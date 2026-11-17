"""Los iconos propios de Alfa y las variantes del lobo (docs/KIT.md, "Iconos").

Lo usa tools/interfaz.py: no se corre solo. Todo se dibuja en una rejilla de
32 unidades (los lobos en una de 128) con el mismo trazo: 2.5 unidades de
grosor, puntas y uniones redondas, cajas con las esquinas cortadas del diseno A
(arriba a la izquierda y abajo a la derecha) y rellenos solo donde la forma es
una mancha (la huella, el punto de grabar). Se dibuja a 8x y se reduce, para que
las diagonales queden suaves. Blancos con transparencia: el juego los tine.

  ICONOS   {nombre: funcion(lapiz)}   ic-* (funciones) y sec-* (secciones)
  LOBOS    {nombre: funcion() -> Image}  lobo-normal, -atento, -aullando, -dormido, -vacio
"""
import math
import pathlib
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import marca  # noqa: E402  (la silueta del lobo: la misma geometria que el emblema)

F = 8          # sobremuestreo
LADO = 32      # rejilla de los iconos
TRAZO = 2.5    # grosor de linea, en unidades de la rejilla
BLANCO = (255, 255, 255, 255)
NADA = (0, 0, 0, 0)


class Lapiz:
    """Primitivas de dibujo en unidades de la rejilla (y hacia abajo)."""

    def __init__(self, im, escala=F):
        self.im = im
        self.d = ImageDraw.Draw(im)
        self.f = escala

    def p(self, x, y):
        return (x * self.f, y * self.f)

    def _tapas(self, pts, w, color):
        r = w / 2
        for x, y in pts:
            self.d.ellipse([self.p(x - r, y - r), self.p(x + r, y + r)], fill=color)

    def linea(self, *pts, w=TRAZO, cerrada=False, color=BLANCO):
        pts = list(pts)
        if cerrada:
            pts.append(pts[0])
        self.d.line([self.p(*q) for q in pts], fill=color, width=max(1, round(w * self.f)))
        self._tapas(pts, w, color)

    def aro(self, cx, cy, r, w=TRAZO, color=BLANCO):
        m = r + w / 2
        self.d.ellipse([self.p(cx - m, cy - m), self.p(cx + m, cy + m)], outline=color, width=max(1, round(w * self.f)))

    def punto(self, cx, cy, r, color=BLANCO):
        self.d.ellipse([self.p(cx - r, cy - r), self.p(cx + r, cy + r)], fill=color)

    def ovalo(self, x0, y0, x1, y1, w=TRAZO, lleno=False, color=BLANCO):
        if lleno:
            self.d.ellipse([self.p(x0, y0), self.p(x1, y1)], fill=color)
        else:
            h = w / 2
            self.d.ellipse([self.p(x0 - h, y0 - h), self.p(x1 + h, y1 + h)], outline=color, width=max(1, round(w * self.f)))

    def arco(self, cx, cy, r, a0, a1, w=TRAZO, color=BLANCO):
        """Arco de a0 a a1 grados (0 = derecha, en el sentido del reloj), con puntas redondas."""
        m = r + w / 2
        self.d.arc([self.p(cx - m, cy - m), self.p(cx + m, cy + m)], a0, a1, fill=color, width=max(1, round(w * self.f)))
        puntas = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in (a0, a1)]
        self._tapas(puntas, w, color)

    def lleno(self, *pts, color=BLANCO):
        self.d.polygon([self.p(*q) for q in pts], fill=color)

    def borrar(self, *pts):
        self.lleno(*pts, color=NADA)

    def borrar_punto(self, cx, cy, r):
        self.punto(cx, cy, r, color=NADA)

    def caja(self, x0, y0, x1, y1, corte=4, w=TRAZO, lleno=False):
        """Una caja con las esquinas del diseno A cortadas (arriba-izq, abajo-der)."""
        c = corte
        pts = [(x0 + c, y0), (x1, y0), (x1, y1 - c), (x1 - c, y1), (x0, y1), (x0, y0 + c)]
        if lleno:
            self.lleno(*pts)
        else:
            self.linea(*pts, w=w, cerrada=True)


