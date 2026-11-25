"""Instalador de Alfa: un asistente guiado que instala o actualiza Alfa en
WoW Forever sin tocar carpetas a mano (toxic3000 / La Jauria, GPL-3.0).

1. Bienvenida: revisa en GitHub cuál es la versión más nueva de Alfa.
2. Carpeta del juego: encuentra WoW Forever solo (Battle.net, registro y
   discos); si no, deja elegir la carpeta.
3. Instalar: espera a que WoW esté cerrado, descarga el zip de la versión,
   revisa su firma SHA-256 y reemplaza las carpetas de Alfa (si algo falla,
   deja todo como estaba).
4. Listo: cómo empezar en el juego y el Discord de La Jauría.

No toca tus ajustes ni ningún otro addon. En WTF solo cambia la palabra
`enviado` de los reportes del buzón que ya mandó a Toxic (ver «Buzón»).

Para probar sin ventana:   python instalador.py --sin-ventana --carpeta X [--zip Y]
Solo el buzón:             python instalador.py --solo-buzon [--carpeta X]
Sin mandar reportes:       python instalador.py --sin-buzon
Para revisar el diseño:    python instalador.py --capturas CARPETA
"""
import ctypes
import hashlib
import json
import os
import pathlib
import queue
import re
import shutil
import string
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
import zipfile

VERSION = "1.1.0"
REPO = "toxic3000/alfa-forever"
API = f"https://api.github.com/repos/{REPO}/releases/latest"
DESCARGAS = f"https://github.com/{REPO}/releases"
DISCORD = "https://discord.gg/hUNjA6BJwh"
AGENTE = f"AlfaInstalador/{VERSION}"
JUEGOS = ("wow.exe", "wowt.exe", "wowb.exe", "wowclassic.exe")
SIN_CONSOLA = 0x08000000


class ErrorAmable(Exception):
    """Un error con un mensaje en español para quien instala."""


class ErrorPermiso(ErrorAmable):
    """Windows no deja escribir en la carpeta del juego."""


def recurso(nombre: str) -> pathlib.Path:
    base = getattr(sys, "_MEIPASS", None) or pathlib.Path(__file__).resolve().parent
    p = pathlib.Path(base) / nombre
    if not p.exists():  # sin empaquetar: el logo vive en curseforge/
        p = pathlib.Path(__file__).resolve().parent.parent / "curseforge" / nombre
    return p


# ---------------------------------------------------------------------------
# Encontrar WoW Forever
# ---------------------------------------------------------------------------
def forever_de(ruta) -> "pathlib.Path | None":
    """La carpeta _forever_ a partir de cualquier ruta dentro o encima de ella."""
    if not ruta:
        return None
    try:
        p = pathlib.Path(str(ruta).strip().strip('"')).resolve()
    except (OSError, ValueError):
        return None
    for q in [p, *p.parents]:
        if q.name.lower() == "_forever_" and q.is_dir():
            return q
    q = p / "_forever_"
    return q if q.is_dir() else None


def _discos_fijos() -> list:
    letras = []
    try:
        mascara = ctypes.windll.kernel32.GetLogicalDrives()
        for i, letra in enumerate(string.ascii_uppercase):
            if mascara & (1 << i) and ctypes.windll.kernel32.GetDriveTypeW(f"{letra}:\\") == 3:
                letras.append(letra)
    except (AttributeError, OSError):
        letras = [l for l in "CDEFG" if os.path.exists(f"{l}:\\")]
    return letras


def buscar_forever() -> list:
    """Todas las instalaciones de WoW Forever que se encuentran, sin repetir."""
    vistas = []

    def agregar(ruta):
        f = forever_de(ruta)
        if f and f not in vistas:
            vistas.append(f)

    # 1. Battle.net guarda la ruta de cada juego en product.db
    db = pathlib.Path(os.environ.get("ProgramData", r"C:\ProgramData")) / "Battle.net" / "Agent" / "product.db"
    try:
        datos = db.read_bytes()
        for m in re.finditer(rb'[A-Za-z]:[\\/](?:[^\x00-\x1f"<>|*?]{0,160}?[\\/])?World of Warcraft', datos):
            agregar(m.group().decode("utf-8", "ignore"))
    except OSError:
        pass
    # 2. El registro de programas instalados
    try:
        import winreg
        for raiz in (winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER):
            for base in (r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                         r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"):
                try:
                    k = winreg.OpenKey(raiz, base)
                except OSError:
                    continue
                i = 0
                while True:
                    try:
                        sub = winreg.EnumKey(k, i)
                    except OSError:
                        break
                    i += 1
                    try:
                        sk = winreg.OpenKey(k, sub)
                        if "warcraft" in str(winreg.QueryValueEx(sk, "DisplayName")[0]).lower():
                            agregar(winreg.QueryValueEx(sk, "InstallLocation")[0])
                    except OSError:
                        pass
    except ImportError:
        pass
    # 3. Los lugares de siempre en cada disco
    for letra in _discos_fijos():
        for sub in (r"Program Files (x86)\World of Warcraft", r"Program Files\World of Warcraft",
                    r"World of Warcraft", r"Games\World of Warcraft", r"Juegos\World of Warcraft",
                    r"Blizzard\World of Warcraft", r"Battle.net\World of Warcraft"):
            agregar(f"{letra}:\\{sub}")
    return vistas


def carpeta_addons(forever: pathlib.Path) -> pathlib.Path:
    return forever / "Interface" / "AddOns"


def _leer_toc(carpeta: pathlib.Path) -> str:
    for toc in sorted(carpeta.glob("*.toc")):
        try:
            return toc.read_text(encoding="utf-8", errors="replace")
        except OSError:
            pass
    return ""


def version_instalada(forever: pathlib.Path) -> "str | None":
    m = re.search(r"^##\s*Version:\s*(\S+)", _leer_toc(carpeta_addons(forever) / "Alfa"), re.M)
    return m.group(1) if m else None


def es_de_alfa(carpeta: pathlib.Path) -> bool:
    """Una carpeta de Alfa (de cualquier versión), no otro addon con nombre parecido."""
    if not (carpeta.name == "Alfa" or carpeta.name.startswith("Alfa_")):
        return False
    m = re.search(r"^##\s*Author:\s*(.+)$", _leer_toc(carpeta), re.M)
    autor = (m.group(1) if m else "").lower()
    return "toxic" in autor or "jaur" in autor


def numeros(v: "str | None") -> tuple:
    return tuple(int(x) for x in re.findall(r"\d+", v or "")) or (0,)


def wow_abierto() -> bool:
    try:
        r = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True,
                           creationflags=SIN_CONSOLA, timeout=15)
        salida = r.stdout.decode("mbcs", "ignore").lower()
    except (OSError, subprocess.SubprocessError):
        return False
    return any(f'"{j}"' in salida for j in JUEGOS)


# ---------------------------------------------------------------------------
# Descargar
# ---------------------------------------------------------------------------
def _abrir(url: str, timeout=30):
    req = urllib.request.Request(url, headers={"User-Agent": AGENTE, "Accept": "application/vnd.github+json"})
    return urllib.request.urlopen(req, timeout=timeout)


def ultima_version(intentos=3) -> dict:
    ultimo = None
    for i in range(intentos):
        try:
            with _abrir(API) as r:
                datos = json.load(r)
            break
        except (urllib.error.URLError, OSError, ValueError) as e:
            ultimo = e
            time.sleep(1.5 * (i + 1))
    else:
        raise ErrorAmable("No pude conectarme a GitHub para ver la versión más nueva de Alfa. "
                          "Revisa tu conexión a internet.") from ultimo
    zips = [a for a in datos.get("assets", []) if re.fullmatch(r"Alfa-[\w.\-]+\.zip", a.get("name", ""))]
    if not zips:
        raise ErrorAmable("La versión publicada todavía no tiene su archivo de instalación. Intenta en un rato.")
    a = zips[0]
    digest = a.get("digest") or ""
    return {"version": str(datos.get("tag_name", "")).lstrip("vV"), "url": a["browser_download_url"],
            "tam": int(a.get("size") or 0), "sha256": digest.split(":", 1)[1] if digest.startswith("sha256:") else None,
            "nombre": a["name"]}


def descargar(info: dict, informar, intentos=3) -> pathlib.Path:
    destino = pathlib.Path(tempfile.gettempdir()) / "AlfaInstalador" / info["nombre"]
    destino.parent.mkdir(parents=True, exist_ok=True)
    ultimo = None
    for i in range(intentos):
        try:
            h = hashlib.sha256()
            hecho = 0
            with _abrir(info["url"], timeout=60) as r, open(destino, "wb") as f:
                total = int(r.headers.get("Content-Length") or info["tam"] or 0)
                while True:
                    trozo = r.read(256 * 1024)
                    if not trozo:
                        break
                    f.write(trozo)
                    h.update(trozo)
                    hecho += len(trozo)
                    informar("descarga", hecho, total)
            if info["tam"] and hecho != info["tam"]:
                raise OSError("descarga incompleta")
            if info["sha256"] and h.hexdigest() != info["sha256"]:
                raise ErrorAmable("La descarga llegó dañada (su firma no coincide). Vuelve a intentarlo.")
            return destino
        except ErrorAmable:
            raise
        except (urllib.error.URLError, OSError) as e:
            ultimo = e
            informar("reintento", i + 1, intentos)
            time.sleep(2 * (i + 1))
    raise ErrorAmable("La descarga se cortó varias veces. Revisa tu conexión a internet y vuelve a intentarlo.") from ultimo


