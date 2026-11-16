-- Alfa - Mazmorras: las piezas propias de la página, hechas con el Kit
-- (Toxic / La Jauría). GPL-3.0.
--
-- Todas son bloques del Kit (docs/KIT.md): :Acomodar(ancho[, altoMin]) -> alto,
-- se crean una vez y se reutilizan, y se pintan con tokens.
--   Pz.Arte(padre, tam)              el arte de la mazmorra (su pantalla de carga)
--   Pz.TarjetaMazmorra(padre)        tarjeta de la rejilla: arte, nombre, datos, insignias, avance
--   Pz.Cabecera(padre, alVolver)     arriba de la página de una mazmorra
--   Pz.BloqueJefe(padre)             un jefe: estado, nombre, consejos, botín y misiones
--   Pz.Celda(padre)                  un objeto del botín
--   Pz.Consejo(padre)                un consejo con su huella
--   Pz.Nota(padre, rol, color)       un párrafo
--   Pz.Botones(padre)                una fila de botones
--   Pz.ArteEnTarjeta(tarjeta, key)   pone el arte en la baldosa de una K.Tarjeta

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local D = M.D

local type, ipairs, tostring, format = type, ipairs, tostring, string.format
local floor, max, min = math.floor, math.max, math.min
local ESP = K.ESP

local Pz = {}
M.Pz = Pz

local DOT = "  \194\183  "
Pz.DOT = DOT

-- Mayúsculas que respetan los acentos ("Estás aquí" -> "ESTÁS AQUÍ"): el
-- upper de Lua solo cambia las letras sin acento, y los sobretítulos del Kit
-- (que llaman a upper) dejarían "ESTáS AQUí". Las minúsculas latinas de dos
-- bytes (U+00E0 a U+00FE) están 0x20 arriba de su mayúscula.
function Pz.Mayus(s)
	if type(s) ~= "string" then return s end
	return (s:upper():gsub("\195([\160-\190])", function(c)
		local b = c:byte()
		if b == 0xB7 then return "\195" .. c end -- ÷ no tiene mayúscula
		return "\195" .. string.char(b - 0x20)
	end))
end

local function arteDe(key)
	local Dg = A.Dungeons
	local art = Dg and Dg.Art and D.Llamar(Dg.Art, key)
	return type(art) == "table" and art.file and art or nil
end

---------------------------------------------------------------------------
-- El arte de una mazmorra: un cuadro con línea de 1 px; sin arte, el ícono.
---------------------------------------------------------------------------
function Pz.Arte(padre, tam)
	local f = CreateFrame("Frame", nil, padre)
	f:SetSize(tam, tam)
	f.caja = K.Caja(f, { fondo = "hundido", borde = "linea", corte = 0 })
	f.Tex = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.Tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.Tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.Luz = f:CreateTexture(nil, "ARTWORK", nil, 2)
	f.Luz:SetAllPoints(f.Tex)
	f.Luz:SetBlendMode("ADD")
	f.Luz:Hide()
	f.Glifo = K.Icono(f, "ic-mazmorra", floor(tam * 0.45), "mazmorra")
	f.Glifo:SetPoint("CENTER")
	function f:Set(key)
		local art = arteDe(key)
		if art then
			self.Tex:SetTexture(art.file)
			self.Tex:SetTexCoord(art.l or 0, art.r or 1, art.t or 0, art.b or 1)
			self.Tex:SetVertexColor(1, 1, 1, 1)
			self.Tex:Show()
			if art.lift then
				self.Luz:SetTexture(art.file)
				self.Luz:SetTexCoord(art.l or 0, art.r or 1, art.t or 0, art.b or 1)
				self.Luz:SetAlpha(art.lift)
				self.Luz:Show()
			else
				self.Luz:Hide()
			end
			self.Glifo:Hide()
		else
			self.Tex:Hide()
			self.Luz:Hide()
			self.Glifo:Show()
		end
	end
	return f
end

