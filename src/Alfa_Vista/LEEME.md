# Alfa - Paisaje y gráficos (`Alfa_Vista`)

Hace que el mundo se vea mejor: muestra los ajustes de gráficos que el menú del juego esconde, trae preajustes, ajusta la cámara, las placas de nombre y el texto de combate, y suma filtros propios (viñeta, grano, barras de cine y tintes). Código propio de Alfa (GPL-3.0).

## Dónde está

- **Ventana completa:** `/alfa paisaje` (o `/alfa graficos`), y el botón «Abrir Paisaje y gráficos» de su página. Pestañas: Calidad, Entorno, Cámara, Interfaz, Filtros y Avanzado, con un buscador que busca en todas (también en inglés y por el nombre de la variable).
- **Página:** Mundo > Paisaje y gráficos. El estado (como el juego, a tu gusto o el preajuste puesto), los preajustes en tarjetas y atajos: viñeta, grano, barras, tinte, quitar la niebla del horizonte, placas de mascotas y tótems enemigos, y volver a poner tus valores al entrar.

## Cada fila

- El control (deslizador, interruptor o lista) muestra **el valor que el juego de verdad aplicó**: después de escribir, Alfa vuelve a leer la variable. Si el juego la limitó, la fila lo dice («Pediste 2.6; el juego lo dejó en 2»).
- Los deslizadores traen un **campo para escribir el valor exacto** (Enter lo aplica; acepta coma o punto).
- **Por defecto** pone el valor de fábrica del juego (`C_CVar.GetCVarInfo` / `GetCVarDefault`) y Alfa deja de mantenerla.
- **Marca a la izquierda:** verde, Alfa la mantiene; gris, la cambió otra cosa (menú del juego o consola); amarilla, espera a que termine el combate.
- **Estrella dorada:** también está en el menú de opciones del juego.
- Las filas que dependen de otra (la calidad de la niebla de la niebla volumétrica, las mascotas enemigas de las placas de enemigos, el HDR...) se atenúan cuando la de arriba está apagada.
- Al pasar el ratón: el nombre de la variable, su valor ahora y el de fábrica.

## Cómo se porta

- **Al instalar no cambia nada:** solo lee. Hasta que tocas un control, Alfa no escribe ninguna variable (el banco de pruebas lo comprueba: 0 escrituras al entrar y al recorrer la ventana).
- **Variables que el cliente no tiene, bloqueadas o de solo lectura** se ocultan y nunca se escriben (se pregunta con `C_CVar.GetCVarInfo`). La ventana dice cuántas faltan.
- **En combate no se toca nada:** lo que pidas (también un preajuste) espera y se aplica al salir (`N.FueraDeCombate`); la ventana y la fila lo dicen. Las placas de mascotas, guardianes, tótems, menores y su distancia son variables «seguras»: el juego solo deja cambiarlas fuera de combate.
- **Al entrar** (3 s después de `PLAYER_ENTERING_WORLD`, cuando el juego terminó de aplicar sus opciones), si «Volver a poner mis valores al entrar» está encendido, Alfa revisa los valores que elegiste y vuelve a poner los que algo cambió. La distancia de la cámara se salta si «Alejar más la cámara» de Comodidades está encendido (esa opción manda).
- **Sigue al juego:** si después cambias una de esas variables en el menú del juego o con `/console` (`CVAR_UPDATE`, y al abrir la ventana), Alfa se queda con el valor nuevo en lugar de pelear.
- **Deshacer** (pie de la ventana y enlace de Preajustes) devuelve los valores de antes del último preajuste. **Todo como estaba antes de Alfa** (Avanzado > Herramientas, con confirmación) devuelve cada variable que Alfa tocó al valor que tenía antes.
- **Reiniciar gráficos** (`RestartGx`, con confirmación y fuera de combate): en Avanzado > Herramientas, y en el pie de la ventana cuando cambiaste algo que lo necesita (el HDR).
- **Rendimiento:** nada se crea hasta abrir la ventana o encender un filtro; al entrar solo se leen y, si hace falta, se escriben las variables elegidas. Mover un deslizador aplica el valor un cuarto de segundo después de soltarlo (no en cada cuadro).

