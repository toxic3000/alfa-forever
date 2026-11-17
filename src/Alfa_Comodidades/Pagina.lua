-- Alfa - Comodidades: su página, hecha con el Kit (Toxic / La Jauría). GPL-3.0.
--
-- Plantilla Tablero (docs/KIT.md): arriba, el estado y la acción
-- recomendada (encender las comodidades que casi todos quieren, de un
-- clic); debajo, cada comodidad en su grupo, con su interruptor principal
-- y sus opciones dentro (atenuadas mientras está apagado). Lo que este
-- cliente no tiene (un probador, la CVar de la cámara...) no se muestra.
-- La página vive en Ajustes (es de las que se tocan una vez). Sus controles
-- también van a la búsqueda de ajustes de la ventana de Alfa.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit

local ipairs, format = ipairs, string.format
local ESP = K.ESP
local ID = M.ID

local function clave(k) return ID .. "." .. k end

---------------------------------------------------------------------------
-- Los grupos: cada fila es { k, titulo, texto, hija = principal, existe = fn, activa = fn, buscar }
---------------------------------------------------------------------------
local function cvarDe(k)
	for _, s in ipairs(M.SONIDOS or {}) do
		if s.clave == k then return s.cvar end
	end
end

local function textoMisiones()
	local t = L["También las que no son de la guía (de esas se encarga \"Aceptar misiones de la guía\"). No toma misiones grises, no entrega las que piden oro, monedas o materiales de oficio, y si hay varias recompensas eliges tú. Mantén presionado Mayús para hacerlo tú."]
	if A.Get("ruta.soloRuta") == true then
		t = t .. " " .. K.Tenir("aviso", L["Tienes encendido «solo las misiones de mi ruta»: solo acepta las de tu ruta."])
	end
	return t
end

