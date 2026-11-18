# Manual de usuario de Alfa

El manual en PDF, uno por idioma, se arma con `tools/manual.py`. Nada se hace a mano: textos, capturas e índice salen del generador, así que en cada versión basta con volver a correrlo.

| Idioma | PDF |
|---|---|
| Español (México) | `Alfa-Manual-Espanol-Mexico.pdf` |
| Español (España) | `Alfa-Manual-Espanol-Espana.pdf` |
| English | `Alfa-Manual-English.pdf` |
| Deutsch | `Alfa-Manual-Deutsch.pdf` |
| Français | `Alfa-Manual-Francais.pdf` |
| Português (Brasil) | `Alfa-Manual-Portugues-Brasil.pdf` |
| Русский | `Alfa-Manual-Russian.pdf` |
| 한국어 | `Alfa-Manual-Korean.pdf` |
| 简体中文 | `Alfa-Manual-Chinese-Simplified.pdf` |
| 繁體中文 | `Alfa-Manual-Chinese-Traditional.pdf` |

Los nombres de los archivos están en `IDIOMAS`, al principio de `tools/manual.py`.

## Regenerarlo

```bash
python -I tools/manual.py                     # los 10 PDF (unos 10 minutos)
python -I tools/manual.py esMX                # solo uno
python -I tools/manual.py --capturas          # antes, copia las capturas nuevas del banco y del instalador
python -I tools/manual.py esMX --revisar CARPETA   # además, cada página a PNG y una hoja de muestra
python -I tools/manual.py esMX --html CARPETA      # además, el HTML para abrirlo en el navegador
```

Al final dice `RESULTADO: todo bien` o la lista de avisos de cada idioma. Necesita Microsoft Edge (viene con Windows) y, en el Python del sistema, `playwright`, `pymupdf`, `fonttools` y `Pillow` (ya están). La versión de Alfa de la portada sale de `tools/alfa.json`.

### Qué revisa solo

- **Estructura:** cada idioma tiene los mismos bloques, imágenes, íconos y comandos que `esMX.json`.
- **Textos que se salen:** antes de imprimir busca textos más anchos que su caja o fuera de su hoja.
- **Páginas vacías o casi vacías.** Cada capítulo empieza en su página; si la última de un capítulo queda casi vacía, el generador prueba tres niveles de apretado (imágenes más chicas, menos aire) y se queda con el que mejor acomoda. En la consola sale como `(apretados: lya x2, ...)`.
- **Cuadritos:** que cada letra del PDF exista en las fuentes del manual.
- **Índice:** los números de página se miden en una primera pasada y se escriben en la segunda.

## Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Textos | `textos/<idioma>.json`. El español de México (`esMX.json`) manda: los demás tienen la misma forma |
| Capturas | `imagenes/*.png` (las copia `--capturas`; ver abajo) |
| Letras | `letras/`: Inter y Fira Sans con su licencia (SIL OFL 1.1). Coreano y chino usan las de Windows (Malgun Gothic, Microsoft YaHei y Microsoft JhengHei), que Windows permite incrustar en documentos |
| Plantilla y estilo | `tools/manual.py` (`CSS` y la clase `Armado`) |
| Íconos, Lya y marca | Se convierten en cada corrida desde `motor/Alfa/Media/UI/ic-*.tga`, `src/Alfa_Lya/Media/lya-cuerpo*.tga`, `marca/` y `curseforge/avatar.png` |

## Cambiar un texto

Edita el JSON del idioma. Marcas que entiende el texto: `**negrita**`, `*cursiva*`, `` `/alfa comando` `` y `[[Tecla]]`. Los enlaces `https://...` se vuelven clic solos.

Cada capítulo es una lista de bloques (`"t"` dice el tipo):

| Bloque | Para qué |
|---|---|
| `intro`, `p`, `h` | Párrafo de entrada, párrafo y subtítulo |
| `lista`, `pasos`, `etapas` | Viñetas, pasos numerados y pasos en tarjetas (con `titulo` opcional) |
| `tarjetas` | Tarjetas con ícono (`cols`: 1, 2 o 3) |
| `consejo`, `nota`, `importante` | Cajas de color |
| `lya` | Un globo de Lya (`pose`: la de `POSES` en `tools/manual.py`) |
| `novedad` | La caja de novedades (ver abajo) |
| `teclas`, `comandos`, `faq` | Atajos, comandos y preguntas |
| `img` | Una captura (`img`: su nombre en `imagenes/`; `ancho`: `media`, `chica` o `angosta`; `marcas` + `leyenda`: llamadas numeradas) |
| `dos` | Captura y texto lado a lado (`lado`: `izq` o `der`; `prop`: 34, 40, 50 o 60) |
| `ilustracion` | Dibujos hechos en HTML que se traducen: `rotacion`, `raton`, `pesca`, `mapa`, `cuadro`, `instalador` |
| `enlace`, `creditos`, `poses` | El enlace grande del Discord, la tabla de créditos y las poses de Lya |

Si cambias la forma del español (un bloque nuevo, una imagen, un elemento más en una lista), haz el mismo cambio en los otros nueve idiomas: el generador avisa con `estructura ...` lo que no coincida. Las posiciones de las llamadas numeradas están en `MARCAS` (en pixeles de la captura original) y el texto de cada una en la `leyenda` del JSON.

## La caja «Novedad»

`NOVEDADES` en `tools/manual.py` dice de qué versión es cada caja (`{"mapa": "1.2.1"}`) y `"novedades"` de cada JSON trae su título y sus puntos. Mientras `tools/alfa.json` esté por debajo de esa versión, la caja dice «Lo que llega con la versión 1.2.1»; desde esa versión, «Lo nuevo desde la versión 1.2.1». Para quitarla, borra el bloque `{"t": "novedad", "ref": "mapa"}` de los JSON (o su entrada en `NOVEDADES`).

## Capturas

Salen del banco de pruebas (`tools/banco/`), que dibuja las ventanas reales de Alfa sobre un juego simulado: **no dibuja el arte del juego** (el mapa sale vacío, los íconos de objetos son fichas lisas), por eso el capítulo del mapa usa un dibujo de referencia. Las capturas muestran Alfa en español en todos los idiomas; los demás manuales lo dicen en una nota al principio.

Para renovarlas:

```bash
python -I tools/build.py
.venv/Scripts/python -I tools/banco/run.py dist <módulos de curseforge/LEEME.md> galeria.lua
.venv/Scripts/python -I tools/banco/run.py dist <los mismos módulos> galeria110.lua
.venv/Scripts/python -I tools/banco/run.py dist <los mismos módulos> manual.lua
python -I tools/manual.py --capturas
```

`manual.lua` dibuja las páginas que la galería no tiene (Curación, Comercio, Recolección, Combate, Comodidades, Lya, Pesca, Paisaje, Misiones, Estilo y sonido y Reportar). La del instalador sale de `instalador/instalador.py --capturas`. Qué archivo y qué recorte usa cada captura está en `CAPTURAS`.

## Agregar un idioma

1. Agrégalo a `IDIOMAS` en `tools/manual.py` (archivo, etiqueta de idioma y, si usa otra escritura, la letra de Windows).
2. Copia `textos/esMX.json` como `textos/<idioma>.json` y traduce solo el texto: deja igual `t`, `id`, `img`, `marcas`, `icono`, `pose`, `cmd`, `url`, los comandos `/alfa ...` y los huecos `{v}` y `{j}`.
3. Usa los nombres que ya usa Alfa en ese idioma (`textos/<idioma>/*.json` del addon).
4. `python -I tools/manual.py <idioma>` hasta que diga `todo bien`.
