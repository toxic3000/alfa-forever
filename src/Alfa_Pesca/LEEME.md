# Alfa - Pesca

Pescar con una sola tecla: lanzar y recoger con la misma, con autobotín, sonido amplificado, nombres ocultos mientras pescas y doble clic derecho. Todo es código propio de Alfa.

- **Una tecla:** la tecla lanza Pesca. Mientras el corcho está en el agua, la misma tecla lo recoge (pasa a `INTERACTTARGET` con `SetOverrideBinding` y la interacción suave, `SoftTargetInteract*`, apunta al corcho). Con el botín de pesca abierto la tecla no vuelve a lanzar (con las bolsas llenas perderías el pez); al cerrarse, vuelve a lanzar.
- **Doble clic derecho** (opcional) para lanzar, con su rapidez, "también en montura" y "doble clic mientras pescas vuelve a lanzar" (con Mayús, Ctrl o Alt hace lo contrario: recoge).
- **Mientras pescas:** recoger todo el botín de pesca aunque el botín automático esté apagado; sonido amplificado (sin música ni ambiente, efectos al volumen elegido, también con el juego en segundo plano); ocultar placas y nombres de PNJ (los hostiles conservan el nombre); ícono sobre el corcho.
- **Nunca en combate ni en vuelo:** la macro es `/cast [nocombat,noflying] Pesca`, y al entrar en combate todo vuelve a como estaba.
- **Todo vuelve a como estaba:** CVars y teclas se restauran unos segundos después de sacar el corcho (si vuelves a lanzar, siguen puestos y la música no se corta entre lanzamientos), al entrar en combate, al apagar el módulo, al recargar y al salir. El respaldo también se guarda en disco: si el juego se cierra de golpe pescando, se restaura al entrar. Si cambias tú uno de esos ajustes mientras pescas, queda tu valor nuevo.
- **Extras de Alfa:** tarjeta de estado (listo, pescando, sin caña, sin tecla, en pausa), habilidad de pesca con barra, lo que subiste en la sesión y la bonificación de cebo o equipo, y el registro de lo pescado en la sesión (cuántos de cada cosa, capturas, tiempo con la caña en el agua). La sesión empieza al entrar al juego (no al recargar).
- **Con otro addon de pesca cargado** (la lista está en `Compat.lua`): Alfa no liga nada ni cambia ajustes, avisa una vez en el chat y lo dice en su página. Toma una vez sus opciones como punto de partida y recuerda su tecla: cuando lo desactives, si Alfa no tiene tecla y esa sigue libre, la toma sola y lo avisa.

## Comandos

- `/alfa pesca`: abre la página.
- `/alfa pesca on` / `off`: el interruptor general.
- `/alfa pesca reiniciar`: empieza un registro nuevo.

La tecla se asigna en la página (clic y pulsa la tecla) o en el menú de atajos del juego: **Alfa > Pescar: lanzar y recoger** (`CLICK AlfaPescaBoton:LeftButton`).

## Ajustes (`AlfaDB.settings.pesca`)

| Clave | Por omisión | Qué hace |
|---|---|---|
| `activo` | sí | Interruptor general |
| `autobotin` | sí | Recoger todo lo pescado aunque el botín automático esté apagado |
| `ocultarNombres` | sí | Ocultar placas y nombres de PNJ mientras pescas |
| `sonido` / `volumen` | sí / 100 % | Sonido amplificado mientras pescas (y su volumen) |
| `dobleClic` / `velocidad` | no / 0,20 s | Doble clic derecho para lanzar (y su rapidez) |
| `montado` | no | El doble clic también lanza en montura |
| `relanzar` | sí | Doble clic mientras pescas vuelve a lanzar |
| `iconoCorcho` | sí | Ícono sobre el corcho |

Los valores por omisión son los que usa Toxic al pescar. Datos propios: `AlfaNucleoCharDB.pesca` (`sesion`, `respaldo`) y `AlfaNucleoDB.pesca` (`importadoOtro`, `teclasOtro`, `avisoOtro`).

## Para verificar en el juego

1. Con otro addon de pesca **activo**: sale el aviso una vez, la página dice "En pausa" y pescar con la tecla de ese addon sigue igual que siempre.
2. Desactiva el otro addon y recarga: Alfa avisa que tomó tu tecla. Púlsala con la caña puesta: lanza.
3. Cuando pica, la misma tecla recoge. Si no la recoge, prueba más cerca del corcho (alcance de la interacción suave) y revisa que aparezca el ícono sobre el corcho.
4. Tras recoger, la misma tecla vuelve a lanzar. Pulsarla con la ventana de botín abierta no lanza. Al soltar la tecla tras recoger tampoco relanza.
5. Sonido: al lanzar se apagan la música y el ambiente; unos 6 segundos después de terminar (sin volver a lanzar) todo vuelve a como estaba. Revisa las opciones de sonido del juego tras una sesión.
6. Nombres: al lanzar se ocultan las placas y los nombres de PNJ amistosos; los hostiles siguen. Al terminar vuelven.
7. Botín: con el botín automático del juego apagado, lo pescado se toma solo. El registro de la página suma bien (incluye pilas de 2 o más).
8. Entra en combate a media pesca: todo vuelve enseguida y la tecla no lanza en combate.
9. `/reload` pescando y `/reload` en combate: tras volver, sonido y nombres quedan como estaban.
10. Doble clic derecho (actívalo en la página): lanza en el mundo; no lanza montado (salvo "También en montura"), moviéndote, nadando ni en combate. Pescando: con "vuelve a lanzar" relanza, y con Mayús recoge. El clic derecho normal (girar la cámara, hablar con PNJ) sigue funcionando después.
11. Asigna y cambia la tecla desde la página (clic, pulsa, clic derecho la quita) y desde el menú de atajos del juego.
12. La habilidad de pesca y su barra se ven y suben; "+N en esta sesión" aparece al subir.
