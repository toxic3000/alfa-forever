-- Alfa - Enciclopedia: el catálogo de cada tipo, la búsqueda y los filtros
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- Cada tipo (objetos, PNJ, misiones, zonas, raros) es una tabla de columnas
-- (una tabla por dato), armada una vez por sesión, por lotes, la primera vez
-- que se abre la enciclopedia, a partir del índice de nombres del Codex.
-- Para gastar poca memoria (son unos 38 000 nombres), cada fila guarda:
--   id     el id del Codex
--   nom    " nombre en inglés" o " inglés\1 tu idioma", plegados (sin
--          acentos ni mayúsculas): así se busca en los dos idiomas a la vez
--   q      calidad + 1 (0: no se sabe), +10 si ya no se consigue, +20 sin fuente
--   kinds  el grupo del Codex por tramos ({ desde, hasta, kind }), no por fila
--   orden  las filas por nombre en tu idioma
-- Los objetos suman, en segundo plano, sus facetas: tipo, subtipo y ranura en
-- un número (f) desde el cliente (sin pedir nada al servidor), y el nivel y
-- la profesión desde su registro del Codex.
--
--   Cat.Pedir(tipo, fn(ok, motivo))     arma el catálogo la primera vez
--   Cat.Listo(tipo), Cat.Total(tipo), Cat.Col(tipo), Cat.Kind(c, i), Cat.Calidad(c, i)
--   Cat.Buscar(tipo, texto, filtro, salida) -> salida, pendiente
--   Cat.Contar(texto) -> { [tipo] = n }  cuántos encuentra cada tipo
--   Cat.Facetas(), Cat.Avance(nombre), Cat.Clase(i), Cat.Subtipo(i), Cat.Inv(i), Cat.Req(i)
--   Cat.OpcionesTipo(), Cat.OpcionesSubtipo(clase), Cat.OpcionesRanura()
-- Monturas y mascotas (Coleccion.lua) suman sus filas y columnas al armar
-- (TIPO.completar) y filtran con M.Col.Filtro.

local ADDON, M = ...
local A, L, K = M.A, M.L, M.K
local Cat = {}
M.Cat = Cat

local type, tonumber, tostring, ipairs, pairs, pcall = type, tonumber, tostring, ipairs, pairs, pcall
local floor, max, min, format = math.floor, math.max, math.min, string.format
local find, sub, match = string.find, string.sub, string.match
local sort = table.sort

local MONTURA, MASCOTA = 100, 101 -- tipos propios para lo que el juego no separa

local col = {}      -- tipo -> columnas
local estado = {}   -- tipo -> "armando" | "listo"
local esperan = {}  -- tipo -> { fn, ... }
local avance = {}   -- nombre -> fracción 0..1

function Cat.Avance(nombre) return avance[nombre] end
function Cat.Listo(tipo) return estado[tipo] == "listo" end
function Cat.Col(tipo) return col[tipo] end
function Cat.Total(tipo) local c = col[tipo] return c and c.n or 0 end

local function fold(s)
	local S = A.Search
	if S and type(S.Fold) == "function" then return S.Fold(s) end
	s = (" " .. tostring(s or "")):lower():gsub("[%p%c]", " "):gsub("%s+", " ")
	return s
end
Cat.Plegar = fold

local function localName(kind, id)
	local S = A.Search
	if not (S and type(S.LocalName) == "function") then return nil end
	local ok, n = pcall(S.LocalName, kind, id)
	return ok and type(n) == "string" and n ~= "" and n or nil
end

Cat.NombreLocal = localName

-- El grupo del Codex de la fila i.
local function kindDe(c, i)
	local ks = c.kinds
	for k = 1, #ks do
		local t = ks[k]
		if i <= t[2] then return t[3] end
	end
	return nil
end
Cat.Kind = kindDe

-- La calidad (0..7) o nil, y si ya no se consigue ("r") o no tiene fuente ("n").
function Cat.Calidad(c, i)
	local v = c.q[i] or 0
	local q = v % 10 - 1
	local e = floor(v / 10)
	return q >= 0 and q or nil, e == 1 and "r" or e == 2 and "n" or nil
end

