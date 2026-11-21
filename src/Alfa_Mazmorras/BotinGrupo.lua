-- Alfa - Mazmorras: el botín de tu grupo, con su historial (1.3.7).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- En una mazmorra o una banda con grupo, quién se llevó qué y con qué
-- tirada: se leen los mensajes del botín que el juego ya pone en tu chat
-- (CHAT_MSG_LOOT con los textos del propio cliente: LOOT_ROLL_ROLLED_*,
-- LOOT_ROLL_WON, LOOT_ROLL_YOU_WON, LOOT_ITEM...). Nada se anuncia ni se
-- manda a nadie: es solo tu cuaderno, en la página Mazmorras > Tu progreso.
-- Solo objetos de calidad poco común o mejor. Un texto secreto no se lee.
--
-- Por personaje: N.DatosPersonaje("mazmorras").historial =
--   { { t, k (mazmorra), id, link, quien, tirada, tipo ("necesidad" | "codicia" | "desencantar" | nil) }, ... }
-- (lo más nuevo al final, hasta MAX). Ajuste: mazmorras.historial (sí).
--
--   Hb.Lista(n) -> lo más nuevo primero ; Hb.Leer(texto) -> entrada | nil ; Hb.Borrar()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local D = M.D

local type, ipairs, pairs, tonumber, tostring, pcall = type, ipairs, pairs, tonumber, tostring, pcall
local match, find, lower = string.match, string.find, string.lower

local Hb = {}
M.Historial = Hb

local ID = D.ID
local MAX = 100
local REPETIDO = 15 -- s: «X ganó» y luego «X recibe botín» del mismo objeto son uno

local function activo() return N.Get(ID, "historial") ~= false end

local function datos()
	local d = N.DatosPersonaje(ID)
	if type(d.historial) ~= "table" then d.historial = {} end
	return d.historial
end