def huella(l: Lapiz, cx, cy, s=1.0, giro=0.0):
    """Una huella de lobo rellena: la almohadilla facetada y cuatro dedos."""
    a = math.radians(giro)

    def t(x, y):
        x, y = x * s, y * s
        return (cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a))

    l.lleno(t(0, -1), t(7.5, 4), t(6, 11), t(0, 12.5), t(-6, 11), t(-7.5, 4))
    for dx, dy, rx, ry in ((-9, -4.5, 2.8, 3.4), (-3.5, -10, 2.8, 3.4), (3.5, -10, 2.8, 3.4), (9, -4.5, 2.8, 3.4)):
        x, y = t(dx, dy)
        l.d.ellipse([l.p(x - rx * s, y - ry * s), l.p(x + rx * s, y + ry * s)], fill=BLANCO)


# ---------------------------------------------------------------------------
# Iconos (32 unidades). Margen de 3 a 4 unidades.
# ---------------------------------------------------------------------------

def i_hoy(l):
    # Amanecer: medio sol sobre el horizonte y tres rayos.
    l.arco(16, 21, 7, 180, 360)
    l.linea((4, 21), (28, 21))
    l.linea((16, 5), (16, 9))
    l.linea((7.2, 9.2), (9.8, 11.8))
    l.linea((24.8, 9.2), (22.2, 11.8))
    l.linea((10, 26), (22, 26))


def i_aventura(l):
    # Brujula: el aro y la aguja en rombo hacia el noreste (la punta llena).
    l.aro(16, 16, 12)
    l.lleno((22.5, 9.5), (17.9, 17.9), (14.1, 14.1))
    l.linea((9.5, 22.5), (14.1, 14.1), (17.9, 17.9), w=1.8, cerrada=True)


def i_personaje(l):
    # Escudo facetado con un galon.
    l.linea((7, 5), (25, 5), (25, 16), (16, 27.5), (7, 16), w=TRAZO, cerrada=True)
    l.linea((11.5, 12), (16, 16.5), (20.5, 12))


def i_mundo(l):
    # Globo: aro, meridiano y ecuador.
    l.aro(16, 16, 12)
    l.ovalo(11, 4, 21, 28, w=2)
    l.linea((4, 16), (28, 16), w=2)


def i_oficios(l):
    # Martillo: el mango en diagonal y la cabeza facetada.
    l.linea((7, 26), (17, 16), w=3)
    cx, cy, w, h = 20.5, 11.5, 13, 6
    a = math.radians(45)
    pts = []
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        x, y = sx * w / 2, sy * h / 2
        pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
    l.linea(*pts, cerrada=True)


def i_manada(l):
    # La huella de la manada.
    huella(l, 16, 16.5, 1.0)


def i_ajustes(l):
    # Engrane de ocho dientes en trazo, con su eje.
    pts = []
    n = 8
    for i in range(n * 2):
        ang = math.pi * 2 * i / (n * 2) - math.pi / 2
        for lado in (-1, 1):
            r = 12.2 if i % 2 == 0 else 8.8
            da = (math.pi / (n * 2)) * 0.6 * lado
            pts.append((16 + r * math.cos(ang + da), 16 + r * math.sin(ang + da)))
    l.linea(*pts, w=2.2, cerrada=True)
    l.aro(16, 16, 3.6, w=2.2)


def i_ruta(l):
    # La ruta: dos huellas que avanzan en diagonal.
    huella(l, 10.5, 21, 0.62, -20)
    huella(l, 21.5, 10.5, 0.62, 20)


def i_huella(l):
    huella(l, 16, 16.5, 1.05)


