# Alfa 1.4.0: la manada firme (plan)

Cierre de la serie 1.3. Pedido de Toxic: las ideas de cierre (velocidad, pendientes de la 1.3, algo grande, calidad), **mejorar Dos pantallas** («lo probé realmente y no me gustó»), el **bug de las bolsas al restablecer** y **50 mejoras adicionales**.

## 0. Urgente (1–3)
1. **[BUG] Bolsas tras restablecer:** después de «Restablecer» (página o ajustes de Bolsas, o al volver de Dos pantallas) los números de las casillas salen gigantes y encimados (montón «20», nivel de objeto «27», recarga «56m» cortada), la cabecera aprieta los botones y la tarjeta de «bolsas llenas» se corta. Captura: `scratchpad/bug-bolsas-140.webp`. Encontrar la causa (escala/tamaño de letra que se pierde o se duplica al rehacer, `P.Rehacer`, el texto propio de recarga de la 1.3.9, escala de `UIParent` tras el Escritorio) y arreglarla de raíz, con prueba que restablezca y mida cada texto de casilla.
2. **[BUG] Texto de la flecha encimado:** «892 yd / Consigue Mena de estaño de… / ≈ 2 min a pie» se encima con otras ventanas y se corta arriba: que la línea de la meta no se salga ni se corte, y que la flecha no quede detrás de ventanas de Alfa.
3. **Dos pantallas, rehecho a fondo:** Toxic lo probó y no le gustó. Revisar todo el flujo real (estirar la ventana, el mundo y la interfaz en el monitor principal, paneles en el otro) y hacerlo claramente mejor: paneles más grandes y legibles a distancia, diseño de «tablero» con jerarquía (guía y flecha grandes; lo demás secundario), fondo propio (nada de verde liso), que no se vea vacío, que no tape nada del juego, menos pasos para ponerlo y quitarlo, volver al modo normal siempre limpio (escala, posición y bolsas intactas), y vista previa real antes de aplicar.

## 1. Velocidad de verdad (4–6)
4. **Guías por rango de nivel:** cargar solo las guías de tu tramo (Alfa_Guides pesa ~10 MB y 188 ms); el resto a pedido. Meta: entrada y memoria a la mitad.
5. **El Codex por partes:** misiones, objetos y PNJ por separado y a pedido, nunca todo junto.
6. **Precios duplicados:** juntar o limpiar los precios guardados con el reino vacío («?-Alliance», ~742 KB) y poner tope a la historia de precios.

## 2. Cerrar los pendientes de la 1.3 (7–10)
7. **Lista guiada «Confirma en el juego»** (`/alfa confirmar`): las ~30 cosas que los agentes de la 1.3.9 no pudieron confirmar, una por una con botón «Funciona / No funciona» que guarda el resultado para el reporte.
8. **Recetas con datos reales de Forever:** reactivos y colores de todas las recetas desde el juego (al abrir el oficio) y del Codex, para que todas las guías de profesión bajen de costo (Sastrería incluida).
9. **El marcador del otro bando:** el instalador lleva la cuenta de lobos por bando (`AlfaNucleoDB.jauria.bandos`) para ver los dos lados.
10. `docs/PLAN.md` en cero: lo hecho, marcado; lo que quede, pasado a este plan o descartado con su porqué.

## 3. Lo grande de la 1.4 (11–13)
11. **«Tu temporada con la manada»:** tu aventura desde que usas Alfa: niveles, misiones, mazmorras, peces, oro, récords, días jugados y momentos con Lya, en una ventana bonita con tarjetas y una imagen para compartir (texto para Discord, sin datos privados).
12. **Lya 2.0:** más lore por zona y por misión, recuerdos de lo que hicieron juntos («¿te acuerdas de cuando…?»), momentos especiales y frases nuevas en los 10 idiomas.
13. **Página web de Alfa** (`docs/web/`, para GitHub Pages): portada, novedades, manual en línea por idioma, galería y descarga; enlazada desde CurseForge y Discord.

