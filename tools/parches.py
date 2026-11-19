"""Parches de Alfa sobre el codigo ya renombrado.

Cada parche es (archivo, texto_original, texto_nuevo). El texto original debe
aparecer exactamente una vez; si no, la construccion se detiene para revisar a
mano que cambio en Polestar.
"""
import pathlib
import re


def _creditos(cfg):
    return (
        '"Alfa: toxic3000 - La Jauría. Basado en Polestar de The Polestar authors '
        f'({cfg["urls"]["repo"]}), GPL-3.0, con la navegación de Shortest Path '
        'Forever de Cillian Berragan (GPL-3.0-or-later)." .. "\\n"\n\t\t.. '
        '"Recolección usa la base de nodos de GatherLite de Wuild (MIT). Mundo usa la lógica '
        'y las máscaras de territorio de OpenMap de OpenMap contributors (MIT); el arte del '
        'mapa es de Blizzard." .. "\\n"\n\t\t.. '
    )


# Pagina "Acerca de": la historia de Alfa en lugar de la de Polestar.
# (clave en ingles del codigo, texto nuevo en ingles, texto en espanol)
ACERCA = [
    ("Leveling guides have become a business: the best routes sit behind subscriptions and paywalls. "
     "Alfa goes the other way. It is free, open source under the GPL-3.0, and built by the community that plays it.",
     "Alfa is La Jauría's all-in-one for WoW Forever: guides, map, bags, builds, fishing, trading and "
     "your pack, in one place and with one look.",
     "Alfa es el todo en uno de La Jauría para WoW Forever: guías, mapa, bolsas, builds, pesca, comercio "
     "y tu manada, en un solo lugar y con un solo estilo."),
    ("Alfa doesn't claim to be the fastest guide, or the smoothest. It is a free alternative, and it gets better with time.",
     "Alfa is free and open source, under the GPL-3.0. The free projects it builds on are credited below, "
     "in Credits and licenses.",
     "Alfa es libre y de código abierto, bajo la GPL-3.0. Los proyectos libres en los que se apoya tienen "
     "su crédito abajo, en Créditos y licencias."),
    ("Anyone can read the code, fix a step, sharpen a route or write a new guide, and contributions are welcome. "
     "The GPL keeps it that way: every copy and every fork stays open.",
     "Made by toxic3000 and La Jauría. Come play with the pack: our Discord is open to everyone.",
     "Hecho por toxic3000 y La Jauría. Ven a jugar con la manada: nuestro Discord está abierto para todos."),
    ("Open source and free is the future.", "Lead your pack.", "Guía a tu manada."),
]

PARCHES = [
    # Reportes y versiones nuevas van a la pagina de Alfa, no a la de Polestar.
    ("Alfa/Core/Init.lua",
     'ns.IssueURL = "https://github.com/fitzforge/polestar/issues/new"',
     lambda c: f'ns.IssueURL = "{c["urls"]["issues"]}"'),
    ("Alfa/Core/Update.lua",
     'local base = "https://github.com/fitzforge/polestar/releases"',
     lambda c: f'local base = "{c["urls"]["releases"]}"'),
    # Alfa no es beta: sin la etiqueta junto a la version (ns.stage = nil).
    ("Alfa/Core/Init.lua",
     'ns.stage = "Beta"',
     lambda c: 'ns.stage = nil -- Alfa: version estable, sin etiqueta de etapa'),
    # Reglas de Blizzard (no saturar el chat de otros): escribir tu avance de
    # misiones en el chat del grupo viene apagado; la bienvenida lo pregunta.
    ("Alfa/Quests/Party.lua",
     'panelPos = false, chat = true,',
     lambda c: 'panelPos = false, chat = false,'),
    # Los puntos de vuelo y los de viaje (barcos, zepelines, tranvia) se ven en
    # el mapa de fabrica: son como se llega a los destinos (Toxic, 1.1.4).
    ("Alfa/Maps/Maps.lua",
     'taxiPins = false,       -- flight masters',
     lambda c: 'taxiPins = true,        -- flight masters (Alfa: a la vista de fabrica)'),
    ("Alfa/Maps/Maps.lua",
     'dockPins = false,       -- boats, zeppelins, tram',
     lambda c: 'dockPins = true,        -- boats, zeppelins, tram (Alfa: a la vista de fabrica)'),
    # El Discord de Alfa es el de La Jauria.
    ("Alfa/Core/Init.lua",
     'ns.DiscordURL = "https://discord.gg/polestar"',
     lambda c: f'ns.DiscordURL = "{c["urls"]["discord"] or c["urls"]["releases"]}"'),
    # Color de Alfa en el chat.
    ("Alfa/Core/Init.lua",
     'local PREFIX = "|cff4fd1c5Alfa|r: "',
     lambda c: f'local PREFIX = "|cff{c["color"]}Alfa|r: "'),
    # Creditos visibles en Opciones > Acerca de.
    ("Alfa/UI/Options.lua",
     'local credH, credText = block(L["Credits"], ',
     lambda c: 'local credH, credText = block(L["Credits"], ' + _creditos(c)),
    # Menu del boton del minimapa: un acceso por cada modulo de Alfa cargado.
    ("Alfa/Maps/MinimapButton.lua",
     '\titems[#items + 1] = { text = L["Options"], icon = "sliders", onClick = open("SHOW_OPTIONS") }\n',
     lambda c: (
         '\titems[#items + 1] = { text = L["Options"], icon = "sliders", onClick = open("SHOW_OPTIONS") }\n'
         '\tlocal mods = AlfaNucleo and AlfaNucleo.modulos\n'
         '\tif mods and #mods > 0 then\n'
         '\t\tlocal lista = {}\n'
         '\t\tfor i = 1, #mods do lista[i] = mods[i] end\n'
         '\t\ttable.sort(lista, function(a, b) return (a.orden or 99) < (b.orden or 99) end)\n'
         '\t\titems[#items + 1] = { separator = true }\n'
         '\t\tfor _, m in ipairs(lista) do\n'
         '\t\t\tlocal id = m.id\n'
         '\t\t\titems[#items + 1] = { text = m.nombre, icon = m.icono,\n'
         '\t\t\t\tonClick = function() ns.SetHidden(false) ns.Fire("SHOW_OPTIONS", id) end }\n'
         '\t\tend\n'
         '\tend\n')),
    # 1.1.6: Alfa es independiente: sin el comando corto de Polestar ni su
    # sitio como pagina del modulo de navegacion.
    ("Alfa/Core/Init.lua",
     '\tSLASH_ALFA2 = "/pole"',
     lambda c: '\t-- Alfa: solo /alfa (sin el comando corto de Polestar)'),
    ("Alfa_Nav/Alfa_Nav.toc",
     '## X-Website: https://github.com/fitzforge/polestar',
     lambda c: '## X-Website: ' + c["urls"]["issues"].rsplit("/issues", 1)[0]),
    # 1.1.6: un destino "persistente" (Seguir de La Jauria) no se suelta
    # cuando la guia cambia de paso; Nav.KeepTarget lo marca.
    ("Alfa/Nav/Nav.lua",
     'function Nav.IsHeld()',
     lambda c: (
         '-- Alfa: el destino puesto sigue aunque la guia cambie de paso (Seguir de La Jauria).\r\n'
         'function Nav.KeepTarget(t)\r\n'
         '\tif t == nil or t ~= override then return false end\r\n'
         '\tt.persistent = true\r\n'
         '\treturn true\r\n'
         'end\r\n'
         '\r\n'
         'function Nav.IsHeld()')),
    ("Alfa/Nav/Nav.lua",
     '\tif override == nil and not dismissed then return end',
     lambda c: (
         '\tif override and override.persistent then return end -- Alfa: Nav.KeepTarget\r\n'
         '\tif override == nil and not dismissed then return end')),
    # 1.1.6: cuando otro modulo de Alfa acaba de pedir algo en la ventana
    # (Comodidades toma una diaria), "cerrar lo que la guia no toma" espera.
    ("Alfa/Core/Automation.lua",
     'local function mayClose()',
     lambda c: (
         '-- Alfa: otro modulo acaba de pedir algo en esta ventana; no se cierra un rato.\r\n'
         'local keepUntil = 0\r\n'
         'function Automation.Keep(seconds)\r\n'
         '\tkeepUntil = (GetTime and GetTime() or 0) + (tonumber(seconds) or 2)\r\n'
         'end\r\n'
         'local function kept() return GetTime ~= nil and GetTime() < keepUntil end\r\n'
         '\r\n'
         'local function mayClose()')),
    ("Alfa/Core/Automation.lua",
     '\treturn ns.Get("behavior.closeSkipped") and not suppressed() and not ns.Compat.InCombat()',
     lambda c: '\treturn ns.Get("behavior.closeSkipped") and not suppressed() and not ns.Compat.InCombat() and not kept()'),
    # 1.1.6: la barra de vuelo para otros modulos, sin depender del global ni
    # del orden de los OnLogin.
    ("Alfa/Maps/FlightTimer.lua",
     '-- Current state for other modules: toName, secondsLeft (nil when unknown), source.',
     lambda c: (
         '-- Alfa: el marco de la barra de vuelo (lo crea si aun no existe).\r\n'
         'function Maps.GetFlightFrame()\r\n'
         '\tbuildFrame()\r\n'
         '\treturn frame\r\n'
         'end\r\n'
         '\r\n'
         '-- Current state for other modules: toName, secondsLeft (nil when unknown), source.')),
] + [
    ("Alfa/UI/Options.lua", f'L["{viejo}"]', (lambda n: lambda c: f'L["{n}"]')(nuevo))
    for viejo, nuevo, _ in ACERCA
]

