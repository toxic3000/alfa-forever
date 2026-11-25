"""Guías por tramo de nivel (1.4.0, «la manada firme»; plan 1.4.0, número 4).

Después de tools/diferir.py, cada guía de los paquetes de guías trae sus pasos
como un texto largo (`stepsSrc = [====[return { ... }]====]`). Ese texto es casi
todo el peso de Alfa_Guides (2 MB) y de Alfa_Guides_<facción> (3 MB), y Lua lo
lee entero al entrar aunque solo abras una guía.

Este paso los saca a paquetes que cargan a pedido:

    Guides.lua:   stepsSrc = [====[...]====]   ->   stepsPart = "Alfa_Guides_Horde_Pasos1", alfaStart = {...}
    Alfa_Guides_Horde_Pasos1/Pasos.lua:
        Alfa.RegisterGuideSteps("guides", { ["forever/horde/02-the-barrens"] = [====[...]====], ... })

Siete paquetes:
  * Alfa_Guides_<Horde|Alliance>_Pasos1..3: niveles 1-19, 20-39 y 40-60. Las
    guías de subida y de clase de esa facción con un rango corto, y también las
    de clase de Alfa_Guides (de las dos facciones) de ese tramo, copiadas en los
    dos lados: así las de tu clase llegan con el paquete de tu tramo, que ya se
    carga por la guía que sigues. Su ficha dice `stepsPart = "Alfa_Guides_*_Pasos2"`
    y el motor pone tu facción en el `*`.
  * Alfa_Guides_Pasos: todo lo de cualquier nivel (oficios, reputación,
    coleccionables, exploración y las de rango largo), de las dos facciones.

La ficha de cada guía (título, niveles, zona, `next`, `qref`, `groupQuests`,
`dungeonMaps`...) se queda en Guides.lua: el motor, la Biblioteca, Planes, el
Asistente, las búsquedas y la Enciclopedia siguen viendo todas las guías. Lleva
además `alfaStart`: dónde empieza la guía (el primer objetivo con mapa y
coordenadas, como Guides.Start), para que las sugerencias al entrar no abran
los pasos. Si no se puede saber seguro (los pasos usan una tabla del
preámbulo), no se escribe y el motor lee los pasos como antes. Los pasos
llegan cuando alguien lee `g.steps` (Guides.Steps carga el paquete;
tools/parches.py, bloque 1.4.0).

`juntar` lo deshace byte por byte (la construcción lo comprueba antes de
escribir nada, y tools/prueba.py lo usa para comparar con las guías como venían).
Trabaja en latin-1 byte por byte, como build.py y diferir.py.
"""
import pathlib
import re
import shutil
import sys

PAQUETES = ("Alfa_Guides", "Alfa_Guides_Alliance", "Alfa_Guides_Horde")
LADOS = {"Alfa_Guides_Horde": "Horde", "Alfa_Guides_Alliance": "Alliance"}
VARIOS = "Alfa_Guides_Pasos"
SEPARA = re.compile(r"(?=\n-- Source: )")
FUENTE = re.compile(r"stepsSrc = (\[(=+)\[.*?\]\2\])", re.S)
PARTE = re.compile(r'stepsPart = "([A-Za-z0-9_*]+)"(, alfaStart = (?:false|\{[^{}\n]*\}))?')
CABEZA = "-- Alfa (1.4.0): los pasos de las guías de %s (tools/tramos.py). Carga a pedido.\n"

IDIOMAS = ("enUS", "deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW")
PRE = {"enUS": "Alfa Guides", "deDE": "Alfa Guides", "esMX": "Alfa: guías", "esES": "Alfa: guías",
       "frFR": "Alfa : guides", "ptBR": "Alfa: guias", "ruRU": "Alfa: гайды", "koKR": "Alfa 가이드",
       "zhCN": "Alfa 指南", "zhTW": "Alfa 指南"}
LADO_TXT = {"Horde": {"enUS": "Horde", "esMX": "Horda", "esES": "Horda", "deDE": "Horde", "frFR": "Horde", "ptBR": "Horda",
                      "ruRU": "Орда", "koKR": "호드", "zhCN": "部落", "zhTW": "部落"},
            "Alliance": {"enUS": "Alliance", "esMX": "Alianza", "esES": "Alianza", "deDE": "Allianz", "frFR": "Alliance",
                         "ptBR": "Aliança", "ruRU": "Альянс", "koKR": "얼라이언스", "zhCN": "联盟", "zhTW": "聯盟"}}
