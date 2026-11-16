-- Alfa - Inicio: la portada de Alfa (Toxic / La Jauría). GPL-3.0.
--
-- La primera página de la ventana de Alfa (orden 5), de arriba abajo:
--   * la cabecera: tu nombre, nivel, clase y zona, el tiempo de sesión y tu
--     barra de XP con la XP descansada detrás;
--   * el tablero de la sesión: tiempo, XP ganada, XP por hora, tiempo para
--     subir, oro neto, misiones entregadas, niveles y muertes (M.Sesion);
--   * tu siguiente paso: el paso vivo de la guía del motor (Engine.GetLiveStep,
--     GetStepView y UI.GoalText, lo mismo que dibuja la ventana de la guía) y
--     el botón para abrirla (SHOW_FRAME) o elegir otra (SHOW_PICKER);
--   * la revisión rápida: equipo, bolsas, entrenador, buff y descanso (M.Rec);
--   * accesos rápidos: un mosaico por módulo de AlfaNucleo.modulos, por su
--     orden; los que cargan después llegan con ALFA_MODULO;
--   * el diario: una gráfica de barras (XP, XP por hora, oro o tiempo) de las
--     últimas sesiones con la de ahora al final, y las últimas cinco en lista;
--   * los recordatorios: sus ajustes, con las filas de la ventana de opciones
--     (Alfa.UI.Options.Rows), más dos del motor que van con ellos.
-- Mientras la página se ve, los números se repintan una vez por segundo (un
-- temporizador que se apaga al ocultarla); el resto se acomoda solo cuando
-- algo cambia.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local W, T = A.Widgets, A.Theme
local L = N.Textos(M.EN)
local S, R, Aviso = M.Sesion, M.Rec, M.Aviso
local num, texto, miles = M.num, M.texto, M.miles

local floor, max, min, ceil, format = math.floor, math.max, math.min, math.ceil, string.format
local ipairs, pairs, type, tostring, tonumber = ipairs, pairs, type, tostring, tonumber

local P = {}
M.Pagina = P

local GAP = 10       -- entre mosaicos
local COLGAP = 24    -- entre las dos columnas (como en Acerca de)
local HERO_H = 128
local TILE_H = 66
local FILA_H = 38    -- una fila de la revisión rápida
local CHART_H = 172
local BARRAS = 12    -- barras de la gráfica (la sesión de ahora es la última)
local LISTA = 5      -- sesiones en la lista
local LISTA_H = 34
local DOT = "  \194\183  "
local RAYA = "\226\128\148"

local function ancho()
	local O = A.UI and A.UI.Options
	local win = type(O) == "table" and O.frame
	local w = type(win) == "table" and num(win.BodyWidth)
	return w or 640
end

---------------------------------------------------------------------------
-- Ajustes
---------------------------------------------------------------------------

local AJUSTES = {
	recDurabilidad = true, durAviso = 30, durUrgente = 10,
	recBolsas = true, bolsasLibres = 4,
	recEntrenar = true, entrenarMin = 1,
	recBuff = true, buffCada = 3, buffQueda = 0,
	recDescanso = true, descansoBajo = 5,
	resumen = "ambos", segAviso = 10, sonido = true, diarioMax = 30,
	grafica = "xp",
}

local function apagado(clave) return function() return not N.Get("inicio", clave) end end
local function porc(v) return format("%d%%", v) end

local C = {
	recDurabilidad = { kind = "toggle", key = "inicio.recDurabilidad", label = L["Avisarme cuando mi equipo se gaste"],
		help = L["Te dice qué pieza está por romperse, para que la repares a tiempo."],
		search = "durabilidad, reparar, equipo, roto, armadura, durability, repair, broken, gear" },
	durAviso = { kind = "slider", key = "inicio.durAviso", label = L["Primer aviso"], min = 15, max = 60, step = 5, format = porc,
		help = L["Cuando una pieza baja de este porcentaje."], child = true, disabled = apagado("recDurabilidad"),
		search = "durabilidad, reparar, durability, repair" },
	durUrgente = { kind = "slider", key = "inicio.durUrgente", label = L["Aviso urgente, con sonido"], min = 0, max = 25, step = 5, format = porc,
		help = L["Cuando ya casi se rompe."], child = true, disabled = apagado("recDurabilidad"),
		search = "durabilidad, reparar, urgente, durability, repair" },
	recBolsas = { kind = "toggle", key = "inicio.recBolsas", label = L["Avisarme cuando mis bolsas se llenen"],
		help = L["Para que no dejes botín tirado por falta de espacio."],
		search = "bolsas, llenas, espacio, inventario, bags, full, space" },
	bolsasLibres = { kind = "slider", key = "inicio.bolsasLibres", label = L["Avisar con estos espacios libres o menos"], min = 0, max = 12, step = 1,
		format = function(v) return v == 1 and L["1 espacio"] or format(L["%d espacios"], v) end,
		child = true, disabled = apagado("recBolsas"), search = "bolsas, espacio, bags, slots" },
	recEntrenar = { kind = "toggle", key = "inicio.recEntrenar", label = L["Avisarme en la ciudad si tengo habilidades por aprender"],
		help = L["Al llegar a una ciudad o posada. También repite la nota de entrenar de la guía cuando su ventana está oculta."],
		search = "entrenar, entrenador, habilidades, hechizos, train, trainer, spells, skills" },
	entrenarMin = { kind = "slider", key = "inicio.entrenarMin", label = L["Desde cuántas habilidades"], min = 1, max = 5, step = 1,
		format = function(v) return format("%d", v) end, child = true, disabled = apagado("recEntrenar"),
		search = "entrenar, habilidades, train, spells" },
	recBuff = { kind = "toggle", key = "inicio.recBuff", label = L["Avisarme si me falta mi buff fuera de combate"],
		help = L["Grito de batalla para el guerrero; Intelecto Arcano y una armadura para el mago; Entereza y Fuego interno para el sacerdote; y lo suyo para cada clase."],
		search = "buff, grito de batalla, battle shout, aura, armadura, intelecto, reminder" },
	buffCada = { kind = "slider", key = "inicio.buffCada", label = L["Repetir a lo más cada"], min = 1, max = 10, step = 1,
		format = function(v) return format(L["%d min"], v) end, child = true, disabled = apagado("recBuff"),
		search = "buff, repetir, minutos, minutes" },
	buffQueda = { kind = "slider", key = "inicio.buffQueda", label = L["Avisar también si le quedan menos de"], min = 0, max = 60, step = 5,
		format = function(v) return v <= 0 and L["Solo si falta"] or format(L["%d s"], v) end, child = true, disabled = apagado("recBuff"),
		search = "buff, segundos, queda, expira, seconds, expiring" },
	recDescanso = { kind = "toggle", key = "inicio.recDescanso", label = L["Avisarme de mi XP descansada"],
		help = L["Cuando entras a una posada o ciudad, y cuando tu XP descansada se acaba."],
		search = "descanso, descansada, posada, rested, rest, inn, xp" },
	descansoBajo = { kind = "slider", key = "inicio.descansoBajo", label = L["Avisar cuando baje de"], min = 0, max = 50, step = 5,
		format = function(v) return v <= 0 and L["Solo al acabarse"] or format(L["%d%% de nivel"], v) end, child = true,
		disabled = apagado("recDescanso"), search = "descanso, descansada, rested, low" },
	resumen = { kind = "dropdown", key = "inicio.resumen", label = L["Resumen de tu sesión anterior al entrar"],
		help = L["Lo que ganaste la última vez que jugaste con este personaje."],
		choices = { { value = "ambos", label = L["En un aviso y en el chat"] }, { value = "aviso", label = L["En un aviso"] },
			{ value = "chat", label = L["En el chat"] }, { value = "no", label = L["No mostrar"] } },
		search = "resumen, sesión anterior, diario, summary, last session" },
	segAviso = { kind = "slider", key = "inicio.segAviso", label = L["Cuánto dura un aviso en pantalla"], min = 5, max = 30, step = 1,
		format = function(v) return format(L["%d s"], v) end, help = L["Con el cursor encima no se cierra."],
		search = "aviso, duración, segundos, toast, seconds" },
	sonido = { kind = "toggle", key = "inicio.sonido", label = L["Sonido en los avisos urgentes"],
		help = L["Equipo a punto de romperse."], search = "sonido, alerta, sound, alert" },
	diarioMax = { kind = "slider", key = "inicio.diarioMax", label = L["Sesiones que guarda el diario"], min = 10, max = 60, step = 5,
		format = function(v) return format("%d", v) end, search = "diario, sesiones, historial, journal, history" },
	probar = { kind = "button", key = nil, label = L["Probar un aviso"], button = L["Probar"], icon = "info",
		help = L["Muestra un aviso de ejemplo para que veas dónde sale."], onClick = function() Aviso.Probar() end,
		search = "aviso, probar, test, toast" },
	lugar = { kind = "button", label = L["Devolver los avisos a su lugar"], button = L["Restablecer"], icon = "window",
		help = L["Si moviste los avisos y ya no los encuentras."], onClick = function() N.Set("inicio", "avisoPos", nil) end,
		search = "aviso, posición, mover, position, reset" },
	borrar = { kind = "button", label = L["Borrar el diario"], button = L["Borrar"], icon = "reset", danger = true, confirm = true,
		confirmTitle = L["¿Borrar el diario?"], confirmAction = L["Borrar"],
		confirmText = L["Se borran las sesiones guardadas de este personaje. La sesión de ahora sigue contando."],
		help = L["Las sesiones guardadas de este personaje."], onClick = function() S.Borrar() end,
		search = "diario, borrar, historial, clear, journal" },
}

