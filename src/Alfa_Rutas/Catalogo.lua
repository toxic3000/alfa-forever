-- Alfa - Rutas: el catálogo de todos los objetos del juego. Toxic / La Jauría. GPL-3.0.
--
-- Los objetos salen del Codex del motor (sus grupos item, mount, pet, recipe
-- y tabard: unos 23 000). El tipo, el subtipo, la ranura, el nivel y las
-- estadísticas de lo que se equipa salen de la base de objetos del motor
-- (A.ItemDB); los demás se preguntan al cliente (C_Item.GetItemInfoInstant,
-- que responde sin pedir nada al servidor). El índice se arma una vez, en
-- segundo plano, y se guarda en columnas (una tabla por dato) para que
-- filtrar miles de filas sea rápido.
--
--   Catalogo.Pedir(fn(ok, motivo), alAvanzar?)  -- arma el índice la primera vez
--   Catalogo.Listo() -> bool ; Catalogo.Total() -> n
--   Catalogo.Filtrar(filtro) -> { fila, ... }   -- filtro = { texto, tipo, sub, calidad, nivel, ranura, usable, retirados, orden }
--   Catalogo.Fila(i) -> datos de la fila ; Catalogo.FilaDe(itemId) -> i
--   Catalogo.Tipos(), Catalogo.Subtipos(tipo), Catalogo.RANURAS, Catalogo.NIVELES, Catalogo.ORDENES
--   Catalogo.Ficha(itemId) -> ficha (calidad, tipo, estadísticas, fuentes)

local ADDON, M = ...
local A, L = M.A, M.L
local T = M.Tareas
local Cat = {}
M.Catalogo = Cat

local type, ipairs, pairs, tonumber, tostring = type, ipairs, pairs, tonumber, tostring
local floor, max, min, format, find, sort = math.floor, math.max, math.min, string.format, string.find, table.sort

local function CX() return M.Motor("Codex") end
local function DB() return M.Motor("ItemDB") end

-- Columnas del índice.
local col = { id = {}, nombre = {}, plegado = {}, calidad = {}, clase = {}, sub = {}, inv = {}, req = {}, ilvl = {}, estado = {}, grupo = {}, usable = {} }
local porId = {}
local total, listo = 0, false
local conteoTipo, conteoSub = {}, {}

local GRUPOS = { "item", "mount", "pet", "recipe", "tabard" }
-- Clases propias del catálogo para lo que el juego no separa.
local MONTURA, MASCOTA = 100, 101

local EQUIPO = {
	INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_WAIST = 6,
	INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12,
	INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14, INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16, INVTYPE_2HWEAPON = 17,
	INVTYPE_BAG = 18, INVTYPE_TABARD = 19, INVTYPE_ROBE = 20, INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22,
	INVTYPE_HOLDABLE = 23, INVTYPE_AMMO = 24, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26, INVTYPE_QUIVER = 27, INVTYPE_RELIC = 28,
}
local CLAVE_EQUIPO = {}
for k, v in pairs(EQUIPO) do CLAVE_EQUIPO[v] = k end

-- Las ranuras del filtro (cada una junta las del juego que se usan igual).
Cat.RANURAS = {
	{ clave = "cabeza", nombre = L["Cabeza"], inv = { 1 } }, { clave = "cuello", nombre = L["Cuello"], inv = { 2 } },
	{ clave = "hombros", nombre = L["Hombros"], inv = { 3 } }, { clave = "espalda", nombre = L["Espalda"], inv = { 16 } },
	{ clave = "pecho", nombre = L["Pecho"], inv = { 5, 20 } }, { clave = "camisa", nombre = L["Camisa"], inv = { 4 } },
	{ clave = "tabardo", nombre = L["Tabardo"], inv = { 19 } }, { clave = "munecas", nombre = L["Muñecas"], inv = { 9 } },
	{ clave = "manos", nombre = L["Manos"], inv = { 10 } }, { clave = "cintura", nombre = L["Cintura"], inv = { 6 } },
	{ clave = "piernas", nombre = L["Piernas"], inv = { 7 } }, { clave = "pies", nombre = L["Pies"], inv = { 8 } },
	{ clave = "dedo", nombre = L["Dedo"], inv = { 11 } }, { clave = "abalorio", nombre = L["Abalorio"], inv = { 12 } },
	{ clave = "unamano", nombre = L["Una mano"], inv = { 13 } }, { clave = "dosmanos", nombre = L["Dos manos"], inv = { 17 } },
	{ clave = "principal", nombre = L["Mano derecha"], inv = { 21 } }, { clave = "secundaria", nombre = L["Mano izquierda"], inv = { 22, 14, 23 } },
	{ clave = "distancia", nombre = L["A distancia"], inv = { 15, 25, 26 } }, { clave = "reliquia", nombre = L["Reliquia"], inv = { 28 } },
	{ clave = "bolsa", nombre = L["Bolsa"], inv = { 18, 27 } }, { clave = "municion", nombre = L["Munición"], inv = { 24 } },
}
local RANURA_DE = {}
for _, r in ipairs(Cat.RANURAS) do for _, v in ipairs(r.inv) do RANURA_DE[v] = r end end

