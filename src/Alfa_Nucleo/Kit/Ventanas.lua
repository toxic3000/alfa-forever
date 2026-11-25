-- Alfa - Kit: ventanas, diálogos y avisos (toxic3000 / La Jauría). GPL-3.0.
--
--   K.Ventana(opts)        ventana flotante que se mueve, recuerda su lugar y se cierra con Esc
--   K.Desplazable(padre)   un área que se desplaza con la rueda (y su barra fina)
--   K.Dialogo(opts)        diálogo modal sobre un velo (uno a la vez)
--   K.Aviso(opts)          aviso flotante arriba, junto a la flecha (hasta 3, se van solos;
--                          1.3.7: el cuarto espera su turno, y lo que no es
--                          urgente espera a que el juego termine: Momentos.lua)
-- Nada de esto es un marco protegido: se puede abrir y cerrar en combate.

local _, N = ...
local K = N.Kit
local A = N.A
local L = K.L

local floor, max, min, type, ipairs = math.floor, math.max, math.min, type, ipairs
local ESP = K.ESP

local function datos() return N.Datos("kit") end

local function cerrarConEsc(nombre)
	if not nombre then return end
	if A and type(A.CloseOnEscape) == "function" then
		A.CloseOnEscape(nombre)
	elseif type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, nombre)
	end
end

-- 1.4.0 (61): Esc cierra todas las ventanas de Alfa. Las del Kit (K.Ventana
-- con nombre), las del motor (W.Shell) y las que ya se anotaban solas
-- (Bolsas, Oro, el Mapa, Cerca) ya lo hacían; aquí van las propias que
-- faltaban, por su nombre (un nombre que aún no existe no estorba). No van
-- las que no deben: la flecha, el rastreador, Lya, los avisos y anuncios,
-- los marcos de Combate y Curación, la barra de Pesca, la ventana de guía
-- y Dos pantallas (se quitan con su propio botón).
K.CERRAR_CON_ESC = {
	"AlfaKitMenu",           -- los menús desplegables del Kit
	"AlfaMazmorrasResumen",  -- el resumen al salir de una mazmorra
	"AlfaBolsasPrevia",      -- la vista previa de «Ordenar» (al esconderse, se cancela)
}
function K.AnotarCerrarConEsc()
	for _, n in ipairs(K.CERRAR_CON_ESC) do cerrarConEsc(n) end
end
if A and A.OnLogin then A.OnLogin(function() K.AnotarCerrarConEsc() end) end

---------------------------------------------------------------------------
-- Área desplazable
--   d = K.Desplazable(padre) ; d.Contenido (el hijo) ; d:SetAltoContenido(h)
--   d:Acomodar(ancho, alto) ; d:IrArriba()
---------------------------------------------------------------------------
function K.Desplazable(padre)
	local d = CreateFrame("ScrollFrame", nil, padre)
	d.Contenido = CreateFrame("Frame", nil, d)
	d.Contenido:SetSize(1, 1)
	d:SetScrollChild(d.Contenido)
	d:EnableMouseWheel(true)
	d.alfaAltoContenido = 0
	local barra = CreateFrame("Slider", nil, d)
	d.Barra = barra
	barra:SetOrientation("VERTICAL")
	barra:SetWidth(6)
	barra:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, 0)
	barra:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, 0)
	barra:SetMinMaxValues(0, 1)
	barra.Pista = K.Plano(barra, "hundido", "BACKGROUND", 0)
	barra.Pista:SetAllPoints(barra)
	barra:SetThumbTexture(K.Ruta("knob"))
	local pulgar = barra.GetThumbTexture and barra:GetThumbTexture()
	if pulgar then
		pulgar:SetSize(6, 32)
		K.Pintar(pulgar, function(t) t:SetVertexColor(K.Color("lineaFuerte")) end)
	end
	barra:Hide()
	local function rango() return max(0, d.alfaAltoContenido - K.num(d:GetHeight(), 0)) end
	barra:SetScript("OnValueChanged", function(_, v)
		if d.alfaQuieto then return end
		d:SetVerticalScroll(v)
	end)
	d:SetScript("OnMouseWheel", function(self, delta)
		local v = max(0, min(rango(), K.num(self:GetVerticalScroll(), 0) - delta * 48))
		self:SetVerticalScroll(v)
		self.alfaQuieto = true
		barra:SetValue(v)
		self.alfaQuieto = nil
	end)
	function d:SetAltoContenido(h)
		self.alfaAltoContenido = h or 0
		self.Contenido:SetHeight(max(1, self.alfaAltoContenido))
		local r = rango()
		barra:SetShown(r > 0)
		barra:SetMinMaxValues(0, max(1, r))
		if K.num(self:GetVerticalScroll(), 0) > r then self:SetVerticalScroll(r) end
	end
	function d:Acomodar(ancho, alto)
		if ancho then self:SetWidth(ancho) self.Contenido:SetWidth(ancho - 12) end
		if alto then self:SetHeight(alto) end
		self:SetAltoContenido(self.alfaAltoContenido)
		return K.num(self:GetHeight(), 0)
	end
	function d:AnchoUtil() return K.num(self:GetWidth(), 0) - 12 end
	function d:IrArriba()
		self:SetVerticalScroll(0)
		self.alfaQuieto = true
		barra:SetValue(0)
		self.alfaQuieto = nil
	end
	-- 1.3.9: hasta abajo (lo que acaba de aparecer al final, a la vista).
	function d:IrAbajo()
		local r = rango()
		self:SetVerticalScroll(r)
		self.alfaQuieto = true
		barra:SetValue(r)
		self.alfaQuieto = nil
	end
	return d
end

---------------------------------------------------------------------------
-- Ventana flotante
--   opts = { nombre = "AlfaRuta" (global, para Esc y su lugar), titulo, subtitulo,
--            icono = "ic-ruta", ancho = 760, alto = 560, cerrar = true,
--            desplazar = false (un área desplazable como cuerpo),
--            alAbrir = fn(v), alCerrar = fn(v) }
--   Al abrirse o cerrarse una con nombre: A.Fire("ALFA_VENTANA", nombre, abierta) (1.3.2)
--   v.Cuerpo (marco del contenido; con desplazar, v.Cuerpo es el Contenido)
--   v:Abrir() v:Cerrar() v:Alternar() v:SetTitulo(t, sub, icono) v:SetTamano(w, h)
--   v:AnchoCuerpo() v:AltoCuerpo() v:SetAltoContenido(h) v:SetPie(botones)
--   v.margen: el margen a los lados del cuerpo (24)
---------------------------------------------------------------------------
local CABECERA, PIE, MARGEN = K.ALTO.cabecera, K.ALTO.pie, ESP.l

local function guardarLugar(v)
	if not v.alfaNombre then return end
	local p, _, rp, x, y = v:GetPoint(1)
	if not p then return end
	local d = datos()
	d.ventanas = type(d.ventanas) == "table" and d.ventanas or {}
	d.ventanas[v.alfaNombre] = { p, rp, floor(K.num(x, 0) + 0.5), floor(K.num(y, 0) + 0.5) }
end

local function ponerEnSuLugar(v)
	v:ClearAllPoints()
	local d = v.alfaNombre and datos().ventanas
	local l = type(d) == "table" and d[v.alfaNombre]
	if type(l) == "table" and type(l[1]) == "string" and type(l[2]) == "string" and type(l[3]) == "number" and type(l[4]) == "number" then
		v:SetPoint(l[1], UIParent, l[2], l[3], l[4])
	else
		v:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	end
end

-- Todas las ventanas del Kit, para cerrar de una vez las que tapan la
-- pantalla al empezar a seguir algo (N.EmpezarRuta). No tapan: las de
-- opts.fija (la configuración obligatoria, un reporte a medio escribir) ni
-- las de la capa MEDIUM (piezas que acompañan al jugar, como el medidor).
K.VENTANAS = K.VENTANAS or {}
function K.CerrarLasQueTapan()
	for _, v in ipairs(K.VENTANAS) do
		if v.alfaTapa and v:IsShown() then v:Cerrar() end
	end
