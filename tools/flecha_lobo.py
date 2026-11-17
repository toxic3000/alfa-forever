"""La flecha de navegacion de Alfa: un lobo que apunta (docs/KIT.md, "Estilos").

Uso:  .venv/Scripts/python -I tools/flecha_lobo.py [carpeta_vista_previa]

Dibuja en motor/Alfa/Media/Nav/ (y las anota como nuevas en motor/BASE.json):

  lobo-flecha.tga        la cabeza de un lobo vista desde arriba: el hocico es
                         la punta y las orejas, hacia atras, las aletas de la
                         flecha. Facetada como el lobo de la marca (las caras de
                         la izquierda y el interior de las orejas un poco mas
                         tenues) y con los ojos calados.
  lobo-flecha-borde.tga  la misma silueta, mas ancha: el contorno oscuro que va
                         debajo para leerla sobre cualquier terreno (por los
                         ojos calados se ve oscuro: los ojos).
  lobo-llegada.tga       la huella del lobo, dentro del aro al llegar.

Todas son blancas con transparencia, de 128 x 128 (el juego las tine: la
flecha en su color, el contorno en la sombra del tema). Nav/Arrow.lua las gira
con SetRotation, asi que la punta mira hacia arriba y el lobo queda centrado
en el lienzo. Se dibujan a 4x y se reducen, para que los bordes queden suaves.
Con una carpeta deja ahi una hoja PNG sobre pasto, nieve y el grafito de Alfa.
"""
import json
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "motor" / "Alfa" / "Media" / "Nav"
BASE = RAIZ / "motor" / "BASE.json"
LADO = 128
F = 4
BLANCO = (255, 255, 255, 255)
NADA = (0, 0, 0, 0)

# La cabeza vista desde arriba (128 x 128, y hacia abajo), la punta arriba.
# Todo cabe en un circulo de radio 56 alrededor de (64, 64), el centro sobre
# el que gira: con el contorno (5) no pasa de 61, asi que SetRotation nunca
# recorta una oreja ni la punta.
SILUETA = [(64, 10), (71, 28), (78, 46), (90, 64), (86, 80), (102, 105), (84, 93), (64, 99),
           (44, 93), (26, 105), (42, 80), (38, 64), (50, 46), (57, 28)]
# Las caras en sombra: el lado izquierdo (del hocico a la nuca) y el interior
# de cada oreja.
SOMBRA = [(64, 10), (57, 28), (50, 46), (38, 64), (42, 80), (44, 93), (64, 99), (64, 56)]
OREJAS = [[(42, 80), (26, 105), (44, 93)], [(86, 80), (102, 105), (84, 93)]]
# La trufa, en la punta, y los ojos (rasgados, hacia la punta).
TRUFA = [(64, 11), (59, 20.5), (69, 20.5)]
OJOS = [[(48.5, 60), (58.5, 63.5), (51.5, 68)], [(79.5, 60), (69.5, 63.5), (76.5, 68)]]
CONTORNO = 5  # unidades de la rejilla que el borde sale de la silueta


def lienzo():
    return Image.new("RGBA", (LADO * F, LADO * F), NADA)


def pts(lista):
    return [(x * F, y * F) for x, y in lista]


def flecha() -> Image.Image:
    im = lienzo()
    d = ImageDraw.Draw(im)
    d.polygon(pts(SILUETA), fill=BLANCO)
    d.polygon(pts(SOMBRA), fill=(255, 255, 255, 215))
    for o in OREJAS:
        d.polygon(pts(o), fill=(255, 255, 255, 165))
    d.polygon(pts(TRUFA), fill=(255, 255, 255, 120))
    for o in OJOS:
        d.polygon(pts(o), fill=NADA)
    return im.resize((LADO, LADO), Image.LANCZOS)


