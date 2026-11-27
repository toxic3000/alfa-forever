-- Alfa - Kit: tokens del diseño A (toxic3000 / La Jauría). GPL-3.0.
--
-- El Kit de Alfa son las piezas propias de la interfaz (docs/KIT.md): se
-- escribió desde cero para Alfa 1.0 y no deriva de los Widgets del motor.
--   local K = AlfaNucleo.Kit
-- Este archivo: medidas (rejilla de 8 px), cortes, colores, letra, íconos y
-- el repintado cuando cambia el aspecto (Ajustes > Apariencia).

local _, N = ...
local A = N.A
local T = A and A.Theme

local K = {}
N.Kit = K
K.L = N.Textos(N.EN)

local type, pairs, pcall, floor, ceil, max, min = type, pairs, pcall, math.floor, math.ceil, math.max, math.min

---------------------------------------------------------------------------
-- Medidas: todo cae en una rejilla de 8 px (4 para los ajustes finos).
---------------------------------------------------------------------------
K.ESP = { xs = 4, s = 8, m = 12, base = 16, l = 24, xl = 32, xxl = 48 }

-- Las esquinas cortadas del diseño A (arriba a la izquierda y abajo a la
-- derecha). Alfa no usa radios redondos: el "radio" de cada pieza es su corte.
-- 1.2.5: más finos (antes 10, 8, 8, 6, 4, 3), igual que el motor (Theme.CUT).
K.CORTE = { ventana = 8, panel = 6, tarjeta = 6, control = 4, chico = 4, casilla = 3 }

-- Alturas fijas de las piezas, para que todo alinee en la rejilla.
K.ALTO = {
	boton = 32, botonGrande = 40, botonChico = 24, control = 32, insignia = 20,
	fila = 36, filaCompacta = 28, seccion = 32, interruptor = 20, pildora = 28,
	cabecera = 56, pie = 56, compacta = 48,
}

-- Anchos de referencia.
K.ANCHO = { tarjeta = 256, ficha = 340, lista = 320, dialogo = 420, aviso = 360, info = 280 }

-- 1.3.9 (mejora 56): la tabla de medidas de Alfa, en un solo lugar. Cada
-- ventana, página y pieza usa estas (y la prueba de la 1.3.9 las revisa en
-- todas las páginas). Lo que no está aquí sale de K.ESP, K.ALTO y K.TIPO.
--   pagina      margen a los lados de una página de la ventana de Alfa
--               (el del marco del motor, N.MargenPagina) y entre sus bloques
--   ventana     margen dentro de una ventana propia (K.Ventana) y su pie
--   tarjeta     relleno de cada variante de tarjeta (Bloques.lua, VARIANTE)
--   rejilla     espacio entre tarjetas y el ancho mínimo de una columna
--   fila        alto mínimo de una fila de ajustes y su relleno
--   boton       los tres altos de botón y el espacio entre botones juntos
--   tiposBoton  los únicos estilos de botón: principal (primario), secundario,
--               fantasma (el de texto) y peligro; «acento» queda para un
--               botón elegido de un grupo. El principal va a la derecha.
K.MEDIDA = {
	pagina = { margen = 32, arriba = 16, entreBloques = 24, entreSecciones = 32 },
	ventana = { margen = 24, pie = 56 },
	tarjeta = { accion = 24, estado = 24, normal = 16, compacta = 12 },
	rejilla = { espacio = 16, espacioChico = 12, columna = 256 },
	fila = { alto = 48, relleno = 12, compacta = 28, lista = 36 },
	boton = { chico = 24, normal = 32, grande = 40, entre = 8 },
	tiposBoton = { primario = true, secundario = true, fantasma = true, peligro = true, acento = true },
}

---------------------------------------------------------------------------
-- Colores: los nombres del Kit y su token del tema. El tema resuelve el
-- esquema (Grafito, Noche, Pizarra), el acento propio y la legibilidad; sin
-- tema (pruebas) se usan los valores del diseño A.
---------------------------------------------------------------------------
local function hex(s, a)
	local r, g, b = s:match("(%x%x)(%x%x)(%x%x)")
	return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, a or 1 }
end

local DEL_TEMA = {
	fondo = "bg", panel = "panel", elevado = "panelAlt", hundido = "sidebar", pie = "footer",
	linea = "line", lineaFuerte = "lineStrong",
	texto = "text", textoSuave = "textDim", textoTenue = "textMuted",
	acento = "accent", sobreAcento = "onAccent",
	exito = "success", aviso = "warning", peligro = "danger", peligroRelleno = "dangerFill",
	oro = "gold", mision = "quest", pnj = "npc", objeto = "item", lugar = "place",
	mazmorra = "dungeon", raro = "rare", clase = "class", claseTexto = "classText", velo = "scrim",
	titulo = "title", -- los títulos: el texto en Alfa y Cristal, el oro del juego en Clásico WoW
	-- 1.3.0: los perjuicios por su tipo (K.ColorPerjuicio), con su paleta para daltonismo
	debuffMagia = "debuffMagic", debuffMaldicion = "debuffCurse", debuffEnfermedad = "debuffDisease",
	debuffVeneno = "debuffPoison", debuffFisico = "debuffNone",
}
K.DEL_TEMA = DEL_TEMA

