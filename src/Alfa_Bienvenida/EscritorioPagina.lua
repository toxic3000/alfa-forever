-- Alfa - Bienvenida: la página «Dos pantallas» en Ajustes (1.3.8).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Arriba, cómo está tu escritorio (con «Acomodar mis pantallas» o «Editar
-- escritorio» y «Volver a una pantalla»); abajo, tu escritorio (cambiar solo,
-- el fondo, el mapa dentro de su panel), cuándo cambia (qué distribución va en
-- cada momento) y lo avanzado (mover el mundo y la interfaz). La búsqueda de
-- Alfa encuentra todo con «dos monitores», «segundo monitor», «ultrawide»…
-- y Lya lo explica en «¿En qué te ayudo?».

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP
local Es = M.Escritorio
local ID = Es.ID

local format = string.format

local vista

local function estado()
	local g = Es.Aplicado()
	if g then
		local donde = g.una and L["Tu escritorio está a un lado de la pantalla"] or L["Tu escritorio está en el otro monitor"]
		return {
			icono = "ic-ventana", tono = "acento", sobre = L["Dos pantallas"], titulo = donde,
			texto = format(L["Distribución: %s. Arrastra y acomoda tus paneles con «Editar escritorio»."], Es.NombreDe(Es.Actual()) or ""),
			accion = { texto = L["Editar escritorio"], icono = "ic-ajustes", alClic = function() if M.EscritorioEditor then M.EscritorioEditor.Abrir() end end },
			secundaria = { texto = L["Volver a una pantalla"], alClic = function() Es.Apagar() M.EscritorioPagina.Refrescar() end },
		}
	end
	local s = Es.Sugerencia()
	local e = {
		icono = "ic-ventana", tono = "acento", sobre = L["Dos pantallas"], titulo = L["Alfa en tu segundo monitor"],
		texto = s.motivo == "una" and L["Deja el juego en tu monitor principal y pon tus paneles de Alfa en el otro: tu guía, la flecha, el mapa, el medidor, Lya y más. Con un monitor, también a un lado."]
			or L["Tu ventana es muy ancha: deja el juego en tu monitor principal y pon tus paneles de Alfa en vivo en el otro."],
		accion = { texto = L["Acomodar mis pantallas"], icono = "ic-ventana", alClic = function() Es.AbrirAsistente(true) end },
	}
	-- 1.3.8: con otro monitor libre, todo en un clic; el asistente queda «a mano».
	local Au = M.EscritorioAuto
	if Au and Au.PuedeUnClic() then
		e.titulo = L["Vi que tienes otro monitor. ¿Pongo Alfa ahí?"]
		e.texto = L["Estiro la ventana del juego a tus dos monitores: el juego se queda en este y tus paneles de Alfa van al otro. Lo pruebas 15 segundos antes de guardar."]
		e.accion = { texto = L["Sí, en un clic"], icono = "ic-ventana", alClic = function() Au.UnClic() end }
		e.secundaria = { texto = L["Ajustar a mano"], alClic = function() Es.AbrirAsistente(true) end }
	end
	return e
end

