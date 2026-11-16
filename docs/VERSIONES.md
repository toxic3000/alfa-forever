# Versiones de Alfa

Alfa es un addon para un juego masivo: cada versión publicada debe poder identificarse, reconstruirse y explicarse.

## Números

`MAYOR.MENOR.PARCHE` (versionado semántico):
- **MAYOR**: cambios grandes que rompen ajustes o cómo se usa (1.0.0 es la primera versión pública buena).
- **MENOR**: funciones nuevas que no rompen nada.
- **PARCHE**: correcciones.

La versión vive en un solo lugar, `tools/alfa.json` (`version`). `tools/build.py` la estampa en todos los `.toc`. Los jugadores comparan versiones entre sí, así que **nunca se baja el número**.

## Historial

| Versión | Fecha | Etiqueta en git | Qué fue |
|---|---|---|---|
| 0.1.0 | 16/11/2026 | `v0.1.0` | Primera beta interna, la que Toxic llama "0.5": 12 módulos sobre el motor de Polestar renombrado, interfaz con el diseño A. Probada en el juego sin errores. |
| 1.0.0 | (en curso) | `v1.0.0` | Interfaz propia con el Kit, ruta guiada, Enciclopedia, Talentos, Combate, La Jauría solo con usuarios de Alfa ([PLAN-1.0](PLAN-1.0.md)). |

## Cómo se publica una versión

1. Subir `version` en `tools/alfa.json` y agregar su sección a `CHANGELOG.md` (español e inglés).
2. `python -I tools/build.py`, `revisar.py`, `humo.py` y `textos.py estado` sin errores ni textos faltantes.
3. Probar en el juego con `tools/instalar.py --aplicar` (con WoW cerrado).
4. `python -I tools/empaquetar.py` → `paquetes/Alfa-<versión>.zip`.
5. Commit "Alfa <versión>", etiqueta `git tag -a v<versión> -m "Alfa <versión>"` y `git push --follow-tags`.
6. Subir el zip a CurseForge (Beta o Release) con las notas del `CHANGELOG.md`, y crear la versión en GitHub (Releases) con el mismo zip.
