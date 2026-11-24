-- Alfa - Comercio: las recetas que te faltan cerca de ti (toxic3000 / La Jauría). GPL-3.0. 1.3.8.
--
-- Para un oficio: las recetas que se compran a un vendedor y que aún no
-- tienes, las de tu zona primero y luego las más cercanas de tu continente,
-- con su vendedor, dónde está y si ya te alcanza la habilidad. Todo sale del
-- Codex del motor (las recetas traen su oficio, la habilidad que piden, el
-- hechizo que enseñan y quién las vende; los PNJ, su facción y dónde están).
-- Lo de entrenador (lo que enseña tu instructor) lo dice la guía: aquí va su
-- botón «Tu instructor más cercano».
--
-- Nada pesado de golpe: el índice (oficio -> recetas de vendedor) se arma una
-- vez por sesión, en una tarea que cede cada tanto (M.Tarea, nunca en
-- combate), y cada consulta solo mira las de un oficio.
-- «Ya la tienes»: las recetas que guardó Recetas.lua al abrir tu oficio
-- (por el hechizo que enseña) o, si el juego lo sabe, IsPlayerSpell.
--
--   Rz.Listo() -> bool                     ¿ya está el índice?
--   Rz.Preparar(alTerminar)                arma el índice (una vez; carga el Codex fuera de combate)
--   Rz.Buscar(linea, rank) -> { { id, nombre, req, puede, vendedor, map, x, y, f, zona, aqui, dist, limitada }, ... }, motivo
--   Rz.Ir(x) -> bool                       la flecha al vendedor (tu clic)

local _, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L

local type, pairs, ipairs, tonumber, pcall, format, sqrt, sort = type, pairs, ipairs, tonumber, pcall, string.format, math.sqrt, table.sort

local Rz = {}
M.RecetasZona = Rz

Rz.MAX = 8          -- recetas a la vista por oficio
Rz.PRONTO = 25      -- puntos de habilidad: «pronto la puedes aprender»

local indice        -- skillLine -> { { id, req, spell, vendedores = { npc, ... }, limitada }, ... }
local preparando = false
local esperan = {}
local npcs = {}     -- npc -> { nombre, faccion, spawns } | false

local function secreto(v) return type(v) ~= "nil" and issecretvalue ~= nil and issecretvalue(v) and true or false end

local function codex(cargar)
	return M.Lista and M.Lista.Codex and M.Lista.Codex(cargar) or nil
end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

function Rz.Listo() return indice ~= nil end

local function avisar()
	local lista = esperan
	esperan = {}
	for _, fn in ipairs(lista) do pcall(fn) end
end

