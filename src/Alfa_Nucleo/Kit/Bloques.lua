-- Alfa - Kit: bloques de página (toxic3000 / La Jauría). GPL-3.0.
--
-- Un bloque es un marco con :Acomodar(ancho) -> alto. Las plantillas
-- (Kit/Plantillas.lua) los apilan con márgenes y ritmo fijos.
--   K.Pila(padre, opts)               apila bloques hacia abajo
--   K.Encabezado(padre, opts)         ícono, título, subtítulo y acciones
--   K.Seccion(padre, titulo, opts)    encabezado de sección con su faceta
--   K.Tarjeta(padre, opts)            accion | normal | compacta | estado
--   K.Rejilla(padre, opts)            tarjetas en columnas según el ancho
--   K.Lista(padre, opts)              lista virtual (solo las filas a la vista)
--   K.Vacio(padre, opts)              estado vacío con el lobo
--   K.FilaAjuste / K.GrupoAjustes     filas de ajustes sobre un panel

local _, N = ...
local K = N.Kit
local L = K.L

local floor, ceil, max, min, type, ipairs = math.floor, math.ceil, math.max, math.min, type, ipairs
local ESP = K.ESP

-- Pone `hijo` dentro de `padre` (si no lo estaba) y lo sube de nivel para que
-- no quede debajo del fondo de su nuevo padre. Mejor aún: crear cada pieza
-- con su padre final (K.Seccion(pila, ...), grupo:Fila{ control = fn }).
function K.Adoptar(hijo, padre)
	if not (hijo and padre) then return hijo end
	if hijo:GetParent() ~= padre then hijo:SetParent(padre) end
	local nivel = K.num(padre:GetFrameLevel(), 0) + 1
	if K.num(hijo:GetFrameLevel(), 0) < nivel then hijo:SetFrameLevel(nivel) end
	return hijo
end

---------------------------------------------------------------------------
-- Pila: bloques uno bajo otro.
--   pila:Agregar(bloque, { espacio = 16 (antes), sangria = 0 })
--   pila:Acomodar(ancho) -> alto   (los bloques ocultos no cuentan)
---------------------------------------------------------------------------
function K.Pila(padre, opts)
	opts = opts or {}
	local p = CreateFrame("Frame", nil, padre)
	p.bloques = {}
	p.alfaEspacio = opts.espacio or ESP.base
	function p:Agregar(b, o)
		o = o or {}
		self.bloques[#self.bloques + 1] = { b = b, espacio = o.espacio, sangria = o.sangria or 0 }
		if b.GetParent and b:GetParent() ~= self then K.Adoptar(b, self) end
		return b
	end
	function p:Vaciar()
		for _, e in ipairs(self.bloques) do e.b:Hide() end
		self.bloques = {}
	end
	function p:Acomodar(ancho)
		local y, primero = 0, true
		for _, e in ipairs(self.bloques) do
			local b = e.b
			if b:IsShown() and not b.alfaOculto then
				if not primero then y = y + (e.espacio or self.alfaEspacio) end
				primero = false
				local h = b.Acomodar and b:Acomodar(ancho - e.sangria) or K.num(b:GetHeight(), 0)
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", self, "TOPLEFT", e.sangria, -y)
				if not b.alfaAnchoPropio then b:SetWidth(ancho - e.sangria) end
				y = y + K.num(h, 0)
			end
		end
		self:SetSize(ancho, max(1, y))
		return y
	end
	return p
end

-- Muestra u oculta un bloque dentro de una pila (sin dejar su hueco).
function K.Mostrar(b, on)
	b.alfaOculto = not on
	b:SetShown(on and true or false)
end

---------------------------------------------------------------------------
-- Encabezado de página o ventana
--   opts = { icono, titulo, subtitulo, sobre (sobretítulo), tono = "acento" }
--   enc:Set(opts), enc:Acciones({ boton, boton... }) a la derecha
---------------------------------------------------------------------------
function K.Encabezado(padre, opts)
	local e = CreateFrame("Frame", nil, padre)
	e.Baldosa = CreateFrame("Frame", nil, e)
	e.Baldosa:SetSize(44, 44)
	e.Baldosa:SetPoint("TOPLEFT", e, "TOPLEFT", 0, 0)
	e.Baldosa.caja = K.Caja(e.Baldosa, { fondo = "elevado", borde = "linea", corte = K.CORTE.control })
	e.Icono = K.Icono(e.Baldosa, "ic-lobo", 24, "acento")
	e.Icono:SetPoint("CENTER")
	e.Sobre = K.Texto(e, "mayus", "acento")
	e.Titulo = K.Texto(e, "titulo", "texto")
	e.Subtitulo = K.Texto(e, "nota", "textoSuave")
	e.acciones = {}
	function e:Set(o)
		o = o or {}
		self.alfaDatos = o
		K.Mostrar(self.Baldosa, o.icono ~= nil)
		if o.icono then K.SetIcono(self.Icono, o.icono, o.tono or "acento") end
		K.Escribir(self.Sobre, o.sobre and K.Mayus(o.sobre) or "")
		K.Escribir(self.Titulo, o.titulo or "")
		K.Escribir(self.Subtitulo, o.subtitulo or "")
	end
	function e:Acciones(lista) self.acciones = lista or {} for _, b in ipairs(self.acciones) do K.Adoptar(b, self) end end
	function e:Acomodar(ancho)
		local conBaldosa = self.Baldosa:IsShown()
		local x = conBaldosa and 44 + ESP.base or 0
		local derecha = 0
		for i = #self.acciones, 1, -1 do
			local b = self.acciones[i]
			if b:IsShown() then
				b:ClearAllPoints()
				b:SetPoint("TOPRIGHT", self, "TOPRIGHT", -derecha, -6)
				derecha = derecha + K.num(b:GetWidth(), 0) + ESP.s
			end
		end
		local tw = max(80, ancho - x - derecha)
		-- Primero se mide, luego se coloca: junto a la baldosa, el texto queda
		-- centrado con ella.
		local conSobre = (self.Sobre:GetText() or "") ~= ""
		local conSub = (self.Subtitulo:GetText() or "") ~= ""
		self.Sobre:SetWidth(tw)
		self.Titulo:SetWidth(tw)
		local hs = conSobre and (K.AltoTexto(self.Sobre) + 2) or 0
		local ht = K.AltoTexto(self.Titulo)
		local hsub = conSub and (4 + K.Parrafo(self.Subtitulo, tw, 2)) or 0
		local total = hs + ht + hsub
		local y = conBaldosa and max(0, floor((44 - total) / 2)) or 0
		self.Sobre:SetShown(conSobre)
		self.Sobre:ClearAllPoints()
		self.Sobre:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
		y = y + hs
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
		y = y + ht
		self.Subtitulo:SetShown(conSub)
		self.Subtitulo:ClearAllPoints()
		self.Subtitulo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(y + 4))
		y = y + hsub
		local alto = max(conBaldosa and 44 or 0, y)
		self:SetHeight(alto)
		return alto
	end
	e:Set(opts)
	return e
