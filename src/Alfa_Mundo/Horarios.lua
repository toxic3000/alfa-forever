-- Alfa - Mundo: los horarios de barcos de La Jauría (1.4.0, mejora 37).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Cada barco, zepelín, tranvía y elevador da vueltas fijas, pero en qué
-- punto de su vuelta va depende de cuándo arrancó el servidor: nadie lo sabe
-- hasta que alguien lo toma y el motor lo mide (Nav/Transit.lua). Con esto,
-- cuando un lobo de tu hermandad mide uno, todos tienen la cuenta real: la
-- tarjeta del viaje dice «sale en 1:20» en vez de «~3 min», y quién lo midió.
--
-- Cómo se comparte: con la red de La Jauría (AlfaManada.Red, tipo "t"), solo
-- por la hermandad; nunca a canales públicos ni por susurro. Todo mensaje
-- lleva la facción al final (la red la pone: «|~H» / «|~A») y versión:
--   1t|S|<versión>|<ruta>:<visto s>:<fase ms>;...   tus horarios medidos
--   1t|Q|<versión>                                   «¿alguien midió algo?»
-- Una versión más nueva que la tuya se ignora (no se adivina un formato que
-- no conoces); una vieja se lee si trae lo mismo. Lo de otra facción ya no
-- llega (Núcleo, Faccion.lua). Solo se comparte lo que TÚ mediste, y lo que
-- llega solo cuenta si es de las últimas 6 horas y de tu reino (lo mismo que
-- pide el motor: Transit.decode); lo tuyo de la última hora siempre gana.
-- Ajuste mundo.horariosManada (de fábrica, sí). Sin hermandad, nada.
--
--   Ho.Mios() -> { "ruta:visto:fase", ... }   Ho.Texto(entradas) ; Ho.Leer(campos) -> entradas | nil
--   Ho.Enviar() ; Ho.Preguntar() ; Ho.AlMensaje(clave, remitente, campos, canal)
--   Ho.Fuente(id de transporte) -> { nombre, t } | nil   quién te pasó su horario (la tarjeta lo dice)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

local type, ipairs, pairs, pcall, tonumber, tostring, format, floor = type, ipairs, pairs, pcall, tonumber, tostring, string.format, math.floor

local Ho = {}
M.Horarios = Ho

Ho.TIPO = "t"
Ho.VERSION = 1
local MAX_EDAD = 6 * 3600   -- s: como el motor (un reinicio del servidor rehace las vueltas)
local RESP_HUECO = 120      -- s entre dos respuestas a una pregunta
local TOPE = 220            -- letras por mensaje (la red tiene 255 con el prefijo y la facción)
local ultimaRespuesta = -math.huge
local fuentes = {}          -- id de transporte -> { nombre, t }

local function activo() return A.Get("mundo.horariosManada") ~= false end
local function ahoraJuego() return GetTime and GetTime() or 0 end

local function red()
	local Ma = rawget(_G, "AlfaManada")
	local R = type(Ma) == "table" and rawget(Ma, "Red")
	if type(R) == "table" and type(R.EnviarHermandad) == "function" and type(R.Escuchar) == "function" then return R end
	return nil
end

local function transit()
	local X = A.Transit
	if type(X) == "table" and type(X.encode) == "function" and type(X.decode) == "function" and type(X.Sighted) == "function" then return X end
	return nil
end

local function enHermandad()
	if not IsInGuild then return false end
	local ok, si = pcall(IsInGuild)
	return ok and N.Si(si) or false
end

-- Tus horarios medidos de este reino (lo que guarda el motor), frescos.
local function guardados()
	local db = type(A.DB) == "function" and A.DB() or nil
	local t = type(db) == "table" and type(db.transit) == "table" and db.transit or nil
	if not t then return nil end
	local C = A.Compat
	local ok, i = pcall(function() return C and C.GetPlayerInfo and C.GetPlayerInfo() end)
	local reino = ok and type(i) == "table" and type(i.realm) == "string" and i.realm ~= "" and i.realm or "?"
	return type(t[reino]) == "table" and t[reino] or nil
end

