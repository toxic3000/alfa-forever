# Idiomas de Alfa

Alfa se escribe en español y viene en 9 idiomas: español, inglés, alemán (deDE), francés (frFR), portugués de Brasil (ptBR), ruso (ruRU), coreano (koKR), chino simplificado (zhCN) y chino tradicional (zhTW). El motor (lo que viene de Polestar) trae sus propias traducciones; los módulos de Alfa usan las de esta carpeta.

## Cómo funciona

- Cada módulo escribe sus textos en español y trae su inglés en `Textos.lua` (`M.EN`). Los consejos de Mazmorras traen el par `{ español, inglés }`.
- `tools/textos.py fuente` reúne todo en `textos/fuente.json`.
- Las traducciones están en `textos/<locale>/*.json`, como `{ "texto en español": "traducción" }`.
- `tools/textos.py estado` dice cuánto falta en cada idioma y qué está mal.
- `tools/textos.py generar` escribe `src/Alfa_Nucleo/Idiomas/<locale>.lua`. Cada archivo solo se carga en un cliente de ese idioma.

Una traducción se descarta si no conserva exactamente los huecos `%s`/`%d` **en el mismo orden** (el `string.format` de Lua no permite reordenarlos), los colores `|c…|r`, las texturas `|T…|t`, los enlaces `|H…|h` y los saltos de línea.

## Corregir una traducción

1. Busca el texto en `textos/<locale>/` y cambia solo la traducción, nunca la clave en español.
2. Corre `tools/textos.py estado` y luego `tools/textos.py generar`.
3. Abre un Issue o un pull request en https://github.com/toxic3000/alfa-forever, o avísanos en el Discord de La Jauría.

## Para que revise alguien nativo

Las traducciones las hizo una IA con los términos del cliente de cada idioma y del motor. Estas son las dudas que dejaron los traductores:

- **Todos los idiomas:** nombres de habilidades clásicas de guerrero (Embate, Golpes de barrido, Muro de escudo, Último recurso, Deseo de muerte, Ataque victorioso…) y de otras clases (Forma de lechúcico lunar, Mordedura de mangosta, Transfusión de vida); los nombres de funciones nuevas de Blizzard (clic para lanzar, línea de tiempo de jefes, ayuda de combate); y los nombres de estilos y builds de Alfa.
- **Claves que comparten dos clases:** "Protección" (guerrero / paladín) y "Restauración" (druida / chamán) tienen nombres distintos en coreano y otros idiomas. Hay que separarlas en el español.
- **Fechas:** "el %d/%d a las %s" va con el orden día/mes del español; en coreano y chino se lee al revés.
- **frFR:** "Stormwind" o "Hurlevent", y Polestar usa otros nombres para algunos talentos ("Coup mortel", "Lacération").
- **zhCN:** "Asesinato" como 刺杀 o 奇袭; "Forever" sin traducir (Polestar usa 无限).
- **zhTW:** 主要/次要 frente a 主手/副手 en el temporizador de golpe.
- **ruRU:** los plurales van como "Заданий: %d". La búsqueda de Bolsas con mayúscula inicial no encuentra nada en cirílico (pendiente en `docs/PLAN.md`).
- **deDE:** "Ruhebonus", "Fokusmodus", "Vorkommen" y "Klickzauber".
- **ptBR:** varios hechizos quedaron en inglés (Slam, Shield Wall, Last Stand…) a la espera del nombre oficial.
