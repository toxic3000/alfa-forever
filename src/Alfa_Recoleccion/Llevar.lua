-- Alfa - Recolección: «Llévame» a un material que se recolecta (toxic3000 /
-- La Jauría, GPL-3.0). 1.3.9, pedido de Toxic: «Buscando plata me manda a un
-- lugar donde literalmente no hay».
--
-- En lugar de un punto suelto, la zona con más probabilidad:
--   * de tu facción (o en disputa) y que tu nivel aguante (no muy por encima
--     de ti; una gris vale, pero cuenta menos);
--   * con más puntos del nodo y mejor densidad (puntos por área);
--   * un mineral raro que sale en lugar de otro (la plata en vetas de estaño
--     y cobre, el oro en hierro, la veraplata en mitril) cuenta también los
--     puntos del nodo común donde puede salir, y se dice.
-- Ahí se arma la ruta circular de Ruta.lua por todos esos puntos y la flecha
-- va al más cercano; los puntos vacíos se saltan solos (Ruta.lua).
--
--   Ll.GruposDe(itemID) -> { clave, ... }          los nodos que dan ese objeto
--   Ll.Zonas({ claves, anfitriones, nivel, faccion, actual }) -> { zona, ... }
--       zona = { mapa, puntos, propios, anfitrion, min, max, puntaje, densidad }
--   Ll.Motivo(z, op) -> «Mejor para tu nivel: Bosque del Ocaso, 34 puntos, nivel 18–30.»
--   Ll.Llevar(itemID | clave) -> ok, zona | false, motivo
--   AlfaRecoleccion.Llevar / .Zonas / .GruposDe (para las guías de oficios,
--   Comercio, la Enciclopedia y Planes)

local _, M = ...
local N = AlfaNucleo
local A = N.A
local R, Ruta = M.R, M.Ruta
local L = N.Textos(M.EN)

local type, ipairs, pairs, floor, max, min, format = type, ipairs, pairs, math.floor, math.max, math.min, string.format

local Ll = {}
M.Llevar = Ll

-- De quién es cada zona abierta: "A" Alianza, "H" Horda, "C" en disputa.
Ll.ZONAS = {
	[1411] = "H", [1412] = "H", [1413] = "H", [1420] = "H", [1421] = "H",
	[1426] = "A", [1429] = "A", [1431] = "A", [1432] = "A", [1433] = "A", [1436] = "A", [1437] = "A", [1438] = "A", [1439] = "A",
	[1416] = "C", [1417] = "C", [1418] = "C", [1419] = "C", [1422] = "C", [1423] = "C", [1424] = "C", [1425] = "C",
	[1427] = "C", [1428] = "C", [1430] = "C", [1434] = "C", [1435] = "C", [1440] = "C", [1441] = "C", [1442] = "C",
	[1443] = "C", [1444] = "C", [1445] = "C", [1446] = "C", [1447] = "C", [1448] = "C", [1449] = "C", [1450] = "C",
	[1451] = "C", [1452] = "C", [2482] = "C", [2521] = "C", [2548] = "C",
}
-- En disputa, pero con más pueblos de un lado.
Ll.LEAN = { [1441] = "H", [1442] = "H", [1440] = "A", [1425] = "A" }

-- Los raros que salen en los mismos puntos que un nodo común.
Ll.EN_LUGAR = {
	silver_vein = { "tin_vein", "copper_vein" },
	gold_vein = { "iron_deposit" },
	truesilver_deposit = { "mithril_deposit" },
}
-- Las piedras salen del mineral de su veta.
Ll.PIEDRAS = { [2835] = "copper_vein", [2836] = "tin_vein", [2838] = "iron_deposit", [7912] = "mithril_deposit", [12365] = "small_thorium_vein" }

local function grupo(clave) return M.GRUPOS[M.porClave[clave or ""] or 0] end

