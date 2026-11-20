-- Alfa - Rutas: la página Ruta de la ventana de Alfa (toxic3000 / La Jauría).
-- GPL-3.0.
--
-- Un Tablero del Kit (docs/KIT.md), de arriba abajo:
--   1. lo que conviene ahora, en grande: entregar tus misiones listas (si
--      tienes varias), seguir tu guía o, sin guía, "¿Qué quieres hacer?";
--   2. las otras opciones en tarjetas: el asistente, cerrar tus misiones,
--      recoger las de cerca, la biblioteca de guías, buscar cerca (Cerca.lua)
--      y tu ruta;
--   3. tu plan de misiones (VistaMisiones.lua);
--   4. tus planes (VistaPlanes.lua: listas de metas propias y plantillas)
--      y tus rutas propias, en árbol (VistaArbol.lua);
--   5. los ajustes de la ruta: solo las misiones de tu ruta, aceptar y
--      entregar solas, evitar las de grupo y cuántos niveles arriba; y los
--      de buscar cerca (el botón del rastreador, la fila de Hoy, el aviso).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K
local Cr = M.Cerrar

local format, floor, ipairs = string.format, math.floor, ipairs

local vista
local function rehacer() if vista then N.RehacerPagina(vista) end end
M.Rehacer = rehacer

local function E() return A.Engine end

local function guiaActual()
	local e = E()
	local g = e and e.GetGuide and e.GetGuide()
	if not g then return nil end
	local done, total = 0, 0
	if e.GetProgress then done, total = e.GetProgress() end
	return g, done or 0, total or 0
end

-- 1. La acción grande.
local function accion()
	local listas = Cr.ListasAhora()
	local g, done, total = guiaActual()
	if listas >= 3 then
		return { icono = "ic-misiones", tono = "exito", sobre = L["Lo que más conviene ahora"],
			titulo = format(L["Tienes %d misiones listas para entregar"], listas),
			texto = L["Alfa arma la ruta más corta para cobrarlas, junta por PNJ. La flecha usa vuelos y tu piedra de hogar cuando conviene, y te avisa si una entrega queda lejos."],
			estado = { texto = format(L["%d listas"], listas), tono = "exito" },
			accion = { texto = L["Entregarlas ahora"], icono = "ic-seguir", alClic = function() Cr.Ahora("listas") end },
			secundaria = { texto = L["Cerrar todas mis misiones"], alClic = function() Cr.Ahora("todas") end } }
	end
	if g then
		local u = A.UI
		return { icono = "ic-huella", tono = "acento", sobre = L["Tu guía"],
			titulo = u and u.GuideLabel and u.GuideLabel(g) or g.title,
			texto = total > 0 and format(L["%d de %d pasos hechos. El rastreador te dice el siguiente y la flecha te lleva."], done, total)
				or L["El rastreador te dice el siguiente paso y la flecha te lleva."],
			-- Un solo número, los pasos (como el rastreador): sin un % aparte.
			progreso = total > 0 and { actual = done, total = total, huellas = true,
				texto = total - done == 1 and L["Falta 1 paso"] or format(L["Faltan %d pasos"], total - done) } or nil,
			accion = { texto = L["Mostrar mi guía"], icono = "ic-seguir", alClic = function() M.Empezar() end },
			secundaria = { texto = L["¿Qué quieres hacer?"], alClic = function() M.Asistente.Abrir() end } }
	end
	return { lobo = "atento", tono = "acento", sobre = L["Empieza aquí"], titulo = L["¿Qué quieres hacer hoy?"],
		texto = L["Subir de nivel, profesiones, hacer oro o mazmorras: dos clics y Alfa te lleva."],
		accion = { texto = L["Elegir mi camino"], icono = "ic-seguir", alClic = function() M.Asistente.Abrir() end } }
end

