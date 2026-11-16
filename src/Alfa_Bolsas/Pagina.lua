-- Alfa - Bolsas: la página "Bolsas" en la ventana de Alfa. GPL-3.0.
--
-- Arriba, dos accesos (tus bolsas, tu banco); luego los ajustes en paneles
-- como los del resto de Alfa (vista, tamaño, columnas, reemplazar las de
-- Blizzard, ordenar, cada marca) y al final la lista de tus personajes con
-- lo que lleva cada uno, para ver sus bolsas o su banco, u olvidarlo.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D, V, R = M.Datos, M.Ventana, M.Reemplazo
local W, T = A.Widgets, A.Theme

local type, pairs, ipairs, tonumber, floor, max = type, pairs, ipairs, tonumber, math.floor, math.max

local P = {}
M.Pagina = P

local GAP, SECCION = 12, 22

local function ancho()
	local O = A.UI and A.UI.Options
	local f = O and O.frame
	local w = f and tonumber(f.BodyWidth)
	return w or 640
end

local function margen()
	local s = W.SHELL
	return (s and tonumber(s.pad)) or 32
end

local function ruta(clave) return M.ID .. "." .. clave end

local ajustes = {
	{ seccion = L["Ventana"], filas = {
		{ "dropdown", "vista", L["Vista"], L["Por categorías agrupa tus cosas (equipo, consumibles, misiones...) con encabezados que se pliegan; una sola bolsa las muestra todas juntas, en su lugar."],
			{ { value = "categorias", text = L["Por categorías"] }, { value = "una", text = L["Una sola bolsa"] } } },
		{ "slider", "tamIcono", L["Tamaño de los iconos"], L["Qué tan grande se ve cada casilla."], 28, 48, 1 },
		{ "slider", "columnas", L["Columnas"], L["Cuántas casillas caben en cada fila."], 6, 20, 1 },
		{ "toggle", "reemplazar", L["Usar las bolsas de Alfa"], L["Con la B, Mayús+B, la tecla de cada bolsa o al visitar un comerciante se abre la ventana de Alfa en lugar de las bolsas de Blizzard. Apágalo para volver a las de Blizzard."] },
		{ "toggle", "banco", L["Usar el banco de Alfa"], L["Al visitar a un banquero se abre el banco de Alfa. La primera vez que un personaje visita el banco verás el de Blizzard: así el juego le da su primera pestaña."], depende = "reemplazar", hijo = true },
		{ "toggle", "llavero", L["Mostrar el llavero"], L["Tus llaves junto a tus bolsas."] },
	} },
	{ seccion = L["Ordenar"], filas = {
		{ "toggle", "ordenar", L["Botón Ordenar"], L["Junta los montones y acomoda tus objetos con un clic."] },
		{ "toggle", "ordenarInverso", L["Ordenar de derecha a izquierda"], L["Los objetos se juntan al final de tus bolsas en lugar de al principio."] },
	} },
	{ seccion = L["Marcas sobre cada objeto"], filas = {
		{ "toggle", "marcaNivel", L["Nivel de objeto"], L["El número abajo a la izquierda de cada pieza de equipo."] },
		{ "toggle", "marcaCalidad", L["Borde de calidad"], L["Un borde del color de la calidad: verde, azul, morado..."] },
		{ "toggle", "marcaChatarra", L["Chatarra"], L["Una moneda sobre lo gris: lo que solo sirve para vender."] },
		{ "toggle", "marcaNuevos", L["Objetos nuevos"], L["Brillan los objetos que acabas de conseguir, hasta que cierras las bolsas."] },
		{ "toggle", "marcaMejora", L["Flecha de mejora"], L["Una flecha verde en el equipo que es mejor que lo que llevas puesto, según tu clase y nivel."] },
		{ "toggle", "marcaMision", L["Objetos de misión"], L["Un marco dorado en lo que sirve para una misión (con «!» si empieza una)."] },
		{ "toggle", "cuadroConteo", L["Cuántos tienes, en el cuadro de cada objeto"], L["Al pasar el ratón por un objeto: «Tienes 12 (Toxic: 7 en bolsas, Alt: 5 en banco)», con todos tus personajes."] },
	} },
}

local function crearFila(view, f)
	local tipo, clave, texto, ayuda = f[1], f[2], f[3], f[4]
	local w
	if tipo == "dropdown" then
		w = W.Dropdown(view, texto, ruta(clave), f[5], ayuda)
	elseif tipo == "slider" then
		w = W.Slider(view, texto, ruta(clave), f[5], f[6], f[7], "%d", ayuda)
	else
		w = W.Toggle(view, texto, ruta(clave), ayuda, f.depende and ruta(f.depende) or nil)
	end
	W.RowDetails(w, { inset = f.hijo and 40 or 16, child = f.hijo })
	return w
end

