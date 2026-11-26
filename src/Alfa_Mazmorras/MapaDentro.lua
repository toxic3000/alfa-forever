-- Alfa - Mazmorras: el mapa por dentro (1.3.9). toxic3000 / La Jauría. GPL-3.0.
--
-- Pedido de Toxic: un mapa para hacer zoom dentro de la mazmorra y saber
-- dónde estás, con el mismo manejo que el mapa de Alfa (la rueda acerca,
-- arrastrar mueve, botones de pisos, centrar).
--
-- Lo que el juego da (documentación en referencia/, MapDocumentation.lua):
--   * C_Map.GetBestMapForUnit("player"): dentro de una instancia, el mapa de
--     la mazmorra si el juego tiene uno para ella (tipo Dungeon, 4); si no,
--     otro mapa (la zona de afuera) o nada. Alfa solo usa uno de tipo mazmorra.
--   * C_Map.GetMapGroupID / GetMapGroupMembersInfo: los pisos (cada uno es su
--     propio mapa, con su nombre y su altura).
--   * C_Map.GetMapArtLayers / GetMapArtLayerTextures: el arte del plano en
--     piezas (las mismas que pinta el mapa del juego).
--   * C_Map.GetPlayerMapPosition(mapa, "player"): «solo para el jugador y su
--     grupo»; dentro de las instancias el juego suele no darla (nil). Alfa no
--     inventa una posición: sin ella lo dice claro y marca tu avance por jefes.
-- Los datos de Alfa no traen dónde está cada jefe dentro de la mazmorra: los
-- jefes van como camino (el de Piezas.lua), no sobre el plano.
-- Ligero: el plano se arma al abrir la ventana o al cambiar de piso; la
-- flecha se mueve con un reloj chico (N.Cada) solo mientras la ventana está a
-- la vista y el juego da tu posición. En combate el plano no toma clics.
-- Se abre desde Mazmorras (dentro), desde el mapa del juego (un botón, solo
-- dentro de una instancia), con su tecla y como panel del Escritorio.
--   Md.Leer() -> s ; Md.Abrir() ; Md.Alternar() ; Md.Visible() ; Md.TextoAvance(key)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local D = M.D

local type, ipairs, pairs, pcall, tonumber, format = type, ipairs, pairs, pcall, tonumber, string.format
local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil
local ESP = K.ESP

local Md = {}
M.MapaDentro = Md

-- Enum.UIMapType.Dungeon = 4 (UIMapType en MapConstantsDocumentation.lua).
local DUNGEON = 4
do
	local E = Enum and Enum.UIMapType
	local d = type(E) == "table" and tonumber(rawget(E, "Dungeon")) or nil
	if d and d > 0 then DUNGEON = d end
end
local ZOOM_MAX = 4

local function leer(v) return D.Legible(v) end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function cmap(fn, ...)
	local C = C_Map
	if not (C and type(C[fn]) == "function") then return nil end
	local ok, a = pcall(C[fn], ...)
	if not ok then return nil end
	if N.Secreto and N.Secreto(a) then return nil end
	return a
end

local function enInstancia()
	if not IsInInstance then return false end
	local ok, si, tipo = pcall(IsInInstance)
	if not ok or (N.Secreto and N.Secreto(si)) then return false end
	return si == true, leer(tipo)
end

---------------------------------------------------------------------------
-- Lo que el juego dice
---------------------------------------------------------------------------
local function infoMapa(id)
	local info = id and cmap("GetMapInfo", id)
	return type(info) == "table" and info or nil
end

