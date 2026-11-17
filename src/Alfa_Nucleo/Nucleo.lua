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
-- [locale] = { ["texto en español"] = "traducción" }. Los diccionarios viven
-- en el paquete de idioma del motor (Alfa_<locale>, que solo se carga en su
-- idioma; tools/build.py los pone ahí) y llegan en AlfaNucleoIdiomas, que
-- se lee en cada consulta por si el paquete cargó después.
N.idiomas = N.idiomas or {}
local function diccionario()
	return N.idiomas[locale] or (AlfaNucleoIdiomas and AlfaNucleoIdiomas[locale])
end

function N.Textos(en)
	if N.espanol then
		return setmetatable({}, { __index = function(_, k) return k end })
	end
	return setmetatable({}, { __index = function(_, k)
		local d = diccionario()
		return (d and d[k]) or (type(en) == "table" and en[k]) or k
	end })
end

-- Un texto suelto que trae su versión en español y en inglés (por ejemplo,
-- los consejos de Mazmorras): devuelve el del idioma del cliente.
function N.Traducir(es, en)
	if N.espanol then return es end
	local d = diccionario()
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

---------------------------------------------------------------------------
-- El idioma de Alfa (src/Alfa_Idioma) y la bienvenida obligatoria
---------------------------------------------------------------------------
-- -> true si hace falta /reload para verlo. loc nil: el idioma del juego.
function N.PonerIdioma(loc)
	if type(AlfaPonerIdioma) ~= "function" then return false end
	return AlfaPonerIdioma(loc) and true or false
end
function N.Idiomas() return AlfaIdiomas or { { N.locale, N.locale } } end

---------------------------------------------------------------------------
-- Empezar una ruta o seguir algo desde una ventana de Alfa ("Seguir",
-- "Guíame", "Llévame"...): se cierran las ventanas de Alfa que tapan la
-- pantalla y queda la de seguimiento con la flecha hacia el objetivo.
-- Se llama desde el clic del jugador, nunca por un avance automático.
---------------------------------------------------------------------------
local TAPAN = { "AlfaEnciclopediaVentana", "AlfaAsistente", "AlfaBiblioteca", "AlfaCamino",
	"AlfaRutaTexto", "AlfaMundoMapa" }
function N.EmpezarRuta()
	if A and A.Set then A.Set("ui.shown", true) end
	local function cerrar()
		local UI = A and A.UI
		for _, parte in ipairs({ "Options", "Picker" }) do
			local f = UI and UI[parte] and UI[parte].frame
			if f and f.IsShown and f:IsShown() then f:Hide() end
		end
		for _, nombre in ipairs(TAPAN) do
			local f = rawget(_G, nombre)
			if f and f.IsShown and f:IsShown() then f:Hide() end
		end
		-- Y cualquier otra ventana del Kit que tape (Kit/Ventanas.lua): así
		-- una ventana nueva no tiene que anotarse en TAPAN.
		local K = N.Kit
		if K and K.CerrarLasQueTapan then pcall(K.CerrarLasQueTapan) end
	end
	-- en el siguiente cuadro: no cerrar la ventana a mitad de su propio clic
	if C_Timer and C_Timer.After then C_Timer.After(0, cerrar) else cerrar() end
end

-- Mientras falte terminar la bienvenida (Alfa_Bienvenida), Alfa no se usa:
-- abrir cualquier ventana suya abre la bienvenida. Los módulos que abren una
-- ventana sin pasar por el motor preguntan antes con N.Permitido().
local function pendiente()
	local B = rawget(_G, "AlfaBienvenida")
	if not (B and type(B.Pendiente) == "function") then return false end
	local ok, si = pcall(B.Pendiente)
	return ok and si == true
end
function N.Permitido()
	if not pendiente() then return true end
	local B = rawget(_G, "AlfaBienvenida")
	if B and type(B.Abrir) == "function" then pcall(B.Abrir) end
	return false
end
if A then
	-- Reportar un problema (y copiar su texto o la invitación al Discord)
	-- sigue abierto aunque falte la configuración: quien se atora en ella
	-- tiene que poder decirlo.
	local SIEMPRE = { SHOW_REPORT = true, SHOW_COPY = true, SHOW_DISCORD = true }
	A.Puerta = function(msg)
		if SIEMPRE[msg] then return false end
		return not N.Permitido()
	end
	-- "Reportar un problema" del motor (botón del bicho, menú del minimapa,
	-- /alfa report) abre el reporte de Alfa (Alfa_Manada: va al buzón privado
	-- del Discord de La Jauría); sin ese módulo, sigue el del motor.
	if A.DesviosDeMensajes then
		A.DesviosDeMensajes.SHOW_REPORT = function()
			local R = rawget(_G, "AlfaReporte")
			if not (R and type(R.Abrir) == "function") then return false end
			local ok = pcall(R.Abrir, "error")
			return ok
		end
	end
end

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

-- 123456 cobre -> "12 34 56" con el ícono de cada moneda y los colores del
-- juego. Las monedas siguen el estilo de Alfa: en Alfa y Cristal, las propias
-- (Media/moneda-<metal>-<estilo>, tools/monedas.py); en Clásico WoW, las del
-- juego. N.DineroTexto da "12o 34p 56c" sin íconos, para textos que se copian
-- (una caja de texto muestra los códigos de los íconos tal cual).
local LETRAS = N.espanol and { "o", "p", "c" } or { "g", "s", "c" }
local COLOR = { "|cffffd700", "|cffc7c7cf", "|cffeda55f" }
local METAL = { "oro", "plata", "cobre" }
local DEL_JUEGO = { "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon", "Interface\\MoneyFrame\\UI-CopperIcon" }
local PROPIAS = "Interface\\AddOns\\Alfa_Nucleo\\Media\\moneda-%s-%s"

local function iconoMoneda(i)
	local K = N.Kit
	local estilo = K and K.Estilo and K.Estilo() or "alfa"
	local ruta = estilo == "clasico" and DEL_JUEGO[i] or PROPIAS:format(METAL[i], estilo == "cristal" and "cristal" or "alfa")
	return "|T" .. ruta .. ":0:0:1:0|t"
end

local function dinero(cobre, corto, conIconos)
	cobre = math.floor(tonumber(cobre) or 0)
	local signo = cobre < 0 and "-" or ""
	cobre = math.abs(cobre)
	local valores = { math.floor(cobre / 10000), math.floor(cobre / 100) % 100, cobre % 100 }
	local partes = {}
	local function poner(i)
		local marca = conIconos and iconoMoneda(i) or LETRAS[i]
		partes[#partes + 1] = COLOR[i] .. valores[i] .. "|r" .. marca
	end
	local o, p, c = valores[1], valores[2], valores[3]
	if o > 0 then poner(1) end
	if p > 0 and not (corto and o >= 100) then poner(2) end
	if (c > 0 and not (corto and o > 0)) or #partes == 0 then poner(3) end
	return signo .. table.concat(partes, " ")
end

function N.Dinero(cobre, corto) return dinero(cobre, corto, true) end
function N.DineroTexto(cobre, corto) return dinero(cobre, corto, false) end

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
