-- Alfa - Comodidades: el probador (como DressupItemButtons y
-- DressupAnimControl de Leatrix Plus, con código propio). GPL-3.0.
--
--   Botones de objetos: a los lados del modelo, un botón por ranura (como en
--     la hoja de personaje: cabeza a muñecas a la izquierda, manos a armas a
--     la derecha) con el ícono de lo que lleva puesto el modelo. Un clic lo
--     oculta en el modelo y otro lo vuelve a poner.
--   Animación: abajo del modelo, flechas para elegir lo que hace tu
--     personaje (quieto, caminar, bailar, saludar...) y un botón de pausa.
--
-- Forever usa el probador moderno (Mainline DressUpFrames.xml): DressUpFrame
-- con su ModelScene, y el actor del jugador por ModelScene:GetPlayerActor()
-- (Blizzard_SharedXML/ModelSceneMixin.lua). Del actor se usan
-- GetItemTransmogInfo, UndressSlot, SetItemTransmogInfo, DressPlayerSlot, SetAnimation y
-- SetPaused (FrameAPIModelSceneFrameActor*Documentation). Los íconos salen de
-- C_TransmogCollection.GetSourceItemID y C_Item.GetItemIconByID, y si no, del
-- ícono vacío de la ranura (GetInventorySlotInfo).
-- Ganchos (hooksecurefunc / HookScript, nunca se reemplaza nada):
-- DressUpFrame OnShow y SetMode, ModelScene:ReleaseAllActors (el modelo se
-- arma de nuevo: se olvida lo oculto) y el guion OnDressModel (te pruebas
-- algo en una ranura: vuelve a verse).
-- Los números de animación son los del juego (AnimationData): 0 quieto,
-- 4 caminar, 5 correr, 60 hablar, 66 reverencia, 67 saludar, 68 vitorear,
-- 69 bailar, 70 reír, 71 dormir, 74 rugir, 75 arrodillarse, 77 llorar,
-- 80 aplaudir, 82 músculos, 84 señalar.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local W, T = A.Widgets, A.Theme

local legible = M.Legible

local function opcion(clave) return M.On("probador", clave) end

local TAM, SEP = 28, 4
local MANO_PRINCIPAL = 16

-- { ranura, nombre de la ranura para GetInventorySlotInfo, texto global }
local IZQUIERDA = {
	{ 1, "HeadSlot", "HEADSLOT", L["Cabeza"] }, { 3, "ShoulderSlot", "SHOULDERSLOT", L["Hombros"] },
	{ 15, "BackSlot", "BACKSLOT", L["Espalda"] }, { 5, "ChestSlot", "CHESTSLOT", L["Pecho"] },
	{ 4, "ShirtSlot", "SHIRTSLOT", L["Camisa"] }, { 19, "TabardSlot", "TABARDSLOT", L["Tabardo"] },
	{ 9, "WristSlot", "WRISTSLOT", L["Muñecas"] },
}
local DERECHA = {
	{ 10, "HandsSlot", "HANDSSLOT", L["Manos"] }, { 6, "WaistSlot", "WAISTSLOT", L["Cintura"] },
	{ 7, "LegsSlot", "LEGSSLOT", L["Piernas"] }, { 8, "FeetSlot", "FEETSLOT", L["Pies"] },
	{ 16, "MainHandSlot", "MAINHANDSLOT", L["Mano principal"] }, { 17, "SecondaryHandSlot", "SECONDARYHANDSLOT", L["Mano secundaria"] },
	{ 18, "RangedSlot", "RANGEDSLOT", L["A distancia"] },
}

local ANIMACIONES = {
	{ 0, L["Quieto"] }, { 4, L["Caminar"] }, { 5, L["Correr"] }, { 60, L["Hablar"] },
	{ 66, L["Reverencia"] }, { 67, L["Saludar"] }, { 68, L["Vitorear"] }, { 69, L["Bailar"] },
	{ 70, L["Reír"] }, { 71, L["Dormir"] }, { 74, L["Rugir"] }, { 75, L["Arrodillarse"] },
	{ 77, L["Llorar"] }, { 80, L["Aplaudir"] }, { 82, L["Músculos"] }, { 84, L["Señalar"] },
}

local botones = {}   -- ranura -> botón
local ocultas = {}   -- ranura -> ItemTransmogInfo de lo que se ocultó
local poniendo = {}  -- ranura -> true mientras volvemos a poner algo
local columnas, barra
local animacion, pausado = 1, false

local function escena()
	local f = DressUpFrame
	return f and f.ModelScene
end

local function actor()
	local s = escena()
	if not (s and s.GetPlayerActor) then return nil end
	local ok, a = pcall(s.GetPlayerActor, s)
	return ok and a or nil
end

local function modoJugador()
	local f = DressUpFrame
	if not (f and f.GetMode) then return true end
	local ok, modo = pcall(f.GetMode, f)
	return not ok or modo == nil or modo == "player"
end

---------------------------------------------------------------------------
-- Botones de objetos
---------------------------------------------------------------------------

