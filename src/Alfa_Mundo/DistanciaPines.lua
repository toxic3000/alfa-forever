-- Alfa - Mundo: a qué distancia está cada pin (1.3.7c). toxic3000 / La
-- Jauría. GPL-3.0.
--
-- El cuadro de cualquier pin de Alfa (el minimapa, el mapa del juego y el
-- mapa de Alfa: misiones, vuelos, servicios, raros, mazmorras, la guía...)
-- termina con una línea que dice dónde queda desde ti: «A 120 yd, al
-- noreste» (en yardas o metros, como la flecha), o «Aquí mismo». En otro
-- continente no dice nada.
--
-- Cómo: Alfa.Pins.SetLayer se envuelve una vez; cada pin con cuadro guarda su
-- cuadro de antes y recibe uno que lo pinta igual y agrega la línea al final
-- (se calcula al pasar el ratón: nada de trabajo mientras no lo miras). Las
-- capas de La Jauría ya dicen la distancia en su cuadro: se dejan como están.
-- Ajuste: mundo.distanciaPines (de fábrica, prendido).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

local type, pairs, ipairs, pcall, tonumber, tostring = type, pairs, ipairs, pcall, tonumber, tostring
local sqrt, atan2, floor, pi, format = math.sqrt, math.atan2, math.floor, math.pi, string.format

local DP = {}
M.DistanciaPines = DP

local AQUI = 12 -- yardas: más cerca, «Aquí mismo»
-- Capas que ya traen su distancia (Alfa_Manada/Mapa.lua).
local SIN_LINEA = { ["manada.grupo"] = true, ["manada.jauria"] = true }
DP.SIN_LINEA = SIN_LINEA

local RUMBOS = { L["al norte"], L["al noroeste"], L["al oeste"], L["al suroeste"],
	L["al sur"], L["al sureste"], L["al este"], L["al noreste"] }

local function prendido() return A.Get("mundo.distanciaPines") ~= false end

local function numero(v)
	if N.Secreto(v) then return nil end
	return type(v) == "number" and v or nil
end

-- Tu posición en yardas: c, norte, oeste (nil si no se sabe o es secreta).
local function yo()
	local C = A.Compat
	if not (C and type(C.GetPlayerWorldPosition) == "function") then return nil end
	local ok, c, x, y = pcall(C.GetPlayerWorldPosition)
	if not ok then return nil end
	c, x, y = numero(c), numero(x), numero(y)
	if not (c and x and y) then return nil end
	return c, x, y
end

-- Dónde está el pin en yardas: c, norte, oeste.
local function dondePin(p)
	local c, wx, wy = tonumber(p.c), tonumber(p.wx), tonumber(p.wy)
	if c and wx and wy then return c, wx, wy end
	local C = A.Compat
	if not (C and type(C.MapToWorld) == "function" and p.map and p.x and p.y) then return nil end
	local ok, c2, x2, y2 = pcall(C.MapToWorld, p.map, p.x, p.y, p.f)
	if not ok then return nil end
	return tonumber(c2), tonumber(x2), tonumber(y2)
end

local function texto(yardas)
	local Fmt = A.FormatDistance
	if type(Fmt) == "function" then
		local ok, s = pcall(Fmt, yardas)
		if ok and type(s) == "string" then return s end
	end
	return floor(yardas + 0.5) .. " yd"
end

-- La línea de un pin: «A 120 yd, al noreste» | «Aquí mismo» | nil.
function DP.Linea(p)
	if type(p) ~= "table" then return nil end
	local c, x, y = yo()
	if not c then return nil end
	local pc, px, py = dondePin(p)
	if not (pc and px and py) or pc ~= c then return nil end
	local dn, dw = px - x, py - y
	local d = sqrt(dn * dn + dw * dw)
	if d < AQUI then return L["Aquí mismo"] end
	local grados = atan2(dw, dn) * 180 / pi -- 0 norte, 90 oeste
	local r = RUMBOS[floor(((grados + 22.5) % 360) / 45) + 1]
	return format(L["A %s, %s"], texto(d), r)
end

-- El cuadro de antes y, al final, la línea (gris claro, como las notas del juego).
local function envolver(p)
	local antes = p.tooltip
	if antes == nil or antes == p.alfaTipDP then return end
	local nuevo
	nuevo = function(tt)
		if type(antes) == "function" then antes(tt) else tt:SetText(tostring(antes)) end
		if not prendido() then return end
		local ok, linea = pcall(DP.Linea, p)
		if ok and linea and type(tt.AddLine) == "function" then tt:AddLine(linea, 0.75, 0.78, 0.82) end
	end
	-- El texto de antes se guarda: «Seguir» y «Guardar como marcador»
	-- (Marcadores.lua, nombreDePin) sacan de ahí el nombre del pin.
	p.alfaTipTexto = type(antes) == "string" and antes or nil
	p.alfaTipDP = nuevo
	p.tooltip = nuevo
end
DP.Envolver = envolver

local function envolverCapa(nombre, pins)
	if SIN_LINEA[nombre] or type(pins) ~= "table" then return end
	for _, p in pairs(pins) do
		if type(p) == "table" and p.tooltip ~= nil then envolver(p) end
	end
end

local Pins = A.Pins
if type(Pins) == "table" and type(Pins.SetLayer) == "function" and not Pins.alfaDistancia then
	Pins.alfaDistancia = true
	local original = Pins.SetLayer
	Pins.SetLayer = function(nombre, pins, opts, ...)
		-- Un error aquí nunca debe impedir que la capa se pinte.
		pcall(envolverCapa, nombre, pins)
		return original(nombre, pins, opts, ...)
	end
	DP.Original = original
end

-- Las capas que se publicaron antes de que Mundo cargara (las vuelve a mirar
-- al entrar; las nuevas pasan por SetLayer).
function DP.Repasar(nombres)
	local P = A.Pins
	if not (P and type(P.GetLayer) == "function") then return end
	for _, n in ipairs(nombres) do
		local ok, pins = pcall(P.GetLayer, n)
		if ok then pcall(envolverCapa, n, pins) end
	end
end

local CONOCIDAS = { "maps.services", "quests.available", "quests.objectives", "quests.turnin", "rares.treasure", "rares.rare",
	"maps.inns", "maps.docks", "maps.taxi", "maps.dungeons", "nav.upcoming", "nav.goals", "nav.spots", "qol.death", "nav.target" }
if type(A.OnLogin) == "function" then A.OnLogin(function() DP.Repasar(CONOCIDAS) end) end
