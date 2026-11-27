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


def correr(escena: str, entorno: dict | None = None, modulos: str | None = None):
    codigo = ("import sys, runpy; sys.path.insert(0, %r); sys.argv = ['run.py', %r, %r, %r]; "
              "runpy.run_path(%r, run_name='__main__')" % (str(SITE), str(DIST), modulos or MODULOS, escena, str(RAIZ / "tools" / "banco" / "run.py")))
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


def guias_iguales() -> bool:
    """-> True si algo salió mal."""
    global DIST
    import shutil
    import tempfile
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    import diferir
    import tramos
    original = DIST
    copia = pathlib.Path(tempfile.mkdtemp(prefix="alfa_guias_")) / "dist"
    try:
        shutil.copytree(DIST, copia, ignore=shutil.ignore_patterns("Media", "*.tga", "*.blp", "*.ogg", "*.mp3", "*.ttf"))
        tramos.juntar(copia)  # 1.4.0: los pasos de vuelta en Guides.lua
        for nombre in diferir.PAQUETES:
            p = copia / nombre / "Guides.lua"
            if p.exists():
                p.write_bytes(diferir.revertir(p.read_bytes().decode("latin-1")).encode("latin-1"))
        a, ca = correr("volcar_guias.lua")
        DIST = copia
        b, cb = correr("volcar_guias.lua")
    finally:
        DIST = original
        shutil.rmtree(copia.parent, ignore_errors=True)
    ga = [l for l in a if l.startswith("GUIA ")]
    gb = [l for l in b if l.startswith("GUIA ")]
    distintas = [x for x, y in zip(ga, gb) if x != y]
    print(f"GUÍAS DIFERIDAS: {len(ga)} guías comparadas, {len(distintas)} distintas de como venían")
    for x in distintas[:5]:
        print("   ", x)
    return bool(ca or cb or not ga or len(ga) != len(gb) or distintas)


TOPE_CARGA_MS, TOPE_ARMADAS = 120, 8


