-- Alfa - Combate: temporizadores de jefe sencillos (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.7. Sin registro de combate ni datos de otros addons: Alfa aprende pelea
-- a pelea. Cada vez que un jefe ("boss1".."boss5") empieza a lanzar algo que
-- se ve (UNIT_SPELLCAST_START / _CHANNEL_START), se guarda cuánto pasó desde
-- su lanzamiento anterior y desde que empezó la pelea. La siguiente vez, una
-- línea chica dice «Próximo Aliento en ~15 s». Sin datos, nada.
--   * Se guarda por jefe (su encuentro o su número de criatura) y por hechizo,
--     en AlfaNucleoDB.combate.jefes: { media, veces, primero, vecesPrimero }.
--   * Lo secreto (dentro de mazmorras el juego puede ocultar qué lanza) no se
--     lee: esa vez no se aprende.
--   * Solo se escucha dentro de una instancia; el reloj corre solo en la pelea.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local J = {}
M.Jefes = J

local type, ipairs, pairs, pcall, floor, max, min, format, tonumber, tostring, sort = type, ipairs, pairs, pcall, math.floor, math.max, math.min, string.format, tonumber, tostring, table.sort
local ESP = K.ESP

local MIN_INTERVALO, MAX_INTERVALO = 3, 180
local HASTA = 30     -- s: solo lo que viene en menos de esto
local LINEAS = 3
local VECES_MAX = 10 -- la media pesa como mucho tantas peleas

local pelea          -- { clave, inicio, ultimo = { [id] = t }, nombre = { [id] = texto } }
local ev, f

local function guardado()
	local d = N.Datos(M.ID)
	if type(d.jefes) ~= "table" then d.jefes = {} end
	return d.jefes
end

local function numero(v) if M.Secreto(v) or type(v) ~= "number" then return nil end return v end

-- El jefe: su encuentro (si el juego lo dijo) o su número de criatura.
local encuentro
local function claveDe(unidad)
	if encuentro then return "e" .. encuentro end
	local guid = M.Legible(M.Llamar(UnitGUID, unidad))
	if type(guid) ~= "string" then return nil end
	local npc = select(6, strsplit("-", guid))
	return npc and ("n" .. npc) or nil
end

---------------------------------------------------------------------------
-- Aprender
---------------------------------------------------------------------------
local function aprender(clave, id, cuanto, campo, vecesCampo)
	local g = guardado()
	g[clave] = type(g[clave]) == "table" and g[clave] or {}
	local x = type(g[clave][id]) == "table" and g[clave][id] or {}
	g[clave][id] = x
	local n = min(VECES_MAX, tonumber(x[vecesCampo]) or 0)
	local m = tonumber(x[campo]) or cuanto
	x[campo] = floor(((m * n) + cuanto) / (n + 1) * 10 + 0.5) / 10
	x[vecesCampo] = n + 1
end

-- unidad lanzó id (en el momento ahora).
function J.Lanzo(unidad, id, ahora)
	if not M.Opt("jefes") then return end
	if type(unidad) ~= "string" or not unidad:find("^boss%d$") then return end
	id = numero(id)
	if not id then return end
	ahora = ahora or GetTime()
	if not pelea then J.Empieza(nil, unidad, ahora) end
	if not pelea.clave then pelea.clave = claveDe(unidad) end
	if not pelea.clave then return end
	local antes = pelea.ultimo[id]
	if antes then
		local i = ahora - antes
		if i >= MIN_INTERVALO and i <= MAX_INTERVALO then aprender(pelea.clave, id, i, "media", "veces") end
	else
		local i = ahora - pelea.inicio
		if i >= 0 and i <= MAX_INTERVALO then aprender(pelea.clave, id, i, "primero", "vecesPrimero") end
	end
	pelea.ultimo[id] = ahora
	J.Pintar()
end

-- Lo que viene: { { id, nombre, falta } }, de lo más cercano a lo más lejano.
function J.Proximos(ahora)
	if not (pelea and pelea.clave) then return {} end
	ahora = ahora or GetTime()
	local g = guardado()[pelea.clave]
	if type(g) ~= "table" then return {} end
	local out = {}
	for id, x in pairs(g) do
		if type(x) == "table" then
			local cuando
			local ult = pelea.ultimo[id]
			if ult and tonumber(x.media) and (tonumber(x.veces) or 0) >= 1 then
				cuando = ult + x.media
			elseif not ult and tonumber(x.primero) and (tonumber(x.vecesPrimero) or 0) >= 1 then
				cuando = pelea.inicio + x.primero
			end
			if cuando then
				local falta = cuando - ahora
				if falta > -2 and falta <= HASTA then
					out[#out + 1] = { id = id, nombre = M.NombreHechizo(id) or L["Su próximo ataque"], falta = max(0, falta) }
				end
			end
		end
	end
	sort(out, function(a, b) return a.falta < b.falta end)
	return out
end

---------------------------------------------------------------------------
-- Lo que se ve: unas líneas chicas, sin ratón
---------------------------------------------------------------------------
local function crear()
	if f then return f end
	f = M.Marco("Jefes", L["Temporizadores de jefe"], 230, 18 * LINEAS + 8, { "TOP", "TOP", 260, -190 })
	f.lineas = {}
	for i = 1, LINEAS do
		local t = K.Texto(f, "pequeno", i == 1 and "texto" or "textoSuave")
		t:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4 - (i - 1) * 18)
		t:SetPoint("RIGHT", f, "RIGHT", -4, 0)
		f.lineas[i] = t
	end
	f:Hide()
	return f
end

function J.Pintar()
	local lista = (M.Opt("jefes") and pelea) and J.Proximos() or {}
	if M.Desbloqueado() and #lista == 0 then
		lista = { { nombre = L["Aliento de fuego"], falta = 15 } }
	end
	if #lista == 0 then
		if f then f:Hide() end
		return
	end
	crear()
	for i = 1, LINEAS do
		local x = lista[i]
		if x then
			local s = floor(x.falta + 0.5)
			K.Escribir(f.lineas[i], s <= 0 and format(L["%s: ¡ya viene!"], x.nombre) or format(L["Próximo %s en ~%d s"], x.nombre, s))
			K.ColorTexto(f.lineas[i], s <= 3 and "aviso" or (i == 1 and "texto" or "textoSuave"))
			f.lineas[i]:Show()
		else
			f.lineas[i]:Hide()
		end
	end
	f:Show()
end

function J.Empieza(id, unidad, ahora)
	encuentro = numero(id)
	pelea = { clave = nil, inicio = ahora or GetTime(), ultimo = {} }
	if unidad then pelea.clave = claveDe(unidad) end
	N.Cada("combate.jefes", 0.5, J.Pintar)
end

function J.Termina()
	pelea, encuentro = nil, nil
	N.Quitar("combate.jefes")
	if f and not M.Desbloqueado() then f:Hide() end
end

function J.EnPelea() return pelea ~= nil end

---------------------------------------------------------------------------
-- Escuchar solo dentro de una instancia
---------------------------------------------------------------------------
local EVENTOS = { "ENCOUNTER_START", "ENCOUNTER_END" }
-- 1.3.7: los lanzamientos, solo de boss1..boss5 (RegisterUnitEvent toma dos
-- unidades por marco): no todos los UNIT_SPELLCAST de la zona.
local LANZAR = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START" }
local PARES = { { "boss1", "boss2" }, { "boss3", "boss4" }, { "boss5" } }
local oyentes = {}

function J.Evento(evento, a, b, c)
	if evento == "ENCOUNTER_START" then
		J.Empieza(a)
	elseif evento == "ENCOUNTER_END" then
		J.Termina()
	else
		-- (unidad, castGUID, spellID); solo los jefes, sin mirar nada más.
		if type(a) == "string" and not M.Secreto(a) and a:sub(1, 4) == "boss" then J.Lanzo(a, c) end
	end
end

function J.Ver()
	local quiere = M.Opt("jefes") and M.EnInstancia()
	if quiere and not ev then
		ev = CreateFrame("Frame")
		ev:SetScript("OnEvent", function(_, evento, ...) K.Llamar(J.Evento, evento, ...) end)
	end
	if ev then
		if quiere then
			for _, e in ipairs(EVENTOS) do pcall(ev.RegisterEvent, ev, e) end
			for i, par in ipairs(PARES) do
				local o = oyentes[i]
				if not o then
					o = CreateFrame("Frame")
					o:SetScript("OnEvent", function(_, evento, ...) K.Llamar(J.Evento, evento, ...) end)
					oyentes[i] = o
				end
				for _, e in ipairs(LANZAR) do
					if not pcall(o.RegisterUnitEvent, o, e, par[1], par[2]) and i == 1 then pcall(o.RegisterEvent, o, e) end
				end
			end
		else
			ev:UnregisterAllEvents()
			for _, o in ipairs(oyentes) do o:UnregisterAllEvents() end
		end
	end
	if not quiere and pelea then J.Termina() end
	if M.Desbloqueado() then J.Pintar() elseif f and not pelea then f:Hide() end
end

A.RegisterEvent("PLAYER_ENTERING_WORLD", function() K.Llamar(J.Ver) end)
-- Sin encuentro (algunos jefes no lo dan): la pelea termina al salir de combate.
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() if pelea and not encuentro then J.Termina() end end)

A.OnLogin(function()
	M.Ensenar({ id = "combate.jefes", icono = "ic-reloj",
		pregunta = L["¿Alfa me avisa lo que va a hacer el jefe?"],
		respuesta = L["Sí, poco a poco: en cada pelea Alfa aprende cada cuánto lanza el jefe sus ataques. La próxima vez verás una línea chica como «Próximo Aliento en ~15 s». La primera pelea no dice nada: está aprendiendo."] })
end)
