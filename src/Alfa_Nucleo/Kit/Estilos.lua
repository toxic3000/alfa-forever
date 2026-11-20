-- Alfa - Kit: elegir el estilo y el acento (toxic3000 / La Jauría). GPL-3.0.
--
--   K.SelectorEstilo(padre, opts)   los tres estilos con su muestra; un clic lo aplica
--   K.SelectorAcento(padre, opts)   los acentos de K.ACENTOS y el color de tu clase
-- Los estilos y acentos viven en Kit/Tokens.lua (K.ESTILOS, K.SetEstilo,
-- K.ACENTOS, K.SetAcento). Las dos piezas son bloques: :Acomodar(ancho) -> alto.

local _, N = ...
local K = N.Kit
local A = N.A
local L = K.L

local floor, max, min, ipairs = math.floor, math.max, math.min, ipairs
local ESP = K.ESP

---------------------------------------------------------------------------
-- La muestra de cada estilo: un trocito de ventana pintado como ese estilo,
-- se use el que se use ahora (colores fijos, no tokens).
---------------------------------------------------------------------------
local function rect(padre, capa, sub, r, g, b, a)
	local t = padre:CreateTexture(nil, capa or "ARTWORK", nil, sub or 0)
	t:SetColorTexture(r, g, b, a or 1)
	return t
end

local MUESTRA_ALTO = 72

local function muestraAlfa(m)
	local fondo = rect(m, "BACKGROUND", 0, 0.063, 0.078, 0.071)
	fondo:SetAllPoints(m)
	local panel = rect(m, "BORDER", 0, 0.094, 0.125, 0.106)
	panel:SetPoint("TOPLEFT", m, "TOPLEFT", 12, -12)
	panel:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -12, 12)
	-- la esquina cortada de arriba a la izquierda, con su marca de acento
	local corte = m:CreateTexture(nil, "BORDER", nil, 1)
	corte:SetTexture(K.Ruta("cut"))
	corte:SetVertexColor(0.063, 0.078, 0.071, 1)
	corte:SetSize(8, 8)
	corte:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	local marca = rect(m, "ARTWORK", 1, 0.545, 0.878, 0.306)
	marca:SetSize(24, 2)
	marca:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, 0)
	local l1 = rect(m, "ARTWORK", 0, 0.902, 0.937, 0.894)
	l1:SetSize(70, 5)
	l1:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -14)
	local l2 = rect(m, "ARTWORK", 0, 0.541, 0.6, 0.545)
	l2:SetSize(110, 4)
	l2:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -7)
	local boton = rect(m, "ARTWORK", 0, 0.545, 0.878, 0.306)
	boton:SetSize(36, 12)
	boton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 8)
	m.partes = { fondo, panel, corte, marca, l1, l2, boton }
end

local function muestraClasico(m)
	local fondo = m:CreateTexture(nil, "BACKGROUND", nil, 0)
	fondo:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark", true, true)
	fondo:SetAllPoints(m)
	-- El marco de los cuadros de información del juego, alrededor.
	local marco = CreateFrame("Frame", nil, m)
	marco:SetPoint("TOPLEFT", m, "TOPLEFT", 6, -6)
	marco:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -6, 6)
	m.juego = K.MarcoJuego(marco, "info")
	m.juego:Pintar({ fondo = { 0, 0, 0, 0.7 }, borde = { 0.8, 0.8, 0.8, 1 } })
	local titulo = marco:CreateFontString(nil, "OVERLAY")
	titulo:SetFont(K.LetraDelJuego(), 12, "")
	titulo:SetShadowOffset(1, -1)
	titulo:SetShadowColor(0, 0, 0, 1)
	titulo:SetTextColor(1, 0.82, 0, 1)
	titulo:SetText("Alfa")
	titulo:SetPoint("TOPLEFT", marco, "TOPLEFT", 12, -10)
	local l2 = rect(marco, "ARTWORK", 0, 0.8, 0.8, 0.8)
	l2:SetSize(100, 4)
	l2:SetPoint("TOPLEFT", titulo, "BOTTOMLEFT", 0, -7)
	-- un botón rojo del juego
	local boton = marco:CreateTexture(nil, "ARTWORK")
	boton:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
	boton:SetTexCoord(0, 0.625, 0, 0.6875)
	boton:SetSize(48, 16)
	boton:SetPoint("BOTTOMRIGHT", marco, "BOTTOMRIGHT", -8, 7)
	m.partes = { fondo, titulo, l2, boton }
