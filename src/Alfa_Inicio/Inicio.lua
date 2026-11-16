-- Alfa - Inicio: la página Hoy, la portada de Alfa (Toxic / La Jauría). GPL-3.0.
--
-- La primera página de la ventana de Alfa (sección Hoy), de arriba abajo:
--   * Tu siguiente paso: una tarjeta grande con el borde de acento a la
--     izquierda. El paso vivo de la guía del motor (Engine.GetLiveStep,
--     GetStepView y UI.GoalText, lo mismo que dibuja la ventana de la guía),
--     la distancia y el rumbo hasta la flecha (Nav.TargetOffset, sin tocar su
--     lógica de llegada), "paso N de M", el avance, y los botones Seguir ruta
--     (muestra la guía y la flecha y cierra esta ventana), Ver pasos (la lista
--     de pasos de la ventana de guía: UI.StepList) y Cambiar guía.
--   * Alertas: solo lo urgente (equipo gastado, bolsas casi llenas,
--     habilidades por entrenar, descanso), con su botón donde hay a dónde ir.
--   * Para tu <clase>: la franja del color de la clase y tres mini tarjetas
--     de esa clase y su rol (M.Clase), cada una abre su módulo.
--   * La fila de números: XP por hora, tiempo para subir, oro de hoy (las
--     sesiones del diario que empezaron hoy más la de ahora) y los lobos de tu
--     hermandad conectados.
--   * Debajo, plegables y más compactos: el diario (tu sesión de ahora, la
--     gráfica y las últimas sesiones), la revisión rápida, los accesos a los
--     módulos y los ajustes de los recordatorios. Lo abierto se recuerda
--     (inicio.abrir*).
-- Mientras la página se ve, los números se repintan una vez por segundo (un
-- temporizador que se apaga al ocultarla); el resto se acomoda solo cuando
-- algo cambia (un paso, una alerta nueva, un módulo que llega).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local W, T = A.Widgets, A.Theme
local L = N.Textos(M.EN)
local S, R, Aviso, K = M.Sesion, M.Rec, M.Aviso, M.Clase
local num, texto, miles = M.num, M.texto, M.miles

local floor, max, min, ceil, format = math.floor, math.max, math.min, math.ceil, string.format
local ipairs, pairs, type, tostring, tonumber = ipairs, pairs, type, tostring, tonumber

local P = {}
M.Pagina = P

local GAP = 10       -- entre tarjetas
local BLOQUE = 18    -- entre bloques de la página
local IZQ = 22       -- texto de las tarjetas con franja: después de la franja
local FRANJA = 3
local TILE_H = 66
local MINI_H = 80
local ALERTA_H = 44
local FILA_H = 38    -- una fila de la revisión rápida
local SESION_H = 36
local CHART_H = 150
local BARRAS = 12    -- barras de la gráfica (la sesión de ahora es la última)
local LISTA = 4      -- sesiones en la lista
local LISTA_H = 30
local PLEG_H = 40    -- cabecera de un bloque plegable
local DOT = "  \194\183  "
local RAYA = "\226\128\148"

local relayout -- más abajo

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
	-- Los bloques plegables de abajo: abiertos o cerrados.
	abrirDiario = true, abrirRevision = false, abrirAccesos = true, abrirAjustes = false,
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

local NUMEROS = {
	{ clave = "ritmo", icono = "bolt", etiqueta = L["XP por hora"] },
	{ clave = "subir", icono = "hourglass-sand", etiqueta = L["Para subir de nivel"] },
	{ clave = "oro", icono = "qol-coin", etiqueta = L["Oro de hoy"] },
	{ clave = "lobos", icono = "flag", etiqueta = L["Lobos conectados"] },
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

local function conTip(frame)
	frame:EnableMouse(true)
	frame:SetScript("OnEnter", W.SimpleTip)
	frame:SetScript("OnLeave", W.HideTip)
end

-- La franja de una tarjeta, a la izquierda: de debajo de su esquina cortada
-- hasta abajo (las otras apariencias no cortan, y va de arriba abajo).
local function franja(card, color)
	local t = W.Tex(card, "ARTWORK", nil, color)
	t:SetWidth(FRANJA)
	W.Painter(t, function(tex)
		local tl = T.CutsOf and T.CutsOf(card, "panel") or 0
		tex:ClearAllPoints()
		tex:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -(tonumber(tl) or 0))
		tex:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
	end)
	return t
end

local function nuevoTile(view, def)
	local t = CreateFrame("Button", nil, view)
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
	conTip(t)
	t.def = def
	return t
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

---------------------------------------------------------------------------
-- Tu siguiente paso
---------------------------------------------------------------------------

local function cerrarVentana()
	local O = A.UI and A.UI.Options
	local win = type(O) == "table" and O.frame
	if type(win) == "table" and type(win.Hide) == "function" then win:Hide() end
end

-- Seguir ruta: la ventana de guía a la vista y la flecha encendida; esta
-- ventana se cierra para que se vean.
local function seguirRuta()
	A.Fire("SHOW_FRAME")
	if A.Get("nav.arrow") == false then A.Set("nav.arrow", true) end
	cerrarVentana()
end

-- Ver pasos: la lista de pasos de la ventana de guía (UI.StepList).
local function verPasos()
	A.Fire("SHOW_FRAME")
	A.After(0.1, function()
		local SL = A.UI and A.UI.StepList
		if type(SL) ~= "table" or type(SL.Toggle) ~= "function" then return end
		if type(SL.On) == "function" and SL.On() then return end
		pcall(SL.Toggle, true)
	end)
	cerrarVentana()
end

