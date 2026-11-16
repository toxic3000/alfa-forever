-- Alfa - Bolsas: la barra de las bolsas equipadas, en la ventana. GPL-3.0.
--
-- Una casilla por bolsa (la mochila, las cuatro bolsas, la de componentes y
-- el llavero; en el banco, cada pestaña), con su ícono, cuántas casillas
-- tiene y una raya de lo ocupado. Al pasar el ratón se resalta lo que lleva
-- (y con un clic queda resaltado); arrastrando se cambia la bolsa, como en
-- los botones de bolsa del juego:
--   * tus bolsas: PickupBagFromSlot(ranura) / PutItemInBag(ranura) con la
--     ranura de inventario de C_Container.ContainerIDToInventoryID
--     (Blizzard_MainMenuBarBagButtons/Shared/MainMenuBarBagButtons.lua);
--   * las casillas de bolsa del banco (con el banco abierto):
--     C_Container.PickupContainerItem(Enum.BagIndex.Characterbanktab, casilla)
--     (Blizzard_UIPanels_Game/Camelot/BankFrame.lua, BankItemButtonBagMixin).
-- Son botones simples de Alfa (no plantillas del juego, que se registran en
-- la barra de bolsas de Blizzard): nada protegido, y cambiar una bolsa nunca
-- en combate. En el banco, la última casilla es "comprar otra" con su costo.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D = M.Datos
local K = N.Kit

local type, ipairs, tonumber, format, max, floor = type, ipairs, tonumber, string.format, math.max, math.floor

local Barra = {}
M.Barra = Barra

local TAM, PASO = 30, 34
Barra.ALTO = 44

local function cursorConObjeto() return CursorHasItem and CursorHasItem() and true or false end

local function poner(d)
	if M.EnCombate() then N.Imprimir(L["No se pueden cambiar bolsas en combate."]) return end
	local info = d.info
	if info.inv and PutItemInBag then
		PutItemInBag(info.inv)
	elseif info.casilla and info.casilla >= 2 and D.BancoAbierto() and C_Container and C_Container.PickupContainerItem then
		C_Container.PickupContainerItem(D.BANCO_BOLSAS, info.casilla)
	end
end

local function recoger(d)
	if M.EnCombate() then N.Imprimir(L["No se pueden cambiar bolsas en combate."]) return end
	local info = d.info
	if info.inv and PickupBagFromSlot then
		PickupBagFromSlot(info.inv)
	elseif info.casilla and info.casilla >= 2 and D.BancoAbierto() and C_Container and C_Container.PickupContainerItem then
		C_Container.PickupContainerItem(D.BANCO_BOLSAS, info.casilla)
	end
end

local function pintarCasilla(b)
	local d = b.dato
	local fijada = d and b.barra.ventana.fijada ~= nil and b.barra.ventana.fijada == d.bolsa
	local compra = d and d.compra
	b.caja:Estilo({ fondo = "hundido", borde = (fijada or compra) and "acento" or (b.sobre and "textoTenue" or "lineaFuerte"),
		alfaBorde = compra and 0.6 or nil })
end

local function entrar(self)
	local d = self.dato
	if not d then return end
	self.sobre = true
	pintarCasilla(self)
	local f = self.barra.ventana
	if not GameTooltip then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	if d.compra then
		local c = d.compra
		GameTooltip:SetText(L["Comprar otra casilla del banco"], 1, 1, 1)
		if c.costo then GameTooltip:AddLine(format(L["Cuesta %s."], N.Dinero(c.costo)), 1, 1, 1) end
		GameTooltip:AddLine(format(L["Tienes %d de %d casillas de bolsa en el banco."], c.compradas, c.maximo), K.Color("textoSuave"))
		if d.vivo then
			GameTooltip:AddLine(c.alcanza == false and L["Todavía no te alcanza."] or L["Clic para comprarla."], K.Color(c.alcanza == false and "aviso" or "acento"))
		else
			GameTooltip:AddLine(L["Habla con un banquero para comprarla."], K.Color("textoSuave"))
		end
		GameTooltip:Show()
		return
	end
	local info = d.info
	local puesto = false
	if d.vivo and info.inv and GameTooltip.SetInventoryItem then
		puesto = M.Leer(M.Llamar(GameTooltip.SetInventoryItem, GameTooltip, "player", info.inv)) and true or false
	end
	if not puesto and type(info.link) == "string" then
		local hl = info.link:match("|H(.-)|h") or info.link
		puesto = pcall(GameTooltip.SetHyperlink, GameTooltip, hl)
	end
	if not puesto then
		GameTooltip:SetText(info.nombre or (d.n > 0 and L["Bolsa"] or L["Casilla de bolsa vacía"]), 1, 1, 1)
	end
	local tr, tg, tb = K.Color("textoSuave")
	if d.n > 0 then
		GameTooltip:AddLine(format(L["%d de %d casillas ocupadas"], d.usadas, d.n), tr, tg, tb)
		GameTooltip:AddLine(L["Clic: resalta lo que lleva."], tr, tg, tb)
	end
	if d.cambiar then
		GameTooltip:AddLine(d.n > 0 and L["Arrastra otra bolsa aquí para cambiarla."] or L["Arrastra una bolsa aquí para ponerla."], tr, tg, tb)
	end
	GameTooltip:Show()
	if d.n > 0 then M.Ventana.Resaltar(f, d.bolsa) end