end

local function muestraCristal(m)
	-- el mundo detrás: cielo y pasto
	local cielo = rect(m, "BACKGROUND", 0, 0.36, 0.52, 0.66)
	cielo:SetPoint("TOPLEFT", m, "TOPLEFT", 0, 0)
	cielo:SetPoint("BOTTOMRIGHT", m, "RIGHT", 0, 0)
	local pasto = rect(m, "BACKGROUND", 0, 0.27, 0.42, 0.22)
	pasto:SetPoint("TOPLEFT", m, "LEFT", 0, 0)
	pasto:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 0, 0)
	local panel = rect(m, "BORDER", 0, 0.063, 0.078, 0.071, 0.6)
	panel:SetPoint("TOPLEFT", m, "TOPLEFT", 12, -12)
	panel:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -12, 12)
	local borde = {}
	for i = 1, 4 do borde[i] = rect(m, "BORDER", 1, 0.9, 0.94, 0.9, 0.22) end
	borde[1]:SetPoint("TOPLEFT", panel, "TOPLEFT") borde[1]:SetPoint("TOPRIGHT", panel, "TOPRIGHT") borde[1]:SetHeight(1)
	borde[2]:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT") borde[2]:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT") borde[2]:SetHeight(1)
	borde[3]:SetPoint("TOPLEFT", panel, "TOPLEFT") borde[3]:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT") borde[3]:SetWidth(1)
	borde[4]:SetPoint("TOPRIGHT", panel, "TOPRIGHT") borde[4]:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT") borde[4]:SetWidth(1)
	local l1 = rect(m, "ARTWORK", 0, 0.95, 0.97, 0.95)
	l1:SetSize(70, 5)
	l1:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -14)
	local l2 = rect(m, "ARTWORK", 0, 0.8, 0.85, 0.8)
	l2:SetSize(110, 4)
	l2:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -7)
	-- la marca y el botón en el acento que elijas (el de Cristal)
	local marca = rect(m, "ARTWORK", 1, 1, 1, 1)
	marca:SetSize(24, 2)
	marca:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, 0)
	local boton = rect(m, "ARTWORK", 0, 1, 1, 1)
	boton:SetSize(36, 12)
	boton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 8)
	m.acento = { marca, boton }
	m.partes = { cielo, pasto, panel, l1, l2, marca, boton }
end

-- 1.3.0: La Jauría nocturno y Fogata: la casa con su esquema y su acento,
-- más una luna (nocturno) o unas brasas (fogata) en la esquina.
local function muestraCasa(fondoC, panelC, t1, t2, acento, adorno)
	return function(m)
		local fondo = rect(m, "BACKGROUND", 0, fondoC[1], fondoC[2], fondoC[3])
		fondo:SetAllPoints(m)
		local panel = rect(m, "BORDER", 0, panelC[1], panelC[2], panelC[3])
		panel:SetPoint("TOPLEFT", m, "TOPLEFT", 12, -12)
		panel:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -12, 12)
		local corte = m:CreateTexture(nil, "BORDER", nil, 1)
		corte:SetTexture(K.Ruta("cut"))
		corte:SetVertexColor(fondoC[1], fondoC[2], fondoC[3], 1)
		corte:SetSize(8, 8)
		corte:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
		local marca = rect(m, "ARTWORK", 1, acento[1], acento[2], acento[3])
		marca:SetSize(24, 2)
		marca:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, 0)
		local l1 = rect(m, "ARTWORK", 0, t1[1], t1[2], t1[3])
		l1:SetSize(70, 5)
		l1:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -14)
		local l2 = rect(m, "ARTWORK", 0, t2[1], t2[2], t2[3])
		l2:SetSize(110, 4)
		l2:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -7)
		local boton = rect(m, "ARTWORK", 0, acento[1], acento[2], acento[3])
		boton:SetSize(36, 12)
		boton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 8)
		local deco = m:CreateTexture(nil, "ARTWORK", nil, 2)
		deco:SetTexture(K.Ruta(adorno))
		deco:SetVertexColor(acento[1], acento[2], acento[3], 0.9)
		deco:SetSize(18, 18)
		deco:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
		m.partes = { fondo, panel, corte, marca, l1, l2, boton, deco }
	end
end

