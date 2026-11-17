"""Dibuja el lugar de Lya en el suelo (toxic3000 / La Jauría). GPL-3.0.

Uso (desde la raíz del proyecto):
  .venv/Scripts/python -I tools/lya_marco.py [hoja.png]

Lya (tools/lya_cuerpo.py) no lleva cuadro de fondo: va parada sobre dos piezas
en pixel art de 64 x 16 pixeles (TGA de 32 bits sin comprimir, escaladas con
NEAREST) en src/Alfa_Lya/Media. El juego las muestra a 64 x 16 pixeles del
dibujo de Lya (1 px cada uno a tamaño 64), centradas donde pisan sus patas
(PIES en lya_cuerpo.py: 3 pixeles arriba del borde de abajo del cuadro):
  lya-sombra.tga  una sombra ovalada, oscura al centro y con orillas en
                  escalones (128 x 32). No se tiñe; va con ella al correr.
  lya-suelo.tga   una elipse fina en blanco, con el rombo de la marca de Alfa
                  al frente y dos marcas cortas a los lados (256 x 64). El juego
                  la tiñe con el acento del estilo (oro en Clásico WoW), la hace
                  respirar despacio y la deja en su lugar aunque ella corra.
"""
import math
import pathlib
import sys

from PIL import Image

AQUI = pathlib.Path(__file__).resolve().parent.parent / "src" / "Alfa_Lya" / "Media"
W, H = 64, 16
CX, CY = 32, 8


def sombra() -> Image.Image:
    im = Image.new("RGBA", (W, H), (6, 8, 10, 0))
    p = im.load()
    for y in range(H):
        for x in range(W):
            d = ((x + 0.5 - CX) / 20) ** 2 + ((y + 0.5 - CY) / 4.2) ** 2
            if d <= 1:
                a = 150 if d < 0.35 else 110 if d < 0.7 else 60
                p[x, y] = (6, 8, 10, a)
    return im.resize((W * 2, H * 2), Image.NEAREST)


def suelo() -> Image.Image:
    im = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    p = im.load()
    rx, ry = 27, 5.5
    puntos = set()
    for i in range(720):
        a = 2 * math.pi * i / 720
        x, y = CX + rx * math.cos(a), CY + ry * math.sin(a)
        puntos.add((int(math.floor(x)), int(math.floor(y))))
    for x, y in puntos:
        if 0 <= x < W and 0 <= y < H:
            # la mitad de atrás (arriba) más tenue: queda detrás de ella
            p[x, y] = (255, 255, 255, 255 if y >= CY else 120)
    # el rombo de Alfa al frente
    ry0 = int(CY + ry)
    for dy, ancho in ((-2, 0), (-1, 1), (0, 2), (1, 1), (2, 0)):
        for dx in range(-ancho, ancho + 1):
            x, y = CX + dx, ry0 + dy
            if 0 <= y < H:
                p[x, y] = (255, 255, 255, 255)
    # un hueco a cada lado del rombo, para que se lea como pieza aparte
    for dx in (-4, 4):
        for y in range(H):
            if p[CX + dx, y][3] and y >= CY:
                p[CX + dx, y] = (255, 255, 255, 0)
    # dos marcas cortas a los lados (como las de la brújula de la marca)
    for x0 in (CX - rx - 3, CX + rx + 2):
        p[x0, CY] = (255, 255, 255, 200)
        p[x0 + 1, CY] = (255, 255, 255, 200)
    return im.resize((W * 4, H * 4), Image.NEAREST)


def main() -> int:
    AQUI.mkdir(parents=True, exist_ok=True)
    piezas = {"lya-sombra": sombra(), "lya-suelo": suelo()}
    for n, im in piezas.items():
        im.save(AQUI / f"{n}.tga")
    if len(sys.argv) > 1:
        # una hoja para revisar: las piezas con Lya parada encima, sobre fondo oscuro y claro
        Z = 6
        hoja = Image.new("RGB", (W * Z * 2, 40 * Z), (24, 28, 26))
        hoja.paste(Image.new("RGB", (W * Z, 40 * Z), (190, 196, 190)), (W * Z, 0))
        cuerpo = Image.open(AQUI / "lya-cuerpo.tga").convert("RGBA").crop((0, 0, 60, 54))
        borde = Image.open(AQUI / "lya-cuerpo-borde.tga").convert("RGBA").crop((0, 0, 60, 54))
        for ox in (0, W):
            capa = Image.new("RGBA", (W, 40), (0, 0, 0, 0))
            s = piezas["lya-suelo"].resize((W, H), Image.NEAREST)
            verde = Image.new("RGBA", (W, H), (139, 224, 78, 255))
            verde.putalpha(s.getchannel("A").point(lambda v: v * 0.7))
            capa.alpha_composite(verde, (0, 40 - H - 1))
            capa.alpha_composite(piezas["lya-sombra"].resize((W, H), Image.NEAREST), (0, 40 - H - 1))
            v2 = Image.new("RGBA", (60, 54), (139, 224, 78, 255))
            v2.putalpha(borde.getchannel("A").point(lambda v: v * 0.6))
            dibujo = Image.new("RGBA", (60, 54), (0, 0, 0, 0))
            dibujo.alpha_composite(v2)
            dibujo.alpha_composite(cuerpo)
            # donde pisan las patas (fila 51 del cuadro) al centro de la elipse (fila 31 de la hoja)
            capa.alpha_composite(dibujo.crop((0, 20, 60, 54)), (2, 0))
            fondo = hoja.crop((ox * Z, 0, ox * Z + W * Z, 40 * Z)).convert("RGBA")
            fondo.alpha_composite(capa.resize((W * Z, 40 * Z), Image.NEAREST))
            hoja.paste(fondo.convert("RGB"), (ox * Z, 0))
        hoja.save(sys.argv[1])
        print("hoja:", sys.argv[1])
    print("OK", ", ".join(f"{n}.tga" for n in piezas))
    return 0


if __name__ == "__main__":
    sys.exit(main())