local function opcionesDistribucion()
	local out = {}
	for _, d in ipairs(Es.Distribuciones()) do out[#out + 1] = { valor = d.id, texto = d.nombre, icono = d.icono } end
	return out
end

local function grupos(padre)
	local tuyo = K.GrupoAjustes(padre, { titulo = L["Tu escritorio"] })
	tuyo:Fila({ titulo = L["Acomodar mis pantallas"], texto = L["El asistente con el dibujo de tus monitores: qué proporción tiene el principal y de qué lado está el otro, y probar antes de guardar."],
		control = function(f) return K.Boton(f, L["Abrir"], function() Es.AbrirAsistente(true) end, { tipo = "secundario", icono = "ic-ventana" }) end })
	tuyo:Fila({ titulo = L["Cambiar el escritorio solo"], texto = L["En una mazmorra, pescando o en la subasta, Alfa pone los paneles que te sirven ahí."],
		control = function(f) return K.Interruptor(f, { clave = ID .. ".auto", alCambiar = function() Es.RevisarContexto(true) end }) end })
	-- 1.4.0: el tamaño de los paneles y sus letras.
	tuyo:Fila({ titulo = L["Tamaño de los paneles"], texto = L["Más grande se lee mejor desde lejos; más chico cabe más."],
		control = function(f)
			local ops = {}
			for _, t in ipairs(Es.TAMANOS) do ops[#ops + 1] = { valor = t.valor, texto = L[t.texto] } end
			return K.Desplegable(f, { ancho = 160, opciones = ops, get = function() return N.Get(ID, "tamano") end,
				set = function(v) N.Set(ID, "tamano", v) Es.PonerEscala() end })
		end })
	tuyo:Fila({ titulo = L["Fondo del escritorio"], texto = L["Una noche de Alfa detrás de los paneles: cielo, estrellas, la luna y el lobo. Apágalo si quieres ver lo que haya detrás."],
		control = function(f) return K.Interruptor(f, { clave = ID .. ".fondo", alCambiar = function() K.Repintar() end }) end })
	tuyo:Fila({ titulo = L["El mapa dentro de su panel"], texto = L["El mapa de Alfa se pone solo dentro del panel «Mapa». Apagado, el panel dice dónde estás y lo abres con un clic."],
		control = function(f) return K.Interruptor(f, { clave = ID .. ".mapaDentro" }) end })
	tuyo:Fila({ titulo = L["Avisarme si mi ventana es de dos monitores"], texto = L["Una vez: si tu ventana es mucho más ancha que un monitor, Alfa te ofrece el escritorio."],
		control = function(f) return K.Interruptor(f, { clave = ID .. ".ofrecer" }) end })
	-- 1.4.0: si la ventana o la interfaz quedaron raras después de Dos pantallas.
	tuyo:Fila({ titulo = L["Reparar mi pantalla"], texto = L["Si después de usar Dos pantallas la ventana o la interfaz del juego quedaron de otro tamaño, las dejo como estaban."],
		control = function(f) return K.Boton(f, L["Reparar"], function() if M.EscritorioReparar then M.EscritorioReparar.Preguntar() end end, { tipo = "secundario", icono = "ic-ajustes" }) end })
	-- Qué distribución va en cada momento.
	local cuando = K.GrupoAjustes(padre, { titulo = L["Qué escritorio va en cada momento"] })
	cuando.desplegables = {}
	for _, c in ipairs(Es.CONTEXTOS) do
		local d
		cuando:Fila({ titulo = L[c.texto], texto = "",
			control = function(f)
				d = K.Desplegable(f, { ancho = 200, opciones = opcionesDistribucion(),
					get = function() return Es.Regla(c.id) end, set = function(v) Es.PonerRegla(c.id, v) end })
				return d
			end, activa = function() return N.Get(ID, "auto") ~= false end })
		cuando.desplegables[#cuando.desplegables + 1] = d
	end
	local refrescarCuando = cuando.Refrescar
	function cuando:Refrescar()
		for _, d in ipairs(self.desplegables) do d:SetOpciones(opcionesDistribucion()) end
		refrescarCuando(self)
	end
	-- Lo avanzado.
	local avanzado = K.GrupoAjustes(padre, { titulo = L["Avanzado"] })
	local function reponer() if Es.Aplicado() then Es.Aplicar() end end
	avanzado:Fila({ titulo = L["Poner el mundo en el monitor principal"], texto = L["El mundo se dibuja solo en tu monitor principal y no detrás de Alfa."],
		control = function(f) return K.Interruptor(f, { clave = ID .. ".moverMundo", alCambiar = reponer }) end,
		activa = function() return not Es.OtroLoHace() end })
	avanzado:Fila({ titulo = L["Poner la interfaz del juego en el principal"], texto = L["Tus barras, tu retrato, el minimapa, el chat y las misiones se quedan contigo."],
		control = function(f) return K.Interruptor(f, { clave = ID .. ".moverInterfaz", alCambiar = reponer }) end,
		activa = function() return not Es.OtroLoHace() end })
	avanzado:Fila({ titulo = L["Tus escritorios guardados"], texto = L["Los que guardaste con «Guardar como…» en el editor. Bórralos desde su menú en la barra del escritorio."],
		control = function(f) return K.Boton(f, L["Editar escritorio"], function() if M.EscritorioEditor then M.EscritorioEditor.Abrir() end end, { tipo = "secundario" }) end,
		activa = function() return Es.Aplicado() ~= nil end })
	return { tuyo, cuando, avanzado }
end

local function construir(view)
	local ui = {}
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado" })
	ui.grupos = grupos(t.Extra)
	for i, g in ipairs(ui.grupos) do t:AgregarBloque(g, { espacio = i == 1 and ESP.xl or ESP.l }) end
	K.EnPagina(view, t, function()
		t:SetAccion(estado())
		for _, g in ipairs(ui.grupos) do g:Refrescar() end
	end)
	vista = view
end

M.EscritorioPagina = {}
function M.EscritorioPagina.Refrescar() if vista then N.RehacerPagina(vista) end end
A.On("ALFA_ESCRITORIO", function() M.EscritorioPagina.Refrescar() end)
Es.AlAplicar(function() M.EscritorioPagina.Refrescar() end)

-- Para la búsqueda de Alfa.
local BUSCAR = "second monitor, dual monitor, two monitors, two screens, multi monitor, multiple monitors, ultrawide, super ultrawide, 32:9, 21:9, offhand, companion, desktop, dashboard, panels, segundo monitor, dos monitores, dos pantallas, otra pantalla, escritorio, paneles, tablero"
local CONTROLES = {
	{ kind = "button", label = L["Acomodar mis pantallas"], button = L["Abrir"], icon = "info",
		help = L["El asistente con el dibujo de tus monitores: qué proporción tiene el principal y de qué lado está el otro, y probar antes de guardar."],
		onClick = function() Es.AbrirAsistente(true) end, search = BUSCAR },
	{ kind = "button", label = L["Editar escritorio"], button = L["Editar"], icon = "info",
		help = L["Mueve los paneles, cámbiales el tamaño y agrega otros."],
		onClick = function() if M.EscritorioEditor then M.EscritorioEditor.Abrir() end end, search = "edit desktop, layout, panels, move panels, editar escritorio, paneles, acomodar" },
	{ kind = "button", label = L["Volver a una pantalla"], button = L["Volver"], icon = "info",
		help = L["El juego y su interfaz vuelven a toda la ventana, como siempre."],
		onClick = function() Es.Apagar() end, search = "one screen, single monitor, reset screen, undo monitors, una pantalla, volver" },
	{ kind = "button", label = L["Reparar mi pantalla"], button = L["Reparar"], icon = "info",
		help = L["Si después de usar Dos pantallas la ventana o la interfaz del juego quedaron de otro tamaño, las dejo como estaban."],
		onClick = function() if M.EscritorioReparar then M.EscritorioReparar.Preguntar() end end,
		search = "repair screen, fix screen, ui scale, interface too big, window size, reparar pantalla, escala, interfaz grande, letra grande" },
	{ kind = "toggle", key = ID .. ".auto", label = L["Cambiar el escritorio solo"],
		help = L["En una mazmorra, pescando o en la subasta, Alfa pone los paneles que te sirven ahí."], search = "auto layout, switch layout, context, automatic, cambiar solo, distribucion" },
	{ kind = "toggle", key = ID .. ".fondo", label = L["Fondo del escritorio"],
		help = L["Una noche de Alfa detrás de los paneles: cielo, estrellas, la luna y el lobo. Apágalo si quieres ver lo que haya detrás."], search = "desktop background, wallpaper, fondo, noche" },
	{ kind = "toggle", key = ID .. ".mapaDentro", label = L["El mapa dentro de su panel"],
		help = L["El mapa de Alfa se pone solo dentro del panel «Mapa». Apagado, el panel dice dónde estás y lo abres con un clic."], search = "map panel, minimap, big map, mapa" },
	{ kind = "toggle", key = ID .. ".moverMundo", label = L["Poner el mundo en el monitor principal"],
		help = L["El mundo se dibuja solo en tu monitor principal y no detrás de Alfa."], search = "world frame, viewport, 3d view, mundo, vista" },
	{ kind = "toggle", key = ID .. ".moverInterfaz", label = L["Poner la interfaz del juego en el principal"],
		help = L["Tus barras, tu retrato, el minimapa, el chat y las misiones se quedan contigo."], search = "ui parent, game interface, action bars, interfaz, barras" },
}

N.Modulo({
	id = ID, nombre = L["Dos pantallas"], icono = "ic-ventana", orden = 95, seccion = "ajustes",
	subtitulo = L["Alfa en tu segundo monitor, con paneles en vivo."],
	comando = nil,
	ajustes = { activo = false, lado = "derecha", proporcion = "16:9", medida = 70,
		moverMundo = true, moverInterfaz = true, auto = true, ofrecer = true, fondo = true, mapaDentro = true, tamano = "grande",
		distribucion = "aventura" },
	controles = CONTROLES,
	construir = construir,
	restablecer = { fn = function() if Es.Aplicado() then Es.Aplicar() Es.PonerEscala() end end },
})

-- Lya lo explica.
A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) ~= "table" or type(Lya.Ensenar) ~= "function" then return end
	pcall(Lya.Ensenar, { id = "pantallas", icono = "ic-ventana", modulo = ID,
		pregunta = L["¿Puedo usar Alfa en un segundo monitor?"],
		respuesta = L["¡Sí! Estira la ventana del juego sobre tus dos monitores y abre «Dos pantallas»: dejo el juego en el principal y pongo en el otro tu guía, la flecha grande, el mapa, el medidor, tus bolsas y lo que te digo. Con un solo monitor, también va a un lado."],
		palabras = "monitor, monitores, pantalla, pantallas, segundo, ultrawide, escritorio, offhand" })
end)
