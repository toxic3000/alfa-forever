-- Alfa - Rutas: el bloque "Mis rutas" de la página Ruta (toxic3000 / La Jauría).
-- GPL-3.0.
--
-- Tu ruta como un árbol: un tronco con una huella por tramo (XP, oro,
-- profesión, clase u objeto) y su cantidad; un clic abre el tramo y muestra
-- las misiones que Alfa eligió (se cambian, se fijan o se quitan con un
-- clic), el material o el objeto. Abajo, agregar tramos, el resumen y
-- "Seguir esta ruta". Sin rutas: las plantillas para empezar. El catálogo de
-- objetos vive en la Enciclopedia: su "Agregar a mi ruta" llega aquí
-- (AlfaRuta.AgregarObjeto).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K
local P, I = M.Plan, M.Indice

local ipairs, pairs, type, tostring, tonumber = ipairs, pairs, type, tostring, tonumber
local floor, max, min, format = math.floor, math.max, math.min, string.format

local est = { abierto = nil, alt = nil, altLista = nil, ocupado = false, avance = 0, motivo = nil }
local alCambiarPagina

local function rehacer() if alCambiarPagina then alCambiarPagina() end end

local function ruta() return M.RutaEditada() end

local function tramoPorUid(r, uid)
	for i, t in ipairs(r and r.tramos or {}) do if t.uid == uid then return t, i end end
	return nil
end

local function cuenta(id)
	local Cp = M.Motor("Compat")
	return M.num(Cp and Cp.GetItemCount and Cp.GetItemCount(id, true), 0)
end

