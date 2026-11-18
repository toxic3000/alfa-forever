"""Cambia el nombre Polestar por Alfa en codigo y textos, sin tocar comentarios.

Los comentarios guardan los avisos de copyright y de licencia de Polestar y de
Shortest Path Forever; la GPL pide conservarlos tal cual, asi que no se tocan.
Tampoco se tocan las direcciones de Polestar (su repositorio y su sitio).
"""
import re

CAMBIOS = {"Polestar": "Alfa", "POLESTAR": "ALFA", "polestar": "alfa"}
PATRON = re.compile("|".join(CAMBIOS))
POLE = re.compile(r"/pole(?=[\s).,:;])")

# Fragmentos que nunca cambian: avisos de autoria y direcciones de Polestar.
PROTEGIDOS = [
    "fitzforge/polestar",
    "polestar.guide",
    "discord.gg/polestar",
    "Polestar authors",
    "Polestar Client",
]


def cambiar(texto: str) -> str:
    guardados = {}
    for i, frag in enumerate(PROTEGIDOS):
        marca = f"\x00{i}\x00"
        if frag in texto:
            texto = texto.replace(frag, marca)
            guardados[marca] = frag
    texto = PATRON.sub(lambda m: CAMBIOS[m.group(0)], texto)
    # Los textos que enseñan el comando corto ("/pole lookup") dicen /alfa;
    # el alias "/pole" (SLASH_ALFA2 = "/pole") sigue funcionando.
    texto = POLE.sub("/alfa", texto)
    for marca, frag in guardados.items():
        texto = texto.replace(marca, frag)
    return texto


def _nivel_largo(src: str, i: int):
    """Si en i empieza un corchete largo [==[ devuelve su nivel, si no None."""
    if src[i] != "[":
        return None
    j = i + 1
    while j < len(src) and src[j] == "=":
        j += 1
    if j < len(src) and src[j] == "[":
        return j - i - 1
    return None


def trozos_lua(src: str):
    """Parte un archivo Lua en ("codigo"|"texto"|"comentario", contenido)."""
    i, n, inicio = 0, len(src), 0
    while i < n:
        c = src[i]
        if c == "-" and src.startswith("--", i):
            if i > inicio:
                yield "codigo", src[inicio:i]
            nivel = _nivel_largo(src, i + 2) if i + 2 < n else None
            if nivel is not None:
                cierre = "]" + "=" * nivel + "]"
                fin = src.find(cierre, i + 4 + nivel)
                fin = n if fin < 0 else fin + len(cierre)
            else:
                fin = src.find("\n", i)
                fin = n if fin < 0 else fin
            yield "comentario", src[i:fin]
            i = inicio = fin
            continue
        if c == "[":
            nivel = _nivel_largo(src, i)
            if nivel is not None:
                if i > inicio:
                    yield "codigo", src[inicio:i]
                cierre = "]" + "=" * nivel + "]"
                fin = src.find(cierre, i + 2 + nivel)
                fin = n if fin < 0 else fin + len(cierre)
                yield "texto", src[i:fin]
                i = inicio = fin
                continue
        if c in "\"'":
            if i > inicio:
                yield "codigo", src[inicio:i]
            j = i + 1
            while j < n and src[j] != c and src[j] != "\n":
                j += 2 if src[j] == "\\" else 1
            fin = min(j + 1, n)
            yield "texto", src[i:fin]
            i = inicio = fin
            continue
        i += 1
    if inicio < n:
        yield "codigo", src[inicio:]


def cambiar_lua(src: str) -> str:
    return "".join(
        t if tipo == "comentario" else cambiar(t) for tipo, t in trozos_lua(src)
    )


def cambiar_xml(src: str) -> str:
    partes = re.split(r"(<!--.*?-->)", src, flags=re.S)
    return "".join(p if p.startswith("<!--") else cambiar(p) for p in partes)


def cambiar_toc(src: str) -> str:
    salida = []
    for linea in re.split(r"(?<=\n)", src):  # no splitlines(): ver build.py
        sin = linea.lstrip()
        es_comentario = sin.startswith("#") and not sin.startswith("##")
        if es_comentario or sin.startswith("## X-License"):
            salida.append(linea)
        else:
            salida.append(cambiar(linea))
    return "".join(salida)
