-- Alfa - Mundo: geometría del mapa continuo (Toxic / La Jauría). GPL-3.0.
--
-- Todo el mundo se dibuja en "unidades de mundo": el mapa de Azeroth (947)
-- normalizado, 0..1 de izquierda a derecha y de arriba abajo. Cada mapa
-- (continente, zona, ciudad) se coloca con C_Map.GetMapRectOnMap(mapa, 947)
-- (ver CREDITOS.md). Nada aquí escribe en el mapa de Blizzard: solo se leen
-- datos del cliente.
--
--   Geo.Rect(mapa) -> l, r, t, b            su rectángulo en 947 (o nil)
--   Geo.DeMapa(mapa, x, y) -> u, v          x, y en porcentaje (0..100)
--   Geo.AMapa(mapa, u, v) -> x, y           al revés
--   Geo.DeYardas(c, wx, wy) -> u, v         posición del mundo (yardas)
--   Geo.Cadena(u, v) -> continente, zona     lo que hay bajo un punto
--   Geo.Capa(mapa) -> info, archivos         la primera capa de arte del mapa
--   Geo.Continentes(), Geo.Zonas(cont)       los mapas que se dibujan
--   Geo.Niveles(zona) -> min, max            rango de niveles (datos del motor)
--   Geo.Nombre(mapa)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A

local type, pairs, ipairs, pcall, tonumber, min, max = type, pairs, ipairs, pcall, tonumber, math.min, math.max

local Geo = {}
M.Geo = Geo

local MUNDO = 947
Geo.MUNDO = MUNDO
-- Enum.UIMapType (MapConstantsDocumentation): 2 continente, 3 zona.
local CONTINENTE, ZONA = 2, 3
Geo.CONTINENTE, Geo.ZONA = CONTINENTE, ZONA

local function num(v) return type(v) == "number" and v or nil end

-- Un vector para las llamadas de C_Map que lo piden (el cliente solo lee x, y).
local vector
local function vec(x, y)
	if not vector then vector = type(CreateVector2D) == "function" and CreateVector2D(0, 0) or {} end
	if type(vector) == "table" then vector.x, vector.y = x, y end
	return vector
end

local function xy(v)
	if type(v) ~= "table" then return nil end
	if type(v.GetXY) == "function" then return v:GetXY() end
	return v.x, v.y
end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return false end
	return pcall(fn, ...)
end

local function api(nombre)
	local M_ = C_Map
	return type(M_) == "table" and M_[nombre] or nil
end

---------------------------------------------------------------------------
-- Rectángulos en el mapa del mundo
---------------------------------------------------------------------------

local rects = {} -- mapa -> { l, r, t, b } | false

function Geo.Rect(mapa)
	if mapa == MUNDO then return 0, 1, 0, 1 end
	if type(mapa) ~= "number" then return nil end
	local r = rects[mapa]
	if r == nil then
		r = false
		local ok, l, rr, t, b = llamar(api("GetMapRectOnMap"), mapa, MUNDO)
		l, rr, t, b = num(l), num(rr), num(t), num(b)
		if ok and l and rr and t and b and rr > l and b > t then r = { l, rr, t, b } end
		rects[mapa] = r
	end
	if r then return r[1], r[2], r[3], r[4] end
	return nil
end

-- x, y: porcentaje del mapa (0..100), como los da C_Map por cien.
function Geo.DeMapa(mapa, x, y)
	x, y = num(x), num(y)
	if not (x and y) then return nil end
	local l, r, t, b = Geo.Rect(mapa)
	if not l then return nil end
	return l + (r - l) * x / 100, t + (b - t) * y / 100
end

function Geo.AMapa(mapa, u, v)
	local l, r, t, b = Geo.Rect(mapa)
	if not (l and num(u) and num(v)) then return nil end
	return (u - l) / (r - l) * 100, (v - t) / (b - t) * 100
end

---------------------------------------------------------------------------
-- Mapas que se dibujan: continentes del mundo y sus zonas
---------------------------------------------------------------------------

local function hijos(mapa, tipo)
	local ok, lista = llamar(api("GetMapChildrenInfo"), mapa, tipo)
	if ok and type(lista) == "table" then return lista end
	return {}
end

function Geo.Info(mapa)
	if type(mapa) ~= "number" then return nil end
	local ok, info = llamar(api("GetMapInfo"), mapa)
	if ok and type(info) == "table" and num(info.mapID) then return info end
	return nil
end

function Geo.Nombre(mapa)
	local C = A.Compat
	local nombre = C and type(C.MapName) == "function" and C.MapName(mapa)
	if type(nombre) == "string" and nombre ~= "" then return nombre end
	local info = Geo.Info(mapa)
	return info and type(info.name) == "string" and info.name or nil
end

local function esCiudad(mapa)
	local ok, si = llamar(api("IsCityMap"), mapa)
	return ok and si == true