-- 2. Las otras opciones.
local function opciones()
	local Cp = M.Motor("Compat")
	local enLog = #(Cp and Cp.GetLogQuests and Cp.GetLogQuests() or {})
	local listas = Cr.ListasAhora()
	local out = {}
	out[#out + 1] = { icono = "ic-lobo", titulo = L["¿Qué quieres hacer?"], texto = L["Subir de nivel, profesiones, oro o mazmorras."],
		alClic = function() M.Asistente.Abrir() end }
	if enLog > 0 then
		out[#out + 1] = { icono = "ic-misiones", tono = "exito", titulo = L["Cerrar mis misiones"],
			texto = listas > 0 and format(L["%d en tu registro, %d listas: termínalas y entrégalas en el orden más corto."], enLog, listas)
				or format(L["%d en tu registro: termínalas y entrégalas en el orden más corto."], enLog),
			alClic = function() Cr.Ahora() end }
	end
	out[#out + 1] = { icono = "ic-misiones", titulo = L["Recoger misiones"], texto = L["Toma las mejores de cerca que ya puedes hacer."],
		alClic = function() M.Recoger.Ahora() end }
	out[#out + 1] = { icono = "ic-guia", titulo = L["Biblioteca de guías"], texto = L["La recomendada para ti y todas las demás."],
		alClic = function() M.Biblioteca.Abrir() end }
	if M.Cerca then
		out[#out + 1] = { icono = "ic-cerca", titulo = L["Buscar cerca"], texto = L["El maestro de vuelo, la posada, reparar, el banco y más, con la flecha."],
			alClic = function(tarjeta) M.Cerca.Menu(tarjeta) end }
	end
	-- 1.3.0: el circuito de la zona, «Llévame a…» y las grises que puedes soltar.
	if M.Circuito and A.Get(M.ID .. ".circuito") ~= false then
		out[#out + 1] = { icono = "ic-ruta", titulo = L["Circuito de la zona"], texto = L["Todas las misiones de aquí en el mejor orden, con la flecha."],
			alClic = function() M.Circuito.Ahora() end }
	end
	if M.Viaje and A.Get(M.ID .. ".llevame") ~= false then
		out[#out + 1] = { icono = "ic-huella", titulo = L["Llévame a..."], texto = L["A cualquier lugar: vuelos, barcos, zepelines, portales y a pie."],
			alClic = function() M.Viaje.Abrir() end }
	end
	local grises = M.Grises and M.Grises.Cuantas() or 0
	if grises > 0 then
		out[#out + 1] = { icono = "ic-misiones", tono = "aviso", titulo = L["Misiones grises"],
			texto = format(grises == 1 and L["%d no vale la pena: suéltala para hacer espacio."] or L["%d no valen la pena: suéltalas para hacer espacio."], grises),
			alClic = function() M.Grises.Abrir() end }
	end
	local r = M.RutaActiva() or M.RutaEditada()
	if r and #r.tramos > 0 then
		out[#out + 1] = { icono = "ic-ruta", titulo = r.nombre, texto = format(L["Tu ruta de %d tramos."], #r.tramos),
			alClic = function() M.Seguir(r) end }
	end
	return out
end

-- 5. Los ajustes.
local function ajustes(padre)
	local g = K.GrupoAjustes(padre, { titulo = L["Cómo trabaja tu ruta"] })
	-- Aceptar y entregar (las de la guía, todas o solo las de tu ruta): en
	-- Ajustes > Misiones, con las demás misiones (1.2.0).
	g:Fila({ titulo = L["Aceptar y entregar misiones"],
		texto = L["Las de tu ruta, las de la guía o todas: se eligen en Ajustes > Misiones, con lo demás de las misiones."],
		control = function(f) return K.Boton(f, L["Abrir Misiones"], function() N.Abrir("questing") end, { tipo = "secundario" }) end })
	g:Fila({ titulo = L["Evitar misiones de grupo"],
		texto = L["Al armar tus rutas, Alfa deja fuera las que piden élites."],
		control = function(f) return K.Interruptor(f, { clave = M.ID .. ".evitarGrupo" }) end })
	g:Fila({ titulo = L["Niveles arriba del tuyo"],
		texto = L["Qué tan difíciles pueden ser las misiones que Alfa elige (siempre de las que ya puedes tomar)."],
		control = function(f)
			local d = K.Deslizador(f, { min = 1, max = 4, paso = 1, clave = M.ID .. ".margen", formato = function(v) return format(L["+%d"], v) end })
			d.alfaAnchoFila = 200
			return d
		end })
	-- El rastreador es de la ruta (no de buscar cerca).
	g:Fila({ titulo = L["Mostrar más en el seguimiento"],
		texto = L["De fábrica el seguimiento muestra solo lo que estás haciendo; encendido, muestra el paso completo con sus notas."],
		control = function(f) return K.Interruptor(f, { clave = M.ID .. ".seguimientoCompleto" }) end })
	return g
