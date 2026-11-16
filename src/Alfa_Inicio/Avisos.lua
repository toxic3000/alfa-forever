-- Alfa - Inicio: los avisos en pantalla (Toxic / La Jauría). GPL-3.0.
--
-- Una tarjeta pequeña con el estilo de Alfa, como la alerta de raros del
-- motor (Alfa/Rares/Toast.lua): arriba una banda de noche con el glifo en su
-- anillo (o el ícono de un hechizo), el título y una línea; debajo el texto y
-- hasta dos botones (el principal a la derecha). Baja desde arriba, se vacía
-- una línea mientras espera, se queda quieta con el cursor encima y se
-- cierra sola a los inicio.segAviso segundos. Se arrastra para moverla
-- (inicio.avisoPos). Uno a la vez: los demás esperan en una cola corta, y un
-- aviso urgente pasa primero.
--
--   M.Aviso.Mostrar(spec)
--     spec = { clave, tipo = "info" | "exito" | "aviso" | "peligro",
--              icono = glifo de Alfa/Media/UI, textura = fileID (un hechizo),
--              titulo, linea, texto, segundos, sonido = true,
--              botones = { { texto, fn, icono }, ... } }  -- el primero es el principal
--   M.Aviso.Ocultar(todo)   -- todo = true vacía también la cola
--   M.Aviso.Visible() -> la clave del aviso en pantalla, o nil

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local W, T, Anim = A.Widgets, A.Theme, A.Anim
local L = N.Textos(M.EN)

local floor, max, min, ceil, ipairs, type = math.floor, math.max, math.min, math.ceil, ipairs, type

local Aviso = {}
M.Aviso = Aviso

local WIDTH, MAX_W, BAND_H, PAD = 360, 470, 54, 16
local RING, GLYPH, ICON = 32, 16, 26
local TEXT_X = PAD + RING + 12
local BTN_H = 26
local COLA_MAX = 5
local DEFAULT = { "TOP", 0, -250 }
local COLOR = { info = "accent", exito = "success", aviso = "warning", peligro = "danger" }

local f, actual
local cola = {}

local function casa() return T.SkinKey() == "alfa" end

local function lugar()
	local p = N.Get("inicio", "avisoPos")
	if type(p) ~= "table" or type(p[1]) ~= "string" then p = DEFAULT end
	Anim.Anchor(f, p[1], UIParent, p[1], tonumber(p[2]) or 0, tonumber(p[3]) or 0)
end

-- Degradado vertical: color de arriba, color de abajo.
local function vgrad(t, r1, g1, b1, a1, r2, g2, b2, a2)
	if t.SetGradient and CreateColor then
		t:SetVertexColor(1, 1, 1, 1)
		t:SetGradient("VERTICAL", CreateColor(r2, g2, b2, a2), CreateColor(r1, g1, b1, a1))
	else
		t:SetVertexColor(r2, g2, b2, (a1 + a2) / 2)
	end
end

local function clic(self)
	local b = self.psBoton
	if not b then return end
	Aviso.Ocultar()
	if type(b.fn) == "function" then A.SafeCall(b.fn) end
end

