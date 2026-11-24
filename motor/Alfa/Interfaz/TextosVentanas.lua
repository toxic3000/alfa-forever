-- Alfa - Textos de la interfaz (Ventanas). toxic3000 / La Jauria. GPL-3.0.
-- Mismo formato que Textos.lua: la clave es el texto en espanol y aqui va su ingles.
-- Se carga despues de Textos.lua (Alfa.toc), por eso se agrega a M.EN en vez de reemplazarlo.
local _, M = ...
M.EN = M.EN or {}
local EN = M.EN

-- EN["texto en espanol"] = "English text"

-- El centro (UI/Picker.lua): sus secciones y sus pildoras
EN["Inicio de Alfa"] = "Alfa home"
EN["Abre la ventana principal de Alfa."] = "Opens Alfa's main window."
EN["Más"] = "More"

-- Selector de guias: vistas, filtros, tarjetas y ficha
EN["Inicio"] = "Home"
EN["Todas"] = "All"
EN["Abiertas"] = "Open"
EN["Recientes"] = "Recent"
EN["Comunidad"] = "Community"
EN["Guías de la comunidad"] = "Community guides"
EN["Mis rutas"] = "My routes"
EN["Zona o raza"] = "Zone or race"
EN["Todas las zonas y razas"] = "All zones and races"
EN["Razas"] = "Races"
EN["Zonas"] = "Zones"
EN["Nivel"] = "Level"
EN["Todos los niveles"] = "All levels"
EN["Niveles %s"] = "Levels %s"
EN["Tipo"] = "Type"
EN["Todos los tipos"] = "All types"
EN["Para tu nivel"] = "For your level"
EN["Para tu nivel (%d)"] = "For your level (%d)"
EN["Quitar filtros"] = "Clear filters"
EN["Tu facción (%s)"] = "Your faction (%s)"
EN["Sigue donde ibas"] = "Pick up where you were"
EN["Recomendadas para ti"] = "Recommended for you"
EN["Recomendada para ti"] = "Recommended for you"
EN["Usar esta guía"] = "Use this guide"
EN["Pestaña nueva"] = "New tab"
EN["Aún no tienes nada abierto. Mira Todas o usa los filtros de arriba para encontrar una guía."] = "Nothing open yet. Look under All or use the filters above to find a guide."
EN["Aún no tienes rutas. Ármalas en la ventana de Alfa: Aventura > Rutas; cada una aparece aquí como guía."] = "No routes yet. Build them in Alfa's window: Adventure > Routes; each one shows up here as a guide."
EN["Ninguna guía cumple estos filtros. Quita alguno para ver más."] = "No guide matches these filters. Clear one to see more."

-- Buscador (UI/Lookup.lua)
EN["Todo"] = "Everything"
EN["Guíame"] = "Guide me"
EN["¿Qué buscas?"] = "What are you looking for?"
EN["Cómo conseguir cualquier objeto, montura, PNJ, misión o lugar."] = "How to get any item, mount, NPC, quest or place."

-- Diario de mazmorras (UI/Dungeons.lua)
EN["Mazmorras"] = "Dungeons"
EN["Todas las mazmorras"] = "All dungeons"
EN["Entrada"] = "Entrance"
EN["mejor en %d"] = "best at %d"
EN["Escribe arriba el nombre de una mazmorra para buscarla."] = "Type a dungeon's name above to find it."
EN["Clic: abre su página con sus misiones, jefes y entrada."] = "Click: opens its page with its quests, bosses and entrance."

-- 1.3.9 (interfaz): textos nuevos
M.EN["Deshacer"] = "Undo"
M.EN["Vuelve el último ajuste que cambiaste a como estaba."] = "Puts the last setting you changed back as it was."
M.EN["Vuelven los %d ajustes del último cambio a como estaban."] = "Puts the %d settings of the last change back as they were."