local MUESTRAS = { alfa = muestraAlfa, clasico = muestraClasico, cristal = muestraCristal,
	nocturno = muestraCasa({ 0.043, 0.059, 0.102 }, { 0.071, 0.094, 0.161 }, { 0.91, 0.93, 0.97 }, { 0.56, 0.6, 0.69 },
		{ 0.784, 0.827, 0.902 }, "lobo-aullando"),
	fogata = muestraCasa({ 0.082, 0.067, 0.055 }, { 0.118, 0.094, 0.078 }, { 0.95, 0.92, 0.88 }, { 0.63, 0.57, 0.51 },
		{ 1, 0.604, 0.302 }, "lobo-dormido"),
}

-- El acento que Cristal tendrá: el propio guardado para Cristal, el de ahora
-- si ya es Cristal, o el verde de La Jauría.
local function acentoDeCristal()
	if K.Cristal() then return K.Color("acento") end
	local d = N.Datos and N.Datos("kit")
	local c = d and type(d.acentos) == "table" and d.acentos.cristal
	if type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number" then return c[1], c[2], c[3] end
	local j = K.ACENTOS[1].color
	return j[1], j[2], j[3]
end

---------------------------------------------------------------------------
-- Selector de estilo
--   K.SelectorEstilo(padre, { alCambiar = fn(id), min = 220 })
--   sel:Leer() (vuelve a marcar el de ahora) ; sel:Acomodar(ancho) -> alto
---------------------------------------------------------------------------
local function pintarOpcion(o)
	local elegido = K.Estilo() == o.alfaId
	o.caja:Estilo({ fondo = "panel", borde = elegido and "acento" or (o.alfaSobre and "lineaFuerte" or "linea"),
		alfaBorde = elegido and 0.9 or nil })
	o.velo:SetShown(o.alfaSobre and not elegido and true or false)
	o.Marca:SetShown(elegido)
	K.ColorTexto(o.Nombre, elegido and "acento" or "texto")
	if o.Muestra.acento then
		local r, g, b = acentoDeCristal()
		for _, t in ipairs(o.Muestra.acento) do t:SetVertexColor(r, g, b, 1) end
	end
end

local function opcionEstilo(padre, e, sel)
	local o = CreateFrame("Button", nil, padre)
	o:RegisterForClicks("LeftButtonUp")
	o.alfaId = e.id
	o.caja = K.Caja(o, { corte = K.CORTE.tarjeta, rol = "panel" })
	o.velo = K.Velo(o, K.CORTE.tarjeta, 0.04)
	o.Muestra = CreateFrame("Frame", nil, o)
	o.Muestra:SetHeight(MUESTRA_ALTO)
	MUESTRAS[e.id](o.Muestra)
	o.Nombre = K.Texto(o, "subtitulo", "texto")
	K.Escribir(o.Nombre, L[e.nombre])
	o.Texto = K.Texto(o, "nota", "textoSuave")
	K.Escribir(o.Texto, L[e.texto])
	o.Marca = K.Icono(o, "ic-exito", 16, "acento")
	o:SetScript("OnClick", function(self)
		if K.Estilo() == self.alfaId then return end
		K.SetEstilo(self.alfaId)
		if sel.alCambiar then K.Llamar(sel.alCambiar, self.alfaId) end
	end)
	o:SetScript("OnEnter", function(self) self.alfaSobre = true pintarOpcion(self) end)
	o:SetScript("OnLeave", function(self) self.alfaSobre = nil pintarOpcion(self) end)
	function o:Acomodar(ancho, altoMin)
		local pad = ESP.base
		self:SetWidth(ancho)
		self.Muestra:ClearAllPoints()
		self.Muestra:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad)
		self.Muestra:SetWidth(ancho - 2 * pad)
		local y = pad + MUESTRA_ALTO + ESP.m
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -y)
		self.Nombre:SetWidth(ancho - 2 * pad - 24)
		self.Marca:ClearAllPoints()
		self.Marca:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, -y)
		y = y + K.AltoTexto(self.Nombre) + ESP.xs
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -y)
		y = y + K.Parrafo(self.Texto, ancho - 2 * pad, 3) + pad
		local h = max(y, altoMin or 0)
		self:SetHeight(h)
		return h
	end
	K.Pintar(o, pintarOpcion)
	return o
end

