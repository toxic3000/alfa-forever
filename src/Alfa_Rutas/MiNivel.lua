-- Alfa - Rutas: «Saltar a mi nivel» (toxic3000 / La Jauría). GPL-3.0.
-- 1.4.0 (26)
--
-- Si tu guía va atrás de tu nivel (subiste con mazmorras, en grupo o en otra
-- zona y la guía sigue en lo de antes), el rastreador te lo dice y te ofrece
-- ir a la parte que te toca: «Ya eres nivel 24 y esta parte es para llegar
-- al 22. ¿Saltas al paso 58?». Atrás quiere decir que más adelante hay una
-- meta de «Sube al nivel N» con N menor que tu nivel: la parte que sirve para
-- llegar ahí ya no te hace falta. Se salta hasta el paso que sigue a la
-- última meta de nivel que ya tienes (Restablecer.EmpezarDesde: los pasos de
-- antes quedan omitidos, lo que ya hiciste no se pierde, y con «Deshacer»).
-- Si la guía entera ya te queda chica, propone la siguiente (Siguiente.lua).
--
-- Nunca en combate ni en una guía de oficio (sus metas son de habilidad);
-- con su X se calla para esa guía en la sesión. Ajuste rutas.saltarNivel.
--
--   MiNivel.Destino() -> { paso, titulo, meta, nivel, salto, chica = bool } | nil
--   MiNivel.Aviso(v, live) -> el aviso del rastreador | nil
--   MiNivel.Saltar(d) -> ok

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local Mn = {}
M.MiNivel = Mn

A.RegisterDefaults(M.ID, { saltarNivel = true })

local type, ipairs, tonumber, pcall, format = type, ipairs, tonumber, pcall, string.format

local MIN_SALTO = 4 -- pasos: saltar menos que esto no vale la pena decirlo

local function E() return A.Engine end
local function encendido() return A.Get(M.ID .. ".saltarNivel") ~= false end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function miNivel()
	local I = M.Indice
	local p = I and I.Jugador and I.Jugador() or {}
	return M.num(N.Leer(p.level), 1)
end

local function aplica(e, s, gi)
	if not e.Applies then return true end
	local ok, r = pcall(e.Applies, s, gi)
	return not ok or r ~= false
end

local function deOficio(g)
	for _, paso in ipairs(g.steps or {}) do
		for _, x in ipairs(paso.goals or {}) do
			if x.t == "skill" or (x.t == "craft" and x.untilSkill) then return true end
		end
	end
	return false
end

local function titulo(e, s)
	local v = e.GetStepView and e.GetStepView(s)
	local t = type(v) == "table" and v.title
	return (type(t) == "string" and t ~= "") and t or format(L["Paso %d"], s)
end

local guardado -- { clave, d }

function Mn.Destino()
	local e = E()
	if not (encendido() and e and e.GetGuide and e.GetLiveStep) then return nil end
	local g = e.GetGuide()
	local live = e.GetLiveStep()
	if type(g) ~= "table" or type(g.steps) ~= "table" or not live then return nil end
	local nivel = miNivel()
	local clave = tostring(g.id) .. ":" .. live .. ":" .. nivel
	if guardado and guardado.clave == clave then return guardado.d end
	local d
	if not deOficio(g) then
		local ultimo, meta, atras
		for s = live, #g.steps do
			for gi, x in ipairs(g.steps[s].goals or {}) do
				local n = x.t == "level" and tonumber(x.level)
				if n and aplica(e, s, gi) then
					if n <= nivel then
						ultimo, meta = s, n
						if n < nivel then atras = true end
					end
				end
			end
		end
		if ultimo and atras then
			local destino = ultimo + 1
			if destino > #g.steps then
				d = { chica = true, meta = meta, nivel = nivel }
			elseif destino - live >= MIN_SALTO then
				d = { paso = destino, titulo = titulo(e, destino), meta = meta, nivel = nivel, salto = destino - live }
			end
		end
	end
	guardado = { clave = clave, d = d }
	return d
end

function Mn.Olvidar() guardado = nil end

function Mn.Saltar(d)
	d = d or Mn.Destino()
	if not (d and d.paso and M.Restablecer) then return false end
	Mn.Olvidar()
	return M.Restablecer.EmpezarDesde(d.paso, true)
end

function Mn.Aviso(v, live)
	if not (v and live and v.index == live) or enCombate() then return nil end
	local d = Mn.Destino()
	if not d then return nil end
	local e = E()
	local g = e and e.GetGuide and e.GetGuide()
	local id = type(g) == "table" and tostring(g.id) or "?"
	if d.chica then
		local sig = M.Siguiente and M.Siguiente.Proponer and M.Siguiente.Proponer() or nil
		if not sig then return nil end
		return { tono = "info", icono = "ic-nivel", clave = "rutas.miNivel:" .. id,
			titulo = L["Esta guía ya te queda chica"],
			texto = format(L["Ya eres nivel %d: lo que falta de esta guía es para llegar al %d. Lo que sigue para tu nivel: %s."], d.nivel, d.meta, sig.nombre),
			uno = { L["Seguir con la siguiente"], function() M.Siguiente.Seguir(sig) end } }
	end
	return { tono = "info", icono = "ic-nivel", clave = "rutas.miNivel:" .. id,
		titulo = L["Tu guía va atrás de tu nivel"],
		texto = format(L["Ya eres nivel %d y esta parte de la guía es para llegar al %d. La que te toca empieza en el paso %d: %s."],
			d.nivel, d.meta, d.paso, d.titulo),
		uno = { L["Saltar a mi nivel"], function() Mn.Saltar(d) end } }
end

for _, msg in ipairs({ "GUIDE_CHANGED", "STEP_CHANGED", "STEP_SKIPPED" }) do A.On(msg, Mn.Olvidar) end
A.RegisterEvent("PLAYER_LEVEL_UP", Mn.Olvidar)
