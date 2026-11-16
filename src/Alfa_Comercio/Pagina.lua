-- Alfa - Comercio: la página "¿Qué hago con mis objetos?" (Toxic / La Jauría). GPL-3.0.
--
-- Lo que llevas en las bolsas, ordenado por lo que más ganas, con la
-- recomendación en un chip de color (Vender, Subastar, Transformar, Guardar),
-- el total si sigues los consejos, la antigüedad de los precios, tus recetas
-- que dejan ganancia y los ajustes del módulo. Todo es información: nada se
-- vende, compra ni publica solo.
--
-- Bolsas: C_Container.GetContainerNumSlots / GetContainerItemInfo
-- (ContainerDocumentation.lua: ContainerItemInfo.itemID, stackCount,
-- isBound, hyperlink), de 0 a NUM_TOTAL_EQUIPPED_BAG_SLOTS (bolsa de
-- reactivos incluida), como el motor (Alfa/QoL/QoL.lua Client.NumBags).

local _, M = ...
local N = AlfaNucleo
local A = N.A
local W, T = A.Widgets, A.Theme
local L = M.L

local type, pairs, ipairs, floor, max, min = type, pairs, ipairs, math.floor, math.max, math.min

local FILA_H, ICONO, VALOR_W = 46, 30, 120
local GAP = 12
local MAX_RECETAS = 8

local pagina -- la vista, cuando ya se armó
local filtro = "todos"

---------------------------------------------------------------------------
-- Piezas
---------------------------------------------------------------------------

local function opciones() return A.UI and A.UI.Options end

local function anchoCuerpo()
	local O = opciones()
	local win = O and O.frame
	local w = win and win.BodyWidth
	return type(w) == "number" and w > 0 and w or 640
end

local function pad() return W.SHELL.pad end

local function relayout(view)
	view = view or pagina
	if not (view and view.Refresh) then return end
	local h = view.Refresh()
	view:SetHeight(h)
	local O = opciones()
	local win = O and O.frame
	if win and view:IsShown() then W.ShellBody(win, h) end
end

local pendienteRelayout = false
local function relayoutLuego()
	if not (pagina and pagina:IsVisible()) or pendienteRelayout then return end
	pendienteRelayout = true
	local function ir()
		pendienteRelayout = false
		if pagina and pagina:IsVisible() then relayout(pagina) end
	end
	if C_Timer and C_Timer.After then C_Timer.After(0.4, ir) else ir() end
end

-- Un chip en un color de la paleta (los de W.SetChip y cualquier otro);
-- sin color o "textDim": el chip neutro.
local function pintarChip(chip, texto, color)
	if color == "accent" then return W.SetChip(chip, texto, "accent") end
	local w = W.SetChip(chip, texto, "neutral")
	if color and color ~= "textDim" then
		local r, g, b = T.Color(color)
		chip.Bg:SetColor(r, g, b, 0.16)
		W.Color(chip.Text, color)
	end
	return w
end

local function hexColor(nombre) return "|c" .. T.Hex(nombre) end

local function colorCalidad(calidad)
	local C = A.Compat
	local h = C and C.ItemQualityHex and C.ItemQualityHex(calidad)
	return type(h) == "string" and ("|c" .. h) or hexColor("text")
end

local function nombreObjeto(id)
	local C = A.Compat
	return (C and C.GetItemName and C.GetItemName(id)) or ("#" .. tostring(id))
end

local function iconoObjeto(id, info)
	if info and info.icono then return info.icono end
	local C = A.Compat
	return C and C.ItemIcon and C.ItemIcon(id) or 134400
end

---------------------------------------------------------------------------
-- Bolsas
---------------------------------------------------------------------------

local function ultimaBolsa() return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 end

