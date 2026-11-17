-- Alfa - Inicio: la página Hoy, la portada de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- Hecha con el Kit (docs/KIT.md, K.Tablero). De arriba abajo, y cada pieza
-- solo si tiene algo útil o una acción (lo vacío no se muestra):
--   1. ¿Qué hacemos hoy?: el título grande y los cuatro caminos (Subir de
--      nivel, Profesiones, Hacer oro, Mazmorras). Cada uno abre el asistente
--      de la ruta (AlfaRuta.Asistente(camino)); sin él, la página Rutas (o
--      Mazmorras). En el nivel máximo, subir de nivel no sale.
--   2. Tu siguiente paso (la tarjeta grande): el paso vivo de tu guía, sus
--      metas, la distancia y el rumbo hasta la flecha, el avance de la guía,
--      Seguir y Ver pasos. Sin guía no sale: los caminos de arriba la eligen.
--      Al terminar una guía: elegir qué sigue.
--   3. Liberar misiones y Recoger misiones a un clic (AlfaRuta.Liberar() y
--      AlfaRuta.Recoger(), si la ruta los tiene; Liberar, si tienes misiones).
--   4. Alertas: equipo gastado, bolsas casi llenas, habilidades por
--      entrenar, tu buff y, si curas, preparar tus marcos de curación.
--   5. Para tu <clase>: el talento que toca (AlfaBuilds.SiguienteTalento) y
--      tres tarjetas de tu clase (M.Clase), cada una abre su módulo.
--   6. Hoy en números: XP por hora, para subir, oro de hoy, esta sesión.
--   7. Abajo y compacto: la revisión rápida en una fila, tu diario (lo de
--      ahora; las sesiones pasadas al pedirlas), los accesos a los módulos y
--      los ajustes de tus avisos (plegados).
-- Mientras la página se ve, los números, la distancia y la clase se
-- repintan una vez por segundo (un temporizador que se apaga al ocultarla);
-- lo demás se acomoda solo cuando algo cambia.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local S, R, Aviso, CL = M.Sesion, M.Rec, M.Aviso, M.Clase
local num, texto, miles = M.num, M.texto, M.miles

local floor, max, min, format = math.floor, math.max, math.min, string.format
local ipairs, pairs, type, tostring, tonumber, pcall = ipairs, pairs, type, tostring, tonumber, pcall
local ESP = K.ESP

local P = {}
M.Pagina = P

local DOT = "  \194\183  "
local RAYA = "\226\128\148"
local SESIONES = 4 -- sesiones pasadas al abrir el diario

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
	-- Lo plegable de abajo: el diario completo y los ajustes de los avisos.
	verDiario = false, verAjustes = false,
}

local function apagado(clave) return function() return not N.Get("inicio", clave) end end
local function porc(v) return format("%d%%", v) end

-- Los controles del motor (la búsqueda de la ventana de Alfa los encuentra);
-- en la página se dibujan con el Kit (grupos, abajo).
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

local CONTROLES = {
	C.recDurabilidad, C.durAviso, C.durUrgente, C.recBolsas, C.bolsasLibres, C.recEntrenar, C.entrenarMin,
	C.recBuff, C.buffCada, C.buffQueda, C.recDescanso, C.descansoBajo,
	C.resumen, C.segAviso, C.sonido, C.diarioMax, C.probar, C.lugar, C.borrar,
}

---------------------------------------------------------------------------
-- Ayudas
---------------------------------------------------------------------------

-- Una función del contrato de la ruta (área A1), si existe.
local function deRuta(nombre)
	local R0 = rawget(_G, "AlfaRuta")
	local fn = type(R0) == "table" and R0[nombre]
	return type(fn) == "function" and fn or nil
end

local function hay(id) return N.ModuloPorId(id) ~= nil end

-- Los colores que da M.Clase (los del motor) en tokens del Kit.
local COLOR = { success = "exito", warning = "aviso", danger = "peligro", textMuted = "textoTenue",
	textDim = "textoSuave", text = "texto", accent = "acento" }
local TONO = { exito = "exito", aviso = "aviso", peligro = "peligro", textoTenue = "neutro", acento = "acento" }

local function maximo()
	local lv, mx = num(UnitLevel and UnitLevel("player")), num(GetMaxPlayerLevel and GetMaxPlayerLevel())
	return lv ~= nil and mx ~= nil and lv >= mx
end

-- Una tarjeta compacta que lleva un ícono del juego (hechizo u objeto): sin
-- teñir y recortado; el valor con su color.
local function retocar(card, d)
	if not card then return end
	if d.textura then
		card.Icono:SetTexture(d.textura)
		card.Icono.alfaColor = nil
		card.Icono:SetVertexColor(1, 1, 1, 1)
		card.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		card.Icono:SetSize(22, 22)
	else
		card.Icono:SetTexCoord(0, 1, 0, 1)
		card.Icono:SetSize(16, 16)
	end
	K.ColorTexto(card.Valor, d.colorValor or "texto")
end

local function llenar(rejilla, datos)
	rejilla:Llenar(datos)
	for i, d in ipairs(datos) do
		if d.variante == "compacta" then retocar(rejilla.pool[i], d) end
	end
end

local function cerrarVentana()
	local O = A.UI and A.UI.Options
	local win = type(O) == "table" and O.frame
	if type(win) == "table" and type(win.Hide) == "function" then win:Hide() end
end

---------------------------------------------------------------------------
-- 1. ¿Qué hacemos hoy?
---------------------------------------------------------------------------

local CAMINOS = {
	{ camino = "nivel", icono = "ic-nivel", titulo = L["Subir de nivel"], texto = L["La ruta más rápida desde tu nivel, misión por misión."] },
	{ camino = "profesiones", icono = "ic-oficios", titulo = L["Profesiones"], texto = L["Sube tus oficios con lo que tienes cerca."] },
	{ camino = "oro", icono = "ic-oro", titulo = L["Hacer oro"], texto = L["Qué recolectar, fabricar o vender hoy."] },
	{ camino = "mazmorras", icono = "ic-mazmorra", titulo = L["Mazmorras"], texto = L["La que te toca, con sus misiones y su botín."] },
}

