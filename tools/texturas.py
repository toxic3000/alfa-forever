"""Texturas que no existen (1.4.0).

Uso:  python -I tools/texturas.py        (revisa dist/ o ALFA_DIST)

Busca en el código de Alfa ya armado (dist/) cada textura nombrada con un
texto fijo y falla si el archivo no está en el build:
  - rutas completas "Interface\\AddOns\\Alfa...\\Media\\..." (sin `..` después);
  - MEDIA .. "nombre", con MEDIA definida en el mismo archivo (también la forma
    "Interface\\AddOns\\" .. ADDON .. "\\Media\\UI\\");
  - nombres cortos del Kit: "ic-*", "sec-*", "lobo-*" (Alfa/Media/UI, como
    K.Ruta) y "viaje-*" (Alfa_Nucleo/Media, la tarjeta de viaje de Arrow.lua);
  - K.Lobo("x") y los campos lobo = "x" (Alfa/Media/UI/lobo-x);
  - K.Icono(p, "x") y K.SetIcono(t, "x") con un nombre corto.
En el juego una textura que no existe sale como un cuadro verde o vacío.
Lo que se arma con variables (`"ic-" .. nombre`) no se puede revisar aquí.
Sale con código 1 si encuentra alguna.
"""
import os
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import renombrar  # noqa: E402

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DIST = pathlib.Path(os.environ.get("ALFA_DIST") or RAIZ / "dist")
# Datos enormes sin texturas (guías, Codex, bases de objetos y misiones, traducciones).
SALTAR = re.compile(r"^Alfa_(Guides|Codex|ItemDB|QuestDB|Nav_|deDE|esES|esMX|frFR|koKR|ptBR|ruRU|zhCN|zhTW)")
EXT = (".tga", ".blp", ".png", ".jpg", ".ttf", ".otf", ".ogg", ".mp3", ".wav")
CORTO_UI = re.compile(r"^(ic|sec|lobo)-[a-z0-9-]+$")
CORTO_NUCLEO = re.compile(r"^viaje-[a-z0-9-]+$")
_cache: dict = {}


def _listado(carpeta: pathlib.Path) -> set:
    if carpeta not in _cache:
        _cache[carpeta] = {p.name.lower() for p in carpeta.iterdir()} if carpeta.is_dir() else set()
    return _cache[carpeta]


def existe(ruta_juego: str) -> bool | None:
    """-> True/False, o None si la ruta no es de un addon de dist/ (no se revisa)."""
    partes = [p for p in ruta_juego.replace("/", "\\").split("\\") if p]
    if len(partes) < 4 or partes[0].lower() != "interface" or partes[1].lower() != "addons":
        return None
    addon = partes[2]
    if not (DIST / addon).is_dir():
        return None
    carpeta = DIST.joinpath(*partes[2:-1])
    nombre = partes[-1].lower()
    nombres = _listado(carpeta)
    if pathlib.PurePath(nombre).suffix in EXT:
        return nombre in nombres
    return any(nombre + e in nombres for e in EXT)


def valor(literal: str) -> str | None:
    """El contenido de un texto Lua "..." o '...' (los [[...]] no se revisan)."""
    if len(literal) < 2 or literal[0] not in "\"'" or literal[-1] != literal[0]:
        return None
    return re.sub(r"\\(.)", r"\1", literal[1:-1])


def revisar_archivo(archivo: pathlib.Path, addon: str) -> list:
    src = archivo.read_bytes().decode("latin-1")
    trozos = list(renombrar.trozos_lua(src))
    sin_comentarios = "".join(t if tipo != "comentario" else "\n" * t.count("\n") for tipo, t in trozos)
    malos = []
    linea = 1

    def mal(nombre, como):
        malos.append(f"{archivo.relative_to(DIST)}:{linea}: {como} «{nombre}» no existe")

    # Variables con la carpeta de las texturas (MEDIA, UI_MEDIA, NUCLEO_MEDIA...).
    vars_media = {}
    for m in re.finditer(r"(?:local\s+)?([A-Za-z_][\w.]*)\s*=\s*\"(Interface\\\\AddOns\\\\[^\"]*)\"\s*(\.\.\s*ADDON\s*\.\.\s*\"([^\"]*)\")?",
                         sin_comentarios):
        base = valor('"' + m.group(2) + '"')
        if m.group(3):
            base += addon + valor('"' + m.group(4) + '"')
        if base.endswith("\\"):
            vars_media.setdefault(m.group(1), base)
    for i, (tipo, t) in enumerate(trozos):
        if tipo == "texto":
            v = valor(t)
            antes = trozos[i - 1][1] if i > 0 and trozos[i - 1][0] == "codigo" else ""
            despues = trozos[i + 1][1] if i + 1 < len(trozos) and trozos[i + 1][0] == "codigo" else ""
            sigue = despues.lstrip().startswith("..")
            pegado = re.search(r"([A-Za-z_][\w.]*)\s*\.\.\s*$", antes)
            if v and not sigue:
                if v.lower().startswith("interface\\addons\\") and "\\media\\" in v.lower() \
                        and not v.endswith(("\\", "-")) and "%" not in v:
                    if existe(v) is False:
                        mal(v, "la textura")
                elif pegado and pegado.group(1) in vars_media:
                    if existe(vars_media[pegado.group(1)] + v) is False:
                        mal(v, f"{pegado.group(1)} ..")
                elif not antes.rstrip().endswith(".."):
                    if CORTO_UI.match(v) and existe("Interface\\AddOns\\Alfa\\Media\\UI\\" + v) is False:
                        mal(v, "el ícono")
                    elif CORTO_NUCLEO.match(v) and existe("Interface\\AddOns\\Alfa_Nucleo\\Media\\" + v) is False:
                        mal(v, "el ícono de viaje")
                    elif re.search(r"\bK\.(Set)?Icono\([^,()]+,\s*$", antes) \
                            and re.fullmatch(r"[a-z][a-z0-9-]*", v) and not CORTO_NUCLEO.match(v) \
                            and existe("Interface\\AddOns\\Alfa\\Media\\UI\\" + v) is False:
                        mal(v, "el ícono")
                    elif re.search(r"(\bK\.Lobo\(\s*|\blobo\s*=\s*|\bK\.Lobo\([^()]*\b(or|and)\s*)$", antes) \
                            and re.fullmatch(r"[a-z]+", v) \
                            and existe("Interface\\AddOns\\Alfa\\Media\\UI\\lobo-" + v) is False:
                        mal(v, "el lobo")
        linea += t.count("\n")
    return malos


def revisar() -> list:
    malos = []
    for carpeta in sorted(p for p in DIST.iterdir() if p.is_dir() and p.name.startswith("Alfa")):
        if SALTAR.match(carpeta.name):
            continue
        for archivo in sorted(carpeta.rglob("*.lua")):
            malos += revisar_archivo(archivo, carpeta.name)
    return malos


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    if not (DIST / "Alfa").is_dir():
        print(f"Falta {DIST}: corre tools/build.py")
        return 1
    malos = revisar()
    for m in malos:
        print("TEXTURA FALTA", m)
    print(f"TEXTURAS: {len(malos)} nombres de textura que no existen")
    return 1 if malos else 0


if __name__ == "__main__":
    sys.exit(main())
