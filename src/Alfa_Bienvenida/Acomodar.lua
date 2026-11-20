-- Alfa - Bienvenida: acomodar la pantalla (1.3.1). toxic3000 / La Jauría. GPL-3.0.
--
-- Un solo modo para mover con el ratón todo lo de Alfa que está en pantalla:
-- Lya, tu guía (el rastreador), la flecha, la tarjeta de avisos, la barra y
-- las metas de pesca, y los marcos de Combate y Curación. Al entrar, el
-- juego se oscurece un poco, cada cosa sale con un marco verde y su nombre, y
-- una cruz fina marca el centro de la pantalla para alinearse. Se arrastra
-- cada una; clic derecho la regresa a su lugar de siempre (si lo tiene). Cada
-- cosa guarda su lugar con su propio código (el mismo de cuando la arrastras a
-- mano), así que nada nuevo se guarda aquí. Combate y Curación encienden sus
-- propios marcos para mover. «Listo», Esc o entrar en combate lo terminan.
--
--   /alfa acomodar   ·   Ajustes > Estilo y sonido > «Acomodar la pantalla»
--   M.Acomodar.Abrir() / .Cerrar() / .Activo() / .Marcas() (para el banco)

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local Ac = {}
M.Acomodar = Ac

-- marco: el nombre global del marco que se ve y se mueve. asa: dónde está su
-- OnDragStop, el que guarda el lugar ("hijo": el primer hijo que lo tenga,
-- como la cabecera del rastreador). modo "script": su OnDragStart hace falta
-- (la flecha anota ahí que se está moviendo).
local ELEMENTOS = {
	{ id = "lya", nombre = "Lya", marco = "AlfaLyaLoba",
		restablecer = function() N.Set("lya", "pos", nil) end },
	{ id = "rastreador", nombre = "Tu guía", marco = "AlfaRastreador", asa = "hijo" },
	{ id = "flecha", nombre = "La flecha", marco = "AlfaNavArrow", modo = "script",
		restablecer = function(f)
			local Nav = A.Nav
			if Nav and Nav.ResetArrowPosition then Nav.ResetArrowPosition() end
			f:ClearAllPoints()
			f:SetPoint("TOP", UIParent, "TOP", 0, -140)
		end },
	{ id = "aviso", nombre = "Los avisos", marco = "AlfaInicioAviso",
		restablecer = function() N.Set("inicio", "avisoPos", nil) end },
	{ id = "pescaBarra", nombre = "La barra de pesca", marco = "AlfaPescaBarra" },
	{ id = "pescaMetas", nombre = "Tus metas de pesca", marco = "AlfaPescaMetas" },
}
-- Los que traen sus propios marcos para mover: se encienden y se apagan.
local PROPIOS = {
	{ id = "combate", global = "AlfaCombate",
		encender = function(C) if type(C.Mover) == "function" then C.Mover() return true end end,
		apagar = function(C) if type(C.Mover) == "function" then C.Mover() end end },
	{ id = "curacion", global = "AlfaCuracion",
		encender = function(C)
			if type(C.Mover) ~= "function" then return false end
			if type(C.Moviendo) == "function" and C.Moviendo() then return false end
			C.Mover(true)
			return true
		end,
		apagar = function(C) if type(C.Mover) == "function" then C.Mover(false) end end },
}

local activo = false
local velo, panel
local marcas = {}      -- id -> el marco verde de cada cosa
local encendidos = {}  -- id de PROPIOS que encendimos nosotros
local bloqueoAntes     -- A.DragLocked de antes (mientras acomodas, nada está bloqueado)

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function marcoDe(el) local f = rawget(_G, el.marco) return type(f) == "table" and f or nil end

-- El hijo que guarda el lugar (el que tiene OnDragStop).
local function asaDe(el, f)
	if el.asa ~= "hijo" then return f end
	for _, h in ipairs({ f:GetChildren() }) do
		if h.GetScript and h:GetScript("OnDragStop") then return h end
	end
	return f
end

local function empezar(el)
	local f = marcoDe(el)
	if not f or enCombate() then return end
	el.moviendo = true
	if el.modo == "script" and f:GetScript("OnDragStart") then
		f:GetScript("OnDragStart")(f)
	elseif f.StartMoving then
		if f.SetMovable then f:SetMovable(true) end
		f:StartMoving()
	end
end

local function soltar(el)
	if not el.moviendo then return end
	el.moviendo = false
	local f = marcoDe(el)
	if not f then return end
	local asa = asaDe(el, f)
	local alSoltar = asa and asa:GetScript("OnDragStop")
	if alSoltar then
		alSoltar(asa)
	elseif f.StopMovingOrSizing then
		f:StopMovingOrSizing()
	end
