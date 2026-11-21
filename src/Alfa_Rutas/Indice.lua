-- Alfa - Rutas: el índice de misiones de este personaje y las piezas para
-- medirlas (XP, oro estimado, dónde empiezan y terminan, cuánto camino y
-- esfuerzo llevan) y para armar sus pasos con el formato de guía del motor.
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Todo sale del Codex del motor (A.Codex) y de su Lookup (A.Lookup): quién
-- da y recibe cada misión, sus objetivos, sus recompensas, su XP. El camino
-- se mide en línea recta (A.DirectTravelCost): el planificador de rutas del
-- motor tarda hasta 40 ms por consulta y aquí se comparan cientos.
--
--   Indice.CodexListo() -> ok, motivo         -- carga el Codex (nunca en combate)
--   Indice.Pedir(fn(indice | nil, motivo))    -- el índice (lo arma en segundo plano la primera vez)
--   Indice.Listo() -> indice | nil
--   Indice.Disponible(e, usadas, nivel) -> bool
--   Indice.XP(e), Indice.XPPara(e, nivel), Indice.Oro(e), Indice.Esfuerzo(e)
--   Indice.Puntos(e, desde) -> dador, fin      -- puntos { map, x, y, f, kind, id, name }
--   Indice.Objetivo(e, desde) -> punto, grupo, dentro
--   Indice.Viaje(a, b) -> segundos
--   Indice.PasosMision(q, desde) -> partes | nil   -- metas aceptar / objetivos / entregar
--   Indice.Recoleccion(itemId, desde) -> lugar | nil
--   Indice.MaterialSugerido() -> itemId | nil, Indice.HayClase() -> bool

local ADDON, M = ...
local A, L = M.A, M.L
local I = {}
M.Indice = I

local type, ipairs, pairs, tonumber, tostring = type, ipairs, pairs, tonumber, tostring
local floor, max, min, format = math.floor, math.max, math.min, string.format

local LEJOS = 7200 -- segundos: un punto que no se puede medir
I.LEJOS = LEJOS
local MAX_NIVEL_NPC = 63

local function LK() return M.Motor("Lookup") end
local function CX() return M.Motor("Codex") end
local function CP() return M.Motor("Compat") end

local function hecha(id)
	local C = CP()
	return C and C.IsQuestCompleted and C.IsQuestCompleted(id) or false
end
I.Hecha = hecha

local function enRegistro(id)
	local C = CP()
	return C and C.IsOnQuest and C.IsOnQuest(id) or false
end
I.EnRegistro = enRegistro

function I.Jugador()
	local Lk = LK()
	local p = Lk and Lk.PlayerInfo and Lk.PlayerInfo() or {}
	p.level = M.num(p.level, 1)
	p.xp, p.xpMax = M.num(p.xp, 0), M.num(p.xpMax, 0)
	return p
end

-- El nivel con su parte ya ganada: 14.6
function I.NivelDecimal(p)
	p = p or I.Jugador()
	local frac = (p.xpMax or 0) > 0 and (p.xp or 0) / p.xpMax or 0
	return p.level + min(0.99, frac)
end

function I.CodexListo()
	local C = CX()
	if not (C and C.Load) then return false, "missing" end
	if C.IsLoaded and C.IsLoaded() then
		if M.Disp then M.Disp.Cargar() end
		return true
	end
	if InCombatLockdown and InCombatLockdown() then return false, "combat" end
	local ok, motivo = C.Load()
	-- La base de misiones también: dice previas, excluyentes y profesión.
	if ok and M.Disp then M.Disp.Cargar() end
	return ok and true or false, motivo
end

-- Por qué no se pudo leer el Codex, en palabras.
function I.TextoMotivo(m)
	if m == "combat" then return L["Espera a salir de combate."] end
	if m == "missing" then return L["Falta la carpeta Alfa_Codex: reinstala Alfa."] end
	if m == "disabled" then return L["Alfa_Codex está apagado en la lista de addons."] end
	return L["No se pudieron leer los datos del juego."]
