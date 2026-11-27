-- Alfa - Recolección: textos en inglés para clientes que no son esMX/esES.
-- El español es el idioma principal y va en el código, dentro de L["..."].

local _, M = ...

M.EN = {
	-- 1.4.2 (economía)
	["Con %s %d te dan puntos: %s."] = "With %s %d these give you points: %s.",
	["Lo verde (%s) a veces."] = "The green ones (%s) sometimes.",
	["A subir %s"] = "Let's level %s",
	["Atenuar lo que recolectaste hace poco"] = "Dim what you gathered recently",
	["Subir %s"] = "Level %s",
	["O deja que Alfa te lleve a la zona donde más subes tu oficio."] = "Or let Alfa take you to the zone where you level your profession the most.",
	["Un nodo que recolectaste en los últimos minutos se ve tenue en el mapa y el minimapa (aún no vuelve), y su cuadro dice hace cuánto."] = "A node you gathered in the last few minutes looks dim on the map and minimap (it hasn't come back yet), and its tooltip says how long ago.",
	["Uso: /alfa recoleccion [ruta [mineria|hierbas|pesca|tesoros] | subir [mineria|hierbas] | guiar | parar | mapa | minimapa]"] = "Usage: /alfa recoleccion [ruta [mineria|hierbas|pesca|tesoros] | subir [mineria|hierbas] | guiar | parar | mapa | minimapa]",
	["Lo recolectaste hace un momento: aún no vuelve."] = "You gathered it a moment ago: it hasn't come back yet.",
	["Lo recolectaste hace %d minuto: puede que aún no vuelva."] = "You gathered it %d minute ago: it may not be back yet.",
	["Lo recolectaste hace %d minutos: puede que aún no vuelva."] = "You gathered it %d minutes ago: it may not be back yet.",
	["Clic: la flecha te lleva aquí. Mayús+clic: una ruta por todos los de este recurso en la zona."] = "Click: the arrow takes you here. Shift+click: a route through all of this resource in the zone.",
	["Ruta de %s: %s"] = "%s route: %s",
	["Tu personaje no tiene ese oficio. Te lo enseña un instructor de profesión."] = "Your character doesn't have that profession. A profession trainer teaches it.",
	["Tu oficio ya está al máximo. ¡Bien hecho!"] = "Your profession is already maxed. Well done!",
	["No encontré una zona de tu facción con lo que te da puntos."] = "I couldn't find a zone of your faction with what gives you points.",
	-- 1.4.0 (diario): mejoras del día a día
	["Llévame"] = "Take me there",
	["¡%s %d!"] = "%s %d!",
	["Ya puedes minar %s."] = "You can now mine %s.",
	["Ya puedes recoger %s."] = "You can now gather %s.",
	["«Llévame» te lleva a la zona más cercana de tu nivel."] = "\"Take me there\" leads you to the nearest zone for your level.",
	["Te falta la herramienta"] = "You're missing the tool",
	["Necesitas %s en tus bolsas. Tienes uno en el banco: sácalo la próxima vez que pases."] = "You need %s in your bags. You have one in the bank: take it out next time you're there.",
	["Necesitas %s en tus bolsas. Lo venden los comerciantes de suministros de oficios en las ciudades y los pueblos grandes."] = "You need %s in your bags. Trade supplies vendors sell it in cities and large towns.",
	["Avisar al poder recolectar algo nuevo"] = "Tell me when I can gather something new",
	["Avisar si te falta el pico o el cuchillo"] = "Tell me if I'm missing the pick or the knife",
	["Al subir Minería o Herboristería al nivel de otro recurso, un aviso con «Llévame» a la zona más cercana de tu nivel."] = "When Mining or Herbalism reaches the level of a new resource, a notice with \"Take me there\" to the nearest zone for your level.",
	["Si el juego no te deja minar o desollar por la herramienta, Alfa te dice qué falta y dónde se compra."] = "If the game won't let you mine or skin because of the tool, Alfa tells you what's missing and where to buy it.",
	["Recolección"] = "Gathering",
	["Minería"] = "Mining",
	["Hierbas"] = "Herbs",
	["Bancos de peces"] = "Fishing pools",
	["Tesoros"] = "Treasures",
	["Herboristería"] = "Herbalism",
	["Pesca"] = "Fishing",

	-- Cuadro de información de un nodo
	["Requiere %s (%d)"] = "Requires %s (%d)",
	["(tienes %d)"] = "(you have %d)",
	["Lo recolectaste 1 vez"] = "You gathered it once",
	["Lo recolectaste %d veces"] = "You gathered it %d times",
	["última: %s"] = "last: %s",
	["Todavía no lo recolectas"] = "Not gathered yet",
	["De la base de datos incluida"] = "From the included database",
	["%d nodos en esta zona del mapa"] = "%d nodes in this part of the map",
	["y %d recursos más"] = "and %d more resources",
	["Los recolectaste %d veces en total"] = "You gathered them %d times in all",
	["Clic: la flecha te lleva aquí."] = "Click: the arrow takes you here.",
	["%s y %d más"] = "%s and %d more",
	["Lugar conocido: el punto del rastreo del juego dice si ahora hay algo."] = "Known location: the game's tracking dot tells whether something is there now.",

	-- Ruta de farmeo
	["No sé en qué zona estás."] = "Your zone is unknown.",
	["No hay nodos conocidos en esta zona."] = "No known nodes in this zone.",
	["Hacen falta al menos 3 lugares distintos de ese recurso en la zona."] = "A route needs at least 3 different spots of that resource in the zone.",
	["Ruta %d/%d: %s"] = "Route %d/%d: %s",
	-- 1.3.6
	["La flecha ya no sigue tu ruta para juntar."] = "The arrow no longer follows your gathering route.",
	["%d paradas · %s · unos %d min a pie (%d montado)"] = "%d stops · %s · about %d min on foot (%d mounted)",
	["Qué recolectar"] = "What to gather",
	["El tipo de nodos que une la ruta."] = "The kind of nodes the route links.",
	["Recurso"] = "Resource",
	["Todos los de ese tipo, o solo uno (por ejemplo, solo cobre). Entre paréntesis, cuántos hay en tu zona."] = "All of that kind, or just one (for example, only copper). In brackets, how many are in your zone.",
	["Todos"] = "All",
	["Crear ruta"] = "Create route",
	["Ruta lista en %s: %s"] = "Route ready in %s: %s",
	["Guiarme"] = "Guide me",
	["Detener"] = "Stop",
	["Ver en el mapa"] = "Show on the map",
	["Borrar"] = "Delete",

	-- Ajustes
	["Dónde se ven"] = "Where they show",
	["En el mapa del mundo"] = "On the world map",
	["En el minimapa"] = "On the minimap",
	["Los nodos que tienes cerca. El punto del rastreo del juego dice si ahora hay algo ahí."] = "The nodes near you. The game's tracking dot tells whether something is there now.",
	["Tamaño en el mapa"] = "Size on the map",
	["Tamaño en el minimapa"] = "Size on the minimap",
	["Qué se ve"] = "What shows",
	["Filones y depósitos de mineral."] = "Mineral veins and deposits.",
	["Las plantas de herboristería."] = "Herbalism plants.",
	["Bancos y restos flotantes donde pescar."] = "Pools and floating wreckage to fish in.",
	["Cofres, baúles y almejas que se abren."] = "Chests, footlockers and clams you can open.",
	["Ocultar lo de profesiones que no tienes"] = "Hide what your professions can't gather",
	["Sin Minería no ves filones; sin Herboristería, hierbas; sin Pesca, bancos. Los tesoros siempre se ven."] = "Without Mining you see no veins; without Herbalism, no herbs; without Fishing, no pools. Treasures always show.",
	["Solo lo que ya puedes recolectar"] = "Only what you can gather now",
	["Esconde lo que pide más habilidad de la que tienes. Sin esto se ve gris y tenue."] = "Hides what needs more skill than you have. Without this it shows grey and faded.",
	["Juntar nodos cercanos al alejar"] = "Group nearby nodes when zoomed out",
	["Los nodos que se pisarían en pantalla van en un solo pin con su cantidad. Al acercar el mapa se separan."] = "Nodes that would overlap on screen share one pin with their count. Zoom in and they split.",
	["Usar la base de datos incluida"] = "Use the included database",
	["Los nodos que trae Alfa. Sin esto solo ves los que tú descubriste."] = "The nodes Alfa ships with. Without it you only see the ones you found.",

	-- Resumen e historial
	["Zona %d"] = "Zone %d",
	["y %d más"] = "and %d more",
	["en %s"] = "in %s",
	["%s por hora"] = "%s per hour",
	["Esta sesión, por recurso"] = "This session, by resource",
	["Lo que obtuviste en esta sesión"] = "What you got this session",
	["Por zona (este personaje)"] = "By zone (this character)",
	["Sesiones anteriores"] = "Earlier sessions",

	-- Datos
	["Borrar lo que descubrí"] = "Delete what I found",
	["¿Borrar lo que descubriste?"] = "Delete what you found?",
	["Borrar el historial"] = "Delete the history",
	["¿Borrar el historial?"] = "Delete the history?",
	["Se borran las sesiones, las zonas y los objetos de este personaje. No se puede deshacer."] = "This character's sessions, zones and items are deleted. This can't be undone.",
	["La base incluida trae %s lugares en %d zonas. Tú descubriste %s."] = "The included database has %s spots in %d zones. You found %s.",

	-- Módulo y comandos
	-- 1.3.6
	["Minas, hierbas, pesca y tesoros, con rutas para juntar"] = "Mining, herbs, fishing and treasures, with gathering routes",
	-- 1.3.6
	["Todavía no tienes una ruta"] = "You don't have a route yet",
	["Alfa arma una con lo que puedes juntar en tu zona y la flecha te lleva de punto en punto."] = "Alfa builds one from what you can gather in your zone, and the arrow takes you from spot to spot.",
	["Crear una ruta aquí"] = "Create a route here",
	["Nodos visibles."] = "Nodes shown.",
	["Nodos ocultos."] = "Nodes hidden.",
	-- 1.3.6
	["Abre Recolección. Con «ruta», crea y sigue una ruta para juntar en tu zona."] = "Opens Gathering. With \"ruta\", creates and follows a gathering route in your zone.",

	-- Página (Kit)
	["Calculando la vuelta más corta…"] = "Working out the shortest loop…",
	["Alfa ordena las paradas para que no camines de más. Tarda unos segundos y no traba el juego."] = "Alfa orders the stops so you don't walk more than needed. It takes a few seconds and doesn't stall the game.",
	["Calculando"] = "Working",
	["Siguiendo tu ruta de %s"] = "Following your %s route",
	["%s. La flecha te lleva a la parada %d; al llegar o recolectar ahí pasa sola a la siguiente."] = "%s. The arrow takes you to stop %d; once you arrive or gather there it moves on to the next one.",
	["En camino"] = "On the way",
	["Parada %d de %d"] = "Stop %d of %d",
	["Tu ruta de %s en %s está lista"] = "Your %s route in %s is ready",
	["Pulsa Guiarme y la flecha te lleva de parada en parada desde la más cercana."] = "Press Guide me and the arrow takes you from stop to stop, starting with the closest.",
	["Lista"] = "Ready",
	["Borrar la ruta"] = "Delete the route",
	["Aquí no hay nodos que recolectar"] = "Nothing to gather here",
	["Dentro de mazmorras y ciudades no hay nodos. Sal al mundo y tu ruta se arma en un clic."] = "Dungeons and cities have no nodes. Head out into the world and your route is one click away.",
	["Sin zona"] = "No zone",
	["Pocos lugares de %s en %s"] = "Few %s spots in %s",
	["Una ruta necesita al menos 3 lugares que tu habilidad alcance. Elige otro tipo o recurso abajo, o recolecta aquí: Alfa anota cada nodo que encuentras."] = "A route needs at least 3 spots your skill can reach. Pick another kind or resource below, or gather here: Alfa records every node you find.",
	["1 lugar"] = "1 spot",
	["%d lugares"] = "%d spots",
	["Arma una ruta de %s en %s"] = "Build a %s route in %s",
	["Une los %d lugares que tu habilidad alcanza en una vuelta corta, la dibuja en el mapa y la flecha te lleva de parada en parada."] = "Links the %d spots your skill can reach in a short loop, draws it on the map, and the arrow takes you from stop to stop.",
	["Tipo"] = "Kind",
	["Recolectado"] = "Gathered",
	["Por hora"] = "Per hour",
	["Cargando…"] = "Loading…",
	["Todavía no recolectas nada"] = "Nothing gathered yet",
	["Mina, herboriza, pesca en un banco o abre un cofre: aquí verás cuánto, qué te dio cada nodo y en qué zona."] = "Mine, pick herbs, fish a pool or open a chest: here you'll see how much, what each node gave you and in which zone.",
	["Los nodos de la zona que miras, con su nombre, nivel y cuántas veces los recolectaste al pasar el ratón. Clic en uno: la flecha te lleva."] = "The nodes of the zone you are looking at; hover one for its name, level and how often you gathered it. Click one: the arrow takes you there.",
	["En el mapa"] = "On the map",
	["Tus datos"] = "Your data",
	["Lo que conoce Alfa"] = "What Alfa knows",
	["Se quitan los nodos que anotaste al recolectar y cuántas veces los recolectaste. La base incluida se queda. No se puede deshacer."] = "The nodes you recorded while gathering, and how often you gathered them, are removed. The included database stays. This can't be undone.",
	["Tu historial"] = "Your history",
	["Las sesiones, las zonas y los objetos de este personaje."] = "This character's sessions, zones and items.",
	["Esta sesión"] = "This session",
	["Uso: /alfa recoleccion [ruta [mineria|hierbas|pesca|tesoros] | guiar | parar | mapa | minimapa]"] = "Usage: /alfa recoleccion [ruta [mineria|hierbas|pesca|tesoros] | guiar | parar | mapa | minimapa]",
	-- Sin profesión de recolección
	["Aprende Minería o Herboristería"] = "Learn Mining or Herbalism",
	["Tu personaje todavía no recolecta. Con Minería o Herboristería, Alfa une las minas o las hierbas de tu zona en una vuelta corta. Te las enseña un instructor de profesión."] = "Your character doesn't gather yet. With Mining or Herbalism, Alfa links the mines or herbs in your zone into a short loop. A profession trainer teaches them.",
	["Sin profesión"] = "No profession",
	["Instructor de Minería"] = "Mining trainer",
	["Instructor de Herboristería"] = "Herbalism trainer",
	["Pregúntale a un guardia de la ciudad por el instructor de la profesión."] = "Ask a city guard for the profession trainer.",
	-- Mapa continuo (1.1.8)
	["Varios puntos juntos: acércate en el mapa para verlos."] = "Several spots together: zoom in on the map to see them.",
	-- 1.3.7
	["Los recolectaste %d vez en total"] = "You gathered them %d time in total",
	["Nodos en el mapa del mundo: visibles."] = "Nodes on the world map: shown.",
	["Nodos en el mapa del mundo: ocultos."] = "Nodes on the world map: hidden.",
	["Nodos en el minimapa: visibles."] = "Nodes on the minimap: shown.",
	["Nodos en el minimapa: ocultos."] = "Nodes on the minimap: hidden.",
}

