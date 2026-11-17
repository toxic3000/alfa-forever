-- Alfa - Enciclopedia: los índices al revés (toxic3000 / La Jauría). GPL-3.0.
--
-- El Codex dice de dónde sale cada objeto; la enciclopedia también quiere lo
-- contrario: lo que vende o suelta un PNJ, lo que da un cofre o un banco de
-- peces, lo que hay dentro de un contenedor, las misiones que da o pide
-- cada quien y lo que hay en cada zona. Se arman una vez por sesión, por
-- lotes y en segundo plano, solo después de abrir la enciclopedia:
--   objetos  (Catalogo.lua, al preparar las facetas): vende, suelta, da, contiene, receta
--   misiones (I.PrepararMisiones): niveles, bandos y masks, quién las da y las recibe,
--            qué objetos piden o las empiezan, a quién hay que matar, por zona
--   raros    (I.PrepararRaros): la zona y el nivel de cada raro y tesoro
--   servicios (I.PrepararServicios): los PNJ con oficio (vuelo, posada...) por zona
-- Cada fila de vende/suelta/da/contiene es un número: M.Empacar(id, probabilidad).

local ADDON, M = ...
local A, L, K = M.A, M.L, M.K
local I = {}
M.Indices = I

local type, tonumber, ipairs, pairs, pcall = type, tonumber, ipairs, pairs, pcall
local min, sort = math.min, table.sort
local Empacar = M.Empacar

local listos = { objetos = false, misiones = false, raros = false, servicios = false }
function I.Listo(nombre) return listos[nombre] end

local VACIA = {}