-- La ranura de un tipo de inventario, como la escribe el juego si la tiene.
function Cat.NombreRanura(inv)
	local k = CLAVE_EQUIPO[inv]
	local s = k and _G[k]
	if type(s) == "string" and s ~= "" then return s end
	local r = RANURA_DE[inv]
	return r and r.nombre or nil
end

-- Familias de armas: "Espadas" junta las de una y dos manos.
local FAMILIAS = {
	{ clave = "espadas", nombre = L["Espadas"], sub = { 7, 8 } }, { clave = "hachas", nombre = L["Hachas"], sub = { 0, 1 } },
	{ clave = "mazas", nombre = L["Mazas"], sub = { 4, 5 } }, { clave = "dagas", nombre = L["Dagas"], sub = { 15 } },
	{ clave = "bastones", nombre = L["Bastones"], sub = { 10 } }, { clave = "asta", nombre = L["Armas de asta"], sub = { 6 } },
	{ clave = "punos", nombre = L["Armas de puño"], sub = { 13 } }, { clave = "arcos", nombre = L["Arcos"], sub = { 2 } },
	{ clave = "fuego", nombre = L["Armas de fuego"], sub = { 3 } }, { clave = "ballestas", nombre = L["Ballestas"], sub = { 18 } },
	{ clave = "varitas", nombre = L["Varitas"], sub = { 19 } }, { clave = "arrojadizas", nombre = L["Arrojadizas"], sub = { 16 } },
	{ clave = "pesca", nombre = L["Cañas de pescar"], sub = { 20 } }, { clave = "varias", nombre = L["Otras armas"], sub = { 14 } },
}

Cat.NIVELES = {
	{ clave = "todos", nombre = L["Cualquier nivel"] },
	{ clave = "mio", nombre = L["Para mi nivel (±3)"] },
	{ clave = "hasta", nombre = L["Hasta mi nivel"] },
	{ clave = "1-10", nombre = "1-10", lo = 1, hi = 10 }, { clave = "11-20", nombre = "11-20", lo = 11, hi = 20 },
	{ clave = "21-30", nombre = "21-30", lo = 21, hi = 30 }, { clave = "31-40", nombre = "31-40", lo = 31, hi = 40 },
	{ clave = "41-50", nombre = "41-50", lo = 41, hi = 50 }, { clave = "51-60", nombre = "51-60", lo = 51, hi = 60 },
}

Cat.ORDENES = {
	{ clave = "nivel", nombre = L["Nivel (menor primero)"] }, { clave = "nivelDesc", nombre = L["Nivel (mayor primero)"] },
	{ clave = "calidad", nombre = L["Calidad (mejor primero)"] }, { clave = "nombre", nombre = L["Nombre (A-Z)"] },
}

local NOMBRE_TIPO = {
	[0] = L["Consumibles"], [1] = L["Bolsas"], [2] = L["Armas"], [4] = L["Armaduras"], [5] = L["Componentes"],
	[6] = L["Proyectiles"], [7] = L["Materiales"], [9] = L["Recetas"], [11] = L["Carcajs"], [12] = L["De misión"],
	[13] = L["Llaves"], [15] = L["Varios"], [MONTURA] = L["Monturas"], [MASCOTA] = L["Mascotas"],
}

function Cat.NombreTipo(c)
	if NOMBRE_TIPO[c] then return NOMBRE_TIPO[c] end
	local f = C_Item and C_Item.GetItemClassInfo
	if type(f) == "function" and type(c) == "number" then
		local ok, s = pcall(f, c)
		if ok and type(s) == "string" and s ~= "" then return s end
	end
	return L["Otros"]
end

