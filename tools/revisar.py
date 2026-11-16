"""Revision automatica de dist/ sin abrir el juego.

Uso:  .venv/Scripts/python -I tools/revisar.py [carpeta ...]

1. Sintaxis: compila cada .lua con Lua 5.1, la misma version que usa WoW.
2. Manifiestos: cada archivo que nombra un .toc o un .xml existe, y cada
   dependencia (## Dependencies / RequiredDeps) es una carpeta de dist/.
3. Nombre viejo: avisa si queda "Polestar" en el codigo de los modulos propios.
Sale con codigo 1 si encuentra errores.
"""
import os
import pathlib
import re
import sys

import lupa.lua51 as lua51

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import renombrar  # noqa: E402

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DIST = pathlib.Path(os.environ.get("ALFA_DIST") or RAIZ / "dist")
_lua = lua51.LuaRuntime(unpack_returned_tuples=True)
_compilar = _lua.eval("function(src, name) local f, e = loadstring(src, name) return e end")


def sintaxis(archivo: pathlib.Path) -> str | None:
    datos = archivo.read_bytes()
    if datos.startswith(b"\xef\xbb\xbf"):
        datos = datos[3:]
    error = _compilar(datos, "@" + str(archivo.relative_to(DIST)))
    return None if error is None else str(error)


def archivos_xml(xml: pathlib.Path, errores: list, vistos: set) -> None:
    if xml in vistos:
        return
    vistos.add(xml)
    texto = xml.read_bytes().decode("latin-1")
    texto = re.sub(r"<!--.*?-->", "", texto, flags=re.S)
    for ruta in re.findall(r'<(?:Script|Include)\s+file="([^"]+)"', texto):
        destino = xml.parent / ruta.replace("\\", "/")
        if not destino.exists():
            errores.append(f"{xml.relative_to(DIST)} nombra {ruta}, que no existe")
        elif destino.suffix.lower() == ".xml":
            archivos_xml(destino, errores, vistos)


def manifiesto(toc: pathlib.Path, errores: list) -> None:
    carpeta = toc.parent
    texto = toc.read_bytes().decode("latin-1")
    vistos: set = set()
    for linea in texto.replace("\r\n", "\n").split("\n"):  # no splitlines(): ver build.py
        l = linea.strip()
        m = re.match(r"##\s*(Dependencies|RequiredDeps|Dep\w*)\s*:\s*(.*)", l)
        if m:
            for dep in [d.strip() for d in m.group(2).split(",") if d.strip()]:
                if not (DIST / dep).is_dir():
                    errores.append(f"{toc.relative_to(DIST)} depende de {dep}, que no esta en dist/")
            continue
        if not l or l.startswith("#"):
            continue
        destino = carpeta / l.replace("\\", "/")
        if not destino.exists():
            errores.append(f"{toc.relative_to(DIST)} nombra {l}, que no existe")
        elif destino.suffix.lower() == ".xml":
            archivos_xml(destino, errores, vistos)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    carpetas = [DIST / a for a in sys.argv[1:]] or sorted(p for p in DIST.iterdir() if p.is_dir())
    errores: list = []
    total = 0
    for carpeta in carpetas:
        for archivo in sorted(carpeta.rglob("*.lua")):
            total += 1
            e = sintaxis(archivo)
            if e:
                errores.append(e)
        for toc in carpeta.glob("*.toc"):
            manifiesto(toc, errores)
        if (RAIZ / "src" / carpeta.name).is_dir():
            for archivo in carpeta.rglob("*.lua"):
                codigo = "".join(t for tipo, t in renombrar.trozos_lua(
                    archivo.read_bytes().decode("latin-1")) if tipo != "comentario")
                if re.search(r"(?i)polestar", codigo):
                    errores.append(f"{archivo.relative_to(DIST)} dice Polestar fuera de comentarios")
    for e in errores:
        print("ERROR", e)
    print(f"{total} archivos Lua revisados en {len(carpetas)} carpetas: "
          f"{'sin errores' if not errores else f'{len(errores)} errores'}")
    return 1 if errores else 0


if __name__ == "__main__":
    sys.exit(main())
