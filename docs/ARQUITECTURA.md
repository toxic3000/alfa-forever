# Arquitectura de Alfa

Alfa es un solo addon para WoW Forever (cliente 1.60.1, `## Interface: 16001`) hecho por toxic3000 / La Jauría. Junta en un solo lugar guías, mapa, bolsas, builds, curación, recolección, mazmorras, pesca, comercio y comodidades, sobre el motor de Polestar. Es software libre bajo la GPL-3.0.

## Cómo se construye

```
upstream/polestar-<v>/   Polestar publicado, bajado y verificado (no va en git)
src/Alfa_*/              módulos propios (sí van en git)
tools/                   fetch_upstream, build, renombrar, parches, revisar, humo
dist/                    lo que se instala en Interface/AddOns (no va en git)
motor/                   la interfaz propia del motor (diseño A) y sus archivos propios
referencia/              código de la interfaz de Forever (no va en git)
```

```bash
python -I tools/fetch_upstream.py 0.3.7.2      # una vez por versión de Polestar
python -I tools/build.py                       # arma dist/
.venv/Scripts/python -I tools/revisar.py       # sintaxis Lua 5.1 + TOC/XML
.venv/Scripts/python -I tools/humo.py          # carga los módulos con el juego simulado
```

- **Motor (dist/Alfa y sus partes):** es Polestar con el nombre cambiado. `build.py` reemplaza Polestar por Alfa en el código y los textos, pero nunca en los comentarios, porque ahí están los avisos de copyright que la GPL obliga a conservar. Los cambios de comportamiento van en `tools/parches.py`: cada parche debe encajar exactamente, y si Polestar cambia ese código la construcción se detiene. **Nunca se edita dist/ a mano.**
- **Actualizar Polestar:** se cambia `upstream` en `tools/alfa.json`, se corre `fetch_upstream.py` y luego `build.py`; si un parche ya no encaja, se ajusta.
- **Versión única:** el build pone la versión de `tools/alfa.json` en todos los `.toc`, también en los de `src/`.

## El motor que usan los módulos

`Alfa` (global) es el espacio de nombres interno del motor, `ns` en su código. Lo que pueden usar los módulos (verificado en `dist/Alfa/Core/Init.lua` y `Theme/Widgets.lua`):

| Función | Para qué |
|---|---|
| `Alfa.RegisterOptions(spec)` | Agrega una página a la ventana de Alfa. Se usa a través de `AlfaNucleo.Modulo` |
| `Alfa.RegisterDefaults(seccion, tabla)`, `Alfa.Get("seccion.clave")`, `Alfa.Set(...)` | Ajustes guardados en `AlfaDB.settings`. Cada `Set` dispara el mensaje `SETTING_CHANGED` |
| `Alfa.RegisterEvent(evento, fn)` | Eventos del juego por un marco compartido. Devuelve false si el evento no existe en Forever |
| `Alfa.On(msg, fn)`, `Alfa.Off(h)`, `Alfa.Fire(msg, ...)` | Mensajes internos (`SHOW_OPTIONS`, `TOGGLE_FRAME`, `SETTING_CHANGED`, `ALFA_MODULO`...) |
| `Alfa.RegisterCommand(nombre, fn, ayuda)` | Agrega el comando `/alfa <nombre>` |
| `Alfa.Print(...)` | Escribe en el chat con el prefijo de Alfa |
| `Alfa.Widgets` (W) y `Alfa.Theme` | El kit visual de la ventana: `W.Shell`, `W.Button`, `W.Checkbox`, `W.Dropdown`, `W.Text`, `W.Scroll`, `W.SearchBox`, `W.Chip`, `W.ActionTile`, `W.SectionHeader`, `W.Modal`, `W.CopyBox`, `W.ProgressLine`... (ver `dist/Alfa/Theme/Widgets.lua`). **Usarlo siempre**: así todo se ve como el menú de Polestar |
| `Alfa.Codex`, `Alfa.QuestDB`, `Alfa.ItemDB`, `Alfa.Gear`, `Alfa.Dungeons`, `Alfa.Pins`... | Datos y sistemas del motor. Antes de usarlos, leer su código en `dist/Alfa` |