## Preajustes

Solo tocan gráficos: nunca cámara, ratón ni interfaz. Tocan 27 variables (distancia, horizonte, detalle de terreno, edificios y objetos, pasto, niebla, sombras, oclusión, rayos de sol, agua, partículas, clima, texturas proyectadas y filtrado de texturas); las que el cliente no tenga se saltan.

| Preajuste | Para qué |
|---|---|
| Bajo | Equipos modestos o peleas grandes: distancia 600, sin sombras, sin niebla volumétrica, pasto mínimo |
| Medio | Equilibrado, cerca de lo que trae el juego: distancia 1000, sombras medias |
| Alto | Distancia 2000, sombras finas y suaves, agua con reflejos, pasto 128 |
| Ultra | Todo al máximo seguro: distancia 4000, sombras ultra, oclusión ultra, pasto 256, agua 3 (nunca más) |
| Paisaje de la manada (firma de Alfa) | Bonito sin pedir de más: distancia 2600, horizonte hasta 4400, pasto 192 a 220 de distancia, niebla del horizonte quitada y niebla volumétrica ligera, rayos de sol, sombras altas, agua 2 |

Los números exactos están en `Datos.lua` (`COLUMNAS`).

## Filtros

Los dibuja Alfa, no el juego (ninguna variable). Son texturas a pantalla completa en un marco hijo de `WorldFrame`, capa `BACKGROUND`, nivel 0, sin ratón: quedan encima del paisaje y **detrás de toda la interfaz**, y siguen con la interfaz oculta (Alt+Z), para capturas.

- **Viñeta** (`Media/vineta.tga`, 512×512) con su fuerza.
- **Grano de película** (`Media/grano.tga`, 256×256, se repite sin costura) con su fuerza; «En movimiento» corre sus coordenadas a un lugar al azar unas 14 veces por segundo con un `OnUpdate` que solo existe mientras el grano está encendido y a la vista.
- **Barras de cine** arriba y abajo (2 a 20 % del alto). Solo cambian cómo se ve: no dan más FPS.
- **Tintes:** sepia, cálido, frío, noche, esmeralda (el verde de La Jauría) y atardecer, con su fuerza. Multiplican el mundo por un color (`SetBlendMode("MOD")`) y algunos suman un velo. Cada uno tiene su miniatura (`Media/tinte-*.tga`) dibujada con la misma cuenta.

Las texturas son TGA de 32 bits sin compresión dibujadas con Pillow (con `vista_medios.py`, que todavía no está en `tools/`).

## API

```lua
AlfaVista.Abrir()                 -- abre la ventana (si la bienvenida ya terminó: N.Permitido)
AlfaVista.AplicarPreset(nombre)   -- "bajo" | "medio" | "alto" | "ultra" | "manada" (o su nombre visible)
                                  -- -> true, "ok" | "espera" (en combate) ; false, motivo
AlfaVista.Presets()               -- { { id, nombre, texto, icono }, ... }
AlfaVista.Deshacer()              -- lo de antes del último preajuste -> true | false
```

`AplicarPreset` funciona aunque la bienvenida no haya terminado (la bienvenida puede preguntar «Mejorar el paisaje»).

## Datos

- Ajustes (`AlfaDB.settings.vista`): `reaplicar`, `vineta`, `vinetaFuerza`, `grano`, `granoFuerza`, `granoMover`, `barras`, `barrasAlto`, `tinte`, `tinteFuerza`.
- `N.Datos("vista")`: `valores` (lo que elegiste, como quedó en el juego), `originales` (lo de antes de Alfa), `deshacer`, `ultimoPreset`, `reinicio`, `pestana`.

## Las variables y de dónde salen

