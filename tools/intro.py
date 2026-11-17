"""Dibuja las texturas de la intro del lobo y la luna (Alfa_Bienvenida).

Uso:  .venv/Scripts/python -I tools/intro.py [carpeta_vista_previa]

Escribe en src/Alfa_Bienvenida/Media, como TGA de 32 bits sin comprimir:
  intro-luna.tga         la luna llena (256): disco con sus mares y cráteres
  intro-halo.tga         un resplandor redondo y suave (256): detrás de la luna
                         y detrás de la marca A L F A
  intro-estrella.tga     una estrella (32): punto suave con cuatro puntas cortas
  intro-lobo.tga         el lobo sentado que aúlla sobre su peña (512), en una
                         sola silueta blanca: Intro.lua la tiñe casi negra para
                         recortarla contra la luna
  intro-lobo-borde.tga   la luz de la luna en el contorno del lobo y de la peña
                         (512), en blanco: se tiñe con el acento del estilo
  intro-onda.tga         una onda del aullido (256): un arco abierto hacia la
                         luna, centrado en el hocico
  intro-destello.tga     el destello de la marca (64): cuatro puntas finas
  intro-marca.tga        A L F A en la letra de Alfa (512 x 64), para la marca
                         y su brillo (que la recorre por sus coordenadas)

Todas son blancas (o grises) para que el juego las tiña con los colores de
cada estilo (alfa, clásico, cristal). Con una carpeta, deja ahí una hoja PNG
para revisarlas sobre fondo oscuro.
"""
import math
import pathlib
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "src" / "Alfa_Bienvenida" / "Media"
F = 4  # sobremuestreo: se dibuja a 4x y se reduce (bordes suaves)
BLANCO = (255, 255, 255, 255)


def lienzo(lado):
    return Image.new("RGBA", (lado * F, lado * F), (255, 255, 255, 0))


def reducir(im, lado):
    return im.resize((lado, lado), Image.LANCZOS)


def blanco_con_alfa(alfa: Image.Image) -> Image.Image:
    """Una imagen blanca cuyo alfa es `alfa` (modo L)."""
    im = Image.new("RGBA", alfa.size, (255, 255, 255, 0))
    im.putalpha(alfa)
    return im


