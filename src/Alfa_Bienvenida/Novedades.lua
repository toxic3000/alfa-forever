-- Alfa - Bienvenida: lo nuevo de Alfa 1.0 (toxic3000 / La Jauría). GPL-3.0.
--
-- Las novedades que muestra la portada de la bienvenida. Deben decir lo mismo
-- que la sección 1.0.0 de CHANGELOG.md (docs/VERSIONES.md): una línea por
-- novedad, en el mismo orden. Al publicar otra versión, se cambia VERSION y
-- esta lista (y, si debe salir otra vez a todos, M.VERSION en Bienvenida.lua).

local ADDON, M = ...

M.VERSION_ALFA = "1.0.0"

-- { icono (ic-* de Alfa), título, una línea }
M.NOVEDADES = {
	{ "ic-hoy", "Hoy te guía", "Una acción recomendada en grande y tu camino en un par de clics." },
	{ "ic-ruta", "Tu ruta, paso a paso", "Rastreador propio y misiones que se liberan o se recogen en un clic." },
	{ "ic-enciclopedia", "Enciclopedia", "Todo objeto, PNJ, misión, zona y raro, con dónde conseguirlo y «Guíame»." },
	{ "ic-talentos", "Talentos y combate", "Qué talento poner y por qué, ayuda de rotación y el daño del grupo." },
	{ "ic-mazmorra", "Mazmorras claras", "Por nivel: jefes, botín, misiones, la entrada y consejos." },
	{ "ic-manada", "La Jauría", "Solo tu grupo y quienes usan Alfa y aceptaron compartir." },
	{ "ic-bolsas", "Bolsas y banco", "General, por categorías o por bolsa, y depósito rápido al banco." },
	{ "ic-mapa", "Mapa y marcadores", "Marcadores propios para compartir y seguir con la flecha." },
	{ "ic-apariencia", "Tres estilos y el lobo", "Alfa, Clásico WoW o Cristal, la flecha del lobo y el aullido." },
}

