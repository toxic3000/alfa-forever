"""Dibuja las texturas de Lya, la loba negra de Alfa (toxic3000 / La Jauría). GPL-3.0.

Uso (desde la raíz del proyecto):
  .venv/Scripts/python -I tools/lya.py [carpeta-para-la-hoja-png]

Parte de la misma cabeza de lobo que la marca de Alfa (tools/marca.py) y que
los lobos del Kit (tools/iconos.py), con las facciones más suaves y redondas
(un poco gordita), el pelaje casi negro y los ojos ámbar. Cada pose sale en dos
capas de 128 x 128 (TGA de 32 bits sin comprimir):
  lya-<pose>.tga        el pelaje con sus colores (no se tiñe)
  lya-<pose>-borde.tga  el contorno, el brillo y los adornos en blanco: el juego
                        lo tiñe con el acento del estilo, para que se lea sobre
                        fondos oscuros
Poses: normal, atenta, aullando, dormida, parpadeo.
"""
import math
import pathlib
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

# las imagenes van en la carpeta Media del modulo
AQUI = pathlib.Path(__file__).resolve().parent.parent / "src" / "Alfa_Lya" / "Media"
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import marca  # noqa: E402

L = 128
F = 4                    # sobremuestreo
PELO = (20, 22, 21)      # #141615
FACETA = {"oreja": (43, 34, 37), "mejilla": (29, 32, 30), "frente": (33, 37, 35)}
OJO = (242, 190, 84)     # ámbar
PUPILA = (24, 18, 10)
NARIZ = (6, 7, 6)
BRILLO_NARIZ = (70, 76, 72)
PARPADO = (150, 162, 152)
BLANCO = (255, 255, 255, 255)


def p(x, y):
    return (x * F, y * F)


def mover(pts, dx=0.0, dy=0.0, s=1.0, giro=0.0, cx=64, cy=64):
    a = math.radians(giro)
    out = []
    for x, y in pts:
        x, y = cx + (x - cx) * math.cos(a) - (y - cy) * math.sin(a), cy + (x - cx) * math.sin(a) + (y - cy) * math.cos(a)
        out.append((cx + (x - cx) * s + dx, cy + (y - cy) * s + dy))
    return out


# La silueta de la marca, más llena en mejillas y quijada (gordita, sin exagerar).
SILUETA = list(marca.SILUETA)
SILUETA[6] = (113, 72)   # mejilla derecha
SILUETA[7] = (93, 99)
SILUETA[8] = (64, 117)   # barbilla
SILUETA[9] = (35, 99)
SILUETA[10] = (15, 72)   # mejilla izquierda
FACETAS = [
    ("oreja", [(36, 16), (50, 38), (41, 45)]),
    ("oreja", [(92, 16), (78, 38), (87, 45)]),
    ("mejilla", [(17, 72), (40, 76), (37, 97)]),
    ("mejilla", [(111, 72), (88, 76), (91, 97)]),
    ("frente", [(64, 35), (53, 56), (64, 82), (75, 56)]),
]
OJOS = [(46.5, 64.5), (81.5, 64.5)]
HOCICO = [(55, 99), (73, 99), (64, 109)]


def redondear(mascara, r):
    """Esquinas suaves: desenfoca y vuelve a cortar a la mitad."""
    m = mascara.filter(ImageFilter.GaussianBlur(r * F))
    return m.point(lambda v: 255 if v >= 128 else 0)