# ---------------------------------------------------------------------------
# La luna
# ---------------------------------------------------------------------------
def luna():
    lado = 256
    s = lado * F
    c, r = s / 2, s * 0.46
    # El disco, un poco más oscuro hacia el borde (el limbo) y con luz desde arriba a la derecha.
    disco = Image.new("L", (s, s), 0)
    ImageDraw.Draw(disco).ellipse([c - r, c - r, c + r, c + r], fill=255)
    luz = Image.new("L", (s, s), 0)
    px = luz.load()
    paso = 4
    for y in range(0, s, paso):
        for x in range(0, s, paso):
            dx, dy = (x - c) / r, (y - c) / r
            d2 = dx * dx + dy * dy
            if d2 > 1.05:
                continue
            limbo = math.sqrt(max(0.0, 1 - min(1.0, d2)))
            lado_luz = 0.5 + 0.5 * (dx * 0.45 - dy * 0.55)
            v = 196 + 46 * limbo + 13 * lado_luz
            for yy in range(y, min(s, y + paso)):
                for xx in range(x, min(s, x + paso)):
                    px[xx, yy] = int(max(0, min(255, v)))
    luz = luz.filter(ImageFilter.GaussianBlur(F * 2))
    # Los mares: manchas grandes y suaves.
    mares = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(mares)
    for (mx, my, mr, a) in ((-0.28, -0.22, 0.30, 70), (0.05, -0.32, 0.20, 60), (0.22, 0.05, 0.26, 66),
                            (-0.12, 0.25, 0.22, 52), (-0.38, 0.12, 0.14, 46), (0.30, 0.34, 0.12, 40)):
        x0, y0 = c + mx * r, c + my * r
        d.ellipse([x0 - mr * r, y0 - mr * r * 0.85, x0 + mr * r, y0 + mr * r * 0.85], fill=a)
    mares = mares.filter(ImageFilter.GaussianBlur(F * 7))
    # Cráteres: aro claro y centro oscuro.
    crateres = Image.new("L", (s, s), 0)
    brillo = Image.new("L", (s, s), 0)
    dc, db = ImageDraw.Draw(crateres), ImageDraw.Draw(brillo)
    rnd = random.Random(7)
    for (mx, my, mr) in ((0.42, -0.30, 0.07), (-0.05, 0.52, 0.08), (0.55, 0.18, 0.05), (-0.50, -0.35, 0.05),
                         (0.18, 0.62, 0.04), (-0.62, 0.30, 0.045), (0.36, -0.58, 0.04)):
        x0, y0, rr = c + mx * r, c + my * r, mr * r
        dc.ellipse([x0 - rr, y0 - rr, x0 + rr, y0 + rr], fill=60)
        db.arc([x0 - rr * 1.15, y0 - rr * 1.15, x0 + rr * 1.15, y0 + rr * 1.15], 200, 380, fill=90, width=int(F * 2))
    for _ in range(26):
        a, dd = rnd.uniform(0, math.tau), math.sqrt(rnd.uniform(0, 0.8))
        x0, y0, rr = c + math.cos(a) * dd * r, c + math.sin(a) * dd * r, rnd.uniform(0.012, 0.03) * r
        dc.ellipse([x0 - rr, y0 - rr, x0 + rr, y0 + rr], fill=40)
    crateres = crateres.filter(ImageFilter.GaussianBlur(F * 1.2))
    brillo = brillo.filter(ImageFilter.GaussianBlur(F * 1.0))
    gris = ImageChops.subtract(ImageChops.subtract(luz, mares), crateres)
    gris = ImageChops.add(gris, brillo)
    # Un borde fino y luminoso.
    aro = Image.new("L", (s, s), 0)
    ImageDraw.Draw(aro).ellipse([c - r, c - r, c + r, c + r], outline=255, width=int(F * 1.5))
    aro = aro.filter(ImageFilter.GaussianBlur(F * 0.8))
    gris = ImageChops.lighter(gris, ImageChops.multiply(aro, Image.new("L", (s, s), 235)))
    im = Image.merge("RGBA", (gris, gris, gris, disco))
    return im.resize((lado, lado), Image.LANCZOS)


# ---------------------------------------------------------------------------
# El resplandor, la estrella y el destello
# ---------------------------------------------------------------------------
def halo():
    lado = 256
    a = Image.new("L", (lado, lado), 0)
    px = a.load()
    c = (lado - 1) / 2
    for y in range(lado):
        for x in range(lado):
            d = math.hypot(x - c, y - c) / c
            if d < 1:
                # una campana suave que llega a cero en el borde
                v = math.exp(-d * d * 4.2) * (1 - d) ** 1.4
                px[x, y] = int(255 * min(1, v * 1.15))
    return blanco_con_alfa(a)


def estrella():
    lado = 32
    s = lado * F
    a = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(a)
    c = s / 2
    # el brillo de fondo
    nube = Image.new("L", (s, s), 0)
    ImageDraw.Draw(nube).ellipse([c - s * 0.3, c - s * 0.3, c + s * 0.3, c + s * 0.3], fill=110)
    nube = nube.filter(ImageFilter.GaussianBlur(F * 3))
    # cuatro puntas cortas y finas
    for ang in (0, 90, 180, 270):
        t = math.radians(ang)
        largo, ancho = s * 0.46, s * 0.05
        px, py = c + math.cos(t) * largo, c + math.sin(t) * largo
        nx, ny = -math.sin(t) * ancho, math.cos(t) * ancho
        d.polygon([(c + nx, c + ny), (px, py), (c - nx, c - ny)], fill=200)
    d.ellipse([c - s * 0.1, c - s * 0.1, c + s * 0.1, c + s * 0.1], fill=255)
    a = ImageChops.lighter(a, nube)
    return blanco_con_alfa(a.resize((lado, lado), Image.LANCZOS))


