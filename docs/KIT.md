# Kit de Alfa (interfaz 1.0)

El Kit son las piezas propias de la interfaz de Alfa 1.0: tokens, componentes, plantillas de página, ventanas, íconos y los **reemplazos** de las ventanas del motor. Se escribió desde cero (no deriva de `Theme/Widgets.lua`) y toda ventana o página nueva se arma con él. Plan y reglas de fondo: `docs/PLAN-1.0.md`.

```lua
local N = AlfaNucleo
local K = N.Kit          -- el Kit
local A = N.A            -- el motor (datos y funciones)
```

| Dónde | Qué |
|---|---|
| `src/Alfa_Nucleo/Kit/Tokens.lua` | Medidas, cortes, colores, letra, íconos, repintado |
| `src/Alfa_Nucleo/Kit/Formas.lua` | La forma de esquinas cortadas, su borde, la caja, la marca de acento |
| `src/Alfa_Nucleo/Kit/Basicos.lua` | Botones, insignia, interruptor, deslizador, segmentos, buscador, desplegable, atajo, barra, huellas, ícono de objeto, cuadro de información |
| `src/Alfa_Nucleo/Kit/Bloques.lua` | Pila, encabezado, sección, tarjeta, rejilla, lista virtual, estado vacío, filas de ajustes |
| `src/Alfa_Nucleo/Kit/Ventanas.lua` | Ventana flotante, área desplazable, diálogo, aviso flotante |
| `src/Alfa_Nucleo/Kit/Plantillas.lua` | Tablero, Lista con ficha, Asistente, y cómo ponerlas en una página |
| `src/Alfa_Nucleo/Kit/Estilos.lua` | Los selectores de estilo y de acento (los estilos viven en `Tokens.lua`) |
| `src/Alfa_Nucleo/Textos.lua` | El inglés de los textos del Kit (`M.EN`) |
| `motor/Alfa/Core/Reemplazos.lua` | El registro de reemplazos de ventanas del motor |
| `tools/iconos.py` (lo llama `tools/interfaz.py`) | Los íconos `ic-*`, `sec-*` y los lobos `lobo-*` |
| `src/Alfa_Pesca/Pagina.lua` | La página de referencia, hecha con el Kit |

## Reglas de diseño

1. **Guiar primero.** Cada pantalla dice qué hacer ahora: arriba, la acción recomendada en grande (una tarjeta `accion` o `estado` con su botón primario); debajo, las alternativas en tarjetas; al final, los ajustes. Nada de muros de opciones.
2. **Una rejilla de 8 px.** Los espacios salen de `K.ESP` (4, 8, 12, 16, 24, 32, 48) y las alturas de `K.ALTO`. Entre bloques de una página, 24; entre una sección y su contenido, 12; dentro de una tarjeta, 16 o 24.
3. **Todo se alinea a un mismo borde.** Las plantillas ponen el contenido en `margen` (la página: `N.MargenPagina()`, 32; una ventana: `v.margen`, 24) y lo acomodan al ancho que les das. Nunca un ancho fijo a mano: todo bloque tiene `:Acomodar(ancho) -> alto`.
4. **La forma de Alfa:** esquinas cortadas (arriba a la izquierda y abajo a la derecha) en lugar de radios, líneas de 1 px, la marca de acento tras el corte de las piezas importantes. Sin brillos, sin degradados de cielo.
5. **Colores por token, nunca a mano.** El acento (`acento`, el verde de La Jauría) marca lo principal y el progreso; la clase (`clase`, `claseTexto`) es el segundo acento. Los tonos de estado: `exito`, `aviso`, `peligro`, `neutro`.
6. **Letra Inter** en la escala de `K.TIPO`. Mayúsculas solo en sobretítulos (`mayus`) y en A L F A.
7. **Textos propios** en español, con su inglés en el `Textos.lua` del módulo (`M.EN`). Los textos del motor no se copian en ventanas nuevas: el motor da datos, las frases son de Alfa.
8. **Rendimiento:** las piezas se crean una vez y se reutilizan (rejillas y listas tienen su reserva), la lista virtual solo crea las filas a la vista, nada corre en `OnUpdate` (las animaciones son del cliente: `AnimationGroup`) y una búsqueda espera a que dejes de escribir.
9. **Sin contaminación:** ninguna pieza del Kit es un marco protegido ni usa plantillas seguras. Una acción protegida (lanzar, usar, elegir objetivo) va en el botón seguro de su módulo, nunca en el Kit.
10. **Cada pieza nace con su padre final** (`K.Seccion(pila, ...)`, `grupo:Fila({ control = function(fila) ... end })`). Reparentar deja la pieza debajo del fondo de su nuevo padre; si no hay otra, `K.Adoptar(hijo, padre)`.

## Tokens

### Medidas

