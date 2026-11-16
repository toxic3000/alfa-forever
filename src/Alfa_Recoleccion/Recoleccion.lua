-- Alfa - Recolección (Toxic / La Jauría, GPL-3.0): reemplaza a GatherLite.
--
-- Esta parte: la página del módulo (resumen de la sesión, ruta de farmeo,
-- qué se muestra, historial y datos), las capas de Alfa_Mundo, el comando
-- /alfa recoleccion y el arranque. Los nodos están en Nodos.lua, la
-- detección en Deteccion.lua, el mapa en Mapa.lua, el minimapa en
-- Minimapa.lua y la ruta en Ruta.lua.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local W, T = A.Widgets, A.Theme
local R, Ruta = M.R, M.Ruta
local L = N.Textos(M.EN)

local floor, max, min = math.floor, math.max, math.min
local ID = R.ID

---------------------------------------------------------------------------
-- Capas de Alfa_Mundo (si está): un interruptor por tipo en su control.
---------------------------------------------------------------------------
local function hayMundo()
	return type(AlfaMundo) == "table" and type(AlfaMundo.RegistrarCapa) == "function"
end

local function iconoCapa(tipo)
	local tex = R.IconoTipo(tipo)
	return tex
end

if hayMundo() then
	for _, tipo in ipairs(M.TIPOS) do
		local ok = pcall(AlfaMundo.RegistrarCapa, {
			id = "recoleccion." .. tipo, grupo = L["Recolección"], nombre = R.NombreTipo(tipo),
			icono = iconoCapa(tipo), activa = N.Get(ID, tipo) ~= false,
			alCambiar = function(activa)
				-- Se guarda también aquí, para cuando Alfa_Mundo no esté.
				N.Set(ID, tipo, activa and true or false)
				R.Refiltrar()
			end,
		})
		if ok then R.mundo = true end
	end
end

-- Encender o apagar un tipo: con Alfa_Mundo, en su capa (si su control no
-- se puede mover desde aquí, se abre la página de Mundo).
local function ponerTipo(tipo, valor)
	if valor == nil then valor = true end
	if R.mundo and type(AlfaMundo) == "table" then
		if type(AlfaMundo.ActivarCapa) == "function" then
			pcall(AlfaMundo.ActivarCapa, "recoleccion." .. tipo, valor)
		else
			N.Imprimir(L["Las capas de Recolección se encienden y apagan en la página Mundo."])
			N.Abrir("mundo")
			return
		end
	end
	N.Set(ID, tipo, valor and true or false)
	R.Refiltrar()
end

---------------------------------------------------------------------------
-- Ajustes y controles (los mismos sirven a la página y a la búsqueda)
---------------------------------------------------------------------------
local AJUSTES = {
	mapa = true, minimapa = true,
	mineria = true, hierbas = true, pesca = true, tesoros = true,
	soloProfesiones = true, soloHabilidad = false,
	base = true, agrupar = true,
	tamanoMapa = 1, tamanoMinimapa = 1,
	rutaTipo = "mineria", rutaRecurso = "todos",
}

local function porciento(v) return floor(v * 100 + 0.5) .. "%" end
local function clave(k) return ID .. "." .. k end

local function control(tipo, k, etiqueta, ayuda, extra)
	local c = { kind = tipo, key = clave(k), label = etiqueta, help = ayuda }
	for a, b in pairs(extra or {}) do c[a] = b end
	return c
end

local function interruptorTipo(tipo, etiqueta, ayuda)
	return control("toggle", tipo, etiqueta, ayuda, {
		search = "gatherlite, capas, layers, " .. tipo,
		get = function() return R.TipoActivo(tipo) end,
		set = function(v) ponerTipo(tipo, v) end,
	})
end

local SECCIONES = {
	{ nombre = L["Dónde se ven"], controles = {
		control("toggle", "mapa", L["En el mapa del mundo"], L["Los nodos de la zona que miras, con su nombre, nivel y cuántas veces los recolectaste al pasar el ratón."], { search = "gatherlite, mapa, world map, pins, nodos" }),
		control("toggle", "minimapa", L["En el minimapa"], L["Los nodos que tienes cerca. El punto del rastreo del juego dice si ahora hay algo ahí."], { search = "gatherlite, minimap, nodos, cerca" }),
		control("slider", "tamanoMapa", L["Tamaño en el mapa"], nil, { min = 0.6, max = 1.8, step = 0.05, format = porciento }),
		control("slider", "tamanoMinimapa", L["Tamaño en el minimapa"], nil, { min = 0.6, max = 1.8, step = 0.05, format = porciento }),
	} },
	{ nombre = L["Qué se ve"], mundo = true, controles = {
		interruptorTipo("mineria", L["Minería"], L["Filones y depósitos de mineral."]),
		interruptorTipo("hierbas", L["Hierbas"], L["Las plantas de herboristería."]),
		interruptorTipo("pesca", L["Bancos de peces"], L["Bancos y restos flotantes donde pescar."]),
		interruptorTipo("tesoros", L["Tesoros"], L["Cofres, baúles y almejas que se abren."]),
		control("toggle", "soloProfesiones", L["Ocultar lo de profesiones que no tienes"], L["Sin Minería no ves filones; sin Herboristería, hierbas; sin Pesca, bancos. Los tesoros siempre se ven."]),
		control("toggle", "soloHabilidad", L["Solo lo que ya puedes recolectar"], L["Esconde lo que pide más habilidad de la que tienes. Sin esto se ve gris y tenue."]),
	} },
	{ nombre = L["Mapa"], controles = {
		control("toggle", "agrupar", L["Juntar nodos cercanos al alejar"], L["Los nodos que se pisarían en pantalla van en un solo pin con su cantidad. Al acercar el mapa se separan."]),
		control("toggle", "base", L["Usar la base de datos incluida"], L["Los nodos que trae Alfa (los de GatherLite). Sin esto solo ves los que tú descubriste."]),
	} },
}

