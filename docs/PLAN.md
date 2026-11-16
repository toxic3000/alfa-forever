# Plan de Alfa

**Alfa: guía a tu manada.** Un solo addon para WoW Forever que reemplaza a doce y agrega lo que ninguno tiene. Es español primero (con inglés), muy visual y hecho por La Jauría.

Estrategia acordada el 15/11/2026: construir todo y probarlo en el juego al final. Mientras tanto, cada módulo pasa `revisar.py` y `humo.py`.

## Módulos

| Módulo | Página (orden) | Reemplaza a | Qué hace |
|---|---|---|---|
| Motor (`Alfa` + partes) | Guía, Apariencia, Mapa, Misiones, Descubrir, Comodidades, Integraciones, Guías de la comunidad, Acerca de | Polestar Guides | Guías por clasificación, flecha, rutas, misiones en el mapa, buscador "cómo conseguirlo", mazmorras con sus misiones, raros, personajes, consejo de equipo, vender y reparar, entrenar, XP por hora |
| `Alfa_Nucleo` | — | — | Piezas comunes de los módulos |
| `Alfa_Inicio` | Inicio (5) | — | Tablero: diario de sesión (XP/h, tiempo para subir, oro, misiones, muertes, resumen al salir), recordatorios (durabilidad antes de que se rompa, bolsas llenas, habilidades por entrenar, Grito de batalla fuera de combate, descanso), siguiente paso de la guía y accesos a cada módulo |
| `Alfa_Builds` | Builds (14) | Sonah, Pawn | Asistente de builds por clase y especialización: objetivo (subir solo, mazmorras, tanque, JcJ) y estilo (Tranquilo, Equilibrado, Arriesgado), talentos recomendados aplicables con un clic fuera de combate (C_Traits), prioridad de estadísticas que alimenta las flechas de mejora, equipo meta con "dónde conseguirlo", profesiones sugeridas y el *porqué* en español. Ayuda de rotación oficial (C_AssistedCombat), alertas de habilidades de reacción, recordatorio de buffs, temporizador de golpes, panel de estadísticas y compartir build. Guerrero completo primero |
| `Alfa_Rutas` | Rutas (12) | — | Árbol de ruta propio (ramas de XP, oro, profesión y clase, con cantidades y orden), liberar misiones (ruta más corta para cerrar las abiertas), catálogo de todos los objetos con filtros (tipo, calidad, nivel, ranura), "cómo conseguirlo" y "agregar a mi ruta" |
| `Alfa_Mundo` | Mundo (31) | OpenMap, Leatrix Maps | Mapa continuo con zoom y desplazamiento, zonas sin descubrir reveladas, coordenadas, niveles de zona, entradas de mazmorras, y **un solo control de capas** para todo lo que se pinta en el mapa |
| `Alfa_Recoleccion` | Recolección (32) | GatherLite | Nodos de minería, hierbas, pesca y tesoros (base de GatherLite + lo que recolectas), en mapa y minimapa, historial y rutas de farmeo |
| `Alfa_Bolsas` | Bolsas (40) | Baganator, Syndicator | Bolsas en una sola ventana o por categorías, ordenar, buscar, nivel de objeto, chatarra, flechas de mejora, banco, y el inventario de todos tus personajes (también en el cuadro de cada objeto) |
| `Alfa_Comercio` | Comercio (45) | — (Auctionator, como complemento) | Escaneo de la subasta, precios guardados y consejo por objeto: vender al comerciante, subastar o transformar (receta o desencantar), con cuánto ganas |
| `Alfa_Mazmorras` | Mazmorras (50) | DungeonJournal, DBM | Diario por mazmorra: jefes, botín, misiones y entrada; páginas que se desbloquean al vencer al jefe; avisos de jefes con la línea de tiempo del propio juego; consejos por jefe |
| `Alfa_Pesca` | Pesca (55) | Better Fishing | Las mismas funciones y opciones de Better Fishing: doble clic o una tecla para lanzar, la misma tecla recoge el pez, autobotín, sonido amplificado y ocultar nombres mientras pescas |
| `Alfa_Manada` | La Jauría (8) | — | Tu grupo en el mapa; tu hermandad y tus amigos si usan Alfa y aceptan compartir; botón Seguir con ruta hacia ellos; página del clan (información, Discord, pedir invitación) |
| `Alfa_Comodidades` | (dentro de Comodidades) | Leatrix Plus | Minimapa cuadrado, colores de clase, cuadro de información con objetivo y rango, barra de vuelo, entregar misiones diarias y semanales, aceptar resurrección fuera de combate, reparar con fondos de la hermandad y su resumen, vender grises y su resumen, botones del probador, ocultar botones de addons en el minimapa |

## Pendientes antes del lanzamiento

- [x] Enlace de Discord de La Jauría: https://discord.gg/hUNjA6BJwh
- [ ] Logo y marca de Alfa (`Alfa/Media/UI/logo`, `wordmark`), con colores de La Jauría.
- [ ] Textos del motor que mencionan "Polestar Client" (avisos de actualización) y la página "Novedades", que hoy son de Polestar.
- [ ] Texto de "Acerca de" con la historia de Alfa y La Jauría.
- [ ] Pasar tus ajustes de Polestar a Alfa (`PolestarDB` → `AlfaDB`) al instalar.
- [ ] Prueba en el juego, módulo por módulo, con /reload.
- [ ] Página de CurseForge en español e inglés, repositorio público (GPL: el código debe estar disponible).
