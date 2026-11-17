# Alfa - Recolección

Muestra en el mapa del mundo y en el minimapa los nodos de **minería**, **hierbas**, **bancos de peces** y **tesoros** de WoW Forever: los de la base incluida (unos 25 000 nodos en 46 zonas: sus 35 000 puntos sin repetidos; su origen está en `CREDITOS.md`) más los que tú descubres al recolectar. Arma **rutas de farmeo** en tu zona y lleva el **historial** de lo que recolectas.

## Qué hace

- **Pines** con el ícono del recurso en un círculo y un aro del color de su tipo (cobre la minería, verde las hierbas, azul la pesca, oro los tesoros). Lo que tu habilidad todavía no alcanza se ve gris y tenue. Al pasar el ratón: nombre, nivel necesario (en el color de tu habilidad, como el juego), cuántas veces lo recolectaste y cuándo fue la última.
- **Mapa del mundo**: solo la zona que miras y lo que se ve; los nodos que se pisarían en pantalla van en un pin con su cantidad y se separan al acercar. Clic en un pin: la flecha de Alfa te lleva ahí.
- **Minimapa**: los nodos que tienes cerca, con giro, zoom y forma del minimapa (la geometría del motor).
- **Filtros**: por tipo, "solo lo que ya puedes recolectar" y "ocultar lo de profesiones que no tienes" (encendido: sin Herboristería no ves hierbas).
- **Detección** por el hechizo (enviado, terminado y botín) y además por el objeto que da el botín, así reconoce nodos con nombres que no conoce (y los aprende) y los bancos de peces.
- **Ruta de farmeo**: en tu zona, junta los nodos del tipo o recurso elegido en paradas, los ordena en una vuelta cerrada corta (vecino más cercano + 2-opt, sin trabar el juego) y la dibuja en el mapa. "Guiarme" pone la flecha en la parada más cercana y pasa a la siguiente al llegar o al recolectar ahí. No incluye lo que tu habilidad aún no alcanza.
- **Historial** (por personaje): esta sesión por recurso y por tipo, por hora, lo que obtuviste, por zona y las sesiones anteriores. Una sesión sigue tras un `/reload`.
- **Sin otros addons**: Alfa no depende de ningún addon de recolección ni importa de ellos; la base incluida (con su aviso de licencia MIT) y lo que tú descubres son todo lo que usa.
- **Página con el Kit** (`Recoleccion.lua`): arriba tu ruta de farmeo con la acción de ahora (crearla, guiarte con su avance en huellas, detenerla o borrarla) y qué recolectar (tipo y recurso); después esta sesión en números (solo si ya recolectaste algo); lo recolectado en listas que solo aparecen con datos (por recurso, objetos, por zona, sesiones anteriores; sin nada, el lobo dormido con qué hacer); los ajustes y tus datos (borrar lo descubierto o el historial, con confirmación).
- **Alfa_Mundo**: si está, cada tipo es una capa en su control de capas (`recoleccion.mineria`, `recoleccion.hierbas`, `recoleccion.pesca`, `recoleccion.tesoros`).

## Comandos

- `/alfa recoleccion` abre la página.
- `/alfa recoleccion ruta [mineria|hierbas|pesca|tesoros]` crea la ruta en tu zona y empieza a guiar.
- `/alfa recoleccion guiar` · `/alfa recoleccion parar` siguen o detienen la ruta.
- `/alfa recoleccion mapa` · `/alfa recoleccion minimapa` muestran u ocultan los pines.

## Ajustes (`recoleccion.*`)

`mapa`, `minimapa`, `tamanoMapa`, `tamanoMinimapa`, `mineria`, `hierbas`, `pesca`, `tesoros`, `soloProfesiones` (sí), `soloHabilidad` (no), `agrupar` (sí), `base` (sí), `rutaTipo`, `rutaRecurso`. Todos están en la página y en la búsqueda del menú.

Datos: `N.Datos("recoleccion")` guarda los nodos descubiertos (`nodos[mapa] = { {x, y, k, o, n, t}, ... }`) y los nombres aprendidos; `N.DatosPersonaje("recoleccion")` el historial. (Un `importadoOtro` que haya quedado de la versión 0.1 ya no se usa.)

## Para verificar en el juego

1. La página: en tu zona, la tarjeta de arriba dice cuántos lugares hay y "Crear ruta"; en una ciudad o mazmorra, que ahí no hay nodos (sin botón). Sin nada recolectado, las listas no aparecen: solo el lobo dormido.
2. Abrir el mapa en Elwynn (o donde estés): se ven los pines, el cuadro de información dice nombre, "Requiere Minería (N)" con color, y cuántas veces. Hacer zoom: los grupos con número se separan. Pasar el mapa a otra zona y volver.
3. Clic izquierdo en un pin: la flecha va ahí. Clic derecho sobre un pin: el mapa se aleja como siempre (el botón pasa al mapa).
4. Minimapa: los pines siguen al caminar y al girar (probar con "Girar minimapa" encendido), al hacer zoom y en un minimapa cuadrado. No tapan la flecha del jugador.
5. Minar un filón y herborizar: el historial suma, el botín aparece en "Lo que obtuviste", el pin dice "Lo recolectaste 1 vez". Probar un nodo que no esté en la base: aparece un pin nuevo.
6. Pescar en un banco: cuenta en "Bancos de peces" (depende de que el botín diga que viene del banco; ver supuestos).
7. Abrir un cofre (hechizo Abrir) y, con pícaro, forzar un baúl de prácticas.
8. Crear una ruta (Minería, todos), "Ver en el mapa": línea cerrada sobre los pines. "Guiarme": la flecha a la parada más cercana; al llegar pasa a la siguiente. Hacer clic en otra cosa del mapa: la ruta deja de guiar y lo avisa en el chat.
9. Sin Herboristería: las hierbas no se ven; apagar "Ocultar lo de profesiones que no tienes" y se ven. Encender "Solo lo que ya puedes recolectar": desaparece lo gris.
10. En una mazmorra: no hay pines en el minimapa ni se anota nada.
11. `/alfa hide` (ocultar Alfa): los pines del mapa y del minimapa se van; al volver, regresan.
12. Con el modo de mando (gamepad) del juego: abrir y cerrar el mapa varias veces sin el aviso de "acción bloqueada".
13. Con Alfa_Mundo: sus capas de Recolección encienden y apagan cada tipo.
