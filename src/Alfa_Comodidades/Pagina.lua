-- Alfa - Comodidades: su página, hecha con el Kit (toxic3000 / La Jauría). GPL-3.0.
--
-- Plantilla Tablero (docs/KIT.md): arriba, el estado y la acción
-- recomendada (encender las comodidades que casi todos quieren, de un
-- clic); debajo, cada comodidad en su grupo, con su interruptor principal
-- y sus opciones dentro (atenuadas mientras está apagado). Lo que este
-- cliente no tiene (un probador, la CVar de la cámara...) no se muestra.
-- La página vive en Ajustes (es de las que se tocan una vez). Sus controles
-- también van a la búsqueda de ajustes de la ventana de Alfa.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit

local ipairs, format, floor = ipairs, string.format, math.floor
local ESP = K.ESP
local ID = M.ID

local function clave(k) return ID .. "." .. k end

---------------------------------------------------------------------------
-- Los grupos: cada fila es { k, titulo, texto, hija = principal, existe = fn, activa = fn, buscar }
---------------------------------------------------------------------------
local function cvarDe(k)
	for _, s in ipairs(M.SONIDOS or {}) do
		if s.clave == k then return s.cvar end
	end
end

-- La ayuda de "Aceptar y entregar todas las misiones" (en Ajustes > Misiones).
local TEXTO_MISIONES = L["También las que no son de la guía (de esas se encarga \"Aceptar misiones de la guía\"). No toma misiones grises, no entrega las que piden oro, monedas o materiales de oficio, y si hay varias recompensas eliges tú. Mantén presionado Mayús para hacerlo tú."]

local function textoEstilo()
	return L["«Igual que Alfa» sigue el estilo de Ajustes > Apariencia y cambia con él."]
end

