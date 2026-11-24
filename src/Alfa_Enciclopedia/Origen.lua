-- Alfa - Enciclopedia: cómo se consigue cada objeto y de qué facción es
-- (1.3.8). toxic3000 / La Jauría. GPL-3.0.
--
-- Pedido de Toxic: «agregarle una etiqueta para saber si el objeto lo
-- sueltan, te lo dan en la misión, se consigue de una serie de misiones, si
-- está en Alianza o en Horda o zona neutral», «incluye la probabilidad».
-- Todo sale de las fuentes del Codex de cada objeto (rec.sources):
--   drop      «Lo sueltan» (de un jefe o de un raro, se dice), con la mejor
--             probabilidad que traen los datos (sin dato, sin número)
--   quest     «Misión», o «Serie de misiones» si pide otra antes (pre/preAny)
--   vendor    «Vendedor»; craft «Fabricado»; object «Pesca», «Recolección»
--             o «Mundo» (cofres y objetos del suelo); rep, pvp, gift, container
-- La facción: la de los PNJ que lo venden o dan, la de la misión, o la de la
-- zona donde están los enemigos y los objetos (zonas de la Alianza, de la
-- Horda y las demás, en disputa o neutrales: «Neutral»).
--
-- Ligero: nada al entrar al juego ni sin el Codex ya cargado (solo lo usa la
-- ventana). Cada objeto se calcula una vez por sesión y solo el que se ve
-- (O.Resumen); los filtros «Cómo se consigue» y «Facción» y el orden «Más
-- probable primero» piden O.Preparar (por lotes, en segundo plano, una vez).
--
--   O.Resumen(id) -> m, b, prob     m: suma de O.BIT, b: suma de O.BANDO, prob: 0..100 | nil
--   O.Etiquetas(id, tope) -> { { texto, tono, icono }, ... }   las de la fila (las más útiles primero)
--   O.Ficha(f, kind, id, rec, lista)  las insignias y la sección «Cómo se consigue» de la ficha
--   O.Preparar(fn), O.Listo(), O.Fila(i) -> m, b, prob   (para filtrar el catálogo)
--   O.Pasa(m, b, origen, bando) -> bool
--   O.ORIGENES, O.BANDOS: las opciones de los filtros

local ADDON, M = ...
local A, L, K = M.A, M.L, M.K
local O = {}
M.Origen = O

local type, tonumber, tostring, ipairs, pairs, pcall, next = type, tonumber, tostring, ipairs, pairs, pcall, next
local floor, max, min, format = math.floor, math.max, math.min, string.format
local sort, concat = table.sort, table.concat

local BIT = {
	suelta = 1, jefe = 2, raro = 4, mision = 8, serie = 16, vendedor = 32, fabricado = 64,
	pesca = 128, recoleccion = 256, mundo = 512, rep = 1024, pvp = 2048, regalo = 4096, contenedor = 8192, botin = 16384,
}
O.BIT = BIT
local BANDO = { A = 1, H = 2, N = 4 }
O.BANDO = BANDO

local function tiene(v, b) return v and floor(v / b) % 2 == 1 or false end
O.Tiene = tiene

local TOPE_FILA = 6 -- enemigos, vendedores y misiones que se miran por objeto en la lista

---------------------------------------------------------------------------
-- Zonas: de quién es cada una (uiMapID del cliente)
---------------------------------------------------------------------------
local ZONA = {
	-- Alianza
	[1429] = "A", [1426] = "A", [1438] = "A", [1439] = "A", [1436] = "A", [1432] = "A", [1433] = "A",
	[1431] = "A", [1437] = "A", [1453] = "A", [1455] = "A", [1457] = "A",
	-- Horda
	[1411] = "H", [1412] = "H", [1420] = "H", [1421] = "H", [1413] = "H", [1454] = "H", [1456] = "H", [1458] = "H",
}
O.ZONA = ZONA
function O.LadoZona(map)
	if map == nil then return nil end
	return ZONA[map] or "N"
end

---------------------------------------------------------------------------
-- Lo que se guarda por sesión
---------------------------------------------------------------------------
local resumen = {}  -- id de objeto -> m + b * 65536
local probDe = {}   -- id de objeto -> probabilidad | false
local npcDe = {}    -- id de PNJ -> { lado territorial (bits), lado propio (bits), jefe, raro }
local misionDe = {} -- id de misión -> { lado (bits), serie }
local objetoDe = {} -- id de objeto del mundo -> "pesca" | "recoleccion" | "mundo"
local listo, armando = false, false
local filas -- columnas del catálogo de objetos: org[i], prob[i]

