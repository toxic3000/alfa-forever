"""Prueba visual de Alfa (1.3.9): compara cada página con la versión anterior.

Uso (después de tools/build.py; ALFA_DIST elige otra carpeta de build):
  python -I tools/regresion.py             compara y avisa lo que cambió
  python -I tools/regresion.py --aceptar   lo de ahora pasa a ser la referencia
  python -I tools/regresion.py --estricto  termina con 1 si algo cambió

Corre tools/banco/vistas.lua (cada página de Alfa y algunas ventanas, siempre
en el mismo estado) y compara lo que se dibuja, pieza por pieza (texto,
textura, lugar y tamaño), con tools/banco/referencia/vistas.json.gz. Por cada
captura que cambió dice cuántas piezas son nuevas, cuántas ya no están y
cuántas se movieron, y deja una imagen con las dos versiones lado a lado
(tools/banco/shot-dif-<captura>.png: a la izquierda la de antes, a la derecha
la de ahora, con lo distinto en rojo) para revisarla con calma.

Un cambio no es un error: si se quiso, se acepta con --aceptar al cerrar la
versión. Lo que sí es error: una página que ya no abre o un error de Lua.
"""
import collections
import gzip
import json
import os
import pathlib
import re
import sys
import tempfile

RAIZ = pathlib.Path(__file__).resolve().parent.parent
BANCO = RAIZ / "tools" / "banco"
REFERENCIA = BANCO / "referencia" / "vistas.json.gz"
sys.path.insert(0, str(RAIZ / "tools"))
sys.path.insert(0, str(BANCO))
import prueba  # noqa: E402


def version() -> str:
    try:
        return json.loads((RAIZ / "tools" / "alfa.json").read_text(encoding="utf-8")).get("version", "?")
    except (OSError, ValueError):
        return "?"


def capturar():
    """-> ({captura: {rect, entries}}, salida del banco)."""
    carpeta = pathlib.Path(tempfile.mkdtemp(prefix="alfa_vistas_"))
    try:
        salida, cortado = prueba.correr("vistas.lua", {"BANCO_CAPTURAS": str(carpeta), "BANCO_VOLCAR": "1"})
        if cortado:
            salida.append("PRUEBA CORTADA: vistas.lua " + cortado)
        capturas = {}
        for p in sorted(carpeta.glob("shot-*.json")):
            capturas[p.stem[len("shot-"):]] = json.loads(p.read_text(encoding="utf-8"))
        return capturas, salida
    finally:
        for p in carpeta.glob("*"):
            p.unlink()
        carpeta.rmdir()


def _texto(t) -> str:
    # Los números cambian solos (la hora, el oro, los días): no cuentan.
    t = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", str(t or ""))
    return re.sub(r"\d+", "#", t).strip()


def piezas(cap) -> list:
    """Lo que se ve de una captura: (tipo, contenido, l, b, w, h)."""
    out = []
    for e in cap.get("entries", []):
        if float(e.get("alpha") or 1) <= 0.01:
            continue
        kind = e.get("kind") or "?"
        if kind == "FontString":
            contenido = _texto(e.get("text"))
            if not contenido:
                continue
        elif kind == "Texture":
            contenido = re.split(r"[\\/]", str(e.get("tex") or ""))[-1].lower()
        else:
            contenido = ""
        r = lambda k: int(round(float(e.get(k) or 0) / 2)) * 2  # noqa: E731  (2 px de holgura)
        out.append((kind, contenido, r("l"), r("b"), r("w"), r("h")))
    return out


def comparar(antes, ahora):
    a, b = collections.Counter(piezas(antes)), collections.Counter(piezas(ahora))
    fuera, nuevas = a - b, b - a
    # Las que solo cambiaron de lugar o de tamaño (mismo tipo y contenido).
    porContenido = collections.Counter((p[0], p[1]) for p in fuera.elements())
    movidas = 0
    for p in list(nuevas.elements()):
        k = (p[0], p[1])
        if porContenido[k] > 0:
            porContenido[k] -= 1
            movidas += 1
    n_fuera = sum(fuera.values()) - movidas
    n_nuevas = sum(nuevas.values()) - movidas
    textos = sorted({p[1] for p in nuevas.elements() if p[0] == "FontString"} - {p[1] for p in fuera.elements() if p[0] == "FontString"})
    return n_nuevas, n_fuera, movidas, textos, list(nuevas.elements()), list(fuera.elements())


