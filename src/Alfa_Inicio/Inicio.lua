-- Alfa - Inicio: la página Hoy, la portada de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- Hecha con el Kit (docs/KIT.md, K.Tablero). De arriba abajo, y cada pieza
-- solo si tiene algo útil o una acción (lo vacío no se muestra):
--   1. ¿Qué hacemos hoy?: el título grande y los cuatro caminos (Subir de
--      nivel, Profesiones, Hacer oro, Mazmorras). Cada uno abre el asistente
--      de la ruta (AlfaRuta.Asistente(camino)); sin él, la página Rutas (o
--      Mazmorras). En el nivel máximo, subir de nivel no sale.
--      Con una guía o un plan en marcha, lo que sigues va primero y los
--      caminos bajan a una fila compacta («¿Otra cosa hoy?», ordenar()).
--   2. Tu siguiente paso (la tarjeta grande): el paso vivo de tu guía, sus
--      metas, la distancia y el rumbo hasta la flecha, cuántos pasos llevas,
--      Seguir y Ver pasos. Sin guía no sale: los caminos de arriba la eligen.
--      Al terminar una guía: elegir qué sigue.
--   3. Cerrar mis misiones y Recoger misiones a un clic (AlfaRuta.Liberar() y
--      AlfaRuta.Recoger(), si la ruta los tiene; Cerrar, si tienes misiones),
--      y «Una hora de caza» (AlfaRuta.UnaHora(), 1.2.7). El avance de la
--      tarjeta dice cuánto falta por tu ritmo (AlfaRuta.Estimado(), 1.2.7).
--      Tu plan: la meta de ahora del plan que sigues (AlfaPlanes.Tarjeta()).
--      1.2.9: «¿Cuánto tiempo tienes?» (M.Tiempo): eliges 30 min, 1 h, 2 h u
--      otro y Alfa arma el plan en pasos con sus minutos; con el plan en
--      marcha, su tarjeta (paso, avance, Llévame y Siguiente) va arriba.
--   4. Alertas: equipo gastado, bolsas casi llenas, habilidades por
--      entrenar, tu buff y, si curas, preparar tus marcos de curación.
--      Debajo, Buscar cerca: vuelo, posada, reparar, banco, buzón y tu
--      entrenador a un clic (AlfaCerca, de la ruta; con rutas.cercaHoy).
--   5. Para tu <clase>: el talento que toca (AlfaBuilds.SiguienteTalento) y
--      tres tarjetas de tu clase (M.Clase), cada una abre su módulo.
--   6. Hoy en números: XP por hora, para subir, oro de hoy, esta sesión.
--      1.2.9: Camino al 60 (M.Camino), con su ventana aparte (las guías y
--      mazmorras por tramos y tus días de caza).
--   7. Abajo y compacto: la revisión rápida en una fila, tu diario (lo de
--      ahora, desde los 5 minutos de sesión; las sesiones pasadas al
--      pedirlas) y los ajustes de tus avisos (plegados). Los módulos ya están
--      en la barra lateral: Hoy no los repite.
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
local DIARIO_MIN = 300 -- segundos de sesión antes de mostrar tu diario

---------------------------------------------------------------------------
-- Ajustes
---------------------------------------------------------------------------

local AJUSTES = {
	recDurabilidad = true, durAviso = 30, durUrgente = 10,
	recBolsas = true, bolsasLibres = 4,
	recEntrenar = true, entrenarMin = 1,
	recBuff = true, buffCada = 3, buffQueda = 0,
	recDescanso = true, descansoBajo = 5,
	-- 1.3.3: el resumen de la sesión anterior, sin chat al entrar (era "ambos").
	resumen = "aviso", segAviso = 10, sonido = true, diarioMax = 30,
	-- Lo plegable de abajo: el diario completo y los ajustes de los avisos.
	verDiario = false, verAjustes = false,
	-- 1.2.9: tu tiempo de juego, el camino al 60, listo para la mazmorra y la comida.
	horaPlan = true, horaMin = 60, horaAuto = true, camino = true,
	listoAuto = true, listoDur = 50, listoBolsas = 6, listoComida = 10,
	comidaAviso = true, comidaMin = 5,
	-- 1.3.7: lo de Alfa en los cuadros de las barras de experiencia y de
	-- reputación, y tu tiempo jugado en Hoy (sin chat).
	barraXP = true, barraRep = true, jugado = true,
}

local function apagado(clave) return function() return not N.Get("inicio", clave) end end
local function porc(v) return format("%d%%", v) end

-- Los controles del motor (la búsqueda de la ventana de Alfa los encuentra);
-- en la página se dibujan con el Kit (grupos, abajo).
-- 1.3.3: con el módulo Bolsas, el aviso de bolsas llenas es el suyo (una sola
-- voz) y sus ajustes mandan también en Hoy.
local function conBolsas() return N.ModuloPorId ~= nil and N.ModuloPorId("bolsas") ~= nil end
-- Al cargar, Bolsas puede venir después: también cuenta si está prendido.
local function bolsasPrendido()
	if conBolsas() then return true end
	local CA = rawget(_G, "C_AddOns")
	local f = type(CA) == "table" and CA.GetAddOnEnableState
	if type(f) ~= "function" then return false end
	local ok, e = pcall(f, "Alfa_Bolsas", UnitName and UnitName("player"))
	return ok and (tonumber(e) or 0) > 0
end
local CON_BOLSAS = bolsasPrendido()

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
	recBolsas = { kind = "toggle", key = CON_BOLSAS and "bolsas.avisoLleno" or "inicio.recBolsas", label = L["Avisarme cuando mis bolsas se llenen"],
		help = L["Para que no dejes botín tirado por falta de espacio."],
		search = "bolsas, llenas, espacio, inventario, bags, full, space" },
	bolsasLibres = { kind = "slider", key = CON_BOLSAS and "bolsas.avisoLibres" or "inicio.bolsasLibres", label = L["Avisar con estos espacios libres o menos"],
		min = CON_BOLSAS and 1 or 0, max = CON_BOLSAS and 10 or 12, step = 1,
		format = function(v) return v == 1 and L["1 espacio"] or format(L["%d espacios"], v) end,
		child = true, disabled = apagado("recBolsas"), search = "bolsas, espacio, bags, slots" },
	recEntrenar = { kind = "toggle", key = "inicio.recEntrenar", label = L["Avisarme en la ciudad si tengo habilidades por aprender"],
		help = L["Al llegar a una ciudad o posada. También repite la nota de entrenar de la guía cuando su ventana está oculta."],
		search = "entrenar, entrenador, habilidades, hechizos, train, trainer, spells, skills" },
	entrenarMin = { kind = "slider", key = "inicio.entrenarMin", label = L["Desde cuántas habilidades"], min = 1, max = 5, step = 1,
		format = function(v) return format("%d", v) end, child = true, disabled = apagado("recEntrenar"),
		search = "entrenar, habilidades, train, spells" },
	-- 1.3.6: «la mejora de tu clase» en vez de «buff».
	recBuff = { kind = "toggle", key = "inicio.recBuff", label = L["Avisarme si me falta la mejora de mi clase fuera de combate"],
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
	-- 1.2.9
	horaPlan = { kind = "toggle", key = "inicio.horaPlan", label = L["«¿Cuánto tiempo tienes?» en Hoy"],
		help = L["Dices cuánto vas a jugar y Alfa arma tu plan: entregar, cerrar misiones, una mazmorra si cabe y lo demás."],
		search = "tiempo, hora, plan, una hora, minutos, time, hour, plan, minutes" },
	horaMin = { kind = "slider", key = "inicio.horaMin", label = L["Tu tiempo de juego"], min = 15, max = 240, step = 15,
		format = function(v) return M.Tiempo.Minutos(v) end, child = true, disabled = apagado("horaPlan"),
		search = "tiempo, minutos, time, minutes" },
	horaAuto = { kind = "toggle", key = "inicio.horaAuto", label = L["Pasar solo al siguiente paso"],
		help = L["Cuando ya entregaste todo o cerraste tu zona, te dice qué sigue (la flecha la pones tú con «Llévame»)."],
		child = true, disabled = apagado("horaPlan"), search = "siguiente, paso, plan, next, step" },
	camino = { kind = "toggle", key = "inicio.camino", label = L["«Camino al 60» en Hoy"],
		help = L["Cuánto te falta para el 60 a tu ritmo, qué guías y mazmorras te tocan y cuánto avanzas cada día."],
		search = "camino, 60, nivel máximo, horas, ritmo, road, level 60, max level, hours, pace" },
	-- 1.3.7
	barraXP = { kind = "toggle", key = "inicio.barraXP", label = L["Lo de Alfa en la barra de experiencia"],
		help = L["Al pasar el ratón: en cuánto subes de nivel a tu ritmo, lo que dan tus misiones listas y tu descanso."],
		search = "experiencia, barra, nivel, descanso, xp bar, rested" },
	barraRep = { kind = "toggle", key = "inicio.barraRep", label = L["Lo de Alfa en la barra de reputación"],
		help = L["Al pasar el ratón: cuánto te falta para el rango que sigue y unas cuántas misiones son eso."],
		search = "reputación, facción, rango, reputation, faction" },
	jugado = { kind = "toggle", key = "inicio.jugado", label = L["Tu tiempo jugado en Hoy"],
		help = L["Alfa lo pregunta al entrar sin escribir en tu chat."],
		search = "tiempo jugado, played, horas" },
	listoAuto = { kind = "toggle", key = "inicio.listoAuto", label = L["Revisar sola al entrar a una mazmorra"],
		help = L["Al entrar o al juntarse tu grupo: equipo, bolsas, comida, agua, munición y lo de tu clase. Nunca en combate."],
		search = "mazmorra, listo, revisar, reparar, munición, componentes, dungeon, ready, check, ammo, reagents" },
	listoDur = { kind = "slider", key = "inicio.listoDur", label = L["Reparar si mi equipo baja de"], min = 20, max = 90, step = 10, format = porc,
		child = true, disabled = apagado("listoAuto"), search = "mazmorra, durabilidad, reparar, dungeon, durability" },
	listoBolsas = { kind = "slider", key = "inicio.listoBolsas", label = L["Espacios libres para el botín"], min = 0, max = 16, step = 1,
		format = function(v) return v == 1 and L["1 espacio"] or format(L["%d espacios"], v) end,
		child = true, disabled = apagado("listoAuto"), search = "mazmorra, bolsas, espacio, dungeon, bags" },
	listoComida = { kind = "slider", key = "inicio.listoComida", label = L["Comida y agua para llevar"], min = 0, max = 40, step = 5,
		format = function(v) return format("%d", v) end, child = true, disabled = apagado("listoAuto"),
		search = "mazmorra, comida, agua, dungeon, food, water" },
	comidaAviso = { kind = "toggle", key = "inicio.comidaAviso", label = L["Avisarme cuando se me acabe la comida o el agua"],
		help = L["Te dice qué comprar a tu nivel y te lleva al vendedor de comida más cercano. El agua, solo si usas maná."],
		search = "comida, agua, beber, comer, posadero, food, water, drink, eat, innkeeper" },
	comidaMin = { kind = "slider", key = "inicio.comidaMin", label = L["Avisar cuando me queden"], min = 1, max = 20, step = 1,
		format = function(v) return format("%d", v) end, child = true, disabled = apagado("comidaAviso"),
		search = "comida, agua, food, water" },
}

