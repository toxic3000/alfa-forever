-- Alfa - Mundo: la página del módulo, sus comandos y su tecla (Toxic / La
-- Jauría). GPL-3.0.
--
-- Hecha con el Kit (docs/KIT.md), plantilla Tablero:
--   1. arriba, en grande: abrir el mapa de Alfa (con lo que hace la tecla M
--      y cuántos marcadores tienes);
--   2. dos tarjetas: el modo limpio y las capas;
--   3. tus marcadores, con seguir, ver en el mapa, compartir y su ficha (o
--      el lobo dormido con cómo poner el primero);
--   4. los ajustes del mapa de Alfa;
--   5. las capas, un grupo a la vez (píldoras), todo lo que se pinta en tus
--      mapas en un solo lugar;
--   6. cómo se usa.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local Capas, V, Lz, Mk, PM = M.Capas, M.Ventana, M.Lienzo, M.Marcadores, M.PanelMarcadores

local type, ipairs, pairs, tonumber, max, min, floor, format = type, ipairs, pairs, tonumber, math.max, math.min, math.floor, string.format
local ESP = K.ESP

local ID = "mundo"
local FILA = 44
local FILAS_VISIBLES = 6

-- La tecla propia (Bindings.xml) en Opciones > Teclado > Alfa.
BINDING_NAME_ALFA_MUNDO_MAPA = L["Abrir o cerrar el mapa de Alfa"]

---------------------------------------------------------------------------
-- 1. La acción grande y 2. las tarjetas
---------------------------------------------------------------------------
local function teclaDelMapa()
	if not GetBindingKey then return nil end
	local k = GetBindingKey("TOGGLEWORLDMAP")
	if type(k) ~= "string" or k == "" then return nil end
	local ok, t = pcall(GetBindingText, k)
	return ok and type(t) == "string" and t ~= "" and t or k
end

