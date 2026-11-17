# Alfa - Lya

**Lya, la loba de confianza del Alfa**: una loba negra chiquita que te acompaña en pantalla con consejos cortos, ánimo y atajos a lo que Alfa sabe hacer. No es una mascota del juego: es un marco de la interfaz hecho con el Kit (`docs/KIT.md`). Lleva el nombre de Lya, una gran perrita, en su memoria (la tarjeta «Sobre Lya» de su página). Todo es código y arte propios de Alfa (GPL-3.0).

## Qué hace

- **En pantalla** (`Lya.lua`): una loba negra de cuerpo completo en pixel art que mira hacia el centro de la pantalla; se arrastra y recuerda su lugar, y con «Bloquear posición» se queda fija. Está viva: respira y mueve la cola, parpadea, se pone atenta (las orejas paradas) cuando te ofrece algo, se sienta a pedir comida (la manita arriba, la lengua de fuera y un huesito) cuando dice que tiene hambre, aúlla al subir de nivel, salta con las buenas noticias y se duerme enroscada (con sus «z») si estás ausente o llevas 5 minutos descansando. Entre globos, de vez en cuando, se busca la cola, sale corriendo y regresa a su lugar, se estira con un bostezo o se sienta un rato. En combate se queda quieta y tenue. Su contorno toma el acento del estilo (el oro en Clásico WoW) y va parada sobre su lugar: una elipse fina del mismo color con el rombo de Alfa que respira despacio, y su sombra. Sin cuadro de fondo; cambia sola con Alfa, Clásico WoW y Cristal.
- **Su globo**: «Lya: …» en hasta 3 líneas, con hasta dos botones que llevan a algo de verdad (Buscar cerca, entregar tus misiones, abrir una página de Alfa...). Se va solo a los 8 s (12 con botones; no con el ratón encima). Clic en Lya: un consejo cuando quieras.
- **Clic derecho**: Silenciar 1 hora · Cuéntame algo de aquí · Cuéntame algo · Háblame de mi gente · Historias de tus misiones · Consejos: muchos / pocos / solo importantes (una fila que pasa a la siguiente con cada clic) · Bloquear posición · Volver a mostrar los consejos vistos · Ajustes de Lya · Ocultar a Lya (10 filas: las líneas entre grupos, mientras quepan).

## Historias y datos curiosos (`Historias.lua`, `VentanaHistorias.lua`, `Lore.lua`)

Seguir la flecha hace que uno se salte la historia: Lya la guarda y te la cuenta si quieres.

