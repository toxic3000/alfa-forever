-- Alfa - Comercio: precios de la subasta (toxic3000 / La Jauría). GPL-3.0.
--
-- Guarda, por reino y facción, el precio mínimo por unidad de cada objeto en
-- la casa de subastas, con su fecha y un historial corto (un precio por día,
-- 14 días). Los precios son solo de Alfa y llegan de dos lados:
--   * el escaneo completo (Subasta.lua: C_AuctionHouse.ReplicateItems),
--   * lo que el jugador ya busca a mano (eventos de resultados de búsqueda).
-- También anota lo que cuesta comprar cada objeto a un comerciante (al abrir
-- su ventana), para el costo de los reactivos de las recetas.
--
-- API verificada en referencia/.../Blizzard_APIDocumentationGenerated:
--   AuctionHouseDocumentation.lua: GetNumCommoditySearchResults,
--   GetCommoditySearchResultInfo (unitPrice), GetCommoditySearchResultsQuantity,
--   GetNumItemSearchResults, GetItemSearchResultInfo (buyoutAmount, quantity),
--   GetBrowseResults (BrowseResultInfo.minPrice, totalQuantity, itemKey) y los
--   eventos COMMODITY_SEARCH_RESULTS_UPDATED/ADDED, ITEM_SEARCH_RESULTS_UPDATED/
--   ADDED, AUCTION_HOUSE_BROWSE_RESULTS_UPDATED/ADDED.
--   MerchantFrameDocumentation.lua: C_MerchantFrame.GetItemInfo, MERCHANT_SHOW.
--   GetMerchantNumItems / GetMerchantItemID: globales clásicas que el motor ya
--   usa (Alfa/QoL/Buy.lua).

local _, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L

local type, pairs, floor, tonumber, tostring = type, pairs, math.floor, tonumber, tostring
local DIA = 86400
local HISTORIA = 14

M.ID = "comercio"

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------

function M.Ahora()
	local C = A.Compat
	if C and C.Now then
		local t = C.Now()
		if type(t) == "number" then return t end
	end
	return time and time() or 0
end

function M.Ajuste(clave) return N.Get(M.ID, clave) end

-- 1.3.7: N.Reino recuerda tu reino cuando el juego lo da vacío (Nucleo.lua).
-- -> el reino ("?" si no se sabe), seguro (del juego o de este personaje)
local function nombreReino()
	local r, seguro
	if N.Reino then r, seguro = N.Reino() else r, seguro = GetRealmName and GetRealmName(), true end
	if type(r) ~= "string" or r == "" then return "?", false end
	return r, seguro
end

-- "Reino-Facción": cada casa de subastas tiene sus precios.
function M.ClaveReino()
	local C = A.Compat
	local f = C and C.GetPlayerFaction and C.GetPlayerFaction() or "Neutral"
	if type(f) ~= "string" then f = "Neutral" end
	return (nombreReino()) .. "-" .. f
end

function M.NombrePersonaje()
	local n = UnitName and UnitName("player")
	if type(n) ~= "string" or n == "" then n = "?" end
	return n
end

function M.ClavePersonaje()
	return M.NombrePersonaje() .. "-" .. (nombreReino())
end

-- "hace 5 min" / "hace 3 h" / "hace 2 d".
function M.Hace(t)
	if type(t) ~= "number" then return L["sin fecha"] end
	local s = M.Ahora() - t
	if s < 60 then return L["hace un momento"] end
	if s < 3600 then return L["hace %d min"]:format(floor(s / 60)) end
	if s < 2 * DIA then return L["hace %d h"]:format(floor(s / 3600)) end
	return L["hace %d d"]:format(floor(s / DIA))
end

-- "+700%" / "-20%".
function M.Porcentaje(f)
	if type(f) ~= "number" then return "" end
	local p = floor(f * 100 + 0.5)
	return (p > 0 and "+" or "") .. p .. "%"
end

function M.Dinero(cobre) return N.Dinero(cobre or 0) end

-- Avisar a la página y a la barra de la subasta que algo cambió.
local avisoPendiente = false
function M.Cambio()
	M.version = (M.version or 0) + 1
	if avisoPendiente then return end
	avisoPendiente = true
	local function avisar()
		avisoPendiente = false
		A.Fire("ALFA_COMERCIO")
	end
	-- 1.3.7: con el reloj de Alfa (N.Una), no un C_Timer suelto.
	if N.Una then N.Una("comercio.cambio", 0.2, avisar) else avisar() end