local GRUPOS = {
	{ titulo = L["Misiones"], filas = {
		{ k = "misiones", titulo = L["Aceptar y entregar todas las misiones"], texto = textoMisiones,
			buscar = "automate quests, auto accept all quests, auto turn in, quest automation, daily, weekly" },
		{ k = "misionesNormales", hija = "misiones", titulo = L["Misiones normales"], texto = L["Las que se hacen una sola vez."], buscar = "regular quests" },
		{ k = "misionesDiarias", hija = "misiones", titulo = L["Misiones diarias"], texto = L["Las que se repiten cada día."], buscar = "daily quests, dailies" },
		{ k = "misionesSemanales", hija = "misiones", titulo = L["Misiones semanales"], texto = L["Las que se repiten cada semana."], buscar = "weekly quests" },
		{ k = "misionesEntregar", hija = "misiones", titulo = L["Entregar las completadas"], texto = L["Apagado, solo las acepta y la entrega la haces tú."], buscar = "turn in completed quests, hand in" },
	} },
	{ titulo = L["Viajes"], filas = {
		{ k = "vueloParada", titulo = L["Mostrar la siguiente parada"],
			texto = L["En un vuelo con escalas, una línea bajo el temporizador dice dónde es la siguiente parada y cuánto falta para llegar. Necesita el temporizador de vuelo encendido."],
			activa = function() return A.Get("maps.flightTimer") and true or false end,
			buscar = "flight bar, next stop, next hop, taxi, flight path" },
	} },
	{ titulo = L["Minimapa"], filas = {
		{ k = "minimapa", titulo = L["Mejorar el minimapa"],
			texto = L["Enciende los cambios de abajo; cada uno se puede apagar por separado. Algunos addons acomodan sus botones al cuadrado después de /reload."],
			buscar = "enhance minimap, square minimap, minimap buttons" },
		{ k = "minimapaCuadrado", hija = "minimapa", titulo = L["Minimapa cuadrado"],
			texto = L["El minimapa pasa de redondo a cuadrado, con un borde fino. No se recomienda junto con girar el minimapa."], buscar = "square minimap, minimap shape" },
		{ k = "minimapaBotones", hija = "minimapa", titulo = L["Ocultar los botones de addons"],
			texto = L["Los botones de otros addons alrededor del minimapa (también el de Alfa) solo aparecen al pasar el ratón por encima."],
			buscar = "hide minimap buttons, addon buttons, libdbicon, minimap icons" },
		{ k = "minimapaMenu", hija = "minimapa", titulo = L["Ocultar el menú de addons"],
			texto = L["Oculta el botón con el número de addons en la esquina del minimapa. Esos addons se siguen abriendo con su comando, como /alfa."],
			buscar = "addon compartment, addon menu, minimap number" },
	} },
	{ titulo = L["Marcos y barra"], filas = {
		{ k = "colores", titulo = L["Colores de clase en los marcos"],
			texto = L["Pinta del color de la clase el fondo del nombre en tu marco y en el del objetivo cuando es un jugador."],
			buscar = "class colored frames, class colours, unit frames, player frame, target frame" },
		{ k = "coloresJugador", hija = "colores", titulo = L["En tu marco"], texto = L["Un fondo del color de tu clase bajo tu nombre."], buscar = "player frame" },
		{ k = "coloresObjetivo", hija = "colores", titulo = L["En el marco del objetivo"],
			texto = L["Si tu objetivo es un jugador, su fondo toma el color de su clase en lugar del de su reacción."], buscar = "target frame" },
		{ k = "grifos", titulo = L["Ocultar los grifos de la barra de acción"],
			texto = L["Quita los grifos de los lados de la barra principal. Edit Mode también tiene su propia opción para esto."],
			existe = function() return M.Remates() ~= nil end, buscar = "gryphons, end caps, action bar art, wyverns" },
	} },
	{ titulo = L["Cuadro de información"], filas = {
		{ k = "cuadro", titulo = L["Mejorar el cuadro de información"],
			texto = L["Enciende los cambios de abajo en el cuadro que sale al pasar el ratón por un personaje o criatura."], buscar = "enhance tooltip, tooltip" },
		{ k = "cuadroObjetivo", hija = "cuadro", titulo = L["Mostrar a quién apunta"],
			texto = L["Agrega una línea con el objetivo de esa unidad; si te tiene a ti, lo dice."], buscar = "tooltip target, show target, unit target" },
		{ k = "cuadroRango", hija = "cuadro", titulo = L["Mostrar el rango de tu hermandad"], texto = L["Para alguien de tu hermandad, agrega su rango."], buscar = "guild rank, tooltip rank" },
		{ k = "cuadroCombate", hija = "cuadro", titulo = L["Ocultarlo en combate"],
			texto = L["En combate no aparece el cuadro de los personajes y criaturas del mundo (el de los marcos sí)."], buscar = "hide tooltip in combat" },
		{ k = "cuadroShift", hija = "cuadro", titulo = L["Mostrarlo con Mayús"], texto = L["Con el cuadro oculto en combate, mantén presionado Mayús para verlo."],
			activa = function() return M.On("cuadro", "cuadroCombate") end, buscar = "shift override, show tooltip shift" },
	} },
	{ titulo = L["Probador"], existe = function() return M.HayProbador() end, filas = {
		{ k = "probador", titulo = L["Mejorar el probador"], texto = L["Enciende los cambios de abajo en el probador (Ctrl + clic en un objeto)."],
			buscar = "enhance dressup, dressing room, dress up" },
		{ k = "probadorBotones", hija = "probador", titulo = L["Botones de objetos"],
			texto = L["A los lados del modelo, un botón por ranura: un clic oculta esa pieza y otro la vuelve a poner."], buscar = "dressup item buttons, hide items, undress slot" },
		{ k = "probadorAnimacion", hija = "probador", titulo = L["Control de animación"],
			texto = L["Abajo del modelo, elige lo que hace tu personaje (caminar, bailar, saludar...) y páusalo."], buscar = "dressup animation, animation slider, pause model" },
	} },
	{ titulo = L["Cámara"], existe = function() return M.ExisteCVar(M.CVAR_CAMARA) end, filas = {
		{ k = "camara", titulo = L["Alejar más la cámara"],
			texto = L["Lleva al máximo la distancia de la cámara (la de Opciones > Controles). Al apagarlo vuelve la que tenías."],
			buscar = "max camera zoom, camera distance, zoom out" },
	} },
	{ titulo = L["Silenciar sonidos"], filas = {
		{ k = "silenciarErrores", titulo = L["Voces de error"],
			texto = L["Tu personaje deja de decir \"No tengo suficiente maná\", \"Eso todavía no está listo\" y parecidas. El texto rojo sigue."],
			existe = function() return M.ExisteCVar(cvarDe("silenciarErrores")) end, buscar = "mute error speech, vocal errors, not enough mana" },
		{ k = "silenciarDialogos", titulo = L["Saludos y diálogos de los PNJ"],
			texto = L["Los PNJ dejan de hablar al saludarte o al darte misiones. También calla las voces de error."],
			existe = function() return M.ExisteCVar(cvarDe("silenciarDialogos")) end, buscar = "mute npc dialog, greetings, voice" },
		{ k = "silenciarMascotas", titulo = L["Sonidos de mascotas"], texto = L["Calla los ruidos de las mascotas, como el bostezo de los gatos de cazador."],
			existe = function() return M.ExisteCVar(cvarDe("silenciarMascotas")) end, buscar = "mute pet sounds, yawns, cat" },
		{ k = "silenciarGestos", titulo = L["Sonidos de gestos"], texto = L["Calla las voces de /bailar, /reír, /aplaudir y otros gestos."],
			existe = function() return M.ExisteCVar(cvarDe("silenciarGestos")) end, buscar = "mute emote sounds, dance, laugh" },
		{ k = "silenciarLista", titulo = L["Tu lista de sonidos"],
			texto = L["Silencia los sonidos que agregues por su número de archivo (FileDataID): /alfa silenciar <número>; /alfa silenciar quitar <número> lo quita."],
			boton = { texto = L["Ver tu lista"], alClic = function() M.MostrarListaSonidos() end },
			buscar = "mute custom sounds, mute sound file, filedataid" },
	} },
}

