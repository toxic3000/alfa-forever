-- Alfa - Comodidades: el cuadro de información de las unidades (como
-- TipShowTarget, TipShowRank, TipHideInCombat y TipHideShiftOverride de
-- Leatrix Plus, con código propio). GPL-3.0.
--
--   A quién apunta: una línea "Objetivo: ..." con el objetivo de la unidad
--     (tú, en el color del acento; un jugador, en el color de su clase; una
--     criatura, en rojo, amarillo o verde según su reacción).
--   Rango de tu hermandad: para alguien de tu hermandad, una línea con su
--     rango.
--   Ocultar en combate: el cuadro de las unidades del mundo (el que sale
--     junto al ratón, no el de los marcos) no aparece en combate; con la
--     opción de Mayús, mantener Mayús lo muestra.
--
-- Las líneas se agregan por Alfa.Hooks.UnitLines (Core/Hooks.lua, el único
-- dueño de los ganchos del cuadro en Alfa). El ocultar usa su propio
-- TooltipDataProcessor.AddTooltipPostCall de unidades (el mismo mecanismo
-- del motor). Nada de esto se muestra con valores secretos (combate en
-- mazmorras): se deja el cuadro como lo arma Blizzard.
--
-- Cliente: UnitExists, UnitIsUnit, UnitName, UnitIsPlayer, UnitClass,
-- UnitReaction (UnitDocumentation); GetGuildInfo no está en la documentación
-- generada (la usa Leatrix Plus en Forever): va protegida con pcall.
-- MODIFIER_STATE_CHANGED (KeyBindingsDocumentation); GameTooltip_SetDefaultAnchor
-- (Blizzard_SharedXML/SharedTooltipTemplates.lua).

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local T = A.Theme

local legible = M.Legible

local function opcion(clave) return M.On("cuadro", clave) end

local function hex(r, g, b)
	return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function leer(fn, ...)
	if not fn then return nil end
	local ok, v1, v2, v3 = pcall(fn, ...)
	if not ok then return nil end
	return legible(v1), legible(v2), legible(v3)
end

-- El color de una unidad para su nombre: su clase (jugadores) o su reacción.
local function colorDe(unidad)
	if leer(UnitIsPlayer, unidad) then
		local _, clase = leer(UnitClass, unidad)
		if type(clase) == "string" then
			local r, g, b = T.ClassColor(clase)
			if r then return r, g, b end
		end
		return 1, 1, 1
	end
	local reaccion = tonumber(leer(UnitReaction, unidad, "player"))
	if not reaccion then return 1, 1, 1 end
	if reaccion <= 3 then return 1, 0.25, 0.2 end
	if reaccion == 4 then return 1, 0.85, 0.2 end
	return 0.3, 0.9, 0.3
end

local function lineaObjetivo(tooltip, unidad)
	if not opcion("cuadroObjetivo") then return end
	local destino = unidad .. "target"
	if not leer(UnitExists, destino) then return end
	local texto
	if leer(UnitIsUnit, destino, "player") then
		local r, g, b = T.Accent()
		texto = hex(r, g, b) .. L["¡Tú!"] .. "|r"
	else
		local nombre = leer(UnitName, destino)
		if type(nombre) ~= "string" or nombre == "" then return end
		texto = hex(colorDe(destino)) .. nombre .. "|r"
	end
	local r, g, b = T.Color("textDim")
	A.Hooks.AddLine(tooltip, L["Objetivo:"] .. " " .. texto, nil, r, g, b)
end

local function lineaRango(tooltip, unidad)
	if not opcion("cuadroRango") then return end
	if not (GetGuildInfo and leer(UnitIsPlayer, unidad)) then return end
	local mio = leer(GetGuildInfo, "player")
	if type(mio) ~= "string" or mio == "" then return end
	local suyo, rango = leer(GetGuildInfo, unidad)
	if suyo ~= mio or type(rango) ~= "string" or rango == "" then return end
	A.Hooks.AddLine(tooltip, L["Rango en tu hermandad:"] .. " " .. rango, nil, 0.25, 1, 0.25)
end

local function lineas(tooltip, unidad)
	if not M.Get("cuadro") or type(unidad) ~= "string" then return end
	lineaObjetivo(tooltip, unidad)
	lineaRango(tooltip, unidad)
end

---------------------------------------------------------------------------
-- Ocultar en combate
---------------------------------------------------------------------------

local function enCombate()
	return InCombatLockdown and InCombatLockdown() and true or false
end

local function delMundo(tooltip)
	if tooltip ~= GameTooltip then return false end
	if tooltip.IsForbidden and tooltip:IsForbidden() then return false end
	return tooltip.GetOwner and tooltip:GetOwner() == UIParent or false
end

local function alCuadroDeUnidad(tooltip)
	if not (opcion("cuadroCombate") and enCombate()) then return end
	if opcion("cuadroShift") and M.Shift() then return end
	if delMundo(tooltip) then tooltip:Hide() end
end

local instalado = false
local function instalarOcultar()
	if instalado then return end
	instalado = true
	local P = TooltipDataProcessor
	local tipos = Enum and Enum.TooltipDataType
	if P and P.AddTooltipPostCall and tipos and tipos.Unit then
		P.AddTooltipPostCall(tipos.Unit, function(tooltip) M.Seguro(alCuadroDeUnidad, tooltip) end)
	elseif GameTooltip and GameTooltip.HookScript then
		GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip) M.Seguro(alCuadroDeUnidad, tooltip) end)
	end
end

-- Mayús en combate: muestra el cuadro de la unidad bajo el ratón, y al
-- soltarla se vuelve a ocultar.
local function alModificador(_, tecla, abajo)
	if not (opcion("cuadroCombate") and opcion("cuadroShift") and enCombate()) then return end
	if tecla ~= "LSHIFT" and tecla ~= "RSHIFT" then return end
	local tip = GameTooltip
	if not tip then return end
	if abajo == 1 then
		if not leer(UnitExists, "mouseover") or (tip:IsShown() and delMundo(tip)) then return end
		if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(tip, UIParent) end
		pcall(tip.SetUnit, tip, "mouseover")
	elseif delMundo(tip) and tip:IsShown() then
		tip:Hide()
	end
end

local modificador = false
M.AlCambiar({ "cuadro", "cuadroCombate", "cuadroShift" }, function()
	if not opcion("cuadroCombate") then return end
	instalarOcultar()
	if not modificador then
		modificador = A.RegisterEvent("MODIFIER_STATE_CHANGED", function(...) M.Seguro(alModificador, ...) end)
	end
end)

-- Las líneas solo se piden al motor la primera vez que hacen falta.
local registrado = false
M.AlCambiar({ "cuadro", "cuadroObjetivo", "cuadroRango" }, function()
	if registrado or not (opcion("cuadroObjetivo") or opcion("cuadroRango")) then return end
	if A.Hooks and A.Hooks.UnitLines then
		registrado = A.Hooks.UnitLines(ADDON, function(tooltip, unidad) M.Seguro(lineas, tooltip, unidad) end) and true or false
	end
end)

-- Para pruebas.
M.Cuadro = { Lineas = lineas, AlCuadroDeUnidad = alCuadroDeUnidad, ColorDe = colorDe }