end

function K.Ventana(opts)
	opts = opts or {}
	local v = CreateFrame("Frame", opts.nombre, K.Raiz())
	v.alfaNombre = opts.nombre
	v.alfaTapa = not opts.fija and (opts.capa or "HIGH") ~= "MEDIUM"
	K.VENTANAS[#K.VENTANAS + 1] = v
	v:SetSize(opts.ancho or 760, opts.alto or 560)
	v:SetFrameStrata(opts.capa or "HIGH")
	v:SetToplevel(true)
	v:SetClampedToScreen(true)
	v:SetMovable(true)
	v:EnableMouse(true)
	v.margen = MARGEN
	v.caja = K.Caja(v, { fondo = "fondo", borde = "linea", corte = K.CORTE.ventana })
	v.Marca = K.Marca(v, K.CORTE.ventana, "acento", 44)

	-- Cabecera: la baldosa con el ícono, el título y el subtítulo; se arrastra.
	local c = CreateFrame("Frame", nil, v)
	v.Cabecera = c
	c:SetPoint("TOPLEFT", v, "TOPLEFT", 0, 0)
	c:SetPoint("TOPRIGHT", v, "TOPRIGHT", 0, 0)
	c:SetHeight(CABECERA)
	c:EnableMouse(true)
	c:RegisterForDrag("LeftButton")
	c:SetScript("OnDragStart", function() if not (A and A.DragLocked and A.DragLocked()) then v:StartMoving() end end)
	c:SetScript("OnDragStop", function() v:StopMovingOrSizing() guardarLugar(v) end)
	c.Icono = K.Icono(c, opts.icono or "ic-lobo", 20, "acento")
	c.Icono:SetPoint("LEFT", c, "LEFT", MARGEN, 0)
	c.Titulo = K.Texto(c, "subtitulo", "texto")
	c.Subtitulo = K.Texto(c, "pequeno", "textoTenue")
	c.Linea = K.Linea(c, "linea")
	c.Linea:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
	c.Linea:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
	if opts.cerrar ~= false then
		c.Cerrar = K.BotonIcono(c, "ic-cerrar", function() v:Cerrar() end, { tam = 28, icono = 14, ayuda = L["Cerrar"] })
		-- En Clásico WoW, un poco más adentro: el marco del cuadro de diálogo es más ancho.
		c.alfaCerrar = { c.Cerrar }
		K.Pintar(c.alfaCerrar, function(x)
			x[1]:ClearAllPoints()
			x[1]:SetPoint("RIGHT", c, "RIGHT", K.Clasico() and -ESP.base - 2 or -ESP.m, K.Clasico() and -2 or 0)
		end)
	end

	local cuerpo = CreateFrame("Frame", nil, v)
	v.Marco = cuerpo
	cuerpo:SetPoint("TOPLEFT", c, "BOTTOMLEFT", 0, 0)
	cuerpo:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", 0, 0)
	if opts.desplazar then
		v.Desplazable = K.Desplazable(cuerpo)
		v.Desplazable:SetPoint("TOPLEFT", cuerpo, "TOPLEFT", 0, -1)
		v.Cuerpo = v.Desplazable.Contenido
	else
		v.Cuerpo = cuerpo
	end

	function v:SetTitulo(t, sub, icono)
		K.Escribir(c.Titulo, t or "")
		K.Escribir(c.Subtitulo, sub or "")
		if icono then K.SetIcono(c.Icono, icono, "acento") end
		local conSub = (sub or "") ~= ""
		c.Titulo:ClearAllPoints()
		c.Titulo:SetPoint("LEFT", c.Icono, "RIGHT", ESP.m, conSub and 8 or 0)
		c.Subtitulo:ClearAllPoints()
		c.Subtitulo:SetPoint("TOPLEFT", c.Titulo, "BOTTOMLEFT", 0, -2)
		c.Subtitulo:SetShown(conSub)
	end
	function v:AnchoCuerpo() return K.num(self:GetWidth(), 0) - 2 * MARGEN end
	function v:AltoCuerpo()
		return K.num(self:GetHeight(), 0) - CABECERA - ((self.Pie and self.Pie:IsShown()) and PIE or 0)
	end
	function v:SetTamano(w, h)
		self:SetSize(w or K.num(self:GetWidth(), 760), h or K.num(self:GetHeight(), 560))
		self:Reacomodar()
	end
	-- El cuerpo cambió de alto (con desplazar): ajusta la barra.
	function v:SetAltoContenido(h)
		if self.Desplazable then self.Desplazable:SetAltoContenido(h) end
	end
	function v:Reacomodar()
		local abajo = (self.Pie and self.Pie:IsShown()) and PIE or 0
		cuerpo:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, abajo)
		if self.Desplazable then
			self.Desplazable:Acomodar(K.num(self:GetWidth(), 0) - 8, self:AltoCuerpo() - 2)
			self.Cuerpo:SetWidth(K.num(self:GetWidth(), 0) - 20)
		end
		if self.alAcomodar then K.Llamar(self.alAcomodar, self) end
	end
	-- El pie: botones a la derecha (el primero, el principal, queda al final).
	function v:SetPie(botones, izquierda)
		if not self.Pie then
			local p = CreateFrame("Frame", nil, self)
			p:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
			p:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
			p:SetHeight(PIE)
			p.Fondo = K.Forma(p, 0, "BACKGROUND", -4)
			K.Pintar(p.Fondo, function(f) f:Color("pie") end)
			p.Fondo:Corte(0, K.CORTE.ventana)
			p.Linea = K.Linea(p, "linea")
			p.Linea:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
			p.Linea:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
			self.Pie = p
		end
		local p = self.Pie
		p.botones = botones or {}
		p.izquierda = izquierda or {}
		local x = MARGEN
		for i = #p.botones, 1, -1 do
			local b = p.botones[i]
			K.Adoptar(b, p)
			b:ClearAllPoints()
			b:SetPoint("RIGHT", p, "RIGHT", -x, 0)
			x = x + K.num(b:GetWidth(), 80) + ESP.s
		end
		local xi = MARGEN
		for _, b in ipairs(p.izquierda) do
			K.Adoptar(b, p)
			b:ClearAllPoints()
			b:SetPoint("LEFT", p, "LEFT", xi, 0)
			xi = xi + K.num(b:GetWidth(), 80) + ESP.s
		end
		p:SetShown(#p.botones + #p.izquierda > 0)
		self:Reacomodar()
	end
	function v:Abrir()
		if not self:IsShown() then ponerEnSuLugar(self) end
		self:Show()
		self:Raise()
	end
	function v:Cerrar() self:Hide() end
	function v:Alternar() if self:IsShown() then self:Cerrar() else self:Abrir() end end
	-- 1.3.2: ALFA_VENTANA (nombre, abierta): quien depende de una ventana
	-- (los nodos de Recolección en el mapa de Alfa) trabaja solo con ella abierta.
	v:SetScript("OnShow", function(self)
		if opts.alAbrir then K.Llamar(opts.alAbrir, self) end
		if opts.nombre and A and A.Fire then A.Fire("ALFA_VENTANA", opts.nombre, true) end
	end)
	v:SetScript("OnHide", function(self)
		K.CerrarMenu()
		K.OcultarInfo()
		if opts.alCerrar then K.Llamar(opts.alCerrar, self) end
		if opts.nombre and A and A.Fire then A.Fire("ALFA_VENTANA", opts.nombre, false) end
	end)
	v:SetTitulo(opts.titulo, opts.subtitulo, opts.icono)
	v:Hide()
	cerrarConEsc(opts.nombre)
	v:Reacomodar()
	return v
end

---------------------------------------------------------------------------
-- Diálogo modal (uno a la vez)
--   K.Dialogo({ titulo, texto, icono = "ic-alerta", lobo = "atento", peligro = false,
--               aceptar = "Aceptar", alAceptar = fn, cancelar = "Cancelar", alCancelar = fn })
---------------------------------------------------------------------------
local dialogo

local function armarDialogo()
	local velo = CreateFrame("Frame", "AlfaKitVelo", UIParent)
	velo:SetAllPoints(UIParent)
	velo:SetFrameStrata("DIALOG")
	velo:EnableMouse(true)
	velo.Fondo = K.Plano(velo, "velo", "BACKGROUND", 0)
	velo.Fondo:SetAllPoints(velo)
	K.Pintar(velo.Fondo, function(t) t:SetVertexColor(K.ConAlfa("velo", 0.6)) end)
	velo:Hide()
	local d = CreateFrame("Frame", "AlfaKitDialogo", velo)
	d:SetFrameStrata("DIALOG")
	d:SetFrameLevel(velo:GetFrameLevel() + 5)
	d:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	d:EnableMouse(true)
	d.caja = K.Caja(d, { fondo = "fondo", borde = "lineaFuerte", corte = K.CORTE.ventana })
	d.Marca = K.Marca(d, K.CORTE.ventana, "acento", 44)
	d.Icono = d:CreateTexture(nil, "ARTWORK")
	d.Icono:SetSize(40, 40)
	d.Icono:SetPoint("TOPLEFT", d, "TOPLEFT", ESP.l, -ESP.l)
	d.Titulo = K.Texto(d, "titulo", "texto")
	d.Texto = K.Texto(d, "texto", "textoSuave")
	-- Cada botón suelta las respuestas antes de cerrar: el velo, al ocultarse por
	-- otro camino (Esc, otro diálogo encima), llama a alCancelar.
	d.Aceptar = K.Boton(d, "", function()
		local fn = d.alAceptar
		d.alAceptar, d.alCancelar = nil, nil
		d.velo:Hide()
		if fn then K.Llamar(fn) end
	end, { tipo = "primario" })
	d.Cancelar = K.Boton(d, "", function()
		local fn = d.alCancelar
		d.alAceptar, d.alCancelar = nil, nil
		d.velo:Hide()
		if fn then K.Llamar(fn) end
	end, { tipo = "fantasma" })
	d.velo = velo
	-- 1.4.0 (118): Enter acepta (salvo en uno de peligro: ahí solo el clic).
	-- Las demás teclas siguen al juego (caminar, Esc...). Nunca en combate:
	-- el velo no sale en una pelea y, si llegara una tecla, pasa de largo.
	if d.EnableKeyboard and d.SetPropagateKeyboardInput then
		d:EnableKeyboard(true)
		d:SetPropagateKeyboardInput(true)
		d:SetScript("OnKeyDown", function(self, tecla)
			if InCombatLockdown and InCombatLockdown() then return end
			local enter = tecla == "ENTER" or tecla == "NUMPADENTER"
			if enter and not self.alfaPeligro and self.Aceptar:IsShown() and self.Aceptar:IsEnabled() then
				self:SetPropagateKeyboardInput(false)
				self.alfaEnter = true
				self.Aceptar:Click()
				return
			end
			self:SetPropagateKeyboardInput(true)
		end)
		velo:HookScript("OnShow", function()
			if not (InCombatLockdown and InCombatLockdown()) then d:SetPropagateKeyboardInput(true) end
		end)
	end
	velo:SetScript("OnHide", function()
		if velo.alfaSinCancelar then return end
		local fn = d.alCancelar
		d.alAceptar, d.alCancelar = nil, nil
		if fn then K.Llamar(fn) end
	end)
	cerrarConEsc("AlfaKitVelo")
	-- En combate el velo no atrapa el ratón: al empezar uno, el diálogo se
	-- esconde sin darse por cancelado (la pregunta sigue pendiente) y vuelve al
	-- terminar, si nadie lo cerró o lo cambió por otro mientras tanto.
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:SetScript("OnEvent", function(_, evento)
		if evento == "PLAYER_REGEN_DISABLED" then
			if velo:IsShown() then
				d.porCombate = true
				velo.alfaSinCancelar = true
				velo:Hide()
				velo.alfaSinCancelar = nil
			end
		elseif d.porCombate then
			d.porCombate = nil
			velo:Show()
		end
	end)
	return d
end

-- 1.3.7 (20): ningún velo sale solo. Un diálogo que nadie pidió con un clic
-- (o.solo = true, o uno que llega mientras el juego sube de nivel, carga o pasa
-- una cinemática) sale como aviso con sus dos botones: no tapa la pantalla.
-- K.VelosSinClic: los velos que salieron sin un clic (el banco lo revisa).
K.VelosSinClic = {}
local function dialogoComoAviso(o)
	local resuelto = false
	local function fin(fn) if resuelto then return end resuelto = true if fn then K.Llamar(fn) end end
	local acs = { { texto = o.aceptar or L["Aceptar"], alClic = function() fin(o.alAceptar) end } }
	if o.cancelar ~= false then acs[2] = { texto = o.cancelar or L["Cancelar"], alClic = function() fin(o.alCancelar) end } end
	K.Aviso({ titulo = o.titulo, texto = o.texto, icono = o.icono or (o.peligro and "ic-alerta" or "ic-info"), lobo = o.lobo,
		tono = o.peligro and "peligro" or "acento", acciones = acs, duracion = 20, lya = false, prioridad = 2,
		alCerrar = function() fin(o.alCancelar) end })
	return nil
end
local function sinClic(o)
	if o.pedido or (N.PidioJugador and N.PidioJugador()) then return false end
	if o.solo then return true end
	if not (N.MomentosActivos and N.MomentosActivos() and N.Ocupado) then return false end
	local oc, motivo = N.Ocupado("aviso", 1)
	return oc and (motivo == "nivel" or motivo == "cinematica" or motivo == "carga") or false
end

function K.Dialogo(o)
	o = o or {}
	if sinClic(o) then return dialogoComoAviso(o) end
	if not (o.pedido or (N.PidioJugador and N.PidioJugador())) then
		local l = K.VelosSinClic
		l[#l + 1] = { titulo = o.titulo, t = GetTime and GetTime() or 0, nivel = N.SubiendoNivel and N.SubiendoNivel() or false }
		while #l > 20 do table.remove(l, 1) end
	end
	dialogo = dialogo or armarDialogo()
	local d = dialogo
	local ancho = o.ancho or K.ANCHO.dialogo
	-- Un diálogo nuevo encima del que estaba abierto: el anterior se da por cancelado.
	local previo = d.velo and (d.velo:IsShown() or d.porCombate) and d.alCancelar
	d.alAceptar, d.alCancelar = nil, nil
	d.porCombate = nil
	if previo then K.Llamar(previo) end
	d.alAceptar, d.alCancelar = o.alAceptar, o.alCancelar
	d.alfaPeligro = o.peligro and true or nil
	if o.lobo then
		d.Icono:SetTexture(K.Lobo(o.lobo))
		d.Icono:SetVertexColor(K.Color(o.peligro and "peligro" or "acento"))
	else
		d.Icono:SetTexture(K.Ruta(o.icono or (o.peligro and "ic-alerta" or "ic-info")))
		d.Icono:SetVertexColor(K.Color(o.peligro and "peligro" or "acento"))
	end
	local x = ESP.l + 40 + ESP.base
	local tw = ancho - x - ESP.l
	K.Escribir(d.Titulo, o.titulo or "")
	d.Titulo:ClearAllPoints()
	d.Titulo:SetPoint("TOPLEFT", d, "TOPLEFT", x, -ESP.l)
	d.Titulo:SetWidth(tw)
	d.Titulo:SetWordWrap(true)
	local y = ESP.l + K.AltoTexto(d.Titulo)
	K.Escribir(d.Texto, o.texto or "")
	if (o.texto or "") ~= "" then
		y = y + ESP.s
		d.Texto:ClearAllPoints()
		d.Texto:SetPoint("TOPLEFT", d, "TOPLEFT", x, -y)
		y = y + K.Parrafo(d.Texto, tw)
	end
	y = max(y, ESP.l + 40) + ESP.l
	d.Aceptar:SetTipo(o.peligro and "peligro" or "primario")
	d.Aceptar:SetTexto(o.aceptar or L["Aceptar"])
	d.Cancelar:SetTexto(o.cancelar or L["Cancelar"])
	d.Cancelar:SetShown(o.cancelar ~= false)
	d.Aceptar:ClearAllPoints()
	d.Aceptar:SetPoint("TOPRIGHT", d, "TOPRIGHT", -ESP.l, -y)
	d.Cancelar:ClearAllPoints()
	d.Cancelar:SetPoint("RIGHT", d.Aceptar, "LEFT", -ESP.s, 0)
	y = y + K.ALTO.boton + ESP.l
	d:SetSize(ancho, y)
	-- Pedido en plena pelea: sale al terminar (el velo no atrapa a nadie en combate).
	if InCombatLockdown and InCombatLockdown() then d.porCombate = true else d.velo:Show() end
	return d
end

-- Hay un diálogo a la vista o esperando el fin del combate.
function K.DialogoAbierto()
	return dialogo ~= nil and (dialogo.velo:IsShown() or dialogo.porCombate) and true or false
end

function K.CerrarDialogo()
	if not dialogo then return end
	if dialogo.porCombate then
		-- Esperaba al fin del combate: se da por cancelado, como al cerrarlo.
		dialogo.porCombate = nil
		local fn = dialogo.alCancelar
		dialogo.alAceptar, dialogo.alCancelar = nil, nil
		if fn then K.Llamar(fn) end
	end
	dialogo.velo:Hide()
end

---------------------------------------------------------------------------
-- Avisos flotantes (toasts): arriba, a la izquierda de la flecha (1.4.0: su
-- lugar se acomoda con «Acomodar»), el más nuevo arriba, hasta 3.
-- Se van solos (no mientras el ratón está encima) o con su X.
--   K.Aviso({ titulo, texto, icono, lobo, tono = "acento", duracion = 6,
--             accion = { texto, alClic }, alCerrar = fn(aviso),
--             detalle = true (1.2.9: no sale con Alfa sencillo),
--             1.3.7: prioridad = 1..4 | "urgente" | "importante" | "util" | "detalle"
--             (de fábrica: importante = true -> 2, si no 3), acciones = { { texto,
--             alClic | fn }, ... } (hasta dos botones), pedido = true (lo pidió el
--             jugador: sale ya), sonido = tipo | false, donde = true (dice dónde
--             verlo), alMostrar = fn(aviso) (cuando de verdad sale), caduca = s,
--             1.3.9: textura = ruta (un ícono a color, sin teñir), firma = clave
--             del Centro de avisos (Kit/Firmas.lua) })
--   -> aviso | nil (guardado o esperando su turno) | true (lo dijo Lya) | false
--   duracion: de fábrica según lo largo del texto (5 a 15 s); no se va en combate.
--   aviso:Cerrar()   lo cierra desde fuera. El marco se reutiliza: Cerrar()
--   cierra el mensaje que muestra ahora (aviso.turno dice cuál es; con
--   aviso:Cerrar(turno) solo cierra si sigue mostrando ese).
-- alCerrar se llama una vez, se cierre como se cierre (X, tiempo, su acción,
-- Cerrar() o un aviso nuevo que toma su lugar).
---------------------------------------------------------------------------
local avisos, MAX_AVISOS = {}, 3
local ancla

-- 1.4.0 (81): un solo lugar para los avisos, arriba y a la izquierda de la
-- flecha (la flecha va al centro, a -140; el rastreador, a la derecha): la
-- pila nunca tapa a ninguno de los dos. El ancla tiene nombre
-- (AlfaAvisosAncla) y se acomoda con «Acomodar» (K.Movible, clave
-- "avisos"): aquí solo se pone su lugar de fábrica, una vez; nunca se mueve
-- después (las tarjetas se anclan a ella).
local ANCLA_X, ANCLA_Y = -118, -120
K.AVISOS_LUGAR = { "TOPRIGHT", "TOP", ANCLA_X, ANCLA_Y }
function K.AnclaAvisos()
	if ancla then return ancla end
	ancla = CreateFrame("Frame", "AlfaAvisosAncla", K.Raiz())
	ancla:SetSize(K.ANCHO.aviso, 72)
	ancla:SetPoint("TOPRIGHT", UIParent, "TOP", ANCLA_X, ANCLA_Y)
	ancla:EnableMouse(false)
	if K.Movible then pcall(K.Movible, ancla, "avisos", { nombre = L["Los avisos de Alfa"], muestra = L["Así se verá un aviso"] }) end
	return ancla
end

-- 1.3.8: con un anuncio grande a la vista (Kit/Anuncio.lua), los avisos van
-- debajo de él: nunca se empalman. 1.4.0: el ancla no se mueve; las tarjetas
-- empiezan más abajo (solo si el anuncio de verdad cae sobre la pila).
local function bajoAnuncio()
	local an = rawget(_G, "AlfaAnuncio")
	if not (ancla and type(an) == "table" and an.IsShown and an:IsShown() and not an.alfaSaliendo) then return 0 end
	local al, ar, ab = K.num(an:GetLeft(), 0), K.num(an:GetRight(), 0), K.num(an:GetBottom(), 0)
	local pl, pr, pt = K.num(ancla:GetLeft(), 0), K.num(ancla:GetRight(), 0), K.num(ancla:GetTop(), 0)
	if ar <= pl or al >= pr or ab >= pt then return 0 end
	return pt - ab + ESP.s
end
local function recolocar()
	if not ancla then return end
	local y = bajoAnuncio()
	ancla.alfaBajoAnuncio = y > 0 or nil
	for _, a in ipairs(avisos) do
		if a.alfaVivo and a:IsShown() then
			a:ClearAllPoints()
			a:SetPoint("TOP", ancla, "TOP", 0, -y)
			y = y + K.num(a:GetHeight(), 64) + ESP.s
		end
	end
end

-- 1.4.0 (81): ¿el cliente anima de verdad? (el banco no: ahí todo es al instante)
local function animaDeVerdad(ag)
	if type(ag) ~= "table" or type(ag.Play) ~= "function" then return false end
	-- (como Entrada.lua y Momentos.lua: el banco prueba todo al instante, salvo BANCO_ANIMAR)
	return not (rawget(_G, "FIRE_EVENT") ~= nil and rawget(_G, "BANCO_ANIMAR") ~= true)
end

local function quitar(a)
	local vivo = a.alfaVivo
	a.alfaVivo = nil
	-- 1.4.0 (81): se va suave (un desvanecido corto); sin animación, al instante.
	if vivo and a:IsShown() and animaDeVerdad(a.salida) and not (InCombatLockdown and InCombatLockdown()) then
		a:EnableMouse(false)
		a.alfaSaliendo = true
		a.entrada:Stop()
		a.salida:Stop()
		a.salida:Play()
		-- (por si la animación no termina: el marco se escondió con su padre, etc.)
		if C_Timer and C_Timer.After then
			C_Timer.After(0.5, function() if a.alfaSaliendo and not a.alfaVivo then a.alfaSaliendo = nil a:Hide() end end)
		end
	else
		a.alfaSaliendo = nil
		a:Hide()
	end
	recolocar()
	local fn = a.alfaAlCerrar
	a.alfaAlCerrar = nil
	if vivo and fn then K.Llamar(fn, a) end
end

-- 1.3.7: en plena pelea los avisos no atrapan clics (se quedan hasta que
-- acaba): el cuerpo, la X y los botones que no son del juego no toman el ratón.
-- Un botón seguro (abre algo del juego) sí, porque se toca a propósito.
local function ratonAviso(a, on)
	a:EnableMouse(on)
	for _, campo in ipairs({ "BotonCerrar", "Boton", "Boton2" }) do
		local b = a[campo]
		if b and b.EnableMouse and not (on == false and b.alfaSeguro) then b:EnableMouse(on) end
	end
	a.alfaSinRaton = not on or nil
end
local function ratonAvisos(on)
	for _, a in ipairs(avisos) do
		if a.alfaVivo or a.alfaSinRaton then ratonAviso(a, on) end
	end
end
K.RatonAvisos = ratonAvisos -- (para el banco)
function K.RecolocarAvisos() if ancla then recolocar() end end
function K.Avisos() return avisos end -- (para el banco: los marcos de la pila, el más nuevo primero)
function K.AvisosBajoAnuncio() return ancla ~= nil and ancla.alfaBajoAnuncio == true end
do
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:SetScript("OnEvent", function(_, evento) ratonAvisos(evento ~= "PLAYER_REGEN_DISABLED") end)
end

-- 1.4.0 (81): la tarjeta nueva, hermana del rastreador. Arriba, la banda de
-- su módulo (el color y el ícono de su firma, su nombre en mayúsculas y la
-- X), igual que la banda del título del rastreador; abajo, el ícono en una
-- baldosa del mismo color, el título, el texto y los botones a la derecha
-- (el principal al final). Entra deslizándose y se va desvanecida.
local BANDA_AVISO = 22
local BALDOSA_AVISO = 30
K.AVISO_BANDA, K.AVISO_BALDOSA = BANDA_AVISO, BALDOSA_AVISO

local function armarAviso()
	K.AnclaAvisos()
	local a = CreateFrame("Button", nil, ancla)
	-- 1.4.0 (81): por encima de las ventanas de Alfa (HIGH): antes, con una
	-- ventana abierta, la tarjeta salía entreverada con ella (niveles mezclados).
	a:SetFrameStrata("DIALOG")
	a:SetToplevel(true)
	a:SetWidth(K.ANCHO.aviso)
	a.caja = K.Caja(a, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.panel })
	a.caja:Estilo({ alfaFondo = 0.96 })
	-- La banda de arriba (como Alfa_Rutas/Banda.lua, aquí del color de la firma).
	local bf = CreateFrame("Frame", nil, a)
	bf:SetPoint("TOPLEFT", a, "TOPLEFT", 1, -1)
	bf:SetPoint("TOPRIGHT", a, "TOPRIGHT", -1, -1)
	bf:SetHeight(BANDA_AVISO - 1)
	bf:EnableMouse(false)
	a.Banda = bf
	a.BandaFondo = K.Forma(bf, K.CORTE.panel, "BACKGROUND", -4, a)
	a.BandaFondo:Corte(max(0, K.CORTE.panel - 1), 0)
	a.Arriba = K.Plano(a, "acento", "ARTWORK", 3)
	a.Arriba:SetHeight(2)
	a.Arriba:SetPoint("TOPLEFT", bf, "TOPLEFT", max(0, K.CORTE.panel - 1), 0)
	a.Arriba:SetPoint("TOPRIGHT", bf, "TOPRIGHT", 0, 0)
	K.SoloCasa(a.Arriba)
	a.BandaLinea = K.Linea(a, "linea")
	a.BandaLinea:SetPoint("BOTTOMLEFT", bf, "BOTTOMLEFT", 0, 0)
	a.BandaLinea:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", 0, 0)
	if K.TiraBando then
		a.Tira = K.TiraBando(a, 3, "ARTWORK")
		a.Tira:SetPoint("TOPLEFT", bf, "BOTTOMLEFT", 0, 1)
		a.Tira:SetPoint("TOPRIGHT", bf, "BOTTOMRIGHT", 0, 1)
	end
	-- 1.3.8 / 1.4.0: la firma del módulo (Kit/Firmas.lua): su ícono y su nombre en la banda.
	a.Firma = a:CreateTexture(nil, "ARTWORK", nil, 3)
	a.Firma:SetSize(12, 12)
	a.Firma:SetPoint("LEFT", bf, "LEFT", ESP.m, 0)
	a.FirmaNombre = K.Texto(a, "mayus", "acento")
	a.FirmaNombre:SetPoint("LEFT", a.Firma, "RIGHT", 6, 0)
	a.FirmaNombre:SetPoint("RIGHT", bf, "RIGHT", -30, 0)
	a.FirmaNombre:SetJustifyH("LEFT")
	a.FirmaNombre:SetWordWrap(false)
	-- (el disco de la firma de la 1.3.8 ya no va: queda escondido por si alguien lo lee)
	a.FirmaFondo = a:CreateTexture(nil, "ARTWORK", nil, 2)
	a.FirmaFondo:SetSize(1, 1)
	a.FirmaFondo:Hide()
	-- La franja fina del lado, bajo la banda (del color de la firma).
	a.Franja = K.Plano(a, "acento", "ARTWORK", 1)
	a.Franja:SetWidth(2)
	a.Franja:SetPoint("TOPLEFT", bf, "BOTTOMLEFT", 0, 0)
	a.Franja:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 1, K.CORTE.panel + 1)
	-- El ícono, en su baldosa.
	a.Baldosa = CreateFrame("Frame", nil, a)
	a.Baldosa:SetSize(BALDOSA_AVISO, BALDOSA_AVISO)
	a.Baldosa:SetPoint("TOPLEFT", bf, "BOTTOMLEFT", ESP.m - 1, -ESP.s - 1)
	a.Baldosa.caja = K.Caja(a.Baldosa, { fondo = "acento", alfaFondo = 0.14, borde = "acento", alfaBorde = 0.35, corte = K.CORTE.control })
	a.Icono = a.Baldosa:CreateTexture(nil, "ARTWORK")
	a.Icono:SetSize(18, 18)
	a.Icono:SetPoint("CENTER", a.Baldosa, "CENTER", 0, 0)
	a.Titulo = K.Texto(a, "encabezado", "texto")
	a.Texto = K.Texto(a, "nota", "textoSuave")
	-- El botón no se llama "Cerrar": a:Cerrar(turno) (abajo) es la función para quitar el aviso.
	a.BotonCerrar = K.BotonIcono(a, "ic-cerrar", function() quitar(a) end, { tam = 18, icono = 9, ayuda = L["Cerrar"] })
	a.BotonCerrar:SetPoint("RIGHT", bf, "RIGHT", -4, 0)
	-- Entra: aparece y se desliza 16 px desde la derecha. Sale: se desvanece.
	local ag = a:CreateAnimationGroup()
	local alfa = ag:CreateAnimation("Alpha")
	alfa:SetFromAlpha(0)
	alfa:SetToAlpha(1)
	alfa:SetDuration(0.22)
	alfa:SetSmoothing("OUT")
	alfa:SetOrder(2)
	local oculto = ag:CreateAnimation("Alpha") -- (en el salto a la derecha, aún no se ve)
	oculto:SetFromAlpha(0)
	oculto:SetToAlpha(0)
	oculto:SetDuration(0)
	oculto:SetOrder(1)
	local ida = ag:CreateAnimation("Translation")
	ida:SetOffset(16, 0)
	ida:SetDuration(0)
	ida:SetOrder(1)
	local vuelta = ag:CreateAnimation("Translation")
	vuelta:SetOffset(-16, 0)
	vuelta:SetDuration(0.22)
	vuelta:SetSmoothing("OUT")
	vuelta:SetOrder(2)
	a.entrada = ag
	local sal = a:CreateAnimationGroup()
	local fuera = sal:CreateAnimation("Alpha")
	fuera:SetFromAlpha(1)
	fuera:SetToAlpha(0)
	fuera:SetDuration(0.16)
	fuera:SetSmoothing("IN")
	sal:SetScript("OnFinished", function()
		if a.alfaSaliendo and not a.alfaVivo then a:Hide() end
		a.alfaSaliendo = nil
	end)
	a.salida = sal
	function a:Cerrar(turno)
		if turno and turno ~= self.turno then return end
		if self.alfaVivo then quitar(self) end
	end
	-- Clic en el cuerpo: su acción, salvo la que abre algo del juego (con
	-- seguro): esa solo la hace su botón, con el clic del juego (K.Seguro).
	a:SetScript("OnClick", function(self)
		local ac = self.alfaAccion
		if ac and ac.alClic and not ac.seguro then K.Llamar(ac.alClic, self) quitar(self) end
	end)
	return a
