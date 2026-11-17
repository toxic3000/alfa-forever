# Versiones de Alfa

Alfa es un addon para un juego masivo: cada versión publicada debe poder identificarse, reconstruirse y explicarse.

## Números

`MAYOR.MENOR.PARCHE` (versionado semántico):
- **MAYOR**: cambios grandes que rompen ajustes o cómo se usa (1.0.0 es la primera versión pública buena).
- **MENOR**: funciones nuevas que no rompen nada.
- **PARCHE**: correcciones.

Regla de Toxic desde la 1.0.0 (16/11/2026): **cada cambio publicado sube el PARCHE** (1.0.1, 1.0.2, ...). Cuando un cambio es más grande, se decide con él si pasa a la siguiente MENOR (1.1.0) y desde ahí se sigue con 1.1.1, 1.1.2, etc.

La versión vive en un solo lugar, `tools/alfa.json` (`version`). `tools/build.py` la estampa en todos los `.toc`. Los jugadores comparan versiones entre sí, así que **nunca se baja el número**.

## Historial

| Versión | Fecha | Etiqueta en git | Qué fue |
|---|---|---|---|
| 0.1.0 | 16/11/2026 | `v0.1.0` | Primera beta interna, la que Toxic llama "0.5": 12 módulos sobre el motor de Polestar renombrado, interfaz con el diseño A. Probada en el juego sin errores. |
| 1.0.0 | 16/11/2026 | `v1.0.0` | Probada en el juego sin errores. Interfaz propia con el Kit, ruta guiada, Enciclopedia, Talentos, Combate, La Jauría solo con usuarios de Alfa ([PLAN-1.0](PLAN-1.0.md)). |

## Cómo se publica una versión

1. Subir `version` en `tools/alfa.json` y agregar su sección a `CHANGELOG.md` (español e inglés).
2. Repasar `docs/REGLAS-BLIZZARD.md` (sin donaciones ni anuncios en el juego, nada que escriba solo en el chat de otros, créditos al día).
3. `python -I tools/build.py`, `revisar.py`, `humo.py` y `textos.py estado` sin errores ni textos faltantes.
   Después, `python -I tools/prueba.py`: usa Alfa como un jugador en el banco (la bienvenida completa, todas las páginas en los 3 estilos, el mapa con zoom, arrastre, inercia, bordes, capas y cambio de tamaño, las ventanas de cada módulo, Lya, combate y eventos) y revisa que ningún texto salga cortado. Tiene que decir `RESULTADO: todo bien`. El banco se comporta como el juego en lo que ya nos mordió (un texto sin letra es error, el mapa tiene arte, el chat y el minimapa existen); si sale un error nuevo del juego real, primero se agrega al banco para que la prueba lo atrape y después se arregla.
4. Probar en el juego con `tools/instalar.py --aplicar` (con WoW cerrado).
5. `python -I tools/empaquetar.py` → `paquetes/Alfa-<versión>.zip`.
6. Commit "Alfa <versión>", etiqueta `git tag -a v<versión> -m "Alfa <versión>"` y `git push --follow-tags`.
7. Subir el zip a CurseForge (Beta o Release) con las notas del `CHANGELOG.md`, y crear la versión en GitHub (Releases) con el mismo zip **y `paquetes/Instalar-Alfa.exe`** (`python -I instalador/construir.py`). El enlace del instalador apunta siempre a la última versión publicada, así que las dos cosas tienen que ir en cada una.
8. Avisar a la manada: `python -I tools/anunciar.py version <versión>` publica la sección del CHANGELOG en #wow-addon-alfa-actualizaciones del Discord de La Jauría con el bot Jesus GPT (sin menciones). Necesita `tools/anunciar_local.json`, que no se sube a git.
