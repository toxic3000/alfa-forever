-- Alfa - Mazmorras: datos y progreso (toxic3000 / La Jauría). GPL-3.0.
--
-- Lee el diario del motor (Alfa.Dungeons: misiones, jefes, entrada), que
-- desde la 1.0 solo se ve a través de esta página (Reemplazos.lua), y le
-- suma lo que el motor no tiene:
--   * el botín de cada jefe, del Codex (Codex.Instance(key).bosses[i].items y
--     las fuentes de cada objeto, Codex.Item(id).sources: "drop" con su PNJ y
--     su probabilidad);
--   * los consejos por jefe (Consejos/*.lua, M.Consejos[key][id del PNJ]);
--   * el progreso de este personaje: jefes vencidos (ENCOUNTER_END y
--     BOSS_KILL, que dan el id del encuentro: el mismo `encounter` de las
--     páginas del motor), mazmorras hechas (su último jefe de encuentro),
--     botín obtenido (CHAT_MSG_LOOT dentro de la mazmorra, y lo que ya tienes)
--     y las pruebas por misiones entregadas (un jefe cuya misión de matarlo
--     ya entregaste está vencido).
-- Dentro de las mazmorras casi todo sobre los enemigos es secreto y no hay
-- registro de combate: aquí no se calcula nada del enemigo, solo se leen los
-- eventos de fin de encuentro y lo que el propio jugador recibe.
--
-- Datos por personaje (N.DatosPersonaje("mazmorras")):
--   hechas[key] = { veces = n, t = última vez, desde = primera, por = "jefe"|"antes"|"mision" }
--   jefes[key][idJefe] = { t = cuándo, por = "jefe"|"mision" }
--   botin[idObjeto] = { k = key, j = idJefe | nil, t = cuándo, por = "botin"|"tienes" }
-- Datos de la cuenta (N.Datos("mazmorras")):
--   entradas[key] = { mapa, m, x, y, f, nombre, min, max, tipo, jefes }   -- para el
--     minimapa y para saber en qué mazmorra estás sin cargar el Codex.
--
-- idJefe: el id de su PNJ como texto ("644"), "o<id>" para un cofre,
-- "e<encuentro>" para un grupo sin PNJ (Los enanos perdidos).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

local D = {}
M.D = D
local ID = "mazmorras"
D.ID = ID

local type, pairs, ipairs, tonumber, tostring, pcall, next = type, pairs, ipairs, tonumber, tostring, pcall, next
local floor = math.floor
local sort = table.sort
local format, lower, find, match = string.format, string.lower, string.find, string.match

---------------------------------------------------------------------------
-- Ayudas
---------------------------------------------------------------------------

local function secreto(v)
	local C = A.Compat
	if C and C.IsSecret then return C.IsSecret(v) == true end
	return issecretvalue ~= nil and v ~= nil and issecretvalue(v) and true or false
end

local function legible(v)
	if secreto(v) then return nil end
	return v
end
D.Legible = legible

local function ahora()
	local C = A.Compat
	local t = C and C.Now and C.Now()
	if type(t) == "number" then return t end
	return time and time() or 0
end
D.Ahora = ahora

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d
end
D.Llamar = llamar

-- Oyentes internos (la vista y la capa del minimapa): fn(que)
local oyentes = {}
function D.AlCambiar(fn) oyentes[#oyentes + 1] = fn end
function D.Avisar(que)
	for i = 1, #oyentes do
		local ok, err = pcall(oyentes[i], que)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
end

-- Tu nivel y tu bando ("A", "H" o nil).
function D.Nivel()
	local C = A.Compat
	local info = C and llamar(C.GetPlayerInfo)
	if type(info) == "table" and type(info.level) == "number" then return info.level end
	local n = UnitLevel and legible(UnitLevel("player"))
	return type(n) == "number" and n or 1
end

function D.Lado()
	local C = A.Compat
	local f = C and llamar(C.GetPlayerFaction)
	return f == "Alliance" and "A" or f == "Horde" and "H" or nil
end

-- Lo que se le cuenta al jugador al entrar, al descubrir un jefe y al
-- terminar una mazmorra. La vista lo muestra con un aviso del Kit
-- (M.Anunciar); sin ella, una línea en el chat.
local function anunciar(tipo, key, a, b, texto)
	if M.Anunciar then
		local ok, err = pcall(M.Anunciar, tipo, key, a, b)
		if ok then return end
		if geterrorhandler then geterrorhandler()(err) end
	end
	if texto then N.Imprimir(texto) end
end

local function prog()
	local d = N.DatosPersonaje(ID)
	if type(d.hechas) ~= "table" then d.hechas = {} end
	if type(d.jefes) ~= "table" then d.jefes = {} end
	if type(d.botin) ~= "table" then d.botin = {} end
	return d
end
D.Progreso = prog

local function cuenta()
	local d = N.Datos(ID)
	if type(d.entradas) ~= "table" then d.entradas = {} end
	return d
end

---------------------------------------------------------------------------
-- El diario del motor
---------------------------------------------------------------------------

-- -> listo, razón ("off", "combat", "missing", "nodata", "motor"...)
function D.Listo()
	local Dg = A.Dungeons
	if not (Dg and Dg.Load) then return false, "motor" end
	local ok, listo, razon = pcall(Dg.Load)
	if not ok then return false, "error" end
	return listo == true, razon
end

local lista -- Dungeons.List(), guardada mientras no cambien los nombres
local jefesCache = {} -- key -> { jefe, ... }
local porEncuentro -- encounterID -> key

local function olvidarCaches()
	lista, jefesCache, porEncuentro = nil, {}, nil
end

-- Las entradas en los datos de la cuenta: el minimapa las pinta sin cargar
-- el Codex al iniciar sesión.
local function guardarEntradas(l)
	local e = cuenta().entradas
	for _, d in ipairs(l) do
		local en = d.entrance
		if type(d.key) == "string" then
			e[d.key] = {
				mapa = d.map, m = en and en.map, x = en and en.x, y = en and en.y, f = en and en.f,
				nombre = d.name, min = d.minLevel, max = d.maxLevel, tipo = d.kind, jefes = d.bosses,
			}
		end
	end
end

function D.Lista()
	if lista then return lista end
	local Dg = A.Dungeons
	local l = Dg and llamar(Dg.List)
	if type(l) ~= "table" or #l == 0 then return {} end
	lista = l
	guardarEntradas(l)
	return l
end

function D.Entradas() return cuenta().entradas end

function D.Info(key)
	if type(key) ~= "string" then return nil end
	for _, d in ipairs(D.Lista()) do
		if d.key == key then return d end
	end
	return nil
end

-- El nombre de una mazmorra aunque el Codex no esté cargado.
function D.Nombre(key)
	local d = D.Info(key)
	if d and d.name then return d.name end
	local e = cuenta().entradas[key]
	return (e and e.nombre) or key
end

local function idJefe(b, i)
	if type(b.npc) == "number" then return tostring(b.npc) end
	if type(b.object) == "number" then return "o" .. b.object end
	if type(b.encounter) == "number" then return "e" .. b.encounter end
	return "i" .. tostring(i)
end

local function consejosDe(t, b)
	if type(t) ~= "table" then return nil end
	return (b.npc and t[b.npc]) or (b.encounter and t["e" .. b.encounter]) or (b.object and t["o" .. b.object]) or nil
end

-- Los jefes de una página del motor, en orden, con sus consejos. El botín se
-- calcula aparte (D.BotinDe) para que indexar los encuentros sea liviano.
--   jefe = { id, orden, nombre, npc, objeto, nivel, encuentro, rol, final, misiones, consejos }
function D.Jefes(key)
	if type(key) ~= "string" then return {} end
	local c = jefesCache[key]
	if c then return c end
	local Dg = A.Dungeons
	local bosses = Dg and llamar(Dg.Bosses, key)
	if type(bosses) ~= "table" or #bosses == 0 then return {} end
	local consejos = M.Consejos and M.Consejos[key]
	local out, ultimo = {}, nil
	for i, b in ipairs(bosses) do
		if type(b) == "table" then
			local j = {
				id = idJefe(b, i), orden = b.order or i, nombre = b.name, npc = b.npc, objeto = b.object,
				nivel = b.level, encuentro = b.encounter, rol = b.role, misiones = b.quests,
				consejos = consejosDe(consejos, b), indice = i,
			}
			out[#out + 1] = j
			if not b.role then ultimo = j end
		end
	end
	if ultimo then ultimo.final = true end
	jefesCache[key] = out
	return out
end

function D.Consejos(key)
	local t = M.Consejos and M.Consejos[key]
	return type(t) == "table" and t.general or nil
end

---------------------------------------------------------------------------
-- Botín (Codex)
---------------------------------------------------------------------------

-- El jefe del Codex que corresponde al del motor: por PNJ, por cofre, o por
-- su lugar en la lista (los dos van en el mismo orden).
local function jefeCodex(lista, j)
	for _, cb in ipairs(lista) do
		if j.npc and cb.npc == j.npc then return cb end
		if j.objeto and cb.object == j.objeto then return cb end
	end
	local cb = lista[j.indice]
	if cb and not cb.npc and not cb.object and not j.npc and not j.objeto then return cb end
	return nil
end

-- Un objeto es "del jefe" cuando nadie más lo suelta (sus objetos de misión,
-- los objetos nuevos de Forever, raros pero suyos) o, desde poco común,
-- cuando él lo suelta seguido (5 % o más). El resto de lo que suelta desde
-- poco común (recetas, verdes y azules del mundo) va en "botín poco
-- probable", los EXTRA más probables. Lo común que sueltan muchos (tela,
-- comida, pociones, piedras) y lo gris no se listan.
local PROPIO, EXTRA = 5, 15

local function clasificar(cb, j)
	local principal, extra = {}, {}
	local X = A.Codex
	if not (cb and type(cb.items) == "table" and X and X.Item) then return principal, extra end
	local visto = {}
	local grupo = not j.npc and not j.objeto
	for _, id in ipairs(cb.items) do
		if type(id) == "number" and not visto[id] then
			visto[id] = true
			local rec = llamar(X.Item, id)
			if type(rec) == "table" and rec.status ~= "retired" then
				local chance, suyo, otros = nil, false, false
				for _, s in ipairs(rec.sources or {}) do
					if s.type == "drop" and j.npc and s.npc == j.npc then
						chance, suyo = s.chance, true
					elseif s.type == "object" and j.objeto and s.object == j.objeto then
						chance, suyo = s.chance, true
					else
						otros = true
					end
				end
				local q = rec.quality
				local e = { id = id, chance = chance, calidad = q, req = rec.reqLevel, nombre = rec.name, jefe = j.id }
				if grupo then
					if (q or 2) >= 2 then principal[#principal + 1] = e end
				elseif suyo then
					local seguido = type(chance) == "number" and chance >= PROPIO
					if not otros and (q == nil or q >= 1) then
						principal[#principal + 1] = e
					elseif seguido and (q == nil or q >= 2) then
						principal[#principal + 1] = e
					elseif (q or 0) >= 2 then
						extra[#extra + 1] = e
					end
				end
			end
		end
	end
	local function porChance(a, b)
		local ca, cb2 = a.chance or 0, b.chance or 0
		if ca ~= cb2 then return ca > cb2 end
		return a.id < b.id
	end
	sort(principal, porChance)
	sort(extra, porChance)
	for i = #extra, EXTRA + 1, -1 do extra[i] = nil end
	return principal, extra
end

-- -> principal, extra (listas de { id, chance, calidad, req, nombre, jefe })
function D.BotinDe(key, j)
	if j.botin then return j.botin, j.extra end
	local X = A.Codex
	local inst = X and llamar(X.Instance, key)
	local lista = type(inst) == "table" and type(inst.bosses) == "table" and inst.bosses or {}
	j.botin, j.extra = clasificar(jefeCodex(lista, j), j)
	return j.botin, j.extra
end

-- Todo el botín principal de la mazmorra, sin repetir, de mejor a peor.
function D.BotinMazmorra(key)
	local out, visto = {}, {}
	for _, j in ipairs(D.Jefes(key)) do
		local principal = D.BotinDe(key, j)
		for _, e in ipairs(principal) do
			if not visto[e.id] then
				visto[e.id] = true
				out[#out + 1] = e
			end
		end
	end
	sort(out, function(a, b)
		local qa, qb = a.calidad or 0, b.calidad or 0
		if qa ~= qb then return qa > qb end
		local ra, rb = a.req or 0, b.req or 0
		if ra ~= rb then return ra > rb end
		return a.id < b.id
	end)
	return out
end

-- Lo que el cliente sabe de un objeto, sin preguntar al servidor:
-- -> { nombre, calidad, icono, ranura, tipo, link }
local INVTIPO_NADA = { [""] = true, INVTYPE_NON_EQUIP_IGNORE = true, INVTYPE_NON_EQUIP = true }
function D.Objeto(e)
	local C = A.Compat
	local id = e.id
	local o = {}
	local X = A.Codex
	local rec
	if not e.nombre and X and X.IsLoaded and llamar(X.IsLoaded) then
		rec = llamar(X.Item, id)
		if type(rec) ~= "table" then rec = nil end
	end
	o.nombre = (C and llamar(C.GetItemName, id)) or e.nombre or (rec and rec.name) or (L["Objeto"] .. " " .. tostring(id))
	o.calidad = (C and llamar(C.GetItemQuality, id)) or e.calidad or (rec and rec.quality)
	o.req = e.req or (rec and rec.reqLevel)
	o.icono = C and llamar(C.ItemIcon, id)
	o.link = C and llamar(C.ItemLink, id)
	if C_Item and C_Item.GetItemInfoInstant then
		local _, tipo, subtipo, ranura = llamar(C_Item.GetItemInfoInstant, id)
		if type(ranura) == "string" and not INVTIPO_NADA[ranura] then
			local nombre = _G[ranura]
			if type(nombre) == "string" and nombre ~= "" then o.ranura = nombre end
		end
		if type(subtipo) == "string" and subtipo ~= "" and o.ranura then
			o.tipo = subtipo
		elseif type(tipo) == "string" and tipo ~= "" then
			o.tipo = tipo
		end
	end
	if (type(o.calidad) ~= "number" or not o.link) and C and C.RequestItem then llamar(C.RequestItem, id) end
	return o
end

-- ¿Lo tiene el personaje (bolsas, banco o puesto)?
function D.Tengo(id)
	if not C_Item then return false end
	local n = legible(llamar(C_Item.GetItemCount, id, true))
	if type(n) == "number" and n > 0 then return true end
	return legible(llamar(C_Item.IsEquippedItem, id)) == true
end

-- Piezas que cualquier clase usa sin tipo de armadura (cuello, anillos,
-- abalorios, capa, objetos que se sostienen).
local SIN_ARMADURA = { [2] = true, [11] = true, [12] = true, [16] = true, [23] = true }

-- "Lo que me sirve": equipo que tu clase puede usar, de tu mejor tipo de
-- armadura (malla a partir de 40 para guerreros, paladines, cazadores y
-- chamanes) y con algo que le sirva a tu especialización (Gear.ScoreItem).
-- nil: el motor no tiene Gear.
function D.MeSirve(id)
	local G = A.Gear
	if not (G and G.GetItemInfo and G.Usability) then return nil end
	local C = A.Compat
	local link = (C and llamar(C.ItemLink, id)) or id
	local jugador = llamar(G.GetPlayer)
	local info = llamar(G.GetItemInfo, link)
	if type(info) ~= "table" then return false end
	if llamar(G.Usability, info) ~= true then return false end
	if info.class == 4 and type(info.subclass) == "number" and info.subclass >= 1 and info.subclass <= 4 and not SIN_ARMADURA[info.inv] then
		local prof = type(jugador) == "table" and type(G.PROFICIENCY) == "table" and G.PROFICIENCY[jugador.class]
		if type(prof) == "table" and type(prof.armor) == "number" then
			local mejor = prof.armor
			if prof.armorAt40 and ((jugador.level or 1) >= 40 or (info.req or 0) >= 40) then mejor = prof.armorAt40 end
			if info.subclass ~= mejor then return false end
		end
	end
	local puntos = llamar(G.ScoreItem, link)
	if type(puntos) == "number" and puntos <= 0 then return false end
	return true
end

-- La flecha de mejora del motor (Gear.IsUpgrade):
-- -> esMejora, porcentaje, nivel (cuando servirá más adelante)
function D.Mejora(id)
	local G = A.Gear
	if not (G and G.IsUpgrade) then return false end
	if G.IsEnabled and not llamar(G.IsEnabled) then return false end
	local C = A.Compat
	local link = (C and llamar(C.ItemLink, id)) or id
	local up, _, pct = llamar(G.IsUpgrade, link)
	if up == true then return true, pct end
	local r = llamar(G.CompareToEquipped, link)
	local jugador = llamar(G.GetPlayer)
	local nivel = type(jugador) == "table" and jugador.level or 1
	if type(r) == "table" and r.usable and type(r.delta) == "number" and r.delta > 0 and (r.minLevel or 0) > nivel then
		return false, r.pct, r.minLevel
	end
	return false
end

---------------------------------------------------------------------------
-- Progreso del personaje
---------------------------------------------------------------------------

function D.Historia() return N.Get(ID, "historia") and true or false end

function D.Hecha(key)
	local h = prog().hechas[key]
	return type(h) == "table" and h or nil
end

function D.Vencido(key, jid)
	local t = prog().jefes[key]
	local r = type(t) == "table" and t[jid]
	return type(r) == "table" and r or nil
end

-- En modo historia, la página de un jefe se abre al vencerlo, y la mazmorra
-- entera al terminarla (o al marcarla como hecha antes).
function D.Descubierto(key, j)
	if not D.Historia() then return true end
	if D.Hecha(key) then return true end
	return D.Vencido(key, j.id) ~= nil
end

-- -> vencidos, total (jefes de encuentro)
function D.Cuenta(key)
	local v, total = 0, 0
	local t = prog().jefes[key]
	local jefes = D.Jefes(key)
	if #jefes == 0 then
		local e = cuenta().entradas[key]
		total = e and e.jefes or 0
		if type(t) == "table" then for _ in pairs(t) do v = v + 1 end end
		return v, total
	end
	for _, j in ipairs(jefes) do
		if not j.rol then
			total = total + 1
			if type(t) == "table" and type(t[j.id]) == "table" then v = v + 1 end
		end
	end
	return v, total
end

-- -> true si es la primera vez
function D.MarcarJefe(key, jid, por)
	local p = prog()
	local t = p.jefes[key]
	if type(t) ~= "table" then
		t = {}
		p.jefes[key] = t
	end
	if type(t[jid]) == "table" then return false end
	t[jid] = { t = ahora(), por = por }
	return true
end

-- contar: una vuelta completa más (el último jefe cayó ahora).
-- -> true si es la primera vez que queda hecha
function D.MarcarHecha(key, por, contar)
	local p = prog()
	local h = p.hechas[key]
	local nueva = type(h) ~= "table"
	if nueva then
		h = { veces = 0, desde = ahora(), por = por }
		p.hechas[key] = h
	end
	if contar then
		h.veces = (h.veces or 0) + 1
		h.t = ahora()
	end
	return nueva
end

function D.Olvidar(key)
	local p = prog()
	p.hechas[key], p.jefes[key] = nil, nil
	for id, b in pairs(p.botin) do
		if type(b) == "table" and b.k == key then p.botin[id] = nil end
	end
	D.Avisar("progreso")
end

function D.OlvidarTodo()
	local d = N.DatosPersonaje(ID)
	d.hechas, d.jefes, d.botin = {}, {}, {}
	D.Avisar("progreso")
end

function D.Botin(id)
	local b = prog().botin[id]
	return type(b) == "table" and b or nil
end

function D.MarcarBotin(id, key, jid, por)
	local p = prog()
	if type(p.botin[id]) == "table" then return false end
	p.botin[id] = { k = key, j = jid, t = ahora(), por = por }
	return true
end

-- Un objeto del botín que ya tienes cuenta como obtenido.
function D.Obtenido(e, key)
	if D.Botin(e.id) then return true end
	if D.Tengo(e.id) then
		D.MarcarBotin(e.id, key, e.jefe, "tienes")
		return true
	end
	return false
end

-- Misiones que prueban un jefe vencido: matarlo, recoger lo que suelta o
-- la misión que empieza su objeto, ya entregadas por este personaje.
local PRUEBA = { kill = true, item = true, starts = true }
function D.RevisarMisiones(key)
	local C = A.Compat
	if not (C and C.IsQuestCompleted) then return false end
	local cambio = false
	for _, j in ipairs(D.Jefes(key)) do
		if not D.Vencido(key, j.id) and type(j.misiones) == "table" then
			for _, q in ipairs(j.misiones) do
				if type(q) == "table" and PRUEBA[q.how] and type(q.id) == "number" and llamar(C.IsQuestCompleted, q.id) == true then
					D.MarcarJefe(key, j.id, "mision")
					cambio = true
					break
				end
			end
		end
		if j.final and D.Vencido(key, j.id) and not D.Hecha(key) then
			D.MarcarHecha(key, "mision", false)
			cambio = true
		end
	end
	return cambio
end

-- Una vez por sesión (y tras entregar misiones) al abrir la página.
local revisado = false
function D.RevisarTodo()
	if revisado then return false end
	if not D.Listo() then return false end
	revisado = true
	local cambio = false
	for _, d in ipairs(D.Lista()) do
		if D.RevisarMisiones(d.key) then cambio = true end
	end
	return cambio
end

function D.MarcarAntes(key)
	for _, j in ipairs(D.Jefes(key)) do
		if not j.rol then D.MarcarJefe(key, j.id, "antes") end
	end
	D.MarcarHecha(key, "antes", false)
	D.Avisar("progreso")
end

-- -> hechas, jefes, objetos, veces
function D.Resumen()
	local p = prog()
	local hechas, jefes, objetos, veces = 0, 0, 0, 0
	for _, h in pairs(p.hechas) do
		if type(h) == "table" then
			hechas = hechas + 1
			veces = veces + (h.veces or 0)
		end
	end
	for _, t in pairs(p.jefes) do
		if type(t) == "table" then for _ in pairs(t) do jefes = jefes + 1 end end
	end
	for _ in pairs(p.botin) do objetos = objetos + 1 end
	return hechas, jefes, objetos, veces
end

---------------------------------------------------------------------------
-- Dónde estás
---------------------------------------------------------------------------

function D.MazmorraActual()
	local C = A.Compat
	local mapa = C and legible(llamar(C.GetInstanceMapID))
	if type(mapa) ~= "number" then return nil end
	for key, e in pairs(cuenta().entradas) do
		if type(e) == "table" and e.mapa == mapa then return key end
	end
	local Dg = A.Dungeons
	local key = Dg and llamar(Dg.ForMap, mapa)
	return type(key) == "string" and key or nil
end

local function indiceEncuentros()
	if porEncuentro then return porEncuentro end
	local idx = {}
	for _, d in ipairs(D.Lista()) do
		for _, j in ipairs(D.Jefes(d.key)) do
			if type(j.encuentro) == "number" then idx[j.encuentro] = d.key end
		end
	end
	if next(idx) then porEncuentro = idx end
	return idx
end

local function jefePorEncuentro(key, encId, nombre)
	if not key then return nil end
	local jefes = D.Jefes(key)
	for _, j in ipairs(jefes) do
		if j.encuentro == encId then return j end
	end
	if type(nombre) == "string" and nombre ~= "" then
		local n = lower(nombre)
		for _, j in ipairs(jefes) do
			if type(j.nombre) == "string" and lower(j.nombre) == n then return j end
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Fin de un encuentro: el jefe queda vencido; el último, la mazmorra hecha.
---------------------------------------------------------------------------

local recientes = {} -- encounterID -> momento (ENCOUNTER_END y BOSS_KILL llegan juntos)

local function alVencer(encId, nombre)
	if not D.Listo() then return end
	local key = D.MazmorraActual()
	local j = jefePorEncuentro(key, encId, nombre)
	if not j then
		key = indiceEncuentros()[encId]
		j = jefePorEncuentro(key, encId, nombre)
	end
	if not j then return end
	local nuevo = D.MarcarJefe(key, j.id, "jefe")
	local primeraVez
	if j.final then primeraVez = D.MarcarHecha(key, "jefe", true) end
	local nombreM = D.Nombre(key)
	if j.final then
		local h = D.Hecha(key)
		local veces = h and h.veces or 1
		anunciar("hecha", key, (primeraVez or veces <= 1) and 1 or veces, nil,
			format(L["¡Completaste %s!"], nombreM))
	elseif nuevo and D.Historia() and N.Get(ID, "avisoDescubrir") then
		anunciar("jefe", key, j, nil, format(L["Descubriste a %s (%s)."], j.nombre or "?", nombreM))
	end
	D.Avisar("progreso")
end

local function victoria(encId, nombre)
	encId = legible(encId)
	if type(encId) ~= "number" then return end
	nombre = legible(nombre)
	if type(nombre) ~= "string" then nombre = nil end
	local t = GetTime and GetTime() or 0
	local antes = recientes[encId]
	if antes and t - antes < 60 then return end
	recientes[encId] = t
	-- Fuera de combate: el Codex no se carga en combate.
	N.FueraDeCombate(function() alVencer(encId, nombre) end)
end

A.RegisterEvent("ENCOUNTER_END", function(_, encId, nombre, _, _, exito)
	exito = legible(exito)
	if exito ~= 1 and exito ~= true then return end
	victoria(encId, nombre)
end)

A.RegisterEvent("BOSS_KILL", function(_, encId, nombre)
	victoria(encId, nombre)
end)

---------------------------------------------------------------------------
-- Botín recibido dentro de la mazmorra (CHAT_MSG_LOOT con los textos del
-- propio cliente: "Recibes botín: %s.")
---------------------------------------------------------------------------

local function patron(fmt)
	if type(fmt) ~= "string" or fmt == "" then return nil end
	local s = fmt:gsub("%%%d*%$?s", "\1"):gsub("%%%d*%$?d", "\2")
	s = s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	s = s:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
	return "^" .. s
end

local patrones
local function esMio(texto)
	if not patrones then
		patrones = {}
		for _, g in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }) do
			local p = patron(_G[g])
			if p then patrones[#patrones + 1] = p end
		end
	end
	for _, p in ipairs(patrones) do
		if find(texto, p) then return true end
	end
	return false
end

-- El jefe del que vino: el que lo suelta; si lo sueltan varios, el que
-- cayó más recientemente.
local function registrarBotin(id)
	if not D.Listo() then return end
	local key = D.MazmorraActual()
	if not key or D.Botin(id) then return end
	local mejor, cuando
	local vencidos = prog().jefes[key]
	for _, j in ipairs(D.Jefes(key)) do
		local principal, extra = D.BotinDe(key, j)
		local esta = false
		for _, lista2 in ipairs({ principal, extra }) do
			for _, e in ipairs(lista2) do
				if e.id == id then esta = true end
			end
		end
		if esta then
			local v = type(vencidos) == "table" and vencidos[j.id]
			local t = type(v) == "table" and v.t or 0
			if not mejor or t > cuando then mejor, cuando = j, t end
		end
	end
	if not mejor then return end
	if D.MarcarBotin(id, key, mejor.id, "botin") then D.Avisar("botin") end
end

A.RegisterEvent("CHAT_MSG_LOOT", function(_, texto)
	if secreto(texto) or type(texto) ~= "string" then return end
	if not esMio(texto) then return end
	local id = tonumber(match(texto, "|Hitem:(%d+)"))
	if not id then return end
	local C = A.Compat
	if not (C and llamar(C.IsInInstance)) then return end
	N.FueraDeCombate(function() registrarBotin(id) end)
end)

---------------------------------------------------------------------------
-- Al entrar a una mazmorra: una línea en el chat (avisoEntrar)
---------------------------------------------------------------------------

local ultimaEntrada
local function avisoEntrada()
	local C = A.Compat
	if not (C and llamar(C.IsInInstance)) then
		ultimaEntrada = nil
		return
	end
	if not D.Listo() then return end
	local key = D.MazmorraActual()
	if not key or key == ultimaEntrada then return end
	ultimaEntrada = key
	D.RevisarMisiones(key)
	D.Avisar("entrada")
	if not N.Get(ID, "avisoEntrar") then return end
	local v, total = D.Cuenta(key)
	anunciar("entrada", key, v, total, format(L["Entraste a %s."], D.Nombre(key)))
end

A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if A.After then
		A.After(4, function() N.FueraDeCombate(avisoEntrada) end)
	end
end)

A.RegisterEvent("QUEST_TURNED_IN", function()
	revisado = false
end)

---------------------------------------------------------------------------
-- Cachés
---------------------------------------------------------------------------

A.On("CODEX_LOADED", function()
	olvidarCaches()
	D.Lista()
	D.Avisar("codex")
end)
A.On("NAMES_LOADED", function()
	olvidarCaches()
	D.Avisar("nombres")
end)
