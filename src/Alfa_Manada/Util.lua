-- Alfa - La Jauría: piezas comunes del módulo (nombres, posiciones,
-- distancias, tiempos, susurros e invitaciones). toxic3000 / La Jauría. GPL-3.0.
--
-- Nombres en Forever: los personajes llevan apellido ("Ana Smith"). Los
-- remitentes de los mensajes de addon llegan como "Ana Smith" (o con
-- "-Reino" si son de otro reino), y la lista de la hermandad puede traerlos
-- con el reino ("Ana Smith-CAMWOWUS1Realm2PvP") o con guion ("Ana-Smith").
-- U.Clave los deja en una sola forma para compararlos: sin el reino cuando
-- es el propio o uno de los reinos numerados de Forever, en minúsculas y con
-- un solo espacio entre las partes (de dónde viene la idea: CREDITOS.md).
--
-- Toda llamada al juego se comprueba antes y lo que llega "secreto" (en
-- combate o en mazmorras) se trata como desconocido.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

M.ID = "manada"
M.L = L

local U = {}
M.U = U

local type, tonumber, tostring, pcall = type, tonumber, tostring, pcall
local floor, sqrt = math.floor, math.sqrt

---------------------------------------------------------------------------
-- Valores secretos
---------------------------------------------------------------------------

function U.Secreto(v)
	return v ~= nil and issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- El valor, o nil si es secreto.
function U.Leer(v)
	if U.Secreto(v) then return nil end
	return v
end

-- Un número legible, o nil.
local function numero(v)
	v = U.Leer(v)
	return type(v) == "number" and v or nil
end
U.Numero = numero

-- Un texto legible no vacío, o nil.
local function texto(v)
	v = U.Leer(v)
	return type(v) == "string" and v ~= "" and v or nil
end
U.Texto = texto

---------------------------------------------------------------------------
-- Nombres
---------------------------------------------------------------------------

local miReinoCache
local function miReino()
	if miReinoCache then return miReinoCache end
	local r
	if GetNormalizedRealmName then
		local ok, v = pcall(GetNormalizedRealmName)
		if ok then r = texto(v) end
	end
	if not r and GetRealmName then
		local ok, v = pcall(GetRealmName)
		if ok then r = texto(v) end
	end
	if not r then return "" end
	miReinoCache = (r:gsub("[%s%-']", "")):lower()
	return miReinoCache
end

-- Si el cliente usa apellidos (Forever): el nombre completo del jugador
-- tiene un espacio.
local conApellidos
local function usaApellidos()
	if conApellidos ~= nil then return conApellidos end
	local C = A.Compat
	local ok, full = pcall(C.UnitFullName, "player")
	full = ok and texto(full) or nil
	if not full then return false end
	conApellidos = full:find(" ", 1, true) ~= nil
	return conApellidos
end

-- Quita "-Reino" cuando el reino es el propio o uno de Forever.
local function sinReino(nombre)
	local base, sufijo = nombre:match("^(.-)%-([^%-%s]+)$")
	if base and base ~= "" then
		local s = sufijo:lower():gsub("'", "")
		if s:find("^camwow") or s == miReino() then return base end
	end
	return nombre
end

-- La forma de comparar un nombre: "ana smith". nil si no se puede leer.
function U.Clave(nombre)
	nombre = texto(nombre)
	if not nombre then return nil end
	local n = sinReino(nombre)
	n = n:gsub("[%s%-]+", " "):gsub("^ ", ""):gsub(" $", "")
	if n == "" then return nil end
	return n:lower()
end

-- El nombre para mostrar: sin el reino propio, y "Ana Smith" aunque llegue
-- como "Ana-Smith" en Forever.
function U.Mostrar(nombre)
	nombre = texto(nombre)
	if not nombre then return "?" end
	local n = sinReino(nombre)
	if usaApellidos() and not n:find(" ", 1, true) then n = n:gsub("%-", " ") end
	return n
end

-- El nombre para susurrar o invitar: como lo da el juego, sin el reino
-- propio (Ambiguate "none").
function U.Destino(nombre)
	nombre = texto(nombre)
	if not nombre then return nil end
	if Ambiguate then
		local ok, v = pcall(Ambiguate, nombre, "none")
		if ok and texto(v) then return v end
	end
	return nombre
end