def destello():
    lado = 64
    s = lado * F
    a = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(a)
    c = s / 2
    for ang, largo in ((0, 0.49), (90, 0.49), (180, 0.49), (270, 0.49), (45, 0.22), (135, 0.22), (225, 0.22), (315, 0.22)):
        t = math.radians(ang)
        ancho = s * (0.045 if largo > 0.3 else 0.03)
        px, py = c + math.cos(t) * s * largo, c + math.sin(t) * s * largo
        nx, ny = -math.sin(t) * ancho, math.cos(t) * ancho
        d.polygon([(c + nx, c + ny), (px, py), (c - nx, c - ny)], fill=255)
    nube = Image.new("L", (s, s), 0)
    ImageDraw.Draw(nube).ellipse([c - s * 0.16, c - s * 0.16, c + s * 0.16, c + s * 0.16], fill=170)
    nube = nube.filter(ImageFilter.GaussianBlur(F * 4))
    a = ImageChops.lighter(a.filter(ImageFilter.GaussianBlur(F * 0.6)), nube)
    return blanco_con_alfa(a.resize((lado, lado), Image.LANCZOS))


# ---------------------------------------------------------------------------
# El lobo sentado que aúlla, sobre su peña (512 unidades; y hacia abajo).
# De perfil mirando a la derecha, la cabeza alzada y el hocico hacia la luna.
# ---------------------------------------------------------------------------
HOCICO = (350, 76)  # la punta del hocico: de aquí salen las ondas (Intro.lua)

LOBO = [
    # la cola, tupida y tendida sobre la peña
    (78, 397), (86, 388), (98, 378), (116, 368), (138, 361), (158, 358), (176, 358),
    # la grupa y el muslo
    (184, 348), (186, 334), (192, 318),
    # el lomo, de la grupa a la cruz
    (202, 298), (214, 278), (228, 258), (242, 240),
    # la melena del cuello, con sus mechones
    (250, 228), (248, 216), (258, 208), (256, 196), (264, 186), (264, 172),
    # la nuca y la oreja, echada hacia atrás al aullar
    (270, 156), (262, 126), (286, 140),
    # la frente y el hocico alzado hacia la luna
    (298, 132), (308, 122), (320, 106), (334, 90), (350, 74),
    # la boca abierta: la mandíbula de arriba, la comisura y la de abajo
    (353, 79), (340, 96), (329, 111), (346, 101), (349, 106), (338, 118), (332, 126),
    # la garganta con su melena y el pecho
    (330, 140), (326, 152), (333, 160), (327, 170), (331, 184), (338, 204), (344, 228),
    (347, 252), (345, 276),
    # la pata delantera de adelante, hasta la peña
    (343, 298), (343, 332), (345, 360), (347, 378), (360, 384), (363, 393), (329, 393),
    (330, 378), (328, 350), (324, 320),
    # el vientre, el muslo de adelante y la pata de atrás
    (315, 322), (305, 338), (300, 362), (306, 380), (318, 387), (318, 394),
    (240, 395), (200, 393), (176, 390),
    # la cola por abajo
    (150, 393), (120, 396), (96, 399),
]
# La otra pata delantera, un poco más atrás.
PATA = [(305, 296), (311, 336), (312, 372), (321, 386), (322, 394), (298, 394), (300, 372), (296, 332)]
# La peña: una cresta de roca con escalones, que se pierde a los lados y abajo.
PENA = [
    (0, 474), (0, 452), (36, 440), (70, 424), (96, 411), (120, 404), (150, 397), (176, 392),
    (232, 389), (300, 391), (352, 393), (382, 399), (404, 407), (422, 405), (446, 418),
    (472, 432), (494, 446), (512, 452), (512, 512), (0, 512),
]
# Facetas de la peña (un tono apenas más claro para dar volumen).
FACETAS_PENA = [
    [(70, 424), (120, 404), (150, 446), (90, 468)],
    [(232, 389), (300, 391), (276, 432), (220, 440)],
    [(352, 393), (404, 407), (384, 452), (330, 444)],
    [(446, 418), (494, 446), (470, 486), (420, 472)],
]


def _escalar(pts, f=F):
    return [(x * f, y * f) for x, y in pts]


