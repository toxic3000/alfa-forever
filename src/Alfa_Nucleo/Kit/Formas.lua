-- Alfa - Kit: formas del diseño A (Toxic / La Jauría). GPL-3.0.
--
-- La forma de Alfa: un rectángulo con las esquinas de arriba a la izquierda
-- y de abajo a la derecha cortadas a 45 grados, como las facetas del lobo.
--   K.Forma(marco, corte, capa, sub)        el relleno (5 texturas)
--   K.Borde(marco, corte, capa)             la línea de 1 px alrededor
--   K.Caja(marco, { fondo, borde, corte })  las dos, pintadas con tokens
--   K.Marca(marco, corte, color)            la raya de acento de 28 x 2 tras el corte
-- Las texturas son de Alfa (Media/UI/cut, cut-line*: tools/interfaz.py).

local _, N = ...
local K = N.Kit

local floor, max, abs = math.floor, math.max, math.abs
local MEDIA = "Interface\\AddOns\\Alfa\\Media\\UI\\"
local LINEAS = { 4, 6, 8, 10 } -- cut-line<n>: la diagonal de un corte de n unidades

local function lineaDeCorte(c)
	local mejor, dif = 10, 99
	for _, n in ipairs(LINEAS) do
		if abs(n - c) < dif then mejor, dif = n, abs(n - c) end
	end
	return MEDIA .. "cut-line" .. mejor
end

---------------------------------------------------------------------------
-- El relleno
---------------------------------------------------------------------------
local Forma = {}
Forma.__index = Forma

function Forma:Color(token, alfa)
	local r, g, b, a = K.Color(token)
	if alfa then a = alfa end
	for i = 1, 5 do self.partes[i]:SetVertexColor(r, g, b, a) end
end

function Forma:RGBA(r, g, b, a)
	for i = 1, 5 do self.partes[i]:SetVertexColor(r, g, b, a or 1) end
end

function Forma:SetShown(on)
	self.on = on and true or false
	local p = self.partes
	p[1]:SetShown(self.on)
	p[2]:SetShown(self.on and self.tl > 0)
	p[4]:SetShown(self.on and self.tl > 0)
	p[3]:SetShown(self.on and self.br > 0)
	p[5]:SetShown(self.on and self.br > 0)
end
function Forma:Show() self:SetShown(true) end
function Forma:Hide() self:SetShown(false) end
function Forma:IsShown() return self.on end

-- El corte de cada esquina, en unidades (0: esquina recta).
function Forma:Corte(tl, br)
	tl = max(0, floor((tl or 0) + 0.5))
	br = max(0, floor((br or tl) + 0.5))
	self.tl, self.br = tl, br
	local m, p = self.marco, self.partes
	for i = 1, 5 do p[i]:ClearAllPoints() end
	p[1]:SetPoint("TOPLEFT", m, "TOPLEFT", 0, -tl)
	p[1]:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 0, br)
	p[2]:SetPoint("TOPLEFT", m, "TOPLEFT", tl, 0)
	p[2]:SetPoint("BOTTOMRIGHT", m, "TOPRIGHT", 0, -tl)
	p[3]:SetPoint("TOPLEFT", m, "BOTTOMLEFT", 0, br)
	p[3]:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -br, 0)
	p[4]:SetPoint("TOPLEFT", m, "TOPLEFT", 0, 0)
	p[4]:SetSize(max(tl, 0.01), max(tl, 0.01))
	p[5]:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 0, 0)
	p[5]:SetSize(max(br, 0.01), max(br, 0.01))
	self:SetShown(self.on ~= false)
end

function K.Forma(marco, corte, capa, sub, dueno)
	dueno = dueno or marco
	local f = setmetatable({ marco = marco, partes = {}, on = true }, Forma)
	for i = 1, 5 do
		local t = dueno:CreateTexture(nil, capa or "BACKGROUND", nil, sub or -6)
		if i <= 3 then t:SetColorTexture(1, 1, 1, 1) else t:SetTexture(MEDIA .. "cut") end
		f.partes[i] = t
	end
	f.partes[5]:SetTexCoord(1, 0, 1, 0) -- la de abajo a la derecha es la misma, girada
	f:Corte(corte or 0)
	return f
end

---------------------------------------------------------------------------
-- La línea de 1 px (física) alrededor de la misma forma
---------------------------------------------------------------------------
local Borde = {}
Borde.__index = Borde

function Borde:Color(token, alfa)
	local r, g, b, a = K.Color(token)
	if alfa then a = alfa end
	for _, t in ipairs(self.partes) do t:SetVertexColor(r, g, b, a) end
end

function Borde:SetShown(on)
	self.on = on and true or false
	for i, t in ipairs(self.partes) do
		if i == 5 then t:SetShown(self.on and self.tl > 0)
		elseif i == 6 then t:SetShown(self.on and self.br > 0)
		else t:SetShown(self.on) end
	end
end
function Borde:Show() self:SetShown(true) end
function Borde:Hide() self:SetShown(false) end