| Token | Valor |
|---|---|
| `K.ESP` | `xs` 4, `s` 8, `m` 12, `base` 16, `l` 24, `xl` 32, `xxl` 48 |
| `K.CORTE` | `ventana` 10, `panel` 8, `tarjeta` 8, `control` 6, `chico` 4, `casilla` 3 (el "radio" de Alfa) |
| `K.ALTO` | `boton` 32, `botonGrande` 40, `botonChico` 24, `control` 32, `insignia` 20, `fila` 36, `filaCompacta` 28, `seccion` 32, `interruptor` 20, `pildora` 28, `cabecera` 56, `pie` 56, `compacta` 48 |
| `K.ANCHO` | `tarjeta` 256 (mínimo en rejilla), `ficha` 340, `lista` 320, `dialogo` 420, `aviso` 360, `info` 280 |

### Colores (`K.Color(token) -> r, g, b, a`)

| Token | Diseño A | Uso |
|---|---|---|
| `fondo` | `#101412` | Fondo de ventana |
| `panel` | `#18201b` | Tarjetas, paneles, menús |
| `elevado` | `#1f2a23` | Controles, lo elegido en una lista |
| `hundido` | `#0d110f` | Campos, pistas de barras y deslizadores |
| `pie` | `#141a16` | Pie de ventana |
| `linea` / `lineaFuerte` | `#26302a` / `#34423a` | Bordes de 1 px / borde de un control |
| `texto` / `textoSuave` / `textoTenue` | `#e6efe4` / `#a3b1a4` / `#8a998b` | Texto principal / descripciones / secundario |
| `acento` / `sobreAcento` | `#8be04e` / `#0d1a08` | Lo principal / texto sobre el acento |
| `clase` / `claseTexto` | color de la clase | Segundo acento / el mismo aclarado para leer |
| `exito`, `aviso`, `peligro`, `peligroRelleno` | verde, `#f0b34a`, `#e86b5a`, `#e05a4f` | Estados |
| `oro`, `mision`, `pnj`, `objeto`, `lugar`, `mazmorra`, `raro` | los del tema | Temas del juego |

Los resuelve el tema (`Alfa.Theme`): siguen el estilo (ver "Estilos"), el esquema (Grafito, Noche, Pizarra), el acento propio y la regla de legibilidad del jugador, y se repintan solos al cambiar. `titulo` es el color de los títulos: el texto en Alfa y Cristal, el oro del juego en Clásico WoW. Otras ayudas: `K.ConAlfa(token, a)`, `K.Hex(token)`, `K.Tenir(token, texto)` (`|c...|r`), `K.Clase()`, `K.Tono(tono) -> relleno, texto`.

### Estilos

Tres maneras de verse que se cambian en un clic y repintan todo, el Kit y las ventanas del motor. Una página o ventana hecha con el Kit **no tiene que hacer nada**: las piezas se adaptan solas.

| Estilo | `K.Estilo()` | `ui.skin` | Cómo se ve |
|---|---|---|---|
| Alfa | `"alfa"` | `alfa` | El diseño A: grafito, esquinas cortadas, el verde de La Jauría, letra Inter |
| Clásico WoW | `"clasico"` | `classic` | El propio juego: esquinas rectas; las ventanas con el marco y el fondo del cuadro de diálogo (`UI-DialogBox-Border`, `UI-DialogBox-Background-Dark`), los paneles y tarjetas con el de los cuadros de información (`UI-Tooltip-Border`), los botones rojos (`UI-Panel-Button-*`), la letra del juego con su sombra y los títulos en oro. Sin marca de acento ni facetas. Las texturas están verificadas en `referencia/` (`Blizzard_SharedXML/Backdrop.lua`, `SharedUIPanelTemplates.xml`) |
| Cristal | `"cristal"` | `cristal` | El diseño A con los fondos de cristal (el mundo se ve detrás), líneas claras de vidrio, una sombra suave en el texto y el acento que elijas |

```lua
K.Estilo()                -- "alfa" | "clasico" | "cristal" ; K.Clasico(), K.Cristal()
K.SetEstilo("cristal")    -- lo cambia (cada estilo recuerda su acento propio)
K.ESTILOS                 -- { id, piel, nombre, texto, icono } ; K.NombreEstilo(id), K.DatosEstilo(id)
K.ACENTOS                 -- { id, nombre, color } ; K.SetAcento(id | { r, g, b } | nil), K.AcentoActual()
K.SelectorEstilo(padre, { alCambiar = fn(id) })   -- los tres con su muestra; un clic lo aplica
K.SelectorAcento(padre, { alCambiar = fn(id) })   -- las muestras de color y el de tu clase
```

Si una pieza propia necesita otra cosa en un estilo: `K.Clasico()` al pintarla (desde `K.Pintar`, que se vuelve a llamar al cambiar). `K.SoloCasa(region)` deja transparente algo que en Clásico WoW no va. `K.Caja(..., { rol = "ventana" | "panel" | "control" })` dice qué marco del juego le toca (por omisión sale del corte: 10 ventana, 8 panel, menos control); `K.MarcoJuego(marco, "dialogo" | "info")` lo pone a mano.

### Mayúsculas

