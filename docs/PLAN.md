# Plan de Alfa

**Alfa: guía a tu manada.** Un solo addon para WoW Forever con todo lo que hace falta para jugar, y lo que ningún otro tiene. Es español primero (con inglés), muy visual y hecho por La Jauría.

Estrategia acordada el 15/11/2026: construir todo y probarlo en el juego al final. Mientras tanto, cada módulo pasa `revisar.py` y `humo.py`.

**Estado del 24/11/2026 (1.3.9 en camino):** 19 módulos propios sobre el motor, publicados de la 1.0.0 a la 1.3.8; cada versión trae su prueba en el banco (`tools/banco/prueba_*.lua`, más de 100 escenas) y `tools/prueba.py` las corre todas. El plan de cada versión grande va aparte: `docs/PLAN-1.3.7.md` (200 mejoras) y `docs/PLAN-1.3.9.md` (106); lo que salió, en `CHANGELOG.md`; las notas para trabajar, en `CLAUDE.md`. Este archivo queda como la historia de las primeras rutas y la lista de pendientes de fondo (revisada el 24/11: lo ya hecho está marcado).

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

## De la 1.2.9 a la 1.3.8 (hecho)

- **1.2.9 — La gran cacería:** 32 mejoras; un solo reloj para todo lo que se repite (`N.Cada`, `Alfa_Nucleo/Reloj.lua`), errores atrapados (`Errores.lua`), respaldos, modo sencillo o completo.
- **1.3.0 — La manada sana:** curar con un clic (Curación), la llegada de la flecha como placa propia, bolsas con conjuntos y comparar, resumen de combate con `C_DamageMeter`.
- **1.3.1 — La manada afinada:** acomodar la pantalla (`/alfa acomodar`), anuncios que esperan a los del juego, migraciones como conjunto, revisión de la 1.2.4 a la 1.3.0.
- **1.3.2 — La manada en orden:** un solo menú de Alfa (`O.MenuAlfa`), base de misiones sin Codex (`Rutas/Ligero.lua`), un solo reloj de La Jauría.
- **1.3.3 — La manada en calma:** entrar en silencio (`Alfa_Nucleo/Entrada.lua`), una sola voz por aviso (`dichosSesion`), la ruta de tu grupo.
- **1.3.4 — La manada ligera:** guías con los pasos diferidos (`tools/diferir.py`, `docs/DISENO-GUIAS-DIFERIDAS.md`): lo que Alfa lee al entrar bajó de 185 a unos 45 ms en el banco (`docs/perfil-1.3.4.txt`).
- **1.3.5 — La manada más ligera:** modo combate, modo mazmorra y modo ligero del reloj (`N.DeFondo`, `N.DeAfuera`, `N.Ligero`), eventos por unidad y por prefijo (`Alfa_Nucleo/Eventos.lua`).
- **1.3.6 — La manada te guía:** páginas que se arman una vez y se reusan (`tools/perfil.py --paginas`), ayuda para quien empieza.
- **1.3.7 — La manada a tu ritmo:** 200 mejoras (`docs/PLAN-1.3.7.md`): el orquestador de momentos (`Alfa_Nucleo/Momentos.lua`: `N.Ocupado`, `N.AlLibre`, «Lo que me perdí»), anuncios de zona, la sección Planes.
- **1.3.8 — La manada en dos pantallas:** el Escritorio en el segundo monitor (`Alfa_Bienvenida/Escritorio*.lua`), facciones separadas en la Red (`Alfa_Nucleo/Faccion.lua`), firmas de los avisos, pesca con récords, candado de objetos.

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
- [x] Logo y marca de Alfa (`marca/`, `tools/marca.py`), con colores de La Jauría.
- [x] Textos del motor que mencionan "Polestar Client" (avisos de actualización) y la página "Novedades", que hoy son de Polestar (1.1.6).
- [x] Texto de "Acerca de" con la historia de Alfa y La Jauría (`ACERCA` en `tools/parches.py`).
- [ ] Pasar tus ajustes de Polestar a Alfa (`PolestarDB` → `AlfaDB`) al instalar. (Al 24/11 no se hizo: Alfa empieza con ajustes propios; decidir con Toxic si aún hace falta.)
- [x] Prueba en el juego, módulo por módulo, con /reload (Toxic prueba cada versión antes de publicarla).
- [x] Página de CurseForge en español e inglés, repositorio público (GPL: el código debe estar disponible).

