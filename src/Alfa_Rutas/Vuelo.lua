-- Alfa - Rutas: vuelo listo (toxic3000 / La Jauría). GPL-3.0.
-- 1.2.9
--
-- Con el mapa de vuelos abierto (TAXIMAP_OPENED), si la ruta del motor no
-- marcó ya un vuelo (QoL.Flight.node: el vuelo de la ruta o el del paso), Alfa
-- marca el destino al que puedes volar que queda más cerca de tu paso de
-- ahora (la flecha), con una huella que late y «Más cerca de tu paso». Solo
-- si volar ahí te deja bastante más cerca que donde estás. Solo se mira:
-- nada toma el ratón ni vuela por ti. Ajuste rutas.vueloListo.
--
--   Vuelo.Mejor() -> { slot, nombre, yardas } | nil, motivo
--   Vuelo.Marcar() -> slot | nil, motivo     marca el destino en el mapa abierto
--   Vuelo.Quitar()

local ADDON, M = ...
local A, L, K = M.A, M.L, M.K
local Vu = {}
M.Vuelo = Vu

A.RegisterDefaults(M.ID, { vueloListo = true })

local type, ipairs, tonumber, pcall = type, ipairs, tonumber, pcall
local sqrt = math.sqrt

local MIN_YARDAS = 400  -- más cerca que esto de tu paso, a pie
local MEJORA = 0.6      -- el vuelo te deja a menos del 60 % de lo que estás ahora

local function CP() return M.Motor("Compat") end
local function encendido() return A.Get(M.ID .. ".vueloListo") ~= false end

local function mundo(p)
	local Cp = CP()
	if not (p and p.map and p.x and p.y and Cp and Cp.MapToWorld) then return nil end
	local ok, c, wx, wy = pcall(Cp.MapToWorld, p.map, p.x, p.y, p.f)
	if ok and c and type(wx) == "number" and type(wy) == "number" then return c, wx, wy end
	return nil
end

local function objetivo()
	local Nav = A.Nav
	local t = Nav and Nav.GetTarget and Nav.GetTarget()
	if not t then
		local E = A.Engine
		t = E and E.GetWaypoint and E.GetWaypoint()
	end
	return type(t) == "table" and t or nil
end

-- slot -> nodeID del vuelo (C_TaxiMap), si el cliente lo dice.
local function idsDeVuelo()
	local out = {}
	local mapa = GetTaxiMapID and select(2, pcall(GetTaxiMapID))
	local C = C_TaxiMap
	if mapa and C and type(C.GetAllTaxiNodes) == "function" then
		local ok, lista = pcall(C.GetAllTaxiNodes, mapa)
		for _, info in ipairs(ok and type(lista) == "table" and lista or {}) do
			if type(info) == "table" and info.slotIndex and info.nodeID then out[info.slotIndex] = info.nodeID end
		end
	end
	return out
end

local function nodoDe(slot, ids)
	local Nav, Mp = A.Nav, A.Maps
	local id = ids[slot]
	if not id and Mp and type(Mp.TaxiNodeByName) == "function" and TaxiNodeName then
		local ok, nombre = pcall(TaxiNodeName, slot)
		if ok and type(nombre) == "string" and nombre ~= "" then id = Mp.TaxiNodeByName(nombre) end
	end
	local n = id and Nav and Nav.GetTaxiNode and Nav.GetTaxiNode(id)
	if type(n) == "table" and n.c and n.wx and n.wy then return n end
	return nil
end

local function nombreCorto(slot)
	local ok, nombre = pcall(TaxiNodeName, slot)
	nombre = ok and type(nombre) == "string" and nombre or ""
	return nombre:match("^([^,]+),") or nombre
end

