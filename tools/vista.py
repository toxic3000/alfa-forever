"""Dibuja las texturas de Alfa_Vista (filtros del paisaje).

Uso:  .venv/Scripts/python -I tools/vista.py  ->  src/Alfa_Vista/Media/*.tga

  vineta.tga        512x512  negro con alfa que crece hacia las orillas
  grano.tga         256x256  motas claras y oscuras (alfa = fuerza), se repite sin costura
  estrella.tga       32x32   estrella blanca (se tiñe en el juego)
  tinte-<id>.tga    128x64   miniatura de un paisaje con cada tinte aplicado

TGA de 32 bits sin compresión, como las demás texturas de Alfa.
Los tintes usan la misma cuenta que el juego (Filtros.lua): multiplicar por
un color y, en algunos, mezclar un velo encima.
"""
import math
import pathlib
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

SALIDA = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent / "src" / "Alfa_Vista" / "Media"

# Los mismos números que M.TINTES en Filtros.lua: (multiplicar), (velo r, g, b, alfa)
TINTES = {
    "ninguno": ((1.0, 1.0, 1.0), None),
    "sepia": ((1.0, 0.86, 0.66), (0.44, 0.31, 0.18, 0.22)),
    "calido": ((1.0, 0.9, 0.76), None),
    "frio": ((0.8, 0.9, 1.0), None),
    "noche": ((0.5, 0.58, 0.82), None),
    "esmeralda": ((0.72, 1.0, 0.56), None),
    "atardecer": ((1.0, 0.78, 0.62), (0.9, 0.35, 0.25, 0.12)),
}


def guardar(im, nombre):
    SALIDA.mkdir(parents=True, exist_ok=True)
    im.convert("RGBA").save(SALIDA / nombre, compression=None)


def vineta():
    T = 512
    im = Image.new("RGBA", (T, T))
    px = im.load()
    c = (T - 1) / 2
    for y in range(T):
        for x in range(T):
            r = math.hypot((x - c) / c, (y - c) / c)  # 0 centro, ~1.41 esquinas
            t = max(0.0, min(1.0, (r - 0.42) / 0.95))
            a = t * t * (3 - 2 * t)  # suave
            px[x, y] = (0, 0, 0, int(round(255 * a)))
    guardar(im, "vineta.tga")


def grano():
    T = 256
    rnd = random.Random(3000)  # siempre el mismo grano
    ruido = Image.new("L", (T, T))
    ruido.putdata([max(0, min(255, int(rnd.gauss(128, 46)))) for _ in range(T * T)])
    # un poco de suavizado (grano de película, no estática de TV), con vuelta
    # a la orilla para que se repita sin costura
    grande = Image.new("L", (T * 3, T * 3))
    for i in range(3):
        for j in range(3):
            grande.paste(ruido, (i * T, j * T))
    grande = grande.filter(ImageFilter.GaussianBlur(0.6)).crop((T, T, 2 * T, 2 * T))
    im = Image.new("RGBA", (T, T))
    px, src = im.load(), grande.load()
    for y in range(T):
        for x in range(T):
            n = (src[x, y] - 128) / 128.0  # -1..1
            v = 255 if n > 0 else 0
            px[x, y] = (v, v, v, int(min(255, abs(n) * 255 * 1.6)))
    guardar(im, "grano.tga")


def estrella():
    E = 8
    T = 32 * E
    im = Image.new("L", (T, T), 0)
    c, R, r = T / 2, T * 0.47, T * 0.2
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rad = R if i % 2 == 0 else r
        pts.append((c + rad * math.cos(ang), c + 0.04 * T + rad * math.sin(ang)))
    ImageDraw.Draw(im).polygon(pts, fill=255)
    a = im.resize((32, 32), Image.LANCZOS)
    out = Image.new("RGBA", (32, 32), (255, 255, 255, 0))
    out.putalpha(a)
    guardar(out, "estrella.tga")


def paisaje():
    """Un paisaje chico propio: cielo, sol, montes, pasto y dos árboles."""
    W, H, E = 128, 64, 4
    im = Image.new("RGB", (W * E, H * E))
    d = ImageDraw.Draw(im)
    for y in range(H * E):  # cielo
        t = y / (H * E * 0.62)
        t = min(1.0, t)
        col = tuple(int(a + (b - a) * t) for a, b in zip((70, 120, 190), (235, 190, 140)))
        d.line([(0, y), (W * E, y)], fill=col)
    d.ellipse([86 * E, 10 * E, 102 * E, 26 * E], fill=(255, 236, 170))
    d.polygon([(0, 44 * E), (30 * E, 26 * E), (58 * E, 40 * E), (84 * E, 22 * E), (128 * E, 42 * E), (128 * E, 64 * E), (0, 64 * E)], fill=(92, 110, 120))
    d.polygon([(0, 50 * E), (40 * E, 38 * E), (80 * E, 48 * E), (128 * E, 40 * E), (128 * E, 64 * E), (0, 64 * E)], fill=(70, 120, 60))
    d.rectangle([0, 54 * E, W * E, H * E], fill=(52, 96, 44))
    for x0 in (18, 104):
        d.rectangle([(x0 + 3) * E, 44 * E, (x0 + 5) * E, 56 * E], fill=(70, 48, 30))
        d.polygon([(x0 - 4) * E, 48 * E, (x0 + 4) * E, 28 * E, (x0 + 12) * E, 48 * E], fill=(34, 74, 40))
    return im.resize((W, H), Image.LANCZOS)


def tintes():
    base = paisaje()
    for nombre, (mul, velo) in TINTES.items():
        im = base.copy()
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b = px[x, y]
                r, g, b = r * mul[0], g * mul[1], b * mul[2]
                if velo:
                    vr, vg, vb, va = velo
                    r = r * (1 - va) + vr * 255 * va
                    g = g * (1 - va) + vg * 255 * va
                    b = b * (1 - va) + vb * 255 * va
                px[x, y] = (int(r), int(g), int(b))
        guardar(im, f"tinte-{nombre}.tga")


if __name__ == "__main__":
    vineta()
    grano()
    estrella()
    tintes()
    for p in sorted(SALIDA.glob("*.tga")):
        im = Image.open(p)
        print(p.name, im.size, im.mode)