# Interfaz propia (docs/INTERFAZ.md). Los textos nuevos de la interfaz son
# claves en espanol de motor/Alfa/Interfaz/Textos.lua: ese archivo se carga
# antes del tema, y ns.T(texto) da el del idioma del cliente.
_CARGADO = 'function() return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("{}") and true or false end'


def _fijo(texto):
    return lambda c: texto


INTERFAZ = [
    ("Alfa/Alfa.toc", "Theme\\Theme.xml\n",
     _fijo("Interfaz\\Textos.lua\nInterfaz\\TextosGuia.lua\nInterfaz\\TextosVentanas.lua\nTheme\\Theme.xml\n")),
    # Sin nombrar addons de terceros: las opciones de los que Alfa reemplaza
    # solo se ven con ese addon cargado, y los demas textos van en neutro.
    # Los textos en espanol de las opciones los traduce la ventana al dibujarlos.
    ("Alfa/Gear/Options.lua",
     'help = L["Import a Pawn scale string, and use, rename, export or delete the scales you have."],',
     _fijo('help = "Importa una cadena de escala de estadísticas y usa, renombra, exporta o borra las escalas que tienes.",')),
    ("Alfa/Gear/Options.lua",
     'help = L["A green arrow on each item in your bags that is an upgrade for your spec, in the game\'s bags and in Baganator."] },',
     _fijo('help = "Una flecha verde en cada objeto de tus bolsas que es una mejora para tu especialización." },')),
    ("Alfa/Gear/Options.lua",
     'needs = function() return ns.Compat.AddOnPresent("Pawn") end,',
     _fijo("needs = " + _CARGADO.format("Pawn") + ",")),
    ("Alfa/UI/QuestieTurnIns.lua",
     'needs = function() return ns.Compat.AddOnPresent("Questie") end },',
     _fijo("needs = " + _CARGADO.format("Questie") + " },")),
    ("Alfa/Gear/Pawn.lua", 'local base = L["Pawn scale"]', _fijo('local base = ns.T("Escala de estadísticas")')),
    ("Alfa/Gear/Pawn.lua", 'empty = L["Paste a Pawn scale string first."],',
     _fijo('empty = "Pega primero una cadena de escala de estadísticas.",')),
    ("Alfa/Gear/Pawn.lua", 'toolong = L["That text is too long for a Pawn string."],',
     _fijo('toolong = "Ese texto es demasiado largo para una cadena de escala.",')),
    ("Alfa/Gear/Pawn.lua", 'notpawn = L["That is not a Pawn string. It starts with ( Pawn: v1: \\"Name\\": ..."],',
     _fijo('notpawn = "Eso no es una cadena de escala de estadísticas. Empieza con ( Pawn: v1: \\"Nombre\\": ...",')),
    ("Alfa/Gear/Pawn.lua", 'version = L["Only Pawn string version 1 is supported."],',
     _fijo('version = "Solo se admite la versión 1 de la cadena de escala.",')),
    ("Alfa/Gear/Pawn.lua", 'nostats = L["That Pawn string has no stat Alfa scores."],',
     _fijo('nostats = "Esa cadena no trae ninguna estadística que Alfa puntúe.",')),
    ("Alfa/Gear/Pawn.lua", "return ERRORS[err] or tostring(err)",
     _fijo("return ERRORS[err] and ns.T(ERRORS[err]) or tostring(err)")),
    ("Alfa/UI/GearScales.lua",
     'L["Paste a Pawn scale string (Ctrl+V). In Pawn, open a scale\'s Scale tab and use Share, Copy."]',
     _fijo('ns.T("Pega una cadena de escala de estadísticas (Ctrl+V), la que copiaste desde donde la compartieron.")')),
    ("Alfa/UI/GearScales.lua",
     'L["Selected for you: copy it with Ctrl+C (Cmd+C on a Mac), then paste it into Pawn\'s import box or share it."]',
     _fijo('ns.T("Ya está seleccionada: cópiala con Ctrl+C (Cmd+C en Mac) y pégala donde importes escalas, o compártela.")')),
    ("Alfa/UI/GearScales.lua", 'L["No custom scales yet. Paste a Pawn string above."]',
     _fijo('ns.T("Todavía no tienes escalas propias. Pega una cadena de escala arriba.")')),
    ("Alfa/QoL/Options.lua",
     'help = L["Hides the game\'s tracker on the right of the screen, with its quests, achievements and professions, as Questie can. Not with the gamepad interface."],',
     _fijo('help = "Oculta el rastreador del juego a la derecha de la pantalla, con sus misiones, logros y profesiones. No con la interfaz de mando.",')),
    ("Alfa/QoL/Options.lua",
     'help = L["The item the current step uses, or a quest item it collects, glows in your bags (and in Baganator). An item a later step needs gets a lock, so you don\'t sell it."],',
     _fijo('help = "El objeto que usa el paso actual, o el objeto de misión que junta, brilla en tus bolsas. Un objeto que necesita un paso más adelante lleva un candado, para que no lo vendas.",')),
    ("Alfa/Nav/Journey.lua", 'page = L["Integrations"], section = "TomTom",',
     _fijo('page = L["Integrations"], section = "Puntos de ruta",')),
    ("Alfa/Nav/Journey.lua", 'label = L["Let other addons set waypoints"],',
     _fijo('label = "Otros addons pueden poner puntos de ruta",')),
    ("Alfa/Nav/Journey.lua",
     'help = L["Without TomTom installed, waypoints other addons set through TomTom, and /way, point Alfa\'s arrow. Addons that expect TomTom\'s own settings may not work with it on."] }),',
     _fijo('help = "Los puntos de ruta que ponen otros addons, y el comando /way, apuntan la flecha de Alfa. Un addon que espere los ajustes de otro addon de puntos de ruta puede no funcionar con esto encendido." }),')),
    ("Alfa/Nav/Journey.lua", "disabled = function() return TomTom == nil or TomTom == shim end },",
     _fijo("disabled = function() return TomTom == nil or TomTom == shim end,\n\t\t\t\tneeds = "
           + _CARGADO.format("TomTom") + " },")),
    ("Alfa/UI/UpdateCard.lua",
     'L["Polestar Client can update it for you: open it, press Update, then restart the game or /reload."]',
     _fijo('ns.T("Actualízalo con la app de CurseForge o con el zip más reciente y luego reinicia el juego o usa /reload.")')),
    ("Alfa/UI/UpdateCard.lua",
     'L["Update it with the CurseForge app or Polestar Client (or the zip from GitHub), then restart the game or /reload."]',
     _fijo('ns.T("Actualízalo con la app de CurseForge o con el zip más reciente y luego reinicia el juego o usa /reload.")')),
    ("Alfa/Core/Update.lua",
     'L["No newer Alfa is known. Polestar Client, the CurseForge app or the releases page say for sure."]',
     _fijo('ns.T("No se conoce ningún Alfa más reciente. La app de CurseForge o la página de versiones lo dicen con seguridad.")')),
    ("Alfa/Core/Data.lua",
     'ns.L["Your install is mixed or incomplete (%s). Close the game, delete every Alfa folder in Interface/AddOns and install Alfa again: with the Polestar Client, the CurseForge app, or the latest zip from GitHub Releases (not \\"Source code\\")."]',
     _fijo('ns.T("Tu instalación está mezclada o incompleta (%s). Cierra el juego, borra todas las carpetas de Alfa en Interface/AddOns e instala Alfa de nuevo con la app de CurseForge o el zip más reciente (no \\"Source code\\").")')),
]
PARCHES += INTERFAZ