local function tramoHecho(t, pt)
	if t.rama == "prof" or t.rama == "objeto" then
		local item = (pt and pt.item) or t.item
		return item ~= nil and cuenta(item) >= (t.cantidad or 1)
	end
	if not (pt and pt.quests and #pt.quests > 0) then return false end
	for _, q in ipairs(pt.quests) do if not I.Hecha(q) then return false end end
	return true
end

local function resumen(t, pt)
	if not pt then return est.ocupado and L["Alfa está eligiendo..."] or "" end
	local extra = (pt.antes and #pt.antes > 0) and ("  \194\183  " .. format(L["+%d de XP antes (nivel %d)"], #pt.antes, pt.nivel or 0)) or ""
	if t.rama == "xp" then return format(L["+%s XP  \194\183  %d misiones"], M.Miles(pt.xp), #pt.quests) .. extra end
	if t.rama == "oro" then return format(L["%s estimado  \194\183  %d misiones"], N.Dinero(pt.oro, true), #pt.quests) .. extra end
	if t.rama == "clase" then
		if pt.premios and pt.premios[1] then return format(L["Premio: %s"], M.NombreObjeto(pt.premios[1])) .. extra end
		return format(L["%d misiones de tu clase"], #pt.quests) .. extra
	end
	if t.rama == "prof" then
		local zona = pt.zona and M.Zona(pt.zona)
		local tienes = pt.item and cuenta(pt.item) or 0
		return (zona and format(L["Tienes %d  \194\183  en %s"], tienes, zona) or format(L["Tienes %d"], tienes)) .. extra
	end
	if t.rama == "objeto" then return (pt.fuente or "") .. extra end
	return extra
end

---------------------------------------------------------------------------
-- Acciones
---------------------------------------------------------------------------

local function planear()
	local r = ruta()
	if not r or #r.tramos == 0 then return end
	est.ocupado, est.avance, est.motivo = true, 0, nil
	P.Armar(r, function(plan, motivo)
		est.ocupado = false
		est.motivo = not plan and motivo or nil
		rehacer()
	end, function(f) est.avance = M.num(f, 0) end)
end

local pendiente = false
M.Escuchar("RUTA", function()
	if pendiente then return end
	pendiente = true
	A.After(0.3, function() pendiente = false planear() rehacer() end)
end)
M.Escuchar("RUTAS", function() est.abierto, est.alt = nil, nil rehacer() end)

local function cambiar(r) M.Cambio(r) rehacer() end

local function sacar(lista, v)
	local out = {}
	for _, x in ipairs(lista or {}) do if x ~= v then out[#out + 1] = x end end
	return out
end

local function fijada(t, q)
	for _, x in ipairs(t.fijas or {}) do if x == q then return true end end
	return false
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
	t.fijas = fijas
	if viejo then
		t.quitar = sacar(t.quitar, viejo)
		t.quitar[#t.quitar + 1] = viejo
	end
	est.alt, est.altLista = nil, nil
	cambiar(r)
end

local function agregarTramo(rama)
	if rama == "objeto" then
		if AlfaEnciclopedia and AlfaEnciclopedia.Abrir then
			AlfaEnciclopedia.Abrir("item")
			M.Aviso(L["Elige el objeto"], L["En su ficha toca «Agregar a mi ruta»."], { icono = "ic-enciclopedia" })
		else
			M.Aviso(L["Elige el objeto"], L["Abre la Enciclopedia y en la ficha del objeto toca «Agregar a mi ruta»."], { icono = "ic-enciclopedia" })
		end
		return
	end
	local r = ruta() or M.NuevaRuta(L["Mi ruta"], {})
	local t = M.NuevoTramo({ rama = rama, item = rama == "prof" and I.MaterialSugerido() or nil })
	r.tramos[#r.tramos + 1] = t
	est.abierto = t.uid
	cambiar(r)
end

---------------------------------------------------------------------------
-- Texto para compartir e importar (una ventana chica con un campo)
---------------------------------------------------------------------------

local vt
local function ventanaTexto(modo)
	if not vt then
		vt = K.Ventana({ nombre = "AlfaRutaTexto", titulo = "", icono = "ic-ruta", ancho = 520, alto = 250 })
		vt.Texto = K.Texto(vt.Cuerpo, "nota", "textoSuave")
		vt.Texto:SetPoint("TOPLEFT", vt.Cuerpo, "TOPLEFT", vt.margen, -K.ESP.base)
		vt.Texto:SetWidth(520 - 2 * vt.margen)
		vt.Texto:SetWordWrap(true)
		local caja = CreateFrame("Frame", nil, vt.Cuerpo)
		caja:SetPoint("TOPLEFT", vt.Cuerpo, "TOPLEFT", vt.margen, -58)
		caja:SetSize(520 - 2 * vt.margen, K.ALTO.control)
		caja.caja = K.Caja(caja, { fondo = "hundido", borde = "lineaFuerte", corte = K.CORTE.control })
		local e = CreateFrame("EditBox", nil, caja)
		e:SetPoint("TOPLEFT", caja, "TOPLEFT", 10, 0)
		e:SetPoint("BOTTOMRIGHT", caja, "BOTTOMRIGHT", -10, 0)
		e:SetAutoFocus(false)
		K.Fuente(e, "etiqueta")
		e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		e:SetScript("OnEnterPressed", function() if vt.alAceptar then vt.alAceptar() end end)
		vt.Campo = e
		vt.Error = K.Texto(vt.Cuerpo, "pequeno", "aviso")
		vt.Error:SetPoint("TOPLEFT", caja, "BOTTOMLEFT", 0, -K.ESP.s)
		vt.Aceptar = K.Boton(vt, "", function() if vt.alAceptar then vt.alAceptar() end end, { tipo = "primario" })
		vt:SetPie({ K.Boton(vt, L["Cerrar"], function() vt:Cerrar() end, { tipo = "fantasma" }), vt.Aceptar })
	end
	local r = ruta()
	vt.Error:SetText("")
	if modo == "exportar" then
		vt:SetTitulo(L["Compartir esta ruta"], r and r.nombre or "")
		K.Escribir(vt.Texto, L["Copia este texto (Ctrl+C) y pásalo a tu manada. Lo pegan en Importar."])
		vt.Campo:SetText(M.Exportar(r))
		vt.Aceptar:SetTexto(L["Seleccionar todo"])
		vt.alAceptar = function() vt.Campo:SetFocus() vt.Campo:HighlightText() end
	elseif modo == "importar" then
		vt:SetTitulo(L["Importar una ruta"], "")
		K.Escribir(vt.Texto, L["Pega aquí (Ctrl+V) el texto de una ruta de Alfa."])
		vt.Campo:SetText("")
		vt.Aceptar:SetTexto(L["Importar"])
		vt.alAceptar = function()
			local nueva, motivo = M.Importar(vt.Campo:GetText() or "")
			if not nueva then vt.Error:SetText(motivo or "") return end
			M.Aviso(L["Ruta importada"], nueva.nombre, { icono = "ic-exito" })
			vt:Cerrar()
			rehacer()
		end
	else
		vt:SetTitulo(L["Nombre de la ruta"], "")
		K.Escribir(vt.Texto, L["Escribe un nombre corto para reconocerla."])
		vt.Campo:SetText(r and r.nombre or "")
		vt.Aceptar:SetTexto(L["Guardar"])
		vt.alAceptar = function()
			local t = (vt.Campo:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
			if r and t ~= "" then
				r.nombre = t:sub(1, 60)
				M.Cambio(r)
			end
			vt:Cerrar()
			rehacer()
		end
	end
	vt:Abrir()
	vt.Campo:SetFocus()
	if modo == "exportar" then vt.Campo:HighlightText() end
end

local function menuRuta(dueno)
	local r = ruta()
	local op = {}
	for _, x in ipairs(M.Rutas()) do
		local activa = M.Personaje().activa == x.id
		op[#op + 1] = { valor = function() M.Personaje().editando = x.id est.abierto = nil rehacer() end,
			texto = x.nombre .. (activa and ("  \194\183  " .. L["en marcha"]) or ""), icono = (r and r.id == x.id) and "ic-huella" or "ic-ruta" }
	end
	op[#op + 1] = { valor = function() M.NuevaRuta(L["Mi ruta"], {}) rehacer() end, texto = L["Nueva ruta vacía"], icono = "ic-mas" }
	for _, p in ipairs(M.PLANTILLAS) do
		op[#op + 1] = { valor = function()
			local n = M.DesdePlantilla(p.clave)
			if n then M.Aviso(format(L["Nueva ruta: %s"], n.nombre), L["Puedes cambiar cada tramo."], { icono = p.icono }) end
			rehacer()
		end, texto = format(L["Plantilla: %s"], p.nombre), icono = p.icono }
	end
	if r then
		op[#op + 1] = { valor = function() ventanaTexto("renombrar") end, texto = L["Cambiar nombre..."], icono = "ic-ajustes" }
		op[#op + 1] = { valor = function()
			local tramos = {}
			for i, t in ipairs(r.tramos) do tramos[i] = M.Copia(t) end
			M.NuevaRuta(format(L["%s (copia)"], r.nombre), tramos, r.plantilla)
			rehacer()
		end, texto = L["Duplicar"], icono = "ic-rejilla" }
		op[#op + 1] = { valor = function() ventanaTexto("exportar") end, texto = L["Compartir..."], icono = "ic-manada" }
	end
	op[#op + 1] = { valor = function() ventanaTexto("importar") end, texto = L["Importar..."], icono = "ic-mas" }
	if r then
		op[#op + 1] = { valor = function()
			K.Dialogo({ titulo = L["¿Borrar esta ruta?"], texto = format(L["%s se borra de todos tus personajes. No se puede deshacer."], r.nombre),
				aceptar = L["Borrar"], peligro = true, alAceptar = function() M.BorrarRuta(r.id) rehacer() end })
		end, texto = L["Borrar esta ruta"], icono = "ic-cerrar" }
	end
	K.Menu(dueno, op, nil, function(fn) if type(fn) == "function" then fn() end end, 260)
end

---------------------------------------------------------------------------
-- Las piezas
---------------------------------------------------------------------------

-- Una misión del tramo abierto (o una alternativa para cambiar).
local function filaMisionTramo(padre)
	local f = CreateFrame("Frame", nil, padre)
	f.Nivel = K.Texto(f, "numero", "textoSuave")
	f.Nivel:SetPoint("LEFT", f, "LEFT", 0, 0)
	f.Nivel:SetWidth(26)
	f.Nivel:SetJustifyH("RIGHT")
	f.Titulo = K.Texto(f, "etiqueta", "texto")
	f.Valor = K.Texto(f, "pequeno", "textoTenue")
	f.Valor:SetJustifyH("RIGHT")
	f.B1 = K.Boton(f, "", nil, { tipo = "fantasma", tam = "chico" })
	f.B2 = K.Boton(f, "", nil, { tipo = "fantasma", tam = "chico" })
	f.B3 = K.Boton(f, "", nil, { tipo = "fantasma", tam = "chico" })
	function f:Set(d)
		self.d = d
		self.Nivel:SetText(d.nivel and tostring(d.nivel) or "")
		K.Escribir(self.Titulo, d.titulo or "")
		K.ColorTexto(self.Titulo, d.hecha and "textoTenue" or "texto")
		K.Escribir(self.Valor, d.valor or "")
		for k, nombre in ipairs({ "B1", "B2", "B3" }) do
			local b, x = self[nombre], d.botones and d.botones[k]
			if x then b:SetTexto(x[1]) b.alClic = x[2] b:Show() else b:Hide() end
		end
	end
	function f:Acomodar(ancho)
		self:SetSize(ancho, K.ALTO.filaCompacta)
		local x = ancho
		for _, nombre in ipairs({ "B3", "B2", "B1" }) do
			local b = self[nombre]
			if b:IsShown() then
				x = x - b:AnchoNatural()
				b:ClearAllPoints()
				b:SetPoint("LEFT", self, "LEFT", x, 0)
				x = x - K.ESP.xs
			end
		end
		local vw = K.Ajustar(self.Valor, 110)
		self.Valor:ClearAllPoints()
		self.Valor:SetPoint("RIGHT", self, "LEFT", x - K.ESP.s, 0)
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("LEFT", self, "LEFT", 34, 0)
		self.Titulo:SetWidth(max(40, x - K.ESP.s - vw - K.ESP.s - 34))
		return K.ALTO.filaCompacta
	end
	return f
end

-- Un tramo: la huella en el tronco, su título y su resumen, sus controles y,
-- abierto, su contenido.
local function filaTramo(padre)
	local f = CreateFrame("Button", nil, padre)
	f:RegisterForClicks("LeftButtonUp")
	f.caja = K.Caja(f, { fondo = "panel", borde = "linea", corte = K.CORTE.tarjeta })
	f.Nodo = CreateFrame("Frame", nil, f)
	f.Nodo:SetSize(32, 32)
	f.Nodo.caja = K.Caja(f.Nodo, { fondo = "elevado", borde = "linea", corte = K.CORTE.control })
	f.Nodo.Icono = K.Icono(f.Nodo, "ic-huella", 16, "acento")
	f.Nodo.Icono:SetPoint("CENTER")
	f.Titulo = K.Texto(f, "subtitulo", "texto")
	f.Sub = K.Texto(f, "pequeno", "textoTenue")
	f.Quitar = K.BotonIcono(f, "ic-cerrar", nil, { tam = 24, icono = 10, ayuda = L["Quitar este tramo"] })
	f.Bajar = K.BotonIcono(f, "chevron-down", nil, { tam = 24, icono = 12, ayuda = L["Bajar"] })
	f.Subir = K.BotonIcono(f, "chevron-up", nil, { tam = 24, icono = 12, ayuda = L["Subir"] })
	f.Mas = K.Boton(f, "+", nil, { tipo = "secundario", tam = "chico", ancho = 24, ayuda = L["Uno más"] })
	f.Cant = K.Texto(f, "numero", "texto")
	f.Cant:SetJustifyH("CENTER")
	f.Cant:SetWidth(26)
	f.Menos = K.Boton(f, "\226\136\146", nil, { tipo = "secundario", tam = "chico", ancho = 24, ayuda = L["Uno menos"] })
	f.Contenido = K.Pila(f, { espacio = K.ESP.xs })
	f.misiones = {}
	f.Notas = K.Texto(f.Contenido, "pequeno", "aviso")
	f.Notas:SetWordWrap(true)
	function f.Notas:Acomodar(ancho) return K.Parrafo(self, ancho, 4) end
	f.Material = K.Desplegable(f.Contenido, { ancho = 260 })
	f.Material.alfaAnchoPropio = true
	f.Objeto = CreateFrame("Frame", nil, f.Contenido)
	f.Objeto.Icono = K.IconoObjeto(f.Objeto, 30)
	f.Objeto.Icono:SetPoint("LEFT", f.Objeto, "LEFT", 0, 0)
	f.Objeto.Nombre = K.Texto(f.Objeto, "cuerpo", "objeto")
	f.Objeto.Nombre:SetPoint("LEFT", f.Objeto.Icono, "RIGHT", K.ESP.m, 0)
	f.Objeto.Ver = K.Boton(f.Objeto, L["Ver en la Enciclopedia"], nil, { tipo = "fantasma", tam = "chico", icono = "ic-enciclopedia" })
	f.Objeto.Ver:SetPoint("RIGHT", f.Objeto, "RIGHT", 0, 0)
	function f.Objeto:Acomodar(ancho) self:SetHeight(36) return 36 end
	f.Volver = K.Boton(f.Contenido, L["Volver"], function() est.alt, est.altLista = nil, nil rehacer() end, { tipo = "fantasma", tam = "chico" })
	f.Volver.alfaAnchoPropio = true
	f:SetScript("OnClick", function(self)
		est.abierto = (est.abierto ~= self.uid) and self.uid or nil
		est.alt, est.altLista = nil, nil
		rehacer()
	end)

	function f:Set(r, t, k, n, plan)
		self.uid = t.uid
		local pt = plan and plan.tramos[t.uid]
		local rama = M.RAMA[t.rama] or M.RAMA.xp
		local hecho = tramoHecho(t, pt)
		local abierto = est.abierto == t.uid
		local relleno = K.Tono(rama.tono)
		self.caja:Estilo({ borde = abierto and relleno or "linea", alfaBorde = abierto and 0.6 or nil })
		self.Nodo.caja:Estilo({ fondo = hecho and relleno or "elevado", alfaFondo = hecho and 0.25 or nil, borde = relleno, alfaBorde = 0.6 })
		K.SetIcono(self.Nodo.Icono, hecho and "ic-exito" or rama.icono, relleno)
		K.Escribir(self.Titulo, M.TituloTramo(t))
		K.ColorTexto(self.Titulo, hecho and "textoTenue" or "texto")
		K.Escribir(self.Sub, hecho and L["Hecho"] or resumen(t, pt))
		self.Cant:SetText(tostring(t.cantidad))
		self.Mas.alClic = function() t.cantidad = min(99, t.cantidad + (t.rama == "prof" and 5 or 1)) cambiar(r) end
		self.Menos.alClic = function() t.cantidad = max(1, t.cantidad - (t.rama == "prof" and 5 or 1)) cambiar(r) end
		self.Subir.alClic = function() if k > 1 then r.tramos[k], r.tramos[k - 1] = r.tramos[k - 1], r.tramos[k] cambiar(r) end end
		self.Bajar.alClic = function() if k < n then r.tramos[k], r.tramos[k + 1] = r.tramos[k + 1], r.tramos[k] cambiar(r) end end
		self.Quitar.alClic = function()
			table.remove(r.tramos, k)
			if est.abierto == t.uid then est.abierto = nil end
			cambiar(r)
		end
		self.Subir:SetShown(k > 1)
		self.Bajar:SetShown(k < n)
		-- Abierto: lo de adentro.
		self.Contenido:Vaciar()
		self.Contenido:SetShown(abierto)
		if not abierto then return end
		local notas = {}
		for _, x in ipairs(pt and pt.notas or {}) do notas[#notas + 1] = x end
		if t.rama == "prof" then
			local ops = {}
			for _, m in ipairs(I.MaterialesOfrecidos()) do
				local extra = m.desde and format(L["habilidad %d+"], m.desde) or format(L["nivel %d+"], m.nivel or 1)
				ops[#ops + 1] = { valor = m.item, texto = M.NombreObjeto(m.item) .. "  (" .. extra .. ")" }
			end
			self.Material:SetOpciones(ops)
			self.Material:SetValor((pt and pt.item) or t.item)
			self.Material.alCambiar = function(item) t.item = item cambiar(r) end
			self.Material:Show()
			self.Contenido:Agregar(self.Material)
		elseif t.rama == "objeto" then
			self.Objeto.Icono:SetObjeto(t.item)
			K.Escribir(self.Objeto.Nombre, t.item and M.NombreObjeto(t.item) or L["Sin objeto"])
			local enc = AlfaEnciclopedia and AlfaEnciclopedia.Abrir
			self.Objeto.Ver:SetShown(enc ~= nil and t.item ~= nil)
			self.Objeto.Ver.alClic = function() if enc then AlfaEnciclopedia.Abrir("item", t.item) end end
			self.Objeto:Show()
			self.Contenido:Agregar(self.Objeto)
			if pt and pt.fuente then table.insert(notas, 1, pt.fuente) end
		end
		local deMisiones = t.rama == "xp" or t.rama == "oro" or t.rama == "clase"
		local datos = {}
		local enAlt = est.alt and est.alt.uid == t.uid
		local p = I.Jugador()
		if enAlt then
			if not est.altLista then notas[#notas + 1] = L["Buscando otras misiones..."] end
			for _, c in ipairs(est.altLista or {}) do
				local e = c.e
				datos[#datos + 1] = { nivel = e.lvl, titulo = M.TituloMision(e.id),
					valor = t.rama == "oro" and N.Dinero(c.valor or I.Oro(e, false), true) or ("+" .. M.Miles(c.valor or I.XPPara(e, p.level)) .. " XP"),
					botones = { { L["Usar esta"], function() reemplazar(r, t, est.alt.quest, e.id) end } } }
			end
		elseif deMisiones then
			for _, q in ipairs(pt and pt.quests or {}) do
				local idx = I.Listo()
				local e = idx and idx.porId[q]
				local hecha = I.Hecha(q)
				local v
				if t.rama == "oro" and e then v = N.Dinero(I.Oro(e, false), true) elseif e then v = "+" .. M.Miles(I.XPPara(e, p.level)) .. " XP" end
				local fija = fijada(t, q)
				datos[#datos + 1] = { nivel = e and e.lvl, titulo = M.TituloMision(q), hecha = hecha, valor = hecha and L["hecha"] or v,
					botones = not hecha and {
						{ L["Cambiar"], function()
							est.alt, est.altLista = { uid = t.uid, quest = q }, nil
							P.Alternativas(r, t.uid, function(lista) if est.alt and est.alt.uid == t.uid then est.altLista = lista rehacer() end end)
							rehacer()
						end },
						{ fija and L["Fija"] or L["Fijar"], function()
							if fija then t.fijas = sacar(t.fijas, q) else t.fijas = t.fijas or {} t.fijas[#t.fijas + 1] = q end
							cambiar(r)
						end },
						{ L["Quitar"], function() reemplazar(r, t, q, nil) end },
					} or nil }
			end
		end
		for i, d in ipairs(datos) do
			local fm = self.misiones[i] or filaMisionTramo(self.Contenido)
			self.misiones[i] = fm
			fm:Set(d)
			fm:Show()
			self.Contenido:Agregar(fm)
		end
		for i = #datos + 1, #self.misiones do self.misiones[i]:Hide() end
		if enAlt then self.Volver:Show() self.Contenido:Agregar(self.Volver) end
		if #notas > 0 then
			K.Escribir(self.Notas, table.concat(notas, "\n"))
			self.Notas:Show()
			self.Contenido:Agregar(self.Notas, { espacio = K.ESP.s })
		end
	end
	function f:Acomodar(ancho)
		local pad = K.ESP.m
		self.Nodo:ClearAllPoints()
		self.Nodo:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad)
		local derecha = ancho - pad
		-- Lugares fijos para quitar, bajar y subir: los controles quedan en
		-- columna de un tramo a otro aunque el primero no suba.
		for _, b in ipairs({ self.Quitar, self.Bajar, self.Subir }) do
			b:ClearAllPoints()
			b:SetPoint("TOPRIGHT", self, "TOPLEFT", derecha, -(pad + 4))
			derecha = derecha - 26
		end
		derecha = derecha - K.ESP.s
		self.Mas:ClearAllPoints()
		self.Mas:SetPoint("TOPRIGHT", self, "TOPLEFT", derecha, -(pad + 4))
		self.Cant:ClearAllPoints()
		self.Cant:SetPoint("RIGHT", self.Mas, "LEFT", -2, 0)
		self.Menos:ClearAllPoints()
		self.Menos:SetPoint("RIGHT", self.Cant, "LEFT", -2, 0)
		local x = pad + 32 + K.ESP.m
		local tw = max(60, derecha - 26 * 2 - 30 - x)
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(pad - 1))
		self.Titulo:SetWidth(tw)
		self.Sub:ClearAllPoints()
		self.Sub:SetPoint("TOPLEFT", self.Titulo, "BOTTOMLEFT", 0, -3)
		self.Sub:SetWidth(tw)
		local h = pad + 32 + pad
		if self.Contenido:IsShown() then
			self.Contenido:ClearAllPoints()
			self.Contenido:SetPoint("TOPLEFT", self, "TOPLEFT", x, -h)
			local ch = self.Contenido:Acomodar(ancho - x - pad)
			if ch > 0 then h = h + ch + pad end
		end
		self:SetSize(ancho, h)
		return h
	end
	return f
end

---------------------------------------------------------------------------
-- El bloque
---------------------------------------------------------------------------

function M.BloqueRutas(padre, alCambiar)
	alCambiarPagina = alCambiar
	local b = K.Pila(padre, { espacio = K.ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Mis rutas"]))
	-- La barra: la ruta que editas y su menú.
	local barra = CreateFrame("Frame", nil, b)
	b.Elegir = K.Boton(barra, "", function(self) menuRuta(self) end, { tipo = "secundario", icono = "ic-ruta" })
	b.Recalcular = K.Boton(barra, L["Recalcular"], function()
		local r = ruta()
		if r then M.Personaje().planes[r.id] = nil end
		planear()
		rehacer()
	end, { tipo = "fantasma", tam = "chico", ayuda = L["Alfa vuelve a elegir desde donde estás ahora (las misiones fijas se quedan)."] })
	function barra:Acomodar(ancho)
		b.Elegir:ClearAllPoints()
		b.Elegir:SetPoint("LEFT", self, "LEFT", 0, 0)
		b.Recalcular:ClearAllPoints()
		b.Recalcular:SetPoint("RIGHT", self, "RIGHT", 0, 0)
		self:SetHeight(K.ALTO.boton)
		return K.ALTO.boton
	end
	b.Barra = b:Agregar(barra)
	-- El árbol: el tronco y los tramos.
	b.Arbol = b:Agregar(K.Pila(b, { espacio = K.ESP.s }))
	b.Tronco = K.Linea(b.Arbol, "lineaFuerte", true)
	b.filas = {}
	-- Agregar un tramo.
	local agregar = CreateFrame("Frame", nil, b)
	agregar.botones = {}
	for _, rama in ipairs(M.RAMAS) do
		local d = M.RAMA[rama]
		agregar.botones[#agregar.botones + 1] = K.Boton(agregar, d.nombre, function() agregarTramo(rama) end,
			{ tipo = "acento", tam = "chico", icono = "ic-mas", ayuda = d.desc, ayudaTitulo = d.nombre })
	end
	agregar.Etiqueta = K.Texto(agregar, "pequeno", "textoTenue")
	K.Escribir(agregar.Etiqueta, L["Agregar un tramo:"])
	function agregar:Acomodar(ancho)
		self.Etiqueta:ClearAllPoints()
		self.Etiqueta:SetPoint("LEFT", self, "LEFT", 0, 0)
		local x, y = K.Ajustar(self.Etiqueta) + K.ESP.s, 0
		for _, bt in ipairs(self.botones) do
			local w = bt:AnchoNatural()
			if x + w > ancho then x, y = 0, y + K.ALTO.botonChico + K.ESP.xs end
			bt:ClearAllPoints()
			bt:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			x = x + w + K.ESP.xs
		end
		self.Etiqueta:ClearAllPoints()
		self.Etiqueta:SetPoint("LEFT", self, "TOPLEFT", 0, -K.ALTO.botonChico / 2)
		local h = y + K.ALTO.botonChico
		self:SetHeight(h)
		return h
	end
	b.Agregar_ = b:Agregar(agregar)
	-- El resumen y seguir.
	b.Estado = b:Agregar(K.Tarjeta(b, { variante = "estado" }), { espacio = K.ESP.base })
	-- Sin rutas: las plantillas.
	b.Vacio = b:Agregar(K.Vacio(b, { lobo = "dormido", titulo = L["Todavía no tienes rutas propias"],
		texto = L["Una ruta es tu árbol de tramos: misiones de XP, de oro, de clase, materiales u objetos. Empieza con una plantilla."] }))
	b.Plantillas = b:Agregar(K.Rejilla(b, { min = 240, gap = K.ESP.s, variante = "compacta" }))

	function b:Llenar()
		local r = ruta()
		local hay = r ~= nil
		K.Mostrar(self.Barra, hay)
		K.Mostrar(self.Arbol, hay and #r.tramos > 0)
		K.Mostrar(self.Agregar_, hay)
		K.Mostrar(self.Estado, hay)
		K.Mostrar(self.Vacio, not hay)
		local plantillas = {}
		for _, p in ipairs(M.PLANTILLAS) do
			plantillas[#plantillas + 1] = { variante = "compacta", icono = p.icono, titulo = p.nombre, texto = p.desc,
				alClic = function() M.DesdePlantilla(p.clave) rehacer() end, ayuda = p.desc }
		end
		self.Plantillas:Llenar(plantillas)
		K.Mostrar(self.Plantillas, not hay)
		self.Seccion:Set(L["Mis rutas"], { cuenta = #M.Rutas() > 0 and #M.Rutas() or nil })
		if not hay then return end
		self.Elegir:SetTexto(r.nombre)
		local plan = P.De(r)
		if not plan and not est.ocupado and #r.tramos > 0 and not est.motivo then planear() end
		self.Arbol:Vaciar()
		for k, t in ipairs(r.tramos) do
			local f = self.filas[k] or filaTramo(self.Arbol)
			self.filas[k] = f
			f:Set(r, t, k, #r.tramos, plan)
			f:Show()
			self.Arbol:Agregar(f)
		end
		for k = #r.tramos + 1, #self.filas do self.filas[k]:Hide() end
		-- La tarjeta de estado: qué hace la ruta y seguirla.
		local p = M.Personaje()
		local activa = p.activa == r.id and p.guias[r.id] ~= nil
		local firma = p.progreso[r.id] and p.progreso[r.id].firma
		local d = { icono = "ic-ruta" }
		if #r.tramos == 0 then
			d.titulo, d.tono = L["Tu ruta está vacía"], "neutro"
			d.texto = L["Agrega tramos arriba: Alfa elige las misiones por ti."]
		elseif est.ocupado then
			d.titulo, d.tono = L["Alfa está armando tu ruta..."], "acento"
			d.texto = L["Revisa miles de misiones para elegir las que sí puedes tomar: tarda unos segundos."]
			d.estado = { texto = L["Armando"], tono = "acento" }
		elseif plan then
			d.titulo, d.tono = format(L["%d misiones  \194\183  +%s XP"], plan.misiones or 0, M.Miles(plan.xp)), "exito"
			d.texto = format(L["De nivel %.1f a %.1f, con unos %s de oro. Solo misiones que ya puedes tomar; lo que pide más nivel va después de un paso que lo espera."],
				plan.desde or 1, plan.hasta or 1, N.Dinero(plan.oro or 0, true))
			d.estado = activa and { texto = L["En marcha"], tono = "exito" } or nil
			local texto = L["Seguir esta ruta"]
			if activa then texto = firma == M.Firma(r) and L["Continuar mi ruta"] or L["Actualizar mi guía"] end
			d.accion = { texto = texto, icono = "ic-seguir", alClic = function() M.Seguir(r) end }
		elseif est.motivo then
			d.titulo, d.tono = L["No pude armar la ruta"], "aviso"
			d.texto = I.TextoMotivo(est.motivo)
			d.accion = { texto = L["Probar otra vez"], icono = "ic-seguir", alClic = function() est.motivo = nil planear() rehacer() end }
		end
		self.Estado:Set(d)
	end
	local acomodar = b.Acomodar
	function b:Acomodar(ancho)
		local h = acomodar(self, ancho)
		-- El tronco pasa por detrás de las huellas de los tramos.
		if self.Arbol:IsShown() then
			self.Tronco:ClearAllPoints()
			self.Tronco:SetPoint("TOP", self.Arbol, "TOPLEFT", K.ESP.m + 16, -K.ESP.m - 16)
			self.Tronco:SetPoint("BOTTOM", self.Arbol, "BOTTOMLEFT", K.ESP.m + 16, K.ESP.m + 16)
			self.Tronco:Show()
		else
			self.Tronco:Hide()
		end
		return h
	end
	return b
end
