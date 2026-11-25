-- Alfa - Bienvenida: el fondo del Escritorio de Alfa, una noche (1.4.0).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Detrás de los paneles: el cielo azul de noche (de arriba más oscuro), sus
-- estrellas siempre en el mismo lugar, la luna con su halo, unas colinas con
-- niebla y el lobo aullando, tenue. Las texturas son las de la intro
-- (Media/intro-*.tga). Todo es fijo (nada se mueve: no gasta nada) y se
-- acomoda cuando el escritorio cambia de tamaño. Con «Fondo del escritorio»
-- apagado no se ve (Escritorio.lua lo pinta).

local _, M = ...
local N = AlfaNucleo
local K = N.Kit
local Es = M.Escritorio

local floor = math.floor
local MEDIA = "Interface\\AddOns\\Alfa_Bienvenida\\Media\\"
local ESTRELLAS = 90

local function azarDe(semilla)
	return function()
		semilla = (semilla * 1103515245 + 12345) % 2147483648
		return semilla / 2147483648
	end
end

local function textura(f, capa, sub, archivo, aditiva)
	local t = f:CreateTexture(nil, capa, nil, sub)
	t:SetTexture(archivo and (MEDIA .. archivo) or K.Ruta("white"))
	if aditiva and t.SetBlendMode then t:SetBlendMode("ADD") end
	return t
end

-- Las colinas: { x, y (desde abajo), ancho, alto (fracciones), color }
local COLINAS = {
	{ 0.18, -0.10, 0.75, 0.55, { 0.050, 0.068, 0.078 } },
	{ 0.78, -0.14, 0.90, 0.62, { 0.042, 0.058, 0.068 } },
	{ 0.50, -0.30, 1.30, 0.66, { 0.030, 0.042, 0.050 } },
}

function Es.ArmarCielo(c)
	c.Cielo = textura(c, "BACKGROUND", -8)
	c.Cielo:SetAllPoints(c)
	c.Bruma = textura(c, "BACKGROUND", -7)
	c.Bruma:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	c.Bruma:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
	local azar = azarDe(1408)
	c.Estrellas = {}
	for i = 1, ESTRELLAS do
		c.Estrellas[i] = { tex = textura(c, "BACKGROUND", -6, "intro-estrella", true),
			x = azar(), y = azar() * 0.62, tam = 3 + floor(azar() * azar() * 9), a = 0.18 + azar() * 0.5 }
	end
	c.HaloLuna = textura(c, "BACKGROUND", -5, "intro-halo", true)
	c.Luna = textura(c, "BACKGROUND", -4, "intro-luna")
	c.Colinas = {}
	for i, h in ipairs(COLINAS) do c.Colinas[i] = { tex = textura(c, "BACKGROUND", -3, "intro-halo"), d = h } end
	c.Lobo = textura(c, "BACKGROUND", -2)
	c.Lobo:SetTexture(K.Lobo("aullando"))
	c:SetScript("OnSizeChanged", function(self) Es.AcomodarCielo(self) end)
	Es.AcomodarCielo(c)
end

-- Cada pieza en su lugar (fracciones del tamaño del escritorio).
function Es.AcomodarCielo(c)
	if not (c and c.Cielo) then return end
	local w, h = K.num(c:GetWidth(), 0), K.num(c:GetHeight(), 0)
	if w <= 0 or h <= 0 then return end
	local u = math.min(w, h)
	for _, e in ipairs(c.Estrellas) do
		e.tex:ClearAllPoints()
		e.tex:SetPoint("CENTER", c, "TOPLEFT", e.x * w, -e.y * h)
		e.tex:SetSize(e.tam, e.tam)
	end
	local lx, ly = w * 0.83, h * 0.17
	c.Luna:ClearAllPoints()
	c.Luna:SetPoint("CENTER", c, "TOPLEFT", lx, -ly)
	c.Luna:SetSize(u * 0.11, u * 0.11)
	c.HaloLuna:ClearAllPoints()
	c.HaloLuna:SetPoint("CENTER", c.Luna, "CENTER", 0, 0)
	c.HaloLuna:SetSize(u * 0.55, u * 0.55)
	for _, x in ipairs(c.Colinas) do
		local d = x.d
		x.tex:ClearAllPoints()
		x.tex:SetPoint("CENTER", c, "BOTTOMLEFT", d[1] * w, d[2] * h + d[4] * h * 0.5)
		x.tex:SetSize(d[3] * w, d[4] * h * 1.6)
	end
	c.Bruma:SetHeight(h * 0.45)
	c.Lobo:ClearAllPoints()
	c.Lobo:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -w * 0.05, h * 0.06)
	c.Lobo:SetSize(u * 0.36, u * 0.36)
end

-- Los colores (al cambiar el estilo de Alfa): la noche es la misma; el
-- brillo de las estrellas, la bruma y el lobo toman el acento del estilo.
function Es.PintarCielo(c)
	if not (c and c.Cielo) then return end
	local r, g, b = K.Color(K.Clasico() and "oro" or "acento")
	if c.Cielo.SetGradient and CreateColor then
		c.Cielo:SetGradient("VERTICAL", CreateColor(0.085, 0.11, 0.14, 1), CreateColor(0.035, 0.05, 0.09, 1))
		c.Bruma:SetGradient("VERTICAL", CreateColor(r, g, b, 0.05), CreateColor(r, g, b, 0))
	else
		c.Cielo:SetVertexColor(0.04, 0.055, 0.08, 1)
		c.Bruma:SetVertexColor(r, g, b, 0.03)
	end
	for _, e in ipairs(c.Estrellas) do e.tex:SetVertexColor(0.85, 0.9, 1, e.a) end
	c.Luna:SetVertexColor(0.86, 0.9, 0.95, 0.55)
	c.HaloLuna:SetVertexColor(0.55, 0.65, 0.8, 0.12)
	for _, x in ipairs(c.Colinas) do x.tex:SetVertexColor(x.d[5][1], x.d[5][2], x.d[5][3], 1) end
	c.Lobo:SetVertexColor(r, g, b, 0.09)
end
