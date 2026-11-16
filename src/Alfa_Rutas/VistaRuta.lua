-- Alfa - Rutas: la pestaña "Mi ruta". El árbol de la ruta a la izquierda
-- (una columna por rama: XP, oro, profesión, clase y objeto; cada tramo es
-- un nodo en su columna y una línea lo une con el anterior), el tramo
-- elegido a la derecha (cantidad, material u objeto, y las misiones que Alfa
-- eligió, que se cambian con un clic) y abajo el resumen con "Seguir esta
-- ruta". Toxic / La Jauría. GPL-3.0.

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local W, Th, K = M.W, M.T, M.Kit
local P, I = M.Plan, M.Indice
local VR = {}
M.VistaRuta = VR

local type, ipairs, pairs, tonumber, tostring = type, ipairs, pairs, tonumber, tostring
local floor, max, min, format = math.floor, math.max, math.min, string.format
local num = M.num

local FILA, BARRA_H, PIE_H, IZQ_W = 52, 30, 54, 352
local CARRIL_X0, CARRIL_DX, TARJ_X = 22, 24, 140
local CHIP_RAMA = { xp = "success", oro = "accent", prof = "warning", clase = "neutral", objeto = "dungeon" }

local c -- el marco de la pestaña
local ui = { filas = {}, guias = {} }
local est = { sel = nil, modo = "lista", alt = nil, altLista = nil, ocupado = false, avance = 0, motivo = nil, datos = {} }

local function carrilX(rama)
	for i, r in ipairs(M.RAMAS) do
		if r == rama then return CARRIL_X0 + (i - 1) * CARRIL_DX end
	end
	return CARRIL_X0
end

local function ruta() return M.RutaEditada() end

local function tramoPorUid(r, uid)
	for i, t in ipairs(r and r.tramos or {}) do
		if t.uid == uid then return t, i end
	end
	return nil
end

local function cuenta(id)
	local Cp = M.Motor("Compat")
	return num(Cp and Cp.GetItemCount and Cp.GetItemCount(id, true), 0)
end

