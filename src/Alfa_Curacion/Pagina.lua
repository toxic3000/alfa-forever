-- Alfa - Curación: su página en la ventana de Alfa (Toxic / La Jauría). GPL-3.0.
--
-- De arriba abajo, en pocas palabras:
--   1. Una tarjeta con el estado (clase, preajuste, grupo) y los botones de
--      prueba y de mover los marcos.
--   2. Tu ratón: una cuadrícula con los tres botones (izquierdo, central y
--      derecho) sin tecla y con Mayús, Ctrl y Alt. Clic en una casilla para
--      elegir un hechizo de tu libro, seleccionar o el menú.
--   3. Los preajustes de tu clase, "el clic izquierdo solo selecciona" y
--      "usar también en los marcos de Blizzard".
--   4. Los ajustes de los marcos.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local W, T = A.Widgets, A.Theme
local L = M.L
local ID = M.ID

local floor, max, min, ceil, format = math.floor, math.max, math.min, math.ceil, string.format

local DOT = "  \194\183  "
local INSET, HIJO, GAP = 16, 40, 22
local CELDA_H, ETIQ, ENTRE = 46, 82, 8
local ICONO_VACIO = "Interface\\Icons\\INV_Misc_QuestionMark"

local function ancho()
	local O = A.UI and A.UI.Options
	local win = O and O.frame
	local w = win and win.BodyWidth
	if type(w) ~= "number" or w <= 0 then w = 640 end
	return w
end

local function margen()
	local p = W.SHELL and W.SHELL.pad
	return type(p) == "number" and p or 24
end

local function enCasa() return T.SkinKey() == "alfa" end

---------------------------------------------------------------------------
-- Textos de estado
---------------------------------------------------------------------------

local function queHace(e)
	if type(e) ~= "table" or e.t == "nada" then return L["no hace nada"] end
	if e.t == "spell" then return M.NombreHechizo(e.id) or L["un hechizo"] end
	if e.t == "target" then return L["selecciona"] end
	if e.t == "menu" then return L["abre su menú"] end
	return L["no hace nada"]
end

local function grupo()
	local n = 0
	if GetNumGroupMembers then
		local ok, v = pcall(GetNumGroupMembers)
		n = ok and tonumber(v) or 0
	end
	if IsInRaid and IsInRaid() then return format(L["Banda de %d"], n), "accent" end
	if IsInGroup and IsInGroup() then return format(L["Grupo de %d"], n), "accent" end
	return L["Solo"], nil
end

-- ¿Cambiaste algo a mano después del preajuste?
local function aMano()
	for _, e in pairs(M.Mapa()) do
		if type(e) == "table" and not e.p then return true end
	end
	return false
end

-- -> título, texto, chip, tipo de chip
local function estado()
	local clase = M.Clase()
	if not N.Get(ID, "activo") then
		return L["Los marcos de Curación están apagados"],
			L["Enciéndelos abajo, en Marcos, para ver a tu grupo con su vida y curar con un clic."], L["Apagados"], nil
	end
	if M.EnPrueba() then
		return L["Modo prueba"],
			L["Así se verán tus marcos. Arrástralos para moverlos y cambia su tamaño abajo. Pulsa Listo cuando termines."],
			L["Prueba"], "warning"
	end
	local mapa = M.Mapa()
	local texto = format(L["Pasa el ratón sobre un compañero y haz clic: el izquierdo %s y el derecho %s."],
		queHace(mapa["1"]), queHace(mapa["2"]))
	if M.EnCombate() then texto = texto .. " " .. L["Estás en combate: lo que cambies se aplica al salir."] end
	if M.EsCurandero(clase) then return L["Listo para curar"], texto, L["Listo"], "success" end
	return L["Listo para ayudar a tu grupo"], texto, L["Listo"], "success"
end

