# Alfa 1.3.7: 200 mejoras y correcciones (propuesta)

Estado: **propuesta para revisar con Toxic. Nada está hecho todavía.**

Salen de tus pedidos y de cuatro auditorías del código: avisos y momentos, aventura, personaje y oficios, e ideas de otros addons. Las marcadas **[BUG]** son errores que hoy le pasan al jugador. Los números de archivo son de la versión 1.3.6.

---

## 1. Tus pedidos (1–28)

### El oro en las bolsas
1. **[BUG]** El oro sale dos veces en el pie de Bolsas (el tuyo y «Cuenta: …»). Que quede solo el de tu personaje.
2. Botón de monedas junto a tu oro. Un clic abre «Tu oro» y otro lo cierra.
3. «Tu oro» enseña una fila por personaje, con el color de su clase. Primero tú, luego de más a menos oro, y «hace 3 días» en los demás.
4. Subtotal por reino y facción (ese oro no se pasa de uno a otro) y «Toda la cuenta» al final. Todo eso solo en el desglose.
5. «Esta sesión» dentro de «Tu oro»: ganaste, gastaste, del buzón, en total y por hora.
6. Clic en otro personaje del desglose: abre sus bolsas.
7. El cuadro del pie, al pasar el ratón, ya solo habla del espacio.
8. Viendo las bolsas de otro personaje, su oro dice de cuándo es («hace 2 días»).
9. **[BUG]** La sesión de oro se borra con /reload y el «por hora» sale mal. Que se guarde.

### Llegar a una zona se siente
10. Anuncio al **llegar** a una zona o subzona, no solo la primera vez que la descubres, como el de barcos y raros.
11. **Una animación distinta para cada tipo de anuncio**:
    - **zona:** baja con fundido y rayas largas;
    - **subzona:** fundido corto y pequeño;
    - **descubrir:** destello dorado y huellas que se dibujan;
    - **barco:** se desliza y ondea;
    - **zepelín:** baja flotando con balanceo;
    - **tranvía:** entra de lado y frena seco;
    - **raro:** salto con rebote;
    - **tesoro:** brillo que gira;
    - **mazmorra:** sube desde abajo, morado;
    - **ciudad o posada:** fundido lento y azul;
    - **zona peligrosa:** el borde late en rojo;
    - **llegada a tu destino:** el lobo aúlla;
    - **lobo de la manada:** huellas que cruzan.
12. Cada tipo con su color, ícono, sonido y duración. Las zonas toman el color según de quién son (verde amistosa, rojo hostil, ámbar disputada, azul santuario) y llevan su rango de niveles.
13. La primera vez que descubres una zona: brillo dorado y un dato de esa zona contado por Lya.
14. Que conviva con el nombre de zona que pone el juego. Con la opción «Alfa anuncia las zonas», el del juego se esconde y no salen dos.
15. Límites para que no canse:
    - nada en grifo ni en combate;
    - la misma zona no se repite antes de 10 minutos;
    - en una subzona a la que vas y vienes, esperar 20 s;
    - como mucho un anuncio cada 8 s.
16. En Ajustes, un interruptor y un botón «Probar» por cada tipo de anuncio.

### Subir de nivel se disfruta (sin ventanas encimadas)
17. Al subir de nivel, Alfa espera a que termine la animación del juego (y 1 s más) antes de mostrar algo.
18. Un solo mensaje de nivel con todo: «¡Nivel 12! 1 punto de talento · 3 habilidades por aprender · ya puedes ir a X», con dos botones.
19. **[BUG]** Al subir de nivel, Curación podía sacar un diálogo que oscurece toda la pantalla y no deja dar clic. Ahora solo sale un aviso con «Usarlo / Ahora no».
20. Ninguna ventana con fondo oscuro sale sola: solo con un clic tuyo. El banco de pruebas lo revisa.