-- fn(...) en pcall: su primer valor si salió bien, si no nil.
local function llamar(fn, ...)
	if not fn then return nil end
	local ok, v = pcall(fn, ...)
	if ok then return legible(v) end
	return nil
end

local function iconoDe(ranura, vacio)
	local a = actor()
	local info = a and llamar(a.GetItemTransmogInfo, a, ranura)
	local apariencia = type(info) == "table" and legible(info.appearanceID)
	if apariencia and apariencia ~= 0 then
		local TC = C_TransmogCollection
		local item = TC and llamar(TC.GetSourceItemID, apariencia)
		local icono = item and C_Item and llamar(C_Item.GetItemIconByID, item)
		return icono or vacio, true
	end
	return vacio, false
end

local function pintarBoton(b)
	local oculta = ocultas[b.ranura] ~= nil
	local icono, lleva = iconoDe(b.ranura, b.vacio)
	if oculta and not lleva then
		icono = ocultas[b.ranura].icono or b.vacio
	end
	b.Icono:SetTexture(icono or b.vacio)
	b.Icono:SetDesaturated(oculta)
	b.Icono:SetAlpha(oculta and 0.45 or (lleva and 1 or 0.35))
	b.Tachado:SetShown(oculta)
	b.lleva = lleva
end

local function pintarTodo()
	for _, b in pairs(botones) do M.Seguro(pintarBoton, b) end
end

local function alternar(b)
	local a = actor()
	if not a then return end
	local r = b.ranura
	local guardado = ocultas[r]
	if guardado then
		ocultas[r] = nil
		poniendo[r] = true
		if a.SetItemTransmogInfo and guardado.info then
			pcall(a.SetItemTransmogInfo, a, guardado.info, r, r ~= MANO_PRINCIPAL)
		elseif a.DressPlayerSlot then
			-- Sin lo guardado: lo que tienes puesto en esa ranura.
			pcall(a.DressPlayerSlot, a, r)
		end
	else
		if not b.lleva or not a.UndressSlot then return end
		ocultas[r] = { info = llamar(a.GetItemTransmogInfo, a, r), icono = b.Icono:GetTexture() }
		pcall(a.UndressSlot, a, r)
	end
	pintarBoton(b)
	A.After(0.1, pintarTodo)
end

local function tooltipBoton(b)
	local lineas = {}
	if ocultas[b.ranura] then
		lineas[1] = { L["Oculto en el modelo."], T.Color("warning") }
		lineas[2] = L["Clic: volver a ponerlo."]
	elseif b.lleva then
		lineas[1] = L["Clic: ocultarlo en el modelo."]
	else
		lineas[1] = L["El modelo no lleva nada aquí."]
	end
	W.Tooltip(b, b.lado == "izq" and "ANCHOR_LEFT" or "ANCHOR_RIGHT", b.nombre, lineas)
end

local function crearBoton(padre, datos, lado)
	local b = CreateFrame("Button", nil, padre)
	b:SetSize(TAM, TAM)
	b.ranura, b.lado = datos[1], lado
	b.nombre = _G[datos[3]] or datos[4]
	local ok, _, vacio = pcall(GetInventorySlotInfo, datos[2])
	b.vacio = ok and vacio or 134400 -- el signo de pregunta
	W.Fill(b, "bg", "BACKGROUND")
	b.Icono = b:CreateTexture(nil, "ARTWORK")
	b.Icono:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.Icono:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	T.Border(b, 0, 0, 0, 0.9, "OVERLAY")
	local luz = b:CreateTexture(nil, "HIGHLIGHT")
	luz:SetAllPoints(b.Icono)
	luz:SetTexture(T.Media("white"))
	luz:SetVertexColor(1, 1, 1, 0.15)
	b.Tachado = W.Tex(b, "OVERLAY", "cross", "danger")
	b.Tachado:SetSize(16, 16)
	b.Tachado:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.Tachado:Hide()
	b:SetScript("OnClick", function(self) M.Seguro(alternar, self) end)
	b:SetScript("OnEnter", function(self) M.Seguro(tooltipBoton, self) end)
	b:SetScript("OnLeave", function(self) W.HideTooltip(self) end)
	botones[b.ranura] = b
	return b
end

local function crearColumnas()
	if columnas then return columnas end
	local s = escena()
	if not s then return nil end
	columnas = CreateFrame("Frame", nil, s)
	columnas:SetAllPoints(s)
	columnas:SetFrameLevel(s:GetFrameLevel() + 5)
	for i, d in ipairs(IZQUIERDA) do
		local b = crearBoton(columnas, d, "izq")
		b:SetPoint("TOPLEFT", columnas, "TOPLEFT", 8, -8 - (i - 1) * (TAM + SEP))
	end
	for i, d in ipairs(DERECHA) do
		local b = crearBoton(columnas, d, "der")
		b:SetPoint("TOPRIGHT", columnas, "TOPRIGHT", -8, -8 - (i - 1) * (TAM + SEP))
	end
	return columnas
end

---------------------------------------------------------------------------
-- Animación
---------------------------------------------------------------------------