NIVELES = {"enUS": "levels %s", "esMX": "niveles %s", "esES": "niveles %s", "deDE": "Stufen %s", "frFR": "niveaux %s",
           "ptBR": "níveis %s", "ruRU": "уровни %s", "koKR": "레벨 %s", "zhCN": "等级 %s", "zhTW": "等級 %s"}
RANGOS = {"1": "1-19", "2": "20-39", "3": "40-60"}
PASOS = {"enUS": "steps", "esMX": "pasos", "esES": "pasos", "deDE": "Schritte", "frFR": "étapes", "ptBR": "passos",
         "ruRU": "шаги", "koKR": "단계", "zhCN": "步骤", "zhTW": "步驟"}
OTRAS = {"enUS": "professions, reputation and more", "esMX": "oficios, reputación y más",
         "esES": "oficios, reputación y más", "deDE": "Berufe, Ruf und mehr", "frFR": "métiers, réputation et plus",
         "ptBR": "profissões, reputação e mais", "ruRU": "профессии, репутация и другое", "koKR": "전문 기술, 평판 등",
         "zhCN": "专业、声望等", "zhTW": "專業、聲望等"}
NOTAS = {"enUS": "The steps of some of Alfa's guides. Loaded on demand, when a guide is opened.",
         "esMX": "Los pasos de una parte de las guías de Alfa. Se carga a pedido, al abrir una guía.",
         "esES": "Los pasos de una parte de las guías de Alfa. Se carga bajo demanda, al abrir una guía.",
         "deDE": "Die Schritte eines Teils der Alfa-Guides. Wird bei Bedarf geladen, wenn ein Guide geöffnet wird.",
         "frFR": "Les étapes d'une partie des guides d'Alfa. Chargé à la demande, à l'ouverture d'un guide.",
         "ptBR": "Os passos de uma parte dos guias do Alfa. Carregado sob demanda, ao abrir um guia.",
         "ruRU": "Шаги части гайдов Alfa. Загружается по требованию, при открытии гайда.",
         "koKR": "Alfa 가이드 일부의 단계. 가이드를 열 때 필요할 때 불러옵니다.",
         "zhCN": "部分 Alfa 指南的步骤。打开指南时按需加载。",
         "zhTW": "部分 Alfa 指南的步驟。開啟指南時按需載入。"}


class NoEncaja(Exception):
    pass


# ---------------------------------------------------------------------------
# Dónde empieza una guía, leído del texto de sus pasos (sin correrlo): un
# lector chico de tablas de Lua. Lo que no sea un dato escrito ahí mismo (una
# variable del preámbulo, una llamada) sale como DESCONOCIDO, y entonces la
# ficha no lleva `alfaStart`.
_TOKEN = re.compile(r"""
    (?P<espacio>\s+)
  | (?P<comentario_largo>--\[(?P<cq>=*)\[.*?\](?P=cq)\])
  | (?P<comentario>--[^\n]*)
  | (?P<largo>\[(?P<lq>=*)\[.*?\](?P=lq)\])
  | (?P<texto>"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')
  | (?P<numero>0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)
  | (?P<nombre>[A-Za-z_][A-Za-z_0-9]*)
  | (?P<signo>\.\.\.|\.\.|==|~=|<=|>=|[{}\[\]=,;()+\-*/%^#<>.:])
""", re.S | re.X)


class _Desconocido(Exception):
    pass


class _Ref:
    pass


REF = _Ref()


def _tokens(s):
    i, n, out = 0, len(s), []
    while i < n:
        m = _TOKEN.match(s, i)
        if not m:
            raise _Desconocido("token")
        k = m.lastgroup
        if k not in ("espacio", "comentario", "comentario_largo"):
            if k in ("largo", "texto"):
                out.append(("texto", m.group(0)))
            else:
                out.append((k, m.group(0)))
        i = m.end()
    return out


def _leer_tabla(tk, i):
    """tk[i] es '{'. -> (tabla {pos: [...], campos: {}}, índice después de '}')."""
    pos, campos = [], {}
    i += 1
    while True:
        k, v = tk[i]
        if (k, v) == ("signo", "}"):
            return {"pos": pos, "campos": campos}, i + 1
        if k == "nombre" and tk[i + 1] == ("signo", "="):
            val, i = _leer_valor(tk, i + 2)
            campos[v] = val
        elif (k, v) == ("signo", "["):
            _, i = _leer_valor(tk, i + 1)
            if tk[i] != ("signo", "]") or tk[i + 1] != ("signo", "="):
                raise _Desconocido("clave")
            _, i = _leer_valor(tk, i + 2)
            # (una clave [x] puede pisar una posición: no se puede saber seguro)
            campos["\0rara"] = REF
        else:
            val, i = _leer_valor(tk, i)
            pos.append(val)
        k, v = tk[i]
        if (k, v) in (("signo", ","), ("signo", ";")):
            i += 1
        elif (k, v) != ("signo", "}"):
            raise _Desconocido("separador")


