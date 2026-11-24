-- Alfa - Lya: su página en la ventana de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- Personaje > Lya, hecha con el Kit (plantilla Tablero):
--   1. cómo está Lya (a la vista, calladita, descansando, esperando la
--      bienvenida) y el botón que toca;
--   2. cuántos consejos ya te dio y el modo;
--   3. "Sobre Lya": su recuerdo;
--   4. los ajustes (lya.*), con Historias y datos curiosos (lya.historias,
--      lya.minutosHistoria, lya.epilogo y el botón de la ventana Historias).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local Ce = M.Cerebro

local format, floor, type = string.format, math.floor, type

-- 1.2.6: el tamaño de su letra.
local LETRAS = {
	{ valor = "normal", texto = L["Normal"] },
	{ valor = "grande", texto = L["Grande"] },
	{ valor = "enorme", texto = L["Muy grande"] },
}

local MODOS = {
	{ valor = "muchos", texto = L["Muchos"] },
	{ valor = "pocos", texto = L["Pocos"] },
	{ valor = "importantes", texto = L["Solo importantes"] },
}
local MODOS_HISTORIA = {
	{ valor = "siempre", texto = L["Siempre"] },
	{ valor = "aveces", texto = L["A veces"] },
	{ valor = "pedir", texto = L["Solo si le pido"] },
	{ valor = "nunca", texto = L["Nunca"] },
}
local NOMBRE_MODO ={ muchos = L["Consejos: muchos"], pocos = L["Consejos: pocos"], importantes = L["Consejos: solo importantes"] }

-- "2026-11-19" -> "19/11/2026"
local function fechaBonita(f)
	if type(f) ~= "string" then return "" end
	local y, m, d = f:match("^(%d+)%-(%d+)%-(%d+)$")
	if not y then return f end
	return d .. "/" .. m .. "/" .. y
end

local function bienvenidaPendiente()
	local B = rawget(_G, "AlfaBienvenida")
	if not (type(B) == "table" and type(B.Pendiente) == "function") then return false end
	local ok, p = pcall(B.Pendiente)
	return ok and p == true
end

local function estado()
	local d = { icono = "ic-lobo" }
	if bienvenidaPendiente() then
		d.titulo, d.tono = L["Lya te espera"], "neutro"
		d.texto = L["Aparece en cuanto termines la bienvenida de Alfa."]
		d.estado = { texto = L["Esperando"], tono = "neutro" }
	elseif N.Get(ID, "mostrar") == false then
		d.titulo, d.tono = L["Lya está descansando"], "neutro"
		d.texto = L["No se ve en pantalla. Tráela de vuelta cuando quieras (también con /alfa lya)."]
		d.estado = { texto = L["Oculta"], tono = "neutro" }
		d.accion = { texto = L["Mostrar a Lya"], icono = "ic-seguir", alClic = function() Ce.Mostrar(true) end }
	elseif Ce.Silenciada() then
		d.titulo, d.tono = L["Lya está calladita"], "aviso"
		local hasta = tonumber(N.DatosPersonaje(ID).silencio)
		d.texto = hasta and date and format(L["Sigue a tu lado, pero no habla hasta las %s."], date("%H:%M", hasta))
			or L["Sigue a tu lado, pero no habla por un rato."]
		d.estado = { texto = L["En silencio"], tono = "aviso" }
		d.accion = { texto = L["Quitar el silencio"], icono = "ic-reloj", alClic = function() Ce.Silenciar(false) end }
	else
		d.titulo, d.tono = L["Lya te acompaña"], "exito"
		d.texto = L["Te da consejos cortos y ánimo sin repetirse: cada frase sale tres veces como mucho. Dale clic para pedirle uno; clic derecho para sus opciones."]
		d.estado = { texto = L["A tu lado"], tono = "exito" }
		d.accion = { texto = L["Pedirle un consejo"], icono = "ic-info", alClic = function() Ce.Pedir() end }
	end
	return d
end