`K.Mayus(texto)`: mayúsculas que entienden las letras con acento (á é í ó ú ü ñ, à è ç ö ä, ł ś ż č ř...) y el cirílico; el chino y el coreano quedan igual, y los códigos del juego (`|c...|r`, `|T...|t`, `|H...|h`) también. `string.upper` solo cambia la A-Z ("LA JAURíA"): en el Kit se usa siempre `K.Mayus`.

### Letra (`K.TIPO`)

| Rol | Peso, tamaño | Uso |
|---|---|---|
| `portada` | semibold 26 | El título de una portada |
| `titulo` | semibold 18 | Título de ventana, de la acción recomendada |
| `subtitulo` | semibold 15 | Título de tarjeta |
| `encabezado` | semibold 13 | Encabezado de sección |
| `cuerpo` / `texto` | medium 13 / regular 13 | Filas / párrafos |
| `etiqueta`, `boton` | medium 12, semibold 12 | Controles y botones (`botonGrande` 14) |
| `nota` | regular 12 | Descripciones |
| `pequeno`, `insignia` | medium 11, semibold 11 | Secundarias, insignias |
| `mayus` | semibold 10 | Sobretítulos ("RECOMENDADO") |
| `numero` / `cifra` | semibold 13 / 22 | Contadores / números grandes |

`K.Texto(padre, rol, color)` crea un texto (una línea por omisión); `K.Escribir(fs, texto)` lo pone (y toma la letra del juego para nombres en coreano o chino); `K.Parrafo(fs, ancho, lineas)` lo envuelve y devuelve su alto; `K.Ajustar(fs, tope)`, `K.AnchoTexto(fs)`, `K.AltoTexto(fs)` miden. Respetan el tamaño de texto del jugador y su letra (Inter por omisión; la del juego en coreano y chino).

### Íconos y lobos

`K.Icono(padre, nombre, tam, color)`, `K.SetIcono(textura, nombre, color)` y `K.Lobo(variante)`. Todos son blancos y los tiñe el tema; se dibujan con `tools/iconos.py` (rejilla de 32, trazo de 2,5, puntas redondas, cajas con esquinas cortadas).

| Grupo | Nombres |
|---|---|
| Secciones (ventana principal) | `sec-hoy`, `sec-aventura`, `sec-personaje`, `sec-mundo`, `sec-oficios`, `sec-manada`, `sec-ajustes` |
| Áreas | `ic-hoy`, `ic-ruta`, `ic-huella`, `ic-guia`, `ic-talentos`, `ic-enciclopedia`, `ic-mazmorra`, `ic-curacion`, `ic-manada`, `ic-mundo`, `ic-mapa`, `ic-bolsas`, `ic-comercio`, `ic-oro`, `ic-pesca`, `ic-recoleccion`, `ic-oficios`, `ic-aventura`, `ic-personaje`, `ic-ajustes`, `ic-raros`, `ic-personajes`, `ic-misiones` |
| Acciones y estados | `ic-buscar`, `ic-flecha`, `ic-seguir`, `ic-nivel`, `ic-mas`, `ic-cerrar`, `ic-filtro`, `ic-lista`, `ic-rejilla`, `ic-aviso`, `ic-info`, `ic-exito`, `ic-alerta`, `ic-reloj` |
| Ajustes | `ic-ventana`, `ic-apariencia`, `ic-descubrir`, `ic-comodidades`, `ic-conexiones`, `ic-comunidad`, `ic-mando`, `ic-grabar`, `ic-lobo` |
| El lobo (128 px) | `lobo-normal`, `lobo-atento` (algo pide atención), `lobo-aullando` (la manada, una celebración), `lobo-dormido` (nada todavía), `lobo-vacio` (sin resultados) |

Los menús de Ajustes y las píldoras de los módulos ya usan estos íconos (`O.ICONOS` en `motor/Alfa/UI/Options.lua`; un módulo que pase un `icono = "ic-..."` en `N.Modulo` usa el suyo). Para dibujar uno nuevo: una función en `ICONOS` de `tools/iconos.py` y `.venv/Scripts/python -I tools/interfaz.py <carpeta>` (deja una hoja PNG para revisarlos).

## Componentes

Todas las piezas se repintan solas al cambiar el aspecto. Los bloques tienen `:Acomodar(ancho) -> alto`.

### Formas

```lua
local caja = K.Caja(marco, { fondo = "panel", borde = "linea", corte = K.CORTE.panel, rol = nil })
caja:Estilo({ borde = "acento", alfaBorde = 0.6 })  -- cambia y repinta; un alfa que no pasas junto a su color vuelve al del token
K.Marca(marco, K.CORTE.panel)                       -- la raya de acento de 28 x 2 tras el corte
K.Velo(marco, corte)                                -- el velo blanco al pasar el ratón
K.Faceta(padre, "acento")                           -- la faceta de 4 x 14 de las secciones
K.Linea(padre, "linea", vertical)                   -- una línea de 1 px física
```

### Botones

