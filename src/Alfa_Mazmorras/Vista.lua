-- Alfa - Mazmorras: la página en la ventana de Alfa (Toxic / La Jauría). GPL-3.0.
--
-- Cuatro secciones arriba, como pestañas:
--   Mazmorras        la lista (para tu nivel, todas, hechas) y, al elegir una,
--                    su diario: jefes en orden con sus consejos y su botín
--                    (o "Todo el botín"), "Solo lo que me sirve", y los
--                    enlaces al diario del motor (misiones y entrada) y a la
--                    flecha. En modo historia los jefes sin vencer quedan
--                    ocultos ("Jefe por descubrir"); sus consejos se pueden
--                    ver a propósito.
--   Mi progreso      mazmorras hechas, jefes vencidos, botín obtenido.
--   Avisos de jefes  las opciones de la línea de tiempo y de los avisos de
--                    encuentros del propio juego (Avisos.lua), explicadas.
--   Ajustes          los de este módulo.
-- Todo se dibuja con el kit del motor (Alfa.Widgets, Alfa.Theme) en marcos
-- reutilizados; la página se vuelve a medir y se repinta en su lugar.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local W, T = A.Widgets, A.Theme
local L = N.Textos(M.EN)
local D, Av = M.D, M.Avisos
local ID = D.ID

local type, pairs, ipairs, tostring, tonumber = type, pairs, ipairs, tostring, tonumber
local floor, max, min = math.floor, math.max, math.min
local format, concat = string.format, table.concat
local sort = table.sort

local V = {}
M.V = V

local SH = W.SHELL
local DOT = "  \194\183  "
local GUION = "\226\128\147"

local SEG_H = 32
local FILA_H = 60
local ARTE = 40
local ARTE_GRANDE = 64
local OBJ_H = 36
local POZO = 30
local PANEL_PAD = 16

local estado = {
	seccion = "lista", -- lista | mazmorra | progreso | avisos | ajustes
	clave = nil, -- la mazmorra abierta
	botin = "jefes", -- jefes | todo
	filtro = "nivel", -- nivel | todas | hechas
	abiertos = {}, -- key .. jefe -> más botín a la vista
	spoiler = {}, -- key .. jefe -> consejos a la vista sin descubrirlo
}
V.estado = estado

local vista, capa -- la vista de la página y la capa de textos sobre ella

---------------------------------------------------------------------------
-- Ayudas
---------------------------------------------------------------------------

local llamar, legible = D.Llamar, D.Legible

local function ventana()
	local O = A.UI and A.UI.Options
	return O and O.frame
end

local function ancho()
	local win = ventana()
	local w = win and win.BodyWidth
	if type(w) == "number" and w > 200 then return w end
	return 566
end

-- Un consejo en el idioma del cliente.
local function texto2(c)
	if type(c) ~= "table" then return "" end
	if N.espanol or not c[2] then return c[1] or "" end
	return c[2]
end

local function nivelJugador()
	local C = A.Compat
	local info = C and llamar(C.GetPlayerInfo)
	if type(info) == "table" and type(info.level) == "number" then return info.level end
	local n = UnitLevel and legible(UnitLevel("player"))
	return type(n) == "number" and n or 1
end

local function lado()
	local C = A.Compat
	local f = C and llamar(C.GetPlayerFaction)
	return f == "Alliance" and "A" or f == "Horde" and "H" or nil
end

local function niveles(lo, hi)
	if type(lo) ~= "number" then return nil end
	if type(hi) ~= "number" or hi == lo then return format(L["Nivel %d"], lo) end
	return format(L["Niveles %s"], lo .. GUION .. hi)
end

local function fecha(t)
	if type(t) ~= "number" or t <= 0 or not date then return nil end
	return date("%d/%m/%Y", t)
end

local function colorCalidad(q)
	if type(q) ~= "number" then return nil end
	if C_Item and C_Item.GetItemQualityColor then
		local r, g, b = llamar(C_Item.GetItemQualityColor, q)
		if type(r) == "number" and legible(r) then return r, g, b end
	end
	local t = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if type(t) == "table" and type(t.r) == "number" then return t.r, t.g, t.b end
	return nil
end

---------------------------------------------------------------------------
-- Marcos reutilizados
---------------------------------------------------------------------------

local pools = {}
local function tomar(nombre, crear)
	local p = pools[nombre]
	if not p then
		p = { n = 0, lista = {} }
		pools[nombre] = p
	end
	p.n = p.n + 1
	local f = p.lista[p.n]
	if not f then
		f = crear()
		p.lista[p.n] = f
	end
	f:ClearAllPoints()
	f:Show()
	return f
end

local function soltarTodo()
	for _, p in pairs(pools) do
		for i = 1, #p.lista do p.lista[i]:Hide() end
		p.n = 0
	end
end

local function en(f, x, y)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", vista, "TOPLEFT", x, -y)
	return f
end

-- Un texto en la capa. envolver: ancho fijo y varias líneas. -> fs, alto
local function texto(rol, color, s, x, y, envolver)
	local fs = tomar("texto", function() return capa:CreateFontString(nil, "OVERLAY") end)
	T.Font(fs, rol)
	W.Color(fs, color or "text")
	fs:SetJustifyH("LEFT")
	fs:SetSpacing(envolver and 3 or 0)
	fs:SetWordWrap(envolver and true or false)
	fs:SetJustifyV(envolver and "TOP" or "MIDDLE")
	fs:SetWidth(envolver or 0)
	fs:SetText(s or "")
	en(fs, x, y)
	return fs, math.ceil(fs:GetStringHeight() or 0)
end

local function cabecera(s, cuenta, x, y, w)
	local h = tomar("cabecera", function() return W.SectionHeader(capa) end)
	W.SetSection(h, s, cuenta)
	h:SetWidth(w)
	en(h, x, y)
	return y + 44
end

local function panel(x, y, w, h)
	local p = tomar("panel", function()
		local f = CreateFrame("Frame", nil, vista)
		f:SetFrameLevel(vista:GetFrameLevel() + 1)
		T.Skin(f, "panel")
		return f
	end)
	p:SetSize(w, max(1, h))
	en(p, x, y)
	return p
end

local function chip(s, tipo, x, y)
	local c = tomar("chip", function() return W.Chip(capa) end)
	local w = W.SetChip(c, s, tipo)
	en(c, x, y)
	return c, w
end

local function enlace(s, fn, x, y)
	local b = tomar("enlace", function()
		local l = W.Link(capa, "", nil, { role = "label" })
		l:SetFrameLevel(capa:GetFrameLevel() + 2)
		return l
	end)
	W.SetLinkText(b, s)
	b.psTip = nil
	b:SetScript("OnClick", fn)
	en(b, x, y)
	return b
end

local function boton(nombre, s, fn, opts)
	vista.botones = vista.botones or {}
	local b = vista.botones[nombre]
	if not b then
		b = W.Button(capa, s, fn, opts)
		b:SetFrameLevel(capa:GetFrameLevel() + 2)
		vista.botones[nombre] = b
	else
		W.SetButtonText(b, s)
		if fn then b:SetScript("OnClick", fn) end
	end
	b:Show()
	return b
end

local function ocultarBotones()
	for _, b in pairs(vista.botones or {}) do b:Hide() end
end

---------------------------------------------------------------------------
-- La imagen de cada mazmorra (su pantalla de carga, Dungeons.Art)
---------------------------------------------------------------------------

