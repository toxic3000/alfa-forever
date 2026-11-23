-- Alfa - Mundo: lo que te falta en tu zona (1.2.9). toxic3000 / La Jauría. GPL-3.0.
--
-- Dos capas propias de Alfa.Pins, para la zona donde estás:
--   mundo.porDescubrir  los rincones de la zona que todavía no exploras: las
--                       piezas del mapa que el juego aún te tapa (las mismas
--                       que revela «Zonas sin descubrir»: UI.ZoneArt del motor
--                       contra C_MapExplorationInfo.GetExploredMapTextures), un
--                       pin en el centro de cada una. Descubrir da experiencia;
--                       cuánto, Alfa lo aprende del mensaje del juego al
--                       descubrir (ERR_ZONE_EXPLORED_XP) y lo dice en el pin.
--   mundo.vuelosFaltan  los maestros de vuelo de tu facción (y los neutrales)
--                       de tu zona que todavía no conoces (Nav.UnknownTaxiOn
--                       del motor). Clic: la flecha te lleva.
-- Se rehacen al cambiar de zona, al descubrir algo, al abrir el mapa de vuelos
-- y al cambiar sus ajustes. Solo tu zona: unas decenas de pines a lo mucho.
--
--   Ds.Rincones(zona) -> { { x, y }, ... }   Ds.Vuelos(zona) -> { nodo, ... }
--   Ds.Zona() -> uiMapID de tu zona          Ds.Refrescar()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local Geo = M.Geo

local type, ipairs, pairs, pcall, tonumber, format = type, ipairs, pairs, pcall, tonumber, string.format

local Ds = {}
M.Descubrir = Ds

local CAPA_RINCONES, CAPA_VUELOS = "mundo.porDescubrir", "mundo.vuelosFaltan"
Ds.CAPA_RINCONES, Ds.CAPA_VUELOS = CAPA_RINCONES, CAPA_VUELOS
local NIVEL_MAX = 60

local login = false

local function secreto(v) return issecretvalue ~= nil and type(v) ~= "nil" and issecretvalue(v) and true or false end

local function rgb(nombre)
	local T = A.Theme
	if T and type(T.Color) == "function" then
		local ok, r, g, b = pcall(T.Color, nombre)
		if ok and type(r) == "number" then return r, g, b end
	end
	return 1, 1, 1
end
local function color(nombre) local r, g, b = rgb(nombre) return { r, g, b, 1 } end

local function datos()
	local d = N.DatosPersonaje("mundo")
	d.exploracion = type(d.exploracion) == "table" and d.exploracion or {}
	return d
end

-- Tu zona (la de tu mapa continuo; una cueva cuenta como su zona).
function Ds.Zona()
	local u, v = Geo.Jugador()
	if not u then return nil end
	local _, zona = Geo.Cadena(u, v)
	return zona
end

---------------------------------------------------------------------------
-- Rincones por descubrir
---------------------------------------------------------------------------
local function explorado(zona)
	local X = C_MapExplorationInfo
	if not (X and X.GetExploredMapTextures) then return nil end
	local ok, lista = pcall(X.GetExploredMapTextures, zona)
	return ok and type(lista) == "table" and lista or nil
end

