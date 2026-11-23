-- Alfa - Comercio: subastar fácil (toxic3000 / La Jauría). GPL-3.0. 1.2.9.
--
-- Con la casa de subastas abierta y un objeto puesto en la pestaña de vender,
-- un panel de Alfa junto a la ventana dice el precio sugerido (el más bajo que
-- viste: escaneo completo o tus búsquedas, Precios.lua), el historial de ese
-- objeto (un precio por día, los últimos 14) con su más bajo, su promedio y su
-- más alto, y un aviso si tu precio queda muy por debajo de lo que vale
-- (comercio.precioBajo, en %). Solo se ve: Alfa nunca pone ni cambia precios
-- ni publica nada (la venta es tu clic en el botón del juego).
--
-- La ventana de la subasta no viene en referencia/ (se carga a pedido): sus
-- piezas se leen con cuidado y con pcall, y si alguna falta el panel no sale.
--   AuctionHouseFrame.CommoditiesSellFrame / .ItemSellFrame (la que se ve):
--     :GetItem() -> ItemLocation ; C_Item.GetItemID(itemLocation)
--       (ItemDocumentation.lua) ; precio: :GetUnitPrice(), :GetBuyoutAmount()
--       o .PriceInput:GetAmount().
-- El panel cuelga de la capa de Alfa y solo se ancla a la subasta, como la
-- barra de Subasta.lua. Se mira cada medio segundo mientras la subasta está
-- abierta (nada corre con ella cerrada).

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, ipairs, floor, max, min, format, tonumber = type, ipairs, math.floor, math.max, math.min, string.format, tonumber
local ESP = K.ESP
local DIA = 86400

local Ve = {}
M.Vender = Ve

local ANCHO, BARRAS = 260, 14
local panel, reloj
local estado -- lo último que se mostró: { id, precio, sugerido, bajo, ... }

local function encendido() return M.Ajuste("vender") ~= false end

local function llamar(obj, metodo, ...)
	if type(obj) ~= "table" or type(obj[metodo]) ~= "function" then return nil end
	local ok, a, b = pcall(obj[metodo], obj, ...)
	if ok then return a, b end
	return nil
end

local function secreto(v) return type(v) ~= "nil" and issecretvalue ~= nil and issecretvalue(v) and true or false end
local function num(v) if secreto(v) then return nil end return tonumber(v) end

-- La pestaña de vender que se ve: -> marco, "commodity" | "item"
local function ventaVisible()
	local AH = rawget(_G, "AuctionHouseFrame")
	if type(AH) ~= "table" or not (AH.IsShown and AH:IsShown()) then return nil end
	for _, par in ipairs({ { AH.CommoditiesSellFrame, "commodity" }, { AH.ItemSellFrame, "item" } }) do
		local f = par[1]
		if type(f) == "table" and f.IsShown and f:IsShown() then return f, par[2] end
	end
	return nil
end

local function objetoDe(f)
	local loc = llamar(f, "GetItem")
	if type(loc) ~= "table" then return nil end
	local CI = C_Item
	if CI and CI.DoesItemExist then
		local ok, hay = pcall(CI.DoesItemExist, loc)
		if ok and hay == false then return nil end
	end
	if CI and CI.GetItemID then
		local ok, id = pcall(CI.GetItemID, loc)
		if ok and num(id) then return num(id) end
	end
	return nil
end

local function precioDe(f)
	local p = num(llamar(f, "GetUnitPrice")) or num(llamar(f, "GetBuyoutAmount"))
	if not p and type(f.PriceInput) == "table" then p = num(llamar(f.PriceInput, "GetAmount")) end
	if p and p > 0 then return p end
	return nil
end

---------------------------------------------------------------------------
-- El historial de un objeto (Precios.lua guarda un precio por día)
---------------------------------------------------------------------------

