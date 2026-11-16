-- Alfa - Comodidades: dónde se ven sus ajustes. GPL-3.0.
--
-- Todo va en la página "Calidad de vida" del motor (UI/Options.lua la
-- declara con la clave "qualityoflife"). El registro encuentra una página,
-- una pestaña o una sección por su nombre ya traducido (pageOf, tabOf y
-- sectionOf), así que aquí se usan los mismos textos del motor (Alfa.L) para
-- caer en las pestañas que ya existen, y textos propios para lo nuevo:
--   Misiones > Todas las misiones          (sección nueva)
--   Viajes > Temporizador de vuelo         (la siguiente parada)
--   Mapa > Minimapa                        (junto al botón de Alfa)
--   Interfaz                               (pestaña nueva: marcos, cuadro de
--                                           información, probador, cámara y sonidos)
-- Los controles son los estándar del registro, con claves "comodidades.*".

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local AL = A.L

local PAGINA = AL["Quality of Life"]

local function registrar(pestana, seccion, controles)
	local ok, err = A.RegisterOptions({ page = PAGINA, tab = pestana, section = seccion, controls = controles })
	if not ok and geterrorhandler then geterrorhandler()(err) end
end

local function clave(k) return M.ID .. "." .. k end

local function apagado(k)
	return function() return not M.Get(k) end
end

-- Una opción de dentro de un grupo: sangrada bajo su interruptor y apagada
-- mientras él lo está.
local function hija(k, principal, etiqueta, ayuda, buscar, extra)
	local c = { kind = "toggle", key = clave(k), label = etiqueta, help = ayuda, search = buscar, child = true,
		disabled = extra or apagado(principal) }
	return c
end

---------------------------------------------------------------------------
-- Misiones > Todas las misiones
---------------------------------------------------------------------------

registrar(AL["Quests"], L["Todas las misiones"], {
	{ kind = "toggle", key = clave("misiones"), label = L["Aceptar y entregar todas las misiones"],
		help = L["También las que no son de la guía (de esas se encarga \"Aceptar misiones de la guía\"). No toma misiones grises, no entrega las que piden oro, monedas o materiales de oficio, y si hay varias recompensas eliges tú. Mantén presionado Mayús para hacerlo tú."],
		search = "automate quests, auto accept all quests, auto turn in, quest automation, leatrix, daily, weekly" },
	hija("misionesNormales", "misiones", L["Misiones normales"], L["Las que se hacen una sola vez."], "regular quests"),
	hija("misionesDiarias", "misiones", L["Misiones diarias"], L["Las que se repiten cada día."], "daily quests, dailies"),
	hija("misionesSemanales", "misiones", L["Misiones semanales"], L["Las que se repiten cada semana."], "weekly quests"),
	hija("misionesEntregar", "misiones", L["Entregar las completadas"], L["Apagado, solo las acepta y la entrega la haces tú."], "turn in completed quests, hand in"),
})

---------------------------------------------------------------------------
-- Viajes > Temporizador de vuelo
---------------------------------------------------------------------------

registrar(AL["Travel"], AL["Flight timer"], {
	{ kind = "toggle", key = clave("vueloParada"), label = L["Mostrar la siguiente parada"],
		help = L["En un vuelo con escalas, una línea bajo el temporizador dice dónde es la siguiente parada y cuánto falta para llegar. Necesita el temporizador de vuelo encendido."],
		search = "flight bar, next stop, next hop, taxi, flight path, leatrix",
		disabled = function() return not A.Get("maps.flightTimer") end },
})

---------------------------------------------------------------------------
-- Mapa > Minimapa
---------------------------------------------------------------------------

registrar(AL["Map"], AL["Minimap"], {
	{ kind = "toggle", key = clave("minimapa"), label = L["Mejorar el minimapa"],
		help = L["Enciende los cambios de abajo; cada uno se puede apagar por separado. Algunos addons acomodan sus botones al cuadrado después de /reload."],
		search = "enhance minimap, minimap modder, leatrix" },
	hija("minimapaCuadrado", "minimapa", L["Minimapa cuadrado"],
		L["El minimapa pasa de redondo a cuadrado, con un borde fino. No se recomienda junto con girar el minimapa."],
		"square minimap, minimap shape"),
	hija("minimapaBotones", "minimapa", L["Ocultar los botones de addons"],
		L["Los botones de otros addons alrededor del minimapa (también el de Alfa) solo aparecen al pasar el ratón por encima."],
		"hide minimap buttons, addon buttons, libdbicon, minimap icons"),
	hija("minimapaMenu", "minimapa", L["Ocultar el menú de addons"],
		L["Oculta el botón con el número de addons en la esquina del minimapa. Esos addons se siguen abriendo con su comando, como /alfa."],
		"addon compartment, addon menu, minimap number"),
})

---------------------------------------------------------------------------
-- Interfaz (pestaña nueva)
---------------------------------------------------------------------------

local INTERFAZ = L["Interfaz"]