# Reemplazos (docs/KIT.md): una ventana o un aviso del motor que un modulo de
# Alfa tomo (Alfa.Reemplazar, motor/Alfa/Core/Reemplazos.lua) no se dibuja; el
# motor llama a la ventana de Alfa en el mismo punto donde dibujaba la suya.
# Sin reemplazo todo sigue igual.
_AQUI = "-- Alfa: con esta ventana reemplazada (Core/Reemplazos.lua) se muestra la de Alfa.\n"
REEMPLAZOS = [
    # El registro, justo despues del bus de mensajes.
    ("Alfa/Core/Core.xml", '\t<Script file="Init.lua"/>\n',
     _fijo('\t<Script file="Init.lua"/>\n\t<Script file="Reemplazos.lua"/>\n')),
    # Un mensaje que abre una ventana reemplazada va primero a la de Alfa.
    ("Alfa/Core/Init.lua", "function ns.Fire(msg, ...)\n\tlocal list = listeners[msg]\n",
     _fijo("-- Alfa: un mensaje que abre una ventana reemplazada (Core/Reemplazos.lua) va a la\n"
           "-- ventana de Alfa que la tomo; si no la atiende, sigue a los oyentes del motor.\n"
           "ns.DesviosDeMensajes = ns.DesviosDeMensajes or {}\n\n"
           "-- Alfa: la puerta (ns.Puerta, la pone Alfa_Nucleo) puede detener un mensaje que\n"
           "-- abre una ventana: mientras falte terminar la bienvenida, abre la bienvenida.\n"
           "local function cerrada(msg)\n\tlocal puerta = ns.Puerta\n"
           "\tif not puerta or type(msg) ~= \"string\" or msg == \"SHOW_WELCOME\" then return false end\n"
           "\tif not (msg:find(\"^SHOW_\") or msg:find(\"^TOGGLE_\")) then return false end\n"
           "\tlocal ok, si = pcall(puerta, msg)\n\treturn ok and si == true\nend\n\n"
           "function ns.Fire(msg, ...)\n\tif cerrada(msg) then return end\n"
           "\tlocal desvio = ns.DesviosDeMensajes[msg]\n"
           "\tif desvio and desvio(...) then return end\n\tlocal list = listeners[msg]\n")),
    # Las secciones del centro abren el centro del motor sin pasar por el
    # reemplazo del selector (UI.AbrirCentro, motor/Alfa/UI/Picker.lua).
] + [
    (archivo, "\tif UI.ShowPicker then UI.ShowPicker() end\n",
     _fijo("\tif UI.AbrirCentro then UI.AbrirCentro() elseif UI.ShowPicker then UI.ShowPicker() end\n"))
    for archivo in ("Alfa/Talents/View.lua", "Alfa/Rares/View.lua", "Alfa/Alts/View.lua", "Alfa/UI/Import.lua")
] + [
    # La tarjeta de avisos (mision de clase, hechizos, rangos, mazmorra, version).
    ("Alfa/UI/ClassToast.lua", "function CT.ShowCard(m)\n\tif not (m and window()) then return false end\n",
     _fijo("function CT.ShowCard(m)\n\t" + _AQUI.replace("\n", "\n\t")
           + "if m and ns.Reemplazos and ns.Reemplazos.Aviso(m) then\n\t\tif f then f:Hide() end\n\t\treturn true\n\tend\n"
           "\tif not (m and window()) then return false end\n")),
    ("Alfa/UI/ClassToast.lua", "function CT.Place(animate)\n\tlocal w = window()\n",
     _fijo("function CT.Place(animate)\n\tlocal w = window()\n"
           "\tif CT.current and CT.current.alfaReemplazo then\n\t\tif f then f:Hide() end\n\t\treturn\n\tend\n")),
    ("Alfa/UI/ClassToast.lua", "\tCT.current = nil\n\tif f then f:Hide() end\n\tif was and ns.Fire then",
     _fijo("\tCT.current = nil\n\tif f then f:Hide() end\n"
           "\tif was and ns.Reemplazos then ns.Reemplazos.AvisoFuera(was) end\n\tif was and ns.Fire then")),
    # El fin de una guia.
    ("Alfa/UI/GuideEnd.lua", "\tshown = m\n\tlayout(m)\n",
     _fijo("\tshown = m\n\t" + _AQUI.replace("\n", "\n\t")
           + 'if ns.Reemplazos and ns.Reemplazos.Llamar("GUIDE_END", { accion = "mostrar", info = info, modelo = m,\n'
           "\t\tEmpezar = GE.Start, Despues = GE.Later, Cerrar = GE.Hide }) then\n\t\tF:Hide()\n\t\treturn true\n\tend\n"
           "\tlayout(m)\n")),
    ("Alfa/UI/GuideEnd.lua", "\tshown = nil\n\tif F then F:Hide() end\n",
     _fijo("\tshown = nil\n\tif F then F:Hide() end\n"
           '\tif ns.Reemplazos then ns.Reemplazos.Llamar("GUIDE_END", { accion = "ocultar" }) end\n')),
    ("Alfa/UI/GuideEnd.lua", "function GE.IsShown()\n\treturn F ~= nil and F:IsShown()\n",
     _fijo('function GE.IsShown()\n\treturn (F ~= nil and F:IsShown()) or ns.ReemplazoVisible("GUIDE_END") == true\n')),
    ("Alfa/UI/GuideEnd.lua", "\tif shown and F and F:IsShown() and E and E.GetTabs then\n",
     _fijo("\tif shown and GE.IsShown() and E and E.GetTabs then\n")),
    # Elegir el camino.
    ("Alfa/UI/RouteChoice.lua",
     "\tchoice.offeredAgain = E.PendingRouteChoice and E.PendingRouteChoice() ~= id or false\n\tlayout(choice)\n",
     _fijo("\tchoice.offeredAgain = E.PendingRouteChoice and E.PendingRouteChoice() ~= id or false\n\t"
           + _AQUI.replace("\n", "\n\t")
           + 'if ns.Reemplazos and ns.Reemplazos.Llamar("ROUTE_CHOICE", { accion = "mostrar", desde = id, eleccion = choice,\n'
           "\t\tsolo = byItself and true or false, Elegir = RC.Choose, Despues = RC.Hide }) then\n"
           "\t\tF:Hide()\n\t\treturn true\n\tend\n\tlayout(choice)\n")),
    ("Alfa/UI/RouteChoice.lua", "function RC.Hide()\n\twaiting = nil\n\tif F then F:Hide() end\nend\n",
     _fijo("function RC.Hide()\n\twaiting = nil\n\tif F then F:Hide() end\n"
           '\tif ns.Reemplazo and ns.Reemplazo("ROUTE_CHOICE") then\n'
           '\t\tns.Reemplazos.Llamar("ROUTE_CHOICE", { accion = "ocultar" })\n'
           '\t\tns.Fire("ROUTE_CHOICE_HIDDEN")\n\tend\nend\n')),
    ("Alfa/UI/RouteChoice.lua", "function RC.IsShown()\n\treturn F ~= nil and F:IsShown()\n",
     _fijo('function RC.IsShown()\n\treturn (F ~= nil and F:IsShown()) or ns.ReemplazoVisible("ROUTE_CHOICE") == true\n')),
    ("Alfa/UI/RouteChoice.lua", 'ns.On("ROUTE_CHOSEN", function()\n\tif F and F:IsShown() then F:Hide() end\n',
     _fijo('ns.On("ROUTE_CHOSEN", function()\n\tif F and F:IsShown() then F:Hide() end\n'
           '\tif ns.Reemplazos then ns.Reemplazos.Llamar("ROUTE_CHOICE", { accion = "ocultar" }) end\n')),
    # "Mientras estas aqui" con la ventana de guia oculta.
    ("Alfa/UI/WhileHere.lua", "function T.Show(v)\n\tif not f then build() end\n",
     _fijo("function T.Show(v)\n\t" + _AQUI.replace("\n", "\n\t")
           + 'if ns.Reemplazos and ns.Reemplazos.Llamar("WHILE_HERE", { accion = "mostrar", linea = v, texto = text(v),\n'
           "\t\tGuiar = function() local E = ns.Engine if E and E.AimWhileHere then E.AimWhileHere(shownIndex()) end end,\n"
           "\t\tDescartar = function() local E = ns.Engine if E and E.DismissWhileHere then E.DismissWhileHere(shownIndex()) end end,\n"
           "\t}) then\n\t\tif f then f:Hide() end\n\t\treturn\n\tend\n\tif not f then build() end\n")),
    ("Alfa/UI/WhileHere.lua", "function T.Hide()\n\tif not (f and f:IsShown()) then return end\n",
     _fijo('function T.Hide()\n\tif ns.Reemplazos then ns.Reemplazos.Llamar("WHILE_HERE", { accion = "ocultar" }) end\n'
           "\tif not (f and f:IsShown()) then return end\n")),
    ("Alfa/UI/WhileHere.lua", "\t\t\tif f and f:IsShown() then f.Text:SetText(text(cur)) end\n",
     _fijo("\t\t\tif f and f:IsShown() then f.Text:SetText(text(cur)) end\n"
           '\t\t\tif ns.Reemplazos then ns.Reemplazos.Llamar("WHILE_HERE", { accion = "actualizar", linea = cur, texto = text(cur) }) end\n')),
    # El panel de niveles de una ruta.
    ("Alfa/UI/LevelTip.lua", "function LevelTip.Show(chip)\n\tif not (chip and chip.psXP) then return end\n",
     _fijo("function LevelTip.Show(chip)\n\tif not (chip and chip.psXP) then return end\n"
           '\tif ns.Reemplazos and ns.Reemplazos.Llamar("LEVEL_TIP", { accion = "mostrar", chip = chip, resumen = chip.psXP, textos = chip.psTexts }) then return end\n')),
    ("Alfa/UI/LevelTip.lua", "function LevelTip.Hide()\n\towner = nil\n",
     _fijo('function LevelTip.Hide()\n\towner = nil\n\tif ns.Reemplazos then ns.Reemplazos.Llamar("LEVEL_TIP", { accion = "ocultar" }) end\n')),
    # La tarjeta de mision de clase de la ventana de guia: su modelo sin
    # dibujar (CC.Modelo) y, reemplazada, la ventana de Alfa la dibuja.
    ("Alfa/UI/ClassCard.lua", "function CC.Fill(guide, index, view)\n\tshown = nil\n\tCC.shown = nil\n",
     _fijo("function CC.Fill(guide, index, view)\n\tshown = nil\n\tCC.shown = nil\n\t" + _AQUI.replace("\n", "\n\t")
           + 'if ns.Reemplazo and ns.Reemplazo("CLASS_CARD") then\n'
           "\t\tif F then F:Hide() end\n"
           "\t\tlocal m = CC.Modelo(guide, index, view)\n"
           "\t\tif m then\n"
           '\t\t\tshown = { key = tostring(guide.id) .. ":" .. tostring(chainOf(m.mision)), class = m.clase, quest = m.mision, reward = m.recompensa, slim = m.tomada }\n'
           "\t\t\tCC.shown = shown\n\t\tend\n"
           '\t\tif ns.Reemplazos.Llamar("CLASS_CARD", { modelo = m, guia = guide, indice = index, vista = view }) then return m and m.hex or nil end\n'
           "\t\tshown = nil\n\t\tCC.shown = nil\n\tend\n")),
    ("Alfa/UI/ClassCard.lua", "function CC.Layout(width)\n",
     _fijo("-- Alfa (docs/KIT.md, CLASS_CARD): lo que dice la tarjeta para el paso `index`\n"
           "-- de `guide`, sin dibujarla, para una ventana de Alfa. -> modelo | nil\n"
           "--   { clase, nombreClase, nivel, mision, meta (indice de la meta), titulo,\n"
           "--     recompensa, nombreRecompensa, linea (\"Aprende ...\"), insignia, icono,\n"
           "--     hex (color de la clase para texto), zonas, pasos, aceptar (meta que\n"
           "--     se pliega en la tarjeta), tomada, entregaA, entregaLuego }\n"
           "function CC.Modelo(guide, index, view)\n"
           "\tlocal step = guide and index and guide.steps and guide.steps[index]\n"
           "\tlocal p = player()\n"
           "\tlocal gi = step and view and p and p.class and cardGoal(step, view, p)\n"
           "\tif not gi then return nil end\n"
           "\tlocal goal, gv = step.goals[gi], view.goals[gi]\n"
           "\tlocal e = entry(goal.quest)\n"
           "\tlocal d = ns.ClassRewards\n"
           "\tlocal reward = e and e[3] and e[3] > 0 and d.rewards[e[3]] or nil\n"
           "\tlocal hex = hexOf(textColor(p.class))\n"
           "\tlocal chain = chainOf(goal.quest)\n"
           "\tlocal zones, n = trip(guide, index, chain, goal.quest, p)\n"
           "\tlocal fold = CC.Fold(guide, view)\n"
           "\tlocal m = {\n"
           "\t\tclase = p.class, nombreClase = UI.ClassName(p.class), nivel = goal.minLevel or goal.qlvl,\n"
           "\t\tmision = goal.quest, meta = gi, titulo = (gv and gv.subject) or goal.title or \"\",\n"
           "\t\trecompensa = reward, nombreRecompensa = (CC.RewardName(reward)), linea = CC.RewardLine(reward, hex),\n"
           "\t\tinsignia = CC.BadgeText(reward), icono = CC.Icon(reward, p.class), hex = hex,\n"
           "\t\tzonas = zones, pasos = n, aceptar = fold, tomada = fold ~= nil and gv and gv.status == \"done\" or false,\n"
           "\t}\n"
           "\tif m.tomada then m.entregaA, m.entregaLuego = handIn(guide, index, view, goal.quest, chain, p) end\n"
           "\treturn m\n"
           "end\n\n"
           "function CC.Layout(width)\n")),
]
PARCHES += REEMPLAZOS

