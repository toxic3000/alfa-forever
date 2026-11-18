-- Alfa - Builds: equipo meta por ranura (toxic3000 / La Jauría). GPL-3.0.
--
-- Recorre los objetos del Codex del motor (Alfa_Codex, se carga a pedido y
-- solo fuera de combate), se queda con los que tu clase puede usar cerca de
-- tu nivel, los puntúa con los pesos del build (Pesos.lua, Gear.ScoreWith) y
-- guarda los mejores de cada ranura. El trabajo se reparte en pedazos por
-- cuadro para no trabar el juego. "Cómo conseguirlo" usa el buscador del
-- motor (Lookup.Guide / Lookup.Show, el mismo "Guíame").
--
--   E.Buscar(build, alListo)   alListo(resultado | nil, razon)
--   E.Resultado(build) -> resultado en caché (mismo build y nivel) | nil
--   E.Guiar(itemID)            abre la guía para conseguirlo
--   E.Ocupado() -> bool, avance (0..1)
--
-- resultado = { grupos = { { clave, nombre, slots, items = { { id, puntos,
--   req, calidad, mejora (porcentaje sobre lo que llevas | nil) } } } }, nivel }

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local E = {}
M.Equipo = E

local POR_GRUPO = 4
local POR_CUADRO = 300
local ATRAS, ADELANTE = 6, 3 -- niveles: de cuánto antes y cuánto después

-- Grupos en el orden de la hoja de personaje. inv: tipos de inventario del
-- motor (Gear.EQUIP_LOC); slots: ranuras equipadas con las que se compara.
local GRUPOS = {
	{ clave = "cabeza", slot = 1, inv = { 1 }, slots = { 1 } },
	{ clave = "cuello", slot = 2, inv = { 2 }, slots = { 2 } },
	{ clave = "hombros", slot = 3, inv = { 3 }, slots = { 3 } },
	{ clave = "espalda", slot = 15, inv = { 16 }, slots = { 15 } },
	{ clave = "pecho", slot = 5, inv = { 5, 20 }, slots = { 5 } },
	{ clave = "munecas", slot = 9, inv = { 9 }, slots = { 9 } },
	{ clave = "manos", slot = 10, inv = { 10 }, slots = { 10 } },
	{ clave = "cintura", slot = 6, inv = { 6 }, slots = { 6 } },
	{ clave = "piernas", slot = 7, inv = { 7 }, slots = { 7 } },
	{ clave = "pies", slot = 8, inv = { 8 }, slots = { 8 } },
	{ clave = "anillo", slot = 11, inv = { 11 }, slots = { 11, 12 } },
	{ clave = "abalorio", slot = 13, inv = { 12 }, slots = { 13, 14 } },
	{ clave = "principal", slot = 16, inv = { 13, 21, 17 }, slots = { 16 } },
	{ clave = "secundaria", slot = 17, inv = { 13, 22, 14, 23 }, slots = { 17 } },
	{ clave = "distancia", slot = 18, inv = { 15, 25, 26, 28 }, slots = { 18 } },
}
E.GRUPOS = GRUPOS

local NOMBRE = {
	cabeza = L["Cabeza"], cuello = L["Cuello"], hombros = L["Hombros"], espalda = L["Espalda"], pecho = L["Pecho"],
	munecas = L["Muñecas"], manos = L["Manos"], cintura = L["Cintura"], piernas = L["Piernas"], pies = L["Pies"],
	anillo = L["Anillos"], abalorio = L["Abalorios"], principal = L["Mano principal"], secundaria = L["Mano secundaria"],
	distancia = L["A distancia"],
}

function E.NombreGrupo(g)
	local G = A.Gear
	local propio = G and G.SlotName and G.SlotName(g.slot)
	if g.clave == "anillo" or g.clave == "abalorio" then propio = nil end
	return propio or NOMBRE[g.clave] or g.clave
end