end

local function salir(self)
	self.sobre = nil
	pintarCasilla(self)
	if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
	local f = self.barra.ventana
	M.Ventana.Resaltar(f, f.fijada)
end

local function clic(self)
	local d = self.dato
	if not d then return end
	if d.compra then
		if d.vivo then M.Banco.Comprar() else N.Imprimir(L["Para comprar espacio, habla con un banquero."]) end
		return
	end
	if d.cambiar and cursorConObjeto() then
		poner(d)
		return
	end
	if d.n <= 0 then return end
	local f = self.barra.ventana
	f.fijada = (f.fijada ~= d.bolsa) and d.bolsa or nil
	M.Ventana.Resaltar(f, f.fijada)
	for _, x in ipairs(self.barra.casillas) do pintarCasilla(x) end
end

local function casilla(barra, i)
	local b = barra.casillas[i]
	if b then return b end
	b = CreateFrame("Button", nil, barra)
	b.barra = barra
	b:SetSize(TAM, TAM)
	b:RegisterForClicks("LeftButtonUp")
	b:RegisterForDrag("LeftButton")
	b.caja = K.Caja(b, { fondo = "hundido", borde = "lineaFuerte", corte = K.CORTE.casilla })
	b.Icono = b:CreateTexture(nil, "ARTWORK")
	b.Icono:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.Icono:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.Simbolo = K.Icono(b, "ic-mas", 14, "textoTenue")
	b.Simbolo:SetPoint("CENTER")
	b.Cuenta = b:CreateFontString(nil, "OVERLAY")
	b.Cuenta:SetFont(K.Cara("semibold"), 10, "OUTLINE")
	b.Cuenta:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.Cuenta:SetJustifyH("RIGHT")
	b.Uso = K.Progreso(b, { alto = 2 })
	b.Uso:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -3)
	b.Uso:Acomodar(TAM)
	b:SetScript("OnEnter", entrar)
	b:SetScript("OnLeave", salir)
	b:SetScript("OnClick", clic)
	b:SetScript("OnDragStart", function(self)
		local d = self.dato
		if d and d.cambiar and d.info.id then recoger(d) end
	end)
	b:SetScript("OnReceiveDrag", function(self)
		local d = self.dato
		if d and d.cambiar then poner(d) end
	end)
	K.Pintar(b, pintarCasilla)
	barra.casillas[i] = b
	return b
end

function Barra.Crear(f, padre)
	local barra = CreateFrame("Frame", nil, padre or f)
	barra.ventana = f
	barra.casillas = {}
	barra:SetHeight(Barra.ALTO)
	barra.Costo = K.Texto(barra, "pequeno", "textoSuave")
	barra.Costo:Hide()
	return barra
end

