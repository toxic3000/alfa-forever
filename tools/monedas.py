"""Dibuja las monedas de Alfa (oro, plata y cobre) en alta resolución.

Uso:  python -I tools/monedas.py   ->  src/Alfa_Nucleo/Media/moneda-<metal>-<estilo>.tga

Dos estilos propios (el Clásico WoW usa las monedas del juego):
  alfa     moneda plana y limpia, canto oscuro y un aro fino, como el resto de Alfa
  cristal  moneda brillante, con reflejo de vidrio arriba
128 px dibujados a 4x y reducidos (bordes suaves); TGA de 32 bits sin compresión,
que el juego lee tal cual.
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

SALIDA = pathlib.Path(__file__).resolve().parent.parent / "src" / "Alfa_Nucleo" / "Media"
TAM, ESCALA = 64, 4

# (claro, medio, oscuro, canto)
METALES = {
    "oro": ((255, 236, 140), (240, 190, 50), (176, 120, 20), (110, 70, 10)),
    "plata": ((250, 252, 255), (200, 206, 216), (128, 136, 150), (70, 76, 88)),
    "cobre": ((255, 196, 150), (214, 128, 72), (150, 78, 38), (90, 44, 20)),
}


def radial(tam, centro, radio, dentro, fuera):
    """Degradado radial de dentro (centro) a fuera (borde del radio)."""
    im = Image.new("RGBA", (tam, tam))
    px = im.load()
    cx, cy = centro
    for y in range(tam):
        for x in range(tam):
            t = min(1.0, math.hypot(x - cx, y - cy) / radio)
            px[x, y] = tuple(int(dentro[i] + (fuera[i] - dentro[i]) * t) for i in range(3)) + (255,)
    return im


def moneda(metal, estilo):
    claro, medio, oscuro, canto = METALES[metal]
    T = TAM * ESCALA
    c = T / 2
    r = T / 2 - 2 * ESCALA
    mascara = Image.new("L", (T, T), 0)
    ImageDraw.Draw(mascara).ellipse([c - r, c - r, c + r, c + r], fill=255)

    if estilo == "alfa":
        cara = radial(T, (c - r * 0.25, c - r * 0.3), r * 1.6, claro, oscuro)
    else:  # cristal
        cara = radial(T, (c - r * 0.35, c - r * 0.45), r * 1.35, claro, oscuro)
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    im.paste(cara, (0, 0), mascara)
    d = ImageDraw.Draw(im)

    # canto: un aro oscuro por fuera y uno claro por dentro (el relieve)
    d.ellipse([c - r, c - r, c + r, c + r], outline=canto + (255,), width=int(3.2 * ESCALA))
    ri = r - 3.2 * ESCALA
    d.ellipse([c - ri, c - ri, c + ri, c + ri], outline=claro + (150,), width=int(1.2 * ESCALA))

    if estilo == "alfa":
        # el aro fino de Alfa, un poco hacia dentro, y un rombo en el centro
        ra = r * 0.62
        d.ellipse([c - ra, c - ra, c + ra, c + ra], outline=oscuro + (210,), width=int(1.6 * ESCALA))
        k = r * 0.22
        d.polygon([(c, c - k), (c + k, c), (c, c + k), (c - k, c)], fill=claro + (230,), outline=oscuro + (220,))
    else:
        # cristal: reflejo de vidrio en la mitad de arriba y un destello
        brillo = Image.new("L", (T, T), 0)
        ImageDraw.Draw(brillo).ellipse([c - r * 0.78, c - r * 0.92, c + r * 0.78, c + r * 0.12], fill=120)
        brillo = brillo.filter(ImageFilter.GaussianBlur(5 * ESCALA))
        blanco = Image.new("RGBA", (T, T), (255, 255, 255, 255))
        capa = Image.new("RGBA", (T, T), (0, 0, 0, 0))
        capa.paste(blanco, (0, 0), Image.composite(brillo, Image.new("L", (T, T), 0), mascara))
        im = Image.alpha_composite(im, capa)
        d = ImageDraw.Draw(im)
        s = r * 0.16
        sx, sy = c + r * 0.38, c - r * 0.42
        d.polygon([(sx, sy - s), (sx + s * 0.28, sy), (sx, sy + s), (sx - s * 0.28, sy)], fill=(255, 255, 255, 235))
        d.polygon([(sx - s, sy), (sx, sy - s * 0.28), (sx + s, sy), (sx, sy + s * 0.28)], fill=(255, 255, 255, 235))

    # una sombra muy suave abajo para que no se vea plana sobre fondos oscuros
    sombra = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    ImageDraw.Draw(sombra).ellipse([c - r, c - r + 2 * ESCALA, c + r, c + r + 2 * ESCALA], fill=(0, 0, 0, 110))
    sombra = sombra.filter(ImageFilter.GaussianBlur(2 * ESCALA))
    final = Image.alpha_composite(sombra, im)
    return final.resize((TAM, TAM), Image.LANCZOS)


def main():
    SALIDA.mkdir(parents=True, exist_ok=True)
    for estilo in ("alfa", "cristal"):
        for metal in METALES:
            moneda(metal, estilo).save(SALIDA / f"moneda-{metal}-{estilo}.tga")
    # una vista de las seis, para revisar
    hoja = Image.new("RGBA", (TAM * 3 + 40, TAM * 2 + 30), (24, 32, 27, 255))
    for j, estilo in enumerate(("alfa", "cristal")):
        for i, metal in enumerate(METALES):
            m = Image.open(SALIDA / f"moneda-{metal}-{estilo}.tga")
            hoja.alpha_composite(m, (10 + i * (TAM + 10), 10 + j * (TAM + 10)))
    print("OK", SALIDA)
    return hoja


if __name__ == "__main__":
    import sys
    h = main()
    if len(sys.argv) > 1:
        h.save(sys.argv[1])