-- Los pisos de un mapa: { { mapa, nombre, altura } } (uno solo si no tiene pisos).
function Md.Pisos(mapa)
	local out = {}
	local grupo = mapa and cmap("GetMapGroupID", mapa)
	local miembros = type(grupo) == "number" and cmap("GetMapGroupMembersInfo", grupo)
	if type(miembros) == "table" then
		for _, x in ipairs(miembros) do
			if type(x) == "table" and type(x.mapID) == "number" then
				out[#out + 1] = { mapa = x.mapID, nombre = leer(x.name), altura = tonumber(x.relativeHeightIndex) or #out }
			end
		end
		table.sort(out, function(a, b) return a.altura < b.altura end)
	end
	if #out == 0 and mapa then
		local info = infoMapa(mapa)
		out[1] = { mapa = mapa, nombre = info and leer(info.name), altura = 0 }
	end
	for i, p in ipairs(out) do
		if type(p.nombre) ~= "string" or p.nombre == "" then p.nombre = format(L["Piso %d"], i) end
	end
	return out
end

-- El arte del plano -> { ancho, alto, tw, th, texturas } | nil
function Md.Arte(mapa)
	local capas = mapa and cmap("GetMapArtLayers", mapa)
	local c = type(capas) == "table" and capas[1]
	if type(c) ~= "table" then return nil end
	local w, h, tw, th = tonumber(c.layerWidth), tonumber(c.layerHeight), tonumber(c.tileWidth), tonumber(c.tileHeight)
	if not (w and h and tw and th and w > 0 and h > 0 and tw > 0 and th > 0) then return nil end
	local tex = cmap("GetMapArtLayerTextures", mapa, 1)
	if type(tex) ~= "table" or #tex == 0 then return nil end
	return { ancho = w, alto = h, tw = tw, th = th, texturas = tex }
end

-- Tu posición en ese mapa (0-1) o nil si el juego no la da.
function Md.Posicion(mapa)
	local p = mapa and cmap("GetPlayerMapPosition", mapa, "player")
	if p == nil then return nil end
	local x, y
	if type(p) == "table" and type(p.GetXY) == "function" then
		local ok, a, b = pcall(p.GetXY, p)
		if ok then x, y = a, b end
	elseif type(p) == "table" then
		x, y = p.x, p.y
	end
	if (N.Secreto and (N.Secreto(x) or N.Secreto(y))) then return nil end
	x, y = tonumber(x), tonumber(y)
	if not (x and y) or (x == 0 and y == 0) or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
	return x, y
end

---------------------------------------------------------------------------
-- 1.4.0 (44): los jefes en el plano, donde Alfa los conoce. Los datos de
-- Alfa no traen dónde está cada jefe por dentro, así que se aprende: al
-- empezar un encuentro (ENCOUNTER_START) con el plano de la mazmorra y tu
-- posición a la mano, ese lugar queda guardado para la cuenta
-- (AlfaNucleoDB.mazmorras.jefesPlano[mapa][jefe] = { x, y }). La siguiente
-- vez, el plano marca a cada jefe que ya conoce con su calavera y su nombre
-- (palomita si ya lo vencieron esta vez). Sin posición del juego, nada se
-- inventa. Nada se lee en combate más que el evento y tu posición (sin
-- secretos: N.Secreto).
--   Md.Jefes(mapa) -> { { nombre, x, y }, ... }   Md.Aprender(mapa, nombre, x, y)
---------------------------------------------------------------------------
local function guardados()
	local d = N.Datos(D.ID or "mazmorras")
	if type(d.jefesPlano) ~= "table" then d.jefesPlano = {} end
	return d.jefesPlano
end

function Md.Aprender(mapa, nombre, x, y)
	if type(mapa) ~= "number" or type(nombre) ~= "string" or nombre == "" or (N.Secreto and N.Secreto(nombre)) then return false end
	if type(x) ~= "number" or type(y) ~= "number" then return false end
	local g = guardados()
	g[mapa] = type(g[mapa]) == "table" and g[mapa] or {}
	g[mapa][nombre] = { x = math.floor(x * 1000 + 0.5) / 1000, y = math.floor(y * 1000 + 0.5) / 1000 }
	return true
end

function Md.Jefes(mapa)
	local out = {}
	local g = mapa and guardados()[mapa]
	if type(g) ~= "table" then return out end
	for nombre, p in pairs(g) do
		if type(p) == "table" and tonumber(p.x) and tonumber(p.y) then out[#out + 1] = { nombre = nombre, x = tonumber(p.x), y = tonumber(p.y) } end
	end
	table.sort(out, function(a, b) return a.nombre < b.nombre end)
	return out
end

local function rumbo()
	if not GetPlayerFacing then return nil end
	local ok, f = pcall(GetPlayerFacing)
	if not ok or (N.Secreto and N.Secreto(f)) then return nil end
	return tonumber(f)
end

-- «Vas entre el jefe 3 y el 4» (o lo que toque).
function Md.TextoAvance(key)
	if type(key) ~= "string" then return nil end
	local V = M.V
	local j, i
	if V and V.SiguienteJefe then j, i = V.SiguienteJefe(key) end
	local v, total = D.Cuenta(key)
	if total == 0 then return nil end
	if not j then return L["Ya vencieron a todos sus jefes."] end
	if v == 0 or (i or 1) <= 1 then return L["Vas camino al primer jefe."] end
	return format(L["Vas entre el jefe %d y el %d (%d de %d vencidos)."], i - 1, i, v, total)
end

-- Todo junto -> { dentro, key, nombre, mapa (de la mazmorra) | nil, pisos, piso, arte, x, y }
function Md.Leer(verMapa)
	local s = { dentro = false }
	local dentro = enInstancia()
	s.key = dentro and D.MazmorraActual() or nil
	s.dentro = dentro and s.key ~= nil
	if s.key then s.nombre = D.Nombre(s.key) end
	local mapa = cmap("GetBestMapForUnit", "player")
	local info = type(mapa) == "number" and infoMapa(mapa)
	if info and tonumber(leer(info.mapType)) == DUNGEON then s.mapa = mapa end
	if s.mapa then
		s.pisos = Md.Pisos(s.mapa)
		for i, p in ipairs(s.pisos) do if p.mapa == s.mapa then s.piso = i end end
	else
		s.pisos = {}
	end
	s.ver = verMapa or s.mapa
	s.arte = s.ver and Md.Arte(s.ver) or nil
	if s.mapa and s.ver == s.mapa then s.x, s.y = Md.Posicion(s.mapa) end
	return s
end

---------------------------------------------------------------------------
-- El plano: zoom con la rueda, arrastrar, centrar
---------------------------------------------------------------------------
-- Todos los planos (el de la ventana y los del Escritorio): en combate
-- ninguno toma el ratón (1.3.9, revisión 11).
local planos = setmetatable({}, { __mode = "k" })
local function ratonPlano(c, si)
	if not si then c.arrastre = nil if c.SetScript then c:SetScript("OnUpdate", nil) end end
	c:EnableMouse(si)
	if c.EnableMouseWheel then c:EnableMouseWheel(si) end
end

local function crearPlano(padre)
	local c = CreateFrame("Frame", nil, padre)
	planos[c] = true
	c.caja = K.Caja(c, { fondo = "hundido", borde = "linea", corte = K.CORTE.panel })
	if c.SetClipsChildren then c:SetClipsChildren(true) end
	c.Lienzo = CreateFrame("Frame", nil, c)
	c.Lienzo:SetSize(10, 10)
	c.piezas = {}
	c.zoom, c.ox, c.oy = 1, 0, 0
	c.Flecha = K.Icono(c.Lienzo, "ic-flecha", 22, "acento", "OVERLAY")
	c.Flecha:Hide()
	c.Vacio = K.Vacio(c, { lobo = "atento", titulo = "", texto = "" })
	c.Vacio:Hide()
	function c:Medidas()
		local w, h = K.num(self:GetWidth(), 1), K.num(self:GetHeight(), 1)
		local a = self.arte
		if not a then return w, h, 0, 0 end
		local s0 = min(w / a.ancho, h / a.alto)
		return w, h, a.ancho * s0 * self.zoom, a.alto * s0 * self.zoom
	end
	function c:Limitar()
		local w, h, lw, lh = self:Medidas()
		local mx, my = max(0, (lw - w) / 2), max(0, (lh - h) / 2)
		self.ox = max(-mx, min(mx, self.ox))
		self.oy = max(-my, min(my, self.oy))
	end
	function c:Colocar()
		local a = self.arte
		if not a then self.Lienzo:Hide() return end
		self:Limitar()
		local _, _, lw, lh = self:Medidas()
		self.Lienzo:ClearAllPoints()
		self.Lienzo:SetPoint("CENTER", self, "CENTER", self.ox, self.oy)
		self.Lienzo:SetSize(max(1, lw), max(1, lh))
		local s = lw / a.ancho
		local cols = ceil(a.ancho / a.tw)
		for i, t in ipairs(self.piezas) do
			if t:IsShown() then
				local col, fila = (i - 1) % cols, floor((i - 1) / cols)
				-- La última columna y la última fila se recortan al borde del plano.
				local fw = min(1, (a.ancho - col * a.tw) / a.tw)
				local fh = min(1, (a.alto - fila * a.th) / a.th)
				t:ClearAllPoints()
				if fw <= 0 or fh <= 0 then
					t:SetAlpha(0)
				else
					t:SetAlpha(1)
					t:SetPoint("TOPLEFT", self.Lienzo, "TOPLEFT", col * a.tw * s, -fila * a.th * s)
					t:SetSize(a.tw * s * fw, a.th * s * fh)
					t:SetTexCoord(0, fw, 0, fh)
				end
			end
		end
		self.Lienzo:Show()
		self:PonerFlecha()
		self:PonerJefes()
	end
	-- 1.4.0 (44): las calaveras de los jefes que Alfa ya conoce en este plano.
	c.jefes = {}
	function c:PonerJefes()
		local lista = self.arte and self.mapaArte and Md.Jefes(self.mapaArte) or {}
		local _, _, lw, lh = self:Medidas()
		for i, j in ipairs(lista) do
			local m = self.jefes[i]
			if not m then
				m = CreateFrame("Frame", nil, self.Lienzo)
				m:SetSize(18, 18)
				m.Icono = K.Icono(m, "ic-raros", 16, "peligro", "OVERLAY")
				m.Icono:SetPoint("CENTER")
				m.Nombre = K.Texto(m, "pequeno", "texto")
				m.Nombre:SetPoint("TOP", m, "BOTTOM", 0, -1)
				m.Nombre:SetWordWrap(false)
				self.jefes[i] = m
			end
			m:ClearAllPoints()
			m:SetPoint("CENTER", self.Lienzo, "TOPLEFT", j.x * lw, -j.y * lh)
			K.Escribir(m.Nombre, j.nombre)
			K.Ajustar(m.Nombre, 140)
			m:Show()
		end
		for i = #lista + 1, #self.jefes do self.jefes[i]:Hide() end
	end
	function c:PonerFlecha()
		local x, y = self.px, self.py
		if not (self.arte and x and y) then self.Flecha:Hide() return end
		local _, _, lw, lh = self:Medidas()
		self.Flecha:ClearAllPoints()
		self.Flecha:SetPoint("CENTER", self.Lienzo, "TOPLEFT", x * lw, -y * lh)
		local r = rumbo()
		if r and self.Flecha.SetRotation then self.Flecha:SetRotation(r) end
		self.Flecha:Show()
	end
	function c:SetArte(a)
		self.arte = a
		local n = a and #a.texturas or 0
		for i = 1, n do
			local t = self.piezas[i] or self.Lienzo:CreateTexture(nil, "ARTWORK")
			self.piezas[i] = t
			t:SetTexture(a.texturas[i])
			t:Show()
		end
		for i = n + 1, #self.piezas do self.piezas[i]:Hide() end
	end
	function c:Zoom(z, cx, cy)
		if not self.arte then return end
		local antes = self.zoom
		z = max(1, min(ZOOM_MAX, z))
		if z == antes then return end
		-- Que el punto bajo el ratón se quede bajo el ratón.
		cx, cy = cx or 0, cy or 0
		local f = z / antes
		self.ox = cx - (cx - self.ox) * f
		self.oy = cy - (cy - self.oy) * f
		self.zoom = z
		self:Colocar()
	end
	function c:Centrar()
		local _, _, lw, lh = self:Medidas()
		if self.px and self.py then
			if self.zoom < 2 then self.zoom = 2 _, _, lw, lh = self:Medidas() end
			self.ox, self.oy = (0.5 - self.px) * lw, (self.py - 0.5) * lh
		else
			self.zoom, self.ox, self.oy = 1, 0, 0
		end
		self:Colocar()
	end
	local function cursor(self)
		local x, y = GetCursorPosition()
		local e = self:GetEffectiveScale() or 1
		local l, b = self:GetLeft() or 0, self:GetBottom() or 0
		local w, h = K.num(self:GetWidth(), 1), K.num(self:GetHeight(), 1)
		return x / e - l - w / 2, y / e - b - h / 2
	end
	c:SetScript("OnMouseWheel", function(self, delta)
		if enCombate() then return end
		local x, y = cursor(self)
		self:Zoom(self.zoom * (delta > 0 and 1.25 or 0.8), x, y)
	end)
	c:SetScript("OnMouseDown", function(self, boton)
		if boton ~= "LeftButton" or not self.arte or enCombate() then return end
		local x, y = cursor(self)
		self.arrastre = { x = x, y = y, ox = self.ox, oy = self.oy }
		self:SetScript("OnUpdate", function(me)
			local a = me.arrastre
			if not a then me:SetScript("OnUpdate", nil) return end
			local nx, ny = cursor(me)
			me.ox, me.oy = a.ox + (nx - a.x), a.oy + (ny - a.y)
			me:Colocar()
		end)
	end)
	c:SetScript("OnMouseUp", function(self)
		self.arrastre = nil
		self:SetScript("OnUpdate", nil)
	end)
	c:SetScript("OnHide", function(self) self.arrastre = nil self:SetScript("OnUpdate", nil) end)
	-- 1.4.1: después de los scripts (ponerlos le prende ratón y rueda en el
	-- juego): armado en combate, no se queda con la rueda de la cámara.
	ratonPlano(c, not enCombate())
	return c
end
Md.CrearPlano = crearPlano

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local v, ui = nil, {}
local estado = { ver = nil }

local function pintar()
	if not (v and v:IsShown()) then return end
	local s = Md.Leer(estado.ver)
	ui.s = s
	estado.ver = s.ver
	v:SetTitulo(s.nombre or L["Mapa de la mazmorra"], s.dentro and L["El plano por dentro, con tu avance"] or L["Entra a una mazmorra para verla por dentro"], "ic-mazmorra")
	-- Los pisos.
	local ops = {}
	for _, p in ipairs(s.pisos) do ops[#ops + 1] = { valor = p.mapa, texto = p.nombre } end
	ui.pisos:SetOpciones(ops)
	ui.pisos:SetValor(s.ver)
	ui.pisos:SetShown(#ops > 1)
	ui.centrar:SetShown(s.arte ~= nil)
	ui.mas:SetShown(s.arte ~= nil)
	ui.menos:SetShown(s.arte ~= nil)
	-- El plano.
	local p = ui.plano
	if p.mapaArte ~= s.ver then
		p.mapaArte = s.ver
		p.zoom, p.ox, p.oy = 1, 0, 0
		p:SetArte(s.arte)
	end
	p.px, p.py = s.x, s.y
	if s.arte then
		p.Vacio:Hide()
		p:Colocar()
	else
		p:SetArte(nil)
		p.Lienzo:Hide()
		p.Flecha:Hide()
		local titulo, texto
		if not s.dentro then
			titulo, texto = L["No estás en una mazmorra"], L["Al entrar a una, aquí ves su plano (si el juego lo tiene) y por dónde vas."]
		else
			titulo, texto = L["El juego no trae el plano de esta mazmorra"], L["Abajo va su camino de jefes, marcado con lo que ya vencieron."]
		end
		p.Vacio:Set({ lobo = s.dentro and "atento" or "dormido", titulo = titulo, texto = texto })
		p.Vacio:Show()
	end
	-- Lo que se sabe de dónde vas.
	local partes = {}
	if s.dentro then
		if s.arte and not s.x then partes[#partes + 1] = L["Dentro de las mazmorras el juego no comparte tu posición."] end
		local nj = s.ver and #Md.Jefes(s.ver) or 0
		if s.arte and nj > 0 then partes[#partes + 1] = N.Plural(nj, L["%d jefe marcado donde lo encontraste."], L["%d jefes marcados donde los encontraste."]) end
		if s.piso and #s.pisos > 1 then partes[#partes + 1] = format(L["Estás en: %s."], s.pisos[s.piso].nombre) end
		local av = Md.TextoAvance(s.key)
		if av then partes[#partes + 1] = av end
	end
	K.Escribir(ui.estado, table.concat(partes, "  "))
	ui.jefes:Set(s.key and M.V and M.V.DatosMapa and M.V.DatosMapa(s.key) or {})
	-- La flecha se mueve sola solo si hay posición que mover.
	if s.x then N.Cada("mazmorras.mapaDentro", 0.25, Md.Latido) else N.Quitar("mazmorras.mapaDentro") end
	Md.Acomodar()
end
Md.Pintar = pintar

function Md.Latido()
	if not (v and v:IsShown() and ui.s and ui.s.mapa and ui.s.ver == ui.s.mapa) then N.Quitar("mazmorras.mapaDentro") return end
	local x, y = Md.Posicion(ui.s.mapa)
	ui.plano.px, ui.plano.py = x, y
	ui.plano:PonerFlecha()
end

function Md.Acomodar()
	if not (v and v:IsShown()) then return end
	local ancho, alto = v:AnchoCuerpo(), v:AltoCuerpo()
	local m = v.margen or ESP.base
	local y = ESP.base
	-- La barra: pisos a la izquierda, zoom y centrar a la derecha.
	ui.centrar:ClearAllPoints()
	ui.centrar:SetPoint("TOPRIGHT", v.Cuerpo, "TOPRIGHT", -m, -y)
	ui.mas:ClearAllPoints()
	ui.mas:SetPoint("RIGHT", ui.centrar, "LEFT", -ESP.s, 0)
	ui.menos:ClearAllPoints()
	ui.menos:SetPoint("RIGHT", ui.mas, "LEFT", -ESP.xs, 0)
	local derecha = (ui.centrar:IsShown() and (K.num(ui.centrar:GetWidth(), 0) + K.num(ui.mas:GetWidth(), 0) + K.num(ui.menos:GetWidth(), 0) + 3 * ESP.s)) or 0
	if ui.pisos:IsShown() then
		ui.pisos:Acomodar(ancho - derecha - ESP.base)
		ui.pisos:ClearAllPoints()
		ui.pisos:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", m, -y)
	end
	local barra = (ui.pisos:IsShown() or ui.centrar:IsShown()) and max(K.ALTO.control, K.num(ui.pisos:GetHeight(), 0)) or 0
	if barra > 0 then y = y + barra + ESP.s end
	-- Abajo: tu avance y el camino de jefes.
	local hJ = ui.jefes:Acomodar(ancho)
	local hE = K.Parrafo(ui.estado, ancho, 3)
	local abajo = hJ + (hE > 0 and (hE + ESP.s) or 0) + ESP.base
	local hp = max(140, alto - y - abajo - ESP.base)
	ui.plano:ClearAllPoints()
	ui.plano:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", m, -y)
	ui.plano:SetSize(ancho, hp)
	y = y + hp + ESP.s
	ui.estado:ClearAllPoints()
	ui.estado:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", m, -y)
	if hE > 0 then y = y + hE + ESP.s end
	ui.jefes:ClearAllPoints()
	ui.jefes:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", m, -y)
	local vh = ui.plano.Vacio:IsShown() and ui.plano.Vacio:Acomodar(ancho - 2 * ESP.l) or 0
	ui.plano.Vacio:ClearAllPoints()
	ui.plano.Vacio:SetPoint("TOP", ui.plano, "TOP", 0, -max(ESP.base, floor((hp - vh) / 2)))
	if ui.s and ui.s.arte then ui.plano:Colocar() end
end

local function armar()
	v = K.Ventana({ nombre = "AlfaMazmorraMapa", titulo = L["Mapa de la mazmorra"], icono = "ic-mazmorra", ancho = 720, alto = 600, capa = "MEDIUM" })
	v.alAcomodar = Md.Acomodar
	ui.pisos = K.Segmentos(v.Cuerpo, { estilo = "pildoras", opciones = {}, alCambiar = function(mapa)
		estado.ver = mapa
		pintar()
	end })
	ui.centrar = K.Boton(v.Cuerpo, L["Centrar"], function() ui.plano:Centrar() end,
		{ tipo = "secundario", tam = "chico", icono = "ic-flecha", ayuda = L["En ti, si el juego da tu posición; si no, el plano entero."] })
	ui.mas = K.Boton(v.Cuerpo, "+", function() ui.plano:Zoom(ui.plano.zoom * 1.25) end, { tipo = "secundario", tam = "chico", ayuda = L["Acercar (también con la rueda del ratón)"] })
	ui.menos = K.Boton(v.Cuerpo, "-", function() ui.plano:Zoom(ui.plano.zoom * 0.8) end, { tipo = "secundario", tam = "chico", ayuda = L["Alejar"] })
	ui.plano = crearPlano(v.Cuerpo)
	ui.estado = K.Texto(v.Cuerpo, "nota", "textoSuave")
	ui.jefes = M.Pz.MapaJefes(v.Cuerpo)
	v:HookScript("OnHide", function() N.Quitar("mazmorras.mapaDentro") end)
end

function Md.Abrir()
	if N.Permitido and not N.Permitido() then return false end
	if not v then armar() end
	estado.ver = nil
	v:Abrir()
	pintar()
	return true
end
function Md.Alternar() if v and v:IsShown() then v:Cerrar() else Md.Abrir() end end
function Md.Visible() return v ~= nil and v:IsShown() end
function Md.Ventana() return v end
function Md.Plano() return ui.plano end

-- Cambios: de piso o de zona, un jefe vencido.
local function cambio()
	if not Md.Visible() then return end
	N.Una("mazmorras.mapaDentroCambio", 0.5, function() estado.ver = nil pintar() end)
end
for _, ev in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_END", "BOSS_KILL" }) do
	pcall(A.RegisterEvent, ev, cambio)
end
-- En combate el plano no toma clics (ni la rueda ni arrastrar).
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() for c in pairs(planos) do ratonPlano(c, false) end end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() for c in pairs(planos) do ratonPlano(c, true) end end)
Md.Planos = planos -- (para el banco)

---------------------------------------------------------------------------
-- El botón en el mapa del juego (solo dentro de una mazmorra que Alfa conoce)
---------------------------------------------------------------------------
local boton
function Md.BotonMapaJuego()
	local W = rawget(_G, "WorldMapFrame")
	if not (W and W.HookScript) then return nil end
	if not boton then
		local host = W.ScrollContainer or W
		boton = K.Boton(W, L["Mapa de Alfa de esta mazmorra"], function() Md.Abrir() end,
			{ tipo = "acento", tam = "chico", icono = "ic-mazmorra", ayuda = L["Su plano con zoom, sus pisos y por dónde vas con tus jefes."] })
		boton:SetPoint("TOP", host, "TOP", 0, -8)
		boton:SetFrameLevel((host:GetFrameLevel() or 1) + 30)
		boton:Hide()
	end
	return boton
end

function Md.RevisarBotonMapa()
	local b = Md.BotonMapaJuego()
	if not b then return end
	local on = N.Get(D.ID, "mapaDentro") ~= false and enInstancia() and D.MazmorraActual() ~= nil
	b:SetShown(on and true or false)
end

A.OnLogin(function()
	local W = rawget(_G, "WorldMapFrame")
	if W and W.HookScript then W:HookScript("OnShow", function() Md.RevisarBotonMapa() end) end
end)

_G.BINDING_NAME_ALFA_MAZMORRA_MAPA = L["Mapa de la mazmorra (por dentro)"]
AlfaMazmorras = type(AlfaMazmorras) == "table" and AlfaMazmorras or {}
AlfaMazmorras.MapaDentro = function() return Md.Alternar() end
AlfaMazmorras.LeerMapaDentro = function() return Md.Leer() end
AlfaMazmorras.AvanceDentro = function(key) return Md.TextoAvance(key or D.MazmorraActual()) end
AlfaMazmorras.CrearPlano = function(padre) return crearPlano(padre) end

-- 1.4.0 (44): al empezar un encuentro, su lugar en el plano (si el juego da tu posición).
A.RegisterEvent("ENCOUNTER_START", function(_, _, nombre)
	if N.Secreto and N.Secreto(nombre) then return end
	if not enInstancia() then return end
	local mapa = cmap("GetBestMapForUnit", "player")
	local info = type(mapa) == "number" and infoMapa(mapa)
	if not (info and tonumber(leer(info.mapType)) == DUNGEON) then return end
	local x, y = Md.Posicion(mapa)
	if x and Md.Aprender(mapa, nombre, x, y) and v and v:IsShown() then N.FueraDeCombate("mazmorras.mapaJefes", pintar) end
end)
