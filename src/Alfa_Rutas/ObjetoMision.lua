-- Alfa - Rutas: el botón del objeto de misión, más claro (toxic3000 / La
-- Jauría). GPL-3.0.
-- 1.3.0
--
-- El motor ya tiene el botón seguro del objeto de misión del paso de ahora
-- (AlfaQuestItemButton, QoL/Buttons.lua: se arma fuera de combate, se mueve
-- con el resto y se le pone tecla como «CLICK AlfaQuestItemButton:
-- LeftButton»). Alfa no hace otro: le suma, solo con texturas y texto (nada
-- seguro, así que también vale en combate):
--   * el nombre del objeto y cuánto llevas («Antorcha · 2 de 5») junto al
--     botón, en la etiqueta que el motor deja vacía para este botón;
--   * un aro de La Jauría que late cuando lo puedes usar ya (al alcance de
--     tu objetivo y sin espera), para que no se te pase;
--   * en el rastreador, la tecla que tiene (o cómo ponérsela).
-- Ajuste rutas.objetoBoton.
--
--   Objeto.Boton() -> el botón del motor | nil
--   Objeto.Tecla() -> texto de la tecla | nil
--   Objeto.Texto(itemID) -> «Nombre · 2 de 5»
--   Objeto.Listo(boton) -> bool   (se puede usar ya)
--   Objeto.Pintar()

local ADDON, M = ...
local A, L, K = M.A, M.L, M.K
local Ob = {}
M.Objeto = Ob

A.RegisterDefaults(M.ID, { objetoBoton = true })

local type, ipairs, tonumber, pcall = type, ipairs, tonumber, pcall
local format = string.format

local NOMBRE = "AlfaQuestItemButton"
local BINDING = "CLICK " .. NOMBRE .. ":LeftButton"

local function encendido() return A.Get(M.ID .. ".objetoBoton") ~= false end

function Ob.Boton() return rawget(_G, NOMBRE) end

function Ob.Tecla()
	if not GetBindingKey then return nil end
	local k = GetBindingKey(BINDING)
	if type(k) ~= "string" or k == "" then return nil end
	local B = A.QoL and A.QoL.Buttons
	if B and B.KeyText then
		local ok, t = pcall(B.KeyText, k)
		if ok and type(t) == "string" and t ~= "" then return t end
	end
	return k
end

-- El avance de la meta "use" del paso de ahora con ese objeto (cur, max) | nil.
local function avance(item)
	local Q = A.QoL
	local ok, view = pcall(function() return Q and Q.CurrentStep and Q.CurrentStep() end)
	if not ok or type(view) ~= "table" then return nil end
	for _, g in ipairs(view.goals or {}) do
		if g.item == item and g.progress and tonumber(g.progress.max) and g.progress.max > 1 then
			return tonumber(g.progress.cur) or 0, g.progress.max
		end
	end
	for _, g in ipairs(view.goals or {}) do
		if g.status == "active" and g.progress and tonumber(g.progress.max) and g.progress.max > 1 then
			return tonumber(g.progress.cur) or 0, g.progress.max
		end
	end
	return nil
end

function Ob.Texto(item)
	local nombre = M.NombreObjeto(item)
	local cur, max = avance(item)
	if cur then return format(L["%s · %d de %d"], nombre, cur, max) end
	return nombre
end

-- Al alcance (el motor lo pinta "near") y sin espera.
function Ob.Listo(b)
	if not (b and b.itemID and b:IsShown()) then return false end
	if b.tint == "far" then return false end
	if not (UnitExists and UnitExists("target")) then return false end
	local f = (C_Container and C_Container.GetItemCooldown) or rawget(_G, "GetItemCooldown")
	if type(f) == "function" then
		local ok, inicio, dura = pcall(f, b.itemID)
		if ok and type(dura) == "number" and dura > 1.5 and type(inicio) == "number" and inicio > 0 then return false end
	end
	return b.tint == "near"
end

