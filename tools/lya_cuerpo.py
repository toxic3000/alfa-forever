"""Dibuja a Lya de cuerpo completo en pixel art (toxic3000 / La Jauría). GPL-3.0.

Uso (desde la raíz del proyecto):
  .venv/Scripts/python -I tools/lya_cuerpo.py [carpeta-para-la-hoja-de-muestra]

Lya es una loba negra, un poco gordita y tierna, de ojos ámbar (la misma de
tools/lya.py, ahora entera). Cada cuadro se dibuja a 48 x 40 px de verdad
(pixel art: polígonos sin suavizado, sombreado plano de 3-4 tonos y contorno
oscuro) dentro de un cuadro de 52 x 42 (la orilla es para el contorno) y se
escala x2 con NEAREST a una celda de 104 x 84. Las celdas van de izquierda a
derecha y de arriba abajo, 9 por fila (6 filas), en dos hojas de
1024 x 512 (TGA de 32 bits sin comprimir) en src/Alfa_Lya/Media:
  lya-cuerpo.tga        el pelaje con sus colores (no se tiñe)
  lya-cuerpo-borde.tga  en blanco, para teñir con el acento del estilo: un
                        contorno de un pixel por fuera del oscuro (para que la
                        loba negra se lea sobre fondos oscuros) y los adornos
                        (las "z" al dormir, el aullido, el huesito al pedir,
                        las rayitas al buscarse la cola)
Todas miran a la derecha; el juego las voltea con SetTexCoord.

El orden de las celdas (ORDEN) es el mismo que ORDEN en src/Alfa_Lya/Lya.lua.
"""
import math
import pathlib
import sys

from PIL import Image, ImageDraw

AQUI = pathlib.Path(__file__).resolve().parent.parent / "src" / "Alfa_Lya" / "Media"

W, H = 52, 42            # el cuadro de pixel art (se dibuja en 48 x 40, con orilla)
OX, OY = 2, 1            # dónde empieza el dibujo dentro del cuadro
X = 2                    # escala (NEAREST)
CW, CH = W * X, H * X    # la celda en la hoja: 104 x 84
HOJA_W, HOJA_H = 1024, 512
COLS = HOJA_W // CW      # 9

# Paleta: casi negro con matices carbón y un toque azulado para el volumen.
CERCA = {  # partes cercanas (cuerpo, cabeza, patas de este lado)
    "base": (31, 34, 44), "medio": (37, 41, 53), "luz": (66, 75, 96),
    "sombra": (20, 22, 29), "linea": (13, 14, 19),
}
LEJOS = {  # las patas y la oreja del otro lado: un tono más oscuras
    "base": (23, 25, 33), "medio": (27, 30, 39), "luz": (41, 46, 59),
    "sombra": (16, 17, 23), "linea": (11, 12, 16),
}
CONTORNO = (9, 9, 13)
OJO = (242, 190, 84)          # ámbar
OJO_BRILLO = (255, 226, 150)
PUPILA = (58, 32, 12)
PARPADO = (112, 122, 146)     # el ojo cerrado: una rayita clara
OREJA = (92, 62, 76)          # por dentro de la oreja
NARIZ = (5, 5, 7)
BRILLO_NARIZ = (104, 110, 128)
LENGUA = (236, 116, 138)
LENGUA_SOMBRA = (190, 78, 102)
BOCA = (44, 14, 22)
HOCICO = (52, 58, 75)         # el hocico de frente, un poco más claro
POLVO = (168, 160, 146)

# Las capas, de lejos a cerca: una orilla oscura separa lo de enfrente de lo
# de atrás (menos las patas de este lado, que salen del cuerpo).
LEJANA, CUERPO, COLA, CERCANA, CABEZA = 1, 2, 3, 4, 5
CABEZA_ESCALA = 1.12


# ---------------------------------------------------------------------------
# Geometría
# ---------------------------------------------------------------------------
def girar(pts, ang, cx=0.0, cy=0.0):
    """Gira en grados (positivo = como las manecillas en pantalla, y hacia abajo)."""
    a = math.radians(ang)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


def elipse_pts(cx, cy, rx, ry, ang=0.0, n=28):
    pts = [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]
    return girar(pts, ang, cx, cy) if ang else pts