local function chipsDeEstado()
	local t = {}
	local _, nombreClase = M.Clase()
	if nombreClase then t[#t + 1] = { nombreClase, "accent" } end
	local pre = M.PREAJUSTES[M.Datos().preajuste or ""]
	if pre then
		t[#t + 1] = { aMano() and format(L["%s, a tu gusto"], pre.nombre) or pre.nombre }
	end
	local texto, tipo = grupo()
	t[#t + 1] = { texto, tipo }
	return t
end

---------------------------------------------------------------------------
-- La tarjeta de estado
---------------------------------------------------------------------------

local function crearTarjeta(view)
	local c = CreateFrame("Frame", nil, view)
	c.Fondo = W.RowPanel(view)
	c.Fondo:SetAllPoints(c)
	c.Disco = W.Tex(c, "ARTWORK", "circle")
	c.Disco:SetSize(44, 44)
	c.Disco:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -16)
	W.Painter(c.Disco, function(t)
		local r, g, b = T.Accent()
		t:SetVertexColor(r, g, b, 0.16)
	end)
	c.Icono = W.Tex(c, "OVERLAY", "plus", "accent")
	c.Icono:SetSize(22, 22)
	c.Icono:SetPoint("CENTER", c.Disco, "CENTER", 0, 0)
	c.Titulo = W.Text(c, "title", "text")
	c.Estado = W.Chip(c)
	c.Texto = W.Text(c, "note", "textDim")
	c.Texto:SetWordWrap(true)
	c.Texto:SetSpacing(2)
	c.Texto:SetJustifyV("TOP")
	c.Chips = { W.Chip(c), W.Chip(c), W.Chip(c) }
	c.Probar5 = W.Button(c, L["Probar con 5"], function()
		if M.EnPrueba() == 5 then M.Prueba(nil) else M.Prueba(5) end
	end, { primary = true })
	c.Probar20 = W.Button(c, L["Probar con 20"], function()
		if M.EnPrueba() == 20 then M.Prueba(nil) else M.Prueba(20) end
	end)
	c.Mover = W.Button(c, L["Mover marcos"], function() M.Mover(not M.Moviendo()) end, { ghost = true })
	return c
end

-- -> alto de la tarjeta
local function ordenarTarjeta(c, width)
	c:SetWidth(width)
	c.Fondo:SetShown(enCasa())
	local titulo, texto, chip, tipo = estado()
	local cw = W.SetChip(c.Estado, chip, tipo)
	c.Titulo:ClearAllPoints()
	c.Titulo:SetPoint("TOPLEFT", c, "TOPLEFT", 76, -18)
	c.Titulo:SetWidth(0)
	c.Titulo:SetText(titulo)
	c.Titulo:SetWidth(max(40, min(ceil(W.TextWidth(c.Titulo)) + 2, width - 76 - 16 - cw - 10)))
	c.Estado:ClearAllPoints()
	c.Estado:SetPoint("LEFT", c.Titulo, "RIGHT", 10, 0)
	c.Texto:SetWidth(width - 76 - 16)
	c.Texto:SetText(texto)
	c.Texto:ClearAllPoints()
	c.Texto:SetPoint("TOPLEFT", c, "TOPLEFT", 76, -42)
	local y = 42 + ceil(c.Texto:GetStringHeight()) + 12

	local x, datos = 76, chipsDeEstado()
	for i, ch in ipairs(c.Chips) do
		local d = datos[i]
		if d then
			local w = W.SetChip(ch, d[1], d[2])
			ch:ClearAllPoints()
			ch:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
			x = x + w + 6
		else
			ch:Hide()
		end
	end
	y = y + W.CHIP_H + 14

	local prueba = M.EnPrueba()
	W.SetButtonText(c.Probar5, prueba == 5 and L["Quitar la prueba"] or L["Probar con 5"])
	W.SetButtonText(c.Probar20, prueba == 20 and L["Quitar la prueba"] or L["Probar con 20"])
	W.SetButtonText(c.Mover, M.Moviendo() and L["Fijar marcos"] or L["Mover marcos"])
	x = 76
	for _, b in ipairs({ c.Probar5, c.Probar20, c.Mover }) do
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
		x = x + b:GetWidth() + 8
	end
	y = max(y + c.Probar5:GetHeight() + 16, 16 + 44 + 16)
	c:SetHeight(y)
	return y
end

---------------------------------------------------------------------------
-- Tu ratón: la cuadrícula
---------------------------------------------------------------------------

local function crearRaton(padre)
	local f = CreateFrame("Frame", nil, padre)
	f:SetSize(18, 26)
	f.Izq = W.Tex(f, "ARTWORK")
	f.Izq:SetSize(8, 10)
	f.Izq:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.Der = W.Tex(f, "ARTWORK")
	f.Der:SetSize(8, 10)
	f.Der:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	f.Rueda = W.Tex(f, "OVERLAY")
	f.Rueda:SetSize(2, 7)
	f.Rueda:SetPoint("TOP", f, "TOP", 0, -2)
	f.Cuerpo = W.Tex(f, "ARTWORK")
	f.Cuerpo:SetSize(18, 14)
	f.Cuerpo:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
	return f
end

local function marcarRaton(f, s)
	W.Color(f.Izq, s == "1" and "accent" or "textMuted", s == "1" and 1 or 0.35)
	W.Color(f.Der, s == "2" and "accent" or "textMuted", s == "2" and 1 or 0.35)
	W.Color(f.Rueda, s == "3" and "accent" or "textMuted", s == "3" and 1 or 0.6)
	W.Color(f.Cuerpo, "textMuted", 0.35)
end

local abrirMenu

local function pintarCelda(b)
	local e = M.Mapa()[b.ranura]
	local t = type(e) == "table" and e.t or "nada"
	if t == "spell" then
		b.Icono:SetTexture(M.IconoHechizo(e.id) or ICONO_VACIO)
		b.Icono:Show()
		b.Glifo:Hide()
		b.Nombre:SetText(M.NombreHechizo(e.id) or L["Hechizo desconocido"])
		W.Color(b.Nombre, "text")
		b.Tipo:SetText(e.p and L["Hechizo del preajuste"] or L["Hechizo elegido por ti"])
	else
		b.Icono:Hide()
		b.Glifo:Show()
		if t == "target" then
			b.Glifo:SetTexture(T.Media("qol-target"))
			W.Color(b.Glifo, "accent")
			b.Nombre:SetText(L["Seleccionar objetivo"])
			W.Color(b.Nombre, "text")
			b.Tipo:SetText(L["Lo marca como tu objetivo"])
		elseif t == "menu" then
			b.Glifo:SetTexture(T.Media("menu"))
			W.Color(b.Glifo, "accent")
			b.Nombre:SetText(L["Menú del jugador"])
			W.Color(b.Nombre, "text")
			b.Tipo:SetText(L["Invitar, comerciar, susurrar…"])
		else
			b.Glifo:SetTexture(T.Media("plus"))
			W.Color(b.Glifo, "textMuted", 0.6)
			b.Nombre:SetText(L["Sin acción"])
			W.Color(b.Nombre, "textMuted")
			b.Tipo:SetText(L["Clic para elegir"])
		end
	end
end

local function tooltipCelda(self)
	local e = M.Mapa()[self.ranura]
	local pista = { L["Clic: elegir qué hace."], L["Clic derecho: dejarla sin acción."] }
	if type(e) == "table" and e.t == "spell" and type(e.id) == "number" then
		W.SpellTip(self, e.id, function(tip)
			tip:AddLine(" ")
			tip:AddLine(M.NombreRanura(self.ranura), 0.55, 0.88, 0.31)
			for _, l in ipairs(pista) do tip:AddLine(l, 0.62, 0.65, 0.73, true) end
		end)
	else
		W.Tooltip(self, "ANCHOR_RIGHT", M.NombreRanura(self.ranura), pista)
	end
end

local function crearCelda(view, ranura)
	local b = CreateFrame("Button", nil, view)
	b:SetHeight(CELDA_H)
	T.Skin(b, "tile")
	W.Hover(b, 0.7)
	b.ranura = ranura
	b.Icono = b:CreateTexture(nil, "ARTWORK")
	b.Icono:SetSize(26, 26)
	b.Icono:SetPoint("LEFT", b, "LEFT", 10, 0)
	b.Glifo = W.Tex(b, "ARTWORK", "plus", "textMuted")
	b.Glifo:SetSize(16, 16)
	b.Glifo:SetPoint("CENTER", b.Icono, "CENTER", 0, 0)
	b.Nombre = W.Text(b, "label", "text")
	b.Nombre:SetPoint("TOPLEFT", b.Icono, "TOPRIGHT", 8, -1)
	b.Nombre:SetPoint("RIGHT", b, "RIGHT", -8, 0)
	b.Tipo = W.Text(b, "small", "textMuted")
	b.Tipo:SetPoint("BOTTOMLEFT", b.Icono, "BOTTOMRIGHT", 8, 1)
	b.Tipo:SetPoint("RIGHT", b, "RIGHT", -8, 0)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(self, boton)
		W.HideTooltip(self)
		if boton == "RightButton" then
			W.HideMenu()
			M.FijarRanura(self.ranura, { t = "nada" })
		else
			abrirMenu(self)
		end
	end)
	b:SetScript("OnEnter", tooltipCelda)
	b:SetScript("OnLeave", function(self) W.HideTooltip(self) end)
	return b
end

abrirMenu = function(celda)
	if W.MenuShown(celda) then return W.HideMenu() end
	local r = celda.ranura
	local actual = M.Mapa()[r]
	local t = type(actual) == "table" and actual.t or "nada"
	local nombreActual = t == "spell" and M.NombreHechizo(actual.id) or nil
	local items = {
		{ text = L["Sin acción"], checked = t == "nada", onClick = function() M.FijarRanura(r, { t = "nada" }) end },
		{ text = L["Seleccionar objetivo"], checked = t == "target", onClick = function() M.FijarRanura(r, { t = "target" }) end },
	}
	if M.PermiteMenu(r) then
		items[#items + 1] = { text = L["Menú del jugador"], checked = t == "menu", onClick = function() M.FijarRanura(r, { t = "menu" }) end }
	end
	items[#items + 1] = { separator = true }
	local libro = M.HechizosDelLibro()
	if #libro == 0 then
		items[#items + 1] = { text = L["Tu libro no tiene hechizos para aliados"], disabled = true }
	end
	for _, h in ipairs(libro) do
		local id = h.id
		items[#items + 1] = {
			text = h.nombre, checked = nombreActual == h.nombre,
			onClick = function() M.FijarRanura(r, { t = "spell", id = id }) end,
		}
	end
	W.ShowMenu(celda, items, { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 0, y = -2, minWidth = max(200, celda:GetWidth()) })
end

local function crearMapa(view, ui)
	ui.mapaEnc = W.SectionHeader(view, { plain = true })
	ui.mapaPanel = W.RowPanel(view)
	ui.cols = {}
	for i, bt in ipairs(M.BOTONES) do
		local h = CreateFrame("Frame", nil, view)
		h:SetHeight(30)
		h.Raton = crearRaton(h)
		h.Raton:SetPoint("LEFT", h, "LEFT", 2, 0)
		marcarRaton(h.Raton, bt.s)
		h.Texto = W.Text(h, "label", "textDim")
		h.Texto:SetPoint("LEFT", h.Raton, "RIGHT", 8, 0)
		h.Texto:SetText(bt.nombre)
		ui.cols[i] = h
	end
	ui.filas, ui.celdas = {}, {}
	for i, md in ipairs(M.MODS) do
		local t = W.Text(view, "label", i == 1 and "textDim" or "text")
		t:SetText(i == 1 and md.nombre or (md.nombre .. " +"))
		ui.filas[i] = t
		for _, bt in ipairs(M.BOTONES) do
			local r = md.p .. bt.s
			ui.celdas[r] = crearCelda(view, r)
		end
	end
	ui.mapaNota = W.Text(view, "note", "textMuted")
	ui.mapaNota:SetWordWrap(true)
	ui.mapaNota:SetJustifyV("TOP")
	ui.mapaAviso = W.Text(view, "note", "warning")
	ui.mapaAviso:SetWordWrap(true)
	ui.mapaAviso:SetJustifyV("TOP")
end

local function ordenarMapa(view, ui, y, width, x)
	W.SetSection(ui.mapaEnc, L["Tu ratón"])
	ui.mapaEnc:ClearAllPoints()
	ui.mapaEnc:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
	ui.mapaEnc:SetWidth(width)
	y = y + W.PLAIN_SECTION_H
	local top = y
	local inner = width - 2 * INSET
	local colW = floor((inner - ETIQ - 2 * ENTRE) / 3)
	y = y + 12
	for i, h in ipairs(ui.cols) do
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", view, "TOPLEFT", x + INSET + ETIQ + (i - 1) * (colW + ENTRE), -y)
		h:SetWidth(colW)
	end
	y = y + 30 + 6
	for i, md in ipairs(M.MODS) do
		local t = ui.filas[i]
		t:ClearAllPoints()
		t:SetPoint("LEFT", view, "TOPLEFT", x + INSET, -(y + CELDA_H / 2))
		t:SetWidth(ETIQ - 8)
		for j, bt in ipairs(M.BOTONES) do
			local celda = ui.celdas[md.p .. bt.s]
			celda:ClearAllPoints()
			celda:SetPoint("TOPLEFT", view, "TOPLEFT", x + INSET + ETIQ + (j - 1) * (colW + ENTRE), -y)
			celda:SetWidth(colW)
			pintarCelda(celda)
		end
		y = y + CELDA_H + 6
	end
	y = y + 6
	ui.mapaNota:SetWidth(inner)
	ui.mapaNota:SetText(L["Clic en una casilla para elegir qué hace sobre el compañero bajo tu ratón; clic derecho la deja sin acción. Los cambios se aplican fuera de combate."])
	ui.mapaNota:ClearAllPoints()
	ui.mapaNota:SetPoint("TOPLEFT", view, "TOPLEFT", x + INSET, -y)
	y = y + ceil(ui.mapaNota:GetStringHeight()) + 10
	local choques = M.ChoquesBlizzard()
	if choques > 0 then
		ui.mapaAviso:SetWidth(inner)
		ui.mapaAviso:SetText(format(L["Ojo: tu clic para lanzar de Blizzard usa %d de estas teclas, y ese manda también aquí. Para igualarlos, usa «Usar también en los marcos de Blizzard»."], choques))
		ui.mapaAviso:ClearAllPoints()
		ui.mapaAviso:SetPoint("TOPLEFT", view, "TOPLEFT", x + INSET, -y)
		ui.mapaAviso:Show()
		y = y + ceil(ui.mapaAviso:GetStringHeight()) + 10
	else
		ui.mapaAviso:Hide()
	end
	y = y + 4
	ui.mapaPanel:ClearAllPoints()
	ui.mapaPanel:SetPoint("TOPLEFT", view, "TOPLEFT", x, -top)
	ui.mapaPanel:SetSize(width, max(1, y - top))
	ui.mapaPanel:SetShown(enCasa())
	return y
end

---------------------------------------------------------------------------
-- Preajustes
---------------------------------------------------------------------------

local function descripcionPreajuste(pre)
	local mapa = M.Resolver(pre, M.IzquierdoSelecciona())
	local resumen = M.ResumenDe(mapa, 4)
	if pre == "cero" then
		return L["El izquierdo selecciona y el derecho abre el menú. Tú eliges el resto."]
	end
	if pre == "buffs" then
		if resumen == "" then return L["El izquierdo selecciona y el derecho abre el menú; tu clase no tiene buffs para otros."] end
		return L["El izquierdo selecciona y el derecho abre el menú."] .. DOT .. resumen
	end
	if resumen == "" then return L["Todavía no conoces sus hechizos: se llenan al aprenderlos."] end
	return resumen
end

local function tituloPreajuste(pre)
	local P = M.PREAJUSTES[pre]
	local titulo = P and P.nombre or pre
	if pre == "curar" then
		local _, nombreClase = M.Clase()
		if nombreClase then titulo = format(L["%s (%s)"], titulo, nombreClase) end
	end
	if M.Datos().preajuste == pre then titulo = titulo .. DOT .. L["en uso"] end
	return titulo
end

local function usarPreajuste(pre)
	local P = M.PREAJUSTES[pre]
	if not P then return end
	if aMano() then
		W.Modal({
			title = format(L["¿Usar «%s»?"], P.nombre), icon = P.icono,
			text = L["Tus clics vuelven a los del preajuste. Lo que cambiaste a mano se pierde."],
			action = L["Usarlo"],
			onAccept = function() M.AplicarPreajuste(pre) end,
		})
	else
		M.AplicarPreajuste(pre)
	end
end

local function fila(w, hijo)
	W.RowDetails(w, { inset = hijo and HIJO or INSET, child = hijo })
	return w
end

local function crearPreajustes(view, ui)
	ui.preEnc = W.SectionHeader(view, { plain = true })
	ui.tiles = {}
	for _, pre in ipairs(M.PreajustesDe()) do
		local P = M.PREAJUSTES[pre]
		ui.tiles[#ui.tiles + 1] = { pre = pre, tile = W.ActionTile(view, P.icono, P.nombre, "", function() usarPreajuste(pre) end) }
	end
	ui.prePanel = W.RowPanel(view)
	local izq = fila(W.Toggle(view, L["El clic izquierdo solo selecciona"], nil,
		L["Para quien prefiere seleccionar con el izquierdo: la cura de ese clic pasa al botón central. Se vuelve a aplicar tu preajuste."],
		nil, { get = M.IzquierdoSelecciona, set = function(v) M.FijarIzquierdoSelecciona(v == true) end }))
	W.SetDisabledWhen(izq, function() return M.Datos().preajuste ~= "curar" end)
	ui.blizzard = fila(W.ActionRow(view, L["Usar también en los marcos de Blizzard"], "", L["Usar"],
		function() M.UsarEnBlizzard() end))
	ui.preFilas = { izq, ui.blizzard }
end

local BASE_BLIZZARD = L["Copia tu mapa al clic para lanzar de Blizzard, así curas igual en sus marcos de grupo. Si el juego no lo deja, abre su ventana para que lo hagas ahí."]

local function colocarFilas(view, filas, y, panel, width, x)
	local top = y
	for i, w in ipairs(filas) do
		w:ClearAllPoints()
		w:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		w:Show()
		if w.Refresh then w:Refresh() end
		y = y + W.LayoutRow(w, width)
		if w.Rule then w.Rule:SetShown(i < #filas) end
	end
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", view, "TOPLEFT", x, -top)
	panel:SetSize(width, max(1, y - top))
	panel:SetShown(enCasa())
	return y
end

local function ordenarPreajustes(view, ui, y, width, x)
	W.SetSection(ui.preEnc, L["Preajustes listos para usar"])
	ui.preEnc:ClearAllPoints()
	ui.preEnc:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
	ui.preEnc:SetWidth(width)
	y = y + W.PLAIN_SECTION_H
	for _, t in ipairs(ui.tiles) do
		local b = t.tile
		local titulo = tituloPreajuste(t.pre)
		b.psTitle = titulo
		b.Title:SetText(titulo)
		W.Color(b.Title, "text")
		b.Desc:SetText(descripcionPreajuste(t.pre))
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		y = y + W.LayoutTile(b, width) + 8
	end
	y = y + 6
	-- El resultado del último intento con Blizzard, bajo la fila.
	local r = M.Datos().blizzard
	local desc = BASE_BLIZZARD
	if type(r) == "table" and type(r.texto) == "string" then desc = desc .. "\n" .. r.texto end
	local fb = ui.blizzard
	fb.psDesc = desc
	if rawget(fb, "Help") then
		fb.Help:SetText(desc)
		fb.Help:Show()
		fb.psTip, fb.psTipLines = nil, nil
	end
	return colocarFilas(view, ui.preFilas, y, ui.prePanel, width, x)
end

---------------------------------------------------------------------------
-- Ajustes de los marcos
---------------------------------------------------------------------------

local function condicion(w, padre)
	W.SetDisabledWhen(w, function()
		if not N.Get(ID, "activo") then return true end
		return padre ~= nil and not N.Get(ID, padre)
	end)
	return w
end

local function px(v) return format(L["%d px"], floor((tonumber(v) or 0) + 0.5)) end
local function entero(v) return tostring(floor((tonumber(v) or 0) + 0.5)) end

local function grupos(view)
	local p = ID .. "."
	return {
		{ titulo = L["Marcos"], filas = {
			fila(W.Toggle(view, L["Usar los marcos de Alfa"], p .. "activo",
				L["Tu grupo y tu banda con su vida, para curar con un clic. Se cambia fuera de combate."])),
			fila(condicion(W.Toggle(view, L["Verte a ti estando solo"], p .. "solo",
				L["Tu propio marco aparece aunque no estés en grupo, para curarte con un clic."]))),
			fila(condicion(W.Toggle(view, L["Ocultar los marcos de grupo de Blizzard"], p .. "ocultarBlizzard",
				L["Para no ver dos veces a tu grupo. Se cambia fuera de combate."]))),
			fila(condicion(W.Slider(view, L["Ancho"], p .. "ancho", 50, 200, 2, px,
				L["Lo ancho de cada compañero."]))),
			fila(condicion(W.Slider(view, L["Alto"], p .. "alto", 20, 80, 1, px,
				L["Lo alto de cada compañero."]))),
			fila(condicion(W.Slider(view, L["Compañeros por columna"], p .. "porColumna", 1, 40, 1, entero,
				L["Cuántos van en cada columna (o fila) antes de empezar otra. 5 es un grupo por columna."]))),
			fila(condicion(W.Dropdown(view, L["Crecen hacia"], p .. "crecer", {
				{ value = "abajo", text = L["Abajo"] }, { value = "derecha", text = L["La derecha"] },
			}, L["Hacia dónde se acomodan tus compañeros."]))),
			fila(condicion(W.Dropdown(view, L["Orden"], p .. "orden", {
				{ value = "grupo", text = L["Por grupo"] }, { value = "rol", text = L["Por rol"] },
				{ value = "clase", text = L["Por clase"] }, { value = "nombre", text = L["Por nombre"] },
			}, L["En qué orden aparecen."]))),
		} },
		{ titulo = L["Qué muestran"], filas = {
			fila(condicion(W.Toggle(view, L["Color de clase"], p .. "colorClase",
				L["La barra de vida con el color de la clase de cada uno. Apagado: barra verde y el nombre con su color."]))),
			fila(condicion(W.Toggle(view, L["Curas que van llegando"], p .. "entrantes",
				L["Una franja verde clara muestra las curas que ya vienen en camino."]))),
			fila(condicion(W.Toggle(view, L["Amenaza"], p .. "amenaza",
				L["Una línea roja arriba avisa cuando un enemigo va por ese compañero."]))),
			fila(condicion(W.Toggle(view, L["Perjuicios que puedes quitar"], p .. "disipar",
				L["El borde toma el color del perjuicio (magia, maldición, enfermedad o veneno) cuando tú lo puedes quitar."]))),
			fila(condicion(W.Toggle(view, L["Porcentaje de vida"], p .. "porcentaje",
				L["Muestra la vida en número, debajo del nombre."]))),
			fila(condicion(W.Toggle(view, L["Atenuar a quien está lejos"], p .. "alcance",
				L["Si está fuera de tu alcance, su marco se ve más tenue."]))),
			fila(condicion(W.Toggle(view, L["Detalle al pasar el ratón"], p .. "descripcion",
				L["El cuadro del jugador al pasar el ratón. En combate no sale, para no estorbar."]))),
		} },
		{ titulo = L["Lugar"], filas = {
			fila(W.ActionRow(view, L["Volver a su lugar"], L["Pone los marcos donde estaban al instalar Alfa."],
				L["Reiniciar"], function() M.ReiniciarPosicion() end, { icon = "reset" })),
		} },
	}
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

local function ordenar(view, ui)
	local width, x = ancho(), margen()
	local y = 16
	ui.tarjeta:ClearAllPoints()
	ui.tarjeta:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
	y = y + ordenarTarjeta(ui.tarjeta, width) + GAP
	y = ordenarMapa(view, ui, y, width, x) + GAP
	y = ordenarPreajustes(view, ui, y, width, x) + GAP
	for i, g in ipairs(ui.grupos) do
		W.SetSection(g.encabezado, g.titulo)
		g.encabezado:ClearAllPoints()
		g.encabezado:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		g.encabezado:SetWidth(width)
		y = y + W.PLAIN_SECTION_H
		y = colocarFilas(view, g.filas, y, g.panel, width, x)
		if i < #ui.grupos then y = y + GAP end
	end
	return y + 24
end

local function construir(view)
	local ui = { tarjeta = crearTarjeta(view) }
	crearMapa(view, ui)
	crearPreajustes(view, ui)
	ui.grupos = grupos(view)
	for _, g in ipairs(ui.grupos) do
		g.encabezado = W.SectionHeader(view, { plain = true })
		g.panel = W.RowPanel(view)
	end
	view.Refresh = function() return ordenar(view, ui) end
	M.vista = view
end

-- Algo cambió (tu grupo, tu mapa, la prueba...): la página se rehace si está a la vista.
M.alCambiar = function()
	local view = M.vista
	if not (view and view.Refresh and view.IsVisible and view:IsVisible()) then return end
	local h = view.Refresh()
	view:SetHeight(h)
	local O = A.UI and A.UI.Options
	if O and O.frame then W.ShellBody(O.frame, h) end
end

N.Modulo({
	id = ID, nombre = L["Curación"], icono = "plus", orden = 16,
	subtitulo = L["Marcos de grupo y banda para curar con un clic, con preajustes por clase."],
	comando = "curacion",
	ajustes = M.AJUSTES,
	construir = construir,
})

---------------------------------------------------------------------------
-- /alfa curacion [prueba | prueba20 | mover | blizzard | on | off | reiniciar]
---------------------------------------------------------------------------

local ACCIONES = {
	prueba = function() M.Prueba(5) end, prueba5 = function() M.Prueba(5) end,
	prueba20 = function() M.Prueba(20) end,
	listo = function() M.Prueba(nil) M.Mover(false) end,
	mover = function() M.Mover(not M.Moviendo()) end,
	blizzard = function()
		local _, texto = M.UsarEnBlizzard()
		if texto then N.Imprimir(texto) end
	end,
	on = function() N.Set(ID, "activo", true) N.Imprimir(L["Marcos de Curación encendidos."]) end,
	off = function() N.Set(ID, "activo", false) N.Imprimir(L["Marcos de Curación apagados."]) end,
	reiniciar = function() M.ReiniciarPosicion() end,
}

function M.Comando(resto)
	resto = (type(resto) == "string" and resto or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local fn = ACCIONES[resto]
	if fn then fn() else N.Abrir(ID) end
end

A.RegisterCommand("curacion", M.Comando, L["abre Curación (también: prueba, prueba20, mover, listo, blizzard, on, off, reiniciar)"])
