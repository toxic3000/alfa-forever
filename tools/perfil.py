"""Perfilador de Alfa en el banco: python -I tools/perfil.py [salida.txt]

Carga solo los addons que el juego carga al entrar (los LoadOnDemand entran
cuando Alfa los pide), y corre tools/banco/perfil.lua con BANCO_PERFIL=1.
Los tiempos son del banco: sirven para comparar entre versiones.
"""
import os
import pathlib
import subprocess
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SITE = RAIZ / ".venv" / "Lib" / "site-packages"
DIST = pathlib.Path(os.environ.get("ALFA_DIST") or RAIZ / "dist")


def al_entrar() -> list:
    nombres = []
    for d in sorted(DIST.iterdir()):
        toc = next(d.glob("*.toc"), None) if d.is_dir() else None
        if not toc:
            continue
        texto = toc.read_text(encoding="utf-8", errors="replace")
        if "## LoadOnDemand: 1" in texto:
            continue
        nombres.append(d.name)
    # El motor primero, como en el juego (dependencias).
    nombres.sort(key=lambda n: (n != "Alfa", n != "Alfa_Nucleo", n != "Alfa_Guides", n))
    return nombres


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    modulos = ",".join(al_entrar())
    # --paginas: lo que cuesta abrir cada página de Alfa (tools/banco/perfil_paginas.lua).
    escena = "perfil_paginas.lua" if "--paginas" in sys.argv else "perfil.lua"
    sys.argv = [a for a in sys.argv if a != "--paginas"]
    codigo = ("import sys, runpy; sys.path.insert(0, %r); sys.argv = ['run.py', %r, %r, %r]; "
              "runpy.run_path(%r, run_name='__main__')" % (str(SITE), str(DIST), modulos, escena, str(RAIZ / "tools" / "banco" / "run.py")))
    env = dict(os.environ, BANCO_PERFIL="1")
    r = subprocess.run([sys.executable, "-I", "-c", codigo], env=env, capture_output=True, text=True, encoding="utf-8", errors="replace")
    salida = r.stdout + r.stderr
    print(salida)
    if len(sys.argv) > 1:
        pathlib.Path(sys.argv[1]).write_text(salida, encoding="utf-8")
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
