"""Arma el manual de usuario de Alfa en PDF, uno por idioma (docs/manual/).

Uso (desde la raíz del proyecto, con WoW abierto o cerrado, da igual):
  python -I tools/manual.py                    los 10 PDF
  python -I tools/manual.py esMX deDE          solo esos idiomas
  python -I tools/manual.py --capturas         antes, copia las capturas nuevas del banco
                                               y del instalador a docs/manual/imagenes/
  python -I tools/manual.py --html CARPETA     deja también el HTML de cada idioma
  python -I tools/manual.py --revisar CARPETA  pinta cada página a PNG (y hojas de muestra)
                                               en CARPETA para revisarlas a ojo

Cómo está hecho:
  - Los textos de cada idioma están en docs/manual/textos/<idioma>.json (mismo
    orden y mismos bloques en todos; el español de México manda). Ver
    docs/manual/LEEME.md para el formato de los bloques.
  - Las capturas van en docs/manual/imagenes/ (salen del banco de pruebas:
    tools/banco/run.py ... galeria.lua, galeria110.lua y manual.lua; con
    --capturas se copian y se recortan aquí). Los íconos (motor/Alfa/Media/UI),
    las poses de Lya (src/Alfa_Lya/Media) y la marca se convierten en cada corrida.
  - La plantilla es HTML y CSS; Microsoft Edge (sin ventana, con Playwright) la
    imprime a PDF. Si Playwright no está, se usa msedge --print-to-pdf.
  - Dos pasadas: la primera mide en qué página empieza cada capítulo (con el
    índice del PDF) y la segunda escribe esos números en el índice.
  - Letras: Inter y Fira Sans (SIL OFL 1.1, en docs/manual/letras) y, para
    coreano y chino, las del sistema (Malgun Gothic, Microsoft YaHei y Microsoft
    JhengHei, que Windows permite incrustar en documentos).
  - Revisión: antes de imprimir se buscan textos que se salgan de su caja; después,
    páginas vacías o casi vacías y letras que ninguna fuente tenga (cuadritos).

La caja "Novedad" del mapa: NOVEDADES abajo (versión) y "novedades" en cada JSON.
Hecho por toxic3000 / La Jauría. GPL-3.0.
"""
import base64
import html
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

RAIZ = pathlib.Path(__file__).resolve().parent.parent
MANUAL = RAIZ / "docs" / "manual"
TEXTOS = MANUAL / "textos"
IMAGENES = MANUAL / "imagenes"
LETRAS = MANUAL / "letras"
UI_MOTOR = RAIZ / "motor" / "Alfa" / "Media" / "UI"
MARCA = RAIZ / "marca" / "Alfa" / "Media" / "UI"
LYA_MEDIA = RAIZ / "src" / "Alfa_Lya" / "Media"
LYA_LUA = RAIZ / "src" / "Alfa_Lya" / "Lya.lua"
BANCO = RAIZ / "tools" / "banco"

JUEGO = "1.60.1"   # la versión de WoW Forever para la que es Alfa

# idioma: (archivo PDF, etiqueta HTML, letra para su escritura)
IDIOMAS = {
    "esMX": ("Alfa-Manual-Espanol-Mexico.pdf", "es-MX", None),
    "esES": ("Alfa-Manual-Espanol-Espana.pdf", "es-ES", None),
    "enUS": ("Alfa-Manual-English.pdf", "en", None),
    "deDE": ("Alfa-Manual-Deutsch.pdf", "de", None),
    "frFR": ("Alfa-Manual-Francais.pdf", "fr", None),
    "ptBR": ("Alfa-Manual-Portugues-Brasil.pdf", "pt-BR", None),
    "ruRU": ("Alfa-Manual-Russian.pdf", "ru", None),
    "koKR": ("Alfa-Manual-Korean.pdf", "ko", ("Malgun Gothic", ["malgun.ttf", "malgunbd.ttf"])),
    "zhCN": ("Alfa-Manual-Chinese-Simplified.pdf", "zh-Hans", ("Microsoft YaHei", ["msyh.ttc", "msyhbd.ttc"])),
    "zhTW": ("Alfa-Manual-Chinese-Traditional.pdf", "zh-Hant", ("Microsoft JhengHei", ["msjh.ttc", "msjhbd.ttc"])),
}

# La caja "Novedad" de cada capítulo: clave del JSON -> versión de Alfa que la trae.
# Si la versión de tools/alfa.json ya llegó a esa versión, la caja dice "Lo nuevo
# desde la X" en lugar de "Lo que llega con la X". Para quitarla, borra su bloque
# {"t": "novedad", ...} de los JSON (o la entrada de aquí: entonces no sale).
NOVEDADES = {"mapa": "1.3.6"}

# Capturas: id -> (archivo de origen, recorte (x0, y0, x1, y1) o None).
# Con --capturas se copian a docs/manual/imagenes/<id>.png.
VENTANA = (0, 4, 1175, 875)   # el banco deja una rayita verde arriba
CAPTURAS = {
    "intro": ("tools/banco/shot-intro.png", (680, 40, 1720, 1010)),
    "inicio": ("tools/banco/shot-g-inicio.png", VENTANA),
    "rutas": ("tools/banco/shot-g-rutas.png", VENTANA),
    "builds": ("tools/banco/shot-g-builds.png", VENTANA),
    "bolsas": ("tools/banco/shot-g-bolsas.png", VENTANA),
    "manada": ("tools/banco/shot-g-manada.png", VENTANA),
    "mazmorras": ("tools/banco/shot-g-mazmorras.png", VENTANA),
    "mundo": ("tools/banco/shot-g-mundo.png", VENTANA),
    "asistente": ("tools/banco/shot-v-asistente.png", None),
    "biblioteca": ("tools/banco/shot-v-biblioteca.png", None),
    "enciclopedia": ("tools/banco/shot-v-enciclopedia.png", None),
    "rastreador": ("tools/banco/shot-v-rastreador.png", None),
    "monturas": ("tools/banco/shot-monturas.png", None),
    "planes": ("tools/banco/shot-planes.png", None),
    "cerca": ("tools/banco/shot-cerca.png", None),
    "lya-globo": ("tools/banco/shot-lya-globo.png", None),
    "lya-historias": ("tools/banco/shot-lya-historias.png", None),
    "pesca-diario": ("tools/banco/shot-pesca-diario.png", None),
    "pesca-barra": ("tools/banco/shot-pesca-barra.png", None),
    "vista": ("tools/banco/shot-vista.png", None),
    "notas": ("tools/banco/shot-notas.png", None),
    "bv-quees": ("tools/banco/shot-bv-quees.png", None),
    "curacion": ("tools/banco/shot-manual-curacion.png", VENTANA),
    "comercio": ("tools/banco/shot-manual-comercio.png", VENTANA),
    "recoleccion": ("tools/banco/shot-manual-recoleccion.png", VENTANA),
    "comodidades": ("tools/banco/shot-manual-comodidades.png", VENTANA),
    "lya": ("tools/banco/shot-manual-lya.png", VENTANA),
    "pesca": ("tools/banco/shot-manual-pesca.png", VENTANA),
    "misiones": ("tools/banco/shot-manual-questing.png", VENTANA),
    "estilo": ("tools/banco/shot-manual-bienvenida.png", VENTANA),
    "reportar": ("tools/banco/shot-manual-reportar.png", None),
    "instalador": ("instalador:2-carpeta.png", None),
}

# Llamadas numeradas sobre una captura: (id, juego) -> [(x, y)] en pixeles del
# archivo de ORIGEN (antes del recorte). El JSON trae la leyenda en el mismo orden.
MARCAS = {
    ("inicio", "ventana"): [(224, 20), (834, 32), (24, 110), (1019, 110), (26, 841)],
    ("inicio", "hoy"): [(44, 250), (44, 489), (42, 627), (26, 706)],
    ("rastreador", "partes"): [(232, 60), (346, 67), (366, 106), (240, 157), (141, 202), (241, 202)],
}

# Íconos de Alfa por nombre corto -> archivo ic-*.tga del motor
ICONO_DEF = "ic-huella"

# Poses de Lya para el manual (las del juego: src/Alfa_Lya/Lya.lua, ORDEN)
POSES = ["sentada1", "atenta1", "quieta1", "pedir2", "correr3", "cola2", "dormir2", "aullar2", "saltar2",
         "estirarse2"]

VERDE = (139, 224, 78)
VERDE_TINTA = (47, 106, 18)


def leer_version() -> str:
    return json.loads((RAIZ / "tools" / "alfa.json").read_text(encoding="utf-8"))["version"]


def vnum(v: str):
    return tuple(int(x) for x in re.findall(r"\d+", v))


# ---------------------------------------------------------------------------
# Capturas (--capturas)
# ---------------------------------------------------------------------------
def capturas() -> None:
    """Copia y recorta las capturas del banco y del instalador a docs/manual/imagenes."""
    IMAGENES.mkdir(parents=True, exist_ok=True)
    inst = None
    for ident, (origen, recorte) in CAPTURAS.items():
        if origen.startswith("instalador:"):
            if inst is None:
                inst = pathlib.Path(tempfile.mkdtemp(prefix="alfa-inst-"))
                subprocess.run([sys.executable, "-I", str(RAIZ / "instalador" / "instalador.py"),
                                "--capturas", str(inst)], check=False, capture_output=True)
            ruta = inst / origen.split(":", 1)[1]
        else:
            ruta = RAIZ / origen
        if not ruta.exists():
            print("  falta la captura", origen, "(se queda la que había)")
            continue
        im = Image.open(ruta).convert("RGB")
        if recorte:
            im = im.crop(recorte)
        im.save(IMAGENES / f"{ident}.png", optimize=True)
        print("  captura", ident, im.size)
    if inst:
        shutil.rmtree(inst, ignore_errors=True)


# ---------------------------------------------------------------------------
# Recursos que se arman en cada corrida (íconos, Lya, marca, estrellas)
# ---------------------------------------------------------------------------
def tenir(im: Image.Image, color) -> Image.Image:
    """Un ícono blanco con alfa, teñido de un color (como hace el juego)."""
    im = im.convert("RGBA")
    capa = Image.new("RGBA", im.size, color + (255,))
    capa.putalpha(im.getchannel("A"))
    return capa


def orden_lya() -> list:
    texto = LYA_LUA.read_text(encoding="utf-8")
    m = re.search(r"local ORDEN = \{(.*?)\n\}", texto, re.S)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []


