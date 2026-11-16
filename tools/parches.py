"""Parches de Alfa sobre el codigo ya renombrado.

Cada parche es (archivo, texto_original, texto_nuevo). El texto original debe
aparecer exactamente una vez; si no, la construccion se detiene para revisar a
mano que cambio en Polestar.
"""
import pathlib


def _creditos(cfg):
    return (
        '"Alfa: Toxic - La Jauría. Basado en Polestar de The Polestar authors '
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
     "It is built on Polestar, the free and open-source leveling guide by The Polestar authors. "
     "Alfa is free and open source too, under the GPL-3.0.",
     "Está construido sobre Polestar, la guía libre y de código abierto de The Polestar authors. "
     "Alfa también es libre y de código abierto, bajo la GPL-3.0."),
    ("Anyone can read the code, fix a step, sharpen a route or write a new guide, and contributions are welcome. "
     "The GPL keeps it that way: every copy and every fork stays open.",
     "Made by Toxic and La Jauría. Come play with the pack: our Discord is open to everyone.",
     "Hecho por Toxic y La Jauría. Ven a jugar con la manada: nuestro Discord está abierto para todos."),
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

# Textos que se agregan al final de un archivo: las traducciones de lo nuevo.
AGREGADOS = [
    (f"Alfa_{loc}/Interface.lua",
     "\n-- Alfa: pagina Acerca de\n" + "".join(f'L["{n}"] = "{es}"\n' for _, n, es in ACERCA))
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
    return errores
