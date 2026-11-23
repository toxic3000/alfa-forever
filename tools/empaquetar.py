"""Arma el .zip de Alfa para subirlo a CurseForge.

Uso:  python -I tools/empaquetar.py        (antes corre tools/build.py)
      python -I tools/empaquetar.py --salida 1.3.7-fix
         (un zip con otro nombre, para un arreglo suelto: paquetes/1.3.7-fix.zip)

Deja paquetes/Alfa-<version>.zip con las carpetas de addon en la raiz del
zip (Alfa, Alfa_Nucleo, Alfa_Bolsas...), como pide CurseForge, mas
NOTICE-ALFA.txt dentro de la carpeta Alfa. Tambien escribe a un lado la
lista de carpetas y el tamano, para revisarlo antes de subir.
"""
import json
import pathlib
import sys
import zipfile

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def nombre_pedido(argumentos: list) -> str | None:
    for i, a in enumerate(argumentos):
        if a == "--salida" and i + 1 < len(argumentos):
            return argumentos[i + 1]
        if a.startswith("--salida="):
            return a.split("=", 1)[1]
    return None


def main() -> int:
    cfg = json.loads((RAIZ / "tools" / "alfa.json").read_text(encoding="utf-8"))
    dist = RAIZ / "dist"
    if not (dist / "Alfa" / "Alfa.toc").exists():
        print("Falta dist/: corre tools/build.py")
        return 1
    version = cfg["version"]
    pedido = nombre_pedido(sys.argv[1:])
    if pedido:
        # Sin ruta ni .zip: un nombre suelto dentro de paquetes/.
        nombre = pathlib.Path(pedido).name
        if nombre.lower().endswith(".zip"):
            nombre = nombre[:-4]
        nombre += ".zip"
    else:
        nombre = f"Alfa-{version}.zip"
    salida = RAIZ / "paquetes" / nombre
    salida.parent.mkdir(exist_ok=True)
    carpetas = sorted(p for p in dist.iterdir() if p.is_dir())
    for c in carpetas:
        for toc in c.glob("*.toc"):
            v = next((l.split(":", 1)[1].strip() for l in toc.read_text(encoding="utf-8").splitlines()
                      if l.startswith("## Version:")), None)
            if v != version:
                print(f"{toc.relative_to(dist)} dice version {v}, no {version}: vuelve a construir")
                return 1
    total = 0
    with zipfile.ZipFile(salida, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for c in carpetas:
            for f in sorted(c.rglob("*")):
                if f.is_file():
                    z.write(f, f.relative_to(dist).as_posix())
                    total += f.stat().st_size
        z.write(dist / "NOTICE-ALFA.txt", "Alfa/NOTICE-ALFA.txt")
    tam = salida.stat().st_size
    resumen = {"version": version, "zip": salida.name, "zip_mb": round(tam / 1048576, 1),
               "sin_comprimir_mb": round(total / 1048576, 1), "carpetas": [c.name for c in carpetas]}
    (salida.with_suffix(".json")).write_text(json.dumps(resumen, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"OK {salida.relative_to(RAIZ)}: {len(carpetas)} carpetas, "
          f"{resumen['sin_comprimir_mb']} MB -> {resumen['zip_mb']} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
