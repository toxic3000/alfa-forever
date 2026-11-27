# Plan 1.4.3: 100 mejoras propuestas (27/11/2026)

Propuesta, no compromiso: Toxic elige. Antes de hacer una, revisar en el código que no exista ya (docs/PLAN.md se atrasó otras veces). Prioridad: **A** = vital, **B** = muy útil, **C** = pulido.

## 1. Firmeza: que lo de la 1.4.2 funcione en el juego real (A)
1. `/alfa confirmar` con una lista guiada de lo nuevo de la 1.4.2 que el banco no puede probar (medidor oficial, revivir, «Alfa: llévame» en el registro, «Comprar» de Siempre a la mano, flechas del chat).
2. Si `ERR_FRIEND_ONLINE_SS` no existe o cambia en Forever, que «Quién se conecta» caiga a la línea del juego sin romperse, y lo anote en `/alfa errores`.
3. Siempre a la mano: confirmar que `BuyMerchantItem` compra la pila correcta (por unidad o por paquete) y nunca compra de más; tope de oro por visita.
4. Subastas: confirmar si `buyoutAmount` es por unidad o total y quitar la adivinanza.
5. «¿Qué me tumbó?»: si el medidor oficial no trae `isDeadly`, armar el golpe final con lo último que sí trae.
6. Revivir: que el botón no salga para quien ya soltó su espíritu, si la macro no le llega.
7. Reaparición de nodos: medir en el juego y ajustar los 8 minutos por tipo de nodo.
8. Un «modo seguro» (`/alfa seguro`) que apague todo lo nuevo de la última versión de un clic, por si algo estorba en una banda.
9. Reporte del Lobo Malo con el número de versión y la lista de ajustes cambiados de fábrica, para reproducir más rápido.
10. Revisión de Yuki y Discord: cada reporte abierto pasa al banco antes de cerrar la 1.4.3.
10b. **Ya encontrado (27/11):** «Lo que te tumbó» (`Alfa_Combate/Caida.lua`, `Ca.Texto`) se corta en el aviso con 3 golpes y un nombre de enemigo largo (el banco lo marca CORTADO): menos líneas o una frase final más corta.

## 2. Rendimiento y carga (A)
11. Bajar la entrada al juego de ~58 ms a 45 ms: diferir los textos de las guías por idioma.
12. Juntar los precios del reino vacío («?-Alliance») cuando el reino se sepa; podar `AlfaNucleoDB` (hoy 1.7 MB).
13. Limpieza automática de datos viejos (compañeros, subastas, capturas) con fecha y límite por personaje.
14. `/alfa rendimiento` con un «semáforo» por módulo y un botón «apagar este módulo».
15. Medir la memoria de cada módulo nuevo de la 1.4.2 en `tools/perfil.py` y fijar un techo en `prueba.py`.
16. Que nada de lo social (conexiones, vigilar) corra en banda o en combate grande.
17. Un solo escuchador de `CHAT_MSG_SYSTEM` para todo Alfa en lugar de uno por módulo.
18. Cargar Comercio (subastas, reventa) solo al abrir la subasta o un comerciante.
19. Pesca y Recolección: dormir del todo si el personaje no tiene el oficio.
20. Prueba de carga en el banco: 40 jugadores en banda con todo prendido, que no pase de un tope de ms por cuadro.

## 3. Primeros pasos y quien empieza (A)
21. Bienvenida 1.4.3: «Lo nuevo para ti» según tu clase y tus oficios, no la lista completa.
22. Un recorrido corto de 60 segundos de lo esencial (flecha, Hoy, Lya, M) para personajes de nivel 1.
23. Perfil «Solo lo básico» de un clic para quien se abruma: flecha, misiones y bolsas.
24. Cada aviso nuevo, la primera vez, con un «¿Qué es esto?» que abre la ayuda de Lya.
25. Botón «Deshacer» en el último cambio de ajustes durante 10 s.
26. Un «Alfa en 5 palabras» en cada página: qué hace y para quién.
27. Ajustes sugeridos al llegar a nivel 10, 20, 40 y 60 (montura, mazmorras, banda).
28. Detectar si el jugador usa otro addon que hace lo mismo y ofrecer apagar la parte de Alfa (sin tocar el otro).
29. Importar un perfil desde un código corto que comparta La Jauría por Discord.
30. Que el manual en PDF tenga un índice «Si quieres… ve a…» por objetivo, no por módulo.

## 4. Misiones, flecha y viaje (A/B)
31. Ruta óptima de un clic con todas las misiones de la zona (recoger, hacer y entregar en un solo recorrido).
32. Aviso de misión de escolta o con tiempo antes de aceptarla.
33. Marcar en el registro qué misiones son «grises» y ofrecer abandonarlas de un clic (con confirmación).
34. Avisar cuando una misión pide un objeto que ya tienes en el banco.
35. Elegir recompensa: comparar con lo que traes puesto y con su precio de venta, y marcar la mejor para tu clase.
36. Flecha: modo «a pie o en montura» que cambia el camino sugerido.
37. Tiempo estimado de llegada en la tarjeta de viaje según tu velocidad real.
38. Avisar antes de salir de la zona si te quedan misiones por entregar ahí.
39. Cadenas: decir cuántas misiones faltan para terminar la cadena y qué da al final.
40. «Llévame a…» con categorías (banco, subasta, maestro de clase, maestro de oficio, buzón, posada) ya armadas por ciudad.

