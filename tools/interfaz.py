"""Dibuja las texturas de la interfaz propia de Alfa (Diseño A, moderno táctico).

Uso:  .venv/Scripts/python -I tools/interfaz.py [carpeta_vista_previa]

Escribe dos grupos de imagenes:

  marca/Alfa/Media/UI/   reemplazan texturas que ya trae el motor (las del
                         cielo nocturno de Polestar): band, band-stars, glow,
                         emblem-hot. La banda pasa a ser una cabecera lisa, las
                         estrellas y el centro del emblema quedan vacios, y el
                         brillo es una mancha octogonal tenue (sigue sirviendo
                         de aviso detras del boton del objeto de mision).
  motor/Alfa/Media/UI/   texturas nuevas de la interfaz: las esquinas cortadas
                         (cut, cut-line4..10), la perilla de los interruptores
                         (knob), los iconos de las secciones (sec-*) y de las
                         funciones (ic-*) y las variantes del lobo (lobo-*),
                         todos de tools/iconos.py con el mismo trazo. Se anotan
                         en motor/BASE.json como nuevas.

Todas son blancas con transparencia: el tema del juego las tine. Se dibujan a
8x y se reducen, para que los bordes diagonales queden suaves.
Con una carpeta, deja ahi una hoja PNG para verlas sobre el fondo grafito.
"""
import json
import math
import pathlib
import sys

from PIL import Image, ImageDraw

RAIZ = pathlib.Path(__file__).resolve().parent.parent
MARCA = RAIZ / "marca" / "Alfa" / "Media" / "UI"
NUEVAS = RAIZ / "motor" / "Alfa" / "Media" / "UI"
BASE = RAIZ / "motor" / "BASE.json"
F = 8  # sobremuestreo
BLANCO = (255, 255, 255, 255)

# Los cortes que usa Theme.lua (Theme.CUT): ventana 10, panel 8, control 6, chico 4.
CORTES = (4, 6, 8, 10)


def lienzo(tam):
    return Image.new("RGBA", (tam * F, tam * F), (0, 0, 0, 0))


def reducir(im, tam):
    return im.resize((tam, tam), Image.LANCZOS)


# ---------------------------------------------------------------------------
# Texturas que reemplazan las del motor
# ---------------------------------------------------------------------------

def banda():
    """La cabecera: lisa hasta la fila 120 y un fundido corto de 8 filas, por
    si una ventana la estira mas alla de su cabecera (1024 x 128, a 1:1)."""
    im = Image.new("RGBA", (1024, 128), (255, 255, 255, 255))
    px = im.load()
    for y in range(120, 128):
        a = int(255 * (127 - y) / 8)
        for x in range(1024):
            px[x, y] = (255, 255, 255, a)
    return im


def vacia(tam=8):
    return Image.new("RGBA", (tam, tam), (0, 0, 0, 0))


def brillo():
    """Una mancha octogonal tenue, sin halo: a lo mas 45 % y se apaga antes del borde."""
    tam = 64
    im = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    px = im.load()
    c = (tam - 1) / 2
    for y in range(tam):
        for x in range(tam):
            dx, dy = abs(x - c) / c, abs(y - c) / c
            d = max(dx, dy, (dx + dy) / 1.41421)  # distancia octogonal
            t = max(0.0, 1 - d / 0.92)
            px[x, y] = (255, 255, 255, int(255 * 0.45 * t * t))
    return im


# ---------------------------------------------------------------------------
# Esquinas cortadas
# ---------------------------------------------------------------------------

def corte():
    """La esquina de arriba a la izquierda de un panel: el triangulo de abajo a
    la derecha lleno (x + y >= lado). Abajo a la derecha se usa girada 180."""
    tam = 64
    im = lienzo(tam)
    d = ImageDraw.Draw(im)
    s = tam * F
    d.polygon([(s, 0), (s, s), (0, s)], fill=BLANCO)
    return reducir(im, tam)


def linea_de_corte(lado):
    """La diagonal del borde para un corte de `lado` unidades: una banda de una
    unidad de ancho, del lado de adentro de la hipotenusa."""
    tam = 64
    im = lienzo(tam)
    d = ImageDraw.Draw(im)
    s = tam * F
    grosor = s / lado  # una unidad, medida en perpendicular
    paso = grosor * math.sqrt(2)
    d.polygon([(s, 0), (s, paso), (paso, s), (0, s)], fill=BLANCO)
    return reducir(im, tam)


def perilla():
    """El cuadro de los interruptores y deslizadores, con sus dos esquinas cortadas."""
    tam = 32
    im = lienzo(tam)
    d = ImageDraw.Draw(im)
    s, c = tam * F, tam * F * 0.28
    d.polygon([(c, 0), (s, 0), (s, s - c), (s - c, s), (0, s), (0, c)], fill=BLANCO)
    return reducir(im, tam)


