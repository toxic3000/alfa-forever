"""Paint a DUMP() of the mocked frames into a PNG (a faithful-ish preview of
the layout the code computes: grounds, cut corners, hairlines, pills, text)."""
import pathlib
import re

from PIL import Image, ImageDraw, ImageFont

FONTS = {}
SYMBOL = r"C:\Windows\Fonts\seguisym.ttf"
GLYPH = {
    "chevron-down": "\u2304", "chevron-right": "\u203a", "chevron-left": "\u2039", "chevron-up": "\u2303",
    "check": "\u2713", "close": "\u00d7", "star": "\u2605", "plus": "+", "search": "\u2315", "cross": "\u00d7",
    "info": "i", "lock": "\u25a3", "circle": "\u25cf", "layers": "\u2263", "guides": "\u2630",
}


def font(path_hint: str, size: float, fonts_dir: pathlib.Path):
    name = "Inter-Medium.ttf"
    m = re.search(r"([A-Za-z]+-[A-Za-z]+)\.ttf", path_hint or "")
    if m and (fonts_dir / (m.group(1) + ".ttf")).exists():
        name = m.group(1) + ".ttf"
    key = (name, round(size))
    if key not in FONTS:
        FONTS[key] = ImageFont.truetype(str(fonts_dir / name), max(6, round(size)))
    return FONTS[key]


def symbol(size):
    key = ("sym", round(size))
    if key not in FONTS:
        try:
            FONTS[key] = ImageFont.truetype(SYMBOL, max(6, round(size)))
        except OSError:
            FONTS[key] = ImageFont.load_default()
    return FONTS[key]


def segments(text, base):
    """'|cffRRGGBBtext|r' -> [(text, rgb)]"""
    out, cur = [], base
    pos = 0
    for m in re.finditer(r"\|c([0-9a-fA-F]{8})|\|r|\|T[^|]*\|t", text):
        if m.start() > pos:
            out.append((text[pos:m.start()], cur))
        tok = m.group(0)
        if tok.startswith("|c"):
            h = m.group(1)
            cur = (int(h[2:4], 16), int(h[4:6], 16), int(h[6:8], 16), base[3])
        elif tok == "|r":
            cur = base
        pos = m.end()
    if pos < len(text):
        out.append((text[pos:], cur))
    return out


def plain(text):
    return re.sub(r"\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t", "", text)


TEXTURAS = {}
USADAS = {}


def textura(ruta: str, dist: pathlib.Path):
    """La imagen real de una textura propia de un addon (archivo .tga o .png) o None."""
    if ruta in TEXTURAS:
        return TEXTURAS[ruta]
    img = None
    partes = ruta.replace("\\", "/").split("/")
    if len(partes) > 3 and partes[0].lower() == "interface" and partes[1].lower() == "addons":
        base = dist.joinpath(*partes[2:])
        for cand in (base, base.with_name(base.name + ".tga"), base.with_name(base.name + ".png")):
            if cand.is_file() and cand.suffix.lower() in (".tga", ".png"):
                try:
                    img = Image.open(cand).convert("RGBA")
                except OSError:
                    img = None
                break
    TEXTURAS[ruta] = img
    return img


