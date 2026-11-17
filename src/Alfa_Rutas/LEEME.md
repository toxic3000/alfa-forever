# Alfa - Rutas (área A1 · Ruta y misiones)

Todo lo de seguir un camino: qué hacer ahora, el rastreador de pasos, la biblioteca de guías, el plan para cerrar tus misiones, recoger las de cerca y tus rutas propias. La interfaz es del Kit (`docs/KIT.md`); el motor de guías se usa como motor (`Engine`, `Guides`, `Nav`, `Dungeons.PlanStops`, `Lookup`, `QuestDB`) y sus ventanas se reemplazan.

## La regla de la ruta

**Nunca mandarte a una misión que no puedes hacer, a menos de que la ruta agregue lo que falta (sin preguntar).** `Disponible.lua` revisa nivel, previas (todas y "una de"), excluyentes, facción, raza, clase, fiestas, profesión y reputación con la base de misiones del motor (`QuestDB`), el Codex (previas, nivel, reputación) y el juego (hechas, registro, profesiones, reputaciones). `Disp.Resolver` arma lo que falta, recursivo (hasta 10 previas de hondo, sin ciclos): de las "una de", la que ya tienes o la más corta que se pueda. Lo que se arregla haciendo misiones se agrega antes, en orden (las previas; si falta nivel, misiones de XP y un paso "Llega a nivel N", la meta `level` del motor) y la misión dice `antes` ("Antes: …"). Lo que no (otra facción, raza o clase, fiesta, excluyente hecha, profesión que no tienes, reputación que no alcanzas) la deja fuera con su motivo. El planificador elige solo con tu nivel de verdad; la XP del plan se cuenta a la baja.

En las guías del motor (parches `REQUISITOS` de `tools/parches.py`, por `Alfa.Requisitos`): `Disp.Bloqueo` cierra la aceptación y sus metas (estado "skipped", `noDisponible` = motivo en la vista de la meta) salvo que el PNJ ya la haya ofrecido; una previa que ninguna guía anterior da entra como paso de alimentación armado por Alfa (`Disp.Cadena`, con las reglas del motor: en las zonas de la guía y barata) y la aceptación que abre trae `antes` (también "Guíame" de la Enciclopedia: la misión buscada dice sus previas). Mis planes: `Tarjeta()` trae `antes` y `noDisponible` en una meta de misión. Prueba con los datos de verdad: `.venv/Scripts/python -I tools/prueba_requisitos.py`.

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
| `Cerca.lua`, `Bindings.xml` | **Buscar cerca** (`AlfaCerca`): maestro de vuelo, posadero, reparar, banco, buzón, casa de subastas, entrenador de tu clase, entrenadores de profesión (las tuyas primero), vendedor (comida y bebida, mercancías, munición si la usas), componentes (no guerrero ni cazador) y establos (cazador). Cada fila dice el más cercano, su zona y el tiempo de camino (`Alfa.Nav.nearby.Find`, una búsqueda por cuadro al abrir, válida 25 s o hasta moverte 40 yardas); clic: `Nearby.Go` (flecha y ruta) y un aviso con el lugar. Combate, datos del mundo faltantes o apagados y "ninguno para tu facción" se dicen en español. Una tecla en Atajos > Alfa |
| `Planes.lua`, `VistaPlanes.lua` | **Mis planes** (`AlfaPlanes`): listas de metas propias en tu orden, sus plantillas, el avance en vivo y el editor (ver abajo) |

El catálogo de objetos se fue a la Enciclopedia (área B): su "Agregar a mi ruta" llama a `AlfaRuta.AgregarObjeto(itemID)`.

## Contrato (`AlfaRuta`)

- `Asistente(camino)`: `"nivel"`, `"profesiones"`, `"oro"`, `"mazmorras"` o nada.
- `Liberar(filtro)` (`"todas"`, `"listas"`, `"zona"`; sin él, el del jugador) y `Entregar()` (solo las listas).
- `Recoger()`, `AgregarObjeto(itemID)`.
- `AgregarMision(questID)`, `QuitarMision(questID)`, `EnPlan(questID)`, `Desbloquear(questID)`, `Disponible(questID) -> ok, texto`.
- `EsDeMiRuta(questID, verbo)`: si una guía abierta la toma (`"accept"`) o la entrega (`"turnin"`) de aquí en adelante, o si está en tu plan (también como `EnRuta`). `SoloRuta()`: el ajuste `ruta.soloRuta`.
- `Listas()`, `Biblioteca()`, `MostrarGuia()`, `RastreadorVisible()`, `Pagina()`.

