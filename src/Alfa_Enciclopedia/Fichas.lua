-- Alfa - Enciclopedia: lo que dice la ficha de cada cosa (toxic3000 / La Jauría).
-- GPL-3.0.
--
-- Cada función arma un modelo (solo datos, sin marcos) que Ventana.lua
-- dibuja. Una sección sin datos no se agrega: la ficha nunca muestra algo
-- vacío. Las fuentes las ordena el motor (Lookup.Sources: lo que puedes
-- hacer primero, luego lo más rápido para ti).
--
--   F.Construir(kind, id) -> ficha | nil
--   ficha = { kind, id, icono = { objeto, calidad } | { ic, tono }, sobre, titulo, color = { r, g, b },
--             subtitulo, insignias = { { texto, tono } }, mejor = { sobre, titulo, texto, ir },
--             datos = { titulo, filas = { { etiqueta, valor } } }, nota,
--             acciones = { guiar = fn, mapa = { punto, ... }, ruta = fn, vincular = fn },
--             secciones = { { clave, titulo, filas, total } } }
--   fila  = { icono, titulo, color, texto, valor, tenue, ir = { kind, id }, punto = { map, x, y, f, nombre, icono },
--             guia = { kind, id, fila del motor } }

local ADDON, M = ...
local A, L, K, N = M.A, M.L, M.K, M.N
local F = {}
M.F = F
local I = M.Indices

local type, tonumber, tostring, ipairs, pairs, pcall = type, tonumber, tostring, ipairs, pairs, pcall
local floor, max, min, format = math.floor, math.max, math.min, string.format
local sort, concat = table.sort, table.concat
local SEP = M.SEP

local function Codex() return M.CodexListo() end
local function Lk() return A.Lookup end

-- Si ya armaste una ruta propia en la página Ruta (sus datos de cuenta,
-- N.Datos("rutas").rutas, solo se leen).
local function tienesRuta()
	local d = N.Datos and N.Datos("rutas")
	return type(d) == "table" and type(d.rutas) == "table" and next(d.rutas) ~= nil
end

-- Por qué una fuente no es para ti todavía (los códigos del motor, en palabras de Alfa).
local POR_QUE = {
	faction = L["De la otra facción"], race = L["No es para tu raza"], class = L["No es para tu clase"],
	level = L["Aún no tienes el nivel"], done = L["Ya la hiciste"], reputation = L["Te falta reputación"],
	profession = L["Te falta la profesión"], retired = L["Ya no se consigue"], pre = L["Antes necesitas otra misión"],
}
F.POR_QUE = POR_QUE

local function viaje(seg)
	seg = tonumber(seg)
	if not seg then return nil end
	if seg < 60 then return L["a menos de 1 min"] end
	local m = floor(seg / 60 + 0.5)
	if m < 60 then return format(L["a %d min"], m) end
	return format(L["a %d h %d min"], floor(m / 60), m % 60)
end
F.Viaje = viaje

