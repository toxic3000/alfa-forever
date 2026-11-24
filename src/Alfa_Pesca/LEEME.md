# Alfa - Pesca

El modo pesca de Alfa: una tecla lo hace todo (equipo, cebo, lanzar y recoger), con su barra, diario, estadísticas, metas, guía de 1 a 300 y cocina junto al agua. Todo es código propio de Alfa, hecho con el Kit.

## Qué hace

- **Modo pesca** (`Pesca.lua`): se abre con el botón de la barra o de la página, `/alfa pesca`, su tecla (Atajos > Alfa > Abrir o cerrar el modo pesca) o al ponerte una caña (`abrirConCana`). Mientras está abierto, tu tecla del modo (`tecla`, Espacio de fábrica) pulsa el botón seguro `AlfaPescaBoton` con `SetOverrideBindingClick`; Mayús+Espacio sigue saltando (`saltoMayus`), al moverte la tecla vuelve a la normal (`saltarAlMoverse`) y Ctrl+Espacio (`teclaRelanzar`) pulsa `AlfaPescaRelanzar` (suelta el lanzamiento y lanza otra vez, sin preparar nada). Se cierra con su botón, el comando o la tecla, y al montar (`cerrarAlMontar`). La tecla fija de siempre (`CLICK AlfaPescaBoton:LeftButton`) sigue funcionando también fuera del modo.
- **Una tecla, un paso por pulsación** (`Equipo.lua`): la macro del botón seguro cambia según lo que falta: ponerte la mejor caña y lo que tengas con bonificación de Pesca (`/equipslot`), poner el mejor cebo o el preferido (`/use cebo` + `/use 16`), y luego lanzar (`/cast [nocombat,noflying] Pesca`). El equipo y los cebos se reconocen por su descripción (la línea que nombra la Pesca y su número) y por la lista de cebos del juego. Al cerrar el modo con tu clic vuelve tu equipo normal (`restaurarEquipo`); si se cerró solo (al montar), un aviso ofrece volver con un clic. Grupos de ranuras que nunca se tocan: `excluir`.
- **Recoger con la misma tecla**: al empezar el canal, tus teclas pasan a `INTERACTTARGET` y la interacción suave apunta al corcho. La barra dice si el lanzamiento fue bueno (el corcho entró a la interacción suave) o si cayó lejos.
- **La barra** (`Barra.lua`): habilidad ("Experto 126/225") con su avance y la bonificación, lo que hace tu tecla ahora, el tiempo del lanzamiento y botones: equipo, cebos, cocina, juguetes y consumibles de pesca, metas, diario, ajustes y cerrar. Horizontal o vertical, se mueve, cambia de tamaño y se pliega sola. Sus menús se abren hacia donde hay pantalla. Vista mínima al lanzar (`vistaMinima`) y aviso con lo que sacas (`resumen`).
- **Sonido para el chapoteo**: efectos al volumen elegido, música y ambiente bajos, sonido con el juego en segundo plano (`sonidoFondo`), nombres de PNJ ocultos e ícono sobre el corcho. Avisos suaves con sonidos del juego (sin voces): captura, escape y "¿otra vez?" si te quedas sin lanzar. Ocultar la interfaz al pescar (`ocultarUI`, fuera de combate, dejando minimapa y chat si quieres).
- **A pelear / Volver a mi equipo** (`Pelear.lua`, 1.3.7): la espada de la barra es un botón seguro propio (`AlfaPescaPelear`, padre UIParent, colocado sobre el hueco que la barra le guarda) con la macro `/equipslot 16/17` de las armas que recuerda `Equipo.lua`, armada solo fuera de combate. En combate te pone las armas y lo demás vuelve al terminar la pelea (`N.FueraDeCombate`); fuera de combate te pone todo y cierra el modo. Sin armas recordadas se ve apagado y su cuadro dice por qué. Tecla `CLICK AlfaPescaPelear:LeftButton` y aviso al entrar en combate con la caña (`avisoPelear`). En combate la barra no se pliega, no se mueve y no cambia a la vista mínima.
- **Clic derecho en la barra** (1.3.7): estadísticas, guía, logros, lo que te falta del diario en los bancos de tu zona, barra vertical u horizontal y sesión nueva. El cuadro de la baldosa dice cuánto falta para el tope de tu rango y desde cuándo aprendes el siguiente; al cerrar el modo, un resumen (`resumenCerrar`); consejos (`consejos`): se acabó el cebo, llegaste al tope.
- **Botín**: recoge todo lo pescado aunque el botín automático esté apagado y lo anota (también si salió de un banco de peces, por el GUID de su fuente).
- **Diario de pesca** (`Diario.lua`): el catálogo de lo que se pesca en Forever (`Datos.lua`) más todo lo que saques, con buscador y filtros; la ficha con la maestría (10, 50, 100, 250, 500, 1000), tus números (primera vez y con qué habilidad, última vez), dónde sale (tus zonas y los bancos de peces), recetas, valor y acciones: meta, Guíame, Mis planes, Enciclopedia.
- **Estadísticas** (`Estadisticas.lua`): sesión y desde siempre (lanzamientos, capturas, éxito, por hora, tiempo hasta que pica, tiempo pescando, valor de venta y de subasta con Comercio) y las sesiones anteriores con lo pescado y dónde. Una sesión se cierra tras 20 minutos sin lanzar.
- **Logros**: 22 logros propios de la manada (primera captura, 100/500/1000, especies, trofeo, rangos, cebos, bancos, zonas, cocina, una hora, racha, maestría, concurso, valor). Cada uno se anuncia una sola vez.
- **Metas** (`Metas.lua`): ventanita propia con metas de un pez, capturas, lanzamientos, tiempo o valor; cuentan aunque esté cerrada. Una meta de un pez se puede llevar a Mis planes (`AlfaPlanes.AgregarObjeto`).
- **Guía de pesca** (`Guia.lua`): tu siguiente paso, los tramos de 1 a 300 (orientativos), cerca de ti (bancos de tu zona con el más cercano y lo que tú sacas ahí), instructores y vendedores (Buscar cerca y Guíame; marcadores en el mapa con las capas `pesca.instructores` y `pesca.vendedores` de Alfa_Mundo), equipo y cebos con cómo conseguirlos, misiones de pesca y el concurso de Tuercespina (domingos 14:00 a 16:00 del reino, mostrado en tu hora).
- **Antes de pescar** (`Previa.lua`, 1.3.8): al abrir el modo, un cuadro con tu caña (si tienes varias), tu cebo (con su bonificación y cuántos) y la barra («Como la tienes ahora» de fábrica; si no, horizontal, vertical o mínima y qué botones). Se guarda al momento por personaje (`Eq.Eleccion()`: `cana`, `cebo`, `barra`, `noPreguntar`) y tu tecla lo usa. «A pescar» te pone la caña elegida. Con una caña y sin cebos no sale; nunca en combate ni tras un /reload. Se vuelve a abrir con el clic derecho de la barra, Ajustes o `/alfa pesca antes`.
- **Tamaños, récords, nivel y pez de la semana** (`Pescador.lua`, `VistaPescador.lua`, 1.3.8): cada pieza tiene un tamaño creíble y estable (especie, forma, tu habilidad y el número de tu captura: no se puede repetir); récords por pez y por zona; nivel de pescador de Alfa (1 a 60, con títulos) con experiencia por captura, lo raro, lo nuevo, los récords, los bancos y el pez de la semana (igual para tu facción, por la fecha del servidor; 5 dan +300). Centímetros y kilos (pulgadas y libras en inglés).
- **Sesiones** (`VistaSesiones.lua`, 1.3.8): cada sesión con su lugar, peces, tamaño total, peces por hora y la mejor captura; filtros por día y por lugar.
- **La tabla de La Jauría** (`Jauria.lua`, 1.3.8): opcional y apagada (`jauria`); tu nivel y tus récords por la hermandad con la red de La Jauría (tipo `1p`), solo de tu facción, nada a canales públicos.
- **Cocina junto al agua** (`Cocina.lua`, `VistaCocina.lua`): recetas de pescado con si las sabes, la habilidad que piden, los ingredientes (la receta del juego) y para cuántas alcanza; una cola que avanza con tu clic, lote por lote (si la Cocina del juego no está abierta, el clic la abre); la fogata básica.