def pegar(base, img, caja, color, tc):
    """Pega la textura recortada por sus coordenadas y teñida por su color de vértice."""
    x0, y0, x1, y1 = caja
    w, h = int(round(x1 - x0)), int(round(y1 - y0))
    if w <= 0 or h <= 0:
        return
    W, H = img.size
    if tc and len(tc) >= 4:
        if len(tc) == 8:  # ULx,ULy,LLx,LLy,URx,URy,LRx,LRy
            l, t, r, b = tc[0], tc[1], tc[6], tc[7]
        else:
            l, r, t, b = tc[0], tc[1], tc[2], tc[3]
        flipx, flipy = l > r, t > b
        cl, cr = sorted((l, r))
        ct, cb = sorted((t, b))
        img = img.crop((int(cl * W), int(ct * H), max(int(cl * W) + 1, int(cr * W)), max(int(ct * H) + 1, int(cb * H))))
        if flipx:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        if flipy:
            img = img.transpose(Image.FLIP_TOP_BOTTOM)
    img = img.resize((w, h), Image.LANCZOS)
    r, g, b, a = img.split()
    cr, cg, cb, ca = color
    r = r.point(lambda v: v * cr // 255)
    g = g.point(lambda v: v * cg // 255)
    b = b.point(lambda v: v * cb // 255)
    a = a.point(lambda v: v * ca // 255)
    img = Image.merge("RGBA", (r, g, b, a))
    # pegar con su alfa como máscara mezcla sobre el fondo (ImageDraw en RGB también)
    base.paste(img.convert("RGB"), (int(round(x0)), int(round(y0))), a)


def wrap(draw, text, fnt, width):
    lines = []
    for para in text.split("\n"):
        words = para.split(" ")
        line = ""
        for w in words:
            cand = (line + " " + w) if line else w
            if width > 0 and draw.textlength(plain(cand), font=fnt) > width and line:
                lines.append(line)
                line = w
            else:
                line = cand
        lines.append(line)
    return lines


# Textos que no cupieron al dibujarlos (cortados con «…» o con renglones de más):
# run.py los lista como CORTADO para que no se cuelen en la interfaz.
CORTES = []


def render(entries, rect, out_path, fonts_dir, scale=1.25):
    l0, b0, w0, h0 = rect
    W, H = int(w0 * scale), int(h0 * scale)
    base = Image.new("RGB", (W, H), (34, 40, 48))
    d = ImageDraw.Draw(base, "RGBA")
    dist = pathlib.Path(fonts_dir).parents[2]
    entries = sorted(entries, key=lambda e: (e["strata"], e["level"], e["layer"], e["sub"], e["seq"]))

    def box(e):
        x0 = (e["l"] - l0) * scale
        y0 = (b0 + h0 - (e["b"] + e["h"])) * scale
        return x0, y0, x0 + e["w"] * scale, y0 + e["h"] * scale

    def restaurar():
        while recortes:
            caja, viejo, (cx0, cy0, cx1, cy1) = recortes.pop()
            mascara = Image.new("L", viejo.size, 255)
            ImageDraw.Draw(mascara).rectangle([cx0 - caja[0], cy0 - caja[1], cx1 - caja[0] - 1, cy1 - caja[1] - 1], fill=0)
            base.paste(viejo, caja[:2], mascara)

    recortes = []
    for e in entries:
        restaurar()
        a = e.get("a", 1) * e.get("alpha", 1)
        if a <= 0.01:
            continue
        col = (int(255 * max(0, min(1, e["r"]))), int(255 * max(0, min(1, e["g"]))), int(255 * max(0, min(1, e["bb"]))), int(255 * max(0, min(1, a))))
        x0, y0, x1, y1 = box(e)
        if e.get("cw") is not None:
            cx0 = (e["cl"] - l0) * scale
            cy0 = (b0 + h0 - (e["cb"] + e["ch"])) * scale
            cx1, cy1 = cx0 + e["cw"] * scale, cy0 + e["ch"] * scale
            if y1 < cy0 or y0 > cy1 or x1 < cx0 or x0 > cx1:
                continue
            # lo que se sale del area con desplazamiento no se ve: se dibuja y luego
            # se devuelve el fondo que habia fuera del recorte
            if y0 < cy0 or y1 > cy1 or x0 < cx0 or x1 > cx1:
                caja = (max(0, int(x0) - 6), max(0, int(y0) - 6), min(W, int(x1) + 6), min(H, int(y1) + 6))
                if caja[2] > caja[0] and caja[3] > caja[1]:
                    recortes.append((caja, base.crop(caja), (cx0, cy0, cx1, cy1)))
        if e["kind"] == "Texture" and e.get("g1") is not None and (e.get("tex") or "").endswith("white"):
            g1, g2 = e["g1"], e["g2"]
            g1 = list(g1.values()) if hasattr(g1, "values") else list(g1)
            g2 = list(g2.values()) if hasattr(g2, "values") else list(g2)
            vert = e.get("gorient") == "VERTICAL"
            n = int((y1 - y0) if vert else (x1 - x0))
            for i in range(max(1, n)):
                t = i / max(1, n - 1)
                # VERTICAL: c1 at the bottom, c2 at the top
                if vert:
                    t = 1 - t
                cc = [g1[k] + (g2[k] - g1[k]) * t for k in range(4)]
                fill = tuple(int(255 * max(0, min(1, v))) for v in cc[:3]) + (int(255 * max(0, min(1, cc[3] * e.get("alpha", 1)))),)
                if vert:
                    d.line([(x0, y0 + i), (x1, y0 + i)], fill=fill)
                else:
                    d.line([(x0 + i, y0), (x0 + i, y1)], fill=fill)
            continue
        if e["kind"] == "Texture":
            if e["w"] <= 0 or e["h"] <= 0:
                continue
            tex = (e.get("tex") or "").replace("\\", "/").split("/")[-1]
            real = None if (tex in ("white", "color", "cut", "circle") or tex.startswith("cut-line")) else textura(e.get("tex") or "", dist)
            if real is not None:
                USADAS[e.get('tex')] = USADAS.get(e.get('tex'), 0) + 1
                tc = e.get("tc")
                tc = list(tc.values()) if hasattr(tc, "values") else (list(tc) if tc else None)
                pegar(base, real, (x0, y0, x1, y1), col, tc)
                d = ImageDraw.Draw(base, "RGBA")
            elif tex in ("white", "color") or tex.startswith("band"):
                d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=col)
            elif tex == "cut":
                if e.get("flip"):
                    d.polygon([(x0, y0), (x1, y0), (x0, y1)], fill=col)
                else:
                    d.polygon([(x1, y0), (x1, y1), (x0, y1)], fill=col)
            elif tex.startswith("cut-line"):
                d.line([(x1, y0), (x0, y1)], fill=col, width=max(1, int(scale)))
            elif tex == "circle":
                half = e.get("half")
                if half == "L":
                    d.pieslice([x0, y0, x0 + 2 * (x1 - x0), y1], 90, 270, fill=col)
                elif half == "R":
                    d.pieslice([x1 - 2 * (x1 - x0), y0, x1, y1], 270, 90, fill=col)
                else:
                    d.ellipse([x0, y0, x1, y1], fill=col)
            elif tex in ("shadow", "glow", "emblem-hot", "veil-soft", "watermark", "wordmark", "wordmark-small", "band-stars"):
                pass
            elif tex.isdigit() or ("/" in (e.get("tex") or "").replace("\\", "/") and "addons/" not in (e.get("tex") or "").replace("\\", "/").lower()):
                # arte o icono del juego (el simulador no lo tiene): una ficha sobria
                d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=(30, 38, 32, 255))
                d.rectangle([x0, y0, x1 - 1, y1 - 1], outline=(70, 96, 64, 255), width=max(1, int(scale)))
                r = min(x1 - x0, y1 - y0) * 0.22
                cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
                d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], outline=(120, 170, 90, 255), width=max(1, int(scale)))
            else:
                g = GLYPH.get(tex)
                size = (y1 - y0) * 0.95
                if tex == "emblem":
                    d.polygon([((x0 + x1) / 2, y0), (x1, (y0 + y1) / 2), ((x0 + x1) / 2, y1), (x0, (y0 + y1) / 2)], outline=col, width=2)
                elif g:
                    fnt = symbol(size)
                    tw = d.textlength(g, font=fnt)
                    d.text(((x0 + x1) / 2 - tw / 2, (y0 + y1) / 2), g, font=fnt, fill=col, anchor="lm")
                else:
                    # a glyph: a small facet in its colour
                    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
                    r = min(x1 - x0, y1 - y0) * 0.38
                    d.rectangle([cx - r, cy - r, cx + r, cy + r], outline=col, width=max(1, int(scale)))
        else:
            text = e.get("text") or ""
            if text == "":
                continue
            fnt = font(e.get("fontpath", ""), e["size"] * scale, fonts_dir)
            width = e["setw"] * scale if e["setw"] and e["setw"] > 0 else 0
            if e["wrap"] and width > 0:
                lines = wrap(d, text, fnt, width)
            else:
                lines = text.split("\n")
            if e.get("maxl"):
                if len(lines) > e["maxl"]:
                    CORTES.append((out_path.stem if hasattr(out_path, "stem") else str(out_path), plain(text)[:90], "renglones"))
                lines = lines[: e["maxl"]]
            lh = (e["size"] + 3) * scale
            total = lh * len(lines)
            jv = e.get("jv", "MIDDLE")
            if jv == "TOP":
                ty = y0
            elif jv == "BOTTOM":
                ty = y1 - total
            else:
                ty = (y0 + y1) / 2 - total / 2
            for line in lines:
                pl = plain(line)
                if width > 0 and not e["wrap"] and d.textlength(pl, font=fnt) > width + 1:
                    CORTES.append((out_path.stem if hasattr(out_path, "stem") else str(out_path), pl[:90], "ancho"))
                    while pl and d.textlength(pl + "\u2026", font=fnt) > width:
                        pl = pl[:-1]
                    line = pl + "\u2026"
                    pl = line
                tw = d.textlength(pl, font=fnt)
                jh = e.get("jh", "CENTER")
                if jh == "LEFT":
                    tx = x0
                elif jh == "RIGHT":
                    tx = x1 - tw
                else:
                    tx = (x0 + x1) / 2 - tw / 2
                x = tx
                for seg, c in segments(line, col):
                    d.text((x, ty + lh / 2), seg, font=fnt, fill=c, anchor="lm")
                    x += d.textlength(seg, font=fnt)
                ty += lh
    restaurar()
    base.save(out_path)
    return out_path