# ---------------------------------------------------------------------------
# Instalar
# ---------------------------------------------------------------------------
def _carpetas_del_zip(z: zipfile.ZipFile) -> list:
    tops = set()
    for n in z.namelist():
        limpio = n.replace("\\", "/")
        partes = [p for p in limpio.split("/") if p]
        if not partes:
            continue
        if limpio.startswith("/") or ".." in partes or ":" in partes[0]:
            raise ErrorAmable("El paquete descargado no es válido. Vuelve a intentarlo más tarde.")
        if len(partes) > 1 or limpio.endswith("/"):
            tops.add(partes[0])
    carpetas = sorted(t for t in tops if t == "Alfa" or t.startswith("Alfa_"))
    if "Alfa" not in carpetas:
        raise ErrorAmable("El paquete descargado no trae Alfa. Vuelve a intentarlo más tarde.")
    return carpetas


def instalar(zip_path: pathlib.Path, forever: pathlib.Path, informar) -> int:
    """Reemplaza las carpetas de Alfa. Si algo falla, deja todo como estaba."""
    addons = carpeta_addons(forever)
    trabajo = forever / "Interface" / ".alfa-instalando"
    try:
        addons.mkdir(parents=True, exist_ok=True)
        if trabajo.exists():
            shutil.rmtree(trabajo, ignore_errors=True)
        nuevo, anterior = trabajo / "nuevo", trabajo / "anterior"
        nuevo.mkdir(parents=True)
        anterior.mkdir()
    except PermissionError as e:
        raise ErrorPermiso("Windows no me deja escribir en la carpeta del juego.") from e

    with zipfile.ZipFile(zip_path) as z:
        carpetas = _carpetas_del_zip(z)
        miembros = [n for n in z.namelist() if n.replace("\\", "/").split("/")[0] in carpetas]
        for i, n in enumerate(miembros):
            try:
                z.extract(n, nuevo)
            except PermissionError as e:
                shutil.rmtree(trabajo, ignore_errors=True)
                raise ErrorPermiso("Windows no me deja escribir en la carpeta del juego.") from e
            if i % 150 == 0:
                informar("copia", i, len(miembros))

    # Lo de antes: las carpetas que se reemplazan y las de Alfa que ya no existen
    viejas = [d for d in addons.iterdir() if d.is_dir() and (d.name in carpetas or es_de_alfa(d))]
    movidas, puestas = [], []
    try:
        for d in viejas:
            os.replace(d, anterior / d.name)
            movidas.append(d.name)
        for c in carpetas:
            os.replace(nuevo / c, addons / c)
            puestas.append(c)
    except OSError as e:
        for c in puestas:
            shutil.rmtree(addons / c, ignore_errors=True)
        for c in movidas:
            try:
                os.replace(anterior / c, addons / c)
            except OSError:
                pass
        if isinstance(e, PermissionError):
            raise ErrorPermiso("Windows no me deja reemplazar las carpetas de Alfa.") from e
        raise ErrorAmable("No pude copiar Alfa a la carpeta del juego. Si WoW o el Explorador tienen "
                          "abierta una carpeta de Alfa, ciérralos y vuelve a intentarlo.") from e
    informar("copia", len(miembros), len(miembros))
    shutil.rmtree(trabajo, ignore_errors=True)
    return len(carpetas)


def pedir_administrador(forever: "pathlib.Path | None") -> bool:
    """Vuelve a abrir el instalador con permiso de administrador y empieza solo."""
    if getattr(sys, "frozen", False):
        programa, args = sys.executable, []
    else:
        programa, args = sys.executable, [str(pathlib.Path(__file__).resolve())]
    args += ["--seguir"] + (["--carpeta", str(forever)] if forever else [])
    params = subprocess.list2cmdline(args)
    try:
        return ctypes.windll.shell32.ShellExecuteW(None, "runas", programa, params, None, 1) > 32
    except (AttributeError, OSError):
        return False


def _mb(n: int) -> str:
    return f"{n / 1048576:.0f} MB" if n >= 1048576 else f"{max(1, n // 1024)} KB"


# ---------------------------------------------------------------------------
# Buzón: los reportes de errores que se escriben en el juego van a #buzon-alfa
# ---------------------------------------------------------------------------
# El juego no deja que un addon mande nada a internet: Alfa guarda cada reporte
# en AlfaNucleoDB.buzon.pendientes (WTF/Account/<cuenta>/SavedVariables/
# Alfa_Nucleo.lua). Con el juego cerrado, el instalador los manda al formulario
# de Google de Toxic (las respuestas le llegan a su correo) y, si el .exe trae
# webhook (buzon_local.json), también a #buzon-alfa en Discord. Luego los marca
# enviado = true cambiando solo esa palabra del archivo.
#
# El formulario (camino principal): una URL pública, no es secreto.
BUZON_FORMULARIO = {
    "url": "https://docs.google.com/forms/d/e/1FAIpQLSfCKW97uxmZL5ZGl5Ym4hLjUMTWt6O0N7TJgw6buSDMoRIXUA/formResponse",
    "tipo": "entry.832145550",       # Error | Mejora | Comentario (exactamente así)
    "texto": "entry.1889667288",     # lo que escribió el jugador
    "version": "entry.1259972415",   # la versión de Alfa
}
BUZON_TIPOS = {"error": "Error", "mejora": "Mejora", "comentario": "Comentario"}
BUZON_ARCHIVO = "Alfa_Nucleo.lua"   # SavedVariables: AlfaNucleoDB (src/Alfa_Nucleo/Alfa_Nucleo.toc)
BUZON_GLOBAL = "AlfaNucleoDB"
BUZON_MAX = 5                       # reportes por apertura del instalador
BUZON_LETRAS = 1950                 # largo máximo de cada texto
BUZON_ESPERA = 1.2                  # segundos entre envíos (Discord: 5 cada 2 s por webhook)
BUZON_CLAVE = b"La Jauria - buzon de Alfa"
BUZON_WEBHOOK = re.compile(r"https://(?:(?:ptb|canary)\.)?discord(?:app)?\.com/api/webhooks/\d+/[\w-]+")


def _buzon_ofuscar(texto: str) -> str:
    """No es protección de verdad: solo evita que la URL se lea a simple vista dentro del .exe."""
    import base64
    b = texto.encode("utf-8")
    return base64.b64encode(bytes(c ^ BUZON_CLAVE[i % len(BUZON_CLAVE)] for i, c in enumerate(b))).decode("ascii")


def _buzon_desofuscar(dato: str) -> str:
    import base64
    b = base64.b64decode(dato.strip())
    return bytes(c ^ BUZON_CLAVE[i % len(BUZON_CLAVE)] for i, c in enumerate(b)).decode("utf-8")


def webhook_buzon() -> "str | None":
    """La URL del webhook: dentro del .exe (buzon.dat) o, sin empaquetar, de instalador/buzon_local.json.
    Si no hay o no es de Discord, el buzón no hace nada."""
    url = None
    try:
        base = getattr(sys, "_MEIPASS", None)
        if base:
            p = pathlib.Path(base) / "buzon.dat"
            if p.is_file():
                url = _buzon_desofuscar(p.read_text(encoding="ascii"))
        else:
            p = pathlib.Path(__file__).resolve().parent / "buzon_local.json"
            if p.is_file():
                url = json.loads(p.read_text(encoding="utf-8")).get("webhook")
    except (OSError, ValueError, UnicodeError, AttributeError):
        return None
    url = str(url or "").strip()
    return url if BUZON_WEBHOOK.fullmatch(url) else None


class _LuaMal(ValueError):
    """El archivo guardado no se entiende: no se toca."""


class _Num(str):
    """Un número de Lua tal como está escrito (se compara por su texto, nunca se reescribe)."""


class _TablaLua:
    __slots__ = ("campos", "lugar")

    def __init__(self):
        self.campos = {}   # clave -> valor
        self.lugar = {}    # clave -> (inicio, fin) del valor en el texto


_LUA_NUM = re.compile(r"-?(?:inf|nan|[0-9.](?:[eE][+-]|[0-9A-Za-z_.#])*)(?:\(\w*\))?")
_LUA_NOMBRE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_LUA_LARGA = re.compile(r"\[(=*)\[")
_LUA_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v",
                "\\": "\\", '"': '"', "'": "'", "\n": "\n", "\r": "\n"}


