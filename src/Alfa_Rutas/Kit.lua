-- Alfa - Rutas: piezas de interfaz hechas con el kit del motor (A.Widgets y
-- A.Theme), para que la página se vea como el resto de Alfa: pestañas
-- propias, una lista virtual (solo dibuja las filas visibles), campos de
-- texto, nodos y líneas del árbol. Toxic / La Jauría. GPL-3.0.

local ADDON, M = ...
local A, L = M.A, M.L
local W, Th = M.W, M.T
local K = {}
M.Kit = K

local type, ipairs, pairs = type, ipairs, pairs
local floor, max, min = math.floor, math.max, math.min
local num = M.num

local BLANCO = Th.Media("white")

function K.Texto(parent, rol, color, envolver)
	local fs = W.Text(parent, rol or "body", color or "text")
	if envolver then
		fs:SetWordWrap(true)
		fs:SetJustifyV("TOP")
	end
	return fs
end

function K.Ancho(fs)
	return num(fs and fs.GetStringWidth and fs:GetStringWidth(), 0)
end

function K.Alto(fs)
	return num(fs and fs.GetStringHeight and fs:GetStringHeight(), 0)
end

-- Un color "r, g, b" para una región que no sigue la paleta.
function K.Tinte(region, r, g, b, a)
	if W.Uncolor then W.Uncolor(region) end
	if region.GetObjectType and region:GetObjectType() == "Texture" then
		region:SetVertexColor(r, g, b, a or 1)
	else
		region:SetTextColor(r, g, b, a or 1)
	end
end

-- Texto con el color de una calidad del juego.
function K.ColorCalidad(fs, calidad)
	local Cp = M.Motor("Compat")
	local hex = Cp and Cp.ItemQualityHex and Cp.ItemQualityHex(calidad)
	if type(hex) == "string" and #hex == 8 then
		local r, g, b = tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), tonumber(hex:sub(7, 8), 16)
		if r then return K.Tinte(fs, r / 255, g / 255, b / 255) end
	end
	W.Color(fs, "text")
end

function K.Fondo(parent, color, alfa)
	local t = parent:CreateTexture(nil, "BACKGROUND", nil, -6)
	t:SetTexture(BLANCO)
	t:SetAllPoints(parent)
	W.Color(t, color or "panelAlt", alfa)
	return t
end

-- Una línea recta entre dos puntos de `parent` (y hacia abajo negativo).
function K.Linea(parent, grosor)
	local l = parent:CreateLine(nil, "ARTWORK")
	l:SetColorTexture(1, 1, 1, 1)
	l:SetThickness(grosor or 2)
	return l
end

function K.Trazar(l, parent, x1, y1, x2, y2)
	l:ClearAllPoints()
	l:SetStartPoint("TOPLEFT", parent, x1, y1)
	l:SetEndPoint("TOPLEFT", parent, x2, y2)
	l:Show()
end

-- Un nodo del árbol: un círculo del color de su rama con su ícono encima.
function K.Nodo(parent, tam)
	tam = tam or 24
	local n = CreateFrame("Frame", nil, parent)
	n:SetSize(tam, tam)
	n.Halo = n:CreateTexture(nil, "BACKGROUND")
	n.Halo:SetTexture(Th.Media("glow"))
	n.Halo:SetSize(tam * 2.2, tam * 2.2)
	n.Halo:SetPoint("CENTER", n, "CENTER", 0, 0)
	n.Circulo = n:CreateTexture(nil, "ARTWORK")
	n.Circulo:SetTexture(Th.Media("circle"))
	n.Circulo:SetAllPoints(n)
	n.Icono = n:CreateTexture(nil, "OVERLAY")
	n.Icono:SetSize(tam * 0.55, tam * 0.55)
	n.Icono:SetPoint("CENTER", n, "CENTER", 0, 0)
	function n.Pintar(self, icono, r, g, b, apagado, hecho)
		self.Icono:SetTexture(Th.Media(Th.Icon(hecho and "check" or icono)))
		local a = apagado and 0.45 or 1
		self.Circulo:SetVertexColor(r, g, b, a)
		self.Halo:SetVertexColor(r, g, b, apagado and 0 or 0.35)
		self.Icono:SetVertexColor(0.06, 0.07, 0.1, 1)
	end
	return n
end

