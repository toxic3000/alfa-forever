"""El mapa del código de Alfa (1.4.1): docs/MAPA.md.

Uso:
  python -I tools/mapa.py            escribe docs/MAPA.md
  python -I tools/mapa.py --revisar  no escribe; termina con 1 si MAPA.md está
                                     atrasado o si un archivo .lua no tiene cabecera

Cada archivo de Lua empieza con su cabecera: «-- Alfa - <Módulo>: <qué hace>».
Este mapa junta esas cabeceras por módulo y dice qué pruebas del banco tocan
cada módulo, para saber dónde agregar algo nuevo y dónde buscar un error.
Lo de «Si pasa esto, mira aquí» se escribe a mano abajo (SINTOMAS).
"""
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "docs" / "MAPA.md"
BANCO = RAIZ / "tools" / "banco"

# Si pasa esto, mira aquí. (Escrito a mano: agrega una fila cuando un error
# nuevo te enseñe dónde vivía.)
SINTOMAS = [
    ("No puedo clicar algo del juego, la cámara no gira o la rueda no hace zoom",
     "`/alfa raton` en el juego (dice quién se queda con el clic). Código: `src/Alfa_Nucleo/Kit/Raton.lua` (guardia, `K.SinRaton`, `K.Enganchar`), `Kit/Movible.lua` (Mayús+arrastre).",
     "`prueba_141_raton.lua`, `tools/banco/raton.lua` (barrido del ratón)"),
    ("El volumen o el sonido no me obedece",
     "`src/Alfa_Pesca/Pesca.lua` (deseadas, Aplicar, Restaurar, `/alfa sonido`), `src/Alfa_Comodidades/Sonidos.lua`.",
     "`prueba_140_control.lua`"),
    ("Un error de Lua", "`/alfa errores` (lista y copia). Código: `src/Alfa_Nucleo/Errores.lua`.", "el banco: agrega el caso primero"),
    ("«Alfa_X se ha bloqueado de una acción…»",
     "Una función restringida o protegida en combate: busca la función en `referencia/` (`HasRestrictions`) y pásala por `N.FueraDeCombate` o un botón seguro.",
     "`NOTE(\"ADDON_ACTION_BLOCKED\", ...)` en el banco"),
    ("Un texto cortado o que se sale de su caja", "El Kit (`src/Alfa_Nucleo/Kit/`) y la página del módulo (`Pagina.lua`).",
     "`prueba_letras.lua`, galería (`tools/prueba.py`)"),
    ("Los anuncios grandes (zona, raro, barco)", "`src/Alfa_Nucleo/Kit/Anuncio.lua`, `src/Alfa_Nucleo/Zonas.lua`.", "`prueba_140_anuncios.lua`"),
    ("Los avisos pequeños y Lya diciéndolos", "`src/Alfa_Nucleo/Kit/Ventanas.lua` (`K.Aviso`), `src/Alfa_Nucleo/Momentos.lua`, `src/Alfa_Lya/Cerebro.lua`.",
     "`prueba_138_avisos.lua`, `prueba_139_avisos.lua`"),
    ("La flecha, sus placas o la tarjeta de viaje", "`motor/Alfa/Nav/Arrow.lua`.", "`prueba_139_flecha.lua`"),
    ("Una guía o un paso que no avanza", "`src/Alfa_Rutas/` (Guias, Rastreador, Ruta), paquetes de pasos de `tools/tramos.py`.",
     "`prueba_134_guias.lua`, `prueba_140_misiones.lua`"),
    ("Un ajuste que no se guarda o cambia solo", "`motor/Alfa/UI/Options.lua`, migraciones `N.Migracion` (`src/Alfa_Nucleo/`).",
     "`prueba_ajustes.lua` (3 fases)"),
    ("La pantalla se ve rara tras Dos pantallas", "`src/Alfa_Bienvenida/Escritorio*.lua`, `/alfa pantallas reparar`.", "`prueba_140_pantallas.lua`"),
    ("Va lento o tiene tirones", "`/alfa rendimiento`; `src/Alfa_Nucleo/Reloj.lua` (todo lo que se repite va ahí).",
     "`tools/perfil.py`, `prueba_140_velocidad.lua`"),
    ("Algo en combate o en mazmorra (valores secretos)", "`issecretvalue` primero: `N.Leer`, `N.LeerNumero` (`src/Alfa_Nucleo/Nucleo.lua`).",
     "`prueba_140_secretos.lua`"),
]

AGREGAR = """## Para agregar algo nuevo

1. **El lugar:** el módulo de la tabla de abajo cuyo tema es el tuyo; un archivo nuevo va en su carpeta y en su `.toc`, con su cabecera `-- Alfa - <Módulo>: <qué hace> (versión). toxic3000 / La Jauría. GPL-3.0.`
2. **Sus textos:** en español en el código (`L["..."]`), el inglés en el `Textos.lua` del módulo y los demás idiomas en `textos/<idioma>/Alfa_<versión>.json` (`tools/textos.py estado`).
3. **Sus ajustes:** `A.RegisterDefaults` en el módulo y su fila en la `Pagina.lua` del módulo; si cambia un valor de fábrica, una migración (`N.Migracion`).
4. **Lo que se ve en pantalla:** con el Kit (`src/Alfa_Nucleo/Kit/`). Un marco que no dibuja nada (un ancla) nunca toma el ratón: `K.SinRaton(marco)`. Un gancho a un marco del juego: `K.Enganchar(marco, script, fn)`, nunca `HookScript` directo con scripts del ratón. Que se pueda mover: `K.Movible`.
5. **Lo que se repite:** `N.Cada` / `N.Una` (`src/Alfa_Nucleo/Reloj.lua`); lo que espera al fin del combate, `N.FueraDeCombate`.
6. **Su prueba:** `tools/nueva_version.py` deja la plantilla (`tools/banco/plantilla_prueba.lua`); termina siempre con `RATON_LIMPIO`.
7. **Lya lo presenta:** `AlfaLya.Ensenar({ id, pregunta, respuesta, icono, modulo })`.
"""

