-- Alfa - Comercio: lo valioso que vendiste sin querer (toxic3000 / La Jauría).
-- GPL-3.0. 1.4.0 (diario, 94)
--
-- Un clic derecho de más con el comerciante abierto y la pieza azul que
-- ibas a usar se vende. El juego la guarda en «Recompra» mientras sigas ahí,
-- pero no lo dice. Al vender algo azul o mejor (calidad 3+), o un arma o
-- armadura que es mejor que lo que llevas (la flecha de mejora del motor),
-- un aviso: «Vendiste [Pieza] por 1o 20p», con «Recomprar» (te cuesta lo
-- mismo que te pagaron). Lo que tiene candado ya lo avisa Bolsas
-- (Candado.lua); aquí no se repite. Las ventas en tanda (tu chatarra, «Vender
-- lo que sobra») son a propósito y no avisan.
-- Nunca recompra solo. Ajuste comercio.recompra (sí).
--
-- API clásica del comerciante (globales; el juego las usa en su pestaña de
-- recompra): GetNumBuybackItems(), GetBuybackItemLink(i),
-- GetBuybackItemInfo(i) -> nombre, ícono, precio, cantidad, BuybackItem(i);
-- eventos MERCHANT_SHOW, MERCHANT_UPDATE, MERCHANT_CLOSED.
--
--   Rc.Valioso(link) -> true | false     Rc.Recomprar(link) -> ok

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, pcall, tonumber, format = type, pcall, tonumber, string.format

local Rc = {}
M.Recompra = Rc

local TANDA = 1.5 -- s: más de 2 ventas en este rato son una tanda (a propósito)

local function encendido() return M.Ajuste("recompra") ~= false end
local function num(v) return N.LeerNumero and N.LeerNumero(v) or tonumber(N.Leer(v)) end
local function texto(v) v = N.Leer(v) return type(v) == "string" and v or nil end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d
end

local function idDe(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil end

local function calidad(link)
	local CI = rawget(_G, "C_Item")
	local f = CI and CI.GetItemInfo or rawget(_G, "GetItemInfo")
	local _, _, q, _, _, _, _, _, equipo = llamar(f, link)
	return num(q), texto(equipo)
end

local function esMejora(link)
	local G = A and A.Gear
	local B = G and G.Bags
	if not (B and type(B.IsUpgrade) == "function") then return false end
	local ok, si = pcall(B.IsUpgrade, link)
	return ok and si == true
end

function Rc.Valioso(link)
	if type(link) ~= "string" then return false end
	local q, equipo = calidad(link)
	if q and q >= 3 then return true end
	if equipo and equipo ~= "" and q and q >= 2 and esMejora(link) then return true end
	return false
end

local function conCandado(id, link)
	local B = rawget(_G, "AlfaBolsas")
	return type(B) == "table" and type(B.Candado) == "function" and B.Candado(id, link) and true or false
end

-- La posición de ese objeto en «Recompra» (la última que coincide).
local function buscar(link)
	local n = num(llamar(rawget(_G, "GetNumBuybackItems"))) or 0
	for i = n, 1, -1 do
		if texto(llamar(rawget(_G, "GetBuybackItemLink"), i)) == link then return i end
	end
	return nil
end

function Rc.Recomprar(link)
	local i = buscar(link)
	if not i then
		if K and K.Aviso then K.Aviso({ titulo = L["Ya no está en «Recompra»"], texto = L["El comerciante solo la guarda mientras sigues con él."], icono = "ic-aviso", tono = "aviso", pedido = true }) end
		return false
	end
	local f = rawget(_G, "BuybackItem")
	return type(f) == "function" and pcall(f, i) and true or false
end

local abierto, ultima, ventas = false, nil, {}

local function ultimaRecompra()
	local n = num(llamar(rawget(_G, "GetNumBuybackItems"))) or 0
	return n, n > 0 and texto(llamar(rawget(_G, "GetBuybackItemLink"), n)) or nil
end

local function avisar(link, precio)
	if not (K and K.Aviso) then return end
	local t = format(L["Vendiste %s por %s."], link, N.Dinero(precio or 0)) .. " " .. L["Si fue sin querer, recómprala ahora: cuesta lo mismo."]
	K.Aviso({
		id = "comercio.recompra", titulo = L["¿Lo vendiste sin querer?"], texto = t, icono = "ic-comercio", tono = "aviso",
		duracion = 12, prioridad = "importante", pedido = true,
		acciones = { { texto = L["Recomprar"], alClic = function() Rc.Recomprar(link) end } },
	})
end

A.RegisterEvent("MERCHANT_SHOW", function()
	abierto = true
	ventas = {}
	local n, link = ultimaRecompra()
	ultima = { n = n, link = link }
end)
A.RegisterEvent("MERCHANT_CLOSED", function() abierto, ultima, ventas = false, nil, {} end)
A.RegisterEvent("MERCHANT_UPDATE", function()
	if not (abierto and ultima and encendido()) then return end
	local n, link = ultimaRecompra()
	if n == ultima.n and link == ultima.link then return end
	ultima = { n = n, link = link }
	if not link then return end
	local t = GetTime and GetTime() or 0
	-- Las ventas en tanda (la chatarra, «lo que sobra») son a propósito.
	local recientes = {}
	for _, v in ipairs(ventas) do if t - v < TANDA then recientes[#recientes + 1] = v end end
	recientes[#recientes + 1] = t
	ventas = recientes
	if #recientes > 2 then return end
	local id = idDe(link)
	if not id or conCandado(id, link) or not Rc.Valioso(link) then return end
	local _, _, precio = llamar(rawget(_G, "GetBuybackItemInfo"), n)
	N.Una("comercio.recompra", 0.3, function()
		-- Si en ese rato vino otra venta, era una tanda.
		if #ventas > 2 then return end
		avisar(link, num(precio))
	end)
end)
