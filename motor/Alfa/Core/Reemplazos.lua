-- Alfa: los reemplazos de las ventanas del motor (toxic3000 / La Jauria, GPL-3.0).
-- La tabla de claves, con quien abre cada ventana, esta en docs/KIT.md.
--
-- Un modulo de Alfa toma el lugar de una ventana o un aviso del motor:
--
--   Alfa.Reemplazar(clave, fn, visible)      (AlfaNucleo.Reemplazar es lo mismo)
--     clave    una de CLAVES (abajo): "SHOW_PICKER", "GUIDE_FRAME", "HEADS_UP"...
--     fn       fn(pedido): pedido es una tabla con lo que se pidio (cada clave
--              trae los suyos) y, en los avisos, las acciones del motor
--              (pedido.Cerrar(), pedido.Actuar()...). nil devuelve la ventana
--              al motor.
--     visible  opcional: visible() -> true mientras tu ventana esta a la vista.
--              El motor la consulta donde antes miraba la suya (la bienvenida
--              espera a que se cierre la eleccion de ruta, por ejemplo).
--   -> true | false, por que
--
-- Desde ese momento la ventana del motor no se muestra: el motor llama a fn y
-- sigue haciendo su trabajo por dentro (guias, pasos, avisos que esperan su
-- turno, lo ya visto). Si fn falla (un error de Lua), el error se reporta y esa
-- vez se muestra la ventana del motor: nada se queda sin abrir.
--
-- Por donde pasa cada pedido:
--   * los mensajes que abren ventanas (SHOW_PICKER, TOGGLE_PICKER, SHOW_LOOKUP,
--     SHOW_DUNGEON, SHOW_TALENTS, SHOW_RARES, SHOW_ALTS, SHOW_IMPORT,
--     SHOW_WELCOME, SHOW_WHATSNEW): ns.Fire los desvia aqui antes de los
--     oyentes del motor (parche de Core/Init.lua en tools/parches.py);
--   * las funciones directas (UI.ShowPicker, UI.ShowLookup, UI.ToggleLookup,
--     las secciones del centro, la ventana de guia, la bienvenida, las
--     novedades): su propio codigo pregunta ns.Reemplazos.Llamar(clave, ...)
--     antes de mostrar nada (motor/Alfa/UI/*.lua);
--   * los avisos y tarjetas automaticas (ClassToast, SpellCards, DungeonToast,
--     UpdateCard, GuideEnd, RouteChoice, LevelTip, WhileHere, ClassCard):
--     parches de tools/parches.py en el punto donde se dibujan.

local ADDON, ns = ...

local R = {}
ns.Reemplazos = R

local activos = {} -- clave -> { fn = fn, visible = fn | nil }
local desvios = ns.DesviosDeMensajes or {} -- mensaje -> fn(...) -> true si lo atendio (Core/Init.lua)
ns.DesviosDeMensajes = desvios

local function vacio() return {} end

-- Las claves: los mensajes que desvia ns.Fire (con como se arma el pedido) y
-- lo que se hace al tomar o devolver la ventana.
local CLAVES = {
	-- Ventanas que se abren a pedido
	SHOW_PICKER = { mensajes = {
		SHOW_PICKER = vacio,
		TOGGLE_PICKER = function() return { alternar = true } end,
	} },
	SHOW_LOOKUP = { mensajes = {
		SHOW_LOOKUP = function(q, k, id) return { buscar = q, tipo = k, id = id } end,
	} },
	SHOW_DUNGEON = { mensajes = {
		SHOW_DUNGEON = function(key) return { mazmorra = key } end,
	} },
	SHOW_TALENTS = { mensajes = { SHOW_TALENTS = vacio } },
	SHOW_RARES = { mensajes = {
		SHOW_RARES = function(kind, id) return { tipo = kind, id = id } end,
	} },
	SHOW_ALTS = { mensajes = { SHOW_ALTS = vacio } },
	SHOW_IMPORT = { mensajes = { SHOW_IMPORT = vacio } },
	SHOW_WELCOME = { mensajes = {
		SHOW_WELCOME = function() return { motivo = "asked", Listo = function() ns.Fire("WELCOME_CLOSED") end } end,
	} },
	SHOW_WHATSNEW = { mensajes = { SHOW_WHATSNEW = function() return { motivo = "asked" } end } },
	-- La ventana de guia: sigue a ui.shown y a sus reglas (combate, instancias)
	GUIDE_FRAME = { alCambiar = function()
		local GF = ns.UI and ns.UI.GuideFrame
		if GF and GF.ApplyVisibility and ns.IsLoggedIn and ns.IsLoggedIn() then GF.ApplyVisibility() end
	end },
	-- Avisos y tarjetas automaticas
	HEADS_UP = {}, CLASS_TOAST = {}, SPELL_CARDS = {}, DUNGEON_TOAST = {}, UPDATE_CARD = {},
	CLASS_CARD = {}, GUIDE_END = {}, ROUTE_CHOICE = {}, LEVEL_TIP = {}, WHILE_HERE = {},
}
R.CLAVES = CLAVES

local function reportar(err)
	if ns.NoteError then pcall(ns.NoteError, err) end
	if geterrorhandler then geterrorhandler()(err) end
end

function ns.Reemplazar(clave, fn, visible)
	local c = CLAVES[clave]
	if not c then return false, "Reemplazar: no hay ventana del motor con la clave " .. tostring(clave) end
	if fn ~= nil and type(fn) ~= "function" then return false, "Reemplazar: fn debe ser una funcion (o nil)" end
	if visible ~= nil and type(visible) ~= "function" then return false, "Reemplazar: visible debe ser una funcion (o nil)" end
	activos[clave] = fn and { fn = fn, visible = visible } or nil
	for msg, armar in pairs(c.mensajes or {}) do
		desvios[msg] = fn and function(...) return R.Llamar(clave, armar(...)) end or nil
	end
	if c.alCambiar then c.alCambiar() end
	ns.Fire("ALFA_REEMPLAZO", clave, fn ~= nil)
	return true
end

-- La funcion que reemplaza la ventana `clave`, o nil.
function ns.Reemplazo(clave)
	local a = activos[clave]
	return a and a.fn or nil
end

-- Si la ventana de Alfa que reemplaza `clave` esta a la vista: true/false, y
-- nil cuando no hay reemplazo (pregunta al motor por la suya).
function ns.ReemplazoVisible(clave)
	local a = activos[clave]
	if not a then return nil end
	if not a.visible then return false end
	local ok, v = pcall(a.visible)
	return ok and v and true or false
end

-- Llama al reemplazo de `clave` con `pedido`. -> true cuando lo atendio; false
-- sin reemplazo o si fallo (entonces el motor muestra la suya).
function R.Llamar(clave, pedido)
	local a = activos[clave]
	if not a then return false end
	local ok, err = pcall(a.fn, pedido or {})
	if not ok then
		reportar(err)
		return false
	end
	return true
end

-- Lista de claves activas (para /alfa y las pruebas).
function R.Activas()
	local t = {}
	for k in pairs(activos) do t[#t + 1] = k end
	table.sort(t)
	return t
end

---------------------------------------------------------------------------
-- Los avisos de la tarjeta del motor (UI/ClassToast.lua, CT.ShowCard): el de
-- mision de clase, los de hechizos y rangos, el de mazmorra y el de version.
-- Su tipo sale del modelo; su clave propia manda, y si no, HEADS_UP.
---------------------------------------------------------------------------

local function tipoDeAviso(m)
	if m.update then return "UPDATE_CARD" end
	if m.dungeon then return "DUNGEON_TOAST" end
	if m.kind == "levelUp" or m.kind == "oldRanks" then return "SPELL_CARDS" end
	return "CLASS_TOAST"
end
R.TipoDeAviso = tipoDeAviso

local function claveDeAviso(m)
	local tipo = tipoDeAviso(m)
	if activos[tipo] then return tipo, tipo end
	if activos.HEADS_UP then return "HEADS_UP", tipo end
	return nil, tipo
end

-- CT.ShowCard(m): -> true cuando una ventana de Alfa lo muestra (el motor lo
-- da por mostrado: CT.current = m, y espera a que se cierre).
function R.Aviso(m)
	if type(m) ~= "table" then return false end
	local clave, tipo = claveDeAviso(m)
	if not clave then return false end
	local CT = ns.UI and ns.UI.ClassToast
	if not CT then return false end
	-- El motor lo da por mostrado antes de llamar: las acciones (CT.Act...)
	-- leen CT.current.
	local antes = CT.current
	m.alfaReemplazo = clave
	CT.current = m
	local ok = R.Llamar(clave, {
		accion = "mostrar", tipo = tipo, modelo = m,
		Actuar = CT.Act, Mas = CT.More, Apagar = CT.Off, Despues = CT.Later,
		Abrir = CT.Open, Mostrarme = CT.ShowMe, Cerrar = CT.Hide,
	})
	if not ok then
		m.alfaReemplazo = nil
		CT.current = antes
	end
	return ok
end

-- CT.Hide(): el aviso `m` se fue (lo cerro el jugador o el motor).
function R.AvisoFuera(m)
	if type(m) ~= "table" or not m.alfaReemplazo then return end
	local clave = activos[m.alfaReemplazo] and m.alfaReemplazo or (activos.HEADS_UP and "HEADS_UP") or nil
	if clave then R.Llamar(clave, { accion = "ocultar", tipo = tipoDeAviso(m), modelo = m }) end
end
