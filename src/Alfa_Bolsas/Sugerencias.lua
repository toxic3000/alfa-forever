-- Alfa - Bolsas: qué vender, qué conservar o ir al comerciante cuando las
-- bolsas se empiezan a llenar. GPL-3.0.
--
-- Cuando quedan pocas casillas libres (ajuste avisoLibres) Alfa mira lo que
-- llevas y separa:
--   * vender: lo gris y lo que marcaste como chatarra (seguro), y lo que el
--     consejo de Comercio dice que solo sirve para el comerciante cuando no
--     hace falta (equipo que no es mejora, chatarra blanca, materiales que no
--     usa ninguna de tus recetas);
--   * conservar: lo que vale más en la subasta, desencantado o en una receta;
--   * nunca sugiere: misiones, consumibles, bolsas, llaves, la piedra de
--     hogar, lo que marcaste para conservar o lo que tu guía aún necesita.
-- Lo muestra en la ventana de bolsas y con un aviso del Kit, con acciones de
-- un clic: marcar como chatarra (Alfa.QoL.Marks: el motor la vende al abrir
-- un comerciante), llevarte al comerciante o al banco (la flecha del motor:
-- Alfa.Nav.nearby.Go) y, con el comerciante abierto, vender la chatarra
-- (por lotes, tras el clic: Lotes.lua, con la misma regla del motor,
-- Alfa.QoL.Vendor.JunkAt).
-- Con Alfa_Comercio usa su consejo y su valor (AlfaComercio.Consejo); sin
-- él, el precio del comerciante.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D, O = M.Datos, M.Objetos
local K = N.Kit

local type, pairs, ipairs, tonumber, format, floor, max, min = type, pairs, ipairs, tonumber, string.format, math.floor, math.max, math.min

local S = {}
M.Sugerencias = S

local PIEDRA_HOGAR = 6948
local ORIGEN = { 0, 1, 2, 3, 4, 5 }
local GENERALES = { 0, 1, 2, 3, 4 } -- las que cuentan como espacio libre
local CADA_AVISO = 10 * 60          -- un aviso como mucho cada 10 minutos

local function comercio()
	local C = AlfaComercio
	return type(C) == "table" and type(C.Consejo) == "function" and C or nil
end
S.Comercio = comercio

local function marcas()
	local Q = A.QoL
	return Q and type(Q.Marks) == "table" and Q.Marks or nil
end

local function precioVenta(id)
	local get = C_Item and C_Item.GetItemInfo
	if type(get) ~= "function" then return 0 end
	local ok, nombre, _, _, _, _, _, _, _, _, _, venta = pcall(get, id)
	if not ok or type(nombre) ~= "string" then return 0 end
	return M.Num(venta) or 0
end

local function esMejora(link)
	local G = A.Gear
	local Bg = G and G.Bags
	if not (Bg and Bg.IsUpgrade and type(link) == "string") then return false end
	return M.Leer(M.Llamar(Bg.IsUpgrade, link)) and true or false
end

local function guardaLaGuia(id)
	local Q = A.QoL
	local kept = Q and Q.Kept
	return type(kept) == "function" and M.Leer(M.Llamar(kept, id)) ~= nil
end

-- Espacio libre en las bolsas que aceptan cualquier objeto: -> libres, total
function S.Espacio()
	local C = C_Container
	local libres, total = 0, 0
	if not C then return 0, 0 end
	for _, bolsa in ipairs(GENERALES) do
		local n = M.Num(M.Llamar(C.GetContainerNumSlots, bolsa)) or 0
		if n > 0 then
			local f, familia = M.Llamar(C.GetContainerNumFreeSlots, bolsa)
			if (M.Num(familia) or 0) == 0 then
				libres = libres + (M.Num(f) or 0)
				total = total + n
			end
		end
	end
	return libres, total
end

---------------------------------------------------------------------------
-- El análisis (se rehace solo cuando cambian las bolsas, las marcas o los
-- precios)
---------------------------------------------------------------------------

local cache, sucio = nil, true
function S.Invalidar() sucio = true end

