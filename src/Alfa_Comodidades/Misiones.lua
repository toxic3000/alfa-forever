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
--   * Con "solo las misiones de mi ruta" encendido (ruta.soloRuta, el ajuste
--     de la ruta de Alfa) no acepta nada que no sea de tu ruta. Entregar lo
--     que ya llevas sigue igual: no toma nada nuevo.
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
-- Solo las de tu ruta
---------------------------------------------------------------------------

local function soloRuta() return A.Get("ruta.soloRuta") == true end

-- Si la misión es de tu ruta: lo dice la ruta de Alfa (AlfaRuta.EnRuta, si
-- la publica) y, si no, la guía que sigues en el motor (Engine.WantsQuest).
local function enRuta(q)
	q = legible(q)
	if not (q and q ~= 0) then return false end
	local Ru = AlfaRuta
	if type(Ru) == "table" and type(Ru.EnRuta) == "function" then
		local ok, si = pcall(Ru.EnRuta, q)
		if ok then return si and true or false end
	end
	return quiere("accept", q)
end

local function puedeAceptar(q) return not soloRuta() or enRuta(q) end

-- Antes de pedir algo en la ventana: que el motor no la cierre en ese
-- momento ("cerrar lo que la guía no toma", Automation.Keep; 1.1.6).
local function pedir()
	local Au = A.Automation
	if Au and Au.Keep then Au.Keep(2) end
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
	if not puedeAceptar(q) then return end -- sin marcarla: si cambias de ruta, vale
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
				pedir()
				SelectActiveQuest(i)
				return
			end
		end
	end
	if not SelectAvailableQuest then return end
	for i = 1, disponibles do
		local esTrivial, frecuencia, _, _, q = GetAvailableQuestInfo(i)
		q = legible(q)
		if not legible(esTrivial) and not (q and dejadas[q]) and quiereFrecuencia(frecuencia) and puedeAceptar(q) then
			pedir()
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
				pedir()
				G.SelectActiveQuest(q)
				return
			end
		end
	end
	if not G.SelectAvailableQuest then return end
	for _, info in ipairs(disponibles) do
		local q = legible(info.questID)
		if q and not dejadas[q] and not legible(info.isTrivial) and not legible(info.isIgnored)
			and quiereFrecuencia(info.frequency) and puedeAceptar(q) then
			pedir()
			G.SelectAvailableQuest(q)
			return
		end
	end
end

---------------------------------------------------------------------------
-- 1.2.8: Elegir la recompensa
---------------------------------------------------------------------------
-- Con varias recompensas para elegir (QUEST_COMPLETE), Alfa marca la mejor
-- para ti: la mayor mejora que tu clase puede usar comparada con lo que
-- llevas puesto (Alfa.Gear, por el orden del motor: QoL.Rewards.Rank) y, sin
-- mejoras, la que más vale al venderla. Una huella sobre su botón y, bajo la
-- ventana, «Alfa te recomienda: X». Solo se ve: nunca elige por ti (eso es
-- «Tomar la mejor recompensa» del motor, si la enciendes). Los botones de
-- recompensa no son seguros; nada se toca en ellos más que su marca.
-- Ajuste comodidades.recompensa (de fábrica, encendido).

A.RegisterDefaults(M.ID, { recompensa = true })

local K = N.Kit
local REINTENTOS, ESPERA = 4, 0.4
local ANCHO_LINEA = 300
local rec = { marca = nil, linea = nil, turno = 0 }

local function recompensaEncendida()
	return A.Get(M.ID .. ".recompensa") ~= false and not (A.Hidden and A.Hidden())
end

local function panelRecompensas()
	local f = (QuestInfoFrame and QuestInfoFrame.rewardsFrame) or rawget(_G, "QuestInfoRewardsFrame")
	if not (f and type(f.RewardButtons) == "table") then return nil end
	if f.IsShown and not f:IsShown() then return nil end
	return f
end

local function botonDe(i)
	local f = panelRecompensas()
	if not f then return nil end
	for _, b in pairs(f.RewardButtons) do
		if b and b.type == "choice" and (b.objectType == nil or b.objectType == "item") and b.IsShown and b:IsShown()
			and b.GetID and b:GetID() == i then
			return b
		end
	end
	return nil
end

