# Alfa - Rutas (área A1 · Ruta y misiones)

Todo lo de seguir un camino: qué hacer ahora, el rastreador de pasos, la biblioteca de guías, el plan para cerrar tus misiones, recoger las de cerca y tus rutas propias. La interfaz es del Kit (`docs/KIT.md`); el motor de guías se usa como motor (`Engine`, `Guides`, `Nav`, `Dungeons.PlanStops`, `Lookup`, `QuestDB`) y sus ventanas se reemplazan.

## La regla de la ruta

**Nunca proponer una misión que todavía no se puede tomar.** `Disponible.lua` revisa nivel, previas (todas y "una de"), excluyentes, facción, raza, clase, fiestas y profesión con la base de misiones del motor (`QuestDB.CheckAvailable`) y, si no está cargada, con el Codex. Lo que falta se arma: las previas en orden (`Lookup.QuestChain`), misiones de XP hasta el nivel que pide y un paso "Llega a nivel N" (la meta `level` del motor) antes de mandarte allá. El planificador elige solo con tu nivel de verdad; la XP del plan se cuenta a la baja.

## Qué hay

| Archivo | Qué hace |
|---|---|
| `Pagina.lua` | La página **Ruta** (Aventura): la acción grande (entregar tus listas, tu guía o "¿Qué quieres hacer?"), las opciones, tu plan de misiones, tus rutas y los ajustes |
| `Rastreador.lua` | La ventana de guía de Alfa (`GUIDE_FRAME`, `GUIDE_END`): cabecera con pestañas en su menú, huellas de avance, un aviso a la vez (fin de guía, misión perdida, de grupo, **misión que aún no puedes tomar** con "Armar lo que falta", mirando otro paso), el paso con sus metas (clic: flecha; clic derecho: marcar, omitir, Enciclopedia, a tu plan), el objeto de misión, "Mientras estás aquí", Anterior · Omitir · Siguiente y la lista de pasos |
| `Camino.lua` | Elegir el camino al terminar una guía (`ROUTE_CHOICE`) |
| `Biblioteca.lua` | La biblioteca de guías (`SHOW_PICKER`): la recomendada en grande y las demás en tarjetas, con buscador y categorías |
| `Asistente.lua` | "¿Qué quieres hacer?": Subir de nivel / Profesiones / Hacer oro / Mazmorras, y en el segundo clic la opción en marcha |
| `Cerrar.lua`, `VistaMisiones.lua` | **Liberar**: el plan para cerrar tus misiones (las listas y las por terminar, con filtro y a mano), ordenado por el camino de verdad (`Nav.EstimateTravel`: vuelos, barcos y la piedra de hogar desde donde estás) con `Dungeons.PlanStops`, junto por PNJ; cada parada dice su zona y si queda lejos. Abandonar las que no valen la pena, con confirmación |
| `Recoger.lua` | **Recoger**: las mejores misiones que ya puedes tomar cerca (sin pasarte del registro). **Desbloquear**: la guía con lo que pide una misión |
| `VistaArbol.lua`, `Plan.lua`, `Indice.lua`, `Guias.lua` | Tus rutas propias como árbol de tramos (XP, oro, profesión, clase, objeto), el planificador y su paso a guías del motor (paquete `mis-rutas`) |
| `Contrato.lua` | `AlfaRuta` y el menú del registro de misiones del juego |

El catálogo de objetos se fue a la Enciclopedia (área B): su "Agregar a mi ruta" llama a `AlfaRuta.AgregarObjeto(itemID)`.

## Contrato (`AlfaRuta`)

- `Asistente(camino)`: `"nivel"`, `"profesiones"`, `"oro"`, `"mazmorras"` o nada.
- `Liberar(filtro)` (`"todas"`, `"listas"`, `"zona"`; sin él, el del jugador) y `Entregar()` (solo las listas).
- `Recoger()`, `AgregarObjeto(itemID)`.
- `AgregarMision(questID)`, `QuitarMision(questID)`, `EnPlan(questID)`, `Desbloquear(questID)`, `Disponible(questID) -> ok, texto`.
- `EsDeMiRuta(questID, verbo)`: si una guía abierta la toma (`"accept"`) o la entrega (`"turnin"`) de aquí en adelante, o si está en tu plan (también como `EnRuta`). `SoloRuta()`: el ajuste `ruta.soloRuta`.
- `Listas()`, `Biblioteca()`, `MostrarGuia()`, `RastreadorVisible()`, `Pagina()`.

## Ajustes

`ruta.soloRuta` (sí): aceptar y entregar solo las misiones de tu ruta; lo respeta "todas las misiones" de Comodidades. En la página también: `behavior.autoAccept`, `behavior.autoTurnin` (del motor), `rutas.evitarGrupo` y `rutas.margen` (1 a 4 niveles arriba).

Datos: las rutas en la cuenta (`N.Datos("rutas")`); el plan, las guías compiladas, las marcas, las agregadas a mano y el filtro por personaje (`N.DatosPersonaje("rutas")`).

## Comandos

`/alfa rutas` (la página), `liberar`, `entregar`, `recoger`, `asistente`, `guias`, `seguir`, `ayuda`.

## Para verificar en el juego

1. Con 10 o más misiones listas: la página Ruta dice "Tienes N misiones listas para entregar"; **Entregarlas ahora** arma la guía en segundos, las paradas van juntas por PNJ, en orden corto, y las de otra zona o lejos lo dicen (paso y aviso). La flecha toma vuelos y la piedra de hogar cuando conviene.
2. Clic derecho en una misión del registro del juego y del seguimiento de objetivos: "Alfa: agregar a / quitar de mi plan de misiones".
3. Filtro Todas / Listas / Esta zona y los interruptores de cada misión; "Armar mi plan" respeta lo que tocaste. Abandonar marcadas pide confirmación y abandona solo esas.
4. Rastreador: se mueve por la cabecera y recuerda su lugar; Anterior, Omitir, Siguiente; la lista de pasos; clic en una meta lleva la flecha; el menú cambia de pestaña y abre otra guía. Con una guía que manda a una misión que aún no se puede tomar, sale el aviso "Aún no puedes tomar…" con "Armar lo que falta".
5. Al terminar una guía: el aviso del rastreador y, si hay varios caminos, la ventana "¿Por dónde sigues?".
6. La biblioteca (`/alfa rutas guias`, el menú del minimapa): la recomendada arriba; categorías; abrir en pestaña nueva desde el + del rastreador.
7. El asistente: dos clics hasta tener una guía o una ruta en marcha, en los cuatro caminos.
8. Tus rutas: plantillas, tramos (cantidad, subir, bajar, quitar), misiones (cambiar, fijar, quitar), compartir e importar; una ruta de clase que pide más nivel muestra "+N de XP antes" y el paso "Llega a nivel N".
