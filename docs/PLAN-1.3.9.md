# Alfa 1.3.9: 100 mejoras (propuesta)

Estado: **propuesta para revisar con Toxic.** Nada está hecho todavía.

## 1. «Cerrar mis misiones», de verdad (1–12)
Pedido de Toxic: el botón de Hoy no hace nada; al darle clic debe armar un recorrido que te lleve a completar **todas** las misiones de tu diario en el mejor orden.

1. **[BUG]** El botón de Hoy llama al plan sin filtro y usa el último que elegiste («solo listas», «solo esta zona»); si así no queda nada, solo sale un aviso que se pierde. Desde Hoy arma siempre con **todas** tus misiones.
2. **[BUG]** Si falta la base de misiones, el plan no se arma y no te dice por qué. Que la cargue sola (con «Preparando tu ruta…») y siga.
3. Al dar clic, una **tarjeta de avance** clara («Midiendo caminos… 40 %») y al terminar se abre la ruta con la flecha apuntando a la primera parada.
4. **El mejor orden de verdad:** agrupa por zona y por PNJ, junta objetivos cercanos (matar, recoger y usar en el mismo lugar), mete los vuelos y la piedra de hogar cuando ahorran tiempo, y deja las entregas para el final de cada zona.
5. **Misiones que no puedes terminar ahora** (élite, mazmorra, nivel alto, de grupo): van aparte, en «Para después», con su porqué, y no rompen la ruta.
6. **Antes de salir, un resumen:** «12 misiones · 4 zonas · unos 55 min · +8,400 XP», con «Empezar», «Ver paradas» y «Quitar algunas».
7. **Elegir cuáles entran** con casillas (todas marcadas de fábrica), y «Solo de esta zona» / «Solo listas» como atajos, no como trampas escondidas.
8. **La ruta se rehace sola** cuando terminas, abandonas o tomas una misión (sin perder lo hecho).
9. **Ver la ruta en el mapa de Alfa:** las paradas numeradas con el camino dibujado.
10. Al terminar cada misión, «¡Lista! Sigue: X» y la flecha pasa a la siguiente parada.
11. Al cerrar la última, festejo de Lya y la cuenta: tiempo, XP y misiones cerradas.
12. El mismo plan desde la página Ruta, el rastreador, el menú de Alfa y el Escritorio (un solo botón para todo).

## 2. Lo que quedó pendiente de la 1.3.8 (13–17)
13. Candado automático para **herramientas de oficio** (caña, pico, martillo, cuchillo de desollar) y objetos de viaje.
14. **[BUG]** El número de recarga («55m») se sale de su casilla dentro de las bolsas.
15. **[BUG]** La captura de Hoy de la galería muestra textos en inglés en la vista en español («Into Vallefresno»): revisar que los títulos de pasos de guía salgan traducidos o con su nombre en español.
16. «Separar» en las bolsas: que los épicos con candado sí salgan como «a la subasta» si tú quieres (ajuste).
17. Dos pantallas: soporte para el segundo monitor a la **izquierda** en el modo de un clic.

## 3. Rendimiento y estabilidad (18–25)
18. Medir de nuevo la entrada con todo lo de la 1.3.8 y bajarla otra vez (meta: menos de 45 ms en el banco).
19. Los paneles del Escritorio y el rastreador comparten una sola lectura de la guía por segundo.
20. La Enciclopedia: filtros y etiquetas listos más rápido (cálculo en segundo plano la primera vez que la abres).
21. Una revisión de memoria: soltar lo que no se ve (ventanas cerradas que guardan miles de filas).
22. Datos guardados más chicos: podar historiales viejos (sesiones de pesca, avisos, botín) con topes claros.
23. Una prueba de «sesión larga» en el banco: 3 horas simuladas sin que crezca la memoria ni los relojes.
24. Un informe de errores dentro de Alfa más útil: `/alfa reportar` adjunta la versión, los módulos y los últimos errores sin datos privados.
25. Revisión independiente de toda la 1.3.9 antes de publicar.

## 4. Aventura y misiones (26–33)
26. **Misiones grises:** «Abandonar todas las grises» con un clic y confirmación.
27. **Diario lleno:** cuando estás cerca de 20/20, Alfa te sugiere cuáles abandonar (grises, lejanas o de otra zona).
28. Recompensas: al entregar, Alfa marca la mejor para ti y por qué (mejora de equipo o la que más vale).
29. Misiones compartidas: al entrar en grupo, «Yuki y tú tienen 3 misiones en común: ¿armamos la ruta juntos?».
30. Objetos de misión: botón para usarlos desde el rastreador (seguro, con tu clic) cuando estás cerca del objetivo.
31. Cadenas de misiones: en la ficha de la misión, la cadena completa y en qué paso vas.
32. «¿Por qué no puedo tomar esta misión?»: Alfa te dice qué te falta (nivel, misión previa, reputación).
33. Marcas en el mapa del juego para las paradas de la ruta (además del mapa de Alfa).