end

---------------------------------------------------------------------------
-- Sección: una faceta de acento, el título, una cuenta y un enlace a la derecha.
--   opts = { cuenta, enlace = { texto, alClic } }
---------------------------------------------------------------------------
function K.Seccion(padre, titulo, opts)
	opts = opts or {}
	local s = CreateFrame("Frame", nil, padre)
	s:SetHeight(K.ALTO.seccion)
	s.Faceta = K.Faceta(s, "acento", 4, 14)
	s.Faceta:SetPoint("LEFT", s, "LEFT", 0, 0)
	s.Titulo = K.Texto(s, "encabezado", "texto")
	s.Titulo:SetPoint("LEFT", s, "LEFT", 12, 0)
	s.Cuenta = K.Texto(s, "numero", "textoTenue")
	s.Cuenta:SetPoint("LEFT", s.Titulo, "RIGHT", 8, 0)
	s.Linea = K.Linea(s, "linea")
	function s:Set(t, o)
		o = o or {}
		K.Escribir(self.Titulo, t or "")
		self.Cuenta:SetText(o.cuenta ~= nil and tostring(o.cuenta) or "")
		if o.enlace then
			if not self.Enlace then self.Enlace = K.Boton(self, "", nil, { tipo = "fantasma", tam = "chico" }) end
			self.Enlace:SetTexto(o.enlace.texto)
			self.Enlace.alClic = o.enlace.alClic
			K.SeguroDe(self.Enlace, o.enlace)
			self.Enlace:Show()
		elseif self.Enlace then
			self.Enlace:Hide()
		end
	end
	function s:Acomodar(ancho)
		local derecha = 0
		if self.Enlace and self.Enlace:IsShown() then
			self.Enlace:ClearAllPoints()
			self.Enlace:SetPoint("RIGHT", self, "RIGHT", 0, 0)
			derecha = K.num(self.Enlace:GetWidth(), 0) + ESP.m
		end
		-- El título no se mete debajo del enlace ni de la cuenta (un enlace
		-- ancho, como "Abrir la ventana del juego", pasa de 120).
		local cw = K.Ajustar(self.Cuenta)
		cw = (self.Cuenta:GetText() or "") ~= "" and (cw + 8) or 0
		K.Ajustar(self.Titulo, max(40, ancho - max(120, derecha + cw + ESP.m)))
		self.Linea:ClearAllPoints()
		local ancla = (self.Cuenta:GetText() or "") ~= "" and self.Cuenta or self.Titulo
		self.Linea:SetPoint("LEFT", ancla, "RIGHT", ESP.m, 0)
		self.Linea:SetPoint("RIGHT", self, "RIGHT", -derecha, 0)
		return K.ALTO.seccion
	end
	s:Set(titulo, opts)
	return s
end

---------------------------------------------------------------------------
-- Tarjeta
--   K.Tarjeta(padre, { variante = "accion" | "normal" | "compacta" | "estado" })
--   tarjeta:Set({
--     icono = "ic-ruta", lobo = "atento" (en vez de ícono), tono = "acento",
--     sobre = "RECOMENDADO", titulo, texto, valor (compacta: a la derecha),
--     insignias = { { texto, tono, icono } }, estado = { texto, tono } (estado),
--     progreso = { actual, total, texto, huellas = true },
--     accion = { texto, alClic, icono }, secundaria = { texto, alClic },
--     alClic = fn (toda la tarjeta), ayuda = "texto del cuadro de información",
--     elegida = true (la opción marcada de un grupo: borde de acento),
--     tenir = false (el ícono con sus colores: uno de hechizo u objeto del juego),
--   })
--   tarjeta:Acomodar(ancho, altoMinimo) -> alto
---------------------------------------------------------------------------
local VARIANTE = {
	accion = { baldosa = 64, icono = 34, pad = ESP.l, titulo = "titulo", texto = "texto", lineas = 6, corte = K.CORTE.tarjeta },
	normal = { baldosa = 40, icono = 22, pad = ESP.base, titulo = "subtitulo", texto = "nota", lineas = 6, corte = K.CORTE.tarjeta },
	compacta = { baldosa = 28, icono = 16, pad = ESP.m, titulo = "cuerpo", texto = "pequeno", lineas = 1, corte = K.CORTE.control },
	estado = { baldosa = 56, icono = 30, pad = ESP.l, titulo = "titulo", texto = "texto", lineas = 8, corte = K.CORTE.tarjeta },
}