def imagen_dif(nombre, antes, ahora, nuevas, fuera):
    """Las dos versiones lado a lado, lo distinto en rojo."""
    try:
        import render
        from PIL import Image, ImageDraw
    except ImportError:
        return None
    fonts = prueba.DIST / "Alfa" / "Media" / "Fonts"
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="alfa_dif_"))
    try:
        imgs = []
        for lado, cap, marcas in (("antes", antes, fuera), ("ahora", ahora, nuevas)):
            p = tmp / (lado + ".png")
            render.render(cap["entries"], tuple(cap["rect"]), p, fonts)
            img = Image.open(p).convert("RGB")
            l0, b0, w0, h0 = cap["rect"]
            sx, sy = img.width / max(1, w0), img.height / max(1, h0)
            d = ImageDraw.Draw(img)
            for m in marcas:
                _, _, l, b, w, h = m
                x0, y1 = (l - l0) * sx, img.height - (b - b0) * sy
                d.rectangle([x0, y1 - h * sy, x0 + w * sx, y1], outline=(235, 60, 60), width=2)
            imgs.append(img)
        render.CORTES.clear()
        render.SALEN.clear()
        alto = max(i.height for i in imgs)
        hoja = Image.new("RGB", (imgs[0].width + imgs[1].width + 12, alto), (20, 20, 24))
        hoja.paste(imgs[0], (0, 0))
        hoja.paste(imgs[1], (imgs[0].width + 12, 0))
        destino = BANCO / ("shot-dif-%s.png" % nombre)
        hoja.save(destino)
        return destino
    finally:
        for p in tmp.glob("*"):
            p.unlink()
        tmp.rmdir()


def leer_referencia():
    if not REFERENCIA.exists():
        return None
    with gzip.open(REFERENCIA, "rt", encoding="utf-8") as f:
        return json.load(f)


def guardar_referencia(capturas):
    REFERENCIA.parent.mkdir(parents=True, exist_ok=True)
    datos = {"version": version(), "capturas": capturas}
    with gzip.open(REFERENCIA, "wt", encoding="utf-8", compresslevel=9) as f:
        json.dump(datos, f, separators=(",", ":"))


def revisar(aceptar=False) -> tuple:
    """-> (errores, cambios). Imprime lo que encuentra."""
    capturas, salida = capturar()
    errores = 0
    for l in salida:
        if l.startswith(("ERROR", "FALLA EN", "PRUEBA CORTADA", "AVISO VISUAL")):
            print(l)
            if not l.startswith("AVISO"):
                errores += 1
    if not capturas:
        print("VISUAL: el banco no dio capturas")
        return errores + 1, 0
    ref = leer_referencia()
    if aceptar or ref is None:
        guardar_referencia(capturas)
        print("VISUAL: %d capturas guardadas como referencia (%s)%s" % (
            len(capturas), version(), "" if aceptar else ": no había una anterior"))
        return errores, 0
    antes = ref.get("capturas", {})
    cambios = 0
    for nombre in sorted(set(antes) | set(capturas)):
        if nombre not in capturas:
            print("AVISO VISUAL: %s ya no se capturó" % nombre)
            cambios += 1
            continue
        if nombre not in antes:
            print("AVISO VISUAL: %s es nueva (no estaba en la %s)" % (nombre, ref.get("version", "?")))
            cambios += 1
            continue
        n, f, m, textos, nuevas, fuera = comparar(antes[nombre], capturas[nombre])
        if n or f or m:
            cambios += 1
            img = imagen_dif(nombre, antes[nombre], capturas[nombre], nuevas, fuera)
            print("AVISO VISUAL: %s cambió desde la %s: %d piezas nuevas, %d ya no están, %d se movieron%s" % (
                nombre, ref.get("version", "?"), n, f, m, (" -> " + str(img)) if img else ""))
            for t in textos[:4]:
                print("      texto nuevo: %s" % t[:90])
    print("VISUAL: %d capturas, %d cambiaron desde la %s" % (len(capturas), cambios, ref.get("version", "?")))
    return errores, cambios


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    if not (prueba.DIST / "Alfa").is_dir():
        print("Falta %s: corre tools/build.py" % prueba.DIST)
        return 1
    errores, cambios = revisar(aceptar="--aceptar" in sys.argv)
    if errores:
        return 1
    return 1 if (cambios and "--estricto" in sys.argv) else 0


if __name__ == "__main__":
    sys.exit(main())