def _leer_valor(tk, i):
    k, v = tk[i]
    if (k, v) == ("signo", "{"):
        return _leer_tabla(tk, i)
    if k == "texto":
        j = i + 1
        if tk[j] == ("signo", ".."):
            raise _Desconocido("concatenación")
        return ("texto", v), j
    if k == "numero":
        if tk[i + 1][0] == "signo" and tk[i + 1][1] in ("+", "-", "*", "/", "%", "^", ".."):
            raise _Desconocido("cuenta")
        return ("numero", v), i + 1
    if (k, v) == ("signo", "-") and tk[i + 1][0] == "numero":
        if tk[i + 2][0] == "signo" and tk[i + 2][1] in ("+", "-", "*", "/", "%", "^", ".."):
            raise _Desconocido("cuenta")
        return ("numero", "-" + tk[i + 1][1]), i + 2
    if k == "nombre" and v in ("true", "false", "nil"):
        return ("bool", v), i + 1
    if k == "nombre":
        # Una variable del preámbulo (`candidateRecords[1]`, `a.b`): un
        # dato que no se sabe aquí. Una llamada o una cuenta: no se lee.
        i += 1
        while True:
            if tk[i] == ("signo", "["):
                _, i = _leer_valor(tk, i + 1)
                if tk[i] != ("signo", "]"):
                    raise _Desconocido("índice")
                i += 1
            elif tk[i] == ("signo", ".") and tk[i + 1][0] == "nombre":
                i += 2
            else:
                break
        if tk[i][0] == "signo" and tk[i][1] in ("(", ":", "..", "+", "-", "*", "/", "%", "^", "{") or tk[i][0] == "texto":
            raise _Desconocido("expresión")
        return REF, i
    raise _Desconocido("valor")


def inicio_de(src: str):
    """-> el texto Lua de `alfaStart` ("false" o "{ map = ..., x = ..., y = ... }"), o None si no se sabe."""
    j = src.find("return {")
    if j < 0:
        return None
    try:
        tk = _tokens(src[j + len("return "):]) + [("fin", "")] * 4
        pasos, _ = _leer_tabla(tk, 0)
    except (_Desconocido, IndexError):
        return None
    if "\0rara" in pasos["campos"]:
        return None
    for paso in pasos["pos"]:
        if not isinstance(paso, dict) or "\0rara" in paso["campos"]:
            return None
        metas = paso["campos"].get("goals")
        if not isinstance(metas, dict) or "\0rara" in metas["campos"]:
            return None
        for meta in metas["pos"]:
            if not isinstance(meta, dict) or "\0rara" in meta["campos"]:
                return None
            c = meta["campos"]
            vals = [c.get("map"), c.get("x"), c.get("y")]
            if any(x is REF for x in vals) or c.get("f") is REF:
                return None
            if all(x is not None and x != ("bool", "nil") and x != ("bool", "false") for x in vals):
                if not all(x[0] == "numero" for x in vals):
                    return None
                f = c.get("f")
                if f is not None and f[0] != "texto":
                    return None
                partes = ["map = %s" % vals[0][1], "x = %s" % vals[1][1], "y = %s" % vals[2][1]]
                if f is not None:
                    partes.append("f = %s" % f[1])
                return "{ " + ", ".join(partes) + " }"
    return "false"


# ---------------------------------------------------------------------------
def destino(paquete: str, bloque: str):
    """-> (stepsPart de la ficha, [paquetes donde va el texto])."""
    ficha = bloque[:bloque.find("stepsSrc = [")]
    cat = re.search(r'\n\t+category = "([^"]*)"', ficha)
    mn = re.search(r"\n\t+minLevel = (\d+)", ficha)
    mx = re.search(r"\n\t+maxLevel = (\d+)", ficha)
    cat = cat and cat.group(1)
    t = None
    if cat in ("Leveling", "Class", "Legacy") and mn and mx and int(mx.group(1)) - int(mn.group(1)) <= 20:
        a = int(mn.group(1))
        t = "1" if a < 20 else ("2" if a < 40 else "3")
    if paquete == "Alfa_Guides" and cat not in ("Class", "Legacy"):
        t = None
    if t is None:
        return VARIOS, [VARIOS]
    if paquete == "Alfa_Guides":
        return "Alfa_Guides_*_Pasos" + t, ["Alfa_Guides_%s_Pasos%s" % (l, t) for l in ("Horde", "Alliance")]
    nombre = "%s_Pasos%s" % (paquete, t)
    return nombre, [nombre]


