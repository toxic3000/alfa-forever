# Alfa - Rutas

Página **Rutas** (orden 12) de la ventana de Alfa, con tres pestañas:

- **Mi ruta**: un árbol de tramos en orden. Cada tramo es una rama (XP, Oro, Profesión, Clase u Objeto) con su cantidad ("3 misiones de XP", "20 de Mena de cobre"). Alfa elige las misiones con el Codex del motor (nivel, facción, raza y clase, cercanía, XP, oro estimado, recompensas, cadenas de clase) y cada una se cambia, se quita o se fija con un clic. Plantillas: Subir rápido, Equilibrada, Hacer oro, Profesión y Recomendada por Alfa. **Seguir esta ruta** la convierte en una guía del motor (paquete `mis-rutas`): flecha, pasos, mapa y pestañas del motor, y en el menú de guías aparece bajo **Mis rutas**.
- **Liberar misiones**: revisa tu registro y arma una guía con el orden más corto (el planificador de paradas del motor, `Dungeons.PlanStops`) para terminar y entregar todo. Marca las que no valen la pena (fallidas, grises, muy lejos; las de grupo o mazmorra quedan fuera) y las abandona con un clic y confirmación.
- **Catálogo de objetos**: los ~23 000 objetos del Codex en una lista virtual, con búsqueda y filtros (tipo, subtipo, calidad, nivel, ranura, "Puedo usar"). La ficha muestra calidad, estadísticas y de dónde sale (Lookup del motor), con **Guíame** (guía al momento del motor), **Agregar a mi ruta** (un tramo Objeto; si sigues esa ruta, tu guía se actualiza), **Vincular en el chat** y **Buscador**.

Las rutas se guardan en la cuenta (`N.Datos("rutas")`) y se comparten con **Compartir / Importar** (texto `!ALFARUTA1!...`). El plan, la guía compilada y las marcas del registro son de cada personaje (`N.DatosPersonaje("rutas")`); las guías guardadas se registran otra vez al cargar, antes de que el motor reabra las pestañas.

## Comandos

- `/alfa rutas`: abre la página.
- `/alfa rutas liberar`: arma y abre la guía para entregar tus misiones abiertas.
- `/alfa rutas catalogo`: abre el catálogo.
- `/alfa rutas seguir`: sigue (o actualiza) tu ruta.

## Ajustes

En el botón de ajustes de la pestaña Mi ruta: evitar misiones de grupo (`rutas.evitarGrupo`) y cuántos niveles arriba del tuyo se aceptan (`rutas.margen`, 1 a 4). En el catálogo: solo lo que puedo usar (`rutas.soloUsables`) y mostrar lo que ya no se consigue (`rutas.verRetirados`).

## Para verificar en el juego

1. `/alfa rutas`: la página entra completa sin barra de desplazamiento de la ventana; el árbol, el detalle y el pie no se encimen (skins Alfa, Halo y Blizzard).
2. Plantilla **Equilibrada**: "Alfa está armando tu ruta..." dura pocos segundos y no congela; las misiones elegidas son de tu facción y nivel, y cerca.
3. **Seguir esta ruta**: abre una pestaña nueva, la flecha apunta al primer PNJ, y en el menú de guías aparece "Mis rutas" con la ruta. Tras `/reload` la pestaña sigue ahí.
4. En una misión del tramo: Cambiar por otra / Quitar / Fijar; Recalcular conserva las fijas.
5. Tramo de Profesión con Minería: la meta "Junta 20 de Mena de cobre" recorre los nodos y se completa al tener 20 en las bolsas.
6. Liberar misiones: el orden tiene sentido; **Abandonar marcadas** pide confirmación y abandona solo esas (`C_QuestLog.AbandonQuest` sin bloqueo de "AddOn bloqueado").
7. Catálogo: los tipos y subtipos salen con los nombres del cliente en español; Espadas junta una y dos manos; "Puedo usar" oculta lo que tu clase no lleva.
8. Guíame, Agregar a mi ruta (con la ruta en seguimiento, la pestaña se actualiza sola) y Vincular en el chat (con y sin la caja de chat abierta).
9. Compartir una ruta, borrarla e importarla otra vez.
