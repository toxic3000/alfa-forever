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
	{ version = "1.3.7", titulo = "La manada a tu ritmo", puntos = {
		{ "ic-oro", "Tu oro, una sola vez: un clic en las monedas y ves cuánto tiene cada personaje." },
		{ "ic-mapa", "Cada zona se anuncia al llegar, con su propia animación para barcos, raros, mazmorras y más." },
		{ "ic-nivel", "Al subir de nivel, Alfa espera a la animación del juego y te da un solo resumen." },
		{ "ic-manada", "El medidor de daño sale solo en grupo, compacto y sin tapar tus barras." },
		{ "ic-pesca", "Pescando, la espada te devuelve tus armas en un clic, incluso en plena pelea." },
		{ "ic-alerta", "Los avisos hacen fila y no se enciman; lo que te perdiste queda en «Lo que me perdí»." },
	} },
	{ version = "1.3.3", titulo = "La manada en calma", puntos = {
		{ "ic-lobo", "Al entrar solo sale la animación; lo demás te espera en Hoy y con Lya." },
		{ "ic-manada", "Sigue la ruta de tu grupo y pide las misiones que lleva tu compañero." },
		{ "ic-flecha", "La piedra de hogar, clara: a dónde vuelves, qué entregas y un botón para usarla." },
		{ "ic-alerta", "Una sola voz: Hoy, las bolsas y Lya ya no repiten lo mismo." },
	} },
	{ version = "1.3.2", titulo = "La manada en orden", puntos = {
		{ "ic-ventana", "Un solo menú de Alfa: el ícono del minimapa, la lista de addons y el botón Alfa del menú Esc abren lo mismo." },
		{ "ic-alerta", "Menos estorbo: Combate se calla yendo solo y los avisos de grupo esperan a que acabe la pelea." },
		{ "ic-lobo", "Lya te entiende sin acentos, te cuenta datos aunque esté oculta y su menú dice lo que hará." },
		{ "ic-manada", "Citas y notas sin compartir tu ubicación, el oro del buzón aparte y Alfa más ligero." },
	} },
	{ version = "1.3.1", titulo = "La manada afinada", puntos = {
		{ "ic-ventana", "Acomoda con el ratón a Lya, tu guía, la flecha y tus marcos: Ajustes > Estilo y sonido o /alfa acomodar." },
		{ "ic-alerta", "Más de 40 arreglos: combate y curación en mazmorras, el buzón cuenta bien tu dinero y la placa de llegada se va sola." },
		{ "ic-lobo", "Los anuncios esperan a que el juego termine de escribir la zona, y el botón de Alfa queda siempre a la vista en el minimapa." },
		{ "ic-manada", "La Jauría más cuidadosa y Alfa más ligero: el mapa del grupo, los barcos y tus bolsas trabajan menos." },
	} },
	{ version = "1.3.0", titulo = "La manada sana", puntos = {
		{ "ic-curacion", "Cura con un clic y ese compañero queda seleccionado; limpia maldiciones y venenos con otro clic." },
		{ "ic-flecha", "La llegada de la flecha, nueva; circuito de la zona y «Llévame a…» con vuelos y barcos." },
		{ "ic-bolsas", "Bolsas sin errores, conjuntos de equipo, comparar y buscar en todos tus personajes." },
		{ "ic-manada", "Cortar hechizos, amenaza, el tablón de la manada, mentor y dos estilos nuevos." },
	} },
	{ version = "1.2.9", titulo = "La gran cacería", puntos = {
		{ "ic-flecha", "La flecha con el estilo de La Jauría, y «¿Cuánto tiempo tienes?» arma tu plan paso a paso." },
		{ "ic-manada", "Cambia de plano cuando está lleno, «¿Quién tiene...?» y los festejos de la manada." },
		{ "ic-bolsas", "«Ponte esto», lista de compras, oficios del 1 al 300 y subastar fácil." },
		{ "ic-huella", "Lya te enseña tu clase y te ayuda al morir; respaldos, diagnóstico y Alfa más ligero." },
	} },
	{ version = "1.2.8", titulo = "La manada se organiza y tu historia", puntos = {
		{ "ic-manada", "Citas de la manada, «¿Quién va?», raros con reloj y notas en tu mapa." },
		{ "ic-ruta", "Vuelta a entregar por el camino más corto, la piedra de hogar a tiempo y la mejor recompensa marcada." },
		{ "ic-huella", "Lya lleva tu historia, aprende qué consejos ya no quieres y te avisa de tus oficios." },
		{ "ic-bolsas", "«Tomar todo» en el buzón, tu oro por hora y aviso de bolsas casi llenas." },
	} },
	{ version = "1.2.7", titulo = "Anuncios animados y la manada a la vista", puntos = {
		{ "ic-lobo", "Al llegar en barco o al encontrar un raro, un anuncio grande con animación, como la intro." },
		{ "ic-manada", "La manada en el mapa, cazar juntos, el saludo al entrar y la calavera para el raro con un clic." },
		{ "ic-huella", "Lya en las mazmorras, con ánimo, su salchicha y su despedida; y te enseña Alfa en 5 pasos." },
		{ "ic-ruta", "Una hora de caza, aviso de cadena, «Deshacer» al omitir y cuánto te falta de tu guía." },
	} },
	{ version = "1.2.6", titulo = "Lya te lo dice todo", puntos = {
		{ "ic-manada", "Llama a la manada cuando necesites ayuda; los lobos de tu zona llegan con «¡Voy!». Y «Seguir» ya no se suelta al alcanzar a alguien." },
		{ "ic-nivel", "Lya recuerda lo que te dijo, tiene una tecla para su botón y te cuenta tu semana de caza y tu mejor día." },
		{ "ic-lobo", "Todos los avisos de Alfa los dice Lya, también los de al entrar y el de hechizos nuevos, con letra más grande que cambias con su clic derecho." },
		{ "ic-ruta", "Tu guía y Hoy dicen lo mismo: al terminar «Desbloquear» vuelves solo a tu guía, y el final de una guía con pasos sin hacer ya no dice «terminaste»." },
	} },
	{ version = "1.2.5", titulo = "La manada caza junta", puntos = {
		{ "ic-raros", "Raros de la manada: cuando un lobo encuentra un raro en tu zona, te avisa en qué guarida está, con «Ir de caza» o «Pedir entrar»." },
		{ "ic-huella", "Tu día de caza: Lya cuenta tus misiones, niveles, oro y raros del día. Pídeselo con /alfa lya dia." },
		{ "ic-lobo", "Un «?» en cada página de Alfa para que Lya te la explique, y su propia tecla." },
		{ "ic-misiones", "Al completar una misión vuelve a salir en tu chat: «[Misión] está lista para entregar» y «¡Misión completada!». Si lo prendes, también tu grupo lo ve." },
	} },
	{ version = "1.2.4", titulo = "Lya te guía, un asistente más sencillo y las guaridas", puntos = {
		{ "ic-lobo", "Pregúntale a Lya: clic derecho en ella y «¿En qué te ayudo?». Te explica cada parte de Alfa y te lleva con un clic." },
		{ "ic-ajustes", "La configuración es más visual: tres tarjetas para decidir cuánto te ayuda Alfa y tus extras en un mosaico." },
		{ "ic-manada", "Nuevo: las guaridas. Alfa te dice en qué capa de la zona estás y en cuáles anda la manada; con «Pedir entrar» te pasas a la de un lobo con la puerta abierta." },
		{ "ic-huella", "Los avisos de viaje hablan como la manada: «La manada viaja», el lobo en el aro y una huellita que camina mientras llega tu barco." },
		{ "ic-lobo", "Lya es quien olfatea los raros y los tesoros: su tarjeta trae «Ir de caza», «Su ficha» y «Seleccionarlo»." },
		{ "ic-manada", "Si Toxic, el fundador de La Jauría, anda cerca, Alfa te avisa para que lo saludes." },
	} },
	{ version = "1.2.3", titulo = "Invitar a una comunidad sin bloqueos", puntos = {
		{ "ic-manada", "Al invitar a una comunidad ya no sale el aviso de bloqueo: Alfa te deja el nombre listo para copiar y te abre la ventana. A tu hermandad, un clic como antes." },
		{ "ic-ruta", "El rastreador te avisa si tu plan se quedó sin paso y lo rearma con un clic." },
	} },
	{ version = "1.2.2", titulo = "Invita a tu clan con un clic, y arreglos", puntos = {
		{ "ic-manada", "Clic derecho en un jugador y «Invitar al clan»: eliges tu hermandad o tu comunidad y la invitación le llega sin escribir su nombre." },
		{ "ic-exito", "Solo salen los clanes donde puedes invitar, y Alfa te confirma en el chat a quién invitaste. Lo apagas en La Jauría > Invitar." },
		{ "ic-lobo", "Tu insignia de La Jauría en el borde de tu retrato, y en el de tu objetivo si la lleva." },
		{ "ic-ruta", "Arreglos: «Cerrar mis misiones» vuelve a armar tu ruta, la ayuda de rotación vuelve a decirte qué usar y el mapa ya no muestra rectángulos pegados al acercar." },
	} },
	{ version = "1.2.1", titulo = "Tu camino en el mapa y un aullido nuevo", puntos = {
		{ "ic-mapa", "Un mapa de una pieza: al acercar ya no se ven pedazos pegados, y el terreno se une sin rayas ni cuadros." },
		{ "ic-ruta", "Tu ruta dibujada en el mapa de Alfa hasta tu destino, que late para que lo encuentres; arriba ves a qué distancia está y cuánto falta, y un clic te muestra todo el camino." },
		{ "ic-flecha", "En grifo, la línea de tu vuelo en el mapa: por dónde vas, dónde aterrizas y el tiempo que falta." },
		{ "ic-huella", "Tu lugar resalta más: tu flecha lleva un aro y un pulso suave, y se ve bien hasta en la nieve." },
		{ "ic-lobo", "El lobo de la intro aúlla de pie sobre la peña, con un aullido largo que otro lobo contesta; y al entrar, Lya llega corriendo a decirte que te extrañó." },
	} },
	{ version = "1.2.0", titulo = "Alfa estable: en orden y en manada", puntos = {
		{ "ic-ajustes", "Ajustes en orden: Comodidades y Calidad de vida son una sola página con pestañas, y todo lo de misiones vive en Ajustes > Misiones. Tu configuración se mudó sola, sin perder nada." },
		{ "ic-lobo", "El lobo te recibe cada vez que entras al juego, redibujado: cabeza, orejas y hocico de lobo de verdad." },
		{ "ic-manada", "Insignias de La Jauría: los Alfas y los miembros llevan su lobo en el cuadro, en La Jauría y en el mapa; y quienes comparten se ven con una huella." },
		{ "ic-comodidades", "Quien instala Alfa ya tiene encendidos los colores de clase, el cuadro de información, el probador, el minimapa y las barras con el estilo de Alfa." },
		{ "ic-exito", "Una revisión completa para la versión estable: más de 20 arreglos en mazmorras con grupo, combate, el mapa, Pesca, Talentos y más." },
	} },
	{ version = "1.1.9", titulo = "Todo a la mano", puntos = {
		{ "ic-buscar", "El buscador de Ajustes ya encuentra todo: también Pesca, Comercio, Ruta, Bolsas, Combate, Curación, Lya y Estilo y sonido." },
		{ "ic-bolsas", "Bolsas encuentra tus objetos en ruso y en otros alfabetos aunque escribas con mayúscula." },
		{ "ic-hoy", "Cuando tus bolsas se llenan, Hoy te dice qué puedes vender y cuánto te dan." },
		{ "ic-exito", "Tus ajustes pasan una prueba de guardar y recargar en cada versión, para que nunca se pierdan." },
	} },
	{ version = "1.1.8", titulo = "Íconos limpios y tus recursos en el mapa", puntos = {
		{ "ic-ventana", "Íconos sin bordes negros: el mapa y las ventanas de Alfa se ven limpios al hacer zoom o al teñirse de color." },
		{ "ic-recoleccion", "Minería, hierbas, pesca y tesoros también en el mapa grande de Alfa: al acercarte a una zona salen agrupados, con su cantidad." },
		{ "ic-mapa", "Al acercar o cargar el mapa, cada parte aparece completa de una vez, sin cuadritos sueltos." },
		{ "ic-exito", "El minimapa de Recolección descansa cuando no tiene nada que mostrar." },
	} },
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
