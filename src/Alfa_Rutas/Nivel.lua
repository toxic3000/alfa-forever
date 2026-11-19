-- Alfa - Rutas: pasos de nivel claros (toxic3000 / La Jauría). GPL-3.0.
-- 1.2.9
--
-- Cuando tu paso de ahora es «Sube al nivel N» (la meta `level` del motor),
-- el aviso del rastreador lo dice claro: cuánta experiencia te falta, una
-- barrita con tu nivel de ahora y «dónde rinde más»: los enemigos cerca de ti,
-- de tu nivel, que además cuentan para una misión de tu registro (matarlos o
-- lo que sueltan). Con «Llévame» la flecha va a su lugar más cercano.
--
-- Los datos son los del motor y solo se leen: el Codex (misiones de tu
-- registro, sus objetivos, quién suelta cada objeto, nivel y lugares de cada
-- enemigo), Levels.MobXP (la experiencia por enemigo) y Compat.MapToWorld (las
-- yardas). Nada en combate ni con el Codex sin cargar (la última respuesta se
-- guarda un rato). Ajuste rutas.nivelClaro.
--
--   Nivel.Meta(v) -> gv | nil              la meta de nivel abierta del paso v
--   Nivel.Falta() -> falta, xp, xpMax, nivel   experiencia hasta la meta de ahora
--   Nivel.DondeRinde(forzar) -> { npc, nombre, nivel, xp, mision, titulo, p, yardas } | nil
--   Nivel.Aviso(v, live) -> el aviso del rastreador | nil

local ADDON, M = ...
local A, L = M.A, M.L
local Nv = {}
M.Nivel = Nv

A.RegisterDefaults(M.ID, { nivelClaro = true })

local type, ipairs, pairs, tonumber, pcall = type, ipairs, pairs, tonumber, pcall
local sqrt, floor, min, max, format = math.sqrt, math.floor, math.min, math.max, string.format

local ABAJO, ARRIBA = 4, 2  -- niveles: de tu nivel - 4 a tu nivel + 2 (los grises casi no dan)
local MAX_MISIONES = 25
local MAX_ENEMIGOS = 3      -- los que más sueltan un objeto
local MAX_LUGARES = 60      -- lugares de cada enemigo que se miran
local LEJOS = 1500          -- yardas: más lejos ya no es «cerca de ti»
local VIGENCIA = 20         -- segundos que vale la respuesta

local function CX() return M.Motor("Codex") end
local function CP() return M.Motor("Compat") end
local function enCombate() return InCombatLockdown and InCombatLockdown() or false end
local function encendido() return A.Get(M.ID .. ".nivelClaro") ~= false end

local function jugador()
	local I = M.Indice
	local p = I and I.Jugador and I.Jugador() or {}
	return M.num(p.level, 1), M.num(p.xp, 0), M.num(p.xpMax, 0)
end

-- La meta de nivel abierta del paso (su vista).
function Nv.Meta(v)
	if type(v) ~= "table" or type(v.goals) ~= "table" then return nil end
	for _, gv in ipairs(v.goals) do
		if type(gv) == "table" and gv.t == "level" and (gv.status == "active" or gv.status == "pending") then return gv end
	end
	return nil
end

-- El nivel de la meta: el del paso en la guía (la vista no lo trae suelto).
local function nivelDe(v, gv)
	local e = A.Engine
	local g = e and e.GetGuide and e.GetGuide()
	local paso = type(g) == "table" and type(g.steps) == "table" and g.steps[v.index]
	for _, goal in ipairs(paso and paso.goals or {}) do
		if goal.t == "level" and tonumber(goal.level) then return tonumber(goal.level) end
	end
	local n = tonumber(type(gv.subject) == "string" and gv.subject:match("^(%d+)"))
	return n
end

function Nv.Falta(v)
	local gv = Nv.Meta(v)
	if not gv then return nil end
	local nivel, xp, xpMax = jugador()
	return M.num(gv.xpLeft, nil), xp, xpMax, nivelDe(v, gv) or nivel + 1
end

---------------------------------------------------------------------------
-- Dónde rinde más
---------------------------------------------------------------------------

local function mundo(p)
	local Cp = CP()
	if not (p and p.map and p.x and p.y and Cp and Cp.MapToWorld) then return nil end
	local ok, c, wx, wy = pcall(Cp.MapToWorld, p.map, p.x, p.y, p.f)
	if ok and c and type(wx) == "number" and type(wy) == "number" then return c, wx, wy end
	return nil
end

