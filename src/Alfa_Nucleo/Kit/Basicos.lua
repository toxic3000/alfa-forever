-- Alfa - Kit: piezas básicas (toxic3000 / La Jauría). GPL-3.0.
--
--   K.Boton(padre, texto, alClic, opts)       primario, secundario, fantasma, peligro
--   K.BotonIcono(padre, icono, alClic, opts)  cuadrado, con su ayuda
--   K.Insignia(padre, texto, tono)            etiqueta corta de color
--   K.Interruptor(padre, opts)                encendido / apagado
--   K.Deslizador(padre, opts)                 un valor entre dos límites
--   K.Segmentos(padre, opts)                  píldoras o segmentos (elegir uno)
--   K.Buscador(padre, opts)                   campo de búsqueda
--   K.Desplegable(padre, opts)                elegir de una lista (K.Menu)
--   K.Progreso(padre, opts)                   barra de avance
--   K.Huellas(padre, opts)                    el avance con huellas del lobo
--   K.IconoObjeto(padre, tam)                 un objeto con el borde de su calidad
--   K.MostrarInfo / K.OcultarInfo / K.ConInfo el cuadro de información
-- Todas se pintan con tokens (Kit/Tokens.lua) y se repintan solas.

local _, N = ...
local K = N.Kit
local A = N.A
local L = K.L

local floor, ceil, max, min, type, ipairs, pairs = math.floor, math.ceil, math.max, math.min, type, ipairs, pairs

---------------------------------------------------------------------------
-- Ajustes ligados: un control con `clave` ("id.clave") lee A.Get y guarda
-- con A.Set; si el ajuste cambia en otra parte, se vuelve a leer.
---------------------------------------------------------------------------
local ligados = setmetatable({}, { __mode = "k" })

local function ligar(ctrl, clave)
	if type(clave) ~= "string" then return end
	ctrl.alfaClave = clave
	ligados[ctrl] = clave
end

local function leerAjuste(clave) return A and A.Get and A.Get(clave) end
local function guardarAjuste(clave, v) if A and A.Set then A.Set(clave, v) end end

if A and A.On then
	A.On("SETTING_CHANGED", function(path)
		if type(path) ~= "string" then return end
		for c, clave in pairs(ligados) do
			if path == "" or clave == path or clave:sub(1, #path + 1) == path .. "." then
				if c.Leer then K.Llamar(c.Leer, c) end
			end
		end
	end)
end

---------------------------------------------------------------------------
-- El cuadro de información (propio: no el del juego)
---------------------------------------------------------------------------
local info

local function armarInfo()
	local f = CreateFrame("Frame", "AlfaKitInfo", UIParent)
	f:SetFrameStrata("TOOLTIP")
	f:SetClampedToScreen(true)
	f.caja = K.Caja(f, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.control, rol = "panel" })
	f.Titulo = K.Texto(f, "encabezado", "texto")
	f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
	f.Cuerpo = K.Texto(f, "nota", "textoSuave")
	f:Hide()
	return f
end

-- Muestra el cuadro junto a `dueno`. texto: una cadena o una lista de líneas.
function K.MostrarInfo(dueno, titulo, texto, opts)
	if not dueno then return end
	info = info or armarInfo()
	opts = opts or {}
	if type(texto) == "table" then texto = table.concat(texto, "\n") end
	local ancho = opts.ancho or K.ANCHO.info
	local y = 10
	info.Titulo:SetShown(titulo ~= nil and titulo ~= "")
	if info.Titulo:IsShown() then
		K.Escribir(info.Titulo, titulo)
		info.Titulo:SetWidth(ancho - 24)
		info.Titulo:SetWordWrap(true)
		y = y + K.AltoTexto(info.Titulo) + 4
	end
	info.Cuerpo:SetShown(texto ~= nil and texto ~= "")
	if info.Cuerpo:IsShown() then
		K.Escribir(info.Cuerpo, texto)
		info.Cuerpo:ClearAllPoints()
		info.Cuerpo:SetPoint("TOPLEFT", info, "TOPLEFT", 12, -y)
		y = y + K.Parrafo(info.Cuerpo, ancho - 24)
	end
	info:SetSize(ancho, y + 10)
	info:SetScale(dueno.GetEffectiveScale and (dueno:GetEffectiveScale() / max(0.01, K.num(UIParent:GetEffectiveScale(), 1))) or 1)
	info:ClearAllPoints()
	local top = K.num(dueno:GetTop(), 0)
	local alto = K.num(UIParent:GetHeight(), 768)
	if top + y + 30 < alto then
		info:SetPoint("BOTTOM", dueno, "TOP", 0, 6)
	else
		info:SetPoint("TOP", dueno, "BOTTOM", 0, -6)
	end
	info.dueno = dueno
	info:Show()
end

function K.OcultarInfo(dueno)
	if info and (not dueno or info.dueno == dueno) then
		info:Hide()
		info.dueno = nil
	end
end

-- Información al pasar el ratón. titulo/texto: cadenas, o una función que
-- devuelve titulo, texto (se lee al mostrarse).
function K.ConInfo(marco, titulo, texto)
	marco.alfaInfo = { titulo, texto }
	if marco.alfaConInfo then return marco end
	marco.alfaConInfo = true
	marco:HookScript("OnEnter", function(self)
		local i = self.alfaInfo
		local t, x = i[1], i[2]
		if type(t) == "function" then t, x = t(self) end
		if (t and t ~= "") or (x and x ~= "") then K.MostrarInfo(self, t, x) end
	end)
	marco:HookScript("OnLeave", function(self) K.OcultarInfo(self) end)
	return marco
end

---------------------------------------------------------------------------
-- Líneas
---------------------------------------------------------------------------
function K.Linea(padre, color, vertical)
	local t = K.Plano(padre, color or "linea", "ARTWORK", 1)
	if vertical then t:SetWidth(K.Pixel(padre)) else t:SetHeight(K.Pixel(padre)) end
	return t
end

---------------------------------------------------------------------------
-- Botón
---------------------------------------------------------------------------
local TAM = {
	normal = { alto = K.ALTO.boton, pad = 16, rol = "boton", icono = 16, corte = K.CORTE.control },
	grande = { alto = K.ALTO.botonGrande, pad = 20, rol = "botonGrande", icono = 18, corte = K.CORTE.control },
	chico = { alto = K.ALTO.botonChico, pad = 10, rol = "pequeno", icono = 14, corte = K.CORTE.chico },
}

-- tipo -> estilo de caja, color del texto, alfa del velo al pasar el ratón
local ESTILO = {
	primario = { { fondo = "acento", borde = false }, "sobreAcento", 0.14 },
	secundario = { { fondo = "elevado", borde = "lineaFuerte" }, "texto", 0.06 },
	fantasma = { { fondo = false, borde = false }, "textoSuave", 0.06 },
	peligro = { { fondo = "peligroRelleno", alfaFondo = 0.16, borde = "peligroRelleno", alfaBorde = 0.55 }, "peligro", 0.06 },
	acento = { { fondo = "acento", alfaFondo = 0.12, borde = "acento", alfaBorde = 0.5 }, "acento", 0.06 },
}