def _silueta():
    """El alfa del lobo con su peña (modo L, a 512*F) y el del lobo solo."""
    s = 512 * F
    lobo = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(lobo)
    d.polygon(_escalar(LOBO), fill=255)
    d.polygon(_escalar(PATA), fill=255)
    pena = Image.new("L", (s, s), 0)
    ImageDraw.Draw(pena).polygon(_escalar(PENA), fill=255)
    # La peña se pierde a los lados y hacia abajo.
    desvanecer = Image.new("L", (s, s), 0)
    px = desvanecer.load()
    for x in range(0, s, F):
        lado = min(x, s - 1 - x) / (s * 0.22)
        v = int(255 * min(1.0, lado) ** 1.3)
        for xx in range(x, min(s, x + F)):
            px[xx, 0] = v
    fila = desvanecer.crop((0, 0, s, 1))
    desvanecer = fila.resize((s, s))
    abajo = Image.new("L", (1, s), 0)
    pa = abajo.load()
    for y in range(s):
        t = (y / F - 430) / 82.0
        pa[0, y] = int(255 * max(0.0, min(1.0, 1 - t)))
    abajo = abajo.resize((s, s))
    pena = ImageChops.multiply(ImageChops.multiply(pena, desvanecer), abajo)
    return ImageChops.lighter(lobo, pena), lobo


def lobo():
    alfa, solo = _silueta()
    s = 512 * F
    # Gris casi blanco con las facetas de la peña un poco más claras: al teñirlo
    # oscuro, la roca toma volumen sin perder la silueta.
    gris = Image.new("L", (s, s), 226)
    d = ImageDraw.Draw(gris)
    for fac in FACETAS_PENA:
        d.polygon(_escalar(fac), fill=255)
    gris = ImageChops.lighter(gris, solo)  # el lobo, parejo
    im = Image.merge("RGBA", (gris, gris, gris, alfa))
    return im.resize((512, 512), Image.LANCZOS)


def lobo_borde():
    """La luz de la luna en el contorno: más fuerte arriba y del lado de la luna."""
    alfa, solo = _silueta()
    s = 512 * F
    adentro = alfa.filter(ImageFilter.MinFilter(F * 3 + 1))
    # el contorno corrido hacia la luna (arriba a la derecha): un filo de luz de ese lado
    corrido = ImageChops.offset(adentro, -F * 3, F * 3)
    filo = ImageChops.subtract(alfa, corrido)
    filo = filo.filter(ImageFilter.GaussianBlur(F * 0.9))
    # arriba más fuerte que abajo, y la peña más tenue que el lobo
    peso = Image.new("L", (1, s), 0)
    pp = peso.load()
    for y in range(s):
        t = y / s
        pp[0, y] = int(255 * max(0.18, min(1.0, 1.25 - t * 1.3)))
    peso = peso.resize((s, s))
    filo = ImageChops.multiply(filo, peso)
    lobo_filo = ImageChops.multiply(filo, solo.filter(ImageFilter.MaxFilter(F * 2 + 1)))
    pena_filo = ImageChops.multiply(ImageChops.subtract(filo, lobo_filo), Image.new("L", (s, s), 120))
    a = ImageChops.lighter(lobo_filo, pena_filo)
    # un resplandor muy suave por fuera del lobo
    brillo = solo.filter(ImageFilter.GaussianBlur(F * 6))
    brillo = ImageChops.subtract(brillo, solo)
    brillo = ImageChops.multiply(brillo, Image.new("L", (s, s), 90))
    a = ImageChops.lighter(a, ImageChops.multiply(brillo, peso))
    return blanco_con_alfa(a.resize((512, 512), Image.LANCZOS))


def onda():
    """Un arco abierto hacia la luna (arriba, un poco a la derecha)."""
    lado = 256
    s = lado * F
    a = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(a)
    c = s / 2
    r = s * 0.44
    # PIL: 0 grados a la derecha y en el sentido del reloj; el hocico mira a unos -62.
    centro, abre = -62, 46
    pasos = 36
    for i in range(pasos):
        t0 = centro - abre + 2 * abre * i / pasos
        t1 = centro - abre + 2 * abre * (i + 1) / pasos
        # más grueso y más claro al centro del arco
        m = 1 - abs((i + 0.5) / pasos * 2 - 1)
        ancho = int(F * (1.5 + 4.5 * m))
        d.arc([c - r, c - r, c + r, c + r], t0, t1 + 0.5, fill=int(90 + 165 * m), width=ancho)
    a = a.filter(ImageFilter.GaussianBlur(F * 1.1))
    return blanco_con_alfa(a.resize((lado, lado), Image.LANCZOS))


