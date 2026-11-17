# Plan de Alfa

**Alfa: guía a tu manada.** Un solo addon para WoW Forever con todo lo que hace falta para jugar, y lo que ningún otro tiene. Es español primero (con inglés), muy visual y hecho por La Jauría.

Estrategia acordada el 15/11/2026: construir todo y probarlo en el juego al final. Mientras tanto, cada módulo pasa `revisar.py` y `humo.py`.

**Estado del 16/11/2026:** los 11 módulos y el motor están construidos y en git. Todo junto da 473 archivos Lua en 40 carpetas sin errores de sintaxis, y los 12 módulos cargan juntos en la prueba de humo sin errores ni avisos. Cada módulo tiene su lista "Para verificar en el juego" en su `LEEME.md`. Siguiente paso: instalar con `tools/instalar.py --aplicar` (con WoW cerrado) y probar módulo por módulo.

## Módulos

| Módulo | Página (orden) | Qué hace |
|---|---|---|
| Motor (`Alfa` + partes) | Guía, Apariencia, Mapa, Misiones, Descubrir, Comodidades, Integraciones, Guías de la comunidad, Acerca de | Guías por clasificación, flecha, rutas, misiones en el mapa, buscador "cómo conseguirlo", mazmorras con sus misiones, raros, personajes, consejo de equipo, vender y reparar, entrenar, XP por hora |
| `Alfa_Nucleo` | — | Piezas comunes de los módulos |
| `Alfa_Inicio` | Inicio (5) | Tablero: diario de sesión (XP/h, tiempo para subir, oro, misiones, muertes, resumen al salir), recordatorios (durabilidad antes de que se rompa, bolsas llenas, habilidades por entrenar, Grito de batalla fuera de combate, descanso), siguiente paso de la guía y accesos a cada módulo |
| `Alfa_Builds` | Builds (14) | Asistente de builds por clase y especialización: objetivo (subir solo, mazmorras, tanque, JcJ) y estilo (Tranquilo, Equilibrado, Arriesgado), talentos recomendados aplicables con un clic fuera de combate (C_Traits), prioridad de estadísticas que alimenta las flechas de mejora, equipo meta con "dónde conseguirlo", profesiones sugeridas y el *porqué* en español. Ayuda de rotación oficial (C_AssistedCombat), alertas de habilidades de reacción, recordatorio de buffs, temporizador de golpes, panel de estadísticas y compartir build. Guerrero completo primero |
| `Alfa_Curacion` | Curación (16) | Marcos de grupo y banda con vida compatible con valores secretos, curar con clic (botones seguros) con un mapa del ratón visual, preajustes por clase (Sacerdote, Druida, Paladín, Chamán y "solo buffs"), modo prueba, y opción de usar el clic para lanzar de Blizzard |
| `Alfa_Rutas` | Rutas (12) | Árbol de ruta propio (ramas de XP, oro, profesión y clase, con cantidades y orden), liberar misiones (ruta más corta para cerrar las abiertas), catálogo de todos los objetos con filtros (tipo, calidad, nivel, ranura), "cómo conseguirlo" y "agregar a mi ruta" |
| `Alfa_Mundo` | Mundo (31) | Mapa continuo con zoom y desplazamiento, zonas sin descubrir reveladas, coordenadas, niveles de zona, entradas de mazmorras, y **un solo control de capas** para todo lo que se pinta en el mapa |
| `Alfa_Recoleccion` | Recolección (32) | Nodos de minería, hierbas, pesca y tesoros (base incluida + lo que recolectas), en mapa y minimapa, historial y rutas de farmeo |
| `Alfa_Bolsas` | Bolsas (40) | Bolsas en una sola ventana o por categorías, ordenar, buscar, nivel de objeto, chatarra, flechas de mejora, banco, y el inventario de todos tus personajes (también en el cuadro de cada objeto) |
| `Alfa_Comercio` | Comercio (45) | Escaneo de la subasta, precios guardados y consejo por objeto: vender al comerciante, subastar o transformar (receta o desencantar), con cuánto ganas |
| `Alfa_Mazmorras` | Mazmorras (50) | Diario por mazmorra: jefes, botín, misiones y entrada; páginas que se desbloquean al vencer al jefe; avisos de jefes con la línea de tiempo del propio juego; consejos por jefe |
| `Alfa_Pesca` | Pesca (55) | Doble clic o una tecla para lanzar, la misma tecla recoge el pez, autobotín, sonido amplificado y ocultar nombres mientras pescas |
| `Alfa_Manada` | La Jauría (8) | Tu grupo en el mapa; tu hermandad y tus amigos si usan Alfa y aceptan compartir; botón Seguir con ruta hacia ellos; página del clan (información, Discord, pedir invitación) |
| `Alfa_Comodidades` | (dentro de Comodidades) | Minimapa cuadrado, colores de clase, cuadro de información con objetivo y rango, barra de vuelo, entregar misiones diarias y semanales, aceptar resurrección fuera de combate, reparar con fondos de la hermandad y su resumen, vender grises y su resumen, botones del probador, ocultar botones de addons en el minimapa |