-- El arte en la baldosa de una K.Tarjeta (la de "accion" mide 64): tras
-- cada tarjeta:Set, que pone su ícono.
function Pz.ArteEnTarjeta(t, key)
	local ic = t.Icono
	local art = arteDe(key)
	if not t.alfaLuz then
		t.alfaLuz = t.Baldosa:CreateTexture(nil, "ARTWORK", nil, 2)
		t.alfaLuz:SetAllPoints(ic)
		t.alfaLuz:SetBlendMode("ADD")
		t.alfaTamIcono = ic:GetWidth()
	end
	if art then
		ic:SetTexture(art.file)
		ic:SetTexCoord(art.l or 0, art.r or 1, art.t or 0, art.b or 1)
		ic.alfaColor = nil
		ic:SetVertexColor(1, 1, 1, 1)
		local s = K.num(t.Baldosa:GetWidth(), 64) - 2
		ic:SetSize(s, s)
		if art.lift then
			t.alfaLuz:SetTexture(art.file)
			t.alfaLuz:SetTexCoord(art.l or 0, art.r or 1, art.t or 0, art.b or 1)
			t.alfaLuz:SetAlpha(art.lift)
			t.alfaLuz:Show()
		else
			t.alfaLuz:Hide()
		end
	else
		ic:SetTexCoord(0, 1, 0, 1)
		local s = K.num(t.alfaTamIcono, 34)
		ic:SetSize(s, s)
		t.alfaLuz:Hide()
	end
end

---------------------------------------------------------------------------
-- Insignias en fila (se envuelven): fila:Set({ { texto, tono, icono } }),
-- fila:Acomodar(ancho) -> alto
---------------------------------------------------------------------------
local function filaInsignias(padre)
	local f = CreateFrame("Frame", nil, padre)
	f.pool, f.n = {}, 0
	function f:Set(lista)
		lista = lista or {}
		for i, x in ipairs(lista) do
			local ch = self.pool[i] or K.Insignia(self, "", "neutro")
			self.pool[i] = ch
			ch:Set(x[1], x[2], x[3])
		end
		for i = #lista + 1, #self.pool do self.pool[i]:Hide() end
		self.n = #lista
	end
	function f:Acomodar(ancho)
		if self.n == 0 then self:SetSize(1, 1) return 0 end
		local x, y = 0, 0
		for i = 1, self.n do
			local ch = self.pool[i]
			local w = K.num(ch:GetWidth(), 0)
			if x > 0 and x + w > ancho then x, y = 0, y + K.ALTO.insignia + 6 end
			ch:ClearAllPoints()
			ch:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			x = x + w + 6
		end
		local alto = y + K.ALTO.insignia
		self:SetSize(ancho, alto)
		return alto
	end
	return f
end
Pz.Insignias = filaInsignias

---------------------------------------------------------------------------
-- Tarjeta de una mazmorra en la rejilla
--   c:Set({ key, nombre, meta, insignias, avance = { v, total }, alClic, ayuda })
---------------------------------------------------------------------------
local ARTE_TARJETA = 56

local function pintarTarjeta(c)
	local sobre = c.alfaSobre
	c.caja:Estilo({ fondo = "panel", borde = sobre and "lineaFuerte" or "linea" })
	c.velo:SetShown(sobre and true or false)
end

function Pz.TarjetaMazmorra(padre)
	local c = CreateFrame("Button", nil, padre)
	c:RegisterForClicks("LeftButtonUp")
	c.caja = K.Caja(c, { corte = K.CORTE.tarjeta })
	c.velo = K.Velo(c, K.CORTE.tarjeta, 0.035)
	c.Arte = Pz.Arte(c, ARTE_TARJETA)
	c.Nombre = K.Texto(c, "subtitulo", "texto")
	c.Meta = K.Texto(c, "pequeno", "textoTenue")
	c.Fila = filaInsignias(c)
	c.Barra = K.Progreso(c, { alto = 3 })
	c:SetScript("OnClick", function(self) local d = self.alfaDatos if d and d.alClic then K.Llamar(d.alClic, d) end end)
	c:SetScript("OnEnter", function(self)
		self.alfaSobre = true
		pintarTarjeta(self)
		local d = self.alfaDatos
		if d and d.ayuda then K.MostrarInfo(self, d.nombre, d.ayuda) end
	end)
	c:SetScript("OnLeave", function(self) self.alfaSobre = nil pintarTarjeta(self) K.OcultarInfo(self) end)
	function c:Set(d)
		self.alfaDatos = d or {}
		d = self.alfaDatos
		self.Arte:Set(d.key)
		K.Escribir(self.Nombre, d.nombre or "")
		K.Escribir(self.Meta, d.meta or "")
		self.Fila:Set(d.insignias)
		local a = d.avance
		if a and (a[2] or 0) > 0 and (a[1] or 0) > 0 then
			self.Barra:Set(a[1], a[2])
			self.Barra:Show()
		else
			self.Barra:Hide()
		end
	end
	function c:Acomodar(ancho, altoMin)
		local pad = ESP.m
		self:SetWidth(ancho)
		self.Arte:ClearAllPoints()
		self.Arte:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad)
		local x = pad + ARTE_TARJETA + ESP.m
		local tw = max(60, ancho - x - pad)
		local y = pad
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
		y = y + K.Parrafo(self.Nombre, tw, 2)
		if (self.Meta:GetText() or "") ~= "" then
			y = y + 2
			self.Meta:ClearAllPoints()
			self.Meta:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			y = y + K.Parrafo(self.Meta, tw, 2)
		end
		if self.Fila.n > 0 then
			y = y + ESP.s
			self.Fila:ClearAllPoints()
			self.Fila:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			y = y + self.Fila:Acomodar(tw)
		end
		if self.Barra:IsShown() then
			y = y + ESP.s
			self.Barra:ClearAllPoints()
			self.Barra:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			self.Barra:Acomodar(tw)
			y = y + 3
		end
		local alto = max(pad + ARTE_TARJETA + pad, y + pad, altoMin or 0)
		self:SetHeight(alto)
		return alto
	end
	K.Pintar(c, pintarTarjeta)
	return c