end

---------------------------------------------------------------------------
-- Tareas por lotes: el trabajo largo (escaneo completo, recetas) corre en
-- una corrutina que cede el cuadro al pasar su presupuesto de tiempo, así el
-- juego no se congela.
---------------------------------------------------------------------------

local PRESUPUESTO_MS = 8
local tareas = {}
local motor = CreateFrame("Frame")
motor:Hide()
local reloj = type(debugprofilestop) == "function" and debugprofilestop or nil
local inicio, pasos = 0, 0

-- Llamar dentro de una tarea cada tanto: cede si ya se usó el cuadro.
function M.Ceder()
	pasos = pasos + 1
	if reloj then
		if reloj() - inicio < PRESUPUESTO_MS then return end
	elseif pasos < 400 then
		return
	end
	coroutine.yield()
end

local function correr()
	local t = tareas[1]
	if not t then
		motor:Hide()
		return
	end
	-- 1.3.7: el escaneo de la subasta y la lectura de recetas esperan a que
	-- termine el combate (siguen donde iban).
	if InCombatLockdown and InCombatLockdown() then return end
	inicio, pasos = reloj and reloj() or 0, 0
	local ok, err = coroutine.resume(t.co)
	if not ok then
		table.remove(tareas, 1)
		if t.alFallar then pcall(t.alFallar, err) end
		if geterrorhandler then geterrorhandler()(err) end
	elseif coroutine.status(t.co) == "dead" then
		table.remove(tareas, 1)
	end
	if #tareas == 0 then motor:Hide() end
end
motor:SetScript("OnUpdate", correr)
M.motorTareas = motor -- para las pruebas