```lua
K.Boton(padre, L["Seguir"], function(self) ... end, { tipo = "primario", icono = "ic-seguir", tam = "grande" })
-- tipo: primario (acento) | secundario | fantasma | peligro | acento (tenue); tam: normal | grande | chico
-- b:SetTexto(t), b:SetIcono(n), b:SetTipo(t), b:SetActivo(bool), b:AnchoNatural(), b:SetAncho(w | nil)
K.BotonIcono(padre, "ic-ajustes", fn, { tipo = "secundario", ayuda = L["Ajustes"], tam = 28 })
```

### Insignia

```lua
local ch = K.Insignia(padre, L["Listo"], "exito")   -- tonos: acento, clase, exito, aviso, peligro, neutro, oro, mazmorra, raro
local ancho = ch:Set(L["En pausa"], "aviso", "ic-reloj")
```

### Controles

```lua
K.Interruptor(padre, { clave = "pesca.activo" })              -- con clave lee A.Get y guarda A.Set
K.Interruptor(padre, { valor = true, alCambiar = function(v) end })
K.Deslizador(padre, { min = 0, max = 1, paso = 0.05, clave = "pesca.volumen", formato = function(v) return floor(v * 100) .. " %" end })
K.Segmentos(padre, { estilo = "segmentos", opciones = { { valor = "todo", texto = L["Todo"] }, { valor = "obj", texto = L["Objetos"], cuenta = 120 } }, valor = "todo", alCambiar = fn })
-- estilo "pildoras" (filtros, se envuelven en varias filas) o "segmentos" (cambiar de vista); seg:Acomodar(ancho) -> alto, anchoUsado
K.Buscador(padre, { ayuda = L["Buscar objetos"], alCambiar = function(texto) end, alEnter = fn, retraso = 0.2 })
K.Desplegable(padre, { opciones = { { valor = "g", texto = L["Grafito"] } }, valor = "g", alCambiar = fn, ancho = 180 })
K.Atajo(padre, { accion = "CLICK AlfaPescaBoton:LeftButton" })  -- clic y pulsa una tecla; clic derecho la quita; atajo:Capturar()
```

Un control con `clave` se vuelve a leer solo cuando ese ajuste cambia en otra parte. Sin `clave`, el interruptor, el deslizador y el desplegable aceptan `get = fn() -> valor` y `set = fn(valor)` propios (`ctrl:Leer()` vuelve a llamar a `get`). Todos los controles tienen `:SetActivo(bool)` (las filas de ajustes lo usan).

```lua
K.Menu(dueno, { { valor = "a", texto = L["Uno"] }, { separador = true },
	{ valor = "b", texto = L["Otro"], apagada = true, motivo = L["Necesitas nivel 20"] } }, valor, alElegir)
-- un separador es una línea; una opción apagada se ve atenuada, no se elige y dice su motivo al pasar el ratón
```

### Avance

```lua
local barra = K.Progreso(padre, { alto = 6, tono = "acento" }) ; barra:Set(0.4) ; barra:Set(12, 30)
local h = K.Huellas(padre, { tam = 16, max = 10 }) ; h:Set(3, 8)   -- el rastro del lobo: hechas, la de ahora late, las que faltan
```

Las huellas son la identidad del avance (pasos de una guía, de un asistente, tramos de una ruta). Con más pasos que `max`, cada huella es una parte del camino.

### Objetos e información

```lua
local ic = K.IconoObjeto(padre, 36) ; ic:SetObjeto(6303) ; ic:SetObjeto({ id = 6303, cantidad = 4 })
-- borde de su calidad, cuadro del juego al pasar el ratón, Mayús-clic lo enlaza
K.ConInfo(marco, L["Título"], L["Texto"])   -- o una función que devuelve título, texto
K.MostrarInfo(dueno, titulo, texto) ; K.OcultarInfo()
```

### Bloques

```lua
local s = K.Seccion(pila, L["Lo pescado"], { cuenta = 12, enlace = { texto = L["Ver todo"], alClic = fn } })
local e = K.Encabezado(padre, { icono = "ic-enciclopedia", sobre = L["Objeto"], titulo = nombre, subtitulo = L["Nivel 20"] })
local t = K.Tarjeta(padre, { variante = "normal" })
t:Set({
	icono = "ic-mazmorra", tono = "acento", sobre = L["Recomendado"], titulo = ..., texto = ...,
	insignias = { { L["Nivel 18-22"], "acento" } }, valor = "12",            -- valor: a la derecha (compacta)
	estado = { texto = L["Listo"], tono = "exito" },                            -- la insignia junto al título (estado)
	progreso = { actual = 3, total = 8, texto = L["3 de 8"], huellas = true },
	accion = { texto = L["Seguir"], icono = "ic-seguir", alClic = fn }, secundaria = { texto = L["Ver"], alClic = fn },
	alClic = fn, ayuda = L["..."],
	elegida = true,                                                               -- la opción marcada de un grupo (borde de acento)
	tenir = false,                                                                -- el ícono con sus colores (hechizo u objeto del juego)
})
-- variantes: accion (la recomendada, grande: botones a la derecha si cabe), normal (rejilla),
--            compacta (una fila de 48: ícono, título, valor), estado (cómo está algo y qué hacer)
local r = K.Rejilla(padre, { min = 256, gap = 16 }) ; r:Llenar(listaDeDatos) ; r:Acomodar(ancho)
-- tantas columnas como quepan; cada fila toma el alto de su tarjeta más alta. r:SetElementos(bloques) para bloques propios.
local v = K.Vacio(padre, { lobo = "dormido", titulo = ..., texto = ..., accion = { texto = ..., alClic = fn } })
local p = K.Pila(padre, { espacio = 16 }) ; p:Agregar(bloque, { espacio = 8 }) ; p:Acomodar(ancho)
K.Mostrar(bloque, false)   -- lo oculta sin dejar hueco en su pila
```