end

---------------------------------------------------------------------------
-- Un párrafo como bloque: nota:Set(texto) ; nota:Acomodar(ancho) -> alto
---------------------------------------------------------------------------
function Pz.Nota(padre, rol, color)
	local f = CreateFrame("Frame", nil, padre)
	f.Texto = K.Texto(f, rol or "nota", color or "textoSuave")
	f.Texto:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.Texto:SetJustifyH("LEFT")
	function f:Set(t) K.Escribir(self.Texto, t or "") end
	function f:Vacia() return (self.Texto:GetText() or "") == "" end
	function f:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, ancho, 0)
		self:SetSize(ancho, max(1, h))
		return h
	end
	return f
end

---------------------------------------------------------------------------
-- Un consejo: la huella y el texto (con su papel teñido delante).
---------------------------------------------------------------------------
local PAPEL = {
	tanque = { L["Tanque"], "acento" },
	cura = { L["Cura"], "exito" },
	dano = { L["Daño"], "aviso" },
}

-- Un consejo {es, en, rol} en el idioma del cliente.
function Pz.TextoConsejo(c)
	if type(c) ~= "table" or not c[1] then return "" end
	local s = N.Traducir(c[1], c[2])
	local p = PAPEL[c.rol]
	if p then s = K.Tenir(p[2], p[1] .. ":") .. " " .. s end
	return s
end

function Pz.Consejo(padre)
	local f = CreateFrame("Frame", nil, padre)
	f.Huella = K.Icono(f, "ic-huella", 12, "textoTenue")
	f.Huella:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)
	f.Texto = K.Texto(f, "texto", "texto")
	f.Texto:SetPoint("TOPLEFT", f, "TOPLEFT", 20, 0)
	f.Texto:SetJustifyH("LEFT")
	function f:Set(c) K.Escribir(self.Texto, type(c) == "string" and c or Pz.TextoConsejo(c)) end
	function f:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, max(40, ancho - 20), 0)
		h = max(h, 16)
		self:SetSize(ancho, h)
		return h
	end
	return f
end

-- Una lista de consejos: lista:Set({ c, ... }) ; lista:Acomodar(ancho) -> alto
function Pz.Consejos(padre)
	local p = K.Pila(padre, { espacio = ESP.s })
	p.filas = {}
	function p:Set(lista)
		lista = lista or {}
		for i, c in ipairs(lista) do
			local f = self.filas[i]
			if not f then
				f = self:Agregar(Pz.Consejo(self))
				self.filas[i] = f
			end
			f:Set(c)
			K.Mostrar(f, true)
		end
		for i = #lista + 1, #self.filas do K.Mostrar(self.filas[i], false) end
		self.n = #lista
	end
	return p
end