### El medidor de daño (sí existía, pero apagado y escondido)
21. De fábrica en «automático»: sale solo en grupo, en banda o en una mazmorra. Solo en el mundo, no sale. A quien ya lo usaba se le respeta lo que tenía.
22. Más compacto: barras de 16 px en 220 px de ancho, una cabecera «Daño · 1:23», y lo demás (tipo de dato, anunciar, empezar de cero) en el clic derecho.
23. En grupo muestra 5 filas (tu grupo entero) y en banda las que elijas. Tu fila siempre está a la vista.
24. Poco invasivo:
    - de fábrica abajo a la derecha, arriba de las barras;
    - se atenúa 10 s después de la pelea;
    - en combate no atrapa clics.
25. La X lo esconde hasta tu próximo grupo; para apagarlo del todo está Ajustes.
26. Si tu cliente no trae el medidor del juego, nunca sale solo, y su página explica por qué.
27. Si el medidor del juego está apagado en tus opciones, Lya te dice una vez cómo encenderlo.
28. Fácil de encontrar: en el menú de Alfa, en «Acomodar la pantalla», en las respuestas de Lya y en el asistente.

---

## 2. Avisos, notificaciones y momentos (29–72)

29. **Un orquestador de momentos**: una sola cola para todo lo que Alfa muestra, una cosa a la vez y por prioridad.
30. La cola se pausa en combate, en cinemáticas, en pantallas de carga, mientras hablas con un PNJ y durante la animación de nivel del juego.
31. Después de una pantalla de carga, 3 s de calma: entrar a una mazmorra ya no suelta todo junto.
32. Hablando con un PNJ (misiones, vendedor, entrenador, maestro de vuelo), lo que no es urgente espera a que cierres. Lo de ese PNJ sí sale.
33. Lya ya no aúlla encima de la animación de nivel del juego.
34. El aviso de talento sale después, dentro del resumen de nivel, y no encima del estandarte del juego.
35. Un reto cumplido ya no trae un segundo aullido al subir de nivel.
36. El festejo de racha reemplaza al aullido normal en vez de sumarse.
37. Sin tirón al subir de nivel: unos 15 recálculos (guía, mazmorras, planes…) esperan a que termine la animación y se escalonan.
38. Los mensajes de La Jauría al subir de nivel (mentor, botín, logros) salen escalonados, no en el mismo instante.
39. Los avisos de Alfa esperan a que el juego termine sus propios estandartes (nivel, logros, jefe).
40. Los avisos y los anuncios ya no se encima unos sobre otros.
41. **[BUG]** Lo importante que Lya tenía guardado se perdía si llegaba otra cosa importante. Ahora es una lista con prioridad.
42. Con más de 3 avisos, el más viejo ya no desaparece sin leerse: espera su turno.
43. Un anuncio ya no pisa a otro (un raro tapaba la cuenta del barco): van por prioridad.
44. Si un anuncio espera mucho, lo vencido caduca (un barco que ya zarpó no se anuncia).
45. El sonido del anuncio suena cuando de verdad aparece, no antes.
46. El anuncio ya no atrapa clics en toda su franja: solo el título se puede tocar.
47. Clic derecho en un anuncio lo cierra.
48. Si empieza una pelea, el anuncio se desvanece rápido y vuelve después si todavía vale.
49. Los avisos que no son urgentes esperan a que termine la pelea.
50. **No molestar**: `/alfa calma` por 30 min, 1 h o la sesión. También respeta el /dnd del juego. Lo callado queda guardado.
51. «Te perdiste esto» completo: incluye tarjetas que caducaron, anuncios de barcos y raros, lo importante de Lya y los avisos sin botón.
52. Ese historial se guarda (los últimos 30 por personaje, con hora), y el botón del minimapa enseña un contador.
53. «Lo que me perdí» en el menú de Alfa.
54. Cuatro niveles claros de prioridad: urgente, importante, útil y detalle.
55. Una sola voz en más casos: talento, entrenador y hechizo nuevo ya no los dicen a la vez Talentos, Lya y Curación.
56. El aviso del entrenador sale una sola vez por nivel (hoy podía salir hasta tres veces).
57. **[BUG]** Curación decía lo del hechizo nuevo dos veces (un aviso y un diálogo). Ahora una sola.
58. Todo aviso importante dice qué hacer o dónde verlo. Una revisión automática lo comprueba.
59. La tarjeta de Hoy sale arriba a la derecha y ya no en el centro, donde estorba para apuntar.
60. Cada aviso dura según lo largo de su texto (de 5 a 15 s) y se pausa en combate.
61. Un solo ajuste manda sobre todos los anuncios grandes (hoy cada módulo decide por su lado).
62. «Un lobo de La Jauría anda cerca», en ciudades: aviso chico, y una vez al día por persona.
63. Un raro en plena pelea o dentro de una mazmorra: un ícono chico; el anuncio grande sale después, si el raro sigue ahí.
64. Si al barco le quedan menos de 10 s, el anuncio sale ya, compacto.
65. La placa de llegada de la flecha y el anuncio de zona salen en orden, no encimados.
66. Al entrar a una mazmorra, un anuncio morado con sus niveles y sus jefes (una vez cada 30 min por instancia).
67. Zona peligrosa para tu nivel: anuncio rojo «Zona de nivel 30–40: ve con cuidado».
68. Los anuncios se adaptan al tamaño de la pantalla (hoy miden 720 px fijos y se salen con la interfaz grande o en pantallas 4:3).
69. Sonidos suaves según el tipo de aviso, en vez de la alerta de banda (la tarjeta de Hoy usaba el sonido de alerta de banda).
70. Lya aúlla suave solo en lo importante; sus comentarios sueltos no suenan.
71. Ajuste «Sonidos de Alfa»: todos, solo los importantes o ninguno.
72. Prueba nueva del banco: subir de nivel con la animación del juego simulada. Falla si algo sale antes de tiempo, si salen dos cosas a la vez o si aparece un fondo que bloquea.