end

-- Los de buscar cerca (Cerca.lua).
local function ajustesCerca(padre)
	local g = K.GrupoAjustes(padre, { titulo = L["Buscar cerca y tus planes"] })
	g:Fila({ titulo = L["Botón «Buscar cerca» en el rastreador"],
		texto = L["La lupa de la cabecera del rastreador abre el menú. También: /alfa cerca o tu tecla."],
		control = function(f) return K.Interruptor(f, { clave = M.ID .. ".cercaBoton" }) end })
	g:Fila({ titulo = L["«Buscar cerca» en la página Hoy"],
		texto = L["Una fila con vuelo, posada, reparar, banco, buzón y tu entrenador, a un clic."],
		control = function(f) return K.Interruptor(f, { clave = M.ID .. ".cercaHoy" }) end })
	g:Fila({ titulo = L["Aviso al poner la flecha"],
		texto = L["Un aviso corto con el lugar, su zona y el tiempo de camino."],
		control = function(f) return K.Interruptor(f, { clave = M.ID .. ".cercaAviso" }) end })
	g:Fila({ titulo = L["Mis planes: la flecha va sola al siguiente lugar"],
		texto = L["Cuando la meta de ahora de tu plan es un lugar, la flecha lo toma sin que hagas clic."],
		control = function(f) return K.Interruptor(f, { clave = M.ID .. ".planFlecha" }) end })
	return g
end

local function construir(view)
	vista = view
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado", tituloOpciones = L["Otras opciones"], min = 200 })
	local misiones = t:AgregarBloque(M.BloqueMisiones(t.Extra, rehacer))
	local planes = t:AgregarBloque(M.BloquePlanes(t.Extra, rehacer), { espacio = K.ESP.xl })
	local rutas = t:AgregarBloque(M.BloqueRutas(t.Extra, rehacer), { espacio = K.ESP.xl })
	local grupo = t:AgregarBloque(ajustes(t.Extra), { espacio = K.ESP.xl })
	local grupoCerca = M.Cerca and t:AgregarBloque(ajustesCerca(t.Extra), { espacio = K.ESP.l }) or nil
	K.EnPagina(view, t, function()
		t:SetAccion(accion())
		t:SetOpciones(opciones(), L["Otras opciones"])
		misiones:Llenar()
		planes:Llenar()
		rutas:Llenar()
		grupo:Refrescar()
		if grupoCerca then grupoCerca:Refrescar() end
	end)
end

-- Lo que cambia en el juego se ve en la página abierta.
local pendiente = false
local function luego()
	if pendiente or not (vista and vista:IsVisible()) then return end
	pendiente = true
	A.After(0.4, function() pendiente = false rehacer() end)
end
A.RegisterEvent("QUEST_TURNED_IN", luego)
A.RegisterEvent("QUEST_ACCEPTED", luego)
A.RegisterEvent("QUEST_REMOVED", luego)
A.RegisterEvent("BAG_UPDATE_DELAYED", luego)
A.On("GUIDE_CHANGED", luego)
A.On("STEP_CHANGED", luego)
M.Escuchar("NIVEL", luego)
M.Escuchar("SEGUIR", luego)
M.Escuchar("CERRAR", luego)
-- Las tarjetas de Mis planes muestran el avance: una meta cumplida se ve.
M.Escuchar("PLAN_AVANCE", luego)

-- ruta.soloRuta: el ajuste que lee Comodidades (y el primer arranque).
A.RegisterDefaults("ruta", { soloRuta = true })

