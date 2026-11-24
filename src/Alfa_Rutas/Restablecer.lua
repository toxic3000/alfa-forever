-- Alfa - Rutas: restablecer una guía y empezar desde un paso (toxic3000 / La
-- Jauría). GPL-3.0. 1.3.9 (pedido de Toxic)
--
-- «Por error omití la de minería y ya no puedo regresar a cierto paso»:
--   * Restablecer esta guía: olvida lo omitido y lo marcado a mano (pasos,
--     metas y las misiones omitidas de esta guía) y vuelve a ubicarte solo:
--     el último paso que el juego ya da por hecho (una meta de habilidad o de
--     «craftear hasta N» que tu oficio ya pasó, un nivel que ya tienes, una
--     misión ya entregada o que llevas en tu registro) y todo lo de antes
--     queda atrás; la guía sigue en el primero que te falta.
--   * Empezar desde este paso: la guía sigue desde el paso que elijas (los
--     de antes quedan omitidos; los de después se abren otra vez).
-- Los dos con confirmación y «Deshacer» (vuelve todo como estaba: lo
-- omitido, lo marcado y el paso). Se piden desde el menú de la guía del
-- rastreador, el clic derecho de un paso (rastreador, detalle y ventana de
-- guía), la pestaña de la ventana de guía, Planes y /alfa guia restablecer.
--
--   Restablecer.Restablecer(sinPreguntar) -> ok
--   Restablecer.Detectar() -> paso | nil      hasta dónde lo de antes queda atrás
--   Restablecer.EmpezarDesde(paso, sinPreguntar) -> ok
--   Restablecer.Deshacer() -> ok             Restablecer.PuedeDeshacer() -> bool

local ADDON, M = ...
local A, L, N, K = M.A, M.L, M.N, M.K
local Rb = {}
M.Restablecer = Rb

local type, ipairs, pairs, tonumber, pcall = type, ipairs, pairs, tonumber, pcall
local format = string.format

local function E() return M.Motor("Engine") end
local function CP() return M.Motor("Compat") end

-- Lo que el motor guarda por guía (CharState()[campo][guía]); lo mismo que
-- Guias.Olvidar borra.
local CAMPOS = { "manual", "skipped", "when", "skipStored", "added", "gone", "behind", "passedBefore", "lostQuests",
	"guideEnds", "shapes", "stepKeys", "shapeVersions", "ownShapes", "pins" }

local function estado()
	if type(A.CharState) ~= "function" then return nil end
	local ok, s = pcall(A.CharState)
	return ok and type(s) == "table" and s or nil
end

local function guia()
	local e = E()
	return e and e.GetGuide and e.GetGuide() or nil
end

local function nombre(g)
	local u = A.UI
	local n = u and u.GuideLabel and select(2, pcall(u.GuideLabel, g))
	if type(n) ~= "string" or n == "" then n = g and g.title or L["Tu guía"] end
	return n
end