def toc_de(nombre: str, version: str) -> str:
    m = re.match(r"Alfa_Guides_(Horde|Alliance)_Pasos(\d)$", nombre)
    lineas = ["## Interface: 16001"]
    for loc in IDIOMAS:
        if m:
            que = "%s, %s, %s" % (LADO_TXT[m.group(1)][loc], PASOS[loc], NIVELES[loc] % RANGOS[m.group(2)])
        else:
            que = "%s: %s" % (PASOS[loc], OTRAS[loc])
        sufijo = "" if loc == "enUS" else "-" + loc
        lineas.append("## Title%s: %s (%s)" % (sufijo, PRE[loc], que))
        lineas.append("## Notes%s: %s" % (sufijo, NOTAS[loc]))
    deps = "Alfa, Alfa_Guides" + (", Alfa_Guides_" + m.group(1) if m else "")
    lineas += ["## Author: Alfa", "## Version: %s" % version, "## Category: Alfa", "## Group: Alfa",
               "## LoadOnDemand: 1", "## Dependencies: %s" % deps, "## X-Alfa-Part: guides",
               "## X-License: GPL-3.0-only",
               "# Generado por tools/tramos.py al construir: no se edita a mano.", "", "Pasos.lua", ""]
    return "\n".join(lineas)


def partir_texto(paquete: str, texto: str, partes: dict):
    """-> Guides.lua nuevo; agrega a partes { paquete: [(pack, id, literal)] }."""
    out = []
    for bloque in SEPARA.split(texto):
        m = FUENTE.search(bloque)
        if not m:
            if "stepsSrc" in bloque:
                raise NoEncaja("%s: stepsSrc con forma rara: %s" % (paquete, bloque[:80].strip()))
            out.append(bloque)
            continue
        gid = re.search(r'\n\t+id = "([^"]+)"', bloque)
        pack = re.search(r'\n\t+pack = "([^"]+)"', bloque)
        if not (gid and pack):
            raise NoEncaja("%s: guía sin id o sin pack: %s" % (paquete, bloque[:80].strip()))
        if FUENTE.search(bloque, m.end()):
            raise NoEncaja("%s: dos stepsSrc en %s" % (paquete, gid.group(1)))
        parte, destinos = destino(paquete, bloque)
        for d in destinos:
            partes.setdefault(d, []).append((pack.group(1), gid.group(1), m.group(1)))
        lit = m.group(1)
        cuerpo = lit[lit.index("[", 1) + 1:lit.rindex("]", 0, len(lit) - 1)]
        inicio = inicio_de(cuerpo)
        extra = ", alfaStart = %s" % inicio if inicio is not None else ""
        out.append(bloque[:m.start()] + 'stepsPart = "%s"%s' % (parte, extra) + bloque[m.end():])
    return "".join(out)


def archivo_parte(nombre: str, guias: list) -> str:
    out = [CABEZA % nombre]
    packs = []
    for pack, _, _ in guias:
        if pack not in packs:
            packs.append(pack)
    for pack in packs:
        out.append('Alfa.RegisterGuideSteps("%s", {\n' % pack)
        for p, gid, lit in guias:
            if p == pack:
                out.append('\t["%s"] = %s,\n' % (gid, lit))
        out.append("})\n")
    return "".join(out)


def leer_parte(texto: str) -> dict:
    """Pasos.lua -> { id: literal }."""
    out = {}
    for m in re.finditer(r'^\t\["([^"]+)"\] = (\[(=+)\[.*?\]\3\]),(?=\n)', texto, re.S | re.M):
        out[m.group(1)] = m.group(2)
    return out


def juntar_texto(texto: str, fuentes: dict) -> str:
    out = []
    for bloque in SEPARA.split(texto):
        m = PARTE.search(bloque)
        if m:
            gid = re.search(r'\n\t+id = "([^"]+)"', bloque).group(1)
            if gid not in fuentes:
                raise NoEncaja("falta el texto de los pasos de %s" % gid)
            bloque = bloque[:m.start()] + "stepsSrc = " + fuentes[gid] + bloque[m.end():]
        out.append(bloque)
    return "".join(out)


