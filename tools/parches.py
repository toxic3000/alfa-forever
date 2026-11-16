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
