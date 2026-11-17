-- Alfa - Núcleo de los módulos propios (toxic3000 / La Jauría). GPL-3.0.
--
-- Todo módulo de Alfa (Alfa_Inicio, Alfa_Bolsas, ...) se cuelga de aquí:
--   local N = AlfaNucleo          -- este archivo
--   local A = N.A                 -- el motor de Alfa (Polestar renombrado)
--   local L = N.Textos(EN)        -- textos en español con traducción al inglés
--   N.Modulo({ ... })             -- su página en la ventana de Alfa
-- Contrato completo: docs/ARQUITECTURA.md.

local _, N = ...
AlfaNucleo = N

local A = Alfa
N.A = A
N.version = A and A.version or "dev"
N.COLOR = "8be04e"
N.HEX = "|cff8be04e"

---------------------------------------------------------------------------
-- Idioma: los textos se escriben en español. En otros clientes se busca la
-- traducción en el diccionario de ese idioma (Idiomas/<locale>.lua, generado
-- con tools/textos.py), luego en la tabla en inglés del módulo, y si falta,
-- se deja el texto español.
---------------------------------------------------------------------------
local locale = GetLocale and GetLocale() or "esMX"
N.locale = locale
N.espanol = (locale == "esMX" or locale == "esES")
N.idiomas = N.idiomas or {} -- [locale] = { ["texto en español"] = "traducción" }

function N.Textos(en)
	if N.espanol then
		return setmetatable({}, { __index = function(_, k) return k end })
	end
	return setmetatable({}, { __index = function(_, k)
		local d = N.idiomas[locale]
		return (d and d[k]) or (type(en) == "table" and en[k]) or k
	end })
end

-- Un texto suelto que trae su versión en español y en inglés (por ejemplo,
-- los consejos de Mazmorras): devuelve el del idioma del cliente.
function N.Traducir(es, en)
	if N.espanol then return es end
	local d = N.idiomas[locale]
	return (d and d[es]) or en or es
end

---------------------------------------------------------------------------
-- Módulos: cada uno es una página de la ventana de Alfa (la de opciones de
-- Polestar), con su ícono, su orden y su vista propia.
-- spec = {
--   id = "bolsas",            -- clave estable: página, ajustes y comandos
--   nombre = "Bolsas",        -- título visible
--   icono = "icon-collect",   -- nombre de un .tga de Alfa/Media/UI
--   orden = 40,               -- posición en la barra lateral
--   subtitulo = "...",        -- una línea bajo el título
--   ajustes = { ... },        -- valores por omisión (A.RegisterDefaults)
--   construir = function(view) end,  -- arma la vista la primera vez
--   controles = { ... },      -- opcional: controles estándar de A.RegisterOptions
--   comando = "bolsas",       -- opcional: /alfa bolsas abre la página
-- }
---------------------------------------------------------------------------
N.modulos = {}
local porId = {}