-- La calidad por el color del enlace (sin preguntarle al servidor).
local CALIDAD = { ["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5, e6cc80 = 6 }
local function calidad(link)
	local hex = type(link) == "string" and match(link, "|c%x%x(%x%x%x%x%x%x)")
	return hex and CALIDAD[lower(hex)] or nil
end
Hb.Calidad = calidad

-- Los textos del juego, como patrones con el orden de sus huecos.
local formas
local function armar()
	formas = {}
	local function poner(global, tipo, campos)
		local p, orden = D.PatronOrden(rawget(_G, global))
		if p then formas[#formas + 1] = { p = p, orden = orden, tipo = tipo, campos = campos } end
	end
	-- "Need Roll - %d for %s by %s"
	poner("LOOT_ROLL_ROLLED_NEED", "necesidad", { "tirada", "link", "quien" })
	poner("LOOT_ROLL_ROLLED_GREED", "codicia", { "tirada", "link", "quien" })
	poner("LOOT_ROLL_ROLLED_DE", "desencantar", { "tirada", "link", "quien" })
	-- "You won: %s" / "%s won: %s" (1.3.7: los tuyos primero; si no, en inglés
	-- «You won: X» entraba con quien = "You" y luego otra vez con tu nombre)
	poner("LOOT_ROLL_YOU_WON", "gane", { "link" })
	poner("LOOT_ROLL_WON", "gano", { "quien", "link" })
	-- "You receive loot: %s." / "%s receives loot: %s." (maestro despojador, libre para todos)
	poner("LOOT_ITEM_SELF_MULTIPLE", "recibo", { "link", "n" })
	poner("LOOT_ITEM_SELF", "recibo", { "link" })
	poner("LOOT_ITEM_MULTIPLE", "recibe", { "quien", "link", "n" })
	poner("LOOT_ITEM", "recibe", { "quien", "link" })
end

-- Un texto del chat -> { tipo, quien, link, tirada } | nil
function Hb.Leer(texto)
	if type(texto) ~= "string" or D.Legible(texto) == nil then return nil end
	if not formas or #formas == 0 then armar() end
	for _, f in ipairs(formas) do
		local c = { match(texto, f.p) }
		if c[1] then
			local r = { tipo = f.tipo }
			for i, v in ipairs(c) do
				local campo = f.campos[f.orden[i] or i]
				if campo then r[campo] = v end
			end
			if r.tirada then r.tirada = tonumber(r.tirada) end
			if type(r.link) == "string" and find(r.link, "|Hitem:", 1, true) then return r end
		end
	end
	return nil
end

local function miNombre()
	local n = UnitName and D.Legible(UnitName("player"))
	return type(n) == "string" and n or "?"
end

local tiradas = {} -- link -> { [quien] = { tirada, tipo } } (de este objeto, hasta que alguien lo gane)

local function anotar(link, quien, tirada, tipo)
	local id = tonumber(match(link, "|Hitem:(%d+)"))
	if not id then return end
	local q = calidad(link)
	if q and q < 2 then return end
	local h = datos()
	local t = D.Ahora()
	-- El mismo objeto para la misma persona, recién anotado: es el mismo.
	for i = #h, math.max(1, #h - 5), -1 do
		local e = h[i]
		if e.id == id and e.quien == quien and t - (e.t or 0) < REPETIDO then
			if tirada and not e.tirada then e.tirada, e.tipo = tirada, tipo end
			return
		end
	end
	h[#h + 1] = { t = t, k = D.MazmorraActual(), id = id, link = link, quien = quien, tirada = tirada, tipo = tipo }
	while #h > MAX do table.remove(h, 1) end
	D.Avisar("historial")
end

local function enGrupoDentro()
	if not (IsInGroup and IsInGroup()) then return false end
	local C = A.Compat
	return C and D.Llamar(C.IsInInstance) and true or false
end

function Hb.Procesar(texto)
	if not activo() or not enGrupoDentro() then return end
	local r = Hb.Leer(texto)
	if not r then return end
	if r.tipo == "necesidad" or r.tipo == "codicia" or r.tipo == "desencantar" then
		tiradas[r.link] = tiradas[r.link] or {}
		if r.quien then tiradas[r.link][r.quien] = { tirada = r.tirada, tipo = r.tipo } end
		return
	end
	local quien = (r.tipo == "gane" or r.tipo == "recibo") and miNombre() or r.quien
	if not quien then return end
	if quien == (rawget(_G, "YOU") or "You") then quien = miNombre() end
	local tir = tiradas[r.link]
	local suya = tir and (tir[quien] or (quien == miNombre() and tir[rawget(_G, "YOU") or "You"]))
	if r.tipo == "gano" or r.tipo == "gane" then tiradas[r.link] = nil end
	anotar(r.link, quien, suya and suya.tirada, suya and suya.tipo)
end

A.RegisterEvent("CHAT_MSG_LOOT", function(_, texto)
	if type(texto) ~= "string" or D.Legible(texto) == nil then return end
	local ok, err = pcall(Hb.Procesar, texto)
	if not ok and geterrorhandler then geterrorhandler()(err) end
end)

function Hb.Lista(n)
	local h = datos()
	local out = {}
	for i = #h, 1, -1 do
		out[#out + 1] = h[i]
		if n and #out >= n then break end
	end
	return out
end

function Hb.Borrar()
	N.DatosPersonaje(ID).historial = {}
	D.Avisar("historial")
end

local TIPO = { necesidad = "Necesidad", codicia = "Codicia", desencantar = "Desencantar" }
-- «Ana · Necesidad 87»
function Hb.Linea(e)
	local partes = { e.quien or "?" }
	if e.tirada then
		partes[#partes + 1] = (TIPO[e.tipo] and L[TIPO[e.tipo]] or L["Tirada"]) .. " " .. tostring(e.tirada)
	elseif e.tipo == nil then
		partes[#partes + 1] = L["sin tirada"]
	end
	return table.concat(partes, " \194\183 ")
end