local TODOS = {}
for _, s in ipairs(SECCIONES) do
	for _, c in ipairs(s.controles) do TODOS[#TODOS + 1] = c end
end

local TIPOS_RUTA = {
	{ value = "mineria", text = L["Minería"] }, { value = "hierbas", text = L["Hierbas"] },
	{ value = "pesca", text = L["Bancos de peces"] }, { value = "tesoros", text = L["Tesoros"] },
}

local function recursosRuta()
	local tipo = N.Get(ID, "rutaTipo") or "mineria"
	local out = { { value = "todos", text = L["Todos"] } }
	local elegido, esta = N.Get(ID, "rutaRecurso"), false
	for _, r in ipairs(Ruta.RecursosEn(Ruta.ZonaActual(), tipo)) do
		out[#out + 1] = { value = r.clave, text = ("%s (%d)"):format(r.nombre, r.cuenta) }
		if r.clave == elegido then esta = true end
	end
	if elegido and elegido ~= "todos" and not esta and M.porClave[elegido] then
		out[#out + 1] = { value = elegido, text = ("%s (0)"):format(R.Nombre(M.porClave[elegido])) }
	end
	return out
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
local SH = W.SHELL
local SECCION_H = type(W.PLAIN_SECTION_H) == "number" and W.PLAIN_SECTION_H or 30
local HUECO = 22        -- entre secciones
local PAD = 16          -- dentro de un panel
local FILA = 30         -- una fila de lista
local MAX_FILAS = 10

local pagina            -- la vista, una vez armada
local V = {}            -- sus piezas

local function pad()
	local p = type(SH) == "table" and SH.pad
	return type(p) == "number" and p or 32
end

local function opciones()
	local UI = A.UI
	return type(UI) == "table" and UI.Options or nil
end

local function ancho()
	local O = opciones()
	local win = O and O.frame
	local w = type(win) == "table" and win.BodyWidth
	if type(w) == "number" and w > 0 then return w end
	local vw = pagina and pagina:GetWidth()
	if type(vw) == "number" and vw > 2 * pad() then return vw - 2 * pad() end
	return 600
end

local function miles(n)
	local s = tostring(floor(tonumber(n) or 0))
	local sep = N.espanol and "." or ","
	while true do
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1" .. sep .. "%2")
		if k == 0 then return s end
	end
end

local function nombreZona(mapID)
	local C = A.Compat
	return (C and C.MapName and C.MapName(mapID)) or L["Zona %d"]:format(tonumber(mapID) or 0)
end

-- Una insignia redonda con un ícono (el de un tipo o un recurso).
local function insignia(parent, tam)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(tam, tam)
	M.P.Construir(f)
	f:EnableMouse(false)
	return f
end

local function pintarInsigniaTipo(f, tipo, tam)
	local tex, glifo = R.IconoTipo(tipo)
	f:SetSize(tam, tam)
	f.icono:SetTexture(tex)
	local c = M.TIPO[tipo].color
	if glifo then
		f.icono:SetTexCoord(0, 1, 0, 1)
		f.icono:SetSize(tam * 0.78, tam * 0.78)
		f.icono:SetVertexColor(c[1], c[2], c[3], 1)
	else
		f.icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		f.icono:SetSize(tam, tam)
		f.icono:SetVertexColor(1, 1, 1, 1)
	end
	f.fondo:SetSize(tam * 1.2, tam * 1.2)
	f.fondo:SetVertexColor(0, 0, 0, 0.6)
	f.aro:SetSize(tam * 1.42, tam * 1.42)
	f.aro:SetVertexColor(c[1], c[2], c[3], 0.95)
	f.cuenta:Hide()
end

-- Listas del historial: filas reutilizables (ícono, nombre, detalle, valor).
local function fila(lista, k, parent)
	local f = lista.filas[k]
	if f then return f end
	f = CreateFrame("Frame", nil, parent)
	f:SetHeight(FILA)
	f.Icono = f:CreateTexture(nil, "ARTWORK")
	f.Icono:SetSize(18, 18)
	f.Icono:SetPoint("LEFT", f, "LEFT", PAD, 0)
	f.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.Nombre = W.Text(f, "body", "text")
	f.Nombre:SetPoint("LEFT", f.Icono, "RIGHT", 10, 0)
	f.Detalle = W.Text(f, "small", "textMuted")
	f.Valor = W.Text(f, "number", "text")
	f.Valor:SetJustifyH("RIGHT")
	f.Valor:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
	f.Detalle:SetPoint("RIGHT", f.Valor, "LEFT", -12, 0)
	f.Detalle:SetJustifyH("RIGHT")
	f.Linea = W.Divider(f, false, 0.6)
	f.Linea:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 0)
	f.Linea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 0)
	lista.filas[k] = f
	return f
end

local function nuevaLista(view, titulo)
	local l = { filas = {}, titulo = titulo }
	l.Panel = W.RowPanel(view)
	l.Titulo = W.Text(view, "label", "textDim")
	l.Titulo:SetText(titulo)
	l.Vacio = W.Text(view, "note", "textMuted")
	l.Vacio:SetWordWrap(true)
	l.Vacio:SetJustifyV("TOP")
	return l
end

-- Pinta `datos` = { { icono, nombre, detalle, valor }, ... } en la lista,
-- desde y; -> nueva y.
local function pintarLista(l, view, datos, y, w, vacio)
	l.Titulo:ClearAllPoints()
	l.Titulo:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -y)
	l.Titulo:Show()
	y = y + 22
	local n = min(#datos, MAX_FILAS)
	if n == 0 then
		for _, f in ipairs(l.filas) do f:Hide() end
		l.Panel:Hide()
		l.Vacio:SetText(vacio or "")
		l.Vacio:SetWidth(w)
		l.Vacio:ClearAllPoints()
		l.Vacio:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -y)
		l.Vacio:Show()
		return y + math.ceil(l.Vacio:GetStringHeight()) + 6
	end
	l.Vacio:Hide()
	local top = y
	for k = 1, n do
		local d = datos[k]
		local f = fila(l, k, view)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -y)
		f:SetWidth(w)
		if d.icono then
			f.Icono:SetTexture(d.icono)
			if d.glifo then
				local c = M.TIPO.tesoros.color
				f.Icono:SetTexCoord(0, 1, 0, 1)
				f.Icono:SetVertexColor(c[1], c[2], c[3], 1)
			else
				f.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				f.Icono:SetVertexColor(1, 1, 1, 1)
			end
			f.Icono:Show()
			f.Nombre:SetPoint("LEFT", f.Icono, "RIGHT", 10, 0)
		else
			f.Icono:Hide()
			f.Nombre:SetPoint("LEFT", f, "LEFT", PAD, 0)
		end
		f.Nombre:SetText(d.nombre or "")
		f.Detalle:SetText(d.detalle or "")
		f.Valor:SetText(d.valor or "")
		f.Nombre:SetWidth(max(60, w - PAD * 2 - 28 - (d.detalle and 190 or 70)))
		f.Linea:SetShown(k < n)
		f:Show()
		y = y + FILA
	end
	for k = n + 1, #l.filas do l.filas[k]:Hide() end
	l.Panel:ClearAllPoints()
	l.Panel:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -top)
	l.Panel:SetSize(w, y - top)
	l.Panel:Show()
	if #datos > n then
		l.Vacio:SetText(L["y %d más"]:format(#datos - n))
		l.Vacio:SetWidth(w)
		l.Vacio:ClearAllPoints()
		l.Vacio:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -(y + 4))
		l.Vacio:Show()
		y = y + 22
	end
	return y
end

local function ordenadoPorValor(t)
	local out = {}
	for k, v in pairs(t or {}) do out[#out + 1] = { k = k, v = tonumber(v) or 0 } end
	table.sort(out, function(a, b)
		if a.v ~= b.v then return a.v > b.v end
		return tostring(a.k) < tostring(b.k)
	end)
	return out
end

local function porHora(total, seg)
	if seg < 300 or total == 0 then return nil end
	return floor(total / (seg / 3600) + 0.5)
end

---------------------------------------------------------------------------
-- Piezas de la página
---------------------------------------------------------------------------
local function armarResumen(view)
	local p = W.RowPanel(view)
	V.resumen = p
	V.resEtiqueta = W.Text(p, "caption", "textMuted")
	V.resEtiqueta:SetText(L["ESTA SESIÓN"])
	V.resNumero = W.Text(p, "hero", "text")
	V.resPalabra = W.Text(p, "body", "textDim")
	V.resLinea = W.Text(p, "note", "textMuted")
	V.resTotal = W.Text(p, "small", "textMuted")
	V.resTotal:SetJustifyH("RIGHT")
	V.tipos = {}
	for _, tipo in ipairs(M.TIPOS) do
		local b = CreateFrame("Frame", nil, p)
		b:SetHeight(44)
		b.Insignia = insignia(b, 20)
		b.Insignia:SetPoint("LEFT", b, "LEFT", 4, 0)
		b.Cuenta = W.Text(b, "title", "text")
		b.Cuenta:SetPoint("TOPLEFT", b.Insignia, "TOPRIGHT", 12, 4)
		b.Nombre = W.Text(b, "small", "textMuted")
		b.Nombre:SetPoint("TOPLEFT", b.Cuenta, "BOTTOMLEFT", 0, -2)
		b.Nombre:SetText(R.NombreTipo(tipo))
		b.tipo = tipo
		V.tipos[#V.tipos + 1] = b
	end
end

local function layoutResumen(view, y, w)
	local s = R.Sesion()
	local P = R.Personaje()
	local dur = max(0, time() - (tonumber(s.inicio) or time()))
	local total = tonumber(s.total) or 0
	local p = V.resumen
	p:ClearAllPoints()
	p:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -y)
	p:SetWidth(w)
	V.resEtiqueta:ClearAllPoints()
	V.resEtiqueta:SetPoint("TOPLEFT", p, "TOPLEFT", PAD + 2, -14)
	V.resNumero:SetText(miles(total))
	V.resNumero:ClearAllPoints()
	V.resNumero:SetPoint("TOPLEFT", V.resEtiqueta, "BOTTOMLEFT", 0, -6)
	V.resPalabra:SetText(total == 1 and L["nodo recolectado"] or L["nodos recolectados"])
	V.resPalabra:ClearAllPoints()
	V.resPalabra:SetPoint("BOTTOMLEFT", V.resNumero, "BOTTOMRIGHT", 10, 3)
	local partes = { L["en %s"]:format(N.Duracion(dur)) }
	local ph = porHora(total, dur)
	if ph then partes[#partes + 1] = L["%s por hora"]:format(miles(ph)) end
	local zona = R.PosicionJugador()
	if zona then partes[#partes + 1] = nombreZona(zona) end
	V.resLinea:SetText(table.concat(partes, "  ·  "))
	V.resLinea:ClearAllPoints()
	V.resLinea:SetPoint("TOPLEFT", V.resNumero, "BOTTOMLEFT", 0, -6)
	V.resTotal:SetText(L["Este personaje: %s en total"]:format(miles(P.total or 0)))
	V.resTotal:ClearAllPoints()
	V.resTotal:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD - 2, -14)
	local fila0 = 14 + 14 + 6 + 30 + 6 + 16 + 14
	local cw = (w - PAD * 2) / #V.tipos
	for k, b in ipairs(V.tipos) do
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", p, "TOPLEFT", PAD + (k - 1) * cw, -fila0)
		b:SetWidth(cw)
		pintarInsigniaTipo(b.Insignia, b.tipo, 20)
		local n = tonumber(s.tipos[b.tipo]) or 0
		b.Cuenta:SetText(miles(n))
		W.Color(b.Cuenta, n > 0 and "text" or "textMuted")
		b:SetAlpha(R.TipoActivo(b.tipo) and 1 or 0.55)
	end
	local h = fila0 + 44 + 14
	p:SetHeight(h)
	return y + h
end

local function armarRuta(view)
	V.rutaH = W.SectionHeader(view, { plain = true })
	W.SetSection(V.rutaH, L["Ruta de farmeo"])
	V.rutaPanel = W.RowPanel(view)
	-- Los textos van en el panel: así quedan sobre su fondo.
	V.rutaZona = W.Text(V.rutaPanel, "body", "text")
	V.rutaEstado = W.Text(V.rutaPanel, "note", "textDim")
	V.rutaEstado:SetWordWrap(true)
	V.rutaEstado:SetJustifyV("TOP")
	V.rutaTipo = W.Dropdown(view, L["Qué recolectar"], clave("rutaTipo"), TIPOS_RUTA,
		L["El tipo de nodos que une la ruta."])
	V.rutaRecurso = W.Dropdown(view, L["Recurso"], clave("rutaRecurso"), recursosRuta,
		L["Todos los de ese tipo, o solo uno (por ejemplo, solo cobre). Entre paréntesis, cuántos hay en tu zona."])
	for _, r in ipairs({ V.rutaTipo, V.rutaRecurso }) do W.RowDetails(r, { inset = PAD, marks = false }) end
	V.bCrear = W.Button(view, L["Crear ruta"], function()
		local zona = Ruta.ZonaActual()
		local ok, motivo = Ruta.Crear(N.Get(ID, "rutaTipo") or "mineria", N.Get(ID, "rutaRecurso") or "todos", zona, function(r)
			if r and r.n then N.Imprimir(L["Ruta lista en %s: %s"]:format(nombreZona(r.mapa), Ruta.Resumen(r) or "")) end
		end)
		if not ok then
			V.aviso = motivo
			M.Pagina.Actualizar()
		else
			V.aviso = nil
		end
	end, { primary = true, icon = "icon-goto" })
	V.bGuiar = W.Button(view, L["Guiarme"], function()
		local r = Ruta.Actual()
		if r and r.guiando then Ruta.Detener() else Ruta.Guiar() end
	end)
	V.bMapa = W.Button(view, L["Ver en el mapa"], function()
		local r = Ruta.Actual()
		local C = A.Compat
		local mapa = (r and r.mapa) or Ruta.ZonaActual()
		if mapa and C and C.OpenWorldMap then C.OpenWorldMap(mapa) end
	end)
	V.bBorrar = W.Button(view, L["Borrar"], function() Ruta.Borrar() end, { ghost = true })
end

local function habilitar(b, on)
	if on then b:Enable() else b:Disable() end
	b:SetAlpha(on and 1 or 0.4)
end

local function textoRuta()
	local r = Ruta.Actual()
	if Ruta.Calculando() then return L["Calculando la vuelta más corta..."] end
	if V.aviso then return V.aviso end
	if not r then
		return L["Elige qué recolectar y crea la ruta: une los nodos de tu zona en una vuelta corta, la dibuja en el mapa y la flecha te lleva de parada en parada."]
	end
	local recurso = r.recurso and r.recurso ~= "todos" and M.porClave[r.recurso] and R.Nombre(M.porClave[r.recurso]) or R.NombreTipo(r.tipo)
	local linea = L["%s en %s: %s."]:format(recurso, nombreZona(r.mapa), Ruta.Resumen(r) or "")
	if r.guiando then
		linea = linea .. " " .. L["La flecha te lleva a la parada %d."]:format(r.siguiente or 1)
	else
		linea = linea .. " " .. L["Pulsa Guiarme para que la flecha te lleve."]
	end
	return linea
end

local function layoutRuta(view, y, w)
	V.rutaH:ClearAllPoints()
	V.rutaH:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -y)
	V.rutaH:SetWidth(w)
	y = y + SECCION_H
	local top = y
	local zona = Ruta.ZonaActual()
	V.rutaZona:SetText(zona and L["Tu zona: %s"]:format(nombreZona(zona)) or L["Tu zona: (desconocida)"])
	V.rutaZona:ClearAllPoints()
	V.rutaZona:SetPoint("TOPLEFT", view, "TOPLEFT", pad() + PAD, -(y + 14))
	y = y + 14 + 18
	V.rutaEstado:SetText(textoRuta())
	V.rutaEstado:SetWidth(w - PAD * 2)
	V.rutaEstado:ClearAllPoints()
	V.rutaEstado:SetPoint("TOPLEFT", view, "TOPLEFT", pad() + PAD, -(y + 4))
	y = y + 4 + math.ceil(V.rutaEstado:GetStringHeight()) + 10
	for _, r in ipairs({ V.rutaTipo, V.rutaRecurso }) do
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -y)
		if r.Refresh then r:Refresh() end
		y = y + W.LayoutRow(r, w)
		if r.Rule then r.Rule:Show() end
	end
	y = y + 12
	local x = pad() + PAD
	local ruta = Ruta.Actual()
	local calculando = Ruta.Calculando()
	W.SetButtonText(V.bGuiar, ruta and ruta.guiando and L["Detener"] or L["Guiarme"])
	habilitar(V.bCrear, not calculando and zona ~= nil)
	habilitar(V.bGuiar, ruta ~= nil and not calculando)
	local C = A.Compat
	habilitar(V.bMapa, (ruta or zona) ~= nil and C and C.CanOpenWorldMap and C.CanOpenWorldMap() and true or false)
	habilitar(V.bBorrar, ruta ~= nil and not calculando)
	for _, b in ipairs({ V.bCrear, V.bGuiar, V.bMapa, V.bBorrar }) do
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
		b:Show()
		x = x + b:GetWidth() + 8
	end
	y = y + (V.bCrear:GetHeight() or 28) + PAD
	V.rutaPanel:ClearAllPoints()
	V.rutaPanel:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -top)
	V.rutaPanel:SetSize(w, y - top)
	V.rutaPanel:Show()
	return y
