# Interfaz de Alfa — Diseño A, «moderno táctico»

La interfaz propia de Alfa reemplaza el aspecto de Polestar (cielo nocturno, estrellas, halos, oro) por uno de La Jauría: grafito, líneas finas, esquinas cortadas como las facetas del lobo y el verde de la manada. Todo el motor (ventana de guía, selector, buscador, diario de mazmorras, diálogos, menús, avisos) y las páginas de los módulos lo toman solos, porque se pintan con `Alfa.Theme` y `Alfa.Widgets`.

## Dónde vive

| Archivo | Qué hace |
|---|---|
| `motor/Alfa/Theme/Theme.lua` | Paleta, letra, formas (esquinas cortadas) y pintura de cada tipo de marco |
| `motor/Alfa/Theme/Widgets.lua` | El kit de piezas (`W.*`) y el armazón de ventanas `W.Shell`, con el de la ventana principal |
| `motor/Alfa/UI/Options.lua` | La ventana principal: secciones, páginas, búsqueda de ajustes, «Tu guía», `/alfa` y `/alfa guia` |
| `motor/Alfa/Maps/MinimapButton.lua` | El clic izquierdo del botón del minimapa abre la ventana principal |
| `motor/Alfa/Interfaz/Textos.lua` | Los textos nuevos de la interfaz (clave en español, su inglés) |
| `tools/interfaz.py` | Dibuja las texturas (`marca/` reemplaza las de Polestar; `motor/Alfa/Media/UI/` las nuevas) |
| `tools/parches.py` (`INTERFAZ`) | Carga `Interfaz/Textos.lua` en `Alfa.toc` y deja en neutro los textos que nombraban otros addons |

Para tocar otro archivo del motor: `python -I tools/build.py` y `python -I tools/motor.py tomar Alfa/<ruta>`; se edita en `motor/`. Las texturas se vuelven a dibujar con `.venv/Scripts/python -I tools/interfaz.py [carpeta]` (con una carpeta deja una hoja PNG para verlas).

## Paleta

| Token (`Theme.Color`) | Valor | Uso |
|---|---|---|
| `bg` | `#101412` | Fondo de toda ventana (con la opacidad del jugador) |
| `panel` | `#18201b` | Paneles, tarjetas, menús |
| `panelAlt` | `#1f2a23` | Panel elevado: botones, controles, sección elegida |
| `line` | `#26302a` | Líneas de 1 px y bordes de paneles y ventanas (`border` y `divider` lo usan) |
| `lineStrong` | `#34423a` | Borde de un control (botón, desplegable, campo) |
| `text` | `#e6efe4` | Texto |
| `textDim` | `#a3b1a4` | Descripciones largas (un punto más claro, para leer de corrido) |
| `textMuted` | `#8a998b` | Texto secundario |
| `accent` | `#8be04e` | Verde de La Jauría: lo elegido, lo principal, el progreso |
| `onAccent` | `#0d1a08` | Texto e íconos sobre el acento |
| `warning` | `#f0b34a` | Aviso |
| `danger` / `dangerFill` | `#e86b5a` / `#e05a4f` | Peligro: en texto (se lee sobre el panel elevado) y en rellenos y líneas |
| `gold` (= `quest`) | `#f2d06b` | Oro, misiones |
| `class` / `classText` | color de la clase | Segundo acento: barra de XP, franja de la tarjeta de clase, nombre del personaje (`classText` está aclarado para leerse) |
| `sidebar`, `footer`, `scrim` | `#0d110f`, `#141a16`, `#0b0e0c` | Barra lateral del selector, pie, fondo bajo texto sobre arte |

Los esquemas (Ajustes > Apariencia) son **Grafito** (el de arriba), **Noche** (más hondo) y **Pizarra** (gris neutro). El color de fondo propio, el brillo, la opacidad y el acento propio siguen funcionando, y la regla de Polestar se conserva: el texto siempre se lee (7:1 el principal, 4.5:1 el resto), y si un fondo no lo permite se oscurece.

## Formas