-- 1.3.9 (oficios): «Llévame» a un material y los puntos vacíos
M.EN["Aquí no hay ahora; voy al siguiente (%d de %d)."] = "Nothing here right now; on to the next one (%d of %d)."
M.EN["Voy al siguiente (%d de %d)."] = "On to the next one (%d of %d)."
M.EN["Mejor para tu nivel: %s, %d puntos, nivel %d–%d."] = "Best for your level: %s, %d spots, level %d–%d."
M.EN["La mejor zona: %s, %d puntos."] = "The best zone: %s, %d spots."
M.EN["%s sale a veces en lugar de %s: aquí hay %d."] = "%s sometimes spawns instead of %s: there are %d here."
M.EN["Ruta a %s"] = "Route to %s"
M.EN["No encontré ese recurso en las zonas de tu facción."] = "I couldn't find that resource in your faction's zones."

-- 1.4.0 (plan 73): la ruta corta de los pasos de juntar (Junta.lua)
M.EN["Ruta corta en %s"] = "Short route in %s"
M.EN["%d paradas cerca de ti, empezando por la más cercana. Al terminar el paso, la flecha vuelve a tu guía."] = "%d stops near you, starting with the closest. When the step is done, the arrow goes back to your guide."
M.EN["Guiar los pasos de juntar con una ruta corta"] = "Guide gathering steps with a short route"
M.EN["Cuando tu guía pide juntar un mineral o una hierba, la flecha te lleva por las vetas más cercanas de una zona de tu nivel, empezando por la más cercana."] = "When your guide asks you to gather an ore or an herb, the arrow takes you through the closest nodes in a zone for your level, starting with the nearest."
M.EN["El más cercano está a %s de ti."] = "The closest one is %s from you."

-- 1.4.0 (oficios)
M.EN["Oro estimado"] = "Estimated gold"
M.EN["≈ %s por hora"] = "≈ %s per hour"
-- 1.4.1: elegir a dónde ir por un material
M.EN["En otro continente: barco o vuelo (cuesta oro)"] = "On another continent: boat or flight (costs gold)"
M.EN["%s: quizá te convenga volar (cuesta oro)"] = "%s: you may want to fly (costs gold)"
M.EN["%s, unos %d min a pie"] = "%s, about %d min on foot"
M.EN["nivel %d–%d"] = "level %d–%d"
M.EN["%d puntos"] = "%d spots"
M.EN["Cerca de ti"] = "Near you"
M.EN["Cerca de ti y recomendado"] = "Near you and recommended"
M.EN["El lugar recomendado"] = "The recommended place"
M.EN["Otra zona"] = "Another zone"
M.EN["Guíame"] = "Guide me" -- 1.4.1
