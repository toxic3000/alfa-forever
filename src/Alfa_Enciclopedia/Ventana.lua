-- Alfa - Enciclopedia: la ventana (toxic3000 / La Jauría). GPL-3.0.
--
-- Una ventana propia del Kit (K.Ventana) con, de arriba abajo:
--   1. el buscador (español o inglés, también por número) y los tipos
--      (Objetos, PNJ, Misiones, Zonas, Raros), con cuántos encuentra cada uno;
--   2. los filtros del tipo elegido (solo los que sirven: un tipo sin filtros
--      no deja una fila vacía);
--   3. la lista virtual y la ficha (K.ListaFicha). La ficha empieza con lo
--      mejor para ti y sus botones (Guíame, Ver en el mapa, Agregar a Mis
--      planes, a mi ruta o a Cerrar mis misiones, Vincular) y sigue con una
--      sección por cada fuente que tiene datos.
-- Las filas de la ficha llevan a la ficha de lo que nombran (un PNJ, una
-- misión, un objeto...) y "Volver" regresa.
--
--   V.Abrir(pedido)  pedido = { texto, tipo, kind, id }   V.Cerrar(), V.Visible()

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local Cat, I, F = M.Cat, M.Indices, M.F
local Cu = M.Cuadro -- 1.3.7: el cuadro con retraso y el menú del clic derecho (Cuadro.lua)
local V = {}
M.V = V

local type, tonumber, tostring, ipairs, pairs, pcall = type, tonumber, tostring, ipairs, pairs, pcall
local floor, max, min, format = math.floor, math.max, math.min, string.format
local ESP = K.ESP

local ANCHO, ALTO = 1040, 660
-- 1.3.7: la ventana se agranda y se achica por su esquina; nunca más grande
-- que la pantalla (con la interfaz grande, en pantallas chicas, no cabía).
local ANCHO_MIN, ALTO_MIN = 720, 460
local FILA = 40
local CAPA = "enciclopedia" -- la capa de Alfa.Pins con lo que pides ver en el mapa
local VISIBLES, EXPANDIDAS = 5, 50 -- filas de una sección: plegada y abierta

local v      -- la ventana
local ui = {}
local est = {
	tipo = "objeto", texto = "",
	-- Monturas y mascotas empiezan con las que se pueden conseguir.
	filtros = { objeto = {}, montura = { estado = "conseguible" }, mascota = { estado = "conseguible" }, pnj = {}, mision = {}, zona = {}, raro = {} },
	resultados = {}, pila = {}, actual = nil, abiertas = {}, enMapa = nil,
}

local function aviso(ok, texto, titulo)
	if not texto then return end
	K.Aviso({ titulo = titulo or (ok and L["Listo"] or L["No se pudo"]), texto = texto, icono = ok and "ic-exito" or "ic-aviso",
		tono = ok and "acento" or "aviso", duracion = ok and 4 or 6 })
end

---------------------------------------------------------------------------
-- El mapa y la flecha
---------------------------------------------------------------------------
local capaRegistrada = false
local function registrarCapa()
	if capaRegistrada then return end
	capaRegistrada = true
	local Mu = AlfaMundo
	if type(Mu) == "table" and type(Mu.RegistrarCapa) == "function" then
		pcall(Mu.RegistrarCapa, { id = CAPA, grupo = L["Guía"], nombre = L["Lo que buscas en la Enciclopedia"],
			ayuda = L["Los lugares que pides ver en el mapa desde la Enciclopedia."], color = "acento", activa = true, esencial = true, zoom = 1,
			-- Su interruptor también manda en el mapa del juego y el minimapa (no solo en el de Alfa).
			alCambiar = function(on)
				local Pn = A.Pins
				if Pn and Pn.SetLayerVisible then Pn.SetLayerVisible(CAPA, on) end
			end })
	end
end

-- La flecha y la ruta del motor hasta un punto. Con el mapa de Alfa, como
-- sus marcadores (AlfaMundo.SeguirPunto: un viaje que vuelve a la guía al
-- llegar, y avisa él); un punto en coordenadas de la era (f = "e") o sin
-- Mundo, directo con el motor, que respeta ese marco.
local function flecha(p)
	if not p then return end
	local Mu = AlfaMundo
	if not p.f and type(Mu) == "table" and type(Mu.SeguirPunto) == "function" then
		local ok, bien = pcall(Mu.SeguirPunto, p.map, p.x, p.y, p.nombre)
		if ok and bien then return end
	end
	local Nv = A.Nav
	if not (Nv and Nv.SetTarget) then return end
	local t = Nv.SetTarget(p.map, p.x, p.y, p.nombre, p.f, nil, p.z)
	if not t then return aviso(false, L["Ahí no se puede poner la flecha."]) end
	if type(Nv.StartTrip) == "function" then pcall(Nv.StartTrip, t, p.nombre, L["Enciclopedia"], "arrive") end
	aviso(true, format(L["La flecha te lleva a %s."], p.nombre or M.Zona(p.map) or "?"), L["Flecha puesta"])
end
V.Flecha = flecha

local function abrirMapa(mapa)
	if not mapa then return end
	local Mu = AlfaMundo
	if type(Mu) == "table" and type(Mu.Abrir) == "function" then
		local ok = pcall(Mu.Abrir, mapa)
		if ok then return end
	end
	local Cp = A.Compat
	if Cp.CanOpenWorldMap and Cp.CanOpenWorldMap() and Cp.OpenWorldMap(mapa) then return end
	aviso(false, L["El mapa no se abre en combate."])
end

-- Los lugares de una ficha en el mapa (la capa de la Enciclopedia).
local function verEnMapa(puntos, mapa, clave)
	local Pn = A.Pins
	if not (Pn and Pn.SetLayer) then return end
	registrarCapa()
	local pines = {}
	for k, p in ipairs(puntos or {}) do
		pines[k] = {
			map = p.map, x = p.x, y = p.y, f = p.f, icon = p.icono or "map:target", size = 22, priority = 5,
			tooltip = p.nombre and (p.nombre .. "\n" .. (M.Lugar(p.map, p.x, p.y) or "")) or nil,
			onClick = function() flecha(p) end,
		}
	end
	if #pines > 0 then
		Pn.SetLayer(CAPA, pines, { world = true, minimap = true })
		est.enMapa = clave
	end
	abrirMapa(mapa or (puntos and puntos[1] and puntos[1].map))
end

local function quitarDelMapa()
	local Pn = A.Pins
	if Pn and Pn.ClearLayer then Pn.ClearLayer(CAPA) end
	est.enMapa = nil
end

---------------------------------------------------------------------------
-- Navegar entre fichas
---------------------------------------------------------------------------
local mostrarFicha -- (kind, id, desdeLista)
local rehacerFichaActual -- (más abajo)

local function recordar(kind, id)
	local d = N.DatosPersonaje(M.ID)
	d.recientes = type(d.recientes) == "table" and d.recientes or {}
	local r = d.recientes
	for i = #r, 1, -1 do if r[i].k == kind and r[i].id == id then table.remove(r, i) end end
	table.insert(r, 1, { k = kind, id = id })
	for i = #r, 13, -1 do r[i] = nil end
	if M.alRecientes then K.Llamar(M.alRecientes) end
end

local function navegar(ir)
	if not (ir and ir.kind and ir.id) then return end
	if ir.kind == "instance" then
		A.Fire("SHOW_DUNGEON", ir.id)
		return
	end
	if est.actual then est.pila[#est.pila + 1] = est.actual end
	if #est.pila > 20 then table.remove(est.pila, 1) end
	ui.lf:MostrarFicha({ kind = ir.kind, id = ir.id, nav = true })
end

local function volver()
	local previo = table.remove(est.pila)
	if previo then ui.lf:MostrarFicha({ kind = previo.kind, id = previo.id, nav = true, atras = true }) end
end

---------------------------------------------------------------------------
-- La ficha: sus bloques se crean una vez y se reutilizan
---------------------------------------------------------------------------
local B = {}

-- Cabecera: ícono (del objeto, con el borde de su calidad, o de Alfa),
-- sobretítulo, nombre, línea de datos, insignias y "Volver".
local function bloqueCabecera(pila)
	local c = CreateFrame("Frame", nil, pila)
	c.Objeto = K.IconoObjeto(c, 44)
	c.Objeto:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	c.Baldosa = CreateFrame("Frame", nil, c)
	c.Baldosa:SetSize(44, 44)
	c.Baldosa:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	c.Baldosa.caja = K.Caja(c.Baldosa, { fondo = "elevado", borde = "linea", corte = K.CORTE.control })
	c.Glifo = K.Icono(c.Baldosa, "ic-enciclopedia", 24, "acento")
	c.Glifo:SetPoint("CENTER")
	c.Sobre = K.Texto(c, "mayus", "acento")
	c.Titulo = K.Texto(c, "titulo", "texto")
	c.Sub = K.Texto(c, "nota", "textoSuave")
	c.Volver = K.BotonIcono(c, "chevron-left", function() volver() end, { tam = 26, icono = 14, tipo = "secundario", ayuda = L["Volver"] })
	c.Volver:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, 0)
	c.insignias = {}
	function c:Set(f, conVolver)
		local ic = f.icono or {}
		local esObjeto = ic.objeto ~= nil
		self.Objeto:SetShown(esObjeto)
		self.Baldosa:SetShown(not esObjeto)
		if esObjeto then self.Objeto:SetObjeto({ id = ic.objeto, calidad = ic.calidad })
		else K.SetIcono(self.Glifo, ic.ic or "ic-enciclopedia", select(2, K.Tono(ic.tono or "acento"))) end
		K.Escribir(self.Sobre, M.Mayus(f.sobre) or "")
		K.Escribir(self.Titulo, f.titulo or "")
		if type(f.color) == "table" then self.Titulo:SetTextColor(f.color[1], f.color[2], f.color[3])
		else K.ColorTexto(self.Titulo, f.color or "texto") end
		K.Escribir(self.Sub, f.subtitulo or "")
		self.Volver:SetShown(conVolver and true or false)
		local lista = f.insignias or {}
		for i, x in ipairs(lista) do
			self.insignias[i] = self.insignias[i] or K.Insignia(self, "", "neutro")
			self.insignias[i]:Set(x[1], x[2], x[3])
		end
		for i = #lista + 1, #self.insignias do self.insignias[i]:Hide() end
		self.alfaN = #lista
	end
	function c:Acomodar(w)
		local x = 44 + ESP.m
		local derecha = self.Volver:IsShown() and 34 or 0
		local tw = max(80, w - x - derecha)
		local y = 0
		local conSobre = (self.Sobre:GetText() or "") ~= ""
		if conSobre then
			self.Sobre:ClearAllPoints()
			self.Sobre:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			self.Sobre:SetWidth(tw)
			y = y + K.AltoTexto(self.Sobre) + 3
		end
		self.Sobre:SetShown(conSobre)
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
		y = y + K.Parrafo(self.Titulo, tw, 2)
		if (self.Sub:GetText() or "") ~= "" then
			y = y + 4
			self.Sub:ClearAllPoints()
			self.Sub:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			y = y + K.Parrafo(self.Sub, tw, 2)
			self.Sub:Show()
		else
			self.Sub:Hide()
		end
		y = max(44, y)
		if self.alfaN > 0 then
			y = y + ESP.s + 2
			local ix, iy = 0, y
			for i = 1, self.alfaN do
				local ch = self.insignias[i]
				local cw = K.num(ch:GetWidth(), 0)
				if ix > 0 and ix + cw > w then ix, iy = 0, iy + K.ALTO.insignia + 6 end
				ch:ClearAllPoints()
				ch:SetPoint("TOPLEFT", self, "TOPLEFT", ix, -iy)
				ix = ix + cw + 6
			end
			y = iy + K.ALTO.insignia
		end
		self:SetHeight(y)
		return y
	end
	return c