local function construir()
	f = CreateFrame("Frame", "AlfaInicioAviso", A.UIParent)
	f:SetSize(WIDTH, BAND_H + 80)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	-- Un aviso: las apariencias del juego le dan el marco claro de la guía.
	f.psLight = true
	T.Skin(f, "window")

	-- La banda de noche: qué es.
	local head = CreateFrame("Frame", nil, f)
	head:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	head:SetHeight(BAND_H)
	f.Head = head
	f.Night = head:CreateTexture(nil, "BACKGROUND", nil, -8)
	f.Night:SetTexture(T.Media("white"))
	f.Night:SetAllPoints(head)
	W.Painter(f.Night, function(t)
		t:SetShown(casa())
		local tr, tg, tb = T.Color("scrim")
		local br, bg, bb = T.Color("bg")
		vgrad(t, tr, tg, tb, 1, br, bg, bb, 1)
	end)
	if W.Haze then f.Haze = W.Haze(head, { height = BAND_H, sub = -6 }) end
	f.Band = T.Band(head, "BACKGROUND", -5)
	f.Band:SetAllPoints(head)
	f.Band:SetTexCoord(T.BandCoords(WIDTH - 2, BAND_H))
	f.BandRule = W.Divider(f)
	f.BandRule:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -(BAND_H + 1))
	f.BandRule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -(BAND_H + 1))

	-- El glifo en su anillo, del color del tipo; o el ícono de un hechizo.
	f.Ring = W.Tex(head, "ARTWORK", "qol-ring", "accent")
	f.Ring:SetSize(RING, RING)
	f.Ring:SetPoint("LEFT", head, "LEFT", PAD - 1, 0)
	f.Glyph = W.Tex(head, "OVERLAY", "info", "accent")
	f.Glyph:SetSize(GLYPH, GLYPH)
	f.Glyph:SetPoint("CENTER", f.Ring, "CENTER", 0, 0)
	f.Icon = head:CreateTexture(nil, "OVERLAY")
	f.Icon:SetSize(ICON, ICON)
	f.Icon:SetPoint("CENTER", f.Ring, "CENTER", 0, 0)
	f.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.Icon:Hide()

	f.Title = W.Text(head, "title", "title")
	f.Title:SetPoint("BOTTOMLEFT", f.Ring, "RIGHT", 12, 1)
	f.Title:SetPoint("RIGHT", head, "RIGHT", -40, 0)
	f.Line = W.Text(head, "small", "textDim")
	f.Line:SetPoint("TOPLEFT", f.Ring, "RIGHT", 12, -3)
	f.Line:SetPoint("RIGHT", head, "RIGHT", -PAD, 0)
	for _, fs in ipairs({ f.Title, f.Line }) do
		W.Painter(fs, function(t)
			local r, g, b = T.Color("shade")
			t:SetShadowOffset(0, -1)
			t:SetShadowColor(r, g, b, 0.85)
		end)
	end

	f.Close = W.IconButton(head, "close", 22, L["Cerrar"], function() Aviso.Ocultar() end, 12)
	f.Close:SetPoint("TOPRIGHT", head, "TOPRIGHT", -8, -8)

	f.Text = W.Text(f, "note", "textDim")
	f.Text:SetWordWrap(true)
	f.Text:SetSpacing(2)
	f.Text:SetJustifyV("TOP")
	f.Text:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(BAND_H + 1 + 12))

	-- Dos botones: el principal (a la derecha) y uno más.
	f.Primary = W.Button(f, "", clic, { primary = true, height = BTN_H })
	f.Second = W.Button(f, "", clic, { height = BTN_H })

	f.Timer = W.ProgressLine(f, 2)
	f.Timer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
	f.Timer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint(1)
		if point then N.Set("inicio", "avisoPos", { point, floor(x + 0.5), floor(y + 0.5) }) end
	end)
	-- Solo mientras se ve, y a lo más 20 veces por segundo.
	f:SetScript("OnUpdate", A.Safe(function(self, elapsed)
		if self:IsMouseOver() then return end
		self.psLeft = (self.psLeft or 0) - elapsed
		self.psTick = (self.psTick or 0) + elapsed
		if self.psTick >= 0.05 then
			self.psTick = 0
			W.SetProgress(self.Timer, max(0, self.psLeft) / (self.psTotal or 1), self:GetWidth() - 2)
		end
		if self.psLeft <= 0 then Aviso.Ocultar() end
	end))
	if W.Rim then W.Rim(f, { height = BAND_H }) end
	f:Hide()
	Aviso.frame = f
end

local function ponerBoton(b, spec)
	if not spec then
		b:Hide()
		b.psBoton = nil
		return 0
	end
	b.psBoton = spec
	W.SetButtonText(b, spec.texto or "")
	b:Show()
	return b:GetWidth()
end

