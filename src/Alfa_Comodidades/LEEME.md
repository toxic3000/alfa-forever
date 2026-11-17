# Alfa - Comodidades

Comodidades de calidad de vida dentro de Alfa. Solo hace lo que el motor de Alfa todavía no tenía; lo demás ya viene en Alfa y no se repite. Todo es código propio.

## Dónde está

Su propia página, hecha con el Kit (`Pagina.lua`): **Ajustes > Comodidades** (`/alfa comodidades`). Arriba, el estado y un botón para **encender las recomendadas** (colores de clase, cuadro de información, probador, siguiente parada del vuelo y sin voces de error); debajo, un grupo por comodidad con su interruptor principal y sus opciones dentro, atenuadas mientras está apagado. Lo que este cliente no tiene (probador, la variable de la cámara, los grifos, un sonido) no se muestra. Todos sus controles también salen en la búsqueda de ajustes de la ventana de Alfa.

| Grupo | Qué hay |
|---|---|
| Misiones | **Aceptar y entregar todas las misiones**, con normales, diarias, semanales y entregar las completadas. Con «solo las misiones de mi ruta» (`ruta.soloRuta`, de la ruta de Alfa) encendido, **no acepta nada fuera de tu ruta** (lo dice en la fila) |
| Viajes | **Mostrar la siguiente parada** en vuelos con escalas |
| Minimapa | Cuadrado, ocultar los botones de addons (aparecen con el ratón) y el menú de addons |
| Estilo del chat | **Dar al chat el estilo de Alfa**: panel, pestañas, caja para escribir y letra con el estilo elegido; opacidad del fondo y ocultar la columna de botones |
| Estilo del minimapa | **Dar al minimapa el estilo de Alfa**: bisel (cuadrado) o aro (redondo) y la barra de la zona y la hora |
| Estilo de las barras | **Dar a las barras el estilo de Alfa**: barra principal, botones de acción, barras extra, experiencia y reputación, menú y bolsas; grifos como están, del color del estilo u ocultos |
| Marcos y barra | Colores de clase en tu marco y en el del objetivo · ocultar los grifos |
| Cuadro de información | A quién apunta, rango de tu hermandad, ocultarlo en combate y verlo con Mayús |
| Probador | Botones de objetos y control de animación |
| Cámara | Alejar más la cámara |
| Silenciar sonidos | Voces de error, diálogos, mascotas, gestos y tu lista (con "Ver tu lista") |

### Solo las misiones de tu ruta

`Misiones.lua` pregunta si una misión es de tu ruta a `AlfaRuta.EnRuta(questID)` cuando la ruta de Alfa lo publica; si no, a la guía del motor (`Engine.WantsQuest("accept", q)`). Lo que deja por no ser de la ruta no queda marcado: si cambias de ruta, la vuelve a ofrecer. Entregar las que ya llevas sigue igual.

## Comandos

- `/alfa comodidades`: abre su página (también `N.Abrir("comodidades")` desde otro módulo).
- `/alfa silenciar <número>`: agrega un sonido a tu lista por su número de archivo (FileDataID). `/alfa silenciar quitar <número>`, `/alfa silenciar borrar` y `/alfa silenciar` (muestra la lista).

## Ajustes (`comodidades.*`) y cómo vienen

Cada grupo tiene un interruptor principal y sus opciones dentro. **Los interruptores principales vienen apagados** y las opciones de dentro encendidas: así, al encender un grupo queda listo para usar.

| Clave | Por omisión | Qué hace |
|---|---|---|
| `misiones` (`misionesNormales`, `misionesDiarias`, `misionesSemanales`, `misionesEntregar`) | apagado (dentro: sí) | Aceptar y entregar todas las misiones: normales, diarias, semanales y entregar las completadas |
| `vueloParada` | sí (necesita el temporizador del motor, `maps.flightTimer`) | La siguiente parada en vuelos con escalas |
| `minimapa` (`minimapaCuadrado`, `minimapaBotones`, `minimapaMenu`) | apagado (dentro: sí) | Minimapa cuadrado, botones de addons ocultos (salen con el ratón) y sin el menú de addons |
| `colores` (`coloresJugador`, `coloresObjetivo`) | apagado (dentro: sí) | Colores de clase en tu marco y en el del objetivo |
| `cuadro` (`cuadroObjetivo`, `cuadroRango`, `cuadroCombate`, `cuadroShift`) | apagado (dentro: sí, sí, no, sí) | Cuadro de información: a quién apunta, rango de hermandad, ocultarlo en combate y verlo con Mayús |
| `probador` (`probadorBotones`, `probadorAnimacion`) | apagado (dentro: sí) | Probador: botones de objetos y control de la animación |
| `camara` | no | Alejar más la cámara |
| `grifos` | no | Ocultar los grifos de la barra de acción |
| `silenciarErrores`, `silenciarDialogos`, `silenciarMascotas`, `silenciarGestos`, `silenciarLista` | no | Silenciar grupos de sonidos del juego y tu lista propia |
| `chat` (`chatEstilo`, `chatOpacidad`, `chatPestanas`, `chatEscribir`, `chatLetra`, `chatBotones`) | apagado (dentro: `"igual"`, 0.7, sí, sí, sí, no) | El chat con el estilo de Alfa |
| `minimapaEstilo` (`minimapaEstiloTema`, `minimapaCabecera`) | apagado (dentro: `"igual"`, sí) | El minimapa con el estilo de Alfa |
| `barras` (`barrasEstilo`, `barrasBotones`, `barrasGrifos`, `barrasExperiencia`, `barrasMenu`) | apagado (dentro: `"igual"`, sí, `"como"`, sí, sí) | Las barras de abajo con el estilo de Alfa. `barrasGrifos`: `"como"`, `"color"` u `"ocultar"` |