---------------------------------------------------------------------------
-- Una fila de botones (se envuelve): fila:Set({ boton, ... }) con botones
-- nacidos en la fila (K.Boton(fila, ...)); fila:Acomodar(ancho) -> alto
---------------------------------------------------------------------------
function Pz.Botones(padre)
	local f = CreateFrame("Frame", nil, padre)
	f.lista = {}
	function f:Set(lista) self.lista = lista or {} end
	function f:Hay()
		for _, b in ipairs(self.lista) do if b:IsShown() then return true end end
		return false
	end
	function f:Acomodar(ancho)
		local x, y, alto = 0, 0, 0
		for _, b in ipairs(self.lista) do
			if b:IsShown() then
				local w = b:AnchoNatural()
				b:SetAncho(nil)
				local h = K.num(b:GetHeight(), K.ALTO.botonChico)
				if x > 0 and x + w > ancho then x, y = 0, y + alto + ESP.s end
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
				x = x + w + ESP.s
				alto = max(alto, h)
			end
		end
		local total = alto > 0 and (y + alto) or 0
		self:SetSize(ancho, max(1, total))
		return total
	end
	return f
end

-- El botón "volver": fantasma, con la flecha hacia la izquierda.
function Pz.Volver(padre, texto, alClic)
	local b = K.Boton(padre, texto, alClic, { tipo = "fantasma", tam = "chico", icono = "ic-seguir" })
	if b.Icono then b.Icono:SetTexCoord(1, 0, 0, 1) end
	return b
end

---------------------------------------------------------------------------
-- Cabecera de la página de una mazmorra
--   cab:Set({ key, sobre, titulo, meta, insignias, avance = { v, total, texto } })
---------------------------------------------------------------------------
local ARTE_CABECERA = 96

function Pz.Cabecera(padre, alVolver)
	local f = CreateFrame("Frame", nil, padre)
	f.Volver = Pz.Volver(f, L["Todas las mazmorras"], alVolver)
	f.Arte = Pz.Arte(f, ARTE_CABECERA)
	f.Sobre = K.Texto(f, "mayus", "mazmorra")
	f.Titulo = K.Texto(f, "portada", "texto")
	f.Meta = K.Texto(f, "nota", "textoSuave")
	f.Fila = filaInsignias(f)
	f.Avance = K.Texto(f, "pequeno", "textoTenue")
	function f:Set(d)
		d = d or {}
		self.alfaDatos = d
		self.Arte:Set(d.key)
		K.Escribir(self.Sobre, d.sobre and Pz.Mayus(tostring(d.sobre)) or "")
		K.Escribir(self.Titulo, d.titulo or "")
		K.Escribir(self.Meta, d.meta or "")
		self.Fila:Set(d.insignias)
		local a = d.avance
		if a and (a[2] or 0) > 0 then
			-- Las huellas nacen la primera vez que hacen falta.
			self.Huellas = self.Huellas or K.Huellas(self, { tam = 16, max = 12 })
			self.Huellas:Set(a[1] or 0, a[2])
			self.Huellas:Show()
			K.Escribir(self.Avance, a[3] or "")
			self.Avance:Show()
		else
			if self.Huellas then self.Huellas:Hide() end
			self.Avance:Hide()
		end
	end
	function f:Acomodar(ancho)
		self.Volver:ClearAllPoints()
		self.Volver:SetPoint("TOPLEFT", self, "TOPLEFT", -8, 0)
		local top = K.ALTO.botonChico + ESP.base
		self.Arte:ClearAllPoints()
		self.Arte:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -top)
		local x = ARTE_CABECERA + ESP.l
		local tw = max(80, ancho - x)
		local y = 0
		local conSobre = (self.Sobre:GetText() or "") ~= ""
		local hSobre = conSobre and (K.AltoTexto(self.Sobre) + 4) or 0
		self.Titulo:SetWordWrap(true)
		local hTitulo = K.Parrafo(self.Titulo, tw, 2)
		local hMeta = (self.Meta:GetText() or "") ~= "" and (4 + K.Parrafo(self.Meta, tw, 2)) or 0
		local hFila = self.Fila.n > 0 and (ESP.s + self.Fila:Acomodar(tw)) or 0
		local hAvance = self.Huellas and self.Huellas:IsShown() and (ESP.m + 22) or 0
		local total = hSobre + hTitulo + hMeta + hFila + hAvance
		-- El texto queda centrado con el arte cuando cabe.
		y = max(0, floor((ARTE_CABECERA - total) / 2))
		self.Sobre:SetShown(conSobre)
		self.Sobre:ClearAllPoints()
		self.Sobre:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(top + y))
		self.Sobre:SetWidth(tw)
		y = y + hSobre
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(top + y))
		y = y + hTitulo
		if hMeta > 0 then
			self.Meta:ClearAllPoints()
			self.Meta:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(top + y + 4))
			y = y + hMeta
		end
		if hFila > 0 then
			self.Fila:ClearAllPoints()
			self.Fila:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(top + y + ESP.s))
			y = y + hFila
		end
		if hAvance > 0 then
			local hw = self.Huellas:Acomodar()
			self.Huellas:ClearAllPoints()
			self.Huellas:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(top + y + ESP.m))
			self.Avance:ClearAllPoints()
			self.Avance:SetPoint("LEFT", self.Huellas, "RIGHT", ESP.m, 0)
			K.Ajustar(self.Avance, max(40, tw - hw - ESP.m))
			y = y + hAvance
		end
		local alto = top + max(ARTE_CABECERA, y)
		self:SetSize(ancho, alto)
		return alto
	end
	return f