# Requisitos de una mision (src/Alfa_Rutas/Disponible.lua llena ns.Requisitos):
# la ruta no manda a una mision que este personaje no puede hacer. Lo que no se
# arregla haciendo algo (otra clase, raza o faccion, una excluyente ya hecha,
# una profesion que no tiene, una reputacion que no alcanza) deja la aceptacion
# fuera sin preguntar, con su motivo (noDisponible en la vista de la meta); una
# previa que ninguna guia anterior da entra como paso de alimentacion armado
# por Alfa (Own.feederPlan, con las mismas reglas: en las zonas de la guia y
# barata), y la mision que la pide dice que se agrego (antes).
_REQ_DEF = (
    "-- Alfa: lo que la ruta de Alfa sabe de una misión y el motor no (Alfa_Rutas,\n"
    "-- Disponible.lua, llena ns.Requisitos):\n"
    "--   Bloqueo(questID) -> texto | nil: este personaje no puede tomarla ahora ni\n"
    "--     haciendo otras misiones (otra clase, raza o facción, una excluyente ya\n"
    "--     hecha, una profesión que no tiene, una reputación que no alcanza): la\n"
    "--     aceptación y sus metas quedan fuera (marca \"alfa\"), sin preguntar.\n"
    "--   Cadena(questID) -> { { quest, title, step, preAll }, ... } | nil: los\n"
    "--     pasos en orden de la cadena que trae esa misión cuando ninguna guía\n"
    "--     anterior la da (Own.feederPlan los pone como los de una guía previa).\n"
    "-- La palabra del PNJ (Own.offered) gana: si la ofreció, se puede.\n"
    "ns.Requisitos = ns.Requisitos or {}\n"
    "Own.alfaMarks = setmetatable({}, { __mode = \"k\" })\n"
    "\n"
    "function Own.alfaBloqueo(goal, own, list)\n"
    "\tlocal fn = ns.Requisitos.Bloqueo\n"
    "\tlocal q = goal.quest\n"
    "\tif type(fn) ~= \"function\" or not q or Own.offered[q] then return nil end\n"
    "\tlocal a = own and goal or (list[1] and list[1].goal)\n"
    "\tif not a then return nil end\n"
    "\tlocal ok, texto = pcall(fn, q)\n"
    "\tif not (ok and type(texto) == \"string\" and texto ~= \"\") then return nil end\n"
    "\tlocal m = Own.alfaMarks[a]\n"
    "\tif not m then\n"
    "\t\tm = { reason = \"alfa\", accept = a }\n"
    "\t\tOwn.alfaMarks[a] = m\n"
    "\tend\n"
    "\tm.texto = texto\n"
    "\treturn m\n"
    "end\n"
    "\n"
    "-- Alfa: lo que la ruta agregó antes de esta meta (texto), de la meta o del plan\n"
    "-- de la guía (guide.antes: misión -> texto, Own.alfaAntesDe).\n"
    "function Own.alfaAntes(goal)\n"
    "\tif type(goal.antes) == \"string\" and goal.antes ~= \"\" then return goal.antes end\n"
    "\tlocal byQuest = goal.t == \"accept\" and goal.quest and guide and rawget(guide, \"antes\")\n"
    "\treturn type(byQuest) == \"table\" and byQuest[goal.quest] or nil\n"
    "end\n"
    "\n"
    "-- Alfa: la cadena de Alfa para la previa p, como la de Own.feederChain: cada\n"
    "-- misión es de la guía \"alfa\" (distancia 0: va justo antes de la aceptación\n"
    "-- que abre), en orden. -> cadena | nil\n"
    "function Own.alfaFeeder(p, idx)\n"
    "\tlocal fn = ns.Requisitos.Cadena\n"
    "\tif type(fn) ~= \"function\" then return nil end\n"
    "\tlocal ok, list = pcall(fn, p)\n"
    "\tif not (ok and type(list) == \"table\" and #list > 0) then return nil end\n"
    "\tlocal skips = ns.CharState().feedSkips\n"
    "\tfor _, e in ipairs(list) do\n"
    "\t\tif not (e.quest and type(e.step) == \"table\" and type(e.step.goals) == \"table\") then return nil end\n"
    "\t\tif Own.questSkipped(e.quest) or (type(skips) == \"table\" and skips[e.quest]) then\n"
    "\t\t\treturn { p = p, from = { id = \"alfa\", guide = \"Alfa\", title = list[#list].title }, ok = false, skipped = true, quests = {}, deps = {} }\n"
    "\t\tend\n"
    "\tend\n"
    "\tlocal C = Compat()\n"
    "\tlocal ch = { p = p, ok = true, quests = {}, deps = {}, orden = {} }\n"
    "\tfor _, e in ipairs(list) do\n"
    "\t\tlocal q = e.quest\n"
    "\t\tidx.alfaN = (idx.alfaN or 0) + 1\n"
    "\t\tlocal s = idx.alfaN\n"
    "\t\tidx.first[q] = { id = \"alfa\", guide = \"Alfa\", title = e.title, d = 0, s = s, preAll = e.preAll }\n"
    "\t\tlocal goals = {}\n"
    "\t\tfor _, goal in ipairs(e.step.goals) do\n"
    "\t\t\tgoals[#goals + 1] = { id = \"alfa\", d = 0, s = s, step = e.step, goal = goal }\n"
    "\t\tend\n"
    "\t\tidx.goals[q] = goals\n"
    "\t\tch.quests[q] = C.IsOnQuest(q) and \"turnin\" or true\n"
    "\t\tch.orden[#ch.orden + 1] = q\n"
    "\tend\n"
    "\tch.from = idx.first[p]\n"
    "\tif not ch.from then return nil end\n"
    "\treturn ch\n"
    "end\n"
    "\n"
    "-- Alfa: de cada cadena que el plan metió, sus misiones por nombre para las\n"
    "-- aceptaciones que abre. -> { [quest] = texto } | nil\n"
    "function Own.alfaAntesDe(list, idx)\n"
    "\tlocal out\n"
    "\tlocal N = ns.Names\n"
    "\tfor _, ch in ipairs(list or NONE) do\n"
    "\t\tif ch.inserted then\n"
    "\t\t\tlocal orden = ch.orden\n"
    "\t\t\tif not orden then\n"
    "\t\t\t\torden = {}\n"
    "\t\t\t\tfor q in pairs(ch.quests) do orden[#orden + 1] = q end\n"
    "\t\t\t\ttable.sort(orden)\n"
    "\t\t\tend\n"
    "\t\t\tlocal t = {}\n"
    "\t\t\tfor _, q in ipairs(orden) do\n"
    "\t\t\t\tlocal e = idx and idx.first[q]\n"
    "\t\t\t\tt[#t + 1] = (N and N.Quest and N.Quest(q)) or (e and e.title) or Compat().GetQuestTitle(q) or tostring(q)\n"
    "\t\t\tend\n"
    "\t\t\tif #t > 0 then\n"
    "\t\t\t\tlocal s = table.concat(t, \", \")\n"
    "\t\t\t\tout = out or {}\n"
    "\t\t\t\tfor _, d in ipairs(ch.deps) do out[d.q] = out[d.q] and (out[d.q] .. \", \" .. s) or s end\n"
    "\t\t\tend\n"
    "\t\tend\n"
    "\tend\n"
    "\treturn out\n"
    "end\n"
    "\n"
)