## 5. Interfaz y comodidad (34–42)
34. Hoy más claro: una sola «Siguiente acción» grande arriba, lo demás en tarjetas chicas.
35. Tutorial corto la primera vez que abres cada página (3 pasos, se puede saltar).
36. Atajos visibles: una tecla para «Cerrar mis misiones» y otra para la siguiente parada.
37. Todas las tarjetas de sugerencia con «Ahora no / No volver a mostrar».
38. Modo compacto del rastreador para pantallas chicas.
39. Ajustes: «Restablecer esta página» en cada página y un «Deshacer» del último cambio.
40. Un tema de colores más para daltonismo en mapas y rutas (no solo en avisos).
41. Lya: «¿Qué hago ahora?» te responde con tu siguiente mejor acción (la ruta, entrenar, reparar, vender).
42. Capturas de la galería al día con lo nuevo (y Hoy en español).

## 6. Personaje, oficios y La Jauría (43–50)
43. Pesca: aviso del pez de la semana cuando estás en su zona.
44. Pesca: récords con su fecha y lugar en la ficha del pez.
45. Bolsas: «Lo que me sobra» para vender o mandar a un alt en un clic (respetando el candado).
46. Oficios: la siguiente receta que sube tu habilidad más barata con lo que tienes.
47. Curación: guardar varios mapas de clics (uno por especialización) y cambiar en un clic.
48. Combate: el medidor guarda tus últimas 5 peleas para compararlas.
49. La Jauría: «¿Dónde está la manada?» en el Escritorio, con la zona y el nivel de cada lobo conectado.
50. La Jauría: lista de quiénes de tu hermandad usan Alfa y su versión (para saber quién debe actualizar).

## 7. Experiencia de usuario y calidad de lo que ya tenemos (51–100)

*Primera impresión y aprendizaje*
51. Bienvenida más corta: 3 pantallas en vez de 7, con «Ajustar más» para quien quiera.
52. Al terminar la bienvenida, Alfa te lleva a tu **primera acción real** (no solo a Hoy).
53. Cada página nueva que se ve por primera vez trae una línea de «para qué sirve» que se cierra sola.
54. Ayuda contextual: el «?» de cada página abre a Lya justo en la respuesta de esa página.
55. Un «Modo aprendiz» opcional: Lya explica cada aviso la primera vez que sale.

*Consistencia visual*
56. Revisión de todas las ventanas: márgenes, alturas de fila y tamaños de letra iguales en todo Alfa.
57. Todos los botones de acción con el mismo estilo (principal, secundario, peligro) y el mismo orden (aceptar a la derecha).
58. Íconos revisados: cada módulo con el suyo y sin íconos repetidos con distinto significado.
59. Estados vacíos con el lobo en todas las listas (sin «nada» seco).
60. Los 3 estilos (Alfa, Clásico, Cristal) revisados página por página con capturas.
61. Letra grande revisada en todas las páginas (nada cortado ni encimado).
62. Las ventanas de Alfa recuerdan su lugar y tamaño, todas igual.

*Textos y lenguaje*
63. Revisión completa de textos en español: tono, claridad y palabras iguales para lo mismo en todo Alfa.
64. Revisión de las traducciones con más uso (inglés, portugués, alemán) por frases que suenen raras.
65. Mensajes de error con «qué pasó» y «qué hacer», nunca técnicos.
66. Los números siempre con separador de miles y las monedas con su ícono, en todos lados.

*Avisos y ruido*
67. Un «Centro de avisos» en Ajustes: cada tipo de aviso con su interruptor y un botón «Probar».
68. Avisos que se repiten mucho en una sesión se callan solos («ya te lo dije 3 veces») con opción de reactivarlos.
69. Lya habla menos en la primera hora si eres jugador nuevo, para no abrumar.
70. Sonidos de Alfa revisados: volumen parejo entre todos.

*Rastreador y flecha*
71. El rastreador muestra solo lo esencial de fábrica; lo demás al pasar el ratón.
72. La flecha con modo «mínimo» (solo flecha y distancia).
73. Clic derecho en cualquier paso: «Llévame», «Omitir», «Ver en el mapa», «Abandonar misión» en el mismo orden siempre.
74. La distancia y el tiempo con el mismo formato en la flecha, el rastreador, Hoy y el Escritorio.

*Hoy y Planes*
75. Hoy ordenado por importancia real de ahora (en combate, en ciudad, en mazmorra cambia).
76. Tarjetas de Hoy que puedes ocultar o reordenar.
77. Planes: arrastrar para reordenar y ver el plan entero en el mapa.

*Mapa y mundo*
78. Mapa de Alfa: leyenda de capas con ejemplos y búsqueda de lugares por nombre.
79. Marcadores con nota y color, y compartir uno solo con un clic.
80. Anuncios de zona revisados en las zonas nuevas de Forever (nombres, niveles, colores).