-- Sin el motor: cada opción por su precio de venta (sin saber de mejoras).
local function opcionesPropias()
	local n = GetNumQuestChoices and num(GetNumQuestChoices()) or 0
	local lista, completa = {}, true
	local info = (C_Item and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
	for i = 1, n do
		local link = GetQuestItemLink and legible(GetQuestItemLink("choice", i))
		local cuenta = GetQuestItemInfo and select(3, GetQuestItemInfo("choice", i))
		local precio
		if link and type(info) == "function" then
			local ok, r = pcall(function() return select(11, info(link)) end)
			precio = ok and tonumber(legible(r)) or nil
		end
		if not (link and precio) then completa = false end
		local pila = num(cuenta) > 0 and num(cuenta) or 1
		lista[i] = { index = i, link = link, count = pila, value = (precio or 0) * pila }
	end
	return lista, completa
end

local function ordenPropio(lista)
	local orden = {}
	for i = 1, #lista do orden[i] = lista[i] end
	table.sort(orden, function(a, b)
		if a.value ~= b.value then return a.value > b.value end
		return a.index < b.index
	end)
	local out = {}
	for i = 1, #orden do out[i] = orden[i].index end
	return out, "value"
end

-- -> índice de la mejor, "upgrade" | "value"; nil, "esperar" (faltan datos)
local function laMejor()
	local R = A.QoL and A.QoL.Rewards
	local lista, completa, orden, por
	if R and type(R.ReadChoices) == "function" and type(R.Rank) == "function" then
		local ok, l, c = pcall(R.ReadChoices, false)
		if ok and type(l) == "table" then
			lista, completa = l, c
			if completa and #lista >= 2 then
				local okR, o, r = pcall(R.Rank, lista)
				if okR and type(o) == "table" then orden, por = o, r end
			end
		end
	end
	if not lista then
		lista, completa = opcionesPropias()
		if completa and #lista >= 2 then orden, por = ordenPropio(lista) end
	end
	if #lista < 2 then return nil end
	if not completa then return nil, "esperar" end
	if not (orden and orden[1]) then return nil end
	-- Sin mejoras ni precios (todo vale 0): nada que recomendar.
	if por ~= "upgrade" then
		local alguno = false
		for _, c in ipairs(lista) do if (c.value or 0) > 0 then alguno = true end end
		if not alguno then return nil end
	end
	return orden[1], por
end

local function ocultarRecompensa()
	rec.turno = rec.turno + 1
	rec.mejor, rec.por = nil, nil
	if rec.marca then rec.marca:Hide() end
	if rec.linea then rec.linea:Hide() end
end

local function marcaEn(b)
	local m = rec.marca
	if not m then
		m = CreateFrame("Frame", nil, b)
		m:SetSize(18, 18)
		m.Fondo = K.Plano(m, "fondo", "BACKGROUND")
		m.Fondo:SetAllPoints()
		m.Fondo:SetAlpha(0.85)
		m.Icono = K.Icono(m, "ic-huella", 12, "acento")
		m.Icono:SetPoint("CENTER", m, "CENTER", 0, 0)
		rec.marca = m
	end
	m:SetParent(b)
	m:SetFrameLevel((b:GetFrameLevel() or 1) + 4)
	m:ClearAllPoints()
	m:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	m:Show()
	return m
end

local function lineaBajo(nombre, por)
	local f = rec.linea
	if not f then
		f = CreateFrame("Frame", nil, K.Raiz())
		f:SetFrameStrata("MEDIUM")
		f:SetSize(ANCHO_LINEA, 44)
		f.caja = K.Caja(f, { fondo = "panel", borde = "acento", corte = K.CORTE.control })
		f.caja:Estilo({ alfaBorde = 0.6, alfaFondo = 0.94 })
		f.Icono = K.Icono(f, "ic-huella", 16, "acento")
		f.Icono:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -9)
		f.Titulo = K.Texto(f, "etiqueta", "texto")
		f.Titulo:SetWordWrap(true)
		f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 34, -9)
		f.Texto = K.Texto(f, "pequeno", "textoSuave")
		f.Texto:SetWordWrap(true)
		rec.linea = f
	end
	local tw = ANCHO_LINEA - 34 - 10
	K.Escribir(f.Titulo, string.format(L["Alfa te recomienda: %s"], nombre))
	K.Escribir(f.Texto, por == "upgrade" and L["Es una mejora para ti."] or L["Es la que más vale al venderla."])
	local y = 9 + K.Parrafo(f.Titulo, tw, 2)
	f.Texto:ClearAllPoints()
	f.Texto:SetPoint("TOPLEFT", f, "TOPLEFT", 34, -(y + 2))
	y = y + 2 + K.Parrafo(f.Texto, tw, 2)
	f:SetHeight(y + 9)
	f:ClearAllPoints()
	local q = rawget(_G, "QuestFrame")
	if q and q.IsShown and q:IsShown() then
		f:SetPoint("TOP", q, "BOTTOM", 0, -4)
	else
		f:SetPoint("TOP", UIParent, "TOP", 0, -140)
	end
	f:Show()
	return f