local function aplicarAnimacion()
	local a = actor()
	if not a then return end
	local anim = ANIMACIONES[animacion]
	if a.SetAnimation and anim then pcall(a.SetAnimation, a, anim[1], 0, 1, 0) end
	if a.SetPaused then pcall(a.SetPaused, a, pausado) end
end

local function pintarBarra()
	if not barra then return end
	barra.Nombre:SetText(ANIMACIONES[animacion][2])
	W.SetButtonText(barra.Pausa, pausado and L["Seguir"] or L["Pausa"])
end

local function cambiarAnimacion(paso)
	animacion = (animacion - 1 + paso) % #ANIMACIONES + 1
	pintarBarra()
	aplicarAnimacion()
end

local function crearBarra()
	if barra then return barra end
	local s = escena()
	if not s then return nil end
	barra = CreateFrame("Frame", nil, s)
	barra:SetSize(236, 30)
	barra:SetPoint("BOTTOM", s, "BOTTOM", 0, 8)
	barra:SetFrameLevel(s:GetFrameLevel() + 6)
	T.Skin(barra, "panel")
	local antes = W.IconButton(barra, "chevron-left", 24, L["Animación anterior"], function() M.Seguro(cambiarAnimacion, -1) end)
	antes:SetPoint("LEFT", barra, "LEFT", 4, 0)
	barra.Pausa = W.Button(barra, L["Pausa"], function()
		pausado = not pausado
		pintarBarra()
		M.Seguro(aplicarAnimacion)
	end, { height = 22, width = 64 })
	barra.Pausa:SetPoint("RIGHT", barra, "RIGHT", -4, 0)
	local despues = W.IconButton(barra, "chevron-right", 24, L["Animación siguiente"], function() M.Seguro(cambiarAnimacion, 1) end)
	despues:SetPoint("RIGHT", barra.Pausa, "LEFT", -4, 0)
	barra.Nombre = W.Text(barra, "label", "text")
	barra.Nombre:SetPoint("LEFT", antes, "RIGHT", 4, 0)
	barra.Nombre:SetPoint("RIGHT", despues, "LEFT", -4, 0)
	barra.Nombre:SetJustifyH("CENTER")
	pintarBarra()
	return barra
end

---------------------------------------------------------------------------
-- Mostrar y ocultar con el probador
---------------------------------------------------------------------------

local function actualizar()
	local f = DressUpFrame
	if not (f and f:IsShown()) then return end
	local jugador = modoJugador()
	local conBotones = jugador and opcion("probadorBotones")
	local conBarra = jugador and opcion("probadorAnimacion")
	if conBotones then crearColumnas() end
	if columnas then columnas:SetShown(conBotones) end
	if conBarra then crearBarra() end
	if barra then barra:SetShown(conBarra) end
	if conBotones then pintarTodo() end
end

-- El modelo se armó de nuevo: lo oculto vuelve a verse y la animación
-- elegida se pone otra vez cuando el actor termina de cargar.
local function modeloNuevo()
	for k in pairs(ocultas) do ocultas[k] = nil end
	for k in pairs(poniendo) do poniendo[k] = nil end
	A.After(0.2, function()
		if opcion("probadorAnimacion") and (animacion ~= 1 or pausado) then aplicarAnimacion() end
		actualizar()
	end)
	A.After(0.8, function()
		if opcion("probadorAnimacion") and (animacion ~= 1 or pausado) then aplicarAnimacion() end
		if columnas and columnas:IsShown() then pintarTodo() end
	end)
end

local function alVestir(_, _, ranura, quitado)
	ranura = legible(ranura)
	if not ranura then return end
	if not quitado then
		if poniendo[ranura] then poniendo[ranura] = nil else ocultas[ranura] = nil end
	end
	A.After(0, function() if columnas and columnas:IsShown() then pintarTodo() end end)
end

local enganchado = false
local function enganchar()
	if enganchado then return end
	local f = DressUpFrame
	local s = escena()
	if not (f and s and hooksecurefunc) then return end
	enganchado = true
	f:HookScript("OnShow", function() M.Seguro(actualizar) end)
	if f.SetMode then hooksecurefunc(f, "SetMode", function() M.Seguro(actualizar) end) end
	if s.ReleaseAllActors then hooksecurefunc(s, "ReleaseAllActors", function() M.Seguro(modeloNuevo) end) end
	if s.HookScript and s.HasScript and s:HasScript("OnDressModel") then
		s:HookScript("OnDressModel", function(...) M.Seguro(alVestir, ...) end)
	end
end

M.AlCambiar({ "probador", "probadorBotones", "probadorAnimacion" }, function()
	if M.Get("probador") then enganchar() end
	if not opcion("probadorBotones") and columnas then columnas:Hide() end
	if not opcion("probadorAnimacion") and barra then barra:Hide() end
	actualizar()
end)

function M.HayProbador()
	return DressUpFrame ~= nil and DressUpFrame.ModelScene ~= nil
end

-- Para pruebas.
M.Probador = { Actualizar = actualizar, Alternar = alternar, Animaciones = ANIMACIONES }
