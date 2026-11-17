-- Alfa - Lya: la ventana Historias (toxic3000 / La Jauría). GPL-3.0.
--
-- Las misiones que Lya te guardó, agrupadas por zona (las de la zona donde
-- jugaste hace menos, primero), con buscador y filtro de zona. A la
-- derecha, la historia completa con el formato de Alfa: quién te la dio, con
-- quién se entrega, la historia, lo que te piden, lo que te dicen mientras y el
-- final; "Seguir" si aún la tienes (la guía del motor y N.EmpezarRuta) y la
-- Enciclopedia. Clic en una zona: lo que Lya sabe de ese lugar (Lore.lua).
-- Hecha con el Kit (K.Ventana y K.ListaFicha): se ve bien en los tres estilos.
--
--   M.VentanaHistorias.Abrir(questID, seccion)   .Cerrar()   .Visible()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, tonumber, tostring, pairs, ipairs, pcall, rawget, format = type, tonumber, tostring, pairs, ipairs, pcall, rawget, string.format
local floor, max, min = math.floor, math.max, math.min
local sort = table.sort
local ESP = K.ESP

local V = {}
M.VentanaHistorias = V

local ANCHO, ALTO, FILA, ANCHO_ZONA = 920, 620, 36, 240
local TODAS = "\001todas"

local v
local ui = {}
local est = { texto = "", zona = TODAS, n = 0 }

local function H() return M.Historias end

local function secreto(x) return issecretvalue and issecretvalue(x) or false end
local function verdad(x) return not secreto(x) and x == true end

local function enRegistro(q)
	local QL = C_QuestLog
	if not (QL and q) then return false end
	if QL.IsOnQuest then
		local ok, si = pcall(QL.IsOnQuest, q)
		if ok and verdad(si) then return true end
	end
	if QL.GetLogIndexForQuestID then
		local ok, i = pcall(QL.GetLogIndexForQuestID, q)
		if ok and not secreto(i) and type(i) == "number" and i > 0 then return true end
	end
	return false
end

local function terminada(q, r)
	if r and r.c then return true end
	local QL = C_QuestLog
	if QL and QL.IsQuestFlaggedCompleted then
		local ok, si = pcall(QL.IsQuestFlaggedCompleted, q)
		return ok and verdad(si)
	end
	return false
end

local function zonaDe(r) return r.zn or L["Otras tierras"] end

-- Se muestran las que tomaste (o entregaste): las que solo viste y rechazaste, no.
local function mostrable(q, r)
	return type(q) == "number" and type(r) == "table" and (r.t or r.d) and (r.a or r.c) and true or false
end
local function tituloDe(q, r) return r.t or format(L["Misión %d"], q) end

local function fecha(t)
	t = tonumber(t)
	if not (t and date) then return nil end
	local ok, s = pcall(date, "%d/%m/%Y", t)
	return ok and s or nil
end

---------------------------------------------------------------------------
-- Los datos de la lista
---------------------------------------------------------------------------
local function coincide(q, r, zona, buscar)
	if buscar == "" then return true end
	local minus = H().Minus
	for _, s in ipairs({ r.t, r.g, r.e, zona, r.d, r.o }) do
		if type(s) == "string" and minus(s):find(buscar, 1, true) then return true end
	end
	return tostring(q) == buscar
end