## Lo seguro (reglas de Blizzard)

- Todo lo protegido va en botones seguros y solo con tu tecla o tu clic: `AlfaPescaBoton`, `AlfaPescaRelanzar`, `AlfaPescaClic` (doble clic derecho) y `AlfaPescaSeguro`, un único botón seguro que se pone encima del botón del Kit bajo el ratón (usar un cebo o un juguete, la fogata, abrir la Cocina) y se quita al empezar un combate. Ningún marco del Kit queda protegido.
- Las macros y las teclas se cambian solo fuera de combate; al entrar en combate se sueltan y tus teclas vuelven a ser las de siempre. Ponerte o quitarte el equipo con los botones del menú es tu clic (`C_Item.EquipItemByName`).
- Nada corre en `OnUpdate` salvo el tiempo del lanzamiento mientras dura; el resto son eventos y temporizadores de una vez.
- Sin mensajes en el chat salvo la respuesta a tus comandos y el aviso único de otro addon de pesca.

## Comandos

- `/alfa pesca`: abre o cierra el modo pesca.
- `/alfa pesca ajustes | diario | guia | cocina | metas | estadisticas | logros`.
- `/alfa pesca on | off`: el interruptor general. `/alfa pesca reiniciar`: sesión nueva.

## Ajustes (`AlfaDB.settings.pesca`)