local function pintarTarjeta(c)
	local d = c.alfaDatos or {}
	local v = c.alfaVariante
	local relleno = K.Tono(d.tono or "acento")
	local sobre = c.alfaSobre and d.alClic
	-- elegida: la opción marcada de un grupo de tarjetas (un asistente), con borde de acento.
	c.caja:Estilo({ fondo = "panel", borde = d.elegida and "acento" or (sobre and "lineaFuerte" or "linea"), alfaBorde = d.elegida and 0.9 or false })
	c.velo:SetShown(sobre and true or false)
	c.Baldosa.caja:Estilo({ fondo = (v == "accion" or v == "estado") and relleno or "elevado", alfaFondo = (v == "accion" or v == "estado") and 0.14 or nil,
		borde = (v == "accion" or v == "estado") and relleno or "linea", alfaBorde = (v == "accion" or v == "estado") and 0.4 or nil })
	if c.Franja then K.ColorPlano(c.Franja, relleno) end
	if c.Marca then K.ColorPlano(c.Marca, relleno) end
end

local function insignia(c, i)
	c.insignias[i] = c.insignias[i] or K.Insignia(c, "", "neutro")
	return c.insignias[i]
end

function K.Tarjeta(padre, opts)
	opts = opts or {}
	local v = VARIANTE[opts.variante or "normal"] and (opts.variante or "normal") or "normal"
	local cfg = VARIANTE[v]
	local c = CreateFrame("Button", nil, padre)
	c.alfaVariante = v
	c:RegisterForClicks("LeftButtonUp")
	c.caja = K.Caja(c, { corte = cfg.corte, rol = "panel" })
	c.velo = K.Velo(c, cfg.corte, 0.035)
	if v == "accion" or v == "estado" then
		c.Franja = K.Plano(c, "acento", "ARTWORK", 1)
		c.Franja:SetWidth(3)
		c.Franja:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -cfg.corte - 4)
		c.Franja:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, cfg.corte + 4)
		K.SoloCasa(c.Franja)
		c.Marca = K.Marca(c, cfg.corte, "acento")
	end
	c.Baldosa = CreateFrame("Frame", nil, c)
	c.Baldosa:SetSize(cfg.baldosa, cfg.baldosa)
	c.Baldosa.caja = K.Caja(c.Baldosa, { corte = v == "compacta" and K.CORTE.chico or K.CORTE.control })
	c.Icono = K.Icono(c.Baldosa, "ic-lobo", cfg.icono, "acento")
	c.Icono:SetPoint("CENTER")
	c.Sobre = K.Texto(c, "mayus", "acento")
	c.Titulo = K.Texto(c, cfg.titulo, "texto")
	c.Texto = K.Texto(c, cfg.texto, "textoSuave")
	c.Valor = K.Texto(c, "numero", "texto")
	c.Valor:SetJustifyH("RIGHT")
	c.insignias = {}
	c:SetScript("OnClick", function(self)
		local d = self.alfaDatos
		if d and d.alClic then K.Llamar(d.alClic, self) end
	end)
	c:SetScript("OnEnter", function(self) self.alfaSobre = true pintarTarjeta(self) end)
	c:SetScript("OnLeave", function(self) self.alfaSobre = nil pintarTarjeta(self) end)

	function c:Set(d)
		d = d or {}
		self.alfaDatos = d
		local relleno, texto = K.Tono(d.tono or "acento")
		if d.lobo then
			self.Icono:SetTexture(K.Lobo(d.lobo))
			self.Icono.alfaColor = relleno
			self.Icono:SetVertexColor(K.Color(relleno))
		else
			local color = (v == "compacta" or v == "normal") and (d.tono and relleno or "acento") or relleno
			if d.tenir == false then color = nil end
			K.SetIcono(self.Icono, d.icono or "ic-lobo", color)
		end
		-- Un ícono del juego (un número o una ruta) sin su marco gris de los bordes.
		local delJuego = d.tenir == false and not d.lobo and (type(d.icono) == "number" or (type(d.icono) == "string" and d.icono:find("\\", 1, true) ~= nil))
		if delJuego then self.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92) else self.Icono:SetTexCoord(0, 1, 0, 1) end
		K.Mostrar(self.Baldosa, (d.icono or d.lobo) ~= nil)
		K.Escribir(self.Sobre, d.sobre and K.Mayus(d.sobre) or "")
		K.ColorTexto(self.Sobre, texto)
		K.Escribir(self.Titulo, d.titulo or "")
		K.Escribir(self.Texto, d.texto or "")
		K.Escribir(self.Valor, d.valor ~= nil and tostring(d.valor) or "")
		local lista = d.insignias or {}
		if d.estado then lista = { { d.estado.texto, d.estado.tono, d.estado.icono } } end
		for i, x in ipairs(lista) do insignia(self, i):Set(x[1] or x.texto, x[2] or x.tono, x[3] or x.icono) end
		for i = #lista + 1, #self.insignias do self.insignias[i]:Hide() end
		self.alfaInsignias = #lista
		if d.progreso then
			local p = d.progreso
			if p.huellas then
				self.Huellas = self.Huellas or K.Huellas(self, { tam = 14 })
				self.Huellas:Set(p.actual, p.total)
				self.Huellas:Show()
				if self.Barra then self.Barra:Hide() end
			else
				self.Barra = self.Barra or K.Progreso(self, { alto = 6 })
				self.Barra:Set(p.actual, p.total)
				self.Barra:SetTono(d.tono or "acento")
				self.Barra:Show()
				if self.Huellas then self.Huellas:Hide() end
			end
			self.TextoBarra = self.TextoBarra or K.Texto(self, "pequeno", "textoTenue")
			K.Escribir(self.TextoBarra, p.texto or "")
			self.TextoBarra:Show()
		else
			if self.Huellas then self.Huellas:Hide() end
			if self.Barra then self.Barra:Hide() end
			if self.TextoBarra then self.TextoBarra:Hide() end
		end
		if d.accion then
			self.Accion = self.Accion or K.Boton(self, "", nil, { tipo = "primario", tam = v == "accion" and "grande" or "normal", conIcono = true })
			self.Accion:SetTexto(d.accion.texto)
			self.Accion:SetIcono(d.accion.icono)
			self.Accion.alClic = d.accion.alClic
			K.SeguroDe(self.Accion, d.accion)
			self.Accion:Show()
		elseif self.Accion then
			self.Accion:Hide()
		end
		if d.secundaria then
			self.Secundaria = self.Secundaria or K.Boton(self, "", nil, { tipo = "fantasma", tam = v == "accion" and "normal" or "chico" })
			self.Secundaria:SetTexto(d.secundaria.texto)
			self.Secundaria.alClic = d.secundaria.alClic
			K.SeguroDe(self.Secundaria, d.secundaria)
			self.Secundaria:Show()
		elseif self.Secundaria then
			self.Secundaria:Hide()
		end
		if d.ayuda then K.ConInfo(self, d.titulo, d.ayuda) elseif self.alfaInfo then self.alfaInfo = { nil, nil } end
		pintarTarjeta(self)
	end

	-- -> alto
	function c:Acomodar(ancho, altoMin)
		local d = self.alfaDatos or {}
		local pad = cfg.pad
		local conBaldosa = self.Baldosa:IsShown()
		local x = pad + (conBaldosa and (cfg.baldosa + (v == "compacta" and ESP.m or ESP.base)) or 0)
		if self.Franja then x = x + 2 end
		self:SetWidth(ancho)
		if v == "compacta" then
			local alto = max(K.ALTO.compacta, altoMin or 0)
			self.Baldosa:ClearAllPoints()
			self.Baldosa:SetPoint("LEFT", self, "LEFT", pad, 0)
			local vw = (self.Valor:GetText() or "") ~= "" and (K.Ajustar(self.Valor, 120) + ESP.m) or 0
			self.Valor:ClearAllPoints()
			self.Valor:SetPoint("RIGHT", self, "RIGHT", -pad, 0)
			local tw = max(40, ancho - x - pad - vw)
			local conTexto = (self.Texto:GetText() or "") ~= ""
			self.Titulo:ClearAllPoints()
			self.Titulo:SetWidth(tw)
			self.Titulo:SetPoint("LEFT", self, "LEFT", x, conTexto and 7 or 0)
			self.Texto:ClearAllPoints()
			self.Texto:SetWidth(tw)
			self.Texto:SetWordWrap(false)
			self.Texto:SetPoint("TOPLEFT", self.Titulo, "BOTTOMLEFT", 0, -2)
			self.Sobre:Hide()
			for i = 1, #self.insignias do self.insignias[i]:Hide() end
			self:SetHeight(alto)
			return alto
		end
		self.Sobre:SetShown((self.Sobre:GetText() or "") ~= "")
		-- Botones: a la derecha en una tarjeta ancha (accion, estado), abajo en una angosta.
		local botones = {}
		if self.Accion and self.Accion:IsShown() then botones[#botones + 1] = self.Accion end
		if self.Secundaria and self.Secundaria:IsShown() then botones[#botones + 1] = self.Secundaria end
		local bw = 0
		for _, b in ipairs(botones) do bw = max(bw, b:AnchoNatural()) end
		local lado = (v == "accion" or v == "estado") and #botones > 0 and ancho >= 560
		local derecha = lado and (bw + ESP.l) or 0
		local tw = max(60, ancho - x - pad - derecha)
		local y = pad
		self.Baldosa:ClearAllPoints()
		self.Baldosa:SetPoint("TOPLEFT", self, "TOPLEFT", pad + (self.Franja and 2 or 0), -pad)
		if self.Sobre:IsShown() then
			self.Sobre:ClearAllPoints()
			self.Sobre:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			self.Sobre:SetWidth(tw)
			y = y + K.AltoTexto(self.Sobre) + 4
		end
		-- El título, con la insignia de estado a su lado en la tarjeta de estado.
		local estadoAlLado = v == "estado" and self.alfaInsignias == 1
		local iw = estadoAlLado and K.num(self.insignias[1]:GetWidth(), 0) + ESP.s or 0
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
		self.Titulo:SetWordWrap(true)
		self.Titulo:SetWidth(max(40, tw - iw))
		if estadoAlLado then
			local real = min(K.AnchoTexto(self.Titulo), tw - iw)
			self.Titulo:SetWidth(max(40, real + 1))
			self.insignias[1]:ClearAllPoints()
			self.insignias[1]:SetPoint("LEFT", self.Titulo, "RIGHT", ESP.s, 0)
		end
		y = y + K.AltoTexto(self.Titulo)
		if (self.Texto:GetText() or "") ~= "" then
			y = y + (v == "accion" and 6 or 4)
			self.Texto:ClearAllPoints()
			self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			y = y + K.Parrafo(self.Texto, tw, d.lineas or cfg.lineas)
			self.Texto:Show()
		else
			self.Texto:Hide()
		end
		-- Las insignias en fila (no la de estado, que va junto al título).
		if self.alfaInsignias > 0 and not estadoAlLado then
			y = y + ESP.s
			local ix, iy = x, y
			for i = 1, self.alfaInsignias do
				local ch = self.insignias[i]
				local w = K.num(ch:GetWidth(), 0)
				if ix > x and ix + w > x + tw then ix, iy = x, iy + K.ALTO.insignia + 6 end
				ch:ClearAllPoints()
				ch:SetPoint("TOPLEFT", self, "TOPLEFT", ix, -iy)
				ix = ix + w + 6
			end
			y = iy + K.ALTO.insignia
		end
		-- El avance.
		if d.progreso then
			y = y + ESP.m
			local tb = self.TextoBarra
			-- El texto va junto a la barra si cabe; si es largo, en su propio
			-- renglón debajo, completo (nunca cortado con "…").
			local tiene = (tb:GetText() or "") ~= ""
			tb:SetWordWrap(false)
			local mide = tiene and K.Ajustar(tb) or 0
			local alLado = tiene and mide <= floor(tw * 0.5)
			local tbw = alLado and (mide + ESP.m) or 0
			if self.Huellas and self.Huellas:IsShown() then
				local _, hh = self.Huellas:Acomodar()
				self.Huellas:ClearAllPoints()
				self.Huellas:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
				tb:ClearAllPoints()
				tb:SetPoint("LEFT", self.Huellas, "RIGHT", ESP.m, 0)
				y = y + hh
			else
				self.Barra:ClearAllPoints()
				self.Barra:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(y + 5))
				self.Barra:Acomodar(max(40, tw - tbw))
				tb:ClearAllPoints()
				if alLado or not tiene then
					tb:SetPoint("LEFT", self.Barra, "RIGHT", ESP.m, 0)
					y = y + 16
				else
					tb:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(y + 16))
					y = y + 16 + K.Parrafo(tb, tw) + 2
				end
			end
		end
		local abajo = y
		local baldosaAbajo = conBaldosa and (pad + cfg.baldosa) or 0
		abajo = max(abajo, baldosaAbajo)
		-- Botones.
		if #botones > 0 then
			if lado then
				local by = pad
				for _, b in ipairs(botones) do
					b:SetAncho(bw)
					b:ClearAllPoints()
					b:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, -by)
					by = by + K.num(b:GetHeight(), 32) + ESP.s
				end
				abajo = max(abajo, by - ESP.s)
			else
				local bx = x
				abajo = abajo + ESP.base
				-- En una fila de rejilla (altoMin), los botones van al pie de la
				-- tarjeta: así quedan a la misma altura en todas las de la fila.
				local bh = K.num(botones[1]:GetHeight(), 32)
				if altoMin and altoMin > abajo + bh + pad then abajo = altoMin - pad - bh end
				for _, b in ipairs(botones) do
					b:SetAncho(nil)
					b:ClearAllPoints()
					b:SetPoint("TOPLEFT", self, "TOPLEFT", bx, -abajo)
					bx = bx + b:AnchoNatural() + ESP.s
				end
				abajo = abajo + K.num(botones[1]:GetHeight(), 32)
			end
		end
		local alto = max(abajo + pad, altoMin or 0)
		self:SetHeight(alto)
		return alto
	end

	K.Pintar(c, pintarTarjeta)
	c:Set(opts)
	return c