def i_guia(l):
    # Poste con dos tablas que senalan el camino.
    l.linea((16, 5), (16, 28))
    l.linea((11, 28), (21, 28))
    l.linea((16, 7), (25, 7), (28, 10), (25, 13), (16, 13))
    l.linea((16, 15.5), (7, 15.5), (4, 18.5), (7, 21.5), (16, 21.5))


def i_talentos(l):
    # Arbol de talentos: una raiz que se abre en tres.
    l.aro(16, 25.5, 2.6, w=2.2)
    l.linea((16, 22.8), (16, 18.8))
    l.aro(16, 16, 2.8, w=2.2)
    l.linea((14, 14), (9.5, 9.6))
    l.linea((18, 14), (22.5, 9.6))
    l.linea((16, 13.2), (16, 9.6))
    l.punto(7.6, 7.6, 3)
    l.punto(16, 6.8, 3)
    l.punto(24.4, 7.6, 3)


def i_enciclopedia(l):
    # Libro abierto con sus renglones.
    l.linea((16, 9.5), (16, 26.5))
    l.linea((16, 9.5), (4.5, 7), (4.5, 24), (16, 26.5))
    l.linea((16, 9.5), (27.5, 7), (27.5, 24), (16, 26.5))
    l.linea((8, 12.5), (12.5, 13.4), w=1.8)
    l.linea((8, 16.5), (12.5, 17.4), w=1.8)
    l.linea((19.5, 13.4), (24, 12.5), w=1.8)
    l.linea((19.5, 17.4), (24, 16.5), w=1.8)


def i_mazmorra(l):
    # La puerta de piedra con su rastrillo.
    l.linea((7, 28), (7, 15))
    l.arco(16, 15, 9, 180, 360)
    l.linea((25, 15), (25, 28))
    l.linea((3.5, 28), (28.5, 28))
    for x in (12, 16, 20):
        top = 15 - math.sqrt(max(0.0, 81 - (x - 16) ** 2)) + 2.2
        l.linea((x, top), (x, 28), w=1.8)
    l.linea((9, 20), (23, 20), w=1.8)


def i_curacion(l):
    # La cruz de la curacion dentro de una caja facetada.
    l.caja(5, 5, 27, 27, corte=6)
    l.linea((16, 10.5), (16, 21.5), w=3)
    l.linea((10.5, 16), (21.5, 16), w=3)


def i_mapa(l):
    # Mapa plegado en tres.
    l.linea((4, 8), (11, 5), (21, 8), (28, 5), (28, 24), (21, 27), (11, 24), (4, 27), cerrada=True)
    l.linea((11, 5), (11, 24), w=2)
    l.linea((21, 8), (21, 27), w=2)


def i_bolsas(l):
    # Morral facetado: el asa, la tapa y su broche.
    l.arco(16, 11, 5, 180, 360)
    l.caja(5, 11, 27, 28, corte=4)
    l.linea((5, 17.5), (27, 17.5), w=2)
    l.caja(13.5, 15.5, 18.5, 20.5, corte=1.5, w=2, lleno=True)


def i_comercio(l):
    # Balanza: el fiel, la cruz y los dos platos.
    l.linea((16, 6), (16, 26.5))
    l.linea((10.5, 27), (21.5, 27))
    l.linea((5.5, 9), (26.5, 9))
    for x in (6.5, 25.5):
        l.linea((x, 9), (x - 3.5, 17.5), w=1.6)
        l.linea((x, 9), (x + 3.5, 17.5), w=1.6)
        l.arco(x, 17.5, 3.8, 0, 180, w=2.2)


def i_oro(l):
    # Moneda con una faceta en el centro.
    l.aro(16, 16, 11.5)
    l.lleno((16, 10.5), (21.5, 16), (16, 21.5), (10.5, 16))


