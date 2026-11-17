-- Alfa - Pesca: el diario de pesca (toxic3000 / La Jauría). GPL-3.0.
--
-- La pestaña Diario: el catálogo de lo que se pesca en Forever (Datos.lua)
-- más todo lo que tú hayas sacado, con un buscador y filtros. A la derecha,
-- la ficha de lo elegido: su maestría (seis niveles: 10, 50, 100, 250, 500 y
-- 1000), tus números, dónde sale (tus aguas y los bancos de peces), sus
-- recetas, lo que vale y qué hacer: ponerte una meta, Guíame, agregarlo a
-- Mis planes o verlo en la Enciclopedia.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local V = M.V
local Eq = M.Eq

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring
local ESP = K.ESP
local DOT = " \194\183 "

local FILTROS = {
	todo = function() return true end,
	mios = function(d) return d.n > 0 end,
	pez = function(d) return d.clase == "pez" end,
	especial = function(d) return d.clase == "trofeo" or d.clase == "concurso" or d.clase == "mision" end,
	otros = function(d) return d.clase == "sorpresa" or d.clase == "botin" or d.clase == "otro" end,
}

local ORDEN_CLASE = { pez = 1, trofeo = 2, concurso = 3, mision = 4, sorpresa = 5, botin = 6, otro = 7 }

local function minus(s) return (tostring(s or ""):lower()) end

-- Todas las entradas: el catálogo y lo que pescaste.
local function entradas()
	local diario = M.Diario()
	local lista, vistos = {}, {}
	local function agregar(id, clase)
		if id == nil or vistos[id] then return end
		vistos[id] = true
		local e = diario[id]
		local n = type(e) == "table" and tonumber(e.n) or 0
		local d = { id = id, clase = clase or M.CLASE[id] or "otro", n = n, e = type(e) == "table" and e or nil }
		if type(id) == "number" then
			d.nombre = V.NombreObjeto(id)
			d.calidad = (d.e and d.e.calidad) or Eq.Calidad(id)
		else
			d.nombre = (d.e and d.e.nombre) or tostring(id)
			d.calidad = d.e and d.e.calidad
		end
		lista[#lista + 1] = d
	end
	for _, c in ipairs(M.CATALOGO) do agregar(c.id, c.clase) end
	for id in pairs(diario) do agregar(id) end
	return lista
end

local function filtrar(lista, filtro, texto)
	local f = FILTROS[filtro] or FILTROS.todo
	local t = minus(texto)
	local out = {}
	for _, d in ipairs(lista) do
		if f(d) and (t == "" or minus(d.nombre):find(t, 1, true)) then out[#out + 1] = d end
	end
	table.sort(out, function(a, b)
		if (a.n > 0) ~= (b.n > 0) then return a.n > 0 end
		if a.n ~= b.n then return a.n > b.n end
		local ca, cb = ORDEN_CLASE[a.clase] or 9, ORDEN_CLASE[b.clase] or 9
		if ca ~= cb then return ca < cb end
		return minus(a.nombre) < minus(b.nombre)
	end)
	return out
end

---------------------------------------------------------------------------
-- La ficha
---------------------------------------------------------------------------
local function cabecera(padre)
	local c = CreateFrame("Frame", nil, padre)
	c.Icono = K.IconoObjeto(c, 44)
	c.Icono:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	c.Titulo = K.Texto(c, "subtitulo", "texto")
	c.Clase = K.Insignia(c, "", "acento")
	c.Sub = K.Texto(c, "pequeno", "textoTenue")
	function c:Set(d)
		self.Icono:SetObjeto({ id = type(d.id) == "number" and d.id or nil, icono = d.e and d.e.icono, calidad = d.calidad })
		K.Escribir(self.Titulo, d.nombre or "?")
		V.ColorCalidad(self.Titulo, d.calidad)
		self.Clase:Set(M.NOMBRE_CLASE[d.clase] or M.NOMBRE_CLASE.otro, M.TONO_CLASE[d.clase] or "neutro")
		local nivel, nombre = M.Maestria(d.n)
		K.Escribir(self.Sub, d.n > 0 and format(L["%d pescados"], d.n) .. (nivel > 0 and (DOT .. nombre) or "") or L["Todavía no lo pescas"])
	end
	function c:Acomodar(ancho)
		local x = 44 + ESP.m
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -1)
		self.Titulo:SetWidth(max(60, ancho - x))
		self.Titulo:SetWordWrap(true)
		local h = K.AltoTexto(self.Titulo)
		self.Clase:ClearAllPoints()
		self.Clase:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(h + 5))
		self.Sub:ClearAllPoints()
		self.Sub:SetPoint("LEFT", self.Clase, "RIGHT", ESP.s, 0)
		K.Ajustar(self.Sub, max(40, ancho - x - K.num(self.Clase:GetWidth(), 0) - ESP.s))
		local alto = max(44, h + 5 + K.ALTO.insignia)
		self:SetSize(ancho, alto)
		return alto
	end
	return c
