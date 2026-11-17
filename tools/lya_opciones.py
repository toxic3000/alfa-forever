"""Las dos propuestas para Lya que se compararon (toxic3000 / La Jauría). GPL-3.0.

Uso (desde la raíz del proyecto):
  .venv/Scripts/python -I tools/lya_opciones.py [carpeta-de-salida]

No toca src/: solo dibuja la hoja para comparar las dos opciones. Toxic eligió
la B, que ya es la Lya del juego: su dibujo (y el lienzo, los colores y la
salchicha que usan las dos) vive en tools/lya_cuerpo.py y aquí se toma de ahí.

  Opción A "Lobita chibi": cabeza grande, cuerpo corto, de frente; pixel art
    gordito de 34 x 28 pixeles que el juego mostraría a x2 (un pixel del
    dibujo = 2 px de pantalla): 54 x 48 px en pantalla sentada.
  Opción B "Loba de perfil estilizada" (la elegida): de perfil, más fina, con
    su pañoleta verde de Alfa y el rombo; pixel art de 60 x 54 pixeles
    mostrado a x1: unos 57 x 50 px en pantalla parada.
  (La de antes medía 94 x 80. Las medidas cuentan el contorno y el borde teñido.)

Escribe en la carpeta: comparacion.png, opcion-a.png y opcion-b.png.
"""
import pathlib
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

RAIZ = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "tools"))
import lya_cuerpo as lya  # noqa: E402  (la opción B, ya en el juego)
from lya_cuerpo import (  # noqa: E402  (lo que comparten las dos opciones)
    BRILLO_OJO, CABEZA, COLA, CUERPO, FRENTE, LEJANA, LENGUA, LENGUA_SOMBRA, NARIZ, NARIZ_BRILLO, OJO,
    OJO_CLARO, OJO_OSCURO, PARPADO, PATA, PUPILA, VERDE, Lienzo, componer, girar, salchicha)

FUENTES = RAIZ / "upstream" / "polestar-0.3.7.2" / "Polestar" / "Media" / "Fonts"
MEDIA = RAIZ / "src" / "Alfa_Lya" / "Media"

# Los colores propios de la opción A: negro suave, con volumen en carbón
CACHETE = (112, 64, 86)         # el rubor de la chibi, apenas
PIEL_A = {"base": (30, 32, 42), "medio": (40, 44, 57), "luz": (62, 69, 89), "brillo": (76, 86, 112),
          "sombra": (19, 20, 27), "linea": (12, 13, 18)}
PIEL_A_LEJOS = {"base": (22, 24, 31), "medio": (27, 29, 38), "luz": (40, 44, 57), "brillo": (40, 44, 57),
                "sombra": (15, 16, 21), "linea": (10, 11, 15)}
HOCICO_A = (64, 70, 90)


# ---------------------------------------------------------------------------
# Opción A: la lobita chibi (34 x 28, x2 en pantalla)
# ---------------------------------------------------------------------------
AW, AH = 34, 28
AX = 16.5              # el eje de la cara (entre los pixeles 16 y 17)
AEJE = 34              # para espejar: x' = 33 - x


def a_cabeza_frente(lo, cy=14.0, orejas="arriba", cx=AX):
    """La cabeza grande de frente (basta la mitad izquierda: luego se espeja)."""
    if orejas == "arriba":
        oreja = [(cx - 7.4, cy - 1.2), (cx - 2.4, cy - 4.2), (cx - 6.8, cy - 7.8)]
        dentro = [(cx - 6.4, cy - 2.0), (cx - 3.8, cy - 3.6), (cx - 6.2, cy - 6.2)]
    else:  # un poco hacia los lados (contenta)
        oreja = [(cx - 7.2, cy - 2.4), (cx - 2.6, cy - 4.8), (cx - 9.4, cy - 7.6)]
        dentro = [(cx - 6.6, cy - 3.0), (cx - 4.0, cy - 4.4), (cx - 8.2, cy - 6.6)]
    lo.poli(oreja, CABEZA)
    lo.orejas.append(dentro)
    lo.orejas.append([(2 * cx - x, y) for x, y in dentro])
    lo.elipse(cx, cy, 7.2, 5.0, CABEZA)
    lo.elipse(cx, cy + 1.8, 6.8, 3.6, CABEZA)
    # el pelo esponjado de los cachetes (de lobo)
    lo.poli([(cx - 6.4, cy + 0.2), (cx - 8.8, cy + 3.2), (cx - 5.2, cy + 4.0)], CABEZA)
    lo.poli([(cx - 4.6, cy + 3.6), (cx - 5.6, cy + 5.8), (cx - 2.4, cy + 5.2)], CABEZA)
    # y la melenita del pecho, en picos
    lo.poli([(cx - 2.6, cy + 4.6), (cx - 0.2, cy + 4.8), (cx - 1.2, cy + 6.8)], CABEZA)