function Cat.NombreSub(c, s)
	if c == MONTURA then return L["Monturas"] end
	if c == MASCOTA then return L["Mascotas"] end
	local f = C_Item and C_Item.GetItemSubClassInfo
	if type(f) == "function" and type(c) == "number" and type(s) == "number" then
		local ok, n = pcall(f, c, s)
		if ok and type(n) == "string" and n ~= "" then return n end
	end
	return format(L["Subtipo %d"], M.num(s, 0))
end

---------------------------------------------------------------------------
-- El índice
---------------------------------------------------------------------------

local esperando = {}

local function instantaneo(id)
	local f = C_Item and C_Item.GetItemInfoInstant
	if type(f) ~= "function" then return nil end
	local r = { pcall(f, id) }
	if not (r[1] and r[2]) then return nil end
	return r[7], r[8], EQUIPO[r[5]] or 0
end

local function armar(ceder)
	local C, D = CX(), DB()
	if D and D.Load then D.Load() end
	local crudos = {}
	for gi, kind in ipairs(GRUPOS) do
		C.Each(kind, function(id, name, quality, status)
			if type(id) == "number" then crudos[#crudos + 1] = { id, name, quality, status, gi } end
		end)
	end
	local n = 0
	local cuantos = #crudos
	for k, cr in ipairs(crudos) do
		local id = cr[1]
		if not porId[id] then
			local nombre = C.Name("item", id) or cr[2] or tostring(id)
			local cls, sb, iv, rq, il
			local rec = D and D.IsLoaded and D.IsLoaded() and D.Get(id)
			if rec then
				cls, sb, iv, rq, il = rec.class, rec.subclass, rec.inv, rec.req, rec.ilvl
			else
				cls, sb, iv = instantaneo(id)
				local crec = C.Item(id)
				rq = crec and crec.reqLevel
			end
			local grupo = GRUPOS[cr[5]]
			if grupo == "mount" then cls, sb = MONTURA, 0 elseif grupo == "pet" then cls, sb = MASCOTA, 0 end
			n = n + 1
			col.id[n], col.nombre[n] = id, nombre
			local plegado = M.Plegar(nombre)
			if cr[2] and cr[2] ~= nombre then plegado = plegado .. "\1" .. M.Plegar(cr[2]) end
			col.plegado[n] = plegado
			col.calidad[n] = M.num(cr[3], (rec and rec.quality) or 1)
			col.clase[n], col.sub[n], col.inv[n] = M.num(cls, -1), M.num(sb, -1), M.num(iv, 0)
			col.req[n], col.ilvl[n] = M.num(rq, 0), M.num(il, 0)
			col.estado[n], col.grupo[n] = cr[4], grupo
			porId[id] = n
			local c = col.clase[n]
			conteoTipo[c] = (conteoTipo[c] or 0) + 1
			local cs = conteoSub[c]
			if not cs then
				cs = {}
				conteoSub[c] = cs
			end
			cs[col.sub[n]] = (cs[col.sub[n]] or 0) + 1
		end
		if k % 200 == 0 then T.Avance("catalogo", k / max(1, cuantos)) end
		ceder()
	end
	total = n
	-- El orden de base: nivel, luego mejor calidad, luego nombre.
	local orden = {}
	for i = 1, n do orden[i] = i end
	local req, cal, nom = col.req, col.calidad, col.plegado
	sort(orden, function(a, b)
		if req[a] ~= req[b] then return req[a] < req[b] end
		if cal[a] ~= cal[b] then return cal[a] > cal[b] end
		return nom[a] < nom[b]
	end)
	Cat.base = orden
	return true
end

function Cat.Listo() return listo end
function Cat.Total() return total end

function Cat.Pedir(fn, alAvanzar)
	if listo then return fn(true) end
	local ok, motivo = M.Indice.CodexListo()
	if not ok then return fn(false, motivo) end
	esperando[#esperando + 1] = fn
	if T.Corriendo("catalogo") then return end
	T.Lanzar("catalogo", armar, function(res, err)
		listo = res and true or false
		local lista = esperando
		esperando = {}
		for _, f in ipairs(lista) do
			local bien, e2 = pcall(f, listo, err and "error" or nil)
			if not bien and geterrorhandler then geterrorhandler()(e2) end
		end
	end, alAvanzar)
end

-- Los tipos con objetos, con cuántos hay de cada uno.
function Cat.Tipos()
	local out = {}
	for c, n in pairs(conteoTipo) do
		if c >= 0 then out[#out + 1] = { clase = c, nombre = Cat.NombreTipo(c), cuenta = n } end
	end
	sort(out, function(a, b) return a.nombre < b.nombre end)
	return out
end

-- Los subtipos de un tipo (las armas, por familias).
function Cat.Subtipos(c)
	local out = {}
	local cs = conteoSub[c] or {}
	if c == 2 then
		for _, f in ipairs(FAMILIAS) do
			local n = 0
			for _, s in ipairs(f.sub) do n = n + (cs[s] or 0) end
			if n > 0 then out[#out + 1] = { clave = f.clave, nombre = f.nombre, sub = f.sub, cuenta = n } end
		end
		return out
	end
	for s, n in pairs(cs) do
		if s >= 0 then out[#out + 1] = { clave = tostring(s), nombre = Cat.NombreSub(c, s), sub = { s }, cuenta = n } end
	end
	sort(out, function(a, b) return a.nombre < b.nombre end)
	return out
end

-- ¿Lo puede usar tu personaje? (el motor de equipo decide por clase y competencia)
local gearListo = false
local function usable(i)
	local u = col.usable[i]
	if u ~= nil then return u end
	u = true
	local Gear = M.Motor("Gear")
	local D = DB()
	local rec = D and D.IsLoaded and D.IsLoaded() and D.Get(col.id[i])
	if rec and Gear and Gear.Usability then
		if not gearListo and Gear.GetPlayer then
			Gear.GetPlayer()
			gearListo = true
		end
		local ok, puede, motivo = pcall(Gear.Usability, rec)
		if ok then u = puede and true or (motivo == "skill") end
	end
	col.usable[i] = u
	return u
end
Cat.Usable = usable

A.RegisterEvent("PLAYER_LEVEL_UP", function() col.usable = {} end)

local function rangoNivel(f)
	local clave = f.nivel or "todos"
	if clave == "todos" then return nil end
	local nivel = M.Indice.Jugador().level
	if clave == "mio" then return max(1, nivel - 3), nivel + 3 end
	if clave == "hasta" then return 0, nivel end
	for _, n in ipairs(Cat.NIVELES) do
		if n.clave == clave then return n.lo, n.hi end
	end
	return nil
end

-- filtro -> lista de filas. texto: palabras que deben estar todas en el
-- nombre (en tu idioma o en inglés), sin acentos ni mayúsculas.
function Cat.Filtrar(f)
	f = f or {}
	local out = {}
	if not listo then return out end
	local palabras = {}
	for w in M.Plegar(f.texto or ""):gmatch("%S+") do palabras[#palabras + 1] = w end
	local tipo = f.tipo
	local subs
	if f.sub and type(f.subLista) == "table" then
		subs = {}
		for _, s in ipairs(f.subLista) do subs[s] = true end
	end
	local calidad = f.calidad
	local ranuras
	if f.ranura then
		for _, r in ipairs(Cat.RANURAS) do
			if r.clave == f.ranura then
				ranuras = {}
				for _, v in ipairs(r.inv) do ranuras[v] = true end
			end
		end
	end
	local lo, hi = rangoNivel(f)
	local plegado, clase, sub, inv, req, cal, est = col.plegado, col.clase, col.sub, col.inv, col.req, col.calidad, col.estado
	for _, i in ipairs(Cat.base or {}) do
		local ok = true
		if tipo and clase[i] ~= tipo then ok = false end
		if ok and subs and not subs[sub[i]] then ok = false end
		if ok and calidad and cal[i] ~= calidad then ok = false end
		if ok and ranuras and not ranuras[inv[i]] then ok = false end
		if ok and lo and (req[i] < lo or req[i] > hi) then ok = false end
		if ok and not f.retirados and est[i] == "retired" then ok = false end
		if ok then
			local p = plegado[i]
			for w = 1, #palabras do
				if not find(p, palabras[w], 1, true) then ok = false break end
			end
		end
		if ok and f.usable and not usable(i) then ok = false end
		if ok then out[#out + 1] = i end
	end
	local orden = f.orden or "nivel"
	if orden == "nivelDesc" then
		local n = #out
		for k = 1, floor(n / 2) do out[k], out[n - k + 1] = out[n - k + 1], out[k] end
	elseif orden == "calidad" then
		sort(out, function(a, b)
			if cal[a] ~= cal[b] then return cal[a] > cal[b] end
			if req[a] ~= req[b] then return req[a] > req[b] end
			return plegado[a] < plegado[b]
		end)
	elseif orden == "nombre" then
		sort(out, function(a, b) return plegado[a] < plegado[b] end)
	end
	return out
end

function Cat.FilaDe(itemId) return porId[tonumber(itemId) or 0] end

function Cat.Fila(i)
	if not col.id[i] then return nil end
	return {
		id = col.id[i], nombre = col.nombre[i], calidad = col.calidad[i], clase = col.clase[i], sub = col.sub[i],
		inv = col.inv[i], req = col.req[i], ilvl = col.ilvl[i], estado = col.estado[i], grupo = col.grupo[i],
	}
end

-- "Espada de una mano · Mano derecha · Nv 12"
function Cat.Linea(i)
	local partes = {}
	local c, s, iv, rq = col.clase[i], col.sub[i], col.inv[i], col.req[i]
	if c and c >= 0 then
		partes[#partes + 1] = (c == 2 or c == 4) and Cat.NombreSub(c, s) or Cat.NombreTipo(c)
	end
	local ranura = iv and iv > 0 and Cat.NombreRanura(iv)
	if ranura then partes[#partes + 1] = ranura end
	if rq and rq > 0 then partes[#partes + 1] = format(L["Nv %d"], rq) end
	if col.estado[i] == "retired" then partes[#partes + 1] = L["ya no se consigue"] end
	return table.concat(partes, " \194\183 ")
end

---------------------------------------------------------------------------
-- La ficha de un objeto
---------------------------------------------------------------------------

-- Las estadísticas de la base de objetos, en palabras y en un orden fijo.
local STATS = {
	{ "dps", L["Daño por segundo"] }, { "armor", L["Armadura"] }, { "str", L["Fuerza"] }, { "agi", L["Agilidad"] },
	{ "sta", L["Aguante"] }, { "int", L["Intelecto"] }, { "spi", L["Espíritu"] }, { "ap", L["Poder de ataque"] },
	{ "rap", L["Poder de ataque a distancia"] }, { "crit", L["Golpe crítico (%)"] }, { "hit", L["Golpe (%)"] },
	{ "defense", L["Defensa"] }, { "dodge", L["Esquiva (%)"] }, { "parry", L["Parada (%)"] }, { "block", L["Bloqueo (%)"] },
	{ "blockValue", L["Valor de bloqueo"] }, { "sp", L["Poder con hechizos"] }, { "heal", L["Sanación"] },
	{ "spellCrit", L["Crítico con hechizos (%)"] }, { "spellHit", L["Golpe con hechizos (%)"] },
	{ "mp5", L["Maná cada 5 s"] }, { "hp5", L["Salud cada 5 s"] }, { "health", L["Salud"] }, { "mana", L["Maná"] },
}

function Cat.Ficha(itemId)
	itemId = tonumber(itemId)
	if not itemId then return nil end
	local i = porId[itemId]
	local C = CX()
	local rec = C and C.Item(itemId)
	local f = { id = itemId, nombre = (i and col.nombre[i]) or M.NombreObjeto(itemId), kind = rec and rec.kind or "item",
		calidad = (i and col.calidad[i]) or (rec and rec.quality) or 1, linea = i and Cat.Linea(i) or "", stats = {},
		retirado = rec and rec.status == "retired", sinFuente = rec and rec.status == "nosource" }
	if i then f.req, f.ilvl, f.usable = col.req[i], col.ilvl[i], usable(i) end
	local D = DB()
	local it = D and D.IsLoaded and D.IsLoaded() and D.Get(itemId)
	if it and type(it.stats) == "table" then
		local vistos = {}
		for _, s in ipairs(STATS) do
			local v = it.stats[s[1]]
			if type(v) == "number" and v ~= 0 then
				f.stats[#f.stats + 1] = { nombre = s[2], valor = v }
				vistos[s[1]] = true
			end
		end
		for k, v in pairs(it.stats) do
			if not vistos[k] and type(v) == "number" and v ~= 0 then f.stats[#f.stats + 1] = { nombre = tostring(k), valor = v } end
		end
		if it.speed then f.velocidad = it.speed / 1000 end
		if it.unique then f.unico = true end
	end
	local Lk = M.Motor("Lookup")
	f.fuentes = {}
	if Lk and Lk.Sources then
		local ok, lista = pcall(Lk.Sources, f.kind, itemId, true)
		if ok and type(lista) == "table" then
			for k = 1, min(6, #lista) do f.fuentes[k] = lista[k] end
			f.totalFuentes = #lista
		end
	end
	return f
end
