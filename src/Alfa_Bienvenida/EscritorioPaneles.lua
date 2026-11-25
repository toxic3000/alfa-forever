-- Alfa - Bienvenida: los paneles del Escritorio de Alfa (1.3.8).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Cada panel es un marco propio que usa lo que ya hace cada módulo (sus
-- globales: AlfaInicio, AlfaRuta, AlfaMundo, AlfaCombate, AlfaPesca,
-- AlfaBolsas, AlfaLya y los avisos de Alfa_Nucleo/Momentos.lua): aquí no se
-- calcula nada que otro ya calcule. Se pinta al mostrarse, al cambiar de
-- tamaño y a su ritmo (Es.Latido, solo con el escritorio a la vista); en
-- combate solo el medidor y el grupo, que pasan lo secreto tal cual a
-- SetText / SetValue (nunca lo suman ni lo comparan).
-- El tamaño del panel decide cuánto enseña: compacto, medio o grande.

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP
local Es = M.Escritorio

local type, pairs, ipairs, tonumber, tostring, pcall, select = type, pairs, ipairs, tonumber, tostring, pcall, select
local floor, max, min, sqrt, atan2, pi = math.floor, math.max, math.min, math.sqrt, math.atan2, math.pi
local format = string.format
local DOT = "  \194\183  "

local function G(n) local v = rawget(_G, n) return type(v) == "table" and v or nil end
local function llamar(t, fn, ...)
	if type(t) ~= "table" or type(t[fn]) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(t[fn], ...)
	if ok then return a, b, c, d end
	return nil
end
local function secreto(v) return N.Secreto and N.Secreto(v) or false end
local function num(v) if secreto(v) then return nil end return tonumber(v) end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function opt(k) return N.Get(Es.ID, k) end

---------------------------------------------------------------------------
-- Piezas comunes
---------------------------------------------------------------------------

local function texto(padre, rol, color)
	local fs = K.Texto(padre, rol or "cuerpo", color or "texto")
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	return fs
end

local function poner(fs, c, x, y, w)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
	if w then fs:SetWidth(w) end
	fs:Show()
end

-- Un texto que puede venir secreto del juego (un nombre en mazmorra): tal cual.
local function escribir(fs, v)
	if secreto(v) then fs:SetText(v) return end
	K.Escribir(fs, v ~= nil and tostring(v) or "")
end

-- Un párrafo de hasta `lineas` renglones -> su alto.
local function parrafo(fs, c, x, y, w, lineas, v)
	escribir(fs, v)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
	fs:SetWordWrap(true)
	fs:Show()
	return K.Parrafo(fs, w, lineas)
end

-- Filas: ícono, texto, una línea abajo (opcional), un valor a la derecha y su clic.
local function Filas(c)
	local pool = { filas = {} }
	function pool:Fila(i)
		local f = self.filas[i]
		if f then return f end
		f = CreateFrame("Button", nil, c)
		f:RegisterForClicks("LeftButtonUp")
		f.velo = K.Velo(f, K.CORTE.chico)
		f.Icono = K.Icono(f, "ic-info", 14, "textoSuave")
		f.Icono:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -5)
		f.Texto = texto(f, "cuerpo", "texto")
		f.Sub = texto(f, "pequeno", "textoTenue")
		f.Valor = texto(f, "numero", "texto")
		f.Valor:SetJustifyH("RIGHT")
		f.Punto = K.Plano(f, "acento", "ARTWORK")
		f.Punto:SetSize(6, 6)
		f:SetScript("OnEnter", function(self) if self.alClic then self.velo:Show() end end)
		f:SetScript("OnLeave", function(self) self.velo:Hide() end)
		f:SetScript("OnClick", function(self) if self.alClic then K.Llamar(self.alClic, self) end end)
		self.filas[i] = f
		return f
	end
	-- lista = { { icono, color, texto, sub, valor, colorValor, punto, alClic } }
	-- Cada fila mide lo que su texto: hasta 2 renglones del texto y 2 de la
	-- línea de abajo (nada se corta); la que ya no cabe no sale.
	function pool:Poner(lista, ancho, y, alto)
		local n = 0
		for i, it in ipairs(lista) do
			local f = self:Fila(i)
			-- 1.4.0: el rol de la letra de la lista (las metas de la guía, en grande).
			if f.rol ~= (self.rol or "cuerpo") then
				f.rol = self.rol or "cuerpo"
				K.Fuente(f.Texto, f.rol)
				local t = f.rol == "cuerpo" and 14 or 18
				f.Icono:SetSize(t, t)
			end
			K.SetIcono(f.Icono, it.icono or "ic-info", it.color or "textoSuave")
			escribir(f.Valor, it.valor or "")
			if it.colorValor then K.ColorTexto(f.Valor, it.colorValor) else K.ColorTexto(f.Valor, "texto") end
			local vw = (it.valor and it.valor ~= "") and (K.AnchoTexto(f.Valor) + 4) or 0
			f.Valor:ClearAllPoints()
			f.Valor:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -6)
			f.Valor:SetWidth(vw)
			local tw = max(20, ancho - 26 - vw - 8 - (it.punto and 10 or 0))
			escribir(f.Texto, it.texto or "")
			f.Texto:ClearAllPoints()
			f.Texto:SetPoint("TOPLEFT", f, "TOPLEFT", f.rol ~= "cuerpo" and 28 or 24, -5)
			local th = secreto(it.texto) and 16 or K.Parrafo(f.Texto, tw, it.lineas or 2)
			if it.colorTexto then f.Texto:SetTextColor(it.colorTexto[1], it.colorTexto[2], it.colorTexto[3]) else K.ColorTexto(f.Texto, "texto") end
			local sh = 0
			if it.sub ~= nil then
				escribir(f.Sub, it.sub)
				f.Sub:ClearAllPoints()
				f.Sub:SetPoint("TOPLEFT", f.Texto, "BOTTOMLEFT", 0, -3)
				sh = 3 + K.Parrafo(f.Sub, max(20, ancho - 28), 2)
				f.Sub:Show()
			else
				f.Sub:Hide()
			end
			local h = max(26, 5 + th + sh + 6)
			if y + h > alto + 1 then break end
			n = i
			f.Punto:ClearAllPoints()
			f.Punto:SetPoint("TOPLEFT", f.Texto, "TOPLEFT", min(K.AnchoTexto(f.Texto), tw) + 6, -5)
			f.Punto:SetShown(it.punto == true)
			f.alClic = it.alClic
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
			f:SetSize(ancho, h)
			f:Show()
			y = y + h + 2
		end
		for i = n + 1, #self.filas do self.filas[i]:Hide() end
		return y, n
	end
	function pool:Ocultar() for _, f in ipairs(self.filas) do f:Hide() end end
	return pool
end

-- Cifras: baldosas con su título chico, el número y una línea.
local function Cifras(c)
	local pool = { cajas = {} }
	function pool:Caja(i)
		local b = self.cajas[i]
		if b then return b end
		b = CreateFrame("Frame", nil, c)
		b.caja = K.Caja(b, { fondo = "hundido", borde = "linea", corte = K.CORTE.chico })
		b.Titulo = texto(b, "pequeno", "textoTenue")
		b.Valor = texto(b, "numero", "texto")
		b.Texto = texto(b, "pequeno", "textoSuave")
		self.cajas[i] = b
		return b
	end
	-- lista = { { titulo, valor, texto, colorValor } } -> alto usado
	function pool:Poner(lista, ancho, y, alto, columnas, grande)
		columnas = max(1, columnas or 2)
		local gap = ESP.s
		local w = floor((ancho - gap * (columnas - 1)) / columnas)
		local conTexto = false
		for _, it in ipairs(lista) do if it.texto and it.texto ~= "" then conTexto = true end end
		local hb = grande and 70 or (conTexto and 62 or 48)
		local filas = 0
		local n = 0
		for i, it in ipairs(lista) do
			local col = (i - 1) % columnas
			local fila = floor((i - 1) / columnas)
			local top = y + fila * (hb + gap)
			if top + hb > alto + 1 then break end
			n = i
			filas = fila + 1
			local b = self:Caja(i)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", c, "TOPLEFT", col * (w + gap), -top)
			b:SetSize(w, hb)
			K.Fuente(b.Valor, grande and "cifra" or "numero")
			poner(b.Titulo, b, ESP.s, ESP.s - 1, w - ESP.base)
			escribir(b.Titulo, it.titulo or "")
			poner(b.Valor, b, ESP.s, ESP.s + 14, w - ESP.base)
			escribir(b.Valor, it.valor or "")
			if it.colorValor then K.ColorTexto(b.Valor, it.colorValor) else K.ColorTexto(b.Valor, "texto") end
			poner(b.Texto, b, ESP.s, hb - ESP.s - 12, w - ESP.base)
			escribir(b.Texto, it.texto or "")
			-- La línea chica solo si cabe entera.
			b.Texto:SetShown(it.texto ~= nil and it.texto ~= "" and K.AnchoTexto(b.Texto) <= w - ESP.base)
			b:Show()
		end
		for i = n + 1, #self.cajas do self.cajas[i]:Hide() end
		return filas > 0 and filas * (hb + gap) - gap or 0, n
	end
	return pool
end

-- Hasta tres botones chicos abajo del cuerpo.
local function Botones(c)
	local pool = { b = {} }
	function pool:Poner(lista, ancho)
		local x = 0
		local n = 0
		for i, it in ipairs(lista) do
			local b = self.b[i] or K.Boton(c, "", nil, { tipo = i == 1 and "primario" or "secundario", tam = "chico" })
			self.b[i] = b
			b:SetTexto(it.texto)
			b.alClic = it.alClic
			b:SetTipo(it.tipo or (i == 1 and "primario" or "secundario"))
			local w = b:AnchoNatural()
			if x + w > ancho + 1 then b:Hide() else
				b:ClearAllPoints()
				b:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", x, 0)
				b:SetActivo(it.activo ~= false)
				b:Show()
				x = x + w + ESP.s
				n = i
			end
		end
		for i = #lista + 1, #self.b do self.b[i]:Hide() end
		return n > 0 and K.ALTO.botonChico or 0
	end
	return pool
