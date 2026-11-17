# Alfa - Lya

**Lya, la loba de confianza del Alfa**: una loba negra chiquita que te acompaña en pantalla con consejos cortos, ánimo y atajos a lo que Alfa sabe hacer. No es una mascota del juego: es un marco de la interfaz hecho con el Kit (`docs/KIT.md`). Lleva el nombre de Lya, una gran perrita, en su memoria (la tarjeta «Sobre Lya» de su página). Todo es código y arte propios de Alfa (GPL-3.0).

## Qué hace

- **En pantalla** (`Lya.lua`): 64 px, se arrastra y recuerda su lugar; con «Bloquear posición» se queda fija. Respira (un `AnimationGroup` en bucle), parpadea (un temporizador al azar), salta con las buenas noticias, aúlla al subir de nivel, se pone atenta cuando te ofrece algo y se duerme si estás ausente o llevas 5 minutos descansando. En combate se queda quieta y tenue. Su contorno toma el acento del estilo (el oro en Clásico WoW) y su placa es una caja del Kit: cambia sola con Alfa, Clásico WoW y Cristal.
- **Su globo**: «Lya: …» en hasta 3 líneas, con hasta dos botones que llevan a algo de verdad (Buscar cerca, entregar tus misiones, abrir una página de Alfa...). Se va solo a los 8 s (12 con botones; no con el ratón encima). Clic en Lya: un consejo cuando quieras.
- **Clic derecho**: Silenciar 1 hora · Cuéntame algo de aquí · Historias de tus misiones · Consejos: muchos / pocos / solo importantes · Bloquear posición · Volver a mostrar los consejos vistos · Ajustes de Lya · Ocultar a Lya (10 filas: las líneas entre grupos, mientras quepan).

## Historias y datos curiosos (`Historias.lua`, `VentanaHistorias.lua`, `Lore.lua`)

Seguir la flecha hace que uno se salte la historia: Lya la guarda y te la cuenta si quieres.

- **Lo que guarda** (por eventos): `QUEST_DETAIL` (`GetTitleText`, `GetQuestText`, `GetObjectiveText`, quien te la da: `UnitName("questnpc")` o el objeto que la empieza), `QUEST_ACCEPTED`, `QUEST_PROGRESS` (`GetProgressText`), `QUEST_COMPLETE` (`GetRewardText`, con quién se entrega), `QUEST_TURNED_IN`; las que ya estaban en tu registro, una vez por sesión con `GetQuestLogQuestText` (si el cliente solo lee la elegida, se elige un instante y se devuelve, nunca en combate ni con el registro abierto). Zona (`C_Map`, subiendo de cuevas y pisos a su zona) y fecha. Los textos son los del juego, en el idioma de tu cliente; un valor secreto no se guarda.
- **Dónde**: `N.Datos("lya").historias.q[questID] = { t, d, o, p, r, g, e, z, zn, a, c, u, l }` (la cuenta: las 500 más recientes y 450 000 letras como mucho). Por personaje (`hist`): `ganchos`, `finales`, `zonas`, `datos`, `ultima`, `ultimaDato`.
- **Lya lo cuenta**: al tomar una misión dice un gancho corto con sus palabras (el PNJ y un tema que saca del texto: la Plaga, los múrlocs, los Defias... y si hay lobos, «me toca de cerca») con **Contármela**, que abre Historias en esa misión. Nunca el texto largo en el globo. Al entregarla, si quieres, «¿Te cuento el final?» con **Contármelo** (la ventana baja al final).
- **Datos curiosos** (`Lore.lua`, notas propias de una o dos frases con su inglés en `Textos.lua`): 145 notas de 47 zonas (Kalimdor, los Reinos del Este, las 6 capitales y el Monte Hyjal) por uiMapID (1411-1458, 2482) y 12 del lore del mundo. Uno al entrar por primera vez a una zona con ese personaje, al pedirlo (**Cuéntame algo de aquí**: con *Otro dato* e *Historias*) y, rara vez, en el latido después de un buen rato callada.
- **Contra el spam** (además de las reglas de abajo): un globo de historia cada `lya.minutosHistoria` (10) como mucho, un dato automático cada 20 min, cada gancho, final y dato una sola vez por personaje, nunca con la ventana de misión abierta. Un gancho que no pudo salir (combate, otro globo) se reintenta cada 30 s, 6 veces; si llega otro, el nuevo manda. Sin tickers.
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

Los consejos del momento se revisan con los eventos del juego (`UPDATE_INVENTORY_DURABILITY`, `BAG_UPDATE_DELAYED`, `QUEST_LOG_UPDATE`, `PLAYER_UPDATE_RESTING`, juntados a 3 s) y en un latido de 60 s que solo corre con Lya a la vista. Nada en `OnUpdate`.

## Contra el spam

- Un globo cada `lya.minutos` (5) a lo más; con «pocos», el doble, y el consejo suelto cada 40 min en vez de 15. «Solo importantes»: morir, subir de nivel y los logros.
- Lo importante se salta la espera, pero nunca sale en combate, en una instancia ni mientras escribes: espera hasta 10 minutos a que se pueda. Lo demás se pierde (y se vuelve a revisar luego).
- **Cada frase sale 3 veces por personaje como mucho** y luego nunca más (`AlfaNucleoCharDB.lya.vistos`); «Volver a mostrar los consejos vistos» las devuelve. Las frases tienen varias versiones, así que no se repite la misma.
- Nunca encima del aviso de Hoy (`AlfaInicioAviso`) ni de otro globo suyo. «Silenciar 1 hora» calla todo menos lo que pides con clic.
- Mientras falte la bienvenida de Alfa (`AlfaBienvenida.Pendiente()`), Lya no aparece; al terminarla (`ALFA_CONFIGURADO`) sale y se presenta.

