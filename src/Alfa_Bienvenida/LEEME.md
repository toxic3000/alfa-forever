# Alfa - Bienvenida

El primer arranque de Alfa 1.0, las novedades y el aullido. Todo es código propio de Alfa.

- **Reemplaza la bienvenida y las novedades del motor** (`SHOW_WELCOME` y `SHOW_WHATSNEW`): las dos abren la misma ventana del Kit.
- **Portada:** arriba la acción grande ("Empezar", o "Todo listo" con tus respuestas) y abajo lo nuevo de la 1.0 (`Novedades.lua`, que debe decir lo mismo que la sección 1.0.0 de `CHANGELOG.md`).
- **Asistente** (`K.Asistente`), en este orden:
  1. el estilo: Alfa, Clásico WoW o Cristal (y en Cristal, el color de acento);
  2. las misiones automáticas: solo las de tu ruta (recomendado) o todas, el ajuste `ruta.soloRuta` de Ruta y misiones;
  3. compartir tu ubicación con La Jauría: lo pregunta `AlfaManada.PreguntarCompartir()` al llegar al paso (sin La Jauría, el paso no sale);
  4. el aullido.
  Cada respuesta se guarda al elegirla. "Listo" cierra con un aviso y el aullido.
- **Cuándo sale sola:** una vez por cuenta, también a quien ya vio la bienvenida de antes. Unos segundos después de entrar, fuera de combate, de instancias, de cinemáticas y de la elección de camino. Mostrarla la marca vista (`AlfaNucleoDB.bienvenida.visto`), así que un `/reload` no la repite. Subir `M.VERSION` en `Bienvenida.lua` la vuelve a mostrar una vez a todos.
- **Página Ajustes > Estilo y sonido:** tu estilo con "Repetir el asistente", los tres estilos en un clic, el acento de Cristal, el aullido y la bienvenida.

## El aullido

La primera vez que abres la ventana de Alfa en cada sesión suena un lobo **del propio juego** (canal de efectos, así que respeta tu volumen y si tienes los efectos apagados). Un `/reload` no lo repite; volver a entrar sí.

Sonidos, por FileDataID, en este orden (si el cliente no tiene uno, prueba el siguiente):

| FileDataID | Archivo del juego | Qué es |
|---|---|---|
| 569109 | `Sound/SPELLS/FuriousHowl1.ogg` | Aullido furioso, la habilidad del lobo del cazador (desde la 1.x) |
| 564211 | `Sound/CREATURE/Wolf/WolfStandVar4.ogg` | El lobo de siempre, quieto, aullando (desde la 1.x) |

De dónde salen: el listado de archivos de la comunidad, [wowdev/wow-listfile](https://github.com/wowdev/wow-listfile) (`parts/sound.csv`, versión 202611141741). Los dos son archivos del juego original (1.x), así que el cliente clásico los trae; el motor ya toca sonidos del juego por FileDataID del mismo rango (las campanas de barco y zepelín, 566652 y 566719). Alfa no reparte ningún sonido propio.

## Comandos

- `/alfa bienvenida`: abre la portada. `/alfa bienvenida asistente`: abre las preguntas.
- `/alfa estilo`: abre Ajustes > Estilo y sonido.
- `/alfa welcome` y Acerca de > "Mostrar la bienvenida otra vez" (del motor) abren la portada.

## Ajustes y datos

| Dónde | Qué |
|---|---|
| `AlfaDB.settings.bienvenida.aullido` | El aullido al abrir Alfa (sí por omisión) |
| `AlfaDB.settings.ui.skin` | El estilo: `alfa`, `classic` (Clásico WoW) o `cristal` |
| `AlfaDB.settings.ruta.soloRuta` | Misiones automáticas solo de la ruta (lo usa Ruta y misiones) |
| `AlfaNucleoDB.bienvenida` | `visto` (la versión del asistente que ya salió), `respondio`, `cuando` |
| `AlfaNucleoCharDB.bienvenida.aulloSesion` | Ya aulló en esta sesión |
| `AlfaNucleoDB.kit.acentos` | El acento propio que recuerda cada estilo |

## Contrato

`AlfaBienvenida.Abrir(vista)` (`"portada"` o `"asistente"`), `AlfaBienvenida.Aullar()` y `AlfaBienvenida.Visto()`.

## Para verificar en el juego

1. Con una cuenta que ya tenía Alfa 0.1.0: al entrar, a los pocos segundos sale la bienvenida de la 1.0 una sola vez; ni la bienvenida ni las novedades viejas del motor aparecen. Tras `/reload` no vuelve.
2. "Empezar": los tres estilos cambian todo al instante (ventana de Alfa, esta ventana, la flecha). En Cristal aparecen los acentos; elegir uno cambia el color en el momento.
3. Paso de misiones: elegir una opción la marca. Con La Jauría instalada, al llegar a su paso sale su pregunta; la tarjeta muestra lo que respondiste.
4. Paso del aullido: "Sí" suena el aullido; "Escuchar el aullido" también. Confirma que se oye un lobo (si suena otra cosa o nada, cambia `M.SONIDOS`).
5. Cierra el juego, entra de nuevo y abre Alfa: aúlla una vez. Ábrelo otra vez: no. Con el aullido apagado: nada.
6. Entra en combate antes de que salga la bienvenida: espera a que termine el combate.