- **Lo que guarda** (por eventos): `QUEST_DETAIL` (`GetTitleText`, `GetQuestText`, `GetObjectiveText`, quien te la da: `UnitName("questnpc")` o el objeto que la empieza), `QUEST_ACCEPTED`, `QUEST_PROGRESS` (`GetProgressText`), `QUEST_COMPLETE` (`GetRewardText`, con quién se entrega), `QUEST_TURNED_IN`; las que ya estaban en tu registro, una vez por sesión con `GetQuestLogQuestText` (si el cliente solo lee la elegida, se elige un instante y se devuelve, nunca en combate ni con el registro abierto). Zona (`C_Map`, subiendo de cuevas y pisos a su zona) y fecha. Los textos son los del juego, en el idioma de tu cliente; un valor secreto no se guarda.
- **Dónde**: `N.Datos("lya").historias.q[questID] = { t, d, o, p, r, g, e, z, zn, a, c, u, l }` (la cuenta: las 500 más recientes y 450 000 letras como mucho). Por personaje (`hist`): `ganchos`, `finales`, `zonas`, `datos`, `ultima`, `ultimaDato`.
- **Lya lo cuenta**: al tomar una misión dice un gancho corto con sus palabras (el PNJ y un tema que saca del texto: la Plaga, los múrlocs, los Defias... y si hay lobos, «me toca de cerca») con **Contármela**, que abre Historias en esa misión. Nunca el texto largo en el globo. Al entregarla, si quieres, «¿Te cuento el final?» con **Contármelo** (la ventana baja al final).
- **Datos curiosos** (`Lore.lua` y `LoreMas.lua`, notas propias de una o dos frases con su inglés en `Textos.lua`): 285 notas de 47 zonas (Kalimdor, los Reinos del Este, las 6 capitales y el Monte Hyjal) por uiMapID (1411-1458, 2482) y 202 del lore del mundo (titanes y dragones, la Guerra de los Ancestros, los trols, los reinos humanos, las tres guerras, la Plaga, otros pueblos, lugares, objetos, facciones y curiosidades; Burning Crusade solo de contexto). `LoreMas.lua` suma las nuevas al final de cada lista, sin mover los ids. Uno al entrar por primera vez a una zona con ese personaje (y al volver a una que todavía tiene algo que contar), al pedirlo (**Cuéntame algo de aquí**: con *Otro dato* e *Historias*) y en la plática de los ratos tranquilos (abajo).
- **La plática** (`Charla.lua`, con `Saberes.lua`): lo que dice en los ratos tranquilos, en rondas barajadas de ocho turnos entre el lugar (lo que no te ha contado de esa zona; al cambiar de zona va primero), el lore (dos turnos), lo tuyo (dos turnos: tu raza por `UnitRace`, tu clase por `UnitClass` y tus profesiones por su línea de habilidad, con `A.Compat.GetSkillRank` o `C_SkillInfo` en pcall y sin valores secretos: 72 de raza, 54 de clase y 72 de profesiones), un consejo de amiga (72 entre eventos del Clásico en sus meses, farmeo, economía, viajes por bando y el Legado de Forever con *Ver el Legado*; o uno de los de siempre), el momento y las salchichas. Nunca la misma cosa dos veces seguidas; el lore, lo tuyo y los consejos no se agotan: sale primero lo que nunca dijo y luego lo que dijo hace más tiempo (`charla.v[id]` = la hora, por personaje). Con `historias` en `pedir` o `nunca`, el lugar, el lore y lo tuyo solo salen si los pides. **Cuéntame algo** (lore, lo tuyo o un consejo, con *Otra cosa* y *Háblame de mi gente*) y **Háblame de mi gente** (de tu raza, con *Más de mi gente*); al dar clic en Lya, a veces también sale de aquí.
- **Contra el spam** (además de las reglas de abajo): un globo de historia cada `lya.minutosHistoria` (10) como mucho, un dato automático de `Historias.lua` cada 6 min, cada gancho, final y dato una sola vez por personaje, nunca con la ventana de misión abierta. Un gancho que no pudo salir (combate, otro globo) se reintenta cada 30 s, 6 veces; si llega otro, el nuevo manda. Sin tickers.
- **La ventana Historias** (`K.Ventana`, los tres estilos): buscador (misión, PNJ, zona o palabra), filtro de zona, la lista por zona (la más reciente arriba) y la ficha: zona, título, quién te la dio y con quién se entrega, *Seguir* si sigue en tu registro (`Lookup.Guide("quest")` y `N.EmpezarRuta`; sin guía, a tu plan de misiones), *En la Enciclopedia*, y La historia, Lo que te piden, Mientras la haces y El final. Clic en una zona: lo que Lya sabe de ahí. Se abre con `/alfa historias`, `/alfa lya historias`, el clic derecho de Lya, su página y `AlfaLya.Historias(questID)`.

## A qué reacciona (`Cerebro.lua`)

| Momento | Qué dice |
|---|---|
| Primera vez, tras la bienvenida de Alfa | Se presenta (una sola vez) |
| Entrar al juego | Te saluda por tu nombre; tras 3 días o más, "hace días que no te veía" con *Abrir Hoy* |
| Subir de nivel (`PLAYER_LEVEL_UP`) | Aúlla y te felicita; en 10, 20, 30, 40 (montura, *Cómo conseguirla*), 50 y 60 algo especial |
| Morir (`PLAYER_DEAD`) | «¡Arriba, lobo!» con un consejo |
| Equipo al 30 % o menos | *Llévame a reparar* (`AlfaCerca.Ir("repair")`) |
| 2 espacios libres o menos | *Abrir bolsas* y *Llévame a un vendedor* |
| En una ciudad con habilidades por aprender (una vez por nivel) | *Llévame con mi entrenador* (`AlfaCerca.Ir("class")`) |
| 3 misiones listas o más (al subir la cuenta) | *Entregar todas* (`AlfaRuta.Entregar()` y `N.EmpezarRuta()`) |
| 10 y 25 misiones entregadas en el día | Un logro, con salto |
| 2 y 4 horas de sesión | Que descanses un poco |
| De vez en cuando y al pedirlo | «¿Sabías que…?» de Alfa (solo lo que está cargado), consejos del juego, ánimo y, muy rara vez, cariño |
| Tras 3 minutos sin hablar («pocos»: 10) | La plática (`Charla.lua`): el lugar, el lore, tu raza, clase y profesiones, un consejo de amiga, el momento o las salchichas |

Los consejos del momento se revisan con los eventos del juego (`UPDATE_INVENTORY_DURABILITY`, `BAG_UPDATE_DELAYED`, `QUEST_LOG_UPDATE`, `PLAYER_UPDATE_RESTING`, juntados a 3 s) y en un latido de 60 s que solo corre con Lya a la vista. Nada en `OnUpdate`.