### Lista virtual

```lua
local l = K.Lista(padre, {
	alto = 36,
	crear = function(fila) fila.Nombre = K.Texto(fila, "cuerpo", "texto") ; fila.Nombre:SetPoint("LEFT", 12, 0) end,
	pintar = function(fila, dato, i, elegida) K.Escribir(fila.Nombre, dato.nombre) end,
	alClic = function(dato, i, boton) end,
	vacio = { lobo = "vacio", titulo = L["Nada por aquí"] },
})
l:SetDatos(miles) ; l:Acomodar(ancho, alto) ; l:Elegir(1) ; l:IrA(i) ; l.alElegir = function(dato, i) end
```

Solo existen las filas que se ven (unas 15), aunque haya miles de datos.

### Filas de ajustes

```lua
local g = K.GrupoAjustes(padre, { titulo = L["Mientras pescas"] })
g:Fila({ titulo = L["Subir el sonido"], texto = L["..."], control = function(fila) return K.Interruptor(fila, { clave = "pesca.sonido" }) end })
g:Fila({ titulo = L["Volumen"], hija = true, activa = function() return N.Get("pesca", "sonido") end,
	control = function(fila) local d = K.Deslizador(fila, { ... }) d.alfaAnchoFila = 220 return d end })
g:Refrescar() ; g:Acomodar(ancho)
```

### Ventanas, diálogos y avisos

```lua
local v = K.Ventana({ nombre = "AlfaEnciclopedia", titulo = L["Enciclopedia"], subtitulo = ..., icono = "ic-enciclopedia",
	ancho = 960, alto = 620, desplazar = false, alCerrar = fn })
v:Abrir() ; v:Cerrar() ; v:Alternar() ; v.Cuerpo ; v.margen ; v:AnchoCuerpo() ; v:AltoCuerpo()
v:SetPie({ K.Boton(v, L["Cerrar"], ...), K.Boton(v, L["Seguir"], ..., { tipo = "primario" }) })
-- se mueve por su cabecera, recuerda su lugar (AlfaNucleoDB.kit.ventanas), se cierra con Esc,
-- se oculta con "Ocultar Alfa" (vive en la capa Alfa.UIParent)
K.Dialogo({ titulo = ..., texto = ..., aceptar = L["Borrar"], peligro = true, alAceptar = fn })
local a = K.Aviso({ titulo = ..., texto = ..., icono = "ic-nivel" | lobo = "aullando", tono = "acento", duracion = 6,
	accion = { texto = L["Llévame"], alClic = fn }, alCerrar = fn })   -- alCerrar: una vez, se cierre como se cierre
a:Cerrar(a.turno)   -- lo cierra desde fuera (el marco se reutiliza: con el turno, solo si sigue mostrando ese aviso)
local d = K.Desplazable(padre) ; d.Contenido ; d:SetAltoContenido(h) ; d:Acomodar(ancho, alto)
```

## Plantillas

Todas reciben `margen` y miden con el ancho que se les da. En la ventana principal:

```lua
construir = function(view)
	local t = K.Tablero(view, { margen = N.MargenPagina() })
	K.EnPagina(view, t, function() --[[ pon los datos aquí ]] end)   -- view.Refresh mide con N.AnchoPagina()
end
-- Algo cambió y la página está a la vista: N.RehacerPagina(view)  (o K.Rehacer(t))
```

En una ventana propia: `K.Tablero(v.Cuerpo, { margen = v.margen })` y `t:Acomodar(v:AnchoCuerpo())`.

### (a) Tablero: la acción grande arriba y la rejilla abajo

```
┌ [ícono] RECOMENDADO PARA TI ──────────────────────── [ Seguir ] ┐
│         Subir de nivel en Los Baldíos                 Ver la ruta │
│         Tu ruta sigue en el Cruce...  [Nivel 23-26] [14 misiones] │
│         🐾🐾🐾·····  3 de 8 tramos                                │
└───────────────────────────────────────────────────────────────────┘
▌Otras opciones ─────────────────────────────────────────────────────
┌ Hacer oro ─────┐ ┌ Profesiones ───┐ ┌ Mazmorra ──────┐
└────────────────┘ └────────────────┘ └────────────────┘
(bloques extra: ajustes, listas...)
```

```lua
local t = K.Tablero(view, { margen = 32, accion = "accion" | "estado", tituloOpciones = L["Otras opciones"], min = 256 })
t:SetAccion({ ... })             -- nil la oculta
t:SetOpciones(listaDeDatos, L["Otras opciones"])
t:AgregarBloque(K.GrupoAjustes(t.Extra, { ... }))   -- los bloques extra nacen en t.Extra
```