class _LectorLua:
    """Lee lo que escribe el juego en SavedVariables: `Nombre = valor` con tablas, textos,
    números, true/false/nil y comentarios. Cualquier otra cosa → _LuaMal."""

    def __init__(self, texto: str):
        self.t, self.i = texto, 0

    def _blanco(self):
        t = self.t
        while self.i < len(t):
            c = t[self.i]
            if c in " \t\r\n\f\v;":
                self.i += 1
            elif t.startswith("--", self.i):
                m = _LUA_LARGA.match(t, self.i + 2)
                if m:
                    fin = t.find("]" + m.group(1) + "]", m.end())
                    if fin < 0:
                        raise _LuaMal("comentario sin cerrar")
                    self.i = fin + len(m.group(1)) + 2
                else:
                    nl = t.find("\n", self.i)
                    self.i = len(t) if nl < 0 else nl + 1
            else:
                return

    def _larga(self):
        m = _LUA_LARGA.match(self.t, self.i)
        cierre = "]" + m.group(1) + "]"
        fin = self.t.find(cierre, m.end())
        if fin < 0:
            raise _LuaMal("texto largo sin cerrar")
        s = self.t[m.end():fin]
        self.i = fin + len(cierre)
        return s[1:] if s.startswith("\n") else s

    def _cadena(self):
        t, q = self.t, self.t[self.i]
        i, partes = self.i + 1, bytearray()
        while True:
            if i >= len(t):
                raise _LuaMal("texto sin cerrar")
            c = t[i]
            if c == q:
                self.i = i + 1
                return partes.decode("utf-8", "replace")
            if c == "\n":
                raise _LuaMal("salto de línea dentro de un texto")
            if c != "\\":
                partes += c.encode("utf-8", "surrogateescape")
                i += 1
                continue
            i += 1
            e = t[i] if i < len(t) else ""
            if e in _LUA_ESCAPES:
                partes += _LUA_ESCAPES[e].encode("ascii")
                i += 2 if t.startswith("\r\n", i) or t.startswith("\n\r", i) else 1
            elif e.isdigit():
                m = re.match(r"\d{1,3}", t[i:])
                n = int(m.group())
                if n > 255:
                    raise _LuaMal("escape fuera de rango")
                partes.append(n)
                i += len(m.group())
            elif e == "x" and re.fullmatch(r"[0-9a-fA-F]{2}", t[i + 1:i + 3]):
                partes.append(int(t[i + 1:i + 3], 16))
                i += 3
            elif e == "z":
                i += 1
                while i < len(t) and t[i] in " \t\r\n\f\v":
                    i += 1
            elif e == "u" and (m := re.match(r"u\{([0-9a-fA-F]{1,6})\}", t[i:])):
                partes += chr(min(int(m.group(1), 16), 0x10FFFF)).encode("utf-8", "surrogatepass")
                i += len(m.group())
            else:
                raise _LuaMal("escape desconocido")

    def _valor(self):
        self._blanco()
        t, i = self.t, self.i
        if i >= len(t):
            raise _LuaMal("se acabó el archivo")
        c = t[i]
        if c == "{":
            return self._tabla()
        if c in "\"'":
            return self._cadena()
        if _LUA_LARGA.match(t, i):
            return self._larga()
        for palabra, v in (("true", True), ("false", False), ("nil", None)):
            if t.startswith(palabra, i) and not _LUA_NOMBRE.match(t, i + len(palabra)) and \
                    not (i + len(palabra) < len(t) and t[i + len(palabra)].isdigit()):
                self.i += len(palabra)
                return v
        m = _LUA_NUM.match(t, i)
        if m and m.group() not in ("-", "."):
            self.i = m.end()
            return _Num(m.group())
        raise _LuaMal(f"no entiendo lo que hay en la posición {i}")

    def _tabla(self):
        tabla, n = _TablaLua(), 0
        self.i += 1
        while True:
            self._blanco()
            t = self.t
            if self.i >= len(t):
                raise _LuaMal("tabla sin cerrar")
            if t[self.i] == "}":
                self.i += 1
                return tabla
            if t[self.i] == "[" and not _LUA_LARGA.match(t, self.i):
                self.i += 1
                clave = self._valor()
                self._blanco()
                if not t.startswith("]", self.i):
                    raise _LuaMal("falta ]")
                self.i += 1
                self._blanco()
                if not t.startswith("=", self.i):
                    raise _LuaMal("falta =")
                self.i += 1
                if isinstance(clave, _Num):
                    try:
                        clave = int(clave)
                    except ValueError:
                        pass
                if isinstance(clave, _TablaLua) or clave is None:
                    raise _LuaMal("clave rara")
            else:
                m = _LUA_NOMBRE.match(t, self.i)
                fin = m and m.end()
                if m and m.group() not in ("true", "false", "nil"):
                    j = fin
                    while j < len(t) and t[j] in " \t\r\n":
                        j += 1
                    if t.startswith("=", j) and not t.startswith("==", j):
                        clave = m.group()
                        self.i = j + 1
                    else:
                        raise _LuaMal("nombre suelto en una tabla")
                else:
                    n += 1
                    clave = n
            self._blanco()
            inicio = self.i
            v = self._valor()
            tabla.campos[clave] = v
            tabla.lugar[clave] = (inicio, self.i)
            self._blanco()
            if self.i < len(t) and t[self.i] == ",":
                self.i += 1

    def todo(self) -> dict:
        globales = {}
        while True:
            self._blanco()
            if self.i >= len(self.t):
                return globales
            m = _LUA_NOMBRE.match(self.t, self.i)
            if not m:
                raise _LuaMal("se esperaba un nombre")
            self.i = m.end()
            self._blanco()
            if not self.t.startswith("=", self.i):
                raise _LuaMal("falta =")
            self.i += 1
            globales[m.group()] = self._valor()


def _plano(v):
    if isinstance(v, dict):
        return {k: _plano(x) for k, x in v.items()}
    if isinstance(v, _TablaLua):
        return {k: _plano(x) for k, x in v.campos.items()}
    return v


def leer_lua(texto: str) -> dict:
    return _LectorLua(texto).todo()


def _buzon_pendientes(globales: dict) -> list:
    """[(índice, tabla del reporte)] de los reportes con enviado = false."""
    db = globales.get(BUZON_GLOBAL)
    buzon = db.campos.get("buzon") if isinstance(db, _TablaLua) else None
    lista = buzon.campos.get("pendientes") if isinstance(buzon, _TablaLua) else None
    if not isinstance(lista, _TablaLua):
        return []
    salida = []
    for k in sorted((k for k in lista.campos if isinstance(k, int))):
        r = lista.campos[k]
        if isinstance(r, _TablaLua) and r.campos.get("enviado") is False and isinstance(r.campos.get("texto"), str):
            salida.append((k, r))
    return salida


def _buzon_clave(r: _TablaLua) -> str:
    partes = [str(r.campos.get(c, "")) for c in ("id", "fecha", "tipo", "texto")]
    return hashlib.sha256("\0".join(partes).encode("utf-8", "replace")).hexdigest()[:24]


def _buzon_texto(v, largo=100) -> str:
    s = "" if v is None or isinstance(v, (bool, _TablaLua)) else str(v)
    s = s.encode("utf-8", "replace").decode("utf-8", "replace").strip()
    return s[:largo]


def _buzon_fecha(v) -> str:
    if isinstance(v, _Num):
        try:
            return time.strftime("%Y-%m-%d %H:%M", time.localtime(int(float(v))))
        except (ValueError, OverflowError, OSError):
            pass
    return _buzon_texto(v) or "—"


def _buzon_mensaje(r: _TablaLua) -> dict:
    """El mensaje para Discord: un embed sencillo, sin menciones (nadie puede hacer @everyone)."""
    tipo = _buzon_texto(r.campos.get("tipo"), 60) or "reporte"
    version = _buzon_texto(r.campos.get("version"), 40) or "?"
    texto = _buzon_texto(r.campos.get("texto"), BUZON_LETRAS) or "(sin texto)"
    ident = _buzon_texto(r.campos.get("id"), 80)
    embed = {"title": f"{tipo[:1].upper()}{tipo[1:]} · Alfa {version}"[:256],
             "description": texto,
             "color": 0x8BE04E,
             "fields": [{"name": "Tipo", "value": tipo, "inline": True},
                        {"name": "Versión", "value": version, "inline": True},
                        {"name": "Fecha", "value": _buzon_fecha(r.campos.get("fecha")), "inline": True}],
             "footer": {"text": f"Instalador {VERSION}" + (f" · id {ident}" if ident else "")}}
    return {"username": "Buzón de Alfa", "allowed_mentions": {"parse": []}, "embeds": [embed]}


# El reporte que arma el addon (Alfa_Bienvenida/Reporte.lua, componer):
#   **[Alfa] <Tipo>**\n<lo que escribió el jugador>\n```\n<datos técnicos>\n```
_REPORTE = re.compile(r"\*\*\[Alfa\][^\n]*\*\*\n(.*)\n```\n(.*?)(?:\n?```)?\s*", re.S)
_SIN_TEXTO = ("(sin comentario)", "(todavía sin texto: escríbelo arriba)")


def separar_reporte(texto: str) -> tuple:
    """(lo que escribió el jugador, datos técnicos). Si no tiene la forma de siempre, todo va a datos."""
    m = _REPORTE.fullmatch(texto.strip())
    if not m:
        return "(sin texto)", texto.strip() or "(sin datos)"
    suyo, datos = m.group(1).strip(), m.group(2).strip()
    if not suyo or suyo in _SIN_TEXTO:
        suyo = "(sin texto)"
    return suyo, datos or "(sin datos)"


# 1.4.0 (24/11/2026): el formulario ya no tiene la pregunta «Datos técnicos»: lo
# técnico va al final del texto, tras esta línea, con el código del reporte primero.
BUZON_SEPARADOR = "— Datos de Alfa —"
# Líneas que nunca salen de la PC aunque el juego las hubiera dejado (Alfa ya
# quita tu nombre y tu reino con N.SinPrivado; esto es la segunda red).
_PRIVADO = re.compile(r"^\s*(personaje|nombre|reino|realm|character|name|jugador|player)\s*[:=]", re.I)


