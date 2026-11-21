-- Alfa - Comodidades: el número (ID) en el cuadro de información (1.3.7).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Para reportar un error o buscar algo en una base de datos: el ID del
-- objeto, del hechizo (o efecto), del PNJ o de la misión, en una línea tenue
-- al final del cuadro. Sale con Mayús presionada (comodidades.cuadroID, de
-- fábrica encendido) o siempre (comodidades.cuadroIDSiempre, avanzado,
-- apagado). Al presionar Mayús con un cuadro abierto, se vuelve a armar.
--
-- Las líneas de objetos y unidades van por Alfa.Hooks (ItemLines/UnitLines,
-- el dueño de los ganchos del cuadro); hechizos, efectos y misiones por
-- TooltipDataProcessor.AddTooltipPostCall (tooltipData.id), como hace el
-- motor. Nada con valores secretos ni en cuadros prohibidos (IsForbidden).

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local Id = {}
M.Ids = Id

local type, tonumber, tostring, pcall = type, tonumber, tostring, pcall
local DUENO = ADDON .. ":ids"

local function quiere()
	if not M.Get("cuadroID") then return false end
	return M.Get("cuadroIDSiempre") or M.Shift()
end
Id.Quiere = quiere

local function numero(v)
	v = M.Legible(v)
	v = type(v) == "number" and v or tonumber(v)
	return v and v > 0 and v or nil
end

function Id.Linea(tooltip, etiqueta, id)
	id = numero(id)
	if not (id and tooltip) or not quiere() then return false end
	if tooltip.IsForbidden and tooltip:IsForbidden() then return false end
	local H = A.Hooks
	if H and H.AddLine then
		H.AddLine(tooltip, etiqueta, tostring(id), 0.54, 0.6, 0.55, 0.85, 0.9, 0.85)
	elseif tooltip.AddDoubleLine then
		tooltip:AddDoubleLine(etiqueta, tostring(id), 0.54, 0.6, 0.55, 0.85, 0.9, 0.85)
	end
	return true
end

-- "Creature-0-4372-0-17-2843-0000123456" -> 2843 (también Vehicle y Pet de PNJ)
function Id.DePNJ(guid)
	guid = M.Legible(guid)
	if type(guid) ~= "string" then return nil end
	local tipo, _, _, _, _, npc = strsplit("-", guid)
	if tipo == "Creature" or tipo == "Vehicle" then return tonumber(npc) end
	return nil
end

local function alUnidad(tooltip, unidad)
	if not quiere() or type(unidad) ~= "string" then return end
	local ok, guid = pcall(UnitGUID, unidad)
	local npc = ok and Id.DePNJ(guid)
	if npc then Id.Linea(tooltip, L["ID de PNJ"], npc) end
end

local function alObjeto(tooltip, _, itemID)
	Id.Linea(tooltip, L["ID de objeto"], itemID)
end

local instalado = false
local function instalar()
	if instalado then return end
	instalado = true
	local H = A.Hooks
	if H and H.ItemLines then H.ItemLines(DUENO, function(t, link, id) M.Seguro(alObjeto, t, link, id) end) end
	if H and H.UnitLines then H.UnitLines(DUENO .. ":u", function(t, u) M.Seguro(alUnidad, t, u) end) end
	local P = rawget(_G, "TooltipDataProcessor")
	local tipos = Enum and Enum.TooltipDataType
	if not (type(P) == "table" and type(P.AddTooltipPostCall) == "function" and type(tipos) == "table") then return end
	local function con(etiqueta)
		return function(tooltip, data)
			if type(data) ~= "table" then return end
			M.Seguro(Id.Linea, tooltip, etiqueta, data.id)
		end
	end
	for _, x in ipairs({ { "Spell", L["ID de hechizo"] }, { "UnitAura", L["ID de hechizo"] }, { "Quest", L["ID de misión"] } }) do
		local t = rawget(tipos, x[1])
		if type(t) == "number" then pcall(P.AddTooltipPostCall, t, con(x[2])) end
	end
end

-- Mayús con un cuadro abierto: se vuelve a armar para mostrar (o quitar) el ID.
local function alModificador(_, tecla)
	if tecla ~= "LSHIFT" and tecla ~= "RSHIFT" then return end
	if not M.Get("cuadroID") or M.Get("cuadroIDSiempre") then return end
	if InCombatLockdown and InCombatLockdown() then return end
	local tip = GameTooltip
	if not (tip and tip.IsShown and tip:IsShown() and type(tip.RefreshData) == "function") then return end
	if tip.IsForbidden and tip:IsForbidden() then return end
	pcall(tip.RefreshData, tip)
end

local modificador = false
M.AlCambiar({ "cuadroID", "cuadroIDSiempre" }, function()
	if not M.Get("cuadroID") then return end
	instalar()
	if not modificador then
		modificador = A.RegisterEvent("MODIFIER_STATE_CHANGED", function(...) M.Seguro(alModificador, ...) end)
	end
end)

-- Para pruebas.
Id.AlUnidad = alUnidad
Id.AlObjeto = alObjeto
