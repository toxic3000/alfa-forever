-- Alfa - Mundo: el panel de capas que abre el botón del mapa (el de Alfa y
-- el del juego) (Toxic / La Jauría). GPL-3.0.
--
-- Hecho con el Kit (Emergente.lua): arriba el modo limpio; debajo cada grupo
-- con sus interruptores, los del motor y los de los módulos que registraron
-- capas (también las que llegan con el panel abierto). Abajo, "Más opciones"
-- lleva a la página Mundo. Escape o la X lo cierran.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local Capas = M.Capas

local type, ipairs, max, min, format = type, ipairs, math.max, math.min, string.format
local ESP = K.ESP

local Panel = {}
M.Panel = Panel

local ANCHO, FILA, TITULO_G, ALTO_MAX, PIE = 336, 32, 28, 560, 44

local F
local filas, titulos = {}, {}

local function pintarFila(r, e)
	r.amCapa = e
	local libre, porque = Capas.Disponible(e)
	r.amLibre, r.amPorque = libre, porque
	K.Escribir(r.Texto, e.nombre)
	if type(e.icono) == "string" or type(e.icono) == "number" then
		r.Icono:SetTexture(e.icono)
		local T = A.Theme
		if e.color and T and T.Color then
			local cr, cg, cb = T.Color(e.color)
			r.Icono:SetVertexColor(cr or 1, cg or 1, cb or 1, 1)
		else
			r.Icono:SetVertexColor(K.Color("textoSuave"))
		end
		r.Icono:Show()
	else
		r.Icono:Hide()
	end
	K.ColorTexto(r.Texto, libre and "texto" or "textoTenue")
	r.Interruptor:SetValor(Capas.Valor(e))
	r.Interruptor:SetAlpha(libre and 1 or 0.4)
	r.Interruptor:EnableMouse(libre and true or false)
end

