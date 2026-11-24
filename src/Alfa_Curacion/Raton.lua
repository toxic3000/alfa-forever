-- Alfa - Curación: el dibujo del ratón (1.3.9). toxic3000 / La Jauría. GPL-3.0.
--
-- Un ratón dibujado con las piezas del Kit: el cuerpo, el botón izquierdo, el
-- derecho y la rueda (el central). Junto a cada botón, lo que hace sobre tu
-- compañero con la tecla elegida arriba (sin tecla, Mayús, Ctrl o Alt), con
-- el ícono del hechizo. Lo usan el asistente (Asistente.lua: pasos 1 y 3) y
-- nada más: solo enseña, no cambia tus clics.
--   local d = M.DibujoRaton(padre)
--   d:Set({ mod = "shift-", marcar = "shift-1" })   (marcar: la ranura que se probó)
--   d:Acomodar(ancho) -> alto

local ADDON, M = ...
local N = AlfaNucleo
local K = N.Kit
local L = M.L

local floor, max, min, ipairs, type = math.floor, math.max, math.min, ipairs, type
local ESP = K.ESP

local CUERPO_W, CUERPO_H = 86, 128
local BOTON_H = 50
local ETIQ_W = 170

local function pintarParte(p)
	local on = p.alfaMarcada
	p.caja:Estilo({ fondo = on and "acento" or "elevado", alfaFondo = on and 0.28 or 1, borde = on and "acento" or "lineaFuerte", alfaBorde = 1 })
end

local function parte(padre, corte)
	local p = CreateFrame("Frame", nil, padre)
	p.caja = K.Caja(p, { corte = corte or K.CORTE.control })
	K.Pintar(p, pintarParte)
	return p
end

-- La etiqueta de un botón: ícono, lo que hace y qué botón es.
local function etiqueta(padre, derecha)
	local e = CreateFrame("Frame", nil, padre)
	e.Icono = e:CreateTexture(nil, "ARTWORK")
	e.Icono:SetSize(20, 20)
	e.Nombre = K.Texto(e, "cuerpo", "texto")
	e.Boton = K.Texto(e, "pequeno", "textoTenue")
	e.Linea = K.Linea(padre, "lineaFuerte")
	e.derecha = derecha
	for _, fs in ipairs({ e.Nombre, e.Boton }) do
		fs:SetJustifyH(derecha and "LEFT" or "RIGHT")
		fs:SetWordWrap(true)
	end
	return e
end

