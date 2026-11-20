"""Revisa que archivos Lua compilen (sin construir dist/): python -I tools/sintaxis.py archivo.lua [...]

Úsalo con el Python del .venv (necesita lupa):
  .venv/Scripts/python -I tools/sintaxis.py src/Alfa_Inicio/Inicio.lua motor/Alfa/UI/Options.lua
Sin argumentos revisa los .lua de src/ y motor/ cambiados según git.
Además revisa que cada textos/<idioma>/*.json sea JSON válido.
"""
import json
import pathlib
import subprocess
import sys

import lupa.lua51 as lua51

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def main() -> int:
    archivos = sys.argv[1:]
    if not archivos:
        salida = subprocess.run(["git", "status", "--porcelain"], cwd=RAIZ, capture_output=True, text=True).stdout
        archivos = [l[3:].strip() for l in salida.splitlines() if l[3:].strip().endswith(".lua")]
    lua = lua51.LuaRuntime()
    compilar = lua.eval("function(src, name) local f, e = loadstring(src, '@' .. name) return e end")
    malos = 0
    for a in archivos:
        p = (RAIZ / a) if not pathlib.Path(a).is_absolute() else pathlib.Path(a)
        if not p.exists() or p.suffix != ".lua":
            continue
        src = p.read_bytes().decode("utf-8", errors="replace")
        if src.startswith("﻿"):
            src = src[1:]
        err = compilar(src, str(p.relative_to(RAIZ)) if p.is_relative_to(RAIZ) else str(p))
        if err:
            malos += 1
            print("ERROR", err)
    for j in sorted((RAIZ / "textos").glob("*/*.json")):
        try:
            json.loads(j.read_text(encoding="utf-8"))
        except Exception as e:  # noqa: BLE001
            malos += 1
            print("JSON MALO", j, e)
    print("sintaxis:", "con errores" if malos else "bien", "(%d archivos Lua)" % len(archivos))
    return 1 if malos else 0


if __name__ == "__main__":
    sys.exit(main())