end

-- Filas de ajustes: las del menú de Alfa (UI.Options.Rows) si están; si no,
-- las mismas piezas del kit a mano.
local cache = {}
local function filasAjustes(view, controles, y, panel, w)
	local O = opciones()
	if O and type(O.Rows) == "function" and type(O.frame) == "table" then
		return O.Rows(view, controles, y, cache, panel)
	end
	local top = y
	for i, c in ipairs(controles) do
		local fw = cache[c]
		if not fw then
			local opts = (c.get or c.set) and { get = c.get, set = c.set } or nil
			if c.kind == "slider" then
				fw = W.Slider(view, c.label, c.key, c.min or 0, c.max or 1, c.step or 0.1, c.format, c.help, nil, opts)
			else
				fw = W.Toggle(view, c.label, c.key, c.help, nil, opts)
			end
			W.RowDetails(fw, { inset = PAD })
			cache[c] = fw
		end
		fw:ClearAllPoints()
		fw:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -y)
		fw:Show()
		if fw.Refresh then fw:Refresh() end
		y = y + W.LayoutRow(fw, w)
		if fw.Rule then fw.Rule:SetShown(i < #controles) end
	end
	if panel then
		panel:ClearAllPoints()
		panel:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -top)
		panel:SetSize(w, max(1, y - top))
		panel:Show()
	end
	return y
