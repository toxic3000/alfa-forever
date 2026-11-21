-- Alfa - Comodidades: la barra de información (1.3.7). toxic3000 / La Jauría. GPL-3.0.
--
-- Una franja chica y movible con lo que uno mira a cada rato: cuadros por
-- segundo y latencia, el oro de esta sesión, tu durabilidad, el espacio en
-- tus bolsas, la hora y la experiencia por hora. Cada dato abre su página de
-- Alfa con un clic (Paisaje, Hoy, Bolsas, Ruta) y cuenta más al pasar el
-- ratón. Se arrastra directo o con «Acomodar la pantalla»; su lugar se guarda
-- en AlfaNucleoDB (comodidades.infoPos).
--
-- Ligera: un solo reloj de Alfa (N.Cada, cada 2 s) mientras se ve; la
-- durabilidad y las bolsas solo se vuelven a leer cuando el juego avisa que
-- cambiaron. En combate no recibe el ratón (nada que atrape clics).
-- Ajuste comodidades.info (de fábrica, apagada: la página la ofrece).
--
-- Cliente: GetFramerate (ClientDocumentation), GetNetStats
-- (ConnectionDocumentation), GetMoney, GetInventoryItemDurability,
-- C_Container.GetContainerNumFreeSlots (ContainerDocumentation: libres y
-- familia; las bolsas especiales no cuentan), UnitXP/UnitXPMax/UnitLevel.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local ID = M.ID

local I = {}
M.Info = I

local type, pcall, tonumber, floor, max, format = type, pcall, tonumber, math.floor, math.max, string.format

local NOMBRE = "AlfaComodidadesInfo"
local ALTO = 22
local CADA = 2
local RELOJ = "comodidades.info"

local barra
local datos = {}       -- id -> { b = botón, fs = texto }
local sucio = { dur = true, bolsas = true }
local cache = {}
local sesion = {}      -- oro, inicio, xp, nivel, xpMax, ganada

local function num(v)
	v = M.Legible(v)
	return type(v) == "number" and v or tonumber(v)
end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

---------------------------------------------------------------------------
-- Los datos
---------------------------------------------------------------------------

function I.Fps()
	if not GetFramerate then return nil end
	local ok, f = pcall(GetFramerate)
	f = ok and num(f)
	return f and floor(f + 0.5) or nil
end

function I.Latencia()
	if not GetNetStats then return nil end
	local ok, _, _, casa, mundo = pcall(GetNetStats)
	if not ok then return nil end
	local v = num(mundo)
	if not v or v <= 0 then v = num(casa) end
	return v and floor(v + 0.5) or nil
end

-- La pieza más gastada, en por ciento (nil sin piezas con durabilidad).
function I.Durabilidad()
	if sucio.dur == false then return cache.dur end
	sucio.dur = false
	cache.dur = nil
	if type(GetInventoryItemDurability) ~= "function" then return nil end
	local menor
	for ranura = 1, 19 do
		local ok, actual, tope = pcall(GetInventoryItemDurability, ranura)
		actual, tope = ok and num(actual), ok and num(tope)
		if actual and tope and tope > 0 then
			local p = actual / tope
			if not menor or p < menor then menor = p end
		end
	end
	cache.dur = menor and floor(menor * 100 + 0.5) or nil
	return cache.dur
end

-- Casillas libres en las bolsas normales (las de oficio o munición no cuentan).
function I.Libres()
	if sucio.bolsas == false then return cache.libres end
	sucio.bolsas = false
	cache.libres = nil
	local C = C_Container
	local fn = type(C) == "table" and C.GetContainerNumFreeSlots or nil
	if type(fn) ~= "function" then fn = rawget(_G, "GetContainerNumFreeSlots") end
	if type(fn) ~= "function" then return nil end
	local n, hay = 0, false
	for bolsa = 0, tonumber(NUM_BAG_SLOTS) or 4 do
		local ok, libres, familia = pcall(fn, bolsa)
		libres, familia = ok and num(libres), ok and num(familia)
		if libres and (not familia or familia == 0) then
			n, hay = n + libres, true
		end
	end
	cache.libres = hay and n or nil
	return cache.libres