local function marcoArte(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.Fondo = W.Fill(f, "scrim", "BACKGROUND", 0)
	f.Tex = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.Tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.Tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.Lift = f:CreateTexture(nil, "ARTWORK", nil, 2)
	f.Lift:SetAllPoints(f.Tex)
	f.Lift:SetBlendMode("ADD")
	f.Lift:Hide()
	W.Painter(f, function(self) T.Border(self, T.Wash("border")) end)
	return f
end

local function pintarArte(f, key)
	local Dg = A.Dungeons
	local art = Dg and Dg.Art and llamar(Dg.Art, key)
	if type(art) == "table" and art.file then
		f.Tex:SetTexture(art.file)
		f.Tex:SetTexCoord(art.l or 0, art.r or 1, art.t or 0, art.b or 1)
		W.Uncolor(f.Tex)
		f.Tex:SetVertexColor(1, 1, 1, 1)
		f.Tex:ClearAllPoints()
		f.Tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		f.Tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
		if art.lift then
			f.Lift:SetTexture(art.file)
			f.Lift:SetTexCoord(art.l or 0, art.r or 1, art.t or 0, art.b or 1)
			f.Lift:SetAlpha(art.lift)
			f.Lift:Show()
		else
			f.Lift:Hide()
		end
	else
		f.Tex:SetTexture(T.Media("icon-dungeon"))
		f.Tex:SetTexCoord(0, 1, 0, 1)
		W.Color(f.Tex, "dungeon")
		local s = floor(f:GetWidth() * 0.25)
		f.Tex:ClearAllPoints()
		f.Tex:SetPoint("TOPLEFT", f, "TOPLEFT", s, -s)
		f.Tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -s, s)
		f.Lift:Hide()
	end
end

---------------------------------------------------------------------------
-- Pestañas de la página
---------------------------------------------------------------------------

local SECCIONES = {
	{ clave = "lista", texto = L["Mazmorras"] },
	{ clave = "progreso", texto = L["Mi progreso"] },
	{ clave = "avisos", texto = L["Avisos de jefes"] },
	{ clave = "ajustes", texto = L["Ajustes"] },
}

local function pestanias(x, y, w)
	vista.pestanias = vista.pestanias or {}
	local cx = x - 12
	local activa = estado.seccion == "mazmorra" and "lista" or estado.seccion
	for i, s in ipairs(SECCIONES) do
		local t = vista.pestanias[i]
		if not t then
			t = CreateFrame("Button", nil, capa)
			t:SetHeight(SEG_H)
			t:SetFrameLevel(capa:GetFrameLevel() + 2)
			t.Label = W.Text(t, "label", "textDim")
			t.Label:SetPoint("CENTER", t, "CENTER", 0, 0)
			T.Skin(t, "tab")
			t:SetScript("OnClick", function(self) V.Ir(self.psClave) end)
			vista.pestanias[i] = t
		end
		t.psClave = s.clave
		t.Label:SetText(s.texto)
		t:SetWidth(floor(t.Label:GetStringWidth() + 24 + 0.5))
		local on = s.clave == activa
		T.SetTabSelected(t, on)
		W.Color(t.Label, on and "text" or "textDim")
		en(t, cx, y)
		t:Show()
		cx = cx + t:GetWidth() + 4
	end
	if not vista.RayaPestanias then vista.RayaPestanias = W.Divider(capa) end
	local r = vista.RayaPestanias
	r:ClearAllPoints()
	r:SetPoint("TOPLEFT", vista, "TOPLEFT", x, -(y + SEG_H))
	r:SetWidth(w)
	r:Show()
	return y + SEG_H + 16
end

---------------------------------------------------------------------------
-- Sin datos todavía (el Codex se carga fuera de combate)
---------------------------------------------------------------------------

local function sinDatos(razon, x, y, w)
	local s
	if razon == "combat" then
		s = L["Los datos de las mazmorras se cargan fuera de combate. Esta página se llenará sola al terminar la pelea."]
		N.FueraDeCombate(function() V.RefrescarPronto() end)
	elseif razon == "off" then
		s = L["El diario de mazmorras de Alfa está apagado. Préndelo aquí abajo para ver jefes, botín y consejos."]
	else
		s = L["No se encontraron los datos de las mazmorras (la carpeta Alfa_Codex). Reinstala Alfa completo."]
	end
	local _, h = texto("note", "textDim", s, x, y, w)
	y = y + h + 12
	if razon == "off" then
		local b = boton("prender", L["Prender el diario de mazmorras"], function()
			A.Set("dungeons.enabled", true)
			V.RefrescarPronto()
		end, { primary = true, icon = "icon-dungeon" })
		en(b, x, y)
		y = y + b:GetHeight() + 8
	end
	return y
end

---------------------------------------------------------------------------
-- Lista de mazmorras
---------------------------------------------------------------------------

local function crearFilaMazmorra()
	local b = CreateFrame("Button", nil, vista)
	b:SetFrameLevel(vista:GetFrameLevel() + 2)
	b:SetHeight(FILA_H)
	T.Skin(b, "tile")
	b.Arte = marcoArte(b, ARTE)
	b.Arte:SetPoint("LEFT", b, "LEFT", 10, 0)
	b.Nombre = W.Text(b, "body", "text")
	b.Nombre:SetPoint("TOPLEFT", b.Arte, "TOPRIGHT", 14, -3)
	b.Sub = W.Text(b, "small", "textMuted")
	b.Sub:SetPoint("BOTTOMLEFT", b.Arte, "BOTTOMRIGHT", 14, 3)
	b.Flecha = W.Tex(b, "ARTWORK", "chevron-right", "textMuted")
	b.Flecha:SetSize(12, 12)
	b.Flecha:SetPoint("RIGHT", b, "RIGHT", -14, 0)
	b.Chip = W.Chip(b)
	b.Chip:SetPoint("RIGHT", b.Flecha, "LEFT", -12, 0)
	b.Barra = W.ProgressLine(b, 2)
	b.Barra:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
	b.Barra:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b:SetScript("OnClick", function(self) V.AbrirMazmorra(self.psClave) end)
	return b
end