def tope_entrada() -> bool:
    """-> True si la entrada pasa del tope (tools/perfil.py)."""
    import re
    r = subprocess.run([sys.executable, "-I", str(RAIZ / "tools" / "perfil.py")], cwd=RAIZ, capture_output=True,
                       text=True, encoding="utf-8", errors="replace", env={**os.environ, "ALFA_DIST": str(DIST), "PYTHONIOENCODING": "utf-8"})
    m = re.search(r"== CARGA de archivos: ([\d.]+) ms", r.stdout)
    g = re.search(r"GU\S{1,3}AS al entrar: \d+ registradas, (\d+) diferidas", r.stdout)
    if not (m and g):
        print("PERFIL: no se pudo medir la entrada")
        return True
    carga, armadas = float(m.group(1)), int(g.group(1))
    print(f"PERFIL: lectura al entrar {carga:.0f} ms (tope {TOPE_CARGA_MS}), {armadas} guías armadas (tope {TOPE_ARMADAS})")
    return carga > TOPE_CARGA_MS or armadas > TOPE_ARMADAS


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
        elif escena == "prueba_140_revision.lua":
            # 1.4.0 (revisión): sola, y luego tres corridas con las mismas
            # variables guardadas: con el paquete de pasos, sin él y de vuelta.
            import tempfile
            archivo = pathlib.Path(tempfile.gettempdir()) / "alfa_banco_revision140.lua"
            if archivo.exists():
                archivo.unlink()
            salida, cortado = correr(escena)
            for fase in ("a", "b", "c"):
                s, c = correr(escena, {"BANCO_GUARDADAS": str(archivo), "BANCO_FASE": fase})
                salida += s
                cortado = cortado or c
        elif escena == "prueba_137c_bugs.lua":
            # 1.3.7: cada caso entra al juego en otra situación (tools/casos137c.py).
            sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
            import casos137c
            salida, cortado = casos137c.correr_casos(correr, MODULOS)
        else:
            salida, cortado = correr(escena)
        if escena != "prueba.lua":
            print("--", escena)
        for l in salida:
            if l.startswith(("FALLA EN", "   ", "AVISO", "PRUEBA:", "errores al entrar", "ERROR", "CASO ")):
                print(l)
        if cortado:
            print("PRUEBA CORTADA:", escena, cortado)
            malo = True
        # 1.4.0 (revisión): una escena que ni corre (un error de sintaxis en la
        # prueba) también falla; antes solo salía su traza y daba «todo bien».
        rota = [l for l in salida if l.startswith("lupa.lua51.LuaError")]
        for l in rota:
            print("ESCENA ROTA:", escena, l)
        if rota:
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
    # Guías diferidas (1.3.4): las 260 guías, ya armadas por el motor, deben
    # quedar iguales con los pasos diferidos y como venían (diferir.py --revertir).
    malo = guias_iguales() or malo
    # El tope de la entrada (tools/perfil.py): lectura de archivos y guías armadas.
    malo = tope_entrada() or malo
    # 1.3.9: la prueba visual (tools/regresion.py): lo que cambió desde la
    # referencia sale como AVISO VISUAL (no falla); una página que no abre o un
    # error de Lua, sí.
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    import regresion
    errores_visual, _ = regresion.revisar()
    malo = bool(errores_visual) or malo
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
    # 1.4.0: cada textura nombrada con un texto fijo existe en el build
    # (tools/texturas.py; un ícono que no existe sale verde o vacío en el juego).
    import texturas
    texturas.DIST = DIST
    faltan = texturas.revisar()
    for m in faltan:
        print("TEXTURA FALTA", m)
    print(f"TEXTURAS: {len(faltan)} nombres de textura que no existen")
    malo = bool(faltan) or malo
    # 1.4.0: globales por accidente (tools/globales.py, lee el bytecode con lupa).
    sys.path.insert(0, str(SITE))
    import globales
    globales.DIST = DIST
    sueltos = globales.revisar()
    for m in sueltos:
        print("GLOBAL", m)
    print(f"GLOBALES: {len(sueltos)} globales por accidente")
    malo = bool(sueltos) or malo
    # 1.4.2: cada aviso de licencia y cada crédito, en el paquete (tools/legal.py, docs/LEGAL.md).
    import legal
    legal.DIST = DIST
    faltan_legal = legal.revisar()
    for m in faltan_legal:
        print("LEGAL", m)
    print(f"LEGAL: {len(faltan_legal)} avisos o créditos que faltan")
    malo = bool(faltan_legal) or malo
    # 1.4.2: la trampa del secreto: «N.Leer(x) or x» devuelve el secreto (el «or»)
    # cuando x lo es; así se coló un error en mazmorras. Se busca en todo el código.
    import re
    trampa = re.compile(r"N\.Leer(?:Numero)?\s*\(\s*([\w.]+)[^()]*\)\s+or\s+(?:tonumber\()?")
    trampas = []
    for base in ("src", "motor"):
        for ruta in sorted((RAIZ / base).rglob("*.lua")):
            for n, linea in enumerate(ruta.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                if trampa.search(linea) and not linea.lstrip().startswith("--"):
                    trampas.append(f"{ruta.relative_to(RAIZ).as_posix()}:{n}")
    for x in trampas:
        print("TRAMPA DEL SECRETO", x)
    print(f"SECRETOS: {len(trampas)} lecturas que devolverían el secreto")
    malo = bool(trampas) or malo
    # 1.4.1: el mapa del código al día y cada archivo con su cabecera (tools/mapa.py).
    import mapa
    texto_mapa, sin_cabecera = mapa.armar()
    for m in sin_cabecera:
        print("SIN CABECERA", m)
    atrasado = not mapa.SALIDA.exists() or mapa.SALIDA.read_text(encoding="utf-8") != texto_mapa
    print(f"MAPA: {len(sin_cabecera)} archivos sin cabecera{', docs/MAPA.md atrasado (python -I tools/mapa.py)' if atrasado else ''}")
    malo = bool(sin_cabecera) or atrasado or malo
    print("RESULTADO:", "con problemas" if malo else "todo bien")
    return 1 if malo else 0


if __name__ == "__main__":
    sys.exit(main())
