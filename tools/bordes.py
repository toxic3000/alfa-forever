"""Alfa - Mundo: las máscaras que difuminan la orilla de un mosaico del terreno.

Un mosaico del minimapa que da a un hueco (no hay mosaico al lado) se veía
como un cuadro pegado sobre el arte de abajo. Su máscara lo funde hacia ese
lado: borde-<n>.tga, con n la suma de los lados que dan a un hueco
(N = 1, E = 2, S = 4, O = 8), del 1 al 15. Lienzo.lua (Lz.Bordes) elige cuál.

Blanco con alfa (y el mismo valor en el color, por si el cliente lee otro
canal): 1 en el centro, 0 en la orilla de cada lado marcado, con una curva
suave a lo largo de ANCHO del lado.

    python -I tools/bordes.py
"""
import pathlib

from PIL import Image

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "src" / "Alfa_Mundo" / "Media" / "Borde"
LADO = 64      # texeles de la máscara (potencia de dos)
ANCHO = 0.22   # parte del mosaico que ocupa el difuminado de cada lado


def suave(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def valor(x, y, n):
    # x, y: el centro del texel en 0..1, y hacia abajo.
    a = 1.0
    if n & 1:
        a *= suave(y / ANCHO)          # norte: arriba
    if n & 2:
        a *= suave((1 - x) / ANCHO)    # este: derecha
    if n & 4:
        a *= suave((1 - y) / ANCHO)    # sur: abajo
    if n & 8:
        a *= suave(x / ANCHO)          # oeste: izquierda
    return a


def main():
    DESTINO.mkdir(parents=True, exist_ok=True)
    for n in range(1, 16):
        im = Image.new("RGBA", (LADO, LADO))
        px = im.load()
        for j in range(LADO):
            for i in range(LADO):
                v = round(255 * valor((i + 0.5) / LADO, (j + 0.5) / LADO, n))
                px[i, j] = (v, v, v, v)
        im.save(DESTINO / f"borde-{n}.tga")
    print(f"OK {DESTINO.relative_to(RAIZ)}: 15 máscaras de {LADO} x {LADO}")


if __name__ == "__main__":
    main()
