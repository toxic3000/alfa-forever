# Alfa — guía a tu manada

El todo en uno de **La Jauría** para World of Warcraft: Forever. Junta en un solo addon las guías, el mapa, las bolsas, los builds, la pesca, el comercio y tu manada. Reemplaza a Polestar Guides, Baganator, Syndicator, Better Fishing, DBM, DungeonJournal, GatherLite, Leatrix Maps, Leatrix Plus, OpenMap, Pawn y Sonah.

Hecho por Toxic y La Jauría — [Discord](https://discord.gg/hUNjA6BJwh). Software libre bajo la GPL-3.0, construido sobre [Polestar](https://github.com/fitzforge/polestar) (GPL-3.0). Los créditos completos están en `NOTICE-ALFA.txt`, en la página «Acerca de» del juego y en el `CREDITOS.md` de cada módulo.

## Módulos

| Comando | Módulo | Qué hace |
|---|---|---|
| `/alfa` | Guía (motor) | Guías por zona, flecha, rutas, buscador, mazmorras y raros |
| `/alfa inicio` | Inicio | Sesión, diario, recordatorios y tu siguiente paso |
| `/alfa manada` | La Jauría | Tu grupo, tu hermandad y tus amigos en el mapa, Seguir, y la página del clan |
| `/alfa rutas` | Rutas | Árbol de ruta propio, liberar misiones y catálogo de objetos |
| `/alfa builds` | Builds | Talentos por objetivo y estilo, pesos, equipo meta y ayuda en combate |
| `/alfa mapa` | Mundo | Mapa continuo con un solo control de capas y modo limpio |
| `/alfa recoleccion` | Recolección | Nodos, pines y ruta de farmeo |
| `/alfa bolsas` | Bolsas | Bolsas, banco e inventario de todos tus personajes |
| `/alfa comercio` | Comercio | Precios de la subasta y qué hacer con cada objeto |
| `/alfa mazmorras` | Mazmorras | Botín por jefe, consejos y modo historia |
| `/alfa pesca` | Pesca | Una tecla para lanzar y recoger |
| (Calidad de vida) | Comodidades | Lo de Leatrix Plus que el motor no hacía |

## Construir e instalar

```bash
python -I tools/fetch_upstream.py 0.3.7.2       # una vez: Polestar verificado
python -I tools/build.py                        # arma dist/
.venv/Scripts/python -I tools/revisar.py        # sintaxis Lua 5.1 + TOC/XML
.venv/Scripts/python -I tools/humo.py           # módulos con el juego simulado
python -I tools/instalar.py                     # simula la instalación
python -I tools/instalar.py --aplicar           # instala (con WoW cerrado)
```

Contrato de los módulos y reglas de Forever: `docs/ARQUITECTURA.md`. Plan y pendientes: `docs/PLAN.md`.