-- Del motor: van con los recordatorios de entrenar, pero son sus ajustes (no
-- se registran aquí, para que la búsqueda los siga llevando a su página).
local DEL_MOTOR = {
	tarjeta = { kind = "toggle", key = "qol.levelUpSpells", label = L["Tarjeta de habilidades nuevas al subir de nivel"],
		help = L["Del motor de Alfa: al subir de nivel te muestra qué aprender y cuánto cuesta."] },
	nota = { kind = "dropdown", key = "behavior.trainReminder", label = L["Nota de entrenar en la ventana de la guía"],
		help = L["Del motor de Alfa: con el entrenador más cercano en tu camino."],
		choices = { { value = "2", label = L["Cada 2 niveles"] }, { value = "1", label = L["Cada nivel"] }, { value = "off", label = L["No"] } } },
}

local GRUPOS = {
	{ L["Durabilidad"], { C.recDurabilidad, C.durAviso, C.durUrgente } },
	{ L["Bolsas"], { C.recBolsas, C.bolsasLibres } },
	{ L["Habilidades por entrenar"], { C.recEntrenar, C.entrenarMin, DEL_MOTOR.tarjeta, DEL_MOTOR.nota } },
	{ L["Buff fuera de combate"], { C.recBuff, C.buffCada, C.buffQueda } },
	{ L["Descanso"], { C.recDescanso, C.descansoBajo } },
	{ L["Avisos y diario"], { C.resumen, C.segAviso, C.sonido, C.diarioMax, C.probar, C.lugar, C.borrar } },
}

local CONTROLES = {
	C.recDurabilidad, C.durAviso, C.durUrgente, C.recBolsas, C.bolsasLibres, C.recEntrenar, C.entrenarMin,
	C.recBuff, C.buffCada, C.buffQueda, C.recDescanso, C.descansoBajo,
	C.resumen, C.segAviso, C.sonido, C.diarioMax, C.probar, C.lugar, C.borrar,
}

-- Los controles que se pueden dibujar: un ajuste sin valor por omisión (un
-- motor sin esa función) se deja fuera.
local function disponibles(lista)
	local out = {}
	for _, c in ipairs(lista) do
		if c.kind == "button" or (c.key and A.GetDefault(c.key) ~= nil) then out[#out + 1] = c end
	end
	return out
end

---------------------------------------------------------------------------
-- Piezas
---------------------------------------------------------------------------

local TILES = {
	{ clave = "tiempo", icono = "hourglass", etiqueta = L["Tiempo de sesión"] },
	{ clave = "xp", icono = "icon-level", etiqueta = L["XP ganada"] },
	{ clave = "ritmo", icono = "bolt", etiqueta = L["XP por hora"] },
	{ clave = "subir", icono = "hourglass-sand", etiqueta = L["Para subir de nivel"] },
	{ clave = "oro", icono = "qol-coin", etiqueta = L["Oro de la sesión"] },
	{ clave = "misiones", icono = "icon-turnin", etiqueta = L["Misiones entregadas"] },
	{ clave = "niveles", icono = "star", etiqueta = L["Niveles subidos"] },
	{ clave = "muertes", icono = "cross", etiqueta = L["Muertes"] },
}

local ESTADOS = {
	{ clave = "equipo", icono = "icon-buy", etiqueta = L["Equipo"], boton = L["Reparar"], ir = "repair" },
	{ clave = "bolsas", icono = "icon-collect", etiqueta = L["Bolsas"], boton = L["Vendedor"], ir = "vendor" },
	{ clave = "entrenar", icono = "icon-train", etiqueta = L["Entrenador"], boton = L["Ir"], ir = "class" },
	{ clave = "buff", icono = "bolt", etiqueta = L["Tu buff"] },
	{ clave = "descanso", icono = "icon-sethome", etiqueta = L["Descanso"] },
}

local METRICAS = {
	{ clave = "xp", texto = L["XP"], titulo = L["XP por sesión"] },
	{ clave = "ritmo", texto = L["XP/h"], titulo = L["XP por hora en cada sesión"] },
	{ clave = "oro", texto = L["Oro"], titulo = L["Oro neto por sesión"] },
	{ clave = "tiempo", texto = L["Tiempo"], titulo = L["Tiempo de juego por sesión"] },
}

local function tooltipDe(frame)
	frame:EnableMouse(true)
	frame:SetScript("OnEnter", W.SimpleTip)
	frame:SetScript("OnLeave", W.HideTip)
end

local function nuevoTile(view, def)
	local t = CreateFrame("Frame", nil, view)
	t:SetHeight(TILE_H)
	T.Skin(t, "panel")
	t.Icon = W.Tex(t, "ARTWORK", def.icono, "accent")
	t.Icon:SetSize(14, 14)
	t.Icon:SetPoint("TOPLEFT", t, "TOPLEFT", 12, -12)
	t.Label = W.Text(t, "small", "textMuted")
	t.Label:SetPoint("LEFT", t.Icon, "RIGHT", 7, 0)
	t.Label:SetPoint("RIGHT", t, "RIGHT", -10, 0)
	t.Label:SetText(def.etiqueta)
	t.Value = W.Text(t, "display", "text")
	t.Value:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 12, 11)
	t.Value:SetPoint("RIGHT", t, "RIGHT", -10, 0)
	t.psTip = def.etiqueta
	t.psTipAnchor = "ANCHOR_TOP"
	tooltipDe(t)
	return t