Todas existen en el cliente de Forever 1.60.1 (70938) según el volcado de variables de ese cliente (`Resources/CVars.lua` de la rama `forever` de Ketho/BlizzardInterfaceResources, que da nombre, valor de fábrica y si es «segura»). Las que también están en el menú del juego se confirmaron en el código de la interfaz de Blizzard (rama `forever` de Gethe/wow-ui-source, carpetas `Blizzard_SettingsDefinitions_Shared` y `Blizzard_SettingsDefinitions_Frame`, que en Forever carga los archivos `Camelot/`). Los rangos que da Blizzard se usan tal cual (filtrado 0 a 5, nitidez 0 a 2 al revés, distancia de cámara 1 a 2 en el menú, modo de la cámara 0/1/2/4, texto de combate 1 a 3; y de la ayuda de la variable: sombras 0 a 3, capas 1 a 4, niebla 0 a 3); los demás los eligió Alfa a partir del valor de fábrica, y el juego puede limitarlos (Alfa muestra lo que quedó). En el juego, además, cada una se comprueba con `C_CVar.GetCVarInfo` antes de mostrarla.

| Variable | Pestaña / grupo | Rango en Alfa | De fábrica | Fuente |
|---|---|---|---|---|
| `shadowMode` | calidad / Sombras | lista | 0 | dump 1.60.1 |
| `shadowTextureSize` | calidad / Sombras | lista | 1024 | dump 1.60.1 |
| `shadowNumCascades` | calidad / Sombras | 1 a 4 (paso 1) | 1 | dump 1.60.1 |
| `shadowBlendCascades` | calidad / Sombras | 0 / 1 | 0 | dump 1.60.1 |
| `shadowSoft` | calidad / Sombras | 0 / 1 | 0 | dump 1.60.1 |
| `SSAO` | calidad / Luz y efectos | lista | 0 | dump 1.60.1 |
| `particleDensity` | calidad / Luz y efectos | 10 a 100 (paso 5) | 100 | dump 1.60.1 |
| `projectedTextures` | calidad / Luz y efectos | 0 / 1 | 0 | dump 1.60.1 |
| `textureFilteringMode` | calidad / Texturas y nitidez | lista | 5 | dump 1.60.1; men� del juego: Graphics.lua |
| `ResampleAlwaysSharpen` | calidad / Texturas y nitidez | 0 / 1 | 0 | dump 1.60.1 |
| `ResampleSharpness` | calidad / Texturas y nitidez | 0 a 2 (paso 0.1) | 0.2 | dump 1.60.1; men� del juego: Graphics.lua |
| `farclip` | entorno / Distancia | 300 a 8000 (paso 50) | 1000 | dump 1.60.1 |
| `horizonStart` | entorno / Distancia | 200 a 8000 (paso 50) | 800 | dump 1.60.1 |
| `horizonClip` | entorno / Distancia | 400 a 10000 (paso 100) | 1600 | dump 1.60.1 |
| `terrainLodDist` | entorno / Distancia | 100 a 1000 (paso 25) | 400 | dump 1.60.1 |
| `wmoLodDist` | entorno / Distancia | 100 a 1000 (paso 25) | 300 | dump 1.60.1 |
| `doodadLodScale` | entorno / Distancia | 25 a 200 (paso 5) | 100 | dump 1.60.1 |
| `lodObjectCullSize` | entorno / Distancia | 1 a 40 (paso 1) | 15 | dump 1.60.1 |
| `lodObjectFadeScale` | entorno / Distancia | 50 a 300 (paso 10) | 100 | dump 1.60.1 |
| `groundEffectDensity` | entorno / Vegetaci�n | 16 a 256 (paso 8) | 16 | dump 1.60.1 |
| `groundEffectDist` | entorno / Vegetaci�n | 30 a 600 (paso 10) | 70 | dump 1.60.1 |
| `disableHorizonStart` | entorno / Niebla | 0 / 1 | 0 | dump 1.60.1 |
| `volumeFog` | entorno / Niebla | 0 / 1 | 1 | dump 1.60.1 |
| `volumeFogLevel` | entorno / Niebla | lista | 3 | dump 1.60.1 |
| `volumeFogInterior` | entorno / Niebla | 0 / 1 | 1 | dump 1.60.1 |
| `waterDetail` | entorno / Agua | lista | 0 | dump 1.60.1 |
| `reflectionMode` | entorno / Agua | lista | 3 | dump 1.60.1 |
| `rippleDetail` | entorno / Agua | lista | 2 | dump 1.60.1 |
| `refraction` | entorno / Agua | 0 / 1 | 0 | dump 1.60.1 |
| `sunShafts` | entorno / Cielo y clima | lista | 0 | dump 1.60.1 |
| `weatherDensity` | entorno / Cielo y clima | lista | 2 | dump 1.60.1 |
| `cameraDistanceMaxZoomFactor` | camara / Distancia y velocidad | 1 a 2.6 (paso 0.1) | 1.000000 | dump 1.60.1; men� del juego: Camelot/ControlsOverrides.lua |
| `cameraZoomSpeed` | camara / Distancia y velocidad | 1 a 50 (paso 1) | 20.000000 | dump 1.60.1 |
| `cameraFov` | camara / Distancia y velocidad | 50 a 90 (paso 1) | 90.000000 | dump 1.60.1; men� del juego: Graphics.lua |
| `cameraSmoothStyle` | camara / Seguimiento | lista | 4 | dump 1.60.1; men� del juego: Controls.lua |
| `cameraTerrainTilt` | camara / Seguimiento | 0 / 1 | 0 | dump 1.60.1; men� del juego: Camelot/ControlsOverrides.lua |
| `cameraBobbing` | camara / Seguimiento | 0 / 1 | 0 | dump 1.60.1; men� del juego: Camelot/ControlsOverrides.lua |
| `cameraPivot` | camara / Seguimiento | 0 / 1 | 1 | dump 1.60.1; men� del juego: Camelot/ControlsOverrides.lua |
| `cameraIndirectVisibility` | camara / Choques de la c�mara | 0 / 1 | 1 | dump 1.60.1 |
| `cameraIndirectOffset` | camara / Choques de la c�mara | 1 a 10 (paso 0.5) | 6.000000 | dump 1.60.1 |
| `cameraWaterCollision` | camara / Choques de la c�mara | 0 / 1 | 0 | dump 1.60.1; men� del juego: Controls.lua |
| `nameplateMaxDistance` | interfaz / Placas de nombre | 10 a 60 (paso 1) | 45.000000 | dump 1.60.1 (segura: solo fuera de combate) |
| `nameplateShowEnemies` | interfaz / Placas de nombre | 0 / 1 | 0 | dump 1.60.1; men� del juego: Nameplates.lua |
| `nameplateShowEnemyPets` | interfaz / Placas de nombre | 0 / 1 | 0 | dump 1.60.1 (segura: solo fuera de combate) |
| `nameplateShowEnemyGuardians` | interfaz / Placas de nombre | 0 / 1 | 0 | dump 1.60.1 (segura: solo fuera de combate) |
| `nameplateShowEnemyTotems` | interfaz / Placas de nombre | 0 / 1 | 0 | dump 1.60.1 (segura: solo fuera de combate) |
| `nameplateShowEnemyMinions` | interfaz / Placas de nombre | 0 / 1 | 0 | dump 1.60.1; men� del juego: Nameplates.lua |
| `nameplateShowEnemyMinus` | interfaz / Placas de nombre | 0 / 1 | 0 | dump 1.60.1; men� del juego: Nameplates.lua (segura: solo fuera de combate) |
| `enableFloatingCombatText` | interfaz / Texto de combate flotante | 0 / 1 | 0 | dump 1.60.1; men� del juego: Mainline/CombatOverrides.lua |
| `floatingCombatTextFloatMode_v2` | interfaz / Texto de combate flotante | lista | 1 | dump 1.60.1; men� del juego: Mainline/CombatOverrides.lua |
| `floatingCombatTextCombatDamage_v2` | interfaz / Texto de combate flotante | 0 / 1 | 1 | dump 1.60.1; men� del juego: Mainline/CombatOverrides.lua |
| `floatingCombatTextCombatLogPeriodicSpells_v2` | interfaz / Texto de combate flotante | 0 / 1 | 1 | dump 1.60.1; men� del juego: Mainline/CombatOverrides.lua |
| `floatingCombatTextPetMeleeDamage_v2` | interfaz / Texto de combate flotante | 0 / 1 | 1 | dump 1.60.1 |
| `floatingCombatTextPetSpellDamage_v2` | interfaz / Texto de combate flotante | 0 / 1 | 1 | dump 1.60.1 |
| `floatingCombatTextCombatDamageDirectionalScale_v2` | interfaz / Texto de combate flotante | 0 a 3 (paso 0.1) | 0.000000 | dump 1.60.1 |
| `floatingCombatTextCombatHealing_v2` | interfaz / Texto de combate flotante | 0 / 1 | 1 | dump 1.60.1; men� del juego: Mainline/CombatOverrides.lua |
| `worldBaseMip` | avanzado / Detalle fino | lista | 0 | dump 1.60.1 |
| `terrainMipLevel` | avanzado / Detalle fino | lista | 0 | dump 1.60.1 |
| `DepthBasedOpacity` | avanzado / Detalle fino | 0 / 1 | 1 | dump 1.60.1 |
| `ffxGlow` | avanzado / Efectos de pantalla del juego | 0 / 1 | 1 | dump 1.60.1 |
| `ffxDeath` | avanzado / Efectos de pantalla del juego | 0 / 1 | 1 | dump 1.60.1 |
| `ffxNether` | avanzado / Efectos de pantalla del juego | 0 / 1 | 1 | dump 1.60.1 |
| `HDROutput` | avanzado / HDR (Windows) | 0 / 1 | 0 | dump 1.60.1 |
| `HDRFactor` | avanzado / HDR (Windows) | 1 a 4 (paso 0.1) | 2.000000 | dump 1.60.1 |
| `useHDRPeakBrightness` | avanzado / HDR (Windows) | 0 / 1 | 0 | dump 1.60.1 |
| `HDRPeakBrightness` | avanzado / HDR (Windows) | 200 a 2000 (paso 50) | 400 | dump 1.60.1 |
| `useHDRBrightness` | avanzado / HDR (Windows) | 0 / 1 | 0 | dump 1.60.1 |
| `HDRBrightness` | avanzado / HDR (Windows) | 80 a 500 (paso 5) | 203 | dump 1.60.1 |