local function unir(...)
	local t = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v and v ~= "" then t[#t + 1] = v end
	end
	return concat(t, SEP)
end
F.Unir = unir

local function nivelTexto(a, b)
	if not a then return nil end
	if b and b ~= a then return format(L["Nivel %d–%d"], a, b) end
	return format(L["Nivel %d"], a)
end

local function punto(map, x, y, f, nombre, icono, z)
	if not (map and x and y) then return nil end
	return { map = map, x = x, y = y, f = f, nombre = nombre, icono = icono, z = z }
end

local function colorObjeto(id)
	local C = Codex()
	local q
	if C then
		local ok, r = pcall(C.Item, id)
		q = ok and r and r.quality
	end
	if not q then
		local ok, v = pcall(C_Item.GetItemQualityByID, id)
		q = ok and v or nil
	end
	local r, g, b = M.ColorCalidad(q)
	return r and { r, g, b } or nil, q
end

local function filaObjeto(id, texto, valor)
	local color, q = colorObjeto(id)
	return { icono = { objeto = id, calidad = q }, titulo = M.Nombre("item", id), color = color, texto = texto, valor = valor,
		ir = { kind = "item", id = id } }
end

local function filaMision(id, texto)
	local C = Codex()
	local q = C and C.Quest(id)
	local hecha = A.Compat.IsQuestCompleted(id)
	return { icono = { ic = "ic-misiones", tono = hecha and "exito" or "oro" }, titulo = q and q.title or M.Nombre("quest", id),
		color = "mision", texto = unir(q and q.level and format(L["Nivel %d"], q.level) or nil, hecha and L["hecha"] or nil, texto),
		tenue = hecha or nil, ir = { kind = "quest", id = id } }
end

local function seccion(f, clave, titulo, filas, extra)
	if not (filas and #filas > 0) then return end
	local s = { clave = clave, titulo = titulo, filas = filas, total = #filas }
	if extra then for k, v in pairs(extra) do s[k] = v end end
	f.secciones[#f.secciones + 1] = s
	return s
end

local function nueva(kind, id)
	return { kind = kind, id = id, insignias = {}, secciones = {}, acciones = {} }
end

-- Para las fichas de Coleccion.lua y Legado.lua.
F.Nueva, F.Seccion, F.Punto, F.FilaObjeto, F.FilaMision = nueva, seccion, punto, filaObjeto, filaMision
F.NivelTexto = nivelTexto

-- Lugares para "Ver en el mapa": los de las filas, sin repetir y con tope.
local function puntosDe(secciones, tope)
	local out, visto = {}, {}
	for _, s in ipairs(secciones) do
		for _, fl in ipairs(s.filas) do
			local p = fl.punto
			if p and not fl.tenue then
				local clave = p.map .. ":" .. floor(p.x) .. ":" .. floor(p.y)
				if not visto[clave] then
					visto[clave] = true
					out[#out + 1] = p
					if #out >= (tope or 30) then return out end
				end
			end
		end
	end
	-- Si todo estaba atenuado, los atenuados.
	if #out == 0 then
		for _, s in ipairs(secciones) do
			for _, fl in ipairs(s.filas) do
				if fl.punto and #out < (tope or 30) then out[#out + 1] = fl.punto end
			end
		end
	end
	return out
end
F.PuntosDe = puntosDe

---------------------------------------------------------------------------
-- Los bancos de peces (objetos del Codex por su nombre en inglés)
---------------------------------------------------------------------------
local pesca
local function esPesca(objeto)
	if not pesca then
		pesca = {}
		local C = Codex()
		if C then
			C.Each("object", function(id, nombre)
				local n = type(nombre) == "string" and nombre:lower() or ""
				if n:find("school", 1, true) or n:find("wreckage", 1, true) or n:find("floating debris", 1, true)
					or n:find("oil spill", 1, true) or n:find("elemental water", 1, true) then
					pesca[id] = true
				end
			end)
		end
	end
	return pesca[objeto] == true
end
F.EsPesca = esPesca

---------------------------------------------------------------------------
-- Objetos
---------------------------------------------------------------------------
local ICONO_MAPA = {
	vendor = "map:vendor", drop = "map:kill", object = "map:loot", quest = "map:quest-available", craft = "map:trainer-profession",
	rep = "map:vendor", pvp = "map:battlemaster", gift = "map:target", spawn = "map:target", start = "map:quest-available",
	["end"] = "map:quest-turnin", entrance = "map:dungeon",
}
F.ICONO_MAPA = ICONO_MAPA

local function lugarDe(r, nombre)
	return punto(r.map, r.x, r.y, r.f, nombre or r.label, ICONO_MAPA[r.type])
end

-- Una fuente del motor -> fila de la ficha, y la sección a la que va.
local function filaFuente(r, kind, id)
	local C = Codex()
	local src = type(r.src) == "table" and r.src or {}
	local fl = { tenue = not r.available or nil, guia = r.guideable and { kind = kind, id = id, fila = r } or nil }
	local lugar = (r.zone or (r.map and M.Zona(r.map))) and M.Lugar(r.map, r.x, r.y) or nil
	local clave = r.type
	if r.type == "drop" then
		local npc = src.npc and C.Npc(src.npc)
		fl.icono = { ic = npc and npc.rare and "ic-raros" or "ic-personajes", tono = npc and npc.boss and "mazmorra" or "acento" }
		fl.titulo, fl.color = r.label, "pnj"
		fl.valor = M.Porcentaje(r.chance)
		fl.ir = src.npc and { kind = "npc", id = src.npc } or nil
		if r.instance then
			clave = "instancia"
			local inst = C.Instance(r.instance)
			fl.texto = unir(inst and inst.name, npc and npc.boss and L["jefe"] or nil)
			fl.icono = { ic = "ic-mazmorra", tono = "mazmorra" }
		else
			fl.texto = unir(npc and nivelTexto(npc.level, npc.levelMax), lugar, npc and npc.rare and L["raro"] or nil, npc and npc.elite and L["élite"] or nil)
		end
		fl.orden = -(r.chance or 0)
	elseif r.type == "vendor" then
		fl.icono = { ic = "ic-comercio", tono = "acento" }
		fl.titulo, fl.color = r.label, "pnj"
		fl.valor = r.price and r.price > 0 and N.Dinero(r.price, true) or nil
		fl.texto = unir(lugar, src.limited and L["pocas unidades, se reabastece con el tiempo"] or nil)
		fl.ir = src.npc and { kind = "npc", id = src.npc } or nil
	elseif r.type == "quest" then
		local q = src.quest and C.Quest(src.quest)
		fl.icono = { ic = "ic-misiones", tono = "oro" }
		fl.titulo, fl.color = r.label, "mision"
		fl.texto = unir(q and q.level and format(L["Nivel %d"], q.level), lugar, src.choice and L["a elegir"] or nil)
		fl.ir = src.quest and { kind = "quest", id = src.quest } or nil
	elseif r.type == "craft" then
		fl.icono = { ic = "ic-oficios", tono = "acento" }
		local prof = M.NombreProfesion(src.skillLine)
		fl.titulo = src.skill and src.skill > 0 and format(L["%s (%d)"], prof, src.skill) or prof
		local rec = I.Receta(src.spell)
		if rec then
			fl.texto = format(L["Se aprende con %s"], M.Nombre("item", rec))
			fl.ir = { kind = "item", id = rec }
		elseif lugar then
			fl.texto = format(L["Lo enseña un instructor en %s"], lugar)
		else
			fl.texto = L["Lo enseña un instructor de la profesión"]
		end
	elseif r.type == "object" then
		local pez = src.object and esPesca(src.object)
		clave = pez and "pesca" or "object"
		fl.icono = { ic = pez and "ic-pesca" or "ic-recoleccion", tono = "acento" }
		fl.titulo = r.label
		fl.valor = M.Porcentaje(r.chance)
		fl.texto = lugar
		fl.ir = src.object and { kind = "object", id = src.object } or nil
		fl.orden = -(r.chance or 0)
	elseif r.type == "container" then
		local color, q
		if src.item then color, q = colorObjeto(src.item) end
		fl.icono = { objeto = src.item, calidad = q }
		fl.titulo, fl.color = r.label, color
		fl.valor = M.Porcentaje(r.chance)
		fl.ir = src.item and { kind = "item", id = src.item } or nil
		fl.orden = -(r.chance or 0)
	elseif r.type == "rep" then
		fl.icono = { ic = "ic-manada", tono = "acento" }
		fl.titulo = r.label
		fl.texto = unir(src.standing and format(L["Con reputación %s"], M.NombreReputacion(src.standing) or "") or nil,
			src.npc and M.Nombre("npc", src.npc) or nil, lugar)
		fl.ir = src.npc and { kind = "npc", id = src.npc } or nil
	elseif r.type == "pvp" then
		fl.icono = { ic = "ic-alerta", tono = "peligro" }
		fl.titulo = src.rank and format(L["Rango de honor %d"], src.rank) or L["Honor"]
		fl.texto = unir(src.npc and M.Nombre("npc", src.npc) or nil, lugar)
		fl.ir = src.npc and { kind = "npc", id = src.npc } or nil
	elseif r.type == "gift" then
		fl.icono = { ic = "ic-personajes", tono = "acento" }
		fl.titulo, fl.color = r.label, "pnj"
		fl.texto = lugar
		fl.ir = src.npc and { kind = "npc", id = src.npc } or nil
	elseif r.type == "world" then
		fl.icono = { ic = "ic-mundo", tono = "acento" }
		fl.titulo = L["Cualquier criatura de su nivel"]
		fl.texto = src.minLevel and src.maxLevel and format(L["Criaturas de nivel %d a %d"], src.minLevel, src.maxLevel) or nil
	else
		return nil
	end
	if r.map and r.x then fl.punto = lugarDe(r) end
	if fl.tenue then
		fl.texto = unir(POR_QUE[r.why] or L["Todavía no es para ti"], fl.texto)
	elseif r.travel and r.type ~= "craft" and clave ~= "instancia" then
		-- El viaje solo en las fuentes que se recorren.
		fl.viaje = viaje(r.travel)
	end
	return fl, clave
end

local SECCIONES_OBJETO = {
	{ "vendor", L["Se vende en"] },
	{ "drop", L["Lo sueltan"] },
	{ "instancia", L["En mazmorras y bandas"] },
	{ "quest", L["Recompensa de misión"] },
	{ "craft", L["Se fabrica"] },
	{ "pesca", L["Se pesca"] },
	{ "object", L["En el mundo"] },
	{ "container", L["Dentro de"] },
	{ "rep", L["Por reputación"] },
	{ "pvp", L["Por honor (JcJ)"] },
	{ "gift", L["Te lo da un PNJ"] },
	{ "world", L["Botín del mundo"] },
}

-- Las estadísticas de la base de objetos del motor, en un orden fijo.
local STATS = {
	{ "armor", L["Armadura"] }, { "str", L["Fuerza"] }, { "agi", L["Agilidad"] }, { "sta", L["Aguante"] },
	{ "int", L["Intelecto"] }, { "spi", L["Espíritu"] }, { "ap", L["Poder de ataque"] }, { "rap", L["Poder de ataque a distancia"] },
	{ "crit", L["Golpe crítico"], "%" }, { "hit", L["Golpe"], "%" }, { "defense", L["Defensa"] }, { "dodge", L["Esquiva"], "%" },
	{ "parry", L["Parada"], "%" }, { "block", L["Bloqueo"], "%" }, { "sp", L["Poder con hechizos"] }, { "heal", L["Sanación"] },
	{ "mp5", L["Maná cada 5 s"] }, { "hp5", L["Salud cada 5 s"] },
}

local function estadisticas(rec)
	if not (rec and type(rec.stats) == "table") then return nil end
	local filas = {}
	local s = rec.stats
	if type(s.dps) == "number" and s.dps > 0 then
		filas[#filas + 1] = { L["Daño por segundo"], M.Decimal(s.dps) }
		if rec.speed then filas[#filas + 1] = { L["Velocidad"], M.Decimal(rec.speed / 1000, 2) .. " s" } end
	end
	for _, d in ipairs(STATS) do
		local v = s[d[1]]
		if type(v) == "number" and v ~= 0 then filas[#filas + 1] = { d[2], (v > 0 and d[1] ~= "armor" and "+" or "") .. v .. (d[3] or "") } end
	end
	if #filas == 0 then return nil end
	return { titulo = L["Estadísticas"], filas = filas }
end

-- "Arma · Espada de una mano" y la línea de debajo.
local function tipoTexto(kind, cls, sb)
	if kind == "mount" then return L["Montura"] end
	if kind == "pet" then return L["Mascota"] end
	if kind == "recipe" then
		local s = cls == 9 and sb and M.Cat.NombreSubtipo(9, sb)
		return s and (L["Receta"] .. SEP .. s) or L["Receta"]
	end
	if not cls or cls < 0 then return L["Objeto"] end
	local t = M.Cat.NombreTipo(cls)
	local s = sb and sb >= 0 and M.Cat.NombreSubtipo(cls, sb)
	if s and s ~= t then return t .. SEP .. s end
	return t
end

function F.Objeto(id)
	local C = Codex()
	local rec = C and C.Item(id)
	if not rec then return nil end
	local kind = rec.kind or "item"
	local f = nueva(kind, id)
	local cls, sb, iv, rq, il, allow, dbrec = M.Cat.DatosRapidos(id, kind)
	local req = rq or rec.reqLevel
	f.icono = { objeto = id, calidad = rec.quality }
	f.titulo = rec.name
	local r, g, b = M.ColorCalidad(rec.quality)
	f.color = r and { r, g, b } or nil
	f.sobre = tipoTexto(kind, cls, sb)
	local partes = {}
	local ranura = iv and iv > 0 and M.Cat.NombreRanura(iv)
	if ranura then partes[#partes + 1] = ranura end
	if il and il > 0 then partes[#partes + 1] = format(L["Nivel de objeto %d"], il) end
	if req and req > 1 then partes[#partes + 1] = format(L["Requiere nivel %d"], req) end
	if rec.reqSkill then
		partes[#partes + 1] = format(L["Requiere %s (%d)"], M.NombreProfesion(rec.reqSkill), rec.reqSkillRank or 1)
	end
	f.subtitulo = unir(unpack(partes))

	-- Insignias: lo que tienes, si te sirve, si ya no se consigue.
	if rec.status == "retired" then f.insignias[#f.insignias + 1] = { L["Ya no se consigue"], "peligro" }
	elseif rec.status == "nosource" then f.insignias[#f.insignias + 1] = { L["Sin fuente conocida"], "neutro" } end
	local tienes = A.Compat.GetItemCount and A.Compat.GetItemCount(id, true)
	if type(tienes) == "number" and tienes > 0 then f.insignias[#f.insignias + 1] = { format(L["Tienes %d"], tienes), "exito" } end
	-- ¿Te sirve? El motor de equipo decide por clase, armadura y armas.
	local G = A.Gear
	if dbrec and (cls == 2 or cls == 4) and iv and iv > 0 and G and G.Usability then
		if G.GetPlayer then pcall(G.GetPlayer) end
		local ok, puede, motivo, desde = pcall(G.Usability, dbrec)
		if ok then
			local herramienta = cls == 2 and (sb == 20 or sb == 14)
			local si = (puede or herramienta or motivo == "skill") and not (type(desde) == "number" and desde > M.MiNivel())
			f.insignias[#f.insignias + 1] = si and { L["Puedes usarlo"], "exito" } or { L["No lo puedes usar todavía"], "aviso" }
		end
	end
	if dbrec and dbrec.unique then f.insignias[#f.insignias + 1] = { L["Único"], "neutro" } end
	f.datos = estadisticas(dbrec)
	-- Monturas y mascotas: si ya la tienes y qué pide (Coleccion.lua).
	if (kind == "mount" or kind == "pet") and M.Col then M.Col.Enriquecer(f, rec, kind, id) end

	-- De dónde sale (el motor ordena: lo que puedes primero, lo más rápido).
	local lista = {}
	local L2 = Lk()
	if L2 and L2.Sources then
		local ok, l = pcall(L2.Sources, kind, id)
		if ok and type(l) == "table" then lista = l end
	end
	local grupos = {}
	for _, fr in ipairs(lista) do
		local fl, clave = filaFuente(fr, kind, id)
		if fl then
			grupos[clave] = grupos[clave] or {}
			grupos[clave][#grupos[clave] + 1] = fl
		end
	end
	for _, d in ipairs(SECCIONES_OBJETO) do
		local filas = grupos[d[1]]
		if filas then
			-- El botín, por probabilidad (lo que puedes hacer, primero).
			if d[1] == "drop" or d[1] == "instancia" or d[1] == "object" or d[1] == "pesca" or d[1] == "container" then
				local pos = {}
				for k, fl in ipairs(filas) do pos[fl] = k end
				sort(filas, function(a, b)
					if (a.tenue or false) ~= (b.tenue or false) then return not a.tenue end
					if (a.orden or 0) ~= (b.orden or 0) then return (a.orden or 0) < (b.orden or 0) end
					return pos[a] < pos[b]
				end)
			end
			seccion(f, d[1], d[2], filas)
		end
	end

	-- Lo que se sabe al revés (cuando el índice está listo).
	if I.Listo("objetos") then
		local dentro = {}
		for _, v in ipairs(I.Contiene(id)) do
			local oid, p = M.Desempacar(v)
			local fl = filaObjeto(oid, nil, M.Porcentaje(p))
			fl.orden = -(p or 0)
			dentro[#dentro + 1] = fl
		end
		sort(dentro, function(a, b) return (a.orden or 0) < (b.orden or 0) end)
		seccion(f, "contiene", L["Lo que hay dentro"], dentro)
	else
		f.nota = L["Preparando lo que contiene… la ficha se completa sola."]
	end
	if I.Listo("misiones") then
		local empieza = {}
		for _, q in ipairs(I.EmpiezaItem(id)) do empieza[#empieza + 1] = filaMision(q) end
		seccion(f, "empieza", L["Empieza una misión"], empieza)
		local piden = {}
		for _, q in ipairs(I.PideItem(id)) do piden[#piden + 1] = filaMision(q) end
		seccion(f, "pide", L["Lo piden estas misiones"], piden)
	end

	-- Lo mejor para ti: la guía cuidada que lo junta, o la mejor fuente.
	local curada, mejor
	if L2 and L2.CuratedGuide then
		local ok, g = pcall(L2.CuratedGuide, kind, id)
		if ok and type(g) == "string" then curada = g end
	end
	if L2 and L2.BestSource then mejor = L2.BestSource(lista) end
	if type(curada) == "string" then
		local G = A.Guides and A.Guides.Get and A.Guides.Get(curada)
		f.mejor = { sobre = L["Hay una guía de Alfa"], titulo = G and G.title or curada, texto = L["Guíame te lleva paso a paso."], icono = "ic-guia" }
	elseif mejor then
		local fl = filaFuente(mejor, kind, id)
		if fl then f.mejor = { sobre = L["Lo mejor para ti"], titulo = fl.titulo, texto = unir(fl.texto, fl.valor, fl.viaje), ir = fl.ir, icono = fl.icono and fl.icono.ic } end
	end

	f.acciones.guiar = (type(curada) == "string" or mejor) and function() return F.Guiar(kind, id, mejor) end or nil
	f.acciones.mapa = puntosDe(f.secciones)
	-- "Quiero este objeto" tiene un botón: Agregar a Mis planes (Alfa_Rutas,
	-- una meta "conseguir este objeto" en tu plan de ahora). Agregar a mi
	-- ruta (un tramo de la ruta que armas en la página Ruta, que manda a
	-- elegir el objeto aquí) sale solo si ya tienes una ruta, o si no hay
	-- Mis planes: sin ruta crearía una que no pediste.
	local P = rawget(_G, "AlfaPlanes")
	local conPlanes = type(P) == "table" and type(P.AgregarObjeto) == "function"
	if conPlanes then
		f.acciones.plan = function() return P.AgregarObjeto(id) end
	end
	if type(AlfaRuta) == "table" and type(AlfaRuta.AgregarObjeto) == "function" and (not conPlanes or tienesRuta()) then
		f.acciones.ruta = function() return AlfaRuta.AgregarObjeto(id) end
		f.acciones.rutaAyuda = L["Un tramo más en la ruta que armas en la página Ruta: Alfa elige el camino para conseguirlo."]
	end
	-- 1.2.9: a la lista de compras de Alfa_Comercio (si está).
	local C = rawget(_G, "AlfaComercio")
	if type(C) == "table" and type(C.Lista) == "table" and type(C.Lista.Agregar) == "function" then
		f.acciones.compra = function() return C.Lista.Agregar(id, 1) end
	end
	f.acciones.vincular = function() return F.Vincular("item", id) end
	return f
end

---------------------------------------------------------------------------
-- PNJ y raros
---------------------------------------------------------------------------
local function filasLugares(lista, nombre, icono, kind, id)
	local out = {}
	for _, r in ipairs(lista) do
		if r.map and r.x then
			local fl = { icono = { ic = "ic-mapa", tono = "acento" }, titulo = M.Zona(r.map) or L["Zona sin nombre"],
				texto = unir(M.Coords(r.x, r.y), r.travel and viaje(r.travel) or nil), punto = punto(r.map, r.x, r.y, r.f, nombre, icono),
				tenue = r.hostile or nil, guia = r.guideable and { kind = kind, id = id, fila = r } or nil, ir = { kind = "zone", id = r.map } }
			out[#out + 1] = fl
		end
	end
	return out
end

local function filasVende(id)
	local C = Codex()
	local out = {}
	for _, oid in ipairs(I.Vende(id)) do
		local rec = C.Item(oid)
		local precio, limitado
		for _, s in ipairs(rec and rec.sources or {}) do
			if s.type == "vendor" and s.npc == id then precio, limitado = s.cost, s.limited end
		end
		local fl = filaObjeto(oid, limitado and L["pocas unidades, se reabastece con el tiempo"] or nil, precio and precio > 0 and N.Dinero(precio, true) or nil)
		out[#out + 1] = fl
	end
	sort(out, function(a, b) return (a.titulo or "") < (b.titulo or "") end)
	return out
end

local function filasSuelta(lista)
	local out = {}
	for _, v in ipairs(lista) do
		local oid, p = M.Desempacar(v)
		local fl = filaObjeto(oid, nil, M.Porcentaje(p))
		fl.orden = -(p or 0)
		out[#out + 1] = fl
	end
	sort(out, function(a, b)
		if (a.orden or 0) ~= (b.orden or 0) then return (a.orden or 0) < (b.orden or 0) end
		return (a.titulo or "") < (b.titulo or "")
	end)
	return out
end

local function ultimaVez(kind, id)
	local R = A.Rares
	if not (R and R.History and R.Key) then return nil end
	local ok, h = pcall(R.History)
	local e = ok and type(h) == "table" and h[R.Key(kind, id)]
	if not (type(e) == "table" and e.t) then return nil end
	local ahora = A.Compat.Now and A.Compat.Now() or time()
	local hace = max(0, ahora - e.t)
	local cuando
	if hace < 3600 then cuando = format(L["hace %d min"], max(1, floor(hace / 60)))
	elseif hace < 86400 then cuando = format(L["hace %d h"], floor(hace / 3600))
	else cuando = N.Plural(floor(hace / 86400), L["hace %d día"], L["hace %d días"]) end
	return cuando, e
end

function F.Pnj(id, kindPedido)
	local C = Codex()
	local npc = C and C.Npc(id)
	if not npc then return nil end
	local kind = npc.rare and "rare" or (kindPedido == "rare" and "rare" or "npc")
	local f = nueva(kind, id)
	f.icono = { ic = npc.rare and "ic-raros" or (npc.boss and "ic-mazmorra" or "ic-personajes"), tono = npc.rare and "raro" or (npc.boss and "mazmorra" or "acento") }
	f.titulo, f.color = npc.name, "pnj"
	f.sobre = npc.boss and L["Jefe"] or npc.rare and (npc.elite and L["Raro élite"] or L["Raro"]) or npc.elite and L["Élite"] or L["PNJ"]
	local inst = npc.instance and C.Instance(npc.instance)
	f.subtitulo = unir(nivelTexto(npc.level, npc.levelMax), M.NombreBando(npc.faction), inst and inst.name,
		not N.espanol and npc.subName or nil)
	local mio = M.MiBando()
	if npc.faction and npc.faction ~= "AH" and mio and not npc.faction:find(mio, 1, true) then
		f.insignias[#f.insignias + 1] = { L["De la otra facción"], "aviso" }
	end
	for _, rol in ipairs(npc.roles or {}) do
		local n = M.NombreRol(rol)
		if n and #f.insignias < 5 then f.insignias[#f.insignias + 1] = { n, "acento" } end
	end

	-- Dónde está (el motor lo ordena por lo cerca que te queda).
	local lugares = {}
	local L2 = Lk()
	if L2 and L2.Sources then
		local ok, l = pcall(L2.Sources, kind, id)
		if ok and type(l) == "table" then lugares = l end
	end
	local icono = npc.rare and "map:rare" or "map:target"
	local filas = filasLugares(lugares, npc.name, icono, kind, id)
	if #filas > 0 then
		local primero = filas[1]
		f.mejor = { sobre = L["Lo más cerca de ti"], titulo = primero.titulo, texto = primero.texto, icono = "ic-mapa", punto = primero.punto }
		seccion(f, "lugares", L["Dónde está"], filas)
	elseif inst then
		seccion(f, "lugares", L["Dónde está"], { { icono = { ic = "ic-mazmorra", tono = "mazmorra" }, titulo = inst.name,
			texto = L["Dentro de la mazmorra"], ir = { kind = "instance", id = inst.key } } })
	end

	-- Si es raro: la última vez que lo vieron en este reino.
	if kind == "rare" then
		local cuando, e = ultimaVez("rare", id)
		if cuando then
			f.datos = { titulo = L["Visto por última vez"], filas = { { L["Cuándo"], cuando }, e.map and { L["Dónde"], M.Lugar(e.map, e.x, e.y) or "?" } or nil } }
		end
	end

	local conBotin = false
	if I.Listo("objetos") then
		seccion(f, "vende", L["Vende"], filasVende(id))
		local suelta = I.Suelta(id)
		if #suelta > 0 then
			seccion(f, "suelta", L["Suelta"], filasSuelta(suelta))
			conBotin = true
		end
	else
		f.nota = L["Preparando lo que vende y suelta… la ficha se completa sola."]
	end
	-- El botín destacado de un raro (el Codex lo trae aunque el índice no esté).
	if not conBotin and npc.loot and #npc.loot > 0 then
		local filas2 = {}
		for k = 1, #npc.loot do filas2[k] = filaObjeto(npc.loot[k]) end
		seccion(f, "suelta", L["Suelta"], filas2)
	end
	if I.Listo("misiones") then
		local da, recibe, matar = {}, {}, {}
		for _, q in ipairs(I.DaNpc(id)) do da[#da + 1] = filaMision(q) end
		for _, q in ipairs(I.RecibeNpc(id)) do recibe[#recibe + 1] = filaMision(q) end
		for _, q in ipairs(I.PideMatar(id)) do matar[#matar + 1] = filaMision(q) end
		seccion(f, "da", L["Misiones que da"], da)
		seccion(f, "recibe", L["Misiones que recibe"], recibe)
		seccion(f, "matar", L["Misiones que piden derrotarlo"], matar)
	end

	f.acciones.guiar = #filas > 0 and function() return F.Guiar(kind, id) end or nil
	f.acciones.mapa = puntosDe(f.secciones)
	return f
end

---------------------------------------------------------------------------
-- Objetos del mundo y tesoros (cofres, vetas, bancos de peces)
---------------------------------------------------------------------------
function F.Cosa(id, kindPedido)
	local C = Codex()
	local obj = C and C.Object(id)
	if not obj then return nil end
	local kind = obj.treasure and "treasure" or (kindPedido or "object")
	local f = nueva(kind, id)
	local pez = esPesca(id)
	f.icono = { ic = obj.treasure and "ic-raros" or (pez and "ic-pesca" or "ic-recoleccion"), tono = obj.treasure and "raro" or "acento" }
	f.titulo = obj.name
	f.sobre = obj.treasure and L["Tesoro"] or (pez and L["Banco de peces"] or L["Objeto del mundo"])
	local lugares = {}
	local L2 = Lk()
	if L2 and L2.Sources then
		local ok, l = pcall(L2.Sources, kind == "treasure" and "treasure" or "object", id)
		if ok and type(l) == "table" then lugares = l end
	end
	local filas = filasLugares(lugares, obj.name, obj.treasure and "map:treasure" or "map:loot", kind == "treasure" and "treasure" or "object", id)
	if #filas > 0 then
		f.mejor = { sobre = L["Lo más cerca de ti"], titulo = filas[1].titulo, texto = filas[1].texto, icono = "ic-mapa", punto = filas[1].punto }
		seccion(f, "lugares", L["Dónde está"], filas)
	end
	local da = {}
	if I.Listo("objetos") then
		da = filasSuelta(I.Da(id))
	elseif obj.loot and #obj.loot > 0 then
		for k = 1, #obj.loot do da[k] = filaObjeto(obj.loot[k]) end
		f.nota = L["Preparando lo que da… la ficha se completa sola."]
	end
	seccion(f, "da", pez and L["Lo que se pesca aquí"] or L["Lo que da"], da)
	if I.Listo("misiones") then
		local qs = {}
		for _, q in ipairs(I.DaObjeto(id)) do qs[#qs + 1] = filaMision(q) end
		seccion(f, "misiones", L["Misiones que empiezan aquí"], qs)
	end
	if kind == "treasure" then
		local cuando, e = ultimaVez("treasure", id)
		if cuando then f.datos = { titulo = L["Visto por última vez"], filas = { { L["Cuándo"], cuando }, e.map and { L["Dónde"], M.Lugar(e.map, e.x, e.y) or "?" } or nil } } end
	end
	f.acciones.guiar = #filas > 0 and function() return F.Guiar(kind == "treasure" and "treasure" or "object", id) end or nil
	f.acciones.mapa = puntosDe(f.secciones)
	return f
end

---------------------------------------------------------------------------
-- Misiones
---------------------------------------------------------------------------
local function quienPara(q)
	local L2 = Lk()
	local ok, para = pcall(L2.QuestFor, q)
	if not (ok and type(para) == "table") then return nil end
	local partes = {}
	for _, r in ipairs(para.races or {}) do partes[#partes + 1] = M.RAZAS[r] or r end
	for _, c in ipairs(para.classes or {}) do partes[#partes + 1] = M.NombreClase(c) end
	if #partes == 0 then return nil end
	return format(L["Solo %s"], concat(partes, ", "))
end

-- Quién da o recibe una misión (PNJ u objeto), en su lugar más cercano a ti;
-- los del otro bando, atenuados.
local function filasExtremo(ext, tipo)
	local C, L2 = Codex(), Lk()
	local out = {}
	if type(ext) ~= "table" then return out end
	local desde = A.PlayerPoint and A.PlayerPoint()
	local p = L2 and L2.PlayerInfo and L2.PlayerInfo()
	local icono = tipo == "start" and "ic-misiones" or "ic-exito"
	local function agregarFila(kind, ent)
		if not ent then return end
		local s, t
		if L2 and L2.Nearest and ent.spawns then s, t = L2.Nearest(ent.spawns, desde, true) end
		local otro = kind == "npc" and ent.faction and p and L2.SideOK and not L2.SideOK(ent.faction, p)
		out[#out + 1] = { icono = { ic = kind == "npc" and icono or "ic-recoleccion", tono = "oro" }, titulo = ent.name, color = kind == "npc" and "pnj" or nil,
			texto = unir(otro and L["De la otra facción"] or nil, s and M.Lugar(s.map, s.x, s.y) or nil, t and viaje(t) or nil),
			tenue = otro or nil, ir = { kind = kind, id = ent.id },
			punto = s and punto(s.map, s.x, s.y, s.f, ent.name, ICONO_MAPA[tipo], s.z) or nil }
	end
	for _, n in ipairs(ext.npc or {}) do agregarFila("npc", C.Npc(n)) end
	for _, o in ipairs(ext.object or {}) do agregarFila("object", C.Object(o)) end
	local pos = {}
	for k, fl in ipairs(out) do pos[fl] = k end
	sort(out, function(a, b)
		if (a.tenue or false) ~= (b.tenue or false) then return not a.tenue end
		return pos[a] < pos[b]
	end)
	return out
end

-- Misiones previas sin hacer (todas las de `pre` y una de `preAny`).
local function previasAbiertas(q)
	local Cp = A.Compat
	for _, p in ipairs(q.pre or {}) do
		if not Cp.IsQuestCompleted(p) then return true end
	end
	local any = q.preAny or {}
	if #any > 0 then
		for _, p in ipairs(any) do if Cp.IsQuestCompleted(p) then return false end end
		return true
	end
	return false
end

local OBJETIVO_TEXTO = {
	kill = L["Derrota a %s"], item = L["Consigue %s"], object = L["Usa %s"], talk = L["Habla con %s"],
}

-- 1.3.7: la experiencia de una misión a tu nivel, como la da el juego: toda
-- hasta 5 niveles arriba de la misión, luego 80/60/40/20 % y 10 % desde 10
-- arriba (Levels.Share del motor), redondeada como el juego (a 5, o a 50
-- arriba de 1000). -> xp | nil, gris
function F.XPTuya(q, nivel)
	if type(q) ~= "table" or type(q.xp) ~= "number" or q.xp <= 0 then return nil end
	nivel = nivel or M.MiNivel()
	local Lv = A.Levels
	local maximo = (Lv and Lv.MAX_LEVEL) or 60
	local gris = false
	local C = A.Compat
	if type(q.level) == "number" and C and C.IsQuestTrivial then
		local ok, g = pcall(C.IsQuestTrivial, q.level, nivel)
		gris = ok and g == true
	end
	if nivel >= maximo then return 0, gris end
	local parte = 1
	if Lv and Lv.Share and type(q.level) == "number" then
		local ok, s = pcall(Lv.Share, nivel, q.level)
		if ok and type(s) == "number" then parte = s end
	end
	local xp = q.xp * parte
	local paso = xp >= 1000 and 50 or 5
	xp = floor(xp / paso + 0.5) * paso
	return max(paso, xp), gris
end

function F.Mision(id)
	local C = Codex()
	local q = C and C.Quest(id)
	if not q then return nil end
	local f = nueva("quest", id)
	f.icono = { ic = "ic-misiones", tono = "oro" }
	f.titulo, f.color = q.title, "mision"
	f.sobre = L["Misión"]
	f.subtitulo = unir(q.level and format(L["Nivel %d"], q.level), q.minLevel and q.minLevel ~= q.level and format(L["desde el nivel %d"], q.minLevel) or nil,
		q.zone and M.Zona(q.zone) or nil)

	-- ¿La puedes tomar?
	local L2 = Lk()
	local hecha = A.Compat.IsQuestCompleted(id)
	local tienes = A.Compat.IsOnQuest and A.Compat.IsOnQuest(id)
	local R = type(AlfaRuta) == "table" and AlfaRuta or nil
	local bloqueada
	if hecha then f.insignias[#f.insignias + 1] = { L["Ya la hiciste"], "exito" }
	elseif tienes then f.insignias[#f.insignias + 1] = { L["En tu registro"], "acento" }
	else
		local why
		if L2 and L2.QuestBlock and L2.PlayerInfo then
			local ok, w = pcall(L2.QuestBlock, q, L2.PlayerInfo())
			why = ok and w or nil
		end
		if not why and previasAbiertas(q) then why = "pre" end
		-- Si no se puede, la ruta de Alfa lo explica mejor ("Antes: «...»",
		-- "Disponible a nivel 20"); decide el motor, como al guiar.
		local texto = why and (POR_QUE[why] or L["Todavía no es para ti"]) or nil
		if why and R and type(R.Disponible) == "function" then
			local ok, si, porque = pcall(R.Disponible, id)
			if ok and si == false and type(porque) == "string" and porque ~= "" then texto = porque end
		end
		if why then
			f.insignias[#f.insignias + 1] = { texto, "aviso" }
			bloqueada = why ~= "faction" and why ~= "race" and why ~= "class" and why ~= "done"
		else
			f.insignias[#f.insignias + 1] = { L["Puedes tomarla"], "exito" }
		end
	end
	if R and not hecha and type(R.EnPlan) == "function" then
		local ok, en = pcall(R.EnPlan, id)
		if ok and en then f.insignias[#f.insignias + 1] = { L["En tu plan"], "acento", "ic-ruta" } end
	end
	local side = q.faction or (L2 and L2.QuestSide and L2.QuestSide(q))
	if side == "A" or side == "H" then f.insignias[#f.insignias + 1] = { M.NombreBando(side), "neutro" } end
	local para = quienPara(q)
	if para then f.insignias[#f.insignias + 1] = { para, "neutro" } end

	local datos = {}
	if q.xp and q.xp > 0 then
		datos[#datos + 1] = { L["Experiencia"], M.Miles(q.xp) }
		-- 1.3.7: lo que te da a ti, a tu nivel (más de 5 niveles arriba de la
		-- misión da menos), y si ya está gris.
		local tuya, gris = F.XPTuya(q)
		if tuya and not hecha then
			if tuya == 0 then
				datos[#datos + 1] = { L["A tu nivel"], L["Ya no da experiencia (estás en el nivel máximo)"] }
			elseif tuya < q.xp then
				datos[#datos + 1] = { L["A tu nivel"], format(L["%s (menos, porque ya la pasaste)"], M.Miles(tuya)) }
			else
				datos[#datos + 1] = { L["A tu nivel"], format(L["%s, completa"], M.Miles(tuya)) }
			end
		end
		if gris and not hecha then f.insignias[#f.insignias + 1] = { L["Gris para ti"], "neutro" } end
	end
	if q.repFaction and q.repStanding then
		datos[#datos + 1] = { L["Reputación necesaria"], unir(M.Nombre("faction", q.repFaction), M.NombreReputacion(q.repStanding)) }
	end
	if #datos > 0 then f.datos = { titulo = L["Datos"], filas = datos } end

	-- Quién la da y dónde se entrega.
	local da = filasExtremo(q.start, "start")
	for _, it in ipairs(q.start and q.start.item or {}) do da[#da + 1] = filaObjeto(it, L["Empieza al usar este objeto"]) end
	local entrega = filasExtremo(q["end"], "end")
	seccion(f, "da", L["Quién la da"], da)

	-- Qué hay que hacer.
	local obj = {}
	for _, o in ipairs(q.objectives or {}) do
		local nombre, ir, icono
		if o.type == "kill" and o.id then
			nombre, ir, icono = M.Nombre("npc", o.id), { kind = "npc", id = o.id }, { ic = "ic-personajes", tono = "peligro" }
		elseif o.type == "item" and o.id then
			nombre, ir, icono = M.Nombre("item", o.id), { kind = "item", id = o.id }, { objeto = o.id }
		elseif o.type == "object" and o.id then
			nombre, ir, icono = M.Nombre("object", o.id), { kind = "object", id = o.id }, { ic = "ic-recoleccion", tono = "acento" }
		elseif o.type == "talk" and o.id then
			nombre, ir, icono = M.Nombre("npc", o.id), { kind = "npc", id = o.id }, { ic = "ic-personajes", tono = "acento" }
		end
		local titulo
		if nombre and OBJETIVO_TEXTO[o.type] then
			titulo = format(OBJETIVO_TEXTO[o.type], nombre)
		else
			titulo = o.text or L["Completa el objetivo"]
			icono = icono or { ic = "ic-exito", tono = "acento" }
		end
		obj[#obj + 1] = { icono = icono, titulo = titulo, valor = o.count and o.count > 1 and ("\195\151" .. o.count) or nil, ir = ir,
			punto = o.map and punto(o.map, o.x, o.y, o.f, titulo, "map:target") or nil, texto = o.map and M.Lugar(o.map, o.x, o.y) or nil }
	end
	seccion(f, "objetivos", L["Qué hay que hacer"], obj)
	seccion(f, "entrega", L["Dónde se entrega"], entrega)

	local premios = {}
	for _, it in ipairs(q.rewards or {}) do premios[#premios + 1] = filaObjeto(it) end
	seccion(f, "premios", L["Recompensas"], premios)
	local elegir = {}
	for _, it in ipairs(q.choices or {}) do elegir[#elegir + 1] = filaObjeto(it) end
	seccion(f, "elegir", L["Eliges una"], elegir)

	-- Antes y después.
	local antes = {}
	for _, p in ipairs(q.pre or {}) do antes[#antes + 1] = filaMision(p, not A.Compat.IsQuestCompleted(p) and L["pendiente"] or nil) end
	if q.preAny and #q.preAny > 0 then
		for _, p in ipairs(q.preAny) do antes[#antes + 1] = filaMision(p, L["basta una de estas"]) end
	end
	seccion(f, "antes", L["Antes necesitas"], antes)
	local despues = {}
	local ok, sig = pcall(C.FollowUps, id)
	if ok and type(sig) == "table" then
		for _, s in ipairs(sig) do despues[#despues + 1] = filaMision(s.id) end
	end
	seccion(f, "despues", L["Después sigue"], despues)

	local giver = da[1]
	if giver and not hecha then
		f.mejor = { sobre = L["Para empezar"], titulo = giver.titulo, texto = giver.texto, icono = "ic-misiones", punto = giver.punto, ir = giver.ir }
	end
	f.acciones.guiar = not hecha and (#da > 0 or #entrega > 0) and function() return F.Guiar("quest", id) end or nil
	f.acciones.mapa = puntosDe(f.secciones)
	f.acciones.vincular = function() return F.Vincular("quest", id) end
	-- Cerrar mis misiones (el plan de Alfa_Rutas que las termina y entrega):
	-- agregarla o quitarla, y qué falta para tomarla.
	if R and not hecha and type(R.AgregarMision) == "function" then
		local okP, enPlan = pcall(function() return type(R.EnPlan) == "function" and R.EnPlan(id) end)
		enPlan = okP and enPlan
		if enPlan and type(R.QuitarMision) == "function" then
			f.acciones.ruta, f.acciones.rutaTexto = function() return R.QuitarMision(id) end, L["Quitar de Cerrar mis misiones"]
		elseif not enPlan then
			f.acciones.ruta, f.acciones.rutaTexto = function() return R.AgregarMision(id) end, L["Agregar a Cerrar mis misiones"]
			f.acciones.rutaAyuda = L["Entra en el plan que termina y entrega tus misiones por el camino más corto, con lo que pide antes."]
		end
	end
	if R and bloqueada and type(R.Desbloquear) == "function" then
		f.acciones.desbloquear = function() return R.Desbloquear(id) end
	end
	return f
end

---------------------------------------------------------------------------
-- Zonas
---------------------------------------------------------------------------
local ROL_ICONO = { flightmaster = "map:flightmaster", innkeeper = "map:inn", banker = "map:bank", auctioneer = "map:auction",
	repair = "map:repair", stablemaster = "map:stable", battlemaster = "map:battlemaster", spirithealer = "map:ankh",
	weapon = "map:trainer-weapon", trainer = "map:trainer-profession" }

function F.Zona(id)
	local C = Codex()
	local z = C and C.Zone(id)
	local nombre = M.Zona(id) or (z and z.name)
	if not nombre then return nil end
	local f = nueva("zone", id)
	f.icono = { ic = "ic-mapa", tono = "acento" }
	f.titulo = nombre
	f.sobre = L["Zona"]
	local lo, hi
	local Mp = A.Maps
	if Mp and Mp.GetZoneLevels then lo, hi = Mp.GetZoneLevels(id) end
	f.subtitulo = lo and nivelTexto(lo, hi) or nil
	if lo then
		local nivel = M.MiNivel()
		if nivel >= lo and nivel <= (hi or lo) then f.insignias[#f.insignias + 1] = { L["Para tu nivel"], "exito" }
		elseif lo > nivel + 3 then f.insignias[#f.insignias + 1] = { L["Peligrosa para tu nivel"], "aviso" }
		elseif hi and hi < nivel - 5 then f.insignias[#f.insignias + 1] = { L["Por debajo de tu nivel"], "neutro" } end
	end
	-- 1.2.7: Lya cuenta algo de la zona (sus datos curiosos, AlfaLya.DatoDeZona).
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and type(Lya.DatoDeZona) == "function" then
		local ok, dato = pcall(Lya.DatoDeZona, id)
		if ok and type(dato) == "string" and dato ~= "" then
			f.mejor = { sobre = L["Lya te cuenta"], titulo = nombre, texto = dato, icono = "ic-lobo" }
		end
	end
	local pendiente = {}
	-- Lo que la zona necesita y aún no está: se prepara ya (la ficha se rehace sola).
	if not I.Listo("misiones") then I.PrepararMisiones() end
	if not I.RarosListos() then I.PrepararRaros() end
	if not I.ServiciosListos() then I.PrepararServicios() end

	local mazmorras = {}
	for _, inst in ipairs(I.MazmorrasDeZona(id)) do
		local lv = inst.levels
		mazmorras[#mazmorras + 1] = { icono = { ic = "ic-mazmorra", tono = "mazmorra" }, titulo = inst.name, color = "mazmorra",
			texto = unir(inst.kind == "raid" and L["Banda"] or L["Mazmorra"], lv and lv[1] and nivelTexto(lv[1], lv[#lv]) or nil),
			ir = { kind = "instance", id = inst.key },
			punto = inst.entrance and punto(inst.entrance.map, inst.entrance.x, inst.entrance.y, inst.entrance.f, inst.name, "map:dungeon") or nil }
	end
	seccion(f, "mazmorras", L["Mazmorras y bandas"], mazmorras)

	if I.Listo("misiones") then
		local qs, tuyas = {}, 0
		for _, q in ipairs(I.PorZona(id)) do
			local fl = filaMision(q)
			if I.MisionParaMi(q) then tuyas = tuyas + 1 else fl.tenue = true end
			qs[#qs + 1] = fl
		end
		-- Las que puedes tomar, primero.
		local pos = {}
		for k, fl in ipairs(qs) do pos[fl] = k end
		sort(qs, function(a, b)
			if (a.tenue or false) ~= (b.tenue or false) then return not a.tenue end
			return pos[a] < pos[b]
		end)
		local s = seccion(f, "misiones", L["Misiones"], qs)
		if s and tuyas > 0 then s.cuenta = format(L["%d para ti"], tuyas) end
	else
		pendiente[#pendiente + 1] = L["misiones"]
	end
	if I.RarosListos() then
		local raros, tesoros = {}, {}
		for _, r in ipairs(I.RarosDeZona(id)) do
			local nombreR = M.Nombre(r.kind, r.id)
			local fl = { icono = { ic = "ic-raros", tono = "raro" }, titulo = nombreR, color = r.kind == "rare" and "pnj" or nil,
				texto = r.nivel and format(L["Nivel %d"], r.nivel) or nil, ir = { kind = r.kind, id = r.id } }
			if r.kind == "rare" then raros[#raros + 1] = fl else tesoros[#tesoros + 1] = fl end
		end
		seccion(f, "raros", L["Raros"], raros)
		seccion(f, "tesoros", L["Tesoros"], tesoros)
	else
		pendiente[#pendiente + 1] = L["raros"]
	end
	if I.ServiciosListos() then
		local serv = I.Servicios(id) or {}
		local filas = {}
		for _, rol in ipairs(I.SERVICIOS) do
			for _, npcId in ipairs(serv[rol] or {}) do
				local npc = C.Npc(npcId)
				local s
				for _, sp in ipairs(npc and npc.spawns or {}) do if sp.map == id then s = s or sp end end
				if npc and s then
					filas[#filas + 1] = { icono = { ic = "ic-personajes", tono = "acento" }, titulo = npc.name, color = "pnj",
						texto = unir(M.NombreRol(rol), M.Coords(s.x, s.y)), ir = { kind = "npc", id = npcId },
						punto = punto(s.map, s.x, s.y, s.f, npc.name, ROL_ICONO[rol]) }
				end
			end
		end
		seccion(f, "servicios", L["Servicios"], filas)
	else
		pendiente[#pendiente + 1] = L["servicios"]
	end
	if #pendiente > 0 then f.nota = format(L["Preparando %s… la ficha se completa sola."], concat(pendiente, ", ")) end
	f.acciones.mapa = puntosDe(f.secciones, 40)
	f.acciones.mapaZona = id
	-- 1.3.7: a un clic, la guía de esta zona y (si estás aquí) su circuito.
	local gid = F.GuiaDeZona(id)
	if gid then f.acciones.guiaZona = function() return F.AbrirGuia(gid) end end
	local R = type(AlfaRuta) == "table" and AlfaRuta or nil
	if R and type(R.Circuito) == "function" and F.EstasEn(id) then
		f.acciones.circuito = function()
			local ok, e = pcall(R.Circuito)
			if not ok then return false, tostring(e) end
			return true, L["Armé el circuito de la zona: sigue la flecha."]
		end
	end
	return f
end

-- 1.3.7: la guía de subir de nivel de una zona (la que te queda mejor por
-- nivel, de tu bando, raza y clase). -> id | nil
function F.GuiaDeZona(mapa)
	local G = A.Guides
	if not (G and type(G.List) == "function" and type(mapa) == "number") then return nil end
	local C = A.Compat
	local p = C and C.GetPlayerInfo and C.GetPlayerInfo() or {}
	local nivel = M.MiNivel()
	local mejor, dist
	local ok, lista = pcall(G.List)
	for _, g in ipairs(ok and lista or {}) do
		if g.zone == mapa and (g.category == nil or g.category == "" or g.category == "Leveling")
			and (not G.GuideMatches or G.GuideMatches(g, p)) then
			local lo, hi = g.minLevel or 1, g.maxLevel or g.minLevel or 60
			local d = nivel < lo and (lo - nivel) or (nivel > hi and (nivel - hi) or 0)
			if not mejor or d < dist then mejor, dist = g.id, d end
		end
	end
	return mejor
end

-- Abre una guía: su pestaña si ya está, una nueva, o la de ahora.
function F.AbrirGuia(gid)
	local E = A.Engine
	if not (E and gid) then return false, L["El motor no puede armar guías ahora."] end
	if InCombatLockdown() then return false, L["Se puede al salir de combate."] end
	local tabs = E.GetTabs and E.GetTabs() or {}
	for i, t in ipairs(tabs) do
		if t.guideId == gid then
			if E.SelectTab then E.SelectTab(i) end
			F.Empezar()
			return true, L["Guía abierta: sigue la flecha."]
		end
	end
	if E.OpenTab then
		if not E.OpenTab(gid, true) then return false, L["Ya tienes seis guías abiertas: cierra una y vuelve a intentar."] end
	elseif E.SetGuide then
		E.SetGuide(gid)
	else
		return false, L["El motor no puede armar guías ahora."]
	end
	F.Empezar()
	return true, L["Guía abierta en una pestaña nueva: sigue la flecha."]
end

-- ¿Estás en esa zona (o en una parte de ella)?
function F.EstasEn(mapa)
	local C = A.Compat
	local ok, aqui = pcall(function() return C and C.GetPlayerMapPosition and C.GetPlayerMapPosition() end)
	aqui = ok and aqui or nil
	if type(aqui) ~= "number" then return false end
	if aqui == mapa then return true end
	local Cm = rawget(_G, "C_Map")
	local info = Cm and Cm.GetMapInfo and Cm.GetMapInfo(aqui)
	return type(info) == "table" and info.parentMapID == mapa
end


---------------------------------------------------------------------------
-- Lo que se abre desde una fila o desde fuera
---------------------------------------------------------------------------
function F.Construir(kind, id)
	if M.ES_OBJETO[kind] then return F.Objeto(tonumber(id)) end
	if kind == "npc" or kind == "rare" then return F.Pnj(tonumber(id), kind) end
	if kind == "object" or kind == "treasure" then return F.Cosa(tonumber(id), kind) end
	if kind == "quest" then return F.Mision(tonumber(id)) end
	if kind == "zone" then return F.Zona(tonumber(id)) end
	if kind == "mountspell" and M.Col then return M.Col.FichaHechizo(tonumber(id)) end
	if kind == "guia" then
		local g = M.FICHAS_GUIA and M.FICHAS_GUIA[id]
		return g and g() or nil
	end
	return nil
end

-- "Guíame": la guía del motor (Lookup.Guide) en una pestaña nueva; `fila`
-- (opcional) guía a esa fuente en lugar de la mejor.
local MOTIVO = {
	disabled = L["El buscador del motor está apagado (Ajustes > Descubrir): enciéndelo para que Alfa arme guías."],
	tabs = L["Ya tienes seis guías abiertas: cierra una y vuelve a intentar."],
	login = L["Espera a terminar de entrar al juego."],
	nosource = L["No se conoce de dónde sale."],
	noguide = L["No hay un camino que Alfa pueda guiar para esto."],
	nolocation = L["No se sabe en qué lugar está."],
	combat = L["Se puede al salir de combate."],
}

-- Al empezar a seguir algo: la ventana de seguimiento a la vista y las de
-- Alfa (esta también) se cierran (N.EmpezarRuta del núcleo; sin él, la guía).
local function empezar()
	if N.EmpezarRuta then
		local ok = pcall(N.EmpezarRuta)
		if ok then return end
	end
	if A.Set then A.Set("ui.shown", true) end
end
F.Empezar = empezar

function F.Guiar(kind, id, fila)
	local L2 = Lk()
	if not (L2 and L2.Guide) then return false, L["El motor no puede armar guías ahora."] end
	if InCombatLockdown() then return false, MOTIVO.combat end
	local ok, gid, motivo = pcall(L2.Guide, kind, id, fila)
	if ok and not gid and motivo == "mount" and not fila then
		-- Una montura sin guía cuidada: a su mejor fuente (el motor no la arma sola).
		local lista = L2.Sources(kind, id)
		local mejor = L2.BestSource(lista)
		if mejor then ok, gid, motivo = pcall(L2.Guide, kind, id, mejor) end
		if ok and gid then
			empezar()
			return true, L["Te llevo a la mejor fuente. Recuerda que una montura pide nivel, equitación y oro."]
		end
	end
	if not ok then return false, tostring(gid) end
	if gid then
		empezar()
		return true, L["Guía abierta en una pestaña nueva: sigue la flecha."]
	end
	return false, MOTIVO[motivo] or format(L["No se pudo armar la guía (%s)."], tostring(motivo or "?"))
end

-- El enlace en el chat: el del juego, o uno armado con el nombre del Codex.
function F.Enlace(kind, id)
	if M.ES_OBJETO[kind] or kind == "item" then
		local link = A.Compat.ItemLink(id)
		if link then return link end
		A.Compat.RequestItem(id)
		local _, q = colorObjeto(id)
		local hex = "ffffffff"
		if C_Item and C_Item.GetItemQualityColor then
			local ok, _, _, _, h = pcall(C_Item.GetItemQualityColor, q or 1)
			if ok and type(h) == "string" and #h == 8 then hex = h end
		end
		return format("|c%s|Hitem:%d::::::::|h[%s]|h|r", hex, id, M.Nombre("item", id))
	end
	if kind == "quest" then
		local C = Codex()
		local q = C and C.Quest(id)
		return format("|cffffff00|Hquest:%d:%d|h[%s]|h|r", id, q and q.level or 0, q and q.title or M.Nombre("quest", id))
	end
	return nil
end

function F.Vincular(kind, id)
	local link = F.Enlace(kind, id)
	if not link then return false, L["Esto no se puede vincular."] end
	local U = ChatFrameUtil
	if U and type(U.InsertLink) == "function" and U.InsertLink(link) then return true end
	if type(ChatEdit_InsertLink) == "function" and ChatEdit_InsertLink(link) then return true end
	if U and type(U.OpenChat) == "function" then U.OpenChat(link) return true end
	if type(ChatFrame_OpenChat) == "function" then ChatFrame_OpenChat(link) return true end
	return false, L["No se encontró el chat."]
end