-- -> { { x, y }, ... } en 0-100 del mapa de la zona (vacía si no se sabe).
function Ds.Rincones(zona)
	local out = {}
	local ZA = A.UI and A.UI.ZoneArt
	local Maps = A.Maps
	if not (zona and ZA and type(ZA.FullOverlays) == "function" and Maps and type(Maps.UnexploredOverlays) == "function") then return out end
	local info = Geo.Capa(zona)
	if not info then return out end
	local ok, arte = pcall(ZA.FullOverlays, zona, info.tileWidth, info.tileHeight)
	if not (ok and type(arte) == "table") then return out end
	local bien, faltan = pcall(Maps.UnexploredOverlays, arte, explorado(zona))
	if not (bien and type(faltan) == "table") then return out end
	local w, h = info.layerWidth, info.layerHeight
	for _, o in ipairs(faltan) do
		local ow, oh, ox, oy = tonumber(o[1]), tonumber(o[2]), tonumber(o[3]), tonumber(o[4])
		if ow and oh and ox and oy and w > 0 and h > 0 then
			out[#out + 1] = { x = (ox + ow / 2) / w * 100, y = (oy + oh / 2) / h * 100 }
		end
	end
	return out
end

-- 1.3.0: el modo explorador. -> descubiertos, total (nil si el juego no da
-- el arte completo de esa zona). Cada pieza del mapa que el juego te tapa es
-- un rincón: los mismos de «Por descubrir».
function Ds.Progreso(zona)
	local ZA = A.UI and A.UI.ZoneArt
	local Maps = A.Maps
	if not (zona and ZA and type(ZA.FullOverlays) == "function" and Maps and type(Maps.UnexploredOverlays) == "function") then return nil end
	local info = Geo.Capa(zona)
	if not info then return nil end
	local ok, arte = pcall(ZA.FullOverlays, zona, info.tileWidth, info.tileHeight)
	if not (ok and type(arte) == "table") then return nil end
	local total = #arte - 2
	if total <= 0 then return nil end
	local bien, faltan = pcall(Maps.UnexploredOverlays, arte, explorado(zona))
	if not (bien and type(faltan) == "table") then return nil end
	return total - #faltan, total
end

-- 1.3.6: lo ya medido del modo explorador, por continente.
local explorados = {}
function Ds.OlvidarExplorador() explorados = {} end

-- Las zonas de tu continente (o de `cont`) con su avance:
-- { { zona, nombre, hechos, total }, ... } y el resumen { completas, zonas, hechos, total }.
-- Primero tu zona, luego las empezadas (las que menos faltan) y al final las completas.
function Ds.Explorador(cont)
	local lista, resumen = {}, { completas = 0, zonas = 0, hechos = 0, total = 0 }
	local mia = Ds.Zona()
	if not cont and mia then
		local u, v = Geo.Jugador()
		if u then cont = Geo.Cadena(u, v) end
	end
	if not cont then return lista, resumen end
	-- 1.3.6: el avance de cada zona (FullOverlays/UnexploredOverlays) se
	-- calcula una vez por continente y se guarda hasta que descubres algo o
	-- cambias de zona (Ds.OlvidarExplorador); cada refresco solo lo ordena.
	local zonasCont = explorados[cont]
	if not zonasCont then
		local ok, zonas = pcall(Geo.Zonas, cont)
		if not (ok and type(zonas) == "table") then return lista, resumen end
		zonasCont = {}
		for _, z in ipairs(zonas) do
			local id = type(z) == "table" and (z.mapID or z.id) or z
			local hechos, total = Ds.Progreso(id)
			if hechos then zonasCont[#zonasCont + 1] = { id = id, nombre = Geo.Nombre(id) or "?", hechos = hechos, total = total } end
		end
		explorados[cont] = zonasCont
	end
	for _, z in ipairs(zonasCont) do
		local id, hechos, total = z.id, z.hechos, z.total
		do
			lista[#lista + 1] = { zona = id, nombre = z.nombre, hechos = hechos, total = total, mia = id == mia }
			resumen.zonas = resumen.zonas + 1
			resumen.hechos, resumen.total = resumen.hechos + hechos, resumen.total + total
			if hechos >= total then resumen.completas = resumen.completas + 1 end
		end
	end
	table.sort(lista, function(a, b)
		if a.mia ~= b.mia then return a.mia end
		local fa, fb = a.hechos >= a.total, b.hechos >= b.total
		if fa ~= fb then return fb end
		local ea, eb = a.hechos > 0, b.hechos > 0
		if ea ~= eb then return ea end
		if (a.total - a.hechos) ~= (b.total - b.hechos) then return (a.total - a.hechos) < (b.total - b.hechos) end
		return a.nombre < b.nombre
	end)
	return lista, resumen
end

local function nivel()
	local n = Geo.NivelJugador()
	if n then return n end
	n = UnitLevel and UnitLevel("player")
	return not secreto(n) and tonumber(n) or 1
end

local function tipRincon(zona)
	local nombre = Geo.Nombre(zona) or L["tu zona"]
	return function(tip)
		tip:SetText(L["Por descubrir"], rgb("text"))
		tip:AddLine(format(L["Un rincón de %s que todavía no pisas."], nombre), rgb("textDim"))
		if zona and nivel() < NIVEL_MAX then
			local xp = tonumber(datos().exploracion[zona])
			if xp then
				tip:AddLine(format(L["Descubrir aquí te dio %d de experiencia la última vez."], xp), rgb("quest"))
			else
				tip:AddLine(L["Descubrirlo te da experiencia."], rgb("quest"))
			end
		end
		tip:AddLine(L["En el mapa de Alfa, clic: seguirla con la flecha o guardarla como marcador."], rgb("textDim"))
	end
end

local function pinesRincones(zona)
	local lista = {}
	local col = color("accent")
	local tip = tipRincon(zona)
	for _, r in ipairs(Ds.Rincones(zona)) do
		lista[#lista + 1] = { map = zona, x = r.x, y = r.y, icon = "map:explore", size = 13, color = col, priority = 1,
			label = L["Por descubrir"], tooltip = tip }
	end
	return lista
end

-- El mensaje del juego al descubrir: cuánta experiencia dio (por zona).
local patron
local function patronXP()
	if patron ~= nil then return patron end
	patron = false
	local g = rawget(_G, "ERR_ZONE_EXPLORED_XP")
	if type(g) == "string" and g:find("%%s") and g:find("%%d") then
		local p = g:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
		p = p:gsub("%%s", ".-"):gsub("%%d", "(%%d+)")
		patron = "^" .. p
	end
	return patron
end

function Ds.AlMensaje(texto)
	if type(texto) ~= "string" or secreto(texto) then return false end
	local p = patronXP()
	if not p then return false end
	local xp = tonumber(texto:match(p))
	if not xp then return false end
	local zona = Ds.Zona()
	if zona then datos().exploracion[zona] = xp end
	return true
end

---------------------------------------------------------------------------
-- Vuelos que te faltan en tu zona
---------------------------------------------------------------------------
local nodos = {}

function Ds.Vuelos(zona)
	local out = {}
	local Nv, C = A.Nav, A.Compat
	if not (zona and Nv and type(Nv.UnknownTaxiOn) == "function" and C and type(C.GetPlayerWorldPosition) == "function") then return out end
	local ok, c = pcall(C.GetPlayerWorldPosition)
	if not (ok and tonumber(c)) then return out end
	local bien = pcall(Nv.UnknownTaxiOn, c, nodos)
	if not bien then return out end
	for _, nodo in ipairs(nodos) do
		if type(nodo) == "table" and nodo.c == c then
			local u, v = Geo.DeYardas(nodo.c, nodo.wx, nodo.wy)
			if u then
				local _, z = Geo.Cadena(u, v)
				if z == zona then
					local x, y = Geo.AMapa(zona, u, v)
					if x then out[#out + 1] = { nodo = nodo, x = x, y = y } end
				end
			end
		end
	end
	return out
end

local function nombreVuelo(nodo)
	local T = A.Nav and A.Nav.travel
	if T and type(T.TaxiName) == "function" then
		local ok, n = pcall(T.TaxiName, nodo)
		if ok and type(n) == "string" and n ~= "" then return n end
	end
	return nodo.name or L["Maestro de vuelo"]
end

local function pinesVuelos(zona)
	local lista = {}
	local col = color("warning")
	for _, e in ipairs(Ds.Vuelos(zona)) do
		local nombre = nombreVuelo(e.nodo)
		local x, y = e.x, e.y
		lista[#lista + 1] = {
			map = zona, x = x, y = y, icon = "map:flightmaster", size = 16, color = col, ring = col, badge = "!",
			priority = 3, label = nombre, nodeID = e.nodo.id,
			tooltip = function(tip)
				tip:SetText(nombre, rgb("text"))
				tip:AddLine(L["Te falta este vuelo: háblale al maestro de vuelo para aprenderlo."], rgb("warning"))
				tip:AddLine(L["Clic: la flecha te lleva."], rgb("textDim"))
			end,
			onClick = function(boton)
				if boton ~= "LeftButton" then return end
				local Mk = M.Marcadores
				if Mk and Mk.SeguirPunto then Mk.SeguirPunto(zona, x, y, nombre) end
			end,
		}
	end
	return lista
end

---------------------------------------------------------------------------
-- Publicar
---------------------------------------------------------------------------
local function poner(Pins, capa, lista)
	if lista and #lista > 0 then
		Pins.SetLayer(capa, lista, { world = true, minimap = false, edge = false })
	else
		Pins.ClearLayer(capa)
	end
end

function Ds.Refrescar()
	local Pins = A.Pins
	if not (login and Pins and type(Pins.SetLayer) == "function") then return end
	local zona = Ds.Zona()
	poner(Pins, CAPA_RINCONES, zona and A.Get(CAPA_RINCONES) ~= false and pinesRincones(zona) or nil)
	poner(Pins, CAPA_VUELOS, zona and A.Get(CAPA_VUELOS) ~= false and pinesVuelos(zona) or nil)
end

local pendiente = false
local function pronto(espera)
	if pendiente then return end
	pendiente = true
	A.After(espera or 1, function()
		pendiente = false
		local ok, e = pcall(Ds.Refrescar)
		if not ok and geterrorhandler then geterrorhandler()(e) end
	end)
end
Ds.Pronto = pronto

if type(A.OnLogin) == "function" then
	A.OnLogin(function()
		login = true
		A.After(6, Ds.Refrescar)
		-- Lya lo enseña en «¿En qué te ayudo?».
		local Lya = rawget(_G, "AlfaLya")
		if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
			pcall(Lya.Ensenar, { id = "mundo.descubrir", icono = "ic-mundo", modulo = "mundo",
				pregunta = L["¿Qué me falta por explorar en esta zona?"],
				respuesta = L["En el mapa de Alfa, la capa «Por descubrir» marca los rincones de tu zona que no has pisado, y «Vuelos que te faltan» los maestros de vuelo que aún no conoces. Clic en un vuelo y la flecha te lleva."] })
		end
	end)
end

for _, ev in ipairs({ "ZONE_CHANGED_NEW_AREA", "MAP_EXPLORATION_UPDATED", "TAXIMAP_OPENED", "TAXI_NODE_STATUS_CHANGED", "PLAYER_LEVEL_UP" }) do
	A.RegisterEvent(ev, function()
		-- 1.3.6: descubrir algo o cambiar de zona vuelve a medir el modo explorador.
		if ev == "ZONE_CHANGED_NEW_AREA" or ev == "MAP_EXPLORATION_UPDATED" then Ds.OlvidarExplorador() end
		if login then pronto(1) end
	end)
end
-- 1.3.6: un descubrimiento también olvida lo medido del modo explorador.
A.RegisterEvent("CHAT_MSG_SYSTEM", function(_, texto) if Ds.AlMensaje(texto) then Ds.OlvidarExplorador() pronto(1) end end)
A.RegisterEvent("UI_INFO_MESSAGE", function(_, _, texto) if Ds.AlMensaje(texto) then Ds.OlvidarExplorador() pronto(1) end end)

A.On("SETTING_CHANGED", function(path)
	if path == "" or path == "mundo" or path == CAPA_RINCONES or path == CAPA_VUELOS then pronto(0) end
end)

local T = A.Theme
if T and type(T.OnChanged) == "function" then T.OnChanged(function() pronto(0) end) end
