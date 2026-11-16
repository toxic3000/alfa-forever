-- Alfa - Mazmorras: las entradas de mazmorras en el minimapa (Toxic / La Jauría). GPL-3.0.
--
-- El motor ya marca las entradas en el mapa del mundo (Maps/Dungeons.lua,
-- capa "maps.dungeons", world = true, minimap = false; Alfa_Mundo la ofrece
-- como "Entradas de mazmorras"). Aquí solo se pinta lo que el motor no
-- pinta: las mismas entradas en el minimapa, en verde las que ya hiciste,
-- con un clic que abre su diario en esta página.
--
-- Las posiciones salen de los datos de la cuenta (D.Entradas, guardados la
-- primera vez que se cargó el Codex), así que el minimapa no carga el Codex
-- al iniciar sesión.
--
-- Con Alfa_Mundo, la capa "mazmorras.entradas" vive en su control de capas
-- (AlfaMundo.RegistrarCapa) y su estado manda; sin él, el ajuste
-- mazmorras.capaEntradas.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local T = A.Theme
local L = N.Textos(M.EN)
local D, V = M.D, M.V
local ID = D.ID

local type, pairs, format = type, pairs, string.format

local CAPA = "mazmorras.entradas"
local ICONO = "Interface\\AddOns\\Alfa\\Media\\Map\\icon-dungeon"

local Capa = {}
M.Capa = Capa

local registrada = false

local function mundo()
	local Mu = AlfaMundo
	if type(Mu) == "table" and type(Mu.RegistrarCapa) == "function" then return Mu end
	return nil
end

function Capa.Activa()
	local Mu = mundo()
	if registrada and Mu and type(Mu.CapaActiva) == "function" then
		return D.Llamar(Mu.CapaActiva, CAPA) == true
	end
	return N.Get(ID, "capaEntradas") and true or false
end

local function color(nombre)
	local r, g, b = T.Color(nombre)
	return { r, g, b, 1 }
end

local function tooltip(key, e)
	return function(tip)
		tip:SetText(e.nombre or key, T.Color("text"))
		local lo, hi = e.min, e.max
		if type(lo) == "number" then
			local s = (type(hi) == "number" and hi ~= lo) and format(L["Niveles %s"], lo .. "\226\128\147" .. hi) or format(L["Nivel %d"], lo)
			tip:AddLine(s, T.Color("textDim"))
		end
		local h = D.Hecha(key)
		local v, total = D.Cuenta(key)
		if h then
			tip:AddLine(L["Ya la completaste"], T.Color("success"))
		elseif v > 0 then
			tip:AddLine(format(L["%d de %d jefes"], v, total), T.Color("accent"))
		end
		tip:AddLine(" ")
		tip:AddLine(L["Clic: ver su diario en Alfa"], T.Color("textDim"))
	end
end

local pintando = false
function Capa.Pintar()
	local Pins = A.Pins
	if not (Pins and Pins.SetLayer and Pins.ClearLayer) then return end
	if not Capa.Activa() then
		D.Llamar(Pins.ClearLayer, CAPA)
		return
	end
	local pins = {}
	local normal, hecha = color("dungeon"), color("success")
	for key, e in pairs(D.Entradas()) do
		if type(key) == "string" and type(e) == "table" and type(e.m) == "number" and type(e.x) == "number" and type(e.y) == "number" then
			pins[#pins + 1] = {
				map = e.m, x = e.x, y = e.y, f = e.f,
				icon = e.tipo == "raid" and "map:raid" or "map:dungeon", size = 16, minimapSize = 14, priority = 2,
				color = D.Hecha(key) and hecha or normal,
				tooltip = tooltip(key, e),
				onClick = function(button)
					if button == "LeftButton" and V then V.AbrirMazmorra(key) end
				end,
			}
		end
	end
	if #pins == 0 then
		D.Llamar(Pins.ClearLayer, CAPA)
	else
		D.Llamar(Pins.SetLayer, CAPA, pins, { world = false, minimap = true, edge = false })
	end
end

-- Un solo repintado aunque lleguen varios avisos juntos.
local function pintarPronto()
	if pintando then return end
	pintando = true
	local function ya()
		pintando = false
		Capa.Pintar()
	end
	if A.After then A.After(0.5, ya) else ya() end
end

function Capa.Poner(on)
	on = on ~= false
	local Mu = mundo()
	if registrada and Mu and type(Mu.PonerCapa) == "function" then
		D.Llamar(Mu.PonerCapa, CAPA, on) -- Mundo llama a alCambiar
	else
		N.Set(ID, "capaEntradas", on)
	end
	pintarPronto()
end

local function registrar()
	if registrada then return end
	local Mu = mundo()
	if not Mu then return end
	local id = D.Llamar(Mu.RegistrarCapa, {
		id = CAPA, grupo = L["Mazmorras"], nombre = L["Entradas en el minimapa"], icono = ICONO, color = "dungeon",
		ayuda = L["La entrada de cada mazmorra en el minimapa, en verde las que ya hiciste. El mapa del mundo ya las marca con «Entradas de mazmorras»."],
		activa = true,
		alCambiar = function() pintarPronto() end,
	})
	registrada = id ~= nil
end

registrar()
if A.OnLogin then
	A.OnLogin(function()
		registrar()
		pintarPronto()
	end)
end

D.AlCambiar(function(que)
	if que == "progreso" or que == "codex" or que == "nombres" then pintarPronto() end
end)

A.On("SETTING_CHANGED", function(path)
	if path == ID .. ".capaEntradas" or path == ID or path == "" then pintarPronto() end
end)
