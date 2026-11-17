-- Alfa - Kit: formas del diseño A (Toxic / La Jauría). GPL-3.0.
--
-- La forma de Alfa: un rectángulo con las esquinas de arriba a la izquierda
-- y de abajo a la derecha cortadas a 45 grados, como las facetas del lobo.
--   K.Forma(marco, corte, capa, sub)        el relleno (5 texturas)
--   K.Borde(marco, corte, capa)             la línea de 1 px alrededor
--   K.Caja(marco, { fondo, borde, corte })  las dos, pintadas con tokens
--   K.Marca(marco, corte, color)            la raya de acento de 28 x 2 tras el corte
-- Las texturas son de Alfa (Media/UI/cut, cut-line*: tools/interfaz.py).
--
-- Estilos (Kit/Tokens.lua, K.Estilo): en Clásico WoW las esquinas son rectas,
-- la marca y la faceta no se ven y las cajas de ventana y de panel llevan los
-- marcos del propio juego (K.MarcoJuego): el del cuadro de diálogo en las
-- ventanas y el de los cuadros de información en paneles y tarjetas, con sus
-- fondos. En Cristal los colores ya traen su transparencia (el tema).

local _, N = ...
local K = N.Kit

local floor, max, abs, pairs = math.floor, math.max, math.abs, pairs
local MEDIA = "Interface\\AddOns\\Alfa\\Media\\UI\\"
local LINEAS = { 4, 6, 8, 10 } -- cut-line<n>: la diagonal de un corte de n unidades

-- Las formas y bordes vivos: al cambiar de estilo se cortan otra vez (en
-- Clásico WoW, rectas).
local cortables = setmetatable({}, { __mode = "k" })
local estiloCortado

local function corteEfectivo(tl, br)
	if K.Clasico() then return 0, 0 end
	return tl, br
end

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

-- El corte de cada esquina, en unidades (0: esquina recta). En Clásico WoW
-- se recuerda y la forma queda recta.
function Forma:Corte(tl, br)
	tl = max(0, floor((tl or 0) + 0.5))
	br = max(0, floor((br or tl) + 0.5))
	self.baseTl, self.baseBr = tl, br
	tl, br = corteEfectivo(tl, br)
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
	cortables[f] = true
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
	self.baseTl, self.baseBr = tl, br
	tl, br = corteEfectivo(tl, br)
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
	cortables[b] = true
	return b
end

-- Un cambio de estilo corta de nuevo cada forma y borde (antes de repintar).
local function recortar()
	local e = K.Estilo()
	if e == estiloCortado then return end
	estiloCortado = e
	for x in pairs(cortables) do
		if x.baseTl then x:Corte(x.baseTl, x.baseBr) end
	end
end
estiloCortado = K.Estilo()
K.AntesDeRepintar(recortar)

---------------------------------------------------------------------------
-- El marco del juego (Clásico WoW): las nueve piezas de un "backdrop" del
-- cliente, armadas como BackdropTemplateMixin (Blizzard_SharedXML/Backdrop.lua
-- de la rama forever de referencia/): esquinas de borde x borde, los bordes
-- repetidos entre ellas y el fondo repetido dentro de sus márgenes. Las piezas
-- son texturas del propio marco (fondo en BACKGROUND, bordes en BORDER), así
-- que nada queda encima de su contenido. Las texturas son del juego:
--   dialogo  BACKDROP_DARK_DIALOG_32_32 (los cuadros de diálogo)
--   info     el de los cuadros de información (GameTooltip), borde de 16
--   K.MarcoJuego(marco, "dialogo" | "info") -> marco del juego
--   mj:Pintar({ fondo, borde, alfaFondo, alfaBorde }) ; mj:Show() ; mj:Hide()
---------------------------------------------------------------------------
local MARCOS = {
	dialogo = { borde = "Interface\\DialogFrame\\UI-DialogBox-Border", fondo = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		tam = 32, baldosa = 32, izq = 11, der = 12, arriba = 12, abajo = 11, propio = true },
	info = { borde = "Interface\\Tooltips\\UI-Tooltip-Border", fondo = "Interface\\Tooltips\\UI-Tooltip-Background",
		tam = 16, baldosa = 16, izq = 4, der = 4, arriba = 4, abajo = 4 },
}
K.MARCOS = MARCOS

-- La tira del borde: ocho piezas en fila (izquierda, derecha, arriba, abajo y
-- las cuatro esquinas), con medio texel de margen arriba y abajo.
local C0 = 0.0625
local ESQUINA = {
	{ "TOPLEFT", 0.5078125, 0.6171875 }, { "TOPRIGHT", 0.6328125, 0.7421875 },
	{ "BOTTOMLEFT", 0.7578125, 0.8671875 }, { "BOTTOMRIGHT", 0.8828125, 0.9921875 },
}
local BORDES = { 1, 2, 3, 4, "izq", "der", "arriba", "abajo" }

