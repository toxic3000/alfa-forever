"""Dibuja las texturas de los anuncios de la 1.4.0 (toxic3000 / La Jauría).

Uso:  python -I tools/anuncios.py [hoja.png]   ->  src/Alfa_Nucleo/Media/anuncio-*.tga

Pedido de Toxic (1.4.0, n.º 77): «quiero ver una mejora bastante clara en
todos los anuncios». La identidad nueva es una franja de cine: una niebla oscura
difuminada (una sola forma, sin bordes) que se abre como telón, dos líneas de luz del color del tipo arriba y abajo,
y un medallón sobre el borde de arriba con el dibujo del tipo. Todo es dibujo
propio (nada del arte de Blizzard), blanco con transparencia: el juego lo tiñe.

  anuncio-niebla   una elipse difuminada en todos los bordes: el fondo «Suave» (512x256)
  anuncio-disco    el fondo del medallón (128)
  anuncio-aro      el aro del medallón, doble (128)
  anuncio-luz      el destello que cruza el nombre (256x32)
  anuncio-<tipo>   el dibujo de cada tipo (128): zona, rincon, descubrir, ciudad,
                   mazmorra, banda, peligro, barco, zepelin, tranvia, raro,
                   tesoro, manada, nivel
Se dibuja a 4x y se reduce: bordes suaves. TGA de 32 bits.
"""
import math
import random
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter

SALIDA = pathlib.Path(__file__).resolve().parent.parent / "src" / "Alfa_Nucleo" / "Media"
NADA = (0, 0, 0, 0)
B = (255, 255, 255, 255)
SS = 4


