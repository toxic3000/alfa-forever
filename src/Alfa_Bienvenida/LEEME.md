# Alfa - Bienvenida

La configuración de Alfa (obligatoria la primera vez), las novedades, el aullido y los reportes al desarrollador. Todo es código propio de Alfa.

- **Reemplaza la bienvenida y las novedades del motor** (`SHOW_WELCOME` y `SHOW_WHATSNEW`): abren la misma ventana del Kit.
- **Configuración** (`K.Asistente`, `Asistente.lua` + `Pasos.lua`), una decisión por pantalla:
  1. **Idioma** de Alfa: los diez, cada uno escrito en el suyo; ya elegido el de Alfa ahora (el del juego si nunca elegiste). Cambiarlo llama a `N.PonerIdioma(loc)` (Alfa_Idioma) y, si pide recargar, el botón dice "Recargar y seguir": guarda el paso siguiente, avisa en el chat y llama a `ReloadUI()`; al entrar, la configuración sigue en el paso 2. La elección también queda en `bienvenida.idioma`.
  2. **Estilo** (Alfa, Clásico WoW, Cristal) con su muestra; se aplica al instante en esta misma ventana. En Cristal, el acento. Debajo, el aullido.
  3. **Misiones**: aceptar y entregar las de la guía, solo las de tu ruta, también las demás (Comodidades), saltar grises, cerrar lo que la guía salta, avisar de misiones que cierran otras, mejor recompensa, ponerte la recompensa, **resaltar lo de misión**.
  4. **Tu guía**: elegir guía, seguir con la siguiente, zona recomendada, "Mientras estás aquí", misiones de clase, recordatorio del instructor, charla de una opción, lo que pide el paso.
  5. **Comerciantes y viajes**: vender lo gris, reparar (y con la hermandad), comprar lo de la guía, despojo rápido, mapa de vuelo, tomar el vuelo, fijar el hogar.
  6. **Otros jugadores**: invocaciones, resurrecciones, grupos de amigos, liberar en JcJ; rechazar grupos de desconocidos, hermandades y duelos; compartir el avance con el grupo y los horarios de barcos.
  7. **Tu personaje**: curar con un clic, **ayuda de rotación**, avisos de reacción, recolección en el mapa. La primera vez que alguien configura Alfa se escribe lo recomendado para su rol: quien cura, curar con un clic encendido y la rotación apagada; tanque y daño, la rotación encendida.
  8. **La Jauría**: "No compartir" o "Sí, compartir mi ubicación". Nunca está elegido el sí hasta que lo pulsas (`AlfaManada.Compartir`). Sin Alfa_Manada, el paso no sale.
  9. **Resumen**: cada pantalla con lo que Alfa hará sola y "Cambiar"; la rotación y resaltar lo de misión con su propia fila; "Apoya a Alfa" (termina y abre Manada en ese bloque); un solo botón, **Listo**.
  - Cada respuesta se guarda al elegirla y cada interruptor lee el ajuste real: quien ya usaba Alfa ve lo suyo. Solo salen las filas cuyo módulo está cargado y cuyo ajuste existe. "Ir al resumen" deja el resto como está.
