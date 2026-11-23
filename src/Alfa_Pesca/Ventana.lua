-- Alfa - Pesca: la ventana de pesca (toxic3000 / La Jauría). GPL-3.0.
--
-- Una ventana del Kit con cinco pestañas (segmentos arriba):
--   Diario         todo lo que se pesca en Forever y lo que llevas de cada cosa
--   Estadísticas   la sesión, desde siempre y las sesiones anteriores
--   Guía           de 1 a 300, cerca de ti, equipo y cebos, misiones, concurso
--   Cocina         recetas de pescado, la cola y la fogata
--   Logros         los logros de pesca de Alfa
-- Cada pestaña se arma la primera vez que se abre (Diario.lua, Estadisticas.lua,
-- Guia.lua, VistaCocina.lua) y se rehace cuando cambia algo y está a la vista.
-- Aquí también viven las piezas que comparten: la página desplazable, la celda
-- de un objeto, "Guíame" y el Codex.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring
local ESP = K.ESP

local V = {}
M.V = V
V.PESTANAS, V.orden = {}, {}

function V.Registrar(id, def)
	V.PESTANAS[id] = def
	V.orden[#V.orden + 1] = id
	table.sort(V.orden, function(a, b) return (V.PESTANAS[a].orden or 99) < (V.PESTANAS[b].orden or 99) end)
end

---------------------------------------------------------------------------
-- Piezas que comparten las pestañas
---------------------------------------------------------------------------

-- Una página que se desplaza: p.pila (K.Pila) ; p:Acomodar(ancho, alto)
function V.Pagina(padre)
	local p = CreateFrame("Frame", nil, padre)
	p.desp = K.Desplazable(p)
	p.desp:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
	p.pila = K.Pila(p.desp.Contenido, { espacio = ESP.l })
	p.pila:SetPoint("TOPLEFT", p.desp.Contenido, "TOPLEFT", 0, 0)
	function p:Acomodar(ancho, alto)
		self:SetSize(ancho, alto)
		self.desp:Acomodar(ancho, alto)
		if self.antes then K.Llamar(self.antes, self) end
		local h = self.pila:Acomodar(self.desp:AnchoUtil())
		self.desp:SetAltoContenido(h + ESP.base)
		return alto
	end
	return p
end

-- Un párrafo como bloque de una pila: b:Set(texto, color) ; b:Acomodar(ancho)
function V.Parrafo(padre, rol, color)
	local b = CreateFrame("Frame", nil, padre)
	b.Texto = K.Texto(b, rol or "texto", color or "textoSuave")
	b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	function b:Set(t, c)
		K.Escribir(self.Texto, t or "")
		if c then K.ColorTexto(self.Texto, c) end
		K.Mostrar(self, (t or "") ~= "")
	end
	function b:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, ancho)
		self:SetSize(ancho, max(1, h))
		return h
	end
	return b
end

