# Alfa - Bolsas

Tus bolsas, tu banco y el inventario de todos tus personajes en una ventana de Alfa. Todo es código propio.

## Qué hace

- **Tus bolsas en una ventana de Alfa** que se abre en lugar de las de Blizzard: con la B, Mayús+B, la tecla de cada bolsa, los botones de la barra, al visitar un comerciante, el correo o el banco, y al hacer clic en una alerta de botín. Escape o la X la cierran.
- **Dos vistas:** *por categorías* (Recientes, Equipo, Consumibles, Misiones, Artesanía y comercio, Componentes, Monturas y mascotas, Chatarra, Otros y Espacio libre, con encabezados que se pliegan) o *una sola bolsa* (todas las casillas en su lugar, con el llavero al final).
- **Ordenar** con `C_Container.SortBags` (y `SortBank` en el banco), con la opción de ordenar de derecha a izquierda.
- **Buscar** por nombre, tipo, calidad (también "verde", "azul", "morado"...) o nivel de objeto ("20", ">20", "<=30", "20-30"). Lo que coincide se resalta y lo demás se atenúa.
- **Marcas sobre cada objeto:** nivel de objeto, borde del color de la calidad, moneda sobre la chatarra, brillo en lo nuevo, flecha verde de mejora (la del motor: `Alfa.Gear.Bags.IsUpgrade`) y marco de objeto de misión.
- **El banco** en la misma clase de ventana: en vivo con un banquero y, si no, la última foto.
- **El inventario de todos tus personajes:** Alfa guarda por personaje su reino, facción, clase, nivel, dinero, bolsas, banco y equipo. En el cuadro de cada objeto: *"Tienes 12 (Toxic: 7 en bolsas, Alt: 5 en banco)"*. Desde la ventana (botón de personajes) o la página se ven las bolsas y el banco de cualquiera.
- **Pie de la ventana:** tu dinero, el de toda la cuenta y el espacio libre (al pasar el ratón: el detalle por bolsa y el dinero de cada personaje).
- Por categorías, mientras el ratón está sobre la ventana (vendiendo, usando) nada cambia de lugar: lo vendido queda vacío donde estaba y se acomoda al salir.

## Comandos

- `/alfa bolsas`: la página de Bolsas.
- `/alfa bolsas abrir`: abre o cierra tus bolsas.
- `/alfa bolsas banco`: tu banco (en vivo o la última foto).

## Ajustes (página Bolsas)

Vista, tamaño de los iconos, columnas, usar las bolsas de Alfa (apagado: vuelven las de Blizzard), usar el banco de Alfa, mostrar el llavero, botón Ordenar, ordenar de derecha a izquierda, cada marca, el conteo en el cuadro de los objetos, y la lista de tus personajes (ver sus bolsas o su banco, u olvidarlos).

Si hay otro addon de bolsas activo (la lista está en `Compat.lua`) o la interfaz para mando, Alfa no reemplaza las bolsas del juego; su ventana se sigue abriendo desde la página.

## Cómo está hecho (lo seguro)

- Los botones de tus bolsas y de tu banco abierto son `ContainerFrameItemButtonTemplate` de Blizzard, hijos de un marco con `SetID(bolsa)` y con `SetID(casilla)` propio: su clic es el de Blizzard, así que el clic derecho usa o equipa también en combate. Alfa nunca escribe en la tabla del botón: pinta regiones propias y guarda lo suyo aparte.
- Nada reemplaza funciones de Blizzard: `hooksecurefunc` en ToggleAllBags, ToggleBackpack, ToggleBag, OpenAllBags, OpenBackpack, OpenBag, CloseAllBags y CloseBackpack. Las bolsas y el banco de Blizzard siguen funcionando por dentro, dentro de un marco oculto.
- Por lotes: un cambio solo marca qué falta; se leen las bolsas marcadas, se crean a lo sumo 40 botones y se pintan a lo sumo 48 casillas por cuadro, y una casilla que no cambió no se vuelve a pintar.

## Para verificar en el juego

1. B, Mayús+B, la tecla de una bolsa y los botones de la barra abren y cierran la ventana de Alfa, una sola vez por pulsación, y no se ven las de Blizzard.
2. **En combate:** clic derecho sobre una poción o comida la usa, y sobre un arma la equipa (el chat no debe decir "Acción bloqueada" ni aparecer el aviso de addon bloqueado).
3. Arrastrar objetos entre casillas, a la barra de acciones y a la ventana del comerciante; Mayús+clic enlaza en el chat; Ctrl+clic en el probador.
4. En un comerciante: la ventana se abre sola, clic derecho vende y al cerrar el comerciante se cierra. Lo vendido no hace saltar las casillas mientras el ratón sigue encima.
5. Ordenar acomoda las bolsas (y "de derecha a izquierda" al revés); no hace nada en combate.
6. Buscar "espada", "verde", ">20" y "20-30".
7. Nivel de objeto, borde de calidad, moneda en lo gris, brillo en lo nuevo (se apaga al cerrar), flecha de mejora y marco de misión; cada uno se apaga desde la página.
8. Banco: la primera visita de cada personaje muestra el de Blizzard; desde la segunda, el de Alfa con tus bolsas. Clic derecho en tus bolsas guarda en el banco y en el banco lo saca. Al cerrar la ventana se termina la visita. Lejos del banco, el botón de banco muestra la foto con su fecha.
9. El cuadro de un objeto dice "Tienes N (...)" con tus personajes; ver las bolsas y el banco de otro personaje desde el menú de personajes y desde la página.
10. Apagar "Usar las bolsas de Alfa" devuelve las de Blizzard sin recargar (con las bolsas cerradas).
11. El llavero aparece al final en la vista de una sola bolsa y sus llaves en la de categorías.