### (b) Lista con filtros y ficha

```
[ Buscar...                                   ] [Todo|Armas|Armaduras]
1 234 resultados
┌ lista virtual ─────────────────┐ ┌ ficha ───────────────────┐
│ ▌Objeto elegido                │ │ [ícono] Nombre           │
│  Otro objeto                   │ │ ▌Dónde conseguirlo       │
│  ...                           │ │ [Guíame]                 │
└────────────────────────────────┘ └──────────────────────────┘
```

```lua
local lf = K.ListaFicha(view, {
	margen = N.MargenPagina(), anchoFicha = 340, alto = 36,
	buscador = { ayuda = L["Buscar objetos"], alCambiar = function(texto) filtrar(texto) end },
	segmentos = { opciones = { ... }, valor = "todo", alCambiar = fn },
	crear = fn, pintar = fn,
	ficha = function(pila, dato) -- crea sus bloques la primera vez (en `pila`) y los actualiza después
		if not pila.enc then pila.enc = pila:Agregar(K.Encabezado(pila, {})) end
		pila.enc:Set({ icono = "ic-bolsas", titulo = dato.nombre })
	end,
})
lf:SetDatos(lista) ; lf:Acomodar(ancho, alto)   -- en la página: K.EnPagina usa N.AltoPagina()
```

Bajo 680 de ancho, la ficha baja debajo de la lista; con poco ancho, los segmentos bajan a su propia fila.

### (c) Asistente por pasos

```lua
local a = K.Asistente(v.Cuerpo, { margen = v.margen, textoTerminar = L["Listo"], alTerminar = fn, pasos = {
	{ titulo = L["Elige un preajuste"], texto = L["..."], construir = function(pila, asistente) ... end,
	  listo = function() return elegido ~= nil end, alMostrar = fn, alSalir = fn },
	...
} })
a:Acomodar(v:AnchoCuerpo(), v:AltoCuerpo())   -- con alto, el pie (Atrás / Siguiente) queda abajo
```

Arriba van las huellas (un paso por huella), "PASO 2 DE 3", el título y la explicación del paso.

## Página de referencia: Pesca

`src/Alfa_Pesca/Pagina.lua` es un Tablero con la tarjeta `estado` arriba:

1. **Estado y acción:** listo, pescando, sin caña, sin tecla, apagada, en pausa, con tu habilidad de pesca como barra y, cuando algo falta, el botón que lo arregla ("Encender la pesca", "Elegir mi tecla").
2. **Esta sesión:** capturas, tiempo con la caña en el agua y habilidad subida, en tarjetas compactas.
3. **Lo pescado:** una rejilla de objetos con su calidad (los 8 primeros y "Ver todo"), o el lobo dormido si aún no hay nada.
4. **Ajustes:** tres grupos de filas, con su control a la derecha y las hijas atenuadas cuando su opción de arriba está apagada.

`M.alCambiar` (lo llama `Pesca.lua` cuando algo cambia) hace `N.RehacerPagina(view)`.

## Reemplazos: tu ventana en lugar de la del motor

```lua
N.Reemplazar("SHOW_PICKER", function(pedido)
	if pedido.alternar and miVentana:IsShown() then miVentana:Cerrar() return end
	miVentana:Abrir(pedido.pestanaNueva)
end, function() return miVentana:IsShown() end)
-- N.Reemplazar(clave, nil) devuelve la ventana al motor. -> true | false, por qué
```

- Desde que un módulo registra su reemplazo, **la ventana del motor no se muestra**: el motor llama a tu función y sigue haciendo su trabajo por dentro (guías, pasos, navegación, lo ya visto, los avisos que esperan turno).
- **Sin reemplazo, se usa la del motor** como respaldo. Si tu función falla (un error de Lua), el error se reporta y esa vez se abre la del motor: nada se queda sin abrir.
- `visible()` (opcional) dice si tu ventana está a la vista: el motor lo consulta donde miraba la suya (`GE.IsShown`, `RC.IsShown`, `WEL.IsShown`, `WN.IsShown`; la bienvenida y las novedades esperan a que se cierre la elección de camino).
- Las secciones del centro del motor sin ventana propia se siguen abriendo en el centro del motor aunque el selector tenga la suya (`UI.AbrirCentro(seccion)`), y en ese centro, el botón de una sección reemplazada lleva a tu ventana.
- Mensajes nuevos: `ALFA_REEMPLAZO(clave, activo)` y `ROUTE_CHOICE_HIDDEN` (tu elección de camino se cerró).

Cómo funciona: `ns.Fire` desvía los mensajes que abren ventanas a tu función antes que a los oyentes del motor (parche de `Core/Init.lua`); las funciones directas preguntan `ns.Reemplazos.Llamar(clave, pedido)` antes de dibujar (en `motor/Alfa/UI/*.lua`, que son nuestros, y con parches de `tools/parches.py` en `ClassToast`, `GuideEnd`, `RouteChoice`, `WhileHere`, `LevelTip`, `ClassCard`, `Talents/View`, `Rares/View`, `Alts/View` e `Import`).

