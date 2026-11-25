"""Globales por accidente (1.4.0).

Uso:  .venv/Scripts/python -I tools/globales.py      (revisa dist/ o ALFA_DIST)

Compila cada archivo Lua de Alfa con Lua 5.1 (como el juego) y lee su
bytecode (`string.dump`): cada SETGLOBAL es un global que el archivo escribe
y cada GETGLOBAL uno que lee. Falla con:
  - un global escrito que no es de Alfa (Alfa*, SLASH_*, BINDING_*) ni de la
    lista de abajo: casi siempre un `local` olvidado, que pisa a otros addons;
  - un global leído con minúscula que no es de Lua ni del juego: casi siempre
    una función `local` usada antes de declararla (en la 1.4.0, `luego` en
    Rastreador.lua y `gradient` en Widgets.lua: la X de una sugerencia y la
    barra lateral tronaban con «attempt to call a nil value»).
Los globales del juego con mayúscula no se pueden revisar aquí (el banco los
simula). Sale con código 1 si encuentra alguno.
"""
import os
import pathlib
import re
import struct
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DIST = pathlib.Path(os.environ.get("ALFA_DIST") or RAIZ / "dist")
SALTAR = re.compile(r"^Alfa_(Guides|Codex|ItemDB|QuestDB|Nav_|deDE|esES|esMX|frFR|koKR|ptBR|ruRU|zhCN|zhTW)")
ESCRIBE_BIEN = re.compile(r"^(Alfa|SLASH_|BINDING_)")
ESCRIBE_TAMBIEN = {
    "TomTom",           # Nav/Journey.lua: hace de TomTom si no está (para otros addons)
    "GetMinimapShape",  # Comodidades/Minimapa.lua: la forma del minimapa para otros addons
}
LEE_BIEN = set("""_G assert bit collectgarbage coroutine date debugprofilestop debugstack error format
geterrorhandler getmetatable hooksecurefunc ipairs issecretvalue canaccessvalue loadstring math next os pairs
pcall rawget rawset rawequal select seterrorhandler setfenv getfenv setmetatable string strlenutf8 strsplit
strtrim strjoin strconcat strsub strlower strupper strfind strmatch strrep strbyte strchar gsub table time tinsert
tremove tContains tonumber tostring type unpack wipe xpcall print newproxy securecallfunction
securecall secureexecuterange max min floor ceil abs sqrt random mod sort""".split())

_dump = None


def _compilador():
    global _dump
    if _dump is None:
        import lupa.lua51 as lua51
        lua = lua51.LuaRuntime(unpack_returned_tuples=True, encoding=None)
        _dump = lua.eval("function(src, name) local f = loadstring(src, name) if not f then return nil end "
                         "return string.dump(f) end")
    return _dump


class _Lector:
    def __init__(self, b):
        self.b, self.i = b, 12
        self.sz = b[8]  # sizeof(size_t)

    def u8(self):
        v = self.b[self.i]
        self.i += 1
        return v

    def i32(self):
        v = struct.unpack_from("<i", self.b, self.i)[0]
        self.i += 4
        return v

    def texto(self):
        n = struct.unpack_from("<Q" if self.sz == 8 else "<I", self.b, self.i)[0]
        self.i += self.sz
        if n == 0:
            return None
        v = self.b[self.i:self.i + n - 1]
        self.i += n
        return v.decode("latin-1")


def _funcion(r: _Lector, out: list) -> None:
    r.texto(); r.i32(); r.i32(); r.u8(); r.u8(); r.u8(); r.u8()
    n = r.i32()
    codigo = struct.unpack_from("<%dI" % n, r.b, r.i)
    r.i += 4 * n
    k = []
    for _ in range(r.i32()):
        t = r.u8()
        if t == 0:
            k.append(None)
        elif t == 1:
            k.append(bool(r.u8()))
        elif t == 3:
            k.append(struct.unpack_from("<d", r.b, r.i)[0])
            r.i += 8
        elif t == 4:
            k.append(r.texto())
    for _ in range(r.i32()):
        _funcion(r, out)
    nl = r.i32()
    lineas = struct.unpack_from("<%di" % nl, r.b, r.i)
    r.i += 4 * nl
    for _ in range(r.i32()):
        r.texto(); r.i32(); r.i32()
    for _ in range(r.i32()):
        r.texto()
    for pc, ins in enumerate(codigo):
        op = ins & 0x3F
        if op in (5, 7):  # GETGLOBAL, SETGLOBAL
            out.append(("lee" if op == 5 else "escribe", k[ins >> 14], lineas[pc] if pc < nl else 0))


