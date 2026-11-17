-- Alfa - Builds: el árbol de talentos dibujado con el Kit (toxic3000 / La Jauría). GPL-3.0.
--
-- Un bloque del Kit (:Acomodar(ancho) -> alto) con las tres ramas en tres
-- paneles, tus puntos de verdad y el plan encima:
--   * el número arriba de cada ícono es el orden en que el build lo toma;
--   * borde verde de éxito: ya lo tienes como pide el plan;
--   * anillo de acento: el que toca ahora;
--   * borde de acento tenue: falta tomarlo;
--   * borde de peligro: puntos fuera del plan;
--   * sin plan ni puntos: apagado.
-- Las flechas del árbol son líneas de 2 px (rectángulos, nada de CreateLine).
--
--   Lz.Nuevo(padre) -> bloque ; bloque:Set(estado) (el de M.Estado())

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local T = M.Arbol
local Lz = {}
M.Lienzo = Lz

local floor, max, min, format = math.floor, math.max, math.min, string.format
local ESP = K.ESP

local GAP_RAMA = ESP.base   -- entre paneles de rama
local PAD = ESP.m           -- dentro de cada panel
local CABEZA = 36           -- la cabecera de cada rama
local CELDA_MAX, CELDA_MIN = 50, 30

local function nivelDe(i) return 9 + i end

-- El cuadro de un talento: el del juego (hechizo) con las líneas de Alfa.
local function info(self)
	if not (self.spell and GameTooltip) then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, self.spell)
	if not ok then GameTooltip:SetText(self.nombre or "?") end
	if self.lineas and #self.lineas > 0 then
		GameTooltip:AddLine(" ")
		for _, l in ipairs(self.lineas) do
			local r, g, b = K.Color(l[2] or "texto")
			GameTooltip:AddLine(l[1], r, g, b, true)
		end
	end
	GameTooltip:Show()
end

local function fueraInfo(self)
	if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end

local function enlazar(self)
	if not (self.spell and IsModifiedClick and IsModifiedClick("CHATLINK")) then return end
	local C = A.Compat
	local link = C and C.SpellLink and C.SpellLink(self.spell)
	local insertar = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
	if link and insertar then insertar(link) end
end

local function nodo(padre)
	local b = CreateFrame("Button", nil, padre)
	b:RegisterForClicks("LeftButtonUp")
	b.caja = K.Caja(b, { fondo = "hundido", borde = "linea", corte = K.CORTE.casilla })
	b.Icono = b:CreateTexture(nil, "ARTWORK")
	b.Icono:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.Icono:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	-- El anillo del que toca ahora: 3 px por fuera.
	b.Anillo = CreateFrame("Frame", nil, b)
	b.Anillo:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
	b.Anillo:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
	b.Anillo.caja = K.Caja(b.Anillo, { fondo = false, borde = "acento", corte = K.CORTE.chico })
	b.Anillo:Hide()
	-- El rango, en una placa oscura abajo a la derecha (se lee sobre cualquier ícono).
	b.Placa = CreateFrame("Frame", nil, b)
	b.Placa:SetFrameLevel(K.num(b:GetFrameLevel(), 0) + 4)
	b.Placa:SetHeight(13)
	b.Placa:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 4, -4)
	b.Placa.caja = K.Caja(b.Placa, { fondo = "fondo", borde = "lineaFuerte", corte = 2, rol = "control" })
	b.Rango = K.Texto(b.Placa, "pequeno", "texto")
	b.Rango:SetPoint("CENTER", b.Placa, "CENTER", 0, 0)
	b.Orden = CreateFrame("Frame", nil, b)
	b.Orden:SetFrameLevel(K.num(b:GetFrameLevel(), 0) + 4)
	b.Orden:SetHeight(14)
	b.Orden:SetPoint("TOPLEFT", b, "TOPLEFT", -5, 5)
	b.Orden.caja = K.Caja(b.Orden, { fondo = "fondo", borde = "lineaFuerte", corte = 2, rol = "control" })
	b.Orden.Texto = K.Texto(b.Orden, "insignia", "acento")
	b.Orden.Texto:SetPoint("CENTER", b.Orden, "CENTER", 0, 0)
	b:SetScript("OnEnter", info)
	b:SetScript("OnLeave", fueraInfo)
	b:SetScript("OnClick", enlazar)
	return b
end

-- El panel de una rama: caja, nombre y puntos.
local function rama(padre)
	local p = CreateFrame("Frame", nil, padre)
	p.caja = K.Caja(p, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	p.Nombre = K.Texto(p, "encabezado", "texto")
	p.Nombre:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -PAD)
	p.Puntos = K.Insignia(p, "", "neutro")
	p.Puntos:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -(PAD - 3))
	return p
end

