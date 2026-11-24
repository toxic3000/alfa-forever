"""Dibuja el ícono del Lobo Malo, el que caza bichos (Alfa 1.3.9, mejora 101).

Uso:  python -I tools/lobo_malo.py   ->  src/Alfa_Nucleo/Media/lobo-malo.tga

La misma cabeza del lobo de Alfa (tools/marca.py), pero oscura, con los ojos
rojos y una ceja de pícaro, y una red chiquita con un bicho verde adentro.
Simpático, no aterrador: es el lobo que atrapa los errores de Alfa.
128 px dibujados a 4x y reducidos (bordes suaves); TGA de 32 bits sin
compresión, a color (el juego no lo tiñe).
"""
import pathlib
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import marca  # noqa: E402  (la silueta del lobo de Alfa)

SALIDA = pathlib.Path(__file__).resolve().parent.parent / "src" / "Alfa_Nucleo" / "Media" / "lobo-malo.tga"
TAM, F = 128, 4

PELO = (46, 46, 58, 255)        # el lobo oscuro
FACETA = (78, 78, 96, 255)      # el volumen de la cabeza
BORDE = (18, 18, 24, 255)
OJO = (236, 48, 44, 255)        # los ojos rojos
BRILLO = (255, 214, 200, 255)
NARIZ = (20, 20, 26, 255)
RED = (214, 196, 150, 255)      # la red, de cuerda
PALO = (150, 104, 60, 255)
BICHO = (124, 214, 74, 255)
BICHO_OSCURO = (56, 120, 36, 255)


def p(x, y, dx=0, dy=0, s=1.0, cx=64, cy=64):
    return ((cx + (x - cx) * s + dx) * F, (cy + (y - cy) * s + dy) * F)


def dibujar():
    im = Image.new("RGBA", (TAM * F, TAM * F), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # La cabeza un poco más chica y a la izquierda: la red va a la derecha, abajo.
    m = dict(dx=-10, dy=-4, s=0.84)
    sil = [p(x, y, **m) for x, y in marca.SILUETA]
    d.polygon(sil, fill=PELO)
    d.line(sil + [sil[0]], fill=BORDE, width=3 * F, joint="curve")
    for faceta in marca.FACETAS:
        d.polygon([p(x, y, **m) for x, y in faceta], fill=FACETA)
    # Los ojos rojos, con su brillo (lo que lo hace simpático).
    for ojo in marca.OJOS:
        pts = [p(x, y, **m) for x, y in ojo]
        d.polygon(pts, fill=OJO)
        cx = sum(q[0] for q in pts) / 3
        cy = sum(q[1] for q in pts) / 3
        r = 1.6 * F
        d.ellipse([cx - r, cy - r - F, cx + r, cy + r - F], fill=BRILLO)
    # Las cejas de pícaro: inclinadas hacia la nariz.
    d.line([p(34, 52, **m), p(56, 58, **m)], fill=BORDE, width=4 * F)
    d.line([p(94, 52, **m), p(72, 58, **m)], fill=BORDE, width=4 * F)
    d.polygon([p(x, y, **m) for x, y in marca.NARIZ], fill=NARIZ)
    # Una sonrisa de lado.
    a = p(54, 106, **m)
    b = p(78, 104, **m)
    d.arc([a[0], a[1] - 6 * F, b[0], b[1] + 6 * F], 20, 160, fill=BORDE, width=3 * F)
    # La red: el palo, el aro y la malla, con el bicho adentro.
    d.line([(78 * F, 124 * F), (98 * F, 98 * F)], fill=PALO, width=5 * F)
    cx, cy, r = 108 * F, 86 * F, 17 * F
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(214, 196, 150, 60), outline=RED, width=4 * F)
    for k in range(-2, 3):
        off = k * 7 * F
        d.line([(cx + off, cy - r + 3 * F), (cx + off, cy + r - 3 * F)], fill=RED, width=1 * F + 2)
        d.line([(cx - r + 3 * F, cy + off), (cx + r - 3 * F, cy + off)], fill=RED, width=1 * F + 2)
    # El bicho: un escarabajo verde con sus patitas.
    bx, by = cx, cy + 1 * F
    for dy in (-4, 0, 4):
        d.line([(bx - 10 * F, by + dy * F - F), (bx + 10 * F, by + dy * F + F)], fill=BICHO_OSCURO, width=2 * F)
    d.ellipse([bx - 6 * F, by - 7 * F, bx + 6 * F, by + 7 * F], fill=BICHO, outline=BICHO_OSCURO, width=F + 2)
    d.line([(bx, by - 7 * F), (bx, by + 7 * F)], fill=BICHO_OSCURO, width=F + 2)
    d.ellipse([bx - 3 * F, by - 11 * F, bx + 3 * F, by - 5 * F], fill=BICHO_OSCURO)
    d.line([(bx - 2 * F, by - 10 * F), (bx - 6 * F, by - 15 * F)], fill=BICHO_OSCURO, width=F + 2)
    d.line([(bx + 2 * F, by - 10 * F), (bx + 6 * F, by - 15 * F)], fill=BICHO_OSCURO, width=F + 2)
    return im.resize((TAM, TAM), Image.LANCZOS)


def main():
    im = dibujar()
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    im.save(SALIDA)
    if len(sys.argv) > 1:  # una vista grande para revisarlo (PNG)
        fondo = Image.new("RGBA", im.size, (24, 30, 44, 255))
        fondo.alpha_composite(im)
        fondo.resize((256, 256), Image.LANCZOS).save(sys.argv[1])
    print(f"listo: {SALIDA}")


if __name__ == "__main__":
    main()
