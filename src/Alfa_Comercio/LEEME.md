# Alfa - Comercio

Responde la pregunta "¿lo vendo al comerciante, lo subasto o lo convierto en algo que valga más?" para cada objeto. Solo informa: nunca compra, vende ni publica nada por ti.

## Qué hace

- **Precios de la subasta.** Con la casa de subastas abierta aparece una barra de Alfa bajo su ventana con el botón **Escanear con Alfa**. El escaneo completo (`C_AuctionHouse.ReplicateItems`) guarda el precio más bajo por unidad de cada objeto, con su fecha, por reino y facción, y un historial de 14 días (un precio por día) para ver si sube o baja. Se lee por lotes, sin congelar el juego. Entre escaneos hay que esperar 15 minutos.
- **Lo que ya buscas.** Cuando buscas algo en la subasta, Alfa también guarda el precio más bajo que ves.
- **Comerciante.** Al abrir un comerciante, anota lo que cuesta comprarle cada cosa (por ejemplo, el hilo), para calcular el costo de las recetas.
- **Recetas.** Al abrir la ventana de una profesión, Alfa lee tus recetas aprendidas (reactivos y producto). Sirven en todos tus personajes del mismo reino y facción ("créalo con Fulano").
- **Desencantar.** Si tú u otro personaje tuyo tiene Encantamiento con nivel suficiente, calcula el valor esperado de los materiales según la calidad y el nivel del objeto.
- **Consejo.** Para cada objeto compara vender, subastar (menos la comisión) y transformar (receta o desencantar). Recomienda lo que más oro deja si gana por lo menos un 10 % a venderlo; si nada da oro, dice que lo guardes.
- **Cuadro del objeto.** Dos líneas al pasar el ratón: `Subasta: 1o 20p (hace 3 h) · Comerciante: 15p` y `Mejor: subastar 1o 14p (+660%)`.
- **Página "Comercio".** Lo que llevas en las bolsas, ordenado por lo que más ganas, con un chip de color (Vender, Subastar, Transformar, Guardar), filtros por chip, el total si sigues los consejos contra venderlo todo, la antigüedad de los precios (con aviso para escanear) y tus recetas que dejan ganancia.
- **Otro addon de subastas.** Si hay uno instalado de la lista de `Compat.lua`, sus precios se usan solo cuando Alfa no tiene uno, a través de su API pública.

## Comandos

- `/alfa comercio`: abre la página.
- `/alfa comercio escanear`: escaneo completo (con la subasta abierta).
- `/alfa comercio precio <enlace>`: escribe el consejo de un objeto en el chat.

## Ajustes (en la página, sección Ajustes)

| Ajuste | Por omisión | Qué hace |
|---|---|---|
| Consejo en el cuadro de los objetos | sí | Las dos líneas en el cuadro de cada objeto |
| Barra de Alfa en la casa de subastas | sí | El botón Escanear con Alfa |
| Aprender de tus búsquedas | sí | Guarda los precios de lo que buscas a mano |
| Comisión de la subasta | 5 % | Lo que se queda la subasta de cada venta (estimado) |
| Considerar desencantar | Si tú o tus personajes pueden | O Siempre (un amigo te ayuda) o Nunca |
| Avisar cuando los precios tengan más de | 3 días | Cuándo un precio cuenta como viejo |
| Usar los precios de otro addon de subastas si faltan | sí | Solo aparece si hay uno instalado |
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
10. En la página: filtros por chip, totales, orden por ganancia, aviso de precios viejos y la sección Ajustes (cada ajuste se guarda tras `/reload`).
11. Con otro addon de subastas instalado: un objeto sin precio de Alfa toma el suyo y el ajuste aparece.