end

---------------------------------------------------------------------------
-- Rejilla: tarjetas en tantas columnas como quepan (al menos `min` de ancho
-- cada una); cada fila toma el alto de su tarjeta más alta.
--   opts = { min = 256, gap = 16, variante = "normal" }
--   rej:Llenar(datos)        crea o reutiliza una tarjeta por dato (tarjeta:Set)
--   rej:SetElementos(lista)  o pone bloques propios (con :Acomodar(ancho, altoMin))
--   rej:Acomodar(ancho) -> alto ; rej:Columnas(ancho) -> n
---------------------------------------------------------------------------
function K.Rejilla(padre, opts)
	opts = opts or {}
	local r = CreateFrame("Frame", nil, padre)
	r.alfaMin, r.alfaGap, r.alfaVariante = opts.min or K.ANCHO.tarjeta, opts.gap or ESP.base, opts.variante or "normal"
	r.pool, r.elementos = {}, {}
	function r:Llenar(datos)
		datos = datos or {}
		for i, d in ipairs(datos) do
			local t = self.pool[i]
			if not t then
				t = K.Tarjeta(self, { variante = d.variante or self.alfaVariante })
				self.pool[i] = t
			end
			t:Set(d)
			t:Show()
		end
		for i = #datos + 1, #self.pool do self.pool[i]:Hide() end
		self.elementos = {}
		for i = 1, #datos do self.elementos[i] = self.pool[i] end
	end
	function r:SetElementos(lista) self.elementos = lista or {} end
	function r:Columnas(ancho)
		return max(1, floor((ancho + self.alfaGap) / (self.alfaMin + self.alfaGap)))
	end
	function r:Acomodar(ancho)
		local cols = min(self:Columnas(ancho), max(1, #self.elementos))
		local gap = self.alfaGap
		local cw = floor((ancho - gap * (cols - 1)) / cols)
		local y, i = 0, 1
		local n = #self.elementos
		while i <= n do
			local alto = 0
			for c = 0, cols - 1 do
				local e = self.elementos[i + c]
				if e then alto = max(alto, e:Acomodar(cw)) end
			end
			for c = 0, cols - 1 do
				local e = self.elementos[i + c]
				if e then
					e:Acomodar(cw, alto)
					e:ClearAllPoints()
					e:SetPoint("TOPLEFT", self, "TOPLEFT", c * (cw + gap), -y)
					e:Show()
				end
			end
			y = y + alto + gap
			i = i + cols
		end
		local total = n > 0 and y - gap or 0
		self:SetSize(ancho, max(1, total))
		return total
	end
	return r
end

---------------------------------------------------------------------------
-- Lista virtual: solo existen las filas que se ven (se reutilizan al
-- desplazarse), así que aguanta miles de datos.
--   opts = { alto = 36, crear = fn(fila), pintar = fn(fila, dato, i, elegida),
--            alClic = fn(dato, i, boton), elegir = true, vacio = { titulo, texto, lobo } }
--   lista:SetDatos(t), lista:Elegir(i), lista:Elegida() -> i, dato,
--   lista:IrA(i), lista:Refrescar(), lista:Acomodar(ancho, alto) -> alto
---------------------------------------------------------------------------
local function pintarFila(f)
	local l = f.alfaLista
	local on = l.alfaElegir ~= false and f.alfaI ~= nil and f.alfaI == l.alfaElegida
	f.Fondo:SetShown(on or (f.alfaSobre and not f.alfaInerte and true or false))
	f.Fondo:SetColorTexture(1, 1, 1, 1)
	if on then f.Fondo:SetVertexColor(K.Color("elevado")) else f.Fondo:SetVertexColor(1, 1, 1, 0.04) end
	f.Barra:SetShown(on)
end

local function filaDe(l, i)
	local f = l.filas[i]
	if f then return f end
	f = CreateFrame("Button", nil, l.Area)
	f.alfaLista = l
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f.Fondo = f:CreateTexture(nil, "BACKGROUND")
	f.Fondo:SetAllPoints(f)
	f.Barra = K.Plano(f, "acento", "ARTWORK", 3)
	f.Barra:SetWidth(2)
	f.Barra:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -4)
	f.Barra:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 4)
	if l.alfaCrear then K.Llamar(l.alfaCrear, f) end
	f:SetScript("OnClick", function(self, boton)
		local lista = self.alfaLista
		-- El índice y el dato se toman antes de elegir: Elegir puede desplazar la
		-- lista y esta fila pasar a mostrar otra.
		local i = self.alfaI
		if not i then return end
		local dato = lista.datos[i]
		if lista.alfaElegir ~= false and boton == "LeftButton" then lista:Elegir(i) end
		if lista.alClic then K.Llamar(lista.alClic, dato, i, boton) end
	end)
	f:SetScript("OnEnter", function(self) self.alfaSobre = true pintarFila(self) if self.alfaLista.alEntrar then K.Llamar(self.alfaLista.alEntrar, self, self.alfaLista.datos[self.alfaI]) end end)
	f:SetScript("OnLeave", function(self) self.alfaSobre = nil pintarFila(self) K.OcultarInfo(self) end)
	f:SetScript("OnMouseWheel", function(self, d) self.alfaLista:Desplazar(-d * 3 * self.alfaLista.alfaAlto) end)
	f:EnableMouseWheel(true)
	l.filas[i] = f
	return f
