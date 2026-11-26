"""Abre una versión nueva de Alfa (1.4.1) en un paso.

Uso:
  python -I tools/nueva_version.py 1.4.2 "tema corto"     (sin versión: el parche siguiente)

Hace lo de siempre al empezar una versión, para que no se olvide nada:
  1. Sube `version` en tools/alfa.json (nunca la baja: regla de Toxic).
  2. Agrega la sección de la versión al CHANGELOG.md (español e inglés, vacía).
  3. Crea textos/<idioma>/Alfa_<versión>.json vacíos (las traducciones nuevas).
  4. Copia tools/banco/plantilla_prueba.lua a tools/banco/prueba_<NNN>_<tema>.lua.
  5. Escribe docs/MAPA.md al día (tools/mapa.py).
Y enseña la lista de lo que falta para publicar (docs/VERSIONES.md).
"""
import datetime
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ALFA = RAIZ / "tools" / "alfa.json"
IDIOMAS = ["deDE", "frFR", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]


def partes(v: str) -> tuple[int, int, int]:
    m = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", v.strip())
    if not m:
        raise SystemExit(f"Versión inválida: {v!r} (usa MAYOR.MENOR.PARCHE)")
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def tema_archivo(t: str) -> str:
    t = t.lower()
    for a, b in zip("áéíóúüñ", "aeiouun"):
        t = t.replace(a, b)
    t = re.sub(r"[^a-z0-9]+", "_", t).strip("_")
    return t or "tema"


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    datos = json.loads(ALFA.read_text(encoding="utf-8"))
    actual = datos["version"]
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if args and re.fullmatch(r"\d+\.\d+\.\d+", args[0]):
        nueva, tema = args[0], " ".join(args[1:]) or "revision"
    else:
        a, b, c = partes(actual)
        nueva, tema = f"{a}.{b}.{c + 1}", " ".join(args) or "revision"
    if partes(nueva) <= partes(actual):
        print(f"La versión {nueva} no es mayor que {actual}: nunca se baja el número (regla de Toxic).")
        return 1
    hoy = datetime.date.today().strftime("%d/%m/%Y")

    # 1. tools/alfa.json (sin tocar nada más del archivo)
    texto = ALFA.read_text(encoding="utf-8")
    ALFA.write_text(texto.replace(f'"version": "{actual}"', f'"version": "{nueva}"', 1), encoding="utf-8")
    print(f"1. tools/alfa.json: {actual} -> {nueva}")

    # 2. CHANGELOG.md
    cl = RAIZ / "CHANGELOG.md"
    t = cl.read_text(encoding="utf-8")
    if f"## {nueva} " not in t:
        seccion = (f"## {nueva} — (título) ({hoy})\n\n(Una línea de qué trae.)\n\n**Español**\n\n"
                   "*Arreglos de lo que viste en el juego*\n- \n\n**English**\n\n*Fixes for what you saw in the game*\n- \n\n")
        t = t.replace("# Cambios de Alfa\n\n", "# Cambios de Alfa\n\n" + seccion, 1)
        cl.write_text(t, encoding="utf-8")
        print("2. CHANGELOG.md: sección nueva arriba (llénala en español y en inglés)")
    else:
        print("2. CHANGELOG.md: ya tenía la sección")

    # 3. textos/<idioma>/Alfa_<versión>.json
    hechos = 0
    for loc in IDIOMAS:
        p = RAIZ / "textos" / loc / f"Alfa_{nueva}.json"
        if not p.exists():
            p.write_text("{}\n", encoding="utf-8")
            hechos += 1
    print(f"3. textos: {hechos} archivos Alfa_{nueva}.json nuevos")

    # 4. La prueba de la versión
    a, b, c = partes(nueva)
    num = f"{a}{b}{c}"
    destino = RAIZ / "tools" / "banco" / f"prueba_{num}_{tema_archivo(tema)}.lua"
    if not destino.exists():
        plantilla = (RAIZ / "tools" / "banco" / "plantilla_prueba.lua").read_text(encoding="utf-8")
        destino.write_text(plantilla.replace("{VERSION}", nueva).replace("{TEMA}", tema), encoding="utf-8")
        print(f"4. {destino.relative_to(RAIZ).as_posix()}: la prueba de la versión (escribe ahí el error primero)")
    else:
        print(f"4. {destino.relative_to(RAIZ).as_posix()} ya existía")

    # 5. El mapa
    sys.path.insert(0, str(RAIZ / "tools"))
    import mapa
    texto_mapa, _ = mapa.armar()
    mapa.SALIDA.write_text(texto_mapa, encoding="utf-8")
    print("5. docs/MAPA.md al día")

    print(f"""
Lo que falta para publicar la {nueva} (docs/VERSIONES.md):
  - el error primero en su prueba (que falle con el código de antes), luego el arreglo
  - python -I tools/build.py
  - .venv/Scripts/python -I tools/revisar.py   y   .venv/Scripts/python -I tools/humo.py
  - .venv/Scripts/python -I tools/textos.py estado
  - python -I tools/prueba.py   hasta «RESULTADO: todo bien»
  - con WoW cerrado: python -I tools/instalar.py --aplicar   (y Toxic lo prueba)
  - python -I tools/empaquetar.py   y   python -I instalador/construir.py
  - commit «Alfa {nueva}», git tag -a v{nueva}, git push --follow-tags, GitHub Release
  - CurseForge junto con Toxic, y python -I tools/anunciar.py version {nueva}""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
