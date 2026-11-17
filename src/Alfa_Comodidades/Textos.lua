-- Alfa - Comodidades: los textos en inglés (el español es el idioma
-- principal y va escrito en el código). GPL-3.0.

local ADDON, M = ...

M.EN = {
	-- Comodidades.lua
	["Abrir las comodidades (minimapa, cuadro de información, probador...)"] = "Open the conveniences (minimap, tooltip, dressing room...)",

	-- Cuadro.lua
	["¡Tú!"] = "You!",
	["Objetivo:"] = "Target:",
	["Rango en tu hermandad:"] = "Guild rank:",

	-- Misiones.lua
	["esta misión"] = "this quest",
	["No entregué %s: pide oro o monedas. Entrégala tú si quieres."] = "Did not turn in %s: it asks for gold or currency. Turn it in yourself if you want to.",
	["No entregué %s: pide materiales de oficio. Entrégala tú si quieres."] = "Did not turn in %s: it asks for trade goods. Turn it in yourself if you want to.",

	-- Pagina.lua: Misiones
	["Aceptar y entregar todas las misiones"] = "Accept and turn in all quests",
	["También las que no son de la guía (de esas se encarga \"Aceptar misiones de la guía\"). No toma misiones grises, no entrega las que piden oro, monedas o materiales de oficio, y si hay varias recompensas eliges tú. Mantén presionado Mayús para hacerlo tú."] = "Also the ones that are not in the guide (\"Accept guide quests\" handles those). Grey quests are left alone, quests that ask for gold, currency or trade goods are not turned in, and when there are several rewards you choose. Hold Shift to do it yourself.",
	["Misiones normales"] = "Regular quests",
	["Las que se hacen una sola vez."] = "The ones you do only once.",
	["Misiones diarias"] = "Daily quests",
	["Las que se repiten cada día."] = "The ones that repeat every day.",
	["Misiones semanales"] = "Weekly quests",
	["Las que se repiten cada semana."] = "The ones that repeat every week.",
	["Entregar las completadas"] = "Turn in completed quests",
	["Apagado, solo las acepta y la entrega la haces tú."] = "Off, it only accepts them and you turn them in.",

	-- Pagina.lua: Viajes
	["Mostrar la siguiente parada"] = "Show the next stop",
	["En un vuelo con escalas, una línea bajo el temporizador dice dónde es la siguiente parada y cuánto falta para llegar. Necesita el temporizador de vuelo encendido."] = "On a flight with stops, a line under the timer says where the next stop is and how long until you get there. Needs the flight timer on.",

	-- Pagina.lua: Minimapa
	["Mejorar el minimapa"] = "Enhance the minimap",
	["Enciende los cambios de abajo; cada uno se puede apagar por separado. Algunos addons acomodan sus botones al cuadrado después de /reload."] = "Turns on the changes below; each can be turned off on its own. Some addons move their buttons to the square after a /reload.",
	["Minimapa cuadrado"] = "Square minimap",
	["El minimapa pasa de redondo a cuadrado, con un borde fino. No se recomienda junto con girar el minimapa."] = "The minimap goes from round to square, with a thin border. Not recommended with a rotating minimap.",
	["Ocultar los botones de addons"] = "Hide addon buttons",
	["Los botones de otros addons alrededor del minimapa (también el de Alfa) solo aparecen al pasar el ratón por encima."] = "Other addons' buttons around the minimap (Alfa's too) only show while the pointer is over it.",
	["Ocultar el menú de addons"] = "Hide the addon menu",
	["Oculta el botón con el número de addons en la esquina del minimapa. Esos addons se siguen abriendo con su comando, como /alfa."] = "Hides the button with the number of addons in the corner of the minimap. Those addons still open with their command, such as /alfa.",

	-- Pagina.lua: Interfaz
	["Colores de clase en los marcos"] = "Class colours on the frames",
	["Pinta del color de la clase el fondo del nombre en tu marco y en el del objetivo cuando es un jugador."] = "Paints the name background of your frame, and of the target's when it is a player, in the class colour.",
	["En tu marco"] = "On your frame",
	["Un fondo del color de tu clase bajo tu nombre."] = "A background in your class colour under your name.",
	["En el marco del objetivo"] = "On the target's frame",
	["Si tu objetivo es un jugador, su fondo toma el color de su clase en lugar del de su reacción."] = "When your target is a player, its background takes their class colour instead of their reaction's.",
	["Ocultar los grifos de la barra de acción"] = "Hide the action bar gryphons",
	["Quita los grifos de los lados de la barra principal. Edit Mode también tiene su propia opción para esto."] = "Removes the gryphons at the sides of the main bar. Edit Mode has its own setting for this too.",
	["Cuadro de información"] = "Tooltip",
	["Mejorar el cuadro de información"] = "Enhance the tooltip",
	["Enciende los cambios de abajo en el cuadro que sale al pasar el ratón por un personaje o criatura."] = "Turns on the changes below in the tooltip you get when the pointer is over a character or creature.",
	["Mostrar a quién apunta"] = "Show the unit's target",
	["Agrega una línea con el objetivo de esa unidad; si te tiene a ti, lo dice."] = "Adds a line with that unit's target; when it is you, it says so.",
	["Mostrar el rango de tu hermandad"] = "Show your guild's ranks",
	["Para alguien de tu hermandad, agrega su rango."] = "For someone in your guild, adds their rank.",
	["Ocultarlo en combate"] = "Hide it in combat",
	["En combate no aparece el cuadro de los personajes y criaturas del mundo (el de los marcos sí)."] = "In combat, the tooltip of characters and creatures in the world does not show (the unit frames' still does).",
	["Mostrarlo con Mayús"] = "Show it with Shift",
	["Con el cuadro oculto en combate, mantén presionado Mayús para verlo."] = "While the tooltip is hidden in combat, hold Shift to see it.",
	["Probador"] = "Dressing room",
	["Mejorar el probador"] = "Enhance the dressing room",
	["Enciende los cambios de abajo en el probador (Ctrl + clic en un objeto)."] = "Turns on the changes below in the dressing room (Ctrl-click an item).",
	["Botones de objetos"] = "Item buttons",
	["A los lados del modelo, un botón por ranura: un clic oculta esa pieza y otro la vuelve a poner."] = "At the sides of the model, a button per slot: one click hides that piece and another puts it back.",
	["Control de animación"] = "Animation control",
	["Abajo del modelo, elige lo que hace tu personaje (caminar, bailar, saludar...) y páusalo."] = "Under the model, choose what your character does (walk, dance, wave...) and pause it.",
	["Cámara"] = "Camera",
	["Alejar más la cámara"] = "Zoom the camera out further",
	["Lleva al máximo la distancia de la cámara (la de Opciones > Controles). Al apagarlo vuelve la que tenías."] = "Sets the camera distance (the one in Options > Controls) to its maximum. Turning it off brings yours back.",
	["Silenciar sonidos"] = "Mute sounds",
	["Voces de error"] = "Error speech",
	["Tu personaje deja de decir \"No tengo suficiente maná\", \"Eso todavía no está listo\" y parecidas. El texto rojo sigue."] = "Your character stops saying \"Not enough mana\", \"That isn't ready yet\" and the like. The red text stays.",
	["Saludos y diálogos de los PNJ"] = "NPC greetings and dialogue",
	["Los PNJ dejan de hablar al saludarte o al darte misiones. También calla las voces de error."] = "NPCs stop talking when they greet you or give you quests. It also mutes error speech.",
	["Sonidos de mascotas"] = "Pet sounds",
	["Calla los ruidos de las mascotas, como el bostezo de los gatos de cazador."] = "Mutes pet noises, such as hunter cats yawning.",
	["Sonidos de gestos"] = "Emote sounds",
	["Calla las voces de /bailar, /reír, /aplaudir y otros gestos."] = "Mutes the voices of /dance, /laugh, /applaud and other emotes.",
	["Tu lista de sonidos"] = "Your sound list",
	["Silencia los sonidos que agregues por su número de archivo (FileDataID): /alfa silenciar <número>; /alfa silenciar quitar <número> lo quita."] = "Mutes the sounds you add by their file number (FileDataID): /alfa silenciar <number>; /alfa silenciar quitar <number> removes it.",
	["Ver tu lista"] = "Show your list",

	-- Probador.lua
	["Cabeza"] = "Head", ["Hombros"] = "Shoulder", ["Espalda"] = "Back", ["Pecho"] = "Chest",
	["Camisa"] = "Shirt", ["Tabardo"] = "Tabard", ["Muñecas"] = "Wrist", ["Manos"] = "Hands",
	["Cintura"] = "Waist", ["Piernas"] = "Legs", ["Pies"] = "Feet", ["Mano principal"] = "Main Hand",
	["Mano secundaria"] = "Off Hand", ["A distancia"] = "Ranged",
	["Quieto"] = "Stand", ["Caminar"] = "Walk", ["Correr"] = "Run", ["Hablar"] = "Talk",
	["Reverencia"] = "Bow", ["Saludar"] = "Wave", ["Vitorear"] = "Cheer", ["Bailar"] = "Dance",
	["Reír"] = "Laugh", ["Dormir"] = "Sleep", ["Rugir"] = "Roar", ["Arrodillarse"] = "Kneel",
	["Llorar"] = "Cry", ["Aplaudir"] = "Applaud", ["Músculos"] = "Flex", ["Señalar"] = "Point",
	["Oculto en el modelo."] = "Hidden on the model.",
	["Clic: volver a ponerlo."] = "Click: put it back on.",
	["Clic: ocultarlo en el modelo."] = "Click: hide it on the model.",
	["El modelo no lleva nada aquí."] = "The model wears nothing here.",
	["Seguir"] = "Resume",
	["Pausa"] = "Pause",
	["Animación anterior"] = "Previous animation",
	["Animación siguiente"] = "Next animation",

	-- Sonidos.lua
	["Tu lista de sonidos está vacía. Agrega uno con /alfa silenciar <número>."] = "Your sound list is empty. Add one with /alfa silenciar <number>.",
	["Sonidos en tu lista (%d): %s"] = "Sounds on your list (%d): %s",
	["Tu lista de sonidos quedó vacía."] = "Your sound list is now empty.",
	["Uso: /alfa silenciar <número>, /alfa silenciar quitar <número>, /alfa silenciar borrar."] = "Usage: /alfa silenciar <number>, /alfa silenciar quitar <number>, /alfa silenciar borrar.",
	["Se quitó el sonido %d de tu lista."] = "Removed sound %d from your list.",
	["Se agregó el sonido %d a tu lista."] = "Added sound %d to your list.",
	["Silenciar un sonido por su número (FileDataID)"] = "Mute a sound by its number (FileDataID)",

	-- Vuelo.lua
	["Escalas:"] = "Stops:",
	["Siguiente parada:"] = "Next stop:",

	-- Pagina.lua
	["Tienes encendido «solo las misiones de mi ruta»: solo acepta las de tu ruta."] = "You have \"only my route's quests\" on: it only accepts your route's quests.",
	["Misiones"] = "Quests",
	["Viajes"] = "Travel",
	["Minimapa"] = "Minimap",
	["Marcos y barra"] = "Frames and action bar",
	["Enciende las comodidades recomendadas"] = "Turn on the recommended conveniences",
	["Colores de clase en los marcos, un cuadro de información más útil, el probador mejorado, la siguiente parada en los vuelos y sin voces de error. Cada una se apaga abajo cuando quieras."] = "Class colours on the frames, a more useful tooltip, the improved dressing room, the next stop on flights and no error voices. Each one can be turned off below whenever you like.",
	["%d de %d encendidas"] = "%d of %d on",
	["Encender las recomendadas"] = "Turn on the recommended ones",
	["Tus comodidades están listas"] = "Your conveniences are ready",
	["Tienes %d encendidas. Abajo está cada una, con lo que hace, por si quieres cambiar algo."] = "You have %d on. Each one is below, with what it does, in case you want to change something.",
	["Listo"] = "Ready",
	["Comodidades"] = "Conveniences",
	["Lo pequeño que hace el juego más cómodo: misiones, vuelos, minimapa, marcos, cuadro de información, probador, cámara y sonidos."] = "The small things that make the game more comfortable: quests, flights, minimap, frames, tooltip, dressing room, camera and sounds.",
	["La lista está apagada: enciende «Tu lista de sonidos» en Comodidades (/alfa comodidades)."] = "The list is off: turn on \"Your sound list\" in Conveniences (/alfa comodidades).",
}
