"""Dibuja a Lya de cuerpo completo en pixel art (toxic3000 / La Jauría). GPL-3.0.

Uso (desde la raíz del proyecto):
  .venv/Scripts/python -I tools/lya_cuerpo.py [carpeta-para-la-hoja-de-muestra]

Lya es la "loba de perfil estilizada" (la opción B de tools/lya_opciones.py):
negra con brillos azulados sutiles, ojos ámbar almendrados y su pañoleta verde
de Alfa (#8be04e) con el rombo. Cada cuadro es pixel art de verdad, de 60 x 54
pixeles (polígonos sin suavizado, sombreado plano con luz de arriba a la
izquierda, una orilla oscura entre lo de enfrente y lo de atrás y contorno
oscuro), y el juego lo muestra a x1: a tamaño 64, un pixel del dibujo = 1 px
de la interfaz, y ella mide unos 57 x 50 parada. La textura guarda cada pixel
una sola vez (sin escalar): con el filtro NEAREST se ve igual de nítida que a
x2 y pesa la cuarta parte.

Las celdas van de izquierda a derecha y de arriba abajo, 17 por fila, en dos
hojas de 1024 x 256 (TGA de 32 bits sin comprimir) en src/Alfa_Lya/Media:
  lya-cuerpo.tga        el pelaje, la pañoleta y la salchicha con sus colores
  lya-cuerpo-borde.tga  en blanco, para teñir con el acento del estilo: un
                        contorno de un pixel por fuera del oscuro (para que la
                        loba negra se lea sobre fondos oscuros) y los adornos
                        (las "z" al dormir, el aullido, el destello de la
                        salchicha, las rayitas al buscarse la cola)
Todas miran a la derecha; el juego las voltea con SetTexCoord. Las patas
tocan el suelo en la fila PIES (el contorno de abajo de las patas).

El orden de las celdas (ORDEN) es el mismo que ORDEN en src/Alfa_Lya/Lya.lua
(main() lo compara y se niega a escribir si no cuadra).
"""
import math
import pathlib
import re
import sys

from PIL import Image, ImageChops, ImageDraw

RAIZ = pathlib.Path(__file__).resolve().parent.parent
AQUI = RAIZ / "src" / "Alfa_Lya" / "Media"
LUA = RAIZ / "src" / "Alfa_Lya" / "Lya.lua"

W, H = 60, 54                    # el cuadro, en pixeles del dibujo (y de la textura)
HOJA_W, HOJA_H = 1024, 256
COLS = HOJA_W // W               # 17
PIES = 51                        # la fila del suelo: el contorno bajo las patas

# ---------------------------------------------------------------------------
# Colores
# ---------------------------------------------------------------------------
VERDE = (139, 224, 78)          # #8be04e, el acento de Alfa
VERDE_CLARO = (196, 246, 150)
VERDE_OSCURO = (78, 150, 40)
VERDE_LINEA = (36, 74, 22)
CONTORNO = (9, 9, 13)
OJO = (246, 186, 70)            # ámbar
OJO_CLARO = (255, 222, 132)
OJO_OSCURO = (196, 120, 34)
BRILLO_OJO = (255, 251, 236)
PUPILA = (52, 28, 10)
PARPADO = (122, 134, 162)       # el ojo cerrado: una rayita clara
OREJA = (96, 62, 80)
NARIZ = (4, 4, 6)
NARIZ_BRILLO = (110, 118, 140)
LENGUA = (238, 118, 140)
LENGUA_SOMBRA = (192, 80, 104)
BOCA = (58, 16, 26)
POLVO = (168, 160, 146)

# negro con brillos azulados (cerca) y un tono más oscuro (lo del otro lado)
PIEL = {"base": (26, 29, 39), "medio": (34, 39, 54), "luz": (58, 72, 104), "brillo": (88, 112, 160),
        "sombra": (16, 18, 25), "linea": (10, 11, 16)}
PIEL_LEJOS = {"base": (19, 21, 29), "medio": (23, 26, 35), "luz": (34, 40, 56), "brillo": (40, 48, 68),
              "sombra": (13, 14, 19), "linea": (9, 10, 14)}
TELA = {"base": VERDE, "medio": (150, 230, 92), "luz": VERDE_CLARO, "brillo": VERDE_CLARO,
        "sombra": VERDE_OSCURO, "linea": VERDE_LINEA}

# Capas, de lejos a cerca: una orilla oscura separa lo de enfrente de lo de
# atrás (menos las patas de este lado, que salen del cuerpo).
LEJANA, CUERPO, COLA, PATA, FRENTE, CAPA_TELA, CABEZA = 1, 2, 3, 4, 5, 6, 7


# ---------------------------------------------------------------------------
# Geometría y lienzo
# ---------------------------------------------------------------------------
def girar(pts, ang, cx=0.0, cy=0.0):
    """Gira en grados (positivo = como las manecillas en pantalla)."""
    a = math.radians(ang)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


def elipse_pts(cx, cy, rx, ry, ang=0.0, n=32):
    pts = [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]
    return girar(pts, ang, cx, cy) if ang else pts


def _medio(pts):
    return [(round(x * 2) / 2, round(y * 2) / 2) for x, y in pts]