def suave(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def niebla():
    """1.4.0 (pedido de Toxic: «no se ve parejo, se distinguen las capas»): una
    sola forma, una elipse difuminada en todos sus bordes, sin escalones ni
    rectángulos. Se estira a lo que mida el anuncio y sigue siendo elipse."""
    w, h = 512, 256
    im = Image.new("RGBA", (w, h), NADA)
    px = im.load()
    for x in range(w):
        dx = (x + 0.5) / w * 2 - 1
        for y in range(h):
            dy = (y + 0.5) / h * 2 - 1
            r = math.sqrt(dx * dx + dy * dy)
            a = (1 - suave((r - 0.38) / 0.62)) ** 1.35 if r < 1 else 0
            px[x, y] = (255, 255, 255, int(255 * a + 0.5))
    return im


def lienzo(n=128):
    im = Image.new("RGBA", (n * SS, n * SS), NADA)
    return im, ImageDraw.Draw(im), n * SS


def reducir(im, n=128):
    return im.resize((n, n), Image.LANCZOS)


def disco():
    im, d, s = lienzo()
    m = 4 * SS
    d.ellipse([m, m, s - m, s - m], fill=B)
    return reducir(im)


def aro():
    im, d, s = lienzo()
    m = 4 * SS
    d.ellipse([m, m, s - m, s - m], outline=B, width=6 * SS)
    m2 = 15 * SS
    d.ellipse([m2, m2, s - m2, s - m2], outline=(255, 255, 255, 110), width=2 * SS)
    # Cuatro muescas (norte, sur, este y oeste): un sello, no un círculo simple.
    c = s / 2
    for ang in (0, 90, 180, 270):
        a = math.radians(ang)
        r1, r2 = c - m - 2 * SS, c - m + 7 * SS
        x1, y1 = c + math.cos(a) * r1, c + math.sin(a) * r1
        x2, y2 = c + math.cos(a) * r2, c + math.sin(a) * r2
        d.line([(x1, y1), (x2, y2)], fill=B, width=5 * SS)
    return reducir(im)


def luz():
    w, h = 256, 32
    im = Image.new("RGBA", (w, h), NADA)
    px = im.load()
    for x in range(w):
        u = abs(x / (w - 1) - 0.5) * 2
        ax = (1 - u) ** 2.2
        for y in range(h):
            v = abs(y / (h - 1) - 0.5) * 2
            ay = math.exp(-(v * v) / 0.08)
            px[x, y] = (255, 255, 255, int(255 * ax * ay))
    return im


# ---------------------------------------------------------------------------
# Los dibujos (rejilla de 128 unidades; se dibujan a 4x)
# ---------------------------------------------------------------------------
def P(pts):
    return [(x * SS, y * SS) for x, y in pts]


def g_zona(d):
    d.polygon(P([(6, 110), (44, 34), (62, 66), (84, 16), (122, 110)]), fill=B)
    d.polygon(P([(84, 16), (96, 42), (88, 38), (80, 48), (73, 40)]), fill=NADA)
    d.polygon(P([(44, 34), (54, 54), (45, 50), (37, 58)]), fill=NADA)


def g_rincon(d):
    d.ellipse(P([(34, 14), (94, 74)]), fill=B)
    d.polygon(P([(38, 56), (90, 56), (64, 114)]), fill=B)
    d.ellipse(P([(52, 32), (76, 56)]), fill=NADA)


def g_descubrir(d):
    c = 64
    d.ellipse(P([(14, 14), (114, 114)]), outline=B, width=7 * SS)
    pts = []
    for i in range(8):
        a = math.radians(i * 45 - 90)
        r = 46 if i % 2 == 0 else 13
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    d.polygon(P(pts), fill=B)


def g_ciudad(d):
    d.polygon(P([(14, 62), (64, 18), (114, 62), (104, 62), (64, 28), (24, 62)]), fill=B)
    d.rectangle(P([(26, 60), (102, 112)]), fill=B)
    d.rectangle(P([(82, 22), (94, 46)]), fill=B)
    d.rectangle(P([(54, 78), (74, 112)]), fill=NADA)
    d.rectangle(P([(34, 70), (46, 82)]), fill=NADA)
    d.rectangle(P([(82, 70), (94, 82)]), fill=NADA)


def g_mazmorra(d):
    d.rectangle(P([(16, 30), (112, 112)]), fill=B)
    d.pieslice(P([(16, 6), (112, 102)]), 180, 360, fill=B)
    d.rectangle(P([(38, 56), (90, 112)]), fill=NADA)
    d.pieslice(P([(38, 30), (90, 82)]), 180, 360, fill=NADA)
    for i, y in enumerate((96, 104)):
        d.rectangle(P([(44 + i * 6, y), (84 - i * 6, y + 4)]), fill=B)


def g_banda(d):
    d.polygon(P([(14, 98), (20, 36), (44, 64), (64, 24), (84, 64), (108, 36), (114, 98)]), fill=B)
    d.rectangle(P([(14, 102), (114, 114)]), fill=B)
    for x in (20, 64, 108):
        d.ellipse(P([(x - 7, 16 if x == 64 else 28), (x + 7, 30 if x == 64 else 42)]), fill=B)
    d.ellipse(P([(56, 76), (72, 92)]), fill=NADA)


def g_peligro(d):
    d.polygon(P([(64, 10), (120, 112), (8, 112)]), fill=B)
    d.polygon(P([(58, 42), (70, 42), (67, 82), (61, 82)]), fill=NADA)
    d.ellipse(P([(57, 88), (71, 102)]), fill=NADA)


def g_barco(d):
    d.polygon(P([(10, 76), (118, 76), (98, 104), (28, 104)]), fill=B)
    d.rectangle(P([(61, 12), (67, 78)]), fill=B)
    d.polygon(P([(70, 14), (110, 68), (70, 68)]), fill=B)
    d.polygon(P([(58, 26), (58, 68), (24, 68)]), fill=B)
    d.line(P([(10, 116), (30, 110), (50, 116), (70, 110), (90, 116), (110, 110), (120, 114)]), fill=B, width=5 * SS)


def g_zepelin(d):
    d.ellipse(P([(8, 16), (110, 70)]), fill=B)
    d.polygon(P([(96, 40), (124, 18), (124, 64)]), fill=B)
    d.line(P([(30, 44), (90, 44)]), fill=NADA, width=3 * SS)
    d.line(P([(44, 70), (48, 86)]), fill=B, width=3 * SS)
    d.line(P([(80, 70), (76, 86)]), fill=B, width=3 * SS)
    d.rounded_rectangle(P([(40, 84), (86, 104)]), radius=5 * SS, fill=B)
    for x in (48, 60, 72):
        d.rectangle(P([(x, 89), (x + 7, 97)]), fill=NADA)


def g_tranvia(d):
    d.rounded_rectangle(P([(22, 18), (106, 96)]), radius=14 * SS, fill=B)
    d.rectangle(P([(32, 30), (60, 56)]), fill=NADA)
    d.rectangle(P([(68, 30), (96, 56)]), fill=NADA)
    d.ellipse(P([(32, 70), (46, 84)]), fill=NADA)
    d.ellipse(P([(82, 70), (96, 84)]), fill=NADA)
    d.line(P([(36, 96), (22, 116)]), fill=B, width=6 * SS)
    d.line(P([(92, 96), (106, 116)]), fill=B, width=6 * SS)
    d.line(P([(14, 116), (114, 116)]), fill=B, width=4 * SS)


def g_raro(d):
    d.ellipse(P([(26, 22), (102, 92)]), fill=B)
    d.rectangle(P([(42, 80), (86, 108)]), fill=B)
    d.ellipse(P([(38, 46), (60, 68)]), fill=NADA)
    d.ellipse(P([(68, 46), (90, 68)]), fill=NADA)
    d.polygon(P([(64, 70), (58, 82), (70, 82)]), fill=NADA)
    for x in (52, 64, 76):
        d.rectangle(P([(x - 2, 96), (x + 2, 108)]), fill=NADA)
    # Los cuernos de élite.
    d.polygon(P([(30, 40), (8, 8), (44, 26)]), fill=B)
    d.polygon(P([(98, 40), (120, 8), (84, 26)]), fill=B)


def g_tesoro(d):
    d.rounded_rectangle(P([(14, 26), (114, 62)]), radius=16 * SS, fill=B)
    d.rectangle(P([(14, 50), (114, 110)]), fill=B)
    d.rectangle(P([(14, 58), (114, 64)]), fill=NADA)
    d.rectangle(P([(54, 52), (74, 80)]), fill=NADA)
    d.rectangle(P([(58, 56), (70, 76)]), fill=B)
    d.rectangle(P([(30, 26), (36, 110)]), fill=NADA)
    d.rectangle(P([(92, 26), (98, 110)]), fill=NADA)


def g_manada(d):
    d.ellipse(P([(34, 58), (94, 112)]), fill=B)
    for (x, y) in ((22, 36), (46, 14), (82, 14), (106, 36)):
        d.ellipse(P([(x - 13, y - 15), (x + 13, y + 15)]), fill=B)


def g_nivel(d):
    for y in (52, 82):
        d.polygon(P([(16, y + 26), (64, y - 18), (112, y + 26), (112, y + 42), (64, y - 2), (16, y + 42)]), fill=B)
    pts = []
    for i in range(10):
        a = math.radians(i * 36 - 90)
        r = 18 if i % 2 == 0 else 7
        pts.append((64 + math.cos(a) * r, 18 + math.sin(a) * r))
    d.polygon(P(pts), fill=B)


GLIFOS = {
    "zona": g_zona, "rincon": g_rincon, "descubrir": g_descubrir, "ciudad": g_ciudad, "mazmorra": g_mazmorra,
    "banda": g_banda, "peligro": g_peligro, "barco": g_barco, "zepelin": g_zepelin, "tranvia": g_tranvia,
    "raro": g_raro, "tesoro": g_tesoro, "manada": g_manada, "nivel": g_nivel,
}


# ---------------------------------------------------------------------------
# 1.4.0 (Toxic: «la mancha oscura no me gusta del todo»): tres fondos con
# más detalle. Grises claros con transparencia: el juego los tiñe del color
# del tipo (más oscuro, para que el nombre claro se lea encima).
# ---------------------------------------------------------------------------
def _gris(v, a=255):
    v = max(0, min(255, int(v)))
    return (v, v, v, a)


def cinta_centro():
    """El cuerpo de la cinta: tela con trama fina y dos dobladillos con puntada."""
    w, h = 128, 64
    im = Image.new("RGBA", (w, h), NADA)
    px = im.load()
    rnd = random.Random(11)
    for x in range(w):
        hilo = rnd.uniform(-2, 2)
        for y in range(h):
            borde = min(y, h - 1 - y)
            if borde < 2:
                v = 200                       # el canto, con luz
            elif borde < 7:
                v = 175 - (borde - 2) * 6     # el dobladillo
            else:
                v = 140 + hilo + rnd.uniform(-3, 3) + (3 if (x + y) % 4 == 0 else 0)
                # una sombra suave hacia el centro: la tela se curva
                v -= 18 * (1 - abs((y - h / 2) / (h / 2 - 7)))
            px[x, y] = _gris(v)
    d = ImageDraw.Draw(im)
    for y in (8, h - 9):                      # la puntada
        for x in range(0, w, 8):
            d.line([(x + 1, y), (x + 4, y)], fill=_gris(95))
    return im


def cinta_punta():
    """La punta de pendón (izquierda; la derecha es la misma, volteada)."""
    w, h, s = 64, 64, SS
    im = Image.new("RGBA", (w * s, h * s), NADA)
    d = ImageDraw.Draw(im)
    forma = [(w * s, 0), (6 * s, 0), (24 * s, h * s / 2), (6 * s, h * s), (w * s, h * s)]
    d.polygon(forma, fill=_gris(140))
    # El pliegue: una franja más oscura antes del cuerpo.
    d.polygon([(w * s - 10 * s, 0), (w * s - 4 * s, 0), (w * s - 4 * s, h * s), (w * s - 10 * s, h * s)], fill=_gris(92))
    # Los cantos con luz siguiendo la forma.
    d.line([(6 * s, 2 * s), (w * s, 2 * s)], fill=_gris(200), width=3 * s)
    d.line([(6 * s, h * s - 2 * s), (w * s, h * s - 2 * s)], fill=_gris(200), width=3 * s)
    d.line([(7 * s, 1 * s), (24 * s, h * s / 2), (7 * s, h * s - 1 * s)], fill=_gris(200), width=3 * s)
    return im.resize((w, h), Image.LANCZOS)


def filigrana():
    """El ornamento de un lado del nombre (el de la derecha es el mismo, volteado):
    un rombo junto al nombre, una línea que se adelgaza y dos volutas."""
    w, h, s = 256, 48, SS
    im = Image.new("RGBA", (w * s, h * s), NADA)
    d = ImageDraw.Draw(im)
    cy = h / 2
    B2 = (255, 255, 255, 255)
    # La línea, más gruesa junto al nombre.
    for i in range(0, 220):
        x = 236 - i
        g = 3.2 - 2.4 * (i / 220)
        a = int(255 * (1 - (i / 220) ** 2.2))
        d.ellipse([(x - g / 2) * s, (cy - g / 2) * s, (x + g / 2) * s, (cy + g / 2) * s], fill=(255, 255, 255, a))
    # El rombo junto al nombre.
    d.polygon([(244 * s, (cy - 6) * s), (250 * s, cy * s), (244 * s, (cy + 6) * s), (238 * s, cy * s)], fill=B2)
    # Dos volutas: una arriba, una abajo.
    for cx, arriba, r in ((172, True, 12), (116, False, 10)):
        y0 = cy - r if arriba else cy + r
        caja = [(cx - r) * s, (y0 - r) * s, (cx + r) * s, (y0 + r) * s]
        if arriba:
            d.arc(caja, 0, 270, fill=B2, width=int(2 * s))
        else:
            d.arc(caja, 90, 360, fill=B2, width=int(2 * s))
        r2 = r * 0.45
        caja2 = [(cx - r2) * s, (y0 - r2) * s, (cx + r2) * s, (y0 + r2) * s]
        d.arc(caja2, 0, 300, fill=B2, width=int(1.6 * s))
    # Una hoja a cada lado del rombo.
    d.polygon([(226 * s, cy * s), (214 * s, (cy - 7) * s), (204 * s, (cy - 2) * s)], fill=B2)
    d.polygon([(226 * s, cy * s), (214 * s, (cy + 7) * s), (204 * s, (cy + 2) * s)], fill=B2)
    return im.resize((w, h), Image.LANCZOS)


def todo():
    out = {"anuncio-niebla": niebla(), "anuncio-disco": disco(), "anuncio-aro": aro(), "anuncio-luz": luz(),
           "anuncio-cinta": cinta_centro(), "anuncio-cinta-punta": cinta_punta(), "anuncio-filigrana": filigrana()}
    for n, fn in GLIFOS.items():
        im, d, _ = lienzo()
        fn(d)
        out["anuncio-" + n] = reducir(im)
    return out


def main():
    SALIDA.mkdir(parents=True, exist_ok=True)
    imgs = todo()
    for n, im in imgs.items():
        im.save(SALIDA / f"{n}.tga")
    if len(sys.argv) > 1:
        hoja = Image.new("RGBA", (16 + 84 * len(GLIFOS), 200), (12, 15, 22, 255))
        for i, n in enumerate(GLIFOS):
            x = 16 + i * 84
            hoja.alpha_composite(imgs["anuncio-disco"].resize((72, 72)).point(lambda v: v), (x, 16))
            g = imgs["anuncio-" + n].resize((40, 40), Image.LANCZOS)
            tinte = Image.new("RGBA", g.size, (255, 214, 120, 255))
            tinte.putalpha(g.split()[3])
            fondo = Image.new("RGBA", (72, 72), (10, 12, 18, 255))
            mask = imgs["anuncio-disco"].resize((72, 72)).split()[3]
            hoja.paste(fondo, (x, 16), mask)
            a = imgs["anuncio-aro"].resize((72, 72))
            ta = Image.new("RGBA", a.size, (255, 214, 120, 255))
            ta.putalpha(a.split()[3])
            hoja.alpha_composite(ta, (x, 16))
            hoja.alpha_composite(tinte, (x + 16, 32))
            hoja.alpha_composite(g, (x + 16, 110))
        hoja.save(sys.argv[1])


if __name__ == "__main__":
    main()