end

---------------------------------------------------------------------------
-- Un objeto del botín: ícono con su calidad, nombre, ranura y tipo, de qué
-- jefe, su probabilidad y una marca (lo tienes, es mejora, lo será).
--   celda:Set({ id, nombre, calidad, icono, sub, chance, marca = "tienes" | "mejora" | "luego" })
---------------------------------------------------------------------------
local MARCA = {
	tienes = { "ic-exito", "exito", L["Ya lo tienes"] },
	mejora = { "ic-nivel", "acento", L["Es una mejora para ti"] },
	luego = { "ic-nivel", "textoTenue", L["Será una mejora más adelante"] },
}

local function porcentaje(c)
	if type(c) ~= "number" then return "" end
	if c < 1 then return "<1 %" end
	return format("%d %%", floor(c + 0.5))
end

function Pz.Celda(padre)
	local c = CreateFrame("Frame", nil, padre)
	c.caja = K.Caja(c, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	c.Icono = K.IconoObjeto(c, 30)
	c.Icono:SetPoint("LEFT", c, "LEFT", ESP.m, 0)
	c.Marca = K.Icono(c, "ic-exito", 14, "exito")
	c.Marca:SetPoint("RIGHT", c, "RIGHT", -ESP.m, 0)
	c.Chance = K.Texto(c, "numero", "textoSuave")
	c.Chance:SetJustifyH("RIGHT")
	c.Nombre = K.Texto(c, "cuerpo", "objeto")
	c.Sub = K.Texto(c, "pequeno", "textoTenue")
	c.Zona = CreateFrame("Frame", nil, c)
	c.Zona:SetAllPoints(c.Marca)
	c.Zona:EnableMouse(true)
	function c:Set(o)
		self.alfaDatos = o
		self.Icono:SetObjeto({ id = o.id, icono = o.icono, calidad = o.calidad })
		K.Escribir(self.Nombre, o.nombre or "?")
		local r, g, b = K.ColorDeCalidad(o.calidad)
		if r and A.Theme and A.Theme.Legible then
			self.Nombre:SetTextColor(A.Theme.Legible(r, g, b))
		else
			K.ColorTexto(self.Nombre, "objeto")
		end
		K.Escribir(self.Sub, o.sub or "")
		self.Chance:SetText(porcentaje(o.chance))
		local m = MARCA[o.marca or ""]
		if m then
			K.SetIcono(self.Marca, m[1], m[2])
			self.Marca:Show()
			K.ConInfo(self.Zona, m[3], o.marcaTexto)
			self.Zona:Show()
		else
			self.Marca:Hide()
			self.Zona:Hide()
		end
	end
	function c:Acomodar(ancho, altoMin)
		local h = max(K.ALTO.compacta, altoMin or 0)
		self:SetSize(ancho, h)
		local derecha = ESP.m + (self.Marca:IsShown() and (14 + ESP.s) or 0)
		self.Chance:ClearAllPoints()
		self.Chance:SetPoint("RIGHT", self, "RIGHT", -derecha, 0)
		local cw = (self.Chance:GetText() or "") ~= "" and (K.Ajustar(self.Chance, 60) + ESP.s) or 0
		local x = ESP.m + 30 + ESP.m
		local tw = max(40, ancho - x - derecha - cw)
		local conSub = (self.Sub:GetText() or "") ~= ""
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("LEFT", self, "LEFT", x, conSub and 7 or 0)
		self.Nombre:SetWidth(tw)
		self.Nombre:SetWordWrap(false)
		self.Sub:ClearAllPoints()
		self.Sub:SetPoint("TOPLEFT", self.Nombre, "BOTTOMLEFT", 0, -2)
		self.Sub:SetWidth(tw)
		self.Sub:SetWordWrap(false)
		self.Sub:SetShown(conSub)
		return h
	end
	return c
end

---------------------------------------------------------------------------
-- Iconos de objetos en una tira: los que caben y "+N" (lleva al botín).
--   tira:Set(lista de { id, icono, calidad }, alMas) ; tira:Acomodar(ancho) -> alto
---------------------------------------------------------------------------
local ICONO_TIRA = 30

function Pz.Tira(padre)
	local f = CreateFrame("Frame", nil, padre)
	f.iconos = {}
	f.Mas = K.Boton(f, "", nil, { tipo = "fantasma", tam = "chico" })
	function f:Set(lista, alMas)
		self.lista = lista or {}
		self.Mas.alClic = alMas
	end
	function f:Acomodar(ancho)
		local n = #self.lista
		if n == 0 then
			for _, ic in ipairs(self.iconos) do ic:Hide() end
			self.Mas:Hide()
			self:SetSize(ancho, 1)
			return 0
		end
		local paso = ICONO_TIRA + 6
		local caben = max(1, floor((ancho + 6) / paso))
		local mostrar = n
		if n > caben then mostrar = max(1, caben - 2) end
		for i = 1, mostrar do
			local ic = self.iconos[i] or K.IconoObjeto(self, ICONO_TIRA)
			self.iconos[i] = ic
			ic:SetObjeto(self.lista[i])
			ic:ClearAllPoints()
			ic:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * paso, 0)
			ic:Show()
		end
		for i = mostrar + 1, #self.iconos do self.iconos[i]:Hide() end
		if mostrar < n then
			self.Mas:SetTexto(format(L["+%d en Botín"], n - mostrar))
			self.Mas:ClearAllPoints()
			self.Mas:SetPoint("LEFT", self, "TOPLEFT", mostrar * paso, -ICONO_TIRA / 2)
			self.Mas:Show()
		else
			self.Mas:Hide()
		end
		self:SetSize(ancho, ICONO_TIRA)
		return ICONO_TIRA
	end
	return f