local function nuevoPaso(view)
	local c = CreateFrame("Frame", nil, view)
	c:SetFrameLevel(view:GetFrameLevel())
	T.Skin(c, "panel")
	c.Bar = franja(c, "accent")
	c.Eyebrow = W.Text(c, "small", "accent")
	c.Eyebrow:SetText(L["Tu siguiente paso"])
	c.Num = W.Chip(c)
	c.Icon = W.Tex(c, "ARTWORK", "icon-goto", "accent")
	c.Icon:SetSize(20, 20)
	c.Titulo = W.Text(c, "display", "text")
	c.Titulo:SetWordWrap(true)
	c.Titulo:SetJustifyV("TOP")
	c.Lineas = {}
	c.DistIcon = W.Tex(c, "ARTWORK", "icon-goto", "accent")
	c.DistIcon:SetSize(14, 14)
	c.Dist = W.Text(c, "body", "text")
	c.Hacia = W.Text(c, "note", "textDim")
	c.Guia = W.Text(c, "small", "textMuted")
	c.Prog = W.ProgressLine(c, 3)
	c.Pct = W.Text(c, "small", "textDim")
	c.Pct:SetJustifyH("RIGHT")
	c.Vacio = W.Text(c, "note", "textDim")
	c.Vacio:SetWordWrap(true)
	c.Vacio:SetSpacing(3)
	c.Vacio:SetJustifyV("TOP")
	c.Seguir = W.Button(c, L["Seguir ruta"], seguirRuta, { primary = true, icon = "icon-goto", height = 30 })
	c.Seguir.psTip = L["Seguir ruta"]
	c.Seguir.psTipLines = { L["Muestra la ventana de guía y la flecha, y cierra esta ventana para que las veas."] }
	c.Pasos = W.Button(c, L["Ver pasos"], verPasos, { icon = "menu", height = 30 })
	c.Pasos.psTip = L["Ver pasos"]
	c.Pasos.psTipLines = { L["Todos los pasos de la guía en la ventana de guía."] }
	c.Cambiar = W.Button(c, L["Cambiar guía"], function() A.Fire("SHOW_PICKER") end, { icon = "guides", height = 30 })
	-- Sin paso que mostrar: un solo botón (elegir una guía, la siguiente, o abrirla).
	c.Primera = W.Button(c, L["Elegir una guía"], function(self)
		if type(self.psAccion) == "function" then self.psAccion() else A.Fire("SHOW_PICKER") end
	end, { primary = true, icon = "guides", height = 30 })
	return c
end

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

-- Rumbo de la flecha en ocho vientos: dn hacia el norte, dw hacia el oeste
-- (yardas del mundo, Nav.TargetOffset).
local RUMBOS = { L["al norte"], L["al noroeste"], L["al oeste"], L["al suroeste"],
	L["al sur"], L["al sureste"], L["al este"], L["al noreste"] }

local function rumbo(dn, dw)
	local grados = math.atan2(dw, dn) * 180 / math.pi -- 0 norte, 90 oeste
	return RUMBOS[floor(((grados + 22.5) % 360) / 45) + 1]
end

-- La línea de la distancia: texto, color y a qué (o nil sin flecha).
local function distancia()
	local Nav = A.Nav
	if type(Nav) ~= "table" or type(Nav.GetTarget) ~= "function" then return nil end
	local t = Nav.GetTarget()
	if type(t) ~= "table" then return nil end
	local label = texto(t.label)
	local Cp = A.Compat
	if type(Cp) == "table" then
		if type(Cp.IsInInstance) == "function" and Cp.IsInInstance() then
			return L["Estás en una instancia: la flecha vuelve al salir."], "textDim", nil
		end
		if type(Cp.IsOnTaxi) == "function" and Cp.IsOnTaxi() then
			return L["En vuelo: la flecha sigue al bajar."], "textDim", label
		end
	end
	local dn, dw
	if type(Nav.TargetOffset) == "function" then
		local ok, a, b = pcall(Nav.TargetOffset)
		if ok then dn, dw = num(a), num(b) end
	end
	if not (dn and dw) then
		local zona = type(Nav.GetTargetZoneName) == "function" and texto(Nav.GetTargetZoneName()) or nil
		return zona and format(L["Lejos de aquí: %s"], zona) or L["Lejos de aquí"], "textDim", label
	end
	local d = math.sqrt(dn * dn + dw * dw)
	local area = tonumber(t.area)
	if area and area > 0 then d = d > area and d - area or 0 end
	if d <= (tonumber(t.r) or 8) then return L["Ya llegaste"], "success", label end
	local txt = type(A.FormatDistance) == "function" and A.FormatDistance(d) or format("%d yd", floor(d + 0.5))
	return txt .. " " .. rumbo(dn, dw), "text", label
end