-- Clásico WoW: el botón rojo del juego (UIPanelButtonTemplate: la izquierda
-- y la derecha de 12 y el centro de UI-Panel-Button-*, con su brillo al pasar
-- el ratón) y el texto en oro (GameFontNormal), blanco bajo el ratón.
local ROJO = {
	arriba = "Interface\\Buttons\\UI-Panel-Button-Up", abajo = "Interface\\Buttons\\UI-Panel-Button-Down",
	apagado = "Interface\\Buttons\\UI-Panel-Button-Disabled", brillo = "Interface\\Buttons\\UI-Panel-Button-Highlight",
}
local function botonRojo(b, on)
	if not on then
		if b.rojo then for i = 1, 3 do b.rojo[i]:Hide() end b.rojo.brillo:Hide() end
		return
	end
	if not b.rojo then
		local r = {}
		for i, c in ipairs({ { 0, 0.09375 }, { 0.09375, 0.53125 }, { 0.53125, 0.625 } }) do
			local t = b:CreateTexture(nil, "BACKGROUND", nil, -6)
			t:SetTexCoord(c[1], c[2], 0, 0.6875)
			r[i] = t
		end
		r[1]:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0); r[1]:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0); r[1]:SetWidth(12)
		r[3]:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0); r[3]:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0); r[3]:SetWidth(12)
		r[2]:SetPoint("TOPLEFT", r[1], "TOPRIGHT", 0, 0); r[2]:SetPoint("BOTTOMRIGHT", r[3], "BOTTOMLEFT", 0, 0)
		r.brillo = b:CreateTexture(nil, "HIGHLIGHT")
		r.brillo:SetTexture(ROJO.brillo)
		r.brillo:SetTexCoord(0, 0.625, 0, 0.6875)
		r.brillo:SetBlendMode("ADD")
		r.brillo:SetAllPoints(b)
		b.rojo = r
	end
	local activo = b:IsEnabled()
	local archivo = not activo and ROJO.apagado or (b.alfaAbajo and ROJO.abajo or ROJO.arriba)
	for i = 1, 3 do
		b.rojo[i]:SetTexture(archivo)
		b.rojo[i]:Show()
	end
	b.rojo.brillo:SetShown(activo and true or false)
end

local function pintarBoton(b)
	if K.Clasico() then
		local fantasma = b.alfaTipo == "fantasma"
		b.caja:Estilo({ fondo = false, borde = false })
		botonRojo(b, not fantasma)
		local color = b.alfaTipo == "peligro" and "peligro" or ((b.alfaSobre or b.alfaMarcado) and "texto" or "titulo")
		if not b:IsEnabled() then color = "textoTenue" end
		K.ColorTexto(b.Texto, color)
		if b.Icono then K.SetIcono(b.Icono, b.alfaIcono, color) end
		b.velo:Hide()
		return
	end
	botonRojo(b, false)
	local e = ESTILO[b.alfaTipo] or ESTILO.secundario
	local caja = {}
	for k, v in pairs(e[1]) do caja[k] = v end
	if caja.fondo == nil then caja.fondo = false end
	if caja.borde == nil then caja.borde = false end
	if b.alfaTipo == "secundario" and b.alfaSobre then caja.borde = "textoTenue" end
	b.caja:Estilo(caja)
	local color = e[2]
	if b.alfaTipo == "fantasma" and b.alfaSobre then color = "texto" end
	K.ColorTexto(b.Texto, color)
	if b.Icono then K.SetIcono(b.Icono, b.alfaIcono, color) end
	b.velo:RGBA(1, 1, 1, e[3])
	b.velo:SetShown(b.alfaSobre and b:IsEnabled() and true or false)
end

local function medirBoton(b)
	local t = TAM[b.alfaTam] or TAM.normal
	local w = K.AnchoTexto(b.Texto)
	local icono = b.alfaIcono and (t.icono + (w > 0 and 6 or 0)) or 0
	return max(b.alfaIcono and w == 0 and t.alto or 56, t.pad * 2 + icono + w)
end

local function acomodarBoton(b)
	local t = TAM[b.alfaTam] or TAM.normal
	b:SetHeight(t.alto)
	if not b.alfaAncho then b:SetWidth(medirBoton(b)) end
	local w = K.AnchoTexto(b.Texto)
	local icono = b.alfaIcono and (t.icono + (w > 0 and 6 or 0)) or 0
	local x = -(icono + w) / 2
	local dy = b.alfaAbajo and -1 or 0
	if b.Icono then
		b.Icono:SetShown(b.alfaIcono ~= nil)
		b.Icono:SetSize(t.icono, t.icono)
		b.Icono:ClearAllPoints()
		b.Icono:SetPoint("LEFT", b, "CENTER", floor(x + 0.5), dy)
	end
	b.Texto:ClearAllPoints()
	b.Texto:SetPoint("LEFT", b, "CENTER", floor(x + icono + 0.5), dy)
end

function K.Boton(padre, texto, alClic, opts)
	opts = opts or {}
	local b = CreateFrame("Button", nil, padre)
	b:RegisterForClicks("LeftButtonUp")
	b.alfaTipo, b.alfaTam, b.alfaIcono, b.alfaAncho = opts.tipo or "secundario", opts.tam or "normal", opts.icono, opts.ancho
	local t = TAM[b.alfaTam] or TAM.normal
	b.caja = K.Caja(b, { corte = t.corte })
	b.velo = K.Velo(b, t.corte)
	b.Texto = K.Texto(b, t.rol, "texto")
	if opts.icono or opts.conIcono then b.Icono = K.Icono(b, opts.icono or "ic-mas", t.icono) end
	K.Escribir(b.Texto, texto or "")
	b.alClic = alClic
	b:SetScript("OnClick", function(self, boton)
		if self.alClic then K.Llamar(self.alClic, self, boton) end
	end)
	b:SetScript("OnEnter", function(self) self.alfaSobre = true pintarBoton(self) end)
	b:SetScript("OnLeave", function(self) self.alfaSobre = nil pintarBoton(self) end)
	b:SetScript("OnMouseDown", function(self)
		if not self:IsEnabled() then return end
		self.alfaAbajo = true
		acomodarBoton(self)
		if self.rojo then botonRojo(self, K.Clasico() and self.alfaTipo ~= "fantasma") end
	end)
	b:SetScript("OnMouseUp", function(self)
		self.alfaAbajo = nil
		acomodarBoton(self)
		if self.rojo then botonRojo(self, K.Clasico() and self.alfaTipo ~= "fantasma") end
	end)
	if opts.ancho then b:SetWidth(opts.ancho) end
	if opts.ayuda then K.ConInfo(b, opts.ayudaTitulo, opts.ayuda) end

	function b:SetTexto(s)
		K.Escribir(self.Texto, s or "")
		acomodarBoton(self)
	end
	function b:SetTipo(tipo) self.alfaTipo = tipo pintarBoton(self) end
	function b:SetIcono(nombre)
		self.alfaIcono = nombre
		if nombre and not self.Icono then self.Icono = K.Icono(self, nombre, t.icono) end
		pintarBoton(self)
		acomodarBoton(self)
	end
	function b:SetActivo(on)
		if on == false then self:Disable() else self:Enable() end
		self:SetAlpha(on == false and 0.45 or 1)
		pintarBoton(self)
	end
	function b:AnchoNatural() return medirBoton(self) end
	function b:SetAncho(w) self.alfaAncho = w if w then self:SetWidth(w) end acomodarBoton(self) end

	K.Pintar(b, function(x) pintarBoton(x) acomodarBoton(x) end)
	return b