function Borde:Corte(tl, br)
	tl = max(0, floor((tl or 0) + 0.5))
	br = max(0, floor((br or tl) + 0.5))
	self.tl, self.br = tl, br
	local m, p = self.marco, self.partes
	local px = K.Pixel(m)
	for i = 1, 6 do p[i]:ClearAllPoints() end
	-- arriba, derecha, abajo, izquierda
	p[1]:SetPoint("TOPLEFT", m, "TOPLEFT", tl, 0); p[1]:SetPoint("TOPRIGHT", m, "TOPRIGHT", 0, 0); p[1]:SetHeight(px)
	p[2]:SetPoint("TOPRIGHT", m, "TOPRIGHT", 0, -px); p[2]:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 0, br); p[2]:SetWidth(px)
	p[3]:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", 0, 0); p[3]:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -br, 0); p[3]:SetHeight(px)
	p[4]:SetPoint("TOPLEFT", m, "TOPLEFT", 0, -tl); p[4]:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", 0, px); p[4]:SetWidth(px)
	-- las diagonales
	if tl > 0 then
		p[5]:SetTexture(lineaDeCorte(tl))
		p[5]:SetTexCoord(0, 1, 0, 1)
		p[5]:SetSize(tl, tl)
		p[5]:SetPoint("TOPLEFT", m, "TOPLEFT", 0, 0)
	end
	if br > 0 then
		p[6]:SetTexture(lineaDeCorte(br))
		p[6]:SetTexCoord(1, 0, 1, 0)
		p[6]:SetSize(br, br)
		p[6]:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 0, 0)
	end
	self:SetShown(self.on ~= false)
end

function K.Borde(marco, corte, capa, dueno)
	dueno = dueno or marco
	local b = setmetatable({ marco = marco, partes = {}, on = true }, Borde)
	for i = 1, 6 do
		local t = dueno:CreateTexture(nil, capa or "BORDER", nil, 6)
		if i <= 4 then t:SetColorTexture(1, 1, 1, 1) end
		b.partes[i] = t
	end
	b:Corte(corte or 0)
	return b
end

---------------------------------------------------------------------------
-- La caja: relleno y borde pintados con tokens, que se repintan solos.
--   K.Caja(marco, { fondo = "panel", borde = "linea", corte = 8, alfa = nil })
--   caja:Estilo({ fondo, borde, alfaFondo, alfaBorde })   (cambia y repinta)
---------------------------------------------------------------------------
local Caja = {}
Caja.__index = Caja

local function pintarCaja(c)
	local e = c.estilo
	if e.fondo then
		c.fondo:Show()
		c.fondo:Color(e.fondo, e.alfaFondo)
	else
		c.fondo:Hide()
	end
	if e.borde then
		c.borde:Show()
		c.borde:Color(e.borde, e.alfaBorde)
	else
		c.borde:Hide()
	end
end

function Caja:Estilo(e)
	for k, v in pairs(e) do self.estilo[k] = v end
	if e.fondo == false then self.estilo.fondo = nil end
	if e.borde == false then self.estilo.borde = nil end
	pintarCaja(self)
end

function Caja:Corte(tl, br)
	self.fondo:Corte(tl, br)
	self.borde:Corte(tl, br)
end

function Caja:SetShown(on)
	if on then pintarCaja(self) else self.fondo:Hide() self.borde:Hide() end
end

function K.Caja(marco, opts)
	opts = opts or {}
	local c = setmetatable({ marco = marco, estilo = {} }, Caja)
	c.fondo = K.Forma(marco, opts.corte or K.CORTE.panel, "BACKGROUND", -7)
	c.borde = K.Borde(marco, opts.corte or K.CORTE.panel)
	c.estilo.fondo = opts.fondo == nil and "panel" or opts.fondo or nil
	c.estilo.borde = opts.borde == nil and "linea" or opts.borde or nil
	c.estilo.alfaFondo, c.estilo.alfaBorde = opts.alfaFondo, opts.alfaBorde
	K.Pintar(c, pintarCaja)
	return c
end

-- La marca de acento: una raya de 28 x 2 justo después del corte de arriba.
function K.Marca(marco, corte, color, ancho)
	local t = K.Plano(marco, color or "acento", "ARTWORK", 3)
	t:SetSize(ancho or 28, 2)
	t:SetPoint("TOPLEFT", marco, "TOPLEFT", (corte or K.CORTE.panel) + 6, 0)
	return t
end

-- El velo al pasar el ratón: la misma forma, blanca al 5 %.
function K.Velo(marco, corte, alfa)
	local f = K.Forma(marco, corte or K.CORTE.control, "BACKGROUND", -5)
	f:RGBA(1, 1, 1, alfa or 0.05)
	f:Hide()
	return f
end

-- Una faceta de color (la de los encabezados de sección): 4 x 14 con su corte.
function K.Faceta(padre, color, ancho, alto)
	local m = CreateFrame("Frame", nil, padre)
	m:SetSize(ancho or 4, alto or 14)
	local f = K.Forma(m, 2, "ARTWORK", 2, m)
	K.Pintar(f, function(x) x:Color(color or "acento") end)
	m.forma = f
	return m
end