end

-- Los botones de la ficha, en una o dos filas.
local function bloqueAcciones(pila)
	local b = CreateFrame("Frame", nil, pila)
	b.Guiar = K.Boton(b, L["Guíame"], nil, { tipo = "primario", icono = "ic-seguir" })
	b.Mapa = K.Boton(b, L["Ver en el mapa"], nil, { tipo = "secundario", icono = "ic-mapa" })
	b.Ruta = K.Boton(b, L["Agregar a mi ruta"], nil, { tipo = "secundario", icono = "ic-ruta" })
	b.Falta = K.Boton(b, L["Qué me falta"], nil, { tipo = "secundario", icono = "ic-ruta",
		ayuda = L["Arma con tu ruta lo que necesitas para poder tomarla: el nivel o las misiones de antes."] })
	b.Vincular = K.Boton(b, L["Vincular"], nil, { tipo = "fantasma", icono = "ic-mas", ayuda = L["Pone el enlace en el chat."] })
	b.Plan = K.Boton(b, L["Agregar a Mis planes"], nil, { tipo = "secundario", icono = "ic-ruta",
		ayuda = L["Suma «conseguir este objeto» a tu plan de ahora (o a uno nuevo)."] })
	b.Extra = K.Boton(b, "", nil, { tipo = "secundario", icono = "ic-ventana" })
	b.Compra = K.Boton(b, L["A mi lista de compras"], nil, { tipo = "secundario", icono = "ic-oro",
		ayuda = L["Lo suma a tu lista de compras de Comercio, con lo que pide su receta."] })
	-- 1.3.7: en la ficha de una zona, su guía y su circuito a un clic.
	b.GuiaZona = K.Boton(b, L["Guía de esta zona"], nil, { tipo = "primario", icono = "ic-guia",
		ayuda = L["Abre la guía de subir de nivel de esta zona que mejor te queda."] })
	b.Circuito = K.Boton(b, L["Circuito de la zona"], nil, { tipo = "secundario", icono = "ic-ruta",
		ayuda = L["Tus misiones y las de aquí en el mejor orden, como una guía."] })
	b.lista = { b.Guiar, b.GuiaZona, b.Circuito, b.Plan, b.Falta, b.Extra, b.Mapa, b.Ruta, b.Compra, b.Vincular }
	function b:Set(f)
		local a = f.acciones or {}
		local clave = f.kind .. ":" .. tostring(f.id)
		self.Guiar:SetShown(a.guiar ~= nil)
		self.Guiar.alClic = function() local ok, msg = a.guiar() aviso(ok, msg) end
		local puntos = a.mapa or {}
		local conMapa = #puntos > 0 or a.mapaZona ~= nil
		self.Mapa:SetShown(conMapa)
		local mostrado = est.enMapa == clave
		self.Mapa:SetTexto(mostrado and L["Quitar del mapa"] or L["Ver en el mapa"])
		self.Mapa.alClic = function()
			if est.enMapa == clave then
				quitarDelMapa()
			else
				verEnMapa(puntos, a.mapaZona, clave)
			end
			self:Set(f)
			ui.lf:RehacerFicha()
		end
		-- El mismo botón sirve a dos cosas: el tramo de tu ruta (objetos) o
		-- Cerrar mis misiones (misiones); su texto y su ayuda dicen cuál.
		self.Ruta:SetShown(a.ruta ~= nil)
		self.Ruta:SetTexto(a.rutaTexto or L["Agregar a mi ruta"])
		K.ConInfo(self.Ruta, nil, a.rutaAyuda)
		self.Ruta.alClic = function()
			-- La ruta avisa sola lo que hizo; aquí solo si falló sin decir nada.
			local ok, r = pcall(a.ruta)
			if not ok then aviso(false, L["Tu ruta no pudo agregarlo."]) end
			if ok and r ~= false then K.Despues(0.1, rehacerFichaActual) end
		end
		-- La lista de compras (Alfa_Comercio): una pieza más de este objeto.
		self.Compra:SetShown(a.compra ~= nil)
		self.Compra.alClic = function()
			local ok, r = pcall(a.compra)
			if ok and r ~= false then
				aviso(true, L["Está en tu lista de compras."])
			elseif not ok then
				aviso(false, L["Tu lista de compras no pudo agregarlo."])
			end -- r == false: la lista ya dijo por qué (por ejemplo, llena)
		end
		self.Falta:SetShown(a.desbloquear ~= nil)
		self.Falta.alClic = function() pcall(a.desbloquear) end
		self.GuiaZona:SetShown(a.guiaZona ~= nil)
		self.GuiaZona.alClic = function() local ok, msg = a.guiaZona() aviso(ok, msg) end
		self.Circuito:SetShown(a.circuito ~= nil)
		self.Circuito.alClic = function() local ok, msg = a.circuito() aviso(ok, msg) end
		self.Vincular:SetShown(a.vincular ~= nil)
		self.Vincular.alClic = function() local ok, msg = a.vincular() if not ok then aviso(false, msg) end end
		-- Mis planes (Alfa_Rutas): un objetivo "conseguir este objeto".
		self.Plan:SetShown(a.plan ~= nil)
		self.Plan.alClic = function()
			-- Mis planes avisa solo lo que agregó (con «Ver mi plan»); aquí solo si falló.
			local ok, r, msg = pcall(a.plan)
			if not ok or r == false then aviso(false, type(msg) == "string" and msg or L["Tu plan no pudo agregarlo."]) end
		end
		-- Un botón propio de la ficha (una guía: "Abrir el Legado del juego").
		-- Con ex.seguro, el clic lo hace el juego (K.SeguroDe: un botón seguro
		-- encima al pasar el ratón); alClic queda para cuando no se puede.
		local ex = a.extra
		self.Extra:SetShown(ex ~= nil)
		K.SeguroDe(self.Extra, ex)
		if ex then
			self.Extra:SetTexto(ex.texto or "")
			self.Extra:SetIcono(ex.icono or "ic-ventana")
			self.Extra.alClic = function() local ok, msg = ex.alClic() if ok == false then aviso(false, msg) end end
		end
	end
	function b:Acomodar(w)
		local x, y, alto = 0, 0, 0
		for _, bt in ipairs(self.lista) do
			if bt:IsShown() then
				bt:SetAncho(nil)
				local bw = bt:AnchoNatural()
				if x > 0 and x + bw > w then x, y = 0, y + K.ALTO.boton + ESP.s end
				bt:ClearAllPoints()
				bt:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
				x = x + bw + ESP.s
				alto = y + K.ALTO.boton
			end
		end
		self:SetHeight(max(1, alto))
		return alto
	end
	return b
end

