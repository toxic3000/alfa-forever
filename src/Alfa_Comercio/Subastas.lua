-- Alfa - Comercio: tus subastas, lo que tienes a la venta (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Lo que pusiste a la venta se olvida en cuanto cierras la casa de subastas:
-- cuántas cosas tienes publicadas, cuánto valen, cuáles ya se vendieron y
-- cuándo vencen. Alfa lo recuerda por personaje (de toda tu cuenta) y lo
-- dice en la página de Comercio, en el cuadro de cada objeto («3 en la
-- subasta», Alfa_Bolsas) y en la ayuda al subastar («La última vez lo
-- pusiste a…», Vender.lua). Al abrir la subasta, si algo se vendió desde la
-- última vez, un aviso lo dice.
--
-- Solo se lee: nada se publica, cancela ni compra.
-- API (Blizzard_APIDocumentationGenerated/AuctionHouseDocumentation.lua, sin
-- HasRestrictions):
--   C_AuctionHouse.QueryOwnedAuctions(sorts)   (se pide una vez al abrir)
--   OWNED_AUCTIONS_UPDATED -> C_AuctionHouse.GetOwnedAuctions() o
--     GetNumOwnedAuctions + GetOwnedAuctionInfo(i): { auctionID, itemKey,
--     itemLink, status (0 en venta, 1 vendida), quantity, timeLeftSeconds,
--     buyoutAmount, bidAmount }
--   AUCTION_HOUSE_AUCTION_CREATED -> se vuelve a pedir (para el precio nuevo)
-- POR CONFIRMAR EN EL JUEGO: si buyoutAmount de una pila es por unidad o el
-- total. Alfa elige la lectura que más se parece al precio que conoce del
-- objeto; sin precio, la toma por unidad (como el cliente moderno).
--
-- Datos de la cuenta: N.Datos("comercio").subastas["Nombre-Reino"] =
--   { t = cuándo se leyó, reino, lista = { { id, q, u (cobre c/u), fin, v (1 vendida), n } } }
-- y por reino (M.Reino().mio[id] = { u, t }): el último precio que pusiste.
--
--   Su.Leer() -> n            Su.Todas() -> { { clave, nombre, propio, o... } }
--   Su.EnSubasta(id) -> n     Su.UltimoPrecio(id) -> cobre c/u, cuándo
--   Su.Resumen() -> { activas, vendidas, vencidas, valor, vendido, proxima, personajes }

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, ipairs, pairs, pcall, tonumber, floor, max, min, format, abs =
	type, ipairs, pairs, pcall, tonumber, math.floor, math.max, math.min, string.format, math.abs

local Su = {}
M.Subastas = Su

local MAX_LISTA = 120
local VIEJA = 7 * 86400 -- una foto de más de una semana ya no dice nada

local function encendido() return M.Ajuste("subastas") ~= false end
local function num(v) return N.LeerNumero and N.LeerNumero(v) or tonumber(N.Leer(v)) end

local function raiz()
	local d = M.Datos()
	d.subastas = type(d.subastas) == "table" and d.subastas or {}
	return d.subastas
end

local function api()
	local AH = rawget(_G, "C_AuctionHouse")
	return type(AH) == "table" and AH or nil
end

-- El precio por unidad de una subasta tuya (ver «POR CONFIRMAR» arriba).
function Su.Unidad(id, total, cantidad)
	total, cantidad = num(total), max(1, num(cantidad) or 1)
	if not total or total <= 0 then return nil end
	if cantidad <= 1 then return total end
	local ref = M.PrecioSubasta(id)
	if ref and ref > 0 then
		local porPila = total / cantidad
		if abs(porPila - ref) < abs(total - ref) then return floor(porPila + 0.5) end
	end
	return total
end

local function info(AH, i)
	if type(AH.GetOwnedAuctionInfo) ~= "function" then return nil end
	local ok, o = pcall(AH.GetOwnedAuctionInfo, i)
	return ok and type(o) == "table" and o or nil
end

local function todasDelJuego(AH)
	if type(AH.GetOwnedAuctions) == "function" then
		local ok, t = pcall(AH.GetOwnedAuctions)
		if ok and type(t) == "table" then return t end
	end
	local out = {}
	local n = 0
	if type(AH.GetNumOwnedAuctions) == "function" then
		local ok, v = pcall(AH.GetNumOwnedAuctions)
		n = ok and num(v) or 0
	end
	for i = 1, min(n or 0, MAX_LISTA) do
		local o = info(AH, i)
		if o then out[#out + 1] = o end
	end
	return out
end

local function nombreDe(o, id)
	local link = N.Leer(o.itemLink)
	if type(link) == "string" then
		local nombre = link:match("%[(.-)%]")
		if nombre and nombre ~= "" then return nombre end
	end
	local CI = rawget(_G, "C_Item")
	local f = (type(CI) == "table" and CI.GetItemInfo) or rawget(_G, "GetItemInfo")
	if type(f) == "function" and id then
		local ok, n = pcall(f, id)
		if ok and type(N.Leer(n)) == "string" then return N.Leer(n) end
	end
	return nil
end

-- Lee lo que el juego dice de tus subastas y lo guarda. -> cuántas, vendidas nuevas, cobre de esas
function Su.Leer()
	local AH = api()
	if not AH then return 0, 0, 0 end
	local ahora = M.Ahora()
	local clave = M.ClavePersonaje()
	local R = raiz()
	local antes = R[clave]
	local yaVendidas = {}
	for _, o in ipairs(type(antes) == "table" and type(antes.lista) == "table" and antes.lista or {}) do
		if o.v == 1 and o.a then yaVendidas[o.a] = true end
	end
	local lista, nuevas, cobreNuevas = {}, 0, 0
	local mio = M.Reino().mio
	if type(mio) ~= "table" then mio = {} M.Reino().mio = mio end
	for _, o in ipairs(todasDelJuego(AH)) do
		if #lista >= MAX_LISTA then break end
		local key = type(o.itemKey) == "table" and o.itemKey or {}
		local id = num(key.itemID)
		if id then
			local q = max(1, num(o.quantity) or 1)
			local u = Su.Unidad(id, o.buyoutAmount or o.bidAmount, q)
			local seg = num(o.timeLeftSeconds)
			local vendida = num(o.status) == 1
			local a = num(o.auctionID)
			local e = { id = id, q = q, u = u, a = a, n = nombreDe(o, id), v = vendida and 1 or nil,
				fin = (not vendida and seg and seg > 0) and (ahora + seg) or nil }
			lista[#lista + 1] = e
			if vendida and not (a and yaVendidas[a]) then
				nuevas = nuevas + 1
				cobreNuevas = cobreNuevas + (u or 0) * q
			end
			-- El último precio que pusiste a ese objeto (solo de lo que sigue en venta).
			if u and not vendida then mio[id] = { u, ahora } end
		end
	end
	R[clave] = { t = ahora, reino = M.ClaveReino(), nombre = M.NombrePersonaje(), lista = lista }
	return #lista, nuevas, cobreNuevas
end

-- Las subastas de todos tus personajes: { { clave, nombre, propio, id, q, u, fin, v, n } }
function Su.Todas()
	local out = {}
	local propio = M.ClavePersonaje()
	local ahora = M.Ahora()
	for clave, s in pairs(raiz()) do
		if type(s) == "table" and type(s.lista) == "table" and (tonumber(s.t) or 0) > ahora - VIEJA then
			for _, o in ipairs(s.lista) do
				if type(o) == "table" and o.id then
					out[#out + 1] = { clave = clave, nombre = s.nombre or clave, propio = clave == propio,
						id = o.id, q = o.q or 1, u = o.u, fin = o.fin, v = o.v, n = o.n }
				end
			end
		end
	end
	-- Lo vendido primero; luego lo que vence antes.
	table.sort(out, function(a, b)
		if (a.v or 0) ~= (b.v or 0) then return (a.v or 0) > (b.v or 0) end
		local fa, fb = a.fin or math.huge, b.fin or math.huge
		if fa ~= fb then return fa < fb end
		return tostring(a.n or a.id) < tostring(b.n or b.id)
	end)
	return out
end

-- Cuántos de ese objeto tienes a la venta (todos tus personajes, sin lo vendido ni lo vencido).
function Su.EnSubasta(id)
	id = tonumber(id)
	if not id or not encendido() then return 0 end
	local ahora, n = M.Ahora(), 0
	for _, o in ipairs(Su.Todas()) do
		if o.id == id and o.v ~= 1 and (not o.fin or o.fin > ahora) then n = n + (o.q or 1) end
	end
	return n
end

-- El último precio por unidad que le pusiste a ese objeto (en este reino). -> cobre, cuándo | nil
function Su.UltimoPrecio(id)
	id = tonumber(id)
	local m = id and type(M.Reino().mio) == "table" and M.Reino().mio[id]
	if type(m) == "table" and type(m[1]) == "number" then return m[1], m[2] end
	return nil
end

function Su.Resumen()
	local r = { activas = 0, vendidas = 0, vencidas = 0, valor = 0, vendido = 0, personajes = 0 }
	local ahora, vistos = M.Ahora(), {}
	for _, o in ipairs(Su.Todas()) do
		if not vistos[o.clave] then vistos[o.clave] = true r.personajes = r.personajes + 1 end
		local total = (o.u or 0) * (o.q or 1)
		if o.v == 1 then
			r.vendidas, r.vendido = r.vendidas + 1, r.vendido + total
		elseif o.fin and o.fin <= ahora then
			r.vencidas = r.vencidas + 1
		else
			r.activas, r.valor = r.activas + 1, r.valor + total
			if o.fin and (not r.proxima or o.fin < r.proxima) then r.proxima = o.fin end
		end
	end
	return r
end

-- «vence en 3 h» / «vence en 25 min» / «venció».
function Su.Vence(fin)
	if not fin then return L["en venta"] end
	local s = fin - M.Ahora()
	if s <= 0 then return L["venció: llega por el buzón"] end
	if s < 3600 then return format(L["vence en %d min"], max(1, floor(s / 60))) end
	if s < 2 * 86400 then return format(L["vence en %d h"], floor(s / 3600 + 0.5)) end
	return format(L["vence en %d d"], floor(s / 86400 + 0.5))
end

---------------------------------------------------------------------------
-- Con la subasta abierta: se pide la lista una vez y se lee cuando llega.
---------------------------------------------------------------------------
local abierta, avisada = false, false

local function pedir()
	if not (abierta and encendido()) then return end
	local AH = api()
	if not (AH and type(AH.QueryOwnedAuctions) == "function") then return end
	pcall(AH.QueryOwnedAuctions, {})
end
Su.Pedir = pedir

local function alLlegar()
	if not encendido() then return end
	local _, nuevas, cobre = Su.Leer()
	M.Cambio()
	if nuevas > 0 and not avisada and K and K.Aviso then
		avisada = true
		K.Aviso({
			id = "comercio.subastasVendidas", icono = "ic-oro", tono = "exito", duracion = 10, prioridad = "util",
			titulo = N.Plural(nuevas, L["¡Se vendió %d de tus subastas!"], L["¡Se vendieron %d de tus subastas!"]),
			texto = (cobre > 0 and format(L["Unos %s, menos la comisión."], M.Dinero(cobre)) .. " " or "") .. L["El dinero te espera en el buzón."],
			donde = L["Comercio > Tus subastas"],
		})
	end
end
Su.AlLlegar = alLlegar

A.RegisterEvent("AUCTION_HOUSE_SHOW", function()
	abierta, avisada = true, false
	-- Después del escaneo del motor y de la barra (no se pisan): 1,5 s.
	N.Una("comercio.subastas", 1.5, pedir)
end)
A.RegisterEvent("AUCTION_HOUSE_CLOSED", function() abierta = false end)
A.RegisterEvent("OWNED_AUCTIONS_UPDATED", function() N.Una("comercio.subastasLeer", 0.3, alLlegar) end)
A.RegisterEvent("AUCTION_HOUSE_AUCTION_CREATED", function() N.Una("comercio.subastas", 1, pedir) end)
A.RegisterEvent("AUCTION_CANCELED", function() N.Una("comercio.subastas", 1, pedir) end)

-- Para Alfa_Bolsas (el cuadro «Tienes N») y quien quiera.
AlfaComercio = type(rawget(_G, "AlfaComercio")) == "table" and rawget(_G, "AlfaComercio") or {}
AlfaComercio.EnSubasta = function(id) return Su.EnSubasta(id) end
AlfaComercio.UltimoPrecio = function(id) return Su.UltimoPrecio(id) end