local function numeros()
	local n, total = Ce.Vistos()
	local lista = {
		{ variante = "compacta", icono = "ic-lista", titulo = L["Frases dichas"], valor = format(L["%d de %d"], n, total),
			ayuda = L["Las que Lya ya te dijo sus tres veces. Con «Volver a mostrarlos» salen otra vez."] },
		{ variante = "compacta", icono = "ic-reloj", titulo = NOMBRE_MODO[Ce.Frecuencia()] },
	}
	local Hi = M.Historias
	if Hi then
		lista[#lista + 1] = { variante = "compacta", icono = "ic-misiones", titulo = L["Historias guardadas"], valor = tostring(Hi.Cuantas()),
			alClic = function() Hi.Abrir() end, ayuda = L["Abre la ventana Historias."] }
	end
	-- 1.2.7: las salchichas que le has dado (Momentos.lua).
	local Mo = M.Momentos
	if Mo then
		lista[#lista + 1] = { variante = "compacta", icono = "ic-huella", titulo = L["Salchichas que le diste"], valor = tostring(Mo.Salchichas()),
			ayuda = L["De vez en cuando Lya te pide una. Te las tiene bien contadas."] }
	end
	return lista
end

---------------------------------------------------------------------------
-- Ajustes
---------------------------------------------------------------------------
local function interruptor(clave)
	return function(fila) return K.Interruptor(fila, { clave = ID .. "." .. clave }) end
end

local function deslizador(clave, a, b, paso, formato)
	return function(fila)
		local d = K.Deslizador(fila, { min = a, max = b, paso = paso, clave = ID .. "." .. clave, formato = formato })
		d.alfaAnchoFila = 220
		return d
	end
end

local function visible() return N.Get(ID, "mostrar") ~= false end
local function hablaMas() return visible() and Ce.Frecuencia() ~= "importantes" end

