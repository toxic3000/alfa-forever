"""Arma paquetes/Instalar-Alfa.exe (un solo archivo, sin consola).

Uso:  python -I instalador/construir.py

Necesita PyInstaller y Pillow en el Python con el que se corre. El ícono sale
de curseforge/avatar.png y los datos del .exe (nombre, autor, licencia) de la
versión del instalador en instalador.py.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

AQUI = pathlib.Path(__file__).resolve().parent
RAIZ = AQUI.parent
AVATAR = RAIZ / "curseforge" / "avatar.png"
SALIDA = RAIZ / "paquetes"


def main() -> int:
    version = re.search(r'^VERSION = "([^"]+)"', (AQUI / "instalador.py").read_text(encoding="utf-8"), re.M).group(1)
    n = [int(x) for x in version.split(".")] + [0]
    trabajo = pathlib.Path(tempfile.mkdtemp(prefix="alfa-instalador-"))
    try:
        icono = trabajo / "alfa.ico"
        Image.open(AVATAR).convert("RGBA").save(icono, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
        datos = trabajo / "version.txt"
        datos.write_text(f"""VSVersionInfo(
  ffi=FixedFileInfo(filevers=({n[0]}, {n[1]}, {n[2]}, 0), prodvers=({n[0]}, {n[1]}, {n[2]}, 0)),
  kids=[
    StringFileInfo([StringTable('080A04B0', [
      StringStruct('CompanyName', 'toxic3000 - La Jauria'),
      StringStruct('FileDescription', 'Instalador de Alfa para WoW Forever'),
      StringStruct('FileVersion', '{version}'),
      StringStruct('InternalName', 'Instalar-Alfa'),
      StringStruct('LegalCopyright', 'GPL-3.0 - github.com/toxic3000/alfa-forever'),
      StringStruct('OriginalFilename', 'Instalar-Alfa.exe'),
      StringStruct('ProductName', 'Alfa'),
      StringStruct('ProductVersion', '{version}')])]),
    VarFileInfo([VarStruct('Translation', [2058, 1200])])
  ]
)
""", encoding="utf-8")
        SALIDA.mkdir(exist_ok=True)
        r = subprocess.run([sys.executable, "-m", "PyInstaller", "--noconfirm", "--clean", "--onefile", "--windowed",
                            "--name", "Instalar-Alfa", "--icon", str(icono), "--version-file", str(datos),
                            "--add-data", f"{AVATAR}{';'}.",
                            # Pillow solo sirve para las capturas de diseño; no va en el .exe
                            "--exclude-module", "PIL", "--exclude-module", "numpy", "--exclude-module", "win32com",
                            "--distpath", str(SALIDA), "--workpath", str(trabajo / "build"), "--specpath", str(trabajo),
                            str(AQUI / "instalador.py")])
        if r.returncode:
            return r.returncode
    finally:
        shutil.rmtree(trabajo, ignore_errors=True)
    exe = SALIDA / "Instalar-Alfa.exe"
    print(f"OK {exe} ({exe.stat().st_size / 1048576:.1f} MB), instalador {version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