---

## 3. La aventura: ruta, guía, Hoy, mazmorras y mapa (73–124)

73. **[BUG]** Hoy decía «Guía completa» aunque te hubieras saltado pasos, y el rastreador decía otra cosa. Ahora los dos dicen lo mismo.
74. **[BUG]** Con la guía terminada, Ruta decía «Faltan 0 pasos». Ahora dice «¡Terminaste!» y ofrece «Seguir con X».
75. **[BUG]** «Guías con esta misión» de la Biblioteca no filtraba nada. Ahora te enseña solo esas guías, de un clic.
76. **[BUG]** «Vuelta a entregar» se ofrecía y luego decía «Necesitas al menos 2». Ahora cuenta igual al ofrecerla y al empezarla, y dice cuáles quedaron fuera.
77. **[BUG]** La barra del aviso de nivel enseñaba tu nivel de ahora, no la meta que te pide la ruta.
78. **[BUG]** Plurales rotos («quedaron 1 pasos», «1 misiones», «hace 1 días», «1 capas ocultas»…) en Rutas, Hoy, Mazmorras, Mundo, la Enciclopedia y La Jauría: unos 20 textos.
79. **[BUG]** El texto bajo una meta se cortaba cuando se juntaban «Antes», el lugar y «Vale la pena».
80. **[BUG]** «Mientras estás aquí» se cortaba con nombres largos en el rastreador compacto.
81. **[BUG]** La caja del objeto de misión se salía en alemán y francés.
82. «Omitir esta misión» desde el menú de una meta tiene «Deshacer», igual que omitir un paso.
83. **[BUG]** Las notas de guía en inglés se escondían solo en español; en los otros idiomas salían mezcladas.
84. **[BUG]** «Seguir con » salía vacío en algunas guías.
85. **[BUG]** La Vuelta se volvía a ofrecer aunque ya estuvieras entregando tus misiones.
86. Una sola manera de entregar tus misiones listas, con el mismo número en todos lados (hoy son 2, 3, 5 y 2 según la página).
87. La Vuelta sigue aunque hagas /reload o te reconectes.
88. La Vuelta suma la misión que terminas a medio camino.
89. Al terminar la guía, Hoy te propone la que sigue (como ya lo hace el rastreador).
90. Si al final te quedaron pasos sin hacer, Hoy ofrece «Elegir mi camino» o «Seguir con X».
91. «Esta guía no tiene un paso para ti ahora» dice por qué y ofrece «Recuperar lo omitido».
92. La Biblioteca enseña el estado de cada guía: terminada, «Paso 12 de 80», desde qué nivel y cuánta experiencia da.
93. La Biblioteca tiene «Ver detalle» antes de cargar una guía: zonas, recompensas y qué sigue.
94. El buscador de la Biblioteca encuentra guías por el nombre de una misión o de un PNJ.
95. Pestaña «Recientes» y favoritas en la Biblioteca.
96. Tiempo estimado por guía: «≈ 2 h a tu ritmo».
97. La experiencia que da cada entrega en el rastreador («+1,250 XP»), y «¡Con esta subes de nivel!».
98. En Hoy: «tus 4 misiones listas dan unos 3,200 XP», y si con entregarlas subes de nivel.
99. Tu experiencia de descanso a la vista: «Descansado: doble experiencia hasta X».
100. El aviso de nivel en algo que se entiende: «unos 14 jabalíes» y «≈ 25 min a tu ritmo».
101. Los tiempos se escriben igual en todo Alfa: «1 h 5 min» (hoy hay 5 formatos distintos).
102. La flecha dice «1 h 13 min» en vez de «73:05 en total».
103. «Ya llegaste» de Hoy y del rastreador concuerda con la llegada de la flecha.
104. La distancia y el rumbo se calculan en un solo lugar: Hoy y el rastreador ya no pueden decir cosas distintas.
105. «Ver el camino en el mapa» desde el rastreador y desde Hoy: abre el mapa de Alfa ya encuadrado.
106. Las metas sin misión (ir a un lugar, matar) también tienen menú: «Llévame», «Ver en el mapa» y «Omitir».
107. «Compartir con mi grupo» en el menú de una meta cuando vas en grupo.
108. La mazmorra recomendada toma en cuenta qué tan lejos está (ya no te manda a otro continente).
109. Si una mazmorra se abre pronto, ofrece «Recoger sus misiones ya».
110. Tarjeta en Hoy con tu mazmorra: «X · 3 misiones para recoger · Prepárame».
111. Dentro de una mazmorra, Hoy y el rastreador enseñan el siguiente jefe y las misiones que te faltan ahí.
112. Mazmorras recalcula menos: ya no lo hace cada vez que recoges botín.
113. La Enciclopedia enseña la experiencia de una misión a tu nivel, y si ya está gris.
114. La ficha de una zona en la Enciclopedia trae «Guía de esta zona» y «Circuito de la zona» a un clic.
115. La Biblioteca y la Enciclopedia se pueden agrandar y achicar (hoy no caben en pantallas chicas con la interfaz grande).
116. Las tarjetas de los lobos en La Jauría dicen qué misiones tienen en común contigo, con «Invitar».
117. «Sigues a X» en Hoy enseña la distancia y un botón para dejar de seguir.
118. **[BUG]** «Una hora de caza» contaba 0 misiones en las capitales.
119. Los minutos por misión del plan ya no cuentan el tiempo en subasta, en mazmorras ni ausente.
120. El ritmo de la guía no cuenta el tiempo en grifo.
121. La guía que sigue a la tuya se propone solo si es de tu nivel.
122. La tarjeta de guía en Ruta dice cuánto falta en tiempo, como Hoy.
123. «Cerrar mis misiones» en Hoy dice «12 · 4 listas», como la página Ruta.
124. El mapa de Alfa enseña sus atajos la primera vez (clic derecho: marcador; Ctrl+clic: llévame), y sus errores salen en pantalla, no en el chat.

