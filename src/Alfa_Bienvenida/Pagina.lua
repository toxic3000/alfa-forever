-- Alfa - Bienvenida: la página "Estilo y sonido" en Ajustes (toxic3000 / La
-- Jauría). GPL-3.0.
--
-- Un Tablero del Kit:
--   1. tu estilo de ahora, con "Mi configuración" (el asistente, en su resumen);
--   2. los tres estilos para cambiar en un clic (y, en Cristal, el acento);
--   3. el sonido: el aullido al abrir Alfa y un botón para escucharlo;
--   4. la configuración, lo nuevo de la versión y "Reportar".

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local ESP = K.ESP

local format = string.format

local function estado()
	local e = K.DatosEstilo()
	return {
		icono = e and e.icono or "ic-apariencia", tono = "acento", sobre = L["Tu estilo"],
		titulo = K.NombreEstilo(K.Estilo()) or "",
		texto = e and L[e.texto] or nil,
		accion = { texto = L["Mi configuración"], icono = "ic-ajustes", alClic = function() M.Abrir("pedido", "asistente") end },
		-- La letra, su tamaño, los bordes y la flecha siguen en Ajustes > Apariencia (del motor).
		secundaria = { texto = L["Más opciones de apariencia"], alClic = function() N.Abrir("appearance") end },
	}
end