local function armarAro(b)
	if b.alfaAro then return b.alfaAro end
	local aro = b:CreateTexture(nil, "OVERLAY", nil, 7)
	aro:SetTexture(K.Ruta("ic-huella"))
	aro:SetPoint("CENTER", b, "TOPRIGHT", -2, -2)
	aro:SetSize(16, 16)
	aro:Hide()
	local halo = b:CreateTexture(nil, "BACKGROUND", nil, -2)
	halo:SetTexture(K.Ruta("ic-huella"))
	halo:SetPoint("CENTER", b, "CENTER", 0, 0)
	halo:SetSize(56, 56)
	halo:SetBlendMode("ADD")
	halo:Hide()
	local ag = halo:CreateAnimationGroup()
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(0.9)
	a:SetToAlpha(0.25)
	a:SetDuration(0.8)
	ag:SetLooping("BOUNCE")
	aro.Halo, aro.Late = halo, ag
	b.alfaAro = aro
	return aro
end

local listoAntes
local function pintarListo(b)
	local aro = b.alfaAro
	if not aro then return end
	local listo = encendido() and Ob.Listo(b)
	if listo == listoAntes then return end
	listoAntes = listo
	aro:SetShown(listo)
	aro.Halo:SetShown(listo)
	if listo then
		aro:SetVertexColor(K.Color("acento"))
		aro.Halo:SetVertexColor(K.ConAlfa("acento", 0.5))
		if A.Get("ui.reduceMotion") then aro.Late:Stop() else aro.Late:Play() end
	else
		aro.Late:Stop()
	end
end

function Ob.Pintar()
	local b = Ob.Boton()
	if not b then return end
	if not encendido() then
		if b.alfaEtiqueta and b.Label then b.Label:SetText("") end
		b.alfaEtiqueta = nil
		listoAntes = nil
		if b.alfaAro then pintarListo(b) end
		return
	end
	armarAro(b)
	if b.Label and b.itemID then
		local t = Ob.Texto(b.itemID)
		if b.Label:GetText() ~= t then b.Label:SetText(t) end
		b.alfaEtiqueta = true
	elseif b.Label and b.alfaEtiqueta then
		b.Label:SetText("")
		b.alfaEtiqueta = nil
	end
	listoAntes = nil
	pintarListo(b)
end

-- 1.3.9 (30): ¿estás cerca de su objetivo? (el motor lo pinta "near"). El
-- rastreador muestra entonces el objeto con su clic (K.Seguro: hace clic en
-- el botón seguro del motor, solo fuera de combate y con tu clic).
function Ob.Cerca()
	local b = Ob.Boton()
	return (encendido() and b and b.itemID and b:IsShown() and b.tint == "near") and true or false
end
local cercaAntes = false

local enganchado = false
local function enganchar()
	local b = Ob.Boton()
	if enganchado or not b then return end
	enganchado = true
	-- Texturas y texto (no seguros): HookScript no cambia lo que hace el botón.
	local cada = 0
	b:HookScript("OnUpdate", function(self, dt)
		cada = cada + (dt or 0)
		if cada < 0.25 then return end
		cada = 0
		pintarListo(self)
		local cerca = Ob.Cerca()
		if cerca ~= cercaAntes then
			cercaAntes = cerca
			if M.Rastreador and M.Rastreador.Luego then M.Rastreador.Luego() end
		end
	end)
	b:HookScript("OnShow", function() Ob.Pintar() end)
	Ob.Pintar()
end
Ob.Enganchar = enganchar

-- Fuera de combate se arma (el botón lo crea el motor al entrar al mundo).
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	A.After(1, function() M.N.FueraDeCombate("rutas:objeto", enganchar) end)
end)
A.On("STEP_CHANGED", function() A.After(0.2, Ob.Pintar) end)
A.RegisterEvent("QUEST_LOG_UPDATE", function() if enganchado then Ob.Pintar() end end)
A.RegisterEvent("PLAYER_TARGET_CHANGED", function() local b = Ob.Boton() if b and b.alfaAro then listoAntes = nil pintarListo(b) end end)