local MarcoJuego = {}
MarcoJuego.__index = MarcoJuego

-- Cuántas veces se repite cada borde y el fondo (como SetupTextureCoordinates).
function MarcoJuego:Coordenadas()
	local m, s, p = self.marco, self.spec, self.partes
	local w, h = K.num(m:GetWidth(), 0), K.num(m:GetHeight(), 0)
	local esc = K.num(m.GetEffectiveScale and m:GetEffectiveScale(), 1)
	local rx = max(0, (w / s.tam) * esc - 2 - C0)
	local ry = max(0, (h / s.tam) * esc - 2 - C0)
	p.izq:SetTexCoord(0.0078125, 0.1171875, C0, ry)
	p.der:SetTexCoord(0.1328125, 0.2421875, C0, ry)
	p.arriba:SetTexCoord(0.2578125, rx, 0.3671875, rx, 0.2578125, C0, 0.3671875, C0)
	p.abajo:SetTexCoord(0.3828125, rx, 0.4921875, rx, 0.3828125, C0, 0.4921875, C0)
	p.centro:SetTexCoord(0, max(0.01, w / s.baldosa * esc), 0, max(0.01, h / s.baldosa * esc))
end

function MarcoJuego:Tipo(tipo)
	if self.tipo == tipo then return end
	local s = MARCOS[tipo] or MARCOS.info
	self.tipo, self.spec = tipo, s
	local m, p = self.marco, self.partes
	for i, e in ipairs(ESQUINA) do
		local t = p[i]
		t:SetTexture(s.borde, true, true)
		t:SetTexCoord(e[2], e[3], C0, 1 - C0)
		t:SetSize(s.tam, s.tam)
		t:ClearAllPoints()
		t:SetPoint(e[1], m, e[1], 0, 0)
	end
	for _, k in ipairs({ "izq", "der", "arriba", "abajo" }) do p[k]:SetTexture(s.borde, true, true) end
	p.arriba:ClearAllPoints()
	p.arriba:SetPoint("TOPLEFT", p[1], "TOPRIGHT", 0, 0)
	p.arriba:SetPoint("BOTTOMRIGHT", p[2], "BOTTOMLEFT", 0, 0)
	p.abajo:ClearAllPoints()
	p.abajo:SetPoint("TOPLEFT", p[3], "TOPRIGHT", 0, 0)
	p.abajo:SetPoint("BOTTOMRIGHT", p[4], "BOTTOMLEFT", 0, 0)
	p.izq:ClearAllPoints()
	p.izq:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT", 0, 0)
	p.izq:SetPoint("BOTTOMRIGHT", p[3], "TOPRIGHT", 0, 0)
	p.der:ClearAllPoints()
	p.der:SetPoint("TOPLEFT", p[2], "BOTTOMLEFT", 0, 0)
	p.der:SetPoint("BOTTOMRIGHT", p[4], "TOPRIGHT", 0, 0)
	p.centro:SetTexture(s.fondo, true, true)
	p.centro:ClearAllPoints()
	p.centro:SetPoint("TOPLEFT", m, "TOPLEFT", s.izq, -s.arriba)
	p.centro:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -s.der, s.abajo)
	self:Coordenadas()
end

-- El fondo y el borde con los tokens de la caja. El cuadro de diálogo
-- conserva su arte tal cual; solo un borde de acento lo tiñe.
function MarcoJuego:Pintar(e)
	local p, propio = self.partes, self.spec.propio
	self.conFondo, self.conBorde = e.fondo ~= nil, e.borde ~= nil
	if e.fondo then
		local r, g, b, a = K.Color(e.fondo)
		if e.alfaFondo then a = e.alfaFondo end
		if propio then r, g, b = 1, 1, 1 end
		p.centro:SetVertexColor(r, g, b, a)
	end
	local r, g, b, a = 1, 1, 1, 1
	if e.borde and not (propio and e.borde ~= "acento") then
		r, g, b, a = K.Color(e.borde)
		if e.alfaBorde then a = e.alfaBorde end
	end
	for _, k in ipairs(BORDES) do p[k]:SetVertexColor(r, g, b, a) end
	self:SetShown(self.on)
	if self.on then self:Coordenadas() end
end

function MarcoJuego:SetShown(on)
	self.on = on and true or false
	local p = self.partes
	p.centro:SetShown(self.on and self.conFondo ~= false)
	for _, k in ipairs(BORDES) do p[k]:SetShown(self.on and self.conBorde ~= false) end
end
function MarcoJuego:Show() self:SetShown(true) end
function MarcoJuego:Hide() self:SetShown(false) end

