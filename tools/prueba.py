"""Prueba de navegación y funcionalidad de Alfa en el banco, con un tope de memoria.

Uso (desde la raíz, después de tools/build.py):
  python -I tools/prueba.py

Corre tools/banco/prueba.lua con todos los módulos: la bienvenida completa,
todas las páginas en los 3 estilos, el mapa (zoom, arrastre, bordes, capas,
tamaño), las ventanas de cada módulo, Lya, combate y eventos. Después corre las
escenas de la galería para el detector de textos cortados.

Termina con código 1 si hay algún error de Lua o algún texto CORTADO. El banco
corre en otro proceso que se corta si pasa de 3 GB o de 5 minutos (un marco de
Blizzard que el banco no simula puede comerse la memoria).
"""
import ctypes
import ctypes.wintypes as wt
import os
import pathlib
import subprocess
import sys
import time

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SITE = RAIZ / ".venv" / "Lib" / "site-packages"
MODULOS = ",".join([
    "Alfa", "Alfa_esMX", "Alfa_Idioma", "Alfa_Nucleo", "Alfa_Guides", "Alfa_Guides_Horde", "Alfa_Guides_Orc",
    "Alfa_Codex", "Alfa_ItemDB", "Alfa_QuestDB", "Alfa_Nav", "Alfa_Nav_Kalimdor", "Alfa_Inicio", "Alfa_Rutas",
    "Alfa_Enciclopedia", "Alfa_Builds", "Alfa_Bolsas", "Alfa_Manada", "Alfa_Mazmorras", "Alfa_Mundo",
    "Alfa_Comodidades", "Alfa_Comercio", "Alfa_Recoleccion", "Alfa_Pesca", "Alfa_Combate", "Alfa_Curacion",
    "Alfa_Bienvenida", "Alfa_Lya", "Alfa_Vista"])
TOPE_MB, TOPE_S = 3000, 300
DIST = pathlib.Path(os.environ.get("ALFA_DIST") or RAIZ / "dist")


class PMC(ctypes.Structure):
    _fields_ = [("cb", wt.DWORD), ("PageFaultCount", wt.DWORD), ("PeakWorkingSetSize", ctypes.c_size_t),
                ("WorkingSetSize", ctypes.c_size_t), ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPagedPoolUsage", ctypes.c_size_t), ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                ("QuotaNonPagedPoolUsage", ctypes.c_size_t), ("PagefileUsage", ctypes.c_size_t),
                ("PeakPagefileUsage", ctypes.c_size_t)]


def memoria_mb(p) -> int:
    if os.name != "nt":
        return 0
    c = PMC()
    c.cb = ctypes.sizeof(c)
    if ctypes.windll.psapi.GetProcessMemoryInfo(int(p._handle), ctypes.byref(c), c.cb):
        return max(c.WorkingSetSize, c.PagefileUsage) // (1024 * 1024)
    return 0


def correr(escena: str, entorno: dict | None = None):
    codigo = ("import sys, runpy; sys.path.insert(0, %r); sys.argv = ['run.py', %r, %r, %r]; "
              "runpy.run_path(%r, run_name='__main__')" % (str(SITE), str(DIST), MODULOS, escena, str(RAIZ / "tools" / "banco" / "run.py")))
    p = subprocess.Popen([sys.executable, "-u", "-c", codigo], cwd=RAIZ, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, env={**os.environ, "PYTHONUNBUFFERED": "1", "PYTHONIOENCODING": "utf-8", **(entorno or {})})
    inicio, salida = time.time(), []
    import threading
    hilo = threading.Thread(target=lambda: salida.extend(p.stdout.read().decode("utf-8", "replace").splitlines()))
    hilo.start()
    cortado = None
    while p.poll() is None:
        time.sleep(1)
        mb = memoria_mb(p)
        if mb > TOPE_MB or time.time() - inicio > TOPE_S:
            p.kill()
            p.wait()
            cortado = f"cortado a los {time.time() - inicio:.0f} s con {mb} MB"
            break
    hilo.join(10)
    return salida, cortado


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    if not (DIST / "Alfa").is_dir():
        print(f"Falta {DIST}: corre tools/build.py")
        return 1
    malo = False
    salen = 0
    # prueba.lua y las pruebas de cada área (tools/banco/prueba_*.lua).
    escenas = ["prueba.lua"] + sorted(x.name for x in (RAIZ / "tools" / "banco").glob("prueba_*.lua"))
    for escena in escenas:
        if escena == "prueba_ajustes.lua":
            # Dos corridas con las mismas variables guardadas: como un /reload (1.1.9).
            import tempfile
            archivo = pathlib.Path(tempfile.gettempdir()) / "alfa_banco_guardadas.lua"
            if archivo.exists():
                archivo.unlink()
            salida, cortado = [], None
            for fase in ("0", "1", "2"):
                s, c = correr(escena, {"BANCO_GUARDADAS": str(archivo), "BANCO_FASE": fase})
                salida += s
                cortado = cortado or c
        else:
            salida, cortado = correr(escena)
        if escena != "prueba.lua":
            print("--", escena)
        for l in salida:
            if l.startswith(("FALLA EN", "   ", "AVISO", "PRUEBA:", "errores al entrar", "ERROR")):
                print(l)
        if cortado:
            print("PRUEBA CORTADA:", escena, cortado)
            malo = True
        if any(l.startswith("ERROR") or l.startswith("FALLA EN") for l in salida):
            malo = True
    for escena in ("galeria.lua", "galeria110.lua"):
        salida, cortado = correr(escena)
        for l in salida:
            if l.startswith("CORTADO"):
                print(l)
                malo = True
            if l.startswith("SALE"):
                print(l)
                salen += 1
        if cortado:
            print("GALERÍA CORTADA:", escena, cortado)
            malo = True
    if salen:
        print(f"{salen} textos se salen de su caja (revisar: alineación)")
        malo = True
    # Orillas limpias en los iconos (tools/sangrado.py, 1.1.8): casi ningún
    # pixel transparente negro junto a uno visible (los que quedan son sombras).
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    import sangrado
    from PIL import Image
    sucias = 0
    for sub in ("Map", "Nav", "UI"):
        for tga in sorted((DIST / "Alfa" / "Media" / sub).glob("*.tga")):
            with Image.open(tga) as img:
                sucias += sangrado.orillas_sucias(img)
    print(f"ORILLAS: {sucias} pixeles de orilla sucia en los iconos")
    if sucias > 40:
        print("ORILLAS SUCIAS: corre tools/build.py (tools/sangrado.py)")
        malo = True
    print("RESULTADO:", "con problemas" if malo else "todo bien")
    return 1 if malo else 0


if __name__ == "__main__":
    sys.exit(main())
