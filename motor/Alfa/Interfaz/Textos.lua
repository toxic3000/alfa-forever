-- Alfa - Textos de la interfaz propia del motor (toxic3000 / La Jauría). GPL-3.0.
--
-- La clave es el texto en español; aquí va su inglés. En el juego se leen con
-- ns.T(texto) (Theme.T): en español sale la clave, en inglés este texto, y en
-- los demás idiomas la traducción del núcleo (src/Alfa_Nucleo/Idiomas), que
-- tools/textos.py arma a partir de este archivo. Se carga antes del tema
-- (Alfa.toc, parche de tools/parches.py); aquí `M` es el espacio del motor.
local _, M = ...

M.EN = {
	-- Ventana principal: secciones, cabecera y pie
	["Hoy"] = "Today",
	["Aventura"] = "Adventure",
	["Personaje"] = "Character",
	["Mundo"] = "World",
	["Oficios"] = "Trades",
	["Manada"] = "Pack",
	["Ajustes"] = "Settings",
	["Buscar ajustes"] = "Search settings",
	["Buscar «%s» en la Enciclopedia"] = "Search \"%s\" in the Encyclopedia",
	["Nivel %d"] = "Level %d",
	["Nivel máximo"] = "Maximum level",
	["%d %% de experiencia"] = "%d %% experience",
	["%d %% descansada"] = "%d %% rested",
	["abrir o cerrar esta ventana"] = "open or close this window",
	["mostrar u ocultar la ventana de guía"] = "show or hide the guide window",
	["Mostrar u ocultar la ventana de guía"] = "Show or hide the guide window",

	-- Botón del minimapa
	["Clic: abrir o cerrar la ventana de Alfa"] = "Click: open or close the Alfa window",
	["Alfa está oculto: clic para mostrarlo y abrir su ventana"] = "Alfa is hidden: click to show it and open its window",

	-- Aventura > Tu guía
	["Tu guía"] = "Your guide",
	["La guía que sigues, tu paso de ahora y todo lo de las guías a un clic."] = "The guide you follow, your step now and everything about guides one click away.",
	["Guía actual"] = "Current guide",
	["Paso %d de %d"] = "Step %d of %d",
	["Paso %d"] = "Step %d",
	["Elegir una guía"] = "Choose a guide",
	["Terminaste esta guía. Elige la siguiente para seguir subiendo."] = "You finished this guide. Choose the next one to keep levelling.",
	["Todavía no sigues ninguna guía. Elige una y Alfa te lleva paso a paso, con la flecha y la ruta."] = "You are not following a guide yet. Choose one and Alfa takes you step by step, with the arrow and the route.",
	["A un clic"] = "One click away",
	["Mostrar la ventana de guía"] = "Show the guide window",
	["Ocultar la ventana de guía"] = "Hide the guide window",
	["Muéstrala u ocúltala. También con su tecla o con /alfa guia."] = "Show or hide it. Also with its key or /alfa guia.",
	["Elegir otra guía"] = "Choose another guide",
	["Todas las guías por zona y nivel, con la que Alfa te sugiere para ti."] = "Every guide by zone and level, with the one Alfa suggests for you.",
	["Buscador"] = "Lookup",
	["Cómo conseguir cualquier objeto, misión o PNJ, y qué guía te lleva ahí."] = "How to get any item, quest or NPC, and which guide takes you there.",
	["Diario de mazmorras"] = "Dungeon journal",
	["Jefes, botín y la entrada de cada mazmorra y banda."] = "Bosses, loot and the entrance of every dungeon and raid.",

	-- Ajustes > Apariencia
	["Grafito"] = "Graphite",
	["Noche"] = "Night",
	["Pizarra"] = "Slate",
	["Verde de La Jauría"] = "La Jauría green",
	["El tono de los fondos: Grafito es el de Alfa, Noche el más oscuro y Pizarra un gris neutro."] = "The tone of the backgrounds: Graphite is Alfa's own, Night the darkest and Slate a neutral grey.",
	["La letra del aspecto (Inter en el de Alfa, Fira Sans en Halo, la del juego en los demás) o la que elijas."] = "The skin's font (Inter in Alfa's own look, Fira Sans in Halo, the game's in the others) or one you choose.",

	-- Ajustes > Guía > Flecha y rutas (sin nombrar otros addons)
	["La flecha sigue caminos por el suelo alrededor de acantilados, agua y muros, con los mapas para caminar de Alfa. Apagado: apunta directo a cada parada."] = "The arrow follows paths on the ground around cliffs, water and walls, on Alfa's walking maps. Off: it points straight at each stop.",
	["El camino a la meta en el mapa del mundo y el minimapa: una línea o puntos donde caminas, líneas donde vuelas, navegas o montas, y los tramos que siguen más tenues."] = "The way to the goal on the world map and the minimap: a line or dots where you walk, lines where you fly, sail or ride, the legs after this one fainter.",

	-- Ajustes > Integraciones > Puntos de ruta (Nav/Journey.lua, parche)
	["Puntos de ruta"] = "Waypoints",
	["Otros addons pueden poner puntos de ruta"] = "Let other addons set waypoints",
	["Los puntos de ruta que ponen otros addons, y el comando /way, apuntan la flecha de Alfa. Un addon que espere los ajustes de otro addon de puntos de ruta puede no funcionar con esto encendido."] = "Waypoints other addons set, and /way, point Alfa's arrow. An addon that expects another waypoint addon's settings may not work with this on.",

	-- Equipo: escalas de estadísticas (Gear/Options.lua, Gear/Pawn.lua, UI/GearScales.lua; parches)
	["Importa una cadena de escala de estadísticas y usa, renombra, exporta o borra las escalas que tienes."] = "Import a stat scale string, and use, rename, export or delete the scales you have.",
	["Una flecha verde en cada objeto de tus bolsas que es una mejora para tu especialización."] = "A green arrow on each item in your bags that is an upgrade for your spec.",
	["Escala de estadísticas"] = "Stat scale",
	["Pega primero una cadena de escala de estadísticas."] = "Paste a stat scale string first.",
	["Ese texto es demasiado largo para una cadena de escala."] = "That text is too long for a scale string.",
	["Eso no es una cadena de escala de estadísticas. Empieza con ( Pawn: v1: \"Nombre\": ..."] = "That is not a stat scale string. It starts with ( Pawn: v1: \"Name\": ...",
	["Solo se admite la versión 1 de la cadena de escala."] = "Only version 1 of the scale string is supported.",
	["Esa cadena no trae ninguna estadística que Alfa puntúe."] = "That string has no stat Alfa scores.",
	["Pega una cadena de escala de estadísticas (Ctrl+V), la que copiaste desde donde la compartieron."] = "Paste a stat scale string (Ctrl+V), the one you copied from where it was shared.",
	["Ya está seleccionada: cópiala con Ctrl+C (Cmd+C en Mac) y pégala donde importes escalas, o compártela."] = "Selected for you: copy it with Ctrl+C (Cmd+C on a Mac), then paste it wherever you import scales, or share it.",
	["Todavía no tienes escalas propias. Pega una cadena de escala arriba."] = "No custom scales yet. Paste a scale string above.",

	-- Calidad de vida (QoL/Options.lua, parches)
	["Oculta el rastreador del juego a la derecha de la pantalla, con sus misiones, logros y profesiones. No con la interfaz de mando."] = "Hides the game's tracker on the right of the screen, with its quests, achievements and professions. Not with the gamepad interface.",
	["El objeto que usa el paso actual, o el objeto de misión que junta, brilla en tus bolsas. Un objeto que necesita un paso más adelante lleva un candado, para que no lo vendas."] = "The item the current step uses, or a quest item it collects, glows in your bags. An item a later step needs gets a lock, so you don't sell it.",

	-- Actualizaciones e instalación (UI/UpdateCard.lua, Core/Update.lua, Core/Data.lua; parches)
	["Actualízalo con la app de CurseForge o con el zip más reciente y luego reinicia el juego o usa /reload."] = "Update it with the CurseForge app or the latest zip, then restart the game or /reload.",
	["No se conoce ningún Alfa más reciente. La app de CurseForge o la página de versiones lo dicen con seguridad."] = "No newer Alfa is known. The CurseForge app or the releases page say for sure.",
	["Tu instalación está mezclada o incompleta (%s). Cierra el juego, borra todas las carpetas de Alfa en Interface/AddOns e instala Alfa de nuevo con la app de CurseForge o el zip más reciente (no \"Source code\")."] = "Your install is mixed or incomplete (%s). Close the game, delete every Alfa folder in Interface/AddOns and install Alfa again with the CurseForge app or the latest zip (not \"Source code\").",
	-- Créditos y licencias (UI/Options.lua, Acerca de)
	["Créditos y licencias"] = "Credits and licenses",
	["Alfa lo hace toxic3000 para La Jauría. Es software libre (GPL-3.0) y su código está en github.com/toxic3000/alfa-forever."] = "Alfa is made by toxic3000 for La Jauría. It is free software (GPL-3.0) and its source is at github.com/toxic3000/alfa-forever.",
	["Alfa usa código y datos de estos proyectos libres, con sus avisos de autor y sus licencias incluidos en cada carpeta:"] = "Alfa uses code and data from these free projects, with their copyright notices and licenses included in each folder:",
	["• Polestar, de The Polestar authors (GPL-3.0): el motor de guías, navegación y datos (github.com/fitzforge/polestar)."] = "• Polestar, by The Polestar authors (GPL-3.0): the guide, navigation and data engine (github.com/fitzforge/polestar).",
	["• Shortest Path Forever, de Cillian Berragan (GPL-3.0-or-later): la navegación y los servicios cercanos."] = "• Shortest Path Forever, by Cillian Berragan (GPL-3.0-or-later): navigation and nearby services.",
	["• pfQuest, de shagu (MIT): datos de misiones, PNJ y objetos."] = "• pfQuest, by shagu (MIT): quest, NPC and object data.",
	["• GatherLite, de Wuild (MIT): la base de nodos de recolección."] = "• GatherLite, by Wuild (MIT): the gathering node database.",
	["• OpenMap, de OpenMap contributors (MIT): la lógica del mapa continuo y las máscaras de territorio."] = "• OpenMap, by OpenMap contributors (MIT): the seamless map logic and territory masks.",
	["• TerrainWorldMap, de Dramacydal (MIT): la tabla de mosaicos del terreno del mapa."] = "• TerrainWorldMap, by Dramacydal (MIT): the map terrain tile table.",
	["• Letras Inter, Fira Sans y Open Sans (SIL Open Font License 1.1)."] = "• Inter, Fira Sans and Open Sans typefaces (SIL Open Font License 1.1).",
	["Alfa no está afiliado a esos proyectos ni ellos lo respaldan; gracias a todos por compartir su trabajo."] = "Alfa is not affiliated with or endorsed by those projects; thanks to all of them for sharing their work.",
	["World of Warcraft, Warcraft y Blizzard Entertainment son marcas de Blizzard Entertainment, Inc. El arte del juego y del mapa es de Blizzard. Alfa no está afiliado a Blizzard. Discord es marca de Discord Inc."] = "World of Warcraft, Warcraft and Blizzard Entertainment are trademarks of Blizzard Entertainment, Inc. The game and map art belong to Blizzard. Alfa is not affiliated with Blizzard. Discord is a trademark of Discord Inc.",
	-- Avisos de viaje y de raros con la voz de La Jauría (1.2.4: Nav/Alerts.lua, Rares/Toast.lua)
	["La manada viaja"] = "The pack travels",
	["El barco a %s ya viene"] = "The boat to %s is coming",
	["El zepelín a %s ya viene"] = "The zeppelin to %s is coming",
	["El tranvía a %s ya viene"] = "The tram to %s is coming",
	["Prepárate: llega en %s"] = "Get ready: it arrives in %s",
	["¡Tierra a la vista: %s!"] = "Land ahoy: %s!",
	["La manada desembarca en %s"] = "The pack goes ashore in %s",
	["¡Ya llegó! Vamos, manada"] = "We're here! Let's go, pack",
	["Lya olfateó un raro"] = "Lya sniffed out a rare",
	["Lya encontró un tesoro"] = "Lya found a treasure",
	["El alfa de La Jauría anda cerca"] = "La Jauría's alpha is nearby",
	["Ir de caza"] = "Go hunt",
	["Ir por él"] = "Go get it",
	["Su ficha"] = "Its page",
	["Seleccionarlo"] = "Target it",
	["Dejarlo ir"] = "Let it go",
	["Toca «Seleccionarlo» otra vez, o usa el botón de raros."] = "Tap \"Target it\" again, or use the rare button.",
}
