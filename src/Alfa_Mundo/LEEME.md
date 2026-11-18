# Alfa - Mundo

Página **Mundo** de la ventana de Alfa (sección Mundo) y el **mapa de Alfa**: todo el mundo en un solo mapa con zoom, tus **marcadores** y un solo control para todo lo que se pinta. Interfaz hecha con el Kit (`docs/KIT.md`).

- **Mapa de Alfa** (`Ventana.lua`, una `K.Ventana` propia que no toca el mapa de Blizzard): rueda = zoom suave donde está el cursor; arrastrar = mover, con inercia al soltar rápido; doble clic = acercar; botones +, – y centrar en mí abajo a la derecha. Arriba: **buscar cerca** (lupa, solo si Alfa_Rutas publica `AlfaCerca.Menu`: vuelo, posada, banco, reparar, buzón, entrenadores, subasta...), tus marcadores, las capas, el modo limpio, el mapa del juego y el **engrane** (estilo del mapa y "Más opciones de Mundo"). Se mueve por la cabecera, cambia de tamaño por la esquina y recuerda las dos cosas. Abre centrado en tu zona. El marco sigue el estilo de Alfa (Alfa, Clásico WoW, Cristal): en Clásico WoW el mapa, el pie y el asa quedan dentro del borde del cuadro de diálogo.
- **Estilo del mapa** (`mundo.estiloMapa`): **"terreno"** (de fábrica) o **"clasico"**. Con terreno, al acercarte (zoom 4,5 a 7, con fundido) se ve el **suelo real del minimapa** (montañas, ríos, caminos, los mismos tonos): la capa `terreno` de `Lienzo.lua`, encima del arte de zonas y debajo de las ciudades (los mosaicos no traen el interior de las ciudades) y de nombres, etiquetas y pines. En mar abierto no hay mosaicos y queda el arte de Blizzard. Clásico: solo el arte pintado. Se elige en el engrane del mapa y en la página.
  - Datos: `TerrenoDatos.lua` (2,4 KB): los fileID de los 1724 mosaicos de Kalimdor (988) y los Reinos del Este (736), en rachas `{ col, fila, n, fileID }` (106 rachas), sacados de TerrainWorldMap (MIT, `LICENSE-TerrainWorldMap.txt`, ver `VENDOR.md`). En Forever los mosaicos solo cargan por fileID.
  - Colocación: mosaico `mapCC_FF` = columna CC, fila FF de una rejilla de 64 x 64 de 533,33 yardas; su esquina está en Y = (32 − CC) · 533,33 y X = (32 − FF) · 533,33. Las yardas de las esquinas del mapa del continente (1414, 1415) salen de `C_Map.GetWorldPosFromMapPos` (por `Compat.MapToWorld`), su lugar en el mapa 947 de `GetMapRectOnMap` (`Geo.Rect`); los mosaicos de la orilla se recortan con `SetTexCoord`.
  - Carga: solo los mosaicos que se ven (más un margen), por la cola de `POR_CUADRO` con su fundido, con filtrado TRILINEAR y sin ajuste a píxel. Los que quedan lejos (más de 0,35 vistas) se sueltan, y con más de 600 cargados se sueltan todos los ocultos (~43 KB cada uno; todos juntos serían ~75 MB). Al alejarse por debajo del zoom 4,5 se sueltan todos.
  - Si un mosaico no carga (`SetTexture` da false o la textura queda sin fileID) se oculta y queda el arte. Si fallan los primeros 16, todos, el terreno se apaga solo y la página lo dice.
  - **De una pieza (1.2.1)**: con el estilo terreno (y el terreno disponible) no se pintan las bases ni los recuadros de cada zona (`Lz.ArteDeZonas`): cada zona tiene sus tonos y orillas y juntas se veían como pedazos pegados. Del arte del continente se pasa directo al terreno. Las zonas siguen contando como a la vista (`ZonasALaVista`) para Recolección. El estilo clásico las pinta como siempre.
  - **Sin rayas ni cuadros (1.2.1)**: cada mosaico se mete medio texel bajo cada vecino (`ENCIMA`, leyendo el texel de su orilla con `CLAMP`: nada se estira ni se mueve contra los pines) y los lados que dan a un hueco (sin mosaico o que no cargó) se difuminan con una máscara (`Lz.Bordes`: N = 1, E = 2, S = 4, O = 8; `Media/Borde/borde-<n>.tga`, de `tools/bordes.py`). Una tanda que espera más de `ESPERA_TANDA` (2 s) a una textura que no llega aparece con lo que llegó.