local function accion()
	local n = Mk.Cuantos()
	local tecla = teclaDelMapa()
	local conM = A.Get("mundo.teclaM") == true
	local partes = { L["Todo Azeroth en un solo lienzo: acerca con la rueda, arrastra para moverte y pon tus marcadores con clic derecho."] }
	if conM and tecla then
		partes[#partes + 1] = format(L["Tu tecla del mapa (%s) lo abre."], tecla)
	elseif not conM then
		partes[#partes + 1] = L["Para abrirlo con la tecla del mapa, enciende «Abrir el mapa de Alfa con la tecla del mapa» abajo."]
	end
	local insignias = {}
	if conM then insignias[#insignias + 1] = { tecla and format(L["%s abre este mapa"], tecla) or L["La tecla del mapa abre este mapa"], "acento" } end
	if n > 0 then insignias[#insignias + 1] = { n == 1 and L["1 marcador"] or format(L["%d marcadores"], n), "neutro", "ic-huella" } end
	if Capas.Limpio() then insignias[#insignias + 1] = { L["Modo limpio"], "aviso" } end
	return {
		icono = "ic-mundo", sobre = L["Tu mapa"], titulo = L["El mundo entero en un mapa"],
		texto = table.concat(partes, " "), insignias = insignias,
		accion = { texto = L["Mapa de Alfa"], icono = "ic-mundo", alClic = function() V.Abrir() end },
		secundaria = { texto = L["Ir al mapa del juego"], alClic = function() V.AlMapaDelJuego() end },
	}
end

local function encendidas()
	local si, total = 0, 0
	for _, g in ipairs(Capas.Grupos()) do
		for _, e in ipairs(g.capas) do
			total = total + 1
			if Capas.Activa(e) then si = si + 1 end
		end
	end
	return si, total
end

local function tarjetas()
	local limpio = Capas.Limpio()
	local n = Capas.CuantasOcultas()
	local si, total = encendidas()
	return {
		{ icono = "ic-descubrir", titulo = L["Modo limpio"],
			texto = limpio and (n > 0 and format(L["%d capas ocultas. Al salir vuelven como estaban."], n) or L["Solo tú, tu grupo, tus marcadores y el siguiente paso de la guía."])
				or L["Un clic y queda solo lo esencial: tú, tu grupo, tus marcadores y el siguiente paso de la guía."],
			insignias = { { limpio and L["Encendido"] or L["Apagado"], limpio and "acento" or "neutro" } },
			alClic = function() Capas.AlternarLimpio() end,
			secundaria = { texto = limpio and L["Salir del modo limpio"] or L["Activar el modo limpio"],
				alClic = function() Capas.AlternarLimpio() end } },
		{ icono = "ic-comunidad", titulo = L["Capas de Alfa"],
			texto = L["Todo lo que se pinta en tus mapas, en un solo lugar. Lo de otros módulos de Alfa también llega aquí."],
			insignias = { { format(L["%d de %d encendidas"], si, total), "neutro" } },
			secundaria = { texto = L["Elegir capas"],
				alClic = function(boton) M.Panel.Alternar(boton, { punto = "TOPLEFT", relativo = "BOTTOMLEFT", x = 0, y = -6 }) end } },
	}
end

---------------------------------------------------------------------------
-- 3. Tus marcadores
---------------------------------------------------------------------------
local function bloqueMarcadores(ui, padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Tus marcadores"]))
	b.Marco = CreateFrame("Frame", nil, b)
	b.Marco.caja = K.Caja(b.Marco, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.Lista = K.Lista(b.Marco, {
		alto = FILA, elegir = false,
		crear = function(f) PM.CrearFila(f, { mapa = true }) end,
		pintar = function(f, m) PM.PintarFila(f, m) end,
		alClic = function(m) if m then V.IrAMarcador(m) end end,
	})
	b.Lista:SetPoint("TOPLEFT", b.Marco, "TOPLEFT", 4, -4)
	function b.Marco:Acomodar(ancho)
		local n = Mk.Cuantos()
		local h = min(FILAS_VISIBLES, max(1, n)) * FILA
		b.Lista:Acomodar(ancho - 8, h)
		self:SetSize(ancho, h + 8)
		return h + 8
	end
	b:Agregar(b.Marco)
	b.Vacio = b:Agregar(K.Vacio(b, {
		lobo = "dormido", titulo = L["Todavía no tienes marcadores"],
		texto = L["Abre el mapa y haz clic derecho (o Mayús+clic) donde quieras uno: le pones nombre, ícono y color, y la flecha te lleva cuando quieras. En el mapa del juego, Mayús+clic derecho."],
		accion = { texto = L["Mapa de Alfa"], icono = "ic-mundo", alClic = function() V.Abrir() end },
	}), { espacio = ESP.base })
	b.Pista = b:Agregar(K.Texto(b, "pequeno", "textoTenue"), { espacio = ESP.s })
	function b.Pista:Acomodar(ancho) return K.Parrafo(self, ancho) end
	function b:Llenar()
		local n = Mk.Cuantos()
		self.Seccion:Set(L["Tus marcadores"], {
			cuenta = n > 0 and n or nil,
			enlace = n > 0 and { texto = L["Borrar todos"], alClic = function()
				K.Dialogo({ titulo = L["¿Borrar todos tus marcadores?"], texto = format(L["Se borran los %d marcadores de todos tus personajes. No se puede deshacer."], n),
					aceptar = L["Borrar todos"], peligro = true, alAceptar = function() Mk.BorrarTodos() end })
			end } or nil,
		})
		K.Mostrar(self.Marco, n > 0)
		K.Mostrar(self.Vacio, n == 0)
		K.Mostrar(self.Pista, n > 0)
		if n > 0 then
			self.Lista:SetDatos(Mk.Lista(), true)
			local puede, por = Mk.PuedeCompartir()
			K.Escribir(self.Pista, puede and L["Clic en uno: el mapa de Alfa va hasta él. «Seguir» pone la flecha y la ruta; la huella del grupo lo comparte con quien use Alfa."]
				or (L["Clic en uno: el mapa de Alfa va hasta él. «Seguir» pone la flecha y la ruta."] .. " " .. Mk.PorQueNo(por)))
		end
	end
	return b
end

---------------------------------------------------------------------------
-- 4. Los ajustes del mapa
---------------------------------------------------------------------------
local function interruptor(clave)
	return function(fila) return K.Interruptor(fila, { clave = clave }) end
end

-- Los dos estilos del mapa de Alfa (también en el engrane del mapa).
local function opcionesEstilo()
	local roto = Lz.TerrenoRoto()
	return {
		{ valor = "terreno", texto = L["Terreno, como el minimapa"], icono = "ic-mundo",
			apagada = roto or nil, motivo = roto and L["Este cliente no carga los mosaicos del minimapa: se ve el arte pintado."] or nil },
		{ valor = "clasico", texto = L["Clásico, el arte pintado del juego"], icono = "ic-mapa" },
	}
end
M.OpcionesEstilo = opcionesEstilo

local function ajustesMapa(padre)
	local g = K.GrupoAjustes(padre, { titulo = L["El mapa de Alfa"] })
	g:Fila({ titulo = L["Estilo del mapa"],
		texto = L["Terreno: al acercarte se ve el suelo real del minimapa, con sus montañas, ríos y tonos. Clásico: solo el mapa pintado del juego."],
		control = function(fila)
			return K.Desplegable(fila, { clave = "mundo.estiloMapa", ancho = 260, opciones = opcionesEstilo() })
		end })
	g:Fila({ titulo = L["Abrir el mapa de Alfa con la tecla del mapa"], control = interruptor("mundo.teclaM"),
		texto = L["La tecla que abre el mapa del juego (M) abre el de Alfa; en él, un botón te lleva al del juego. Apágalo y la tecla vuelve a abrir el del juego. También puedes darle una tecla propia en Opciones > Teclado > Alfa."] })
	g:Fila({ titulo = L["Botones de Alfa en el mapa del juego"], control = interruptor("mundo.botonMapa"),
		texto = L["Junto a la lupa del mapa del juego: las capas, el modo limpio y «Mapa de Alfa» para cambiar al de Alfa."] })
	g:Fila({ titulo = L["Marcadores con Mayús+clic derecho en el mapa del juego"], control = interruptor("mundo.marcarEnMapaJuego"),
		texto = L["El clic derecho solo sigue alejando el mapa del juego, como siempre."] })
	g:Fila({ titulo = L["Recibir marcadores de tu grupo"], control = interruptor("mundo.recibirMarcadores"),
		texto = L["Lo que comparte alguien de tu grupo con Alfa llega a tus marcadores, con su nombre, y te avisa para seguirlo."] })
	g:Fila({ titulo = L["Capas en la lupa del mapa del juego"], control = interruptor("mundo.menuMapa"),
		texto = L["El menú de la lupa del mapa del juego tiene también todas las capas de Alfa."] })
	g:Fila({ titulo = L["Cómo se ven las zonas sin descubrir"],
		texto = L["Ocultas como en el juego, reveladas, o reveladas con un tono más frío para saber dónde no has estado."],
		control = function(fila)
			return K.Desplegable(fila, { clave = "maps.reveal", ancho = 220, opciones = {
				{ valor = "off", texto = L["Ocultas"] }, { valor = "on", texto = L["Reveladas"] }, { valor = "tint", texto = L["Reveladas con otro tono"] },
			} })
		end })
	g:Fila({ titulo = L["Modo explorador"], control = interruptor("mundo.explorador"),
		texto = L["En esta página, cuánto llevas descubierto de cada zona de tu continente y lo que te falta."] })
	g.detalle = g:Fila({ titulo = L["Más detalle al acercar el mapa"], control = interruptor("mundo.detalle"),
		activa = function() return Lz.HayTexturas() end,
		texto = L["Dibuja el arte completo de cada zona recortado a su forma, con las texturas de detalle incluidas. Sin ellas el mapa sigue completo, solo más suave entre zona y zona."] })
	return g
end

---------------------------------------------------------------------------
-- 5. Las capas: un grupo a la vez
---------------------------------------------------------------------------
local function filaCapa(g, e)
	return g:Fila({
		titulo = e.nombre,
		texto = (e.ayuda or "") .. (e.esencial and (" " .. L["Se queda en el modo limpio."]) or ""),
		activa = function() return Capas.Disponible(e) end,
		control = function(fila)
			local s = K.Interruptor(fila, { alCambiar = function(v) Capas.Poner(e, v) end })
			function s:Leer() self:SetValor(Capas.Valor(e)) end
			s:Leer()
			return s
		end,
	})
end

local function bloqueCapas(ui, padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Qué se pinta en tus mapas"]))
	b.Nota = b:Agregar(K.Texto(b, "nota", "textoSuave"), { espacio = ESP.s })
	K.Escribir(b.Nota, L["El mapa de Alfa, el del juego y el minimapa. Si algo te estorba, apágalo aquí; los otros módulos de Alfa agregan sus capas a esta misma lista."])
	function b.Nota:Acomodar(ancho) return K.Parrafo(self, ancho) end
	b.Grupos = b:Agregar(K.Segmentos(b, { estilo = "pildoras", alCambiar = function(v)
		ui.grupoCapas = v
		N.RehacerPagina(ui.view)
	end }))
	b.grupos = {}   -- nombre -> K.GrupoAjustes
	b.vistas = {}   -- nombre -> { [capa] = true }
	function b:Llenar()
		local opciones, elegido, hay = {}, ui.grupoCapas, false
		local lista = Capas.Grupos()
		for _, g in ipairs(lista) do
			local si = 0
			for _, e in ipairs(g.capas) do if Capas.Activa(e) then si = si + 1 end end
			opciones[#opciones + 1] = { valor = g.nombre, texto = g.nombre, cuenta = format("%d/%d", si, #g.capas) }
			if g.nombre == elegido then hay = true end
		end
		if not hay then elegido = lista[1] and lista[1].nombre end
		ui.grupoCapas = elegido
		self.Grupos:SetOpciones(opciones)
		self.Grupos:SetValor(elegido)
		for _, g in ipairs(lista) do
			local ga = self.grupos[g.nombre]
			if not ga then
				ga = self:Agregar(K.GrupoAjustes(self, {}), { espacio = ESP.base })
				self.grupos[g.nombre] = ga
				self.vistas[g.nombre] = {}
			end
			-- Las capas que llegan tarde (otros módulos) se suman a su grupo.
			for _, e in ipairs(g.capas) do
				if not self.vistas[g.nombre][e] then
					self.vistas[g.nombre][e] = true
					filaCapa(ga, e)
				end
			end
			ga:Refrescar()
			K.Mostrar(ga, g.nombre == elegido)
		end
	end
	return b
end

---------------------------------------------------------------------------
-- 1.3.0: el modo explorador (Descubrir.lua): cuánto llevas de cada zona
---------------------------------------------------------------------------
local EXPLORAR = 6

local function bloqueExplorador(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Modo explorador"]))
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 200, variante = "normal" }))
	function b:Llenar()
		local on = A.Get("mundo.explorador") ~= false
		K.Mostrar(self, on)
		if not on then return end
		local Ds = M.Descubrir
		local lista, r = {}, { completas = 0, zonas = 0 }
		if Ds and Ds.Explorador then lista, r = Ds.Explorador() end
		local datos = {}
		for i = 1, math.min(EXPLORAR, #lista) do
			local e = lista[i]
			local falta = e.total - e.hechos
			datos[i] = {
				icono = falta == 0 and "ic-exito" or "ic-descubrir", tono = falta == 0 and "exito" or "acento",
				sobre = e.mia and L["Tu zona"] or nil, titulo = e.nombre,
				texto = falta == 0 and L["¡Explorada completa!"] or (falta == 1 and L["Te falta 1 rincón."] or format(L["Te faltan %d rincones."], falta)),
				progreso = { actual = e.hechos, total = e.total, texto = format(L["%d de %d rincones"], e.hechos, e.total) },
			}
		end
		if #datos == 0 then
			datos[1] = { icono = "ic-descubrir", tono = "neutro", titulo = L["Sal a explorar"],
				texto = L["Aquí verás cuánto llevas descubierto de cada zona de tu continente."] }
		end
		self.Rejilla:Llenar(datos)
		self.Seccion:Set(L["Modo explorador"], { cuenta = r.zonas > 0 and format(L["%d de %d zonas completas"], r.completas, r.zonas) or nil })
	end
	return b
end

---------------------------------------------------------------------------
-- 6. Cómo se usa
---------------------------------------------------------------------------
local AYUDA = {
	L["Rueda del ratón: acercar o alejar donde está el cursor. Arrastrar: mover el mapa (al soltar rápido sigue un poco). Doble clic: acercar."],
	L["Clic derecho (o Mayús+clic): un marcador ahí. Ctrl+clic: la flecha y la ruta te llevan ahí sin guardar nada."],
	L["Clic en un marcador: su ficha (cambiarlo, compartirlo, borrarlo o seguirlo). Mayús+clic: seguirlo de una vez. Clic derecho en cualquier otro pin: seguirlo o guardarlo como marcador."],
	L["/alfa mapa abre el mapa, /alfa limpio cambia el modo limpio y /alfa mundo abre esta página."],
}

local function bloqueAyuda(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b:Agregar(K.Seccion(b, L["Cómo se usa"]))
	local panel = CreateFrame("Frame", nil, b)
	panel.caja = K.Caja(panel, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	panel.lineas = {}
	for i, t in ipairs(AYUDA) do
		local fs = K.Texto(panel, "nota", "textoSuave")
		K.Escribir(fs, t)
		local h = K.Icono(panel, "ic-huella", 12, "acento")
		panel.lineas[i] = { fs = fs, h = h }
	end
	function panel:Acomodar(ancho)
		local y = ESP.base
		local tw = ancho - ESP.base * 2 - 20
		for _, l in ipairs(self.lineas) do
			l.h:ClearAllPoints()
			l.h:SetPoint("TOPLEFT", self, "TOPLEFT", ESP.base, -(y + 1))
			l.fs:ClearAllPoints()
			l.fs:SetPoint("TOPLEFT", self, "TOPLEFT", ESP.base + 20, -y)
			y = y + K.Parrafo(l.fs, tw) + ESP.s
		end
		y = y - ESP.s + ESP.base
		self:SetSize(ancho, y)
		return y
	end
	b:Agregar(panel)
	return b
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
local function construir(view)
	local ui = { view = view }
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "accion", tituloOpciones = L["El mapa a tu gusto"], min = 300 })
	ui.marcadores = t:AgregarBloque(bloqueMarcadores(ui, t.Extra))
	ui.explorador = t:AgregarBloque(bloqueExplorador(t.Extra))
	ui.ajustes = t:AgregarBloque(ajustesMapa(t.Extra))
	ui.sinTexturas = t:AgregarBloque(K.Texto(t.Extra, "pequeno", "textoTenue"), { espacio = ESP.s })
	function ui.sinTexturas:Acomodar(ancho) return K.Parrafo(self, ancho) end
	ui.capas = t:AgregarBloque(bloqueCapas(ui, t.Extra))
	t:AgregarBloque(bloqueAyuda(t.Extra))
	K.EnPagina(view, t, function()
		t:SetAccion(accion())
		t:SetOpciones(tarjetas(), L["El mapa a tu gusto"])
		ui.marcadores:Llenar()
		ui.explorador:Llenar()
		ui.ajustes:Refrescar()
		local faltan, roto = not Lz.HayTexturas(), Lz.TerrenoRoto()
		K.Mostrar(ui.sinTexturas, faltan or roto)
		local notas = {}
		if faltan then notas[#notas + 1] = L["Faltan las texturas de detalle en la carpeta Media de Alfa_Mundo: el mapa se dibuja solo con el arte del juego."] end
		if roto then notas[#notas + 1] = L["Este cliente no carga los mosaicos del minimapa: se ve el arte pintado."] end
		if #notas > 0 then K.Escribir(ui.sinTexturas, table.concat(notas, " ")) end
		ui.capas:Llenar()
	end)
	M.vista = view
	local function rehacer() N.RehacerPagina(view) end
	Capas.AlCambiar(rehacer)
	Mk.AlCambiar(rehacer)
	view:HookScript("OnShow", rehacer)
end

---------------------------------------------------------------------------
-- El módulo
---------------------------------------------------------------------------

N.Modulo({
	id = ID, nombre = L["Mundo"], icono = "ic-mundo", orden = 31,
	subtitulo = L["El mapa del mundo entero con zoom, tus marcadores y un solo control para todo lo que se pinta."],
	comando = "mundo",
	ajustes = {
		grupo = true,       -- tu grupo en el mapa de Alfa (esencial)
		nombres = true,     -- nombres de zona en el mapa de Alfa
		detalle = true,     -- arte base de cada zona con las texturas de detalle
		estiloMapa = "terreno", -- "terreno" (los mosaicos del minimapa) | "clasico" (solo el arte pintado)
		salidas = true,     -- salidas de zona (Entradas.lua)
		portales = true,    -- portales a pie (Entradas.lua)
		vueloEnMapa = true, -- la línea de tu vuelo en grifo en el mapa de Alfa (Trayecto.lua, 1.2.1)
		porDescubrir = true, -- los rincones de tu zona que no exploras (Descubrir.lua, 1.2.9)
		vuelosFaltan = true, -- los vuelos de tu zona que no conoces (Descubrir.lua, 1.2.9)
		peligros = true,    -- los élites y raros peligrosos de tu zona (Peligros.lua, 1.3.0)
		explorador = true,  -- el modo explorador en la página (Descubrir.lua, 1.3.0)
		botonMapa = true,   -- botones de Alfa junto a la lupa del mapa del juego
		menuMapa = true,    -- las capas en el menú de la lupa
		teclaM = true,      -- la tecla del mapa abre el de Alfa
		marcarEnMapaJuego = true, -- Mayús+clic derecho en el mapa del juego pone un marcador
		recibirMarcadores = true, -- lo que comparte tu grupo llega a tus marcadores
		ventana = false,    -- { ancho, alto } al cambiar su tamaño
	},
	-- Para la búsqueda de ajustes de la ventana de Alfa (la página es propia).
	controles = {
		{ kind = "toggle", key = "mundo.teclaM", label = L["Abrir el mapa de Alfa con la tecla del mapa"],
			search = "map key, M key, world map, open map, tecla M, mapa" },
		{ kind = "toggle", key = "mundo.botonMapa", label = L["Botones de Alfa en el mapa del juego"], search = "world map buttons" },
		{ kind = "toggle", key = "mundo.marcarEnMapaJuego", label = L["Marcadores con Mayús+clic derecho en el mapa del juego"],
			search = "waypoints, markers, pins, marcadores, notas" },
		{ kind = "toggle", key = "mundo.recibirMarcadores", label = L["Recibir marcadores de tu grupo"], search = "share waypoints, party, compartir" },
		{ kind = "toggle", key = "mundo.menuMapa", label = L["Capas en la lupa del mapa del juego"], search = "tracking menu, layers" },
		{ kind = "toggle", key = "mundo.detalle", label = L["Más detalle al acercar el mapa"], search = "map detail, textures, zoom, detalle fino" },
		{ kind = "toggle", key = "mundo.vueloEnMapa", label = L["Tu vuelo en el mapa"], search = "flight path, gryphon, taxi, flight line, vuelo, grifo, línea" },
		{ kind = "toggle", key = "mundo.porDescubrir", label = L["Por descubrir"], search = "explore, unexplored, discover, exploration xp, explorar" },
		{ kind = "toggle", key = "mundo.vuelosFaltan", label = L["Vuelos que te faltan"], search = "flight paths, missing, taxi, flight master, vuelos" },
		{ kind = "toggle", key = "mundo.peligros", label = L["Peligros"], search = "danger, elites, dangerous rares, elite mobs, peligro" },
		{ kind = "toggle", key = "mundo.explorador", label = L["Modo explorador"], search = "explorer, exploration progress, subzones, discovered, explorar" },
		{ kind = "dropdown", key = "mundo.estiloMapa", label = L["Estilo del mapa"],
			choices = { { value = "terreno", label = L["Terreno, como el minimapa"] }, { value = "clasico", label = L["Clásico, el arte pintado del juego"] } },
			search = "map style, terrain, minimap, classic, estilo, terreno, minimapa" },
	},
	construir = construir,
})

-- 1.3.0: el modo explorador se rehace al prenderlo o al descubrir algo.
local function rehacerVista()
	local v = M.vista
	if v and v.IsVisible and v:IsVisible() then N.RehacerPagina(v) end
end
A.On("SETTING_CHANGED", function(path) if path == "mundo.explorador" then rehacerVista() end end)
A.RegisterEvent("MAP_EXPLORATION_UPDATED", rehacerVista)

A.RegisterCommand("mapa", function() V.Alternar() end, L["Abre o cierra el mapa de Alfa"])
A.RegisterCommand("limpio", function()
	Capas.AlternarLimpio()
	N.Imprimir(Capas.Limpio() and L["Modo limpio encendido: solo tú, tu grupo, tus marcadores y la guía."] or L["Modo limpio apagado: tus capas volvieron como estaban."])
end, L["Cambia el modo limpio del mapa"])

-- La primera vez: las entradas de mazmorras, los puntos de vuelo y los
-- barcos se marcan (el motor los trae apagados). Si después los apagas, se
-- quedan apagados. (`vuelos` y `entradas` llegaron después: las cuentas que
-- ya tenían `iniciado` también los pasan.)
if type(A.OnLogin) == "function" then
	A.OnLogin(function()
		local d = N.Datos(ID)
		if not d.iniciado then
			d.iniciado = 1
			if A.Get("maps.dungeonPins") == false then A.Set("maps.dungeonPins", true) end
		end
		if not d.vuelos then
			d.vuelos = 1
			if A.Get("maps.taxiPins") == false then A.Set("maps.taxiPins", true) end
		end
		if not d.entradas then
			d.entradas = 1
			if A.Get("maps.dockPins") == false then A.Set("maps.dockPins", true) end
		end
	end)
end
