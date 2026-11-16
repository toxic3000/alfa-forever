# Texturas de OpenMap que usa Alfa_Mundo

El código de Mundo funciona sin ellas: el mapa continuo se dibuja con el arte del propio juego (mundo, continentes y recuadros de exploración de cada zona). Con ellas gana detalle fino: el arte base de cada zona recortado a su forma y las ciudades con su borde. **No van en `src/`**: se integran en la construcción.

## De dónde salen

| | |
|---|---|
| Addon | OpenMap **v0.8.9** (`## Version: v0.8.9` en `OpenMap.toc`) |
| Licencia | Código MIT (`LICENSE-OpenMap.txt`). El arte es de Blizzard, como dice su `X-License` ("map art is Blizzard's") y su `Media/Textures/Forever/NOTICE.md` |
| Código fuente | https://github.com/openmap-world/openmap |
| CurseForge | proyecto 1735937 (`## X-Curse-Project-ID` en su `.toc`) |
| Copia instalada | `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\OpenMap\` |

## Qué se copia y a dónde

Origen: `OpenMap/Media/Textures/Forever/`. Destino: `Alfa_Mundo/Media/OpenMap/` (la ruta que usa el código: `Interface\AddOns\Alfa_Mundo\Media\OpenMap\...`, en `Lienzo.lua`).

| Carpeta o archivo | Tamaño | Para qué | Origen según su NOTICE.md |
|---|---|---|---|
| `MapTerritory/` (44 `.tga`: 1411-1452, 2482, 2521, 2548, 2652) | ~11 MB | Máscara del territorio de cada zona: recorta su arte base | Máscaras trazadas de cada mapa de zona (herramientas de OpenMap) |
| `MapCityMask/` (4 `.tga`: 1454, 1455, 1456, 1458) | ~1,1 MB | Recorta el mapa de Orgrimmar, Forjaz, Cima del Trueno y Entrañas | Máscaras trazadas sobre el arte |
| `MapFeatherRound.tga` | 260 KB | Borde redondo y suave de las otras ciudades; también sirve para saber si las texturas están | Generada por ruido (sin arte del juego) |
| `NOTICE.md` | 8 KB | Procedencia de las texturas, se conserva junto a ellas | — |

Total: unos 12,4 MB (de los ~361 MB de OpenMap). Si se cambia la lista de `TERRITORIOS` o `CIUDAD_MASCARA` en `Lienzo.lua`, hay que cambiar esta tabla.

## Lo que NO se copia

- `MapGapFill/`, `MapChart/` y `MapDungeonDrawn/`: dibujados a mano por Santiago Reyes, usados por OpenMap con su permiso y **fuera de la licencia MIT** (lo dice su NOTICE.md). Tampoco `MapZones/`, que los incluye horneados.
- `OpenMapIcon*.tga`: dibujo de zloyeb con permiso solo para OpenMap.
- Todo lo demás (mar, costas, LOD del minimapa, cuevas, etc.): Mundo no lo usa.

## Comprobación

La primera vez que lo necesita, Mundo pone `MapFeatherRound` en una textura de prueba: si el cliente responde que no existe, se queda con el arte del juego y la página Mundo lo dice ("Las texturas de OpenMap no están..."). El ajuste "Detalle fino de cada zona" (`mundo.detalle`) apaga el detalle aunque estén.