## Contra el spam

- Un globo cada `lya.minutos` (3) a lo más; con «pocos», el doble, y el consejo suelto cada 40 min en vez de 15. «Solo importantes»: morir, subir de nivel y los logros.
- Lo importante se salta la espera, pero nunca sale en combate, en una instancia ni mientras escribes: espera hasta 10 minutos a que se pueda. Lo demás se pierde (y se vuelve a revisar luego).
- **Cada frase sale 3 veces por personaje como mucho** y luego nunca más (`AlfaNucleoCharDB.lya.vistos`); «Volver a mostrar los consejos vistos» las devuelve. Las frases tienen varias versiones, así que no se repite la misma.
- Nunca encima del aviso de Hoy (`AlfaInicioAviso`) ni de otro globo suyo. «Silenciar 1 hora» calla todo menos lo que pides con clic.
- Mientras falte la bienvenida de Alfa (`AlfaBienvenida.Pendiente()`), Lya no aparece; al terminarla (`ALFA_CONFIGURADO`) sale y se presenta.

## Ajustes (`AlfaDB.settings.lya`) — página Personaje > Lya

| Clave | Por omisión | Qué hace |
|---|---|---|
| `mostrar` | sí | Lya en pantalla |
| `frecuencia` | `muchos` | `muchos`, `pocos` o `importantes` |
| `minutos` | 3 | Lo menos entre un consejo y otro |
| `tamano` | 64 | Su tamaño (48 a 96): a 64, cada pixel del dibujo mide 1 px y ella ocupa unos 57 x 50 parada (el cuadro, 60 x 54) |
| `sonido` | no | Un clic bajito al hablar |
| `bloqueado` | no | Fija su lugar |
| `pos` | — | Su lugar (se guarda al arrastrarla) |
| `historias` | `aveces` | `siempre` (el gancho de cada misión y un dato en cada zona nueva), `aveces` (las que tomas sin leer: aceptadas al momento o con la guía andando, una de cada dos; un dato en la mitad de las zonas nuevas), `pedir` (solo con clic derecho) o `nunca`. Las historias se guardan siempre |
| `minutosHistoria` | 10 | Lo menos entre un globo de historia y otro (3 a 60) |
| `epilogo` | sí | «¿Te cuento el final?» al entregar (en `aveces`, solo de las que ya te ofreció) |

Datos por personaje (`N.DatosPersonaje("lya")`): `vistos`, `presentada`, `silencio`, `ultimaVez`, `sesionInicio`, `sesionAvisos`, `hoy`, `entrenarNivel`, `giro`, `charla` (la plática: `v[id]` = cuándo dijo cada nota, `ronda`, `paso`, `ultima`, `zona`).

## Comandos y contrato

- `/alfa lya`: la muestra o la oculta. `/alfa lya consejo`: un consejo. `/alfa lya dato`: un dato curioso de donde estás. `/alfa lya historias` o `/alfa historias`: la ventana Historias. `/alfa lya ajustes`: su página. `/alfa lobito` hace lo mismo.
- `AlfaLya` (y su alias `AlfaLobito`):
  - `Decir(texto, opts)`: que Lya diga algo. `opts = { importante = true, accion = { texto, fn }, acciones = { { texto, fn }, ... }, id = "mio1" }`. Con `id`, esa frase también sale 3 veces como mucho. Respeta todas las reglas de arriba. -> `true`, `"espera"` (importante, saldrá en cuanto se pueda) o `false, motivo`.
  - `Mostrar(si)`, `Consejo()`, `Visible()`, `Recuerdo()` -> título, texto y pie de «Sobre Lya» (para mostrarlo en otra página, por ejemplo La Jauría).
  - `Historias(questID)`: abre la ventana Historias (en esa misión, si está guardada). `DatoCurioso()`: «Cuéntame algo de aquí». `Contar()`: «Cuéntame algo». `Gente()`: «Háblame de mi gente».

## Las texturas