end

---------------------------------------------------------------------------
-- Atajo: la tecla (o el botón del mando) de una acción del juego. Clic y
-- pulsa una tecla (Esc cancela); clic derecho la quita. Una tecla que ya usa
-- otra acción pide un segundo clic. Captura y guarda con el servicio de
-- teclas del motor (Alfa.Gamepad: Capture, Bind, Unbind, WhoUses).
--   K.Atajo(padre, { accion = "CLICK AlfaPescaBoton:LeftButton", ancho = 160 })
---------------------------------------------------------------------------
local atajos = setmetatable({}, { __mode = "k" })

local function textoDeTecla(k)
	if type(k) ~= "string" or k == "" then return nil end
	if GetBindingText then
		local ok, t = pcall(GetBindingText, k)
		if ok and type(t) == "string" and t ~= "" then return t end
	end
	return k
end

function K.Atajo(padre, opts)
	opts = opts or {}
	local b = K.Boton(padre, "", nil, { tipo = "secundario", ancho = opts.ancho or 160 })
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.alfaAccion = opts.accion
	local function G() return A and A.Gamepad end
	function b:Leer()
		local g = G()
		local texto, color
		if self.alfaEsperando then
			texto, color = L["Pulsa una tecla…"], "acento"
		elseif self.alfaArmada then
			texto, color = L["Ya se usa: clic otra vez"], "peligro"
		elseif self.alfaDice then
			texto, color = self.alfaDice, "aviso"
		else
			local k = g and g.KeyText and g.KeyText(self.alfaAccion)
			if not k and GetBindingKey then
				local ok, k1 = pcall(GetBindingKey, self.alfaAccion)
				k = ok and textoDeTecla(k1) or nil
			end
			texto, color = k or L["Sin tecla"], k and "texto" or "textoTenue"
		end
		self:SetTexto(texto)
		K.ColorTexto(self.Texto, color)
		self:SetAncho(max(opts.ancho or 160, self:AnchoNatural()))
	end
	b.alClic = function(self, boton)
		local g = G()
		if not (g and g.Capture) or (InCombatLockdown and InCombatLockdown()) then return end
		if boton == "RightButton" then
			if g.IsCapturing and g.IsCapturing() then g.StopCapture(nil) return end
			self.alfaArmada, self.alfaDice = nil, nil
			g.Unbind(self.alfaAccion)
			self:Leer()
			return
		end
		if self.alfaArmada then
			local k = self.alfaArmada
			self.alfaArmada = nil
			if not g.Bind(self.alfaAccion, k) then self.alfaDice = L["El juego no aceptó esa tecla."] end
			self:Leer()
			return
		end
		self.alfaEsperando, self.alfaDice = true, nil
		self:Leer()
		g.Capture({
			chords = g.ChordAllowed and g.ChordAllowed(self.alfaAccion),
			say = function(t) self.alfaDice = t self:Leer() end,
			done = function(k)
				self.alfaEsperando, self.alfaDice = nil, nil
				if k then
					local quien = g.WhoUses and g.WhoUses(self.alfaAccion, k)
					if quien then
						self.alfaArmada = k
						self.alfaQuien = quien
						K.Despues(5, function() if self.alfaArmada == k then self.alfaArmada = nil self:Leer() end end)
					elseif not g.Bind(self.alfaAccion, k) then
						self.alfaDice = L["El juego no aceptó esa tecla."]
					end
				end
				self:Leer()
				if g.UpdateDriver then g.UpdateDriver() end
			end,
		})
	end
	K.ConInfo(b, function(self)
		local g = G()
		if self.alfaArmada and g and g.ConflictText and self.alfaQuien then
			return L["Esa tecla ya tiene dueño"], g.ConflictText(self.alfaArmada, self.alfaQuien)
		end
		return opts.titulo, L["Haz clic y pulsa la tecla que quieras (Esc cancela). Clic derecho la quita."]
	end)
	-- Abre la espera de tecla como si se hubiera hecho clic (para un botón "Elegir mi tecla").
	function b:Capturar() self.alClic(self, "LeftButton") end
	atajos[b] = true
	b:Leer()
	return b
end

if A and A.RegisterEvent then
	A.RegisterEvent("UPDATE_BINDINGS", function()
		for b in pairs(atajos) do if not b.alfaEsperando then K.Llamar(b.Leer, b) end end
	end)
end

---------------------------------------------------------------------------
-- Botón de ícono
---------------------------------------------------------------------------
local function pintarBotonIcono(b)
	local sec = b.alfaTipo == "secundario"
	b.caja:Estilo({ fondo = sec and "elevado" or false, borde = sec and (b.alfaSobre and "textoTenue" or "lineaFuerte") or false })
	local color = b.alfaColor or ((b.alfaSobre or b.alfaActivo) and "texto" or "textoSuave")
	if b.alfaActivo and not b.alfaColor then color = "acento" end
	K.SetIcono(b.Icono, b.alfaIcono, color)
	b.velo:SetShown(b.alfaSobre and b:IsEnabled() and true or false)
end

function K.BotonIcono(padre, icono, alClic, opts)
	opts = opts or {}
	local tam = opts.tam or 28
	local b = CreateFrame("Button", nil, padre)
	b:SetSize(tam, tam)
	b:RegisterForClicks("LeftButtonUp")
	b.alfaIcono, b.alfaTipo, b.alfaColor = icono, opts.tipo or "fantasma", opts.color
	b.caja = K.Caja(b, { corte = K.CORTE.chico })
	b.velo = K.Velo(b, K.CORTE.chico, 0.07)
	b.Icono = K.Icono(b, icono, opts.icono or floor(tam * 0.57 + 0.5))
	b.Icono:SetPoint("CENTER")
	b.alClic = alClic
	b:SetScript("OnClick", function(self, boton) if self.alClic then K.Llamar(self.alClic, self, boton) end end)
	b:SetScript("OnEnter", function(self) self.alfaSobre = true pintarBotonIcono(self) end)
	b:SetScript("OnLeave", function(self) self.alfaSobre = nil pintarBotonIcono(self) end)
	if opts.ayuda then K.ConInfo(b, opts.ayuda, opts.ayudaTexto) end
	function b:SetIcono(nombre) self.alfaIcono = nombre pintarBotonIcono(self) end
	function b:SetMarcado(on) self.alfaActivo = on and true or nil pintarBotonIcono(self) end
	K.Pintar(b, pintarBotonIcono)
	return b
end

---------------------------------------------------------------------------
-- Insignia
---------------------------------------------------------------------------
local function pintarInsignia(c)
	local relleno, texto = K.Tono(c.alfaTono)
	c.caja:Estilo({ fondo = relleno, alfaFondo = c.alfaLleno and 1 or 0.16, borde = relleno, alfaBorde = c.alfaLleno and 1 or 0.45 })
	local color = c.alfaLleno and "sobreAcento" or texto
	K.ColorTexto(c.Texto, color)
	if c.Icono then K.SetIcono(c.Icono, c.alfaIcono, color) end
end

