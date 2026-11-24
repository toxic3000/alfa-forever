-- Alfa - Paisaje y gráficos: su página, los comandos y la API para otros
-- módulos (toxic3000 / La Jauría). GPL-3.0.
--
-- Mundo > Paisaje y gráficos (plantilla Tablero del Kit):
--   1. cómo está tu paisaje y el botón que abre la ventana completa;
--   2. los preajustes en tarjetas (un clic los aplica);
--   3. atajos: los filtros, la niebla, las placas de mascotas y tótems
--      enemigos y si Alfa vuelve a poner tus valores al entrar.
-- Comandos: /alfa paisaje y /alfa graficos abren la ventana.
-- API (la usa la bienvenida para preguntar «Mejorar el paisaje»):
--   AlfaVista.Abrir()                 abre la ventana (si la bienvenida ya terminó)
--   AlfaVista.AplicarPreset(nombre)   "bajo" | "medio" | "alto" | "ultra" | "manada"
--                                     (o su nombre visible) -> true, "ok"|"espera" | false, motivo
--   AlfaVista.Presets()               { { id, nombre, texto, icono }, ... }
--   AlfaVista.Deshacer()              devuelve lo de antes del último preajuste

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local ID = M.ID
local V = M.Ventana

local format, ipairs = string.format, ipairs

local function abrir(pestana)
	if not N.Permitido() then return end
	V.Abrir(pestana)
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
local function estado()
	local p = M.UltimoPreset()
	local n = M.Elegidas()
	local d = { icono = "ic-paisaje", titulo = L["Paisaje y gráficos"] }
	if M.EnCombate() and M.Pendientes() > 0 then
		d.tono, d.estado = "aviso", { texto = L["En espera"], tono = "aviso" }
		d.texto = L["Estás en combate: tus cambios se aplican en cuanto termine."]
	elseif p then
		d.tono, d.estado = "exito", { texto = p.nombre, tono = "exito" }
		d.texto = format(L["Tienes puesto «%s». Abre la ventana para afinar cada detalle: distancia, pasto, niebla, agua, cámara, placas y filtros."], p.nombre)
	elseif n > 0 then
		d.tono, d.estado = "acento", { texto = L["A tu gusto"], tono = "acento" }
		d.texto = N.Plural(n, L["Alfa mantiene %d ajuste que elegiste. Abre la ventana para verlo o cambiarlo."], L["Alfa mantiene %d ajustes que elegiste. Abre la ventana para ver o cambiar cada uno."])
	else
		d.tono, d.estado = "neutro", { texto = L["Como el juego"], tono = "neutro" }
		d.texto = L["Alfa no ha cambiado nada todavía. Prueba «Paisaje de la manada» o abre la ventana para ver los ajustes que el menú del juego no enseña."]
	end
	d.accion = { texto = L["Abrir Paisaje y gráficos"], icono = "ic-seguir", alClic = function() abrir() end }
	if p and M.PuedeDeshacer() then
		-- Con un preajuste puesto, deshacerlo desde aquí (como en la ventana).
		d.secundaria = { texto = L["Deshacer preajuste"], alClic = function() M.Deshacer() end }
	elseif not p or p.id ~= "manada" then
		d.secundaria = { texto = L["Paisaje de la manada"], alClic = function() V.AplicarPreset("manada") end }
	end
	return d
end

local function presets()
	local actual = M.UltimoPreset()
	local t = {}
	for _, p in ipairs(M.PRESETS) do
		t[#t + 1] = { icono = p.icono, tono = p.id == "manada" and "acento" or "neutro", titulo = p.nombre, texto = p.texto,
			elegida = actual == p, sobre = p.id == "manada" and L["Firma de Alfa"] or nil,
			accion = { texto = actual == p and L["Puesto"] or L["Aplicar"], alClic = function() V.AplicarPreset(p.id) end } }
	end
	return t
end

local function interruptor(clave)
	return function(fila) return K.Interruptor(fila, { clave = ID .. "." .. clave }) end
end

-- Un atajo de una variable del juego (solo si el cliente la tiene).
local function atajoCVar(g, cvar, titulo, texto)
	local fila = g:Fila({ titulo = titulo, texto = texto, control = function(f)
		return K.Interruptor(f, {
			get = function() local n = tonumber(M.ValorDe(cvar)) return n ~= nil and n ~= 0 end,
			set = function(on) M.Pedir(cvar, on and 1 or 0) end })
	end })
	fila.alfaCVar = cvar
	return fila
end

