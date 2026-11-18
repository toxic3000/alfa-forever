-- Alfa - Comodidades: la siguiente parada del vuelo. GPL-3.0.
--
-- El motor ya muestra, mientras vuelas, el destino, el tiempo que falta y la
-- barra de progreso (Maps/FlightTimer.lua, ajuste maps.flightTimer). Lo que
-- le falta es la parada intermedia: en un vuelo con escalas, una línea bajo
-- su recuadro dice cuál es la siguiente y cuánto falta para llegar a ella.
--
-- Al elegir el destino (TakeTaxiNode, enganchado con hooksecurefunc, nunca
-- reemplazado) se leen los tramos de la ruta con GetNumRoutes y
-- TaxiGetNodeSlot, como hace el motor para dibujarla (QoL/Flight.lua), y
-- sus nombres con TaxiNodeName. En el aire, la parada siguiente es el final
-- del tramo más cercano a tu posición (Alfa.Compat.GetPlayerWorldPosition y
-- las posiciones de los maestros de vuelo del motor, Alfa.Nav.GetTaxiNode),
-- sin volver nunca atrás. Sin posiciones se muestran las escalas en orden.
-- El tiempo es una estimación ("~") a la velocidad del grifo que usa el motor.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local W, T = A.Widgets, A.Theme

local legible = M.Legible
local sqrt, max, min, floor = math.sqrt, math.max, math.min, math.floor

local VELOCIDAD = 30 -- yardas por segundo, la del motor (Maps/FlightTimer.lua)
local PAUSA = 2      -- segundos por escala: despegar y aterrizar
local TICK = 0.5
local VIGENCIA = 3600 -- un viaje guardado vale una hora (un /reload en el aire)

local viaje   -- { origen = nodo, paradas = { nodo, ... }, tramo = n, t = time() }
local marco, ticker

local function activo()
	return M.Get("vueloParada") and A.Get("maps.flightTimer") and true or false
end

---------------------------------------------------------------------------
-- La ruta elegida en el mapa de vuelo
---------------------------------------------------------------------------

local function corto(nombre)
	if type(nombre) ~= "string" or nombre == "" then return nil end
	return nombre:match("^([^,]+),") or nombre
end

local function nodo(slot)
	slot = legible(slot)
	if not slot then return nil end
	local id, nombre
	local C = A.Maps and A.Maps.Client
	if C and C.TaxiSlot then
		local ok, i, n = pcall(C.TaxiSlot, slot)
		if ok then id, nombre = legible(i), legible(n) end
	end
	if TaxiNodeName then
		local propio = legible(TaxiNodeName(slot))
		if type(propio) == "string" and propio ~= "" then nombre = propio end
	end
	local n = { id = id, nombre = corto(nombre) }
	local Nav = A.Nav
	local t = id and Nav and Nav.GetTaxiNode and Nav.GetTaxiNode(id)
	if type(t) == "table" then n.c, n.wx, n.wy = t.c, t.wx, t.wy end
	return n
end

local function guardar()
	local d = N.DatosPersonaje(M.ID)
	d.viaje = viaje
end

local function alTomar(slot)
	if not activo() then return end
	viaje = nil
	if not (GetNumRoutes and TaxiGetNodeSlot) then return guardar() end
	local tramos = tonumber(legible(GetNumRoutes(slot))) or 0
	if tramos < 2 then return guardar() end -- sin escalas: el motor ya muestra el destino
	local v = { origen = nodo(TaxiGetNodeSlot(slot, 1, true)), paradas = {}, tramo = 1, t = time and time() or 0 }
	for i = 1, tramos do
		local p = nodo(TaxiGetNodeSlot(slot, i, false))
		if not (p and p.nombre) then return guardar() end
		v.paradas[i] = p
	end
	viaje = v
	guardar()
end

if TakeTaxiNode and hooksecurefunc then
	hooksecurefunc("TakeTaxiNode", function(slot) M.Seguro(alTomar, slot) end)
end

---------------------------------------------------------------------------
-- En el aire
---------------------------------------------------------------------------

local function conPosicion(n)
	return n and n.c and n.wx and n.wy
end

local function distancia(a, b)
	local dx, dy = a.wx - b.wx, a.wy - b.wy
	return sqrt(dx * dx + dy * dy)
end

-- Yardas del tramo a -> b en los datos de vuelo del motor, si las tiene.
local function yardasTramo(a, b)
	local Nav = A.Nav
	local d = Nav and Nav.GetTravelData and Nav.GetTravelData()
	local lista = d and d.flights and a.id and d.flights[a.id]
	if type(lista) == "table" then
		for i = 1, #lista - 1, 2 do
			if lista[i] == b.id and type(lista[i + 1]) == "number" then return lista[i + 1] end
		end
	end
	return distancia(a, b) * 1.15
end