end
Geo.EsCiudad = esCiudad

local continentes
function Geo.Continentes()
	if continentes then return continentes end
	continentes = {}
	for _, info in ipairs(hijos(MUNDO, CONTINENTE)) do
		local id = type(info) == "table" and num(info.mapID)
		if id and info.mapType == CONTINENTE and Geo.Rect(id) then continentes[#continentes + 1] = id end
	end
	return continentes
end

-- Zonas y ciudades de un continente, en el orden del cliente.
local zonas = {}
function Geo.Zonas(cont)
	local lista = zonas[cont]
	if lista then return lista end
	lista = {}
	for _, info in ipairs(hijos(cont, ZONA)) do
		local id = type(info) == "table" and num(info.mapID)
		if id and info.mapType == ZONA and Geo.Rect(id) then
			lista[#lista + 1] = { id = id, ciudad = esCiudad(id) }
		end
	end
	zonas[cont] = lista
	return lista
end

---------------------------------------------------------------------------
-- Arte de un mapa: su primera capa y sus archivos (como MapCanvasDetailLayer)
---------------------------------------------------------------------------

local capas = {} -- mapa -> { info, archivos } | false

function Geo.Capa(mapa)
	local c = capas[mapa]
	if c == nil then
		c = false
		local ok, lista = llamar(api("GetMapArtLayers"), mapa)
		local info = ok and type(lista) == "table" and lista[1] or nil
		if type(info) == "table" and (num(info.layerWidth) or 0) > 0 and (num(info.layerHeight) or 0) > 0
			and (num(info.tileWidth) or 0) > 0 and (num(info.tileHeight) or 0) > 0 then
			local ok2, archivos = llamar(api("GetMapArtLayerTextures"), mapa, 1)
			if ok2 and type(archivos) == "table" and #archivos > 0 then c = { info, archivos } end
		end
		capas[mapa] = c
	end
	if c then return c[1], c[2] end
	return nil
end

-- Tamaño del arte del mundo (unidades de dibujo del lienzo).
function Geo.TamanoMundo()
	local info = Geo.Capa(MUNDO)
	if info then return info.layerWidth, info.layerHeight end
	return 1002, 668
end

---------------------------------------------------------------------------
-- Yardas del mundo -> mapa continuo (por el mapa del continente)
---------------------------------------------------------------------------

local deInstancia -- id de continente del juego (0, 1, ...) -> su uiMapID

local function instancias()
	if deInstancia then return deInstancia end
	deInstancia = {}
	for _, cont in ipairs(Geo.Continentes()) do
		local ok, c = llamar(api("GetWorldPosFromMapPos"), cont, vec(0.5, 0.5))
		if ok and num(c) then deInstancia[c] = cont end
	end
	return deInstancia
end

function Geo.DeYardas(c, wx, wy)
	if not (num(c) and num(wx) and num(wy)) then return nil end
	local cont = instancias()[c]
	local C = A.Compat
	if not (cont and C and type(C.WorldToMap) == "function") then return nil end
	local x, y = C.WorldToMap(c, wx, wy, cont)
	return Geo.DeMapa(cont, x, y)
end

---------------------------------------------------------------------------
-- Qué hay bajo un punto: continente y zona (o ciudad). Una ciudad cuenta
-- solo en el centro de su rectángulo, porque el continente la da para todo
-- su rectángulo (ver CREDITOS.md).
---------------------------------------------------------------------------

local BORDE_CIUDAD = 0.25
local zonaDeCiudad = {}

local function infoEn(mapa, x, y)
	local ok, info = llamar(api("GetMapInfoAtPosition"), mapa, x, y)
	if ok and type(info) == "table" and num(info.mapID) and info.mapID ~= mapa then return info end
	return nil
end

-- La zona que rodea a una ciudad: la que contiene su centro.
local function zonaDe(ciudad, cont)
	local z = zonaDeCiudad[ciudad]
	if z ~= nil then return z or nil end
	z = false
	local l, r, t, b = Geo.Rect(ciudad)
	if l then
		local cu, cv = (l + r) / 2, (t + b) / 2
		for _, zona in ipairs(Geo.Zonas(cont)) do
			if not zona.ciudad then
				local zl, zr, zt, zb = Geo.Rect(zona.id)
				if zl and cu >= zl and cu <= zr and cv >= zt and cv <= zb then
					z = zona.id
					break
				end
			end
		end
	end
	zonaDeCiudad[ciudad] = z
	return z or nil
end

-- -> continente, zona (o ciudad) | nil
function Geo.Cadena(u, v)
	if not (num(u) and num(v)) then return nil end
	local info = infoEn(MUNDO, u, v)
	if not (info and info.mapType == CONTINENTE) then return nil end
	local cont = info.mapID
	local l, r, t, b = Geo.Rect(cont)
	if not l then return cont end
	local cx, cy = (u - l) / (r - l), (v - t) / (b - t)
	local z = infoEn(cont, cx, cy)
	if not (z and z.mapType == ZONA) then return cont end
	if esCiudad(z.mapID) then
		local zl, zr, zt, zb = Geo.Rect(z.mapID)
		local dentro = false
		if zl then
			local fx, fy = (u - zl) / (zr - zl), (v - zt) / (zb - zt)
			dentro = min(fx, 1 - fx) >= BORDE_CIUDAD and min(fy, 1 - fy) >= BORDE_CIUDAD
		end
		if not dentro then
			local alrededor = zonaDe(z.mapID, cont)
			if alrededor then return cont, alrededor end
		end
	end
	return cont, z.mapID
end

---------------------------------------------------------------------------
-- Niveles de zona: los del motor (Maps/ZoneLevels.lua, datos de pfQuest),
-- y si faltan, los que da el cliente (C_Map.GetMapLevels).
---------------------------------------------------------------------------

function Geo.Niveles(zona)
	local Maps = A.Maps
	if Maps and type(Maps.GetZoneLevels) == "function" then
		local lo, hi = Maps.GetZoneLevels(zona)
		if num(lo) and num(hi) then return lo, hi end
	end
	local ok, lo, hi = llamar(api("GetMapLevels"), zona)
	lo, hi = num(lo), num(hi)
	if ok and lo and hi and lo > 0 and hi >= lo then return lo, hi end
	return nil
end

function Geo.NivelJugador()
	local C = A.Compat
	local info = C and type(C.GetPlayerInfo) == "function" and C.GetPlayerInfo()
	return type(info) == "table" and num(info.level) or nil
end

-- "12–20" con el color del motor para tu nivel.
function Geo.TextoNiveles(lo, hi)
	local Maps = A.Maps
	if not (num(lo) and num(hi)) then return nil end
	local texto = lo == hi and tostring(lo) or (lo .. "–" .. hi)
	if Maps and type(Maps.FormatLevels) == "function" then texto = Maps.FormatLevels(lo, hi) end
	local color = "quest"
	if Maps and type(Maps.LevelColor) == "function" then color = Maps.LevelColor(lo, hi, Geo.NivelJugador()) end
	return texto, color
end

---------------------------------------------------------------------------
-- Dónde estás: el jugador y su grupo, en el mapa continuo
---------------------------------------------------------------------------

-- -> u, v, mapa, x, y (porcentaje) | nil
function Geo.Jugador()
	local C = A.Compat
	if not (C and type(C.GetPlayerMapPosition) == "function") then return nil end
	local mapa, x, y = C.GetPlayerMapPosition()
	if not (num(mapa) and num(x) and num(y)) then return nil end
	local u, v = Geo.DeMapa(mapa, x, y)
	if not u then
		-- Una cueva o un mapa pequeño fuera de 947: por la zona que lo contiene.
		local zona = type(C.GetUnitZone) == "function" and C.GetUnitZone("player")
		if num(zona) and zona ~= mapa and type(C.MapToWorld) == "function" then
			local c, wx, wy = C.MapToWorld(mapa, x, y)
			u, v = Geo.DeYardas(c, wx, wy)
		end
	end
	if not u then return nil end
	return u, v, mapa, x, y
end

function Geo.Unidad(unidad)
	local C = A.Compat
	if not (C and type(C.GetUnitMapPosition) == "function") then return nil end
	local mapa, x, y = C.GetUnitMapPosition(unidad)
	if not (num(mapa) and num(x) and num(y)) then return nil end
	return Geo.DeMapa(mapa, x, y)
end

function Geo.Orientacion()
	local C = A.Compat
	local f = C and type(C.GetPlayerFacing) == "function" and C.GetPlayerFacing()
	if type(f) ~= "number" or (C.IsSecret and C.IsSecret(f)) then return nil end
	return f
end

-- Un pin del motor (Polestar.Pins): map/x/y (f = "e" en el marco Era) o c/wx/wy.
function Geo.DePin(p)
	if type(p) ~= "table" then return nil end
	if num(p.c) and num(p.wx) and num(p.wy) then return Geo.DeYardas(p.c, p.wx, p.wy) end
	if not (num(p.map) and num(p.x) and num(p.y)) then return nil end
	if p.f == "e" then
		local C = A.Compat
		if C and type(C.MapToWorld) == "function" then
			local c, wx, wy = C.MapToWorld(p.map, p.x, p.y, "e")
			return Geo.DeYardas(c, wx, wy)
		end
		return nil
	end
	return Geo.DeMapa(p.map, p.x, p.y)
end

-- Encaja un rectángulo de mundo entre 0..1 (para centrar la vista).
function Geo.Encajar(u, v)
	return max(0, min(1, u)), max(0, min(1, v))
end
