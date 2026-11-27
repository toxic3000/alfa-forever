-- Alfa - Curación: «Faltan por revivir», a quién del grupo levantar al terminar la pelea (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Al terminar una pelea en grupo, si conoces un hechizo para revivir
-- (Resurrección, Redención, Espíritu ancestral o, para el druida, Renacer) y
-- alguien de tu grupo quedó caído, un aviso con quiénes faltan y un botón
-- «Revivir a <nombre>» por cada uno (hasta dos). El botón es seguro (K.Seguro:
-- el clic lo hace el juego, como en tu barra): Alfa nunca lanza nada solo.
-- Su macro lleva [@unidad,dead,nocombat]: si ya lo levantaron, o empezó otra
-- pelea, no hace nada.
-- Reglas:
--   * Nada en combate: se revisa 2 s después de salir (N.Una) y fuera de
--     combate (N.FueraDeCombate). En combate el seguro del Kit ya se quitó.
--   * Si tú también estás caído, no (no puedes lanzar). Quien ya tiene una
--     resurrección en camino (UnitHasIncomingResurrection, si el cliente lo
--     trae) o está desconectado no cuenta.
--   * Lo secreto no se lee: un nombre secreto (dentro de mazmorras) sale como
--     «tu compañero»; una muerte que llega secreta no se cuenta.
--   * Una vez por pelea; nada se manda al chat.
-- Ajuste curacion.revivir (sí).
--
--   Rv.Hechizo() -> id, nombre | nil   Rv.Caidos() -> { { unidad, nombre, fantasma } }
--   Rv.Revisar() -> true si avisó   Rv.Macro(unidad, hechizo) -> texto

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local secreto = M.Secreto

local type, ipairs, pcall, format, rawget, tostring = type, ipairs, pcall, string.format, rawget, tostring

local Rv = {}
M.Revivir = Rv

M.AJUSTES.revivir = true -- «Faltan por revivir» al terminar una pelea en grupo

Rv.BOTONES = 2
-- En orden: los que reviven fuera de combate primero; Renacer (el del druida) al final.
Rv.HECHIZOS = { "resurreccion", "redencion", "espirituAncestral", "renacer" }

local function leer(v) if secreto(v) then return nil end return v end
local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function enCombate()
	if InCombatLockdown and InCombatLockdown() then return true end
	return leer(llamar(UnitAffectingCombat, "player")) == true
end
local function activo() return N.Get(ID, "revivir") ~= false end

-- El hechizo para revivir que sabes: -> id, nombre (en el idioma del cliente)
function Rv.Hechizo()
	for _, clave in ipairs(Rv.HECHIZOS) do
		local id = M.Conocido and M.Conocido(clave)
		if id then
			local nombre = M.NombreHechizo(id)
			if type(nombre) == "string" and nombre ~= "" then return id, nombre, clave end
		end
	end
	return nil
end

-- Las unidades de tu grupo o banda (sin ti).
local function unidades()
	local out = {}
	local n = leer(llamar(GetNumGroupMembers)) or 0
	if type(n) ~= "number" or n <= 1 then return out end
	local banda = leer(llamar(IsInRaid)) == true
	if banda then
		for i = 1, n do
			local u = "raid" .. i
			if leer(llamar(UnitIsUnit, u, "player")) ~= true then out[#out + 1] = u end
		end
	else
		for i = 1, n - 1 do out[#out + 1] = "party" .. i end
	end
	return out
end

-- Quiénes de tu grupo están caídos y se pueden revivir.
function Rv.Caidos()
	local out = {}
	local entrante = rawget(_G, "UnitHasIncomingResurrection")
	for _, u in ipairs(unidades()) do
		if leer(llamar(UnitExists, u)) == true and leer(llamar(UnitIsDeadOrGhost, u)) == true
			and leer(llamar(UnitIsConnected, u)) ~= false and leer(llamar(entrante, u)) ~= true then
			local nombre = leer(llamar(UnitName, u))
			if type(nombre) ~= "string" or nombre == "" then nombre = nil end
			out[#out + 1] = { unidad = u, nombre = nombre, fantasma = leer(llamar(UnitIsGhost, u)) == true }
		end
	end
	-- Los que siguen junto a su cuerpo primero (los que soltaron su espíritu tardan más en volver).
	table.sort(out, function(a, b)
		if a.fantasma ~= b.fantasma then return not a.fantasma end
		return a.unidad < b.unidad
	end)
	return out
end

function Rv.Macro(unidad, hechizo)
	return "/cast [@" .. unidad .. ",dead,nocombat] " .. hechizo
end

local function nombreDe(c) return c.nombre or L["tu compañero"] end

local avisado = false -- una vez por pelea

function Rv.Revisar()
	if not activo() or enCombate() then return false end
	if leer(llamar(UnitIsDeadOrGhost, "player")) == true then return false end
	local id, hechizo, clave = Rv.Hechizo()
	if not id then return false end
	local caidos = Rv.Caidos()
	if #caidos == 0 then return false end
	local acciones = {}
	for i = 1, math.min(Rv.BOTONES, #caidos) do
		local c = caidos[i]
		acciones[i] = { texto = format(L["Revivir a %s"], nombreDe(c)), seguro = { type = "macro", macrotext = Rv.Macro(c.unidad, hechizo) } }
	end
	local nombres = {}
	for i, c in ipairs(caidos) do
		if i > 4 then break end
		nombres[#nombres + 1] = nombreDe(c)
	end
	local lista = table.concat(nombres, ", ")
	if #caidos > 4 then lista = lista .. " " .. format(L["y %d más"], #caidos - 4) end
	local titulo = #caidos == 1 and format(L["%s quedó caído"], nombreDe(caidos[1])) or format(L["Faltan por revivir: %d"], #caidos)
	local texto = #caidos == 1 and format(L["Tu %s lo levanta."], hechizo) or format(L["%s. Tu %s los levanta."], lista, hechizo)
	if clave == "renacer" then texto = texto .. " " .. L["Renacer tiene una recarga larga: guárdalo para quien más falta hace."] end
	avisado = true
	K.Aviso({ id = "curacion.revivir", titulo = titulo, texto = texto, icono = "ic-curacion", tono = "aviso",
		duracion = 20, acciones = acciones, prioridad = 2, agrupar = false })
	return true
end

A.RegisterEvent("PLAYER_REGEN_DISABLED", function() avisado = false end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if avisado or not activo() then return end
	N.Una("curacion.revivir", 2, function() N.FueraDeCombate("curacion.revivir", Rv.Revisar) end)
end)

A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
		pcall(Lya.Ensenar, { id = "curacion.revivir", icono = "ic-curacion", modulo = ID,
			pregunta = L["¿A quién me falta revivir?"],
			respuesta = L["Si sabes revivir, al terminar una pelea en grupo Alfa te dice quién quedó caído, con un botón para revivir a cada uno. El clic es tuyo: Alfa nunca lanza nada solo."] })
	end
end)