REQUISITOS = [
    ("Alfa/Core/Engine.lua",
     "-- Per quest, a goal's unavailable mark or nil. First, a quest the player\n",
     _fijo(_REQ_DEF + "-- Per quest, a goal's unavailable mark or nil. First, a quest the player\n")),
    ("Alfa/Core/Engine.lua",
     "\tlocal u = unavailable[q]\n\tif u and u.reason == \"closed\" then\n",
     _fijo("\t-- Alfa: lo que la ruta de Alfa sabe que la cierra (Own.alfaBloqueo).\n"
           "\tlocal alfa = Own.alfaBloqueo(goal, own, list)\n"
           "\tif alfa then return alfa end\n"
           "\tlocal u = unavailable[q]\n\tif u and u.reason == \"closed\" then\n")),
    ("Alfa/Core/Engine.lua",
     "\tif u.reason == \"skipped\" then return L[\"You skipped this quest\"] end\n",
     _fijo("\tif u.reason == \"skipped\" then return L[\"You skipped this quest\"] end\n"
           "\tif u.reason == \"alfa\" then return u.texto end\n")),
    ("Alfa/Core/Engine.lua",
     "\t\tunavailableText = unavail and unavailableText(unavail) or nil,\n",
     _fijo("\t\tunavailableText = unavail and unavailableText(unavail) or nil,\n"
           "\t\t-- Alfa: por qué no se puede (Own.alfaBloqueo) y lo que la ruta agregó antes.\n"
           "\t\tnoDisponible = unavail and unavail.reason == \"alfa\" and unavail.texto or nil,\n"
           "\t\tantes = Own.alfaAntes(goal),\n")),
    ("Alfa/Core/Engine.lua",
     "\t\t\t\t\t\t\t\tch = Own.feederChain(p, idx) or false\n",
     _fijo("\t\t\t\t\t\t\t\tch = Own.feederChain(p, idx)\n"
           "\t\t\t\t\t\t\t\t-- Alfa: sin guía previa que la dé, la cadena de Alfa (Own.alfaFeeder).\n"
           "\t\t\t\t\t\t\t\tif not (ch and (ch.ok or ch.skipped)) then ch = Own.alfaFeeder(p, idx) or ch end\n"
           "\t\t\t\t\t\t\t\tch = ch or false\n")),
    ("Alfa/Core/Engine.lua",
     "\treturn { steps = steps, feeders = feeders, hidden = hidden, cost = cost, fromBase = fromBase, legs = legs, onWay = onWay }\n",
     _fijo("\treturn { steps = steps, feeders = feeders, hidden = hidden, cost = cost, fromBase = fromBase, legs = legs, onWay = onWay,\n"
           "\t\tantes = Own.alfaAntesDe(list, idx) }\n")),
    ("Alfa/Core/Engine.lua",
     "\tg2.onWay = next(plan.onWay) and plan.onWay or nil\n",
     _fijo("\tg2.onWay = next(plan.onWay) and plan.onWay or nil\n\tg2.antes = plan.antes\n")),
    # Guiame a una mision: la aceptacion de la buscada dice que previas se agregaron.
    ("Alfa/Lookup/Guide.lua",
     "\treturn steps\nend\nLookup.QuestChain = questChain\n",
     _fijo("\t-- Alfa: la misión buscada dice qué se agregó antes (sus previas, en orden).\n"
           "\tif #chain > 1 then\n"
           "\t\tlocal N, t = ns.Names, {}\n"
           "\t\tfor i = 1, #chain - 1 do\n"
           "\t\t\tif i > 3 then\n"
           "\t\t\t\tt[#t] = t[#t] .. \"...\"\n"
           "\t\t\t\tbreak\n"
           "\t\t\tend\n"
           "\t\t\tt[#t + 1] = (N and N.Quest and N.Quest(chain[i].id)) or chain[i].title or tostring(chain[i].id)\n"
           "\t\tend\n"
           "\t\tlocal last = steps[#steps]\n"
           "\t\tlocal a = last and last.goals and last.goals[1]\n"
           "\t\tif a and a.t == \"accept\" and a.quest == questId then a.antes = table.concat(t, \", \") end\n"
           "\tend\n"
           "\treturn steps\nend\nLookup.QuestChain = questChain\n")),
]
PARCHES += REQUISITOS