end

-- Un vacío: el lobo, un título y una línea, centrado.
local function Vacio(c)
	local v = CreateFrame("Frame", nil, c)
	v.Lobo = v:CreateTexture(nil, "ARTWORK")
	v.Lobo:SetSize(40, 40)
	v.Lobo:SetPoint("TOP", v, "TOP", 0, 0)
	K.Pintar(v.Lobo, function(t) t:SetVertexColor(K.Color("textoTenue")) end)
	v.Titulo = K.Texto(v, "cuerpo", "textoSuave")
	v.Titulo:SetPoint("TOP", v.Lobo, "BOTTOM", 0, -ESP.s)
	v.Texto = K.Texto(v, "nota", "textoTenue")
	v.Texto:SetPoint("TOP", v.Titulo, "BOTTOM", 0, -4)
	v.Texto:SetJustifyH("CENTER")
	function v:Poner(ancho, alto, titulo, linea, lobo, arriba)
		self.Lobo:SetTexture(K.Lobo(lobo or "dormido"))
		-- 1.4.0: en un panel principal y grande, el vacío también se lee de lejos.
		local p = c:GetParent()
		local grande = p and p.protagonista and ancho >= 300 and alto >= 220
		local lw = grande and 72 or 40
		self.Lobo:SetSize(lw, lw)
		K.Fuente(self.Titulo, grande and "titulo" or "cuerpo")
		K.Fuente(self.Texto, grande and "texto" or "nota")
		K.Escribir(self.Titulo, titulo or "")
		K.Escribir(self.Texto, linea or "")
		local h = lw + ESP.s + K.AltoTexto(self.Titulo) + (linea and (4 + K.Parrafo(self.Texto, max(60, ancho - ESP.base), 3)) or 0)
		self:ClearAllPoints()
		self:SetPoint("TOP", c, "TOP", 0, -(arriba or max(0, floor((alto - h) / 2) - 8)))
		self:SetSize(ancho, h)
		self:Show()
		return h
	end
	v:Hide()
	return v
end

local function ocultarTodo(lista) for _, x in ipairs(lista) do if x then x:Hide() end end end

