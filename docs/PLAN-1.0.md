# Alfa 1.0: la versión buena

Toxic probó la 0.5 (versión 0.1.0, 16/11/2026) y no tuvo errores. Su veredicto: **sigue viéndose como el addon base** (listas de zonas y mazmorras, Talentos con el mismo mensaje, ventana de guía). Además hay cosas mal centradas y mal alineadas, espacio desaprovechado y la app se siente **confusa**: «parece que solo juntaste todo sin depurar qué tomar de cada cosa». Lo que pide:

> Toma los addons antiguos **como ejemplo**, no como código fuente: decide qué vale la pena de cada uno y créalo **nuevo, diferente y mejor**. Más ordenado, más visual, que **guíe** y que con un par de clics elijas tu camino. Quien quiera detalle se mete a Ajustes. Es un addon para mucha gente.

## Principios (todos los agentes)

1. **Depurar antes de construir.** Por cada área, decide qué hace falta de verdad y quita lo que confunde. Cada pantalla empieza con **una acción recomendada en grande** y después las alternativas.
2. **Interfaz propia con el Kit** (`src/Alfa_Nucleo/Kit/`, `docs/KIT.md`). Nada de componentes ni acomodos del motor original en las ventanas de funciones. Las ventanas del motor se sustituyen con `AlfaNucleo.Reemplazar(clave, fn)` (tabla en `docs/KIT.md`). Los menús de **Ajustes** se quedan (ya tienen íconos y tema nuevos).
3. **Identidad Alfa / La Jauría:** lobo, huellas, manada. Íconos de `motor/Alfa/Media/UI/ic-*` y `lobo-*`.
4. **Ordenado:** plantillas del Kit (`K.Tablero`, `K.ListaFicha`, `K.Asistente`), rejilla de 8 px, todo alineado y centrado.
5. **Reglas de Forever** (`docs/ARQUITECTURA.md`): nada que decida en combate, valores secretos, acciones protegidas solo con clic y fuera de combate.

## Áreas y responsables

Cada agente trabaja **solo** en sus carpetas o archivos. Lo que necesite de otro lo pide en su reporte. Nadie edita `src/Alfa_Nucleo/Kit/` salvo A2 (estilos). Nadie hace commits. Cada uno construye con su propia carpeta: `ALFA_DIST=dist-<área>`.

