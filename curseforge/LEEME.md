# Subir Alfa a CurseForge

Lo que hay en esta carpeta:

- `descripcion.md`: la descripción del proyecto (español, inglés y una línea en cada idioma). Se pega en "Description" en modo Markdown.
- `avatar.png`: el logo del proyecto, en 400x400.
- `galeria/`: las imágenes para la pestaña "Images" (portada + 8 vistas, 1600x1000). Se arman con `tools/galeria.py` (ver abajo).
- El zip se arma con `python -I tools/build.py` y luego `python -I tools/empaquetar.py`, y queda en `paquetes/Alfa-<versión>.zip`.

## Datos para crear el proyecto

| Campo | Valor |
|---|---|
| Game | World of Warcraft |
| Name | **Alfa Forever**, para que la dirección sea `curseforge.com/wow/addons/alfa-forever`, que es la que ya usa el addon para reportes y versiones |
| Summary | El todo en uno para WoW Forever, hecho por toxic3000 / The all-in-one for WoW Forever, by toxic3000 |
| Main category | Quests & Leveling |
| Additional categories | Map & Minimap, Bags & Inventory, Auction & Economy, Professions, Dungeons & Raids, Healer, Guild |
| License | GNU General Public License version 3 (GPLv3) |
| Source / Issues | https://github.com/toxic3000/alfa-forever y https://github.com/toxic3000/alfa-forever/issues (la GPL pide que el código esté disponible) |
| Logo | `avatar.png` |

## Subir un archivo

| Campo | Valor |
|---|---|
| File | `paquetes/Alfa-<versión>.zip` |
| Display name | `Alfa <versión>` |
| Release type | **Beta** mientras no se haya probado a fondo en el juego |
| Game version | La de WoW Forever (1.60.1, interfaz 16001) |
| Changelog | La sección de esa versión en `CHANGELOG.md` |

El proyecto ya existe: **https://www.curseforge.com/wow/addons/alfa-forever** (número **1811544**, creado el 16/11/2026 con la cuenta toxic3000). El número ya está en `tools/alfa.json` como `X-Curse-Project-ID` y sale a partir de la 1.0.1. La 1.0.0 se subió como Beta, para 1.60.1, y queda pendiente de la revisión de CurseForge.

Para subir una versión nueva: en el panel de autores, proyecto Alfa Forever, pestaña **Files**, suelta `paquetes/Alfa-<versión>.zip`, nombre `Alfa <versión>`, versión de juego 1.60.1, el tipo que toque y las notas del CHANGELOG.

## Imágenes de la galería

`curseforge/galeria/` tiene la portada (`00-portada.png`, la que conviene marcar como destacada) y 8 vistas de la 1.0: Hoy, el asistente, la ruta, la biblioteca de guías, la enciclopedia, mazmorras, bolsas y La Jauría. En cada imagen, el título va en "Title" y la línea de abajo en "Description".

Salen del código real de Alfa dibujado en el banco de pruebas (`tools/banco/`), con un personaje de ejemplo ("Lobato") y sin ningún dato tuyo. Lo único que el banco no tiene es el arte del juego (íconos de objetos y retratos de mazmorras), que se ve como una ficha con un rombo.

Para rehacerlas:

```bash
python -I tools/build.py
.venv/Scripts/python -I tools/banco/run.py dist Alfa,Alfa_esMX,Alfa_Nucleo,Alfa_Guides,Alfa_Guides_Horde,Alfa_Guides_Orc,Alfa_Codex,Alfa_ItemDB,Alfa_QuestDB,Alfa_Nav,Alfa_Nav_Kalimdor,Alfa_Inicio,Alfa_Rutas,Alfa_Enciclopedia,Alfa_Builds,Alfa_Bolsas,Alfa_Manada,Alfa_Mazmorras,Alfa_Mundo,Alfa_Comodidades,Alfa_Comercio,Alfa_Recoleccion,Alfa_Pesca,Alfa_Combate,Alfa_Curacion,Alfa_Bienvenida galeria.lua
.venv/Scripts/python -I tools/galeria.py
```

Capturas del juego: ponlas en `curseforge/capturas/` con un nombre como `01-mapa_del_mundo.jpg` y `tools/galeria.py` las enmarca igual (`galeria/juego-*.png`). Antes de subirlas, revisa que no se vean el nombre de tu personaje, tu reino ni tu chat si no quieres que aparezcan.
