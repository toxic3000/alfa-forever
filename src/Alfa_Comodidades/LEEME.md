# Alfa - Comodidades

Comodidades de calidad de vida dentro de Alfa. Solo hace lo que el motor de Alfa todavía no tenía; lo demás ya viene en Alfa y no se repite. Todo es código propio.

## Dónde está

Su propia página, hecha con el Kit (`Pagina.lua`): **Ajustes > Comodidades** (`/alfa comodidades`). Arriba, el estado y un botón para **encender las recomendadas** (colores de clase, cuadro de información, probador, siguiente parada del vuelo y sin voces de error); debajo, un grupo por comodidad con su interruptor principal y sus opciones dentro, atenuadas mientras está apagado. Lo que este cliente no tiene (probador, la variable de la cámara, los grifos, un sonido) no se muestra. Todos sus controles también salen en la búsqueda de ajustes de la ventana de Alfa.

| Grupo | Qué hay |
|---|---|
| Misiones | **Aceptar y entregar todas las misiones**, con normales, diarias, semanales y entregar las completadas. Con «solo las misiones de mi ruta» (`ruta.soloRuta`, de la ruta de Alfa) encendido, **no acepta nada fuera de tu ruta** (lo dice en la fila) |
| Viajes | **Mostrar la siguiente parada** en vuelos con escalas |
| Minimapa | Cuadrado, ocultar los botones de addons (aparecen con el ratón) y el menú de addons |
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

Para que un grupo venga encendido de fábrica basta cambiar su valor en `M.AJUSTES` (Comodidades.lua). Lo que enciende "Encender las recomendadas" está en `RECOMENDADAS` (Pagina.lua).

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
