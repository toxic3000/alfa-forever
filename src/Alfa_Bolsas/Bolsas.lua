-- Alfa - Bolsas (Toxic / La Jauría). GPL-3.0.
--
-- Tus bolsas y tu banco en una sola ventana de Alfa, con dos vistas (una
-- sola bolsa o por categorías), ordenar, buscar, marcas sobre cada objeto y
-- el inventario de todos tus personajes (también en el cuadro de cada
-- objeto). Reemplaza a Baganator y Syndicator con código propio.
--
-- Archivos (en el orden del .toc):
--   Bolsas.lua     registro del módulo, ajustes y utilidades comunes (este)
--   Datos.lua      el registro por personaje y los conteos del cuadro de objeto
--   Objetos.lua    datos de cada objeto, categorías y búsqueda
--   Botones.lua    los botones de objeto (seguros en vivo, de foto) y sus marcas
--   Ventana.lua    las ventanas de bolsas y de banco
--   Reemplazo.lua  abrir la ventana de Alfa en lugar de las bolsas de Blizzard
--   Pagina.lua     la página "Bolsas" en la ventana de Alfa

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

M.N, M.A, M.L = N, A, L
M.ID = "bolsas"

local type, tonumber, pairs, pcall = type, tonumber, pairs, pcall

---------------------------------------------------------------------------
-- Ajustes (AlfaDB.settings.bolsas)
---------------------------------------------------------------------------

M.AJUSTES = {
	vista = "categorias",     -- "categorias" | "una"
	tamIcono = 36,            -- lado de cada casilla, en puntos
	columnas = 10,            -- casillas por fila
	reemplazar = true,        -- abrir la ventana de Alfa en lugar de las bolsas de Blizzard
	banco = true,             -- y en lugar del banco de Blizzard
	llavero = true,           -- mostrar el llavero junto a las bolsas
	ordenar = true,           -- el botón Ordenar
	ordenarInverso = false,   -- ordenar de derecha a izquierda
	marcaNivel = true,        -- nivel de objeto
	marcaCalidad = true,      -- borde del color de la calidad
	marcaChatarra = true,     -- moneda sobre la chatarra
	marcaNuevos = true,       -- brillo en los objetos nuevos
	marcaMejora = true,       -- flecha de mejora
	marcaMision = true,       -- marca de objeto de misión
	cuadroConteo = true,      -- "Tienes 12 (...)" en el cuadro de cada objeto
}

N.Modulo({
	id = M.ID, nombre = L["Bolsas"], icono = "icon-collect", orden = 40,
	subtitulo = L["Tus bolsas y tu banco en una sola ventana, y lo que lleva cada uno de tus personajes."],
	comando = "bolsas",
	ajustes = M.AJUSTES,
	construir = function(view) if M.ConstruirPagina then M.ConstruirPagina(view) end end,
})

function M.Get(clave)
	local v = N.Get(M.ID, clave)
	if v == nil then v = M.AJUSTES[clave] end
	return v
end

function M.Set(clave, valor) N.Set(M.ID, clave, valor) end

-- Un número del ajuste, dentro de [lo, hi].
function M.Numero(clave, lo, hi)
	local v = tonumber(M.Get(clave)) or tonumber(M.AJUSTES[clave]) or lo
	if v < lo then v = lo elseif v > hi then v = hi end
	return math.floor(v + 0.5)
end

---------------------------------------------------------------------------
-- Valores del juego: los secretos (Forever) se leen como desconocidos.
---------------------------------------------------------------------------

local function secreto(v)
	return v ~= nil and issecretvalue ~= nil and issecretvalue(v) and true or false
end

function M.Leer(v)
	if secreto(v) then return nil end
	return v
end

function M.Num(v)
	if secreto(v) then return nil end
	return tonumber(v)
end

function M.Texto(v)
	if secreto(v) or type(v) ~= "string" then return nil end
	return v
end

-- Una llamada al cliente protegida con pcall: -> sus resultados, o nada.
local function resultados(ok, ...)
	if ok then return ... end
	return nil
end

function M.Llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	return resultados(pcall(fn, ...))
end

function M.ItemID(link)
	if type(link) == "number" then return link end
	if type(link) ~= "string" then return nil end
	return tonumber(link:match("item:(%d+)"))
end

-- Error de una función nuestra al manejador del juego, sin cortar el resto.
function M.Seguro(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		if A.NoteError then pcall(A.NoteError, err) end
		if geterrorhandler then pcall(geterrorhandler(), err) end
	end
	return ok
end

---------------------------------------------------------------------------
-- Avisos internos del módulo (sin pasar por el motor)
---------------------------------------------------------------------------

local oyentes = {}

function M.Escuchar(que, fn)
	oyentes[que] = oyentes[que] or {}
	local lista = oyentes[que]
	lista[#lista + 1] = fn
end

function M.Avisar(que, ...)
	local lista = oyentes[que]
	if not lista then return end
	for i = 1, #lista do M.Seguro(lista[i], ...) end
end

-- fn en el siguiente cuadro (o ya, si no hay temporizador).
function M.Luego(seg, fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(seg or 0, function() M.Seguro(fn) end)
	else
		M.Seguro(fn)
	end
end

---------------------------------------------------------------------------
-- Comandos: /alfa bolsas abre la página; con "abrir" o "banco", las ventanas.
---------------------------------------------------------------------------

A.RegisterCommand("bolsas", function(resto)
	local arg = type(resto) == "string" and resto:lower():match("^%s*(%S*)") or ""
	if arg == "abrir" or arg == "open" then
		if M.Ventana then M.Ventana.AlternarBolsas() end
	elseif arg == "banco" or arg == "bank" then
		if M.Ventana then M.Ventana.MostrarBanco() end
	else
		N.Abrir(M.ID)
	end
end, L["La página de Bolsas; «abrir» abre tus bolsas y «banco» tu banco"])

-- Un texto de color: "|cffrrggbb...|r".
function M.Pintado(texto, r, g, b)
	return ("|cff%02x%02x%02x%s|r"):format(math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5),
		math.floor((b or 1) * 255 + 0.5), tostring(texto or ""))
end

-- Color del tema por nombre, con respaldo.
function M.Color(nombre, r, g, b)
	local T = A.Theme
	if T and T.Color then
		local ok, cr, cg, cb, ca = pcall(T.Color, nombre)
		if ok and type(cr) == "number" then return cr, cg, cb, ca or 1 end
	end
	return r or 1, g or 1, b or 1, 1
end

function M.Acento()
	local T = A.Theme
	if T and T.Accent then
		local ok, r, g, b = pcall(T.Accent)
		if ok and type(r) == "number" then return r, g, b end
	end
	return 0.55, 0.88, 0.31
end

-- Color de una clase ("WARRIOR").
function M.ColorClase(clase)
	local T = A.Theme
	if T and T.ClassColor and type(clase) == "string" then
		local ok, r, g, b = pcall(T.ClassColor, clase)
		if ok and type(r) == "number" then return r, g, b end
	end
	return M.Color("text")
end

-- "hoy", "ayer", "hace 3 días".
function M.Hace(t)
	t = tonumber(t)
	if not t or t <= 0 then return L["nunca"] end
	local ahora = time and time() or t
	local dias = math.floor((ahora - t) / 86400)
	if dias <= 0 then return L["hoy"] end
	if dias == 1 then return L["ayer"] end
	return (L["hace %d días"]):format(dias)
end
