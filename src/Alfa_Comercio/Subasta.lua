-- Alfa - Comercio: escaneo completo de la subasta (toxic3000 / La Jauría). GPL-3.0.
--
-- Con la casa de subastas abierta, una barra de Alfa bajo su ventana tiene el
-- botón "Escanear con Alfa". Nada se compra ni se publica: solo se leen
-- precios cuando el jugador pulsa el botón.
--
-- API verificada (Blizzard_APIDocumentationGenerated/AuctionHouseDocumentation.lua):
--   C_AuctionHouse.ReplicateItems()          -- "en lugar de QueryAuctionItems con allItem"
--   REPLICATE_ITEM_LIST_UPDATE               -- los datos llegaron
--   C_AuctionHouse.GetNumReplicateItems()
--   C_AuctionHouse.GetReplicateItemInfo(i)   -- índice desde 0 (tipo number, no luaIndex):
--       name, texture, count, qualityID, usable, level, levelType, minBid,
--       minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName,
--       owner, ownerFullName, saleStatus, itemID, hasAllInfo
--   AUCTION_HOUSE_SHOW / AUCTION_HOUSE_CLOSED
-- La API no dice cuánto hay que esperar entre escaneos completos. Se usan
-- 15 minutos desde la última petición (la espera habitual del cliente
-- moderno): ESTIMADO, se verifica en el juego.
-- Si la subasta no responde en 90 s, se avisa y se puede intentar después.

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, floor, max, min, tonumber, tostring = type, math.floor, math.max, math.min, tonumber, tostring

local ESPERA = 15 * 60
local SIN_RESPUESTA = 90
local LOTE = 200

local estado = "listo" -- "listo" | "esperando" | "procesando"
local progreso, mensaje = 0, nil
local abierta = false
local temporizador

local function api()
	local AH = C_AuctionHouse
	if type(AH) ~= "table" or type(AH.ReplicateItems) ~= "function" then return nil end
	if type(AH.GetNumReplicateItems) ~= "function" or type(AH.GetReplicateItemInfo) ~= "function" then return nil end
	return AH
end

function M.SubastaAbierta() return abierta end
function M.EstadoEscaneo() return estado, progreso, mensaje end

-- Segundos que faltan para poder pedir otro escaneo completo (0 = ya).
function M.EsperaEscaneo()
	local r = M.Reino()
	local pedido = type(r.pedido) == "number" and r.pedido or 0
	return max(0, ESPERA - (M.Ahora() - pedido))
end

-- 12345 -> "12,345". 1.3.7: el separador de miles según tu idioma (en alemán,
-- francés, portugués, ruso y español de España la coma se lee como decimal).
local SEPARADOR = { deDE = ".", ptBR = ".", esES = ".", frFR = " ", ruRU = " " }
function M.SeparadorMiles()
	local loc = GetLocale and GetLocale()
	return SEPARADOR[loc] or ","
end
local function miles(n)
	n = floor(tonumber(n) or 0)
	local signo = n < 0 and "-" or ""
	local s = tostring(math.abs(n))
	local sep = M.SeparadorMiles()
	local k
	repeat s, k = s:gsub("^(%d+)(%d%d%d)", "%1" .. sep .. "%2") until k == 0
	return signo .. s
end
M.Miles = miles

-- Segundos -> "12 min" / "40 s", para la espera del botón.
local function minutos(seg)
	if seg >= 60 then return L["%d min"]:format(math.ceil(seg / 60)) end
	return L["%d s"]:format(math.ceil(seg))
end

local refrescarBarra

local function terminar(texto, bien)
	estado, progreso, mensaje = "listo", 0, texto
	if temporizador then N.Quitar(temporizador) end
	temporizador = nil
	-- 1.3.7: lo que dijo al terminar se va solo y la barra vuelve a quedarse quieta.
	if texto then
		N.Una("comercio.mensaje", bien and 8 or 20, function()
			if mensaje == texto and estado == "listo" then
				mensaje = nil
				if refrescarBarra then refrescarBarra() end
			end
		end)
	end
	if refrescarBarra then refrescarBarra() end
	M.Cambio()
end