-- ¿Se puede sugerir venderlo aunque no sea chatarra? Solo cuando se sabe
-- que no vale más de otra forma: equipo que no es mejora (el verde, si está
-- ligado o la subasta lo paga menos), chatarra blanca y materiales que
-- ninguna receta tuya usa y que en la subasta valen menos (sin precio de la
-- subasta, un material no se sugiere: puede valer más).
local function vendible(e, q, link, c)
	if type(e) ~= "table" then return false end
	q = q or 1
	local cl, sub = e.clase, e.subclase
	if O.EsEquipo(e) then
		if esMejora(link) then return false end
		return q <= 1 or (q == 2 and c ~= nil and (c.ligado or c.subasta ~= nil))
	end
	if cl == 15 and sub == 0 then return q <= 1 end
	if cl == 7 then return c ~= nil and c.subasta ~= nil and not c.receta and q <= 1 end
	return false
end

local function analizar()
	local C = C_Container
	local Mk = marcas()
	local CM = comercio()
	local libres, total = S.Espacio()
	local grupos, orden = {}, {}
	if C then
		for _, bolsa in ipairs(ORIGEN) do
			for s = 1, M.Num(M.Llamar(C.GetContainerNumSlots, bolsa)) or 0 do
				local info = M.Llamar(C.GetContainerItemInfo, bolsa, s)
				local id = type(info) == "table" and M.Num(info.itemID)
				if id then
					local g = grupos[id]
					if not g then
						local mision = false
						local qi = M.Llamar(C.GetContainerItemQuestInfo, bolsa, s)
						if type(qi) == "table" then mision = (M.Leer(qi.isQuestItem) or M.Num(qi.questID)) and true or false end
						g = { id = id, cantidad = 0, casillas = 0, q = M.Num(info.quality), link = M.Texto(info.hyperlink),
							sinValor = M.Leer(info.hasNoValue) and true or false, mision = mision }
						grupos[id] = g
						orden[#orden + 1] = g
					end
					g.cantidad = g.cantidad + (M.Num(info.stackCount) or 1)
					g.casillas = g.casillas + 1
				end
			end
		end
	end
	local vender, conservar = {}, {}
	local valorVenta, casillasVenta, sinMarcar = 0, 0, 0
	for _, g in ipairs(orden) do
		local e = O.Info(g.id, g.link)
		g.nombre = e.nombre or (g.link and g.link:match("%[(.-)%]")) or ("#" .. g.id)
		-- 1.3.0: Mk.Get por M.Llamar (sin él, un motor sin Get dejaba vacía la sugerencia).
		local guardar = (Mk and (M.Llamar(Mk.Get, g.id) == "keep" or M.Leer(M.Llamar(Mk.Protected, g.id)))) or g.mision
			or e.clase == 12 or g.id == PIEDRA_HOGAR or guardaLaGuia(g.id)
		if not guardar then
			local basura = Mk and M.Leer(M.Llamar(Mk.Junk, g.id)) and true or false
			local venta = precioVenta(g.id)
			if (g.q == 0 or basura) and not g.sinValor and venta > 0 then
				g.chatarra, g.valor = true, venta * g.cantidad
				vender[#vender + 1] = g
			elseif not g.sinValor and venta > 0 then
				local c = CM and M.Llamar(CM.Consejo, g.id, { link = g.link }) or nil
				if type(c) == "table" and c.mejor ~= "vender" and c.mejor ~= "guardar" and (c.valor or 0) > 0 then
					g.valor = (c.valor or 0) * g.cantidad
					g.motivo = CM.TextoMejor and M.Llamar(CM.TextoMejor, c) or nil
					conservar[#conservar + 1] = g
				elseif vendible(e, g.q, g.link, type(c) == "table" and c or nil) and (CM == nil or type(c) ~= "table" or c.mejor == "vender") then
					g.valor = venta * g.cantidad
					vender[#vender + 1] = g
				end
			end
		end
	end
	table.sort(vender, function(a, b)
		if a.chatarra ~= b.chatarra then return a.chatarra and true or false end
		local va, vb = a.valor / max(1, a.casillas), b.valor / max(1, b.casillas)
		if va ~= vb then return va < vb end
		return tostring(a.nombre) < tostring(b.nombre)
	end)
	table.sort(conservar, function(a, b) return (a.valor or 0) > (b.valor or 0) end)
	for _, g in ipairs(vender) do
		valorVenta = valorVenta + g.valor
		casillasVenta = casillasVenta + g.casillas
		if not g.chatarra then sinMarcar = sinMarcar + 1 end
	end
	local umbral = M.Numero("avisoLibres", 0, 20)
	return {
		libres = libres, total = total, lleno = total > 0 and libres <= umbral,
		vender = vender, conservar = conservar, valorVenta = valorVenta, casillasVenta = casillasVenta,
		sinMarcar = sinMarcar, conComercio = CM ~= nil,
	}
end

function S.Estado()
	if sucio or not cache then
		local ok, r = pcall(analizar)
		if ok then cache = r else
			cache = { libres = 0, total = 0, lleno = false, vender = {}, conservar = {}, valorVenta = 0, casillasVenta = 0, sinMarcar = 0 }
			if geterrorhandler then geterrorhandler()(r) end
		end
		sucio = false
	end
	return cache
end

-- "Lino ×12, Garra rota ×3 y 2 más" (hasta `n` nombres).
function S.Nombres(lista, n)
	n = n or 3
	local partes = {}
	for i = 1, min(#lista, n) do
		local g = lista[i]
		partes[#partes + 1] = g.cantidad > 1 and format("%s \195\151%d", g.nombre, g.cantidad) or g.nombre
	end
	local texto = table.concat(partes, ", ")
	if #lista > n then texto = format(L["%s y %d más"], texto, #lista - n) end
	return texto
end

-- Las líneas del cuadro de información: una por objeto, con su valor.
function S.Lineas(lista, n)
	local out = {}
	for i = 1, min(#lista, n or 12) do
		local g = lista[i]
		local nombre = g.cantidad > 1 and format("%s \195\151%d", g.nombre, g.cantidad) or g.nombre
		local extra = g.motivo and ("  ·  " .. g.motivo) or ""
		out[#out + 1] = nombre .. "  ·  " .. N.Dinero(g.valor or 0, true) .. extra
	end
	if #lista > (n or 12) then out[#out + 1] = format(L["y %d más"], #lista - (n or 12)) end
	return out
end

---------------------------------------------------------------------------
-- Acciones (siempre tras un clic)
---------------------------------------------------------------------------

local comercianteAbierto = false
function S.ComercianteAbierto() return comercianteAbierto end

-- Marca como chatarra lo sugerido para vender que todavía no lo es.
function S.MarcarChatarra()
	local Mk = marcas()
	if not (Mk and Mk.Set) then
		N.Imprimir(L["No se pudo marcar: falta el motor de Alfa."])
		return 0
	end
	local est = S.Estado()
	local marcados = {}
	for _, g in ipairs(est.vender) do
		if not g.chatarra then
			M.Llamar(Mk.Set, g.id, "junk")
			marcados[#marcados + 1] = g
		end
	end
	S.Invalidar()
	if #marcados > 0 then
		local Q = A.QoL
		local vende = Q and Q.On and M.Leer(M.Llamar(Q.On, "sellJunk"))
		N.Imprimir(format(vende and L["Marcaste como chatarra: %s. Se vende sola al hablar con un comerciante."]
			or L["Marcaste como chatarra: %s. Véndela con «Vender la chatarra» en el comerciante."], S.Nombres(marcados, 6)))
	end
	M.Avisar("SUGERENCIAS")
	return #marcados
end

local function irA(clase)
	local Nav = A.Nav
	local cerca = Nav and Nav.nearby
	if not (cerca and cerca.Go) then
		N.Imprimir(L["No se pudo buscar el lugar más cercano."])
		return false
	end
	return M.Llamar(cerca.Go, clase) and true or false
end

function S.LlevarComerciante() return irA("vendor") end
function S.LlevarBanco() return irA("bank") end

-- La chatarra que se puede vender ahora (la regla del motor). -> lista, valor
local function chatarraAhora()
	local V = A.QoL and A.QoL.Vendor
	local junkAt = V and V.JunkAt
	local C = C_Container
	local lista, valor = {}, 0
	if type(junkAt) ~= "function" or not C then return lista, 0 end
	for _, bolsa in ipairs(ORIGEN) do
		for s = 1, M.Num(M.Llamar(C.GetContainerNumSlots, bolsa)) or 0 do
			local id, cantidad, precio = M.Llamar(junkAt, bolsa, s)
			id = M.Num(id)
			if id then
				-- 1.3.1: con su precio, para sumar al vender solo lo que de verdad se vendió.
				lista[#lista + 1] = { bolsa, s, id, precio = M.Num(precio) or 0 }
				valor = valor + (M.Num(cantidad) or 1) * (M.Num(precio) or 0)
			end
		end
	end
	return lista, valor
end
S.ChatarraAhora = chatarraAhora

function S.Vendiendo() return M.Lotes.Activo("vender") end

function S.VenderChatarra()
	if M.Lotes.Activo("vender") then
		M.Lotes.Cancelar("vender")
		return
	end
	if not comercianteAbierto then
		N.Imprimir(L["Para vender, habla con un comerciante."])
		return
	end
	local lista = chatarraAhora()
	if #lista == 0 then
		N.Imprimir(L["No llevas chatarra para vender."])
		return
	end
	local C = C_Container
	-- 1.3.1: lo que se vendió de verdad (antes decía el valor de toda la lista,
	-- aunque algo ya no estuviera: lo había vendido el motor al abrir).
	local vendido = 0
	M.Lotes.Iniciar({
		nombre = "vender", lista = lista,
		puede = function()
			if not comercianteAbierto then return false, "cerrado" end
			return true
		end,
		mover = function(bolsa, casilla, info, e)
			C.UseContainerItem(bolsa, casilla)
			vendido = vendido + (M.Num(type(info) == "table" and info.stackCount) or 1) * (type(e) == "table" and e.precio or 0)
		end,
		alTerminar = function(hechos, total, corte, saltados)
			if corte and corte ~= "cancelado" then
				N.Imprimir(format(L["La venta se detuvo: vendiste %d de %d."], hechos, total))
			elseif hechos > 0 then
				N.Imprimir(format(L["Vendiste %d objetos de chatarra por unos %s."], hechos, N.Dinero(vendido, true)))
			end
			if not corte and (saltados or 0) > 0 then N.Imprimir(M.Lotes.TextoSaltados(saltados)) end
			S.Invalidar()
			M.Avisar("SUGERENCIAS")
		end,
	})
end

---------------------------------------------------------------------------
-- El aviso del Kit (una vez al empezar a llenarse, no más de uno cada 10 min)
---------------------------------------------------------------------------

local estabaLleno, ultimoAviso, pendiente = false, 0, false

local function textoAviso(est)
	if #est.vender > 0 then
		return format(L["Quedan %d casillas libres. Puedes vender %s (unos %s)."], est.libres, S.Nombres(est.vender, 3),
			N.Dinero(est.valorVenta, true))
	end
	return format(L["Quedan %d casillas libres y no llevas nada que convenga vender: guarda algo en el banco."], est.libres)
end
S.TextoAviso = textoAviso

local function avisar(est)
	if not (K and K.Aviso) then return end
	local accion
	if #est.vender > 0 then
		accion = comercianteAbierto and { texto = L["Vender la chatarra"], alClic = S.VenderChatarra }
			or { texto = L["Llévame al comerciante"], alClic = S.LlevarComerciante }
	else
		accion = { texto = L["Llévame al banco"], alClic = S.LlevarBanco }
	end
	K.Aviso({ titulo = L["Tus bolsas se están llenando"], texto = textoAviso(est), icono = "ic-bolsas", tono = "aviso",
		duracion = 9, accion = accion })
end

---------------------------------------------------------------------------
-- 1.2.8: casi llenas (2 casillas libres o menos). Un aviso con lo primero
-- que conviene soltar (lo gris, luego lo que menos vale: la lista de
-- vender ya va en ese orden) y un botón: «Vender» con el comerciante
-- abierto, si no «Ver bolsas». Uno cada 10 minutos, salvo al llegar a 0.
---------------------------------------------------------------------------

S.CASI = 2
local ultimoCasi, avisoCero, casiPendiente = 0, false, false

function S.VerBolsas()
	if M.EnCombate() then
		N.Imprimir(L["No se puede en combate."])
		return
	end
	local V = M.Ventana
	if V and V.MostrarBolsas then V.MostrarBolsas(true) end
end

function S.TextoCasi(est)
	local base = est.libres == 0 and L["Ya no te queda ninguna casilla libre."]
		or est.libres == 1 and L["Te queda 1 casilla libre."]
		or format(L["Te quedan %d casillas libres."], est.libres)
	local g = est.vender[1]
	if not g then return base .. " " .. L["No llevas nada que convenga vender: guarda algo en el banco."] end
	local nombre = g.cantidad > 1 and format("%s \195\151%d", g.nombre, g.cantidad) or g.nombre
	local texto = base .. " " .. format(L["Lo primero que puedes soltar: %s (%s)."], nombre, N.Dinero(g.valor or 0, true))
	if #est.vender > 1 then
		texto = texto .. " " .. format(L["En total, %d cosas por unos %s."], #est.vender, N.Dinero(est.valorVenta, true))
	end
	return texto
end

local function avisarCasi(est)
	if not (K and K.Aviso) then return end
	local accion
	if comercianteAbierto and #chatarraAhora() > 0 then
		accion = { texto = L["Vender [botón]"], alClic = S.VenderChatarra }
	else
		accion = { texto = L["Ver bolsas"], alClic = S.VerBolsas }
	end
	K.Aviso({ titulo = est.libres == 0 and L["Tus bolsas están llenas"] or L["Tus bolsas están casi llenas"],
		texto = S.TextoCasi(est), icono = "ic-bolsas", tono = "aviso", duracion = 10, accion = accion })
end

-- -> true si las bolsas están casi llenas (y el aviso normal no hace falta).
local function revisarCasi(est, ahora)
	if not M.Get("avisoCasiLleno") or not (est.total > 0 and est.libres <= S.CASI) then
		if est.libres > 0 then avisoCero = false end
		casiPendiente = false
		return false
	end
	if est.libres > 0 then avisoCero = false end
	-- En combate no se avisa: se mira otra vez al salir.
	if M.EnCombate() then casiPendiente = true return true end
	casiPendiente = false
	local cero = est.libres == 0 and not avisoCero
	if cero or ultimoCasi == 0 or ahora - ultimoCasi >= CADA_AVISO then
		ultimoCasi, ultimoAviso = ahora, ahora
		if est.libres == 0 then avisoCero = true end
		avisarCasi(est)
	end
	return true
end
S.RevisarCasi = revisarCasi

local function revisar()
	pendiente = false
	if not M.Get("avisoLleno") and not M.Get("avisoCasiLleno") then estabaLleno = false return end
	local est = S.Estado()
	local ahora = GetTime and GetTime() or 0
	if revisarCasi(est, ahora) then estabaLleno = est.lleno return end
	if not M.Get("avisoLleno") then estabaLleno = false return end
	if est.lleno and not estabaLleno then
		-- En combate no se avisa: se mira otra vez al salir (PLAYER_REGEN_ENABLED).
		if M.EnCombate() then return end
		if ahora - ultimoAviso >= CADA_AVISO or ultimoAviso == 0 then
			ultimoAviso = ahora
			avisar(est)
		end
	end
	estabaLleno = est.lleno
end

local function programar(seg)
	S.Invalidar()
	M.Avisar("SUGERENCIAS")
	if pendiente then return end
	pendiente = true
	M.Luego(seg or 1, revisar)
end

A.RegisterEvent("BAG_UPDATE_DELAYED", function() programar(1) end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() if not estabaLleno or casiPendiente then programar(2) end end)
A.RegisterEvent("MERCHANT_SHOW", function() comercianteAbierto = true programar(1.5) end)
A.RegisterEvent("MERCHANT_CLOSED", function()
	comercianteAbierto = false
	if M.Lotes.Activo("vender") then M.Lotes.Cancelar("vender") end
	programar(0.5)
end)
A.On("ITEM_MARKS", function() programar(0.2) end)
A.On("ALFA_COMERCIO", function() programar(2) end)
A.On("SETTING_CHANGED", function(ruta)
	if ruta == M.ID .. ".avisoLibres" or ruta == M.ID .. ".avisoLleno" or ruta == M.ID .. ".avisoCasiLleno" then
		estabaLleno = false
		programar(0.2)
	end
end)
M.Escuchar("ITEM", function() S.Invalidar() end)