local function armar()
	local s = H().Todas()
	local buscar = H().Minus(est.texto or "")
	local grupos, orden = {}, {}
	local n = 0
	for q, r in pairs(s) do
		if mostrable(q, r) then
			local zona = zonaDe(r)
			if (est.zona == TODAS or est.zona == zona) and coincide(q, r, zona, buscar) then
				local g = grupos[zona]
				if not g then
					g = { zona = zona, mapa = r.z, items = {}, reciente = 0 }
					grupos[zona] = g
					orden[#orden + 1] = g
				end
				g.items[#g.items + 1] = { q = q, r = r }
				local u = tonumber(r.u) or 0
				if u > g.reciente then g.reciente = u end
				if not g.mapa and r.z then g.mapa = r.z end
				n = n + 1
			end
		end
	end
	sort(orden, function(a, b)
		if a.reciente ~= b.reciente then return a.reciente > b.reciente end
		return a.zona < b.zona
	end)
	local datos = {}
	for _, g in ipairs(orden) do
		sort(g.items, function(a, b) return (tonumber(a.r.u) or 0) > (tonumber(b.r.u) or 0) end)
		datos[#datos + 1] = { encabezado = true, zona = g.zona, mapa = g.mapa, n = #g.items }
		for _, it in ipairs(g.items) do datos[#datos + 1] = it end
	end
	est.n = n
	return datos
end

local function opcionesZona()
	local cuenta, nombres = {}, {}
	for q, r in pairs(H().Todas()) do
		if mostrable(q, r) then
			local z = zonaDe(r)
			if not cuenta[z] then cuenta[z] = 0 nombres[#nombres + 1] = z end
			cuenta[z] = cuenta[z] + 1
		end
	end
	sort(nombres)
	local ops = { { valor = TODAS, texto = L["Todas las zonas"] } }
	for _, z in ipairs(nombres) do ops[#ops + 1] = { valor = z, texto = format(L["%s (%d)"], z, cuenta[z]) } end
	if est.zona ~= TODAS and not cuenta[est.zona] then est.zona = TODAS end
	return ops
end

---------------------------------------------------------------------------
-- Las filas
---------------------------------------------------------------------------
local function crearFila(f)
	f.Icono = K.Icono(f, "ic-misiones", 14, "textoSuave")
	f.Icono:SetPoint("LEFT", f, "LEFT", 14, 0)
	f.Nombre = K.Texto(f, "cuerpo", "texto")
	f.Nombre:SetPoint("LEFT", f, "LEFT", 36, 0)
	f.Estado = K.Texto(f, "pequeno", "textoTenue")
	f.Estado:SetPoint("RIGHT", f, "RIGHT", -12, 0)
	f.Estado:SetJustifyH("RIGHT")
	f.Zona = K.Texto(f, "mayus", "acento")
	f.Zona:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
end

local function pintarFila(f, d)
	local ancho = K.num(f:GetWidth(), 300)
	if d.encabezado then
		f.Icono:Hide()
		f.Nombre:Hide()
		f.Estado:Hide()
		f.Zona:Show()
		K.Escribir(f.Zona, K.Mayus(d.zona) .. "   " .. K.Tenir("textoTenue", tostring(d.n)))
		f.Zona:SetWidth(max(60, ancho - 24))
		return
	end
	f.Zona:Hide()
	f.Icono:Show()
	f.Nombre:Show()
	f.Estado:Show()
	local abierta = enRegistro(d.q)
	K.SetIcono(f.Icono, "ic-misiones", abierta and "acento" or "textoSuave")
	K.Escribir(f.Estado, abierta and L["En tu registro"] or (terminada(d.q, d.r) and L["Terminada"] or ""))
	local we = K.Ajustar(f.Estado, 110)
	K.Escribir(f.Nombre, tituloDe(d.q, d.r))
	K.Ajustar(f.Nombre, ancho - 36 - (we > 0 and we + 20 or 12))
end

---------------------------------------------------------------------------
-- La ficha
---------------------------------------------------------------------------
-- Un título de sección y su texto (el del juego, completo).
local function bloqueTexto(pila)
	local b = CreateFrame("Frame", nil, pila)
	b.Seccion = K.Seccion(b, "")
	b.Texto = K.Texto(b, "texto", "texto")
	function b:Set(titulo, t, color)
		self.Seccion:Set(titulo)
		K.ColorTexto(self.Texto, color or "texto")
		K.Escribir(self.Texto, t or "")
	end
	function b:Acomodar(w)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(w)
		local y = self.Seccion:Acomodar(w) + ESP.s
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -y)
		y = y + K.Parrafo(self.Texto, w - 8)
		self:SetHeight(y)
		return y
	end
	return b
end

-- Varias notas cortas con su huella (lo que Lya sabe de una zona).
local function bloqueNotas(pila)
	local b = CreateFrame("Frame", nil, pila)
	b.Seccion = K.Seccion(b, "")
	b.notas = {}
	function b:Set(titulo, lista)
		self.Seccion:Set(titulo, { cuenta = #lista })
		for i, t in ipairs(lista) do
			local n = self.notas[i]
			if not n then
				n = { Huella = K.Icono(self, "ic-huella", 12, "acento"), Texto = K.Texto(self, "texto", "texto") }
				self.notas[i] = n
			end
			K.Escribir(n.Texto, t)
			n.Huella:Show()
			n.Texto:Show()
		end
		for i = #lista + 1, #self.notas do self.notas[i].Huella:Hide() self.notas[i].Texto:Hide() end
		self.alfaN = #lista
	end
	function b:Acomodar(w)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(w)
		local y = self.Seccion:Acomodar(w) + ESP.s
		for i = 1, self.alfaN or 0 do
			local n = self.notas[i]
			n.Huella:ClearAllPoints()
			n.Huella:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -(y + 2))
			n.Texto:ClearAllPoints()
			n.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 24, -y)
			y = y + K.Parrafo(n.Texto, w - 28) + ESP.m
		end
		self:SetHeight(y)
		return y
	end
	return b
end

-- Los botones de la ficha y cómo va la misión.
local function bloqueAcciones(pila)
	local b = CreateFrame("Frame", nil, pila)
	b.Seguir = K.Boton(b, L["Seguir"], nil, { tipo = "primario", icono = "ic-seguir" })
	b.Enciclopedia = K.Boton(b, L["En la Enciclopedia"], nil, { tipo = "secundario", icono = "ic-enciclopedia" })
	b.Estado = K.Insignia(b, "", "neutro")
	function b:Acomodar(w)
		local x = 0
		for _, bt in ipairs({ self.Seguir, self.Enciclopedia }) do
			if bt:IsShown() then
				bt:SetAncho(nil)
				local bw = bt:AnchoNatural()
				bt:SetAncho(bw)
				bt:ClearAllPoints()
				bt:SetPoint("TOPLEFT", self, "TOPLEFT", x, 0)
				x = x + bw + ESP.s
			end
		end
		self.Estado:ClearAllPoints()
		if x > 0 then
			self.Estado:SetPoint("LEFT", self, "TOPLEFT", x + ESP.xs, -floor(K.ALTO.boton / 2))
		else
			self.Estado:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		end
		local h = x > 0 and K.ALTO.boton or K.ALTO.insignia
		self:SetHeight(h)
		return h
	end
	return b
end

local function bloqueNota(pila)
	local b = CreateFrame("Frame", nil, pila)
	b.Texto = K.Texto(b, "pequeno", "textoTenue")
	b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	function b:Set(t) K.Escribir(self.Texto, t or "") end
	function b:Acomodar(w)
		local h = K.Parrafo(self.Texto, w)
		self:SetHeight(max(1, h))
		return h
	end
	return b
end

local function seguir(q)
	if InCombatLockdown and InCombatLockdown() then
		N.Imprimir(L["Eso se puede al salir de combate."])
		return
	end
	local Lk = A.Lookup
	if Lk and type(Lk.Guide) == "function" then
		local ok, gid = pcall(Lk.Guide, "quest", q)
		if ok and gid then
			N.EmpezarRuta()
			return
		end
	end
	-- Sin la guía del motor: a tu plan de misiones (Rutas avisa y la arma).
	local R = rawget(_G, "AlfaRuta")
	if type(R) == "table" and type(R.AgregarMision) == "function" then
		local ok, puesto = pcall(R.AgregarMision, q)
		if ok and puesto then return end
	end
	N.Imprimir(L["Ahora no pude armar el camino a esta misión."])
end

local function enciclopedia(q)
	local E = rawget(_G, "AlfaEnciclopedia")
	if type(E) == "table" and type(E.Abrir) == "function" then pcall(E.Abrir, "mision", q) end
end

local B = {}

local function armarFicha(pila)
	if B.enc then return end
	B.pila = pila
	B.enc = pila:Agregar(K.Encabezado(pila, {}))
	B.acc = pila:Agregar(bloqueAcciones(pila), { espacio = ESP.base })
	B.historia = pila:Agregar(bloqueTexto(pila), { espacio = ESP.l })
	B.objetivos = pila:Agregar(bloqueTexto(pila), { espacio = ESP.l })
	B.progreso = pila:Agregar(bloqueTexto(pila), { espacio = ESP.l })
	B.final = pila:Agregar(bloqueTexto(pila), { espacio = ESP.l })
	B.notas = pila:Agregar(bloqueNotas(pila), { espacio = ESP.l })
	B.pie = pila:Agregar(bloqueNota(pila), { espacio = ESP.l })
end

local function texto(b, titulo, t, color)
	if t then b:Set(titulo, t, color) end
	K.Mostrar(b, t ~= nil)
end

local function fichaZona(d)
	local cuantas = d.n == 1 and L["1 historia guardada aquí"] or format(L["%d historias guardadas aquí"], d.n)
	B.enc:Set({ icono = "ic-mundo", sobre = L["Zona"], titulo = d.zona, subtitulo = cuantas })
	K.Mostrar(B.acc, false)
	for _, b in ipairs({ B.historia, B.objetivos, B.progreso, B.final }) do K.Mostrar(b, false) end
	local notas = H().NotasDeZona(d.mapa)
	local lista = {}
	if notas then for i, es in ipairs(notas) do lista[i] = L[es] end end
	if #lista > 0 then B.notas:Set(L["Lo que Lya sabe de aquí"], lista) end
	K.Mostrar(B.notas, #lista > 0)
	B.pie:Set(#lista > 0 and L["Datos curiosos de Lya, escritos por Alfa."] or L["De este lugar Lya todavía no sabe datos curiosos. Elige una misión de la lista para leer su historia."])
	K.Mostrar(B.pie, true)
end

local function fichaMision(d)
	local q, r = d.q, d.r
	local sub
	if r.g and r.e and r.g ~= r.e then sub = format(L["Te la dio %s · Se entrega con %s"], r.g, r.e)
	elseif r.g and r.e then sub = format(L["Te la dio y la recibe %s"], r.g)
	elseif r.g then sub = format(L["Te la dio %s"], r.g)
	elseif r.e then sub = format(L["Se entrega con %s"], r.e) end
	B.enc:Set({ icono = "ic-misiones", sobre = zonaDe(r), titulo = tituloDe(q, r), subtitulo = sub })
	local abierta = enRegistro(q)
	local hecha = terminada(q, r)
	B.acc.Seguir.alClic = function() seguir(q) end
	B.acc.Seguir:SetShown(abierta)
	local E = rawget(_G, "AlfaEnciclopedia")
	B.acc.Enciclopedia.alClic = function() enciclopedia(q) end
	B.acc.Enciclopedia:SetShown(type(E) == "table" and type(E.Abrir) == "function")
	if abierta then B.acc.Estado:Set(L["En tu registro"], "exito", "ic-exito")
	elseif hecha then B.acc.Estado:Set(L["Terminada"], "neutro")
	else B.acc.Estado:Set(L["Ya no está en tu registro"], "neutro") end
	K.Mostrar(B.acc, true)
	texto(B.historia, L["La historia"], r.d)
	texto(B.objetivos, L["Lo que te piden"], r.o)
	texto(B.progreso, L["Mientras la haces"], r.p, "textoSuave")
	texto(B.final, L["El final"], r.r)
	K.Mostrar(B.notas, false)
	local partes = {}
	local f = fecha(r.a) or fecha(r.u)
	if f then partes[#partes + 1] = format(L["Guardada el %s"], f) end
	if not r.r then partes[#partes + 1] = hecha and L["Su final no alcanzó a guardarse."] or L["El final lo verás al entregarla."] end
	if not r.d then partes[#partes + 1] = L["La historia se guarda cuando el juego te muestra la misión."] end
	B.pie:Set(table.concat(partes, "  ·  "))
	K.Mostrar(B.pie, #partes > 0)
end

local function llenarFicha(pila, d)
	armarFicha(pila)
	if d.encabezado then fichaZona(d) else fichaMision(d) end
end

---------------------------------------------------------------------------
-- Acomodo
---------------------------------------------------------------------------
local function acomodar()
	if not v then return end
	local w = v:AnchoCuerpo()
	local x, y = v.margen, ESP.base
	local zw = min(ANCHO_ZONA, floor(w * 0.4))
	ui.zonas:SetWidth(zw)
	ui.zonas:ClearAllPoints()
	ui.zonas:SetPoint("TOPRIGHT", v.Cuerpo, "TOPLEFT", x + w, -y)
	ui.buscador:ClearAllPoints()
	ui.buscador:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
	ui.buscador:SetWidth(max(160, w - zw - ESP.base))
	y = y + K.ALTO.control + ESP.m
	local alto = v:AltoCuerpo() - y - ESP.base
	ui.zona:ClearAllPoints()
	ui.zona:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
	ui.zona:SetSize(w, alto)
	ui.lf:Acomodar(w, alto)
end

local function indiceDe(datos, q)
	for i, d in ipairs(datos) do if d.q == q then return i end end
	return nil
end

-- Vuelve a llenar la lista; elige `q` si está, o la primera misión.
local function rehacer(q)
	ui.zonas:SetOpciones(opcionesZona())
	ui.zonas:SetValor(est.zona)
	local datos = armar()
	ui.lf:SetDatos(datos)
	local i = q and indiceDe(datos, q)
	if not i then
		for k, d in ipairs(datos) do if not d.encabezado then i = k break end end
	end
	if i then ui.lf:Elegir(i) else ui.lf:MostrarFicha(nil) end
end

local function cuentaTexto()
	local n = est.n or 0
	if n == 0 then return "" end
	return n == 1 and L["1 historia"] or format(L["%d historias"], n)
end

local function crear()
	v = K.Ventana({ nombre = "AlfaLyaHistorias", titulo = L["Historias"], subtitulo = L["Lo que cuentan las misiones que vas tomando"],
		icono = "ic-misiones", ancho = ANCHO, alto = ALTO })
	local cuerpo = v.Cuerpo
	ui.buscador = K.Buscador(cuerpo, { ayuda = L["Busca una misión, un PNJ, una zona o una palabra…"], retraso = 0.25,
		alCambiar = function(t)
			est.texto = t or ""
			rehacer()
		end })
	ui.zonas = K.Desplegable(cuerpo, { opciones = { { valor = TODAS, texto = L["Todas las zonas"] } }, valor = TODAS, ancho = ANCHO_ZONA,
		alCambiar = function(val)
			est.zona = val or TODAS
			rehacer()
		end })
	ui.zona = CreateFrame("Frame", nil, cuerpo)
	ui.lf = K.ListaFicha(ui.zona, {
		margen = 0, arriba = 0, abajo = 0, anchoFicha = 500, alto = FILA,
		crear = crearFila, pintar = pintarFila, ficha = llenarFicha, cuenta = cuentaTexto,
		elegirPrimero = false,
		vacio = { lobo = "dormido", titulo = L["Aún no hay historias"],
			texto = L["Lya guarda la historia de cada misión que tomas, aunque la aceptes sin leerla. Tú sigue la flecha: ella se acuerda de todo."] },
		vacioFicha = { lobo = "atento", titulo = L["Elige una misión"], texto = L["Aquí la lees completa: cómo empieza, qué te piden y cómo termina."] },
	})
	v.alAcomodar = function() acomodar() end
	v:SetPie({ K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "fantasma" }) },
		{ K.Boton(v, L["Cuéntame algo de aquí"], function() if M.Historias then M.Historias.Contar() end end, { tipo = "secundario", icono = "ic-lobo" }) })
end

-- q: la misión que se elige (si está guardada); seccion: "final" baja hasta el final.
function V.Abrir(q, seccion)
	if N.Permitido and not N.Permitido() then return end
	if not v then crear() end
	if q then
		est.texto, est.zona = "", TODAS
		ui.buscador:SetTexto("", true)
	end
	v:Abrir()
	acomodar()
	rehacer(q)
	if seccion == "final" and B.final and B.final:IsShown() and ui.lf.FichaDesp then
		-- Que el final quede a la vista: la ficha baja hasta él.
		local d = ui.lf.FichaDesp
		local arriba = K.num(d.Contenido:GetTop(), 0) - K.num(B.final:GetTop(), 0)
		local rango = max(0, K.num(d.alfaAltoContenido, 0) - K.num(d:GetHeight(), 0))
		local y = max(0, min(rango, floor(arriba) - ESP.s))
		d:SetVerticalScroll(y)
		if d.Barra then
			d.alfaQuieto = true
			d.Barra:SetValue(y)
			d.alfaQuieto = nil
		end
	end
end

-- Elige la fila i de la lista (una zona o una misión).
function V.Elegir(i) if v and v:IsShown() and i then ui.lf:Elegir(i) end end
function V.Cerrar() if v then v:Cerrar() end end
function V.Visible() return v and v:IsShown() and true or false end
