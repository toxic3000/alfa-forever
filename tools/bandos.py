"""Dibuja las texturas de la 1.3.9: el viaje y los dos bandos (toxic3000 / La Jauría).

Uso:  python -I tools/bandos.py [hoja.png]   ->  src/Alfa_Nucleo/Media/*.tga

Todo es dibujo propio (nada copiado del arte de Blizzard):
  viaje-barco, -zepelin, -tranvia, -portal, -grifo
      los transportes con el trazo de los iconos de Alfa (tools/iconos.py):
      blancos con transparencia, el juego los tiñe. 64 px.
  bando-horda       escudo redondo de hierro con canto de bronce, campo rojo y
                    dos hachas cruzadas con una lanza (128 px, a color)
  bando-alianza     escudo de punta con canto de oro, campo azul, una estrella
                    de cuatro puntas y una corona sencilla (128 px, a color)
  adorno-horda      tira de madera con bandas de hierro y remaches (256x32)
  adorno-alianza    tira de piedra en bloques con filo de plata (256x32)
  esquina-horda     escuadra de hierro con remache (64 px)
  esquina-alianza   esquina de plata con una voluta (64 px)
Se dibuja a 8x (4x las grandes) y se reduce: bordes suaves. TGA de 32 bits.
"""
import math
import pathlib
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import iconos  # noqa: E402  (el mismo lápiz y el mismo trazo que los iconos de Alfa)

SALIDA = pathlib.Path(__file__).resolve().parent.parent / "src" / "Alfa_Nucleo" / "Media"
NADA = (0, 0, 0, 0)


# ---------------------------------------------------------------------------
# Los transportes (rejilla de 32 unidades, trazo de Alfa)
# ---------------------------------------------------------------------------

def v_barco(l):
    # El casco, el mástil, la vela y dos olas.
    l.linea((4, 19), (28, 19), (24, 25), (8, 25), cerrada=True)
    l.linea((16, 4), (16, 19))
    l.lleno((17.5, 5), (26, 16), (17.5, 16))
    l.lleno((14.5, 8), (14.5, 16), (8, 16))
    l.arco(8, 30, 3, 200, 340, w=2)
    l.arco(16, 30, 3, 200, 340, w=2)
    l.arco(24, 30, 3, 200, 340, w=2)


def v_zepelin(l):
    # El globo, sus costillas, las aletas y la barquilla.
    l.ovalo(4, 5, 26, 17)
    l.linea((9, 11), (21, 11), w=1.6)
    l.linea((26, 9), (30, 6), (30, 16), (26, 13), w=2)
    l.linea((12, 17), (13, 21))
    l.linea((18, 17), (17, 21))
    l.caja(10, 21, 20, 26, corte=2, w=2)


def v_tranvia(l):
    # El vagón con sus ventanas, las ruedas y el riel.
    l.caja(5, 5, 27, 22, corte=4)
    l.caja(8.5, 9, 14.5, 14, corte=1.5, w=1.8)
    l.caja(17.5, 9, 23.5, 14, corte=1.5, w=1.8)
    l.punto(11, 25, 2.2)
    l.punto(21, 25, 2.2)
    l.linea((3, 29), (29, 29), w=2)


def v_portal(l):
    # Un arco de piedra y el remolino adentro.
    l.linea((7, 29), (7, 13))
    l.linea((25, 29), (25, 13))
    l.arco(16, 13, 9, 180, 360)
    l.arco(16, 17, 5.5, 200, 520 - 40, w=2)
    l.arco(16, 17, 2.2, 0, 300, w=1.8)
    l.linea((4, 29), (28, 29), w=2)


def v_grifo(l):
    # Una cabeza con pico de águila y un ala de tres plumas.
    l.aro(10, 11, 4.5)
    l.lleno((13, 9.5), (19, 12), (13.5, 13.5))
    l.punto(9.5, 10, 1.2)
    l.linea((8, 16), (10, 27), (16, 22))
    l.linea((14, 18), (29, 6))
    l.linea((15, 21), (30, 13))
    l.linea((16, 24), (28, 20))


TRANSPORTES = {"viaje-barco": v_barco, "viaje-zepelin": v_zepelin, "viaje-tranvia": v_tranvia,
               "viaje-portal": v_portal, "viaje-grifo": v_grifo}


def transporte(fn, tam=64):
    im = Image.new("RGBA", (iconos.LADO * iconos.F, iconos.LADO * iconos.F), NADA)
    fn(iconos.Lapiz(im))
    return im.resize((tam, tam), Image.LANCZOS)


