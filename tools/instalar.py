"""Instala Alfa en el juego (para la prueba final). Por omision solo SIMULA.

Uso:
  python -I tools/instalar.py              muestra lo que haria, sin tocar nada
  python -I tools/instalar.py --aplicar    lo hace (con el juego cerrado)

Pasos:
1. Comprueba que WoW este cerrado: el juego reescribe los ajustes al salir.
2. Respalda WTF/ en respaldos/WTF-<fecha>.zip.
3. Copia dist/Alfa* a Interface/AddOns (reemplaza solo carpetas Alfa*).
4. Pasa tus ajustes de Polestar a Alfa (Polestar.lua -> Alfa.lua, de la cuenta
   y de cada personaje), solo si Alfa.lua no existe todavia.
5. En AddOns.txt de cada personaje: activa Alfa* y desactiva los addons que
   Alfa reemplaza. No desinstala nada: se quitan desde la app de CurseForge.
"""
import datetime
import pathlib
import re
import shutil
import subprocess
import sys
import zipfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import renombrar  # noqa: E402

RAIZ = pathlib.Path(__file__).resolve().parent.parent
JUEGO = pathlib.Path(r"C:\Program Files (x86)\World of Warcraft\_forever_")
ADDONS = JUEGO / "Interface" / "AddOns"
WTF = JUEGO / "WTF"
REEMPLAZADOS = [
    r"Polestar.*", "Baganator", "Syndicator", "BetterFishing", "GatherLite", "OpenMap",
    "Leatrix_Maps", "Leatrix_Plus", "Pawn", "ForeverDungeonJournal", r"DBM-.*", "Sonah",
]


def juego_abierto() -> bool:
    salida = subprocess.run(["tasklist", "/FI", "IMAGENAME eq Wow.exe"],
                            capture_output=True, text=True).stdout
    return "Wow.exe" in salida


def main() -> int:
    aplicar = "--aplicar" in sys.argv
    hacer = (lambda *_: None) if not aplicar else (lambda fn, *a: fn(*a))
    dist = RAIZ / "dist"
    if not (dist / "Alfa").is_dir():
        print("Falta dist/: corre tools/build.py")
        return 1
    if aplicar and juego_abierto():
        print("WoW esta abierto: cierralo y vuelve a correr esto.")
        return 1
    print("APLICANDO" if aplicar else "SIMULACION (nada cambia; usa --aplicar)")

    fecha = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    respaldo = RAIZ / "respaldos" / f"WTF-{fecha}.zip"
    print(f"- respaldo de WTF en {respaldo}")
    if aplicar:
        respaldo.parent.mkdir(exist_ok=True)
        with zipfile.ZipFile(respaldo, "w", zipfile.ZIP_DEFLATED) as z:
            for p in WTF.rglob("*"):
                if p.is_file():
                    z.write(p, p.relative_to(WTF.parent))

    carpetas = sorted(p for p in dist.iterdir() if p.is_dir())
    for c in carpetas:
        destino = ADDONS / c.name
        print(f"- copiar {c.name} a AddOns{' (reemplaza)' if destino.exists() else ''}")
        if aplicar:
            if destino.exists():
                shutil.rmtree(destino)
            shutil.copytree(c, destino)

    for viejo in WTF.rglob("SavedVariables/Polestar.lua"):
        nuevo = viejo.with_name("Alfa.lua")
        if nuevo.exists():
            print(f"- ya existe {nuevo.relative_to(WTF)}: se deja como esta")
            continue
        print(f"- pasar ajustes {viejo.relative_to(WTF)} -> Alfa.lua")
        if aplicar:
            texto = viejo.read_bytes().decode("latin-1")
            nuevo.write_bytes(renombrar.cambiar(texto).encode("latin-1"))

    nombres = [c.name for c in carpetas]
    patron = re.compile("^(" + "|".join(REEMPLAZADOS) + ")$")
    instalados = [p.name for p in ADDONS.iterdir() if p.is_dir()]
    apagar = [n for n in instalados if patron.match(n)]
    for lista in WTF.glob("Account/*/*/*/AddOns.txt"):
        lineas = lista.read_text(encoding="utf-8", errors="replace").splitlines()
        estado = {}
        for l in lineas:
            if ":" in l:
                k, v = l.split(":", 1)
                estado[k.strip()] = v.strip()
        for n in nombres:
            estado[n] = "enabled"
        for n in apagar:
            estado[n] = "disabled"
        print(f"- {lista.relative_to(WTF)}: activar {len(nombres)} de Alfa, desactivar {len(apagar)}: "
              + ", ".join(apagar))
        if aplicar:
            lista.write_text("".join(f"{k}: {v}\n" for k, v in estado.items()), encoding="utf-8")
    print("Listo." if aplicar else "Fin de la simulacion.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