def globales(archivo: pathlib.Path) -> list:
    src = archivo.read_bytes()
    if src.startswith(b"\xef\xbb\xbf"):
        src = src[3:]
    b = _compilador()(src, ("@" + archivo.name).encode())
    if b is None:
        return []  # (la sintaxis la revisa revisar.py)
    out: list = []
    _funcion(_Lector(bytes(b)), out)
    return out


def revisar() -> list:
    malos = []
    for carpeta in sorted(p for p in DIST.iterdir() if p.is_dir() and p.name.startswith("Alfa")):
        if SALTAR.match(carpeta.name):
            continue
        for archivo in sorted(carpeta.rglob("*.lua")):
            for tipo, nombre, linea in globales(archivo):
                if not isinstance(nombre, str):
                    continue
                donde = f"{archivo.relative_to(DIST)}:{linea}"
                if tipo == "escribe" and not ESCRIBE_BIEN.match(nombre) and nombre not in ESCRIBE_TAMBIEN:
                    malos.append(f"{donde}: escribe el global «{nombre}» (¿falta un local?)")
                elif tipo == "lee" and nombre[:1].islower() and nombre not in LEE_BIEN:
                    malos.append(f"{donde}: lee el global «{nombre}», que no existe (¿una función local usada antes de declararla?)")
    return malos + marcos_que_pisan()


# 1.4.0: un marco con nombre (CreateFrame(tipo, "AlfaX") o <Frame name="AlfaX">)
# se guarda en _G.AlfaX. Si otro archivo hace de AlfaX una tabla de funciones
# (la API de un módulo), el primer marco que se crea la borra: así «Acomodar la
# pantalla» se perdía del menú después de abrirlo una vez (el panel se llamaba
# "AlfaAcomodar", igual que la API AlfaAcomodar).
_MARCO_LUA = re.compile(r'CreateFrame\(\s*[^,()]+,\s*"(Alfa\w+)"\s*[,)]')
_MARCO_XML = re.compile(r'<\w+\s[^>]*\bname="(Alfa\w+)"')
_API = re.compile(r'(?m)^\s*(Alfa\w+)\s*=\s*(\{|type\(|setmetatable\(|rawget\(|_G\.\1\s+or\b|\1\s+or\b)')


def _linea(texto: str, i: int) -> int:
    return texto.count("\n", 0, i) + 1


def marcos_que_pisan() -> list:
    marcos: dict = {}
    apis: dict = {}
    for carpeta in sorted(p for p in DIST.iterdir() if p.is_dir() and p.name.startswith("Alfa")):
        if SALTAR.match(carpeta.name):
            continue
        for archivo in sorted(list(carpeta.rglob("*.lua")) + list(carpeta.rglob("*.xml"))):
            texto = archivo.read_text("utf-8", errors="replace")
            donde = archivo.relative_to(DIST)
            patron = _MARCO_LUA if archivo.suffix == ".lua" else _MARCO_XML
            for m in patron.finditer(texto):
                marcos.setdefault(m.group(1), f"{donde}:{_linea(texto, m.start())}")
            if archivo.suffix == ".lua":
                for m in _API.finditer(texto):
                    apis.setdefault(m.group(1), f"{donde}:{_linea(texto, m.start())}")
    return [f"{marcos[n]}: el marco «{n}» pisa la API global {n} ({apis[n]}); dale otro nombre al marco"
            for n in sorted(set(marcos) & set(apis))]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    if not (DIST / "Alfa").is_dir():
        print(f"Falta {DIST}: corre tools/build.py")
        return 1
    malos = revisar()
    for m in malos:
        print("GLOBAL", m)
    print(f"GLOBALES: {len(malos)} globales por accidente")
    return 1 if malos else 0


if __name__ == "__main__":
    sys.exit(main())