# Seguir a alguien de La Jauria sin soltarse (1.2.6): un viaje "follow" no
# termina al llegar; si la persona se mueve, la flecha vuelve a llevarte.
PARCHES += [
    ("Alfa/Nav/Nav.lua", 'ends = ends == "instance" and "instance" or "arrive"',
     lambda cfg: 'ends = (ends == "instance" or ends == "follow") and ends or "arrive"'),
    ("Alfa/Nav/Nav.lua", "\tt.map, t.x, t.y = map, x, y\n",
     lambda cfg: "\tt.map, t.x, t.y = map, x, y\n\tlocal tr = Nav.Trip and Nav.Trip()\n\tif tr and tr.target == t and tr.ends == \"follow\" then arrived = false end -- Alfa: seguir sin soltarse\n"),
]

# El aviso de misiones en el chat (1.2.5): tus propias líneas te salen siempre
# a ti (motor/Alfa/Quests/PartyChat.lua); mandarlas al chat del grupo sigue
# apagado de fábrica (REGLAS-BLIZZARD.md, regla 3: el parche de arriba) y la
# bienvenida lo pregunta. Su ayuda lo explica.
PARCHES += [
    ("Alfa/Quests/Party.lua", "chatLoot = true, chatEcho = false,", lambda cfg: "chatLoot = true, chatEcho = true,"),
    ("Alfa/Quests/Party.lua",
     'help = L["A party chat line with the quest\'s link when you finish its objectives, and one when the quest is ready to turn in. Everyone in the party sees it, Alfa or not. Never solo or in a raid."] },',
     lambda cfg: 'help = ns.T("Manda al chat del grupo una línea con el enlace de la misión cuando completas sus objetivos, otra cuando está lista para entregar y otra al entregarla; todo el grupo la ve, con o sin Alfa. Apagado, esas líneas solo te salen a ti. Nunca en banda.") },'),
]

