-- Alfa - Mundo: entradas y salidas (toxic3000 / La Jauría). GPL-3.0.
--
-- Dos capas propias de Alfa.Pins (mapa de Alfa, mapa del juego y minimapa),
-- en el grupo "Entradas y salidas" del control de capas junto a las
-- entradas de mazmorras y los barcos del motor (Capas.lua):
--   mundo.salidas   por dónde se pasa de una zona a otra: los pasos, túneles,
--                   puertas y puentes del grafo de navegación del motor
--                   (AlfaNavChokepoints de Alfa_Nav, que parte de Shortest
--                   Path Forever) cuyos dos lados caen en zonas distintas. Un
--                   pin en cada lado, "Hacia <zona> (niv. x–y)", con una
--                   flechita hacia la otra zona en el mapa de Alfa. En el
--                   mapa del juego solo en los mapas de zona (minMapType).
--   mundo.portales  los portales a pie del motor (Nav.GetTravelData) que tu
--                   facción puede usar: "Portal a <destino>".
--
-- Costo: las salidas se arman una sola vez (unos 200 pines, cada lado se
-- ubica con un par de llamadas a C_Map), unos segundos después de entrar al
-- juego, y solo se rehacen si cambia el tema. Alfa_Nav no se carga desde
-- aquí (arma ~26 MB): si aún no está, se reintenta al cargarse o al abrir el
-- mapa de Alfa. El motor indexa los pines por celdas, y el mapa de Alfa solo
-- crea marcos (reusados) para los que caen en la vista.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local Geo = M.Geo

local type, pairs, ipairs, pcall, format, atan2, sqrt = type, pairs, ipairs, pcall, string.format, math.atan2, math.sqrt

local E = {}
M.Entradas = E

local CAPA_SALIDAS, CAPA_PORTALES = "mundo.salidas", "mundo.portales"
E.CAPA_SALIDAS, E.CAPA_PORTALES = CAPA_SALIDAS, CAPA_PORTALES
local JUNTAR = 400 -- yardas: dos salidas de un mismo lado hacia la misma zona más cerca que esto son una
local ICONO = { tunnel = "map:cave", cave = "map:cave", bridge = "map:bridge" } -- el resto: "map:pass"

local salidas          -- lista de pines armada (nil: aún no)
local login = false

local function rgb(nombre)
	local T = A.Theme
	if T and type(T.Color) == "function" then
		local ok, r, g, b = pcall(T.Color, nombre)
		if ok and type(r) == "number" then return r, g, b end
	end
	return 1, 1, 1
end

local function color(nombre)
	local r, g, b = rgb(nombre)
	return { r, g, b, 1 }
end

local function datosNav() return rawget(_G, "AlfaNavChokepoints") end
function E.HayDatos() return type(datosNav()) == "table" end

---------------------------------------------------------------------------
-- Salidas de zona
---------------------------------------------------------------------------

-- "12–20" de una zona (sin color) | nil
local function niveles(zona)
	local lo, hi = Geo.Niveles(zona)
	if not lo then return nil end
	return (Geo.TextoNiveles(lo, hi)), lo, hi
end

local function tipSalida(zona, nombre)
	return function(tip)
		tip:SetText(format(L["Hacia %s"], nombre), rgb("text"))
		local texto, lo, hi = niveles(zona)
		if texto then
			local Maps = A.Maps
			local col = Maps and type(Maps.LevelColor) == "function" and Maps.LevelColor(lo, hi, Geo.NivelJugador()) or "quest"
			tip:AddLine(format((lo and lo == hi) and L["Nivel %s"] or L["Niveles %s"], texto), rgb(col)) -- 1.4.0: «Nivel 60»
		end
		tip:AddLine(L["En el mapa de Alfa, clic: seguirla con la flecha o guardarla como marcador."], rgb("textDim"))
	end
end