def _sin_privado(texto: str) -> str:
    return "\n".join(l for l in texto.splitlines() if not _PRIVADO.match(l))


def texto_formulario(suyo: str, datos: str, codigo: str, pie: str, letras=BUZON_LETRAS) -> str:
    """Lo que escribió el jugador y, tras «— Datos de Alfa —», «Código: <id>», los datos y el pie.
    Cabe en `letras`: primero se recortan los datos y, si no basta, lo suyo."""
    cabeza = f"{BUZON_SEPARADOR}\nCódigo: {codigo}"
    datos = _sin_privado(datos).strip() or "(sin datos)"
    fijo = len(cabeza) + len(pie) + 6
    minimo = min(len(datos), 200)
    if len(suyo) + fijo + minimo > letras:
        suyo = suyo[:max(40, letras - fijo - minimo - 1)].rstrip() + "…"
    resto = letras - len(suyo) - fijo
    if len(datos) > resto:
        datos = datos[:max(0, resto - 1)].rstrip() + "…"
    return f"{suyo}\n\n{cabeza}\n{datos}\n\n{pie}"[:letras]


def _buzon_formulario(r: _TablaLua) -> dict:
    """Los campos del formulario de Google para un reporte (tipo, texto y versión)."""
    f = BUZON_FORMULARIO
    tipo = BUZON_TIPOS.get(_buzon_texto(r.campos.get("tipo"), 60).lower(), "Comentario")
    suyo, datos = separar_reporte(_buzon_texto(r.campos.get("texto"), BUZON_LETRAS))
    codigo = _buzon_texto(r.campos.get("id"), 80) or "?"
    pie = f"fecha {_buzon_fecha(r.campos.get('fecha'))} · instalador {VERSION}"
    return {f["tipo"]: tipo, f["texto"]: texto_formulario(suyo, datos, codigo, pie),
            f["version"]: _buzon_texto(r.campos.get("version"), 40) or "?"}


def _buzon_post(url: str, carga: dict, abrir, esperar, formulario=False) -> bool:
    """True si llegó (200). Con el límite de velocidad (429) espera lo que pide y reintenta."""
    if formulario:
        datos = urllib.parse.urlencode(carga).encode("ascii")
        tipo = "application/x-www-form-urlencoded"
    else:  # Discord: pide confirmación del mensaje
        url = url + ("&" if "?" in url else "?") + "wait=true"
        datos = json.dumps(carga, ensure_ascii=False).encode("utf-8")
        tipo = "application/json"
    for _ in range(3):
        req = urllib.request.Request(url, data=datos, method="POST",
                                     headers={"Content-Type": tipo, "User-Agent": AGENTE})
        try:
            with abrir(req, timeout=15) as r:
                return 200 <= getattr(r, "status", 200) < 300
        except urllib.error.HTTPError as e:
            if e.code != 429:
                return False   # borrado (404), datos raros (400) o el servicio caído (5xx)
            espera = 2.0
            try:
                espera = float(json.loads(e.read().decode("utf-8", "replace")).get("retry_after", espera))
            except (ValueError, AttributeError, OSError):
                try:
                    espera = float(e.headers.get("Retry-After") or espera)
                except (TypeError, ValueError):
                    pass
            esperar(min(max(espera, 0.5), 30.0))
        except (urllib.error.URLError, OSError, ValueError):
            return False       # sin internet: se intenta la próxima vez
    return False


def _buzon_registro(ruta: "pathlib.Path | None") -> pathlib.Path:
    if ruta:
        return pathlib.Path(ruta)
    base = os.environ.get("LOCALAPPDATA") or tempfile.gettempdir()
    return pathlib.Path(base) / "AlfaInstalador" / "buzon_enviados.json"


def _registro_leer(ruta: pathlib.Path) -> list:
    try:
        datos = json.loads(ruta.read_text(encoding="utf-8"))
        return [str(x) for x in datos.get("enviados", [])] if isinstance(datos, dict) else []
    except (OSError, ValueError):
        return []


def _registro_guardar(ruta: pathlib.Path, claves: list):
    try:
        ruta.parent.mkdir(parents=True, exist_ok=True)
        tmp = ruta.with_name(ruta.name + ".tmp")
        tmp.write_text(json.dumps({"enviados": claves[-500:]}), encoding="utf-8")
        os.replace(tmp, ruta)
    except OSError:
        pass


def _buzon_marcar(archivo: pathlib.Path, crudo: bytes, indices: list) -> bool:
    """Cambia `false` por `true` en el campo enviado de esos reportes y nada más.
    Copia de respaldo antes; si algo no cuadra, el archivo se queda como estaba."""
    try:
        if archivo.read_bytes() != crudo:
            return False   # alguien lo cambió mientras mandábamos (¿se abrió el juego?)
        texto = crudo.decode("utf-8", "surrogateescape")
        globales = leer_lua(texto)
        lista = globales[BUZON_GLOBAL].campos["buzon"].campos["pendientes"]
        esperado = _plano(globales)
        cambios = []
        for k in indices:
            r = lista.campos[k]
            a, b = r.lugar["enviado"]
            if texto[a:b] != "false":
                return False
            cambios.append((a, b))
            esperado[BUZON_GLOBAL]["buzon"]["pendientes"][k]["enviado"] = True
        nuevo = texto
        for a, b in sorted(cambios, reverse=True):
            nuevo = nuevo[:a] + "true" + nuevo[b:]
        if _plano(leer_lua(nuevo)) != esperado:
            return False
        datos = nuevo.encode("utf-8", "surrogateescape")
        if len(datos) != len(crudo) - len(cambios):
            return False
        respaldo = archivo.with_name(archivo.name + ".antes-del-buzon")
        if respaldo.exists():
            os.chmod(respaldo, 0o666)
            respaldo.unlink()
        respaldo.write_bytes(crudo)
        if respaldo.read_bytes() != crudo:
            return False
        tmp = archivo.with_name(archivo.name + ".alfa-buzon.tmp")
        tmp.write_bytes(datos)
        try:
            os.replace(tmp, archivo)
        except OSError:
            try:
                tmp.unlink()
            except OSError:
                pass
            return False
        return archivo.read_bytes() == datos
    except (OSError, KeyError, AttributeError, TypeError, _LuaMal, UnicodeError, RecursionError):
        return False


def archivos_buzon(forevers) -> list:
    """El Alfa_Nucleo.lua de cada cuenta de WTF, sin repetir."""
    vistos = []
    for f in forevers:
        if not f:
            continue
        cuentas = pathlib.Path(f) / "WTF" / "Account"
        try:
            for c in sorted(cuentas.iterdir()):
                p = c / "SavedVariables" / BUZON_ARCHIVO
                if p.is_file() and p.resolve() not in vistos:
                    vistos.append(p.resolve())
        except OSError:
            pass
    return vistos


def enviar_buzon(forevers, webhook=None, registro=None, maximo=BUZON_MAX, espera=BUZON_ESPERA,
                 abrir=urllib.request.urlopen, esperar=time.sleep, formulario=None) -> dict:
    """Manda los reportes con enviado = false de todas las cuentas al formulario de Toxic
    (y, si hay webhook, también a #buzon-alfa) y los marca. Cuenta como enviado lo que recibió
    el formulario; Discord es un extra y su falla no detiene nada.
    Llamar solo con el juego cerrado (el juego reescribe el archivo al salir). Nunca lanza errores."""
    res = {"enviados": 0, "marcados": 0, "sin_marcar": 0, "dañados": 0, "pendientes": 0, "discord": 0}
    formulario = formulario or BUZON_FORMULARIO["url"]
    ruta_reg = _buzon_registro(registro)
    hechos = _registro_leer(ruta_reg)
    cupo, primero, parar = maximo, True, False
    for archivo in archivos_buzon(forevers):
        if parar:
            break
        try:
            crudo = archivo.read_bytes()
            if b"buzon" not in crudo:
                continue
            pendientes = _buzon_pendientes(leer_lua(crudo.decode("utf-8", "surrogateescape")))
        except (OSError, _LuaMal, UnicodeError, RecursionError):
            res["dañados"] += 1
            continue
        marcar = []
        for k, r in pendientes:
            clave = _buzon_clave(r)
            if clave in hechos:      # ya se mandó otra vez, pero no se pudo marcar
                marcar.append(k)
                continue
            if cupo <= 0 or parar:
                res["pendientes"] += 1
                continue
            if not primero:
                esperar(espera)
            primero = False
            if not _buzon_post(formulario, _buzon_formulario(r), abrir, esperar, formulario=True):
                parar = True
                res["pendientes"] += 1
                continue
            if webhook and _buzon_post(webhook, _buzon_mensaje(r), abrir, esperar):
                res["discord"] += 1
            cupo -= 1
            res["enviados"] += 1
            hechos.append(clave)
            _registro_guardar(ruta_reg, hechos)
            marcar.append(k)
        if marcar:
            if _buzon_marcar(archivo, crudo, marcar):
                res["marcados"] += len(marcar)
            else:
                res["sin_marcar"] += len(marcar)
    return res


def frase_buzon(n: int) -> str:
    return f"Envié {n} reporte{'s' if n != 1 else ''} a Toxic. ¡Gracias por ayudar a la manada!"


