# Alfa - Comodidades

Reemplaza a **Leatrix Plus** dentro de Alfa. Solo hace lo que el motor de Alfa todavía no tenía; lo demás ya viene en Alfa y no se repite. Todo es código propio (Leatrix no tiene licencia libre: solo se imitan sus funciones).

## Dónde está

Ventana de Alfa > **Calidad de vida** (la página que ya existía):

| Pestaña > sección | Qué hay |
|---|---|
| Misiones > **Todas las misiones** | Aceptar y entregar todas las misiones, con opciones para normales, diarias, semanales y entregar las completadas |
| Viajes > Temporizador de vuelo | **Mostrar la siguiente parada** en vuelos con escalas |
| Mapa > Minimapa | **Mejorar el minimapa**: cuadrado, ocultar los botones de addons (aparecen con el ratón) y ocultar el menú de addons |
| **Interfaz** (pestaña nueva) | Colores de clase en tu marco y en el del objetivo · ocultar los grifos de la barra · cuadro de información (a quién apunta, rango de tu hermandad, ocultarlo en combate y verlo con Mayús) · probador (botones de objetos y control de animación) · alejar más la cámara · silenciar sonidos |

## Comandos

- `/alfa comodidades`: abre la pestaña Interfaz de Calidad de vida (también `N.Abrir("comodidades")` desde otro módulo).
- `/alfa silenciar <número>`: agrega un sonido a tu lista por su número de archivo (FileDataID). `/alfa silenciar quitar <número>`, `/alfa silenciar borrar` y `/alfa silenciar` (muestra la lista).

## Ajustes (`comodidades.*`) y cómo vienen

Cada grupo tiene un interruptor principal y sus opciones dentro, como en Leatrix. En la configuración de Leatrix de quien juega **los interruptores principales están apagados** (ClassColFrames, MinimapModder, TipModEnable, EnhanceDressup, AutomateQuests, ShowFlightTimes, MaxCameraZoom y MuteGameSounds en Off) y las opciones de dentro están en On (los valores de fábrica de Leatrix). Alfa los copia igual: los principales vienen apagados y las de dentro encendidas, así al encender un grupo queda como en Leatrix.

| Clave | Por omisión | Leatrix |
|---|---|---|
| `misiones` (`misionesNormales`, `misionesDiarias`, `misionesSemanales`, `misionesEntregar`) | apagado (dentro: sí) | AutomateQuests (AutoQuestRegular, Daily, Weekly, Completed) |
| `vueloParada` | sí (necesita el temporizador del motor, `maps.flightTimer`) | FlightBarNextHop |
| `minimapa` (`minimapaCuadrado`, `minimapaBotones`, `minimapaMenu`) | apagado (dentro: sí) | MinimapModder (SquareMinimap, HideMiniAddonButtons, HideMiniAddonMenu) |
| `colores` (`coloresJugador`, `coloresObjetivo`) | apagado (dentro: sí) | ClassColFrames (ClassColPlayer, ClassColTarget) |
| `cuadro` (`cuadroObjetivo`, `cuadroRango`, `cuadroCombate`, `cuadroShift`) | apagado (dentro: sí, sí, no, sí) | TipModEnable (TipShowTarget, TipShowRank, TipHideInCombat, TipHideShiftOverride) |
| `probador` (`probadorBotones`, `probadorAnimacion`) | apagado (dentro: sí) | EnhanceDressup (DressupItemButtons, DressupAnimControl) |
| `camara` | no | MaxCameraZoom |
| `grifos` | no | (favorito de Leatrix) |
| `silenciarErrores`, `silenciarDialogos`, `silenciarMascotas`, `silenciarGestos`, `silenciarLista` | no | MuteGameSounds / MuteCustomSounds |

Para que un grupo venga encendido de fábrica basta cambiar su valor en `M.AJUSTES` (Comodidades.lua).

## Lo que ya hace el motor (no se duplica)

- Vender objetos grises y su resumen en el chat; reparar, primero con el banco de la hermandad, y su resumen (Calidad de vida > Mercaderes).
- Recordatorios de entrenador y hechizos nuevos al subir de nivel (Mercaderes > Entrenadores).
- Aceptar y entregar las misiones de la guía, texto instantáneo, saltar diálogos de una opción, botín rápido, ocultar errores de combate (Misiones).
- Aceptar resurrecciones salvo que quien resucita esté en combate (AutoResNoCombat), aceptar invocaciones, liberar en campos de batalla.
- Invitaciones de amigos y hermandad, rechazar desconocidos, invitaciones de hermandad y duelos: la hermandad **siempre** cuenta como amiga (FriendlyGuild, que en Leatrix está en On).
- Abrir el mapa de vuelo y el temporizador de vuelo con destino, tiempo y barra (Viajes).
- El zoom del minimapa con la rueda del ratón ya lo trae el juego en Forever.

## Para verificar en el juego

1. `/reload` y abrir `/alfa comodidades`: la pestaña Interfaz y las secciones nuevas en Misiones, Viajes y Mapa se ven con el estilo de Alfa.
2. **Misiones**: con "Aceptar y entregar todas las misiones" encendido, hablar con un PNJ que da misiones que no son de la guía; que acepte y entregue solo. Mayús lo detiene. Una misión que pide tela no se entrega y lo dice una vez. Una misión con varias recompensas espera a que elijas. Con una misión de la guía no debe pasar nada raro (la hace el motor).
3. **Vuelo**: un vuelo con escalas (uno en el que el mapa de vuelo dibuja varios tramos): bajo el temporizador sale "Siguiente parada" con el lugar y el tiempo, cambia al pasar cada escala y desaparece en el último tramo. Probar un `/reload` en el aire.
4. **Minimapa**: cuadrado con borde fino; el aro de Blizzard desaparece; los botones de addons (también el de Alfa) aparecen al pasar el ratón; el número de addons de la esquina no está. Al apagarlo, todo vuelve. Revisar que no se oculte nada de Blizzard (correo, rastreo, reloj, cola de grupo) ni pines de mapas.
5. **Colores de clase**: el fondo bajo tu nombre en tu marco (que encaje con el arte del marco, en espejo del objetivo) y el de un jugador objetivo en su color de clase; una criatura sigue en rojo/amarillo/verde.
6. **Grifos**: desaparecen de la barra principal y vuelven al apagar; Edit Mode sigue funcionando.
7. **Cuadro de información**: "Objetivo: ..." y "¡Tú!" cuando una criatura te apunta; rango de alguien de tu hermandad; en combate el cuadro de las unidades del mundo no sale y con Mayús sí; el de los marcos sigue. En mazmorras en combate no debe dar errores.
8. **Probador** (Ctrl + clic en un objeto): siete botones a cada lado con los íconos de lo que lleva el modelo; clic oculta y vuelve a poner; "Restablecer" lo olvida. Abajo, las flechas cambian la animación y Pausa la detiene. Revisar que los números de animación (0, 4, 5, 60, 66-71, 74, 75, 77, 80, 82, 84) hagan lo que dice su nombre.
9. **Cámara**: alejar al máximo; si Forever no acepta 2.6 se queda en 2. Al apagar vuelve tu distancia.
10. **Sonidos**: cada casilla calla lo que dice y al apagarla vuelve (también se ve en Opciones > Audio). `/alfa silenciar 12345` con la lista encendida.