# ---------------------------------------------------------------------------
# Iconos propios (secciones sec-* y funciones ic-*) y las variantes del lobo:
# tools/iconos.py, con un solo trazo para todos (docs/KIT.md, "Iconos").
# ---------------------------------------------------------------------------

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import iconos  # noqa: E402


# ---------------------------------------------------------------------------

def hoja(piezas, carpeta: pathlib.Path):
    """Las texturas sobre el fondo grafito, tenidas como en el juego."""
    fondo, panel, verde, texto = (16, 20, 18), (24, 32, 27), (139, 224, 78), (230, 239, 228)
    celdas = [(n, im) for n, im in piezas.items() if n not in ("band", "band-stars", "emblem-hot")]
    ancho, alto = 120, 120
    cols = 9
    filas = (len(celdas) + cols - 1) // cols
    out = Image.new("RGB", (cols * ancho, filas * alto + 120), fondo)
    d = ImageDraw.Draw(out)
    for i, (nombre, im) in enumerate(celdas):
        x, y = (i % cols) * ancho, (i // cols) * alto
        d.rectangle([x + 8, y + 8, x + ancho - 8, y + alto - 30], fill=panel)
        color = verde if nombre.startswith(("sec-", "lobo-")) or nombre == "knob" else texto
        lado = 64 if im.size[0] <= 32 else 80
        g = im.resize((lado, lado * im.size[1] // im.size[0]), Image.LANCZOS)
        tinte = Image.new("RGBA", g.size, color + (255,))
        tinte.putalpha(g.getchannel("A"))
        out.paste(tinte, (x + (ancho - g.size[0]) // 2, y + (alto - 22 - g.size[1]) // 2), tinte)
        d.text((x + 10, y + alto - 24), nombre, fill=(138, 153, 139))
    # Un panel con las esquinas cortadas, armado como en Theme.CutShape.
    y0 = filas * alto + 10
    corte_im, linea_im = piezas["cut"], piezas["cut-line10"]
    w, h, c = 360, 90, 10
    caja = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    relleno = Image.new("RGBA", (w, h), (31, 42, 35, 255))
    mascara = Image.new("L", (w, h), 255)
    tl = corte_im.resize((c, c), Image.LANCZOS).getchannel("A")
    mascara.paste(tl, (0, 0))
    mascara.paste(tl.rotate(180), (w - c, h - c))
    caja.paste(relleno, (0, 0), mascara)
    borde = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    db = ImageDraw.Draw(borde)
    db.line([(c, 0), (w - 1, 0)], fill=(38, 48, 42, 255))
    db.line([(w - 1, 0), (w - 1, h - c)], fill=(38, 48, 42, 255))
    db.line([(w - c, h - 1), (0, h - 1)], fill=(38, 48, 42, 255))
    db.line([(0, h - 1), (0, c)], fill=(38, 48, 42, 255))
    ln = linea_im.resize((c, c), Image.LANCZOS).getchannel("A")
    for pos, img in (((0, 0), ln), ((w - c, h - c), ln.rotate(180))):
        capa = Image.new("RGBA", (c, c), (38, 48, 42, 255))
        capa.putalpha(img)
        borde.alpha_composite(capa, pos)
    caja.alpha_composite(borde)
    acento = Image.new("RGBA", (40, 2), verde + (255,))
    caja.alpha_composite(acento, (c + 6, 0))
    out.paste(caja, (20, y0), caja)
    d.text((40, y0 + 34), "Panel con esquinas cortadas (10 px)", fill=texto)
    carpeta.mkdir(parents=True, exist_ok=True)
    destino = carpeta / "interfaz-texturas.png"
    out.save(destino)
    print(f"hoja: {destino}")


def anotar_nuevas(nombres):
    base = json.loads(BASE.read_text(encoding="utf-8")) if BASE.exists() else {}
    for n in nombres:
        base.setdefault(f"Alfa/Media/UI/{n}.tga", None)
    BASE.write_text(json.dumps(base, indent=1, sort_keys=True), encoding="utf-8")


def main() -> int:
    MARCA.mkdir(parents=True, exist_ok=True)
    NUEVAS.mkdir(parents=True, exist_ok=True)
    reemplazos = {
        "band": banda(),
        "band-stars": vacia(),
        "emblem-hot": vacia(),
        "glow": brillo(),
    }
    nuevas = {"cut": corte(), "knob": perilla()}
    for lado in CORTES:
        nuevas[f"cut-line{lado}"] = linea_de_corte(lado)
    nuevas.update(iconos.todo())
    for nombre, im in reemplazos.items():
        im.save(MARCA / f"{nombre}.tga")
    for nombre, im in nuevas.items():
        im.save(NUEVAS / f"{nombre}.tga")
    anotar_nuevas(nuevas)
    print(f"{len(reemplazos)} texturas del motor reemplazadas en marca/, {len(nuevas)} nuevas en motor/")
    if len(sys.argv) > 1:
        hoja({**reemplazos, **nuevas}, pathlib.Path(sys.argv[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
