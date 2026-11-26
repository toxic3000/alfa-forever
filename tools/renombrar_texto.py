"""Cambia un texto de Alfa en todos lados a la vez (1.4.1).

Uso:
  python -I tools/renombrar_texto.py "texto viejo" "texto nuevo" [--ver]
  python -I tools/renombrar_texto.py --lista cambios.json [--ver]   (lista de ["viejo", "nuevo"])

La clave de un texto ES su español: cambiar una palabra de un botón obliga a
tocar el código (L["..."] y ns.T("...")), su inglés (M.EN del Textos.lua de su
módulo o de motor/Alfa/Interfaz/Textos.lua) y su traducción en los 7 idiomas
(textos/<idioma>/*.json). Esto lo hace en un paso y conserva las traducciones:
la traducción del texto viejo pasa a ser la del nuevo. Si el texto nuevo ya
existía, se usa el suyo (no se pisa). Con --ver solo dice qué cambiaría.
Después: tools/textos.py generar (los Idiomas) y tools/textos.py estado.
Los finales de línea de cada archivo se respetan.
"""
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
IDIOMAS = ["deDE", "frFR", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]


def lua_str(s: str) -> str:
    """El texto como va entre comillas dobles en Lua."""
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def leer(p: pathlib.Path):
    b = p.read_bytes()
    t = b.decode("utf-8")
    return t, ("\r\n" if "\r\n" in t else "\n")


def escribir(p: pathlib.Path, t: str, nl: str):
    t = t.replace("\r\n", "\n")
    if nl == "\r\n":
        t = t.replace("\n", "\r\n")
    p.write_bytes(t.encode("utf-8"))


def archivos_lua():
    for base in (RAIZ / "src", RAIZ / "motor"):
        for p in base.rglob("*.lua"):
            if "Idiomas" in p.parts:
                continue
            yield p


def renombrar(viejo: str, nuevo: str, ver: bool) -> int:
    cambios = 0
    lv, ln = lua_str(viejo), lua_str(nuevo)
    # Código e inglés: L["viejo"], ns.T("viejo"), T("viejo"), M.EN["viejo"], ["viejo"] =
    patrones = [(f'["{lv}"]', f'["{ln}"]'), (f'T("{lv}")', f'T("{ln}")')]
    for p in archivos_lua():
        t, nl = leer(p)
        n = sum(t.count(a) for a, _ in patrones)
        if not n:
            continue
        # Si el nuevo ya tenía su inglés en ese archivo, la línea vieja se quita (no dos claves iguales).
        if f'["{ln}"] =' in t and f'["{lv}"] =' in t:
            t = re.sub(r'^[^\n]*\["' + re.escape(lv) + r'"\]\s*=[^\n]*\n', "", t, flags=re.M)
        for a, b in patrones:
            t = t.replace(a, b)
        cambios += n
        print(f"  {p.relative_to(RAIZ).as_posix()}: {n}")
        if not ver:
            escribir(p, t, nl)
    # Traducciones: la clave vieja pasa a la nueva (si la nueva no tenía ya la suya).
    for loc in IDIOMAS:
        for p in sorted((RAIZ / "textos" / loc).glob("*.json")):
            t, nl = leer(p)
            d = json.loads(t)
            if viejo not in d:
                continue
            ya = any(nuevo in json.loads(leer(q)[0]) for q in (RAIZ / "textos" / loc).glob("*.json"))
            valor = d.pop(viejo)
            if not ya:
                d[nuevo] = valor
            cambios += 1
            print(f"  {p.relative_to(RAIZ).as_posix()}: traducción {'(ya tenía la nueva)' if ya else 'pasada'}")
            if not ver:
                # La sangría que ya tenía el archivo (unos usan 1 espacio, otros 2).
                m = re.search(r"\n( +)\"", t)
                escribir(p, json.dumps(d, ensure_ascii=False, indent=len(m.group(1)) if m else 1) + "\n", nl)
    return cambios


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    args = [a for a in sys.argv[1:] if a != "--ver"]
    ver = "--ver" in sys.argv
    if args and args[0] == "--lista":
        pares = json.loads(pathlib.Path(args[1]).read_text(encoding="utf-8"))
    elif len(args) == 2:
        pares = [args]
    else:
        print(__doc__)
        return 1
    total = 0
    for viejo, nuevo in pares:
        if viejo == nuevo:
            continue
        print(f"«{viejo}» -> «{nuevo}»")
        n = renombrar(viejo, nuevo, ver)
        if not n:
            print("  (no aparece)")
        total += n
    print(f"{total} cambios{' (solo vista)' if ver else ''}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
