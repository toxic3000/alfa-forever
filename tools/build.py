"""Construye Alfa: Polestar renombrado + parches de Alfa + modulos propios.

Uso:  python -I tools/build.py            (deja todo en dist/)

1. Toma upstream/polestar-<version>/ (bajado con tools/fetch_upstream.py).
2. Cambia Polestar por Alfa en codigo y textos (tools/renombrar.py), sin tocar
   comentarios ni avisos de licencia, y renombra carpetas y archivos.
3. Aplica los parches de tools/parches.py (cada uno debe encajar exactamente;
   si Polestar cambio ese codigo, la construccion se detiene y lo dice).
4. Copia los modulos propios de src/ (Alfa_*).
5. Escribe dist/NOTICE-ALFA.txt con la procedencia.
"""
import json
import os
import pathlib
import re
import shutil
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import parches  # noqa: E402
import renombrar  # noqa: E402

RAIZ = pathlib.Path(__file__).resolve().parent.parent
TEXTO = {".lua": renombrar.cambiar_lua, ".xml": renombrar.cambiar_xml,
         ".toc": renombrar.cambiar_toc}
SALTO = chr(10)
RETORNO = chr(13)


# latin-1 conserva cada byte tal cual (hay datos empacados que no son UTF-8);
# los cambios de nombre son ASCII, asi que no se rompe ningun texto UTF-8.
def leer(p: pathlib.Path) -> str:
    return p.read_bytes().decode("latin-1")


def escribir(p: pathlib.Path, s: str) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(s.encode("latin-1"))


def lineas_de(texto: str) -> list:
    """Parte en lineas solo por el salto de linea: splitlines() tambien corta
    en bytes como 0x85, que aparecen dentro de letras UTF-8 leidas como latin-1."""
    return texto.replace(RETORNO + SALTO, SALTO).rstrip(SALTO).split(SALTO)


def ajustar_toc(src: str, cfg: dict, principal: bool) -> str:
    """Pone la version de Alfa en todas las partes y la identidad en la principal."""
    campos = dict(cfg["toc"]) if principal else {}
    campos["Version"] = cfg["version"]
    # el TOC se leyo como latin-1: los textos nuevos (con acentos) entran como
    # sus bytes UTF-8 para que el archivo final siga siendo UTF-8 valido
    campos = {k: v.encode("utf-8").decode("latin-1") for k, v in campos.items()}
    vistos = set()
    out = []
    for linea in lineas_de(src):
        m = re.match(r"^##\s*([A-Za-z0-9_-]+)\s*:", linea)
        if m and m.group(1) in campos:
            clave = m.group(1)
            out.append(f"## {clave}: {campos[clave]}")
            vistos.add(clave)
            continue
        if principal and m and (m.group(1).startswith("Title-") or m.group(1).startswith("Notes-")):
            if m.group(1) not in campos:
                continue  # los titulos y notas por idioma de Polestar se quitan
        out.append(linea)
    faltan = [f"## {k}: {v}" for k, v in campos.items() if k not in vistos]
    if faltan:
        pos = max(i for i, l in enumerate(out) if l.startswith("##")) + 1
        out[pos:pos] = faltan
    return SALTO.join(out) + SALTO


def main() -> int:
    cfg = json.loads((RAIZ / "tools" / "alfa.json").read_text(encoding="utf-8"))
    base = RAIZ / "upstream" / f"polestar-{cfg['upstream']}"
    if not base.is_dir():
        print(f"Falta {base}: corre tools/fetch_upstream.py {cfg['upstream']}")
        return 1
    dist = pathlib.Path(os.environ.get("ALFA_DIST") or RAIZ / "dist")
    if dist.exists():
        shutil.rmtree(dist)

    archivos = 0
    for origen in sorted(base.rglob("*")):
        if origen.is_dir():
            continue
        rel = origen.relative_to(base)
        rel_nuevo = pathlib.Path(*[renombrar.cambiar(p) for p in rel.parts])
        destino = dist / rel_nuevo
        fn = TEXTO.get(origen.suffix.lower())
        if fn:
            texto = fn(leer(origen))
            if origen.suffix.lower() == ".toc":
                principal = rel_nuevo.parts[0] == "Alfa"
                texto = ajustar_toc(texto, cfg, principal)
            escribir(destino, texto)
        else:
            destino.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(origen, destino)
        archivos += 1

    # La marca de Alfa (tools/marca.py) reemplaza imagenes del motor.
    marca = RAIZ / "marca"
    if marca.is_dir():
        for origen in marca.rglob("*"):
            if origen.is_file():
                destino = dist / origen.relative_to(marca)
                if not destino.exists():
                    print(f"AVISO: marca/{origen.relative_to(marca)} no reemplaza nada del motor")
                destino.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(origen, destino)

    errores = parches.aplicar(dist, cfg)
    if errores:
        print("PARCHES QUE NO ENCAJARON (Polestar cambio ese codigo):")
        for e in errores:
            print("  -", e)
        return 1

    propios = 0
    src = RAIZ / "src"
    if src.is_dir():
        for carpeta in sorted(p for p in src.iterdir() if p.is_dir()):
            shutil.copytree(carpeta, dist / carpeta.name)
            for toc in (dist / carpeta.name).glob("*.toc"):
                escribir(toc, ajustar_toc(leer(toc), cfg, False))  # version unica
            propios += 1

    # Archivos de terceros que usan los modulos (vendor/<Modulo>/...), con su
    # licencia al lado: por ejemplo, las texturas de OpenMap (MIT) de Mundo.
    vendor = RAIZ / "vendor"
    if vendor.is_dir():
        for origen in vendor.rglob("*"):
            if origen.is_file():
                destino = dist / origen.relative_to(vendor)
                if not destino.parts[len(dist.parts)] in {p.name for p in dist.iterdir()}:
                    print(f"AVISO: vendor/{origen.relative_to(vendor)} no tiene modulo en dist/")
                destino.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(origen, destino)

    (dist / "NOTICE-ALFA.txt").write_text(
        f"Alfa {cfg['version']} - Toxic / La Jauria\n\n"
        f"Alfa es software libre bajo la GNU GPL version 3 (ver Alfa/LICENSE).\n"
        f"Esta basado en Polestar {cfg['upstream']} de The Polestar authors\n"
        f"({cfg['urls']['repo']}), GPL-3.0, que a su vez incluye trabajo de\n"
        f"Shortest Path Forever de Cillian Berragan (GPL-3.0-or-later) y datos de\n"
        f"pfQuest (MIT) y otras fuentes listadas en cada LICENSE-DATA.txt.\n"
        f"Los avisos de copyright originales se conservan sin cambios.\n",
        encoding="utf-8")

    if not cfg["urls"].get("discord"):
        print("AVISO: falta el enlace de Discord de La Jauria en tools/alfa.json")
    print(f"OK dist/: {archivos} archivos de Polestar convertidos, "
          f"{len(parches.PARCHES)} parches, {propios} modulos propios")
    return 0


if __name__ == "__main__":
    sys.exit(main())