-- Las misiones (aceptar y entregar todas) viven en Ajustes > Misiones desde
-- la 1.2.0, con las demás misiones: ver MISIONES, al final.
local GRUPOS = {
	{ titulo = L["Viajes"], filas = {
		{ k = "vueloParada", titulo = L["Mostrar la siguiente parada"],
			texto = L["En un vuelo con escalas, una línea bajo el temporizador dice dónde es la siguiente parada y cuánto falta para llegar. Necesita el temporizador de vuelo encendido."],
			activa = function() return A.Get("maps.flightTimer") and true or false end,
			buscar = "flight bar, next stop, next hop, taxi, flight path" },
	} },
	-- 1.3.7: la barra de información (Info.lua).
	{ titulo = L["Barra de información"], filas = {
		{ k = "info", titulo = L["Mostrar la barra de información"],
			texto = L["Una franja chica con tus cuadros por segundo y latencia, el oro de esta sesión, tu durabilidad, el espacio en bolsas, la experiencia por hora y la hora. Un clic en cada dato abre su página. Arrástrala a donde quieras."],
			boton = { texto = L["Moverla"], alClic = function()
				if not M.Get("info") then N.Set(ID, "info", true) end
				local Ac = rawget(_G, "AlfaAcomodar")
				if type(Ac) == "table" and Ac.Abrir then Ac.Abrir() end
			end },
			buscar = "info bar, data bar, fps, latency, ms, durability, bag space, gold per session, xp per hour, clock, titan panel" },
	} },
	{ titulo = L["Minimapa"], filas = {
		{ k = "minimapa", titulo = L["Mejorar el minimapa"],
			texto = L["Enciende los cambios de abajo; cada uno se puede apagar por separado. Algunos addons acomodan sus botones al cuadrado después de /reload."],
			buscar = "enhance minimap, square minimap, minimap buttons" },
		{ k = "minimapaCuadrado", hija = "minimapa", titulo = L["Minimapa cuadrado"],
			texto = L["El minimapa pasa de redondo a cuadrado, con un borde fino. No se recomienda junto con girar el minimapa."], buscar = "square minimap, minimap shape" },
		{ k = "minimapaBotones", hija = "minimapa", titulo = L["Ocultar los botones de addons"],
			texto = L["Los botones de otros addons alrededor del minimapa solo aparecen al pasar el ratón por encima. El de Alfa siempre queda a la vista."],
			buscar = "hide minimap buttons, addon buttons, libdbicon, minimap icons" },
		{ k = "minimapaMenu", hija = "minimapa", titulo = L["Ocultar el menú de addons"],
			texto = L["El botón con el número de addons en la esquina del minimapa solo aparece al pasar el ratón por encima, como los demás botones."],
			buscar = "addon compartment, addon menu, minimap number" },
		{ k = "minimapaEstilo", titulo = L["Dar al minimapa el estilo de Alfa"],
			texto = L["El borde del minimapa, redondo o cuadrado («Minimapa cuadrado», arriba), y la barra con la zona y la hora toman el estilo que elijas, como la ventana del mapa. Al apagarlo vuelve el de siempre."],
			buscar = "minimap skin, minimap border, minimap style, zone text" },
		{ k = "minimapaEstiloTema", etiqueta = L["Estilo del minimapa"], hija = "minimapaEstilo", tipo = "estilo", titulo = L["Estilo"], texto = textoEstilo,
			buscar = "minimap theme, alfa, classic, glass, cristal" },
		{ k = "minimapaCabecera", hija = "minimapaEstilo", titulo = L["Barra de la zona con el estilo"],
			texto = L["La barra con el nombre de la zona y la hora toma los colores y la letra del estilo. Los botones de rastreo, calendario y correo quedan como siempre."],
			buscar = "zone text bar, minimap clock, minimap header" },
	} },
	{ titulo = L["Estilo del chat"], filas = {
		{ k = "chat", titulo = L["Dar al chat el estilo de Alfa"],
			texto = L["Las ventanas de chat, sus pestañas y la caja para escribir toman el estilo que elijas abajo y cambian con él. Al apagarlo vuelve el chat de siempre, sin /reload."],
			buscar = "chat skin, chat style, chat frame, chat tabs, edit box, theme chat" },
		{ k = "chatEstilo", etiqueta = L["Estilo del chat"], hija = "chat", tipo = "estilo", titulo = L["Estilo"], texto = textoEstilo,
			buscar = "chat theme, alfa, classic, glass, cristal" },
		{ k = "chatOpacidad", hija = "chat", tipo = "deslizador", min = 0, max = 1, paso = 0.05, titulo = L["Opacidad del fondo"],
			texto = L["Cuánto se ve el fondo de las ventanas de chat; en cero solo queda el borde."], buscar = "chat background opacity, alpha" },
		{ k = "chatPestanas", hija = "chat", titulo = L["Pestañas con el estilo"],
			texto = L["Las pestañas toman la letra y los colores del estilo; la elegida lleva la línea de acento. En Clásico WoW quedan las del juego."], buscar = "chat tabs" },
		{ k = "chatEscribir", hija = "chat", titulo = L["Caja para escribir con el estilo"],
			texto = L["La caja donde escribes toma el estilo, con el borde de acento mientras escribes. En Clásico WoW queda la del juego."], buscar = "chat edit box, input box" },
		{ k = "chatLetra", hija = "chat", titulo = L["Letra del estilo"],
			texto = L["El chat usa la letra de Alfa (la de Ajustes > Apariencia). El tamaño se sigue cambiando en el menú de la pestaña."], buscar = "chat font" },
		{ k = "chatBotones", hija = "chat", titulo = L["Ocultar los botones del chat"],
			texto = L["Quita la columna de botones junto al chat (menú, canales y voz). Los comandos como /s, /g o /canal siguen igual."], buscar = "hide chat buttons, chat menu button" },
	} },
	-- 1.3.7: tu chat (Charla.lua). Todo es solo en tu chat: nada se envía.
	{ titulo = L["Tu chat"], filas = {
		{ k = "chatHora", titulo = L["La hora en cada línea"],
			texto = L["Cada mensaje de tu chat empieza con la hora a la que llegó. Solo lo ves tú."], buscar = "chat timestamps, time in chat, clock" },
		{ k = "chatClase", titulo = L["Nombres con el color de su clase"],
			texto = L["En tu chat, el nombre de cada jugador sale del color de su clase. Al apagarlo vuelve como lo tenías."], buscar = "class colored names, chat class colors" },
		{ k = "chatCopiar", titulo = L["Copiar del chat"],
			texto = L["Las direcciones (http, www, discord.gg) se vuelven un enlace: un clic abre un cuadro para copiarla. Al pasar el ratón por una ventana de chat, un botón copia sus últimas líneas (también /alfa copiar). Nada se envía."],
			buscar = "copy chat, copy url, links, chat copy, url copy" },
		{ k = "susurros", titulo = L["Susurros a la vista"],
			texto = L["Guarda tus susurros por persona para leerlos después (/alfa susurros). Solo en tu computadora; Alfa nunca responde por ti."],
			boton = { texto = L["Ver"], alClic = function(b) if M.Charla then M.Charla.VerSusurros(b) end end },
			buscar = "whisper history, whispers, tells, whisper sound" },
		{ k = "susurrosSonido", hija = "susurros", titulo = L["Sonido al llegarte uno"],
			texto = L["Un sonido de Alfa, distinto al del juego, cuando alguien te susurra (una vez cada pocos segundos por persona)."], buscar = "whisper sound, tell sound" },
		{ k = "spam", titulo = L["Filtro de spam"],
			texto = L["La venta de oro no sale en tu chat. Nunca se filtra a tus amigos, tu hermandad ni tu grupo. Lo escondido se puede ver (/alfa filtrado)."],
			boton = { texto = L["Ver lo filtrado"], alClic = function() if M.Charla then M.Charla.VerFiltrado() end end },
			buscar = "spam filter, gold sellers, gold spam, block spam, repeated messages" },
		{ k = "spamRepetidos", hija = "spam", titulo = L["También los mensajes repetidos"],
			texto = L["En los canales, la misma persona con el mismo mensaje en menos de un minuto sale una sola vez."], buscar = "repeated messages, duplicate messages, spam channel" },
		-- 1.4.2 (Flechas.lua, CopiarNombre.lua)
		{ k = "chatFlechas", titulo = L["Lo que escribiste antes, con las flechas"],
			texto = L["Mientras escribes en el chat, la flecha hacia arriba trae lo último que escribiste (sin Alt), y las de los lados mueven el cursor en vez de girar a tu personaje."],
			buscar = "chat history, arrow keys, alt arrow, edit box history, previous message" },
		{ k = "copiarNombre", titulo = L["«Copiar el nombre» en el clic derecho"],
			texto = L["Clic derecho en un jugador (su retrato, su nombre en el chat, tu grupo o tu hermandad) y «Copiar el nombre»: te lo deja listo para pegar, con todo y acentos."],
			buscar = "copy name, copy player name, right click menu, unit popup" },
	} },
	-- 1.4.2: tu gente (Conexiones.lua, Pedido.lua, Pendientes.lua). Nada se envía solo.
	{ titulo = L["Tu gente"], filas = {
		{ k = "conexiones", titulo = L["Quién se conecta y dónde anda"],
			texto = L["Cuando un amigo o alguien de tu hermandad se conecta, la línea de tu chat dice también su clase, su nivel, su zona y la nota que le pusiste."],
			buscar = "friend online, guild member online, login message, come online, level, zone, note" },
		{ k = "conexionesInvitar", hija = "conexiones", titulo = L["Con «Invitar» a un clic"],
			texto = L["Al final de esa línea, «[Invitar]»: un clic y le llega la invitación a tu grupo."], buscar = "invite link, quick invite" },
		{ k = "invitarSusurro", titulo = L["Invitar a quien te pide «inv»"],
			texto = L["Si un amigo o alguien de tu hermandad te susurra solo «inv» (o «invítame», «invite»…), Alfa lo invita a tu grupo. No le contesta nada; en tu chat te dice lo que hizo."],
			buscar = "auto invite, invite on whisper, whisper inv, keyword invite" },
		{ k = "invitarSusurroTodos", hija = "invitarSusurro", titulo = L["También a quien no conoces"],
			texto = L["Invita a cualquiera que te pida «inv», no solo a tus amigos y tu hermandad. Útil cuando armas grupo en el canal."], buscar = "invite anyone, strangers" },
		{ k = "susurrosPendientes", titulo = L["Lo que te escribieron mientras peleabas"],
			texto = L["Si te susurran en plena pelea o mientras estás ausente, al terminar un aviso te dice quién y qué, con «Responder» a un clic (lo envías tú)."],
			buscar = "missed whispers, whispers in combat, afk whispers, reply" },
	} },
	-- 1.3.7: los números de las recargas (Recargas.lua).
	{ titulo = L["Recargas"], filas = {
		{ k = "recargas", titulo = L["Números en las recargas"],
			texto = L["Sobre cada botón de tus barras que espera su recarga, cuánto le falta en grande. Usa los números del juego con la letra de Alfa, así siguen en mazmorras."],
			buscar = "cooldown numbers, cooldown count, omnicc, cooldown text, action bar cooldowns" },
		{ k = "recargasColor", hija = "recargas", titulo = L["Color según lo que falta"],
			texto = L["Amarillo los últimos 10 segundos y rojo los últimos 3."], buscar = "cooldown color" },
		{ k = "recargasDestello", hija = "recargas", titulo = L["Destello al quedar lista"],
			texto = L["El botón brilla un momento cuando la habilidad vuelve a estar lista (no con la recarga global)."], buscar = "cooldown flash, ready flash, pulse" },
	} },
	{ titulo = L["Estilo de las barras"], filas = {
		{ k = "barras", titulo = L["Dar a las barras el estilo de Alfa"],
			texto = L["La barra de acción, las barras extra, la de experiencia, el menú y las bolsas toman el estilo que elijas. Solo cambia su aspecto, fuera de combate; al apagarlo vuelven las del juego."],
			buscar = "action bar skin, action bars style, main menu bar, buttons skin, xp bar, micro menu, bags bar" },
		{ k = "barrasEstilo", etiqueta = L["Estilo de las barras"], hija = "barras", tipo = "estilo", titulo = L["Estilo"], texto = textoEstilo,
			buscar = "action bar theme, alfa, classic, glass, cristal" },
		{ k = "barrasBotones", hija = "barras", titulo = L["Botones con el estilo"],
			texto = L["Cada botón de acción con el borde y el fondo del estilo, el ícono cuadrado y la letra de Alfa en la tecla y la cuenta."], buscar = "action button border, hotkey font, empty slot" },
		{ k = "barrasExperiencia", hija = "barras", titulo = L["Experiencia y reputación"],
			texto = L["El marco de las barras de experiencia y reputación; el relleno conserva sus colores."], buscar = "xp bar, experience bar, reputation bar" },
		{ k = "barrasMenu", hija = "barras", titulo = L["Menú y bolsas"],
			texto = L["El marco del menú del juego y de las bolsas, abajo a la derecha."], buscar = "micro menu, bags bar, bag buttons" },
	} },
	{ titulo = L["Marcos y barra"], filas = {
		{ k = "colores", titulo = L["Colores de clase en los marcos"],
			texto = L["Pinta del color de la clase el fondo del nombre en tu marco y en el del objetivo cuando es un jugador."],
			buscar = "class colored frames, class colours, unit frames, player frame, target frame" },
		{ k = "coloresJugador", hija = "colores", titulo = L["En tu marco"], texto = L["Un fondo del color de tu clase bajo tu nombre."], buscar = "player frame" },
		{ k = "coloresObjetivo", hija = "colores", titulo = L["En el marco del objetivo"],
			texto = L["Si tu objetivo es un jugador, su fondo toma el color de su clase en lugar del de su reacción."], buscar = "target frame" },
		{ k = "barrasGrifos", tipo = "desplegable", titulo = L["Grifos"], opciones = function() return {
				{ valor = "como", texto = L["Como están"] }, { valor = "color", texto = L["Del color del estilo"] }, { valor = "ocultar", texto = L["Ocultos"] } } end,
			texto = L["Los grifos (o dragones) a los lados de la barra principal. «Del color del estilo» necesita el estilo de las barras; «Ocultos» funciona siempre."],
			existe = function() return M.Remates() ~= nil end, buscar = "gryphons, wyverns, end caps, action bar art, hide gryphons" },
		{ k = "barraForma", titulo = L["Avisar si la barra de una forma está vacía"],
			texto = L["Al cambiar de forma o de actitud, el juego usa otra barra de abajo. Si está vacía, Alfa te avisa una vez y puede llenar sus casillas vacías con las habilidades de esa forma que ya sabes, fuera de combate y sin tocar lo que ya tienes."],
			existe = function() return M.ClaseConFormas and M.ClaseConFormas() end,
			buscar = "empty stance bar, form bar, cat form, bear form, stealth bar, action bar disappears, druid, warrior, rogue" },
	} },
	{ titulo = L["Cuadro de información"], filas = {
		{ k = "cuadro", titulo = L["Mejorar el cuadro de información"],
			texto = L["Enciende los cambios de abajo en el cuadro que sale al pasar el ratón por un personaje o criatura."], buscar = "enhance tooltip, tooltip" },
		{ k = "cuadroObjetivo", hija = "cuadro", titulo = L["Mostrar a quién apunta"],
			texto = L["Agrega una línea con el objetivo de esa unidad; si te tiene a ti, lo dice."], buscar = "tooltip target, show target, unit target" },
		{ k = "cuadroAmigo", hija = "cuadro", titulo = L["Mostrar si es tu amigo"],
			texto = L["Para tus amigos, «Tu amigo» y la nota que le pusiste; también para tus amigos de Battle.net."], buscar = "friend tooltip, friend note, battle.net friend" },
		{ k = "cuadroRango", hija = "cuadro", titulo = L["Mostrar el rango de tu hermandad"], texto = L["Para alguien de tu hermandad, agrega su rango."], buscar = "guild rank, tooltip rank" },
		{ k = "cuadroCombate", hija = "cuadro", titulo = L["Ocultarlo en combate"],
			texto = L["En combate no aparece el cuadro de los personajes y criaturas del mundo (el de los marcos sí)."], buscar = "hide tooltip in combat" },
		{ k = "cuadroShift", hija = "cuadro", titulo = L["Mostrarlo con Mayús"], texto = L["Con el cuadro oculto en combate, mantén presionado Mayús para verlo."],
			activa = function() return M.On("cuadro", "cuadroCombate") end, buscar = "shift override, show tooltip shift" },
		-- 1.3.7: el ID (Ids.lua); no depende de «Mejorar el cuadro».
		{ k = "cuadroID", titulo = L["Ver el ID con Mayús"],
			texto = L["Con Mayús presionada, el cuadro de un objeto, hechizo, PNJ o misión dice su número (ID), útil para reportar un error."],
			buscar = "tooltip id, item id, spell id, npc id, quest id, idtip" },
		{ k = "cuadroIDSiempre", hija = "cuadroID", titulo = L["Verlo siempre"],
			existe = function() return not (N.Sencillo and N.Sencillo()) end,
			texto = L["El ID sale siempre, sin presionar Mayús."], buscar = "always show id" },
	} },
	{ titulo = L["Probador"], existe = function() return M.HayProbador() end, filas = {
		{ k = "probador", titulo = L["Mejorar el probador"], texto = L["Enciende los cambios de abajo en el probador (Ctrl + clic en un objeto)."],
			buscar = "enhance dressup, dressing room, dress up" },
		{ k = "probadorBotones", hija = "probador", titulo = L["Botones de objetos"],
			texto = L["A los lados del modelo, un botón por ranura: un clic oculta esa pieza y otro la vuelve a poner."], buscar = "dressup item buttons, hide items, undress slot" },
		{ k = "probadorAnimacion", hija = "probador", titulo = L["Control de animación"],
			texto = L["Abajo del modelo, elige lo que hace tu personaje (caminar, bailar, saludar…) y páusalo."], buscar = "dressup animation, animation slider, pause model" },
	} },
	{ titulo = L["Cámara"], existe = function() return M.ExisteCVar(M.CVAR_CAMARA) end, filas = {
		{ k = "camara", titulo = L["Alejar más la cámara"],
			texto = L["Lleva al máximo la distancia de la cámara (la de Opciones > Controles). Al apagarlo vuelve la que tenías."],
			buscar = "max camera zoom, camera distance, zoom out" },
	} },
	{ titulo = L["Silenciar sonidos"], filas = {
		{ k = "silenciarErrores", titulo = L["Voces de error"],
			texto = L["Tu personaje deja de decir \"No tengo suficiente maná\", \"Eso todavía no está listo\" y parecidas. El texto rojo sigue."],
			existe = function() return M.ExisteCVar(cvarDe("silenciarErrores")) end, buscar = "mute error speech, vocal errors, not enough mana" },
		{ k = "silenciarDialogos", titulo = L["Saludos y diálogos de los PNJ"],
			texto = L["Los PNJ dejan de hablar al saludarte o al darte misiones. También calla las voces de error."],
			existe = function() return M.ExisteCVar(cvarDe("silenciarDialogos")) end, buscar = "mute npc dialog, greetings, voice" },
		{ k = "silenciarMascotas", titulo = L["Sonidos de mascotas"], texto = L["Calla los ruidos de las mascotas, como el bostezo de los gatos de cazador."],
			existe = function() return M.ExisteCVar(cvarDe("silenciarMascotas")) end, buscar = "mute pet sounds, yawns, cat" },
		{ k = "silenciarGestos", titulo = L["Sonidos de gestos"], texto = L["Calla las voces de /bailar, /reír, /aplaudir y otros gestos."],
			existe = function() return M.ExisteCVar(cvarDe("silenciarGestos")) end, buscar = "mute emote sounds, dance, laugh" },
		-- 1.3.6: es para quien sabe el número de un sonido: no sale con Alfa
		-- sencillo (N.Sencillo) y su texto ya no dice «FileDataID».
		{ k = "silenciarLista", titulo = L["Tu lista de sonidos"],
			existe = function() return not (N.Sencillo and N.Sencillo()) end,
			texto = L["Para quien sabe el número de un sonido del juego: /alfa silenciar <número> lo calla y /alfa silenciar quitar <número> lo devuelve."],
			boton = { texto = L["Ver tu lista"], alClic = function() M.MostrarListaSonidos() end },
			buscar = "mute custom sounds, mute sound file, filedataid" },
	} },
}