end

local function armarAjustes(view)
	V.secciones = {}
	for _, s in ipairs(SECCIONES) do
		local h = W.SectionHeader(view, { plain = true })
		W.SetSection(h, s.nombre)
		V.secciones[#V.secciones + 1] = { h = h, panel = W.RowPanel(view), controles = s.controles, mundo = s.mundo }
	end
	V.notaMundo = W.Text(view, "note", "textMuted")
	V.notaMundo:SetWordWrap(true)
	V.notaMundo:SetText(L["Con el módulo Mundo, estos tipos también son capas en su control de capas."])
end

local function layoutAjustes(view, y, w)
	for _, s in ipairs(V.secciones) do
		s.h:ClearAllPoints()
		s.h:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -y)
		s.h:SetWidth(w)
		y = y + SECCION_H
		y = filasAjustes(view, s.controles, y, s.panel, w)
		if s.mundo and R.mundo then
			V.notaMundo:SetWidth(w)
			V.notaMundo:ClearAllPoints()
			V.notaMundo:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -(y + 6))
			V.notaMundo:Show()
			y = y + 6 + math.ceil(V.notaMundo:GetStringHeight())
		end
		y = y + HUECO
	end
	if not R.mundo then V.notaMundo:Hide() end
	return y
end

local function armarHistorial(view)
	V.histH = W.SectionHeader(view, { plain = true })
	W.SetSection(V.histH, L["Historial"])
	V.lRecursos = nuevaLista(view, L["Esta sesión, por recurso"])
	V.lObjetos = nuevaLista(view, L["Lo que obtuviste en esta sesión"])
	V.lZonas = nuevaLista(view, L["Por zona (este personaje)"])
	V.lSesiones = nuevaLista(view, L["Sesiones anteriores"])