end

function K.Lista(padre, opts)
	opts = opts or {}
	local l = CreateFrame("Frame", nil, padre)
	l.alfaAlto = opts.alto or K.ALTO.fila
	l.alfaCrear, l.alfaPintar, l.alClic, l.alfaElegir, l.alEntrar = opts.crear, opts.pintar, opts.alClic, opts.elegir, opts.alEntrar
	l.datos, l.filas, l.alfaPos = {}, {}, 0
	l.Area = CreateFrame("Frame", nil, l)
	l.Area:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 0)
	l.Area:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", -10, 0)
	l.Area:SetClipsChildren(true)
	l:EnableMouseWheel(true)
	l:SetScript("OnMouseWheel", function(self, d) self:Desplazar(-d * 3 * self.alfaAlto) end)
	-- La barra de desplazamiento: una pista fina y su pulgar facetado.
	local barra = CreateFrame("Slider", nil, l)
	l.BarraDesp = barra
	barra:SetOrientation("VERTICAL")
	barra:SetWidth(6)
	barra:SetPoint("TOPRIGHT", l, "TOPRIGHT", 0, 0)
	barra:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", 0, 0)
	barra:SetMinMaxValues(0, 1)
	barra:SetValueStep(1)
	barra.Pista = K.Plano(barra, "hundido", "BACKGROUND", 0)
	barra.Pista:SetAllPoints(barra)
	barra:SetThumbTexture(K.Ruta("knob"))
	local pulgar = barra.GetThumbTexture and barra:GetThumbTexture()
	if pulgar then
		pulgar:SetSize(6, 28)
		K.Pintar(pulgar, function(t) t:SetVertexColor(K.Color("lineaFuerte")) end)
	end
	barra:SetScript("OnValueChanged", function(_, v)
		if l.alfaQuieto then return end
		l.alfaPos = v
		l:Refrescar()
	end)
	barra:Hide()
	if opts.vacio then
		l.Vacio = K.Vacio(l, opts.vacio)
		l.Vacio:Hide()
	end

	function l:Rango() return max(0, #self.datos * self.alfaAlto - K.num(self.Area:GetHeight(), 0)) end
	function l:Desplazar(d) self:IrAPos(self.alfaPos + d) end
	function l:IrAPos(p)
		self.alfaPos = max(0, min(self:Rango(), floor(p + 0.5)))
		self.alfaQuieto = true
		self.BarraDesp:SetValue(self.alfaPos)
		self.alfaQuieto = nil
		self:Refrescar()
	end
	function l:IrA(i)
		local top = (i - 1) * self.alfaAlto
		local h = K.num(self.Area:GetHeight(), 0)
		if top < self.alfaPos then self:IrAPos(top)
		elseif top + self.alfaAlto > self.alfaPos + h then self:IrAPos(top + self.alfaAlto - h) end
	end
	function l:SetDatos(t, conservar)
		self.datos = t or {}
		if not conservar then self.alfaElegida = nil self.alfaPos = 0 end
		self:Acomodar()
	end
	function l:Elegir(i)
		self.alfaElegida = i
		self:Refrescar()
		if i then self:IrA(i) end
		if self.alElegir then K.Llamar(self.alElegir, self.datos[i], i) end
	end
	function l:Elegida() return self.alfaElegida, self.alfaElegida and self.datos[self.alfaElegida] end
	function l:Refrescar()
		local alto = self.alfaAlto
		local h = K.num(self.Area:GetHeight(), 0)
		local w = K.num(self.Area:GetWidth(), 0)
		local primero = floor(self.alfaPos / alto) + 1
		local cuantas = ceil(h / alto) + 1
		local desfase = self.alfaPos % alto
		for k = 1, cuantas do
			local i = primero + k - 1
			local f = filaDe(self, k)
			local dato = self.datos[i]
			if dato ~= nil then
				f.alfaI = i
				f:SetSize(w, alto)
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", self.Area, "TOPLEFT", 0, -((k - 1) * alto - desfase))
				if self.alfaPintar then K.Llamar(self.alfaPintar, f, dato, i, i == self.alfaElegida) end
				pintarFila(f)
				f:Show()
			else
				f.alfaI = nil
				f:Hide()
			end
		end
		for k = cuantas + 1, #self.filas do self.filas[k].alfaI = nil self.filas[k]:Hide() end
		if self.Vacio then
			local vacio = #self.datos == 0
			self.Vacio:SetShown(vacio)
			if vacio then
				local vh = self.Vacio:Acomodar(max(160, w - 32))
				self.Vacio:ClearAllPoints()
				self.Vacio:SetPoint("TOP", self.Area, "TOP", 0, -max(16, floor((h - vh) / 2)))
			end
		end
	end
	function l:Acomodar(ancho, alto)
		if ancho then self:SetWidth(ancho) end
		if alto then self:SetHeight(alto) end
		local rango = self:Rango()
		self.BarraDesp:SetShown(rango > 0)
		self.Area:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", rango > 0 and -10 or 0, 0)
		self.BarraDesp:SetMinMaxValues(0, max(1, rango))
		self.alfaPos = min(self.alfaPos, rango)
		self.alfaQuieto = true
		self.BarraDesp:SetValue(self.alfaPos)
		self.alfaQuieto = nil
		self:Refrescar()
		return K.num(self:GetHeight(), 0)
	end
	return l
end

---------------------------------------------------------------------------
-- Estado vacío: el lobo, un título, un texto y, si sirve, un botón.
--   opts = { lobo = "dormido", titulo, texto, accion = { texto, alClic, icono } }
---------------------------------------------------------------------------
function K.Vacio(padre, opts)
	local v = CreateFrame("Frame", nil, padre)
	v.Lobo = v:CreateTexture(nil, "ARTWORK")
	v.Lobo:SetSize(72, 72)
	v.Titulo = K.Texto(v, "subtitulo", "texto")
	v.Titulo:SetJustifyH("CENTER")
	v.Texto = K.Texto(v, "nota", "textoSuave")
	v.Texto:SetJustifyH("CENTER")
	function v:Set(o)
		o = o or {}
		self.alfaDatos = o
		self.Lobo:SetTexture(K.Lobo(o.lobo or "dormido"))
		self.Lobo:SetVertexColor(K.Color(o.lobo == "atento" and "acento" or (o.lobo == "aullando" and "acento" or "textoTenue")))
		K.Escribir(self.Titulo, o.titulo or "")
		K.Escribir(self.Texto, o.texto or "")
		if o.accion then
			self.Accion = self.Accion or K.Boton(self, "", nil, { tipo = "secundario", conIcono = true })
			self.Accion:SetTexto(o.accion.texto)
			self.Accion:SetIcono(o.accion.icono)
			self.Accion.alClic = o.accion.alClic
			K.SeguroDe(self.Accion, o.accion)
			self.Accion:Show()
		elseif self.Accion then
			self.Accion:Hide()
		end
	end
	function v:Acomodar(ancho)
		local w = min(ancho, 440)
		local y = 0
		self.Lobo:ClearAllPoints()
		self.Lobo:SetPoint("TOP", self, "TOP", 0, 0)
		y = 72 + ESP.base
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOP", self, "TOP", 0, -y)
		self.Titulo:SetWidth(w)
		y = y + K.AltoTexto(self.Titulo)
		if (self.Texto:GetText() or "") ~= "" then
			y = y + 6
			self.Texto:ClearAllPoints()
			self.Texto:SetPoint("TOP", self, "TOP", 0, -y)
			y = y + K.Parrafo(self.Texto, w)
		end
		if self.Accion and self.Accion:IsShown() then
			y = y + ESP.base
			self.Accion:ClearAllPoints()
			self.Accion:SetPoint("TOP", self, "TOP", 0, -y)
			y = y + K.num(self.Accion:GetHeight(), 32)
		end
		self:SetSize(ancho, y)
		return y
	end
	v:Set(opts)
	return v
end

---------------------------------------------------------------------------
-- Filas de ajustes: el nombre, su descripción y el control a la derecha,
-- sobre un panel (como los menús de Ajustes, con las piezas del Kit).
--   K.FilaAjuste(padre, { titulo, texto, control, hija = true, activa = fn() -> bool })
--     control: una función fn(fila) -> control (se crea dentro de la fila, lo
--     mejor) o un control ya hecho (se adopta).
--   K.GrupoAjustes(padre, { titulo })
--     grupo:Fila(opts) -> fila (la crea en el grupo) ; grupo:Agregar(fila)
--     grupo:Refrescar() ; grupo:Acomodar(ancho) -> alto
---------------------------------------------------------------------------
function K.FilaAjuste(padre, opts)
	local f = CreateFrame("Frame", nil, padre)
	f.alfaDatos = opts
	f.Titulo = K.Texto(f, "cuerpo", "texto")
	f.Texto = K.Texto(f, "nota", "textoSuave")
	if type(opts.control) == "function" then
		f.Control = opts.control(f)
	elseif opts.control then
		f.Control = K.Adoptar(opts.control, f)
	end
	if opts.hija then
		f.Guia = K.Linea(f, "lineaFuerte", true)
		f.Guia:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.base + 8, -10)
		f.Guia:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", ESP.base + 8, 10)
	end
	function f:Refrescar()
		local d = self.alfaDatos
		K.Escribir(self.Titulo, d.titulo or "")
		K.Escribir(self.Texto, d.texto or "")
		local activa = not d.activa or d.activa()
		self:SetAlpha(activa and 1 or 0.45)
		-- El control: su SetActivo (la fila ya lo atenúa: el control queda a su
		-- alfa), si no Enable / Disable, y si no tiene, solo deja de tomar el ratón.
		local c = self.Control
		if c then
			if c.SetActivo then
				c:SetActivo(activa)
				c:SetAlpha(1)
			elseif c.Enable and c.Disable then
				if activa then c:Enable() else c:Disable() end
			elseif c.EnableMouse then
				c:EnableMouse(activa and true or false)
			end
			if c.Leer then c:Leer() end
		end
	end
	function f:Acomodar(ancho)
		local d = self.alfaDatos
		local x = ESP.base + (d.hija and 24 or 0)
		local cw = 0
		if self.Control then
			if self.Control.alfaAnchoFila then
				self.Control:Acomodar(self.Control.alfaAnchoFila)
			elseif self.Control.SetOpciones and self.Control.Acomodar then
				self.Control:Acomodar(floor(ancho * 0.5)) -- segmentos: hasta la mitad de la fila
			end
			cw = K.num(self.Control:GetWidth(), 0)
		end
		local tw = max(120, ancho - x - ESP.base - (cw > 0 and cw + ESP.l or 0))
		local y = ESP.m
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
		self.Titulo:SetWidth(tw)
		self.Titulo:SetWordWrap(true)
		y = y + K.AltoTexto(self.Titulo)
		if (self.Texto:GetText() or "") ~= "" then
			y = y + 3
			self.Texto:ClearAllPoints()
			self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			y = y + K.Parrafo(self.Texto, tw)
		end
		y = max(y + ESP.m, K.ALTO.control + 2 * ESP.s)
		if self.Control then
			self.Control:ClearAllPoints()
			self.Control:SetPoint("RIGHT", self, "TOPRIGHT", -ESP.base, -floor(y / 2))
		end
		self:SetSize(ancho, y)
		return y
	end
	f:Refrescar()
	return f