## 4. Calidad que protege (14–16)
14. **`/alfa revisar` en el juego:** recorre las páginas y ventanas reales, y reporta solo lo que falle (errores, textos cortados, marcos fuera de pantalla).
15. **Pasada de valores secretos por todo Alfa:** toda lectura del juego que pueda llegar secreta en combate o mazmorras (velocidad, vida, nombres, posición…) pasa por `N.Leer/N.Si`; el banco lo prueba con `SECRETOS_PRENDER` en cada módulo.
16. **Compatibilidad de la Red:** la 1.4 y la 1.3.x se entienden por La Jauría (versiones de mensaje, nada se rompe con alguien sin actualizar).

## 5. 50 mejoras adicionales (17–66)

### Bolsas y objetos (17–24)
17. Las casillas se ven parejas a cualquier escala: número de montón, nivel de objeto y recarga con tamaño fijo relativo a la casilla, nunca encimados.
18. Ajuste para mostrar u ocultar el nivel de objeto en las casillas (y solo en equipo).
19. «Ordenar» con vista previa de cómo quedará antes de mover nada.
20. La tarjeta de «bolsas llenas» compacta (una línea con «Ver»), sin cortar textos.
21. Recordar las secciones plegadas por personaje.
22. Arrastrar un objeto a una sección para cambiarlo de categoría.
23. Contador de espacio libre por tipo de bolsa (munición, hierbas, etc.).
24. Comparar con lo equipado al pasar el ratón por una pieza de equipo (mejor / peor en una línea).

### Misiones y guías (25–32)
25. Rastreador: barra de avance de la guía con el % y el tiempo estimado restante.
26. «Saltar a mi nivel»: si la guía va atrasada respecto a tu nivel, ofrecer ir a la parte que te toca.
27. Misiones de cadena: aviso antes de abandonar una que abre una cadena valiosa.
28. Las guías dicen qué recompensa elegir para tu clase en cada misión.
29. Paso de entrega con el PNJ marcado en el minimapa al llegar.
30. «Cerrar mis misiones»: opción de incluir la vuelta a la ciudad para entrenar y vender.
31. Guías de profesión: botón «Comprar lo que falta» que arma la lista de subasta.
32. Historial de guías terminadas con fecha y tiempo.

### Mapa, flecha y viaje (33–39)
33. Flecha: tamaño y posición por personaje; recuerda si la escondiste.
34. La flecha avisa con un sonido suave al llegar (opcional).
35. Mapa de Alfa: capa de entrenadores de tu clase y profesiones.
36. Mapa de Alfa: capa de vendedores de comida, agua y reparación cercanos.
37. Tarjeta de viaje: horarios medidos compartidos por La Jauría para que todos tengan la cuenta real.
38. Rutas de vuelo: el mapa marca los puntos de vuelo que te faltan descubrir.
39. «Llévame» a cualquier PNJ o lugar escribiendo su nombre (`/alfa ir <nombre>`).

### Combate, curación y mazmorras (40–45)
40. Curación: perfiles de marcos por tamaño de grupo (solo, grupo, banda).
41. Curación: aviso de quién no tiene tu buff, en un ícono discreto.
42. Combate: el medidor recuerda su posición y tamaño por personaje.
43. Mazmorras: «¿Qué cae aquí para mí?» con lo que te sirve de cada jefe.
44. Mazmorras: el plano por dentro con los jefes marcados donde Alfa los conoce.
45. Tras una muerte, «Vuelve a tu cuerpo» con la flecha y el tiempo estimado.

### Oficios, comercio y pesca (46–51)
46. Comercio: aviso cuando un objeto que buscas aparece barato en la subasta mientras la tienes abierta.
47. Comercio: historial de tus ventas y compras de la semana.
48. Recolección: estadística por sesión (nodos, oro estimado por hora).
49. Pesca: meta del día («pesca 3 peces nuevos») con festejo de Lya.
50. Pesca: el cebo se reaplica con un recordatorio al acabarse.
51. Oficios: aviso cuando una receta pasa a verde (deja de dar puntos seguros).