end

function I.OroSesion()
	if not (GetMoney and sesion.oro) then return nil end
	local ahora = num(GetMoney())
	return ahora and (ahora - sesion.oro) or nil
end

local function alTope()
	local nivel, tope = num(UnitLevel and UnitLevel("player")), num(GetMaxPlayerLevel and GetMaxPlayerLevel())
	if nivel and tope and nivel >= tope then return true end
	return IsXPUserDisabled and IsXPUserDisabled() and true or false
end

-- La experiencia ganada desde que entraste (sumando las subidas de nivel).
local function leerXP()
	local xp, tope, nivel = num(UnitXP and UnitXP("player")), num(UnitXPMax and UnitXPMax("player")), num(UnitLevel and UnitLevel("player"))
	if not (xp and tope and nivel) then return end
	if sesion.xp then
		if nivel > sesion.nivel then
			sesion.ganada = sesion.ganada + max(0, (sesion.xpMax or 0) - sesion.xp) + xp
		elseif xp >= sesion.xp then
			sesion.ganada = sesion.ganada + (xp - sesion.xp)
		elseif nivel == sesion.nivel then
			-- 1.3.7: subiste y el juego aún no dice tu nivel nuevo: no se pisa
			-- nada (PLAYER_LEVEL_UP lo cuenta bien); si no, salía inflada.
			return
		end
	end
	sesion.xp, sesion.xpMax, sesion.nivel = xp, tope, nivel
end

-- -> experiencia por hora (nil al tope de nivel o con menos de 2 min)
function I.XPHora()
	if alTope() or not sesion.inicio then return nil end
	local t = (GetTime and GetTime() or 0) - sesion.inicio
	if t < 120 then return nil end
	return floor((sesion.ganada or 0) * 3600 / t + 0.5)
end

function I.Hora()
	return date and date("%H:%M") or nil
end