-- nombre: una sola tarea con ese nombre a la vez (la nueva reemplaza a la que
-- aún no empieza). -> true si quedó en cola.
function M.Tarea(nombre, fn, alFallar)
	for i = 2, #tareas do
		if tareas[i].nombre == nombre then table.remove(tareas, i) break end
	end
	if tareas[1] and tareas[1].nombre == nombre then return false end
	tareas[#tareas + 1] = { nombre = nombre, co = coroutine.create(fn), alFallar = alFallar }
	motor:Show()
	return true
end

function M.Ocupado(nombre)
	for i = 1, #tareas do
		if tareas[i].nombre == nombre then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Datos guardados
--   N.Datos("comercio") = {
--     reinos = { ["Reino-Facción"] = {
--       p = { [itemID] = { precio, fecha, cantidad, fuente } },   -- fuente 1 escaneo, 2 búsqueda
--       h = { [itemID] = "día:precio,día:precio" },             -- historial corto
--       escaneo = { fecha, objetos, subastas },                  -- último escaneo completo
--       pedido = fecha,                                          -- última petición de escaneo
--     } },
--     comprar = { [itemID] = precio por unidad con el comerciante },
--     recetas, encantar  (Recetas.lua)
--   }
---------------------------------------------------------------------------

function M.Datos()
	local d = N.Datos(M.ID)
	d.reinos = type(d.reinos) == "table" and d.reinos or {}
	d.comprar = type(d.comprar) == "table" and d.comprar or {}
	return d
end

function M.Reino(clave)
	local d = M.Datos()
	clave = clave or M.ClaveReino()
	local r = d.reinos[clave]
	if type(r) ~= "table" then
		r = {}
		d.reinos[clave] = r
	end
	r.p = type(r.p) == "table" and r.p or {}
	r.h = type(r.h) == "table" and r.h or {}
	return r
end

-- Agrega el precio del día al historial (el mínimo del día).
function M.Historia(r, id, precio, fecha)
	local dia = floor(fecha / DIA)
	local s = r.h[id]
	local lista = {}
	if type(s) == "string" then
		for d, p in s:gmatch("(%d+):(%d+)") do lista[#lista + 1] = { tonumber(d), tonumber(p) } end
	end
	local ultimo = lista[#lista]
	if ultimo and ultimo[1] == dia then
		if precio < ultimo[2] then ultimo[2] = precio end
	else
		lista[#lista + 1] = { dia, precio }
	end
	local desde = math.max(1, #lista - HISTORIA + 1)
	local partes = {}
	for i = desde, #lista do partes[#partes + 1] = lista[i][1] .. ":" .. lista[i][2] end
	r.h[id] = table.concat(partes, ",")
end

-- Tendencia: el último precio contra el promedio de los anteriores.
-- -> fracción (+0.12 = sube 12 %) o nil sin historia suficiente.
function M.Tendencia(id)
	local r = M.Reino()
	local s = r.h[id]
	if type(s) ~= "string" then return nil end
	local lista = {}
	for _, p in s:gmatch("(%d+):(%d+)") do lista[#lista + 1] = tonumber(p) end
	if #lista < 2 then return nil end
	local suma = 0
	for i = 1, #lista - 1 do suma = suma + lista[i] end
	local prom = suma / (#lista - 1)
	if prom <= 0 then return nil end
	return (lista[#lista] - prom) / prom
end

-- Guarda un precio visto (por unidad, en cobre).
function M.Anotar(id, precio, cantidad, fuente, fecha, r)
	if type(id) ~= "number" or type(precio) ~= "number" or precio <= 0 then return end
	r = r or M.Reino()
	fecha = fecha or M.Ahora()
	precio = floor(precio)
	r.p[id] = { precio, fecha, type(cantidad) == "number" and cantidad or 0, fuente or 2 }
	M.Historia(r, id, precio, fecha)
end

-- Lo viejo se olvida (1.2.0): un precio de hace más de PODAR_DIAS días ya no
-- dice nada, y sin podar los datos guardados crecían para siempre (más lento
-- al entrar y al salir del juego). Un reino sin nada reciente se borra.
local PODAR_DIAS = 60
-- 1.4.0: tope a la historia. Cada punto de la historia vale HISTORIA_DIAS
-- días (la tendencia compara lo de ahora con lo reciente), y un reino guarda a
-- lo más TOPE_OBJETOS objetos: si pasa, se van los vistos hace más tiempo.
local HISTORIA_DIAS = 30
local TOPE_OBJETOS = 8000
M.TOPE_OBJETOS, M.HISTORIA_DIAS = TOPE_OBJETOS, HISTORIA_DIAS

local function historiaReciente(s, desdeDia)
	if type(s) ~= "string" then return nil end
	local partes = {}
	for dia, precio in s:gmatch("(%d+):(%d+)") do
		if tonumber(dia) >= desdeDia then partes[#partes + 1] = dia .. ":" .. precio end
	end
	return #partes > 0 and table.concat(partes, ",") or nil
end

function M.Podar(ahora)
	local d = M.Datos()
	ahora = ahora or M.Ahora()
	local limite = ahora - PODAR_DIAS * DIA
	local desdeDia = floor((ahora - HISTORIA_DIAS * DIA) / DIA)
	local quitados = 0
	for clave, r in pairs(d.reinos) do
		if type(r) ~= "table" then
			d.reinos[clave] = nil
		else
			local quedan = 0
			local vivos = {}
			for id, e in pairs(type(r.p) == "table" and r.p or {}) do
				local fecha = type(e) == "table" and tonumber(e[2]) or nil
				if not fecha or fecha < limite then
					r.p[id] = nil
					if type(r.h) == "table" then r.h[id] = nil end
					quitados = quitados + 1
				else
					quedan = quedan + 1
					vivos[#vivos + 1] = { id, fecha }
				end
			end
			if type(r.h) == "table" then
				for id, s in pairs(r.h) do
					local nueva = type(r.p) == "table" and r.p[id] ~= nil and historiaReciente(s, desdeDia) or nil
					if nueva ~= s then r.h[id] = nueva end
				end
			end
			if quedan > TOPE_OBJETOS then
				table.sort(vivos, function(a, b) return a[2] > b[2] end)
				for i = TOPE_OBJETOS + 1, #vivos do
					local id = vivos[i][1]
					r.p[id] = nil
					if type(r.h) == "table" then r.h[id] = nil end
					quitados = quitados + 1
				end
				quedan = TOPE_OBJETOS
			end
			if quedan == 0 and not (type(r.pedido) == "number" and r.pedido >= limite) then d.reinos[clave] = nil end
		end
	end
	return quitados
end
-- 1.3.7: lo que se guardó con el reino vacío («?-Alliance», «Toxic-?»: el
-- juego dio GetRealmName() vacío desde el 20/11/2026) vuelve a tu reino de
-- verdad en cuanto Alfa lo sabe (N.Reino): precios (el más nuevo gana), su
-- historial (el mínimo de cada día), el último escaneo, tus recetas y tu
-- Encantamiento. -> cuántas cosas se mudaron
local function juntarHistoria(a, b)
	local dias = {}
	for _, s in ipairs({ a, b }) do
		if type(s) == "string" then
			for dia, precio in s:gmatch("(%d+):(%d+)") do
				dia, precio = tonumber(dia), tonumber(precio)
				if not dias[dia] or precio < dias[dia] then dias[dia] = precio end
			end
		end
	end
	local orden = {}
	for dia in pairs(dias) do orden[#orden + 1] = dia end
	table.sort(orden)
	local partes = {}
	for i = math.max(1, #orden - HISTORIA + 1), #orden do partes[#partes + 1] = orden[i] .. ":" .. dias[orden[i]] end
	return #partes > 0 and table.concat(partes, ",") or nil
end
-- Solo con el reino seguro de este personaje (N.Reino: del juego o de lo que
-- el juego le dio antes), y solo lo suyo: sus recetas «Nombre-?» y los
-- precios «?-SuFacción». Las recetas se juntan receta por receta (nada se tira).
local function juntarFicha(f, otra)
	if type(otra) ~= "table" then return f end
	-- otra (la que ya tenía reino) queda de base; lo de «?» es lo más nuevo
	for campo, v in pairs(f) do
		if campo ~= "r" and campo ~= "profs" and campo ~= "s" and v ~= nil then otra[campo] = v end
	end
	if type(f.r) == "table" then
		otra.r = type(otra.r) == "table" and otra.r or {}
		for rid, rec in pairs(f.r) do otra.r[rid] = rec end
	end
	if type(f.profs) == "table" then
		otra.profs = type(otra.profs) == "table" and otra.profs or {}
		for prof, nivel in pairs(f.profs) do
			if type(nivel) ~= "number" or nivel >= (tonumber(otra.profs[prof]) or 0) then otra.profs[prof] = nivel end
		end
	end
	if type(f.s) == "number" and f.s > (tonumber(otra.s) or 0) then otra.s = f.s end
	return otra
end

function M.JuntarReinoSinNombre()
	local real, seguro = nombreReino()
	if real == "?" then return 0 end
	local d = M.Datos()
	local n = 0
	local C = A.Compat
	local miFaccion = C and C.GetPlayerFaction and C.GetPlayerFaction()
	-- 1.4.0: con el reino supuesto (el juego lo sigue dando vacío) también,
	-- pero solo los precios y solo si en la cuenta no hay otro reino de tu
	-- facción: así «?-Facción» no puede ser de otro reino. Las recetas
	-- esperan a saberlo seguro.
	if not seguro then
		if type(miFaccion) ~= "string" then return 0 end
		for clave in pairs(d.reinos) do
			local reino, f
			if type(clave) == "string" then reino, f = clave:match("^(.+)%-([^%-]+)$") end
			if f == miFaccion and reino ~= "?" and reino ~= real then return 0 end
		end
	end
	-- (primero las claves: agregar a una tabla mientras se recorre no se vale)
	local sueltos = {}
	for clave in pairs(d.reinos) do sueltos[#sueltos + 1] = clave end
	for _, clave in ipairs(sueltos) do
		local r = d.reinos[clave]
		local faccion = type(clave) == "string" and clave:match("^%?%-(.+)$")
		if faccion and faccion == miFaccion and type(r) == "table" then
			local dest = M.Reino(real .. "-" .. faccion)
			for id, e in pairs(type(r.p) == "table" and r.p or {}) do
				local otro = dest.p[id]
				if type(e) == "table" and (type(otro) ~= "table" or (tonumber(e[2]) or 0) > (tonumber(otro[2]) or 0)) then
					dest.p[id] = e
				end
				n = n + 1
			end
			for id, s in pairs(type(r.h) == "table" and r.h or {}) do dest.h[id] = juntarHistoria(dest.h[id], s) end
			local ea, eb = r.escaneo, dest.escaneo
			if type(ea) == "table" and (type(eb) ~= "table" or (tonumber(ea[1]) or 0) > (tonumber(eb[1]) or 0)) then dest.escaneo = ea end
			if type(r.pedido) == "number" and r.pedido > (tonumber(dest.pedido) or 0) then dest.pedido = r.pedido end
			d.reinos[clave] = nil
		end
	end
	-- Recetas y Encantamiento: solo «TuNombre-?» pasa a «TuNombre-Reino»
	-- (las de tus otros personajes esperan a que ellos entren).
	local yo = M.NombrePersonaje()
	if yo ~= "?" and seguro then
		local clave, nueva = yo .. "-?", yo .. "-" .. real
		for _, campo in ipairs({ "recetas", "encantar" }) do
			local t = type(d[campo]) == "table" and d[campo] or nil
			local f = t and t[clave]
			if type(f) == "table" then
				if type(f.rk) == "string" then f.rk = f.rk:gsub("^%?%-", real .. "-") end
				t[nueva] = juntarFicha(f, t[nueva])
				t[clave] = nil
				n = n + 1
			end
		end
	end
	return n
end

A.OnLogin(function()
	pcall(M.JuntarReinoSinNombre)
	pcall(M.Podar)
end)

---------------------------------------------------------------------------
-- Lectura de precios
---------------------------------------------------------------------------

-- Precio de subasta por unidad (bruto), fecha, cantidad vista y fuente
-- ("alfa": el escaneo completo; "busqueda": lo que buscaste). nil si no hay.
function M.PrecioSubasta(id)
	if type(id) ~= "number" then return nil end
	local e = M.Reino().p[id]
	if type(e) == "table" and type(e[1]) == "number" then
		return e[1], e[2], e[3], e[4] == 1 and "alfa" or "busqueda"
	end
	return nil
end

-- Lo que te queda al vender en la subasta, por unidad (menos la comisión).
function M.Comision()
	local c = tonumber(M.Ajuste("comision")) or 5
	if c < 0 then c = 0 elseif c > 50 then c = 50 end
	return c / 100
end

function M.NetoSubasta(bruto)
	if type(bruto) ~= "number" then return nil end
	return floor(bruto * (1 - M.Comision()))
end

-- Lo que cuesta conseguir un objeto: el menor entre la subasta (bruto) y el
-- comerciante. nil si no se sabe.
function M.CostoCompra(id)
	local sub = M.PrecioSubasta(id)
	local com = M.Datos().comprar[id]
	if type(com) ~= "number" then com = nil end
	if sub and com then return math.min(sub, com) end
	return sub or com
end

-- Estado del último escaneo completo de este reino.
function M.Escaneo()
	local r = M.Reino()
	local e = r.escaneo
	if type(e) ~= "table" then return nil end
	return e[1], e[2], e[3]
end

function M.CuantosPrecios()
	local n = 0
	for _ in pairs(M.Reino().p) do n = n + 1 end
	return n
end

function M.Viejo(fecha)
	if type(fecha) ~= "number" then return true end
	local dias = tonumber(M.Ajuste("diasViejo")) or 3
	return M.Ahora() - fecha > dias * DIA
end

function M.Olvidar()
	local d = M.Datos()
	local k = M.ClaveReino()
	local v = d.reinos[k]
	-- La espera del escaneo completo (pedido, Subasta.lua) es del servidor: se
	-- queda, o el botón se encendería y la subasta no respondería.
	d.reinos[k] = (type(v) == "table" and type(v.pedido) == "number") and { pedido = v.pedido } or nil
	M.Cambio()
end

---------------------------------------------------------------------------
-- Lo que el jugador busca a mano en la subasta
---------------------------------------------------------------------------

local function aprende() return M.Ajuste("busquedas") and not M.Ocupado("escaneo") end

local function deCommodity(_, itemID)
	if not aprende() or type(itemID) ~= "number" then return end
	local AH = C_AuctionHouse
	if not (AH and AH.GetNumCommoditySearchResults and AH.GetCommoditySearchResultInfo) then return end
	local n = AH.GetNumCommoditySearchResults(itemID)
	if type(n) ~= "number" or n <= 0 then return end
	local minimo
	for i = 1, math.min(n, 10) do
		local r = AH.GetCommoditySearchResultInfo(itemID, i)
		local u = type(r) == "table" and r.unitPrice
		if type(u) == "number" and u > 0 and (not minimo or u < minimo) then minimo = u end
	end
	if not minimo then return end
	local total = AH.GetCommoditySearchResultsQuantity and AH.GetCommoditySearchResultsQuantity(itemID)
	M.Anotar(itemID, minimo, total, 2)
	M.Cambio()
end

local function deObjeto(_, itemKey)
	if not aprende() or type(itemKey) ~= "table" then return end
	local id = itemKey.itemID
	local AH = C_AuctionHouse
	if type(id) ~= "number" or not (AH and AH.GetNumItemSearchResults and AH.GetItemSearchResultInfo) then return end
	local n = AH.GetNumItemSearchResults(itemKey)
	if type(n) ~= "number" or n <= 0 then return end
	local minimo, total = nil, 0
	for i = 1, math.min(n, 50) do
		local r = AH.GetItemSearchResultInfo(itemKey, i)
		if type(r) == "table" then
			local b, q = r.buyoutAmount, r.quantity
			if type(q) ~= "number" or q < 1 then q = 1 end
			total = total + q
			if type(b) == "number" and b > 0 then
				local u = b / q
				if not minimo or u < minimo then minimo = u end
			end
		end
	end
	if not minimo then return end
	M.Anotar(id, minimo, total, 2)
	M.Cambio()
end

local function deLista(lista)
	if type(lista) ~= "table" then return end
	local minimo, total = {}, {}
	for i = 1, #lista do
		local r = lista[i]
		local key = type(r) == "table" and r.itemKey
		local id = type(key) == "table" and key.itemID
		local p = type(r) == "table" and r.minPrice
		if type(id) == "number" and type(p) == "number" and p > 0 then
			if not minimo[id] or p < minimo[id] then minimo[id] = p end
			total[id] = (total[id] or 0) + (type(r.totalQuantity) == "number" and r.totalQuantity or 0)
		end
	end
	local r = M.Reino()
	local ahora = M.Ahora()
	local alguno = false
	for id, p in pairs(minimo) do
		M.Anotar(id, p, total[id], 2, ahora, r)
		alguno = true
	end
	if alguno then M.Cambio() end
end

local function deNavegar(_, agregados)
	if not aprende() then return end
	if type(agregados) == "table" then return deLista(agregados) end
	local AH = C_AuctionHouse
	if AH and AH.GetBrowseResults then deLista(AH.GetBrowseResults()) end
end

A.RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", deCommodity)
A.RegisterEvent("COMMODITY_SEARCH_RESULTS_ADDED", deCommodity)
A.RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", deObjeto)
A.RegisterEvent("ITEM_SEARCH_RESULTS_ADDED", deObjeto)
A.RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function() deNavegar() end)
A.RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", deNavegar)

---------------------------------------------------------------------------
-- Precios de compra con el comerciante
---------------------------------------------------------------------------

local function leerComerciante()
	if not (GetMerchantNumItems and GetMerchantItemID) then return end
	local n = GetMerchantNumItems()
	if type(n) ~= "number" then return end
	local comprar = M.Datos().comprar
	local MF = C_MerchantFrame
	for i = 1, n do
		local id = GetMerchantItemID(i)
		local precio, pila, extra
		if MF and MF.GetItemInfo then
			local info = MF.GetItemInfo(i)
			if type(info) == "table" then precio, pila, extra = info.price, info.stackCount, info.hasExtendedCost end
		elseif GetMerchantItemInfo then
			local _, _, p, s, _, _, _, e = GetMerchantItemInfo(i)
			precio, pila, extra = p, s, e
		end
		if type(id) == "number" and type(precio) == "number" and precio > 0 and not extra then
			if type(pila) ~= "number" or pila < 1 then pila = 1 end
			comprar[id] = floor(precio / pila + 0.5)
		end
	end
end

A.RegisterEvent("MERCHANT_SHOW", function()
	if N.Una then N.Una("comercio.comerciante", 0.3, leerComerciante) else leerComerciante() end
end)
