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
	consejos:Fila({ titulo = L["Sonido suave"], control = interruptor("sonido"), activa = visible,
		texto = L["Un clic bajito cuando Lya te dice algo."] })
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
	return { ella, consejos, historias }
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
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado", tituloOpciones = L["Sus consejos"], min = 240 })
	ui.recuerdo = t:AgregarBloque(recuerdo(t.Extra))
	ui.ajustes = grupos(t.Extra)
	for i, g in ipairs(ui.ajustes) do t:AgregarBloque(g, { espacio = i == 1 and K.ESP.xl or K.ESP.l }) end
	K.EnPagina(view, t, function()
		t:SetAccion(estado())
		t:SetOpciones(numeros(), L["Lo que te ha contado"])
		for _, g in ipairs(ui.ajustes) do g:Refrescar() end
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
	{ kind = "toggle", key = clave("sonido"), label = L["Sonido suave"], disabled = no(visible),
		help = L["Un clic bajito cuando Lya te dice algo."], search = "lya sound" },
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
