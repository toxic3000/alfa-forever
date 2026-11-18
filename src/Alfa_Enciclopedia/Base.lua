-- Alfa - Enciclopedia: lo común (toxic3000 / La Jauría). GPL-3.0.
--
-- Los datos son los del motor (Alfa_Codex, Alfa_ItemDB y las funciones de
-- Lookup): aquí no se copia nada, solo se lee y se pone en palabras de Alfa.
--   M.Codex() -> Codex | nil, motivo     carga el Codex (nunca en combate)
--   M.Tarea(nombre, paso, fin)           trabajo por lotes en segundo plano
--   M.Nombre(kind, id), M.Zona(map), M.Coords(x, y), M.Porcentaje(p)
--   M.TIPOS, M.PROFESIONES, M.ROLES, M.RAZAS: los nombres que muestra Alfa

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
M.N, M.A, M.K = N, A, N.Kit
M.L = N.Textos(M.EN)
M.ID = "enciclopedia"

local L = M.L
local type, tonumber, tostring, ipairs, pairs, pcall = type, tonumber, tostring, ipairs, pairs, pcall
local floor, format, max = math.floor, string.format, math.max

M.DOT = "  \194\183  "
M.SEP = " \194\183 "

---------------------------------------------------------------------------
-- El Codex: se carga la primera vez que abres la enciclopedia (nunca al
-- iniciar sesión ni en combate).
---------------------------------------------------------------------------
function M.Codex()
	local C = A.Codex
	if type(C) ~= "table" or type(C.IsLoaded) ~= "function" then return nil, "missing" end
	if C.IsLoaded() then return C end
	if InCombatLockdown() then return nil, "combat" end
	local ok, motivo = C.Load()
	if ok and C.IsLoaded() then return C end
	return nil, motivo or "missing"
end

-- El Codex ya cargado, sin intentar cargarlo.
function M.CodexListo()
	local C = A.Codex
	if type(C) == "table" and type(C.IsLoaded) == "function" and C.IsLoaded() then return C end
	return nil
end

-- Por qué no hay datos, en palabras del jugador.
function M.MotivoTexto(motivo)
	if motivo == "combat" then return L["Se abre al salir de combate."] end
	if motivo == "disabled" then return L["El paquete de datos de Alfa (Alfa_Codex) está desactivado: actívalo en la lista de addons y recarga."] end
	if motivo == "missing" or motivo == "MISSING" then return L["Falta el paquete de datos de Alfa (Alfa_Codex): vuelve a instalar Alfa completo."] end
	if motivo == "loading" then return L["Cargando los datos…"] end
	return format(L["Los datos de Alfa no cargaron (%s)."], tostring(motivo or "?"))
end

---------------------------------------------------------------------------
-- Trabajo por lotes: cada paso hace un poco y devuelve true al terminar. Se
-- corre en el siguiente cuadro (C_Timer), unos milisegundos por cuadro, y se
-- detiene en combate (sigue al salir).
---------------------------------------------------------------------------
local cola = {}
local programado, pausado = false, false
local PRESUPUESTO = 7   -- ms por cuadro
local MAX_PASOS = 40    -- pasos por cuadro si el reloj no responde

local function reloj()
	local f = debugprofilestop
	if type(f) ~= "function" then return nil end
	local ok, v = pcall(f)
	return ok and type(v) == "number" and v or nil
end

local tick
local function programar()
	if programado or #cola == 0 then return end
	programado = true
	C_Timer.After(0, tick)
end

tick = function()
	programado = false
	if InCombatLockdown() then pausado = true return end
	local t0 = reloj()
	local pasos = 0
	while #cola > 0 do
		local t = cola[1]
		local ok, listo = pcall(t.paso)
		if not ok then
			if geterrorhandler then geterrorhandler()(listo) end
			listo, t.fallo = true, true
		end
		if listo then
			table.remove(cola, 1)
			M.tareas[t.nombre] = nil
			if t.fin then for _, fn in ipairs(t.fin) do M.K.Llamar(fn, not t.fallo) end end
		end
		pasos = pasos + 1
		local ahora = reloj()
		if t0 and ahora then
			if ahora - t0 >= PRESUPUESTO then break end
		elseif pasos >= MAX_PASOS then
			break
		end
	end
	programar()
end

M.tareas = {} -- nombre -> tarea en la cola

