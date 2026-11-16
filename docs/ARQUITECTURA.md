# Arquitectura de Alfa

Alfa es un solo addon para WoW Forever (cliente 1.60.1, `## Interface: 16001`) hecho por Toxic / La Jauría. Junta en un solo lugar guías, mapa, bolsas, builds, curación, recolección, mazmorras, pesca, comercio y comodidades, sobre el motor de Polestar. Es software libre bajo la GPL-3.0.

## Cómo se construye

```
upstream/polestar-<v>/   Polestar publicado, bajado y verificado (no va en git)
src/Alfa_*/              módulos propios (sí van en git)
tools/                   fetch_upstream, build, renombrar, parches, revisar, humo
dist/                    lo que se instala en Interface/AddOns (no va en git)
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
## Author: Toxic - La Jauria
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
- **Archivos:** cada módulo toca solo su carpeta. Si necesita algo del motor o del núcleo que no existe, lo dice en su reporte en lugar de editar otra carpeta.

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