end

function K.GrupoAjustes(padre, opts)
	opts = opts or {}
	local g = CreateFrame("Frame", nil, padre)
	g.filas, g.lineas = {}, {}
	if opts.titulo then g.Seccion = K.Seccion(g, opts.titulo, opts) end
	g.Panel = CreateFrame("Frame", nil, g)
	g.Panel.caja = K.Caja(g.Panel, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	function g:Agregar(fila)
		K.Adoptar(fila, self.Panel)
		self.filas[#self.filas + 1] = fila
		return fila
	end
	function g:Fila(o) return self:Agregar(K.FilaAjuste(self.Panel, o)) end
	function g:Refrescar() for _, f in ipairs(self.filas) do f:Refrescar() end end
	function g:Acomodar(ancho)
		local y = 0
		if self.Seccion then
			self.Seccion:ClearAllPoints()
			self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
			self.Seccion:SetWidth(ancho)
			y = self.Seccion:Acomodar(ancho) + ESP.s
		end
		local py = 0
		local visibles = 0
		for i, f in ipairs(self.filas) do
			if f:IsShown() and not f.alfaOculto then
				visibles = visibles + 1
				if visibles > 1 then
					local ln = self.lineas[visibles - 1] or K.Linea(self.Panel, "linea")
					self.lineas[visibles - 1] = ln
					ln:ClearAllPoints()
					ln:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", ESP.base, -py)
					ln:SetPoint("TOPRIGHT", self.Panel, "TOPRIGHT", -ESP.base, -py)
					ln:Show()
				end
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", 0, -py)
				py = py + f:Acomodar(ancho)
			end
		end
		for i = max(1, visibles), #self.lineas do self.lineas[i]:Hide() end
		self.Panel:ClearAllPoints()
		self.Panel:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		self.Panel:SetSize(ancho, max(1, py))
		local alto = y + py
		self:SetSize(ancho, alto)
		return alto
	end
	return g
end