### Tabla de ventanas y avisos del motor

| Ventana o aviso | Archivo del motor | Qué la abre | Clave | El pedido trae |
|---|---|---|---|---|
| Selector de guías (el centro en Guías) | `UI/Picker.lua` | `SHOW_PICKER`, `TOGGLE_PICKER`, `UI.ShowPicker(opts)`, `UI.Picker.ShowQuest(id)`, el botón Guías del centro; lo usan `/alfa guides`, el menú del minimapa, la ventana de guía, la bienvenida, Hoy y Rutas | `SHOW_PICKER` | `pestanaNueva`, `opciones`, `alternar` (TOGGLE_PICKER), `mision` (ShowQuest) |
| Buscador | `UI/Lookup.lua` | `SHOW_LOOKUP(q, tipo, id)`, `UI.ShowLookup({ query, kind, id })`, `UI.ToggleLookup()`, `Lookup.Show(q, tipo, id)` (con el buscador encendido), su botón del centro | `SHOW_LOOKUP` | `buscar`, `tipo`, `id`, `alternar` |
| "Guíame" de un objeto | `Lookup/Guide.lua` | `Lookup.Guide(tipo, id)` arma y abre la guía (no es una ventana; si no puede, llama a `Lookup.Show`) | ninguna: úsala desde tu ventana | — |
| Diario de mazmorras | `UI/Dungeons.lua` | `SHOW_DUNGEON(clave)`, `Dungeons.Open(clave)` (con mazmorras encendidas), `UI.DungeonsSection.Show(clave)`, su botón del centro | `SHOW_DUNGEON` | `mazmorra` |
| Talentos (sección del centro) | `Talents/View.lua` | `SHOW_TALENTS` (`Alfa.Talents.Show()`), su botón | `SHOW_TALENTS` | — |
| Raros (sección) | `Rares/View.lua` | `SHOW_RARES(tipo, id)` (`Alfa.Rares.Show`), su botón | `SHOW_RARES` | `tipo` (`"rare"`, `"treasure"`), `id` |
| Personajes (sección) | `Alts/View.lua` | `SHOW_ALTS` (`/alfa alts`), su botón | `SHOW_ALTS` | — |
| Importar (sección) | `UI/Import.lua` | `SHOW_IMPORT`, su botón | `SHOW_IMPORT` | — |
| Ventana de guía | `UI/GuideFrame.lua` | el ajuste `ui.shown` (`TOGGLE_FRAME`, `SHOW_FRAME`, `/alfa guia`, la tecla, el menú del minimapa, "Tu guía", elegir una guía) y sus reglas (combate, instancias): `GF.ApplyVisibility()` | `GUIDE_FRAME` | `mostrar`, `combate`, `instancia` |
| Tarjeta de misión de clase (en la ventana de guía) | `UI/ClassCard.lua` | `CC.Fill(guía, paso, vista)` en cada dibujo de la ventana de guía | `CLASS_CARD` | `modelo` (`UI.ClassCard.Modelo`), `guia`, `indice`, `vista` |
| Aviso de misión de clase | `UI/ClassToast.lua` | subir de nivel, entrar, `/alfa classtoast` → `CT.Show(q)` → `CT.ShowCard(m)` | `CLASS_TOAST` (o `HEADS_UP`) | ver "Avisos de tarjeta" |
| Hechizos nuevos y rangos viejos | `UI/SpellCards.lua` | `LEVELUP_SPELLS`, `OLD_RANKS` → `CT.ShowCard` | `SPELL_CARDS` (o `HEADS_UP`) | ídem (`modelo.kind` = `"levelUp"` / `"oldRanks"`) |
| Mazmorra abierta | `UI/DungeonToast.lua` | subir de nivel, entrar, entregar una misión, `/alfa dungeontoast` → `CT.ShowCard` | `DUNGEON_TOAST` (o `HEADS_UP`) | ídem (`modelo.dungeon`) |
| Versión nueva | `UI/UpdateCard.lua` | `UPDATE_KNOWN`, entrar → `CT.ShowCard` | `UPDATE_CARD` (o `HEADS_UP`) | ídem (`modelo.update`) |
| Fin de una guía | `UI/GuideEnd.lua` | `GUIDE_END` → `GE.Show(info)` | `GUIDE_END` | `accion` (`"mostrar"`/`"ocultar"`), `info`, `modelo` (`GE.Model`), `Empezar()`, `Despues()`, `Cerrar()` |
| Elegir el camino | `UI/RouteChoice.lua` | `ROUTE_CHOICE` → `RC.Show(id)`, `UI.ShowRouteChoice(id)` | `ROUTE_CHOICE` | `accion`, `desde`, `eleccion` (`Engine.GetRouteChoice`), `solo`, `Elegir(id)`, `Despues()` |
| Panel de niveles de una ruta | `UI/LevelTip.lua` | pasar el ratón por su ficha: `LevelTip.Show(chip)` / `Hide()` | `LEVEL_TIP` | `accion`, `chip`, `resumen`, `textos` |
| "Mientras estás aquí" (con la ventana de guía oculta) | `UI/WhileHere.lua` | `WHILE_HERE_CHANGED` → `T.Show(v)` / `T.Hide()` | `WHILE_HERE` | `accion` (`"mostrar"`, `"actualizar"`, `"ocultar"`), `linea`, `texto`, `Guiar()`, `Descartar()` |
| Bienvenida | `UI/Welcome.lua` | entrar con un personaje nuevo, `SHOW_WELCOME`, `UI.Welcome.Show()` | `SHOW_WELCOME` | `motivo` (`"login"`, `"asked"`), `solo`, `Listo()` (avisa `WELCOME_CLOSED`: llámalo al cerrar) |
| Novedades | `UI/WhatsNew.lua` | entrar con una versión nueva, `SHOW_WHATSNEW`, `UI.WhatsNew.Show()` | `SHOW_WHATSNEW` | `motivo`, `version`, `notas` (`UI.WhatsNew.NOTES`) |