local DISENO_A = {
	fondo = hex("101412", 0.97), panel = hex("18201b", 0.98), elevado = hex("1f2a23"), hundido = hex("0d110f"),
	pie = hex("141a16"), linea = hex("26302a"), lineaFuerte = hex("34423a"),
	texto = hex("e6efe4"), textoSuave = hex("a3b1a4"), textoTenue = hex("8a998b"),
	acento = hex("8be04e"), sobreAcento = hex("0d1a08"),
	exito = { 0.42, 0.85, 0.6, 1 }, aviso = hex("f0b34a"), peligro = hex("e86b5a"), peligroRelleno = hex("e05a4f"),
	oro = hex("f2d06b"), mision = hex("f2d06b"), pnj = { 0.58, 0.79, 1, 1 }, objeto = { 0.78, 0.68, 1, 1 },
	lugar = { 0.96, 0.68, 0.52, 1 }, mazmorra = { 0.64, 0.52, 1, 1 }, raro = { 1, 0.5, 0.32, 1 },
	clase = hex("8be04e"), claseTexto = hex("8be04e"), velo = hex("0b0e0c"), titulo = hex("e6efe4"),
	debuffMagia = { 0.2, 0.6, 1, 1 }, debuffMaldicion = { 0.6, 0, 1, 1 }, debuffEnfermedad = { 0.6, 0.4, 0, 1 },
	debuffVeneno = { 0, 0.6, 0, 1 }, debuffFisico = { 0.8, 0, 0, 1 },
}
K.DISENO_A = DISENO_A

-- token (nombre del Kit, del tema, o { r, g, b, a }) -> r, g, b, a
function K.Color(token)
	if type(token) == "table" then return token[1] or 1, token[2] or 1, token[3] or 1, token[4] or 1 end
	if T and T.Color then
		local r, g, b, a = T.Color(DEL_TEMA[token] or token)
		if type(r) == "number" then return r, g, b, a or 1 end
	end
	local c = DISENO_A[token] or DISENO_A.texto
	return c[1], c[2], c[3], c[4] or 1
end

-- El mismo color con otra opacidad.
function K.ConAlfa(token, alfa)
	local r, g, b = K.Color(token)
	return r, g, b, alfa
end

-- "ffrrggbb" para |c...|r.
function K.Hex(token)
	local r, g, b = K.Color(token)
	return ("ff%02x%02x%02x"):format(floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

---------------------------------------------------------------------------
-- 1.3.0: accesibilidad (Ajustes > Estilo y sonido). Los ajustes viven en
-- "nucleo.*" y el tema los lee (motor/Alfa/Theme/Theme.lua):
--   nucleo.daltonico    bien, aviso, peligro y perjuicios en una paleta que
--                       no depende del rojo contra el verde (Okabe e Ito)
--   nucleo.letraGrande  todo el texto de Alfa un escalón más grande (Theme.Escalon)
-- Los módulos leen los colores con los tokens de siempre (exito, aviso,
-- peligro, peligroRelleno) y los de los perjuicios con K.ColorPerjuicio.
---------------------------------------------------------------------------
if A and A.RegisterDefaults then
	A.RegisterDefaults("nucleo", { daltonico = false, letraGrande = false, ligero = false })
end

function K.Daltonico() return A and A.Get and A.Get("nucleo.daltonico") and true or false end
function K.LetraGrande() return A and A.Get and A.Get("nucleo.letraGrande") and true or false end

---------------------------------------------------------------------------
-- 1.4.0 (66): «Alto contraste» (nucleo.altoContraste, apagado de fábrica).
-- Un retoque de la paleta del tema (Theme.Retoque, motor/Alfa/Theme): el
-- texto blanco puro, los textos secundarios más claros, los fondos opacos y
-- un poco más oscuros (también en Cristal), las líneas y bordes visibles y
-- el acento con 7:1 sobre cualquier fondo. Vale en los 3 estilos y se suma a
-- «Colores para daltonismo» y «Letra más grande».
---------------------------------------------------------------------------
if A and A.RegisterDefaults then A.RegisterDefaults("nucleo", { altoContraste = false }) end
function K.AltoContraste() return A and A.Get and A.Get("nucleo.altoContraste") and true or false end

-- c llevado hacia el blanco (o el negro, sobre fondos claros) hasta que se
-- lea con `minimo` sobre cada fondo. -> { r, g, b, 1 }
function K.Legible(c, fondos, minimo)
	local Th = T
	local x = { c[1], c[2], c[3], 1 }
	if not (Th and Th.Contrast) then return x end
	local function basta(y)
		for _, f in ipairs(fondos) do
			if type(f) == "table" and Th.Contrast(y, f) < minimo then return false end
		end
		return true
	end
	if basta(x) then return x end
	local claro = true
	local f1 = fondos[1]
	if type(f1) == "table" and Th.Luminance and Th.Luminance(f1[1], f1[2], f1[3]) > 0.4 then claro = false end
	local d = claro and 1 or 0
	-- Primero más brillo con el mismo tono (un rojo sigue rojo, no rosa);
	-- luego, si hace falta, hacia el blanco.
	if claro then
		local m = math.max(c[1], c[2], c[3], 0.01)
		for i = 1, 10 do
			local k = 1 + (1 / m - 1) * i / 10
			local y = { math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k), 1 }
			if basta(y) then return y end
		end
		x = { c[1] / m, c[2] / m, c[3] / m, 1 }
		c = x
	end
	for i = 1, 20 do
		local t = i * 0.05
		local y = { c[1] + (d - c[1]) * t, c[2] + (d - c[2]) * t, c[3] + (d - c[3]) * t, 1 }
		if basta(y) then return y end
	end
	return { d, d, d, 1 }
end

