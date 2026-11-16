# Alfa 1.0: la versión buena

Toxic probó la 0.5 (la versión 0.1.0 del 16/11/2026) y no salió ningún error. Su veredicto: **todavía se ve demasiado al addon en el que nos basamos**. Las listas de zonas y mazmorras, la sección de talentos (con el mismo mensaje), la ventana de guía y varios elementos de muchas pestañas se ven "casi iguales". Además hay cosas mal centradas, espacio desaprovechado, alineación pobre y pantallas revueltas.

Los addons antiguos son nuestra base, pero **vamos más allá**: Alfa 1.0 debe tener una interfaz **propia, distinta y mejor**, más ordenada, más visual y que **guíe**. Con un par de clics eliges qué hacer y Alfa arma la ruta; quien quiera detalle entra a Ajustes.

## Reglas para 1.0

1. **Nada de la interfaz del addon base a la vista**, salvo los menús de Ajustes. A esos les cambiamos un poco el tema y los íconos. Las ventanas de funciones (guía, elegir guía, buscador, mazmorras, talentos, raros, personajes, bienvenida, tarjetas de entrenamiento y avisos) se rehacen como **ventanas propias** con el **Kit de Alfa**. Las del motor se dejan de mostrar. El motor sigue trabajando por dentro (guías, pasos, navegación y datos) y solo se usa a través de sus funciones.
2. **Kit de Alfa:** componentes propios escritos desde cero (no derivados de `Widgets.lua`) en `src/Alfa_Nucleo/Kit/`. Plantillas de página fijas (encabezado, secciones, rejillas de tarjetas, listas) con márgenes, alineación y ritmo consistentes. Todas las páginas de los módulos se pasan al Kit.
3. **Diseño:** se mantiene el diseño A (grafito, verde #8be04e, color de clase como segundo acento y esquinas cortadas), pero con **identidad renovada**: íconos propios para cada sección y función, el lobo como personaje (estados, huellas como progreso) y nada de estrellas, rieles ni barras laterales.
4. **Guiar:** cada pantalla dice qué hacer después. Primero va la acción recomendada en grande y luego las alternativas. Nada de muros de opciones.

## Qué tiene 1.0

| Área | Qué es |
|---|---|
| **Hoy** | Portada: "¿Qué hacemos hoy?" con 4 caminos grandes (Subir de nivel, Hacer oro, Profesiones y Mazmorra con la manada). Al elegir uno, Alfa propone una ruta y con **Seguir** arranca. También van tu paso actual, tus alertas y la tarjeta de tu clase. |
| **Ruta y guía** | Reemplaza el selector de guías y la ventana de guía. Muestra la guía recomendada para tu nivel y zona en grande y las demás en tarjetas visuales. El **rastreador de pasos** es propio, compacto, con huellas como progreso y la flecha. Las rutas propias (árbol XP/oro/profesión) y "liberar misiones" viven aquí. |
| **Talentos** | Builds pasa a ser el lugar de los talentos (también en la sección del motor que se llamaba Talentos). Dice qué talento poner ahora y por qué, con un clic para aplicarlo, más el árbol, el estilo y el objetivo. |
| **Enciclopedia** | Nueva. Wiki de **todos** los objetos del juego (aunque no los tengas): buscar, filtrar y una ficha con fuentes (quién lo suelta y con qué probabilidad, dónde, vendedores con ubicación y precio, misiones, recetas, pesca y contenedores), ubicación en el mapa y "Guíame". También PNJ, misiones, zonas y raros. Reemplaza al buscador del motor y al catálogo de Rutas. |
| **Mazmorras** | Una sola: la nuestra (botín por jefe, consejos y modo historia) más las funciones del motor (misiones de cada mazmorra, recoger y entregar, entrada). |
| **Curación** | Más visible y guiada para sanadores (sacerdote, druida, paladín y chamán): asistente de 3 pasos (elige preajuste, acomoda marcos, prueba) y acceso desde Hoy. |
| **La Jauría** | **Sin lista de la hermandad.** Solo tu grupo y la gente que **tiene Alfa y aceptó compartir**. Al instalar Alfa sale una ventana que pregunta si quieres compartir tu ubicación con la manada (quienes usan Alfa). No se puede saber desde el juego quién está en el Discord. |
| **Resto de módulos** | Bolsas, Comercio, Pesca, Recolección, Mundo, Comodidades y Mazmorras pasan al Kit: ordenados, centrados, alineados y sin espacio perdido. |

## Versión

La 0.1.0 instalada es la que Toxic llama "0.5". La siguiente versión buena será la **1.0.0**. Se interpretó así su "0.1, ya la buena": un número menor confundiría el aviso de versión nueva entre jugadores.