- **Nitidez**: el zoom nunca agranda un texel a más de ~2 píxeles de la pantalla, según la mejor capa que hay donde acercas (`Lz.Densidad`: el terreno; si no, el arte de la zona (solo en clásico), del continente o del mundo). Al arrastrar no se aleja solo.
- **Tu camino (1.2.1, `Trayecto.lua`)**, entre el arte y los pines:
  - **La ruta de la flecha**: la del motor (`RouteLines.GetPaths`, la misma del mapa del juego y el minimapa), con su estilo (`nav.lineStyle`: línea o puntos; los destellos van como línea) y desde donde vas (`Strokes.Live`). Las líneas son de `Strokes.Map` con una vista por continente que cubre solo la ventana (más 40 unidades): un camino largo no trabaja fuera de lo que se ve. Capa "Línea de la ruta" (`nav.routeLines`).
  - **El vuelo en grifo**: al elegir el destino (`TakeTaxiNode`, enganchado) se arma con sus escalas (`GetNumRoutes`, `TaxiGetNodeSlot`) por donde vuela el maestro de vuelo (`FlightTracks`); se dibuja desde que despegas hasta que aterrizas y se guarda para un `/reload` en el aire (`N.DatosPersonaje("mundo").vuelo`, una hora). Capa "Tu vuelo en el mapa" (`mundo.vueloEnMapa`, id `guia.vuelo`, esencial).
  - **El destino** con un aro que late (quieto con `ui.reduceMotion`) y, arriba a la izquierda, **la ficha**: a dónde vas, cuánto falta por el camino (`A.FormatDistance`) y en tiempo (el plan de viaje del motor; en el aire, el reloj de vuelo). Clic: la vista se desliza hasta mostrar todo el camino (`V.VerCamino`). En el aire manda el vuelo; la ruta sigue dibujada para después.
- **Tú (1.2.1)**: tu flecha lleva una sombra que la despega del suelo, un halo, un aro del color de acento y un pulso que sale cada 2 s (`Mc.Latir`; quieto con `ui.reduceMotion`).
- **La tecla M** (`mundo.teclaM`, **encendida de fábrica**) abre el mapa de Alfa; en él, "Ir al mapa del juego" abre el del juego en la misma zona (con el abridor del cliente, `Compat.OpenWorldMap`: nunca en combate). En el mapa del juego, junto a la lupa, el botón **"Mapa de Alfa"** cambia al de Alfa (el del juego queda debajo: cerrarlo desde un addon lo contamina).
- **Marcadores** (`Marcadores.lua`, `Editor.lua`, `PanelMarcadores.lua`), guardados para la cuenta en `N.Datos("mundo").marcadores`:
  - **Poner**: en el mapa de Alfa, clic derecho o Mayús+clic; en el del juego, **Mayús+clic derecho** (`mundo.marcarEnMapaJuego`). Se abre su ficha: nombre, 13 íconos (huella, lobo, cofre, peligro, misión, mazmorra, raro, recurso, pesca, oro, comercio, posada, destino) y 10 colores del tema. "Guardar" o "Guardar y seguir".
  - **Ficha de uno tuyo**: clic en su pin (cualquier mapa) o en "Cambiar o borrar" de la lista: cambiarlo, compartirlo, borrarlo (con "Deshacer") o seguirlo.
  - **Seguir**: la flecha y la ruta del motor (`Nav.SetTarget` + `Nav.StartTrip`): al llegar, la flecha vuelve a la guía. Desde la ficha, la lista, Mayús+clic en el pin o el aviso al recibir uno. **Cualquier otro pin** del mapa de Alfa (mazmorras, vuelos, raros, misiones...): clic derecho → "Seguir (flecha y ruta)" o "Guardar como marcador". Ctrl+clic en el mapa de Alfa: la flecha y la ruta a ese punto, sin guardar nada. **Al empezar a seguir algo** (cualquiera de estas acciones, todas pasan por `Mk.SeguirPunto`) se llama a `N.EmpezarRuta()` del núcleo: se cierran el mapa y las ventanas de Alfa y se ve el rastreador. `AlfaMundo.SeguirPunto` / `SeguirMarcador` (desde otro módulo) no lo llaman: ese módulo decide.
  - **Lista**: botón de la huella en el mapa de Alfa (con buscador desde 7) y sección "Tus marcadores" de la página. Clic en uno: el mapa va hasta él.
  - **Compartir con el grupo**: mensaje de addon oculto (prefijo `AlfaMarca`, al grupo o la banda). Quien usa Alfa lo recibe en sus marcadores con tu nombre y un aviso para seguirlo (`mundo.recibirMarcadores`). En una instancia el juego no deja mandarlo: queda en espera y sale solo al salir. Las cuentas de prueba no pueden.
  - Se ven en el mapa de Alfa, en el del juego y en el minimapa: capas de `Alfa.Pins` (`mundo.marcadores`, `mundo.marcadoresMini`) con su grupo "Tus marcadores" en el control de capas. Son esenciales: el modo limpio las deja.