-- Datos o estadísticas: pares en dos columnas.
local function bloqueDatos(pila)
	local b = CreateFrame("Frame", nil, pila)
	b.Seccion = K.Seccion(b, "")
	b.pares = {}
	function b:Set(d)
		self.Seccion:Set(d.titulo or L["Datos"])
		local filas = {}
		for _, x in ipairs(d.filas or {}) do if x then filas[#filas + 1] = x end end
		for i, x in ipairs(filas) do
			local p = self.pares[i]
			if not p then
				p = { E = K.Texto(self, "pequeno", "textoTenue"), V = K.Texto(self, "cuerpo", "texto") }
				p.V:SetJustifyH("RIGHT")
				self.pares[i] = p
			end
			K.Escribir(p.E, x[1] or "")
			K.Escribir(p.V, x[2] or "")
			p.E:Show()
			p.V:Show()
		end
		for i = #filas + 1, #self.pares do self.pares[i].E:Hide() self.pares[i].V:Hide() end
		self.alfaN = #filas
	end
	function b:Acomodar(w)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(w)
		local y = self.Seccion:Acomodar(w) + ESP.xs
		local cw = floor((w - ESP.l) / 2)
		for i = 1, self.alfaN do
			local p = self.pares[i]
			local colx = ((i - 1) % 2) * (cw + ESP.l)
			local fy = y + floor((i - 1) / 2) * 24
			p.E:ClearAllPoints()
			p.E:SetPoint("LEFT", self, "TOPLEFT", colx, -(fy + 11))
			K.Ajustar(p.E, floor(cw * 0.6))
			p.V:ClearAllPoints()
			p.V:SetPoint("RIGHT", self, "TOPLEFT", colx + cw, -(fy + 11))
			K.Ajustar(p.V, cw - K.num(p.E:GetWidth(), 0) - ESP.s)
		end
		local h = y + math.ceil(self.alfaN / 2) * 24
		self:SetHeight(h)
		return h
	end
	return b
end

-- Una fila de una sección.
local function filaFicha(padre)
	local r = CreateFrame("Button", nil, padre)
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	r.velo = K.Velo(r, K.CORTE.chico, 0.045)
	r.Objeto = K.IconoObjeto(r, 26)
	r.Objeto:EnableMouse(false)
	r.Objeto:SetPoint("LEFT", r, "LEFT", 4, 0)
	r.Baldosa = CreateFrame("Frame", nil, r)
	r.Baldosa:SetSize(26, 26)
	r.Baldosa:SetPoint("LEFT", r, "LEFT", 4, 0)
	r.Baldosa.caja = K.Caja(r.Baldosa, { fondo = "elevado", borde = "linea", corte = K.CORTE.chico })
	r.Glifo = K.Icono(r.Baldosa, "ic-mapa", 14, "acento")
	r.Glifo:SetPoint("CENTER")
	r.Titulo = K.Texto(r, "cuerpo", "texto")
	r.Texto = K.Texto(r, "pequeno", "textoTenue")
	r.Valor = K.Texto(r, "etiqueta", "textoSuave")
	r.Valor:SetJustifyH("RIGHT")
	r.Flecha = K.BotonIcono(r, "ic-flecha", function(self) flecha(self:GetParent().dato.punto) end, { tam = 22, icono = 12, ayuda = L["Poner la flecha aquí"] })
	r.Guia = K.BotonIcono(r, "ic-seguir", function(self)
		local g = self:GetParent().dato.guia
		if g then local ok, msg = F.Guiar(g.kind, g.id, g.fila) aviso(ok, msg) end
	end, { tam = 22, icono = 12, ayuda = L["Guíame aquí"] })
	-- 1.3.7: el cuadro sale con el ratón quieto un rato (Cuadro.lua), sin las
	-- comparaciones del equipo salvo con Mayús.
	r:SetScript("OnEnter", function(self)
		self.velo:Show()
		local d = self.dato
		if not d then return end
		if d.icono and d.icono.objeto then
			Cu.Entrar(self, { item = d.icono.objeto, ancla = "ANCHOR_LEFT" })
		elseif d.texto and d.texto ~= "" then
			Cu.Entrar(self, { titulo = d.titulo, texto = d.viaje and (d.texto .. M.SEP .. d.viaje) or d.texto })
		end
	end)
	r:SetScript("OnLeave", function(self)
		self.velo:Hide()
		Cu.Salir(self)
		K.OcultarInfo(self)
	end)
	r:SetScript("OnClick", function(self, boton)
		local d = self.dato
		if not d then return end
		-- Clic derecho en un objeto: su menú (comparar, guiar, la lista de compras, vincular).
		if boton == "RightButton" then
			local obj = d.icono and d.icono.objeto
			if obj then
				Cu.Menu("item", obj, { dueno = self, verFicha = function() navegar(d.ir or { kind = "item", id = obj }) end })
			elseif d.ir and d.ir.kind and d.ir.id and d.ir.kind ~= "instance" then
				Cu.Menu(d.ir.kind, d.ir.id, { dueno = self, verFicha = function() navegar(d.ir) end })
			end
			return
		end
		Cu.Cerrar()
		if d.icono and d.icono.objeto and IsModifiedClick and IsModifiedClick("CHATLINK") then F.Vincular("item", d.icono.objeto) return end
		if d.ir then navegar(d.ir) elseif d.punto then flecha(d.punto) end
	end)
	function r:Set(d)
		self.dato = d
		local ic = d.icono or {}
		local esObjeto = ic.objeto ~= nil
		self.Objeto:SetShown(esObjeto)
		self.Baldosa:SetShown(not esObjeto)
		if esObjeto then self.Objeto:SetObjeto({ id = ic.objeto, calidad = ic.calidad })
		else K.SetIcono(self.Glifo, ic.ic or "ic-mapa", select(2, K.Tono(ic.tono or "acento"))) end
		K.Escribir(self.Titulo, d.titulo or "?")
		if type(d.color) == "table" then self.Titulo:SetTextColor(d.color[1], d.color[2], d.color[3])
		else K.ColorTexto(self.Titulo, d.color or "texto") end
		local texto = d.texto
		if d.viaje then texto = texto and (texto .. M.SEP .. d.viaje) or d.viaje end
		K.Escribir(self.Texto, texto or "")
		K.Escribir(self.Valor, d.valor or "")
		self.Flecha:SetShown(d.punto ~= nil)
		self.Guia:SetShown(d.guia ~= nil)
		self:SetAlpha(d.tenue and 0.6 or 1)
		self:SetHeight((texto and texto ~= "") and 40 or 32)
	end
	function r:Acomodar(w)
		self:SetWidth(w)
		local der = 4
		for _, bt in ipairs({ self.Guia, self.Flecha }) do
			if bt:IsShown() then
				bt:ClearAllPoints()
				bt:SetPoint("RIGHT", self, "RIGHT", -der, 0)
				der = der + 22 + 2
			end
		end
		local vw = 0
		if (self.Valor:GetText() or "") ~= "" then
			vw = K.Ajustar(self.Valor, floor(w * 0.35)) + 4 + ESP.s
			self.Valor:SetWidth(vw - ESP.s)
			self.Valor:ClearAllPoints()
			self.Valor:SetPoint("RIGHT", self, "RIGHT", -der - 2, 0)
		end
		local x = 4 + 26 + ESP.s + 2
		local tw = max(40, w - x - der - vw - 4)
		local conTexto = (self.Texto:GetText() or "") ~= ""
		-- El título y el texto bajan de renglón si no caben (nunca "…"); la
		-- fila crece con ellos.
		local th = K.Parrafo(self.Titulo, tw)
		local xh = conTexto and K.Parrafo(self.Texto, tw) or 0
		local contenido = th + (conTexto and (2 + xh) or 0)
		local alto = max(32, contenido + 8)
		self:SetHeight(alto)
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -floor((alto - contenido) / 2))
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self.Titulo, "BOTTOMLEFT", 0, -2)
		self.Texto:SetShown(conTexto)
		return alto
	end
	return r
end

-- Una sección: su título con cuántas hay, las filas y "Ver todas".
-- 1.3.9: cada sección se pliega con un clic en su título (con su flecha); lo
-- plegado se recuerda por tipo de sección (todas las fichas) en tu cuenta.
local function plegadas()
	local d = N.Datos(M.ID)
	if type(d.plegadas) ~= "table" then d.plegadas = {} end
	return d.plegadas
end
V.Plegadas = plegadas

local function bloqueSeccion(pila)
	local b = CreateFrame("Frame", nil, pila)
	b.Seccion = K.Seccion(b, "")
	b.Seccion.Titulo:ClearAllPoints()
	b.Seccion.Titulo:SetPoint("LEFT", b.Seccion, "LEFT", 30, 0)
	b.Flecha = K.Icono(b.Seccion, "chevron-down", 12, "textoSuave")
	b.Flecha:SetPoint("LEFT", b.Seccion, "LEFT", 12, 0)
	b.Plegar = CreateFrame("Button", nil, b.Seccion)
	b.Plegar:SetPoint("TOPLEFT", b.Seccion, "TOPLEFT", 8, 0)
	b.Plegar:SetPoint("BOTTOMLEFT", b.Seccion, "BOTTOMLEFT", 8, 0)
	b.Plegar:SetWidth(120)
	b.Plegar:RegisterForClicks("LeftButtonUp")
	b.Plegar:SetScript("OnClick", function()
		local s, clave = b.alfaS, b.alfaClave
		if not s then return end
		local p = plegadas()
		p[s.clave] = not p[s.clave] or nil
		b:Set(s, clave)
		ui.lf:RehacerFicha()
	end)
	b.Plegar:SetScript("OnEnter", function(self) K.SetIcono(b.Flecha, b.alfaPlegada and "chevron-right" or "chevron-down", "texto") end)
	b.Plegar:SetScript("OnLeave", function(self) K.SetIcono(b.Flecha, b.alfaPlegada and "chevron-right" or "chevron-down", "textoSuave") end)
	K.ConInfo(b.Plegar, nil, L["Clic: plegar o abrir esta sección."])
	b.filas = {}
	b.Mas = K.Texto(b, "pequeno", "textoTenue")
	function b:Set(s, clave)
		self.alfaS, self.alfaClave = s, clave
		local plegada = s.clave ~= nil and plegadas()[s.clave] and true or false
		self.alfaPlegada = plegada
		K.SetIcono(self.Flecha, plegada and "chevron-right" or "chevron-down", "textoSuave")
		local abierta = est.abiertas[clave] and true or false
		local n = #s.filas
		local tope = plegada and 0 or (abierta and EXPANDIDAS or VISIBLES)
		local enlace
		if n > VISIBLES and not plegada then
			enlace = { texto = abierta and L["Ver menos"] or format(L["Ver todas (%d)"], n), alClic = function()
				est.abiertas[clave] = not est.abiertas[clave] or nil
				self:Set(s, clave)
				ui.lf:RehacerFicha()
			end }
		end
		self.Seccion:Set(s.titulo, { cuenta = s.cuenta or n, enlace = enlace })
		local m = min(n, tope)
		for i = 1, m do
			local r = self.filas[i] or filaFicha(self)
			self.filas[i] = r
			r:Set(s.filas[i])
			r:Show()
		end
		for i = m + 1, #self.filas do self.filas[i]:Hide() self.filas[i].dato = nil end
		self.alfaN = m
		K.Escribir(self.Mas, n > m and abierta and format(L["y %d más"], n - m) or "")
		self.Plegar:SetWidth(30 + math.min(260, K.AnchoTexto(self.Seccion.Titulo) + 40))
	end
	function b:Acomodar(w)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(w)
		local y = self.Seccion:Acomodar(w) + ESP.xs
		for i = 1, self.alfaN do
			local r = self.filas[i]
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			y = y + r:Acomodar(w) + 2
		end
		if (self.Mas:GetText() or "") ~= "" then
			self.Mas:ClearAllPoints()
			self.Mas:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -(y + 4))
			y = y + 22
		end
		self:SetHeight(y)
		return y
	end
	return b