end

-- 1.2.6: ¿lo dijo Lya? Para quien arma su aviso aparte (usa la ventanita):
-- si Lya lo dice, no hace falta el aviso. Nunca con un botón seguro.
function K.PorLya(o)
	if type(o) ~= "table" or (o.accion and o.accion.seguro) or type(K.AvisoPorLya) ~= "function" then return false end
	local ok, dijo = pcall(K.AvisoPorLya, o)
	return ok and dijo == true
end

-- 1.3.3 / 1.3.7: un aviso que se fue sin que lo tocaras (se acabó su tiempo
-- o lo quitó otro) queda en «Te perdiste esto» (N.Perdido, Momentos.lua),
-- salvo lo que pediste tú o lo que leíste con el ratón encima. Uno con una
-- acción (no segura) también avisa A.Fire("ALFA_AVISO_PERDIDO", o).
local function accionDe(o)
	local ac = type(o) == "table" and o.accion
	if type(ac) == "table" then return ac end
	local l = type(o) == "table" and o.acciones
	if type(l) == "table" and type(l[1]) == "table" then
		local b = l[1]
		return { texto = b.texto, alClic = b.alClic or b.fn, seguro = b.seguro }
	end
	return nil
end

local function perdido(a)
	local o = a and a.alfaO
	if a then a.alfaO = nil end
	if type(o) ~= "table" then return end
	local leido = a.alfaLeido
	a.alfaLeido = nil
	if leido then return end
	local ac = accionDe(o)
	if not o.alfaPedido and N.Perdido then
		pcall(N.Perdido, { titulo = o.titulo, texto = o.texto, icono = o.icono or (o.lobo and "ic-lobo") or nil,
			accion = ac, origen = o.origen or "aviso" })
	end
	if type(ac) ~= "table" or ac.seguro or type(ac.alClic) ~= "function" then return end
	if A and A.Fire then pcall(A.Fire, "ALFA_AVISO_PERDIDO", o) end