-- -> { { dia, precio }, ... } (el más viejo primero), bajo, promedio, alto
function Ve.Historial(id)
	local r = M.Reino()
	local s = r.h[id]
	local lista = {}
	if type(s) ~= "string" then return lista end
	local suma, bajo, alto = 0, nil, nil
	for d, p in s:gmatch("(%d+):(%d+)") do
		d, p = tonumber(d), tonumber(p)
		lista[#lista + 1] = { d, p }
		suma = suma + p
		if not bajo or p < bajo then bajo = p end
		if not alto or p > alto then alto = p end
	end
	if #lista == 0 then return lista end
	return lista, bajo, floor(suma / #lista + 0.5), alto
end

-- El estado del objeto en venta: -> { id, precio, sugerido, fecha, viejo, bajo, historia } | nil
function Ve.Leer()
	if not (encendido() and M.SubastaAbierta()) then return nil end
	local f = ventaVisible()
	if not f then return nil end
	local id = objetoDe(f)
	if not id then return nil end
	local e = { id = id, precio = precioDe(f) }
	local sug, fecha = M.PrecioSubasta(id)
	e.sugerido, e.fecha = sug, fecha
	e.viejo = sug and M.Viejo(fecha) or false
	e.historia, e.minimo, e.promedio, e.maximo = Ve.Historial(id)
	-- Un precio para comparar: el sugerido o, sin él, el promedio de los días.
	local ref = sug or e.promedio
	local umbral = (tonumber(M.Ajuste("precioBajo")) or 30) / 100
	if e.precio and ref and ref > 0 and e.precio < ref * (1 - umbral) then
		e.bajo = (ref - e.precio) / ref
	end
	return e
end

---------------------------------------------------------------------------
-- El panel
---------------------------------------------------------------------------

local function crear()
	if panel then return panel end
	local AH = rawget(_G, "AuctionHouseFrame")
	if type(AH) ~= "table" then return nil end
	panel = CreateFrame("Frame", nil, K.Raiz())
	if AH.GetFrameStrata then panel:SetFrameStrata(AH:GetFrameStrata()) end
	panel:SetWidth(ANCHO)
	panel:SetPoint("TOPLEFT", AH, "TOPRIGHT", 4, -24)
	panel.caja = K.Caja(panel, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel })
	panel.Marca = K.Marca(panel, K.CORTE.panel, "acento")
	panel.Icono = K.Icono(panel, "ic-comercio", 18, "acento")
	panel.Icono:SetPoint("TOPLEFT", panel, "TOPLEFT", ESP.m, -ESP.m)
	panel.Titulo = K.Texto(panel, "encabezado", "texto")
	panel.Titulo:SetPoint("LEFT", panel.Icono, "RIGHT", ESP.s, 0)
	K.Escribir(panel.Titulo, L["Precio sugerido"])
	panel.Valor = K.Texto(panel, "cifra", "texto")
	panel.Detalle = K.Texto(panel, "nota", "textoSuave")
	panel.Aviso = K.Texto(panel, "nota", "aviso")
	panel.Historia = K.Texto(panel, "pequeno", "textoTenue")
	panel.Pie = K.Texto(panel, "pequeno", "textoTenue")
	panel.barras = {}
	for i = 1, BARRAS do
		local b = K.Plano(panel, "acento", "ARTWORK")
		b:SetWidth(floor((ANCHO - 2 * ESP.m) / BARRAS) - 2)
		panel.barras[i] = b
	end
	panel:SetScript("OnHide", function() estado = nil end)
	panel:Hide()
	return panel
end

local ALTO_BARRAS = 36

local function pintar(e)
	local p = crear()
	if not p then return end
	local tw = ANCHO - 2 * ESP.m
	local y = ESP.m + 20 + ESP.s
	local function poner(fs, texto, lineas)
		K.Escribir(fs, texto or "")
		if (texto or "") == "" then fs:Hide() return end
		fs:Show()
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", p, "TOPLEFT", ESP.m, -y)
		y = y + K.Parrafo(fs, tw, lineas or 3) + ESP.s
	end
	poner(p.Valor, e.sugerido and M.Dinero(e.sugerido) or "—", 1)
	local detalle
	if e.sugerido then
		detalle = format(L["El más bajo que viste, %s."], M.Hace(e.fecha))
		if e.viejo then detalle = detalle .. " " .. L["Es viejo: escanea para tenerlo al día."] end
	else
		detalle = L["Aún no conozco su precio. Al buscarlo o escanear, Alfa lo aprende."]
	end
	poner(p.Detalle, detalle)
	if e.bajo then
		poner(p.Aviso, format(L["¡Ojo! Tu precio está %d %% por debajo de lo que vale."], floor(e.bajo * 100 + 0.5)))
	else
		poner(p.Aviso, nil)
	end
	-- Las barras de los últimos días.
	local h = e.historia or {}
	local alto = e.maximo or 0
	local desde = max(1, #h - BARRAS + 1)
	local bw = floor(tw / BARRAS)
	for i = 1, BARRAS do
		local b = p.barras[i]
		local dato = h[desde + i - 1]
		if dato and alto > 0 and #h >= 2 then
			local bh = max(2, floor(ALTO_BARRAS * dato[2] / alto + 0.5))
			b:SetHeight(bh)
			b:ClearAllPoints()
			b:SetPoint("BOTTOMLEFT", p, "TOPLEFT", ESP.m + (i - 1) * bw, -(y + ALTO_BARRAS))
			K.ColorPlano(b, (desde + i - 1) == #h and "acento" or "lineaFuerte")
			b:Show()
		else
			b:Hide()
		end
	end
	if #h >= 2 then
		y = y + ALTO_BARRAS + ESP.s
		poner(p.Historia, format(#h == 1 and L["%d día: más bajo %s · promedio %s · más alto %s"] or L["%d días: más bajo %s · promedio %s · más alto %s"], #h, M.Dinero(e.minimo), M.Dinero(e.promedio), M.Dinero(e.maximo)))
	elseif #h == 1 then
		poner(p.Historia, L["Un solo día de precios: el historial crece con cada escaneo o búsqueda."])
	else
		poner(p.Historia, L["Sin historial todavía."])
	end
	poner(p.Pie, L["Alfa solo te sugiere: el precio lo pones tú."], 2)
	p:SetHeight(y + ESP.s)
	p:Show()
end

local function ocultar()
	estado = nil
	if panel then panel:Hide() end
end

function Ve.Refrescar()
	local e = Ve.Leer()
	if not e then return ocultar() end
	local clave = table.concat({ e.id, e.precio or 0, e.sugerido or 0, #(e.historia or {}), e.bajo and 1 or 0, M.version or 0 }, ":")
	if estado and estado.clave == clave and panel and panel:IsShown() then return end
	e.clave = clave
	estado = e
	pintar(e)
end

function Ve.Estado() return estado end
function Ve.Panel() return panel end

local function parar()
	if reloj then reloj:Cancel() reloj = nil end
	ocultar()
end

local function empezar()
	if not encendido() then return parar() end
	if not reloj then
		reloj = N.Ticker("comercio.vender", 0.5, function() M.Seguro(Ve.Refrescar) end)
	end
	Ve.Refrescar()
end

-- Un error del panel no corta la subasta.
function M.Seguro(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and geterrorhandler then pcall(geterrorhandler(), err) end
	return ok
end

A.RegisterEvent("AUCTION_HOUSE_SHOW", function() N.Una("comercio.vender", 0.2, empezar) end) -- 1.3.7: reloj de Alfa
A.RegisterEvent("AUCTION_HOUSE_CLOSED", parar)
A.On("SETTING_CHANGED", function(path)
	if path == M.ID .. ".vender" or path == M.ID .. ".precioBajo" then
		if M.SubastaAbierta() then empezar() else parar() end
	end
end)