def a_cara(lo, cy=14.0, ojos="abiertos", boca="cerrada", mirar=0, cx=AX):
    """Ojos, hocico y nariz, pixel por pixel (la cara ya espejada)."""
    c = int(cx - 0.5)          # el pixel izquierdo del centro (16)
    ey = int(cy) - 1           # la fila de arriba de los ojos
    for ex in (c - 4, c + 4):
        if ojos == "abiertos":
            # 2 x 3: brillo arriba a la izquierda, el ámbar y lo oscuro abajo
            lo.punto(ex, ey, BRILLO_OJO)
            lo.punto(ex + 1, ey, OJO_CLARO)
            lo.punto(ex, ey + 1, OJO)
            lo.punto(ex + 1, ey + 1, OJO)
            lo.punto(ex, ey + 2, OJO_OSCURO)
            lo.punto(ex + 1, ey + 2, PUPILA)
            if mirar > 0:      # mira hacia arriba (pidiendo): ojitos brillosos
                lo.punto(ex + 1, ey, BRILLO_OJO)
                lo.punto(ex, ey + 2, OJO)
                lo.punto(ex + 1, ey + 2, OJO_OSCURO)
        elif ojos == "felices":   # ^ ^
            lo.punto(ex, ey + 2, PARPADO)
            lo.punto(ex, ey + 1, PARPADO)
            lo.punto(ex + 1, ey + 1, PARPADO)
            lo.punto(ex + 1, ey + 2, PARPADO)
        else:                     # cerrados: una rayita curva
            lo.punto(ex - 1, ey + 1, PARPADO)
            lo.punto(ex, ey + 2, PARPADO)
            lo.punto(ex + 1, ey + 2, PARPADO)
            lo.punto(ex + 2, ey + 1, PARPADO)
    lo.punto(c - 5, ey + 3, CACHETE)
    lo.punto(c + 6, ey + 3, CACHETE)
    # el hocico, un poco más claro, con la nariz arriba y la boquita en "w"
    hy = ey + 3
    for x in range(c - 1, c + 3):
        lo.punto(x, hy, HOCICO_A)
    for x in range(c - 2, c + 4):
        lo.punto(x, hy + 1, HOCICO_A)
    for x in range(c - 1, c + 3):
        lo.punto(x, hy + 2, HOCICO_A)
    lo.punto(c, hy, NARIZ)
    lo.punto(c + 1, hy, NARIZ)
    lo.punto(c, hy - 1, NARIZ_BRILLO)
    lo.punto(c + 1, hy - 1, NARIZ)
    lo.punto(c, hy + 1, PIEL_A["linea"])
    lo.punto(c + 1, hy + 1, PIEL_A["linea"])
    lo.punto(c - 1, hy + 2, PIEL_A["linea"])
    lo.punto(c + 2, hy + 2, PIEL_A["linea"])
    if boca == "lengua":
        lo.punto(c, hy + 2, LENGUA)
        lo.punto(c + 1, hy + 2, LENGUA)
        lo.punto(c, hy + 3, LENGUA)
        lo.punto(c + 1, hy + 3, LENGUA_SOMBRA)


def a_sentada(cola=0.0, ojos="abiertos", boca="cerrada"):
    lo = Lienzo(AW, AH)
    cx = AX
    # el cuerpo de pera y las ancas a los lados
    lo.elipse(cx, 21.8, 5.4, 4.0, CUERPO)
    lo.elipse(cx - 4.4, 23.2, 3.0, 2.6, CUERPO)
    lo.elipse(cx - 5.4, 24.9, 2.2, 0.9, PATA)                   # el pie de atrás
    # las manitas de enfrente
    lo.trazo([(cx - 2.0, 20.4), (cx - 2.0, 24.4)], [2.6, 2.6], PATA)
    lo.elipse(cx - 2.0, 24.8, 1.7, 1.1, FRENTE)
    a_cabeza_frente(lo)
    lo.espejar(AEJE)
    # la cola esponjada, a la derecha, con la punta hacia arriba
    base = (cx + 4.6, 24.4)
    pts = [(base[0] + x, base[1] + y) for x, y in girar([(0, 0), (3.6, -0.4), (5.6, -2.8), (5.8, -6.0)], cola)]
    lo.encima(lambda: lo.trazo(pts, [2.8, 4.2, 4.4, 2.6], COLA))
    a_cara(lo, ojos=ojos, boca=boca)
    return lo