function O.Olvidar()
	resumen, probDe, npcDe, misionDe, objetoDe = {}, {}, {}, {}, {}
end

local function Codex() return M.CodexListo() end

-- Los lados de las zonas donde aparece algo (hasta 4 zonas distintas).
local function ladosDe(spawns)
	local b, vistos, n = 0, {}, 0
	for _, s in ipairs(spawns or {}) do
		local m = s.map
		if m and not vistos[m] then
			vistos[m] = true
			n = n + 1
			local l = BANDO[O.LadoZona(m)]
			if not tiene(b, l) then b = b + l end
			if n >= 4 then break end
		end
	end
	return b
end

local function lado(f)
	if f == "A" or f == "Alliance" then return BANDO.A end
	if f == "H" or f == "Horde" then return BANDO.H end
	if f == "AH" or f == "HA" then return BANDO.N end
	return 0
end

-- PNJ: el lado de sus zonas, el suyo propio, si es jefe y si es raro.
local function npc(id)
	if id == nil then return nil end
	local x = npcDe[id]
	if x ~= nil then return x or nil end
	local C = Codex()
	local ok, n = false, nil
	if C and C.Npc then ok, n = pcall(C.Npc, id) end
	if not (ok and type(n) == "table") then
		if C then npcDe[id] = false end
		return nil
	end
	x = { zona = ladosDe(n.spawns), propio = lado(n.faction), jefe = n.boss and true or false, raro = n.rare and true or false,
		instancia = n.instance and true or false }
	npcDe[id] = x
	return x
end
O.Npc = npc

local function lados(b, mas)
	local out = b
	for _, l in ipairs({ 1, 2, 4 }) do
		if tiene(mas, l) and not tiene(out, l) then out = out + l end
	end
	return out
end