- **Obligatoria**: mientras falte, `AlfaBienvenida.Pendiente()` es true y la puerta del núcleo (`N.Permitido`, `Alfa.Puerta`) llama a `AlfaBienvenida.Abrir()`, que abre la configuración donde la dejaste y dice en el chat "Termina la configuración para usar Alfa (2 minutos)." (también al cerrarla sin terminar). No bloquea el juego: solo las ventanas de Alfa. Sale sola a los pocos segundos de cada entrada mientras falte (fuera de combate, de instancias, de cinemáticas y de la elección de camino).
- **Quien ya terminó el asistente de antes** (`M.VERSION` 1) ve la nueva configuración una vez (`M.VERSION` = 2), con sus ajustes de ahora ya elegidos, y no recibe las recomendaciones por rol.
- **Página Ajustes > Estilo y sonido:** tu estilo con "Mi configuración", los tres estilos, el acento de Cristal, el aullido, la configuración, "Reportar" y lo nuevo de la versión (abre las notas).
- **La intro del lobo** (`Intro.lua`, texturas de `tools/intro.py` en `Media/`): estrellas que titilan, una estrella fugaz, la luna que sube con su halo, el lobo en su peña recortado contra la luna con el contorno encendido, chispas de luz que suben de la peña y neblina abajo; el lobo toma aire y aúlla (el aullido largo) con cinco ondas mientras la luna le contesta con su halo; A L F A con su resplandor, una raya de luz y un brillo que recorre las letras hasta un destello; un destello en el ojo del lobo al terminar de aullar; luego el lema. Toda la escena se acerca despacio (las estrellas no). 5,8 s (1.2.1), se salta con clic, Esc, espacio o Enter y se corta si entras en combate. Sale antes de la configuración pendiente y antes de las notas de una versión nueva, una vez por sesión. Avisa `ALFA_INTRO_INICIO` y, cuando deja ver lo que sigue, `ALFA_INTRO_FIN` (Lya llega corriendo entonces).
- **El lobo de la intro**: `tools/intro.py` trae tres (`LOBOS`: `sentado`, el de la 1.2.0; `de-pie`, parado con la cabeza alzada; `facetado`, el sentado con las facetas del emblema) y `ELEGIDO` dice cuál se dibuja; al correrlo escribe en `Intro.lua` la punta del hocico y el ojo del elegido (la línea `local LOBO = ...`).
- **Notas de cada versión** (`Notas.lua`, la tabla `M.NOTAS` de `Novedades.lua`): al entrar con una versión de Alfa más nueva que la última que viste (`AlfaNucleoDB.bienvenida.versionVista`; una vez por versión y por cuenta), unos segundos después de los demás avisos y fuera de combate, de instancias, de cinemáticas y de la elección de camino: la intro y luego una ventana chica en el centro, "Lo nuevo en Alfa X.Y.Z", con "Seguir jugando" y "Ver todo lo nuevo" (la portada, que lista las notas de cada versión). Quien no tenía Alfa ve la configuración, no las notas; al terminarla su versión queda vista. Quien ya había configurado y no tiene registro, viene de una versión anterior: ve las notas. En combate la ventana se esconde y vuelve al terminar la pelea. Una versión sin entrada en `M.NOTAS` no muestra ventana.

## Reportar un error, una mejora o un comentario (`Reporte.lua`)

Un addon no puede enviar nada fuera del juego. La ventana arma el reporte y tú lo pegas en el buzón privado del Discord de La Jauría (canal `📮-buzon-alfa`: los miembros escriben pero no leen lo de los demás; solo lo lee el desarrollador).

