-- Alfa - Rutas: Mis planes en pantalla, la sección de la página Ruta y el
-- editor de un plan (toxic3000 / La Jauría). GPL-3.0.
--
-- La sección (página Ruta): tus planes en tarjetas (el que sigues marcado,
-- cuántas metas llevas y cuál sigue), "Nuevo plan" y las plantillas, cada una
-- con Empezar (la sigue ya) y Copiar y editar.
--
-- El editor (una ventana del Kit) tiene tres vistas:
--   plan   el nombre, las metas en orden (subir, bajar, editar, marcar,
--          quitar) y "Agregar una meta"; abajo, Seguir, Duplicar y Borrar
--   tipo   qué clase de meta agregas (las siete, en tarjetas)
--   meta   el formulario de esa meta: buscar el objeto o la misión, la
--          cantidad, el oro, la profesión y su nivel, el lugar (un servicio
--          cercano, un marcador de tu mapa, donde estás ahora o la entrada de
--          una mazmorra), el nivel o tu nota
-- Los planes y su avance viven en Planes.lua (M.Planes).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K
local Pl = M.Planes

local VP = {}
M.VistaPlanes = VP

local type, ipairs, pairs, tostring, tonumber, pcall = type, ipairs, pairs, tostring, tonumber, pcall
local floor, max, min, format = math.floor, math.max, math.min, string.format
local ESP = K.ESP

local RIDING = 762
local KINDS_OBJETO = { item = true, mount = true, pet = true, recipe = true, tabard = true }

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

---------------------------------------------------------------------------
-- Piezas chicas
---------------------------------------------------------------------------

-- Un campo de texto (o de número) del Kit: :Texto(), :SetTexto(t), :Acomodar(ancho).
local function campo(padre, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, padre)
	f:SetHeight(K.ALTO.control)
	f.caja = K.Caja(f, { fondo = "hundido", borde = "lineaFuerte", corte = K.CORTE.control })
	local e = CreateFrame("EditBox", nil, f)
	e:SetPoint("TOPLEFT", f, "TOPLEFT", 10, 0)
	e:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 0)
	e:SetAutoFocus(false)
	e:SetMaxLetters(opts.max or 60)
	if opts.numero then e:SetNumeric(true) end
	K.Fuente(e, "etiqueta")
	f.Ayuda = K.Texto(f, "nota", "textoTenue")
	f.Ayuda:SetPoint("LEFT", e, "LEFT", 1, 0)
	K.Escribir(f.Ayuda, opts.ayuda or "")
	e:SetScript("OnTextChanged", function(self)
		f.Ayuda:SetShown((self:GetText() or "") == "")
		if opts.alCambiar then K.Llamar(opts.alCambiar, f:Texto()) end
	end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		if opts.alEnter then K.Llamar(opts.alEnter, f:Texto()) end
	end)
	e:SetScript("OnEditFocusGained", function() f.caja:Estilo({ borde = "acento" }) end)
	e:SetScript("OnEditFocusLost", function()
		f.caja:Estilo({ borde = "lineaFuerte" })
		if opts.alSalir then K.Llamar(opts.alSalir, f:Texto()) end
	end)
	f:EnableMouse(true)
	f:SetScript("OnMouseDown", function() e:SetFocus() end)
	f.Campo = e
	function f:Texto()
		local t = self.Campo:GetText() or ""
		return (t:gsub("^%s+", ""):gsub("%s+$", ""))
	end
	function f:SetTexto(t) self.Campo:SetText(t ~= nil and tostring(t) or "") end
	function f:Acomodar(ancho)
		self:SetWidth(min(ancho, opts.ancho or ancho))
		return K.ALTO.control
	end
	return f
end

-- Una fila de formulario: la etiqueta arriba y el control debajo.
local function filaForm(padre, etiqueta, control, nota)
	local f = CreateFrame("Frame", nil, padre)
	f.Etiqueta = K.Texto(f, "etiqueta", "textoSuave")
	K.Escribir(f.Etiqueta, etiqueta or "")
	f.Control = control
	K.Adoptar(control, f)
	if nota then
		f.Nota = K.Texto(f, "pequeno", "textoTenue")
		K.Escribir(f.Nota, nota)
	end
	function f:SetNota(t)
		if not self.Nota then self.Nota = K.Texto(self, "pequeno", "textoTenue") end
		K.Escribir(self.Nota, t or "")
	end
	function f:Acomodar(ancho)
		self.Etiqueta:ClearAllPoints()
		self.Etiqueta:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		local y = (etiqueta and etiqueta ~= "") and 18 or 0
		self.Etiqueta:SetShown(y > 0)
		self.Control:ClearAllPoints()
		self.Control:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		local h = self.Control.Acomodar and self.Control:Acomodar(ancho) or K.num(self.Control:GetHeight(), K.ALTO.control)
		y = y + (tonumber(h) or K.ALTO.control)
		if self.Nota and (self.Nota:GetText() or "") ~= "" then
			self.Nota:ClearAllPoints()
			self.Nota:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(y + 4))
			y = y + 4 + K.Parrafo(self.Nota, ancho, 3)
			self.Nota:Show()
		elseif self.Nota then
			self.Nota:Hide()
		end
		self:SetSize(ancho, y)
		return y
	end
	return f
end

-- Un desplegable que se acomoda a lo ancho (hasta su tope).
local function desplegable(padre, opts)
	local d = K.Desplegable(padre, opts)
	local tope = opts.ancho or 320
	function d:Acomodar(ancho)
		self:SetWidth(min(ancho, tope))
		return K.ALTO.control
	end
	return d
end

