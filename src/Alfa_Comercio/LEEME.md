# Alfa - Comercio

Responde la pregunta "¿lo vendo al comerciante, lo subasto o lo convierto en algo que valga más?" para cada objeto. Solo informa: nunca compra, vende ni publica nada por ti.

## Qué hace

- **Precios de la subasta, solo de Alfa.** Con la casa de subastas abierta aparece una barra de Alfa (hecha con el Kit) bajo su ventana con el botón **Escanear con Alfa**. El escaneo completo (`C_AuctionHouse.ReplicateItems`) guarda el precio más bajo por unidad de cada objeto, con su fecha, por reino y facción, y un historial de 14 días (un precio por día) para ver si sube o baja. Se lee por lotes, sin congelar el juego. Entre escaneos hay que esperar 15 minutos.
- **Lo que ya buscas.** Cuando buscas algo en la subasta, Alfa también guarda el precio más bajo que ves.
- **Comerciante.** Al abrir un comerciante, anota lo que cuesta comprarle cada cosa (por ejemplo, el hilo), para calcular el costo de las recetas.
- **Recetas.** Al abrir la ventana de una profesión, Alfa lee tus recetas aprendidas (reactivos y producto). Sirven en todos tus personajes del mismo reino y facción ("créalo con Fulano").
- **Desencantar.** Si tú u otro personaje tuyo tiene Encantamiento con nivel suficiente, calcula el valor esperado de los materiales según la calidad y el nivel del objeto.
- **Consejo.** Para cada objeto compara vender, subastar (menos la comisión) y transformar (receta o desencantar). Recomienda lo que más oro deja si gana por lo menos un 10 % a venderlo; si nada da oro, dice que lo guardes.
- **Cuadro del objeto.** Dos líneas al pasar el ratón: `Subasta: 1o 20p (hace 3 h) · Comerciante: 15p` y `Mejor: subastar 1o 14p (+660%)`.
- **Página "Comercio"** (Oficios > Comercio, hecha con el Kit, plantilla Tablero): arriba y en grande, **qué hacer con lo que llevas** (cuánto ganas si sigues los consejos, cuántas cosas vender, subastar, transformar o guardar, y la acción que toca: escanear, *Llévame a la subasta* o *al comerciante*, con la flecha del motor); tus números; lo que llevas, ordenado por lo que más ganas, con insignias de color y filtros (los 10 primeros y "Ver todo"); los precios de la subasta (al día, viejos o sin precios, con su acción); tus recetas que dejan ganancia; cómo decide Alfa y los ajustes.
- **Para Bolsas.** Publica `AlfaComercio.Consejo`, `TextoMejor`, `ValorVenta`, `PrecioSubasta` y `AnalizarBolsas`: Bolsas los usa para sugerir qué vender y qué conservar cuando se llenan.
- **Lista de compras (1.2.9, `Lista.lua`).** Para una receta (las tuyas o las de la guía) o una meta: los materiales, cuántos tienes en bolsas y banco (`AlfaBolsas.Cuantos`), cuántos faltan, cuánto cuesta comprarlos y de dónde sale cada uno (Codex). Se llena sola mientras juntas, con un aviso al completar un material o la lista. Es de cada personaje (`N.DatosPersonaje("comercio").lista`). Para otros módulos: `AlfaComercio.Lista.Agregar(itemID, cantidad)`, `AgregarOficio(línea)`, `Quitar`, `Vaciar`, `Metas`, `Materiales`, `Completa`.
- **Oficios de 1 a 300 (1.2.9, `OficiosDatos.lua`, `Oficios.lua`, `VentanaOficios.lua`).** Una guía por oficio (los 11: Alquimia, Herrería, Encantamiento, Ingeniería, Peletería, Sastrería, Herboristería, Minería, Desuello, Cocina y Primeros auxilios) con los tramos de habilidad, su receta y reactivos, lo que te falta de aquí a 300 y dónde aprender el siguiente rango. Los pasos inciertos son generales (qué hacer y unos materiales), nunca una receta inventada; si ya conoces la receta, se usan los reactivos del juego. En la página, la sección Oficios; la guía en su ventana (`/alfa comercio oficios`).
- **Subastar fácil (1.2.9, `Vender.lua`).** Con un objeto en la pestaña de vender de la subasta, un panel a un lado con el precio sugerido, su historial de 14 días (barras, más bajo, promedio y más alto) y un aviso si tu precio queda muy por debajo. Nunca pone ni cambia el precio.
- **Para Bolsas (1.2.9).** `AlfaComercio.Usan(id)`: quién de tus personajes usa un objeto en sus recetas («Qué guardar»).
- **Sin otros addons.** Alfa usa solo sus propios escaneos y lo que ves al buscar; no lee precios de otros addons.
- **1.3.1.** `AlfaComercio.OlvidarPersonaje(nombre, reino)` (`Recetas.lua`): «Olvidar» en la página de Bolsas borra también las recetas y el Encantamiento de ese personaje (la clave es nombre-reino con espacios; también se reconoce sin ellos) y rehace el índice (`M.RecetasCambiaron`). La lista de compras avisa (`ALFA_COMERCIO`, `ALFA_COMERCIO_LISTA`) solo cuando cambia lo que está listo, no con cada cambio de tus bolsas. «Tomar todo» del buzón da sus pasos con el reloj de Alfa (`N.Ticker("comercio.buzon")`). Prueba: `tools/banco/prueba_131_bolsas.lua`.

