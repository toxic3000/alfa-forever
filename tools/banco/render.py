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


def render(entries, rect, out_path, fonts_dir, scale=1.25):
    l0, b0, w0, h0 = rect
    W, H = int(w0 * scale), int(h0 * scale)
    base = Image.new("RGB", (W, H), (34, 40, 48))
    d = ImageDraw.Draw(base, "RGBA")
    entries = sorted(entries, key=lambda e: (e["strata"], e["level"], e["layer"], e["sub"], e["seq"]))

    def box(e):
        x0 = (e["l"] - l0) * scale
        y0 = (b0 + h0 - (e["b"] + e["h"])) * scale
        return x0, y0, x0 + e["w"] * scale, y0 + e["h"] * scale

    for e in entries:
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
            if tex in ("white", "color") or tex.startswith("band"):
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
            elif tex.isdigit():
                d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=(90, 80, 60, 255))
                d.rectangle([x0 + 2, y0 + 2, x1 - 3, y1 - 3], outline=(160, 140, 90, 255))
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
                if width > 0 and not e["wrap"] and d.textlength(pl, font=fnt) > width:
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
    base.save(out_path)
    return out_path