-- Resultados de una búsqueda (objetos o misiones): hasta 8 filas para elegir.
local function resultados(padre, alElegir)
	local r = CreateFrame("Frame", nil, padre)
	r.filas, r.datos = {}, {}
	local function fila(i)
		local f = r.filas[i]
		if f then return f end
		f = CreateFrame("Button", nil, r)
		f:RegisterForClicks("LeftButtonUp")
		f.caja = K.Caja(f, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
		f.velo = K.Velo(f, K.CORTE.control, 0.05)
		f.Titulo = K.Texto(f, "cuerpo", "texto")
		f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -5)
		f.Titulo:SetPoint("RIGHT", f, "RIGHT", -12, 0)
		f.Sub = K.Texto(f, "pequeno", "textoTenue")
		f.Sub:SetPoint("TOPLEFT", f.Titulo, "BOTTOMLEFT", 0, -2)
		f.Sub:SetPoint("RIGHT", f, "RIGHT", -12, 0)
		f:SetScript("OnEnter", function(self) self.velo:Show() end)
		f:SetScript("OnLeave", function(self) self.velo:Hide() end)
		f:SetScript("OnClick", function(self) if self.alfaDato then K.Llamar(alElegir, self.alfaDato) end end)
		r.filas[i] = f
		return f
	end
	function r:Set(lista, elegido)
		self.datos = lista or {}
		for i, d in ipairs(self.datos) do
			local f = fila(i)
			f.alfaDato = d
			K.Escribir(f.Titulo, d.titulo or "?")
			K.Escribir(f.Sub, d.sub or "")
			local si = elegido ~= nil and d.id == elegido
			f.caja:Estilo({ borde = si and "acento" or "linea", alfaBorde = si and 0.8 or nil })
			K.ColorTexto(f.Titulo, si and "acento" or "texto")
		end
		for i = #self.datos + 1, #self.filas do self.filas[i]:Hide() end
	end
	function r:Acomodar(ancho)
		local y = 0
		for i = 1, #self.datos do
			local f = self.filas[i]
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			f:SetSize(ancho, 38)
			f:Show()
			y = y + 38 + ESP.xs
		end
		self:SetSize(ancho, max(1, y))
		return y
	end
	return r
end

-- Busca en el Codex (el buscador del motor). -> { { id, kind, titulo, sub } }, motivo
local function buscar(texto, kinds, cuantos)
	local S = M.Motor("Search")
	if not (S and type(S.Query) == "function") then return {}, L["El buscador no está disponible."] end
	if (texto or ""):len() < 2 then return {}, nil end
	local ok, lista = pcall(S.Query, texto, { kinds = kinds, limit = cuantos or 8, subtitles = true })
	if not ok or type(lista) ~= "table" then return {}, L["No pude buscar ahora: inténtalo al salir de combate."] end
	local out = {}
	for _, r in ipairs(lista) do
		if r.id and kinds[r.kind] then
			out[#out + 1] = { id = r.id, kind = r.kind, titulo = r.title or tostring(r.id), sub = type(r.subtitle) == "string" and r.subtitle or nil }
		end
	end
	return out, #out == 0 and L["Nada con ese nombre."] or nil
end

---------------------------------------------------------------------------
-- El editor
---------------------------------------------------------------------------

local v, raiz
local est = { plan = nil, vista = "plan", tipo = nil, meta = nil }
local ui = { formas = {}, filas = {} }

local function plan() return est.plan and Pl.De(est.plan) end

local acomodar, mostrar -- adelante

-- Las filas de las metas.
local function filaMeta(i)
	local f = ui.filas[i]
	if f then return f end
	f = CreateFrame("Button", nil, ui.lista)
	f:RegisterForClicks("LeftButtonUp")
	f.caja = K.Caja(f, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	f.velo = K.Velo(f, K.CORTE.control, 0.04)
	f.Franja = K.Plano(f, "acento", "ARTWORK", 2)
	f.Franja:SetWidth(2)
	f.Franja:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -6)
	f.Franja:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 6)
	f.Num = K.Texto(f, "numero", "textoTenue")
	f.Num:SetPoint("LEFT", f, "LEFT", 10, 0)
	f.Num:SetWidth(18)
	f.Num:SetJustifyH("RIGHT")
	f.Icono = K.Icono(f, "ic-huella", 16, "textoSuave")
	f.Icono:SetPoint("LEFT", f, "LEFT", 36, 0)
	f.Quitar = K.BotonIcono(f, "ic-cerrar", function(self) local m = self:GetParent().alfaMeta if m then Pl.QuitarMeta(est.plan, m.uid) end end,
		{ tam = 22, icono = 10, ayuda = L["Quitar esta meta"] })
	f.Quitar:SetPoint("RIGHT", f, "RIGHT", -8, 0)
	f.Editar = K.BotonIcono(f, "ic-ajustes", function(self) local m = self:GetParent().alfaMeta if m then VP.EditarMeta(m) end end,
		{ tam = 22, icono = 12, ayuda = L["Cambiar esta meta"] })
	f.Editar:SetPoint("RIGHT", f.Quitar, "LEFT", -2, 0)
	f.Hecha = K.BotonIcono(f, "ic-exito", function(self)
		local m, pl = self:GetParent().alfaMeta, plan()
		if m and pl then Pl.MarcarHecha(pl, m, not Pl.EstaHecha(pl, m)) end
	end, { tam = 22, icono = 12, ayuda = L["Marcar como hecha (o desmarcar)"] })
	f.Hecha:SetPoint("RIGHT", f.Editar, "LEFT", -2, 0)
	f.Bajar = K.BotonIcono(f, "chevron-down", function(self) local m = self:GetParent().alfaMeta if m then Pl.MoverMeta(est.plan, m.uid, 1) end end,
		{ tam = 22, icono = 12, ayuda = L["Bajar"] })
	f.Bajar:SetPoint("RIGHT", f.Hecha, "LEFT", -2, 0)
	f.Subir = K.BotonIcono(f, "chevron-up", function(self) local m = self:GetParent().alfaMeta if m then Pl.MoverMeta(est.plan, m.uid, -1) end end,
		{ tam = 22, icono = 12, ayuda = L["Subir"] })
	f.Subir:SetPoint("RIGHT", f.Bajar, "LEFT", -2, 0)
	f.Titulo = K.Texto(f, "cuerpo", "texto")
	f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 62, -8)
	f.Titulo:SetPoint("RIGHT", f.Subir, "LEFT", -8, 0)
	f.Sub = K.Texto(f, "pequeno", "textoTenue")
	f.Sub:SetPoint("TOPLEFT", f.Titulo, "BOTTOMLEFT", 0, -3)
	f.Sub:SetPoint("RIGHT", f.Subir, "LEFT", -8, 0)
	f:SetScript("OnEnter", function(self) self.velo:Show() end)
	f:SetScript("OnLeave", function(self) self.velo:Hide() end)
	f:SetScript("OnClick", function(self) if self.alfaMeta then VP.EditarMeta(self.alfaMeta) end end)
	ui.filas[i] = f
	return f