# ---------------------------------------------------------------------------
# Marcador por bando (Alfa 1.4.0, plan 9)
# ---------------------------------------------------------------------------
# En el juego, la Horda y la Alianza no se hablan por addon: cada lado solo
# cuenta a los suyos (src/Alfa_Manada/Marcador.lua). El instalador ve los datos
# guardados de todas las cuentas de esta PC y, con el juego cerrado, deja en
# cada una el último número conocido de cada bando:
#   AlfaNucleoDB.jauria.bandos[H|A] = { n, fecha, fuente = "instalador" }
# El número de un bando es el más alto de:
#   * lo que cada cuenta contó en vivo de ese bando (bandos[l].n y el máximo del
#     día, de los últimos 30 días);
#   * los lobos distintos que oyó el censo de La Jauría con esa marca de bando
#     (AlfaNucleoDB.manada.censo[clave].f, de los últimos 30 días).
# No manda nada a internet. Solo toca la tabla bandos; copia de respaldo antes.
MARCADOR_DIAS = 30
MARCADOR_LETRAS = ("H", "A")


def _entero(v) -> "int | None":
    try:
        n = float(str(v))
    except (TypeError, ValueError):
        return None
    if n != n or n in (float("inf"), float("-inf")):
        return None
    return int(n)


def _campo(t, *ruta):
    for k in ruta:
        if not isinstance(t, _TablaLua):
            return None
        t = t.campos.get(k)
    return t


def _marcador_de(globales: dict, ahora: int) -> dict:
    """Lo que sabe una cuenta: {letra: {"n", "fecha", "lobos": {clave: t}}}."""
    db = globales.get(BUZON_GLOBAL)
    desde = ahora - MARCADOR_DIAS * 86400
    out = {l: {"n": 0, "fecha": 0, "lobos": {}} for l in MARCADOR_LETRAS}
    bandos = _campo(db, "jauria", "bandos")
    for l in MARCADOR_LETRAS:
        b = _campo(bandos, l)
        if not isinstance(b, _TablaLua) or b.campos.get("fuente") == "instalador":
            continue   # lo que dejó el instalador no se vuelve a contar
        fecha = _entero(b.campos.get("fecha")) or 0
        if fecha < desde or fecha > ahora + 86400:
            continue
        n = max(_entero(b.campos.get("n")) or 0, _entero(b.campos.get("max")) or 0)
        if 0 < n <= 100000:
            out[l]["n"], out[l]["fecha"] = n, fecha
    censo = _campo(db, "manada", "censo")
    if isinstance(censo, _TablaLua):
        for clave, x in censo.campos.items():
            if not (isinstance(clave, str) and isinstance(x, _TablaLua)):
                continue
            l, t = x.campos.get("f"), _entero(x.campos.get("t")) or 0
            if l in MARCADOR_LETRAS and desde <= t <= ahora + 86400:
                lobos = out[l]["lobos"]
                lobos[clave.lower()] = max(lobos.get(clave.lower(), 0), t)
    return out


def contar_bandos(archivos, ahora=None) -> dict:
    """{letra: {"n", "fecha"}} juntando lo de todas las cuentas (sin el bando que nadie vio)."""
    ahora = int(ahora if ahora is not None else time.time())
    vivo = {l: (0, 0) for l in MARCADOR_LETRAS}
    lobos = {l: {} for l in MARCADOR_LETRAS}
    for archivo in archivos:
        try:
            crudo = pathlib.Path(archivo).read_bytes()
            if b"jauria" not in crudo and b"censo" not in crudo:
                continue
            m = _marcador_de(leer_lua(crudo.decode("utf-8", "surrogateescape")), ahora)
        except (OSError, _LuaMal, UnicodeError, RecursionError):
            continue
        for l in MARCADOR_LETRAS:
            n, f = m[l]["n"], m[l]["fecha"]
            if n > vivo[l][0] or (n == vivo[l][0] and f > vivo[l][1]):
                vivo[l] = (n, f)
            for clave, t in m[l]["lobos"].items():
                lobos[l][clave] = max(lobos[l].get(clave, 0), t)
    salida = {}
    for l in MARCADOR_LETRAS:
        n, fecha = vivo[l]
        if len(lobos[l]) > n:
            n = len(lobos[l])
        fecha = max([fecha, *lobos[l].values()])
        if n > 0:
            salida[l] = {"n": n, "fecha": fecha}
    return salida


def _salto(texto: str) -> str:
    return "\r\n" if "\r\n" in texto else "\n"


def _tabla_texto(campos: list, nl: str) -> str:
    """Una tabla como la escribe el juego: {\n["n"] = 5,\n...}."""
    partes = []
    for k, v in campos:
        valor = f'"{v}"' if isinstance(v, str) else str(v)
        partes.append(f'["{k}"] = {valor},')
    return "{" + nl + nl.join(partes) + nl + "}"


def _marcador_escribir(archivo: pathlib.Path, crudo: bytes, cuenta: dict) -> int:
    """Deja en el archivo los bandos de `cuenta` que son más nuevos que los suyos.
    -> cuántos bandos escribió (0 si no hizo falta o si algo no cuadra: el archivo queda igual)."""
    try:
        if archivo.read_bytes() != crudo:
            return 0
        texto = crudo.decode("utf-8", "surrogateescape")
        globales = leer_lua(texto)
        db = globales.get(BUZON_GLOBAL)
        if not isinstance(db, _TablaLua):
            return 0
        nl = _salto(texto)
        jauria = _campo(db, "jauria")
        bandos = _campo(jauria, "bandos")
        esperado = _plano(globales)
        cambios = []   # (inicio, fin, texto nuevo)
        nuevos = []
        for l in MARCADOR_LETRAS:
            c = cuenta.get(l)
            if not c:
                continue
            viejo = _campo(bandos, l)
            if isinstance(viejo, _TablaLua):
                f = _entero(viejo.campos.get("fecha")) or 0
                n = _entero(viejo.campos.get("n"))
                if viejo.campos.get("fuente") == "instalador":
                    # lo de una vez anterior: se cambia si hay algo distinto y no más viejo
                    if (n, f) == (c["n"], c["fecha"]) or c["fecha"] < f:
                        continue
                elif c["fecha"] <= f:
                    continue   # lo que esta cuenta contó en vivo es igual de nuevo o más
            elif viejo is not None:
                return 0
            campos = [("n", c["n"]), ("fecha", c["fecha"]), ("fuente", "instalador")]
            nuevos.append((l, campos, viejo))
        if not nuevos:
            return 0
        # Lo que debe quedar.
        esperado.setdefault(BUZON_GLOBAL, {})
        eb = esperado[BUZON_GLOBAL].setdefault("jauria", {}).setdefault("bandos", {})
        for l, campos, viejo in nuevos:
            eb[l] = {k: (v if isinstance(v, str) else str(v)) for k, v in campos}
        # Dónde va cada cosa.
        if isinstance(bandos, _TablaLua):
            a0 = jauria.lugar["bandos"][0]
            for l, campos, viejo in nuevos:
                if isinstance(viejo, _TablaLua):
                    a, b = bandos.lugar[l]
                    cambios.append((a, b, _tabla_texto(campos, nl)))
                else:
                    cambios.append((a0 + 1, a0 + 1, nl + f'["{l}"] = ' + _tabla_texto(campos, nl) + ","))
        else:
            if jauria is not None and not isinstance(jauria, _TablaLua):
                return 0
            dentro = nl.join(f'["{l}"] = ' + _tabla_texto(campos, nl) + "," for l, campos, _ in nuevos)
            tabla_bandos = "{" + nl + dentro + nl + "}"
            if isinstance(jauria, _TablaLua):
                a0 = db.lugar["jauria"][0]
                cambios.append((a0 + 1, a0 + 1, nl + '["bandos"] = ' + tabla_bandos + ","))
            else:
                m = re.search(r"(?m)^" + BUZON_GLOBAL + r"\s*=\s*\{", texto)
                if not m:
                    return 0
                a0 = m.end() - 1
                cambios.append((a0 + 1, a0 + 1, nl + '["jauria"] = {' + nl + '["bandos"] = ' + tabla_bandos + "," + nl + "},"))
        nuevo = texto
        for a, b, t in sorted(cambios, key=lambda x: x[0], reverse=True):
            nuevo = nuevo[:a] + t + nuevo[b:]
        if _plano(leer_lua(nuevo)) != esperado:
            return 0
        datos = nuevo.encode("utf-8", "surrogateescape")
        respaldo = archivo.with_name(archivo.name + ".antes-del-marcador")
        if respaldo.exists():
            os.chmod(respaldo, 0o666)
            respaldo.unlink()
        respaldo.write_bytes(crudo)
        if respaldo.read_bytes() != crudo:
            return 0
        tmp = archivo.with_name(archivo.name + ".alfa-marcador.tmp")
        tmp.write_bytes(datos)
        try:
            os.replace(tmp, archivo)
        except OSError:
            try:
                tmp.unlink()
            except OSError:
                pass
            return 0
        return len(nuevos) if archivo.read_bytes() == datos else 0
    except (OSError, KeyError, AttributeError, TypeError, ValueError, _LuaMal, UnicodeError, RecursionError):
        return 0