local function pintarDistancia()
	local c = P.paso
	if not (c and c.psConGuia) then return end
	local txt, color, label = distancia()
	if not txt then
		txt, color, label = L["Este paso no tiene punto en el mapa."], "textMuted", nil
	end
	c.Dist:SetText(txt)
	W.Color(c.Dist, color)
	c.Hacia:SetText(label and label ~= "" and (L["Hacia:"] .. " " .. label) or "")
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
	local inner = w - IZQ - 18
	local cy = 16
	local conGuia = info and not info.fin and info.num ~= nil
	c.psConGuia = conGuia and true or false
	c.Num:SetShown(conGuia and true or false)
	for _, r in ipairs({ c.Icon, c.Titulo, c.DistIcon, c.Dist, c.Hacia, c.Seguir, c.Pasos, c.Cambiar }) do
		r:SetShown(conGuia and true or false)
	end
	c.Vacio:SetShown(not conGuia)
	c.Primera:SetShown(not conGuia)

	c.Eyebrow:ClearAllPoints()
	c.Eyebrow:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ, -cy)
	if conGuia then
		W.SetChip(c.Num, info.total and format(L["Paso %d de %d"], info.num, info.total) or format(L["Paso %d"], info.num), "accent")
		c.Num:ClearAllPoints()
		c.Num:SetPoint("TOPRIGHT", c, "TOPRIGHT", -16, -(cy - 4))
	end
	cy = cy + 24

	if conGuia then
		c.Icon:SetTexture(T.VerbIcon(info.verbo))
		c.Icon:ClearAllPoints()
		c.Icon:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ, -(cy - 1))
		c.Titulo:SetText(info.titulo)
		c.Titulo:SetWidth(max(1, inner - 32))
		c.Titulo:ClearAllPoints()
		c.Titulo:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ + 32, -cy)
		cy = cy + max(22, ceil(c.Titulo:GetStringHeight())) + 8
		for i, m in ipairs(info.metas or {}) do
			local l = lineaPaso(c, i)
			l.Icon:SetTexture(T.VerbIcon(m.t))
			l.Icon:ClearAllPoints()
			l.Icon:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ + 34, -(cy + 1))
			l.Text:SetText(m.texto)
			l.Text:SetWidth(max(1, inner - 54))
			l.Text:ClearAllPoints()
			l.Text:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ + 54, -cy)
			W.Color(l.Text, i == 1 and "text" or "textDim")
			l.Icon:Show()
			l.Text:Show()
			cy = cy + ceil(l.Text:GetStringHeight()) + 6
		end
		cy = cy + 6
		-- La distancia y el rumbo hasta la flecha: se repinta cada segundo.
		c.DistIcon:ClearAllPoints()
		c.DistIcon:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ + 3, -(cy + 1))
		c.Dist:ClearAllPoints()
		c.Dist:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ + 32, -cy)
		c.Hacia:ClearAllPoints()
		c.Hacia:SetPoint("LEFT", c.Dist, "RIGHT", 12, 0)
		c.Hacia:SetPoint("RIGHT", c, "RIGHT", -18, 0)
		pintarDistancia()
		cy = cy + 26
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
		c.Vacio:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ, -cy)
		cy = cy + ceil(c.Vacio:GetStringHeight()) + 14
	end

	-- La guía y su avance, en una línea.
	local conProg = info ~= nil and (info.todos or 0) > 0
	c.Guia:SetShown(info ~= nil)
	c.Prog:SetShown(conProg)
	c.Pct:SetShown(conProg)
	if info then
		c.Guia:SetText(format(L["Guía: %s"], info.guia ~= "" and info.guia or RAYA))
		c.Guia:ClearAllPoints()
		c.Guia:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ, -cy)
		local guiaW = conProg and floor(inner * 0.42) or inner
		c.Guia:SetWidth(max(1, guiaW))
		if conProg then
			local frac = info.hechos / info.todos
			local barX = IZQ + guiaW + 16
			local barW = max(1, w - barX - 18 - 48)
			c.Prog:ClearAllPoints()
			c.Prog:SetPoint("TOPLEFT", c, "TOPLEFT", barX, -(cy + 5))
			c.Prog:SetWidth(barW)
			W.SetProgress(c.Prog, frac, barW)
			c.Pct:SetText(format("%d%%", floor(frac * 100 + 0.5)))
			c.Pct:ClearAllPoints()
			c.Pct:SetPoint("RIGHT", c, "TOPRIGHT", -18, -(cy + 6))
		end
		cy = cy + 26
	end

	-- Los botones.
	if conGuia then
		c.Seguir:ClearAllPoints()
		c.Seguir:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ, -cy)
		c.Pasos:ClearAllPoints()
		c.Pasos:SetPoint("LEFT", c.Seguir, "RIGHT", 8, 0)
		c.Cambiar:ClearAllPoints()
		c.Cambiar:SetPoint("LEFT", c.Pasos, "RIGHT", 8, 0)
		cy = cy + c.Seguir:GetHeight()
	else
		if not info then
			W.SetButtonText(c.Primera, L["Elegir una guía"])
			c.Primera.psAccion = nil
		elseif info.fin then
			W.SetButtonText(c.Primera, L["Elegir la siguiente guía"])
			c.Primera.psAccion = nil
		else
			W.SetButtonText(c.Primera, L["Abrir la guía"])
			c.Primera.psAccion = seguirRuta
		end
		c.Primera:ClearAllPoints()
		c.Primera:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ, -cy)
		cy = cy + c.Primera:GetHeight()
	end
	cy = cy + 18
	c:SetHeight(cy)
	return cy
end

---------------------------------------------------------------------------
-- Alertas: lo urgente de M.Rec, del más grave al menos
---------------------------------------------------------------------------

local COLOR_TIPO = { peligro = "danger", aviso = "warning", info = "accent", exito = "success" }
local PESO_TIPO = { peligro = 1, aviso = 2, info = 3, exito = 4 }

local function alertas()
	local st = R.Estado()
	local lista = {}
	local durAviso = tonumber(N.Get("inicio", "durAviso")) or 30
	local durUrg = tonumber(N.Get("inicio", "durUrgente")) or 10
	local e = st.equipo
	if e.pct and e.pct <= durAviso then
		local pct = floor(e.pct + 0.5)
		local pieza = R.NombrePieza(e.slot) or R.NombreRanura(e.slot)
		local det = pct <= 0 and format(L["%s está rota"], pieza) or format(L["%s al %d%%"], pieza, pct)
		local otras = (e.gastadas or 1) - 1
		if otras > 0 then det = det .. DOT .. (otras == 1 and L["y 1 pieza más"] or format(L["y %d piezas más"], otras)) end
		local urgente = e.pct <= durUrg
		lista[#lista + 1] = { clave = "equipo", tipo = urgente and "peligro" or "aviso", icono = "icon-buy",
			titulo = urgente and L["¡Repara tu equipo!"] or L["Tu equipo se está gastando"], detalle = det,
			boton = L["Llévame a reparar"], fn = function() R.IrA("repair") end }
	end
	local libres, total = st.bolsas.libres, st.bolsas.total
	local umbral = tonumber(N.Get("inicio", "bolsasLibres")) or 4
	if libres and libres <= umbral then
		lista[#lista + 1] = { clave = "bolsas", tipo = libres == 0 and "peligro" or "aviso", icono = "icon-collect",
			titulo = libres == 0 and L["Tus bolsas están llenas"] or L["Tus bolsas están casi llenas"],
			detalle = libres == 1 and L["Te queda 1 espacio"] or format(L["Te quedan %d de %d espacios"], libres, total or 0),
			boton = L["Llévame a un vendedor"], fn = function() R.IrA("vendor") end }
	end
	local en = st.entrenar
	if en.listo and en.n >= (tonumber(N.Get("inicio", "entrenarMin")) or 1) then
		local det = en.n == 1 and L["1 habilidad por aprender"] or format(L["%d habilidades por aprender"], en.n)
		if (en.costo or 0) > 0 then det = det .. DOT .. N.Dinero(en.costo) end
		lista[#lista + 1] = { clave = "entrenar", tipo = "info", icono = "icon-train", titulo = L["Tienes habilidades nuevas"],
			detalle = det, boton = L["Llévame con mi entrenador"], fn = function() R.IrA("class") end }
	end
	local d = st.descanso
	if not d.maximo then
		local pct = floor((d.pct or 0) + 0.5)
		local bajo = tonumber(N.Get("inicio", "descansoBajo")) or 5
		if d.activo then
			lista[#lista + 1] = { clave = "descanso", tipo = "exito", icono = "icon-sethome", titulo = L["Estás descansando"],
				detalle = format(L["XP descansada: %d%% de un nivel"], pct) }
		elseif (d.xp or 0) > 0 and bajo > 0 and (d.pct or 0) <= bajo then
			lista[#lista + 1] = { clave = "descansoBajo", tipo = "info", icono = "icon-sethome", titulo = L["Te queda poca XP descansada"],
				detalle = L["Descansa en una posada o una ciudad para juntar más."] }
		end
	end
	table.sort(lista, function(a, b)
		local pa, pb = PESO_TIPO[a.tipo] or 9, PESO_TIPO[b.tipo] or 9
		if pa ~= pb then return pa < pb end
		return a.clave < b.clave
	end)
	return lista
