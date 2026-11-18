# Alfa - Enciclopedia

La wiki del juego dentro de Alfa: **todos** los objetos, monturas, mascotas, PNJ, misiones, zonas y raros, aunque no los tengas, con dónde conseguirlos y cómo llegar. Reemplaza el buscador del motor (`SHOW_LOOKUP`) y su sección de raros (`SHOW_RARES`). Todo es código propio de Alfa sobre los datos del motor (`Alfa_Codex`, `Alfa_ItemDB`, `Lookup`): no copia datos.

- **Ventana** (`K.Ventana` + `K.ListaFicha`): buscador en español o en inglés (también `#12345` por número), los tipos con cuántos encuentra cada uno (si el tuyo no tiene nada y otro sí, cambia solo), los filtros del tipo y la lista virtual con la ficha.
- **Filtros:** objetos por tipo, subtipo (solo si el tipo tiene varios), calidad, nivel, ranura y "Puedo usar" (clase, armadura, armas, nivel y profesión, con el motor de equipo); PNJ por oficio; misiones por nivel y "Para mí"; raros y tesoros, y "En mi zona". Las opciones salen de lo que hay.
- **Ficha:** primero lo mejor para ti y los botones (Guíame, Qué me falta, Ver en el mapa, Agregar a Mis planes o a Cerrar mis misiones, Vincular); después una sección por fuente con datos (las vacías no aparecen):
  - objeto: estadísticas; quién lo vende (precio, pocas unidades), quién lo suelta (probabilidad, nivel, zona y coordenadas), mazmorras y bandas (jefe y probabilidad), misiones que lo dan, cómo se fabrica (profesión, nivel y la receta que lo enseña), bancos de peces, cofres y plantas, contenedores, reputación, honor, botín del mundo; lo que contiene, las misiones que lo piden o que empieza;
  - PNJ y raro: dónde está (lo más cerca primero), lo que vende, lo que suelta, sus misiones (da, recibe, piden derrotarlo) y, si es raro, cuándo y dónde lo vieron en tu reino;
  - misión: si la puedes tomar (y por qué no, con el texto de la ruta), quién la da, qué hay que hacer, dónde se entrega, recompensas, antes y después;
  - zona: niveles, mazmorras, misiones (las tuyas primero), raros, tesoros y servicios (vuelo, posada, banco, instructores...).
- Cada fila lleva a la ficha de lo que nombra (Volver regresa), pone la flecha o arma la guía a esa fuente.
- **Monturas y mascotas** (`Coleccion.lua`, 1.1.0): sus propios tipos en la ventana y en la página. Son todos los objetos de los grupos `mount` (139) y `pet` (97) del Codex, más las monturas que son un hechizo: las de clase del Codex (brujo y paladín, con la misión que las da) y las del diario del juego que el Codex conoce o que ya tienes. Cada fila dice cómo se consigue (vendedor y precio, botín, misión, profesión, reputación, JcJ, de clase, Legado u otras), el nivel, el bando y si ya la tienes. Filtros: se pueden conseguir / para ti ahora / ya no se consiguen, las que tengo o me faltan, fuente y bando. La ficha suma "Qué pide" (nivel, equitación de aprendiz u oficial, bando, reputación, precio), lo que falta antes (el instructor de equitación de tu raza) y el texto del diario de monturas. "Agregar a Mis planes" (`AlfaPlanes.AgregarObjeto`) en toda ficha de objeto ("Agregar a mi ruta" solo si ya tienes una ruta propia).
  - **Si ya la tienes:** montura: `C_MountJournal` (`GetMountFromItem`/`GetMountFromSpell` + `GetMountInfoByID`), luego `GetCompanionInfo("MOUNT")`, luego el libro de hechizos; mascota: `GetCompanionInfo("CRITTER")`, luego `C_PetJournal` (`GetPetInfoByItemID` + `GetNumCollectedInfo` o `GetOwnedPetIDs`), luego el libro; y el objeto en las bolsas ("úsala para aprenderla"). Sin nada de eso: "el juego no dice".
  - **Mi primera montura** (guía, `kind = "guia", id = "montura"`): tu nivel, tu equitación, el costo de entrenar (con la rebaja del motor, `QoL.Riding.EffectiveCost`), la montura más barata de tu raza, tu oro y lo que falta; a quién ir (instructor y vendedor de tu raza, con flecha y Guíame), las monturas de tu raza y tu montura de clase.