end

local function datosRecursos(s)
	local out = {}
	for _, e in ipairs(ordenadoPorValor(s.recursos)) do
		local g = M.porClave[e.k]
		if g then
			local gr = M.GRUPOS[g]
			local icono, glifo = R.Icono(g)
			out[#out + 1] = { icono = icono, glifo = glifo, nombre = R.Nombre(g), detalle = R.NombreTipo(gr.tipo), valor = miles(e.v) }
		end
	end
	return out
end

local function datosObjetos(s)
	local out = {}
	local C = A.Compat
	for _, e in ipairs(ordenadoPorValor(s.objetos)) do
		local id = tonumber(e.k)
		if id then
			local nombre = C.GetItemName and C.GetItemName(id)
			if not nombre then
				if C.RequestItem then C.RequestItem(id) end
				nombre = L["Cargando..."]
				V.esperaObjetos = true
			end
			out[#out + 1] = { icono = C.ItemIcon and C.ItemIcon(id), nombre = nombre, valor = "×" .. miles(e.v) }
		end
	end
	return out
end

local function datosZonas(P)
	local out = {}
	local lista = {}
	for mapID, z in pairs(P.zonas or {}) do
		if type(z) == "table" then lista[#lista + 1] = { m = mapID, z = z, v = tonumber(z.total) or 0 } end
	end
	table.sort(lista, function(a, b)
		if a.v ~= b.v then return a.v > b.v end
		return tostring(a.m) < tostring(b.m)
	end)
	for _, e in ipairs(lista) do
		local partes = {}
		for _, tipo in ipairs(M.TIPOS) do
			local n = tonumber(e.z.tipos and e.z.tipos[tipo]) or 0
			if n > 0 then partes[#partes + 1] = R.NombreTipo(tipo) .. " " .. miles(n) end
		end
		out[#out + 1] = { nombre = nombreZona(e.m), detalle = table.concat(partes, "  ·  "), valor = miles(e.v) }
	end
	return out
end

local function datosSesiones(P)
	local out = {}
	local actual = R.Sesion()
	local lista = P.sesiones or {}
	for k = #lista, 1, -1 do
		local s = lista[k]
		if type(s) == "table" and s ~= actual and (tonumber(s.total) or 0) > 0 then
			local dur = max(0, (tonumber(s.fin) or 0) - (tonumber(s.inicio) or 0))
			local detalle = N.Duracion(dur)
			local ph = porHora(tonumber(s.total) or 0, dur)
			if ph then detalle = detalle .. "  ·  " .. L["%s por hora"]:format(miles(ph)) end
			out[#out + 1] = { nombre = date("%d/%m/%Y %H:%M", tonumber(s.inicio) or 0), detalle = detalle, valor = miles(s.total) }
		end
	end
	return out
end

local function layoutHistorial(view, y, w)
	V.histH:ClearAllPoints()
	V.histH:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -y)
	V.histH:SetWidth(w)
	y = y + SECCION_H
	local s, P = R.Sesion(), R.Personaje()
	V.esperaObjetos = false
	y = pintarLista(V.lRecursos, view, datosRecursos(s), y, w,
		L["Todavía no recolectas nada en esta sesión. Mina, herboriza, pesca en un banco o abre un cofre y aparece aquí."]) + 14
	y = pintarLista(V.lObjetos, view, datosObjetos(s), y, w, L["Aquí verás los objetos que te dio cada nodo."]) + 14
	y = pintarLista(V.lZonas, view, datosZonas(P), y, w, L["Cuando recolectes, aquí verás cuánto en cada zona."]) + 14
	y = pintarLista(V.lSesiones, view, datosSesiones(P), y, w, L["Tus sesiones anteriores con algo recolectado aparecen aquí."])
	return y + HUECO
end

local function armarDatos(view)
	V.datosH = W.SectionHeader(view, { plain = true })
	W.SetSection(V.datosH, L["Datos"])
	V.datosTexto = W.Text(view, "note", "textDim")
	V.datosTexto:SetWordWrap(true)
	V.datosTexto:SetJustifyV("TOP")
	V.tImportar = W.ActionTile(view, "icon-collect", L["Traer lo de GatherLite"],
		L["Copia los nodos que recolectaste con GatherLite (debe estar activo). Ya se hace solo la primera vez."], function()
			local n = R.ImportarGatherLite()
			if n then N.Imprimir(L["Se trajeron %d nodos de GatherLite."]:format(n)) end
			M.Pagina.Actualizar()
		end)
	V.tBorrarNodos = W.ActionTile(view, "reset", L["Borrar lo que descubrí"],
		L["Quita los nodos que anotaste tú. La base incluida se queda."], function()
			W.Modal({ title = L["¿Borrar lo que descubriste?"], icon = "reset", danger = true, action = L["Borrar"],
				text = L["Se quitan los nodos que anotaste al recolectar y cuántas veces los recolectaste. No se puede deshacer."],
				onAccept = function() R.BorrarDescubiertos() end })
		end, { danger = true })
	V.tBorrarHist = W.ActionTile(view, "reset", L["Borrar el historial"],
		L["Las sesiones y lo recolectado por zona de este personaje."], function()
			W.Modal({ title = L["¿Borrar el historial?"], icon = "reset", danger = true, action = L["Borrar"],
				text = L["Se borran las sesiones, las zonas y los objetos de este personaje. No se puede deshacer."],
				onAccept = function() R.BorrarHistorial() end })
		end, { danger = true })
end

local function layoutDatos(view, y, w)
	V.datosH:ClearAllPoints()
	V.datosH:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -y)
	V.datosH:SetWidth(w)
	y = y + SECCION_H
	local base, propios, zonas = R.Conteos()
	local texto = L["La base incluida trae %s lugares en %d zonas. Tú descubriste %s."]:format(miles(base), zonas, miles(propios))
	if R.HayGatherLite() then
		texto = texto .. " " .. L["GatherLite sigue activo: Alfa ya hace lo mismo, así que puedes desactivarlo para no ver los nodos dos veces."]
	end
	V.datosTexto:SetText(texto)
	V.datosTexto:SetWidth(w)
	V.datosTexto:ClearAllPoints()
	V.datosTexto:SetPoint("TOPLEFT", view, "TOPLEFT", pad(), -y)
	y = y + math.ceil(V.datosTexto:GetStringHeight()) + 12
	local tiles = { V.tBorrarNodos, V.tBorrarHist }
	if R.HayGatherLite() then
		table.insert(tiles, 1, V.tImportar)
		V.tImportar:Show()
	else
		V.tImportar:Hide()
	end
	local cols = 2
	local cw = (w - 12) / cols
	local filaH = 0
	for k, t in ipairs(tiles) do
		local col = (k - 1) % cols
		if col == 0 and k > 1 then
			y = y + filaH + 12
			filaH = 0
		end
		local h = W.LayoutTile(t, cw)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", view, "TOPLEFT", pad() + col * (cw + 12), -y)
		t:Show()
		filaH = max(filaH, h)
	end
	return y + filaH + 24
end

local function construir(view)
	pagina = view
	armarResumen(view)
	armarRuta(view)
	armarAjustes(view)
	armarHistorial(view)
	armarDatos(view)
	view.Refresh = function()
		local w = ancho()
		local y = 16
		y = layoutResumen(view, y, w) + HUECO
		y = layoutRuta(view, y, w) + HUECO
		y = layoutAjustes(view, y, w)
		y = layoutHistorial(view, y, w)
		y = layoutDatos(view, y, w)
		return y
	end
	view:HookScript("OnShow", function() M.Pagina.Actualizar() end)
end

---------------------------------------------------------------------------
-- Volver a armar la página abierta (como mucho 4 veces por segundo).
---------------------------------------------------------------------------
M.Pagina = {}
local pendiente = false

local function rehacer()
	pendiente = false
	if not (pagina and pagina:IsVisible() and pagina.Refresh) then return end
	local h = pagina.Refresh()
	if type(h) ~= "number" then return end
	pagina:SetHeight(h)
	local O = opciones()
	local win = O and O.frame
	if type(win) == "table" and W.ShellBody then W.ShellBody(win, h) end
end

function M.Pagina.Actualizar()
	if pendiente then return end
	pendiente = true
	A.After(0.25, rehacer)
end

R.AlCambiar(function() M.Pagina.Actualizar() end)
A.RegisterEvent("GET_ITEM_INFO_RECEIVED", function()
	if V.esperaObjetos then M.Pagina.Actualizar() end
end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() M.Pagina.Actualizar() end)

---------------------------------------------------------------------------
-- El módulo
---------------------------------------------------------------------------
N.Modulo({
	id = ID, nombre = L["Recolección"], icono = "icon-craft", orden = 32,
	subtitulo = L["Minería, hierbas, pesca y tesoros en tu mapa y minimapa, con rutas de farmeo e historial."],
	comando = "recoleccion",
	ajustes = AJUSTES,
	controles = TODOS,
	construir = construir,
})

-- /alfa recoleccion [ruta [tipo] | guiar | parar | mapa | minimapa | importar]
local TIPO_POR_PALABRA = {
	mineria = "mineria", ["minería"] = "mineria", mining = "mineria", minar = "mineria",
	hierbas = "hierbas", herboristeria = "hierbas", ["herboristería"] = "hierbas", herbs = "hierbas",
	pesca = "pesca", fishing = "pesca", peces = "pesca",
	tesoros = "tesoros", cofres = "tesoros", chests = "tesoros",
}

A.RegisterCommand("recoleccion", function(resto)
	local orden, arg = (resto or ""):lower():match("^%s*(%S*)%s*(%S*)")
	if orden == "" then return N.Abrir(ID) end
	if orden == "ruta" then
		local tipo = TIPO_POR_PALABRA[arg] or N.Get(ID, "rutaTipo") or "mineria"
		local recurso = TIPO_POR_PALABRA[arg] and "todos" or (N.Get(ID, "rutaRecurso") or "todos")
		local ok, motivo = Ruta.Crear(tipo, recurso, nil, function(r)
			if r and r.n then
				N.Imprimir(L["Ruta lista en %s: %s"]:format(nombreZona(r.mapa), Ruta.Resumen(r) or ""))
				Ruta.Guiar()
			end
		end)
		if not ok then N.Imprimir(motivo) end
	elseif orden == "guiar" then
		if not Ruta.Guiar() then N.Imprimir(L["Primero crea una ruta: /alfa recoleccion ruta"]) end
	elseif orden == "parar" then
		Ruta.Detener()
	elseif orden == "mapa" or orden == "minimapa" then
		N.Set(ID, orden, N.Get(ID, orden) == false)
		N.Imprimir(N.Get(ID, orden) ~= false and L["Nodos visibles."] or L["Nodos ocultos."])
	elseif orden == "importar" then
		local n = R.ImportarGatherLite()
		N.Imprimir(n and L["Se trajeron %d nodos de GatherLite."]:format(n) or L["GatherLite no está activo."])
	else
		N.Imprimir(L["Uso: /alfa recoleccion [ruta [mineria|hierbas|pesca|tesoros] | guiar | parar | mapa | minimapa | importar]"])
	end
end, L["Abre Recolección. Con «ruta», crea y sigue una ruta de farmeo en tu zona."])

---------------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------------
local FILTROS = { mineria = true, hierbas = true, pesca = true, tesoros = true, soloProfesiones = true, soloHabilidad = true, base = true }

A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" then return end
	local k = path:match("^recoleccion%.(.+)$")
	if not k then
		-- Ajustes de vuelta a sus valores: todos ("") o los de este módulo.
		if path == "" or path == ID then
			R.Refiltrar()
			M.Pagina.Actualizar()
		end
		return
	end
	if FILTROS[k] then R.Refiltrar() end
	if k == "rutaTipo" or k == "rutaRecurso" then V.aviso = nil end
	if k == "rutaTipo" then N.Set(ID, "rutaRecurso", "todos") end
	M.Pagina.Actualizar()
end)

local habilidadesPendiente = false
local function releer()
	habilidadesPendiente = false
	R.LeerHabilidades()
	R.Refiltrar()
end
A.RegisterEvent("SKILL_LINES_CHANGED", function()
	if habilidadesPendiente then return end
	habilidadesPendiente = true
	A.After(0.3, releer)
end)

A.RegisterEvent("PLAYER_LOGOUT", function() R.CerrarSesion() end)

A.OnLogin(function()
	R.LeerHabilidades()
	R.Refiltrar()
	R.Sesion()
	M.Mapa.Instalar()
	M.Mini.Instalar()
	-- Las habilidades pueden llegar tarde; y lo de GatherLite pasa una vez.
	A.After(3, function()
		releer()
		local D = R.Datos()
		if not D.importadoGL and R.HayGatherLite() then
			local n = R.ImportarGatherLite()
			if n and n > 0 then N.Imprimir(L["Recolección: se trajeron %d nodos que recolectaste con GatherLite."]:format(n)) end
		end
	end)
end)