function Ho.Mios()
	local X = transit()
	local s = guardados()
	local out = {}
	if not (X and s) then return out end
	local ahora = X.Now and X.Now() or (GetServerTime and GetServerTime()) or 0
	for ruta, a in pairs(s) do
		if type(a) == "table" and a.source == "you" and type(a.seen) == "number" and type(a.epoch) == "number"
			and ahora - a.seen <= MAX_EDAD then
			local ok, e = pcall(X.encode, ruta, a)
			if ok and type(e) == "string" then out[#out + 1] = e end
		end
	end
	table.sort(out)
	return out
end

-- Los mensajes de unas entradas (varios si no caben en uno).
function Ho.Texto(entradas)
	local mensajes, actual = {}, {}
	local base = "S|" .. Ho.VERSION .. "|"
	local largo = #base
	for _, e in ipairs(entradas or {}) do
		if largo + #e + 1 > TOPE and #actual > 0 then
			mensajes[#mensajes + 1] = base .. table.concat(actual, ";")
			actual, largo = {}, #base
		end
		actual[#actual + 1] = e
		largo = largo + #e + 1
	end
	if #actual > 0 then mensajes[#mensajes + 1] = base .. table.concat(actual, ";") end
	return mensajes
end

function Ho.Enviar()
	if not (activo() and enHermandad()) then return false end
	local R = red()
	if not R then return false end
	local mios = Ho.Mios()
	if #mios == 0 then return false end
	local algo = false
	for i, texto in ipairs(Ho.Texto(mios)) do
		local ok, r = pcall(R.EnviarHermandad, "mundo.horarios." .. i, Ho.TIPO, texto)
		algo = algo or (ok and r and true or false)
	end
	return algo
end

function Ho.Preguntar()
	if not (activo() and enHermandad()) then return false end
	local R = red()
	if not R then return false end
	local ok, r = pcall(R.EnviarHermandad, "mundo.horarios.q", Ho.TIPO, "Q|" .. Ho.VERSION)
	return ok and r and true or false
end

---------------------------------------------------------------------------
-- Lo que llega
---------------------------------------------------------------------------
-- campos = { "S", versión, "ruta:visto:fase;..." } -> el texto de las entradas | nil
function Ho.Leer(campos)
	if type(campos) ~= "table" or campos[1] ~= "S" then return nil end
	local v = tonumber(campos[2])
	if not v or v < 1 or v > Ho.VERSION then return nil end
	local cuerpo = campos[3]
	if type(cuerpo) ~= "string" or cuerpo == "" or #cuerpo > 255 then return nil end
	if not cuerpo:match("^[%w%-:;]+$") then return nil end
	return cuerpo
end

local function nombreCorto(remitente)
	return type(remitente) == "string" and (remitente:match("^([^%-]+)") or remitente) or nil
end

local recibiendo -- el nombre de quien mandó lo que se está anotando (NAV_TRANSIT dice qué cambió)

function Ho.AlMensaje(_, remitente, campos, canal)
	if not activo() or canal ~= "GUILD" or type(campos) ~= "table" then return end
	if campos[1] == "Q" then
		local ahora = ahoraJuego()
		if ahora - ultimaRespuesta < RESP_HUECO then return end
		if #Ho.Mios() == 0 then return end
		ultimaRespuesta = ahora
		N.Una("mundo.horarios.respuesta", 3 + math.random() * 9, Ho.Enviar)
		return
	end
	local cuerpo = Ho.Leer(campos)
	local X = transit()
	if not (cuerpo and X) then return end
	local ahora = X.Now and X.Now() or 0
	local ok, entradas = pcall(X.decode, cuerpo, ahora)
	if not (ok and type(entradas) == "table") then return end
	local cuantas = 0
	recibiendo = nombreCorto(remitente) or "?"
	for ruta, a in pairs(entradas) do
		local bien, si = pcall(X.Sighted, ruta, a)
		if bien and si then cuantas = cuantas + 1 end
	end
	recibiendo = nil
	return cuantas
end

-- Quién te pasó el horario de un transporte (la tarjeta del viaje lo dice).
function Ho.Fuente(id)
	local f = id ~= nil and fuentes[id]
	if not f then return nil end
	if (time and time() or 0) - (f.t or 0) > MAX_EDAD then fuentes[id] = nil return nil end
	return f
end

local escuchando = false
function Ho.Escuchar()
	if escuchando then return true end
	local R = red()
	if not R then return false end
	local ok, si = pcall(R.Escuchar, Ho.TIPO, Ho.AlMensaje, true)
	escuchando = ok and si and true or false
	return escuchando
end

-- La tarjeta del viaje pregunta por aquí (motor/Alfa/Nav/Arrow.lua).
if A.Nav then A.Nav.HorarioDeLaManada = function(id) local f = Ho.Fuente(id) return f and f.nombre or nil end end

if A.On then
	-- Lo que cambió: si viene de un lobo, se anota quién; si lo mediste tú, se comparte.
	A.On("NAV_TRANSIT", function(cambios, propio)
		if recibiendo and type(cambios) == "table" then
			local t = time and time() or 0
			for id in pairs(cambios) do fuentes[id] = { nombre = recibiendo, t = t } end
			return
		end
		if propio and type(cambios) == "table" and next(cambios) then
			for id in pairs(cambios) do fuentes[id] = nil end
			if activo() then N.Una("mundo.horarios.envio", 5, Ho.Enviar) end
		end
	end)
	A.On("SETTING_CHANGED", function(path)
		if path == "mundo.horariosManada" and activo() then
			Ho.Escuchar()
			N.Una("mundo.horarios.pregunta", 2, Ho.Preguntar)
		end
	end)
end

A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, inicial)
	Ho.Escuchar()
	if not (inicial and activo()) then return end
	-- Al entrar: lo tuyo (si mediste algo hace poco) y la pregunta, sin prisa.
	N.Una("mundo.horarios.envio", 45, Ho.Enviar)
	N.Una("mundo.horarios.pregunta", 60, Ho.Preguntar)
end)