end

-- 1.3.7: cuatro prioridades (N.PRIORIDAD): 1 urgente, 2 importante, 3 útil, 4 detalle.
local function prioridadDe(o)
	if o.prioridad ~= nil and N.Prioridad then return N.Prioridad(o.prioridad) end
	if o.importante == "siempre" then return 1 end
	if o.importante then return 2 end
	if o.detalle then return 4 end
	return 3
end

local function esSeguro(o)
	if type(o.accion) == "table" and o.accion.seguro then return true end
	if type(o.boton) == "table" and o.boton.seguro then return true end
	if type(o.acciones) == "table" then
		for _, b in ipairs(o.acciones) do if type(b) == "table" and b.seguro then return true end end
	end
	return false
end

-- Cada aviso dura según lo largo de su texto: de 5 a 15 s.
local function duracionDe(o)
	if tonumber(o.duracion) then return tonumber(o.duracion) end
	local n = #(o.titulo or "") + #(o.texto or "")
	return max(5, min(15, floor(4 + n / 20 + 0.5)))
end

function K.AvisosLlenos()
	for _, x in ipairs(avisos) do if not x.alfaVivo then return false end end
	return #avisos >= MAX_AVISOS
end
function K.AvisosVivos()
	local n = 0
	for _, x in ipairs(avisos) do if x.alfaVivo then n = n + 1 end end
	return n
