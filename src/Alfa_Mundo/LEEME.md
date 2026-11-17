# Alfa - Mundo

Página **Mundo** de la ventana de Alfa (sección Mundo) y el **mapa de Alfa**: todo el mundo en un solo mapa con zoom, tus **marcadores** y un solo control para todo lo que se pinta. Interfaz hecha con el Kit (`docs/KIT.md`).

- **Mapa de Alfa** (`Ventana.lua`, una `K.Ventana` propia que no toca el mapa de Blizzard): rueda = zoom suave donde está el cursor; arrastrar = mover, con inercia al soltar rápido; doble clic = acercar; botones +, – y centrar en mí abajo a la derecha. Arriba: tus marcadores, las capas, el modo limpio, el mapa del juego y los ajustes. Se mueve por la cabecera, cambia de tamaño por la esquina y recuerda las dos cosas. Abre centrado en tu zona.
- **La tecla M** (`mundo.teclaM`, **encendida de fábrica**) abre el mapa de Alfa; en él, "Ir al mapa del juego" abre el del juego en la misma zona (con el abridor del cliente, `Compat.OpenWorldMap`: nunca en combate). En el mapa del juego, junto a la lupa, el botón **"Mapa de Alfa"** cambia al de Alfa (el del juego queda debajo: cerrarlo desde un addon lo contamina).
- **Marcadores** (`Marcadores.lua`, `Editor.lua`, `PanelMarcadores.lua`), guardados para la cuenta en `N.Datos("mundo").marcadores`:
  - **Poner**: en el mapa de Alfa, clic derecho o Mayús+clic; en el del juego, **Mayús+clic derecho** (`mundo.marcarEnMapaJuego`). Se abre su ficha: nombre, 13 íconos (huella, lobo, cofre, peligro, misión, mazmorra, raro, recurso, pesca, oro, comercio, posada, destino) y 10 colores del tema. "Guardar" o "Guardar y seguir".
  - **Ficha de uno tuyo**: clic en su pin (cualquier mapa) o en "Cambiar o borrar" de la lista: cambiarlo, compartirlo, borrarlo (con "Deshacer") o seguirlo.
  - **Seguir**: la flecha y la ruta del motor (`Nav.SetTarget` + `Nav.StartTrip`): al llegar, la flecha vuelve a la guía. Desde la ficha, la lista, Mayús+clic en el pin o el aviso al recibir uno. **Cualquier otro pin** del mapa de Alfa (mazmorras, vuelos, raros, misiones...): clic derecho → "Seguir (flecha y ruta)" o "Guardar como marcador". Ctrl+clic en el mapa de Alfa: la flecha y la ruta a ese punto, sin guardar nada.
  - **Lista**: botón de la huella en el mapa de Alfa (con buscador desde 7) y sección "Tus marcadores" de la página. Clic en uno: el mapa va hasta él.
  - **Compartir con el grupo**: mensaje de addon oculto (prefijo `AlfaMarca`, al grupo o la banda). Quien usa Alfa lo recibe en sus marcadores con tu nombre y un aviso para seguirlo (`mundo.recibirMarcadores`). En una instancia el juego no deja mandarlo: queda en espera y sale solo al salir. Las cuentas de prueba no pueden.
  - Se ven en el mapa de Alfa, en el del juego y en el minimapa: capas de `Alfa.Pins` (`mundo.marcadores`, `mundo.marcadoresMini`) con su grupo "Tus marcadores" en el control de capas. Son esenciales: el modo limpio las deja.
- **Zonas sin descubrir reveladas**, **coordenadas**, **niveles de zona**, **entradas de mazmorras** (se encienden la primera vez).
- **Un solo control de capas**: en la página (un grupo a la vez), en el botón de capas del mapa de Alfa, junto a la lupa del mapa del juego y dentro del menú de esa lupa.
- **Modo limpio**: un clic deja solo lo esencial (tú, tu grupo, tus marcadores y el siguiente paso de la guía) y al salir devuelve todo como estaba.

## Comandos y tecla

- `/alfa mapa`: abre o cierra el mapa. `/alfa limpio`: cambia el modo limpio. `/alfa mundo`: la página.
- Tecla propia en Opciones > Teclado > Alfa ("Abrir o cerrar el mapa de Alfa", `Bindings.xml`).

## Ajustes (`mundo.*`)

`teclaM` (sí), `botonMapa` (sí), `menuMapa` (sí), `marcarEnMapaJuego` (sí), `recibirMarcadores` (sí), `grupo`, `nombres`, `detalle`, `ventana` (`{ ancho, alto }`), `limpio`, `antes` y `suprimidas` (lo que el modo limpio apagó), `capas.<id>` (capas de otros módulos). El resto son los del motor (`nav.*`, `qol.*`, `rares.*`, `maps.*`).

## Contrato de capas (para otros módulos)

