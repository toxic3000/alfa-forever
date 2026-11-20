-- Alfa - Rutas: lo que se sabe sin el Codex (toxic3000 / La Jauría). GPL-3.0.
-- 1.3.2
--
-- El Codex (~7 MB) no se carga al entrar. La base de misiones del motor
-- (A.QuestDB, Alfa_QuestDB) sí suele estar: la cargan los tooltips de misión
-- y las marcas del mapa. Con ella, lo que necesita saber «dónde» funciona
-- desde el principio:
--   * a quién se entrega una misión y dónde está (la piedra de hogar a
--     tiempo, Hogar.lua, con Vuelta.Listas(true));
--   * a qué enemigos pide matar o de quién sale lo que pide, y dónde andan
--     («Sube al nivel N»: dónde rinde más, Nivel.lua).
-- Aquí nada carga nada: sin la base, todo da nil.
--
--   Ligero.Listo() -> bool
--   Ligero.Entrega(qid, desde) -> punto { map, x, y, f, kind, id, name } | nil
--   Ligero.Enemigos(qid) -> { { npc, nombre, spawns = { { map, x, y, f } } }, ... }
--   Ligero.Nivel(qid) -> nivel de la misión | nil

local ADDON, M = ...
local A = M.A
local Lg = {}
M.Ligero = Lg

local type, ipairs, tonumber, pcall = type, ipairs, tonumber, pcall
local sqrt = math.sqrt

local MAX_FUENTES = 3 -- de quién sale un objeto: los que más lo sueltan

local function QD() return M.Motor("QuestDB") end
local function CP() return M.Motor("Compat") end

function Lg.Listo()
	local Q = QD()
	return Q and Q.IsLoaded and Q.IsLoaded() and Q.QuestRecord and Q.F and Q.EachSpawn and true or false
end

local function registro(qid)
	if not Lg.Listo() then return nil end
	local Q = QD()
	local ok, r = pcall(Q.QuestRecord, tonumber(qid))
	return ok and type(r) == "table" and r or nil, Q
end

local function mundo(map, x, y, f)
	local Cp = CP()
	if not (Cp and Cp.MapToWorld and map and x and y) then return nil end
	local ok, c, wx, wy = pcall(Cp.MapToWorld, map, x, y, f)
	if ok and c and type(wx) == "number" and type(wy) == "number" then return c, wx, wy end
	return nil
end

-- Las referencias de un campo "una o una lista" (PNJ > 0, objeto < 0).
local function refs(Q, v)
	local out = {}
	for _, r in Q.Each(v) do if type(r) == "number" then out[#out + 1] = r end end
	return out
end

-- La aparición más cercana de una referencia a `desde` (o la primera).
local function cercana(Q, ref, desde)
	local dc, dx, dy
	if desde then dc, dx, dy = mundo(desde.map, desde.x, desde.y, desde.f) end
	local mejor, md
	pcall(Q.EachSpawn, ref, function(_, _, map, f, x, y)
		if not (map and x and y) then return end
		local d = 1e9
		if dc then
			local c, wx, wy = mundo(map, x, y, f)
			if c == dc then d = sqrt((wx - dx) ^ 2 + (wy - dy) ^ 2) elseif c then d = 1e8 end
		end
		if not md or d < md then mejor, md = { map = map, x = x, y = y, f = f }, d end
	end)
	return mejor, md
end

function Lg.Entrega(qid, desde)
	local r, Q = registro(qid)
	if not r then return nil end
	local mejor, md
	for _, ref in ipairs(refs(Q, r[Q.F.FINISH])) do
		local p, d = cercana(Q, ref, desde)
		if p and (not md or d < md) then
			mejor, md = p, d
			p.kind = ref > 0 and "npc" or "object"
			p.id = ref > 0 and ref or -ref
			local okN, nombre = pcall(Q.EntityName, ref)
			p.name = okN and type(nombre) == "string" and nombre or nil
		end
	end
	return mejor
end

function Lg.Nivel(qid)
	local r, Q = registro(qid)
	local v = r and r[Q.F.LEVEL]
	return type(v) == "number" and v > 0 and v or nil
end

local function spawns(Q, ref)
	local out = {}
	pcall(Q.EachSpawn, ref, function(_, _, map, f, x, y)
		if map and x and y then out[#out + 1] = { map = map, x = x, y = y, f = f } end
	end)
	return out
end

local function nombre(Q, ref)
	local ok, n = pcall(Q.EntityName, ref)
	return ok and type(n) == "string" and n or nil
end

function Lg.Enemigos(qid)
	local out = {}
	local r, Q = registro(qid)
	local obj = r and r[Q.F.OBJ]
	if type(obj) ~= "table" then return out end
	local vistos = {}
	local function sumar(npc)
		if type(npc) ~= "number" or npc <= 0 or vistos[npc] then return end
		vistos[npc] = true
		local s = spawns(Q, npc)
		if #s > 0 then out[#out + 1] = { npc = npc, nombre = nombre(Q, npc), spawns = s } end
	end
	for i = 1, #obj, 3 do
		local tipo, id = obj[i], obj[i + 1]
		if tipo == 1 then
			sumar(id)
		elseif tipo == 2 and Q.GetItemDroppers then
			local ok, d = pcall(Q.GetItemDroppers, id)
			for k = 1, ok and type(d) == "table" and math.min(#d, MAX_FUENTES) or 0 do sumar(d[k].id) end
		end
	end
	return out
end
