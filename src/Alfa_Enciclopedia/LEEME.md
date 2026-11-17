# Alfa - Enciclopedia

La wiki del juego dentro de Alfa: **todos** los objetos, PNJ, misiones, zonas y raros, aunque no los tengas, con dónde conseguirlos y cómo llegar. Reemplaza el buscador del motor (`SHOW_LOOKUP`) y su sección de raros (`SHOW_RARES`). Todo es código propio de Alfa sobre los datos del motor (`Alfa_Codex`, `Alfa_ItemDB`, `Lookup`): no copia datos.

- **Ventana** (`K.Ventana` + `K.ListaFicha`): buscador en español o en inglés (también `#12345` por número), los tipos con cuántos encuentra cada uno (si el tuyo no tiene nada y otro sí, cambia solo), los filtros del tipo y la lista virtual con la ficha.
- **Filtros:** objetos por tipo, subtipo (solo si el tipo tiene varios), calidad, nivel, ranura y "Puedo usar" (clase, armadura, armas, nivel y profesión, con el motor de equipo); PNJ por oficio; misiones por nivel y "Para mí"; raros y tesoros, y "En mi zona". Las opciones salen de lo que hay.
- **Ficha:** primero lo mejor para ti y los botones (Guíame, Qué me falta, Ver en el mapa, Agregar a mi ruta o a mi plan, Vincular); después una sección por fuente con datos (las vacías no aparecen):
  - objeto: estadísticas; quién lo vende (precio, pocas unidades), quién lo suelta (probabilidad, nivel, zona y coordenadas), mazmorras y bandas (jefe y probabilidad), misiones que lo dan, cómo se fabrica (profesión, nivel y la receta que lo enseña), bancos de peces, cofres y plantas, contenedores, reputación, honor, botín del mundo; lo que contiene, las misiones que lo piden o que empieza;
  - PNJ y raro: dónde está (lo más cerca primero), lo que vende, lo que suelta, sus misiones (da, recibe, piden derrotarlo) y, si es raro, cuándo y dónde lo vieron en tu reino;
  - misión: si la puedes tomar (y por qué no, con el texto de la ruta), quién la da, qué hay que hacer, dónde se entrega, recompensas, antes y después;
  - zona: niveles, mazmorras, misiones (las tuyas primero), raros, tesoros y servicios (vuelo, posada, banco, instructores...).
- Cada fila lleva a la ficha de lo que nombra (Volver regresa), pone la flecha o arma la guía a esa fuente.
- **Rendimiento:** nada se carga al entrar al juego. Al abrir la ventana se carga el Codex y, por lotes de unos milisegundos por cuadro (en pausa durante el combate), los catálogos, las facetas y los índices al revés. Las listas al revés se guardan como texto. Unos 14 MB con todo armado.

## Contratos

- `AlfaEnciclopedia.Abrir(tipo, id)`: `tipo` de Alfa (`"objeto"`, `"pnj"`, `"mision"`, `"zona"`, `"raro"`) o del motor (`"item"`, `"npc"`, `"quest"`, `"zone"`, `"rare"`, `"treasure"`, `"object"`, `"instance"`); sin id abre la lista entera de ese tipo. También `.Buscar(texto)`, `.Cerrar()`, `.Visible()`.
- Usa `AlfaRuta.AgregarObjeto`, `AgregarMision`, `QuitarMision`, `EnPlan`, `Disponible` y `Desbloquear` (A1), y `AlfaMundo.SeguirPunto`, `Abrir` y `RegistrarCapa` (H), si existen.
- Comandos: `/alfa enciclopedia [texto]` (y `/alfa wiki`); `/alfa lookup` y `/alfa rares` también la abren.

## Para verificar en el juego

1. `/alfa enciclopedia`: la primera vez, "Preparando…" unos segundos y luego la lista; sin tirones al moverte mientras se prepara.
2. Busca "paño de lino" y "linen cloth": el mismo objeto. Prueba un nombre de PNJ en la pestaña Objetos: salta sola a PNJ.
3. Filtros: Armas > Espada de una mano > Puedo usar; que los tipos y subtipos vengan con su nombre del cliente y que "Puedo usar" respete tu clase.
4. Ficha de un objeto: los íconos con su calidad, el cuadro del juego al pasar el ratón, Mayús+clic enlaza, "Vincular" pone el enlace en el chat abierto.
5. Guíame abre una guía en una pestaña nueva; la flecha de una fila apunta bien (también en zonas reformadas de Forever).
6. "Ver en el mapa" pinta los lugares en el mapa de Alfa y en el del juego, y abre el mapa en la zona; "Quitar del mapa" los borra.
7. Alt+clic en un objeto de tus bolsas abre su guía o, si no hay, su ficha. El aviso de un raro y `/alfa rares` abren la ficha del raro.
8. Una misión de la otra facción o con previas dice por qué; "Qué me falta" y "Agregar a mi plan" llaman a la ruta.
9. Ficha de un PNJ vendedor: lo que vende con su precio; de un enemigo: lo que suelta con su probabilidad.
10. Ficha de una zona: misiones, raros y servicios aparecen solos al terminar de prepararse.