end

-- Párrafos con su título (las guías y lo que dice el juego).
local function bloqueParrafos(pila)
	local b = CreateFrame("Frame", nil, pila)
	b.Seccion = K.Seccion(b, "")
	b.textos = {}
	function b:Set(p)
		self.Seccion:Set(p.titulo or "")
		local n = 0
		for _, t in ipairs(p.textos or {}) do
			if type(t) == "string" and t ~= "" then
				n = n + 1
				local fs = self.textos[n] or K.Texto(self, "texto", "textoSuave")
				self.textos[n] = fs
				K.Escribir(fs, t)
				fs:Show()
			end
		end
		for i = n + 1, #self.textos do self.textos[i]:Hide() end
		self.alfaN = n
	end
	function b:Acomodar(w)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(w)
		local y = self.Seccion:Acomodar(w) + ESP.s
		for i = 1, self.alfaN do
			local fs = self.textos[i]
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -y)
			y = y + K.Parrafo(fs, w - 8, 12) + ESP.s
		end
		self:SetHeight(y)
		return y
	end
	return b
end

-- Una nota corta (lo que se está preparando).
local function bloqueNota(pila)
	local b = CreateFrame("Frame", nil, pila)
	b.Icono = K.Icono(b, "ic-reloj", 14, "textoTenue")
	b.Icono:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -1)
	b.Texto = K.Texto(b, "nota", "textoTenue")
	b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", 22, 0)
	function b:Set(t) K.Escribir(self.Texto, t or "") end
	function b:Acomodar(w)
		local h = K.Parrafo(self.Texto, w - 22)
		self:SetHeight(max(16, h))
		return max(16, h)
	end
	return b
end

local function armarBloques(pila)
	if B.cab then return end
	B.cab = pila:Agregar(bloqueCabecera(pila))
	B.acc = pila:Agregar(bloqueAcciones(pila), { espacio = ESP.base })
	B.mejor = pila:Agregar(K.Tarjeta(pila, { variante = "normal" }))
	B.datos = pila:Agregar(bloqueDatos(pila))
	B.secciones = {}
	B.parrafos = {}
	B.nota = nil
	B.pila = pila
end

local function parrafoN(i)
	local b = B.parrafos[i]
	if b then return b end
	b = B.pila:Agregar(bloqueParrafos(B.pila), { espacio = ESP.l })
	B.parrafos[i] = b
	return b
end

