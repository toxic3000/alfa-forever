# Alfa y lo legal (revisión del 27/11/2026, versión 1.4.2)

Pedido de Toxic: «no quiero que nos pase lo de Mastercraft (lo retiraron porque Wowhead le pidió quitar los datos que había tomado de su sitio); hay que blindarnos: si algo de otro addon nos puede meter en problemas, quitarlo; todo nuestro código, limpio y propio».

## En corto

- **Alfa cumple.** Todo lo de terceros que usa está permitido por su licencia, lleva su crédito en «Acerca de» > Créditos y licencias, y su aviso de licencia viaja dentro de su carpeta. `tools/prueba.py` falla si un aviso deja de viajar (`tools/legal.py`).
- **Lo propio es propio.** Los módulos de `src/` y la interfaz de `motor/` son código de Alfa. Los nombres de otros addons que aparecen en el código son solo para **detectarlos** y no chocar con ellos (Diagnóstico, «usar la flecha de TomTom», «otro medidor»): eso no es copiar.
- **Nada de datos de sitios web** de terceros en lo que hace Alfa (ni Wowhead ni otros). Lo que Alfa sabe sale del juego, del motor (con sus fuentes acreditadas) o de lo que el jugador ve.

## Lo de terceros, uno por uno

| Qué | De quién / licencia | Qué usa Alfa | Riesgo | Qué hacer |
|---|---|---|---|---|
| **Polestar** (el motor) | The Polestar authors, **GPL-3.0** | El motor de guías, flecha, navegación y datos, renombrado y parcheado (`tools/parches.py`). | Ninguno mientras cumplamos la GPL: Alfa es GPL-3.0, da crédito y su código es público en GitHub. | Mantener: la GPL **obliga** a dar el crédito, no es opcional. No se puede «quitar» sin rehacer el motor. |
| Datos de misiones/PNJ/objetos que trae Polestar (QuestieDB, pfQuest, CMaNGOS, VMaNGOS, ForeverTDB, Factoruide, EG Link, tablas del cliente) | Ver cada `LICENSE-DATA.txt` | Solo **hechos** (ids, niveles, posiciones), nunca textos ni imágenes. | Bajo. QuestieDB no tiene licencia de datos publicada, pero Polestar los usa **con el acuerdo de sus mantenedores** y con crédito, y los quita si lo piden (`forge data build --no-questie`). | Si los mantenedores de Questie pidieran quitarlos: pasar a los paquetes de datos de un Polestar más nuevo (su base abierta `forever-db`, GPL-3.0 + CC BY 4.0) o reconstruir sin ellos. Ver «Si alguien pide algo». |
| **Shortest Path Forever** | Cillian Berragan, GPL-3.0-or-later (con su permiso a Polestar) | La navegación (vía el motor). | Ninguno. | Mantener el crédito. |
| **pfQuest** | shagu, MIT | Datos de misiones/PNJ/objetos (vía el motor). | Ninguno. | Mantener el crédito. |
| **GatherLite** | Wuild, MIT | La base de nodos de recolección (`Alfa_Recoleccion`, `LICENSE-GatherLite.txt`). | Ninguno (MIT: copiar y modificar con el aviso). | Mantener el aviso. |
| **OpenMap** | OpenMap contributors, MIT | Ideas y lógica del mapa continuo, reescritas con código propio; las máscaras de territorio y de ciudades (`vendor/Alfa_Mundo`, `LICENSE-OpenMap.txt`). | Muy bajo. Las máscaras son formas trazadas (sin color) sobre mapas de Blizzard; el arte del mapa es de Blizzard y Alfa no lo copia (lo pinta el cliente). | Mantener. Si alguna vez se quisiera cero dudas: Mundo funciona sin las máscaras (usa el arte del juego), solo pierde detalle fino. |
| **TerrainWorldMap** | Dramacydal, MIT | La tabla de mosaicos del terreno (números, no imágenes). | Ninguno. | Mantener el aviso. |
| Letras Inter, Fira Sans, Open Sans | SIL OFL 1.1 | Las letras de Alfa. | Ninguno. | Mantener sus `*-OFL.txt`. |
| ForeverLevelingBiS | Thunder, MIT | Datos de equipo (vía el motor). | Ninguno. | Mantener el crédito. |
| Arte de Blizzard | Blizzard | Íconos del juego **por su ruta** (`Interface\Icons\...`): los dibuja el cliente del jugador; Alfa no los copia. | Ninguno (así funcionan todos los addons). | No extraer ni empaquetar arte del juego. |
| Mastercraft | — | **Nada.** La ficha de la 1.4.2 tomó solo la idea de juntar todo de un personaje en una vista; diseño, código y datos son de Alfa. | Ninguno. | Sin crédito: no se copió nada (y nombrarlo no conviene mientras su autor resuelve lo suyo). |

## Reglas para lo que venga

1. **Ideas sí, copias no.** Se puede tomar la idea de una función de otro addon; el código, el arte y los textos se hacen desde cero.
2. **Código ajeno solo con licencia libre** (MIT, BSD, GPL compatible) y **siempre** con su aviso en la carpeta y su línea en Créditos. Nada de addons «todos los derechos reservados» ni sin licencia.
3. **Ningún dato sacado de sitios web** (Wowhead y similares), aunque sea público. Solo el juego, el motor y fuentes con licencia.
4. **Nada de arte del juego empaquetado**: los íconos y mapas se piden al cliente por su ruta.
5. Los nombres de otros addons solo para detectarlos y convivir con ellos.
6. Antes de publicar: `python -I tools/prueba.py` revisa que cada aviso de licencia siga en el paquete (`tools/legal.py`).

## Si alguien pide algo

Contestar con calma y rápido, y quitar lo que pidan aunque creamos tener razón: no vale la pena el pleito.
- **Questie** pide sus datos fuera: pasar a los datos de un Polestar más nuevo o reconstruidos sin Questie; mientras tanto, avisar en Discord.
- **OpenMap** u otro autor pide su crédito de otra forma o retirar algo: hacerlo en la siguiente versión.
- **Blizzard**: Alfa sigue sus reglas de addons (`docs/REGLAS-BLIZZARD.md`): nada de donaciones ni anuncios dentro del juego, nada automático que juegue por ti.
