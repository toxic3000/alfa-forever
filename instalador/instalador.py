"""Instalador de Alfa: un asistente guiado que instala o actualiza Alfa en
WoW Forever sin tocar carpetas a mano (toxic3000 / La Jauria, GPL-3.0).

1. Bienvenida: revisa en GitHub cuál es la versión más nueva de Alfa.
2. Carpeta del juego: encuentra WoW Forever solo (Battle.net, registro y
   discos); si no, deja elegir la carpeta.
3. Instalar: espera a que WoW esté cerrado, descarga el zip de la versión,
   revisa su firma SHA-256 y reemplaza las carpetas de Alfa (si algo falla,
   deja todo como estaba).
4. Listo: cómo empezar en el juego y el Discord de La Jauría.

No toca la carpeta WTF (tus ajustes) ni ningún otro addon.

Para probar sin ventana:   python instalador.py --sin-ventana --carpeta X [--zip Y]
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
import urllib.request
import webbrowser
import zipfile

VERSION = "1.0.0"
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
        def __init__(self, carpeta=None, seguir=False, zip_local=None):
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
            while self.info is None:
                try:
                    info = ultima_version()
                    self._en_ventana(lambda i=info: self._al_saber_version(i, None))
                    return
                except ErrorAmable as e:
                    self._en_ventana(lambda m=str(e): self._al_saber_version(None, m))
                    time.sleep(6)

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
    app = Asistente()
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
    if "--sin-ventana" in argv:
        return sin_ventana(valor("--carpeta"), valor("--zip"))
    Asistente = _ventana()
    Asistente(carpeta=valor("--carpeta"), seguir="--seguir" in argv, zip_local=valor("--zip")).mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
