-- Alfa - Pesca: su página en la ventana de Alfa (Toxic / La Jauría). GPL-3.0.
--
-- Arriba, una tarjeta con el estado (listo, pescando, sin caña, en pausa...),
-- cómo pescar con tu tecla y tu habilidad de pesca. Debajo, las secciones de
-- ajustes en el mismo estilo que el resto de las páginas (filas con su
-- descripción sobre un panel) y el registro de lo pescado en la sesión.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local W, T = A.Widgets, A.Theme
local L = M.L
local ID = M.ID

local floor, max, min, ceil, format = math.floor, math.max, math.min, math.ceil, string.format

local DOT = "  \194\183  "
local INSET, HIJO, GAP = 16, 40, 22
local FILA_OBJETO, MAX_OBJETOS = 34, 40
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

local function pct(v) return floor((tonumber(v) or 0) * 100 + 0.5) .. "%" end
local function segundos(v) return format(L["%.2f s"], tonumber(v) or 0) end

local function teclaTexto()
	local t = M.Teclas()
	return t[1] and M.TextoTecla(t[1]) or nil
end

---------------------------------------------------------------------------
-- La tarjeta de estado
---------------------------------------------------------------------------

-- -> título, texto, chip, tipo de chip
local function estado()
	local tecla = teclaTexto()
	local clic = M.Opt("dobleClic")
	if M.E.otro then
		return L["Otro addon de pesca está activo"],
			L["Para que no choquen, Alfa no toma tu tecla ni cambia tus ajustes. Desactiva uno de los dos en la lista de addons (pantalla de personajes) y recarga. Si dejas Alfa, tomará sola la tecla que usabas en el otro addon."],
			L["En pausa"], "warning"
	end
	if not M.Opt("activo") then
		return L["La pesca de Alfa está apagada"], L["Tu tecla y tus ajustes del juego quedan como siempre. Enciéndela abajo para pescar con una sola tecla."], L["Apagada"], nil
	end
	if M.SabePesca() == false then
		return L["Todavía no sabes pescar"], L["Aprende Pesca con un instructor de pesca (hay en las capitales) y compra una caña. Luego vuelve aquí."], L["Aprende Pesca"], "warning"
	end
	if M.Pescando() then
		local texto = tecla and format(L["El corcho está en el agua. Cuando se hunda, pulsa %s para recoger."], tecla)
			or L["El corcho está en el agua. Cuando se hunda, haz clic derecho sobre él para recoger."]
		return L["Pescando…"], texto, L["Pescando"], "accent"
	end
	if not M.TieneCana() then
		return L["Equipa tu caña de pescar"], L["Para pescar necesitas una caña en las manos. Cuando la tengas puesta, ya puedes lanzar."], L["Sin caña"], "warning"
	end
	if not tecla and not clic then
		return L["Elige tu tecla para pescar"], L["Asígnala abajo, en Tecla para pescar: con ella lanzas la caña y, cuando pica, recoges el pez."], L["Sin tecla"], "warning"
	end
	local texto
	if tecla then
		texto = format(L["Pulsa %s para lanzar. Cuando el corcho se hunda, pulsa %s otra vez para recoger."], tecla, tecla)
		if clic then texto = texto .. " " .. L["También puedes lanzar con doble clic derecho."] end
	else
		texto = L["Haz doble clic derecho en el mundo para lanzar. Cuando pique, haz clic derecho sobre el corcho para recoger."]
	end
	return L["Listo para pescar"], texto, L["Listo"], "success"
end