---------------------------------------------------------------------------
-- Las notas de cada versión: lo que sale al entrar al juego con una versión
-- nueva (Notas.lua), después de la intro del lobo. Salen de CHANGELOG.md,
-- contadas corto y en confianza: de 4 a 7 puntos, la más nueva primero.
-- Al publicar otra versión se agrega su entrada arriba (con su inglés en
-- Textos.lua); sin entrada, esa versión no muestra ventana.
--   { version, titulo, puntos = { { icono (ic-*), texto } } }
---------------------------------------------------------------------------
M.NOTAS = {
	{ version = "1.1.7", titulo = "Un mapa impecable", puntos = {
		{ "ic-mapa", "El mapa se ve más limpio: sin líneas finas entre sus pedazos ni halos oscuros en las orillas de las zonas." },
		{ "ic-flecha", "Los íconos, los nombres y tu flecha se mueven pegados al mapa al hacer zoom o arrastrar: ya no brincan un píxel." },
		{ "ic-mundo", "Las fronteras entre zonas ya no parpadean al mover el mapa." },
		{ "ic-exito", "Cada ícono del mapa con su tamaño exacto en tu pantalla, nítido de orilla a orilla." },
	} },
	{ version = "1.1.6", titulo = "Más firme y en tu idioma", puntos = {
		{ "ic-seguir", "«Seguir» en La Jauría ya no se suelta cuando tu guía cambia de paso ni cuando vas por tu cuerpo: al terminar, la flecha vuelve con quien sigues." },
		{ "ic-misiones", "Aceptar todas las misiones ya no pierde una diaria porque la ventana se cerraba antes de tiempo." },
		{ "ic-reloj", "La barra de tu vuelo con sus paradas sale siempre al despegar." },
		{ "ic-mazmorra", "Mazmorras: los avisos de jefes que tu juego sí trae ya no salen apagados." },
		{ "ic-exito", "Ajustes de Alfa en todos los idiomas: las fechas en el orden de cada uno y los nombres de cada especialización bien puestos." },
	} },
	{ version = "1.1.5", titulo = "Sin bloqueos y más claro", puntos = {
		{ "ic-talentos", "Se acabó el aviso «Alfa_Builds se ha bloqueado…»: la ventana de talentos, el clic para lanzar y el Legado ahora los abre el juego, y tus hechizos se lanzan sin problema desde el libro." },
		{ "ic-ruta", "Tu guía ya no te manda a entregar misiones sin terminar: primero te lleva a lo que falta, y «Cerrar mis misiones» se pone al día sola." },
		{ "ic-flecha", "«Ver el siguiente» te deja mirar el paso que viene y lo dice claro; y un solo contador de pasos hechos." },
		{ "ic-personaje", "Druidas, guerreros y pícaros: si tu barra de forma o de actitud está vacía, Alfa te avisa y la llena con un clic." },
		{ "ic-hoy", "Hoy te pone tu siguiente paso primero, y en combate ninguna ventana de Alfa te deja atrapado." },
		{ "ic-exito", "Una revisión completa de todos los módulos: más de 60 arreglos." },
	} },
	{ version = "1.1.4", titulo = "Lya tiene mucho que contar", puntos = {
		{ "ic-lobo", "Lya platica mucho más: lore de Warcraft, datos de cada zona, de tu raza, tu clase y tus profesiones, y consejos de eventos y de farmeo. ¡Y le encantan las salchichas!" },
		{ "ic-cerca", "Junto a tu guía hay un botón para buscar lo que tienes cerca: vuelo, banco, subasta, reparar, comerciantes y entrenadores." },
		{ "ic-mapa", "Los puntos de vuelo y de viaje ya se ven en el mapa." },
		{ "ic-info", "Cada versión nueva te recibe con la intro del lobo y sus notas, como estas." },
		{ "ic-ventana", "Textos y cajas mejor alineados en las ventanas de Alfa." },
	} },
	{ version = "1.1.3", titulo = "Mapa estable y 46 arreglos", puntos = {
		{ "ic-mapa", "El mapa abre sin errores con M y se arrastra suave, aunque empieces encima de un ícono." },
		{ "ic-flecha", "Tu destino y tus marcadores ya no desaparecen cuando hay muchos pines." },
		{ "ic-ruta", "La ruta ya no se salta para siempre una misión que todavía no puede revisar." },
		{ "ic-talentos", "El medidor de daño aguanta en combate y la ayuda de rotación ya no te pide interrumpir lo que no se puede." },
		{ "ic-pesca", "Pesca: si te atacan mientras vuelve tu equipo normal, ya no pierdes piezas." },
		{ "ic-exito", "Y una prueba nueva que juega Alfa de punta a punta antes de cada versión, para que estos errores no regresen." },
	} },
	{ version = "1.1.2", titulo = "Lya de cuerpo completo", puntos = {
		{ "ic-lobo", "Lya ahora es una loba negra de cuerpo completo, con 39 cuadros de animación: se sienta, corre, se busca la cola, bosteza y duerme enroscada." },
		{ "ic-apariencia", "Ya no está sobre un cuadro negro: la acompañan una sombra suave y una elipse del color de tu estilo." },
		{ "ic-manada", "Te saluda según la hora, comenta la zona y a veces se sienta a pedirte algo con su huesito." },
		{ "ic-personaje", "La línea de tu personaje ya no se corta: si no cabe, quita partes y nunca tu nombre ni tu nivel." },
		{ "ic-exito", "Se acabaron los textos cortados con «…» en Hoy, La Jauría, Buscar cerca y la Enciclopedia." },
	} },
	{ version = "1.1.1", titulo = "Bienvenida a pantalla completa", puntos = {
		{ "ic-exito", "Cada paso de la bienvenida deja bajar hasta el final, sin cerrar y volver a abrir." },
		{ "ic-ruta", "El mismo arreglo llegó a los asistentes de Ruta y de Curación." },
		{ "ic-ventana", "La bienvenida ocupa toda la pantalla, con el juego oscurecido detrás." },
		{ "ic-apariencia", "El contenido va en una columna centrada y se acomoda solo si cambias la resolución o la escala." },
	} },
	{ version = "1.1.0", titulo = "La manada crece", puntos = {
		{ "ic-lobo", "Una bienvenida nueva en 9 pasos con la intro del lobo: eliges el idioma de Alfa (hay 10) y cada cosa que hace sola por ti." },
		{ "ic-mapa", "El mapa de Alfa muestra el terreno real, con puntos de vuelo, mazmorras, barcos, zepelines y portales." },
		{ "ic-cerca", "«Buscar cerca» te lleva con flecha a lo que necesitas, y «Mis planes» arma tus propias metas, que se marcan solas." },
		{ "ic-pesca", "La pesca se rehízo: una sola tecla para equiparte, lanzar y recoger, con diario, logros y una guía de 1 a 300." },
		{ "ic-manada", "Llega Lya, una loba compañera que guarda la historia de cada misión y te cuenta datos de cada zona." },
		{ "ic-talentos", "Ayuda de rotación para las 27 especializaciones y la ventana /alfa paisaje con 68 ajustes gráficos explicados." },
	} },
}

-- "1.1.4" -> { 1, 1, 4 } ; lo que no es una versión ("dev") -> nil
function M.PartesVersion(v)
	if type(v) ~= "string" then return nil end
	local a, b, c = v:match("^%s*(%d+)%.(%d+)%.?(%d*)")
	if not a then return nil end
	return { tonumber(a), tonumber(b), tonumber(c) or 0 }
end

-- -1 si a es más vieja que b, 0 si son iguales, 1 si es más nueva.
function M.CompararVersion(a, b)
	local x, y = M.PartesVersion(a), M.PartesVersion(b)
	if not x or not y then return 0 end
	for i = 1, 3 do
		if x[i] ~= y[i] then return x[i] < y[i] and -1 or 1 end
	end
	return 0
end

-- La versión instalada de Alfa (la del .toc), o nil fuera de un paquete ("dev").
function M.VersionAlfa()
	local N = AlfaNucleo
	local v = N and (N.version or (N.A and N.A.version))
	return M.PartesVersion(v) and v or nil
end

-- Las notas de una versión (o nil).
function M.NotaDe(version)
	for _, n in ipairs(M.NOTAS) do
		if M.CompararVersion(n.version, version) == 0 then return n end
	end
	return nil
end

M.VERSION_ALFA = M.VersionAlfa() or M.NOTAS[1].version
