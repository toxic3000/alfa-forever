-- Alfa - Bolsas: depositar rápido y comprar espacio en el banco. GPL-3.0.
--
-- Depositar: con el banco abierto, un clic en "Depositar" y una opción del
-- menú (lo que ya tienes en el banco, todos los materiales, una categoría o
-- todo lo que no sea equipo) arma la lista y la mueve por lotes (Lotes.lua)
-- con C_Container.UseContainerItem(bolsa, casilla, nil, banco, false), lo
-- mismo que hace el clic derecho del juego con el banco abierto
-- (Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua). Antes cuenta cuánto
-- cabe (casillas libres del banco y montones a medias), para no mandar lo que
-- no entra. Nunca con el banco cerrado ni en combate.
--
-- Comprar espacio: Forever vende casillas de bolsa del banco, una tras otra
-- (C_Bank.FetchNextPurchasableBankTabData: costo y si te alcanza;
-- C_Bank.PurchaseBankTab: la compra, restringida a Blizzard). Alfa muestra el
-- costo y, al pedir comprar, vuelve a mostrar el banco del juego para que su
-- botón haga la compra (Camelot/BankFrame.lua, CONFIRM_BUY_BANK_TAB).

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D, O = M.Datos, M.Objetos
local K = N.Kit

local type, pairs, ipairs, tonumber, format = type, pairs, ipairs, tonumber, string.format

local Banco = {}
M.Banco = Banco

local PIEDRA_HOGAR = 6948
local ORIGEN = { 0, 1, 2, 3, 4, 5 } -- de dónde se deposita (sin el llavero)

---------------------------------------------------------------------------
-- Qué se deposita con cada opción
---------------------------------------------------------------------------

Banco.OPCIONES = {
	{ clave = "banco", texto = L["Lo que ya tienes en el banco"] },
	{ clave = "materiales", texto = L["Todos los materiales"] },
	{ clave = "noEquipo", texto = L["Todo lo que no sea equipo"] },
	{ clave = "categoria", texto = L["Una categoría…"] },
}

local function enBanco()
	local r = D.Actual()
	local ids = {}
	if not (r and type(r.banco) == "table") then return ids end
	for _, t in pairs(r.banco) do
		if type(t) == "table" then
			for s = 1, tonumber(t.n) or 0 do
				local e = t[s]
				if type(e) == "table" and type(e.i) == "number" then ids[e.i] = true end
			end
		end
	end
	return ids
end

local function guardaLaGuia(id)
	local Q = A.QoL
	local kept = Q and Q.Kept
	return type(kept) == "function" and M.Leer(M.Llamar(kept, id)) ~= nil
end

-- Lo que llevas (bolsas 0 a 5): -> { { bolsa, casilla, id, cantidad, e, rec, cat }, ... }
local function lo_que_llevas()
	local C = C_Container
	local out = {}
	if not C then return out end
	for _, bolsa in ipairs(ORIGEN) do
		for s = 1, M.Num(M.Llamar(C.GetContainerNumSlots, bolsa)) or 0 do
			local info = M.Llamar(C.GetContainerItemInfo, bolsa, s)
			local id = type(info) == "table" and M.Num(info.itemID)
			if id then
				local rec = { i = id, q = M.Num(info.quality), l = M.Texto(info.hyperlink), c = M.Num(info.stackCount) or 1,
					sinValor = M.Leer(info.hasNoValue) and true or false }
				local q = M.Llamar(C.GetContainerItemQuestInfo, bolsa, s)
				if type(q) == "table" then rec.mision = (M.Leer(q.isQuestItem) or M.Num(q.questID)) and true or false end
				local e = O.Info(id, rec.l)
				out[#out + 1] = { bolsa = bolsa, casilla = s, id = id, cantidad = rec.c, e = e, rec = rec,
					cat = O.CategoriaFija(rec, e, bolsa) }
			end
		end
	end
	return out
end

