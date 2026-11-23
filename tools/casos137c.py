"""Los casos de tools/banco/prueba_137c_bugs.lua (1.3.7): cada uno es una
corrida aparte del banco que entra al juego en otra situación (/reload en
mazmorra, en combate, en grifo, muerto, en banda de 40, el juego en alemán o
chino, la interfaz escalada, Sencillo o Completo, cada módulo apagado y una
cuenta vieja). tools/prueba.py los corre con `correr_casos`.

Lo que va antes de cargar los addons (tools/banco/casos_137c.lua) viaja en
BANCO_GUARDADAS, el archivo de variables guardadas del banco: así un caso
«/reload» lee lo que guardó el caso anterior, como el juego.

Con `respaldos/` (los WTF de Toxic, no se suben), también entra con la cuenta
de la 1.1.2 y la de hoy, de verdad.
"""
import pathlib
import tempfile
import zipfile

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ANTES = RAIZ / "tools" / "banco" / "casos_137c.lua"
ESCENA = "prueba_137c_bugs.lua"

# Los módulos que el jugador puede apagar en la lista de addons.
APAGABLES = ["Alfa_Inicio", "Alfa_Rutas", "Alfa_Enciclopedia", "Alfa_Builds", "Alfa_Bolsas", "Alfa_Manada",
             "Alfa_Mazmorras", "Alfa_Mundo", "Alfa_Comodidades", "Alfa_Comercio", "Alfa_Recoleccion", "Alfa_Pesca",
             "Alfa_Combate", "Alfa_Curacion", "Alfa_Bienvenida", "Alfa_Lya", "Alfa_Vista", "Alfa_Codex",
             "Alfa_Idioma", "Alfa_Nav_Kalimdor"]
SOLO_NUCLEO = ["Alfa", "Alfa_esMX", "Alfa_Nucleo"]


def lua(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return "{" + ", ".join(f"[{lua(k)}] = {lua(x)}" for k, x in v.items()) + "}"


def casos():
    """-> [(nombre, caso, recarga_del_anterior, modulos o None)]"""
    c = [
        ("cuenta de la 1.2.x", {"vieja": True}, False, None),
        ("/reload en mazmorra con secretos", {"recarga": True, "mazmorra": True, "secretos": True}, True, None),
        ("/reload en combate en mazmorra", {"recarga": True, "mazmorra": True, "combate": True, "secretos": True}, True, None),
        ("/reload en grifo", {"recarga": True, "grifo": True}, True, None),
        ("/reload muerto (fantasma)", {"recarga": True, "fantasma": True}, True, None),
        ("/reload en banda de 40 en combate", {"recarga": True, "banda": True, "combate": True, "secretos": True}, True, None),
        ("juego en alemán, en mazmorra", {"idioma": "deDE", "mazmorra": True, "secretos": True}, False, None),
        ("juego en chino, en banda", {"idioma": "zhCN", "banda": True}, False, None),
        ("juego en chino, /reload en combate", {"idioma": "zhCN", "recarga": True, "combate": True}, True, None),
        ("interfaz al 64 %, Sencillo", {"escala": 0.64, "modo": "sencillo"}, False, None),
        ("interfaz al 120 %, Completo, en grifo", {"escala": 1.2, "modo": "completo", "grifo": True}, False, None),
        ("Sencillo en combate", {"modo": "sencillo", "combate": True, "secretos": True}, False, None),
        ("solo el núcleo", {"secretos": True}, False, SOLO_NUCLEO),
    ]
    for m in APAGABLES:
        c.append((f"sin {m}", {"quitar": m, "secretos": True, "combate": m in ("Alfa_Combate", "Alfa_Curacion")}, False, "-" + m))
    return c


def respaldos():
    """-> [(nombre, texto de las variables guardadas)] de los WTF de Toxic, si están."""
    zips = sorted((RAIZ / "respaldos").glob("WTF-*.zip"))
    if not zips:
        return []
    out = []
    for nombre, z in (("cuenta real más vieja", zips[0]), ("cuenta real de hoy", zips[-1])):
        try:
            with zipfile.ZipFile(z) as f:
                partes = []
                for n in f.namelist():
                    if n.endswith(".lua") and "/SavedVariables/Alfa" in n:
                        partes.append(f.read(n).decode("utf-8", "replace"))
                if partes:
                    out.append((f"{nombre} ({z.stem})", "\n".join(partes)))
        except (OSError, zipfile.BadZipFile):
            pass
    return out


def correr_casos(correr, modulos: str):
    """correr(escena, entorno, modulos) -> (salida, cortado). -> (salida, cortado)"""
    antes = ANTES.read_text(encoding="utf-8")
    archivo = pathlib.Path(tempfile.gettempdir()) / "alfa_banco_137c.lua"
    todo, cortado, guardadas = [], None, ""
    lista = [(n, c, r, m, None) for n, c, r, m in casos()]
    for nombre, texto in respaldos():
        # Como en el juego desde el 20/11/2026: el reino llega vacío y el personaje es Toxic.
        lista.append((nombre, {"secretos": True, "reinoVacio": True, "yo": "Toxic"}, False, None, texto))
        lista.append((nombre + ", /reload en mazmorra", {"recarga": True, "mazmorra": True, "secretos": True}, True, None, None))
    for nombre, caso, recarga, mods, texto in lista:
        caso = dict(caso, nombre=nombre)
        previas = guardadas if recarga else (texto or "")
        archivo.write_text(previas + "\nBANCO_CASO = " + lua(caso) + "\n" + antes, encoding="utf-8")
        if mods is None:
            usar = modulos
        elif isinstance(mods, str) and mods.startswith("-"):
            usar = ",".join(x for x in modulos.split(",") if x != mods[1:])
        else:
            usar = ",".join(mods)
        salida, c = correr(ESCENA, {"BANCO_GUARDADAS": str(archivo)}, usar)
        todo.append(f"CASO {nombre}")
        todo += salida
        cortado = cortado or (c and f"{nombre}: {c}")
        try:
            guardadas = archivo.read_text(encoding="utf-8")
        except OSError:
            guardadas = ""
    try:
        archivo.unlink()
    except OSError:
        pass
    return todo, cortado
