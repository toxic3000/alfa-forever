# Alfa — guía a tu manada

![Alfa — guía a tu manada](curseforge/galeria/00-banner.png)

<p align="center">
<a href="https://www.curseforge.com/wow/addons/alfa-forever"><img src="https://img.shields.io/badge/CurseForge-Alfa_Forever-F16436?style=for-the-badge&logo=curseforge&logoColor=white" alt="CurseForge"></a>
<a href="https://github.com/toxic3000/alfa-forever/releases/latest/download/Instalar-Alfa.exe"><img src="https://img.shields.io/badge/Descargar-Instalar--Alfa.exe-8BE04E?style=for-the-badge&logo=windows&logoColor=white" alt="Descargar el instalador"></a>
<a href="https://discord.gg/hUNjA6BJwh"><img src="https://img.shields.io/badge/Discord-La_Jaur%C3%ADa-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord de La Jauría"></a>
</p>

El todo en uno de **La Jauría** para World of Warcraft: Forever. Junta en un solo addon las guías, el mapa, las bolsas, los builds, la curación, la recolección, las mazmorras, la pesca, el comercio y tu manada, con un solo estilo.

Hecho por **toxic3000** y La Jauría — [Discord](https://discord.gg/hUNjA6BJwh). Software libre bajo la GPL-3.0, construido sobre [Polestar](https://github.com/fitzforge/polestar) (GPL-3.0). Los créditos completos están en `NOTICE-ALFA.txt`, en la página «Acerca de» del juego y en el `CREDITOS.md` de cada módulo.

## Un vistazo

<p align="center"><img src="curseforge/galeria/16-lya-poses.png" alt="Lya, la loba compañera de Alfa" width="900"></p>

**Lya, tu loba compañera.** Negrita, con su pañoleta de Alfa: te acompaña, corre, se busca la cola, duerme y te pide salchichas. Y platica: lore de Warcraft, datos de cada zona, de tu raza y tus profesiones, y consejos de amiga.

| | |
|---|---|
| ![Lya platica contigo](curseforge/galeria/17-lya-globo.png) | ![Tu ruta](curseforge/galeria/03-rutas.png) |
| **Lya platica contigo** — sin estorbar, cuando hay calma. | **Tu ruta** — la guía que te toca y entregar todo lo listo. |
| ![Reingeniería de la pesca](curseforge/galeria/11-pesca-diario.png) | ![Enciclopedia](curseforge/galeria/05-enciclopedia.png) |
| **Pesca** — una tecla para todo, diario, logros y guía de 1 a 300. | **Enciclopedia** — todo el juego, aunque no lo tengas, con "Guíame". |
| ![Paisaje y gráficos](curseforge/galeria/13-vista.png) | ![Mis planes](curseforge/galeria/14-planes.png) |
| **Paisaje** — los gráficos explicados, con preajustes. | **Mis planes** — tus propias metas, y la flecha te lleva. |
| ![Cada entrada, una bienvenida](curseforge/galeria/18-intro.png) | ![Lo nuevo, a la vista](curseforge/galeria/19-notas.png) |
| **Cada entrada, una bienvenida** — la intro del lobo y la luna te recibe al entrar. | **Lo nuevo, a la vista** — qué cambió, en una ventana. |

Más imágenes en [`curseforge/galeria/`](curseforge/galeria).

## Instalar

La forma fácil: descarga **[Instalar-Alfa.exe](https://github.com/toxic3000/alfa-forever/releases/latest/download/Instalar-Alfa.exe)** y ábrelo. Encuentra tu WoW Forever, baja la versión más nueva y la instala; vuelve a abrirlo para actualizar. Más detalles en [`instalador/LEEME.md`](instalador/LEEME.md).

A mano: descarga `Alfa-<versión>.zip` de [Releases](https://github.com/toxic3000/alfa-forever/releases) y descomprímelo en `World of Warcraft/_forever_/Interface/AddOns` con el juego cerrado.

## Módulos

| Comando | Módulo | Qué hace |
|---|---|---|
| `/alfa` | Ventana principal | Hoy, Aventura, Personaje, Mundo, Oficios y Manada, con Ajustes aparte; el ícono del minimapa y el botón Alfa del menú Esc abren lo mismo (clic derecho: el mismo menú); 3 estilos (Alfa, Clásico WoW, Cristal) que también visten el chat, el minimapa y las barras |
| `/alfa bienvenida` | Bienvenida | Intro del lobo, idioma de Alfa (10 idiomas), qué es Alfa y cada opción automática como una pregunta |
| `/alfa inicio` | Hoy | "¿Qué hacemos hoy?", tu siguiente paso, entregar o recoger misiones, alertas, tu clase y tus números |
| `/alfa rutas` | Ruta | Asistente de 4 caminos, seguimiento compacto con detalle aparte, biblioteca de guías, **Mis planes**, misiones previas agregadas solas, solo misiones que sí puedes hacer, vuelta a entregar y la mejor recompensa marcada |
| `/alfa cerca` | Buscar cerca | Maestro de vuelo, posada, reparar, banco, buzón, subastas y entrenadores con flecha y ruta |
| `/alfa enciclopedia` | Enciclopedia | Objetos, PNJ, misiones, zonas, raros, monturas y mascotas, con sus fuentes y "Guíame"; guía de los puntos del Legado |
| `/alfa mazmorras` | Mazmorras | Para tu nivel con "Prepárame"; jefes, botín, misiones y consejos |
| `/alfa builds` | Talentos | Qué poner ahora y por qué, con un clic; equipo y compartir |
| `/alfa combate` · `/alfa dps` | Combate | Ayuda de rotación para las 27 especializaciones, objetivos de misión resaltados, avisos de reacción y medidor de daño |
| `/alfa curacion` | Curación | Marcos para curar con clic y asistente de 3 pasos |
| `/alfa bolsas` | Bolsas | Tres vistas, banco con depositar rápido, objetos de misión que brillan, qué vender, tu oro por hora (el del buzón aparte) y el aviso de cartas por vencer |
| `/alfa mapa` (o M) | Mundo | Mapa de todo el mundo con el terreno real, puntos de vuelo, entradas y salidas, marcadores propios y capas |
| `/alfa recoleccion` | Recolección | Nodos, pines y ruta de farmeo |
| `/alfa comercio` | Comercio | Precios de la subasta y qué hacer con cada objeto |
| `/alfa pesca` | Pesca | Modo pesca de una tecla (equipo, cebo, lanzar y recoger), barra, diario, logros, guía de 1 a 300 y cocina |
| `/alfa paisaje` | Paisaje y gráficos | Ajustes gráficos explicados, preajustes, deshacer y filtros de pantalla |
| `/alfa lya` · `/alfa ayuda` | Lya | Una loba negra compañera: consejos, ánimo e historias de tus misiones y zonas; te dice los avisos, te responde «¿Cómo hago...?», lleva tu historia y te avisa de tus oficios. En memoria de una gran perrita |
| `/alfa manada` · `/alfa cita` · `/alfa nota` | La Jauría | Tu grupo y quienes usan Alfa y aceptan que la manada los vea en el mapa; Seguir; llamar a la manada; guaridas; raros con reloj; citas; «¿Quién va?»; notas en tu mapa; «Un lobo de La Jauría anda cerca»; insignia y el clan |
| `/alfa plano` | Cambiar de plano | Te pasa al plano de un lobo de la manada con su guarida abierta cuando el tuyo está lleno |
| `/alfa camino` · `/alfa listo` | Hoy | El camino al 60 a tu ritmo y la revisión antes de la mazmorra |
| `/alfa diagnostico` | Diagnóstico | Revisa choques con otros addons, partes apagadas y ajustes raros, con arreglo de un clic |
| `/alfa llevame` | Llévame a… | El viaje completo a cualquier lugar con vuelos, barcos, zepelines y a pie |
| `/alfa limpia` · `/alfa teclas` | Interfaz | Pantalla limpia con una tecla y todos tus atajos de Alfa en una pantalla |
| `/alfa recorrido` | Recorrido | Lya te enseña la ventana de Alfa en 5 pasos |
| `/alfa rendimiento` | Rendimiento | Cuánta memoria usa cada parte de Alfa, y suelta la que ya no ocupa |
| `/alfa reportar` | Reportes | Errores, mejoras y comentarios para el buzón privado del Discord, revisados por el desarrollador |
| (Ajustes) | Comodidades | Minimapa, colores de clase, cuadro de información, probador, vuelo, misiones y sonidos |

Alfa no depende de ningún otro addon. Versiones y notas: [`docs/VERSIONES.md`](docs/VERSIONES.md) y [`CHANGELOG.md`](CHANGELOG.md).

## Apoya a Alfa

Alfa es gratis y lo seguirá siendo. Donar es totalmente opcional: es una forma de agradecer el trabajo de toxic3000 y ayudar a que Alfa siga creciendo. No desbloquea nada y no cambia nada en el juego.

[![Donar con PayPal](https://img.shields.io/badge/Donar-PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white)](https://www.paypal.com/donate/?hosted_button_id=7J5BYWH9DVT9C)

Dentro del juego no hay donaciones: así lo piden las reglas de Blizzard para addons (ver `docs/REGLAS-BLIZZARD.md`).

## Construir e instalar

```bash
python -I tools/fetch_upstream.py 0.3.7.2       # una vez: Polestar verificado
python -I tools/build.py                        # arma dist/
.venv/Scripts/python -I tools/revisar.py        # sintaxis Lua 5.1 + TOC/XML
.venv/Scripts/python -I tools/humo.py           # módulos con el juego simulado
python -I tools/instalar.py                     # simula la instalación
python -I tools/instalar.py --aplicar           # instala (con WoW cerrado)
```

Los addons que el instalador desactiva en tu PC van en `tools/instalar_local.json` (`{"desactivar": ["Carpeta", "Prefijo-.*"]}`), que no se sube a git.

Contrato de los módulos y reglas de Forever: `docs/ARQUITECTURA.md`. Plan y pendientes: `docs/PLAN.md`.

## Código fuente y licencia

Alfa es GPL-3.0. Cada versión publicada se arma así:
- el código y los datos de **Polestar** de la versión indicada en `tools/alfa.json` (`upstream`), tal como los publica su repositorio [fitzforge/polestar](https://github.com/fitzforge/polestar/releases), con su firma SHA256 verificada;
- los cambios de nombre y los parches de `tools/` (renombrar, parches, marca);
- los módulos de `src/`, las texturas de terceros de `vendor/` con su licencia, y los textos de `textos/`.

Con este repositorio y `tools/fetch_upstream.py`, cualquiera puede reconstruir exactamente el mismo paquete.