local CONTROLES = {
	C.recDurabilidad, C.durAviso, C.durUrgente, C.recBolsas, C.bolsasLibres, C.recEntrenar, C.entrenarMin,
	C.recBuff, C.buffCada, C.buffQueda, C.recDescanso, C.descansoBajo,
	C.resumen, C.segAviso, C.sonido, C.diarioMax, C.probar, C.lugar, C.borrar,
	C.horaPlan, C.horaMin, C.horaAuto, C.camino, C.listoAuto, C.listoDur, C.listoBolsas, C.listoComida,
	C.comidaAviso, C.comidaMin, C.barraXP, C.barraRep, C.jugado,
}
-- 1.3.3: con Bolsas, sus ajustes de bolsas ya salen en la búsqueda: no se repiten aquí.
if CON_BOLSAS then
	for i = #CONTROLES, 1, -1 do
		if CONTROLES[i] == C.recBolsas or CONTROLES[i] == C.bolsasLibres then table.remove(CONTROLES, i) end
	end
end

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

local function cerrarVentana() N.CerrarVentana() end

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

-- Con una guía o un plan en marcha: los mismos caminos en una fila de
-- botones chicos, debajo de lo que sigues.
local function nuevaOtra(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Seccion = K.Seccion(b, L["¿Otra cosa hoy?"])
	b.botones = {}
	function b:Llenar()
		local lista = caminos()
		for i, c in ipairs(lista) do
			local bt = self.botones[i]
			if not bt then
				bt = K.Boton(self, "", nil, { tipo = "secundario", tam = "chico", conIcono = true })
				self.botones[i] = bt
			end
			bt:SetTexto(c.titulo)
			bt:SetIcono(c.icono)
			bt.alClic = c.alClic
			K.ConInfo(bt, c.titulo, c.texto)
			bt:Show()
		end
		for i = #lista + 1, #self.botones do self.botones[i]:Hide() end
		self.alfaN = #lista
	end
	function b:Acomodar(ancho)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(ancho)
		local y = self.Seccion:Acomodar(ancho) + ESP.s
		local x, fila = 0, y
		for i = 1, self.alfaN or 0 do
			local bt = self.botones[i]
			bt:SetAncho(nil)
			local w = bt:AnchoNatural()
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

---------------------------------------------------------------------------
-- 2. Tu siguiente paso
---------------------------------------------------------------------------

-- Empezar a seguir: el rastreador a la vista y las ventanas de Alfa cerradas
-- (N.EmpezarRuta del núcleo; sin él, como antes).
local function empezar()
	if N.EmpezarRuta then
		N.EmpezarRuta()
	else
		A.Fire("SHOW_FRAME")
		cerrarVentana()
	end
end

-- Seguir: tu guía y la flecha a la vista; la ventana de Alfa se cierra para que se vean.
local function seguirRuta()
	if A.Get("nav.arrow") == false then A.Set("nav.arrow", true) end
	empezar()
end

-- Ver pasos: la lista de pasos de tu guía.
local function verPasos()
	empezar()
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
	local info = { guia = texto(g.title) or "", id = type(g.id) == "string" and g.id or nil }
	local okp, hechos, todos = pcall(E.GetProgress)
	if okp then info.hechos, info.todos = num(hechos) or 0, num(todos) or 0 end
	local live = type(E.GetLiveStep) == "function" and E.GetLiveStep() or nil
	local i = type(live) == "number" and live or (type(E.GetStepIndex) == "function" and E.GetStepIndex()) or nil
	if type(live) ~= "number" and info.todos and info.todos > 0 and info.hechos >= info.todos then
		-- 1.3.7: sin paso vivo el motor cuenta los omitidos como hechos: la
		-- guía terminó solo si cada paso está hecho de verdad, lo mismo que
		-- dice el rastreador (AlfaRuta.GuiaTerminada, 73).
		local hecha = deRuta("GuiaTerminada")
		if hecha and not hecha() then
			info.sinPaso = true
			return info
		end
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
	-- 1.3.7: la misma cuenta que el rastreador (AlfaRuta.Distancia, 103-104).
	local comun = deRuta("Distancia")
	if comun then
		local ok, t, tono, label = pcall(comun)
		if ok then return t, tono, label and texto(label) or nil end
	end
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

-- Un texto sin colores ni íconos y en minúsculas, para compararlo.
local function plano(s)
	s = tostring(s or "")
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
	return s:lower()
end

-- "Hacia: X" solo si X no sale ya en el título o en las metas del paso.
local function diceAlgoMas(hacia, info)
	local h = plano(hacia)
	if h == "" then return false end
	if plano(info.titulo):find(h, 1, true) then return false end
	for _, m in ipairs(info.metas or {}) do
		if plano(m.texto):find(h, 1, true) then return false end
	end
	return true
end

-- 1.2.7: «unos 40 min», «como 1 h 30 min»: lo que te falta de tu guía por tu
-- ritmo (AlfaRuta.Estimado), o nil si todavía no se sabe.
local function tiempoQueFalta()
	local est = deRuta("Estimado")
	local ok, m = false, nil
	if est then ok, m = pcall(est) end
	m = ok and tonumber(m) or nil
	if not m or m <= 0 then return nil end
	-- 1.3.7: el mismo formato de tiempo que todo Alfa (N.Duracion, 101).
	if m >= 60 then m = floor(m / 5 + 0.5) * 5 end
	return format(L["unos %s"], N.Duracion(m * 60, true))
end

-- 1.3.6: la última tarjeta de un paso en marcha y su paso, para que el reloj
-- de cada segundo solo vuelva a medir la distancia (distanciaPaso).
local pasoVivo

-- Las insignias de la tarjeta: la distancia (y «Hacia: X») de la flecha.
local function insigniasPaso(info)
	local insignias = {}
	local dist, tono, hacia = distancia()
	if dist then
		insignias[#insignias + 1] = { dist, tono, "ic-flecha" }
		if hacia and diceAlgoMas(hacia, info) then insignias[#insignias + 1] = { format(L["Hacia: %s"], hacia), "neutro" } end
	end
	return insignias
end

-- Los datos de la tarjeta grande, o nil (sin guía: los caminos de arriba la eligen).
-- fin = true: la guía ya terminó (no cuenta como una guía en marcha).
local function tarjetaPaso()
	pasoVivo = nil
	local info = pasoActual()
	if not info then return nil end
	-- 1.2.6: «Desbloquear» terminada: ya puedes tomar la misión.
	if info.fin and info.id == "mis-rutas/desbloquear" then
		return { fin = true, lobo = "aullando", tono = "acento", sobre = L["Fin del camino"], titulo = L["¡Ya la desbloqueaste!"],
			texto = L["Hiciste lo que pedía antes. Búscala con su «!» y tómala, o elige qué sigue."],
			accion = { texto = L["Elegir qué sigue"], icono = "ic-ruta", alClic = function() A.Fire("SHOW_PICKER") end } }
	end
	-- 1.2.6: lo mismo que el rastreador cuando la guía llegó a su final con
	-- pasos sin hacer (antes Hoy decía «Seguir» como si nada).
	local fin = deRuta("FinGuia")
	local mf = fin and fin()
	-- 1.3.7: cómo quedó la guía, lo mismo que el rastreador (AlfaRuta.Cierre):
	-- la que sigue o el camino para elegir a un clic (89, 90) y, con pasos
	-- omitidos que tapan lo demás, «Recuperar lo omitido» (91).
	local cierreFn = deRuta("Cierre")
	local c = cierreFn and (info.fin or info.sinPaso or type(mf) == "table") and cierreFn() or nil
	local seguirC, textoC = deRuta("SeguirCierre"), deRuta("TextoCierre")
	local function accionCierre(icono)
		if not (c and seguirC and textoC and (c.sig or c.elegir)) then return nil end
		return { texto = textoC(c), icono = icono or "ic-ruta", alClic = function() seguirC(c) end }
	end
	local quedo = (type(mf) == "table" and not mf.complete) or (info.sinPaso and c and c.omitidos > 0)
	if quedo and not info.fin then
		local undone = type(mf) == "table" and mf.undone or (c and c.omitidos) or 0
		local recuperar = deRuta("Recuperar")
		local otra = accionCierre("ic-ruta")
		return { lobo = "atento", tono = "acento", sobre = L["Fin del camino"],
			titulo = format(L["Final de %s"], (type(mf) == "table" and mf.label) or info.guia or ""),
			texto = N.Plural(undone, L["Llegaste al final; quedó %d paso sin hacer."], L["Llegaste al final; quedaron %d pasos sin hacer."]),
			accion = otra or { texto = L["Ver lo que quedó"], icono = "ic-seguir", alClic = seguirRuta },
			secundaria = (c and c.recuperar and recuperar) and { texto = L["Recuperar lo omitido"], alClic = function() recuperar(c) end }
				or (otra and { texto = L["Ver lo que quedó"], alClic = seguirRuta })
				or { texto = L["¿Qué sigue?"], alClic = function() A.Fire("SHOW_PICKER") end } }
	end
	if info.fin then
		local otra = accionCierre("ic-ruta")
		local texto = format(L["%s quedó completa. Elige qué sigue y la manada va contigo."], info.guia ~= "" and info.guia or L["Tu guía"])
		if otra and c.sig and c.sig.nombre then texto = format(L["%s quedó completa. Lo que sigue para tu nivel: %s."], info.guia ~= "" and info.guia or L["Tu guía"], c.sig.nombre) end
		return { fin = true, lobo = "aullando", tono = "acento", sobre = L["Fin del camino"], titulo = L["¡Terminaste tu guía!"], texto = texto,
			accion = otra or { texto = L["Elegir qué sigue"], icono = "ic-ruta", alClic = function() A.Fire("SHOW_PICKER") end },
			secundaria = otra and { texto = L["Elegir otra"], alClic = function() A.Fire("SHOW_PICKER") end } or nil }
	end
	if not info.num then
		-- «Cerrar mis misiones» abierta pero sin paso (lo que tenía quedó
		-- omitido o ya no está en tu registro): Seguir la vuelve a armar con
		-- tu registro de ahora (1.2.2), en vez de abrir un rastreador vacío.
		local liberar = deRuta("Liberar")
		if liberar and info.id == "mis-rutas/liberar" then
			return { icono = "ic-ruta", tono = "acento", sobre = L["Tu siguiente paso"], titulo = info.guia ~= "" and info.guia or L["Tu guía"],
				texto = L["Tu plan se quedó sin paso. Seguir lo vuelve a armar con las misiones que tienes ahora."],
				accion = { texto = L["Seguir"], icono = "ic-seguir", alClic = function()
					if A.Get("nav.arrow") == false then A.Set("nav.arrow", true) end
					K.Llamar(liberar)
				end } }
		end
		-- 1.2.6: sin paso vivo, lo mismo que dice el rastreador (antes decía
		-- «Tu guía está lista» y Seguir abría un rastreador vacío).
		-- 1.3.7: con el porqué y «Recuperar lo omitido» (91).
		local c2 = cierreFn and cierreFn()
		local recuperar = deRuta("Recuperar")
		if c2 and c2.recuperar and recuperar then
			return { lobo = "atento", tono = "acento", sobre = L["Tu siguiente paso"], titulo = info.guia ~= "" and info.guia or L["Tu guía"],
				texto = c2.recuperar.title and format(L["Omitiste «%s» y lo que sigue depende de eso. Recupéralo y la guía sigue."], c2.recuperar.title)
					or L["Omitiste pasos y lo que queda depende de ellos. Recupéralos y la guía sigue."],
				accion = { texto = L["Recuperar lo omitido"], icono = "ic-huella", alClic = function() recuperar(c2) end },
				secundaria = { texto = L["Elegir otra guía"], alClic = function() A.Fire("SHOW_PICKER") end } }
		end
		return { lobo = "atento", tono = "acento", sobre = L["Tu siguiente paso"], titulo = info.guia ~= "" and info.guia or L["Tu guía"],
			texto = L["Esta guía no tiene un paso para ti ahora: puede que hayas omitido lo que queda o que aún no te toque. Elige otra guía o vuelve a esta más adelante."],
			accion = { texto = L["Elegir otra guía"], icono = "ic-guia", alClic = function() A.Fire("SHOW_PICKER") end } }
	end
	local lineas = {}
	for i, m in ipairs(info.metas or {}) do lineas[i] = m.texto end
	-- El avance es uno solo, el de la barra: los pasos hechos de la guía
	-- (Engine.GetProgress, el mismo de la ventana de guía y de Rutas).
	local insignias = insigniasPaso(info)
	local d = {
		icono = VERBO[info.verbo] or "ic-ruta", tono = "acento", sobre = L["Tu siguiente paso"],
		titulo = info.titulo, texto = #lineas > 0 and table.concat(lineas, "\n") or nil, lineas = 4,
		insignias = insignias,
		accion = { texto = L["Seguir"], icono = "ic-seguir", alClic = seguirRuta },
		secundaria = { texto = L["Ver pasos"], alClic = verPasos },
		ayuda = L["Seguir muestra tu guía y la flecha, y cierra esta ventana para que las veas."],
	}
	if (info.todos or 0) > 0 then
		d.progreso = { actual = info.hechos, total = info.todos,
			texto = format(L["%s: %d de %d pasos hechos"], info.guia ~= "" and info.guia or L["Tu guía"], info.hechos, info.todos) }
		-- 1.2.7: cuánto te falta, por tu ritmo (AlfaRuta.Estimado).
		local falta = tiempoQueFalta()
		if falta then d.progreso.texto = d.progreso.texto .. DOT .. falta end
	end
	pasoVivo = { d = d, info = info }
	return d
end

-- 1.3.6: la misma tarjeta de la última vez con la distancia de ahora (lo
-- único que cambia cada segundo), o nil si no hay un paso en marcha.
local function distanciaPaso()
	if not pasoVivo then return nil end
	pasoVivo.d.insignias = insigniasPaso(pasoVivo.info)
	return pasoVivo.d
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
-- 3. Cerrar y recoger misiones
---------------------------------------------------------------------------

local function misionesAbiertas()
	local Q = C_QuestLog
	if not (Q and Q.GetNumQuestLogEntries) then return nil end
	local ok, _, n = pcall(Q.GetNumQuestLogEntries)
	return ok and num(n) or nil
end

local function misiones()
	local lista = {}
	-- 1.3.7 (105): con un paso en marcha, su camino en el mapa de Alfa, ya encuadrado.
	local verMapa = deRuta("VerEnMapa")
	if verMapa and pasoVivo then
		lista[#lista + 1] = { variante = "compacta", icono = "ic-mapa", titulo = L["Ver el camino en el mapa"],
			texto = L["El mapa de Alfa, en el lugar de tu flecha"],
			alClic = function() K.Llamar(verMapa) end,
			ayuda = L["Abre el mapa de Alfa encuadrado donde apunta la flecha, con el camino de tu guía."] }
	end
	local liberar, recoger = deRuta("Liberar"), deRuta("Recoger")
	local n = misionesAbiertas()
	if liberar and n ~= 0 then
		-- 1.3.7: «12 · 4 listas», como la página Ruta (123), y lo que dan tus
		-- listas juntas, y si con ellas subes de nivel (98).
		local fx = deRuta("XPListas")
		local xl = fx and select(2, pcall(fx)) or nil
		if type(xl) ~= "table" then xl = nil end
		local listas = xl and xl.n or (deRuta("Listas") and num((select(2, pcall(deRuta("Listas")))))) or 0
		local valor = n and tostring(n) or nil
		if valor and listas and listas > 0 then valor = valor .. DOT .. N.Plural(listas, L["%d lista"], L["%d listas"]) end
		local textoC = L["Completa o entrega las que tienes abiertas"]
		if xl and xl.n > 0 and xl.xp > 0 then
			textoC = xl.n == 1 and format(L["Tu misión lista da unos %s XP"], miles(xl.xp))
				or format(L["Tus %d misiones listas dan unos %s XP"], xl.n, miles(xl.xp))
			if xl.subes then textoC = textoC .. DOT .. L["¡con eso subes de nivel!"] end
		end
		lista[#lista + 1] = { variante = "compacta", icono = "ic-exito", titulo = L["Cerrar mis misiones"],
			texto = textoC, valor = valor,
			alClic = function() K.Llamar(liberar) end,
			ayuda = L["Arma el plan para cerrar las misiones de tu registro y te lleva a cada una."] }
	end
	if recoger then
		lista[#lista + 1] = { variante = "compacta", icono = "ic-misiones", titulo = L["Recoger misiones"],
			texto = L["Toma las de tu ruta que tienes cerca"],
			alClic = function() K.Llamar(recoger) end,
			ayuda = L["Te lleva a las misiones de tu ruta que ya puedes tomar."] }
	end
	-- 1.3.7: tu mazmorra (110) y, dentro de una, su siguiente jefe y tus
	-- misiones de ahí (111). Del área Mundo (AlfaMazmorras), protegido; solo
	-- se pide con Hoy a la vista (Tarjeta carga el Codex).
	local Mz = rawget(_G, "AlfaMazmorras")
	if type(Mz) == "table" and not (InCombatLockdown and InCombatLockdown()) then
		local dentro = type(Mz.Dentro) == "function" and select(2, pcall(Mz.Dentro)) or nil
		if type(dentro) == "table" then
			local partes = {}
			if type(dentro.jefe) == "table" and dentro.jefe.nombre then
				partes[#partes + 1] = format(L["Siguiente jefe: %s (%d de %d)"], dentro.jefe.nombre, (dentro.jefe.vencidos or 0) + 1, dentro.jefe.total or 0)
			end
			if (dentro.faltan or 0) > 0 then partes[#partes + 1] = N.Plural(dentro.faltan, L["Te falta %d misión aquí"], L["Te faltan %d misiones aquí"]) end
			lista[#lista + 1] = { variante = "compacta", icono = "ic-mazmorra", titulo = dentro.nombre or L["Tu mazmorra"],
				texto = #partes > 0 and table.concat(partes, DOT) or L["Ya venciste a todos sus jefes"],
				alClic = type(dentro.abrir) == "function" and function() pcall(dentro.abrir) end or nil }
		else
			local t = type(Mz.Tarjeta) == "function" and select(2, pcall(Mz.Tarjeta)) or nil
			if type(t) == "table" and t.titulo then
				local acc = type(t.accion) == "table" and t.accion or nil
				lista[#lista + 1] = { variante = "compacta", icono = "ic-mazmorra", titulo = t.titulo, texto = t.texto,
					-- (la acción va en el cuadro del ratón: «Llévame a la entrada» no cabe a la derecha)
					ayuda = acc and acc.texto or nil,
					alClic = (acc and type(acc.alClic) == "function" and function() pcall(acc.alClic) end)
						or (type(t.abrir) == "function" and function() pcall(t.abrir) end) or nil }
			end
		end
	end
	-- 1.2.7: «Una hora de caza»: Alfa elige lo que más rinde cerca de ti.
	-- 1.2.9: con «¿Cuánto tiempo tienes?» a la vista, ese plan ya lo incluye.
	local unaHora = deRuta("UnaHora")
	if unaHora and not N.Get("inicio", "horaPlan") then
		lista[#lista + 1] = { variante = "compacta", icono = "ic-reloj", titulo = L["Una hora de caza"],
			texto = L["Lo que más rinde cerca de ti"],
			alClic = function() K.Llamar(unaHora) end,
			ayuda = L["Alfa elige por ti: entregar las que tienes listas, cerrar las de esta zona o recoger misiones nuevas."] }
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
	local umbral = R.UmbralBolsas() -- 1.3.3: el mismo umbral que el aviso de Bolsas
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
	-- 1.2.9: comida y agua, después de que se te acabaron (M.Comida).
	local Co = M.Comida
	if Co and Co.Bajo() then
		local ec = Co.Estado()
		local faltan = { comida = ec.bajo.comida, agua = ec.bajo.agua }
		local titulo = (faltan.comida and faltan.agua and L["Te queda poca comida y agua"]) or (faltan.agua and L["Te queda poca agua"]) or L["Te queda poca comida"]
		lista[#lista + 1] = { clave = "comida", tono = "aviso", icono = "ic-comercio", titulo = titulo,
			texto = format(L["A tu nivel: %s"], Co.QueComprar(faltan)),
			accion = { texto = L["Llévame a comprar"], icono = "ic-flecha", alClic = function() Co.Ir() end } }
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

---------------------------------------------------------------------------
-- 3c. 1.3.3: «Mientras entrabas» (N.AlEntrar del Núcleo): lo que no salió al
-- entrar al juego para dejar la animación sola. Cada cosa con su acción y su
-- «Listo» (N.OlvidarAlEntrar); se repinta con ALFA_ALENTRAR. Vacía, no sale.
---------------------------------------------------------------------------

local function deNucleo(nombre)
	local f = rawget(N, nombre)
	return type(f) == "function" and f or nil
end

function P.AlEntrar()
	local f = deNucleo("AlEntrar")
	if not f then return {} end
	local ok, lista = pcall(f)
	return ok and type(lista) == "table" and lista or {}
end

local function olvidarAlEntrar(id)
	local f = deNucleo("OlvidarAlEntrar")
	if f and id ~= nil then pcall(f, id) end
end

local function tarjetasAlEntrar()
	local out = {}
	for _, o in ipairs(P.AlEntrar()) do
		if type(o) == "table" and (o.titulo or o.texto) then
			local id = o.id
			local d = { icono = o.icono or "ic-hoy", tono = "acento", titulo = o.titulo or "", texto = o.texto, lineas = 3,
				secundaria = { texto = L["Listo"], alClic = function() olvidarAlEntrar(id) end } }
			local a = type(o.accion) == "table" and o.accion or nil
			if a and type(a.alClic) == "function" then
				d.accion = { texto = a.texto or L["Ver"], icono = "ic-seguir", alClic = function()
					olvidarAlEntrar(id)
					K.Llamar(a.alClic)
				end }
			end
			out[#out + 1] = d
		end
	end
	return out
end
P.TarjetasAlEntrar = tarjetasAlEntrar

local function nuevoAlEntrar(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Mientras entrabas"]))
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 340, gap = ESP.m }), { espacio = ESP.s })
	function b:Llenar()
		local lista = tarjetasAlEntrar()
		self.Seccion:Set(L["Mientras entrabas"], { cuenta = #lista > 0 and #lista or nil })
		self.Rejilla:Llenar(lista)
		K.Mostrar(self, #lista > 0)
	end
	return b
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
-- 3b. Tu plan: la meta de ahora de Mis planes (AlfaPlanes, de la ruta)
---------------------------------------------------------------------------

local function planes()
	local Pl = rawget(_G, "AlfaPlanes")
	if type(Pl) == "table" and type(Pl.Tarjeta) == "function" then return Pl end
	return nil
end

local function nuevoPlan(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Tu plan"]))
	b.Tarjeta = b:Agregar(K.Tarjeta(b, { variante = "normal" }), { espacio = ESP.s })
	-- -> true si sigues un plan (la tarjeta sale)
	function b:Llenar()
		local Pl = planes()
		local ok, d = false, nil
		if Pl then ok, d = pcall(Pl.Tarjeta) end
		if not (ok and type(d) == "table" and d.plan) then
			K.Mostrar(self, false)
			return false
		end
		local id = d.plan.id
		local abrir = function() if type(Pl.Abrir) == "function" then K.Llamar(Pl.Abrir, id) end end
		self.Seccion:Set(L["Tu plan"], { cuenta = d.total > 0 and format(L["%d de %d"], d.hechas, d.total) or nil,
			enlace = { texto = L["Ver el plan"], alClic = abrir } })
		local t = { icono = d.icono or "ic-lista", tono = d.fin and "exito" or "acento", sobre = tostring(d.nombre or ""),
			titulo = d.titulo or "", texto = d.texto, alClic = abrir }
		if d.frac then t.progreso = { actual = floor(d.frac * 100 + 0.5), total = 100, texto = d.texto } t.texto = nil end
		if d.ir then t.accion = { texto = d.ir[1], icono = "ic-flecha", alClic = d.ir[2] } end
		if d.hecha then t.secundaria = { texto = L["Ya la hice"], alClic = d.hecha } end
		self.Tarjeta:Set(t)
		K.Mostrar(self, true)
		return true
	end
	return b
end

---------------------------------------------------------------------------
-- 4b. Buscar cerca: los lugares de siempre, a un clic (AlfaCerca, de la ruta)
---------------------------------------------------------------------------

-- Los de la fila, en este orden y con su nombre corto; el menú tiene los demás.
local RAPIDOS = { "flight", "innkeeper", "repair", "bank", "mailbox", "class" }
local CORTO = { flight = L["Vuelo"], innkeeper = L["Posada"], repair = L["Reparar"], bank = L["Banco"],
	mailbox = L["Buzón"], class = L["Mi entrenador"] }

local function cercaApi()
	local Ce = rawget(_G, "AlfaCerca")
	if type(Ce) == "table" and type(Ce.Ir) == "function" and type(Ce.Tipos) == "function" then return Ce end
	return nil
end

-- Los de la fila que sirven a este personaje: { tipo, nombre, icono }.
local function rapidos()
	local Ce = cercaApi()
	if not Ce or A.Get("rutas.cercaHoy") == false then return {} end
	local ok, tipos = pcall(Ce.Tipos)
	local hay = {}
	for _, t in ipairs(ok and type(tipos) == "table" and tipos or {}) do
		if type(t) == "table" and type(t.tipo) == "string" then hay[t.tipo] = t end
	end
	local out = {}
	for _, tipo in ipairs(RAPIDOS) do
		if hay[tipo] then out[#out + 1] = hay[tipo] end
	end
	return out
end

-- Lo que dice al pasar el ratón: el más cercano si ya se sabe (sin buscar).
local function infoCerca(tipo, nombre)
	return function()
		local Ce = cercaApi()
		local ok, ya = false, nil
		if Ce and type(Ce.Texto) == "function" then ok, ya = pcall(Ce.Texto, tipo) end
		if ok and type(ya) == "string" and ya ~= "" then return nombre, format(L["El más cercano: %s"], ya) end
		return nombre, L["Clic: la flecha te lleva al más cercano, por tiempo de camino."]
	end
end

local function nuevoCerca(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Seccion = K.Seccion(b, L["Buscar cerca"])
	b.botones = {}
	function b:Llenar()
		local lista = rapidos()
		self.Seccion:Set(L["Buscar cerca"], { enlace = { texto = L["Más lugares"], alClic = function(boton)
			local Ce = cercaApi()
			if Ce and type(Ce.Menu) == "function" then K.Llamar(Ce.Menu, boton) end
		end } })
		for i, t in ipairs(lista) do
			local bt = self.botones[i]
			if not bt then
				bt = K.Boton(self, "", nil, { tipo = "secundario", tam = "chico", conIcono = true })
				self.botones[i] = bt
			end
			local tipo = t.tipo
			bt:SetTexto(CORTO[tipo] or tostring(t.nombre or tipo))
			bt:SetIcono(type(t.icono) == "string" and t.icono or "ic-flecha")
			bt.alClic = function()
				local Ce = cercaApi()
				if Ce then K.Llamar(Ce.Ir, tipo) end
			end
			K.ConInfo(bt, infoCerca(tipo, tostring(t.nombre or CORTO[tipo] or tipo)))
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
			bt:SetAncho(nil)
			local w = bt:AnchoNatural()
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
	-- 300 de ancho mínimo: dos columnas en la ventana, sin textos cortados.
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 300, gap = ESP.s }), { espacio = ESP.s })
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
	-- Cada segundo: solo las tarjetas (su alto no cambia). Una tarjeta que
	-- llega o se va acomoda todo, también con la rejilla oculta (sin datos al
	-- abrir: si no, ya no volvía a salir).
	function b:Repintar()
		local lista = minis(self.Talento:IsShown())
		if #lista ~= #self.Rejilla.elementos then return true end
		if not self:IsShown() or not self.Rejilla:IsShown() then return end
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
			texto = L["Deja que la manada te vea en el mapa"], valor = L["Compartir"], colorValor = "acento",
			alClic = function() K.Llamar(Ma.PreguntarCompartir, function() P.Relayout() end) end,
			ayuda = L["Solo con quienes usan Alfa y aceptaron compartir. Tú decides."] }
	end
	local enManada, enGrupo = num(r.manada) or 0, num(r.grupo) or 0
	local texto = format(L["%d de la manada · %d en tu grupo"], enManada, enGrupo)
	local abrir = type(Ma.Abrir) == "function" and Ma.Abrir or (hay("manada") and function() N.Abrir("manada") end) or nil
	-- 1.3.7: a quién sigues, a qué distancia, y dejar de seguirlo de un clic (117).
	if type(r.siguiendo) == "string" and r.siguiendo ~= "" then
		texto = format(L["Sigues a %s"], r.siguiendo)
		local dist = distancia()
		if dist then texto = texto .. DOT .. dist end
		local dejar = rawget(Ma, "DejarDeSeguir")
		return { variante = "compacta", icono = "ic-manada", titulo = L["Tu manada"], texto = texto,
			valor = nil,
			alClic = function()
				if type(dejar) == "function" then K.Llamar(dejar) P.Relayout() elseif abrir then K.Llamar(abrir) end
			end,
			ayuda = L["Dejar de seguir"] .. ": " .. L["Un clic y dejas de seguirlo: la flecha vuelve a tu guía."] }
	end
	return { variante = "compacta", icono = "ic-manada", titulo = L["Tu manada"], texto = texto,
		valor = tostring(enManada + enGrupo), colorValor = (enManada + enGrupo) > 0 and "acento" or "texto",
		alClic = abrir and function() K.Llamar(abrir) end or nil,
		ayuda = L["Los lobos que usan Alfa y se dejan ver en el mapa, y tu grupo, que ves ahora."] }
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
		-- 1.3.7: con tus misiones listas y tu descanso (Subir.lua, 99 y 169).
		local Sb = M.Subir
		local d = Sb and Sb.Datos()
		local subir = d and d.segundos or e.subir
		local ayuda = { format(L["Te faltan %s XP para el nivel %d"], miles(e.falta), (e.nivel or 1) + 1) }
		if d and d.listas > 0 and d.listasXP > 0 then
			ayuda[#ayuda + 1] = d.listas == 1 and format(L["Tu misión lista da unos %s XP"], miles(d.listasXP))
				or format(L["Tus %d misiones listas dan unos %s XP"], d.listas, miles(d.listasXP))
		end
		local desc = Sb and Sb.Descanso(d)
		if desc then ayuda[#ayuda + 1] = desc end
		lista[#lista + 1] = { variante = "compacta", icono = "ic-nivel", titulo = L["Para subir de nivel"],
			texto = (Sb and Sb.Texto(d)) or format(L["Te faltan %s XP para el nivel %d"], miles(e.falta), (e.nivel or 1) + 1),
			valor = subir and (subir >= 360000 and L["más de 99 h"] or N.Duracion(subir, true)) or "\226\128\148",
			ayuda = table.concat(ayuda, "\n") }
		-- 1.3.7: tu descanso a la vista (99).
		if desc then
			lista[#lista + 1] = { variante = "compacta", icono = "ic-hoy", titulo = L["Descansado"], texto = desc,
				valor = format("%d%%", floor((e.descanso or 0) / math.max(1, e.xpMax or 1) * 100 + 0.5)), colorValor = "acento",
				ayuda = L["Lo que cazas da el doble de experiencia hasta gastar tu descanso. Se llena en una posada o en una ciudad."] }
		end
	end
	-- 1.3.7: tu reputación al día (177).
	local Rp = M.Reputacion
	local rep = Rp and Rp.Actual()
	if rep and not rep.maximo and rep.siguiente then
		lista[#lista + 1] = { variante = "compacta", icono = "ic-manada", titulo = rep.nombre, texto = Rp.Texto(rep),
			valor = rep.rangoNombre or "", colorValor = "acento",
			ayuda = rep.desbloquea and format(L["%s te da %s."], rep.siguiente, rep.desbloquea) or nil }
	end
	-- 1.3.7: tu tiempo jugado, sin chat (191).
	local J = M.Jugado
	local jd = N.Get("inicio", "jugado") ~= false and J and J.Datos()
	if jd then
		local partes = {}
		if jd.nivel then partes[#partes + 1] = format(L["En este nivel: %s"], N.Duracion(jd.nivel, true)) end
		partes[#partes + 1] = format(L["Por nivel: %s"], N.Duracion(jd.promedio, true))
		lista[#lista + 1] = { variante = "compacta", icono = "ic-reloj", titulo = L["Tiempo jugado"], texto = table.concat(partes, DOT),
			valor = J.Corto(jd.total),
			ayuda = L["Con este personaje, en total. Alfa lo pregunta al entrar sin escribir en tu chat."] }
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
		local umbral = R.UmbralBolsas()
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
		-- 1.3.6: «mejora de tu clase» en vez de «buff».
		t[#t + 1] = { L["Mejora de clase puesta"], "exito", "ic-aviso", L["Tu mejora de clase"], L["Lo que tu clase se pone antes de pelear está activo."] }
	elseif (b.estado == "falta" or b.estado == "poco") and b.nombre and not enAlertas.buff then
		t[#t + 1] = { format(L["Te falta %s"], b.nombre), "aviso", "ic-aviso", L["Tu mejora de clase"], L["Lánzalo antes de la siguiente pelea."] }
	end
	local d = st.descanso
	if not d.maximo then
		local pct = floor((d.pct or 0) + 0.5)
		if d.activo then
			-- 1.2.8: con menos de 1 % no dice «0 %».
			t[#t + 1] = { pct >= 1 and format(L["Descansando: %d %%"], pct) or L["Descansando"], "exito", "ic-hoy", L["Descanso"], L["En posadas y ciudades juntas XP descansada: ganas el doble por enemigo hasta gastarla."] }
		elseif (d.xp or 0) > 0 and pct >= 1 then
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
		-- Recién entrando no hay nada que contar: sale a los 5 minutos.
		K.Mostrar(self, e.dur >= DIARIO_MIN)
	end
	-- Cada segundo: true si ya toca mostrarlo (o esconderlo) y hay que acomodar.
	function b:Repintar()
		return (S.Estado().dur >= DIARIO_MIN) ~= (self:IsShown() and true or false)
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
	-- 1.3.3: con Bolsas, estas dos filas son sus ajustes (un solo aviso, el suyo).
	local deBolsas = conBolsas()
	local claveAviso = deBolsas and "bolsas.avisoLleno" or "inicio.recBolsas"
	local libres = deBolsas and { min = 1, max = 10, step = 1, key = "bolsas.avisoLibres", format = C.bolsasLibres.format }
		or { min = 0, max = 12, step = 1, key = "inicio.bolsasLibres", format = C.bolsasLibres.format }
	bol:Fila({ titulo = C.recBolsas.label, texto = deBolsas and L["Un solo aviso: el de tus bolsas, que también te dice qué vender."] or C.recBolsas.help,
		control = function(fila) return K.Interruptor(fila, { clave = claveAviso }) end })
	bol:Fila({ titulo = C.bolsasLibres.label, hija = true, activa = function() return N.Get(claveAviso:match("^(%w+)"), claveAviso:match("%.(.+)$")) ~= false end,
		control = deslizador(libres) })
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
					{ valor = "2", texto = L["Cada 2 niveles"] }, { valor = "1", texto = L["Cada nivel"] }, { valor = "off", texto = L["No [apagado]"] } } })
			end })
	end
	g[#g + 1] = ent
	-- 1.3.6: «la mejora de tu clase» en vez de «buff».
	local buf = K.GrupoAjustes(padre, { titulo = L["Mejora de clase fuera de combate"] })
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
	-- 1.2.9
	local tie = K.GrupoAjustes(padre, { titulo = L["Tu tiempo y tu camino al 60"] })
	tie:Fila({ titulo = C.horaPlan.label, texto = C.horaPlan.help, control = interruptor("horaPlan") })
	tie:Fila({ titulo = C.horaAuto.label, texto = C.horaAuto.help, hija = true, activa = encendido("horaPlan"), control = interruptor("horaAuto") })
	tie:Fila({ titulo = C.camino.label, texto = C.camino.help, control = interruptor("camino") })
	tie:Fila({ titulo = C.barraXP.label, texto = C.barraXP.help, control = interruptor("barraXP") })
	tie:Fila({ titulo = C.barraRep.label, texto = C.barraRep.help, control = interruptor("barraRep") })
	tie:Fila({ titulo = C.jugado.label, texto = C.jugado.help, control = interruptor("jugado") })
	g[#g + 1] = tie
	local maz = K.GrupoAjustes(padre, { titulo = L["Listo para la mazmorra"] })
	maz:Fila({ titulo = C.listoAuto.label, texto = C.listoAuto.help, control = interruptor("listoAuto") })
	maz:Fila({ titulo = C.listoDur.label, hija = true, activa = encendido("listoAuto"), control = deslizador(C.listoDur) })
	maz:Fila({ titulo = C.listoBolsas.label, hija = true, activa = encendido("listoAuto"), control = deslizador(C.listoBolsas) })
	maz:Fila({ titulo = C.listoComida.label, hija = true, activa = encendido("listoAuto"), control = deslizador(C.listoComida) })
	maz:Fila({ titulo = L["Revisar ahora"], texto = L["Lo que te falta para una mazmorra, en un aviso. También con /alfa listo."],
		control = boton(L["Revisar"], function() M.Listo.Revisar("boton") end) })
	g[#g + 1] = maz
	local com = K.GrupoAjustes(padre, { titulo = L["Comida y agua"] })
	com:Fila({ titulo = C.comidaAviso.label, texto = C.comidaAviso.help, control = interruptor("comidaAviso") })
	com:Fila({ titulo = C.comidaMin.label, hija = true, activa = encendido("comidaAviso"), control = deslizador(C.comidaMin) })
	g[#g + 1] = com
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
		-- 1.3.6: «la mejora de tu clase» en vez de «buff».
		K.Escribir(self.Nota.Texto, L["Alfa te avisa del equipo gastado, las bolsas llenas, lo que puedes entrenar, la mejora de tu clase, tu descanso, tu comida y lo que te falta para una mazmorra. Aquí eliges cuáles y cuándo."])
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
-- 3c. ¿Cuánto tiempo tienes? (1.2.9, M.Tiempo)
---------------------------------------------------------------------------

local TM = M.Tiempo
local OTRO = "otro"

local function opcionesHora()
	return { { valor = 30, texto = L["30 min"] }, { valor = 60, texto = L["1 h"] }, { valor = 120, texto = L["2 h"] },
		{ valor = OTRO, texto = L["Otro"], ayuda = L["Elige tus minutos con la barra de abajo."] } }
end

local function valorHora()
	local m = tonumber(N.Get("inicio", "horaMin")) or 60
	if P.horaOtro then return OTRO end
	for _, v in ipairs(TM.OPCIONES) do if v == m then return m end end
	return OTRO
end

local FUENTE = { diario = L["por tu diario"], guia = L["por tu guía"] }

-- Un paso del plan en una tarjeta compacta.
local function tarjetaDePaso(p, hecho)
	local titulo, txt = TM.Textos(p)
	return { variante = "compacta", icono = hecho and "ic-exito" or (p.icono or "ic-reloj"), tono = hecho and "exito" or nil,
		titulo = titulo, texto = txt, valor = hecho and L["Hecho"] or TM.Minutos(p.min),
		colorValor = hecho and "exito" or "textoSuave" }
end

local function nuevaHora(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["¿Cuánto tiempo tienes?"]))
	-- 1.3.3: el plan que venció sin terminar deja su nota (con «Listo»).
	b.Vencido = b:Agregar(K.Tarjeta(b, { variante = "normal" }), { espacio = ESP.s })
	b.Elegir = b:Agregar(K.Segmentos(b, { estilo = "segmentos", opciones = opcionesHora(), valor = 60, alCambiar = function(v)
		if v == OTRO then
			P.horaOtro = true
			P.Relayout()
		else
			P.horaOtro = false
			N.Set("inicio", "horaMin", v)
		end
	end }), { espacio = ESP.s })
	b.Elegir.alfaAnchoPropio = true
	b.Otro = b:Agregar(K.GrupoAjustes(b, {}), { espacio = ESP.s })
	b.Otro:Fila({ titulo = C.horaMin.label, texto = L["De 15 minutos a 4 horas."], control = deslizador(C.horaMin) })
	b.Ahora = b:Agregar(K.Tarjeta(b, { variante = "normal" }), { espacio = ESP.s })
	b.Pasos = b:Agregar(K.Rejilla(b, { min = 300, gap = ESP.s }), { espacio = ESP.s })
	-- El pie: el total y tu ritmo, y «Empezar».
	local pie = CreateFrame("Frame", nil, b)
	pie.Texto = K.Texto(pie, "nota", "textoSuave")
	pie.Boton = K.Boton(pie, L["Empezar"], function() if P.planHora then TM.Empezar(P.planHora) end end, { tipo = "primario", icono = "ic-seguir" })
	K.ConInfo(pie.Boton, L["Empezar"], L["La flecha te lleva al primer paso. En Hoy ves cuánto llevas y «Siguiente» pasa al que sigue."])
	function pie:Acomodar(ancho)
		local bw = self.Boton:AnchoNatural()
		self.Boton:SetAncho(bw)
		self.Boton:ClearAllPoints()
		self.Boton:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -6)
		local h = K.Parrafo(self.Texto, max(80, ancho - bw - ESP.base), 3)
		local alto = max(K.num(self.Boton:GetHeight(), 32), h + 6)
		self:SetSize(ancho, alto)
		return alto
	end
	b.Pie = b:Agregar(pie, { espacio = ESP.m })

	-- -> true si hay un plan en marcha (la tarjeta va arriba)
	function b:Llenar()
		if not N.Get("inicio", "horaPlan") then
			K.Mostrar(self, false)
			return false
		end
		K.Mostrar(self, true)
		local h = TM.Actual()
		local vencido = not h and TM.Vencido()
		if vencido then
			self.Vencido:Set({ icono = "ic-reloj", tono = "aviso", titulo = TM.TextoVencido(vencido),
				texto = L["Elige tu tiempo otra vez y arma uno nuevo cuando quieras."],
				accion = { texto = L["Listo"], icono = "ic-exito", alClic = function() TM.OlvidarVencido() end } })
		end
		K.Mostrar(self.Vencido, vencido and true or false)
		self.alfaFirma = h and (h.i .. ":" .. TM.Llevas(h)) or nil
		if h then
			local n = #h.pasos
			local p = h.pasos[h.i]
			self.Seccion:Set(L["Tu plan de juego"], { cuenta = format(L["Paso %d de %d"], h.i, n),
				enlace = { texto = L["Dejar el plan"], alClic = function() TM.Dejar() end } })
			local titulo, txt = TM.Textos(p)
			local llevas = TM.Llevas(h)
			self.Ahora:Set({ icono = p.icono or "ic-reloj", tono = "acento", sobre = format(L["Ahora · %s"], TM.Minutos(p.min)),
				titulo = titulo, texto = txt,
				progreso = { actual = h.i - 1, total = n, huellas = true,
					texto = format(L["Llevas %s de %s"], TM.Minutos(llevas), TM.Minutos(h.total)) },
				accion = { texto = L["Llévame"], icono = "ic-flecha", alClic = function() TM.Ir(p) end },
				secundaria = { texto = h.i >= n and L["Terminar"] or L["Siguiente"], alClic = function() TM.Siguiente() end },
				ayuda = L["«Llévame» pone la flecha en este paso; «Siguiente» lo da por hecho y te lleva al que sigue."] })
			local lista = {}
			-- Antes de una mazmorra: ¿llevas todo?
			if p.tipo == "mazmorra" and M.Listo then
				lista[#lista + 1] = { variante = "compacta", icono = "ic-mazmorra", titulo = L["Listo para la mazmorra"],
					texto = L["Equipo, bolsas, comida y lo de tu clase"], valor = L["Revisar"], colorValor = "acento",
					alClic = function() M.Listo.Revisar("boton", p.nombre) end }
			end
			for k = h.i + 1, n do lista[#lista + 1] = tarjetaDePaso(h.pasos[k]) end
			llenar(self.Pasos, lista)
			K.Mostrar(self.Ahora, true)
			K.Mostrar(self.Pasos, #lista > 0)
			K.Mostrar(self.Elegir, false)
			K.Mostrar(self.Otro, false)
			K.Mostrar(self.Pie, false)
			return true
		end
		self.Seccion:Set(L["¿Cuánto tiempo tienes?"], {})
		local v = valorHora()
		self.Elegir:SetValor(v)
		K.Mostrar(self.Elegir, true)
		K.Mostrar(self.Otro, v == OTRO)
		if v == OTRO then self.Otro:Refrescar() end
		local plan = TM.Armar(tonumber(N.Get("inicio", "horaMin")) or 60)
		P.planHora = plan
		local lista = {}
		for i, p in ipairs(plan.pasos) do lista[i] = tarjetaDePaso(p) end
		llenar(self.Pasos, lista)
		K.Mostrar(self.Pasos, #lista > 0)
		K.Mostrar(self.Ahora, false)
		local nota = format(L["Tu plan para %s, con tus minutos de verdad."], TM.Minutos(plan.total))
		if FUENTE[plan.fuente] then
			nota = format(L["Tu plan para %s: unos %d min por misión, %s."], TM.Minutos(plan.total), floor(plan.ritmo + 0.5), FUENTE[plan.fuente])
		end
		K.Escribir(self.Pie.Texto, nota)
		K.Mostrar(self.Pie, #lista > 0)
		return false
	end
	-- Cada segundo: los minutos que llevas cambian una vez por minuto.
	function b:Repintar()
		if not self:IsShown() then return end
		local h = TM.Actual()
		local firma = h and (h.i .. ":" .. TM.Llevas(h)) or nil
		return firma ~= self.alfaFirma
	end
	return b
end

---------------------------------------------------------------------------
-- 6b. Camino al 60 (1.2.9, M.Camino)
---------------------------------------------------------------------------

local CA = M.Camino

-- 1.4 -> "1.4"; los enteros sin decimal.
local function decimal(v)
	v = floor((tonumber(v) or 0) * 10 + 0.5) / 10
	if v == floor(v) then return tostring(floor(v)) end
	return format("%.1f", v)
end

local function horasTexto(h)
	if not h then return nil end
	if h >= 999 then return L["más de 999 h"] end
	return TM.Minutos(h * 60 >= 120 and floor(h + 0.5) * 60 or h * 60)
end

local function lineaHoy(r)
	local hoy = r.hoy or 0
	if hoy < 0.05 then return L["Hoy todavía no avanzas: ¡a cazar!"] end
	if decimal(hoy) == "1" then return L["Hoy avanzaste 1 nivel"] end
	return format(L["Hoy avanzaste %s niveles"], decimal(hoy))
end

local abrirCamino -- la ventana, abajo

local function datosCamino()
	local r = CA.Resumen()
	if not r then return nil end
	local lineas = {}
	if r.horas then
		lineas[#lineas + 1] = format(L["Unos %s de juego a tu ritmo (%s XP por hora)."], horasTexto(r.horas), miles(r.ritmo))
	else
		lineas[#lineas + 1] = L["Juega un rato y Alfa calcula cuánto te falta a tu ritmo."]
	end
	lineas[#lineas + 1] = lineaHoy(r)
	if r.dias then lineas[#lineas + 1] = r.dias == 1 and L["Como juegas, llegas en 1 día."] or format(L["Como juegas, llegas en unos %d días."], r.dias) end
	local faltan = decimal(r.faltan)
	return { icono = "ic-nivel", tono = "acento", sobre = L["Camino al 60"],
		titulo = faltan == "1" and L["Te falta 1 nivel para el 60"] or format(L["Te faltan %s niveles para el %d"], faltan, r.tope),
		texto = table.concat(lineas, "\n"), lineas = 4,
		progreso = { actual = floor(r.frac * 10), total = r.tope * 10, texto = format(L["Nivel %s de %d"], decimal(r.frac), r.tope) },
		accion = { texto = L["Ver el camino"], icono = "ic-ruta", alClic = function() abrirCamino() end },
		ayuda = L["Las guías y mazmorras de tu nivel al 60, y cuánto avanzas cada día."] }
end

local function nuevoCamino(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Tarjeta = b:Agregar(K.Tarjeta(b, { variante = "normal" }))
	function b:Llenar()
		local d = N.Get("inicio", "camino") and datosCamino() or nil
		self.alfaFirma = d and (d.titulo .. (d.texto or "")) or nil
		if d then self.Tarjeta:Set(d) end
		K.Mostrar(self, d ~= nil)
	end
	function b:Repintar()
		if not self:IsShown() then return end
		local d = N.Get("inicio", "camino") and datosCamino() or nil
		return (d and (d.titulo .. (d.texto or "")) or nil) ~= self.alfaFirma
	end
	return b
end

-- La ventana: lo detallado va aparte (Hoy queda compacta).
local VC = {}
P.Camino = VC

local function llenarCamino()
	local v = VC.v
	if not (v and v:IsShown()) then return end
	local d = datosCamino()
	if d then
		d.accion = nil
		VC.resumen:Set(d)
	else
		VC.resumen:Set({ lobo = "aullando", tono = "exito", titulo = L["¡Ya llegaste al 60!"], texto = L["La manada aúlla por ti."] })
	end
	local ritmo = CA.Ritmo()
	local tramos = d and CA.Tramos() or {}
	local lista = {}
	for _, t in ipairs(tramos) do
		local xp = 0
		for l = t.desde, t.hasta do xp = xp + (CA.XP[l] or 0) end
		local txt = t.titulo
		if #t.mazmorras > 0 then
			local nombres = {}
			for _, m in ipairs(t.mazmorras) do nombres[#nombres + 1] = m.nombre end
			txt = txt .. DOT .. table.concat(nombres, ", ")
		end
		lista[#lista + 1] = { variante = "compacta", icono = #t.mazmorras > 0 and "ic-mazmorra" or "ic-ruta",
			titulo = t.desde == t.hasta and format(L["Nivel %d: %s"], t.desde, t.zona or t.titulo)
				or format(L["Niveles %d a %d: %s"], t.desde, t.hasta, t.zona or t.titulo),
			texto = txt, valor = ritmo and horasTexto(xp / ritmo) or nil }
	end
	llenar(VC.rejTramos, lista)
	K.Mostrar(VC.secTramos, #lista > 0)
	K.Mostrar(VC.rejTramos, #lista > 0)
	local mz = {}
	for _, m in ipairs(d and CA.Mazmorras() or {}) do
		mz[#mz + 1] = { variante = "compacta", icono = "ic-mazmorra", titulo = m.nombre,
			texto = format(L["Mejor a nivel %d · niveles %d a %d"], m.nivel, m.min, m.max), valor = format(L["Nv %d"], m.nivel) }
	end
	llenar(VC.rejMaz, mz)
	K.Mostrar(VC.secMaz, #mz > 0)
	K.Mostrar(VC.rejMaz, #mz > 0)
	local dias = {}
	for _, x in ipairs(CA.Dias(7)) do
		dias[#dias + 1] = { variante = "compacta", icono = "ic-reloj", titulo = x.hoy and L["Hoy"] or S.Dia(x.t),
			texto = format(L["%s de juego"], TM.Minutos(x.seg / 60)),
			valor = x.niveles >= 0.05 and ("+" .. decimal(x.niveles)) or "0", colorValor = x.niveles >= 0.05 and "acento" or "textoSuave",
			ayuda = format(L["%s niveles · %s XP"], decimal(x.niveles), miles(x.xp)) }
	end
	llenar(VC.rejDias, dias)
	K.Mostrar(VC.secDias, #dias > 0)
	K.Mostrar(VC.rejDias, #dias > 0)
	K.Mostrar(VC.vacio, d ~= nil and #lista == 0)
	if VC.acomodar then VC.acomodar() end
end
VC.Llenar = llenarCamino

abrirCamino = function()
	if not VC.v then
		local v = K.Ventana({ nombre = "AlfaInicioCamino", titulo = L["Camino al 60"], subtitulo = L["De tu nivel al 60, a tu ritmo"],
			icono = "ic-nivel", ancho = 640, alto = 620, desplazar = true })
		VC.v = v
		local p = K.Pila(v.Cuerpo, { espacio = ESP.base })
		VC.pila = p
		VC.resumen = p:Agregar(K.Tarjeta(p, { variante = "normal" }))
		VC.secTramos = p:Agregar(K.Seccion(p, L["Tu ruta, guía por guía"]), { espacio = ESP.l })
		VC.rejTramos = p:Agregar(K.Rejilla(p, { min = 420, gap = ESP.s }), { espacio = ESP.s })
		VC.secMaz = p:Agregar(K.Seccion(p, L["Mazmorras en el camino"]), { espacio = ESP.l })
		VC.rejMaz = p:Agregar(K.Rejilla(p, { min = 420, gap = ESP.s }), { espacio = ESP.s })
		VC.secDias = p:Agregar(K.Seccion(p, L["Tus días de caza"]), { espacio = ESP.l })
		VC.rejDias = p:Agregar(K.Rejilla(p, { min = 260, gap = ESP.s }), { espacio = ESP.s })
		-- 1.3.6: sin guías, qué hacer: puede que la instalación esté incompleta;
		-- «Revisar Alfa» abre el diagnóstico (/alfa diagnostico de Alfa_Bienvenida).
		VC.vacio = p:Agregar(K.Vacio(p, { lobo = "dormido", titulo = L["Todavía no hay guías para tu camino"],
			texto = L["No encontramos las guías de tu facción. Puede que la instalación de Alfa haya quedado incompleta: «Revisar Alfa» te dice qué falta y cómo arreglarlo."],
			accion = { texto = L["Revisar Alfa"], icono = "ic-buscar", alClic = function()
				if rawget(_G, "AlfaBienvenida") and type(A.RunCommand) == "function" then
					A.RunCommand("diagnostico")
				else
					N.Abrir("bienvenida")
				end
			end } }), { espacio = ESP.l })
		VC.acomodar = function()
			if not (v:IsShown() and VC.pila) then return end
			local ancho = v:AnchoCuerpo()
			local h = VC.pila:Acomodar(ancho)
			VC.pila:ClearAllPoints()
			VC.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -v.margen)
			v:SetAltoContenido(h + 2 * v.margen)
		end
		v.alAcomodar = VC.acomodar
	end
	VC.v:Abrir()
	llenarCamino()
	K.Despues(0.05, VC.acomodar)
end
P.AbrirCamino = function() abrirCamino() end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

-- Una guía que no terminó (la de "¡Terminaste tu guía!" ya no está en marcha).
local function enGuia(paso) return paso ~= nil and not paso.fin end

-- El orden de arriba de la pila del tablero. Sin guía ni plan: los caminos
-- en grande primero (la portada). Con una guía: tu siguiente paso, tus
-- misiones y tu plan; con solo un plan, tu plan primero. En los dos casos
-- los caminos bajan a la fila compacta. Lo de abajo (t.Extra) no se mueve.
-- 1.2.9: «¿Cuánto tiempo tienes?» va junto a tus misiones; con su plan en
-- marcha, hasta arriba (es lo que estás haciendo).
local ORDEN = {
	guia = { "accion", "opciones", "hora", "rejilla", "plan", "otra", "portada" },
	plan = { "plan", "accion", "opciones", "hora", "rejilla", "otra", "portada" },
	nada = { "portada", "accion", "opciones", "hora", "rejilla", "plan", "otra" },
	hora = { "hora", "accion", "opciones", "rejilla", "plan", "otra", "portada" },
}

local function ordenar(guia, plan, hora)
	local E = P.entradas
	local orden, ya = {}, {}
	for _, k in ipairs(ORDEN[hora and "hora" or (guia and "guia" or (plan and "plan" or "nada"))]) do
		if E[k] then orden[#orden + 1] = E[k] ya[E[k]] = true end
	end
	-- Lo que el Kit tenga además no se pierde; lo de abajo (t.Extra) al final.
	for _, e in ipairs(P.tablero.bloques) do
		if not ya[e] and e ~= E.extra then orden[#orden + 1] = e ya[e] = true end
	end
	if E.extra then orden[#orden + 1] = E.extra end
	P.tablero.bloques = orden
	K.Mostrar(P.portada, not (guia or plan or hora))
	K.Mostrar(P.otra, (guia or plan or hora) and true or false)
end

local function llenarTodo()
	R.Leer()
	local paso = tarjetaPaso()
	local plan = P.plan:Llenar()
	local hora = P.hora:Llenar()
	P.enGuia = enGuia(paso)
	P.enHora = hora
	ordenar(P.enGuia, plan, hora)
	P.portada:Llenar()
	P.otra:Llenar()
	P.firmaPaso = firmaPaso(paso)
	P.tablero:SetAccion(paso)
	-- Con solo un plan arriba, tus misiones llevan su título (si no, se verían
	-- como parte del plan); junto a la tarjeta del paso no lo necesitan.
	P.tablero:SetOpciones(misiones(), (plan and not P.enGuia) and L["Tus misiones"] or false)
	local lista = alertas()
	P.firmaAlertas = firmaAlertas(lista)
	P.alEntrar:Llenar()
	P.alertas:Llenar(lista)
	P.cerca:Llenar()
	P.clase:Llenar()
	P.numeros:Llenar()
	P.camino:Llenar()
	P.revision:Llenar(lista)
	P.diario:Llenar()
	P.ajustes:Llenar()
end

local function construir(view)
	P.view = view
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "accion", min = 256 })
	P.tablero = t
	-- La portada, tu plan y la fila compacta de los caminos van en la pila
	-- del tablero, junto a la tarjeta grande: ordenar() los acomoda.
	P.portada = nuevaPortada(t)
	P.plan = nuevoPlan(t)
	P.otra = nuevaOtra(t)
	P.hora = nuevaHora(t)
	local E = { portada = { b = P.portada, sangria = 0 }, plan = { b = P.plan, sangria = 0 }, otra = { b = P.otra, sangria = 0 },
		hora = { b = P.hora, sangria = 0 } }
	for _, e in ipairs(t.bloques) do
		if e.b == t.Accion then E.accion = e
		elseif e.b == t.Opciones then E.opciones = e
		elseif e.b == t.Rejilla then E.rejilla = e
		elseif e.b == t.Extra then E.extra = e end
	end
	P.entradas = E
	ordenar(false, false, false)
	P.alEntrar = t:AgregarBloque(nuevoAlEntrar(t.Extra))
	P.alertas = t:AgregarBloque(nuevoAlertas(t.Extra))
	P.cerca = t:AgregarBloque(nuevoCerca(t.Extra))
	P.clase = t:AgregarBloque(nuevaClase(t.Extra))
	P.numeros = t:AgregarBloque(nuevoNumeros(t.Extra))
	P.camino = t:AgregarBloque(nuevoCamino(t.Extra))
	P.revision = t:AgregarBloque(nuevaRevision(t.Extra), { espacio = ESP.xl })
	P.diario = t:AgregarBloque(nuevoDiario(t.Extra))
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
-- 1.3.6: las alertas y la tarjeta del paso completa se revisan cada 3 s
-- (CADA_COMPLETO); en los otros segundos solo la distancia de la tarjeta. Un
-- paso nuevo o una guía nueva ya rehacen la página por su mensaje (STEP_CHANGED...).
-- P.Pintar() (lo llama Recordatorios.lua cuando cambia algo) revisa todo.
local CADA_COMPLETO = 3
local function pintar(completo)
	local view = P.view
	if not (view and view:IsVisible()) or P.acomodando or not P.tablero then return end
	local paso, mirar
	if completo then
		local lista = alertas()
		if firmaAlertas(lista) ~= P.firmaAlertas then return relayoutPronto() end
		paso, mirar = tarjetaPaso(), true
	elseif pasoVivo then
		paso, mirar = distanciaPaso(), true
	end
	-- Una guía que empieza o termina cambia el orden de arriba.
	if mirar and enGuia(paso) ~= P.enGuia then return relayoutPronto() end
	local firma = mirar and firmaPaso(paso) or P.firmaPaso
	if firma ~= P.firmaPaso then
		-- Solo cambió la distancia: la tarjeta se acomoda sola si su alto no cambia.
		local t = P.tablero
		local antes = K.num(t.Accion:GetHeight(), 0)
		P.firmaPaso = firma
		if not paso or not t.Accion:IsShown() then return relayoutPronto() end
		t.Accion:Set(paso)
		if t.Accion:Acomodar(K.num(t.Accion:GetWidth(), N.AnchoPagina())) ~= antes then return relayoutPronto() end
	end
	if P.numeros:Repintar() or P.clase:Repintar() or P.diario:Repintar() or P.hora:Repintar() or P.camino:Repintar() then return relayoutPronto() end
end
function P.Pintar() return pintar(true) end
-- 1.3.7: las piezas de Hoy, para el banco.
P.TarjetaPaso, P.Misiones, P.Numeros = tarjetaPaso, misiones, numeros

-- 1.3.6: el latido de cada segundo; uno de cada CADA_COMPLETO revisa todo.
local function latido()
	P.tick = (P.tick or 0) + 1
	return pintar(P.tick % CADA_COMPLETO == 0)
end

function P.AlMostrar()
	if P.ticker then P.ticker:Cancel() end
	CL.Sucio()
	P.tick = 0 -- 1.3.6: la revisión completa, a los 3 s de abrir
	P.ticker = N.Ticker("inicio.pagina", 1, latido)
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
for _, msg in ipairs({ "STEP_CHANGED", "GUIDE_CHANGED", "GUIDE_COMPLETED", "TABS_CHANGED", "INICIO_DIARIO", "ALFA_REEMPLAZO", "ALFA_CURACION_ASISTENTE", "ALFA_PLAN", "INICIO_HORA",
	"ALFA_ALENTRAR" }) do
	A.On(msg, relayoutPronto)
end
-- Otra rama (o nivel) cambia el rol y las tarjetas de la clase.
A.On("GEAR_UPDATED", function(what)
	if what == "spec" or what == "level" then relayoutPronto() end
end)
A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" then return end
	if path == "inicio.verDiario" or path == "inicio.verAjustes" or path == "curacion.activo" or path == "manada.compartir"
		or path == "rutas.cercaHoy"
		or path == "inicio.horaPlan" or path == "inicio.horaMin" or path == "inicio.camino" or path == "inicio.comidaAviso"
		or path:find("^gear%.spec") then
		relayoutPronto()
	elseif path:find("^inicio%.") and P.ajustes and P.ajustes.grupos then
		for _, g in ipairs(P.ajustes.grupos) do g:Refrescar() end
	end
end)
A.RegisterEvent("PLAYER_TALENT_UPDATE", relayoutPronto)
A.RegisterEvent("TRAIT_CONFIG_UPDATED", relayoutPronto)
A.RegisterEvent("PLAYER_LEVEL_UP", (N.TrasNivel or function(_, f) return f end)("inicio.pagina", relayoutPronto)) -- 1.3.7: tras la animación del juego
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

---------------------------------------------------------------------------
-- 1.2.9: lo que Inicio ofrece a los demás, lo que Lya sabe contar y los comandos
---------------------------------------------------------------------------

--   AlfaInicio.RevisarMazmorra(nombre) -> faltas   «Listo para la mazmorra» (el aviso con lo que falta)
--   AlfaInicio.Faltas() -> { { clave, texto, ir }, ... }   lo mismo, sin aviso
--   AlfaInicio.Comida() -> comida, agua           lo que llevas
--   AlfaInicio.TengoTiempo(minutos) -> plan        el plan para ese tiempo (sin empezarlo)
--   AlfaInicio.Plan() -> plan en curso | nil
--   AlfaInicio.Camino()                            abre «Camino al 60»
AlfaInicio = type(rawget(_G, "AlfaInicio")) == "table" and rawget(_G, "AlfaInicio") or {}
AlfaInicio.RevisarMazmorra = function(nombre) return M.Listo.Revisar("boton", nombre) end
AlfaInicio.Faltas = function() return M.Listo.Faltas() end
AlfaInicio.Comida = function() return M.Comida.Contar() end
AlfaInicio.TengoTiempo = function(minutos) return M.Tiempo.Armar(minutos) end
AlfaInicio.Plan = function() return M.Tiempo.Actual() end
AlfaInicio.Camino = function() P.AbrirCamino() end
-- 1.3.8: para el Escritorio de Alfa (dos pantallas, Alfa_Bienvenida/EscritorioPaneles.lua):
-- lo mismo que pinta Hoy, sin armar la página.
AlfaInicio.Paso = function() return pasoActual() end
AlfaInicio.Alertas = function() return alertas() end
AlfaInicio.Numeros = function() return numeros() end
AlfaInicio.Distancia = function() return distancia() end
AlfaInicio.Sesion = function() return S.Estado() end
AlfaInicio.Jugado = function() return M.Jugado and M.Jugado.Datos() or nil end

A.RegisterCommand("camino", function() P.AbrirCamino() end, L["tu camino al 60"], true)

A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) ~= "table" or type(Lya.Ensenar) ~= "function" then return end
	for _, q in ipairs({
		{ id = "inicio.hora", icono = "ic-reloj", pregunta = L["Tengo poco tiempo, ¿qué hago?"],
			respuesta = L["En Hoy, en «¿Cuánto tiempo tienes?», elige 30 minutos, 1 hora, 2 o los que quieras. Armo tu plan con tu ritmo y, con «Empezar», la flecha te lleva paso por paso."] },
		{ id = "inicio.camino", icono = "ic-nivel", pregunta = L["¿Cuánto me falta para el 60?"],
			respuesta = L["Mira «Camino al 60» en Hoy: cuántas horas te faltan a tu ritmo y cuánto avanzaste hoy. «Ver el camino» te dice qué guías y mazmorras te tocan."] },
		{ id = "inicio.listo", icono = "ic-mazmorra", pregunta = L["¿Estoy listo para la mazmorra?"],
			respuesta = L["Al entrar o al juntarse tu grupo reviso tu equipo, tus bolsas, tu comida y lo de tu clase. Si falta algo te digo qué y te llevo a conseguirlo. También con /alfa listo."] },
		{ id = "inicio.comida", icono = "ic-comercio", pregunta = L["¿Qué comida y agua compro?"],
			respuesta = L["Cuando se te acaban te digo qué te conviene a tu nivel y te llevo al vendedor más cercano. El agua solo si usas maná."] },
	}) do
		q.modulo = "inicio"
		pcall(Lya.Ensenar, q)
	end
end)