FUENTE = RAIZ / "upstream" / "polestar-0.3.7.2" / "Polestar" / "Media" / "Fonts" / "Inter-SemiBold.ttf"


def marca():
    """A L F A en Inter SemiBold, espaciada, en 512 x 64 (la misma letra de la interfaz)."""
    from PIL import ImageFont
    w, h = 512, 64
    a = Image.new("L", (w * F, h * F), 0)
    d = ImageDraw.Draw(a)
    fuente = ImageFont.truetype(str(FUENTE), int(h * F * 0.74))
    letras = "ALFA"
    anchos = [d.textlength(x, font=fuente) for x in letras]
    hueco = h * F * 0.62
    total = sum(anchos) + hueco * (len(letras) - 1)
    x = (w * F - total) / 2
    for letra, an in zip(letras, anchos):
        d.text((x, h * F / 2), letra, font=fuente, fill=255, anchor="lm")
        x += an + hueco
    return blanco_con_alfa(a.resize((w, h), Image.LANCZOS))


TEXTURAS = {
    "intro-luna": luna, "intro-halo": halo, "intro-estrella": estrella, "intro-destello": destello,
    "intro-lobo": lobo, "intro-lobo-borde": lobo_borde, "intro-onda": onda, "intro-marca": marca,
}


def hoja(imagenes: dict, destino: pathlib.Path):
    """Las texturas sobre fondo oscuro, y una composición de prueba."""
    ancho = 1400
    im = Image.new("RGB", (ancho, 980), (12, 16, 14))
    x, y = 20, 20
    for nombre, t in imagenes.items():
        v = t if t.size[0] <= 256 else t.resize((256, 256), Image.LANCZOS)
        if v.size[0] < 96:
            v = v.resize((96, 96), Image.LANCZOS)
        im.paste(v.convert("RGB"), (x, y), v.getchannel("A"))
        x += v.size[0] + 20
        if x > ancho - 280:
            x, y = 20, y + 280
    # composición: luna con halo, lobo oscuro con su filo verde
    base = Image.new("RGBA", (640, 640), (6, 9, 8, 255))
    h = imagenes["intro-halo"].resize((560, 560), Image.LANCZOS)
    hh = Image.new("RGBA", h.size, (139, 224, 78, 0))
    hh.putalpha(h.getchannel("A").point(lambda v: v * 45 // 100))
    base.alpha_composite(hh, (60, 0))
    l = imagenes["intro-luna"].resize((330, 330), Image.LANCZOS)
    tl = Image.merge("RGBA", [c.point(lambda v, k=k: v * k // 255) for c, k in zip(l.split()[:3], (226, 242, 220))] + [l.getchannel("A")])
    base.alpha_composite(tl, (175, 115))
    w = imagenes["intro-lobo"].resize((420, 420), Image.LANCZOS)
    tw = Image.merge("RGBA", [c.point(lambda v, k=k: v * k // 255) for c, k in zip(w.split()[:3], (16, 22, 18))] + [w.getchannel("A")])
    base.alpha_composite(tw, (60, 170))
    b = imagenes["intro-lobo-borde"].resize((420, 420), Image.LANCZOS)
    tb = Image.new("RGBA", b.size, (139, 224, 78, 0))
    tb.putalpha(b.getchannel("A"))
    base.alpha_composite(tb, (60, 170))
    im.paste(base.convert("RGB"), (ancho - 660, 320))
    im.save(destino)
    return destino


def main() -> int:
    SALIDA.mkdir(parents=True, exist_ok=True)
    hechas = {}
    for nombre, fn in TEXTURAS.items():
        t = fn()
        t.save(SALIDA / f"{nombre}.tga")
        hechas[nombre] = t
        print(f"{nombre}.tga {t.size[0]}x{t.size[1]}")
    if len(sys.argv) > 1:
        carpeta = pathlib.Path(sys.argv[1])
        carpeta.mkdir(parents=True, exist_ok=True)
        print("hoja:", hoja(hechas, carpeta / "intro-hoja.png"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
