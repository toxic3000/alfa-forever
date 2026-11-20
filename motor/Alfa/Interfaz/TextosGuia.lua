-- Alfa - Textos de la interfaz (Guia). toxic3000 / La Jauria. GPL-3.0.
-- Mismo formato que Textos.lua: la clave es el texto en espanol y aqui va su ingles.
-- Se carga despues de Textos.lua (Alfa.toc), por eso se agrega a M.EN en vez de reemplazarlo.
local _, M = ...
M.EN = M.EN or {}
local EN = M.EN

-- EN["texto en espanol"] = "English text"

-- La ventana de guia (UI/GuideFrame.lua) y su lista de pasos (UI/StepList.lua)
EN["Elige una guía para empezar"] = "Choose a guide to start"
EN["Clic: elegir otra guía"] = "Click: choose another guide"
EN["Clic derecho: opciones de esta guía"] = "Right-click: this guide's options"
EN["Clic: la lista de pasos. Rueda: mirar otros pasos sin cambiar nada."] = "Click: the step list. Wheel: look at other steps without changing anything."
EN["Lista de pasos"] = "Step list"
EN["Todos los pasos de esta guía; clic en uno para verlo."] = "Every step of this guide; click one to see it."
EN["Ventana de guía oculta. Escribe /alfa guia para volver a verla."] = "Guide window hidden. Type /alfa guia to bring it back."
EN["Vuelve con /alfa guia o desde Aventura > Tu guía."] = "Bring it back with /alfa guia or from Adventure > Your guide."

-- La bienvenida (UI/Welcome.lua)
EN["Bienvenida a Alfa"] = "Welcome to Alfa"
EN["¡Hola, %s!"] = "Hello, %s!"
EN["¡Hola!"] = "Hello!"
EN["Te damos la bienvenida a Alfa, el todo en uno de La Jauría."] = "Welcome to Alfa, La Jauría's all-in-one."
EN["Qué es Alfa"] = "What Alfa is"
EN["Un solo addon con todo lo que usas al jugar: guías paso a paso con flecha y ruta, mapa, bolsas, builds, curación con clic, recolección, mazmorras, pesca y comercio. Todo con el mismo estilo."] = "One addon with everything you use while playing: step-by-step guides with an arrow and a route, the map, bags, builds, click healing, gathering, dungeons, fishing and trading. All in one style."
EN["Tu ventana de Alfa"] = "Your Alfa window"
EN["Escribe %s o haz clic en el lobo del minimapa para abrirla. Empieza en Hoy, con lo que toca a tu clase; %s muestra u oculta la ventana de guía."] = "Type %s or click the wolf on the minimap to open it. It starts on Today, with what your class needs; %s shows or hides the guide window."
EN["Tu primera guía"] = "Your first guide"
EN["Alfa te lleva paso a paso, con la flecha y la ruta en el mapa. Elige la de tu zona y tu nivel."] = "Alfa takes you step by step, with the arrow and the route on the map. Choose the one for your zone and your level."
EN["Sugerida para ti: %s"] = "Suggested for you: %s"
EN["Elegir mi primera guía"] = "Choose my first guide"
EN["La Jauría"] = "La Jauría"
EN["Nuestra manada en Discord: ayuda, avisos y reportes. Haz clic en el enlace y cópialo con Ctrl+C."] = "Our pack on Discord: help, news and reports. Click the link and copy it with Ctrl+C."
EN["Abrir la ventana de Alfa"] = "Open the Alfa window"
EN["Listo"] = "Done"

-- Las novedades (UI/WhatsNew.lua)
EN["Novedades de Alfa %s"] = "What's new in Alfa %s"
EN["Lo nuevo de esta versión, en pocas palabras."] = "What this version brings, in a few words."
EN["Entendido"] = "Got it"
EN["Cuéntanos qué te parece en La Jauría."] = "Tell us what you think in La Jauría."
EN["Ventana principal nueva"] = "A new main window"
EN["Hoy, Aventura, Personaje, Mundo, Oficios y Manada en una sola ventana: %s o el lobo del minimapa."] = "Today, Adventure, Character, World, Trades and Pack in one window: %s or the wolf on the minimap."
EN["Hoy, a tu clase"] = "Today, for your class"
EN["Tu sesión, tu diario, recordatorios y tu siguiente paso, con el color de tu clase."] = "Your session, your journal, reminders and your next step, in your class's colour."
EN["Ventana de guía propia"] = "Our own guide window"
EN["Tu avance arriba, el paso en una tarjeta, los dos siguientes a la vista y los botones abajo."] = "Your progress on top, the step on a card, the next two in sight and the buttons below."
EN["Curación con clic"] = "Click healing"
EN["Marcos de grupo y banda para curar con un clic, con preajustes por clase."] = "Party and raid frames to heal with one click, with presets for each class."
EN["Rutas propias"] = "Our own routes"
EN["El árbol de ruta de Alfa, misiones que se liberan y un catálogo de objetos."] = "Alfa's route tree, quests as they unlock and an item catalogue."
EN["La Jauría en el mapa"] = "La Jauría on the map"
EN["Tu grupo, tu hermandad y tus amigos en el mapa, con Seguir y la página del clan."] = "Your party, your guild and your friends on the map, with Follow and the clan's page."
EN["En 9 idiomas"] = "In 9 languages"
EN["Español, inglés y siete idiomas más, en toda la interfaz."] = "Spanish, English and seven more languages, all through the interface."
EN["¿Algo raro?"] = "Something off?"
EN["Escribe %s y cuéntanos en el Discord de La Jauría."] = "Type %s and tell us on La Jauría's Discord."

-- Ajustes > Apariencia (1.0)
EN["Alfa (el estilo propio, por omisión), Clásico WoW (marcos y letras del juego) o Cristal (transparente, con el acento que elijas). El modo compacto y tus colores funcionan en los tres."] = "Alfa (its own look, the default), Classic WoW (the game's frames and fonts) or Glass (see-through, with the accent you pick). Compact mode and your colours work in all three."
EN["Lobo"] = "Wolf"
EN["El medallón bajo cada marca del mapa y del minimapa: el de Alfa o solo el símbolo, sin medallón."] = "The medallion under every mark on the map and minimap: Alfa's, or the glyph alone with no medallion."
-- 1.3.0: los estilos nuevos (Theme.SkinChoices, Ajustes > Apariencia)
EN["Alfa (el de siempre), Clásico WoW (marcos y letras del juego), Cristal (transparente), La Jauría nocturno (azul de noche y plata de luna) o Fogata (carbón y brasas). El modo compacto y tus colores funcionan en todos."] = "Alfa (the one you know), Classic WoW (the game's frames and fonts), Glass (see-through), La Jauría Night (night blue and moon silver) or Campfire (charcoal and embers). Compact mode and your colours work in all of them."
EN["La Jauría nocturno"] = "La Jauría Night"
EN["Fogata"] = "Campfire"