-- El orden de la pila: cabecera, botones, lo mejor, datos, los párrafos de
-- arriba, las secciones, los demás párrafos y la nota.
local function ordenarPila(arriba, abajo)
	local bl = B.pila.bloques
	local entrada = {}
	for _, e in ipairs(bl) do entrada[e.b] = e end
	local orden = { B.cab, B.acc, B.mejor, B.datos }
	for _, b in ipairs(arriba) do orden[#orden + 1] = b end
	for _, b in ipairs(B.secciones) do orden[#orden + 1] = b end
	for _, b in ipairs(abajo) do orden[#orden + 1] = b end
	local usados, nuevo = {}, {}
	for _, b in ipairs(orden) do
		local e = entrada[b]
		if e and not usados[b] then usados[b] = true nuevo[#nuevo + 1] = e end
	end
	for _, e in ipairs(bl) do if not usados[e.b] and e.b ~= B.nota then usados[e.b] = true nuevo[#nuevo + 1] = e end end
	if B.nota and entrada[B.nota] then nuevo[#nuevo + 1] = entrada[B.nota] end
	for k = #bl, 1, -1 do bl[k] = nil end
	for k, e in ipairs(nuevo) do bl[k] = e end
end

local function seccionN(i)
	local s = B.secciones[i]
	if s then return s end
	s = B.pila:Agregar(bloqueSeccion(B.pila), { espacio = ESP.l })
	B.secciones[i] = s
	return s
end

local function notaBloque()
	if not B.nota then
		-- La nota va al final: se agrega después de las secciones que haya.
		B.nota = B.pila:Agregar(bloqueNota(B.pila))
	end
	return B.nota
end

local function pintarFicha(f, conVolver)
	B.cab:Set(f, conVolver)
	B.acc:Set(f)
	local hayAcciones = false
	for _, bt in ipairs(B.acc.lista) do if bt:IsShown() then hayAcciones = true end end
	K.Mostrar(B.acc, hayAcciones)
	if f.mejor then
		local m = f.mejor
		B.mejor:Set({ icono = m.icono or "ic-seguir", tono = "acento", sobre = M.Mayus(m.sobre), titulo = m.titulo, texto = m.texto,
			alClic = (m.ir and function() navegar(m.ir) end) or (m.punto and function() flecha(m.punto) end) or nil,
			ayuda = m.ir and L["Abre su ficha."] or (m.punto and L["Pone la flecha ahí."] or nil) })
	end
	K.Mostrar(B.mejor, f.mejor ~= nil)
	if f.datos and #f.datos.filas > 0 then B.datos:Set(f.datos) end
	K.Mostrar(B.datos, f.datos ~= nil and #f.datos.filas > 0)
	local clave = f.kind .. ":" .. tostring(f.id)
	for i, s in ipairs(f.secciones) do
		local b = seccionN(i)
		b:Set(s, clave .. ":" .. s.clave)
		K.Mostrar(b, true)
	end
	for i = #f.secciones + 1, #B.secciones do K.Mostrar(B.secciones[i], false) end
	local arriba, abajo = {}, {}
	local ps = f.parrafos or {}
	for i, p in ipairs(ps) do
		local b = parrafoN(i)
		b:Set(p)
		K.Mostrar(b, true)
		-- Lo que explica algo va antes de sus listas; en una guía, solo el primero.
		local alto = p.arriba
		if alto == nil then alto = (f.kind ~= "guia") or i == 1 end
		if alto then arriba[#arriba + 1] = b else abajo[#abajo + 1] = b end
	end
	for i = #ps + 1, #B.parrafos do K.Mostrar(B.parrafos[i], false) end
	if f.nota then
		local nb = notaBloque()
		nb:Set(f.nota)
		K.Mostrar(nb, true)
	elseif B.nota then
		K.Mostrar(B.nota, false)
	end
	ordenarPila(arriba, abajo)
	if V.RevisarGuiaFija then K.Despues(0.05, V.RevisarGuiaFija) end
end

-- 1.3.9: el «Guíame» fijo, solo cuando los botones de la ficha quedaron arriba.
function V.RevisarGuiaFija()
	local b = ui.guiaFija
	if not b then return end
	local a = est.ficha and est.ficha.acciones
	local desp = ui.lf and ui.lf.FichaDesp
	local bajo = 0
	if desp and desp:IsShown() then bajo = K.num(desp:GetVerticalScroll(), 0) end
	local tope = 0
	if B.cab and B.acc then tope = K.num(B.cab:GetHeight(), 0) + K.num(B.acc:GetHeight(), 0) + ESP.base end
	b:SetShown(a ~= nil and a.guiar ~= nil and bajo > tope and tope > 0)
end

-- Lo que la ListaFicha llama al elegir: un número (una fila del catálogo) o
-- { kind, id, nav, atras } (desde otra ficha o desde fuera).
local function llenarFicha(pila, dato)
	armarBloques(pila)
	local kind, id
	if type(dato) == "number" then
		local c = Cat.Col(est.tipo)
		if not c then return end
		kind, id = Cat.Kind(c, dato), c.id[dato]
		est.pila = {}
	elseif type(dato) == "table" then
		kind, id = dato.kind, dato.id
		if not dato.nav then est.pila = {} end
	end
	if not (kind and id) then return end
	local ok, f = pcall(F.Construir, kind, id)
	if not ok then
		if geterrorhandler then geterrorhandler()(f) end
		f = nil
	end
	if not f then
		f = { kind = kind, id = id, titulo = M.Nombre(kind, id), sobre = L["Sin datos"], insignias = {}, secciones = {}, acciones = {},
			icono = { ic = "ic-info", tono = "neutro" }, nota = L["Alfa no tiene datos de esto todavía."] }
	end
	est.actual = { kind = kind, id = id }
	est.ficha = f
	pintarFicha(f, #est.pila > 0)
	recordar(kind, id)
end

-- Rehace la ficha a la vista (algo terminó de prepararse), sin moverla.
rehacerFichaActual = function()
	if not (v and v:IsShown() and est.actual and B.cab) then return end
	local a = est.actual
	local ok, f = pcall(F.Construir, a.kind, a.id)
	if not (ok and f) then return end
	est.ficha = f
	pintarFicha(f, #est.pila > 0)
	ui.lf:RehacerFicha()
end

---------------------------------------------------------------------------
-- La lista
---------------------------------------------------------------------------
local function lineaObjeto(c, i, k)
	-- En Monturas y Mascotas: cómo se consigue, el precio y si ya la tienes.
	if c.src and M.Col then return M.Col.Linea(c, i, k) end
	local partes = {}
	if k == "mount" then partes[1] = L["Montura"]
	elseif k == "pet" then partes[1] = L["Mascota"]
	elseif c.f then
		local cls, sb, iv = Cat.Clase(i), Cat.Subtipo(i), Cat.Inv(i)
		if cls >= 0 then
			partes[#partes + 1] = ((cls == 2 or cls == 4 or cls == 9) and Cat.NombreSubtipo(cls, sb)) or Cat.NombreTipo(cls)
		end
		local ranura = iv > 0 and Cat.NombreRanura(iv)
		if ranura and ranura ~= partes[#partes] then partes[#partes + 1] = ranura end
		local rq = Cat.Req(i)
		if rq and rq > 1 then partes[#partes + 1] = format(L["Nv %d"], rq) end
	elseif k == "recipe" then
		partes[1] = L["Receta"]
	end
	local _, st = Cat.Calidad(c, i)
	if st == "r" then partes[#partes + 1] = L["ya no se consigue"] end
	return table.concat(partes, M.SEP)
end

local function lineaDe(kind, id)
	local C = M.CodexListo()
	if not C then return "" end
	if kind == "npc" or kind == "rare" then
		local n = C.Npc(id)
		if not n then return "" end
		local s = n.spawns and n.spawns[1]
		local inst = n.instance and C.Instance(n.instance)
		return F.Unir(n.level and format(L["Nv %d"], n.level) or nil, s and M.Zona(s.map) or (inst and inst.name) or nil,
			n.elite and L["élite"] or nil, M.NombreBando(n.faction))
	elseif kind == "treasure" then
		local o = C.Object(id)
		local s = o and o.spawns and o.spawns[1]
		return F.Unir(L["Tesoro"], s and M.Zona(s.map) or nil)
	elseif kind == "quest" then
		local q = C.Quest(id)
		if not q then return "" end
		return F.Unir(q.level and format(L["Nv %d"], q.level) or nil, q.zone and M.Zona(q.zone) or nil,
			A.Compat.IsQuestCompleted(id) and L["hecha"] or nil)
	elseif kind == "zone" then
		local Mp = A.Maps
		local lo, hi
		if Mp and Mp.GetZoneLevels then lo, hi = Mp.GetZoneLevels(id) end
		return lo and (hi and hi ~= lo and format(L["Niveles %d–%d"], lo, hi) or format(L["Nivel %d"], lo)) or ""
	end
	return ""
end

local function crearFila(f)
	f.Objeto = K.IconoObjeto(f, 28)
	f.Objeto:EnableMouse(false)
	f.Objeto:SetPoint("LEFT", f, "LEFT", 10, 0)
	f.Baldosa = CreateFrame("Frame", nil, f)
	f.Baldosa:SetSize(28, 28)
	f.Baldosa:SetPoint("LEFT", f, "LEFT", 10, 0)
	f.Baldosa.caja = K.Caja(f.Baldosa, { fondo = "elevado", borde = "linea", corte = K.CORTE.chico })
	f.Glifo = K.Icono(f.Baldosa, "ic-bolsas", 16, "acento")
	f.Glifo:SetPoint("CENTER")
	f.Nombre = K.Texto(f, "cuerpo", "texto")
	f.Nombre:SetPoint("TOPLEFT", f, "TOPLEFT", 48, -5)
	f.Nombre:SetPoint("RIGHT", f, "RIGHT", -10, 0)
	f.Linea = K.Texto(f, "pequeno", "textoTenue")
	f.Linea:SetPoint("TOPLEFT", f.Nombre, "BOTTOMLEFT", 0, -2)
	f.Linea:SetPoint("RIGHT", f, "RIGHT", -10, 0)
	f.pildoras = {} -- 1.3.8: cómo se consigue y la facción (Origen.lua), a la derecha
	f:HookScript("OnLeave", function(self) Cu.Salir(self) end)
end

-- 1.3.8: hasta 3 etiquetas a la derecha de la fila, las que quepan sin cortar
-- el nombre ni su línea (y nunca dejándoles menos de TEXTO_MIN).
local TEXTO_MIN = 150
local function pildorasFila(f, lista)
	lista = lista or {}
	local ancho = K.num(f:GetWidth(), 0)
	if ancho <= 0 then ancho = 320 end
	-- El nombre y su línea nunca se cortan: las etiquetas usan lo que sobra.
	local texto = max(TEXTO_MIN, K.num(K.AnchoTexto(f.Nombre), 0), K.num(K.AnchoTexto(f.Linea), 0))
	local libre = ancho - 48 - 10 - 8 - texto
	-- Las que caben, por importancia (pri: la primera de cómo se consigue, la
	-- facción, lo demás); se ven en su orden, la más útil a la izquierda.
	local orden = {}
	for k in ipairs(lista) do orden[k] = k end
	table.sort(orden, function(x, y)
		local px, py = lista[x].pri or x, lista[y].pri or y
		if px ~= py then return px < py end
		return x < y
	end)
	local elegida, anchoDe, total, cuantas = {}, {}, 0, 0
	for _, k in ipairs(orden) do
		local x = lista[k]
		local p = f.pildoras[k] or K.Insignia(f, "", "neutro")
		f.pildoras[k] = p
		local w = p:Set(x[1], x[2], x[3])
		local mas = (cuantas > 0 and 4 or 0) + w
		if total + mas <= libre then
			elegida[k], anchoDe[k], total, cuantas = true, w, total + mas, cuantas + 1
		end
	end
	local visibles = {}
	for k = 1, #f.pildoras do
		if elegida[k] then visibles[#visibles + 1] = k else f.pildoras[k]:Hide() end
	end
	local n = #visibles
	-- Ancladas a la derecha (si la fila cambia de ancho, siguen en su lugar).
	local der = 10
	for j = n, 1, -1 do
		local k = visibles[j]
		local p = f.pildoras[k]
		p:ClearAllPoints()
		p:SetPoint("RIGHT", f, "RIGHT", -der, 0)
		p:Show()
		der = der + anchoDe[k] + 4
	end
	local fin = n > 0 and (10 + total + 8) or 10
	f.Nombre:SetPoint("RIGHT", f, "RIGHT", -fin, 0)
	f.Linea:SetPoint("RIGHT", f, "RIGHT", -fin, 0)
end

local ICONO_TIPO = { npc = { "ic-personajes", "acento" }, rare = { "ic-raros", "raro" }, treasure = { "ic-raros", "oro" },
	quest = { "ic-misiones", "oro" }, zone = { "ic-mapa", "acento" }, mountspell = { "ic-huella", "clase" } }

local function pintarFila(f, i)
	local c = Cat.Col(est.tipo)
	if not c then return end
	local kind, id = Cat.Kind(c, i), c.id[i]
	local nombre = M.Nombre(kind, id)
	K.Escribir(f.Nombre, nombre)
	-- 1.3.8: un PNJ de la otra facción, atenuado (va al final de la lista).
	local mio = est.tipo == "pnj" and M.MiBando and M.MiBando()
	local suyo = mio and Cat.BandoPnj(id)
	f:SetAlpha((suyo and suyo ~= mio) and 0.6 or 1)
	if M.ES_OBJETO[kind] then
		f.Objeto:Show()
		f.Baldosa:Hide()
		local q = Cat.Calidad(c, i)
		f.Objeto:SetObjeto({ id = id, calidad = q })
		local r, g, b = M.ColorCalidad(q)
		if r then f.Nombre:SetTextColor(r, g, b) else K.ColorTexto(f.Nombre, "objeto") end
		K.Escribir(f.Linea, lineaObjeto(c, i, kind))
		pildorasFila(f, est.tipo == "objeto" and M.Origen and M.Origen.Etiquetas(id, 3) or nil)
	else
		f.Objeto:Hide()
		f.Baldosa:Show()
		pildorasFila(f, nil)
		local ic = ICONO_TIPO[kind] or { "ic-enciclopedia", "acento" }
		K.SetIcono(f.Glifo, ic[1], select(2, K.Tono(ic[2])))
		if kind == "mountspell" then
			K.ColorTexto(f.Nombre, "texto")
			K.Escribir(f.Linea, M.Col.Linea(c, i, kind))
		else
			K.ColorTexto(f.Nombre, kind == "quest" and "mision" or (kind == "zone" and "lugar" or "pnj"))
			K.Escribir(f.Linea, lineaDe(kind, id))
		end
	end
end

-- 1.3.7: objetos, monturas y mascotas igual que en la ficha: el cuadro tras un
-- rato quieto (enciclopedia.cuadro) y sin comparar salvo con Mayús.
local function alEntrarFila(f, i)
	local c = Cat.Col(est.tipo)
	if not (c and i) then return end
	local kind = Cat.Kind(c, i)
	if M.ES_OBJETO[kind] then
		Cu.Entrar(f, { item = c.id[i] })
	elseif kind == "mountspell" then
		Cu.Entrar(f, { spell = c.id[i] })
	end
end

-- La fila bajo el ratón (para anclar la comparación a ella).
local function filaSobre()
	for _, f in pairs(ui.lf and ui.lf.Lista.filas or {}) do
		if f.alfaSobre and f:IsShown() then return f end
	end
	return nil
end

local function alClicFila(i, pos, boton)
	local c = Cat.Col(est.tipo)
	if not (c and i) then return end
	local kind = Cat.Kind(c, i)
	if boton == "RightButton" then
		local inv = c.f and M.ES_OBJETO[kind] and Cat.Inv(i) or nil
		Cu.Menu(kind, c.id[i], { dueno = filaSobre(), inv = inv,
			verFicha = function() if pos then ui.lf:Elegir(pos) end end })
		return
	end
	Cu.Cerrar()
	if M.ES_OBJETO[kind] and IsModifiedClick and IsModifiedClick("CHATLINK") then F.Vincular("item", c.id[i]) end
end

---------------------------------------------------------------------------
-- Buscar y filtrar
---------------------------------------------------------------------------
local VACIO_SIN = { lobo = "vacio", titulo = L["No encontramos nada"], texto = L["Prueba con otra palabra, en español o en inglés, o quita un filtro."] }
local VACIO_PREP = { lobo = "atento", titulo = L["Preparando la enciclopedia…"], texto = L["Juntando todo lo del juego. Es solo la primera vez que la abres."] }

local filtrar
local reloj -- el temporizador del avance mientras algo se prepara

local function avanceTexto(nombre)
	local p = Cat.Avance(nombre)
	return p and format("%d %%", floor(p * 100)) or ""
end

local PREPARA = { facetas = L["los tipos"], registros = L["los niveles"], misiones = L["las misiones"], raros = L["los raros"], catalogo = L["el catálogo"],
	origenes = L["cómo se consigue cada objeto"] }

local function cuentaTexto(n)
	local c = Cat.Col(est.tipo)
	if not c then return format(L["Preparando %s… %s"], PREPARA.catalogo, avanceTexto("cat:" .. est.tipo)) end
	local base = n == 1 and L["1 resultado"] or format(L["%s resultados"], M.Miles(n))
	if est.aprox and n > 0 then base = format(L["%s parecidos a lo que escribiste"], M.Miles(n)) end
	if est.pend then
		local que = PREPARA[est.pend] or est.pend
		local pct = (est.pend == "facetas" or est.pend == "registros") and avanceTexto(est.pend) or ""
		if est.pend == "origenes" and M.Origen.avance then pct = format("%d %%", floor(M.Origen.avance * 100)) end
		base = base .. M.SEP .. format(L["preparando %s para filtrar %s"], que, pct)
	end
	return base
end

local function vigilarAvance()
	if reloj then return end
	reloj = N.Ticker("enciclopedia.avance", 0.3, function() -- por A.Safe: un error, una vez (1.2.0)
		if not (v and v:IsShown()) then reloj:Cancel() reloj = nil return end
		K.Escribir(ui.lf.Cuenta, cuentaTexto(#(est.resultados[est.tipo] or {})))
		local ocupado = false
		for _ in pairs(M.tareas) do ocupado = true end
		if not ocupado then reloj:Cancel() reloj = nil end
	end)
end

local function pedirPreparacion(pend)
	if pend == "facetas" or pend == "registros" then Cat.PrepararFacetas()
	elseif pend == "misiones" then I.PrepararMisiones()
	elseif pend == "raros" then I.PrepararRaros()
	elseif pend == "origenes" then M.Origen.Preparar() end
	vigilarAvance()
end

local function filtrosActivos(tipo)
	for _, x in pairs(est.filtros[tipo] or {}) do if x then return true end end
	return false
end

-- Las cuentas de cada tipo en los segmentos, mientras buscas.
local function actualizarCuentas()
	local cuentas = (est.texto ~= "") and Cat.Contar(est.texto) or nil
	local ops = {}
	for _, t in ipairs(M.TIPOS) do
		ops[#ops + 1] = { valor = t.clave, texto = t.texto, icono = t.icono, cuenta = cuentas and (cuentas[t.clave] or 0) > 0 and cuentas[t.clave] or nil }
	end
	ui.tipos:SetOpciones(ops)
	ui.tipos:SetValor(est.tipo)
	if V.acomodarArriba then V.acomodarArriba() end
	return cuentas
end

local acomodar

filtrar = function(elegir)
	if not (v and v:IsShown()) then return end
	local tipo = est.tipo
	if not Cat.Listo(tipo) then
		ui.lf.Lista.Vacio:Set(VACIO_PREP)
		ui.lf:SetDatos({})
		K.Escribir(ui.lf.Cuenta, cuentaTexto(0))
		vigilarAvance()
		Cat.Pedir(tipo, function(ok, motivo)
			if ok then filtrar(elegir) else V.MostrarMotivo(motivo) end
		end)
		return
	end
	local res, pend = Cat.Buscar(tipo, est.texto, est.filtros[tipo], est.resultados[tipo])
	est.resultados[tipo], est.pend = res, pend
	if pend then pedirPreparacion(pend) end
	local cuentas = actualizarCuentas()
	-- 1.3.9: sin nada en ningún tipo, lo que se parece (un error de dedo, una letra de más).
	est.aprox = nil
	if #res == 0 and est.texto ~= "" and Cat.Parecidos then
		local hay = false
		for _, n in pairs(cuentas or {}) do if n > 0 then hay = true end end
		if not hay then
			local _, n = Cat.Parecidos(tipo, est.texto, est.filtros[tipo], res)
			if n > 0 then est.aprox = true end
		end
	end
	-- Sin nada en este tipo, pero sí en otro: allá vamos.
	if #res == 0 and cuentas and not filtrosActivos(tipo) and not elegir then
		local mejor, n = nil, 0
		for _, t in ipairs(M.TIPOS) do
			local x = cuentas[t.clave] or 0
			if x > n then mejor, n = t.clave, x end
		end
		if mejor and mejor ~= tipo then return V.SetTipo(mejor) end
	end
	ui.lf.Lista.Vacio:Set(VACIO_SIN)
	if elegir then
		ui.lf:SetDatos(res, true)
		local c = Cat.Col(tipo)
		for k, i in ipairs(res) do
			if c.id[i] == elegir.id and (not elegir.kind or Cat.Kind(c, i) == elegir.kind) then
				ui.lf:Elegir(k)
				K.Escribir(ui.lf.Cuenta, cuentaTexto(#res))
				return
			end
		end
		ui.lf.Lista.alfaElegida = nil
		ui.lf.Lista:Refrescar()
		ui.lf:MostrarFicha({ kind = elegir.kind, id = elegir.id })
	else
		ui.lf:SetDatos(res)
	end
	K.Escribir(ui.lf.Cuenta, cuentaTexto(#res))
end
V.Filtrar = filtrar

---------------------------------------------------------------------------
-- Los filtros de cada tipo
---------------------------------------------------------------------------
local barras = {} -- tipo -> { controles = { ... }, Acomodar }

local function desplegable(tipo, clave, opciones, ancho, alCambiar)
	return K.Desplegable(ui.barra, { opciones = opciones, valor = est.filtros[tipo][clave] or false, ancho = ancho,
		alCambiar = function(val)
			est.filtros[tipo][clave] = val or nil
			if alCambiar then alCambiar(val) end
			acomodar()
			filtrar()
		end })
end

local function alternar(tipo, clave, texto, ayuda)
	local b = K.Boton(ui.barra, texto, nil, { tipo = "secundario", icono = "ic-filtro", ayuda = ayuda })
	local function pintar()
		local on = est.filtros[tipo][clave] and true or false
		b:SetTipo(on and "acento" or "secundario")
		b:SetIcono(on and "ic-exito" or "ic-filtro")
	end
	b.alClic = function()
		est.filtros[tipo][clave] = not est.filtros[tipo][clave] or nil
		pintar()
		acomodar()
		filtrar()
	end
	b.Pintar = pintar
	pintar()
	return b
end

local function quitarFiltros(tipo)
	local b = K.Boton(ui.barra, L["Quitar filtros"], function()
		est.filtros[tipo] = {}
		for _, c in ipairs(barras[tipo].controles) do
			if c.SetValor then c:SetValor(false) end
			if c.Pintar then c:Pintar() end
		end
		if barras[tipo].alQuitar then barras[tipo].alQuitar() end
		acomodar()
		filtrar()
	end, { tipo = "fantasma", tam = "chico", icono = "ic-cerrar" })
	return b
end

local function armarBarra(tipo)
	if barras[tipo] ~= nil then return barras[tipo] end
	local bar = { controles = {} }
	local cs = bar.controles
	if tipo == "objeto" then
		local sub
		cs[1] = desplegable(tipo, "tipo", Cat.OpcionesTipo(), 132, function()
			est.filtros.objeto.sub = nil
			local ops = Cat.OpcionesSubtipo(est.filtros.objeto.tipo)
			sub.alfaVisible = ops ~= nil
			if ops then sub:SetOpciones(ops) sub:SetValor(false) end
		end)
		sub = desplegable(tipo, "sub", { { valor = false, texto = L["Todo subtipo"] } }, 150)
		sub.alfaVisible = false
		cs[2] = sub
		cs[3] = desplegable(tipo, "calidad", Cat.OpcionesCalidad(), 124)
		cs[4] = desplegable(tipo, "nivel", Cat.NIVELES, 116)
		cs[5] = desplegable(tipo, "ranura", Cat.OpcionesRanura(), 136)
		cs[6] = alternar(tipo, "usable", L["Puedo usar"], L["Solo lo que tu personaje puede usar hoy: clase, armadura, armas, nivel y profesión."])
		-- 1.3.8: cómo se consigue (con «Más probable primero» para lo que sueltan) y de qué facción (Origen.lua).
		local O = M.Origen
		local probable
		cs[7] = desplegable(tipo, "origen", O.ORIGENES, 150, function(val)
			probable.alfaVisible = val == "suelta"
			if val ~= "suelta" and est.filtros.objeto.probable then
				est.filtros.objeto.probable = nil
				probable:Pintar()
			end
		end)
		probable = alternar(tipo, "probable", L["Más probable primero"], L["Los que caen más seguido van arriba: la mejor probabilidad de cada objeto, de más a menos."])
		probable.alfaVisible = est.filtros.objeto.origen == "suelta"
		cs[8] = probable
		cs[9] = desplegable(tipo, "bando", O.BANDOS, 130)
		bar.alQuitar = function() sub.alfaVisible = false probable.alfaVisible = false end
		-- Cuando las facetas están listas, los desplegables muestran solo lo que hay.
		bar.Refrescar = function()
			cs[1]:SetOpciones(Cat.OpcionesTipo())
			cs[5]:SetOpciones(Cat.OpcionesRanura())
			local ops = est.filtros.objeto.tipo and Cat.OpcionesSubtipo(est.filtros.objeto.tipo)
			sub.alfaVisible = ops ~= nil
			if ops then sub:SetOpciones(ops) end
		end
	elseif tipo == "montura" or tipo == "mascota" then
		local Co = M.Col
		cs[1] = desplegable(tipo, "estado", Co.ESTADOS, 164)
		cs[2] = desplegable(tipo, "mia", Co.MIAS, 150)
		local fuentes = Co.OpcionesFuente()
		if tipo == "mascota" then
			-- Las mascotas no son de clase ni de JcJ.
			local solo = {}
			for _, o in ipairs(fuentes) do if o.valor ~= "clase" and o.valor ~= "pvp" then solo[#solo + 1] = o end end
			fuentes = solo
		end
		cs[3] = desplegable(tipo, "fuente", fuentes, 140)
		cs[4] = desplegable(tipo, "bando", Co.BANDOS, 140)
		if tipo == "montura" then
			cs[5] = K.Boton(ui.barra, L["Mi primera montura"], function() V.Abrir({ kind = "guia", id = "montura" }) end,
				{ tipo = "acento", icono = "ic-huella", ayuda = L["Qué necesitas a tu nivel: equitación, oro y a quién ir."] })
		end
	elseif tipo == "pnj" then
		local ops = { { valor = false, texto = L["Todo oficio"] } }
		for _, r in ipairs(M.ROLES) do ops[#ops + 1] = { valor = r.clave, texto = r.texto } end
		local clase = A.Compat.GetPlayerInfo().class
		if clase then ops[#ops + 1] = { valor = "class:" .. clase, texto = format(L["Instructores de %s"], M.NombreClase(clase)) } end
		cs[1] = desplegable(tipo, "rol", ops, 220)
		cs[2] = desplegable(tipo, "bando", Cat.BANDOS_PNJ, 180) -- 1.3.8: lo de tu facción primero
	elseif tipo == "mision" then
		cs[1] = desplegable(tipo, "nivel", Cat.NIVELES, 150)
		cs[2] = alternar(tipo, "paraMi", L["Para mí"], L["Solo las que puedes tomar: tu bando, raza, clase y nivel, y que no hayas hecho."])
	elseif tipo == "raro" then
		cs[1] = K.Segmentos(ui.barra, { estilo = "pildoras", valor = est.filtros.raro.clase or "todo",
			opciones = { { valor = "todo", texto = L["Todos"] }, { valor = "rare", texto = L["Raros"] }, { valor = "treasure", texto = L["Tesoros"] } },
			alCambiar = function(val)
				est.filtros.raro.clase = val ~= "todo" and val or nil
				acomodar()
				filtrar()
			end })
		local seg = cs[1]
		seg.SetValor0 = seg.SetValor
		function seg:SetValor(val) self:SetValor0(val or "todo") end
		cs[2] = alternar(tipo, "miZona", L["En mi zona"], L["Solo los de la zona donde estás."])
	else
		barras[tipo] = false
		return false
	end
	bar.Quitar = quitarFiltros(tipo)
	for _, c in ipairs(cs) do c:Hide() end
	bar.Quitar:Hide()
	barras[tipo] = bar
	return bar
end

-- Coloca los controles del tipo de ahora; -> alto de la barra (0 sin filtros)
local function acomodarBarra(ancho)
	for t, bar in pairs(barras) do
		if bar and t ~= est.tipo then
			for _, c in ipairs(bar.controles) do c:Hide() end
			bar.Quitar:Hide()
		end
	end
	local bar = armarBarra(est.tipo)
	if not bar then ui.barra:Hide() return 0 end
	ui.barra:Show()
	local x, y, alto = 0, 0, K.ALTO.control
	local function poner(c, w)
		if x > 0 and x + w > ancho then x, y = 0, y + K.ALTO.control + ESP.s end
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", ui.barra, "TOPLEFT", x, -y - floor((K.ALTO.control - K.num(c:GetHeight(), K.ALTO.control)) / 2))
		c:Show()
		x = x + w + ESP.s
		alto = y + K.ALTO.control
	end
	for _, c in ipairs(bar.controles) do
		if c.alfaVisible == false then
			c:Hide()
		else
			local w
			if c.SetValor0 then
				local _, usado = c:Acomodar(ancho)
				w = usado
			elseif c.AnchoNatural then
				c:SetAncho(nil)
				w = c:AnchoNatural()
			else
				w = K.num(c:GetWidth(), 140)
			end
			poner(c, w)
		end
	end
	if filtrosActivos(est.tipo) then
		bar.Quitar:SetAncho(nil)
		poner(bar.Quitar, bar.Quitar:AnchoNatural())
	else
		bar.Quitar:Hide()
	end
	ui.barra:SetSize(ancho, alto)
	return alto
end

-- La fila de arriba: el buscador ocupa lo que dejan los tipos.
local function acomodarArriba()
	if not v then return end
	local w = v:AnchoCuerpo()
	local x, y = v.margen, ESP.base
	local _, sw = ui.tipos:Acomodar(w)
	ui.tipos:ClearAllPoints()
	ui.tipos:SetPoint("TOPRIGHT", v.Cuerpo, "TOPLEFT", x + w, -y)
	ui.buscador:ClearAllPoints()
	ui.buscador:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
	ui.buscador:SetWidth(max(200, w - sw - ESP.base))
end
V.acomodarArriba = acomodarArriba

acomodar = function()
	if not v then return end
	local w = v:AnchoCuerpo()
	local x = v.margen
	local y = ESP.base
	acomodarArriba()
	y = y + K.ALTO.control + ESP.m
	-- Con el aviso de por qué no abre (V.MostrarMotivo) no hay filtros a la vista.
	local hb = 0
	if not ui.estado:IsShown() then hb = acomodarBarra(w) end
	if hb > 0 then
		ui.barra:ClearAllPoints()
		ui.barra:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
		y = y + hb + ESP.m
	end
	local alto = v:AltoCuerpo() - y - ESP.base
	ui.zona:ClearAllPoints()
	ui.zona:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
	ui.zona:SetSize(w, alto)
	ui.lf:Acomodar(w, alto)
	if ui.estado:IsShown() then
		local vh = ui.estado:Acomodar(min(w, 520))
		ui.estado:ClearAllPoints()
		ui.estado:SetPoint("TOP", v.Cuerpo, "TOP", 0, -max(ESP.xl, floor((v:AltoCuerpo() - vh) / 2.5)))
	end
end

function V.SetTipo(tipo, quieto)
	if not M.TIPO[tipo] then return end
	est.tipo = tipo
	if ui.tipos then ui.tipos:SetValor(tipo) end
	if not v then return end
	acomodar()
	if not quieto then filtrar() end
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
-- 1.3.6: si faltan o están apagados los datos, «Revisar Alfa» (el diagnóstico
-- de Alfa_Bienvenida) en vez de «Intentar otra vez», que no lo arregla.
local function revisarAlfa()
	local B = rawget(_G, "AlfaBienvenida")
	return type(B) == "table" and B.Diagnostico or nil
end
function V.MostrarMotivo(motivo)
	if not v then return end
	local accion
	if motivo ~= "combat" then
		local diag = motivo ~= "loading" and revisarAlfa()
		if diag then
			accion = { texto = L["Revisar Alfa"], icono = "ic-buscar", alClic = function() diag() end }
		else
			accion = { texto = L["Intentar otra vez"], icono = "ic-seguir", alClic = function() V.Abrir() end }
		end
	end
	ui.estado:Set({ lobo = "dormido", titulo = L["La enciclopedia no puede abrir todavía"], texto = M.MotivoTexto(motivo),
		accion = accion })
	ui.estado:Show()
	ui.zona:Hide()
	ui.buscador:Hide()
	ui.tipos:Hide()
	ui.barra:Hide()
	est.esperaCombate = motivo == "combat"
	acomodar()
end

local function ocultarMotivo()
	ui.estado:Hide()
	ui.zona:Show()
	ui.buscador:Show()
	ui.tipos:Show()
	est.esperaCombate = nil
end

-- 1.3.7: el tamaño, guardado por cuenta, y lo que cabe en tu pantalla.
local function tamPantalla()
	local W = K.num(UIParent and UIParent:GetWidth(), 1920)
	local H = K.num(UIParent and UIParent:GetHeight(), 1080)
	return W - 40, H - 60
end
function V.Tamano()
	local d = N.Datos(M.ID)
	local t = type(d.tam) == "table" and d.tam or {}
	local pw, ph = tamPantalla()
	local w = min(max(ANCHO_MIN, tonumber(t[1]) or ANCHO), max(ANCHO_MIN, pw))
	local h = min(max(ALTO_MIN, tonumber(t[2]) or ALTO), max(ALTO_MIN, ph))
	return floor(w), floor(h)
end
function V.Redimensionar(w, h, guardar)
	if not v then return end
	local pw, ph = tamPantalla()
	w = floor(min(max(ANCHO_MIN, w or ANCHO), max(ANCHO_MIN, pw)))
	h = floor(min(max(ALTO_MIN, h or ALTO), max(ALTO_MIN, ph)))
	v:SetTamano(w, h)
	if guardar then N.Datos(M.ID).tam = { w, h } end
end
function V.ArmarAsa()
	v:SetResizable(true)
	if v.SetResizeBounds then v:SetResizeBounds(ANCHO_MIN, ALTO_MIN) elseif v.SetMinResize then v:SetMinResize(ANCHO_MIN, ALTO_MIN) end
	local asa = CreateFrame("Button", nil, v)
	asa:SetSize(16, 16)
	asa:SetFrameLevel(v:GetFrameLevel() + 40)
	asa:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", -4, 4)
	asa.t = K.Icono(asa, "resize", 16, "textoTenue", "OVERLAY")
	asa.t:SetAllPoints()
	asa:SetScript("OnEnter", function(self) K.SetIcono(self.t, "resize", "texto") end)
	asa:SetScript("OnLeave", function(self) K.SetIcono(self.t, "resize", "textoTenue") end)
	asa:SetScript("OnMouseDown", function() if v.StartSizing then v:StartSizing("BOTTOMRIGHT") end end)
	asa:SetScript("OnMouseUp", function()
		v:StopMovingOrSizing()
		V.Redimensionar(v:GetWidth(), v:GetHeight(), true)
	end)
	K.ConInfo(asa, L["Cambiar el tamaño"], L["Arrastra la esquina para agrandar o achicar la enciclopedia."])
	-- 1.3.7: mientras se arrastra, una sola vez al pararse (no en cada cuadro).
	v:HookScript("OnSizeChanged", function()
		if not (v.alAcomodar and v:IsShown()) then return end
		if N.Una then
			N.Una("enciclopedia.acomodar", 0.1, function() if v:IsShown() then acomodar() end end)
		else
			acomodar()
		end
	end)
	v.Asa = asa
end

local function crear()

	v = K.Ventana({ nombre = "AlfaEnciclopediaVentana", titulo = L["Enciclopedia"], subtitulo = L["Todo el juego, aunque no lo tengas"],
		icono = "ic-enciclopedia", ancho = V.Tamano(), alto = select(2, V.Tamano()),
		alCerrar = function()
			Cu.Cerrar()
			if reloj then reloj:Cancel() reloj = nil end
		end })
	V.ArmarAsa()
	local cuerpo = v.Cuerpo
	ui.buscador = K.Buscador(cuerpo, { ayuda = L["Busca cualquier cosa, en español o en inglés…"], retraso = 0.25,
		alCambiar = function(t)
			est.texto = t or ""
			filtrar()
		end,
		alEnter = function() if ui.lf and #(est.resultados[est.tipo] or {}) > 0 then ui.lf:Elegir(1) end end })
	local ops = {}
	for _, t in ipairs(M.TIPOS) do ops[#ops + 1] = { valor = t.clave, texto = t.texto, icono = t.icono } end
	ui.tipos = K.Segmentos(cuerpo, { estilo = "segmentos", opciones = ops, valor = est.tipo, alCambiar = function(val) V.SetTipo(val) end })
	ui.barra = CreateFrame("Frame", nil, cuerpo)
	ui.zona = CreateFrame("Frame", nil, cuerpo)
	ui.lf = K.ListaFicha(ui.zona, {
		margen = 0, arriba = 0, abajo = 0, anchoFicha = 470, alto = FILA,
		crear = crearFila, pintar = pintarFila, alClic = alClicFila,
		ficha = llenarFicha, cuenta = cuentaTexto,
		vacio = VACIO_SIN,
		vacioFicha = { lobo = "atento", titulo = L["Elige algo de la lista"], texto = L["Verás de dónde sale, dónde está, cómo llegar y qué hacer después."] },
	})
	ui.lf.Lista.alEntrar = alEntrarFila
	-- 1.3.9: «Guíame» siempre a la mano: si bajas en la ficha y sus botones
	-- quedan arriba, fuera de la vista, sale fijo en la esquina de la ficha.
	ui.guiaFija = K.Boton(ui.lf.Ficha, L["Guíame"], function()
		local a = est.ficha and est.ficha.acciones
		if a and a.guiar then local ok, msg = a.guiar() aviso(ok, msg) end
	end, { tipo = "primario", tam = "chico", icono = "ic-seguir" })
	ui.guiaFija:SetPoint("TOPRIGHT", ui.lf.Ficha, "TOPRIGHT", -ESP.base - 10, -ESP.s)
	ui.guiaFija:SetFrameLevel(ui.lf.FichaDesp:GetFrameLevel() + 20)
	ui.guiaFija:Hide()
	ui.lf.FichaDesp:HookScript("OnVerticalScroll", function() V.RevisarGuiaFija() end)
	ui.lf.FichaDesp:HookScript("OnMouseWheel", function() V.RevisarGuiaFija() end)
	ui.estado = K.Vacio(cuerpo, { lobo = "dormido", titulo = "" })
	ui.estado:Hide()
	v.alAcomodar = function() acomodar() end
end

-- Arma todo lo de fondo la primera vez (por lotes, en orden de uso).
local preparado = false
local function prepararTodo()
	if preparado then return end
	preparado = true
	Cat.Pedir(est.tipo)
	for _, t in ipairs(M.TIPOS) do if t.clave ~= est.tipo then Cat.Pedir(t.clave) end end
	Cat.PrepararFacetas()
	I.PrepararRaros()
	I.PrepararMisiones()
end

-- pedido = { texto, tipo ("objeto", "pnj"...), kind, id }
function V.Abrir(p)
	-- mientras falte terminar la bienvenida, se abre la bienvenida
	if N.Permitido and not N.Permitido() then return end
	p = p or {}
	if not v then crear() end
	-- 1.3.7: si la pantalla cambió (la escala de la interfaz), que siga cabiendo.
	local w, h = V.Tamano()
	if not v:IsShown() and (floor(K.num(v:GetWidth(), 0)) ~= w or floor(K.num(v:GetHeight(), 0)) ~= h) then v:SetTamano(w, h) end
	v:Abrir()
	local C, motivo = M.Codex()
	if not C then return V.MostrarMotivo(motivo) end
	ocultarMotivo()
	prepararTodo()
	vigilarAvance()
	local kind = p.kind and M.KindDe(p.kind)
	local id = p.id
	if kind == "instance" and id then A.Fire("SHOW_DUNGEON", id) end
	if kind and id ~= nil and kind ~= "instance" then
		id = tonumber(id) or id
		local tipo = M.TIPO_DE_KIND[kind]
		if kind == "guia" then
			-- Una guía: Mi primera montura va con las monturas; las demás, con lo que esté abierto.
			if id == "montura" then V.SetTipo("montura", true) end
			est.texto = ""
			ui.buscador:SetTexto("", true)
			acomodar()
			local t = est.tipo
			Cat.Pedir(t, function(ok) if ok then filtrar({ kind = kind, id = id }) end end)
			if not Cat.Listo(t) then ui.lf:MostrarFicha({ kind = kind, id = id }) end
			return
		end
		if tipo then V.SetTipo(tipo, true) end
		-- Lo buscamos por su nombre, así queda elegido en la lista.
		local nombre = M.Nombre(kind, id)
		est.texto = nombre ~= tostring(id) and nombre or ("#" .. tostring(id))
		ui.buscador:SetTexto(est.texto, true)
		acomodar()
		if tipo then
			-- Con el catálogo listo elige ya; si no, lo pide y elige al terminar
			-- (un filtrar() suelto elegiría después la primera fila: otra del mismo nombre).
			filtrar({ kind = kind, id = id })
		else
			ui.lf:MostrarFicha({ kind = kind, id = id })
		end
		return
	end
	if p.tipo and M.TIPO[p.tipo] then V.SetTipo(p.tipo, true) end
	if p.texto then
		est.texto = p.texto
		ui.buscador:SetTexto(p.texto, true)
	end
	acomodar()
	filtrar()
end

function V.Cerrar() if v then v:Cerrar() end end
function V.Visible() return v and v:IsShown() and true or false end
function V.Alternar(p) if V.Visible() then V.Cerrar() else V.Abrir(p) end end

---------------------------------------------------------------------------
-- Lo que termina de prepararse en segundo plano
---------------------------------------------------------------------------
M.alCatalogo = function(tipo)
	if not V.Visible() then return end
	if tipo == est.tipo and #(est.resultados[tipo] or {}) == 0 then filtrar() else actualizarCuentas() end
end

M.alFacetas = function(cual)
	if not V.Visible() then return end
	local bar = barras.objeto
	if cual == "lista" and bar and bar.Refrescar then bar.Refrescar() acomodar() end
	if est.tipo == "objeto" and est.pend then filtrar() end
end

M.alIndice = function(cual)
	if not V.Visible() then return end
	if est.pend and ((cual == "misiones" and est.tipo == "mision") or (cual == "raros" and est.tipo == "raro")
		or (cual == "origenes" and est.tipo == "objeto")) then filtrar() end
	if est.ficha and est.ficha.nota then rehacerFichaActual() end
end

-- Tus monturas o mascotas cambiaron (aprendiste una, la compraste...).
M.alColeccion = function()
	if not V.Visible() then return end
	if est.tipo == "montura" or est.tipo == "mascota" then
		if est.filtros[est.tipo].mia then filtrar() else ui.lf.Lista:Refrescar() end
	end
	local a = est.actual
	if a and (a.kind == "mount" or a.kind == "pet" or a.kind == "mountspell" or a.kind == "guia") then rehacerFichaActual() end
end

-- Tus puntos del legado o tus retos cambiaron.
M.alLegado = function()
	local a = est.actual
	if V.Visible() and a and a.kind == "guia" and a.id == "legado" then rehacerFichaActual() end
end

A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if est.esperaCombate and V.Visible() then V.Abrir() end
end)

-- Para el banco de pruebas (tools/banco): las piezas y el estado.
V.ui, V.est, V.barras = ui, est, barras