function N.Modulo(spec)
	assert(type(spec) == "table" and type(spec.id) == "string", "Modulo: falta id")
	assert(not porId[spec.id], "Modulo: id repetido " .. spec.id)
	porId[spec.id] = spec
	N.modulos[#N.modulos + 1] = spec
	if spec.ajustes then A.RegisterDefaults(spec.id, spec.ajustes) end
	local ok, err = A.RegisterOptions({
		page = spec.nombre, key = spec.id, icon = spec.icono, order = spec.orden,
		subtitle = spec.subtitulo, custom = spec.construir, controls = spec.controles or {},
		seccion = spec.seccion, -- hoy, aventura, personaje, mundo, oficios, manada o ajustes (docs/INTERFAZ.md)
	})
	if not ok and geterrorhandler then geterrorhandler()(err) end
	if spec.comando then
		A.RegisterCommand(spec.comando, function() N.Abrir(spec.id) end, spec.subtitulo)
	end
	A.Fire("ALFA_MODULO", spec)
	return spec
end

function N.ModuloPorId(id) return porId[id] end
function N.Abrir(id) A.Fire("SHOW_OPTIONS", id) end

-- Ancho útil de una página de la ventana de Alfa.
function N.AnchoPagina()
	local O = A.UI and A.UI.Options
	local win = O and O.frame
	local w = win and win.BodyWidth
	return type(w) == "number" and w or 874
end

-- Alto visible de una página (sin desplazarla): para las plantillas que
-- llenan la página (lista con ficha, asistente).
function N.AltoPagina()
	local O = A.UI and A.UI.Options
	local win = O and O.frame
	local h = win and win.psViewH
	return type(h) == "number" and h or 470
end

-- Margen a los lados de una página (el contenido empieza ahí).
function N.MargenPagina()
	local W = A.Widgets
	local p = W and W.SHELL and W.SHELL.pad
	return type(p) == "number" and p or 32
end

-- Mide otra vez una página que está a la vista (cambió algo) y ajusta el
-- desplazamiento de la ventana.
function N.RehacerPagina(view)
	if not (view and view.Refresh and view.IsVisible and view:IsVisible()) then return end
	local h = view.Refresh()
	if type(h) ~= "number" then return end
	view:SetHeight(h)
	local O = A.UI and A.UI.Options
	local W = A.Widgets
	if O and O.frame and W and W.ShellBody then W.ShellBody(O.frame, h) end
end

-- Una ventana o un aviso del motor que toma un módulo de Alfa (docs/KIT.md,
-- "Reemplazos"): desde ese momento el motor llama a fn(pedido) en lugar de
-- mostrar la suya. visible(): opcional, si tu ventana está a la vista.
-- -> true | false, por qué
function N.Reemplazar(clave, fn, visible)
	if not (A and A.Reemplazar) then return false, "el motor no tiene reemplazos" end
	return A.Reemplazar(clave, fn, visible)
end

-- Dentro de una página propia (construir), dibuja controles estándar del motor
-- (toggle, slider, dropdown, button, binding; los mismos de A.RegisterOptions)
-- desde la altura y. Devuelve la nueva altura. Los controles con `key` leen y
-- guardan "id.clave" en los ajustes, como los de cualquier página del motor.
function N.FilasDeAjustes(view, controles, y)
	local O = A.UI and A.UI.Options
	if not (O and O.Rows) then return y end
	view.alfaFilas = view.alfaFilas or {}
	return O.Rows(view, controles, y, view.alfaFilas)
end

-- Ajustes del módulo, guardados en AlfaDB.settings[id].
function N.Get(id, clave) return A.Get(id .. "." .. clave) end
function N.Set(id, clave, valor) A.Set(id .. "." .. clave, valor) end

-- Datos propios del módulo que no son ajustes (historiales, precios, etc.):
-- AlfaNucleoDB[id] para la cuenta y AlfaNucleoCharDB[id] para el personaje.
-- Se leen siempre por aquí: el juego puede devolverlas en nil al arrancar.
function N.Datos(id)
	AlfaNucleoDB = type(AlfaNucleoDB) == "table" and AlfaNucleoDB or {}
	AlfaNucleoDB[id] = type(AlfaNucleoDB[id]) == "table" and AlfaNucleoDB[id] or {}
	return AlfaNucleoDB[id]
end

function N.DatosPersonaje(id)
	AlfaNucleoCharDB = type(AlfaNucleoCharDB) == "table" and AlfaNucleoCharDB or {}
	AlfaNucleoCharDB[id] = type(AlfaNucleoCharDB[id]) == "table" and AlfaNucleoCharDB[id] or {}
	return AlfaNucleoCharDB[id]
end

---------------------------------------------------------------------------
-- Utilidades comunes
---------------------------------------------------------------------------
function N.Imprimir(...) A.Print(...) end

-- 123456 cobre -> "12o 34p 56c" (o "12g 34s 56c" en inglés) con los colores del juego.
local LETRAS = N.espanol and { "o", "p", "c" } or { "g", "s", "c" }
function N.Dinero(cobre, corto)
	cobre = math.floor(tonumber(cobre) or 0)
	local signo = cobre < 0 and "-" or ""
	cobre = math.abs(cobre)
	local o, p, c = math.floor(cobre / 10000), math.floor(cobre / 100) % 100, cobre % 100
	local partes = {}
	if o > 0 then partes[#partes + 1] = ("|cffffd700%d|r%s"):format(o, LETRAS[1]) end
	if p > 0 and not (corto and o >= 100) then partes[#partes + 1] = ("|cffc7c7cf%d|r%s"):format(p, LETRAS[2]) end
	if (c > 0 and not (corto and o > 0)) or #partes == 0 then partes[#partes + 1] = ("|cffeda55f%d|r%s"):format(c, LETRAS[3]) end
	return signo .. table.concat(partes, " ")
end

-- Segundos -> "1 h 05 min" / "4 min 10 s".
function N.Duracion(seg)
	seg = math.max(0, math.floor(tonumber(seg) or 0))
	local h, m, s = math.floor(seg / 3600), math.floor(seg / 60) % 60, seg % 60
	if h > 0 then return ("%d h %02d min"):format(h, m) end
	if m > 0 then return ("%d min %02d s"):format(m, s) end
	return ("%d s"):format(s)
end

-- Ejecuta fn cuando el jugador sale de combate (o ya, si no está en combate).
-- Para todo lo que toca marcos protegidos: nunca durante el combate.
local pendientes = {}
function N.FueraDeCombate(fn)
	if not InCombatLockdown() then return fn() end
	pendientes[#pendientes + 1] = fn
end
A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	local lista = pendientes
	pendientes = {}
	for i = 1, #lista do
		local ok, err = pcall(lista[i])
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
end)
