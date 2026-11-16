# Subir Alfa a CurseForge

Lo que hay en esta carpeta:

- `descripcion.md`: la descripción del proyecto (español, inglés y una línea en cada idioma). Se pega en "Description" en modo Markdown.
- `avatar.png`: el logo del proyecto, en 400x400.
- El zip se arma con `python -I tools/build.py` y luego `python -I tools/empaquetar.py`, y queda en `paquetes/Alfa-<versión>.zip`.

## Datos para crear el proyecto

| Campo | Valor |
|---|---|
| Game | World of Warcraft |
| Name | **Alfa Forever**, para que la dirección sea `curseforge.com/wow/addons/alfa-forever`, que es la que ya usa el addon para reportes y versiones |
| Summary | El todo en uno de La Jauría para WoW Forever / The all-in-one for WoW Forever |
| Main category | Quests & Leveling |
| Additional categories | Map & Minimap, Bags & Inventory, Auction & Economy, Professions, Dungeons & Raids, Healer, Guild |
| License | GNU General Public License version 3 (GPLv3) |
| Source / Issues | El repositorio público de GitHub (la GPL pide que el código esté disponible) |
| Logo | `avatar.png` |

## Subir un archivo

| Campo | Valor |
|---|---|
| File | `paquetes/Alfa-<versión>.zip` |
| Display name | `Alfa <versión>` |
| Release type | **Beta** mientras no se haya probado a fondo en el juego |
| Game version | La de WoW Forever (1.60.1, interfaz 16001) |
| Changelog | La sección de esa versión en `CHANGELOG.md` |

Cuando CurseForge asigne el número del proyecto, va en `tools/alfa.json` como `X-Curse-Project-ID` dentro de `toc`, para que la app de CurseForge lo reconozca.