## Ajustes (`AlfaDB.settings.lya`) — página Personaje > Lya

| Clave | Por omisión | Qué hace |
|---|---|---|
| `mostrar` | sí | Lya en pantalla |
| `frecuencia` | `muchos` | `muchos`, `pocos` o `importantes` |
| `minutos` | 5 | Lo menos entre un consejo y otro |
| `tamano` | 64 | Su tamaño en px (48 a 96) |
| `sonido` | no | Un clic bajito al hablar |
| `bloqueado` | no | Fija su lugar |
| `pos` | — | Su lugar (se guarda al arrastrarla) |
| `historias` | `aveces` | `siempre` (el gancho de cada misión y un dato en cada zona nueva), `aveces` (las que tomas sin leer: aceptadas al momento o con la guía andando, una de cada dos; un dato en la mitad de las zonas nuevas), `pedir` (solo con clic derecho) o `nunca`. Las historias se guardan siempre |
| `minutosHistoria` | 10 | Lo menos entre un globo de historia y otro (3 a 60) |
| `epilogo` | sí | «¿Te cuento el final?» al entregar (en `aveces`, solo de las que ya te ofreció) |

Datos por personaje (`N.DatosPersonaje("lya")`): `vistos`, `presentada`, `silencio`, `ultimaVez`, `sesionInicio`, `sesionAvisos`, `hoy`, `entrenarNivel`, `giro`.

## Comandos y contrato

- `/alfa lya`: la muestra o la oculta. `/alfa lya consejo`: un consejo. `/alfa lya dato`: un dato curioso de donde estás. `/alfa lya historias` o `/alfa historias`: la ventana Historias. `/alfa lya ajustes`: su página. `/alfa lobito` hace lo mismo.
- `AlfaLya` (y su alias `AlfaLobito`):
  - `Decir(texto, opts)`: que Lya diga algo. `opts = { importante = true, accion = { texto, fn }, acciones = { { texto, fn }, ... }, id = "mio1" }`. Con `id`, esa frase también sale 3 veces como mucho. Respeta todas las reglas de arriba. -> `true`, `"espera"` (importante, saldrá en cuanto se pueda) o `false, motivo`.
  - `Mostrar(si)`, `Consejo()`, `Visible()`, `Recuerdo()` -> título, texto y pie de «Sobre Lya» (para mostrarlo en otra página, por ejemplo La Jauría).
  - `Historias(questID)`: abre la ventana Historias (en esa misión, si está guardada). `DatoCurioso()`: «Cuéntame algo de aquí».

## Las texturas

`Media/lya-<pose>.tga` (el pelaje, con sus colores) y `Media/lya-<pose>-borde.tga` (el contorno y los adornos en blanco, que el juego tiñe con el acento), con las poses `normal`, `atenta`, `aullando`, `dormida` y `parpadeo`. Las dibuja `Media/dibujar_lya.py` a partir de la cabeza de lobo de la marca de Alfa (`tools/marca.py`), más suave y redonda, con el pelaje casi negro y los ojos ámbar:

```bash
.venv/Scripts/python -I src/Alfa_Lya/Media/dibujar_lya.py [carpeta-para-una-hoja-png]
```

## Para verificar en el juego

1. Personaje nuevo: Lya no aparece hasta terminar la bienvenida de Alfa; al terminarla sale y se presenta una sola vez.
2. Arrástrala, recarga: sigue en su lugar. Bloquéala desde el clic derecho: ya no se mueve.
3. Cambia el estilo (Alfa, Clásico WoW, Cristal): su borde y su placa cambian al momento.
4. Sube de nivel peleando: el aullido sale al terminar el combate. Muere: «¡Arriba, lobo!» (no dentro de una mazmorra).
5. Deja el equipo bajo 30 %, llena las bolsas, junta 3 misiones listas: cada consejo sale a lo más cada 5 minutos y sus botones llevan al lugar (flecha y ventanas cerradas).
6. Escribe en el chat mientras algo importante espera: sale al dejar de escribir.
7. Clic en Lya varias veces: consejos distintos; después de agotarlos, «Ya te conté todo lo que sé por ahora».
8. Ausente (`/afk`) o 5 minutos en una posada: se duerme. Clic: se despierta con un salto.
9. Silenciar 1 hora, Ocultar a Lya, `/alfa lya`, `/alfa lobito`.
10. Con la guía y la aceptación automática: toma varias misiones sin leerlas; a veces Lya dice «Esta va de <PNJ> y …», nunca en combate ni en mazmorra, y no más de una cada 10 minutos. *Contármela* abre Historias en esa misión con su texto completo. Entrégala: «¿Te cuento el final?» y la ventana baja al final.
11. `/alfa historias`: busca por PNJ o palabra, filtra por zona, *Seguir* en una misión de tu registro (flecha y ventanas cerradas), clic en una zona (sus datos curiosos). Recarga: todo sigue guardado. Una misión que ya tenías en el registro aparece con su historia tras entrar.
12. Entra a una zona nueva con un personaje: a veces Lya cuenta un dato de ahí; clic derecho > *Cuéntame algo de aquí* y *Otro dato* sin repetir hasta agotarlos. Con el cliente en inglés, los datos salen en inglés y las historias en el idioma del juego.
13. En su página, *Lya cuenta historias*: Siempre / A veces / Solo si le pido / Nunca (con Nunca desaparece *Cuéntame algo de aquí* del menú) y los minutos.
