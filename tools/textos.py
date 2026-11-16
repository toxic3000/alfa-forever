"""Traducciones de los modulos de Alfa a los idiomas del juego.

Uso:
  .venv/Scripts/python -I tools/textos.py fuente     reune todos los textos en textos/fuente.json
  .venv/Scripts/python -I tools/textos.py estado     cuanto falta en cada idioma y que esta mal
  .venv/Scripts/python -I tools/textos.py generar    escribe src/Alfa_Nucleo/Idiomas/<loc>.lua

Los textos se escriben en espanol (la clave) y cada modulo trae su ingles
(M.EN en Textos.lua; los consejos de Mazmorras traen el par {es, en}).
Las traducciones van en textos/<loc>/*.json: objetos {"texto en espanol": "traduccion"}.
Solo se generan las que conservan los mismos huecos de formato (%s, %d...),
codigos de color (|c...|r), texturas (|T...|t) y saltos de linea del original.
"""
import json
import pathlib
import re
import sys

import lupa.lua51 as lua51

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SRC = RAIZ / "src"
TEXTOS = RAIZ / "textos"
IDIOMAS = ["deDE", "frFR", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]
NOMBRES = {"deDE": "Deutsch", "frFR": "Français", "ptBR": "Português (Brasil)", "ruRU": "Русский",
           "koKR": "한국어", "zhCN": "简体中文", "zhTW": "繁體中文"}
SALIDA = SRC / "Alfa_Nucleo" / "Idiomas"
HUECOS = re.compile(r"%[-+ #0]*\d*(?:\.\d+)?[sdifgxXq%]|\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t|\|n|\n")


def _lua():
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute("""
      local cmt = {}
      local function comodin() return setmetatable({}, cmt) end
      cmt.__index = function() return comodin() end
      cmt.__call = function() return comodin() end
      function cargar(src, M)
        local f, e = loadstring(src) if not f then error(e) end
        local env = setmetatable({}, {__index = function(_, k)
          local v = _G[k] if v ~= nil then return v end return comodin() end})
        setfenv(f, env)
        f("Alfa_X", M)
      end""")
    return lua


def pares() -> dict:
    """{espanol: {"en": ingles, "origen": modulo}} de todos los modulos."""
    lua = _lua()
    todo = {}
    for carpeta in sorted(SRC.glob("Alfa_*")):
        textos = carpeta / "Textos.lua"
        if textos.exists():
            M = lua.table()
            lua.globals().cargar(textos.read_bytes().decode("utf-8-sig"), M)
            if M.EN:
                for es, en in M.EN.items():
                    todo.setdefault(str(es), {"en": str(en), "origen": carpeta.name})
        for consejo in sorted((carpeta / "Consejos").glob("*.lua")) if (carpeta / "Consejos").is_dir() else []:
            M = lua.table()
            lua.globals().cargar(consejo.read_bytes().decode("utf-8-sig"), M)

            def recorrer(t):
                for _, v in t.items():
                    if lua.eval("type")(v) == "table":
                        a, b = v[1], v[2]
                        if isinstance(a, str) and isinstance(b, str):
                            todo.setdefault(a, {"en": b, "origen": carpeta.name + "/Consejos"})
                        else:
                            recorrer(v)
            if M.Consejos:
                recorrer(M.Consejos)
    return todo


def huecos(s: str) -> list:
    return sorted(HUECOS.findall(s))


def traducciones(loc: str) -> dict:
    out = {}
    carpeta = TEXTOS / loc
    for f in sorted(carpeta.glob("*.json")) if carpeta.is_dir() else []:
        out.update(json.loads(f.read_text(encoding="utf-8")))
    return out


def revisar(loc: str, fuente: dict):
    tr = traducciones(loc)
    buenas, malas = {}, []
    for es, tx in tr.items():
        if es not in fuente:
            continue  # texto que ya no existe
        if not isinstance(tx, str) or not tx.strip():
            malas.append((es, "vacia"))
        elif huecos(tx) != huecos(es):
            malas.append((es, f"huecos {huecos(tx)} != {huecos(es)}"))
        else:
            buenas[es] = tx
    faltan = [es for es in fuente if es not in buenas and es not in dict(malas)]
    return buenas, malas, faltan


def lua_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    orden = sys.argv[1] if len(sys.argv) > 1 else "estado"
    fuente = pares()
    if orden == "fuente":
        TEXTOS.mkdir(exist_ok=True)
        (TEXTOS / "fuente.json").write_text(
            json.dumps(fuente, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
        por = {}
        for v in fuente.values():
            por[v["origen"]] = por.get(v["origen"], 0) + 1
        print(f"{len(fuente)} textos en textos/fuente.json")
        for k in sorted(por):
            print(f"  {k}: {por[k]}")
        return 0
    if orden == "estado":
        for loc in IDIOMAS:
            buenas, malas, faltan = revisar(loc, fuente)
            print(f"{loc}: {len(buenas)}/{len(fuente)} listas, {len(malas)} con problemas, {len(faltan)} faltan")
            for es, motivo in malas[:5]:
                print(f"    - {motivo}: {es[:70]!r}")
        return 0
    if orden == "generar":
        SALIDA.mkdir(exist_ok=True)
        generados = []
        for loc in IDIOMAS:
            buenas, malas, _ = revisar(loc, fuente)
            if not buenas:
                continue
            lineas = [f"-- Alfa: textos de los modulos en {NOMBRES[loc]} ({loc}). GPL-3.0.",
                      "-- Generado por tools/textos.py desde textos/" + loc + "/*.json: no editar a mano.",
                      f'if not (GetLocale and GetLocale() == "{loc}") then return end',
                      "local N = AlfaNucleo",
                      f"N.idiomas.{loc} = {{"]
            lineas += [f"\t[{lua_str(es)}] = {lua_str(tx)}," for es, tx in sorted(buenas.items())]
            lineas.append("}")
            (SALIDA / f"{loc}.lua").write_text("\n".join(lineas) + "\n", encoding="utf-8")
            generados.append(loc)
            print(f"{loc}: {len(buenas)} textos ({len(malas)} descartados por huecos distintos)")
        toc = SRC / "Alfa_Nucleo" / "Alfa_Nucleo.toc"
        texto = toc.read_text(encoding="utf-8")
        texto = re.sub(r"(?m)^Idiomas\\.*\n?", "", texto).rstrip("\n") + "\n"
        texto += "".join(f"Idiomas\\{loc}.lua\n" for loc in generados)
        toc.write_text(texto, encoding="utf-8")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