function K.Insignia(padre, texto, tono, opts)
	opts = opts or {}
	local c = CreateFrame("Frame", nil, padre)
	c:SetHeight(K.ALTO.insignia)
	c.caja = K.Caja(c, { corte = K.CORTE.chico })
	c.Texto = K.Texto(c, "insignia", "texto")
	c.Texto:SetPoint("LEFT", c, "LEFT", 8, 0)
	c.alfaLleno = opts.lleno
	function c:Set(s, t, icono)
		self.alfaTono, self.alfaIcono = t or self.alfaTono or "neutro", icono
		if icono and not self.Icono then
			self.Icono = K.Icono(self, icono, 12)
			self.Icono:SetPoint("LEFT", self, "LEFT", 7, 0)
		end
		if self.Icono then self.Icono:SetShown(icono ~= nil) end
		K.Escribir(self.Texto, s or "")
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("LEFT", self, "LEFT", icono and 23 or 8, 0)
		local w = K.Ajustar(self.Texto) + (icono and 31 or 16)
		self:SetWidth(w)
		pintarInsignia(self)
		self:SetShown(s ~= nil and s ~= "")
		return w
	end
	K.Pintar(c, pintarInsignia)
	c:Set(texto, tono, opts.icono)
	return c
end

---------------------------------------------------------------------------
-- Interruptor
---------------------------------------------------------------------------
local function pintarInterruptor(s)
	local on = s.alfaValor
	s.caja:Estilo({ fondo = on and "acento" or "hundido", borde = on and false or (s.alfaSobre and "textoTenue" or "lineaFuerte") })
	s.Perilla:SetVertexColor(K.Color(on and "sobreAcento" or "textoSuave"))
	s.Perilla:ClearAllPoints()
	if on then s.Perilla:SetPoint("RIGHT", s, "RIGHT", -3, 0) else s.Perilla:SetPoint("LEFT", s, "LEFT", 3, 0) end
end

-- Un control lee su valor de su `get` propio, si no de su `clave`; guarda con
-- su `set` propio, si no en su `clave`. Sin ninguno, solo su valor y alCambiar.
local function leerControl(c)
	if c.alfaGet then
		local ok, v = pcall(c.alfaGet)
		if ok then return true, v end
		if geterrorhandler then geterrorhandler()(v) end
		return false
	end
	if c.alfaClave then return true, leerAjuste(c.alfaClave) end
	return false
end

local function guardarControl(c, v)
	if c.alfaSet then K.Llamar(c.alfaSet, v, c)
	elseif c.alfaClave then guardarAjuste(c.alfaClave, v) end
end

-- Apagar o encender un control que no es un botón (se atenúa y no responde).
local function activoDe(c, on)
	c.alfaApagado = on == false or nil
	c:SetAlpha(on == false and 0.45 or 1)
end

-- opts = { valor, clave ("id.clave"), get = fn() -> valor, set = fn(valor), alCambiar = fn(valor), ayuda }
function K.Interruptor(padre, opts)
	opts = opts or {}
	local s = CreateFrame("Button", nil, padre)
	s:SetSize(36, K.ALTO.interruptor)
	s:RegisterForClicks("LeftButtonUp")
	s.caja = K.Caja(s, { corte = K.CORTE.chico })
	s.Perilla = s:CreateTexture(nil, "ARTWORK")
	s.Perilla:SetTexture(K.Ruta("knob"))
	s.Perilla:SetSize(14, 14)
	s.alCambiar = opts.alCambiar
	s.alfaGet, s.alfaSet = opts.get, opts.set
	function s:SetValor(v) self.alfaValor = v and true or false pintarInterruptor(self) end
	function s:Valor() return self.alfaValor end
	function s:Leer()
		local ok, v = leerControl(self)
		if ok then self:SetValor(v) end
	end
	function s:SetActivo(on)
		if on == false then self:Disable() else self:Enable() end
		self:SetAlpha(on == false and 0.45 or 1)
	end
	s:SetScript("OnClick", function(self)
		local v = not self.alfaValor
		self:SetValor(v)
		guardarControl(self, v)
		if self.alCambiar then K.Llamar(self.alCambiar, v, self) end
	end)
	s:SetScript("OnEnter", function(self) self.alfaSobre = true pintarInterruptor(self) end)
	s:SetScript("OnLeave", function(self) self.alfaSobre = nil pintarInterruptor(self) end)
	ligar(s, opts.clave)
	if opts.ayuda then K.ConInfo(s, nil, opts.ayuda) end
	s.alfaValor = opts.valor and true or false
	local ok, v = leerControl(s)
	if ok then s.alfaValor = v and true or false end
	K.Pintar(s, pintarInterruptor)
	return s
end

---------------------------------------------------------------------------
-- Deslizador
---------------------------------------------------------------------------
local function redondear(v, paso, a)
	if not paso or paso <= 0 then return v end
	return a + floor((v - a) / paso + 0.5) * paso
end

local function rellenoDeslizador(d)
	local a, b = d.alfaMin, d.alfaMax
	local w = K.num(d.Barra:GetWidth(), 0)
	local frac = b > a and (d.alfaValor - a) / (b - a) or 0
	frac = max(0, min(1, frac))
	d.Relleno:SetWidth(max(0.01, w * frac))
	d.Cifra:SetText(d.alfaFormato and d.alfaFormato(d.alfaValor) or tostring(d.alfaValor))
end

-- opts = { min, max, paso, valor, formato = fn(v) -> texto, clave, get, set, alCambiar = fn(v), ancho }
function K.Deslizador(padre, opts)
	opts = opts or {}
	local d = CreateFrame("Frame", nil, padre)
	d:SetSize(opts.ancho or 200, K.ALTO.control)
	d.alfaMin, d.alfaMax, d.alfaPaso = opts.min or 0, opts.max or 1, opts.paso or 0.05
	d.alfaFormato, d.alCambiar = opts.formato, opts.alCambiar
	d.alfaGet, d.alfaSet = opts.get, opts.set
	d.Cifra = K.Texto(d, "numero", "texto")
	d.Cifra:SetJustifyH("RIGHT")
	d.Cifra:SetPoint("RIGHT", d, "RIGHT", 0, 0)
	d.Cifra:SetWidth(52)
	local s = CreateFrame("Slider", nil, d)
	d.Barra = s
	s:SetOrientation("HORIZONTAL")
	s:SetHeight(16)
	s:SetPoint("LEFT", d, "LEFT", 0, 0)
	s:SetPoint("RIGHT", d.Cifra, "LEFT", -12, 0)
	s:SetMinMaxValues(d.alfaMin, d.alfaMax)
	s:SetValueStep(d.alfaPaso)
	s:SetObeyStepOnDrag(true)
	s:SetHitRectInsets(-4, -4, -8, -8)
	s:SetThumbTexture(K.Ruta("knob"))
	local pulgar = s.GetThumbTexture and s:GetThumbTexture()
	if pulgar then
		pulgar:SetSize(14, 14)
		K.Pintar(pulgar, function(t) t:SetVertexColor(K.Color("acento")) end)
	end
	d.Pista = K.Plano(s, "elevado", "BACKGROUND", 0)
	d.Pista:SetHeight(4)
	d.Pista:SetPoint("LEFT", s, "LEFT", 0, 0)
	d.Pista:SetPoint("RIGHT", s, "RIGHT", 0, 0)
	d.Relleno = K.Plano(s, "acento", "BACKGROUND", 1)
	d.Relleno:SetHeight(4)
	d.Relleno:SetPoint("LEFT", s, "LEFT", 0, 0)
	s:SetScript("OnValueChanged", function(_, v)
		if d.alfaQuieto then return end
		v = redondear(v, d.alfaPaso, d.alfaMin)
		if v == d.alfaValor then return end
		d.alfaValor = v
		rellenoDeslizador(d)
		guardarControl(d, v)
		if d.alCambiar then K.Llamar(d.alCambiar, v, d) end
	end)
	s:SetScript("OnSizeChanged", function() rellenoDeslizador(d) end)
	function d:SetValor(v)
		v = tonumber(v) or self.alfaMin
		self.alfaValor = max(self.alfaMin, min(self.alfaMax, v))
		self.alfaQuieto = true
		self.Barra:SetValue(self.alfaValor)
		self.alfaQuieto = nil
		rellenoDeslizador(self)
	end
	function d:Valor() return self.alfaValor end
	function d:Leer()
		local ok, v = leerControl(self)
		if ok then self:SetValor(v) end
	end
	function d:SetActivo(on)
		if on == false then self.Barra:Disable() else self.Barra:Enable() end
		self:SetAlpha(on == false and 0.45 or 1)
	end
	function d:Acomodar(ancho)
		self:SetWidth(ancho)
		rellenoDeslizador(self)
		return K.ALTO.control
	end
	ligar(d, opts.clave)
	local ok, v = leerControl(d)
	d:SetValor(ok and v or opts.valor)
	K.Pintar(d, rellenoDeslizador)
	return d