end

---------------------------------------------------------------------------
-- Puntos y caminos
---------------------------------------------------------------------------

function I.Viaje(a, b)
	if not (a and b and a.map and b.map) then return LEJOS end
	if a == b then return 0 end
	local f = A.DirectTravelCost
	if type(f) ~= "function" then return LEJOS end
	local ok, t = pcall(f, a, b)
	if ok and type(t) == "number" then return t end
	return LEJOS
end

local function marco(f) return f == "e" and "e" or nil end

local function punto(s, kind, id, name)
	if not (s and s.map and s.x and s.y) then return nil end
	return { map = s.map, x = s.x, y = s.y, f = marco(s.f), z = s.z, kind = kind, id = id, name = name }
end

-- Lookup.QuestEnd -> punto (nunca uno de la otra facción).
local function finDe(lista, desde, p)
	local Lk = LK()
	if not (Lk and Lk.QuestEnd) then return nil end
	local e = Lk.QuestEnd(lista, desde, p, true)
	if not e or e.hostile or not e.spawn then return nil end
	return punto(e.spawn, e.npc and "npc" or "object", e.npc or e.object, e.name)
end
I.FinDe = finDe

function I.Puntos(e, desde, p)
	local C = CX()
	local q = C and C.Quest(e.id)
	if not q then return nil end
	local dador = finDe(q.start, desde, p)
	local fin = finDe(q["end"], dador or desde, p)
	return dador, fin, q
end

---------------------------------------------------------------------------
-- El índice
---------------------------------------------------------------------------

local indice -- { lista, porId, clave }
local esperando = {}

local function claveJugador(p)
	return tostring(p.class) .. "/" .. tostring(p.faction) .. "/" .. tostring(p.race)
end

function I.Listo()
	if not indice then return nil end
	if indice.clave ~= claveJugador(I.Jugador()) then return nil end
	return indice
end