Las claves de antes siguen igual: `activo`, `autobotin`, `ocultarNombres`, `sonido`, `volumen`, `dobleClic`, `velocidad`, `montado`, `relanzar`, `iconoCorcho`. Nuevas: `tecla` ("SPACE"), `teclaRelanzar` ("CTRL-SPACE"), `saltoMayus`, `saltarAlMoverse`, `abrirConCana`, `cerrarAlMontar`, `prepararEquipo`, `prepararCebo`, `ceboPreferido` (0 = el mejor), `restaurarEquipo`, `excluir` (`cabeza`, `manos`, `pies`, `abalorios`, `resto`), `barra`, `barraVertical`, `barraEscala`, `barraPlegar`, `vistaMinima`, `resumen`, `metasVentana`, `ocultarUI`, `uiMinimapa`, `uiChat`, `musica`, `ambiente`, `sonidoFondo`, `alertas`, `alertaCaptura`, `alertaEscape`, `alertaInactivo`, `inactivoSeg`, `alertaSonido`, `mapaGuia` (sin Alfa_Mundo).

Datos por personaje (`AlfaNucleoCharDB.pesca`): `sesion`, `historial`, `vida`, `diario`, `registro` (las 1500 últimas capturas con zona, subzona y fecha), `lugares`, `logros`, `metas`, `equipoNormal`, `modo`, `respaldo`, `pestana`. De la cuenta (`AlfaNucleoDB.pesca`): `barra` (lugares), `metasLugar`, `importadoOtro`, `teclasOtro`, `avisoOtro`.

## Datos

`Datos.lua` guarda IDs del juego sacados del Codex del motor con reglas escritas en su cabecera (catálogo, recetas de pescado, bancos y lo que dan, misiones) y los cebos con su bonificación. Los nombres salen del cliente o del Codex; las fuentes, PNJ, bancos y misiones del Codex, que se carga solo al abrir el diario, la guía o una capa del mapa. La habilidad que pide cada agua no está en los datos: la guía la da por tramos y tu diario anota con qué habilidad sacaste cada cosa.

## Para verificar en el juego

1. Abrir el modo (botón, `/alfa pesca`, ponerte la caña): Espacio pone la caña y el equipo, luego el cebo, luego lanza; Mayús+Espacio salta; al correr, Espacio salta; Ctrl+Espacio relanza.
2. Al salpicar, Espacio recoge; la barra dice "Buen lanzamiento" cuando el corcho entra a la interacción suave y "quedó lejos" si no.
3. Cerrar el modo con su botón: vuelve tu equipo normal (también la otra mano tras la caña de dos manos). Montar: se cierra y sale el aviso para volver al equipo.
4. Cebos: el menú usa el cebo con un clic sobre la caña; el clic derecho lo deja como preferido. Juguetes y fogata desde sus menús (el botón seguro encima).
5. Entrar en combate con el modo abierto: tus teclas vuelven a ser las de siempre, sin "acción bloqueada"; al salir, el modo vuelve.
6. Sonido, nombres e interfaz oculta: se aplican al lanzar y vuelven al cerrar el modo, al combate, al recargar y al salir.
7. Botín: el aviso con lo pescado, el diario, la maestría y los logros suman bien; "se escapó" cuenta.
8. Cocina: con la Cocina del juego cerrada, el primer clic la abre y el siguiente cocina un lote; la cola avanza y cuenta para los logros.
9. Guía: instructores y vendedores en el mapa (capas de Mundo), bancos de tu zona y "Llévame", la fecha del concurso en tu hora.
10. Con otro addon de pesca activo: aviso una vez, la página dice "En pausa" y Alfa no toca nada.