end

---------------------------------------------------------------------------
-- Segmentos y píldoras: elegir uno de pocos.
--   opts = { opciones = { { valor, texto, icono, cuenta } }, valor, alCambiar = fn(valor),
--            estilo = "pildoras" | "segmentos" }
--   seg:SetOpciones(lista), seg:SetValor(v), seg:Valor(), seg:Acomodar(ancho) -> alto, anchoUsado
---------------------------------------------------------------------------
local function pintarSegmento(b)
	local seg = b.alfaGrupo
	local on = seg.alfaValor ~= nil and b.alfaValorOpcion == seg.alfaValor
	if seg.alfaEstilo == "segmentos" then
		b.caja:Estilo({ fondo = on and "elevado" or false, borde = false })
		b.Barra:SetShown(on)
	else
		b.caja:Estilo({ fondo = on and "acento" or false, alfaFondo = 0.14, borde = on and "acento" or "linea", alfaBorde = on and 0.7 or 1 })
	end
	local color = on and "texto" or (b.alfaSobre and "texto" or "textoSuave")
	K.ColorTexto(b.Texto, color)
	if b.Icono then K.SetIcono(b.Icono, b.alfaIconoOpcion, on and "acento" or color) end
	b.velo:SetShown(b.alfaSobre and not on and true or false)
end

local function botonSegmento(seg, i)
	local b = seg.botones[i]
	if b then return b end
	b = CreateFrame("Button", nil, seg)
	b:RegisterForClicks("LeftButtonUp")
	b.alfaGrupo = seg
	local corte = seg.alfaEstilo == "segmentos" and 0 or K.CORTE.chico
	b.caja = K.Caja(b, { corte = corte })
	b.velo = K.Velo(b, corte, 0.05)
	b.Texto = K.Texto(b, "insignia", "textoSuave")
	b.Cuenta = K.Texto(b, "pequeno", "textoTenue")
	b.Barra = K.Plano(b, "acento", "ARTWORK", 2)
	b.Barra:SetHeight(2)
	b.Barra:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 6, 0)
	b.Barra:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 0)
	b.Barra:Hide()
	b:SetScript("OnClick", function(self)
		local g = self.alfaGrupo
		if g.alfaValor == self.alfaValorOpcion then return end
		g:SetValor(self.alfaValorOpcion)
		if g.alCambiar then K.Llamar(g.alCambiar, self.alfaValorOpcion, g) end
	end)
	b:SetScript("OnEnter", function(self) self.alfaSobre = true pintarSegmento(self) end)
	b:SetScript("OnLeave", function(self) self.alfaSobre = nil pintarSegmento(self) end)
	K.Pintar(b, pintarSegmento)
	seg.botones[i] = b
	return b
end

function K.Segmentos(padre, opts)
	opts = opts or {}
	local seg = CreateFrame("Frame", nil, padre)
	seg.botones = {}
	seg.alfaEstilo = opts.estilo or "pildoras"
	seg.alCambiar = opts.alCambiar
	if seg.alfaEstilo == "segmentos" then
		seg.caja = K.Caja(seg, { fondo = "hundido", borde = "linea", corte = K.CORTE.control })
	end
	function seg:SetOpciones(lista)
		self.opciones = lista or {}
		for i, o in ipairs(self.opciones) do
			local b = botonSegmento(self, i)
			b.alfaValorOpcion, b.alfaIconoOpcion = o.valor, o.icono
			if o.icono and not b.Icono then b.Icono = K.Icono(b, o.icono, 14) end
			if b.Icono then b.Icono:SetShown(o.icono ~= nil) end
			K.Escribir(b.Texto, o.texto or tostring(o.valor))
			b.Cuenta:SetText(o.cuenta ~= nil and tostring(o.cuenta) or "")
			if o.ayuda then K.ConInfo(b, o.texto, o.ayuda) end
		end
		for i = #self.opciones + 1, #self.botones do self.botones[i]:Hide() end
	end
	function seg:SetValor(v)
		self.alfaValor = v
		for _, b in ipairs(self.botones) do pintarSegmento(b) end
	end
	function seg:Valor() return self.alfaValor end
	function seg:SetActivo(on)
		activoDe(self, on)
		for _, b in ipairs(self.botones) do if on == false then b:Disable() else b:Enable() end end
	end
	function seg:Acomodar(ancho)
		local alto = self.alfaEstilo == "segmentos" and K.ALTO.control or K.ALTO.pildora
		local dentro = self.alfaEstilo == "segmentos" and 3 or 0
		local gap = self.alfaEstilo == "segmentos" and 2 or 6
		local x, y, fila = dentro, dentro, 0
		for i, o in ipairs(self.opciones) do
			local b = self.botones[i]
			local iw = o.icono and 18 or 0
			local tw = K.Ajustar(b.Texto)
			local cw = (o.cuenta ~= nil) and (K.Ajustar(b.Cuenta) + 6) or 0
			local w = 12 + iw + tw + cw + 12
			local h = alto - dentro * 2
			if self.alfaEstilo ~= "segmentos" and x > 0 and ancho and x + w > ancho then
				x, fila = 0, fila + 1
				y = fila * (alto + 6)
			end
			b:SetSize(w, h)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			if b.Icono then b.Icono:ClearAllPoints() b.Icono:SetPoint("LEFT", b, "LEFT", 12, 0) end
			b.Texto:ClearAllPoints()
			b.Texto:SetPoint("LEFT", b, "LEFT", 12 + iw, 0)
			b.Cuenta:ClearAllPoints()
			b.Cuenta:SetPoint("LEFT", b.Texto, "RIGHT", 6, 0)
			b.Cuenta:SetShown(o.cuenta ~= nil)
			b:Show()
			pintarSegmento(b)
			x = x + w + gap
		end
		local usado = max(0, x - gap + dentro)
		local total = (fila + 1) * alto + fila * 6
		self:SetSize(max(1, usado), total)
		return total, usado
	end
	seg:SetOpciones(opts.opciones)
	seg:SetValor(opts.valor)
	return seg
end

