"""Dibuja la marca de Alfa (lobo geometrico + letrero) y la deja en marca/.

Uso:  .venv/Scripts/python -I tools/marca.py [carpeta_vista_previa]

Escribe marca/Alfa/Media/UI/{emblem,logo,watermark,wordmark,wordmark-small}.tga.
build.py copia marca/ encima de dist/ despues de renombrar, asi que estas
imagenes reemplazan las de Polestar. Las blancas las tine el tema del juego;
el logo lleva sus propios colores. Fuente del letrero: Inter (SIL OFL 1.1),
la misma que ya trae el motor.
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "marca" / "Alfa" / "Media" / "UI"
FUENTE = RAIZ / "upstream" / "polestar-0.3.7.2" / "Polestar" / "Media" / "Fonts" / "Inter-SemiBold.ttf"
VERDE_CLARO, VERDE, VERDE_OSCURO = (182, 242, 122), (139, 224, 78), (74, 150, 38)

# Cabeza de lobo de frente, en una cuadricula de 128x128.
SILUETA = [(34, 12), (50, 38), (64, 33), (78, 38), (94, 12), (104, 50), (110, 70),
           (90, 96), (64, 118), (38, 96), (18, 70), (24, 50)]
# Facetas que se pintan un poco mas tenues para dar volumen.
FACETAS = [
    [(34, 12), (50, 38), (40, 46)],            # oreja izquierda, cara interna
    [(94, 12), (78, 38), (88, 46)],            # oreja derecha, cara interna
    [(18, 70), (40, 74), (38, 96)],            # mejilla izquierda
    [(110, 70), (88, 74), (90, 96)],           # mejilla derecha
    [(64, 33), (52, 56), (64, 84), (76, 56)],  # frente
]
OJOS = [[(38, 60), (56, 64), (46, 70)], [(90, 60), (72, 64), (82, 70)]]
NARIZ = [(56, 100), (72, 100), (64, 110)]


def escala(puntos, f, dx=0, dy=0):
    return [(x * f + dx, y * f + dy) for x, y in puntos]


def lobo(tam: int, borde: int = 0) -> Image.Image:
    """Lobo blanco con transparencia, dibujado a 4x y reducido (bordes suaves)."""
    f = 4
    lienzo = 128 + 2 * borde
    im = Image.new("RGBA", (lienzo * f, lienzo * f), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    o = borde * f
    d.polygon(escala(SILUETA, f, o, o), fill=(255, 255, 255, 255))
    for faceta in FACETAS:
        d.polygon(escala(faceta, f, o, o), fill=(255, 255, 255, 190))
    for hueco in OJOS + [NARIZ]:
        d.polygon(escala(hueco, f, o, o), fill=(0, 0, 0, 0))
    return im.resize((tam, tam), Image.LANCZOS)


def degradado(tam, arriba, abajo):
    im = Image.new("RGBA", (tam, tam))
    for y in range(tam):
        t = y / max(1, tam - 1)
        c = tuple(int(arriba[i] + (abajo[i] - arriba[i]) * t) for i in range(3))
        ImageDraw.Draw(im).line([(0, y), (tam, y)], fill=c + (255,))
    return im


def logo() -> Image.Image:
    f, tam = 4, 64
    t = tam * f
    fondo = degradado(t, (24, 30, 26), (8, 10, 9))
    mascara = Image.new("L", (t, t), 0)
    ImageDraw.Draw(mascara).rounded_rectangle([0, 0, t - 1, t - 1], radius=14 * f, fill=255)
    im = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    im.paste(fondo, (0, 0), mascara)
    ImageDraw.Draw(im).rounded_rectangle([f, f, t - f - 1, t - f - 1], radius=13 * f,
                                         outline=VERDE_OSCURO + (255,), width=2 * f)
    figura = lobo(int(t * 0.78))
    color = degradado(figura.size[0], VERDE_CLARO, VERDE_OSCURO)
    color.putalpha(figura.getchannel("A"))
    brillo = color.filter(ImageFilter.GaussianBlur(3 * f))
    brillo.putalpha(brillo.getchannel("A").point(lambda a: a * 55 // 100))
    pos = ((t - figura.size[0]) // 2, (t - figura.size[1]) // 2 + f)
    im.alpha_composite(brillo, pos)
    im.alpha_composite(color, pos)
    return im.resize((tam, tam), Image.LANCZOS)


def logo_grande(tam: int) -> Image.Image:
    """El logo de 64 px redibujado a cualquier tamano (para CurseForge)."""
    f = 4
    t = tam * f
    fondo = degradado(t, (24, 30, 26), (8, 10, 9))
    mascara = Image.new("L", (t, t), 0)
    ImageDraw.Draw(mascara).rounded_rectangle([0, 0, t - 1, t - 1], radius=t // 5, fill=255)
    im = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    im.paste(fondo, (0, 0), mascara)
    borde = max(2, t // 64)
    ImageDraw.Draw(im).rounded_rectangle([borde, borde, t - borde - 1, t - borde - 1], radius=t // 5 - borde,
                                         outline=VERDE_OSCURO + (255,), width=borde * 2)
    figura = lobo(int(t * 0.74))
    color = degradado(figura.size[0], VERDE_CLARO, VERDE_OSCURO)
    color.putalpha(figura.getchannel("A"))
    brillo = color.filter(ImageFilter.GaussianBlur(t // 60))
    brillo.putalpha(brillo.getchannel("A").point(lambda a: a * 55 // 100))
    pos = ((t - figura.size[0]) // 2, (t - figura.size[1]) // 2 + t // 60)
    im.alpha_composite(brillo, pos)
    im.alpha_composite(color, pos)
    return im.resize((tam, tam), Image.LANCZOS)


def marca_de_agua() -> Image.Image:
    f, tam = 4, 256
    t = tam * f
    im = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([10 * f, 10 * f, t - 10 * f, t - 10 * f], outline=(255, 255, 255, 255), width=2 * f)
    d.ellipse([18 * f, 18 * f, t - 18 * f, t - 18 * f], outline=(255, 255, 255, 140), width=1 * f)
    contorno = escala(SILUETA + [SILUETA[0]], 1.5 * f, 32 * f, 30 * f)
    d.line(contorno, fill=(255, 255, 255, 255), width=3 * f, joint="curve")
    for hueco in OJOS + [NARIZ]:
        d.polygon(escala(hueco, 1.5 * f, 32 * f, 30 * f), outline=(255, 255, 255, 255), width=2 * f)
    return im.resize((tam, tam), Image.LANCZOS)


def letrero(alto_letra: int) -> Image.Image:
    f = 4
    ancho, alto = 256 * f, 32 * f
    im = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    fuente = ImageFont.truetype(str(FUENTE), alto_letra * f)
    letras, espacio = "ALFA", int(alto_letra * f * 0.42)
    anchos = [d.textlength(c, font=fuente) for c in letras]
    total = sum(anchos) + espacio * (len(letras) - 1)
    x = (ancho - total) / 2
    for c, w in zip(letras, anchos):
        d.text((x, alto / 2), c, font=fuente, fill=(255, 255, 255, 255), anchor="lm")
        x += w + espacio
    return im.resize((256, 32), Image.LANCZOS)


def main() -> int:
    SALIDA.mkdir(parents=True, exist_ok=True)
    piezas = {
        "emblem": lobo(128),
        "logo": logo(),
        "watermark": marca_de_agua(),
        "wordmark": letrero(26),
        "wordmark-small": letrero(20),
    }
    for nombre, im in piezas.items():
        im.save(SALIDA / f"{nombre}.tga")
    # Avatar del proyecto en CurseForge (400x400): el mismo logo, dibujado en grande.
    curse = RAIZ / "curseforge"
    curse.mkdir(exist_ok=True)
    grande = logo_grande(400)
    grande.save(curse / "avatar.png")
    if len(sys.argv) > 1:
        hoja = Image.new("RGBA", (560, 300), (30, 32, 38, 255))
        for nombre, pos in [("logo", (10, 10)), ("emblem", (90, 10)), ("watermark", (230, 10)),
                            ("wordmark", (10, 230)), ("wordmark-small", (280, 230))]:
            im = piezas[nombre]
            if nombre in ("emblem", "watermark", "wordmark", "wordmark-small"):
                verde = Image.new("RGBA", im.size, VERDE + (255,))
                verde.putalpha(im.getchannel("A"))
                im = verde if nombre != "watermark" else im
            hoja.alpha_composite(im, pos)
        hoja.alpha_composite(piezas["logo"].resize((128, 128), Image.LANCZOS), (10, 90))
        hoja.save(pathlib.Path(sys.argv[1]) / "marca_alfa.png")
    print("OK marca en", SALIDA)
    return 0


if __name__ == "__main__":
    sys.exit(main())
