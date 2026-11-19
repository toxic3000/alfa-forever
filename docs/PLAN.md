# Plan de Alfa

**Alfa: guía a tu manada.** Un solo addon para WoW Forever con todo lo que hace falta para jugar, y lo que ningún otro tiene. Es español primero (con inglés), muy visual y hecho por La Jauría.

Estrategia acordada el 15/11/2026: construir todo y probarlo en el juego al final. Mientras tanto, cada módulo pasa `revisar.py` y `humo.py`.

**Estado del 16/11/2026:** los 11 módulos y el motor están construidos y en git. Todo junto da 473 archivos Lua en 40 carpetas sin errores de sintaxis, y los 12 módulos cargan juntos en la prueba de humo sin errores ni avisos. Cada módulo tiene su lista "Para verificar en el juego" en su `LEEME.md`. Siguiente paso: instalar con `tools/instalar.py --aplicar` (con WoW cerrado) y probar módulo por módulo.

## Ruta de la 1.1.6 a la 1.2.0 (acordada el 18/11/2026)

Sale de una revisión del código del 18/11. En cada versión va primero lo que reporten los jugadores; cada error del juego real se agrega antes al banco. Cada versión se publica sola (git, GitHub con zip e instalador, CurseForge y aviso en Discord).

### 1.1.6 — Arreglos de raíz
- [x] Seguir (La Jauría): destino persistente en `Nav.SetTarget` (hoy `stepMoved` lo borra al cambiar de paso) y no soltarse con `Nav.Hold` activo (camino al cadáver).
- [x] `behavior.closeSkipped` del motor ya no cierra la ventana de una misión que Comodidades acaba de pedir.
- [x] Barra de vuelo: `Maps.GetFlightFrame()` en lugar del global `AlfaFlightTimer` y el orden de `OnLogin`.
- [x] Mazmorras: si falta `combatWarningsEnabled` pero existen las CVars hijas, los avisos no se quedan apagados.
- [x] Fechas armadas por idioma (`Alfa_Inicio/Sesion.lua`): hoy el orden día/mes está fijo y zhTW sale al revés.
- [x] Talentos: claves distintas para Protección (guerrero/paladín) y Restauración (druida/chamán); koKR las necesita.
- [x] Alfa independiente: sin «Polestar Client», sin traducciones viejas que nombran a Polestar, sin `/pole`, README propio y Acerca de sin «construido sobre». Los avisos de licencia y créditos se quedan (GPL).

### 1.1.7 — Mapa impecable, parte 1
- [x] Pines, etiquetas y tu posición ajustados al píxel físico, con tamaños enteros (`Alfa_Mundo/Marcas.lua`).
- [x] Texturas del mapa con `CLAMP` explícito (se queda `TRILINEAR`: con zoom lejano `LINEAR` haría brillar los píxeles al moverse).
- [x] Medio texel de margen en cada `SetTexCoord` recortado.
- [x] Nivel de marco único por zona (sin parpadeo en fronteras).
- [x] Pruebas numéricas en el banco (tamaños enteros, medio texel, niveles únicos) y capturas de antes/después en el juego.

### 1.1.8 — Mapa impecable, parte 2
- [x] Íconos TGA sin bordes negros (dilatar el color en los píxeles transparentes, `tools/iconos.py`).
- [x] Fundido de carga por tandas (`Lienzo.lua`: todo lo pedido en una colocación aparece junto). Las rampas `DETALLE`/`TERRENO` se quedan: el cruce entre capas es intencional.
- [x] Recolección publica sus nodos en `Alfa.Pins` (`recoleccion.<tipo>`) para el mapa continuo.
- [x] El ticker del minimapa de Recolección se detiene cuando la capa está oculta.
- [ ] Máscaras de territorio de 512 o 1024: pendiente, no hay arte de origen de más resolución (las de OpenMap son de 256).

### 1.1.9 — Ensayo general de la 1.2.0
- [x] El buscador de Ajustes incluye Pesca, Comercio, Ruta, Bolsas, Combate, Curación, Lya y Estilo y sonido.
- [x] Bolsas usa `Search.Fold` del motor (cirílico y otros alfabetos).
- [x] Inicio usa `AlfaComercio` como ya lo hace Bolsas.
- [x] Un solo término: «Mazmorras» (decidió Toxic el 18/11; `tools/parches.py`, `mazmorras`).
- [x] Núcleo: `alComando(rest)` y `N.Repintar(id)`.
- [x] Banco: prueba de guardar, recargar y leer ajustes; migraciones que lean `schema`.