end

-- Un botón de ícono a la mano o atenuado (el Kit no les da :SetActivo).
local function activo(bt, si)
	if si then bt:Enable() else bt:Disable() end
	bt:SetAlpha(si and 1 or 0.3)
end

local function pintarLista(ancho)
	local pl = plan()
	local metas = pl and pl.metas or {}
	local actual = pl and select(1, Pl.Actual(pl, true))
	local y = 0
	for i, m in ipairs(metas) do
		local f = filaMeta(i)
		f.alfaMeta = m
		local hecha = Pl.EstaHecha(pl, m)
		local ahora = actual == m
		f.Num:SetText(tostring(i))
		K.SetIcono(f.Icono, hecha and "ic-exito" or (Pl.ICONO[m.tipo] or "ic-huella"), (hecha or ahora) and "acento" or "textoSuave")
		K.Escribir(f.Titulo, Pl.Titulo(m))
		K.ColorTexto(f.Titulo, hecha and "textoTenue" or "texto")
		local sub
		if hecha then sub = L["Hecha"] else
			local _, _, _, txt = Pl.Estado(m)
			sub = ahora and format(L["Ahora: %s"], txt or "") or (txt or "")
		end
		K.Escribir(f.Sub, sub)
		f.Franja:SetShown(ahora)
		f.caja:Estilo({ borde = ahora and "acento" or "linea", alfaBorde = ahora and 0.6 or nil })
		f.Hecha:SetMarcado(hecha)
		activo(f.Subir, i > 1)
		activo(f.Bajar, i < #metas)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", ui.lista, "TOPLEFT", 0, -y)
		f:SetSize(ancho, 48)
		f:Show()
		y = y + 48 + ESP.xs
	end
	for i = #metas + 1, #ui.filas do ui.filas[i]:Hide() end
	ui.lista:SetSize(ancho, max(1, y))
	return y
end

-- Las vistas del editor: cada una es una pila; se muestra una a la vez.
local function construirPlan(pila)
	local p = K.Pila(pila, { espacio = ESP.base })
	ui.nombre = campo(p, { ayuda = L["Nombre del plan"], max = 60, ancho = 420,
		alEnter = function(t) Pl.Renombrar(est.plan, t) end, alSalir = function(t) Pl.Renombrar(est.plan, t) end })
	p:Agregar(filaForm(p, L["Nombre"], ui.nombre))
	ui.resumen = CreateFrame("Frame", nil, p)
	ui.resumen.Texto = K.Texto(ui.resumen, "nota", "textoSuave")
	function ui.resumen:Acomodar(ancho)
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		local h = K.Parrafo(self.Texto, ancho, 3)
		self:SetSize(ancho, h)
		return h
	end
	p:Agregar(ui.resumen, { espacio = ESP.s })
	ui.lista = CreateFrame("Frame", nil, p)
	function ui.lista:Acomodar(ancho) return pintarLista(ancho) end
	p:Agregar(ui.lista, { espacio = ESP.m })
	ui.vacio = p:Agregar(K.Vacio(p, { lobo = "dormido", titulo = L["Tu plan no tiene metas todavía"],
		texto = L["Agrega la primera: un objeto, oro, una profesión, un lugar, una misión, un nivel o una nota."],
		accion = { texto = L["Agregar una meta"], icono = "ic-mas", alClic = function() mostrar("tipo") end } }))
	ui.agregar = K.Boton(p, L["Agregar una meta"], function() mostrar("tipo") end, { tipo = "acento", icono = "ic-mas" })
	local caja = CreateFrame("Frame", nil, p)
	K.Adoptar(ui.agregar, caja)
	function caja:Acomodar()
		ui.agregar:ClearAllPoints()
		ui.agregar:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self:SetSize(K.num(ui.agregar:GetWidth(), 160), K.ALTO.boton)
		return K.ALTO.boton
	end
	ui.agregarCaja = p:Agregar(caja, { espacio = ESP.m })
	return p
end

local DESC = {
	objeto = L["Búscalo por su nombre; se cumple cuando lo tienes en tus bolsas."],
	oro = L["Una cantidad de oro; se cumple cuando la llevas encima."],
	prof = L["Aprender una profesión o llegar a un nivel en ella."],
	lugar = L["Un servicio cercano, un marcador de tu mapa, donde estás ahora o la entrada de una mazmorra."],
	mision = L["Tomarla, completarla o entregarla."],
	nivel = L["Se cumple al llegar a ese nivel."],
	nota = L["Lo que quieras; la marcas tú cuando la hagas."],
}

local function construirTipo(pila)
	local p = K.Pila(pila, { espacio = ESP.base })
	local r = p:Agregar(K.Rejilla(p, { min = 200, gap = ESP.m }))
	local datos = {}
	for _, t in ipairs(Pl.TIPOS) do
		local tipo = t
		datos[#datos + 1] = { icono = Pl.ICONO[t], titulo = Pl.NOMBRE[t], texto = DESC[t], alClic = function() est.tipo, est.meta = tipo, nil mostrar("meta") end }
	end
	r:Llenar(datos)
	return p
end

---------------------------------------------------------------------------
-- Los formularios de cada tipo: :Cargar(meta | nil), :Leer() -> meta | nil, error
---------------------------------------------------------------------------

local function nota(p)
	local f = CreateFrame("Frame", nil, p)
	f.Texto = K.Texto(f, "nota", "textoSuave")
	function f:Set(t) K.Escribir(self.Texto, t or "") end
	function f:Acomodar(ancho)
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		local h = (self.Texto:GetText() or "") ~= "" and K.Parrafo(self.Texto, ancho, 4) or 0
		self:SetSize(ancho, max(1, h))
		return h
	end
	return f
end

local FORMAS = {}

-- Buscar y elegir (objetos o misiones).
local function formaBuscar(p, kinds, ayuda, etiqueta)
	local f = { elegido = nil }
	f.res = resultados(p, function(d)
		f.elegido = d
		f.res:Set(f.res.datos, d.id)
		f.estado:Set(format(L["Elegiste: %s"], d.titulo))
		acomodar()
	end)
	f.buscador = K.Buscador(p, { ayuda = ayuda, retraso = 0.35, alCambiar = function(t)
		local lista, motivo = buscar(t, kinds)
		f.res:Set(lista, f.elegido and f.elegido.id)
		f.estado:Set(motivo or (f.elegido and format(L["Elegiste: %s"], f.elegido.titulo)) or "")
		acomodar()
	end })
	function f.buscador:Acomodar(ancho) self:SetWidth(min(ancho, 420)) return K.ALTO.control end
	p:Agregar(filaForm(p, etiqueta, f.buscador))
	f.estado = p:Agregar(nota(p), { espacio = ESP.s })
	p:Agregar(f.res, { espacio = ESP.s })
	return f
end

FORMAS.objeto = function(p)
	local f = formaBuscar(p, KINDS_OBJETO, L["Nombre del objeto (en español o inglés)"], L["El objeto"])
	f.cantidad = campo(p, { numero = true, ayuda = "1", max = 4, ancho = 120 })
	p:Agregar(filaForm(p, L["Cuántos"], f.cantidad))
	function f:Cargar(m)
		self.buscador:SetTexto("", true)
		self.res:Set({})
		self.elegido = m and { id = m.item, kind = m.kind, titulo = Pl.NombreObjeto(m) } or nil
		self.estado:Set(self.elegido and format(L["Elegiste: %s"], self.elegido.titulo) or L["Escribe al menos dos letras."])
		self.cantidad:SetTexto(m and m.cantidad or 1)
	end
	function f:Leer()
		if not self.elegido then return nil, L["Busca y elige un objeto."] end
		return { tipo = "objeto", item = self.elegido.id, kind = self.elegido.kind, nombre = self.elegido.titulo, cantidad = tonumber(self.cantidad:Texto()) or 1 }
	end
	return f
end

FORMAS.mision = function(p)
	local f = formaBuscar(p, { quest = true }, L["Nombre de la misión"], L["La misión"])
	f.verbo = K.Segmentos(p, { estilo = "segmentos", valor = "turnin", opciones = {
		{ valor = "accept", texto = L["Tomarla"] }, { valor = "complete", texto = L["Completarla"] }, { valor = "turnin", texto = L["Entregarla"] } } })
	p:Agregar(filaForm(p, L["Qué hacer con ella"], f.verbo))
	function f:Cargar(m)
		self.buscador:SetTexto("", true)
		self.res:Set({})
		self.elegido = m and { id = m.quest, titulo = m.titulo or M.TituloMision(m.quest) } or nil
		self.estado:Set(self.elegido and format(L["Elegiste: %s"], self.elegido.titulo) or L["Escribe al menos dos letras."])
		self.verbo:SetValor(m and m.verbo or "turnin")
	end
	function f:Leer()
		if not self.elegido then return nil, L["Busca y elige una misión."] end
		return { tipo = "mision", quest = self.elegido.id, titulo = self.elegido.titulo, verbo = self.verbo:Valor() }
	end
	return f
end

FORMAS.oro = function(p)
	local f = {}
	f.oro = campo(p, { numero = true, ayuda = "10", max = 6, ancho = 160 })
	f.fila = p:Agregar(filaForm(p, L["Cuánto oro"], f.oro, " "))
	function f:Cargar(m)
		self.oro:SetTexto(m and floor(m.cobre / 10000) or "")
		self.fila:SetNota(format(L["Llevas %s ahora. Solo oro entero (10 = 10 de oro)."], N.Dinero(GetMoney and GetMoney() or 0, true)))
	end
	function f:Leer()
		local o = tonumber(self.oro:Texto())
		if not o or o < 1 then return nil, L["Escribe cuánto oro (1 o más)."] end
		return { tipo = "oro", cobre = o * 10000 }
	end
	return f
end

local function opcionesOficio()
	local C = M.Motor("Compat")
	local out = {}
	for _, linea in pairs(C and type(C.SKILL_LINES) == "table" and C.SKILL_LINES or {}) do
		if type(linea) == "number" then out[#out + 1] = { valor = linea, texto = Pl.NombreOficio(linea) } end
	end
	table.sort(out, function(a, b) return a.texto < b.texto end)
	return out
end

FORMAS.prof = function(p)
	local f = {}
	f.linea = desplegable(p, { opciones = {}, ancho = 260 })
	p:Agregar(filaForm(p, L["La profesión"], f.linea))
	f.nivel = campo(p, { numero = true, ayuda = "75", max = 3, ancho = 120 })
	p:Agregar(filaForm(p, L["Hasta qué nivel"], f.nivel, L["1 = solo aprenderla. Los rangos: 75, 150, 225 y 300."]))
	function f:Cargar(m)
		local ops = opcionesOficio()
		self.linea:SetOpciones(ops)
		self.linea:SetValor(m and m.linea or (ops[1] and ops[1].valor))
		self.nivel:SetTexto(m and m.nivel or 75)
	end
	function f:Leer()
		local linea = self.linea:Valor()
		if not linea then return nil, L["Elige una profesión."] end
		return { tipo = "prof", linea = linea, nivel = tonumber(self.nivel:Texto()) or 1 }
	end
	return f
end

FORMAS.nivel = function(p)
	local f = {}
	f.nivel = campo(p, { numero = true, ayuda = "20", max = 2, ancho = 120 })
	f.fila = p:Agregar(filaForm(p, L["Qué nivel"], f.nivel, " "))
	function f:Cargar(m)
		local lv = M.num(UnitLevel and UnitLevel("player"), 1)
		self.nivel:SetTexto(m and m.nivel or (lv + 1))
		self.fila:SetNota(format(L["Eres nivel %d."], lv))
	end
	function f:Leer()
		local n = tonumber(self.nivel:Texto())
		if not n or n < 2 then return nil, L["Escribe un nivel (2 o más)."] end
		return { tipo = "nivel", nivel = n }
	end
	return f
end

FORMAS.nota = function(p)
	local f = {}
	f.texto = campo(p, { ayuda = L["Ej.: Comprar bolsas de 10 casillas"], max = 200 })
	p:Agregar(filaForm(p, L["Tu nota"], f.texto, L["Una meta que marcas tú (el botón de hecha del rastreador o de esta lista)."]))
	function f:Cargar(m) self.texto:SetTexto(m and m.texto or "") end
	function f:Leer()
		local t = self.texto:Texto()
		if t == "" then return nil, L["Escribe tu nota."] end
		return { tipo = "nota", texto = t }
	end
	return f
end

-- Los servicios para elegir: los de Buscar cerca y un entrenador por profesión.
local function opcionesServicio()
	local out = {}
	local Ce = M.Cerca
	if not Ce then return out end
	for _, t in ipairs(Ce.Tipos()) do
		if t.tipo == "vendor" then
			out[#out + 1] = { valor = "vendor", texto = Ce.Nombre("vendor") }
			out[#out + 1] = { valor = "food", texto = Ce.Nombre("food") }
		elseif t.tipo ~= "trainer" then
			out[#out + 1] = { valor = t.tipo, texto = t.nombre }
		end
	end
	for _, o in ipairs(opcionesOficio()) do
		if o.valor ~= RIDING then out[#out + 1] = { valor = "trainer:" .. o.valor, texto = Ce.Nombre("trainer", o.valor) } end
	end
	return out
end

local function marcadores()
	local out = {}
	local Mu = AlfaMundo
	local lista = Mu and llamar(Mu.Marcadores)
	for _, mk in ipairs(type(lista) == "table" and lista or {}) do
		if type(mk) == "table" and mk.id and mk.mapa and mk.x and mk.y then
			local z = M.Zona(mk.mapa)
			out[#out + 1] = { valor = mk.id, texto = (mk.nombre or L["Marcador"]) .. (z and ("  \194\183  " .. z) or ""), dato = mk }
		end
	end
	return out
end

local function mazmorras()
	local out = {}
	local D = M.Motor("Dungeons")
	for _, d in ipairs(D and llamar(D.List) or {}) do
		local e = d.entrance
		if e and e.map and e.x and e.y then
			local lv = d.minLevel and format("  \194\183  %d+", d.minLevel) or ""
			out[#out + 1] = { valor = d.key, texto = (d.name or d.key) .. lv, dato = d }
		end
	end
	return out
end

local function aqui()
	local C = M.Motor("Compat")
	local mapa, x, y = llamar(C and C.GetPlayerMapPosition)
	if mapa and type(x) == "number" and type(y) == "number" then return mapa, x, y end
	return nil
end

FORMAS.lugar = function(p)
	local f = {}
	f.modo = K.Segmentos(p, { estilo = "segmentos", valor = "servicio", opciones = {
		{ valor = "servicio", texto = L["Servicio"] }, { valor = "marcador", texto = L["Marcador"] },
		{ valor = "aqui", texto = L["Aquí"] }, { valor = "mazmorra", texto = L["Mazmorra"] } },
		alCambiar = function() f:Pintar() acomodar() end })
	p:Agregar(filaForm(p, L["Qué lugar"], f.modo))
	f.servicio = desplegable(p, { opciones = {}, ancho = 300 })
	f.filaServicio = p:Agregar(filaForm(p, L["El servicio"], f.servicio, L["El más cercano cuando le toque, por tiempo de camino."]))
	f.marcador = desplegable(p, { opciones = {}, ancho = 360 })
	f.filaMarcador = p:Agregar(filaForm(p, L["Tu marcador"], f.marcador))
	f.mazmorra = desplegable(p, { opciones = {}, ancho = 360 })
	f.filaMazmorra = p:Agregar(filaForm(p, L["La mazmorra"], f.mazmorra, L["La flecha te lleva a su entrada."]))
	f.aqui = p:Agregar(nota(p))
	f.nombre = campo(p, { ayuda = L["Opcional: cómo la llamas"], max = 50, ancho = 360 })
	p:Agregar(filaForm(p, L["Nombre"], f.nombre))
	function f:Pintar()
		local modo = self.modo:Valor()
		K.Mostrar(self.filaServicio, modo == "servicio")
		K.Mostrar(self.filaMarcador, modo == "marcador")
		K.Mostrar(self.filaMazmorra, modo == "mazmorra")
		K.Mostrar(self.aqui, modo == "aqui" or (modo == "marcador" and #self.marcador.opciones == 0)
			or (modo == "mazmorra" and #self.mazmorra.opciones == 0) or (modo == "servicio" and #self.servicio.opciones == 0))
		if modo == "aqui" then
			local mapa, x, y = aqui()
			self.aqui:Set(mapa and format(L["Aquí: %s %.1f, %.1f. Se guarda este punto."], M.Zona(mapa) or "?", x, y) or L["El juego no da tu posición aquí (en una instancia, por ejemplo)."])
		elseif modo == "marcador" and #self.marcador.opciones == 0 then
			self.aqui:Set(L["No tienes marcadores en el mapa de Alfa. Pon uno en el mapa y vuelve aquí."])
		elseif modo == "mazmorra" and #self.mazmorra.opciones == 0 then
			self.aqui:Set(L["Los datos de las mazmorras no están cargados."])
		elseif modo == "servicio" and #self.servicio.opciones == 0 then
			self.aqui:Set(L["Buscar cerca no está disponible."])
		end
		K.Mostrar(self.filaMarcador, modo == "marcador" and #self.marcador.opciones > 0)
		K.Mostrar(self.filaMazmorra, modo == "mazmorra" and #self.mazmorra.opciones > 0)
		K.Mostrar(self.filaServicio, modo == "servicio" and #self.servicio.opciones > 0)
	end
	function f:Cargar(m)
		self.servicio:SetOpciones(opcionesServicio())
		self.marcador:SetOpciones(marcadores())
		self.mazmorra:SetOpciones(mazmorras())
		local modo = "servicio"
		if m then
			if m.modo == "servicio" then
				self.servicio:SetValor(m.linea and ("trainer:" .. m.linea) or m.servicio)
			elseif m.modo == "marcador" then
				modo = "marcador"
				self.marcador:SetValor(m.marcador)
			elseif m.mazmorra then
				modo = "mazmorra"
				self.mazmorra:SetValor(m.mazmorra)
			else
				modo = "aqui"
			end
		else
			local o = self.servicio.opciones[1]
			self.servicio:SetValor(o and o.valor)
			local mk = self.marcador.opciones[1]
			self.marcador:SetValor(mk and mk.valor)
			local dz = self.mazmorra.opciones[1]
			self.mazmorra:SetValor(dz and dz.valor)
		end
		self.punto = m and m.modo == "punto" and not m.mazmorra and m or nil
		self.modo:SetValor(modo)
		self.nombre:SetTexto(m and m.nombre or "")
		self:Pintar()
	end
	local function dato(d, valor)
		for _, o in ipairs(d.opciones or {}) do if o.valor == valor then return o end end
		return nil
	end
	function f:Leer()
		local modo = self.modo:Valor()
		local nombre = self.nombre:Texto()
		nombre = nombre ~= "" and nombre or nil
		if modo == "servicio" then
			local v0 = self.servicio:Valor()
			if not v0 then return nil, L["Elige un servicio."] end
			local linea = type(v0) == "string" and tonumber(v0:match("^trainer:(%d+)$"))
			return { tipo = "lugar", modo = "servicio", servicio = linea and "trainer" or v0, linea = linea, nombre = nombre }
		elseif modo == "marcador" then
			local o = dato(self.marcador, self.marcador:Valor())
			if not o then return nil, L["Elige un marcador."] end
			local mk = o.dato
			return { tipo = "lugar", modo = "marcador", marcador = mk.id, mapa = mk.mapa, x = mk.x, y = mk.y, nombre = nombre or mk.nombre }
		elseif modo == "mazmorra" then
			local o = dato(self.mazmorra, self.mazmorra:Valor())
			if not o then return nil, L["Elige una mazmorra."] end
			local d, e = o.dato, o.dato.entrance
			return { tipo = "lugar", modo = "punto", mapa = e.map, x = e.x, y = e.y, f = e.f, mazmorra = d.key,
				nombre = nombre or format(L["La entrada de %s"], d.name or d.key) }
		end
		local mapa, x, y = aqui()
		if not mapa and self.punto then
			return { tipo = "lugar", modo = "punto", mapa = self.punto.mapa, x = self.punto.x, y = self.punto.y, f = self.punto.f, nombre = nombre or self.punto.nombre }
		end
		if not mapa then return nil, L["El juego no da tu posición aquí (en una instancia, por ejemplo)."] end
		return { tipo = "lugar", modo = "punto", mapa = mapa, x = x, y = y, nombre = nombre or M.Zona(mapa) }
	end
	return f
end

local function construirMeta(pila)
	local p = K.Pila(pila, { espacio = ESP.base })
	ui.metaTitulo = CreateFrame("Frame", nil, p)
	ui.metaTitulo.Texto = K.Texto(ui.metaTitulo, "nota", "textoSuave")
	function ui.metaTitulo:Acomodar(ancho)
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		local h = K.Parrafo(self.Texto, ancho, 3)
		self:SetSize(ancho, h)
		return h
	end
	p:Agregar(ui.metaTitulo)
	ui.metaError = p:Agregar(nota(p), { espacio = ESP.s })
	ui.metaError.Texto.alfaColor = "aviso"
	K.ColorTexto(ui.metaError.Texto, "aviso")
	-- Un formulario por tipo, cada uno en su pila (se hacen la primera vez).
	ui.metaPila = p:Agregar(K.Pila(p, { espacio = ESP.base }), { espacio = ESP.m })
	return p
end

local function forma(tipo)
	local f = ui.formas[tipo]
	if f then return f end
	local p = K.Pila(ui.metaPila, { espacio = ESP.base })
	f = FORMAS[tipo](p)
	f.pila = p
	ui.metaPila:Agregar(p)
	ui.formas[tipo] = f
	return f
end

local function guardarMeta()
	local f = est.tipo and forma(est.tipo)
	if not f then return end
	local m, err = f:Leer()
	if not m then
		ui.metaError:Set(err or L["Falta algo."])
		acomodar()
		return
	end
	local ok
	if est.meta then ok = Pl.CambiarMeta(est.plan, est.meta.uid, m) else ok = Pl.AgregarMeta(est.plan, m) end
	if not ok then
		ui.metaError:Set(L["No pude guardar esa meta: revisa lo que escribiste."])
		acomodar()
		return
	end
	mostrar("plan")
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------

local function pie()
	local pl = plan()
	-- SetPie no esconde los botones de la vista anterior.
	for _, bt in ipairs({ ui.cerrar, ui.seguir, ui.borrar, ui.duplicar, ui.reiniciar, ui.atras, ui.guardar }) do bt:Hide() end
	local function ver(lista) for _, bt in ipairs(lista) do bt:Show() end return lista end
	if est.vista == "plan" then
		local activo = Pl.Activo()
		local sigo = pl and activo and activo.id == pl.id
		ui.seguir:SetTexto(sigo and L["Dejar de seguirlo"] or L["Seguir este plan"])
		ui.seguir:SetTipo(sigo and "secundario" or "primario")
		ui.seguir:SetActivo(pl ~= nil and #pl.metas > 0)
		v:SetPie(ver({ ui.cerrar, ui.seguir }), ver({ ui.borrar, ui.duplicar, ui.reiniciar }))
	elseif est.vista == "tipo" then
		v:SetPie(ver({ ui.atras }), {})
	else
		v:SetPie(ver({ ui.atras, ui.guardar }), {})
	end
end

function acomodar()
	if not (v and v:IsShown()) then return end
	local ancho = v:AnchoCuerpo()
	raiz:ClearAllPoints()
	raiz:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -ESP.base)
	local h = raiz:Acomodar(ancho)
	v:SetAltoContenido(h + 2 * ESP.base)
end

local function pintar()
	local pl = plan()
	if not pl then
		if v then v:Cerrar() end
		return
	end
	if est.vista == "plan" then
		local n, total = Pl.Avance(pl)
		local activo = Pl.Activo()
		v:SetTitulo(pl.nombre, total > 0 and format(L["%d de %d metas"], n, total) or L["Sin metas todavía"], "ic-lista")
		if not ui.nombre.Campo:HasFocus() then ui.nombre:SetTexto(pl.nombre) end
		local partes = {}
		if activo and activo.id == pl.id then
			partes[#partes + 1] = L["Lo sigues: el rastreador te muestra la meta de ahora y la flecha va a cada lugar."]
		else
			partes[#partes + 1] = L["Las metas se cumplen solas al hacerlas; las notas las marcas tú. Ordénalas como quieras."]
		end
		K.Escribir(ui.resumen.Texto, table.concat(partes, " "))
		K.Mostrar(ui.lista, #pl.metas > 0)
		K.Mostrar(ui.resumen, #pl.metas > 0)
		K.Mostrar(ui.vacio, #pl.metas == 0)
		K.Mostrar(ui.agregarCaja, #pl.metas > 0)
	elseif est.vista == "tipo" then
		v:SetTitulo(L["Agregar una meta"], pl.nombre, "ic-mas")
	else
		v:SetTitulo(est.meta and L["Cambiar la meta"] or Pl.NOMBRE[est.tipo], pl.nombre, Pl.ICONO[est.tipo])
		K.Escribir(ui.metaTitulo.Texto, DESC[est.tipo] or "")
		for t, f in pairs(ui.formas) do K.Mostrar(f.pila, t == est.tipo) end
	end
	K.Mostrar(ui.vistaPlan, est.vista == "plan")
	K.Mostrar(ui.vistaTipo, est.vista == "tipo")
	K.Mostrar(ui.vistaMeta, est.vista == "meta")
	pie()
	acomodar()
end

function mostrar(vista)
	est.vista = vista
	if vista == "meta" then
		local f = forma(est.tipo)
		ui.metaError:Set("")
		f:Cargar(est.meta)
	end
	pintar()
	if v.Desplazable and v.Desplazable.IrArriba then v.Desplazable:IrArriba() end
end

function VP.EditarMeta(m)
	est.tipo, est.meta = m.tipo, m
	mostrar("meta")
end

local function construir()
	v = K.Ventana({ nombre = "AlfaPlanEditor", titulo = L["Mi plan"], icono = "ic-lista", ancho = 720, alto = 600, desplazar = true })
	raiz = K.Pila(v.Cuerpo, { espacio = 0 })
	ui.vistaPlan = raiz:Agregar(construirPlan(raiz))
	ui.vistaTipo = raiz:Agregar(construirTipo(raiz))
	ui.vistaMeta = raiz:Agregar(construirMeta(raiz))
	ui.cerrar = K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "fantasma" })
	ui.seguir = K.Boton(v, L["Seguir este plan"], function()
		local pl, activo = plan(), Pl.Activo()
		if not pl then return end
		if activo and activo.id == pl.id then Pl.Dejar() else Pl.Seguir(pl.id) end
	end, { tipo = "primario", icono = "ic-seguir" })
	ui.borrar = K.Boton(v, L["Borrar"], function()
		local pl = plan()
		if not pl then return end
		K.Dialogo({ titulo = L["¿Borrar este plan?"], texto = format(L["%s se borra de todos tus personajes. No se puede deshacer."], pl.nombre),
			aceptar = L["Borrar"], peligro = true, alAceptar = function() Pl.Borrar(pl.id) v:Cerrar() end })
	end, { tipo = "peligro", tam = "chico" })
	ui.duplicar = K.Boton(v, L["Duplicar"], function()
		local c = Pl.Duplicar(est.plan)
		if c then VP.Abrir(c.id) end
	end, { tipo = "fantasma", tam = "chico" })
	ui.reiniciar = K.Boton(v, L["Empezar de nuevo"], function()
		local pl = plan()
		if pl then Pl.Reiniciar(pl) end
	end, { tipo = "fantasma", tam = "chico", ayuda = L["Desmarca las metas hechas de este personaje (las que ya se cumplen se vuelven a marcar solas)."] })
	ui.atras = K.Boton(v, L["Atrás"], function() mostrar(est.vista == "meta" and not est.meta and "tipo" or "plan") end, { tipo = "fantasma" })
	ui.guardar = K.Boton(v, L["Guardar"], guardarMeta, { tipo = "primario", icono = "ic-exito" })
	v.alAcomodar = function() acomodar() end
	M.Escuchar("PLANES", function() if v:IsShown() and est.vista == "plan" then pintar() end end)
	M.Escuchar("PLAN_AVANCE", function() if v:IsShown() and est.vista == "plan" then pintar() end end)
end

-- Abre el editor de un plan (sin id: uno nuevo).
function VP.Abrir(id)
	if not v then construir() end
	local pl = Pl.De(id) or Pl.Nuevo(L["Mi plan"])
	est.plan, est.tipo, est.meta = pl.id, nil, nil
	v:Abrir()
	mostrar("plan")
end

function VP.Nuevo(nombre)
	local pl = Pl.Nuevo(nombre or L["Mi plan"])
	VP.Abrir(pl.id)
	mostrar("tipo")
	return pl
end

---------------------------------------------------------------------------
-- La sección de la página Ruta
---------------------------------------------------------------------------

local function tarjetaPlan(pl, activo)
	local n, total = Pl.Avance(pl)
	local m = Pl.Actual(pl, true)
	local sigo = activo and activo.id == pl.id
	local texto
	if total == 0 then
		texto = L["Sin metas todavía: ábrelo y agrégale una."]
	elseif not m then
		texto = L["Terminado: cumpliste todas sus metas."]
	else
		texto = format(L["Sigue: %s"], Pl.Titulo(m))
	end
	local id = pl.id
	return {
		icono = "ic-lista", tono = sigo and "acento" or "neutro", titulo = pl.nombre, texto = texto,
		estado = sigo and { texto = L["Lo sigues"], tono = "exito" } or nil, elegida = sigo,
		progreso = total > 0 and { actual = n, total = total, texto = format(L["%d de %d metas"], n, total), huellas = total <= 12 } or nil,
		alClic = function() VP.Abrir(id) end,
		accion = (not sigo and total > 0 and m) and { texto = L["Seguir"], icono = "ic-seguir", alClic = function() Pl.Seguir(id) end } or nil,
		secundaria = { texto = L["Editar"], alClic = function() VP.Abrir(id) end },
	}
end

local function tarjetaPlantilla(p)
	local clave = p.clave
	return {
		icono = p.icono, tono = "neutro", titulo = p.nombre, texto = p.texto,
		insignias = { { #p.metas == 1 and L["1 meta"] or format(L["%d metas"], #p.metas), "neutro" } },
		accion = { texto = L["Empezar"], icono = "ic-seguir", alClic = function()
			local pl = Pl.DesdePlantilla(clave)
			if pl then Pl.Seguir(pl.id) end
		end },
		secundaria = { texto = L["Copiar y editar"], alClic = function()
			local pl = Pl.DesdePlantilla(clave)
			if pl then VP.Abrir(pl.id) end
		end },
	}
end

function M.BloquePlanes(padre, alCambiar)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Mis planes"]))
	b.Nota = b:Agregar(nota(b), { espacio = ESP.s })
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 280, gap = ESP.m }), { espacio = ESP.s })
	b.Primero = b:Agregar(K.Tarjeta(b, { variante = "estado" }), { espacio = ESP.s })
	b.SecPlantillas = b:Agregar(K.Seccion(b, L["Plantillas"]), { espacio = ESP.l })
	b.Plantillas = b:Agregar(K.Rejilla(b, { min = 280, gap = ESP.m }), { espacio = ESP.s })
	function b:Llenar()
		local lista = Pl.Lista()
		local activo = Pl.Activo()
		self.Seccion:Set(L["Mis planes"], { cuenta = #lista > 0 and #lista or nil,
			enlace = { texto = L["Nuevo plan"], alClic = function() VP.Nuevo() end } })
		self.Nota:Set(L["Tu propia lista de metas, en el orden que quieras: un objeto, oro, una profesión, un lugar, una misión, un nivel o una nota. Alfa las mide solas y te lleva a cada una."])
		local datos = {}
		for _, pl in ipairs(lista) do datos[#datos + 1] = tarjetaPlan(pl, activo) end
		self.Rejilla:Llenar(datos)
		K.Mostrar(self.Rejilla, #datos > 0)
		if #datos == 0 then
			self.Primero:Set({ lobo = "atento", tono = "acento", titulo = L["Arma tu primer plan"],
				texto = L["Por ejemplo: primero un objeto, luego 10 de oro, luego subir cocina y al final el banco."],
				accion = { texto = L["Nuevo plan"], icono = "ic-mas", alClic = function() VP.Nuevo() end } })
		end
		K.Mostrar(self.Primero, #datos == 0)
		local pls = Pl.Plantillas()
		local pd = {}
		for _, p in ipairs(pls) do pd[#pd + 1] = tarjetaPlantilla(p) end
		self.Plantillas:Llenar(pd)
		K.Mostrar(self.SecPlantillas, #pd > 0)
		K.Mostrar(self.Plantillas, #pd > 0)
	end
	M.Escuchar("PLANES", function() K.Llamar(alCambiar) end)
	return b
end