function K.SelectorEstilo(padre, opts)
	opts = opts or {}
	local sel = K.Rejilla(padre, { min = opts.min or 220, gap = ESP.base })
	sel.alCambiar = opts.alCambiar
	sel.opciones = {}
	for i, e in ipairs(K.ESTILOS) do sel.opciones[i] = opcionEstilo(sel, e, sel) end
	sel:SetElementos(sel.opciones)
	function sel:Leer() for _, o in ipairs(self.opciones) do pintarOpcion(o) end end
	return sel
end

---------------------------------------------------------------------------
-- Selector de acento: una muestra por acento (y el color de tu clase). El
-- elegido lleva su marca; el nombre del de ahora va debajo.
--   K.SelectorAcento(padre, { alCambiar = fn(id), clase = true })
--   sel:Leer() ; sel:Acomodar(ancho) -> alto
---------------------------------------------------------------------------
local MUESTRA = 32

local function deClase() return A and A.Get and A.Get("ui.classAccent") and true or false end

local function pintarMuestra(b)
	local sel = b.alfaSel
	local actual = sel.alfaActual
	local on = actual == b.alfaId
	local color = b.alfaColor
	if b.alfaId == "clase" then
		local c = K.Clase()
		color = { c.r, c.g, c.b, 1 }
	end
	b.caja:Estilo({ fondo = color, borde = on and "texto" or (b.alfaSobre and "textoSuave" or "lineaFuerte") })
	b.Marca:SetShown(on)
	b.Marca:SetVertexColor(0.05, 0.07, 0.05, 1)
end

function K.SelectorAcento(padre, opts)
	opts = opts or {}
	local sel = CreateFrame("Frame", nil, padre)
	sel.alCambiar = opts.alCambiar
	sel.muestras = {}
	local lista = {}
	for _, a in ipairs(K.ACENTOS) do lista[#lista + 1] = { id = a.id, nombre = a.nombre, color = a.color } end
	if opts.clase ~= false then lista[#lista + 1] = { id = "clase", nombre = "El color de mi clase" } end
	for i, a in ipairs(lista) do
		local b = CreateFrame("Button", nil, sel)
		b:SetSize(MUESTRA, MUESTRA)
		b:RegisterForClicks("LeftButtonUp")
		b.alfaSel, b.alfaId, b.alfaColor = sel, a.id, a.color
		b.caja = K.Caja(b, { corte = K.CORTE.chico })
		b.Marca = b:CreateTexture(nil, "OVERLAY")
		b.Marca:SetTexture(K.Ruta("ic-exito"))
		b.Marca:SetSize(16, 16)
		b.Marca:SetPoint("CENTER")
		K.ConInfo(b, L[a.nombre])
		b:SetScript("OnClick", function(self)
			if self.alfaId == "clase" then
				if A and A.Set then A.Set("ui.classAccent", true) end
			else
				K.SetAcento(self.alfaId)
			end
			sel:Leer()
			if sel.alCambiar then K.Llamar(sel.alCambiar, self.alfaId) end
		end)
		b:SetScript("OnEnter", function(self) self.alfaSobre = true pintarMuestra(self) end)
		b:SetScript("OnLeave", function(self) self.alfaSobre = nil pintarMuestra(self) end)
		K.Pintar(b, pintarMuestra)
		sel.muestras[i] = b
	end
	sel.Nombre = K.Texto(sel, "pequeno", "textoSuave")
	function sel:Leer()
		self.alfaActual = deClase() and "clase" or K.AcentoActual()
		local nombre
		for _, b in ipairs(self.muestras) do
			pintarMuestra(b)
			if b.alfaId == self.alfaActual then
				for _, a in ipairs(lista) do if a.id == b.alfaId then nombre = L[a.nombre] end end
			end
		end
		K.Escribir(self.Nombre, nombre and (L["Acento: %s"]):format(nombre) or L["Acento propio (elegido en Ajustes)"])
	end
	function sel:Acomodar(ancho)
		local gap = ESP.s
		local x, y = 0, 0
		for _, b in ipairs(self.muestras) do
			if x > 0 and x + MUESTRA > ancho then x, y = 0, y + MUESTRA + gap end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			x = x + MUESTRA + gap
		end
		y = y + MUESTRA + ESP.s
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		y = y + 16
		self:SetSize(ancho, y)
		return y
	end
	-- Un acento elegido en otra parte (Ajustes, otro selector) se marca al repintar.
	K.Pintar(sel, function(x) x:Leer() end)
	return sel
end
