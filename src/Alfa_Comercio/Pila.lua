-- Alfa - Comercio: Alt+clic compra una pila (toxic3000 / La Jauría). GPL-3.0.
-- 1.4.0 (diario, 95)
--
-- Comprar 20 de agua o 200 flechas es Mayús+clic, escribir el número y
-- aceptar. Con Alfa, Alt+clic sobre lo que vende el comerciante compra una
-- pila entera de un jalón: lo que cabe en un montón (el del objeto), en
-- compras que el comerciante acepta, sin pasar de lo que tiene ni de lo que te
-- alcanza. Lo que compraste sale en tu chat. Solo en la pestaña de comprar y
-- solo con dinero (lo que pide otra moneda u objetos se deja al juego).
-- En el Forever clásico el Alt+clic del comerciante no hace nada: no se pisa
-- nada del juego. Ajuste comercio.pila (sí).
--
-- API (Forever Vanilla MerchantFrame.lua, la que usa la compra del motor en
-- QoL/Buy.lua): GetMerchantItemInfo / C_MerchantFrame.GetItemInfo,
-- GetMerchantItemMaxStack(i), GetMerchantItemLink(i), BuyMerchantItem(i, n)
-- (n: objetos), MerchantFrame.selectedTab, los botones MerchantItem<N>ItemButton
-- (su :GetID() es la casilla del comerciante).
--
--   Pi.Plan(i) -> objetos, costo, motivo     Pi.Comprar(i) -> objetos, costo | nil, motivo

local _, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L

local type, pcall, tonumber, format, floor, min, max = type, pcall, tonumber, string.format, math.floor, math.min, math.max

local Pi = {}
M.Pila = Pi

local function encendido() return M.Ajuste("pila") ~= false end
local function num(v) return N.LeerNumero and N.LeerNumero(v) or tonumber(N.Leer(v)) end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d, e, f, g, h
end

-- nombre, precio por compra, objetos por compra, existencias (-1 sin límite), otra moneda
local function datos(i)
	local CM = rawget(_G, "C_MerchantFrame")
	if CM and type(CM.GetItemInfo) == "function" then
		local info = llamar(CM.GetItemInfo, i)
		if type(info) ~= "table" then return nil end
		return N.Leer(info.name), num(info.price), num(info.stackCount), num(info.numAvailable), N.Si(info.hasExtendedCost)
	end
	local nombre, _, precio, porCompra, hay, _, _, otra = llamar(rawget(_G, "GetMerchantItemInfo"), i)
	return N.Leer(nombre), num(precio), num(porCompra), num(hay), N.Si(otra)
end

local function montonDe(i)
	local link = N.Leer(llamar(rawget(_G, "GetMerchantItemLink"), i))
	local CI = rawget(_G, "C_Item")
	local f = CI and CI.GetItemInfo or rawget(_G, "GetItemInfo")
	if type(link) ~= "string" then return nil, nil end
	local _, _, _, _, _, _, _, monton = llamar(f, link)
	return num(monton), link
end

function Pi.Plan(i)
	local nombre, precio, porCompra, hay, otra = datos(i)
	if not nombre or not precio then return 0, 0, "nada" end
	if otra then return 0, 0, "moneda" end
	porCompra = max(1, porCompra or 1)
	local monton = montonDe(i) or porCompra
	if monton <= 1 then return 0, 0, "suelto" end
	-- Compras enteras hasta llenar un montón.
	local compras = max(1, floor(monton / porCompra))
	if hay and hay >= 0 then compras = min(compras, hay) end
	if precio > 0 then
		local dinero = num(GetMoney and GetMoney()) or 0
		compras = min(compras, floor(dinero / precio))
	end
	if compras <= 0 then return 0, 0, (hay == 0) and "agotado" or "dinero" end
	return compras * porCompra, compras * precio, nil
end

local MOTIVO = {
	dinero = "No te alcanza para una pila.",
	agotado = "El comerciante ya no tiene más.",
	moneda = "Eso se paga con otra cosa: cómpralo con el juego.",
}

function Pi.Comprar(i)
	if InCombatLockdown and InCombatLockdown() then return nil, "combate" end
	local objetos, costo, motivo = Pi.Plan(i)
	if objetos <= 0 then
		if MOTIVO[motivo] then N.Imprimir(L[MOTIVO[motivo]]) end
		return nil, motivo
	end
	local buy = rawget(_G, "BuyMerchantItem")
	if type(buy) ~= "function" then return nil, "juego" end
	local _, _, porCompra = datos(i)
	porCompra = max(1, porCompra or 1)
	local maxVez = num(llamar(rawget(_G, "GetMerchantItemMaxStack"), i)) or porCompra
	local por = maxVez >= porCompra and (maxVez - maxVez % porCompra) or porCompra
	local falta = objetos
	while falta > 0 do
		local n = min(falta, por)
		if not pcall(buy, i, n) then break end
		falta = falta - n
	end
	local _, link = montonDe(i)
	N.Imprimir(format(L["Compraste %d de %s por %s."], objetos - falta, link or (datos(i)) or "?", N.Dinero(costo)))
	return objetos - falta, costo
end

-- El clic: Alt+clic izquierdo en la pestaña de comprar.
local function alClic(boton, raton)
	if not encendido() or raton ~= "LeftButton" then return end
	if not (IsAltKeyDown and IsAltKeyDown()) or (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) then return end
	local MF = rawget(_G, "MerchantFrame")
	if type(MF) == "table" and MF.selectedTab and MF.selectedTab ~= 1 then return end
	local i = boton and boton.GetID and num(boton:GetID())
	if i and i > 0 then Pi.Comprar(i) end
end
Pi.AlClic = alClic

local enganchados = {}
local function enganchar()
	for k = 1, 20 do
		local b = rawget(_G, "MerchantItem" .. k .. "ItemButton")
		if type(b) == "table" and b.HookScript and not enganchados[b] then
			enganchados[b] = true
			b:HookScript("OnClick", alClic)
		end
	end
end
Pi.Enganchar = enganchar

A.RegisterEvent("MERCHANT_SHOW", function() if encendido() then enganchar() end end)