function K.MarcoJuego(marco, tipo)
	local mj = setmetatable({ marco = marco, partes = {}, on = true }, MarcoJuego)
	local p = mj.partes
	for i = 1, 4 do p[i] = marco:CreateTexture(nil, "BORDER", nil, 5) end
	for _, k in ipairs({ "izq", "der", "arriba", "abajo" }) do p[k] = marco:CreateTexture(nil, "BORDER", nil, 4) end
	p.centro = marco:CreateTexture(nil, "BACKGROUND", nil, -8)
	mj:Tipo(tipo or "info")
	if marco.HookScript then
		marco:HookScript("OnSizeChanged", function() if mj.on then mj:Coordenadas() end end)
	end
	return mj
end

---------------------------------------------------------------------------
-- La caja: relleno y borde pintados con tokens, que se repintan solos.
--   K.Caja(marco, { fondo = "panel", borde = "linea", corte = 8, rol = nil })
--   caja:Estilo({ fondo, borde, alfaFondo, alfaBorde })   (cambia y repinta)
-- rol: "ventana", "panel" o "control" (por omisión sale del corte: 10 o más
-- es ventana, 8 panel, menos control). En Clásico WoW la ventana lleva el
-- marco del cuadro de diálogo y el panel el de los cuadros de información; un
-- control conserva sus colores, con esquinas rectas.
---------------------------------------------------------------------------
local Caja = {}
Caja.__index = Caja

local function rolDe(opts)
	if opts.rol then return opts.rol end
	local c = opts.corte or K.CORTE.panel
	if c >= K.CORTE.ventana then return "ventana" end
	if c >= K.CORTE.panel then return "panel" end
	return "control"
end

local JUEGO = { ventana = "dialogo", panel = "info" }

local function pintarCaja(c)
	local e = c.estilo
	local tipo = K.Clasico() and JUEGO[c.rol]
	if tipo then
		c.fondo:Hide()
		c.borde:Hide()
		c.juego = c.juego or K.MarcoJuego(c.marco, tipo)
		c.juego:Tipo(tipo)
		c.juego.on = c.on ~= false
		c.juego:Pintar(e)
		return
	end
	if c.juego then c.juego:Hide() end
	if c.on == false then return end
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

-- Lo que se pasa cambia; un alfa que no se pasa junto a su color (fondo o
-- borde) vuelve al del token (no se queda el de antes).
function Caja:Estilo(e)
	local est = self.estilo
	for k, v in pairs(e) do est[k] = v end
	if e.fondo ~= nil or e.alfaFondo ~= nil then est.alfaFondo = e.alfaFondo or nil end
	if e.borde ~= nil or e.alfaBorde ~= nil then est.alfaBorde = e.alfaBorde or nil end
	if e.fondo == false then est.fondo = nil end
	if e.borde == false then est.borde = nil end
	pintarCaja(self)
end

function Caja:Corte(tl, br)
	self.fondo:Corte(tl, br)
	self.borde:Corte(tl, br)
end

function Caja:SetShown(on)
	self.on = on and true or false
	if on then
		pintarCaja(self)
	else
		self.fondo:Hide()
		self.borde:Hide()
		if self.juego then self.juego:Hide() end
	end
end

function K.Caja(marco, opts)
	opts = opts or {}
	local c = setmetatable({ marco = marco, estilo = {}, rol = rolDe(opts) }, Caja)
	c.fondo = K.Forma(marco, opts.corte or K.CORTE.panel, "BACKGROUND", -7)
	c.borde = K.Borde(marco, opts.corte or K.CORTE.panel)
	c.estilo.fondo = opts.fondo == nil and "panel" or opts.fondo or nil
	c.estilo.borde = opts.borde == nil and "linea" or opts.borde or nil
	c.estilo.alfaFondo, c.estilo.alfaBorde = opts.alfaFondo, opts.alfaBorde
	K.Pintar(c, pintarCaja)
	return c
end

-- Lo propio del diseño A que en Clásico WoW no va (la marca de acento, la
-- franja de una tarjeta, la faceta de una sección): queda transparente, sin
-- tocar si se muestra o no.
function K.SoloCasa(region)
	local x = { region }
	region.alfaSoloCasa = x -- la tabla vive mientras viva la región (K.Pintar es débil)
	K.Pintar(x, function(y) y[1]:SetAlpha(K.Clasico() and 0 or 1) end)
	return region
end

-- La marca de acento: una raya de 28 x 2 justo después del corte de arriba.
function K.Marca(marco, corte, color, ancho)
	local t = K.Plano(marco, color or "acento", "ARTWORK", 3)
	t:SetSize(ancho or 28, 2)
	t:SetPoint("TOPLEFT", marco, "TOPLEFT", (corte or K.CORTE.panel) + 6, 0)
	return K.SoloCasa(t)
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
	K.SoloCasa(m)
	return m
end
