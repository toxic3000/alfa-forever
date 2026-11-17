# Alfa — guía a tu manada

El todo en uno de **La Jauría** para World of Warcraft: Forever. Junta en un solo addon las guías, el mapa, las bolsas, los builds, la curación, la recolección, las mazmorras, la pesca, el comercio y tu manada, con un solo estilo.

Hecho por Toxic y La Jauría — [Discord](https://discord.gg/hUNjA6BJwh). Software libre bajo la GPL-3.0, construido sobre [Polestar](https://github.com/fitzforge/polestar) (GPL-3.0). Los créditos completos están en `NOTICE-ALFA.txt`, en la página «Acerca de» del juego y en el `CREDITOS.md` de cada módulo.

## Módulos

| Comando | Módulo | Qué hace |
|---|---|---|
| `/alfa` | Ventana principal | Hoy, Aventura, Personaje, Mundo, Oficios y Manada, con Ajustes aparte; 3 estilos (Alfa, Clásico WoW, Cristal) |
| `/alfa bienvenida` | Bienvenida | Primer arranque guiado: estilo, misiones solo de tu ruta, compartir con La Jauría, aullido |
| `/alfa inicio` | Hoy | "¿Qué hacemos hoy?", tu siguiente paso, entregar o recoger misiones, alertas, tu clase y tus números |
| `/alfa rutas` | Ruta | Asistente de 4 caminos, rastreador propio, biblioteca de guías, **entregar todas tus misiones listas**, plan de misiones a mano y misiones que sí puedes tomar |
| `/alfa enciclopedia` | Enciclopedia | Todos los objetos, PNJ, misiones, zonas y raros, con sus fuentes y "Guíame" |
| `/alfa mazmorras` | Mazmorras | Para tu nivel con "Prepárame"; jefes, botín, misiones y consejos |
| `/alfa builds` | Talentos | Qué poner ahora y por qué, con un clic; equipo y compartir |
| `/alfa combate` · `/alfa dps` | Combate | Ayuda de rotación discreta, avisos de reacción y medidor de daño del grupo |
| `/alfa curacion` | Curación | Marcos para curar con clic y asistente de 3 pasos |
| `/alfa bolsas` | Bolsas | Tres vistas (todo, categorías, por bolsa), barra de bolsas, banco con depositar rápido y comprar espacio, qué vender |
| `/alfa mapa` (o M) | Mundo | Mapa de todo el mundo con zoom, marcadores propios para seguir y compartir, capas |
| `/alfa recoleccion` | Recolección | Nodos, pines y ruta de farmeo |
| `/alfa comercio` | Comercio | Precios de la subasta y qué hacer con cada objeto |
| `/alfa pesca` | Pesca | Una tecla para lanzar y recoger |
| `/alfa manada` | La Jauría | Tu grupo y quienes usan Alfa y aceptan compartir; Seguir; el clan |
| (Ajustes) | Comodidades | Minimapa, colores de clase, cuadro de información, probador, vuelo, misiones y sonidos |

Alfa no depende de ningún otro addon. Versiones y notas: [`docs/VERSIONES.md`](docs/VERSIONES.md) y [`CHANGELOG.md`](CHANGELOG.md).

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
