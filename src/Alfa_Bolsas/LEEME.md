# Alfa - Bolsas

Tus bolsas, tu banco y el inventario de todos tus personajes en una ventana de Alfa hecha con el Kit. Todo es código propio.

## Qué hace

- **Tus bolsas en una ventana de Alfa** que se abre en lugar de las de Blizzard: con la B, Mayús+B, la tecla de cada bolsa, los botones de la barra, al visitar un comerciante, el correo o el banco, y al hacer clic en una alerta de botín. Escape o la X la cierran. Vive en UIParent: se abre aunque ocultes Alfa.
- **Tres vistas** (botones de la cabecera): *todo junto* (cada casilla en su lugar, llavero al final), *por categorías* (Recientes, Equipo, Consumibles, Misiones, Artesanía y comercio, Componentes, Monturas y mascotas, Chatarra, Otros y Espacio libre, con encabezados que se pliegan) y *por bolsa* (cada bolsa en su bloque con su ícono, nombre y "N libres de M" o "llena").
- **Barra de tus bolsas** (ajuste `barra`): la mochila, las cuatro bolsas, la de componentes y el llavero, con su ícono, sus casillas y una raya de lo ocupado. Al pasar el ratón se resalta lo que lleva esa bolsa (un clic lo deja fijo); se cambia una bolsa arrastrando otra encima (fuera de combate).
- **Cuando las bolsas se llenan** (ajustes `avisoLleno` y `avisoLibres`, 4 casillas): un aviso del Kit y una franja en la ventana dicen qué vender y qué conservar, con acciones de un clic: *Marcar como chatarra* (las marcas del motor: se vende sola al abrir un comerciante), *Llévame al comerciante* o *al banco* (la flecha del motor) y, con el comerciante abierto, *Vender la chatarra*. Usa el consejo y el valor de Comercio.
- **Ordenar** con `C_Container.SortBags` (y `SortBank` en el banco), con la opción de ordenar de derecha a izquierda.
- **Buscar** por nombre, tipo, calidad (también "verde", "azul", "morado"...) o nivel de objeto ("20", ">20", "<=30", "20-30"). Lo que coincide se resalta y lo demás se atenúa.
- **Marcas sobre cada objeto:** nivel de objeto, borde del color de la calidad, moneda sobre la chatarra (y lo marcado como chatarra), brillo en lo nuevo, flecha verde de mejora (`Alfa.Gear.Bags.IsUpgrade`) y marco de objeto de misión.
- **El banco** en la misma clase de ventana: en vivo con un banquero y, si no, la última foto.
  - **Depositar rápido:** un botón y un menú: *lo que ya tienes en el banco*, *todos los materiales*, *una categoría…* y *todo lo que no sea equipo* (sin misiones, la piedra de hogar ni lo que tu guía aún necesita). Antes cuenta cuánto cabe; mueve por lotes tras tu clic y se detiene al entrar en combate o cerrar el banco. Otro clic lo detiene.
  - **Comprar espacio:** la barra del banco muestra la siguiente casilla de bolsa del banco con su costo; un clic pide confirmación y compra (`C_Bank.PurchaseBankTab`). Después se pone una bolsa en ella.
- **El inventario de todos tus personajes:** reino, facción, clase, nivel, dinero, bolsas (con la bolsa misma), banco, equipo y lo que cuesta su siguiente casilla del banco. En el cuadro de cada objeto: *"Tienes 12 (Toxic: 7 en bolsas, Alt: 5 en banco)"*.
- **Pie de la ventana:** tu dinero, el de toda la cuenta y el espacio libre (al pasar el ratón: el detalle y el dinero de cada personaje).
- En la vista por categorías, mientras el ratón está sobre la ventana nada cambia de lugar: lo vendido queda vacío donde estaba y se acomoda al salir.

## Página (Personaje > Bolsas)

Plantilla Tablero del Kit: arriba, cómo están tus bolsas y la acción de ahora (abrirlas; si se llenan, marcar la chatarra o ir al comerciante; si otro addon las tiene o usas mando, por qué). Debajo: tu banco (en vivo o foto, o "Llévame al banco"), más espacio en el banco (casillas compradas, el costo de la siguiente, comprar o ir), y qué vender y conservar (con enlace a Comercio). Luego tus personajes (bolsas, banco, olvidar) y los ajustes en grupos.