function M.DibujoRaton(padre)
	local d = CreateFrame("Frame", nil, padre)
	d.alfaMod, d.alfaMarcar = "", nil
	local o = {}
	for _, md in ipairs(M.MODS) do o[#o + 1] = { valor = md.p, texto = md.nombre } end
	d.Mods = K.Segmentos(d, { estilo = "segmentos", opciones = o, valor = "", alCambiar = function(v)
		d.alfaMod = v
		d:Pintar()
	end })
	d.Cuerpo = parte(d, 16)
	d.Izq = parte(d, K.CORTE.control)
	d.Der = parte(d, K.CORTE.control)
	d.Rueda = parte(d, K.CORTE.casilla)
	d.Cuerpo.alfaFija = true
	d.etiq = { ["1"] = etiqueta(d, false), ["2"] = etiqueta(d, true), ["3"] = etiqueta(d, true) }
	d.Nota = K.Texto(d, "nota", "textoSuave")
	d.Nota:SetJustifyH("CENTER")

	function d:Set(o2)
		o2 = o2 or {}
		if o2.mod ~= nil then self.alfaMod = o2.mod end
		self.alfaMarcar = o2.marcar
		if o2.marcar then self.alfaMod = (M.Partes(o2.marcar)) end
		self.Mods:SetValor(self.alfaMod)
		self:Pintar()
	end

	function d:Pintar()
		local mapa = M.Mapa()
		local partes = { ["1"] = self.Izq, ["2"] = self.Der, ["3"] = self.Rueda }
		for s, p in pairs(partes) do
			local r = self.alfaMod .. s
			p.alfaMarcada = self.alfaMarcar == r or nil
			pintarParte(p)
			local e = self.etiq[s]
			M.PintarRanura(e.Icono, e.Nombre, nil, mapa[r])
			if self.alfaMarcar == r then K.ColorTexto(e.Nombre, "acento") end
			K.Escribir(e.Boton, M.NombreRanura(r))
		end
		pintarParte(self.Cuerpo)
		local md
		for _, x in ipairs(M.MODS) do if x.p == self.alfaMod then md = x end end
		K.Escribir(self.Nota, self.alfaMod == "" and L["Así hace cada botón de tu ratón sobre el compañero que tienes debajo."]
			or string.format(L["Con %s apretada, así hace cada botón."], md and md.nombre or ""))
	end

	function d:Acomodar(ancho)
		local _, sw = self.Mods:Acomodar(ancho)
		self.Mods:ClearAllPoints()
		self.Mods:SetPoint("TOP", self, "TOP", 0, 0)
		local y = K.ALTO.control + ESP.base
		-- La rueda tiene su etiqueta arriba; los botones, a los lados.
		local e3 = self.etiq["3"]
		local lw = max(120, min(ETIQ_W + 60, ancho - 40))
		e3.Nombre:SetJustifyH("CENTER")
		e3.Boton:SetJustifyH("CENTER")
		local hn = K.Parrafo(e3.Nombre, lw - 26, 2)
		local hb = K.Parrafo(e3.Boton, lw, 1)
		e3.Icono:ClearAllPoints()
		e3.Icono:SetPoint("TOP", self, "TOP", 0, -y)
		e3.Nombre:ClearAllPoints()
		e3.Nombre:SetPoint("TOP", self, "TOP", 0, -(y + 22))
		e3.Boton:ClearAllPoints()
		e3.Boton:SetPoint("TOP", e3.Nombre, "BOTTOM", 0, -2)
		y = y + 22 + hn + 2 + hb + ESP.s
		local cx = floor(ancho / 2)
		local top = y + 10
		self.Cuerpo:ClearAllPoints()
		self.Cuerpo:SetPoint("TOPLEFT", self, "TOPLEFT", cx - CUERPO_W / 2, -top)
		self.Cuerpo:SetSize(CUERPO_W, CUERPO_H)
		local bw = floor((CUERPO_W - 6) / 2)
		self.Izq:ClearAllPoints()
		self.Izq:SetPoint("TOPLEFT", self.Cuerpo, "TOPLEFT", 2, -2)
		self.Izq:SetSize(bw, BOTON_H)
		self.Der:ClearAllPoints()
		self.Der:SetPoint("TOPRIGHT", self.Cuerpo, "TOPRIGHT", -2, -2)
		self.Der:SetSize(bw, BOTON_H)
		self.Rueda:ClearAllPoints()
		self.Rueda:SetPoint("TOP", self.Cuerpo, "TOP", 0, -10)
		self.Rueda:SetSize(12, 26)
		self.Rueda:SetFrameLevel(self.Cuerpo:GetFrameLevel() + 3)
		-- La línea de la rueda a su etiqueta.
		e3.Linea:ClearAllPoints()
		e3.Linea:SetPoint("TOP", e3.Boton, "BOTTOM", 0, -3)
		e3.Linea:SetPoint("BOTTOM", self.Rueda, "TOP", 0, 2)
		e3.Linea:SetWidth(1)
		e3.Linea:Show()
		-- Izquierdo y derecho, a los lados del cuerpo, a la altura de su botón.
		local lado = max(80, min(ETIQ_W, floor((ancho - CUERPO_W) / 2) - 24))
		local medio = top + 2 + BOTON_H / 2
		local altoLados = 0
		for _, s in ipairs({ "1", "2" }) do
			local e = self.etiq[s]
			local hN = K.Parrafo(e.Nombre, lado - 26, 2)
			local hB = K.Parrafo(e.Boton, lado, 1)
			local h = max(20, hN) + 2 + hB
			altoLados = max(altoLados, h)
			local y0 = medio - floor(h / 2)
			local derecha = s == "2"
			local x0 = derecha and (cx + CUERPO_W / 2 + 18) or (cx - CUERPO_W / 2 - 18 - lado)
			e.Icono:ClearAllPoints()
			e.Nombre:ClearAllPoints()
			e.Boton:ClearAllPoints()
			if derecha then
				e.Icono:SetPoint("TOPLEFT", self, "TOPLEFT", x0, -y0)
				e.Nombre:SetPoint("TOPLEFT", self, "TOPLEFT", x0 + 26, -y0 - 2)
				e.Boton:SetPoint("TOPLEFT", self, "TOPLEFT", x0, -(y0 + max(20, hN) + 2))
			else
				e.Icono:SetPoint("TOPRIGHT", self, "TOPLEFT", x0 + lado, -y0)
				e.Nombre:SetPoint("TOPRIGHT", self, "TOPLEFT", x0 + lado - 26, -y0 - 2)
				e.Boton:SetPoint("TOPRIGHT", self, "TOPLEFT", x0 + lado, -(y0 + max(20, hN) + 2))
			end
			e.Linea:ClearAllPoints()
			if derecha then
				e.Linea:SetPoint("LEFT", self.Der, "RIGHT", 2, 0)
				e.Linea:SetPoint("RIGHT", self, "TOPLEFT", x0 - 4, -medio)
			else
				e.Linea:SetPoint("RIGHT", self.Izq, "LEFT", -2, 0)
				e.Linea:SetPoint("LEFT", self, "TOPLEFT", x0 + lado + 4, -medio)
			end
			e.Linea:SetHeight(1)
			e.Linea:Show()
		end
		y = top + max(CUERPO_H, BOTON_H / 2 + altoLados / 2 + 2) + ESP.base
		self.Nota:ClearAllPoints()
		self.Nota:SetPoint("TOP", self, "TOP", 0, -y)
		y = y + K.Parrafo(self.Nota, ancho, 2)
		self:SetSize(ancho, y)
		return y
	end
	d:Pintar()
	return d
end