function Lz.Nuevo(padre)
	local c = CreateFrame("Frame", nil, padre)
	c.nodos, c.lineas, c.ramas = {}, {}, {}
	-- Las flechas van en su capa: sobre los paneles de rama, bajo los talentos.
	c.Capa = CreateFrame("Frame", nil, c)
	c.Capa:SetAllPoints(c)
	c.Leyenda = {
		K.Insignia(c, L["Ya lo tienes"], "exito"),
		K.Insignia(c, L["Toca ahora"], "acento"),
		K.Insignia(c, L["Más adelante"], "neutro"),
		K.Insignia(c, L["Fuera del plan"], "peligro"),
	}
	c.Nota = K.Texto(c, "pequeno", "textoTenue")
	K.Escribir(c.Nota, L["El número es el orden en que se toma. Pasa el ratón por un talento para ver qué hace."])

	function c:Set(e) self.alfaEstado = e end

	local function linea(i)
		local t = c.lineas[i]
		if not t then
			t = K.Plano(c.Capa, "lineaFuerte", "ARTWORK", 1)
			c.lineas[i] = t
		end
		return t
	end

	function c:Acomodar(ancho)
		local e = self.alfaEstado or {}
		local vivo, st, res, b = e.vivo, e.st, e.res, e.build
		local d = T.Disposicion(vivo)
		local nRamas = max(1, #d.specs)
		local cols = max(1, d.columnas)
		local pw = floor((ancho - (nRamas - 1) * GAP_RAMA) / nRamas)
		local celda = min(CELDA_MAX, max(CELDA_MIN, floor((pw - 2 * PAD) / cols)))
		local icono = celda - 14
		local altoRama = CABEZA + d.filas * celda + PAD
		local base = K.num(self:GetFrameLevel(), 0)
		self.Capa:SetFrameLevel(base + 2)
		-- El orden del plan en cada nodo y su porqué.
		local primero, porNodo = {}, {}
		if b and res then
			for _, p in ipairs(b.picks) do
				local id = res.nodo[p.spell]
				if id and not primero[id] then
					primero[id] = p.i
					-- Solo el porqué del build: lo que hace ya lo dice el cuadro del juego.
					local por, propio = M.PorQue(b, p)
					porNodo[id] = propio and por or nil
				end
			end
		end
		local sigNodo = st and st.siguiente and res and res.nodo[st.siguiente.spell]
		-- Ramas
		local x0 = {}
		for i = 1, nRamas do
			local p = self.ramas[i] or rama(self)
			self.ramas[i] = p
			local s = d.specs[i] or {}
			local x = (i - 1) * (pw + GAP_RAMA)
			x0[i] = x
			p:ClearAllPoints()
			p:SetPoint("TOPLEFT", self, "TOPLEFT", x, 0)
			p:SetSize(pw, altoRama)
			p:SetFrameLevel(base + 1)
			p:Show()
			K.Escribir(p.Nombre, s.nombre or "?")
			local dc = M.DatosClase()
			local delPlan = b and dc and dc.especialidades and dc.especialidades[b.spec]
			local esRama = delPlan and delPlan.indice == i
			p.Puntos:Set(format(L["%d puntos"], s.gastado or 0), esRama and "acento" or "neutro")
			K.Ajustar(p.Nombre, pw - 2 * PAD - K.num(p.Puntos:GetWidth(), 0) - ESP.s)
			p.caja:Estilo({ borde = esRama and "acento" or "linea", alfaBorde = esRama and 0.5 or nil })
		end
		for i = nRamas + 1, #self.ramas do self.ramas[i]:Hide() end
		-- Nodos
		local pos = {}
		local usados = 0
		local margenRama = floor((pw - cols * celda) / 2)
		for _, n in ipairs(d.nodos) do
			usados = usados + 1
			local nb = self.nodos[usados] or nodo(self)
			self.nodos[usados] = nb
			local r = n.spec or 1
			local px = (x0[r] or 0) + margenRama + (n.col - 1) * celda + floor((celda - icono) / 2)
			local py = CABEZA + (n.fila - 1) * celda + floor((celda - icono) / 2)
			nb:SetSize(icono, icono)
			nb:ClearAllPoints()
			nb:SetPoint("TOPLEFT", self, "TOPLEFT", px, -py)
			nb:SetFrameLevel(base + 3)
			nb.Orden:SetFrameLevel(base + 7)
			nb:Show()
			pos[n.id] = { x = px, y = py, w = icono }
			local v = vivo and vivo.nodos[n.id]
			local activo = v and v.activo or 0
			local plan = st and st.planeado[n.id] or 0
			nb.spell, nb.nombre = n.spell, n.nombre
			nb.Icono:SetTexture((v and v.icono) or T.Icono(n.spell) or "Interface\\Icons\\INV_Misc_QuestionMark")
			local enPlan = plan > 0
			local fuera = activo > plan
			local esSig = (not e.foto) and sigNodo == n.id
			local completo = enPlan and activo >= plan
			nb.Icono:SetDesaturated(not (enPlan or activo > 0))
			nb:SetAlpha((enPlan or activo > 0) and 1 or 0.4)
			if enPlan and not e.foto then
				K.Escribir(nb.Rango, format("%d/%d", activo, plan))
			elseif activo > 0 then
				K.Escribir(nb.Rango, format("%d/%d", activo, n.max or activo))
			else
				K.Escribir(nb.Rango, "")
			end
			K.ColorTexto(nb.Rango, completo and "exito" or "texto")
			local conRango = (nb.Rango:GetText() or "") ~= ""
			nb.Placa:SetShown(conRango)
			if conRango then nb.Placa:SetWidth(K.AnchoTexto(nb.Rango) + 6) end
			nb.Placa:SetFrameLevel(base + 7)
			local borde, alfa = "linea", nil
			if fuera and not e.foto then borde = "peligro"
			elseif esSig then borde = "acento"
			elseif completo and not e.foto then borde = "exito"
			elseif enPlan then borde, alfa = "acento", 0.45 end
			nb.caja:Estilo({ borde = borde, alfaBorde = alfa })
			nb.Anillo:SetFrameLevel(base + 4)
			nb.Anillo:SetShown(esSig and true or false)
			if primero[n.id] then
				K.Escribir(nb.Orden.Texto, tostring(primero[n.id]))
				nb.Orden:SetWidth(max(14, K.AnchoTexto(nb.Orden.Texto) + 6))
				nb.Orden:Show()
			else
				nb.Orden:Hide()
			end
			-- Lo que dice Alfa en el cuadro del talento.
			local lineas = {}
			if primero[n.id] then
				lineas[#lineas + 1] = { format(L["Punto %d de tu build (nivel %d), hasta %d/%d."], primero[n.id], nivelDe(primero[n.id]), plan, n.max or plan), "acento" }
				if esSig then lineas[#lineas + 1] = { L["Es el que toca ahora."], "acento" } end
				if porNodo[n.id] then lineas[#lineas + 1] = { porNodo[n.id], "textoSuave" } end
				if fuera then lineas[#lineas + 1] = { L["Tienes más rangos de los que pide tu build."], "peligro" } end
			elseif activo > 0 then
				lineas[#lineas + 1] = { L["Este talento no está en tu build."], "peligro" }
			end
			nb.lineas = lineas
		end
		for i = usados + 1, #self.nodos do self.nodos[i]:Hide() end
		-- Flechas: de abajo del primero a arriba del segundo (o de lado, en la misma fila).
		local nl = 0
		for _, f in ipairs(d.flechas) do
			local a, z = pos[f.de], pos[f.a]
			if a and z then
				local plan = st and st.planeado[f.a] or 0
				local color, alfa = plan > 0 and "acento" or "lineaFuerte", plan > 0 and 0.7 or 1
				local ax, az = a.x + floor(a.w / 2), z.x + floor(z.w / 2)
				if a.y == z.y then
					nl = nl + 1
					local t = linea(nl)
					local x1, x2 = min(a.x + a.w, z.x + z.w), max(a.x, z.x)
					t:ClearAllPoints()
					t:SetPoint("TOPLEFT", self, "TOPLEFT", x1, -(a.y + floor(a.w / 2) - 1))
					t:SetSize(max(1, x2 - x1), 2)
					K.ColorPlano(t, color) t:SetAlpha(alfa) t:Show()
				else
					local y1 = a.y + a.w
					local y2 = (ax == az) and z.y or (z.y + floor(z.w / 2))
					nl = nl + 1
					local t = linea(nl)
					t:ClearAllPoints()
					t:SetPoint("TOPLEFT", self, "TOPLEFT", ax - 1, -y1)
					t:SetSize(2, max(1, y2 - y1))
					K.ColorPlano(t, color) t:SetAlpha(alfa) t:Show()
					if ax ~= az then
						nl = nl + 1
						local h = linea(nl)
						local x1 = ax < az and ax or (z.x + z.w)
						local x2 = ax < az and z.x or ax
						h:ClearAllPoints()
						h:SetPoint("TOPLEFT", self, "TOPLEFT", x1, -(y2 - 1))
						h:SetSize(max(1, x2 - x1), 2)
						K.ColorPlano(h, color) h:SetAlpha(alfa) h:Show()
					end
				end
			end
		end
		for i = nl + 1, #self.lineas do self.lineas[i]:Hide() end
		-- Leyenda y nota, debajo.
		local y = altoRama + ESP.m
		local lx = 0
		for _, ins in ipairs(self.Leyenda) do
			ins:ClearAllPoints()
			ins:SetPoint("TOPLEFT", self, "TOPLEFT", lx, -y)
			ins:SetShown(not e.foto)
			lx = lx + K.num(ins:GetWidth(), 0) + ESP.s
		end
		local nx = e.foto and 0 or (lx + ESP.s)
		self.Nota:ClearAllPoints()
		if ancho - nx < 240 then
			y = y + K.ALTO.insignia + ESP.s
			nx = 0
		end
		self.Nota:SetPoint("TOPLEFT", self, "TOPLEFT", nx, -(y + 4))
		K.Ajustar(self.Nota, ancho - nx)
		y = y + K.ALTO.insignia
		self:SetSize(ancho, y)
		return y
	end
	return c
end