class Lienzo:
    """Un cuadro: un mapa de capas y sus detalles; pintar() da (pelaje, borde)."""

    def __init__(self, w=W, h=H):
        self.w, self.h = w, h
        self.capa = Image.new("L", (w, h), 0)
        self.d = ImageDraw.Draw(self.capa)
        self.detalles = {}
        self.tinte = set()
        self.polvo = {}
        self.orejas = []
        self.objetos = []      # (imagen RGBA, x, y): la salchicha, encima de todo

    def poli(self, pts, capa):
        self.d.polygon(_medio(pts), fill=capa)

    def elipse(self, cx, cy, rx, ry, capa, ang=0.0):
        self.poli(elipse_pts(cx, cy, rx, ry, ang), capa)

    def trazo(self, pts, anchos, capa):
        """Una línea gruesa que se adelgaza (colas, patas)."""
        for (x0, y0), (x1, y1), w0, w1 in zip(pts, pts[1:], anchos, anchos[1:]):
            dx, dy = x1 - x0, y1 - y0
            ln = math.hypot(dx, dy) or 1
            nx, ny = -dy / ln, dx / ln
            self.poli([(x0 + nx * w0 / 2, y0 + ny * w0 / 2), (x1 + nx * w1 / 2, y1 + ny * w1 / 2),
                       (x1 - nx * w1 / 2, y1 - ny * w1 / 2), (x0 - nx * w0 / 2, y0 - ny * w0 / 2)], capa)
        for (x, y), w in zip(pts, anchos):
            if w >= 2.4:
                self.elipse(x, y, w / 2, w / 2, capa)

    def espejar(self, eje2):
        """Copia la mitad izquierda sobre la derecha (x' = eje2 - 1 - x)."""
        c = self.capa.load()
        for y in range(self.h):
            for x in range(self.w):
                x2 = eje2 - 1 - x
                if x < x2 and 0 <= x2 < self.w:
                    c[x2, y] = c[x, y]

    def encima(self, dibujar):
        """Dibuja en una capa aparte y la funde: en cada pixel gana la capa más cercana."""
        viejo = self.capa
        self.capa = Image.new("L", (self.w, self.h), 0)
        self.d = ImageDraw.Draw(self.capa)
        dibujar()
        self.capa = ImageChops.lighter(viejo, self.capa)
        self.d = ImageDraw.Draw(self.capa)

    def debajo(self, dibujar):
        """Dibuja en una capa aparte y la pone detrás de lo que ya hay."""
        viejo = self.capa
        self.capa = Image.new("L", (self.w, self.h), 0)
        self.d = ImageDraw.Draw(self.capa)
        dibujar()
        self.capa = Image.composite(viejo, self.capa, viejo.point(lambda v: 255 if v else 0))
        self.d = ImageDraw.Draw(self.capa)

    def punto(self, x, y, color):
        self.detalles[(int(round(x)), int(round(y)))] = color

    def relleno(self, pts, color):
        """Los pixeles de un polígono, de un color (encima del sombreado)."""
        m = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(m).polygon(_medio(pts), fill=1)
        mm = m.load()
        for y in range(self.h):
            for x in range(self.w):
                if mm[x, y]:
                    self.detalles[(x, y)] = color

    def dibujo(self, x0, y0, filas, color=None):
        """Filas de '#': en la capa que se tiñe (o del color dado, encima)."""
        for j, fila in enumerate(filas):
            for i, ch in enumerate(fila):
                if ch == "#":
                    if color:
                        self.detalles[(x0 + i, y0 + j)] = color
                    else:
                        self.tinte.add((x0 + i, y0 + j))

    def pintar(self, cerca=PIEL, lejos=PIEL_LEJOS, tela=TELA):
        """-> (pelaje RGBA, borde RGBA) del tamaño del lienzo."""
        Wl, Hl = self.w, self.h
        c = self.capa.load()

        def k(x, y):
            return c[x, y] if 0 <= x < Wl and 0 <= y < Hl else 0

        pelo = Image.new("RGBA", (Wl, Hl), (0, 0, 0, 0))
        p = pelo.load()
        for y in range(Hl):
            for x in range(Wl):
                v = k(x, y)
                if not v:
                    continue
                pal = lejos if v == LEJANA else (tela if v == CAPA_TELA else cerca)
                arriba, abajo = k(x, y - 1), k(x, y + 1)
                vec = (k(x - 1, y), k(x + 1, y), arriba, abajo)
                if any(n > v and not (v == CUERPO and n == PATA) for n in vec):
                    col = pal["linea"]          # junto a algo que está más cerca
                elif abajo < v and not (v == PATA and abajo == CUERPO):
                    col = pal["sombra"]
                elif arriba == 0 or (arriba < v and v != PATA):
                    col = pal["brillo"] if arriba == 0 and v != LEJANA else pal["luz"]
                elif k(x, y - 2) == 0 and v != LEJANA:
                    col = pal["luz"]
                elif (k(x, y - 3) == 0 or k(x - 1, y) == 0) and v != LEJANA:
                    col = pal["medio"]          # la luz viene de arriba a la izquierda
                elif k(x + 1, y) < v and k(x + 1, y + 1) < v:
                    col = pal["sombra"]
                else:
                    col = pal["base"]
                p[x, y] = col + (255,)
        # contorno oscuro por fuera (4 vecinos) y, un pixel más afuera, el borde que se tiñe
        borde = Image.new("RGBA", (Wl, Hl), (255, 255, 255, 0))
        b = borde.load()
        contorno = set()
        for y in range(Hl):
            for x in range(Wl):
                if not k(x, y) and (k(x - 1, y) or k(x + 1, y) or k(x, y - 1) or k(x, y + 1)):
                    p[x, y] = CONTORNO + (255,)
                    contorno.add((x, y))
        for y in range(Hl):
            for x in range(Wl):
                if k(x, y) or (x, y) in contorno:
                    continue
                if any((x + dx, y + dy) in contorno for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    b[x, y] = (255, 255, 255, 255)
        for tri in self.orejas:
            m = Image.new("L", (Wl, Hl), 0)
            ImageDraw.Draw(m).polygon(_medio(tri), fill=1)
            mm = m.load()
            for y in range(Hl):
                for x in range(Wl):
                    if mm[x, y] and k(x, y) == CABEZA and p[x, y][:3] != cerca["linea"]:
                        p[x, y] = OREJA + (255,)
        for (x, y), col in self.detalles.items():
            if 0 <= x < Wl and 0 <= y < Hl:
                p[x, y] = col + (255,)
                if not k(x, y):
                    b[x, y] = (255, 255, 255, 0)      # la lengua de fuera tapa el borde
        for (x, y), a in self.polvo.items():
            if 0 <= x < Wl and 0 <= y < Hl and not k(x, y) and (x, y) not in contorno:
                p[x, y] = POLVO + (a,)
        for (x, y) in self.tinte:
            if 0 <= x < Wl and 0 <= y < Hl and not k(x, y) and (x, y) not in contorno:
                b[x, y] = (255, 255, 255, 255)
        for im, ox, oy in self.objetos:
            pelo.alpha_composite(im, (ox, oy))
            # el objeto tapa el borde teñido que quede debajo
            mask = Image.new("L", borde.size, 0)
            mask.paste(im.getchannel("A"), (ox, oy))
            borde.paste(Image.new("RGBA", borde.size, (255, 255, 255, 0)), (0, 0), mask)
        return pelo, borde


def salchicha(largo, grueso, ang=0):
    """Una salchicha de pixel art (RGBA) con su contorno, amarrada en las puntas."""
    S = 4
    w, h = largo + 4, grueso + 4
    m = Image.new("L", (w * S, h * S), 0)
    ImageDraw.Draw(m).rounded_rectangle([2 * S, 2 * S, (2 + largo) * S - 1, (2 + grueso) * S - 1],
                                        radius=grueso / 2 * S, fill=1)
    m = m.resize((w, h), Image.NEAREST)
    if ang:
        m = m.rotate(ang, resample=Image.NEAREST, expand=True)
    w, h = m.size
    mm = m.load()
    im = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    p = im.load()

    def k(x, y):
        return mm[x, y] if 0 <= x < w and 0 <= y < h else 0
    for y in range(h):
        for x in range(w):
            if not k(x, y):
                if k(x - 1, y) or k(x + 1, y) or k(x, y - 1) or k(x, y + 1):
                    p[x + 1, y + 1] = (64, 22, 14, 255)
                continue
            if not k(x, y - 1):
                col = (240, 152, 102)
            elif not k(x, y + 1):
                col = (140, 58, 36)
            elif not k(x, y - 2):
                col = (214, 112, 70)
            else:
                col = (188, 86, 52)
            p[x + 1, y + 1] = col + (255,)
    # brillito y las amarras de las puntas
    xs = [x for y in range(h) for x in range(w) if k(x, y)]
    ys = [y for y in range(h) for x in range(w) if k(x, y)]
    if xs:
        x0, x1 = min(xs), max(xs)
        y0, y1 = min(ys), max(ys)
        p[x0 + 1 + 2, y0 + 1 + 1] = (255, 214, 176, 255)
        if largo >= 9:
            p[x0 + 1 + 3, y0 + 1 + 1] = (255, 214, 176, 255)
        for x in (x0 - 1, x1 + 1):
            yy = (y0 + y1) // 2 + 1
            if 0 <= x + 1 < im.width:
                p[x + 1, yy] = (110, 44, 26, 255)
    return im


# ---------------------------------------------------------------------------
# La cabeza de perfil y la pañoleta
# ---------------------------------------------------------------------------
OREJAS = {  # (la oreja, lo de dentro), en coordenadas de la cabeza
    "arriba": ([(-5.2, -3.0), (1.0, -4.8), (-2.6, -11.6)], [(-3.8, -3.8), (-0.2, -4.8), (-2.4, -9.2)]),
    "atentas": ([(-4.6, -3.2), (1.6, -4.8), (-0.6, -12.6)], [(-3.2, -4.0), (0.6, -4.8), (-0.8, -10.2)]),
    "atras": ([(-4.6, -2.8), (0.6, -4.8), (-9.0, -8.4)], [(-3.8, -3.4), (-0.6, -4.6), (-7.2, -7.2)]),
}


def cabeza(lo, cx, cy, giro=0.0, ojos="abiertos", boca="cerrada", orejas="arriba", espejo=False):
    """La cabeza de perfil mirando a la derecha (espejo: a la izquierda), centrada en el cráneo.

    giro en grados (negativo = la nariz hacia arriba); ojos: abiertos, brillosos,
    cerrados; boca: cerrada, lengua, aullido, bostezo; orejas: ver OREJAS."""
    sx = -1 if espejo else 1

    def t(pts):
        return [(cx + sx * x, cy + y) for x, y in girar(pts, giro)]

    def tp(x, y):
        return t([(x, y)])[0]

    oreja, dentro = OREJAS[orejas]
    lo.poli(t([(x + 3.2, y + 0.8) for x, y in oreja]), LEJANA)
    lo.poli(t(elipse_pts(0, 0, 6.4, 5.4)), CABEZA)
    lo.poli(t(elipse_pts(-0.6, 2.4, 5.8, 3.8)), CABEZA)
    # el pelo de los cachetes, hacia atrás
    lo.poli(t([(-4.6, 0.0), (-9.0, 5.4), (-3.0, 4.8)]), CABEZA)
    abierta = boca in ("aullido", "bostezo")
    if abierta:
        ang = 32 if boca == "aullido" else 36
        bisagra = (3.6, 3.0)
        lo.poli(t([(3.0, -2.6), (10.6, -0.6), (11.8, 0.9), (10.8, 2.0), (3.8, 2.4)]), CABEZA)   # arriba
        quij = girar([(3.4, 2.6), (9.8, 2.4), (10.2, 3.4), (9.0, 4.4), (3.8, 5.0)], ang, *bisagra)
        lo.poli(t(quij), CABEZA)                                                            # la quijada
        dentro_boca = [(3.6, 2.2), (10.4, 1.8), quij[1], (3.4, 3.2)]
        lo.poli(t(dentro_boca), CABEZA)
        lo.relleno(t([(4.2, 2.6), (10.0, 2.2), girar([(9.2, 2.6)], ang, *bisagra)[0], (4.2, 3.0)]), BOCA)
        if boca == "bostezo":   # la lengua enroscada en la quijada
            for x, y, col in ((6.0, 3.0, LENGUA), (7.2, 3.0, LENGUA), (8.2, 2.9, LENGUA_SOMBRA)):
                lo.punto(*t(girar([(x, y)], ang, *bisagra))[0], col)
    else:
        lo.poli(t([(3.0, -2.6), (10.6, -0.6), (11.8, 1.2), (10.8, 3.0), (3.8, 4.8)]), CABEZA)
    lo.poli(t(oreja), CABEZA)
    if giro > -30:             # con la nariz al cielo, la oreja se ve por detrás
        lo.orejas.append(t(dentro))
    # ojo almendrado (3 x 2) con su brillo hacia el frente
    ox, oy = tp(3.6, -1.2)
    ex, ey = int(round(ox)), int(round(oy))

    def ojo(dx, dy, col):
        lo.punto(ex + sx * dx, ey + dy, col)
    if ojos in ("abiertos", "brillosos"):
        ojo(-1, 0, OJO_OSCURO)
        ojo(0, 0, OJO)
        ojo(1, 0, BRILLO_OJO)
        ojo(-1, 1, OJO)
        ojo(0, 1, PUPILA)
        ojo(1, 1, OJO_CLARO)
        for d in (-1, 0, 1):
            ojo(d, -1, PIEL["linea"])
        if ojos == "brillosos":      # pidiendo: la pupila grande y dos brillos
            ojo(-1, 0, BRILLO_OJO)
            ojo(-1, 1, PUPILA)
    else:
        ojo(-1, 1, PARPADO)
        ojo(0, 1, PARPADO)
        ojo(1, 1, PARPADO)
        ojo(2, 0, PARPADO)
    # la nariz
    for x, y, col in ((11.2, 0.6, NARIZ), (10.2, 0.6, NARIZ), (11.2, 1.6, NARIZ), (10.2, 1.6, NARIZ),
                      (10.2, -0.3, NARIZ_BRILLO)):
        lo.punto(*tp(x, y), col)
    if not abierta:
        for i in range(4):
            lo.punto(*tp(6.0 + i, 3.3 - i * 0.3), PIEL["linea"])
    if boca == "lengua":
        lo.punto(*tp(6.8, 4.6), LENGUA)
        lo.punto(*tp(7.8, 4.4), LENGUA)
        lo.punto(*tp(6.8, 5.6), LENGUA)
        lo.punto(*tp(7.8, 5.4), LENGUA_SOMBRA)
        lo.punto(*tp(7.0, 6.4), LENGUA_SOMBRA)
    return tp


def panoleta(lo, nuca, garganta, punta, rombo=True, nudo=(0.0, 0.0)):
    """La pañoleta verde: la banda del cuello, el nudo en la nuca y el triángulo
    sobre el pecho con el rombo de Alfa. nudo = (dx, dy) para que ondee."""
    (nx, ny), (gx, gy) = nuca, garganta
    lo.trazo([(nx, ny), (gx, gy)], [3.6, 3.6], CAPA_TELA)
    ndx, ndy = nudo
    lo.poli([(nx - 0.4, ny - 0.4), (nx - 4.2 + ndx, ny + 2.4 + ndy), (nx - 2.0 + ndx * 0.6, ny + 4.2 + ndy)], CAPA_TELA)
    if punta is None:          # solo la banda y el nudo (dormida)
        return
    px, py = punta
    tri = [(gx - 7.4, gy - 1.6), (gx + 2.0, gy + 0.6), (px, py)]
    lo.poli(tri, CAPA_TELA)
    if rombo:
        rx = int(round((tri[0][0] + tri[1][0] + tri[2][0]) / 3))
        ry = int(round((tri[0][1] + tri[1][1] + tri[2][1]) / 3)) - 1
        rombo_en(lo, rx, ry)


def rombo_en(lo, rx, ry):
    """El rombo de Alfa (5 x 5 claro, con su orilla oscura) centrado en (rx, ry)."""
    for dy, ancho in ((-3, 0), (-2, 1), (-1, 2), (0, 3), (1, 2), (2, 1), (3, 0)):
        for dx in range(-ancho, ancho + 1):
            lo.punto(rx + dx, ry + dy, (246, 255, 230) if abs(dx) + abs(dy) <= 2 else VERDE_LINEA)
    lo.punto(rx - 1, ry - 1, (255, 255, 255))


# ---------------------------------------------------------------------------
# Las partes del cuerpo
# ---------------------------------------------------------------------------
def pie(lo, x, y, capa, cerca=True, ang=0.0):
    """La patita: un óvalo un poco hacia el frente de donde acaba la pata."""
    lo.elipse(x + 1.3, y + 0.4, 2.5 if cerca else 2.3, 1.3 if cerca else 1.2, capa, ang=ang)


def pierna(lo, cadera, a1, a2, l1, l2, anchos, capa, cerca=True, con_pie=True):
    """Una pata en dos tramos desde la cadera; ángulos en grados desde la vertical
    (positivo = hacia adelante). Devuelve dónde acaba."""
    hx, hy = cadera
    kx, ky = hx + math.sin(math.radians(a1)) * l1, hy + math.cos(math.radians(a1)) * l1
    px_, py_ = kx + math.sin(math.radians(a2)) * l2, ky + math.cos(math.radians(a2)) * l2
    lo.trazo([(hx, hy), (kx, ky), (px_, py_)], anchos, capa)
    if con_pie:
        # la planta queda perpendicular a la caña (y los dedos hacia adelante)
        a = math.radians(a2)
        fx, fy = px_ + math.cos(a) * 1.2, py_ - math.sin(a) * 1.2
        lo.elipse(fx, fy + 0.3, 2.5 if cerca else 2.3, 1.3 if cerca else 1.2, capa, ang=-a2)
    return px_, py_


def cola(lo, base, puntos, anchos, capa=COLA, giro=0.0):
    bx, by = base
    lo.trazo([(bx + x, by + y) for x, y in girar(puntos, giro)], anchos, capa)


COLA_COLGADA = ([(0, 0), (-3.2, 2.4), (-5.0, 6.6), (-5.2, 11.2), (-4.0, 15.0)], [4.2, 6.0, 6.4, 5.2, 2.6])
COLA_ALTA = ([(0, 0), (-3.8, -0.8), (-6.8, -3.4), (-8.0, -7.0), (-7.0, -10.4)], [4.2, 5.8, 6.2, 5.0, 2.6])
COLA_SUELO = ([(0, 0), (-4.6, 0.8), (-8.6, -0.6), (-10.8, -4.0), (-10.6, -7.0)], [4.6, 6.2, 6.4, 5.0, 2.6])


# ---------------------------------------------------------------------------
# Poses
# ---------------------------------------------------------------------------
def parada(cola_giro=0.0, ojos="abiertos", boca="cerrada", orejas="arriba", resp=0.0, cab_dy=0.0,
           cab_giro=0.0, bajar=0.0, alta=False):
    """De pie, de perfil. resp (0 a 1) respira; bajar (px) se agacha doblando las patas."""
    lo = Lienzo()
    b = bajar
    r = resp
    # las patas del otro lado
    lo.trazo([(39.6, 36.0 + b), (40.4 + b * 0.9, 42.2 + b * 0.5), (40.2, 48.4)], [4.0, 3.4, 3.0], LEJANA)
    pie(lo, 40.2, 48.4, LEJANA, cerca=False)
    lo.trazo([(21.6, 36.0 + b), (20.2 - b * 0.6, 42.6 + b * 0.4), (21.4, 48.4)], [4.8, 3.2, 2.8], LEJANA)
    pie(lo, 21.4, 48.4, LEJANA, cerca=False)
    # el cuerpo: anca, panza (un poco gordita), pecho y cuello; respira hacia arriba
    lo.elipse(19.6, 32.0 + b - r * 0.4, 7.2, 7.4 + r * 0.4, CUERPO)
    lo.elipse(28.6, 33.2 + b - r * 0.6, 10.4, 6.8 + r * 0.6, CUERPO)
    lo.elipse(38.4, 32.0 + b - r * 0.5, 6.8, 8.0 + r * 0.5, CUERPO)
    hy = 16.6 + cab_dy + b * 0.9 - r * 0.5
    lo.poli([(33.6, 28.0 + b), (38.6, 17.6 + b * 0.9 + cab_dy), (46.0, 20.4 + b * 0.9 + cab_dy), (45.0, 32.0 + b)], CUERPO)
    # la cola
    forma = COLA_ALTA if alta else COLA_COLGADA
    cola(lo, (13.6, 28.4 + b - (0.8 if alta else 0)), *forma, giro=cola_giro)
    # las patas de este lado
    lo.trazo([(37.2, 37.0 + b), (37.0 + b * 0.9, 42.6 + b * 0.5), (37.8, 48.4)], [4.6, 3.9, 3.4], PATA)
    pie(lo, 37.8, 48.4, PATA)
    lo.trazo([(17.8, 36.4 + b), (15.4 - b * 0.6, 42.6 + b * 0.4), (16.8, 48.4)], [5.8, 3.6, 3.2], PATA)
    pie(lo, 16.8, 48.4, PATA)
    panoleta(lo, (38.0, 22.6 + b * 0.9 + cab_dy - r * 0.3), (45.2, 26.0 + b * 0.9 + cab_dy - r * 0.3),
             (42.6, 35.4 + b - r * 0.5))
    cabeza(lo, 45.0, hy, giro=cab_giro, ojos=ojos, boca=boca, orejas=orejas)
    return lo


def sentada(ojos="abiertos", boca="cerrada", orejas="arriba", resp=0.0, cola_giro=0.0, manos="abajo",
            fase=0, cab=(41.4, 16.6), giro=0.0):
    """Sentada, derechita. manos: abajo, una (una mano arriba) o dos (sentada pidiendo)."""
    lo = Lienzo()
    r = resp
    erguida = manos == "dos"
    up = 2.0 if erguida else 0.0          # sentada pidiendo: el pecho más alto
    if manos != "dos":
        lo.trazo([(37.6, 39.0), (38.0, 48.4)], [4.0, 3.0], LEJANA)
        pie(lo, 38.0, 48.4, LEJANA, cerca=False)
    else:   # la otra mano, doblada, detrás de la de enfrente
        lo.trazo([(37.0, 33.4 - fase * 0.5), (41.6, 32.4 - fase), (43.0, 29.4 - fase)], [3.6, 3.2, 2.8], LEJANA)
        lo.elipse(43.6, 28.8 - fase, 2.0, 1.6, LEJANA)
    # el anca en el suelo, la espalda recta y el pecho alto
    lo.elipse(26.4, 43.2 - r * 0.3, 8.2, 6.6 + r * 0.3, CUERPO)
    lo.elipse(30.4 + (1.0 if erguida else 0), 37.0 - up - r * 0.4, 7.0, 8.4 + r * 0.4, CUERPO, ang=14 - (8 if erguida else 0))
    lo.elipse(34.6, 33.4 - up - r * 0.5, 6.2, 7.4 + r * 0.3, CUERPO)
    lo.poli([(29.6, 29.0 - up), (34.6, 18.6 - up), (42.0, 20.4 - up), (40.6, 33.0 - up)], CUERPO)
    # la cola en el suelo, hacia atrás, con la punta que se mueve
    cola(lo, (20.0, 46.6), *COLA_SUELO, giro=cola_giro)
    lo.elipse(32.0, 48.6, 4.4, 1.6, PATA)                          # la pata de atrás
    if manos == "abajo":
        lo.trazo([(36.2, 37.0), (36.6, 42.8), (36.8, 48.4)], [4.6, 3.9, 3.4], FRENTE)
        pie(lo, 36.8, 48.4, FRENTE)
    elif manos == "una":   # la mano levantada, doblada
        lo.trazo([(36.0, 37.4), (42.4, 36.0 - fase), (46.4, 32.6 - fase)], [4.2, 3.6, 3.2], FRENTE)
        lo.elipse(47.2, 32.0 - fase, 2.4, 1.8, FRENTE)
    else:                  # las dos manitas dobladas frente al pecho
        lo.trazo([(35.6, 34.6 - fase * 0.5), (40.6, 34.0 - fase), (42.0, 30.8 - fase)], [4.2, 3.6, 3.2], FRENTE)
        lo.elipse(42.4, 30.2 - fase, 2.2, 1.8, FRENTE)
    panoleta(lo, (34.0, 23.4 - up - r * 0.3), (41.0, 26.4 - up - r * 0.3), (38.6, 35.2 - up - r * 0.5))
    cabeza(lo, cab[0], cab[1] - r * 0.5, giro=giro, ojos=ojos, boca=boca, orejas=orejas)
    return lo


# El galope y los saltos: el cuerpo largo, con las cuatro patas en dos tramos.
# Cada pata: (muslo, caña) en grados desde la vertical (positivo = adelante).
GALOPE = [
    # bob, inclinación, estirar, mano cerca, mano lejos, pata cerca, pata lejos
    (-1.2, 0, 1.2, (62, 82), (50, 66), (-58, -78), (-46, -64)),      # 1 estirada en el aire
    (0.0, 3, 0.6, (24, 8), (44, 58), (-14, -58), (-36, -72)),        # 2 caen las manos
    (0.6, 2, 0.0, (-22, -30), (6, 0), (28, -24), (12, -44)),         # 3 empujan las manos
    (-1.4, -2, -1.4, (-12, -52), (-4, -40), (40, 2), (30, -6)),      # 4 recogida en el aire
    (0.0, -4, -0.6, (-4, -62), (-28, -92), (30, 4), (46, 16)),       # 5 caen las patas
    (0.4, -2, 0.6, (36, 42), (20, 14), (-30, -42), (4, -4)),         # 6 empujan las patas
]


def galope(bob, incl, estirar, mc, ml, pc, pl, cola_giro=0.0, orejas="atras", boca="lengua", ojos="abiertos",
           cab_giro=8.0, nudo=(0.0, 0.0), arco=0.0, dx=-0.6):
    lo = Lienzo()
    centro = (29.0 + dx, 32.0)
    e = estirar

    def T(x, y):
        (x2, y2), = girar([(x + dx, y + bob)], incl, centro[0], centro[1] + bob)
        return x2, y2

    hombro = T(37.0 + e * 0.5, 34.6)
    cadera = T(19.6 - e * 0.5, 34.8)
    # las patas del otro lado
    pierna(lo, (hombro[0] + 1.6, hombro[1] - 0.4), ml[0], ml[1], 6.0, 6.6, [3.8, 3.2, 2.8], LEJANA, cerca=False)
    pierna(lo, (cadera[0] + 2.2, cadera[1] - 0.6), pl[0], pl[1], 6.4, 6.6, [4.8, 3.2, 2.8], LEJANA, cerca=False)
    # la cola al viento
    bx, by = T(14.4 - e * 0.5, 28.4)
    cola(lo, (bx, by), [(0, 0), (-3.6, -1.8), (-6.8, -2.0), (-8.8, -0.6)], [4.2, 5.6, 5.0, 2.6],
         giro=cola_giro + incl)
    # el cuerpo
    for (x, y, rx, ry) in ((20.4 - e * 0.5, 31.2 - arco * 0.4, 6.8, 6.4), (28.4, 31.4 - arco, 9.8 + e * 0.5, 6.0),
                           (36.6 + e * 0.5, 30.0 - arco * 0.4, 6.6, 7.0)):
        lo.elipse(*T(x, y), rx, ry, CUERPO, ang=incl - 4)
    cuello = [T(33.2 + e * 0.5, 26.0), T(39.0 + e * 0.5, 17.6), T(45.4 + e * 0.5, 21.0), T(42.4 + e * 0.5, 31.0)]
    lo.poli(cuello, CUERPO)
    # las patas de este lado
    pierna(lo, hombro, mc[0], mc[1], 6.0, 6.8, [4.6, 3.6, 3.2], PATA)
    pierna(lo, cadera, pc[0], pc[1], 6.4, 6.8, [5.8, 3.8, 3.2], PATA)
    panoleta(lo, T(37.8 + e * 0.5, 23.8), T(44.4 + e * 0.5, 27.2), T(40.4 + e * 0.5, 35.4), nudo=nudo)
    cabeza(lo, *T(44.6 + e * 0.5, 17.8), giro=cab_giro + incl, ojos=ojos, boca=boca, orejas=orejas)
    return lo


def correr(i):
    bob, incl, est, mc, ml, pc, pl = GALOPE[i]
    ondea = ((-1.6, -0.6), (-1.0, 0.4), (-0.4, 0.8), (-1.8, -1.0), (-1.2, 0.2), (-0.6, 0.6))[i]
    lo = galope(bob, incl, est, mc, ml, pc, pl, cola_giro=(-6, 2, 8, -2, 4, 10)[i], nudo=ondea,
                arco=1.0 if i == 3 else 0.0)
    # polvito detrás de las patas cuando empujan
    if i in (5, 0):
        dx = 0 if i == 5 else -2
        for ddx, ddy, al in ((0, 0, 150), (-3, -1, 110), (-5, 1, 90), (2, 1, 100)):
            lo.polvo[(8 + dx + ddx, PIES - 1 + ddy)] = al
    return lo


def saltar(fase):
    if fase == 0:   # agacharse: las patas dobladas, la cola arriba y las orejas al frente
        return parada(bajar=2.2, orejas="atentas", cab_dy=1.0, cab_giro=4, alta=True, cola_giro=4)
    if fase == 1:   # en el aire: la nariz arriba, las manos recogidas y las patas estiradas
        return galope(-2.0, -12, 0.8, (74, -36), (62, -46), (-54, -84), (-44, -74), cola_giro=14,
                      cab_giro=0, nudo=(-1.6, -0.8))
    # cayendo: la nariz abajo, las manos por delante para el suelo y las patas atrás
    return galope(-0.6, 7, 0.4, (20, 6), (30, 18), (-42, -66), (-30, -54), cola_giro=-10,
                  orejas="arriba", boca="cerrada", cab_giro=-2, nudo=(-0.6, -1.2), dx=-1.4)


def reverencia(ojos="abiertos", boca="cerrada", hondo=0.0, orejas="arriba"):
    """Estirarse: el pecho al suelo, las manos adelante y el anca arriba."""
    lo = Lienzo()
    h = hondo
    # las patas del otro lado
    lo.trazo([(21.6, 33.0), (20.6, 41.2), (21.4, 48.4)], [4.8, 3.2, 2.8], LEJANA)
    pie(lo, 21.4, 48.4, LEJANA, cerca=False)
    lo.trazo([(37.8, 42.4 + h), (42.8, 46.4), (48.4, 47.4)], [3.8, 3.2, 2.8], LEJANA)
    lo.elipse(49.2, 47.6, 2.3, 1.2, LEJANA)
    # la cola arriba
    cola(lo, (13.4, 24.4), *COLA_ALTA, giro=8 + h * 4)
    # el cuerpo inclinado: el anca alta y el pecho abajo
    lo.elipse(19.4, 28.6, 7.0, 7.2, CUERPO)
    lo.elipse(28.4, 33.4 + h * 0.5, 10.4, 6.0, CUERPO, ang=20 + h * 2)
    lo.elipse(37.4, 39.6 + h, 6.4, 5.6, CUERPO)
    lo.poli([(35.6, 35.6 + h), (41.0, 30.4 + h), (47.8, 33.8 + h), (45.0, 43.0 + h)], CUERPO)
    # las patas de este lado: la de atrás derecha y la mano estirada en el suelo
    lo.trazo([(17.6, 32.4), (15.6, 41.0), (16.8, 48.4)], [5.8, 3.6, 3.2], PATA)
    pie(lo, 16.8, 48.4, PATA)
    lo.trazo([(36.6, 43.4 + h), (42.2, 47.4), (47.8, 48.2)], [4.6, 3.6, 3.2], PATA)
    lo.elipse(48.8, 48.6, 2.5, 1.3, PATA)
    panoleta(lo, (39.8, 33.4 + h), (46.0, 37.8 + h), (42.4, 45.4 + h * 0.5))
    cabeza(lo, 45.6, 33.6 + h, giro=-8 - h * 4, ojos=ojos, boca=boca, orejas=orejas)
    return lo


def dormir(resp=0.0):
    """Enroscada: el lomo redondo, la cola por delante y la cabeza recostada encima."""
    lo = Lienzo()
    dy = -2.6
    r = resp
    lo.elipse(17.0, 43.0 + dy - r * 0.5, 8.0, 7.0 + r * 0.4, CUERPO)
    lo.elipse(27.0, 44.4 + dy - r * 0.4, 12.4, 5.6 + r * 0.4, CUERPO)
    # la cola enroscada por delante, hasta la nariz
    lo.trazo([(10.4, 45.0 + dy), (12.6, 49.0 + dy), (22.0, 50.2 + dy), (33.0, 50.0 + dy), (41.0, 49.2 + dy),
              (47.6, 47.6 + dy)], [4.4, 5.6, 6.0, 5.6, 4.6, 2.8], FRENTE)
    panoleta(lo, (31.6, 38.2 + dy - r * 0.3), (34.6, 45.4 + dy), None, nudo=(1.0, -0.6))
    cabeza(lo, 40.0, 40.0 + dy - r * 0.3, giro=16, ojos="cerrados", orejas="arriba")
    return lo


def ondas(lo, x0, y0, radios, rumbo, abre=42):
    """Arcos que salen de (x0, y0) hacia el rumbo (grados; -90 = arriba), en la capa que se tiñe."""
    for r in radios:
        vistos = set()
        for i in range(41):
            a = math.radians(rumbo - abre + 2 * abre * i / 40)
            vistos.add((int(round(x0 + r * math.cos(a))), int(round(y0 + r * math.sin(a)))))
        lo.tinte.update(vistos)


def aullar(abre=0):
    cx, cy, giro = 40.4, 18.4 - abre * 0.6, -40 - 6 * abre
    lo = sentada(ojos="cerrados", boca="aullido", orejas="arriba", cab=(cx, cy), giro=giro, cola_giro=6 * abre)
    # las ondas del aullido (se tiñen): arcos que salen de la boca
    (nx, ny), = girar([(12.4, 1.6)], giro)
    ondas(lo, cx + nx, cy + ny, (5, 8) if not abre else (5, 8, 11), giro, abre=36)
    return lo


# ---------------------------------------------------------------------------
# Buscarse la cola: de lado, de espaldas, del otro lado y de frente
# ---------------------------------------------------------------------------
def cola_lado(paso=0):
    """De perfil, la cabeza vuelta hacia atrás y la cola arriba, hacia la boca."""
    lo = Lienzo()
    s = 1 if paso else -1
    lo.trazo([(39.6, 36.0), (40.6 + s, 42.2), (40.2 + s * 1.6, 48.4)], [4.0, 3.4, 3.0], LEJANA)
    pie(lo, 40.2 + s * 1.6, 48.4, LEJANA, cerca=False)
    lo.trazo([(21.6, 36.0), (20.2, 42.6), (21.4 - s * 1.6, 48.4)], [4.8, 3.2, 2.8], LEJANA)
    pie(lo, 21.4 - s * 1.6, 48.4, LEJANA, cerca=False)
    lo.elipse(19.6, 32.4, 7.2, 7.4, CUERPO)
    lo.elipse(28.6, 33.4, 10.4, 6.6, CUERPO)
    lo.elipse(37.6, 32.4, 6.8, 7.8, CUERPO)
    # el cuello, girado hacia atrás
    lo.poli([(32.0, 31.0), (31.6, 21.0), (38.0, 19.0), (43.0, 30.0)], CUERPO)
    lo.trazo([(37.2, 37.0), (37.4 - s, 42.6), (37.8 - s * 1.6, 48.4)], [4.6, 3.9, 3.4], PATA)
    pie(lo, 37.8 - s * 1.6, 48.4, PATA)
    lo.trazo([(17.8, 36.4), (15.4, 42.6), (16.8 + s * 1.6, 48.4)], [5.8, 3.6, 3.2], PATA)
    pie(lo, 16.8 + s * 1.6, 48.4, PATA)
    # la cola arriba, curvada hacia adelante (casi en la boca)
    cola(lo, (13.4, 28.0), [(0, 0), (-3.2, -3.4), (-2.8, -8.4), (0.8, -11.4), (5.0, -12.0)],
         [4.2, 5.8, 6.2, 5.0, 2.6], capa=FRENTE)
    panoleta(lo, (35.4, 22.4), (41.4, 25.2), (41.6, 34.2), nudo=(0.6, 0.0))
    cabeza(lo, 33.4, 17.4, giro=-6, espejo=True, boca="lengua", orejas="atras")
    return lo


def cola_espalda(paso=0):
    """De espaldas: el anca redonda, la cola alta que barre hacia un lado y las
    orejas asomando; el nudo de la pañoleta en la nuca."""
    lo = Lienzo()
    cx = 30.0                          # el eje (entre los pixeles 29 y 30)
    eje = 60
    # la cabeza por detrás, con sus orejas (sin lo rosado: se ven por detrás)
    lo.poli([(cx - 6.6, 15.8), (cx - 2.0, 13.0), (cx - 7.8, 6.0)], CUERPO)
    lo.elipse(cx, 18.0, 6.6, 5.4, CUERPO)
    lo.poli([(cx - 5.2, 18.4), (cx - 8.8, 22.6), (cx - 3.0, 23.0)], CUERPO)
    # el lomo y las manos asomando por detrás de las patas
    lo.elipse(cx, 29.8, 8.6, 6.6, COLA)
    lo.trazo([(cx - 2.6, 38.0), (cx - 2.6, 46.6)], [3.0, 2.6], LEJANA)
    lo.elipse(cx - 2.6, 47.6, 1.8, 1.1, LEJANA)
    # el anca, redonda, y las patas de atrás con su corvejón
    lo.elipse(cx, 38.0, 9.6, 7.4, FRENTE)
    lo.trazo([(cx - 6.4, 40.0), (cx - 7.2, 44.0), (cx - 6.6, 48.0)], [5.6, 3.8, 3.4], FRENTE)
    lo.elipse(cx - 6.8, 48.6, 2.5, 1.3, FRENTE)
    lo.espejar(eje)
    # la banda de la pañoleta en el cuello y el nudo con sus puntas
    lo.trazo([(cx - 6.0, 24.4), (cx - 0.5, 25.2), (cx + 5.0, 24.4)], [2.6, 2.8, 2.6], CAPA_TELA)
    s = 1 if paso else -1
    lo.elipse(cx - 0.5, 25.4, 1.8, 1.6, CAPA_TELA)
    lo.poli([(cx - 1.4, 26.0), (cx - 3.4 + s, 29.8), (cx - 1.6 + s, 30.2)], CAPA_TELA)
    lo.poli([(cx + 0.4, 26.0), (cx + 2.4 + s, 29.8), (cx + 0.6 + s, 30.2)], CAPA_TELA)
    # la cola, esponjada, que barre hacia un lado y sube la punta
    pts = [(0, 0), (3.4, -2.6), (7.4, -4.2), (11.4, -7.0), (13.2, -11.0), (12.4, -14.4)]
    lo.encima(lambda: cola(lo, (cx - 0.5, 35.0), [(s * x, y) for x, y in pts], [4.0, 5.6, 7.0, 7.0, 5.4, 2.6],
                           capa=CABEZA))
    return lo


def cola_frente():
    """De frente: la cara de Lya, la pañoleta con el rombo y la lengua de fuera."""
    lo = Lienzo()
    cx = 30.0
    eje = 60
    # las patas de atrás asoman por los lados, más lejos
    lo.trazo([(cx - 6.4, 38.0), (cx - 7.0, 46.8)], [3.4, 2.8], LEJANA)
    lo.elipse(cx - 7.2, 47.8, 2.0, 1.1, LEJANA)
    lo.elipse(cx, 32.6, 7.6, 8.6, CUERPO)               # el pecho
    lo.trazo([(cx - 3.4, 37.0), (cx - 3.6, 42.6), (cx - 3.6, 48.0)], [4.4, 3.8, 3.4], PATA)
    lo.elipse(cx - 3.8, 48.6, 2.4, 1.3, PATA)
    # la cabeza de frente
    lo.poli([(cx - 6.8, 15.2), (cx - 2.0, 11.6), (cx - 5.8, 4.0)], CABEZA)
    lo.elipse(cx, 16.0, 6.8, 5.6, CABEZA)
    lo.elipse(cx, 19.4, 6.2, 3.8, CABEZA)
    lo.poli([(cx - 5.6, 16.4), (cx - 9.0, 21.6), (cx - 3.6, 22.0)], CABEZA)
    lo.espejar(eje)
    # la cola asoma por detrás, a un lado, con la punta arriba
    lo.debajo(lambda: cola(lo, (cx + 5.0, 38.0), [(0, 0), (5.0, -1.6), (9.0, -5.2), (10.4, -10.0), (9.4, -13.4)],
                           [3.6, 5.2, 5.8, 4.8, 2.4], capa=LEJANA))
    # la tela: banda bajo la cabeza y el triángulo con el rombo
    lo.trazo([(cx - 7.0, 23.6), (cx - 0.5, 25.4), (cx + 6.0, 23.6)], [3.0, 3.4, 3.0], CAPA_TELA)
    lo.poli([(cx - 6.6, 24.0), (cx + 5.6, 24.0), (cx - 0.5, 34.6)], CAPA_TELA)
    rombo_en(lo, 29, 28)
    lo.orejas.append([(cx - 6.0, 13.6), (cx - 3.0, 11.8), (cx - 5.4, 6.4)])
    lo.orejas.append([(2 * cx - x, y) for x, y in lo.orejas[-1]])
    # ojos almendrados, el hocico y la lengua
    c = int(cx)                         # el pixel derecho del centro (30)
    for lado in (-1, 1):
        ex = c - 4 if lado < 0 else c + 3
        x0 = ex if lado < 0 else ex
        lo.punto(x0 - lado, 15, OJO_OSCURO)
        lo.punto(x0, 15, OJO)
        lo.punto(x0 + lado, 15, BRILLO_OJO if lado < 0 else OJO)
        lo.punto(x0 - lado, 16, OJO)
        lo.punto(x0, 16, PUPILA)
        lo.punto(x0 + lado, 16, OJO_CLARO)
        for d in (-1, 0, 1):
            lo.punto(x0 + d, 14, PIEL["linea"])
    for x in (c - 2, c - 1, c, c + 1):
        lo.punto(x, 19, PIEL["medio"])
    lo.punto(c - 1, 18, NARIZ_BRILLO)
    lo.punto(c, 18, NARIZ)
    lo.punto(c - 1, 19, NARIZ)
    lo.punto(c, 19, NARIZ)
    lo.punto(c - 2, 21, PIEL["linea"])
    lo.punto(c + 1, 21, PIEL["linea"])
    lo.punto(c - 1, 21, LENGUA)
    lo.punto(c, 21, LENGUA)
    lo.punto(c - 1, 22, LENGUA)
    lo.punto(c, 22, LENGUA_SOMBRA)
    return lo


def rayitas(lo, lado):
    """Las rayitas de la vuelta (se tiñen)."""
    if lado > 0:
        lo.dibujo(2, 10, ["##..", "..#.", "...#"])
        lo.dibujo(52, 32, ["#...", ".#..", "..##"])
    else:
        lo.dibujo(52, 10, ["..##", ".#..", "#..."])
        lo.dibujo(2, 32, ["...#", "..#.", "##.."])


# ---------------------------------------------------------------------------
# Los cuadros, en orden (el mismo que ORDEN en Lya.lua)
# ---------------------------------------------------------------------------
def espejo(par):
    pelo, borde = par
    return pelo.transpose(Image.FLIP_LEFT_RIGHT), borde.transpose(Image.FLIP_LEFT_RIGHT)


def cuadros():
    out = []

    def add(nombre, lo):
        out.append((nombre, lo.pintar() if isinstance(lo, Lienzo) else lo))

    # quieta: respira y mece la cola (ida y vuelta); y su parpadeo
    QUIETA = [(0, 0.0), (7, 0.5), (13, 1.0), (7, 0.5)]
    for ojos, suf in (("abiertos", ""), ("cerrados", "-parpadeo")):
        for i, (cg, r) in enumerate(QUIETA):
            add(f"quieta{i + 1}{suf}", parada(cola_giro=cg, resp=r, ojos=ojos))
    # atenta: las orejas paradas, la cabeza en alto y la cola arriba, que se mueve rápido
    for ojos, suf in (("abiertos", ""), ("cerrados", "-parpadeo")):
        for i, cg in enumerate((1, 13)):
            add(f"atenta{i + 1}{suf}", parada(cola_giro=cg, orejas="atentas", cab_dy=-1.0, cab_giro=-6, alta=True,
                                               ojos=ojos))
    # sentada: respira y la punta de la cola se mueve; y su parpadeo
    for ojos, suf in (("abiertos", ""), ("cerrados", "-parpadeo")):
        for i, (cg, r) in enumerate(((0, 0.0), (10, 1.0))):
            add(f"sentada{i + 1}{suf}", sentada(cola_giro=cg, resp=r, ojos=ojos, giro=-3))
    # pedir: sentada con la manita arriba, la lengua de fuera y la salchicha;
    # al final, sentada pidiendo con las dos manos
    PEDIR = [("una", 0, -10, (41.4, 17.2), 0, 0), ("una", 1, -6, (41.4, 16.8), 12, 1),
             ("dos", 1, -12, (42.0, 15.6), 6, 0)]
    for i, (manos, fase, giro, cab, cg, sy) in enumerate(PEDIR):
        lo = sentada(boca="lengua", ojos="brillosos", manos=manos, fase=fase, giro=giro, cab=cab, cola_giro=cg)
        lo.objetos.append((salchicha(10, 4, ang=-20), 42, sy - 1))
        lo.dibujo(41 + (i % 2) * 15, 1 + sy + (i % 2) * 8, [".#.", "###", ".#."])
        add(f"pedir{i + 1}", lo)
    # correr: el galope en 6 tiempos
    for i in range(6):
        add(f"correr{i + 1}", correr(i))
    # buscarse la cola: de lado, de espaldas, del otro lado y de frente
    a = cola_lado(0)
    rayitas(a, 1)
    add("cola1", a)
    add("cola2", cola_espalda(0))
    c = cola_lado(1)
    rayitas(c, 1)
    add("cola3", espejo(c.pintar()))
    add("cola4", cola_frente())
    # dormir (respira) con sus "z"
    for i in range(2):
        lo = dormir(resp=1.0 * i)
        if i == 0:
            lo.dibujo(50, 27, ["###", ".#.", "###"])
        else:
            lo.dibujo(51, 24, ["###", ".#.", "###"])
            lo.dibujo(54, 16, ["####", "..#.", ".#..", "####"])
        add(f"dormir{i + 1}", lo)
    # aullar
    add("aullar1", aullar(0))
    add("aullar2", aullar(1))
    # saltar: agacharse, en el aire, cayendo
    for i in range(3):
        add(f"saltar{i + 1}", saltar(i))
    # estirarse: la reverencia, más honda con un bostezo, y el bostezo de pie
    add("estirarse1", reverencia())
    add("estirarse2", reverencia(ojos="cerrados", boca="bostezo", hondo=1.0, orejas="atras"))
    add("estirarse3", parada(ojos="cerrados", boca="bostezo", cab_giro=-24, cab_dy=-0.6, cola_giro=-6, orejas="atras"))
    return out


def orden_lua():
    """Los nombres de ORDEN en Lya.lua (para no desfasar las celdas)."""
    texto = LUA.read_text(encoding="utf-8")
    m = re.search(r"local ORDEN = \{(.*?)\n\}", texto, re.S)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []


def main():
    lista = cuadros()
    nombres = [n for n, _ in lista]
    lua = orden_lua()
    if lua != nombres:
        print("ORDEN no cuadra con Lya.lua:\n  aquí:", nombres, "\n  Lya.lua:", lua)
        return 1
    assert len(lista) <= COLS * (HOJA_H // H), "no caben"
    pelo = Image.new("RGBA", (HOJA_W, HOJA_H), (0, 0, 0, 0))
    borde = Image.new("RGBA", (HOJA_W, HOJA_H), (255, 255, 255, 0))
    for i, (n, (p, b)) in enumerate(lista):
        x, y = (i % COLS) * W, (i // COLS) * H
        pelo.paste(p, (x, y))
        borde.paste(b, (x, y))
    AQUI.mkdir(parents=True, exist_ok=True)
    pelo.save(AQUI / "lya-cuerpo.tga")
    borde.save(AQUI / "lya-cuerpo-borde.tga")
    print(len(lista), "cuadros en", AQUI / "lya-cuerpo.tga")
    if len(sys.argv) > 1:
        muestra(lista, pathlib.Path(sys.argv[1]))
    return 0


# ---------------------------------------------------------------------------
# Hoja de muestra (para revisar a ojo)
# ---------------------------------------------------------------------------
def componer(pelo, borde, tinte=VERDE, alfa=0.6):
    """El cuadro como se vería en el juego: el borde teñido y el pelaje encima."""
    im = Image.new("RGBA", pelo.size, (0, 0, 0, 0))
    color = Image.new("RGBA", pelo.size, tinte + (255,))
    color.putalpha(borde.getchannel("A").point(lambda v: int(v * alfa)))
    im.alpha_composite(color)
    im.alpha_composite(pelo)
    return im


def muestra(lista, carpeta, z=5):
    """Cada cuadro a xz sobre fondo oscuro, gris y claro, con el borde teñido de
    verde (Alfa) al 60 %; la línea de las patas marcada en rojo."""
    carpeta.mkdir(parents=True, exist_ok=True)
    fondos = [(16, 20, 18), (62, 66, 74), (206, 210, 204)]
    cols = 9
    filas = (len(lista) + cols - 1) // cols
    cw, ch = W * z + 4, H * z + 4
    hoja = Image.new("RGB", (cols * cw, filas * ch * len(fondos)), (0, 0, 0))
    for j, fondo in enumerate(fondos):
        for i, (n, (p, b)) in enumerate(lista):
            celda = Image.new("RGBA", (W, H), fondo + (255,))
            celda.alpha_composite(componer(p, b))
            grande = celda.convert("RGB").resize((W * z, H * z), Image.NEAREST)
            d = ImageDraw.Draw(grande)
            d.line([(0, PIES * z), (6, PIES * z)], fill=(220, 40, 40))
            x = (i % cols) * cw
            y = (j * filas + i // cols) * ch
            hoja.paste(grande, (x + 2, y + 2))
    destino = carpeta / "lya-cuerpo-hoja.png"
    hoja.save(destino)
    print("hoja:", destino)
    return destino


if __name__ == "__main__":
    sys.exit(main())