- **Zonas sin descubrir reveladas**, **coordenadas**, **niveles de zona**, **entradas de mazmorras**, **puntos de vuelo** y **barcos** (los tres últimos los trae apagados el motor: Mundo los enciende una sola vez, con `N.Datos("mundo").iniciado`, `.vuelos` y `.entradas`; si después los apagas, se quedan apagados).
- **Puntos de vuelo** (`viaje.vuelo` = `maps.taxiPins`, capa `maps.taxi` del motor, `Maps/TravelPins.lua`): los maestros de vuelo de tu facción y los neutrales, verdes si ya los conoces y ámbar con "?" si no; el nombre y los vuelos desde ahí al pasar el ratón. Entran en el mapa de Alfa desde el zoom 1,5 (el continente entero). Clic (o clic derecho): "Seguir (flecha y ruta)" o "Guardar como marcador". La misma capa sale en el mapa del juego; en el minimapa solo con "Iconos de viaje en el minimapa".
- **Entradas y salidas** (grupo propio en el control de capas):
  - **Entradas de mazmorras** (`viaje.mazmorras`, del motor): ícono de mazmorra o de banda, nombre y rango de niveles al pasar el ratón; clic: su página; clic derecho: seguirla. El motor no tiene datos de la salida ni de la piedra de encuentro de cada instancia.
  - **Salidas de zona** (`entradas.salidas` = `mundo.salidas`, capa de Pins `mundo.salidas`, `Entradas.lua`): los pasos, túneles, puertas y puentes del grafo de navegación del motor (`AlfaNavChokepoints` de Alfa_Nav) cuyos dos lados caen en zonas distintas: un pin en cada lado, "Hacia <zona> (niv. x–y)", con una flechita hacia la otra zona y el nombre escrito desde el zoom 9. En el mapa de Alfa desde el zoom 6; en el del juego, solo en mapas de zona; también en el minimapa. Necesita Alfa_Nav cargado (con "Seguir caminos reales"); Mundo nunca lo carga.
  - **Barcos, zepelines y tranvía** (`viaje.barcos`, del motor): las dos puntas de cada viaje con su destino ("Barco a Menethil").
  - **Portales** (`entradas.portales` = `mundo.portales`, capa `mundo.portales`): los portales a pie del motor que puede usar tu facción, "Portal a <destino>".
- **Un solo control de capas**: en la página (un grupo a la vez), en el botón de capas del mapa de Alfa, junto a la lupa del mapa del juego y dentro del menú de esa lupa.
- **Modo limpio**: un clic deja solo lo esencial (tú, tu grupo, tus marcadores y el siguiente paso de la guía) y al salir devuelve todo como estaba.

## Comandos y tecla

- `/alfa mapa`: abre o cierra el mapa. `/alfa limpio`: cambia el modo limpio. `/alfa mundo`: la página.
- Tecla propia en Opciones > Teclado > Alfa ("Abrir o cerrar el mapa de Alfa", `Bindings.xml`).

## Ajustes (`mundo.*`)

`teclaM` (sí), `botonMapa` (sí), `menuMapa` (sí), `marcarEnMapaJuego` (sí), `recibirMarcadores` (sí), `estiloMapa` (`"terreno"` | `"clasico"`, terreno), `salidas` (sí), `portales` (sí), `vueloEnMapa` (sí), `grupo`, `nombres`, `detalle`, `ventana` (`{ ancho, alto }`), `limpio`, `antes` y `suprimidas` (lo que el modo limpio apagó), `capas.<id>` (capas de otros módulos). El resto son los del motor (`nav.*`, `qol.*`, `rares.*`, `maps.*`).

## Costo