local function agregar(t, clave, v)
	if clave == nil then return end
	local l = t[clave]
	if not l then
		l = {}
		t[clave] = l
	end
	l[#l + 1] = v
end

-- Una vez armadas, las listas se guardan como texto ("12,345,678"): ocupan
-- una fracción de lo que ocupa una tabla. Se leen solo al abrir una ficha.
local function compactar(t)
	for k, l in pairs(t) do t[k] = table.concat(l, ",") end
	return t
end

local function lista(t, clave)
	local s = clave ~= nil and t[clave]
	if not s then return VACIA end
	if type(s) == "table" then return s end
	local out = {}
	for v in s:gmatch("[^,]+") do out[#out + 1] = tonumber(v) end
	return out
end

---------------------------------------------------------------------------
-- Objetos: se llama una vez por cada registro del Codex (Catalogo.lua)
---------------------------------------------------------------------------
local vende, suelta, da, contiene, receta = {}, {}, {}, {}, {}
local nuevos

function I.Empezar()
	nuevos = { vende = {}, suelta = {}, da = {}, contiene = {}, receta = {} }
end

function I.Objeto(rec)
	local t = nuevos
	if not t then return end
	local id = rec.id
	if rec.kind == "recipe" and rec.spell then t.receta[rec.spell] = id end
	for _, s in ipairs(rec.sources or {}) do
		local tipo = s.type
		if tipo == "vendor" then agregar(t.vende, s.npc, id)
		elseif tipo == "drop" then agregar(t.suelta, s.npc, Empacar(id, s.chance))
		elseif tipo == "object" then agregar(t.da, s.object, Empacar(id, s.chance))
		elseif tipo == "container" then agregar(t.contiene, s.item, Empacar(id, s.chance)) end
	end
end

function I.Terminar()
	local t = nuevos
	if not t then return end
	nuevos = nil
	vende, suelta, da, contiene, receta = compactar(t.vende), compactar(t.suelta), compactar(t.da), compactar(t.contiene), t.receta
	listos.objetos = true
	if M.alIndice then K.Llamar(M.alIndice, "objetos") end
end

function I.Vende(npc) return lista(vende, npc) end
function I.Suelta(npc) return lista(suelta, npc) end
function I.Da(objeto) return lista(da, objeto) end
function I.Contiene(item) return lista(contiene, item) end
function I.Receta(hechizo) return hechizo and receta[hechizo] or nil end

---------------------------------------------------------------------------
-- Misiones: sus datos en columnas por fila del catálogo de misiones (nivel,
-- nivel mínimo, bando, razas, clases) y las listas al revés por id.
---------------------------------------------------------------------------
local filaDe = {}   -- id de misión -> fila del catálogo
local col = { nivel = {}, min = {}, bando = {}, razas = {}, clases = {} }
local daNpc, recibeNpc, daObjeto, empiezaItem, pideItem, pideMatar, porZona = {}, {}, {}, {}, {}, {}, {}

function I.MisionesListas() return listos.misiones end

local function pasoMisiones()
	local C = M.CodexListo()
	local c = M.Cat.Col("mision")
	local n = c and c.n or 0
	local i = 0
	local t = { filaDe = {}, nivel = {}, min = {}, bando = {}, razas = {}, clases = {},
		daNpc = {}, recibeNpc = {}, daObjeto = {}, empiezaItem = {}, pideItem = {}, pideMatar = {}, porZona = {} }
	return function()
		if not (C and c) then return true end
		local hasta = min(n, i + 150)
		for j = i + 1, hasta do
			local id = c.id[j]
			local q = C.Quest(id)
			t.filaDe[id] = j
			if q then
				t.nivel[j], t.min[j] = q.level or false, q.minLevel or false
				t.bando[j], t.razas[j], t.clases[j] = q.faction or false, q.races or false, q.classes or false
				for _, x in ipairs(q.start and q.start.npc or VACIA) do agregar(t.daNpc, x, id) end
				for _, o in ipairs(q.start and q.start.object or VACIA) do agregar(t.daObjeto, o, id) end
				for _, it in ipairs(q.start and q.start.item or VACIA) do agregar(t.empiezaItem, it, id) end
				for _, x in ipairs(q["end"] and q["end"].npc or VACIA) do agregar(t.recibeNpc, x, id) end
				for _, o in ipairs(q.objectives or VACIA) do
					if o.type == "item" and o.id then agregar(t.pideItem, o.id, id)
					elseif o.type == "kill" and o.id then agregar(t.pideMatar, o.id, id) end
				end
				if q.zone then agregar(t.porZona, q.zone, id) end
			else
				t.nivel[j], t.min[j], t.bando[j], t.razas[j], t.clases[j] = false, false, false, false, false
			end
		end
		i = hasta
		if i >= n then
			filaDe = t.filaDe
			col = { nivel = t.nivel, min = t.min, bando = t.bando, razas = t.razas, clases = t.clases }
			daNpc, recibeNpc, daObjeto = compactar(t.daNpc), compactar(t.recibeNpc), compactar(t.daObjeto)
			empiezaItem, pideItem, pideMatar, porZona = compactar(t.empiezaItem), compactar(t.pideItem), compactar(t.pideMatar), t.porZona
			local nivel = col.nivel
			for _, lista in pairs(porZona) do
				sort(lista, function(a, b)
					local la, lb = nivel[filaDe[a]] or 0, nivel[filaDe[b]] or 0
					if la ~= lb then return la < lb end
					return a < b
				end)
			end
			return true
		end
		return false
	end
end

local function empezarMisiones(fn)
	if M.Corriendo("misiones") then
		if fn then M.Tarea("misiones", nil, fn) end
		return
	end
	M.Tarea("misiones", pasoMisiones(), function(ok)
		listos.misiones = ok
		if M.alIndice then K.Llamar(M.alIndice, "misiones") end
		if fn then K.Llamar(fn, ok) end
	end)
end

function I.PrepararMisiones(fn)
	if listos.misiones then return K.Llamar(fn, true) end
	if not M.CodexListo() then return K.Llamar(fn, false) end
	-- Necesita el catálogo de misiones (sus filas).
	M.Cat.Pedir("mision", function(ok)
		if ok then empezarMisiones(fn) elseif fn then K.Llamar(fn, false) end
	end)
end

function I.NivelFila(j) local v = col.nivel[j] return v or nil end
function I.NivelMision(id) local j = filaDe[id] return j and I.NivelFila(j) end
function I.DaNpc(npc) return lista(daNpc, npc) end
function I.RecibeNpc(npc) return lista(recibeNpc, npc) end
function I.DaObjeto(obj) return lista(daObjeto, obj) end
function I.EmpiezaItem(item) return lista(empiezaItem, item) end
function I.PideItem(item) return lista(pideItem, item) end
function I.PideMatar(npc) return lista(pideMatar, npc) end
function I.PorZona(zona) return porZona[zona] or VACIA end

-- ¿La puedes tomar? (bando, raza, clase, nivel y que no la hayas hecho), con
-- las mismas reglas que el motor (Lookup.QuestBlock).
local ligera = {}
local jugador
A.RegisterEvent("PLAYER_LEVEL_UP", function() jugador = nil end)

local function bloqueoFila(j, id)
	local Lk = A.Lookup
	if not (j and Lk and Lk.QuestBlock and Lk.PlayerInfo) then return nil end
	if not jugador then jugador = Lk.PlayerInfo() end
	ligera.id = id
	ligera.faction = col.bando[j] or nil
	ligera.races = col.razas[j] or nil
	ligera.classes = col.clases[j] or nil
	ligera.minLevel = col.min[j] or nil
	local ok, why = pcall(Lk.QuestBlock, ligera, jugador)
	return ok and why or nil
end

function I.ParaMiFila(j)
	local c = M.Cat.Col("mision")
	return c and bloqueoFila(j, c.id[j]) == nil or false
end

function I.MisionParaMi(id)
	local j = filaDe[id]
	if not j then return false end
	return bloqueoFila(j, id) == nil
end

---------------------------------------------------------------------------
-- Raros y tesoros: su zona (la del primer lugar donde aparecen) y su nivel
---------------------------------------------------------------------------
local raro = {} -- "rare:61" -> { zona, nivel, elite }

function I.RarosListos() return listos.raros end

local function pasoRaros()
	local C = M.CodexListo()
	local lista = {}
	if C then
		C.Each("rare", function(id) lista[#lista + 1] = { "rare", id } end)
		C.Each("treasure", function(id) lista[#lista + 1] = { "treasure", id } end)
	end
	local i = 0
	local t = {}
	return function()
		if not C then return true end
		local hasta = min(#lista, i + 100)
		for j = i + 1, hasta do
			local kind, id = lista[j][1], lista[j][2]
			local rec = kind == "rare" and C.Npc(id) or C.Object(id)
			if rec then
				local s = rec.spawns and rec.spawns[1]
				t[kind .. ":" .. id] = { zona = s and s.map, nivel = rec.level, elite = rec.elite }
			end
		end
		i = hasta
		if i >= #lista then raro = t return true end
		return false
	end
end

function I.PrepararRaros(fn)
	if listos.raros then return K.Llamar(fn, true) end
	if not M.CodexListo() then return K.Llamar(fn, false) end
	if M.Corriendo("raros") then
		if fn then M.Tarea("raros", nil, fn) end
		return
	end
	M.Tarea("raros", pasoRaros(), function(ok)
		listos.raros = ok
		if M.alIndice then K.Llamar(M.alIndice, "raros") end
		if fn then K.Llamar(fn, ok) end
	end)
end

function I.Raro(kind, id) return raro[kind .. ":" .. tostring(id)] end
function I.ZonaRaro(kind, id) local r = raro[kind .. ":" .. tostring(id)] return r and r.zona end

-- Los raros y tesoros de una zona: { { kind, id }, ... }
function I.RarosDeZona(zona)
	local out = {}
	for clave, r in pairs(raro) do
		if r.zona == zona then
			local kind, id = clave:match("^(%a+):(%d+)$")
			out[#out + 1] = { kind = kind, id = tonumber(id), nivel = r.nivel }
		end
	end
	sort(out, function(a, b)
		if a.kind ~= b.kind then return a.kind == "rare" end
		return (a.nivel or 0) < (b.nivel or 0)
	end)
	return out
end

---------------------------------------------------------------------------
-- Servicios: los PNJ con oficio, por zona
---------------------------------------------------------------------------
local servicios = {} -- zona -> { [rol] = { npc, ... } }
local SERVICIOS = { "flightmaster", "innkeeper", "banker", "auctioneer", "repair", "stablemaster", "battlemaster", "spirithealer", "weapon", "trainer" }

function I.ServiciosListos() return listos.servicios end

local function pasoServicios()
	local C = M.CodexListo()
	local trabajo = {}
	if C then
		for _, rol in ipairs(SERVICIOS) do
			for _, id in ipairs(C.WithRole(rol) or VACIA) do trabajo[#trabajo + 1] = { rol, id } end
		end
	end
	local i = 0
	local t = {}
	return function()
		if not C then return true end
		local hasta = min(#trabajo, i + 120)
		for j = i + 1, hasta do
			local rol, id = trabajo[j][1], trabajo[j][2]
			local npc = C.Npc(id)
			if npc then
				local vistos = {}
				for _, s in ipairs(npc.spawns or VACIA) do
					if s.map and not vistos[s.map] then
						vistos[s.map] = true
						local z = t[s.map]
						if not z then z = {} t[s.map] = z end
						agregar(z, rol, id)
					end
				end
			end
		end
		i = hasta
		if i >= #trabajo then servicios = t return true end
		return false
	end
end

function I.PrepararServicios(fn)
	if listos.servicios then return K.Llamar(fn, true) end
	if not M.CodexListo() then return K.Llamar(fn, false) end
	if M.Corriendo("servicios") then
		if fn then M.Tarea("servicios", nil, fn) end
		return
	end
	M.Tarea("servicios", pasoServicios(), function(ok)
		listos.servicios = ok
		if M.alIndice then K.Llamar(M.alIndice, "servicios") end
		if fn then K.Llamar(fn, ok) end
	end)
end

function I.Servicios(zona) return servicios[zona] end
I.SERVICIOS = SERVICIOS

-- Las mazmorras y bandas cuya entrada está en esta zona.
function I.MazmorrasDeZona(zona)
	local C = M.CodexListo()
	local out = {}
	if not C then return out end
	C.Each("instance", function(clave)
		local inst = C.Instance(clave)
		if inst and inst.entrance and inst.entrance.map == zona then out[#out + 1] = inst end
	end)
	sort(out, function(a, b) return ((a.levels or VACIA)[1] or 0) < ((b.levels or VACIA)[1] or 0) end)
	return out
end
