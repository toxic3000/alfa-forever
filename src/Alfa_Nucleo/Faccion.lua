-- Alfa - Núcleo: la Horda y la Alianza, cada una por su lado (1.3.8).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Pedido de Toxic: lo que un Alfa comparte (ubicaciones, guaridas, notas,
-- raros, citas, planes...) nunca lo ve la facción contraria.
--
--   N.Faccion() -> "Horde" | "Alliance" | nil      la tuya (nil si el juego aún no dice)
--   N.FaccionLetra(f) -> "H" | "A" | nil            la letra de una facción (sin f, la tuya)
--   N.ConFaccion(texto) -> texto .. "|~H"            la marca al final de un mensaje
--   N.SinFaccion(texto) -> limpio, letra | nil       quita la marca (nil si no traía)
--   N.FaccionDe(remitente) -> "H" | "A" | nil        la de alguien de tu grupo o banda
--   N.FaccionAjena(remitente) -> true                es de tu grupo y de la otra facción
--   N.FiltroFaccion(texto, canal, remitente) -> sigue, limpio
--
-- La marca va como último campo ("|~H" o "|~A"): un Alfa viejo ve un campo
-- de más al final y lo ignora (todos sus mensajes se leen por posición).
-- Al recibir (Eventos.lua, N.PorPrefijo, para todos los prefijos de Alfa):
--   * con marca: solo si es la tuya;
--   * sin marca (un Alfa viejo, o lo que va solo al grupo): solo por PARTY,
--     RAID o GUILD, que ya son de tu facción; un susurro sin marca, solo de
--     alguien de tu grupo que el juego dice que es de tu facción;
--   * de alguien de tu grupo que el juego dice que es de la otra facción
--     (grupos de facciones mezcladas): nunca, traiga la marca que traiga.
-- Lo que va solo a tu grupo (marcadores, la ruta del grupo, Lya, el avance
-- de misiones del motor) no lleva marca: así los Alfa viejos lo siguen
-- entendiendo, y se revisa con la facción que el juego da del remitente.

local _, N = ...

local type, pcall = type, pcall

local LETRAS = { Horde = "H", Alliance = "A" }
local NOMBRES = { H = "Horde", A = "Alliance" }
N.FACCIONES = NOMBRES

local function secreto(v) return N.Secreto and N.Secreto(v) or false end

local mia -- "Horde" | "Alliance": no cambia en la sesión

function N.Faccion()
	if mia then return mia end
	local fn = rawget(_G, "UnitFactionGroup")
	if type(fn) ~= "function" then return nil end
	local ok, f = pcall(fn, "player")
	if not ok or secreto(f) or not LETRAS[f] then return nil end
	mia = f
	return f
end

-- Para el banco (cambiar de personaje sin recargar).
function N.FaccionOlvidar() mia = nil end

function N.FaccionLetra(f)
	if f == nil then f = N.Faccion() end
	if secreto(f) then return nil end
	return LETRAS[f] or (NOMBRES[f] and f) or nil
end

function N.ConFaccion(texto)
	if type(texto) ~= "string" then return texto end
	local l = N.FaccionLetra()
	if not l then return texto end
	return texto .. "|~" .. l
end

function N.SinFaccion(texto)
	if type(texto) ~= "string" or secreto(texto) then return texto, nil end
	local limpio, l = texto:match("^(.*)|~([HA])$")
	if limpio then return limpio, l end
	return texto, nil
end

-- La facción de alguien de tu grupo o banda, como la dice el juego (un
-- nombre de tu grupo sirve de unidad). Fuera de tu grupo, nil.
local function delGrupo(nombre)
	for _, k in ipairs({ "UnitInParty", "UnitInRaid" }) do
		local fn = rawget(_G, k)
		if type(fn) == "function" then
			local ok, si = pcall(fn, nombre)
			if ok and not secreto(si) and si then return true end
		end
	end
	return false
end

function N.FaccionDe(remitente)
	if type(remitente) ~= "string" or secreto(remitente) or remitente == "" then return nil end
	local fn = rawget(_G, "UnitFactionGroup")
	if type(fn) ~= "function" then return nil end
	local amb = rawget(_G, "Ambiguate")
	local nombre = remitente
	if type(amb) == "function" then
		local ok, n = pcall(amb, remitente, "none")
		if ok and type(n) == "string" and not secreto(n) then nombre = n end
	end
	if not delGrupo(nombre) then return nil end
	local ok, f = pcall(fn, nombre)
	if not ok or secreto(f) then return nil end
	return LETRAS[f]
end

function N.FaccionAjena(remitente)
	local suya = N.FaccionDe(remitente)
	local yo = N.FaccionLetra()
	return suya ~= nil and yo ~= nil and suya ~= yo
end

-- Los canales que ya son de tu facción (un mensaje sin marca se acepta).
local PROPIOS = { PARTY = true, RAID = true, GUILD = true }
N.CANALES_DE_FACCION = PROPIOS

N.faccionDiag = { aceptados = 0, ajenos = 0, sinMarca = 0 }

function N.FiltroFaccion(texto, canal, remitente)
	if type(texto) ~= "string" or secreto(texto) or secreto(canal) or secreto(remitente) then return false end
	local d = N.faccionDiag
	local limpio, marca = N.SinFaccion(texto)
	local yo = N.FaccionLetra()
	local suya = N.FaccionDe(remitente)
	if suya and yo and suya ~= yo then
		d.ajenos = d.ajenos + 1
		return false
	end
	if marca then
		if yo then
			if marca ~= yo then d.ajenos = d.ajenos + 1 return false end
		elseif not PROPIOS[canal] then
			return false -- sin saber la tuya, solo lo que ya es de tu facción
		end
		d.aceptados = d.aceptados + 1
		return true, limpio
	end
	-- Un susurro sin marca (de un Alfa 1.3.7) pasa: en este cliente el
	-- susurro no cruza facciones, y si la del remitente se sabía ajena ya se
	-- rechazó arriba.
	if PROPIOS[canal] or canal == "WHISPER" then
		d.sinMarca = d.sinMarca + 1
		return true, limpio
	end
	d.ajenos = d.ajenos + 1
	return false
end