class Lobo:
    """Un cuadro: un mapa de capas (0 vacío, 1 lejana ... 4 cabeza) y los detalles."""

    def __init__(self):
        self.capa = Image.new("L", (W, H), 0)
        self.d = ImageDraw.Draw(self.capa)
        self.detalles = {}      # (x, y) -> color (RGBA o RGB), encima del sombreado
        self.tinte = set()      # (x, y) adornos de la capa que se tiñe
        self.polvo = {}         # (x, y) -> alfa

    # formas -----------------------------------------------------------------
    def poli(self, pts, capa):
        self.d.polygon([(round((x + OX) * 2) / 2, round((y + OY) * 2) / 2) for x, y in pts], fill=capa)

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

    def pata(self, cadera, ang, largo, capa, ancho=3.0, pie=True):
        """Una pata desde la cadera; ang en grados desde la vertical (positivo = hacia adelante)."""
        a = math.radians(ang)
        hx, hy = cadera
        px, py = hx + math.sin(a) * largo, hy + math.cos(a) * largo
        self.trazo([(hx, hy), (px, py)], [ancho + 0.6, ancho - 0.2], capa)
        if pie:
            self.elipse(px + 0.7, py - 0.1, 1.9, 1.15, capa)
        return px, py

    def punto(self, x, y, color):
        self.detalles[(int(round(x)), int(round(y)))] = color

    def marca(self, x, y):
        self.tinte.add((int(round(x)), int(round(y))))

    def dibujo(self, x0, y0, filas):
        """Un adorno de la capa que se tiñe: filas de '#' y '.'."""
        for j, fila in enumerate(filas):
            for i, c in enumerate(fila):
                if c == "#":
                    self.marca(x0 + i, y0 + j)

    # cabeza de perfil ---------------------------------------------------------
    def cabeza(self, cx, cy, giro=0.0, espejo=False, ojos="abiertos", boca="cerrada", orejas="arriba", escala=CABEZA_ESCALA):
        """La cabeza mirando a la derecha (espejo: a la izquierda), centrada en (cx, cy)."""
        sx = -1 if espejo else 1

        def t(pts):
            return [(cx + x, cy + y) for x, y in girar([(sx * x * escala, y * escala) for x, y in pts], giro * sx)]

        def tp(x, y):
            return t([(x, y)])[0]

        # orejas: la de atrás (lejana) un poco más adelante y más baja
        if orejas == "atras":
            oreja = [(-3.8, -2.4), (0.4, -3.8), (-6.6, -7.4)]
            dentro = [(-3.0, -3.0), (-0.4, -3.8), (-5.2, -6.2)]
        elif orejas == "atentas":
            oreja = [(-3.2, -2.8), (1.2, -3.8), (-1.4, -10.4)]
            dentro = [(-2.2, -3.6), (0.4, -4.0), (-1.4, -8.4)]
        else:
            oreja = [(-3.4, -2.8), (1.2, -3.8), (-2.2, -10.0)]
            dentro = [(-2.4, -3.6), (0.4, -4.0), (-1.9, -7.8)]
        lejos = [(x + 2.6, y + 0.5) for x, y in oreja]
        self.poli(t(lejos), LEJANA)
        # cráneo, cachetes y melena (gordita) y el hocico de lobo
        self.poli(t(elipse_pts(0, 0, 5.8, 5.0)), CABEZA)
        self.poli(t(elipse_pts(-0.6, 2.0, 5.6, 3.9)), CABEZA)
        self.poli(t([(-4.6, 0.4), (-7.6, 4.8), (-3.2, 5.6)]), CABEZA)
        if boca in ("abierta", "bostezo"):
            abre = 1.0 if boca == "abierta" else 1.7
            self.poli(t([(2.2, -1.8), (8.4, -0.4), (9.2, 0.8), (8.2, 1.8), (2.6, 2.4)]), CABEZA)     # arriba
            self.poli(t(elipse_pts(4.6, 2.9 + abre, 3.2, 1.2, 8 + abre * 5)), CABEZA)               # quijada
        else:
            self.poli(t([(2.2, -1.8), (8.2, -0.2), (9.2, 1.2), (8.6, 2.8), (3.0, 4.2)]), CABEZA)
            self.poli(t(elipse_pts(6.0, 1.9, 3.0, 1.9)), CABEZA)
        self.poli(t(oreja), CABEZA)
        # los detalles, después del sombreado
        self._oreja_dentro = t(dentro)
        ox, oy = tp(2.4, -0.9)
        ex = int(round(ox)) - (1 if espejo else 0)
        ey = int(round(oy))
        if ojos == "abiertos":
            for i in range(2):
                for j in range(2):
                    self.detalles[(ex + i, ey + j)] = OJO
            # la pupila hacia el frente y abajo, y un brillito
            self.detalles[(ex + (0 if espejo else 1), ey + 1)] = PUPILA
            self.detalles[(ex + (1 if espejo else 0), ey)] = OJO_BRILLO
        else:
            self.detalles[(ex, ey + 1)] = PARPADO
            self.detalles[(ex + 1, ey + 1)] = PARPADO
        abierta = boca in ("abierta", "bostezo")
        if abierta:
            for k in range(4 if boca == "abierta" else 5):
                self.punto(*tp(3.8 + k * 1.0, 2.6 + (0.9 if boca == "bostezo" else 0.3)), BOCA)
            if boca == "bostezo":
                self.punto(*tp(4.4, 3.8), BOCA)
                self.punto(*tp(5.6, 3.8), LENGUA)
                self.punto(*tp(4.6, 4.5), LENGUA_SOMBRA)
            self.punto(*tp(8.6, 0.1), NARIZ)
            self.punto(*tp(7.8, -0.4), NARIZ)
        else:
            self.punto(*tp(8.7, 0.5), NARIZ)
            self.punto(*tp(8.0, 0.2), NARIZ)
            self.punto(*tp(8.6, 1.4), NARIZ)
            self.punto(*tp(6.6, 3.4), CERCA["linea"])
        if boca == "lengua":
            self.punto(*tp(5.4, 4.6), LENGUA)
            self.punto(*tp(6.4, 4.4), LENGUA)
            self.punto(*tp(5.6, 5.5), LENGUA_SOMBRA)
            self.punto(*tp(7.4, 3.3), BOCA)
        return tp

    # sombreado ----------------------------------------------------------------
    def pintar(self):
        """-> (pelaje RGBA, borde RGBA) a 48 x 40."""
        c = self.capa.load()

        def k(x, y):
            return c[x, y] if 0 <= x < W and 0 <= y < H else 0

        pelo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        p = pelo.load()
        for y in range(H):
            for x in range(W):
                v = k(x, y)
                if not v:
                    continue
                pal = LEJOS if v == LEJANA else CERCA
                arriba, abajo = k(x, y - 1), k(x, y + 1)
                vecinos = (k(x - 1, y), k(x + 1, y), arriba, abajo)
                if any(n > v and not (v == CUERPO and n == CERCANA) for n in vecinos):
                    col = pal["linea"]          # junto a algo que está más cerca
                elif abajo < v and not (v == CERCANA and abajo == CUERPO):
                    col = pal["sombra"]
                elif arriba == 0 or (arriba < v and v != CERCANA):
                    col = pal["luz"]
                elif (k(x, y - 2) == 0 or k(x - 1, y) == 0) and v != LEJANA:
                    col = pal["medio"]          # la luz viene de arriba a la izquierda
                elif k(x + 1, y) < v and k(x + 1, y + 1) < v:
                    col = pal["sombra"]
                else:
                    col = pal["base"]
                p[x, y] = col + (255,)
        # contorno oscuro por fuera (4 vecinos)
        borde = Image.new("RGBA", (W, H), (255, 255, 255, 0))
        b = borde.load()
        contorno = set()
        for y in range(H):
            for x in range(W):
                if k(x, y):
                    continue
                if k(x - 1, y) or k(x + 1, y) or k(x, y - 1) or k(x, y + 1):
                    p[x, y] = CONTORNO + (255,)
                    contorno.add((x, y))
        # la capa que se tiñe: un pixel por fuera del contorno
        for y in range(H):
            for x in range(W):
                if k(x, y) or (x, y) in contorno:
                    continue
                if any((x + dx, y + dy) in contorno for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    b[x, y] = (255, 255, 255, 255)
        # detalles
        oreja = getattr(self, "_orejas", [])
        for tri in oreja:
            m = Image.new("L", (W, H), 0)
            ImageDraw.Draw(m).polygon([(round((x + OX) * 2) / 2, round((y + OY) * 2) / 2) for x, y in tri], fill=1)
            mm = m.load()
            for y in range(H):
                for x in range(W):
                    if mm[x, y] and k(x, y) == CABEZA:
                        p[x, y] = OREJA + (255,)
        dentro = lambda x, y: 0 <= x < W and 0 <= y < H  # noqa: E731
        for (x, y), col in self.detalles.items():
            x, y = x + OX, y + OY
            if dentro(x, y) and (k(x, y) or col in (LENGUA, LENGUA_SOMBRA)):
                p[x, y] = (col + (255,)) if len(col) == 3 else col
        for (x, y), a in self.polvo.items():
            x, y = x + OX, y + OY
            if dentro(x, y) and not k(x, y) and (x, y) not in contorno:
                p[x, y] = POLVO + (a,)
        for (x, y) in self.tinte:
            x, y = x + OX, y + OY
            if dentro(x, y) and not k(x, y) and (x, y) not in contorno:
                b[x, y] = (255, 255, 255, 255)
        return pelo, borde

    def oreja_dentro(self):
        """Guarda el triángulo de dentro de la oreja de la última cabeza."""
        self._orejas = getattr(self, "_orejas", []) + [self._oreja_dentro]


# ---------------------------------------------------------------------------
# Las partes del cuerpo
# ---------------------------------------------------------------------------
def cola(lobo, base, puntos, anchos, capa=CUERPO, giro=0.0):
    bx, by = base
    pts = [(bx + x, by + y) for x, y in girar(puntos, giro)]
    lobo.trazo(pts, anchos, capa)


COLA_COLGADA = ([(0, 0), (-2.8, 1.6), (-4.8, 4.6), (-5.8, 8.2), (-6.4, 11.6)], [3.4, 4.8, 5.6, 4.8, 2.2])


def parado(cola_giro=0.0, resp=0.0, ojos="abiertos", boca="cerrada", orejas="arriba", cabeza_dy=0.0,
           cabeza_giro=0.0, bajar=0.0):
    lo = Lobo()
    y = bajar
    # la cola, colgando detrás (gira desde la base: negativo = arriba)
    # patas del otro lado
    lo.pata((18.5, 29 + y), -2, 6.6 - y, LEJANA)
    lo.pata((31.5, 29 + y), 2, 6.6 - y, LEJANA)
    # cuerpo gordito: anca, panza, pecho, cuello
    lo.elipse(15, 24.6 + y, 5.8, 6.4 + resp, CUERPO)
    lo.elipse(21.5, 25 + y, 8.6, 6.4 + resp * 0.6, CUERPO)
    lo.elipse(28.4, 23.6 + y, 5.8, 6.8 + resp * 0.5, CUERPO)
    lo.elipse(31.4, 19 + y, 4.2, 5.0, CUERPO)
    # la cola, colgando por detrás del anca (gira desde la base: negativo = arriba)
    cola(lo, (11.2, 21.2 + y), *COLA_COLGADA, COLA, giro=cola_giro)
    # patas de este lado
    lo.pata((14.5, 29.6 + y), 0, 6.2 - y, CERCANA)
    lo.pata((28, 29.6 + y), 0, 6.2 - y, CERCANA)
    lo.cabeza(35, 13.6 + cabeza_dy + y * 0.8, giro=cabeza_giro, ojos=ojos, boca=boca, orejas=orejas)
    lo.oreja_dentro()
    return lo


def sentado(cola_giro=0.0, resp=0.0, ojos="abiertos", boca="cerrada", orejas="arriba", cabeza_giro=0.0,
            pata=None, cabeza=(31, 13.8)):
    lo = Lobo()
    # la cola en el suelo, hacia atrás (la punta se levanta con cola_giro < 0)
    lo.pata((29.5, 26), 3, 9.4, LEJANA)
    lo.elipse(17.4, 29.2, 6.8, 6.4 + resp * 0.3, CUERPO)          # el anca
    lo.elipse(20.6, 24.4, 6.2, 6.6 + resp * 0.3, CUERPO)          # la espalda, redonda
    lo.elipse(23.6, 22.6, 5.4, 8.2 + resp * 0.4, CUERPO, ang=12)  # el tronco
    lo.elipse(27, 21.6 - resp * 0.3, 4.9, 6.2, CUERPO)            # el pecho
    # la cola en el suelo, hacia atrás, con la punta arriba (se mueve con cola_giro < 0)
    cola(lo, (13.4, 33.4), [(0, 0), (-4, 1.0), (-7.6, 0.6), (-9.6, -1.6)], [3.8, 4.6, 4.0, 2.4], COLA, giro=cola_giro)
    lo.elipse(22.4, 35.2, 3.5, 1.5, CERCANA)                    # la pata de atrás
    if pata is None:
        lo.pata((27, 26), 0, 9.4, CERCANA)
    else:
        # la pata levantada: el brazo hacia adelante y la mano doblada
        ang, alto = pata
        hx, hy = lo.pata((27, 25.5), ang, 6.2, CERCANA, pie=False)
        lo.trazo([(hx, hy), (hx + 2.4, hy - alto)], [3.0, 2.8], CERCANA)
        lo.elipse(hx + 2.8, hy - alto - 0.4, 1.7, 1.3, CERCANA)
    lo.cabeza(cabeza[0], cabeza[1], giro=cabeza_giro, ojos=ojos, boca=boca, orejas=orejas)
    lo.oreja_dentro()
    return lo


def correr(i, n=6):
    lo = Lobo()
    f = 2 * math.pi * i / n
    bob = -1.1 * math.cos(f)
    incl = 4 * math.sin(f)
    A = 44
    x = 1.0  # un poco a la derecha: la cola estirada no se sale del cuadro
    lo.pata((x + 18, 27.5 + bob), -A * math.sin(f + 0.6), 7.4, LEJANA, ancho=2.6)
    lo.pata((x + 30.5, 27 + bob), A * math.sin(f - 0.6), 7.4, LEJANA, ancho=2.6)
    lo.elipse(x + 14.6, 24 + bob, 5.4, 5.8, CUERPO, ang=incl)
    lo.elipse(x + 21.5, 24.4 + bob, 9.6, 5.8, CUERPO, ang=incl)
    lo.elipse(x + 28.6, 23.2 + bob, 5.4, 6.2, CUERPO, ang=incl)
    lo.elipse(x + 31.6, 19 + bob, 3.8, 4.4, CUERPO)
    cola(lo, (x + 10.8, 21.6 + bob), [(0, 0), (-3.4, -0.4), (-6.4, 0.6), (-9, 2.2)], [3.4, 4.6, 4.4, 2.2], COLA,
         giro=-8 + 10 * math.sin(f + 1.2))
    lo.pata((x + 14.6, 27.5 + bob), -A * math.sin(f), 7.6, CERCANA, ancho=2.8)
    lo.pata((x + 28, 27 + bob), A * math.sin(f), 7.6, CERCANA, ancho=2.8)
    lo.cabeza(x + 34, 15 + bob * 0.8, giro=incl * 0.6, boca="lengua", orejas="atras")
    lo.oreja_dentro()
    # polvito detrás de las patas de atrás cuando empujan
    if math.sin(f) > 0.2:
        for dx, dy, al in ((-2, 0, 150), (-4, -1, 110), (-5, 1, 90)):
            lo.polvo[(int(x + 9 + dx - i % 2), int(36 + dy))] = al
    return lo


def cola_lado(paso=0):
    """Buscándose la cola: la cabeza vuelta hacia atrás y la cola hacia la boca."""
    lo = Lobo()
    s = 1 if paso else -1
    lo.pata((17.5, 29), 10 * s, 6.4, LEJANA)
    lo.pata((32, 29), -10 * s, 6.4, LEJANA)
    lo.elipse(14, 25, 5.6, 6.0, CUERPO)
    lo.elipse(21, 25.6, 10, 5.8, CUERPO)
    lo.elipse(29, 24.4, 5.3, 6.0, CUERPO)
    lo.pata((13, 29.5), -10 * s, 6, CERCANA)
    lo.pata((28.5, 29.5), 10 * s, 6, CERCANA)
    # la cola arriba, curvada hacia adelante (casi en la boca)
    cola(lo, (10.6, 21), [(0, 0), (-2.4, -3.6), (-0.8, -7.6), (3.2, -9.4), (6.6, -9)], [3.6, 4.4, 4.6, 4.0, 2.6], COLA)
    lo.elipse(28, 19, 3.6, 4.4, CUERPO)
    lo.cabeza(25.5 + s * 0.5, 13.4, giro=-12, espejo=True, boca="lengua")
    lo.oreja_dentro()
    return lo


def cola_espalda(paso=0):
    """De espaldas: el anca redonda, la cola que barre y las orejas asomando."""
    lo = Lobo()
    cx = 24
    lo.poli([(cx - 6.6, 13.4), (cx - 2.8, 11), (cx - 5.8, 4.8)], CUERPO)
    lo.poli([(cx + 6.6, 13.4), (cx + 2.8, 11), (cx + 5.8, 4.8)], CUERPO)
    lo.elipse(cx, 14.8, 6.4, 5.2, CUERPO)
    lo.elipse(cx, 18.6, 6.6, 3.8, CUERPO)
    lo.elipse(cx, 26.4, 8.6, 7.4, CERCANA)
    lo.pata((cx - 4.4, 31), 0, 4.6, CERCANA, pie=False, ancho=3.4)
    lo.pata((cx + 4.4, 31), 0, 4.6, CERCANA, pie=False, ancho=3.4)
    lo.elipse(cx - 4.4, 35.6, 2.1, 1.2, CERCANA)
    lo.elipse(cx + 4.4, 35.6, 2.1, 1.2, CERCANA)
    s = 1 if paso else -1
    cola(lo, (cx, 22.5), [(0, 0), (1.6 * s, -3.2), (4.6 * s, -5.6), (8.4 * s, -6.2)], [3.6, 4.8, 4.8, 2.4], CABEZA)
    return lo


def cola_frente():
    """De frente: la cara de Lya, como la de siempre, chiquita."""
    lo = Lobo()
    cx = 24
    cola(lo, (cx + 4, 28), [(0, 0), (5, -2.4), (8.4, -6.2), (8.8, -10.4)], [3.0, 4.0, 3.8, 2.4], LEJANA)
    lo.elipse(cx, 27, 6.6, 6.6, CUERPO)
    lo.pata((cx - 3.2, 30.5), 0, 5.2, CERCANA, pie=False)
    lo.pata((cx + 3.2, 30.5), 0, 5.2, CERCANA, pie=False)
    lo.elipse(cx - 3.4, 35.6, 1.9, 1.1, CERCANA)
    lo.elipse(cx + 3.4, 35.6, 1.9, 1.1, CERCANA)
    ore_i = [(cx - 6.4, 13.2), (cx - 2.6, 10.6), (cx - 5.8, 4.8)]
    ore_d = [(cx + 6.4, 13.2), (cx + 2.6, 10.6), (cx + 5.8, 4.8)]
    lo.poli(ore_i, CABEZA)
    lo.poli(ore_d, CABEZA)
    lo.elipse(cx, 15, 6.4, 5.2, CABEZA)
    lo.elipse(cx, 17.6, 6.0, 3.6, CABEZA)
    lo._orejas = [[(cx - 5.6, 12.6), (cx - 3.4, 11.2), (cx - 5.4, 7.2)], [(cx + 5.6, 12.6), (cx + 3.4, 11.2), (cx + 5.4, 7.2)]]
    for x0 in (cx - 4, cx + 2):
        lo.detalles[(x0, 14)] = OJO
        lo.detalles[(x0 + 1, 14)] = OJO
        lo.detalles[(x0, 15)] = OJO if x0 > cx else PUPILA
        lo.detalles[(x0 + 1, 15)] = PUPILA if x0 > cx else OJO
    for x0 in (cx - 2, cx - 1, cx, cx + 1):
        lo.detalles[(x0, 18)] = HOCICO
    lo.detalles[(cx - 1, 17)] = NARIZ
    lo.detalles[(cx, 17)] = NARIZ
    lo.detalles[(cx - 1, 19)] = LENGUA
    lo.detalles[(cx, 19)] = LENGUA
    lo.detalles[(cx, 20)] = LENGUA_SOMBRA
    return lo


def dormir(resp=0.0):
    lo = Lobo()
    lo.elipse(22.5, 29.4 - resp * 0.5, 12, 5.8 + resp * 0.5, CUERPO)
    lo.elipse(14, 29.2 - resp * 0.5, 6.4, 6.0 + resp * 0.4, CUERPO)
    # la cola enroscada por delante
    cola(lo, (11, 29.6), [(0, 0), (1.2, 4), (7.6, 5.6), (15, 5.4), (19.6, 4.2)], [3.2, 4.0, 4.2, 3.6, 2.4], COLA)
    lo.elipse(37.6, 34.4, 3.2, 1.3, CERCANA)            # las manitas bajo la barbilla
    lo.cabeza(33.6, 29 - resp * 0.3, giro=6, ojos="cerrados", orejas="atras")
    lo.oreja_dentro()
    return lo


def aullar(abre=0):
    lo = sentado(ojos="cerrados", boca="abierta", orejas="atras", cabeza_giro=-46 - 4 * abre, cabeza=(29.4, 15.2))
    # las ondas del aullido (se tiñen): una o dos rayitas curvas junto al hocico
    lo.dibujo(38, 3, ["#..", ".#.", ".#.", "#.."])
    if abre:
        lo.dibujo(41, 1, ["#..", ".#.", "..#", "..#", ".#.", "#.."])
    return lo


def saltar(fase):
    lo = Lobo()
    if fase == 0:  # agacharse
        return parado(cola_giro=-14, bajar=1.6, cabeza_dy=0.6, orejas="atentas")
    if fase == 1:  # en el aire
        cola(lo, (10.5, 20.5), [(0, 0), (-3.6, -2), (-6.2, -4.0), (-8.2, -5.0)], [3.6, 4.4, 4.2, 2.6])
        lo.pata((17, 27.5), -50, 7, LEJANA)
        lo.pata((32, 26), 60, 5.4, LEJANA)
        lo.elipse(14, 23.6, 5.4, 5.8, CUERPO, ang=-12)
        lo.elipse(22, 23.6, 10.5, 5.4, CUERPO, ang=-12)
        lo.elipse(30, 21, 5.1, 5.9, CUERPO, ang=-12)
        lo.elipse(33, 16.6, 3.6, 4.4, CUERPO)
        lo.pata((14, 27.5), -38, 7.4, CERCANA)
        lo.pata((29, 25.5), 72, 5.6, CERCANA)
        lo.cabeza(35.4, 12.6, giro=-10, boca="lengua", orejas="atras")
    else:  # cayendo
        cola(lo, (11, 21), [(0, 0), (-3.4, -1.8), (-6.0, -3.8), (-8, -5.4)], [3.6, 4.4, 4.2, 2.6])
        lo.pata((17, 28.5), 30, 6.6, LEJANA)
        lo.pata((32, 28.5), 18, 7, LEJANA)
        lo.elipse(14, 24.4, 5.4, 5.8, CUERPO, ang=8)
        lo.elipse(22, 25, 10.5, 5.6, CUERPO, ang=8)
        lo.elipse(30, 26, 5.1, 5.9, CUERPO, ang=8)
        lo.elipse(33, 21, 3.6, 4.4, CUERPO)
        lo.pata((14, 28.5), 40, 6.4, CERCANA)
        lo.pata((29, 29), 12, 6.6, CERCANA)
        lo.cabeza(35.4, 17, giro=10, orejas="atras")
    lo.oreja_dentro()
    return lo


def reverencia(boca="cerrada", hondo=0.0):
    """Estirarse: el pecho al suelo, las manos adelante y el anca arriba."""
    lo = Lobo()
    cola(lo, (10, 17.5), [(0, 0), (-3, -2.6), (-4.8, -6.4), (-4.4, -10)], [3.6, 4.4, 4.2, 2.6])
    lo.pata((16.5, 25), 2, 10.4, LEJANA)
    lo.trazo([(31.5, 31.5 + hondo), (39.5, 34.8)], [3.2, 3.0], LEJANA)
    lo.elipse(40.6, 34.8, 1.9, 1.15, LEJANA)
    lo.elipse(14, 21, 5.5, 6.0, CUERPO)
    lo.elipse(22, 25 + hondo * 0.5, 10.5, 5.4, CUERPO, ang=22)
    lo.elipse(29.6, 30 + hondo, 5.0, 4.4, CUERPO)
    lo.pata((13, 25), 0, 10.6, CERCANA)
    lo.trazo([(29.5, 32.5 + hondo), (38, 35.2)], [3.4, 3.0], CERCANA)
    lo.elipse(39, 35.2, 1.9, 1.15, CERCANA)
    lo.cabeza(35.6, 25.4 + hondo, giro=-14, ojos="cerrados", boca=boca, orejas="atras")
    lo.oreja_dentro()
    return lo


def huesito(lo, x, y):
    lo.dibujo(x, y, ["#...#", ".###.", "#...#"])


def rayitas(lo, lado):
    """Las rayitas de la vuelta (se tiñen)."""
    if lado > 0:
        lo.dibujo(3, 9, ["##..", "..#.", "...#"])
        lo.dibujo(41, 30, ["#...", ".#..", "..##"])
    else:
        lo.dibujo(41, 9, ["..##", ".#..", "#..."])
        lo.dibujo(3, 30, ["...#", "..#.", "##.."])


# ---------------------------------------------------------------------------
# Los cuadros, en orden (el mismo que ORDEN en Lya.lua)
# ---------------------------------------------------------------------------
def espejo(lo_par):
    pelo, borde = lo_par
    return pelo.transpose(Image.FLIP_LEFT_RIGHT), borde.transpose(Image.FLIP_LEFT_RIGHT)


def cuadros():
    out = []

    def add(nombre, lo):
        out.append((nombre, lo.pintar() if isinstance(lo, Lobo) else lo))

    # quieta: respira (2 tiempos) y mueve la cola (mitad, arriba, mitad, abajo); y su parpadeo
    QUIETA = [(0, 0), (-12, 0), (0, 0.5), (8, 0.5)]
    for i, (cg, r) in enumerate(QUIETA):
        add(f"quieta{i + 1}", parado(cola_giro=cg, resp=r))
    for i, (cg, r) in enumerate(QUIETA):
        add(f"quieta{i + 1}-parpadeo", parado(cola_giro=cg, resp=r, ojos="cerrados"))
    # atenta: las orejas paradas, la cabeza en alto y la cola que se mueve rápido
    for i, cg in enumerate((-30, -14)):
        add(f"atenta{i + 1}", parado(cola_giro=cg, orejas="atentas", cabeza_dy=0.6, cabeza_giro=-4))
    for i, cg in enumerate((-30, -14)):
        add(f"atenta{i + 1}-parpadeo", parado(cola_giro=cg, orejas="atentas", cabeza_dy=0.6, cabeza_giro=-4, ojos="cerrados"))
    # sentada (respira, la punta de la cola se mueve); y su parpadeo
    for i, (cg, r) in enumerate(((0, 0), (-10, 0.6))):
        add(f"sentada{i + 1}", sentado(cola_giro=cg, resp=r))
    for i, (cg, r) in enumerate(((0, 0), (-10, 0.6))):
        add(f"sentada{i + 1}-parpadeo", sentado(cola_giro=cg, resp=r, ojos="cerrados"))
    # pedir: sentada, la manita arriba, la lengua de fuera, la cabeza ladeada y un huesito
    for i, (pata, giro, hy) in enumerate((((40, 1.5), 10, 3), ((60, 3.2), 14, 2), ((40, 1.5), -6, 3))):
        lo = sentado(boca="lengua", cabeza_giro=giro, pata=pata, cola_giro=-12 if i == 1 else 0)
        huesito(lo, 38, hy)
        add(f"pedir{i + 1}", lo)
    # correr
    for i in range(6):
        add(f"correr{i + 1}", correr(i))
    # buscarse la cola: de lado, de espaldas, del otro lado y de frente
    a = cola_lado(0)
    rayitas(a, 1)
    a_par = a.pintar()
    add("cola1", a_par)
    b = cola_espalda(0)
    add("cola2", b)
    c = cola_lado(1)
    rayitas(c, 1)
    add("cola3", espejo(c.pintar()))
    add("cola4", cola_frente())
    # dormir (respira) con sus "z"
    for i in range(2):
        lo = dormir(resp=0.6 * i)
        if i == 0:
            lo.dibujo(39, 22, ["##.", ".#.", ".##"])
        else:
            lo.dibujo(40, 20, ["##.", ".#.", ".##"])
            lo.dibujo(43, 14, ["####", "..#.", ".#..", "####"])
        add(f"dormir{i + 1}", lo)
    # aullar
    add("aullar1", aullar(0))
    add("aullar2", aullar(1))
    # saltar: agacharse, en el aire, cayendo
    for i in range(3):
        add(f"saltar{i + 1}", saltar(i))
    # estirarse: la reverencia, más honda con un bostezo, y el bostezo de pie
    add("estirarse1", reverencia())
    add("estirarse2", reverencia(boca="bostezo", hondo=0.8))
    add("estirarse3", parado(ojos="cerrados", boca="bostezo", cabeza_giro=-22, cabeza_dy=-0.5, cola_giro=-6))
    return out


ORDEN = None  # se llena en main(): los nombres en el orden de las celdas


def main():
    global ORDEN
    lista = cuadros()
    ORDEN = [n for n, _ in lista]
    assert len(lista) <= COLS * (HOJA_H // CH), "no caben"
    pelo = Image.new("RGBA", (HOJA_W, HOJA_H), (0, 0, 0, 0))
    borde = Image.new("RGBA", (HOJA_W, HOJA_H), (255, 255, 255, 0))
    for i, (n, (p, b)) in enumerate(lista):
        x, y = (i % COLS) * CW, (i // COLS) * CH
        pelo.paste(p.resize((CW, CH), Image.NEAREST), (x, y))
        borde.paste(b.resize((CW, CH), Image.NEAREST), (x, y))
    AQUI.mkdir(parents=True, exist_ok=True)
    pelo.save(AQUI / "lya-cuerpo.tga")
    borde.save(AQUI / "lya-cuerpo-borde.tga")
    print(len(lista), "cuadros en", AQUI / "lya-cuerpo.tga")
    for i, n in enumerate(ORDEN):
        print(f"  {i:2d} {n}")
    if len(sys.argv) > 1:
        muestra(lista, pathlib.Path(sys.argv[1]))


def muestra(lista, carpeta):
    """Una hoja para revisar a ojo: cada cuadro x4 sobre fondo oscuro, gris y claro,
    con el borde teñido de verde (Alfa) al 60 %."""
    carpeta.mkdir(parents=True, exist_ok=True)
    Z = 4
    fondos = [(16, 20, 18), (62, 66, 74), (196, 202, 196)]
    cols = 8
    filas = (len(lista) + cols - 1) // cols
    cw, ch = W * Z + 6, H * Z + 6
    hoja = Image.new("RGB", (cols * cw * 1, filas * ch * len(fondos)), (0, 0, 0))
    for j, fondo in enumerate(fondos):
        for i, (n, (p, b)) in enumerate(lista):
            celda = Image.new("RGBA", (W, H), fondo + (255,))
            verde = Image.new("RGBA", (W, H), (139, 224, 78, 255))
            verde.putalpha(b.getchannel("A").point(lambda v: v * 0.6))
            celda.alpha_composite(verde)
            celda.alpha_composite(p)
            x = (i % cols) * cw
            y = (j * filas + i // cols) * ch
            hoja.paste(celda.convert("RGB").resize((W * Z, H * Z), Image.NEAREST), (x + 3, y + 3))
    destino = carpeta / "lya-cuerpo-hoja.png"
    hoja.save(destino)
    print("hoja:", destino)


if __name__ == "__main__":
    main()