def i_pesca(l):
    # Pez: el cuerpo, la cola y el ojo.
    l.ovalo(4.5, 10, 21.5, 22)
    l.linea((20.5, 16), (27.5, 10), (27.5, 22), cerrada=True)
    l.punto(9.8, 14.8, 1.7)


def i_recoleccion(l):
    # Hoja con su nervio y su tallo.
    pts = []
    for i in range(0, 13):
        t = i / 12
        x = 7 + 18 * t
        y = 25 - 18 * t
        bulto = math.sin(math.pi * t) * 6
        pts.append((x - bulto * 0.707, y - bulto * 0.707))
    for i in range(12, -1, -1):
        t = i / 12
        x = 7 + 18 * t
        y = 25 - 18 * t
        bulto = math.sin(math.pi * t) * 6
        pts.append((x + bulto * 0.707, y + bulto * 0.707))
    l.linea(*pts, cerrada=True)
    l.linea((8.5, 23.5), (21, 11), w=1.8)
    l.linea((4.5, 27.5), (7.5, 24.5))


def i_buscar(l):
    l.aro(14, 14, 8.5)
    l.linea((20.5, 20.5), (27, 27), w=3.2)


def i_cerca(l):
    # Pin de ubicacion: "lo que hay cerca" (vuelo, banco, subasta, reparar...).
    cx, cy, r = 16, 12.5, 8.5
    l.arco(cx, cy, r, 135, 405)
    a = (cx - r * math.cos(math.radians(45)), cy + r * math.sin(math.radians(45)))
    b = (cx + r * math.cos(math.radians(45)), cy + r * math.sin(math.radians(45)))
    l.linea(a, (cx, 28.5), b)
    l.punto(cx, cy, 3.2)


def i_flecha(l):
    # La flecha de la guia, llena y con su muesca.
    l.lleno((16, 3.5), (26.5, 27), (16, 21), (5.5, 27))


def i_raros(l):
    # Mira: el aro, cuatro marcas y el centro.
    l.aro(16, 16, 9)
    l.linea((16, 3), (16, 8.5))
    l.linea((16, 23.5), (16, 29))
    l.linea((3, 16), (8.5, 16))
    l.linea((23.5, 16), (29, 16))
    l.punto(16, 16, 2.2)


def i_personajes(l):
    # Dos bustos: el de atras y el de adelante.
    l.aro(21.5, 9.5, 3.4, w=2.2)
    l.arco(21.5, 24, 7, 230, 330, w=2.2)
    l.aro(12, 12.5, 4.2)
    l.arco(12, 28.5, 9, 200, 340)


def i_aviso(l):
    # Campana.
    l.linea((9, 22), (9, 14.5))
    l.arco(16, 14.5, 7, 180, 360)
    l.linea((23, 14.5), (23, 22))
    l.linea((5.5, 23), (26.5, 23))
    l.punto(16, 26.8, 2.2)
    l.linea((16, 4.5), (16, 7))


def i_info(l):
    l.aro(16, 16, 12)
    l.punto(16, 10, 1.9)
    l.linea((16, 14.5), (16, 22.5))


def i_exito(l):
    l.aro(16, 16, 12)
    l.linea((10.5, 16.5), (14.5, 20.5), (22, 12))


def i_alerta(l):
    l.linea((16, 4.5), (28.5, 26.5), (3.5, 26.5), cerrada=True)
    l.linea((16, 11.5), (16, 18.5))
    l.punto(16, 22.6, 1.8)


def i_cerrar(l):
    l.linea((9, 9), (23, 23))
    l.linea((23, 9), (9, 23))


def i_mas(l):
    l.linea((16, 7), (16, 25))
    l.linea((7, 16), (25, 16))


def i_filtro(l):
    l.linea((5, 7), (27, 7), (19, 17), (19, 26), (13, 23), (13, 17), cerrada=True)


def i_lista(l):
    for y in (9, 16, 23):
        l.punto(7, y, 1.8)
        l.linea((12, y), (26, y))


