-- Alfa - Mundo: «Aquí cerca hay un vuelo que no conoces» (toxic3000 /
-- La Jauría). GPL-3.0. 1.4.0 (diario, 99)
--
-- Pasar junto a un maestro de vuelo sin hablarle es la queja de siempre:
-- luego toca volver a pie. La capa «Vuelos que te faltan» (Descubrir.lua) los
-- marca en el mapa, pero hay que abrirlo. Ahora, cuando pasas a menos de
-- CERCA yardas de uno que no conoces, un aviso chico: «A 120 yd hay un maestro
-- de vuelo que no conoces: Puesto del Cruce», con «Llévame» (la flecha).
-- Una vez por vuelo y sesión; nunca en combate, en instancias, en un vuelo
-- ni muerto. Una cuenta cada CADA segundos con los datos de Descubrir.lua
-- (unas decenas de vuelos a lo mucho). Ajuste mundo.vueloCerca (sí).
--
--   Vc.Cercano() -> { nodo, x, y, zona, yardas, nombre } | nil
--   Vc.Revisar() -> aviso | nil

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)

local type, ipairs, pcall, tonumber, format, sqrt, floor = type, ipairs, pcall, tonumber, string.format, math.sqrt, math.floor

local Vc = {}
M.VueloCerca = Vc

local CERCA = 250 -- yd
local CADA = 5    -- s
Vc.CERCA = CERCA

local function encendido() return N.Get("mundo", "vueloCerca") ~= false end
local function num(v) return N.LeerNumero and N.LeerNumero(v) or tonumber(N.Leer(v)) end

local function ocupado()
	if InCombatLockdown and InCombatLockdown() then return true end
	if N.SiJuego(rawget(_G, "UnitOnTaxi"), "player") then return true end
	if N.SiJuego(rawget(_G, "UnitIsDeadOrGhost"), "player") then return true end
	if N.SiJuego(rawget(_G, "IsInInstance")) then return true end
	return false
end

local function nombreVuelo(nodo)
	local T = A.Nav and A.Nav.travel
	if T and type(T.TaxiName) == "function" then
		local ok, n = pcall(T.TaxiName, nodo, true)
		if ok and type(n) == "string" and n ~= "" and not N.Secreto(n) then return n end
	end
	return type(nodo) == "table" and type(nodo.name) == "string" and nodo.name or L["Maestro de vuelo"]
end

function Vc.Cercano()
	local Ds, C = M.Descubrir, A.Compat
	if not (Ds and Ds.Vuelos and Ds.Zona and C and type(C.GetPlayerWorldPosition) == "function") then return nil end
	local zona = Ds.Zona()
	if not zona then return nil end
	local ok, c, wx, wy = pcall(C.GetPlayerWorldPosition)
	c, wx, wy = ok and num(c), ok and num(wx), ok and num(wy)
	if not (c and wx and wy) then return nil end
	local mejor
	for _, e in ipairs(Ds.Vuelos(zona)) do
		local n = e.nodo
		if type(n) == "table" and n.c == c and type(n.wx) == "number" and type(n.wy) == "number" then
			local dx, dy = n.wx - wx, n.wy - wy
			local d = sqrt(dx * dx + dy * dy)
			if not mejor or d < mejor.yardas then
				mejor = { nodo = n, x = e.x, y = e.y, zona = zona, yardas = d }
			end
		end
	end
	if mejor then mejor.nombre = nombreVuelo(mejor.nodo) end
	return mejor
end

local avisados = {} -- id del vuelo -> true

function Vc.Revisar()
	if not encendido() or ocupado() or not (K and K.Aviso) then return nil end
	local e = Vc.Cercano()
	if not e or e.yardas > CERCA then return nil end
	local id = e.nodo.id or e.nombre
	if avisados[id] then return nil end
	avisados[id] = true
	local yd = floor(e.yardas / 10 + 0.5) * 10
	local acciones
	local Mk = M.Marcadores
	if Mk and Mk.SeguirPunto then
		acciones = { { texto = L["Llévame"], alClic = function() Mk.SeguirPunto(e.zona, e.x, e.y, e.nombre) end } }
	end
	return K.Aviso({
		id = "mundo.vueloCerca", titulo = L["Un vuelo que no conoces"],
		texto = format(L["A %d yd está %s. Háblale al maestro de vuelo para aprender el vuelo: luego te ahorra el camino."], yd, e.nombre),
		icono = "ic-flecha", tono = "acento", duracion = 12, prioridad = "util", caduca = 60, acciones = acciones,
	})
end

-- Para el banco.
function Vc.Olvidar() avisados = {} end

A.OnLogin(function()
	N.Cada("mundo.vueloCerca", CADA, function() if encendido() then Vc.Revisar() end end)
end)