local function fila(i)
	local r = filas[i]
	if r then return r end
	r = CreateFrame("Button", nil, F.Desp.Contenido)
	r:SetHeight(FILA)
	r:RegisterForClicks("LeftButtonUp")
	r.velo = K.Velo(r, K.CORTE.chico, 0.05)
	r.velo:Hide()
	r.Icono = r:CreateTexture(nil, "ARTWORK")
	r.Icono:SetSize(16, 16)
	r.Icono:SetPoint("LEFT", r, "LEFT", ESP.s, 0)
	r.Texto = K.Texto(r, "etiqueta", "texto")
	r.Texto:SetPoint("LEFT", r, "LEFT", 32, 0)
	r.Interruptor = K.Interruptor(r, { alCambiar = function(v) if r.amCapa then Capas.Poner(r.amCapa, v) end end })
	r.Interruptor:SetPoint("RIGHT", r, "RIGHT", -ESP.s, 0)
	r.Texto:SetPoint("RIGHT", r.Interruptor, "LEFT", -ESP.s, 0)
	r:SetScript("OnClick", function(self)
		if self.amCapa and self.amLibre then Capas.Poner(self.amCapa, not Capas.Valor(self.amCapa)) end
	end)
	r:SetScript("OnEnter", function(self) self.velo:Show() end)
	r:SetScript("OnLeave", function(self) self.velo:Hide() end)
	K.ConInfo(r, function(self)
		local e = self.amCapa
		if not e then return nil end
		local lineas = {}
		if e.ayuda then lineas[#lineas + 1] = e.ayuda end
		if not self.amLibre and self.amPorque then lineas[#lineas + 1] = K.Tenir("aviso", self.amPorque) end
		if e.esencial then lineas[#lineas + 1] = K.Tenir("textoTenue", L["Se queda en el modo limpio."]) end
		return e.nombre, lineas
	end)
	r.Texto:SetWordWrap(false)
	filas[i] = r
	return r
end

local function titulo(i)
	local h = titulos[i]
	if h then return h end
	h = K.Texto(F.Desp.Contenido, "mayus", "textoTenue")
	titulos[i] = h
	return h
end

local function pintarLimpio()
	local lim = F.Limpio
	local on = Capas.Limpio()
	lim.Interruptor:SetValor(on)
	local n = Capas.CuantasOcultas()
	K.Escribir(lim.Desc, on and (n > 0 and format(L["%d capas ocultas. Apágalo para volver a verlas."], n)
		or L["Solo tú, tu grupo, tus marcadores y el siguiente paso de la guía."])
		or L["Un clic y queda solo lo esencial: tú, tu grupo, tus marcadores y el siguiente paso de la guía."])
	K.Parrafo(lim.Desc, ANCHO - ESP.base * 2 - 42 - 36 - ESP.m - ESP.s, 2)
	K.ColorTexto(lim.Titulo, on and "acento" or "texto")
	lim.caja:Estilo({ fondo = "panel", borde = on and "acento" or "linea", alfaBorde = on and 0.6 or 1 })
end

function Panel.Refrescar()
	if not (F and F:IsShown()) then return end
	pintarLimpio()
	local ancho = ANCHO - ESP.base * 2
	local y, nf, nt = 0, 0, 0
	for _, g in ipairs(Capas.Grupos()) do
		nt = nt + 1
		local h = titulo(nt)
		K.Escribir(h, g.nombre:upper())
		h:ClearAllPoints()
		h:SetPoint("BOTTOMLEFT", F.Desp.Contenido, "TOPLEFT", ESP.s, -(y + TITULO_G - 6))
		h:Show()
		y = y + TITULO_G
		for _, e in ipairs(g.capas) do
			nf = nf + 1
			local r = fila(nf)
			pintarFila(r, e)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", F.Desp.Contenido, "TOPLEFT", 0, -y)
			r:SetWidth(ancho - 12)
			r:Show()
			y = y + FILA
		end
	end
	for i = nf + 1, #filas do filas[i]:Hide() end
	for i = nt + 1, #titulos do titulos[i]:Hide() end
	local fijo = F.arriba + ESP.m + 60 + ESP.s + PIE
	local alto = min(ALTO_MAX, fijo + y + ESP.s)
	F:SetHeight(alto)
	F.Desp:Acomodar(ancho, alto - fijo)
	F.Desp:SetAltoContenido(y + ESP.s)
end

local function construir()
	F = M.Emergente({ nombre = "AlfaMundoCapas", titulo = L["Capas del mapa"], icono = "ic-comunidad", ancho = ANCHO })

	-- El modo limpio, arriba y destacado.
	local lim = CreateFrame("Button", nil, F)
	lim:SetPoint("TOPLEFT", F, "TOPLEFT", ESP.base, -(F.arriba + ESP.m))
	lim:SetPoint("TOPRIGHT", F, "TOPRIGHT", -ESP.base, -(F.arriba + ESP.m))
	lim:SetHeight(60)
	lim:RegisterForClicks("LeftButtonUp")
	lim.caja = K.Caja(lim, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	lim.Icono = K.Icono(lim, "ic-descubrir", 18, "acento")
	lim.Icono:SetPoint("LEFT", lim, "LEFT", ESP.m, 0)
	lim.Interruptor = K.Interruptor(lim, { alCambiar = function(v) Capas.PonerLimpio(v) end })
	lim.Interruptor:SetPoint("RIGHT", lim, "RIGHT", -ESP.m, 0)
	lim.Titulo = K.Texto(lim, "cuerpo", "texto")
	lim.Titulo:SetPoint("TOPLEFT", lim, "TOPLEFT", 42, -ESP.m)
	lim.Titulo:SetPoint("RIGHT", lim.Interruptor, "LEFT", -ESP.s, 0)
	K.Escribir(lim.Titulo, L["Modo limpio"])
	lim.Desc = K.Texto(lim, "pequeno", "textoTenue")
	lim.Desc:SetWordWrap(true)
	lim.Desc:SetPoint("TOPLEFT", lim.Titulo, "BOTTOMLEFT", 0, -3)
	lim.Desc:SetPoint("RIGHT", lim.Interruptor, "LEFT", -ESP.s, 0)
	lim:SetScript("OnClick", Capas.AlternarLimpio)
	F.Limpio = lim

	F.Desp = K.Desplazable(F)
	F.Desp:SetPoint("TOPLEFT", lim, "BOTTOMLEFT", 0, -ESP.s)

	-- Abajo: la página de Mundo para todo lo demás, y el mapa de Alfa.
	local pie = CreateFrame("Frame", nil, F)
	pie:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", 0, 0)
	pie:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", 0, 0)
	pie:SetHeight(PIE)
	pie.Linea = K.Linea(pie, "linea")
	pie.Linea:SetPoint("TOPLEFT", pie, "TOPLEFT", 0, 0)
	pie.Linea:SetPoint("TOPRIGHT", pie, "TOPRIGHT", 0, 0)
	F.Mas = K.Boton(pie, L["Más opciones"], function()
		F:Hide()
		N.Abrir("mundo")
	end, { tipo = "fantasma", tam = "chico", icono = "ic-ajustes" })
	F.Mas:SetPoint("LEFT", pie, "LEFT", ESP.m, 0)
	F.Mapa = K.Boton(pie, L["Abrir el mapa de Alfa"], function()
		F:Hide()
		if AlfaMundo and AlfaMundo.Abrir then AlfaMundo.Abrir(F.alfaMapa) end
	end, { tipo = "acento", tam = "chico", icono = "ic-mundo" })
	F.Mapa:SetPoint("RIGHT", pie, "RIGHT", -ESP.m, 0)

	F:HookScript("OnShow", Panel.Refrescar)
	Capas.AlCambiar(Panel.Refrescar)
end

-- Abre el panel junto a `ancla`, o lo cierra si ya está ahí.
-- opts: { punto, relativo, x, y, sinMapa = true (oculta "Abrir el mapa de Alfa"), mapa = uiMapID }
function Panel.Alternar(ancla, opts)
	if not F then construir() end
	opts = opts or {}
	F.Mapa:SetShown(not opts.sinMapa)
	F.alfaMapa = opts.mapa
	F:Alternar(ancla, opts)
	Panel.Refrescar()
end

function Panel.Ocultar() if F then F:Hide() end end
function Panel.Visible() return F and F:IsShown() or false end