end

local function firma(lista)
	local t = {}
	for i, a in ipairs(lista) do t[i] = a.clave end
	return table.concat(t, ",")
end

local function filaAlerta(i)
	local f = P.alertaFilas[i]
	if f then return f end
	f = CreateFrame("Frame", nil, P.alertas)
	f:SetHeight(ALERTA_H)
	f.Icon = W.Tex(f, "ARTWORK", "info", "accent")
	f.Icon:SetSize(16, 16)
	f.Icon:SetPoint("LEFT", f, "LEFT", 16, 0)
	f.Titulo = W.Text(f, "body", "text")
	f.Titulo:SetPoint("LEFT", f, "LEFT", 44, 0)
	f.Detalle = W.Text(f, "note", "textDim")
	f.Detalle:SetPoint("LEFT", f.Titulo, "RIGHT", 12, 0)
	f.Rule = W.Divider(f, false, 0.6)
	f.Rule:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	f.Rule:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	f.Boton = W.Button(f, "", function(self) if type(self.psAccion) == "function" then self.psAccion() end end, { height = 26 })
	f.Boton:SetPoint("RIGHT", f, "RIGHT", -12, 0)
	f.Boton:Hide()
	P.alertaFilas[i] = f
	return f
end

local function pintarFilaAlerta(f, a)
	f.Icon:SetTexture(T.Media(a.icono or "info"))
	W.Color(f.Icon, COLOR_TIPO[a.tipo] or "accent")
	f.Titulo:SetText(a.titulo or "")
	W.Color(f.Titulo, a.tipo == "peligro" and "danger" or "text")
	f.Detalle:SetText(a.detalle or "")
	local derecha = 16
	if a.boton then
		W.SetButtonText(f.Boton, a.boton)
		f.Boton.psAccion = a.fn
		f.Boton:Show()
		derecha = f.Boton:GetWidth() + 24
	else
		f.Boton.psAccion = nil
		f.Boton:Hide()
	end
	f.Detalle:SetPoint("RIGHT", f, "RIGHT", -derecha, 0)
end

local TODO_BIEN = { clave = "", tipo = "exito", icono = "check" }

local function pintarAlertas()
	local lista = alertas()
	if firma(lista) ~= P.firmaAlertas then
		relayout()
		return
	end
	if #lista == 0 then
		local f = filaAlerta(1)
		TODO_BIEN.titulo = L["Todo en orden"]
		TODO_BIEN.detalle = L["Tu equipo, tus bolsas y tu entrenamiento están al día."]
		pintarFilaAlerta(f, TODO_BIEN)
		return
	end
	for i, a in ipairs(lista) do pintarFilaAlerta(filaAlerta(i), a) end
end