CABECERA = re.compile(r"^--\s*(.*)")
LIMPIAR = [
    re.compile(r"\s*\(?toxic3000\s*/\s*La\s*Jaur[ií]a\)?\.?", re.I),
    re.compile(r"\s*GPL-3\.0\.?", re.I),
    re.compile(r"^Alfa\s*-\s*"),
]


def cabecera(ruta: pathlib.Path) -> str | None:
    lineas = ruta.read_text(encoding="utf-8", errors="replace").splitlines()
    partes = []
    for l in lineas[:6]:
        m = CABECERA.match(l)
        if not m:
            break
        t = m.group(1).strip()
        if not t:
            break
        partes.append(t)
    if not partes:
        return None
    texto = " ".join(partes)
    for r in LIMPIAR:
        texto = r.sub("", texto)
    texto = texto.strip(" .")
    # «Módulo: lo que hace» -> lo que hace
    if ":" in texto[:40]:
        texto = texto.split(":", 1)[1].strip()
    if len(texto) > 160:
        texto = texto[:157].rsplit(" ", 1)[0] + "…"
    return texto or None


def carpetas():
    for d in sorted((RAIZ / "src").iterdir()):
        if d.is_dir():
            yield d
    for d in sorted((RAIZ / "motor" / "Alfa").iterdir()):
        if d.is_dir() and d.name != "Media":
            yield d


def archivos(d: pathlib.Path):
    for f in sorted(d.rglob("*.lua")):
        if "Idiomas" in f.parts:
            continue
        yield f


def pruebas_de(modulo: str, textos_pruebas: dict) -> list[str]:
    nombre = modulo.replace("Alfa_", "")
    out = []
    for nombre_prueba, texto in textos_pruebas.items():
        if f'NS_OF("{modulo}")' in texto:
            out.append(nombre_prueba)
    return out


def armar() -> tuple[str, list[str]]:
    sin = []
    textos_pruebas = {p.name: p.read_text(encoding="utf-8", errors="replace") for p in sorted(BANCO.glob("prueba*.lua"))}
    l = ["# El mapa del código de Alfa", "",
         "Generado por `python -I tools/mapa.py` desde la cabecera de cada archivo (no se edita a mano;",
         "lo de «Si pasa esto, mira aquí» vive en `tools/mapa.py`). `tools/prueba.py` revisa que esté al día.", "",
         "## Si pasa esto, mira aquí", "", "| Lo que pasa | Dónde mirar | Su prueba |", "|---|---|---|"]
    for a, b, c in SINTOMAS:
        l.append(f"| {a} | {b} | {c} |")
    l += ["", AGREGAR, "## Los módulos", ""]
    for d in carpetas():
        rel = d.relative_to(RAIZ).as_posix()
        fs = list(archivos(d))
        if not fs:
            continue
        lineas = sum(len(f.read_text(encoding="utf-8", errors="replace").splitlines()) for f in fs)
        modulo = d.name if d.parent.name == "src" else "Alfa"
        pr = pruebas_de(modulo, textos_pruebas) if modulo != "Alfa" else []
        l.append(f"### `{rel}/` — {len(fs)} archivos, {lineas:,} líneas".replace(",", "."))
        if pr:
            muestra = ", ".join(f"`{p}`" for p in pr[-8:])
            l.append(f"Pruebas que lo usan ({len(pr)}): {muestra}{' y más' if len(pr) > 8 else ''}")
        l.append("")
        for f in fs:
            c = cabecera(f)
            if c is None:
                sin.append(f.relative_to(RAIZ).as_posix())
                c = "(sin cabecera)"
            l.append(f"- `{f.relative_to(d).as_posix()}` — {c}")
        l.append("")
    return "\n".join(l) + "\n", sin


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    texto, sin = armar()
    for s in sin:
        print("SIN CABECERA", s)
    if "--revisar" in sys.argv:
        actual = SALIDA.read_text(encoding="utf-8") if SALIDA.exists() else ""
        atrasado = actual != texto
        if atrasado:
            print("MAPA atrasado: corre python -I tools/mapa.py")
        print(f"MAPA: {len(sin)} archivos sin cabecera{', atrasado' if atrasado else ', al día'}")
        return 1 if (sin or atrasado) else 0
    SALIDA.write_text(texto, encoding="utf-8")
    print(f"MAPA: docs/MAPA.md escrito ({len(sin)} archivos sin cabecera)")
    return 1 if sin else 0


if __name__ == "__main__":
    sys.exit(main())