1. Eliges Error, Mejora o Comentario y lo escribes (hasta 1000 letras).
2. El reporte se arma solo mientras escribes: tipo, tu texto y, en un bloque de código, la versión de Alfa, la del cliente y su compilación, el idioma del juego y el de Alfa, tu clase y nivel, la zona con su mapa y coordenadas y, si es un error, los últimos errores de Lua que el motor atrapó (`Alfa.Errors`) y las acciones que el juego le bloqueó (`Alfa.Blocked`). Cabe en un mensaje de Discord (se quitan los errores más viejos si no). **No lleva el nombre del personaje ni el reino**, ni ningún dato del desarrollador.
3. El reporte y la invitación (`Alfa.DiscordURL`, https://discord.gg/hUNjA6BJwh) van en cuadros para copiar: "Elegir todo" y Ctrl+C.
4. "Pégalo en #buzon-alfa del Discord de La Jauría." y "Lo revisa el desarrollador de Alfa." En el juego el canal se escribe sin el emoji (las letras del juego no lo tienen).

## El aullido

La primera vez que abres la ventana de Alfa en cada sesión suena un lobo **del propio juego** (canal de efectos, así que respeta tu volumen y si tienes los efectos apagados). Un `/reload` no lo repite; volver a entrar sí.

**El aullido largo de la intro** (1.2.1, `M.AULLIDOS` en `Bienvenida.lua`): el juego clásico no trae un aullido largo en un solo archivo, así que se arma con los suyos, uno tras otro (el siguiente empieza cuando termina el anterior, con `C_Sound.IsPlaying`), y otro lobo contesta a lo lejos en el canal de ambiente (suena más bajo, como un eco del valle). Hay tres: `corto` (el de siempre), `largo` (de fábrica en la intro) y `manada` (más lobos que contestan). Para compararlos en el juego: `/alfa bienvenida aullido corto|largo|manada` suena y lo deja como el de la intro (`bienvenida.aullidoIntro`). Al abrir la ventana de Alfa y con «Escuchar» sigue sonando el corto.

Sonidos, por FileDataID, en este orden (si el cliente no tiene uno, prueba el siguiente):

| FileDataID | Archivo del juego | Qué es |
|---|---|---|
| 569109 | `Sound/SPELLS/FuriousHowl1.ogg` | Aullido furioso, la habilidad del lobo del cazador (desde la 1.x) |
| 564211 | `Sound/CREATURE/Wolf/WolfStandVar4.ogg` | El lobo de siempre, quieto, aullando (desde la 1.x) |
| 564217 | `Sound/CREATURE/Wolf/WolfStandVar4b.ogg` | La otra toma del mismo aullido: la segunda parte del aullido largo (desde la 1.x) |

De dónde salen: el listado de archivos de la comunidad, [wowdev/wow-listfile](https://github.com/wowdev/wow-listfile) (`parts/sound.csv`, versión 202611141741). Los dos son archivos del juego original (1.x), así que el cliente clásico los trae; el motor ya toca sonidos del juego por FileDataID del mismo rango (las campanas de barco y zepelín, 566652 y 566719). Alfa no reparte ningún sonido propio.

## Acomodar la pantalla (`Acomodar.lua`, 1.3.1)

Un solo modo para mover con el ratón lo de Alfa que está en pantalla: Lya, tu guía (el rastreador), la flecha, la tarjeta de avisos, la barra y las metas de pesca, y los marcos de Combate y Curación (prende los suyos con `AlfaCombate.Mover()` y `AlfaCuracion.Mover(true)`). Cada cosa sale con un marco verde y su nombre; se arrastra y guarda su lugar con su propio `OnDragStop` (nada nuevo se guarda aquí); clic derecho la regresa a su lugar de siempre (Lya, la flecha y los avisos). Mientras está abierto, `A.DragLocked` da false. Se abre con `/alfa acomodar` o con «Acomodar» en Ajustes > Estilo y sonido; «Listo», Esc o una pelea lo terminan; en combate no se abre. Prueba: `tools/banco/prueba_131_varios.lua`.

## La ventana de Alfa, más cómoda (`Ventana.lua`, 1.3.7)

Envuelve `O.Select` y `O.RefreshNav` de `motor/Alfa/UI/Options.lua` sin cambiar cómo se arma cada página. Atajos con la ventana abierta y fuera de combate (`bienvenida.atajosVentana`): Ctrl+número (sección, en el orden de la barra), Ctrl+← / Ctrl+→ (página), Ctrl+F (buscador), Alt+← (volver); un marco hijo con `EnableKeyboard` deja seguir al juego toda otra tecla (`SetPropagateKeyboardInput`). «‹» volver (historial de 12, se limpia al abrir) corre el título y las pastillas con `win.psPillLeft` (Widgets.lua). La esquina de abajo a la derecha estira solo el alto (`StartSizing("BOTTOM")`); alto y lugar en `AlfaNucleoDB.bienvenida.ventana` si `bienvenida.recordarVentana`. Buscador: al entrar vacío, tus 5 búsquedas recientes (`AlfaNucleoDB.bienvenida.busquedas`) e ideas; sin resultados, `O.SinResultados` pone las páginas a un clic. Prueba: `tools/banco/prueba_137c_ventana.lua` (`BANCO_FOTOS=1` dibuja las capturas).

## Comandos

- `/alfa bienvenida`: abre la configuración (pendiente: donde la dejaste; terminada: el resumen). `/alfa bienvenida novedades`: lo nuevo de la versión. `/alfa bienvenida aullido [corto|largo|manada]`: suena ese aullido y queda como el de la intro.
- `/alfa reportar [error | mejora | comentario]`: la ventana de reportes.
- `/alfa estilo`: abre Ajustes > Estilo y sonido.
- `/alfa acomodar`: acomodar la pantalla con el ratón (1.3.1).
- `/alfa diagnostico` (1.2.9, `Diagnostico.lua`): «Revisar Alfa», lo que choca con Alfa y su arreglo a un clic (nunca apaga el otro addon).
- `/alfa rendimiento`: memoria, procesador (C_AddOnProfiler o scriptProfile) y las tareas del reloj del núcleo.
- `/alfa welcome` y Acerca de > "Mostrar la bienvenida otra vez" (del motor) abren lo nuevo de la versión.

## Contrato

| Global | Qué |
|---|---|
| `AlfaBienvenida.Abrir(vista)` | La configuración (pendiente: con la línea de por qué) o `"portada"` (solo ya terminada) |
| `AlfaBienvenida.Pendiente()` | true mientras la configuración no se terminó |
| `AlfaBienvenida.Exigir()` | Si está pendiente: la abre, lo dice y devuelve true |
| `AlfaBienvenida.Aullar()`, `AlfaBienvenida.Visto()` | El aullido ahora; si ya salió la configuración de esta versión |
| `AlfaBienvenida.Notas()` | La ventana con las notas de tu versión de Alfa |
| `AlfaReporte.Abrir(tipo)` | La ventana de reportes (`"error"`, `"mejora"`, `"comentario"`) |
| Mensaje `ALFA_CONFIGURADO` | Se dispara al pulsar Listo |

## Ajustes que escribe

| Pantalla | Claves |
|---|---|
| Idioma | `AlfaIdiomaDB.idioma` (por `N.PonerIdioma`), `bienvenida.idioma` |
| Estilo | `ui.skin` (por `K.SetEstilo`), el acento (`K.SetAcento`, `ui.classAccent`), `bienvenida.aullido`, `bienvenida.modo` (1.2.9: `sencillo` de fábrica, `completo`; la migración 3 deja en completo a quien ya tenía Alfa) |
| Misiones | `behavior.autoAccept`, `behavior.autoTurnin`, `ruta.soloRuta`, `comodidades.misiones`, `behavior.skipGrey`, `behavior.closeSkipped`, `behavior.warnClosing`, `qol.rewardAutoPick`, `qol.rewardEquip`, `combate.marcaMision` + `bolsas.brilloMision` |
| Tu guía | `behavior.autoSelectGuide`, `behavior.guideEnd` (`continue`/`ask`), `behavior.routeChoice` (`recommended`/`ask`), `behavior.whileHere`, `behavior.offerClassQuests`, `behavior.trainReminder` (`2`/`1`/`off`), `qol.skipGossip`, `qol.stepGossip` |
| Comerciantes y viajes | `qol.sellJunk`, `qol.autoRepair`, `qol.repairGuild`, `qol.buyGoals`, `qol.fastLoot`, `qol.flightAutoOpen`, `qol.flightAutoTake`, `qol.autoBind` |
| Otros jugadores | `qol.acceptSummon`, `qol.acceptResurrect`, `qol.acceptPartyFriends`, `qol.autoReleasePvP`, `qol.declinePartyStrangers`, `qol.declineGuildInvites`, `qol.declineDuels`, `party.share`, `nav.shareTransit` |
| Tu personaje | `curacion.activo`, `combate.rotacion`, `combate.avisos`, `recoleccion.mapa` + `recoleccion.minimapa` |
| La Jauría | `manada.compartir` (por `AlfaManada.Compartir`) |

## Datos

| Dónde | Qué |
|---|---|
| `AlfaNucleoDB.bienvenida` | `respondio` (la versión de la configuración terminada), `paso` (dónde va, mientras falta), `recomendado` (ya se aplicó lo recomendado por rol), `visto`, `cuando`, `versionVista` (la versión de Alfa cuyas notas ya viste) |
| `AlfaNucleoCharDB.bienvenida.aulloSesion` | Ya aulló en esta sesión |
| `AlfaNucleoDB.kit.acentos` | El acento propio que recuerda cada estilo |
| `AlfaNucleoDB.respaldos` | 1.2.9: los últimos 3 respaldos de los ajustes y perfiles (`Alfa_Nucleo/Respaldos.lua`; restaurar y el aviso de ajustes vacíos en `Respaldos.lua`). 1.3.1: cada uno lleva su `esquema` (la última migración); al restaurar uno de antes, sus ajustes se mudan con las migraciones que le faltan (`N.MigrarDesde`). Los de antes de la 1.3.1: el de «antes de actualizar» o uno de antes de la 1.2.9 cuenta como 2, los demás como 3 |
| `AlfaNucleoDB.bienvenida.perfiles` | 1.2.7: tus perfiles (`Perfiles.lua`), cada uno como `{ ["ruta.del.ajuste"] = valor }`. 1.3.1: con `_alfa.esquema` y `_alfa.version` (también en el texto de «Exportar»), que no son ajustes: al aplicarlo o importarlo se mudan sus ajustes desde ese número. Uno de antes, sin número, conserva tu modo (sencillo o completo) si no trae el suyo |
| `AlfaNucleoDB.errores` | 1.2.9: los últimos 30 errores de Alfa atrapados (`Alfa_Nucleo/Errores.lua`), en Estilo y sonido > Errores atrapados |

## Para verificar en el juego

1. Personaje nuevo: a los pocos segundos de entrar sale la configuración. Ciérrala: el chat dice "Termina la configuración…" y `/alfa`, el botón del minimapa o cualquier ventana de Alfa la vuelven a abrir en el mismo paso. Bolsas, combate y el juego siguen normales.
2. Idioma: elige English. El botón dice "Recargar y seguir"; al pulsarlo recarga y la configuración sigue en el paso 2, ya en inglés. Revisa que 한국어 y los chinos se lean (letra del juego para esas escrituras).
3. Estilo: los tres cambian esta misma ventana al instante; en Cristal salen los acentos.
4. Un sacerdote sagrado o un druida de restauración: curar con un clic encendido y la rotación apagada; un guerrero: la rotación encendida.
5. La Jauría: "No compartir" elegido; "Sí" solo al pulsarlo. Con Sí, `/alfa manada estado` dice que compartes.
6. Resumen: "Cambiar" lleva a su pantalla; Listo cierra con el aviso y el aullido; `/alfa bienvenida` abre el resumen.
7. Cuenta que ya había terminado el asistente de antes: ve la nueva configuración una vez, con sus ajustes de siempre.
8. `/alfa reportar`: escribe un texto, "Elegir todo", Ctrl+C y pégalo en Discord: debe verse el título en negritas y los datos en un bloque de código, en un solo mensaje. Provoca un error de Lua de Alfa y revisa que salga en el reporte.
9. Revisa que el texto largo del cuadro se desplace con la rueda y que "Comentario" se lea completo en los segmentos.
10. Notas de versión: con Alfa ya configurada, `/run AlfaNucleoDB.bienvenida.versionVista = "1.0.0"` y `/reload`: a los ~6 s sale la intro y luego "Lo nuevo en Alfa X.Y.Z" en el centro. Esc o "Seguir jugando" la cierran; otro `/reload` ya no la muestra. Pruébalo en los tres estilos y pega a un enemigo con la ventana abierta: se esconde y vuelve al salir del combate.
