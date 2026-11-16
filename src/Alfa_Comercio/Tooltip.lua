-- Alfa - Comercio: el consejo en el cuadro de cada objeto (Toxic / La Jauría). GPL-3.0.
--
-- Dos líneas cortas, por ejemplo:
--   Subasta: 1o 20p (hace 3 h) · Comerciante: 15p
--   Mejor: subastar (+700%)
-- Se cuelga de Alfa.Hooks.ItemLines, el dueño único de los cuadros del motor:
-- usa TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)
-- (verificado en Forever, Alfa/Core/Hooks.lua) y se salta cuadros prohibidos
-- y valores secretos.

local _, M = ...
local N = AlfaNucleo
local A = N.A
local T = A.Theme
local L = M.L

local function hex(nombre)
	local ok, h = pcall(T.Hex, nombre)
	return "|c" .. (ok and type(h) == "string" and h or "ffffffff")
end

-- Las dos líneas del consejo (texto con colores), o nil.
function M.LineasCuadro(c)
	if not c then return nil end
	local gris, blanco = hex("textDim"), hex("text")
	local partes = {}
	if c.subasta then
		local s = gris .. L["Subasta:"] .. "|r " .. M.Dinero(c.subasta.bruto)
		if c.subasta.fecha then
			local edad = M.Hace(c.subasta.fecha)
			s = s .. " " .. (c.subasta.viejo and hex("warning") or gris) .. "(" .. edad .. ")|r"
		end
		partes[#partes + 1] = s
	elseif not c.ligado and c.info.clase ~= M.CLASE_MISION then
		partes[#partes + 1] = gris .. L["Subasta:"] .. "|r " .. gris .. L["sin precio"] .. "|r"
	end
	if c.venta > 0 then
		partes[#partes + 1] = gris .. L["Comerciante:"] .. "|r " .. M.Dinero(c.venta)
	else
		partes[#partes + 1] = gris .. L["Comerciante:"] .. "|r " .. gris .. L["no lo compra"] .. "|r"
	end
	local uno = table.concat(partes, gris .. " · |r")
	local _, color = M.ChipDe(c)
	local dos = gris .. L["Mejor:"] .. "|r " .. hex(color) .. M.TextoMejor(c) .. "|r"
	if c.mejor == "guardar" then
		if c.motivo then dos = dos .. " " .. gris .. "(" .. c.motivo .. ")|r" end
	elseif c.mejor ~= "vender" then
		dos = dos .. " " .. blanco .. M.Dinero(c.valor) .. "|r"
		if c.ganancia then dos = dos .. " " .. hex("success") .. "(" .. M.Porcentaje(c.ganancia) .. ")|r" end
		if c.mejor == "desencantar" or c.mejor == "receta" then dos = dos .. " " .. gris .. L["(estimado)"] .. "|r" end
	end
	if (c.info.pila or 1) > 1 then dos = dos .. " " .. gris .. L["c/u"] .. "|r" end
	return uno, dos
end

A.Hooks.ItemLines(M.ID, function(tooltip, link, itemID)
	if not M.Ajuste("tooltip") or type(itemID) ~= "number" then return end
	local c = M.Consejo(itemID, { link = link })
	local uno, dos = M.LineasCuadro(c)
	if not uno then return end
	A.Hooks.AddLine(tooltip, N.HEX .. "Alfa|r " .. uno, nil, 1, 1, 1)
	A.Hooks.AddLine(tooltip, dos, nil, 1, 1, 1)
end)