-- El tramo en el que vas (1..#paradas) y cuánto llevas de él (0..1).
local function dondeVoy(v, yo)
	local mejor, fraccion, menor = v.tramo, 0, math.huge
	for k = v.tramo, #v.paradas do
		local a = k == 1 and v.origen or v.paradas[k - 1]
		local b = v.paradas[k]
		if not (conPosicion(a) and conPosicion(b)) or a.c ~= yo.c or b.c ~= yo.c then return nil end
		local ax, ay = b.wx - a.wx, b.wy - a.wy
		local largo = ax * ax + ay * ay
		local t = 0
		if largo > 0 then t = max(0, min(1, ((yo.wx - a.wx) * ax + (yo.wy - a.wy) * ay) / largo)) end
		local px, py = a.wx + ax * t, a.wy + ay * t
		local dx, dy = yo.wx - px, yo.wy - py
		local dist = dx * dx + dy * dy
		if dist < menor then mejor, fraccion, menor = k, t, dist end
	end
	return mejor, fraccion
end

local function miPosicion()
	local C = A.Compat
	if not (C and C.GetPlayerWorldPosition) then return nil end
	local ok, c, wx, wy = pcall(C.GetPlayerWorldPosition)
	if not (ok and c and wx and wy) then return nil end
	return { c = c, wx = wx, wy = wy }
end

local function enElAire()
	local C = A.Compat
	return C and C.IsOnTaxi and C.IsOnTaxi() or false
end

local function lugar(nombre)
	return "|c" .. T.Hex("place") .. nombre .. "|r"
end

local function mostrar(texto, tiempo)
	if not marco then return end
	marco.Texto:SetText(texto)
	marco.Tiempo:SetText(tiempo or "")
	marco:Show()
end

local function ocultar()
	if marco then marco:Hide() end
end

local function actualizar()
	local v = viaje
	if not (v and activo() and enElAire()) then return ocultar() end
	local yo = miPosicion()
	local k, fraccion
	if yo then k, fraccion = dondeVoy(v, yo) end
	if not k then
		-- Sin posiciones: las escalas en orden, sin el destino final.
		local nombres = {}
		for i = 1, #v.paradas - 1 do nombres[i] = lugar(v.paradas[i].nombre) end
		return mostrar(L["Escalas:"] .. " " .. table.concat(nombres, "  ›  "))
	end
	v.tramo = k
	if k >= #v.paradas then return ocultar() end -- el siguiente es el destino: ya lo muestra el motor
	local a = k == 1 and v.origen or v.paradas[k - 1]
	local b = v.paradas[k]
	local falta = (yardasTramo(a, b) / VELOCIDAD + PAUSA) * (1 - (fraccion or 0))
	mostrar(L["Siguiente parada:"] .. " " .. lugar(b.nombre), "~" .. N.Duracion(falta))
end

---------------------------------------------------------------------------
-- La línea bajo el recuadro del motor
---------------------------------------------------------------------------

local function construir(base)
	marco = CreateFrame("Frame", "AlfaComodidadesParada", base)
	marco:SetHeight(24)
	marco:SetPoint("TOPLEFT", base, "BOTTOMLEFT", 0, -3)
	marco:SetPoint("TOPRIGHT", base, "BOTTOMRIGHT", 0, -3)
	marco.psLight = true
	T.Skin(marco, "window")
	local punto = W.Tex(marco, "ARTWORK", "chevron-right", "accent")
	punto:SetSize(12, 12)
	punto:SetPoint("LEFT", marco, "LEFT", 12, 0)
	marco.Tiempo = W.Text(marco, "number", "textDim")
	marco.Tiempo:SetPoint("RIGHT", marco, "RIGHT", -10, 0)
	marco.Tiempo:SetJustifyH("RIGHT")
	marco.Texto = W.Text(marco, "small", "textDim")
	marco.Texto:SetPoint("LEFT", punto, "RIGHT", 6, 0)
	marco.Texto:SetPoint("RIGHT", marco.Tiempo, "LEFT", -8, 0)
	marco:Hide()
end

local function arrancar()
	if ticker then return end
	actualizar()
	ticker = A.NewTicker(TICK, actualizar)
end

local function parar()
	if ticker then ticker:Cancel() end
	ticker = nil
	ocultar()
	if not enElAire() then
		viaje = nil
		guardar()
	end
end

A.OnLogin(function()
	-- Un /reload en el aire: el viaje guardado sigue si es reciente.
	local d = N.DatosPersonaje(M.ID)
	local v = d.viaje
	local ahora = time and time() or 0
	-- Un viaje guardado viejo o dañado se descarta entero (1.2.0): el tramo es
	-- un número y cada parada una tabla con su nombre.
	local sano = type(v) == "table" and type(v.paradas) == "table" and type(v.tramo) == "number"
	if sano then
		for _, p in ipairs(v.paradas) do
			if type(p) ~= "table" or type(p.nombre) ~= "string" then sano = false break end
		end
	end
	if sano and enElAire() and ahora - (tonumber(v.t) or 0) < VIGENCIA then
		viaje = v
	else
		d.viaje = nil
	end
	-- La barra de vuelo del motor (Maps.GetFlightFrame la crea si aún no existe,
	-- así no depende del orden en que el juego corre los OnLogin; 1.1.6).
	local Maps = A.Maps
	local base = Maps and Maps.GetFlightFrame and Maps.GetFlightFrame() or _G.AlfaFlightTimer
	if not (base and base.HookScript) then return end
	construir(base)
	base:HookScript("OnShow", function() M.Seguro(arrancar) end)
	base:HookScript("OnHide", function() M.Seguro(parar) end)
	if base:IsShown() then arrancar() end
end)

M.AlCambiar({ "vueloParada" }, function()
	if not activo() then ocultar() elseif ticker then actualizar() end
end)

-- Para pruebas.
M.Vuelo = { AlTomar = alTomar, DondeVoy = dondeVoy, Actualizar = actualizar }