Los tres `*Estilo`/`*EstiloTema` valen `"igual"` (sigue el estilo de Ajustes > Apariencia y cambia con él), `"alfa"`, `"clasico"` o `"cristal"`.

Para que un grupo venga encendido de fábrica basta cambiar su valor en `M.AJUSTES` (Comodidades.lua). Lo que enciende "Encender las recomendadas" está en `RECOMENDADAS` (Pagina.lua).

## El estilo de Alfa en el chat, el minimapa y las barras

`Estilo.lua` tiene lo común: el estilo de cada parte (`M.EstiloDe`), los colores de un estilo aunque no sea el de ahora (`M.ColorDe`: con el mismo estilo que Alfa salen los tokens del tema, con otro los valores fijos de ese estilo), la letra (`M.CaraDe`), la piel (`M.Piel`: la forma de Alfa del Kit, o el marco de los cuadros de información en Clásico WoW) y `M.Toques()`, que recuerda cada transparencia, región oculta y letra que se cambia en una pieza de Blizzard para devolverla tal cual. Las tres partes se repintan solas al cambiar el estilo, el esquema o el acento de Alfa (un pintor de `K.Pintar`) y al cambiar sus ajustes. **Al apagarlas todo vuelve sin /reload.**

- **Chat** (`Chat.lua`): oculta los fondos y bordes de Blizzard (`CHAT_FRAME_TEXTURES`, con `:Hide()`, porque Blizzard solo funde los que se ven) y pone detrás del texto un marco propio en la capa `BACKGROUND`. Pestañas y caja para escribir: su arte queda transparente y se dibuja el propio (la pestaña elegida con línea de acento; la caja con borde de acento mientras escribes); en Clásico WoW quedan las del juego. La letra cambia solo de cara: el tamaño sigue en el menú de la pestaña. Sigue a las ventanas nuevas y a los susurros con `hooksecurefunc` (`FCF_OpenNewWindow`, `FCF_OpenTemporaryWindow`, `FCF_DockUpdate`, `FCFTab_UpdateColors`).
- **Minimapa** (`MinimapaEstilo.lua`): cuadrado, un bisel detrás del mapa en lugar del borde fino de `Minimapa.lua`; redondo (Alfa y Cristal), el aro de Blizzard transparente y un aro propio (`Media/anillo-bisel.tga`, `Media/anillo-linea.tga`: 256 px, blancos; el bisel cubre del radio 96 al 105 de un mapa de 198 dibujado con 6 px de más, la línea del 96 al 97,5). Con el minimapa girando queda el aro de Blizzard (lleva el norte). La barra de la zona (`MinimapCluster.ZoneTextButton`) con una caja de Alfa y la letra del estilo en la zona y la hora.
- **Barras** (`Barras.lua`): `MainActionBar` (su `BorderArt` y los grifos de `EndCaps`), los botones de todas las barras (`bar.actionButtons`: marco, ranura vacía, brillos, máscara y recorte del ícono, letra de tecla, cuenta y macro), `MainStatusTrackingBarContainer`/`SecondaryStatusTrackingBarContainer` (`BarFrameTexture`) y `MicroMenu`/`BagsBar`. Los botones son seguros: solo se tocan texturas, colores, letras, transparencias y Show/Hide de arte, siempre fuera de combate; nada se mueve, reparenta ni recibe atributos, y no se engancha ningún método suyo. Se vuelve a aplicar al salir de Edit Mode. En Clásico WoW quedan las del juego.

## Lo que ya hace el motor (no se duplica)

