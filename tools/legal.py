"""Que cada aviso de licencia viaje en el paquete (1.4.2, docs/LEGAL.md).

Uso:  python -I tools/legal.py        (después de tools/build.py; ALFA_DIST elige otra carpeta)

Cada cosa de terceros que usa Alfa lleva su aviso de licencia en su carpeta
(MIT y GPL lo exigen) y su línea en «Acerca de» > Créditos y licencias. Si un
aviso falta en el build, esto lo dice y tools/prueba.py falla.
"""
import os
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DIST = pathlib.Path(os.environ.get("ALFA_DIST") or RAIZ / "dist")

# (archivo en el build, de qué es)
AVISOS = [
    ("Alfa/LICENSE", "Alfa y Polestar (GPL-3.0)"),
    ("Alfa_Codex/LICENSE-DATA.txt", "las fuentes de datos del Codex"),
    ("Alfa_Guides/LICENSE-DATA.txt", "las fuentes de datos de las guías"),
    ("Alfa_Nav/LICENSE", "la navegación (Shortest Path Forever, GPL)"),
    ("Alfa_Nav/CREDITS.md", "los créditos de la navegación"),
    ("Alfa_Recoleccion/LICENSE-GatherLite.txt", "GatherLite (MIT)"),
    ("Alfa_Mundo/LICENSE-OpenMap.txt", "OpenMap (MIT)"),
    ("Alfa_Mundo/LICENSE-TerrainWorldMap.txt", "TerrainWorldMap (MIT)"),
    ("Alfa_Mundo/Media/Territorios/LICENSE-OpenMap.txt", "las máscaras de OpenMap (MIT)"),
    ("Alfa/Media/Fonts/Inter-OFL.txt", "la letra Inter (OFL)"),
    ("Alfa/Media/Fonts/FiraSans-OFL.txt", "la letra Fira Sans (OFL)"),
    ("Alfa/Media/Fonts/OpenSans-OFL.txt", "la letra Open Sans (OFL)"),
]
# Lo que debe nombrar la página de créditos (motor/Alfa/UI/Options.lua, ya en el build).
CREDITOS = ["Polestar", "Shortest Path Forever", "pfQuest", "GatherLite", "OpenMap", "TerrainWorldMap", "QuestieDB", "SIL Open Font License"]


def revisar() -> list:
    faltan = []
    for ruta, que in AVISOS:
        if not (DIST / ruta).exists():
            faltan.append(f"falta {ruta} ({que})")
    opciones = DIST / "Alfa" / "UI" / "Options.lua"
    texto = opciones.read_text(encoding="utf-8", errors="replace") if opciones.exists() else ""
    for nombre in CREDITOS:
        if nombre not in texto:
            faltan.append(f"«Créditos y licencias» ya no nombra a {nombre}")
    return faltan


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    faltan = revisar()
    for f in faltan:
        print("LEGAL", f)
    print(f"LEGAL: {len(faltan)} avisos o créditos que faltan")
    return 1 if faltan else 0


if __name__ == "__main__":
    sys.exit(main())