end

local function nuevoHero(view)
	local h = CreateFrame("Frame", nil, view)
	h:SetHeight(HERO_H)
	T.Skin(h, "panel")
	h.Band = T.Band(h, "BACKGROUND", -5)
	h.Band:SetPoint("TOPLEFT", h, "TOPLEFT", 1, -1)
	h.Band:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -1, 1)
	if W.Haze then h.Haze = W.Haze(h, { height = 96, sub = -4 }) end
	h.Ring = W.Tex(h, "ARTWORK", "qol-ring", "accent")
	h.Ring:SetSize(40, 40)
	h.Ring:SetPoint("TOPLEFT", h, "TOPLEFT", 18, -20)
	h.Glyph = W.Tex(h, "OVERLAY", "house", "accent")
	h.Glyph:SetSize(18, 18)
	h.Glyph:SetPoint("CENTER", h.Ring, "CENTER", 0, 0)
	h.Hola = W.Text(h, "display", "text")
	h.Hola:SetPoint("TOPLEFT", h, "TOPLEFT", 72, -22)
	h.Quien = W.Text(h, "note", "textDim")
	h.Quien:SetPoint("TOPLEFT", h, "TOPLEFT", 72, -46)
	h.Chip = W.Chip(h)
	h.Chip:SetPoint("TOPRIGHT", h, "TOPRIGHT", -16, -22)
	h.XP = W.ProgressLine(h, 8)
	h.XP:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 18, 20)
	-- La XP descansada: detrás de la barra, en el azul del descanso.
	h.Rested = h.XP:CreateTexture(nil, "BORDER")
	h.Rested:SetTexture(T.Media("white"))
	h.Rested:SetPoint("TOPLEFT", h.XP, "TOPLEFT", 0, 0)
	h.Rested:SetPoint("BOTTOMLEFT", h.XP, "BOTTOMLEFT", 0, 0)
	h.Rested:SetWidth(0.01)
	W.Color(h.Rested, "npc", 0.5)
	h.XPText = W.Text(h, "small", "text")
	h.XPText:SetPoint("BOTTOMLEFT", h.XP, "TOPLEFT", 0, 7)
	h.RestText = W.Text(h, "small", "npc")
	h.RestText:SetJustifyH("RIGHT")
	h.RestText:SetPoint("BOTTOMRIGHT", h.XP, "TOPRIGHT", 0, 7)
	for _, fs in ipairs({ h.Hola, h.Quien, h.XPText, h.RestText }) do
		W.Painter(fs, function(t)
			local r, g, b = T.Color("shade")
			t:SetShadowOffset(0, -1)
			t:SetShadowColor(r, g, b, 0.85)
		end)
	end
	if W.Rim then W.Rim(h, { height = 70 }) end
	return h
end

local function nuevoPaso(view)
	local c = CreateFrame("Frame", nil, view)
	T.Skin(c, "panel")
	c.Bar = W.Tex(c, "ARTWORK", nil, "accent")
	c.Bar:SetWidth(2)
	c.Bar:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	c.Bar:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	c.Guia = W.Text(c, "small", "textMuted")
	c.Num = W.Chip(c)
	c.Icon = W.Tex(c, "ARTWORK", "icon-goto", "accent")
	c.Icon:SetSize(18, 18)
	c.Titulo = W.Text(c, "title", "text")
	c.Titulo:SetWordWrap(true)
	c.Titulo:SetJustifyV("TOP")
	c.Lineas = {}
	c.Prog = W.ProgressLine(c, 3)
	c.Pct = W.Text(c, "small", "textDim")
	c.Pct:SetJustifyH("RIGHT")
	c.Vacio = W.Text(c, "note", "textDim")
	c.Vacio:SetWordWrap(true)
	c.Vacio:SetSpacing(3)
	c.Vacio:SetJustifyV("TOP")
	c.Abrir = W.Button(c, L["Abrir la guía"], function() A.Fire("SHOW_FRAME") end, { primary = true, icon = "window" })
	c.Elegir = W.Button(c, L["Elegir otra guía"], function() A.Fire("SHOW_PICKER") end, { icon = "guides" })
	c.Primera = W.Button(c, L["Elegir una guía"], function() A.Fire("SHOW_PICKER") end, { primary = true, icon = "guides" })
	return c
end

local function lineaPaso(c, i)
	local l = c.Lineas[i]
	if l then return l end
	l = {}
	l.Icon = W.Tex(c, "ARTWORK", "icon-note", "textDim")
	l.Icon:SetSize(12, 12)
	l.Text = W.Text(c, "body", "textDim")
	l.Text:SetWordWrap(true)
	l.Text:SetJustifyV("TOP")
	c.Lineas[i] = l
	return l
end

local function nuevaFila(panel, def)
	local f = CreateFrame("Frame", nil, panel)
	f:SetHeight(FILA_H)
	f.Icon = W.Tex(f, "ARTWORK", def.icono, "accent")
	f.Icon:SetSize(16, 16)
	f.Icon:SetPoint("LEFT", f, "LEFT", 16, 0)
	f.Label = W.Text(f, "body", "rowLabel")
	f.Label:SetPoint("LEFT", f, "LEFT", 44, 0)
	f.Label:SetWidth(130)
	f.Label:SetText(def.etiqueta)
	f.Estado = W.Text(f, "note", "textDim")
	f.Estado:SetPoint("LEFT", f, "LEFT", 180, 0)
	f.Rule = W.Divider(f, false, 0.6)
	f.Rule:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	f.Rule:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	if def.boton then
		f.Boton = W.Button(f, def.boton, function() R.IrA(def.ir) end, { height = 24 })
		f.Boton:SetPoint("RIGHT", f, "RIGHT", -10, 0)
		f.Boton:Hide()
	end
	f.def = def
	return f
end

local function chipBoton(parent, m)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(W.CHIP_H)
	b.Chip = W.Chip(b)
	b.Chip:SetAllPoints(b)
	b.psMetrica = m
	b:SetScript("OnClick", function(self) N.Set("inicio", "grafica", self.psMetrica.clave) end)
	return b
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