end

local function nombreOpcion(i)
	local nombre = GetQuestItemInfo and legible((GetQuestItemInfo("choice", i)))
	if type(nombre) == "string" and nombre ~= "" then return nombre end
	return string.format(L["la opción %d"], i)
end

-- -> índice marcado | nil
local function marcarRecompensa(intento, turno)
	if turno ~= rec.turno then return nil end
	if not recompensaEncendida() then ocultarRecompensa() return nil end
	local mejor, por = laMejor()
	if not mejor then
		if por == "esperar" and intento < REINTENTOS then
			A.After(ESPERA, function() M.Seguro(marcarRecompensa, intento + 1, turno) end)
		end
		return nil
	end
	local b = botonDe(mejor)
	if b then marcaEn(b) elseif rec.marca then rec.marca:Hide() end
	lineaBajo(nombreOpcion(mejor), por)
	rec.mejor, rec.por = mejor, por
	return mejor
end

local function alCompletarRecompensa()
	ocultarRecompensa()
	if not recompensaEncendida() then return end
	local n = GetNumQuestChoices and num(GetNumQuestChoices()) or 0
	if n < 2 then return end
	local turno = rec.turno
	-- La ventana del juego pinta sus botones al abrirse: un momento después.
	A.After(0.05, function() M.Seguro(marcarRecompensa, 0, turno) end)
end

A.RegisterEvent("QUEST_FINISHED", function() ocultarRecompensa() end)
A.RegisterEvent("QUEST_DETAIL", function() ocultarRecompensa() end)
A.RegisterEvent("QUEST_PROGRESS", function() ocultarRecompensa() end)
A.OnLogin(function()
	local q = rawget(_G, "QuestFrame")
	if q and q.HookScript then q:HookScript("OnHide", function() ocultarRecompensa() end) end
end)

-- Ajustes > Misiones: junto a lo demás de las misiones.
do
	local LM = A.L or {}
	local ok, err = A.RegisterOptions({ page = "questing", key = "questing", tab = LM["Quests"] or "Quests",
		section = L["Recompensas"], controls = {
			{ kind = "toggle", key = M.ID .. ".recompensa", label = L["Marcar la mejor recompensa para ti"],
				help = L["Una huella sobre la mejor para tu clase (o la que más vale al venderla) y «Alfa te recomienda». Nunca elige por ti."],
				search = "quest reward, best reward, upgrade, choose reward" },
		} })
	if not ok and geterrorhandler then geterrorhandler()(err) end
end

local function evento(fn)
	return function() M.Seguro(fn) end
end

A.RegisterEvent("QUEST_DETAIL", evento(alDetalle))
A.RegisterEvent("QUEST_PROGRESS", evento(alProgreso))
A.RegisterEvent("QUEST_COMPLETE", evento(alCompletar))
A.RegisterEvent("QUEST_COMPLETE", evento(alCompletarRecompensa))
A.RegisterEvent("QUEST_GREETING", evento(alSaludo))
A.RegisterEvent("GOSSIP_SHOW", evento(alDialogo))

-- Para pruebas.
M.Misiones = { Detalle = alDetalle, Progreso = alProgreso, Completar = alCompletar, Saludo = alSaludo, Dialogo = alDialogo, Dejadas = dejadas,
	SoloRuta = soloRuta, EnRuta = enRuta,
	-- 1.2.8: la recompensa recomendada
	Recompensa = alCompletarRecompensa, LaMejor = laMejor, Rec = rec,
	MarcarRecompensa = function() ocultarRecompensa() return marcarRecompensa(0, rec.turno) end }
