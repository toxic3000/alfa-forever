"""Guías con pasos diferidos (1.3.4, docs/DISENO-GUIAS-DIFERIDAS.md).

Pasa los pasos de cada guía de los paquetes de guías de dist/ a texto:

    steps = { ... }   ->   stepCount = N, stepsSrc = [====[return { ... }]====],
                           groupQuests = { ... }, qref = { q = {...}, p = {...}, c = {...} }

El motor ya sabe leerlos (Core/Guides.lua, «Deferred steps»): al entrar solo
se lee un texto por guía y los pasos se arman la primera vez que se abre.

La ficha lleva lo que el motor lee de todas las guías sin abrir sus pasos:
- groupQuests: las misiones de grupo (`when group`), para Opciones.
- qref: qué misiones toca la guía (q: cualquier `quest = N`; p: las de
  `pre`/`preAll`; c: las de `closedBy`). Es un índice de candidatas: puede
  sobrar alguna, nunca faltar (Guides.QuestGuides en tools/parches.py; la
  prueba prueba_134_guias.lua lo comprueba contra los pasos ya armados).

Trabaja en latin-1 byte por byte, como build.py. Si algo no encaja, se detiene.
"""
import pathlib
import re
import sys

BS = chr(92)
PAQUETES = ("Alfa_Guides", "Alfa_Guides_Alliance", "Alfa_Guides_Horde")


class NoEncaja(Exception):
    pass


def saltar_texto(s, i):
    q = s[i]
    i += 1
    while s[i] != q:
        if s[i] == "\n":
            raise NoEncaja("texto sin cerrar")
        i += 2 if s[i] == BS else 1
    return i


def fin_tabla(s, i):
    """i apunta a '{'; devuelve el índice del '}' que la cierra."""
    depth = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c == '"' or c == "'":
            i = saltar_texto(s, i)
        elif c == "[" and re.match(r"\[=*\[", s[i:i + 10]):
            m = re.match(r"\[(=*)\[", s[i:])
            cierre = "]" + m.group(1) + "]"
            i = s.index(cierre, i) + len(cierre) - 1
        elif c == "-" and s.startswith("--", i):
            i = s.index("\n", i)
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise NoEncaja("tabla sin cierre")


def contar_entradas(tabla):
    """Elementos de primer nivel de una tabla { ... } de tablas."""
    depth = 0
    n = 0
    i = 0
    while i < len(tabla):
        c = tabla[i]
        if c == '"' or c == "'":
            i = saltar_texto(tabla, i)
        elif c == "{":
            if depth == 1:
                n += 1
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    return n


def numeros_en(tabla, clave):
    """Los números de `clave = { 1, 2 }` (o `clave = 3`) en todo el texto."""
    out = []
    for m in re.finditer(r"\b%s = (\{[^{}]*\}|\d+)" % clave, tabla):
        for x in re.findall(r"\d+", m.group(1)):
            out.append(int(x))
    return out


def unicos(lista):
    vistos, out = set(), []
    for x in lista:
        if x not in vistos:
            vistos.add(x)
            out.append(x)
    return out


def lista_lua(nums):
    return "{ " + ", ".join(str(x) for x in nums) + " }" if nums else "{}"


def ficha(tabla):
    grupos = []
    for q in unicos(int(x) for x in re.findall(r'k = "group", q = (\d+)', tabla)):
        m = re.search(r"\bquest = %d, title = (\"(?:[^\"\\\\]|\\\\.)*\")" % q, tabla)
        grupos.append("{ quest = %d%s }" % (q, (", title = " + m.group(1)) if m else ""))
    partes = []
    if grupos:
        partes.append("groupQuests = { " + ", ".join(grupos) + " }")
    q = unicos(numeros_en(tabla, "quest"))
    p = unicos(numeros_en(tabla, "pre") + numeros_en(tabla, "preAll"))
    c = unicos(numeros_en(tabla, "closedBy"))
    partes.append("qref = { q = %s, p = %s, c = %s }" % (lista_lua(q), lista_lua(p), lista_lua(c)))
    return ", ".join(partes)


# Algunas guías arman tablas antes de registrarse (`local candidateRecords =
# { ... }` dentro de register()) y sus pasos las usan: ese preámbulo va
# también al principio de stepsSrc. Si la ficha no lo usa, sale de register()
# y en su lugar queda MARCA (revertir lo devuelve ahí).
MARCA = "-- alfa: preambulo en stepsSrc"
SEPARA = re.compile(r"(?=\n-- Source: )")