---------------------------------------------------------------------------
-- Pestañas: una fila de pestañas con la raya de acento bajo la elegida
---------------------------------------------------------------------------

function K.Pestanas(parent, items, alElegir)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(32)
	f.botones = {}
	local regla = W.Divider(f)
	regla:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	regla:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	local x = 0
	for i, it in ipairs(items) do
		local b = CreateFrame("Button", nil, f)
		b:SetHeight(32)
		b.Label = W.Text(b, "label", "textDim")
		b.Label:SetPoint("CENTER", b, "CENTER", it.icono and 9 or 0, 0)
		b.Label:SetText(it.texto)
		if it.icono then
			b.Icono = b:CreateTexture(nil, "ARTWORK")
			b.Icono:SetTexture(Th.Media(Th.Icon(it.icono)))
			b.Icono:SetSize(14, 14)
			b.Icono:SetPoint("RIGHT", b.Label, "LEFT", -6, 0)
			W.Color(b.Icono, "textDim")
		end
		Th.Skin(b, "tab")
		local ancho = floor(K.Ancho(b.Label) + (it.icono and 44 or 28) + 0.5)
		b:SetWidth(max(64, ancho))
		b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 0)
		x = x + max(64, ancho) + 4
		b.clave = it.clave
		b.psTip = it.tip
		b:SetScript("OnClick", function(self) alElegir(self.clave) end)
		b:SetScript("OnEnter", W.SimpleTip)
		b:SetScript("OnLeave", W.HideTip)
		f.botones[i] = b
	end
	function f.Marcar(self, clave)
		for _, b in ipairs(self.botones) do
			local on = b.clave == clave
			Th.SetTabSelected(b, on)
			W.Color(b.Label, on and "text" or "textDim")
			if b.Icono then W.Color(b.Icono, on and "accent" or "textDim") end
		end
	end
	return f
end

---------------------------------------------------------------------------
-- Campo de texto editable (el CopyBox del motor no deja escribir)
---------------------------------------------------------------------------

function K.Entrada(parent, ayuda, alCambiar)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetHeight(28)
	e:SetAutoFocus(false)
	e:SetTextInsets(10, 10, 0, 0)
	e:SetMaxLetters(8000)
	Th.Font(e, "label")
	W.Color(e, "text")
	Th.Skin(e, "editbox")
	e.Ayuda = W.Text(e, "label", "textMuted")
	e.Ayuda:SetPoint("LEFT", e, "LEFT", 10, 0)
	e.Ayuda:SetPoint("RIGHT", e, "RIGHT", -10, 0)
	e.Ayuda:SetText(ayuda or "")
	e:SetScript("OnEditFocusGained", function(self) Th.SetFocused(self, true) end)
	e:SetScript("OnEditFocusLost", function(self) Th.SetFocused(self, false) end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		if self.alEnter then self.alEnter(self:GetText() or "") end
	end)
	e:SetScript("OnTextChanged", function(self)
		local t = self:GetText() or ""
		self.Ayuda:SetShown(t == "")
		if alCambiar then alCambiar(t) end
	end)
	return e
end

---------------------------------------------------------------------------
-- Lista virtual: crea solo las filas que caben y las vuelve a pintar al
-- desplazarse (miles de objetos sin miles de marcos).
--   lista = K.Lista(parent, altoFila, fabricar(lista, k) -> fila, pintar(fila, i))
--   lista:Datos(n), lista:Refrescar(), lista:Mover(delta), lista:IrA(i)
---------------------------------------------------------------------------

local function pulgarArrastre(barra)
	local l = barra.lista
	local _, y = GetCursorPosition()
	local escala = num(barra:GetEffectiveScale(), 1)
	local alto = num(barra:GetHeight(), 1)
	local top = num(barra:GetTop(), 0)
	local frac = (top - y / escala) / max(1, alto)
	local vis = l:Visibles()
	local maxInicio = max(1, l.n - vis + 1)
	l.inicio = max(1, min(maxInicio, floor(frac * maxInicio + 0.5)))
	l:Refrescar()
end