end

---------------------------------------------------------------------------
-- Lo que se ve
---------------------------------------------------------------------------

local function pintarMarca(m)
	local r, g, b = K.Color(K.Clasico() and "oro" or "acento")
	m.Fondo:SetColorTexture(r, g, b, m.sobre and 0.22 or 0.12)
	for _, t in ipairs(m.Bordes) do t:SetColorTexture(r, g, b, 0.95) end
end

local function crearMarca(el)
	local m = CreateFrame("Button", nil, UIParent)
	m:SetFrameStrata("FULLSCREEN_DIALOG")
	m:SetFrameLevel(20)
	m:RegisterForClicks("RightButtonUp")
	m.Fondo = m:CreateTexture(nil, "BACKGROUND")
	m.Fondo:SetAllPoints(m)
	m.Bordes = {}
	for i, lado in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
		local t = m:CreateTexture(nil, "BORDER")
		t:SetPoint(lado[1], m, lado[1], 0, 0)
		t:SetPoint(lado[2], m, lado[2], 0, 0)
		if lado[3] then t:SetHeight(2) else t:SetWidth(2) end
		m.Bordes[i] = t
	end
	-- El nombre, en una etiqueta oscura arriba del marco.
	m.Etiqueta = CreateFrame("Frame", nil, m)
	m.Etiqueta:SetPoint("BOTTOMLEFT", m, "TOPLEFT", 0, 3)
	m.Etiqueta.caja = K.Caja(m.Etiqueta, { fondo = "fondo", borde = "linea" })
	m.Nombre = K.Texto(m.Etiqueta, "nota", "texto")
	m.Nombre:SetPoint("LEFT", m.Etiqueta, "LEFT", 6, 0)
	K.Escribir(m.Nombre, L[el.nombre])
	m.Etiqueta:SetSize(K.AnchoTexto(m.Nombre) + 12, 18)

	m:SetScript("OnMouseDown", function(_, boton) if boton == "LeftButton" then empezar(el) end end)
	m:SetScript("OnMouseUp", function(_, boton) if boton == "LeftButton" then soltar(el) end end)
	m:SetScript("OnHide", function() soltar(el) end)
	m:SetScript("OnClick", function(_, boton)
		if boton ~= "RightButton" or not el.restablecer or enCombate() then return end
		local f = marcoDe(el)
		pcall(el.restablecer, f)
	end)
	m:SetScript("OnEnter", function(self)
		self.sobre = true
		pintarMarca(self)
		K.MostrarInfo(self, L[el.nombre], el.restablecer and L["Arrástralo para moverlo. Clic derecho: vuelve a su lugar de siempre."]
			or L["Arrástralo para moverlo."])
	end)
	m:SetScript("OnLeave", function(self)
		self.sobre = nil
		pintarMarca(self)
		K.OcultarInfo(self)
	end)
	pintarMarca(m)
	return m
end

local function crearVelo()
	velo = CreateFrame("Frame", nil, UIParent)
	velo:SetAllPoints(UIParent)
	velo:SetFrameStrata("DIALOG")
	velo:EnableMouse(false)
	velo.Oscuro = velo:CreateTexture(nil, "BACKGROUND")
	velo.Oscuro:SetAllPoints(velo)
	velo.Oscuro:SetColorTexture(0, 0, 0, 0.35)
	-- La cruz del centro, para alinear.
	velo.V = velo:CreateTexture(nil, "ARTWORK")
	velo.V:SetPoint("TOP", velo, "TOP", 0, 0)
	velo.V:SetPoint("BOTTOM", velo, "BOTTOM", 0, 0)
	velo.V:SetWidth(1)
	velo.H = velo:CreateTexture(nil, "ARTWORK")
	velo.H:SetPoint("LEFT", velo, "LEFT", 0, 0)
	velo.H:SetPoint("RIGHT", velo, "RIGHT", 0, 0)
	velo.H:SetHeight(1)
	K.Pintar(velo, function(x)
		local r, g, b = K.Color(K.Clasico() and "oro" or "acento")
		x.V:SetColorTexture(r, g, b, 0.3)
		x.H:SetColorTexture(r, g, b, 0.3)
	end)
	velo:Hide()
end

