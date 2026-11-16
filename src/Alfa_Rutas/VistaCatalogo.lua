-- Alfa - Rutas: la pestaña "Catálogo de objetos". Todos los objetos del
-- juego con búsqueda y filtros (tipo, subtipo, calidad, nivel, ranura y "lo
-- que puedo usar") en una lista virtual, y la ficha del elegido: calidad,
-- estadísticas, de dónde sale (el Lookup del motor) y los botones Guíame,
-- Agregar a mi ruta y Vincular en el chat. Toxic / La Jauría. GPL-3.0.

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local W, Th, K = M.W, M.T, M.Kit
local Cat = M.Catalogo
local VC = {}
M.VistaCatalogo = VC

local type, ipairs, pairs, tostring, tonumber = type, ipairs, pairs, tostring, tonumber
local floor, max, min, format, concat = math.floor, math.max, math.min, string.format, table.concat
local num = M.num

local LISTA_W, FILA_H = 360, 32
local c
local ui = {}
local est = { filtro = { orden = "nivel" }, filas = {}, sel = nil, avance = 0, cargando = false, motivo = nil }

local function LK() return M.Motor("Lookup") end
local function CP() return M.Motor("Compat") end

---------------------------------------------------------------------------
-- Filtrar
---------------------------------------------------------------------------

local function aplicar()
	local f = est.filtro
	f.usable = N.Get(M.ID, "soloUsables") and true or false
	f.retirados = N.Get(M.ID, "verRetirados") and true or false
	est.filas = Cat.Filtrar(f)
	if ui.lista then
		ui.lista.inicio = 1
		ui.lista:Datos(#est.filas)
	end
	VC.PintarBarra()
end

local ficha = 0
local function luego()
	ficha = ficha + 1
	local mia = ficha
	A.After(0.2, function() if mia == ficha then aplicar() end end)
end

local function nombreCalidad(q)
	return (A.QualityName and A.QualityName(q)) or tostring(q)
end

local function menuTipo(b)
	local f = est.filtro
	local items = { { texto = L["Todos los tipos"], checked = f.tipo == nil, onClick = function()
		f.tipo, f.sub, f.subLista = nil, nil, nil
		aplicar()
	end }, { separator = true } }
	for _, t in ipairs(Cat.Tipos()) do
		items[#items + 1] = { texto = format("%s  (%s)", t.nombre, M.Miles(t.cuenta)), checked = f.tipo == t.clase, onClick = function()
			f.tipo, f.sub, f.subLista = t.clase, nil, nil
			aplicar()
		end }
	end
	K.Menu(b, items, 200)
end

local function menuSub(b)
	local f = est.filtro
	if not f.tipo then
		K.Aviso(L["Primero elige un tipo (por ejemplo, Armas)."])
		return
	end
	local items = { { texto = L["Todos"], checked = f.sub == nil, onClick = function()
		f.sub, f.subLista = nil, nil
		aplicar()
	end }, { separator = true } }
	for _, s in ipairs(Cat.Subtipos(f.tipo)) do
		items[#items + 1] = { texto = format("%s  (%s)", s.nombre, M.Miles(s.cuenta)), checked = f.sub == s.clave, onClick = function()
			f.sub, f.subLista, f.subNombre = s.clave, s.sub, s.nombre
			aplicar()
		end }
	end
	K.Menu(b, items, 220)
end

local function menuCalidad(b)
	local f = est.filtro
	local items = { { texto = L["Cualquier calidad"], checked = f.calidad == nil, onClick = function() f.calidad = nil aplicar() end }, { separator = true } }
	for q = 0, 5 do
		items[#items + 1] = { texto = nombreCalidad(q), checked = f.calidad == q, onClick = function() f.calidad = q aplicar() end }
	end
	K.Menu(b, items, 180)
end

local function menuNivel(b)
	local f = est.filtro
	local items = {}
	for _, n in ipairs(Cat.NIVELES) do
		items[#items + 1] = { texto = n.nombre, checked = (f.nivel or "todos") == n.clave, onClick = function() f.nivel = n.clave aplicar() end }
	end
	K.Menu(b, items, 180)
end

local function menuRanura(b)
	local f = est.filtro
	local items = { { texto = L["Cualquier ranura"], checked = f.ranura == nil, onClick = function() f.ranura = nil aplicar() end }, { separator = true } }
	for _, r in ipairs(Cat.RANURAS) do
		items[#items + 1] = { texto = r.nombre, checked = f.ranura == r.clave, onClick = function() f.ranura = r.clave aplicar() end }
	end
	K.Menu(b, items, 180)
end

local function menuOrden(b)
	local f = est.filtro
	local items = {}
	for _, o in ipairs(Cat.ORDENES) do
		items[#items + 1] = { texto = o.nombre, checked = f.orden == o.clave, onClick = function() f.orden = o.clave aplicar() end }
	end
	items[#items + 1] = { separator = true }
	items[#items + 1] = { texto = L["Mostrar los que ya no se consiguen"], checked = N.Get(M.ID, "verRetirados") and true or false, onClick = function()
		N.Set(M.ID, "verRetirados", not N.Get(M.ID, "verRetirados"))
		aplicar()
	end }
	K.Menu(b, items, 220)
end

local function limpiar()
	local orden = est.filtro.orden
	est.filtro = { orden = orden }
	if ui.buscar then ui.buscar:SetText("") end
	aplicar()
end

---------------------------------------------------------------------------
-- Las acciones de la ficha
---------------------------------------------------------------------------

local MOTIVOS = {
	tabs = L["Tienes 6 guías abiertas: cierra una pestaña para abrir otra."],
	mount = L["Para una montura mira el Buscador: dice qué nivel, equitación y oro pide."],
	disabled = L["El Buscador del motor está apagado (Opciones > Descubrir > Buscador)."],
	nosource = L["Alfa no sabe de dónde sale este objeto."],
	noguide = L["No hay un camino que Alfa pueda guiar para este objeto (sale al azar o dentro de una mazmorra)."],
	nolocation = L["No se sabe dónde está quien lo da o lo suelta."],
	login = L["Espera a entrar al mundo."],
	combat = L["Espera a salir de combate."],
}

local function guiame(id, kind)
	local Lk = LK()
	if not (Lk and Lk.Guide) then return K.Aviso(L["El Buscador del motor no está disponible."]) end
	local gid, motivo = Lk.Guide(kind or "item", id)
	if gid then
		if A.Set then A.Set("ui.shown", true) end
		K.Aviso(format(L["Guía abierta: %s. Sigue la flecha."], M.NombreObjeto(id)))
		return
	end
	K.Aviso(MOTIVOS[motivo] or format(L["No se pudo armar la guía (%s)."], tostring(motivo or "?")))
end

local function vincular(id)
	local Cp = CP()
	local link = Cp and Cp.ItemLink and Cp.ItemLink(id)
	if not link then
		if Cp and Cp.RequestItem then Cp.RequestItem(id) end
		return K.Aviso(L["El juego aún está cargando este objeto: toca Vincular otra vez en un momento."])
	end
	if A.GamepadUI and A.GamepadUI() then return K.Aviso(link) end
	local U = ChatFrameUtil
	if U and U.InsertLink and U.InsertLink(link) then return end
	if U and U.OpenChat then
		U.OpenChat(link)
	elseif ChatEdit_InsertLink then
		ChatEdit_InsertLink(link)
	else
		K.Aviso(link)
	end
end

local function agregar(id)
	if M.AgregarObjeto then M.AgregarObjeto(id) end
end

local function buscador(id, kind)
	local Lk = LK()
	if Lk and Lk.Show then Lk.Show(nil, kind or "item", id) end
end

---------------------------------------------------------------------------
-- Filas de la lista
---------------------------------------------------------------------------

local function fila(lista)
	local b = K.Fila(lista)
	b.Icono = b:CreateTexture(nil, "ARTWORK")
	b.Icono:SetSize(24, 24)
	b.Icono:SetPoint("LEFT", b, "LEFT", 6, 0)
	b.Nombre = K.Texto(b, "label", "text")
	b.Nombre:SetPoint("TOPLEFT", b, "TOPLEFT", 38, -3)
	b.Nombre:SetPoint("RIGHT", b, "RIGHT", -6, 0)
	b.Linea = K.Texto(b, "small", "textMuted")
	b.Linea:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 38, 4)
	b.Linea:SetPoint("RIGHT", b, "RIGHT", -6, 0)
	b:SetScript("OnClick", function(self)
		local i = self.indice and est.filas[self.indice]
		local id = i and Cat.Fila(i) and Cat.Fila(i).id
		if not id then return end
		if W.ItemClick(id) then return end
		est.sel = id
		ui.lista:Refrescar()
		VC.PintarFicha()
	end)
	b:SetScript("OnEnter", function(self)
		local i = self.indice and est.filas[self.indice]
		local d = i and Cat.Fila(i)
		if d then W.ItemTip(self, d.id) end
	end)
	b:SetScript("OnLeave", W.HideTip)
	return b
end

local function pintar(b, k)
	local i = est.filas[k]
	local d = i and Cat.Fila(i)
	if not d then return b:Hide() end
	local Cp = CP()
	b.Icono:SetTexture(Cp and Cp.ItemIcon and Cp.ItemIcon(d.id) or 134400)
	b.Nombre:SetText(d.nombre or "")
	K.ColorCalidad(b.Nombre, d.calidad)
	b.Linea:SetText(Cat.Linea(i))
	b.Elegida:SetShown(est.sel == d.id)
end

---------------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------------

function VC.Construir(parent)
	c = CreateFrame("Frame", nil, parent)
	ui.buscar = W.SearchBox(c, { L["Busca por nombre: espada, mena, poción..."], L["Buscar objetos"] }, function(texto)
		est.filtro.texto = texto
		luego()
	end)
	ui.buscar:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	ui.buscar:SetWidth(280)
	ui.orden = K.BotonMenu(c, L["Ordenar"], menuOrden, 120)
	ui.orden:SetPoint("LEFT", ui.buscar, "RIGHT", 8, 0)
	ui.limpiar = W.Button(c, L["Limpiar"], limpiar, { ghost = true, icon = "reset" })
	ui.limpiar:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -1)
	ui.cuenta = K.Texto(c, "small", "textMuted")
	ui.cuenta:SetPoint("RIGHT", ui.limpiar, "LEFT", -8, 0)
	ui.cuenta:SetJustifyH("RIGHT")

	ui.filtros = {
		K.BotonMenu(c, L["Tipo"], menuTipo, 100),
		K.BotonMenu(c, L["Subtipo"], menuSub, 100),
		K.BotonMenu(c, L["Calidad"], menuCalidad, 100),
		K.BotonMenu(c, L["Nivel"], menuNivel, 100),
		K.BotonMenu(c, L["Ranura"], menuRanura, 100),
	}
	for i, b in ipairs(ui.filtros) do
		b:SetHeight(24)
		b.psHeight = 24
		if i == 1 then b:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -38) else b:SetPoint("LEFT", ui.filtros[i - 1], "RIGHT", 6, 0) end
	end
	ui.usable = W.Checkbox(c, function(self)
		N.Set(M.ID, "soloUsables", self:GetChecked() and true or false)
		aplicar()
	end)
	ui.usable:SetPoint("LEFT", ui.filtros[5], "RIGHT", 12, 0)
	ui.usableTxt = K.Texto(c, "label", "textDim")
	ui.usableTxt:SetPoint("LEFT", ui.usable, "RIGHT", 4, 0)
	ui.usableTxt:SetText(L["Puedo usar"])
	ui.usable.psTip = L["Solo lo que tu clase puede equipar o usar."]
	ui.usable:SetScript("OnEnter", W.SimpleTip)
	ui.usable:SetScript("OnLeave", W.HideTip)

	ui.panel = W.RowPanel(c)
	ui.lista = K.Lista(ui.panel, FILA_H, fila, pintar)
	ui.lista:SetPoint("TOPLEFT", ui.panel, "TOPLEFT", 4, -4)
	ui.lista:SetPoint("BOTTOMRIGHT", ui.panel, "BOTTOMRIGHT", -2, 4)
	ui.cargaTxt = K.Texto(ui.panel, "note", "textDim", true)
	ui.cargaTxt:SetPoint("TOPLEFT", ui.panel, "TOPLEFT", 20, -30)
	ui.cargaTxt:SetPoint("RIGHT", ui.panel, "RIGHT", -20, 0)
	ui.carga = W.ProgressLine(ui.panel, 3)
	ui.carga:SetPoint("TOPLEFT", ui.panel, "TOPLEFT", 20, -80)
	ui.carga:SetWidth(240)

	-- La ficha
	local fi = W.RowPanel(c)
	ui.ficha = fi
	ui.fIcono = fi:CreateTexture(nil, "ARTWORK")
	ui.fIcono:SetSize(40, 40)
	ui.fIcono:SetPoint("TOPLEFT", fi, "TOPLEFT", 14, -14)
	ui.fIconoBtn = CreateFrame("Button", nil, fi)
	ui.fIconoBtn:SetAllPoints(ui.fIcono)
	ui.fIconoBtn:SetScript("OnEnter", function(self) if est.sel then W.ItemTip(self, est.sel) end end)
	ui.fIconoBtn:SetScript("OnLeave", W.HideTip)
	ui.fIconoBtn:SetScript("OnClick", function() if est.sel then W.ItemClick(est.sel) end end)
	ui.fNombre = K.Texto(fi, "title", "text", true)
	ui.fNombre:SetPoint("TOPLEFT", fi, "TOPLEFT", 62, -14)
	ui.fNombre:SetPoint("RIGHT", fi, "RIGHT", -12, 0)
	ui.fLinea = K.Texto(fi, "small", "textDim", true)
	ui.fChips = { W.Chip(fi), W.Chip(fi), W.Chip(fi) }
	ui.fStats = K.Texto(fi, "small", "text", true)
	ui.fStats:SetSpacing(2)
	ui.fFuenteTit = K.Texto(fi, "heading", "text")
	ui.fFuenteTit:SetText(L["Cómo conseguirlo"])
	ui.fFuentes = K.Texto(fi, "small", "textDim", true)
	ui.fFuentes:SetSpacing(3)
	ui.fGuiame = W.Button(fi, L["Guíame"], function() local f = est.ficha if f then guiame(f.id, f.kind) end end, { primary = true, icon = "icon-goto" })
	ui.fGuiame.psTip = L["Alfa arma al momento una guía para conseguirlo."]
	ui.fAgregar = W.Button(fi, L["Agregar a mi ruta"], function() if est.sel then agregar(est.sel) end end, { icon = "plus" })
	ui.fAgregar.psTip = L["Lo suma como un tramo de Objeto a tu ruta (si la estás siguiendo, tu guía se actualiza)."]
	ui.fVincular = W.Button(fi, L["Vincular en el chat"], function() if est.sel then vincular(est.sel) end end, { ghost = true })
	ui.fBuscador = W.Button(fi, L["Buscador"], function() local f = est.ficha if f then buscador(f.id, f.kind) end end, { ghost = true, icon = "search" })
	ui.fBuscador.psTip = L["Todas sus fuentes en el Buscador de Alfa."]
	ui.fVacio = K.Texto(fi, "note", "textDim", true)
	ui.fVacio:SetPoint("TOPLEFT", fi, "TOPLEFT", 18, -24)
	ui.fVacio:SetPoint("RIGHT", fi, "RIGHT", -18, 0)
	ui.fVacio:SetText(L["Elige un objeto de la lista para ver qué es, de dónde sale y para que Alfa te lleve a conseguirlo."])
	return c
end

function VC.Visible() return c ~= nil and c:IsVisible() end

---------------------------------------------------------------------------
-- Pintar
---------------------------------------------------------------------------

function VC.PintarBarra()
	if not c then return end
	local f = est.filtro
	local tipo = f.tipo and Cat.NombreTipo(f.tipo) or L["Tipo"]
	W.SetButtonText(ui.filtros[1], tipo)
	W.SetButtonText(ui.filtros[2], f.sub and (f.subNombre or L["Subtipo"]) or L["Subtipo"])
	W.SetButtonText(ui.filtros[3], f.calidad and nombreCalidad(f.calidad) or L["Calidad"])
	local nivel = L["Nivel"]
	for _, n in ipairs(Cat.NIVELES) do if n.clave == f.nivel and n.clave ~= "todos" then nivel = n.nombre end end
	W.SetButtonText(ui.filtros[4], nivel)
	local ranura = L["Ranura"]
	for _, r in ipairs(Cat.RANURAS) do if r.clave == f.ranura then ranura = r.nombre end end
	W.SetButtonText(ui.filtros[5], ranura)
	for _, b in ipairs(ui.filtros) do
		b:SetWidth(100)
		b.Label:SetWidth(70)
	end
	local orden = L["Ordenar"]
	for _, o in ipairs(Cat.ORDENES) do if o.clave == f.orden then orden = o.nombre end end
	W.SetButtonText(ui.orden, orden)
	ui.orden:SetWidth(170)
	ui.orden.Label:SetWidth(130)
	ui.usable:SetChecked(N.Get(M.ID, "soloUsables") and true or false)
	if Cat.Listo() then
		ui.cuenta:SetText(format(L["%s de %s objetos"], M.Miles(#est.filas), M.Miles(Cat.Total())))
	else
		ui.cuenta:SetText("")
	end
end

local function textoFuentes(f)
	local lineas = {}
	for k, r in ipairs(f.fuentes or {}) do
		if k > 4 then break end
		local cabeza = r.label or ""
		local resto = {}
		if r.detail and r.detail ~= "" then resto[#resto + 1] = r.detail end
		if r.chance then resto[#resto + 1] = format(L["%.3g%% de probabilidad"], r.chance) end
		if r.travel then resto[#resto + 1] = "~" .. M.Minutos(r.travel) end
		local linea = "|cffffffff" .. cabeza .. "|r"
		if #resto > 0 then linea = linea .. "\n" .. concat(resto, "  \194\183  ") end
		if r.available == false and r.whyText then
			linea = linea .. "\n|cffff9a3c" .. r.whyText .. "|r"
		end
		lineas[#lineas + 1] = linea
	end
	if #lineas == 0 then
		if f.retirado then return L["Ya no se consigue en el juego."] end
		return L["Alfa no conoce de dónde sale. Prueba en el Buscador."]
	end
	if (f.totalFuentes or 0) > 4 then lineas[#lineas + 1] = format(L["...y %d fuentes más en el Buscador."], f.totalFuentes - 4) end
	return concat(lineas, "\n\n")
end

function VC.PintarFicha()
	if not c then return end
	local ancho = est.fichaW or 280
	local alto = est.fichaH or 380
	local partes = { ui.fIcono, ui.fIconoBtn, ui.fNombre, ui.fLinea, ui.fStats, ui.fFuenteTit, ui.fFuentes, ui.fGuiame, ui.fAgregar, ui.fVincular, ui.fBuscador }
	local f = est.sel and Cat.Ficha(est.sel)
	est.ficha = f
	if not f then
		for _, w in ipairs(partes) do w:Hide() end
		for _, ch in ipairs(ui.fChips) do ch:Hide() end
		ui.fVacio:Show()
		return
	end
	ui.fVacio:Hide()
	for _, w in ipairs(partes) do w:Show() end
	local Cp = CP()
	ui.fIcono:SetTexture(Cp and Cp.ItemIcon and Cp.ItemIcon(f.id) or 134400)
	ui.fNombre:SetText(f.nombre)
	K.ColorCalidad(ui.fNombre, f.calidad)
	local y = 14 + max(40, K.Alto(ui.fNombre) + 4) + 6
	ui.fLinea:ClearAllPoints()
	ui.fLinea:SetPoint("TOPLEFT", ui.ficha, "TOPLEFT", 14, -y)
	ui.fLinea:SetWidth(ancho - 28)
	local linea = nombreCalidad(f.calidad)
	if f.linea and f.linea ~= "" then linea = linea .. "  \194\183  " .. f.linea end
	if f.ilvl and f.ilvl > 0 then linea = linea .. "  \194\183  " .. format(L["Nivel de objeto %d"], f.ilvl) end
	ui.fLinea:SetText(linea)
	y = y + K.Alto(ui.fLinea) + 8
	-- Chips: nivel, si lo puedes usar, único
	local x = 14
	local chips = {}
	if f.req and f.req > 0 then
		local p = M.Indice.Jugador()
		chips[#chips + 1] = { format(L["Requiere nivel %d"], f.req), f.req <= p.level and "neutral" or "warning" }
	end
	if f.usable ~= nil then
		chips[#chips + 1] = f.usable and { L["Puedes usarlo"], "success" } or { L["No es para tu clase"], "warning" }
	end
	if f.unico then chips[#chips + 1] = { L["Único"], "accent" } end
	if f.retirado then chips[#chips + 1] = { L["Ya no se consigue"], "warning" } end
	for i, ch in ipairs(ui.fChips) do
		local d = chips[i]
		if d then
			ch:ClearAllPoints()
			ch:SetPoint("TOPLEFT", ui.ficha, "TOPLEFT", x, -y)
			x = x + num(W.SetChip(ch, d[1], d[2]), 60) + 6
		else
			ch:Hide()
		end
	end
	if #chips > 0 then y = y + 28 end
	-- Estadísticas
	local stats = {}
	for k, s in ipairs(f.stats) do
		if k > 8 then break end
		local v = s.valor
		local texto = (v == floor(v)) and tostring(v) or format("%.1f", v)
		stats[#stats + 1] = (v > 0 and "+" or "") .. texto .. " " .. s.nombre
	end
	if f.velocidad then stats[#stats + 1] = format(L["Velocidad %.2f"], f.velocidad) end
	ui.fStats:ClearAllPoints()
	ui.fStats:SetPoint("TOPLEFT", ui.ficha, "TOPLEFT", 14, -y)
	ui.fStats:SetWidth(ancho - 28)
	ui.fStats:SetText(concat(stats, "\n"))
	ui.fStats:SetShown(#stats > 0)
	if #stats > 0 then y = y + K.Alto(ui.fStats) + 10 end
	-- Cómo conseguirlo
	ui.fFuenteTit:ClearAllPoints()
	ui.fFuenteTit:SetPoint("TOPLEFT", ui.ficha, "TOPLEFT", 14, -y)
	y = y + 22
	ui.fFuentes:ClearAllPoints()
	ui.fFuentes:SetPoint("TOPLEFT", ui.ficha, "TOPLEFT", 14, -y)
	ui.fFuentes:SetPoint("BOTTOMRIGHT", ui.ficha, "BOTTOMRIGHT", -14, 76)
	ui.fFuentes:SetText(textoFuentes(f))
	-- Botones
	local bw = floor((ancho - 28 - 8) / 2)
	ui.fGuiame:ClearAllPoints()
	ui.fGuiame:SetPoint("BOTTOMLEFT", ui.ficha, "BOTTOMLEFT", 14, 42)
	ui.fGuiame:SetWidth(bw)
	ui.fAgregar:ClearAllPoints()
	ui.fAgregar:SetPoint("LEFT", ui.fGuiame, "RIGHT", 8, 0)
	ui.fAgregar:SetWidth(bw)
	local Rv = M.VistaRuta
	W.SetButtonText(ui.fAgregar, (Rv and Rv.ElegidoPara and Rv.ElegidoPara()) and L["Usar en mi tramo"] or L["Agregar a mi ruta"])
	ui.fAgregar:SetWidth(bw)
	ui.fVincular:ClearAllPoints()
	ui.fVincular:SetPoint("BOTTOMLEFT", ui.ficha, "BOTTOMLEFT", 14, 10)
	ui.fVincular:SetWidth(bw)
	ui.fBuscador:ClearAllPoints()
	ui.fBuscador:SetPoint("LEFT", ui.fVincular, "RIGHT", 8, 0)
	ui.fBuscador:SetWidth(bw)
	if f.retirado then ui.fGuiame:Disable() else ui.fGuiame:Enable() end
end

function VC.Refrescar(ancho, alto)
	if not c then return end
	ancho = num(ancho, est.ancho or 640)
	alto = num(alto, est.alto or 440)
	est.ancho, est.alto = ancho, alto
	if not c:IsShown() then return end
	local y = 70
	local listaW = min(LISTA_W, floor(ancho * 0.56))
	ui.panel:ClearAllPoints()
	ui.panel:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
	ui.panel:SetSize(listaW, alto - y)
	ui.ficha:ClearAllPoints()
	ui.ficha:SetPoint("TOPLEFT", c, "TOPLEFT", listaW + 12, -y)
	est.fichaW, est.fichaH = ancho - listaW - 12, alto - y
	ui.ficha:SetSize(est.fichaW, est.fichaH)
	VC.PintarBarra()
	if not Cat.Listo() then
		ui.lista:Hide()
		ui.cargaTxt:Show()
		if est.motivo then
			ui.cargaTxt:SetText(M.Indice.TextoMotivo(est.motivo))
		else
			ui.cargaTxt:SetText(format(L["Preparando el catálogo de objetos... %d%%"], floor(est.avance * 100)))
		end
		if not est.cargando and not est.motivo then
			est.cargando = true
			Cat.Pedir(function(ok, motivo)
				est.cargando = false
				est.motivo = not ok and motivo or nil
				if ok then aplicar() end
				VC.Refrescar()
			end, function(frac)
				est.avance = num(frac, 0)
				if ui.cargaTxt:IsVisible() then
					ui.cargaTxt:SetText(format(L["Preparando el catálogo de objetos... %d%%"], floor(est.avance * 100)))
					W.SetProgress(ui.carga, est.avance)
				end
			end)
		end
		ui.carga:SetShown(est.cargando)
		VC.PintarFicha()
		return
	end
	ui.cargaTxt:Hide()
	ui.carga:Hide()
	ui.lista:Show()
	if not est.filtrado then
		est.filtrado = true
		aplicar()
	else
		ui.lista:Datos(#est.filas)
	end
	VC.PintarFicha()
end

-- Abrir el catálogo con un objeto elegido (desde otra pestaña).
function VC.Elegir(itemId)
	est.sel = tonumber(itemId)
	local i = est.sel and Cat.FilaDe(est.sel)
	if i and ui.lista then
		for k, fi in ipairs(est.filas) do
			if fi == i then ui.lista:IrA(k) break end
		end
	end
end

function VC.AlMostrar()
	est.motivo = nil
end

-- Un objeto que el cliente termina de cargar: su nombre y su ícono cambian.
A.RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, id)
	if not VC.Visible() then return end
	if est.sel == id then VC.PintarFicha() end
	if ui.lista then ui.lista:Refrescar() end
end)