def carpetas_de_pasos(dist: pathlib.Path) -> list:
    return sorted(p for p in dist.glob("Alfa_Guides*_Pasos*") if p.is_dir())


def partir(dist: pathlib.Path, version: str) -> dict:
    """-> { paquete de pasos: guías }. Comprueba la vuelta antes de escribir."""
    if carpetas_de_pasos(dist):
        raise NoEncaja("ya hay paquetes de pasos en %s" % dist)
    if not all((dist / p / "Guides.lua").exists() for p in PAQUETES):
        raise NoEncaja("faltan paquetes de guías en %s" % dist)
    partes, viejos, nuevos = {}, {}, {}
    for paquete in PAQUETES:
        p = dist / paquete / "Guides.lua"
        texto = p.read_bytes().decode("latin-1")
        if "stepsPart = " in texto:
            raise NoEncaja("%s ya estaba partido" % p)
        viejos[paquete] = texto
        nuevos[paquete] = partir_texto(paquete, texto, partes)
    archivos = {n: archivo_parte(n, g) for n, g in partes.items()}
    fuentes = {}
    for a in archivos.values():
        for gid, lit in leer_parte(a).items():
            if gid in fuentes and fuentes[gid] != lit:
                raise NoEncaja("dos textos distintos para %s" % gid)
            fuentes[gid] = lit
    for paquete in PAQUETES:
        if juntar_texto(nuevos[paquete], fuentes) != viejos[paquete]:
            raise NoEncaja("%s: la vuelta no da el mismo archivo" % paquete)
    hechos = {}
    lic = dist / "Alfa_Guides" / "LICENSE-DATA.txt"
    for nombre, a in sorted(archivos.items()):
        carpeta = dist / nombre
        carpeta.mkdir()
        (carpeta / "Pasos.lua").write_bytes(a.encode("latin-1"))
        (carpeta / (nombre + ".toc")).write_bytes(toc_de(nombre, version).encode("utf-8"))
        if lic.exists():
            shutil.copy2(lic, carpeta / "LICENSE-DATA.txt")
        hechos[nombre] = len(partes[nombre])
    for paquete in PAQUETES:
        (dist / paquete / "Guides.lua").write_bytes(nuevos[paquete].encode("latin-1"))
    return hechos


def juntar(dist: pathlib.Path) -> int:
    """Lo contrario de partir: los pasos de vuelta en Guides.lua, sin paquetes de pasos."""
    fuentes = {}
    carpetas = carpetas_de_pasos(dist)
    for c in carpetas:
        fuentes.update(leer_parte((c / "Pasos.lua").read_bytes().decode("latin-1")))
    for paquete in PAQUETES:
        p = dist / paquete / "Guides.lua"
        if p.exists():
            p.write_bytes(juntar_texto(p.read_bytes().decode("latin-1"), fuentes).encode("latin-1"))
    for c in carpetas:
        shutil.rmtree(c)
    return len(fuentes)


# ---------------------------------------------------------------------------
# El Codex por partes (1.4.0, plan 5). Alfa_Codex (7,5 MB, unos 33 ms de leer
# en el banco) se queda con lo chico y lo que se busca (meta, zonas,
# instancias, calabozos, hechizos, facciones y el índice de búsqueda); los
# objetos van a un paquete a pedido, y los PNJ con las misiones a otro. El motor
# carga el de un grupo la primera vez que alguien pregunta por él (parche en
# Alfa/Lookup/Codex.lua, tools/parches.py).
CODEX = "Alfa_Codex"
CODEX_PARTES = {
    "Alfa_Codex_Objetos": ("item", "mount", "pet", "recipe", "tabard"),
    "Alfa_Codex_Mundo": ("npc", "rare", "role", "object", "treasure", "quest"),
}
CODEX_NOMBRES = {
    "Alfa_Codex_Objetos": {"enUS": "items", "esMX": "objetos", "esES": "objetos", "deDE": "Gegenstände",
                           "frFR": "objets", "ptBR": "itens", "ruRU": "предметы", "koKR": "아이템",
                           "zhCN": "物品", "zhTW": "物品"},
    "Alfa_Codex_Mundo": {"enUS": "NPCs and quests", "esMX": "PNJ y misiones", "esES": "PNJ y misiones",
                         "deDE": "NPCs und Quests", "frFR": "PNJ et quêtes", "ptBR": "PNJs e missões",
                         "ruRU": "NPC и задания", "koKR": "NPC와 퀘스트", "zhCN": "NPC 和任务", "zhTW": "NPC 與任務"},
}
NOTAS_CODEX = {"enUS": "Part of Alfa's Codex. Loaded on demand, the first time Alfa asks for it.",
               "esMX": "Parte del Codex de Alfa. Se carga a pedido, la primera vez que Alfa la necesita.",
               "esES": "Parte del Codex de Alfa. Se carga bajo demanda, la primera vez que Alfa la necesita.",
               "deDE": "Teil von Alfas Codex. Wird bei Bedarf geladen, wenn Alfa ihn zum ersten Mal braucht.",
               "frFR": "Partie du Codex d'Alfa. Chargé à la demande, la première fois qu'Alfa en a besoin.",
               "ptBR": "Parte do Codex do Alfa. Carregado sob demanda, na primeira vez que o Alfa precisa.",
               "ruRU": "Часть Кодекса Alfa. Загружается по требованию, когда Alfa впервые его запрашивает.",
               "koKR": "Alfa 코덱스의 일부. Alfa가 처음 필요할 때 불러옵니다.",
               "zhCN": "Alfa 典籍的一部分。Alfa 第一次需要时按需加载。",
               "zhTW": "Alfa 典籍的一部分。Alfa 第一次需要時按需載入。"}


