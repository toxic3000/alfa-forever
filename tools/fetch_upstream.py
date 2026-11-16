"""Baja una version publicada de Polestar, verifica su firma SHA256 y la extrae.

Uso:  python -I tools/fetch_upstream.py 0.3.7.2

Queda en upstream/polestar-<version>/ (fuera de git). Alfa se construye a partir
de ahi con tools/build.py. Polestar es GPL-3.0: ver NOTICE.md.
"""
import hashlib
import pathlib
import sys
import urllib.request
import zipfile

RAIZ = pathlib.Path(__file__).resolve().parent.parent
REPO = "https://github.com/fitzforge/polestar/releases/download"


def bajar(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "alfa-build"})
    with urllib.request.urlopen(req, timeout=300) as r:
        return r.read()


def main() -> int:
    if len(sys.argv) != 2:
        print("Uso: python -I tools/fetch_upstream.py <version>")
        return 2
    version = sys.argv[1].lstrip("v")
    nombre = f"Polestar-{version}.zip"
    destino = RAIZ / "upstream" / f"polestar-{version}"
    if destino.exists():
        print(f"Ya existe {destino}")
        return 0

    sumas = bajar(f"{REPO}/v{version}/SHA256SUMS").decode()
    esperado = next(
        (l.split()[0] for l in sumas.splitlines() if l.strip().endswith(nombre)), None
    )
    if not esperado:
        print(f"SHA256SUMS no trae {nombre}")
        return 1

    datos = bajar(f"{REPO}/v{version}/{nombre}")
    real = hashlib.sha256(datos).hexdigest()
    if real != esperado:
        print(f"Firma distinta: {real} != {esperado}")
        return 1

    zip_path = RAIZ / "upstream" / nombre
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    zip_path.write_bytes(datos)
    destino.mkdir(parents=True)
    with zipfile.ZipFile(zip_path) as z:
        for info in z.infolist():
            ruta = (destino / info.filename).resolve()
            if not str(ruta).startswith(str(destino.resolve())):
                print(f"Ruta sospechosa en el zip: {info.filename}")
                return 1
        z.extractall(destino)
    zip_path.unlink()
    print(f"OK {nombre} verificado ({real[:12]}...) en {destino}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