def a_pidiendo(fase=0):
    """Sentada pidiendo: las manitas arriba, la lengua y la salchicha encima."""
    lo = Lienzo(AW, AH)
    cx = AX
    cy = 13.2 - fase * 0.4
    lo.elipse(cx, 21.6, 5.2, 4.2, CUERPO)
    lo.elipse(cx - 4.2, 23.2, 3.0, 2.6, CUERPO)
    lo.elipse(cx - 5.2, 24.9, 2.2, 0.9, PATA)
    a_cabeza_frente(lo, cy=cy)
    lo.espejar(AEJE)
    base = (cx + 4.4, 24.4)
    pts = [(base[0] + x, base[1] + y) for x, y in girar([(0, 0), (3.6, -0.4), (5.6, -2.6), (6.0, -5.8)], -12 * fase)]
    lo.encima(lambda: lo.trazo(pts, [2.8, 4.2, 4.4, 2.6], COLA))
    # las manitas quedan encima de la barbilla
    lo.encima(lambda: [lo.elipse(x, 21.2 - fase * 0.5, 1.6, 1.3, FRENTE) for x in (cx - 2.3, cx + 2.3)])
    a_cara(lo, cy=cy, boca="lengua", mirar=1)
    # la salchicha flotando arriba a la derecha; un destello y un corazoncito (se tiñen)
    lo.objetos.append((salchicha(8, 3, ang=18), 23, 0 + fase))
    lo.dibujo(30, 8 + fase, [".#.", "###", ".#."])
    lo.dibujo(1, 3 - fase, ["##.##", "#####", ".###.", "..#.."])
    return lo


def a_dormida(resp=0.0):
    lo = Lienzo(AW, AH)
    # una bolita: el lomo, la cola enroscada por delante y la cabeza recostada
    lo.elipse(15.2, 21.2 - resp * 0.4, 8.6, 4.8 + resp * 0.4, CUERPO)
    lo.elipse(9.0, 20.6 - resp * 0.4, 4.2, 5.0 + resp * 0.3, CUERPO)
    lo.trazo([(6.2, 23.4), (8.8, 25.2), (14.6, 25.6), (19.4, 25.0)], [3.2, 3.8, 3.8, 2.6], FRENTE)
    cx, cy = 23.5, 19.4
    lo.elipse(cx - 2.4, 24.9, 1.7, 1.0, FRENTE)                  # las manitas
    lo.elipse(cx + 2.4, 24.9, 1.7, 1.0, FRENTE)
    # la cabeza de frente, las orejas caídas a los lados
    for s in (-1, 1):
        lo.poli([(cx + s * 2.4, cy - 4.0), (cx + s * 6.4, cy - 1.8), (cx + s * 7.4, cy - 7.0)], CABEZA)
        lo.orejas.append([(cx + s * 3.6, cy - 3.8), (cx + s * 6.0, cy - 2.6), (cx + s * 6.6, cy - 5.6)])
    lo.elipse(cx, cy, 6.2, 4.6, CABEZA)
    lo.elipse(cx, cy + 1.6, 5.8, 3.4, CABEZA)
    for s in (-1, 1):
        lo.poli([(cx + s * 5.4, cy + 0.4), (cx + s * 7.4, cy + 3.2), (cx + s * 4.0, cy + 3.8)], CABEZA)
    c = int(cx - 0.5)
    ey = int(cy) - 1
    for ex in (c - 3, c + 3):
        lo.punto(ex - 1, ey + 1, PARPADO)
        lo.punto(ex, ey + 2, PARPADO)
        lo.punto(ex + 1, ey + 2, PARPADO)
        lo.punto(ex + 2, ey + 1, PARPADO)
    lo.punto(c - 4, ey + 3, CACHETE)
    lo.punto(c + 5, ey + 3, CACHETE)
    for x in range(c - 1, c + 3):
        lo.punto(x, ey + 3, HOCICO_A)
        lo.punto(x, ey + 4, HOCICO_A)
    lo.punto(c, ey + 3, NARIZ)
    lo.punto(c + 1, ey + 3, NARIZ)
    lo.punto(c, ey + 4, PIEL_A["linea"])
    lo.punto(c + 1, ey + 4, PIEL_A["linea"])
    # las "z" (se tiñen)
    lo.dibujo(26, 8 - int(resp), ["###", ".#.", "###"])
    if resp:
        lo.dibujo(29, 2, ["####", "..#.", ".#..", "####"])
    return lo