# El fundador de Alfa (1.2.4): el aviso de "el fundador anda cerca" buscaba al
# de Polestar, y el cambio de nombre lo dejo en "Fitz Alfa", que no existe.
# Ahora es Toxic, con su nombre y apellido como los da Compat.UnitFullName.
PARCHES += [
    ("Alfa/Rares/Rares.lua", 'Rares.FOUNDER = "Fitz Alfa"\n',
     lambda cfg: 'Rares.FOUNDER = "Toxic Darunia" -- Alfa: el fundador de Alfa y de La Jauria\n'),
]

# 1.2.8, carga ligera: la línea de ritmo de la ventana de guía (Levels.Pace)
# ya no carga el Codex (7 MB) al entrar; lo usa cuando otra cosa lo carga (la
# Enciclopedia, el buscador, el mapa) y la ventana se repinta con
# CODEX_LOADED (motor/Alfa/UI/GuideFrame.lua). El selector de guías y los
# demás que piden niveles lo siguen cargando como siempre.
PARCHES += [
    ("Alfa/Core/Levels.lua",
     'if not (ns.Get("lookup.enabled") and Cx.Load and Cx.Load()) then return nil end',
     lambda cfg: 'if Levels.ligero or not (ns.Get("lookup.enabled") and Cx.Load and Cx.Load()) then return nil end -- Alfa: carga ligera'),
    ("Alfa/Core/Levels.lua",
     '\tlocal s = Levels.ForGuide(g.id, p, live, kind == "goal" and step or nil)\n',
     lambda cfg: '\tLevels.ligero = true -- Alfa (1.2.8): el ritmo no carga el Codex\n'
                 '\tlocal okL, s = pcall(Levels.ForGuide, g.id, p, live, kind == "goal" and step or nil)\n'
                 '\tLevels.ligero = nil\n'
                 '\tif not okL then error(s, 0) end\n'),
]

# 1.2.8: la página Estrellas guía nombra a quienes apoyan y construyen
# Polestar (Core/Credits.lua es la lista de Polestar): son créditos de Polestar,
# no de Alfa, y así lo dice. Textos en motor/Alfa/Interfaz/Textos.lua.
PARCHES += [
    ("Alfa/UI/Thanks.lua", 'b.psTipLines = { L["Everyone who supports Alfa and helps build it."] }',
     lambda cfg: 'b.psTipLines = { ns.T("Quienes apoyan y construyen Polestar, el motor en el que se basa Alfa.") }'),
    ("Alfa/UI/Thanks.lua", 'lead:SetText(L["Thank you to everyone who supports Alfa and helps build it"])',
     lambda cfg: 'lead:SetText(ns.T("Gracias a quienes apoyan y construyen Polestar, el motor de Alfa"))'),
    ("Alfa/UI/Thanks.lua", 'join:SetText(L["Alfa is open source:"])',
     lambda cfg: 'join:SetText(ns.T("Polestar es de código abierto:"))'),
    ("Alfa/UI/Thanks.lua", 'closing:SetText(L["Thank you for making Alfa possible."])',
     lambda cfg: 'closing:SetText(ns.T("Gracias por hacer posible el motor de Alfa."))'),
]

# Textos que se agregan al final de un archivo: las traducciones de lo nuevo.
# Textos del motor que el paquete de idioma de Polestar deja en inglés.
SIN_TRADUCIR_ES = {"Recorder": "Grabadora"}

AGREGADOS = [
    (f"Alfa_{loc}/Interface.lua",
     "\n-- Alfa: pagina Acerca de\n" + "".join(f'L["{n}"] = "{es}"\n' for _, n, es in ACERCA)
     + "-- Alfa: textos que el paquete dejaba en ingles\n"
     + "".join(f'L["{en}"] = "{es}"\n' for en, es in SIN_TRADUCIR_ES.items()))
    for loc in ("esMX", "esES")
]


def aplicar(dist: pathlib.Path, cfg: dict) -> list:
    errores = []
    for rel, viejo, nuevo in PARCHES:
        ruta = dist / rel
        if not ruta.exists():
            errores.append(f"{rel}: no existe")
            continue
        texto = ruta.read_bytes().decode("latin-1")
        veces = texto.count(viejo)
        if veces != 1:
            errores.append(f"{rel}: '{viejo[:60]}' aparece {veces} veces")
            continue
        # el texto nuevo puede traer acentos: va en UTF-8, como el resto del juego
        cambio = nuevo(cfg).encode("utf-8").decode("latin-1")
        ruta.write_bytes(texto.replace(viejo, cambio).encode("latin-1"))
    for rel, extra in AGREGADOS:
        ruta = dist / rel
        if not ruta.exists():
            errores.append(f"{rel}: no existe")
            continue
        ruta.write_bytes(ruta.read_bytes() + extra.encode("utf-8"))
    errores += limpiar(dist, cfg)
    return errores