## Comandos

- `/alfa bolsas`: la página de Bolsas.
- `/alfa bolsas abrir`: abre o cierra tus bolsas.
- `/alfa bolsas banco`: tu banco (en vivo o la última foto).

## Lo que permite Forever para el espacio del banco

Forever (tipo de juego "Camelot" en el código de Blizzard) vende **casillas de bolsa del banco** una tras otra, no casillas sueltas: `C_Bank.FetchNumPurchasedBankTabs` / `FetchMaxNumBankTabs`, `FetchNextPurchasableBankTabData` (`tabCost`, `canAfford`), `CanPurchaseBankTab`, `HasMaxBankTabs` y `PurchaseBankTab` (pide un clic del jugador). La primera casilla es el banco base (gratis); de la segunda en adelante cada una guarda una bolsa en `(Enum.BagIndex.Characterbanktab, casilla)`. `GetBankSlotCost` y `PurchaseSlot` no existen en Forever. También hay `Enum.BankType.Account` (banco de cuenta); Alfa solo usa el del personaje.

## Cómo está hecho (lo seguro)

- Los botones de tus bolsas y de tu banco abierto son `ContainerFrameItemButtonTemplate` de Blizzard, hijos de un marco con `SetID(bolsa)` y con `SetID(casilla)` propio: su clic es el de Blizzard, así que el clic derecho usa o equipa también en combate. Alfa nunca escribe en la tabla del botón.
- La barra de bolsas son botones simples de Alfa (no las plantillas de casilla de bolsa del juego, que se registran en la barra de Blizzard y necesitan nombres globales): llaman `PickupBagFromSlot` / `PutItemInBag` con la ranura de `C_Container.ContainerIDToInventoryID`, y `C_Container.PickupContainerItem(Characterbanktab, casilla)` en el banco, como los botones del juego. Nunca en combate.
- Depositar y vender usan `C_Container.UseContainerItem` (con el banco: `bankType` del personaje), a lo sumo 6 casillas cada 0,2 s, releyendo cada casilla antes de moverla. Siempre empieza con un clic y nunca se repite solo.
- Nada reemplaza funciones de Blizzard: `hooksecurefunc` en ToggleAllBags, ToggleBackpack, ToggleBag, OpenAllBags, OpenBackpack, OpenBag, CloseAllBags y CloseBackpack.
- Por lotes: un cambio solo marca qué falta; se leen las bolsas marcadas, se crean a lo sumo 40 botones y se pintan a lo sumo 48 casillas por cuadro.
- Si hay otro addon de bolsas activo (solo para no chocar; la lista está en `Compat.lua`) o la interfaz para mando, Alfa no reemplaza las bolsas del juego. Alfa no lee nada de otros addons.

## Para verificar en el juego

1. B, Mayús+B, la tecla de una bolsa y los botones de la barra abren y cierran la ventana de Alfa, una sola vez por pulsación.
2. **En combate:** clic derecho sobre una poción la usa y sobre un arma la equipa, sin "Acción bloqueada".
3. Las tres vistas (botones de la cabecera y en la página); en *por bolsa*, el nombre y el ícono de cada bolsa.
4. Barra de bolsas: pasar el ratón resalta su contenido; clic lo fija; arrastrar una bolsa de las bolsas a una casilla de la barra la equipa o la cambia, y arrastrar desde la barra la recoge (sin errores, fuera de combate).
5. Con 4 casillas libres o menos: aparece el aviso y la franja; *Marcar como chatarra* pone la moneda y la mueve a Chatarra; en un comerciante se vende sola (o con *Vender la chatarra*); *Llévame al comerciante* pone la flecha.
6. Banco: *Depositar* con cada opción mueve lo que dice y se detiene al cerrar el banco; con el banco lleno avisa cuántos no cupieron.
7. Banco: la casilla "+" muestra el costo correcto; el diálogo compra al aceptar (verificar que `PurchaseBankTab` no pida otra cosa) y aparece la casilla nueva; arrastrar una bolsa a ella la pone.
8. Ordenar, buscar ("espada", "verde", ">20", "20-30"), las marcas y el cuadro "Tienes N".
9. Apagar "Usar las bolsas de Alfa" devuelve las de Blizzard sin recargar (con las bolsas cerradas).