-- Una fila por personaje: nombre, detalle, inventario y botones.
local function filaPersonaje(view)
	local row = CreateFrame("Frame", nil, view)
	row.Nombre = W.Text(row, "body", "text")
	row.Nombre:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -10)
	row.Detalle = W.Text(row, "small", "textMuted")
	row.Detalle:SetPoint("TOPLEFT", row.Nombre, "BOTTOMLEFT", 0, -3)
	row.Inventario = W.Text(row, "small", "textDim")
	row.Inventario:SetWordWrap(true)
	row.Inventario:SetJustifyV("TOP")
	row.Inventario:SetPoint("TOPLEFT", row.Detalle, "BOTTOMLEFT", 0, -3)
	row.Olvidar = W.Button(row, L["Olvidar"], function(self)
		local k = self:GetParent().clave
		local r = D.Personaje(k)
		if not r then return end
		W.Modal({
			title = L["Olvidar a este personaje"],
			text = (L["Alfa borrará lo que guardó de %s: sus bolsas, su banco y su equipo. Si vuelves a jugar con él, se guarda de nuevo."]):format(tostring(r.nombre or k)),
			icon = "reset", action = L["Olvidar"], danger = true,
			onAccept = function()
				D.Olvidar(k)
				P.Relayout()
			end,
		})
	end, { height = 24, danger = true })
	row.Banco = W.Button(row, L["Banco"], function(self) V.MostrarBanco(self:GetParent().clave) end, { height = 24 })
	row.Bolsas = W.Button(row, L["Bolsas"], function(self)
		local f = V.Ventana("bolsas")
		V.Ver(f, self:GetParent().clave)
	end, { height = 24 })
	row.Olvidar:SetPoint("RIGHT", row, "RIGHT", -12, 0)
	row.Banco:SetPoint("RIGHT", row.Olvidar, "LEFT", -6, 0)
	row.Bolsas:SetPoint("RIGHT", row.Banco, "LEFT", -6, 0)
	row.Linea = W.Divider(row, false, 0.6)
	row.Linea:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.Linea:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	return row
end

