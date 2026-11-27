-- Alfa - Rutas: «¡Lista para entregar!», tu misión terminada con la flecha a un clic (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Cuando terminas lo que pide una misión que tu guía no va a entregar (la
-- tomaste por tu cuenta, te la compartieron, la guía ya pasó por ahí), Alfa
-- te avisa una vez: «Pieles de jabalí: se entrega con Gornek», con
-- «Llévame a entregarla» (la flecha a quien la recibe, IrMision.lua) y, con
-- 2 o más listas, «Vuelta a entregar». Las que tu guía sí entrega no se
-- avisan: la guía ya te lleva (AlfaRuta.EsDeMiRuta).
--
-- Solo lo que acaba de pasar: al entrar al juego, en un /reload o tras una
-- pantalla de carga, las primeras lecturas solo aprenden tu registro (el
-- juego llena sus cuentas tarde). En combate espera a que salgas. Aquí no se
-- lee el Codex: el nombre de quien la recibe sale de lo que ya se sabe.
--
--   La.Revisar()   lee tu registro y avisa lo nuevo
--   La.Listas() -> { [qid] = true }   las listas que conoce
-- Ajuste: rutas.avisoLista (de fábrica, sí).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local La = {}
M.ListaAviso = La

A.RegisterDefaults(M.ID, { avisoLista = true })

local type, ipairs, pairs, tonumber = type, ipairs, pairs, tonumber
local format, concat = string.format, table.concat

local ASENTAR = 5 -- segundos tras entrar en los que solo se aprende

local function CP() return M.Motor("Compat") end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function ahora() return GetTime and GetTime() or 0 end

local listas = {}
local aprendiendoHasta = 0
local conocido = false

function La.Listas() return listas end

local function deMiRuta(qid)
	local R = rawget(_G, "AlfaRuta")
	if type(R) == "table" and type(R.EsDeMiRuta) == "function" then
		local ok, si = pcall(R.EsDeMiRuta, qid, "turnin")
		return ok and si and true or false
	end
	return false
end

local function cuantasListas()
	local n = 0
	for _ in pairs(listas) do n = n + 1 end
	return n
end

local function avisar(nuevas)
	local Cp = CP()
	local quedan = {}
	for _, qid in ipairs(nuevas) do
		if Cp.IsQuestReadyForTurnIn(qid) and not deMiRuta(qid) then quedan[#quedan + 1] = qid end
	end
	if #quedan == 0 then return end
	local Ir = M.IrMision
	local acciones = {}
	local titulo, texto
	if #quedan == 1 then
		local qid = quedan[1]
		local cita = M.Citar(M.TituloMision(qid))
		local p = Ir and Ir.Punto(qid, nil, true)
		titulo = L["¡Lista para entregar!"]
		texto = p and p.nombre and format(L["%s: se entrega con %s."], cita, p.nombre)
			or format(L["%s ya tiene todo lo que pide."], cita)
		if Ir then acciones[1] = { texto = L["Llévame a entregarla"], alClic = function() Ir.Ir(qid) end } end
	else
		local nombres = {}
		for i, qid in ipairs(quedan) do
			if i > 3 then break end
			nombres[#nombres + 1] = M.Citar(M.TituloMision(qid))
		end
		titulo = format(L["%d misiones listas para entregar"], #quedan)
		texto = concat(nombres, ", ") .. (#quedan > 3 and "…" or "")
	end
	local total = cuantasListas()
	if total >= 2 and A.Get(M.ID .. ".vueltaEntregar") ~= false then
		acciones[#acciones + 1] = { texto = format(L["Vuelta a entregar (%d)"], total), alClic = function() M.EntregarListas() end }
	end
	M.Aviso(titulo, texto, { icono = "ic-misiones", tono = "exito", acciones = acciones, prioridad = 3, caduca = 120,
		suceso = "rutas.lista." .. tostring(quedan[1]) })
end

function La.Revisar()
	local Cp = CP()
	if not (Cp and Cp.GetLogQuests and Cp.IsQuestReadyForTurnIn) then return end
	local ya = {}
	for _, qid in ipairs(Cp.GetLogQuests() or {}) do
		if Cp.IsQuestReadyForTurnIn(qid) then ya[qid] = true end
	end
	local nuevas = {}
	local aprender = not conocido or ahora() < aprendiendoHasta
	if not aprender then
		for qid in pairs(ya) do
			if not listas[qid] then nuevas[#nuevas + 1] = qid end
		end
	end
	listas = ya
	conocido = true
	if #nuevas == 0 or A.Get(M.ID .. ".avisoLista") == false then return end
	table.sort(nuevas)
	if enCombate() and N.FueraDeCombate then
		N.FueraDeCombate("rutas.listaAviso", function() avisar(nuevas) end)
	else
		avisar(nuevas)
	end
end

local function pronto() if N.Una then N.Una("rutas.listaAviso", 0.8, La.Revisar) else La.Revisar() end end

A.RegisterEvent("QUEST_LOG_UPDATE", pronto)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	aprendiendoHasta = ahora() + ASENTAR
	pronto()
end)