local function construir(view)
	P.view = view
	P.cache = {}
	P.hero = nuevoHero(view)
	P.tiles = {}
	for i, def in ipairs(TILES) do
		local t = nuevoTile(view, def)
		t.def = def
		P.tiles[i] = t
	end

	P.hPaso = W.SectionHeader(view)
	P.paso = nuevoPaso(view)

	P.hEstado = W.SectionHeader(view)
	P.estado = W.RowPanel(view)
	P.filas = {}
	for i, def in ipairs(ESTADOS) do P.filas[i] = nuevaFila(P.estado, def) end

	P.hAccesos = W.SectionHeader(view)
	P.accesos = {}
	P.sinAccesos = W.Text(view, "note", "textMuted")
	P.sinAccesos:SetWordWrap(true)
	P.sinAccesos:SetText(L["Aquí aparecerán los demás módulos de Alfa (bolsas, rutas, mundo y más) en cuanto estén instalados."])

	P.hDiario = W.SectionHeader(view)
	local g = CreateFrame("Frame", nil, view)
	T.Skin(g, "panel")
	g.Titulo = W.Text(g, "small", "textDim")
	g.Titulo:SetPoint("TOPLEFT", g, "TOPLEFT", 14, -14)
	g.Chips = {}
	for i, m in ipairs(METRICAS) do g.Chips[i] = chipBoton(g, m) end
	g.Base = W.Divider(g)
	g.Barras = {}
	g.Vacio = W.Text(g, "note", "textMuted")
	g.Vacio:SetText(L["Todavía no hay datos para esta gráfica."])
	P.grafica = g
	P.lista = W.RowPanel(view)
	P.listaFilas = {}
	P.sinDiario = W.Text(view, "note", "textMuted")
	P.sinDiario:SetWordWrap(true)
	P.sinDiario:SetSpacing(3)
	P.sinDiario:SetText(L["Tu primera sesión entra al diario cuando salgas del juego. La manada te espera: ¡a cazar!"])

	P.hAjustes = W.SectionHeader(view)
	P.hGrupos, P.paneles = {}, {}
	for i = 1, #GRUPOS do
		P.hGrupos[i] = W.SectionHeader(view, { plain = true })
		P.paneles[i] = W.RowPanel(view)
	end
	P.sinAjustes = W.Text(view, "note", "textMuted")
	P.sinAjustes:SetWordWrap(true)
	P.sinAjustes:SetText(L["Los ajustes de los recordatorios están en la búsqueda de la ventana de Alfa."])

	view.Refresh = function() return P.Layout(view) end
	view:HookScript("OnShow", function() P.AlMostrar() end)
	view:HookScript("OnHide", function() P.AlOcultar() end)
end

local function encabezado(h, txt, y, w, cuenta)
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", P.view, "TOPLEFT", W.SHELL.pad, -y)
	h:SetWidth(w)
	W.SetSection(h, txt, cuenta)
	h:Show()
	return y + 44 + 6
end

---------------------------------------------------------------------------
-- Tu siguiente paso
---------------------------------------------------------------------------

local ABIERTA = { active = true, pending = true }

local function textoMeta(g)
	local UI = A.UI
	if type(UI) == "table" and type(UI.GoalText) == "function" then
		local ok, s = pcall(UI.GoalText, g)
		if ok and type(s) == "string" and s ~= "" then return s end
	end
	return texto(g.text) or ""
end

-- El paso vivo de la guía activa: { guia, num, total, titulo, verbo, metas,
-- hechos, todos } o { guia, fin = true }; nil sin guía.
local function pasoActual()
	local E = A.Engine
	if type(E) ~= "table" or type(E.GetGuide) ~= "function" then return nil end
	local ok, g = pcall(E.GetGuide)
	if not ok or type(g) ~= "table" then return nil end
	local info = { guia = texto(g.title) or "" }
	local okp, hechos, todos = pcall(E.GetProgress)
	if okp then info.hechos, info.todos = num(hechos) or 0, num(todos) or 0 end
	local live = type(E.GetLiveStep) == "function" and E.GetLiveStep() or nil
	local i = type(live) == "number" and live or (type(E.GetStepIndex) == "function" and E.GetStepIndex()) or nil
	if type(live) ~= "number" and info.todos and info.todos > 0 and info.hechos >= info.todos then
		info.fin = true
		return info
	end
	if type(i) ~= "number" then return info end
	local okv, v = pcall(E.GetStepView, i)
	if not okv or type(v) ~= "table" then return info end
	if type(E.StepNumber) == "function" then info.num = num(E.StepNumber(i)) end
	if type(E.StepTotal) == "function" then info.total = num(E.StepTotal()) end
	local UI = A.UI
	if type(UI) == "table" and type(UI.StepSummary) == "function" then
		local oks, s = pcall(UI.StepSummary, v)
		if oks and type(s) == "string" then info.titulo = s end
	end
	info.titulo = (info.titulo ~= "" and info.titulo) or texto(v.title) or ""
	-- La meta de ahora primero, luego las demás abiertas (sin notas), tres a lo más.
	local metas, usadas = {}, {}
	local goals = type(v.goals) == "table" and v.goals or {}
	local function tomar(k)
		local gv = goals[k]
		if type(gv) ~= "table" or usadas[k] or gv.folded or not ABIERTA[gv.status] then return end
		usadas[k] = true
		metas[#metas + 1] = { t = gv.t, texto = textoMeta(gv) }
	end
	if type(v.current) == "number" then tomar(v.current) end
	for k, gv in ipairs(goals) do
		if #metas >= 3 then break end
		if type(gv) == "table" and gv.t ~= "note" then tomar(k) end
	end
	if #metas == 0 then
		for k = 1, #goals do
			if #metas >= 3 then break end
			tomar(k)
		end
	end
	info.metas = metas
	info.verbo = metas[1] and metas[1].t or "goto"
	return info
end

function P.LayoutPaso(w, x, y)
	local c = P.paso
	c:ClearAllPoints()
	c:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
	c:SetWidth(w)
	for _, l in ipairs(c.Lineas) do
		l.Icon:Hide()
		l.Text:Hide()
	end
	local info = pasoActual()
	local inner = w - 32
	local cy = 16
	local conGuia = info and not info.fin and info.num ~= nil
	c.Guia:SetShown(info ~= nil)
	c.Num:SetShown(conGuia)
	c.Icon:SetShown(conGuia)
	c.Titulo:SetShown(conGuia)
	c.Prog:SetShown(info ~= nil and (info.todos or 0) > 0)
	c.Pct:SetShown(c.Prog:IsShown())
	c.Vacio:SetShown(not conGuia)
	c.Abrir:SetShown(info ~= nil)
	c.Elegir:SetShown(info ~= nil)
	c.Primera:SetShown(info == nil)

	if info then
		c.Guia:ClearAllPoints()
		c.Guia:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -cy)
		c.Guia:SetText(format(L["Guía: %s"], info.guia ~= "" and info.guia or RAYA))
		local chipW = 0
		if conGuia then
			chipW = W.SetChip(c.Num, info.total and format(L["Paso %d de %d"], info.num, info.total) or format(L["Paso %d"], info.num), "accent")
			c.Num:ClearAllPoints()
			c.Num:SetPoint("TOPRIGHT", c, "TOPRIGHT", -14, -(cy - 3))
		end
		c.Guia:SetWidth(max(1, inner - chipW - 12))
		cy = cy + 26
	end

	if conGuia then
		c.Icon:SetTexture(T.VerbIcon(info.verbo))
		c.Icon:ClearAllPoints()
		c.Icon:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -(cy - 1))
		c.Titulo:SetText(info.titulo)
		c.Titulo:SetWidth(max(1, inner - 28))
		c.Titulo:ClearAllPoints()
		c.Titulo:SetPoint("TOPLEFT", c, "TOPLEFT", 44, -cy)
		cy = cy + max(18, ceil(c.Titulo:GetStringHeight())) + 10
		for i, m in ipairs(info.metas or {}) do
			local l = lineaPaso(c, i)
			l.Icon:SetTexture(T.VerbIcon(m.t))
			l.Icon:ClearAllPoints()
			l.Icon:SetPoint("TOPLEFT", c, "TOPLEFT", 46, -(cy + 1))
			l.Text:SetText(m.texto)
			l.Text:SetWidth(max(1, inner - 50))
			l.Text:ClearAllPoints()
			l.Text:SetPoint("TOPLEFT", c, "TOPLEFT", 66, -cy)
			W.Color(l.Text, i == 1 and "text" or "textDim")
			l.Icon:Show()
			l.Text:Show()
			cy = cy + ceil(l.Text:GetStringHeight()) + 6
		end
		cy = cy + 6
	else
		local txt
		if not info then
			txt = L["Todavía no tienes una guía abierta. Elige una y Alfa te lleva paso a paso: a dónde ir, qué hacer y con quién hablar."]
		elseif info.fin then
			txt = L["¡Terminaste esta guía! Elige la siguiente y sigue subiendo con la manada."]
		else
			txt = L["Tu guía está lista. Ábrela para ver tu paso."]
		end
		c.Vacio:SetText(txt)
		c.Vacio:SetWidth(max(1, inner))
		c.Vacio:ClearAllPoints()
		c.Vacio:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -cy)
		cy = cy + ceil(c.Vacio:GetStringHeight()) + 14
	end

	if c.Prog:IsShown() then
		local frac = info.todos > 0 and info.hechos / info.todos or 0
		local barW = max(1, inner - 56)
		c.Prog:ClearAllPoints()
		c.Prog:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -cy)
		c.Prog:SetWidth(barW)
		W.SetProgress(c.Prog, frac, barW)
		c.Pct:SetText(format("%d%%", floor(frac * 100 + 0.5)))
		c.Pct:ClearAllPoints()
		c.Pct:SetPoint("RIGHT", c, "TOPRIGHT", -16, -(cy + 1))
		cy = cy + 16
	end

	if info then
		c.Abrir:ClearAllPoints()
		c.Abrir:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -cy)
		c.Elegir:ClearAllPoints()
		c.Elegir:SetPoint("LEFT", c.Abrir, "RIGHT", 8, 0)
		cy = cy + c.Abrir:GetHeight()
	else
		c.Primera:ClearAllPoints()
		c.Primera:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -cy)
		cy = cy + c.Primera:GetHeight()
	end
	cy = cy + 16
	c:SetHeight(cy)
	return cy