local function textoInventario(r)
	local objetos, ocupadas, total = D.Resumen(r.bolsas)
	local partes = { (L["Bolsas: %d objetos en %d de %d casillas"]):format(objetos, ocupadas, total) }
	local piezas = 0
	if type(r.equipo) == "table" then for _ in pairs(r.equipo) do piezas = piezas + 1 end end
	if piezas > 0 then partes[#partes + 1] = (L["Equipo: %d piezas"]):format(piezas) end
	if r.bancoVisto then
		local bo, bocc = D.Resumen(r.banco)
		partes[#partes + 1] = (L["Banco: %d objetos en %d casillas (foto: %s)"]):format(bo, bocc, M.Hace(r.bancoVisto))
	else
		partes[#partes + 1] = L["Banco: sin foto todavía"]
	end
	return table.concat(partes, "  ·  ")
end

function M.ConstruirPagina(view)
	P.view = view
	local tiles = {
		W.ActionTile(view, "icon-collect", L["Abrir mis bolsas"], L["Tu ventana de bolsas de Alfa. También con la B."], function() V.MostrarBolsas(true) end),
		W.ActionTile(view, "icon-treasure", L["Ver mi banco"], L["En vivo si estás con un banquero; si no, la última foto que guardó Alfa."], function() V.MostrarBanco(nil) end),
	}
	local aviso = W.Text(view, "note", "warning")
	aviso:SetWordWrap(true)
	aviso:SetJustifyV("TOP")

	local secciones = {}
	for _, s in ipairs(ajustes) do
		local h = W.SectionHeader(view, { plain = true })
		W.SetSection(h, s.seccion)
		local sec = { cab = h, panel = W.RowPanel(view), filas = {} }
		for _, f in ipairs(s.filas) do sec.filas[#sec.filas + 1] = crearFila(view, f) end
		secciones[#secciones + 1] = sec
	end

	local cabPj = W.SectionHeader(view, { plain = true })
	W.SetSection(cabPj, L["Tus personajes"])
	local panelPj = W.RowPanel(view)
	local cuenta = W.InfoRow(view, L["Dinero de toda la cuenta"], L["La suma de lo que guardó Alfa de cada personaje (el tuyo, al día)."])
	W.RowDetails(cuenta, { inset = 16, marks = false })
	local vacia = W.Text(view, "note", "textMuted")
	vacia:SetWordWrap(true)
	vacia:SetText(L["Aún no hay personajes guardados."])
	local filas = {}

	view.Refresh = function()
		local w = ancho()
		local x = margen()
		local y = 8

		-- Accesos, lado a lado.
		local cw = floor((w - GAP) / 2)
		local th = 0
		for i, t in ipairs(tiles) do
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", view, "TOPLEFT", x + (i - 1) * (cw + GAP), -y)
			t:Show()
			th = max(th, tonumber(W.LayoutTile(t, cw)) or 60)
		end
		for _, t in ipairs(tiles) do t:SetHeight(th) end
		y = y + th + 14

		local motivo
		if R.Conflicto() then
			motivo = (L["Tienes otro addon de bolsas activo (%s): mientras lo esté, Alfa no reemplaza tus bolsas. Igual puedes abrir la ventana de Alfa desde aquí."]):format(R.Conflicto())
		elseif R.Mando() then
			motivo = L["Con la interfaz para mando, Alfa deja las bolsas del juego. Igual puedes abrir la ventana de Alfa desde aquí."]
		end
		if motivo then
			aviso:SetText(motivo)
			aviso:SetWidth(w)
			aviso:ClearAllPoints()
			aviso:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
			aviso:Show()
			y = y + aviso:GetStringHeight() + 14
		else
			aviso:Hide()
		end

		for _, sec in ipairs(secciones) do
			sec.cab:ClearAllPoints()
			sec.cab:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
			sec.cab:SetWidth(w)
			sec.cab:Show()
			y = y + (tonumber(W.PLAIN_SECTION_H) or 30)
			local top = y
			for i, row in ipairs(sec.filas) do
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
				row:Show()
				if row.Refresh then row:Refresh() end
				y = y + (tonumber(W.LayoutRow(row, w)) or 50)
				if row.Rule then row.Rule:SetShown(i < #sec.filas) end
			end
			sec.panel:ClearAllPoints()
			sec.panel:SetPoint("TOPLEFT", view, "TOPLEFT", x, -top)
			sec.panel:SetSize(w, max(1, y - top))
			sec.panel:SetShown(T.SkinKey and T.SkinKey() == "alfa")
			y = y + SECCION
		end

		-- Tus personajes.
		cabPj:ClearAllPoints()
		cabPj:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		cabPj:SetWidth(w)
		local lista = D.Lista()
		W.SetSection(cabPj, L["Tus personajes"], #lista)
		y = y + (tonumber(W.PLAIN_SECTION_H) or 30)
		local top = y
		cuenta.Value:SetText(N.Dinero(D.DineroCuenta(), true))
		cuenta:ClearAllPoints()
		cuenta:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		cuenta:Show()
		y = y + (tonumber(W.LayoutRow(cuenta, w)) or 50)
		if #lista == 0 then
			vacia:SetWidth(w - 32)
			vacia:ClearAllPoints()
			vacia:SetPoint("TOPLEFT", view, "TOPLEFT", x + 16, -(y + 10))
			vacia:Show()
			y = y + vacia:GetStringHeight() + 20
		else
			vacia:Hide()
		end
		local actual = D.Clave()
		for i, p in ipairs(lista) do
			local row = filas[i]
			if not row then
				row = filaPersonaje(view)
				filas[i] = row
			end
			local r = p.r
			row.clave = p.clave
			local cr, cg, cb = M.ColorClase(r.clase)
			local nombre = M.Pintado(r.nombre or p.clave, cr, cg, cb)
			if p.clave == actual then nombre = nombre .. "  " .. M.Pintado(L["(tú)"], M.Color("textMuted")) end
			row.Nombre:SetText(nombre)
			local detalle = {}
			if tonumber(r.nivel) then detalle[#detalle + 1] = (L["Nivel %d"]):format(r.nivel) end
			if type(r.reino) == "string" then detalle[#detalle + 1] = r.reino end
			local faccion = A.FactionName and A.FactionName(r.faccion)
			if type(faccion) == "string" then detalle[#detalle + 1] = faccion end
			local dinero = (p.clave == actual and M.Num(GetMoney and GetMoney())) or tonumber(r.dinero) or 0
			detalle[#detalle + 1] = N.Dinero(dinero, true)
			if p.clave ~= actual then detalle[#detalle + 1] = (L["visto %s"]):format(M.Hace(r.visto)) end
			row.Detalle:SetText(table.concat(detalle, "  ·  "))
			row.Inventario:SetText(textoInventario(r))
			row.Olvidar:SetShown(p.clave ~= actual)
			local botones = (row.Bolsas:GetWidth() or 0) + (row.Banco:GetWidth() or 0) + (row.Olvidar:GetWidth() or 0) + 40
			local texto = max(120, w - 16 - botones)
			row.Nombre:SetWidth(texto)
			row.Detalle:SetWidth(texto)
			row.Inventario:SetWidth(texto)
			local alto = max(64, floor(10 + 16 + 3 + 14 + 3 + (row.Inventario:GetStringHeight() or 14) + 12))
			row:SetSize(w, alto)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
			row:Show()
			row.Linea:SetShown(i < #lista)
			y = y + alto
		end
		for i = #lista + 1, #filas do filas[i]:Hide() end
		panelPj:ClearAllPoints()
		panelPj:SetPoint("TOPLEFT", view, "TOPLEFT", x, -top)
		panelPj:SetSize(w, max(1, y - top))
		panelPj:SetShown(T.SkinKey and T.SkinKey() == "alfa")
		return y + 24
	end
end

-- La página otra vez, donde está (un personaje olvidado, datos nuevos).
function P.Relayout()
	local view = P.view
	if not (view and view.Refresh and view:IsShown()) then return end
	local h = view.Refresh()
	view:SetHeight(h)
	local O = A.UI and A.UI.Options
	local win = O and O.frame
	if win and W.ShellBody then W.ShellBody(win, h) end
end

local pendiente = false
M.Escuchar("DATOS", function()
	if pendiente then return end
	pendiente = true
	M.Luego(1, function()
		pendiente = false
		P.Relayout()
	end)
end)