local FONDOS_CONTRASTE = { "bg", "panel", "panelAlt", "sidebar", "footer" }
if T and T.Retoque then
	T.Retoque(function(out)
		if not K.AltoContraste() then return end
		local claro = T.Luminance and out.bg and T.Luminance(out.bg[1], out.bg[2], out.bg[3]) > 0.4
		for _, n in ipairs(FONDOS_CONTRASTE) do
			local g = out[n]
			if type(g) == "table" then
				local k = claro and 1 or 0.7
				out[n] = claro and { g[1], g[2], g[3], 1 } or { g[1] * k, g[2] * k, g[3] * k, 1 }
			end
		end
		local fondos = {}
		for _, n in ipairs(FONDOS_CONTRASTE) do fondos[#fondos + 1] = out[n] end
		out.text = claro and { 0, 0, 0, 1 } or { 1, 1, 1, 1 }
		if out.textDim then out.textDim = K.Legible(out.textDim, fondos, 9) end
		if out.textMuted then out.textMuted = K.Legible(out.textMuted, fondos, 7) end
		if out.accent then
			out.accent = K.Legible(out.accent, fondos, 7)
			local r, g, b = out.accent[1], out.accent[2], out.accent[3]
			out.accentLine, out.padSelect, out.chipAccent = { r, g, b, 0.6 }, { r, g, b, 0.22 }, { r, g, b, 0.28 }
			local tinta = { 0.04, 0.04, 0.04, 1 }
			out.onAccent = (T.Contrast(tinta, out.accent) >= T.Contrast(out.text, out.accent)) and tinta or { out.text[1], out.text[2], out.text[3], 1 }
		end
		local t = out.text
		out.line = { t[1], t[2], t[3], 0.35 }
		out.lineStrong = { t[1], t[2], t[3], 0.6 }
		out.border, out.divider = { t[1], t[2], t[3], 0.35 }, { t[1], t[2], t[3], 0.35 }
		out.windowBorder = { t[1], t[2], t[3], 0.85 }
		for _, n in ipairs({ "success", "warning", "danger", "gold", "quest", "npc", "item", "place", "rare" }) do
			if type(out[n]) == "table" then out[n] = K.Legible(out[n], fondos, 7) end
		end
	end)
end

-- Los tipos de perjuicio del juego ("Magic", "Curse", "Disease", "Poison", "" o
-- nil) y sus nombres en español, a su token del Kit.
local PERJUICIO = {
	Magic = "debuffMagia", Curse = "debuffMaldicion", Disease = "debuffEnfermedad", Poison = "debuffVeneno",
	magia = "debuffMagia", maldicion = "debuffMaldicion", enfermedad = "debuffEnfermedad", veneno = "debuffVeneno",
}
K.PERJUICIO = PERJUICIO
function K.TokenPerjuicio(tipo)
	if issecretvalue and issecretvalue(tipo) then return "debuffFisico" end
	return PERJUICIO[tipo or ""] or "debuffFisico"
end
-- -> r, g, b, a del color de un tipo de perjuicio (sigue el modo para daltonismo)
function K.ColorPerjuicio(tipo) return K.Color(K.TokenPerjuicio(tipo)) end

-- Texto en un color: K.Tenir("acento", "Seguir").
function K.Tenir(token, texto) return "|c" .. K.Hex(token) .. tostring(texto) .. "|r" end

-- La clase del jugador (el segundo acento): { archivo, nombre, r, g, b, hex, texto = { r, g, b } }.
function K.Clase()
	if T and T.Clase then
		local ok, c = pcall(T.Clase)
		if ok and type(c) == "table" and type(c.r) == "number" then return c end
	end
	local r, g, b = K.Color("acento")
	return { archivo = nil, nombre = "", r = r, g = g, b = b, hex = K.Hex("acento"), texto = { r, g, b } }
end

-- Los tonos de las piezas (insignias, tarjetas de estado, avisos): su color
-- de relleno y el de su texto.
K.TONOS = {
	acento = { "acento", "acento" }, clase = { "clase", "claseTexto" }, exito = { "exito", "exito" },
	aviso = { "aviso", "aviso" }, peligro = { "peligroRelleno", "peligro" }, neutro = { "textoTenue", "textoSuave" },
	oro = { "oro", "oro" }, mazmorra = { "mazmorra", "mazmorra" }, raro = { "raro", "raro" },
}
function K.Tono(tono)
	local t = K.TONOS[tono or "neutro"] or K.TONOS.neutro
	return t[1], t[2]
end

---------------------------------------------------------------------------
-- Repintado: cada pieza registra cómo se pinta; un cambio de aspecto (tema,
-- acento, letra, tamaño de texto) las repinta todas.
---------------------------------------------------------------------------
local pintores = setmetatable({}, { __mode = "k" })

function K.Pintar(obj, fn)
	pintores[obj] = fn
	fn(obj)
	return obj
end

-- Lo que se rehace antes de repintar (las formas que cambian de corte con el estilo).
local antes = {}
function K.AntesDeRepintar(fn) antes[#antes + 1] = fn end

-- 1.3.6: la generación del pintado. Las piezas que no se repintan si nada
-- cambió (Caja:Estilo, las tarjetas, el interruptor, las páginas del Kit)
-- recuerdan con qué generación se pintaron: al subirla aquí, todas se pintan
-- de nuevo aunque sus datos sean los mismos (el token ya da otro color).
K.genPintado = 0

function K.Repintar()
	K.genPintado = K.genPintado + 1
	for i = 1, #antes do
		local ok, err = pcall(antes[i])
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
	for obj, fn in pairs(pintores) do
		local ok, err = pcall(fn, obj)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
	if K.alRepintar then
		for i = 1, #K.alRepintar do pcall(K.alRepintar[i]) end
	end
end

-- Algo que se rehace tras un cambio de aspecto (una plantilla que mide de nuevo).
function K.AlRepintar(fn)
	K.alRepintar = K.alRepintar or {}
	K.alRepintar[#K.alRepintar + 1] = fn
end

if T and type(T.OnChanged) == "function" then T.OnChanged(K.Repintar) end

---------------------------------------------------------------------------
-- Estilos (docs/KIT.md, "Estilos"): tres maneras de verse que se cambian en
-- un clic y lo repintan todo, el Kit y las ventanas del motor.
--   alfa     el diseño A: grafito, esquinas cortadas, el verde de La Jauría
--   clasico  el propio juego: los marcos y fondos del cuadro de diálogo y de
--            los cuadros de información, los botones rojos y la letra del
--            juego con sus títulos en oro (la piel "classic" del motor)
--   cristal  el diseño A con fondos de cristal (se ve el mundo detrás) y el
--            acento que elijas (K.ACENTOS)
-- Cada estilo recuerda su acento: al volver a uno, vuelve el suyo.
---------------------------------------------------------------------------
K.ESTILOS = {
	{ id = "alfa", piel = "alfa", nombre = "Alfa", icono = "ic-lobo",
		texto = "Grafito con esquinas cortadas y el verde de La Jauría. El de siempre." },
	{ id = "clasico", piel = "classic", nombre = "Clásico WoW", icono = "ic-ventana",
		texto = "Los marcos, fondos, botones y letras del propio juego, con títulos en oro." },
	{ id = "cristal", piel = "cristal", nombre = "Cristal", icono = "ic-apariencia",
		texto = "Fondos transparentes para ver el mundo detrás y el color de acento que elijas." },
	-- 1.3.0: la casa con su propio esquema y acento (Theme.ESTILOS_CASA)
	{ id = "nocturno", piel = "nocturno", nombre = "La Jauría nocturno", icono = "ic-lobo", acento = "plata",
		texto = "Azul de medianoche casi negro con detalles en plata de luna. Para cazar de noche." },
	{ id = "fogata", piel = "fogata", nombre = "Fogata", icono = "ic-lobo", acento = "brasa",
		texto = "Carbón cálido y el naranja de las brasas, como la manada junto al fuego." },
}
local ESTILO = {}
for _, e in ipairs(K.ESTILOS) do ESTILO[e.id] = e end

-- -> "alfa" | "clasico" | "cristal" | "nocturno" | "fogata"
-- 1.3.6: K.Estilo se lee muchísimo (cada pintado, cada corte). El estilo
-- sale solo de "ui.skin" (Theme.EstiloKey), así que se recuerda por el valor
-- crudo de ese ajuste: se sigue leyendo el ajuste (una lectura), pero sin
-- pcall ni Theme.EstiloKey cada vez. No se limpia con SETTING_CHANGED porque
-- el tema repinta (y lee el estilo) antes de que el Kit oiga ese aviso; con
-- la clave cruda nunca queda viejo, ni al importar un perfil o un respaldo.
local estiloPorPiel = {}
local SIN_PIEL = {} -- la clave de "ui.skin" sin valor (nil no puede ser clave)
local function estiloDelTema()
	local ok, v = pcall(T.EstiloKey)
	if ok and ESTILO[v] then return v end
	return "alfa"
end
function K.Estilo()
	if not (T and T.EstiloKey) then return "alfa" end
	-- Las pruebas que enseñan las pieles ocultas cambian la respuesta: sin memoria.
	if T._testShowHidden or not (A and A.Get) then return estiloDelTema() end
	local crudo = A.Get("ui.skin")
	if crudo == nil then crudo = SIN_PIEL
	elseif type(crudo) ~= "string" then return estiloDelTema() end
	local v = estiloPorPiel[crudo]
	if not v then
		v = estiloDelTema()
		estiloPorPiel[crudo] = v
	end
	return v
end
-- 1.3.6: un cambio de tema vacía la memoria (por si el motor cambia las pieles).
if T and type(T.OnChanged) == "function" then T.OnChanged(function() for k in pairs(estiloPorPiel) do estiloPorPiel[k] = nil end end) end
function K.Clasico() return K.Estilo() == "clasico" end
function K.Cristal() return K.Estilo() == "cristal" end
-- 1.3.0: si en este estilo se elige el acento (Cristal, nocturno, Fogata).
function K.EligeAcento() local e = K.Estilo() return e ~= "alfa" and e ~= "clasico" end

function K.DatosEstilo(id) return ESTILO[id or K.Estilo()] end
function K.NombreEstilo(id)
	local e = ESTILO[id]
	return e and K.L[e.nombre] or nil
end

local function memoria()
	local d = N.Datos and N.Datos("kit") or {}
	d.acentos = type(d.acentos) == "table" and d.acentos or {}
	return d.acentos
end

local function esColor(c) return type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number" end

-- Cambia de estilo. El acento propio del estilo que dejas se guarda y vuelve
-- el del estilo nuevo (nada si sigues el color de tu clase).
function K.SetEstilo(id)
	local e = ESTILO[id]
	if not (e and A and A.Set and A.Get) then return false end
	local antes = K.Estilo()
	if antes == id and A.Get("ui.skin") == e.piel then return true end
	if not A.Get("ui.classAccent") then
		local mem = memoria()
		local propio = A.Get("ui.accent")
		mem[antes] = esColor(propio) and { propio[1], propio[2], propio[3] } or false
		local nuevo = mem[id]
		if esColor(nuevo) then
			A.Set("ui.accent", { nuevo[1], nuevo[2], nuevo[3] })
		elseif esColor(propio) then
			A.Set("ui.accent", nil)
		end
	end
	A.Set("ui.skin", e.piel)
	return true
end

-- Los acentos para elegir (sobre todo en Cristal). El primero es el verde de
-- La Jauría: el acento de Alfa y de Cristal por omisión.
K.ACENTOS = {
	{ id = "jauria", nombre = "Verde de La Jauría", color = hex("8be04e") },
	{ id = "hielo", nombre = "Hielo", color = hex("6fd3ff") },
	{ id = "lavanda", nombre = "Lavanda", color = hex("b39cff") },
	{ id = "ambar", nombre = "Ámbar", color = hex("f0b34a") },
	{ id = "coral", nombre = "Coral", color = hex("ff7a68") },
	{ id = "rosa", nombre = "Rosa", color = hex("f590c8") },
	{ id = "luna", nombre = "Luna", color = hex("e6efe4") },
	-- 1.3.0: los acentos de fábrica de La Jauría nocturno y de Fogata
	{ id = "plata", nombre = "Plata de luna", color = hex("c8d3e6") },
	{ id = "brasa", nombre = "Brasa", color = hex("ff9a4d") },
}

-- El acento con el que viene un estilo: el de su tema (nocturno, fogata) o
-- el verde de La Jauría. -> { r, g, b }
function K.AcentoDeFabrica(id)
	id = id or K.Estilo()
	local casa = T and T.ESTILOS_CASA and T.ESTILOS_CASA[id]
	if casa and casa.accent then return casa.accent end
	return K.ACENTOS[1].color
end

-- Un color del Kit en un estilo que no es el de ahora (para quien viste
-- algo con otro estilo, como el chat): el de ahora sale del tema; los
-- estilos de la casa, de su esquema; los demás, del diseño A.
function K.ColorEstilo(id, token)
	if id == nil or id == K.Estilo() then return K.Color(token) end
	local casa = T and T.ESTILOS_CASA and T.ESTILOS_CASA[id]
	local esquema = casa and T.SCHEMES and T.SCHEMES[casa.scheme]
	if esquema then
		if token == "acento" then
			local c = casa.accent
			return c[1], c[2], c[3], 1
		end
		local c = esquema[DEL_TEMA[token] or token]
		if type(c) == "table" then return c[1], c[2], c[3], c[4] or 1 end
	end
	local c = DISENO_A[token] or DISENO_A.texto
	return c[1], c[2], c[3], c[4] or 1
end

local function igual(a, b)
	if not (esColor(a) and esColor(b)) then return false end
	for i = 1, 3 do if math.abs(a[i] - b[i]) > 0.004 then return false end end
	return true
end
K.MismoColor = igual

-- Pone el acento: un { r, g, b } o un id de K.ACENTOS; nil vuelve al del estilo.
function K.SetAcento(c)
	if not (A and A.Set) then return end
	-- Elegir cualquier acento deja de usar el color de la clase (si no, volver
	-- al verde de La Jauría no cambiaba nada).
	if A.Get and A.Get("ui.classAccent") then A.Set("ui.classAccent", false) end
	if type(c) == "string" then
		for _, a in ipairs(K.ACENTOS) do if a.id == c then c = a.color end end
	end
	if not esColor(c) then A.Set("ui.accent", nil) return end
	-- El acento de fábrica del estilo (el verde de La Jauría en Alfa y Cristal,
	-- la plata en nocturno, la brasa en Fogata) no se guarda como propio.
	if not K.Clasico() and igual(c, K.AcentoDeFabrica()) then A.Set("ui.accent", nil) return end
	A.Set("ui.accent", { c[1], c[2], c[3] })
end

-- El id de K.ACENTOS del acento de ahora, o nil (uno propio de otro color).
function K.AcentoActual()
	local r, g, b = K.Color("acento")
	for _, a in ipairs(K.ACENTOS) do if igual(a.color, { r, g, b }) then return a.id end end
	return nil
end

---------------------------------------------------------------------------
-- Letra: Inter (Alfa/Media/Fonts), con la escala de texto del jugador.
-- Coreano y chino usan la letra del juego; el ruso, Fira Sans cuando el
-- jugador eligió la letra del juego (la del juego no tiene el punto medio).
---------------------------------------------------------------------------
local FUENTES = "Interface\\AddOns\\Alfa\\Media\\Fonts\\"
local FAMILIAS = {
	inter = { regular = "Inter-Regular.ttf", medium = "Inter-Medium.ttf", semibold = "Inter-SemiBold.ttf" },
	fira = { regular = "FiraSans-Regular.ttf", medium = "FiraSans-Medium.ttf", semibold = "FiraSans-SemiBold.ttf" },
	opensans = { regular = "OpenSans-Regular.ttf", medium = "OpenSans-Regular.ttf", semibold = "OpenSans-Bold.ttf" },
}
local CJK = { zhCN = true, zhTW = true, koKR = true }

-- La escala tipográfica: { peso, tamaño }.
K.TIPO = {
	portada = { "semibold", 26 },    -- el título de una portada ("¿Qué hacemos hoy?")
	titulo = { "semibold", 18 },     -- título de ventana, de la acción recomendada
	subtitulo = { "semibold", 15 },  -- título de tarjeta
	encabezado = { "semibold", 13 }, -- encabezado de sección
	cuerpo = { "medium", 13 },       -- texto principal de filas
	texto = { "regular", 13 },       -- párrafos
	etiqueta = { "medium", 12 },     -- controles
	boton = { "semibold", 12 },      -- botones
	botonGrande = { "semibold", 14 },
	nota = { "regular", 12 },        -- descripciones
	pequeno = { "medium", 11 },      -- líneas secundarias
	insignia = { "semibold", 11 },   -- insignias y píldoras
	mayus = { "semibold", 10 },      -- sobretítulos en mayúsculas ("RECOMENDADO")
	numero = { "semibold", 13 },     -- contadores
	cifra = { "semibold", 22 },      -- números grandes
	-- 1.2.6: el globo de Lya, en grande o muy grande (lya.letra)
	globoGrande = { "medium", 15 },
	globoEnorme = { "medium", 18 },
	-- 1.2.7: el nombre grande del anuncio animado (Anuncio.lua)
	anuncio = { "semibold", 30 },
	-- 1.4.0 (77): el nombre en la franja de cine del anuncio (baja a `anuncio` si no cabe)
	cine = { "semibold", 36 },
}

local function letraDelJuego()
	return type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end
K.LetraDelJuego = letraDelJuego

function K.Cara(peso)
	local loc = GetLocale and GetLocale()
	if CJK[loc] then return letraDelJuego() end
	local clave = (T and T.FontKey and T.FontKey()) or "inter"
	if clave == "game" then
		if loc ~= "ruRU" then return letraDelJuego() end
		clave = "fira"
	end
	local fam = FAMILIAS[clave] or FAMILIAS.inter
	return FUENTES .. (fam[peso] or fam.medium)
end

local function escalaTexto()
	local v = T and T.TextScale and T.TextScale()
	return type(v) == "number" and v or 1
end

-- El tamaño en pantalla de un rol (con la escala de texto del jugador).
function K.Tamano(rol)
	local spec = K.TIPO[rol] or K.TIPO.cuerpo
	-- 1.3.0: con «Letra más grande», un escalón más de la escala (Theme.Escalon).
	local base = (T and T.Escalon) and T.Escalon(spec[2]) or spec[2]
	return floor(base * escalaTexto() * 2 + 0.5) / 2
end

function K.Fuente(fs, rol)
	rol = rol or fs.alfaRol or "cuerpo"
	fs.alfaRol = rol
	local spec = K.TIPO[rol] or K.TIPO.cuerpo
	local tam = K.Tamano(rol)
	local ruta = fs.alfaEscritura or K.Cara(spec[1])
	local ok, cargo = pcall(fs.SetFont, fs, ruta, tam, "")
	if not (ok and cargo) then fs:SetFont(letraDelJuego(), tam, "") end
	-- La sombra: ninguna en Alfa; la dura del juego en Clásico WoW; una suave
	-- en Cristal, para leer sobre el mundo que se ve detrás.
	local estilo = K.Estilo()
	if estilo == "clasico" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	elseif estilo == "cristal" then
		-- 1.2.5: más suave (antes 0.55): se lee igual y se ve más fino.
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 0.4)
	else
		fs:SetShadowOffset(0, 0)
	end
end

-- Los roles de título: en Clásico WoW, el texto principal de estos roles va
-- en el oro de los títulos del juego (GameFontNormal).
local TITULARES = { portada = true, titulo = true, subtitulo = true, encabezado = true }
K.TITULARES = TITULARES

function K.ColorDeTexto(fs)
	local c = fs.alfaColor or "texto"
	if c == "texto" and TITULARES[fs.alfaRol] and K.Clasico() then return "titulo" end
	return c
end

local function pintarTexto(fs)
	K.Fuente(fs)
	fs:SetTextColor(K.Color(K.ColorDeTexto(fs)))
end

-- Un texto del Kit: rol de K.TIPO y color (token). Una línea por omisión.
function K.Texto(padre, rol, color, capa)
	local fs = padre:CreateFontString(nil, capa or "OVERLAY", "GameFontNormalSmall")
	fs.alfaRol, fs.alfaColor = rol or "cuerpo", color or "texto"
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	K.Pintar(fs, pintarTexto)
	K.TEXTOS[fs] = true
	return fs
end

---------------------------------------------------------------------------
-- 1.4.0: Forever no vuelve a acomodar un texto hasta que su texto cambia
-- (tras GX_RESTARTED, DISPLAY_SIZE_CHANGED, UI_SCALE_CHANGED o un cambio de
-- tamaño de UIParent, como al volver de Dos pantallas): se quedaba con la
-- medida de antes (grande, encimado o cortado). Tras uno de esos cambios,
-- cada texto del Kit a la vista se pinta y se escribe otra vez (lo mismo que
-- hace Bolsas con B.Refrescar), la ventana de Alfa también, y ALFA_PANTALLA
-- avisa a quien se acomoda solo (Hoy).
---------------------------------------------------------------------------
K.TEXTOS = setmetatable({}, { __mode = "k" })

local function otraVez(fs)
	if fs.HasFocus and fs:HasFocus() then return end
	local t = fs.GetText and fs:GetText()
	if issecretvalue and issecretvalue(t) then return end
	if type(t) == "string" and t ~= "" then
		fs:SetText(t .. " ")
		fs:SetText(t)
	end
end

-- -> cuántos textos se escribieron otra vez
function K.ReescribirTextos()
	local n = 0
	for fs in pairs(K.TEXTOS) do
		if fs.IsVisible and fs:IsVisible() then
			local ok = pcall(otraVez, fs)
			if ok then n = n + 1 end
		end
	end
	return n
end

function K.PantallaCambio()
	if InCombatLockdown and InCombatLockdown() and N.FueraDeCombate then
		return N.FueraDeCombate("kit.pantalla", K.PantallaCambio)
	end
	pcall(K.Repintar)
	local n = K.ReescribirTextos()
	local O = A and A.UI and A.UI.Options
	if O and O.frame and O.frame:IsShown() and T and T.RetextLater then pcall(T.RetextLater, O.frame) end
	if A and A.Fire then pcall(A.Fire, "ALFA_PANTALLA") end
	return n
end

local function pantallaLuego()
	if N.Una then N.Una("kit.pantalla", 0.2, K.PantallaCambio) else K.PantallaCambio() end
end
if A and A.RegisterEvent then
	for _, ev in ipairs({ "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "GX_RESTARTED" }) do
		A.RegisterEvent(ev, pantallaLuego)
	end
end
if UIParent and UIParent.HookScript then UIParent:HookScript("OnSizeChanged", pantallaLuego) end

function K.ColorTexto(fs, color)
	fs.alfaColor = color
	fs:SetTextColor(K.Color(K.ColorDeTexto(fs)))
end

---------------------------------------------------------------------------
-- Mayúsculas que entienden UTF-8 (string.upper solo cambia la A-Z): las
-- letras con acento y las de otros alfabetos latinos (á é í ó ú ü ñ à è ç ö
-- ä ł ś ż č ř...) y el cirílico. Lo que no tiene mayúsculas (chino, coreano)
-- queda igual, y los códigos del juego (|c...|r, |T...|t, |H...|h) también.
--   K.Mayus("La Jauría") -> "LA JAURÍA"
---------------------------------------------------------------------------
local schar = string.char

local function mayusDe(c)
	local a, b = c:byte(1, 2)
	local cp = (a - 192) * 64 + (b - 128)
	local up = cp
	if cp >= 0xE0 and cp <= 0xFE and cp ~= 0xF7 then up = cp - 32      -- à..þ (sin ÷)
	elseif cp == 0xFF then up = 0x178                                   -- ÿ
	elseif cp == 0x131 then return "I"                                  -- ı (sin punto)
	elseif cp >= 0x100 and cp <= 0x137 then if cp % 2 == 1 then up = cp - 1 end   -- ā..ķ
	elseif cp >= 0x139 and cp <= 0x148 then if cp % 2 == 0 then up = cp - 1 end   -- ĺ..ň
	elseif cp >= 0x14A and cp <= 0x177 then if cp % 2 == 1 then up = cp - 1 end   -- ŋ..ŷ
	elseif cp >= 0x179 and cp <= 0x17E then if cp % 2 == 0 then up = cp - 1 end   -- ź ż ž
	elseif cp >= 0x430 and cp <= 0x44F then up = cp - 32                -- а..я
	elseif cp >= 0x450 and cp <= 0x45F then up = cp - 80                -- ѐ..џ (ё)
	end
	if up == cp then return c end
	return schar(192 + floor(up / 64), 128 + up % 64)
end

-- La A-Z por bytes (string.upper depende del locale de C y podría tocar
-- bytes de otras letras), y luego las letras de dos bytes.
local function mayusAscii(c) return schar(c:byte() - 32) end
local function mayusTexto(t)
	return (t:gsub("[a-z]", mayusAscii):gsub("[\195-\197\208\209][\128-\191]", mayusDe))
end

function K.Mayus(s)
	if s == nil then return "" end
	s = tostring(s)
	if not s:find("|", 1, true) then return mayusTexto(s) end
	local out, i, n = {}, 1, #s
	while i <= n do
		local j = s:find("|", i, true)
		if not j then
			out[#out + 1] = mayusTexto(s:sub(i))
			break
		end
		if j > i then out[#out + 1] = mayusTexto(s:sub(i, j - 1)) end
		local codigo = s:match("^|c%x%x%x%x%x%x%x%x", j) or s:match("^|T.-|t", j) or s:match("^|H.-|h", j)
			or s:match("^|[rhn|]", j) or "|"
		out[#out + 1] = codigo
		i = j + #codigo
	end
	return table.concat(out)
end

-- Pone el texto; un nombre en coreano o chino en un cliente latino toma la
-- letra del juego para esa escritura (sin ella saldrían cuadros).
function K.Escribir(fs, texto)
	-- Un texto secreto va tal cual: no se puede leer (1.2.0).
	if issecretvalue and issecretvalue(texto) then
		fs:SetText(texto)
		return
	end
	texto = texto ~= nil and tostring(texto) or ""
	local otra = T and T.ScriptFont and T.ScriptFont(texto) or nil
	if type(otra) ~= "string" then otra = nil end
	if otra ~= fs.alfaEscritura then
		fs.alfaEscritura = otra
		K.Fuente(fs)
	end
	-- 1.3.5: el mismo texto no se vuelve a poner (el juego lo mediría y
	-- acomodaría otra vez): las ventanas que se repintan seguido solo
	-- cambian lo que cambió. Se compara con lo que el texto tiene de verdad.
	-- (Lo que tenía antes puede ser secreto: eso no se compara.)
	if texto ~= "" and fs.GetText then
		local antes = fs:GetText()
		if not (issecretvalue and issecretvalue(antes)) and antes == texto then return end
	end
	fs:SetText(texto)
end

---------------------------------------------------------------------------
-- Medir. El cliente puede devolver nada antes del primer dibujo: siempre
-- un número.
---------------------------------------------------------------------------
-- 1.4.0: un número secreto del juego (en combate o mazmorras) no se usa: 'd'.
local function num(v, d)
	if issecretvalue and issecretvalue(v) then return d or 0 end
	return type(v) == "number" and v or (d or 0)
end
K.num = num

-- (1.3.8 revisión) El cursor en unidades de UIParent, medido desde su esquina
-- de abajo a la izquierda: con el escritorio de dos pantallas UIParent no
-- empieza en el borde de la pantalla y un menú anclado al cursor salía corrido.
-- Para SetPoint(punto, UIParent, "BOTTOMLEFT", x, y). -> x, y
function K.CursorEnUI()
	local x, y = 0, 0
	if GetCursorPosition then x, y = GetCursorPosition() end
	local U = UIParent
	local s = num(U and U.GetEffectiveScale and U:GetEffectiveScale(), 1)
	if s <= 0 then s = 1 end
	local l = num(U and U.GetLeft and U:GetLeft(), 0)
	local b = num(U and U.GetBottom and U:GetBottom(), 0)
	return num(x, 0) / s - l, num(y, 0) / s - b
end

function K.AnchoTexto(fs)
	local w = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
	return ceil(num(w))
end

-- 1.4.2 (Toxic: «el tiempo sale del recuadro»): que un texto de una línea
-- quepa en `ancho`. Prueba los roles de la escala del Kit en orden (del más
-- grande al más chico, p. ej. { "cifra", "titulo", "subtitulo" }) y se queda con
-- el primero que cabe; si ni el más chico cabe, lo deja en ese con «…» al final
-- (el texto completo en su cuadro de ayuda). -> el rol que quedó, true si cupo
function K.Encajar(fs, ancho, roles)
	ancho = max(1, floor(num(ancho, 1)))
	roles = type(roles) == "table" and roles or { fs.alfaRol or "cuerpo" }
	fs:SetWordWrap(false)
	fs:SetWidth(0)
	for _, rol in ipairs(roles) do
		if fs.alfaRol ~= rol then K.Fuente(fs, rol) end
		if K.AnchoTexto(fs) <= ancho then return rol, true end
	end
	-- (ni el más chico: se corta con «…» en vez de salirse)
	fs:SetWidth(ancho)
	return roles[#roles], false
end

function K.AltoTexto(fs)
	if (fs:GetText() or "") == "" then return 0 end
	return ceil(num(fs:GetStringHeight()))
end

-- Un párrafo de `ancho`: lo envuelve y devuelve su alto.
function K.Parrafo(fs, ancho, lineas)
	fs:SetWidth(max(1, floor(ancho)))
	fs:SetWordWrap(true)
	if lineas then fs:SetMaxLines(lineas) end
	fs:SetJustifyV("TOP")
	return K.AltoTexto(fs)
end

-- Pone una letra con respaldo: si la del estilo no carga, la del juego (un
-- texto o una caja sin letra dan "Font not set" al escribirles).
function K.FuenteSegura(obj, cara, tam, banderas)
	local ok = obj:SetFont(cara, tam, banderas or "")
	if not ok and obj.SetFontObject then
		local caja = obj.GetObjectType and obj:GetObjectType() == "EditBox"
		obj:SetFontObject(caja and ChatFontNormal or GameFontNormal)
	end
end

-- Ajusta el ancho de un texto de una línea a lo que mide, sin pasar de `tope`.
function K.Ajustar(fs, tope)
	fs:SetWidth(0)
	local w = K.AnchoTexto(fs)
	if tope and w > tope then w = tope end
	fs:SetWidth(max(1, w + 1))
	return w
end

function K.Pixel(region)
	if T and T.Pixel then
		local ok, v = pcall(T.Pixel, region)
		if ok and type(v) == "number" and v > 0 then return v end
	end
	return 1
end

---------------------------------------------------------------------------
-- Íconos: los nombres son texturas de Alfa/Media/UI (ic-*, sec-*, lobo-*);
-- un número (fileID) o una ruta completa pasan tal cual.
---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\Alfa\\Media\\UI\\"

function K.Ruta(nombre)
	if type(nombre) ~= "string" then return nombre end
	if nombre:find("\\", 1, true) or nombre:find("/", 1, true) then return nombre end
	return MEDIA .. nombre
end

-- Las variantes del lobo (tools/iconos.py): normal, atento, aullando, dormido, vacio.
function K.Lobo(variante) return MEDIA .. "lobo-" .. (variante or "normal") end

local function pintarIcono(t)
	if t.alfaColor then t:SetVertexColor(K.Color(t.alfaColor)) else t:SetVertexColor(1, 1, 1, 1) end
end

function K.SetIcono(t, nombre, color)
	t:SetTexture(K.Ruta(nombre))
	t.alfaColor = color
	K.Pintar(t, pintarIcono)
end

function K.Icono(padre, nombre, tam, color, capa)
	local t = padre:CreateTexture(nil, capa or "ARTWORK")
	t:SetSize(tam or 16, tam or 16)
	K.SetIcono(t, nombre, color)
	return t
end

-- Un rectángulo de color (líneas, rellenos planos).
function K.Plano(padre, color, capa, sub)
	local t = padre:CreateTexture(nil, capa or "BACKGROUND", nil, sub or 0)
	t:SetColorTexture(1, 1, 1, 1)
	t.alfaColor = color
	K.Pintar(t, pintarIcono)
	return t
end

function K.ColorPlano(t, color)
	t.alfaColor = color
	pintarIcono(t)
end

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------

-- Llama fn sin dejar que un error rompa la pieza (lo reporta).
function K.Llamar(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok and geterrorhandler then geterrorhandler()(err) end
	return ok
end

-- Un temporizador que se puede cancelar (para búsquedas mientras escribes).
function K.Despues(seg, fn)
	if C_Timer and C_Timer.NewTimer then return C_Timer.NewTimer(seg, fn) end
	local vivo = { cancelado = false }
	function vivo:Cancel() self.cancelado = true end
	if C_Timer and C_Timer.After then C_Timer.After(seg, function() if not vivo.cancelado then fn() end end) end
	return vivo
end

-- La capa de Alfa (se oculta con "Ocultar Alfa"); sin motor, UIParent.
function K.Raiz()
	return (A and A.UIParent) or UIParent
end
