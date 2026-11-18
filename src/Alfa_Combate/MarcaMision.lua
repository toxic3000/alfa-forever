-- Alfa - Combate: marca de misión en las placas de nombre (toxic3000 / La Jauría). GPL-3.0.
--
-- Quien te falta para una misión de tu registro lleva en su placa de nombre
-- un ícono de misión de Alfa y, si quieres, un brillo suave que late
-- alrededor de su barra (combate.marcaMision, combate.marcaMisionBrillo).
-- Cómo se sabe, con lo que el cliente deja leer:
--   * C_TooltipInfo.GetUnit(unidad): sus líneas de objetivo de misión
--     (Enum.TooltipDataLineType.QuestObjective) que aún no están completas y
--     son tuyas (no las de otro del grupo, que van tras su nombre);
--   * los datos de misiones del motor (Alfa.QuestDB.ObjectivesForNpc por el
--     id del PNJ), para lo que el cuadro no diga;
--   * UnitIsQuestBoss.
-- Si algo llega secreto (mazmorras, encuentros) se toma como "no se sabe" y
-- la placa queda sin marca, sin errores. El motor ya pone su calavera en las
-- placas de lo que hay que matar (qol.nameplateIcons): si está a la vista,
-- Alfa no repite el ícono y solo agrega el brillo.
-- Se repasa al aparecer una placa, al cambiar tu registro de misiones
-- (QUEST_LOG_UPDATE, UNIT_QUEST_LOG_CHANGED) y al salir de combate. Los
-- objetos del mundo (cajas, plantas...) no se pueden marcar desde un addon.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local MM = {}
M.MarcaMision = MM

local type, ipairs, pairs, pcall, tonumber, floor = type, ipairs, pairs, pcall, tonumber, math.floor

local TAM = 18
local LINEA = Enum and Enum.TooltipDataLineType or {}
local OBJETIVO = LINEA.QuestObjective or 8
local TITULO = LINEA.QuestTitle or 17
local JUGADOR = LINEA.QuestPlayer or 18

local placas = {}   -- unidad -> true mientras su placa está a la vista
local marcas = {}   -- unidad -> marca
local reserva = {}
local pendiente = false

local function encendida()
	if not M.Opt("marcaMision") then return false end
	if A.Hidden and A.Hidden() then return false end
	return true
end

---------------------------------------------------------------------------
-- ¿Te falta para una misión? true, false o nil (no se sabe)
---------------------------------------------------------------------------
local function porCuadro(unidad)
	local fn = C_TooltipInfo and C_TooltipInfo.GetUnit
	if type(fn) ~= "function" then return nil end
	local ok, datos = pcall(fn, unidad)
	if not ok or M.Secreto(datos) or type(datos) ~= "table" then return nil end
	local lineas = datos.lines
	if M.Secreto(lineas) or type(lineas) ~= "table" then return nil end
	local yo = M.Legible(M.Llamar(UnitName, "player"))
	local mia, falta, dudosa = true, false, false
	for _, ln in ipairs(lineas) do
		if M.Secreto(ln) or type(ln) ~= "table" then
			dudosa = true
		else
			local tipo = M.Legible(ln.type)
			if tipo == TITULO then
				mia = true
			elseif tipo == JUGADOR then
				-- Lo que sigue es de otro del grupo (o tuyo, si dice tu nombre).
				local quien = M.Legible(ln.leftText)
				mia = type(quien) == "string" and quien == yo
			elseif tipo == OBJETIVO and mia then
				local hecha = M.Legible(ln.completed)
				if hecha == false then
					falta = true
				elseif hecha == nil then
					local t = M.Legible(ln.leftText)
					if type(t) == "string" then
						local a, b = t:match("(%d+)%s*/%s*(%d+)")
						if not a or tonumber(a) < tonumber(b) then falta = true end
					else
						dudosa = true
					end
				end
			end
		end
		if falta then return true end
	end
	if dudosa then return nil end
	return false
end

local function porMotor(unidad)
	local Q, C = A.QuestDB, A.Compat
	if type(Q) ~= "table" or type(Q.ObjectivesForNpc) ~= "function" then return nil end
	if type(C) ~= "table" or type(C.GetNpcID) ~= "function" then return nil end
	if type(Q.IsRunning) == "function" then
		local ok, si = pcall(Q.IsRunning)
		if ok and not si then return nil end
	end
	local ok, npc = pcall(C.GetNpcID, unidad)
	if not ok or type(npc) ~= "number" then return nil end
	local ok2, lista = pcall(Q.ObjectivesForNpc, npc)
	if not ok2 or type(lista) ~= "table" then return false end
	for _, o in ipairs(lista) do
		if type(o) == "table" and not o.done and not (type(o.entry) == "table" and o.entry.ready) then return true end
	end
	return false
