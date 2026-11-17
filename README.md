# Alfa — guía a tu manada

El todo en uno de **La Jauría** para World of Warcraft: Forever. Junta en un solo addon las guías, el mapa, las bolsas, los builds, la curación, la recolección, las mazmorras, la pesca, el comercio y tu manada, con un solo estilo.

Hecho por **toxic3000** y La Jauría — [Discord](https://discord.gg/hUNjA6BJwh). Software libre bajo la GPL-3.0, construido sobre [Polestar](https://github.com/fitzforge/polestar) (GPL-3.0). Los créditos completos están en `NOTICE-ALFA.txt`, en la página «Acerca de» del juego y en el `CREDITOS.md` de cada módulo.

## Instalar

La forma fácil: descarga **[Instalar-Alfa.exe](https://github.com/toxic3000/alfa-forever/releases/latest/download/Instalar-Alfa.exe)** y ábrelo. Encuentra tu WoW Forever, baja la versión más nueva y la instala; vuelve a abrirlo para actualizar. Más detalles en [`instalador/LEEME.md`](instalador/LEEME.md).

A mano: descarga `Alfa-<versión>.zip` de [Releases](https://github.com/toxic3000/alfa-forever/releases) y descomprímelo en `World of Warcraft/_forever_/Interface/AddOns` con el juego cerrado.

## Módulos

| Comando | Módulo | Qué hace |
|---|---|---|
| `/alfa` | Ventana principal | Hoy, Aventura, Personaje, Mundo, Oficios y Manada, con Ajustes aparte; 3 estilos (Alfa, Clásico WoW, Cristal) que también visten el chat, el minimapa y las barras |
| `/alfa bienvenida` | Bienvenida | Intro del lobo, idioma de Alfa (10 idiomas), qué es Alfa y cada opción automática como una pregunta |
| `/alfa inicio` | Hoy | "¿Qué hacemos hoy?", tu siguiente paso, entregar o recoger misiones, alertas, tu clase y tus números |
| `/alfa rutas` | Ruta | Asistente de 4 caminos, seguimiento compacto con detalle aparte, biblioteca de guías, **Mis planes**, misiones previas agregadas solas y solo misiones que sí puedes hacer |
| `/alfa cerca` | Buscar cerca | Maestro de vuelo, posada, reparar, banco, buzón, subastas y entrenadores con flecha y ruta |
| `/alfa enciclopedia` | Enciclopedia | Objetos, PNJ, misiones, zonas, raros, monturas y mascotas, con sus fuentes y "Guíame"; guía de los puntos del Legado |
| `/alfa mazmorras` | Mazmorras | Para tu nivel con "Prepárame"; jefes, botín, misiones y consejos |
| `/alfa builds` | Talentos | Qué poner ahora y por qué, con un clic; equipo y compartir |
| `/alfa combate` · `/alfa dps` | Combate | Ayuda de rotación para las 27 especializaciones, objetivos de misión resaltados, avisos de reacción y medidor de daño |
| `/alfa curacion` | Curación | Marcos para curar con clic y asistente de 3 pasos |
| `/alfa bolsas` | Bolsas | Tres vistas, banco con depositar rápido, objetos de misión que brillan y qué vender |
| `/alfa mapa` (o M) | Mundo | Mapa de todo el mundo con el terreno real, puntos de vuelo, entradas y salidas, marcadores propios y capas |
| `/alfa recoleccion` | Recolección | Nodos, pines y ruta de farmeo |
| `/alfa comercio` | Comercio | Precios de la subasta y qué hacer con cada objeto |
| `/alfa pesca` | Pesca | Modo pesca de una tecla (equipo, cebo, lanzar y recoger), barra, diario, logros, guía de 1 a 300 y cocina |
| `/alfa paisaje` | Paisaje y gráficos | Ajustes gráficos explicados, preajustes, deshacer y filtros de pantalla |
| `/alfa lya` | Lya | Una loba negra compañera: consejos, ánimo e historias de tus misiones y zonas. En memoria de una gran perrita |
| `/alfa manada` | La Jauría | Tu grupo y quienes usan Alfa y aceptan que la manada los vea en el mapa; Seguir; el clan |
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