```lua
-- En su .toc:  ## OptionalDeps: Alfa_Mundo   (así Mundo carga antes)
if AlfaMundo and AlfaMundo.RegistrarCapa then
	AlfaMundo.RegistrarCapa({
		id = "recoleccion.mineria",       -- único; no puede ser uno de Mundo
		grupo = "Recolección",            -- "Guía", "Zonas", "marcadores"... caen en el grupo de Mundo
		nombre = "Minería",
		icono = "Interface\\...",         -- ruta o fileID (opcional)
		color = "quest",                  -- color del tema para teñir el ícono (opcional)
		ayuda = "Vetas en el mapa y el minimapa.", -- opcional
		activa = true,                    -- estado de fábrica
		esencial = false,                 -- true: se queda en el modo limpio
		alCambiar = function(activa) end, -- al cambiar (y una vez al registrar, en el siguiente cuadro)
		pines = "otra.capa",              -- capa de Alfa.Pins que dibuja el mapa de Alfa (por omisión, el mismo id)
		zoom = 2,                         -- desde qué zoom se ven esos pines en el mapa de Alfa
	})
end
AlfaMundo.CapaActiva(id)        --> boolean (ya cuenta el modo limpio)
AlfaMundo.ActivarCapa(id, on)   -- (= PonerCapa) pedir el estado que ya manda no cambia nada
AlfaMundo.ModoLimpio(), AlfaMundo.PonerModoLimpio(on)
AlfaMundo.Capas()               --> { { id, grupo, nombre, activa, esencial }, ... }
AlfaMundo.Abrir(uiMapID?)       -- AlfaMundo.Alternar(), AlfaMundo.Cerrar()
```

`RegistrarCapa` devuelve el id, o `nil, error` sin ventana de error. El estado de fábrica es el `activa` de la primera vez que se registró (se recuerda); después manda lo guardado. Se puede registrar en cualquier momento: la página y los paneles se rearman solos. Si un módulo carga antes que Mundo puede dejar sus specs en `AlfaMundo = { pendientes = { spec, ... } }`. El estado se guarda en `mundo.capas.<id>`.

Ids de Mundo que se pueden consultar: `esencial.grupo`, `marcadores.mapas`, `marcadores.minimapa`, `guia.mapa`, `guia.ruta`, `guia.siguientes`, `guia.minimapa`, `guia.rutaMinimapa`, `misiones.disponibles`, `misiones.entregas`, `misiones.objetivos`, `misiones.minimapa`, `raros.mapa`, `raros.tesoros`, `raros.minimapa`, `raros.tesorosMinimapa`, `viaje.mazmorras`, `viaje.vuelo`, `viaje.barcos`, `viaje.posadas`, `viaje.servicios`, `viaje.minimapa`, `viaje.serviciosMinimapa`, `zonas.descubrir`, `zonas.niveles`, `zonas.nombres`, `zonas.coordenadas`, `zonas.coordMinimapa`.

Lo que un módulo publica con `Alfa.Pins.SetLayer` se ve en el mapa del juego; en el mapa de Alfa se dibujan las capas de Pins del motor que lista `Marcas.lua` (`CAPAS_MOTOR`) y la de cada capa registrada (su `id` o su `pines`) mientras está activa. Lo que un módulo pinta con marcos propios sobre el mapa del juego no sale en el de Alfa.

## Marcadores (para otros módulos)

```lua
AlfaMundo.Marcadores()                  --> { { id, nombre, mapa, x, y, icono, color, de }, ... }
AlfaMundo.PonerMarcador({ mapa, x, y, nombre, icono, color }) --> id   (x, y: 0-100 del mapa)
AlfaMundo.SeguirMarcador(id)            -- la flecha y la ruta del motor hasta él
AlfaMundo.SeguirPunto(mapa, x, y, nombre) -- lo mismo a un punto cualquiera, sin guardarlo
```

## Para verificar en el juego

1. **M** abre el mapa de Alfa centrado en tu zona; M otra vez lo cierra. "Ir al mapa del juego" abre el del juego en la zona que veías y cierra el de Alfa. En el mapa del juego, "Mapa de Alfa" (junto a la lupa) abre el de Alfa encima. Apagar "Abrir el mapa de Alfa con la tecla del mapa": M vuelve a abrir el del juego.
2. Zoom con la rueda y con +/–, suave y sin tirones; arrastrar y soltar rápido: sigue un poco y se frena; "centrar en mí" se desliza hasta ti.
3. Clic derecho en el mapa de Alfa: la ficha junto al cursor, el nombre listo para escribir; elegir ícono y color; Enter guarda. El pin sale en el mapa de Alfa, en el del juego (abrir la zona) y en el minimapa al acercarte, con su aro de color.
4. Mayús+clic derecho en el mapa del juego: la ficha de un marcador nuevo, y el mapa **no** se aleja. El clic derecho solo sigue alejando. Sin "acción bloqueada" al abrir el mapa del juego en combate después.
5. Seguir (ficha, lista o Mayús+clic en el pin): la flecha y su ruta (vuelos, barcos) van al marcador; al llegar, la flecha vuelve a la guía. "Dejar" en la lista la devuelve antes.
6. Clic derecho en una entrada de mazmorra o un maestro de vuelo del mapa de Alfa: "Seguir (flecha y ruta)" y "Guardar como marcador".
7. Compartir con alguien del grupo que use Alfa: le llega el aviso con "Seguir" y el marcador con tu nombre. Dentro de una mazmorra: dice que sale al salir, y sale.
8. Borrar uno: el aviso con "Deshacer" lo devuelve. "Borrar todos" pide confirmación.
9. Panel de capas (mapa de Alfa y junto a la lupa): cada interruptor apaga y enciende lo suyo en los dos mapas y en el minimapa, también "Tus marcadores". Modo limpio: quedan tú, tu grupo, tus marcadores y la guía.
10. Con la interfaz de mando (gamepad) no aparecen botones ni manejadores de Alfa en el mapa del juego.
