"""Arma las imágenes de la galería de CurseForge (curseforge/galeria/).

Uso:
  python -I tools/build.py
  .venv/Scripts/python -I tools/banco/run.py dist <módulos> galeria.lua   (dibuja tools/banco/shot-*.png)
  .venv/Scripts/python -I tools/galeria.py

Las vistas salen del banco (tools/banco/): el código real de Alfa dibujado
sobre el cliente simulado, con las texturas propias de Alfa. Lo que es arte
del juego (íconos de objetos, retratos de mazmorras) se ve como una ficha
sobria, porque el simulador no lo tiene. En cuanto haya capturas del juego,
van en curseforge/capturas/ y este script las enmarca igual (ver CAPTURAS).
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = pathlib.Path(__file__).resolve().parent.parent
BANCO = RAIZ / "tools" / "banco"
FUENTES = RAIZ / "dist" / "Alfa" / "Media" / "Fonts"
MARCA = RAIZ / "marca" / "Alfa" / "Media" / "UI"
SALIDA = RAIZ / "curseforge" / "galeria"
CAPTURAS = RAIZ / "curseforge" / "capturas"

ANCHO, ALTO = 1600, 1000
FONDO = (16, 20, 18)
PANEL = (24, 32, 27)
ACENTO = (139, 224, 78)
TEXTO = (232, 238, 230)
TENUE = (150, 165, 150)

# (archivo del banco, título, línea en español, línea en inglés)
VISTAS = [
    ("shot-g-inicio.png", "¿Qué hacemos hoy?", "Tu siguiente paso, tus misiones listas y tu clase en una sola página.",
     "Your next step, ready quests and your class on one page."),
    ("shot-v-asistente.png", "Dos clics y Alfa te lleva", "Elige subir de nivel, profesiones, oro o mazmorras y Alfa arma el plan.",
     "Pick leveling, professions, gold or dungeons and Alfa builds the plan."),
    ("shot-g-rutas.png", "Tu ruta", "La guía que te toca, tu plan de misiones y entregar todas las que tienes listas.",
     "Your guide, your quest plan and a route to turn in every ready quest."),
    ("shot-v-biblioteca.png", "Biblioteca de guías", "La recomendada para tu nivel y zona, y todas las demás.",
     "The guide that fits your level and zone, and all the others."),
    ("shot-v-enciclopedia.png", "Enciclopedia", "Todos los objetos, PNJ, misiones, zonas y raros, aunque no los tengas.",
     "Every item, NPC, quest, zone and rare, even if you don't own it."),
    ("shot-g-mazmorras.png", "Mazmorras", "La que te toca, qué misiones llevar y cómo llegar a la entrada.",
     "The dungeon for your level, which quests to bring and how to get there."),
    ("shot-g-bolsas.png", "Bolsas y banco", "Tres vistas, banco desde cualquier lugar y qué vender cuando se llenan.",
     "Three views, your bank from anywhere and what to sell when they fill up."),
    ("shot-g-manada.png", "La Jauría", "Tu grupo en el mapa, con permiso, y el clan a un clic.",
     "Your group on the map, with consent, and the guild one click away."),
    # 1.1.0 (tools/banco/galeria110.lua)
    ("shot-bv-quees.png", "Una bienvenida que te pregunta", "Elige el idioma de Alfa y decide, una por una, qué hace solo. Tú mandas.",
     "Pick Alfa's language and decide, one by one, what it does for you. You're in charge."),
    ("shot-lya-historias.png", "Lya y sus historias", "Tu loba compañera guarda la historia de cada misión y te cuenta datos de cada zona.",
     "Your companion she-wolf keeps every quest's story and tells you about each zone."),
    ("shot-pesca-diario.png", "Reingeniería de la pesca", "Una tecla para todo, diario de capturas, logros, metas y guía de 1 a 300.",
     "One key for everything, a catch journal, achievements, goals and a 1–300 guide."),
    ("shot-pesca-guia.png", "Guía de pesca", "Dónde pescar según tu habilidad, instructores, vendedores y el concurso.",
     "Where to fish for your skill, trainers, vendors and the contest."),
    ("shot-vista.png", "Paisaje y gráficos", "Los ajustes del juego en palabras simples, con preajustes y deshacer de un clic.",
     "The game's graphics settings in plain words, with presets and one-click undo."),
    ("shot-planes.png", "Mis planes", "Arma tus propias metas: objetos, oro, profesiones, lugares, misiones o niveles.",
     "Build your own goals: items, gold, professions, places, quests or levels."),
    ("shot-monturas.png", "Monturas y mascotas", "Cómo conseguir cada una, si ya la tienes y \"Guíame\".",
     "How to get each one, whether you already have it, and \"Guide me\"."),
    # 1.1.4 (las escenas de Lya y de la intro: ver curseforge/LEEME.md)
    ("shot-lya-poses.png", "Lya, tu loba compañera", "Negrita, con su pañoleta de Alfa: corre, se busca la cola, duerme, aúlla y pide salchichas.",
     "Black, with her Alfa bandana: she runs, chases her tail, sleeps, howls and begs for sausages."),
    ("shot-lya-globo.png", "Lya platica contigo", "Lore de Warcraft, datos de cada zona, de tu raza y tus profesiones, y consejos de amiga.",
     "Warcraft lore, facts about every zone, your race and professions, and friendly tips."),
    ("shot-intro.png", "Cada entrada, una bienvenida", "La intro del lobo y la luna te recibe al entrar al juego; con una versión nueva, después sale lo nuevo.",
     "The wolf and moon intro greets you when you log in; with a new version, what's new comes next."),
    ("shot-notas.png", "Lo nuevo, a la vista", "Al actualizar, una ventana te cuenta qué cambió. La cierras y sigues jugando.",
     "After an update, a window tells you what changed. Close it and keep playing."),
    # 1.3.6 (tools/banco/galeria136.lua, galeria.lua y manual.lua): al final, para
    # que las imágenes que ya usa curseforge/descripcion.md conserven su número.
    ("shot-136-buscador.png", "Busca en todo Alfa", "Escribe una palabra: Alfa te encuentra la página y el ajuste, y si no, te ofrece a Lya.",
     "Type a word: Alfa finds the page and the setting, or offers you Lya."),
    ("shot-136-lya-guia.png", "Pregúntale a Lya", "Todo Alfa explicado por Lya, con un clic que te lleva a donde se hace.",
     "All of Alfa explained by Lya, with a click that takes you where it's done."),
    ("shot-136-resumen.png", "Tu pelea, sin estorbar", "Al terminar una pelea, tu daño y lo que más te pegó, junto a tus barras y nunca encima.",
     "After a fight, your damage and what hit you hardest, next to your bars, never on top."),
    ("shot-g-builds.png", "Talentos", "Qué talento poner ahora, tu plan de talentos y tu equipo.",
     "Which talent to take now, your talent plan and your gear."),
    ("shot-manual-curacion.png", "Curación con un clic", "Marcos de grupo y banda: cura, selecciona y quita perjuicios con tus clics.",
     "Party and raid frames: heal, target and cleanse with your clicks."),
    ("shot-g-mundo.png", "Mundo", "El mapa de Alfa: el mundo entero, tus marcadores y un solo control de capas.",
     "Alfa's map: the whole world, your markers and one layer control."),
    ("shot-v-rastreador.png", "Tu rastreador", "Tu paso de ahora, la flecha y lo que sigue, siempre a la vista y compacto.",
     "Your current step, the arrow and what's next, always in view and compact."),
    ("shot-manual-comercio.png", "Comercio", "¿Vender, subastar o transformar? Lo que más oro te deja con cada objeto.",
     "Vendor, auction or craft? What makes you the most gold with each item."),
    ("shot-manual-recoleccion.png", "Recolección", "Minas, hierbas, pesca y tesoros, con rutas para juntar.",
     "Mining, herbs, fishing and treasures, with gathering routes."),
    ("shot-manual-comodidades.png", "Comodidades", "Detalles que hacen el juego más cómodo, todos en un lugar.",
     "Little touches that make the game more comfortable, all in one place."),
]


def fuente(nombre, tam):
    return ImageFont.truetype(str(FUENTES / nombre), tam)


def fondo_marca():
    """Fondo oscuro con un brillo verde suave arriba a la izquierda."""
    im = Image.new("RGB", (ANCHO, ALTO), FONDO)
    brillo = Image.new("L", (ANCHO, ALTO), 0)
    d = ImageDraw.Draw(brillo)
    d.ellipse([-500, -600, 900, 500], fill=70)
    d.ellipse([1100, 600, 2200, 1500], fill=35)
    brillo = brillo.filter(ImageFilter.GaussianBlur(220))
    verde = Image.new("RGB", (ANCHO, ALTO), (40, 70, 30))
    im.paste(verde, (0, 0), brillo)
    return im


def logo(tam):
    p = MARCA / "logo.tga"
    if not p.exists():
        p = RAIZ / "curseforge" / "avatar.png"
    im = Image.open(p).convert("RGBA")
    im.thumbnail((tam, tam), Image.LANCZOS)
    return im


def sombra(im, radio=24, opacidad=170):
    w, h = im.size
    s = Image.new("RGBA", (w + radio * 4, h + radio * 4), (0, 0, 0, 0))
    ImageDraw.Draw(s).rectangle([radio * 2, radio * 2 + 10, radio * 2 + w, radio * 2 + h + 10], fill=(0, 0, 0, opacidad))
    return s.filter(ImageFilter.GaussianBlur(radio))


def cabecera(im, titulo, es, en):
    d = ImageDraw.Draw(im)
    lg = logo(64)
    im.paste(lg, (56, 40), lg)
    d.text((140, 44), titulo, font=fuente("Inter-SemiBold.ttf", 40), fill=TEXTO)
    d.text((140, 96), es, font=fuente("Inter-Regular.ttf", 22), fill=TENUE)
    d.rectangle([56, 128 + 14, 56 + 44, 128 + 17], fill=ACENTO)
    d.text((ANCHO - 56, 52), "ALFA", font=fuente("Inter-SemiBold.ttf", 22), fill=ACENTO, anchor="ra")
    d.text((ANCHO - 56, 84), "toxic3000 · La Jauría", font=fuente("Inter-Regular.ttf", 18), fill=TENUE, anchor="ra")
    d.text((ANCHO // 2, ALTO - 34), en, font=fuente("Inter-Regular.ttf", 18), fill=TENUE, anchor="mm")


def enmarcar(vista, titulo, es, en):
    im = fondo_marca()
    cabecera(im, titulo, es, en)
    caja_w, caja_h = ANCHO - 160, ALTO - 170 - 80
    v = vista.convert("RGB")
    v.thumbnail((caja_w, caja_h), Image.LANCZOS)
    x = (ANCHO - v.width) // 2
    y = 170 + (caja_h - v.height) // 2
    s = sombra(v)
    im.paste(s, (x - 48, y - 48), s)
    im.paste(v, (x, y))
    ImageDraw.Draw(im).rectangle([x - 1, y - 1, x + v.width, y + v.height], outline=(52, 70, 56))
    return im


def portada(vistas):
    """La imagen principal: marca a la izquierda, dos vistas encimadas a la derecha."""
    im = fondo_marca()
    d = ImageDraw.Draw(im)
    lg = logo(150)
    im.paste(lg, (90, 150), lg)
    d.text((90, 330), "Alfa", font=fuente("Inter-SemiBold.ttf", 110), fill=TEXTO)
    d.text((94, 470), "Guía a tu manada", font=fuente("Inter-Medium.ttf", 40), fill=ACENTO)
    d.multiline_text((94, 540), "El todo en uno para WoW Forever:\nguías, mapa, pesca, Lya, talentos,\nenciclopedia, mazmorras y tu clan.",
                     font=fuente("Inter-Regular.ttf", 28), fill=TENUE, spacing=10)
    d.text((94, 720), "Hecho por toxic3000", font=fuente("Inter-SemiBold.ttf", 30), fill=TEXTO)
    d.text((94, 762), "para La Jauría · 10 idiomas · GPL-3.0", font=fuente("Inter-Regular.ttf", 24), fill=TENUE)
    atras, frente = vistas
    for v, (x, y, w) in ((atras, (820, 90, 700)), (frente, (700, 380, 760))):
        v = v.convert("RGB").copy()
        v.thumbnail((w, 1000), Image.LANCZOS)
        s = sombra(v, 30, 200)
        im.paste(s, (x - 60, y - 60), s)
        im.paste(v, (x, y))
        ImageDraw.Draw(im).rectangle([x - 1, y - 1, x + v.width, y + v.height], outline=(52, 70, 56))
    return im


def lya_sprite(cuadro=0, escala=4):
    """Lya (src/Alfa_Lya/Media/lya-cuerpo*.tga, celda `cuadro`) con su borde verde, en pixel art."""
    media = RAIZ / "src" / "Alfa_Lya" / "Media"
    pelo = Image.open(media / "lya-cuerpo.tga").convert("RGBA")
    borde = Image.open(media / "lya-cuerpo-borde.tga").convert("RGBA")
    cw, ch, cols = 60, 54, 17
    x, y = (cuadro % cols) * cw, (cuadro // cols) * ch
    caja = (x, y, x + cw, y + ch)
    p, b = pelo.crop(caja), borde.crop(caja)
    verde = Image.new("RGBA", b.size, ACENTO + (255,))
    tenido = Image.new("RGBA", b.size, (0, 0, 0, 0))
    tenido.paste(verde, (0, 0), b.split()[3].point(lambda v: int(v * 0.85)))
    tenido.alpha_composite(p)
    return tenido.resize((cw * escala, ch * escala), Image.NEAREST)


def banner():
    """El encabezado ancho de CurseForge y del README: la marca, lo que es y lo
    mejor de Alfa a la vista (tres ventanas y Lya)."""
    ancho, alto = 1600, 600
    im = Image.new("RGB", (ancho, alto), FONDO)
    brillo = Image.new("L", (ancho, alto), 0)
    dd = ImageDraw.Draw(brillo)
    dd.ellipse([-400, -500, 900, 520], fill=80)
    dd.ellipse([900, 200, 2000, 1100], fill=40)
    brillo = brillo.filter(ImageFilter.GaussianBlur(200))
    im.paste(Image.new("RGB", (ancho, alto), (40, 70, 30)), (0, 0), brillo)
    d = ImageDraw.Draw(im)
    lg = logo(96)
    im.paste(lg, (80, 70), lg)
    d.text((80, 180), "Alfa", font=fuente("Inter-SemiBold.ttf", 96), fill=TEXTO)
    d.text((84, 300), "Guía a tu manada · Lead your pack", font=fuente("Inter-Medium.ttf", 30), fill=ACENTO)
    d.multiline_text((84, 356), "El todo en uno para WoW Forever:\nguías, mapa, pesca, Lya y mucho más.",
                     font=fuente("Inter-Regular.ttf", 26), fill=TENUE, spacing=10)
    x = 84
    for chip in ("Gratis", "10 idiomas", "Hecho por toxic3000"):
        f = fuente("Inter-SemiBold.ttf", 20)
        w = d.textlength(chip, font=f) + 28
        d.rounded_rectangle([x, 470, x + w, 508], radius=6, outline=ACENTO, width=2)
        d.text((x + 14, 489), chip, font=f, fill=TEXTO, anchor="lm")
        x += w + 12
    # tres ventanas encimadas a la derecha
    capas = [("shot-g-mundo.png", (900, 40, 600)), ("shot-pesca-diario.png", (1000, 230, 520)), ("shot-g-inicio.png", (760, 280, 560))]
    for archivo, (vx, vy, vw) in capas:
        if not (BANCO / archivo).exists():
            continue
        v = Image.open(BANCO / archivo).convert("RGB")
        v.thumbnail((vw, 1000), Image.LANCZOS)
        s = sombra(v, 26, 190)
        im.paste(s, (vx - 52, vy - 52), s)
        im.paste(v, (vx, vy))
        ImageDraw.Draw(im).rectangle([vx - 1, vy - 1, vx + v.width, vy + v.height], outline=(52, 70, 56))
    try:
        ly = lya_sprite(0, 3)
        im.paste(ly, (590, alto - ly.height - 24), ly)
    except FileNotFoundError:
        pass
    return im


def main() -> int:
    SALIDA.mkdir(parents=True, exist_ok=True)
    faltan = [a for a, *_ in VISTAS if not (BANCO / a).exists()]
    if faltan:
        # 1.3.2: una vista que el banco no dibujó se queda con su imagen de antes.
        print("AVISO: sin vista nueva del banco, se queda la imagen de antes:", ", ".join(faltan))
    for viejo in SALIDA.glob("*.png"):
        if not any(viejo.name.endswith(a[len("shot-"):]) for a in faltan):
            viejo.unlink()
    portada([Image.open(BANCO / "shot-g-rutas.png"), Image.open(BANCO / "shot-g-inicio.png")]).save(SALIDA / "00-portada.png")
    banner().save(SALIDA / "00-banner.png")
    for i, (archivo, titulo, es, en) in enumerate(VISTAS, 1):
        if archivo in faltan:
            continue
        nombre = archivo[len("shot-"):]
        for prefijo in ("g-", "v-"):
            if nombre.startswith(prefijo):
                nombre = nombre[len(prefijo):]
        enmarcar(Image.open(BANCO / archivo), titulo, es, en).save(SALIDA / f"{i:02d}-{nombre}")
    # capturas del juego, si las hay: curseforge/capturas/<nombre>.png|jpg -> galeria/juego-<nombre>.png
    if CAPTURAS.is_dir():
        for c in sorted(CAPTURAS.iterdir()):
            if c.suffix.lower() in (".png", ".jpg", ".jpeg"):
                titulo = c.stem.split("-", 1)[-1].replace("_", " ").capitalize()
                enmarcar(Image.open(c), titulo, "", "").save(SALIDA / f"juego-{c.stem}.png")
    print(f"OK {SALIDA}: {len(list(SALIDA.glob('*.png')))} imágenes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