def convertir_guia(bloque):
    """Una guía (desde su `-- Source:`) -> (bloque nuevo, 1) o (bloque, 0)."""
    m = re.search(r"\n(\t+)steps = \{", bloque)
    if not m:
        return bloque, 0
    sangria = m.group(1)
    a = m.end() - 1
    e = fin_tabla(bloque, a)
    tabla = bloque[a:e + 1]
    n = contar_entradas(tabla)
    if n == 0:
        raise NoEncaja("guía sin pasos: %s" % bloque[:80].strip())
    preambulo, mover, inicio_pre = "", False, None
    r = re.search(r"local function register\(\)\n", bloque)
    g = bloque.find("Alfa.RegisterGuide({")
    if r and r.end() < g < a:
        inicio_pre = r.end()
        fin_pre = bloque.rfind("\n", 0, g) + 1
        preambulo = bloque[inicio_pre:fin_pre]
        if preambulo.strip():
            if re.search(r"\breturn\b", preambulo):
                raise NoEncaja("preámbulo con return: %s" % bloque[:80].strip())
            nombres = re.findall(r"^\s*local (\w+) =", preambulo, re.M)
            c0 = g + len("Alfa.RegisterGuide(")
            c1 = fin_tabla(bloque, c0)
            fuera = bloque[c0:m.start()] + bloque[e + 1:c1 + 1]
            mover = not any(re.search(r"\b%s\b" % x, fuera) for x in nombres)
        else:
            preambulo = ""
    src = preambulo + "return " + tabla
    nivel = "===="
    while ("]" + nivel + "]") in src:
        nivel += "="
    nuevo = (bloque[:m.start()]
             + "\n%sstepCount = %d, %s,\n%sstepsSrc = [%s[%s]%s]" % (sangria, n, ficha(tabla), sangria, nivel, src, nivel)
             + bloque[e + 1:])
    if mover:
        lineas_sangria = re.match(r"\t*", bloque[g - 8:g].split("\n")[-1]).group(0)
        nuevo = nuevo[:inicio_pre] + lineas_sangria + MARCA + "\n" + nuevo[inicio_pre + len(preambulo):]
    return nuevo, 1


def convertir(texto):
    """-> (texto nuevo, guías diferidas)."""
    out, total = [], 0
    for bloque in SEPARA.split(texto):
        nuevo, n = convertir_guia(bloque)
        out.append(nuevo)
        total += n
    return "".join(out), total


def revertir_guia(bloque):
    m = re.search(r"\n(\t+)stepCount = \d+, [^\n]*,\n\1stepsSrc = \[(=+)\[(.*?)\]\2\]", bloque, re.S)
    if not m:
        return bloque
    pre, _, tabla = m.group(3).partition("return ")
    nuevo = bloque[:m.start()] + "\n%ssteps = %s" % (m.group(1), tabla) + bloque[m.end():]
    if MARCA in nuevo:
        i = nuevo.index(MARCA)
        ini = nuevo.rfind("\n", 0, i) + 1
        nuevo = nuevo[:ini] + pre + nuevo[i + len(MARCA) + 1:]
    return nuevo


def revertir(texto):
    """Lo contrario de convertir (para la prueba: la guía como venía)."""
    return "".join(revertir_guia(b) for b in SEPARA.split(texto))


def diferir(dist: pathlib.Path) -> int:
    total = 0
    for nombre in PAQUETES:
        p = dist / nombre / "Guides.lua"
        if not p.exists():
            continue
        t = p.read_bytes().decode("latin-1")
        if "stepsSrc = [" in t:
            raise NoEncaja("%s ya estaba diferido" % p)
        nuevo, n = convertir(t)
        if n != t.count("Alfa.RegisterGuide({"):
            raise NoEncaja("%s: %d guías y %d pasos diferidos" % (p, t.count("Alfa.RegisterGuide({"), n))
        p.write_bytes(nuevo.encode("latin-1"))
        total += n
    return total


if __name__ == "__main__":
    # python -I tools/diferir.py [--revertir] [dist]
    raiz = pathlib.Path(__file__).resolve().parent.parent
    args = [a for a in sys.argv[1:] if a != "--revertir"]
    destino = pathlib.Path(args[0]) if args else raiz / "dist"
    if "--revertir" in sys.argv:
        for nombre in PAQUETES:
            p = destino / nombre / "Guides.lua"
            if p.exists():
                p.write_bytes(revertir(p.read_bytes().decode("latin-1")).encode("latin-1"))
        print("guías revertidas")
    else:
        print("guías diferidas:", diferir(destino))
