-- Alfa - Curación: el maná de los curanderos del grupo (toxic3000 / La Jauría). GPL-3.0.
--
-- Una lista chica arriba de tus marcos con el maná de quienes curan (rol de
-- curandero; si nadie tiene rol, las clases que curan). Solo en grupo y con
-- otro curandero además de ti, o contigo si curas en banda. No atrapa clics.
--   * Fuera de combate el maná se lee y se colorea (rojo bajo 30 %, amarillo
--     bajo 60 %). En combate puede llegar secreto: el porcentaje va directo
--     al texto con UnitPowerPercent y una curva, sin compararse.
--   * Al terminar una pelea la lista se destaca unos segundos («Maná tras la
--     pelea»): es cuando el grupo decide si esperar a sus curanderos.
--   * 1.3.1: quiénes curan (nombre, color, si eres tú) se arma solo cuando
--     cambia el grupo (GROUP_ROSTER_UPDATE, PLAYER_ROLES_ASSIGNED,
--     UNIT_NAME_UPDATE, al entrar); el reloj de cada segundo solo repinta los
--     porcentajes, sin tablas nuevas.
--   M.Mana.Lista() ; M.Mana.Refrescar() ; M.Mana.Sucia()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local T = A.Theme
local L = M.L
local ID = M.ID
local secreto = M.Secreto

local Mn = {}
M.Mana = Mn

local MAX_FILAS = 8
local FILA_H = 14
local ANCHO = 150
local DESTACAR = 12 -- segundos tras la pelea
local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local CURAN = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true }

local function opt(k) return N.Get(ID, k) end

