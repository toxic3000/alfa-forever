-- Alfa - Comodidades: aceptar y entregar todas las misiones. GPL-3.0.
--
-- El motor ya acepta y entrega las misiones de la guía (behavior.autoAccept
-- y behavior.autoTurnin, Core/Automation.lua). Esto hace lo mismo con las
-- demás: normales, diarias y semanales, cada una con su opción. Nunca toca
-- una ventana en la que el motor va a actuar, así los dos no se pisan.
--
-- Reglas (las mismas ideas que el motor):
--   * Mantener Mayús deja todo en tus manos.
--   * No acepta misiones grises (triviales), ni las que piden confirmar JcJ,
--     ni las que cierran otra misión para siempre (Alfa.Closes).
--   * No entrega misiones que piden oro, monedas o materiales de oficio
--     (tela, minerales, hierbas...): eso lo decides tú, y lo dice en el chat.
--   * Con varias recompensas para elegir no entrega: eliges tú (o "Tomar la
--     mejor recompensa" del motor, si la tienes encendida).
--   * Lo que dejó de lado una vez no lo vuelve a abrir en esa sesión, para
--     no repetirse si vuelves atrás en la ventana del PNJ.
--
-- Cliente (Forever, verificado en Mainline QuestFrame.lua / QuestInfo.lua y
-- en el motor): GetQuestID, AcceptQuest, QuestGetAutoAccept,
-- AcknowledgeAutoAcceptQuest, QuestFlagsPVP, IsQuestCompletable,
-- CompleteQuest, GetNumQuestItems, GetQuestItemLink, GetNumQuestCurrencies,
-- GetQuestMoneyToGet, GetNumQuestChoices, GetQuestReward,
-- GetNumActiveQuests, GetActiveTitle, GetActiveQuestID, SelectActiveQuest,
-- GetNumAvailableQuests, GetAvailableQuestInfo, SelectAvailableQuest,
-- GetTitleText; C_GossipInfo.GetActiveQuests / GetAvailableQuests /
-- SelectActiveQuest / SelectAvailableQuest (GossipInfoDocumentation);
-- C_QuestLog.IsQuestTrivial (QuestLogDocumentation); C_Item.GetItemInfoInstant
-- (ItemDocumentation). QuestIsDaily y QuestIsWeekly no están en la
-- documentación; otros addons los usan en Forever y aquí van protegidos.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local legible = M.Legible

-- Un número que da el cliente (0 si no lo hay o es secreto).
local function num(v) return tonumber(legible(v)) or 0 end

local function opcion(clave) return M.On("misiones", clave) end
local function activo() return M.Get("misiones") and not M.Shift() end

-- Lo que esta sesión ya dejó de lado (no se insiste): questID -> true.
local dejadas = {}

---------------------------------------------------------------------------
-- Lo que hace el motor con las misiones de la guía
---------------------------------------------------------------------------

local function quiere(verbo, q)
	local E = A.Engine
	if not (E and E.WantsQuest) then return false end
	local ok, si = pcall(E.WantsQuest, verbo, q)
	return ok and si and true or false
end

local function motorAcepta(q)
	q = legible(q)
	if not (q and q ~= 0) or not A.Get("behavior.autoAccept") then return false end
	return quiere("accept", q)
end

local function motorEntrega(q)
	q = legible(q)
	if not (q and q ~= 0) or not A.Get("behavior.autoTurnin") then return false end
	local C = A.Compat
	if C and C.IsOnQuest and C.IsOnQuest(q) then return quiere("turnin", q) end
	return quiere("direct", q)
end

---------------------------------------------------------------------------
-- Qué misiones toma
---------------------------------------------------------------------------

local FQ = Enum and Enum.QuestFrequency
local DIARIA = FQ and FQ.Daily or 1
local SEMANAL = FQ and FQ.Weekly or 2
local PROGRAMADA = FQ and FQ.ResetByScheduler or 3

local function quiereFrecuencia(f)
	f = legible(f)
	if f == SEMANAL then return opcion("misionesSemanales") end
	if f == DIARIA or f == PROGRAMADA then return opcion("misionesDiarias") end
	return opcion("misionesNormales")
end

-- La frecuencia de la misión que muestra la ventana de detalles.
local function frecuenciaDetalle()
	if QuestIsWeekly then
		local ok, si = pcall(QuestIsWeekly)
		if ok and legible(si) then return SEMANAL end
	end
	if QuestIsDaily then
		local ok, si = pcall(QuestIsDaily)
		if ok and legible(si) then return DIARIA end
	end
	return 0
end

local function trivial(q)
	local Q = C_QuestLog
	if not (q and Q and Q.IsQuestTrivial) then return false end
	local ok, si = pcall(Q.IsQuestTrivial, q)
	return ok and legible(si) and true or false
end

local function idActual()
	local q = GetQuestID and legible(GetQuestID())
	return (q and q ~= 0) and q or nil
end

local function titulo()
	local t = GetTitleText and legible(GetTitleText())
	return type(t) == "string" and t ~= "" and t or L["esta misión"]
end

-- Una vez por misión y sesión, por qué no la entregó.
local avisadas = {}
local function avisar(q, texto)
	local clave = q or titulo()
	if avisadas[clave] then return end
	avisadas[clave] = true
	N.Imprimir(texto)
end

---------------------------------------------------------------------------
-- Lo que piden para entregarla
---------------------------------------------------------------------------

local TRADEGOODS = Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods or 7

local function pideMateriales()
	if not (GetNumQuestItems and GetQuestItemLink) then return false end
	local GI = C_Item and C_Item.GetItemInfoInstant
	if not GI then return false end
	for i = 1, num(GetNumQuestItems()) do
		local link = legible(GetQuestItemLink("required", i))
		if link then
			local ok, _, _, _, _, _, clase = pcall(GI, link)
			if ok and legible(clase) == TRADEGOODS then return true end
		end
	end
	return false
end

local function pideOro()
	return GetQuestMoneyToGet and num(GetQuestMoneyToGet()) > 0 or false
end

local function pideMonedas()
	return GetNumQuestCurrencies and num(GetNumQuestCurrencies()) > 0 or false
end

---------------------------------------------------------------------------
-- Ventanas de misión
---------------------------------------------------------------------------

local function alDetalle()
	if not activo() then return end
	local q = idActual()
	if (q and dejadas[q]) or motorAcepta(q) then return end
	local function dejar() if q then dejadas[q] = true end end
	if not quiereFrecuencia(frecuenciaDetalle()) then return end -- sin marcarla: puedes encender ese tipo luego
	if trivial(q) then return dejar() end
	if QuestFlagsPVP and legible(QuestFlagsPVP()) then return dejar() end
	local Cl = A.Closes
	if Cl and Cl.HoldsOffer then
		local ok, cierra = pcall(Cl.HoldsOffer)
		if ok and cierra then return dejar() end
	end
	if QuestGetAutoAccept and legible(QuestGetAutoAccept()) then
		if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end
	elseif AcceptQuest then
		AcceptQuest()
	end
end

local function alProgreso()
	if not (activo() and opcion("misionesEntregar")) then return end
	local q = idActual()
	if (q and dejadas[q]) or motorEntrega(q) then return end
	if not (IsQuestCompletable and legible(IsQuestCompletable())) then return end
	if pideOro() or pideMonedas() then
		if q then dejadas[q] = true end
		return avisar(q, string.format(L["No entregué %s: pide oro o monedas. Entrégala tú si quieres."], titulo()))
	end
	if pideMateriales() then
		if q then dejadas[q] = true end
		return avisar(q, string.format(L["No entregué %s: pide materiales de oficio. Entrégala tú si quieres."], titulo()))
	end
	if CompleteQuest then CompleteQuest() end
end

local function alCompletar()
	if not (activo() and opcion("misionesEntregar")) then return end
	local q = idActual()
	if (q and dejadas[q]) or motorEntrega(q) then return end
	local opciones = GetNumQuestChoices and num(GetNumQuestChoices()) or 0
	if opciones > 1 then return end -- la recompensa la eliges tú
	if pideOro() then return end
	if GetQuestReward then GetQuestReward(opciones == 1 and 1 or 0) end
end

-- Varias misiones de un mismo PNJ (ventana de saludo): primero las entregas.
local function alSaludo()
	if not activo() then return end
	if not (GetActiveTitle and GetAvailableQuestInfo) then return end
	local activas = GetNumActiveQuests and num(GetNumActiveQuests()) or 0
	local disponibles = GetNumAvailableQuests and num(GetNumAvailableQuests()) or 0
	-- Si el motor va a actuar en esta ventana, es suya.
	for i = 1, activas do
		local _, completa = GetActiveTitle(i)
		if legible(completa) and motorEntrega(GetActiveQuestID and GetActiveQuestID(i)) then return end
	end
	for i = 1, disponibles do
		local q = select(5, GetAvailableQuestInfo(i))
		if motorAcepta(q) or motorEntrega(q) then return end
	end
	if opcion("misionesEntregar") and SelectActiveQuest then
		for i = 1, activas do
			local _, completa = GetActiveTitle(i)
			local q = GetActiveQuestID and legible(GetActiveQuestID(i))
			if legible(completa) and not (q and dejadas[q]) then
				SelectActiveQuest(i)
				return
			end
		end
	end
	if not SelectAvailableQuest then return end
	for i = 1, disponibles do
		local esTrivial, frecuencia, _, _, q = GetAvailableQuestInfo(i)
		q = legible(q)
		if not legible(esTrivial) and not (q and dejadas[q]) and quiereFrecuencia(frecuencia) then
			SelectAvailableQuest(i)
			return
		end
	end
end

local function alDialogo()
	if not activo() then return end
	local G = C_GossipInfo
	if not (G and G.GetActiveQuests and G.GetAvailableQuests) then return end
	local activas = G.GetActiveQuests() or {}
	local disponibles = G.GetAvailableQuests() or {}
	for _, info in ipairs(activas) do
		if legible(info.isComplete) and motorEntrega(info.questID) then return end
	end
	for _, info in ipairs(disponibles) do
		if motorAcepta(info.questID) or motorEntrega(info.questID) then return end
	end
	if opcion("misionesEntregar") and G.SelectActiveQuest then
		for _, info in ipairs(activas) do
			local q = legible(info.questID)
			if q and legible(info.isComplete) and not dejadas[q] then
				G.SelectActiveQuest(q)
				return
			end
		end
	end
	if not G.SelectAvailableQuest then return end
	for _, info in ipairs(disponibles) do
		local q = legible(info.questID)
		if q and not dejadas[q] and not legible(info.isTrivial) and not legible(info.isIgnored)
			and quiereFrecuencia(info.frequency) then
			G.SelectAvailableQuest(q)
			return
		end
	end
end

local function evento(fn)
	return function() M.Seguro(fn) end
end

A.RegisterEvent("QUEST_DETAIL", evento(alDetalle))
A.RegisterEvent("QUEST_PROGRESS", evento(alProgreso))
A.RegisterEvent("QUEST_COMPLETE", evento(alCompletar))
A.RegisterEvent("QUEST_GREETING", evento(alSaludo))
A.RegisterEvent("GOSSIP_SHOW", evento(alDialogo))

-- Para pruebas.
M.Misiones = { Detalle = alDetalle, Progreso = alProgreso, Completar = alCompletar, Saludo = alSaludo, Dialogo = alDialogo, Dejadas = dejadas }