function Vu.Mejor()
	if not encendido() then return nil, "apagado" end
	if not (NumTaxiNodes and TaxiNodeGetType and TaxiNodeName) then return nil, "sinMapa" end
	local tc, twx, twy = mundo(objetivo())
	if not tc then return nil, "sinPaso" end
	local yc, ywx, ywy = mundo(A.PlayerPoint and A.PlayerPoint())
	local apie
	if yc == tc then
		local dx, dy = ywx - twx, ywy - twy
		apie = sqrt(dx * dx + dy * dy)
		if apie < MIN_YARDAS then return nil, "cerca" end
	end
	local ids = idsDeVuelo()
	local mejor, yardas
	local ok, n = pcall(NumTaxiNodes)
	for slot = 1, ok and tonumber(n) or 0 do
		if TaxiNodeGetType(slot) == "REACHABLE" then
			local nodo = nodoDe(slot, ids)
			if nodo and nodo.c == tc then
				local dx, dy = nodo.wx - twx, nodo.wy - twy
				local d = sqrt(dx * dx + dy * dy)
				if not yardas or d < yardas then mejor, yardas = slot, d end
			end
		end
	end
	if not mejor then return nil, "sinVuelo" end
	if apie and yardas > apie * MEJORA then return nil, "noConviene" end
	return { slot = mejor, nombre = nombreCorto(mejor), yardas = math.floor(yardas + 0.5) }
end

---------------------------------------------------------------------------
-- La marca en el mapa de vuelos (solo se ve: no toma el ratón)
---------------------------------------------------------------------------

local marca

local function armar()
	if marca then return marca end
	local m = CreateFrame("Frame", nil, UIParent)
	m:SetSize(34, 34)
	m:EnableMouse(false)
	m.Halo = m:CreateTexture(nil, "BACKGROUND")
	m.Halo:SetTexture(K.Ruta("ic-huella"))
	m.Halo:SetPoint("CENTER")
	m.Halo:SetSize(30, 30)
	m.Halo:SetBlendMode("ADD")
	m.Huella = K.Icono(m, "ic-huella", 18, "acento", "OVERLAY")
	m.Huella:SetPoint("BOTTOM", m, "CENTER", 0, 10)
	m.Texto = K.Texto(m, "pequeno", "acento")
	m.Texto:SetPoint("BOTTOM", m.Huella, "TOP", 0, 2)
	m.Texto:SetJustifyH("CENTER")
	local ag = m.Huella:CreateAnimationGroup()
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.45)
	a:SetDuration(0.9)
	a:SetSmoothing("IN_OUT")
	ag:SetLooping("BOUNCE")
	m.Late = ag
	m:Hide()
	marca = m
	Vu.marca = m
	return m
end

local function botonDe(slot)
	if TaxiFrame and TaxiFrame.IsShown and TaxiFrame:IsShown() then
		local b = _G["TaxiButton" .. slot]
		if b and b:IsShown() then return b end
	end
	local fm = rawget(_G, "FlightMapFrame")
	if fm and fm.IsShown and fm:IsShown() and fm.EnumeratePinsByTemplate then
		for pin in fm:EnumeratePinsByTemplate("FlightMap_FlightPointPinTemplate") do
			if pin.taxiNodeData and pin.taxiNodeData.slotIndex == slot then return pin end
		end
	end
	return nil
end

function Vu.Quitar()
	if marca then
		marca.Late:Stop()
		marca:Hide()
		marca:SetParent(UIParent)
	end
	Vu.marcado = nil
end

function Vu.Marcar()
	Vu.Quitar()
	local Fl = A.QoL and A.QoL.Flight
	if Fl and Fl.node then return nil, "motor" end -- la ruta ya marcó su vuelo
	local d, motivo = Vu.Mejor()
	if not d then return nil, motivo end
	local b = botonDe(d.slot)
	if not b then return nil, "sinBoton" end
	local m = armar()
	m:SetParent(b)
	m:ClearAllPoints()
	m:SetPoint("CENTER", b, "CENTER", 0, 0)
	m:SetFrameLevel((b:GetFrameLevel() or 1) + 4)
	m.Halo:SetVertexColor(K.ConAlfa("acento", 0.35))
	K.Escribir(m.Texto, L["Más cerca de tu paso"])
	m:Show()
	m.Late:Play()
	Vu.marcado = d.slot
	return d.slot
end

A.RegisterEvent("TAXIMAP_OPENED", function()
	-- Después del motor (marca su vuelo en el mismo evento, con After 0).
	A.After(0.1, function() pcall(Vu.Marcar) end)
end)
A.RegisterEvent("TAXIMAP_CLOSED", function() Vu.Quitar() end)