-- ¿Ya terminaste este tramo? (las misiones entregadas, el material en tus bolsas)
local function tramoHecho(t, pt)
	if t.rama == "prof" or t.rama == "objeto" then
		local item = (pt and pt.item) or t.item
		return item ~= nil and cuenta(item) >= (t.cantidad or 1)
	end
	if not (pt and pt.quests and #pt.quests > 0) then return false end
	for _, q in ipairs(pt.quests) do
		if not I.Hecha(q) then return false end
	end
	return true
end
VR.TramoHecho = tramoHecho

local function resumenTramo(t, pt)
	if not pt then return est.ocupado and L["Alfa está eligiendo..."] or "" end
	if t.rama == "xp" then
		return format(L["+%s XP · %d misiones"], M.Miles(pt.xp), #pt.quests)
	elseif t.rama == "oro" then
		return format(L["%s estimado · %d misiones"], N.Dinero(pt.oro, true), #pt.quests)
	elseif t.rama == "clase" then
		if pt.premios and pt.premios[1] then return format(L["Premio: %s"], M.NombreObjeto(pt.premios[1])) end
		return format(L["%d misiones de tu clase"], #pt.quests)
	elseif t.rama == "prof" then
		local Cp = M.Motor("Compat")
		local zona = pt.zona and Cp and Cp.MapName and Cp.MapName(pt.zona)
		local tienes = pt.item and cuenta(pt.item) or 0
		if zona then return format(L["Tienes %d · en %s"], tienes, zona) end
		return format(L["Tienes %d"], tienes)
	elseif t.rama == "objeto" then
		return pt.fuente or (t.item and L["Toca para ver de dónde sale"] or L["Elige el objeto en el catálogo"])
	end
	return ""
end

-- El color de la dificultad de una misión para tu nivel, como el juego.
local function colorNivel(nivel)
	local p = I.Jugador()
	local d = num(nivel, p.level) - p.level
	local Cp = M.Motor("Compat")
	if Cp and Cp.IsQuestTrivial and Cp.IsQuestTrivial(nivel, p.level) then return 0.55, 0.55, 0.55 end
	if d >= 5 then return 1, 0.15, 0.15 end
	if d >= 3 then return 1, 0.5, 0.25 end
	if d >= -2 then return 1, 0.82, 0 end
	return 0.25, 0.75, 0.25
end
VR.ColorNivel = colorNivel

---------------------------------------------------------------------------
-- Acciones
---------------------------------------------------------------------------

function VR.Planear()
	local r = ruta()
	if not r or #r.tramos == 0 then return end
	est.ocupado, est.avance, est.motivo = true, 0, nil
	P.Armar(r, function(plan, motivo)
		est.ocupado = false
		est.motivo = not plan and motivo or nil
		VR.Refrescar()
	end, function(frac)
		est.avance = num(frac, 0)
		if ui.progreso and ui.progreso:IsShown() then W.SetProgress(ui.progreso, est.avance) end
	end)
	VR.Refrescar()
end

local pendiente = false
local function planLuego()
	pendiente = true
	A.After(0.35, function()
		if not pendiente then return end
		pendiente = false
		VR.Planear()
	end)
end

M.Escuchar("RUTA", function() planLuego() end)
M.Escuchar("RUTAS", function() est.sel, est.modo = nil, "lista" if VR.Visible() then VR.Refrescar() end end)

local function cambiar(r)
	M.Cambio(r)
	VR.Refrescar()
end

local function agregarTramo(rama)
	local r = ruta() or M.NuevaRuta(L["Mi ruta"], {})
	if rama == "objeto" then
		K.Aviso(L["Elige el objeto en el catálogo y toca \"Agregar a mi ruta\"."])
		if M.Vista then M.Vista.Mostrar("catalogo") end
		return
	end
	local t = M.NuevoTramo({ rama = rama, item = rama == "prof" and I.MaterialSugerido() or nil })
	r.tramos[#r.tramos + 1] = t
	est.sel, est.modo = t.uid, "lista"
	cambiar(r)
end

local function moverTramo(r, i, d)
	local j = i + d
	if j < 1 or j > #r.tramos then return end
	r.tramos[i], r.tramos[j] = r.tramos[j], r.tramos[i]
	cambiar(r)
end

local function quitarTramo(r, i)
	local t = table.remove(r.tramos, i)
	if t and est.sel == t.uid then est.sel = nil end
	cambiar(r)
end

local function cambiarCantidad(r, t, n)
	n = max(1, min(99, floor(num(n, t.cantidad))))
	if n == t.cantidad then return end
	t.cantidad = n
	cambiar(r)
end

local function sacar(lista, v)
	local out = {}
	for _, x in ipairs(lista or {}) do if x ~= v then out[#out + 1] = x end end
	return out
end

-- Cambia una misión del tramo por otra: las demás quedan fijas, la vieja fuera.
local function reemplazar(r, t, viejo, nuevo)
	local plan = P.De(r)
	local pt = plan and plan.tramos[t.uid]
	local fijas = {}
	for _, q in ipairs(pt and pt.quests or t.fijas or {}) do
		if q == viejo then
			if nuevo then fijas[#fijas + 1] = nuevo end
		elseif q ~= nuevo then
			fijas[#fijas + 1] = q
		end
	end
	if nuevo and not viejo then fijas[#fijas + 1] = nuevo end
	t.fijas = fijas
	if viejo then
		t.quitar = sacar(t.quitar, viejo)
		t.quitar[#t.quitar + 1] = viejo
	end
	est.modo, est.alt, est.altLista = "lista", nil, nil
	cambiar(r)
end

local function fijada(t, q)
	for _, x in ipairs(t.fijas or {}) do if x == q then return true end end
	return false
end

local function alternar(r, t, q)
	if fijada(t, q) then t.fijas = sacar(t.fijas, q) else
		t.fijas = t.fijas or {}
		t.fijas[#t.fijas + 1] = q
	end
	cambiar(r)
end

local function verAlternativas(r, t, q)
	est.modo, est.alt, est.altLista = "alt", { uid = t.uid, quest = q }, nil
	P.Alternativas(r, t.uid, function(lista)
		if est.alt and est.alt.uid == t.uid then
			est.altLista = lista
			VR.Refrescar()
		end
	end)
	VR.Refrescar()
end

---------------------------------------------------------------------------
-- La capa para exportar, importar y renombrar
---------------------------------------------------------------------------

local function cerrarCapa()
	if ui.capa then ui.capa:Hide() end
end

local function abrirCapa(modo)
	local r = ruta()
	local capa = ui.capa
	capa.modo = modo
	capa.Entrada:Hide()
	capa.Copia:Hide()
	capa.Error:SetText("")
	if modo == "exportar" then
		capa.Titulo:SetText(L["Compartir esta ruta"])
		capa.Texto:SetText(L["Copia este texto (Ctrl+C) y pégalo a tu amigo. Él lo pega en Importar."])
		capa.Copia:Show()
		W.SetCopyText(capa.Copia, M.Exportar(r))
		W.SetButtonText(capa.Accion, L["Seleccionar todo"])
		capa:Show()
		W.SelectCopy(capa.Copia)
		return
	end
	capa.Entrada:Show()
	if modo == "importar" then
		capa.Titulo:SetText(L["Importar una ruta"])
		capa.Texto:SetText(L["Pega aquí (Ctrl+V) el texto de una ruta de Alfa."])
		capa.Entrada:SetText("")
		capa.Entrada.Ayuda:SetText(L["!ALFARUTA1!..."])
		W.SetButtonText(capa.Accion, L["Importar"])
	else
		capa.Titulo:SetText(L["Nombre de la ruta"])
		capa.Texto:SetText(L["Escribe un nombre corto para reconocerla."])
		capa.Entrada:SetText(r and r.nombre or "")
		capa.Entrada.Ayuda:SetText(L["Mi ruta"])
		W.SetButtonText(capa.Accion, L["Guardar"])
	end
	capa:Show()
	capa.Entrada:SetFocus()
end

local function accionCapa()
	local capa = ui.capa
	if capa.modo == "exportar" then
		W.SelectCopy(capa.Copia)
		return
	end
	local texto = capa.Entrada:GetText() or ""
	if capa.modo == "importar" then
		local r, motivo = M.Importar(texto)
		if not r then
			capa.Error:SetText(motivo or "")
			return
		end
		K.Aviso(format(L["Ruta importada: %s."], r.nombre))
		est.sel = nil
	else
		local r = ruta()
		texto = texto:gsub("^%s+", ""):gsub("%s+$", "")
		if r and texto ~= "" then
			r.nombre = texto:sub(1, 60)
			M.Cambio(r)
		end
	end
	cerrarCapa()
	VR.Refrescar()
end

---------------------------------------------------------------------------
-- Menús
---------------------------------------------------------------------------

local function menuRutas(b)
	local actual = ruta()
	local items = {}
	for _, r in ipairs(M.Rutas()) do
		local activa = M.Personaje().activa == r.id
		items[#items + 1] = { texto = r.nombre .. (activa and ("  \194\183  " .. L["en seguimiento"]) or ""), checked = actual and actual.id == r.id,
			onClick = function()
				M.Personaje().editando = r.id
				est.sel, est.modo = nil, "lista"
				VR.Refrescar()
			end }
	end
	if #items > 0 then items[#items + 1] = { separator = true } end
	items[#items + 1] = { texto = L["Nueva ruta vacía"], icon = "plus", onClick = function()
		M.NuevaRuta(L["Mi ruta"], {})
		VR.Refrescar()
	end }
	if actual then
		items[#items + 1] = { texto = L["Cambiar nombre..."], onClick = function() abrirCapa("renombrar") end }
		items[#items + 1] = { texto = L["Duplicar"], onClick = function()
			local tramos = {}
			for i, t in ipairs(actual.tramos) do tramos[i] = M.Copia(t) end
			M.NuevaRuta(format(L["%s (copia)"], actual.nombre), tramos, actual.plantilla)
			VR.Refrescar()
		end }
		items[#items + 1] = { texto = L["Borrar esta ruta"], icon = "close", onClick = function()
			W.Modal({ title = L["¿Borrar esta ruta?"], icon = "close", danger = true, action = L["Borrar"],
				text = format(L["%s se borra de todos tus personajes. No se puede deshacer."], actual.nombre),
				onAccept = function()
					M.BorrarRuta(actual.id)
					VR.Refrescar()
				end })
		end }
	end
	K.Menu(b, items, 220)
end

local function menuPlantillas(b)
	local items = {}
	for _, p in ipairs(M.PLANTILLAS) do
		items[#items + 1] = { texto = p.nombre, icon = p.icono, tip = p.desc, onClick = function()
			local r = M.DesdePlantilla(p.clave)
			if r then K.Aviso(format(L["Nueva ruta: %s. Puedes cambiar cada tramo."], r.nombre)) end
			est.sel, est.modo = nil, "lista"
			VR.Refrescar()
		end }
	end
	K.Menu(b, items, 220)
end

local function menuAgregar(b)
	local items = {}
	for _, rama in ipairs(M.RAMAS) do
		local d = M.RAMA[rama]
		items[#items + 1] = { texto = d.nombre, icon = d.icono, tip = d.desc, onClick = function() agregarTramo(rama) end }
	end
	K.Menu(b, items, 200)
end

local function menuAjustes(b)
	local margen = num(N.Get(M.ID, "margen"), 2)
	local items = {
		{ texto = L["Evitar misiones de grupo (élites)"], checked = N.Get(M.ID, "evitarGrupo") ~= false, onClick = function()
			N.Set(M.ID, "evitarGrupo", N.Get(M.ID, "evitarGrupo") == false)
			cambiar(ruta())
		end },
		{ separator = true },
	}
	for _, n in ipairs({ 1, 2, 3, 4 }) do
		items[#items + 1] = { texto = format(n == 1 and L["Misiones hasta %d nivel arriba del tuyo"] or L["Misiones hasta %d niveles arriba del tuyo"], n),
			checked = margen == n, onClick = function()
				N.Set(M.ID, "margen", n)
				cambiar(ruta())
			end }
	end
	K.Menu(b, items, 260)
end

local function menuMaterial(b, r, t)
	local items = {}
	for _, m in ipairs(I.MaterialesOfrecidos()) do
		local extra = m.desde and format(L["habilidad %d+"], m.desde) or format(L["nivel %d+"], m.nivel or 1)
		items[#items + 1] = { texto = M.NombreObjeto(m.item) .. "  (" .. extra .. ")", checked = t.item == m.item, onClick = function()
			t.item = m.item
			cambiar(r)
		end }
	end
	items[#items + 1] = { separator = true }
	items[#items + 1] = { texto = L["Otro material del catálogo..."], icon = "search", onClick = function()
		est.elegirPara = t.uid
		K.Aviso(L["Busca el material en el catálogo y toca \"Agregar a mi ruta\": cambia este tramo."])
		if M.Vista then M.Vista.Mostrar("catalogo") end
	end }
	K.Menu(b, items, 260)
end

-- Un objeto elegido en el catálogo para un tramo de profesión pendiente.
function VR.ElegidoPara()
	return est.elegirPara
end

function VR.UsarObjeto(itemId)
	local uid = est.elegirPara
	est.elegirPara = nil
	local r = ruta()
	local t = r and uid and tramoPorUid(r, uid)
	if not t then return false end
	t.item = itemId
	est.sel = t.uid
	M.Cambio(r)
	return true
end

local function menuMision(b, r, t, q)
	local Lk = M.Motor("Lookup")
	local items = {
		{ texto = L["Cambiar por otra misión..."], icon = "reload", onClick = function() verAlternativas(r, t, q) end },
		{ texto = L["Quitar (Alfa busca otra)"], icon = "close", onClick = function() reemplazar(r, t, q, nil) end },
		{ texto = fijada(t, q) and L["Ya no fijar"] or L["Fijar en este tramo"], icon = "lock", onClick = function() alternar(r, t, q) end },
	}
	if Lk and Lk.Show then
		items[#items + 1] = { texto = L["Ver en el Buscador"], icon = "search", onClick = function() Lk.Show(nil, "quest", q) end }
	end
	K.Menu(b, items, 220)
end

---------------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------------

local function filaArbol(k)
	local f = ui.filas[k]
	if f then return f end
	local hijo = ui.scroll.Child
	f = {}
	f.linea = K.Linea(hijo, 3)
	f.nodo = K.Nodo(hijo, 24)
	local tj = CreateFrame("Button", nil, hijo)
	tj:SetHeight(44)
	Th.Skin(tj, "tile")
	f.tarjeta = tj
	f.barra = tj:CreateTexture(nil, "OVERLAY")
	f.barra:SetTexture(Th.Media("white"))
	f.barra:SetPoint("TOPLEFT", tj, "TOPLEFT", 0, 0)
	f.barra:SetPoint("BOTTOMLEFT", tj, "BOTTOMLEFT", 0, 0)
	f.barra:SetWidth(3)
	f.titulo = K.Texto(tj, "body", "text")
	f.titulo:SetPoint("TOPLEFT", tj, "TOPLEFT", 10, -7)
	f.titulo:SetPoint("RIGHT", tj, "RIGHT", -8, 0)
	f.sub = K.Texto(tj, "small", "textMuted")
	f.sub:SetPoint("TOPLEFT", tj, "TOPLEFT", 10, -25)
	f.sub:SetPoint("RIGHT", tj, "RIGHT", -8, 0)
	f.quitar = W.IconButton(tj, "close", 18, L["Quitar este tramo"], function() local r = ruta() if r and f.indice then quitarTramo(r, f.indice) end end, 10)
	f.quitar:SetPoint("TOPRIGHT", tj, "TOPRIGHT", -3, -3)
	f.abajo = W.IconButton(tj, "chevron-down", 18, L["Bajar"], function() local r = ruta() if r and f.indice then moverTramo(r, f.indice, 1) end end, 10)
	f.abajo:SetPoint("RIGHT", f.quitar, "LEFT", 0, 0)
	f.arriba = W.IconButton(tj, "chevron-up", 18, L["Subir"], function() local r = ruta() if r and f.indice then moverTramo(r, f.indice, -1) end end, 10)
	f.arriba:SetPoint("RIGHT", f.abajo, "LEFT", 0, 0)
	tj:SetScript("OnClick", function()
		if f.uid then
			est.sel, est.modo = f.uid, "lista"
			VR.Refrescar()
		end
	end)
	ui.filas[k] = f
	return f
end

local function filaMision(lista)
	local b = K.Fila(lista)
	b.Nivel = K.Texto(b, "number", "text")
	b.Nivel:SetPoint("LEFT", b, "LEFT", 6, 0)
	b.Nivel:SetWidth(24)
	b.Nivel:SetJustifyH("CENTER")
	b.Valor = K.Texto(b, "small", "textDim")
	b.Valor:SetPoint("RIGHT", b, "RIGHT", -6, 0)
	b.Valor:SetJustifyH("RIGHT")
	b.Titulo = K.Texto(b, "label", "text")
	b.Titulo:SetPoint("LEFT", b, "LEFT", 34, 0)
	b.Titulo:SetPoint("RIGHT", b.Valor, "LEFT", -6, 0)
	b.Candado = b:CreateTexture(nil, "OVERLAY")
	b.Candado:SetTexture(Th.Media("lock"))
	b.Candado:SetSize(10, 10)
	b.Candado:SetPoint("LEFT", b, "LEFT", 26, 6)
	W.Color(b.Candado, "accent")
	b:SetScript("OnClick", function(self)
		local d = self.indice and est.datos[self.indice]
		if d and d.alClic then d.alClic(self) end
	end)
	b:SetScript("OnEnter", function(self)
		local d = self.indice and est.datos[self.indice]
		if d and d.tip then W.Tooltip(self, "ANCHOR_LEFT", d.titulo, d.tip) end
	end)
	b:SetScript("OnLeave", W.HideTip)
	return b
end

local function pintarMision(b, i)
	local d = est.datos[i]
	if not d then return b:Hide() end
	b.Nivel:SetText(d.nivel and tostring(d.nivel) or "")
	if d.nivel then K.Tinte(b.Nivel, colorNivel(d.nivel)) end
	b.Titulo:SetText(d.titulo or "")
	W.Color(b.Titulo, d.hecha and "textMuted" or "text")
	b.Valor:SetText(d.valor or "")
	b.Candado:SetShown(d.fija and true or false)
	b.Elegida:SetShown(d.elegida and true or false)
end

function VR.Construir(parent)
	c = CreateFrame("Frame", nil, parent)
	ui.raiz = c

	-- Barra de arriba
	ui.bRuta = K.BotonMenu(c, L["Mi ruta"], menuRutas, 210)
	ui.bRuta:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	ui.bRuta.psTip = L["Tus rutas: elige, crea, renombra o borra."]
	ui.bPlantillas = K.BotonMenu(c, L["Plantillas"], menuPlantillas, 120)
	ui.bPlantillas:SetPoint("LEFT", ui.bRuta, "RIGHT", 8, 0)
	ui.bPlantillas.psTip = L["Rutas listas para empezar."]
	ui.bAjustes = W.IconButton(c, "sliders", 28, L["Cómo elige Alfa las misiones"], menuAjustes, 14)
	ui.bAjustes:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, 0)
	ui.bImportar = W.Button(c, L["Importar"], function() abrirCapa("importar") end, { ghost = true, icon = "plus" })
	ui.bImportar:SetPoint("RIGHT", ui.bAjustes, "LEFT", -6, 0)
	ui.bExportar = W.Button(c, L["Compartir"], function() abrirCapa("exportar") end, { ghost = true, icon = "layers" })
	ui.bExportar:SetPoint("RIGHT", ui.bImportar, "LEFT", -4, 0)

	-- El árbol
	local arbol = W.RowPanel(c)
	ui.arbol = arbol
	ui.carriles = {}
	for i, rama in ipairs(M.RAMAS) do
		local h = CreateFrame("Frame", nil, arbol)
		h:SetSize(20, 20)
		h:SetPoint("CENTER", arbol, "TOPLEFT", CARRIL_X0 + (i - 1) * CARRIL_DX, -14)
		h.Icono = h:CreateTexture(nil, "ARTWORK")
		h.Icono:SetTexture(Th.Media(Th.Icon(M.RAMA[rama].icono)))
		h.Icono:SetSize(14, 14)
		h.Icono:SetPoint("CENTER", h, "CENTER", 0, 0)
		h.rama = rama
		h:EnableMouse(true)
		h:SetScript("OnEnter", function(self) W.Tooltip(self, "ANCHOR_TOP", M.RAMA[self.rama].nombre, { M.RAMA[self.rama].desc }) end)
		h:SetScript("OnLeave", W.HideTip)
		ui.carriles[i] = h
	end
	ui.arbolTitulo = K.Texto(arbol, "small", "textMuted")
	ui.arbolTitulo:SetPoint("LEFT", arbol, "TOPLEFT", TARJ_X, -14)
	ui.arbolTitulo:SetText(L["Tu árbol: un tramo después de otro"])
	ui.scroll = W.Scroll(arbol)
	ui.scroll:SetPoint("TOPLEFT", arbol, "TOPLEFT", 0, -BARRA_H)
	ui.scroll:SetPoint("BOTTOMRIGHT", arbol, "BOTTOMRIGHT", 0, 2)
	for i = 1, #M.RAMAS do
		local g = K.Linea(ui.scroll.Child, 1)
		ui.guias[i] = g
	end
	ui.inicio = K.Texto(ui.scroll.Child, "small", "textDim")
	ui.agregar = W.Button(ui.scroll.Child, L["Agregar tramo"], function(self) menuAgregar(self) end, { icon = "plus" })
	ui.vacio = K.Texto(arbol, "note", "textDim", true)
	ui.vacio:SetPoint("TOPLEFT", arbol, "TOPLEFT", 20, -48)
	ui.vacio:SetPoint("RIGHT", arbol, "RIGHT", -20, 0)
	ui.vacio:SetText(L["Tu ruta está vacía. Agrega tramos (XP, oro, profesión, clase u objeto) o empieza con una plantilla."])
	ui.plantillasVacio = {}
	for i, p in ipairs(M.PLANTILLAS) do
		local b = W.Button(arbol, p.nombre, function()
			M.DesdePlantilla(p.clave)
			est.sel = nil
			VR.Refrescar()
		end, { icon = Th.Icon(p.icono) })
		b.psTip = p.desc
		ui.plantillasVacio[i] = b
	end

	-- El detalle del tramo
	local det = W.RowPanel(c)
	ui.det = det
	ui.dChip = W.Chip(det)
	ui.dChip:SetPoint("TOPLEFT", det, "TOPLEFT", 14, -12)
	ui.dPos = K.Texto(det, "small", "textMuted")
	ui.dPos:SetPoint("LEFT", ui.dChip, "RIGHT", 8, 0)
	ui.dTitulo = K.Texto(det, "title", "text")
	ui.dTitulo:SetPoint("TOPLEFT", det, "TOPLEFT", 14, -40)
	ui.dTitulo:SetPoint("RIGHT", det, "RIGHT", -14, 0)
	ui.dDesc = K.Texto(det, "note", "textDim", true)
	ui.dDesc:SetPoint("TOPLEFT", ui.dTitulo, "BOTTOMLEFT", 0, -6)
	ui.dDesc:SetPoint("RIGHT", det, "RIGHT", -14, 0)
	ui.dCantLbl = K.Texto(det, "label", "textDim")
	ui.dCantLbl:SetText(L["Cantidad"])
	ui.dMenos = W.Button(det, "-", function() local r = ruta() local t = r and tramoPorUid(r, est.sel) if t then cambiarCantidad(r, t, t.cantidad - 1) end end, { width = 28, height = 24 })
	ui.dCant = K.Texto(det, "number", "text")
	ui.dCant:SetWidth(30)
	ui.dCant:SetJustifyH("CENTER")
	ui.dMas = W.Button(det, "+", function() local r = ruta() local t = r and tramoPorUid(r, est.sel) if t then cambiarCantidad(r, t, t.cantidad + 1) end end, { width = 28, height = 24 })
	ui.dRapidos = {}
	for i, n in ipairs({ 3, 5, 10, 20 }) do
		local b = W.Button(det, tostring(n), function() local r = ruta() local t = r and tramoPorUid(r, est.sel) if t then cambiarCantidad(r, t, n) end end, { ghost = true, width = 30, height = 24 })
		ui.dRapidos[i] = b
	end
	ui.dMaterial = K.BotonMenu(det, L["Material"], function(self)
		local r = ruta()
		local t = r and tramoPorUid(r, est.sel)
		if t then menuMaterial(self, r, t) end
	end, 240)
	ui.dObjIcono = det:CreateTexture(nil, "ARTWORK")
	ui.dObjIcono:SetSize(28, 28)
	ui.dObjNombre = K.Texto(det, "body", "text")
	ui.dObjCambiar = W.Button(det, L["Cambiar objeto"], function()
		if M.Vista then M.Vista.Mostrar("catalogo") end
	end, { ghost = true })
	ui.dObjBoton = CreateFrame("Button", nil, det)
	ui.dObjBoton:SetAllPoints(ui.dObjIcono)
	ui.dObjBoton:SetScript("OnEnter", function(self) if self.item then W.ItemTip(self, self.item) end end)
	ui.dObjBoton:SetScript("OnLeave", W.HideTip)
	ui.dListaTit = K.Texto(det, "heading", "text")
	ui.dVolver = W.Button(det, L["Volver"], function() est.modo, est.alt, est.altLista = "lista", nil, nil VR.Refrescar() end, { ghost = true, height = 22 })
	ui.dLista = K.Lista(det, 24, filaMision, pintarMision)
	ui.dNota = K.Texto(det, "small", "warning", true)
	ui.dVacio = K.Texto(det, "note", "textDim", true)
	ui.dVacio:SetPoint("TOPLEFT", det, "TOPLEFT", 18, -24)
	ui.dVacio:SetPoint("RIGHT", det, "RIGHT", -18, 0)

	-- El pie: resumen y "Seguir esta ruta"
	local pie = CreateFrame("Frame", nil, c)
	ui.pie = pie
	ui.resumen1 = K.Texto(pie, "body", "text")
	ui.resumen1:SetPoint("TOPLEFT", pie, "TOPLEFT", 2, -8)
	ui.resumen2 = K.Texto(pie, "small", "textDim")
	ui.resumen2:SetPoint("TOPLEFT", ui.resumen1, "BOTTOMLEFT", 0, -4)
	ui.progreso = W.ProgressLine(pie, 3)
	ui.progreso:SetPoint("BOTTOMLEFT", pie, "BOTTOMLEFT", 2, 6)
	ui.progreso:SetWidth(240)
	ui.bSeguir = W.Button(pie, L["Seguir esta ruta"], function() if M.Seguir then M.Seguir(ruta()) end end, { primary = true, icon = "icon-goto" })
	ui.bSeguir:SetPoint("RIGHT", pie, "RIGHT", 0, 0)
	ui.bSeguir.psTip = L["Convierte tu ruta en una guía: la flecha, los pasos y el mapa te llevan."]
	ui.bRecalc = W.Button(pie, L["Recalcular"], function()
		local r = ruta()
		if r then M.Personaje().planes[r.id] = nil end
		VR.Planear()
	end, { ghost = true, icon = "reload" })
	ui.bRecalc:SetPoint("RIGHT", ui.bSeguir, "LEFT", -8, 0)
	ui.bRecalc.psTip = L["Alfa vuelve a elegir desde donde estás ahora (las misiones fijas se quedan)."]
	ui.bMenu = W.Button(pie, L["Ver en el menú"], function()
		local r = ruta()
		if r then M.Guias.MostrarEnMenu(M.Guias.IdRuta(r.id)) end
	end, { ghost = true })
	ui.bMenu:SetPoint("RIGHT", ui.bRecalc, "LEFT", -4, 0)
	ui.bMenu.psTip = L["El menú de guías, en \"Mis rutas\"."]

	-- La capa de compartir / importar / renombrar
	local capa = CreateFrame("Frame", nil, c)
	capa:SetAllPoints(c)
	capa:SetFrameLevel(num(c:GetFrameLevel(), 1) + 30)
	capa:EnableMouse(true)
	K.Fondo(capa, "bg", 0.92)
	local caja = W.RowPanel(capa)
	caja:SetSize(520, 190)
	caja:SetPoint("CENTER", capa, "CENTER", 0, 20)
	capa.Titulo = K.Texto(caja, "title", "text")
	capa.Titulo:SetPoint("TOPLEFT", caja, "TOPLEFT", 20, -18)
	capa.Texto = K.Texto(caja, "note", "textDim", true)
	capa.Texto:SetPoint("TOPLEFT", capa.Titulo, "BOTTOMLEFT", 0, -6)
	capa.Texto:SetWidth(480)
	capa.Entrada = K.Entrada(caja, "")
	capa.Entrada:SetPoint("TOPLEFT", caja, "TOPLEFT", 20, -84)
	capa.Entrada:SetWidth(480)
	capa.Entrada.alEnter = function() accionCapa() end
	capa.Copia = W.CopyBox(caja)
	capa.Copia:SetPoint("TOPLEFT", caja, "TOPLEFT", 20, -84)
	capa.Copia:SetWidth(480)
	capa.Error = K.Texto(caja, "small", "warning")
	capa.Error:SetPoint("TOPLEFT", caja, "TOPLEFT", 20, -122)
	capa.Error:SetWidth(480)
	capa.Accion = W.Button(caja, L["Guardar"], accionCapa, { primary = true })
	capa.Accion:SetPoint("BOTTOMRIGHT", caja, "BOTTOMRIGHT", -16, 14)
	capa.Cerrar = W.Button(caja, L["Cerrar"], cerrarCapa)
	capa.Cerrar:SetPoint("RIGHT", capa.Accion, "LEFT", -8, 0)
	capa:Hide()
	ui.capa = capa
	return c
end

function VR.Visible()
	return c ~= nil and c:IsShown()
end

---------------------------------------------------------------------------
-- Pintar
---------------------------------------------------------------------------

local function pintarArbol(r, plan, alto)
	local hijo = ui.scroll.Child
	local n = #r.tramos
	hijo:SetWidth(IZQ_W)
	local vacia = n == 0
	ui.vacio:SetShown(vacia)
	local y0 = 40
	for i, b in ipairs(ui.plantillasVacio) do
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", ui.arbol, "TOPLEFT", 20, -(y0 + 70 + (i - 1) * 34))
		b:SetShown(vacia)
	end
	local cuenta = 0
	local px, py
	local primero = 22
	ui.inicio:ClearAllPoints()
	ui.inicio:SetPoint("LEFT", hijo, "TOPLEFT", TARJ_X, -10)
	ui.inicio:SetText(vacia and "" or format(L["Empiezas en nivel %.1f"], I.NivelDecimal()))
	for k, t in ipairs(r.tramos) do
		cuenta = k
		local f = filaArbol(k)
		local pt = plan and plan.tramos[t.uid]
		local x, y = carrilX(t.rama), -(primero + (k - 1) * FILA + FILA / 2)
		local cr, cg, cb = M.ColorRama(t.rama)
		local hecho = tramoHecho(t, pt)
		local elegido = est.sel == t.uid
		f.indice, f.uid = k, t.uid
		f.nodo:ClearAllPoints()
		f.nodo:SetPoint("CENTER", hijo, "TOPLEFT", x, y)
		f.nodo:Pintar(M.RAMA[t.rama].icono, cr, cg, cb, false, hecho)
		f.nodo:Show()
		if k == 1 then
			K.Trazar(f.linea, hijo, x, -4, x, y)
		else
			K.Trazar(f.linea, hijo, px, py, x, y)
		end
		f.linea:SetVertexColor(cr, cg, cb, hecho and 0.9 or 0.55)
		px, py = x, y
		local tj = f.tarjeta
		tj:ClearAllPoints()
		tj:SetPoint("LEFT", hijo, "TOPLEFT", TARJ_X, y)
		tj:SetWidth(IZQ_W - TARJ_X - 12)
		tj:Show()
		f.titulo:SetText(M.TituloTramo(t))
		W.Color(f.titulo, hecho and "textMuted" or "text")
		f.sub:SetText(hecho and L["Hecho"] or resumenTramo(t, pt))
		f.barra:SetShown(elegido)
		f.barra:SetVertexColor(cr, cg, cb, 1)
		f.titulo:SetPoint("RIGHT", tj, "RIGHT", elegido and -60 or -8, 0)
		f.quitar:SetShown(elegido)
		f.arriba:SetShown(elegido and k > 1)
		f.abajo:SetShown(elegido and k < n)
	end
	for k = cuenta + 1, #ui.filas do
		local f = ui.filas[k]
		f.nodo:Hide()
		f.linea:Hide()
		f.tarjeta:Hide()
		f.indice, f.uid = nil, nil
	end
	local fondo = primero + n * FILA + 8
	ui.agregar:ClearAllPoints()
	ui.agregar:SetPoint("TOPLEFT", hijo, "TOPLEFT", TARJ_X, -fondo)
	ui.agregar:SetShown(not vacia)
	local contenido = fondo + 40
	local vista = max(40, alto - BARRA_H - 2)
	for i, g in ipairs(ui.guias) do
		local x = CARRIL_X0 + (i - 1) * CARRIL_DX
		K.Trazar(g, hijo, x, 0, x, -max(contenido, vista))
		local cr, cg, cb = M.ColorRama(M.RAMAS[i])
		g:SetVertexColor(cr, cg, cb, 0.12)
		g:SetShown(not vacia)
	end
	for i, h in ipairs(ui.carriles) do
		local cr, cg, cb = M.ColorRama(M.RAMAS[i])
		h.Icono:SetVertexColor(cr, cg, cb, 1)
	end
	W.SetScrollContent(ui.scroll, contenido, vista)
end

local function datosMisiones(r, t, pt)
	local datos = {}
	local Lk = M.Motor("Lookup")
	local p = I.Jugador()
	if est.modo == "alt" and est.alt and est.alt.uid == t.uid then
		for _, c2 in ipairs(est.altLista or {}) do
			local e = c2.e
			local v = t.rama == "oro" and N.Dinero(c2.valor or I.Oro(e, false), true) or ("+" .. M.Miles(c2.valor or I.XPPara(e, p.level)) .. " XP")
			local tip = {}
			if c2.tiempo then tip[#tip + 1] = format(L["Unos %s de camino y trabajo"], M.Minutos(c2.tiempo)) end
			if c2.grupo then tip[#tip + 1] = L["Pide grupo: hay élites."] end
			tip[#tip + 1] = L["Clic: usar esta en lugar de la otra."]
			datos[#datos + 1] = { nivel = e.lvl, titulo = P.Titulo(e.id), valor = v, tip = tip,
				alClic = function() reemplazar(r, t, est.alt.quest, e.id) end }
		end
		return datos
	end
	for _, q in ipairs(pt and pt.quests or {}) do
		local idx = I.Listo()
		local e = idx and idx.porId[q]
		local C = M.Motor("Codex")
		local rec = C and C.Quest(q)
		local nivel = (e and e.lvl) or (rec and rec.level)
		local v
		if t.rama == "oro" and e then v = N.Dinero(I.Oro(e, false), true)
		elseif e then v = "+" .. M.Miles(I.XPPara(e, p.level)) .. " XP" end
		local hecha = I.Hecha(q)
		local tip = { hecha and L["Ya la entregaste."] or (I.EnRegistro(q) and L["Ya la tienes en tu registro."] or L["Clic: cambiarla, quitarla o fijarla."]) }
		if fijada(t, q) then tip[#tip + 1] = L["Fijada: Alfa no la cambia al recalcular."] end
		datos[#datos + 1] = { nivel = nivel, titulo = P.Titulo(q), valor = hecha and L["hecha"] or v, hecha = hecha, fija = fijada(t, q), tip = tip,
			alClic = function(b) menuMision(b, r, t, q) end }
	end
	return datos
end

local function pintarDetalle(r, plan, ancho, alto)
	local t, i = tramoPorUid(r, est.sel)
	if not t and r.tramos[1] then
		t, i = r.tramos[1], 1
		est.sel = t.uid
	end
	local partes = { ui.dChip, ui.dPos, ui.dTitulo, ui.dDesc, ui.dCantLbl, ui.dMenos, ui.dCant, ui.dMas, ui.dMaterial,
		ui.dObjIcono, ui.dObjNombre, ui.dObjCambiar, ui.dObjBoton, ui.dListaTit, ui.dVolver, ui.dLista, ui.dNota }
	if not t then
		for _, w in ipairs(partes) do w:Hide() end
		for _, b in ipairs(ui.dRapidos) do b:Hide() end
		ui.dVacio:SetText(L["Aquí verás las misiones de cada tramo. Agrega tu primer tramo a la izquierda."])
		ui.dVacio:Show()
		return
	end
	ui.dVacio:Hide()
	for _, w in ipairs(partes) do w:Show() end
	local pt = plan and plan.tramos[t.uid]
	local rama = M.RAMA[t.rama]
	W.SetChip(ui.dChip, rama.nombre, CHIP_RAMA[t.rama])
	ui.dPos:SetText(format(L["Tramo %d de %d"], i, #r.tramos))
	ui.dTitulo:SetText(M.TituloTramo(t))
	ui.dDesc:SetText(rama.desc)
	local y = 40 + 20 + 6 + max(14, K.Alto(ui.dDesc)) + 12
	ui.dCantLbl:ClearAllPoints()
	ui.dCantLbl:SetPoint("TOPLEFT", ui.det, "TOPLEFT", 14, -(y + 5))
	ui.dMenos:ClearAllPoints()
	ui.dMenos:SetPoint("TOPLEFT", ui.det, "TOPLEFT", 84, -y)
	ui.dCant:ClearAllPoints()
	ui.dCant:SetPoint("LEFT", ui.dMenos, "RIGHT", 2, 0)
	ui.dCant:SetText(tostring(t.cantidad))
	ui.dMas:ClearAllPoints()
	ui.dMas:SetPoint("LEFT", ui.dCant, "RIGHT", 2, 0)
	local prev = ui.dMas
	for _, b in ipairs(ui.dRapidos) do
		b:ClearAllPoints()
		b:SetPoint("LEFT", prev, "RIGHT", prev == ui.dMas and 10 or 2, 0)
		b:Show()
		prev = b
	end
	y = y + 34
	ui.dMaterial:SetShown(t.rama == "prof")
	local esObjeto = t.rama == "objeto"
	ui.dObjIcono:SetShown(esObjeto)
	ui.dObjNombre:SetShown(esObjeto)
	ui.dObjCambiar:SetShown(esObjeto)
	ui.dObjBoton:SetShown(esObjeto)
	if t.rama == "prof" then
		ui.dMaterial:ClearAllPoints()
		ui.dMaterial:SetPoint("TOPLEFT", ui.det, "TOPLEFT", 14, -y)
		local item = (pt and pt.item) or t.item
		W.SetButtonText(ui.dMaterial, item and M.NombreObjeto(item) or L["Elige el material"])
		ui.dMaterial:SetWidth(min(ancho - 28, 260))
		y = y + 36
	elseif esObjeto then
		local Cp = M.Motor("Compat")
		ui.dObjIcono:ClearAllPoints()
		ui.dObjIcono:SetPoint("TOPLEFT", ui.det, "TOPLEFT", 14, -y)
		ui.dObjIcono:SetTexture(t.item and Cp and Cp.ItemIcon and Cp.ItemIcon(t.item) or Th.Media("icon-collect"))
		ui.dObjBoton.item = t.item
		ui.dObjNombre:ClearAllPoints()
		ui.dObjNombre:SetPoint("LEFT", ui.dObjIcono, "RIGHT", 8, 0)
		ui.dObjNombre:SetPoint("RIGHT", ui.det, "RIGHT", -120, 0)
		ui.dObjNombre:SetText(t.item and M.NombreObjeto(t.item) or L["Sin objeto"])
		local Cx = M.Motor("Codex")
		local rec = t.item and Cx and Cx.Item(t.item)
		if rec then K.ColorCalidad(ui.dObjNombre, rec.quality) else W.Color(ui.dObjNombre, "text") end
		ui.dObjCambiar:ClearAllPoints()
		ui.dObjCambiar:SetPoint("TOPRIGHT", ui.det, "TOPRIGHT", -12, -y)
		y = y + 38
	end
	-- La lista de misiones (o las alternativas para cambiar una)
	local deMisiones = t.rama == "xp" or t.rama == "oro" or t.rama == "clase"
	ui.dListaTit:ClearAllPoints()
	ui.dListaTit:SetPoint("TOPLEFT", ui.det, "TOPLEFT", 14, -y)
	ui.dVolver:ClearAllPoints()
	ui.dVolver:SetPoint("TOPRIGHT", ui.det, "TOPRIGHT", -10, -(y - 4))
	local alt = est.modo == "alt" and est.alt and est.alt.uid == t.uid
	ui.dVolver:SetShown(alt and true or false)
	if alt then
		ui.dListaTit:SetText(est.altLista and L["Elige la que prefieras"] or L["Buscando otras misiones..."])
	elseif deMisiones then
		ui.dListaTit:SetText(est.ocupado and L["Alfa está eligiendo..."] or L["Las misiones de este tramo"])
	else
		ui.dListaTit:SetText(t.rama == "prof" and L["Dónde juntarlo"] or L["Cómo conseguirlo"])
	end
	y = y + 24
	local notas = {}
	for _, n in ipairs(pt and pt.notas or {}) do notas[#notas + 1] = n end
	if deMisiones or alt then
		est.datos = datosMisiones(r, t, pt)
		ui.dLista:Show()
	else
		est.datos = {}
		ui.dLista:Hide()
		if t.rama == "prof" and pt then
			local Cp = M.Motor("Compat")
			local zona = pt.zona and Cp and Cp.MapName and Cp.MapName(pt.zona)
			notas[#notas + 1] = zona and format(L["Lo más cercano está en %s. La guía te lleva de un nodo al siguiente."], zona) or nil
		elseif esObjeto and pt and pt.fuente then
			notas[#notas + 1] = pt.fuente
		end
	end
	local notaH = 0
	ui.dNota:SetWidth(ancho - 28)
	ui.dNota:SetText(table.concat(notas, "\n"))
	if #notas > 0 then notaH = K.Alto(ui.dNota) + 10 end
	W.Color(ui.dNota, deMisiones and "warning" or "textDim")
	ui.dNota:ClearAllPoints()
	if deMisiones or alt then
		ui.dNota:SetPoint("BOTTOMLEFT", ui.det, "BOTTOMLEFT", 14, 10)
	else
		ui.dNota:SetPoint("TOPLEFT", ui.det, "TOPLEFT", 14, -y)
	end
	ui.dLista:ClearAllPoints()
	ui.dLista:SetPoint("TOPLEFT", ui.det, "TOPLEFT", 8, -y)
	ui.dLista:SetPoint("BOTTOMRIGHT", ui.det, "BOTTOMRIGHT", -4, 8 + notaH)
	ui.dLista:Datos(#est.datos)
end

local function pintarPie(r, plan)
	local p = M.Personaje()
	local activa = p.activa == r.id
	local instalada = p.guias[r.id] ~= nil
	ui.progreso:SetShown(est.ocupado)
	if est.ocupado then
		W.SetProgress(ui.progreso, est.avance)
		ui.resumen1:SetText(L["Alfa está armando tu ruta..."])
		ui.resumen2:SetText(L["Revisa miles de misiones para elegir las mejores: tarda unos segundos."])
	elseif plan then
		ui.resumen1:SetText(format(L["%d misiones · +%s XP · nivel %.1f a %.1f"], plan.misiones or 0, M.Miles(plan.xp), plan.desde or 1, plan.hasta or 1))
		local extra = format(L["Oro estimado: %s"], N.Dinero(plan.oro or 0, true))
		if not plan.posicion then extra = extra .. "  \194\183  " .. L["No pude leer dónde estás: las distancias son aproximadas."] end
		ui.resumen2:SetText(extra)
	elseif est.motivo then
		ui.resumen1:SetText(L["No pude armar la ruta."])
		ui.resumen2:SetText(I.TextoMotivo(est.motivo))
	elseif #r.tramos == 0 then
		ui.resumen1:SetText(L["Agrega tramos para armar tu ruta."])
		ui.resumen2:SetText("")
	else
		ui.resumen1:SetText("")
		ui.resumen2:SetText("")
	end
	local firma = p.progreso[r.id] and p.progreso[r.id].firma
	local texto = L["Seguir esta ruta"]
	if activa and instalada then
		texto = firma == M.Firma(r) and L["Continuar mi ruta"] or L["Actualizar mi guía"]
	end
	W.SetButtonText(ui.bSeguir, texto)
	if (plan and #r.tramos > 0) and not est.ocupado then ui.bSeguir:Enable() else ui.bSeguir:Disable() end
	ui.bMenu:SetShown(instalada)
end

-- ancho, alto: el espacio de la pestaña.
function VR.Refrescar(ancho, alto)
	if not c then return end
	ancho = num(ancho, est.ancho or 640)
	alto = num(alto, est.alto or 440)
	est.ancho, est.alto = ancho, alto
	if not c:IsShown() then return end
	local r = ruta()
	if not r then r = M.NuevaRuta(L["Mi ruta"], {}) end
	W.SetButtonText(ui.bRuta, r.nombre)
	ui.bRuta:SetWidth(210)
	local areaY = 38
	local areaH = alto - areaY - PIE_H
	local izq = min(IZQ_W, floor(ancho * 0.54))
	ui.arbol:ClearAllPoints()
	ui.arbol:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -areaY)
	ui.arbol:SetSize(izq, areaH)
	ui.det:ClearAllPoints()
	ui.det:SetPoint("TOPLEFT", c, "TOPLEFT", izq + 12, -areaY)
	ui.det:SetSize(ancho - izq - 12, areaH)
	ui.pie:ClearAllPoints()
	ui.pie:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(areaY + areaH + 4))
	ui.pie:SetSize(ancho, PIE_H - 4)
	local plan = P.De(r)
	if not plan and not est.ocupado and #r.tramos > 0 and not est.motivo then
		VR.Planear()
		return
	end
	pintarArbol(r, plan, areaH)
	pintarDetalle(r, plan, ancho - izq - 12, areaH)
	pintarPie(r, plan)
end

-- Al volver a la pestaña, un plan viejo se rehace y el error se reintenta.
function VR.AlMostrar()
	est.motivo = nil
end