-- ¿Entra esta casilla en la opción?
local function entra(clave, x, ids, cat)
	if x.id == PIEDRA_HOGAR or guardaLaGuia(x.id) then return false end
	if clave == "banco" then return ids[x.id] == true end
	if clave == "categoria" then return cat ~= nil and x.cat == cat end
	if x.rec.mision or x.cat == "misiones" then return false end
	if clave == "materiales" then return O.EsMaterial(x.e) end
	if clave == "noEquipo" then return not O.EsEquipo(x.e) end
	return false
end

-- Cuánto cabe en el banco: casillas libres para cualquier objeto y lo que
-- falta a cada montón a medias. -> libres, huecos { [id] = unidades }
local function espacioDelBanco()
	local C = C_Container
	local CI = C_Item
	local libres, huecos = 0, {}
	if not (C and D.BancoAbierto()) then return 0, huecos end
	for _, bolsa in ipairs(D.BANCO) do
		local n = M.Num(M.Llamar(C.GetContainerNumSlots, bolsa)) or 0
		if n > 0 then
			local f, familia = M.Llamar(C.GetContainerNumFreeSlots, bolsa)
			f, familia = M.Num(f) or 0, M.Num(familia) or 0
			if familia == 0 then libres = libres + f end
			for s = 1, n do
				local info = M.Llamar(C.GetContainerItemInfo, bolsa, s)
				local id = type(info) == "table" and M.Num(info.itemID)
				if id then
					local tope = CI and M.Num(M.Llamar(CI.GetItemMaxStackSizeByID, id)) or 1
					local c = M.Num(info.stackCount) or 1
					if tope and tope > c then huecos[id] = (huecos[id] or 0) + (tope - c) end
				end
			end
		end
	end
	return libres, huecos
end