# 1.1.6: Alfa es independiente. Los paquetes de idioma traen traducciones que
# el codigo de Alfa ya no usa y que nombran a Polestar o a su programa
# (Polestar Client): las comentadas ("-- L[...]") y las de Polestar Client.
# Los avisos de autor y de licencia (LICENSE*, CREDITS, NOTICE-ALFA.txt,
# Acerca de) se quedan: la GPL pide conservarlos.
_SOBRANTE = re.compile(
    r'^[ \t]*(?:--[ \t]*L\[[^\n]*(?:[Pp]olestar|/pole\b)[^\n]*|L\["[^\n]*Polestar Client[^\n]*)\r?\n', re.M)

_README = """Alfa {version}
El todo en uno de La Jauria para World of Warcraft: Forever. Hecho por toxic3000.

Instalar
- Lo facil: Instalar-Alfa.exe ({web}/releases/latest/download/Instalar-Alfa.exe).
- A mano: con el juego cerrado, copia todas las carpetas Alfa* del zip en
  World of Warcraft/_forever_/Interface/AddOns/ y vuelve a abrir el juego
  (un /reload no carga carpetas nuevas).

Codigo, reportes y versiones: {web}
Discord de La Jauria: {discord}

Licencia
Alfa es software libre bajo la GNU General Public License, version 3 (LICENSE).
Los creditos y avisos de autor de todo lo que usa estan en NOTICE-ALFA.txt,
en la pagina "Acerca de" del juego y en los archivos LICENSE* y CREDITOS.md
de cada carpeta.
"""


# 1.1.9: un solo termino. El paquete esMX del motor dice "Calabozos" y Alfa
# dice "Mazmorras" (decision de Toxic, 18/11/2026). Se cambia con su genero:
# "el calabozo" -> "la mazmorra". En orden: lo largo antes que lo corto.
_MAZMORRAS = [
    ("Todos los calabozos", "Todas las mazmorras"), ("todos los calabozos", "todas las mazmorras"),
    ("Los calabozos están desactivados", "Las mazmorras están desactivadas"),
    ("Calabozos desactivados", "Mazmorras desactivadas"),
    ("Ningún calabozo", "Ninguna mazmorra"), ("ningún calabozo", "ninguna mazmorra"),
    ("Los calabozos", "Las mazmorras"), ("los calabozos", "las mazmorras"),
    ("del calabozo", "de la mazmorra"), ("El calabozo", "La mazmorra"), ("el calabozo", "la mazmorra"),
    ("Un calabozo", "Una mazmorra"), ("un calabozo", "una mazmorra"),
    ("Este calabozo", "Esta mazmorra"), ("este calabozo", "esta mazmorra"),
    ("CALABOZOS", "MAZMORRAS"), ("CALABOZO", "MAZMORRA"),
    ("Calabozos", "Mazmorras"), ("calabozos", "mazmorras"), ("Calabozo", "Mazmorra"), ("calabozo", "mazmorra"),
]


# 1.2.0: Calidad de vida vive dentro de Comodidades (motor/Alfa/UI/Options.lua).
# Los avisos del motor que mandaban a "Quality of Life > ..." dicen ahora el
# nombre de Comodidades en cada idioma (las pestañas siguen con su nombre).
_FRASES_QOL = [
    "Classic limits; Forever may differ (set them under Quality of Life, Trackers).",
    "The XP tracker is off (Options > Quality of Life > Trackers).",
    "Level-up spell cards are off. Turn them back on under Options > Quality of Life > Vendors > Trainers.",
    "Old rank cards are off. Turn them back on under Options > Quality of Life > Vendors > Trainers.",
]
_COMODIDADES = {"esMX": "Comodidades", "esES": "Comodidades", "deDE": "Komfort", "frFR": "Confort de jeu",
                "ptBR": "Comodidades", "ruRU": "Удобства", "koKR": "편의 기능", "zhCN": "便利功能", "zhTW": "便利功能"}


def comodidades(dist: pathlib.Path) -> list:
    errores = []
    nuevas = {f: f.replace("Quality of Life", "Conveniences") for f in _FRASES_QOL}
    for ruta in sorted(dist.glob("Alfa*/**/*.lua")):
        try:
            texto = ruta.read_bytes().decode("utf-8")
        except UnicodeDecodeError:
            continue  # un archivo de datos en otra codificación: no tiene estos avisos
        if "Quality of Life" not in texto:
            continue
        nuevo = texto
        for vieja, buena in nuevas.items():
            nuevo = nuevo.replace(vieja, buena)
        loc = ruta.parent.name[5:] if ruta.parent.name.startswith("Alfa_") else ""
        if loc in _COMODIDADES and ruta.name == "Interface.lua":
            m = re.search(r'^L\["Quality of Life"\] = "([^"\n]*)"', nuevo, re.M)
            if m:
                qol, com = m.group(1), _COMODIDADES[loc]
                lineas = nuevo.split("\n")
                for i, linea in enumerate(lineas):
                    if any(linea.startswith(f'L["{b}"]') for b in nuevas.values()):
                        clave, _, valor = linea.partition("] = ")
                        lineas[i] = clave + "] = " + valor.replace(qol, com)
                nuevo = "\n".join(lineas)
        if nuevo != texto:
            ruta.write_bytes(nuevo.encode("utf-8"))
    return errores


def mazmorras(dist: pathlib.Path) -> list:
    rutas = sorted((dist / "Alfa_esMX").glob("*.lua")) + [dist / "Alfa_Codex" / "Alfa_Codex.toc"]
    for ruta in rutas:
        if not ruta.exists():
            continue
        texto = ruta.read_bytes().decode("utf-8")
        nuevo = texto
        for viejo, bueno in _MAZMORRAS:
            nuevo = nuevo.replace(viejo, bueno)
        if nuevo != texto:
            ruta.write_bytes(nuevo.encode("utf-8"))
    return []


def limpiar(dist: pathlib.Path, cfg: dict) -> list:
    errores = []
    for ruta in sorted(dist.glob("Alfa_????/Interface.lua")):
        texto = ruta.read_bytes().decode("latin-1")
        nuevo = _SOBRANTE.sub("", texto)
        if nuevo != texto:
            ruta.write_bytes(nuevo.encode("latin-1"))
    errores += mazmorras(dist)
    errores += comodidades(dist)
    readme = dist / "Alfa" / "README.txt"
    if readme.exists():
        web = cfg["urls"]["issues"].rsplit("/issues", 1)[0]
        readme.write_text(_README.format(version=cfg["version"], web=web, discord=cfg["urls"]["discord"]),
                          encoding="utf-8", newline="\r\n")
    else:
        errores.append("Alfa/README.txt: no existe")
    return errores