---------------------------------------------------------------------------
-- Hoy: lo que conviene ahora y tus números
---------------------------------------------------------------------------
Es.Registrar({ id = "hoy", titulo = "Hoy", icono = "ic-hoy", texto = "Lo que conviene ahora y tus números del día.",
	forma = "cifras", tam = { 6, 8 }, ritmo = 5,
	abrir = function() N.Abrir("inicio") end,
	crear = function(p, c)
		p.filas = Filas(c)
		p.cifras = Cifras(c)
		p.botones = Botones(c)
		p.Sec = texto(c, "mayus", "textoTenue")
		p.Sec2 = texto(c, "mayus", "textoTenue")
	end,
	pintar = function(p, c, w, h, tam)
		local I = G("AlfaInicio")
		local botones = { { texto = L["Una hora de caza"], alClic = function() llamar(G("AlfaRuta"), "UnaHora") end } }
		-- 1.3.9 (12, área misiones): el mismo «Cerrar mis misiones» de Hoy y del menú.
		local cerrarTxt = llamar(G("AlfaRuta"), "TextoCerrar")
		if type(cerrarTxt) == "string" then
			botones[#botones + 1] = { texto = cerrarTxt, alClic = function() llamar(G("AlfaRuta"), "CerrarTodo", "escritorio") end }
		end
		botones[#botones + 1] = { texto = L["Abrir Hoy"], alClic = function() N.Abrir("inicio") end }
		local abajo = p.botones:Poner(botones, w)
		local alto = h - (abajo > 0 and abajo + ESP.s or 0)
		local y = 0
		poner(p.Sec, c, 0, y, w)
		K.Escribir(p.Sec, K.Mayus(L["Lo que conviene ahora"]))
		y = y + 18
		local lista = {}
		for _, a in ipairs(llamar(I, "Alertas") or {}) do
			local ac = a.accion
			lista[#lista + 1] = { icono = a.icono or "ic-aviso", color = a.tono == "peligro" and "peligro" or (a.tono == "aviso" and "aviso" or "acento"),
				texto = a.titulo, sub = tam ~= "compacto" and a.texto or nil, alClic = ac and ac.alClic or nil }
		end
		if #lista == 0 then
			lista[1] = { icono = "ic-exito", color = "exito", texto = L["Todo en orden: a cazar"], sub = tam ~= "compacto" and L["Tu equipo, tus bolsas y tus habilidades están bien."] or nil }
		end
		local maxAlertas = tam == "grande" and 4 or (tam == "medio" and 3 or 2)
		while #lista > maxAlertas do lista[#lista] = nil end
		y = p.filas:Poner(lista, w, y, alto)
		local num = llamar(I, "Numeros") or {}
		if #num > 0 and y + 18 + 54 <= alto then
			y = y + ESP.s
			poner(p.Sec2, c, 0, y, w)
			K.Escribir(p.Sec2, K.Mayus(L["Hoy en números"]))
			y = y + 18
			local cif = {}
			for _, n in ipairs(num) do cif[#cif + 1] = { titulo = n.titulo, valor = n.valor, texto = tam == "grande" and n.texto or nil, colorValor = n.colorValor } end
			p.cifras:Poner(cif, w, y, alto, tam == "grande" and 3 or 2, tam == "grande")
		else
			p.Sec2:Hide()
			p.cifras:Poner({}, w, y, alto)
		end
	end })

---------------------------------------------------------------------------
-- Tu guía: el rastreador en grande
---------------------------------------------------------------------------
local VERBO = { ["goto"] = "ic-flecha", accept = "ic-misiones", turnin = "ic-exito", complete = "ic-exito", kill = "ic-raros",
	collect = "ic-bolsas", loot = "ic-bolsas", talk = "ic-personajes", use = "ic-seguir", fly = "ic-mapa", taxi = "ic-mapa",
	hearth = "ic-hoy", train = "ic-nivel", fish = "ic-pesca", buy = "ic-comercio" }

-- Los pasos que siguen (títulos), para el panel grande.
local function siguientes(n)
	local E, U = A.Engine, A.UI
	if type(E) ~= "table" or type(E.GetLiveStep) ~= "function" then return {} end
	local ok, i = pcall(E.GetLiveStep)
	if not ok or type(i) ~= "number" then return {} end
	local out = {}
	for k = i + 1, i + 12 do
		if #out >= n then break end
		local okv, v = pcall(N.VistaPaso or E.GetStepView, k) -- 1.3.9 (19): la lectura compartida
		if not okv or type(v) ~= "table" then break end
		local t
		if type(U) == "table" and type(U.StepSummary) == "function" then
			local oks, s = pcall(U.StepSummary, v)
			if oks and type(s) == "string" and s ~= "" then t = s end
		end
		t = t or (type(v.title) == "string" and v.title ~= "" and v.title) or nil
		if t then out[#out + 1] = t end
	end
	return out
end

Es.Registrar({ id = "rastreador", titulo = "Tu guía", icono = "ic-ruta", texto = "El paso de ahora, sus metas, cuánto falta y lo que sigue.",
	forma = "lista", tam = { 8, 10 }, ritmo = 2, protagonista = true,
	abrir = function() llamar(G("AlfaRuta"), "Pagina") end,
	crear = function(p, c)
		p.Guia = texto(c, "pequeno", "textoTenue")
		p.Avance = K.Progreso(c, { alto = 4, tono = "acento" })
		p.Paso = K.Texto(c, "subtitulo", "texto")
		p.Paso:SetJustifyH("LEFT")
		p.metas = Filas(c)
		p.Dist = texto(c, "cuerpo", "acento")
		p.Sec = texto(c, "mayus", "textoTenue")
		p.sig = Filas(c)
		p.vacio = Vacio(c)
		p.botones = Botones(c)
	end,
	pintar = function(p, c, w, h, tam)
		local I, R = G("AlfaInicio"), G("AlfaRuta")
		local info = llamar(I, "Paso")
		local partes = { p.Guia, p.Avance, p.Paso, p.Dist, p.Sec }
		if not info or info.fin or not info.titulo then
			ocultarTodo(partes)
			p.metas:Ocultar()
			p.sig:Ocultar()
			local abajo
			if info and info.fin then
				abajo = p.botones:Poner({ { texto = L["Elegir otra guía"], alClic = function() llamar(R, "Biblioteca") end } }, w)
				p.vacio:Poner(w, h - abajo, L["¡Terminaste tu guía!"], L["Elige otra y la flecha te sigue llevando."], "aullando")
			else
				abajo = p.botones:Poner({ { texto = L["Elegir una guía"], alClic = function() llamar(R, "Asistente") end } }, w)
				p.vacio:Poner(w, h - abajo, L["Todavía no sigues una guía"], L["Dime a dónde quieres ir y te armo el camino."], "atento")
			end
			return
		end
		p.vacio:Hide()
		local abajo = p.botones:Poner({
			{ texto = L["Ver pasos"], alClic = function() llamar(R, "MostrarGuia") end },
			{ texto = L["Abrir la ruta"], alClic = function() llamar(R, "Pagina") end },
		}, w)
		local alto = h - (abajo > 0 and abajo + ESP.s or 0)
		local y = 0
		local guia = info.guia or ""
		if info.num and info.total and info.total > 0 then guia = guia .. DOT .. format(L["Paso %d de %d"], min(info.num, info.total), info.total) end
		poner(p.Guia, c, 0, y, w)
		escribir(p.Guia, guia)
		y = y + 16
		if (info.todos or 0) > 0 then
			p.Avance:ClearAllPoints()
			p.Avance:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
			p.Avance:Acomodar(w)
			p.Avance:Set(info.hechos or 0, info.todos)
			p.Avance:Show()
			y = y + 4 + ESP.s
		else
			p.Avance:Hide()
		end
		-- 1.4.0: el paso de ahora, en letra de portada (se lee desde la silla).
		K.Fuente(p.Paso, tam == "grande" and "portada" or (tam == "medio" and "titulo" or "subtitulo"))
		y = y + parrafo(p.Paso, c, 0, y, w, tam == "compacto" and 2 or 3, info.titulo) + ESP.m
		local metas = {}
		for _, g in ipairs(info.metas or {}) do metas[#metas + 1] = { icono = VERBO[g.t] or "ic-huella", color = "acento", texto = g.texto } end
		p.metas.rol = tam == "grande" and "subtitulo" or "cuerpo"
		y = p.metas:Poner(metas, w, y, alto)
		local d, tono = llamar(I, "Distancia")
		-- Con el panel de la flecha a la vista, la distancia va allá (no repetida).
		if Es.TienePanel("flecha") and Es.Marcos.flecha and Es.Marcos.flecha:IsShown() then d = nil end
		if type(d) == "string" and y + 20 <= alto then
			poner(p.Dist, c, 0, y + 2, w)
			K.Escribir(p.Dist, d)
			K.ColorTexto(p.Dist, tono == "exito" and "exito" or "acento")
			y = y + 24
		else
			p.Dist:Hide()
		end
		if tam ~= "compacto" and y + 18 + 26 <= alto then
			local lista = {}
			for _, t in ipairs(siguientes(tam == "grande" and 5 or 3)) do lista[#lista + 1] = { icono = "chevron-right", color = "textoTenue", texto = t } end
			if #lista > 0 then
				y = y + ESP.s
				poner(p.Sec, c, 0, y, w)
				K.Escribir(p.Sec, K.Mayus(L["Lo que sigue"]))
				y = y + 18
				p.sig:Poner(lista, w, y, alto)
			else
				p.Sec:Hide()
				p.sig:Ocultar()
			end
		else
			p.Sec:Hide()
			p.sig:Ocultar()
		end
	end })

---------------------------------------------------------------------------
-- La flecha en grande, con la distancia y cuánto tardas
---------------------------------------------------------------------------
local FLECHA = "Interface\\AddOns\\Alfa\\Media\\Nav\\arrow"

local function rumboFlecha()
	local Nav = A.Nav
	if type(Nav) ~= "table" or type(Nav.GetTarget) ~= "function" then return nil end
	local ok, t = pcall(Nav.GetTarget)
	if not ok or type(t) ~= "table" then return nil end
	local dn, dw
	if type(Nav.TargetOffset) == "function" then
		local ok2, a, b = pcall(Nav.TargetOffset)
		if ok2 then dn, dw = num(a), num(b) end
	end
	return t, dn, dw
end

local function girar(p)
	local t, dn, dw = rumboFlecha()
	if not (t and dn and dw) then return end
	local cara = GetPlayerFacing and num(GetPlayerFacing())
	if not cara then p.Flecha:SetRotation(0) return end
	-- 0 = norte y crece hacia el oeste, como GetPlayerFacing.
	p.Flecha:SetRotation(atan2(dw, dn) - cara)
end

Es.Registrar({ id = "flecha", titulo = "La flecha", icono = "ic-flecha", texto = "Hacia dónde ir, cuánto falta y en cuánto llegas.",
	forma = "flecha", tam = { 6, 6 }, ritmo = 1, enCombate = true, protagonista = true,
	abrir = function() llamar(G("AlfaRuta"), "Pagina") end,
	crear = function(p, c)
		p.Aro = c:CreateTexture(nil, "BACKGROUND")
		p.Aro:SetTexture("Interface\\AddOns\\Alfa\\Media\\Nav\\ring")
		p.Flecha = c:CreateTexture(nil, "ARTWORK")
		p.Flecha:SetTexture(FLECHA)
		p.Lobo = c:CreateTexture(nil, "ARTWORK")
		p.Dist = K.Texto(c, "cifra", "texto")
		p.Dist:SetJustifyH("LEFT")
		p.Destino = texto(c, "cuerpo", "textoSuave")
		p.Llega = texto(c, "nota", "acento")
		p.vacio = Vacio(c)
		K.Pintar(p, function(x)
			x.Aro:SetVertexColor(K.Color("lineaFuerte"))
			x.Flecha:SetVertexColor(K.Color(K.Clasico() and "oro" or "acento"))
			x.Lobo:SetVertexColor(K.Color("exito"))
		end)
		local paso = 0
		p:SetScript("OnUpdate", function(self, dt)
			paso = paso + (dt or 0)
			if paso < 0.1 then return end
			paso = 0
			if self.Flecha:IsShown() then girar(self) end
		end)
	end,
	pintar = function(p, c, w, h, tam)
		local t, dn, dw = rumboFlecha()
		local I = G("AlfaInicio")
		local txt, tono, label = llamar(I, "Distancia")
		if not t or type(txt) ~= "string" then
			ocultarTodo({ p.Aro, p.Flecha, p.Lobo, p.Dist, p.Destino, p.Llega })
			p.vacio:Poner(w, h, L["Sin destino"], L["Cuando la flecha te lleve a algún lado, aquí la ves en grande."], "dormido")
			return
		end
		p.vacio:Hide()
		-- 1.4.0: en un panel alto, la flecha arriba y en grande, y abajo la
		-- distancia, el destino y cuánto tardas, centrados (se leen de lejos).
		local alta = h >= w * 0.9 and w >= 150
		local lado
		if alta then lado = max(48, min(floor(w * 0.72), floor(h * 0.5)))
		else lado = max(48, min(h - 8, floor(w * (tam == "compacto" and 0.36 or 0.42)))) end
		local llego = tono == "exito"
		p.Aro:ClearAllPoints()
		if alta then p.Aro:SetPoint("TOP", c, "TOP", 0, -max(0, floor((h - lado - 118) / 2)))
		else p.Aro:SetPoint("LEFT", c, "LEFT", 0, 0) end
		p.Aro:SetSize(lado, lado)
		p.Aro:Show()
		p.Flecha:ClearAllPoints()
		p.Flecha:SetPoint("CENTER", p.Aro, "CENTER", 0, 0)
		p.Flecha:SetSize(lado * 0.62, lado * 0.62)
		p.Flecha:SetShown(not llego and dn ~= nil)
		p.Lobo:ClearAllPoints()
		p.Lobo:SetPoint("CENTER", p.Aro, "CENTER", 0, 0)
		p.Lobo:SetSize(lado * 0.7, lado * 0.7)
		p.Lobo:SetTexture(K.Lobo("aullando"))
		p.Lobo:SetShown(llego)
		if not llego then girar(p) end
		local x = lado + ESP.base
		local tw = max(40, w - x)
		-- La distancia sola en grande; el rumbo va en la línea de abajo.
		local d = dn and dw and sqrt(dn * dn + dw * dw) or nil
		local area = t and tonumber(t.area)
		if d and area and area > 0 then d = d > area and d - area or 0 end
		local grande
		if llego then grande = L["Ya llegaste"]
		elseif d and type(A.FormatDistance) == "function" then
			local ok, s = pcall(A.FormatDistance, d)
			grande = ok and type(s) == "string" and s or nil
		end
		grande = grande or (d and format(L["%d yardas"], floor(d + 0.5))) or txt
		local destino = label or (type(t.label) == "string" and t.label) or txt
		local vel = GetUnitSpeed and num(GetUnitSpeed("player")) or nil
		if not vel or vel < 1 then vel = 7 end
		local llega = (d and not llego) and format(L["Llegas en %s"], N.Duracion(max(1, d / vel), true)) or nil
		if alta then
			-- La distancia en letra de anuncio si cabe; si no, un escalón menos.
			K.Fuente(p.Dist, "anuncio")
			K.Escribir(p.Dist, grande)
			if K.AnchoTexto(p.Dist) > w then K.Fuente(p.Dist, "cifra") end
			local y = K.num(p.Aro:GetHeight(), lado) + max(0, floor((h - lado - 118) / 2)) + ESP.m
			for _, fs in ipairs({ p.Dist, p.Destino, p.Llega }) do fs:SetJustifyH("CENTER") end
			poner(p.Dist, c, 0, y, w)
			K.ColorTexto(p.Dist, llego and "exito" or "texto")
			y = y + K.AltoTexto(p.Dist) + ESP.xs
			K.Fuente(p.Destino, "subtitulo")
			y = y + parrafo(p.Destino, c, 0, y, w, 2, (d and not llego) and txt or destino) + ESP.xs
			if llega then
				K.Fuente(p.Llega, "cuerpo")
				poner(p.Llega, c, 0, y, w)
				K.Escribir(p.Llega, llega)
			else
				p.Llega:Hide()
			end
			return
		end
		for _, fs in ipairs({ p.Dist, p.Destino, p.Llega }) do fs:SetJustifyH("LEFT") end
		K.Fuente(p.Dist, (tam == "compacto" or #grande > 12) and "titulo" or "cifra")
		K.Fuente(p.Destino, "cuerpo")
		K.Fuente(p.Llega, "nota")
		p.Destino:SetWordWrap(false)
		poner(p.Dist, c, x, max(0, floor(h / 2) - 34), tw)
		K.Escribir(p.Dist, grande)
		K.ColorTexto(p.Dist, llego and "exito" or "texto")
		poner(p.Destino, c, x, max(0, floor(h / 2) - 4), tw)
		escribir(p.Destino, (d and not llego) and txt or destino)
		-- En cuánto llegas: a tu velocidad (corriendo si estás quieto).
		if llega then
			poner(p.Llega, c, x, max(0, floor(h / 2) + 16), tw)
			K.Escribir(p.Llega, llega)
		else
			p.Llega:Hide()
		end
	end })

---------------------------------------------------------------------------
-- El mapa de Alfa, dentro del panel
---------------------------------------------------------------------------
local mapaEn -- el panel que tiene el mapa
local mapaAntes -- { anclas, ancho, alto, abierto }

local function marcoMapa() local f = rawget(_G, "AlfaMundoMapa") return type(f) == "table" and f.SetPoint and f or nil end

local function soltarMapa()
	local f = marcoMapa()
	if f and mapaAntes then
		f:ClearAllPoints()
		for _, q in ipairs(mapaAntes.anclas) do f:SetPoint(q[1], q[2], q[3], q[4] or 0, q[5] or 0) end
		if #mapaAntes.anclas == 0 then f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
		if mapaAntes.ancho then f:SetSize(mapaAntes.ancho, mapaAntes.alto) end
		if not mapaAntes.abierto and f:IsShown() then llamar(G("AlfaMundo"), "Cerrar") end
	end
	mapaEn, mapaAntes = nil, nil
end
Es.SoltarMapa = soltarMapa

-- (1.3.8 revisión) pedido = true: lo pidió el botón «Ver el mapa aquí». Si
-- cerraste el mapa que estaba en el panel, ya no se vuelve a abrir solo
-- (cada 5 s) hasta que lo pidas o lo abras tú.
local function tomarMapa(p, pedido)
	local Mu = G("AlfaMundo")
	if not (Mu and type(Mu.Abrir) == "function") then return false end
	if enCombate() then return false end
	local f = marcoMapa()
	local abierto = f ~= nil and f:IsShown()
	if pedido then p.alfaMapaCerrado = nil end
	if mapaEn == p and not abierto and not pedido then
		p.alfaMapaCerrado = true -- lo cerró el jugador
		soltarMapa()
		return false
	end
	if not abierto and p.alfaMapaCerrado then return false end
	if abierto then p.alfaMapaCerrado = nil end
	if not abierto then llamar(Mu, "Abrir") f = marcoMapa() end
	if not f then return false end
	if mapaEn ~= p then
		mapaAntes = { anclas = Es.Anclas(f), ancho = K.num(f:GetWidth(), 0), alto = K.num(f:GetHeight(), 0), abierto = abierto }
		mapaEn = p
	end
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", p.Cuerpo, "TOPLEFT", -ESP.m + 2, ESP.s - 2)
	f:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -2, 2)
	return true
end
Es.TomarMapa = tomarMapa

local function dondeEstoy()
	local zona = GetZoneText and GetZoneText() or ""
	local sub = GetSubZoneText and GetSubZoneText() or ""
	local x, y
	if C_Map and type(C_Map.GetBestMapForUnit) == "function" and type(C_Map.GetPlayerMapPosition) == "function" then
		local ok, mapa = pcall(C_Map.GetBestMapForUnit, "player")
		if ok and num(mapa) then
			local ok2, pos = pcall(C_Map.GetPlayerMapPosition, mapa, "player")
			if ok2 and type(pos) == "table" and pos.GetXY then
				local a, b = pos:GetXY()
				x, y = num(a), num(b)
			end
		end
	end
	return zona, sub, x, y
end

Es.Registrar({ id = "mapa", titulo = "Mapa", icono = "ic-mapa", texto = "El mapa de Alfa con tu posición, tus marcadores y la ruta.",
	forma = "mapa", tam = { 10, 10 }, ritmo = 5,
	abrir = function() llamar(G("AlfaMundo"), "Abrir") end,
	crear = function(p, c)
		p.Zona = texto(c, "subtitulo", "texto")
		p.Sub = texto(c, "cuerpo", "textoSuave")
		p.Coord = texto(c, "numero", "acento")
		p.Nota = K.Texto(c, "nota", "textoTenue")
		p.Nota:SetJustifyH("LEFT")
		p.botones = Botones(c)
	end,
	alOcultar = function(p) if mapaEn == p then soltarMapa() end end,
	pintar = function(p, c, w, h, tam)
		local Ed = M.EscritorioEditor
		local editando = Ed and Ed.Activo()
		if not editando and opt("mapaDentro") ~= false and tomarMapa(p) then
			ocultarTodo({ p.Zona, p.Sub, p.Coord, p.Nota })
			p.botones:Poner({}, w)
			return
		end
		if mapaEn == p then soltarMapa() end
		local zona, sub, x, y = dondeEstoy()
		local yy = 0
		poner(p.Zona, c, 0, yy, w)
		escribir(p.Zona, zona ~= "" and zona or L["Mapa"])
		yy = yy + 22
		if sub ~= "" then
			poner(p.Sub, c, 0, yy, w)
			escribir(p.Sub, sub)
			yy = yy + 20
		else
			p.Sub:Hide()
		end
		if x and y then
			poner(p.Coord, c, 0, yy, w)
			K.Escribir(p.Coord, format("%.1f, %.1f", x * 100, y * 100))
			yy = yy + 22
		else
			p.Coord:Hide()
		end
		local hay = G("AlfaMundo") and type(G("AlfaMundo").Abrir) == "function"
		local nota = editando and L["Mientras editas, el mapa espera aquí afuera."]
			or (hay and L["El mapa de Alfa se pone aquí solo; si lo cierras, vuelve con «Ver el mapa aquí»."]
			or L["Prende el módulo Mundo para ver el mapa de Alfa aquí."])
		yy = yy + ESP.s
		parrafo(p.Nota, c, 0, yy, w, 3, nota)
		p.botones:Poner(hay and not editando and { { texto = L["Ver el mapa aquí"], alClic = function()
			if tomarMapa(p, true) then Es.PintarPanel(p, true) end
		end } } or {}, w)
	end })

---------------------------------------------------------------------------
-- Planes: lo que sigues (guías y tu plan)
---------------------------------------------------------------------------
Es.Registrar({ id = "planes", titulo = "Planes", icono = "ic-lista", texto = "Tus guías abiertas y tu plan; clic para seguir otra.",
	forma = "lista", tam = { 6, 6 }, ritmo = 5,
	abrir = function() llamar(G("AlfaRuta"), "EnCurso") end,
	crear = function(p, c)
		p.filas = Filas(c)
		p.vacio = Vacio(c)
		p.botones = Botones(c)
	end,
	pintar = function(p, c, w, h, tam)
		local R = G("AlfaRuta")
		local lista = llamar(R, "ListaEnCurso") or {}
		local abajo = p.botones:Poner({ { texto = L["Abrir Planes"], alClic = function() llamar(R, "EnCurso") end } }, w)
		if #lista == 0 then
			p.filas:Ocultar()
			p.vacio:Poner(w, h - abajo, L["Nada en marcha"], L["Abre una guía o arma tu plan y aquí lo sigues."], "dormido")
			return
		end
		p.vacio:Hide()
		local filas = {}
		for _, it in ipairs(lista) do
			local linea = llamar(R, "LineaEnCurso", it, true)
			filas[#filas + 1] = { icono = it.tipo == "plan" and "ic-lista" or "ic-ruta", color = it.activa and "acento" or "textoSuave",
				texto = it.nombre or "", sub = tam ~= "compacto" and type(linea) == "string" and linea or nil, punto = it.activa == true,
				alClic = function() llamar(R, "SeguirEnCurso", it) Es.PintarPanel(p, true) end }
		end
		p.filas:Poner(filas, w, 0, h - (abajo > 0 and abajo + ESP.s or 0))
	end })

---------------------------------------------------------------------------
-- Avisos: la campanita
---------------------------------------------------------------------------
local function hora(e)
	if type(e.hora) == "string" and e.hora ~= "" then return e.hora end
	local t = tonumber(e.t)
	return t and date and date("%H:%M", t) or ""
end

Es.Registrar({ id = "avisos", titulo = "Avisos", icono = "ic-aviso", texto = "Lo que Alfa te avisó, con su hora y su botón.",
	forma = "lista", tam = { 6, 6 }, ritmo = 3,
	abrir = function() if N.VerAvisos then N.VerAvisos() end end,
	menu = function() return { { valor = "vistos", texto = L["Marcar todo como visto"], icono = "ic-exito" } } end,
	alMenu = function(p, v) if v == "vistos" and N.MarcarAvisosVistos then N.MarcarAvisosVistos() Es.PintarPanel(p, true) end end,
	crear = function(p, c)
		p.filas = Filas(c)
		p.vacio = Vacio(c)
		p.botones = Botones(c)
	end,
	pintar = function(p, c, w, h, tam)
		local lista = N.Avisos and N.Avisos() or {}
		local abajo = p.botones:Poner(#lista > 0 and { { texto = L["Ver todos"], alClic = function() if N.VerAvisos then N.VerAvisos() end end } } or {}, w)
		if #lista == 0 then
			p.filas:Ocultar()
			p.vacio:Poner(w, h - abajo, L["Sin avisos"], L["Lo que te avise Alfa queda aquí, para que no se te pase."], "dormido")
			return
		end
		p.vacio:Hide()
		local filas = {}
		for _, e in ipairs(lista) do
			if #filas >= 12 then break end
			local ac = N.IrDeAviso and N.IrDeAviso(e)
			filas[#filas + 1] = { icono = e.icono or "ic-aviso", color = e.visto and "textoTenue" or "acento", texto = e.titulo or e.texto or "",
				sub = tam ~= "compacto" and e.titulo and e.texto ~= "" and e.texto or nil, valor = hora(e), colorValor = "textoTenue",
				punto = not e.visto and not e.reciente,
				alClic = function()
					if N.MarcarVisto then N.MarcarVisto(e) end
					if ac then K.Llamar(ac.alClic or ac.fn) end
					Es.PintarPanel(p, true)
				end }
		end
		p.filas:Poner(filas, w, 0, h - (abajo > 0 and abajo + ESP.s or 0))
	end })

---------------------------------------------------------------------------
-- Lya: lo que te dijo
---------------------------------------------------------------------------
Es.Registrar({ id = "lya", titulo = "Lya", icono = "ic-lobo", texto = "Lo último que te dijo tu loba compañera, y un consejo a un clic.",
	forma = "texto", tam = { 6, 5 }, ritmo = 3,
	abrir = function() N.Abrir("lya") end,
	crear = function(p, c)
		p.Cara = c:CreateTexture(nil, "ARTWORK")
		p.Cara:SetSize(36, 36)
		p.Cara:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
		p.Cara:SetTexture(K.Lobo("normal"))
		K.Pintar(p.Cara, function(t) t:SetVertexColor(K.Color(K.Clasico() and "oro" or "acento")) end)
		p.Globo = CreateFrame("Frame", nil, c)
		p.Globo.caja = K.Caja(p.Globo, { fondo = "elevado", borde = "linea", corte = K.CORTE.tarjeta })
		p.Dice = K.Texto(p.Globo, "texto", "texto")
		p.Dice:SetJustifyH("LEFT")
		p.Hora = texto(c, "pequeno", "textoTenue")
		p.filas = Filas(c)
		p.botones = Botones(c)
	end,
	pintar = function(p, c, w, h, tam)
		local Ly = G("AlfaLya")
		local hist = llamar(Ly, "Historial", 8) or {}
		local abajo = p.botones:Poner({
			{ texto = L["Un consejo"], alClic = function() llamar(Ly, "Consejo") Es.PintarPanel(p, true) end },
			{ texto = L["Pregúntale"], alClic = function() llamar(Ly, "Guia") end },
		}, w)
		local alto = h - (abajo > 0 and abajo + ESP.s or 0)
		local primero = hist[1]
		local dice = primero and primero.texto or L["Aquí te cuento lo que vea mientras juegas. ¿Una salchicha?"]
		local gx = 36 + ESP.s
		local gw = w - gx
		p.Globo:ClearAllPoints()
		p.Globo:SetPoint("TOPLEFT", c, "TOPLEFT", gx, 0)
		local lineas = tam == "compacto" and 3 or (tam == "grande" and 6 or 4)
		local th = parrafo(p.Dice, p.Globo, ESP.m, ESP.s + 2, gw - ESP.m * 2, lineas, dice)
		local gh = th + ESP.s * 2 + 4
		p.Globo:SetSize(gw, gh)
		local y = gh + 4
		-- 1.4.0: la hora solo si cabe sobre los botones (antes se encimaba en un panel bajo).
		if primero and primero.hora and primero.hora ~= "" and y + 16 <= alto then
			poner(p.Hora, c, gx, y, gw)
			K.Escribir(p.Hora, primero.hora)
			y = y + 16
		else
			p.Hora:Hide()
		end
		local antes = {}
		for i = 2, #hist do antes[#antes + 1] = { icono = "ic-huella", color = "textoTenue", texto = hist[i].texto, valor = hist[i].hora, colorValor = "textoTenue", lineas = 3 } end
		if tam ~= "compacto" and #antes > 0 then p.filas:Poner(antes, w, y + ESP.s, alto) else p.filas:Ocultar() end
	end })

---------------------------------------------------------------------------
-- El medidor del grupo (el oficial del juego, como Alfa_Combate)
---------------------------------------------------------------------------
local MEDIDOR_TIPOS = { { "dps", "DPS" }, { "dano", "Daño" }, { "cps", "CPS" }, { "curacion", "Curación" } }
local MEDIDOR_SESIONES = { { "actual", "Pelea actual" }, { "anterior", "La anterior" }, { "todo", "Toda la sesión" } }

local function filaMedidor(p, i, c)
	local f = p.barras[i]
	if f then return f end
	f = CreateFrame("Frame", nil, c)
	f.Pista = K.Plano(f, "hundido", "BACKGROUND", 0)
	f.Pista:SetAllPoints(f)
	f.Relleno = f:CreateTexture(nil, "BORDER")
	f.Relleno:SetTexture(K.Ruta("white"))
	f.Relleno:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.Relleno:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	-- Con números secretos (en combate) la barra la llena el juego.
	f.Barra = CreateFrame("StatusBar", nil, f)
	f.Barra:SetAllPoints(f)
	f.Barra:SetStatusBarTexture(K.Ruta("white"))
	f.Pos = texto(f, "numero", "textoSuave")
	f.Pos:SetPoint("LEFT", f, "LEFT", 6, 0)
	f.Nombre = texto(f, "cuerpo", "texto")
	f.Nombre:SetPoint("LEFT", f, "LEFT", 28, 0)
	f.Valor = texto(f, "numero", "texto")
	f.Valor:SetJustifyH("RIGHT")
	f.Valor:SetPoint("RIGHT", f, "RIGHT", -6, 0)
	p.barras[i] = f
	return f
end

Es.Registrar({ id = "medidor", titulo = "Medidor del grupo", icono = "ic-nivel", texto = "El daño o la curación de cada quien, en vivo.",
	forma = "barras", tam = { 8, 8 }, ritmo = 1, enCombate = true, protagonista = true,
	abrir = function() llamar(G("AlfaCombate"), "Abrir") end,
	menu = function(p)
		local ops = {}
		for _, t in ipairs(MEDIDOR_TIPOS) do ops[#ops + 1] = { valor = "t:" .. t[1], texto = L[t[2]], icono = (p.tipo or "dps") == t[1] and "check" or nil } end
		ops[#ops + 1] = { separador = true }
		for _, s in ipairs(MEDIDOR_SESIONES) do ops[#ops + 1] = { valor = "s:" .. s[1], texto = L[s[2]], icono = (p.sesion or "actual") == s[1] and "check" or nil } end
		return ops
	end,
	alMenu = function(p, v)
		local k, x = v:match("^(%a):(.+)$")
		if k == "t" then p.tipo = x elseif k == "s" then p.sesion = x end
		local d = N.Datos(Es.ID)
		d.medidor = { tipo = p.tipo, sesion = p.sesion }
		Es.PintarPanel(p, true)
	end,
	crear = function(p, c)
		local d = N.Datos(Es.ID).medidor
		p.tipo = type(d) == "table" and d.tipo or "dps"
		p.sesion = type(d) == "table" and d.sesion or "actual"
		p.barras = {}
		p.Info = texto(c, "pequeno", "textoTenue")
		p.Pie = texto(c, "pequeno", "textoTenue")
		p.vacio = Vacio(c)
	end,
	pintar = function(p, c, w, h, tam)
		local C = G("AlfaCombate")
		local r = llamar(C, "LeerMedidor", p.sesion, p.tipo, 12)
		local nombreTipo, nombreSes = "", ""
		for _, t in ipairs(MEDIDOR_TIPOS) do if t[1] == p.tipo then nombreTipo = L[t[2]] end end
		for _, s in ipairs(MEDIDOR_SESIONES) do if s[1] == p.sesion then nombreSes = L[s[2]] end end
		poner(p.Info, c, 0, 0, w)
		K.Escribir(p.Info, nombreTipo .. DOT .. nombreSes)
		if type(r) ~= "table" or not r.ok or r.vacia or #(r.filas or {}) == 0 then
			for _, f in ipairs(p.barras) do f:Hide() end
			local linea = type(r) == "table" and type(r.motivo) == "string" and r.motivo or L["Cuando pelees, aquí ves cuánto hace cada quien."]
			p.vacio:Poner(w, h - 18, L["Sin pelea todavía"], linea, "dormido", 24)
			return
		end
		p.vacio:Hide()
		-- El pie: cuánto va la pelea y el total del grupo (tal cual, aunque sea secreto).
		local pie = 0
		if tam ~= "compacto" then
			local dur = num(r.dur)
			local partes = {}
			if dur and dur > 0 then partes[#partes + 1] = format(L["Duración: %s"], N.Duracion(dur)) end
			poner(p.Pie, c, 0, h - 16, w)
			if secreto(r.total) then
				p.Pie:SetText(r.total)
			else
				local tot = llamar(C, "NumeroMedidor", r.total)
				if type(tot) == "string" and tot ~= "" then partes[#partes + 1] = format(L["Total del grupo: %s"], tot) end
				K.Escribir(p.Pie, table.concat(partes, DOT))
			end
			pie = 22
		else
			p.Pie:Hide()
		end
		local cuantas = math.max(5, #r.filas)
		local alto = max(20, min(34, floor((h - 20 - pie) / cuantas) - 2))
		local y = 20
		local n = 0
		local maxv = r.max
		local secretoMax = secreto(maxv) or r.secreto
		for i, x in ipairs(r.filas) do
			if y + alto > h - pie then break end
			n = i
			local f = filaMedidor(p, i, c)
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
			f:SetSize(w, alto)
			local cr, cg, cb = llamar(C, "ColorClase", x.clase)
			cr, cg, cb = cr or 0.6, cg or 0.6, cb or 0.6
			local valor = (p.tipo == "dps" or p.tipo == "cps") and x.porSeg or x.valor
			if secretoMax or secreto(valor) then
				f.Relleno:Hide()
				f.Barra:Show()
				f.Barra:SetStatusBarColor(cr, cg, cb, 0.55)
				f.Barra:SetMinMaxValues(0, r.max)
				f.Barra:SetValue(x.valor)
			else
				f.Barra:Hide()
				local frac = (tonumber(maxv) or 0) > 0 and (tonumber(x.valor) or 0) / maxv or 0
				f.Relleno:SetWidth(max(1, w * max(0, min(1, frac))))
				f.Relleno:SetVertexColor(cr, cg, cb, 0.55)
				f.Relleno:Show()
			end
			K.Escribir(f.Pos, tostring(x.pos or i))
			f.Nombre:SetWidth(max(30, w - 28 - 70))
			escribir(f.Nombre, x.nombre)
			K.ColorTexto(f.Nombre, "texto")
			escribir(f.Valor, llamar(C, "NumeroMedidor", valor) or "")
			f:Show()
			y = y + alto + 2
		end
		for i = n + 1, #p.barras do p.barras[i]:Hide() end
	end })

---------------------------------------------------------------------------
-- Tu última pelea
---------------------------------------------------------------------------
Es.Registrar({ id = "pelea", titulo = "Tu última pelea", icono = "ic-lista", texto = "Cuánto duró, tu daño y tu curación, y lo que más te pegó.",
	forma = "cifras", tam = { 8, 6 }, ritmo = 5,
	abrir = function() llamar(G("AlfaCombate"), "Abrir") end,
	crear = function(p, c)
		p.cifras = Cifras(c)
		p.SecGolpes = texto(c, "mayus", "textoTenue")
		p.golpes = Filas(c)
		p.Golpe = K.Texto(c, "nota", "textoSuave")
		p.Golpe:SetJustifyH("LEFT")
		p.Cuando = texto(c, "pequeno", "textoTenue")
		p.vacio = Vacio(c)
	end,
	pintar = function(p, c, w, h, tam)
		local u = llamar(G("AlfaCombate"), "UltimaPelea")
		if type(u) ~= "table" then
			p.cifras:Poner({}, w, 0, h)
			p.Golpe:Hide()
			p.Cuando:Hide()
			p.vacio:Poner(w, h, L["Todavía no peleas"], L["Al terminar una pelea, aquí queda su resumen."], "dormido")
			return
		end
		p.vacio:Hide()
		local C = G("AlfaCombate")
		local function n(v) return num(v) and (llamar(C, "NumeroMedidor", v) or tostring(floor(v))) or "—" end
		local lista = {
			{ titulo = L["Duró"], valor = num(u.dur) and N.Duracion(u.dur) or "—" },
			{ titulo = L["Tu daño"], valor = n(u.dano), texto = num(u.dps) and format(L["%s por segundo"], n(u.dps)) or nil },
		}
		if num(u.cura) and u.cura > 0 then
			lista[#lista + 1] = { titulo = L["Tu curación"], valor = n(u.cura), texto = num(u.cps) and format(L["%s por segundo"], n(u.cps)) or nil }
		end
		local cols = tam == "compacto" and 2 or #lista
		local hc = p.cifras:Poner(lista, w, 0, h, cols, tam == "grande")
		local y = hc + ESP.m
		local golpes = type(u.golpes) == "table" and u.golpes or nil
		if tam ~= "compacto" and golpes and #golpes > 1 and y + 18 + 26 < h then
			poner(p.SecGolpes, c, 0, y, w)
			K.Escribir(p.SecGolpes, K.Mayus(L["Lo que más te pegó"]))
			y = y + 18
			local filas = {}
			for i, gp in ipairs(golpes) do
				if i > 5 then break end
				if type(gp) == "table" and type(gp.nombre) == "string" then
					filas[#filas + 1] = { icono = "ic-alerta", color = i == 1 and "peligro" or "aviso", texto = gp.nombre,
						valor = num(gp.valor) and n(gp.valor) or nil, colorValor = "textoSuave" }
				end
			end
			y = p.golpes:Poner(filas, w, y, h - 18)
			p.Golpe:Hide()
		else
			p.SecGolpes:Hide()
			p.golpes:Ocultar()
		end
		local g = u.golpe
		if not (golpes and #golpes > 1 and tam ~= "compacto") and type(g) == "table" and type(g.nombre) == "string" and y + 16 < h then
			local t = format(L["Lo que más te pegó: %s"], g.nombre)
			if type(g.quien) == "string" and g.quien ~= "" then t = t .. " (" .. g.quien .. ")" end
			if num(g.cuanto) then t = t .. DOT .. n(g.cuanto) end
			y = y + parrafo(p.Golpe, c, 0, y, w, 2, t) + 4
		else
			p.Golpe:Hide()
		end
		local cuando = num(u.cuando)
		if cuando and time and y + 14 < h then
			poner(p.Cuando, c, 0, y, w)
			K.Escribir(p.Cuando, format(L["Hace %s"], N.Duracion(max(1, time() - cuando), true)))
		else
			p.Cuando:Hide()
		end
	end })

---------------------------------------------------------------------------
-- Pesca
---------------------------------------------------------------------------
Es.Registrar({ id = "pesca", titulo = "Pesca", icono = "ic-pesca", texto = "Cómo va tu lanzamiento, tu habilidad y tu sesión de pesca.",
	forma = "cifras", tam = { 8, 8 }, ritmo = 2, protagonista = true,
	abrir = function() N.Abrir("pesca") end,
	crear = function(p, c)
		p.Estado = K.Texto(c, "subtitulo", "texto")
		p.Estado:SetJustifyH("LEFT")
		p.Hab = texto(c, "pequeno", "textoTenue")
		p.Avance = K.Progreso(c, { alto = 4, tono = "acento" })
		p.cifras = Cifras(c)
		p.botones = Botones(c)
		p.vacio = Vacio(c)
	end,
	pintar = function(p, c, w, h, tam)
		local Pe = G("AlfaPesca")
		if not Pe then
			ocultarTodo({ p.Estado, p.Hab, p.Avance })
			p.cifras:Poner({}, w, 0, h)
			p.botones:Poner({}, w)
			p.vacio:Poner(w, h, L["Pesca está apagada"], L["Prende el módulo Pesca para verla aquí."], "dormido")
			return
		end
		p.vacio:Hide()
		local activo = llamar(Pe, "Activo") == true
		local abajo = p.botones:Poner({
			{ texto = activo and L["Terminar de pescar"] or L["Ponerme a pescar"], activo = not enCombate(), alClic = function() llamar(Pe, "Alternar") Es.PintarPanel(p, true) end },
		}, w)
		local alto = h - (abajo > 0 and abajo + ESP.s or 0)
		local e = llamar(Pe, "Estado") or {}
		local y = 0
		y = y + parrafo(p.Estado, c, 0, y, w, 2, e.texto or L["Pesca"]) + ESP.s
		K.ColorTexto(p.Estado, e.tono == "aviso" and "aviso" or (e.tono == "exito" and "exito" or "texto"))
		local t, r, mx = llamar(Pe, "Habilidad")
		if type(t) == "string" then
			poner(p.Hab, c, 0, y, w)
			K.Escribir(p.Hab, t)
			y = y + 16
			p.Avance:ClearAllPoints()
			p.Avance:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
			p.Avance:Acomodar(w)
			p.Avance:Set(tonumber(r) or 0, tonumber(mx) or 1)
			p.Avance:Show()
			y = y + 4 + ESP.m
		else
			p.Hab:Hide()
			p.Avance:Hide()
		end
		local s, cu = llamar(Pe, "Sesion")
		s, cu = type(s) == "table" and s or {}, type(cu) == "table" and cu or {}
		local lista = {
			{ titulo = L["Capturas"], valor = tostring(tonumber(s.capturas) or 0), texto = format(L["de %d lanzamientos"], tonumber(s.lanzamientos) or 0) },
			{ titulo = L["Éxito"], valor = cu.exito and format("%d%%", floor(cu.exito * 100 + 0.5)) or "—" },
			{ titulo = L["Por hora"], valor = cu.porHora and tostring(floor(cu.porHora + 0.5)) or "—" },
			{ titulo = L["Valor de venta"], valor = N.Dinero(tonumber(s.valor) or 0, true) },
		}
		p.cifras:Poner(lista, w, y, alto, tam == "grande" and 4 or 2, tam == "grande")
	end })

---------------------------------------------------------------------------
-- Tus bolsas
---------------------------------------------------------------------------
local function espacios()
	local CC = rawget(_G, "C_Container")
	local libres, total = 0, 0
	for bolsa = 0, 4 do
		local n, l
		if type(CC) == "table" and type(CC.GetContainerNumSlots) == "function" then
			local ok, a = pcall(CC.GetContainerNumSlots, bolsa)
			n = ok and num(a) or nil
			local ok2, b, fam = pcall(CC.GetContainerNumFreeSlots, bolsa)
			-- Las bolsas especiales (de munición, de almas) no son espacio libre.
			if ok2 and (num(fam) or 0) == 0 then l = num(b) end
		end
		if n then
			total = total + n
			libres = libres + (l or 0)
		end
	end
	return libres, total
end

Es.Registrar({ id = "bolsas", titulo = "Tus bolsas", icono = "ic-bolsas", texto = "Cuánto espacio te queda y lo que juntaste en la sesión.",
	forma = "cifras", tam = { 7, 8 }, ritmo = 3,
	abrir = function() llamar(G("AlfaBolsas"), "Abrir") end,
	crear = function(p, c)
		p.Grande = K.Texto(c, "cifra", "texto")
		p.Grande:SetJustifyH("LEFT")
		p.Linea = texto(c, "nota", "textoSuave")
		p.Avance = K.Progreso(c, { alto = 6, tono = "acento" })
		p.cifras = Cifras(c)
		p.botones = Botones(c)
	end,
	pintar = function(p, c, w, h, tam)
		local B = G("AlfaBolsas")
		local abajo = p.botones:Poner({ { texto = L["Abrir bolsas"], alClic = function()
			if B and type(B.Abrir) == "function" then llamar(B, "Abrir") elseif ToggleAllBags then ToggleAllBags() end
		end } }, w)
		local alto = h - (abajo > 0 and abajo + ESP.s or 0)
		local libres, total = espacios()
		local y = 0
		poner(p.Grande, c, 0, y, w)
		K.Escribir(p.Grande, total > 0 and tostring(libres) or "—")
		K.ColorTexto(p.Grande, libres == 0 and total > 0 and "peligro" or (libres <= 4 and total > 0 and "aviso" or "texto"))
		y = y + 30
		poner(p.Linea, c, 0, y, w)
		K.Escribir(p.Linea, total > 0 and ((libres == 1 and L["libre"] or L["libres"]) .. DOT .. format(L["de %d espacios"], total)) or L["Tus bolsas"])
		y = y + 20
		if total > 0 then
			p.Avance:ClearAllPoints()
			p.Avance:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
			p.Avance:Acomodar(w)
			p.Avance:Set(total - libres, total)
			p.Avance:SetTono(libres == 0 and "peligro" or (libres <= 4 and "aviso" or "acento"))
			p.Avance:Show()
			y = y + 6 + ESP.m
		else
			p.Avance:Hide()
		end
		local s = llamar(B, "Sesion")
		if type(s) == "table" and tam ~= "compacto" then
			p.cifras:Poner({
				{ titulo = L["Botín de la sesión"], valor = tostring(tonumber(s.botin) or 0), texto = L["objetos"] },
				{ titulo = L["Vale"], valor = N.Dinero(tonumber(s.valor) or 0, true), texto = L["si lo vendes"] },
			}, w, y, alto, 2, false)
		else
			p.cifras:Poner({}, w, y, alto)
		end
	end })

---------------------------------------------------------------------------
-- Tu oro
---------------------------------------------------------------------------
Es.Registrar({ id = "oro", titulo = "Tu oro", icono = "ic-oro", texto = "Lo que llevas, lo que ganaste hoy y el de toda la cuenta.",
	forma = "cifras", tam = { 7, 5 }, ritmo = 3,
	abrir = function() N.Abrir("bolsas") end,
	crear = function(p, c)
		p.Grande = K.Texto(c, "cifra", "texto")
		p.Grande:SetJustifyH("LEFT")
		p.filas = Filas(c)
	end,
	pintar = function(p, c, w, h, tam)
		local B = G("AlfaBolsas")
		local oro = num(GetMoney and GetMoney()) or 0
		poner(p.Grande, c, 0, 0, w)
		K.Escribir(p.Grande, N.Dinero(oro, true))
		local s = llamar(B, "Sesion")
		local lista = {}
		if type(s) == "table" then
			lista[#lista + 1] = { icono = "ic-oro", color = "oro", texto = L["Esta sesión"], valor = ((tonumber(s.ganado) or 0) > 0 and "+" or "") .. N.Dinero(tonumber(s.ganado) or 0, true) }
			if (tonumber(s.porHora) or 0) > 0 then lista[#lista + 1] = { icono = "ic-reloj", color = "textoSuave", texto = L["Por hora"], valor = N.Dinero(s.porHora, true) } end
		end
		local cuenta = llamar(B, "OroCuenta")
		if cuenta and cuenta > oro then lista[#lista + 1] = { icono = "ic-personajes", color = "textoSuave", texto = L["Toda la cuenta"], valor = N.Dinero(cuenta, true) } end
		p.filas:Poner(lista, w, 36, h)
	end })

---------------------------------------------------------------------------
-- Reloj y sesión
---------------------------------------------------------------------------
Es.Registrar({ id = "reloj", titulo = "Reloj y sesión", icono = "ic-reloj", texto = "La hora, la del reino, cuánto llevas jugando hoy y en total.",
	forma = "cifras", tam = { 6, 3 }, ritmo = 5, enCombate = true,
	abrir = function() N.Abrir("inicio") end,
	crear = function(p, c)
		p.Hora = K.Texto(c, "cifra", "texto")
		p.Hora:SetJustifyH("LEFT")
		p.Reino = texto(c, "pequeno", "textoTenue")
		p.filas = Filas(c)
	end,
	pintar = function(p, c, w, h, tam)
		local I = G("AlfaInicio")
		local ahora = date and date("%H:%M") or ""
		K.Fuente(p.Hora, (tam ~= "compacto" and h >= 120) and "anuncio" or "cifra")
		poner(p.Hora, c, 0, 0, floor(w * 0.45))
		K.Escribir(p.Hora, ahora)
		local hh, mm = GetGameTime and GetGameTime()
		hh, mm = num(hh), num(mm)
		if hh and mm then
			poner(p.Reino, c, 0, (tam ~= "compacto" and h >= 120) and 40 or 30, floor(w * 0.45))
			K.Escribir(p.Reino, format(L["En el reino: %02d:%02d"], hh, mm))
		else
			p.Reino:Hide()
		end
		local lista = {}
		local e = llamar(I, "Sesion")
		if type(e) == "table" and num(e.dur) then lista[#lista + 1] = { icono = "ic-hoy", color = "acento", texto = L["Esta sesión"], valor = N.Duracion(e.dur, true) } end
		local j = llamar(I, "Jugado")
		if type(j) == "table" and num(j.total) then lista[#lista + 1] = { icono = "ic-reloj", color = "textoSuave", texto = L["En total"], valor = N.Duracion(j.total, true) } end
		local x = floor(w * 0.45) + ESP.s
		local cont = p.filasMarco
		if not cont then
			cont = CreateFrame("Frame", nil, c)
			p.filasMarco = cont
			p.filas = Filas(cont)
		end
		cont:ClearAllPoints()
		cont:SetPoint("TOPLEFT", c, "TOPLEFT", x, 0)
		cont:SetSize(w - x, h)
		p.filas:Poner(lista, w - x, 0, h)
	end })

---------------------------------------------------------------------------
-- Tu grupo (para la mazmorra)
---------------------------------------------------------------------------
local function unidades()
	local out = {}
	local n = GetNumGroupMembers and num(GetNumGroupMembers()) or 0
	if IsInRaid and IsInRaid() == true then
		for i = 1, min(n, 40) do out[#out + 1] = "raid" .. i end
	else
		out[1] = "player"
		for i = 1, min(4, max(0, n - 1)) do out[#out + 1] = "party" .. i end
	end
	return out
end

Es.Registrar({ id = "grupo", titulo = "Tu grupo", icono = "ic-manada", texto = "Quién va contigo, su clase y su vida.",
	forma = "barras", tam = { 8, 8 }, ritmo = 1, enCombate = true,
	abrir = function() N.Abrir("manada") end,
	crear = function(p, c)
		p.barras = {}
		p.vacio = Vacio(c)
	end,
	pintar = function(p, c, w, h, tam)
		if not (IsInGroup and IsInGroup() == true) then
			for _, f in ipairs(p.barras) do f:Hide() end
			p.vacio:Poner(w, h, L["Vas solo"], L["Cuando entres a un grupo, aquí ves a tu manada."], "dormido")
			return
		end
		p.vacio:Hide()
		local lista = unidades()
		local alto = max(22, min(36, floor(h / max(5, #lista)) - 2))
		local y, n = 0, 0
		for i, u in ipairs(lista) do
			if y + alto > h then break end
			if UnitExists and UnitExists(u) then
				n = n + 1
				local f = filaMedidor(p, n, c)
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
				f:SetSize(w, alto)
				local _, clase = UnitClass(u)
				if secreto(clase) then clase = nil end
				local cr, cg, cb = llamar(G("AlfaCombate"), "ColorClase", clase)
				cr, cg, cb = cr or 0.6, cg or 0.6, cb or 0.6
				local vida, maxi = UnitHealth and UnitHealth(u), UnitHealthMax and UnitHealthMax(u)
				local muerto = UnitIsDeadOrGhost and UnitIsDeadOrGhost(u)
				if secreto(vida) or secreto(maxi) then
					f.Relleno:Hide()
					f.Barra:Show()
					f.Barra:SetStatusBarColor(cr, cg, cb, 0.55)
					f.Barra:SetMinMaxValues(0, maxi)
					f.Barra:SetValue(vida)
					f.Valor:SetText("")
				else
					f.Barra:Hide()
					local frac = (num(maxi) or 0) > 0 and (num(vida) or 0) / maxi or 0
					f.Relleno:SetWidth(max(1, w * max(0, min(1, frac))))
					f.Relleno:SetVertexColor(cr, cg, cb, 0.55)
					f.Relleno:Show()
					K.Escribir(f.Valor, N.Si(muerto) and L["Caído"] or format("%d%%", floor(frac * 100 + 0.5)))
				end
				local lv = UnitLevel and num(UnitLevel(u))
				K.Escribir(f.Pos, lv and tostring(lv) or "")
				f.Nombre:SetWidth(max(30, w - 28 - 60))
				escribir(f.Nombre, UnitName and UnitName(u) or "")
				f:Show()
				y = y + alto + 2
			end
		end
		for i = n + 1, #p.barras do p.barras[i]:Hide() end
	end })

---------------------------------------------------------------------------
-- 1.3.9: más paneles (Tus misiones, Cerrar mis misiones, Enciclopedia rápida,
-- ¿Dónde está la manada?, Mapa de la mazmorra). Como los demás: usan lo que
-- ya hace cada módulo (AlfaRuta, AlfaEnciclopedia, AlfaManada, AlfaMazmorras).
---------------------------------------------------------------------------

-- Tu diario: { { id, titulo, nivel, lista, meta } } (lo secreto no se lee).
local function diario()
	local out = {}
	local Q = rawget(_G, "C_QuestLog")
	if type(Q) ~= "table" or type(Q.GetNumQuestLogEntries) ~= "function" or type(Q.GetInfo) ~= "function" then return out end
	local ok, n = pcall(Q.GetNumQuestLogEntries)
	n = ok and num(n) or 0
	for i = 1, min(n, 60) do
		local okI, info = pcall(Q.GetInfo, i)
		if okI and type(info) == "table" and not secreto(info) and info.isHeader ~= true and info.isHidden ~= true then
			local id = num(info.questID)
			if id and id > 0 then
				local lista = info.isComplete == true or info.isComplete == 1
				if not lista and type(Q.IsComplete) == "function" then
					local okc, c = pcall(Q.IsComplete, id)
					lista = okc and c == true
				end
				local meta
				if not lista and type(Q.GetQuestObjectives) == "function" then
					local oko, objs = pcall(Q.GetQuestObjectives, id)
					for _, o in ipairs(oko and type(objs) == "table" and objs or {}) do
						if type(o) == "table" and o.finished ~= true and type(o.text) == "string" and not secreto(o.text) and o.text ~= "" then meta = o.text break end
					end
				end
				local titulo = info.title
				out[#out + 1] = { id = id, titulo = (type(titulo) == "string" and not secreto(titulo)) and titulo or "?", nivel = num(info.level), lista = lista, meta = meta }
			end
		end
	end
	table.sort(out, function(a, b)
		if a.lista ~= b.lista then return a.lista end
		return (a.nivel or 0) < (b.nivel or 0)
	end)
	return out
end
Es.Diario = diario

local function cerrarMisiones()
	local R = G("AlfaRuta")
	if R and type(R.CerrarTodo) == "function" then return llamar(R, "CerrarTodo") end
	return llamar(R, "Liberar", "todas")
end

Es.Registrar({ id = "misiones", titulo = "Tus misiones", icono = "ic-misiones", texto = "Tu diario: lo que llevas de cada misión, las listas primero.",
	forma = "lista", tam = { 6, 8 }, ritmo = 3,
	abrir = function() llamar(G("AlfaRuta"), "Pagina") end,
	crear = function(p, c)
		p.filas = Filas(c)
		p.vacio = Vacio(c)
		p.botones = Botones(c)
	end,
	pintar = function(p, c, w, h, tam)
		local lista = diario()
		local abajo = p.botones:Poner(#lista > 0 and { { texto = L["Cerrar mis misiones"], alClic = cerrarMisiones } } or {}, w)
		if #lista == 0 then
			p.filas:Ocultar()
			p.vacio:Poner(w, h - abajo, L["Tu diario está vacío"], L["Toma misiones y aquí ves cuánto te falta de cada una."], "dormido")
			return
		end
		p.vacio:Hide()
		local filas = {}
		for _, q in ipairs(lista) do
			if #filas >= 15 then break end
			local id = q.id
			filas[#filas + 1] = { icono = q.lista and "ic-exito" or "ic-misiones", color = q.lista and "exito" or "mision",
				texto = q.titulo, sub = tam ~= "compacto" and (q.lista and L["Lista para entregar"] or q.meta) or nil,
				valor = q.nivel and tostring(q.nivel) or nil, colorValor = "textoTenue", lineas = 1,
				alClic = function() llamar(G("AlfaRuta"), "VerCadena", id) end }
		end
		p.filas:Poner(filas, w, 0, h - (abajo > 0 and abajo + ESP.s or 0))
	end })

Es.Registrar({ id = "cerrar", titulo = "Cerrar mis misiones", icono = "ic-misiones", texto = "Tus misiones en el mejor orden, con un clic.",
	forma = "cifras", tam = { 6, 5 }, ritmo = 5,
	abrir = cerrarMisiones,
	crear = function(p, c)
		p.cifras = Cifras(c)
		p.botones = Botones(c)
		p.Nota = texto(c, "nota", "textoSuave")
	end,
	pintar = function(p, c, w, h, tam)
		local lista = diario()
		local listas = 0
		for _, q in ipairs(lista) do if q.lista then listas = listas + 1 end end
		local R = G("AlfaRuta")
		local abajo = p.botones:Poner({
			{ texto = L["Cerrar mis misiones"], alClic = cerrarMisiones, activo = #lista > 0 },
			{ texto = L["Solo las listas"], alClic = function() llamar(R, "Entregar") end, activo = listas > 0 },
		}, w)
		local alto = h - (abajo > 0 and abajo + ESP.s or 0)
		local y = p.cifras:Poner({
			{ titulo = L["En tu diario"], valor = tostring(#lista), texto = format(L["de %d"], 20) },
			{ titulo = L["Listas para entregar"], valor = tostring(listas), colorValor = listas > 0 and "exito" or "texto" },
		}, w, 0, alto, 2)
		if y + ESP.s + 16 <= alto then
			local t = #lista == 0 and L["Toma misiones y Alfa te arma la ruta para cerrarlas todas."]
				or L["Alfa arma la ruta con todas tus misiones: zona por zona, juntando lo cercano y las entregas al final."]
			parrafo(p.Nota, c, 0, y + ESP.s, w, 3, t)
		else
			p.Nota:Hide()
		end
	end })

Es.Registrar({ id = "enciclopedia", titulo = "Enciclopedia rápida", icono = "ic-enciclopedia", texto = "Busca cualquier cosa del juego y vuelve a lo último que viste.",
	forma = "lista", tam = { 6, 6 },
	abrir = function() llamar(G("AlfaEnciclopedia"), "Abrir") end,
	crear = function(p, c)
		p.Buscar = K.Buscador(c, { ayuda = L["Busca, en español o en inglés…"], retraso = 0,
			alEnter = function(t) if t and t ~= "" then llamar(G("AlfaEnciclopedia"), "Buscar", t) end end })
		p.Sec = texto(c, "mayus", "textoTenue")
		p.filas = Filas(c)
	end,
	pintar = function(p, c, w, h, tam)
		p.Buscar:ClearAllPoints()
		p.Buscar:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
		p.Buscar:SetWidth(w)
		p.Buscar:Show()
		local y = K.ALTO.control + ESP.base
		local E = G("AlfaEnciclopedia")
		local rec = llamar(E, "Recientes") or {}
		if #rec == 0 or y + 18 + 24 > h then
			p.Sec:Hide()
			p.filas:Ocultar()
			return
		end
		poner(p.Sec, c, 0, y, w)
		K.Escribir(p.Sec, K.Mayus(L["Lo último que viste"]))
		y = y + 18
		local filas = {}
		for _, r in ipairs(rec) do
			if #filas >= 8 then break end
			local kind, id = r.kind, r.id
			filas[#filas + 1] = { icono = r.icono or "ic-enciclopedia", color = "textoSuave", texto = r.nombre or "?", lineas = 1,
				alClic = function() llamar(E, "Abrir", kind, id) end }
		end
		p.filas:Poner(filas, w, y, h)
	end })

Es.Registrar({ id = "manada", titulo = "¿Dónde está la manada?", icono = "ic-manada", texto = "Los lobos de tu hermandad con Alfa conectados: su zona y su nivel.",
	forma = "lista", tam = { 6, 7 }, ritmo = 10,
	abrir = function() llamar(G("AlfaManada"), "AbrirLobos") end,
	crear = function(p, c)
		p.filas = Filas(c)
		p.vacio = Vacio(c)
		p.botones = Botones(c)
	end,
	pintar = function(p, c, w, h, tam)
		local Mn = G("AlfaManada")
		local lista = llamar(Mn, "Conectados") or {}
		local abajo = p.botones:Poner({ { texto = L["Lobos con Alfa"], alClic = function() llamar(Mn, "AbrirLobos") end } }, w)
		if #lista == 0 then
			p.filas:Ocultar()
			p.vacio:Poner(w, h - abajo, L["La manada anda lejos"], (IsInGuild and IsInGuild()) and L["Cuando alguien de tu hermandad con Alfa se conecte, aquí ves dónde anda."]
				or L["Con una hermandad, aquí ves dónde anda cada lobo con Alfa."], "dormido")
			return
		end
		p.vacio:Hide()
		local filas = {}
		for _, e in ipairs(lista) do
			if #filas >= 12 then break end
			local partes = {}
			if e.zona then partes[#partes + 1] = e.zona end
			local nombre = e.nombre
			filas[#filas + 1] = { icono = "ic-lobo", color = e.vieja and "aviso" or "acento", texto = nombre,
				sub = tam ~= "compacto" and (#partes > 0 and table.concat(partes, DOT) or L["No comparte dónde anda"]) or nil,
				valor = e.nivel and tostring(e.nivel) or nil, colorValor = "textoTenue",
				alClic = function() llamar(Mn, "Ficha", nombre) end }
		end
		p.filas:Poner(filas, w, 0, h - (abajo > 0 and abajo + ESP.s or 0))
	end })

Es.Registrar({ id = "mapaMazmorra", titulo = "Mapa de la mazmorra", icono = "ic-mazmorra", texto = "Dentro de una mazmorra: su plano, el piso y por dónde vas con sus jefes.",
	forma = "texto", tam = { 8, 8 }, ritmo = 2,
	abrir = function() llamar(G("AlfaMazmorras"), "MapaDentro") end,
	crear = function(p, c)
		p.vacio = Vacio(c)
		p.botones = Botones(c)
		p.Nota = texto(c, "nota", "textoSuave")
		local Mz = G("AlfaMazmorras")
		p.plano = Mz and type(Mz.CrearPlano) == "function" and Mz.CrearPlano(c) or nil
		if p.plano then p.plano:Hide() end
	end,
	pintar = function(p, c, w, h, tam)
		local Mz = G("AlfaMazmorras")
		local s = llamar(Mz, "LeerMapaDentro")
		local abajo = p.botones:Poner({ { texto = L["Abrir el mapa"], alClic = function() llamar(Mz, "MapaDentro") end } }, w)
		local alto = h - (abajo > 0 and abajo + ESP.s or 0)
		if type(s) ~= "table" or not s.dentro then
			if p.plano then p.plano:Hide() end
			p.Nota:Hide()
			p.vacio:Poner(w, alto, L["No estás en una mazmorra"], L["Al entrar a una, aquí ves su plano y por dónde vas."], "dormido")
			return
		end
		p.vacio:Hide()
		local partes = {}
		local av = llamar(Mz, "AvanceDentro", s.key)
		if av then partes[#partes + 1] = av end
		if s.piso and s.pisos and #s.pisos > 1 and s.pisos[s.piso] then partes[#partes + 1] = format(L["Estás en: %s."], s.pisos[s.piso].nombre) end
		local hn = parrafo(p.Nota, c, 0, 0, w, 3, table.concat(partes, " "))
		local y = hn + ESP.s
		local pl = p.plano
		if pl and s.arte and alto - y > 60 then
			pl:ClearAllPoints()
			pl:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
			pl:SetSize(w, alto - y)
			if pl.mapaArte ~= s.ver then pl.mapaArte = s.ver pl.zoom, pl.ox, pl.oy = 1, 0, 0 pl:SetArte(s.arte) end
			pl.px, pl.py = s.x, s.y
			pl:Show()
			pl:Colocar()
		elseif pl then
			pl:Hide()
		end
	end })
