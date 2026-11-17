# Alfa y las reglas de Blizzard para addons

Blizzard publica una política para addons de World of Warcraft (*UI Add-On Development Policy*, foro oficial: https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534). Alfa la cumple así. **Antes de publicar cada versión se repasa esta lista** (paso de `docs/VERSIONES.md`).

| # | Regla | Cómo la cumple Alfa |
|---|---|---|
| 1 | Gratis, sin versiones de pago ni servicios cobrados | Alfa es gratis y GPL-3.0. Nada se desbloquea pagando. |
| 2 | Código visible, nunca oculto ni ofuscado | Todo el código es Lua legible y está en GitHub. Los archivos grandes de `Alfa_Nav`, `Alfa_Codex` y las guías son **datos** (tablas), no código escondido. |
| 3 | No dañar a otros jugadores ni saturar el chat | Nada escribe solo en canales públicos. El avance de misiones en el chat del grupo viene **apagado** (`party.chat`) y la bienvenida lo pregunta. El top 10 del medidor solo se manda con tu clic. Los mensajes entre usuarios de Alfa son mensajes de addon (ocultos), con freno, y nunca dentro de instancias. |
| 4 | Sin anuncios de productos o servicios | Alfa no anuncia nada. El enlace al Discord de La Jauría es la comunidad del addon (reportes y ayuda), discreto y sin promociones. |
| 5 | Sin pedir donaciones dentro del addon | **Dentro del juego no hay donaciones.** El botón de donar vive solo en CurseForge, GitHub y el Discord. |
| 6 | Sin contenido ofensivo (clasificación T) | Textos y arte aptos para todo el público. |
| 7 | Cumplir los Términos de Uso y el EULA | Nada juega por ti: lo que actúa necesita tu tecla o tu clic (curar, pescar, talentos, objetos), fuera de combate cuando el juego lo pide. La ayuda de rotación solo sugiere. La automatización de misiones, vender y reparar usa funciones que el juego permite a los addons. |
| 8 | Blizzard puede desactivar funciones | Alfa se adapta: si una API no responde (valores secretos, funciones apagadas en Forever), la función se apaga sola sin errores. |

## Licencias y créditos

- Alfa conserva los avisos de autor y las licencias de todo lo que usa (cada carpeta trae su `LICENSE`/`CREDITOS.md`; el resumen está en *Ajustes > Acerca de > Créditos y licencias* y en `NOTICE-ALFA.txt`): Polestar (GPL-3.0), Shortest Path Forever (GPL-3.0-or-later), pfQuest (MIT), GatherLite (MIT), OpenMap (MIT), TerrainWorldMap (MIT) y las letras Inter, Fira Sans y Open Sans (OFL 1.1).
- Solo se nombra lo que Alfa **usa** (código o datos). Los addons que solo inspiraron una idea no se nombran: no se copió nada de ellos.
- Alfa no está afiliado a esos proyectos ni a Blizzard. World of Warcraft, Warcraft y Blizzard Entertainment son marcas de Blizzard Entertainment, Inc.; Discord es marca de Discord Inc.
- No se usan logos de otros proyectos.

## Antes de publicar

- [ ] Nada nuevo pide dinero dentro del juego ni anuncia productos.
- [ ] Nada nuevo escribe solo en el chat de otros jugadores.
- [ ] Todo lo nuevo que actúa en el juego espera tu tecla o tu clic.
- [ ] Lo nuevo que usa código o datos de terceros tiene su licencia en la carpeta y su línea en Créditos y licencias.