### Avisos de tarjeta (`HEADS_UP` y sus claves propias)

Los cuatro avisos pasan por un mismo punto (`CT.ShowCard(m)`); la clave propia de su tipo manda y, si no hay, `HEADS_UP`. El motor sigue decidiendo cuándo y cuál (uno a la vez; los demás esperan a que se cierre el de ahora).

```lua
N.Reemplazar("HEADS_UP", function(p)
	if p.accion == "ocultar" then miAviso:Hide() return end
	-- p.tipo: CLASS_TOAST | SPELL_CARDS | DUNGEON_TOAST | UPDATE_CARD ; p.modelo: lo que dice
	-- (head, title, giver, route, badge, icon, class, art, spells, act/more/off/later = { label, run }, hideAfter, quiet, guideId)
	-- botones: p.Actuar(), p.Mas(), p.Apagar(), p.Despues(), p.Abrir() (guía en pestaña nueva), p.Mostrarme() (flecha), p.Cerrar()
end)
```

Al cerrarlo el jugador, llama a `p.Cerrar()` (el motor deja pasar el siguiente); con `modelo.hideAfter`, ciérralo a esos segundos (no con el ratón encima).

### Al reemplazar la ventana de guía

La del motor deja de dibujarse (solo se dibuja visible). Tu rastreador escucha `GUIDE_CHANGED`, `STEP_CHANGED`, `STEP_UPDATED`, `WAYPOINT_CHANGED`, `WHILE_HERE_CHANGED` y `QUEST_TIMER`, y lee `Alfa.Engine` (`GetGuide`, `GetStepIndex`, `GetWhileHereList`...) y las ayudas de `Alfa.UI` (`StepSummary`, `GoalText`, `GoalProgress`, `GoalBar`...). La tarjeta de misión de clase se lee con `Alfa.UI.ClassCard.Modelo(guía, paso, vista)`. Reemplaza también `HEADS_UP` y `WHILE_HERE`: esos avisos vivían sobre la ventana de guía.

## Cosas que no hacemos

- **Rieles ni barras laterales:** la navegación va arriba (secciones y píldoras), nunca en una columna a un lado.
- **Estrellas, cielo nocturno, halos, brillos** ni degradados de fondo. El lobo y las huellas son la identidad.
- **Textos o mensajes copiados del motor** en ventanas nuevas: escribe los tuyos, en español, con su inglés en `M.EN`. El motor da datos, no frases.
- **Muros de opciones:** la acción recomendada va primero y en grande; los ajustes, al final o en Ajustes.
- **Derivar de `Widgets.lua`** (`W.*`) en ventanas o páginas nuevas: usa el Kit.
- **Radios redondos, sombras de colores, mayúsculas espaciadas** (salvo A L F A) o títulos en mayúsculas (solo el sobretítulo `mayus`).
- **Íconos del juego como adorno:** los íconos de Alfa (`ic-*`) para la interfaz; los del juego solo para objetos, hechizos y monturas.
- **Colores a mano** (`SetTextColor(1, 0.8, 0)`): siempre tokens.
- **Marcos protegidos o plantillas seguras** en el Kit, `OnUpdate` permanentes, o crear marcos en cada dibujo (reutiliza).
- **Mostrar la ventana del motor al lado de la tuya:** registra el reemplazo.
- **Nombrar otros addons** en código o textos (salvo licencias y `Compat.lua`).

## Comprobar

```bash
python -I tools/build.py
.venv/Scripts/python -I tools/revisar.py
.venv/Scripts/python -I tools/humo.py
```

El banco (`tools/banco/LEEME.md`) carga el motor de verdad sobre un cliente simulado y dibuja maquetas PNG del acomodo real: sirve para ver una ventana del Kit y para probar reemplazos (registrar uno, disparar el mensaje y revisar que la ventana del motor siga oculta). Lo que el simulador no imita (medidas exactas del texto, recortes, contaminación) se revisa en el juego.
