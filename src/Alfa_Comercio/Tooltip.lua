-- Alfa - Comercio: el consejo en el cuadro de cada objeto (toxic3000 / La Jauría). GPL-3.0.
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
	if (c.info.pila or 1) > 1 then
		dos = dos .. " " .. gris .. L["c/u"] .. "|r"
		-- 1.3.7: lo que vale la pila entera («×20: 3o 40p»).
		if (c.valor or 0) > 0 then
			dos = dos .. gris .. " · ×" .. c.info.pila .. ":|r " .. M.Dinero(c.valor * c.info.pila)
		end
	end
	return uno, dos
end

-- 1.3.9: el consejo en una sola línea, lo que conviene y cuánto deja:
--   «Alfa  Subástalo: 1o 20p (+700 %)»  /  «Alfa  Véndelo: 15p (×20: 3o)»
-- Con Mayús (o con comercio.tooltipDetalle) salen las dos líneas de antes.
local VERBO = {
	vender = L["Véndelo al comerciante"], subastar = L["Súbelo a la subasta"], desencantar = L["Desencántalo"],
	guardar = L["Guárdalo"],
}
function M.LineaCuadro(c)
	if not c then return nil end
	local gris = hex("textDim")
	local _, color = M.ChipDe(c)
	local verbo = VERBO[c.mejor] or VERBO.guardar
	if c.mejor == "desencantar" or c.mejor == "receta" then
		local t = M.TextoMejor(c)
		-- «crear X (con Y)» / «desencantar (con Y)»: lo de los paréntesis se queda.
		local con = t:match("(%b())%s*$")
		if c.mejor == "receta" then verbo = (t:gsub("^%l", string.upper)) elseif con then verbo = verbo .. " " .. con end
	end
	local s = hex(color) .. verbo .. "|r"
	if c.mejor == "guardar" then
		if c.motivo then s = s .. " " .. gris .. "(" .. c.motivo .. ")|r" end
		return s
	end
	s = s .. gris .. ":|r " .. hex("text") .. M.Dinero(c.valor) .. "|r"
	local extra = {}
	if c.mejor ~= "vender" and c.ganancia then extra[#extra + 1] = hex("success") .. M.Porcentaje(c.ganancia) .. "|r" end
	if (c.info.pila or 1) > 1 and (c.valor or 0) > 0 then extra[#extra + 1] = gris .. "×" .. c.info.pila .. ":|r " .. M.Dinero(c.valor * c.info.pila) end
	if c.mejor == "subastar" and c.subasta and c.subasta.viejo then extra[#extra + 1] = hex("warning") .. L["precio viejo"] .. "|r" end
	if c.mejor == "desencantar" or c.mejor == "receta" then extra[#extra + 1] = gris .. L["estimado"] .. "|r" end
	if #extra > 0 then s = s .. " " .. gris .. "(|r" .. table.concat(extra, gris .. " · |r") .. gris .. ")|r" end
	return s
end

local function detalle()
	if M.Ajuste("tooltipDetalle") then return true end
	return IsShiftKeyDown and IsShiftKeyDown() == true or false
end
M.CuadroDetalle = detalle

-- 1.3.7: objetos donde el consejo no dice nada útil y solo llena el cuadro:
-- la piedra de hogar, los de misión y el equipo que ya es tuyo (ligado) o que
-- no se puede vender ni transformar.
M.SIN_CONSEJO = { [6948] = true } -- piedra de hogar
function M.SinConsejo(c, ligadoReal)
	if not c then return true end
	if M.SIN_CONSEJO[c.id] then return true end
	local clase = c.info and c.info.clase
	if clase == M.CLASE_MISION then return true end
	if ligadoReal == true and (clase == 2 or clase == 4) then return true end
	if c.ligado and (c.venta or 0) <= 0 and not c.desencantar and not c.receta then return true end
	return false
end

local function secreto(v) return issecretvalue and issecretvalue(v) or false end

-- El objeto de ese cuadro ya está ligado (uno "al equiparse" que ya te pusiste):
-- true, false o nil si no se sabe (un objeto que no es tuyo, un enlace del chat).
-- El cuadro trae su GUID (GetTooltipData); C_Item.GetItemLocation y IsBound
-- (ItemDocumentation) dicen si está ligado. Sin eso, el tipo de ligado del objeto.
local function ligadoDe(tooltip)
	if not (tooltip and tooltip.GetTooltipData) then return nil end
	local ok, d = pcall(tooltip.GetTooltipData, tooltip)
	if not ok or secreto(d) or type(d) ~= "table" then return nil end
	local guid = d.guid
	if secreto(guid) or type(guid) ~= "string" or guid == "" then return nil end
	local CI = C_Item
	if not (CI and CI.GetItemLocation and CI.IsBound) then return nil end
	local ok2, loc = pcall(CI.GetItemLocation, guid)
	if not ok2 or type(loc) ~= "table" or not loc.IsValid then return nil end
	local ok3, valido = pcall(loc.IsValid, loc)
	if not (ok3 and valido == true) then return nil end
	local ok4, si = pcall(CI.IsBound, loc)
	if ok4 and not secreto(si) and type(si) == "boolean" then return si end
	return nil
end

A.Hooks.ItemLines(M.ID, function(tooltip, link, itemID)
	if not M.Ajuste("tooltip") or type(itemID) ~= "number" then return end
	local ligado = ligadoDe(tooltip)
	local c = M.Consejo(itemID, { link = link, ligado = ligado })
	if M.SinConsejo(c, ligado) then return end
	if not detalle() then
		local linea = M.LineaCuadro(c)
		if not linea then return end
		A.Hooks.AddLine(tooltip, N.HEX .. "Alfa|r  " .. linea, nil, 1, 1, 1)
	else
		local uno, dos = M.LineasCuadro(c)
		if not uno then return end
		A.Hooks.AddLine(tooltip, N.HEX .. "Alfa|r " .. uno, nil, 1, 1, 1)
		A.Hooks.AddLine(tooltip, dos, nil, 1, 1, 1)
	end
	-- 1.3.7: con la subasta abierta, si es ganga (Gangas.lua).
	if M.GangaDe and M.SubastaAbierta() and M.GangasActivas() then
		local g = M.GangaDe(itemID)
		if g then A.Hooks.AddLine(tooltip, hex("success") .. M.TextoGanga(g) .. "|r", nil, 1, 1, 1) end
	end
end)
