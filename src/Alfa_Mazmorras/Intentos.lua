-- Alfa - Mazmorras: los intentos contra cada jefe (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Cuando el grupo cae ante un jefe, un aviso con el número de intento y lo
-- que más importa de esa pelea para tu papel (de sus consejos, como la
-- tarjeta en vivo, EnVivo.lua), con «Ver sus consejos». Cuando por fin lo
-- vencen después de caer, «¡Lo vencieron al intento 3!». La tarjeta en vivo
-- del jefe dice en qué intento van (Iv.EnVuelta).
-- De dónde sale: ENCOUNTER_START y ENCOUNTER_END del juego (su id de
-- encuentro y si se ganó); el jefe, de los datos de la mazmorra (D.Jefes).
-- Reglas:
--   * Un valor secreto no se lee: si el juego oculta si se ganó, no cuenta.
--   * Nada en combate: se cuenta y se avisa fuera de combate (N.FueraDeCombate).
--   * La cuenta de esta vuelta va en memoria (se olvida tras VUELTA s sin
--     pelear con ese jefe o al cambiar de mazmorra); tu historial por jefe
--     (victorias y caídas) se guarda por personaje: N.DatosPersonaje("mazmorras").intentos.
--   * Nada se manda a nadie.
-- Ajuste mazmorras.intentos (sí).
--
--   Iv.Fin(encId, nombre, gano) -> { key, jefe, intento, gano } | nil
--   Iv.EnVuelta(key, jid) -> caídas en esta vuelta   Iv.Historial(key, jid) -> { victorias, caidas }

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local D = M.D
local K = N.Kit

local Iv = {}
M.Intentos = Iv

local ID = D.ID
A.RegisterDefaults(ID, { intentos = true })

local type, ipairs, pcall, tostring, format, lower = type, ipairs, pcall, tostring, string.format, string.lower

Iv.VUELTA = 2 * 3600 -- segundos sin volver a pelear con ese jefe para que la cuenta empiece de nuevo

local function leer(v) return D.Legible(v) end
local function activo() return N.Get(ID, "intentos") ~= false end
local function ahora() return (time and time()) or 0 end

local vuelta = { key = nil, jefes = {} } -- jid -> { caidas, t }

-- El jefe de un encuentro en la mazmorra donde estás (o nil).
local function jefeDe(key, encId, nombre)
	if not key then return nil end
	local jefes = D.Jefes(key)
	for _, j in ipairs(jefes) do
		if encId and j.encuentro == encId then return j end
	end
	if type(nombre) == "string" and nombre ~= "" then
		local n = lower(nombre)
		for _, j in ipairs(jefes) do
			if type(j.nombre) == "string" and lower(j.nombre) == n then return j end
		end
	end
	return nil
end

local function historial()
	local p = N.DatosPersonaje(ID)
	if type(p.intentos) ~= "table" then p.intentos = {} end
	return p.intentos
end

function Iv.Historial(key, jid)
	local h = historial()[tostring(key) .. ":" .. tostring(jid)]
	return type(h) == "table" and h or nil
end

-- Cuántas veces cayeron ante ese jefe en esta vuelta.
function Iv.EnVuelta(key, jid)
	if vuelta.key ~= key then return 0 end
	local x = vuelta.jefes[tostring(jid)]
	if type(x) ~= "table" then return 0 end
	if ahora() - (x.t or 0) > Iv.VUELTA then vuelta.jefes[tostring(jid)] = nil return 0 end
	return x.caidas or 0
end

-- Lo más importante de la pelea para tu papel (EnVivo.lua) o nil.
local function consejo(jefe)
	local Ev = M.EnVivo
	if not (Ev and type(jefe) == "table" and jefe.consejos) then return nil end
	local ok, papel = pcall(Ev.Papel)
	if not ok then return nil end
	local ok2, c = pcall(Ev.LoMasImportante, jefe, papel)
	return ok2 and type(c) == "string" and c or nil
end

function Iv.Fin(encId, nombre, gano)
	local key = D.MazmorraActual()
	if not key then return nil end
	local jefe = jefeDe(key, encId, nombre)
	local jid = jefe and jefe.id or (encId and ("e" .. tostring(encId))) or nil
	if not jid then return nil end
	local nombreJefe = (jefe and type(jefe.nombre) == "string" and jefe.nombre) or (type(nombre) == "string" and nombre) or L["el jefe"]
	if vuelta.key ~= key then vuelta = { key = key, jefes = {} } end
	local antes = Iv.EnVuelta(key, jid)
	local h = historial()
	local clave = key .. ":" .. tostring(jid)
	local x = type(h[clave]) == "table" and h[clave] or { victorias = 0, caidas = 0 }
	h[clave] = x
	local r = { key = key, jefe = jefe, nombre = nombreJefe, gano = gano and true or false }
	if gano then
		x.victorias = (x.victorias or 0) + 1
		r.intento = antes + 1
		vuelta.jefes[tostring(jid)] = nil
	else
		x.caidas = (x.caidas or 0) + 1
		r.intento = antes + 1
		vuelta.jefes[tostring(jid)] = { caidas = antes + 1, t = ahora() }
	end
	if activo() then Iv.Avisar(r) end
	return r
end

function Iv.Avisar(r)
	if type(r) ~= "table" or not (K and K.Aviso) then return false end
	if r.gano then
		if (r.intento or 1) <= 1 then return false end
		K.Aviso({ id = "mazmorras.intentos", titulo = format(L["¡Vencieron a %s al intento %d!"], r.nombre, r.intento),
			texto = L["La manada no se rinde."], icono = "ic-mazmorra", tono = "exito", duracion = 8, detalle = true })
		return true
	end
	local lineas = { format(L["Van %d intentos. Respiren, esperen a que todos tengan maná y vuelvan."], r.intento) }
	if r.intento == 1 then lineas[1] = L["Primer intento. Respiren, esperen a que todos tengan maná y vuelvan."] end
	local c = consejo(r.jefe)
	if c then lineas[#lineas + 1] = format(L["Lo que más importa: %s"], c) end
	local key = r.key
	K.Aviso({ id = "mazmorras.intentos", titulo = format(L["Cayeron ante %s"], r.nombre), texto = table.concat(lineas, "\n"),
		icono = "ic-mazmorra", tono = "aviso", duracion = 14, prioridad = 2, agrupar = false,
		acciones = { { texto = L["Ver sus consejos"], alClic = function()
			if M.V and M.V.AbrirMazmorra then M.V.AbrirMazmorra(key, "jefes") end
		end } } })
	return true
end

A.RegisterEvent("ENCOUNTER_END", function(_, encId, nombre, _, _, exito)
	encId, nombre, exito = leer(encId), leer(nombre), leer(exito)
	if exito == nil then return end -- secreto (o el juego no lo dice): no cuenta
	encId = tonumber(encId)
	local gano = exito == 1 or exito == true
	if type(nombre) ~= "string" then nombre = nil end
	N.FueraDeCombate("mazmorras.intentos", function() pcall(Iv.Fin, encId, nombre, gano) end)
end)

A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	-- Otra mazmorra (o ninguna): la cuenta de la vuelta se queda solo si vuelves a la misma.
	local key = D.MazmorraActual and D.MazmorraActual()
	if key and vuelta.key and key ~= vuelta.key then vuelta = { key = key, jefes = {} } end
end)

if A.OnLogin then
	A.OnLogin(function()
		local Lya = rawget(_G, "AlfaLya")
		if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
			pcall(Lya.Ensenar, { id = "mazmorras.intentos", icono = "ic-mazmorra", modulo = "mazmorras",
				pregunta = L["Caímos ante el jefe, ¿y ahora?"],
				respuesta = L["Alfa lleva la cuenta de los intentos contra cada jefe y te dice lo que más importa de esa pelea para tu papel. Respiren, esperen el maná y vuelvan."] })
		end
	end)
end
