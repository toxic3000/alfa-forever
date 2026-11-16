# Alfa - Mundo

Página **Mundo** (orden 31) de la ventana de Alfa: un mapa continuo y limpio, con un solo control para todo lo que se pinta.

- **Mapa del mundo continuo**: una ventana propia (no toca el mapa de Blizzard) con todo Azeroth en un solo lienzo. Rueda: zoom donde está el cursor; arrastrar: mover; doble clic: acercar; clic derecho: alejar; Mayús+clic: la flecha te lleva ahí. Abre centrado en tu zona.
- **Zonas sin descubrir reveladas** con los recuadros de exploración del motor (con tono frío si quieres), en el mapa de Alfa y en el del juego (`maps.reveal`).
- **Coordenadas** tuyas y del cursor bajo el mapa, y en el minimapa como opción.
- **Niveles de zona** sobre cada zona y bajo el cursor, con color según tu nivel; **entradas de mazmorras** marcadas (se encienden la primera vez).
- **Un solo control de capas**: en la página, en el botón del mapa de Alfa, en los botones junto a la lupa del mapa del juego y dentro del menú de esa lupa. Las capas del motor están enlazadas a sus ajustes; las de otros módulos llegan por el contrato de abajo.
- **Modo limpio**: un clic deja solo lo esencial (tú, tu grupo y el siguiente paso de la guía) y al salir devuelve todo como estaba.

## Comandos y tecla

- `/alfa mapa`: abre o cierra el mapa. `/alfa limpio`: cambia el modo limpio. `/alfa mundo`: la página.
- Tecla propia en Opciones > Teclado > Alfa ("Abrir o cerrar el mapa de Alfa", `Bindings.xml`). Opción para que la tecla del mapa (M) abra el de Alfa.

## Ajustes (`mundo.*`)

`grupo` (tu grupo en el mapa), `nombres` (nombres de zona), `detalle` (arte fino con las texturas de detalle de `VENDOR.md`), `botonMapa`, `menuMapa`, `teclaM`, `ventana` (tamaño y lugar), `limpio`, `antes` y `suprimidas` (lo que el modo limpio apagó), `capas.<id>` (capas de otros módulos). El resto son los del motor (`nav.*`, `qol.*`, `rares.*`, `maps.*`).

## Contrato de capas (para otros módulos)

```lua
-- En su .toc:  ## OptionalDeps: Alfa_Mundo   (así Mundo carga antes)
if AlfaMundo and AlfaMundo.RegistrarCapa then
	AlfaMundo.RegistrarCapa({
		id = "recoleccion.mineria",       -- único; no puede ser uno de Mundo
		grupo = "Recolección",            -- "Guía", "Zonas"... caen en el grupo de Mundo
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

`RegistrarCapa` devuelve el id, o `nil, error` sin ventana de error. El estado de fábrica es el `activa` de la primera vez que se registró (se recuerda); después manda lo guardado. Un módulo puede copiar en su propio ajuste lo que oye en `alCambiar` y devolverlo con `ActivarCapa`: repetir el estado que ya manda no cuenta como decisión del jugador, así el modo limpio vuelve bien. Se puede registrar en cualquier momento: la página y los paneles se rearman solos. Si un módulo carga antes que Mundo puede dejar sus specs en `AlfaMundo = { pendientes = { spec, ... } }` y Mundo las registra al cargar. El estado se guarda en `mundo.capas.<id>` (los caracteres que no son letras ni números pasan a `_`).

Ids de Mundo que se pueden consultar: `esencial.grupo`, `guia.mapa`, `guia.ruta`, `guia.siguientes`, `guia.minimapa`, `guia.rutaMinimapa`, `misiones.disponibles`, `misiones.entregas`, `misiones.objetivos`, `misiones.minimapa`, `raros.mapa`, `raros.tesoros`, `raros.minimapa`, `raros.tesorosMinimapa`, `viaje.mazmorras`, `viaje.vuelo`, `viaje.barcos`, `viaje.posadas`, `viaje.servicios`, `viaje.minimapa`, `viaje.serviciosMinimapa`, `zonas.descubrir`, `zonas.niveles`, `zonas.nombres`, `zonas.coordenadas`, `zonas.coordMinimapa`.

Lo que un módulo publica con `Alfa.Pins.SetLayer` se ve en el mapa del juego; en el mapa de Alfa se dibujan las capas de Pins del motor que lista `Marcas.lua` (`CAPAS_MOTOR`) y la de cada capa registrada (su `id` o su `pines`) mientras está activa. Lo que un módulo pinta con marcos propios sobre el mapa del juego no sale en el de Alfa.

## Para verificar en el juego

1. `/alfa mapa`: abre centrado en tu zona; rueda, arrastre, doble clic, clic derecho y los botones + y – van suaves y sin tirones al cruzar un continente entero.
2. Del mundo entero al detalle: entra el arte de los continentes y luego el de las zonas sin huecos ni bordes cuadrados visibles; las ciudades aparecen al acercarte. Con y sin las texturas de `VENDOR.md`.
3. Zonas sin descubrir: con "Reveladas con otro tono" lo no explorado se ve en tono frío; con "Ocultas", solo lo explorado. Explorar un área nueva la actualiza.
4. Tu flecha gira con la cámara; tu grupo aparece con su color de clase; el pie muestra zona, niveles y coordenadas (comparar con las del motor bajo el mapa del juego).
5. Mayús+clic pone el destino de la flecha en el punto exacto.
6. Mazmorras, vuelos, misiones y raros salen en el mapa de Alfa en el mismo lugar que en el del juego, con su cuadro y su clic.
7. Panel de capas (mapa de Alfa y botones junto a la lupa del mapa del juego): cada interruptor apaga y enciende lo suyo en los dos mapas y en el minimapa. El menú de la lupa trae "Alfa: capas del mapa".
8. Modo limpio: deja la flecha, su ruta, tu grupo y las coordenadas; al salir vuelve todo, salvo lo que tocaste entretanto. Sobrevive a `/reload`.
9. Tecla M con "Abrir el mapa de Alfa con la tecla del mapa": abre el de Alfa; apagado, vuelve el del juego. No hay errores de "acción bloqueada" al abrir el mapa del juego en combate después de usar el de Alfa.
10. Con la interfaz de mando (gamepad) no aparecen botones ni menú de Alfa en el mapa del juego.