La prueba de humo (`tools/humo.py`) marca como ERROR cualquier `Alfa.algo` que no exista en el motor.

## Contrato de un módulo

Cada módulo es una carpeta `src/Alfa_<Nombre>/` con su `.toc`, y es un addon aparte del mismo paquete:

```
## Interface: 16001
## Title: |cff8be04eAlfa|r - <Nombre>
## Notes: <una línea en español>
## Author: toxic3000 - La Jauria
## Version: dev
## X-License: GPL-3.0-only
## Dependencies: Alfa, Alfa_Nucleo
## Category: Alfa
## SavedVariables: ...        (solo si de verdad necesita las suyas)

Textos.lua
<Nombre>.lua
...
```

```lua
local ADDON, M = ...
local N = AlfaNucleo          -- núcleo propio (src/Alfa_Nucleo/Nucleo.lua)
local A = N.A                 -- el motor
local W, T = A.Widgets, A.Theme
local L = N.Textos(M.EN)      -- M.EN viene de Textos.lua

N.Modulo({
	id = "bolsas", nombre = L["Bolsas"], icono = "icon-collect", orden = 40,
	subtitulo = L["..."], comando = "bolsas",
	ajustes = { vista = "categorias", ordenar = true },
	construir = function(view) ... end,
})
```

- **Ajustes:** `N.Get(id, clave)` y `N.Set(id, clave, valor)`.
- **Datos que no son ajustes** (historiales, precios, inventarios): `N.Datos(id)` para la cuenta y `N.DatosPersonaje(id)` para el personaje. Siempre se leen con esas funciones y nunca se guarda la referencia, porque el juego puede devolverlas en nil al arrancar.
- **Textos:** se escriben en español dentro de `L["..."]`. `Textos.lua` define `M.EN = { ["texto en español"] = "English text" }`. El español es el idioma principal.
- **Utilidades:** `N.Dinero(cobre)`, `N.Duracion(seg)`, `N.Imprimir(...)`, `N.FueraDeCombate(fn)` y `N.Abrir(id)`.
- **Lya:** `src/Alfa_Lya` es la loba compañera en pantalla; cualquier módulo puede hacerla hablar con `AlfaLya.Decir(texto, { importante, accion = { texto, fn } })`, que respeta sus reglas contra el spam (ver su `LEEME.md`).
- **Paisaje y gráficos:** `src/Alfa_Vista` (Mundo > Paisaje y gráficos, `/alfa paisaje`) expone ajustes escondidos del juego (CVars), preajustes y filtros propios; otros módulos usan `AlfaVista.Abrir()`, `AlfaVista.AplicarPreset(nombre)` y `AlfaVista.Presets()` (ver su `LEEME.md`).
- **Archivos:** cada módulo toca solo su carpeta. Si necesita algo del motor o del núcleo que no existe, lo dice en su reporte en lugar de editar otra carpeta.

## El núcleo: lo que comparten los módulos (al día con la 1.4.0)

`src/Alfa_Nucleo/` (global `AlfaNucleo`, `N` en el código) junta lo que antes cada módulo hacía a su manera. Cada archivo explica su contrato arriba; lo principal:

| Archivo | Qué da |
|---|---|
| `Nucleo.lua` | `N.Modulo`, `N.Get/Set`, `N.Datos/N.DatosPersonaje`, `N.Migracion(n, fn)` y `N.MigrarDesde(n)`, `N.Repintar`, `N.Reino`, `N.Imprimir`, `N.Dinero`, `N.Duracion`, `N.Plural`, `N.Secreto/N.Leer/N.LeerNumero/N.Si/N.SiJuego` (valores secretos) |
| `Reloj.lua` (1.2.9) | Un solo reloj para todo lo que se repite: `N.Cada`, `N.Una`, `N.Ticker`, `N.Quitar`, `N.Tareas()`. Duerme sin tareas; modo combate (`N.DeFondo`), mazmorra (`N.DeAfuera`) y ligero (`N.Ligero`). 1.3.9: `N.VistaPaso(i)` y `N.Compartido(clave, seg, fn)`: una sola lectura de la guía por segundo para Hoy, el rastreador y el Escritorio |
| `Eventos.lua` (1.3.5) | `N.DeUnidad(evento, unidades, fn)`, `N.Juntar(fn)` (una vez por cuadro), `N.PorPrefijo(prefijo, fn)` (un solo marco para los mensajes de addon, con el filtro de facción) |
| `Entrada.lua` (1.3.3) | Entrar en silencio: `N.Entrando`, `N.GuardarAlEntrar`, `N.AlEntrar` |
| `Momentos.lua` (1.3.7) | El orquestador: `N.Ocupado(tipo)`, `N.AlLibre(clave, fn, prioridad)`, `N.Perdido` («Lo que me perdí»), `N.Suceso/N.Visto` (un mensaje por suceso, 1.3.8), `N.Repeticion` (1.3.9) |
| `Faccion.lua` (1.3.8) | `N.ConFaccion`: todo lo de la Red de La Jauría lleva la marca de tu facción; lo de la otra no llega |
| `Errores.lua` (1.2.9) e `Informe.lua` (1.3.9) | Los errores de Alfa atrapados (`N.Errores`, 30 a lo más) y los datos técnicos del reporte (`N.InformeTecnico`: módulos, modo, memoria, tareas, otros addons; `N.SinPrivado`: sin tu nombre, tu reino ni el de otros) |
| `Kit/` | El kit visual de Alfa (`K.Ventana`, `K.Aviso`, `K.Anuncio`, `K.Pila`, `K.Texto`, `K.Parrafo`...): ver `docs/KIT.md` |

## Un ayudante por cosa: dónde vive cada uno (al día con la 1.4.0)

Antes de escribir un `local function` en un módulo, busca aquí si ya existe. Si lo que necesitas no está, súmalo al Núcleo (con su prueba) en vez de copiarlo en tu módulo.

| Para… | Usa | No hagas |
|---|---|---|
| Saber si un valor del juego es secreto | `N.Secreto(v)` | `v ~= nil`, `if v`, `v == x` antes de preguntar |
| Leer un valor que puede ser secreto | `N.Leer(v, otro)` | `N.Leer and N.Leer(v) or v`: el `or` devuelve el secreto (1.4.0: estaba en 5 archivos) |
| Un número del juego (nivel, vida, velocidad…) | `N.LeerNumero(v, otro)` (1.4.0) | `tonumber(UnitLevel("player"))`: en el juego `tonumber` de un secreto da el mismo secreto y compararlo truena |
| Un sí/no del juego | `N.Si(v)` / `N.SiJuego(fn, ...)` | `UnitAffectingCombat("player") == true` sin `N.Si` |
| Un número para medir marcos | `K.num(v, d)` (1.4.0: también descarta secretos) | `v or 0` con lo que devuelve un marco |
| Algo que se repite | `N.Cada / N.Una / N.Ticker / N.Quitar` (Reloj.lua) | `C_Timer.NewTicker`, un `OnUpdate` propio que no se esconde |
| Esperar al fin del combate | `N.FueraDeCombate(clave, fn)` | `PLAYER_REGEN_ENABLED` suelto en cada módulo |
| Esperar a que el jugador esté libre | `N.AlLibre(clave, fn, prioridad)` | avisos en medio de una pantalla de carga |
| Dinero, tiempo, plurales | `N.Dinero`, `N.Duracion`, `N.Plural` | formatos a mano |
| Un ícono | `K.Icono(p, "nombre")` con un nombre que exista en `Alfa/Media/UI` (`ic-*`, `sec-*`, `lobo-*` o los de siempre: `star`, `house`, `gear`…) | inventar `ic-algo`: sale un cuadro verde (`tools/texturas.py` lo revisa) |
| La variante del lobo | `K.Lobo("normal" \| "atento" \| "aullando" \| "dormido" \| "vacio")` | otra palabra (`"contento"` no existe) |
| Una tarea larga | `Tareas.Lanzar(clave, fn(ceder), fin)` (Rutas) / el trabajo por lotes de Enciclopedia | un bucle de miles de vueltas en un cuadro |
| Datos del Codex que pueden no estar leídos | `Indice.Cargado(grupo)` (Rutas, 1.4.0): un dato que falta porque su parte no está leída no es «no existe» | tomar un `nil` del Codex como «está en una mazmorra» |