-- Los nodos (del juego clásico: con sus cuatro colores) que dan un objeto.
function Ll.GruposDe(item)
	local out = {}
	if type(item) ~= "number" then return out end
	if Ll.PIEDRAS[item] then return { Ll.PIEDRAS[item] } end
	for _, gr in ipairs(M.GRUPOS) do
		if gr.item == item and type(gr.niveles) == "table" and #gr.niveles == 4 and (gr.tipo == "mineria" or gr.tipo == "hierbas") then
			out[#out + 1] = gr.clave
		end
	end
	return out
end

-- Puntos de un nodo por zona (de la base incluida), una vez por nodo.
local cuentas = {}
function Ll.Puntos(clave)
	local t = cuentas[clave]
	if t then return t end
	t = {}
	local gr = grupo(clave)
	for _, oid in ipairs(gr and gr.ids or {}) do
		for mapa, xy in pairs((M.BASE or {})[oid] or {}) do
			-- La base compacta (dist) trae cada zona como texto «x,y,x,y».
			local n = 0
			if type(xy) == "string" then
				local _, comas = xy:gsub(",", ",")
				n = xy == "" and 0 or floor((comas + 1) / 2)
			elseif type(xy) == "table" then
				n = floor(#xy / 2)
			end
			if Ll.ZONAS[mapa] and n > 0 then t[mapa] = (t[mapa] or 0) + n end
		end
	end
	cuentas[clave] = t
	return t
end

local function jugador()
	local C = A.Compat
	local p = C and C.GetPlayerInfo and C.GetPlayerInfo() or {}
	return p
end

local function nivelesDe(mapa)
	local Mp = A.Maps
	if Mp and Mp.GetZoneLevels then
		local a, b = Mp.GetZoneLevels(mapa)
		if a then return a, b end
	end
	return nil
end

-- Cuánto vale una zona por tu nivel: muy por encima de ti casi nada; gris, un poco menos.
function Ll.FactorNivel(zmin, zmax, nivel)
	if not (zmin and nivel) then return 1 end
	if zmin > nivel + 6 then return 0.1 end
	if zmin > nivel + 2 then return 0.55 end
	if zmax and zmax < nivel - 12 then return 0.85 end
	return 1
end

function Ll.FactorFaccion(mapa, fac)
	local z = Ll.ZONAS[mapa]
	if not z then return 0 end
	if z == "C" then
		local lean = Ll.LEAN[mapa]
		if not lean or not fac then return 1 end
		return lean == fac and 1.1 or 0.85
	end
	if not fac then return 1 end
	return z == fac and 1.3 or 0.05
end

-- 1.4.0 (plan 73, Toxic: «buscando estaño en Los Humedales a nivel 33 me
-- mandaba a casi 2,000 yardas»): las yardas de donde estás (c, wx, wy) al
-- nodo más cercano de esas claves en una zona (los puntos de la base y los
-- que descubriste). -> yardas | nil (otro continente o sin datos)
function Ll.Distancia(claves, mapa, c, wx, wy)
	local b = c and R.Limites(mapa)
	if not (b and b.c == c) then return nil end
	local mejor
	local function medir(x, y)
		local _, px, py = R.AlMundo(b, x, y)
		local dx, dy = px - wx, py - wy
		local d = dx * dx + dy * dy
		if not mejor or d < mejor then mejor = d end
	end
	for _, clave in ipairs(claves or {}) do
		local gr = grupo(clave)
		for _, oid in ipairs(gr and gr.ids or {}) do
			local xy = ((M.BASE or {})[oid] or {})[mapa]
			if type(xy) == "string" then
				for x, y in xy:gmatch("([%d%.]+),([%d%.]+)") do medir(tonumber(x), tonumber(y)) end
			elseif type(xy) == "table" then
				for i = 1, #xy - 1, 2 do medir(xy[i], xy[i + 1]) end
			end
		end
	end
	return mejor and math.sqrt(mejor) or nil
end

-- Cuánto vale una zona por lo lejos que está: la tuya (o junto a ti) entera;
-- a 1,200 yardas, la mitad; en otro continente, poco.
function Ll.FactorCerca(d, hayPosicion)
	if not hayPosicion then return 1 end
	if not d then return 0.25 end
	return 1 / (1 + d / 1200)
end

-- op: { claves = { clave, ... }, anfitriones = { clave, ... } (cuentan la mitad),
--   nivel, faccion ("A" | "H"), actual (mapa donde estás), pos = { c, wx, wy } (dónde estás) }
function Ll.Zonas(op)
	op = op or {}
	local p = jugador()
	local nivel = op.nivel or p.level or 1
	local fac = op.faccion or (p.faction == "Alliance" and "A") or (p.faction == "Horde" and "H") or nil
	local actual, pos = op.actual, op.pos
	if not actual or not pos then
		local m, _, _, c, wx, wy = R.PosicionJugador()
		actual = actual or m
		if not pos and c and wx then pos = { c, wx, wy } end
	end
	local por = {}
	local function sumar(clave, campo, peso)
		for mapa, n in pairs(Ll.Puntos(clave)) do
			local z = por[mapa]
			if not z then
				z = { mapa = mapa, propios = 0, anfitrion = 0 }
				por[mapa] = z
			end
			z[campo] = z[campo] + n
			z.efectivo = (z.efectivo or 0) + n * peso
		end
	end
	for _, c in ipairs(op.claves or {}) do sumar(c, "propios", 1) end
	for _, c in ipairs(op.anfitriones or {}) do sumar(c, "anfitrion", 0.5) end
	local lista, densMax = {}, 0
	for mapa, z in pairs(por) do
		z.puntos = z.propios + z.anfitrion
		local b = R.Limites(mapa)
		local area = b and (b.ancho * b.alto) / 1e6 or nil
		z.densidad = area and area > 0 and z.efectivo / area or nil
		if z.densidad and z.densidad > densMax then densMax = z.densidad end
		z.min, z.max = nivelesDe(mapa)
		lista[#lista + 1] = z
	end
	local todas = {}
	for _, c in ipairs(op.claves or {}) do todas[#todas + 1] = c end
	for _, c in ipairs(op.anfitriones or {}) do todas[#todas + 1] = c end
	for _, z in ipairs(lista) do
		local dens = (z.densidad and densMax > 0) and z.densidad / densMax or 0.5
		-- 1.4.0: lo cerca que está el nodo más cercano de esa zona.
		if pos and Ll.FactorFaccion(z.mapa, fac) > 0.1 then z.distancia = Ll.Distancia(todas, z.mapa, pos[1], pos[2], pos[3]) end
		z.puntaje = z.efectivo * Ll.FactorFaccion(z.mapa, fac) * Ll.FactorNivel(z.min, z.max, nivel) * (0.7 + 0.3 * dens)
			* (z.mapa == actual and 1.15 or 1) * Ll.FactorCerca(z.distancia, pos ~= nil)
	end
	table.sort(lista, function(a, b)
		if a.puntaje ~= b.puntaje then return a.puntaje > b.puntaje end
		return a.mapa < b.mapa
	end)
	-- Las que no valen para ti (de la otra facción) no se ofrecen.
	local out = {}
	for _, z in ipairs(lista) do
		if z.puntaje > 0 and Ll.FactorFaccion(z.mapa, fac) > 0.1 then out[#out + 1] = z end
	end
	return out
end

local function nombreZona(mapa)
	local C = A.Compat
	local n = C and (C.GetMapName and C.GetMapName(mapa) or (C.MapName and C.MapName(mapa)))
	return type(n) == "string" and n ~= "" and n or ("#" .. tostring(mapa))
end
Ll.NombreZona = nombreZona

local function nombreNodo(clave)
	local g = M.porClave[clave or ""]
	return g and R.Nombre(g) or tostring(clave)
end

-- La línea de por qué esa zona.
function Ll.Motivo(z, op)
	if not z then return nil end
	local partes = {}
	if z.min and z.max then
		partes[1] = format(L["Mejor para tu nivel: %s, %d puntos, nivel %d–%d."], nombreZona(z.mapa), z.puntos, z.min, z.max)
	else
		partes[1] = format(L["La mejor zona: %s, %d puntos."], nombreZona(z.mapa), z.puntos)
	end
	local raro, anfitrion = op and op.claves and op.claves[1], op and op.anfitriones and op.anfitriones[1]
	if raro and anfitrion and (z.anfitrion or 0) > 0 then
		partes[2] = format(L["%s sale a veces en lugar de %s: aquí hay %d."], nombreNodo(raro), nombreNodo(anfitrion), z.anfitrion)
	end
	-- 1.4.0: lo cerca que está.
	if z.distancia then
		local d = A.FormatDistance and A.FormatDistance(z.distancia) or (floor(z.distancia + 0.5) .. " yd")
		partes[#partes + 1] = format(L["El más cercano está a %s de ti."], d)
	end
	return table.concat(partes, " ")
end

-- Lo que pide un objeto o un nodo: { claves, anfitriones, tipo }.
function Ll.Pedido(cosa)
	local claves = type(cosa) == "number" and Ll.GruposDe(cosa) or (grupo(cosa) and { cosa } or {})
	if #claves == 0 then return nil end
	local anf, visto = {}, {}
	for _, c in ipairs(claves) do visto[c] = true end
	for _, c in ipairs(claves) do
		for _, h in ipairs(Ll.EN_LUGAR[c] or {}) do
			if not visto[h] then visto[h] = true anf[#anf + 1] = h end
		end
	end
	return { claves = claves, anfitriones = anf, tipo = grupo(claves[1]).tipo }
end

---------------------------------------------------------------------------
-- Buscar por lo que escribes: «plata», «mena de plata», «silver», «veta de
-- plata» y «Silver Ore» son lo mismo (el nodo y lo que da, en español e inglés).
---------------------------------------------------------------------------
local ACENTOS = { ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u", ["ñ"] = "n" }
local RELLENO = { "mena de ", "mena ", "veta de ", "veta ", "filon de ", "filon ", "deposito de ", "deposito ",
	"formacion de ", " ore", " vein", " deposit", " bar", "barra de ", "mineral de ", "mineral ", "piedra de ", "trozo de " }

function Ll.Plegar(s)
	s = (type(s) == "string" and s or ""):lower()
	s = s:gsub("[\195][\128-\191]", function(c) return ACENTOS[c] or c end)
	s = " " .. s:gsub("[^%w%s']", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "") .. " "
	return s
end
local function nucleo(s)
	s = Ll.Plegar(s)
	for _, r in ipairs(RELLENO) do s = s:gsub(r, " ") end
	return (s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end
Ll.Nucleo = nucleo

-- -> clave | nil (el nodo clásico que mejor coincide)
function Ll.Buscar(texto)
	local q = nucleo(texto)
	if q == "" then return nil end
	local mejor, puntos
	for _, gr in ipairs(M.GRUPOS) do
		if (gr.tipo == "mineria" or gr.tipo == "hierbas") and type(gr.niveles) == "table" then
			local nombres = { gr.es, gr.en }
			for _, a in ipairs(gr.alias or {}) do nombres[#nombres + 1] = a end
			for _, n in ipairs(nombres) do
				local c = nucleo(n)
				local p
				if c == q then p = 3
				elseif (" " .. c .. " "):find(" " .. q .. " ", 1, true) then p = 2
				elseif #q >= 4 and c:find(q, 1, true) then p = 1 end
				if p then
					if #gr.niveles == 4 then p = p + 0.5 end
					-- «plata» es el filón de plata, no el de «plata estelar»: el nombre más corto gana.
					p = p - #c / 1000
					if not puntos or p > puntos then mejor, puntos = gr.clave, p end
				end
			end
		end
	end
	return mejor
end

-- La zona y la ruta: -> true, zona | false, motivo
function Ll.Llevar(cosa, op)
	if type(cosa) == "string" and not grupo(cosa) then cosa = Ll.Buscar(cosa) end
	local pd = Ll.Pedido(cosa)
	if not pd then return false, "nodo" end
	if InCombatLockdown and InCombatLockdown() then return false, "combate" end
	op = op or {}
	op.claves, op.anfitriones = pd.claves, pd.anfitriones
	local zonas = Ll.Zonas(op)
	local z = zonas[1]
	-- 1.4.1: la zona que elegiste («Cerca de ti», «Recomendado» u otra).
	if op.zona then
		for _, x in ipairs(zonas) do if x.mapa == op.zona then z = x end end
	elseif op.modo == "cerca" then
		z = Ll.MasCerca(zonas) or z
	end
	if not z then return false, "zona" end
	local set = {}
	for _, c in ipairs(pd.claves) do set[c] = true end
	for _, c in ipairs(pd.anfitriones) do set[c] = true end
	-- 1.4.0 (plan 73): un circuito corto por las paradas más cercanas a ti
	-- (o a tu lado de la zona), no la vuelta a toda la zona: para juntar N,
	-- unas N × 0,75 + 6 paradas (cada veta da 1 a 3 y alguna estará vacía).
	local cerca = op.todo and nil or (op.cuenta and max(10, min(30, math.ceil(op.cuenta * 0.75) + 6)) or 24)
	local ok, por = Ruta.Crear(pd.tipo, set, z.mapa, function(r)
		if r then
			Ruta.Guiar()
			if op.alListo then op.alListo(r, z) end
		end
	end, { cerca = cerca, deGuia = op.deGuia })
	if not ok then return false, por end
	local texto = Ll.Motivo(z, op)
	local K = N.Kit
	if op.silencio then
		-- quien pidió la ruta lo dice a su manera
	elseif K and K.Aviso then
		K.Aviso({ titulo = format(L["Ruta a %s"], nombreNodo(pd.claves[1])), texto = texto, icono = "ic-flecha", tono = "acento" })
	else
		N.Imprimir(texto)
	end
	Ll.ultima = { zona = z, texto = texto, claves = pd.claves }
	return true, z
end

---------------------------------------------------------------------------
-- 1.4.1 (Toxic: «me sigues mandando al mismo lugar una y otra vez; que al
-- elegir el material venga Buscar cerca o Ir al lugar recomendado, para
-- saber a dónde me va a llevar, porque si es lejos implica dinero»): antes de
-- salir, eliges. Cada opción dice la zona, lo lejos que está y si es a pie o
-- si quizá necesites vuelo o barco (eso cuesta oro).
---------------------------------------------------------------------------
local LEJOS_A_PIE = 1600 -- yardas: más que esto, quizá te convenga volar

-- La zona con el nodo más cercano a ti (en tu continente), de las que valen.
function Ll.MasCerca(zonas)
	local mejor
	for _, z in ipairs(zonas or {}) do
		if z.distancia and (not mejor or z.distancia < mejor.distancia) then mejor = z end
	end
	return mejor
end

-- Cómo se llega: { texto, lejos } — «320 yd, unos 1 min a pie»,
-- «1,9 km: quizá te convenga volar (cuesta oro)», «En otro continente: barco o vuelo (cuesta oro)».
function Ll.Viaje(z)
	if not z then return nil end
	if not z.distancia then
		return { texto = L["En otro continente: barco o vuelo (cuesta oro)"], lejos = true }
	end
	local d = A.FormatDistance and A.FormatDistance(z.distancia) or (floor(z.distancia + 0.5) .. " yd")
	local mins = max(1, floor(z.distancia / 7 / 60 + 0.5)) -- a pie, unas 7 yd/s
	if z.distancia > LEJOS_A_PIE then
		return { texto = format(L["%s: quizá te convenga volar (cuesta oro)"], d), lejos = true }
	end
	return { texto = format(L["%s, unos %d min a pie"], d, mins), lejos = false }
end

-- Las opciones para elegir: { { modo, zona, titulo, texto, icono }, ... }
-- (la primera, «Cerca de ti»; luego «Recomendado» si es otra zona; luego hasta 3 más).
function Ll.Opciones(cosa)
	if type(cosa) == "string" and not grupo(cosa) then cosa = Ll.Buscar(cosa) end
	local pd = Ll.Pedido(cosa)
	if not pd then return {} end
	local op = { claves = pd.claves, anfitriones = pd.anfitriones }
	local zonas = Ll.Zonas(op)
	local out, puestas = {}, {}
	local function linea(z)
		local partes = { nombreZona(z.mapa) }
		if z.min and z.max then partes[#partes + 1] = format(L["nivel %d–%d"], z.min, z.max) end
		partes[#partes + 1] = format(L["%d puntos"], z.puntos or 0)
		return table.concat(partes, " · ")
	end
	local function poner(modo, z, titulo, icono)
		if not z or puestas[z.mapa] then return end
		puestas[z.mapa] = true
		local v = Ll.Viaje(z)
		out[#out + 1] = { modo = modo, zona = z.mapa, titulo = titulo, texto = linea(z) .. (v and (" · " .. v.texto) or ""),
			lejos = v and v.lejos or false, icono = icono, z = z }
	end
	local cerca = Ll.MasCerca(zonas)
	-- (si la más cercana es también la recomendada, se dice una vez y con las dos)
	poner("cerca", cerca, (cerca and zonas[1] and cerca.mapa == zonas[1].mapa) and L["Cerca de ti y recomendado"] or L["Cerca de ti"], "ic-huella")
	poner("recomendado", zonas[1], L["El lugar recomendado"], "ic-exito")
	for i = 2, #zonas do
		if #out >= 5 then break end
		poner("zona", zonas[i], L["Otra zona"], "ic-mapa")
	end
	return out, op
end

-- El menú para elegir, colgado de un botón (la Enciclopedia, Comercio).
-- Sin botón (o sin opciones para elegir), directo al lugar recomendado.
function Ll.Elegir(cosa, dueno, alListo)
	local K = N.Kit
	local opciones = Ll.Opciones(cosa)
	if #opciones <= 1 or not (dueno and K and K.Menu) then
		local ok, z = Ll.Llevar(cosa, opciones[1] and { zona = opciones[1].zona } or nil)
		if alListo then alListo(ok, z) end
		return ok, z
	end
	local items = {}
	for i, o in ipairs(opciones) do
		items[i] = { valor = i, icono = o.icono, texto = o.titulo .. ": " .. o.texto }
	end
	K.Menu(dueno, items, nil, function(i)
		local o = opciones[i]
		if not o then return end
		local ok, z = Ll.Llevar(cosa, { zona = o.zona })
		if alListo then alListo(ok, z) end
	end, 420)
	return true, "menu"
end

AlfaRecoleccion = type(rawget(_G, "AlfaRecoleccion")) == "table" and rawget(_G, "AlfaRecoleccion") or {}
AlfaRecoleccion.Opciones = function(cosa) return Ll.Opciones(cosa) end
AlfaRecoleccion.Elegir = function(cosa, dueno, alListo) return Ll.Elegir(cosa, dueno, alListo) end
AlfaRecoleccion.Llevar = function(cosa, op) return Ll.Llevar(cosa, op) end
AlfaRecoleccion.Zonas = function(op) return Ll.Zonas(op) end
AlfaRecoleccion.GruposDe = function(item) return Ll.GruposDe(item) end
AlfaRecoleccion.Motivo = function(z, op) return Ll.Motivo(z, op) end
AlfaRecoleccion.Puntos = function(clave) return Ll.Puntos(clave) end
AlfaRecoleccion.Buscar = function(texto) return Ll.Buscar(texto) end
