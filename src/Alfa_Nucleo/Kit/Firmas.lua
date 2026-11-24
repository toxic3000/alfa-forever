-- Alfa - Kit: la firma de cada módulo (1.3.8). toxic3000 / La Jauría. GPL-3.0.
--
-- Pedido de Toxic (mejora 7): «cada aviso trae el color, el ícono y un sonido
-- corto de su módulo, para saber de dónde viene sin leerlo». Una tabla central:
--   K.FIRMAS[clave] = { nombre, color, icono, sonido (SOUNDKIT), id (FileDataID de respaldo) }
--   K.FirmaDe(o) -> firma, clave   de dónde viene un aviso: o.modulo, o.firma,
--       su o.pagina, la carpeta del archivo que lo pidió (Alfa_Rutas -> ruta)
--       o su ícono; nil si no se sabe (sale como siempre).
--   K.SonarFirma(clave, prioridad) -> bool   el sonido corto de ese módulo
--       (pasa por N.Sonar: respeta «sonidos» y No molestar; dos juntos, uno solo)
-- El aviso (Kit/Ventanas.lua) pinta su franja del color de la firma y pone el
-- ícono del módulo en una insignia chica junto al suyo. Los anuncios grandes
-- (Kit/Anuncio.lua) ya tienen su estilo propio por tipo.

local _, N = ...
local K = N.Kit

local type, rawget, pcall, tostring = type, rawget, pcall, tostring

-- Colores: los del Kit cuando hay uno que le queda; si no, uno propio (fijo,
-- se lee igual en los tres estilos).
local FIRMAS = {
	ruta = { nombre = "Ruta", color = "acento", icono = "ic-ruta", sonido = "IG_QUEST_LIST_SELECT", id = 877 },
	hoy = { nombre = "Hoy", color = "oro", icono = "ic-hoy", sonido = "IG_QUEST_LOG_OPEN", id = 844 },
	bolsas = { nombre = "Bolsas", color = { 0.86, 0.66, 0.4, 1 }, icono = "ic-bolsas", sonido = "IG_BACKPACK_OPEN", id = 862 },
	pesca = { nombre = "Pesca", color = { 0.36, 0.72, 0.95, 1 }, icono = "ic-pesca", sonido = "FISHING_REEL_IN", id = 3407 },
	combate = { nombre = "Combate", color = "peligro", icono = "ic-nivel", sonido = "IG_CREATURE_AGGRO_SELECT", id = 873 },
	curacion = { nombre = "Curación", color = "exito", icono = "ic-curacion", sonido = "IG_CHARACTER_INFO_OPEN", id = 839 },
	manada = { nombre = "La Jauría", color = { 0.55, 0.88, 0.31, 1 }, icono = "ic-manada", sonido = "IG_PLAYER_INVITE", id = 880 },
	lya = { nombre = "Lya", color = { 0.78, 0.7, 0.96, 1 }, icono = "ic-lobo", sonido = "IG_MAINMENU_OPTION_CHECKBOX_ON", id = 856 },
	comercio = { nombre = "Comercio", color = "oro", icono = "ic-comercio", sonido = "LOOT_WINDOW_COIN_SOUND", id = 120 },
	oficios = { nombre = "Oficios", color = { 0.9, 0.55, 0.3, 1 }, icono = "ic-oficios", sonido = "PUT_DOWN_SMALL_CHAIN", id = 1212 },
	mundo = { nombre = "Mundo", color = "lugar", icono = "ic-mundo", sonido = "IG_MINIMAP_OPEN", id = 821 },
	mazmorras = { nombre = "Mazmorras", color = "mazmorra", icono = "ic-mazmorra", sonido = "IG_SPELLBOOK_OPEN", id = 829 },
	talentos = { nombre = "Talentos", color = { 0.95, 0.8, 0.35, 1 }, icono = "ic-talentos", sonido = "IG_ABILITY_PAGE_TURN", id = 836 },
	comodidades = { nombre = "Comodidades", color = "pnj", icono = "ic-comodidades", sonido = "U_CHAT_SCROLL_BUTTON", id = 1115 },
	recoleccion = { nombre = "Recolección", color = { 0.55, 0.8, 0.45, 1 }, icono = "ic-recoleccion", sonido = "IG_INVENTORY_ROTATE_CHARACTER", id = 861 },
	enciclopedia = { nombre = "Enciclopedia", color = "objeto", icono = "ic-enciclopedia", sonido = "IG_ABILITY_PAGE_TURN", id = 836 },
	alfa = { nombre = "Alfa", color = "acento", icono = "ic-lobo", sonido = "IG_QUEST_LIST_OPEN", id = 875 },
}
K.FIRMAS = FIRMAS

