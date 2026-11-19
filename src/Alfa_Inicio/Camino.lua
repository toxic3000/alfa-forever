-- Alfa - Inicio: «Camino al 60» (toxic3000 / La Jauría). GPL-3.0. -- 1.2.9
--
-- Tu plan de punta a punta desde tu nivel hasta el 60: qué guías (y en qué
-- zonas) a qué niveles, las mazmorras en el camino (al nivel que mejor te
-- quedan), cuántas horas te faltan a tu ritmo de verdad y cuánto avanzas
-- cada día («Hoy avanzaste 1.4 niveles»).
--
-- Tu ritmo: la XP por hora de tus últimos días de juego (lo que anota este
-- archivo cada minuto que juegas); sin días todavía, el de esta sesión.
-- Por personaje, en N.DatosPersonaje("inicio").camino:
--   dias[aaaammdd] = { t, desde, hasta, xp, seg }   desde/hasta: tu nivel con su fracción
--   (los últimos DIAS días)
--
--   M.Camino.Resumen() -> { nivel, frac, faltan, xp, ritmo, horas, hoy, porDia, dias? } | nil (nivel máximo)
--   M.Camino.Tramos() -> { { desde, hasta, titulo, zona, id, mazmorras = { ... } }, ... }
--   M.Camino.Mazmorras() -> { { key, nombre, nivel, min, max }, ... }
--   M.Camino.Dias(n) -> { { t, niveles, seg, xp }, ... }   los últimos n días que jugaste, el más nuevo primero
--   M.Camino.Anotar()   un minuto más de juego (lo llama el temporizador)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local num, texto = M.num, M.texto

local type, ipairs, pairs, pcall, tonumber, tostring, format = type, ipairs, pairs, pcall, tonumber, tostring, string.format
local floor, max, min = math.floor, math.max, math.min

local Ca = {}
M.Camino = Ca

Ca.TOPE = 60
Ca.DIAS = 30        -- días que se guardan
Ca.RITMO_DIAS = 7   -- días con que se mide tu ritmo
Ca.RITMO_MIN = 1800 -- segundos de juego para confiar en él
Ca.CADA = 60

-- La XP para pasar de cada nivel al siguiente (la de Clásico).
Ca.XP = {
	400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, 8800, 10100, 11400, 12900, 14400, 16000, 17700,
	19400, 21300, 23200, 25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400, 50800, 54500,
	58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700, 95800, 101000, 106300, 111800, 117500, 123200,
	129100, 135100, 141200, 147500, 153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800,
}

local function db()
	local d = N.DatosPersonaje("inicio")
	if type(d.camino) ~= "table" then d.camino = {} end
	if type(d.camino.dias) ~= "table" then d.camino.dias = {} end
	return d.camino
end

local function nivelJugador() return num(UnitLevel and UnitLevel("player")) or 1 end

local function tope()
	local mx = num(GetMaxPlayerLevel and GetMaxPlayerLevel())
	return min(Ca.TOPE, mx or Ca.TOPE)
end

-- Tu nivel con su fracción: 23.42
local function nivelFrac()
	local lv = nivelJugador()
	local xp = num(UnitXP and UnitXP("player")) or 0
	local mx = num(UnitXPMax and UnitXPMax("player")) or 0
	if mx <= 0 then return lv end
	return lv + min(0.999, xp / mx)
end
Ca.NivelFrac = nivelFrac

local function clave(t) return date("%Y%m%d", t or time()) end

---------------------------------------------------------------------------
-- Lo que juegas cada día
---------------------------------------------------------------------------

local ultimo     -- time() de la última anotación
local xpPrevia   -- la XP de la sesión entonces

function Ca.Anotar()
	local S = M.Sesion
	if not (S and S.Empezada and S.Empezada()) then return end
	local c = db()
	local t = time()
	local k = clave(t)
	local d = c.dias[k]
	local nf = nivelFrac()
	if type(d) ~= "table" then
		d = { t = t, desde = nf, hasta = nf, xp = 0, seg = 0 }
		c.dias[k] = d
	end
	local a = S.Actual()
	local xp = num(a.xp) or 0
	if ultimo then
		d.seg = (tonumber(d.seg) or 0) + min(Ca.CADA * 2, max(0, t - ultimo))
		if xpPrevia and xp >= xpPrevia then d.xp = (tonumber(d.xp) or 0) + (xp - xpPrevia) end
	end
	ultimo, xpPrevia = t, xp
	if nf >= (tonumber(d.desde) or nf) then d.hasta = nf end
	-- Solo los últimos DIAS días.
	local n, viejo = 0, nil
	for kk in pairs(c.dias) do
		n = n + 1
		if not viejo or kk < viejo then viejo = kk end
	end
	if n > Ca.DIAS and viejo then c.dias[viejo] = nil end