-- Las misiones de la guía (para volver a abrir las que omitiste).
local function misionesDe(g)
	local out, visto = {}, {}
	for _, s in ipairs(g and g.steps or {}) do
		for _, x in ipairs(s.goals or {}) do
			local q = tonumber(x.quest)
			if q and not visto[q] then visto[q] = true out[#out + 1] = q end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Deshacer: una foto de lo que el motor guardaba de esta guía
---------------------------------------------------------------------------
local foto

local function tomarFoto(g, que)
	local s = estado()
	local e = E()
	if not (s and g) then return nil end
	local f = { id = g.id, que = que, campos = {}, misiones = {}, vivo = e.GetLiveStep and e.GetLiveStep() or nil,
		vista = e.GetStepIndex and e.GetStepIndex() or nil }
	for _, c in ipairs(CAMPOS) do
		if type(s[c]) == "table" and s[c][g.id] ~= nil then f.campos[c] = M.Copia(s[c][g.id]) end
	end
	if e.IsQuestSkipped then
		for _, q in ipairs(misionesDe(g)) do
			if e.IsQuestSkipped(q) then f.misiones[#f.misiones + 1] = q end
		end
	end
	return f
end

function Rb.PuedeDeshacer()
	local g = guia()
	return foto ~= nil and g ~= nil and g.id == foto.id
end

function Rb.Deshacer()
	local g, s, e = guia(), estado(), E()
	if not (foto and g and s and e and g.id == foto.id) then return false end
	local f = foto
	foto = nil
	for _, c in ipairs(CAMPOS) do
		if type(s[c]) ~= "table" then s[c] = {} end
		s[c][f.id] = f.campos[c] and M.Copia(f.campos[c]) or nil
	end
	for _, q in ipairs(f.misiones) do pcall(e.SkipQuest, q, true) end
	-- Goto vuelve a calcular el paso de ahora con lo guardado y mira el de antes.
	local a = f.vivo or f.vista
	if a and e.Goto then pcall(e.Goto, a) end
	if f.vista and f.vista ~= a and e.Goto then pcall(e.Goto, f.vista) end
	M.Aviso(L["Volvió como estaba"], nombre(g), { icono = "ic-exito" })
	if M.Rastreador and M.Rastreador.Luego then M.Rastreador.Luego() end
	return true
end

local function avisoConDeshacer(titulo, texto)
	M.Aviso(titulo, texto, { icono = "ic-exito", duracion = 10, importante = "siempre",
		accion = { texto = L["Deshacer"], alClic = function() Rb.Deshacer() end } })
end

---------------------------------------------------------------------------
-- Dónde vas, según el juego
---------------------------------------------------------------------------
local SIEMPRE = { skill = true, level = true }

local function hechaLaMision(q)
	local Cp = CP()
	if Cp and Cp.IsQuestCompleted and Cp.IsQuestCompleted(q) then return true end
	local f = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
	if type(f) == "function" then
		local ok, r = pcall(f, q)
		if ok and N.Leer(r) == true then return true end
	end
	return false
end
local function enRegistro(q)
	local Cp = CP()
	return Cp and Cp.IsOnQuest and Cp.IsOnQuest(q) and true or false
end

-- ¿Es para este personaje? (la condición del paso y de la meta, en el motor).
local function aplica(e, s, gi)
	if not e.Applies then return true end
	local ok, r = pcall(e.Applies, s, gi)
	return not ok or r ~= false
end

-- ¿Es guía de oficio? (metas de habilidad o de «craftear hasta N»).
local function deOficio(g)
	for _, paso in ipairs(g.steps or {}) do
		for _, x in ipairs(paso.goals or {}) do
			if x.t == "skill" or (x.t == "craft" and x.untilSkill) then return true end
		end
	end
	return false
end

-- Una meta que el juego puede contestar: true (hecha), false (te falta) o
-- nil (no dice nada: un viaje, una nota...).
local function segunElJuego(e, s, gi, x)
	local t = x.t
	if SIEMPRE[t] or (t == "craft" and x.untilSkill) then
		local ok, r = pcall(e.GoalDone, s, gi)
		return ok and r == true
	elseif (t == "turnin" or t == "accept") and tonumber(x.quest) then
		local q = tonumber(x.quest)
		return hechaLaMision(q) or (t == "accept" and enRegistro(q))
	end
	return nil
end

-- Dónde vas: el último paso que el juego ya da por hecho, y lo de antes
-- queda atrás. -> índice | nil
--   * Guía de oficio: el último con una meta de habilidad, de «craftear
--     hasta N» o de nivel cumplida (tu habilidad no baja).
--   * Guía de niveles (1.3.9, revisión 5): el paso de antes del primero que
--     te falta (una misión que no entregaste ni llevas, o un nivel que aún no
--     tienes). Una misión de mucho más adelante que ya llevas en tu registro
--     no te salta media guía.
function Rb.Detectar()
	local g, e = guia(), E()
	if not (g and e and e.GoalDone) then return nil end
	local oficio = deOficio(g)
	local ultimo
	for s, paso in ipairs(g.steps or {}) do
		local hecho, falta = false, false
		for gi, x in ipairs(paso.goals or {}) do
			if aplica(e, s, gi) then
				local r = segunElJuego(e, s, gi, x)
				if r == true then hecho = true elseif r == false then falta = true end
			end
		end
		if oficio then
			if hecho then ultimo = s end
		elseif falta then
			-- El primero que te falta: lo de antes queda atrás.
			return ultimo and s > 1 and (s - 1) or nil
		elseif hecho then
			ultimo = s
		end
	end
	return ultimo
end

---------------------------------------------------------------------------
-- Restablecer
---------------------------------------------------------------------------
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function hacerRestablecer()
	local g, e = guia(), E()
	if not (g and e) then return false end
	foto = tomarFoto(g, "restablecer")
	-- 1. Olvidar todo lo tuyo de esta guía (también las misiones omitidas).
	for _, q in ipairs(foto and foto.misiones or {}) do pcall(e.SkipQuest, q, false) end
	M.Guias.Olvidar(g.id)
	if e.ResetProgress then pcall(e.ResetProgress) end
	-- 2. Ubicarte: lo de antes del último paso hecho queda atrás.
	local hecho = Rb.Detectar()
	local total = e.GetStepCount and e.GetStepCount() or 0
	if hecho and e.SkipUpTo then
		pcall(e.SkipUpTo, math.min(total, hecho + 1))
	end
	local vivo = e.GetLiveStep and e.GetLiveStep()
	if vivo and e.Goto then pcall(e.Goto, vivo) end
	local v = vivo and e.GetStepView and e.GetStepView(vivo)
	local donde = v and type(v.title) == "string" and v.title ~= "" and format(L["Sigues en: %s."], v.title) or L["Tu guía quedó al día."]
	avisoConDeshacer(format(L["Restableciste %s"], nombre(g)), donde)
	if M.Rastreador and M.Rastreador.Luego then M.Rastreador.Luego() end
	return true
end

function Rb.Restablecer(sinPreguntar)
	local g = guia()
	if not g then
		M.Aviso(L["Restablecer esta guía"], L["No sigues ninguna guía ahora."], { icono = "ic-info" })
		return false
	end
	if enCombate() then
		M.Aviso(L["Restablecer esta guía"], L["Se puede al salir de combate."], { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	if sinPreguntar then return hacerRestablecer() end
	K.Dialogo({
		titulo = format(L["¿Restablecer %s?"], nombre(g)),
		texto = L["Olvido lo que omitiste y marcaste a mano en esta guía, y te ubico solo por lo que ya llevas: tu habilidad del oficio, tu nivel y tus misiones. Puedes deshacerlo."],
		aceptar = L["Restablecer"], alAceptar = hacerRestablecer,
	})
	return true
end

---------------------------------------------------------------------------
-- Empezar desde un paso
---------------------------------------------------------------------------
local function hacerDesde(paso)
	local g, e = guia(), E()
	if not (g and e and g.steps and g.steps[paso]) then return false end
	foto = tomarFoto(g, "desde")
	local vivo = e.GetLiveStep and e.GetLiveStep()
	-- Los de este paso en adelante que omitiste se abren otra vez.
	if e.Unskip then
		for s = paso, #g.steps do pcall(e.Unskip, s) end
	end
	vivo = e.GetLiveStep and e.GetLiveStep()
	-- Los de antes quedan atrás (omitidos, sin borrar lo que ya hiciste).
	if vivo and vivo < paso and e.SkipUpTo then pcall(e.SkipUpTo, paso) end
	if e.Goto then pcall(e.Goto, paso) end
	local v = e.GetStepView and e.GetStepView(paso)
	avisoConDeshacer(L["La guía sigue desde aquí"], v and type(v.title) == "string" and v.title ~= "" and v.title or format(L["Paso %d"], paso))
	if M.Rastreador and M.Rastreador.Luego then M.Rastreador.Luego() end
	return true
end

function Rb.EmpezarDesde(paso, sinPreguntar)
	paso = tonumber(paso)
	local g = guia()
	if not (paso and g and g.steps and g.steps[paso]) then return false end
	if enCombate() then
		M.Aviso(L["Empezar desde este paso"], L["Se puede al salir de combate."], { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	if sinPreguntar then return hacerDesde(paso) end
	local e = E()
	local v = e and e.GetStepView and e.GetStepView(paso)
	K.Dialogo({
		titulo = L["¿Empezar desde este paso?"],
		texto = format(L["La guía sigue desde «%s». Los pasos de antes quedan omitidos (lo que ya hiciste no se pierde) y puedes deshacerlo."],
			v and v.title or format(L["Paso %d"], paso)),
		aceptar = L["Empezar desde aquí"], alAceptar = function() hacerDesde(paso) end,
	})
	return true
end

-- Para los menús: las dos opciones (la de un paso, si se da).
function Rb.Opciones(paso)
	local op = {}
	local e = E()
	if paso and e and e.GetLiveStep and paso ~= e.GetLiveStep() then
		op[#op + 1] = { valor = function() Rb.EmpezarDesde(paso) end, texto = L["Empezar desde este paso"], icono = "ic-huella" }
	end
	op[#op + 1] = { valor = function() Rb.Restablecer() end, texto = L["Restablecer esta guía"], icono = "ic-ruta" }
	return op
end
