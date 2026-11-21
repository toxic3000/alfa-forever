"""Corre una o varias escenas del banco y enseña su salida (1.3.7).

Uso (después de tools/build.py; ALFA_DIST elige otra carpeta de build):
  python -I tools/escena.py prueba_137_oro.lua [otra.lua ...]

Termina con código 1 si alguna escena da ERROR, FALLA EN o se corta.
"""
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import prueba  # noqa: E402


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    malo = False
    for escena in sys.argv[1:]:
        salida, cortado = prueba.correr(escena)
        print("--", escena, "(" + str(prueba.DIST) + ")")
        for l in salida:
            print(l)
        if cortado:
            print("PRUEBA CORTADA:", escena, cortado)
            malo = True
        if any(l.startswith(("ERROR", "FALLA EN")) for l in salida):
            malo = True
    return 1 if malo else 0


if __name__ == "__main__":
    sys.exit(main())