def llevar_marcador(forevers, ahora=None) -> dict:
    """Cuenta los lobos por bando de todas las cuentas y lo deja en cada una.
    Llamar solo con el juego cerrado. Nunca lanza errores."""
    res = {"cuentas": 0, "escritos": 0, "bandos": {}}
    try:
        archivos = archivos_buzon(forevers)
        res["cuentas"] = len(archivos)
        cuenta = contar_bandos(archivos, ahora)
        res["bandos"] = {l: c["n"] for l, c in cuenta.items()}
        if not cuenta:
            return res
        for archivo in archivos:
            try:
                crudo = archivo.read_bytes()
            except OSError:
                continue
            res["escritos"] += _marcador_escribir(archivo, crudo, cuenta)
    except Exception:  # noqa: BLE001 - el marcador nunca debe estorbar a la instalación
        pass
    return res


# ---------------------------------------------------------------------------
# Ventana
# ---------------------------------------------------------------------------
FONDO = "#101412"
LATERAL = "#0b0e0c"
PANEL = "#18201b"
PANEL_ALTO = "#1f2a23"
LINEA = "#2b382f"
ACENTO = "#8be04e"
ACENTO_HOVER = "#a3ec6d"
SOBRE_ACENTO = "#0d1a08"
TEXTO = "#e8eee6"
TENUE = "#96a596"
APAGADO = "#5d6b60"
AVISO = "#e5b454"
ERROR = "#ff7b6b"
LETRA = "Segoe UI"
PASOS = ("Bienvenida", "Carpeta del juego", "Instalar", "Listo")