local function armar(C)
	local ids = {}
	pcall(C.Each, "recipe", function(id, _, _, status)
		if status ~= "retired" and status ~= "nosource" and type(id) == "number" then ids[#ids + 1] = id end
	end)
	local t = {}
	for i, id in ipairs(ids) do
		local ok, rec = pcall(C.Item, id)
		if ok and type(rec) == "table" and type(rec.reqSkill) == "number" then
			local vend, limitada = nil, false
			for _, s in ipairs(rec.sources or {}) do
				if s.type == "vendor" and type(s.npc) == "number" then
					vend = vend or {}
					vend[#vend + 1] = s.npc
					if s.limited then limitada = true end
				end
			end
			if vend then
				local lista = t[rec.reqSkill]
				if not lista then
					lista = {}
					t[rec.reqSkill] = lista
				end
				lista[#lista + 1] = { id = id, req = tonumber(rec.reqSkillRank) or 1, spell = rec.spell, vendedores = vend, limitada = limitada }
			end
		end
		if i % 25 == 0 then M.Ceder() end
	end
	return t
end

-- Arma el índice (una vez por sesión). alTerminar corre al tenerlo.
function Rz.Preparar(alTerminar)
	if indice then
		if alTerminar then pcall(alTerminar) end
		return true
	end
	if alTerminar then esperan[#esperan + 1] = alTerminar end
	if preparando then return false end
	if enCombate() then return false end
	local C = codex(true)
	if not C or type(C.Each) ~= "function" or type(C.Item) ~= "function" then return false end
	preparando = true
	local puesta = M.Tarea("recetasZona", function()
		-- Sin pcall alrededor: M.Ceder no puede ceder a través de él (un error
		-- lo atrapa M.Tarea y llega a alFallar).
		indice = armar(C) or {}
		preparando = false
		avisar()
	end, function()
		indice, preparando = {}, false
		avisar()
	end)
	if not puesta then preparando = false end
	return false
end

-- Para las pruebas.
function Rz.Olvidar() indice, preparando, npcs = nil, false, {} end

---------------------------------------------------------------------------
-- Buscar
---------------------------------------------------------------------------

local FACCION = { Alliance = "A", Horde = "H" }

local function miFaccion()
	local f = UnitFactionGroup and UnitFactionGroup("player")
	if secreto(f) then return nil end
	return FACCION[f]
end

local function amigo(faccion, yo)
	return faccion == nil or faccion == "" or faccion == "AH" or (yo ~= nil and faccion:find(yo, 1, true) ~= nil)
end

local function npc(id)
	local hit = npcs[id]
	if hit ~= nil then return hit or nil end
	local C = codex(false)
	local ok, r = false, nil
	if C and C.Npc then ok, r = pcall(C.Npc, id) end
	if not ok or type(r) ~= "table" or r.instance then
		npcs[id] = false
		return nil
	end
	local x = { nombre = r.name, faccion = r.faction, spawns = r.spawns or {} }
	npcs[id] = x
	return x
end

local function compat() return A.Compat end

local function mapaActual()
	local C = C_Map
	if not (C and C.GetBestMapForUnit) then return nil end
	local ok, m = pcall(C.GetBestMapForUnit, "player")
	if not ok or secreto(m) then return nil end
	return tonumber(m)
end

local function aqui()
	local C = compat()
	if not (C and C.GetPlayerWorldPosition) then return nil end
	local ok, c, x, y = pcall(C.GetPlayerWorldPosition)
	if ok and c and type(x) == "number" and type(y) == "number" then return c, x, y end
	return nil
end

local function mundo(s)
	local C = compat()
	if not (C and C.MapToWorld) then return nil end
	local ok, c, x, y = pcall(C.MapToWorld, s.map, s.x, s.y, s.f)
	if ok and c and type(x) == "number" and type(y) == "number" then return c, x, y end
	return nil
end

local function nombreMapa(map)
	local C = compat()
	if C and C.GetMapName then
		local ok, n = pcall(C.GetMapName, map)
		if ok and type(n) == "string" and n ~= "" then return n end
	end
	return nil
end

-- ¿Ya la tienes? (las recetas de este personaje que vio Recetas.lua, o el juego)
local function conocidas()
	local por = {}
	if not M.TodasLasRecetas then return por end
	local ok, todas = pcall(M.TodasLasRecetas)
	if not ok or type(todas) ~= "table" then return por end
	for _, e in ipairs(todas) do
		if e.propio and e.id then por[tonumber(e.id) or e.id] = true end
	end
	return por
end

local function laTienes(spell, por)
	if type(spell) ~= "number" then return false end
	if por[spell] then return true end
	local C = compat()
	local f = (C and C.IsPlayerSpell) or rawget(_G, "IsPlayerSpell")
	if type(f) == "function" then
		local ok, si = pcall(f, spell)
		if ok and si == true then return true end
	end
	return false
end

-- -> lista, motivo ("cargando" | "combate" | "codex" | nil)
function Rz.Buscar(linea, rank)
	linea = tonumber(linea)
	if not indice then
		if enCombate() then return {}, "combate" end
		Rz.Preparar()
		return {}, indice and nil or (codex(false) and "cargando" or "codex")
	end
	local lista = linea and indice[linea]
	if not lista then return {}, nil end
	rank = tonumber(rank) or 0
	local yo = miFaccion()
	local mapa = mapaActual()
	local c0, x0, y0 = aqui()
	local por = conocidas()
	local out = {}
	for _, r in ipairs(lista) do
		if r.req <= rank + Rz.PRONTO and not laTienes(r.spell, por) then
			-- El vendedor más cercano de los que te venden (de tu facción).
			local mejor
			for _, nid in ipairs(r.vendedores) do
				local p = npc(nid)
				if p and amigo(p.faccion, yo) then
					for _, s in ipairs(p.spawns) do
						if type(s.map) == "number" and type(s.x) == "number" and type(s.y) == "number" then
							local c, wx, wy = mundo(s)
							local dist
							if c and c0 and c == c0 then dist = sqrt((wx - x0) ^ 2 + (wy - y0) ^ 2) end
							local esta = mapa ~= nil and s.map == mapa
							local cand = { npc = nid, nombre = p.nombre, map = s.map, x = s.x, y = s.y, f = s.f, aqui = esta, dist = dist }
							if not mejor or (cand.aqui and not mejor.aqui)
								or (cand.aqui == mejor.aqui and (cand.dist or 1e12) < (mejor.dist or 1e12)) then
								mejor = cand
							end
						end
					end
				end
			end
			-- Solo lo de tu zona o de tu continente.
			if mejor and (mejor.aqui or mejor.dist) then
				out[#out + 1] = {
					id = r.id, nombre = M.NombreObjeto(r.id), req = r.req, puede = r.req <= rank,
					vendedor = type(mejor.nombre) == "string" and mejor.nombre or "?", npc = mejor.npc,
					map = mejor.map, x = mejor.x, y = mejor.y, f = mejor.f,
					zona = nombreMapa(mejor.map), aqui = mejor.aqui, dist = mejor.dist, limitada = r.limitada,
				}
			end
		end
	end
	sort(out, function(a, b)
		if a.aqui ~= b.aqui then return a.aqui end
		if a.puede ~= b.puede then return a.puede end
		local da, db = a.dist or 1e12, b.dist or 1e12
		if da ~= db then return da < db end
		return a.req < b.req
	end)
	while #out > Rz.MAX do out[#out] = nil end
	return out, nil
end

-- La flecha al vendedor (tu clic).
function Rz.Ir(x)
	local Nav = A.Nav
	if type(x) ~= "table" or not (Nav and Nav.SetTarget) then return false end
	local ok, si = pcall(Nav.SetTarget, x.map, x.x, x.y, format(L["%s (recetas)"], x.vendedor or "?"), x.f)
	if ok and si ~= false then
		if N.EmpezarRuta then pcall(N.EmpezarRuta) end
		return true
	end
	N.Imprimir(L["No pude buscar el lugar más cercano. Prueba de nuevo en un momento; si sigue, /alfa diagnostico lo revisa."])
	return false
end

-- Al terminar el combate, lo que se quedó esperando el índice.
A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if not indice and #esperan > 0 then Rz.Preparar() end
end)