Los `local function num(v)` que ya están en los módulos (unos 40, todos revisados en la 1.4.0: todos descartan secretos) se quedan; el código nuevo usa `N.LeerNumero`.

Dos detalles que el banco no ve y las herramientas sí:
- **Una función local usada antes de declararla** es un global `nil` en el juego («attempt to call a nil value»); en el banco, un global desconocido es un comodín que no truena. `tools/globales.py` lo encuentra en el bytecode (en la 1.4.0: `luego` en `Rutas/Rastreador.lua`, la X de las sugerencias; `gradient` en `Theme/Widgets.lua`).
- **Una textura que no existe** sale verde o vacía, sin error. `tools/texturas.py`.

## Datos guardados y sus topes

Todo lo que crece con el tiempo tiene un tope, para que entrar y salir del juego no se vuelva lento. Los de hoy (24/11/2026):

| Dónde | Tope |
|---|---|
| `AlfaNucleoDB.errores` (Errores.lua) | 30 errores distintos |
| `AlfaNucleoDB.comercio.reinos` (Comercio/Precios.lua) | los precios de más de 60 días se borran; un reino sin nada reciente, también |
| `AlfaNucleoDB.lya.historias` (Lya/Historias.lua) | 500 misiones y 450 000 letras |
| `AlfaNucleoCharDB.mazmorras.historial` (Mazmorras/BotinGrupo.lua) | 100 repartos de botín |
| `AlfaNucleoCharDB.pesca` (Pesca/Registro.lua) | 40 sesiones y 1500 pescas |
| `AlfaNucleoCharDB.momentos` (Momentos.lua) | 30 perdidos y 20 recientes |
| `AlfaNucleoCharDB.inicio.sesiones` (Inicio/Sesion.lua) | las últimas sesiones (`keep`) |
| buzón de reportes (Bienvenida/Reporte.lua) | 20 |

Para medir los de una cuenta de verdad: `tools/banco/prueba_139_calidad.lua` (la sesión larga de 3 horas falla si lo guardado crece más de 64 KB entre la hora 1 y la 3).

## Herramientas de calidad (tools/)

| Herramienta | Para qué |
|---|---|
| `build.py`, `revisar.py`, `humo.py`, `sintaxis.py` | Armar `dist/`, revisar sintaxis y TOC/XML, cargar todo con el juego simulado |
| `prueba.py` | La suite completa del banco: `prueba.lua`, cada `tools/banco/prueba_*.lua`, la galería (textos cortados), las guías diferidas, el tope de la entrada y la prueba visual. Termina con «RESULTADO: todo bien» |
| `escena.py` | Corre una o varias escenas del banco y enseña su salida |
| `perfil.py` | El perfil de la entrada y de un rato de juego (`--paginas`: cada página; `--veces N`: N corridas, el mínimo y la mediana). El mapa empieza cerrado, como en el juego |
| `regresion.py` (1.3.9) | Prueba visual: captura cada página y algunas ventanas (`tools/banco/vistas.lua`) y las compara pieza por pieza con `tools/banco/referencia/vistas.json.gz`; lo que cambió sale como AVISO VISUAL con una imagen lado a lado (`tools/banco/shot-dif-*.png`). `--aceptar` al cerrar una versión |
| `tools/banco/prueba_139_calidad.lua` | Todos los comandos `/alfa`, cada aviso en los 10 idiomas, el reporte sin datos privados, la sesión larga y la memoria de las páginas |
| `texturas.py` (1.4.0) | Cada textura nombrada con un texto fijo (`"ic-…"`, `K.Lobo("…")`, `MEDIA .. "…"`, `"Interface\\AddOns\\Alfa…\\Media\\…"`, `viaje-*`) existe en el build. Lo corren `revisar.py` y `prueba.py` |
| `globales.py` (1.4.0) | Globales por accidente, desde el bytecode de Lua 5.1: escritos sin `local` y leídos sin existir (una función local usada antes de declararla). Lo corren `revisar.py` y `prueba.py` |
| `tools/banco/prueba_140_dia.lua` (1.4.0) | Un día de juego, siete veces: entrar, guía, misiones, «Cerrar mis misiones», barco, recolección, combate y mazmorra con secretos, morir, bolsas, pesca, Dos pantallas, cada página, `/reload`, salir. Falla con un error, una acción que el juego bloquearía (marco seguro tocado en combate, función restringida, `SendChatMessage` solo) o si los marcos, ganchos, tareas del reloj, tickers u `OnUpdate` crecen del sexto al séptimo día. `BANCO_DIA_FUGAS=1` dice quién crea cada marco nuevo |