---------------------------------------------------------------------------
-- Armar un catálogo: las líneas del índice del Codex de cada grupo
-- ("\2<plegado>\1<id>,<calidad>,<estado>,<largo>\n"), por lotes.
---------------------------------------------------------------------------
local LINEA = "\2([^\1]*)\1([^,]*),(%d*),(%a?),%d+\n"
local POR_PASO = 700
local ESTADO = { r = 10, n = 20 }

local function terminar(tipo, ok, motivo)
	estado[tipo] = ok and "listo" or nil
	local lista = esperan[tipo] or {}
	esperan[tipo] = nil
	for _, fn in ipairs(lista) do K.Llamar(fn, ok, motivo) end
	if ok and M.alCatalogo then K.Llamar(M.alCatalogo, tipo) end
end

-- El orden de base: por nombre en tu idioma (o en inglés). Se ordenan
-- cadenas (rápido, en C) con el número de fila al final de cada una.
local function ordenar(c)
	local claves = {}
	for i = 1, c.n do
		local s = c.nom[i]
		local corte = find(s, "\1", 2, true)
		claves[i] = (corte and sub(s, corte + 1) or s) .. "\0" .. format("%06d", i)
	end
	sort(claves)
	local orden = {}
	for p = 1, #claves do orden[p] = tonumber(sub(claves[p], -6)) end
	c.orden = orden
end