local function bloqueEstilos(ui, padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Elige tu estilo"]))
	b.Selector = b:Agregar(K.SelectorEstilo(b, { min = 220, alCambiar = function() M.alCambiar() end }))
	b.SecAcento = b:Agregar(K.Seccion(b, L["Tu color de acento"]), { espacio = ESP.l })
	b.Acento = b:Agregar(K.SelectorAcento(b, {}), { espacio = ESP.s })
	function b:Refrescar()
		local cristal = K.Cristal()
		K.Mostrar(self.SecAcento, cristal)
		K.Mostrar(self.Acento, cristal)
		self.Selector:Leer()
		self.Acento:Leer()
	end
	return b
end

local function grupos(ui, padre)
	local sonido = K.GrupoAjustes(padre, { titulo = L["Sonido"] })
	sonido:Fila({ titulo = L["Aullido al abrir Alfa"],
		texto = L["Un aullido de lobo, del propio juego, la primera vez que abres Alfa en cada sesión."],
		control = function(fila) return K.Interruptor(fila, { clave = ID .. ".aullido" }) end })
	sonido:Fila({ titulo = L["El lobo te recibe al entrar"],
		texto = L["Cada vez que entras al juego, la intro del lobo y la luna te da la bienvenida. Un clic o Esc la saltan."],
		control = function(fila) return K.Interruptor(fila, { clave = ID .. ".introSiempre" }) end })
	sonido:Fila({ titulo = L["Escuchar el aullido"], texto = L["Suena ahora, aunque el aullido esté apagado."],
		control = function(fila) return K.Boton(fila, L["Escuchar"], function() M.Aullar(true) end, { tipo = "secundario", icono = "ic-lobo" }) end })

	local bienvenida = K.GrupoAjustes(padre, { titulo = L["Configuración y ayuda"] })
	bienvenida:Fila({ titulo = L["Tu configuración de Alfa"],
		texto = L["El idioma, el estilo, lo que Alfa hace sola por ti y La Jauría, con «Cambiar» en cada cosa. También con /alfa bienvenida."],
		control = function(fila) return K.Boton(fila, L["Abrir"], function() M.Abrir("pedido", "asistente") end, { tipo = "secundario" }) end })
	bienvenida:Fila({ titulo = L["Reportar un error, una mejora o un comentario"],
		texto = L["Alfa arma el reporte y tú lo pegas en el buzón privado del Discord de La Jauría. También con /alfa reportar."],
		control = function(fila) return K.Boton(fila, L["Reportar"], function() M.AbrirReporte() end, { tipo = "secundario" }) end })
	bienvenida:Fila({ titulo = format(L["Lo nuevo en Alfa %s"], M.VERSION_ALFA),
		texto = L["La bienvenida con las novedades de esta versión."],
		control = function(fila) return K.Boton(fila, L["Ver"], function()
			if M.AbrirNotas and M.AbrirNotas() then return end
			M.Abrir("pedido", "portada")
		end, { tipo = "secundario" }) end })
	return { sonido, bienvenida }
end

local function construir(view)
	local ui = {}
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado" })
	ui.estilos = t:AgregarBloque(bloqueEstilos(ui, t.Extra))
	ui.grupos = grupos(ui, t.Extra)
	for i, g in ipairs(ui.grupos) do t:AgregarBloque(g, { espacio = i == 1 and ESP.xl or ESP.l }) end
	K.EnPagina(view, t, function()
		t:SetAccion(estado())
		ui.estilos:Refrescar()
		for _, g in ipairs(ui.grupos) do g:Refrescar() end
	end)
	M.vista = view
end

-- Algo cambió (el estilo, el acento): la página se rehace si está a la vista.
function M.alCambiar()
	local view = M.vista
	if view then N.RehacerPagina(view) end
end
K.AlRepintar(function() M.alCambiar() end)

-- Para la búsqueda de ajustes de la ventana de Alfa (la página es propia):
-- el aullido y los botones de arriba. El estilo y el acento no van: son
-- ui.skin, ui.accent y ui.classAccent, que la búsqueda ya encuentra en
-- Ajustes > Apariencia (cada ajuste sale una sola vez).
local CONTROLES = {
	{ kind = "toggle", key = ID .. ".aullido", label = L["Aullido al abrir Alfa"],
		help = L["Un aullido de lobo, del propio juego, la primera vez que abres Alfa en cada sesión."], search = "howl, wolf sound, sound, opening sound" },
	{ kind = "toggle", key = ID .. ".introSiempre", label = L["El lobo te recibe al entrar"],
		help = L["Cada vez que entras al juego, la intro del lobo y la luna te da la bienvenida. Un clic o Esc la saltan."],
		search = "intro, wolf, moon, login animation, welcome animation" },
	{ kind = "button", label = L["Escuchar el aullido"], button = L["Escuchar"], icon = "info",
		help = L["Suena ahora, aunque el aullido esté apagado."], onClick = function() M.Aullar(true) end, search = "howl, play sound, test sound" },
	{ kind = "button", label = L["Tu configuración de Alfa"], button = L["Abrir"], icon = "info",
		help = L["El idioma, el estilo, lo que Alfa hace sola por ti y La Jauría, con «Cambiar» en cada cosa. También con /alfa bienvenida."],
		onClick = function() M.Abrir("pedido", "asistente") end, search = "setup, welcome, wizard, language, configuration" },
	{ kind = "button", label = L["Reportar un error, una mejora o un comentario"], button = L["Reportar"], icon = "info",
		help = L["Alfa arma el reporte y tú lo pegas en el buzón privado del Discord de La Jauría. También con /alfa reportar."],
		onClick = function() M.AbrirReporte() end, search = "bug report, feedback, suggestion, discord" },
	{ kind = "button", label = function() return format(L["Lo nuevo en Alfa %s"], M.VERSION_ALFA) end, button = L["Ver"], icon = "info",
		help = L["La bienvenida con las novedades de esta versión."],
		onClick = function()
			if M.AbrirNotas and M.AbrirNotas() then return end
			M.Abrir("pedido", "portada")
		end, search = "whats new, changelog, patch notes, release notes, version" },
}

N.Modulo({
	id = ID, nombre = L["Estilo y sonido"], icono = "ic-apariencia", orden = 90, seccion = "ajustes",
	subtitulo = L["Tu estilo (Alfa, Clásico WoW o Cristal), el color de acento y el aullido."],
	comando = "estilo",
	ajustes = { aullido = true, idioma = "", introSiempre = true },
	controles = CONTROLES,
	construir = construir,
})