end

---------------------------------------------------------------------------
-- Revisión rápida
---------------------------------------------------------------------------

function P.LayoutEstado(w, x, y)
	local panel = P.estado
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
	panel:SetSize(w, #P.filas * FILA_H)
	for i, f in ipairs(P.filas) do
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(i - 1) * FILA_H)
		f:SetWidth(w)
		f.Estado:SetWidth(max(1, w - 180 - (f.Boton and (f.Boton:GetWidth() + 20) or 12)))
		f.Rule:SetShown(i < #P.filas)
	end
	return #P.filas * FILA_H
end

local function pintarFila(f, txt, color, boton)
	f.Estado:SetText(txt or RAYA)
	W.Color(f.Estado, color or "textDim")
	if f.Boton then f.Boton:SetShown(boton and true or false) end
end

local function pintarEstado()
	local st = R.Estado()
	local durAviso = tonumber(N.Get("inicio", "durAviso")) or 30
	local durUrg = tonumber(N.Get("inicio", "durUrgente")) or 10
	for _, f in ipairs(P.filas) do
		local k = f.def.clave
		if k == "equipo" then
			local e = st.equipo
			if not e.pct then
				pintarFila(f, L["Nada que reparar"], "textMuted")
			else
				local pct = floor(e.pct + 0.5)
				local pieza = R.NombreRanura(e.slot)
				if e.pct <= durUrg then
					pintarFila(f, format(L["%s al %d%%: ¡repara ya!"], pieza, pct), "danger", true)
				elseif e.pct <= durAviso then
					pintarFila(f, format(L["%s al %d%%"], pieza, pct), "warning", true)
				else
					pintarFila(f, format(L["Todo bien (lo más gastado: %d%%)"], pct), "success")
				end
			end
		elseif k == "bolsas" then
			local libres, total = st.bolsas.libres, st.bolsas.total
			if not libres then
				pintarFila(f, nil, "textMuted")
			else
				local umbral = tonumber(N.Get("inicio", "bolsasLibres")) or 4
				local txt = format(L["%d de %d espacios libres"], libres, total or 0)
				pintarFila(f, txt, (libres == 0 and "danger") or (libres <= umbral and "warning") or "success", libres <= umbral)
			end
		elseif k == "entrenar" then
			local e = st.entrenar
			if not e.listo then
				pintarFila(f, nil, "textMuted")
			elseif e.n == 0 then
				pintarFila(f, L["Nada nuevo por aprender"], "success")
			else
				local txt = e.n == 1 and L["1 habilidad por aprender"] or format(L["%d habilidades por aprender"], e.n)
				if e.costo > 0 then txt = txt .. DOT .. N.Dinero(e.costo) end
				pintarFila(f, txt, "warning", true)
			end
		elseif k == "buff" then
			local b = st.buff
			if b.estado == "ok" then
				pintarFila(f, L["Activo"], "success")
			elseif b.estado == "falta" then
				pintarFila(f, format(L["Te falta %s"], b.nombre or "?"), "warning")
			elseif b.estado == "poco" then
				pintarFila(f, format(L["A %s le queda poco"], b.nombre or "?"), "warning")
			elseif b.estado == "noaprendido" then
				pintarFila(f, L["Aún no lo aprendes"], "textMuted")
			else
				pintarFila(f, L["Tu clase no necesita recordatorio"], "textMuted")
			end
		elseif k == "descanso" then
			local d = st.descanso
			local pct = floor((d.pct or 0) + 0.5)
			if d.maximo then
				pintarFila(f, L["Nivel máximo"], "textMuted")
			elseif d.activo then
				pintarFila(f, format(L["Descansando%s%d%% de un nivel"], DOT, pct), "success")
			elseif (d.xp or 0) > 0 then
				pintarFila(f, format(L["%d%% de un nivel"], pct), "npc")
			else
				pintarFila(f, L["Sin XP descansada"], "textMuted")
			end
		end
	end
end

---------------------------------------------------------------------------
-- Accesos rápidos
---------------------------------------------------------------------------

local function modulos()
	local out = {}
	for _, spec in ipairs(N.modulos or {}) do
		if type(spec) == "table" and type(spec.id) == "string" and spec.id ~= "inicio" then out[#out + 1] = spec end
	end
	table.sort(out, function(a, b)
		local oa, ob = tonumber(a.orden) or 100, tonumber(b.orden) or 100
		if oa ~= ob then return oa < ob end
		return tostring(a.nombre) < tostring(b.nombre)
	end)
	return out
end

function P.LayoutAccesos(w, x, y)
	local lista = modulos()
	for _, t in pairs(P.accesos) do t:Hide() end
	if #lista == 0 then
		P.sinAccesos:SetWidth(w)
		P.sinAccesos:ClearAllPoints()
		P.sinAccesos:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
		P.sinAccesos:Show()
		return ceil(P.sinAccesos:GetStringHeight()) + 4
	end
	P.sinAccesos:Hide()
	local cw = (w - COLGAP) / 2
	local top = y
	for i = 1, #lista, 2 do
		local par, h = {}, 0
		for k = i, min(i + 1, #lista) do
			local spec = lista[k]
			local t = P.accesos[spec.id]
			if not t then
				t = W.ActionTile(P.view, spec.icono or "gear", tostring(spec.nombre or spec.id), tostring(spec.subtitulo or ""),
					function() N.Abrir(spec.id) end)
				P.accesos[spec.id] = t
			end
			par[#par + 1] = t
		end
		for col, t in ipairs(par) do
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", P.view, "TOPLEFT", x + (col - 1) * (cw + COLGAP), -y)
			t:Show()
			h = max(h, W.LayoutTile(t, cw))
		end
		for _, t in ipairs(par) do t:SetHeight(h) end
		y = y + h + GAP
	end
	return y - top - GAP
end

---------------------------------------------------------------------------
-- Diario
---------------------------------------------------------------------------

local function metrica()
	local m = N.Get("inicio", "grafica")
	for _, d in ipairs(METRICAS) do
		if d.clave == m then return d end
	end
	return METRICAS[1]
end

local function valorDe(s, clave)
	if clave == "ritmo" then
		local dur = tonumber(s.dur) or 0
		return dur >= 300 and (tonumber(s.xp) or 0) / dur * 3600 or 0
	elseif clave == "oro" then
		return tonumber(s.oro) or 0
	elseif clave == "tiempo" then
		return tonumber(s.dur) or 0
	end
	return tonumber(s.xp) or 0
end

local function valorTexto(v, clave)
	if clave == "oro" then return (v > 0 and "+" or "") .. N.Dinero(v) end
	if clave == "tiempo" then return N.Duracion(v) end
	return miles(v)
end

local function detalle(owner, s, ahora)
	local lines = {
		{ left = L["Duración"], right = N.Duracion(s.dur or 0) },
		{ left = L["XP ganada"], right = miles(s.xp or 0) },
		{ left = L["XP por hora"], right = miles(valorDe(s, "ritmo")) },
		{ left = L["Oro"], right = ((tonumber(s.oro) or 0) > 0 and "+" or "") .. N.Dinero(s.oro or 0) },
		{ left = L["Misiones"], right = tostring(s.misiones or 0) },
		{ left = L["Niveles"], right = tostring(s.niveles or 0) },
		{ left = L["Muertes"], right = tostring(s.muertes or 0) },
	}
	W.Tooltip(owner, "ANCHOR_TOP", ahora and L["Tu sesión de ahora"] or S.Cuando(s.inicio), lines)
end

local function barra(g, i)
	local b = g.Barras[i]
	if b then return b end
	-- Un botón: la capa HIGHLIGHT (W.Hover) se enciende sola bajo el cursor.
	b = CreateFrame("Button", nil, g)
	b.Fill = W.Tex(b, "ARTWORK", nil, "accent")
	b.Fill:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	b.Fill:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	b.Fill:SetHeight(1)
	b.Hover = W.Hover(b, 0.8)
	b.Label = W.Text(g, "caption", "textMuted")
	b.Label:SetJustifyH("CENTER")
	b:EnableMouse(true)
	b:SetScript("OnEnter", function(self) if self.psSesion then detalle(self, self.psSesion, self.psAhora) end end)
	b:SetScript("OnLeave", W.HideTip)
	g.Barras[i] = b
	return b
end

local function filaLista(i)
	local f = P.listaFilas[i]
	if f then return f end
	f = CreateFrame("Frame", nil, P.lista)
	f:SetHeight(LISTA_H)
	f.Fecha = W.Text(f, "body", "rowLabel")
	f.Fecha:SetPoint("LEFT", f, "LEFT", 16, 0)
	f.Dur = W.Text(f, "small", "textMuted")
	f.Dur:SetPoint("LEFT", f.Fecha, "RIGHT", 10, 0)
	f.Resumen = W.Text(f, "small", "textDim")
	f.Resumen:SetJustifyH("RIGHT")
	f.Resumen:SetPoint("RIGHT", f, "RIGHT", -14, 0)
	f.Rule = W.Divider(f, false, 0.6)
	f.Rule:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	f.Rule:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	f:EnableMouse(true)
	f:SetScript("OnEnter", function(self) if self.psSesion then detalle(self, self.psSesion, false) end end)
	f:SetScript("OnLeave", W.HideTip)
	P.listaFilas[i] = f
	return f
end

-- Lo que la sesión deja, sin el tiempo (va aparte): "+12,340 XP · 8 misiones · +1o".
local function resumenCorto(s)
	local parts = {}
	if (tonumber(s.xp) or 0) > 0 then parts[#parts + 1] = "+" .. miles(s.xp) .. " XP" end
	local nv = tonumber(s.niveles) or 0
	if nv > 0 then parts[#parts + 1] = nv == 1 and L["1 nivel"] or format(L["%d niveles"], nv) end
	local mis = tonumber(s.misiones) or 0
	if mis > 0 then parts[#parts + 1] = mis == 1 and L["1 misión"] or format(L["%d misiones"], mis) end
	local oro = tonumber(s.oro) or 0
	if oro ~= 0 then parts[#parts + 1] = (oro > 0 and "+" or "") .. N.Dinero(oro, true) end
	if #parts == 0 then return L["Sin cambios"] end
	return table.concat(parts, DOT)
end

-- La gráfica, de ancho w: las últimas sesiones y, al final, la de ahora.
-- Su alto no cambia, así que el temporizador la redibuja sin acomodar la página.
local function dibujarGrafica(w)
	local g = P.grafica
	local m = metrica()
	local pasadas = S.Sesiones()
	local datos = {}
	local desde = max(1, #pasadas - (BARRAS - 2))
	for i = desde, #pasadas do datos[#datos + 1] = { s = pasadas[i] } end
	local e = S.Estado()
	datos[#datos + 1] = { s = { inicio = e.inicio, dur = e.dur, xp = e.xp, oro = e.oro, misiones = e.misiones, niveles = e.niveles, muertes = e.muertes }, ahora = true }

	-- Los botones de la métrica, de derecha a izquierda.
	local right = -12
	for i = #g.Chips, 1, -1 do
		local b = g.Chips[i]
		local cw = W.SetChip(b.Chip, b.psMetrica.texto, b.psMetrica.clave == m.clave and "accent" or nil)
		b:SetWidth(cw)
		b:ClearAllPoints()
		b:SetPoint("TOPRIGHT", g, "TOPRIGHT", right, -10)
		right = right - cw - 6
	end
	local maxV, suma, cuenta = 0, 0, 0
	for _, d in ipairs(datos) do
		d.v = valorDe(d.s, m.clave)
		maxV = max(maxV, math.abs(d.v))
		if not d.ahora then
			suma = suma + d.v
			cuenta = cuenta + 1
		end
	end
	local titulo = m.titulo
	if cuenta > 0 then titulo = titulo .. DOT .. format(L["promedio %s"], valorTexto(suma / cuenta, m.clave)) end
	g.Titulo:SetText(titulo)
	g.Titulo:SetWidth(max(1, w + right - 28))

	local areaTop, areaBottom = 42, 30
	local areaH = CHART_H - areaTop - areaBottom
	local areaW = w - 28
	g.Base:ClearAllPoints()
	g.Base:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 14, areaBottom)
	g.Base:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -14, areaBottom)
	for _, b in ipairs(g.Barras) do
		b:Hide()
		b.Label:Hide()
	end
	g.Vacio:ClearAllPoints()
	g.Vacio:SetPoint("CENTER", g, "CENTER", 0, -4)
	g.Vacio:SetShown(maxV <= 0)
	if maxV > 0 then
		local n = #datos
		local slot = areaW / BARRAS
		local bw = max(6, min(30, floor(slot * 0.6)))
		-- Pegadas a la derecha: la de ahora siempre en el mismo lugar.
		local x0 = 14 + areaW - n * slot
		for i, d in ipairs(datos) do
			local b = barra(g, i)
			local cx = x0 + (i - 0.5) * slot
			b:ClearAllPoints()
			b:SetPoint("BOTTOM", g, "BOTTOMLEFT", cx, areaBottom)
			b:SetSize(bw, areaH)
			local h = max(1, areaH * math.abs(d.v) / maxV)
			b.Fill:SetHeight(h)
			local color = (m.clave == "oro" and d.v < 0) and "danger" or ((m.clave == "oro" and d.v > 0) and "success" or "accent")
			W.Color(b.Fill, color, d.ahora and 1 or 0.55)
			b.psSesion, b.psAhora = d.s, d.ahora
			b.Label:SetText(d.ahora and L["Ahora"] or S.Dia(d.s.inicio))
			W.Color(b.Label, d.ahora and "accent" or "textMuted")
			b.Label:ClearAllPoints()
			b.Label:SetPoint("TOP", g, "BOTTOMLEFT", cx, areaBottom - 6)
			b.Label:Show()
			b:Show()
		end
	end
end

function P.LayoutDiario(w, x, y)
	local g = P.grafica
	local top = y
	local pasadas = S.Sesiones()
	g:ClearAllPoints()
	g:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
	g:SetSize(w, CHART_H)
	dibujarGrafica(w)
	y = y + CHART_H + 10

	-- La lista: las últimas sesiones, la más nueva arriba.
	for _, f in ipairs(P.listaFilas) do f:Hide() end
	local n = min(LISTA, #pasadas)
	P.lista:SetShown(n > 0)
	P.sinDiario:SetShown(n == 0)
	if n == 0 then
		P.sinDiario:SetWidth(w)
		P.sinDiario:ClearAllPoints()
		P.sinDiario:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
		y = y + ceil(P.sinDiario:GetStringHeight()) + 4
		return y - top
	end
	P.lista:ClearAllPoints()
	P.lista:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
	P.lista:SetSize(w, n * LISTA_H)
	for k = 1, n do
		local s = pasadas[#pasadas - k + 1]
		local f = filaLista(k)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", P.lista, "TOPLEFT", 0, -(k - 1) * LISTA_H)
		f:SetWidth(w)
		f.Fecha:SetText(S.Cuando(s.inicio))
		f.Dur:SetText(N.Duracion(s.dur or 0))
		f.Resumen:SetText(resumenCorto(s))
		f.Resumen:SetWidth(max(1, w * 0.55))
		f.psSesion = s
		f.Rule:SetShown(k < n)
		f:Show()
	end
	y = y + n * LISTA_H
	return y - top
end

---------------------------------------------------------------------------
-- Ajustes de los recordatorios
---------------------------------------------------------------------------

function P.LayoutAjustes(view, w, x, y)
	local O = A.UI and A.UI.Options
	if type(O) ~= "table" or type(O.Rows) ~= "function" then
		for i = 1, #GRUPOS do
			P.hGrupos[i]:Hide()
			P.paneles[i]:Hide()
		end
		P.sinAjustes:SetWidth(w)
		P.sinAjustes:ClearAllPoints()
		P.sinAjustes:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		P.sinAjustes:Show()
		return y + ceil(P.sinAjustes:GetStringHeight()) + 8
	end
	P.sinAjustes:Hide()
	for _, wd in pairs(P.cache) do wd:Hide() end
	for i, grupo in ipairs(GRUPOS) do
		local h, panel = P.hGrupos[i], P.paneles[i]
		local lista = disponibles(grupo[2])
		if #lista == 0 then
			h:Hide()
			panel:Hide()
		else
			W.SetSection(h, grupo[1])
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
			h:SetWidth(w)
			h:Show()
			y = y + W.PLAIN_SECTION_H
			y = O.Rows(view, lista, y, P.cache, panel)
			if i < #GRUPOS then y = y + 22 end
		end
	end
	return y
end

---------------------------------------------------------------------------
-- Pintar y acomodar
---------------------------------------------------------------------------

function P.Layout(view)
	local w = ancho()
	local x = W.SHELL.pad
	local y = 12
	R.Leer()

	local h = P.hero
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
	h:SetSize(w, HERO_H)
	h.Band:SetTexCoord(T.BandCoords(w - 2, HERO_H - 2))
	h.XP:SetWidth(max(1, w - 36))
	if W.LayoutRim then W.LayoutRim(h) end
	y = y + HERO_H + 12

	local cols = w >= 520 and 4 or 2
	local tw = (w - GAP * (cols - 1)) / cols
	for i, t in ipairs(P.tiles) do
		local c, r = (i - 1) % cols, floor((i - 1) / cols)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", view, "TOPLEFT", x + c * (tw + GAP), -(y + r * (TILE_H + GAP)))
		t:SetSize(tw, TILE_H)
	end
	y = y + ceil(#P.tiles / cols) * (TILE_H + GAP) - GAP + 10

	y = encabezado(P.hPaso, L["Tu siguiente paso"], y, w)
	y = y + P.LayoutPaso(w, x, y) + 10

	y = encabezado(P.hEstado, L["Revisión rápida"], y, w)
	y = y + P.LayoutEstado(w, x, y) + 10

	local mods = modulos()
	y = encabezado(P.hAccesos, L["Accesos rápidos"], y, w, #mods > 0 and #mods or nil)
	y = y + P.LayoutAccesos(w, x, y) + 10

	local n = #S.Sesiones()
	y = encabezado(P.hDiario, L["Diario"], y, w, n > 0 and n or nil)
	y = y + P.LayoutDiario(w, x, y) + 10

	y = encabezado(P.hAjustes, L["Recordatorios"], y, w)
	y = P.LayoutAjustes(view, w, x, y)

	-- La ventana crea la vista ya visible: su primer OnShow no llega, así que
	-- el temporizador también arranca aquí.
	if view:IsVisible() and not P.ticker then
		P.AlMostrar()
	else
		P.Pintar()
	end
	return y + 24
end

local function claseColoreada()
	if not UnitClass then return "" end
	local nombre, file = UnitClass("player")
	nombre, file = texto(nombre), texto(file)
	if not nombre then return "" end
	local r, g, b = T.ClassColor(file)
	if r then return format("|cff%02x%02x%02x%s|r", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5), nombre) end
	return nombre
end

local function pintarHero(e)
	local h = P.hero
	local nombre = UnitName and texto((UnitName("player")))
	h.Hola:SetText(nombre and format(L["¡Hola, %s!"], nombre) or L["¡Hola!"])
	local partes = { format(L["Nivel %d"], e.nivel or 1) .. " " .. claseColoreada() }
	local C = A.Compat
	if type(C) == "table" and type(C.GetZoneText) == "function" then
		local zona = texto((C.GetZoneText()))
		if zona then partes[#partes + 1] = zona end
	end
	h.Quien:SetText(table.concat(partes, DOT))
	W.SetChip(h.Chip, format(L["Sesión: %s"], N.Duracion(e.dur)), "accent")

	local barW = h.XP:GetWidth()
	if e.maximo then
		W.SetProgress(h.XP, 1, barW)
		h.Rested:SetShown(false)
		h.XPText:SetText(L["Nivel máximo"])
		h.RestText:SetText("")
		return
	end
	local frac = e.xpMax > 0 and e.xpAhora / e.xpMax or 0
	local rfrac = e.xpMax > 0 and min(1, (e.xpAhora + e.descanso) / e.xpMax) or 0
	W.SetProgress(h.XP, frac, barW)
	h.Rested:SetWidth(max(0.01, barW * rfrac))
	h.Rested:SetShown(rfrac > frac)
	h.XPText:SetText(format(L["%s%% del nivel %d"], format("%.1f", frac * 100), e.nivel or 1) .. DOT .. format(L["faltan %s XP"], miles(e.falta)))
	if e.descanso > 0 and e.xpMax > 0 then
		h.RestText:SetText(format(L["Descansada: %d%% de un nivel"], floor(e.descanso / e.xpMax * 100 + 0.5)))
	else
		h.RestText:SetText("")
	end
end

local function pintarTiles(e)
	for _, t in ipairs(P.tiles) do
		local k = t.def.clave
		local v, color, lines = RAYA, "text", nil
		if k == "tiempo" then
			v = N.Duracion(e.dur)
			lines = { format(L["Empezó %s."], S.Cuando(e.inicio)), L["Un /reload no la corta."] }
		elseif k == "xp" then
			v = miles(e.xp)
			lines = { format(L["Promedio de la sesión: %s XP por hora."], miles(e.prom)) }
		elseif k == "ritmo" then
			if e.ritmo and e.ritmo > 0 then v = miles(e.ritmo) end
			lines = { L["Tu ritmo de los últimos 15 minutos, con el contador de XP de Alfa."],
				format(L["Promedio de la sesión: %s XP por hora."], miles(e.prom)) }
		elseif k == "subir" then
			if e.maximo then
				v = L["Nivel máximo"]
			elseif e.subir then
				v = e.subir >= 360000 and L["más de 99 h"] or N.Duracion(e.subir)
				lines = { format(L["Te faltan %s XP para el nivel %d, a tu ritmo actual."], miles(e.falta), (e.nivel or 1) + 1) }
			else
				lines = { L["Gana un poco de XP y Alfa calcula cuánto te falta."] }
			end
		elseif k == "oro" then
			v = (e.oro > 0 and "+" or "") .. N.Dinero(e.oro, true)
			lines = { { left = L["Ganado"], right = N.Dinero(e.ganado) }, { left = L["Gastado"], right = N.Dinero(e.gastado) } }
		elseif k == "misiones" then
			v = tostring(e.misiones)
		elseif k == "niveles" then
			v = tostring(e.niveles)
			if e.nivel0 then lines = { format(L["Empezaste la sesión en el nivel %d."], e.nivel0) } end
		elseif k == "muertes" then
			v = tostring(e.muertes)
			if e.muertes > 0 then color = "danger" end
			lines = { L["Cada muerte gasta un 10% la durabilidad de tu equipo: revisa tu equipo en la revisión rápida."] }
		end
		t.Value:SetText(v)
		W.Color(t.Value, color)
		t.psTipLines = lines
	end
end

local tic = 0
function P.Pintar()
	local view = P.view
	if not (view and view:IsVisible()) then return end
	local e = S.Estado()
	pintarHero(e)
	pintarTiles(e)
	pintarEstado()
	-- La barra de ahora crece con la sesión: cada 10 segundos.
	tic = tic + 1
	if tic >= 10 then
		tic = 0
		dibujarGrafica(P.grafica:GetWidth())
	end
end

local function relayout()
	local view = P.view
	if not (view and view:IsVisible() and view.Refresh) then return end
	local h = view.Refresh()
	view:SetHeight(h)
	local O = A.UI and A.UI.Options
	local win = type(O) == "table" and O.frame
	if type(win) == "table" then W.ShellBody(win, h) end
end

local pendiente = false
local function relayoutPronto()
	if pendiente or not (P.view and P.view:IsVisible()) then return end
	pendiente = true
	A.After(0.3, function()
		pendiente = false
		relayout()
	end)
end
P.Relayout = relayoutPronto

function P.AlMostrar()
	if P.ticker then P.ticker:Cancel() end
	P.ticker = A.NewTicker(1, P.Pintar)
	P.Pintar()
end

function P.AlOcultar()
	if P.ticker then
		P.ticker:Cancel()
		P.ticker = nil
	end
end

A.On("ALFA_MODULO", function(spec)
	if type(spec) == "table" and type(spec.id) == "string" and spec.id ~= "inicio" then relayoutPronto() end
end)
for _, msg in ipairs({ "STEP_CHANGED", "STEP_UPDATED", "GUIDE_CHANGED", "TABS_CHANGED", "INICIO_DIARIO" }) do
	A.On(msg, relayoutPronto)
end
A.On("SETTING_CHANGED", function(path)
	if path == "inicio.grafica" then relayoutPronto() end
end)

---------------------------------------------------------------------------
-- El módulo
---------------------------------------------------------------------------

N.Modulo({
	id = "inicio", nombre = L["Inicio"], icono = "house", orden = 5,
	subtitulo = L["Tu sesión, tus avisos y tu siguiente paso, de un vistazo."],
	comando = "inicio",
	ajustes = AJUSTES,
	controles = CONTROLES,
	construir = construir,
})