### 1.2.0 — Ajustes en orden
- [x] Juntar Comodidades y Calidad de vida (chocan en misiones, errores, minimapa y vuelos).
- [x] Ajustes de misiones en un solo lugar (hoy en 6, contando la bienvenida).
- [x] Mudar la configuración de cada jugador (`schema = 2`, con el modelo de `migradoBuilds`).
- [x] Qué viene encendido de fábrica en Comodidades: las 5 recomendadas, el minimapa mejorado y las barras con el estilo de Alfa (decidió Toxic el 18/11; solo en instalaciones nuevas).
- [x] Bienvenida y novedades que expliquen dónde quedó cada cosa; galería y anuncio nuevos.
- [ ] Talentos, Raros, Personajes e Importar con `UI.HubKit`: pasa a la 1.2.2 (la 1.2.0 fue la versión estable y la 1.2.1 la del mapa: tu camino, el vuelo y el terreno sin pedazos).
- [x] Insignias de La Jauría (idea de Toxic, 18/11): una chapita discreta (solo visual) junto al nombre de quien es de la manada, en el cuadro del jugador, La Jauría y el mapa. Solo para ciertas personas, no para todos los que usan Alfa. Decidido: una lista de personajes (nombre-reino) dentro del addon que Toxic pasa y mantiene (opción 1), con permiso de cada persona para salir en la lista.
- [x] Mapa «en manada» (Toxic, 18/11): quien usa Alfa y comparte su ubicación (capa `manada.jauria` de `Alfa_Manada/Mapa.lua`, ya existe y es voluntaria) se ve con una huella pequeña de lobo, más chica que el pin de tu grupo; los de la lista de insignias llevan además su chapita. Sigue siendo voluntario: nadie aparece sin aceptar compartir.

- [x] La intro del lobo te recibe en cada entrada (`bienvenida.introSiempre`) y el lobo se redibujó con curvas (`tools/intro.py`).
- [x] Lya tutea en francés y ruso (decidió Toxic el 18/11).
- [x] La descripción de CurseForge dice que Alfa se hace con ayuda de IA, con la broma de Claudio la ballena y Jesus GPT, y agradece a quienes lo usan.

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
- [x] Choque: `behavior.closeSkipped` del motor puede cerrar la ventana antes de que "todas las misiones" de Comodidades actúe.
- [ ] Comodidades: cada grupo viene apagado; decidir con Toxic cuáles vienen encendidos.
- [x] Páginas propias (Pesca, Comercio, Inicio): sus ajustes no salen en el buscador de opciones.
- [~] Mundo: `AlfaMundo.ActivarCapa` ya existe; falta una proyección para pintar pines en el mapa continuo (Recolección solo pinta en mapas de zona).
- [x] Acerca de: créditos visibles del código y los datos reutilizados bajo MIT.
- [ ] Núcleo: opción `alComando(rest)` en `N.Modulo` para comandos con argumentos (Manada y Pesca lo registran aparte).
- [x] Motor: destino "persistente" en `Nav.SetTarget` para que Seguir (La Jauría) no se suelte cuando la guía cambia de paso.
- [x] La Jauría: "Quiero unirme" lleva al Discord (sin oficiales con nombre de personaje en el código).
- [ ] Núcleo: `N.Repintar(id)` oficial para volver a dibujar una página propia (Mazmorras, Pesca e Inicio usan piezas internas de Options).
- [ ] Mazmorras: confirmar en el juego si Forever trae las CVars de avisos de jefes (la variante "Camelot" dice `HasBossWarnings = false`).
- [x] Builds y Rutas: terminados y en git el 16/11.
- [x] Mundo: Recolección debería publicar sus nodos en `Alfa.Pins` (id `recoleccion.<tipo>`) para verse en el mapa continuo.
- [x] Idiomas: en Builds, "Protección" y "Restauración" son la misma clave para dos clases (guerrero/paladín, druida/chamán), pero en coreano y otros idiomas tienen nombres distintos. Separar las claves en español.
- [x] Idiomas: las fechas "el %d/%d a las %s" llevan el orden día/mes del español; en coreano y chino conviene que el formato de fecha sea parte de la traducción.
- [ ] Idiomas: nombres de hechizos que los traductores dejaron en inglés o marcaron como dudosos (lista en sus reportes); que los revise alguien nativo.
- [x] Bolsas: la búsqueda en ruso (y otros alfabetos) depende de minúsculas; `string.lower` de WoW no convierte el cirílico, así que buscar con mayúscula inicial puede no encontrar nada.

## Interfaz propia (diseño A, 16/11/2026)

- [x] Tema, componentes, ventana principal con secciones, página Hoy por clase, ventana de guía, bienvenida, novedades, selector de guías, buscador y diario de mazmorras con acomodo propio (27 archivos en `motor/`).
- [ ] En el centro de guías, las secciones Talentos, Raros, Personajes e Importar ya usan el ancho completo y píldoras, pero su acomodo interior sigue siendo el original.
- [x] Términos: los textos del motor en esMX dicen "Calabozos"; los de Alfa dicen "Mazmorras". Hay que unificarlos.
- [ ] Documentar `UI.HubKit` (piezas compartidas del centro de guías) en `docs/INTERFAZ.md`.
- [ ] Revisar en el juego la lista "Qué revisar" de cada parte (esquinas cortadas, que quepan las píldoras, desplazamiento, mando).