-- La carpeta del addon que pidió el aviso -> su firma.
local POR_CARPETA = {
	Alfa_Rutas = "ruta", Alfa_Inicio = "hoy", Alfa_Bolsas = "bolsas", Alfa_Pesca = "pesca", Alfa_Combate = "combate",
	Alfa_Curacion = "curacion", Alfa_Manada = "manada", Alfa_Lya = "lya", Alfa_Comercio = "comercio",
	Alfa_Mundo = "mundo", Alfa_Mazmorras = "mazmorras", Alfa_Builds = "talentos", Alfa_Comodidades = "comodidades",
	Alfa_Recoleccion = "recoleccion", Alfa_Enciclopedia = "enciclopedia", Alfa_Bienvenida = "alfa",
	-- (1.3.8 revisión) El motor (carpeta Alfa) no es todo Ruta: se deduce por
	-- su ícono y, si no, la firma propia de Alfa (K.FirmaDe).
}
K.FIRMA_POR_CARPETA = POR_CARPETA
-- El id de una página de Alfa (N.modulos) -> su firma.
local POR_PAGINA = { rutas = "ruta", inicio = "hoy", builds = "talentos", bienvenida = "alfa" }
-- Su ícono -> su firma (lo que no se pudo saber de otro modo).
local POR_ICONO = {
	["ic-ruta"] = "ruta", ["ic-huella"] = "ruta", ["ic-guia"] = "ruta", ["ic-misiones"] = "ruta", ["ic-seguir"] = "ruta",
	["ic-flecha"] = "ruta", ["ic-hoy"] = "hoy", ["ic-reloj"] = "hoy", ["ic-bolsas"] = "bolsas", ["ic-pesca"] = "pesca",
	["ic-curacion"] = "curacion", ["ic-manada"] = "manada", ["ic-comercio"] = "comercio", ["ic-oro"] = "comercio",
	["ic-oficios"] = "oficios", ["ic-mundo"] = "mundo", ["ic-mapa"] = "mundo", ["ic-raros"] = "mundo", ["ic-descubrir"] = "mundo",
	["ic-mazmorra"] = "mazmorras", ["ic-talentos"] = "talentos", ["ic-comodidades"] = "comodidades",
	["ic-recoleccion"] = "recoleccion", ["ic-enciclopedia"] = "enciclopedia",
}

-- La carpeta del primer archivo de la pila que no es del Núcleo.
local function carpetaDeLaPila()
	if type(debugstack) ~= "function" then return nil end
	local ok, pila = pcall(debugstack, 3, 12, 0)
	if not ok or type(pila) ~= "string" then return nil end
	for carpeta in pila:gmatch("AddOns[\\/]([%w_]+)[\\/]") do
		if carpeta ~= "Alfa_Nucleo" then return carpeta end
	end
	return nil
end

function K.FirmaDe(o)
	if type(o) ~= "table" then return nil end
	local clave = o.firma or o.modulo
	if type(clave) == "string" and not FIRMAS[clave] then clave = POR_PAGINA[clave] or POR_CARPETA[clave] or clave end
	if not (type(clave) == "string" and FIRMAS[clave]) and type(o.pagina) == "string" then
		clave = POR_PAGINA[o.pagina] or (FIRMAS[o.pagina] and o.pagina) or nil
	end
	local delMotor = false
	if not (type(clave) == "string" and FIRMAS[clave]) then
		local c = carpetaDeLaPila()
		delMotor = c == "Alfa"
		clave = c and POR_CARPETA[c] or nil
	end
	if not clave and o.lobo and not o.icono then clave = "lya" end
	if not clave and type(o.icono) == "string" then clave = POR_ICONO[o.icono] end
	if not clave and delMotor then clave = "alfa" end
	if not (clave and FIRMAS[clave]) then return nil end
	return FIRMAS[clave], clave
end

-- El sonido corto del módulo (por N.Sonar, Momentos.lua: respeta el ajuste y No molestar).
function K.SonarFirma(clave, p)
	local f = FIRMAS[clave or ""]
	if not f then return false end
	local Sp = rawget(N, "SonidoPermitido")
	if type(Sp) == "function" and not Sp(p or 3) then return false end
	local Sn = rawget(N, "SonarId")
	if type(Sn) == "function" then return Sn(f.sonido, f.id, "firma:" .. tostring(clave), p) end
	return false
end