Además: `CVAR_UPDATE` (evento, `ConsoleDocumentation.lua`), `C_CVar.GetCVar`, `GetCVarInfo`, `GetCVarDefault`, `SetCVar`, `AreCVarsLoaded` (`CVarDocumentation.lua`) y `RestartGx` (`ClientDocumentation.lua`), todas en `Blizzard_APIDocumentationGenerated` de la rama `forever`.

## Probar en el juego

- **Que no truene nada al subir:** `farclip` (hasta 8000), `horizonClip` (hasta 10000), `groundEffectDensity` 256 y `groundEffectDist` 600 al máximo; mirar los FPS y si el juego los limita (la fila lo dice).
- **Qué variables limita o ignora Forever:** `cameraDistanceMaxZoomFactor` arriba de 2 (el menú llega a 2), `nameplateMaxDistance` arriba de 45, `farclip` contra la «Distancia de visión» del menú, `SSAO` 4 y `sunShafts` 2.
- **Agua:** `waterDetail` 3 y `reflectionMode` 3 juntos (Alfa no deja pasar de 3; valores mayores cierran el juego en otros clientes).
- **HDR:** solo con monitor HDR; `HDROutput` necesita «Reiniciar gráficos».
- **Filtros:** que queden detrás de la interfaz y de las placas de nombre, que el tinte «MOD» se vea bien de noche y de día, y que el grano no se note en los FPS.
- **Combate:** cambiar algo y aplicar un preajuste en combate (debe esperar y aplicarse al salir, sin errores de acción bloqueada).
- **Entrar y `/reload`:** con valores elegidos, que vuelvan después de cargar; luego cambiar uno en el menú del juego y ver que Alfa lo adopta (marca gris → verde con el nuevo valor).
- El texto de combate sobre tu personaje puede necesitar `/reload` la primera vez que se enciende.