local function armar(tipo)
	local C = M.CodexListo()
	local t = M.TIPO[tipo]
	local c = { n = 0, id = {}, nom = {}, q = {}, kinds = {} }
	local g, pos, blob = 0, 1, nil
	avance["cat:" .. tipo] = 0
	return function()
		if not C then return true end
		-- El siguiente grupo del Codex.
		while not blob do
			if g > 0 then
				local ks = c.kinds
				local desde = #ks > 0 and ks[#ks][2] + 1 or 1
				if c.n >= desde then ks[#ks + 1] = { desde, c.n, t.kinds[g] } end
			end
			g = g + 1
			local kind = t.kinds[g]
			if not kind then
				-- Un tipo puede sumar filas propias y sus datos (Coleccion.lua).
				if t.completar then t.completar(c, C) end
				ordenar(c)
				col[tipo] = c
				avance["cat:" .. tipo] = 1
				return true
			end
			local b = C.Index(kind)
			if type(b) == "string" then blob, pos = b, 1 end
		end
		local kind = t.kinds[g]
		local hechas = 0
		while hechas < POR_PASO do
			local s, e, plegado, rawId, q, st = find(blob, LINEA, pos)
			if not s then
				blob = nil
				break
			end
			pos = e + 1
			local id = tonumber(rawId)
			if id then
				local n = c.n + 1
				c.n = n
				c.id[n] = id
				local en = " " .. plegado
				local loc = localName(kind, id)
				local lf = loc and fold(loc)
				c.nom[n] = (lf and lf ~= en) and (en .. "\1" .. lf) or en
				c.q[n] = (tonumber(q) or -1) + 1 + (ESTADO[st] or 0)
			end
			hechas = hechas + 1
		end
		avance["cat:" .. tipo] = blob and pos / #blob or avance["cat:" .. tipo]
		return false
	end
end

-- Pide el catálogo de un tipo: fn(ok, motivo) cuando esté (enseguida si ya está).
function Cat.Pedir(tipo, fn)
	if estado[tipo] == "listo" then return K.Llamar(fn, true) end
	local C, motivo = M.Codex()
	if not C then return K.Llamar(fn, false, motivo) end
	esperan[tipo] = esperan[tipo] or {}
	if fn then esperan[tipo][#esperan[tipo] + 1] = fn end
	if estado[tipo] == "armando" then return end
	estado[tipo] = "armando"
	M.Tarea("cat:" .. tipo, armar(tipo), function(ok) terminar(tipo, ok) end)
end

-- La fila de un id en un catálogo (búsqueda lineal: solo al abrir algo).
function Cat.FilaDe(tipo, kind, id)
	local c = col[tipo]
	if not c then return nil end
	for i = 1, c.n do
		if c.id[i] == id and (not kind or kindDe(c, i) == kind) then return i end
	end
	return nil
end

---------------------------------------------------------------------------
-- Facetas de los objetos (en segundo plano)
--   f:   (tipo + 2) * 10000 + (subtipo + 2) * 100 + tipo de inventario
--   req: nivel requerido (false hasta saberlo)
--   skill (disperso): profesión * 1000 + rango que pide
---------------------------------------------------------------------------
local EQUIPO = {
	INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_WAIST = 6,
	INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12,
	INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14, INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16, INVTYPE_2HWEAPON = 17,
	INVTYPE_BAG = 18, INVTYPE_TABARD = 19, INVTYPE_ROBE = 20, INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22,
	INVTYPE_HOLDABLE = 23, INVTYPE_AMMO = 24, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26, INVTYPE_QUIVER = 27, INVTYPE_RELIC = 28,
}
Cat.EQUIPO = EQUIPO

local facetas = { lista = false, nivel = false } -- lista: tipo y ranura; nivel: nivel y profesión
function Cat.Facetas() return facetas end

local function instantaneo(id)
	local f = C_Item and C_Item.GetItemInfoInstant
	if type(f) ~= "function" then return nil end
	local ok, rid, _, _, loc, _, c, s = pcall(f, id)
	if not (ok and rid) then return nil end
	return c, s, EQUIPO[loc] or 0
end

local function itemDB()
	local DB = A.ItemDB
	if not (DB and DB.IsLoaded) then return nil end
	if not DB.IsLoaded() and DB.Load then pcall(DB.Load) end
	return DB.IsLoaded() and DB or nil
end

-- Un objeto suelto (su ficha): tipo, subtipo, ranura y lo que dice la base
-- de objetos del motor (niveles, clases, estadísticas).
function Cat.DatosRapidos(id, kind)
	local cls, sb, iv = instantaneo(id)
	local DB = itemDB()
	local rec = DB and DB.Get(id)
	local rq, il, allow
	if rec then
		cls, sb, iv = cls or rec.class, sb or rec.subclass, (iv and iv > 0) and iv or rec.inv
		rq, il, allow = rec.req, rec.ilvl, rec.allow
	end
	if kind == "mount" then cls, sb = MONTURA, 0
	elseif kind == "pet" then cls, sb = MASCOTA, 0
	elseif kind == "recipe" and not cls then cls = 9 end
	return cls, sb, iv, rq, il, allow, rec
end

local function empacar(cls, sb, iv) return ((cls or -1) + 2) * 10000 + ((sb or -1) + 2) * 100 + (iv or 0) end
function Cat.Clase(i) local c = col.objeto local f = c and c.f and c.f[i] return f and floor(f / 10000) - 2 or -1 end
function Cat.Subtipo(i) local c = col.objeto local f = c and c.f and c.f[i] return f and floor(f / 100) % 100 - 2 or -1 end
function Cat.Inv(i) local c = col.objeto local f = c and c.f and c.f[i] return f and f % 100 or 0 end
function Cat.Req(i) local c = col.objeto return c and c.req and c.req[i] or nil end

local function pasoFacetas()
	local c = col.objeto
	local i = 0
	-- Sin la respuesta del cliente (un cliente viejo o el banco de pruebas),
	-- la base de objetos del motor.
	local sinCliente = not (C_Item and type(C_Item.GetItemInfoInstant) == "function")
	local DB = sinCliente and itemDB() or nil
	c.f, c.req = {}, {}
	avance.facetas = 0
	return function()
		local hasta = min(c.n, i + 1500)
		for j = i + 1, hasta do
			local id, kind = c.id[j], kindDe(c, j)
			local cls, sb, iv = instantaneo(id)
			local rq = false
			if DB then
				local rec = DB.Get(id)
				if rec then cls, sb, iv, rq = rec.class, rec.subclass, rec.inv, rec.req end
			end
			if kind == "mount" then cls, sb = MONTURA, 0
			elseif kind == "pet" then cls, sb = MASCOTA, 0
			elseif kind == "recipe" and not cls then cls = 9 end
			c.f[j] = empacar(cls, sb, iv)
			c.req[j] = rq
		end
		i = hasta
		avance.facetas = c.n > 0 and i / c.n or 1
		return i >= c.n
	end
end

-- El nivel y la profesión, del registro del Codex de cada objeto. Este
-- mismo recorrido arma los índices inversos de Indices.lua (quién lo vende,
-- qué suelta cada quien, qué contiene).
local function pasoRegistros()
	local c = col.objeto
	local C = M.CodexListo()
	local i = 0
	c.skill = {}
	avance.registros = 0
	local I = M.Indices
	if I and I.Empezar then I.Empezar() end
	return function()
		if not C then return true end
		local hasta = min(c.n, i + 120)
		for j = i + 1, hasta do
			local rec = C.Item(c.id[j])
			if rec then
				if not c.req[j] then c.req[j] = rec.reqLevel or 0 end
				if rec.reqSkill then c.skill[j] = rec.reqSkill * 1000 + (rec.reqSkillRank or 0) end
				if I and I.Objeto then I.Objeto(rec) end
			elseif not c.req[j] then
				c.req[j] = 0
			end
		end
		i = hasta
		avance.registros = c.n > 0 and i / c.n or 1
		if i >= c.n then
			if I and I.Terminar then I.Terminar() end
			return true
		end
		return false
	end
end

-- Facetas: tipo y ranura enseguida, nivel y profesión después.
function Cat.PrepararFacetas()
	if facetas.pedidas then return end
	facetas.pedidas = true
	Cat.Pedir("objeto", function(ok)
		if not ok then facetas.pedidas = nil return end
		M.Tarea("facetas", pasoFacetas(), function(bien)
			facetas.lista = bien
			if M.alFacetas then K.Llamar(M.alFacetas, "lista") end
			M.Tarea("registros", pasoRegistros(), function(bien2)
				facetas.nivel = bien2
				if M.alFacetas then K.Llamar(M.alFacetas, "nivel") end
			end)
		end)
	end)
end

---------------------------------------------------------------------------
-- Nombres de tipos, subtipos y ranuras
---------------------------------------------------------------------------
local NOMBRE_TIPO = {
	[0] = L["Consumibles"], [1] = L["Bolsas"], [2] = L["Armas"], [4] = L["Armaduras"], [5] = L["Componentes"],
	[6] = L["Proyectiles"], [7] = L["Materiales"], [9] = L["Recetas"], [11] = L["Carcajs"], [12] = L["De misión"],
	[13] = L["Llaves"], [15] = L["Varios"], [MONTURA] = L["Monturas"], [MASCOTA] = L["Mascotas"],
}

function Cat.NombreTipo(c)
	if NOMBRE_TIPO[c] then return NOMBRE_TIPO[c] end
	local f = C_Item and C_Item.GetItemClassInfo
	if type(f) == "function" and type(c) == "number" and c >= 0 then
		local ok, s = pcall(f, c)
		if ok and type(s) == "string" and s ~= "" then return s end
	end
	return L["Otros"]
end

local SUBTIPO = {
	[2] = { [0] = L["Hacha de una mano"], [1] = L["Hacha de dos manos"], [2] = L["Arco"], [3] = L["Arma de fuego"],
		[4] = L["Maza de una mano"], [5] = L["Maza de dos manos"], [6] = L["Arma de asta"], [7] = L["Espada de una mano"],
		[8] = L["Espada de dos manos"], [10] = L["Bastón"], [13] = L["Arma de puño"], [14] = L["Herramienta"],
		[15] = L["Daga"], [16] = L["Arrojadiza"], [18] = L["Ballesta"], [19] = L["Varita"], [20] = L["Caña de pescar"] },
	[4] = { [0] = L["Misceláneo"], [1] = L["Tela"], [2] = L["Cuero"], [3] = L["Malla"], [4] = L["Placas"],
		[6] = L["Escudo"], [7] = L["Tratado"], [8] = L["Ídolo"], [9] = L["Tótem"] },
	[9] = { [0] = L["Libro"], [1] = L["Peletería"], [2] = L["Sastrería"], [3] = L["Ingeniería"], [4] = L["Herrería"],
		[5] = L["Cocina"], [6] = L["Alquimia"], [7] = L["Primeros auxilios"], [8] = L["Encantamiento"], [9] = L["Pesca"] },
	[6] = { [2] = L["Flechas"], [3] = L["Balas"] },
	[1] = { [0] = L["Bolsa"], [1] = L["Bolsa de almas"], [2] = L["Bolsa de hierbas"], [3] = L["Bolsa de encantamiento"], [4] = L["Bolsa de ingeniería"] },
	[11] = { [2] = L["Carcaj"], [3] = L["Bolsa de munición"] },
}

function Cat.NombreSubtipo(c, s)
	local t = SUBTIPO[c]
	if t and t[s] then return t[s] end
	local f = C_Item and C_Item.GetItemSubClassInfo
	if type(f) == "function" and type(c) == "number" and type(s) == "number" and c >= 0 and s >= 0 then
		local ok, n = pcall(f, c, s)
		if ok and type(n) == "string" and n ~= "" then return n end
	end
	return nil
end

-- Las ranuras del filtro (cada una junta las del juego que se usan igual).
Cat.RANURAS = {
	{ clave = "cabeza", texto = L["Cabeza"], inv = { 1 } }, { clave = "cuello", texto = L["Cuello"], inv = { 2 } },
	{ clave = "hombros", texto = L["Hombros"], inv = { 3 } }, { clave = "espalda", texto = L["Espalda"], inv = { 16 } },
	{ clave = "pecho", texto = L["Pecho"], inv = { 5, 20 } }, { clave = "camisa", texto = L["Camisa"], inv = { 4 } },
	{ clave = "tabardo", texto = L["Tabardo"], inv = { 19 } }, { clave = "munecas", texto = L["Muñecas"], inv = { 9 } },
	{ clave = "manos", texto = L["Manos"], inv = { 10 } }, { clave = "cintura", texto = L["Cintura"], inv = { 6 } },
	{ clave = "piernas", texto = L["Piernas"], inv = { 7 } }, { clave = "pies", texto = L["Pies"], inv = { 8 } },
	{ clave = "dedo", texto = L["Dedo"], inv = { 11 } }, { clave = "abalorio", texto = L["Abalorio"], inv = { 12 } },
	{ clave = "unamano", texto = L["Una mano"], inv = { 13 } }, { clave = "dosmanos", texto = L["Dos manos"], inv = { 17 } },
	{ clave = "principal", texto = L["Mano derecha"], inv = { 21 } }, { clave = "secundaria", texto = L["Mano izquierda"], inv = { 22, 14, 23 } },
	{ clave = "distancia", texto = L["A distancia"], inv = { 15, 25, 26 } }, { clave = "reliquia", texto = L["Reliquia"], inv = { 28 } },
	{ clave = "bolsa", texto = L["Bolsa"], inv = { 18, 27 } }, { clave = "municion", texto = L["Munición"], inv = { 24 } },
}
local RANURA_DE = {}
for _, r in ipairs(Cat.RANURAS) do for _, v in ipairs(r.inv) do RANURA_DE[v] = r end end

function Cat.NombreRanura(inv)
	local r = RANURA_DE[inv]
	return r and r.texto or nil
end

---------------------------------------------------------------------------
-- Las opciones de los filtros (solo lo que hay en el catálogo)
---------------------------------------------------------------------------
function Cat.OpcionesTipo()
	local c = col.objeto
	local out = { { valor = false, texto = L["Todo tipo"] } }
	if not (c and facetas.lista) then return out end
	local cuenta = {}
	for i = 1, c.n do local v = floor(c.f[i] / 10000) - 2 cuenta[v] = (cuenta[v] or 0) + 1 end
	local lista = {}
	for v, n in pairs(cuenta) do if v >= 0 then lista[#lista + 1] = { valor = v, texto = Cat.NombreTipo(v), cuenta = n } end end
	sort(lista, function(a, b) return a.texto < b.texto end)
	for _, o in ipairs(lista) do out[#out + 1] = o end
	return out
end

function Cat.OpcionesSubtipo(clase)
	local c = col.objeto
	local out = { { valor = false, texto = L["Todo subtipo"] } }
	if not (c and facetas.lista and clase) then return nil end
	local cuenta = {}
	for i = 1, c.n do
		local f = c.f[i]
		if floor(f / 10000) - 2 == clase then local s = floor(f / 100) % 100 - 2 cuenta[s] = (cuenta[s] or 0) + 1 end
	end
	local lista = {}
	for s, n in pairs(cuenta) do
		local nombre = s >= 0 and Cat.NombreSubtipo(clase, s)
		if nombre then lista[#lista + 1] = { valor = s, texto = nombre, cuenta = n } end
	end
	sort(lista, function(a, b) return a.texto < b.texto end)
	if #lista < 2 then return nil end -- un solo subtipo: el filtro no sirve
	for _, o in ipairs(lista) do out[#out + 1] = o end
	return out
end

function Cat.OpcionesRanura()
	local c = col.objeto
	local out = { { valor = false, texto = L["Toda ranura"] } }
	if not (c and facetas.lista) then return out end
	local hay = {}
	for i = 1, c.n do local r = RANURA_DE[c.f[i] % 100] if r then hay[r.clave] = true end end
	for _, r in ipairs(Cat.RANURAS) do if hay[r.clave] then out[#out + 1] = { valor = r.clave, texto = r.texto } end end
	return out
end

Cat.NIVELES = {
	{ valor = false, texto = L["Todo nivel"] },
	{ valor = "hasta", texto = L["Hasta mi nivel"] },
	{ valor = "mio", texto = L["Para mi nivel (±3)"] },
	{ valor = "1-10", texto = "1–10", lo = 1, hi = 10 }, { valor = "11-20", texto = "11–20", lo = 11, hi = 20 },
	{ valor = "21-30", texto = "21–30", lo = 21, hi = 30 }, { valor = "31-40", texto = "31–40", lo = 31, hi = 40 },
	{ valor = "41-50", texto = "41–50", lo = 41, hi = 50 }, { valor = "51-60", texto = "51–60", lo = 51, hi = 60 },
}

function Cat.OpcionesCalidad()
	local out = { { valor = false, texto = L["Toda calidad"] } }
	for q = 0, 5 do out[#out + 1] = { valor = q, texto = M.NombreCalidad(q) or tostring(q) } end
	return out
end

local function rangoNivel(clave)
	if not clave then return nil end
	local nivel = M.MiNivel()
	if clave == "mio" then return max(1, nivel - 3), nivel + 3 end
	if clave == "hasta" then return 0, nivel end
	for _, n in ipairs(Cat.NIVELES) do
		if n.valor == clave then return n.lo, n.hi end
	end
	return nil
end
Cat.RangoNivel = rangoNivel

---------------------------------------------------------------------------
-- ¿Lo puede usar tu personaje? Clase y competencia (el motor de equipo),
-- nivel y profesión. Se guarda por sesión y se olvida al subir de nivel o
-- aprender algo.
---------------------------------------------------------------------------
local usable = {}
local info = {}
local habilidades = {}

local function rango(linea)
	local r = habilidades[linea]
	if r == nil then
		r = A.Compat.GetSkillRank(linea) or false
		habilidades[linea] = r
	end
	return r
end

local function puedeUsar(c, i)
	local u = usable[i]
	if u ~= nil then return u end
	u = true
	local nivel = M.MiNivel()
	local f = c.f[i]
	local cls, sb, iv = floor(f / 10000) - 2, floor(f / 100) % 100 - 2, f % 100
	local req = c.req[i] or 0
	if req > nivel then u = false end
	local sk = c.skill and c.skill[i]
	if u and sk then
		local r = rango(floor(sk / 1000))
		if not r or r < sk % 1000 then u = false end
	end
	if u and (cls == 2 or cls == 4) and iv > 0 then
		local G = A.Gear
		if G and G.Usability then
			info.class, info.subclass, info.inv, info.req, info.allow = cls, sb, iv, req, 0
			if G.GetPlayer then pcall(G.GetPlayer) end
			local ok, puede, motivo, desde = pcall(G.Usability, info)
			if ok then
				-- Las cañas de pescar y las herramientas sirven a cualquiera; un
				-- arma que tu clase puede entrenar cuenta como usable.
				local herramienta = cls == 2 and (sb == 20 or sb == 14)
				if not puede and not herramienta and motivo ~= "skill" then u = false end
				if u and type(desde) == "number" and desde > nivel then u = false end
			end
		end
	end
	usable[i] = u
	return u
end
Cat.PuedeUsar = function(i) local c = col.objeto return c and c.f and c.req and puedeUsar(c, i) end

local function olvidar() usable, habilidades = {}, {} end
A.RegisterEvent("PLAYER_LEVEL_UP", olvidar)
A.RegisterEvent("SKILL_LINES_CHANGED", olvidar)

---------------------------------------------------------------------------
-- Buscar. Cada fila tiene un solo texto, " inglés" o " inglés\1 tu idioma":
-- un find por palabra la prueba en los dos idiomas.
---------------------------------------------------------------------------
local ID_EXACTO, EXACTO, PREFIJO, PALABRA, DENTRO, PALABRAS = 6, 5, 4, 3, 2, 1

local function preparar(texto)
	if type(texto) ~= "string" then return nil end
	local s = texto:gsub("^%s+", ""):gsub("%s+$", "")
	if s == "" then return nil end
	local id = tonumber(s:match("^#?(%d+)$"))
	local q = fold(s)
	if q == "" or q == " " then return id and { id = id } or nil end
	local cuerpo = sub(q, 2)
	local palabras
	if find(cuerpo, " ", 1, true) then
		palabras = {}
		for w in cuerpo:gmatch("%S+") do palabras[#palabras + 1] = w end
	end
	return { q = q, cuerpo = cuerpo, corto = #cuerpo < 2, palabras = palabras, id = id,
		qLo = "\1" .. q, preLo = "\1 " .. cuerpo, largo = #q }
end
Cat.Preparar = preparar

-- El nivel de coincidencia de la fila i (0: no coincide).
local function coincide(c, i, p)
	if p.id and c.id[i] == p.id then return ID_EXACTO end
	local q = p.q
	if not q then return 0 end
	local s = c.nom[i]
	local corte = find(s, "\1", 2, true)
	-- Exacto: el nombre en inglés o en tu idioma, entero.
	if s == q or (corte and ((corte - 1 == p.largo and find(s, q, 1, true) == 1) or (#s - corte == p.largo and find(s, p.qLo, corte, true) == corte))) then
		return EXACTO
	end
	local pos = find(s, p.cuerpo, 2, true)
	if pos == 2 or (corte and find(s, p.preLo, corte, true) == corte) then return PREFIJO end
	if p.corto then
		return find(s, q, 1, true) and PALABRA or 0
	end
	if pos then
		return find(s, q, 1, true) and PALABRA or DENTRO
	end
	local ws = p.palabras
	if ws then
		for k = 1, #ws do
			if not find(s, ws[k], 2, true) then return 0 end
		end
		return PALABRAS
	end
	return 0
end

-- Cuántos encuentra cada tipo listo con este texto (para las cuentas de los
-- segmentos). Sin texto, nil.
function Cat.Contar(texto)
	local p = preparar(texto)
	if not p then return nil end
	local out = {}
	for _, t in ipairs(M.TIPOS) do
		local c = col[t.clave]
		if c then
			local n = 0
			for i = 1, c.n do if coincide(c, i, p) > 0 then n = n + 1 end end
			out[t.clave] = n
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Filtros de cada tipo: fn(c, i, filtro, ctx) -> pasa
---------------------------------------------------------------------------
local FILTROS = {}

FILTROS.objeto = function(c, i, f, ctx)
	if f.calidad and (c.q[i] % 10) - 1 ~= f.calidad then return false end
	local fc = c.f
	if not fc then return true end
	local v = fc[i]
	if f.tipo and floor(v / 10000) - 2 ~= f.tipo then return false end
	if f.sub and floor(v / 100) % 100 - 2 ~= f.sub then return false end
	if ctx.ranuras and not ctx.ranuras[v % 100] then return false end
	if ctx.lo then
		local r = c.req[i]
		if not r or r < ctx.lo or r > ctx.hi then return false end
	end
	if f.usable and not puedeUsar(c, i) then return false end
	return true
end

FILTROS.pnj = function(c, i, f, ctx)
	if ctx.rol and not ctx.rol[c.id[i]] then return false end
	return true
end

FILTROS.mision = function(c, i, f, ctx)
	local I = M.Indices
	if ctx.lo then
		local lv = I.NivelFila(i)
		if not lv or lv < ctx.lo or lv > ctx.hi then return false end
	end
	if f.paraMi and not I.ParaMiFila(i) then return false end
	return true
end

FILTROS.raro = function(c, i, f, ctx)
	local kind = (f.clase or ctx.zona) and kindDe(c, i)
	if f.clase and kind ~= f.clase then return false end
	if ctx.zona and M.Indices.ZonaRaro(kind, c.id[i]) ~= ctx.zona then return false end
	return true
end

-- Monturas y mascotas: sus filtros viven en Coleccion.lua.
FILTROS.montura = function(c, i, f, ctx) return M.Col.Filtro(c, i, f, ctx) end
FILTROS.mascota = FILTROS.montura

local function contexto(tipo, f)
	if tipo == "montura" or tipo == "mascota" then return M.Col.Contexto(tipo, f) end
	local ctx = {}
	if tipo == "objeto" then
		if f.ranura then
			for _, r in ipairs(Cat.RANURAS) do
				if r.clave == f.ranura then
					ctx.ranuras = {}
					for _, v in ipairs(r.inv) do ctx.ranuras[v] = true end
				end
			end
		end
		ctx.lo, ctx.hi = rangoNivel(f.nivel)
	elseif tipo == "pnj" then
		if f.rol then
			local C = M.CodexListo()
			local ids = C and C.WithRole(f.rol) or {}
			ctx.rol = {}
			for _, id in ipairs(ids) do ctx.rol[id] = true end
		end
	elseif tipo == "mision" then
		ctx.lo, ctx.hi = rangoNivel(f.nivel)
	elseif tipo == "raro" then
		if f.miZona then
			local pp = A.PlayerPoint and A.PlayerPoint()
			ctx.zona = pp and pp.map or -1
		end
	end
	return ctx
end

-- ¿Este filtro necesita algo que todavía se está preparando? -> nombre | nil
local function pendienteDe(tipo, f)
	local I = M.Indices
	if tipo == "objeto" then
		if (f.tipo or f.sub or f.ranura) and not facetas.lista then return "facetas" end
		if (f.nivel or f.usable) and not facetas.nivel then return "registros" end
	elseif tipo == "mision" then
		if (f.nivel or f.paraMi) and not I.MisionesListas() then return "misiones" end
	elseif tipo == "raro" then
		if f.miZona and not I.RarosListos() then return "raros" end
	end
	return nil
end
Cat.Pendiente = pendienteDe

-- -> salida (filas del catálogo, en orden), pendiente (lo que falta preparar)
-- Con texto: primero lo exacto, luego lo que empieza igual, luego por
-- palabra, luego lo demás; dentro de cada grupo, por nombre (sin ordenar:
-- se reparte en cubetas recorriendo el orden de base).
local cubetas = { {}, {}, {}, {}, {}, {} }

function Cat.Buscar(tipo, texto, f, salida)
	salida = salida or {}
	for k = #salida, 1, -1 do salida[k] = nil end
	local c = col[tipo]
	if not c then return salida, "catalogo" end
	f = f or {}
	local pend = pendienteDe(tipo, f)
	local filtro = not pend and FILTROS[tipo] or nil
	local ctx = contexto(tipo, f)
	local p = preparar(texto)
	local orden = c.orden or {}
	local n = 0
	if p then
		for t = 1, #cubetas do local b = cubetas[t] for k = #b, 1, -1 do b[k] = nil end end
		for k = 1, #orden do
			local i = orden[k]
			local t = coincide(c, i, p)
			if t > 0 and (not filtro or filtro(c, i, f, ctx)) then
				local b = cubetas[t]
				b[#b + 1] = i
			end
		end
		for t = #cubetas, 1, -1 do
			local b = cubetas[t]
			for k = 1, #b do n = n + 1 salida[n] = b[k] b[k] = nil end
		end
	else
		for k = 1, #orden do
			local i = orden[k]
			if not filtro or filtro(c, i, f, ctx) then
				n = n + 1
				salida[n] = i
			end
		end
		-- Las misiones sin texto van por nivel (y por nombre dentro de cada nivel).
		local I = M.Indices
		if tipo == "mision" and I.MisionesListas() then
			local claves = {}
			for k = 1, n do claves[k] = (I.NivelFila(salida[k]) or 0) * 1000000 + k end
			sort(claves)
			local copia = {}
			for k = 1, n do copia[k] = salida[k] end
			for k = 1, n do salida[k] = copia[claves[k] % 1000000] end
		end
	end
	return salida, pend
end