def i_rejilla(l):
    for x0, y0 in ((5, 5), (18, 5), (5, 18), (18, 18)):
        l.caja(x0, y0, x0 + 9, y0 + 9, corte=2.5, w=2.2)


def i_seguir(l):
    l.lleno((10, 5.5), (26, 16), (10, 26.5))


def i_nivel(l):
    l.linea((8, 16.5), (16, 8.5), (24, 16.5))
    l.linea((8, 24.5), (16, 16.5), (24, 24.5))


def i_comodidades(l):
    for y, x in ((9, 11), (16, 21), (23, 14)):
        l.linea((5, y), (27, y), w=2)
        l.punto(x, y, 3.4)


def i_misiones(l):
    l.caja(8, 4, 24, 28, corte=4)
    l.linea((16, 9.5), (16, 18))
    l.punto(16, 22.5, 1.9)


def i_apariencia(l):
    # Paleta: el contorno, el hueco del pulgar y tres colores.
    l.arco(16, 16, 12, 60, 400)
    l.linea((22, 26.4), (22, 22))
    l.aro(21.5, 20, 2.4, w=2)
    for x, y in ((9.5, 13), (14.5, 8.8), (20.5, 10)):
        l.punto(x, y, 2.1)


def i_mando(l):
    l.linea((7, 10), (25, 10), (29, 22), (26, 25.5), (21, 20.5), (11, 20.5), (6, 25.5), (3, 22), cerrada=True)
    l.linea((10.5, 13), (10.5, 18), w=2)
    l.linea((8, 15.5), (13, 15.5), w=2)
    l.punto(21, 13.8, 1.8)
    l.punto(24, 16.8, 1.8)


def i_grabar(l):
    l.aro(16, 16, 11.5)
    l.punto(16, 16, 5.6)


def i_conexiones(l):
    l.caja(9.5, 10, 22.5, 21.5, corte=3)
    l.linea((13, 4), (13, 10))
    l.linea((19, 4), (19, 10))
    l.linea((16, 21.5), (16, 28))


def i_comunidad(l):
    l.linea((16, 5), (28, 11), (16, 17), (4, 11), cerrada=True)
    l.linea((4, 16), (16, 22), (28, 16))
    l.linea((4, 21), (16, 27), (28, 21))


def i_descubrir(l):
    # Ojo: dos arcos y la pupila.
    l.arco(16, 30, 18.5, 228, 312)
    l.arco(16, 2, 18.5, 48, 132)
    l.aro(16, 16, 4)
    l.punto(16, 16, 1.6)


def i_ventana(l):
    l.caja(4, 6, 28, 26, corte=4)
    l.linea((4, 12), (28, 12), w=2)
    l.punto(9, 9, 1.4)


def i_lobo(l):
    # El lobo de la marca en trazo, a 32 unidades.
    s, ox, oy = 0.215, 2.2, 1.6
    pts = [(x * s + ox, y * s + oy) for x, y in marca.SILUETA]
    l.linea(*pts, w=2.2, cerrada=True)
    for ojo in marca.OJOS:
        l.lleno(*[(x * s + ox, y * s + oy) for x, y in ojo])
    l.lleno(*[(x * s + ox, y * s + oy) for x, y in marca.NARIZ])


def i_reloj(l):
    l.aro(16, 16, 12)
    l.linea((16, 9), (16, 16), (21, 19))


