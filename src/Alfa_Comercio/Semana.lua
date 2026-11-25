-- Alfa - Comercio: tu semana en la subasta (1.4.0, plan 47; toxic3000 / La Jauría). GPL-3.0.
--
-- Lo que vendiste y compraste en la subasta estos 7 días, con lo que te
-- quedó: se anota al tomar del buzón la carta de la subasta (la de «venta
-- exitosa» trae el dinero; la de «ganaste» trae el objeto). La factura de la
-- carta: GetInboxInvoiceInfo(i) -> tipo ("seller" | "buyer" | ...), objeto,
-- comprador/vendedor (nunca se guarda), puja, compra inmediata, depósito,
-- comisión, ..., cantidad (API clásica del buzón; va protegida: por
-- confirmar en Forever). Se anota al pulsar tú (o «Tomar todo») TakeInboxMoney
-- o TakeInboxItem / AutoLootMailItem, una vez por carta.
-- Por personaje: N.DatosPersonaje("comercio").semana = { { t, k = "v" | "c", n, id, q, c }, ... }
-- (30 días como mucho y 300 movimientos).
--   M.Semana(dias) -> { vendido, comprado, neto, ventas, compras, lista = { ... } (lo más nuevo primero) }
--   M.AnotarMovimiento(k, nombre, cantidad, cobre, id)

local _, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L

local type, ipairs, tonumber, tostring, floor, max, time, format = type, ipairs, tonumber, tostring, math.floor, math.max, time, string.format

local DIA = 86400
local GUARDA, MAX = 30 * DIA, 300

local function lista()
	local d = N.DatosPersonaje(M.ID)
	d.semana = type(d.semana) == "table" and d.semana or {}
	return d.semana
end

local function ahora() return M.Ahora and M.Ahora() or time() end

function M.AnotarMovimiento(k, nombre, cantidad, cobre, id)
	cobre = tonumber(cobre)
	if (k ~= "v" and k ~= "c") or not cobre or cobre <= 0 then return false end
	local l = lista()
	l[#l + 1] = { t = ahora(), k = k, n = type(nombre) == "string" and nombre:sub(1, 80) or nil,
		id = tonumber(id), q = max(1, floor(tonumber(cantidad) or 1)), c = floor(cobre) }
	local limite = ahora() - GUARDA
	while #l > 0 and ((tonumber(l[1].t) or 0) < limite or #l > MAX) do table.remove(l, 1) end
	M.Cambio()
	return true
end

function M.Semana(dias)
	local desde = ahora() - (dias or 7) * DIA
	local out = { vendido = 0, comprado = 0, ventas = 0, compras = 0, lista = {} }
	local l = lista()
	for i = #l, 1, -1 do
		local m = l[i]
		if type(m) == "table" and (tonumber(m.t) or 0) >= desde then
			if m.k == "v" then out.vendido, out.ventas = out.vendido + (m.c or 0), out.ventas + 1
			elseif m.k == "c" then out.comprado, out.compras = out.comprado + (m.c or 0), out.compras + 1 end
			out.lista[#out.lista + 1] = m
		end
	end
	out.neto = out.vendido - out.comprado
	return out
end

---------------------------------------------------------------------------
-- Las cartas de la subasta
---------------------------------------------------------------------------
local vistas = {} -- firma de la carta -> true (en esta visita al buzón)

local function leer(v) if N.Secreto and N.Secreto(v) then return nil end return v end

local function factura(i)
	local f = rawget(_G, "GetInboxInvoiceInfo")
	if type(f) ~= "function" then return nil end
	local ok, tipo, objeto, _, puja, _, _, comision, _, _, _, cantidad = pcall(f, i)
	if not ok then return nil end
	tipo, objeto, puja, comision, cantidad = leer(tipo), leer(objeto), leer(puja), leer(comision), leer(cantidad)
	if type(tipo) ~= "string" or type(puja) ~= "number" then return nil end
	return tipo, objeto, puja, tonumber(comision) or 0, tonumber(cantidad) or 1
end

local function idDe(nombre)
	if type(nombre) ~= "string" or not M.BuscarPorNombre then return nil end
	local ok, id = pcall(M.BuscarPorNombre, nombre)
	return ok and id or nil
end

-- Se llama al tomar el dinero o el objeto de la carta i.
function M.RevisarCarta(i)
	if type(i) ~= "number" then return end
	local tipo, objeto, puja, comision, cantidad = factura(i)
	if not tipo then return end
	local firma = tostring(tipo) .. "|" .. tostring(objeto) .. "|" .. tostring(puja) .. "|" .. tostring(cantidad) .. "|" .. tostring(i)
	if vistas[firma] then return end
	vistas[firma] = true
	if tipo == "seller" then
		M.AnotarMovimiento("v", objeto, cantidad, puja - comision, idDe(objeto))
	elseif tipo == "buyer" then
		M.AnotarMovimiento("c", objeto, cantidad, puja, idDe(objeto))
	end
end

local function antesDe(nombre)
	if type(rawget(_G, nombre)) ~= "function" or type(hooksecurefunc) ~= "function" then return end
	-- hooksecurefunc no ensucia lo del juego; corre justo después de la llamada,
	-- cuando la carta sigue en el buzón (el servidor la quita después).
	hooksecurefunc(nombre, function(i) pcall(M.RevisarCarta, i) end)
end
antesDe("TakeInboxMoney")
antesDe("TakeInboxItem")
antesDe("AutoLootMailItem")
-- 1.4.0 (revisión): la firma lleva el número de la carta, que cambia cuando el
-- servidor quita una: al cambiar cuántas cartas hay, las firmas se olvidan.
-- Así dos ventas iguales tomadas desde arriba (las dos en la carta 1) se
-- anotan las dos, y dos clics seguidos en la misma carta, una sola vez.
local cuantas
local function cuentaCartas()
	local f = rawget(_G, "GetInboxNumItems")
	if type(f) ~= "function" then return nil end
	local ok, n = pcall(f)
	n = ok and leer(n) or nil
	return type(n) == "number" and n or nil
end
M.CuentaCartas = cuentaCartas
A.RegisterEvent("MAIL_SHOW", function() vistas = {}; cuantas = cuentaCartas() end)
A.RegisterEvent("MAIL_INBOX_UPDATE", function()
	local n = cuentaCartas()
	if n ~= cuantas then vistas = {} end
	cuantas = n
end)

---------------------------------------------------------------------------
-- /alfa comercio semana
---------------------------------------------------------------------------
function M.ImprimirSemana()
	local s = M.Semana(7)
	if #s.lista == 0 then
		N.Imprimir(L["Esta semana no anoté ventas ni compras de la subasta. Se anotan al tomar sus cartas del buzón."])
		return
	end
	N.Imprimir(format(L["Tu semana en la subasta: vendiste %s, compraste %s; te quedan %s."], M.Dinero(s.vendido), M.Dinero(s.comprado),
		(s.neto < 0 and "-" or "") .. M.Dinero(math.abs(s.neto))))
	for i = 1, math.min(15, #s.lista) do
		local m = s.lista[i]
		N.Imprimir(format("%s %s ×%d · %s", m.k == "v" and L["Vendiste"] or L["Compraste"], m.n or "?", m.q or 1, M.Dinero(m.c or 0)))
	end
end