-- nombre: una sola a la vez por nombre (pedirla otra vez suma su `fin`).
function M.Tarea(nombre, paso, fin)
	local t = M.tareas[nombre]
	if t then
		if fin then t.fin[#t.fin + 1] = fin end
		return t
	end
	t = { nombre = nombre, paso = paso, fin = { fin } }
	M.tareas[nombre] = t
	cola[#cola + 1] = t
	programar()
	return t
end

function M.Corriendo(nombre) return M.tareas[nombre] ~= nil end

A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if pausado then
		pausado = false
		programar()
	end
end)

---------------------------------------------------------------------------
-- Nombres y lugares (en el idioma del cliente cuando el motor lo sabe)
---------------------------------------------------------------------------
local GRUPO_NOMBRE = { item = "item", mount = "item", pet = "item", recipe = "item", tabard = "item",
	npc = "npc", rare = "npc", object = "object", treasure = "object", quest = "quest" }

-- Las guías propias (Coleccion.lua, Legado.lua): kind "guia", id -> nombre.
M.GUIAS = {}

function M.Nombre(kind, id)
	if id == nil then return "?" end
	if kind == "zone" then return M.Zona(id) or tostring(id) end
	if kind == "guia" then return M.GUIAS[id] or tostring(id) end
	local C = M.CodexListo()
	if not C then return tostring(id) end
	if kind == "mountspell" then
		-- Una montura que es un hechizo (de clase, o del diario de monturas).
		local s = C.Spell(id)
		local nombre = s and s.name
		if not nombre and M.Col and M.Col.NombreDiario then nombre = M.Col.NombreDiario(id) end
		return nombre or tostring(id)
	end
	if kind == "instance" then
		local inst = C.Instance(id)
		return inst and inst.name or tostring(id)
	end
	if kind == "faction" then
		local f = C.Faction(id)
		return f and f.name or tostring(id)
	end
	return C.Name(GRUPO_NOMBRE[kind] or kind, id) or tostring(id)
end

function M.Zona(map)
	if not map then return nil end
	local Cp = A.Compat
	local ok, n = pcall(Cp.MapName, map)
	if ok and type(n) == "string" and n ~= "" then return n end
	return nil
end

-- 48.1, 80.5 -> "48,1 · 80,5" (con punto en inglés)
local DEC = N.espanol and "," or "."
local function decimal(v, cifras)
	local s = format(cifras == 2 and "%.2f" or "%.1f", tonumber(v) or 0)
	if DEC ~= "." then s = s:gsub("%.", DEC) end
	return s
end
M.Decimal = decimal

function M.Coords(x, y)
	if not (x and y) then return nil end
	return decimal(x) .. "  " .. decimal(y)
end

-- "Durotar (48,1  80,5)"
function M.Lugar(map, x, y)
	local z = M.Zona(map)
	local c = M.Coords(x, y)
	if z and c then return z .. " (" .. c .. ")" end
	return z or c
end

-- Mayúsculas que respetan los acentos (string.upper no toca á, é, ñ...).
local MAYUS = {
	["\195\161"] = "\195\129", ["\195\169"] = "\195\137", ["\195\173"] = "\195\141", ["\195\179"] = "\195\147",
	["\195\186"] = "\195\154", ["\195\177"] = "\195\145", ["\195\188"] = "\195\156",
}
function M.Mayus(s)
	if s == nil then return nil end
	s = tostring(s):upper()
	return (s:gsub("\195[\161\169\173\179\186\177\188]", MAYUS))
end

function M.Porcentaje(p)
	p = tonumber(p)
	if not p then return nil end
	local s
	if p >= 10 then s = tostring(floor(p + 0.5))
	elseif p >= 1 then s = decimal(p)
	else s = format("%.2f", p):gsub("0+$", ""):gsub("%.$", "") if DEC ~= "." then s = s:gsub("%.", DEC) end end
	return s .. " %"
end

-- 12345 -> "12 345"
function M.Miles(n)
	local s = tostring(floor(tonumber(n) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^ ", ""))
end

-- El color de una calidad, legible sobre los paneles.
function M.ColorCalidad(q)
	local r, g, b = M.K.ColorDeCalidad(q)
	if not r then return nil end
	local T = A.Theme
	if T and type(T.Legible) == "function" then
		local ok, lr, lg, lb = pcall(T.Legible, r, g, b)
		if ok and lr then return lr, lg, lb end
	end
	return r, g, b
end

local CALIDAD = { [0] = L["Pobre"], [1] = L["Común"], [2] = L["Poco común"], [3] = L["Raro"], [4] = L["Épico"], [5] = L["Legendario"], [6] = L["Artefacto"] }
function M.NombreCalidad(q)
	local s = A.QualityName and A.QualityName(q)
	if type(s) == "string" and s ~= "" then return s end
	return CALIDAD[q]
end

function M.NombreReputacion(n)
	local s = A.StandingName and A.StandingName(n)
	if type(s) == "string" and s ~= "" then return s end
	return n and format(L["Nivel %d"], n) or nil
end

-- "A" | "H" -> nombre del bando
function M.NombreBando(f)
	if f == "A" or f == "Alliance" then return L["Alianza"] end
	if f == "H" or f == "Horde" then return L["Horda"] end
	return nil
end

-- El bando del jugador: "A" | "H" | nil
function M.MiBando()
	local f = A.Compat.GetPlayerFaction()
	return f == "Alliance" and "A" or f == "Horde" and "H" or nil
end

function M.MiNivel()
	local ok, p = pcall(A.Compat.GetPlayerInfo)
	return ok and p and tonumber(p.level) or 1
end

---------------------------------------------------------------------------
-- Tipos de la enciclopedia
---------------------------------------------------------------------------
M.TIPOS = {
	{ clave = "objeto", texto = L["Objetos"], icono = "ic-bolsas", kinds = { "item", "mount", "pet", "recipe", "tabard" },
		descripcion = L["Armas, armaduras, materiales, recetas y monturas: quién los suelta y quién los vende."] },
	{ clave = "montura", texto = L["Monturas"], icono = "ic-huella", kinds = { "mount" },
		descripcion = L["Todas las monturas: cómo se consigue cada una, qué pide y si ya la tienes."] },
	{ clave = "mascota", texto = L["Mascotas"], icono = "ic-lobo", kinds = { "pet" },
		descripcion = L["Todas las mascotas de compañía: dónde salen, cuánto cuestan y cuáles te faltan."] },
	{ clave = "pnj", texto = L["PNJ"], icono = "ic-personajes", kinds = { "npc" },
		descripcion = L["Dónde está cada uno, lo que vende, lo que suelta y sus misiones."] },
	{ clave = "mision", texto = L["Misiones"], icono = "ic-misiones", kinds = { "quest" },
		descripcion = L["Quién la da, qué pide, qué te dan y qué necesitas antes."] },
	{ clave = "zona", texto = L["Zonas"], icono = "ic-mapa", kinds = { "zone" },
		descripcion = L["Niveles, misiones, raros, mazmorras y servicios de cada zona."] },
	{ clave = "raro", texto = L["Raros"], icono = "ic-raros", kinds = { "rare", "treasure" },
		descripcion = L["Criaturas raras y tesoros: dónde aparecen y lo que sueltan."] },
}
M.TIPO = {}
M.TIPO_DE_KIND = {}
for _, t in ipairs(M.TIPOS) do
	M.TIPO[t.clave] = t
	-- Las monturas y mascotas también están en Objetos, pero se abren en su tipo.
	for _, k in ipairs(t.kinds) do M.TIPO_DE_KIND[k] = t.clave end
end
M.TIPO_DE_KIND.mountspell = "montura"
M.ES_OBJETO = { item = true, mount = true, pet = true, recipe = true, tabard = true }

-- Lo que pide quien abre la enciclopedia (los tipos del motor y los de Alfa).
local ALIAS = {
	item = "item", objeto = "item", mount = "mount", montura = "mount", pet = "pet", mascota = "pet",
	recipe = "recipe", receta = "recipe", tabard = "tabard", tabardo = "tabard",
	npc = "npc", pnj = "npc", quest = "quest", mision = "quest", ["misión"] = "quest",
	zone = "zone", zona = "zone", rare = "rare", raro = "rare", treasure = "treasure", tesoro = "treasure",
	object = "object", instance = "instance", mazmorra = "instance", dungeon = "instance",
	mountspell = "mountspell", guia = "guia",
}
function M.KindDe(tipo) return type(tipo) == "string" and ALIAS[tipo:lower()] or nil end

---------------------------------------------------------------------------
-- Palabras del juego en las de Alfa
---------------------------------------------------------------------------
M.PROFESIONES = {
	[171] = L["Alquimia"], [164] = L["Herrería"], [333] = L["Encantamiento"], [202] = L["Ingeniería"],
	[182] = L["Herboristería"], [165] = L["Peletería"], [186] = L["Minería"], [393] = L["Desuello"],
	[197] = L["Sastrería"], [185] = L["Cocina"], [356] = L["Pesca"], [129] = L["Primeros auxilios"],
}

function M.NombreProfesion(linea)
	if M.PROFESIONES[linea] then return M.PROFESIONES[linea] end
	local Lk = A.Lookup
	local n = Lk and Lk.ProfessionName and Lk.ProfessionName(linea)
	return n or L["Profesión"]
end

local CLASES = {
	WARRIOR = L["Guerrero"], PALADIN = L["Paladín"], HUNTER = L["Cazador"], ROGUE = L["Pícaro"], PRIEST = L["Sacerdote"],
	SHAMAN = L["Chamán"], MAGE = L["Mago"], WARLOCK = L["Brujo"], DRUID = L["Druida"],
}
function M.NombreClase(archivo)
	local s = type(LOCALIZED_CLASS_NAMES_MALE) == "table" and LOCALIZED_CLASS_NAMES_MALE[archivo]
	if type(s) == "string" and s ~= "" then return s end
	return CLASES[archivo] or archivo
end

M.RAZAS = {
	Human = L["Humanos"], Orc = L["Orcos"], Dwarf = L["Enanos"], NightElf = L["Elfos de la noche"], Scourge = L["No-muertos"],
	Undead = L["No-muertos"], Tauren = L["Tauren"], Gnome = L["Gnomos"], Troll = L["Trols"], Skyborne = L["Celestes"],
}

-- Los roles de los PNJ (Codex.WithRole) que se filtran y se muestran.
M.ROLES = {
	{ clave = "vendor", texto = L["Vendedores"], uno = L["Vendedor"], icono = "map:vendor" },
	{ clave = "repair", texto = L["Reparación"], uno = L["Repara"], icono = "map:repair" },
	{ clave = "trainer", texto = L["Instructores"], uno = L["Instructor"], icono = "map:trainer-profession" },
	{ clave = "flightmaster", texto = L["Maestros de vuelo"], uno = L["Maestro de vuelo"], icono = "map:flightmaster" },
	{ clave = "innkeeper", texto = L["Posaderos"], uno = L["Posadero"], icono = "map:inn" },
	{ clave = "banker", texto = L["Banqueros"], uno = L["Banquero"], icono = "map:bank" },
	{ clave = "auctioneer", texto = L["Subastadores"], uno = L["Subastador"], icono = "map:auction" },
	{ clave = "stablemaster", texto = L["Maestros de establos"], uno = L["Maestro de establos"], icono = "map:stable" },
	{ clave = "battlemaster", texto = L["Maestros de batalla"], uno = L["Maestro de batalla"], icono = "map:battlemaster" },
	{ clave = "spirithealer", texto = L["Ángeles de la resurrección"], uno = L["Ángel de la resurrección"], icono = "map:ankh" },
	{ clave = "weapon", texto = L["Maestros de armas"], uno = L["Maestro de armas"], icono = "map:trainer-weapon" },
}
M.ROL = {}
for _, r in ipairs(M.ROLES) do M.ROL[r.clave] = r end

-- El nombre de un rol del Codex ("trainer:197", "class:MAGE", "sells:food").
function M.NombreRol(rol)
	if type(rol) ~= "string" then return nil end
	if M.ROL[rol] then return M.ROL[rol].uno end
	local linea = rol:match("^trainer:(%d+)$")
	if linea then return format(L["Instructor de %s"], M.NombreProfesion(tonumber(linea))) end
	local clase = rol:match("^class:(%u+)$")
	if clase then return format(L["Instructor de %s"], M.NombreClase(clase)) end
	return nil
end

-- Una fila de un índice inverso guarda objeto y probabilidad en un número:
-- id * 10000 + probabilidad en centésimas (0: no se sabe). Tope 99,99: el
-- 100 % (10000) se comería el id (se leería como el objeto siguiente).
function M.Empacar(id, p)
	p = tonumber(p)
	local c = p and p > 0 and floor(math.min(p, 99.99) * 100 + 0.5) or 0
	return id * 10000 + c
end
function M.Desempacar(v)
	local id = floor(v / 10000)
	local c = v % 10000
	return id, c > 0 and c / 100 or nil
end

function M.num(v, d) return type(v) == "number" and v or (d or 0) end
