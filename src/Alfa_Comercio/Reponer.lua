-- Alfa - Comercio: «Siempre a la mano», reponer con un clic en el comerciante (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- El agua, las flechas, los venenos, el hilo o los frascos se compran una y
-- otra vez: Mayús+clic, escribir el número, aceptar, y otra vez con lo
-- siguiente. Con Alfa eliges lo que quieres llevar siempre y cuánto
-- («Agua refrescante: 40»); al hablar con un comerciante que lo vende, un
-- aviso dice lo que falta y lo que cuesta, y «Comprar» lo repone todo con un
-- clic. También ofrece lo que te falta de tu lista de compras (el hilo o el
-- fundente de una receta) si ese comerciante lo vende.
--
-- Cómo se llena la lista: si compras lo mismo en dos visitas distintas,
-- Alfa pregunta una vez «¿Siempre a la mano?»; en la página de Comercio
-- (sección «Siempre a la mano») cambias la cantidad o lo quitas; y con
-- /alfa comercio reponer <objeto> <cantidad>.
--
-- Nunca compra solo: la compra es tu clic en «Comprar», fuera de combate, en
-- la pestaña de comprar, con dinero (lo que pide otra moneda u objetos se
-- deja al juego) y sin pasar de lo que te alcanza ni de lo que tiene.
-- API (la de Pila.lua): GetMerchantNumItems, GetMerchantItemID(i),
-- C_MerchantFrame.GetItemInfo(i) | GetMerchantItemInfo(i),
-- GetMerchantItemMaxStack(i), BuyMerchantItem(i, n) (n: objetos).
-- Ajustes comercio.reponer y comercio.reponerLista (sí).
-- Por personaje: N.DatosPersonaje("comercio").reponer = { [id] = cantidad },
--   .reponerVistos = { [id] = { visitas, ultima } }, .reponerNo = { [id] = true }
--
--   Rp.Plan() -> { { i, id, nombre, objetos, costo, motivo = "siempre" | "lista" } }, costo
--   Rp.Comprar(plan) -> objetos, costo     Rp.Poner(id, n) / Rp.Quitar(id) / Rp.Lista()

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, ipairs, pairs, pcall, tonumber, floor, max, min, ceil, format, unpack =
	type, ipairs, pairs, pcall, tonumber, math.floor, math.max, math.min, math.ceil, string.format, unpack

local Rp = {}
M.Reponer = Rp

local MAX_CANTIDAD = 1000
-- Lo que se repone: consumibles (0), componentes (5), munición (6) y materiales de oficio (7).
local CLASES = { [0] = true, [5] = true, [6] = true, [7] = true }

local function on(k) return M.Ajuste(k) ~= false end
local function num(v) return N.LeerNumero and N.LeerNumero(v) or tonumber(N.Leer(v)) end

-- Todo lo que devuelve (GetItemInfo trae la clase en el 12.º lugar).
local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local r = { pcall(fn, ...) }
	if not r[1] then return nil end
	return unpack(r, 2, table.maxn(r))
end

local function datos()
	local d = N.DatosPersonaje(M.ID)
	d.reponer = type(d.reponer) == "table" and d.reponer or {}
	d.reponerVistos = type(d.reponerVistos) == "table" and d.reponerVistos or {}
	d.reponerNo = type(d.reponerNo) == "table" and d.reponerNo or {}
	return d
end

local function infoObjeto(id)
	local CI = rawget(_G, "C_Item")
	local f = (type(CI) == "table" and CI.GetItemInfo) or rawget(_G, "GetItemInfo")
	local nombre, link, _, _, _, _, _, monton, _, _, _, clase = llamar(f, id)
	return N.Leer(nombre), N.Leer(link), num(monton), num(clase)
end

local function nombreDe(id) return (infoObjeto(id)) or ("#" .. tostring(id)) end

---------------------------------------------------------------------------
-- Tu lista de «siempre a la mano»
---------------------------------------------------------------------------
function Rp.Poner(id, n)
	id, n = tonumber(id), floor(tonumber(n) or 0)
	if not id then return false end
	local d = datos()
	if n <= 0 then d.reponer[id] = nil else d.reponer[id] = min(n, MAX_CANTIDAD) end
	d.reponerNo[id] = nil
	M.Cambio()
	return true
end
function Rp.Quitar(id) return Rp.Poner(id, 0) end
function Rp.Cantidad(id) return datos().reponer[tonumber(id) or 0] end

-- -> { { id, nombre, quieres, tienes } } (por nombre)
function Rp.Lista()
	local out = {}
	for id, n in pairs(datos().reponer) do
		if type(id) == "number" and type(n) == "number" and n > 0 then
			out[#out + 1] = { id = id, nombre = nombreDe(id), quieres = n, tienes = M.EnBolsas(id) }
		end
	end
	table.sort(out, function(a, b) return tostring(a.nombre) < tostring(b.nombre) end)
	return out
end

---------------------------------------------------------------------------
-- Lo que vende este comerciante
---------------------------------------------------------------------------
-- -> nombre, precio por compra, objetos por compra, existencias (-1 sin límite), otra moneda
local function venta(i)
	local CM = rawget(_G, "C_MerchantFrame")
	if type(CM) == "table" and type(CM.GetItemInfo) == "function" then
		local info = llamar(CM.GetItemInfo, i)
		if type(info) ~= "table" then return nil end
		return N.Leer(info.name), num(info.price), num(info.stackCount), num(info.numAvailable), N.Si(info.hasExtendedCost)
	end
	local nombre, _, precio, porCompra, hay, _, _, otra = llamar(rawget(_G, "GetMerchantItemInfo"), i)
	return N.Leer(nombre), num(precio), num(porCompra), num(hay), N.Si(otra)
end

-- Cuántas compras (y objetos) para tener al menos `faltan`. -> objetos, costo, compras, porCompra
local function cuanto(i, faltan, dinero)
	local _, precio, porCompra, hay, otra = venta(i)
	if not precio or otra or faltan <= 0 then return 0, 0, 0, 1 end
	porCompra = max(1, porCompra or 1)
	local compras = ceil(faltan / porCompra)
	if hay and hay >= 0 then compras = min(compras, hay) end
	if precio > 0 and dinero then compras = min(compras, floor(dinero / precio)) end
	if compras <= 0 then return 0, 0, 0, porCompra end
	return compras * porCompra, compras * precio, compras, porCompra
end

local function abierto()
	local MF = rawget(_G, "MerchantFrame")
	return type(MF) == "table" and MF.IsShown and MF:IsShown() and true or false
end

-- Lo que falta y vende este comerciante.
function Rp.Plan()
	local n = num(llamar(rawget(_G, "GetMerchantNumItems"))) or 0
	if n <= 0 then return {}, 0 end
	local d = datos()
	local deLista = {}
	if on("reponerLista") and M.Lista and M.Lista.Materiales then
		local ok, mats = pcall(M.Lista.Materiales)
		for _, m in ipairs(ok and mats or {}) do
			if (m.faltan or 0) > 0 then deLista[m.id] = m.faltan end
		end
	end
	local plan, total = {}, 0
	local dinero = num(GetMoney and GetMoney()) or 0
	local puestos = {}
	for i = 1, min(n, 200) do
		local id = num(llamar(rawget(_G, "GetMerchantItemID"), i))
		if id and not puestos[id] then
			local quiero, motivo = 0, nil
			local siempre = d.reponer[id]
			if on("reponer") and type(siempre) == "number" and siempre > 0 then
				quiero, motivo = max(0, siempre - M.EnBolsas(id)), "siempre"
			end
			if (deLista[id] or 0) > quiero then quiero, motivo = deLista[id], "lista" end
			if quiero > 0 then
				local objetos, costo = cuanto(i, quiero, dinero - total)
				if objetos > 0 then
					puestos[id] = true
					total = total + costo
					plan[#plan + 1] = { i = i, id = id, nombre = (venta(i)) or nombreDe(id), objetos = objetos, costo = costo, motivo = motivo }
				end
			end
		end
	end
	return plan, total
end

local comprando = false

function Rp.Comprar(plan)
	if InCombatLockdown and InCombatLockdown() then
		N.Imprimir(L["En combate no se puede comprar: espera a que termine."])
		return 0, 0
	end
	local MF = rawget(_G, "MerchantFrame")
	if type(MF) == "table" and MF.selectedTab and MF.selectedTab ~= 1 then
		N.Imprimir(L["Vuelve a la pestaña de comprar del comerciante y prueba otra vez."])
		return 0, 0
	end
	local buy = rawget(_G, "BuyMerchantItem")
	if type(buy) ~= "function" then return 0, 0 end
	plan = plan or Rp.Plan()
	local objetos, costo, cosas = 0, 0, 0
	comprando = true
	for _, p in ipairs(plan) do
		-- Se vuelve a medir (el dinero y lo que tiene pueden haber cambiado).
		local dinero = num(GetMoney and GetMoney()) or 0
		local o, c, _, porCompra = cuanto(p.i, p.objetos, dinero)
		if o > 0 then
			local maxVez = num(llamar(rawget(_G, "GetMerchantItemMaxStack"), p.i)) or porCompra
			local por = maxVez >= porCompra and (maxVez - maxVez % porCompra) or porCompra
			local falta = o
			while falta > 0 do
				local k = min(falta, por)
				if not pcall(buy, p.i, k) then break end
				falta = falta - k
			end
			if falta < o then
				objetos, costo, cosas = objetos + (o - falta), costo + c, cosas + 1
			end
		end
	end
	comprando = false
	if cosas > 0 then
		N.Imprimir(format(L["Repuse %s por %s."], N.Plural(cosas, L["%d cosa"], L["%d cosas"]), N.Dinero(costo)))
	end
	return objetos, costo
end

---------------------------------------------------------------------------
-- El aviso al abrir el comerciante
---------------------------------------------------------------------------
local function textoPlan(plan)
	local partes = {}
	for k, p in ipairs(plan) do
		if k > 4 then
			partes[#partes + 1] = format(L["y %d más"], #plan - 4)
			break
		end
		partes[#partes + 1] = format("%s ×%d", tostring(p.nombre), p.objetos)
	end
	return table.concat(partes, ", ")
end

function Rp.Ofrecer()
	if not (on("reponer") or on("reponerLista")) then return nil end
	if InCombatLockdown and InCombatLockdown() then return nil end
	local plan, total = Rp.Plan()
	if #plan == 0 or not (K and K.Aviso) then return nil end
	local deLista = false
	for _, p in ipairs(plan) do if p.motivo == "lista" then deLista = true end end
	local o = {
		id = "comercio.reponer", icono = "ic-comercio", tono = "acento", duracion = 20, prioridad = "util",
		titulo = deLista and L["Este comerciante tiene lo que te falta"] or L["¿Reponemos lo de siempre?"],
		texto = textoPlan(plan) .. ": " .. N.Dinero(total) .. ".",
		donde = L["Comercio > Siempre a la mano"],
		acciones = { { texto = format(L["Comprar (%s)"], N.DineroTexto and N.DineroTexto(total, true) or N.Dinero(total)), alClic = function() Rp.Comprar() end } },
	}
	K.Aviso(o)
	return o
end

---------------------------------------------------------------------------
-- Aprender de lo que compras: lo mismo en dos visitas -> «¿Siempre a la mano?»
---------------------------------------------------------------------------
local visita = 0

function Rp.AlComprar(i, n)
	if comprando or not on("reponer") then return end
	local id = num(llamar(rawget(_G, "GetMerchantItemID"), i))
	if not id then return end
	local d = datos()
	if d.reponer[id] or d.reponerNo[id] then return end
	local _, _, _, clase = infoObjeto(id)
	if clase and not CLASES[clase] then return end
	local v = d.reponerVistos[id]
	if type(v) ~= "table" then v = { 0, 0 } d.reponerVistos[id] = v end
	if v[2] == visita then return end
	v[1], v[2] = (tonumber(v[1]) or 0) + 1, visita
	if v[1] < 2 then return end
	local cuantos = tonumber(n) or 1
	N.Una("comercio.reponerPreguntar", 0.6, function() Rp.Preguntar(id, cuantos) end)
end

function Rp.Preguntar(id, comprados)
	local d = datos()
	if d.reponer[id] or d.reponerNo[id] or not (K and K.Aviso) then return nil end
	d.reponerNo[id] = true -- se pregunta una sola vez
	local hasta = max(M.EnBolsas(id), tonumber(comprados) or 1, 1)
	local o = {
		id = "comercio.reponerPregunta", icono = "ic-comercio", tono = "acento", duracion = 15, prioridad = "util",
		titulo = L["¿Siempre a la mano?"],
		texto = format(L["Ya compraste %s en dos visitas. Si quieres, cada vez que un comerciante lo venda te ofrezco reponerlo hasta %d."], nombreDe(id), hasta),
		acciones = { { texto = format(L["Sí, hasta %d"], hasta), alClic = function() Rp.Poner(id, hasta) end } },
	}
	K.Aviso(o)
	return o
end

local envuelta
local function engancharCompra()
	local f = rawget(_G, "BuyMerchantItem")
	if type(f) ~= "function" or f == envuelta or not hooksecurefunc then return end
	hooksecurefunc("BuyMerchantItem", function(i, n) Rp.AlComprar(i, n) end)
	envuelta = rawget(_G, "BuyMerchantItem")
end
Rp.Enganchar = engancharCompra

A.RegisterEvent("MERCHANT_SHOW", function()
	visita = visita + 1
	engancharCompra()
	-- Después de que Precios.lua lee los precios (0,3 s).
	N.Una("comercio.reponer", 0.5, function() if abierto() then Rp.Ofrecer() end end)
end)

-- /alfa comercio reponer [<objeto> <cantidad> | quitar <objeto>]
function Rp.Comando(arg)
	arg = type(arg) == "string" and arg or ""
	local quitar = arg:match("^%s*quitar%s+(.+)$") or arg:match("^%s*remove%s+(.+)$")
	local cosa, n = (quitar or arg):match("^%s*(.-)%s+(%d+)%s*$")
	if quitar then cosa, n = quitar, nil end
	if not cosa then cosa = arg:match("^%s*(.-)%s*$") end
	if cosa == "" then
		local lista = Rp.Lista()
		if #lista == 0 then
			N.Imprimir(L["Aún no tienes nada «siempre a la mano». Uso: /alfa comercio reponer <objeto> <cantidad>"])
		else
			for _, e in ipairs(lista) do N.Imprimir(format(L["%s: %d (llevas %d)"], tostring(e.nombre), e.quieres, e.tienes)) end
		end
		return
	end
	local id = tonumber(cosa:match("item:(%d+)") or cosa)
	if not id and M.BuscarPorNombre then id = M.BuscarPorNombre(cosa) end
	if not id then
		N.Imprimir(L["Aún no conozco ese objeto. Pásale el ratón encima y vuelve a intentarlo."])
		return
	end
	if quitar then
		Rp.Quitar(id)
		N.Imprimir(format(L["%s ya no está en «Siempre a la mano»."], nombreDe(id)))
		return
	end
	n = tonumber(n) or 20
	Rp.Poner(id, n)
	N.Imprimir(format(L["Listo: Alfa te ofrecerá reponer %s hasta %d."], nombreDe(id), min(n, MAX_CANTIDAD)))
end