---------------------------------------------------------------------------
-- Buscador
--   opts = { ayuda = "Buscar...", alCambiar = fn(texto), alEnter = fn(texto), retraso = 0.2 }
---------------------------------------------------------------------------
local function pintarBuscador(b)
	b.caja:Estilo({ fondo = "hundido", borde = b.alfaFoco and "acento" or (b.alfaSobre and "textoTenue" or "lineaFuerte"), alfaBorde = b.alfaFoco and 0.8 or 1 })
	K.SetIcono(b.Lupa, "ic-buscar", b.alfaFoco and "acento" or "textoTenue")
	b.Campo:SetTextColor(K.Color("texto"))
	K.FuenteSegura(b.Campo, K.Cara("medium"), K.Tamano("cuerpo"), "")
end

function K.Buscador(padre, opts)
	opts = opts or {}
	local b = CreateFrame("Frame", nil, padre)
	b:SetHeight(K.ALTO.control)
	b.caja = K.Caja(b, { corte = K.CORTE.control })
	b.Lupa = K.Icono(b, "ic-buscar", 14, "textoTenue")
	b.Lupa:SetPoint("LEFT", b, "LEFT", 11, 0)
	local e = CreateFrame("EditBox", nil, b)
	b.Campo = e
	e:SetAutoFocus(false)
	e:SetPoint("LEFT", b, "LEFT", 32, 0)
	e:SetPoint("RIGHT", b, "RIGHT", -30, 0)
	e:SetHeight(K.ALTO.control - 4)
	K.FuenteSegura(e, K.Cara("medium"), K.Tamano("cuerpo"), "")
	e:SetMaxLetters(80)
	b.Ayuda = K.Texto(b, "nota", "textoTenue")
	b.Ayuda:SetPoint("LEFT", e, "LEFT", 1, 0)
	b.Ayuda:SetPoint("RIGHT", e, "RIGHT", 0, 0)
	K.Escribir(b.Ayuda, opts.ayuda or L["Buscar"])
	b.Limpiar = K.BotonIcono(b, "ic-cerrar", function()
		b:SetTexto("")
		e:SetFocus()
	end, { tam = 22, icono = 10, ayuda = L["Borrar la búsqueda"] })
	b.Limpiar:SetPoint("RIGHT", b, "RIGHT", -5, 0)
	b.Limpiar:Hide()
	b.alCambiar, b.alEnter = opts.alCambiar, opts.alEnter
	local retraso = opts.retraso or 0.2
	local function avisar()
		if b.alfaTimer then b.alfaTimer:Cancel() b.alfaTimer = nil end
		if not b.alCambiar then return end
		if retraso <= 0 then K.Llamar(b.alCambiar, b:Texto(), b) return end
		b.alfaTimer = K.Despues(retraso, function()
			b.alfaTimer = nil
			K.Llamar(b.alCambiar, b:Texto(), b)
		end)
	end
	e:SetScript("OnTextChanged", function(self, usuario)
		local t = self:GetText() or ""
		b.Ayuda:SetShown(t == "")
		b.Limpiar:SetShown(t ~= "")
		if b.alfaQuieto then return end
		avisar()
	end)
	e:SetScript("OnEnterPressed", function(self)
		if b.alfaTimer then b.alfaTimer:Cancel() b.alfaTimer = nil if b.alCambiar then K.Llamar(b.alCambiar, b:Texto(), b) end end
		if b.alEnter then K.Llamar(b.alEnter, b:Texto(), b) end
		self:ClearFocus()
	end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEditFocusGained", function() b.alfaFoco = true pintarBuscador(b) end)
	e:SetScript("OnEditFocusLost", function() b.alfaFoco = nil pintarBuscador(b) end)
	b:EnableMouse(true)
	b:SetScript("OnMouseDown", function() if not b.alfaApagado then e:SetFocus() end end)
	b:SetScript("OnEnter", function() b.alfaSobre = true pintarBuscador(b) end)
	b:SetScript("OnLeave", function() b.alfaSobre = nil pintarBuscador(b) end)
	function b:Texto() return strtrim and strtrim(self.Campo:GetText() or "") or (self.Campo:GetText() or "") end
	function b:SetTexto(t, quieto)
		self.alfaQuieto = quieto and true or nil
		self.Campo:SetText(t or "")
		self.alfaQuieto = nil
		self.Ayuda:SetShown((t or "") == "")
		self.Limpiar:SetShown((t or "") ~= "")
		if not quieto then avisar() end
	end
	function b:SetAyuda(t) K.Escribir(self.Ayuda, t) end
	function b:Foco() self.Campo:SetFocus() end
	function b:SetActivo(on)
		activoDe(self, on)
		self.Campo:EnableMouse(on ~= false)
		if on == false then self.Campo:ClearFocus() end
	end
	K.Pintar(b, pintarBuscador)
	return b
end

---------------------------------------------------------------------------
-- Menú (el de los desplegables): una lista que se cierra al hacer clic fuera.
--   K.Menu(dueno, opciones, valor, alElegir, ancho)
--   opciones = { { valor, texto, icono }, { separador = true },
--                { valor, texto, apagada = true, motivo = "por qué no se puede" } }
-- Un separador es una línea; una opción apagada se ve atenuada, no se elige y,
-- con motivo, lo dice en el cuadro de información al pasar el ratón.
---------------------------------------------------------------------------
local menu, atrapa

local function cerrarMenu()
	if menu then menu:Hide() end
	if atrapa then atrapa:Hide() end
end
K.CerrarMenu = cerrarMenu

local function armarMenu()
	atrapa = CreateFrame("Button", nil, UIParent)
	atrapa:SetAllPoints(UIParent)
	atrapa:SetFrameStrata("FULLSCREEN_DIALOG")
	atrapa:RegisterForClicks("AnyUp")
	atrapa:SetScript("OnClick", cerrarMenu)
	atrapa:Hide()
	menu = CreateFrame("Frame", "AlfaKitMenu", UIParent)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetFrameLevel(atrapa:GetFrameLevel() + 10)
	menu:SetClampedToScreen(true)
	menu.caja = K.Caja(menu, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.control, rol = "panel" })
	menu.lista = K.Lista(menu, {
		alto = K.ALTO.filaCompacta,
		crear = function(f)
			f.Icono = K.Icono(f, "ic-mas", 14)
			f.Icono:SetPoint("LEFT", f, "LEFT", 10, 0)
			f.Texto = K.Texto(f, "etiqueta", "texto")
			f.Marca = K.Icono(f, "ic-exito", 14, "acento")
			f.Marca:SetPoint("RIGHT", f, "RIGHT", -10, 0)
			f.Separador = K.Linea(f, "linea")
			f.Separador:SetPoint("LEFT", f, "LEFT", 8, 0)
			f.Separador:SetPoint("RIGHT", f, "RIGHT", -8, 0)
		end,
		pintar = function(f, o)
			local sep = o.separador and true or false
			-- Un separador o una opción apagada no se ilumina bajo el ratón (K.Lista).
			f.alfaInerte = (sep or o.apagada) and true or nil
			f.Separador:SetShown(sep)
			f.Texto:SetShown(not sep)
			f.Icono:SetShown(not sep and o.icono ~= nil)
			if o.icono and not sep then K.SetIcono(f.Icono, o.icono, o.apagada and "textoTenue" or "textoSuave") end
			f.Texto:ClearAllPoints()
			f.Texto:SetPoint("LEFT", f, "LEFT", o.icono and 32 or 12, 0)
			f.Texto:SetPoint("RIGHT", f.Marca, "LEFT", -8, 0)
			K.Escribir(f.Texto, sep and "" or (o.texto or tostring(o.valor)))
			K.ColorTexto(f.Texto, o.apagada and "textoTenue" or "texto")
			f.Texto:SetAlpha(o.apagada and 0.7 or 1)
			f.Marca:SetShown(not sep and menu.valor ~= nil and o.valor == menu.valor)
		end,
		alEntrar = function(f, o)
			if o and o.apagada and o.motivo and o.motivo ~= "" then K.MostrarInfo(f, o.texto, o.motivo) end
		end,
		alClic = function(o)
			if not o or o.separador or o.apagada then return end
			local fn = menu.alElegir
			cerrarMenu()
			if fn then K.Llamar(fn, o.valor, o) end
		end,
		elegir = false,
	})
	menu.lista:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4)
	menu:SetScript("OnHide", function() if atrapa then atrapa:Hide() end end)
	menu:Hide()