-- La celda de un objeto (ícono con su calidad, nombre y cuántos) para una rejilla.
function V.CeldaObjeto(padre)
	local c = CreateFrame("Frame", nil, padre)
	c.caja = K.Caja(c, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	c.Icono = K.IconoObjeto(c, 30)
	c.Icono:SetPoint("LEFT", c, "LEFT", ESP.m, 0)
	c.Cantidad = K.Texto(c, "numero", "textoSuave")
	c.Cantidad:SetJustifyH("RIGHT")
	c.Cantidad:SetPoint("RIGHT", c, "RIGHT", -ESP.base, 0)
	c.Nombre = K.Texto(c, "cuerpo", "objeto")
	c.Nombre:SetPoint("LEFT", c.Icono, "RIGHT", ESP.m, 0)
	c.Nombre:SetPoint("RIGHT", c.Cantidad, "LEFT", -ESP.s, 0)
	function c:Set(o)
		self.Icono:SetObjeto({ id = type(o.id) == "number" and o.id or nil, icono = o.icono, calidad = o.calidad })
		K.Escribir(self.Nombre, o.nombre or "?")
		V.ColorCalidad(self.Nombre, o.calidad)
		self.Cantidad:SetText(format("\195\151%d", o.cantidad or 0))
	end
	function c:Acomodar(ancho, altoMin)
		local h = max(K.ALTO.compacta, altoMin or 0)
		self:SetSize(ancho, h)
		return h
	end
	return c
end

function V.ColorCalidad(fs, q)
	local r, g, b = K.ColorDeCalidad(q)
	if r and q and q >= 2 and A.Theme and A.Theme.Legible then
		fs:SetTextColor(A.Theme.Legible(r, g, b))
	else
		K.ColorTexto(fs, "texto")
	end
end

-- Una rejilla de objetos que reusa sus celdas.
function V.RejillaObjetos(padre, min)
	local r = K.Rejilla(padre, { min = min or 240, gap = ESP.s })
	r.celdas = {}
	function r:Poner(lista)
		local elems = {}
		for i, o in ipairs(lista) do
			local c = self.celdas[i] or V.CeldaObjeto(self)
			self.celdas[i] = c
			c:Set(o)
			c:Show()
			elems[i] = c
		end
		for i = #lista + 1, #self.celdas do self.celdas[i]:Hide() end
		self:SetElementos(elems)
		K.Mostrar(self, #lista > 0)
	end
	return r
end

-- El Codex del motor (se carga al pedirlo, nunca al entrar).
function V.Codex()
	local C = A.Codex
	if not (C and C.Load) then return nil end
	local ok, cargado = pcall(C.Load)
	if ok and cargado then return C end
	return nil
end

function V.CodexListo()
	local C = A.Codex
	return C and C.IsLoaded and C.IsLoaded() and C or nil
end

-- "Guíame": la guía del motor a un objeto, PNJ o misión (tu clic).
local MOTIVO = {
	disabled = L["El buscador del motor está apagado (Ajustes > Descubrir): enciéndelo para que Alfa arme guías."],
	tabs = L["Ya tienes seis guías abiertas: cierra una y vuelve a intentar."],
	nosource = L["No se conoce de dónde sale."],
	noguide = L["No hay un camino que Alfa pueda guiar para esto."],
	nolocation = L["No se sabe en qué lugar está."],
}
function V.Guiar(kind, id)
	local Lk = A.Lookup
	if not (Lk and Lk.Guide) then
		K.Aviso({ titulo = L["Guíame"], texto = L["El motor no puede armar guías ahora."], icono = "ic-aviso", tono = "aviso" })
		return false
	end
	if InCombatLockdown and InCombatLockdown() then
		K.Aviso({ titulo = L["Guíame"], texto = L["Se puede al salir de combate."], icono = "ic-aviso", tono = "aviso" })
		return false
	end
	local ok, gid, motivo = pcall(Lk.Guide, kind, id)
	if ok and gid then
		if N.EmpezarRuta then pcall(N.EmpezarRuta) end
		return true
	end
	-- 1.3.7: sin lugar (las 12 fijadas): el cuadro de elegir de Rutas (EnCurso.lua).
	local R = rawget(_G, "AlfaRuta")
	if ok and motivo == "tabs" and type(R) == "table" and type(R.AvisoLleno) == "function" then
		R.AvisoLleno()
		return false
	end
	K.Aviso({ titulo = L["Guíame"], texto = MOTIVO[motivo] or L["No se pudo armar la guía."], icono = "ic-aviso", tono = "aviso" })
	return false
end

-- "Llévame" a lo más cercano de Buscar cerca (Alfa_Rutas), si está.
function V.Llevar(tipo, linea)
	local C = rawget(_G, "AlfaCerca")
	if type(C) == "table" and type(C.Ir) == "function" then
		local ok, si = pcall(C.Ir, tipo, linea)
		return ok and si
	end
	return false
end

function V.HayCerca()
	local C = rawget(_G, "AlfaCerca")
	return type(C) == "table" and type(C.Ir) == "function"
end

function V.NombreMapa(id)
	local C = C_Map
	if C and C.GetMapInfo then
		local ok, info = pcall(C.GetMapInfo, id)
		if ok and type(info) == "table" and type(info.name) == "string" then return info.name end
	end
	return nil
end

-- El nombre de un objeto: el del cliente, el del diario o el del Codex.
function V.NombreObjeto(id)
	local n = M.Eq.Nombre(id)
	if n then return n end
	local e = M.Diario()[id]
	if type(e) == "table" and type(e.nombre) == "string" then return e.nombre end
	local C = V.CodexListo()
	if C and C.Name then
		local ok, nombre = pcall(C.Name, "item", id)
		if ok and type(nombre) == "string" then return nombre end
	end
	if A.Compat and A.Compat.RequestItem and type(id) == "number" then pcall(A.Compat.RequestItem, id) end
	return format(L["Objeto %s"], tostring(id))
end

function V.Fecha(t)
	t = tonumber(t)
	if not t then return "—" end
	local d = date("*t", t)
	local dia = M.DIAS[d.wday] or ""
	return format(L["%s %d/%d · %02d:%02d"], dia, d.day, d.month, d.hour, d.min)
end

function V.Hace(t)
	t = tonumber(t)
	if not t then return "—" end
	local s = max(0, time() - t)
	if s < 90 then return L["hace un momento"] end
	if s < 3600 then return format(L["hace %d min"], floor(s / 60)) end
	if s < 86400 then return format(L["hace %d h"], floor(s / 3600)) end
	return format(L["hace %d días"], floor(s / 86400))
end

function V.Porcentaje(f) return f and format(L["%d %%"], floor(f * 100 + 0.5)) or "—" end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local v
local actual

local function subtitulo()
	local texto = M.TextoHabilidad()
	local vida = M.Vida()
	return format(L["%s · %d capturas desde siempre"], texto, vida.capturas)
end

local function crear()
	v = K.Ventana({ nombre = "AlfaPescaVentana", titulo = L["Pesca"], subtitulo = subtitulo(), icono = "ic-pesca", ancho = 960, alto = 640 })
	local opciones = {}
	for _, id in ipairs(V.orden) do
		local p = V.PESTANAS[id]
		opciones[#opciones + 1] = { valor = id, texto = p.nombre, icono = p.icono }
	end
	v.Seg = K.Segmentos(v.Cuerpo, { estilo = "segmentos", opciones = opciones, valor = V.orden[1], alCambiar = function(id) V.Mostrar(id) end })
	v.Area = CreateFrame("Frame", nil, v.Cuerpo)
	v.vistas = {}
	v.alAcomodar = function() V.Acomodar() end
	M.VISIBLES[#M.VISIBLES + 1] = v
	return v
end

function V.Acomodar()
	if not v then return end
	local ancho, alto = v:AnchoCuerpo(), v:AltoCuerpo()
	v.Seg:Acomodar(ancho)
	v.Seg:ClearAllPoints()
	v.Seg:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -ESP.base)
	local y = ESP.base + K.ALTO.control + ESP.base
	v.Area:ClearAllPoints()
	v.Area:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -y)
	local altoArea = max(120, alto - y - ESP.base)
	v.Area:SetSize(ancho, altoArea)
	local vista = actual and v.vistas[actual]
	if vista then
		vista:ClearAllPoints()
		vista:SetPoint("TOPLEFT", v.Area, "TOPLEFT", 0, 0)
		if vista.Refrescar then K.Llamar(vista.Refrescar, vista) end
		vista:Acomodar(ancho, altoArea)
	end
end

function V.Mostrar(id)
	if not V.PESTANAS[id] then id = V.orden[1] end
	actual = id
	N.DatosPersonaje(ID).pestana = id
	v.Seg:SetValor(id)
	for k, vista in pairs(v.vistas) do vista:SetShown(k == id) end
	if not v.vistas[id] then
		local p = V.PESTANAS[id]
		local ok, vista = pcall(p.construir, v.Area)
		if not ok then
			if geterrorhandler then geterrorhandler()(vista) end
			return
		end
		v.vistas[id] = vista
	end
	v.vistas[id]:Show()
	v:SetTitulo(L["Pesca"], subtitulo(), "ic-pesca")
	V.Acomodar()
end

function V.Abrir(id)
	if N.Permitido and not N.Permitido() then return end
	v = v or crear()
	v:Abrir()
	V.Mostrar(id or actual or N.DatosPersonaje(ID).pestana or V.orden[1])
end

function V.Alternar(id)
	if v and v:IsShown() and (not id or id == actual) then v:Cerrar() return end
	V.Abrir(id)
end

function V.Visible() return v ~= nil and v:IsShown() end
function V.Actual() return actual end

-- Algo cambió: la pestaña a la vista se rehace (una vez por tanda de cambios).
M.Escuchar(function(m)
	if not V.Visible() then return end
	local p = actual and V.PESTANAS[actual]
	if p and p.cambia then
		for clave in pairs(m) do
			if p.cambia[clave] or clave == "todo" then
				v:SetTitulo(L["Pesca"], subtitulo(), "ic-pesca")
				V.Acomodar()
				return
			end
		end
	end
end)