def pose_lya(nombre: str, escala: int = 6):
    orden = orden_lya()
    if nombre not in orden:
        return None
    i = orden.index(nombre)
    w, h, cols = 60, 54, 1024 // 60
    caja = ((i % cols) * w, (i // cols) * h, (i % cols) * w + w, (i // cols) * h + h)
    piel = Image.open(LYA_MEDIA / "lya-cuerpo.tga").convert("RGBA").crop(caja)
    borde = tenir(Image.open(LYA_MEDIA / "lya-cuerpo-borde.tga").crop(caja), VERDE)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    im.alpha_composite(borde)
    im.alpha_composite(piel)
    caja = im.getbbox() or (0, 0, w, h)
    im = im.crop((caja[0], 0, caja[2], h))   # el suelo siempre a la misma altura
    return im.resize((im.width * escala, im.height * escala), Image.NEAREST)


def estrellas(destino: pathlib.Path, ancho=1240, alto=1754, semilla=7) -> None:
    import random
    from PIL import ImageDraw, ImageFilter
    r = random.Random(semilla)
    im = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for _ in range(140):
        x, y = r.uniform(0, ancho), r.uniform(0, alto)
        t = r.choice([1.0, 1.0, 1.4, 1.8, 2.6])
        a = int(r.uniform(70, 210))
        d.ellipse((x - t, y - t, x + t, y + t), fill=(220, 235, 225, a))
        if t > 2:
            d.line((x - 4 * t, y, x + 4 * t, y), fill=(220, 235, 225, a // 2), width=1)
            d.line((x, y - 4 * t, x, y + 4 * t), fill=(220, 235, 225, a // 2), width=1)
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(destino)


def recursos(carpeta: pathlib.Path) -> dict:
    """Convierte íconos, poses y marca a PNG en `carpeta`. Devuelve rutas relativas."""
    rec = {"icono": {}, "icono_tinta": {}, "pose": {}, "img": {}}
    (carpeta / "r").mkdir(parents=True, exist_ok=True)
    for tga in sorted(UI_MOTOR.glob("ic-*.tga")):
        nombre = tga.stem[3:]
        base = Image.open(tga)
        tenir(base, VERDE).save(carpeta / "r" / f"ic-{nombre}-v.png")
        tenir(base, VERDE_TINTA).save(carpeta / "r" / f"ic-{nombre}-t.png")
        rec["icono"][nombre] = f"r/ic-{nombre}-v.png"
        rec["icono_tinta"][nombre] = f"r/ic-{nombre}-t.png"
    for p in POSES:
        im = pose_lya(p)
        if im is not None:
            im.save(carpeta / "r" / f"lya-{p}.png")
            rec["pose"][p] = (f"r/lya-{p}.png", im.width, im.height)
    marca = tenir(Image.open(MARCA / "watermark.tga"), VERDE)
    marca.save(carpeta / "r" / "marca-lobo.png")
    rec["marca"] = "r/marca-lobo.png"
    shutil.copy(RAIZ / "curseforge" / "avatar.png", carpeta / "r" / "avatar.png")
    rec["avatar"] = "r/avatar.png"
    estrellas(carpeta / "r" / "estrellas.png")
    rec["estrellas"] = "r/estrellas.png"
    for png in sorted(IMAGENES.glob("*.png")):
        shutil.copy(png, carpeta / "r" / f"cap-{png.name}")
        with Image.open(png) as im:
            rec["img"][png.stem] = (f"r/cap-{png.name}", im.width, im.height)
    return rec


def letras_css(cjk) -> str:
    caras = [("Inter", 400, "Inter-Regular.ttf"), ("Inter", 500, "Inter-Medium.ttf"),
             ("Inter", 600, "Inter-SemiBold.ttf"), ("Fira Sans", 500, "FiraSans-Medium.ttf"),
             ("Fira Sans", 600, "FiraSans-SemiBold.ttf")]
    otras = [RAIZ / "upstream" / "polestar-0.3.7.2" / "Polestar" / "Media" / "Fonts",
             RAIZ / "dist" / "Alfa" / "Media" / "Fonts"]
    css = []
    for familia, peso, archivo in caras:
        ruta = LETRAS / archivo
        if not ruta.exists():
            ruta = next((o / archivo for o in otras if (o / archivo).exists()), None)
        if ruta is None:
            raise SystemExit(f"Falta la letra {archivo} (va en docs/manual/letras)")
        datos = base64.b64encode(ruta.read_bytes()).decode("ascii")
        css.append("@font-face{font-family:'%s';font-weight:%d;font-style:normal;"
                   "src:url(data:font/ttf;base64,%s) format('truetype')}" % (familia, peso, datos))
    return "\n".join(css)


# ---------------------------------------------------------------------------
# Texto con marcas sencillas: **negrita**, *cursiva*, `comando`, [[Tecla]]
# ---------------------------------------------------------------------------
def md(texto: str) -> str:
    t = html.escape(texto or "", quote=False)
    t = re.sub(r"\[\[(.+?)\]\]", lambda m: '<kbd>%s</kbd>' % m.group(1), t)
    t = re.sub(r"`(.+?)`", lambda m: '<code>%s</code>' % m.group(1), t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)
    t = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<i>\1</i>", t)
    t = re.sub(r"(https?://[^\s<]+[^\s<.,;:)»」。])", r'<a href="\1">\1</a>', t)
    return t.replace("\n", "<br>")


def esc(texto) -> str:
    return html.escape(str(texto or ""), quote=True)


# ---------------------------------------------------------------------------
# Bloques
# ---------------------------------------------------------------------------
class Armado:
    def __init__(self, datos: dict, rec: dict, version: str, paginas: dict, apretar=None):
        self.d = datos
        self.ui = datos["ui"]
        self.rec = rec
        self.version = version
        self.paginas = paginas      # id de capítulo o parte -> página (pasada 2)
        self.avisos = []
        self.apretar = apretar or {}

    # -- piezas pequeñas ----------------------------------------------------
    def icono(self, nombre, tinta=False, clase="ico"):
        tabla = self.rec["icono_tinta" if tinta else "icono"]
        ruta = tabla.get(nombre) or tabla.get(ICONO_DEF[3:])
        return '<img class="%s" src="%s" alt="">' % (clase, ruta)

    def pose(self, nombre, clase="pose"):
        p = self.rec["pose"].get(nombre) or self.rec["pose"].get("sentada1")
        if not p:
            return ""
        return '<img class="%s" src="%s" style="aspect-ratio:%d/%d" alt="">' % (clase, p[0], p[1], p[2])

    def pagina_de(self, clave):
        n = self.paginas.get(clave)
        return str(n) if n else "00"

    # -- bloques ------------------------------------------------------------
    def bloque(self, b: dict) -> str:
        t = b.get("t")
        f = getattr(self, "b_" + str(t), None)
        if not f:
            self.avisos.append("bloque desconocido: %r" % t)
            return ""
        return f(b)

    def bloques(self, lista) -> str:
        return "\n".join(self.bloque(b) for b in lista or [])

    def b_intro(self, b):
        return '<p class="intro">%s</p>' % md(b["texto"])

    def b_p(self, b):
        return '<p>%s</p>' % md(b["texto"])

    def b_h(self, b):
        return '<h3>%s</h3>' % md(b["texto"])

    def b_lista(self, b):
        items = "".join("<li>%s</li>" % md(x) for x in b["items"])
        tit = '<h4>%s</h4>' % md(b["titulo"]) if b.get("titulo") else ""
        return '<div class="lista">%s<ul>%s</ul></div>' % (tit, items)

    def b_pasos(self, b):
        items = "".join('<li><span class="n">%d</span><div>%s</div></li>' % (i + 1, md(x))
                        for i, x in enumerate(b["items"]))
        tit = '<h4>%s</h4>' % md(b["titulo"]) if b.get("titulo") else ""
        return '<div class="pasos">%s<ol>%s</ol></div>' % (tit, items)

    def b_etapas(self, b):
        celdas = "".join('<div class="etapa"><span class="n">%d</span><b>%s</b><span>%s</span></div>'
                         % (i + 1, md(x["titulo"]), md(x["texto"])) for i, x in enumerate(b["items"]))
        tit = '<h4>%s</h4>' % md(b["titulo"]) if b.get("titulo") else ""
        return '<div class="etapas-caja">%s<div class="etapas">%s</div></div>' % (tit, celdas)

    def b_tarjetas(self, b):
        cols = b.get("cols", 2)
        celdas = []
        for x in b["items"]:
            ic = '<div class="tico">%s</div>' % self.icono(x["icono"]) if x.get("icono") else ""
            celdas.append('<div class="tarjeta">%s<div><b>%s</b><span>%s</span></div></div>'
                          % (ic, md(x["titulo"]), md(x["texto"])))
        tit = '<h4>%s</h4>' % md(b["titulo"]) if b.get("titulo") else ""
        return '<div class="tarjetas-caja">%s<div class="tarjetas c%d">%s</div></div>' % (tit, cols, "".join(celdas))

    def _caja(self, clase, etiqueta, icono, texto):
        return ('<div class="caja %s"><div class="caja-ic">%s</div><div><div class="caja-et">%s</div>'
                '<div class="caja-tx">%s</div></div></div>' % (clase, self.icono(icono, tinta=(clase != "importante")),
                                                             esc(etiqueta), md(texto)))

    def b_consejo(self, b):
        return self._caja("consejo", self.ui["consejo"], "info", b["texto"])

    def b_nota(self, b):
        return self._caja("nota", self.ui["nota"], "lista", b["texto"])

    def b_importante(self, b):
        return self._caja("importante", self.ui["importante"], "alerta", b["texto"])

    def b_lya(self, b):
        return ('<div class="lya">%s<div class="globo"><span class="quien">%s</span>%s</div></div>'
                % (self.pose(b.get("pose", "sentada1"), "lya-av"), esc(self.ui["lya"] + ":"), md(b["texto"])))

    def b_novedad(self, b):
        ref = b.get("ref")
        datos = (self.d.get("novedades") or {}).get(ref)
        v = NOVEDADES.get(ref)
        if not datos or not v:
            return ""
        ya = vnum(self.version) >= vnum(v)
        sub = (self.ui["novedad_ya"] if ya else self.ui["novedad_viene"]).format(v=v)
        items = "".join("<li>%s</li>" % md(x) for x in datos["items"])
        return ('<div class="novedad"><div class="nov-cab"><span class="nov-chip">%s</span>'
                '<span class="nov-sub">%s</span></div><div class="nov-tit">%s</div><ul>%s</ul></div>'
                % (esc(self.ui["novedad"].format(v=v)), esc(sub), md(datos["titulo"]), items))

    def b_teclas(self, b):
        filas = []
        for x in b["items"]:
            teclas = '<span class="mas">+</span>'.join("<kbd>%s</kbd>" % esc(k) for k in x["teclas"])
            filas.append('<div class="tecla-fila"><div class="tecla-k">%s</div><div>%s</div></div>'
                         % (teclas, md(x["texto"])))
        tit = '<h4>%s</h4>' % md(b["titulo"]) if b.get("titulo") else ""
        return '<div class="teclas">%s%s</div>' % (tit, "".join(filas))

    def b_comandos(self, b):
        filas = "".join('<tr><td><code>%s</code></td><td>%s</td></tr>' % (esc(x["cmd"]), md(x["texto"]))
                        for x in b["items"])
        tit = '<h4>%s</h4>' % md(b["titulo"]) if b.get("titulo") else ""
        return '<div class="comandos">%s<table>%s</table></div>' % (tit, filas)

    def b_faq(self, b):
        return "".join('<div class="faq"><div class="faq-q"><span>?</span>%s</div><div class="faq-a">%s</div></div>'
                       % (md(x["q"]), md(x["a"])) for x in b["items"])

    def figura(self, b, clase=""):
        ident = b["img"]
        info = self.rec["img"].get(ident)
        if not info:
            self.avisos.append("falta la imagen %s" % ident)
            return ""
        ruta, w, h = info
        marcas = ""
        ley = ""
        if b.get("marcas"):
            puntos = MARCAS.get((ident, b["marcas"]), [])
            leyenda = b.get("leyenda", [])
            if len(puntos) != len(leyenda):
                self.avisos.append("marcas %s/%s: %d puntos y %d textos" % (ident, b["marcas"], len(puntos), len(leyenda)))
            origen = CAPTURAS.get(ident, ("", None))[1] or (0, 0, w, h)
            for i, (x, y) in enumerate(puntos):
                px = (x - origen[0]) / w * 100
                py = (y - origen[1]) / h * 100
                marcas += '<span class="marca" style="left:%.2f%%;top:%.2f%%">%d</span>' % (px, py, i + 1)
            ley = '<ol class="leyenda">%s</ol>' % "".join(
                '<li><span class="n">%d</span><span>%s</span></li>' % (i + 1, md(x)) for i, x in enumerate(leyenda))
        ancho = {"media": "60%", "chica": "45%", "angosta": "34%"}.get(b.get("ancho"), "100%")
        pie = '<figcaption>%s</figcaption>' % md(b["pie"]) if b.get("pie") else ""
        return ('<figure class="fig %s"><div class="marco" style="width:%s"><img src="%s" style="aspect-ratio:%d/%d" alt="">%s</div>'
                '%s%s</figure>' % (clase, ancho, ruta, w, h, marcas, pie, ley))

    def b_img(self, b):
        return self.figura(b)

    def b_dos(self, b):
        lado = b.get("lado", "izq")
        fig = self.figura(dict(b, ancho=None), "en-dos")
        txt = '<div class="dos-tx">%s</div>' % self.bloques(b.get("bloques"))
        partes = (fig, txt) if lado == "izq" else (txt, fig)
        prop = b.get("prop", "50")
        return '<div class="dos p%s %s">%s%s</div>' % (prop, lado, partes[0], partes[1])

    def b_enlace(self, b):
        return ('<div class="enlace">%s<div><div class="enl-tit">%s</div><a href="%s">%s</a><div class="enl-tx">%s</div></div></div>'
                % (self.icono(b.get("icono", "comunidad")), md(b["titulo"]), esc(b["url"]),
                   esc(re.sub(r"^https?://", "", b["url"])), md(b.get("texto", ""))))

    def b_creditos(self, b):
        filas = "".join('<tr><td><b>%s</b></td><td>%s</td><td class="lic">%s</td></tr>'
                        % (md(x[0]), md(x[1]), esc(x[2])) for x in b["items"])
        return '<table class="creditos">%s</table>' % filas

    def b_poses(self, b):
        celdas = "".join('<div class="pz">%s<span>%s</span></div>' % (self.pose(p, "pz-img"), md(t))
                         for p, t in b["items"])
        return '<div class="poses">%s</div>' % celdas

    # -- ilustraciones hechas con HTML (se traducen con el JSON) ------------
    def b_ilustracion(self, b):
        f = getattr(self, "il_" + b["id"], None)
        if not f:
            self.avisos.append("ilustración desconocida: %s" % b["id"])
            return ""
        cuerpo = f(b.get("e", {}))
        pie = '<figcaption>%s</figcaption>' % md(b["pie"]) if b.get("pie") else ""
        ley = ""
        if b.get("leyenda"):
            ley = '<ol class="leyenda">%s</ol>' % "".join(
                '<li><span class="n">%d</span><span>%s</span></li>' % (i + 1, md(x)) for i, x in enumerate(b["leyenda"]))
        return '<figure class="fig il il-%s">%s%s%s</figure>' % (b["id"], cuerpo, pie, ley)

    def il_rotacion(self, e):
        def hab(ic, clase, extra=""):
            return '<div class="hab %s">%s%s</div>' % (clase, self.icono(ic), extra)
        return ('<div class="rot-escena"><div class="rot">'
                '<div class="rot-col"><div class="rot-grande">%s<span class="area">%s</span><span class="kb">1</span>'
                '<span class="m1">1</span><span class="m4">4</span></div><span class="rot-lab">%s</span></div>'
                '<div class="rot-col"><div class="rot-chicas">%s%s<span class="m2">2</span></div><span class="rot-lab">%s</span></div>'
                '<div class="rot-porque"><span class="m5">5</span>%s</div></div></div>'
                % (hab("nivel", "g brilla", '<span class="barrido"></span><span class="m3">3</span>'),
                   esc(e.get("area", "")), esc(e.get("ahora", "")), hab("alerta", "c"), hab("flecha", "c"),
                   esc(e.get("despues", "")), esc(e.get("porque", ""))))

    def il_raton(self, e):
        botones = e.get("botones", [])
        mods = e.get("mods", [])
        acciones = e.get("acciones", [])
        cab = "<tr><th></th>%s</tr>" % "".join("<th>%s</th>" % esc(x) for x in botones)
        filas = ""
        for i, m in enumerate(mods):
            celdas = ""
            for j in range(len(botones)):
                a = acciones[i][j] if i < len(acciones) and j < len(acciones[i]) else ""
                celdas += '<td class="%s">%s</td>' % ("vacia" if not a else "", esc(a or "—"))
            filas += "<tr><th>%s</th>%s</tr>" % (esc(m), celdas)
        raton = ('<div class="raton-dib"><div class="rb izq"></div><div class="rb der"></div>'
                 '<div class="rueda"></div><div class="rcuerpo"></div></div>')
        return '<div class="raton">%s<table>%s%s</table></div>' % (raton, cab, filas)

    def il_pesca(self, e):
        pasos = e.get("pasos", [])
        ics = ["pesca", "mas", "flecha", "exito"]
        celdas = ""
        for i, p in enumerate(pasos):
            celdas += ('<div class="pp"><div class="pp-ic">%s</div><div class="pp-n">%d</div><div class="pp-tx">%s</div></div>'
                       % (self.icono(ics[i % len(ics)]), i + 1, esc(p)))
            if i < len(pasos) - 1:
                celdas += '<div class="pp-fl">&#8250;</div>'
        return ('<div class="pesca-il"><div class="pp-tecla"><kbd class="grande">%s</kbd><span>%s</span></div>'
                '<div class="pp-fila">%s</div></div>' % (esc(e.get("tecla", "")), esc(e.get("cada", "")), celdas))

    def il_mapa(self, e):
        def chip(ic, clave, pos):
            return ('<div class="mchip %s">%s<span>%s</span></div>' % (pos, self.icono(ic), esc(e.get(clave, ""))))
        barra = "".join('<span class="mb">%s</span>' % self.icono(ic)
                        for ic in ["buscar", "huella", "rejilla", "ventana", "mapa", "ajustes"])
        etiquetas = [("buscar", "cerca"), ("huella", "marcadores"), ("rejilla", "capas"),
                     ("ventana", "limpio"), ("mapa", "juego"), ("ajustes", "engrane")]
        lista_sup = "".join('<li>%s<span>%s</span></li>' % (self.icono(ic, tinta=True), esc(e.get(k, "")))
                            for ic, k in etiquetas)
        return (
            '<div class="mapa-il"><div class="mventana">'
            '<div class="mcab"><b>%s</b><div class="mbarra">%s</div></div>'
            '<div class="mlienzo">'
            '<div class="mzona z1"></div><div class="mzona z2"></div><div class="mzona z3"></div>'
            '<div class="mrio"></div>'
            '<div class="mpin tu">%s</div>'
            '<div class="mpin vuelo">%s</div><div class="mpin vuelo2">?</div>'
            '<div class="mpin marcador">%s</div><div class="mpin mazm">%s</div>'
            '<div class="mpin salida">%s</div>'
            '<div class="mzoom"><span>+</span><span>&#8211;</span><span>%s</span></div>'
            '%s%s%s%s%s%s'
            '</div></div>'
            '<ul class="mley">%s<li><span class="mz">+ &#8211;</span><span>%s</span></li></ul></div>'
            % (esc(e.get("titulo", "")), barra, self.icono("flecha"), self.icono("seguir"), self.icono("huella"),
               self.icono("mazmorra"), self.icono("seguir"), self.icono("flecha"),
               chip("flecha", "tu", "c-tu"), chip("seguir", "vuelo", "c-vuelo"), chip("info", "vuelo2", "c-vuelo2"),
               chip("huella", "marcador", "c-marcador"), chip("mazmorra", "mazmorra", "c-mazm"),
               chip("flecha", "salida", "c-salida"),
               lista_sup, esc(e.get("zoom", ""))))

    def il_cuadro(self, e):
        lineas = "".join('<div class="cl %s">%s</div>' % (esc(x.get("c", "")), md(x["t"])) for x in e.get("lineas", []))
        return '<div class="cuadro-il"><div class="cuadro">%s</div></div>' % lineas

    def il_instalador(self, e):
        pasos = e.get("pasos", [])
        celdas = "".join('<div class="ins"><span class="n">%d</span><b>%s</b><span>%s</span></div>'
                         % (i + 1, esc(p[0]), esc(p[1])) for i, p in enumerate(pasos))
        return '<div class="ins-fila">%s</div>' % celdas

    def il_secciones(self, e):
        celdas = "".join('<div class="sec">%s<b>%s</b></div>' % (self.icono(ic), esc(t))
                         for ic, t in e.get("items", []))
        return '<div class="secs">%s</div>' % celdas

    # -- páginas ------------------------------------------------------------
    def portada(self):
        ui = self.ui
        img = self.rec["img"].get("intro")
        fondo = '<img class="po-img" src="%s" alt="">' % img[0] if img else ""
        return (
            '<section class="hoja portada" data-id="portada">%s'
            '<div class="po-idioma">%s</div>'
            '<div class="po-texto"><div class="po-titulo">%s</div><div class="po-lema">%s</div>'
            '<div class="po-sub">%s</div></div>'
            '<div class="po-pie"><img class="po-av" src="%s" alt=""><div><b>%s</b><span>%s</span></div></div>'
            '</section>' % (fondo, esc(self.d["nombre"]), esc(ui["titulo_manual"]), esc(ui["lema"]),
                            esc(ui["portada_sub"]), self.rec["avatar"], esc(ui["hecho_por"]),
                            esc(ui["portada_version"].format(v=self.version, j=JUEGO))))

    def contraportada(self):
        c = self.d["contraportada"]
        enlaces = "".join('<div class="cp-enl"><span>%s</span><a href="%s">%s</a></div>'
                          % (esc(x[0]), esc(x[1]), esc(re.sub(r"^https?://(www\.)?", "", x[1]))) for x in c["enlaces"])
        return (
            '<section class="hoja contra" data-id="contraportada">'
            '<img class="cp-estrellas" src="%s" alt=""><img class="cp-marca" src="%s" alt="">'
            '<div class="cp-centro"><img class="cp-av" src="%s" alt=""><div class="cp-tit">%s</div>'
            '<div class="cp-tx">%s</div>%s</div>'
            '<div class="cp-lya">%s<div class="cp-suelo"></div></div>'
            '<div class="cp-pie">%s</div></section>'
            % (self.rec["estrellas"], self.rec["marca"], self.rec["avatar"], md(c["titulo"]), md(c["texto"]), enlaces,
               self.pose("dormir2", "cp-pose"), md(c["pie"].format(v=self.version))))

    def carta(self):
        c = self.d["carta"]
        leyenda = "".join('<div class="cl-it">%s<div><b>%s</b><span>%s</span></div></div>'
                          % (self._muestra(x["tipo"]), md(x["titulo"]), md(x["texto"])) for x in c["como_leer"])
        rapido = ""
        if c.get("rapido"):
            r = c["rapido"]
            rapido = ('<div class="rapido"><div class="rp-tit">%s</div><div class="rp-fila">%s</div></div>'
                      % (md(r["titulo"]), "".join('<div class="rp"><span class="rp-n">%d</span><b>%s</b><span>%s</span></div>'
                                                   % (i + 1, md(x["titulo"]), md(x["texto"])) for i, x in enumerate(r["items"]))))
        nota = ""
        if self.ui.get("nota_capturas"):
            nota = self._caja("nota", self.ui["nota"], "idioma" if "idioma" in self.rec["icono"] else "lista",
                              self.ui["nota_capturas"])
        return (
            '<section class="flujo carta" style="page:carta">'
            '<div class="carta-cab">%s<h1 class="carta-tit">%s</h1></div>'
            '%s'
            '%s'
            '<div class="firma">%s</div>'
            '%s<h3>%s</h3><div class="como-leer">%s</div>%s</section>'
            % (self.icono("huella"), md(c["titulo"]), "".join('<p class="%s">%s</p>' % ("intro" if i == 0 else "", md(p))
                                                              for i, p in enumerate(c["parrafos"])),
               self.b_lya({"texto": c["lya"], "pose": "sentada1"}), md(c["firma"]), rapido, md(c["como_leer_titulo"]),
               leyenda, nota))

    def _muestra(self, tipo):
        if tipo == "pasos":
            return '<div class="mu mu-pasos"><span class="n">1</span></div>'
        if tipo == "consejo":
            return '<div class="mu mu-consejo">%s</div>' % self.icono("info", tinta=True)
        if tipo == "teclas":
            return '<div class="mu mu-teclas"><kbd>M</kbd></div>'
        if tipo == "novedad":
            return '<div class="mu mu-novedad">%s</div>' % self.icono("mas")
        if tipo == "lya":
            return '<div class="mu mu-lya">%s</div>' % self.pose("atenta1", "mu-pose")
        return '<div class="mu"></div>'

    def indice(self):
        filas = []
        for ip, parte in enumerate(self.d["partes"]):
            filas.append('<a class="ix-parte" href="#parte-%s"><span class="ix-pn">%s</span><span class="ix-pt">%s</span>'
                         '<span class="ix-pg">%s</span></a>' % (parte["id"], romano(ip + 1), md(parte["titulo"]),
                                                                self.pagina_de("parte-" + parte["id"])))
            for cap in parte["capitulos"]:
                filas.append('<a class="ix-cap" href="#cap-%s">%s<span class="ix-ct">%s</span><span class="ix-pun"></span>'
                             '<span class="ix-pg">%s</span></a>' % (cap["id"], self.icono(cap.get("icono", "huella"), tinta=True, clase="ix-ic"),
                                                                    md(cap["titulo"]), self.pagina_de("cap-" + cap["id"])))
        return ('<section class="flujo indice" style="page:indice"><div class="ix-cab"><h1 class="ix-tit">%s</h1></div>'
                '<div class="ix-lista">%s</div></section>' % (esc(self.ui["indice"]), "".join(filas)))

    def parte(self, ip, parte, num_cap):
        caps = ""
        n = num_cap
        for cap in parte["capitulos"]:
            n += 1
            caps += ('<a class="pa-cap" href="#cap-%s"><span class="pa-ic">%s</span><span class="pa-n">%02d</span>'
                     '<span class="pa-ct">%s</span><span class="pa-pg">%s</span></a>'
                     % (cap["id"], self.icono(cap.get("icono", "huella")), n, md(cap["titulo"]),
                        self.pagina_de("cap-" + cap["id"])))
        return (
            '<section class="hoja parte" data-id="parte-%s">'
            '<img class="pa-estrellas" src="%s" alt=""><img class="pa-marca" src="%s" alt="">'
            '<div class="pa-arriba"><div class="pa-eti">%s %s</div><div class="pa-num">%02d</div>'
            '<h1 class="pa-tit" id="parte-%s">%s</h1><div class="pa-lema">%s</div></div>'
            '<div class="pa-caps">%s</div>'
            '<div class="pa-lya">%s<div class="pa-suelo"></div></div>'
            '</section>' % (parte["id"], self.rec["estrellas"], self.rec["marca"], esc(self.ui["parte"]), romano(ip + 1),
                            ip + 1, parte["id"], md(parte["titulo"]), md(parte["lema"]), caps,
                            self.pose(parte.get("pose", "sentada1"), "pa-pose")))

    def capitulo(self, parte, ip, cap, n):
        cab = (
            '<header class="cap-cab"><div class="cc-ic">%s</div><div class="cc-tx">'
            '<div class="cc-eti">%s %s · %s</div><h2 id="cap-%s">%s</h2><div class="cc-lema">%s</div></div>'
            '<div class="cc-num">%02d</div></header>'
            % (self.icono(cap.get("icono", "huella")), esc(self.ui["parte"]), romano(ip + 1), md(parte["titulo"]),
               cap["id"], md(cap["titulo"]), md(cap.get("lema", "")), n))
        nivel = self.apretar.get(cap["id"], 0)
        return ('<section class="flujo cap%s" style="page:cap-%s">%s%s</section>'
                % (" apretar%d" % nivel if nivel else "", cap["id"], cab, self.bloques(cap["bloques"])))

    def documento(self, css: str) -> str:
        cuerpo = [self.portada(), self.carta(), self.indice()]
        n = 0
        for ip, parte in enumerate(self.d["partes"]):
            cuerpo.append(self.parte(ip, parte, n))
            for cap in parte["capitulos"]:
                n += 1
                cuerpo.append(self.capitulo(parte, ip, cap, n))
        cuerpo.append(self.contraportada())
        # el pie de cada capítulo: su parte y su nombre
        pies = []
        for parte in self.d["partes"]:
            for cap in parte["capitulos"]:
                etiqueta = "%s · %s" % (texto_plano(parte["titulo"]), texto_plano(cap["titulo"]))
                pies.append('@page cap-%s{@bottom-left{content:"%s"}}' % (cap["id"], css_cadena(etiqueta)))
        pies.append('@page carta{@bottom-left{content:"%s"}}' % css_cadena(self.ui["pie"]))
        pies.append('@page indice{@bottom-left{content:"%s"}}' % css_cadena(self.ui["pie"]))
        return ('<!doctype html><html lang="%s"><head><meta charset="utf-8"><title>%s</title>'
                '<style>%s\n%s</style></head><body class="%s">%s</body></html>'
                % (self.d["lang"], esc("Alfa · " + self.ui["titulo_manual"]), css, "\n".join(pies),
                   self.d["clase"], "\n".join(cuerpo)))


def romano(n: int) -> str:
    return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"][n - 1]


def texto_plano(t: str) -> str:
    return re.sub(r"[*`\[\]]", "", t or "")


def css_cadena(t: str) -> str:
    return texto_plano(t).replace("\\", "\\\\").replace('"', '\\"')


# ---------------------------------------------------------------------------
# Hoja de estilos
# ---------------------------------------------------------------------------
CSS = r"""
:root{
  --verde:#8be04e; --verde-osc:#4f9a24; --tinta-verde:#2f6a12; --grafito:#121815; --grafito2:#1b221e;
  --tinta:#1b221e; --suave:#58655d; --tenue:#8a968e; --linea:#dde4dc; --crema:#f3f7f0; --crema2:#e9f0e4;
  --ambar:#e9a93a; --ambar-claro:#fdf3df; --noche:#080a0a;
  --cuerpo: 'Inter', VAR_CJK 'Segoe UI', sans-serif;
  --titulos: 'Fira Sans', 'Inter', VAR_CJK 'Segoe UI', sans-serif;
}
@page{ size:A4; margin:15mm 17mm 18mm 17mm;
  @top-left{ content:"ALFA"; font:600 7pt/1 var(--cuerpo); letter-spacing:.32em; color:#9aa79f; vertical-align:bottom; padding-bottom:4mm }
  @bottom-right{ content:counter(page); font:600 8.5pt/1 var(--cuerpo); color:#2f6a12; vertical-align:top; padding-top:5mm }
  @bottom-left{ font:500 7.5pt/1 var(--cuerpo); color:#8a968e; vertical-align:top; padding-top:5mm }
}
@page portada{ margin:0; @top-left{content:none} @bottom-right{content:none} @bottom-left{content:none} }
@page parte{ margin:0; @top-left{content:none} @bottom-right{content:none} @bottom-left{content:none} }
@page contra{ margin:0; @top-left{content:none} @bottom-right{content:none} @bottom-left{content:none} }
*{ box-sizing:border-box }
html,body{ margin:0; padding:0 }
body{ font-family:var(--cuerpo); font-size:9.6pt; line-height:1.56; color:var(--tinta);
  -webkit-print-color-adjust:exact; print-color-adjust:exact; overflow-wrap:break-word; }
body.cjk{ line-height:1.72; }
body.ko{ word-break:keep-all; }
b{ font-weight:600 }
a{ color:var(--tinta-verde); text-decoration:none }
p{ margin:0 0 2.6mm }
h3{ font-family:var(--titulos); font-weight:600; font-size:13pt; line-height:1.25; margin:6.5mm 0 2.6mm;
  padding-left:3.2mm; border-left:1.1mm solid var(--verde); break-after:avoid; }
h4{ font-family:var(--titulos); font-weight:600; font-size:10.5pt; margin:0 0 2mm; color:var(--tinta); break-after:avoid }
code{ font-family:var(--cuerpo); font-weight:600; font-size:.92em; color:var(--tinta-verde); background:var(--crema2);
  padding:.15mm 1.3mm; border-radius:1mm; white-space:nowrap }
kbd{ display:inline-block; font-family:var(--cuerpo); font-weight:600; font-size:.86em; line-height:1.35; color:var(--tinta);
  background:#fff; border:.3mm solid #c3ccc2; border-bottom-width:.75mm; border-radius:1.1mm; padding:0 1.6mm;
  min-width:5mm; text-align:center; white-space:nowrap; vertical-align:.1mm }
.intro{ font-size:11.6pt; line-height:1.55; color:#26302a; margin-bottom:4mm }
body.cjk .intro{ line-height:1.7 }
ul{ margin:0 0 3mm; padding:0; list-style:none }
ul li{ position:relative; padding-left:5mm; margin:0 0 1.6mm }
ul li::before{ content:""; position:absolute; left:.6mm; top:.62em; width:1.7mm; height:1.7mm; background:var(--verde);
  transform:rotate(45deg) translateY(-50%); }

/* ---------- hojas fijas (portada, partes, contraportada) ---------- */
.hoja{ width:210mm; height:296.8mm; overflow:hidden; position:relative; break-after:page; background:var(--noche); color:#e8eee9 }
.portada{ page:portada } .parte{ page:parte } .contra{ page:contra; break-after:auto }

.po-img{ position:absolute; left:0; top:0; width:210mm; height:196mm; object-fit:cover; object-position:50% 100% }
.po-idioma{ position:absolute; top:12mm; right:14mm; font-size:8pt; letter-spacing:.06em; color:#9fb0a5;
  border:.3mm solid #2b3a31; border-radius:10mm; padding:1.2mm 3.6mm }
.po-texto{ position:absolute; left:0; right:0; top:203mm; text-align:center; padding:0 20mm }
.po-titulo{ font-family:var(--titulos); font-weight:600; font-size:31pt; line-height:1.1; color:#f2f6f2 }
.po-lema{ font-family:var(--titulos); font-weight:500; font-size:15pt; color:var(--verde); margin-top:3mm }
.po-sub{ font-size:10.5pt; color:#a9b8ae; margin-top:3.5mm; line-height:1.45 }
.po-pie{ position:absolute; left:20mm; right:20mm; bottom:14mm; display:flex; align-items:center; gap:4mm;
  border-top:.3mm solid #223028; padding-top:5mm }
.po-av{ width:13mm; height:13mm }
.po-pie b{ display:block; font-size:9.5pt; color:#e8eee9; font-weight:600 }
.po-pie span{ display:block; font-size:8.5pt; color:#8fa196 }

.pa-estrellas,.cp-estrellas{ position:absolute; inset:0; width:210mm; height:297mm; opacity:.55 }
.parte::before{ content:""; position:absolute; inset:0;
  background:radial-gradient(120mm 120mm at 170mm 40mm, rgba(139,224,78,.16), transparent 70%),
             radial-gradient(160mm 90mm at 30mm 300mm, rgba(139,224,78,.10), transparent 70%); }
.pa-marca{ position:absolute; right:-28mm; bottom:-24mm; width:150mm; opacity:.07 }
.pa-arriba{ position:absolute; left:20mm; right:20mm; top:30mm }
.pa-eti{ font-size:8.5pt; font-weight:600; letter-spacing:.22em; text-transform:uppercase; color:var(--verde) }
.pa-num{ font-family:var(--titulos); font-weight:600; font-size:84pt; line-height:1; color:transparent;
  -webkit-text-stroke:.45mm rgba(139,224,78,.6); margin:4mm 0 2mm; letter-spacing:.02em }
.pa-tit{ font-family:var(--titulos); font-weight:600; font-size:38pt; line-height:1.1; margin:0; color:#f3f7f3 }
.pa-lema{ font-size:12.5pt; color:#aab9af; margin-top:4mm; max-width:140mm; line-height:1.45 }
.pa-caps{ position:absolute; left:20mm; right:20mm; top:122mm; display:flex; flex-direction:column; gap:2.4mm }
.pa-cap{ display:flex; align-items:center; gap:4mm; padding:3.2mm 4mm; background:rgba(255,255,255,.035);
  border:.3mm solid rgba(139,224,78,.16); color:#e8eee9; clip-path:polygon(0 0,calc(100% - 3mm) 0,100% 3mm,100% 100%,3mm 100%,0 calc(100% - 3mm)) }
.pa-ic{ width:9mm; height:9mm; display:flex; align-items:center; justify-content:center; background:#16201a;
  border:.3mm solid #2c3d31 } .pa-ic img{ width:5.6mm; height:5.6mm }
.pa-n{ font-family:var(--titulos); font-weight:600; color:var(--verde); font-size:11pt; width:8mm }
.pa-ct{ flex:1; font-family:var(--titulos); font-weight:500; font-size:12.5pt }
.pa-pg{ font-size:9pt; color:#8fa196 }
.pa-lya{ position:absolute; left:20mm; bottom:16mm; width:40mm; height:34mm }
.pa-pose{ position:absolute; left:4mm; bottom:3.6mm; height:30mm; image-rendering:pixelated }
.pa-suelo,.cp-suelo{ position:absolute; left:0; bottom:0; width:40mm; height:8mm; border:.5mm solid rgba(139,224,78,.75);
  border-radius:50%; background:radial-gradient(closest-side, rgba(0,0,0,.6), transparent) }

.cp-marca{ position:absolute; left:50%; top:52mm; width:170mm; transform:translateX(-50%); opacity:.06 }
.cp-centro{ position:absolute; left:20mm; right:20mm; top:62mm; text-align:center }
.cp-av{ width:34mm; height:34mm }
.cp-tit{ font-family:var(--titulos); font-weight:600; font-size:26pt; color:#f3f7f3; margin-top:7mm }
.cp-tx{ font-size:10.5pt; color:#aab9af; margin:3mm auto 8mm; max-width:130mm; line-height:1.5 }
.cp-enl{ display:flex; justify-content:center; gap:3mm; font-size:10pt; margin:2.2mm 0 }
.cp-enl span{ color:#8fa196 } .cp-enl a{ color:var(--verde); font-weight:600 }
.cp-lya{ position:absolute; left:50%; transform:translateX(-50%); bottom:36mm; width:44mm; height:36mm }
.cp-pose{ position:absolute; left:50%; transform:translateX(-50%); bottom:2.6mm; height:30mm; image-rendering:pixelated }
.cp-lya .cp-suelo{ width:44mm }
.cp-pie{ position:absolute; left:20mm; right:20mm; bottom:14mm; text-align:center; font-size:8pt; color:#7f9186; line-height:1.5 }

/* ---------- páginas que fluyen ---------- */
.flujo{ width:176mm; break-before:page }
.carta-cab{ display:flex; align-items:center; gap:4mm; margin:2mm 0 6mm }
.carta-cab .ico{ width:12mm; height:12mm; padding:2.6mm; background:var(--grafito); clip-path:polygon(0 0,calc(100% - 2.4mm) 0,100% 2.4mm,100% 100%,2.4mm 100%,0 calc(100% - 2.4mm)) }
.carta-tit,.ix-tit{ font-family:var(--titulos); font-weight:600; font-size:27pt; line-height:1.15; margin:0 }
.firma{ text-align:right; font-family:var(--titulos); font-weight:500; color:var(--tinta-verde); margin:1mm 0 2mm; font-size:10.5pt }
.como-leer{ display:grid; grid-template-columns:1fr 1fr; gap:3mm }
.cl-it{ display:flex; gap:3.4mm; align-items:center; background:var(--crema); border:.3mm solid var(--linea); border-radius:2mm; padding:3mm }
.cl-it b{ display:block; font-size:9.6pt } .cl-it span{ display:block; font-size:8.6pt; color:var(--suave); line-height:1.4 }
.mu{ flex:none; width:11mm; height:11mm; display:flex; align-items:center; justify-content:center; border-radius:2mm }
.mu-pasos .n{ width:7mm; height:7mm; border-radius:50%; background:var(--verde); color:#132010; font-weight:700;
  display:flex; align-items:center; justify-content:center; font-size:9pt }
.mu-consejo{ background:#e4f5d6 } .mu-consejo img{ width:6mm }
.mu-teclas kbd{ font-size:10pt; padding:.4mm 2.2mm }
.mu-novedad{ background:var(--grafito) } .mu-novedad img{ width:5.6mm }
.mu-pose{ height:10mm; image-rendering:pixelated }

.indice .ix-cab{ margin:2mm 0 3mm }
.ix-lista{ display:flex; flex-direction:column; line-height:1.38 }
.ix-parte{ display:flex; align-items:baseline; gap:3mm; margin:2.8mm 0 .8mm; color:var(--tinta); break-after:avoid;
  border-bottom:.3mm solid var(--linea); padding-bottom:1mm }
.ix-pn{ font-family:var(--titulos); font-weight:600; color:var(--verde-osc); font-size:10pt; width:9mm }
.ix-pt{ flex:1; font-family:var(--titulos); font-weight:600; font-size:12pt }
.ix-cap{ display:flex; align-items:center; gap:3mm; padding:.62mm 0 .62mm 12mm; color:var(--tinta); font-size:9.8pt }
.ix-ic{ width:4.2mm; height:4.2mm; opacity:.9 }
.ix-pun{ flex:1; border-bottom:.35mm dotted #b8c2b9; transform:translateY(-1mm) }
.ix-pg{ font-weight:600; color:var(--tinta-verde); min-width:7mm; text-align:right; font-variant-numeric:tabular-nums }

/* cabecera de cada capítulo */
.cap-cab{ position:relative; display:flex; align-items:center; gap:5mm; background:var(--grafito); color:#eef3ee;
  padding:7mm 8mm; margin:0 0 6mm; min-height:38mm; overflow:hidden;
  clip-path:polygon(0 0,calc(100% - 6mm) 0,100% 6mm,100% 100%,6mm 100%,0 calc(100% - 6mm)) }
.cap-cab::before{ content:""; position:absolute; inset:0; background:radial-gradient(90mm 50mm at 100% 0, rgba(139,224,78,.18), transparent 70%) }
.cap-cab::after{ content:""; position:absolute; left:0; top:0; bottom:0; width:1.3mm; background:var(--verde) }
.cc-ic{ position:relative; flex:none; width:17mm; height:17mm; display:flex; align-items:center; justify-content:center;
  background:#1e2a22; border:.35mm solid #33473a; clip-path:polygon(0 0,calc(100% - 2.6mm) 0,100% 2.6mm,100% 100%,2.6mm 100%,0 calc(100% - 2.6mm)) }
.cc-ic img{ width:9.5mm; height:9.5mm }
.cc-tx{ position:relative; flex:1; min-width:0 }
.cc-eti{ font-size:7.6pt; font-weight:600; letter-spacing:.16em; text-transform:uppercase; color:var(--verde) }
.cap-cab h2{ font-family:var(--titulos); font-weight:600; font-size:23pt; line-height:1.12; margin:1.4mm 0 1.6mm; color:#f4f8f4 }
.cc-lema{ font-size:10.5pt; color:#b3c1b7; line-height:1.4 }
.cc-num{ position:relative; flex:none; font-family:var(--titulos); font-weight:600; font-size:46pt; line-height:1;
  color:transparent; -webkit-text-stroke:.4mm rgba(139,224,78,.6) }
body.cjk .cc-eti,body.cjk .pa-eti{ letter-spacing:.05em }

/* inicio rápido (carta) */
.rapido{ background:var(--grafito); color:#e9efe9; padding:5.5mm 6mm 6mm; margin:5mm 0 3mm; break-inside:avoid; position:relative;
  clip-path:polygon(0 0,calc(100% - 4mm) 0,100% 4mm,100% 100%,4mm 100%,0 calc(100% - 4mm)) }
.rapido::before{ content:""; position:absolute; inset:0; background:radial-gradient(90mm 40mm at 100% 0, rgba(139,224,78,.18), transparent 70%) }
.rp-tit{ position:relative; font-family:var(--titulos); font-weight:600; font-size:13pt; margin-bottom:3.6mm }
.rp-fila{ position:relative; display:grid; grid-template-columns:repeat(3,1fr); gap:5mm }
.rp{ display:flex; flex-direction:column; gap:1mm }
.rp-n{ font-family:var(--titulos); font-weight:600; font-size:24pt; line-height:1; color:transparent; -webkit-text-stroke:.35mm var(--verde); margin-bottom:1mm }
.rp b{ font-size:10pt; color:#f3f7f3 } .rp > span:last-child{ font-size:8.8pt; color:#aab9af; line-height:1.45 }
.rp code{ background:#24302a; color:var(--verde) }

/* un capítulo que se aprieta para no dejar una página casi vacía */
.apretar1 .fig .marco{ max-width:84% } .apretar1 .dos .fig .marco{ max-width:100% }
.apretar1 h3{ margin-top:5mm } .apretar1 .fig{ margin:2.6mm 0 3.6mm }
.apretar2 .fig .marco{ max-width:70% } .apretar2 .dos .fig .marco{ max-width:92% }
.apretar2 h3{ margin-top:4mm } .apretar2 .fig{ margin:2mm 0 3mm } .apretar2 p{ margin-bottom:2mm }
.apretar2 .tarjeta{ padding:2.4mm } .apretar2 .caja{ margin:2.6mm 0 3.4mm }
.apretar3 .fig .marco{ max-width:58% } .apretar3 .dos .fig .marco{ max-width:84% } .apretar3 .il{ padding:3.4mm }
.apretar3 h3{ margin-top:3.6mm } .apretar3 .fig{ margin:1.6mm 0 2.6mm } .apretar3 p{ margin-bottom:1.6mm }
.apretar3 .tarjeta{ padding:2mm } .apretar3 .caja{ margin:2.2mm 0 3mm; padding:2.6mm 3.4mm } .apretar3 .intro{ font-size:10.8pt }
.apretar3 .lya{ margin:3mm 0 3.4mm } .apretar3 .pasos li{ margin-bottom:1.6mm }
.apretar1 .faq{ margin-bottom:3.2mm; padding-bottom:2.8mm } .apretar2 .faq{ margin-bottom:2.6mm; padding-bottom:2.2mm }
.apretar3 .faq{ margin-bottom:2mm; padding-bottom:1.8mm } .apretar3 .faq-a{ font-size:9pt }
.apretar2 .comandos td,.apretar3 .comandos td{ padding:1.3mm 2.4mm } .apretar2 .tecla-fila,.apretar3 .tecla-fila{ padding:1.5mm 3.4mm }
body.cjk .apretar2 .faq-a,body.cjk .apretar3 .faq-a{ line-height:1.6 }

/* figuras */
.fig{ margin:3.5mm 0 5mm; break-inside:avoid; page-break-inside:avoid; display:flow-root }
.fig .marco,.fig .marco img{ break-inside:avoid; page-break-inside:avoid }
.fig .marco{ position:relative; margin:0 auto; border-radius:2.2mm; border:.35mm solid #0c110e; overflow:visible }
.fig .marco img{ display:block; width:100%; height:auto; border-radius:1.9mm }
.fig figcaption{ font-size:8.4pt; color:var(--suave); margin:2.6mm auto 0; text-align:center; line-height:1.45; max-width:150mm }
.fig figcaption::before{ content:""; display:inline-block; width:3.5mm; height:.7mm; background:var(--verde); vertical-align:middle; margin-right:2mm; transform:translateY(-.3mm) }
.marca{ position:absolute; width:6.4mm; height:6.4mm; margin:-3.2mm 0 0 -3.2mm; border-radius:50%; background:var(--verde);
  color:#11200c; font-weight:700; font-size:8.6pt; display:flex; align-items:center; justify-content:center;
  box-shadow:0 0 0 .7mm rgba(255,255,255,.95), 0 .8mm 2mm rgba(0,0,0,.45) }
.leyenda{ list-style:none; margin:3.4mm 0 0; padding:0; display:grid; grid-template-columns:1fr 1fr; gap:1.8mm 6mm }
.leyenda li{ display:flex; gap:2.4mm; font-size:8.8pt; line-height:1.42; align-items:flex-start }
.leyenda .n{ flex:none; width:5mm; height:5mm; border-radius:50%; background:var(--grafito); color:var(--verde); font-weight:700;
  font-size:7.6pt; display:flex; align-items:center; justify-content:center; margin-top:.2mm }
.dos{ display:grid; gap:7mm; align-items:start; margin:3mm 0 4.5mm; break-inside:avoid }
.dos.p50{ grid-template-columns:1fr 1fr } .dos.p40{ grid-template-columns:40fr 60fr } .dos.p60{ grid-template-columns:60fr 40fr }
.dos.p34{ grid-template-columns:34fr 66fr }
.dos.der.p40{ grid-template-columns:60fr 40fr } .dos.der.p34{ grid-template-columns:66fr 34fr } .dos.der.p60{ grid-template-columns:40fr 60fr }
.dos .fig{ margin:0 }
.dos-tx > :first-child{ margin-top:0 }
.dos-tx .pasos{ margin:0 }

/* pasos */
.pasos{ margin:3mm 0 4.5mm; break-inside:avoid }
.pasos ol{ list-style:none; margin:0; padding:0; counter-reset:p }
.pasos li{ display:flex; gap:3.2mm; margin:0 0 2.4mm; align-items:flex-start }
.pasos .n{ flex:none; width:6.6mm; height:6.6mm; border-radius:50%; background:var(--verde); color:#132010; font-weight:700;
  font-size:8.8pt; display:flex; align-items:center; justify-content:center; box-shadow:0 0 0 .8mm #e4f5d6 }
.pasos li > div{ padding-top:.5mm }
.etapas-caja{ margin:3mm 0 5mm; break-inside:avoid }
.etapas{ display:grid; grid-template-columns:repeat(3,1fr); gap:2.6mm }
.etapa{ position:relative; background:var(--crema); border:.3mm solid var(--linea); border-radius:2mm; padding:3mm 3mm 3mm 11.5mm; min-height:16mm }
.etapa .n{ position:absolute; left:3mm; top:3mm; width:6mm; height:6mm; border-radius:50%; background:var(--grafito); color:var(--verde);
  font-weight:700; font-size:8.4pt; display:flex; align-items:center; justify-content:center }
.etapa b{ display:block; font-size:9.4pt; line-height:1.3 } .etapa span{ display:block; font-size:8.2pt; color:var(--suave); line-height:1.38; margin-top:.6mm }

/* tarjetas */
.tarjetas-caja{ margin:3mm 0 5mm; break-inside:avoid }
.lista{ break-inside:avoid }
/* en el apretado más fuerte una lista larga sí puede partirse entre dos páginas, nunca a media viñeta */
.apretar3 .lista{ break-inside:auto } .lista li{ break-inside:avoid }
.tarjetas{ display:grid; gap:2.8mm }
.tarjetas.c2{ grid-template-columns:1fr 1fr } .tarjetas.c3{ grid-template-columns:1fr 1fr 1fr } .tarjetas.c1{ grid-template-columns:1fr }
.tarjeta{ display:flex; gap:3mm; align-items:flex-start; background:var(--crema); border:.3mm solid var(--linea);
  border-radius:2mm; padding:3.2mm; break-inside:avoid }
.tarjeta b{ display:block; font-size:9.6pt; line-height:1.3; margin-bottom:.6mm } .tarjeta span{ display:block; font-size:8.6pt; color:var(--suave); line-height:1.42 }
/* la negrita dentro del texto de una tarjeta va en línea (el título es el <b> de afuera) */
.tarjeta span b,.etapa span b,.cl-it span b,.ins span b,.rp span b{ display:inline; font-size:inherit; line-height:inherit; margin:0; color:var(--tinta) }
.rp span b{ color:#f3f7f3 }
.tico{ flex:none; width:8.6mm; height:8.6mm; display:flex; align-items:center; justify-content:center; background:var(--grafito);
  clip-path:polygon(0 0,calc(100% - 1.6mm) 0,100% 1.6mm,100% 100%,1.6mm 100%,0 calc(100% - 1.6mm)) }
.tico img{ width:5.2mm; height:5.2mm }

/* cajas */
.caja{ display:flex; gap:3.4mm; padding:3.4mm 4mm; border-radius:2mm; margin:3.5mm 0 4.5mm; break-inside:avoid; align-items:flex-start }
.caja-ic{ flex:none; width:7.4mm; height:7.4mm; border-radius:50%; display:flex; align-items:center; justify-content:center; background:#fff }
.caja-ic img{ width:4.4mm; height:4.4mm }
.caja-et{ font-size:7.4pt; font-weight:700; letter-spacing:.14em; text-transform:uppercase; margin-bottom:.6mm }
.caja-tx{ font-size:9.3pt; line-height:1.5 }
.consejo{ background:#eef8e6; border-left:1.1mm solid var(--verde) } .consejo .caja-et{ color:var(--tinta-verde) }
.nota{ background:#f1f3f1; border-left:1.1mm solid #9aa79f } .nota .caja-et{ color:#56625a }
.importante{ background:var(--ambar-claro); border-left:1.1mm solid var(--ambar) } .importante .caja-et{ color:#9a6510 }
.importante .caja-ic{ background:#2a1f0c }
body.cjk .caja-et{ letter-spacing:.04em }

/* Lya */
.lya{ display:flex; gap:4mm; align-items:flex-end; margin:4mm 0 5mm; break-inside:avoid }
.lya-av{ flex:none; height:19mm; image-rendering:pixelated; filter:drop-shadow(0 .8mm .8mm rgba(0,0,0,.25)) }
.globo{ position:relative; flex:1; background:var(--grafito); color:#e9efe9; padding:3.6mm 4.6mm; border-radius:2.2mm;
  font-size:9.6pt; line-height:1.52; border:.35mm solid #2e4034; margin-bottom:3mm }
.globo::before{ content:""; position:absolute; left:-2.2mm; bottom:3.2mm; width:4mm; height:4mm; background:var(--grafito);
  border-left:.35mm solid #2e4034; border-bottom:.35mm solid #2e4034; transform:rotate(45deg) }
.globo .quien{ color:var(--verde); font-weight:600; margin-right:1.4mm }
.globo code{ background:#24302a; color:var(--verde) } .globo kbd{ background:#24302a; color:#e9efe9; border-color:#3a4c40 }

/* novedad */
.novedad{ position:relative; background:var(--grafito); color:#e9efe9; padding:5mm 6mm 4mm; margin:5mm 0; break-inside:avoid;
  border:.35mm solid rgba(139,224,78,.45); clip-path:polygon(0 0,calc(100% - 4mm) 0,100% 4mm,100% 100%,4mm 100%,0 calc(100% - 4mm)) }
.novedad::before{ content:""; position:absolute; inset:0; background:radial-gradient(80mm 40mm at 100% 0, rgba(139,224,78,.2), transparent 70%) }
.nov-cab{ position:relative; display:flex; gap:3mm; align-items:center; flex-wrap:wrap }
.nov-chip{ background:var(--verde); color:#13200d; font-weight:700; font-size:7.6pt; letter-spacing:.12em; text-transform:uppercase; padding:.9mm 2.6mm; border-radius:1mm }
.nov-sub{ font-size:8.6pt; color:#a9b9ae }
.nov-tit{ position:relative; font-family:var(--titulos); font-weight:600; font-size:14pt; margin:2.6mm 0 2mm; color:#f3f7f3 }
.novedad ul{ position:relative; margin:0 }
.novedad li{ font-size:9.4pt }
body.cjk .nov-chip{ letter-spacing:.04em }

/* teclas y comandos */
.teclas{ margin:3mm 0 5mm; break-inside:avoid; border:.3mm solid var(--linea); border-radius:2mm; overflow:hidden }
.teclas h4{ margin:0; padding:2.4mm 3.6mm; background:var(--crema) }
.tecla-fila{ display:grid; grid-template-columns:52mm 1fr; gap:4mm; align-items:center; padding:2.2mm 3.6mm; border-top:.3mm solid var(--linea); font-size:9.2pt; line-height:1.42 }
.tecla-fila:first-child{ border-top:0 }
.tecla-k{ display:flex; flex-wrap:wrap; gap:1mm; align-items:center } .tecla-k .mas{ color:var(--tenue); font-weight:600 }
.comandos{ margin:3mm 0 5mm }
.comandos table{ width:100%; border-collapse:collapse; font-size:9.1pt }
.comandos td{ padding:1.9mm 2.6mm; border-bottom:.3mm solid var(--linea); vertical-align:top; line-height:1.42 }
.comandos tr{ break-inside:avoid }
.comandos td:first-child{ width:62mm }
.comandos tr:nth-child(odd) td{ background:#f7faf5 }

/* preguntas */
.faq{ break-inside:avoid; margin:0 0 4mm; padding-bottom:3.6mm; border-bottom:.3mm solid var(--linea) }
.faq-q{ display:flex; gap:3mm; font-family:var(--titulos); font-weight:600; font-size:11pt; line-height:1.32; margin-bottom:1.6mm }
.faq-q span{ flex:none; width:6mm; height:6mm; border-radius:50%; background:var(--grafito); color:var(--verde); font-size:9pt;
  display:flex; align-items:center; justify-content:center; margin-top:.2mm }
.faq-a{ padding-left:9mm; font-size:9.4pt }

/* enlace grande */
.enlace{ display:flex; gap:5mm; align-items:center; background:var(--grafito); color:#e9efe9; padding:5mm 6mm; margin:4mm 0 5mm; break-inside:avoid;
  clip-path:polygon(0 0,calc(100% - 4mm) 0,100% 4mm,100% 100%,4mm 100%,0 calc(100% - 4mm)) }
.enlace > img{ width:12mm; height:12mm }
.enl-tit{ font-family:var(--titulos); font-weight:600; font-size:13pt } .enlace a{ color:var(--verde); font-weight:600; font-size:11pt }
.enl-tx{ font-size:9pt; color:#a9b9ae; margin-top:1mm }

/* créditos */
.creditos{ width:100%; border-collapse:collapse; font-size:8.9pt; margin:2mm 0 5mm }
.creditos td{ padding:1.8mm 2.4mm; border-bottom:.3mm solid var(--linea); vertical-align:top; line-height:1.4 }
.creditos tr{ break-inside:avoid }
.creditos td:first-child{ width:46mm } .creditos .lic{ width:34mm; color:var(--suave); white-space:nowrap; text-align:right }

/* poses de Lya */
.poses{ display:grid; grid-template-columns:repeat(5,1fr); gap:2.4mm; margin:3mm 0 5mm; break-inside:avoid }
.pz{ background:var(--grafito); border-radius:2mm; padding:3mm 2mm 2.4mm; display:flex; flex-direction:column; align-items:center; gap:2mm }
.pz-img{ height:15mm; image-rendering:pixelated } .pz span{ font-size:8pt; color:#c9d5cc; text-align:center; line-height:1.3 }

/* ilustraciones */
.il{ background:var(--crema); border:.3mm solid var(--linea); border-radius:2.4mm; padding:5mm }
.il figcaption{ margin-top:3.6mm }
.rot-escena{ display:flex; flex-direction:column; align-items:center; gap:2mm }
.rot{ position:relative; display:grid; grid-template-columns:auto auto; gap:2.4mm 4mm; align-items:end;
  background:#0f1411; padding:6mm 8mm 4.5mm; border-radius:2mm }
.rot-col{ display:flex; flex-direction:column; align-items:center; gap:2mm }
.rot-lab{ font-size:8pt; font-weight:600; color:#9fb0a5; text-transform:uppercase; letter-spacing:.1em }
body.cjk .rot-lab{ letter-spacing:.03em }
.hab{ position:relative; display:flex; align-items:center; justify-content:center; background:linear-gradient(145deg,#2c3a30,#18211b);
  border:.4mm solid #3b4f41; border-radius:1.4mm }
.hab img{ width:55% }
.rot-grande{ position:relative }
.hab.g{ width:24mm; height:24mm } .hab.c{ width:13mm; height:13mm }
.hab.brilla{ box-shadow:0 0 0 .6mm var(--verde), 0 0 4mm rgba(139,224,78,.7) }
.barrido{ position:absolute; inset:0; border-radius:1.2mm; background:conic-gradient(rgba(0,0,0,.72) 0 150deg, rgba(0,0,0,0) 150deg 360deg) }
.rot-chicas{ position:relative; display:flex; gap:2mm }
.area{ position:absolute; top:-2.6mm; left:50%; transform:translateX(-50%); background:var(--ambar); color:#2a1a02; font-size:6.8pt; font-weight:700;
  padding:.3mm 1.8mm; border-radius:.8mm; text-transform:uppercase; letter-spacing:.06em; white-space:nowrap; z-index:2 }
.kb{ position:absolute; right:1.2mm; top:1mm; font-size:7.4pt; font-weight:700; color:#fff; z-index:2 }
.rot-porque{ position:relative; grid-column:1 / span 2; font-size:8.8pt; color:#d5e2d8; text-align:center; padding:1.6mm 0 0; border-top:.3mm solid #26332b }
.rot-et{ display:flex; gap:10mm; font-size:8.4pt; color:var(--suave) }
.m1,.m2,.m3,.m4,.m5{ position:absolute; width:5.4mm; height:5.4mm; border-radius:50%; background:var(--verde); color:#11200c; font-weight:700;
  font-size:7.6pt; display:flex; align-items:center; justify-content:center; box-shadow:0 0 0 .6mm #fff; z-index:3 }
.m1{ left:-3mm; top:-3mm } .m4{ right:-3mm; bottom:-3mm } .m2{ right:-3mm; top:-3mm } .m3{ left:68%; top:26%; margin:-2.7mm 0 0 -2.7mm }
.m5{ position:relative; display:inline-flex; margin-right:2mm; vertical-align:middle }

.raton{ display:flex; gap:7mm; align-items:center; justify-content:center }
.raton-dib{ position:relative; flex:none; width:22mm; height:34mm }
.rcuerpo{ position:absolute; inset:0; border:.6mm solid #2b382f; border-radius:11mm 11mm 12mm 12mm; background:#fff }
.rb{ position:absolute; top:0; width:11mm; height:14mm; border-bottom:.6mm solid #2b382f; z-index:1 }
.rb.izq{ left:0; border-right:.3mm solid #2b382f; border-radius:11mm 0 0 0; background:#e4f5d6 } .rb.der{ right:0; border-radius:0 11mm 0 0 }
.rueda{ position:absolute; left:50%; top:3.4mm; width:2.6mm; height:6mm; margin-left:-1.3mm; border-radius:1.3mm; background:#2b382f; z-index:2 }
.raton table{ border-collapse:separate; border-spacing:1.4mm; font-size:8.4pt }
.raton th{ font-weight:600; color:var(--suave); text-align:left; padding:0 1mm; white-space:nowrap }
.raton td{ background:#fff; border:.3mm solid var(--linea); border-radius:1.4mm; padding:1.6mm 2.4mm; min-width:27mm; line-height:1.3 }
.raton td.vacia{ color:var(--tenue); text-align:center }

.pesca-il{ display:flex; flex-direction:column; gap:4mm; align-items:center }
.pp-tecla{ display:flex; align-items:center; gap:3mm; font-size:9pt; color:var(--suave) }
kbd.grande{ font-size:12pt; padding:1mm 9mm; border-bottom-width:1.2mm }
.pp-fila{ display:flex; align-items:stretch; gap:1.6mm; width:100% }
.pp{ flex:1; background:var(--grafito); color:#e9efe9; border-radius:2mm; padding:3.4mm 2.4mm; display:flex; flex-direction:column; align-items:center; gap:1.4mm; text-align:center }
.pp-ic img{ width:7mm; height:7mm } .pp-n{ font-weight:700; color:var(--verde); font-size:8pt }
.pp-tx{ font-size:8.4pt; line-height:1.35 }
.pp-fl{ align-self:center; font-size:16pt; color:var(--verde-osc); font-weight:600 }

.mapa-il{ display:grid; grid-template-columns:1fr 46mm; gap:5mm; align-items:start }
.mventana{ background:var(--grafito); border-radius:2mm; overflow:hidden; border:.35mm solid #2e4034 }
.mcab{ display:flex; align-items:center; justify-content:space-between; padding:2mm 3mm; border-bottom:.3mm solid #2a3a30; color:#e9efe9; font-size:8.6pt }
.mbarra{ display:flex; gap:1.6mm } .mb{ width:6mm; height:6mm; display:flex; align-items:center; justify-content:center; background:#1f2a23; border-radius:1mm }
.mb img{ width:3.8mm; height:3.8mm }
.mlienzo{ position:relative; height:66mm; background:
  repeating-linear-gradient(0deg, rgba(139,224,78,.05) 0 .3mm, transparent .3mm 8mm),
  repeating-linear-gradient(90deg, rgba(139,224,78,.05) 0 .3mm, transparent .3mm 8mm), #16201a }
.mzona{ position:absolute; border:.35mm dashed rgba(139,224,78,.28); border-radius:40% 55% 45% 50% }
.z1{ left:6%; top:10%; width:42%; height:52% } .z2{ left:46%; top:30%; width:44%; height:58% } .z3{ left:14%; top:58%; width:30%; height:34% }
.mrio{ position:absolute; left:0; right:0; top:52%; height:2.2mm; background:rgba(90,150,200,.35); transform:rotate(-8deg) }
.mpin{ position:absolute; width:6.4mm; height:6.4mm; margin:-3.2mm 0 0 -3.2mm; border-radius:50%; display:flex; align-items:center; justify-content:center; font-weight:700; font-size:8pt }
.mpin img{ width:3.8mm; height:3.8mm }
.mpin.tu{ left:34%; top:40%; background:#0f1411; box-shadow:0 0 0 .6mm var(--verde), 0 0 4mm rgba(139,224,78,.7) }
.mpin.vuelo{ left:64%; top:22%; background:#1d3a14; box-shadow:0 0 0 .5mm var(--verde) }
.mpin.vuelo2{ left:82%; top:70%; background:#3a2a0c; color:var(--ambar); box-shadow:0 0 0 .5mm var(--ambar) }
.mpin.marcador{ left:20%; top:76%; background:#0f1411; box-shadow:0 0 0 .5mm #6fc3ff }
.mpin.mazm{ left:60%; top:62%; background:#0f1411; box-shadow:0 0 0 .5mm #c9a2ff }
.mpin.salida{ left:93%; top:40%; background:#0f1411; color:var(--verde); box-shadow:0 0 0 .4mm rgba(139,224,78,.6) }
.mzoom{ position:absolute; right:2.4mm; bottom:2.4mm; display:flex; flex-direction:column; gap:1mm }
.mzoom span{ width:5.6mm; height:5.6mm; background:#1f2a23; color:#e9efe9; display:flex; align-items:center; justify-content:center; border-radius:1mm; font-size:9pt; font-weight:600 }
.mzoom span img{ width:3.4mm }
.mchip{ position:absolute; display:flex; align-items:center; gap:1mm; background:rgba(8,10,10,.82); color:#e9efe9; font-size:6.8pt;
  padding:.5mm 1.6mm .5mm 1mm; border-radius:3mm; white-space:nowrap; border:.25mm solid rgba(139,224,78,.35) }
.mchip img{ width:2.8mm; height:2.8mm }
.c-tu{ left:37%; top:45% } .c-vuelo{ left:67%; top:16% } .c-vuelo2{ right:12%; top:76% } .c-marcador{ left:23%; top:83% }
.c-mazm{ left:47%; top:69% } .c-salida{ right:3%; top:28% }
.mley{ margin:0; font-size:8.4pt }
.mley li{ display:flex; gap:2mm; align-items:center; padding:0 0 1.9mm; margin:0 0 1.9mm; border-bottom:.3mm solid var(--linea); line-height:1.3 }
.mley li::before{ display:none }
.mley img{ width:4.2mm; height:4.2mm; flex:none } .mley .mz{ font-weight:700; color:var(--tinta-verde); width:4.2mm; flex:none; font-size:7.6pt; white-space:nowrap }

.cuadro-il{ display:flex; justify-content:center }
.cuadro{ background:#0e1310; border:.4mm solid #46524a; border-radius:1.6mm; padding:3.2mm 4.4mm; color:#f0f0f0; font-size:9pt; line-height:1.55; min-width:110mm; box-shadow:0 1mm 3mm rgba(0,0,0,.3) }
.cl.t{ color:#1eff00; font-weight:600; font-size:10pt } .cl.g{ color:#c7cfc9 } .cl.a{ color:#8be04e } .cl.o{ color:#ffd200 }

.ins-fila{ display:grid; grid-template-columns:repeat(4,1fr); gap:2.4mm }
.ins{ position:relative; background:#fff; border:.3mm solid var(--linea); border-radius:2mm; padding:3mm 3mm 3mm; display:flex; flex-direction:column; gap:.8mm }
.ins .n{ width:6mm; height:6mm; border-radius:1mm; background:var(--verde); color:#132010; font-weight:700; display:flex; align-items:center; justify-content:center; font-size:8.4pt }
.ins b{ font-size:9.2pt; line-height:1.3 } .ins span{ font-size:8.2pt; color:var(--suave); line-height:1.38 }

.secs{ display:grid; grid-template-columns:repeat(7,1fr); gap:1.8mm }
.sec{ background:var(--grafito); border-radius:1.6mm; padding:3mm 1mm; display:flex; flex-direction:column; align-items:center; gap:1.6mm; color:#e9efe9 }
.sec img{ width:6mm; height:6mm } .sec b{ font-size:7.8pt; text-align:center; line-height:1.2 }
"""


# ---------------------------------------------------------------------------
# Revisión en el navegador (antes de imprimir)
# ---------------------------------------------------------------------------
JS_REVISAR = r"""
() => {
  const out = [];
  const corto = s => (s || '').replace(/\s+/g, ' ').trim().slice(0, 70);
  document.querySelectorAll('.hoja').forEach(h => {
    const caja = h.getBoundingClientRect();
    h.querySelectorAll('*').forEach(el => {
      if (!el.textContent.trim() || el.children.length) return;
      const r = el.getBoundingClientRect();
      if (r.width && (r.right > caja.right + 1 || r.bottom > caja.bottom + 1 || r.left < caja.left - 1))
        out.push('fuera de su hoja (' + h.dataset.id + '): ' + corto(el.textContent));
    });
  });
  document.querySelectorAll('.flujo').forEach(f => {
    const caja = f.getBoundingClientRect();
    f.querySelectorAll('*').forEach(el => {
      const cs = getComputedStyle(el);
      if (cs.display === 'inline' || !el.clientWidth) return;
      const propio = [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
      if (propio && el.scrollWidth > el.clientWidth + 1)
        out.push('texto más ancho que su caja: ' + corto(el.textContent));
      const r = el.getBoundingClientRect();
      if (r.right > caja.right + 1.5)
        out.push('se sale del margen: ' + corto(el.textContent || el.tagName));
    });
  });
  document.querySelectorAll('img').forEach(i => { if (!i.naturalWidth) out.push('imagen sin cargar: ' + i.getAttribute('src')); });
  return out;
}
"""


# ---------------------------------------------------------------------------
# PDF
# ---------------------------------------------------------------------------
class Impresora:
    def __init__(self):
        self.pw = None
        self.navegador = None
        try:
            from playwright.sync_api import sync_playwright
            self.pw = sync_playwright().start()
            self.navegador = self.pw.chromium.launch(channel="msedge", headless=True)
        except Exception as e:     # sin Playwright: Edge directo, sin revisión previa
            print("  (Playwright no disponible: %s; se usa msedge --print-to-pdf)" % str(e).splitlines()[0])
            self.navegador = None

    def imprimir(self, html_path: pathlib.Path, pdf_path: pathlib.Path) -> list:
        if self.navegador:
            pagina = self.navegador.new_page(viewport={"width": 900, "height": 1200})
            pagina.goto(html_path.as_uri(), wait_until="load")
            pagina.evaluate("document.fonts.ready")
            problemas = pagina.evaluate(JS_REVISAR)
            pagina.pdf(path=str(pdf_path), prefer_css_page_size=True, print_background=True, outline=True, tagged=True)
            pagina.close()
            return problemas
        edge = next((p for p in [pathlib.Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
                                 pathlib.Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe")] if p.exists()), None)
        if not edge:
            raise SystemExit("No encontré Microsoft Edge para imprimir el PDF.")
        perfil = tempfile.mkdtemp(prefix="alfa-edge-")   # un Edge aparte, aunque tengas uno abierto
        try:
            subprocess.run([str(edge), "--headless=new", "--disable-gpu", "--no-first-run", "--user-data-dir=" + perfil,
                            "--no-pdf-header-footer", "--generate-pdf-document-outline", "--allow-file-access-from-files",
                            "--virtual-time-budget=8000", "--print-to-pdf=" + str(pdf_path), html_path.as_uri()],
                           check=True, capture_output=True, timeout=300)
        finally:
            shutil.rmtree(perfil, ignore_errors=True)
        if not pdf_path.exists():
            raise SystemExit("Edge no pudo imprimir el PDF (%s)." % pdf_path.name)
        return []

    def cerrar(self):
        if self.navegador:
            self.navegador.close()
        if self.pw:
            self.pw.stop()


def paginas_del_indice(pdf_path: pathlib.Path, datos: dict) -> dict:
    """Lee el índice del PDF (los h1 de las partes y los h2 de los capítulos)."""
    import fitz
    doc = fitz.open(str(pdf_path))
    toc = doc.get_toc()
    doc.close()
    titulos = [(nivel, texto_plano(t).strip(), pag) for nivel, t, pag in toc]
    res = {}
    cola = []
    for parte in datos["partes"]:
        cola.append(("parte-" + parte["id"], 1, texto_plano(parte["titulo"]).strip()))
        for cap in parte["capitulos"]:
            cola.append(("cap-" + cap["id"], 2, texto_plano(cap["titulo"]).strip()))
    i = 0
    for clave, nivel, titulo in cola:
        while i < len(titulos) and (titulos[i][1] != titulo or titulos[i][0] != nivel):
            i += 1
        if i < len(titulos):
            res[clave] = titulos[i][2]
            i += 1
    return res


MM = 72 / 25.4
RALO = 0.34   # una última página llena a menos de esto se intenta acomodar


def llenado(pagina) -> float:
    """Qué tanto de la caja de texto de una página está ocupada (0 a 1)."""
    alto = pagina.rect.height
    arriba, abajo = 15 * MM, alto - 18 * MM
    fondo = arriba
    for b in pagina.get_text("blocks"):
        if b[1] > abajo - 1 or b[3] < arriba + 1:
            continue
        fondo = max(fondo, b[3])
    for info in pagina.get_image_info():
        fondo = max(fondo, min(info["bbox"][3], abajo))
    for d in pagina.get_drawings():
        r = d.get("rect")
        if r is not None and r.height < alto * 0.9 and r.y1 < abajo + 1:
            fondo = max(fondo, r.y1)
    return max(0.0, (fondo - arriba) / (abajo - arriba))


def medir_capitulos(pdf_path: pathlib.Path, paginas: dict) -> dict:
    """Por capítulo: (cuántas páginas ocupa, qué tanto se llena la última)."""
    import fitz
    doc = fitz.open(str(pdf_path))
    inicios = sorted((n, clave) for clave, n in paginas.items())
    res = {}
    for i, (n, clave) in enumerate(inicios):
        if not clave.startswith("cap-"):
            continue
        fin = (inicios[i + 1][0] - 1) if i + 1 < len(inicios) else len(doc) - 1
        res[clave[4:]] = (fin - n + 1, llenado(doc[fin - 1]))
    doc.close()
    return res


def revisar_pdf(pdf_path: pathlib.Path, cjk) -> list:
    """Páginas vacías o casi vacías, y letras que ninguna fuente tiene."""
    import fitz
    from fontTools.ttLib import TTFont, TTCollection
    problemas = []
    doc = fitz.open(str(pdf_path))
    cmaps = []
    for archivo in ["Inter-Regular.ttf", "FiraSans-SemiBold.ttf"]:
        cmaps.append(set(TTFont(str(LETRAS / archivo)).getBestCmap()))
    if cjk:
        for archivo in cjk[1]:
            ruta = pathlib.Path(r"C:\Windows\Fonts") / archivo
            if ruta.suffix.lower() == ".ttc":
                cmaps.append(set(TTCollection(str(ruta)).fonts[0].getBestCmap()))
            else:
                cmaps.append(set(TTFont(str(ruta)).getBestCmap()))
    faltan = {}
    for n, pagina in enumerate(doc, 1):
        texto = pagina.get_text()
        imagenes = pagina.get_images()
        dibujos = len(pagina.get_drawings())
        if not texto.strip() and not imagenes and dibujos < 3:
            problemas.append("página %d vacía" % n)
        elif 1 < n < len(doc):
            f = llenado(pagina)
            if f < 0.18:
                problemas.append("página %d casi vacía (ocupa el %.0f%% de la hoja)" % (n, f * 100))
        for marca in ("**", "[[", "]]", "`"):
            if marca in texto:
                problemas.append("página %d tiene una marca de formato suelta: %s" % (n, marca))
        for ch in texto:
            if ch.isspace() or ord(ch) < 32:
                continue
            if ch == "\ufffd" or not any(ord(ch) in c for c in cmaps):
                faltan[ch] = faltan.get(ch, 0) + 1
        for f in pagina.get_fonts():
            nombre = f[3]
            if "LastResort" in nombre or "Emoji" in nombre:
                problemas.append("página %d usa la letra %s" % (n, nombre))
    if faltan:
        problemas.append("letras sin fuente propia (podrían salir en cuadritos): " +
                         " ".join("%s(U+%04X)x%d" % (c, ord(c), k) for c, k in sorted(faltan.items())))
    doc.close()
    return problemas


def pintar(pdf_path: pathlib.Path, carpeta: pathlib.Path, nombre: str) -> None:
    """Cada página a PNG y una hoja de muestra con todas, para revisarlas a ojo."""
    import fitz
    carpeta.mkdir(parents=True, exist_ok=True)
    doc = fitz.open(str(pdf_path))
    miniaturas = []
    for i, pagina in enumerate(doc, 1):
        pm = pagina.get_pixmap(dpi=110)
        ruta = carpeta / ("%s-%02d.png" % (nombre, i))
        pm.save(str(ruta))
        im = Image.open(ruta).convert("RGB")
        im.thumbnail((300, 425))
        miniaturas.append(im)
    doc.close()
    cols = 8
    filas = (len(miniaturas) + cols - 1) // cols
    hoja = Image.new("RGB", (cols * 310, filas * 435), (120, 120, 120))
    for i, im in enumerate(miniaturas):
        hoja.paste(im, ((i % cols) * 310 + 5, (i // cols) * 435 + 5))
    hoja.save(carpeta / ("%s-muestra.png" % nombre))


FIJAS = {"t", "id", "img", "marcas", "icono", "pose", "ref", "cols", "lado", "prop", "ancho", "cmd", "url", "tipo", "c"}


def comparar(base, otro, ruta="") -> list:
    """Diferencias de estructura entre el JSON del español de México y otro idioma:
    mismas claves, mismos bloques en el mismo orden, mismas imágenes, íconos,
    comandos y enlaces, y los mismos comandos `/alfa ...` y huecos {v} en cada texto."""
    dif = []
    if isinstance(base, dict):
        if not isinstance(otro, dict):
            return ["%s: debería ser un objeto" % ruta]
        for k in base:
            if k not in otro:
                dif.append("%s.%s: falta" % (ruta, k))
            elif k in FIJAS and base[k] != otro[k] and not (k == "t" and re.search(r"\.lineas\[\d+\]$", ruta)):
                dif.append("%s.%s: debe quedar %r (dice %r)" % (ruta, k, base[k], otro[k]))
            elif k not in ("idioma", "nombre"):
                dif += comparar(base[k], otro[k], "%s.%s" % (ruta, k))
        for k in otro:
            if k not in base:
                dif.append("%s.%s: sobra" % (ruta, k))
    elif isinstance(base, list):
        if not isinstance(otro, list) or len(base) != len(otro):
            return ["%s: debería tener %d elementos" % (ruta, len(base))]
        for i, (a, b) in enumerate(zip(base, otro)):
            if ruta.endswith(".poses.items") or (isinstance(a, list) and a and a[0] in POSES):
                if a[0] != b[0]:
                    dif.append("%s[%d]: la pose debe quedar %r" % (ruta, i, a[0]))
            if ruta.endswith(".e.items") and isinstance(a, list) and a[0] != b[0]:
                dif.append("%s[%d]: el ícono debe quedar %r" % (ruta, i, a[0]))
            dif += comparar(a, b, "%s[%d]" % (ruta, i))
    elif isinstance(base, str):
        if not isinstance(otro, str):
            return ["%s: debería ser texto" % ruta]
        cmds = lambda t: sorted(re.findall(r"`(/[^`]+)`", t))
        if cmds(base) != cmds(otro):
            dif.append("%s: los comandos deben quedar igual %s (dice %s)" % (ruta, cmds(base), cmds(otro)))
        for hueco in ("{v}", "{j}"):
            if (hueco in base) != (hueco in otro):
                dif.append("%s: falta o sobra %s" % (ruta, hueco))
        if base.startswith("http") and base != otro:
            dif.append("%s: el enlace debe quedar %r" % (ruta, base))
        # lo vacío en español (una celda sin acción, que sale «—») queda vacío; los textos de ui.* sí se llenan
        if base == "" and otro != "" and not ruta.startswith(".ui."):
            dif.append("%s: debe quedar vacío (dice %r)" % (ruta, otro[:40]))
    return dif


def armar(idioma: str, rec: dict, carpeta: pathlib.Path, impresora: Impresora, version: str,
          html_dir=None, revisar_dir=None) -> int:
    archivo, etiqueta, cjk = IDIOMAS[idioma]
    datos = json.loads((TEXTOS / f"{idioma}.json").read_text(encoding="utf-8"))
    estructura = []
    if idioma != "esMX":
        estructura = ["estructura " + d for d in comparar(json.loads((TEXTOS / "esMX.json").read_text(encoding="utf-8")), datos)]
    datos["lang"] = etiqueta
    clases = []
    if cjk:
        clases.append("cjk")
        clases.append({"ko": "ko", "zh-Hans": "zh", "zh-Hant": "zh"}[etiqueta])
    datos["clase"] = " ".join(clases)
    css = letras_css(cjk) + CSS.replace("VAR_CJK", ("'%s'," % cjk[0]) if cjk else "")
    salida = MANUAL / archivo
    html_path = carpeta / f"manual-{idioma}.html"
    paginas = {}
    problemas = []

    def pasada(apretar, nombre):
        a = Armado(datos, rec, version, paginas, apretar)
        html_path.write_text(a.documento(css), encoding="utf-8")
        tmp = carpeta / f"manual-{idioma}-{nombre}.pdf"
        return a, tmp, impresora.imprimir(html_path, tmp)

    # 1) acomodo: cada capítulo empieza en su página. Si la última de un capítulo
    #    queda casi vacía, se prueban tres niveles de apretado (imágenes más chicas,
    #    menos aire) y se queda el que use menos páginas o llene mejor la última.
    a, tmp_pdf, problemas = pasada({}, "a0")
    paginas = paginas_del_indice(tmp_pdf, datos)
    base = medir_capitulos(tmp_pdf, paginas)
    ralos = [c for c, (n, f) in base.items() if n > 1 and f < RALO]
    mejor = {c: (0, base[c]) for c in ralos}
    for nivel in (1, 2, 3):
        if not ralos:
            break
        _, tmp_pdf, _ = pasada({c: nivel for c in ralos}, "a%d" % nivel)
        medida = medir_capitulos(tmp_pdf, paginas_del_indice(tmp_pdf, datos))
        for c in ralos:
            n, f = medida.get(c, (99, 0))
            bn, bf = mejor[c][1]
            if n < bn or (n == bn and f > bf + 0.02):
                mejor[c] = (nivel, (n, f))
    apretar = {c: v[0] for c, v in mejor.items() if v[0]}
    if apretar:
        a, tmp_pdf, problemas = pasada(apretar, "acomodo")
        paginas = paginas_del_indice(tmp_pdf, datos)
    # 2) la pasada final, con los números de página en el índice
    a, tmp_pdf, problemas = pasada(apretar, "final")
    nuevas = paginas_del_indice(tmp_pdf, datos)
    if nuevas != paginas:
        problemas.append("el índice cambió en la pasada final: %s" % {k: (paginas.get(k), v) for k, v in nuevas.items() if paginas.get(k) != v})
    shutil.copy(tmp_pdf, salida)
    if apretar:
        print("   (apretados: %s)" % ", ".join("%s x%d" % kv for kv in sorted(apretar.items())))
    problemas = estructura + a.avisos + problemas + revisar_pdf(salida, cjk)
    import fitz
    with fitz.open(str(salida)) as doc:
        total = len(doc)
        doc.set_metadata({"title": "Alfa · " + datos["ui"]["titulo_manual"], "author": "toxic3000 · La Jauría",
                          "subject": datos["ui"]["portada_sub"], "keywords": "Alfa, WoW Forever, La Jauría",
                          "creator": "tools/manual.py", "producer": "Alfa"})
        doc.saveIncr()
    if html_dir:
        pathlib.Path(html_dir).mkdir(parents=True, exist_ok=True)
        destino = pathlib.Path(html_dir) / f"manual-{idioma}"
        if destino.exists():
            shutil.rmtree(destino)
        shutil.copytree(carpeta, destino, ignore=shutil.ignore_patterns("*.pdf", "manual-*.html"))
        shutil.copy(html_path, destino / "index.html")
    if revisar_dir:
        pintar(salida, pathlib.Path(revisar_dir), idioma)
    estado = "bien" if not problemas else "%d avisos" % len(problemas)
    print("%s: %s, %d páginas (%s)" % (idioma, salida.relative_to(RAIZ), total, estado))
    for p in problemas:
        print("   -", p)
    return len(problemas)


def main(argv) -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    args = list(argv)

    def valor(op):
        if op in args:
            i = args.index(op)
            v = args[i + 1]
            del args[i:i + 2]
            return v
        return None

    html_dir = valor("--html")
    revisar_dir = valor("--revisar")
    if "--capturas" in args:
        args.remove("--capturas")
        print("Capturas:")
        capturas()
    idiomas = [a for a in args if a in IDIOMAS] or [i for i in IDIOMAS if (TEXTOS / f"{i}.json").exists()]
    faltan = [a for a in args if a not in IDIOMAS]
    if faltan:
        print("Idiomas que no conozco:", ", ".join(faltan), "| conozco:", ", ".join(IDIOMAS))
        return 2
    version = leer_version()
    total = 0
    with tempfile.TemporaryDirectory(prefix="alfa-manual-") as tmp:
        carpeta = pathlib.Path(tmp)
        rec = recursos(carpeta)
        impresora = Impresora()
        try:
            for idioma in idiomas:
                total += armar(idioma, rec, carpeta, impresora, version, html_dir, revisar_dir)
        finally:
            impresora.cerrar()
    print("RESULTADO:", "todo bien" if total == 0 else "%d avisos" % total)
    return 0 if total == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