end

-- 58: un aviso importante dice qué hacer o dónde verlo. El banco lo revisa:
-- los que no traen ni botón ni o.donde quedan aquí.
K.AvisosSinQueHacer = {}

local enTurno = setmetatable({}, { __mode = "k" }) -- o -> true mientras sale de la cola

local function ponerBoton(a, campo, ac, x, y)
	local b = a[campo] or K.Boton(a, "", nil, { tipo = campo == "Boton" and "acento" or "secundario", tam = "chico" })
	a[campo] = b
	b:SetTexto(ac.texto or "")
	local fn = ac.alClic or ac.fn
	b.alClic = function() if fn then K.Llamar(fn, a) end quitar(a) end
	K.SeguroDe(b, ac)
	if ac.seguro then
		-- El clic lo hizo el juego (K.Seguro): después, lo de Alfa y se cierra.
		b.alfaTrasClic = function() if ac.trasClic then K.Llamar(ac.trasClic, a) end quitar(a) end
	else
		b.alfaTrasClic = nil
	end
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", a, "TOPLEFT", x, -y)
	b:Show()
	return K.num(b:GetWidth(), 80)
end

---------------------------------------------------------------------------
-- 1.3.8: únicos y juntos (pedidos de Toxic)
--   * Lo que ya salió por otro lado en los últimos VISTO s (N.YaSeVio,
--     Momentos.lua) no sale otra vez; o.suceso = clave: el primero que avisa
--     de ese suceso lo dice y los demás se callan (N.Suceso).
--   * Agrupar (mejora 8): los parecidos que llegan juntos (en JUNTOS s) van
--     en uno solo: los de un mismo o.grupo (con o.agrupar = fn(n, lista) ->
--     titulo, texto, p. ej. «3 misiones listas para entregar») o, sin grupo,
--     los de un mismo título sin botones: sus textos uno bajo otro (hasta 3 y
--     «y N más»). o.agrupar = false lo evita.
---------------------------------------------------------------------------
local VISTO, JUNTOS = 45, 5
K.AVISO_VISTO, K.AVISO_JUNTOS = VISTO, JUNTOS
local grupos = {}