---

## 4. Personaje y oficios (125–166)

125. **[BUG]** Lya cortaba el aviso de rangos viejos de Talentos y el aviso se quedaba esperando para siempre.
126. «Anunciar» del medidor ya no manda 11 líneas de golpe al chat (el juego podía frenarlas): manda 3 cortas.
127. La tarjeta del medidor en Combate dice cuándo aparece («Sale en grupo»).
128. El medidor deja de leer los datos dos veces cada medio segundo y solo se repinta cuando algo cambia.
129. **[BUG]** La tecla de pesca se atoraba intentando ponerte una pieza que no entra. Ahora se la salta y lanza.
130. El modo pesca ya no sube el volumen al 100 %: parte del volumen que tú tienes.
131. **[BUG]** Textos cortados en la barra de la subasta.
132. El consejo de Comercio ya no sale en la piedra de hogar, objetos de misión ni equipo ligado.
133. **[BUG]** «Guíame» en la lista de compras siempre decía el mismo motivo.
134. «Tomar todo» del buzón enseña cómo va, con un botón «Parar».
135. **[BUG]** La barra del lanzamiento de pesca no usaba la duración real.
136. **[BUG]** El escaneo de la subasta y la lectura de recetas corrían en combate.
137. **[BUG]** En Cocina se quedaban guardados ingredientes de respaldo («1 pescado crudo»).
138. Comercio ya no relee toda la profesión con cada pieza que fabricas.
139. **[BUG]** «Buen lanzamiento» falso cuando el ratón pasaba por otra cosa que no era el corcho.
140. **[BUG]** Los puntos de recolección del minimapa atrapaban clics en combate.
141. Precio por pila en el cuadro del objeto: «×20: 3o 40p».
142. La línea de resumen de la pesca ya no se corta.
143. Separador de miles según tu idioma (en alemán y francés la coma se lee como decimal).
144. Las metas de pesca dicen «2 h», no «120:00».
145. **[BUG]** Talentos le recomendaba una mano secundaria a quien no puede usar dos armas.
146. **[BUG]** Con un arma de dos manos, Talentos ofrecía escudos para la mano secundaria.
147. **[BUG]** La venda ignoraba tu nivel de Primeros auxilios y el clic fallaba.
148. Sin vendas en las bolsas, el clic de venda te lo dice.
149. **[BUG]** En marcos de curación bajos se encimaban el nombre y el estado. Ahora es una línea: «Nombre 45 %».
150. **[BUG]** Títulos de planes de talentos con letras rotas (se cortaban a la mitad de una letra).
151. Importar dos veces el mismo plan de talentos ya no lo duplica.
152. **[BUG]** «Deshacer» en Paisaje dejaba ajustes que no elegiste.
153. **[BUG]** Paisaje pedía reiniciar los gráficos sin hacer falta.
154. El botón de addons del minimapa se atenúa en vez de esconderse.
155. Aceptar misiones solas con la bitácora llena ya no da el error rojo del juego: avisa una vez.
156. La búsqueda de Lya encuentra sus 4 ajustes que faltaban.
157. El modo prueba de Curación imita el acomodo por grupos de verdad.
158. Se esconde la pestaña de banda de Blizzard que se quedaba junto a los marcos de Curación.
159. El cuadro de maná de Curación ya no tapa la barra para mover.
160. Las escalas del vuelo avanzan en la barra.
161. Consejos callados de Lya: se ve el tope y se pueden recuperar.
162. A la búsqueda de Paisaje le faltaban el tinte y las placas de mascotas.
163. `/alfa recoleccion mapa` y `/alfa recoleccion minimapa` ya hacen cosas distintas.
164. `/alfa comercio precio` acepta el nombre del objeto.
165. El buzón dice «piezas» y no «objetos» cuando cuenta piezas.
166. Los bancos de peces ya no se cuentan otra vez con cada pesca (por confirmar en el juego).