-- Para comparar textos sin mayúsculas ni acentos ("La Jauría" = "la jauria").
local ACENTOS = {
	["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u", ["ñ"] = "n",
	["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ü"] = "u", ["Ñ"] = "n",
}
function U.Plegar(s)
	s = texto(s)
	if not s then return "" end
	s = s:gsub("[\195][\128-\191]", function(c) return ACENTOS[c] or c end)
	return (s:lower():gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

-- En mayúsculas, también las letras con acento ("Lo más cerca" -> "LO MÁS
-- CERCA"): string.upper solo cambia las de ASCII.
function U.Mayus(s)
	s = tostring(s or ""):upper()
	return (s:gsub("\195([\160-\190])", function(c)
		local b = c:byte()
		if b == 183 then return "\195" .. c end -- ÷
		return "\195" .. string.char(b - 32)
	end))
end

-- Mi propia clave.
function U.MiClave()
	local C = A.Compat
	local ok, full = pcall(C.UnitFullName, "player")
	full = ok and texto(full) or nil
	if not full and UnitName then
		local ok2, n = pcall(UnitName, "player")
		full = ok2 and texto(n) or nil
	end
	return U.Clave(full)
end

---------------------------------------------------------------------------
-- Clases
---------------------------------------------------------------------------

-- El color de una clase ("WARRIOR"), legible sobre la ventana: r, g, b.
function U.ColorClase(file)
	local T = A.Theme
	local r, g, b
	if type(file) == "string" and file ~= "" then
		local ok, cr, cg, cb = pcall(T.ClassColor, file)
		if ok and type(cr) == "number" then r, g, b = cr, cg, cb end
	end
	if not r then return 0.85, 0.85, 0.85 end
	return r, g, b
end

-- El mismo color, ajustado para leerse como texto.
function U.ColorTexto(file)
	local r, g, b = U.ColorClase(file)
	local T = A.Theme
	local ok, lr, lg, lb = pcall(T.Legible, r, g, b)
	if ok and type(lr) == "number" then return lr, lg, lb end
	return r, g, b
end

-- El nombre de la clase en el idioma del cliente.
function U.NombreClase(file)
	if type(file) ~= "string" or file == "" then return nil end
	local t = LOCALIZED_CLASS_NAMES_MALE
	if type(t) == "table" and type(t[file]) == "string" then return t[file] end
	return nil
end

---------------------------------------------------------------------------
-- Mapas y posiciones (x, y en 0-100, como Alfa.Nav)
---------------------------------------------------------------------------

local ZONA = 3 -- Enum.UIMapType.Zone

-- La zona (no la cueva ni el pueblo) de un mapa.
function U.ZonaDe(map)
	if type(map) ~= "number" or not (C_Map and C_Map.GetMapInfo) then return map end
	for _ = 1, 12 do
		local ok, info = pcall(C_Map.GetMapInfo, map)
		if not ok or type(info) ~= "table" then break end
		local t = numero(info.mapType) or ZONA
		local parent = numero(info.parentMapID)
		if t <= ZONA or not parent or parent == 0 then break end
		map = parent
	end
	return map
end

function U.NombreMapa(map)
	if type(map) ~= "number" then return nil end
	local C = A.Compat
	local ok, name = pcall(C.MapName, map)
	if ok and texto(name) then return name end
	return nil
end

function U.EnInstancia()
	if not IsInInstance then return false end
	local ok, dentro = pcall(IsInInstance)
	if not ok then return false end
	dentro = U.Leer(dentro)
	return dentro and true or false
end

-- Dónde estoy: map, x, y (0-100); nil en instancias o si el juego no lo da.
function U.MiPosicion()
	if U.EnInstancia() then return nil end
	local C = A.Compat
	local ok, map, x, y = pcall(C.GetPlayerMapPosition)
	if not ok then return nil end
	map, x, y = numero(map), numero(x), numero(y)
	if not (map and x and y) then return nil end
	return map, x, y
end

-- Dónde está una unidad del grupo (el juego solo lo da para tu grupo).
function U.PosUnidad(unit)
	local C = A.Compat
	local ok, map, x, y = pcall(C.GetUnitMapPosition, unit)
	if not ok then return nil end
	map, x, y = numero(map), numero(x), numero(y)
	if not (map and x and y) then return nil end
	return map, x, y
end

-- Un punto del mapa en yardas del mundo: continente, wx, wy.
function U.AlMundo(map, x, y)
	if not (map and x and y) then return nil end
	local C = A.Compat
	local ok, c, wx, wy = pcall(C.MapToWorld, map, x, y)
	if not ok then return nil end
	c, wx, wy = numero(c), numero(wx), numero(wy)
	if not (c and wx and wy) then return nil end
	return c, wx, wy
end

-- Yardas de mí a un punto; nil si no se puede medir (otro continente, sin
-- posición). La segunda respuesta dice "otro" cuando está en otro continente.
-- Mi punto en el mundo, una vez por cuadro (una lista larga mide muchas
-- distancias seguidas).
local yo = { t = -1 }
local function miMundo()
	local t = U.Ahora()
	if yo.t ~= t then
		yo.t = t
		local m, mx, my = U.MiPosicion()
		yo.c, yo.wx, yo.wy = nil, nil, nil
		if m then yo.c, yo.wx, yo.wy = U.AlMundo(m, mx, my) end
	end
	return yo.c, yo.wx, yo.wy
end

function U.Distancia(map, x, y)
	local c2, wx2, wy2 = U.AlMundo(map, x, y)
	if not c2 then return nil end
	local c1, wx1, wy1 = miMundo()
	if not c1 then return nil end
	if c1 ~= c2 then return nil, "otro" end
	local dx, dy = wx2 - wx1, wy2 - wy1
	return sqrt(dx * dx + dy * dy)
end

-- "230 yd" (o metros, según el ajuste del motor).
function U.TextoDistancia(yd)
	if type(yd) ~= "number" then return nil end
	local ok, s = pcall(A.FormatDistance, yd)
	if ok and type(s) == "string" then return s end
	return ("%d yd"):format(floor(yd + 0.5))
end

---------------------------------------------------------------------------
-- Tiempos
---------------------------------------------------------------------------

function U.Ahora()
	return GetTime and GetTime() or 0
end

-- Segundos del servidor (sirve entre sesiones).
function U.Reloj()
	local C = A.Compat
	local ok, t = pcall(C.Now)
	if ok and type(t) == "number" then return t end
	return time and time() or 0
end

-- "ahora", "hace 12 s", "hace 3 min", "hace 2 h", "hace 4 días".
function U.Hace(seg)
	seg = tonumber(seg)
	if not seg then return nil end
	if seg < 5 then return L["ahora"] end
	if seg < 60 then return L["hace %d s"]:format(floor(seg)) end
	if seg < 3600 then return L["hace %d min"]:format(floor(seg / 60)) end
	if seg < 86400 then return L["hace %d h"]:format(floor(seg / 3600)) end
	local d = floor(seg / 86400)
	if d == 1 then return L["hace 1 día"] end
	return L["hace %d días"]:format(d)
end

---------------------------------------------------------------------------
-- Hermandad
---------------------------------------------------------------------------

function U.EnHermandad()
	if not IsInGuild then return false end
	local ok, v = pcall(IsInGuild)
	return ok and U.Leer(v) and true or false
end

function U.NombreHermandad()
	if not (U.EnHermandad() and GetGuildInfo) then return nil end
	local ok, name = pcall(GetGuildInfo, "player")
	return ok and texto(name) or nil
end

-- Si estoy en la hermandad del clan (Clan.lua: hermandad).
function U.EnElClan()
	local mine = U.NombreHermandad()
	local clan = M.Clan and M.Clan.hermandad
	return mine ~= nil and type(clan) == "string" and U.Plegar(mine) == U.Plegar(clan)
end

-- Un texto del clan en el idioma del cliente (Clan.lua: en).
function U.TextoClan(campo)
	local c = M.Clan or {}
	if not N.espanol and type(c.en) == "table" and c.en[campo] ~= nil then return c.en[campo] end
	return c[campo]
end

---------------------------------------------------------------------------
-- Cuenta
---------------------------------------------------------------------------

-- Las cuentas de prueba (y las restringidas) no pueden enviar mensajes de
-- addon ni usar canales propios.
function U.CuentaDePrueba()
	for _, fn in ipairs({ IsTrialAccount or false, IsVeteranTrialAccount or false, IsRestrictedAccount or false }) do
		if fn then
			local ok, v = pcall(fn)
			if ok and U.Leer(v) then return true end
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Susurrar e invitar (siempre por un clic de quien juega)
---------------------------------------------------------------------------

-- Abre el cuadro de chat con un susurro a `nombre` y, si se da, el texto ya
-- escrito: quien juega lo lee y lo envía con Intro. Nunca se envía solo.
function U.Susurrar(nombre, mensaje)
	local destino = U.Destino(nombre)
	if not destino then return false end
	local CFU = ChatFrameUtil
	if type(CFU) == "table" and type(CFU.ChooseBoxForSend) == "function" and type(CFU.OpenChat) == "function" then
		local ok = pcall(function()
			local eb = CFU.ChooseBoxForSend()
			eb:SetChatType("WHISPER")
			eb:SetTellTarget(destino)
			local activa = type(CFU.GetActiveWindow) == "function" and CFU.GetActiveWindow() or nil
			if eb ~= activa then
				CFU.OpenChat(mensaje or "")
			else
				eb:SetText(mensaje or "")
				eb:UpdateHeader()
			end
		end)
		if ok then return true end
		if type(CFU.SendTellWithMessage) == "function" and pcall(CFU.SendTellWithMessage, destino, mensaje or "") then return true end
		if type(CFU.SendTell) == "function" and pcall(CFU.SendTell, destino) then return true end
	end
	if ChatFrame_SendTell and pcall(ChatFrame_SendTell, destino) then return true end
	return false
end

function U.Invitar(nombre)
	local destino = U.Destino(nombre)
	if not destino then return false end
	if C_PartyInfo and C_PartyInfo.InviteUnit then
		return pcall(C_PartyInfo.InviteUnit, destino) and true or false
	end
	if InviteUnit then return pcall(InviteUnit, destino) and true or false end
	return false
end

-- Si alguien (por nombre) ya está en mi grupo.
function U.EnMiGrupo(nombre)
	local destino = U.Destino(nombre)
	if not destino then return false end
	for _, fn in ipairs({ UnitInParty or false, UnitInRaid or false }) do
		if fn then
			local ok, v = pcall(fn, destino)
			v = ok and U.Leer(v) or nil
			if v then return true end
		end
	end
	return false
end

-- Avisos en el chat con el prefijo de Alfa.
function U.Decir(...)
	N.Imprimir(...)
end