local function armar(ceder)
	local C, Lk, Cp = CX(), LK(), CP()
	local p = I.Jugador()
	local ids = {}
	C.Each("quest", function(id) if type(id) == "number" then ids[#ids + 1] = id end end)
	local lista, porId = {}, {}
	local total = #ids
	for i, id in ipairs(ids) do
		local q = C.Quest(id)
		if q and M.num(q.level, 0) > 0 and q.level <= MAX_NIVEL_NPC then
			local why = Lk.QuestBlock(q, p)
			if not why or why == "level" then
				local st, fin = q.start or {}, q["end"] or {}
				local dador = #(st.npc or {}) + #(st.object or {}) > 0
				local entrega = #(fin.npc or {}) + #(fin.object or {}) > 0
				if entrega and (dador or enRegistro(id)) then
					local quien = Lk.QuestFor and Lk.QuestFor(q)
					local e = {
						id = id, lvl = q.level, min = M.num(q.minLevel, 1), xp = M.num(q.xp), zone = q.zone,
						clase = quien and quien.classes ~= nil or false,
						rew = q.rewards, cho = q.choices, pre = q.pre, preAny = q.preAny,
						nobj = #(q.objectives or {}),
					}
					lista[#lista + 1] = e
					porId[id] = e
				end
			end
		end
		if i % 100 == 0 then M.Tareas.Avance("indice", i / max(1, total)) end
		ceder()
	end
	return { lista = lista, porId = porId, clave = claveJugador(p) }
end

-- fn(indice) cuando esté (al momento si ya está). Sin Codex: fn(nil, motivo).
function I.Pedir(fn, alAvanzar)
	local listo = I.Listo()
	if listo then return fn(listo) end
	local ok, motivo = I.CodexListo()
	if not ok then return fn(nil, motivo) end
	esperando[#esperando + 1] = fn
	if M.Tareas.Corriendo("indice") then return end
	M.Tareas.Lanzar("indice", armar, function(res, err)
		indice = res
		local lista = esperando
		esperando = {}
		for _, f in ipairs(lista) do
			local bien, e2 = pcall(f, res, err and "error" or nil)
			if not bien and geterrorhandler then geterrorhandler()(e2) end
		end
	end, alAvanzar)
end

-- Al subir de nivel cambian las misiones abiertas: el índice se queda (sus
-- límites se miran al momento), pero la vista se entera.
A.RegisterEvent("PLAYER_LEVEL_UP", (AlfaNucleo.TrasNivel or function(_, f) return f end)("rutas.indice", function() M.Avisar("NIVEL") end)) -- 1.3.7: tras la animación del juego

---------------------------------------------------------------------------
-- Medidas de una misión
---------------------------------------------------------------------------

-- ¿Se puede tomar ya? usadas: las que la ruta hace antes (cuentan como
-- hechas). nivel: el nivel de verdad del personaje (la regla: nunca una
-- misión que todavía no se puede tomar). Primero lo barato del índice y
-- después la revisión completa (Disponible.lua: previas, excluyentes,
-- profesión, facción, raza y clase).
function I.Disponible(e, usadas, nivel)
	if usadas[e.id] or hecha(e.id) then return false end
	local enLog = enRegistro(e.id)
	if enLog then return true end
	if (e.min or 1) > floor(nivel) then return false end
	for _, pid in ipairs(e.pre or {}) do
		if not (usadas[pid] or hecha(pid)) then return false end
	end
	local any = e.preAny
	if type(any) == "table" and #any > 0 then
		local alguna = false
		for _, pid in ipairs(any) do
			if usadas[pid] or hecha(pid) then alguna = true break end
		end
		if not alguna then return false end
	end
	local D = M.Disp
	if D then return (D.Estado(e.id, { usadas = usadas, nivel = nivel })) and true or false end
	return true
end

-- La XP completa (estimada por el nivel cuando el Codex no la sabe).
function I.XP(e)
	return e.xp or floor((e.lvl or 1) * 65)
end

-- La XP que te da a `nivel` (menos si está muy por debajo de ti).
function I.XPPara(e, nivel)
	local Lv = M.Motor("Levels")
	local parte = 1
	if Lv and Lv.Share then parte = M.num(Lv.Share(floor(nivel), e.lvl), 1) end
	return floor(I.XP(e) * parte + 0.5)
end

-- Lo que un objeto se vende al comerciante, si el cliente lo conoce ya
-- (C_Item.GetItemInfo: su 11.º valor). pedir: si no lo conoce, se lo pide
-- al servidor para la próxima vez (pocas veces: cada pedido es tráfico).
local function venta(id, pedir)
	local f = C_Item and C_Item.GetItemInfo
	if type(f) ~= "function" or type(id) ~= "number" then return 0 end
	local r = { pcall(f, id) }
	if r[1] and r[2] and type(r[12]) == "number" then return r[12] end
	if pedir ~= false then
		local C = CP()
		if C and C.RequestItem then C.RequestItem(id) end
	end
	return 0
end
I.Venta = venta

-- Cobre estimado: el juego no publica el dinero de cada misión, así que se
-- calcula por su XP y su nivel, más lo que valen sus recompensas.
function I.Oro(e, pedir)
	local base = I.XP(e) * (0.35 + 0.035 * (e.lvl or 1))
	local fijo = 0
	for _, id in ipairs(e.rew or {}) do fijo = fijo + venta(id, pedir) end
	local mejor = 0
	for _, id in ipairs(e.cho or {}) do mejor = max(mejor, venta(id, pedir)) end
	return floor(base + fijo + mejor)
end

-- Segundos de trabajo de sus objetivos, a ojo.
function I.Esfuerzo(e)
	local C = CX()
	local q = C and C.Quest(e.id)
	local s = 45
	for _, o in ipairs(q and q.objectives or {}) do
		local n = M.num(o.count, 1)
		if o.type == "kill" then s = s + n * 22
		elseif o.type == "item" then s = s + n * 30
		elseif o.type == "object" then s = s + n * 15
		elseif o.type == "talk" then s = s + 20
		else s = s + 120 end
	end
	return s
end

-- Un PNJ que pide grupo afuera: élite, raro élite o jefe (como el motor).
local function grupoDe(npc)
	if not (npc and (npc.elite or npc.boss)) or npc.instance or npc.faction then return nil end
	if npc.level and npc.level > MAX_NIVEL_NPC then return nil end
	return { kind = "elite", rank = npc.boss and 3 or (npc.rare and 2) or 1, lvl = npc.level }
end
I.GrupoDe = grupoDe

-- Dónde se junta un objeto de misión: la fuente con más probabilidad que
-- tenga lugar conocido. -> spawn, registro, tipo, id, lista de spawns
local function fuenteObjeto(itemId, desde)
	local C, Lk = CX(), LK()
	local item = C.Item(itemId)
	if not item then return nil end
	local mejor, mejorP, rec, tipo, fid, spawns
	for _, src in ipairs(item.sources or {}) do
		local r, k, id
		if src.type == "drop" and src.npc then r, k, id = C.Npc(src.npc), "npc", src.npc
		elseif src.type == "object" and src.object then r, k, id = C.Object(src.object), "object", src.object end
		local p = src.chance or 0
		if r and r.spawns and #r.spawns > 0 and (not mejor or p > mejorP) then
			mejor, mejorP, rec, tipo, fid, spawns = Lk.Nearest(r.spawns, desde, true), p, r, k, id, r.spawns
		end
	end
	return mejor, rec, tipo, fid, spawns
end

-- Las misiones de mazmorra (la lista de misiones de cada mazmorra del
-- motor): sus objetivos se hacen DENTRO, aunque el dato del objeto o del PNJ
-- traiga un punto en el mapa de afuera (el cofre del Manuscrito de Lorgalis,
-- en Cavernas de Brazanegra, mandaba la flecha a ese punto). -> clave, nombre
local porMision -- [qid] = clave de la mazmorra
function I.Mazmorra(qid)
	qid = tonumber(qid)
	if not qid then return nil end
	if not porMision then
		local D = M.Motor("Dungeons")
		if not (D and D.List and D.Quests) then return nil end
		if D.Load then pcall(D.Load) end
		local ok, lista = pcall(D.List)
		if not (ok and type(lista) == "table" and #lista > 0) then return nil end
		porMision = {}
		for _, d in ipairs(lista) do
			local okq, qs = pcall(D.Quests, d.key)
			for _, mq in ipairs(okq and type(qs) == "table" and qs or {}) do
				if mq.id and not porMision[mq.id] then porMision[mq.id] = d.key end
			end
		end
	end
	local clave = porMision[qid]
	if not clave then return nil end
	local D = M.Motor("Dungeons")
	local d = D and D.Get and D.Get(clave)
	return clave, d and d.name or clave
end

-- Si el registro del juego marca la misión como de mazmorra o banda (el
-- "(Calabozo)" junto al nombre): se hace dentro aunque el motor no la liste.
local ETIQUETA_DENTRO = { [81] = true, [62] = true, [88] = true, [89] = true } -- calabozo, banda, banda (10/25)
function I.EtiquetaMazmorra(qid)
	qid = tonumber(qid)
	local QL = C_QuestLog
	if not (qid and QL and QL.GetQuestTagInfo) then return false end
	local ok, info = pcall(QL.GetQuestTagInfo, qid)
	if not (ok and type(info) == "table") then return false end
	local id = tonumber(info.tagID)
	return id ~= nil and ETIQUETA_DENTRO[id] == true
end

-- La entrada de esa mazmorra como punto { map, x, y, f } (o nil).
function I.EntradaMazmorra(clave)
	local D = M.Motor("Dungeons")
	if not (clave and D and D.Entrance) then return nil end
	local map, x, y, f = D.Entrance(clave)
	if not (map and x and y) then return nil end
	return { map = map, x = x, y = y, f = f }
end

-- El primer lugar de sus objetivos, si piden grupo y si algo queda dentro
-- de una mazmorra (sin lugar en el mundo).
function I.Objetivo(e, desde)
	local C, Lk = CX(), LK()
	local q = C and C.Quest(e.id)
	-- una misión de mazmorra: dentro, con la entrada como lugar
	local mz = I.Mazmorra(e.id)
	if q and mz then
		local entrada = I.EntradaMazmorra(mz)
		return entrada and punto(entrada) or nil, true, true
	end
	if not q then return nil end
	local lugar, grupo, dentro
	for _, o in ipairs(q.objectives or {}) do
		local s
		if (o.type == "kill" or o.type == "talk") and o.id then
			local npc = C.Npc(o.id)
			if npc then
				if npc.instance then dentro = true end
				if o.type == "kill" and grupoDe(npc) then grupo = true end
				s = Lk.Nearest(npc.spawns, desde, true)
			end
		elseif o.type == "item" and o.id then
			local rec
			s, rec = fuenteObjeto(o.id, desde)
			if rec and grupoDe(rec) then grupo = true end
		elseif o.type == "object" and o.id then
			local obj = C.Object(o.id)
			s = obj and Lk.Nearest(obj.spawns, desde, true)
		elseif o.map then
			s = o
		end
		if s and s.map then
			lugar = lugar or punto(s)
		elseif o.type ~= "event" then
			dentro = true
		end
	end
	return lugar, grupo, dentro
end

---------------------------------------------------------------------------
-- Los pasos de una misión, como los arma el Lookup del motor
-- (Lookup.QuestStep), pero midiendo en línea recta.
---------------------------------------------------------------------------

local SPOTS_CAMPO, SPOTS_AREA, AREA_YARDAS = 6, 10, 250

-- Los lugares donde está el objetivo en el mapa de la meta, el más cercano
-- primero (o en recorrido cuando están desparramados): la flecha los visita.
local function lugares(meta, spawns)
	if not (meta.map and type(spawns) == "table") then return meta end
	local Cp = CP()
	local aMundo = Cp and Cp.MapToWorld
	if type(aMundo) ~= "function" then return meta end
	local c0, gx, gy = aMundo(meta.map, meta.x, meta.y, meta.f)
	if not c0 then return meta end
	local pts, sx, sy = {}, 0, 0
	for _, s in ipairs(spawns) do
		if s.map == meta.map and marco(s.f) == meta.f and s.x and s.y then
			local c, wx, wy = aMundo(s.map, s.x, s.y, meta.f)
			if c == c0 and wx then
				pts[#pts + 1] = { x = s.x, y = s.y, wx = wx, wy = wy }
				sx, sy = sx + wx, sy + wy
			end
		end
		if #pts >= 40 then break end
	end
	local n = #pts
	if n < 2 then return meta end
	local cx, cy = sx / n, sy / n
	local lejos = 0
	for _, p in ipairs(pts) do lejos = max(lejos, ((p.wx - cx) ^ 2 + (p.wy - cy) ^ 2) ^ 0.5) end
	local area = lejos > AREA_YARDAS
	local function d(a, bx, by) return (a.wx - bx) ^ 2 + (a.wy - by) ^ 2 end
	local orden = {}
	if area then
		local quedan, ax, ay = {}, gx, gy
		for i, p in ipairs(pts) do quedan[i] = p end
		while #quedan > 0 do
			local bi = 1
			for i = 2, #quedan do if d(quedan[i], ax, ay) < d(quedan[bi], ax, ay) then bi = i end end
			local p = table.remove(quedan, bi)
			orden[#orden + 1] = p
			ax, ay = p.wx, p.wy
		end
	else
		for i, p in ipairs(pts) do orden[i] = p end
		table.sort(orden, function(a, b) return d(a, gx, gy) < d(b, gx, gy) end)
	end
	local tope = area and SPOTS_AREA or SPOTS_CAMPO
	local spots = {}
	for i, p in ipairs(orden) do
		if i > tope * 2 then break end
		spots[i] = { x = p.x, y = p.y, r = area and 60 or 30, n = 1, alt = i > tope or nil }
	end
	meta.spots = spots
	if area then meta.spread = true end
	return meta
end
I.Lugares = lugares

local function en(meta, s)
	if s and s.map and s.x and s.y then
		meta.map, meta.x, meta.y, meta.f, meta.z = s.map, s.x, s.y, marco(s.f), s.z
	end
	return meta
end

local function metaNpc(t, q, pt)
	local g = { t = t, quest = q.id, title = q.title }
	if pt.kind == "object" then g.object, g.objName = pt.id, pt.name else g.npc, g.npcName = pt.id, pt.name end
	en(g, pt)
	local Lk = LK()
	if Lk and Lk.SpawnZ then
		local z = Lk.SpawnZ(pt.kind == "object" and "object" or "npc", pt.id, pt)
		if z then g.z = z end
	end
	return g
end

-- q: registro del Codex. -> { aceptar = meta | nil, objetivos = { meta... }, entregar = meta,
--   dador, objetivo, fin (puntos), grupo, dentro } | nil (sin entrega conocida)
function I.PasosMision(q, desde)
	local C, Lk = CX(), LK()
	if not (q and C and Lk) then return nil end
	local p = I.Jugador()
	local dador = finDe(q.start, desde, p)
	local fin = finDe(q["end"], dador or desde, p)
	if not fin then return nil end
	local out = { objetivos = {}, dador = dador, fin = fin }
	local enLog = enRegistro(q.id)
	if dador then
		out.aceptar = metaNpc("accept", q, dador)
	elseif q.start and q.start.item and q.start.item[1] then
		local it = q.start.item[1]
		out.aceptar = { t = "accept", quest = q.id, title = q.title, item = it, itemName = M.NombreObjeto(it) }
	elseif not enLog then
		return nil
	end
	if out.aceptar then
		out.aceptar.minLevel = q.minLevel
		if Lk.AcceptPre then Lk.AcceptPre(out.aceptar, q) end
	end
	local aqui = dador or desde
	local evento
	for oi, o in ipairs(q.objectives or {}) do
		local n = M.num(o.count, 1)
		local g
		if o.type == "kill" and o.id then
			local npc = C.Npc(o.id)
			local nombre = (npc and npc.name) or o.text or format(L["PNJ %d"], o.id)
			local s = npc and Lk.Nearest(npc.spawns, aqui, true)
			g = en({ t = "kill", target = nombre, npc = o.id, tame = o.tame, quest = q.id, oi = oi, count = n, title = q.title, group = grupoDe(npc) }, s)
			lugares(g, npc and npc.spawns)
			if npc and npc.instance then out.dentro = true end
			if g.group then out.grupo = true end
		elseif o.type == "item" and o.id then
			local nombre = (C.Name("item", o.id)) or o.text or M.NombreObjeto(o.id)
			local s, rec, tipo, fid, spawns = fuenteObjeto(o.id, aqui)
			g = en({ t = "collect", item = o.id, itemName = nombre, quest = q.id, oi = oi, count = n, title = q.title, group = grupoDe(tipo == "npc" and rec or nil) }, s)
			if rec and rec.name then g.from, g.fromId, g.fromKind = rec.name, fid, tipo end
			lugares(g, spawns)
			if g.group then out.grupo = true end
		elseif o.type == "talk" and o.id then
			local npc = C.Npc(o.id)
			local s = npc and Lk.Nearest(npc.spawns, aqui, true)
			g = en({ t = "talk", npc = o.id, npcName = (npc and npc.name) or o.text or format(L["PNJ %d"], o.id), quest = q.id, oi = oi, title = q.title }, s)
		elseif o.type == "object" and o.id then
			local obj = C.Object(o.id)
			local s = obj and Lk.Nearest(obj.spawns, aqui, true)
			g = en({ t = "interact", object = o.id, objName = (obj and obj.name) or o.text or L["Objeto"], quest = q.id, oi = oi, count = n, title = q.title }, s)
			lugares(g, obj and obj.spawns)
		else
			evento = evento or o
		end
		if g then
			if not g.map then out.dentro = true end
			out.objetivos[#out.objetivos + 1] = g
			if g.map and not out.objetivo then out.objetivo = { map = g.map, x = g.x, y = g.y, f = g.f } end
		end
	end
	if evento then
		local g = en({ t = "complete", quest = q.id, title = q.title, text = evento.text }, evento.map and evento or nil)
		out.objetivos[#out.objetivos + 1] = g
		if g.map and not out.objetivo then out.objetivo = { map = g.map, x = g.x, y = g.y, f = g.f } end
	end
	-- Sin objetivos en el Codex pero con objetivos en tu registro (un dato que
	-- falta): lo que pide el juego, como meta "complete" (el motor muestra sus
	-- líneas del registro). Si no, el plan solo decía "Entrega" y te mandaba
	-- al PNJ con la misión sin terminar.
	if #out.objetivos == 0 and enLog then
		local Cp = CP()
		if Cp and Cp.GetQuestObjectives and Cp.GetQuestObjectives(q.id) then
			out.objetivos[1] = { t = "complete", quest = q.id, title = q.title }
		end
	end
	-- Misión de mazmorra: lo que pide se consigue dentro; la flecha lleva a la
	-- entrada (nunca al punto de afuera que trae el dato) y queda marcada para
	-- que el plan no la meta sin que la pidas.
	local clave, nombreMz = I.Mazmorra(q.id)
	if clave then
		out.dentro, out.grupo, out.mazmorra = true, true, nombreMz
		local entrada = I.EntradaMazmorra(clave)
		for _, g in ipairs(out.objetivos) do
			g.map, g.x, g.y, g.f, g.z, g.spots, g.spread = nil, nil, nil, nil, nil, nil, nil
			if entrada then en(g, entrada) end
			g.dentroDe = nombreMz
		end
		out.objetivo = entrada and { map = entrada.map, x = entrada.x, y = entrada.y, f = entrada.f } or nil
	end
	out.entregar = metaNpc("turnin", q, fin)
	return out
end

---------------------------------------------------------------------------
-- Profesiones: qué material conviene y dónde se junta
---------------------------------------------------------------------------

-- { itemId, habilidad desde la que conviene }, de menor a mayor.
I.MATERIALES = {
	[186] = { { 2770, 1 }, { 2771, 65 }, { 2772, 125 }, { 3858, 175 }, { 10620, 245 } }, -- Minería
	[182] = { { 2447, 1 }, { 785, 50 }, { 2450, 70 }, { 2453, 100 }, { 3355, 115 }, { 3356, 125 }, { 3357, 150 },
		{ 3818, 160 }, { 3821, 170 }, { 4625, 205 }, { 8838, 230 }, { 8846, 250 }, { 13463, 270 }, { 13465, 280 } }, -- Herboristería
	[393] = { { 2318, 1 }, { 2319, 100 }, { 4234, 150 }, { 4304, 200 }, { 8170, 250 } }, -- Desuello
}
-- Sin profesión de recolección: tela, por tu nivel.
I.TELAS = { { 2589, 1 }, { 2592, 15 }, { 4306, 25 }, { 4338, 35 }, { 14047, 48 } }
I.PROFESIONES = { 186, 182, 393 }

local function mejorDe(lista, valor)
	local id = lista[1][1]
	for _, par in ipairs(lista) do
		if valor >= par[2] then id = par[1] end
	end
	return id
end

-- -> itemId, línea de habilidad (nil para tela)
function I.MaterialSugerido()
	local Cp = CP()
	for _, linea in ipairs(I.PROFESIONES) do
		local rango = Cp and Cp.GetSkillRank and Cp.GetSkillRank(linea)
		if type(rango) == "number" then return mejorDe(I.MATERIALES[linea], rango), linea end
	end
	return mejorDe(I.TELAS, I.Jugador().level), nil
end

-- La línea de habilidad que recoge un material de la tabla, si es uno.
function I.LineaDe(itemId)
	for linea, lista in pairs(I.MATERIALES) do
		for _, par in ipairs(lista) do
			if par[1] == itemId then return linea end
		end
	end
	return nil
end

-- Los materiales que se ofrecen en el editor (los de tus profesiones y tela).
function I.MaterialesOfrecidos()
	local out, Cp = {}, CP()
	for _, linea in ipairs(I.PROFESIONES) do
		local rango = Cp and Cp.GetSkillRank and Cp.GetSkillRank(linea)
		if type(rango) == "number" then
			for _, par in ipairs(I.MATERIALES[linea]) do out[#out + 1] = { item = par[1], desde = par[2], linea = linea } end
		end
	end
	for _, par in ipairs(I.TELAS) do out[#out + 1] = { item = par[1], nivel = par[2] } end
	return out
end

-- Dónde juntar un material: la fuente que menos tarda (nodos de mineral o
-- hierba, o bichos que lo sueltan), con todos sus lugares de ese mapa.
-- -> { map, x, y, f, spots, spread, from, fromId, fromKind } | nil
function I.Recoleccion(itemId, desde)
	local C, Lk = CX(), LK()
	local item = C and C.Item(itemId)
	if not (item and Lk) then return nil end
	local nivel = I.Jugador().level
	local mejor, costo
	local nodos = {}
	for _, src in ipairs(item.sources or {}) do
		local r, k, id, p
		if src.type == "object" and src.object and (src.chance == nil or src.chance >= 25) then
			r, k, id, p = C.Object(src.object), "object", src.object, src.chance or 100
		elseif src.type == "drop" and src.npc and (src.chance or 0) >= 5 and not src.instance then
			local npc = C.Npc(src.npc)
			if npc and not npc.instance and not grupoDe(npc) and M.num(npc.level, nivel) <= nivel + 2 then
				r, k, id, p = npc, "npc", src.npc, src.chance
			end
		end
		if r and r.spawns and #r.spawns > 0 then
			local s, t = Lk.Nearest(r.spawns, desde, true)
			t = M.num(t, LEJOS)
			local c = t + (k == "npc" and (100 / p) * 25 or (100 / p) * 20)
			if s and (not costo or c < costo) then
				mejor, costo = { s = s, rec = r, kind = k, id = id }, c
			end
			if k == "object" then nodos[#nodos + 1] = r end
		end
	end
	if not mejor then return nil end
	local s = mejor.s
	local lugar = { map = s.map, x = s.x, y = s.y, f = marco(s.f), from = mejor.rec.name, fromId = mejor.id, fromKind = mejor.kind }
	-- Los nodos de todas las vetas o plantas de ese material, no solo una.
	local todos = mejor.rec.spawns
	if mejor.kind == "object" and #nodos > 1 then
		todos = {}
		for _, r in ipairs(nodos) do
			for _, sp in ipairs(r.spawns) do todos[#todos + 1] = sp end
		end
	end
	lugares(lugar, todos)
	if lugar.spots and not lugar.spread and #lugar.spots > 2 then lugar.spread = true end
	return lugar
end

-- ¿Hay misiones de clase cerca de tu nivel? (para la plantilla de Alfa)
function I.HayClase()
	local idx = I.Listo()
	if not idx then return false end
	local nivel = I.Jugador().level
	for _, e in ipairs(idx.lista) do
		if e.clase and not hecha(e.id) and e.lvl <= nivel + 4 and (e.min or 1) <= nivel + 2 then return true end
	end
	return false
end