| Área | Dueño de | Qué entrega |
|---|---|---|
| **A1 · Ruta y misiones** | `src/Alfa_Rutas/`, nuevo `src/Alfa_Ruta/` si conviene | Asistente "¿Qué quieres hacer?" (Subir de nivel / Profesiones / Hacer oro / Mazmorras). Biblioteca de guías propia (reemplaza `SHOW_PICKER`). **Rastreador de pasos propio** (reemplaza `GUIDE_FRAME`, `GUIDE_END`, `ROUTE_CHOICE`). **"Liberar misiones"** (completar o entregar las abiertas) y **"Recoger misiones"** bien visibles. Rutas por objetivo: solo subir de nivel, solo profesiones. Opción **"aceptar y entregar solo las misiones de mi ruta"** (para no tomar misiones que no sirven a la ruta). Rutas propias (árbol), sin catálogo: el catálogo pasa a la Enciclopedia. |
| **A2 · Primer arranque, estilos y sonido** | `src/Alfa_Nucleo/Kit/` (tokens y estilos), `motor/Alfa/Theme/*`, `motor/Alfa/Media/Nav/` y lo de la flecha, nuevo `src/Alfa_Bienvenida/` | **3 estilos** que se cambian en un clic: *Alfa* (el actual), *Clásico WoW* (bordes y fondos del propio juego) y *Cristal* (transparencias y colores elegibles). **Asistente de primer arranque**: estilo; misiones automáticas solo de la ruta o no; compartir ubicación con La Jauría (lo llama `AlfaManada`); aullido sí o no. **Aullido** al abrir Alfa por primera vez en la sesión (sonido del juego o propio; con ajuste para apagarlo). **Flecha de navegación con temática de lobo** (por ejemplo una cabeza de lobo o una huella que apunta), en los 3 estilos. Reemplaza `SHOW_WELCOME` y `SHOW_WHATSNEW`. |
| **B · Enciclopedia** | nuevo `src/Alfa_Enciclopedia/` | Wiki de **todos** los objetos del juego (también los que no tienes) con búsqueda, filtros y ficha: quién lo suelta y con qué probabilidad y dónde; vendedores con ubicación, precio y reabastecimiento si hay dato; misiones; recetas; pesca; contenedores; mapa; "Guíame" y "Agregar a mi ruta" (contrato con A1). También PNJ, misiones, zonas y raros (reemplaza `SHOW_LOOKUP` y `SHOW_RARES`). |
| **C1 · Talentos** | `src/Alfa_Builds/` | Reemplaza `SHOW_TALENTS` y `CLASS_CARD` / `SPELL_CARDS` (entrenar). Dice **qué talento poner ahora y por qué**, con un clic para aplicarlo. Estilo y objetivo en dos clics. Página ordenada con el Kit. |
| **C2 · Combate** | nuevo `src/Alfa_Combate/` (y saca de Builds lo de combate en coordinación con C1) | **Ayuda de rotación mejorada y no invasiva**: qué presionar y en qué orden según la situación, usando lo permitido (`C_AssistedCombat`, datos propios), discreta, movible y apagable. **Medidor de daño** del grupo o banda con **top 10 de DPS**, con lo que permita Forever (revisar `DamageMeter*` y `C_DamageMeter` en la API; sin registro de combate). Si la API no da datos de otros jugadores, mostrar lo que sí se pueda y decirlo. |
| **D · Mazmorras** | `src/Alfa_Mazmorras/` | Rehacerla **clara**, tomando como ejemplo la experiencia del diario de mazmorras que Toxic usaba (en `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\` ya no está instalado: guíate por `src/Alfa_Mazmorras/LEEME.md` y lo que ya existe). Debe tener la lista por nivel, la página por mazmorra (jefes, botín, misiones, entrada y consejos), el progreso, y recoger y entregar sus misiones. Reemplaza `SHOW_DUNGEON` y `DUNGEON_TOAST`. |
| **E · La Jauría** | `src/Alfa_Manada/` | **Sin lista de hermandad.** Solo tu grupo y quienes **usan Alfa y aceptaron compartir**: un canal oculto propio entre usuarios de Alfa (si la API lo permite; si no, grupo y hermandad solo con Alfa). Expone `AlfaManada.PreguntarCompartir()` para el asistente de A2. Más temática de manada en la página. |
| **F · Hoy, Curación y avisos** | `src/Alfa_Inicio/`, `src/Alfa_Curacion/` | Hoy con el Kit: "¿Qué hacemos hoy?" (abre el asistente de A1), siguiente paso, alertas, la tarjeta de tu clase, y "Liberar" y "Recoger misiones" a un clic. Curación con asistente de 3 pasos. Reemplaza `WHILE_HERE`, `LEVEL_TIP`, `CLASS_TOAST` y `UPDATE_CARD` con avisos del Kit. |
| **G · Bolsas, Comercio** | `src/Alfa_Bolsas/`, `src/Alfa_Comercio/` | Bolsas con **3 vistas**: general, por categorías y **por bolsa**; **ver las casillas de las bolsas** (las bolsas equipadas y cambiarlas). Banco con **depositar rápido** (por ejemplo materiales u objetos de una categoría con un clic) y **comprar más espacio en el banco** (lo que permita la API de Forever). Comercio con el Kit. |
| **H · Mundo, Recolección, Comodidades** | `src/Alfa_Mundo/`, `src/Alfa_Recoleccion/`, `src/Alfa_Comodidades/` | Que el **mapa con zoom de todo el mundo** se use fácil (por ejemplo la tecla M abre el mapa de Alfa, con opción). **Marcadores propios**: poner, nombrar, ícono y color, compartir con el grupo y la flecha hacia ellos. Recolección y Comodidades con el Kit. Comodidades: la opción "todas las misiones" respeta "solo las de mi ruta" de A1 (ajuste `ruta.soloRuta`). |

**Contratos entre áreas** (cada uno los publica como global, si existe):
- `AlfaRuta.Asistente(camino)` para abrir el asistente. `camino` es `"nivel"`, `"profesiones"`, `"oro"` o `"mazmorras"`. También `AlfaRuta.Liberar()`, `AlfaRuta.Recoger()` y `AlfaRuta.AgregarObjeto(itemID)`.
- `AlfaManada.PreguntarCompartir()`.
- `AlfaEnciclopedia.Abrir(tipo, id)`.
- `AlfaBuilds.SiguienteTalento()`, que devuelve `{ nombre, icono, porque }` o nil.

## Versión

La 0.1.0 instalada es la que Toxic llama "0.5". La siguiente será la **1.0.0**.

## Pedidos agregados (16/11, tarde)

- **Nunca mandar a una misión que todavía no puedes tomar.** En la captura de Toxic, la guía lo mandó a "Acepta Lingotes Forjaluz" sin que esa misión estuviera habilitada. Antes de proponer un paso, la ruta comprueba que la misión esté disponible: nivel, misiones previas, facción, clase y profesión. Si no lo está, **arma el plan con lo necesario** (las misiones previas o los requisitos) para llegar al objetivo. Lo mismo vale al elegir un objetivo: si falta contenido, el plan incluye cómo conseguirlo. (A1)
- **Plan para cerrar las misiones que tienes** (Liberar) o elegir una y armar su plan. (A1)
- **Bolsas llenándose:** sugerir qué vender, qué conservar o ir al comerciante, con datos de Comercio (valor, consejo) y Bolsas. (G)
- **Seguir al marcador:** opción de flecha y ruta hacia cualquier marcador del mapa. (H)
- **Nada vacío sin sentido:** si una sección o tarjeta no tiene contenido útil, no se muestra, o muestra qué hacer para llenarla. (Todos)
- **Alfa ya es el addon:** no dependemos de otros addons; todo lo que hace falta está en Alfa.
- **Control de versiones** (ver `docs/VERSIONES.md`): cada versión publicada lleva número, notas y etiqueta en git.
- **Caso real (prioridad):** Toxic tiene de 10 a 15 misiones completas sin entregar y no sabe por dónde empezar. Necesita un botón que arme una **ruta de entregas** con todas, en el orden más corto. También poder **agregar y quitar misiones de un plan** y **crear un plan para cerrar las que tiene** (las completas para entregar, las incompletas para terminar). (A1, con acceso desde Hoy)
- **Sin dependencias:** Alfa no lee datos ni usa funciones de otros addons. Solo detecta si hay otro activo para no chocar con él (tablas `Compat.lua`). Se quitaron el respaldo de precios de otro addon (Comercio), la importación de nodos (Recolección) y la importación de ajustes de pesca.
- **Revisión final ("vuelta de tuerca"):** antes de instalar, revisar todo junto (coherencia, que nada quede vacío, textos, rendimiento) y probar en el banco las pantallas principales.
- **Nombre:** confirmado por Toxic el 16/11: se escribe **Alfa** (como hoy). "Alpha" en sus mensajes es el dictado.
