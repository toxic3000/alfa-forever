-- Alfa - Mundo: el panel de capas que abre el botón del mapa (el de Alfa y
-- el del juego) (Toxic / La Jauría). GPL-3.0.
--
-- Arriba el modo limpio; debajo cada grupo con sus interruptores, los del
-- motor y los de los módulos que registraron capas (también las que llegan
-- con el panel abierto). Escape o la X lo cierran.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local W, T = A.Widgets, A.Theme
local Capas = M.Capas

local type, ipairs, pcall, max, min, floor = type, ipairs, pcall, math.max, math.min, math.floor

local Panel = {}
M.Panel = Panel

local ANCHO, PAD, CAB, FILA, TITULO_G, ALTO_MAX = 320, 14, 46, 30, 26, 540

local F
local filas, titulos = {}, {}

local function cerrar() if F then F:Hide() end end

local function fila(i)
	local r = filas[i]
	if r then return r end
	r = CreateFrame("Button", nil, F.Scroll.Child)
	r:SetHeight(FILA)
	W.Hover(r)
	r.Icono = r:CreateTexture(nil, "ARTWORK")
	r.Icono:SetSize(16, 16)
	r.Icono:SetPoint("LEFT", r, "LEFT", 6, 0)
	r.Texto = W.Text(r, "label", "text")
	r.Texto:SetPoint("LEFT", r, "LEFT", 30, 0)
	r.Switch = W.Switch(r, function() return r.amCapa and Capas.Valor(r.amCapa) or false end,
		function(on) if r.amCapa then Capas.Poner(r.amCapa, on) end end)
	r.Switch:SetPoint("RIGHT", r, "RIGHT", -2, 0)
	r.Texto:SetPoint("RIGHT", r.Switch, "LEFT", -6, 0)
	r:SetScript("OnClick", function(self)
		if self.amCapa and self.amLibre then Capas.Poner(self.amCapa, not Capas.Valor(self.amCapa)) end
	end)
	r:SetScript("OnEnter", function(self)
		local e = self.amCapa
		if not e then return end
		local lineas = {}
		if e.ayuda then lineas[#lineas + 1] = e.ayuda end
		if not self.amLibre and self.amPorque then lineas[#lineas + 1] = { self.amPorque, T.Color("warning") } end
		if e.esencial then lineas[#lineas + 1] = { L["Se queda en el modo limpio."], T.Color("textMuted") } end
		W.Tooltip(self, "ANCHOR_LEFT", e.nombre, lineas)
	end)
	r:SetScript("OnLeave", W.HideTip)
	filas[i] = r
	return r
end

local function titulo(i)
	local h = titulos[i]
	if h then return h end
	h = W.Text(F.Scroll.Child, "caption", "textMuted")
	titulos[i] = h
	return h
end

local function pintarFila(r, e)
	r.amCapa = e
	local libre, porque = Capas.Disponible(e)
	r.amLibre, r.amPorque = libre, porque
	r.Texto:SetText(e.nombre)
	if type(e.icono) == "string" or type(e.icono) == "number" then
		r.Icono:SetTexture(e.icono)
		if e.color then W.Color(r.Icono, e.color) else W.Uncolor(r.Icono) r.Icono:SetVertexColor(1, 1, 1, 1) end
		r.Icono:Show()
	else
		r.Icono:Hide()
	end
	W.Color(r.Texto, libre and "text" or "textMuted")
	r.Switch:SetAlpha(libre and 1 or 0.4)
	r.Switch:EnableMouse(libre)
	r.Switch:Refresh()
end

local function pintarLimpio()
	local on = Capas.Limpio()
	F.Limpio.Switch:Refresh()
	if on then
		local n = Capas.CuantasOcultas()
		F.Limpio.Desc:SetText(n > 0 and string.format(L["%d capas ocultas. Apágalo para volver a verlas."], n)
			or L["Solo tú, tu grupo y el siguiente paso de la guía."])
		W.Color(F.Limpio.Titulo, "accent")
	else
		F.Limpio.Desc:SetText(L["Un clic y queda solo lo esencial: tú, tu grupo y el siguiente paso de la guía."])
		W.Color(F.Limpio.Titulo, "text")
	end
end

function Panel.Refrescar()
	if not (F and F:IsShown()) then return end
	pintarLimpio()
	local ancho = ANCHO - PAD * 2
	local y, nf, nt = 4, 0, 0
	for _, g in ipairs(Capas.Grupos()) do
		nt = nt + 1
		local h = titulo(nt)
		h:SetText(g.nombre)
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", F.Scroll.Child, "TOPLEFT", 6, -(y + 10))
		h:Show()
		y = y + TITULO_G
		for _, e in ipairs(g.capas) do
			nf = nf + 1
			local r = fila(nf)
			pintarFila(r, e)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", F.Scroll.Child, "TOPLEFT", 0, -y)
			r:SetWidth(ancho)
			r:Show()
			y = y + FILA
		end
	end
	for i = nf + 1, #filas do filas[i]:Hide() end
	for i = nt + 1, #titulos do titulos[i]:Hide() end
	F.Scroll.Child:SetWidth(ancho)
	local fijo = CAB + F.Limpio:GetHeight() + 12 + 36
	local alto = min(ALTO_MAX, fijo + y + 8)
	F:SetHeight(alto)
	W.SetScrollContent(F.Scroll, y + 8, alto - fijo)
end

local function construir()
	F = CreateFrame("Frame", "AlfaMundoCapas", A.UIParent)
	F:SetFrameStrata("FULLSCREEN_DIALOG")
	F:SetToplevel(true)
	F:SetClampedToScreen(true)
	F:EnableMouse(true)
	F:SetSize(ANCHO, 400)
	F:Hide()
	T.Skin(F, "window")
	W.Rim(F, { width = ANCHO * 0.7 })

	local cab = CreateFrame("Frame", nil, F)
	cab:SetPoint("TOPLEFT", F, "TOPLEFT", 0, 0)
	cab:SetPoint("TOPRIGHT", F, "TOPRIGHT", 0, 0)
	cab:SetHeight(CAB)
	F.Icono = cab:CreateTexture(nil, "ARTWORK")
	F.Icono:SetTexture(T.Media("layers"))
	F.Icono:SetSize(18, 18)
	F.Icono:SetPoint("LEFT", cab, "LEFT", PAD, 0)
	W.Color(F.Icono, "accent")
	F.Titulo = W.Text(cab, "title", "text")
	F.Titulo:SetPoint("LEFT", F.Icono, "RIGHT", 8, 0)
	F.Titulo:SetText(L["Capas del mapa"])
	F.Cerrar = W.IconButton(cab, "close", 24, L["Cerrar"], cerrar, 12)
	F.Cerrar:SetPoint("RIGHT", cab, "RIGHT", -8, 0)
	local regla = W.Divider(F)
	regla:SetPoint("TOPLEFT", cab, "BOTTOMLEFT", 0, 0)
	regla:SetPoint("TOPRIGHT", cab, "BOTTOMRIGHT", 0, 0)

	-- El modo limpio, arriba y destacado.
	local lim = CreateFrame("Button", nil, F)
	lim:SetPoint("TOPLEFT", F, "TOPLEFT", PAD, -(CAB + 10))
	lim:SetPoint("TOPRIGHT", F, "TOPRIGHT", -PAD, -(CAB + 10))
	lim:SetHeight(54)
	T.Skin(lim, "tile")
	lim.Icono = lim:CreateTexture(nil, "ARTWORK")
	lim.Icono:SetTexture(T.Media("compact"))
	lim.Icono:SetSize(18, 18)
	lim.Icono:SetPoint("LEFT", lim, "LEFT", 12, 0)
	W.Color(lim.Icono, "accent")
	lim.Switch = W.Switch(lim, Capas.Limpio, function(on) Capas.PonerLimpio(on) end)
	lim.Switch:SetPoint("RIGHT", lim, "RIGHT", -6, 0)
	lim.Titulo = W.Text(lim, "body", "text")
	lim.Titulo:SetPoint("TOPLEFT", lim, "TOPLEFT", 40, -10)
	lim.Titulo:SetPoint("RIGHT", lim.Switch, "LEFT", -6, 0)
	lim.Titulo:SetText(L["Modo limpio"])
	lim.Desc = W.Text(lim, "small", "textMuted")
	lim.Desc:SetWordWrap(true)
	lim.Desc:SetPoint("TOPLEFT", lim.Titulo, "BOTTOMLEFT", 0, -3)
	lim.Desc:SetPoint("RIGHT", lim.Switch, "LEFT", -6, 0)
	lim:SetScript("OnClick", Capas.AlternarLimpio)
	F.Limpio = lim

	F.Scroll = W.Scroll(F)
	F.Scroll:SetPoint("TOPLEFT", lim, "BOTTOMLEFT", 0, -2)
	F.Scroll:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -PAD + 4, 40)

	-- Abajo: a la página de Mundo para todo lo demás.
	local pie = W.Divider(F)
	pie:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", 0, 36)
	pie:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", 0, 36)
	F.Mas = W.Link(F, L["Más opciones"], function()
		cerrar()
		N.Abrir("mundo")
	end)
	F.Mas:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", PAD, 10)
	F.Mapa = W.Link(F, L["Abrir el mapa de Alfa"], function()
		cerrar()
		if AlfaMundo and AlfaMundo.Abrir then AlfaMundo.Abrir() end
	end)
	F.Mapa:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -PAD, 10)

	F:SetScript("OnShow", function(self)
		Panel.Refrescar()
		local An = A.Anim
		if An and An.To then An.To(self, "alpha", 0, 1, An.FAST, "out") end
	end)
	if A.CloseOnEscape then A.CloseOnEscape("AlfaMundoCapas") end
	Capas.AlCambiar(Panel.Refrescar)
end

-- Abre el panel junto a `ancla` (o en el centro), o lo cierra si ya está ahí.
-- opts: { punto, relativo, x, y, sinMapa = true (oculta "Abrir el mapa de Alfa") }
function Panel.Alternar(ancla, opts)
	if not F then construir() end
	if F:IsShown() and F.amAncla == ancla then
		F:Hide()
		return
	end
	opts = opts or {}
	F.amAncla = ancla
	F:ClearAllPoints()
	if ancla then
		F:SetPoint(opts.punto or "TOPRIGHT", ancla, opts.relativo or "BOTTOMRIGHT", opts.x or 0, opts.y or -6)
	else
		F:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	F.Mapa:SetShown(not opts.sinMapa)
	F:Show()
	F:Raise()
end

function Panel.Ocultar() cerrar() end
function Panel.Visible() return F and F:IsShown() or false end