local function grupos(padre)
	local ella = K.GrupoAjustes(padre, { titulo = L["Lya en tu pantalla"] })
	ella:Fila({ titulo = L["Mostrar a Lya"], control = interruptor("mostrar"),
		texto = L["Tu loba compañera: te da consejos y ánimo. También con /alfa lya."] })
	ella:Fila({ titulo = L["Tamaño"], control = deslizador("tamano", 48, 96, 4, function(v) return format(L["%d px"], floor(v + 0.5)) end),
		activa = visible, texto = L["Qué tan grande se ve Lya."] })
	ella:Fila({ titulo = L["Bloquear su lugar"], control = interruptor("bloqueado"), activa = visible,
		texto = L["Para no moverla sin querer. Sin bloquear, arrástrala a donde quieras."] })

	local consejos = K.GrupoAjustes(padre, { titulo = L["Sus consejos"] })
	consejos:Fila({ titulo = L["Cuántos consejos"], activa = visible,
		texto = L["Muchos: consejos del momento y de vez en cuando uno de Alfa. Pocos: menos seguido. Solo importantes: al morir, al subir de nivel y en tus logros."],
		control = function(fila) return K.Desplegable(fila, { opciones = MODOS, clave = ID .. ".frecuencia", ancho = 200 }) end })
	consejos:Fila({ titulo = L["Minutos entre consejos"], hija = true, activa = hablaMas,
		control = deslizador("minutos", 2, 30, 1, function(v) return format(L["%d min"], floor(v + 0.5)) end),
		texto = L["Lo menos que espera Lya entre un consejo y otro. Lo importante no espera."] })
	-- 1.3.9 (69): más tranquila con quien empieza.
	consejos:Fila({ titulo = L["Más tranquila con personajes nuevos"], control = interruptor("calmaNuevos"), hija = true, activa = hablaMas,
		texto = L["Hasta el nivel 10, en tu primera hora de juego Lya habla mucho menos: hay mucho que aprender y no quiere abrumarte. Lo importante te lo dice igual."] })
	consejos:Fila({ titulo = L["Sonido suave"], control = interruptor("sonido"), activa = visible,
		texto = L["Un clic bajito cuando Lya te dice algo."] })
	consejos:Fila({ titulo = L["Tamaño de su letra"], activa = visible,
		texto = L["Qué tan grande escribe Lya en su globo. También con clic derecho sobre ella."],
		control = function(fila) return K.Desplegable(fila, { opciones = LETRAS, clave = ID .. ".letra", ancho = 200 }) end })
	-- 1.2.7: el globo compacto y su consejo en las mazmorras.
	consejos:Fila({ titulo = L["Globo compacto"], control = interruptor("compacto"), activa = visible,
		texto = L["El globo de Lya en una sola línea, con sus botones. Pasa el ratón encima para leerlo completo."] })
	consejos:Fila({ titulo = L["Lya en las mazmorras"], control = interruptor("mazmorras"), activa = visible,
		texto = L["Al entrar a una mazmorra, Lya te da un consejo corto y un botón para verla. Nunca en combate."] })
	consejos:Fila({ titulo = L["Lya te dice los avisos"], control = interruptor("avisos"), activa = visible,
		texto = L["Los avisos pequeños de Alfa los dice Lya en su globo, con su botón, en vez de salir arriba. Si está oculta o en combate, salen como siempre."] })
	consejos:Fila({ titulo = L["Aullar al completar una misión"], control = interruptor("aullidoMision"),
		texto = L["Un aullido corto cada vez que entregas una misión. Viene apagado."] })
	consejos:Fila({ titulo = L["Aullar con tu grupo"], control = interruptor("aullarGrupo"), activa = visible,
		texto = L["Cuando alguien de tu grupo sube de nivel, Lya aúlla, lo felicita y te deja felicitarlo en el chat con un clic."] })
	consejos:Fila({ titulo = L["Brincar al llegar"], control = interruptor("brincoLlegar"), activa = visible, -- 1.3.7c
		texto = L["Cuando llegas a donde apunta la flecha, Lya da un brinco de gusto. Sin palabras ni sonido."] })
	consejos:Fila({ titulo = L["Consejos vistos"], activa = visible,
		texto = L["Cada frase sale tres veces como mucho. Con esto vuelven a salir desde el principio."],
		control = function(fila) return K.Boton(fila, L["Volver a mostrarlos"], function() Ce.OlvidarVistos() end, { tipo = "secundario", tam = "chico" }) end })

	local Hi = M.Historias
	local historias = K.GrupoAjustes(padre, { titulo = L["Historias y datos curiosos"] })
	local function cuenta() return visible() and Hi and Hi.Modo() ~= "pedir" and Hi.Modo() ~= "nunca" end
	historias:Fila({ titulo = L["Lya cuenta historias"], activa = visible,
		texto = L["Siempre: te ofrece la historia de cada misión y un dato de cada zona nueva. A veces: de las misiones que tomas sin leer, y no siempre. Solo si le pido: con clic derecho, «Cuéntame algo de aquí». Las historias se guardan igual."],
		control = function(fila) return K.Desplegable(fila, { opciones = MODOS_HISTORIA, clave = ID .. ".historias", ancho = 200 }) end })
	historias:Fila({ titulo = L["Minutos entre historias"], hija = true, activa = cuenta,
		control = deslizador("minutosHistoria", 3, 60, 1, function(v) return format(L["%d min"], floor(v + 0.5)) end),
		texto = L["Lo menos que espera Lya entre una historia y otra. Nunca en combate ni en mazmorras."] })
	historias:Fila({ titulo = L["El final de cada misión"], hija = true, activa = cuenta, control = interruptor("epilogo"),
		texto = L["Al entregar una misión, Lya te ofrece contarte cómo terminó."] })
	historias:Fila({ titulo = L["Tus historias"],
		texto = L["Todas las misiones que Lya te guardó, por zona, con su historia completa. También con /alfa historias."],
		control = function(fila) return K.Boton(fila, L["Abrir Historias"], function() if Hi then Hi.Abrir() end end, { tipo = "secundario", tam = "chico", icono = "ic-misiones" }) end })
	-- 1.2.8: tu historia, el fin de la mazmorra, tus oficios y lo que aprende.
	local nota = K.GrupoAjustes(padre, { titulo = L["Lo que Lya nota"] })
	nota:Fila({ titulo = L["Tu historia"], control = interruptor("historia"),
		texto = L["Lya apunta tus pasos grandes (tu primera mazmorra, tus niveles, tu primera montura...) y festeja cada página nueva."] })
	nota:Fila({ titulo = L["Al salir de una mazmorra"], control = interruptor("finMazmorra"), activa = visible,
		texto = L["Lya te cuenta cuánto tardaron, cuántas veces caíste y lo mejor que sacaste."] })
	nota:Fila({ titulo = L["Tus oficios"], control = interruptor("oficios"),
		texto = L["Cuando un oficio llega al tope de su rango, Lya te dice que ya puedes aprender el siguiente y dónde está tu instructor."] })
	nota:Fila({ titulo = L["Lya aprende"], control = interruptor("aprende"), activa = visible,
		texto = L["Si cierras tres veces el mismo tipo de consejo, Lya te pregunta si ya no quieres que te lo diga."] })

	-- 1.2.9: al caer, la hora y la fiesta, tu clase y el modo foco.
	local contigo = K.GrupoAjustes(padre, { titulo = L["Lya contigo"] })
	contigo:Fila({ titulo = L["Cuando caes"], control = interruptor("muerte"), activa = visible,
		texto = L["Como espíritu, Lya te dice a cuánto está tu cuerpo, lo que cuesta el ángel a tu nivel y qué conviene. La flecha te lleva."] })
	contigo:Fila({ titulo = L["La hora, la fiesta y el lugar"], control = interruptor("momento"), activa = visible,
		texto = L["Lya platica según la hora del día, las fiestas de Azeroth y la zona donde andas."] })
	contigo:Fila({ titulo = L["Lya te enseña tu clase"], control = interruptor("clase"), activa = visible,
		texto = L["Cuando aprendes un hechizo importante de tu clase, Lya te dice para qué sirve y cuándo usarlo."] })
	contigo:Fila({ titulo = L["Modo foco"], control = interruptor("foco"), activa = visible,
		texto = L["En mazmorras y en combate Lya se hace chiquita, se calla y no estorba tus clics. Al terminar vuelve."] })

	-- 1.3.0: su manada, tus misiones en su voz, tu mascota, los retos y los cumpleaños.
	local mundo = K.GrupoAjustes(padre, { titulo = L["Lya y su manada"] })
	mundo:Fila({ titulo = L["Las Lyas de tu grupo"], control = interruptor("manada"), activa = visible,
		texto = L["Si alguien de tu grupo también trae Alfa, sus Lyas se saludan y a veces platican. Poquito y nunca en combate."] })
	mundo:Fila({ titulo = L["Tus misiones en su voz"], control = interruptor("misionVoz"), activa = visible,
		texto = L["Al tomar una misión, Lya te la resume en dos líneas: qué hay que hacer y un consejito suyo."] })
	mundo:Fila({ titulo = L["Lya y tu mascota"], control = interruptor("mascota"), activa = visible,
		texto = L["Lya saluda a tu mascota y, si eres cazador, te avisa cuando tiene hambre o está triste."] })
	mundo:Fila({ titulo = L["Retos de la semana"], control = interruptor("retos"),
		texto = L["Cada lunes, tres retos chiquitos con su salchicha de premio. Tu avance sale arriba, en esta página."] })
	mundo:Fila({ titulo = L["Cumpleaños"], control = interruptor("cumple"),
		texto = L["Cada año, el día que empezaron a cazar juntos, Lya lo festeja. Y también el cumpleaños de Alfa."] })

	local Ap = M.Aprende
	local callados = K.GrupoAjustes(padre, { titulo = L["Consejos que callaste"] })
	callados.vacia = callados:Fila({ titulo = L["Ninguno por ahora"],
		texto = L["Si le dices «Ya no» a un consejo, sale aquí para que puedas devolverlo cuando quieras."] })
	callados.pool = {}
	for i = 1, 16 do
		local fila
		fila = callados:Fila({ titulo = "", control = function(f)
			return K.Boton(f, L["Devolver"], function() if Ap and fila and fila.alfaClave then Ap.Devolver(fila.alfaClave) end end,
				{ tipo = "secundario", tam = "chico" })
		end })
		K.Mostrar(fila, false)
		callados.pool[i] = fila
	end
	-- 1.3.7 (161): aquí caben 16; los que no caben se cuentan (y se devuelven con «todos»).
	callados.mas = callados:Fila({ titulo = "", texto = L["Aquí caben 16. Devuelve alguno de arriba para ver los demás, o devuélvelos todos."] })
	K.Mostrar(callados.mas, false)
	callados.todos = callados:Fila({ titulo = L["Todos los que callaste"],
		texto = L["Lya vuelve a decirte todos esos consejos."],
		control = function(f) return K.Boton(f, L["Devolverlos todos"], function() if Ap then Ap.DevolverTodos() end end, { tipo = "secundario", tam = "chico" }) end })
	function callados:Llenar()
		local lista = Ap and Ap.Lista() or {}
		for i, fila in ipairs(self.pool) do
			local e = lista[i]
			fila.alfaClave = e and e.clave or nil
			if e then
				fila.alfaDatos.titulo = e.nombre
				fila.alfaDatos.texto = e.fecha and format(L["Lo callaste el %s."], fechaBonita(e.fecha)) or ""
			end
			K.Mostrar(fila, e ~= nil)
		end
		local fuera = #lista - #self.pool
		if fuera > 0 then self.mas.alfaDatos.titulo = format(L["Y %d más"], fuera) end
		K.Mostrar(self.mas, fuera > 0)
		self.todos.alfaDatos.titulo = #lista > 1 and format(L["Todos los que callaste (%d)"], #lista) or L["Todos los que callaste"]
		K.Mostrar(self.vacia, #lista == 0)
		K.Mostrar(self.todos, #lista > 1)
	end
	return { ella, consejos, historias, nota, contigo, mundo, callados }
end

---------------------------------------------------------------------------
-- 1.2.8: Tu historia (TuHistoria.lua)
---------------------------------------------------------------------------
local MOSTRAR = 8

local function tuHistoria(padre)
	local p = K.Pila(padre, { espacio = K.ESP.m })
	p.Seccion = p:Agregar(K.Seccion(p, L["Tu historia"]))
	p.Rejilla = p:Agregar(K.Rejilla(p, { min = 260, variante = "normal" }))
	function p:Llenar()
		local Di = M.Diario
		local lista = Di and Di.Lista() or {}
		local datos = {}
		for i = 1, math.min(MOSTRAR, #lista) do
			local e = lista[i]
			datos[i] = { icono = e.icono or "ic-huella", tono = "acento", sobre = fechaBonita(e.fecha),
				titulo = Di.Titulo(e), texto = Di.Linea(e) }
		end
		if #datos == 0 then
			datos[1] = { icono = "ic-huella", tono = "neutro", titulo = L["Tu historia empieza pronto"],
				texto = (Di and not Di.Activo()) and L["El diario está apagado. Préndelo abajo, en «Lo que Lya nota»."]
					or L["Lya apunta aquí tus pasos grandes: tu primera mazmorra, tus niveles, tu primera montura y más."] }
		end
		self.Rejilla:Llenar(datos)
		self.Seccion:Set(L["Tu historia"], { cuenta = #lista > 0 and #lista or nil,
			enlace = #lista > 0 and Di and { texto = L["Que Lya te la cuente"], alClic = function() Di.Contar() end } or nil })
	end
	return p
end

---------------------------------------------------------------------------
-- 1.3.0: los retos de la semana (Retos.lua)
---------------------------------------------------------------------------
local function retos(padre)
	local p = K.Pila(padre, { espacio = K.ESP.m })
	p.Seccion = p:Agregar(K.Seccion(p, L["Retos de la semana"]))
	p.Rejilla = p:Agregar(K.Rejilla(p, { min = 220, variante = "normal" }))
	function p:Llenar()
		local Re = M.Retos
		local datos = {}
		local on = Re and N.Get(ID, "retos") ~= false
		if on then
			for i, e in ipairs(Re.Lista()) do
				datos[i] = { icono = e.icono, tono = e.hecho and "exito" or "acento", titulo = e.titulo,
					texto = e.hecho and L["¡Cumplido! Salchicha ganada."] or L["Un reto de Lya para esta semana."],
					progreso = { actual = e.actual, total = e.total, texto = format(L["%d de %d"], e.actual, e.total) } }
			end
		else
			datos[1] = { icono = "ic-exito", tono = "neutro", titulo = L["Retos apagados"],
				texto = L["Préndelos abajo, en «Lya y su manada»."] }
		end
		self.Rejilla:Llenar(datos)
		local n = on and Re.Premios() or 0
		self.Seccion:Set(L["Retos de la semana"], { cuenta = n > 0 and format(L["%d salchichas de premio"], n) or nil })
	end
	return p
end

local function recuerdo(padre)
	local t = K.Tarjeta(padre, { variante = "normal" })
	t:Set({
		icono = "ic-huella", tono = "acento", sobre = L[M.RECUERDO_PIE], titulo = L[M.RECUERDO_TITULO],
		texto = L[M.RECUERDO],
	})
	return t
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
local function construir(view)
	local ui = {}
	M.paginaUI = ui -- (para el banco)
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado", tituloOpciones = L["Sus consejos"], min = 240 })
	ui.historia = t:AgregarBloque(tuHistoria(t.Extra))
	ui.retos = t:AgregarBloque(retos(t.Extra))
	ui.recuerdo = t:AgregarBloque(recuerdo(t.Extra))
	ui.ajustes = grupos(t.Extra)
	for i, g in ipairs(ui.ajustes) do t:AgregarBloque(g, { espacio = i == 1 and K.ESP.xl or K.ESP.l }) end
	K.EnPagina(view, t, function()
		t:SetAccion(estado())
		t:SetOpciones(numeros(), L["Lo que te ha contado"])
		ui.historia:Llenar()
		ui.retos:Llenar()
		for _, g in ipairs(ui.ajustes) do
			if g.Llenar then g:Llenar() end
			g:Refrescar()
		end
	end)
	M.vista = view
end

M.Avisar = function()
	local view = M.vista
	if view then N.RehacerPagina(view) end
end

---------------------------------------------------------------------------
-- Para la búsqueda de ajustes de la ventana de Alfa (la página es propia):
-- los mismos ajustes y botones de arriba, con su texto y atenuados igual.
---------------------------------------------------------------------------
local function clave(k) return ID .. "." .. k end
local function no(fn) return function() return not fn() end end
local function cuentaHistorias()
	local Hi = M.Historias
	return visible() and Hi and Hi.Modo() ~= "pedir" and Hi.Modo() ~= "nunca"
end
local function elegir(lista)
	local t = {}
	for i, o in ipairs(lista) do t[i] = { value = o.valor, label = o.texto } end
	return t
end
local function minutos(v) return format(L["%d min"], floor(v + 0.5)) end

local CONTROLES = {
	{ kind = "toggle", key = clave("mostrar"), label = L["Mostrar a Lya"],
		help = L["Tu loba compañera: te da consejos y ánimo. También con /alfa lya."], search = "companion, wolf, pet, show lya, hide lya" },
	{ kind = "slider", key = clave("tamano"), label = L["Tamaño"], min = 48, max = 96, step = 4,
		format = function(v) return format(L["%d px"], floor(v + 0.5)) end,
		disabled = no(visible), help = L["Qué tan grande se ve Lya."], search = "lya size, scale" },
	{ kind = "toggle", key = clave("bloqueado"), label = L["Bloquear su lugar"], disabled = no(visible),
		help = L["Para no moverla sin querer. Sin bloquear, arrástrala a donde quieras."], search = "lock lya, move" },
	{ kind = "dropdown", key = clave("frecuencia"), label = L["Cuántos consejos"], choices = elegir(MODOS), disabled = no(visible),
		help = L["Muchos: consejos del momento y de vez en cuando uno de Alfa. Pocos: menos seguido. Solo importantes: al morir, al subir de nivel y en tus logros."],
		search = "tips frequency, how often, chatty" },
	{ kind = "slider", key = clave("minutos"), label = L["Minutos entre consejos"], min = 2, max = 30, step = 1, format = minutos,
		child = true, disabled = no(hablaMas),
		help = L["Lo menos que espera Lya entre un consejo y otro. Lo importante no espera."], search = "tips interval, minutes" },
	{ kind = "toggle", key = clave("calmaNuevos"), label = L["Más tranquila con personajes nuevos"], child = true, disabled = no(hablaMas),
		help = L["Hasta el nivel 10, en tu primera hora de juego Lya habla mucho menos: hay mucho que aprender y no quiere abrumarte. Lo importante te lo dice igual."],
		search = "new player, beginner, quiet, less tips, nuevo, novato, tranquila" },
	{ kind = "toggle", key = clave("sonido"), label = L["Sonido suave"], disabled = no(visible),
		help = L["Un clic bajito cuando Lya te dice algo."], search = "lya sound" },
	-- 1.3.7 (156): los 4 que la búsqueda no encontraba.
	{ kind = "dropdown", key = clave("letra"), label = L["Tamaño de su letra"], choices = elegir(LETRAS), disabled = no(visible),
		help = L["Qué tan grande escribe Lya en su globo. También con clic derecho sobre ella."],
		search = "lya font size, text size, bigger text, letra, tamaño de letra" },
	{ kind = "toggle", key = clave("avisos"), label = L["Lya te dice los avisos"], disabled = no(visible),
		help = L["Los avisos pequeños de Alfa los dice Lya en su globo, con su botón, en vez de salir arriba. Si está oculta o en combate, salen como siempre."],
		search = "notifications, toasts, alerts, lya says, avisos, notificaciones" },
	{ kind = "toggle", key = clave("aullidoMision"), label = L["Aullar al completar una misión"],
		help = L["Un aullido corto cada vez que entregas una misión. Viene apagado."],
		search = "howl, quest complete, quest turned in, sound, aullido, mision" },
	{ kind = "toggle", key = clave("aullarGrupo"), label = L["Aullar con tu grupo"], disabled = no(visible),
		help = L["Cuando alguien de tu grupo sube de nivel, Lya aúlla, lo felicita y te deja felicitarlo en el chat con un clic."],
		search = "group level up, party, congratulate, grats, gz, felicitar, grupo" },
	{ kind = "toggle", key = clave("brincoLlegar"), label = L["Brincar al llegar"], disabled = no(visible), -- 1.3.7c
		help = L["Cuando llegas a donde apunta la flecha, Lya da un brinco de gusto. Sin palabras ni sonido."],
		search = "arrive, arrival, hop, jump, arrow, llegar, brinco, flecha" },
	-- 1.2.7
	{ kind = "toggle", key = clave("compacto"), label = L["Globo compacto"], disabled = no(visible),
		help = L["El globo de Lya en una sola línea, con sus botones. Pasa el ratón encima para leerlo completo."], search = "compact bubble, one line, small" },
	{ kind = "toggle", key = clave("mazmorras"), label = L["Lya en las mazmorras"], disabled = no(visible),
		help = L["Al entrar a una mazmorra, Lya te da un consejo corto y un botón para verla. Nunca en combate."], search = "dungeon tip, instance" },
	{ kind = "button", label = L["Consejos vistos"], button = L["Volver a mostrarlos"], icon = "reset", disabled = no(visible),
		help = L["Cada frase sale tres veces como mucho. Con esto vuelven a salir desde el principio."],
		onClick = function() Ce.OlvidarVistos() end, search = "seen tips, show again" },
	{ kind = "dropdown", key = clave("historias"), label = L["Lya cuenta historias"], choices = elegir(MODOS_HISTORIA), disabled = no(visible),
		help = L["Siempre: te ofrece la historia de cada misión y un dato de cada zona nueva. A veces: de las misiones que tomas sin leer, y no siempre. Solo si le pido: con clic derecho, «Cuéntame algo de aquí». Las historias se guardan igual."],
		search = "quest stories, lore, fun facts" },
	{ kind = "slider", key = clave("minutosHistoria"), label = L["Minutos entre historias"], min = 3, max = 60, step = 1, format = minutos,
		child = true, disabled = no(cuentaHistorias),
		help = L["Lo menos que espera Lya entre una historia y otra. Nunca en combate ni en mazmorras."], search = "stories interval, minutes" },
	{ kind = "toggle", key = clave("epilogo"), label = L["El final de cada misión"], child = true, disabled = no(cuentaHistorias),
		help = L["Al entregar una misión, Lya te ofrece contarte cómo terminó."], search = "quest epilogue, ending" },
	-- 1.2.8
	{ kind = "toggle", key = clave("historia"), label = L["Tu historia"],
		help = L["Lya apunta tus pasos grandes (tu primera mazmorra, tus niveles, tu primera montura...) y festeja cada página nueva."], search = "diary, milestones, journal, history" },
	{ kind = "toggle", key = clave("finMazmorra"), label = L["Al salir de una mazmorra"], disabled = no(visible),
		help = L["Lya te cuenta cuánto tardaron, cuántas veces caíste y lo mejor que sacaste."], search = "dungeon summary, run, loot, deaths" },
	{ kind = "toggle", key = clave("oficios"), label = L["Tus oficios"],
		help = L["Cuando un oficio llega al tope de su rango, Lya te dice que ya puedes aprender el siguiente y dónde está tu instructor."], search = "professions, skill cap, trainer, rank" },
	{ kind = "toggle", key = clave("aprende"), label = L["Lya aprende"], disabled = no(visible),
		help = L["Si cierras tres veces el mismo tipo de consejo, Lya te pregunta si ya no quieres que te lo diga."], search = "learn, mute tips, stop telling" },
	-- 1.2.9
	{ kind = "toggle", key = clave("muerte"), label = L["Cuando caes"], disabled = no(visible),
		help = L["Como espíritu, Lya te dice a cuánto está tu cuerpo, lo que cuesta el ángel a tu nivel y qué conviene. La flecha te lleva."], search = "death, corpse, spirit healer, ghost, durability" },
	{ kind = "toggle", key = clave("momento"), label = L["La hora, la fiesta y el lugar"], disabled = no(visible),
		help = L["Lya platica según la hora del día, las fiestas de Azeroth y la zona donde andas."], search = "time of day, holidays, events, festival, zone" },
	{ kind = "toggle", key = clave("clase"), label = L["Lya te enseña tu clase"], disabled = no(visible),
		help = L["Cuando aprendes un hechizo importante de tu clase, Lya te dice para qué sirve y cuándo usarlo."], search = "class spells, new spell, trainer, abilities" },
	{ kind = "toggle", key = clave("foco"), label = L["Modo foco"], disabled = no(visible),
		help = L["En mazmorras y en combate Lya se hace chiquita, se calla y no estorba tus clics. Al terminar vuelve."], search = "focus mode, quiet, small, combat, dungeon" },
	-- 1.3.0
	{ kind = "toggle", key = clave("manada"), label = L["Las Lyas de tu grupo"], disabled = no(visible),
		help = L["Si alguien de tu grupo también trae Alfa, sus Lyas se saludan y a veces platican. Poquito y nunca en combate."], search = "group, party, greet, other lya, wolves" },
	{ kind = "toggle", key = clave("misionVoz"), label = L["Tus misiones en su voz"], disabled = no(visible),
		help = L["Al tomar una misión, Lya te la resume en dos líneas: qué hay que hacer y un consejito suyo."], search = "quest summary, objectives, two lines" },
	{ kind = "toggle", key = clave("mascota"), label = L["Lya y tu mascota"], disabled = no(visible),
		help = L["Lya saluda a tu mascota y, si eres cazador, te avisa cuando tiene hambre o está triste."], search = "pet, hunter, warlock, happiness, feed" },
	{ kind = "toggle", key = clave("retos"), label = L["Retos de la semana"],
		help = L["Cada lunes, tres retos chiquitos con su salchicha de premio. Tu avance sale arriba, en esta página."], search = "weekly challenges, goals, sausage, reward" },
	{ kind = "toggle", key = clave("cumple"), label = L["Cumpleaños"],
		help = L["Cada año, el día que empezaron a cazar juntos, Lya lo festeja. Y también el cumpleaños de Alfa."], search = "birthday, anniversary, celebration" },
	{ kind = "button", label = L["Consejos que callaste"], button = L["Devolverlos todos"], icon = "reset",
		help = L["Lya vuelve a decirte todos esos consejos."],
		onClick = function() if M.Aprende then M.Aprende.DevolverTodos() end end, search = "muted tips, restore" },
	{ kind = "button", label = L["Tus historias"], button = L["Abrir Historias"], icon = "info",
		needs = function() return M.Historias ~= nil end,
		help = L["Todas las misiones que Lya te guardó, por zona, con su historia completa. También con /alfa historias."],
		onClick = function() if M.Historias then M.Historias.Abrir() end end, search = "stories window, quest log lore" },
}

N.Modulo({
	id = ID, nombre = L["Lya"], icono = "ic-lobo", orden = 48, seccion = "personaje",
	subtitulo = L["Tu loba compañera: consejos cortos, ánimo y nunca te deja atrás."],
	ajustes = M.AJUSTES,
	controles = CONTROLES,
	construir = construir,
})