ICONOS = {
    # Secciones de la ventana principal (los mismos que usa Options.lua).
    "sec-hoy": i_hoy, "sec-aventura": i_aventura, "sec-personaje": i_personaje, "sec-mundo": i_mundo,
    "sec-oficios": i_oficios, "sec-manada": i_manada, "sec-ajustes": i_ajustes,
    # Funciones.
    "ic-hoy": i_hoy, "ic-ruta": i_ruta, "ic-huella": i_huella, "ic-guia": i_guia, "ic-talentos": i_talentos,
    "ic-enciclopedia": i_enciclopedia, "ic-mazmorra": i_mazmorra, "ic-curacion": i_curacion,
    "ic-manada": i_manada, "ic-mundo": i_mundo, "ic-mapa": i_mapa, "ic-bolsas": i_bolsas,
    "ic-comercio": i_comercio, "ic-oro": i_oro, "ic-pesca": i_pesca, "ic-recoleccion": i_recoleccion,
    "ic-ajustes": i_ajustes, "ic-aventura": i_aventura, "ic-personaje": i_personaje, "ic-oficios": i_oficios,
    "ic-buscar": i_buscar, "ic-cerca": i_cerca, "ic-flecha": i_flecha, "ic-raros": i_raros, "ic-personajes": i_personajes,
    "ic-aviso": i_aviso, "ic-info": i_info, "ic-exito": i_exito, "ic-alerta": i_alerta,
    "ic-cerrar": i_cerrar, "ic-mas": i_mas, "ic-filtro": i_filtro, "ic-lista": i_lista,
    "ic-rejilla": i_rejilla, "ic-seguir": i_seguir, "ic-nivel": i_nivel, "ic-comodidades": i_comodidades,
    "ic-misiones": i_misiones, "ic-apariencia": i_apariencia, "ic-mando": i_mando, "ic-grabar": i_grabar,
    "ic-conexiones": i_conexiones, "ic-comunidad": i_comunidad, "ic-descubrir": i_descubrir,
    "ic-ventana": i_ventana, "ic-lobo": i_lobo, "ic-reloj": i_reloj,
}


def icono(fn, tam=LADO):
    im = Image.new("RGBA", (LADO * F, LADO * F), NADA)
    fn(Lapiz(im))
    return im.resize((tam, tam), Image.LANCZOS)


# ---------------------------------------------------------------------------
# El lobo (128 unidades), a partir de la silueta de la marca (tools/marca.py)
# ---------------------------------------------------------------------------

L = 128
FL = 4  # sobremuestreo de los lobos


def _lienzo_lobo():
    return Image.new("RGBA", (L * FL, L * FL), NADA)


def _girar(pts, grados, cx=64, cy=64):
    a = math.radians(grados)
    return [(cx + (x - cx) * math.cos(a) - (y - cy) * math.sin(a), cy + (x - cx) * math.sin(a) + (y - cy) * math.cos(a)) for x, y in pts]


def _mover(pts, dx=0, dy=0, s=1.0, cx=64, cy=64):
    return [(cx + (x - cx) * s + dx, cy + (y - cy) * s + dy) for x, y in pts]


def _cabeza(l, silueta, facetas, ojos, nariz, ojos_cerrados=None):
    l.lleno(*silueta)
    for faceta in facetas:
        l.lleno(*faceta, color=(255, 255, 255, 190))
    if ojos_cerrados:
        for a, b in ojos_cerrados:
            l.d.line([l.p(*a), l.p(*b)], fill=NADA, width=round(4.2 * l.f))
            for q in (a, b):
                l.d.ellipse([l.p(q[0] - 2.1, q[1] - 2.1), l.p(q[0] + 2.1, q[1] + 2.1)], fill=NADA)
    else:
        for ojo in ojos:
            l.borrar(*ojo)
    l.borrar(*nariz)


def lobo_normal():
    im = _lienzo_lobo()
    _cabeza(Lapiz(im, FL), marca.SILUETA, marca.FACETAS, marca.OJOS, marca.NARIZ)
    return im.resize((L, L), Image.LANCZOS)