### La Jauría y social (52–56)
52. Tarjeta de bienvenida para quien entra a la hermandad con Alfa.
53. Eventos de la hermandad en Hoy (citas próximas) con «Me apunto».
54. Ver la guía que sigue un lobo y «Seguir la misma».
55. Logros de La Jauría por semana (más peces, más misiones, más ayuda).
56. Silenciar a un lobo concreto en los avisos de la manada.

### Interfaz, Hoy y avisos (57–66)
57. Hoy: tarjeta «Tu sesión» (tiempo, XP/hora, oro ganado) siempre al día.
58. Atajos de teclado visibles en los botones (tooltip con la tecla).
59. Tema claro/oscuro consistente en todas las ventanas, revisado en los 3 estilos.
60. Búsqueda global de Alfa mejorada: entiende sinónimos y abre directo el ajuste.
61. Todas las ventanas de Alfa se pueden cerrar con Esc (salvo las que no deben).
62. Escala de Alfa independiente de la del juego, que se recuerda y no se pierde al restablecer.
63. Avisos: historial en la campanita agrupado por módulo y por día.
64. Lya: modo «solo lo importante» de un clic.
65. Bienvenida: recorrido de lo nuevo de la 1.4 al entrar la primera vez.
66. Accesibilidad: letra grande y alto contraste revisados en cada página nueva.
67. **Temática por bando que se note** (pedido de Toxic): paleta del bando en acentos, botones, pestañas, barras y tarjetas; cabeceras con estandarte y textura propia (madera y hierro / piedra y plata); fondo sutil y saludo del bando en Hoy y la ventana principal; anuncios, viaje, rastreador y Lya con su color; vista previa de los dos bandos al elegir.

## 6. Lo que Toxic vio en el juego (68–76)
68. **[BUG] La interfaz quedó más grande tras Dos pantallas** (la lista de Amigos del juego, el chat y las barras con letra grande): restaurar exacto el modo de ventana y la escala, y «Reparar mi pantalla» (`/alfa pantallas reparar`). Capturas `scratchpad/bug-escala-amigos-140.webp` y `images/12.webp`.
69. **Tarjeta de viaje más chica y cerrable** (`scratchpad/bug-viaje-140.webp`): el ícono del medallón no se entiende (dibujo claro del transporte: barco, zepelín, grifo/murciélago, tranvía, portal); se cierra con una X y con clic derecho; se va sola al llegar o al subir al transporte cuando ya no aporta; el aro no parpadea; una versión compacta de una o dos líneas que no abrume (lo detallado al pasar el ratón).
70. **La franja de color de los títulos** (rastreador y tarjetas): hoy está corta y mal alineada; que sea una banda completa con el título y los datos adentro, todo alineado.
71. **Reporte de errores:** quitar del formulario el apartado de «datos técnicos (los llena Alfa)» que ve el jugador y agregar un campo para subir capturas de pantalla (opcional), para corregir los bugs con base en ese archivo.
72. **[BUG] Mapa saturado de marcadores** (`scratchpad/bug-mapa-marcadores-140.webp`): decenas de calaveras de élite y signos en un mismo lugar; agrupar los cercanos en uno con su número, mostrar menos por zoom, prioridad a lo relevante para tu nivel y tu ruta, y que el marcador del mapa no parpadee.
73. **Ruta de recolección de verdad** (suma importancia): al buscar un material (mena de estaño, plata…) armar la ruta más óptima en la zona más cercana que sea de tu nivel, con un circuito corto entre nodos reales, no a 2,000 yardas; revisar en el juego con el caso de Toxic (estaño en Pantano del Ocaso/Humedales a nivel 33).
74. **Depuración y estructura del código** (Toxic: «por tantas funciones está tronando y saliendo muchos errores tontos»): revisión completa de todo Alfa por módulo: funciones duplicadas, estados sin limpiar, relojes que no se detienen, ganchos repetidos, nil sin revisar, secretos; unificar patrones (un solo helper por cosa en el Núcleo), quitar código muerto y documentar la arquitectura al día. Cero cambios de comportamiento sin prueba.
75. **Prueba del flujo normal completo** en el banco (un día de juego simulado: entrar, misiones, viaje, mazmorra, muerte, bolsas, recolección, pesca, salir) con secretos prendidos, que falle con cualquier error.
76. Revisar todo el texto de la flecha, el rastreador y las tarjetas en 1920×1080 con escala automática y con escala grande, para que nada se encime ni se salga.