function P.LayoutAlertas(w, x, y)
	local lista = alertas()
	P.firmaAlertas = firma(lista)
	local h = P.hAlertas
	W.SetSection(h, L["Alertas"], #lista > 0 and #lista or nil)
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
	h:SetWidth(w)
	h:Show()
	y = y + W.PLAIN_SECTION_H
	local n = max(1, #lista)
	local panel = P.alertas
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
	panel:SetSize(w, n * ALERTA_H)
	for _, f in ipairs(P.alertaFilas) do f:Hide() end
	for i = 1, n do
		local f = filaAlerta(i)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(i - 1) * ALERTA_H)
		f:SetWidth(w)
		f.Rule:SetShown(i < n)
		f:Show()
	end
	pintarAlertas()
	return y + n * ALERTA_H
end

---------------------------------------------------------------------------
-- Para tu <clase>
---------------------------------------------------------------------------

local ROLES = { cura = L["Sanador"], tanque = L["Tanque"], dano = L["Daño"] }

local function nuevaMini(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(MINI_H)
	T.Skin(b, "tile")
	b.Icono = b:CreateTexture(nil, "ARTWORK")
	b.Icono:SetSize(30, 30)
	b.Icono:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -14)
	b.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.Glifo = W.Tex(b, "ARTWORK", "bolt", "accent")
	b.Glifo:SetSize(18, 18)
	b.Glifo:SetPoint("CENTER", b.Icono, "CENTER", 0, 0)
	b.Titulo = W.Text(b, "small", "textMuted")
	b.Titulo:SetPoint("TOPLEFT", b, "TOPLEFT", 54, -14)
	b.Titulo:SetPoint("RIGHT", b, "RIGHT", -26, 0)
	b.Flecha = W.Tex(b, "ARTWORK", "chevron-right", "textMuted")
	b.Flecha:SetSize(10, 10)
	b.Flecha:SetPoint("TOPRIGHT", b, "TOPRIGHT", -12, -16)
	b.Valor = W.Text(b, "title", "text")
	b.Valor:SetPoint("TOPLEFT", b, "TOPLEFT", 54, -31)
	b.Valor:SetPoint("RIGHT", b, "RIGHT", -12, 0)
	b.Detalle = W.Text(b, "small", "textDim")
	b.Detalle:SetPoint("TOPLEFT", b, "TOPLEFT", 54, -54)
	b.Detalle:SetPoint("RIGHT", b, "RIGHT", -12, 0)
	b:SetScript("OnClick", function(self) if self.psAbrir then N.Abrir(self.psAbrir) end end)
	b:SetScript("OnEnter", function(self)
		W.Color(self.Flecha, self.psAbrir and "accent" or "textMuted")
		W.SimpleTip(self)
	end)
	b:SetScript("OnLeave", function(self)
		W.Color(self.Flecha, "textMuted")
		W.HideTip(self)
	end)
	return b
end

local function pintarMini(b)
	local def = b.def
	if not def then return end
	local r = K.Leer(def)
	local titulo = K.Titulo(def)
	b.Titulo:SetText(titulo)
	b.Valor:SetText(r.valor or RAYA)
	W.Color(b.Valor, r.color or "text")
	b.Detalle:SetText(r.detalle or "")
	if r.textura then
		b.Icono:SetTexture(r.textura)
		b.Icono:Show()
		b.Glifo:Hide()
	else
		b.Icono:Hide()
		b.Glifo:SetTexture(T.Media(def.glifo or "bolt"))
		b.Glifo:Show()
	end
	local destino = K.Destino(def)
	b.psAbrir = destino
	b.Flecha:SetShown(destino ~= nil)
	b.psTip = titulo
	local lines = {}
	if r.valor then lines[#lines + 1] = { r.valor, T.Color(r.color or "text") } end
	if r.detalle and r.detalle ~= "" then lines[#lines + 1] = r.detalle end
	for _, l in ipairs(r.tip or {}) do lines[#lines + 1] = l end
	local spec = destino and N.ModuloPorId(destino)
	if spec then lines[#lines + 1] = format(L["Clic: abre %s."], tostring(spec.nombre or destino)) end
	b.psTipLines = lines
end

local function nombreClase()
	local n
	if type(T.Clase) == "function" then
		local ok, c = pcall(T.Clase)
		n = ok and type(c) == "table" and texto(c.nombre) or nil
	end
	if not n and UnitClass then n = texto((UnitClass("player"))) end
	n = n or ""
	-- "Para tu guerrero": en minúscula en español y en inglés; en otros
	-- idiomas (los sustantivos del alemán) se queda como lo dice el cliente.
	local loc = N.locale
	local b = n:byte(1)
	if b and b >= 65 and b <= 90 and (N.espanol or loc == "enUS" or loc == "enGB") then n = string.char(b + 32) .. n:sub(2) end
	return n
end

local function nuevaClase(view)
	local c = CreateFrame("Frame", nil, view)
	c:SetFrameLevel(view:GetFrameLevel())
	T.Skin(c, "panel")
	c.Franja = franja(c, "class")
	c.Titulo = W.Text(c, "title", "classText")
	c.Rol = W.Chip(c)
	c.Minis = {}
	return c
end

function P.LayoutClase(w, x, y)
	local c = P.clase
	local defs = K.Tarjetas()
	for _, b in ipairs(c.Minis) do b:Hide() end
	if #defs == 0 then
		c:Hide()
		return y
	end
	c:ClearAllPoints()
	c:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
	c:SetWidth(w)
	c:Show()
	local cy = 16
	local rol, rama = K.Rol()
	c.Titulo:SetText(format(L["Para tu %s"], nombreClase()))
	c.Titulo:ClearAllPoints()
	c.Titulo:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ, -cy)
	local chip = ROLES[rol] or ""
	if rama and rama ~= "" then chip = rama .. DOT .. chip end
	W.SetChip(c.Rol, chip, "class")
	c.Rol:ClearAllPoints()
	c.Rol:SetPoint("TOPRIGHT", c, "TOPRIGHT", -16, -(cy - 2))
	cy = cy + 30
	local n = #defs
	local area = w - IZQ - 16
	local mw = (area - GAP * (n - 1)) / n
	for i, def in ipairs(defs) do
		local b = c.Minis[i]
		if not b then
			b = nuevaMini(c)
			c.Minis[i] = b
		end
		b.def = def
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", c, "TOPLEFT", IZQ + (i - 1) * (mw + GAP), -cy)
		b:SetSize(mw, MINI_H)
		b:Show()
		pintarMini(b)
	end
	cy = cy + MINI_H + 16
	c:SetHeight(cy)
	return y + cy + BLOQUE
end

local function pintarClase()
	local c = P.clase
	if not (c and c:IsShown()) then return end
	for _, b in ipairs(c.Minis) do
		if b:IsShown() then pintarMini(b) end
	end
end

---------------------------------------------------------------------------
-- La fila de números
---------------------------------------------------------------------------

-- El oro de hoy: las sesiones del diario que empezaron hoy y la de ahora.
local function mismoDia(a, b) return a.year == b.year and a.yday == b.yday end

local function oroDeHoy(e)
	local hoy = date("*t")
	local neto, ganado, gastado = e.oro or 0, e.ganado or 0, e.gastado or 0
	for _, s in ipairs(S.Sesiones()) do
		local t = date("*t", tonumber(s.inicio) or 0)
		if mismoDia(t, hoy) then
			neto = neto + (tonumber(s.oro) or 0)
			ganado = ganado + (tonumber(s.ganado) or 0)
			gastado = gastado + (tonumber(s.gastado) or 0)
		end
	end
	return neto, ganado, gastado
end

-- Los de tu hermandad conectados, sin contarte: n, total, nombre de la
-- hermandad; nil fuera de una hermandad. La lista la pide el módulo La
-- Jauría; aquí se pide a lo más una vez por minuto mientras la página se ve.
local pedidaEn = -1000
local function lobos()
	local ok, en = pcall(function() return IsInGuild and IsInGuild() end)
	if not ok or not en or (issecretvalue and issecretvalue(en)) then return nil end
	if not GetNumGuildMembers then return nil end
	local t = GetTime and GetTime() or 0
	if t - pedidaEn > 60 and C_GuildInfo and C_GuildInfo.GuildRoster then
		pedidaEn = t
		pcall(C_GuildInfo.GuildRoster)
	end
	local ok2, total, conectados = pcall(GetNumGuildMembers)
	total, conectados = ok2 and num(total) or nil, ok2 and num(conectados) or nil
	if not conectados then return nil end
	local nombre
	if GetGuildInfo then
		local ok3, g = pcall(GetGuildInfo, "player")
		nombre = ok3 and texto(g) or nil
	end
	return max(0, conectados - 1), total, nombre
end

local function esLaJauria(nombre)
	if type(nombre) ~= "string" then return false end
	-- La í primero: con un locale de 8 bits, lower() también cambia los bytes
	-- de una letra UTF-8 y la rompe.
	local n = nombre:gsub("\195\173", "i"):gsub("\195\141", "I")
	return n:lower() == "la jauria"
end

local function pintarNumeros(e)
	for _, t in ipairs(P.tiles) do
		local k = t.def.clave
		local v, color, lines = RAYA, "text", nil
		if k == "ritmo" then
			if e.maximo then
				v = RAYA
				lines = { L["Nivel máximo"] }
			else
				if e.ritmo and e.ritmo > 0 then v = miles(e.ritmo) end
				lines = { L["Tu ritmo de los últimos 15 minutos, con el contador de XP de Alfa."],
					format(L["Promedio de la sesión: %s XP por hora."], miles(e.prom)),
					format(L["XP ganada en la sesión: %s"], miles(e.xp)) }
			end
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
			local neto, ganado, gastado = oroDeHoy(e)
			v = (neto > 0 and "+" or "") .. N.Dinero(neto, true)
			lines = { { left = L["Ganado"], right = N.Dinero(ganado) }, { left = L["Gastado"], right = N.Dinero(gastado) },
				L["Suma tus sesiones de hoy con este personaje."] }
		elseif k == "lobos" then
			local n, total, nombre = lobos()
			local jauria = esLaJauria(nombre)
			t.Label:SetText((nombre and not jauria) and L["Tu hermandad conectada"] or L["Lobos conectados"])
			if n then
				v = tostring(n)
				color = n > 0 and "accent" or "text"
				lines = { format(L["%d de %d miembros de %s conectados, sin contarte."], n, total or n, nombre or L["tu hermandad"]) }
			else
				lines = { L["Todavía no estás en una hermandad. En la página La Jauría ves cómo unirte a la manada."] }
			end
			if t.psAbrir then lines[#lines + 1] = L["Clic: abre La Jauría."] end
		end
		t.Value:SetText(v)
		W.Color(t.Value, color)
		t.psTipLines = lines
	end
end

function P.LayoutNumeros(w, x, y)
	local cols = w >= 520 and 4 or 2
	local tw = (w - GAP * (cols - 1)) / cols
	for i, t in ipairs(P.tiles) do
		local c, r = (i - 1) % cols, floor((i - 1) / cols)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", P.view, "TOPLEFT", x + c * (tw + GAP), -(y + r * (TILE_H + GAP)))
		t:SetSize(tw, TILE_H)
		if t.def.clave == "lobos" then t.psAbrir = N.ModuloPorId("manada") and "manada" or nil end
	end
	return y + ceil(#P.tiles / cols) * (TILE_H + GAP) - GAP
end

---------------------------------------------------------------------------
-- Bloques plegables
---------------------------------------------------------------------------

local function abierto(clave) return N.Get("inicio", "abrir" .. clave) and true or false end

local function nuevoPlegable(view, clave, titulo)
	local b = CreateFrame("Button", nil, view)
	b:SetHeight(PLEG_H)
	b.clave = clave
	b.Chevron = W.Tex(b, "ARTWORK", "chevron-down", "textMuted")
	b.Chevron:SetSize(12, 12)
	b.Chevron:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 11)
	b.Text = W.Text(b, "heading", "text")
	b.Text:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 20, 10)
	b.Text:SetText(titulo)
	b.Count = W.Text(b, "number", "textMuted")
	b.Count:SetJustifyH("RIGHT")
	b.Count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 10)
	b.Rule = W.Divider(b)
	b.Rule:SetPoint("LEFT", b.Text, "RIGHT", 12, 0)
	b.Rule:SetPoint("RIGHT", b, "RIGHT", 0, 0)
	b.psTip = titulo
	b:SetScript("OnClick", function(self)
		N.Set("inicio", "abrir" .. self.clave, not abierto(self.clave))
		relayout()
	end)
	b:SetScript("OnEnter", function(self)
		W.Color(self.Chevron, "accent")
		self.psTipLines = { abierto(self.clave) and L["Clic para plegar."] or L["Clic para desplegar."] }
		W.SimpleTip(self)
	end)
	b:SetScript("OnLeave", function(self)
		W.Color(self.Chevron, "textMuted")
		W.HideTip(self)
	end)
	return b
end

-- La cabecera en y; -> nueva y, y si el bloque está abierto.
local function plegable(b, y, w, cuenta)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", P.view, "TOPLEFT", W.SHELL.pad, -y)
	b:SetWidth(w)
	b:Show()
	local open = abierto(b.clave)
	b.Chevron:SetTexture(T.Media(open and "chevron-down" or "chevron-right"))
	if cuenta then
		b.Count:SetText(cuenta)
		b.Count:Show()
		b.Rule:SetPoint("RIGHT", b.Count, "LEFT", -12, 0)
	else
		b.Count:Hide()
		b.Rule:SetPoint("RIGHT", b, "RIGHT", 0, 0)
	end
	return y + PLEG_H + (open and 6 or 0), open
end

---------------------------------------------------------------------------
-- Revisión rápida
---------------------------------------------------------------------------

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

function P.LayoutEstado(w, x, y, open)
	local panel = P.estado
	panel:SetShown(open)
	if not open then return y end
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
	return y + #P.filas * FILA_H
end

local function pintarFila(f, txt, color, boton)
	f.Estado:SetText(txt or RAYA)
	W.Color(f.Estado, color or "textDim")
	if f.Boton then f.Boton:SetShown(boton and true or false) end
end

local function pintarEstado()
	if not (P.estado and P.estado:IsShown()) then return end
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

function P.LayoutAccesos(w, x, y, open)
	local lista = modulos()
	for _, t in pairs(P.accesos) do t:Hide() end
	P.sinAccesos:Hide()
	if not open then return y end
	if #lista == 0 then
		P.sinAccesos:SetWidth(w)
		P.sinAccesos:ClearAllPoints()
		P.sinAccesos:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
		P.sinAccesos:Show()
		return y + ceil(P.sinAccesos:GetStringHeight()) + 4
	end
	-- Compactos: tres por fila, solo el nombre; lo que hace va en su ayuda.
	local cols = w >= 600 and 3 or 2
	local cw = (w - GAP * (cols - 1)) / cols
	local top = y
	for i = 1, #lista, cols do
		local fila, h = {}, 0
		for k = i, min(i + cols - 1, #lista) do
			local spec = lista[k]
			local t = P.accesos[spec.id]
			if not t then
				t = W.ActionTile(P.view, spec.icono or "gear", tostring(spec.nombre or spec.id), "", function() N.Abrir(spec.id) end)
				t.psTip = tostring(spec.nombre or spec.id)
				t.psTipLines = (spec.subtitulo and spec.subtitulo ~= "") and { tostring(spec.subtitulo) } or nil
				t:SetScript("OnEnter", W.SimpleTip)
				t:SetScript("OnLeave", W.HideTip)
				P.accesos[spec.id] = t
			end
			fila[#fila + 1] = t
		end
		for col, t in ipairs(fila) do
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", P.view, "TOPLEFT", x + (col - 1) * (cw + GAP), -y)
			t:Show()
			h = max(h, W.LayoutTile(t, cw))
		end
		for _, t in ipairs(fila) do t:SetHeight(h) end
		y = y + h + GAP
	end
	return top + (y - top - GAP)
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

local function chipBoton(parent, m)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(W.CHIP_H)
	b.Chip = W.Chip(b)
	b.Chip:SetAllPoints(b)
	b.psMetrica = m
	b:SetScript("OnClick", function(self) N.Set("inicio", "grafica", self.psMetrica.clave) end)
	return b
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

	local areaTop, areaBottom = 40, 28
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

-- Tu sesión de ahora, en una línea: "Ahora | 1 h 20 min · +12,340 XP · ...".
local function pintarSesion()
	local f = P.sesion
	if not (f and f:IsShown()) then return end
	local e = S.Estado()
	f.Texto:SetText(S.Texto(e))
	f.Cuando:SetText(format(L["Empezó %s"], S.Cuando(e.inicio)))
end

function P.LayoutDiario(w, x, y, open)
	local g = P.grafica
	local pasadas = S.Sesiones()
	P.sesion:SetShown(open)
	g:SetShown(open)
	for _, f in ipairs(P.listaFilas) do f:Hide() end
	P.lista:Hide()
	P.sinDiario:Hide()
	if not open then return y end

	local f = P.sesion
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
	f:SetSize(w, SESION_H)
	local cw = W.SetChip(f.Chip, L["Ahora"], "accent")
	pintarSesion()
	f.Texto:SetPoint("LEFT", f, "LEFT", 14 + cw + 10, 0)
	f.Texto:SetPoint("RIGHT", f, "RIGHT", -(ceil(W.TextWidth(f.Cuando)) + 32), 0)
	y = y + SESION_H + GAP

	g:ClearAllPoints()
	g:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
	g:SetSize(w, CHART_H)
	dibujarGrafica(w)
	y = y + CHART_H + GAP

	-- La lista: las últimas sesiones, la más nueva arriba.
	local n = min(LISTA, #pasadas)
	P.lista:SetShown(n > 0)
	P.sinDiario:SetShown(n == 0)
	if n == 0 then
		P.sinDiario:SetWidth(w)
		P.sinDiario:ClearAllPoints()
		P.sinDiario:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
		return y + ceil(P.sinDiario:GetStringHeight()) + 4
	end
	P.lista:ClearAllPoints()
	P.lista:SetPoint("TOPLEFT", P.view, "TOPLEFT", x, -y)
	P.lista:SetSize(w, n * LISTA_H)
	for k = 1, n do
		local s = pasadas[#pasadas - k + 1]
		local fl = filaLista(k)
		fl:ClearAllPoints()
		fl:SetPoint("TOPLEFT", P.lista, "TOPLEFT", 0, -(k - 1) * LISTA_H)
		fl:SetWidth(w)
		fl.Fecha:SetText(S.Cuando(s.inicio))
		fl.Dur:SetText(N.Duracion(s.dur or 0))
		fl.Resumen:SetText(resumenCorto(s))
		fl.Resumen:SetWidth(max(1, w * 0.55))
		fl.psSesion = s
		fl.Rule:SetShown(k < n)
		fl:Show()
	end
	return y + n * LISTA_H
end

---------------------------------------------------------------------------
-- Ajustes de los recordatorios
---------------------------------------------------------------------------

function P.LayoutAjustes(view, w, x, y, open)
	for _, wd in pairs(P.cache) do wd:Hide() end
	for i = 1, #GRUPOS do
		P.hGrupos[i]:Hide()
		P.paneles[i]:Hide()
	end
	P.sinAjustes:Hide()
	if not open then return y end
	local O = A.UI and A.UI.Options
	if type(O) ~= "table" or type(O.Rows) ~= "function" then
		P.sinAjustes:SetWidth(w)
		P.sinAjustes:ClearAllPoints()
		P.sinAjustes:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		P.sinAjustes:Show()
		return y + ceil(P.sinAjustes:GetStringHeight()) + 8
	end
	for i, grupo in ipairs(GRUPOS) do
		local h, panel = P.hGrupos[i], P.paneles[i]
		local lista = disponibles(grupo[2])
		if #lista > 0 then
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
-- La página
---------------------------------------------------------------------------

local function construir(view)
	P.view = view
	P.cache = {}

	P.paso = nuevoPaso(view)

	P.hAlertas = W.SectionHeader(view, { plain = true })
	P.alertas = W.RowPanel(view)
	P.alertaFilas = {}

	P.clase = nuevaClase(view)

	P.tiles = {}
	for i, def in ipairs(NUMEROS) do
		local t = nuevoTile(view, def)
		if def.clave == "lobos" then
			t.Hover = W.Hover(t, 0.6)
			t:SetScript("OnClick", function(self) if self.psAbrir then N.Abrir(self.psAbrir) end end)
		end
		P.tiles[i] = t
	end

	-- Diario
	P.pDiario = nuevoPlegable(view, "Diario", L["Diario"])
	local f = W.RowPanel(view)
	f.Chip = W.Chip(f)
	f.Chip:SetPoint("LEFT", f, "LEFT", 14, 0)
	f.Texto = W.Text(f, "note", "text")
	f.Cuando = W.Text(f, "small", "textMuted")
	f.Cuando:SetJustifyH("RIGHT")
	f.Cuando:SetPoint("RIGHT", f, "RIGHT", -14, 0)
	f.Cuando:SetText(format(L["Empezó %s"], S.Cuando()))
	P.sesion = f
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

	-- Revisión rápida
	P.pRevision = nuevoPlegable(view, "Revision", L["Revisión rápida"])
	P.estado = W.RowPanel(view)
	P.filas = {}
	for i, def in ipairs(ESTADOS) do P.filas[i] = nuevaFila(P.estado, def) end

	-- Accesos rápidos
	P.pAccesos = nuevoPlegable(view, "Accesos", L["Accesos rápidos"])
	P.accesos = {}
	P.sinAccesos = W.Text(view, "note", "textMuted")
	P.sinAccesos:SetWordWrap(true)
	P.sinAccesos:SetText(L["Aquí aparecerán los demás módulos de Alfa (bolsas, rutas, mundo y más) en cuanto estén instalados."])

	-- Recordatorios
	P.pAjustes = nuevoPlegable(view, "Ajustes", L["Recordatorios"])
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

function P.Layout(view)
	local w = N.AnchoPagina()
	local x = W.SHELL.pad
	local y = 12
	R.Leer()

	y = y + P.LayoutPaso(w, x, y) + BLOQUE
	y = P.LayoutAlertas(w, x, y) + BLOQUE
	y = P.LayoutClase(w, x, y)
	y = P.LayoutNumeros(w, x, y) + 8

	local open
	local n = #S.Sesiones()
	y, open = plegable(P.pDiario, y, w, n > 0 and n or nil)
	y = P.LayoutDiario(w, x, y, open) + (open and 8 or 0)

	y, open = plegable(P.pRevision, y, w)
	y = P.LayoutEstado(w, x, y, open) + (open and 8 or 0)

	local mods = modulos()
	y, open = plegable(P.pAccesos, y, w, #mods > 0 and #mods or nil)
	y = P.LayoutAccesos(w, x, y, open) + (open and 8 or 0)

	y, open = plegable(P.pAjustes, y, w)
	y = P.LayoutAjustes(view, w, x, y, open)

	-- La ventana crea la vista ya visible: su primer OnShow no llega, así que
	-- el temporizador también arranca aquí.
	if view:IsVisible() and not P.ticker then
		P.AlMostrar()
	else
		P.Pintar()
	end
	return y + 24
end

local tic = 0
function P.Pintar()
	local view = P.view
	if not (view and view:IsVisible()) or P.acomodando then return end
	local e = S.Estado()
	pintarDistancia()
	pintarAlertas()
	pintarClase()
	pintarNumeros(e)
	pintarSesion()
	pintarEstado()
	-- La barra de ahora crece con la sesión: cada 10 segundos.
	tic = tic + 1
	if tic >= 10 then
		tic = 0
		if P.grafica:IsShown() then dibujarGrafica(P.grafica:GetWidth()) end
	end
end

relayout = function()
	local view = P.view
	if not (view and view:IsVisible() and view.Refresh) or P.acomodando then return end
	P.acomodando = true
	local ok, h = pcall(view.Refresh)
	P.acomodando = false
	if not ok then
		if geterrorhandler then geterrorhandler()(h) end
		return
	end
	view:SetHeight(h)
	local O = A.UI and A.UI.Options
	local win = type(O) == "table" and O.frame
	if type(win) == "table" then W.ShellBody(win, h) end
	P.Pintar()
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
	K.Sucio()
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
for _, msg in ipairs({ "STEP_CHANGED", "STEP_UPDATED", "GUIDE_CHANGED", "GUIDE_COMPLETED", "TABS_CHANGED", "INICIO_DIARIO" }) do
	A.On(msg, relayoutPronto)
end
-- Otra rama (o nivel) cambia el rol y las tarjetas de la clase; lo demás del
-- equipo solo se repinta (M.Clase cuenta otra vez las mejoras).
A.On("GEAR_UPDATED", function(what)
	if what == "spec" or what == "level" then relayoutPronto() end
end)
A.On("SETTING_CHANGED", function(path)
	if path == "inicio.grafica" or path == "curacion.activo" or (type(path) == "string" and path:find("^gear%.spec")) then relayoutPronto() end
end)
-- Los talentos cambian la rama, y con ella el rol y las tarjetas de la clase.
A.RegisterEvent("PLAYER_TALENT_UPDATE", relayoutPronto)
A.RegisterEvent("TRAIT_CONFIG_UPDATED", relayoutPronto)

---------------------------------------------------------------------------
-- El módulo
---------------------------------------------------------------------------

N.Modulo({
	id = "inicio", nombre = L["Hoy"], icono = "house", orden = 5, seccion = "hoy",
	subtitulo = L["Tu siguiente paso, lo urgente y lo de tu clase, de un vistazo."],
	comando = "inicio",
	ajustes = AJUSTES,
	controles = CONTROLES,
	construir = construir,
})