end

-- Los últimos n días que jugaste, el más nuevo primero.
function Ca.Dias(n)
	local c = db()
	local claves = {}
	for k, d in pairs(c.dias) do
		if type(d) == "table" and (tonumber(d.seg) or 0) > 0 then claves[#claves + 1] = k end
	end
	table.sort(claves, function(a, b) return a > b end)
	local out = {}
	for i = 1, min(n or #claves, #claves) do
		local d = c.dias[claves[i]]
		out[i] = { t = tonumber(d.t) or 0, niveles = max(0, (tonumber(d.hasta) or 0) - (tonumber(d.desde) or 0)),
			seg = tonumber(d.seg) or 0, xp = tonumber(d.xp) or 0, hoy = claves[i] == clave() }
	end
	return out
end

-- Lo de hoy: niveles avanzados (con fracción).
function Ca.Hoy()
	local d = db().dias[clave()]
	if type(d) ~= "table" then return 0, 0 end
	return max(0, (tonumber(d.hasta) or 0) - (tonumber(d.desde) or 0)), tonumber(d.seg) or 0
end

-- Tu XP por hora: la de tus últimos días, o la de esta sesión.
function Ca.Ritmo()
	local xp, seg = 0, 0
	for _, d in ipairs(Ca.Dias(Ca.RITMO_DIAS)) do
		xp, seg = xp + d.xp, seg + d.seg
	end
	if seg >= Ca.RITMO_MIN and xp > 0 then return xp / seg * 3600, "dias", seg end
	local S = M.Sesion
	local e = S and S.Estado()
	if e and e.ritmo and e.ritmo > 0 then return e.ritmo, "sesion", seg end
	return nil, nil, seg
end

---------------------------------------------------------------------------
-- Cuánto falta
---------------------------------------------------------------------------

function Ca.XPFaltante()
	local lv = nivelJugador()
	local top = tope()
	if lv >= top then return 0 end
	local xp = num(UnitXP and UnitXP("player")) or 0
	local mx = num(UnitXPMax and UnitXPMax("player")) or Ca.XP[lv] or 0
	local falta = max(0, mx - xp)
	for l = lv + 1, top - 1 do falta = falta + (Ca.XP[l] or 0) end
	return falta
end

function Ca.Resumen()
	local lv = nivelJugador()
	local top = tope()
	if lv >= top then return nil end
	local nf = nivelFrac()
	local r = { nivel = lv, frac = nf, tope = top, faltan = top - nf, xp = Ca.XPFaltante() }
	local ritmo, fuente, jugado = Ca.Ritmo()
	r.ritmo, r.fuente = ritmo, fuente
	if ritmo and ritmo > 0 then r.horas = r.xp / ritmo end
	r.hoy, r.hoySeg = Ca.Hoy()
	-- Cuántas horas juegas al día (los días que juegas): para «en unos N días».
	local dias = Ca.Dias(Ca.RITMO_DIAS)
	if #dias >= 2 and (jugado or 0) > 0 then r.porDia = jugado / #dias / 3600 end
	if r.horas and r.porDia and r.porDia > 0 then r.dias = max(1, floor(r.horas / r.porDia + 0.5)) end
	return r
end

---------------------------------------------------------------------------
-- El camino: guías y mazmorras
---------------------------------------------------------------------------

local function jugador()
	local Cp = A.Compat
	if type(Cp) == "table" and type(Cp.GetPlayerInfo) == "function" then
		local ok, p = pcall(Cp.GetPlayerInfo)
		if ok and type(p) == "table" then return p end
	end
	return { level = nivelJugador() }
end

-- Las guías para subir de nivel que te tocan (de tu facción, raza y clase).
local function guias()
	local G = A.Guides
	if type(G) ~= "table" or type(G.List) ~= "function" then return {} end
	local ok, lista = pcall(G.List)
	if not ok or type(lista) ~= "table" then return {} end
	local p = jugador()
	local fuente = type(G.SuggestSource) == "function" and select(2, pcall(G.SuggestSource)) or nil
	local out, dePack = {}, {}
	for i, g in ipairs(lista) do
		if type(g) == "table" and (g.category == nil or g.category == "Leveling") and tonumber(g.minLevel) then
			local okM, sirve = true, true
			if type(G.GuideMatches) == "function" then okM, sirve = pcall(G.GuideMatches, g, p) end
			if okM and sirve then
				local e = { g = g, i = i, lo = tonumber(g.minLevel), hi = max(tonumber(g.minLevel), tonumber(g.maxLevel) or tonumber(g.minLevel)) }
				out[#out + 1] = e
				if fuente and g.pack == fuente then dePack[#dePack + 1] = e end
			end
		end
	end
	return #dePack > 0 and dePack or out
end

function Ca.Tramos()
	local lv, top = nivelJugador(), tope()
	local lista = guias()
	local tramos = {}
	local guard = 0
	while lv < top and guard < 40 do
		guard = guard + 1
		local mejor
		for _, e in ipairs(lista) do
			if e.lo <= lv and e.hi >= lv then
				-- La más justa a tu nivel: la que empieza más cerca, luego la más corta.
				if not mejor or e.lo > mejor.lo or (e.lo == mejor.lo and (e.hi - e.lo) < (mejor.hi - mejor.lo)) then mejor = e end
			end
		end
		if not mejor then
			-- Un hueco: la siguiente que empieza.
			for _, e in ipairs(lista) do
				if e.lo > lv and (not mejor or e.lo < mejor.lo) then mejor = e end
			end
			if not mejor then break end
		end
		local desde = max(lv, mejor.lo)
		local hasta = min(top, max(desde, mejor.hi))
		local g = mejor.g
		local ultimo = tramos[#tramos]
		if ultimo and ultimo.id == g.id then
			ultimo.hasta = hasta
		else
			tramos[#tramos + 1] = { desde = desde, hasta = hasta, id = g.id, titulo = texto(g.title) or tostring(g.id),
				zona = texto(g.zoneName), mazmorras = {} }
		end
		lv = max(hasta + 1, lv + 1)
	end
	-- Cada mazmorra en el tramo de su nivel.
	for _, d in ipairs(Ca.Mazmorras()) do
		for _, t in ipairs(tramos) do
			if d.nivel >= t.desde and d.nivel <= t.hasta then
				t.mazmorras[#t.mazmorras + 1] = d
				break
			end
		end
	end
	return tramos
end

local LADO = { Alliance = "A", Horde = "H" }

function Ca.Mazmorras()
	-- Los datos de las mazmorras vienen del Codex: nunca se piden peleando.
	if InCombatLockdown and InCombatLockdown() then return {} end
	local Dg = A.Dungeons
	if type(Dg) ~= "table" or type(Dg.List) ~= "function" then return {} end
	local ok, lista = pcall(Dg.List)
	if not ok or type(lista) ~= "table" then return {} end
	local lv, top = nivelJugador(), tope()
	local lado = LADO[jugador().faction or ""]
	local out = {}
	for _, d in ipairs(lista) do
		if type(d) == "table" and d.kind ~= "raid" and tonumber(d.minLevel) then
			local fuera = false
			if lado and type(Dg.EnemyCapital) == "function" then
				local okE, si = pcall(Dg.EnemyCapital, d.key, lado)
				fuera = okE and si and true or false
			end
			local mejor
			if type(Dg.BestAt) == "function" then
				local okB, b = pcall(Dg.BestAt, d.key)
				mejor = okB and tonumber(b) or nil
			end
			local lo, hi = tonumber(d.minLevel), tonumber(d.maxLevel) or tonumber(d.minLevel)
			mejor = mejor or floor((lo + hi) / 2)
			if not fuera and mejor >= lv and mejor < top then
				out[#out + 1] = { key = d.key, nombre = texto(d.name) or tostring(d.key), nivel = mejor, min = lo, max = hi }
			end
		end
	end
	table.sort(out, function(a, b) return a.nivel < b.nivel end)
	return out
end

---------------------------------------------------------------------------
-- Cada minuto (y al subir de nivel)
---------------------------------------------------------------------------

local ticker
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	A.After(2, Ca.Anotar)
	if not ticker then ticker = N.Ticker("inicio.camino", Ca.CADA, Ca.Anotar) end
end)
A.RegisterEvent("PLAYER_LEVEL_UP", function() A.After(1, Ca.Anotar) end)
A.RegisterEvent("PLAYER_LOGOUT", function() Ca.Anotar() end)