## Integración pendiente (sale de los reportes de cada módulo)

- [x] Núcleo: `N.Modulo` dentro de una página que ya existe del motor (1.2.0: la redirección de `add()` en `motor/Alfa/UI/Options.lua`) (Comodidades lo hace a mano reenviando `SHOW_OPTIONS`), y que `N.Abrir(id)` llegue a esa página.
- [x] Núcleo: vía pública entre módulos (por ejemplo, que Bolsas e Inicio pregunten a Comercio el valor y el consejo de un objeto): `AlfaComercio.Consejo/ValorVenta/PrecioSubasta` y los globales `Alfa<Módulo>` de cada uno.
- [x] Motor: forma estable de obtener el marco del temporizador de vuelo: `Maps.GetFlightFrame()` (1.1.6).
- [x] Choque: `behavior.closeSkipped` del motor puede cerrar la ventana antes de que "todas las misiones" de Comodidades actúe.
- [x] Comodidades: cada grupo viene apagado; decidir con Toxic cuáles vienen encendidos (1.2.0: las 5 recomendadas).
- [x] Páginas propias (Pesca, Comercio, Inicio): sus ajustes no salen en el buscador de opciones.
- [~] Mundo: `AlfaMundo.ActivarCapa` ya existe; falta una proyección para pintar pines en el mapa continuo (Recolección solo pinta en mapas de zona).
- [x] Acerca de: créditos visibles del código y los datos reutilizados bajo MIT.
- [x] Núcleo: opción `alComando(rest)` en `N.Modulo` para comandos con argumentos (1.1.9).
- [x] Motor: destino "persistente" en `Nav.SetTarget` para que Seguir (La Jauría) no se suelte cuando la guía cambia de paso.
- [x] La Jauría: "Quiero unirme" lleva al Discord (sin oficiales con nombre de personaje en el código).
- [x] Núcleo: `N.Repintar(id)` oficial para volver a dibujar una página propia (1.1.9).
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

## Pendientes de fondo (revisados el 24/11/2026, con números de `tools/perfil.py --veces 3`)

- [ ] Cargar las guías por rango de niveles (pendiente desde la 1.3.2): `Alfa_Guides_Horde` pesa 10 MB y unos 30 archivos del motor recorren todas las guías.
- [ ] La lectura al entrar sigue en unos 58 ms del banco (meta de la 1.3.9: 45). Lo que más pesa: el paquete de idioma que `Core/Locale.lua` carga al vuelo (unos 13 ms, casi todo compilar `Alfa_esMX`: `Texts.lua` 4 ms, `Names.lua` 3 ms, `Interface.lua` 2 ms) y el registro de las guías (`Alfa_Guides` 7 ms y `Alfa_Guides_Horde` 5 ms). Bajarlo pide diferir también los textos de las guías por idioma (hoy se arman todos para el título de cada guía en la lista).
- [ ] Comercio: en la cuenta de Toxic, los precios con el reino vacío («?-Alliance», 742 KB de los 1.7 MB de `AlfaNucleoDB`) siguen junto a los de su reino: `M.JuntarReinoSinNombre` solo los junta cuando el juego dice el reino con seguridad.
- [ ] Banco: el ancho de las letras CJK es una estimación (la prueba de avisos cuenta casi un cuadro por letra); confirmar en el juego los avisos en coreano y chino.