-- Misión: su lado (el del Codex o la base de misiones, el de quien la da, o
-- el de su zona) y si es parte de una serie (pide otra antes).
local function mision(id)
	if id == nil then return nil end
	local x = misionDe[id]
	if x ~= nil then return x or nil end
	local C = Codex()
	local ok, q = false, nil
	if C and C.Quest then ok, q = pcall(C.Quest, id) end
	if not (ok and type(q) == "table") then
		if C then misionDe[id] = false end
		return nil
	end
	local Lk = A.Lookup
	local side = q.faction
	if not side and Lk and Lk.QuestSide then
		local ok2, s = pcall(Lk.QuestSide, q)
		if ok2 then side = s end
	end
	local b = lado(side)
	if b == 0 then
		for _, n in ipairs(q.start and q.start.npc or {}) do
			local p = npc(n)
			if p and p.propio ~= 0 then b = lados(b, p.propio) end
		end
	end
	if b == 0 and q.zone then b = BANDO[O.LadoZona(q.zone)] end
	local serie = (q.pre and #q.pre > 0) or (q.preAny and #q.preAny > 0) or false
	x = { lado = b, serie = serie and true or false }
	misionDe[id] = x
	return x
end
O.Mision = mision

-- Objetos del mundo: bancos de peces, menas y hierbas (por su nombre en
-- inglés, el del Codex), cofres y lo demás.
local HIERBAS = { "peacebloom", "silverleaf", "earthroot", "mageroyal", "briarthorn", "stranglekelp", "bruiseweed",
	"wild steelbloom", "grave moss", "kingsblood", "liferoot", "fadeleaf", "goldthorn", "khadgar's whisker", "wintersbite",
	"firebloom", "purple lotus", "arthas' tears", "sungrass", "blindweed", "ghost mushroom", "gromsblood", "golden sansam",
	"dreamfoil", "mountain silversage", "plaguebloom", "icecap", "black lotus", "swiftthistle", "bloodthistle" }
local tipoObjeto -- id -> clase, armado una vez de los nombres
local function claseObjeto(oid)
	if oid == nil then return "mundo" end
	if not tipoObjeto then
		local C = Codex()
		if not C then return "mundo" end
		tipoObjeto = {}
		pcall(C.Each, "object", function(id, nombre)
			local n = type(nombre) == "string" and nombre:lower() or ""
			if n:find("school", 1, true) or n:find("wreckage", 1, true) or n:find("floating debris", 1, true)
				or n:find("oil spill", 1, true) or n:find("elemental water", 1, true) then
				tipoObjeto[id] = "pesca"
			elseif n:find(" vein", 1, true) or n:find(" deposit", 1, true) then
				tipoObjeto[id] = "recoleccion"
			else
				for _, h in ipairs(HIERBAS) do
					if n == h or n:find(h, 1, true) == 1 then tipoObjeto[id] = "recoleccion" break end
				end
			end
		end)
	end
	return tipoObjeto[oid] or "mundo"
end
O.ClaseObjeto = claseObjeto

local function objetoLados(oid)
	local x = objetoDe[oid]
	if x ~= nil then return x end
	local C = Codex()
	local ok, o = false, nil
	if C and C.Object then ok, o = pcall(C.Object, oid) end
	x = ok and type(o) == "table" and ladosDe(o.spawns) or 0
	if C then objetoDe[oid] = x end
	return x
end

---------------------------------------------------------------------------
-- Analizar las fuentes de un objeto
---------------------------------------------------------------------------
local function ponerBit(m, b) if not tiene(m, b) then return m + b end return m end

-- rec: el registro del Codex; tope: cuántos PNJ y misiones mirar (nil: todos).
-- -> m, b, prob, detalle (con tope nil: { suelta = { {fuente, npc}... }, ... })
local function analizar(rec, tope)
	local m, b, prob = 0, 0, nil
	local srcs = type(rec) == "table" and rec.sources or {}
	-- Los que lo sueltan, de más a menos probable (los primeros son los que importan).
	local drops = {}
	for _, s in ipairs(srcs) do if s.type == "drop" then drops[#drops + 1] = s end end
	if #drops > 1 then sort(drops, function(x, y) return (x.chance or -1) > (y.chance or -1) end) end
	-- «De jefe» o «De raro» solo si todos los que lo sueltan (de los mirados) lo son.
	local mirados, jefes, raros = 0, 0, 0
	for k, s in ipairs(drops) do
		m = ponerBit(m, BIT.suelta)
		-- Algunos datos pasan de 100 (más de uno por enemigo): se cuenta como seguro.
		local ch = s.chance and min(100, s.chance)
		if ch and (not prob or ch > prob) then prob = ch end
		if not tope or k <= tope then
			local p = npc(s.npc)
			mirados = mirados + 1
			if p then
				if p.jefe then jefes = jefes + 1 end
				if p.raro then raros = raros + 1 end
			end
			if s.instance or (p and p.instancia) then
				b = lados(b, BANDO.N)
			elseif p then
				b = lados(b, p.zona)
			end
		end
	end
	if mirados > 0 and jefes == mirados then m = ponerBit(m, BIT.jefe) end
	if mirados > 0 and raros == mirados then m = ponerBit(m, BIT.raro) end
	local nv, nq = 0, 0
	for _, s in ipairs(srcs) do
		local t = s.type
		if t == "vendor" or t == "gift" or t == "pvp" or t == "rep" then
			m = ponerBit(m, t == "vendor" and BIT.vendedor or t == "gift" and BIT.regalo or t == "pvp" and BIT.pvp or BIT.rep)
			nv = nv + 1
			if not tope or nv <= tope then
				local l = 0
				if t == "rep" and s.faction then
					local C = Codex()
					local ok, fa = pcall(C.Faction, s.faction)
					if ok and type(fa) == "table" then l = lado(fa.side) end
				end
				local p = npc(s.npc)
				if l == 0 and p then l = p.propio ~= 0 and p.propio or p.zona end
				b = lados(b, l)
			end
		elseif t == "quest" then
			m = ponerBit(m, BIT.mision)
			nq = nq + 1
			if not tope or nq <= tope then
				local q = mision(s.quest)
				if q then
					if q.serie then m = ponerBit(m, BIT.serie) end
					b = lados(b, q.lado)
				end
			end
		elseif t == "craft" then
			m = ponerBit(m, BIT.fabricado)
		elseif t == "object" then
			local cl = claseObjeto(s.object)
			m = ponerBit(m, BIT[cl])
			b = lados(b, objetoLados(s.object))
		elseif t == "container" then
			m = ponerBit(m, BIT.contenedor)
		elseif t == "world" then
			m = ponerBit(m, BIT.botin)
			b = lados(b, BANDO.N)
		end
	end
	return m, b, prob
end
O.Analizar = analizar

function O.Resumen(id)
	if id == nil then return 0, 0, nil end
	local v = resumen[id]
	if v then
		local p = probDe[id]
		return v % 65536, floor(v / 65536), p or nil
	end
	local C = Codex()
	if not C then return 0, 0, nil end
	local ok, rec = pcall(C.Item, id)
	local m, b, p = 0, 0, nil
	if ok and type(rec) == "table" then m, b, p = analizar(rec, TOPE_FILA) end
	resumen[id] = m + b * 65536
	probDe[id] = p or false
	return m, b, p
end

---------------------------------------------------------------------------
-- Las etiquetas
---------------------------------------------------------------------------
-- La Alianza en azul y la Horda en rojo (tonos propios de la enciclopedia).
K.TONOS.alianza = K.TONOS.alianza or { "pnj", "pnj" }
K.TONOS.horda = K.TONOS.horda or { "peligroRelleno", "peligro" }

local ICONO = {
	suelta = "ic-personajes", jefe = "ic-mazmorra", raro = "ic-raros", mision = "ic-misiones", serie = "ic-ruta",
	vendedor = "ic-comercio", fabricado = "ic-oficios", pesca = "ic-pesca", recoleccion = "ic-recoleccion", mundo = "ic-mundo",
	rep = "ic-manada", pvp = "ic-alerta", regalo = "ic-personajes", contenedor = "ic-bolsas", botin = "ic-personajes",
}
local TONO = {
	suelta = "raro", jefe = "mazmorra", raro = "raro", mision = "oro", serie = "oro", vendedor = "acento", fabricado = "acento",
	pesca = "acento", recoleccion = "exito", mundo = "neutro", rep = "exito", pvp = "peligro", regalo = "neutro",
	contenedor = "neutro", botin = "neutro",
}
O.ICONO, O.TONO = ICONO, TONO

-- El texto corto de la fila y el largo de la ficha.
local function textoCorto(cat)
	if cat == "suelta" then return L["Lo sueltan [etiqueta]"]
	elseif cat == "jefe" then return L["De jefe"]
	elseif cat == "raro" then return L["De raro"]
	elseif cat == "mision" then return L["Misión"]
	elseif cat == "serie" then return L["Serie de misiones"]
	elseif cat == "vendedor" then return L["Vendedor"]
	elseif cat == "fabricado" then return L["Fabricado"]
	elseif cat == "pesca" then return L["Pesca"]
	elseif cat == "recoleccion" then return L["Recolección"]
	elseif cat == "mundo" then return L["Mundo"]
	elseif cat == "rep" then return L["Reputación"]
	elseif cat == "pvp" then return L["Honor"]
	elseif cat == "regalo" then return L["Te lo dan"]
	elseif cat == "contenedor" then return L["Dentro de otro"]
	elseif cat == "botin" then return L["Botín del mundo"] end
	return cat
end
O.TextoCorto = textoCorto

local function textoLargo(cat)
	if cat == "suelta" then return L["Lo sueltan enemigos"]
	elseif cat == "jefe" then return L["Lo suelta un jefe"]
	elseif cat == "raro" then return L["Lo suelta un raro"]
	elseif cat == "mision" then return L["Te lo dan en una misión"]
	elseif cat == "serie" then return L["Sale de una serie de misiones"]
	elseif cat == "vendedor" then return L["Lo vende un PNJ"]
	elseif cat == "fabricado" then return L["Se fabrica con un oficio"]
	elseif cat == "pesca" then return L["Se pesca"]
	elseif cat == "recoleccion" then return L["Se recolecta"]
	elseif cat == "mundo" then return L["En cofres u objetos del mundo"]
	elseif cat == "rep" then return L["Por reputación"]
	elseif cat == "pvp" then return L["Por honor (JcJ)"]
	elseif cat == "regalo" then return L["Te lo da un PNJ"]
	elseif cat == "contenedor" then return L["Dentro de otro objeto"]
	elseif cat == "botin" then return L["Botín del mundo"] end
	return textoCorto(cat)
end
O.TextoLargo = textoLargo

local function bandoTexto(l)
	if l == BANDO.A then return L["Alianza"] end
	if l == BANDO.H then return L["Horda"] end
	return L["Neutral"]
end
local function bandoTono(l) return l == BANDO.A and "alianza" or l == BANDO.H and "horda" or "neutro" end
local function bandoIcono(l) return l == BANDO.N and "ic-mundo" or "ic-comunidad" end
O.BandoTexto = bandoTexto

-- El orden de los lados: el tuyo, luego lo neutral, luego el otro.
local function ordenLados(b)
	local mio = M.MiBando and M.MiBando()
	local primero = mio == "A" and BANDO.A or mio == "H" and BANDO.H or nil
	local otro = mio == "A" and BANDO.H or mio == "H" and BANDO.A or nil
	local out = {}
	for _, l in ipairs(primero and { primero, BANDO.N, otro } or { BANDO.A, BANDO.H, BANDO.N }) do
		if tiene(b, l) then out[#out + 1] = l end
	end
	return out
end
O.OrdenLados = ordenLados

-- Las categorías de un objeto, de lo más útil para ti a lo menos: lo que se
-- consigue seguro (comprar, una misión, fabricarlo), luego lo que hay que
-- cazar o recoger. «Lo sueltan» se cambia por «De jefe» o «De raro».
local ORDEN = { "vendedor", "serie", "mision", "fabricado", "suelta", "pesca", "recoleccion", "mundo", "rep", "pvp", "regalo", "botin", "contenedor" }

local function categorias(m)
	local out = {}
	for _, cat in ipairs(ORDEN) do
		if tiene(m, BIT[cat]) then
			if cat == "mision" and tiene(m, BIT.serie) then
				-- ya va «Serie de misiones»
			elseif cat == "suelta" then
				out[#out + 1] = tiene(m, BIT.jefe) and "jefe" or tiene(m, BIT.raro) and "raro" or "suelta"
			else
				out[#out + 1] = cat
			end
		end
	end
	return out
end
O.Categorias = categorias

local function conProb(texto, p)
	local s = p and M.Porcentaje(p)
	return s and (texto .. M.SEP .. s) or texto
end

-- Las de la fila: hasta `tope` (2 de cómo se consigue y la facción, o 3 sin facción).
function O.Etiquetas(id, tope)
	tope = tope or 3
	local m, b, p = O.Resumen(id)
	local out = {}
	local ls = ordenLados(b)
	local origen = #ls > 0 and tope - 1 or tope
	for _, cat in ipairs(categorias(m)) do
		if #out >= origen then break end
		local t = textoCorto(cat)
		if cat == "suelta" or cat == "jefe" or cat == "raro" then t = conProb(t, p) end
		-- La primera es la más importante; la facción va antes que la segunda.
		out[#out + 1] = { t, TONO[cat], ICONO[cat], cat = cat, pri = #out == 0 and 1 or 3 }
	end
	if ls[1] and #out < tope then
		if tiene(b, BANDO.A) and tiene(b, BANDO.H) then
			out[#out + 1] = { L["Ambas facciones"], "neutro", "ic-comunidad", cat = "bando", pri = 2 }
		else
			out[#out + 1] = { bandoTexto(ls[1]), bandoTono(ls[1]), bandoIcono(ls[1]), cat = "bando", pri = 2 }
		end
	end
	return out
end

---------------------------------------------------------------------------
-- La ficha: todas las etiquetas y «Cómo se consigue» con su detalle
---------------------------------------------------------------------------
local function unir(...) return M.F and M.F.Unir and M.F.Unir(...) or concat({ ... }, M.SEP) end

-- La mejor fila del motor de un tipo: la más probable de las que puedes
-- (con un poco de peso por lo lejos: «la mejor probabilidad cerca»).
local function mejorFila(lista, tipo)
	local mejor, puntos
	for _, r in ipairs(lista or {}) do
		if r.type == tipo then
			local p = (r.chance or 0) / (1 + (r.travel or 0) / 600)
			if r.available then p = p + 1000 end
			if not puntos or p > puntos then mejor, puntos = r, p end
		end
	end
	return mejor
end
O.MejorFila = mejorFila

local function zonasDe(lista, l)
	local out, visto = {}, {}
	for _, r in ipairs(lista or {}) do
		if r.map and not visto[r.map] and BANDO[O.LadoZona(r.map)] == l and r.type ~= "craft" then
			visto[r.map] = true
			local z = M.Zona(r.map)
			if z then out[#out + 1] = z end
			if #out >= 3 then break end
		end
	end
	return out
end

function O.Ficha(f, kind, id, rec, lista)
	if type(f) ~= "table" or type(rec) ~= "table" then return end
	local m, b, p = analizar(rec, nil)
	-- Lo que se ve en la lista es lo mismo que en la ficha (ya con todos los datos).
	resumen[id] = m + b * 65536
	probDe[id] = p or false
	local cats = categorias(m)
	if #cats == 0 and b == 0 then return end
	local C = Codex()
	local filas = {}
	local ins = {}
	for _, cat in ipairs(cats) do
		local t = textoCorto(cat)
		if cat == "suelta" or cat == "jefe" or cat == "raro" then t = conProb(t, p) end
		ins[#ins + 1] = { t, TONO[cat], ICONO[cat] }
		-- La fila del detalle: el mejor ejemplo, su lugar y «Guíame».
		local tipo = (cat == "suelta" or cat == "jefe" or cat == "raro") and "drop" or (cat == "mision" or cat == "serie") and "quest"
			or cat == "vendedor" and "vendor" or cat == "fabricado" and "craft" or (cat == "pesca" or cat == "recoleccion" or cat == "mundo") and "object"
			or cat == "rep" and "rep" or cat == "pvp" and "pvp" or cat == "regalo" and "gift" or cat == "contenedor" and "container" or "world"
		local r = mejorFila(lista, tipo)
		local src = r and type(r.src) == "table" and r.src or {}
		local fl = { icono = { ic = ICONO[cat], tono = TONO[cat] }, titulo = textoLargo(cat) }
		local detalle
		if r then
			local lugar = r.map and M.Zona(r.map) or nil
			if tipo == "drop" then
				local n = src.npc and C and C.Npc(src.npc)
				local inst = r.instance and C and C.Instance(r.instance)
				detalle = unir(r.label, n and n.level and format(L["Nv %d"], n.level) or nil, inst and inst.name or lugar)
				fl.valor = r.chance and M.Porcentaje(min(100, r.chance)) or nil
				fl.ir = src.npc and { kind = "npc", id = src.npc } or nil
			elseif tipo == "quest" then
				detalle = unir(r.label, lugar)
				fl.valor = not src.choice and M.Porcentaje(100) or L["a elegir"]
				fl.ir = src.quest and { kind = "quest", id = src.quest } or nil
			elseif tipo == "craft" then
				detalle = M.NombreProfesion and M.NombreProfesion(src.skillLine) or nil
			else
				detalle = unir(r.label, lugar)
				fl.valor = r.chance and M.Porcentaje(r.chance) or nil
				fl.ir = (src.npc and { kind = "npc", id = src.npc }) or (src.object and { kind = "object", id = src.object })
					or (src.item and { kind = "item", id = src.item }) or nil
			end
			if r.map and r.x and r.y and M.F and M.F.Punto then fl.punto = M.F.Punto(r.map, r.x, r.y, r.f, r.label) end
			if r.guideable then fl.guia = { kind = kind, id = id, fila = r } end
			fl.tenue = not r.available or nil
		end
		fl.texto = detalle
		filas[#filas + 1] = fl
	end
	-- La facción: la que te sirve primero, y «también en…».
	local ls = ordenLados(b)
	if ls[1] then
		ins[#ins + 1] = { bandoTexto(ls[1]), bandoTono(ls[1]), bandoIcono(ls[1]) }
		local mas = {}
		for k = 2, #ls do mas[#mas + 1] = bandoTexto(ls[k]) end
		if #mas > 0 then ins[#ins + 1] = { format(L["También en: %s"], concat(mas, ", ")), "neutro" } end
		local zonas = {}
		for _, l in ipairs(ls) do
			local zs = zonasDe(lista, l)
			if #zs > 0 then zonas[#zonas + 1] = bandoTexto(l) .. ": " .. concat(zs, ", ") end
		end
		local texto = #mas > 0 and format(L["%s, y también en %s"], bandoTexto(ls[1]), concat(mas, ", ")) or bandoTexto(ls[1])
		filas[#filas + 1] = { icono = { ic = bandoIcono(ls[1]), tono = bandoTono(ls[1]) == "neutro" and "acento" or (ls[1] == BANDO.A and "acento" or "peligro") },
			titulo = texto, texto = #zonas > 0 and concat(zonas, M.SEP) or L["Según quién lo da y dónde está."] }
	end
	-- Las insignias de cómo se consigue van antes de las que ya tenía la ficha.
	local antes = f.insignias or {}
	f.insignias = ins
	for _, x in ipairs(antes) do f.insignias[#f.insignias + 1] = x end
	-- La sección va primero (antes de las de cada fuente).
	local s = { clave = "origen", titulo = L["Cómo se consigue"], filas = filas, total = #filas }
	table.insert(f.secciones, 1, s)
end

---------------------------------------------------------------------------
-- Para los filtros: todo el catálogo, por lotes, una vez
---------------------------------------------------------------------------
function O.Listo() return listo end

function O.Fila(i)
	local c = filas
	if not c then return 0, 0, nil end
	local v = c.org[i]
	if not v then return 0, 0, nil end
	return v % 65536, floor(v / 65536), c.prob[i] or nil
end

local function paso()
	local C = Codex()
	local c = M.Cat.Col("objeto")
	local i = 0
	local org, prob = {}, {}
	return function()
		if not (C and c) then return true end
		local hasta = min(c.n, i + 40)
		for j = i + 1, hasta do
			local id = c.id[j]
			local m, b, p = O.Resumen(id)
			org[j], prob[j] = m + b * 65536, p or false
		end
		i = hasta
		O.avance = c.n > 0 and i / c.n or 1
		if i >= c.n then
			filas = { org = org, prob = prob }
			return true
		end
		return false
	end
end

function O.Preparar(fn)
	if listo then return K.Llamar(fn, true) end
	if not Codex() then return K.Llamar(fn, false) end
	if armando then
		if fn then M.Tarea("origenes", nil, fn) end
		return
	end
	armando = true
	M.Cat.Pedir("objeto", function(ok)
		if not ok then armando = false if fn then K.Llamar(fn, false) end return end
		M.Tarea("origenes", paso(), function(bien)
			listo, armando = bien and true or false, false
			if M.alIndice then K.Llamar(M.alIndice, "origenes") end
			if fn then K.Llamar(fn, bien) end
		end)
	end)
end

-- ¿Pasa los filtros «Cómo se consigue» y «Facción»?
local ORIGEN_BITS = {
	mision = BIT.mision, serie = BIT.serie, vendedor = BIT.vendedor, fabricado = BIT.fabricado,
}
function O.Pasa(m, b, origen, bando)
	if origen then
		if origen == "recoger" then
			if not (tiene(m, BIT.pesca) or tiene(m, BIT.recoleccion)) then return false end
		elseif origen == "mundo" then
			if not (tiene(m, BIT.mundo) or tiene(m, BIT.botin)) then return false end
		elseif origen == "suelta" then
			if not (tiene(m, BIT.suelta) or tiene(m, BIT.botin)) then return false end
		elseif not tiene(m, ORIGEN_BITS[origen] or 0) then
			return false
		end
	end
	if bando then
		if bando == "mio" then
			local mio = M.MiBando and M.MiBando()
			local l = mio == "A" and BANDO.A or mio == "H" and BANDO.H or nil
			-- Sin facción conocida (lo que se fabrica, por ejemplo) es para todos.
			if b ~= 0 and not (tiene(b, BANDO.N) or (l and tiene(b, l))) then return false end
		elseif not tiene(b, BANDO[bando] or 0) then
			return false
		end
	end
	return true
end

O.ORIGENES = {
	{ valor = false, texto = L["Cómo se consigue"] },
	{ valor = "suelta", texto = L["Lo sueltan [etiqueta]"] },
	{ valor = "mision", texto = L["Misión"] },
	{ valor = "serie", texto = L["Serie de misiones"] },
	{ valor = "vendedor", texto = L["Vendedor"] },
	{ valor = "fabricado", texto = L["Fabricado"] },
	{ valor = "recoger", texto = L["Pesca y recolección"] },
	{ valor = "mundo", texto = L["Mundo"] },
}
O.BANDOS = {
	{ valor = false, texto = L["Toda facción"] },
	{ valor = "mio", texto = L["Tu facción"] },
	{ valor = "A", texto = L["Alianza"] },
	{ valor = "H", texto = L["Horda"] },
	{ valor = "N", texto = L["Neutral"] },
}