-- Para la búsqueda de ajustes de la ventana de Alfa (la página es propia):
-- los mismos ajustes de arriba; los de buscar cerca, si está.
local function hayCerca() return M.Cerca ~= nil end
local CONTROLES = {
	-- behavior.autoAccept y behavior.autoTurnin no van aquí: son del motor (la
	-- búsqueda los encuentra en Misiones) y «Restablecer la página» de Ruta no
	-- debe tocarlos.
	{ kind = "toggle", key = M.ID .. ".evitarGrupo", label = L["Evitar misiones de grupo"],
		help = L["Al armar tus rutas, Alfa deja fuera las que piden élites."], search = "group quests, elite quests, skip" },
	{ kind = "slider", key = M.ID .. ".margen", label = L["Niveles arriba del tuyo"], min = 1, max = 4, step = 1,
		format = function(v) return format(L["+%d"], v) end,
		help = L["Qué tan difíciles pueden ser las misiones que Alfa elige (siempre de las que ya puedes tomar)."],
		search = "levels above, quest level, difficulty" },
	{ kind = "toggle", key = M.ID .. ".seguimientoCompleto", label = L["Mostrar más en el seguimiento"],
		help = L["De fábrica el seguimiento muestra solo lo que estás haciendo; encendido, muestra el paso completo con sus notas."],
		search = "tracker, full step, notes" },
	{ kind = "toggle", key = M.ID .. ".cercaBoton", label = L["Botón «Buscar cerca» en el rastreador"], needs = hayCerca,
		help = L["La lupa de la cabecera del rastreador abre el menú. También: /alfa cerca o tu tecla."], search = "nearby, search nearby, tracker button" },
	{ kind = "toggle", key = M.ID .. ".cercaHoy", label = L["«Buscar cerca» en la página Hoy"], needs = hayCerca,
		help = L["Una fila con vuelo, posada, reparar, banco, buzón y tu entrenador, a un clic."], search = "nearby, today page" },
	{ kind = "toggle", key = M.ID .. ".cercaAviso", label = L["Aviso al poner la flecha"], needs = hayCerca,
		help = L["Un aviso corto con el lugar, su zona y el tiempo de camino."], search = "nearby, arrow toast" },
	{ kind = "toggle", key = M.ID .. ".planFlecha", label = L["Mis planes: la flecha va sola al siguiente lugar"], needs = hayCerca,
		help = L["Cuando la meta de ahora de tu plan es un lugar, la flecha lo toma sin que hagas clic."], search = "plans, arrow, goals" },
}

-- "Solo las misiones de mi ruta", en Ajustes > Misiones > Misiones (1.2.0).
do
	local LM = A.L or {}
	local ok, err = A.RegisterOptions({ page = "questing", key = "questing", tab = LM["Quests"] or "Quests",
		section = LM["Faster questing"] or "Faster questing", controls = {
			{ kind = "toggle", key = "ruta.soloRuta", label = L["Aceptar y entregar solo las misiones de mi ruta"],
				help = L["Alfa no toma misiones que no sirven a tu ruta, ni las entrega solas. Lo respeta también «todas las misiones»."],
				search = "only route quests, quest automation" },
		} })
	if not ok and geterrorhandler then geterrorhandler()(err) end
end

-- 1.2.8: lo que Alfa te dice en el camino, en Ajustes > Misiones > Misiones.
do
	local LM = A.L or {}
	local ok, err = A.RegisterOptions({ page = "questing", key = "questing", tab = LM["Quests"] or "Quests",
		section = L["En el camino"], controls = {
			{ kind = "toggle", key = M.ID .. ".vueltaEntregar", label = L["Ofrecer «Vuelta a entregar»"],
				help = L["Con 2 o más misiones listas, el rastreador ofrece llevarte a entregarlas por el camino más corto."],
				search = "turn in route, hand in, ready quests" },
			{ kind = "toggle", key = M.ID .. ".piedraHogar", label = L["Sugerir la piedra de hogar"],
				help = L["Si casi todo lo que vas a entregar está en el pueblo de tu piedra y estás lejos, Lya te lo dice."],
				search = "hearthstone, bind location, turn in" },
			{ kind = "toggle", key = M.ID .. ".zonaPeligrosa", label = L["Avisar de zonas peligrosas"],
				help = L["Al entrar a una zona con enemigos muy arriba de tu nivel, un aviso corto (una vez por zona)."],
				search = "dangerous zone, zone level, high level" },
		} })
	if not ok and geterrorhandler then geterrorhandler()(err) end