-- Qué tipos de arma valen según el build: "2h" solo dos manos en la
-- principal y nada en la secundaria; "dual" dos de una mano; "escudo" una mano
-- y escudo; sin dato, cualquiera.
local ARMAS = {
	["2h"] = { principal = { [17] = true }, secundaria = {} },
	dual = { principal = { [13] = true, [21] = true }, secundaria = { [13] = true, [22] = true } },
	escudo = { principal = { [13] = true, [21] = true }, secundaria = { [14] = true, [23] = true } },
}

local function permitido(b, g, inv)
	local a = b.armas and ARMAS[b.armas]
	if not a or not a[g.clave] then return true end
	return a[g.clave][inv] == true
end

local grupoDeInv = {}
for _, g in ipairs(GRUPOS) do
	for _, inv in ipairs(g.inv) do
		grupoDeInv[inv] = grupoDeInv[inv] or {}
		table.insert(grupoDeInv[inv], g)
	end
end

local cache = {} -- build id -> resultado
local trabajo -- { build, ids, i, mejores, w, alListo, nivel }

function E.Ocupado()
	if not trabajo then return false, 0 end
	return true, (#trabajo.ids > 0) and (trabajo.i / #trabajo.ids) or 0
end

function E.Resultado(b)
	local r = b and cache[b.id]
	local nivel = UnitLevel("player")
	if r and r.nivel == nivel then return r end
	return nil
end

function E.Olvidar() for k in pairs(cache) do cache[k] = nil end end

local function puntuar(info, w, offhand)
	local G = A.Gear
	local ok, s = pcall(G.ScoreWith, info, w, offhand)
	return ok and type(s) == "number" and s or nil
end

-- Lo que llevas puesto, puntuado con los pesos del build: por ranura.
local function puesto(w)
	local G = A.Gear
	local out = {}
	for slot = 1, 18 do
		local link = A.Compat.Readable(GetInventoryItemLink("player", slot))
		local info = link and G.GetItemInfo(link)
		out[slot] = info and puntuar(info, w, slot == 17) or 0
	end
	return out
end

local function insertar(lista, e)
	local pos = #lista + 1
	for i, x in ipairs(lista) do
		if e.puntos > x.puntos then pos = i break end
	end
	if pos <= POR_GRUPO then
		table.insert(lista, pos, e)
		if #lista > POR_GRUPO then lista[#lista] = nil end
	end
end

-- La mejora de cada objeto sobre lo que llevas puesto ahora.
function E.Mejoras(res, w)
	if not (res and w) then return end
	local eq = puesto(w)
	for _, gr in ipairs(res.grupos) do
		local base = math.huge
		for _, s in ipairs(gr.slots) do base = math.min(base, eq[s] or 0) end
		if base == math.huge then base = 0 end
		gr.actual = base
		for _, it in ipairs(gr.items) do
			it.mejora = base > 0 and (it.puntos - base) / base * 100 or nil
			it.vacio = base <= 0
		end
	end
	res.viejo = nil
end

local function terminar()
	local t = trabajo
	trabajo = nil
	local res = { grupos = {}, nivel = t.nivel, build = t.build.id }
	for _, g in ipairs(GRUPOS) do
		local items = t.mejores[g.clave] or {}
		if #items > 0 then
			res.grupos[#res.grupos + 1] = { clave = g.clave, nombre = E.NombreGrupo(g), items = items, slot = g.slot, slots = g.slots }
		end
	end
	E.Mejoras(res, t.w)
	cache[t.build.id] = res
	if t.alListo then t.alListo(res) end
end

local trozo

local function paso()
	local t = trabajo
	if not t then return end
	if InCombatLockdown() then
		-- En combate se espera: se sigue al salir.
		N.FueraDeCombate(function() A.After(0.2, paso) end)
		return
	end
	-- Un objeto raro de la base no deja la búsqueda trabada en "Buscando…"
	-- para siempre: se reporta y la página vuelve a ofrecer buscar.
	local ok, err = pcall(trozo, t)
	if not ok then
		if trabajo == t then trabajo = nil end
		if geterrorhandler then geterrorhandler()(err) end
		if t.alListo then pcall(t.alListo, nil, "codex") end
	end
end

trozo = function(t)
	local G, DB = A.Gear, A.ItemDB
	local fin = math.min(#t.ids, t.i + POR_CUADRO)
	for k = t.i + 1, fin do
		local id = t.ids[k]
		local rec = DB.Get(id)
		if rec and grupoDeInv[rec.inv] then
			local req = rec.req or 0
			local cerca
			if req > 0 then
				cerca = req <= t.nivel + ADELANTE and req >= t.nivel - ATRAS
			else
				cerca = (rec.ilvl or 0) <= t.nivel + ADELANTE + 2 and (rec.ilvl or 0) >= t.nivel - ATRAS
			end
			if cerca then
				local info = G.GetItemInfo(id)
				if info then
					local ok, usable, _, minLevel = pcall(G.Usability, info)
					if ok and usable and (minLevel or 0) <= t.nivel + ADELANTE then
						for _, g in ipairs(grupoDeInv[rec.inv]) do
							if permitido(t.build, g, rec.inv) then
								local s = puntuar(info, t.w, g.clave == "secundaria")
								if s and s > 0 then
									t.mejores[g.clave] = t.mejores[g.clave] or {}
									insertar(t.mejores[g.clave], { id = id, puntos = s, req = math.max(req, minLevel or 0), calidad = rec.quality })
								end
							end
						end
					end
				end
			end
		end
	end
	t.i = fin
	if t.alAvance then pcall(t.alAvance, t.i / math.max(1, #t.ids)) end
	if t.i >= #t.ids then
		terminar()
	else
		A.After(0, paso)
	end
end

-- -> true | false, razon ("combate" | "codex" | "pesos" | "ocupado")
function E.Buscar(b, alListo, alAvance)
	if trabajo then return false, "ocupado" end
	if InCombatLockdown() then return false, "combate" end
	local w = M.Pesos.Pesos(b)
	if not w then return false, "pesos" end
	local C, DB, G = A.Codex, A.ItemDB, A.Gear
	if not (C and C.Load and C.Each and DB and DB.Get and G and G.GetItemInfo and G.Usability and G.ScoreWith) then return false, "codex" end
	local ok = C.Load()
	if not ok then return false, "codex" end
	if DB.Load then DB.Load() end
	local ids = {}
	C.Each("item", function(id, _, calidad, estado)
		if type(id) == "number" and estado ~= "retired" and estado ~= "nosource" and (calidad or 0) >= 2 and (calidad or 0) <= 4 then
			ids[#ids + 1] = id
		end
	end)
	if #ids == 0 then return false, "codex" end
	trabajo = { build = b, ids = ids, i = 0, mejores = {}, w = w, alListo = alListo, alAvance = alAvance,
		nivel = UnitLevel("player") or 1 }
	A.After(0, paso)
	return true
end

E.RAZONES = {
	combate = L["Estás en combate: busca el equipo al terminar la pelea."],
	codex = L["No se pudo abrir el Codex de Alfa (la base de objetos). Revisa que el addon Alfa Codex esté activado."],
	pesos = L["Esta clase no tiene pesos de estadísticas."],
	ocupado = L["Ya se está buscando, espera un momento."],
}

-- Nombre, color y de dónde sale.
function E.Nombre(id)
	local C = A.Codex
	local n = A.Compat.GetItemName(id) or (C and C.IsLoaded and C.IsLoaded() and C.Name("item", id))
		or (A.ItemDB and A.ItemDB.ItemName and A.ItemDB.ItemName(id))
	return n or ("#" .. tostring(id))
end

function E.Origen(id)
	local Lk = A.Lookup
	if not (Lk and Lk.Subtitle) then return nil end
	local ok, s = pcall(Lk.Subtitle, "item", id)
	return ok and s or nil
end

function E.Guiar(id)
	local Lk = A.Lookup
	if not Lk then return end
	local guia = Lk.Guide and Lk.Guide("item", id)
	if not guia and Lk.Show then Lk.Show(nil, "item", id) end
end

A.On("GEAR_UPDATED", function(que)
	if que == "level" or que == "equipment" then
		for k, r in pairs(cache) do
			if que == "level" then cache[k] = nil else r.viejo = true end
		end
	end
end)