- **Esquinas cortadas en diagonal** arriba a la izquierda y abajo a la derecha: ventana 10, panel y tarjeta 8, control 6, chip e interruptor 4, casilla 3 (`Theme.CUT`).
- **Líneas de 1 px** en `line`; el borde de la ventana sigue el ajuste de grosor y color del jugador, sobre el mismo corte.
- **Sin brillos**: no hay banda de cielo (la cabecera es el fondo con una línea debajo), ni estrellas, ni halo detrás del emblema, ni luz bajo el borde. En lugar del «rim» dorado de Polestar, cada ventana lleva una **marca**: una raya de acento de 44 × 2 justo después de su corte.
- **Letra**: Inter (la del aspecto de Alfa). La palabra **A L F A** es la única en mayúsculas espaciadas.
- Un relleno de `W.Fill` que llega a una esquina cortada de su ventana (un pie, un panel de detalles a la derecha) toma el mismo corte, para que la ventana no pierda su forma.
- Los otros aspectos (Halo, Hearth y los del juego) siguen como estaban, con sus formas rectas.

## Componentes

Todo módulo usa las mismas piezas de siempre; ninguna cambió de nombre ni de argumentos:

| Pieza | Aspecto A |
|---|---|
| `W.Button` | Panel elevado con borde `lineStrong` y esquinas cortadas; `primary` relleno de acento con texto `onAccent`; `danger` texto rojo sobre un tinte rojo; `ghost` solo texto |
| `W.Toggle`, `W.Switch` | Pista de esquinas cortadas (acento encendida) y una perilla cuadrada facetada |
| `W.Slider` | Pista de 2 px, relleno de acento, perilla facetada |
| `W.Dropdown`, `W.SearchBox`, `W.CopyBox` | Campo de esquinas cortadas; el enfocado se bordea de acento |
| `W.Chip` | Etiqueta de esquinas cortadas (`"accent"`, `"success"`, `"warning"`, `"dungeon"` y el nuevo `"class"`) |
| `W.ActionTile`, `W.RowPanel`, menús, `W.Modal` | Panel o tarjeta de esquinas cortadas con su línea |
| `W.Rim` | La marca de acento del borde superior |
| `W.Tag(parent, w, h, corte)` | Nuevo: una caja facetada con `:SetColor` (lo usan chips e interruptores) |

Para dibujar una forma propia: `Theme.CutShape(marco, arriba_izq, abajo_der, capa, subcapa)` devuelve una forma con `:SetColor(r, g, b, a)`, `:SetShown`, `:SetCut`; `Theme.CutBorder(marco, arriba_izq, abajo_der, r, g, b, a)` le pone su línea. `Theme.Skin(marco, "panel")` lo hace todo de una vez (`marco.psCut` cambia el corte).

## La clase del jugador

```lua
local c = Alfa.Theme.Clase()
-- c.archivo  "WARRIOR"        c.nombre  "Guerrero" (como lo dice el cliente)
-- c.r, c.g, c.b               el color tal cual (rellenos, barras, franjas)
-- c.hex      "ffc79c6e"       para |c...|r
-- c.texto    { r, g, b }      el mismo, aclarado para leerse sobre los paneles
```

El color viene del cliente (`C_ClassColor`, `RAID_CLASS_COLORS`), así que un addon de colores de clase también manda. Antes de iniciar sesión es el acento. También están los tokens `"class"` y `"classText"` para `W.Color(region, "class")`, que se repintan solos.

## La ventana principal

`/alfa` sin nada y el clic izquierdo del botón del minimapa la abren o la cierran (y traen de vuelta un Alfa oculto). Siempre abre en **Hoy**. La ventana de guía se muestra y se oculta con su tecla, su botón y `/alfa guia`. El clic derecho del minimapa conserva su menú.

```
┌─────────────────────────────────────────────────────────────────────┐
│ [lobo] A L F A  ▌Toxic · Guerrero · Armas · Nivel 23   24 % · 50 %   [buscar ajustes] ✕ │
│                 ▌▓▓▓▓░░░░░░ (XP en el color de la clase, la descansada detrás)          │
├─────────────────────────────────────────────────────────────────────┤
│ Hoy  Aventura  Personaje  Mundo  Oficios  Manada               ⚙ Ajustes │
├─────────────────────────────────────────────────────────────────────┤
│ (Builds) (Curación) (Bolsas)   subtítulo de la página                │
│ pestañas de la página, si tiene varias                                │
│ cuerpo                                                                │
├─────────────────────────────────────────────────────────────────────┤
│ Restablecer página  Recargar interfaz      [Discord] Versión 0.1.0 BETA  Cerrar │
└─────────────────────────────────────────────────────────────────────┘
```