## Buscar cerca (`AlfaCerca`)

- `AlfaCerca.Menu(ancla)`: abre o cierra el menú junto a `ancla` (sin ancla, junto al cursor). Páginas: inicio, `"oficios"`, `"vendedor"` (`Menu(ancla, pagina)`).
- `AlfaCerca.Ir(tipo, linea) -> bool`: la flecha al más cercano. `tipo`: los del motor (`flight`, `innkeeper`, `repair`, `bank`, `mailbox`, `auction`, `class`, `trainer`, `vendor`, `food`, `general`, `arrows`, `bullets`, `ranged`, `reagents`, `stable`) o en español (`vuelo`, `posada`, `reparar`, `banco`, `buzon`, `subasta`, `entrenador`, `oficio`, `vendedor`, `comida`, `componentes`, `establo`...); `linea`: la profesión del entrenador.
- `AlfaCerca.Tipos()`: los de la portada para este personaje (`{ tipo, nombre, icono, pagina }`). `Texto(tipo, linea)`: lo último sabido, sin buscar. `Nombre(tipo, linea)`, `Cerrar()`, `Visible()`. Interno: `M.Cerca.Lugar(tipo, linea)` (el lugar, para Mis planes).
- Entradas: la lupa de la cabecera del rastreador (`rutas.cercaBoton`) y su menú «Buscar cerca...», la tarjeta de la página Ruta, `/alfa cerca [tipo] [profesión]` (`/alfa cerca minería`, `/alfa cerca ayuda`), la tecla `ALFA_RUTAS_CERCA` y la fila de Hoy (`rutas.cercaHoy`). El mapa de Alfa llama `AlfaCerca.Menu(self)` desde su cabecera.

## Mis planes (`AlfaPlanes`)

Un plan es una lista ordenada de metas (en la cuenta; lo hecho, por personaje). Metas: **conseguir un objeto** (búsqueda del Codex, cantidad; hecha con tus bolsas; *Guíame* = `Lookup.Guide`), **juntar oro** (`GetMoney`; ayuda: el asistente de oro), **subir una profesión** (nivel 1 = aprenderla; *A su entrenador* con Buscar cerca), **ir a un lugar** (un servicio cercano, un marcador de `AlfaMundo`, donde estás o la entrada de una mazmorra; hecha a 25 yardas), **una misión** (tomarla, completarla o entregarla; *Llévame* = el plan para cerrar misiones o `Recoger.Desbloquear`), **llegar a un nivel** y **nota libre** (la marcas tú). La meta de ahora se ve en el rastreador (con *Llévame* y *Ya la hice*) y en Hoy; al pasar a una meta con lugar la flecha va sola (`rutas.planFlecha`). Las metas pasadas quedan marcadas aunque después gastes el oro.

Plantillas (solo las que sirven a tu personaje, con datos del juego): *Preparar la mazmorra* (la recomendada de `AlfaMazmorras` y su entrada del motor), *Mi primera montura* y *Oro para la montura* (costo de `QoL.Riding.EffectiveCost`, entrenador de equitación de tu raza), *Subir cocina y pesca juntas* (Caña de pescar, 6256).

- `AlfaPlanes.Lista()`, `Activo()`, `Seguir(id)`, `Dejar()`, `Nuevo(nombre)` (abre el editor), `Abrir(id)`, `Tarjeta()` (la meta de ahora: `{ plan, meta, hechas, total, titulo, texto, frac, icono, ir = { texto, fn }, hecha, fin }`), `AgregarMeta(id, meta)`, `AgregarObjeto(itemID, cantidad)` (al plan activo o a uno nuevo; para la Enciclopedia).
- Mensaje del motor `ALFA_PLAN`: cambió un plan o la meta de ahora (Hoy se acomoda).
- Entradas: la sección *Mis planes* de la página Ruta (Nuevo plan, tus planes, plantillas con *Empezar* y *Copiar y editar*), el asistente (*Mi propio plan*, `AlfaRuta.Asistente("planes")`), el rastreador y Hoy.