## Pendientes antes del lanzamiento

- [x] Enlace de Discord de La Jauría: https://discord.gg/hUNjA6BJwh
- [ ] Logo y marca de Alfa (`Alfa/Media/UI/logo`, `wordmark`), con colores de La Jauría.
- [ ] Textos del motor que mencionan "Polestar Client" (avisos de actualización) y la página "Novedades", que hoy son de Polestar.
- [ ] Texto de "Acerca de" con la historia de Alfa y La Jauría.
- [ ] Pasar tus ajustes de Polestar a Alfa (`PolestarDB` → `AlfaDB`) al instalar.
- [ ] Prueba en el juego, módulo por módulo, con /reload.
- [ ] Página de CurseForge en español e inglés, repositorio público (GPL: el código debe estar disponible).

## Integración pendiente (sale de los reportes de cada módulo)

- [ ] Núcleo: `N.Modulo` dentro de una página que ya existe del motor (Comodidades lo hace a mano reenviando `SHOW_OPTIONS`), y que `N.Abrir(id)` llegue a esa página.
- [ ] Núcleo: vía pública entre módulos (por ejemplo, que Bolsas e Inicio pregunten a Comercio el valor y el consejo de un objeto).
- [ ] Motor: forma estable de obtener el marco del temporizador de vuelo (hoy Comodidades usa el global `AlfaFlightTimer`).
- [ ] Choque: `behavior.closeSkipped` del motor puede cerrar la ventana antes de que "todas las misiones" de Comodidades actúe.
- [ ] Comodidades: cada grupo viene apagado; decidir con Toxic cuáles vienen encendidos.
- [ ] Páginas propias (Pesca, Comercio, Inicio): sus ajustes no salen en el buscador de opciones.
- [~] Mundo: `AlfaMundo.ActivarCapa` ya existe; falta una proyección para pintar pines en el mapa continuo (Recolección solo pinta en mapas de zona).
- [x] Acerca de: créditos visibles del código y los datos reutilizados bajo MIT.
- [ ] Núcleo: opción `alComando(rest)` en `N.Modulo` para comandos con argumentos (Manada y Pesca lo registran aparte).
- [ ] Motor: destino "persistente" en `Nav.SetTarget` para que Seguir (La Jauría) no se suelte cuando la guía cambia de paso.
- [x] La Jauría: "Quiero unirme" lleva al Discord (sin oficiales con nombre de personaje en el código).
- [ ] Núcleo: `N.Repintar(id)` oficial para volver a dibujar una página propia (Mazmorras, Pesca e Inicio usan piezas internas de Options).
- [ ] Mazmorras: confirmar en el juego si Forever trae las CVars de avisos de jefes (la variante "Camelot" dice `HasBossWarnings = false`).
- [x] Builds y Rutas: terminados y en git el 16/11.
- [ ] Mundo: Recolección debería publicar sus nodos en `Alfa.Pins` (id `recoleccion.<tipo>`) para verse en el mapa continuo.
- [ ] Idiomas: en Builds, "Protección" y "Restauración" son la misma clave para dos clases (guerrero/paladín, druida/chamán), pero en coreano y otros idiomas tienen nombres distintos. Separar las claves en español.
- [ ] Idiomas: las fechas "el %d/%d a las %s" llevan el orden día/mes del español; en coreano y chino conviene que el formato de fecha sea parte de la traducción.
- [ ] Idiomas: nombres de hechizos que los traductores dejaron en inglés o marcaron como dudosos (lista en sus reportes); que los revise alguien nativo.
- [ ] Bolsas: la búsqueda en ruso (y otros alfabetos) depende de minúsculas; `string.lower` de WoW no convierte el cirílico, así que buscar con mayúscula inicial puede no encontrar nada.

## Interfaz propia (diseño A, 16/11/2026)

- [x] Tema, componentes, ventana principal con secciones, página Hoy por clase, ventana de guía, bienvenida, novedades, selector de guías, buscador y diario de mazmorras con acomodo propio (27 archivos en `motor/`).
- [ ] En el centro de guías, las secciones Talentos, Raros, Personajes e Importar ya usan el ancho completo y píldoras, pero su acomodo interior sigue siendo el original.
- [ ] Términos: los textos del motor en esMX dicen "Calabozos"; los de Alfa dicen "Mazmorras". Hay que unificarlos.
- [ ] Documentar `UI.HubKit` (piezas compartidas del centro de guías) en `docs/INTERFAZ.md`.
- [ ] Revisar en el juego la lista "Qué revisar" de cada parte (esquinas cortadas, que quepan las píldoras, desplazamiento, mando).