---

## 5. Funciones nuevas inspiradas en otros addons, con el estilo de Alfa (167–192)

167. **Barra de información**: una franja compacta y movible con FPS, latencia, oro de la sesión, durabilidad, espacio en bolsas, hora y experiencia por hora. Cada dato abre su página.
168. **Números en las recargas** de tus barras de acción: cuenta grande, color según lo que falta y destello al quedar lista.
169. **Tiempo para subir de nivel en la barra de experiencia**: «Nivel 34 en 1 h 20 min a tu ritmo», con el descanso y las misiones listas.
170. **«Sal de ahí»**: si estás parado en fuego o veneno de un jefe, sonido y flecha roja. Sin leer el registro de combate; se apaga si el juego esconde esos datos en mazmorra.
171. **Cuenta para jalar**: cuando alguien la lanza, Lya o un anuncio grande con la cuenta. Para lanzarla, un botón tuyo.
172. **Temporizadores de jefe sencillos**: «Próximo aliento en ~15 s», aprendidos pelea a pelea.
173. **Hora en el chat** y nombres con el color de su clase, solo en tu ventana.
174. **Copiar del chat**: clic en una dirección o en una línea y se puede copiar. Nada se envía.
175. **Susurros a la vista**: sonido propio e historial por persona, sin responder nada solo.
176. **Filtro de spam** en tu chat (venta de oro, mensajes repetidos), con «ver lo filtrado».
177. **Reputación al día**: «te faltan 1,200 para Honorable, ~8 misiones», y lo que desbloquea cada rango.
178. **Ver el equipo de un compañero** desde su clic derecho: nivel medio, piezas flojas y si le sirve tu botín.
179. **Nivel de objeto y durabilidad** sobre cada ranura de tu personaje y de la inspección.
180. **Cambiar de equipo con un clic**: botones con tus conjuntos (pesca, tanque, JcJ) y cambio al montar o al salir de combate.
181. **Mapas de mazmorra con los jefes numerados**; los que ya venciste, en verde.
182. **Faltan bufos en el grupo** antes de jalar: quién no tiene Intelecto, Marca o Entereza, con un botón para dárselo.
183. **«¿Listos?» con lo que te falta**: comida, munición, reparar, espacio en bolsas.
184. **Recordatorio de consumibles** al entrar a un jefe o a una banda.
185. **Tus efectos a la vista**: lo que le queda a tus DoT, escudos y demás, con aviso al caer.
186. **Botín de banda con historial**: quién se llevó qué y con qué tirada, sin anunciar nada.
187. **Contador de botín y oro por hora** de tu sesión de farmeo, y tu mejor zona.
188. **Gangas en la subasta**: «cuesta menos de lo que vale» o «se desencanta con ganancia». La compra es tuya.
189. **Mandar a tu alt** desde el buzón, con listas por personaje (hierbas a la alquimista…). El clic en Enviar es tuyo.
190. **ID en el cuadro** (objeto, hechizo, PNJ, misión) con Mayús o un ajuste avanzado, para reportes.
191. **Tiempo jugado** total, por nivel y en promedio, en Hoy, sin escribir en el chat.
192. **Cronómetro de mazmorras**: tu récord y «puedes entrar en 12 min» con el límite de instancias por hora.