-- Las casillas de la ventana f. datos: lo que se muestra (vivo o foto);
-- lista: sus contenedores. -> { { bolsa, info, n, usadas, cambiar, vivo } | { compra, vivo } }
function Barra.Datos(f, datos, lista, vivo, propio)
	local out = {}
	local function usadas(t, n)
		local u = 0
		if type(t) == "table" then for s = 1, n do if type(t[s]) == "table" then u = u + 1 end end end
		return u
	end
	if f.tipo == "banco" then
		local compra = (vivo and D.Compra()) or (propio and D.CompraGuardada()) or D.CompraGuardada(f.clave)
		local compradas = compra and compra.compradas or 0
		for i, bolsa in ipairs(D.BANCO) do
			local t = datos and datos[bolsa]
			local n = type(t) == "table" and tonumber(t.n) or 0
			if i <= compradas or n > 0 then
				local info = vivo and D.InfoBolsa(bolsa) or D.InfoGuardada(bolsa, t)
				out[#out + 1] = { bolsa = bolsa, info = info, n = n, usadas = usadas(t, n), vivo = vivo,
					cambiar = vivo and i >= 2 and true or false }
			end
		end
		if propio and compra and not compra.completo and compra.maximo > 0 then
			out[#out + 1] = { compra = compra, vivo = vivo, bolsa = "compra" }
		end
		return out
	end
	for _, bolsa in ipairs(lista) do
		local t = datos and datos[bolsa]
		local n = type(t) == "table" and tonumber(t.n) or 0
		local info = vivo and D.InfoBolsa(bolsa) or D.InfoGuardada(bolsa, t)
		local mostrar = n > 0 or (vivo and info.inv ~= nil)
		if bolsa == D.LLAVERO then mostrar = n > 0 end
		if mostrar then
			out[#out + 1] = { bolsa = bolsa, info = info, n = n, usadas = usadas(t, n), vivo = vivo,
				cambiar = vivo and info.inv ~= nil and not info.fija }
		end
	end
	return out
end

-- Pinta las casillas. -> el alto de la barra (0 si no hay nada que mostrar)
function Barra.Llenar(barra, lista, ancho, x0)
	local f = barra.ventana
	local n = #lista
	for i, d in ipairs(lista) do
		local b = casilla(barra, i)
		b.dato = d
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", barra, "TOPLEFT", x0 + (i - 1) * PASO, -6)
		b:Show()
		if d.compra then
			b.Icono:Hide()
			b.Simbolo:Show()
			K.SetIcono(b.Simbolo, "ic-mas", d.compra.alcanza == false and "textoTenue" or "acento")
			b.Cuenta:SetText("")
			b.Uso:Hide()
		else
			local info = d.info
			if info.icono then
				b.Icono:SetTexture(info.icono)
				b.Icono:SetVertexColor(1, 1, 1, 1)
				b.Icono:Show()
				b.Simbolo:Hide()
			elseif info.base then
				b.Icono:Hide()
				b.Simbolo:Show()
				K.SetIcono(b.Simbolo, "ic-bolsas", "textoSuave")
			else
				-- Una casilla sin bolsa: el contorno de una bolsa, apagado.
				b.Icono:Hide()
				b.Simbolo:Show()
				K.SetIcono(b.Simbolo, "ic-bolsas", "lineaFuerte")
			end
			b.Cuenta:SetText(d.n > 0 and tostring(d.n) or "")
			b.Uso:SetShown(d.n > 0)
			if d.n > 0 then
				b.Uso:Set(d.usadas, d.n)
				b.Uso:SetTono(d.n - d.usadas <= 1 and "aviso" or "acento")
			end
		end
		pintarCasilla(b)
	end
	for i = n + 1, #barra.casillas do
		barra.casillas[i].dato = nil
		barra.casillas[i]:Hide()
	end
	-- El costo de la siguiente casilla del banco, junto a su "+".
	local ultimo = lista[n]
	if ultimo and ultimo.compra and ultimo.compra.costo then
		local c = ultimo.compra
		K.Escribir(barra.Costo, c.costo > 0 and N.Dinero(c.costo, true) or L["Gratis"])
		K.ColorTexto(barra.Costo, c.alcanza == false and "aviso" or "textoSuave")
		barra.Costo:ClearAllPoints()
		barra.Costo:SetPoint("LEFT", barra.casillas[n], "RIGHT", 8, 0)
		barra.Costo:Show()
	else
		barra.Costo:Hide()
	end
	barra:SetWidth(ancho)
	return n > 0 and Barra.ALTO or 0
end

-- Repinta el marco de cada casilla (la fijada cambió).
function Barra.Repintar(barra)
	for _, b in ipairs(barra.casillas) do if b.dato then pintarCasilla(b) end end
end