## Comandos

- `/alfa comercio`: abre la página.
- `/alfa comercio escanear`: escaneo completo (con la subasta abierta).
- `/alfa comercio precio <enlace>`: escribe el consejo de un objeto en el chat.
- `/alfa comercio oficios`: la guía de oficios de 1 a 300.

## Ajustes (al final de la página: En el juego, Las cuentas, Tus datos)

| Ajuste | Por omisión | Qué hace |
|---|---|---|
| Consejo en el cuadro de los objetos | sí | Las dos líneas en el cuadro de cada objeto |
| Barra de Alfa en la casa de subastas | sí | El botón Escanear con Alfa |
| Aprender de tus búsquedas | sí | Guarda los precios de lo que buscas a mano |
| Comisión de la subasta | 5 % | Lo que se queda la subasta de cada venta (estimado) |
| Considerar desencantar | Si tú o tus personajes pueden | O Siempre (un amigo te ayuda) o Nunca |
| Avisar cuando los precios tengan más de | 3 días | Cuándo un precio cuenta como viejo |
| Ayuda al subastar | sí | El panel junto a la pestaña de vender (`vender`) |
| Avisar si lo das más barato de | 30 % | Cuánto por debajo de lo que vale avisa (`precioBajo`) |
| Avisar al juntar lo de tu lista | sí | Los avisos de la lista de compras (`listaAviso`) |
| Oficios de 1 a 300 en esta página | sí | La sección Oficios (`oficios`) |
| Borrar los precios de este reino | — | Pide confirmación |

Datos: `N.Datos("comercio")` (`AlfaNucleoDB.comercio`): `reinos["Reino-Facción"]` con precios (`p`), historial (`h`), último escaneo y última petición; `comprar` (precios del comerciante); `recetas` y `encantar` por personaje.

## Lo que es estimado

- **Comisión:** la API de Forever no la informa. Se usa 5 % (ajustable). El depósito no se cuenta porque se devuelve si el objeto se vende.
- **Espera del escaneo completo:** la API no la informa. Se usan 15 minutos. Si la subasta no responde en 90 s, Alfa avisa.
- **Tablas de desencantar** (`Datos.lua`): son las del juego clásico, escritas a mano.
- **Precio por objeto, no por variante:** los objetos con sufijo ("del oso") comparten precio; se toma el más barato.

## Para verificar en el juego

1. Abrir la casa de subastas: la barra de Alfa aparece bajo la ventana, a la derecha, sin tapar las pestañas ni el dinero.
2. Pulsar **Escanear con Alfa**: el texto pasa a "Pidiendo...", luego "Leyendo precios... %" sin tirones, y termina con "¡Listo! N precios guardados" y un mensaje en el chat.
3. Volver a pulsar: el botón dice "Espera N min". Comprobar si 15 min es la espera real (si el servidor no responde antes, ajustar `ESPERA` en `Subasta.lua`).
4. Comparar un precio guardado con lo que muestra la subasta para ese objeto (por unidad). Confirmar que `buyoutPrice` de `GetReplicateItemInfo` es el total de la pila (Alfa lo divide entre `count`) y que llega aunque `hasAllInfo` sea falso.
5. Buscar algo a mano (un mineral y una pieza de equipo): su precio se actualiza con fecha "hace un momento".
6. Poner a la venta algo y ver la comisión real que cobra la subasta; si no es 5 %, cambiar el ajuste por omisión.
7. Abrir la ventana de una profesión: en la página aparecen recetas en "Tus recetas que dejan ganancia" (o el aviso de precios faltantes). Confirmar que `C_TradeSkillUI.GetFilteredRecipeIDs` devuelve las recetas aprendidas y que `GetRecipeSchematic` trae reactivos y producto.
8. Con Encantamiento: un objeto verde o azul muestra "Desencantar ≈ ..." y comparar con lo que sale de verdad al desencantar algunos.
9. Pasar el ratón por objetos de las bolsas, del comerciante y de la subasta: las dos líneas de Alfa aparecen una sola vez y sin errores.
10. En la página: la tarjeta de arriba (qué hacer y su acción: escanear con la subasta abierta, o la flecha a la subasta o al comerciante), los filtros, "Ver todo", el orden por ganancia, la tarjeta de precios y los ajustes (cada uno se guarda tras `/reload`).
11. Con otro addon de subastas instalado, Alfa no toma sus precios ni reacciona a sus escaneos: solo lee los que pide su botón.

## 1.3.2

- «Tomar todo» pedido mientras cargan las cartas: el botón dice «Parar» y otro clic lo cancela (`Bz.Pendiente()`, `Bz.Barra()` para las pruebas). Prueba: `tools/banco/prueba_132_hoy.lua`.