local function atajos(padre)
	local g = K.GrupoAjustes(padre, { titulo = L["Efectos"] })
	g:Fila({ titulo = L["Viñeta"], texto = L["Las orillas de la pantalla un poco más oscuras."], control = interruptor("vineta") })
	g:Fila({ titulo = L["Grano de película"], texto = L["Un grano fino de cine sobre el mundo."], control = interruptor("grano") })
	g:Fila({ titulo = L["Barras de cine"], texto = L["Para capturas y paseos. No da más FPS."], control = interruptor("barras") })
	g:Fila({ titulo = L["Tinte de color"], texto = L["La fuerza se cambia en la ventana, en Filtros."], control = function(f)
		local o = {}
		for _, t in ipairs(M.TINTES) do o[#o + 1] = { valor = t.id, texto = t.nombre } end
		return K.Desplegable(f, { opciones = o, clave = ID .. ".tinte", ancho = 180 })
	end })
	atajoCVar(g, "disableHorizonStart", L["Quitar la niebla del horizonte"], L["El paisaje lejano deja de perderse en la niebla espesa."])
	atajoCVar(g, "nameplateShowEnemyPets", L["Placas de mascotas enemigas"], L["Fuera de combate; necesita las placas de enemigos encendidas."])
	atajoCVar(g, "nameplateShowEnemyTotems", L["Placas de tótems enemigos"], L["Fuera de combate; necesita las placas de enemigos encendidas."])
	g:Fila({ titulo = L["Volver a poner mis valores al entrar"], control = interruptor("reaplicar"),
		texto = L["Alfa revisa lo que elegiste cuando el juego termina de cargar. Si los cambias en el menú del juego, se queda con lo nuevo."] })
	return g
end

local function construir(view)
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado", tituloOpciones = L["Preajustes"], min = 240 })
	local g = t:AgregarBloque(atajos(t.Extra), { espacio = K.ESP.xl })
	K.EnPagina(view, t, function()
		t:SetAccion(estado())
		t:SetOpciones(presets(), L["Preajustes"])
		V.TiposDePresets(t.Rejilla, M.UltimoPreset())
		for _, fila in ipairs(g.filas) do
			if fila.alfaCVar then K.Mostrar(fila, M.Existe(fila.alfaCVar)) end
		end
		g:Refrescar()
	end)
	M.vista = view
	-- 1.3.6: sin OnShow; la ventana ya mide la página al mostrarla (O.Select).
end

M.AlCambiar(function() if M.vista then N.RehacerPagina(M.vista) end end)
A.On("SETTING_CHANGED", function(path)
	if M.vista and type(path) == "string" and path:sub(1, #ID + 1) == ID .. "." then N.RehacerPagina(M.vista) end
end)

-- La búsqueda de ajustes de la ventana de Alfa encuentra los filtros.
local BUSCAR = {
	{ kind = "toggle", key = ID .. ".vineta", label = L["Viñeta"], search = "vignette, filter, paisaje" },
	{ kind = "toggle", key = ID .. ".grano", label = L["Grano de película"], search = "film grain, filter" },
	{ kind = "toggle", key = ID .. ".barras", label = L["Barras de cine"], search = "letterbox, cinematic" },
	{ kind = "toggle", key = ID .. ".reaplicar", label = L["Volver a poner mis valores al entrar"], search = "graphics, gráficos, reapply" },
}
-- 1.3.7: también el tinte de color y los atajos de variables del juego
-- (placas de mascotas y tótems, la niebla). Si tu juego no tiene la
-- variable, M.Pedir no escribe nada.
do
	local tintes = {}
	for _, t in ipairs(M.TINTES or {}) do tintes[#tintes + 1] = { value = t.id, label = t.nombre } end
	BUSCAR[#BUSCAR + 1] = { kind = "dropdown", key = ID .. ".tinte", label = L["Tinte de color"], choices = tintes,
		help = L["La fuerza se cambia en la ventana, en Filtros."], search = "tint, color filter, tinte, filtro de color" }
	local function cvarBuscar(cvar, label, help, search)
		BUSCAR[#BUSCAR + 1] = { kind = "toggle", label = label, help = help, search = search,
			get = function() local n = tonumber(M.ValorDe(cvar)) return n ~= nil and n ~= 0 end,
			set = function(on) M.Pedir(cvar, on and 1 or 0) end }
	end
	cvarBuscar("nameplateShowEnemyPets", L["Placas de mascotas enemigas"], L["Fuera de combate; necesita las placas de enemigos encendidas."], "nameplates, enemy pets, placas, mascotas")
	cvarBuscar("nameplateShowEnemyTotems", L["Placas de tótems enemigos"], L["Fuera de combate; necesita las placas de enemigos encendidas."], "nameplates, enemy totems, placas, totems")
	cvarBuscar("disableHorizonStart", L["Quitar la niebla del horizonte"], L["El paisaje lejano deja de perderse en la niebla espesa."], "fog, horizon, niebla")
end

N.Modulo({
	id = ID, nombre = L["Paisaje y gráficos"], icono = "ic-paisaje", orden = 33, seccion = "mundo",
	-- 1.3.6: subtítulo corto (el largo casi nunca se veía).
	subtitulo = L["Para que el mundo se vea mejor, a tu gusto"],
	ajustes = M.AJUSTES,
	controles = BUSCAR,
	construir = construir,
})

A.RegisterCommand("paisaje", function() abrir() end, L["Abre Paisaje y gráficos"])
A.RegisterCommand("graficos", function() abrir() end, L["Abre Paisaje y gráficos"])

---------------------------------------------------------------------------
-- API para otros módulos (la bienvenida)
---------------------------------------------------------------------------
AlfaVista = {
	Abrir = function() abrir() end,
	AplicarPreset = function(nombre) return M.AplicarPreset(nombre) end,
	Presets = function()
		local t = {}
		for _, p in ipairs(M.PRESETS) do t[#t + 1] = { id = p.id, nombre = p.nombre, texto = p.texto, icono = p.icono } end
		return t
	end,
	Deshacer = function() return M.Deshacer() end,
	-- id del preajuste que sigue puesto (nil si se cambió algo después)
	Actual = function() local p = M.UltimoPreset(); return p and p.id or nil end,
	-- el último aplicado y no deshecho (aunque el juego haya recortado un valor)
	Ultimo = function() return M.UltimoId() end,
}