- Vender objetos grises y su resumen en el chat; reparar, primero con el banco de la hermandad, y su resumen (Calidad de vida > Mercaderes).
- Recordatorios de entrenador y hechizos nuevos al subir de nivel (Mercaderes > Entrenadores).
- Aceptar y entregar las misiones de la guía, texto instantáneo, saltar diálogos de una opción, botín rápido, ocultar errores de combate (Misiones).
- Aceptar resurrecciones salvo que quien resucita esté en combate, aceptar invocaciones, liberar en campos de batalla.
- Invitaciones de amigos y hermandad, rechazar desconocidos, invitaciones de hermandad y duelos: la hermandad **siempre** cuenta como amiga.
- Abrir el mapa de vuelo y el temporizador de vuelo con destino, tiempo y barra (Viajes).
- El zoom del minimapa con la rueda del ratón ya lo trae el juego en Forever.

## Para verificar en el juego

1. `/reload` y abrir `/alfa comodidades`: la página propia en Ajustes, con el botón "Encender las recomendadas" (al pulsarlo, la tarjeta dice que están listas) y cada grupo con sus opciones atenuadas mientras está apagado.
2. **Misiones**: con «solo las misiones de mi ruta» encendido en la ruta, un PNJ con una misión que no es de tu ruta no se la acepta (la fila de Misiones lo avisa). Con él apagado y "Aceptar y entregar todas las misiones" encendido, hablar con un PNJ que da misiones que no son de la guía; que acepte y entregue solo. Mayús lo detiene. Una misión que pide tela no se entrega y lo dice una vez. Una misión con varias recompensas espera a que elijas. Con una misión de la guía no debe pasar nada raro (la hace el motor).
3. **Vuelo**: un vuelo con escalas (uno en el que el mapa de vuelo dibuja varios tramos): bajo el temporizador sale "Siguiente parada" con el lugar y el tiempo, cambia al pasar cada escala y desaparece en el último tramo. Probar un `/reload` en el aire.
4. **Minimapa**: cuadrado con borde fino; el aro de Blizzard desaparece; los botones de addons (también el de Alfa) aparecen al pasar el ratón; el número de addons de la esquina no está. Al apagarlo, todo vuelve. Revisar que no se oculte nada de Blizzard (correo, rastreo, reloj, cola de grupo) ni pines de mapas.
5. **Colores de clase**: el fondo bajo tu nombre en tu marco (que encaje con el arte del marco, en espejo del objetivo) y el de un jugador objetivo en su color de clase; una criatura sigue en rojo/amarillo/verde.
6. **Grifos**: desaparecen de la barra principal y vuelven al apagar; Edit Mode sigue funcionando.
7. **Cuadro de información**: "Objetivo: ..." y "¡Tú!" cuando una criatura te apunta; rango de alguien de tu hermandad; en combate el cuadro de las unidades del mundo no sale y con Mayús sí; el de los marcos sigue. En mazmorras en combate no debe dar errores.
8. **Probador** (Ctrl + clic en un objeto): siete botones a cada lado con los íconos de lo que lleva el modelo; clic oculta y vuelve a poner; "Restablecer" lo olvida. Abajo, las flechas cambian la animación y Pausa la detiene. Revisar que los números de animación (0, 4, 5, 60, 66-71, 74, 75, 77, 80, 82, 84) hagan lo que dice su nombre.
9. **Cámara**: alejar al máximo; si Forever no acepta 2.6 se queda en 2. Al apagar vuelve tu distancia.
10. **Sonidos**: cada casilla calla lo que dice y al apagarla vuelve (también se ve en Opciones > Audio). `/alfa silenciar 12345` con la lista encendida.
11. **Estilo del chat**: encenderlo con cada estilo (Alfa, Clásico WoW, Cristal) y con «Igual que Alfa» cambiando el estilo en Ajustes > Apariencia: el panel, la pestaña elegida con su acento, la caja para escribir (borde de acento al escribir), la letra. Abrir una ventana nueva y recibir un susurro en ventana aparte: salen con el estilo. Ocultar los botones. Apagarlo: todo vuelve como Blizzard (fondos al pasar el ratón incluidos). **En combate y en una mazmorra**: escribir `/cast` o usar una macro desde el chat sin errores de «acción bloqueada».
12. **Estilo del minimapa**: redondo y cuadrado en los tres estilos (el aro propio debe cubrir el borde del mapa sin dejar ver el de Blizzard; ajustar el radio en los .tga si no encaja), la barra de la zona y la hora, girar el minimapa (queda el aro de Blizzard) y apagarlo.
13. **Estilo de las barras**: los botones con borde del estilo, ícono cuadrado, tecla con la letra de Alfa; la ranura vacía al arrastrar un hechizo; los brillos al pasar el ratón y al estar activo; grifos de color y ocultos; experiencia, menú y bolsas. Edit Mode (ocultar el arte de la barra, mover barras) y luego salir. Cambiar de estilo en combate: se aplica al salir. Apagarlo: vuelve el arte del juego. Revisar en `/console taintLog 1` que no aparezca nada de Alfa_Comodidades.
