-- Alfa - Comercio: escaneo completo de la subasta (Toxic / La Jauría). GPL-3.0.
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
-- 15 minutos desde la última petición (lo mismo que en el cliente moderno,
-- donde Auctionator usa esa espera): ESTIMADO, se verifica en el juego.
-- Si la subasta no responde en 90 s, se avisa y se puede intentar después.

local _, M = ...
local N = AlfaNucleo
local A = N.A
local W, T = A.Widgets, A.Theme
local L = M.L

local type, floor, max, min, tonumber, tostring = type, math.floor, math.max, math.min, tonumber, tostring

local ESPERA = 15 * 60
local SIN_RESPUESTA = 90
local LOTE = 200

local estado = "listo" -- "listo" | "esperando" | "procesando"
local progreso, mensaje = 0, nil
local abierta = false
local temporizador
local ultimoProcesado = 0

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
	ultimoProcesado = M.Ahora()
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

A.RegisterEvent("REPLICATE_ITEM_LIST_UPDATE", function()
	if estado == "esperando" then return procesar() end
	-- Otro addon pidió el escaneo: también sirve, si no se leyó hace poco.
	if estado == "listo" and abierta and M.Ahora() - ultimoProcesado > 60 then
		if M.EsperaEscaneo() == 0 then M.Reino().pedido = M.Ahora() end
		procesar()
	end
end)

---------------------------------------------------------------------------
-- La barra bajo la ventana de la subasta
---------------------------------------------------------------------------

local barra
local BARRA_W, BARRA_H = 430, 40

local function marcoSubasta()
	return AuctionHouseFrame
end

local function textoEstado()
	if estado == "esperando" then return L["Pidiendo los precios a la subasta..."], "textDim" end
	if estado == "procesando" then
		return L["Leyendo precios... %d%%"]:format(floor(progreso * 100 + 0.5)), "textDim"
	end
	if mensaje then return mensaje, "text" end
	local fecha, objetos = M.Escaneo()
	if not fecha then return L["Aún no tienes precios. Pulsa «Escanear con Alfa»."], "warning" end
	local texto = L["Precios %s · %s objetos"]:format(M.Hace(fecha), miles(objetos or 0))
	return texto, M.Viejo(fecha) and "warning" or "textDim"
end

function refrescarBarra()
	if not barra then return end
	local mostrar = abierta and M.Ajuste("boton") and api() ~= nil
	barra:SetShown(mostrar and true or false)
	if not mostrar then return end
	local texto, color = textoEstado()
	barra.Estado:SetText(texto)
	W.Color(barra.Estado, color)
	local espera = M.EsperaEscaneo()
	local boton = barra.Boton
	if estado ~= "listo" then
		W.SetButtonText(boton, L["Escaneando..."])
		boton:Disable()
	elseif espera > 0 then
		W.SetButtonText(boton, L["Espera %s"]:format(minutos(espera)))
		boton:Disable()
	else
		W.SetButtonText(boton, L["Escanear con Alfa"])
		boton:Enable()
	end
	boton:SetAlpha(boton:IsEnabled() and 1 or 0.55)
	local enCurso = estado == "procesando"
	barra.Progreso:SetShown(enCurso)
	if enCurso then W.SetProgress(barra.Progreso, progreso, BARRA_W - 2) end
end
M.RefrescarBarra = function() if refrescarBarra then refrescarBarra() end end

local function crearBarra()
	if barra then return barra end
	local padre = marcoSubasta()
	if type(padre) ~= "table" then return nil end
	barra = CreateFrame("Frame", nil, padre)
	barra:SetSize(BARRA_W, BARRA_H)
	barra:SetPoint("TOPRIGHT", padre, "BOTTOMRIGHT", 0, -2)
	T.Skin(barra, "panel")
	barra.Emblema = W.Tex(barra, "ARTWORK", "emblem", "accent")
	barra.Emblema:SetSize(18, 18)
	barra.Emblema:SetPoint("LEFT", barra, "LEFT", 10, 0)
	barra.Titulo = W.Text(barra, "label", "text")
	barra.Titulo:SetText("Alfa")
	barra.Titulo:SetPoint("LEFT", barra.Emblema, "RIGHT", 6, 0)
	barra.Estado = W.Text(barra, "small", "textDim")
	barra.Estado:SetPoint("LEFT", barra.Titulo, "RIGHT", 8, 0)
	barra.Boton = W.Button(barra, L["Escanear con Alfa"], function() M.Escanear() end, { primary = true, height = 26, icon = "search" })
	barra.Boton:SetPoint("RIGHT", barra, "RIGHT", -8, 0)
	barra.Boton.psTip = L["Escanear con Alfa"]
	barra.Boton.psTipLines = { L["Lee el precio más bajo de cada objeto en toda la subasta. No compra ni publica nada. Se puede usar cada 15 minutos."] }
	barra.Abrir = W.IconButton(barra, "qol-coin", 24, L["¿Qué hago con mis objetos?"], function() N.Abrir(M.ID) end)
	barra.Abrir:SetPoint("RIGHT", barra.Boton, "LEFT", -6, 0)
	barra.Estado:SetPoint("RIGHT", barra.Abrir, "LEFT", -6, 0)
	barra.Progreso = W.ProgressLine(barra, 2)
	barra.Progreso:SetPoint("BOTTOMLEFT", barra, "BOTTOMLEFT", 1, 1)
	barra.Progreso:SetPoint("BOTTOMRIGHT", barra, "BOTTOMRIGHT", -1, 1)
	barra.Progreso:Hide()
	local acumulado = 0
	barra:SetScript("OnUpdate", function(_, dt)
		acumulado = acumulado + (dt or 0)
		if acumulado < 0.5 then return end
		acumulado = 0
		refrescarBarra()
	end)
	return barra
end

local function alAbrir()
	abierta = true
	mensaje = nil
	if not api() then return end
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
	if type(path) == "string" and path:sub(1, #M.ID + 1) == M.ID .. "." then refrescarBarra() end
end)