end

---------------------------------------------------------------------------
-- Un jefe
--   b:Set({ n, nombre, oculto, vencido, nivel, insignias, consejos, nota,
--           verConsejos = fn | nil, botin = { ... } | nil, alMas, misiones = texto | nil })
---------------------------------------------------------------------------
local function pintarJefe(b)
	local d = b.alfaDatos or {}
	-- (alfa 1 explícito: Estilo conserva lo que no se le pasa)
	b.caja:Estilo({ fondo = "panel", borde = d.vencido and "exito" or "linea", alfaBorde = d.vencido and 0.35 or 1 })
	b.Medalla.caja:Estilo({ fondo = d.vencido and "exito" or "elevado", alfaFondo = d.vencido and 0.16 or 1,
		borde = d.vencido and "exito" or "lineaFuerte", alfaBorde = d.vencido and 0.5 or 1 })
end

function Pz.BloqueJefe(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { corte = K.CORTE.panel })
	b.Medalla = CreateFrame("Frame", nil, b)
	b.Medalla:SetSize(28, 28)
	b.Medalla.caja = K.Caja(b.Medalla, { corte = K.CORTE.chico })
	b.Medalla.Num = K.Texto(b.Medalla, "numero", "textoSuave")
	b.Medalla.Num:SetPoint("CENTER", b.Medalla, "CENTER", 0, 0)
	b.Medalla.Ic = K.Icono(b.Medalla, "ic-exito", 14, "exito")
	b.Medalla.Ic:SetPoint("CENTER")
	b.Nombre = K.Texto(b, "subtitulo", "texto")
	b.Nivel = K.Texto(b, "pequeno", "textoTenue")
	b.Nivel:SetJustifyH("RIGHT")
	b.Fila = filaInsignias(b)
	b.Cuerpo = K.Pila(b, { espacio = ESP.m })
	b.Nota = b.Cuerpo:Agregar(Pz.Nota(b.Cuerpo, "nota", "textoSuave"))
	b.Consejos = b.Cuerpo:Agregar(Pz.Consejos(b.Cuerpo))
	b.Acciones = b.Cuerpo:Agregar(Pz.Botones(b.Cuerpo))
	b.VerConsejos = K.Boton(b.Acciones, L["Ver sus consejos"], nil, { tipo = "fantasma", tam = "chico", icono = "ic-info" })
	b.Acciones:Set({ b.VerConsejos })
	b.EtBotin = b.Cuerpo:Agregar(Pz.Nota(b.Cuerpo, "pequeno", "textoTenue"))
	b.EtBotin:Set(L["Botín"])
	b.Tira = b.Cuerpo:Agregar(Pz.Tira(b.Cuerpo), { espacio = ESP.s })
	b.Misiones = b.Cuerpo:Agregar(Pz.Nota(b.Cuerpo, "pequeno", "mision"))
	function b:Set(d)
		d = d or {}
		self.alfaDatos = d
		if d.vencido then
			self.Medalla.Ic:Show()
			self.Medalla.Num:Hide()
		else
			self.Medalla.Ic:Hide()
			self.Medalla.Num:SetText(d.oculto and "?" or tostring(d.n or ""))
			self.Medalla.Num:Show()
		end
		K.Escribir(self.Nombre, d.nombre or "")
		K.ColorTexto(self.Nombre, d.oculto and "textoTenue" or "texto")
		K.Escribir(self.Nivel, d.nivel and format(L["Nivel %d"], d.nivel) or "")
		self.Fila:Set(d.insignias)
		self.Nota:Set(d.nota)
		K.Mostrar(self.Nota, d.nota ~= nil and d.nota ~= "")
		self.Consejos:Set(d.consejos)
		K.Mostrar(self.Consejos, d.consejos ~= nil and #d.consejos > 0)
		self.VerConsejos.alClic = d.verConsejos
		self.VerConsejos:SetShown(d.verConsejos ~= nil)
		K.Mostrar(self.Acciones, d.verConsejos ~= nil)
		local conBotin = type(d.botin) == "table" and #d.botin > 0
		self.Tira:Set(d.botin, d.alMas)
		K.Mostrar(self.EtBotin, conBotin)
		K.Mostrar(self.Tira, conBotin)
		self.Misiones:Set(d.misiones)
		K.Mostrar(self.Misiones, d.misiones ~= nil and d.misiones ~= "")
		pintarJefe(self)
	end
	function b:Acomodar(ancho)
		local pad = ESP.base
		local iw = ancho - pad * 2
		self.Medalla:ClearAllPoints()
		self.Medalla:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad)
		local nw = (self.Nivel:GetText() or "") ~= "" and (K.Ajustar(self.Nivel, 120) + ESP.m) or 0
		self.Nivel:ClearAllPoints()
		self.Nivel:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, -(pad + 7))
		local x = pad + 28 + ESP.m
		local tw = max(60, ancho - x - pad - nw)
		-- El nombre y sus insignias en la misma línea si caben.
		local anchoNombre = min(K.AnchoTexto(self.Nombre) + 4, tw)
		self.Nombre:SetWidth(max(40, anchoNombre))
		self.Nombre:SetWordWrap(false)
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("LEFT", self.Medalla, "RIGHT", ESP.m, 0)
		local y = pad + 28
		if self.Fila.n > 0 then
			local resto = tw - anchoNombre - ESP.s
			local fw = 0
			for i = 1, self.Fila.n do fw = fw + K.num(self.Fila.pool[i]:GetWidth(), 0) + 6 end
			self.Fila:ClearAllPoints()
			if fw <= resto then
				self.Fila:Acomodar(resto)
				self.Fila:SetPoint("LEFT", self.Nombre, "RIGHT", ESP.s, 0)
			else
				local h = self.Fila:Acomodar(tw)
				self.Fila:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(y + ESP.s))
				y = y + ESP.s + h
			end
		end
		local hc = self.Cuerpo:Acomodar(iw)
		self.Cuerpo:ClearAllPoints()
		if hc > 0 then
			self.Cuerpo:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -(y + ESP.m))
			y = y + ESP.m + hc
		end
		local alto = y + pad
		self:SetSize(ancho, alto)
		return alto
	end
	K.Pintar(b, pintarJefe)
	return b
end