## Pasados de PLAN.md (10, puesto en cero el 24/11)
- P1. **Centro de guías del motor:** Talentos, Raros, Personajes e Importar con `UI.HubKit` y su acomodo interior; documentar `UI.HubKit` en `docs/INTERFAZ.md`.
- P2. **Recolección en el mapa de Alfa:** registrar las capas `recoleccion.<tipo>` con `AlfaMundo.RegistrarCapa` (hoy solo se pintan en los mapas de zona).
- P3. **Nombres de hechizos dudosos** en las traducciones: revisión de alguien nativo (pide gente de la comunidad).
(Los de velocidad y precios ya son los n.º 4, 5 y 6; los de «confirmar en el juego» van en `/alfa confirmar`, n.º 7.)

## 7. El brinco de la 1.4.0 (77–86)
Toxic probó la 1.4.0: «la veo bien pero se siente casi igual». Pide un paquete que se note de verdad. Captura del juego: `scratchpad/juego-140-forjaz.webp`.
77. **Anuncios rehechos de verdad:** siempre centrados en la pantalla (uno salió junto al mapa); los de pueblo, zona, subzona, lugar nuevo, posada, nivel, barco, raro, mazmorra, etc. con una presentación nueva y claramente distinta a la de antes y a la del juego; legibles, cortos, cinematográficos y sin estorbar.
78. **Todo lo visual se puede mover:** cada cosa que Alfa pone en pantalla (flecha, placas de llegada/piedra/viaje, rastreador, Lya, anuncios, avisos, medidor, curación, pesca, barra de bolsas, botones flotantes, etc.) se acomoda arrastrando, con un modo «Acomodar» de toda la pantalla (rejilla con imán, guías, «Volver a su lugar» por elemento y para todo) y recordado por personaje o cuenta.
79. **La placa de «Usa tu piedra de hogar» y las placas de la flecha:** movibles por separado y sin textos cortados («te ahorras 2 min…»).
80. **Rastreador renovado:** el globo de ayuda no se encima con la cabecera; textos completos; aspecto más limpio y moderno.
81. **Avisos (tarjetas) con nuevo estilo** y un solo lugar coherente en pantalla, también movible.
82. **La ventana de Alfa y Hoy con un salto visual:** portada nueva, transiciones suaves entre páginas, jerarquía clara, tarjetas con más aire, coherente con la temática por bando.
83. **Cacería de bugs y fricciones** en todos los módulos con capturas del banco a 1920×1080 (textos cortados o encimados, cosas que se quedan pegadas, botones que no hacen nada, mensajes confusos).
84. **Lo nuevo se nota al entrar:** la primera vez en la 1.4.0, una bienvenida breve que enseña lo nuevo (anuncios, mover todo, temática, temporada) con «Pruébalo».
85. Revisar que nada de lo nuevo quede detrás de otras ventanas o fuera de pantalla en 1920×1080 y 2560×1440, escala automática y grande.
86. Galería y capturas de la 1.4.0 al día (para CurseForge) con fondo nocturno.

## 8. Últimos retoques antes de publicar (87–)
Toxic: «ya casi está: mejora los anuncios de lugares, sitios, raros y demás, arregla los bugs reportados (parpadeo de la tarjeta de barco y de vuelo, el fondo oscuro de los anuncios con capas, el audio que no regresa) y agrega entre 20 y 50 cosas relevantes».
87. Anuncios de lugares, sitios, raros y demás con información útil y fondo parejo (agente anuncios).
88. Tarjeta de barco y de vuelo sin parpadeo (agente revisión).
89. Audio que no regresa y `/alfa sonido` (agente bugs).
90–. Paquete de mejoras relevantes elegidas por los agentes `diario` y `pulido` (cada una con su número en su informe).

