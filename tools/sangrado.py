"""Bordes limpios en las texturas de Alfa (1.1.7 -> 1.1.8).

Al escalar o filtrar una textura, el juego mezcla cada pixel con sus vecinos.
Si los pixeles transparentes guardan color negro (lo normal al exportar), esa
mezcla oscurece la orilla del icono: un borde negro y sucio, sobre todo al
tenirlo de color o al hacer zoom en el mapa. Aqui, sin cambiar lo que se ve
de cerca:

1. Orillas premultiplicadas: un pixel semitransparente cuyo color es el de su
   vecino opaco multiplicado por su alfa (un blanco que quedo gris, un verde
   que quedo oscuro) recupera su color. Las sombras de verdad (negras desde
   antes) se quedan como estan.
2. Sangrado: cada pixel del todo transparente toma el color del pixel visible
   mas cercano. Su alfa sigue en 0, asi que no se ve, pero el filtro ya no
   mezcla negro.

Lo usa tools/build.py sobre dist/ (los archivos de origen no cambian):
  aplicar(carpeta) -> (revisadas, cambiadas)
Uso suelto:  python -I tools/sangrado.py <archivo.tga o carpeta> [--revisar]
"""
import pathlib
import sys
from collections import deque

from PIL import Image

TOLERANCIA = 14    # diferencia por canal para reconocer una orilla premultiplicada
OSCURECIDO = 30    # cuanto mas oscura que su vecino opaco debe estar para corregirla


def _vecinos(i, w, h):
    x, y = i % w, i // w
    if x > 0:
        yield i - 1
    if x < w - 1:
        yield i + 1
    if y > 0:
        yield i - w
    if y < h - 1:
        yield i + w


def limpiar(img: Image.Image) -> Image.Image | None:
    """La imagen con sus orillas limpias, o None si no hacia falta."""
    if img.mode != "RGBA":
        return None
    w, h = img.size
    px = list(img.getdata())
    n = w * h
    cambio = False
    # 1. Orillas premultiplicadas.
    for i in range(n):
        r, g, b, a = px[i]
        if not (0 < a < 255):
            continue
        for j in _vecinos(i, w, h):
            R, G, B, A = px[j]
            if A != 255 or max(R, G, B) < 40:
                continue
            f = a / 255
            if (abs(r - R * f) <= TOLERANCIA and abs(g - G * f) <= TOLERANCIA and abs(b - B * f) <= TOLERANCIA
                    and (R + G + B) - (r + g + b) > OSCURECIDO):
                px[i] = (R, G, B, a)
                cambio = True
                break
    # 2. Sangrado hacia los transparentes (BFS desde lo visible).
    color = [None] * n
    cola = deque()
    for i in range(n):
        if px[i][3] > 0:
            color[i] = px[i][:3]
            cola.append(i)
    if not cola:
        return img if cambio else None
    while cola:
        i = cola.popleft()
        c = color[i]
        for j in _vecinos(i, w, h):
            if color[j] is None:
                color[j] = c
                cola.append(j)
    for i in range(n):
        r, g, b, a = px[i]
        if a == 0 and (r, g, b) != color[i]:
            px[i] = (*color[i], 0)
            cambio = True
    if not cambio:
        return None
    out = Image.new("RGBA", (w, h))
    out.putdata(px)
    return out


def orillas_sucias(img: Image.Image) -> int:
    """Pixeles transparentes junto a uno visible cuyo color es negro mientras el
    visible no lo es: lo que deja el borde oscuro al filtrar."""
    if img.mode != "RGBA":
        return 0
    w, h = img.size
    px = list(img.getdata())
    malos = 0
    for i, (r, g, b, a) in enumerate(px):
        if a != 0 or r + g + b > 30:
            continue
        for j in _vecinos(i, w, h):
            R, G, B, A = px[j]
            if A > 0 and R + G + B > 120:
                malos += 1
                break
    return malos


def aplicar(carpeta: pathlib.Path) -> tuple:
    revisadas = cambiadas = 0
    for tga in sorted(carpeta.rglob("*.tga")):
        with Image.open(tga) as img:
            img.load()
            compresion = img.info.get("compression")
            nueva = limpiar(img)
        revisadas += 1
        if nueva is not None:
            if compresion:
                nueva.save(tga, compression=compresion)
            else:
                nueva.save(tga)
            cambiadas += 1
    return revisadas, cambiadas


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    ruta = pathlib.Path(sys.argv[1])
    archivos = [ruta] if ruta.is_file() else sorted(ruta.rglob("*.tga"))
    if "--revisar" in sys.argv:
        total = 0
        for f in archivos:
            with Image.open(f) as img:
                m = orillas_sucias(img.convert("RGBA") if img.mode == "RGBA" else img)
            if m:
                print(f"{f}: {m} pixeles de orilla sucia")
            total += m
        print(f"{len(archivos)} texturas, {total} pixeles de orilla sucia")
        return 1 if total else 0
    r, c = aplicar(ruta) if ruta.is_dir() else (1, 0)
    print(f"{r} texturas revisadas, {c} limpiadas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