-- Los enemigos que cuentan para cada misión de tu registro: { [npc] = qid }.
local function enemigosDeMisiones(C, Cp)
	local out = {}
	local n = 0
	for _, qid in ipairs(Cp.GetLogQuests and Cp.GetLogQuests() or {}) do
		n = n + 1
		if n > MAX_MISIONES then break end
		local lista = not (Cp.IsQuestReadyForTurnIn and Cp.IsQuestReadyForTurnIn(qid))
		local q = lista and C.Quest and C.Quest(qid)
		for _, o in ipairs(type(q) == "table" and q.objectives or {}) do
			if o.type == "kill" and o.id then
				out[o.id] = out[o.id] or qid
			elseif o.type == "item" and o.id and C.Item then
				local it = C.Item(o.id)
				local fuentes = {}
				for _, s in ipairs(type(it) == "table" and it.sources or {}) do
					if s.type == "drop" and s.npc and not s.instance then fuentes[#fuentes + 1] = s end
				end
				table.sort(fuentes, function(a, b) return M.num(a.chance, 0) > M.num(b.chance, 0) end)
				for i = 1, min(#fuentes, MAX_ENEMIGOS) do out[fuentes[i].npc] = out[fuentes[i].npc] or qid end
			end
		end
	end
	return out
end

local cache, cacheEn = nil, -1e9

function Nv.Olvidar() cache, cacheEn = nil, -1e9 end

function Nv.DondeRinde(forzar)
	local ahora = GetTime and GetTime() or 0
	if not forzar and ahora - cacheEn < VIGENCIA then return cache or nil end
	if enCombate() then return cache or nil end
	local C, Cp = CX(), CP()
	if not (C and Cp and C.IsLoaded and C.IsLoaded() and C.Npc and C.Quest) then return nil end
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	local yc, ywx, ywy = mundo(desde)
	if not yc then return nil end
	local nivel = jugador()
	local Lv = A.Levels
	local mejor, puntos = nil, -1
	for npc, qid in pairs(enemigosDeMisiones(C, Cp)) do
		local r = C.Npc(npc)
		local lvl = type(r) == "table" and M.num(r.level, nil)
		if lvl and not r.elite and not r.rare and not r.boss and not r.instance
			and lvl >= nivel - ABAJO and lvl <= nivel + ARRIBA then
			local xp = Lv and Lv.MobXP and select(2, pcall(Lv.MobXP, nivel, lvl, false))
			xp = M.num(xp, 0)
			if xp > 0 then
				local cerca, lugar = nil, nil
				local spawns = r.spawns or {}
				for i = 1, min(#spawns, MAX_LUGARES) do
					local s = spawns[i]
					local c, wx, wy = mundo(s)
					if c == yc then
						local dx, dy = wx - ywx, wy - ywy
						local d = sqrt(dx * dx + dy * dy)
						if not cerca or d < cerca then cerca, lugar = d, s end
					end
				end
				if cerca and cerca <= LEJOS then
					-- La experiencia por enemigo pesa más que la distancia; lo de
					-- al lado gana entre parecidos.
					local pts = xp / (1 + cerca / 400)
					if pts > puntos then
						puntos = pts
						mejor = { npc = npc, nombre = r.name or M.TituloMision(qid), nivel = lvl, xp = xp, mision = qid,
							titulo = M.TituloMision(qid), p = { map = lugar.map, x = lugar.x, y = lugar.y, f = lugar.f, z = lugar.z },
							yardas = floor(cerca + 0.5) }
					end
				end
			end
		end
	end
	cache, cacheEn = mejor or false, ahora
	return mejor
end

-- La flecha al lugar más cercano de ese enemigo.
function Nv.Ir(d)
	local Nav = A.Nav
	if not (d and d.p and Nav and type(Nav.SetTarget) == "function") then return false end
	local ok, t = pcall(Nav.SetTarget, d.p.map, d.p.x, d.p.y, d.nombre, d.p.f, nil, d.p.z)
	if not (ok and t) then return false end
	if type(Nav.StartTrip) == "function" then pcall(Nav.StartTrip, t, d.nombre, L["Donde más rinde"]) end
	M.Empezar()
	return true
end

---------------------------------------------------------------------------
-- El aviso del rastreador
---------------------------------------------------------------------------

function Nv.Aviso(v, live)
	if not encendido() or not (v and live and v.index == live) then return nil end
	local falta, xp, xpMax, meta = Nv.Falta(v)
	if not falta then return nil end
	local d = {
		tono = "exito", icono = "ic-nivel",
		titulo = format(L["Te faltan %s de experiencia para el nivel %d"], M.Miles(falta), meta),
		barra = xpMax > 0 and min(1, max(0, xp / xpMax)) or nil,
	}
	local r = Nv.DondeRinde()
	if r then
		d.texto = format(L["Donde más rinde: %s (nivel %d), y cuenta para %s."], r.nombre or "", r.nivel, M.Citar(r.titulo or ""))
		d.uno = { L["Llévame"], function() Nv.Ir(r) end }
	else
		d.texto = L["Haz misiones de tu registro o caza enemigos de tu nivel (los grises no dan nada)."]
	end
	return d
end

A.RegisterEvent("QUEST_ACCEPTED", function() cacheEn = -1e9 end)
A.RegisterEvent("QUEST_REMOVED", function() cacheEn = -1e9 end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() cacheEn = -1e9 end)
A.RegisterEvent("PLAYER_LEVEL_UP", function() cacheEn = -1e9 end)