Medidas (`W.TOP`): 940 × 700; cabecera 76, secciones 54, píldoras 46, pestañas 36, pie 52. El cuerpo mide `BodyWidth` = 874 de ancho entre los márgenes (`W.SHELL.pad`, 32) y `psViewH` de alto visible (470 sin pestañas). Una sección con una sola página muestra su título y subtítulo en lugar de píldoras. Si las secciones no caben (otro idioma), quedan solo con su ícono y el nombre en su ayuda.

### Secciones

| Sección | Páginas (clave) |
|---|---|
| Hoy | `inicio` |
| Aventura | `guia` (Tu guía, del motor), `rutas`, `mazmorras` |
| Personaje | `builds`, `curacion`, `bolsas` |
| Mundo | `mundo`, `recoleccion` |
| Oficios | `comercio`, `pesca` |
| Manada | `manada` |
| Ajustes (engrane, a la derecha) | las del motor: `guide`, `appearance`, `map`, `questing`, `discovery`, `qualityoflife` (con Comodidades), `integrations`, `guidepacks`, `gamepad`, `recorder`, `about`; y toda página que no esté en otra sección |

`thanks` (los mecenas de Polestar) no sale en la navegación, pero se puede abrir por su clave. «Acerca de» conserva sus créditos (GPL). Cada sección recuerda la última página que viste en ella.

**Tu guía** (Aventura) muestra la guía que sigues, el paso de ahora con hasta tres metas y el avance, y cuatro accesos grandes: mostrar u ocultar la ventana de guía, elegir otra guía, el buscador y el diario de mazmorras.

### Cómo un módulo elige su sección e ícono

- **Ícono**: el `icono` de `N.Modulo` (un `.tga` de `Alfa/Media/UI`) es el de su píldora. Los de las secciones son `sec-hoy`, `sec-aventura`, `sec-personaje`, `sec-mundo`, `sec-oficios`, `sec-manada` y `sec-ajustes`.
- **Sección**: hay tres formas, de la más fija a la más flexible:
  1. Agregar su clave a `SECCIONES` en `motor/Alfa/UI/Options.lua` (el orden de la lista es el orden de las píldoras).
  2. Que el registro traiga `seccion = "personaje"` (y si quiere, `label` para el nombre que muestra): `Alfa.RegisterOptions` ya lo lee. `N.Modulo` todavía no lo pasa; basta con agregar `seccion = spec.seccion` en su llamada a `A.RegisterOptions`.
  3. En tiempo de ejecución: `Alfa.UI.Options.AsignarSeccion("clave", "mundo")`.
- Sin nada de eso, la página va a **Ajustes**.
- Lo demás sigue igual: la página se registra con `N.Modulo` (`Alfa.RegisterOptions({ page, key, icon, order, custom, controls })`), arma su vista en `construir(view)`, mide su ancho con `N.AnchoPagina()`, dibuja filas con `N.FilasDeAjustes(...)`, devuelve su alto en `view.Refresh` y avisa cambios con `W.ShellBody(win, alto)`. `Alfa.Fire("SHOW_OPTIONS", clave)` la abre.

## Textos

Los textos nuevos se escriben en español y su inglés va en `motor/Alfa/Interfaz/Textos.lua` (`local _, M = ...; M.EN = { ["español"] = "English" }`, que en el motor es `Alfa.EN`). En el juego se leen con `ns.T(texto)` (también `Alfa.Theme.T`): en español sale el texto, en inglés su traducción de `Textos.lua`, y en los demás idiomas la del núcleo (`AlfaNucleo.Textos`), que `tools/textos.py` arma desde este archivo. Un texto que no es clave vuelve igual, así que la ventana pasa por `ns.T` cada etiqueta, ayuda, sección, pestaña y título: un control puede traer directamente la clave en español. Los textos que ya tenía el motor (`L["English"]` y sus paquetes de idioma) siguen igual.

## Sin nombrar otros addons

La interfaz del motor no nombra addons de terceros salvo cuando están cargados: las opciones de flechas de bolsa y de entregas en el rastreador de otros addons, y las de la flecha y los puntos de ruta de otro addon, solo aparecen si ese addon está cargado (`C_AddOns.IsAddOnLoaded`); los textos de la importación de escalas hablan de «cadena de escala de estadísticas» (el formato técnico de la cadena se queda, porque es el de los datos), y la ayuda de las rutas ya no nombra al enrutador. Los créditos de «Acerca de» (licencias) se quedan.