local function crearPanel()
	panel = CreateFrame("Frame", "AlfaAcomodar", UIParent)
	panel:SetFrameStrata("FULLSCREEN_DIALOG")
	panel:SetFrameLevel(40)
	panel:SetSize(420, 112)
	panel:SetPoint("TOP", UIParent, "TOP", 0, -64)
	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:SetClampedToScreen(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
	panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	panel.caja = K.Caja(panel, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.panel })
	panel.Marca = K.Marca(panel, K.CORTE.panel, "acento")
	panel.Icono = K.Icono(panel, "ic-ventana", 18, "acento")
	panel.Icono:SetPoint("TOPLEFT", panel, "TOPLEFT", K.ESP.m, -K.ESP.m)
	panel.Titulo = K.Texto(panel, "encabezado", "texto")
	panel.Titulo:SetPoint("LEFT", panel.Icono, "RIGHT", K.ESP.s, 0)
	K.Escribir(panel.Titulo, L["Acomodar la pantalla"])
	panel.Texto = K.Texto(panel, "nota", "textoSuave")
	panel.Texto:SetPoint("TOPLEFT", panel.Icono, "BOTTOMLEFT", 0, -K.ESP.s)
	panel.Texto:SetPoint("RIGHT", panel, "RIGHT", -K.ESP.m, 0)
	panel.Texto:SetJustifyH("LEFT")
	panel.Listo = K.Boton(panel, L["Listo"], function() Ac.Cerrar() end, { tipo = "primario", tam = "chico" })
	panel.Listo:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -K.ESP.m, K.ESP.m)
	-- Esc lo termina; las demás teclas siguen siendo del juego.
	panel:EnableKeyboard(true)
	panel:SetScript("OnKeyDown", function(self, tecla)
		local esc = tecla == "ESCAPE"
		if self.SetPropagateKeyboardInput and not enCombate() then self:SetPropagateKeyboardInput(not esc) end
		if esc then Ac.Cerrar() end
	end)
	panel:Hide()
end

---------------------------------------------------------------------------
-- Entrar y salir
---------------------------------------------------------------------------

function Ac.Activo() return activo end
function Ac.Marcas() return marcas end

function Ac.Abrir()
	if activo then return true end
	if enCombate() then
		N.Imprimir(L["Los marcos se mueven fuera de combate."])
		return false
	end
	if not velo then crearVelo() end
	if not panel then crearPanel() end
	activo = true
	-- Mientras acomodas, nada está bloqueado (la flecha con «Fijar» incluida).
	bloqueoAntes = A.DragLocked
	A.DragLocked = function() return false end
	local vistos, ocultos = 0, 0
	for _, el in ipairs(ELEMENTOS) do
		local f = marcoDe(el)
		if f and f:IsVisible() then
			local m = marcas[el.id] or crearMarca(el)
			marcas[el.id] = m
			m:ClearAllPoints()
			m:SetAllPoints(f)
			m:Show()
			vistos = vistos + 1
		else
			ocultos = ocultos + 1
		end
	end
	wipe(encendidos)
	for _, p in ipairs(PROPIOS) do
		local C = rawget(_G, p.global)
		if type(C) == "table" then
			local ok, si = pcall(p.encender, C)
			if ok and si then encendidos[p.id] = C vistos = vistos + 1 end
		end
	end
	local texto = L["Arrastra lo que quieras mover. Clic derecho en uno: vuelve a su lugar de siempre."]
	if ocultos > 0 then texto = texto .. " " .. L["Lo que no está a la vista no sale aquí."] end
	if vistos == 0 then texto = L["Ahora no hay nada de Alfa a la vista para mover. Abre tu guía, la pesca o Lya y vuelve a entrar."] end
	K.Escribir(panel.Texto, texto)
	velo:Show()
	panel:Show()
	return true
end

function Ac.Cerrar()
	if not activo then return end
	activo = false
	for _, el in ipairs(ELEMENTOS) do soltar(el) end
	for _, m in pairs(marcas) do m:Hide() end
	for _, p in ipairs(PROPIOS) do
		local C = encendidos[p.id]
		if C then pcall(p.apagar, C) end
	end
	wipe(encendidos)
	if bloqueoAntes ~= nil then A.DragLocked = bloqueoAntes end
	bloqueoAntes = nil
	if velo then velo:Hide() end
	if panel then panel:Hide() end
end

function Ac.Alternar() if activo then Ac.Cerrar() else Ac.Abrir() end end

-- Una pelea lo termina: en combate no se mueve nada.
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() if activo then Ac.Cerrar() end end)

A.RegisterCommand("acomodar", function() Ac.Alternar() end, L["acomoda con el ratón lo de Alfa en tu pantalla"])

AlfaAcomodar = type(AlfaAcomodar) == "table" and AlfaAcomodar or {}
function AlfaAcomodar.Abrir() return Ac.Abrir() end
function AlfaAcomodar.Cerrar() return Ac.Cerrar() end
function AlfaAcomodar.Activo() return activo end
