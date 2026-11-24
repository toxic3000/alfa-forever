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


def una_vez(escena: str, modulos: str):
    codigo = ("import sys, runpy; sys.path.insert(0, %r); sys.argv = ['run.py', %r, %r, %r]; "
              "runpy.run_path(%r, run_name='__main__')" % (str(SITE), str(DIST), modulos, escena, str(RAIZ / "tools" / "banco" / "run.py")))
    env = dict(os.environ, BANCO_PERFIL="1")
    r = subprocess.run([sys.executable, "-I", "-c", codigo], env=env, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return r.stdout + r.stderr, r.returncode


def resumen(salida: str) -> dict:
    """Los números de la línea RESUMEN de perfil.lua (1.3.9)."""
    for linea in salida.splitlines():
        if linea.startswith("RESUMEN "):
            return {k: float(v) for k, v in (x.split("=") for x in linea.split()[1:])}
    return {}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    modulos = ",".join(al_entrar())
    # --paginas: lo que cuesta abrir cada página de Alfa (tools/banco/perfil_paginas.lua).
    escena = "perfil_paginas.lua" if "--paginas" in sys.argv else "perfil.lua"
    # --veces N (1.3.9): corre N veces y se queda con la más rápida; los
    # tiempos del banco suben y bajan con lo que haga la máquina a la vez.
    veces = 1
    if "--veces" in sys.argv:
        i = sys.argv.index("--veces")
        veces = max(1, int(sys.argv[i + 1]))
        del sys.argv[i:i + 2]
    sys.argv = [a for a in sys.argv if a != "--paginas"]
    corridas = [una_vez(escena, modulos) for _ in range(veces)]
    if veces > 1 and escena == "perfil.lua":
        numeros = [resumen(s) for s, _ in corridas]
        salida, codigo = min(corridas, key=lambda c: resumen(c[0]).get("carga_ms", 1e9))
        claves = [k for k in numeros[0] if all(k in n for n in numeros)]
        tabla = ["== %d CORRIDAS (mínimo / mediana / máximo)" % veces]
        for k in claves:
            v = sorted(n[k] for n in numeros)
            tabla.append("  %-12s %9.1f %9.1f %9.1f" % (k, v[0], v[len(v) // 2], v[-1]))
        salida = salida + "\n" + "\n".join(tabla) + "\n"
    else:
        salida, codigo = corridas[0]
    print(salida)
    if len(sys.argv) > 1:
        pathlib.Path(sys.argv[1]).write_text(salida, encoding="utf-8")
    return codigo


if __name__ == "__main__":
    sys.exit(main())