local function chipsDeEstado()
	local t = {}
	local tecla = teclaTexto()
	t[#t + 1] = tecla and { format(L["Tecla: %s"], tecla), "accent" } or { L["Sin tecla"] }
	if M.TieneCana() then t[#t + 1] = { L["Caña equipada"], "success" } else t[#t + 1] = { L["Sin caña"], "warning" } end
	if M.Opt("dobleClic") then t[#t + 1] = { L["Doble clic"] } end
	return t
end

local function crearTarjeta(view)
	local c = CreateFrame("Frame", nil, view)
	-- El panel va detrás (hijo de la vista, a su nivel), como el de las filas.
	c.Fondo = W.RowPanel(view)
	c.Fondo:SetAllPoints(c)
	c.Disco = W.Tex(c, "ARTWORK", "circle")
	c.Disco:SetSize(44, 44)
	c.Disco:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -16)
	W.Painter(c.Disco, function(t)
		local r, g, b = T.Accent()
		t:SetVertexColor(r, g, b, 0.16)
	end)
	c.Icono = W.Tex(c, "OVERLAY", "icon-interact", "accent")
	c.Icono:SetSize(22, 22)
	c.Icono:SetPoint("CENTER", c.Disco, "CENTER", 0, 0)
	c.Titulo = W.Text(c, "title", "text")
	c.Titulo:SetPoint("TOPLEFT", c, "TOPLEFT", 76, -18)
	c.Estado = W.Chip(c)
	c.Estado:SetPoint("LEFT", c.Titulo, "RIGHT", 10, 0)
	c.Texto = W.Text(c, "note", "textDim")
	c.Texto:SetWordWrap(true)
	c.Texto:SetSpacing(2)
	c.Texto:SetJustifyV("TOP")
	c.Chips = { W.Chip(c), W.Chip(c), W.Chip(c) }
	c.Linea = W.Divider(c)
	c.HabNombre = W.Text(c, "small", "textMuted")
	c.HabValor = W.Text(c, "number", "text")
	c.HabValor:SetJustifyH("RIGHT")
	c.Barra = W.ProgressLine(c, 4)
	c.HabNota = W.Text(c, "small", "textMuted")
	c.HabNota:SetWordWrap(true)
	c.HabNota:SetJustifyV("TOP")
	return c
end

-- -> alto de la tarjeta
local function ordenarTarjeta(c, width)
	c:SetWidth(width)
	c.Fondo:SetShown(enCasa())
	local titulo, texto, chip, tipo = estado()
	local cw = W.SetChip(c.Estado, chip, tipo)
	c.Titulo:SetWidth(0)
	c.Titulo:SetText(titulo)
	c.Titulo:SetWidth(max(40, min(ceil(W.TextWidth(c.Titulo)) + 2, width - 76 - 16 - cw - 10)))
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
	y = max(y + W.CHIP_H + 16, 16 + 44 + 16)

	c.Linea:ClearAllPoints()
	c.Linea:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -y)
	c.Linea:SetPoint("TOPRIGHT", c, "TOPRIGHT", -16, -y)
	y = y + 14

	-- La habilidad de pesca, su barra y lo que subiste.
	c.HabNombre:SetText(L["Habilidad de pesca"])
	c.HabNombre:ClearAllPoints()
	c.HabNombre:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -y)
	c.HabValor:ClearAllPoints()
	c.HabValor:SetPoint("TOPRIGHT", c, "TOPRIGHT", -16, -y)
	y = y + 20
	local barraW = width - 32
	c.Barra:ClearAllPoints()
	c.Barra:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -y)
	c.Barra:SetWidth(barraW)
	local rango, maximo, bono = M.Habilidad()
	local nota
	if rango then
		c.HabValor:SetText(maximo > 0 and format("%d / %d", rango, maximo) or tostring(rango))
		W.SetProgress(c.Barra, maximo > 0 and rango / maximo or 0, barraW)
		local partes = {}
		local inicial = tonumber(M.Sesion().rangoInicial)
		if inicial and rango > inicial then partes[#partes + 1] = format(L["+%d en esta sesión"], rango - inicial) end
		if bono > 0 then partes[#partes + 1] = format(L["+%d por cebo o equipo"], bono) end
		if maximo >= 300 and rango >= maximo then
			partes[#partes + 1] = L["Tu pesca está al máximo."]
		elseif maximo > 0 and rango >= maximo then
			partes[#partes + 1] = L["Llegaste al máximo de tu rango: aprende el siguiente con un instructor de pesca."]
		end
		nota = table.concat(partes, DOT)
	else
		c.HabValor:SetText("\226\128\147")
		W.SetProgress(c.Barra, 0, barraW)
		nota = L["Aprende Pesca con un instructor de pesca para empezar a subirla."]
	end
	y = y + 4 + 8
	c.HabNota:SetWidth(barraW)
	c.HabNota:SetText(nota)
	c.HabNota:ClearAllPoints()
	c.HabNota:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -y)
	c.HabNota:SetShown(nota ~= "")
	if nota ~= "" then y = y + ceil(c.HabNota:GetStringHeight()) end
	y = y + 16
	c:SetHeight(y)
	return y
end

---------------------------------------------------------------------------
-- Las filas de ajustes (como las del resto de las páginas)
---------------------------------------------------------------------------

local function fila(w, hijo)
	W.RowDetails(w, { inset = hijo and HIJO or INSET, child = hijo })
	return w
end

-- Atenuada con la pesca apagada y, si es hija, con su opción de arriba apagada.
local function condicion(w, padre)
	W.SetDisabledWhen(w, function()
		if not M.Opt("activo") then return true end
		return padre ~= nil and not M.Opt(padre)
	end)
	return w
end

-- La fila de la tecla: la del motor (la misma de la página Mando), que espera
-- una tecla al hacer clic y avisa si otra acción la usa.
local function filaTecla(view)
	local etiqueta = L["Tecla para pescar"]
	local ayuda = L["Haz clic aquí y pulsa la tecla que quieras (Esc cancela; clic derecho la quita). Con ella lanzas la caña y, cuando pica, recoges el pez. También está en el menú de atajos del juego, en Alfa."]
	local G = A.Gamepad
	if G and G.BindingRow then
		local ok, w = pcall(G.BindingRow, view, { kind = "binding", action = M.ACCION, label = etiqueta, help = ayuda })
		if ok and w then return fila(w) end
	end
	local w = W.InfoRow(view, etiqueta, L["Asígnala en el menú del juego: Opciones, Atajos de teclado, Alfa, Pescar: lanzar y recoger."])
	w.Refresh = function(self) self.Value:SetText(teclaTexto() or L["Sin tecla"]) end
	w:Refresh()
	return fila(w)
end

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

local function grupos(view)
	local p = ID .. "."
	return {
		{ titulo = L["Encendido y tecla"], filas = {
			fila(W.Toggle(view, L["Usar la pesca de Alfa"], p .. "activo",
				L["Apágalo si no quieres que Alfa toque tu tecla ni tus ajustes al pescar."])),
			filaTecla(view),
		} },
		{ titulo = L["Mientras pescas"], filas = {
			fila(condicion(W.Toggle(view, L["Recoger todo lo que pesques"], p .. "autobotin",
				L["Toma el botín de la pesca enseguida, aunque tengas apagado el botín automático del juego."]))),
			fila(condicion(W.Toggle(view, L["Subir el sonido al pescar"], p .. "sonido",
				L["Apaga la música y el ambiente y sube los efectos para que oigas cuando pica, aunque el juego esté en segundo plano. Al terminar, todo vuelve a como estaba."]))),
			fila(condicion(W.Slider(view, L["Volumen mientras pescas"], p .. "volumen", 0, 1, 0.05, pct,
				L["Qué tan fuerte se oye el juego mientras el corcho está en el agua."]), "sonido"), true),
			fila(condicion(W.Toggle(view, L["Ocultar nombres al pescar"], p .. "ocultarNombres",
				L["Esconde las placas y los nombres de los PNJ mientras pescas (los enemigos hostiles conservan su nombre), para ver y tocar mejor el corcho."]))),
			fila(condicion(W.Toggle(view, L["Ícono sobre el corcho"], p .. "iconoCorcho",
				L["Muestra un ícono encima del corcho: así sabes que tu tecla lo va a recoger."]))),
		} },
		{ titulo = L["Doble clic derecho"], filas = {
			fila(condicion(W.Toggle(view, L["Doble clic derecho para lanzar"], p .. "dobleClic",
				L["Haz doble clic derecho en el mundo para lanzar la caña, sin usar la tecla. Nunca en combate ni en vuelo."]))),
			fila(condicion(W.Slider(view, L["Rapidez del doble clic"], p .. "velocidad", 0.1, 0.8, 0.05, segundos,
				L["Tiempo máximo entre los dos clics. Súbelo si tus dobles clics no lanzan."]), "dobleClic"), true),
			fila(condicion(W.Toggle(view, L["También en montura"], p .. "montado",
				L["Permite lanzar con doble clic aunque vayas montado."]), "dobleClic"), true),
			fila(condicion(W.Toggle(view, L["Doble clic mientras pescas vuelve a lanzar"], p .. "relanzar",
				L["Encendido: el doble clic mientras pescas lanza de nuevo y, con Mayús, Ctrl o Alt, recoge. Apagado: al revés."]), "dobleClic"), true),
		} },
	}
end

---------------------------------------------------------------------------
-- El registro de la sesión
---------------------------------------------------------------------------

local function colorCalidad(q)
	if type(q) ~= "number" then return nil end
	local r, g, b
	if C_Item and C_Item.GetItemQualityColor then
		local ok, cr, cg, cb = pcall(C_Item.GetItemQualityColor, q)
		if ok and type(cr) == "number" then r, g, b = cr, cg, cb end
	end
	if not r and type(ITEM_QUALITY_COLORS) == "table" and type(ITEM_QUALITY_COLORS[q]) == "table" then
		local t = ITEM_QUALITY_COLORS[q]
		r, g, b = t.r, t.g, t.b
	end
	if type(r) ~= "number" then return nil end
	return T.Legible(r, g, b)
end

local function iconoDe(o)
	if o.icono then return o.icono end
	if type(o.id) == "number" and C_Item and C_Item.GetItemIconByID then
		local ok, icono = pcall(C_Item.GetItemIconByID, o.id)
		if ok and icono then return icono end
	end
	return ICONO_VACIO
end

local function filaObjeto(view, ui, i)
	local r = ui.objetos[i]
	if r then return r end
	r = CreateFrame("Button", nil, view)
	r:SetHeight(FILA_OBJETO)
	W.Hover(r, 0.6)
	r.Icono = r:CreateTexture(nil, "ARTWORK")
	r.Icono:SetSize(24, 24)
	r.Icono:SetPoint("LEFT", r, "LEFT", INSET, 0)
	r.Cantidad = W.Text(r, "number", "textDim")
	r.Cantidad:SetJustifyH("RIGHT")
	r.Cantidad:SetPoint("RIGHT", r, "RIGHT", -INSET, 0)
	r.Nombre = W.Text(r, "label", "item")
	r.Nombre:SetPoint("LEFT", r.Icono, "RIGHT", 10, 0)
	r.Nombre:SetPoint("RIGHT", r.Cantidad, "LEFT", -10, 0)
	r.Linea = W.Divider(r, false, 0.6)
	r.Linea:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
	r.Linea:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
	r:SetScript("OnEnter", function(self) if self.psID then W.ItemTip(self, self.psID) end end)
	r:SetScript("OnLeave", function(self) W.HideTooltip(self) end)
	-- Mayús-clic lo enlaza en el chat, como en tus bolsas.
	r:SetScript("OnClick", function(self) if self.psID then W.ItemClick(self.psID) end end)
	ui.objetos[i] = r
	return r
end

local function pintarObjeto(r, o)
	r.psID = type(o.id) == "number" and o.id or nil
	r.Icono:SetTexture(iconoDe(o))
	r.Nombre:SetText(o.nombre or "?")
	local cr, cg, cb = colorCalidad(o.calidad)
	if cr then
		W.Uncolor(r.Nombre)
		r.Nombre:SetTextColor(cr, cg, cb, 1)
	else
		W.Color(r.Nombre, "item")
	end
	r.Cantidad:SetText(format("\195\151%d", o.cantidad or 0))
end

local function resumen(s)
	local partes = { format(s.capturas == 1 and L["%d captura"] or L["%d capturas"], s.capturas) }
	local seg = s.segundos + (M.E.canal and max(0, GetTime() - M.E.canal) or 0)
	if seg >= 1 then partes[#partes + 1] = format(L["%s con la caña en el agua"], N.Duracion(seg)) end
	if s.inicio then partes[#partes + 1] = format(L["desde las %s"], date("%H:%M", s.inicio)) end
	return table.concat(partes, DOT)
end

local function ordenarRegistro(view, ui, y, width, x)
	local s = M.Sesion()
	W.SetSection(ui.regEnc, L["Lo pescado en esta sesión"], s.total > 0 and tostring(s.total) or nil)
	ui.regEnc:ClearAllPoints()
	ui.regEnc:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
	ui.regEnc:SetWidth(width)
	y = y + W.PLAIN_SECTION_H

	ui.regResumen:SetWidth(width)
	ui.regResumen:SetText(resumen(s))
	ui.regResumen:ClearAllPoints()
	ui.regResumen:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
	y = y + ceil(ui.regResumen:GetStringHeight()) + 10

	local lista = M.Objetos()
	local n = min(#lista, MAX_OBJETOS)
	local top = y
	if n == 0 then
		ui.regVacio:SetWidth(width - 2 * INSET)
		ui.regVacio:SetText(L["Todavía no has pescado nada en esta sesión. Lo que saques aparece aquí, con cuántos llevas de cada uno."])
		ui.regVacio:ClearAllPoints()
		ui.regVacio:SetPoint("TOPLEFT", view, "TOPLEFT", x + INSET, -(y + 14))
		ui.regVacio:Show()
		y = y + 14 + ceil(ui.regVacio:GetStringHeight()) + 14
	else
		ui.regVacio:Hide()
		for i = 1, n do
			local r = filaObjeto(view, ui, i)
			pintarObjeto(r, lista[i])
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
			r:SetWidth(width)
			r.Linea:SetShown(i < n)
			r:Show()
			y = y + FILA_OBJETO
		end
	end
	for i = n + 1, #ui.objetos do ui.objetos[i]:Hide() end
	ui.regPanel:ClearAllPoints()
	ui.regPanel:SetPoint("TOPLEFT", view, "TOPLEFT", x, -top)
	ui.regPanel:SetSize(width, max(1, y - top))
	ui.regPanel:SetShown(enCasa())

	y = y + 12
	ui.reiniciar:ClearAllPoints()
	ui.reiniciar:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
	ui.reiniciar:SetShown(s.capturas > 0 or s.total > 0)
	if ui.reiniciar:IsShown() then y = y + ui.reiniciar:GetHeight() end
	return y
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
	for _, g in ipairs(ui.grupos) do
		W.SetSection(g.encabezado, g.titulo)
		g.encabezado:ClearAllPoints()
		g.encabezado:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		g.encabezado:SetWidth(width)
		y = y + W.PLAIN_SECTION_H
		y = colocarFilas(view, g.filas, y, g.panel, width, x) + GAP
	end
	return ordenarRegistro(view, ui, y, width, x) + 24
end

local function construir(view)
	local ui = { tarjeta = crearTarjeta(view), grupos = grupos(view), objetos = {} }
	for _, g in ipairs(ui.grupos) do
		g.encabezado = W.SectionHeader(view, { plain = true })
		g.panel = W.RowPanel(view)
	end
	ui.regEnc = W.SectionHeader(view, { plain = true })
	ui.regPanel = W.RowPanel(view)
	ui.regResumen = W.Text(view, "note", "textDim")
	ui.regResumen:SetWordWrap(true)
	ui.regVacio = W.Text(view, "note", "textMuted")
	ui.regVacio:SetWordWrap(true)
	ui.regVacio:SetJustifyV("TOP")
	ui.reiniciar = W.Button(view, L["Empezar de nuevo"], function()
		W.Modal({
			title = L["¿Empezar un registro nuevo?"], icon = "reset", danger = true, action = L["Borrar registro"],
			text = L["Se borra lo pescado en esta sesión. Tu habilidad de pesca no cambia."],
			onAccept = function() M.NuevaSesion() end,
		})
	end, { ghost = true, icon = "reset" })

	view.Refresh = function() return ordenar(view, ui) end
	M.vista = view
end

-- Algo cambió (pescaste, cambió tu tecla, tu caña...): la página se rehace si está a la vista.
M.alCambiar = function()
	local view = M.vista
	if not (view and view.Refresh and view.IsVisible and view:IsVisible()) then return end
	local h = view.Refresh()
	view:SetHeight(h)
	local O = A.UI and A.UI.Options
	if O and O.frame then W.ShellBody(O.frame, h) end
end

N.Modulo({
	id = ID, nombre = L["Pesca"], icono = "icon-interact", orden = 55,
	subtitulo = L["Lanza con una tecla y recoge con la misma, con autobotín, sonido amplificado y doble clic."],
	comando = "pesca",
	ajustes = M.AJUSTES,
	construir = construir,
})

-- /alfa pesca con sus opciones (on, off, reiniciar); sin nada abre la página.
A.RegisterCommand("pesca", M.Comando, L["abre Pesca (también: on, off, reiniciar)"])