def a_corriendo(fase=0):
    """De perfil, la cabeza grande por delante y las patitas cortas en galope."""
    lo = Lienzo(AW, AH)
    bob = (-1.0, 0.4)[fase]
    dx = 1.6
    cx, cy = 22.4 + dx, 11.6 + bob
    # las patas de atrás y la cola al viento
    if fase == 0:   # estirada: manos adelante, patas atrás
        lo.trazo([(dx + 18.6, 19.6 + bob), (dx + 21.8, 22.6 + bob)], [2.8, 2.6], LEJANA)
        lo.trazo([(dx + 10.4, 19.6 + bob), (dx + 7.2, 22.0 + bob)], [2.8, 2.6], LEJANA)
    else:           # recogida: todo bajo la panza
        lo.trazo([(dx + 17.8, 20.0 + bob), (dx + 16.0, 23.8 + bob)], [2.8, 2.6], LEJANA)
        lo.trazo([(dx + 11.4, 20.0 + bob), (dx + 13.8, 23.6 + bob)], [2.8, 2.6], LEJANA)
    tip = (-1.0, 1.4)[fase]
    lo.trazo([(dx + 9.0, 16.4 + bob), (dx + 6.0, 14.8 + bob), (dx + 3.0, 14.4 + bob + tip),
              (dx + 1.0, 15.4 + bob + tip * 1.6)], [2.8, 4.0, 3.8, 2.2], COLA)
    lo.elipse(dx + 14.4, 18.4 + bob, 6.4, 4.6, CUERPO)
    if fase == 0:
        lo.trazo([(dx + 18.0, 20.4 + bob), (dx + 21.4, 23.4 + bob)], [3.0, 2.8], PATA)
        lo.elipse(dx + 22.0, 23.8 + bob, 1.6, 1.0, PATA)
        lo.trazo([(dx + 10.0, 20.4 + bob), (dx + 6.6, 23.0 + bob)], [3.4, 2.8], PATA)
        lo.elipse(dx + 6.2, 23.4 + bob, 1.6, 1.0, PATA)
        for ddx, ddy, al in ((0, 0, 160), (-2, -1, 120), (1, 1, 90)):
            lo.polvo[(int(dx) + 3 + ddx, 25 + ddy)] = al
    else:
        lo.trazo([(dx + 17.6, 21.0 + bob), (dx + 15.6, 24.2 + bob)], [3.0, 2.8], PATA)
        lo.elipse(dx + 16.0, 24.6 + bob, 1.6, 1.0, PATA)
        lo.trazo([(dx + 11.0, 21.0 + bob), (dx + 13.4, 24.0 + bob)], [3.4, 2.8], PATA)
        lo.elipse(dx + 14.0, 24.4 + bob, 1.6, 1.0, PATA)
    # la cabeza de perfil, grande, con la oreja hacia atrás y la lengua de fuera
    lo.poli([(cx - 3.0, cy - 3.4), (cx + 0.6, cy - 4.8), (cx - 5.6, cy - 7.8)], CABEZA)
    lo.orejas.append([(cx - 2.6, cy - 4.0), (cx - 0.4, cy - 4.6), (cx - 4.6, cy - 6.6)])
    lo.elipse(cx, cy, 6.0, 5.0, CABEZA)
    lo.elipse(cx - 0.4, cy + 1.8, 5.8, 3.4, CABEZA)
    lo.poli([(cx - 4.8, cy + 0.4), (cx - 7.8, cy + 3.4), (cx - 3.6, cy + 4.2)], CABEZA)
    lo.elipse(cx + 5.4, cy + 2.0, 2.8, 2.0, CABEZA)                 # el hocico
    ex, ey = int(cx) + 1, int(cy) - 2
    lo.punto(ex, ey, BRILLO_OJO)
    lo.punto(ex + 1, ey, OJO_CLARO)
    lo.punto(ex, ey + 1, OJO)
    lo.punto(ex + 1, ey + 1, OJO)
    lo.punto(ex, ey + 2, OJO_OSCURO)
    lo.punto(ex + 1, ey + 2, PUPILA)
    lo.punto(ex - 1, ey + 3, CACHETE)
    nx, ny = int(cx + 7.8), int(cy + 0.8)
    lo.punto(nx, ny, NARIZ)
    lo.punto(nx - 1, ny, NARIZ)
    lo.punto(nx, ny + 1, NARIZ)
    for x in range(int(cx) + 4, nx - 1):
        lo.punto(x, ny + 1, HOCICO_A)
    lo.punto(nx - 2, ny + 3, LENGUA)
    lo.punto(nx - 2, ny + 4, LENGUA_SOMBRA)
    lo.punto(nx - 1, ny + 3, LENGUA)
    return lo