end

-- 1.2.9: tu guía, más lista (Nivel, Grupo, Siguiente y Vuelo.lua), en Ajustes > Misiones > Misiones.
do
	local LM = A.L or {}
	local ok, err = A.RegisterOptions({ page = "questing", key = "questing", tab = LM["Quests"] or "Quests",
		section = L["Tu guía, más lista"], controls = {
			{ kind = "toggle", key = M.ID .. ".nivelClaro", label = L["Pasos de nivel claros"],
				help = L["En un paso de «Sube al nivel», cuánta experiencia te falta y dónde rinde más: enemigos de tu nivel que cuentan para tus misiones."],
				search = "level step, xp, experience, grind, where to level" },
			{ kind = "toggle", key = M.ID .. ".avisoElite", label = L["Avisar de misiones de élite"],
				help = L["Antes de una misión de élite o de grupo, un aviso con «Llamar a la manada»."],
				search = "elite quest, group quest, call the pack" },
			{ kind = "toggle", key = M.ID .. ".compartirMisiones", label = L["Ofrecer compartir misiones"],
				help = L["En grupo, si alguien no tiene una misión tuya, un botón para compartírsela."],
				search = "share quest, party, group" },
			{ kind = "toggle", key = M.ID .. ".siguienteGuia", label = L["Proponer la siguiente guía"],
				help = L["Al terminar una guía, la que sigue para tu nivel a un clic."],
				search = "next guide, guide finished, continue" },
			{ kind = "toggle", key = M.ID .. ".vueloListo", label = L["Marcar el mejor vuelo"],
				help = L["Con el mapa de vuelos abierto, marca el destino más cerca de tu paso de ahora."],
				search = "flight master, taxi, flight map, fly" },
		} })
	if not ok and geterrorhandler then geterrorhandler()(err) end
end

-- 1.3.0: tus misiones y tus viajes, en Ajustes > Misiones > Misiones.
do
	local LM = A.L or {}
	local ok, err = A.RegisterOptions({ page = "questing", key = "questing", tab = LM["Quests"] or "Quests",
		section = L["Tus misiones y tus viajes"], controls = {
			{ kind = "toggle", key = M.ID .. ".circuito", label = L["Circuito de la zona"],
				help = L["Todas las misiones de tu zona (las que llevas y las que puedes tomar) en el mejor orden, como una guía."],
				search = "zone route, optimal order, all quests, circuit" },
			{ kind = "toggle", key = M.ID .. ".grises", label = L["Avisar de misiones grises"],
				help = L["Una lista de las grises que ya no valen la pena, con «Abandonar» en cada una (tú lo confirmas)."],
				search = "grey quests, gray, abandon, trivial" },
			{ kind = "toggle", key = M.ID .. ".objetoBoton", label = L["Botón del objeto de misión más claro"],
				help = L["Junto al botón, el nombre del objeto y cuánto llevas; una huella late cuando ya lo puedes usar."],
				search = "quest item button, use item, keybind" },
			{ kind = "toggle", key = M.ID .. ".cadenaCompleta", label = L["Ver la cadena completa"],
				help = L["En el menú de una misión: toda su cadena, lo que ya hiciste y el premio del final."],
				search = "quest chain, follow up, final reward" },
			{ kind = "toggle", key = M.ID .. ".mapaGrupo", label = L["Misiones de tu grupo en el mapa"],
				help = L["En grupo, dónde está lo que pide cada misión y quién la lleva."],
				search = "party quests, group map, members objectives" },
			{ kind = "toggle", key = M.ID .. ".llevame", label = L["Llévame a..."],
				help = L["De donde estés a cualquier lugar, con vuelos, barcos, zepelines, portales y a pie, y la lista de tramos."],
				search = "travel, take me to, route, boat, zeppelin, portal" },
			{ kind = "toggle", key = M.ID .. ".horarios", label = L["Horarios de barcos y zepelines en el mapa"],
				help = L["Cada muelle con cuánto falta para que llegue su barco o zepelín."],
				search = "boat schedule, zeppelin timer, countdown, transport" },
		} })
	if not ok and geterrorhandler then geterrorhandler()(err) end