-- 12345 -> "12,345".
local function miles(n)
	local s = tostring(floor(n))
	local sep = ","
	local r = s:reverse():gsub("(%d%d%d)", "%1" .. sep:reverse())
	r = r:reverse()
	if r:sub(1, #sep) == sep then r = r:sub(#sep + 1) end
	return r
end
I.Miles = miles

---------------------------------------------------------------------------
-- Lo que dice cada dato: { id, pagina, texto() -> string|nil, titulo, detalle() }
---------------------------------------------------------------------------
local function tono(v, bien, mal, alReves)
	if not v then return "textoSuave" end
	if alReves then
		if v <= mal then return "peligro" elseif v <= bien then return "aviso" end
		return "texto"
	end
	if v >= mal then return "peligro" elseif v >= bien then return "aviso" end
	return "texto"
end

local DATOS = {
	{ id = "rendimiento", pagina = "vista", titulo = L["Rendimiento"],
		texto = function()
			local f, ms = I.Fps(), I.Latencia()
			if not (f or ms) then return nil end
			local partes = {}
			if f then partes[#partes + 1] = K.Tenir(tono(f, 30, 20, true), f) .. " " .. K.Tenir("textoTenue", L["fps"]) end
			if ms then partes[#partes + 1] = K.Tenir(tono(ms, 200, 400), ms) .. " " .. K.Tenir("textoTenue", L["ms"]) end
			return table.concat(partes, "  ")
		end,
		detalle = function() return L["Cuadros por segundo y la latencia con el mundo. Clic: Paisaje y gráficos, para ganar fluidez."] end },
	{ id = "oro", pagina = "inicio", titulo = L["Oro de esta sesión"],
		texto = function()
			local d = I.OroSesion()
			if not d then return nil end
			if d == 0 then return K.Tenir("textoTenue", L["Oro"]) .. " " .. N.Dinero(0, true) end
			return (d < 0 and "-" or "+") .. N.Dinero(math.abs(d), true)
		end,
		detalle = function()
			local d = I.OroSesion() or 0
			local t = sesion.inicio and N.Duracion((GetTime and GetTime() or 0) - sesion.inicio) or ""
			local linea = d >= 0 and format(L["Ganaste %s en %s."], N.Dinero(d), t) or format(L["Gastaste %s en %s."], N.Dinero(-d), t)
			return linea .. "\n" .. L["Clic: abre Hoy."]
		end },
	{ id = "durabilidad", pagina = "inicio", titulo = L["Durabilidad"],
		texto = function()
			local p = I.Durabilidad()
			if not p then return nil end
			return K.Tenir("textoTenue", L["Equipo"]) .. " " .. K.Tenir(tono(p, 50, 25, true), p .. " %")
		end,
		detalle = function() return L["La pieza más gastada de lo que llevas puesto. Con poca, toca reparar. Clic: abre Hoy."] end },
	{ id = "bolsas", pagina = "bolsas", titulo = L["Bolsas"],
		texto = function()
			local n = I.Libres()
			if not n then return nil end
			return K.Tenir("textoTenue", L["Bolsas"]) .. " " .. K.Tenir(tono(n, 5, 0, true), n)
		end,
		detalle = function() return N.Plural(I.Libres() or 0, L["%d casilla libre en tus bolsas."], L["%d casillas libres en tus bolsas."]) .. "\n" .. L["Clic: abre Bolsas."] end },
	{ id = "xp", pagina = "rutas", titulo = L["Experiencia por hora"],
		texto = function()
			if alTope() then return nil end
			local x = I.XPHora()
			return K.Tenir("textoTenue", L["XP/h"]) .. " " .. (x and miles(x) or K.Tenir("textoTenue", "…"))
		end,
		detalle = function()
			local x = I.XPHora()
			local t = x and format(L["A tu ritmo de esta sesión: %s de experiencia por hora."], miles(x))
				or L["Se calcula tras unos minutos de juego."]
			return t .. "\n" .. L["Clic: abre Ruta."]
		end },
	{ id = "hora", pagina = "inicio", titulo = L["Hora"],
		texto = function() return I.Hora() end,
		detalle = function() return L["La hora de tu computadora. Clic: abre Hoy."] end },
}
I.DATOS = DATOS

---------------------------------------------------------------------------
-- La barra
---------------------------------------------------------------------------

local function guardarLugar()
	if not barra then return end
	local p, _, rp, x, y = barra:GetPoint(1)
	if type(p) ~= "string" then return end
	N.Datos(ID).infoPos = { p, rp or p, floor((x or 0) + 0.5), floor((y or 0) + 0.5) }
end

local function ponerLugar()
	barra:ClearAllPoints()
	local pos = N.Datos(ID).infoPos
	if type(pos) == "table" and type(pos[1]) == "string" then
		barra:SetPoint(pos[1], UIParent, pos[2] or pos[1], tonumber(pos[3]) or 0, tonumber(pos[4]) or 0)
	else
		barra:SetPoint("TOP", UIParent, "TOP", 0, -4)
	end
end

function I.Restablecer()
	N.Datos(ID).infoPos = nil
	if barra then ponerLugar() end
end

local function empezar()
	if enCombate() or (A.DragLocked and A.DragLocked()) then return end
	barra:StartMoving()
	barra.moviendo = true
end

-- (Acomodar la pantalla la mueve con StartMoving y llama a este OnDragStop.)
local function soltar()
	barra.moviendo = nil
	barra:StopMovingOrSizing()
	guardarLugar()
end

local function crear()
	if barra then return barra end
	barra = CreateFrame("Frame", NOMBRE, K.Raiz())
	barra:SetFrameStrata("LOW")
	barra:SetHeight(ALTO)
	barra:SetWidth(200)
	barra:SetMovable(true)
	barra:SetClampedToScreen(true)
	barra:EnableMouse(true)
	barra:RegisterForDrag("LeftButton")
	barra:SetScript("OnDragStart", empezar)
	barra:SetScript("OnDragStop", soltar)
	barra.caja = K.Caja(barra, { fondo = "fondo", borde = "linea", corte = K.CORTE.control })
	barra.caja:Estilo({ alfaFondo = 0.88 })
	for _, d in ipairs(DATOS) do
		local b = CreateFrame("Button", nil, barra)
		b:SetHeight(ALTO)
		b:RegisterForClicks("LeftButtonUp")
		b:RegisterForDrag("LeftButton")
		b.fs = K.Texto(b, "pequeno", "texto")
		b.fs:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.fs:SetWordWrap(false)
		b:SetScript("OnClick", function() if d.pagina then N.Abrir(d.pagina) end end)
		b:SetScript("OnDragStart", empezar)
		b:SetScript("OnDragStop", soltar)
		b:SetScript("OnEnter", function(self)
			local ok, t = pcall(d.detalle)
			K.MostrarInfo(self, d.titulo, ok and t or nil)
		end)
		b:SetScript("OnLeave", function(self) K.OcultarInfo(self) end)
		datos[d.id] = { b = b, d = d }
	end
	ponerLugar()
	barra:Hide()
	return barra
end

-- Pinta cada dato y acomoda los que hay, de izquierda a derecha.
function I.Actualizar()
	if not (barra and barra:IsShown()) then return end
	local x, PAD, SEP = 8, 6, 4
	for _, d in ipairs(DATOS) do
		local e = datos[d.id]
		local ok, t = pcall(d.texto)
		t = ok and t or nil
		if t then
			K.Escribir(e.b.fs, t)
			local w = K.AnchoTexto(e.b.fs) + PAD * 2
			e.b:SetWidth(w)
			e.b:ClearAllPoints()
			e.b:SetPoint("LEFT", barra, "LEFT", x, 0)
			e.b:Show()
			x = x + w + SEP
		else
			e.b:Hide()
		end
	end
	barra:SetWidth(max(60, x - SEP + 8))
end

-- En combate nada de Alfa atrapa clics: la barra se ve, pero no recibe el ratón.
local function raton(si)
	if not barra then return end
	barra:EnableMouse(si)
	for _, e in pairs(datos) do e.b:EnableMouse(si) end
end

local function aplicar()
	local si = M.Get("info") and not (A.Hidden and A.Hidden())
	if si then
		crear()
		if not sesion.inicio then
			sesion.inicio = GetTime and GetTime() or 0
			sesion.oro = GetMoney and num(GetMoney()) or nil
			sesion.ganada = 0
			leerXP()
		end
		sucio.dur, sucio.bolsas = true, true
		barra:Show()
		raton(not enCombate())
		I.Actualizar()
		N.Cada(RELOJ, CADA, I.Actualizar)
		local Ac = rawget(_G, "AlfaAcomodar")
		if type(Ac) == "table" and type(Ac.Agregar) == "function" then
			pcall(Ac.Agregar, { id = "comodidadesInfo", titulo = L["La barra de información"], marco = NOMBRE,
				restablecer = function() I.Restablecer() end })
		end
	else
		N.Quitar(RELOJ)
		if barra then barra:Hide() end
	end
end
I.Aplicar = aplicar

M.AlCambiar({ "info" }, aplicar)

-- El oro y la experiencia se cuentan desde que entras, aunque la enciendas después.
A.OnLogin(function()
	sesion.inicio = GetTime and GetTime() or 0
	sesion.oro = GetMoney and num(GetMoney()) or nil
	sesion.ganada, sesion.xp = 0, nil
	leerXP()
end)
A.RegisterEvent("PLAYER_XP_UPDATE", function() leerXP() end)
A.RegisterEvent("PLAYER_LEVEL_UP", function() N.Una("comodidades.infoNivel", 0.5, leerXP) end)
A.RegisterEvent("UPDATE_INVENTORY_DURABILITY", function() sucio.dur = true end)
A.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() sucio.dur = true end)
A.RegisterEvent("BAG_UPDATE_DELAYED", function() sucio.bolsas = true end)
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() raton(false) end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() raton(true) end)

-- Para pruebas.
I.Barra = function() return barra end
I.Datos = datos
I.Sesion = sesion