end

function MM.Falta(unidad)
	if type(unidad) ~= "string" then return nil end
	if M.Legible(M.Llamar(UnitIsPlayer, unidad)) == true then return false end
	if M.Legible(M.Llamar(UnitIsDead, unidad)) == true then return false end
	if M.Legible(M.Llamar(UnitIsQuestBoss, unidad)) == true then return true end
	-- En combate, sin leer el cuadro de cada placa (pesa con muchas a la vista):
	-- solo lo que sabe el motor; al salir del combate se repasa todo (1.2.0).
	local a = nil
	if not (InCombatLockdown and InCombatLockdown()) then a = porCuadro(unidad) end
	if a == true then return true end
	local b = porMotor(unidad)
	if b == true then return true end
	if a == nil and b == nil then return nil end
	return false
end

---------------------------------------------------------------------------
-- La marca
---------------------------------------------------------------------------
local function placaDe(unidad)
	if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
	local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, unidad)
	if not ok or type(p) ~= "table" then return nil end
	if p.IsForbidden and p:IsForbidden() then return nil end
	return p
end

-- El marco que el jugador ve y su barra de vida.
local function partes(placa)
	local uf = rawget(placa, "UnitFrame")
	if type(uf) ~= "table" or (uf.IsForbidden and uf:IsForbidden()) then uf = nil end
	local barra
	if uf then
		barra = rawget(uf, "healthBar")
		local cont = rawget(uf, "HealthBarsContainer")
		if not barra and type(cont) == "table" then barra = rawget(cont, "healthBar") end
		if type(barra) ~= "table" then barra = nil end
	end
	return uf or placa, barra
end

local function brilloMedia()
	local T = A.Theme
	if T and T.Media then
		local ok, p = pcall(T.Media, "glow")
		if ok and type(p) == "string" then return p end
	end
	return "Interface\\Buttons\\WHITE8x8"
end

local function nueva()
	local m = CreateFrame("Frame")
	m:SetSize(TAM, TAM)
	m.caja = K.Caja(m, { fondo = "fondo", alfaFondo = 0.88, borde = "mision", corte = K.CORTE.casilla })
	m.Icono = K.Icono(m, "ic-misiones", TAM - 6, "mision")
	m.Icono:SetPoint("CENTER", m, "CENTER", 0, 0)
	-- El brillo: un marco aparte, debajo de la barra, que late.
	local g = CreateFrame("Frame")
	g.Luz = g:CreateTexture(nil, "BACKGROUND")
	g.Luz:SetTexture(brilloMedia())
	g.Luz:SetBlendMode("ADD")
	g.Luz:SetAllPoints(g)
	K.Pintar(g.Luz, function(t) t:SetVertexColor(K.Color("mision")) end)
	local ag = g:CreateAnimationGroup()
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(0.85)
	a:SetToAlpha(0.3)
	a:SetDuration(0.9)
	a:SetSmoothing("IN_OUT")
	ag:SetLooping("BOUNCE")
	g.late = ag
	m.Aura = g
	return m
end