- **Puntos del legado** (`Legado.lua`, guía `id = "legado"`): qué son, cómo se gana cada uno (65 retos de 1 punto al salir Forever), en qué se gastan (tres árboles, tope de 16 por personaje), el registro del Legado y el modo extremo, con lo confirmado y sus fuentes (Blizzard, warcraft.wiki.gg, Icy Veins, Method). Del juego: tus puntos para gastar, gastados y tope (`C_Traits.GetTreeCurrencyInfo` de los árboles 1187-1189), los ganados en la cuenta (`C_MajorFactions`, registro 2802), todos tus retos con su avance (`GetCategoryList` + `GetAchievementInfo`) y los premios del registro; "Abrir el Legado del juego": lo abre el juego con un botón seguro sobre su `LegacyMicroButton` (`K.Seguro`); Alfa nunca llama `ToggleLegacySystemUI`, porque una ventana de Blizzard abierta desde un addon queda marcada y el juego bloquea después sus acciones.
- **Guíame** cierra las ventanas de Alfa y muestra la de seguimiento (`N.EmpezarRuta`).
- **Rendimiento:** nada se carga al entrar al juego. Al abrir la ventana se carga el Codex y, por lotes de unos milisegundos por cuadro (en pausa durante el combate), los catálogos, las facetas y los índices al revés. Las listas al revés se guardan como texto. Unos 14 MB con todo armado.

## Contratos

- `AlfaEnciclopedia.Abrir(tipo, id)`: `tipo` de Alfa (`"objeto"`, `"montura"`, `"mascota"`, `"pnj"`, `"mision"`, `"zona"`, `"raro"`, o `"guia"` con `"montura"` o `"legado"`) o del motor (`"item"`, `"npc"`, `"quest"`, `"zone"`, `"rare"`, `"treasure"`, `"object"`, `"instance"`); sin id abre la lista entera de ese tipo. También `.Buscar(texto)`, `.Cerrar()`, `.Visible()`.
- Usa `AlfaRuta.AgregarObjeto`, `AgregarMision`, `QuitarMision`, `EnPlan`, `Disponible` y `Desbloquear` (A1), y `AlfaMundo.SeguirPunto`, `Abrir` y `RegistrarCapa` (H), si existen.
- Comandos: `/alfa enciclopedia [texto]` (y `/alfa wiki`), `/alfa monturas`, `/alfa mascotas`, `/alfa legado`; `/alfa lookup` y `/alfa rares` también la abren.

## Para verificar en el juego

1. `/alfa enciclopedia`: la primera vez, "Preparando…" unos segundos y luego la lista; sin tirones al moverte mientras se prepara.
2. Busca "paño de lino" y "linen cloth": el mismo objeto. Prueba un nombre de PNJ en la pestaña Objetos: salta sola a PNJ.
3. Filtros: Armas > Espada de una mano > Puedo usar; que los tipos y subtipos vengan con su nombre del cliente y que "Puedo usar" respete tu clase.
4. Ficha de un objeto: los íconos con su calidad, el cuadro del juego al pasar el ratón, Mayús+clic enlaza, "Vincular" pone el enlace en el chat abierto.
5. Guíame abre una guía en una pestaña nueva; la flecha de una fila apunta bien (también en zonas reformadas de Forever).
6. "Ver en el mapa" pinta los lugares en el mapa de Alfa y en el del juego, y abre el mapa en la zona; "Quitar del mapa" los borra.
7. Alt+clic en un objeto de tus bolsas abre su guía o, si no hay, su ficha. El aviso de un raro y `/alfa rares` abren la ficha del raro.
8. Una misión de la otra facción o con previas dice por qué; "Qué me falta" y "Agregar a Cerrar mis misiones" llaman a la ruta.
9. Ficha de un PNJ vendedor: lo que vende con su precio; de un enemigo: lo que suelta con su probabilidad.
10. Ficha de una zona: misiones, raros y servicios aparecen solos al terminar de prepararse.
11. Monturas: con el diario de monturas del juego, las que tienes dicen "ya la tienes" (y "Las que tengo" las filtra); una montura en tus bolsas dice "en tus bolsas". Mascotas: lo mismo (aquí se sabe menos: confirma que el juego conteste).
12. Monturas de clase (brujo, paladín): la ficha muestra la cadena de misiones y Guíame lleva a la primera que puedes tomar.
13. Mi primera montura: el costo de entrenar y el de la montura coinciden con lo que cobra el instructor y el vendedor de tu raza; la flecha llega a los dos.
14. Puntos del legado: tus puntos (para gastar, gastados, tope, ganados) coinciden con la ventana del Legado (tecla Y); los retos y su avance aparecen; "Abrir el Legado del juego" la abre.
15. Guíame cierra la enciclopedia y muestra la ventana de seguimiento; "Agregar a Mis planes" agrega el objeto a tus planes.