local function leer(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok or secreto(v) then return nil end
	return v
end

local curva
do
	local CU = C_CurveUtil
	if CU and CU.CreateCurve then
		local ok, c = pcall(CU.CreateCurve)
		if ok and c and pcall(function() c:AddPoint(0, 0); c:AddPoint(1, 100) end) then curva = c end
	end
end

-- Las unidades del grupo: "player", "party1".. o "raid1"..
local function unidades()
	local t = {}
	if IsInRaid and IsInRaid() then
		local n = leer(GetNumGroupMembers) or 0
		for i = 1, math.min(40, n) do t[#t + 1] = "raid" .. i end
	elseif IsInGroup and IsInGroup() then
		t[1] = "player"
		for i = 1, 4 do t[#t + 1] = "party" .. i end
	end
	return t
end

-- Los curanderos del grupo -> { { unidad, nombre, clase } }
function Mn.Lista()
	local lista, porRol, porClase = {}, {}, {}
	local hayRoles = false
	for _, u in ipairs(unidades()) do
		local existe = leer(UnitExists, u)
		if existe then
			local rol = leer(UnitGroupRolesAssigned, u)
			if type(rol) == "string" and rol ~= "NONE" then hayRoles = true end
			local _, clase = nil, nil
			local okC, _n, c = pcall(UnitClass, u)
			if okC and not secreto(c) then clase = c end
			local nombre = leer(UnitName, u)
			local d = { unidad = u, nombre = type(nombre) == "string" and nombre or u, clase = clase }
			if rol == "HEALER" then porRol[#porRol + 1] = d end
			if clase and CURAN[clase] then porClase[#porClase + 1] = d end
		end
	end
	local fuente = hayRoles and porRol or porClase
	for i = 1, math.min(MAX_FILAS, #fuente) do lista[i] = fuente[i] end
	return lista
end

---------------------------------------------------------------------------
-- El marco (no seguro, sin ratón)
---------------------------------------------------------------------------

local marco
local destacarHasta = 0

local function texto(padre, rol)
	local fs = padre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	if T and T.Font then T.Font(fs, rol) end
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetWordWrap(false)
	return fs
end

local function crear()
	if marco or not M.ancla then return marco end
	marco = CreateFrame("Frame", "AlfaCuracionMana", M.ancla)
	marco:SetSize(ANCHO, 20)
	marco:SetPoint("BOTTOMLEFT", M.ancla, "TOPLEFT", 0, 30)
	if marco.EnableMouse then marco:EnableMouse(false) end
	marco.fondo = marco:CreateTexture(nil, "BACKGROUND")
	marco.fondo:SetTexture("Interface\\Buttons\\WHITE8x8")
	marco.fondo:SetAllPoints(marco)
	marco.fondo:SetVertexColor(0.02, 0.025, 0.04, 0.8)
	marco.titulo = texto(marco, "caption")
	marco.titulo:SetJustifyH("LEFT")
	marco.titulo:SetPoint("TOPLEFT", marco, "TOPLEFT", 6, -3)
	marco.titulo:SetWidth(ANCHO - 12)
	marco.filas = {}
	for i = 1, MAX_FILAS do
		local f = {}
		f.nombre = texto(marco, "caption")
		f.nombre:SetJustifyH("LEFT")
		f.nombre:SetPoint("TOPLEFT", marco, "TOPLEFT", 6, -3 - i * FILA_H)
		f.nombre:SetWidth(ANCHO - 54)
		f.valor = texto(marco, "caption")
		f.valor:SetJustifyH("RIGHT")
		f.valor:SetPoint("TOPRIGHT", marco, "TOPRIGHT", -6, -3 - i * FILA_H)
		f.valor:SetWidth(44)
		marco.filas[i] = f
	end
	marco:Hide()
	return marco
end

-- Pinta el porcentaje de una fila: legible (con color) o secreto (directo).
local function pintarValor(f, u)
	local v, mx = leer(UnitPower, u, MANA), leer(UnitPowerMax, u, MANA)
	if type(v) == "number" and type(mx) == "number" and mx > 0 then
		local p = v / mx
		f.valor:SetFormattedText("%d%%", math.floor(p * 100 + 0.5))
		if p < 0.3 then f.valor:SetTextColor(1, 0.35, 0.3, 1)
		elseif p < 0.6 then f.valor:SetTextColor(1, 0.82, 0.3, 1)
		else f.valor:SetTextColor(0.55, 0.8, 1, 1) end
		f.pct = p
		return true
	end
	f.pct = nil
	if curva and UnitPowerPercent then
		local ok, p = pcall(UnitPowerPercent, u, MANA, false, curva)
		-- 1.3.1: lo secreto primero (ni siquiera se compara con nil).
		if ok and (secreto(p) or type(p) == "number") then
			f.valor:SetTextColor(0.55, 0.8, 1, 1)
			if pcall(f.valor.SetFormattedText, f.valor, "%.0f%%", p) then return true end
		end
	end
	return false
end

-- 1.3.1: los curanderos de ahora; se arman solo cuando cambia el grupo.
local lista, otros, sucia = {}, 0, true

function Mn.Sucia() sucia = true end

local function armar()
	sucia = false
	lista = Mn.Lista()
	-- Contigo solo, no hace falta: la lista sirve cuando hay otro curandero.
	otros = 0
	for _, d in ipairs(lista) do
		d.yo = leer(UnitIsUnit, d.unidad, "player") and true or false
		if not d.yo then otros = otros + 1 end
		if d.clase and M.ColorDeClase then d.r, d.g, d.b = M.ColorDeClase(d.clase) end
	end
end

function Mn.Refrescar()
	if not crear() then return end
	local quiere = opt("activo") and opt("mana") and IsInGroup and IsInGroup()
	if not quiere then
		Mn.filas = 0
		return marco:Hide()
	end
	if sucia then armar() end
	if otros == 0 then
		Mn.filas = 0
		return marco:Hide()
	end
	local n = 0
	for i, f in ipairs(marco.filas) do
		local d = lista[i]
		if d and pintarValor(f, d.unidad) then
			n = n + 1
			-- El nombre y su color, solo si la fila cambió de curandero.
			if f.alfaDato ~= d then
				f.alfaDato = d
				f.nombre:SetText(d.nombre)
				if d.r then f.nombre:SetTextColor(d.r, d.g, d.b, 1) else f.nombre:SetTextColor(1, 1, 1, 1) end
			end
			f.nombre:Show()
			f.valor:Show()
		else
			f.nombre:Hide()
			f.valor:Hide()
		end
	end
	Mn.filas = n
	local destacado = (GetTime and GetTime() or 0) < destacarHasta and not M.EnCombate()
	Mn.destacado = destacado
	marco.titulo:SetText(destacado and L["Maná tras la pelea"] or L["Maná"])
	if destacado then marco.titulo:SetTextColor(0.545, 0.878, 0.306, 1) else marco.titulo:SetTextColor(0.75, 0.77, 0.8, 1) end
	marco:SetHeight(6 + (n + 1) * FILA_H)
	marco:SetAlpha(destacado and 1 or (M.EnCombate() and 0.6 or 0.8))
	marco:SetShown(n > 0)
end

A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	destacarHasta = (GetTime and GetTime() or 0) + DESTACAR
	Mn.Refrescar()
end)
-- Cambió el grupo (quién está, sus roles o un nombre): la lista se vuelve a armar.
local function cambioGrupo() sucia = true Mn.Refrescar() end
A.RegisterEvent("GROUP_ROSTER_UPDATE", cambioGrupo)
A.RegisterEvent("PLAYER_ROLES_ASSIGNED", cambioGrupo)
A.RegisterEvent("PLAYER_ENTERING_WORLD", cambioGrupo)
A.RegisterEvent("UNIT_NAME_UPDATE", function(_, u)
	if type(u) == "string" and (u == "player" or u:find("^party%d") or u:find("^raid%d")) then cambioGrupo() end
end)
-- Un reloj chico: el maná cambia muy seguido para ir por eventos de cada uno.
-- Solo repinta los porcentajes: la lista ya está armada.
N.Cada("curacion.mana", 1, function()
	if marco and marco:IsShown() or (IsInGroup and IsInGroup() and opt("mana")) then Mn.Refrescar() end
end)
A.On("SETTING_CHANGED", function(path)
	if type(path) == "string" and path:sub(1, #ID + 1) == ID .. "." then Mn.Refrescar() end
end)