-- Lo que casi todos quieren y no cambia cómo juegas: un clic lo enciende.
local RECOMENDADAS = { "colores", "cuadro", "probador", "vueloParada", "silenciarErrores" }

local function existe(f)
	if not f.existe then return true end
	local ok, si = pcall(f.existe)
	return ok and si and true or false
end

-- -> las recomendadas que existen en este cliente y cuántas están apagadas
local function recomendadas()
	local lista, apagadas = {}, 0
	for _, k in ipairs(RECOMENDADAS) do
		local fila
		for _, g in ipairs(GRUPOS) do
			if not g.existe or existe(g) then
				for _, f in ipairs(g.filas) do if f.k == k and existe(f) then fila = f end end
			end
		end
		if fila then
			lista[#lista + 1] = k
			if not M.Get(k) then apagadas = apagadas + 1 end
		end
	end
	return lista, apagadas
end

local function cuantasEncendidas()
	local n = 0
	for _, g in ipairs(GRUPOS) do
		for _, f in ipairs(g.filas) do
			if not f.hija and existe(f) and M.Get(f.k) then n = n + 1 end
		end
	end
	return n
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
-- Vender lo gris, reparar, los vuelos, las invitaciones... son del motor y
-- desde la 1.2.0 están en las otras pestañas de esta misma página. Las
-- misiones automáticas, en Ajustes > Misiones: un enlace allá.
local masCalidad = { texto = L["Misiones automáticas"], alClic = function() N.Abrir("questing") end }

local function estado()
	local lista, apagadas = recomendadas()
	local n = cuantasEncendidas()
	if apagadas > 0 then
		return {
			icono = "ic-comodidades", tono = "acento",
			titulo = L["Enciende las comodidades recomendadas"],
			texto = L["Colores de clase en los marcos, un cuadro de información más útil, el probador mejorado, la siguiente parada en los vuelos y sin voces de error. Cada una se apaga abajo cuando quieras."],
			estado = { texto = format(L["%d de %d encendidas"], #lista - apagadas, #lista), tono = "neutro" },
			accion = { texto = L["Encender las recomendadas"], icono = "ic-exito", alClic = function()
				for _, k in ipairs(lista) do N.Set(ID, k, true) end
			end },
			secundaria = masCalidad,
		}
	end
	return {
		icono = "ic-comodidades", tono = "exito",
		titulo = L["Tus comodidades están listas"],
		texto = format(L["Tienes %d encendidas. Abajo está cada una, con lo que hace, por si quieres cambiar algo."], n),
		estado = { texto = L["Listo [estado]"], tono = "exito" },
		-- 1.3.7: la barra de información viene apagada; aquí se ofrece.
		accion = not M.Get("info") and { texto = L["Probar la barra de información"], icono = "ic-info",
			alClic = function() N.Set(ID, "info", true) end } or nil,
		secundaria = masCalidad,
	}
end

local function fila(g, f)
	return g:Fila({
		titulo = f.titulo, texto = type(f.texto) == "function" and f.texto() or f.texto,
		hija = f.hija ~= nil,
		activa = function()
			if f.hija and not M.Get(f.hija) then return false end
			if f.activa then return f.activa() and true or false end
			return true
		end,
		control = function(contenedor)
			if f.tipo == "estilo" or f.tipo == "desplegable" then
				local opciones = f.tipo == "estilo" and M.OpcionesEstilo() or f.opciones()
				return K.Desplegable(contenedor, { clave = clave(f.k), opciones = opciones, ancho = 180 })
			end
			if f.tipo == "deslizador" then
				local d = K.Deslizador(contenedor, { min = f.min, max = f.max, paso = f.paso, clave = clave(f.k),
					formato = function(v) return floor(v * 100 + 0.5) .. " %" end })
				d.alfaAnchoFila = 220
				return d
			end
			if f.boton then
				local c = CreateFrame("Frame", nil, contenedor)
				c.Interruptor = K.Interruptor(c, { clave = clave(f.k) })
				c.Boton = K.Boton(c, f.boton.texto, f.boton.alClic, { tipo = "fantasma", tam = "chico" })
				c.Interruptor:SetPoint("RIGHT", c, "RIGHT", 0, 0)
				c.Boton:SetPoint("RIGHT", c.Interruptor, "LEFT", -ESP.m, 0)
				c:SetSize(36 + ESP.m + c.Boton:GetWidth(), K.ALTO.boton)
				function c:Leer() self.Interruptor:Leer() end
				function c:SetActivo(on) self.Interruptor:SetAlpha(on and 1 or 0.45) self.Interruptor:EnableMouse(on) end
				return c
			end
			return K.Interruptor(contenedor, { clave = clave(f.k) })
		end,
	})
end

local function construir(view)
	local ui = { grupos = {} }
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado" })
	for _, g in ipairs(GRUPOS) do
		local ga = t:AgregarBloque(K.GrupoAjustes(t.Extra, { titulo = g.titulo }))
		ga.filasDe = {}
		for _, f in ipairs(g.filas) do ga.filasDe[#ga.filasDe + 1] = { f = f, fila = fila(ga, f) } end
		ui.grupos[#ui.grupos + 1] = { g = g, ga = ga }
	end
	K.EnPagina(view, t, function()
		t:SetAccion(estado())
		for _, x in ipairs(ui.grupos) do
			local visible = 0
			local delGrupo = not x.g.existe or existe(x.g)
			for _, e in ipairs(x.ga.filasDe) do
				local hay = delGrupo and existe(e.f)
				-- Los textos que dependen de otro ajuste (la ruta) se leen otra vez.
				if type(e.f.texto) == "function" then e.fila.alfaDatos.texto = e.f.texto() end
				K.Mostrar(e.fila, hay)
				if hay then visible = visible + 1 end
			end
			x.ga:Refrescar()
			K.Mostrar(x.ga, visible > 0)
		end
	end, {
		-- 1.3.6: la página se reusa si no cambió nada. Un ajuste que cambia ya la
		-- marca sucia (SETTING_CHANGED); lo que viene del juego (qué existe en
		-- este cliente: probador, CVars, formas de tu clase) va en la firma.
		firma = function()
			local partes = {}
			for _, x in ipairs(ui.grupos) do
				partes[#partes + 1] = (not x.g.existe or existe(x.g)) and "1" or "0"
				for _, e in ipairs(x.ga.filasDe) do partes[#partes + 1] = existe(e.f) and "1" or "0" end
			end
			return table.concat(partes)
		end,
	})
	M.vista = view
	-- 1.3.6: sin OnShow; la ventana ya mide la página al mostrarla (O.Select).
end

-- Cualquier ajuste de aquí (o el de la ruta) rehace la página si está a la vista.
-- 1.3.6: varios cambios seguidos («Encender las recomendadas» prende cinco)
-- se juntan en un solo refresco, en el siguiente cuadro.
local pendiente = false
local function rehacer()
	pendiente = false
	if M.vista then N.RehacerPagina(M.vista) end
end
A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" or not M.vista then return end
	if path == "" or path == ID or path:sub(1, #ID + 1) == ID .. "." or path == "ruta.soloRuta" or path == "maps.flightTimer"
		or path == "bienvenida.modo" then -- 1.3.6: Sencillo/Completo muestra u oculta la lista de sonidos
		if not pendiente then
			pendiente = true
			A.After(0, rehacer)
		end
	end
end)

---------------------------------------------------------------------------
-- La búsqueda de ajustes: los mismos, como controles estándar.
---------------------------------------------------------------------------
local BUSCAR = {}
for _, g in ipairs(GRUPOS) do
	for _, f in ipairs(g.filas) do
		local c = { kind = "toggle", key = clave(f.k), label = f.etiqueta or f.titulo, search = f.buscar,
			help = type(f.texto) == "string" and f.texto or nil }
		if f.tipo == "estilo" or f.tipo == "desplegable" then
			c.kind = "dropdown"
			c.choices = function()
				local t = {}
				for i, o in ipairs(f.tipo == "estilo" and M.OpcionesEstilo() or f.opciones()) do t[i] = { value = o.valor, label = o.texto } end
				return t
			end
		elseif f.tipo == "deslizador" then
			c.kind, c.min, c.max, c.step = "slider", f.min, f.max, f.paso
			c.format = function(v) return floor(v * 100 + 0.5) .. " %" end
		end
		BUSCAR[#BUSCAR + 1] = c
	end
end

---------------------------------------------------------------------------
-- Aceptar y entregar todas las misiones: en Ajustes > Misiones > Misiones,
-- con las demás misiones (1.2.0). Mismas claves de siempre.
---------------------------------------------------------------------------
local function apagadoTodas() return not M.Get("misiones") end
local MISIONES = {
	{ kind = "toggle", key = clave("misiones"), label = L["Aceptar y entregar todas las misiones"], help = TEXTO_MISIONES,
		search = "automate quests, auto accept all quests, auto turn in, quest automation, daily, weekly" },
	{ kind = "toggle", key = clave("misionesNormales"), label = L["Misiones normales"], help = L["Las que se hacen una sola vez."],
		child = true, disabled = apagadoTodas, search = "regular quests" },
	{ kind = "toggle", key = clave("misionesDiarias"), label = L["Misiones diarias"], help = L["Las que se repiten cada día."],
		child = true, disabled = apagadoTodas, search = "daily quests, dailies" },
	{ kind = "toggle", key = clave("misionesSemanales"), label = L["Misiones semanales"], help = L["Las que se repiten cada semana."],
		child = true, disabled = apagadoTodas, search = "weekly quests" },
	{ kind = "toggle", key = clave("misionesEntregar"), label = L["Entregar las completadas"], help = L["Apagado, solo las acepta y la entrega la haces tú."],
		child = true, disabled = apagadoTodas, search = "turn in completed quests, hand in" },
	-- 1.3.7: también vale para las de la guía (las acepta el motor).
	{ kind = "toggle", key = clave("bitacoraLlena"), label = L["Con la bitácora llena, no aceptar y avisar"],
		help = L["Con tu bitácora de misiones llena, Alfa no intenta aceptar misiones solas (el juego daría un error rojo): te avisa una vez. Entregar sigue igual."],
		search = "quest log full, log is full, auto accept error" },
}
do
	local LM = A.L or {}
	local ok, err = A.RegisterOptions({ page = "questing", key = "questing", tab = LM["Quests"] or "Quests",
		section = L["Todas las misiones"], controls = MISIONES })
	if not ok and geterrorhandler then geterrorhandler()(err) end
end

N.Modulo({
	id = ID, nombre = L["Comodidades"], icono = "ic-comodidades", orden = 70, seccion = "ajustes",
	-- 1.3.6: subtítulo corto (el largo casi nunca se veía); el detalle está en
	-- cada grupo de la página.
	subtitulo = L["Detalles que hacen el juego más cómodo"],
	controles = BUSCAR,
	construir = construir,
})