## Reglas de Forever (no negociables)

1. **Valores secretos:** en combate, en mazmorras y en encuentros, la vida, el poder, las auras, los lanzamientos y los nombres de otras unidades llegan "secretos". Con ellos no se puede hacer aritmética, comparar ni usarlos como índice. Se pueden mostrar con `StatusBar:SetValue` o `FontString:SetText`. Se comprueba con `issecretvalue(v)`. Los datos del propio jugador sí se pueden leer.
2. **No existe `COMBAT_LOG_EVENT`.** No hay medidores de daño ni avisos de jefes basados en el registro de combate.
3. **Nada de decisiones automáticas en combate.** Para la rotación se usa `C_AssistedCombat` (la ayuda oficial de Blizzard).
4. **Acciones protegidas** (lanzar, usar, interactuar, elegir objetivo): solo con una tecla o un clic del jugador, a través de `SecureActionButtonTemplate` o de `SetOverrideBinding*`, y fuera de combate (`InCombatLockdown()`).
5. **Mensajes de addon:** `C_ChatInfo.SendAddonMessage` no funciona dentro de instancias, y las cuentas de prueba no pueden enviarlos.
6. `C_Map.GetPlayerMapPosition` solo funciona para el jugador y su grupo.
7. La API de Forever vive en `referencia/wow-ui-source/Interface/AddOns/Blizzard_APIDocumentationGenerated/`, de la rama `forever` de Gethe/wow-ui-source. Si una función no aparece ahí, no se usa (salvo las globales clásicas que el motor ya usa, como `GetInventoryItemDurability`). Para más código de Blizzard: `git -C referencia/wow-ui-source sparse-checkout add Interface/AddOns/<carpeta>`.

## Código de terceros

- **Solo se reutiliza código o datos con licencia libre** (GPL o MIT), como el motor de Polestar (GPL-3.0, con datos de pfQuest MIT y otros). Todo código o archivo reutilizado lleva su aviso de licencia dentro de la carpeta del módulo (`LICENSE-<origen>.txt`) y una línea en `CREDITOS.md`, también dentro de la carpeta del módulo. Los créditos visibles van en «Acerca de».
- **Lo que no tiene licencia libre no se copia:** las funciones se escriben con código propio.
- **Ni el código ni los textos nombran a otros addons**, salvo esos avisos y créditos. Cuando un módulo necesita saber si hay otro addon cargado (para no chocar con él o para importar sus datos), los nombres técnicos van en una sola tabla en el `Compat.lua` del módulo (`M.OTROS`).

## Construir un módulo sin pisar a los demás

Varios módulos se construyen a la vez, así que cada uno usa su propia carpeta de salida con `ALFA_DIST`, desde la raíz del proyecto:

```bash
ALFA_DIST=dist-bolsas python -I tools/build.py
ALFA_DIST=dist-bolsas .venv/Scripts/python -I tools/revisar.py Alfa_Nucleo Alfa_Bolsas
ALFA_DIST=dist-bolsas .venv/Scripts/python -I tools/humo.py Alfa_Bolsas
rm -rf dist-bolsas      # al terminar
```

Los addons instalados están en `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\` y solo se leen, nunca se modifican.