# ---------------------------------------------------------------------------
# Los emblemas (128 px, dibujados a 4x)
# ---------------------------------------------------------------------------
E = 4
T = 128 * E


def P(x, y):
    return (x * E, y * E)


def sombra(im, radio=6, alfa=150):
    a = im.split()[3].filter(ImageFilter.GaussianBlur(radio * E))
    s = Image.new("RGBA", im.size, (0, 0, 0, 0))
    s.putalpha(a.point(lambda v: v * alfa // 255))
    fondo = Image.new("RGBA", im.size, NADA)
    fondo.alpha_composite(s, (0, 2 * E))
    fondo.alpha_composite(im)
    return fondo


def degradado_radial(tam, cx, cy, r, dentro, fuera, mascara):
    im = Image.new("RGBA", (tam, tam), NADA)
    px = im.load()
    m = mascara.load()
    for y in range(0, tam):
        for x in range(0, tam):
            if m[x, y]:
                t = min(1.0, math.hypot(x - cx, y - cy) / r)
                px[x, y] = tuple(int(dentro[i] + (fuera[i] - dentro[i]) * t) for i in range(3)) + (m[x, y],)
    return im


def bando_horda():
    im = Image.new("RGBA", (T, T), NADA)
    d = ImageDraw.Draw(im)
    cx = cy = 64
    # Púas de hierro alrededor (ocho), detrás del escudo.
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        pts = [P(cx + 50 * math.cos(a - 0.17), cy + 50 * math.sin(a - 0.17)),
               P(cx + 61 * math.cos(a), cy + 61 * math.sin(a)),
               P(cx + 50 * math.cos(a + 0.17), cy + 50 * math.sin(a + 0.17))]
        d.polygon(pts, fill=(70, 62, 58, 255))
    # El canto de bronce y el hierro.
    d.ellipse([P(10, 10), P(118, 118)], fill=(150, 96, 44, 255))
    d.ellipse([P(15, 15), P(113, 113)], fill=(54, 46, 42, 255))
    # El campo rojo, con luz arriba.
    masc = Image.new("L", (T, T), 0)
    ImageDraw.Draw(masc).ellipse([P(20, 20), P(108, 108)], fill=255)
    campo = degradado_radial(T, 64 * E, 48 * E, 60 * E, (196, 40, 30), (92, 12, 10), masc)
    im.alpha_composite(campo)
    d = ImageDraw.Draw(im)
    # Remaches de bronce en el hierro.
    for i in range(12):
        a = math.radians(i * 30)
        x, y = cx + 47.5 * math.cos(a), cy + 47.5 * math.sin(a)
        d.ellipse([P(x - 2, y - 2), P(x + 2, y + 2)], fill=(214, 156, 84, 255))
    bronce, bronce_os = (226, 160, 82, 255), (120, 70, 28, 255)
    # La lanza al centro.
    d.line([P(64, 34), P(64, 98)], fill=bronce_os, width=7 * E)
    d.line([P(64, 34), P(64, 98)], fill=bronce, width=4 * E)
    d.polygon([P(64, 24), P(71, 38), P(64, 35), P(57, 38)], fill=bronce)
    # Dos hachas cruzadas: el mango y una hoja en media luna.
    for lado in (-1, 1):
        x0, y0, x1, y1 = 64 - 26 * lado, 94, 64 + 22 * lado, 40
        d.line([P(x0, y0), P(x1, y1)], fill=bronce_os, width=6 * E)
        d.line([P(x0, y0), P(x1, y1)], fill=bronce, width=3 * E)
        hx, hy = 64 + 17 * lado, 46
        d.chord([P(hx - 13, hy - 13), P(hx + 13, hy + 13)], 90 + 90 * lado - 70, 90 + 90 * lado + 70, fill=bronce)
        d.chord([P(hx - 9, hy - 9), P(hx + 9, hy + 9)], 90 + 90 * lado - 60, 90 + 90 * lado + 60, fill=(180, 40, 30, 255))
    return sombra(im).resize((128, 128), Image.LANCZOS)


def bando_alianza():
    im = Image.new("RGBA", (T, T), NADA)
    d = ImageDraw.Draw(im)

    def escudo(m):
        pts = []
        top, ancho = 14 + m, 50 - m
        pts += [P(64 - ancho, top), P(64 + ancho, top)]
        for i in range(0, 21):
            t = i / 20
            x = 64 + ancho * (1 - t) ** 1.1
            y = top + 38 + (100 - top - 38 + 14 - m * 0.4) * t
            pts.append(P(x, y if i < 20 else 118 - m * 1.2))
        for i in range(20, -1, -1):
            t = i / 20
            x = 64 - ancho * (1 - t) ** 1.1
            y = top + 38 + (100 - top - 38 + 14 - m * 0.4) * t
            pts.append(P(x, y if i < 20 else 118 - m * 1.2))
        return pts

    d.polygon(escudo(0), fill=(232, 190, 80, 255))      # el canto de oro
    d.polygon(escudo(5), fill=(150, 156, 170, 255))     # el filo de plata
    masc = Image.new("L", (T, T), 0)
    ImageDraw.Draw(masc).polygon(escudo(9), fill=255)
    campo = degradado_radial(T, 64 * E, 40 * E, 80 * E, (52, 104, 200), (14, 34, 92), masc)
    im.alpha_composite(campo)
    d = ImageDraw.Draw(im)
    oro, oro_os = (246, 206, 96, 255), (150, 104, 24, 255)
    # La estrella de cuatro puntas (y una cruz fina detrás).
    cx, cy = 64, 66
    d.line([P(cx, 30), P(cx, 104)], fill=(200, 206, 220, 255), width=2 * E)
    d.line([P(28, cy), P(100, cy)], fill=(200, 206, 220, 255), width=2 * E)
    for r, c in ((26, oro_os), (23, oro)):
        k = r * 0.28
        d.polygon([P(cx, cy - r), P(cx + k, cy - k), P(cx + r, cy), P(cx + k, cy + k),
                   P(cx, cy + r), P(cx - k, cy + k), P(cx - r, cy), P(cx - k, cy - k)], fill=c)
    d.ellipse([P(cx - 4, cy - 4), P(cx + 4, cy + 4)], fill=(255, 244, 200, 255))
    # Una corona sencilla arriba del escudo.
    d.polygon([P(44, 13), P(48, 3), P(56, 9), P(64, 0), P(72, 9), P(80, 3), P(84, 13)], fill=oro)
    d.rectangle([P(44, 12), P(84, 16)], fill=oro_os)
    return sombra(im).resize((128, 128), Image.LANCZOS)


# ---------------------------------------------------------------------------
# Los adornos (tiras y esquinas, a color)
# ---------------------------------------------------------------------------

def adorno_horda():
    W, H, S = 256, 32, 4
    im = Image.new("RGBA", (W * S, H * S), NADA)
    d = ImageDraw.Draw(im)
    rnd = random.Random(1309)
    d.rectangle([0, 4 * S, W * S, 28 * S], fill=(92, 58, 34, 255))
    for _ in range(40):  # la veta de la madera
        y = rnd.uniform(6, 26) * S
        x = rnd.uniform(0, W) * S
        d.line([(x, y), (x + rnd.uniform(20, 70) * S, y + rnd.uniform(-1, 1) * S)], fill=(70, 42, 24, 255), width=S)
    for x in range(0, W, 64):  # tablas
        d.line([(x * S, 4 * S), (x * S, 28 * S)], fill=(50, 30, 16, 255), width=S)
    for x in (24, 152):  # bandas de hierro con remaches
        d.rectangle([x * S, 2 * S, (x + 16) * S, 30 * S], fill=(64, 60, 58, 255))
        d.rectangle([x * S, 2 * S, (x + 16) * S, 4 * S], fill=(120, 112, 104, 255))
        for y in (9, 23):
            d.ellipse([(x + 5) * S, (y - 3) * S, (x + 11) * S, (y + 3) * S], fill=(176, 120, 64, 255))
    d.line([(0, 4 * S), (W * S, 4 * S)], fill=(150, 96, 44, 255), width=S)
    d.line([(0, 28 * S), (W * S, 28 * S)], fill=(40, 24, 12, 255), width=S)
    return im.resize((W, H), Image.LANCZOS)


def adorno_alianza():
    W, H, S = 256, 32, 4
    im = Image.new("RGBA", (W * S, H * S), NADA)
    d = ImageDraw.Draw(im)
    rnd = random.Random(1310)
    d.rectangle([0, 4 * S, W * S, 28 * S], fill=(118, 122, 130, 255))
    for fila, y0 in enumerate((4, 16)):  # bloques de piedra
        off = 0 if fila == 0 else 22
        for x in range(-off, W, 44):
            tono = rnd.randint(-14, 14)
            d.rectangle([(x + 1) * S, (y0 + 1) * S, (x + 43) * S, (y0 + 11) * S],
                        fill=(128 + tono, 132 + tono, 142 + tono, 255))
    d.rectangle([0, 2 * S, W * S, 5 * S], fill=(212, 218, 230, 255))  # filo de plata
    d.rectangle([0, 27 * S, W * S, 30 * S], fill=(176, 182, 196, 255))
    for x in range(16, W, 48):  # clavos de oro en el filo
        d.ellipse([(x - 2) * S, 1.5 * S, (x + 2) * S, 5.5 * S], fill=(240, 200, 90, 255))
    return im.resize((W, H), Image.LANCZOS)


def esquina_horda():
    S, N = 8, 64
    im = Image.new("RGBA", (N * S, N * S), NADA)
    d = ImageDraw.Draw(im)
    d.polygon([(0, 0), (N * S, 0), (N * S, 12 * S), (12 * S, 12 * S), (12 * S, N * S), (0, N * S)], fill=(64, 60, 58, 255))
    d.polygon([(0, 0), (N * S, 0), (N * S, 3 * S), (3 * S, 3 * S), (3 * S, N * S), (0, N * S)], fill=(130, 120, 112, 255))
    d.polygon([(N * S, 0), (N * S, 12 * S), (N * S - 10 * S, 6 * S)], fill=NADA)  # puntas
    d.polygon([(0, N * S), (12 * S, N * S), (6 * S, N * S - 10 * S)], fill=NADA)
    d.ellipse([3 * S, 3 * S, 11 * S, 11 * S], fill=(186, 126, 66, 255))
    d.ellipse([28 * S, 3 * S, 34 * S, 9 * S], fill=(186, 126, 66, 255))
    d.ellipse([3 * S, 28 * S, 9 * S, 34 * S], fill=(186, 126, 66, 255))
    return im.resize((N, N), Image.LANCZOS)


def esquina_alianza():
    S, N = 8, 64
    im = Image.new("RGBA", (N * S, N * S), NADA)
    d = ImageDraw.Draw(im)
    plata, oro = (214, 220, 232, 255), (240, 200, 90, 255)
    d.line([(2 * S, N * S), (2 * S, 2 * S), (N * S, 2 * S)], fill=plata, width=3 * S)
    d.line([(7 * S, 40 * S), (7 * S, 7 * S), (40 * S, 7 * S)], fill=(150, 156, 170, 255), width=2 * S)
    d.arc([7 * S, 7 * S, 27 * S, 27 * S], 180, 270, fill=plata, width=2 * S)
    d.arc([10 * S, 10 * S, 22 * S, 22 * S], 90, 360, fill=oro, width=2 * S)
    d.ellipse([13 * S, 13 * S, 19 * S, 19 * S], fill=oro)
    return im.resize((N, N), Image.LANCZOS)


def todo():
    out = {n: transporte(fn) for n, fn in TRANSPORTES.items()}
    out["bando-horda"] = bando_horda()
    out["bando-alianza"] = bando_alianza()
    out["adorno-horda"] = adorno_horda()
    out["adorno-alianza"] = adorno_alianza()
    out["esquina-horda"] = esquina_horda()
    out["esquina-alianza"] = esquina_alianza()
    return out


def main():
    SALIDA.mkdir(parents=True, exist_ok=True)
    imgs = todo()
    for n, im in imgs.items():
        im.save(SALIDA / f"{n}.tga")
    # Una hoja para revisar: los transportes teñidos sobre el fondo de Alfa.
    hoja = Image.new("RGBA", (720, 330), (16, 20, 18, 255))
    x = 10
    for n in TRANSPORTES:
        t = imgs[n]
        r, g, b, a = t.split()
        verde = Image.merge("RGBA", (r.point(lambda v: v * 139 // 255), g.point(lambda v: v * 224 // 255), b.point(lambda v: v * 78 // 255), a))
        hoja.alpha_composite(verde, (x, 10))
        x += 74
    hoja.alpha_composite(imgs["bando-horda"], (10, 90))
    hoja.alpha_composite(imgs["bando-alianza"], (150, 90))
    hoja.alpha_composite(imgs["adorno-horda"], (290, 100))
    hoja.alpha_composite(imgs["adorno-alianza"], (290, 150))
    hoja.alpha_composite(imgs["esquina-horda"], (290, 200))
    hoja.alpha_composite(imgs["esquina-alianza"], (370, 200))
    print("OK", SALIDA)
    return hoja


if __name__ == "__main__":
    h = main()
    if len(sys.argv) > 1:
        h.save(sys.argv[1])