-- Lee la lista replicada por lotes y guarda el mínimo por unidad de cada objeto.
local function procesar()
	local AH = api()
	if not AH then return terminar(L["Esta subasta no permite el escaneo completo."]) end
	if temporizador then N.Quitar(temporizador) end
	temporizador = nil
	estado, progreso, mensaje = "procesando", 0, nil
	if refrescarBarra then refrescarBarra() end
	M.Tarea("escaneo", function()
		local n = AH.GetNumReplicateItems()
		if type(n) ~= "number" or n <= 0 then
			return terminar(L["La subasta no envió subastas. Intenta de nuevo más tarde."])
		end
		local minimo, cantidad = {}, {}
		for i = 0, n - 1 do
			local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = AH.GetReplicateItemInfo(i)
			if type(itemID) == "number" and type(count) == "number" and count > 0
				and type(buyout) == "number" and buyout > 0 then
				local u = buyout / count
				local m = minimo[itemID]
				if not m or u < m then minimo[itemID] = u end
				cantidad[itemID] = (cantidad[itemID] or 0) + count
			end
			if i % LOTE == 0 then
				progreso = 0.85 * i / n
				M.Ceder()
			end
		end
		local r = M.Reino()
		local ahora = M.Ahora()
		local k = 0
		for id, p in pairs(minimo) do
			M.Anotar(id, p, cantidad[id], 1, ahora, r)
			k = k + 1
			if k % LOTE == 0 then
				progreso = 0.85 + 0.15 * min(1, k / max(1, n))
				M.Ceder()
			end
		end
		r.escaneo = { ahora, k, n }
		terminar(L["¡Listo! %s precios guardados."]:format(miles(k)), true)
		N.Imprimir(L["Escaneo completo: %s objetos con precio (%s subastas)."]:format(miles(k), miles(n)))
	end, function()
		terminar(L["No se pudo leer el escaneo. Intenta de nuevo más tarde."])
	end)
end

-- Pide el escaneo completo. -> true si se pidió.
function M.Escanear()
	local AH = api()
	if not AH then
		N.Imprimir(L["Esta subasta no permite el escaneo completo."])
		return false
	end
	if not abierta then
		N.Imprimir(L["Abre la casa de subastas para escanear."])
		return false
	end
	if estado ~= "listo" then return false end
	local espera = M.EsperaEscaneo()
	if espera > 0 then
		N.Imprimir(L["La subasta deja escanear todo cada 15 minutos. Falta %s."]:format(minutos(espera)))
		return false
	end
	estado, progreso, mensaje = "esperando", 0, nil
	local ok = pcall(AH.ReplicateItems)
	if not ok then
		terminar(L["La subasta no aceptó el escaneo. Intenta de nuevo más tarde."])
		return false
	end
	M.Reino().pedido = M.Ahora()
	-- 1.3.7: la espera de la respuesta va en el reloj de Alfa (N.Una).
	temporizador = N.Una("comercio.sinRespuesta", SIN_RESPUESTA, function()
		temporizador = nil
		if estado == "esperando" then
			terminar(L["La subasta no respondió. Puede que aún esté en espera: intenta en unos minutos."])
		end
	end)
	if refrescarBarra then refrescarBarra() end
	return true
end

-- Solo se leen los escaneos que pidió Alfa (su botón o /alfa comercio escanear).
A.RegisterEvent("REPLICATE_ITEM_LIST_UPDATE", function()
	if estado == "esperando" then return procesar() end
end)

---------------------------------------------------------------------------
-- La barra bajo la ventana de la subasta (hecha con el Kit)
---------------------------------------------------------------------------
-- 1.3.7: compacta (una fila de 30) y sin tapar nada del juego. Va junto a las
-- pestañas de la subasta (Comprar, Vender, Subastas), a su derecha; si no
-- cabe, debajo de ellas. Solo se ve con la subasta a la vista: con otra
-- ventana (la del vendedor) no se queda pegada. Quieta (con precios al día y
-- sin nada que decir) se encoge a su botón: el estado sale en su cuadro de
-- información, y el avance es una línea fina abajo.

local barra
local BARRA_H = 30
local ANCHO_MAX, ANCHO_MIN = 520, 300

local function marcoSubasta()
	local AH = rawget(_G, "AuctionHouseFrame")
	return type(AH) == "table" and AH or nil
