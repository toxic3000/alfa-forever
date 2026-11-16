-- Alfa - Builds: la página en la ventana de Alfa (Toxic / La Jauría). GPL-3.0.
--
-- Cinco pestañas dentro de la página (la ventana de Alfa da una sola vista
-- a los módulos): Asistente, Talentos, Equipo, Combate y Compartir. Todo se
-- arma una vez (V.Construir) y se acomoda en cada Refresh, que devuelve la
-- altura para el desplazamiento. V.Relayout() vuelve a acomodar donde está.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local W, Th = A.Widgets, A.Theme
local V = {}
M.Vista = V

local floor, ceil, max, min, format = math.floor, math.ceil, math.max, math.min, string.format
local SH = W.SHELL
local GAP = 12

local function borde(f, nombre, alfa, grosor) return M.Borde(f, nombre, alfa, grosor) end

local function ventana()
	local O = A.UI and A.UI.Options
	return O and O.frame
end

local function ancho()
	if N.AnchoPagina then return N.AnchoPagina() end
	local win = ventana()
	return (win and win.BodyWidth) or 560
end

local function alto(fs)
	local h = fs:GetStringHeight() or 0
	return ceil(h)
end

local function poner(w, padre, x, y)
	w:ClearAllPoints()
	w:SetPoint("TOPLEFT", padre, "TOPLEFT", x, -y)
	w:Show()
end

local function texto(padre, rol, color)
	local fs = W.Text(padre, rol or "note", color or "textDim")
	fs:SetWordWrap(true)
	fs:SetJustifyV("TOP")
	fs:SetSpacing(2)
	return fs
end

local function ponerTexto(fs, padre, x, y, w, s)
	fs:SetText(s or "")
	fs:SetWidth(w)
	poner(fs, padre, x, y)
	return alto(fs)
end

local function seccion(padre)
	return W.SectionHeader(padre, { plain = true })
end

local function ponerSeccion(h, padre, x, y, w, titulo, cuenta)
	W.SetSection(h, titulo, cuenta)
	h:SetWidth(w)
	poner(h, padre, x, y)
	return W.PLAIN_SECTION_H
end

local function tarjeta(padre)
	local f = CreateFrame("Frame", nil, padre)
	Th.Skin(f, "panel")
	return f
end

---------------------------------------------------------------------------
-- Piezas: opciones (tiles), chips con ícono, filas
---------------------------------------------------------------------------

-- Una opción grande: ícono, título, descripción y un borde de acento cuando
-- está elegida. Atenuada cuando no hay builds para ella.
local function opcion(padre, alClic)
	local b = CreateFrame("Button", nil, padre)
	Th.Skin(b, "tile")
	b.Icon = b:CreateTexture(nil, "ARTWORK")
	b.Icon:SetSize(20, 20)
	b.Icon:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -12)
	b.Titulo = W.Text(b, "body", "text")
	b.Titulo:SetPoint("LEFT", b.Icon, "RIGHT", 8, 0)
	b.Desc = texto(b, "small", "textMuted")
	b.Desc:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -40)
	b.Sel = CreateFrame("Frame", nil, b)
	b.Sel:SetAllPoints(b)
	b.Sel:SetFrameLevel(b:GetFrameLevel() + 2)
	borde(b.Sel, "accent", 1, 2)
	b.Sel.Fondo = W.Fill(b.Sel, "accent", "BACKGROUND")
	W.Color(b.Sel.Fondo, "accent", 0.08)
	b.Sel:Hide()
	b.Check = W.Tex(b, "OVERLAY", "check", "accent")
	b.Check:SetSize(12, 12)
	b.Check:SetPoint("TOPRIGHT", b, "TOPRIGHT", -10, -12)
	b.Check:Hide()
	b.Riesgo = {}
	b:SetScript("OnClick", alClic)
	b:SetScript("OnEnter", W.SimpleTip)
	b:SetScript("OnLeave", W.HideTip)
	return b
end

local function marcarOpcion(b, elegida, apagada)
	b.Sel:SetShown(elegida and true or false)
	b.Check:SetShown(elegida and true or false)
	W.Color(b.Icon, elegida and "accent" or (apagada and "textMuted" or "icon"))
	W.Color(b.Titulo, apagada and "textMuted" or "text")
	b:SetAlpha(apagada and 0.6 or 1)
end

local function disponerOpcion(b, w)
	b:SetWidth(w)
	b.Titulo:SetWidth(w - 60)
	b.Desc:SetWidth(w - 24)
	local h = 40 + alto(b.Desc) + 12
	if b.Riesgo[1] then h = h + 12 end
	b:SetHeight(max(70, h))
	return b:GetHeight()
end

-- Medidor de riesgo: tres barritas, coloreadas según el estilo.
local COLOR_RIESGO = { "success", "accent", "danger" }
local function medidor(b, nivel)
	for i = 1, 3 do
		local t = b.Riesgo[i]
		if not t then
			t = W.Tex(b, "ARTWORK")
			t:SetSize(14, 4)
			b.Riesgo[i] = t
		end
		t:ClearAllPoints()
		t:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 12 + (i - 1) * 17, 10)
		W.Color(t, i <= nivel and COLOR_RIESGO[nivel] or "textMuted", i <= nivel and 1 or 0.35)
	end
end

-- Un chip con ícono de hechizo (las ramas).
local function chipRama(padre, alClic)
	local b = CreateFrame("Button", nil, padre)
	Th.Skin(b, "tile")
	b:SetHeight(30)
	b.Icon = b:CreateTexture(nil, "ARTWORK")
	b.Icon:SetSize(20, 20)
	b.Icon:SetPoint("LEFT", b, "LEFT", 6, 0)
	b.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.Label = W.Text(b, "label", "text")
	b.Label:SetPoint("LEFT", b.Icon, "RIGHT", 6, 0)
	b.Sel = CreateFrame("Frame", nil, b)
	b.Sel:SetAllPoints(b)
	b.Sel:SetFrameLevel(b:GetFrameLevel() + 2)
	borde(b.Sel, "accent", 1, 2)
	b.Sel:Hide()
	b:SetScript("OnClick", alClic)
	b:SetScript("OnEnter", W.SimpleTip)
	b:SetScript("OnLeave", W.HideTip)
	return b
end

local function ponerChipRama(b, icono, texto_, elegida)
	b.Icon:SetTexture(icono)
	b.Label:SetText(texto_)
	b:SetWidth(floor(b.Label:GetStringWidth() + 44))
	b.Sel:SetShown(elegida and true or false)
	W.Color(b.Label, elegida and "accent" or "text")
	return b:GetWidth()
end

-- Fila de chips en una línea (o varias si no caben). -> alto usado
local function filaChips(chips, padre, x, y, w)
	local cx, cy, h = 0, 0, 0
	for _, c in ipairs(chips) do
		local cw = c:GetWidth()
		if cx > 0 and cx + cw > w then
			cx, cy = 0, cy + h + 6
			h = 0
		end
		poner(c, padre, x + cx, y + cy)
		cx = cx + cw + 6
		h = max(h, c:GetHeight())
	end
	return cy + h
end

---------------------------------------------------------------------------
-- Estado común: build elegido, árbol vivo, avance
---------------------------------------------------------------------------

local estado = {} -- se renueva en cada Refresh

local function leerEstado()
	local b = M.BuildElegido()
	local vivo, razon = M.Arbol.Actual()
	local usandoFoto = false
	if not vivo then
		vivo = M.Arbol.VivoDeFoto()
		usandoFoto = vivo ~= nil
	end
	local res = b and vivo and M.Arbol.Resolver(b, vivo)
	local st = b and vivo and res and M.Arbol.Estado(b, vivo, res)
	estado = { build = b, vivo = vivo, razon = razon, foto = usandoFoto, res = res, st = st }
	return estado
end

local function nivelDe(i) return 9 + i end

local NOMBRE_ARMAS = { ["2h"] = L["Arma de dos manos"], dual = L["Dos armas"], escudo = L["Arma y escudo"] }

---------------------------------------------------------------------------
-- Cabecera: clase, nivel, rama y puntos
---------------------------------------------------------------------------

local function construirCabecera(view)
	local c = CreateFrame("Frame", nil, view)
	c:SetHeight(58)
	c.Icon = c:CreateTexture(nil, "ARTWORK")
	c.Icon:SetSize(40, 40)
	c.Icon:SetPoint("LEFT", c, "LEFT", 0, 0)
	c.Titulo = W.Text(c, "title", "text")
	c.Titulo:SetPoint("TOPLEFT", c.Icon, "TOPRIGHT", 12, -2)
	c.Sub = W.Text(c, "small", "textDim")
	c.Sub:SetPoint("TOPLEFT", c.Titulo, "BOTTOMLEFT", 0, -4)
	c.Barra = W.ProgressLine(c, 4)
	c.Barra:SetPoint("BOTTOMLEFT", c.Icon, "BOTTOMRIGHT", 12, 0)
	c.Puntos = W.Chip(c)
	c.Puntos:SetPoint("RIGHT", c, "RIGHT", 0, 6)
	return c