local function esTexto(v) return type(v) == "string" and not (N.Secreto and N.Secreto(v)) end
local function textoDe(o)
	local t = esTexto(o.titulo) and o.titulo or ""
	local x = esTexto(o.texto) and o.texto or ""
	if t == "" then return x end
	if x == "" then return t end
	return t .. " " .. x
end

local function claveGrupo(o)
	if o.grupo ~= nil then return "g:" .. tostring(o.grupo) end
	if o.agrupar == false or o.accion or o.acciones or o.boton then return nil end
	if not esTexto(o.titulo) or o.titulo == "" then return nil end
	return "t:" .. o.titulo
end

local function agrupar(o)
	local c = claveGrupo(o)
	if not c then return o end
	local g = grupos[c]
	local t = GetTime()
	if not g or t - g.t > JUNTOS then return o end
	local lista = {}
	for _, x in ipairs(g.lista) do lista[#lista + 1] = x end
	lista[#lista + 1] = o
	local titulo, texto
	if type(o.agrupar) == "function" then
		local ok, t1, t2 = pcall(o.agrupar, #lista, lista)
		if ok and esTexto(t1) then titulo, texto = t1, t2 end
	end
	if not titulo then
		titulo = o.titulo
		local partes, ya = {}, {}
		for _, x in ipairs(lista) do
			local tx = x.texto
			if esTexto(tx) and tx ~= "" and not ya[tx] then ya[tx] = true partes[#partes + 1] = tx end
		end
		if #partes > 3 then
			local resto = #partes - 3
			partes = { partes[1], partes[2], partes[3], string.format(L["y %d más"], resto) }
		end
		texto = table.concat(partes, "\n")
	end
	local nuevo = {}
	for k, v in pairs(o) do nuevo[k] = v end
	nuevo.titulo, nuevo.texto = titulo, texto
	nuevo.alfaGrupo = { c = c, lista = lista }
	nuevo.duracion = nil
	-- El de antes deja su lugar (sin contar como perdido: sigue en el nuevo).
	local a = g.a
	if a and a.alfaVivo and a.turno == g.turno then
		a.alfaO = nil
		quitar(a)
	end
	return nuevo
end
K.AgruparAviso = agrupar -- (para el banco)

local function recordarGrupo(o, a)
	local c = o.alfaGrupo and o.alfaGrupo.c or claveGrupo(o)
	if not c then return end
	for k, g in pairs(grupos) do if GetTime() - g.t > 60 then grupos[k] = nil end end
	grupos[c] = { t = GetTime(), lista = o.alfaGrupo and o.alfaGrupo.lista or { o }, a = a, turno = a and a.turno }
end

function K.Aviso(o)
	o = o or {}
	-- 1.2.9: con Alfa sencillo (Modo.lua) no salen los avisos de detalle
	-- (o.detalle = true: lo que es bueno saber, pero no hace falta). -> false
	if o.detalle and N.Sencillo and N.Sencillo() then return false end
	-- 1.3.8: de qué módulo viene (se mira aquí, con la pila de quien lo pidió).
	if o.alfaFirma == nil and K.FirmaDe then
		local f, clave = K.FirmaDe(o)
		o.alfaFirma = clave or false
	end
	-- 1.3.8: un mensaje por suceso: lo que otro ya dijo (o.suceso) no se repite.
	if o.suceso ~= nil and not o.alfaSuceso and o.pedido ~= true then
		if N.Suceso and not N.Suceso(o.suceso, o.ventana) then return false end
		o.alfaSuceso = true
	end
	local seguro = esSeguro(o)
	-- 1.3.9 (67): el Centro de avisos (Ajustes > Estilo y sonido): cada tipo
	-- (la firma de su módulo) con su interruptor. Apagado, no sale (queda en
	-- la campanita); lo que pides tú, lo urgente y un botón seguro, sí.
	if o.pedido ~= true and not seguro and N.AvisoApagado and N.AvisoApagado(o) then
		if N.AvisoReciente then pcall(N.AvisoReciente, o, "apagado") end
		return false
	end
	-- 1.3.3: la entrada en silencio (Entrada.lua): al entrar al juego no sale
	-- nada; queda guardado para Hoy y Lya. Salvo lo que no puede esperar
	-- (o.alEntrar, o.importante = "siempre") y un botón seguro (abre algo del juego).
	if N.Entrando and N.Entrando() and not (o.alEntrar == true or o.importante == "siempre" or seguro) then
		if N.GuardarAlEntrar then
			local ac = accionDe(o)
			N.GuardarAlEntrar({ id = o.id or o.clave, titulo = o.titulo, texto = o.texto, icono = o.icono,
				accion = ac and not ac.seguro and ac or nil, origen = o.origen or "aviso" })
		end
		return nil
	end
	-- 1.3.7: lo que pediste tú sale ya; lo demás espera su momento (Momentos.lua).
	local pedido = o.pedido == true or (N.PidioJugador and N.PidioJugador()) or false
	o.alfaPedido = pedido or nil
	local prio = prioridadDe(o)
	-- No molestar (/alfa calma, /dnd): lo que no es urgente se guarda.
	if not pedido and prio >= 2 and not seguro and N.EnCalma and N.EnCalma() then
		if N.Perdido then pcall(N.Perdido, { titulo = o.titulo, texto = o.texto, icono = o.icono, accion = accionDe(o), origen = "calma" }) end
		return nil
	end
	if not pedido and N.Ocupado and N.AlLibre then
		local ocupado, motivo
		if enTurno[o] then
			ocupado, motivo = K.AvisosLlenos(), "lleno"
		else
			ocupado, motivo = N.Ocupado("aviso", prio)
		end
		-- Lo urgente no espera a que se haga lugar: el más viejo lo cede.
		if ocupado and not (motivo == "lleno" and prio == 1) then
			local clave = "aviso:" .. tostring(o.id or o.clave or ((o.titulo or "") .. "|" .. (o.texto or "")))
			N.AlLibre(clave, function()
				enTurno[o] = true
				local ok, err = pcall(K.Aviso, o)
				enTurno[o] = nil
				if not ok and geterrorhandler then geterrorhandler()(err) end
			end, prio, { tipo = "aviso", caduca = tonumber(o.caduca) or 900, alCaducar = function()
				if not pedido and N.Perdido then pcall(N.Perdido, { titulo = o.titulo, texto = o.texto, icono = o.icono, accion = accionDe(o) }) end
			end })
			return nil
		end
	end
	-- 1.2.5: con Lya a la vista, ella lo dice en su globo (K.AvisoPorLya, de
	-- Alfa_Lya) y no salen avisos por todos lados. Siempre el aviso: o.lya =
	-- false (quien usa la ventanita que se devuelve) o un botón seguro (abre
	-- una ventana del juego; el globo de Lya no puede).
	-- 1.3.8: lo mismo que ya salió (en otro aviso, un anuncio, Lya o el chat)
	-- no sale otra vez; y los parecidos que llegan juntos van en uno solo.
	-- (1.3.8 revisión) Nunca lo urgente (prioridad 1) ni lo importante
	-- «siempre»: un «Te atacan» que se repite tiene que salir otra vez.
	if not pedido and not seguro and prio > 1 and o.importante ~= "siempre"
		and N.YaSeVio and N.YaSeVio(textoDe(o), o.ventana or VISTO) then return false end
	if not pedido then o = agrupar(o) end
	-- 1.3.9 (68): lo que se repite mucho en la sesión se calla solo. La
	-- cuarta vez sale con «Ya te lo dije 3 veces» y «Seguir avisando»; las
	-- siguientes, solo en la campanita (Momentos.lua, N.Repeticion).
	-- (Uno que se juntó con otro que ya está a la vista no cuenta otra vez.)
	local juntado = o.alfaGrupo and #o.alfaGrupo.lista > 1
	if not pedido and not seguro and not juntado and prio > 1 and o.importante ~= "siempre" and N.Repeticion then
		local r, clave = N.Repeticion(o)
		if r == "callado" then
			if N.AvisoReciente then pcall(N.AvisoReciente, o, "callado") end
			return false
		elseif r == "ultima" then
			o = N.AvisoCallado(o, clave)
		end
	end
	if o.lya ~= false and not seguro and K.PorLya(o) then
		-- 1.3.7: lo que dijo Lya también queda en «Avisos» (la campanita), como visto.
		if N.AvisoReciente then pcall(N.AvisoReciente, o, "lya") end
		if N.Visto then N.Visto(textoDe(o), "aviso") end
		recordarGrupo(o, nil)
		return true
	end
	local a
	for _, x in ipairs(avisos) do if not x.alfaVivo then a = x break end end
	if not a then
		if #avisos >= MAX_AVISOS then
			a = avisos[#avisos] -- (lo que pediste tú o lo urgente) el más viejo cede su lugar
			table.remove(avisos, #avisos)
			perdido(a)
			local fn = a.alfaAlCerrar
			a.alfaAlCerrar, a.alfaVivo = nil, nil
			if fn then K.Llamar(fn, a) end
		else
			a = armarAviso()
		end
	else
		for i, x in ipairs(avisos) do if x == a then table.remove(avisos, i) break end end
	end
	table.insert(avisos, 1, a)
	local relleno = K.Tono(o.tono or "acento")
	-- 1.3.8: la franja lleva el color del módulo de donde viene (su firma);
	-- 1.4.0 (81): también la banda de arriba, con su ícono y su nombre. Sin
	-- firma conocida, la de Alfa. El ícono del aviso sigue diciendo el tono.
	local firma = K.FIRMAS and o.alfaFirma and K.FIRMAS[o.alfaFirma] or nil
	local fb = firma or (K.FIRMAS and K.FIRMAS.alfa) or { nombre = "Alfa", color = "acento", icono = "ic-lobo" }
	local colorFirma = (o.tono == "peligro" or (o.tono and o.tono ~= "acento" and not firma)) and relleno or fb.color
	K.ColorPlano(a.Franja, colorFirma)
	K.ColorPlano(a.Arriba, colorFirma)
	a.BandaFondo:Color(colorFirma, K.Clasico and K.Clasico() and 0.08 or 0.13)
	a.Firma:SetTexture(K.Ruta(fb.icono or "ic-lobo"))
	a.Firma:SetVertexColor(K.Color(colorFirma))
	a.Firma:Show()
	K.Escribir(a.FirmaNombre, K.Mayus and K.Mayus(L[fb.nombre or "Alfa"]) or L[fb.nombre or "Alfa"])
	a.FirmaNombre:SetTextColor(K.Color(colorFirma))
	a.FirmaFondo:Hide()
	-- El ícono y su baldosa: del color de su firma; con un tono propio (bien,
	-- cuidado, peligro), de ese tono.
	local tonoIcono = (o.tono == nil or o.tono == "acento") and colorFirma or relleno
	if o.lobo then a.Icono:SetTexture(K.Lobo(o.lobo)) else a.Icono:SetTexture(K.Ruta(o.icono or fb.icono or "ic-aviso")) end
	a.Icono:SetVertexColor(K.Color(tonoIcono))
	a.Icono:SetSize(o.lobo and 24 or 18, o.lobo and 24 or 18)
	a.Baldosa.caja:Estilo({ fondo = tonoIcono, borde = tonoIcono, alfaFondo = 0.14, alfaBorde = 0.35 })
	-- 1.4.0: con la temática por bando, su tira (madera o piedra) bajo la banda.
	if a.Tira then a.Tira:Pintar() end
	-- 1.3.9: una textura a color propia (el Lobo Malo de los errores): sin teñir.
	if type(o.textura) == "string" then
		a.Icono:SetTexture(o.textura)
		a.Icono:SetVertexColor(1, 1, 1, 1)
		a.Icono:SetSize(26, 26)
	end
	a.alfaFirma = o.alfaFirma or nil
	local x = ESP.m + BALDOSA_AVISO + ESP.m
	local tw = K.ANCHO.aviso - x - ESP.m - 2
	local y0 = BANDA_AVISO + ESP.s + 1
	K.Escribir(a.Titulo, o.titulo or "")
	a.Titulo:ClearAllPoints()
	a.Titulo:SetPoint("TOPLEFT", a, "TOPLEFT", x, -y0)
	-- 1.3.9 (98): el título en hasta 2 renglones y el texto en hasta 6: en
	-- alemán, francés o ruso un aviso de 3 renglones en español se cortaba
	-- (tools/banco/prueba_139_calidad.lua los mide en los 10 idiomas).
	local ht = (o.titulo or "") ~= "" and K.Parrafo(a.Titulo, tw, 2) or 0
	local y = y0 + ht
	K.Escribir(a.Texto, o.texto or "")
	if (o.texto or "") ~= "" then
		y = y + (ht > 0 and 3 or 0)
		a.Texto:ClearAllPoints()
		a.Texto:SetPoint("TOPLEFT", a, "TOPLEFT", x, -y)
		y = y + K.Parrafo(a.Texto, tw, 6)
	end
	-- Con un título corto y sin texto, el título se centra con la baldosa.
	if ht > 0 and (o.texto or "") == "" and ht < BALDOSA_AVISO then
		local dy = floor((BALDOSA_AVISO - ht) / 2)
		a.Titulo:ClearAllPoints()
		a.Titulo:SetPoint("TOPLEFT", a, "TOPLEFT", x, -(y0 + dy))
		y = y0 + BALDOSA_AVISO
	end
	y = max(y, y0 + BALDOSA_AVISO)
	-- Sus botones: o.accion, o.acciones (1.3.7: hasta dos, { texto, alClic | fn }).
	-- 1.4.0 (81): a la derecha, el principal al final; si no caben juntos,
	-- uno bajo otro (el principal arriba).
	local botones = {}
	if type(o.accion) == "table" then botones[1] = o.accion end
	if type(o.acciones) == "table" then
		for _, b in ipairs(o.acciones) do
			if #botones >= 2 then break end
			if type(b) == "table" and type(b.texto) == "string" then botones[#botones + 1] = b end
		end
	end
	a.alfaAccion = botones[1] and { texto = botones[1].texto, alClic = botones[1].alClic or botones[1].fn, seguro = botones[1].seguro } or nil
	if botones[1] then
		local by = y + ESP.m - 2
		local derecha = K.ANCHO.aviso - ESP.m
		local w1 = ponerBoton(a, "Boton", botones[1], x, by)
		if botones[2] then
			local w2 = ponerBoton(a, "Boton2", botones[2], x, by)
			if w1 + ESP.s + w2 <= K.ANCHO.aviso - x - ESP.m then
				a.Boton:ClearAllPoints()
				a.Boton:SetPoint("TOPLEFT", a, "TOPLEFT", derecha - w1, -by)
				a.Boton2:ClearAllPoints()
				a.Boton2:SetPoint("TOPLEFT", a, "TOPLEFT", derecha - w1 - ESP.s - w2, -by)
			else
				a.Boton:ClearAllPoints()
				a.Boton:SetPoint("TOPLEFT", a, "TOPLEFT", x, -by)
				a.Boton2:ClearAllPoints()
				a.Boton2:SetPoint("TOPLEFT", a, "TOPLEFT", x, -(by + ESP.xs + K.ALTO.botonChico))
				y = y + ESP.xs + K.ALTO.botonChico
			end
		else
			if a.Boton2 then a.Boton2:Hide() end
			if w1 <= K.ANCHO.aviso - x - ESP.m then
				a.Boton:ClearAllPoints()
				a.Boton:SetPoint("TOPLEFT", a, "TOPLEFT", derecha - w1, -by)
			end
		end
		y = y + ESP.m - 2 + K.ALTO.botonChico
	else
		if a.Boton then a.Boton:Hide() end
		if a.Boton2 then a.Boton2:Hide() end
	end
	a:SetHeight(y + ESP.m)
	-- (uno que se iba desvaneciendo y vuelve a usarse: entero)
	if a.salida then a.salida:Stop() end
	a.alfaSaliendo = nil
	a:SetAlpha(1)
	a.alfaVivo = true
	a.alfaLeido = nil
	a.alfaAlCerrar = o.alCerrar
	a.alfaO = o -- 1.3.3: para «Te perdiste esto» (N.Perdido y ALFA_AVISO_PERDIDO)
	a.alfaPrioridad = prio
	a.alfaTurno = (a.alfaTurno or 0) + 1
	a.turno = a.alfaTurno
	local turno = a.alfaTurno
	ratonAviso(a, not (InCombatLockdown and InCombatLockdown()))
	a:Show()
	a.entrada:Stop()
	a.entrada:Play()
	recolocar()
	-- 58: lo importante dice qué hacer (un botón) o dónde verlo (o.donde).
	if prio <= 2 and not botones[1] and not o.donde and not pedido then
		local l = K.AvisosSinQueHacer
		l[#l + 1] = o.titulo or o.texto or "?"
		while #l > 20 do table.remove(l, 1) end
	end
	-- 69: un sonido suave según su tipo (lo importante, o el que lo pide).
	-- 1.3.8 (mejora 7): sin un sonido propio, el corto de su módulo (lo útil
	-- también; los detalles, callados).
	-- (1.3.8 revisión) Lo urgente (prioridad 1 y 2) suena como siempre: la
	-- firma del módulo solo en lo normal (3; lo de detalle sigue sin sonido).
	if o.sonido == nil and firma and o.tono ~= "peligro" and prio == 3 and K.SonarFirma then
		K.SonarFirma(o.alfaFirma, prio)
	elseif o.sonido ~= false and (o.sonido or prio <= 2) and N.Sonar then
		local tipo = type(o.sonido) == "string" and o.sonido or (o.tono == "peligro" and "peligro") or (prio <= 2 and "importante") or "aviso"
		N.Sonar(tipo, prio)
	end
	if N.Visto then N.Visto(textoDe(o), "aviso") end
	recordarGrupo(o, a)
	if A and A.Fire then pcall(A.Fire, "ALFA_AVISO", o) end
	local function vencer()
		if not a.alfaVivo or a.alfaTurno ~= turno then return end
		-- Con el ratón encima (lo estás leyendo) o en plena pelea, espera.
		local encima = a.IsMouseOver and a:IsMouseOver()
		if encima then a.alfaLeido = true end
		if encima or (InCombatLockdown and InCombatLockdown()) then
			if C_Timer and C_Timer.After then C_Timer.After(2, vencer) end
			return
		end
		perdido(a) -- se acabó su tiempo sin que lo tocaras
		quitar(a)
	end
	if C_Timer and C_Timer.After then C_Timer.After(duracionDe(o), vencer) end
	if o.alMostrar then K.Llamar(o.alMostrar, a) end
	return a
end