# ---------------------------------------------------------------------------
# La hoja de comparación
# ---------------------------------------------------------------------------
def fuente(tam, gruesa=False):
    nombre = "Inter-SemiBold.ttf" if gruesa else "Inter-Medium.ttf"
    for f in (FUENTES / nombre, pathlib.Path("C:/Windows/Fonts/segoeui.ttf"), pathlib.Path("C:/Windows/Fonts/arial.ttf")):
        if f.exists():
            return ImageFont.truetype(str(f), tam)
    return ImageFont.load_default()


FONDO_HOJA = (22, 24, 30)
TARJETA = (32, 35, 44)
CELDA = (58, 64, 78)
TEXTO = (232, 236, 240)
TEXTO_SUAVE = (150, 158, 172)


def caja(im):
    """La caja de lo que sí se dibujó (pelaje)."""
    return im.getchannel("A").getbbox()


def fondo_oscuro(w, h):
    """Un recorte tipo WoW de noche: piedra y pasto oscuro, con algo de ruido."""
    import random
    rnd = random.Random(7)
    im = Image.new("RGB", (w, h))
    p = im.load()
    for y in range(h):
        t = y / h
        for x in range(w):
            base = (int(18 + 10 * t), int(26 + 14 * t), int(30 + 4 * t))
            n = rnd.randint(-4, 4)
            p[x, y] = tuple(max(0, c + n) for c in base)
    d = ImageDraw.Draw(im)
    for _ in range(90):
        x, y = rnd.randint(0, w), rnd.randint(int(h * 0.55), h)
        d.line([(x, y), (x + rnd.randint(-2, 2), y - rnd.randint(3, 8))], fill=(34, 52, 36), width=1)
    for _ in range(14):
        x, y = rnd.randint(0, w), rnd.randint(0, int(h * 0.4))
        d.point((x, y), fill=(120, 130, 160))
    return im


def fondo_claro(w, h):
    """Un recorte tipo WoW de día en la nieve: claro y con ruido suave."""
    import random
    rnd = random.Random(11)
    im = Image.new("RGB", (w, h))
    p = im.load()
    for y in range(h):
        t = y / h
        for x in range(w):
            base = (int(214 - 20 * t), int(222 - 16 * t), int(230 - 8 * t))
            n = rnd.randint(-5, 5)
            p[x, y] = tuple(max(0, min(255, c + n)) for c in base)
    d = ImageDraw.Draw(im)
    for _ in range(40):
        x, y = rnd.randint(0, w), rnd.randint(int(h * 0.6), h)
        d.line([(x, y), (x + rnd.randint(4, 12), y)], fill=(184, 194, 206), width=1)
    return im


def sombra_suelo(ancho):
    """La sombra ovalada del juego (lya-sombra.tga), del ancho dado."""
    try:
        s = Image.open(MEDIA / "lya-sombra.tga").convert("RGBA")
    except OSError:
        return None
    alto = max(4, round(ancho / 4))
    s = s.resize((ancho, alto), Image.NEAREST)
    s.putalpha(s.getchannel("A").point(lambda v: int(v * 0.85)))
    return s


def ampliar(im, z):
    return im.resize((im.width * z, im.height * z), Image.NEAREST)


def tarjeta(d, x0, y0, x1, y1, color=TARJETA, r=14):
    d.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=color)