end

local function disponerCabecera(c, w)
	local _, token = UnitClass("player")
	token = A.Compat.Readable(token)
	local coords = CLASS_ICON_TCOORDS and token and CLASS_ICON_TCOORDS[token]
	if coords then
		c.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
		c.Icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	else
		c.Icon:SetTexture(Th.Media("icon-skill"))
		W.Color(c.Icon, "accent")
	end
	local dc = M.DatosClase()
	local nivel = A.Compat.Readable(UnitLevel("player")) or 1
	local rama = M.SpecActual()
	local nombreRama = rama and dc and dc.especialidades[rama] and dc.especialidades[rama].nombre
	c.Titulo:SetText(format("%s %s", dc and dc.nombre or L["Tu personaje"], format(L["nivel %d"], nivel)))
	local st, b = estado.st, estado.build
	local partes = {}
	partes[#partes + 1] = nombreRama and format(L["Tus puntos van en %s"], nombreRama) or L["Todavía no gastas puntos de talento"]
	if st and b then partes[#partes + 1] = format(L["%d de %d talentos del plan"], st.hechos, st.total) end
	c.Sub:SetText(table.concat(partes, "  \194\183  "))
	c.Barra:SetWidth(max(1, w - 52 - 140))
	W.SetProgress(c.Barra, (st and st.total > 0) and st.hechos / st.total or 0, max(1, w - 52 - 140), true)
	local libres = st and st.libres or 0
	if estado.foto then
		W.SetChip(c.Puntos, L["Árbol sin cargar"], "neutral")
	elseif libres > 0 then
		W.SetChip(c.Puntos, format(libres == 1 and L["%d punto libre"] or L["%d puntos libres"], libres), "accent")
	else
		W.SetChip(c.Puntos, L["Sin puntos libres"], "neutral")
	end
	c:SetWidth(w)
	return c:GetHeight()
end

---------------------------------------------------------------------------
-- Pestañas propias
---------------------------------------------------------------------------

local TABS = {
	{ clave = "asistente", nombre = L["Asistente"] },
	{ clave = "talentos", nombre = L["Talentos"] },
	{ clave = "equipo", nombre = L["Equipo"] },
	{ clave = "combate", nombre = L["Combate"] },
	{ clave = "compartir", nombre = L["Compartir"] },
}
V.TABS = TABS

local function tabActual()
	local d = N.DatosPersonaje(M.ID)
	return d.tab or "asistente"
end

function V.IrA(clave)
	local d = N.DatosPersonaje(M.ID)
	d.tab = clave
	V.Relayout(true)
end

local function construirTabs(view)
	local fila = CreateFrame("Frame", nil, view)
	fila:SetHeight(32)
	fila.Botones = {}
	for i, t in ipairs(TABS) do
		local b = CreateFrame("Button", nil, fila)
		b:SetHeight(32)
		Th.Skin(b, "tab")
		b.Label = W.Text(b, "label", "tabRest")
		b.Label:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.Label:SetText(t.nombre)
		b:SetWidth(floor(b.Label:GetStringWidth() + 28))
		b:SetScript("OnClick", function() V.IrA(t.clave) end)
		fila.Botones[i] = b
	end
	fila.Linea = W.Divider(fila)
	fila.Linea:SetPoint("BOTTOMLEFT", fila, "BOTTOMLEFT", 0, 0)
	fila.Linea:SetPoint("BOTTOMRIGHT", fila, "BOTTOMRIGHT", 0, 0)
	return fila
end

local function disponerTabs(fila, w)
	local x = 0
	local actual = tabActual()
	for i, t in ipairs(TABS) do
		local b = fila.Botones[i]
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", fila, "BOTTOMLEFT", x, 0)
		Th.SetTabSelected(b, t.clave == actual)
		W.Color(b.Label, t.clave == actual and "text" or "tabRest")
		x = x + b:GetWidth()
	end
	fila:SetWidth(w)
	return 32
end

---------------------------------------------------------------------------
-- Pestaña Asistente
---------------------------------------------------------------------------

local asis = {}

local function elegir(objetivo, estilo, spec)
	M.ElegirBuild(objetivo, estilo, spec)
	V.Relayout()
end

local function construirAsistente(c)
	asis.hObj = seccion(c)
	asis.hEst = seccion(c)
	asis.objetivos, asis.estilos = {}, {}
	for i, o in ipairs(M.OBJETIVOS) do
		local b = opcion(c, function()
			local e = M.Eleccion()
			elegir(o.clave, e.estilo, nil)
		end)
		b.Icon:SetTexture(Th.Media(o.icono))
		b.Titulo:SetText(o.nombre)
		b.Desc:SetText(o.desc)
		asis.objetivos[i] = b
	end
	for i, e in ipairs(M.ESTILOS) do
		local b = opcion(c, function()
			local el = M.Eleccion()
			elegir(el.objetivo, e.clave, el.spec)
		end)
		b.Icon:SetTexture(Th.Media(e.icono))
		b.Titulo:SetText(e.nombre)
		b.Desc:SetText(e.desc)
		medidor(b, e.riesgo)
		asis.estilos[i] = b
	end
	asis.ramaLabel = W.Text(c, "small", "textMuted")
	asis.ramaLabel:SetText(L["Rama:"])
	asis.ramas = {}
	asis.nota = texto(c, "small", "warning")

	-- La tarjeta del build
	local t = tarjeta(c)
	asis.card = t
	t.Icon = t:CreateTexture(nil, "ARTWORK")
	t.Icon:SetSize(44, 44)
	t.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	t.IconBorde = CreateFrame("Frame", nil, t)
	t.IconBorde:SetAllPoints(t.Icon)
	borde(t.IconBorde, "accent")
	t.Titulo = W.Text(t, "display", "text")
	t.Chips = { W.Chip(t), W.Chip(t), W.Chip(t), W.Chip(t), W.Chip(t) }
	t.Resumen = texto(t, "body", "textDim")
	t.Arma = W.Text(t, "small", "textMuted")
	t.Aplicar = W.Button(t, L["Aplicar talentos"], function() M.PedirAplicar() end, { primary = true, icon = "icon-learn" })
	t.Aplicar.psTip = L["Compra los talentos del plan que te tocan hasta tu nivel. Antes te muestra qué va a cambiar."]
	t.Arbol = W.Button(t, L["Ver el árbol"], function() V.IrA("talentos") end, { ghost = true })
	t.Pesos = W.Button(t, "", function()
		local b = estado.build
		if not b then return end
		if M.Pesos.Activa() == b.id then
			M.Pesos.Desactivar()
		else
			local ok, msg = M.Pesos.Activar(b)
			N.Imprimir(msg)
		end
		V.Relayout()
	end, { ghost = true })
	t.Pesos.psTip = L["Las flechas de mejora de tus bolsas y los cuadros de los objetos usan los pesos de este build."]

	asis.hProx = seccion(c)
	asis.prox = {}
	asis.verTodo = W.Link(c, L["Ver todos los talentos en orden"], function() V.IrA("talentos") end)
	asis.verTodo.psTip = nil
	asis.hStats = seccion(c)
	asis.stats = {}
	asis.statsNota = texto(c, "small", "textMuted")
	asis.hProf = seccion(c)
	asis.prof = {}
	asis.profNota = texto(c, "note", "textDim")
	asis.hTips = seccion(c)
	asis.tips = texto(c, "note", "textDim")
	asis.vacio = texto(c, "body", "textDim")
end

-- Fila compacta de "próximo talento".
local function filaProx(padre)
	local f = CreateFrame("Button", nil, padre)
	f:SetHeight(34)
	f.Icon = f:CreateTexture(nil, "ARTWORK")
	f.Icon:SetSize(26, 26)
	f.Icon:SetPoint("LEFT", f, "LEFT", 0, 0)
	f.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	f.Nivel = W.Text(f, "caption", "textMuted")
	f.Nivel:SetPoint("LEFT", f.Icon, "RIGHT", 10, 0)
	f.Nivel:SetWidth(64)
	f.Nombre = W.Text(f, "body", "text")
	f.Nombre:SetPoint("LEFT", f.Nivel, "RIGHT", 4, 0)
	f.Estado = W.Chip(f)
	f.Estado:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	W.Hover(f, 0.6)
	f:SetScript("OnEnter", function(self) if self.spell then W.SpellTip(self, self.spell, self.extra) end end)
	f:SetScript("OnLeave", W.HideTip)
	f:SetScript("OnClick", function(self) if self.spell then W.SpellClick(self.spell) end end)
	return f
end

-- Las entradas del build (un talento subido hasta un rango) con su avance.
local function entradas(b, st, res)
	local out = {}
	for _, p in ipairs(b.picks) do
		local e = out[p.entrada]
		if not e then
			e = { entrada = p.entrada, spell = p.spell, desde = p.i, hasta = p.i, rank = p.rank, nombre = p.nombre, por = p.por, estados = {} }
			out[p.entrada] = e
		end
		e.hasta, e.rank = p.i, p.rank
		e.primerRango = e.primerRango or p.rank
		e.por = e.por or p.por
		local s = st and st.estadoPick[p.i] or "pendiente"
		e.estados[s] = true
	end
	local lista = {}
	for i = 1, #b.talentos do if out[i] then lista[#lista + 1] = out[i] end end
	for _, e in ipairs(lista) do
		if e.estados.falta then e.estado = "falta"
		elseif e.estados.siguiente then e.estado = "siguiente"
		elseif e.estados.pendiente then e.estado = "pendiente"
		else e.estado = "hecho" end
		local id = res and res.nodo[e.spell]
		local n = id and estado.vivo and estado.vivo.nodos[id]
		e.max = n and n.max or e.rank
		e.nombreVivo = (n and n.nombre) or M.Arbol.Nombre(e.spell) or e.nombre or tostring(e.spell)
		e.icono = (n and n.icono) or M.Arbol.Icono(e.spell)
	end
	return lista
end
V.Entradas = entradas

local ESTADO_CHIP = {
	hecho = { L["Hecho"], "success" }, siguiente = { L["Siguiente"], "accent" },
	pendiente = { L["Más adelante"], "neutral" }, falta = { L["No está en tu árbol"], "warning" },
}

local function textoNiveles(e)
	local a, b = nivelDe(e.desde), nivelDe(e.hasta)
	if a == b then return format(L["Nv %d"], a) end
	return format(L["Nv %d-%d"], a, b)
end

local function textoRango(e)
	if e.primerRango and e.primerRango ~= e.rank then return format("%d-%d/%d", e.primerRango, e.rank, e.max or e.rank) end
	return format("%d/%d", e.rank, e.max or e.rank)
end

local function disponerAsistente(c, w)
	local x, y = SH.pad, 4
	local inner = w
	local el = M.Eleccion()
	local b = estado.build
	if not M.DatosClase() then
		local h = ponerTexto(asis.vacio, c, x, y + 8, inner, L["Alfa todavía no tiene builds para tu clase."])
		return y + h + 24
	end
	asis.vacio:Hide()
	-- Paso 1: objetivo
	y = y + ponerSeccion(asis.hObj, c, x, y, inner, L["1. ¿Qué quieres hacer?"])
	local n = #asis.objetivos
	local cw = floor((inner - (n - 1) * 8) / n)
	local fh = 0
	for i, op in ipairs(asis.objetivos) do
		local o = M.OBJETIVOS[i]
		local hay = M.Hay(o.clave)
		op.psTip = not hay and L["Todavía no hay builds de este tipo para tu clase: Alfa te muestra el más parecido."] or nil
		marcarOpcion(op, el.objetivo == o.clave, not hay)
		fh = max(fh, disponerOpcion(op, cw))
	end
	for i, op in ipairs(asis.objetivos) do op:SetHeight(fh); poner(op, c, x + (i - 1) * (cw + 8), y) end
	y = y + fh + 16
	-- Paso 2: estilo
	y = y + ponerSeccion(asis.hEst, c, x, y, inner, L["2. ¿Cómo te gusta jugar?"])
	n = #asis.estilos
	cw = floor((inner - (n - 1) * 8) / n)
	fh = 0
	for i, op in ipairs(asis.estilos) do
		local e = M.ESTILOS[i]
		local hay = M.Hay(el.objetivo, e.clave)
		op.psTip = not hay and L["No hay un build con este estilo para lo que elegiste: Alfa usa el más cercano."] or nil
		marcarOpcion(op, el.estilo == e.clave, not hay)
		fh = max(fh, disponerOpcion(op, cw))
	end
	for i, op in ipairs(asis.estilos) do op:SetHeight(fh); poner(op, c, x + (i - 1) * (cw + 8), y) end
	y = y + fh + 14
	-- Ramas posibles para el objetivo
	local ramas, vistas = {}, {}
	for _, x2 in ipairs(M.Builds()) do
		if x2.objetivo == el.objetivo and not vistas[x2.spec] then vistas[x2.spec] = true; ramas[#ramas + 1] = x2.spec end
	end
	for _, r in ipairs(asis.ramas) do r:Hide() end
	if #ramas > 1 then
		poner(asis.ramaLabel, c, x, y + 8)
		local chips = {}
		local dc = M.DatosClase()
		for i, spec in ipairs(ramas) do
			local ch = asis.ramas[i]
			if not ch then
				ch = chipRama(c, function(self) elegir(M.Eleccion().objetivo, M.Eleccion().estilo, self.spec) end)
				asis.ramas[i] = ch
			end
			ch.spec = spec
			local sp = dc.especialidades[spec]
			ch.psTip = sp and sp.desc
			ponerChipRama(ch, sp and A.Compat.SpellIcon(sp.icono), sp and sp.nombre or spec, b and b.spec == spec)
			chips[#chips + 1] = ch
		end
		y = y + filaChips(chips, c, x + 44, y, inner - 44) + 12
	else
		asis.ramaLabel:Hide()
	end
	-- Aviso si no es exacto
	if M.EleccionExacta and not M.EleccionExacta() and b then
		local e = M.Estilo(b.estilo)
		y = y + ponerTexto(asis.nota, c, x, y, inner, format(L["No hay exactamente esa combinación. Te mostramos %s (%s), lo más parecido."], b.titulo, e and e.nombre or b.estilo)) + 10
	else
		asis.nota:Hide()
	end
	if not b then return y + 24 end

	-- Tarjeta del build
	local t = asis.card
	local pad = 16
	local tw = inner - 2 * pad
	local dc = M.DatosClase()
	local sp = dc and dc.especialidades[b.spec]
	t.Icon:SetTexture(sp and A.Compat.SpellIcon(sp.icono) or Th.Media("icon-skill"))
	poner(t.Icon, t, pad, pad)
	t.Titulo:SetText(b.titulo or b.id)
	t.Titulo:ClearAllPoints()
	t.Titulo:SetPoint("TOPLEFT", t, "TOPLEFT", pad + 56, -pad)
	t.Titulo:SetWidth(tw - 56)
	local chips = {}
	W.SetChip(t.Chips[1], M.NombreSpec(b), "neutral"); chips[#chips + 1] = t.Chips[1]
	local o, e = M.Objetivo(b.objetivo), M.Estilo(b.estilo)
	W.SetChip(t.Chips[2], o and o.nombre or b.objetivo, "neutral"); chips[#chips + 1] = t.Chips[2]
	W.SetChip(t.Chips[3], e and e.nombre or b.estilo, b.estilo == "arriesgado" and "warning" or (b.estilo == "tranquilo" and "success" or "neutral")); chips[#chips + 1] = t.Chips[3]
	local rec = M.Recomendado(b.objetivo)
	if rec and rec.id == b.id then
		W.SetChip(t.Chips[4], L["Recomendado por Alfa"], "accent"); chips[#chips + 1] = t.Chips[4]
	else
		t.Chips[4]:Hide()
	end
	if b.importado then
		W.SetChip(t.Chips[5], L["Importado"], "dungeon"); chips[#chips + 1] = t.Chips[5]
	else
		t.Chips[5]:Hide()
	end
	local yy = pad + 26
	yy = yy + filaChips(chips, t, pad + 56, yy, tw - 56)
	yy = max(yy, pad + 44) + 12
	yy = yy + ponerTexto(t.Resumen, t, pad, yy, tw, b.resumen or "") + 8
	if b.armas and NOMBRE_ARMAS[b.armas] then
		t.Arma:SetText(L["Arma:"] .. " " .. NOMBRE_ARMAS[b.armas])
		poner(t.Arma, t, pad, yy)
		yy = yy + 18
	else
		t.Arma:Hide()
	end
	yy = yy + 6
	local activa = M.Pesos.Activa() == b.id
	W.SetButtonText(t.Pesos, activa and L["Pesos activos"] or L["Activar pesos"])
	poner(t.Aplicar, t, pad, yy)
	t.Arbol:ClearAllPoints(); t.Arbol:SetPoint("LEFT", t.Aplicar, "RIGHT", 8, 0); t.Arbol:Show()
	t.Pesos:ClearAllPoints(); t.Pesos:SetPoint("LEFT", t.Arbol, "RIGHT", 8, 0); t.Pesos:Show()
	if t.Pesos.Label then W.Color(t.Pesos.Label, activa and "success" or "buttonText") end
	yy = yy + t.Aplicar:GetHeight() + pad
	t:SetSize(inner, yy)
	poner(t, c, x, y)
	y = y + yy + 18

	-- Próximos talentos
	local lista = entradas(b, estado.st, estado.res)
	local proximos = {}
	for _, en in ipairs(lista) do
		if en.estado == "siguiente" or en.estado == "pendiente" then proximos[#proximos + 1] = en end
		if #proximos >= 4 then break end
	end
	for _, f in ipairs(asis.prox) do f:Hide() end
	y = y + ponerSeccion(asis.hProx, c, x, y, inner, L["Tus próximos talentos"])
	if #proximos == 0 then
		local f = asis.prox[1] or filaProx(c)
		asis.prox[1] = f
		f.spell = nil
		f.Icon:SetTexture(Th.Media("check"))
		f.Nivel:SetText("")
		f.Nombre:SetText(L["¡Completaste todo el plan!"])
		f.Estado:Hide()
		f:SetWidth(inner)
		poner(f, c, x, y)
		y = y + 36
	else
		for i, en in ipairs(proximos) do
			local f = asis.prox[i] or filaProx(c)
			asis.prox[i] = f
			f.spell = en.spell
			f.extra = en.por and function(tip) tip:AddLine(" "); tip:AddLine(en.por, 1, 0.82, 0, true) end or nil
			f.Icon:SetTexture(en.icono)
			f.Nivel:SetText(textoNiveles(en))
			f.Nombre:SetText(en.nombreVivo .. "  " .. textoRango(en))
			f.Nombre:SetWidth(inner - 30 - 78 - 130)
			local ch = ESTADO_CHIP[en.estado]
			W.SetChip(f.Estado, ch[1], ch[2])
			f:SetWidth(inner)
			poner(f, c, x, y)
			y = y + 36
		end
	end
	poner(asis.verTodo, c, x, y + 2)
	y = y + 28

	-- Prioridad de estadísticas
	y = y + ponerSeccion(asis.hStats, c, x, y, inner, L["Prioridad de estadísticas"])
	local orden = M.Pesos.Orden(b)
	for _, s in ipairs(asis.stats) do s.Num:Hide(); s.Nombre:Hide(); s.Barra:Hide(); s.Por:Hide() end
	for i, s in ipairs(orden) do
		local row = asis.stats[i]
		if not row then
			row = {
				Num = W.Text(c, "number", "accent"), Nombre = W.Text(c, "body", "text"),
				Barra = W.ProgressLine(c, 6), Por = texto(c, "small", "textMuted"),
			}
			asis.stats[i] = row
		end
		local info = M.STATS[s.clave] or { nombre = s.clave, porque = "" }
		row.Num:SetText(tostring(i))
		poner(row.Num, c, x, y + 2)
		row.Nombre:SetText(info.nombre)
		row.Nombre:SetWidth(170)
		poner(row.Nombre, c, x + 22, y + 2)
		local bw = max(60, floor(inner * 0.32))
		row.Barra:SetWidth(bw)
		poner(row.Barra, c, x + 200, y + 7)
		W.SetProgress(row.Barra, s.relativo or 0.5, bw, true)
		local ph = ponerTexto(row.Por, c, x + 200 + bw + 12, y + 1, inner - (200 + bw + 12), info.porque)
		y = y + max(24, ph + 8)
	end
	y = y + 4
	y = y + ponerTexto(asis.statsNota, c, x, y, inner, L["El orden importa más que los números: busca piezas con las primeras estadísticas de la lista. Al elegir este build, Alfa usa estos pesos en las flechas de mejora."]) + 16

	-- Profesiones
	y = y + ponerSeccion(asis.hProf, c, x, y, inner, L["Profesiones sugeridas"])
	local prof = M.Profesiones(b)
	local lista2 = { { prof[1], true }, { prof[2], true } }
	for _, s in ipairs(M.PROF_SECUNDARIAS) do lista2[#lista2 + 1] = { s[1], false, s[2] } end
	for _, p in ipairs(asis.prof) do p:Hide() end
	local pw = floor((inner - 3 * 8) / 4)
	local ph = 0
	for i, it in ipairs(lista2) do
		local p = asis.prof[i]
		if not p then
			p = CreateFrame("Frame", nil, c)
			Th.Skin(p, "tile")
			p.Icon = p:CreateTexture(nil, "ARTWORK")
			p.Icon:SetSize(28, 28)
			p.Icon:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -10)
			p.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			p.Nombre = W.Text(p, "body", "text")
			p.Nombre:SetPoint("TOPLEFT", p.Icon, "TOPRIGHT", 8, -1)
			p.Tipo = W.Text(p, "caption", "textMuted")
			p.Tipo:SetPoint("TOPLEFT", p.Nombre, "BOTTOMLEFT", 0, -2)
			p.Por = texto(p, "small", "textDim")
			p.Por:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -46)
			asis.prof[i] = p
		end
		local def = M.PROFESIONES[it[1]] or { nombre = it[1] }
		p.Icon:SetTexture(def.icono)
		p.Nombre:SetText(def.nombre)
		p.Nombre:SetWidth(pw - 56)
		p.Tipo:SetText(it[2] and L["Principal"] or L["Secundaria"])
		W.Color(p.Tipo, it[2] and "accent" or "textMuted")
		p.Por:SetWidth(pw - 20)
		p.Por:SetText(it[2] and (i == 1 and (prof[3] or "") or "") or (it[3] or ""))
		p:SetWidth(pw)
		ph = max(ph, 46 + alto(p.Por) + 10)
	end
	for i in ipairs(lista2) do
		local p = asis.prof[i]
		p:SetHeight(max(60, ph))
		poner(p, c, x + (i - 1) * (pw + 8), y)
	end
	y = y + max(60, ph) + 8
	y = y + ponerTexto(asis.profNota, c, x, y, inner, L["Solo puedes tener dos principales a la vez; las secundarias son libres. Aprende cualquiera con su entrenador en las ciudades."]) + 16

	-- Consejos
	if b.consejos and #b.consejos > 0 then
		y = y + ponerSeccion(asis.hTips, c, x, y, inner, L["Consejos para jugarlo"])
		local lineas = {}
		for _, s in ipairs(b.consejos) do lineas[#lineas + 1] = "\226\128\162  " .. s end
		y = y + ponerTexto(asis.tips, c, x, y, inner, table.concat(lineas, "\n")) + 16
	else
		asis.hTips:Hide()
		asis.tips:Hide()
	end
	return y + 16
end

---------------------------------------------------------------------------
-- Pestaña Talentos: árbol dibujado y lista en orden
---------------------------------------------------------------------------

local tal = {}

local function nodoBoton(padre)
	local b = CreateFrame("Button", nil, padre)
	b.Fondo = W.Fill(b, "shade", "BACKGROUND")
	b.Icon = b:CreateTexture(nil, "ARTWORK")
	b.Icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.Icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.Rango = W.Text(b, "caption", "text", "OVERLAY")
	b.Rango:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 4, -4)
	Th.SetOutline(b.Rango, true)
	b.Orden = CreateFrame("Frame", nil, b)
	b.Orden:SetSize(18, 13)
	b.Orden:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 4)
	b.Orden:SetFrameLevel(b:GetFrameLevel() + 3)
	b.Orden.Bg = W.Fill(b.Orden, "shade")
	b.Orden.Text = W.Text(b.Orden, "caption", "accent")
	b.Orden.Text:SetPoint("CENTER", b.Orden, "CENTER", 0, 0)
	b:SetScript("OnEnter", function(self)
		if not self.spell then return end
		W.SpellTip(self, self.spell, function(tip)
			if self.lineas then
				tip:AddLine(" ")
				for _, l in ipairs(self.lineas) do tip:AddLine(l[1], l[2], l[3], l[4], true) end
			end
		end)
	end)
	b:SetScript("OnLeave", W.HideTip)
	b:SetScript("OnClick", function(self) if self.spell then W.SpellClick(self.spell) end end)
	return b
end

local function construirTalentos(c)
	tal.hArbol = seccion(c)
	tal.lienzo = CreateFrame("Frame", nil, c)
	tal.nodos, tal.lineas, tal.cabeceras = {}, {}, {}
	tal.leyenda = texto(c, "small", "textMuted")
	tal.aviso = texto(c, "small", "warning")
	tal.aplicar = W.Button(c, L["Aplicar talentos"], function() M.PedirAplicar() end, { primary = true, icon = "icon-learn" })
	-- La ventana del juego, como su tecla (Bindings_Camelot.xml). Nunca en
	-- combate ni con la interfaz de mando, que maneja sus propias ventanas.
	tal.abrir = W.Button(c, L["Abrir la ventana de talentos"], function()
		if InCombatLockdown() or (A.GamepadUI and A.GamepadUI()) then return end
		local U = PlayerSpellsUtil
		if U and U.ToggleClassTalentOrSpecFrame then pcall(U.ToggleClassTalentOrSpecFrame)
		elseif U and U.OpenToClassTalentsTab then pcall(U.OpenToClassTalentsTab) end
	end, { ghost = true })
	tal.hLista = seccion(c)
	tal.filas = {}
end

local function colorRGB(nombre)
	if nombre == "accent" then return Th.Accent() end
	local r, g, b = Th.Color(nombre)
	return r, g, b
end

local function disponerArbol(c, x, y, w)
	local st, vivo, res, b = estado.st, estado.vivo, estado.res, estado.build
	local d = M.Arbol.Disposicion(vivo)
	local nSpecs = max(3, #d.specs)
	local cols = d.columnas
	local gapSpec = 18
	local cell = floor((w - (nSpecs - 1) * gapSpec) / (nSpecs * cols))
	cell = min(46, max(26, cell))
	local icon = cell - 12
	local specW = cols * cell
	local headH = 24
	local lienzo = tal.lienzo
	-- primer pick de cada nodo y la entrada que lo explica
	local primero, porNodo = {}, {}
	if b and res then
		for _, p in ipairs(b.picks) do
			local id = res.nodo[p.spell]
			if id then
				primero[id] = primero[id] or p.i
				porNodo[id] = porNodo[id] or p.por
			end
		end
	end
	for _, h in ipairs(tal.cabeceras) do h:Hide() end
	for i = 1, nSpecs do
		local h = tal.cabeceras[i]
		if not h then
			h = W.Text(lienzo, "heading", "text")
			tal.cabeceras[i] = h
		end
		local s = d.specs[i]
		h:SetText(format("%s  |c%s%d|r", s and s.nombre or "?", Th.Hex("textMuted"), s and s.gastado or 0))
		h:SetWidth(specW)
		poner(h, lienzo, (i - 1) * (specW + gapSpec), 2)
	end
	local pos = {}
	local usados = 0
	for _, n in ipairs(d.nodos) do
		usados = usados + 1
		local nb = tal.nodos[usados]
		if not nb then
			nb = nodoBoton(lienzo)
			tal.nodos[usados] = nb
		end
		local px = ((n.spec or 1) - 1) * (specW + gapSpec) + (n.col - 1) * cell + floor((cell - icon) / 2)
		local py = headH + (n.fila - 1) * cell + floor((cell - icon) / 2)
		nb:SetSize(icon, icon)
		poner(nb, lienzo, px, py)
		pos[n.id] = { px + icon / 2, py, py + icon }
		local v = vivo and vivo.nodos[n.id]
		local activo = v and v.activo or 0
		local plan = st and st.planeado[n.id] or 0
		nb.spell = n.spell
		nb.Icon:SetTexture((v and v.icono) or M.Arbol.Icono(n.spell) or Th.Media("icon-skill"))
		local enPlan = plan > 0
		local fuera = activo > plan
		local esSig = st and st.siguiente and res and res.nodo[st.siguiente.spell] == n.id
		nb.Icon:SetDesaturated(not (enPlan or activo > 0))
		nb:SetAlpha((enPlan or activo > 0) and 1 or 0.45)
		nb.Rango:SetText(enPlan and format("%d/%d", activo, plan) or (activo > 0 and format("%d/%d", activo, n.max) or ""))
		W.Color(nb.Rango, (enPlan and activo >= plan) and "success" or "text")
		local colorBorde, grosor = "border", 1
		if fuera then colorBorde = "danger"
		elseif esSig then colorBorde, grosor = "accent", 2
		elseif enPlan and activo >= plan then colorBorde = "success"
		elseif enPlan then colorBorde = "accent" end
		local r, g, bl = colorRGB(colorBorde)
		Th.Border(nb, r, g, bl, (enPlan and activo < plan and not esSig) and 0.55 or 1, nil, grosor)
		if primero[n.id] then
			nb.Orden.Text:SetText(tostring(primero[n.id]))
			nb.Orden:SetWidth(max(14, nb.Orden.Text:GetStringWidth() + 6))
			nb.Orden:Show()
		else
			nb.Orden:Hide()
		end
		local lineas = {}
		local ar, ag, ab = Th.Accent()
		if primero[n.id] then
			lineas[#lineas + 1] = { format(L["Alfa: punto %d del plan (nivel %d), hasta %d/%d"], primero[n.id], nivelDe(primero[n.id]), plan, n.max), ar, ag, ab }
			if porNodo[n.id] then lineas[#lineas + 1] = { porNodo[n.id], 0.85, 0.85, 0.85 } end
		elseif activo > 0 then
			local dr, dg, db = Th.Color("danger")
			lineas[#lineas + 1] = { L["Alfa: este talento no está en tu build"], dr, dg, db }
		end
		if fuera and primero[n.id] then
			local dr, dg, db = Th.Color("danger")
			lineas[#lineas + 1] = { L["Tienes más rangos de los que pide el build"], dr, dg, db }
		end
		nb.lineas = lineas
	end
	for i = usados + 1, #tal.nodos do tal.nodos[i]:Hide() end
	-- Flechas
	local nl = 0
	for _, f in ipairs(d.flechas) do
		local a, z = pos[f.de], pos[f.a]
		if a and z then
			nl = nl + 1
			local ln = tal.lineas[nl]
			if not ln then
				ln = lienzo:CreateLine(nil, "BORDER")
				ln:SetTexture(Th.Media("white"))
				ln:SetThickness(2)
				tal.lineas[nl] = ln
			end
			ln:SetStartPoint("TOPLEFT", lienzo, a[1], -a[3])
			ln:SetEndPoint("TOPLEFT", lienzo, z[1], -z[2])
			local plan = st and st.planeado[f.a] or 0
			local r, g, bl = colorRGB(plan > 0 and "accent" or "textMuted")
			ln:SetVertexColor(r, g, bl, plan > 0 and 0.8 or 0.35)
			ln:Show()
		end
	end
	for i = nl + 1, #tal.lineas do tal.lineas[i]:Hide() end
	local h = headH + d.filas * cell + 6
	lienzo:SetSize(nSpecs * specW + (nSpecs - 1) * gapSpec, h)
	poner(lienzo, c, x, y)
	return h
end

local function filaTalento(padre)
	local f = CreateFrame("Button", nil, padre)
	f.Fondo = W.Fill(f, "panelAlt", "BACKGROUND")
	f.Icon = f:CreateTexture(nil, "ARTWORK")
	f.Icon:SetSize(30, 30)
	f.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	f.Nivel = W.Text(f, "caption", "textMuted")
	f.Nivel:SetWidth(62)
	f.Nombre = W.Text(f, "body", "text")
	f.Por = texto(f, "note", "textDim")
	f.Estado = W.Chip(f)
	W.Hover(f, 0.5)
	f:SetScript("OnEnter", function(self) if self.spell then W.SpellTip(self, self.spell) end end)
	f:SetScript("OnLeave", W.HideTip)
	f:SetScript("OnClick", function(self) if self.spell then W.SpellClick(self.spell) end end)
	return f
end

local function disponerTalentos(c, w)
	local x, y = SH.pad, 4
	local b, st = estado.build, estado.st
	if not b then
		tal.hArbol:Hide(); tal.lienzo:Hide(); tal.leyenda:Hide(); tal.aviso:Hide(); tal.aplicar:Hide(); tal.abrir:Hide(); tal.hLista:Hide()
		for _, f in ipairs(tal.filas) do f:Hide() end
		return 60
	end
	y = y + ponerSeccion(tal.hArbol, c, x, y, w, format(L["Árbol de %s"], b.titulo or ""), st and format("%d/%d", st.hechos, st.total) or nil)
	y = y + disponerArbol(c, x, y + 4, w) + 10
	y = y + ponerTexto(tal.leyenda, c, x, y, w, L["El número arriba de cada ícono es el orden en que se toma. Borde verde: ya lo tienes. Borde dorado: falta tomarlo (el más grueso es el siguiente). Borde naranja: puntos fuera del plan."]) + 8
	local avisos = {}
	if estado.foto then avisos[#avisos + 1] = L["El juego todavía no cargó tu árbol: se muestra el plan sin tus puntos. Abre la ventana de talentos una vez o espera unos segundos."] end
	if estado.res and #estado.res.faltan > 0 then
		avisos[#avisos + 1] = format(L["Estos talentos no están en tu árbol (quizás cambiaron con un parche) y se saltan: %s."], table.concat(estado.res.faltan, ", "))
	end
	if st and #st.fuera > 0 then
		local nombres = {}
		for _, f in ipairs(st.fuera) do nombres[#nombres + 1] = format("%s (+%d)", f.nombre or "?", f.rangos) end
		avisos[#avisos + 1] = format(L["Tienes puntos fuera del plan en: %s. Alfa no quita talentos: para seguir el build exacto, reinicia tus talentos con tu entrenador de clase."], table.concat(nombres, ", "))
	end
	if #avisos > 0 then
		y = y + ponerTexto(tal.aviso, c, x, y, w, table.concat(avisos, "\n")) + 10
	else
		tal.aviso:Hide()
	end
	poner(tal.aplicar, c, x, y)
	tal.abrir:ClearAllPoints(); tal.abrir:SetPoint("LEFT", tal.aplicar, "RIGHT", 8, 0); tal.abrir:Show()
	y = y + tal.aplicar:GetHeight() + 18
	-- La lista en orden
	y = y + ponerSeccion(tal.hLista, c, x, y, w, L["Qué tomar y en qué orden"], format(L["%d puntos"], b.total))
	local lista = entradas(b, st, estado.res)
	for i, e in ipairs(lista) do
		local f = tal.filas[i] or filaTalento(c)
		tal.filas[i] = f
		f.spell = e.spell
		W.Color(f.Fondo, "panelAlt", i % 2 == 0 and 0.5 or 0)
		f.Icon:SetTexture(e.icono)
		f.Icon:SetDesaturated(e.estado == "falta")
		poner(f.Icon, f, 8, 8)
		f.Nivel:SetText(textoNiveles(e))
		poner(f.Nivel, f, 46, 10)
		f.Nombre:SetText(e.nombreVivo .. "  |c" .. Th.Hex("textMuted") .. textoRango(e) .. "|r")
		f.Nombre:SetWidth(w - 46 - 66 - 140)
		poner(f.Nombre, f, 46 + 66, 9)
		local ch = ESTADO_CHIP[e.estado]
		W.SetChip(f.Estado, ch[1], ch[2])
		f.Estado:ClearAllPoints()
		f.Estado:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
		local ph = 0
		if e.por then
			ph = ponerTexto(f.Por, f, 46 + 66, 28, w - 46 - 66 - 16, e.por) + 4
		else
			f.Por:Hide()
		end
		local fh = max(46, 30 + ph + 6)
		f:SetSize(w, fh)
		poner(f, c, x, y)
		y = y + fh
	end
	for i = #lista + 1, #tal.filas do tal.filas[i]:Hide() end
	return y + 24
end

---------------------------------------------------------------------------
-- Pestaña Equipo
---------------------------------------------------------------------------

local eq = {}

local function construirEquipo(c)
	eq.hPesos = seccion(c)
	eq.pesosTexto = texto(c, "note", "textDim")
	eq.activar = W.Button(c, L["Activar pesos de este build"], function()
		local b = estado.build
		if b then local _, msg = M.Pesos.Activar(b); N.Imprimir(msg) end
		V.Relayout()
	end, { primary = true })
	eq.auto = W.Button(c, L["Volver a automático"], function() M.Pesos.Desactivar(); V.Relayout() end, { ghost = true })
	eq.hMeta = seccion(c)
	eq.metaTexto = texto(c, "note", "textDim")
	eq.buscar = W.Button(c, L["Buscar equipo para mi nivel"], function() V.BuscarEquipo() end, { primary = true, icon = "search" })
	eq.avance = W.ProgressLine(c, 3)
	eq.estado = texto(c, "small", "textMuted")
	eq.grupos, eq.filas = {}, {}
end

function V.BuscarEquipo()
	local b = estado.build
	if not b then return end
	local ok, razon = M.Equipo.Buscar(b, function()
		eq.msg = nil
		V.Relayout()
	end, function(frac)
		eq.frac = frac
		if eq.avance and eq.avance:IsVisible() then W.SetProgress(eq.avance, frac, eq.avance:GetWidth(), false) end
	end)
	if not ok then
		eq.msg = M.Equipo.RAZONES[razon] or tostring(razon)
	else
		eq.msg, eq.frac = nil, 0
	end
	V.Relayout()
end

local function filaObjeto(padre)
	local f = CreateFrame("Button", nil, padre)
	f:SetHeight(44)
	W.Hover(f, 0.5)
	f.Icon = f:CreateTexture(nil, "ARTWORK")
	f.Icon:SetSize(32, 32)
	f.Icon:SetPoint("LEFT", f, "LEFT", 6, 0)
	f.Borde = CreateFrame("Frame", nil, f)
	f.Borde:SetAllPoints(f.Icon)
	f.Nombre = W.Text(f, "body", "text")
	f.Nombre:SetPoint("TOPLEFT", f.Icon, "TOPRIGHT", 10, -1)
	f.Origen = W.Text(f, "small", "textMuted")
	f.Origen:SetPoint("TOPLEFT", f.Nombre, "BOTTOMLEFT", 0, -3)
	f.Mejora = W.Chip(f)
	f.Nivel = W.Chip(f)
	f.Guia = W.Button(f, L["Cómo conseguirlo"], function(self) local p = self:GetParent(); if p.id then M.Equipo.Guiar(p.id) end end, { ghost = true, icon = "icon-goto", height = 26 })
	f.Guia.psTip = L["Abre la guía de Alfa que te lleva a conseguir este objeto (lo mismo que Alt + clic)."]
	f:SetScript("OnEnter", function(self) if self.id then W.ItemTip(self, self.id) end end)
	f:SetScript("OnLeave", W.HideTip)
	f:SetScript("OnClick", function(self) if self.id then W.ItemClick(self.id) end end)
	return f
end

local function disponerEquipo(c, w)
	local x, y = SH.pad, 4
	local b = estado.build
	if not b then return 60 end
	y = y + ponerSeccion(eq.hPesos, c, x, y, w, L["Pesos de estadísticas"])
	local activa = M.Pesos.Activa()
	local G = A.Gear
	local _, label = G and G.GetSpec and G.GetSpec()
	local txt
	if activa == b.id then
		txt = format(L["Las flechas de mejora de Alfa usan ahora los pesos de %s."], b.titulo)
	else
		txt = format(L["Las flechas de mejora usan ahora: %s. Activa los pesos de este build para que Alfa compare el equipo como lo pide %s."], tostring(label or L["automático"]), b.titulo)
	end
	y = y + ponerTexto(eq.pesosTexto, c, x, y, w, txt) + 8
	poner(eq.activar, c, x, y)
	eq.activar:SetShown(activa ~= b.id)
	eq.auto:ClearAllPoints()
	if activa == b.id then eq.auto:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y) else eq.auto:SetPoint("LEFT", eq.activar, "RIGHT", 8, 0) end
	eq.auto:Show()
	y = y + eq.activar:GetHeight() + 18

	y = y + ponerSeccion(eq.hMeta, c, x, y, w, L["Equipo meta para tu nivel"])
	y = y + ponerTexto(eq.metaTexto, c, x, y, w, L["Alfa busca en su base de objetos lo mejor que tu clase puede usar cerca de tu nivel, puntuado con los pesos de este build, y lo compara con lo que llevas puesto. Pasa el ratón por un objeto para verlo; Mayús + clic lo enlaza en el chat."]) + 10
	local ocupado, frac = M.Equipo.Ocupado()
	poner(eq.buscar, c, x, y)
	eq.buscar:SetEnabled(not ocupado)
	W.SetButtonText(eq.buscar, ocupado and L["Buscando..."] or L["Buscar equipo para mi nivel"])
	y = y + eq.buscar:GetHeight() + 8
	if ocupado then
		eq.avance:SetWidth(w)
		poner(eq.avance, c, x, y)
		W.SetProgress(eq.avance, frac or 0, w, false)
		y = y + 10
	else
		eq.avance:Hide()
	end
	if eq.msg then
		y = y + ponerTexto(eq.estado, c, x, y, w, eq.msg) + 8
	else
		eq.estado:Hide()
	end
	local res = M.Equipo.Resultado(b)
	for _, h in ipairs(eq.grupos) do h:Hide() end
	for _, f in ipairs(eq.filas) do f:Hide() end
	if not res then
		if not ocupado and not eq.msg then
			y = y + ponerTexto(eq.estado, c, x, y, w, L["Pulsa el botón para buscar. Tarda unos segundos la primera vez."]) + 8
		end
		return y + 24
	end
	if res.viejo then M.Equipo.Mejoras(res, M.Pesos.Pesos(b)) end
	local nf = 0
	for gi, g in ipairs(res.grupos) do
		local h = eq.grupos[gi] or seccion(c)
		eq.grupos[gi] = h
		y = y + ponerSeccion(h, c, x, y, w, g.nombre)
		for _, it in ipairs(g.items) do
			nf = nf + 1
			local f = eq.filas[nf] or filaObjeto(c)
			eq.filas[nf] = f
			f.id = it.id
			f.Icon:SetTexture(A.Compat.ItemIcon(it.id))
			local hex = A.Compat.ItemQualityHex(it.calidad)
			f.Nombre:SetText(hex and ("|c" .. hex .. M.Equipo.Nombre(it.id) .. "|r") or M.Equipo.Nombre(it.id))
			f.Nombre:SetWidth(w - 50 - 300)
			f.Origen:SetText(M.Equipo.Origen(it.id) or "")
			f.Origen:SetWidth(w - 50 - 300)
			if hex then
				local r, g2, bl = tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
				Th.Border(f.Borde, r, g2, bl, 1)
			end
			f.Guia:ClearAllPoints()
			f.Guia:SetPoint("RIGHT", f, "RIGHT", -4, 0)
			if it.vacio then
				W.SetChip(f.Mejora, L["Ranura vacía"], "success")
			elseif it.mejora and it.mejora > 0.5 then
				W.SetChip(f.Mejora, format("+%d%%", floor(it.mejora + 0.5)), "success")
			elseif it.mejora and it.mejora >= -0.5 then
				W.SetChip(f.Mejora, L["Igual que lo tuyo"], "neutral")
			else
				W.SetChip(f.Mejora, L["Ya tienes algo mejor"], "neutral")
			end
			f.Mejora:ClearAllPoints()
			f.Mejora:SetPoint("RIGHT", f.Guia, "LEFT", -8, 0)
			local nivel = A.Compat.Readable(UnitLevel("player")) or 1
			if (it.req or 0) > nivel then
				W.SetChip(f.Nivel, format(L["Nv %d"], it.req), "warning")
			else
				W.SetChip(f.Nivel, format(L["Nv %d"], max(1, it.req or 1)), "neutral")
			end
			f.Nivel:ClearAllPoints()
			f.Nivel:SetPoint("RIGHT", f.Mejora, "LEFT", -6, 0)
			f:SetWidth(w)
			poner(f, c, x, y)
			y = y + 46
		end
		y = y + 8
	end
	return y + 24
end

---------------------------------------------------------------------------
-- Pestaña Combate
---------------------------------------------------------------------------

local cmb = {}

local function construirCombate(c)
	local P = "builds."
	cmb.intro = texto(c, "note", "textDim")
	local function grupo(titulo, filas)
		return { h = seccion(c), titulo = titulo, panel = W.RowPanel(c), filas = filas }
	end
	-- Fila de interruptor; con `padre`, depende de ese ajuste (sangría y atenuada).
	local function t(clave, label, desc, padre)
		local r = W.Toggle(c, label, P .. clave, desc, padre and (P .. padre) or nil)
		W.RowDetails(r, { inset = padre and 40 or 16, child = padre and true or nil })
		return r
	end
	local function s(clave, label, lo, hi, paso, fmt, desc, padre)
		local r = W.Slider(c, label, P .. clave, lo, hi, paso, fmt, desc, padre and (P .. padre) or nil)
		W.RowDetails(r, { inset = padre and 40 or 16, child = padre and true or nil })
		return r
	end
	cmb.grupos = {
		grupo(L["Sugerencia de Blizzard"], {
			t("sugerencia", L["Mostrar la sugerencia"], L["Un ícono con el siguiente hechizo que recomienda la ayuda de combate oficial de Blizzard. Es solo una ayuda: tú decides qué apretar."]),
			t("sugerenciaFuera", L["También fuera de combate"], L["Se ve cuando tienes un enemigo seleccionado, antes de empezar la pelea."], "sugerencia"),
			t("sugerenciaNombre", L["Nombre del hechizo"], L["Escribe el nombre debajo del ícono: útil mientras aprendes."], "sugerencia"),
			t("resaltado", L["Marcar el botón en tu barra"], L["Un borde en el botón de tu barra que tiene la sugerencia, para que lo encuentres rápido."], "sugerencia"),
			s("tamSugerencia", L["Tamaño del ícono"], 32, 96, 4, "%d px", L["Qué tan grande se ve el ícono de la sugerencia."], "sugerencia"),
		}),
		grupo(L["Alertas de reacción"], {
			t("alertas", L["Avisar habilidades de reacción"], L["Un aviso grande cuando una habilidad que depende de lo que pasó se activa (por ejemplo, Abrumar después de que el enemigo esquive)."]),
			t("alertasSonido", L["Con sonido"], L["Suena un aviso corto además del texto."], "alertas"),
			t("alertasPorque", L["Explicar por qué"], L["Una línea debajo del aviso que dice por qué se activó."], "alertas"),
		}),
		grupo(L["Temporizador de golpe"], {
			t("golpe", L["Mostrar el temporizador de golpe"], L["Barras que muestran cuánto falta para tu siguiente golpe automático, con cada mano. Ayuda a usar Embate o Golpe heroico sin perder golpes."]),
		}),
		grupo(L["Panel de estadísticas"], {
			t("panel", L["Mostrar el panel"], L["Un cuadro pequeño con tu vida y las estadísticas más importantes de tu build. En combate el juego oculta algunos números: se queda el último que se pudo leer."]),
		}),
		grupo(L["Recordatorios"], {
			t("aviso", L["Avisar al subir de nivel"], L["Al recibir un punto de talento, una línea en el chat dice qué talento toca según tu build."]),
			t("escalaAuto", L["Activar los pesos al elegir un build"], L["Al elegir un build, las flechas de mejora usan sus pesos sin que tengas que hacer nada."]),
		}),
	}
	cmb.hMarcos = seccion(c)
	cmb.mover = W.Button(c, L["Mover marcos"], function()
		M.Combate.Desbloquear(not M.Combate.Desbloqueado())
		V.Relayout()
	end, { primary = true, icon = "resize" })
	cmb.probar = W.Button(c, L["Probar alerta"], function() M.Combate.ProbarAlerta() end, { ghost = true })
	cmb.reiniciar = W.Button(c, L["Restablecer posiciones"], function() M.Combate.ReiniciarPosiciones() end, { ghost = true, icon = "reset" })
	cmb.estado = texto(c, "small", "textMuted")
	cmb.hReac = seccion(c)
	cmb.reac = {}
end

local function disponerCombate(c, w)
	local x, y = SH.pad, 4
	y = y + ponerTexto(cmb.intro, c, x, y + 4, w, L["Ayudas que solo muestran información: nunca aprietan nada por ti. La sugerencia es la oficial de Blizzard, y las alertas leen solo datos de tu personaje."]) + 16
	for _, g in ipairs(cmb.grupos) do
		y = y + ponerSeccion(g.h, c, x, y, w, g.titulo)
		local py = y
		for i, r in ipairs(g.filas) do
			poner(r, c, x, y)
			if rawget(r, "Refresh") then r:Refresh() end
			y = y + W.LayoutRow(r, w)
			local regla = rawget(r, "Rule")
			if regla then regla:SetShown(i < #g.filas) end
		end
		g.panel:ClearAllPoints()
		g.panel:SetPoint("TOPLEFT", c, "TOPLEFT", x, -py)
		g.panel:SetSize(w, max(1, y - py))
		g.panel:SetShown(Th.SkinKey and Th.SkinKey() == "alfa" or false)
		y = y + 14
	end
	-- Estado de la ayuda de Blizzard
	local disp, porque = M.Combate.SugerenciaDisponible()
	local lineas = {}
	lineas[#lineas + 1] = disp and L["La ayuda de combate de Blizzard está disponible."] or format(L["La ayuda de combate de Blizzard no está disponible ahora: %s"], porque or L["sin motivo"])
	lineas[#lineas + 1] = M.Combate.ResaltadoOficial() and L["Tu cliente trae el resaltado oficial de botones; Alfa lo deja en manos del juego."]
		or L["Tu cliente no trae el resaltado oficial de botones: Alfa marca el botón con un borde."]
	-- Reacciones de tu clase
	y = y + ponerSeccion(cmb.hReac, c, x, y, w, L["Habilidades de reacción de tu clase"])
	local reac = M.Combate.Reacciones()
	local dc = M.DatosClase()
	local defs = dc and dc.reacciones or {}
	for _, r in ipairs(cmb.reac) do r.Icon:Hide(); r.Texto:Hide() end
	if #defs == 0 then
		local r = cmb.reac[1]
		if not r then r = { Icon = c:CreateTexture(nil, "ARTWORK"), Texto = texto(c, "note", "textDim") }; cmb.reac[1] = r end
		y = y + ponerTexto(r.Texto, c, x, y, w, L["Tu clase no tiene habilidades de reacción que Alfa vigile."]) + 10
	else
		for i, def in ipairs(defs) do
			local r = cmb.reac[i]
			if not r then
				r = { Icon = c:CreateTexture(nil, "ARTWORK"), Texto = texto(c, "note", "textDim") }
				r.Icon:SetSize(24, 24)
				r.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
				cmb.reac[i] = r
			end
			local conocida = false
			for _, k in ipairs(reac) do if k.def == def then conocida = true end end
			r.Icon:SetTexture(A.Compat.SpellIcon(def.ids[1]))
			r.Icon:SetDesaturated(not conocida)
			poner(r.Icon, c, x, y)
			local t = "|c" .. Th.Hex(conocida and "text" or "textMuted") .. def.texto .. "|r  " .. def.porque
			if not conocida then t = t .. "  " .. L["(todavía no la aprendes)"] end
			local h = ponerTexto(r.Texto, c, x + 34, y + 2, w - 34, t)
			y = y + max(30, h + 10)
		end
	end
	y = y + 8
	-- Marcos
	y = y + ponerSeccion(cmb.hMarcos, c, x, y, w, L["Marcos en pantalla"])
	W.SetButtonText(cmb.mover, M.Combate.Desbloqueado() and L["Listo, fijar marcos"] or L["Mover marcos"])
	poner(cmb.mover, c, x, y)
	cmb.probar:ClearAllPoints(); cmb.probar:SetPoint("LEFT", cmb.mover, "RIGHT", 8, 0); cmb.probar:Show()
	cmb.reiniciar:ClearAllPoints(); cmb.reiniciar:SetPoint("LEFT", cmb.probar, "RIGHT", 8, 0); cmb.reiniciar:Show()
	y = y + cmb.mover:GetHeight() + 10
	y = y + ponerTexto(cmb.estado, c, x, y, w, table.concat(lineas, "\n")) + 16
	return y + 16
end

---------------------------------------------------------------------------
-- Pestaña Compartir
---------------------------------------------------------------------------

local cmp = {}

local function campoTexto(padre, lineas)
	local well = CreateFrame("Frame", nil, padre)
	Th.Skin(well, "editbox")
	local e = CreateFrame("EditBox", nil, well)
	e:SetMultiLine(true)
	e:SetAutoFocus(false)
	e:SetPoint("TOPLEFT", well, "TOPLEFT", 8, -8)
	e:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -8, 8)
	e:SetMaxLetters(2000)
	Th.Font(e, "label")
	W.Color(e, "text")
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEditFocusGained", function() Th.SetFocused(well, true) end)
	e:SetScript("OnEditFocusLost", function() Th.SetFocused(well, false) end)
	well:EnableMouse(true)
	well:SetScript("OnMouseDown", function() e:SetFocus() end)
	well.Edit = e
	well:SetHeight(lineas * 16 + 18)
	return well
end

local function construirCompartir(c)
	cmp.hExp = seccion(c)
	cmp.expTexto = texto(c, "note", "textDim")
	cmp.caja = W.CopyBox(c, { lines = 3 })
	cmp.copiar = W.Button(c, L["Seleccionar para copiar"], function() W.SelectCopy(cmp.caja) end, { ghost = true })
	cmp.actual = W.Button(c, L["Usar mis talentos de ahora"], function()
		local s, razon = M.Compartir.ExportarActual()
		cmp.exportando = s
		cmp.expMsg = not s and (razon == "vacio" and L["Todavía no tienes talentos para exportar."] or L["El juego todavía no cargó tu árbol."]) or nil
		V.Relayout()
	end, { ghost = true })
	cmp.hImp = seccion(c)
	cmp.impTexto = texto(c, "note", "textDim")
	cmp.entrada = campoTexto(c, 3)
	cmp.importar = W.Button(c, L["Importar"], function()
		local b, err = M.Compartir.Importar(cmp.entrada.Edit:GetText())
		if b then
			cmp.impMsg = format(L["Importado: %s. Ya puedes elegirlo abajo."], b.titulo)
			cmp.entrada.Edit:SetText("")
		else
			cmp.impMsg = M.Compartir.ERRORES[err] or tostring(err)
		end
		V.Relayout()
	end, { primary = true })
	cmp.impEstado = texto(c, "small", "accent")
	cmp.hLista = seccion(c)
	cmp.filas = {}
	cmp.vacio = texto(c, "small", "textMuted")
end

local function disponerCompartir(c, w)
	local x, y = SH.pad, 4
	local b = estado.build
	y = y + ponerSeccion(cmp.hExp, c, x, y, w, L["Compartir un build"])
	y = y + ponerTexto(cmp.expTexto, c, x, y, w, L["Copia esta cadena y pásala a un amigo de la manada: con Alfa la pega en Importar y tiene el mismo build. Ctrl + C para copiar."]) + 8
	local s = cmp.exportando or (b and M.Compartir.Exportar(b)) or ""
	cmp.caja:SetWidth(w)
	W.SetCopyText(cmp.caja, s)
	poner(cmp.caja, c, x, y)
	y = y + cmp.caja:GetHeight() + 8
	poner(cmp.copiar, c, x, y)
	cmp.actual:ClearAllPoints(); cmp.actual:SetPoint("LEFT", cmp.copiar, "RIGHT", 8, 0); cmp.actual:Show()
	y = y + cmp.copiar:GetHeight() + 8
	if cmp.expMsg then
		y = y + ponerTexto(cmp.impEstado, c, x, y, w, cmp.expMsg) + 8
	end
	y = y + 10
	y = y + ponerSeccion(cmp.hImp, c, x, y, w, L["Importar un build"])
	y = y + ponerTexto(cmp.impTexto, c, x, y, w, L["Pega aquí una cadena que empiece con ALFA1; (Ctrl + V) y pulsa Importar. Alfa revisa cada talento contra tu árbol."]) + 8
	cmp.entrada:SetWidth(w)
	poner(cmp.entrada, c, x, y)
	y = y + cmp.entrada:GetHeight() + 8
	poner(cmp.importar, c, x, y)
	y = y + cmp.importar:GetHeight() + 8
	if cmp.impMsg and not cmp.expMsg then
		y = y + ponerTexto(cmp.impEstado, c, x, y, w, cmp.impMsg) + 8
	elseif not cmp.expMsg then
		cmp.impEstado:Hide()
	end
	y = y + 10
	local lista = M.Compartir.Lista()
	y = y + ponerSeccion(cmp.hLista, c, x, y, w, L["Tus builds importados"], tostring(#lista))
	for _, f in ipairs(cmp.filas) do f:Hide() end
	if #lista == 0 then
		y = y + ponerTexto(cmp.vacio, c, x, y, w, L["Todavía no importaste ninguno."]) + 10
	else
		cmp.vacio:Hide()
		for i, ib in ipairs(lista) do
			local f = cmp.filas[i]
			if not f then
				f = CreateFrame("Frame", nil, c)
				f:SetHeight(34)
				f.Nombre = W.Text(f, "body", "text")
				f.Nombre:SetPoint("LEFT", f, "LEFT", 0, 0)
				f.Usar = W.Button(f, L["Usar"], function(self) M.UsarBuild(self:GetParent().id); V.IrA("asistente") end, { primary = true, height = 26 })
				f.Borrar = W.Button(f, L["Borrar"], function(self)
					local id = self:GetParent().id
					W.Modal({ title = L["¿Borrar este build?"], icon = "reset", danger = true, action = L["Borrar"],
						text = L["Se quita de tu lista. Si lo necesitas otra vez, vuelve a importar su cadena."],
						onAccept = function() M.Compartir.Borrar(id); V.Relayout() end })
				end, { ghost = true, danger = true, height = 26 })
				f.Usar:SetPoint("RIGHT", f.Borrar, "LEFT", -8, 0)
				f.Borrar:SetPoint("RIGHT", f, "RIGHT", 0, 0)
				cmp.filas[i] = f
			end
			f.id = ib.id
			f.Nombre:SetText(format("%s  |c%s%s|r", ib.titulo, Th.Hex("textMuted"), M.NombreSpec(ib)))
			f.Nombre:SetWidth(w - 200)
			f:SetWidth(w)
			poner(f, c, x, y)
			y = y + 36
		end
	end
	return y + 24
end

---------------------------------------------------------------------------
-- La vista
---------------------------------------------------------------------------

local PESTANAS = {
	asistente = { construirAsistente, disponerAsistente },
	talentos = { construirTalentos, disponerTalentos },
	equipo = { construirEquipo, disponerEquipo },
	combate = { construirCombate, disponerCombate },
	compartir = { construirCompartir, disponerCompartir },
}

function V.Construir(view)
	V.view = view
	view.Cabecera = construirCabecera(view)
	view.Tabs = construirTabs(view)
	view.Conts = {}
	view.Refresh = function()
		local w = ancho()
		leerEstado()
		local y = 10
		poner(view.Cabecera, view, SH.pad, y)
		y = y + disponerCabecera(view.Cabecera, w) + 8
		poner(view.Tabs, view, SH.pad, y)
		y = y + disponerTabs(view.Tabs, w) + 12
		local actual = tabActual()
		if not PESTANAS[actual] then actual = "asistente" end
		for clave, cont in pairs(view.Conts) do cont:SetShown(clave == actual) end
		local cont = view.Conts[actual]
		if not cont then
			cont = CreateFrame("Frame", nil, view)
			view.Conts[actual] = cont
			PESTANAS[actual][1](cont)
		end
		cont:ClearAllPoints()
		cont:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -y)
		cont:SetWidth(w + 2 * SH.pad)
		local h = PESTANAS[actual][2](cont, w)
		cont:SetHeight(h)
		cont:Show()
		return y + h
	end
end

-- Vuelve a acomodar la página donde está (o arriba, si cambió de pestaña).
local pedido, arriba = false, false
function V.Relayout(subir)
	arriba = arriba or subir
	if pedido then return end
	pedido = true
	A.After(0, function()
		pedido = false
		local view = V.view
		if not (view and view.Refresh and view:IsVisible()) then arriba = false return end
		local h = view.Refresh()
		view:SetHeight(h)
		local win = ventana()
		if win then
			W.ShellBody(win, h)
			if arriba and win.Scroll then W.ScrollTo(win.Scroll, 0) end
		end
		arriba = false
	end)
end
