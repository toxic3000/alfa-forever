"""Archivos del motor que Alfa reescribe por completo (su interfaz propia).

La carpeta motor/ refleja rutas de dist/ (por ejemplo motor/Alfa/Theme/Theme.lua).
build.py copia esos archivos encima del motor ya renombrado y parchado, asi que
son la version final de ese archivo: el codigo es nuestro.

Uso:
  python -I tools/motor.py tomar Alfa/UI/Options.lua [...]   copia el archivo de dist/ a motor/
                                                            y anota su base para saber si Polestar lo cambia
  python -I tools/motor.py nuevo Alfa/UI/Ventana.lua        anota un archivo nuevo (sin base en Polestar)
  python -I tools/motor.py estado                           que archivos son propios y si su base cambio

motor/BASE.json guarda, por archivo, la huella SHA256 del archivo de Polestar
(renombrado y parchado) del que se partio. Si una version nueva de Polestar
cambia ese archivo, build.py avisa para revisar si hay algo que traer.
"""
import hashlib
import json
import pathlib
import shutil
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
MOTOR = RAIZ / "motor"
BASE = MOTOR / "BASE.json"
DIST = RAIZ / "dist"


def huella(p: pathlib.Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def cargar() -> dict:
    return json.loads(BASE.read_text(encoding="utf-8")) if BASE.exists() else {}


def guardar(d: dict) -> None:
    MOTOR.mkdir(exist_ok=True)
    BASE.write_text(json.dumps(d, indent=1, sort_keys=True), encoding="utf-8")


def main() -> int:
    orden, rutas = (sys.argv[1] if len(sys.argv) > 1 else "estado"), sys.argv[2:]
    base = cargar()
    if orden == "tomar":
        for r in rutas:
            r = r.replace("\\", "/")
            origen = DIST / r
            if not origen.exists():
                print(f"No existe dist/{r}: corre tools/build.py (sin motor/{r})")
                return 1
            destino = MOTOR / r
            if destino.exists():
                print(f"motor/{r} ya existe: no se sobrescribe")
                continue
            destino.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(origen, destino)
            base[r] = huella(origen)
            print(f"tomado {r}")
        guardar(base)
        return 0
    if orden == "nuevo":
        for r in rutas:
            base[r.replace("\\", "/")] = None
        guardar(base)
        return 0
    for r, h in sorted(base.items()):
        print(f"{r}: {'nuevo' if h is None else 'basado en Polestar'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