-- Una fila: imagen, nombre, niveles y zona, y su estado. -> y nuevo
local function filaMazmorra(d, x, y, w, sub)
	local b = tomar("filaMazmorra", crearFilaMazmorra)
	b.psClave = d.key
	b:SetWidth(w)
	en(b, x, y)
	pintarArte(b.Arte, d.key)
	b.Nombre:SetText(d.name or d.key)
	local partes = {}
	if not sub then
		partes[#partes + 1] = niveles(d.minLevel, d.maxLevel)
		if d.zoneName then partes[#partes + 1] = d.zoneName end
		if d.kind == "raid" then partes[#partes + 1] = L["Banda"] end
		sub = concat(partes, DOT)
	end
	b.Sub:SetText(sub)
	local v, total = D.Cuenta(d.key)
	local hecha = D.Hecha(d.key)
	local cw
	if hecha then
		cw = W.SetChip(b.Chip, (hecha.veces or 0) > 1 and format(L["Hecha %d veces"], hecha.veces) or L["Hecha"], "success")
	elseif v > 0 then
		cw = W.SetChip(b.Chip, format(L["%d de %d jefes"], v, total), "accent")
	elseif d.forever then
		cw = W.SetChip(b.Chip, "Forever", "dungeon")
	else
		b.Chip:Hide()
		cw = 0
	end
	local room = w - 10 - ARTE - 14 - 14 - 12 - (cw > 0 and (cw + 12) or 0) - 8
	b.Nombre:SetWidth(max(60, room))
	b.Sub:SetWidth(max(60, room))
	if total > 0 and v > 0 then
		b.Barra:Show()
		W.SetProgress(b.Barra, v / total, w - 2)
	else
		b.Barra:Hide()
	end
	return y + FILA_H
end

local FILTROS = {
	{ clave = "nivel", texto = L["Para tu nivel"] },
	{ clave = "todas", texto = L["Todas"] },
	{ clave = "hechas", texto = L["Hechas"] },
}

local function paraMiNivel(d, nivel, miLado)
	if d.kind ~= "dungeon" then return false end
	local lo, hi = d.minLevel or 1, d.maxLevel or 60
	if nivel < lo - 2 or nivel > hi + 2 then return false end
	local Dg = A.Dungeons
	if miLado and Dg and Dg.EnemyCapital and llamar(Dg.EnemyCapital, d.key, miLado) then return false end
	return true
end

local function pintarLista(x, y, w)
	local ok, razon = D.Listo()
	if not ok then return sinDatos(razon, x, y, w) end
	D.RevisarTodo()
	local todas = D.Lista()
	local hechas, jefes, objetos = D.Resumen()
	local mazmorras = 0
	for _, d in ipairs(todas) do if d.kind == "dungeon" then mazmorras = mazmorras + 1 end end
	local _, h = texto("note", "textDim", format(L["Has completado %d de %d mazmorras%s%d jefes vencidos%s%d objetos obtenidos"],
		hechas, mazmorras, DOT, jefes, DOT, objetos), x, y, w)
	y = y + h + 14
	-- Filtros
	local bx = x
	for _, f in ipairs(FILTROS) do
		local b = boton("filtro" .. f.clave, f.texto, function()
			estado.filtro = f.clave
			V.Refrescar(true)
		end, { height = 26 })
		local on = estado.filtro == f.clave
		if b.psPrimary ~= on then
			b.psPrimary = on
			T.Repaint(b)
			W.RepaintButton(b)
		end
		en(b, bx, y)
		bx = bx + b:GetWidth() + 8
	end
	y = y + 26 + 16
	local nivel, miLado = nivelJugador(), lado()
	local lista = {}
	for _, d in ipairs(todas) do
		local entra
		if estado.filtro == "todas" then entra = true
		elseif estado.filtro == "hechas" then entra = D.Hecha(d.key) ~= nil or (D.Cuenta(d.key)) > 0
		else entra = paraMiNivel(d, nivel, miLado) end
		if entra then lista[#lista + 1] = d end
	end
	-- Para tu nivel sin ninguna: las tres siguientes.
	if estado.filtro == "nivel" and #lista == 0 then
		for _, d in ipairs(todas) do
			if d.kind == "dungeon" and (d.minLevel or 0) > nivel and #lista < 3 then lista[#lista + 1] = d end
		end
		if #lista > 0 then
			local _, h2 = texto("note", "textMuted", L["Aún no hay mazmorras para tu nivel. Estas son las siguientes:"], x, y, w)
			y = y + h2 + 10
		end
	end
	if #lista == 0 then
		local s = estado.filtro == "hechas" and L["Todavía no has vencido a ningún jefe. ¡Tu primera mazmorra te espera!"]
			or L["No hay mazmorras que mostrar."]
		local _, h3 = texto("note", "textMuted", s, x, y, w)
		return y + h3 + 8
	end
	for _, d in ipairs(lista) do y = filaMazmorra(d, x, y, w) + 8 end
	return y
end

---------------------------------------------------------------------------
-- Objetos
---------------------------------------------------------------------------

local function crearObjeto()
	local b = CreateFrame("Button", nil, vista)
	b:SetFrameLevel(vista:GetFrameLevel() + 3)
	b:SetHeight(OBJ_H)
	W.Hover(b)
	b.Pozo = CreateFrame("Frame", nil, b)
	b.Pozo:SetSize(POZO, POZO)
	b.Pozo:SetPoint("LEFT", b, "LEFT", 2, 0)
	b.Pozo.Fondo = W.Fill(b.Pozo, "scrim", "BACKGROUND", 0)
	b.Icono = b.Pozo:CreateTexture(nil, "ARTWORK")
	b.Icono:SetPoint("TOPLEFT", b.Pozo, "TOPLEFT", 1, -1)
	b.Icono:SetPoint("BOTTOMRIGHT", b.Pozo, "BOTTOMRIGHT", -1, 1)
	b.Nombre = W.Text(b, "label", "text")
	b.Nombre:SetPoint("TOPLEFT", b.Pozo, "TOPRIGHT", 10, -1)
	b.Sub = W.Text(b, "small", "textMuted")
	b.Sub:SetPoint("BOTTOMLEFT", b.Pozo, "BOTTOMRIGHT", 10, 1)
	b.Marca = W.Tex(b, "ARTWORK", "qol-upgrade", "success")
	b.Marca:SetSize(14, 14)
	b.Marca:SetPoint("RIGHT", b, "RIGHT", -6, 0)
	b.Chance = W.Text(b, "number", "textDim")
	b.Chance:SetJustifyH("RIGHT")
	b.Chance:SetPoint("RIGHT", b, "RIGHT", -28, 0)
	b:SetScript("OnEnter", function(self) if self.psID then W.ItemTip(self, self.psID) end end)
	b:SetScript("OnLeave", function(self) W.HideTooltip(self) end)
	b:SetScript("OnClick", function(self) if self.psID then W.ItemClick(self.psID) end end)
	return b
end

local function porcentaje(c)
	if type(c) ~= "number" then return "" end
	if c < 1 then return "<1 %" end
	return format("%d %%", floor(c + 0.5))
end

-- Una fila de botín. conJefe: el nombre del jefe en la segunda línea. -> y nuevo
local function filaObjeto(key, e, x, y, w, conJefe)
	local b = tomar("objeto", crearObjeto)
	b.psID = e.id
	b:SetWidth(w)
	en(b, x, y)
	local o = D.Objeto(e)
	if o.icono then
		b.Icono:SetTexture(o.icono)
		b.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		W.Uncolor(b.Icono)
		b.Icono:SetVertexColor(1, 1, 1, 1)
	else
		b.Icono:SetTexture(T.Media("icon-collect"))
		b.Icono:SetTexCoord(0, 1, 0, 1)
		W.Color(b.Icono, "textMuted")
	end
	local r, g, bl = colorCalidad(o.calidad)
	if r then
		T.Border(b.Pozo, r, g, bl, 0.9)
		W.Uncolor(b.Nombre)
		b.Nombre:SetTextColor(T.Legible(r, g, bl))
	else
		local ir, ig, ib = T.Wash("border")
		T.Border(b.Pozo, ir, ig, ib, 0.6)
		W.Color(b.Nombre, "text")
	end
	b.Nombre:SetText(o.nombre)
	local partes = {}
	if o.ranura then partes[#partes + 1] = o.ranura end
	if o.tipo then partes[#partes + 1] = o.tipo end
	if type(o.req) == "number" and o.req > 1 then partes[#partes + 1] = format(L["Niv. %d"], o.req) end
	if conJefe then
		for _, j in ipairs(D.Jefes(key)) do
			if j.id == e.jefe then partes[#partes + 1] = j.nombre end
		end
	end
	b.Sub:SetText(concat(partes, DOT))
	b.Chance:SetText(porcentaje(e.chance))
	-- La marca: lo tienes, es una mejora ahora, o lo será a cierto nivel.
	local tengo = D.Obtenido(e, key)
	local mejora, _, nivel = D.Mejora(e.id)
	if tengo then
		b.Marca:SetTexture(T.Media("check"))
		W.Color(b.Marca, "success")
		b.Marca:Show()
	elseif mejora then
		b.Marca:SetTexture(T.Media("qol-upgrade"))
		W.Color(b.Marca, "success")
		b.Marca:Show()
	elseif nivel then
		b.Marca:SetTexture(T.Media("qol-upgrade"))
		W.Color(b.Marca, "textMuted")
		b.Marca:Show()
	else
		b.Marca:Hide()
	end
	local room = w - 2 - POZO - 10 - 28 - 52
	b.Nombre:SetWidth(max(60, room))
	b.Sub:SetWidth(max(60, room))
	return y + OBJ_H + 2
end

local function sirve(e)
	if not N.Get(ID, "meSirve") then return true end
	return D.MeSirve(e.id) ~= false
end

---------------------------------------------------------------------------
-- Diario de una mazmorra
---------------------------------------------------------------------------

local ROL = {
	tanque = { L["Tanque"], "accent" },
	cura = { L["Cura"], "success" },
	dano = { L["Daño"], "warning" },
}

-- Consejos con viñeta. -> y nuevo
local function consejos(lista, x, y, w)
	for _, c in ipairs(lista) do
		local s = texto2(c)
		local r = ROL[c.rol]
		if r then s = "|c" .. T.Hex(r[2]) .. r[1] .. ":|r " .. s end
		texto("note", "textMuted", "\226\128\162", x, y)
		local _, h = texto("note", "text", s, x + 14, y, w - 14)
		y = y + max(h, 14) + 6
	end
	return y
end

local function crearInsignia()
	local f = CreateFrame("Frame", nil, capa)
	f:SetSize(24, 24)
	f.Circulo = W.Tex(f, "ARTWORK", "circle", "panelAlt")
	f.Circulo:SetAllPoints(f)
	f.Glifo = W.Tex(f, "OVERLAY", "check", "success")
	f.Glifo:SetSize(12, 12)
	f.Glifo:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.Num = W.Text(f, "caption", "textDim")
	f.Num:SetPoint("CENTER", f, "CENTER", 0, 0)
	return f
end

local ROL_JEFE = { rare = L["Raro"], event = L["Evento"], optional = L["Opcional"] }

-- Un jefe en su panel: número o marca, nombre, nivel, consejos y botín.
local function bloqueJefe(key, j, n, x, y, w)
	local top = y
	local ix, iw = x + PANEL_PAD, w - PANEL_PAD * 2
	local p = panel(x, y, w, 10)
	y = y + 14
	local descubierto = D.Descubierto(key, j)
	local vencido = D.Vencido(key, j.id)
	local ins = tomar("insignia", crearInsignia)
	en(ins, ix, y)
	if vencido then
		ins.Glifo:SetTexture(T.Media("check"))
		W.Color(ins.Glifo, "success")
		ins.Glifo:Show()
		ins.Num:Hide()
	elseif not descubierto then
		ins.Glifo:SetTexture(T.Media("lock"))
		W.Color(ins.Glifo, "textMuted")
		ins.Glifo:Show()
		ins.Num:Hide()
	else
		ins.Glifo:Hide()
		ins.Num:SetText(tostring(n))
		ins.Num:Show()
	end
	local nombre = descubierto and (j.nombre or "?") or format(L["Jefe %d por descubrir"], n)
	local fsN = texto("title", descubierto and "text" or "textMuted", nombre, ix + 34, y + 3)
	local tope = max(80, iw - 34 - 200)
	if fsN:GetStringWidth() > tope then fsN:SetWidth(tope) end
	local cx = ix + 34 + min(fsN:GetStringWidth(), tope) + 10
	if j.rol and ROL_JEFE[j.rol] then
		local _, cw = chip(ROL_JEFE[j.rol], j.rol == "rare" and "warning" or nil, cx, y + 2)
		cx = cx + cw + 6
	end
	if j.final and descubierto then
		local _, cw = chip(L["Jefe final"], "dungeon", cx, y + 2)
		cx = cx + cw + 6
	end
	if vencido then chip(L["Vencido"], "success", cx, y + 2) end
	if type(j.nivel) == "number" then
		local fsL = texto("small", "textMuted", format(L["Nivel %d"], j.nivel), ix, y + 6)
		fsL:ClearAllPoints()
		fsL:SetPoint("TOPRIGHT", vista, "TOPLEFT", ix + iw, -(y + 6))
	end
	y = y + 24 + 10
	local llave = key .. ":" .. j.id
	local verConsejos = descubierto or estado.spoiler[llave]
	if not descubierto then
		local s = j.rol and L["Los jefes opcionales y raros se descubren al terminar la mazmorra."]
			or L["Vence a este jefe para descubrir su nombre y su botín."]
		local _, h = texto("note", "textMuted", s, ix, y, iw)
		y = y + h + 8
		if j.consejos and not verConsejos then
			enlace(L["Ver sus consejos de todos modos"], function()
				estado.spoiler[llave] = true
				V.Refrescar()
			end, ix, y)
			y = y + 26
		end
	end
	if verConsejos and j.consejos then
		texto("caption", "textMuted", L["CONSEJOS"], ix, y)
		y = y + 18
		y = consejos(j.consejos, ix, y, iw) + 4
	elseif descubierto and not j.consejos then
		local _, h = texto("note", "textMuted", L["Todavía no hay consejos para este jefe."], ix, y, iw)
		y = y + h + 8
	end
	if descubierto then
		local principal, extra = D.BotinDe(key, j)
		texto("caption", "textMuted", L["BOTÍN"], ix, y + 2)
		y = y + 20
		local mostrados = 0
		for _, e in ipairs(principal) do
			if sirve(e) then
				y = filaObjeto(key, e, ix - 2, y, iw + 4)
				mostrados = mostrados + 1
			end
		end
		if mostrados == 0 then
			local s = (#principal > 0 and N.Get(ID, "meSirve")) and L["Nada de su botín principal le sirve a tu clase."]
				or (not j.npc and not j.objeto) and L["Es un grupo: cada uno suelta su propio botín (más abajo, entre los opcionales)."]
				or L["No se conoce botín propio de este jefe."]
			local _, h = texto("note", "textMuted", s, ix, y, iw)
			y = y + h + 6
		end
		local extraVisible = {}
		for _, e in ipairs(extra) do if sirve(e) then extraVisible[#extraVisible + 1] = e end end
		if #extraVisible > 0 then
			local abierto = estado.abiertos[llave]
			enlace(abierto and L["Ocultar el botín poco probable"] or format(L["Botín poco probable (%d)"], #extraVisible), function()
				estado.abiertos[llave] = not estado.abiertos[llave] or nil
				V.Refrescar()
			end, ix, y + 2)
			y = y + 26
			if abierto then
				for _, e in ipairs(extraVisible) do y = filaObjeto(key, e, ix - 2, y, iw + 4) end
			end
		end
	end
	y = y + 10
	p:SetHeight(y - top)
	return y
end

-- "Todo el botín": lo principal de cada jefe en un solo panel.
local function bloqueTodo(key, x, y, w)
	local top = y
	local ix, iw = x + PANEL_PAD, w - PANEL_PAD * 2
	local p = panel(x, y, w, 10)
	y = y + 14
	local ocultos, mostrados = 0, 0
	local jefes = {}
	for _, j in ipairs(D.Jefes(key)) do jefes[j.id] = j end
	local lista = D.BotinMazmorra(key)
	for _, e in ipairs(lista) do
		local j = jefes[e.jefe]
		if j and not D.Descubierto(key, j) then
			ocultos = ocultos + 1
		elseif sirve(e) then
			y = filaObjeto(key, e, ix - 2, y, iw + 4, true)
			mostrados = mostrados + 1
		end
	end
	if mostrados == 0 then
		local _, h = texto("note", "textMuted", N.Get(ID, "meSirve") and L["Nada del botín conocido le sirve a tu clase."]
			or L["No hay botín a la vista todavía."], ix, y, iw)
		y = y + h + 6
	end
	if ocultos > 0 then
		local _, h = texto("note", "textMuted", format(L["%d objetos más son de jefes que aún no descubres."], ocultos), ix, y + 4, iw)
		y = y + h + 10
	end
	y = y + 10
	p:SetHeight(y - top)
	return y
end

local function interruptor()
	if not vista.Interruptor then
		local s = W.Switch(capa, function() return N.Get(ID, "meSirve") end, function(on)
			N.Set(ID, "meSirve", on and true or false)
			V.RefrescarPronto()
		end, L["Oculta lo que tu clase no puede usar o no le conviene."])
		s:SetFrameLevel(capa:GetFrameLevel() + 2)
		vista.Interruptor = s
	end
	vista.Interruptor:Refresh()
	vista.Interruptor:Show()
	return vista.Interruptor
end

local function pintarMazmorra(x, y, w)
	local ok, razon = D.Listo()
	if not ok then return sinDatos(razon, x, y, w) end
	local key = estado.clave
	local d = D.Info(key)
	if not d then
		estado.seccion, estado.clave = "lista", nil
		return pintarLista(x, y, w)
	end
	D.RevisarMisiones(key)
	local jefes = D.Jefes(key)
	-- Encabezado: volver, imagen, nombre, datos y estado.
	if not vista.Atras then
		vista.Atras = W.IconButton(capa, "chevron-left", 24, L["Todas las mazmorras"], function() V.Ir("lista") end, 12)
		vista.Atras:SetFrameLevel(capa:GetFrameLevel() + 2)
	end
	vista.Atras:Show()
	en(vista.Atras, x - 4, y + 20)
	if not vista.ArteGrande then
		vista.ArteGrande = marcoArte(capa, ARTE_GRANDE)
	end
	vista.ArteGrande:Show()
	en(vista.ArteGrande, x + 28, y)
	pintarArte(vista.ArteGrande, key)
	local tx = x + 28 + ARTE_GRANDE + 16
	local tw = w - (tx - x)
	local fsT = texto("display", "text", d.name or key, tx, y + 2)
	if fsT:GetStringWidth() > tw then fsT:SetWidth(tw) end
	local partes = { niveles(d.minLevel, d.maxLevel) }
	if d.zoneName then partes[#partes + 1] = d.zoneName end
	if type(d.players) == "number" then partes[#partes + 1] = format(L["%d jugadores"], d.players) end
	local fsD = texto("small", "textDim", concat(partes, DOT), tx, y + 28)
	if fsD:GetStringWidth() > tw then fsD:SetWidth(tw) end
	local v, total = D.Cuenta(key)
	local hecha = D.Hecha(key)
	local cx = tx
	if hecha then
		local s
		if (hecha.veces or 0) > 0 then
			s = (hecha.veces > 1) and format(L["Hecha %d veces"], hecha.veces) or L["Hecha"]
		else
			s = L["Ya la habías hecho"]
		end
		local _, cw = chip(s, "success", cx, y + 44)
		cx = cx + cw + 6
	end
	if total > 0 then
		local _, cw = chip(format(L["%d de %d jefes"], v, total), v > 0 and "accent" or nil, cx, y + 44)
		cx = cx + cw + 6
	end
	if D.Historia() and not hecha then chip(L["Modo historia"], "dungeon", cx, y + 44) end
	y = y + ARTE_GRANDE + 16
	-- Acciones: el diario del motor, la flecha y "ya la hice".
	local Dg = A.Dungeons
	local b1 = boton("misiones", L["Misiones y entrada"], function()
		if Dg and Dg.Open then Dg.Open(estado.clave) end
	end, { primary = true, icon = "icon-dungeon" })
	b1.psTip = L["Abre la página de esta mazmorra en el diario de Alfa: sus misiones, dónde se recogen y su entrada."]
	en(b1, x, y)
	local bx = x + b1:GetWidth() + 8
	local b2 = boton("flecha", L["Guíame a la entrada"], function()
		if Dg and Dg.GuideTo and not Dg.GuideTo(estado.clave) then
			N.Imprimir(L["No se conoce la entrada de esta mazmorra."])
		end
	end, { icon = "icon-goto" })
	b2.psTip = L["Pone la flecha de Alfa en la entrada."]
	en(b2, bx, y)
	bx = bx + b2:GetWidth() + 8
	if D.Historia() and not hecha then
		local b3 = boton("antes", L["Ya la hice antes"], function()
			local k = estado.clave
			W.Modal({
				title = L["¿Ya hiciste esta mazmorra?"], icon = "check",
				text = format(L["Se descubren todos los jefes de %s, como si la hubieras terminado. Si te equivocas, abajo de la página puedes olvidar tu progreso aquí."], D.Nombre(k)),
				action = L["Sí, ya la hice"],
				onAccept = function() D.MarcarAntes(k) end,
			})
		end, { icon = "check" })
		b3.psTip = L["Para quien ya jugó esta mazmorra antes de instalar Alfa."]
		en(b3, bx, y)
	end
	y = y + b1:GetHeight() + 12
	local aviso = Dg and Dg.EnemyEntrance and llamar(Dg.EnemyEntrance, key)
	if type(aviso) == "string" then
		local _, h = texto("note", "warning", aviso, x, y, w)
		y = y + h + 10
	end
	-- Antes de entrar
	local general = D.Consejos(key)
	if general then
		y = cabecera(L["Antes de entrar"], nil, x, y, w)
		y = consejos(general, x, y, w) + 4
	end
	-- Jefes o todo el botín, y el filtro.
	y = cabecera(estado.botin == "todo" and L["Todo el botín"] or L["Jefes"], #jefes > 0 and tostring(#jefes) or nil, x, y, w)
	local bx2 = x
	for _, s in ipairs({ { "jefes", L["Por jefe"] }, { "todo", L["Todo el botín"] } }) do
		local b = boton("vista" .. s[1], s[2], function()
			estado.botin = s[1]
			V.Refrescar()
		end, { height = 26 })
		local on = estado.botin == s[1]
		if b.psPrimary ~= on then
			b.psPrimary = on
			T.Repaint(b)
			W.RepaintButton(b)
		end
		en(b, bx2, y)
		bx2 = bx2 + b:GetWidth() + 8
	end
	local sw = interruptor()
	sw:ClearAllPoints()
	sw:SetPoint("TOPRIGHT", vista, "TOPLEFT", x + w, -(y + 1))
	local et = texto("label", "textDim", L["Solo lo que me sirve"], x, y + 6)
	et:ClearAllPoints()
	et:SetPoint("RIGHT", sw, "LEFT", -6, 0)
	y = y + 26 + 14
	if #jefes == 0 then
		local _, h = texto("note", "textMuted", L["Esta mazmorra no tiene jefes en el diario."], x, y, w)
		y = y + h + 8
	elseif estado.botin == "todo" then
		y = bloqueTodo(key, x, y, w) + 10
	else
		for i, j in ipairs(jefes) do y = bloqueJefe(key, j, i, x, y, w) + 10 end
	end
	-- Olvidar el progreso de esta mazmorra
	if hecha or v > 0 then
		enlace(L["Olvidar mi progreso aquí"], function()
			local k = estado.clave
			W.Modal({
				title = L["¿Olvidar tu progreso?"], icon = "reset", danger = true,
				text = format(L["Se borran los jefes vencidos, las veces completada y el botín anotado de %s para este personaje."], D.Nombre(k)),
				action = L["Olvidar"],
				onAccept = function() D.Olvidar(k) end,
			})
		end, x, y + 4)
		y = y + 30
	end
	return y
end

---------------------------------------------------------------------------
-- Mi progreso
---------------------------------------------------------------------------

local function tarjeta(numero, etiqueta, x, y, w)
	panel(x, y, w, 72)
	texto("display", "accent", tostring(numero), x + 14, y + 12)
	local _, h = texto("small", "textDim", etiqueta, x + 14, y + 42, w - 28)
	return h
end

local function pintarProgreso(x, y, w)
	local listo = D.Listo()
	if listo then D.RevisarTodo() end
	local hechas, jefes, objetos, veces = D.Resumen()
	local gap = 10
	local tw = floor((w - gap * 3) / 4)
	tarjeta(hechas, L["Mazmorras hechas"], x, y, tw)
	tarjeta(jefes, L["Jefes vencidos"], x + (tw + gap), y, tw)
	tarjeta(objetos, L["Objetos obtenidos"], x + (tw + gap) * 2, y, tw)
	tarjeta(veces, L["Veces completadas"], x + (tw + gap) * 3, y, tw)
	y = y + 72 + 18
	-- Por mazmorra: las que tienen algo, la más reciente primero.
	local p = D.Progreso()
	local filas = {}
	local vistas = {}
	local function reciente(key)
		local t = 0
		local h = p.hechas[key]
		if type(h) == "table" then t = max(t, h.t or 0, h.desde or 0) end
		local js = p.jefes[key]
		if type(js) == "table" then
			for _, r in pairs(js) do if type(r) == "table" then t = max(t, r.t or 0) end end
		end
		return t
	end
	for key in pairs(p.hechas) do vistas[key] = true end
	for key in pairs(p.jefes) do vistas[key] = true end
	for key in pairs(vistas) do filas[#filas + 1] = { key = key, t = reciente(key) } end
	sort(filas, function(a, b)
		if a.t ~= b.t then return a.t > b.t end
		return a.key < b.key
	end)
	y = cabecera(L["Por mazmorra"], #filas > 0 and tostring(#filas) or nil, x, y, w)
	if #filas == 0 then
		local _, h = texto("note", "textMuted", L["Cuando venzas a tu primer jefe, tu progreso aparecerá aquí."], x, y, w)
		y = y + h + 12
	end
	local entradas = D.Entradas()
	for _, f in ipairs(filas) do
		local d = (listo and D.Info(f.key)) or nil
		if not d then
			local e = entradas[f.key]
			d = { key = f.key, name = (e and e.nombre) or f.key, minLevel = e and e.min, maxLevel = e and e.max, kind = e and e.tipo }
		end
		local v, total = D.Cuenta(f.key)
		local h = D.Hecha(f.key)
		local partes = {}
		partes[#partes + 1] = total > 0 and format(L["%d de %d jefes"], v, total) or format(L["%d jefes"], v)
		if h and (h.veces or 0) > 0 then
			partes[#partes + 1] = h.veces == 1 and L["completada 1 vez"] or format(L["completada %d veces"], h.veces)
		elseif h then
			partes[#partes + 1] = L["ya la habías hecho"]
		end
		local cuando = fecha(f.t)
		if cuando then partes[#partes + 1] = cuando end
		y = filaMazmorra(d, x, y, w, concat(partes, DOT)) + 8
	end
	-- Botín obtenido, lo último primero.
	local botin = {}
	for id, b in pairs(p.botin) do
		if type(b) == "table" and type(id) == "number" then botin[#botin + 1] = { id = id, k = b.k, j = b.j, t = b.t or 0 } end
	end
	sort(botin, function(a, b)
		if a.t ~= b.t then return a.t > b.t end
		return a.id < b.id
	end)
	y = y + 6
	y = cabecera(L["Botín obtenido"], #botin > 0 and tostring(#botin) or nil, x, y, w)
	if #botin == 0 then
		local _, h = texto("note", "textMuted", L["Lo que recibas de los jefes se anota aquí. Lo que ya tienes en tus bolsas también cuenta."], x, y, w)
		y = y + h + 12
	else
		local top = y
		local pn = panel(x, y, w, 10)
		y = y + 8
		for i, b in ipairs(botin) do
			if i > 20 then break end
			local e = { id = b.id, jefe = b.j }
			local o = filaObjeto(b.k, e, x + PANEL_PAD - 2, y, w - PANEL_PAD * 2 + 4, true)
			y = o
		end
		y = y + 8
		pn:SetHeight(y - top)
		y = y + 12
	end
	-- Borrar todo
	if not vista.Borrar then
		vista.Borrar = W.ActionTile(capa, "reset", L["Borrar todo mi progreso"],
			L["Jefes vencidos, mazmorras hechas y botín anotado de este personaje. No toca tus ajustes."],
			function()
				W.Modal({
					title = L["¿Borrar todo tu progreso?"], icon = "reset", danger = true,
					text = L["Se borra el progreso de mazmorras de este personaje. No se puede deshacer."],
					action = L["Borrar"],
					onAccept = function() D.OlvidarTodo() end,
				})
			end, { danger = true })
		vista.Borrar:SetFrameLevel(capa:GetFrameLevel() + 2)
	end
	local b = vista.Borrar
	b:Show()
	en(b, x, y)
	y = y + W.LayoutTile(b, floor((w - 24) / 2)) + 8
	return y
end

---------------------------------------------------------------------------
-- Avisos de jefes (los del juego)
---------------------------------------------------------------------------

local function ctlCVar(nombre, etiqueta, ayuda, hijo, depende)
	return {
		kind = "toggle", label = etiqueta, help = ayuda, child = hijo, cvar = nombre,
		get = function() return Av.Bool(nombre) end,
		set = function(on) Av.Poner(nombre, on) V.RefrescarPronto() end,
		disabled = function()
			if not Av.Bool("combatWarningsEnabled") and nombre ~= "combatWarningsEnabled" then return true end
			return depende ~= nil and not Av.Bool(depende)
		end,
	}
end

local CONTROLES_AVISOS = {
	ctlCVar("combatWarningsEnabled", L["Avisos de jefes del juego"],
		L["Prende todo el sistema de avisos de jefes de Blizzard: la línea de tiempo y los mensajes en pantalla. Sin esto, lo demás no se ve."]),
	ctlCVar("encounterTimelineEnabled", L["Línea de tiempo del jefe"],
		L["Una barra con los ataques que el jefe va a hacer y cuánto falta para cada uno. Así sabes cuándo moverte o defenderte."], true),
	ctlCVar("encounterTimelineHideLongCountdowns", L["Ocultar cuentas largas"],
		L["No muestra los ataques que todavía tardan mucho: la barra queda más limpia."], true, "encounterTimelineEnabled"),
	ctlCVar("encounterTimelineHideQueuedCountdowns", L["Ocultar ataques en espera"],
		L["No muestra los ataques que ya deberían haber llegado y esperan su momento."], true, "encounterTimelineEnabled"),
	ctlCVar("encounterTimelineHideForOtherRoles", L["Solo lo de mi rol"],
		L["Oculta los avisos que son para otro rol (por ejemplo, los del tanque si tú curas)."], true, "encounterTimelineEnabled"),
	ctlCVar("encounterTimelineIconographyEnabled", L["Íconos de ayuda"],
		L["Pequeños íconos en cada ataque: si es para el tanque, para quien cura, si se puede quitar o si es mortal."], true, "encounterTimelineEnabled"),
	ctlCVar("encounterWarningsEnabled", L["Mensajes de aviso en pantalla"],
		L["Letras grandes en el centro de la pantalla cuando el jefe hace algo importante."], true),
	{
		kind = "dropdown", label = L["Qué mensajes mostrar"], cvar = "encounterWarningsLevel", child = true,
		help = L["Todos: también los avisos leves. Solo los graves: únicamente lo que puede matarte."],
		choices = {
			{ value = 0, text = L["Todos"] },
			{ value = 1, text = L["Medianos y graves"] },
			{ value = 2, text = L["Solo los graves"] },
		},
		get = function() return Av.Numero("encounterWarningsLevel") end,
		set = function(v) Av.Poner("encounterWarningsLevel", v) V.RefrescarPronto() end,
		disabled = function() return not (Av.Bool("combatWarningsEnabled") and Av.Bool("encounterWarningsEnabled")) end,
	},
	ctlCVar("encounterWarningsHideIfNotTargetingPlayer", L["Solo los que me apuntan a mí"],
		L["Oculta los mensajes de ataques que van contra otro jugador."], true, "encounterWarningsEnabled"),
}

local function ocultarFilas()
	for _, cache in ipairs({ vista.cacheAvisos or {}, vista.cacheAjustes or {} }) do
		for _, wdg in pairs(cache) do wdg:Hide() end
	end
	if vista.PanelAvisos then vista.PanelAvisos:Hide() end
	if vista.PanelAjustes then vista.PanelAjustes:Hide() end
	for _, k in ipairs({ "Atras", "ArteGrande", "Interruptor", "Borrar", "Probar", "Recomendado" }) do
		if vista[k] then vista[k]:Hide() end
	end
	if vista.RayaPestanias then vista.RayaPestanias:Hide() end
	for _, t in ipairs(vista.pestanias or {}) do t:Hide() end
	ocultarBotones()
end

-- Filas de controles como en el resto de la ventana (UI.Options.Rows).
local function filas(lista, cacheNombre, panelNombre, y)
	local O = A.UI and A.UI.Options
	if not (O and O.Rows and ventana()) then return y end
	vista[cacheNombre] = vista[cacheNombre] or {}
	if not vista[panelNombre] then vista[panelNombre] = W.RowPanel(vista) end
	local ok, ny = pcall(O.Rows, vista, lista, y, vista[cacheNombre], vista[panelNombre])
	if not ok then
		if geterrorhandler then geterrorhandler()(ny) end
		return y
	end
	for _, wdg in pairs(vista[cacheNombre]) do
		if wdg.SetFrameLevel then wdg:SetFrameLevel(vista:GetFrameLevel() + 2) end
	end
	return ny
end

local function estadoChip(etiqueta, disponible, activa, x, y)
	local s, tipo
	if disponible == false then
		s, tipo = format(L["%s: no disponible"], etiqueta), "warning"
	elseif activa then
		s, tipo = format(L["%s: prendida"], etiqueta), "success"
	elseif activa == false then
		s, tipo = format(L["%s: apagada"], etiqueta), nil
	else
		s, tipo = etiqueta, nil
	end
	local _, w = chip(s, tipo, x, y)
	return w
end

local function pintarAvisos(x, y, w)
	local _, h = texto("note", "textDim", L["Forever ya trae avisos de jefes hechos por Blizzard: una línea de tiempo con los ataques que vienen y mensajes grandes cuando algo es peligroso. Alfa no inventa avisos propios: aquí los prendes y los ajustas, explicados en sencillo."], x, y, w)
	y = y + h + 12
	local cw = estadoChip(L["Línea de tiempo"], Av.LineaDisponible(), Av.LineaActiva(), x, y)
	estadoChip(L["Mensajes"], Av.MensajesDisponibles(), Av.MensajesActivos(), x + cw + 8, y)
	y = y + 20 + 16
	local visibles = {}
	for _, c in ipairs(CONTROLES_AVISOS) do
		if Av.Existe(c.cvar) then visibles[#visibles + 1] = c end
	end
	if #visibles == 0 then
		local _, h2 = texto("note", "warning", L["Tu cliente no trae estas opciones. Si Blizzard las agrega, aparecerán aquí solas."], x, y, w)
		y = y + h2 + 12
	else
		y = filas(visibles, "cacheAvisos", "PanelAvisos", y) + 18
	end
	if not vista.Probar then
		vista.Probar = W.ActionTile(capa, "hourglass", L["Probar la línea de tiempo"],
			L["Pone tres ataques de prueba en la línea de tiempo para que veas dónde sale. Se borran solos."],
			function()
				local ok, porque = Av.Probar()
				if ok then
					N.Imprimir(L["Mira la línea de tiempo: llegan tres ataques de prueba."])
				else
					N.Imprimir(porque or L["No se pudo probar ahora."])
				end
			end)
		vista.Probar:SetFrameLevel(capa:GetFrameLevel() + 2)
	end
	if not vista.Recomendado then
		vista.Recomendado = W.ActionTile(capa, "check", L["Dejarlo como recomienda Alfa"],
			L["Prende la línea de tiempo, los íconos de ayuda y los mensajes medianos y graves."],
			function()
				local puestas, hay = Av.Recomendado()
				if hay > 0 and puestas == hay then
					N.Imprimir(L["Listo: avisos de jefes como los recomienda Alfa."])
				elseif hay > 0 then
					N.Imprimir(format(L["Se pusieron %d de %d opciones; las demás el juego no las dejó cambiar."], puestas, hay))
				end
				V.RefrescarPronto()
			end)
		vista.Recomendado:SetFrameLevel(capa:GetFrameLevel() + 2)
	end
	local cw2 = floor((w - 24) / 2)
	local pb, rc = vista.Probar, vista.Recomendado
	rc:Show()
	en(rc, x, y)
	pb:Show()
	en(pb, x + cw2 + 24, y)
	local th = max(W.LayoutTile(rc, cw2), W.LayoutTile(pb, cw2))
	rc:SetHeight(th)
	pb:SetHeight(th)
	y = y + th + 16
	local editar = type(HUD_EDIT_MODE_MENU) == "string" and HUD_EDIT_MODE_MENU or L["Modo de edición"]
	y = cabecera(L["Bueno saber"], nil, x, y, w)
	local notas = {
		{ format(L["Para mover la línea de tiempo o los mensajes: abre el menú del juego (Esc) y elige %s."], editar),
			format("To move the timeline or the warnings: open the game menu (Esc) and choose %s.", editar) },
		{ "Dentro de las mazmorras el juego no deja que los addons lean la vida ni los hechizos de los enemigos. Por eso los avisos de verdad son los de Blizzard, y Alfa te da los consejos de cada jefe antes de la pelea.",
			"Inside dungeons the game hides enemy health and spells from addons. That is why real warnings come from Blizzard, and Alfa gives you each boss's tips before the fight." },
		{ "Los consejos de cada jefe están en Mazmorras: elige una y mira su diario.",
			"Each boss's tips are under Dungeons: pick one and read its journal." },
	}
	y = consejos(notas, x, y, w)
	return y
end

---------------------------------------------------------------------------
-- Ajustes
---------------------------------------------------------------------------

V.AJUSTES = {
	{ kind = "toggle", key = ID .. ".historia", label = L["Modo historia"],
		help = L["Los jefes se descubren al vencerlos: su nombre y su botín quedan ocultos hasta entonces. Sus consejos siempre se pueden ver."] },
	{ kind = "toggle", key = ID .. ".avisoDescubrir", label = L["Avisarme al descubrir un jefe"], child = true,
		help = L["Una línea en el chat cuando vences a un jefe nuevo."],
		disabled = function() return not N.Get(ID, "historia") end },
	{ kind = "toggle", key = ID .. ".avisoEntrar", label = L["Aviso al entrar a una mazmorra"],
		help = L["Una línea en el chat con cuántos jefes tiene y cómo ver sus consejos."] },
	{ kind = "toggle", key = ID .. ".meSirve", label = L["Solo el botín que me sirve"],
		help = L["Oculta lo que tu clase no puede usar o no le conviene: armadura de otro tipo, armas que no usas, piezas sin nada para tu especialización."] },
	{ kind = "toggle", label = L["Entradas en el minimapa"],
		help = L["Marca en el minimapa la entrada de cada mazmorra (en verde las que ya hiciste). El mapa del mundo ya las marca solo."],
		get = function() return M.Capa ~= nil and M.Capa.Activa() end,
		set = function(on) if M.Capa then M.Capa.Poner(on ~= false) end V.RefrescarPronto() end },
}

local function pintarAjustes(x, y, w)
	y = filas(V.AJUSTES, "cacheAjustes", "PanelAjustes", y) + 18
	local _, h = texto("note", "textMuted", L["Tu progreso se guarda por personaje; los ajustes, para toda la cuenta."], x, y, w)
	return y + h + 8
end

---------------------------------------------------------------------------
-- La vista
---------------------------------------------------------------------------

function V.Render()
	if not vista then return 80 end
	soltarTodo()
	ocultarFilas()
	local w = ancho()
	local x = SH.pad
	local y = pestanias(x, 8, w)
	local s = estado.seccion
	if s == "mazmorra" and estado.clave then
		y = pintarMazmorra(x, y, w)
	elseif s == "progreso" then
		y = pintarProgreso(x, y, w)
	elseif s == "avisos" then
		y = pintarAvisos(x, y, w)
	elseif s == "ajustes" then
		y = pintarAjustes(x, y, w)
	else
		estado.seccion = "lista"
		y = pintarLista(x, y, w)
	end
	return y + 24
end

function V.Construir(view)
	vista = view
	capa = CreateFrame("Frame", nil, view)
	capa:SetAllPoints(view)
	capa:SetFrameLevel(view:GetFrameLevel() + 4)
	view.Capa = capa
	view.Refresh = function()
		local ok, h = pcall(V.Render)
		if not ok then
			if geterrorhandler then geterrorhandler()(h) end
			return 80
		end
		return h
	end
end

-- Repinta en su lugar (arriba: vuelve al principio de la página).
function V.Refrescar(arriba)
	if not (vista and vista:IsVisible()) then return end
	local h = vista.Refresh()
	vista:SetHeight(h)
	local win = ventana()
	if win and win.Body and win.Scroll then
		W.ShellBody(win, h)
		if arriba then W.ScrollTo(win.Scroll, 0) end
	end
end

local pronto = false
function V.RefrescarPronto()
	if pronto then return end
	pronto = true
	local function ya()
		pronto = false
		V.Refrescar()
	end
	if A.After then A.After(0.1, ya) else ya() end
end

function V.Ir(seccion, clave)
	estado.seccion = seccion
	if clave then estado.clave = clave end
	V.Refrescar(true)
end

-- Abre la página en una mazmorra (desde el chat, el minimapa o la lista).
function V.AbrirMazmorra(key)
	if type(key) ~= "string" then return end
	estado.seccion, estado.clave = "mazmorra", key
	if vista and vista:IsVisible() then
		V.Refrescar(true)
	else
		N.Abrir(ID)
	end
end

---------------------------------------------------------------------------
-- La página, el comando y lo que la repinta
---------------------------------------------------------------------------

N.Modulo({
	id = ID, nombre = L["Mazmorras"], icono = "icon-dungeon", orden = 50,
	subtitulo = L["Jefes, botín, consejos y tu progreso en cada mazmorra."],
	comando = "mazmorras",
	ajustes = { historia = true, avisoDescubrir = true, avisoEntrar = true, meSirve = false, capaEntradas = true },
	controles = V.AJUSTES,
	construir = function(view) V.Construir(view) end,
})

-- Minúsculas y sin acentos, para buscar como uno escribe ("sima ignea").
local ACENTOS = {
	["\195\161"] = "a", ["\195\169"] = "e", ["\195\173"] = "i", ["\195\179"] = "o", ["\195\186"] = "u",
	["\195\188"] = "u", ["\195\177"] = "n", ["\195\129"] = "a", ["\195\137"] = "e", ["\195\141"] = "i",
	["\195\147"] = "o", ["\195\154"] = "u", ["\195\156"] = "u", ["\195\145"] = "n",
}
local function plano(s)
	return (tostring(s or ""):gsub("\195[\128-\191]", ACENTOS):lower():gsub("[^%w]+", " "):gsub("^ +", ""):gsub(" +$", ""))
end

-- -> key | nil: igual, luego al principio, luego en cualquier parte del nombre.
local function buscarMazmorra(texto)
	local q = plano(texto)
	if q == "" then return nil end
	local inicio, dentro
	for _, d in ipairs(D.Lista()) do
		local n = plano(d.name)
		if n == q or d.key == q then return d.key end
		if not inicio and n:sub(1, #q) == q then inicio = d.key end
		if not dentro and n:find(q, 1, true) then dentro = d.key end
	end
	if inicio or dentro then return inicio or dentro end
	local Dg = A.Dungeons
	local key = Dg and Dg.Find and llamar(Dg.Find, texto)
	return type(key) == "string" and key or nil
end
V.Buscar = buscarMazmorra

-- /alfa mazmorras [nombre]: la página, o una mazmorra por su nombre.
A.RegisterCommand("mazmorras", function(rest)
	rest = type(rest) == "string" and rest or ""
	if rest ~= "" then
		local key = D.Listo() and buscarMazmorra(rest)
		if type(key) == "string" then return V.AbrirMazmorra(key) end
		N.Imprimir(format(L["No encontré una mazmorra llamada «%s»."], rest))
	end
	if estado.seccion == "mazmorra" then estado.seccion = "lista" end
	N.Abrir(ID)
end, L["Jefes, botín, consejos y tu progreso en cada mazmorra."])

D.AlCambiar(function() V.RefrescarPronto() end)

A.On("SETTING_CHANGED", function(path)
	if type(path) == "string" and (path == "" or path == ID or path:sub(1, #ID + 1) == ID .. ".") then
		V.RefrescarPronto()
	end
end)
A.On("GEAR_UPDATED", function() V.RefrescarPronto() end)

local function siObjetos()
	if estado.seccion == "mazmorra" or estado.seccion == "progreso" then V.RefrescarPronto() end
end
A.RegisterEvent("GET_ITEM_INFO_RECEIVED", siObjetos)
A.RegisterEvent("PLAYER_LEVEL_UP", function() V.RefrescarPronto() end)
A.RegisterEvent("QUEST_TURNED_IN", function() V.RefrescarPronto() end)