def borde() -> Image.Image:
    mascara = Image.new("L", (LADO * F, LADO * F), 0)
    ImageDraw.Draw(mascara).polygon(pts(SILUETA), fill=255)
    # Engrosar la silueta: un filtro de maximo de 2r+1 (impar) a 4x.
    r = CONTORNO * F
    mascara = mascara.filter(ImageFilter.MaxFilter(2 * (r // 2) + 1)).filter(ImageFilter.MaxFilter(2 * (r // 2) + 1))
    mascara = mascara.filter(ImageFilter.GaussianBlur(F * 0.6))
    im = Image.new("RGBA", (LADO * F, LADO * F), (255, 255, 255, 0))
    im.putalpha(mascara)
    return im.resize((LADO, LADO), Image.LANCZOS)


def huella() -> Image.Image:
    """La huella del lobo (la de tools/iconos.py, en grande): almohadilla y cuatro dedos."""
    im = lienzo()
    d = ImageDraw.Draw(im)
    s, cx, cy = 3.6, 64, 70

    def t(x, y):
        return ((cx + x * s) * F, (cy + y * s) * F)

    d.polygon([t(0, -1), t(7.5, 4), t(6, 11), t(0, 12.5), t(-6, 11), t(-7.5, 4)], fill=BLANCO)
    for dx, dy, rx, ry in ((-9, -4.5, 2.8, 3.4), (-3.5, -10, 2.8, 3.4), (3.5, -10, 2.8, 3.4), (9, -4.5, 2.8, 3.4)):
        x, y = t(dx, dy)
        d.ellipse([x - rx * s * F, y - ry * s * F, x + rx * s * F, y + ry * s * F], fill=BLANCO)
    return im.resize((LADO, LADO), Image.LANCZOS)


def tenir(im, color, alfa=1.0):
    capa = Image.new("RGBA", im.size, color + (0,))
    a = im.getchannel("A").point(lambda v: int(v * alfa))
    capa.putalpha(a)
    # el blanco con su alfa propia (las facetas) multiplica el color
    rgb = Image.merge("RGB", [im.getchannel(c).point(lambda v, k=k: v * k // 255) for c, k in zip("RGB", color)])
    capa = Image.merge("RGBA", (*rgb.split(), a))
    return capa


def hoja(piezas, carpeta: pathlib.Path):
    """La flecha girada sobre tres fondos, en los colores de los tres estilos."""
    fondos = {"pasto": (74, 110, 54), "nieve": (226, 232, 238), "grafito": (16, 20, 18)}
    acentos = {"Alfa": (139, 224, 78), "Clasico WoW": (255, 209, 0), "Cristal": (111, 211, 255)}
    celda = 150
    out = Image.new("RGB", (celda * 4, celda * len(fondos) + 20), (16, 20, 18))
    d = ImageDraw.Draw(out)
    for fila, (nombre, fondo) in enumerate(fondos.items()):
        y = fila * celda
        d.rectangle([0, y, out.size[0], y + celda], fill=fondo)
        for col, (estilo, acento) in enumerate(acentos.items()):
            giro = (-25, 0, 40)[col]
            base = Image.new("RGBA", (LADO, LADO), NADA)
            base.alpha_composite(tenir(piezas["lobo-flecha-borde"].rotate(giro, Image.BICUBIC), (0, 0, 0), 0.82))
            base.alpha_composite(tenir(piezas["lobo-flecha"].rotate(giro, Image.BICUBIC), acento))
            out.paste(base, (col * celda + 11, y + 11), base)
        llegada = Image.new("RGBA", (LADO, LADO), NADA)
        llegada.alpha_composite(tenir(piezas["lobo-llegada"], (107, 217, 153)))
        out.paste(llegada, (3 * celda + 11, y + 11), llegada)
        d.text((6, y + 4), nombre, fill=(255, 255, 255) if fondo != fondos["nieve"] else (0, 0, 0))
    carpeta.mkdir(parents=True, exist_ok=True)
    destino = carpeta / "flecha-lobo.png"
    out.save(destino)
    print(f"hoja: {destino}")


def main() -> int:
    SALIDA.mkdir(parents=True, exist_ok=True)
    piezas = {"lobo-flecha": flecha(), "lobo-flecha-borde": borde(), "lobo-llegada": huella()}
    base = json.loads(BASE.read_text(encoding="utf-8")) if BASE.exists() else {}
    for nombre, im in piezas.items():
        im.save(SALIDA / f"{nombre}.tga")
        base.setdefault(f"Alfa/Media/Nav/{nombre}.tga", None)
    BASE.write_text(json.dumps(base, indent=1, sort_keys=True), encoding="utf-8")
    print(f"{len(piezas)} texturas de la flecha en motor/Alfa/Media/Nav/")
    if len(sys.argv) > 1:
        hoja(piezas, pathlib.Path(sys.argv[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