## Ajustes

`ruta.soloRuta` (sí): aceptar y entregar solo las misiones de tu ruta; lo respeta "todas las misiones" de Comodidades. En la página también: `behavior.autoAccept`, `behavior.autoTurnin` (del motor), `rutas.evitarGrupo` y `rutas.margen` (1 a 4 niveles arriba). Grupo *Buscar cerca y tus planes* (todos encendidos): `rutas.cercaBoton` (la lupa del rastreador), `rutas.cercaHoy` (la fila de Hoy), `rutas.cercaAviso` (el aviso al poner la flecha) y `rutas.planFlecha` (la flecha va sola a la meta con lugar).

Datos: las rutas y tus planes (`misPlanes`) en la cuenta (`N.Datos("rutas")`); el plan que sigues (`planActivo`) y sus metas hechas (`planHechas`) por personaje; el plan, las guías compiladas, las marcas, las agregadas a mano y el filtro por personaje (`N.DatosPersonaje("rutas")`).

## Comandos

`/alfa rutas` (la página), `liberar`, `entregar`, `recoger`, `asistente`, `guias`, `seguir`, `ayuda`. `/alfa cerca [tipo] [profesión]`: sin nada abre el menú; `ayuda` lista los tipos.

## Para verificar en el juego

1. Con 10 o más misiones listas: la página Ruta dice "Tienes N misiones listas para entregar"; **Entregarlas ahora** arma la guía en segundos, las paradas van juntas por PNJ, en orden corto, y las de otra zona o lejos lo dicen (paso y aviso). La flecha toma vuelos y la piedra de hogar cuando conviene.
2. Clic derecho en una misión del registro del juego y del seguimiento de objetivos: "Alfa: agregar a / quitar de mi plan de misiones".
3. Filtro Todas / Listas / Esta zona y los interruptores de cada misión; "Armar mi plan" respeta lo que tocaste. Abandonar marcadas pide confirmación y abandona solo esas.
4. Rastreador: se mueve por la cabecera y recuerda su lugar; Anterior, Omitir, Siguiente; la lista de pasos; clic en una meta lleva la flecha; el menú cambia de pestaña y abre otra guía. Con una guía que manda a una misión que aún no se puede tomar, sale el aviso "Aún no puedes tomar…" con "Armar lo que falta".
5. Al terminar una guía: el aviso del rastreador y, si hay varios caminos, la ventana "¿Por dónde sigues?".
6. La biblioteca (`/alfa rutas guias`, el menú del minimapa): la recomendada arriba; categorías; abrir en pestaña nueva desde el + del rastreador.
7. El asistente: dos clics hasta tener una guía o una ruta en marcha, en los cuatro caminos.
8. Tus rutas: plantillas, tramos (cantidad, subir, bajar, quitar), misiones (cambiar, fijar, quitar), compartir e importar; una ruta de clase que pide más nivel muestra "+N de XP antes" y el paso "Llega a nivel N".
9. Buscar cerca: la lupa del rastreador abre el menú; las filas se llenan una a una con el más cercano, su zona y los minutos (en una capital y en una zona sin ciudad). Clic: flecha y ruta, el aviso con *Volver a la guía* y la línea del motor en el chat. En combate antes de cargar los datos: "Después del combate". Entrenadores de profesión con las tuyas arriba; munición solo si usas arco o arma de fuego; establos solo el cazador. `/alfa cerca vuelo`, `/alfa cerca minería`, la tecla y la fila de Hoy. Esc y clic fuera lo cierran.
10. Mis planes: crear un plan con las siete metas (buscar un objeto y una misión por nombre, un marcador del mapa, donde estás, una mazmorra), subir, bajar, editar, marcar, quitar, duplicar y borrar. Seguirlo: el rastreador muestra la meta de ahora, *Ya la hice* avanza, al cumplirse (comprar el objeto, juntar el oro, subir la profesión, llegar) sale "Meta cumplida" y la flecha va sola al siguiente lugar. Las cuatro plantillas con *Empezar* y *Copiar y editar*. Hoy muestra *Tu plan* solo si sigues uno.
