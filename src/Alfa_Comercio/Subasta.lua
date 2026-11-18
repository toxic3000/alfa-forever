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

-- 12345 -> "12,345" (separador de miles de es-MX).
local function miles(n)
	local s = tostring(floor(tonumber(n) or 0))
	local fuera = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if fuera:sub(1, 1) == "," then fuera = fuera:sub(2) end
	return fuera
end
M.Miles = miles

-- Segundos -> "12 min" / "40 s", para la espera del botón.
local function minutos(seg)
	if seg >= 60 then return L["%d min"]:format(math.ceil(seg / 60)) end
	return L["%d s"]:format(math.ceil(seg))
end

local refrescarBarra

local function terminar(texto)
	estado, progreso, mensaje = "listo", 0, texto
	if temporizador and temporizador.Cancel then temporizador:Cancel() end
	temporizador = nil
	if refrescarBarra then refrescarBarra() end
	M.Cambio()
end

-- Lee la lista replicada por lotes y guarda el mínimo por unidad de cada objeto.
local function procesar()
	local AH = api()
	if not AH then return terminar(L["Esta subasta no permite el escaneo completo."]) end
	if temporizador and temporizador.Cancel then temporizador:Cancel() end
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
		terminar(L["¡Listo! %s precios guardados."]:format(miles(k)))
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
	if C_Timer and C_Timer.NewTimer then
		temporizador = C_Timer.NewTimer(SIN_RESPUESTA, function()
			if estado == "esperando" then
				terminar(L["La subasta no respondió. Puede que aún esté en espera: intenta en unos minutos."])
			end
		end)
	end
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

local barra
local BARRA_W, BARRA_H = 440, 44

local function marcoSubasta()
	return AuctionHouseFrame
end

local function textoEstado()
	if estado == "esperando" then return L["Pidiendo los precios a la subasta..."], "textoSuave" end
	if estado == "procesando" then
		return L["Leyendo precios... %d%%"]:format(floor(progreso * 100 + 0.5)), "textoSuave"
	end
	if mensaje then return mensaje, "texto" end
	local fecha, objetos = M.Escaneo()
	if not fecha then return L["Aún no tienes precios. Pulsa «Escanear con Alfa»."], "aviso" end
	local texto = L["Precios %s · %s objetos"]:format(M.Hace(fecha), miles(objetos or 0))
	return texto, M.Viejo(fecha) and "aviso" or "textoSuave"
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
	local mostrar = abierta and M.Ajuste("boton") and api() ~= nil
	barra:SetShown(mostrar and true or false)
	if not mostrar then
		if reloj then reloj:Cancel() reloj = nil end
		return
	end
	if not reloj and C_Timer and C_Timer.NewTicker then reloj = C_Timer.NewTicker(0.5, function() refrescarBarra() end) end
	local texto, color = textoEstado()
	K.Escribir(barra.Estado, texto)
	K.ColorTexto(barra.Estado, color)
	local t, activo = M.BotonEscaneo()
	barra.Boton:SetTexto(t)
	barra.Boton:SetActivo(activo)
	local enCurso = estado == "procesando"
	barra.Progreso:SetShown(enCurso)
	if enCurso then barra.Progreso:Set(progreso) end
end
M.RefrescarBarra = function() if refrescarBarra then refrescarBarra() end end

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
	barra:SetSize(BARRA_W, BARRA_H)
	barra:SetPoint("TOPRIGHT", padre, "BOTTOMRIGHT", 0, -2)
	barra.caja = K.Caja(barra, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel })
	barra.Marca = K.Marca(barra, K.CORTE.panel, "acento")
	barra.Icono = K.Icono(barra, "ic-comercio", 18, "acento")
	barra.Icono:SetPoint("LEFT", barra, "LEFT", K.ESP.m, 0)
	barra.Titulo = K.Texto(barra, "encabezado", "texto")
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
	barra.Progreso = K.Progreso(barra, { alto = 2 })
	barra.Progreso:SetPoint("BOTTOMLEFT", barra, "BOTTOMLEFT", K.CORTE.panel, 1)
	barra.Progreso:Acomodar(BARRA_W - 2 * K.CORTE.panel)
	barra.Progreso:Hide()
	barra:SetScript("OnHide", function() if reloj then reloj:Cancel() reloj = nil end end)
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
		if C_Timer and C_Timer.After then
			C_Timer.After(0.1, function() if abierta and crearBarra() then refrescarBarra() end end)
		end
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
