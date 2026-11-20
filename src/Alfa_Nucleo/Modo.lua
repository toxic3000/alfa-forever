-- Alfa - Núcleo: Alfa sencillo o completo (1.2.9). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- «Sencillo» deja a la vista lo esencial: Hoy, Ruta, Mapa (Mundo), Bolsas y
-- Lya, más Ajustes. Lo demás sigue funcionando: solo no sale en las
-- secciones de la ventana de Alfa (se abre con su comando, la búsqueda o un
-- enlace). Y salen menos avisos: los marcados K.Aviso({ detalle = true }).
-- «Completo» es todo Alfa. El ajuste es bienvenida.modo (Alfa_Bienvenida lo
-- registra; sin ella, Alfa es completo).
--
--   N.Modo() -> "sencillo" | "completo"     N.Sencillo() -> bool
--   N.ESENCIALES[clave de página] = true      N.PaginaVisible(clave) -> bool
--
-- La barra del motor pregunta N.PaginaVisible por cada página (listed, en
-- motor/Alfa/UI/Options.lua); con «Completo» todas salen.

local _, N = ...
local A = N.A

N.ESENCIALES = { inicio = true, rutas = true, mundo = true, bolsas = true, lya = true }

function N.Modo()
	local m = A and A.Get and A.Get("bienvenida.modo")
	return m == "sencillo" and "sencillo" or "completo"
end
function N.Sencillo() return N.Modo() == "sencillo" end

local function opciones() return A and A.UI and A.UI.Options end

-- 1.3.2: las páginas avanzadas del motor (para autores de guías y quien usa
-- mando u otros addons) no salen en Ajustes con Alfa sencillo; siguen ahí con
-- su comando, la búsqueda o «Completo».
N.AVANZADAS = { recorder = true, guidepacks = true, integrations = true, gamepad = true, thanks = true }

function N.PaginaVisible(clave)
	if not N.Sencillo() or type(clave) ~= "string" then return true end
	if N.ESENCIALES[clave] then return true end
	if N.AVANZADAS[clave] then return false end
	local O = opciones()
	local sec = O and O.SectionOf and O.SectionOf(clave)
	-- Ajustes (y lo que no tiene sección) siempre a la vista.
	return sec == nil or sec == "ajustes"
end

-- La barra de la ventana de Alfa pregunta N.PaginaVisible por cada página
-- (motor/Alfa/UI/Options.lua, listed): sin páginas a la vista, una sección
-- no sale, y elegir una sección abre una de sus páginas a la vista.
-- (Hasta la primera ola de la 1.2.9 el núcleo envolvía la barra; ya no hace falta.)
N.EnvolverBarra = function() return true end

local function repintarBarra()
	local O = opciones()
	if O and O.frame and O.frame.IsShown and O.frame:IsShown() and O.RefreshNav then pcall(O.RefreshNav) end
end

if A and A.On then
	A.On("SETTING_CHANGED", function(ruta)
		if ruta == "bienvenida.modo" or ruta == "bienvenida" or ruta == "" then repintarBarra() end
	end)
end