- Terreno: ver arriba; los registros de los 1724 mosaicos se arman la primera vez que entra el terreno, y sus texturas una por mosaico la primera vez que se ve.
- Salidas: se arman una vez (unos 200 pines, un par de llamadas a `C_Map` por lado) 4 s después de entrar al juego, y otra vez solo si cambia el tema. El motor indexa los pines por celdas para el minimapa.
- Mapa de Alfa quieto: el latido (10 veces por segundo) mueve solo tu flecha y tu grupo; los pines se recorren solo si alguna capa de Pins cambió (el motor da una tabla nueva en cada `SetLayer`). Los marcos de pines se reusan y solo se crean para los que caen en la vista.

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

Ids de Mundo que se pueden consultar: `esencial.grupo`, `marcadores.mapas`, `marcadores.minimapa`, `guia.mapa`, `guia.ruta`, `guia.vuelo`, `guia.siguientes`, `guia.minimapa`, `guia.rutaMinimapa`, `misiones.disponibles`, `misiones.entregas`, `misiones.objetivos`, `misiones.minimapa`, `raros.mapa`, `raros.tesoros`, `raros.minimapa`, `raros.tesorosMinimapa`, `viaje.mazmorras`, `entradas.salidas`, `entradas.portales`, `viaje.vuelo`, `viaje.barcos`, `viaje.posadas`, `viaje.servicios`, `viaje.minimapa`, `viaje.serviciosMinimapa`, `zonas.descubrir`, `zonas.niveles`, `zonas.nombres`, `zonas.coordenadas`, `zonas.coordMinimapa`.

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
11. Terreno: acercar en Vallefresno (y en cualquier zona de Kalimdor y los Reinos del Este): el suelo del minimapa entra con un fundido, alineado con el arte (ríos, caminos, la costa, los pines de misiones y vuelos donde deben), sin rayas entre mosaicos y sin verse pixelado al máximo zoom. El mar abierto sigue con el arte de Blizzard; las ciudades con su mapa encima. Engrane → "Clásico": vuelve el arte pintado; "Terreno": regresa. Alejar y volver: sin tirones; la memoria del juego (`/alfa` o el administrador de addons) no crece sin parar al recorrer el mundo.
12. Con el arte clásico, el zoom se detiene antes de pixelarse (más pronto que con terreno).
13. Estilo de Alfa en Clásico WoW y en Cristal: el marco del mapa se ve con ese estilo y el mapa no tapa el borde.
14. Puntos de vuelo en un personaje nuevo: salen verdes los conocidos y ámbar con "?" los que faltan, solo los de tu facción y los neutrales; el nombre al pasar el ratón; clic: "Seguir (flecha y ruta)".
15. Salidas de zona: al acercarte a una zona, flechas en sus bordes ("Hacia Vallefresno (niv. 18–30)") que apuntan hacia la otra zona; clic: seguirla. Portales: el de Darnassus a Rut'theran (alianza). Barcos con su destino.
16. Con Alfa_Rutas que publica `AlfaCerca.Menu`: la lupa de la cabecera abre "lo que hay cerca"; sin él, la lupa no aparece.
17. (1.2.1) Estilo terreno: acercar desde el continente entero hasta el máximo en Dun Morogh, Los Humedales y Durotar: nunca se ven los dibujos de cada zona pegados, el terreno entra con un fundido sobre el continente, sin rayas entre mosaicos; en la costa y donde falte un mosaico la orilla se difumina. Clásico: las zonas pintadas como antes.
18. (1.2.1) Con un paso de la guía activo, abrir el mapa: la línea de la ruta desde tu flecha hasta el destino, el destino latiendo y arriba a la izquierda la ficha (nombre, distancia, tiempo). Caminar: la línea empieza donde vas y la distancia baja. Clic en la ficha: el mapa muestra todo el camino. Apagar "Línea de la ruta" en las capas: se va.
19. (1.2.1) Tomar un vuelo con escalas y abrir el mapa en el aire: la línea del vuelo por donde vuela el grifo, desde ti hasta donde aterrizas; la ficha dice "En vuelo a ..." con el tiempo. `/reload` en el aire: sigue. Al aterrizar: se va. Apagar "Tu vuelo en el mapa": se va.
20. (1.2.1) Tu flecha se ve en la nieve de Dun Morogh y en la arena de Tanaris, con su aro y su pulso; con "Menos movimiento" el pulso queda quieto.