local function abrirCamino(camino)
	local fn = deRuta("Asistente")
	if fn then
		K.Llamar(fn, camino)
		return
	end
	if camino == "mazmorras" and hay("mazmorras") then N.Abrir("mazmorras") return end
	if hay("rutas") then N.Abrir("rutas") return end
	A.Fire("SHOW_PICKER")
end

local function caminos()
	local lista = {}
	local tope = maximo()
	for _, c in ipairs(CAMINOS) do
		if not (tope and c.camino == "nivel") then
			local camino = c.camino
			local abrir = function() abrirCamino(camino) end
			lista[#lista + 1] = { variante = "normal", icono = c.icono, titulo = c.titulo, texto = c.texto,
				alClic = abrir, secundaria = { texto = L["Empezar"], alClic = abrir } }
		end
	end
	return lista
end

local function nuevaPortada(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Titulo = K.Texto(b, "portada", "texto")
	b.Sub = K.Texto(b, "nota", "textoSuave")
	b.Rejilla = K.Rejilla(b, { min = 188, gap = ESP.m })
	K.Escribir(b.Titulo, L["¿Qué hacemos hoy?"])
	K.Escribir(b.Sub, L["Elige un camino: Alfa arma tu plan y te guía paso a paso."])
	function b:Llenar() self.Rejilla:Llenar(caminos()) end
	function b:Acomodar(ancho)
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		local y = K.Parrafo(self.Titulo, ancho, 2)
		y = y + 4
		self.Sub:ClearAllPoints()
		self.Sub:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		y = y + K.Parrafo(self.Sub, ancho, 2) + ESP.base
		self.Rejilla:ClearAllPoints()
		self.Rejilla:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		y = y + self.Rejilla:Acomodar(ancho)
		self:SetSize(ancho, y)
		return y
	end
	return b
end

---------------------------------------------------------------------------
-- 2. Tu siguiente paso
---------------------------------------------------------------------------

-- Seguir: tu guía y la flecha a la vista; la ventana de Alfa se cierra para que se vean.
local function seguirRuta()
	A.Fire("SHOW_FRAME")
	if A.Get("nav.arrow") == false then A.Set("nav.arrow", true) end
	cerrarVentana()
end

-- Ver pasos: la lista de pasos de tu guía.
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
	info.titulo = (info.titulo and info.titulo ~= "" and info.titulo) or texto(v.title) or ""
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

local VERBO = {
	["goto"] = "ic-flecha", accept = "ic-misiones", turnin = "ic-exito", complete = "ic-exito", kill = "ic-raros",
	collect = "ic-bolsas", loot = "ic-bolsas", talk = "ic-personajes", use = "ic-seguir", fly = "ic-mapa",
	taxi = "ic-mapa", hearth = "ic-hoy", train = "ic-nivel", level = "ic-nivel", note = "ic-info", fish = "ic-pesca",
	buy = "ic-comercio",
}

-- Rumbo de la flecha en ocho vientos: dn hacia el norte, dw hacia el oeste.
local RUMBOS = { L["al norte"], L["al noroeste"], L["al oeste"], L["al suroeste"],
	L["al sur"], L["al sureste"], L["al este"], L["al noreste"] }

local function rumbo(dn, dw)
	local grados = math.atan2(dw, dn) * 180 / math.pi -- 0 norte, 90 oeste
	return RUMBOS[floor(((grados + 22.5) % 360) / 45) + 1]
end

-- La distancia hasta la flecha: texto, tono y a qué (o nil sin flecha).
local function distancia()
	local Nav = A.Nav
	if type(Nav) ~= "table" or type(Nav.GetTarget) ~= "function" then return nil end
	local t = Nav.GetTarget()
	if type(t) ~= "table" then return nil end
	local label = texto(t.label)
	local Cp = A.Compat
	if type(Cp) == "table" then
		if type(Cp.IsInInstance) == "function" and Cp.IsInInstance() then
			return L["En una instancia: la flecha vuelve al salir"], "neutro", nil
		end
		if type(Cp.IsOnTaxi) == "function" and Cp.IsOnTaxi() then
			return L["En vuelo: la flecha sigue al bajar"], "neutro", label
		end
	end
	local dn, dw
	if type(Nav.TargetOffset) == "function" then
		local ok, a, b = pcall(Nav.TargetOffset)
		if ok then dn, dw = num(a), num(b) end
	end
	if not (dn and dw) then
		local zona = type(Nav.GetTargetZoneName) == "function" and texto(Nav.GetTargetZoneName()) or nil
		return zona and format(L["Lejos de aquí: %s"], zona) or L["Lejos de aquí"], "neutro", label
	end
	local d = math.sqrt(dn * dn + dw * dw)
	local area = tonumber(t.area)
	if area and area > 0 then d = d > area and d - area or 0 end
	if d <= (tonumber(t.r) or 8) then return L["Ya llegaste"], "exito", label end
	local txt = type(A.FormatDistance) == "function" and A.FormatDistance(d) or format("%d yd", floor(d + 0.5))
	return txt .. " " .. rumbo(dn, dw), "neutro", label
end

-- Los datos de la tarjeta grande, o nil (sin guía: los caminos de arriba la eligen).
local function tarjetaPaso()
	local info = pasoActual()
	if not info then return nil end
	if info.fin then
		return { lobo = "aullando", tono = "acento", sobre = L["Fin del camino"], titulo = L["¡Terminaste tu guía!"],
			texto = format(L["%s quedó completa. Elige qué sigue y la manada va contigo."], info.guia ~= "" and info.guia or L["Tu guía"]),
			accion = { texto = L["Elegir qué sigue"], icono = "ic-ruta", alClic = function() A.Fire("SHOW_PICKER") end } }
	end
	if not info.num then
		return { icono = "ic-ruta", tono = "acento", sobre = L["Tu siguiente paso"], titulo = info.guia ~= "" and info.guia or L["Tu guía"],
			texto = L["Tu guía está lista. Ábrela para ver tu paso."],
			accion = { texto = L["Seguir"], icono = "ic-seguir", alClic = seguirRuta } }
	end
	local lineas = {}
	for i, m in ipairs(info.metas or {}) do lineas[i] = m.texto end
	local insignias = { { info.total and format(L["Paso %d de %d"], info.num, info.total) or format(L["Paso %d"], info.num), "acento" } }
	local dist, tono, hacia = distancia()
	if dist then
		insignias[#insignias + 1] = { dist, tono, "ic-flecha" }
		if hacia and hacia ~= "" then insignias[#insignias + 1] = { format(L["Hacia: %s"], hacia), "neutro" } end
	end
	local d = {
		icono = VERBO[info.verbo] or "ic-ruta", tono = "acento", sobre = L["Tu siguiente paso"],
		titulo = info.titulo, texto = #lineas > 0 and table.concat(lineas, "\n") or nil, lineas = 4,
		insignias = insignias,
		accion = { texto = L["Seguir"], icono = "ic-seguir", alClic = seguirRuta },
		secundaria = { texto = L["Ver pasos"], alClic = verPasos },
		ayuda = L["Seguir muestra tu guía y la flecha, y cierra esta ventana para que las veas."],
	}
	if (info.todos or 0) > 0 then
		local frac = info.hechos / info.todos
		d.progreso = { actual = info.hechos, total = info.todos,
			texto = format(L["%s: %d %%"], info.guia ~= "" and info.guia or L["Tu guía"], floor(frac * 100 + 0.5)) }
	end
	return d
end

-- Una firma de lo que la tarjeta dice: si no cambió, no se vuelve a acomodar.
local function firmaPaso(d)
	if not d then return "" end
	local t = { d.titulo or "", d.texto or "", d.sobre or "" }
	for _, x in ipairs(d.insignias or {}) do t[#t + 1] = x[1] end
	if d.progreso then t[#t + 1] = d.progreso.actual .. "/" .. d.progreso.total end
	return table.concat(t, "|")
end

---------------------------------------------------------------------------
-- 3. Liberar y recoger misiones
---------------------------------------------------------------------------

local function misionesAbiertas()
	local Q = C_QuestLog
	if not (Q and Q.GetNumQuestLogEntries) then return nil end
	local ok, _, n = pcall(Q.GetNumQuestLogEntries)
	return ok and num(n) or nil
end

local function misiones()
	local lista = {}
	local liberar, recoger = deRuta("Liberar"), deRuta("Recoger")
	local n = misionesAbiertas()
	if liberar and n ~= 0 then
		lista[#lista + 1] = { variante = "compacta", icono = "ic-exito", titulo = L["Liberar misiones"],
			texto = L["Completa o entrega las que tienes abiertas"], valor = n and tostring(n) or nil,
			alClic = function() K.Llamar(liberar) end,
			ayuda = L["Arma el plan para cerrar las misiones de tu registro y te lleva a cada una."] }
	end
	if recoger then
		lista[#lista + 1] = { variante = "compacta", icono = "ic-misiones", titulo = L["Recoger misiones"],
			texto = L["Toma las de tu ruta que tienes cerca"],
			alClic = function() K.Llamar(recoger) end,
			ayuda = L["Te lleva a las misiones de tu ruta que ya puedes tomar."] }
	end
	return lista
end

---------------------------------------------------------------------------
-- 4. Alertas
---------------------------------------------------------------------------

local PESO = { peligro = 1, aviso = 2, acento = 3, exito = 4 }

local function curacion() local C0 = rawget(_G, "AlfaCuracion") return type(C0) == "table" and C0 or nil end

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
		lista[#lista + 1] = { clave = "equipo", tono = urgente and "peligro" or "aviso", icono = "ic-oficios",
			titulo = urgente and L["¡Repara tu equipo!"] or L["Tu equipo se está gastando"], texto = det,
			accion = { texto = L["Llévame a reparar"], icono = "ic-flecha", alClic = function() R.IrA("repair") end } }
	end
	local libres, total = st.bolsas.libres, st.bolsas.total
	local umbral = tonumber(N.Get("inicio", "bolsasLibres")) or 4
	if libres and libres <= umbral then
		lista[#lista + 1] = { clave = "bolsas", tono = libres == 0 and "peligro" or "aviso", icono = "ic-bolsas",
			titulo = libres == 0 and L["Tus bolsas están llenas"] or L["Tus bolsas están casi llenas"],
			texto = libres == 1 and L["Te queda 1 espacio"] or format(L["Te quedan %d de %d espacios"], libres, total or 0),
			accion = { texto = L["Llévame a un vendedor"], icono = "ic-flecha", alClic = function() R.IrA("vendor") end },
			secundaria = hay("bolsas") and { texto = L["Abrir bolsas"], alClic = function() N.Abrir("bolsas") end } or nil }
	end
	local en = st.entrenar
	if en.listo and en.n >= (tonumber(N.Get("inicio", "entrenarMin")) or 1) then
		local det = en.n == 1 and L["1 habilidad por aprender"] or format(L["%d habilidades por aprender"], en.n)
		if (en.costo or 0) > 0 then det = det .. DOT .. N.Dinero(en.costo) end
		lista[#lista + 1] = { clave = "entrenar", tono = "acento", icono = "ic-nivel", titulo = L["Tienes habilidades nuevas"],
			texto = det, accion = { texto = L["Llévame con mi entrenador"], icono = "ic-flecha", alClic = function() R.IrA("class") end } }
	end
	local b = st.buff
	if (b.estado == "falta" or b.estado == "poco") and b.nombre then
		lista[#lista + 1] = { clave = "buff", tono = "aviso", icono = "ic-aviso",
			titulo = b.estado == "poco" and format(L["A %s le queda poco"], b.nombre) or format(L["Te falta %s"], b.nombre),
			texto = L["Lánzalo antes de la siguiente pelea."] }
	end
	local Cu = curacion()
	if Cu and type(Cu.AsistentePendiente) == "function" and Cu.AsistentePendiente() then
		lista[#lista + 1] = { clave = "curacion", tono = "acento", icono = "ic-curacion", titulo = L["Prepara tus marcos de curación"],
			texto = L["Tres pasos: tus clics, dónde van tus marcos y una prueba."],
			accion = { texto = L["Empezar"], icono = "ic-seguir", alClic = function() K.Llamar(Cu.Asistente) end },
			secundaria = type(Cu.Omitir) == "function" and { texto = L["Ahora no"], alClic = function() K.Llamar(Cu.Omitir) end } or nil }
	end
	table.sort(lista, function(x, y)
		local px, py = PESO[x.tono] or 9, PESO[y.tono] or 9
		if px ~= py then return px < py end
		return x.clave < y.clave
	end)
	return lista
end

local function firmaAlertas(lista)
	local t = {}
	for i, a in ipairs(lista) do t[i] = a.clave .. ":" .. (a.titulo or "") .. ":" .. (a.texto or "") end
	return table.concat(t, ",")
end

local function nuevoAlertas(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Alertas"]))
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 340, gap = ESP.m }), { espacio = ESP.s })
	function b:Llenar(lista)
		self.Seccion:Set(L["Alertas"], { cuenta = #lista })
		self.Rejilla:Llenar(lista)
		K.Mostrar(self, #lista > 0)
	end
	return b
end

---------------------------------------------------------------------------
-- 5. Para tu <clase>
---------------------------------------------------------------------------

local ROLES = { cura = L["Sanador"], tanque = L["Tanque"], dano = L["Daño"] }

local GLIFO = {
	bolt = "ic-aviso", plus = "ic-curacion", ["icon-skill"] = "ic-talentos", ["qol-upgrade"] = "ic-nivel",
	["icon-buy"] = "ic-comercio", star = "ic-huella", ["icon-craft"] = "ic-oficios", ["icon-sethome"] = "ic-lobo",
	["qol-coin"] = "ic-oro", ["icon-collect"] = "ic-bolsas", ["icon-mount"] = "ic-lobo",
}

local function nombreClase()
	local c = K.Clase()
	local n = texto(c and c.nombre) or (UnitClass and texto((UnitClass("player")))) or ""
	-- "Para tu guerrero": en minúscula en español y en inglés; en otros
	-- idiomas (los sustantivos del alemán) se queda como lo dice el cliente.
	local loc = N.locale
	local b = n:byte(1)
	if b and b >= 65 and b <= 90 and (N.espanol or loc == "enUS" or loc == "enGB") then n = string.char(b + 32) .. n:sub(2) end
	return n
end

-- El talento que toca, del área de Talentos: { nombre, icono, porque } o nil.
local function siguienteTalento()
	local B = rawget(_G, "AlfaBuilds")
	local fn = type(B) == "table" and B.SiguienteTalento
	if type(fn) ~= "function" then return nil end
	local ok, t = pcall(fn)
	if ok and type(t) == "table" and type(t.nombre) == "string" and t.nombre ~= "" then return t end
	return nil
end

local function minis(sinTalentos)
	local lista = {}
	for _, def in ipairs(CL.Tarjetas()) do
		local r = not (sinTalentos and def.id == "talentos") and CL.Leer(def) or nil
		-- Lo que el juego no dice ahora no se muestra.
		if r and r.valor and r.valor ~= RAYA then
			local destino = CL.Destino(def)
			local color = COLOR[r.color or "text"] or "texto"
			local ayuda = {}
			if r.detalle and r.detalle ~= "" then ayuda[#ayuda + 1] = r.detalle end
			for _, l in ipairs(r.tip or {}) do if type(l) == "string" then ayuda[#ayuda + 1] = l end end
			local spec = destino and N.ModuloPorId(destino)
			if spec then ayuda[#ayuda + 1] = format(L["Clic: abre %s."], tostring(spec.nombre or destino)) end
			lista[#lista + 1] = {
				variante = "compacta", icono = GLIFO[def.glifo or ""] or "ic-lobo", textura = r.textura,
				tono = TONO[color], titulo = CL.Titulo(def), texto = r.detalle, valor = r.valor,
				colorValor = color, alClic = destino and function() N.Abrir(destino) end or nil,
				ayuda = #ayuda > 0 and table.concat(ayuda, "\n") or nil,
			}
		end
	end
	return lista
end

local function nuevaClase(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, ""))
	b.Talento = b:Agregar(K.Tarjeta(b, { variante = "normal" }), { espacio = ESP.s })
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 240, gap = ESP.s }), { espacio = ESP.s })
	function b:Llenar()
		local rol, rama = CL.Rol()
		local chip = ROLES[rol] or ""
		if rama and rama ~= "" then chip = rama .. DOT .. chip end
		self.Seccion:Set(format(L["Para tu %s"], nombreClase()), { cuenta = chip ~= "" and chip or nil })
		local t = siguienteTalento()
		if t then
			self.Talento:Set({ icono = "ic-talentos", tono = "clase", sobre = L["El talento que toca"], titulo = t.nombre,
				texto = type(t.porque) == "string" and t.porque or nil,
				accion = hay("builds") and { texto = L["Ver en Talentos"], icono = "ic-seguir", alClic = function() N.Abrir("builds") end } or nil })
		end
		K.Mostrar(self.Talento, t ~= nil)
		local lista = minis(t ~= nil)
		llenar(self.Rejilla, lista)
		K.Mostrar(self.Rejilla, #lista > 0)
		K.Mostrar(self, t ~= nil or #lista > 0)
	end
	-- Cada segundo: solo las tarjetas (su alto no cambia).
	function b:Repintar()
		if not self:IsShown() or not self.Rejilla:IsShown() then return end
		local lista = minis(self.Talento:IsShown())
		if #lista ~= #self.Rejilla.elementos then return true end
		llenar(self.Rejilla, lista)
		if self.alfaAncho then self.Rejilla:Acomodar(self.alfaAncho) end
	end
	local acomodar = b.Acomodar
	function b:Acomodar(ancho)
		self.alfaAncho = ancho
		return acomodar(self, ancho)
	end
	return b
end

---------------------------------------------------------------------------
-- 6. Hoy en números
---------------------------------------------------------------------------

local function mismoDia(a, b) return a.year == b.year and a.yday == b.yday end

-- El oro de hoy: las sesiones del diario que empezaron hoy y la de ahora.
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

-- La manada (área La Jauría, AlfaManada.Resumen): los que comparten su
-- ubicación y tu grupo. Si no compartes, la tarjeta te invita a hacerlo.
local function manada()
	local Ma = rawget(_G, "AlfaManada")
	if type(Ma) ~= "table" or type(Ma.Resumen) ~= "function" then return nil end
	local ok, r = pcall(Ma.Resumen)
	if not ok or type(r) ~= "table" then return nil end
	if not r.comparte then
		if type(Ma.PreguntarCompartir) ~= "function" then return nil end
		return { variante = "compacta", icono = "ic-manada", titulo = L["Tu manada"],
			texto = L["Comparte tu ubicación y ve a la manada"], valor = L["Compartir"], colorValor = "acento",
			alClic = function() K.Llamar(Ma.PreguntarCompartir, function() P.Relayout() end) end,
			ayuda = L["Solo con quienes usan Alfa y aceptaron compartir. Tú decides."] }
	end
	local enManada, enGrupo = num(r.manada) or 0, num(r.grupo) or 0
	local texto = format(L["%d de la manada · %d en tu grupo"], enManada, enGrupo)
	if type(r.siguiendo) == "string" and r.siguiendo ~= "" then texto = format(L["Sigues a %s"], r.siguiendo) end
	local abrir = type(Ma.Abrir) == "function" and Ma.Abrir or (hay("manada") and function() N.Abrir("manada") end) or nil
	return { variante = "compacta", icono = "ic-manada", titulo = L["Tu manada"], texto = texto,
		valor = tostring(enManada + enGrupo), colorValor = (enManada + enGrupo) > 0 and "acento" or "texto",
		alClic = abrir and function() K.Llamar(abrir) end or nil,
		ayuda = L["Los lobos que usan Alfa y comparten su ubicación, y tu grupo, que ves ahora."] }
end

local function numeros()
	local e = S.Estado()
	local lista = {}
	if not e.maximo then
		local ritmo = e.ritmo and e.ritmo > 0
		lista[#lista + 1] = { variante = "compacta", icono = "ic-huella", titulo = L["XP por hora"],
			texto = ritmo and L["Tu ritmo de los últimos 15 minutos"] or L["Gana un poco de XP y Alfa lo calcula"],
			valor = ritmo and miles(e.ritmo) or "\226\128\148",
			ayuda = format(L["Promedio de la sesión: %s XP por hora. XP ganada: %s."], miles(e.prom), miles(e.xp)) }
		lista[#lista + 1] = { variante = "compacta", icono = "ic-nivel", titulo = L["Para subir de nivel"],
			texto = format(L["Te faltan %s XP para el nivel %d"], miles(e.falta), (e.nivel or 1) + 1),
			valor = e.subir and (e.subir >= 360000 and L["más de 99 h"] or N.Duracion(e.subir)) or "\226\128\148" }
	end
	local neto, ganado, gastado = oroDeHoy(e)
	lista[#lista + 1] = { variante = "compacta", icono = "ic-oro", titulo = L["Oro de hoy"],
		texto = format(L["Ganado %s"], N.Dinero(ganado, true)), valor = (neto > 0 and "+" or "") .. N.Dinero(neto, true),
		ayuda = format(L["Ganado: %s. Gastado: %s. Suma tus sesiones de hoy con este personaje."], N.Dinero(ganado), N.Dinero(gastado)) }
	local mis = e.misiones or 0
	lista[#lista + 1] = { variante = "compacta", icono = "ic-reloj", titulo = L["Esta sesión"],
		texto = mis == 1 and L["1 misión entregada"] or format(L["%d misiones entregadas"], mis),
		valor = N.Duracion(e.dur), ayuda = format(L["Empezó %s."], S.Cuando(e.inicio)) }
	local lobos = manada()
	if lobos then lista[#lista + 1] = lobos end
	return lista
end

local function nuevoNumeros(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Hoy en números"]))
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 256, gap = ESP.s }), { espacio = ESP.s })
	function b:Llenar() llenar(self.Rejilla, numeros()) end
	function b:Repintar()
		local lista = numeros()
		if #lista ~= #self.Rejilla.elementos then return true end
		llenar(self.Rejilla, lista)
		if self.alfaAncho then self.Rejilla:Acomodar(self.alfaAncho) end
	end
	local acomodar = b.Acomodar
	function b:Acomodar(ancho)
		self.alfaAncho = ancho
		return acomodar(self, ancho)
	end
	return b
end

---------------------------------------------------------------------------
-- 7. Abajo: revisión, diario, accesos y los ajustes de tus avisos
---------------------------------------------------------------------------

-- La revisión rápida: cómo está todo, en una fila de insignias.
local function revision(enAlertas)
	enAlertas = enAlertas or {}
	local st = R.Estado()
	local t = {}
	local e = st.equipo
	if e.pct and not enAlertas.equipo then
		local pct = floor(e.pct + 0.5)
		local durAviso = tonumber(N.Get("inicio", "durAviso")) or 30
		local durUrg = tonumber(N.Get("inicio", "durUrgente")) or 10
		t[#t + 1] = { format(L["Equipo %d %%"], pct), (e.pct <= durUrg and "peligro") or (e.pct <= durAviso and "aviso") or "exito", "ic-oficios",
			L["Equipo"], format(L["Tu pieza más gastada: %s al %d %%."], R.NombreRanura(e.slot), pct) }
	end
	local libres, total = st.bolsas.libres, st.bolsas.total
	if libres and not enAlertas.bolsas then
		local umbral = tonumber(N.Get("inicio", "bolsasLibres")) or 4
		t[#t + 1] = { libres == 1 and L["1 espacio libre"] or format(L["%d espacios libres"], libres),
			(libres == 0 and "peligro") or (libres <= umbral and "aviso") or "exito", "ic-bolsas",
			L["Bolsas"], format(L["%d de %d espacios libres."], libres, total or 0) }
	end
	local en = st.entrenar
	if en.listo and not enAlertas.entrenar then
		t[#t + 1] = { en.n == 0 and L["Entrenador al día"] or (en.n == 1 and L["1 habilidad por aprender"] or format(L["%d habilidades por aprender"], en.n)),
			en.n == 0 and "exito" or "aviso", "ic-nivel", L["Entrenador"],
			en.n == 0 and L["Nada nuevo por aprender."] or L["Tu entrenador de clase tiene algo para ti."] }
	end
	local b = st.buff
	if b.estado == "ok" then
		t[#t + 1] = { L["Buff activo"], "exito", "ic-aviso", L["Tu buff"], L["Lo que tu clase se pone antes de pelear está activo."] }
	elseif (b.estado == "falta" or b.estado == "poco") and b.nombre and not enAlertas.buff then
		t[#t + 1] = { format(L["Te falta %s"], b.nombre), "aviso", "ic-aviso", L["Tu buff"], L["Lánzalo antes de la siguiente pelea."] }
	end
	local d = st.descanso
	if not d.maximo then
		local pct = floor((d.pct or 0) + 0.5)
		if d.activo then
			t[#t + 1] = { format(L["Descansando: %d %%"], pct), "exito", "ic-hoy", L["Descanso"], L["En posadas y ciudades juntas XP descansada: ganas el doble por enemigo hasta gastarla."] }
		elseif (d.xp or 0) > 0 then
			t[#t + 1] = { format(L["Descanso %d %%"], pct), "neutro", "ic-hoy", L["Descanso"], format(L["XP descansada: %d %% de un nivel."], pct) }
		end
	end
	return t
end

local function nuevaRevision(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Seccion = K.Seccion(b, L["Lo demás, de un vistazo"])
	b.insignias = {}
	function b:Llenar(alertasDeHoy)
		local en = {}
		for _, a in ipairs(alertasDeHoy or {}) do en[a.clave] = true end
		local lista = revision(en)
		for i, x in ipairs(lista) do
			local ch = self.insignias[i]
			if not ch then
				ch = K.Insignia(self, "", "neutro")
				ch:EnableMouse(true)
				self.insignias[i] = ch
			end
			ch:Set(x[1], x[2], x[3])
			K.ConInfo(ch, x[4], x[5])
		end
		for i = #lista + 1, #self.insignias do self.insignias[i]:Hide() end
		self.alfaN = #lista
		K.Mostrar(self, #lista > 0)
	end
	function b:Acomodar(ancho)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(ancho)
		local y = self.Seccion:Acomodar(ancho) + ESP.s
		local x, fila = 0, y
		for i = 1, self.alfaN or 0 do
			local ch = self.insignias[i]
			local w = K.num(ch:GetWidth(), 0)
			if x > 0 and x + w > ancho then x, fila = 0, fila + K.ALTO.insignia + ESP.s end
			ch:ClearAllPoints()
			ch:SetPoint("TOPLEFT", self, "TOPLEFT", x, -fila)
			x = x + w + ESP.s
		end
		local alto = fila + K.ALTO.insignia
		self:SetSize(ancho, alto)
		return alto
	end
	return b
end

-- El diario: lo de ahora y, al pedirlo, las últimas sesiones.
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

local function diario()
	local pasadas = S.Sesiones()
	local lista = {}
	if N.Get("inicio", "verDiario") then
		for k = 1, min(SESIONES, #pasadas) do
			local s = pasadas[#pasadas - k + 1]
			lista[#lista + 1] = { variante = "compacta", icono = "ic-reloj", titulo = S.Cuando(s.inicio), texto = resumenCorto(s),
				valor = N.Duracion(s.dur or 0) }
		end
	end
	return lista, #pasadas
end

local function nuevoDiario(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Tu diario"]))
	b.Ahora = b:Agregar(K.Tarjeta(b, { variante = "compacta" }), { espacio = ESP.s })
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 300, gap = ESP.s }), { espacio = ESP.s })
	function b:Llenar()
		local lista, n = diario()
		local ver = N.Get("inicio", "verDiario")
		self.Seccion:Set(L["Tu diario"], {
			cuenta = n > 0 and n or nil,
			enlace = n > 0 and { texto = ver and L["Ver menos"] or L["Ver las sesiones pasadas"],
				alClic = function() N.Set("inicio", "verDiario", not N.Get("inicio", "verDiario")) end } or nil,
		})
		local e = S.Estado()
		self.Ahora:Set({ icono = "ic-hoy", titulo = L["Ahora"], texto = S.Texto(e), valor = format(L["desde %s"], date("%H:%M", e.inicio)) })
		llenar(self.Rejilla, lista)
		K.Mostrar(self.Rejilla, #lista > 0)
	end
	return b
end

-- Accesos: un botón chico por cada módulo de Alfa.
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

local function iconoDe(spec)
	if type(spec.icono) == "string" and spec.icono:find("^ic%-") then return spec.icono end
	local O = A.UI and A.UI.Options
	local t = type(O) == "table" and O.ICONOS
	return type(t) == "table" and t[spec.id] or "ic-lobo"
end

local function nuevosAccesos(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Seccion = K.Seccion(b, L["Accesos"])
	b.botones = {}
	function b:Llenar()
		local lista = modulos()
		for i, spec in ipairs(lista) do
			local bt = self.botones[i]
			if not bt then
				bt = K.Boton(self, "", nil, { tipo = "secundario", tam = "chico", conIcono = true })
				self.botones[i] = bt
			end
			local id = spec.id
			bt:SetTexto(tostring(spec.nombre or id))
			bt:SetIcono(iconoDe(spec))
			bt.alClic = function() N.Abrir(id) end
			K.ConInfo(bt, tostring(spec.nombre or id), type(spec.subtitulo) == "string" and spec.subtitulo or nil)
			bt:Show()
		end
		for i = #lista + 1, #self.botones do self.botones[i]:Hide() end
		self.alfaN = #lista
		K.Mostrar(self, #lista > 0)
	end
	function b:Acomodar(ancho)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(ancho)
		local y = self.Seccion:Acomodar(ancho) + ESP.s
		local x, fila = 0, y
		for i = 1, self.alfaN or 0 do
			local bt = self.botones[i]
			local w = bt:AnchoNatural()
			bt:SetAncho(nil)
			if x > 0 and x + w > ancho then x, fila = 0, fila + K.ALTO.botonChico + ESP.s end
			bt:ClearAllPoints()
			bt:SetPoint("TOPLEFT", self, "TOPLEFT", x, -fila)
			x = x + w + ESP.s
		end
		local alto = fila + K.ALTO.botonChico
		self:SetSize(ancho, alto)
		return alto
	end
	return b
end

-- Los ajustes de tus avisos: plegados; al abrirlos, grupos de filas del Kit.
local function interruptor(clave) return function(fila) return K.Interruptor(fila, { clave = "inicio." .. clave }) end end

local function deslizador(c)
	return function(fila)
		local d = K.Deslizador(fila, { min = c.min, max = c.max, paso = c.step, clave = c.key, formato = c.format })
		d.alfaAnchoFila = 220
		return d
	end
end

local function boton(texto, fn, tipo)
	return function(fila) return K.Boton(fila, texto, fn, { tipo = tipo or "secundario", tam = "chico" }) end
end

local function encendido(clave) return function() return N.Get("inicio", clave) and true or false end end

local function existe(clave) return A.GetDefault and A.GetDefault(clave) ~= nil end

local function gruposAvisos(padre)
	local g = {}
	local dur = K.GrupoAjustes(padre, { titulo = L["Durabilidad"] })
	dur:Fila({ titulo = C.recDurabilidad.label, texto = C.recDurabilidad.help, control = interruptor("recDurabilidad") })
	dur:Fila({ titulo = C.durAviso.label, texto = C.durAviso.help, hija = true, activa = encendido("recDurabilidad"), control = deslizador(C.durAviso) })
	dur:Fila({ titulo = C.durUrgente.label, texto = C.durUrgente.help, hija = true, activa = encendido("recDurabilidad"), control = deslizador(C.durUrgente) })
	g[#g + 1] = dur
	local bol = K.GrupoAjustes(padre, { titulo = L["Bolsas"] })
	bol:Fila({ titulo = C.recBolsas.label, texto = C.recBolsas.help, control = interruptor("recBolsas") })
	bol:Fila({ titulo = C.bolsasLibres.label, hija = true, activa = encendido("recBolsas"), control = deslizador(C.bolsasLibres) })
	g[#g + 1] = bol
	local ent = K.GrupoAjustes(padre, { titulo = L["Habilidades por entrenar"] })
	ent:Fila({ titulo = C.recEntrenar.label, texto = C.recEntrenar.help, control = interruptor("recEntrenar") })
	ent:Fila({ titulo = C.entrenarMin.label, hija = true, activa = encendido("recEntrenar"), control = deslizador(C.entrenarMin) })
	if existe("qol.levelUpSpells") then
		ent:Fila({ titulo = L["Tarjeta de habilidades nuevas al subir de nivel"], texto = L["Al subir de nivel te muestra qué aprender y cuánto cuesta."],
			control = function(fila) return K.Interruptor(fila, { clave = "qol.levelUpSpells" }) end })
	end
	if existe("behavior.trainReminder") then
		ent:Fila({ titulo = L["Nota de entrenar en tu guía"], texto = L["Con el entrenador más cercano en tu camino."],
			control = function(fila)
				return K.Desplegable(fila, { clave = "behavior.trainReminder", ancho = 170, opciones = {
					{ valor = "2", texto = L["Cada 2 niveles"] }, { valor = "1", texto = L["Cada nivel"] }, { valor = "off", texto = L["No"] } } })
			end })
	end
	g[#g + 1] = ent
	local buf = K.GrupoAjustes(padre, { titulo = L["Buff fuera de combate"] })
	buf:Fila({ titulo = C.recBuff.label, texto = C.recBuff.help, control = interruptor("recBuff") })
	buf:Fila({ titulo = C.buffCada.label, hija = true, activa = encendido("recBuff"), control = deslizador(C.buffCada) })
	buf:Fila({ titulo = C.buffQueda.label, hija = true, activa = encendido("recBuff"), control = deslizador(C.buffQueda) })
	g[#g + 1] = buf
	local des = K.GrupoAjustes(padre, { titulo = L["Descanso"] })
	des:Fila({ titulo = C.recDescanso.label, texto = C.recDescanso.help, control = interruptor("recDescanso") })
	des:Fila({ titulo = C.descansoBajo.label, hija = true, activa = encendido("recDescanso"), control = deslizador(C.descansoBajo) })
	g[#g + 1] = des
	local av = K.GrupoAjustes(padre, { titulo = L["Avisos y diario"] })
	av:Fila({ titulo = C.resumen.label, texto = C.resumen.help, control = function(fila)
		return K.Desplegable(fila, { clave = "inicio.resumen", ancho = 200, opciones = {
			{ valor = "ambos", texto = L["En un aviso y en el chat"] }, { valor = "aviso", texto = L["En un aviso"] },
			{ valor = "chat", texto = L["En el chat"] }, { valor = "no", texto = L["No mostrar"] } } })
	end })
	av:Fila({ titulo = C.segAviso.label, texto = C.segAviso.help, control = deslizador(C.segAviso) })
	av:Fila({ titulo = C.sonido.label, texto = C.sonido.help, control = interruptor("sonido") })
	av:Fila({ titulo = C.diarioMax.label, control = deslizador(C.diarioMax) })
	av:Fila({ titulo = C.probar.label, texto = C.probar.help, control = boton(L["Probar"], function() Aviso.Probar() end) })
	av:Fila({ titulo = C.lugar.label, texto = C.lugar.help, control = boton(L["Restablecer"], function() N.Set("inicio", "avisoPos", nil) end) })
	av:Fila({ titulo = C.borrar.label, texto = C.borrar.help, control = boton(L["Borrar"], function()
		K.Dialogo({ titulo = L["¿Borrar el diario?"], texto = C.borrar.confirmText, aceptar = L["Borrar"], peligro = true,
			alAceptar = function() S.Borrar() end })
	end, "peligro") })
	g[#g + 1] = av
	return g
end

local function nuevosAjustes(padre)
	local b = K.Pila(padre, { espacio = ESP.l })
	b.Seccion = b:Agregar(K.Seccion(b, L["Tus avisos"]))
	b.Nota = CreateFrame("Frame", nil, b)
	b.Nota.Texto = K.Texto(b.Nota, "nota", "textoSuave")
	function b.Nota:Acomodar(ancho)
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		local h = K.Parrafo(self.Texto, ancho, 3)
		self:SetSize(ancho, h)
		return h
	end
	b:Agregar(b.Nota, { espacio = ESP.s })
	function b:Llenar()
		local ver = N.Get("inicio", "verAjustes") and true or false
		self.Seccion:Set(L["Tus avisos"], { enlace = { texto = ver and L["Ocultar ajustes"] or L["Ajustar"],
			alClic = function() N.Set("inicio", "verAjustes", not N.Get("inicio", "verAjustes")) end } })
		K.Escribir(self.Nota.Texto, L["Alfa te avisa del equipo gastado, las bolsas llenas, lo que puedes entrenar, tu buff y tu descanso. Aquí eliges cuáles y cuándo."])
		K.Mostrar(self.Nota, not ver)
		if ver and not self.grupos then
			self.grupos = gruposAvisos(self)
			for i, g in ipairs(self.grupos) do self:Agregar(g, { espacio = i == 1 and ESP.base or ESP.l }) end
		end
		for _, g in ipairs(self.grupos or {}) do
			K.Mostrar(g, ver)
			if ver then g:Refrescar() end
		end
	end
	return b
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

local function llenarTodo()
	R.Leer()
	P.portada:Llenar()
	local paso = tarjetaPaso()
	P.firmaPaso = firmaPaso(paso)
	P.tablero:SetAccion(paso)
	P.tablero:SetOpciones(misiones(), false)
	local lista = alertas()
	P.firmaAlertas = firmaAlertas(lista)
	P.alertas:Llenar(lista)
	P.clase:Llenar()
	P.numeros:Llenar()
	P.revision:Llenar(lista)
	P.diario:Llenar()
	P.accesos:Llenar()
	P.ajustes:Llenar()
end

local function construir(view)
	P.view = view
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "accion", min = 256 })
	P.tablero = t
	-- La portada va antes que la tarjeta grande: es lo primero de la pila del tablero.
	P.portada = nuevaPortada(t)
	table.insert(t.bloques, 1, { b = P.portada, sangria = 0 })
	P.alertas = t:AgregarBloque(nuevoAlertas(t.Extra))
	P.clase = t:AgregarBloque(nuevaClase(t.Extra))
	P.numeros = t:AgregarBloque(nuevoNumeros(t.Extra))
	P.revision = t:AgregarBloque(nuevaRevision(t.Extra), { espacio = ESP.xl })
	P.diario = t:AgregarBloque(nuevoDiario(t.Extra))
	P.accesos = t:AgregarBloque(nuevosAccesos(t.Extra))
	P.ajustes = t:AgregarBloque(nuevosAjustes(t.Extra))
	K.EnPagina(view, t, function()
		llenarTodo()
		-- La ventana crea la vista ya visible: su primer OnShow no llega, así
		-- que el temporizador también arranca aquí.
		if view:IsVisible() and not P.ticker then P.AlMostrar() end
	end)
	view:HookScript("OnShow", function() P.AlMostrar() end)
	view:HookScript("OnHide", function() P.AlOcultar() end)
end

local function relayout()
	local view = P.view
	if not (view and view:IsVisible() and view.Refresh) or P.acomodando then return end
	P.acomodando = true
	local ok, err = pcall(N.RehacerPagina, view)
	P.acomodando = false
	if not ok and geterrorhandler then geterrorhandler()(err) end
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

-- Cada segundo (y cuando un recordatorio cambia algo): lo que se mueve solo.
-- Si algo cambió de forma (una alerta nueva, otro paso), se acomoda todo.
function P.Pintar()
	local view = P.view
	if not (view and view:IsVisible()) or P.acomodando or not P.tablero then return end
	local lista = alertas()
	local paso = tarjetaPaso()
	if firmaAlertas(lista) ~= P.firmaAlertas then return relayoutPronto() end
	local firma = firmaPaso(paso)
	if firma ~= P.firmaPaso then
		-- Solo cambió la distancia: la tarjeta se acomoda sola si su alto no cambia.
		local t = P.tablero
		local antes = K.num(t.Accion:GetHeight(), 0)
		P.firmaPaso = firma
		if not paso or not t.Accion:IsShown() then return relayoutPronto() end
		t.Accion:Set(paso)
		if t.Accion:Acomodar(K.num(t.Accion:GetWidth(), N.AnchoPagina())) ~= antes then return relayoutPronto() end
	end
	if P.numeros:Repintar() or P.clase:Repintar() then return relayoutPronto() end
end

function P.AlMostrar()
	if P.ticker then P.ticker:Cancel() end
	CL.Sucio()
	P.ticker = A.NewTicker(1, P.Pintar)
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
for _, msg in ipairs({ "STEP_CHANGED", "GUIDE_CHANGED", "GUIDE_COMPLETED", "TABS_CHANGED", "INICIO_DIARIO", "ALFA_REEMPLAZO", "ALFA_CURACION_ASISTENTE" }) do
	A.On(msg, relayoutPronto)
end
-- Otra rama (o nivel) cambia el rol y las tarjetas de la clase.
A.On("GEAR_UPDATED", function(what)
	if what == "spec" or what == "level" then relayoutPronto() end
end)
A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" then return end
	if path == "inicio.verDiario" or path == "inicio.verAjustes" or path == "curacion.activo" or path == "manada.compartir"
		or path:find("^gear%.spec") then
		relayoutPronto()
	elseif path:find("^inicio%.") and P.ajustes and P.ajustes.grupos then
		for _, g in ipairs(P.ajustes.grupos) do g:Refrescar() end
	end
end)
A.RegisterEvent("PLAYER_TALENT_UPDATE", relayoutPronto)
A.RegisterEvent("TRAIT_CONFIG_UPDATED", relayoutPronto)
A.RegisterEvent("PLAYER_LEVEL_UP", relayoutPronto)
A.RegisterEvent("QUEST_ACCEPTED", relayoutPronto)
A.RegisterEvent("QUEST_REMOVED", relayoutPronto)

---------------------------------------------------------------------------
-- El módulo
---------------------------------------------------------------------------

N.Modulo({
	id = "inicio", nombre = L["Hoy"], icono = "ic-hoy", orden = 5, seccion = "hoy",
	subtitulo = L["Tu día con la manada: el plan, lo urgente y tu clase."],
	comando = "inicio",
	ajustes = AJUSTES,
	controles = CONTROLES,
	construir = construir,
})