-- Lo que casi todos quieren y no cambia cómo juegas: un clic lo enciende.
local RECOMENDADAS = { "colores", "cuadro", "probador", "vueloParada", "silenciarErrores" }

local function existe(f)
	if not f.existe then return true end
	local ok, si = pcall(f.existe)
	return ok and si and true or false
end

-- -> las recomendadas que existen en este cliente y cuántas están apagadas
local function recomendadas()
	local lista, apagadas = {}, 0
	for _, k in ipairs(RECOMENDADAS) do
		local fila
		for _, g in ipairs(GRUPOS) do
			if not g.existe or existe(g) then
				for _, f in ipairs(g.filas) do if f.k == k and existe(f) then fila = f end end
			end
		end
		if fila then
			lista[#lista + 1] = k
			if not M.Get(k) then apagadas = apagadas + 1 end
		end
	end
	return lista, apagadas
end

local function cuantasEncendidas()
	local n = 0
	for _, g in ipairs(GRUPOS) do
		for _, f in ipairs(g.filas) do
			if not f.hija and existe(f) and M.Get(f.k) then n = n + 1 end
		end
	end
	return n
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
local function estado()
	local lista, apagadas = recomendadas()
	local n = cuantasEncendidas()
	if apagadas > 0 then
		return {
			icono = "ic-comodidades", tono = "acento",
			titulo = L["Enciende las comodidades recomendadas"],
			texto = L["Colores de clase en los marcos, un cuadro de información más útil, el probador mejorado, la siguiente parada en los vuelos y sin voces de error. Cada una se apaga abajo cuando quieras."],
			estado = { texto = format(L["%d de %d encendidas"], #lista - apagadas, #lista), tono = "neutro" },
			accion = { texto = L["Encender las recomendadas"], icono = "ic-exito", alClic = function()
				for _, k in ipairs(lista) do N.Set(ID, k, true) end
			end },
		}
	end
	return {
		icono = "ic-comodidades", tono = "exito",
		titulo = L["Tus comodidades están listas"],
		texto = format(L["Tienes %d encendidas. Abajo está cada una, con lo que hace, por si quieres cambiar algo."], n),
		estado = { texto = L["Listo"], tono = "exito" },
	}
end

local function fila(g, f)
	return g:Fila({
		titulo = f.titulo, texto = type(f.texto) == "function" and f.texto() or f.texto,
		hija = f.hija ~= nil,
		activa = function()
			if f.hija and not M.Get(f.hija) then return false end
			if f.activa then return f.activa() and true or false end
			return true
		end,
		control = function(contenedor)
			if f.boton then
				local c = CreateFrame("Frame", nil, contenedor)
				c.Interruptor = K.Interruptor(c, { clave = clave(f.k) })
				c.Boton = K.Boton(c, f.boton.texto, f.boton.alClic, { tipo = "fantasma", tam = "chico" })
				c.Interruptor:SetPoint("RIGHT", c, "RIGHT", 0, 0)
				c.Boton:SetPoint("RIGHT", c.Interruptor, "LEFT", -ESP.m, 0)
				c:SetSize(36 + ESP.m + c.Boton:GetWidth(), K.ALTO.boton)
				function c:Leer() self.Interruptor:Leer() end
				function c:SetActivo(on) self.Interruptor:SetAlpha(on and 1 or 0.45) self.Interruptor:EnableMouse(on) end
				return c
			end
			return K.Interruptor(contenedor, { clave = clave(f.k) })
		end,
	})
end

local function construir(view)
	local ui = { grupos = {} }
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado" })
	for _, g in ipairs(GRUPOS) do
		local ga = t:AgregarBloque(K.GrupoAjustes(t.Extra, { titulo = g.titulo }))
		ga.filasDe = {}
		for _, f in ipairs(g.filas) do ga.filasDe[#ga.filasDe + 1] = { f = f, fila = fila(ga, f) } end
		ui.grupos[#ui.grupos + 1] = { g = g, ga = ga }
	end
	K.EnPagina(view, t, function()
		t:SetAccion(estado())
		for _, x in ipairs(ui.grupos) do
			local visible = 0
			local delGrupo = not x.g.existe or existe(x.g)
			for _, e in ipairs(x.ga.filasDe) do
				local hay = delGrupo and existe(e.f)
				-- Los textos que dependen de otro ajuste (la ruta) se leen otra vez.
				if type(e.f.texto) == "function" then e.fila.alfaDatos.texto = e.f.texto() end
				K.Mostrar(e.fila, hay)
				if hay then visible = visible + 1 end
			end
			x.ga:Refrescar()
			K.Mostrar(x.ga, visible > 0)
		end
	end)
	M.vista = view
	view:HookScript("OnShow", function() N.RehacerPagina(view) end)
end

-- Cualquier ajuste de aquí (o el de la ruta) rehace la página si está a la vista.
A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" or not M.vista then return end
	if path == "" or path == ID or path:sub(1, #ID + 1) == ID .. "." or path == "ruta.soloRuta" or path == "maps.flightTimer" then
		N.RehacerPagina(M.vista)
	end
end)

---------------------------------------------------------------------------
-- La búsqueda de ajustes: los mismos, como controles estándar.
---------------------------------------------------------------------------
local BUSCAR = {}
for _, g in ipairs(GRUPOS) do
	for _, f in ipairs(g.filas) do
		BUSCAR[#BUSCAR + 1] = { kind = "toggle", key = clave(f.k), label = f.titulo, search = f.buscar,
			help = type(f.texto) == "string" and f.texto or nil }
	end
end

N.Modulo({
	id = ID, nombre = L["Comodidades"], icono = "ic-comodidades", orden = 70, seccion = "ajustes",
	subtitulo = L["Lo pequeño que hace el juego más cómodo: misiones, vuelos, minimapa, marcos, cuadro de información, probador, cámara y sonidos."],
	controles = BUSCAR,
	construir = construir,
})