end

function K.Menu(dueno, opciones, valor, alElegir, ancho)
	if not menu then armarMenu() end
	if menu:IsShown() and menu.dueno == dueno then cerrarMenu() return end
	menu.dueno, menu.valor, menu.alElegir = dueno, valor, alElegir
	local n = #opciones
	local filas = min(n, 10)
	local w = max(ancho or 0, K.num(dueno:GetWidth(), 160))
	local h = filas * K.ALTO.filaCompacta
	menu:SetSize(w, h + 8)
	menu.lista:Acomodar(w - 8, h)
	menu.lista:SetDatos(opciones)
	for i, o in ipairs(opciones) do if o.valor ~= nil and o.valor == valor then menu.lista:IrA(i) end end
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", dueno, "BOTTOMLEFT", 0, -4)
	atrapa:Show()
	menu:Show()
end

---------------------------------------------------------------------------
-- Desplegable
--   opts = { opciones = { { valor, texto, icono } }, valor, alCambiar = fn(valor), clave, ancho }
---------------------------------------------------------------------------
local function pintarDesplegable(d)
	d.caja:Estilo({ fondo = "elevado", borde = d.alfaSobre and "textoTenue" or "lineaFuerte" })
	K.SetIcono(d.Flecha, "chevron-down", d.alfaSobre and "texto" or "textoSuave")
end

function K.Desplegable(padre, opts)
	opts = opts or {}
	local d = CreateFrame("Button", nil, padre)
	d:SetSize(opts.ancho or 180, K.ALTO.control)
	d:RegisterForClicks("LeftButtonUp")
	d.caja = K.Caja(d, { corte = K.CORTE.control })
	d.Texto = K.Texto(d, "etiqueta", "texto")
	d.Texto:SetPoint("LEFT", d, "LEFT", 12, 0)
	d.Flecha = K.Icono(d, "chevron-down", 12)
	d.Flecha:SetPoint("RIGHT", d, "RIGHT", -10, 0)
	d.Texto:SetPoint("RIGHT", d.Flecha, "LEFT", -8, 0)
	d.alCambiar = opts.alCambiar
	function d:SetOpciones(lista) self.opciones = lista or {} self:SetValor(self.alfaValor) end
	function d:SetValor(v)
		self.alfaValor = v
		local texto = ""
		for _, o in ipairs(self.opciones or {}) do if o.valor == v then texto = o.texto or tostring(v) end end
		K.Escribir(self.Texto, texto)
	end
	function d:Valor() return self.alfaValor end
	function d:Leer()
		local ok, v = leerControl(self)
		if ok then self:SetValor(v) end
	end
	function d:SetActivo(on)
		if on == false then self:Disable() else self:Enable() end
		self:SetAlpha(on == false and 0.45 or 1)
	end
	d:SetScript("OnClick", function(self)
		K.Menu(self, self.opciones or {}, self.alfaValor, function(v)
			self:SetValor(v)
			guardarControl(self, v)
			if self.alCambiar then K.Llamar(self.alCambiar, v, self) end
		end)
	end)
	d:SetScript("OnEnter", function(self) self.alfaSobre = true pintarDesplegable(self) end)
	d:SetScript("OnLeave", function(self) self.alfaSobre = nil pintarDesplegable(self) end)
	d.alfaGet, d.alfaSet = opts.get, opts.set
	ligar(d, opts.clave)
	d.opciones = opts.opciones or {}
	local ok, v = leerControl(d)
	d:SetValor(ok and v or opts.valor)
	K.Pintar(d, pintarDesplegable)
	return d
end

---------------------------------------------------------------------------
-- Barra de avance
--   opts = { alto = 6, tono = "acento", fondo = "hundido" }
--   barra:Set(fraccion) | barra:Set(actual, total), barra:Acomodar(ancho) -> alto
---------------------------------------------------------------------------
local function rellenoBarra(b)
	local w = K.num(b:GetWidth(), 0)
	b.Relleno:SetWidth(max(0.01, w * b.alfaFrac))
	b.Relleno:SetShown(b.alfaFrac > 0)
end

function K.Progreso(padre, opts)
	opts = opts or {}
	local b = CreateFrame("Frame", nil, padre)
	b:SetHeight(opts.alto or 6)
	b.Pista = K.Plano(b, opts.fondo or "hundido", "BACKGROUND", 0)
	b.Pista:SetAllPoints(b)
	b.Relleno = K.Plano(b, select(1, K.Tono(opts.tono or "acento")), "ARTWORK", 0)
	b.Relleno:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.Relleno:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	b.alfaFrac = 0
	function b:Set(a, total)
		local f = tonumber(a) or 0
		if total then f = (tonumber(total) or 0) > 0 and f / total or 0 end
		self.alfaFrac = max(0, min(1, f))
		rellenoBarra(self)
	end
	function b:SetTono(t) K.ColorPlano(self.Relleno, (K.Tono(t))) end
	function b:Acomodar(ancho)
		self:SetWidth(ancho)
		rellenoBarra(self)
		return K.num(self:GetHeight(), 6)
	end
	b:SetScript("OnSizeChanged", rellenoBarra)
	return b
end

---------------------------------------------------------------------------
-- Huellas: el avance como un rastro de huellas del lobo. Las hechas en el
-- acento, la de ahora late suave (una animación del cliente, sin OnUpdate) y
-- las que faltan en línea. Con más pasos que huellas, cada huella es una
-- parte del camino.
--   opts = { tam = 16, max = 10, gap = 4, tono = "acento" }
--   h:Set(actual, total) ; h:Acomodar() -> ancho, alto
---------------------------------------------------------------------------
local function huella(h, i)
	local t = h.huellas[i]
	if t then return t end
	t = h:CreateTexture(nil, "ARTWORK")
	t:SetTexture(K.Ruta("ic-huella"))
	local ag = t:CreateAnimationGroup()
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.35)
	a:SetDuration(0.9)
	a:SetSmoothing("IN_OUT")
	ag:SetLooping("BOUNCE")
	t.late = ag
	h.huellas[i] = t
	return t
end