end

local function num(v)
	if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
	return tonumber(v)
end

-- La subasta a la vista (y no otra ventana con la marca vieja de abierta).
local function subastaVisible()
	local AH = marcoSubasta()
	if not (AH and AH.IsVisible and AH:IsVisible()) then return false end
	local MF = rawget(_G, "MerchantFrame")
	if type(MF) == "table" and MF.IsVisible and MF:IsVisible() then return false end
	return true
end
M.SubastaVisible = subastaVisible

-- Las pestañas de la subasta que se ven.
local function pestanas(AH)
	local out, vistos = {}, {}
	local function poner(t)
		if type(t) == "table" and not vistos[t] and t.IsShown and t:IsShown() and t.GetRight then
			vistos[t] = true
			out[#out + 1] = t
		end
	end
	local tabs = rawget(AH, "Tabs")
	if type(tabs) == "table" then for _, t in pairs(tabs) do poner(t) end end
	for _, n in ipairs({ "AuctionHouseFrameBuyTab", "AuctionHouseFrameSellTab", "AuctionHouseFrameAuctionsTab" }) do poner(rawget(_G, n)) end
	for i = 1, 6 do
		poner(rawget(_G, "AuctionHouseFrameTab" .. i))
		poner(rawget(_G, "AuctionFrameTab" .. i))
	end
	return out
end
M.PestanasSubasta = pestanas

-- -> ancho que cabe, desplazamiento hacia abajo (en la escala de la barra)
local function lugar()
	local AH = marcoSubasta()
	local eB = K.num(barra.GetEffectiveScale and barra:GetEffectiveScale(), 1)
	local eA = K.num(AH.GetEffectiveScale and AH:GetEffectiveScale(), 1)
	if eB <= 0 then eB = 1 end
	if eA <= 0 then eA = 1 end
	local f = eA / eB -- de la escala de la subasta a la de la barra
	local ahL, ahR, ahB = num(AH:GetLeft()), num(AH:GetRight()), num(AH:GetBottom())
	if not (ahL and ahR and ahB) then return ANCHO_MAX, 2 end
	local derTabs, bajan = nil, 0
	for _, t in ipairs(pestanas(AH)) do
		local r, b = num(t:GetRight()), num(t:GetBottom())
		if r and b then
			local te = K.num(t.GetEffectiveScale and t:GetEffectiveScale(), eA)
			r, b = r * te / eA, b * te / eA
			if r > ahL then derTabs = max(derTabs or ahL, r) end
			bajan = max(bajan, ahB - b)
		end
	end
	local anchoAH = (ahR - ahL) * f
	if not derTabs then return min(ANCHO_MAX, anchoAH), 2 end
	local libre = (ahR - derTabs) * f - 8
	-- Junto a las pestañas; el tercer y cuarto valor, por si lo de la barra
	-- no cabe ahí (refrescarBarra la baja para no tapar «Subastas»).
	if libre >= ANCHO_MIN then return min(ANCHO_MAX, libre), 2, min(ANCHO_MAX, anchoAH), bajan * f + 4 end
	-- No cabe junto a las pestañas: debajo de ellas.
	return min(ANCHO_MAX, anchoAH), bajan * f + 4
end

-- -> el texto corto de la barra, su color, y el largo para su cuadro de información
local function textoEstado()
	if estado == "esperando" then return L["Pidiendo precios…"], "textoSuave", L["Pidiendo los precios a la subasta..."] end
	if estado == "procesando" then
		local t = L["Leyendo precios... %d%%"]:format(floor(progreso * 100 + 0.5))
		return t, "textoSuave", t
	end
	if mensaje then return mensaje, "texto", mensaje end
	local fecha, objetos = M.Escaneo()
	if not fecha then return L["Sin precios todavía"], "aviso", L["Aún no tienes precios. Pulsa «Escanear con Alfa»."] end
	local largo = L["Precios %s · %s objetos"]:format(M.Hace(fecha), miles(objetos or 0))
	local viejo = M.Viejo(fecha)
	return L["Precios %s"]:format(M.Hace(fecha)), viejo and "aviso" or "textoSuave", largo, not viejo
end

-- El texto y el estado del botón de escanear (también lo usa la página).
function M.BotonEscaneo()
	local espera = M.EsperaEscaneo()
	if estado ~= "listo" then return L["Escaneando..."], false end
	if espera > 0 then return L["Espera %s"]:format(minutos(espera)), false end
	return L["Escanear con Alfa"], true
end

local reloj -- refresca la barra mientras se ve

function refrescarBarra()
	if not barra then return end
	local mostrar = abierta and M.Ajuste("boton") and api() ~= nil and subastaVisible()
	barra:SetShown(mostrar and true or false)
	if not mostrar then
		if reloj then reloj:Cancel() reloj = nil end
		return
	end
	if not reloj then reloj = N.Ticker("comercio.subasta", 0.5, function() refrescarBarra() end) end
	local corto, color, largo, alDia = textoEstado()
	barra.infoEstado = largo
	local t, activo = M.BotonEscaneo()
	barra.Boton:SetTexto(t)
	barra.Boton:SetActivo(activo)
	-- El botón de gangas (Gangas.lua) va junto a «¿Qué hago con mis objetos?».
	local junto = M.PintarGangas and M.PintarGangas(barra) or barra.Abrir
	-- Quieta: sin nada que decir, solo sus botones (el estado, en su cuadro de información).
	local quieta = estado == "listo" and not mensaje and alDia and true or false
	barra.quieta = quieta
	local ancho, abajo, anchoDebajo, abajoDebajo = lugar()
	local w = K.ESP.m + 18 + K.ESP.s + K.num(K.AnchoTexto(barra.Titulo), 28)
	local derecha = K.ESP.m + K.num(barra.Boton:GetWidth(), 120) + K.ESP.s + 24
	if junto ~= barra.Abrir then derecha = derecha + K.ESP.s + K.num(junto:GetWidth(), 80) end
	-- Sus botones no caben junto a las pestañas: debajo de ellas, para no
	-- tapar la pestaña «Subastas».
	if anchoDebajo and w + derecha > ancho then ancho, abajo = anchoDebajo, abajoDebajo end
	barra.Estado:SetShown(not quieta)
	if quieta then
		ancho = min(ancho, w + K.ESP.m + derecha)
	else
		K.Escribir(barra.Estado, corto)
		K.ColorTexto(barra.Estado, color)
		local cabe = ancho - w - derecha - 2 * K.ESP.s
		-- Nunca cortado: si no cabe, solo en el cuadro de información.
		if K.num(K.AnchoTexto(barra.Estado), 0) > cabe then barra.Estado:Hide() end
		barra.Estado:ClearAllPoints()
		barra.Estado:SetPoint("LEFT", barra.Titulo, "RIGHT", K.ESP.s, 0)
		barra.Estado:SetPoint("RIGHT", junto, "LEFT", -K.ESP.s, 0)
	end
	ancho = floor(max(w + derecha, ancho))
	if barra.alfaAncho ~= ancho or barra.alfaAbajo ~= abajo then
		barra.alfaAncho, barra.alfaAbajo = ancho, abajo
		barra:SetSize(ancho, BARRA_H)
		barra:ClearAllPoints()
		barra:SetPoint("TOPRIGHT", marcoSubasta(), "BOTTOMRIGHT", 0, -abajo)
		barra.Progreso:Acomodar(ancho - 2 * K.CORTE.panel)
	end
	local enCurso = estado == "procesando"
	barra.Progreso:SetShown(enCurso)
	if enCurso then barra.Progreso:Set(progreso) end
end
M.RefrescarBarra = function() if refrescarBarra then refrescarBarra() end end
M.Barra = function() return barra end

local function crearBarra()
	if barra then return barra end
	local padre = marcoSubasta()
	if type(padre) ~= "table" then return nil end
	-- Cuelga de la capa de Alfa y solo se ancla a la subasta: crear marcos
	-- dentro de una ventana abierta del juego (AuctionHouseFrame es un panel)
	-- corre la navegación del mando (CreateFrame enganchado) dentro del código
	-- de Alfa y deja la ventana contaminada (ns.CreateFrameUnder del motor).
	barra = CreateFrame("Frame", nil, K.Raiz())
	if padre.GetFrameStrata then barra:SetFrameStrata(padre:GetFrameStrata()) end
	barra:SetSize(ANCHO_MIN, BARRA_H)
	barra:SetPoint("TOPRIGHT", padre, "BOTTOMRIGHT", 0, -2)
	barra.caja = K.Caja(barra, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel })
	barra.Icono = K.Icono(barra, "ic-comercio", 18, "acento")
	barra.Icono:SetPoint("LEFT", barra, "LEFT", K.ESP.m, 0)
	barra.Titulo = K.Texto(barra, "etiqueta", "texto")
	K.Escribir(barra.Titulo, "Alfa")
	barra.Titulo:SetPoint("LEFT", barra.Icono, "RIGHT", K.ESP.s, 0)
	barra.Boton = K.Boton(barra, L["Escanear con Alfa"], function() M.Escanear() end, { tipo = "primario", tam = "chico", icono = "ic-buscar" })
	barra.Boton:SetPoint("RIGHT", barra, "RIGHT", -K.ESP.m, 0)
	K.ConInfo(barra.Boton, L["Escanear con Alfa"], L["Lee el precio más bajo de cada objeto en toda la subasta. No compra ni publica nada. Se puede usar cada 15 minutos."])
	barra.Abrir = K.BotonIcono(barra, "ic-comercio", function() N.Abrir(M.ID) end, { tam = 24, ayuda = L["¿Qué hago con mis objetos?"] })
	barra.Abrir:SetPoint("RIGHT", barra.Boton, "LEFT", -K.ESP.s, 0)
	barra.Estado = K.Texto(barra, "pequeno", "textoSuave")
	barra.Estado:SetPoint("LEFT", barra.Titulo, "RIGHT", K.ESP.s, 0)
	barra.Estado:SetPoint("RIGHT", barra.Abrir, "LEFT", -K.ESP.s, 0)
	barra.Estado:SetWordWrap(false)
	barra.Estado:SetJustifyH("LEFT")
	-- El estado completo (y cuántos objetos) al pasar el ratón por la barra.
	barra:EnableMouse(true)
	K.ConInfo(barra, function(self) return L["Precios de la subasta"], self.infoEstado end)
	barra.Progreso = K.Progreso(barra, { alto = 2 })
	barra.Progreso:SetPoint("BOTTOMLEFT", barra, "BOTTOMLEFT", K.CORTE.panel, 1)
	barra.Progreso:Acomodar(ANCHO_MIN - 2 * K.CORTE.panel)
	barra.Progreso:Hide()
	if M.ArmarGangas then M.ArmarGangas(barra) end
	barra:SetScript("OnHide", function() if reloj then reloj:Cancel() reloj = nil end end)
	-- Si la subasta se esconde sin avisar (otra ventana la tapa), la barra se va con ella.
	if padre.HookScript then
		padre:HookScript("OnHide", function() if barra then barra:Hide() end end)
		padre:HookScript("OnShow", function() if refrescarBarra then refrescarBarra() end end)
	end
	return barra
end

local function alAbrir()
	abierta = true
	mensaje = nil
	if not api() then return end
	-- Con la barra apagada no se arma nada (se arma si la enciendes con la subasta abierta).
	if not barra and not M.Ajuste("boton") then return end
	if not crearBarra() then
		-- La ventana de la subasta se carga a pedido: puede llegar un cuadro después.
		N.Una("comercio.barra", 0.1, function() if abierta and crearBarra() then refrescarBarra() end end)
		return
	end
	refrescarBarra()
end

A.RegisterEvent("AUCTION_HOUSE_SHOW", alAbrir)
A.RegisterEvent("AUCTION_HOUSE_CLOSED", function()
	abierta = false
	if estado == "esperando" then
		terminar(L["Se cerró la subasta antes de recibir los precios. Vuelve a intentarlo después."])
		N.Imprimir(L["Se cerró la subasta antes de recibir los precios. Vuelve a intentarlo después."])
	end
	if barra then barra:Hide() end
end)

A.On("SETTING_CHANGED", function(path)
	if type(path) == "string" and path:sub(1, #M.ID + 1) == M.ID .. "." then
		if abierta and not barra and M.Ajuste("boton") then alAbrir() else refrescarBarra() end
	end
end)