## 5. Combate, curación y mazmorras (B)
41. Resumen de mazmorra al final: tiempo, caídas, intentos por jefe, botín y quién hizo qué.
42. Avisos de mecánicas por jefe con voz de Lya (texto corto), solo en tu papel.
43. Curación: aviso de maná de los sanadores del grupo cuando bajan de 30 %.
44. Recordatorio de buffos de clase faltantes antes de la pelea (solo fuera de combate).
45. Tanques: aviso cuando un enemigo suelto va por un sanador.
46. Medidor: comparar tu pelea con tu mejor contra el mismo jefe.
47. Lista de consumibles recomendados por mazmorra según tu clase.
48. Marcar con calavera/cruz con botones seguros desde la tarjeta del jefe.
49. «Listo para entrar»: revisa durabilidad, bolsas, consumibles y reagentes antes de la mazmorra.
50. Historial por mazmorra: cuántas veces, mejor tiempo y botín conseguido.

## 6. Economía: comercio, bolsas, oficios, recolección y pesca (B)
51. Vender grises y reparar con un solo botón en el comerciante, con resumen de lo ganado.
52. Bolsas: agrupar por «para misión», «para oficio», «para vender» y «para equipar».
53. Banco de todos tus personajes buscable desde cualquier personaje.
54. Lista de compras de un oficio armada sola hasta el siguiente nivel de la receta.
55. Aviso cuando una receta que buscas sale en la subasta o en un comerciante.
56. Precio sugerido de subasta con tendencia (sube/baja) con tus propias lecturas.
57. Correo: mandar materiales a tu personaje con el oficio en un clic.
58. Recolección: ruta circular por zona con los nodos de tu nivel y tiempo estimado.
59. Pesca: aviso de horario y lugar de los peces de evento o temporada.
60. Oro por hora de tu sesión (cacería, recolección, pesca) en Hoy.

## 7. Tu gente y La Jauría (B)
61. Calendario de La Jauría: citas con recordatorio 15 min antes (sobre `Cita.lua`).
62. Buscar grupo dentro de La Jauría para una mazmorra con papel y nivel.
63. Tablón de pedidos de oficio: «¿quién me hace esto?» con quien tiene la receta.
64. Insignias nuevas por logros de la manada (primer jefe juntos, 100 misiones en grupo).
65. Mentor: emparejar a quien empieza con alguien de nivel alto que quiera ayudar.
66. Lista de ignorados compartida opcional (solo nombres, nunca nada automático).
67. «Con quién cazaste»: notas propias por persona y estrellas.
68. Aviso suave cuando un compañero de grupo se queda atrás o muere lejos.
69. Saludo de cumpleaños de personaje (aniversario del primer día con Alfa).
70. Página de La Jauría con lo que pasó en la semana (raros, jefes, niveles).

## 8. Lya y Hoy (B)
71. Lya recuerda lo que te dijo y no repite el mismo dato en la misma semana.
72. Lya comenta tu ficha («ya casi tienes tu montura»).
73. Hoy: «Tu plan de 30 minutos» con lo que más te conviene hacer ahora.
74. Hoy: progreso hacia la montura y su costo con lo que te falta.
75. Lya en mazmorras: un consejo por jefe, nunca en combate.
76. Lya con estados de ánimo visibles según tu día (cansada de noche real, contenta al subir).
77. Logros personales de Alfa (sin logros del juego) con su página.
78. Historia de tu personaje exportable como texto para Discord.
79. Lya avisa del descanso acumulado y sugiere posada cercana.
80. Ajuste de «cuánto habla Lya» con tres niveles claros.

## 9. Interfaz, accesibilidad e idiomas (A/B)
81. Escala de interfaz por ventana (no solo global).
82. Modo alto contraste además de daltónico.
83. Leer los avisos importantes en voz alta con la voz del juego (texto a voz), opcional.
84. Revisión de traducciones por gente nativa de la comunidad (pendiente desde la 1.4.0).
85. Atajos de teclado configurables para cada ventana de Alfa.
86. Búsqueda en todo Alfa que también encuentre comandos y teclas.
87. Revisar que ningún texto nuevo de la 1.4.2 se corte en alemán o ruso (los más largos).
88. Mover y guardar posición de toda ventana nueva de la 1.4.2 con `K.Movible`.
89. Unificar el estilo de las ventanas nuevas («Con quién cazaste», «Qué pica aquí») con el Kit.
90. Documentar `UI.HubKit` en `docs/INTERFAZ.md` (pendiente desde la 1.4.0).

## 10. Legal, seguridad, herramientas y calidad (A)
91. `tools/legal.py`: buscar en el código nombres de otros addons y URLs de sitios de datos (Wowhead, etc.) y fallar si aparecen fuera de la compatibilidad declarada.
92. Huella de los archivos de terceros (MIT/GPL) para saber si alguien los cambió sin dejar el aviso.
93. Página pública «Créditos y licencias» en GitHub igual a la del juego.
94. Revisar que ningún dato del Codex venga de una web; dejar la fuente de cada tabla en `LICENSE-DATA.txt`.
95. `tools/prueba.py` en paralelo para que la prueba completa tarde la mitad.
96. Cada prueba nueva confirma que falla con el código viejo (automático con `git stash`).
97. Pruebas de las 10 lenguas en las escenas visuales clave (no solo español).
98. Revisión automática de que ninguna función nueva use APIs restringidas (`HasRestrictions`) fuera de un clic.
99. Registro de cambios por ajuste: que la página de cada ajuste diga en qué versión llegó.
100. Respaldo automático de `AlfaDB` antes de cada migración, con «volver» de un clic.