- `Media/lya-cuerpo.tga` (el pelaje, la pañoleta y la salchicha, con sus colores) y `Media/lya-cuerpo-borde.tga` (en blanco, que el juego tiñe con el acento: un contorno de un pixel por fuera del oscuro y los adornos, las «z», las ondas del aullido, el destello de la salchicha y las rayitas de la vuelta). Dos hojas de 1024 x 256 con 39 cuadros de 60 x 54 pixeles (sin escalar: un texel por pixel del dibujo, 17 por fila), todos mirando a la derecha: `Lya.lua` elige cada uno con `SetTexCoord` (y lo voltea igual) en el mismo orden que `ORDEN` en el dibujador (el dibujador lo compara con `Lya.lua` y no escribe si no cuadra). Poses y cuadros: quieta 4 (+4 con los ojos cerrados), atenta 2 (+2), sentada 2 (+2), pedir 3, correr 6, cola 4 (de lado, de espaldas, del otro lado y de frente), dormir 2, aullar 2, saltar 3 y estirarse 3. Las dibuja `tools/lya_cuerpo.py`: la «loba de perfil estilizada» (la opción B de `tools/lya_opciones.py`), pixel art de verdad (polígonos sin suavizado, sombreado plano con luz de arriba a la izquierda, una orilla oscura entre lo de enfrente y lo de atrás y contorno oscuro), negra con brillos azulados sutiles, ojos ámbar almendrados y su pañoleta verde de Alfa (#8be04e) con el rombo, siempre puesta. Pide con una salchicha (con sus colores, no se tiñe). Sus patas pisan 3 pixeles arriba del borde de abajo del cuadro (`PISO` en `Lya.lua`).
- `Media/lya-sombra.tga` y `Media/lya-suelo.tga`: su sombra ovalada y su lugar en el suelo (la elipse con el rombo de Alfa, que se tiñe). Las dibuja `tools/lya_marco.py`.
- La cara de antes (`tools/lya.py`, `lya-<pose>.tga`) ya no viaja en el addon: nadie la usaba. El script la vuelve a dibujar si alguna página la quiere.

```bash
.venv/Scripts/python -I tools/lya_cuerpo.py [carpeta-para-una-hoja-de-muestra]
.venv/Scripts/python -I tools/lya_marco.py [hoja-de-muestra.png]
```

## Para verificar en el juego

1. Personaje nuevo: Lya no aparece hasta terminar la bienvenida de Alfa; al terminarla sale y se presenta una sola vez.
2. Arrástrala, recarga: sigue en su lugar. Bloquéala desde el clic derecho: ya no se mueve.
3. Cambia el estilo (Alfa, Clásico WoW, Cristal): su contorno y su elipse cambian al momento. Muévela de un lado al otro de la pantalla: siempre mira hacia el centro y el globo sale del lado de su cabeza. Los pixeles se ven nítidos (sin borrones) en 48, 64 y 96.
4. Sube de nivel peleando: el aullido sale al terminar el combate. Muere: «¡Arriba, lobo!» (no dentro de una mazmorra).
5. Deja el equipo bajo 30 %, llena las bolsas, junta 3 misiones listas: cada consejo sale a lo más cada 5 minutos y sus botones llevan al lugar (flecha y ventanas cerradas).
6. Escribe en el chat mientras algo importante espera: sale al dejar de escribir.
7. Clic en Lya varias veces: consejos distintos; después de agotarlos, «Ya te conté todo lo que sé por ahora».
8. Ausente (`/afk`) o 5 minutos en una posada: se duerme enroscada. Clic: se despierta con un salto.
9. Silenciar 1 hora, Ocultar a Lya, `/alfa lya`, `/alfa lobito`.
10. Con la guía y la aceptación automática: toma varias misiones sin leerlas; a veces Lya dice «Esta va de <PNJ> y …», nunca en combate ni en mazmorra, y no más de una cada 10 minutos. *Contármela* abre Historias en esa misión con su texto completo. Entrégala: «¿Te cuento el final?» y la ventana baja al final.
11. `/alfa historias`: busca por PNJ o palabra, filtra por zona, *Seguir* en una misión de tu registro (flecha y ventanas cerradas), clic en una zona (sus datos curiosos). Recarga: todo sigue guardado. Una misión que ya tenías en el registro aparece con su historia tras entrar.
12. Entra a una zona nueva con un personaje: a veces Lya cuenta un dato de ahí; clic derecho > *Cuéntame algo de aquí* y *Otro dato* sin repetir hasta agotarlos. Con el cliente en inglés, los datos salen en inglés y las historias en el idioma del juego.
13. En su página, *Lya cuenta historias*: Siempre / A veces / Solo si le pido / Nunca (con Nunca desaparece *Cuéntame algo de aquí* del menú) y los minutos.
14. Déjala a la vista unos minutos sin globos: de vez en cuando se busca la cola, corre hacia el centro y regresa a su lugar (sin salirse de la pantalla y sin cambiar su lugar guardado), se estira o se sienta. Cuando dice que tiene hambre, se sienta a pedir con su salchicha (y al final con las dos manos). En combate se queda quieta y tenue, y al salir sigue.