end

-- 1.2.9: Lya sabe contar lo nuevo de la ruta (Pregúntale a Lya).
A.RegisterEvent("PLAYER_LOGIN", function()
	local Lya = rawget(_G, "AlfaLya")
	if not (type(Lya) == "table" and type(Lya.Ensenar) == "function") then return end
	for _, p in ipairs({
		{ id = "rutas.nivel", icono = "ic-nivel", pregunta = L["¿Cuánto me falta para el nivel de mi guía?"],
			respuesta = L["Cuando tu guía dice «Sube al nivel», el rastreador te dice cuánta experiencia te falta y dónde rinde más: enemigos de tu nivel que también cuentan para tus misiones. «Llévame» y la flecha te lleva."] },
		{ id = "rutas.compartir", icono = "ic-manada", pregunta = L["¿Cómo comparto una misión con mi grupo?"],
			respuesta = L["En grupo, si alguien no tiene una misión que tú llevas, el rastreador te lo dice con «Compartir». Un clic y se la ofreces."] },
		{ id = "rutas.siguiente", icono = "ic-ruta", pregunta = L["¿Qué hago al terminar una guía?"],
			respuesta = L["Al terminarla, te propongo la siguiente para tu nivel. Un clic en «Seguir con…» y seguimos de caza."] },
		{ id = "rutas.vuelo", icono = "ic-huella", pregunta = L["¿A dónde vuelo?"],
			respuesta = L["Con el mapa de vuelos abierto, marco con una huella el destino más cerca de tu paso de ahora."] },
		-- 1.3.0
		{ id = "rutas.circuito", icono = "ic-ruta", pregunta = L["¿En qué orden hago las misiones de mi zona?"],
			respuesta = L["Pídeme el «Circuito de la zona» (página Ruta o el menú del rastreador): junto las que llevas y las que puedes tomar aquí y te llevo por el camino más corto."] },
		{ id = "rutas.grises", icono = "ic-misiones", pregunta = L["¿Qué misiones grises puedo abandonar?"],
			respuesta = L["Las que ya no te dan casi nada y no abren otra que valga la pena. En la página Ruta, «Misiones grises»: cada una con su «Abandonar»."] },
		{ id = "rutas.cadena", icono = "ic-ruta", pregunta = L["¿Cómo veo toda la cadena de una misión?"],
			respuesta = L["Clic derecho en la misión, en tu registro o en el rastreador: «Ver la cadena completa». Te digo cuáles hiciste y el premio del final."] },
		{ id = "rutas.llevame", icono = "ic-huella", pregunta = L["¿Cómo llego a otro lugar?"],
			respuesta = L["«Llévame a…» (página Ruta, tu tecla o /alfa llevame): eliges el lugar y te llevo con vuelos, barcos, zepelines y portales, tramo por tramo."] },
		{ id = "rutas.barcos", icono = "ic-reloj", pregunta = L["¿Cuándo sale el barco?"],
			respuesta = L["Abre el mapa: cada muelle dice cuánto falta para que llegue su barco o zepelín."] },
	}) do
		p.modulo = M.ID
		pcall(Lya.Ensenar, p)
	end
end)

N.Modulo({
	id = M.ID, nombre = L["Ruta"], icono = "ic-ruta", orden = 12,
	subtitulo = L["Qué hacer ahora, cerrar tus misiones y tus rutas propias."],
	ajustes = { margen = 2, evitarGrupo = true },
	controles = CONTROLES,
	construir = construir,
})