---

## 6. Calidad para todo Alfa (193–200)

193. Un solo `N.Plural` para que ningún texto diga «1 misiones», en los 10 idiomas.
194. Un solo `N.Duracion` para todos los tiempos.
195. Las esperas sueltas de Comercio y Paisaje pasan al reloj de Alfa (`N.Una`), que ya cuida el combate y el rendimiento.
196. El banco de pruebas falla si un texto nuevo no trae su traducción a los 10 idiomas.
197. Prueba del oro: el pie sin «Cuenta:», el botón, el desglose con 3 personajes de 2 reinos, y nada se sale con mucho oro.
198. Prueba de los anuncios: cada tipo con su animación, sin encimarse, respetando taxi y combate.
199. Prueba del medidor: «automático» en grupo, solo y en mazmorra; sin el medidor del juego; la X; y que no atrape clics en combate.
200. Revisión independiente de toda la 1.3.7 antes de publicarla, como en la 1.3.5 y la 1.3.6.

---

**Lo que se queda fuera a propósito** (por las reglas de Blizzard o porque no se puede en Forever):
- Lanzar la cuenta para jalar o poner marcas de banda solo con un evento: siempre necesitan un clic tuyo.
- Leer el registro de combate: está restringido.
- Esconder el medidor de Blizzard desde Alfa: solo te decimos cómo hacerlo en el Modo de edición.
- Los bufos del mundo (Onyxia, Rend, Zandalar): primero hay que confirmar que existan en Forever.