registrar(INTERFAZ, L["Marcos"], {
	{ kind = "toggle", key = clave("colores"), label = L["Colores de clase en los marcos"],
		help = L["Pinta del color de la clase el fondo del nombre en tu marco y en el del objetivo cuando es un jugador."],
		search = "class colored frames, class colours, unit frames, player frame, target frame, leatrix" },
	hija("coloresJugador", "colores", L["En tu marco"], L["Un fondo del color de tu clase bajo tu nombre."], "player frame"),
	hija("coloresObjetivo", "colores", L["En el marco del objetivo"], L["Si tu objetivo es un jugador, su fondo toma el color de su clase en lugar del de su reacción."], "target frame"),
	{ kind = "toggle", key = clave("grifos"), label = L["Ocultar los grifos de la barra de acción"],
		help = L["Quita los grifos de los lados de la barra principal. Edit Mode también tiene su propia opción para esto."],
		search = "gryphons, end caps, action bar art, wyverns", needs = function() return M.Remates() ~= nil end },
})

registrar(INTERFAZ, L["Cuadro de información"], {
	{ kind = "toggle", key = clave("cuadro"), label = L["Mejorar el cuadro de información"],
		help = L["Enciende los cambios de abajo en el cuadro que sale al pasar el ratón por un personaje o criatura."],
		search = "enhance tooltip, tooltip, leatrix" },
	hija("cuadroObjetivo", "cuadro", L["Mostrar a quién apunta"], L["Agrega una línea con el objetivo de esa unidad; si te tiene a ti, lo dice."], "tooltip target, show target, unit target"),
	hija("cuadroRango", "cuadro", L["Mostrar el rango de tu hermandad"], L["Para alguien de tu hermandad, agrega su rango."], "guild rank, tooltip rank"),
	hija("cuadroCombate", "cuadro", L["Ocultarlo en combate"], L["En combate no aparece el cuadro de los personajes y criaturas del mundo (el de los marcos sí)."], "hide tooltip in combat"),
	hija("cuadroShift", "cuadro", L["Mostrarlo con Mayús"], L["Con el cuadro oculto en combate, mantén presionado Mayús para verlo."], "shift override, show tooltip shift",
		function() return not M.On("cuadro", "cuadroCombate") end),
})

registrar(INTERFAZ, L["Probador"], {
	{ kind = "toggle", key = clave("probador"), label = L["Mejorar el probador"],
		help = L["Enciende los cambios de abajo en el probador (Ctrl + clic en un objeto)."],
		search = "enhance dressup, dressing room, dress up, leatrix", needs = function() return M.HayProbador() end },
	hija("probadorBotones", "probador", L["Botones de objetos"], L["A los lados del modelo, un botón por ranura: un clic oculta esa pieza y otro la vuelve a poner."], "dressup item buttons, hide items, undress slot"),
	hija("probadorAnimacion", "probador", L["Control de animación"], L["Abajo del modelo, elige lo que hace tu personaje (caminar, bailar, saludar...) y páusalo."], "dressup animation, animation slider, pause model"),
})

registrar(INTERFAZ, L["Cámara"], {
	{ kind = "toggle", key = clave("camara"), label = L["Alejar más la cámara"],
		help = L["Lleva al máximo la distancia de la cámara (la de Opciones > Controles). Al apagarlo vuelve la que tenías."],
		search = "max camera zoom, camera distance, zoom out, leatrix", needs = function() return M.ExisteCVar(M.CVAR_CAMARA) end },
})

local function cvarDe(k)
	for _, s in ipairs(M.SONIDOS) do
		if s.clave == k then return s.cvar end
	end
end

local function sonido(k, etiqueta, ayuda, buscar)
	return { kind = "toggle", key = clave(k), label = etiqueta, help = ayuda, search = buscar,
		needs = function() return M.ExisteCVar(cvarDe(k)) end }
end

registrar(INTERFAZ, L["Silenciar sonidos"], {
	sonido("silenciarErrores", L["Voces de error"], L["Tu personaje deja de decir \"No tengo suficiente maná\", \"Eso todavía no está listo\" y parecidas. El texto rojo sigue."], "mute error speech, vocal errors, not enough mana"),
	sonido("silenciarDialogos", L["Saludos y diálogos de los PNJ"], L["Los PNJ dejan de hablar al saludarte o al darte misiones. También calla las voces de error."], "mute npc dialog, greetings, voice"),
	sonido("silenciarMascotas", L["Sonidos de mascotas"], L["Calla los ruidos de las mascotas, como el bostezo de los gatos de cazador."], "mute pet sounds, yawns, cat"),
	sonido("silenciarGestos", L["Sonidos de gestos"], L["Calla las voces de /bailar, /reír, /aplaudir y otros gestos."], "mute emote sounds, dance, laugh"),
	{ kind = "toggle", key = clave("silenciarLista"), label = L["Tu lista de sonidos"],
		help = L["Silencia los sonidos que agregues por su número de archivo (FileDataID): /alfa silenciar <número>; /alfa silenciar quitar <número> lo quita."],
		search = "mute custom sounds, mute sound file, filedataid" },
	{ kind = "button", button = L["Ver"], label = L["Ver tu lista"], help = L["Escribe en el chat los sonidos de tu lista."],
		search = "mute list", onClick = function() M.MostrarListaSonidos() end },
})