local function pintarHuellas(h)
	local n, hechas = tonumber(h.alfaN) or 0, tonumber(h.alfaHechas) or 0
	for i = 1, n do
		local t = huella(h, i)
		local color = i <= hechas and (h.alfaTono or "acento") or (i == hechas + 1 and h.alfaSigue and (h.alfaTono or "acento") or "lineaFuerte")
		t:SetVertexColor(K.Color(color))
		if i == hechas + 1 and h.alfaSigue and h:IsVisible() then
			if not t.late:IsPlaying() then t.late:Play() end
		else
			t.late:Stop()
			t:SetAlpha(1)
		end
	end
end

function K.Huellas(padre, opts)
	opts = opts or {}
	local h = CreateFrame("Frame", nil, padre)
	h.huellas = {}
	h.alfaTam, h.alfaMax, h.alfaGap, h.alfaTono = opts.tam or 16, opts.max or 10, opts.gap or 4, opts.tono
	function h:Set(actual, total)
		actual, total = tonumber(actual) or 0, tonumber(total) or 0
		local n = total
		local hechas = actual
		if total > self.alfaMax or total <= 0 then
			n = self.alfaMax
			hechas = total > 0 and floor(actual / total * n + 0.0001) or 0
		end
		self.alfaN, self.alfaHechas = n, max(0, min(n, hechas))
		self.alfaSigue = actual < total
		for i = n + 1, #self.huellas do self.huellas[i]:Hide() self.huellas[i].late:Stop() end
		self:Acomodar()
		pintarHuellas(self)
	end
	-- Un rastro que camina: izquierda y derecha alternadas, un poco giradas.
	function h:Acomodar()
		local tam, gap = self.alfaTam, self.alfaGap
		local n = tonumber(self.alfaN) or 0
		for i = 1, n do
			local t = huella(self, i)
			t:SetSize(tam, tam)
			t:ClearAllPoints()
			local arriba = (i % 2 == 0) and floor(tam * 0.18) or -floor(tam * 0.18)
			t:SetPoint("LEFT", self, "LEFT", (i - 1) * (tam + gap), arriba)
			if t.SetRotation then t:SetRotation(i % 2 == 0 and -0.35 or -0.15) end
			t:Show()
		end
		local w = n > 0 and n * tam + (n - 1) * gap or 1
		local alto = floor(tam * 1.4)
		self:SetSize(w, alto)
		return w, alto
	end
	h:SetScript("OnShow", pintarHuellas)
	h:SetScript("OnHide", function(self) for _, t in ipairs(self.huellas) do t.late:Stop() end end)
	K.Pintar(h, pintarHuellas)
	h:Set(opts.actual or 0, opts.total or 5)
	return h
end

---------------------------------------------------------------------------
-- Ícono de objeto: el ícono del juego con el borde de su calidad, su
-- cantidad, el cuadro del juego al pasar el ratón y Mayús-clic para enlazarlo.
--   ic:SetObjeto(itemID | { id, icono, calidad, cantidad })
---------------------------------------------------------------------------
local esperando = setmetatable({}, { __mode = "k" }) -- ícono -> id que falta en la caché
local INTERROGACION = "Interface\\Icons\\INV_Misc_QuestionMark"

local function datosDeObjeto(id)
	local icono, calidad
	if C_Item and C_Item.GetItemIconByID then
		local ok, v = pcall(C_Item.GetItemIconByID, id)
		if ok then icono = v end
	end
	if not icono and GetItemIcon then
		local ok, v = pcall(GetItemIcon, id)
		if ok then icono = v end
	end
	if C_Item and C_Item.GetItemQualityByID then
		local ok, v = pcall(C_Item.GetItemQualityByID, id)
		if ok then calidad = v end
	end
	return icono, calidad
end

local function colorDeCalidad(q)
	if type(q) ~= "number" then return nil end
	if C_Item and C_Item.GetItemQualityColor then
		local ok, r, g, b = pcall(C_Item.GetItemQualityColor, q)
		if ok and type(r) == "number" then return r, g, b end
	end
	local t = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[q]
	if type(t) == "table" and type(t.r) == "number" then return t.r, t.g, t.b end
	return nil
end
K.ColorDeCalidad = colorDeCalidad

local function pintarObjeto(ic)
	local d = ic.alfaDato
	local r, g, b = colorDeCalidad(d and d.calidad)
	if r and (d.calidad or 0) >= 2 then
		ic.borde:Color({ r, g, b, 1 })
	else
		ic.borde:Color("lineaFuerte")
	end
end

function K.IconoObjeto(padre, tam)
	tam = tam or 36
	local ic = CreateFrame("Button", nil, padre)
	ic:SetSize(tam, tam)
	ic:RegisterForClicks("LeftButtonUp")
	ic.Fondo = K.Plano(ic, "hundido", "BACKGROUND", 0)
	ic.Fondo:SetAllPoints(ic)
	ic.Icono = ic:CreateTexture(nil, "ARTWORK")
	ic.Icono:SetPoint("TOPLEFT", ic, "TOPLEFT", 2, -2)
	ic.Icono:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", -2, 2)
	ic.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	ic.borde = K.Borde(ic, 0, "OVERLAY")
	ic.Cantidad = ic:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	K.FuenteSegura(ic.Cantidad, K.Cara("semibold"), max(9, floor(tam * 0.3)), "OUTLINE")
	ic.Cantidad:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", -2, 2)
	ic.Cantidad:SetJustifyH("RIGHT")
	function ic:SetObjeto(dato)
		if type(dato) == "number" then dato = { id = dato } end
		self.alfaDato = dato
		if not dato then self.Icono:SetTexture(nil) self.Cantidad:SetText("") pintarObjeto(self) return end
		if dato.id and (not dato.icono or not dato.calidad) then
			local icono, calidad = datosDeObjeto(dato.id)
			dato.icono = dato.icono or icono
			dato.calidad = dato.calidad or calidad
			if not icono then
				esperando[self] = dato.id
				local C = A and A.Compat
				if C and C.RequestItem then pcall(C.RequestItem, dato.id) end
			end
		end
		self.Icono:SetTexture(dato.icono or INTERROGACION)
		local n = tonumber(dato.cantidad)
		self.Cantidad:SetText(n and n > 1 and tostring(n) or "")
		pintarObjeto(self)
	end
	ic:SetScript("OnEnter", function(self)
		local d = self.alfaDato
		if not (d and d.id and GameTooltip) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink("item:" .. d.id)
		GameTooltip:Show()
	end)
	ic:SetScript("OnLeave", function(self)
		if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
	end)
	ic:SetScript("OnClick", function(self)
		local d = self.alfaDato
		if not (d and d.id and IsModifiedClick and IsModifiedClick()) then return end
		local C = A and A.Compat
		local link = C and C.ItemLink and C.ItemLink(d.id)
		if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
	end)
	K.Pintar(ic, pintarObjeto)
	return ic
end

-- Un objeto que llega a la caché del cliente: los íconos que lo esperaban se rehacen.
local eventos = CreateFrame("Frame")
eventos:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventos:SetScript("OnEvent", function(_, _, id, exito)
	id = tonumber(id)
	for ic, falta in pairs(esperando) do
		if falta == id then
			esperando[ic] = nil
			local d = ic.alfaDato
			-- exito == false: el cliente no tiene ese objeto. Se queda con el "?" y no
			-- se vuelve a pedir (si no, pide y responde sin fin).
			if exito ~= false and d and d.id == id then
				d.icono, d.calidad = nil, nil
				ic:SetObjeto(d)
			end
		end
	end
end)