def pose(nombre, t, ojos="abiertos", orejas=None, extra=None):
    """t = dict(dx, dy, s, giro) para mover la cabeza; orejas = (izq, der) nuevas puntas."""
    sil = list(SILUETA)
    fac = [(k, list(v)) for k, v in FACETAS]
    if orejas:
        sil[0], sil[4] = orejas
        fac[0][1][0], fac[1][1][0] = (orejas[0][0] + 2, orejas[0][1] + 4), (orejas[1][0] - 2, orejas[1][1] + 4)
    tr = lambda pts: mover(pts, **t)  # noqa: E731

    # Máscara de la cabeza, redondeada.
    m = Image.new("L", (L * F, L * F), 0)
    ImageDraw.Draw(m).polygon([p(*q) for q in tr(sil)], fill=255)
    m = redondear(m, 2.2)

    pelo = Image.new("RGBA", (L * F, L * F), PELO + (255,))
    d = ImageDraw.Draw(pelo)
    for tipo, f in fac:
        d.polygon([p(*q) for q in tr(f)], fill=FACETA[tipo] + (255,))
    # Ojos.
    centros = tr(OJOS)
    for i, (cx, cy) in enumerate(centros):
        if ojos == "abiertos" or ojos == "grandes":
            rx, ry = (7.2, 6.0) if ojos == "grandes" else (6.6, 5.2)
            d.ellipse([p(cx - rx, cy - ry), p(cx + rx, cy + ry)], fill=OJO + (255,))
            d.ellipse([p(cx - 2.2, cy - 3.6), p(cx + 2.2, cy + 3.6)], fill=PUPILA + (255,))
            hx = cx - 2.4 if i == 0 else cx + 1.0
            d.ellipse([p(hx - 1.3, cy - 3.2), p(hx + 1.3, cy - 0.6)], fill=(255, 255, 255, 255))
        else:
            # cerrados: una curva suave hacia abajo (dormida, contenta)
            r = 6.0
            caja = [p(cx - r, cy - r - 1), p(cx + r, cy + r - 1)]
            d.arc(caja, 25, 155, fill=PARPADO + (255,), width=round(2.4 * F))
    # Nariz, redondeada, con un brillo.
    hoc = tr(HOCICO)
    nm = Image.new("L", (L * F, L * F), 0)
    ImageDraw.Draw(nm).polygon([p(*q) for q in hoc], fill=255)
    nm = redondear(nm, 1.6)
    pelo.paste(NARIZ + (255,), (0, 0), nm)
    bx, by = (hoc[0][0] + hoc[1][0]) / 2 - 2, (hoc[0][1] + hoc[1][1]) / 2 + 1.5
    ImageDraw.Draw(pelo).ellipse([p(bx - 2.2, by - 1.1), p(bx + 2.2, by + 1.1)], fill=BRILLO_NARIZ + (255,))
    pelo.putalpha(m)

    # Borde (blanco, el juego lo tiñe): contorno por fuera, un halo y los adornos.
    ancho = 2.6
    fuera = m.filter(ImageFilter.MaxFilter(int(ancho * F) * 2 + 1))
    aro = ImageChops.subtract(fuera, m)
    halo = fuera.filter(ImageFilter.GaussianBlur(3.5 * F)).point(lambda v: v * 0.45)
    borde_a = ImageChops.lighter(aro, ImageChops.subtract(halo, m))
    borde = Image.new("RGBA", (L * F, L * F), (255, 255, 255, 0))
    borde.putalpha(borde_a)
    if extra:
        extra(ImageDraw.Draw(borde))

    return {nombre: pelo.resize((L, L), Image.LANCZOS), nombre + "-borde": borde.resize((L, L), Image.LANCZOS)}


def linea(d, pts, w):
    d.line([p(*q) for q in pts], fill=BLANCO, width=round(w * F), joint="curve")
    for x, y in (pts[0], pts[-1]):
        r = w / 2
        d.ellipse([p(x - r, y - r), p(x + r, y + r)], fill=BLANCO)


def arco(d, cx, cy, r, a0, a1, w):
    m = r + w / 2
    d.arc([p(cx - m, cy - m), p(cx + m, cy + m)], a0, a1, fill=BLANCO, width=round(w * F))


def todo():
    out = {}
    out.update(pose("lya-normal", dict(dy=2, s=0.94)))
    out.update(pose("lya-parpadeo", dict(dy=2, s=0.94), ojos="cerrados"))

    def alerta(d):
        linea(d, [(112, 14), (119, 8)], 4.5)
        linea(d, [(114, 25), (123, 23)], 4.5)
    out.update(pose("lya-atenta", dict(dy=7, s=0.88), ojos="grandes", orejas=((30, 3), (98, 3)), extra=alerta))

    def ondas(d):
        for r in (11, 20, 29):
            arco(d, 98, 30, r, 280, 350, 4.5)
    out.update(pose("lya-aullando", dict(dx=-9, dy=10, s=0.8, giro=-22), ojos="cerrados", extra=ondas))

    def zetas(d):
        linea(d, [(100, 8), (111, 8), (100, 19), (111, 19)], 4)
        linea(d, [(113, 25), (121, 25), (113, 33), (121, 33)], 3.2)
    out.update(pose("lya-dormida", dict(dy=9, s=0.86), ojos="cerrados", orejas=((22, 22), (106, 22)), extra=zetas))
    return out


def main():
    imgs = todo()
    for n, im in imgs.items():
        im.save(AQUI / f"{n}.tga")
    if len(sys.argv) > 1:
        # Hoja de muestra: cada pose con su borde teñido de verde, sobre tres fondos.
        fondos = [(16, 20, 18), (60, 64, 70), (200, 205, 200)]
        poses = [n for n in imgs if not n.endswith("-borde")]
        hoja = Image.new("RGBA", (len(poses) * 136 + 8, len(fondos) * 136 + 8), (0, 0, 0, 255))
        for j, fondo in enumerate(fondos):
            for i, n in enumerate(poses):
                celda = Image.new("RGBA", (128, 128), fondo + (255,))
                b = imgs[n + "-borde"].copy()
                verde = Image.new("RGBA", (128, 128), (139, 224, 78, 255))
                verde.putalpha(b.getchannel("A"))
                celda.alpha_composite(verde)
                celda.alpha_composite(imgs[n])
                hoja.alpha_composite(celda, (8 + i * 136, 8 + j * 136))
        destino = pathlib.Path(sys.argv[1]) / "lya-hoja.png"
        hoja.save(destino)
        print("hoja:", destino)
    print(len(imgs), "texturas en", AQUI)


if __name__ == "__main__":
    main()