local function pintar(spec)
	actual = spec
	local color = COLOR[spec.tipo] or "accent"
	if spec.textura then
		f.Icon:SetTexture(spec.textura)
		f.Icon:Show()
		f.Glyph:Hide()
		f.Ring:SetShown(false)
	else
		f.Icon:Hide()
		f.Glyph:SetTexture(T.Media(spec.icono or "info"))
		W.Color(f.Glyph, color)
		f.Glyph:Show()
		W.Color(f.Ring, color)
		f.Ring:Show()
	end
	f.Title:SetText(spec.titulo or "")
	f.Line:SetText(spec.linea or "")
	f.Text:SetText(spec.texto or "")
	f.Text:SetShown((spec.texto or "") ~= "")

	local botones = type(spec.botones) == "table" and spec.botones or {}
	local w1 = ponerBoton(f.Primary, botones[1])
	local w2 = ponerBoton(f.Second, botones[2])
	local bw = w1 + (w2 > 0 and (8 + w2) or 0)

	local need = max(WIDTH,
		TEXT_X + ceil(W.TextWidth(f.Title)) + 40,
		TEXT_X + ceil(W.TextWidth(f.Line)) + PAD,
		bw + PAD * 2)
	local width = min(MAX_W, need)
	f:SetWidth(width)
	if W.LayoutRim then W.LayoutRim(f) end
	f.Band:SetTexCoord(T.BandCoords(width - 2, BAND_H))
	f.Text:SetWidth(width - PAD * 2)

	local y = BAND_H + 1 + 12
	if f.Text:IsShown() then y = y + ceil(f.Text:GetStringHeight()) end
	if w1 > 0 then
		y = y + 12
		f.Primary:ClearAllPoints()
		f.Primary:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -y)
		if w2 > 0 then
			f.Second:ClearAllPoints()
			f.Second:SetPoint("RIGHT", f.Primary, "LEFT", -8, 0)
		end
		y = y + BTN_H
	end
	f:SetHeight(y + 14)

	local secs = tonumber(spec.segundos) or tonumber(N.Get("inicio", "segAviso")) or 10
	if w1 > 0 then secs = secs + 4 end
	f.psTotal, f.psLeft, f.psTick = secs, secs, 0
	W.SetProgress(f.Timer, 1, width - 2)

	local wasShown = f:IsShown()
	lugar()
	f:Show()
	if not wasShown then
		local p = f.psAnchor
		Anim.To(f, "alpha", 0, 1, Anim.SLOW, "out")
		if p then Anim.To(f, "offset", p[5] + 18, p[5], Anim.SLOW * 1.5, "out") end
	end
	if spec.sonido and N.Get("inicio", "sonido") and SOUNDKIT and SOUNDKIT.RAID_WARNING then
		pcall(A.PlaySound, SOUNDKIT.RAID_WARNING, "Master")
	end
end

local function siguiente()
	if f and f:IsShown() then return end
	local spec = table.remove(cola, 1)
	if spec then pintar(spec) end
end

function Aviso.Mostrar(spec)
	if type(spec) ~= "table" then return end
	if A.Hidden() then return end
	if not f then construir() end
	if f:IsShown() and actual and actual.clave ~= spec.clave then
		for i = #cola, 1, -1 do
			if cola[i].clave == spec.clave then table.remove(cola, i) end
		end
		if spec.tipo == "peligro" then table.insert(cola, 1, spec) else cola[#cola + 1] = spec end
		while #cola > COLA_MAX do table.remove(cola) end
		return
	end
	pintar(spec)
end

function Aviso.Ocultar(todo)
	actual = nil
	if todo then
		for i = #cola, 1, -1 do cola[i] = nil end
	end
	if f and f:IsShown() then f:Hide() end
	if #cola > 0 then A.After(0.4, siguiente) end
end

function Aviso.Visible()
	return f and f:IsShown() and actual and actual.clave or nil
end

-- Un aviso de muestra (el botón de los ajustes).
function Aviso.Probar()
	Aviso.Mostrar({
		clave = "prueba", tipo = "info", icono = "house",
		titulo = L["Así se ven tus avisos"],
		linea = L["Arrástralo para moverlo"],
		texto = L["Alfa te avisa aquí de lo importante: equipo por reparar, bolsas llenas, habilidades nuevas, tu buff y tu descanso."],
	})
end

-- Ocultar Alfa quita el aviso y su cola: era noticia, no algo para después.
A.On("ALFA_HIDDEN", function(oculto)
	if oculto == true then Aviso.Ocultar(true) end
end)