def _ventana():
    import tkinter as tk
    from tkinter import filedialog

    class Boton(tk.Label):
        """Botón plano con el estilo de Alfa (los botones de Tk no respetan colores en Windows)."""

        def __init__(self, padre, texto, accion, primario=False, s=1.0):
            self.primario, self.accion, self.activo = primario, accion, True
            super().__init__(padre, text=texto, cursor="hand2", padx=int(18 * s), pady=int(8 * s),
                             font=(LETRA, 10, "bold" if primario else "normal"))
            self._pintar(False)
            self.bind("<Enter>", lambda e: self._pintar(True))
            self.bind("<Leave>", lambda e: self._pintar(False))
            self.bind("<Button-1>", lambda e: self.activo and self.accion and self.accion())

        def _pintar(self, encima):
            if not self.activo:
                self.config(bg=PANEL, fg=APAGADO, cursor="arrow")
            elif self.primario:
                self.config(bg=ACENTO_HOVER if encima else ACENTO, fg=SOBRE_ACENTO, cursor="hand2")
            else:
                self.config(bg=PANEL_ALTO if encima else PANEL, fg=TEXTO, cursor="hand2")

        def habilitar(self, si=True):
            self.activo = si
            self._pintar(False)

    class Asistente(tk.Tk):
        def __init__(self, carpeta=None, seguir=False, zip_local=None, buzon=True):
            try:
                ctypes.windll.shcore.SetProcessDpiAwareness(1)
            except (AttributeError, OSError):
                pass
            super().__init__()
            self.s = s = max(1.0, self.winfo_fpixels("1i") / 96)
            self.title("Instalar Alfa")
            self.configure(bg=FONDO)
            self.resizable(False, False)
            ancho, alto = int(760 * s), int(500 * s)
            self.geometry(f"{ancho}x{alto}+{(self.winfo_screenwidth() - ancho) // 2}+{(self.winfo_screenheight() - alto) // 3}")
            try:  # barra de título oscura (Windows 10 2004+ y 11)
                self.update_idletasks()
                hwnd = ctypes.windll.user32.GetParent(self.winfo_id())
                ctypes.windll.dwmapi.DwmSetWindowAttribute(hwnd, 20, ctypes.byref(ctypes.c_int(1)), 4)
            except (AttributeError, OSError):
                pass
            self.cola = queue.Queue()
            self.info = None          # la versión más nueva en GitHub
            self.error_red = None
            self.instaladas = []      # instalaciones de Forever encontradas
            self.forever = forever_de(carpeta) if carpeta else None
            self.zip_local = pathlib.Path(zip_local) if zip_local else None
            self.ocupado = False
            self.buzon_activo = buzon
            self.webhook = webhook_buzon() if buzon else None
            self.buzon_hecho = False
            self.buzon_cerrojo = threading.Lock()
            self.protocol("WM_DELETE_WINDOW", self._cerrar)

            try:
                self.logo = tk.PhotoImage(file=str(recurso("avatar.png")))
                f = max(1, round(self.logo.width() / (92 * s)))
                self.logo_chico = self.logo.subsample(f)
                self.iconphoto(True, self.logo.subsample(max(1, self.logo.width() // 64)))
            except (tk.TclError, OSError):
                self.logo = self.logo_chico = None

            # Columna de la marca y los pasos
            lado = tk.Frame(self, bg=LATERAL, width=int(220 * s))
            lado.pack(side="left", fill="y")
            lado.pack_propagate(False)
            if self.logo_chico:
                tk.Label(lado, image=self.logo_chico, bg=LATERAL).pack(pady=(int(34 * s), int(8 * s)))
            tk.Label(lado, text="ALFA", font=(LETRA, 18, "bold"), fg=TEXTO, bg=LATERAL).pack()
            tk.Label(lado, text="Guía a tu manada", font=(LETRA, 9), fg=ACENTO, bg=LATERAL).pack(pady=(0, int(28 * s)))
            self.marcas = []
            for i, nombre in enumerate(PASOS, 1):
                fila = tk.Frame(lado, bg=LATERAL)
                fila.pack(fill="x", padx=int(28 * s), pady=int(5 * s))
                num = tk.Label(fila, text=str(i), width=2, font=(LETRA, 9, "bold"), bg=PANEL, fg=TENUE)
                num.pack(side="left")
                txt = tk.Label(fila, text=nombre, font=(LETRA, 10), bg=LATERAL, fg=TENUE)
                txt.pack(side="left", padx=int(10 * s))
                self.marcas.append((num, txt))
            tk.Label(lado, text=f"Hecho por toxic3000\npara La Jauría · v{VERSION}", font=(LETRA, 8),
                     fg=APAGADO, bg=LATERAL, justify="center").pack(side="bottom", pady=int(18 * s))
            # la línea del buzón: solo aparece cuando se mandó algo
            self.linea_buzon = tk.Label(lado, text="", font=(LETRA, 9), fg=ACENTO, bg=LATERAL, justify="center",
                                        wraplength=int(176 * s))

            # Contenido del paso
            self.cuerpo = tk.Frame(self, bg=FONDO)
            self.cuerpo.pack(side="left", fill="both", expand=True, padx=int(36 * s), pady=int(30 * s))
            self.after(80, self._bombear)
            threading.Thread(target=self._preparar, daemon=True).start()
            if seguir and self.forever:
                self.paso_instalar()
            else:
                self.paso_bienvenida()

        # -- utilidades de la ventana ------------------------------------------
        def _marcar(self, actual):
            for i, (num, txt) in enumerate(self.marcas):
                if i < actual:
                    num.config(text="✓", bg=ACENTO, fg=SOBRE_ACENTO)
                    txt.config(fg=TEXTO)
                elif i == actual:
                    num.config(text=str(i + 1), bg=ACENTO, fg=SOBRE_ACENTO)
                    txt.config(fg=TEXTO, font=(LETRA, 10, "bold"))
                else:
                    num.config(text=str(i + 1), bg=PANEL, fg=TENUE)
                    txt.config(fg=TENUE, font=(LETRA, 10))

        def _limpiar(self, paso, titulo, texto=None):
            for w in self.cuerpo.winfo_children():
                w.destroy()
            self._marcar(paso)
            self.paso_actual = paso
            tk.Label(self.cuerpo, text=titulo, font=(LETRA, 17, "bold"), fg=TEXTO, bg=FONDO,
                     anchor="w", justify="left").pack(fill="x")
            tk.Frame(self.cuerpo, bg=ACENTO, height=int(3 * self.s), width=int(40 * self.s)).pack(anchor="w", pady=(int(6 * self.s), int(14 * self.s)))
            if texto:
                self._parrafo(self.cuerpo, texto)
            self.botones = tk.Frame(self.cuerpo, bg=FONDO)
            self.botones.pack(side="bottom", fill="x")

        def _parrafo(self, padre, texto, color=TENUE, tam=10, bg=FONDO):
            # dentro de una tarjeta hay menos ancho (borde y relleno)
            ancho = 450 if bg == FONDO else 405
            l = tk.Label(padre, text=texto, font=(LETRA, tam), fg=color, bg=bg, anchor="w", justify="left",
                         wraplength=int(ancho * self.s))
            l.pack(fill="x", pady=(0, int(10 * self.s)))
            return l

        def _tarjeta(self, color=LINEA):
            borde = tk.Frame(self.cuerpo, bg=color)
            borde.pack(fill="x", pady=(int(6 * self.s), int(10 * self.s)))
            caja = tk.Frame(borde, bg=PANEL, padx=int(16 * self.s), pady=int(12 * self.s))
            caja.pack(fill="both", padx=(int(3 * self.s), 0))
            return caja

        def _boton(self, texto, accion, primario=False, izquierda=False):
            b = Boton(self.botones, texto, accion, primario, self.s)
            b.pack(side="left" if izquierda else "right", padx=(0 if izquierda else int(10 * self.s), 0))
            return b

        def _bombear(self):
            try:
                while True:
                    fn = self.cola.get_nowait()
                    fn()
            except queue.Empty:
                pass
            self.after(80, self._bombear)

        def _en_ventana(self, fn):
            self.cola.put(fn)

        def _cerrar(self):
            if self.ocupado == "copiando":
                return  # no cortar a la mitad de la copia
            self.destroy()

        # -- trabajo en segundo plano ------------------------------------------
        def _preparar(self):
            encontradas = buscar_forever()
            self._en_ventana(lambda: self._al_encontrar(encontradas))
            if self.buzon_activo:
                threading.Thread(target=self._buzon, args=(encontradas,), daemon=True).start()
            while self.info is None:
                try:
                    info = ultima_version()
                    self._en_ventana(lambda i=info: self._al_saber_version(i, None))
                    return
                except ErrorAmable as e:
                    self._en_ventana(lambda m=str(e): self._al_saber_version(None, m))
                    time.sleep(6)

        def _buzon(self, encontradas=()):
            """Manda los reportes del juego a Toxic. Con el juego abierto no toca nada:
            se intenta de nuevo al terminar de instalar (ahí ya está cerrado)."""
            if not self.buzon_activo or self.buzon_hecho or not self.buzon_cerrojo.acquire(blocking=False):
                return
            try:
                if self.buzon_hecho or wow_abierto():
                    return
                lugares = [f for f in [self.forever, *encontradas, *self.instaladas] if f]
                res = enviar_buzon(list(dict.fromkeys(lugares)), self.webhook)
                self.buzon_hecho = True
                # 1.4.0: el marcador por bando (solo en tu PC, nada a internet).
                llevar_marcador(list(dict.fromkeys(lugares)))
                if res["enviados"]:
                    self._en_ventana(lambda n=res["enviados"]: self.mostrar_buzon(n))
            except Exception:  # noqa: BLE001 - el buzón nunca debe estorbar a la instalación
                pass
            finally:
                self.buzon_cerrojo.release()

        def mostrar_buzon(self, n):
            self.linea_buzon.config(text=frase_buzon(n).replace(". ¡", ".\n¡", 1))
            self.linea_buzon.pack(side="bottom", padx=int(18 * self.s), pady=(0, int(4 * self.s)))

        def _al_encontrar(self, encontradas):
            self.instaladas = encontradas
            if not self.forever and encontradas:
                self.forever = encontradas[0]
            if getattr(self, "paso_actual", None) in (0, 1):
                (self.paso_bienvenida if self.paso_actual == 0 else self.paso_carpeta)()

        def _al_saber_version(self, info, error):
            if info:
                self.info, self.error_red = info, None
            else:
                self.error_red = error
            if getattr(self, "paso_actual", None) in (0, 1):
                (self.paso_bienvenida if self.paso_actual == 0 else self.paso_carpeta)()

        # -- pasos ---------------------------------------------------------------
        def paso_bienvenida(self):
            self._limpiar(0, "Instala Alfa en un minuto",
                          "Alfa es el todo en uno de La Jauría para WoW Forever: guías, ruta, mapa, bolsas, "
                          "talentos, enciclopedia, mazmorras y tu manada, en un solo addon. "
                          "Este asistente lo instala o lo actualiza por ti.")
            caja = self._tarjeta(ACENTO if self.info else (AVISO if self.error_red else LINEA))
            if self.info:
                tk.Label(caja, text=f"Alfa {self.info['version']}", font=(LETRA, 13, "bold"), fg=TEXTO,
                         bg=PANEL, anchor="w").pack(fill="x")
                linea = f"La versión más nueva · {_mb(self.info['tam'])}"
                tiene = version_instalada(self.forever) if self.forever else None
                if tiene:
                    if numeros(tiene) >= numeros(self.info["version"]):
                        linea += f"\nYa tienes Alfa {tiene}: está al día. Puedes reinstalarlo si algo falla."
                    else:
                        linea += f"\nTienes Alfa {tiene}: se actualizará a la {self.info['version']}."
                self._parrafo(caja, linea, bg=PANEL)
            elif self.error_red:
                tk.Label(caja, text="Sin conexión con GitHub", font=(LETRA, 12, "bold"), fg=AVISO, bg=PANEL,
                         anchor="w").pack(fill="x")
                self._parrafo(caja, self.error_red + " Lo intento de nuevo solo.", bg=PANEL)
            else:
                tk.Label(caja, text="Buscando la versión más nueva…", font=(LETRA, 11), fg=TENUE, bg=PANEL,
                         anchor="w").pack(fill="x")
            self._parrafo(self.cuerpo, "No toca tus ajustes del juego ni tus otros addons.", APAGADO, 9)
            self._boton("Empezar", self.paso_carpeta, primario=True)
            self._boton("Unirme al Discord", lambda: webbrowser.open(DISCORD), izquierda=True)

        def paso_carpeta(self):
            self._limpiar(1, "¿Dónde está tu WoW Forever?")
            if self.forever:
                caja = self._tarjeta(ACENTO)
                tk.Label(caja, text="✓  Encontré WoW Forever", font=(LETRA, 12, "bold"), fg=ACENTO, bg=PANEL,
                         anchor="w").pack(fill="x")
                self._parrafo(caja, str(self.forever), TEXTO, 9, PANEL)
                tiene = version_instalada(self.forever)
                self._parrafo(caja, f"Alfa {tiene} está instalado aquí." if tiene else "Alfa todavía no está instalado aquí.",
                              TENUE, 9, PANEL)
                if len(self.instaladas) > 1:
                    self._parrafo(self.cuerpo, f"Encontré {len(self.instaladas)} instalaciones de WoW. "
                                  "Si no es esta, usa «Cambiar carpeta».", AVISO, 9)
            else:
                caja = self._tarjeta(AVISO)
                tk.Label(caja, text="No encontré WoW Forever", font=(LETRA, 12, "bold"), fg=AVISO, bg=PANEL,
                         anchor="w").pack(fill="x")
                self._parrafo(caja, "Elige la carpeta «World of Warcraft» donde instalaste el juego "
                              "(la que tiene adentro la carpeta _forever_).", TENUE, 10, PANEL)
            listo = self.forever is not None and self.info is not None
            tiene = version_instalada(self.forever) if self.forever else None
            al_dia = bool(tiene and self.info and numeros(tiene) >= numeros(self.info["version"]))
            if self.forever and self.info is None:
                self._parrafo(self.cuerpo, "Esperando la información de la versión más nueva…" if not self.error_red
                              else self.error_red + " Lo intento de nuevo solo.", AVISO if self.error_red else TENUE, 9)
            b = self._boton("Reinstalar" if al_dia else ("Actualizar" if tiene else "Instalar"), self.paso_instalar, primario=True)
            b.habilitar(listo)
            self._boton("Cambiar carpeta…", self._elegir)
            self._boton("Atrás", self.paso_bienvenida, izquierda=True)

        def _elegir(self):
            ruta = filedialog.askdirectory(parent=self, title="Elige la carpeta World of Warcraft",
                                           initialdir=str(self.forever.parent) if self.forever else "C:\\")
            if not ruta:
                return
            f = forever_de(ruta)
            if f:
                self.forever = f
                self.paso_carpeta()
            else:
                self.forever = None
                self.paso_carpeta()
                self._parrafo(self.cuerpo, f"En «{ruta}» no está la carpeta _forever_. Elige la carpeta "
                              "World of Warcraft donde está WoW Forever.", ERROR, 9)

        def paso_instalar(self):
            self._armar_instalar()
            self.ocupado = "descargando"
            threading.Thread(target=self._trabajar, daemon=True).start()

        def _armar_instalar(self):
            version = self.info["version"] if self.info else "…"
            self._limpiar(2, f"Instalando Alfa {version}")
            nombres = ("Revisar que WoW esté cerrado", "Descargar Alfa", "Revisar la descarga", "Copiar los archivos")
            self.filas = []
            for n in nombres:
                fila = tk.Frame(self.cuerpo, bg=FONDO)
                fila.pack(fill="x", pady=int(4 * self.s))
                icono = tk.Label(fila, text="○", font=(LETRA, 11), fg=APAGADO, bg=FONDO, width=2)
                icono.pack(side="left")
                texto = tk.Label(fila, text=n, font=(LETRA, 10), fg=TENUE, bg=FONDO)
                texto.pack(side="left", padx=int(6 * self.s))
                self.filas.append((icono, texto))
            self.barra = tk.Canvas(self.cuerpo, height=int(8 * self.s), bg=PANEL, highlightthickness=0)
            self.barra.pack(fill="x", pady=(int(22 * self.s), int(8 * self.s)))
            self.relleno = self.barra.create_rectangle(0, 0, 0, int(8 * self.s), fill=ACENTO, width=0)
            self.detalle = self._parrafo(self.cuerpo, "", TENUE, 9)

        def _fila(self, i, estado):
            icono, texto = self.filas[i]
            if estado == "activo":
                icono.config(text="●", fg=ACENTO)
                texto.config(fg=TEXTO, font=(LETRA, 10, "bold"))
            elif estado == "hecho":
                icono.config(text="✓", fg=ACENTO)
                texto.config(fg=TENUE, font=(LETRA, 10))

        def _avance(self, frac, texto=None, color=TENUE):
            ancho = self.barra.winfo_width() or int(450 * self.s)
            self.barra.coords(self.relleno, 0, 0, int(ancho * max(0.0, min(1.0, frac))), int(8 * self.s))
            if texto is not None:
                self.detalle.config(text=texto, fg=color)

        def _trabajar(self):
            ui = self._en_ventana
            try:
                while self.info is None and not self.zip_local:
                    try:
                        self.info = ultima_version()
                    except ErrorAmable as e:
                        ui(lambda m=str(e): self._avance(0, m + " Lo intento de nuevo solo.", AVISO))
                        time.sleep(5)
                version = self.info["version"] if self.info else "local"
                ui(lambda: self._fila(0, "activo"))
                avisado = False
                while wow_abierto():
                    if not avisado:
                        ui(lambda: self._avance(0, "Cierra World of Warcraft para seguir. Sigo solo en cuanto lo cierres.", AVISO))
                        avisado = True
                    time.sleep(2)
                ui(lambda: (self._fila(0, "hecho"), self._fila(1, "activo"), self._avance(0, "Conectando…")))

                def informar(que, a, b):
                    if que == "descarga":
                        ui(lambda: self._avance(a / b if b else 0, f"{_mb(a)} de {_mb(b)}"))
                    elif que == "reintento":
                        ui(lambda: self._avance(0, f"La descarga se cortó; lo intento otra vez ({a} de {b})…", AVISO))
                    elif que == "copia":
                        ui(lambda: self._avance(a / b if b else 1, f"{a} de {b} archivos"))

                if self.zip_local:
                    zip_path = self.zip_local
                else:
                    zip_path = descargar(self.info, informar)
                ui(lambda: (self._fila(1, "hecho"), self._fila(2, "activo"), self._avance(1, "Firma SHA-256 correcta.")))
                with zipfile.ZipFile(zip_path) as z:
                    if z.testzip() is not None:
                        raise ErrorAmable("La descarga llegó dañada. Vuelve a intentarlo.")
                ui(lambda: (self._fila(2, "hecho"), self._fila(3, "activo"), self._avance(0, "Copiando…")))
                self.ocupado = "copiando"
                n = instalar(zip_path, self.forever, informar)
                self.ocupado = False
                if self.buzon_activo and not self.buzon_hecho:
                    threading.Thread(target=self._buzon, daemon=True).start()
                if not self.zip_local:
                    try:
                        zip_path.unlink()
                    except OSError:
                        pass
                ui(lambda: self.paso_listo(version, n))
            except ErrorPermiso as e:
                self.ocupado = False
                ui(lambda m=str(e): self.paso_error(m, permiso=True))
            except ErrorAmable as e:
                self.ocupado = False
                ui(lambda m=str(e): self.paso_error(m))
            except Exception as e:  # noqa: BLE001 - cualquier otra cosa, con un mensaje claro
                self.ocupado = False
                ui(lambda m=f"{type(e).__name__}: {e}": self.paso_error(
                    "Pasó algo que no esperaba. Si se repite, avísanos en el Discord de La Jauría con este detalle:\n" + m))

        def paso_listo(self, version, n):
            self._limpiar(3, f"¡Listo! Alfa {version} está instalado")
            caja = self._tarjeta(ACENTO)
            tk.Label(caja, text="Cómo empezar", font=(LETRA, 12, "bold"), fg=TEXTO, bg=PANEL, anchor="w").pack(fill="x")
            self._parrafo(caja, "1.  Abre World of Warcraft y entra con tu personaje.\n"
                                "2.  La primera vez, Alfa te recibe con una bienvenida guiada.\n"
                                "3.  Cuando quieras, escribe  /alfa  en el chat.", TEXTO, 10, PANEL)
            self._parrafo(self.cuerpo, f"Se instalaron {n} carpetas en {carpeta_addons(self.forever)}.", APAGADO, 9)
            self._parrafo(self.cuerpo, "Para actualizar, vuelve a abrir este instalador: baja la versión nueva y la pone sola.",
                          TENUE, 9)
            self._boton("Cerrar", self.destroy, primario=True)
            self._boton("Unirme al Discord de La Jauría", lambda: webbrowser.open(DISCORD))

        def paso_error(self, mensaje, permiso=False):
            self._limpiar(2, "No se pudo terminar")
            caja = self._tarjeta(ERROR)
            self._parrafo(caja, mensaje, TEXTO, 10, PANEL)
            if permiso:
                self._parrafo(self.cuerpo, "Voy a pedirle permiso a Windows: di que sí en la ventana que aparece "
                              "y sigo solo desde ahí.", TENUE, 9)
                self._boton("Dar permiso", self._elevar, primario=True)
            else:
                self._boton("Reintentar", self.paso_instalar, primario=True)
            self._boton("Cerrar", self.destroy)
            self._boton("Descargar a mano", lambda: webbrowser.open(DESCARGAS), izquierda=True)

        def _elevar(self):
            if pedir_administrador(self.forever):
                self.destroy()

    return Asistente


# ---------------------------------------------------------------------------
# Modos sin ventana (pruebas) y capturas del diseño
# ---------------------------------------------------------------------------
def solo_buzon(carpeta) -> int:
    """Manda los reportes pendientes sin instalar nada (para probarlo)."""
    forevers = [forever_de(carpeta)] if carpeta else buscar_forever()
    webhook = webhook_buzon()
    print("Formulario:", BUZON_FORMULARIO["url"])
    print("Discord:", "sí (buzon_local.json)" if webhook else "no (sin instalador/buzon_local.json)")
    if wow_abierto():
        print("WoW está abierto: ciérralo y vuelve a intentarlo")
        return 1
    print("Archivos:", *[str(a) for a in archivos_buzon(forevers)] or ["ninguno"], sep="\n  ")
    res = enviar_buzon(forevers, webhook)
    print(res)
    if res["enviados"]:
        print(frase_buzon(res["enviados"]))
    print("Marcador por bando:", llevar_marcador(forevers))
    return 0


def sin_ventana(carpeta, zip_local) -> int:
    forever = forever_de(carpeta) if carpeta else (buscar_forever() or [None])[0]
    if not forever:
        print("No encontré WoW Forever")
        return 1
    print("Forever:", forever, "| instalada:", version_instalada(forever))
    try:
        if zip_local:
            zip_path = pathlib.Path(zip_local)
        else:
            info = ultima_version()
            print("Más nueva:", info["version"], info["tam"], "bytes, sha256", bool(info["sha256"]))
            zip_path = descargar(info, lambda q, a, b: None)
        n = instalar(zip_path, forever, lambda q, a, b: None)
    except ErrorAmable as e:
        print("ERROR:", e)
        return 1
    print("Instaladas", n, "carpetas | ahora:", version_instalada(forever))
    return 0


def capturas(destino) -> int:
    from PIL import ImageGrab
    destino = pathlib.Path(destino)
    destino.mkdir(parents=True, exist_ok=True)
    Asistente = _ventana()
    app = Asistente(buzon=False)
    app.info = {"version": "1.0.0", "tam": 58014400, "url": "", "sha256": None, "nombre": "Alfa-1.0.0.zip"}

    def foto(nombre):
        app.update()
        time.sleep(0.4)
        app.update()
        x, y = app.winfo_rootx(), app.winfo_rooty()
        ImageGrab.grab((x, y, x + app.winfo_width(), y + app.winfo_height())).save(destino / f"{nombre}.png")

    app.lift()
    app.attributes("-topmost", True)
    app.paso_bienvenida(); foto("1-bienvenida")
    app.mostrar_buzon(2); foto("1b-buzon")
    app.paso_carpeta(); foto("2-carpeta")
    guardada = app.forever
    app.forever = None
    app.paso_carpeta(); foto("2b-sin-carpeta")
    app.forever = guardada
    # la instalación a la mitad, sin trabajar de verdad
    app._armar_instalar()
    app._fila(0, "activo")
    app.update()
    app._avance(0, "Cierra World of Warcraft para seguir. Sigo solo en cuanto lo cierres.", AVISO)
    foto("3a-esperando-wow")
    app._fila(0, "hecho"); app._fila(1, "activo")
    app._avance(0.42, "23 MB de 55 MB", TENUE)
    foto("3b-descargando")
    app.forever = app.forever or pathlib.Path(r"C:\Program Files (x86)\World of Warcraft\_forever_")
    app.paso_listo("1.0.0", 44); foto("4-listo")
    app.paso_error("Windows no me deja escribir en la carpeta del juego.", permiso=True); foto("5-error-permiso")
    app.destroy()
    print("capturas en", destino)
    return 0


def main(argv) -> int:
    def valor(bandera):
        return argv[argv.index(bandera) + 1] if bandera in argv and argv.index(bandera) + 1 < len(argv) else None

    if "--capturas" in argv:
        return capturas(valor("--capturas"))
    if "--solo-buzon" in argv:
        return solo_buzon(valor("--carpeta"))
    if "--sin-ventana" in argv:
        return sin_ventana(valor("--carpeta"), valor("--zip"))
    Asistente = _ventana()
    Asistente(carpeta=valor("--carpeta"), seguir="--seguir" in argv, zip_local=valor("--zip"),
              buzon="--sin-buzon" not in argv).mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