def fila_poses(hoja, d, x0, y0, poses, escala, ancho_celda, alto_celda, sep=16):
    """Las poses en grande: celda redondeada, la loba centrada y su nombre debajo."""
    x = x0
    for nombre, (pelo, borde) in poses:
        tarjeta(d, x, y0, x + ancho_celda, y0 + alto_celda, CELDA, 10)
        im = componer(pelo, borde)
        big = ampliar(im, escala)
        bx = x + (ancho_celda - big.width) // 2
        by = y0 + (alto_celda - big.height) // 2
        hoja.alpha_composite(big, (bx, by))
        f = fuente(17)
        tw = d.textlength(nombre, font=f)
        d.text((x + (ancho_celda - tw) / 2, y0 + alto_celda + 8), nombre, font=f, fill=TEXTO_SUAVE)
        x += ancho_celda + sep


def fila_juego(hoja, d, x0, y0, ancho, alto, figuras):
    """Tamaño real (x1) sobre un recorte oscuro y uno claro; figuras = [(nombre, rgba_en_pantalla)]."""
    mitad = (ancho - 16) // 2
    for j, fondo in enumerate((fondo_oscuro(mitad, alto), fondo_claro(mitad, alto))):
        fx = x0 + j * (mitad + 16)
        m = Image.new("L", (mitad, alto), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, mitad - 1, alto - 1], radius=10, fill=255)
        hoja.paste(fondo, (fx, y0), m)
        suelo = y0 + alto - 34
        n = len(figuras)
        paso = mitad // n
        for i, (nombre, im) in enumerate(figuras):
            bb = caja(im)
            cx = fx + paso * i + paso // 2
            s = sombra_suelo(max(24, (bb[2] - bb[0]) * 9 // 10))
            if s:
                hoja.alpha_composite(s, (cx - s.width // 2, suelo - s.height // 2))
            hoja.alpha_composite(im, (cx - (bb[0] + bb[2]) // 2, suelo - bb[3] + 1))
            nombre = f"{nombre} · {bb[2] - bb[0]}×{bb[3] - bb[1]}"
            f = fuente(14)
            col = (210, 216, 224) if j == 0 else (40, 46, 56)
            tw = d.textlength(nombre, font=f)
            d.text((cx - tw / 2, suelo + 12), nombre, font=f, fill=col)
        etiqueta = "fondo oscuro" if j == 0 else "fondo claro"
        d.text((fx + 12, y0 + 8), etiqueta, font=fuente(13), fill=(150, 160, 170) if j == 0 else (90, 98, 110))


def en_pantalla(par, x):
    pelo, borde = par
    return ampliar(componer(pelo, borde), x)


def alto_en_pantalla(par, x):
    """(alto, ancho) en px de pantalla de todo lo que se ve: pelaje, contorno y borde teñido."""
    bb = caja(componer(*par))
    return (bb[3] - bb[1]) * x, (bb[2] - bb[0]) * x


def opciones():
    A = [
        ("quieta (sentada)", a_sentada().pintar(PIEL_A, PIEL_A_LEJOS)),
        ("pidiendo (salchicha)", a_pidiendo().pintar(PIEL_A, PIEL_A_LEJOS)),
        ("dormida", a_dormida(0.6).pintar(PIEL_A, PIEL_A_LEJOS)),
        ("corriendo", a_corriendo(0).pintar(PIEL_A, PIEL_A_LEJOS)),
    ]
    lista = dict(lya.cuadros())
    B = [("quieta", lista["quieta1"]), ("pidiendo (salchicha)", lista["pedir1"]), ("dormida", lista["dormir2"]),
         ("corriendo", lista["correr1"])]
    return A, B


def hoja_comparacion(A, B, destino):
    ANCHO = 1400
    M = 40
    Z = 4                                    # todo en grande a x4 de su tamaño en pantalla
    XA, XB = 2, 1                             # pixel del dibujo -> px de pantalla
    hA, wA = alto_en_pantalla(A[0][1], XA)
    hB, wB = alto_en_pantalla(B[0][1], XB)

    celdaA = (AW * XA * Z + 8, AH * XA * Z + 8)
    celdaB = (lya.W * XB * Z + 8, lya.H * XB * Z + 8)
    hoja = Image.new("RGBA", (ANCHO, 4000), FONDO_HOJA + (255,))
    d = ImageDraw.Draw(hoja)
    d.text((M, 34), "Lya: las dos opciones (la B ya está en el juego)", font=fuente(38, True), fill=TEXTO)
    d.text((M, 84), "Negrita, ojos ámbar, tierna y un poco gordita. Las poses van a x4 de su tamaño en pantalla; "
           "abajo de cada una, a tamaño real.", font=fuente(18), fill=TEXTO_SUAVE)
    y = 130

    def seccion(titulo, sub, poses, celda, escala_dibujo, figuras, color_titulo):
        nonlocal y
        sep = 16
        n = len(poses)
        ancho_poses = n * celda[0] + (n - 1) * sep
        alto_t = 92 + celda[1] + 40 + 34 + 150 + 30
        tarjeta(d, M - 16, y, ANCHO - M + 16, y + alto_t)
        d.text((M + 4, y + 18), titulo, font=fuente(30, True), fill=color_titulo)
        d.text((M + 4, y + 58), sub, font=fuente(17), fill=TEXTO_SUAVE)
        x0 = M + 4 + (ANCHO - 2 * M - 8 - ancho_poses) // 2
        fila_poses(hoja, d, x0, y + 92, poses, escala_dibujo, celda[0], celda[1], sep)
        yj = y + 92 + celda[1] + 40
        d.text((M + 4, yj), "En el juego, a tamaño real (x1):", font=fuente(17, True), fill=TEXTO)
        fila_juego(hoja, d, M + 4, yj + 30, ANCHO - 2 * M - 8, 150, figuras)
        y += alto_t + 28

    seccion("Opción A — Lobita chibi",
            f"De frente, cabeza grande y cuerpo cortito. {wA}×{hA} px en pantalla (dibujo de {AW}×{AH} a x2). "
            "Orejotas, cachetes y cola esponjada.",
            A, celdaA, XA * Z, [("A quieta", en_pantalla(A[0][1], XA)),
                                ("A pidiendo", en_pantalla(A[1][1], XA)), ("A dormida", en_pantalla(A[2][1], XA))],
            (255, 214, 120))
    seccion("Opción B — Loba de perfil estilizada",
            f"De perfil, más fina y compacta, con su pañoleta verde de Alfa y el rombo. {wB}×{hB} px en pantalla "
            f"(dibujo de {lya.W}×{lya.H} a x1).",
            B, celdaB, XB * Z, [("B quieta", en_pantalla(B[0][1], XB)),
                                ("B pidiendo", en_pantalla(B[1][1], XB)), ("B corriendo", en_pantalla(B[3][1], XB))],
            VERDE)
    hoja = hoja.crop((0, 0, ANCHO, y)).convert("RGB")
    hoja.save(destino)
    return destino


def hoja_opcion(titulo, poses, x, destino, color):
    """Cada opción suelta: sus poses a x4 de pantalla sobre fondo oscuro y claro."""
    Z = 4
    w0, h0 = poses[0][1][0].size
    cw, ch = w0 * x * Z, h0 * x * Z
    M, sep = 24, 12
    n = len(poses)
    ancho = M * 2 + n * cw + (n - 1) * sep
    alto = 70 + 2 * (ch + sep) + 30
    hoja = Image.new("RGBA", (ancho, alto), FONDO_HOJA + (255,))
    d = ImageDraw.Draw(hoja)
    d.text((M, 18), titulo, font=fuente(28, True), fill=color)
    for j, fondo in enumerate(((20, 26, 30), (206, 212, 214))):
        for i, (nombre, (pelo, borde)) in enumerate(poses):
            cx = M + i * (cw + sep)
            cy = 70 + j * (ch + sep)
            d.rounded_rectangle([cx, cy, cx + cw - 1, cy + ch - 1], radius=8, fill=fondo)
            hoja.alpha_composite(ampliar(componer(pelo, borde), x * Z), (cx, cy))
            if j == 0:
                d.text((cx + 10, cy + 8), nombre, font=fuente(15), fill=(150, 160, 170))
    hoja.convert("RGB").save(destino)


def main():
    salida = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(tempfile.gettempdir()) / "lya-opciones"
    salida.mkdir(parents=True, exist_ok=True)
    A, B = opciones()
    hoja_comparacion(A, B, salida / "comparacion.png")
    hoja_opcion("Opción A — Lobita chibi", A, 2, salida / "opcion-a.png", (255, 214, 120))
    hoja_opcion("Opción B — Loba de perfil estilizada", B, 1, salida / "opcion-b.png", VERDE)
    for nombre, poses, x in (("A", A, 2), ("B", B, 1)):
        h, w = alto_en_pantalla(poses[0][1], x)
        print(f"{nombre}: {w} x {h} px en pantalla (quieta)")
    print("listo:", salida)


if __name__ == "__main__":
    main()