end

local function maestria(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Huellas = K.Huellas(b, { tam = 16, max = 6, gap = 6 })
	b.Huellas:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.Texto = K.Texto(b, "nota", "textoSuave")
	function b:Set(n)
		local nivel, nombre, sig, anterior = M.Maestria(n)
		self.Huellas:Set(nivel, #M.MAESTRIA)
		local t
		if nivel == 0 then
			t = format(L["Saca %d para la primera maestría (%s)."], M.MAESTRIA[1].n, M.MAESTRIA[1].nombre)
		elseif sig then
			t = format(L["%s. Llevas %d de %d para %s."], nombre, n, sig, M.MAESTRIA[nivel + 1].nombre)
		else
			t = format(L["%s: la maestría más alta. ¡Ya es tuyo!"], nombre)
		end
		K.Escribir(self.Texto, t)
	end
	function b:Acomodar(ancho)
		local _, hh = self.Huellas:Acomodar()
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(hh + 4))
		local h = hh + 4 + K.Parrafo(self.Texto, ancho)
		self:SetSize(ancho, h)
		return h
	end
	return b
end

local function acciones(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.botones = {}
	function b:Set(lista)
		for i, d in ipairs(lista) do
			local bt = self.botones[i] or K.Boton(self, "", nil, { tipo = i == 1 and "acento" or "secundario", tam = "chico" })
			self.botones[i] = bt
			bt:SetTexto(d.texto)
			bt.alClic = d.alClic
			bt:SetActivo(d.activo ~= false)
			bt:Show()
		end
		for i = #lista + 1, #self.botones do self.botones[i]:Hide() end
		self.n = #lista
	end
	function b:Acomodar(ancho)
		local x, y = 0, 0
		for i = 1, self.n or 0 do
			local bt = self.botones[i]
			local w = bt:AnchoNatural()
			if x > 0 and x + w > ancho then x, y = 0, y + K.ALTO.botonChico + ESP.s end
			bt:ClearAllPoints()
			bt:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			x = x + w + ESP.s
		end
		local h = (self.n or 0) > 0 and (y + K.ALTO.botonChico) or 1
		self:SetSize(ancho, h)
		return h
	end
	return b
end

-- Una meta de pescar más de esto: el menú con cuántos.
local function menuMeta(dueno, d)
	local opciones = {}
	for _, n in ipairs({ 5, 10, 15, 20, 50, 100 }) do
		opciones[#opciones + 1] = { valor = n, texto = format(L["Pescar %d más"], n) }
	end
	K.Menu(dueno, opciones, nil, function(n)
		M.AgregarMeta({ tipo = "pez", item = d.id, nombre = d.nombre, objetivo = n })
		if M.Metas then M.Metas.Alternar(true) end
	end, 180)
end

local function textoNumeros(d)
	local e = d.e
	if not e or d.n <= 0 then return L["Todavía no lo sacas del agua. Cuando lo hagas, aquí verás cuántos llevas, cuándo y dónde."] end
	local lineas = { format(L["Pescaste %d."], d.n) }
	if e.primera then
		local con = e.hab and format(L[", con %d de habilidad"], e.hab) or ""
		lineas[#lineas + 1] = format(L["La primera vez: %s%s."], V.Fecha(e.primera), con)
	end
	if e.ultima then lineas[#lineas + 1] = format(L["La última: %s."], V.Hace(e.ultima)) end
	return table.concat(lineas, "\n")
end

local function textoAguas(d)
	local lineas = {}
	local e = d.e
	if e and type(e.zonas) == "table" then
		local z = {}
		for nombre, n in pairs(e.zonas) do z[#z + 1] = { nombre, n } end
		table.sort(z, function(a, b) return a[2] > b[2] end)
		local partes = {}
		for i = 1, min(4, #z) do partes[#partes + 1] = format(L["%s ×%d"], z[i][1], z[i][2]) end
		if #partes > 0 then lineas[#lineas + 1] = format(L["Donde lo sacas: %s."], table.concat(partes, DOT)) end
	end
	local bancos = type(d.id) == "number" and M.BANCOS_DE[d.id]
	if bancos then
		local mapas, visto = {}, {}
		for _, b in ipairs(bancos) do
			for _, m in ipairs(M.BANCOS[b].mapas) do
				local n = V.NombreMapa(m)
				if n and not visto[n] then
					visto[n] = true
					mapas[#mapas + 1] = n
				end
			end
		end
		table.sort(mapas)
		if #mapas > 0 then lineas[#lineas + 1] = format(L["En bancos de peces de: %s."], table.concat(mapas, ", ")) end
	end
	if #lineas == 0 then
		lineas[#lineas + 1] = L["Sale en aguas abiertas; los datos del juego no dicen dónde. Tu diario lo anota cuando lo saques."]
	end
	return table.concat(lineas, "\n")
end

local function textoRecetas(d)
	local rs = type(d.id) == "number" and M.RECETAS_DE[d.id]
	if not rs then return nil end
	local lineas = {}
	for _, r in ipairs(rs) do
		local nombre = Eq.Nombre(r.cocinado) or V.NombreObjeto(r.cocinado)
		local sabe = M.Cocina and M.Cocina.Sabe(r.hechizo)
		lineas[#lineas + 1] = format(L["%s · Cocina %d · %s"], nombre, r.habilidad, sabe and L["ya la sabes"] or L["sin aprender"])
	end
	return table.concat(lineas, "\n")
end

local function textoValor(d)
	if type(d.id) ~= "number" then return nil end
	local venta, subasta = M.ValorDe(d.id)
	local partes = {}
	if venta and venta > 0 then partes[#partes + 1] = format(L["Se vende en %s cada uno."], N.Dinero(venta)) end
	if subasta then partes[#partes + 1] = format(L["En la subasta, unos %s."], N.Dinero(subasta)) end
	if #partes == 0 then return nil end
	if d.n > 0 and venta and venta > 0 then partes[#partes + 1] = format(L["Lo que llevas pescado: %s."], N.Dinero(venta * d.n)) end
	return table.concat(partes, " ")
end

local function ficha(pila, d)
	if not pila.cab then
		pila.cab = pila:Agregar(cabecera(pila))
		pila.maestria = pila:Agregar(maestria(pila))
		pila.numeros = pila:Agregar(V.Parrafo(pila, "texto", "textoSuave"))
		pila.aguasSec = pila:Agregar(K.Seccion(pila, L["Dónde sale"]))
		pila.aguas = pila:Agregar(V.Parrafo(pila, "nota", "textoSuave"), { espacio = ESP.xs })
		pila.recetasSec = pila:Agregar(K.Seccion(pila, L["Recetas"]))
		pila.recetas = pila:Agregar(V.Parrafo(pila, "nota", "textoSuave"), { espacio = ESP.xs })
		pila.valorSec = pila:Agregar(K.Seccion(pila, L["Lo que vale"]))
		pila.valor = pila:Agregar(V.Parrafo(pila, "nota", "textoSuave"), { espacio = ESP.xs })
		pila.acciones = pila:Agregar(acciones(pila))
	end
	pila.cab:Set(d)
	pila.maestria:Set(d.n)
	pila.numeros:Set(textoNumeros(d))
	pila.aguas:Set(textoAguas(d))
	local rec = textoRecetas(d)
	pila.recetas:Set(rec)
	K.Mostrar(pila.recetasSec, rec ~= nil)
	local val = textoValor(d)
	pila.valor:Set(val)
	K.Mostrar(pila.valorSec, val ~= nil)
	local lista = {}
	lista[#lista + 1] = { texto = L["Ponerme una meta"], alClic = function(b) menuMeta(b, d) end }
	if type(d.id) == "number" then
		lista[#lista + 1] = { texto = L["Guíame"], alClic = function() V.Guiar("item", d.id) end }
		local P = rawget(_G, "AlfaPlanes")
		if type(P) == "table" and type(P.AgregarObjeto) == "function" then
			lista[#lista + 1] = { texto = L["A Mis planes"], alClic = function() pcall(P.AgregarObjeto, d.id, max(1, (d.n > 0 and 20 or 1))) end }
		end
		local En = rawget(_G, "AlfaEnciclopedia")
		if type(En) == "table" and type(En.Abrir) == "function" then
			lista[#lista + 1] = { texto = L["En la Enciclopedia"], alClic = function() pcall(En.Abrir, "objeto", d.id) end }
		end
	end
	pila.acciones:Set(lista)
end

---------------------------------------------------------------------------
-- La pestaña
---------------------------------------------------------------------------
local function construir(padre)
	V.Codex()
	local p = CreateFrame("Frame", nil, padre)
	local estado = { filtro = "todo", texto = "" }
	local todas = {}
	local lf
	local function cuentas()
		local c = {}
		for k, f in pairs(FILTROS) do
			local n = 0
			for _, d in ipairs(todas) do if f(d) then n = n + 1 end end
			c[k] = n
		end
		return c
	end
	local function opciones()
		local c = cuentas()
		return {
			{ valor = "todo", texto = L["Todo"], cuenta = c.todo },
			{ valor = "mios", texto = L["Lo que pescaste"], cuenta = c.mios },
			{ valor = "pez", texto = L["Peces"], cuenta = c.pez },
			{ valor = "especial", texto = L["Trofeos y concurso"], cuenta = c.especial },
			{ valor = "otros", texto = L["Sorpresas y cofres"], cuenta = c.otros },
		}
	end
	local function rehacer(conservar)
		local elegido = lf and lf:Elegido()
		local lista = filtrar(todas, estado.filtro, estado.texto)
		lf:SetDatos(lista, conservar)
		if conservar and elegido then
			for i, d in ipairs(lista) do
				if d.id == elegido.id then lf.Lista.alfaElegida = i lf:MostrarFicha(d) break end
			end
			lf.Lista:Refrescar()
		end
	end
	lf = K.ListaFicha(p, {
		margen = 0, arriba = 0, abajo = 0, anchoFicha = 360, alto = 40,
		buscador = { ayuda = L["Buscar en el diario"], alCambiar = function(t) estado.texto = t or "" rehacer() end },
		segmentos = { opciones = opciones(), valor = "todo", estilo = "pildoras", alCambiar = function(v2) estado.filtro = v2 rehacer() end },
		crear = function(f)
			f.Icono = K.IconoObjeto(f, 28)
			f.Icono:EnableMouse(false)
			f.Icono:SetPoint("LEFT", f, "LEFT", 8, 0)
			f.Cuenta = K.Texto(f, "numero", "textoSuave")
			f.Cuenta:SetJustifyH("RIGHT")
			f.Cuenta:SetPoint("RIGHT", f, "RIGHT", -12, 0)
			f.Nombre = K.Texto(f, "cuerpo", "texto")
			f.Nombre:SetPoint("TOPLEFT", f.Icono, "TOPRIGHT", 10, 1)
			f.Nombre:SetPoint("RIGHT", f.Cuenta, "LEFT", -8, 0)
			f.Sub = K.Texto(f, "pequeno", "textoTenue")
			f.Sub:SetPoint("TOPLEFT", f.Nombre, "BOTTOMLEFT", 0, -2)
			f.Sub:SetPoint("RIGHT", f.Cuenta, "LEFT", -8, 0)
		end,
		pintar = function(f, d)
			f.Icono:SetObjeto({ id = type(d.id) == "number" and d.id or nil, icono = d.e and d.e.icono, calidad = d.calidad })
			f.Icono:SetAlpha(d.n > 0 and 1 or 0.55)
			K.Escribir(f.Nombre, d.nombre or "?")
			if d.n > 0 then V.ColorCalidad(f.Nombre, d.calidad) else K.ColorTexto(f.Nombre, "textoSuave") end
			local nivel, nombre = M.Maestria(d.n)
			K.Escribir(f.Sub, (M.NOMBRE_CLASE[d.clase] or "") .. (nivel > 0 and (DOT .. nombre) or ""))
			f.Cuenta:SetText(d.n > 0 and format("\195\151%d", d.n) or "\226\128\148")
		end,
		ficha = ficha,
		vacio = { lobo = "vacio", titulo = L["Nada con ese nombre"], texto = L["Prueba con otra palabra o quita el filtro."] },
		vacioFicha = { lobo = "dormido", titulo = L["Elige una captura"], texto = L["Aquí ves cuántas llevas, dónde sale y qué hacer con ella."] },
	})
	function p:Refrescar()
		todas = entradas()
		if lf.Segmentos then lf.Segmentos:SetOpciones(opciones()) lf.Segmentos:SetValor(estado.filtro) end
		rehacer(self.armado)
		self.armado = true
	end
	function p:Acomodar(ancho, alto)
		self:SetSize(ancho, alto)
		lf:Acomodar(ancho, alto)
		-- La primera vez la lista se llenó antes de tener alto: arriba del todo.
		if not self.medida then
			self.medida = true
			lf.Lista:IrAPos(0)
		end
		return alto
	end
	return p
end

V.Registrar("diario", { nombre = L["Diario"], icono = M.ICONO.diario, orden = 1, cambia = { registro = true, captura = true }, construir = construir })
