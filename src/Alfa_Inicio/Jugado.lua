-- Alfa - Inicio: tu tiempo jugado (toxic3000 / La Jauría). GPL-3.0.
-- 1.3.7 (191)
--
-- El total, el de tu nivel y el promedio por nivel, en Hoy, sin escribir en
-- el chat. El juego solo lo dice con RequestTimePlayed, que también lo
-- escribe en el chat («Tiempo total jugado: …»): Alfa lo pide una vez al
-- entrar (y al subir de nivel) con el aviso del chat callado solo para esa
-- respuesta (los marcos del chat dejan de oír TIME_PLAYED_MSG un instante y
-- lo vuelven a oír enseguida). Cuando tú escribes /played, sale en tu chat
-- como siempre y Alfa solo lo anota. Ajuste inicio.jugado.
--
--   Jugado.Datos() -> { total, nivel, promedio, lv } | nil   (segundos, al día)
--   Jugado.Pedir()   lo pide sin chat (fuera de combate)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local num = M.num

local type, pcall, ipairs = type, pcall, ipairs

local J = {}
M.Jugado = J

local function db() return N.DatosPersonaje("inicio") end
local function ahora() return time and time() or 0 end
local function encendido() return N.Get("inicio", "jugado") ~= false end

local medidaSesion = false -- 1.3.7: ¿la medida guardada es de esta sesión?
local callados -- los marcos del chat que dejaron de oír la respuesta
local pidio = false

local function devolver()
	if not callados then return end
	for _, f in ipairs(callados) do pcall(f.RegisterEvent, f, "TIME_PLAYED_MSG") end
	callados = nil
end

local function callar()
	callados = {}
	local n = tonumber(rawget(_G, "NUM_CHAT_WINDOWS")) or 10
	for i = 1, n do
		local f = rawget(_G, "ChatFrame" .. i)
		if type(f) == "table" and type(f.IsEventRegistered) == "function" then
			local ok, si = pcall(f.IsEventRegistered, f, "TIME_PLAYED_MSG")
			if ok and si then
				pcall(f.UnregisterEvent, f, "TIME_PLAYED_MSG")
				callados[#callados + 1] = f
			end
		end
	end
end

function J.Pedir()
	if not encendido() or pidio then return false end
	if InCombatLockdown and InCombatLockdown() then
		-- 1.3.7: en plena pelea, al terminarla (antes no se volvía a pedir).
		if N.FueraDeCombate then N.FueraDeCombate("inicio.jugado", J.Pedir) end
		return false
	end
	local f = rawget(_G, "RequestTimePlayed")
	if type(f) ~= "function" then return false end
	pidio = true
	callar()
	local ok = pcall(f)
	if not ok then pidio = false devolver() return false end
	-- Por si la respuesta no llega: el chat vuelve a oírla.
	N.Una("inicio.jugadoDevolver", 5, function() pidio = false devolver() end)
	return true
end

A.RegisterEvent("TIME_PLAYED_MSG", function(_, total, nivel)
	total, nivel = num(total), num(nivel)
	if total then
		local d = db()
		d.jugado = { total = total, nivel = nivel or 0, en = ahora(), lv = num(UnitLevel and UnitLevel("player")) }
		medidaSesion = true
	end
	if pidio then
		pidio = false
		-- El chat vuelve a oírla después de esta respuesta (no la recibe).
		N.Una("inicio.jugadoDevolver", 0.2, devolver)
	end
	A.Fire("INICIO_JUGADO")
end)

-- «3 d 4 h» con más de un día; si no, como todo Alfa («5 h 20 min»).
function J.Corto(seg)
	seg = num(seg) or 0
	if seg >= 86400 then
		return string.format(L["%d d %d h"], math.floor(seg / 86400), math.floor(seg % 86400 / 3600))
	end
	return N.Duracion(seg, true)
end

function J.Datos()
	local j = db().jugado
	if type(j) ~= "table" or not num(j.total) then return nil end
	-- 1.3.7: solo se suma lo que pasó desde una medida de esta sesión (desde
	-- una de otra sesión se sumaba también el tiempo desconectado).
	local pasado = medidaSesion and math.max(0, ahora() - (num(j.en) or ahora())) or 0
	local lv = num(UnitLevel and UnitLevel("player")) or num(j.lv) or 1
	local total = j.total + pasado
	local enNivel = (num(j.nivel) or 0) + pasado
	-- Si subiste desde la última medida, lo de este nivel ya no se sabe bien.
	if num(j.lv) and lv ~= j.lv then enNivel = nil end
	local hechos = math.max(1, lv - 1 + (UnitXPMax and (num(UnitXPMax("player")) or 0) > 0 and (num(UnitXP("player")) or 0) / UnitXPMax("player") or 0))
	return { total = total, nivel = enNivel, promedio = total / hechos, lv = lv }
end

A.OnLogin(function() N.Una("inicio.jugado", 12, J.Pedir) end)
A.RegisterEvent("PLAYER_LEVEL_UP", function() N.Una("inicio.jugado", 4, J.Pedir) end)