function K.Lista(parent, altoFila, fabricar, pintar)
	local f = CreateFrame("Frame", nil, parent)
	f.alto, f.n, f.inicio, f.filas = altoFila, 0, 1, {}
	f.fabricar, f.pintar = fabricar, pintar
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(self, delta) self:Mover(-num(delta, 0) * 3) end)
	local barra = CreateFrame("Button", nil, f)
	barra:SetWidth(8)
	barra:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	barra:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	barra.lista = f
	barra.Pulgar = barra:CreateTexture(nil, "OVERLAY")
	barra.Pulgar:SetTexture(BLANCO)
	barra.Pulgar:SetWidth(3)
	W.Painter(barra.Pulgar, function(t) t:SetVertexColor(Th.Wash("thumb")) end)
	barra:SetScript("OnMouseDown", function(self) self:SetScript("OnUpdate", pulgarArrastre) end)
	barra:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
	barra:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
	f.Barra = barra
	f:SetScript("OnSizeChanged", function(self) self:Refrescar() end)

	function f.Visibles(self)
		return max(1, floor(num(self:GetHeight(), self.alto) / self.alto))
	end

	function f.Datos(self, n)
		self.n = n or 0
		local maxInicio = max(1, self.n - self:Visibles() + 1)
		if self.inicio > maxInicio then self.inicio = maxInicio end
		if self.inicio < 1 then self.inicio = 1 end
		self:Refrescar()
	end

	function f.Refrescar(self)
		local vis = self:Visibles()
		for k = 1, vis do
			local fila = self.filas[k]
			if not fila then
				fila = self.fabricar(self, k)
				fila:SetHeight(self.alto)
				self.filas[k] = fila
			end
			fila:ClearAllPoints()
			fila:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(k - 1) * self.alto)
			fila:SetPoint("RIGHT", self, "RIGHT", -12, 0)
			local i = self.inicio + k - 1
			if i <= self.n then
				fila.indice = i
				self.pintar(fila, i)
				fila:Show()
			else
				fila.indice = nil
				fila:Hide()
			end
		end
		for k = vis + 1, #self.filas do self.filas[k]:Hide() end
		local b = self.Barra
		if self.n <= vis then
			b:Hide()
		else
			b:Show()
			local alto = num(self:GetHeight(), 100)
			local h = max(20, alto * vis / self.n)
			local maxInicio = max(1, self.n - vis + 1)
			local y = (alto - h) * ((self.inicio - 1) / max(1, maxInicio - 1))
			b.Pulgar:SetHeight(h)
			b.Pulgar:ClearAllPoints()
			b.Pulgar:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -y)
		end
	end

	function f.Mover(self, d)
		local maxInicio = max(1, self.n - self:Visibles() + 1)
		self.inicio = max(1, min(maxInicio, self.inicio + floor(d)))
		self:Refrescar()
	end

	function f.IrA(self, i)
		local vis = self:Visibles()
		if i < self.inicio then self.inicio = i
		elseif i > self.inicio + vis - 1 then self.inicio = i - vis + 1 end
		self:Datos(self.n)
	end

	return f
end

---------------------------------------------------------------------------
-- Una fila de lista con fondo al pasar y al elegir
---------------------------------------------------------------------------

function K.Fila(parent)
	local b = CreateFrame("Button", nil, parent)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.Elegida = b:CreateTexture(nil, "BACKGROUND", nil, -5)
	b.Elegida:SetTexture(BLANCO)
	b.Elegida:SetAllPoints(b)
	W.Painter(b.Elegida, function(t) t:SetVertexColor(Th.Wash("selected")) end)
	b.Elegida:Hide()
	W.Hover(b)
	return b
end

-- Un botón con menú: el texto y una flecha abajo.
function K.BotonMenu(parent, texto, alAbrir, ancho)
	local b = W.Button(parent, texto, function(self) alAbrir(self) end, { width = ancho, icon = "chevron-down" })
	return b
end

-- Un menú del motor bajo un botón. items: { texto, onClick, checked, disabled, tip, icon } o { separator = true }
function K.Menu(ancla, items, ancho)
	local lista = {}
	for i, it in ipairs(items) do
		if it.separator then
			lista[i] = { separator = true }
		else
			lista[i] = { text = it.texto, onClick = it.onClick, checked = it.checked, disabled = it.disabled, tip = it.tip, icon = it.icon }
		end
	end
	W.ShowMenu(ancla, lista, { point = "TOPLEFT", relPoint = "BOTTOMLEFT", y = -4, minWidth = ancho })
end

function K.Aviso(texto)
	if A.Print then A.Print(texto) end
end