-- Un lado de un paso: el pin en `s` (en la zona `desde`) hacia la zona `hacia`.
local function agregar(lista, vistos, c, s, desde, hacia, du, dv, kind, Wm, Hm)
	local clave = desde .. ">" .. hacia
	local cerca = vistos[clave]
	if not cerca then
		cerca = {}
		vistos[clave] = cerca
	end
	for _, o in ipairs(cerca) do
		if o.c == c and sqrt((o.wx - s.wx) ^ 2 + (o.wy - s.wy) ^ 2) < JUNTAR then return end
	end
	local nombre = Geo.Nombre(hacia)
	if not nombre then return end
	local texto = niveles(hacia)
	local etiqueta = texto and format(L["Hacia %s (niv. %s)"], nombre, texto) or format(L["Hacia %s"], nombre)
	local p = {
		c = c, wx = s.wx, wy = s.wy,
		icon = ICONO[kind] or "map:pass", size = 13, minimapSize = 12, color = color("link"), priority = 1,
		label = etiqueta, etiqueta = etiqueta, tooltip = tipSalida(hacia, nombre),
		-- La flechita del mapa de Alfa: hacia el otro lado (0 = arriba, contra el reloj).
		rumbo = atan2(-du * Wm, -dv * Hm),
	}
	cerca[#cerca + 1] = p
	lista[#lista + 1] = p
end

-- La zona (uiMapID) de un área de AlfaNavChokepoints (zoneArea, de la tabla
-- de áreas del juego): por su nombre en tu idioma entre las zonas y ciudades
-- del mapa 947. Así manda el dato del motor, no lo que da el mapa justo en
-- la orilla de dos zonas.
local porNombre
local function zonaDeArea(area)
	local C = A.Compat
	if type(area) ~= "number" or not (C and type(C.GetAreaName) == "function") then return nil end
	local ok, nombre = pcall(C.GetAreaName, area)
	if not (ok and type(nombre) == "string" and nombre ~= "") then return nil end
	if not porNombre then
		porNombre = {}
		for _, cont in ipairs(Geo.Continentes()) do
			for _, z in ipairs(Geo.Zonas(cont)) do
				local n = Geo.Nombre(z.id)
				if n and porNombre[n] == nil then porNombre[n] = z.id end
			end
		end
	end
	return porNombre[nombre]
end

-- La zona de un lado: la de su área; si no es una zona del mapa, la que hay bajo el punto.
local function zonaDeLado(s, u, v)
	local z = zonaDeArea(s.zoneArea)
	if z then return z end
	local _, bajo = Geo.Cadena(u, v)
	return bajo
end

local function armarSalidas()
	local datos = datosNav()
	if type(datos) ~= "table" then return nil end
	local Wm, Hm = Geo.TamanoMundo()
	local lista, vistos = {}, {}
	for c, puntos in pairs(datos) do
		if type(puntos) == "table" then
			for _, p in ipairs(puntos) do
				local lados = type(p) == "table" and p.kind ~= "lift" and p.sides
				local a, b = type(lados) == "table" and lados[1], type(lados) == "table" and lados[2]
				-- Lados en dos áreas distintas: puede ser un paso entre zonas.
				if type(a) == "table" and type(b) == "table" and a.zoneArea ~= b.zoneArea
					and type(a.wx) == "number" and type(b.wx) == "number" then
					local ua, va = Geo.DeYardas(c, a.wx, a.wy)
					local ub, vb = Geo.DeYardas(c, b.wx, b.wy)
					if ua and ub then
						local za, zb = zonaDeLado(a, ua, va), zonaDeLado(b, ub, vb)
						if za and zb and za ~= zb then
							agregar(lista, vistos, c, a, za, zb, ub - ua, vb - va, p.kind, Wm, Hm)
							agregar(lista, vistos, c, b, zb, za, ua - ub, va - vb, p.kind, Wm, Hm)
						end
					end
				end
			end
		end
	end
	return lista
end

---------------------------------------------------------------------------
-- Portales a pie
---------------------------------------------------------------------------

local function armarPortales()
	local Nv, Maps = A.Nav, A.Maps
	local ok, d = false, nil
	if Nv and type(Nv.GetTravelData) == "function" then ok, d = pcall(Nv.GetTravelData) end
	local lista = {}
	if not (ok and type(d) == "table" and type(d.portals) == "table") then return lista end
	local faccion = Maps and type(Maps.Faction) == "function" and Maps.Faction() or 0
	local T = Nv.travel
	local col = color("link")
	for _, t in ipairs(d.portals) do
		local a, b = t.a, t.b
		local puede = not (Maps and type(Maps.Allowed) == "function") or Maps.Allowed(t.faction or 3, faccion)
		if puede and type(a) == "table" and type(b) == "table" and type(a.wx) == "number" then
			local destino = T and type(T.PlaceName) == "function" and T.PlaceName(b) or b.name or t.name or ""
			local texto = format(L["Portal a %s"], destino)
			lista[#lista + 1] = {
				c = a.c, wx = a.wx, wy = a.wy,
				icon = "map:portal", size = 15, minimapSize = 13, color = col, priority = 2,
				label = texto, etiqueta = texto,
				tooltip = function(tip)
					tip:SetText(texto, rgb("text"))
					tip:AddLine(L["En el mapa de Alfa, clic: seguirla con la flecha o guardarla como marcador."], rgb("textDim"))
				end,
			}
		end
	end
	return lista
end

---------------------------------------------------------------------------
-- Publicar
---------------------------------------------------------------------------

function E.Refrescar()
	local Pins = A.Pins
	if not (login and Pins and type(Pins.SetLayer) == "function") then return end
	if A.Get("mundo.salidas") ~= false then
		if not salidas then salidas = armarSalidas() end
		if salidas and #salidas > 0 then
			Pins.SetLayer(CAPA_SALIDAS, salidas, { world = true, minimap = true, edge = false, minMapType = Geo.ZONA })
		else
			Pins.ClearLayer(CAPA_SALIDAS)
		end
	else
		Pins.ClearLayer(CAPA_SALIDAS)
	end
	local portales = A.Get("mundo.portales") ~= false and armarPortales() or nil
	if portales and #portales > 0 then
		Pins.SetLayer(CAPA_PORTALES, portales, { world = true, minimap = true, edge = false })
	else
		Pins.ClearLayer(CAPA_PORTALES)
	end
end

-- Al abrir el mapa de Alfa: si las salidas faltan porque Alfa_Nav llegó tarde.
function E.Preparar()
	if login and not salidas and A.Get("mundo.salidas") ~= false and E.HayDatos() then E.Refrescar() end
end

if type(A.OnLogin) == "function" then
	A.OnLogin(function()
		login = true
		-- Unos segundos después de entrar: nada de esto traba la pantalla de carga.
		if type(A.After) == "function" then A.After(4, E.Refrescar) else E.Refrescar() end
	end)
end

A.RegisterEvent("ADDON_LOADED", function(_, nombre)
	if nombre == "Alfa_Nav" and login and not salidas then
		if type(A.After) == "function" then A.After(1, E.Refrescar) else E.Refrescar() end
	end
end)

A.On("SETTING_CHANGED", function(path)
	if path == "" or path == "mundo" or path == "mundo.salidas" or path == "mundo.portales" then E.Refrescar() end
end)

local T = A.Theme
if T and type(T.OnChanged) == "function" then
	T.OnChanged(function()
		salidas = nil -- los colores van dentro de cada pin
		E.Refrescar()
	end)
end