def lobo_atento():
    """Las orejas mas altas y los ojos abiertos: algo pide tu atencion."""
    s = list(marca.SILUETA)
    s[0], s[4] = (30, 3), (98, 3)  # las puntas de las orejas, arriba
    fac = [list(f) for f in marca.FACETAS]
    fac[0][0], fac[1][0] = (30, 3), (98, 3)
    ojos = [[(36, 57), (56, 62), (47, 72)], [(92, 57), (72, 62), (81, 72)]]
    sil = _mover(s, dy=6, s=0.92)
    im = _lienzo_lobo()
    l = Lapiz(im, FL)
    _cabeza(l, sil, [_mover(f, dy=6, s=0.92) for f in fac], [_mover(o, dy=6, s=0.92) for o in ojos],
            _mover(marca.NARIZ, dy=6, s=0.92))
    # Dos marcas de alerta junto a la oreja derecha.
    l.linea((112, 14), (120, 8), w=5)
    l.linea((114, 26), (124, 24), w=5)
    return im.resize((L, L), Image.LANCZOS)


def lobo_aullando():
    """La cabeza hacia arriba y tres ondas: el aullido de la manada."""
    girar = -24
    sil = _mover(_girar(marca.SILUETA, girar), dx=-8, dy=8, s=0.84)
    fac = [_mover(_girar(f, girar), dx=-8, dy=8, s=0.84) for f in marca.FACETAS]
    ojos_c = []
    for a, b in (((40, 64), (54, 66)), ((88, 64), (74, 66))):
        p = _mover(_girar([a, b], girar), dx=-8, dy=8, s=0.84)
        ojos_c.append((p[0], p[1]))
    nariz = _mover(_girar(marca.NARIZ, girar), dx=-8, dy=8, s=0.84)
    im = _lienzo_lobo()
    l = Lapiz(im, FL)
    _cabeza(l, sil, fac, [], nariz, ojos_cerrados=ojos_c)
    for r in (12, 22, 32):
        l.arco(96, 30, r, 280, 350, w=5)
    return im.resize((L, L), Image.LANCZOS)


def lobo_dormido():
    """Los ojos cerrados, las orejas caidas y dos zetas."""
    s = list(marca.SILUETA)
    s[0], s[4] = (22, 22), (106, 22)
    fac = [list(f) for f in marca.FACETAS]
    fac[0][0], fac[1][0] = (22, 22), (106, 22)
    sil = _mover(s, dy=8, s=0.88)
    im = _lienzo_lobo()
    l = Lapiz(im, FL)
    ojos_c = [tuple(_mover([(38, 64), (54, 66)], dy=8, s=0.88)), tuple(_mover([(90, 64), (74, 66)], dy=8, s=0.88))]
    _cabeza(l, sil, [_mover(f, dy=8, s=0.88) for f in fac], [], _mover(marca.NARIZ, dy=8, s=0.88),
            ojos_cerrados=ojos_c)
    l.linea((100, 6), (112, 6), (100, 18), (112, 18), w=4.5)
    l.linea((114, 24), (122, 24), (114, 32), (122, 32), w=3.5)
    return im.resize((L, L), Image.LANCZOS)


def lobo_vacio():
    """El lobo en trazo, sin relleno: para lo que todavia no tiene nada."""
    im = _lienzo_lobo()
    l = Lapiz(im, FL)
    sil = _mover(marca.SILUETA, s=0.9)
    l.linea(*sil, w=5, cerrada=True)
    for ojo in marca.OJOS:
        l.linea(*_mover(ojo, s=0.9), w=3.5, cerrada=True)
    l.lleno(*_mover(marca.NARIZ, s=0.9))
    return im.resize((L, L), Image.LANCZOS)


LOBOS = {
    "lobo-normal": lobo_normal, "lobo-atento": lobo_atento, "lobo-aullando": lobo_aullando,
    "lobo-dormido": lobo_dormido, "lobo-vacio": lobo_vacio,
}


def todo():
    """{nombre: Image} de iconos y lobos."""
    out = {n: icono(fn) for n, fn in ICONOS.items()}
    out.update({n: fn() for n, fn in LOBOS.items()})
    return out