*Bolsas y oro*
81. Búsqueda de bolsas más lista (por tipo, calidad, «sin usar», «mejora»).
82. Ordenar bolsas con tu orden preferido (y que no mueva lo que tiene candado si no quieres).
83. El banco y las bolsas de todos tus personajes con el mismo estilo de ventana.

*Combate, curación y mazmorras*
84. Combate: una página más simple de fábrica, lo avanzado plegado.
85. Curación: asistente de clics revisado paso a paso con dibujos de qué hace cada botón.
86. Mazmorras: «Prepárame» revisado con lista de cotejo que se va marcando.

*Pesca, comercio y oficios*
87. Pesca: la ventana revisada con menos pestañas visibles de fábrica (las demás en «Más»).
88. Comercio: el consejo del cuadro del objeto más corto y claro (una línea).
89. Oficios: lo que puedes fabricar ya, primero, con cuánto ganas.

*Enciclopedia*
90. Enciclopedia: la ficha con secciones plegables y «Guíame» siempre arriba.
91. Resultados de búsqueda que entienden errores de dedo y nombres en inglés y español.

*La Jauría y social*
92. La Jauría: la página ordenada en «Tu grupo», «Tu hermandad» y «Cerca».
93. Mensajes de la manada con un solo estilo y sin duplicados.

*Escritorio (dos pantallas)*
94. Más paneles: rastreador de misiones, «Cerrar mis misiones», Enciclopedia rápida.
95. Plantillas listas para monitores verticales y ultraanchos.

*Calidad interna*
96. Prueba visual automática: capturas de cada página comparadas con la versión anterior para detectar cambios no queridos.
97. Prueba de todos los comandos `/alfa` (que ninguno dé error ni quede sin respuesta).
98. Prueba de cada aviso en los 10 idiomas (que ninguno se corte).
99. Documentación interna al día (`docs/ARQUITECTURA.md`, `docs/PLAN.md`) con lo que ya se hizo.
100. Manual en PDF revisado de punta a punta con capturas nuevas.

## 8. Pedidos extra de Toxic (101–106)

101. **El Lobo Malo caza bichos (reportes de errores):** un lobo malo con su propio dibujo y animación aparece cuando Alfa atrapa un error de Lua («¡Atrapé un bicho!») o cuando abres `/alfa reportar`. Arma el reporte solo (versión, módulo, el error, qué hacías, tu clase y zona; nunca tu nombre ni tu reino) y lo guarda en una «jaula» de reportes pendientes.
    - **Cómo llega al Discord privado:** el juego no deja que un addon mande nada a internet, así que hay dos caminos:
      - **Copiar y pegar** en el buzón privado (como hoy, más fácil: un clic copia y un clic abre la invitación).
      - **Envío automático con el instalador:** `Instalar-Alfa.exe`, que ya corre fuera del juego, encuentra los reportes guardados y, con el permiso del jugador, los manda al canal privado del Discord. Para eso hace falta una dirección de envío (un webhook o el bot de ToxicHost). Un webhook metido en un programa público se puede sacar y usar para spam, así que lo seguro es que pase por el bot de ToxicHost, con límite de envíos.
102. **Marcador de La Jauría por bando:** cuántos lobos de la Horda y cuántos de la Alianza hay, visible para todos en la página de La Jauría (y en el Escritorio).
    - El juego no deja que la Horda y la Alianza se hablen por addon (y la 1.3.8 separó las facciones a propósito), así que cada quien solo puede contar en vivo a los de **su** bando.
    - El número de la otra facción se publicaría desde fuera: el bot de ToxicHost lo calcula (por ejemplo, con los roles del Discord) y el instalador lo trae al actualizar, o va en cada versión.
103. **Temática por bando:** Alfa se viste según tu facción. La Horda lleva rojo y bronce, con el emblema de la Horda y adornos de madera y hierro. La Alianza lleva azul y oro, con el emblema de la Alianza y adornos de piedra y plata. Se aplica en el marco de las ventanas, los anuncios, Hoy y el marcador. Es opcional, con un interruptor en Estilo y sonido.
104. **[BUG]** Al abrir la ventana de tu personaje sale un recuadro de pesca en la esquina de arriba a la derecha. Sospecho de la barra de conjuntos (`Bolsas/Cambio.lua`), que se ancla junto a la ventana del personaje, o de la espada de «A pelear» de Pesca. Hay que reproducirlo y corregirlo.
105. **Anuncios aún mejores:** animaciones más finas y cinematográficas (entrada, brillo, salida), con su tema por bando, y revisadas en cada tipo.
106. **Reportes con capturas de pantalla:** el Lobo Malo recuerda al jugador tomar una captura y le dice cómo adjuntarla en el Discord.

---
Lo que se queda fuera a propósito: nada que juegue por ti, que actúe en combate sin tu clic o que mande mensajes solo al chat de otros.