-- -> { { id, cantidad, ligado, link }, ... } agrupado por objeto y ligado.
local function leerBolsas()
	local C = C_Container
	local out, por = {}, {}
	if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return out end
	for bolsa = 0, ultimaBolsa() do
		local n = C.GetContainerNumSlots(bolsa)
		for ranura = 1, (type(n) == "number" and n or 0) do
			local info = C.GetContainerItemInfo(bolsa, ranura)
			local id = type(info) == "table" and info.itemID
			if type(id) == "number" then
				local ligado = info.isBound == true
				local clave = id .. (ligado and ":l" or "")
				local g = por[clave]
				if not g then
					g = { id = id, cantidad = 0, ligado = ligado, link = info.hyperlink }
					por[clave] = g
					out[#out + 1] = g
				end
				g.cantidad = g.cantidad + (type(info.stackCount) == "number" and info.stackCount or 1)
			end
		end
	end
	return out
end

-- Consejo de cada grupo y totales. -> lista, totales, pendientes
-- (También como M.AnalizarBolsas.)
local function analizar()
	local lista = leerBolsas()
	local out, pendientes = {}, 0
	local tot = { consejo = 0, comerciante = 0, cuenta = { todos = 0, vender = 0, subastar = 0, transformar = 0, guardar = 0 }, sinPrecio = 0 }
	for _, g in ipairs(lista) do
		local c = M.Consejo(g.id, { ligado = g.ligado, link = g.link })
		if not c then
			pendientes = pendientes + 1
		else
			g.c = c
			g.total = c.valor * g.cantidad
			out[#out + 1] = g
			if c.mejor ~= "guardar" then tot.consejo = tot.consejo + g.total end
			tot.comerciante = tot.comerciante + c.venta * g.cantidad
			local cat = (c.mejor == "desencantar" or c.mejor == "receta") and "transformar" or c.mejor
			g.cat = cat
			tot.cuenta[cat] = (tot.cuenta[cat] or 0) + 1
			tot.cuenta.todos = tot.cuenta.todos + 1
			if not c.ligado and not c.subasta and c.info.clase ~= M.CLASE_MISION then tot.sinPrecio = tot.sinPrecio + 1 end
		end
	end
	table.sort(out, function(a, b)
		local ga, gb = a.c.mejor == "guardar", b.c.mejor == "guardar"
		if ga ~= gb then return gb end
		if a.total ~= b.total then return a.total > b.total end
		return tostring(a.c.info.nombre) < tostring(b.c.info.nombre)
	end)
	return out, tot, pendientes
end
M.AnalizarBolsas = analizar

---------------------------------------------------------------------------
-- Filas
---------------------------------------------------------------------------

local function detalleDe(c)
	local partes = {}
	if c.venta > 0 then
		partes[#partes + 1] = L["Comerciante"] .. " " .. M.Dinero(c.venta)
	else
		partes[#partes + 1] = L["El comerciante no lo compra"]
	end
	if c.subasta then
		local s = L["Subasta"] .. " " .. M.Dinero(c.subasta.bruto)
		if c.subasta.fecha then
			s = s .. " " .. (c.subasta.viejo and hexColor("warning") or "") .. "(" .. M.Hace(c.subasta.fecha) .. ")" .. (c.subasta.viejo and "|r" or "")
		end
		local t = M.Tendencia(c.id)
		if t and math.abs(t) >= 0.05 then
			local cuanto = (M.Porcentaje(math.abs(t)):gsub("^%+", ""))
			s = s .. " " .. (t > 0 and L["sube %s"] or L["baja %s"]):format(cuanto)
		end
		partes[#partes + 1] = s
	elseif c.ligado then
		partes[#partes + 1] = L["Ligado: no se subasta"]
	end
	if c.desencantar then
		partes[#partes + 1] = L["Desencantar ≈ %s"]:format(M.Dinero(c.desencantar.valor))
	end
	if c.receta then
		partes[#partes + 1] = L["Crear %s ≈ %s"]:format(nombreObjeto(c.receta.producto), M.Dinero(c.receta.valor))
	end
	if c.mejor == "guardar" and c.motivo then partes[#partes + 1] = c.motivo end
	return table.concat(partes, "  ·  ")
end

local function extraCuadro(g)
	return function(tip)
		local c = g.c
		if not c then return end
		local r, gg, b = T.Color("textDim")
		tip:AddLine(" ")
		if g.cantidad > 1 then
			tip:AddDoubleLine(L["Tienes"], tostring(g.cantidad), r, gg, b, 1, 1, 1)
		end
		if c.mejor ~= "guardar" then
			tip:AddDoubleLine(L["Si sigues el consejo"], M.Dinero(g.total), r, gg, b, 1, 1, 1)
		end
		if c.venta > 0 and g.cantidad > 0 then
			tip:AddDoubleLine(L["Al comerciante"], M.Dinero(c.venta * g.cantidad), r, gg, b, 1, 1, 1)
		end
		local de = c.desencantar
		if de then
			local quien = (de.propio or not de.quien) and "" or (" " .. L["(con %s)"]:format(de.quien))
			tip:AddLine(L["Desencantar: ≈ %s por objeto%s. Pide Encantamiento %d."]:format(M.Dinero(de.valor), quien, de.habilidad or 1), r, gg, b, true)
			if de.incompleto then
				local wr, wg, wb = T.Color("warning")
				tip:AddLine(L["Faltan precios de algunos materiales."], wr, wg, wb, true)
			end
		end
		local re = c.receta
		if re then
			local quien = (re.propio or not re.quien) and "" or (" " .. L["(con %s)"]:format(re.quien))
			tip:AddLine(L["Receta: %s%s. Cada unidad rinde ≈ %s."]:format(re.rec.n or "?", quien, M.Dinero(re.valor)), r, gg, b, true)
		end
		if c.subasta and c.subasta.fuente == "otro" then
			tip:AddLine(L["Precio de la subasta tomado de otro addon de subastas."], r, gg, b, true)
		end
		tip:AddLine(L["Comisión de la subasta estimada: %d%%."]:format(floor(M.Comision() * 100 + 0.5)), r, gg, b, true)
	end
end

local function nuevaFila(view)
	local f = CreateFrame("Button", nil, view)
	f:SetHeight(FILA_H)
	W.Hover(f, 0.6)
	f.Regla = W.Divider(f, false, 0.6)
	f.Regla:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	f.Regla:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	f.Icono = f:CreateTexture(nil, "ARTWORK")
	f.Icono:SetSize(ICONO, ICONO)
	f.Icono:SetPoint("LEFT", f, "LEFT", 12, 0)
	f.Icono:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	f.Cuenta = W.Text(f, "number", "text", "OVERLAY")
	f.Cuenta:SetJustifyH("RIGHT")
	f.Cuenta:SetPoint("BOTTOMRIGHT", f.Icono, "BOTTOMRIGHT", 1, 0)
	T.SetShadow(f.Cuenta, true)
	f.Nombre = W.Text(f, "body", "text")
	f.Nombre:SetPoint("TOPLEFT", f.Icono, "TOPRIGHT", 10, 1)
	f.Detalle = W.Text(f, "small", "textMuted")
	f.Detalle:SetPoint("BOTTOMLEFT", f.Icono, "BOTTOMRIGHT", 10, -1)
	f.Valor = W.Text(f, "number", "text")
	f.Valor:SetJustifyH("RIGHT")
	f.Valor:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -9)
	f.Extra = W.Text(f, "small", "success")
	f.Extra:SetJustifyH("RIGHT")
	f.Extra:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 9)
	f.Chip = W.Chip(f)
	f.Chip:SetPoint("RIGHT", f, "RIGHT", -(12 + VALOR_W + GAP), 0)
	f:RegisterForClicks("LeftButtonUp")
	f:SetScript("OnEnter", function(self)
		if self.psID then W.ItemTip(self, self.psID, self.psExtra) end
	end)
	f:SetScript("OnLeave", function(self) W.HideTooltip(self) end)
	f:SetScript("OnClick", function(self) if self.psID then W.ItemClick(self.psID) end end)
	return f
end

-- Lay out a row: chip, value and the two text lines in `width`.
local function pintarFila(f, ancho, d)
	f:SetWidth(ancho)
	f.psID, f.psExtra = d.id, d.extra
	f.Icono:SetTexture(d.icono)
	f.Cuenta:SetText(d.cuenta and d.cuenta > 1 and tostring(d.cuenta) or "")
	f.Nombre:SetText(d.nombre)
	f.Detalle:SetText(d.detalle or "")
	f.Valor:SetText(d.valor or "")
	f.Extra:SetText(d.extra2 or "")
	W.Color(f.Extra, d.colorExtra or "success")
	local chipW = d.chip and pintarChip(f.Chip, d.chip, d.colorChip) or 0
	f.Chip:SetShown(d.chip ~= nil)
	local texto = max(40, ancho - (12 + ICONO + 10) - (12 + VALOR_W + GAP + chipW + 10))
	f.Nombre:SetWidth(texto)
	f.Detalle:SetWidth(texto)
	f:Show()
	return FILA_H
end

---------------------------------------------------------------------------
-- Tarjetas de resumen y filtros
---------------------------------------------------------------------------

local function nuevaTarjeta(view)
	local t = CreateFrame("Frame", nil, view)
	t:SetHeight(70)
	T.Skin(t, "panel")
	t.Etiqueta = W.Text(t, "small", "textMuted")
	t.Etiqueta:SetPoint("TOPLEFT", t, "TOPLEFT", 14, -12)
	t.Valor = W.Text(t, "display", "text")
	t.Valor:SetPoint("TOPLEFT", t.Etiqueta, "BOTTOMLEFT", 0, -6)
	t.Nota = W.Text(t, "small", "textDim")
	t.Nota:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 14, 10)
	return t
end

local function pintarTarjeta(t, ancho, etiqueta, valor, nota, colorNota)
	t:SetWidth(ancho)
	t.Etiqueta:SetText(etiqueta)
	t.Etiqueta:SetWidth(ancho - 28)
	t.Valor:SetText(valor)
	t.Valor:SetWidth(ancho - 28)
	t.Nota:SetText(nota or "")
	t.Nota:SetWidth(ancho - 28)
	W.Color(t.Nota, colorNota or "textDim")
	t:Show()
end

local FILTROS = {
	{ "todos", "Todos", "accent" },
	{ "vender", "Vender", "quest" },
	{ "subastar", "Subastar", "success" },
	{ "transformar", "Transformar", "dungeon" },
	{ "guardar", "Guardar", "text" },
}

local function nuevoFiltro(view, def)
	local b = CreateFrame("Button", nil, view)
	b:SetHeight(W.CHIP_H + 4)
	b.Chip = W.Chip(b)
	b.Chip:SetPoint("LEFT", b, "LEFT", 0, 0)
	b.psClave = def[1]
	b:SetScript("OnClick", function(self)
		filtro = self.psClave
		relayout(view)
	end)
	b:SetScript("OnEnter", function(self) self.Chip:SetAlpha(1) end)
	b:SetScript("OnLeave", function(self) self.Chip:SetAlpha(filtro == self.psClave and 1 or 0.7) end)
	return b
end

---------------------------------------------------------------------------
-- Ajustes (las filas estándar de la ventana de opciones)
---------------------------------------------------------------------------

local function controles()
	local lista = {
		{ kind = "toggle", key = M.ID .. ".tooltip", label = L["Consejo en el cuadro de los objetos"],
			help = L["Al pasar el ratón sobre un objeto: su precio en la subasta, lo que paga el comerciante y qué te conviene."] },
		{ kind = "toggle", key = M.ID .. ".boton", label = L["Barra de Alfa en la casa de subastas"],
			help = L["El botón «Escanear con Alfa» bajo la ventana de la subasta."] },
		{ kind = "toggle", key = M.ID .. ".busquedas", label = L["Aprender de tus búsquedas"],
			help = L["Cuando buscas algo en la subasta, Alfa guarda el precio más bajo que ves."] },
		{ kind = "slider", key = M.ID .. ".comision", label = L["Comisión de la subasta"], min = 0, max = 15, step = 1,
			format = function(v) return ("%d%%"):format(floor((v or 0) + 0.5)) end,
			help = L["Lo que se queda la subasta de cada venta. Suele ser 5 % en la de tu facción y 15 % en la neutral. Es un estimado."] },
		{ kind = "dropdown", key = M.ID .. ".desencantar", label = L["Considerar desencantar"],
			choices = {
				{ value = "auto", text = L["Si tú o tus personajes pueden"] },
				{ value = "siempre", text = L["Siempre"] },
				{ value = "nunca", text = L["Nunca"] },
			},
			help = L["«Siempre» sirve si un amigo encantador te ayuda. Las tablas de desencantar son estimadas."] },
		{ kind = "slider", key = M.ID .. ".diasViejo", label = L["Avisar cuando los precios tengan más de"], min = 1, max = 14, step = 1,
			format = function(v) return L["%d días"]:format(floor((v or 0) + 0.5)) end,
			help = L["Los precios cambian: después de estos días Alfa te recuerda escanear otra vez."] },
	}
	if M.HayOtroPrecio() then
		lista[#lista + 1] = { kind = "toggle", key = M.ID .. ".respaldo", label = L["Usar los precios de otro addon de subastas si faltan"],
			help = L["Solo cuando Alfa no tiene precio para un objeto."] }
	end
	lista[#lista + 1] = { kind = "button", label = L["Borrar los precios de este reino"], button = L["Borrar"], danger = true,
		icon = "reset", confirm = true, confirmTitle = L["¿Borrar los precios?"],
		confirmText = L["Se borran los precios guardados de la subasta de este reino y facción. Tus recetas se quedan."],
		confirmAction = L["Borrar"], onClick = function() M.Olvidar() end }
	return lista
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

local function construir(view)
	pagina = view
	local filas, filasRecetas = {}, {}
	local resumenH = W.SectionHeader(view)
	local tarjetas = { nuevaTarjeta(view), nuevaTarjeta(view), nuevaTarjeta(view) }
	local estadoChip = W.Chip(view)
	local estadoTexto = W.Text(view, "note", "textDim")
	estadoTexto:SetWordWrap(true)
	estadoTexto:SetJustifyV("TOP")
	local escanear = W.Button(view, L["Escanear ahora"], function()
		M.Escanear()
		relayout(view)
	end, { primary = true, icon = "search" })
	local filtros = {}
	for i, def in ipairs(FILTROS) do filtros[i] = nuevoFiltro(view, def) end
	local listaH = W.SectionHeader(view)
	local vacio = W.Text(view, "note", "textMuted")
	vacio:SetWordWrap(true)
	local recetasH = W.SectionHeader(view)
	W.SetSection(recetasH, L["Tus recetas que dejan ganancia"])
	local recetasNota = W.Text(view, "note", "textMuted")
	recetasNota:SetWordWrap(true)
	local comoH = W.SectionHeader(view)
	W.SetSection(comoH, L["Cómo decide Alfa"])
	local comoTexto = W.Text(view, "note", "textDim")
	comoTexto:SetWordWrap(true)
	comoTexto:SetSpacing(3)
	comoTexto:SetJustifyV("TOP")
	local ajustesH = W.SectionHeader(view)
	W.SetSection(ajustesH, L["Ajustes"])
	local panel = W.RowPanel(view)
	local cache = {}
	local lista

	view.Refresh = function()
		local ancho = anchoCuerpo()
		local x = pad()
		local y = 8
		local datos, tot, pendientes = analizar()

		-- Resumen
		resumenH:ClearAllPoints()
		resumenH:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		resumenH:SetWidth(ancho)
		W.SetSection(resumenH, L["Tus bolsas"])
		y = y + 44 + 4
		local tw = floor((ancho - 2 * GAP) / 3)
		local extra = tot.consejo - tot.comerciante
		local pct = tot.comerciante > 0 and M.Porcentaje(extra / tot.comerciante) or nil
		pintarTarjeta(tarjetas[1], tw, L["Si sigues los consejos"], M.Dinero(tot.consejo), L["%d objetos distintos"]:format(tot.cuenta.todos))
		pintarTarjeta(tarjetas[2], tw, L["Si vendes todo al comerciante"], M.Dinero(tot.comerciante), L["lo más fácil"])
		pintarTarjeta(tarjetas[3], tw, L["Ganas de más"], (extra > 0 and "+" or "") .. M.Dinero(max(0, extra)),
			pct and extra > 0 and L["%s contra el comerciante"]:format(pct) or L["sin diferencia"], extra > 0 and "success" or "textDim")
		for i, t in ipairs(tarjetas) do
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", view, "TOPLEFT", x + (i - 1) * (tw + GAP), -y)
		end
		y = y + 70 + 14

		-- Estado de los precios
		local fecha, objetos = M.Escaneo()
		local cuantos = M.CuantosPrecios()
		local chipTexto, chipColor, texto
		if cuantos == 0 and not M.HayOtroPrecio() then
			chipTexto, chipColor = L["Sin precios"], "warning"
			texto = L["Abre la casa de subastas y pulsa «Escanear con Alfa» para saber cuánto valen tus objetos."]
		elseif not fecha then
			chipTexto, chipColor = L["Pocos precios"], "warning"
			texto = L["Tienes %s precios de tus búsquedas. Para conocer todos, escanea en la casa de subastas."]:format(M.Miles(cuantos))
		elseif M.Viejo(fecha) then
			chipTexto, chipColor = L["Precios viejos"], "warning"
			texto = L["Tu último escaneo fue %s. Escanea otra vez en la casa de subastas para tener precios al día."]:format(M.Hace(fecha))
		else
			chipTexto, chipColor = L["Precios al día"], "success"
			texto = L["Último escaneo %s · %s objetos con precio."]:format(M.Hace(fecha), M.Miles(objetos or cuantos))
		end
		if tot.sinPrecio > 0 then
			texto = texto .. " " .. L["%d de tus objetos aún no tienen precio de subasta."]:format(tot.sinPrecio)
		end
		if M.HayOtroPrecio() and M.Ajuste("respaldo") then
			texto = texto .. " " .. L["Si falta un precio, Alfa usa el de tu otro addon de subastas."]
		end
		local cw = pintarChip(estadoChip, chipTexto, chipColor)
		estadoChip:ClearAllPoints()
		estadoChip:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		local abierta = M.SubastaAbierta()
		escanear:SetShown(abierta)
		local derecha = 0
		if abierta then
			local espera = M.EsperaEscaneo()
			local est = M.EstadoEscaneo()
			if est ~= "listo" then
				W.SetButtonText(escanear, L["Escaneando..."])
				escanear:Disable()
			elseif espera > 0 then
				W.SetButtonText(escanear, L["Espera %s"]:format(L["%d min"]:format(math.ceil(espera / 60))))
				escanear:Disable()
			else
				W.SetButtonText(escanear, L["Escanear ahora"])
				escanear:Enable()
			end
			escanear:SetAlpha(escanear:IsEnabled() and 1 or 0.55)
			escanear:ClearAllPoints()
			escanear:SetPoint("TOPRIGHT", view, "TOPRIGHT", -(x), -(y - 4))
			derecha = escanear:GetWidth() + GAP
		end
		estadoTexto:ClearAllPoints()
		estadoTexto:SetPoint("TOPLEFT", view, "TOPLEFT", x + cw + 10, -(y + 3))
		estadoTexto:SetWidth(max(80, ancho - cw - 10 - derecha))
		estadoTexto:SetText(texto)
		y = y + max(W.CHIP_H, estadoTexto:GetStringHeight() + 3, abierta and 28 or 0) + 18

		-- Filtros
		local fx = x
		for i, def in ipairs(FILTROS) do
			local b = filtros[i]
			local activo = filtro == def[1]
			local n = tot.cuenta[def[1]] or 0
			local w = pintarChip(b.Chip, L[def[2]] .. "  " .. n, activo and def[3] or nil)
			b.Chip:SetAlpha(activo and 1 or 0.7)
			b:SetWidth(w)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", view, "TOPLEFT", fx, -y)
			b:Show()
			fx = fx + w + 6
		end
		y = y + W.CHIP_H + 14

		-- Lista
		listaH:ClearAllPoints()
		listaH:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		listaH:SetWidth(ancho)
		local visibles = {}
		for _, g in ipairs(datos) do
			if filtro == "todos" or g.cat == filtro then visibles[#visibles + 1] = g end
		end
		W.SetSection(listaH, L["¿Qué hago con mis objetos?"], #visibles)
		y = y + 44 + 4
		for i, g in ipairs(visibles) do
			local f = filas[i]
			if not f then
				f = nuevaFila(view)
				filas[i] = f
			end
			local c = g.c
			local chip, colorChip = M.ChipDe(c)
			local valor, extra2, colorExtra
			if c.mejor == "guardar" then
				valor, extra2, colorExtra = hexColor("textMuted") .. "—|r", nil, nil
			else
				valor = M.Dinero(g.total)
				if c.ganancia and c.ganancia > 0.005 then
					extra2 = M.Porcentaje(c.ganancia)
				elseif c.mejor == "vender" then
					extra2, colorExtra = L["al comerciante"], "textMuted"
				end
			end
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
			y = y + pintarFila(f, ancho, {
				id = g.id, icono = iconoObjeto(g.id, c.info), cuenta = g.cantidad,
				nombre = colorCalidad(c.info.calidad) .. tostring(c.info.nombre) .. "|r"
					.. (c.mejor ~= "vender" and c.mejor ~= "guardar" and (hexColor("textMuted") .. "  ·  " .. M.TextoMejor(c) .. "|r") or ""),
				detalle = detalleDe(c), valor = valor, extra2 = extra2, colorExtra = colorExtra,
				chip = chip, colorChip = colorChip, extra = extraCuadro(g),
			})
		end
		for i = #visibles + 1, #filas do filas[i]:Hide() end
		if #visibles == 0 then
			if pendientes > 0 then
				vacio:SetText(L["Cargando la información de tus objetos..."])
			elseif tot.cuenta.todos == 0 then
				vacio:SetText(L["Tus bolsas están vacías."])
			else
				vacio:SetText(L["Nada en este grupo."])
			end
			vacio:SetWidth(ancho)
			vacio:ClearAllPoints()
			vacio:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
			vacio:Show()
			y = y + vacio:GetStringHeight() + 12
		else
			vacio:Hide()
		end
		y = y + 18

		-- Recetas
		recetasH:ClearAllPoints()
		recetasH:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		recetasH:SetWidth(ancho)
		y = y + 44 + 4
		local todas = M.TodasLasRecetas()
		local buenas, incompletas = {}, 0
		for _, e in ipairs(todas) do
			local valor, costo, completo = M.CuentaReceta(e.rec)
			if completo then
				if valor > costo then
					buenas[#buenas + 1] = { e = e, valor = valor, costo = costo, gana = valor - costo }
				end
			else
				incompletas = incompletas + 1
			end
		end
		table.sort(buenas, function(a, b) return a.gana > b.gana end)
		local nr = min(#buenas, MAX_RECETAS)
		for i = 1, nr do
			local b = buenas[i]
			local f = filasRecetas[i]
			if not f then
				f = nuevaFila(view)
				filasRecetas[i] = f
			end
			local rec, e = b.e.rec, b.e
			local quien = e.propio and "" or ("  ·  " .. L["con %s"]:format(e.quien or "?"))
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
			y = y + pintarFila(f, ancho, {
				id = rec.o, icono = iconoObjeto(rec.o, M.InfoObjeto(rec.o)), cuenta = rec.q and floor(rec.q) or 1,
				nombre = tostring(rec.n) .. hexColor("textMuted") .. "  ·  " .. tostring(rec.p or "") .. quien .. "|r",
				detalle = L["Reactivos %s  ·  el producto vale %s"]:format(M.Dinero(b.costo), M.Dinero(b.valor)),
				valor = "+" .. M.Dinero(b.gana),
				extra2 = b.costo > 0 and M.Porcentaje(b.gana / b.costo) or nil,
				chip = L["Transformar"], colorChip = "dungeon",
			})
		end
		for i = nr + 1, #filasRecetas do filasRecetas[i]:Hide() end
		local nota
		if #todas == 0 then
			nota = L["Abre la ventana de tu profesión una vez y Alfa leerá tus recetas para decirte cuáles te dejan ganancia."]
		elseif nr == 0 then
			nota = L["Ninguna de tus recetas deja ganancia con los precios que tienes."]
		else
			nota = nil
		end
		if incompletas > 0 then
			local t = L["%d recetas no se pueden calcular porque faltan precios de sus reactivos o su producto."]:format(incompletas)
			nota = nota and (nota .. " " .. t) or t
		end
		if nota then
			recetasNota:SetText(nota)
			recetasNota:SetWidth(ancho)
			recetasNota:ClearAllPoints()
			recetasNota:SetPoint("TOPLEFT", view, "TOPLEFT", x, -(y + 6))
			recetasNota:Show()
			y = y + 6 + recetasNota:GetStringHeight() + 12
		else
			recetasNota:Hide()
		end
		y = y + 18

		-- Cómo decide
		comoH:ClearAllPoints()
		comoH:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		comoH:SetWidth(ancho)
		y = y + 44 + 6
		comoTexto:SetText(table.concat({
			L["Para cada objeto Alfa compara tres caminos: venderlo al comerciante, ponerlo en la subasta o transformarlo (con una receta que conoces o desencantándolo)."],
			L["En la subasta cuenta el precio más bajo que vio, menos la comisión (%d%%, estimada). Al desencantar usa tablas del juego clásico, también estimadas."]:format(floor(M.Comision() * 100 + 0.5)),
			L["Recomienda el camino que te deja más oro, si gana por lo menos un 10 % a venderlo. Si nada da oro, te dice que lo guardes. Alfa nunca vende ni compra por ti."],
		}, "\n\n"))
		comoTexto:SetWidth(ancho)
		comoTexto:ClearAllPoints()
		comoTexto:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		y = y + comoTexto:GetStringHeight() + 22

		-- Ajustes
		local O = opciones()
		if O and type(O.Rows) == "function" then
			ajustesH:ClearAllPoints()
			ajustesH:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
			ajustesH:SetWidth(ancho)
			ajustesH:Show()
			y = y + 44 + 4
			lista = lista or controles()
			y = O.Rows(view, lista, y, cache, panel)
		else
			ajustesH:Hide()
			panel:Hide()
		end
		return y + 24
	end
end

---------------------------------------------------------------------------
-- Módulo, comandos y avisos
---------------------------------------------------------------------------

N.Modulo({
	id = M.ID, nombre = L["Comercio"], icono = "qol-coin", orden = 45, comando = M.ID,
	subtitulo = L["¿Vender, subastar o transformar? Lo que más oro te deja con cada objeto."],
	ajustes = {
		tooltip = true, boton = true, busquedas = true, respaldo = true,
		comision = 5, desencantar = "auto", diasViejo = 3,
	},
	construir = construir,
})

-- /alfa comercio [escanear | precio <objeto>]
local function comando(resto)
	resto = type(resto) == "string" and resto or ""
	local verbo, arg = resto:match("^%s*(%S*)%s*(.-)%s*$")
	verbo = (verbo or ""):lower()
	if verbo == "escanear" or verbo == "scan" then
		M.Escanear()
		return
	end
	if verbo == "precio" or verbo == "price" then
		local id = tonumber((arg or ""):match("item:(%d+)") or arg)
		if not id then
			N.Imprimir(L["Uso: /alfa comercio precio <enlace del objeto>"])
			return
		end
		local c = M.Consejo(id)
		local uno, dos = M.LineasCuadro(c)
		if not uno then
			N.Imprimir(L["Aún no conozco ese objeto. Pásale el ratón encima y vuelve a intentarlo."])
			return
		end
		N.Imprimir((c.info.link or c.info.nombre or "") .. "  " .. uno)
		N.Imprimir(dos)
		return
	end
	N.Abrir(M.ID)
end
A.RegisterCommand(M.ID, comando, L["¿Vender, subastar o transformar? (escanear, precio <objeto>)"])

A.On("ALFA_COMERCIO", relayoutLuego)
A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" or path == "" or path:sub(1, #M.ID + 1) == M.ID .. "." then
		M.Cambio()
	end
end)
A.RegisterEvent("BAG_UPDATE_DELAYED", relayoutLuego)
A.RegisterEvent("GET_ITEM_INFO_RECEIVED", relayoutLuego)
A.RegisterEvent("AUCTION_HOUSE_SHOW", relayoutLuego)
A.RegisterEvent("AUCTION_HOUSE_CLOSED", relayoutLuego)