-- El plan de una opción: -> { lista = { { bolsa, casilla, id }, ... }, total, noCaben }
function Banco.Plan(clave, cat)
	local ids = clave == "banco" and enBanco() or {}
	local libres, huecos = espacioDelBanco()
	local CI = C_Item
	local lista, noCaben, total = {}, 0, 0
	for _, x in ipairs(lo_que_llevas()) do
		if entra(clave, x, ids, cat) then
			total = total + 1
			local hueco = huecos[x.id] or 0
			if hueco >= x.cantidad then
				huecos[x.id] = hueco - x.cantidad
				lista[#lista + 1] = { x.bolsa, x.casilla, x.id }
			elseif libres > 0 then
				libres = libres - 1
				local tope = CI and M.Num(M.Llamar(CI.GetItemMaxStackSizeByID, x.id)) or 1
				huecos[x.id] = math.max(0, (tope or 1) - (x.cantidad - hueco))
				lista[#lista + 1] = { x.bolsa, x.casilla, x.id }
			else
				noCaben = noCaben + 1
			end
		end
	end
	return { lista = lista, total = total, noCaben = noCaben }
end

-- Cuántas casillas mueve cada opción y cada categoría (para el menú).
-- -> { [clave] = n }, { { clave = cat, nombre, n }, ... }
function Banco.Cuentas()
	local ids = enBanco()
	local cuentas = { banco = 0, materiales = 0, noEquipo = 0, categoria = 0 }
	local porCat = {}
	for _, x in ipairs(lo_que_llevas()) do
		for _, o in ipairs({ "banco", "materiales", "noEquipo" }) do
			if entra(o, x, ids) then cuentas[o] = cuentas[o] + 1 end
		end
		if x.id ~= PIEDRA_HOGAR and not guardaLaGuia(x.id) then porCat[x.cat] = (porCat[x.cat] or 0) + 1 end
	end
	local cats = {}
	for _, c in ipairs(O.CATEGORIAS) do
		local n = porCat[c.clave]
		if n and n > 0 and c.clave ~= "recientes" and c.clave ~= "libre" then
			cats[#cats + 1] = { clave = c.clave, nombre = c.nombre, n = n }
			cuentas.categoria = cuentas.categoria + n
		end
	end
	return cuentas, cats
end

---------------------------------------------------------------------------
-- Depositar (tras el clic del jugador)
---------------------------------------------------------------------------

function Banco.Depositando() return M.Lotes.Activo("depositar") end

function Banco.Depositar(clave, cat)
	if M.Lotes.Activo("depositar") then
		M.Lotes.Cancelar("depositar")
		return
	end
	if not D.BancoAbierto() then
		N.Imprimir(L["Para depositar, habla con un banquero."])
		return
	end
	if M.EnCombate() then
		N.Imprimir(L["No se puede en combate."])
		return
	end
	if clave ~= "categoria" then M.Set("deposito", clave) end
	local plan = Banco.Plan(clave, cat)
	if plan.total == 0 then
		N.Imprimir(L["No llevas nada para depositar con esa opción."])
		return
	end
	if #plan.lista == 0 then
		N.Imprimir(L["El banco está lleno: compra otra casilla o pon una bolsa más grande en el banco."])
		return
	end
	local C = C_Container
	M.Lotes.Iniciar({
		nombre = "depositar", lista = plan.lista,
		puede = function()
			if not D.BancoAbierto() then return false, "cerrado" end
			return true
		end,
		mover = function(bolsa, casilla)
			C.UseContainerItem(bolsa, casilla, nil, D.TIPO_BANCO, false)
		end,
		alTerminar = function(hechos, total, corte)
			local faltan = total - hechos
			if corte == "combate" then
				N.Imprimir(format(L["Se detuvo al entrar en combate: guardaste %d y faltaron %d."], hechos, faltan))
			elseif corte == "cerrado" then
				N.Imprimir(format(L["Se detuvo al cerrar el banco: guardaste %d y faltaron %d."], hechos, faltan))
			elseif corte == "cancelado" then
				N.Imprimir(format(L["Depósito detenido: guardaste %d."], hechos))
			else
				N.Imprimir(format(hechos == 1 and L["Guardaste %d objeto en el banco."] or L["Guardaste %d objetos en el banco."], hechos))
			end
			if plan.noCaben > 0 then
				N.Imprimir(format(L["No cupieron %d: el banco está lleno. Compra otra casilla o pon una bolsa más grande."], plan.noCaben))
			end
		end,
	})
end

---------------------------------------------------------------------------
-- Comprar espacio
---------------------------------------------------------------------------

function Banco.Comprar()
	if M.EnCombate() then
		N.Imprimir(L["No se puede en combate."])
		return
	end
	if not D.BancoAbierto() then
		N.Imprimir(L["Para comprar espacio, habla con un banquero."])
		return
	end
	local c = D.Compra()
	if not c then
		N.Imprimir(L["Este banco no vende más espacio."])
		return
	end
	if c.completo then
		N.Imprimir(L["Tu banco ya tiene todas sus casillas."])
		return
	end
	local costo = c.costo or 0
	if c.alcanza == false then
		N.Imprimir(format(L["La siguiente casilla cuesta %s y no te alcanza todavía."], N.Dinero(costo)))
		return
	end
	-- C_Bank.PurchaseBankTab es restringida (HasRestrictions): un addon no
	-- puede llamarla, y su diálogo abierto desde aquí quedaría contaminado.
	-- La compra la hace el botón del banco del juego: se vuelve a mostrar
	-- (sin cerrar la visita) y el jugador compra con él. Alfa no da nada por
	-- comprado: BANK_TABS_CHANGED vuelve a leer el estado (Datos.lua).
	local R = M.Reemplazo
	if R and R.SoltarBanco and R.SoltarBanco() then
		N.Imprimir(format(L["La siguiente casilla cuesta %s: cómprala con el botón del banco del juego, que ya está a la vista."], N.Dinero(costo)))
	else
		N.Imprimir(L["No se pudo mostrar el banco del juego para comprar la casilla."])
	end
end

-- Para la página y la ventana: cómo está el espacio del banco ahora.
-- -> { compradas, maximo, costo, alcanza, completo, vivo, fecha } | nil
function Banco.Estado()
	if D.BancoAbierto() then
		local c = D.Compra()
		if c then c.vivo = true return c end
	end
	return D.CompraGuardada()
end