def grupo_codex(texto: str):
    m = re.findall(r'\bC\.Register\("([a-z]+)"', texto)
    return set(m)


def partir_codex(dist: pathlib.Path, version: str) -> dict:
    """-> { paquete: [archivos] }. Mueve los archivos del Codex por su grupo."""
    base = dist / CODEX
    toc = base / (CODEX + ".toc")
    if not toc.exists():
        return {}
    grupo_a = {g: p for p, gs in CODEX_PARTES.items() for g in gs}
    lineas = toc.read_bytes().decode("utf-8").split("\n")
    quedan, movidos = [], {p: [] for p in CODEX_PARTES}
    for l in lineas:
        s = l.strip()
        if s and not s.startswith("#") and s.endswith(".lua"):
            grupos = grupo_codex((base / s).read_bytes().decode("latin-1"))
            destinos = {grupo_a.get(g) for g in grupos}
            if len(destinos) > 1:
                raise NoEncaja("%s registra grupos de partes distintas: %s" % (s, sorted(grupos)))
            destino = destinos.pop() if destinos else None
            if destino:
                movidos[destino].append(s)
                continue
        quedan.append(l)
    for p, archivos in movidos.items():
        if not archivos:
            raise NoEncaja("el Codex ya no trae archivos para %s" % p)
        carpeta = dist / p
        if carpeta.exists():
            raise NoEncaja("%s ya existe" % carpeta)
        carpeta.mkdir()
        for a in archivos:
            shutil.move(str(base / a), str(carpeta / a))
        if (base / "LICENSE-DATA.txt").exists():
            shutil.copy2(base / "LICENSE-DATA.txt", carpeta / "LICENSE-DATA.txt")
        t = ["## Interface: 16001"]
        for loc in ("enUS", "deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"):
            suf = "" if loc == "enUS" else "-" + loc
            t.append("## Title%s: Alfa Codex (%s)" % (suf, CODEX_NOMBRES[p][loc]))
            t.append("## Notes%s: %s" % (suf, NOTAS_CODEX[loc]))
        t += ["## Author: Alfa", "## Version: %s" % version, "## Category: Alfa", "## Group: Alfa",
              "## LoadOnDemand: 1", "## Dependencies: Alfa, Alfa_Codex", "## X-Alfa-Part: codex",
              "## X-License: GPL-3.0-only", "# Generado por tools/tramos.py al construir: no se edita a mano.", ""]
        t += archivos + [""]
        (carpeta / (p + ".toc")).write_bytes("\n".join(t).encode("utf-8"))
    toc.write_bytes("\n".join(quedan).encode("utf-8"))
    return movidos


if __name__ == "__main__":
    # python -I tools/tramos.py [--juntar] [dist]
    raiz = pathlib.Path(__file__).resolve().parent.parent
    args = [a for a in sys.argv[1:] if a != "--juntar"]
    destino = pathlib.Path(args[0]) if args else raiz / "dist"
    if "--juntar" in sys.argv:
        print("guías juntadas:", juntar(destino))
    else:
        import json
        cfg = json.loads((raiz / "tools" / "alfa.json").read_text(encoding="utf-8"))
        for nombre, n in partir(destino, cfg["version"]).items():
            print(nombre, n)