local function soltar(unidad)
	local m = marcas[unidad]
	if not m then return end
	marcas[unidad] = nil
	m.Aura.late:Stop()
	m.Aura:Hide()
	m.Aura:ClearAllPoints()
	m.Aura:SetParent(nil)
	m:Hide()
	m:ClearAllPoints()
	m:SetParent(nil)
	reserva[#reserva + 1] = m
end

-- ¿El motor ya muestra su ícono de misión en esta placa?
local function iconoDelMotor(unidad)
	local Q = A.QuestDB
	if type(Q) ~= "table" or type(Q.NameplateIcon) ~= "function" then return false end
	local ok, ic = pcall(Q.NameplateIcon, unidad)
	return ok and type(ic) == "table" and ic.IsShown and ic:IsShown() and true or false
end

local function poner(unidad)
	local placa = placaDe(unidad)
	if not placa then soltar(unidad) return end
	local m = marcas[unidad]
	if not m then
		m = table.remove(reserva) or nueva()
		marcas[unidad] = m
	end
	local dueno, barra = partes(placa)
	local ok = pcall(function()
		local ref = barra or dueno
		m:SetParent(dueno)
		m:ClearAllPoints()
		if barra then
			m:SetPoint("RIGHT", barra, "LEFT", -4, 0)
		else
			m:SetPoint("BOTTOM", dueno, "TOP", 0, 2)
		end
		m:SetFrameStrata(ref:GetFrameStrata())
		m:SetFrameLevel(ref:GetFrameLevel() + 6)
		local g = m.Aura
		g:SetParent(dueno)
		g:ClearAllPoints()
		g:SetPoint("TOPLEFT", ref, "TOPLEFT", -8, 6)
		g:SetPoint("BOTTOMRIGHT", ref, "BOTTOMRIGHT", 8, -6)
		g:SetFrameStrata(ref:GetFrameStrata())
		g:SetFrameLevel(math.max(0, ref:GetFrameLevel() - 1))
	end)
	if not ok then soltar(unidad) return end
	-- Si el motor ya puso su calavera, no se repite el ícono.
	m:SetShown(not iconoDelMotor(unidad))
	local luz = M.Opt("marcaMisionBrillo") and true or false
	m.Aura:SetShown(luz)
	if luz then m.Aura.late:Play() else m.Aura.late:Stop() end
end

local function revisar(unidad)
	if not (encendida() and placas[unidad]) then soltar(unidad) return end
	if MM.Falta(unidad) == true then poner(unidad) else soltar(unidad) end
end

local function todas()
	pendiente = false
	for u in pairs(marcas) do
		if not placas[u] then soltar(u) end
	end
	for u in pairs(placas) do K.Llamar(revisar, u) end
end

-- Muchos eventos seguidos (QUEST_LOG_UPDATE): se repasa una vez.
local function pronto(seg)
	if pendiente then return end
	pendiente = true
	A.After(seg or 0.3, todas)
end

-- Las placas que ya están a la vista (al encender o al entrar).
local function leerPlacas()
	for u in pairs(placas) do placas[u] = nil end
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
	local lista = M.Llamar(C_NamePlate.GetNamePlates)
	if type(lista) ~= "table" or M.Secreto(lista) then return end
	for _, p in ipairs(lista) do
		local u = type(p) == "table" and (rawget(p, "namePlateUnitToken") or (type(p.UnitFrame) == "table" and p.UnitFrame.unit))
		if type(u) == "string" and not M.Secreto(u) then placas[u] = true end
	end
end

-- Lo llama M.Refrescar al cambiar un ajuste (también desde el asistente).
function MM.Ver()
	if not encendida() then
		for u in pairs(marcas) do soltar(u) end
		return
	end
	leerPlacas()
	pronto(0)
end

-- Cuántas placas llevan la marca ahora (pruebas, la página).
function MM.Cuantas()
	local n = 0
	for _ in pairs(marcas) do n = n + 1 end
	return n
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local function cada(fn) return function(...) K.Llamar(fn, ...) end end

A.RegisterEvent("NAME_PLATE_UNIT_ADDED", cada(function(_, unidad)
	if M.Secreto(unidad) or type(unidad) ~= "string" then return end
	placas[unidad] = true
	if encendida() then
		revisar(unidad)
		-- Algunas placas se arman un cuadro después: otra mirada.
		A.After(0, function() if placas[unidad] and marcas[unidad] then K.Llamar(poner, unidad) end end)
	end
end))
A.RegisterEvent("NAME_PLATE_UNIT_REMOVED", cada(function(_, unidad)
	if M.Secreto(unidad) or type(unidad) ~= "string" then return end
	placas[unidad] = nil
	soltar(unidad)
end))
A.RegisterEvent("QUEST_LOG_UPDATE", cada(function() if encendida() then pronto(0.3) end end))
A.RegisterEvent("UNIT_QUEST_LOG_CHANGED", cada(function(_, unidad)
	if not M.Secreto(unidad) and unidad == "player" and encendida() then pronto(0.3) end
end))
A.RegisterEvent("QUEST_ACCEPTED", cada(function() if encendida() then pronto(0.3) end end))
A.RegisterEvent("QUEST_TURNED_IN", cada(function() if encendida() then pronto(0.5) end end))
A.RegisterEvent("PLAYER_REGEN_ENABLED", cada(function() if encendida() then pronto(0.2) end end))
A.RegisterEvent("PLAYER_ENTERING_WORLD", cada(function() MM.Ver() end))
A.On("ALFA_HIDDEN", function() K.Llamar(MM.Ver) end)
