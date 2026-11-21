-- Alfa - Bolsas: «Tu oro», el desglose del oro de tus personajes
-- (toxic3000 / La Jauría). GPL-3.0. 1.3.7.
--
-- El pie de tus bolsas enseña solo el oro del personaje que miras; el botón
-- de monedas de al lado abre (y cierra) este panelito, pegado a la ventana de
-- bolsas: una fila por personaje con el color de su clase (tú primero, luego
-- de más a menos oro, y de los demás «visto hace 3 días»), un subtotal por
-- reino y facción (ese oro no se pasa de uno a otro), «Toda la cuenta» y
-- «Esta sesión» (Sesion.lua: ganado, gastado, del buzón, en total, por hora,
-- y tu farmeo). Clic en otro personaje: sus bolsas (Ventana.Ver).
-- Solo lee lo que guardó Datos.lua; el personaje actual, al día.
--   Or.Grupos() -> grupos { { clave, reino, faccion, total, filas = { { clave, r, dinero, actual } } } }, total
--   Or.Abrir(win) ; Or.Cerrar() ; Or.Alternar(win) ; Or.Visible() ; Or.Pintar()

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D = M.Datos
local K = N.Kit
local ESP = K.ESP

local type, ipairs, tonumber, tostring, format = type, ipairs, tonumber, tostring, string.format
local floor, max, min, sort = math.floor, math.max, math.min, table.sort

local Or = {}
M.Oro = Or

Or.ANCHO, Or.ANCHO_MAX = 300, 420
local CAB_H, FILA_H, GRUPO_H, TOTAL_H = 40, 36, 26, 30
local PAD = ESP.m
local NOMBRE_MIN = 96 -- lo mínimo para el nombre antes de ensanchar el panel

local panel -- el marco (se crea al abrirlo la primera vez)

---------------------------------------------------------------------------
-- Los datos
---------------------------------------------------------------------------

local FACCION = { Alliance = "Alianza", Horde = "Horda" }

local function reinoDe(p)
	local r = p.r
	if type(r.reino) == "string" and r.reino ~= "" then return r.reino end
	return tostring(p.clave):match("%-(.+)$") or "?"
end

-- "Reino · Horda"
function Or.TituloGrupo(g)
	local f = g.faccion and FACCION[g.faccion]
	if f then return g.reino .. "  \194\183  " .. L[f] end
	return g.reino
end

-- Tus personajes por reino y facción: el tuyo primero; en cada grupo, de más
-- a menos oro (tú siempre arriba). -> grupos, total de la cuenta
function Or.Grupos()
	local actual = D.Clave()
	local porClave, grupos, total = {}, {}, 0
	for _, p in ipairs(D.Lista()) do
		local esActual = p.clave == actual
		local dinero = (esActual and M.Num(GetMoney and GetMoney())) or tonumber(p.r.dinero) or 0
		local reino = reinoDe(p)
		local faccion = (p.r.faccion == "Alliance" or p.r.faccion == "Horde") and p.r.faccion or nil
		local k = reino .. "|" .. (faccion or "")
		local g = porClave[k]
		if not g then
			g = { clave = k, reino = reino, faccion = faccion, total = 0, filas = {} }
			porClave[k] = g
			grupos[#grupos + 1] = g
		end
		if esActual then g.tuyo = true end
		g.filas[#g.filas + 1] = { clave = p.clave, r = p.r, dinero = dinero, actual = esActual }
		g.total = g.total + dinero
		total = total + dinero
	end
	local function filaAntes(a, b)
		if a.actual ~= b.actual then return a.actual end
		if a.dinero ~= b.dinero then return a.dinero > b.dinero end
		return tostring(a.r.nombre or a.clave) < tostring(b.r.nombre or b.clave)
	end
	for _, g in ipairs(grupos) do sort(g.filas, filaAntes) end
	sort(grupos, function(a, b)
		if (a.tuyo or false) ~= (b.tuyo or false) then return a.tuyo and true or false end
		if a.total ~= b.total then return a.total > b.total end
		return a.clave < b.clave
	end)
	return grupos, total
end

---------------------------------------------------------------------------
-- El panel
---------------------------------------------------------------------------

local function ventanaBolsas()
	local V = M.Ventana
	return V and V.Ventana and V.Ventana("bolsas") or nil
end

local function verPersonaje(clave)
	local V = M.Ventana
	local win = panel and panel.win or ventanaBolsas()
	if not (V and win) then return end
	V.Ver(win, (clave and not D.EsActual(clave)) and clave or nil)
	Or.Pintar()
end

local function fila(f, i)
	local b = f.filas[i]
	if b then return b end
	b = CreateFrame("Button", nil, f.Contenido)
	b:SetHeight(FILA_H)
	b.velo = K.Velo(b, K.CORTE.chico, 0.06)
	b.Marca = K.Plano(b, "acento", "ARTWORK", 1)
	b.Marca:SetWidth(2)
	b.Marca:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -6)
	b.Marca:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 6)
	b.Nombre = K.Texto(b, "cuerpo", "texto")
	b.Nombre:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -4)
	b.Detalle = K.Texto(b, "pequeno", "textoTenue")
	b.Detalle:SetPoint("TOPLEFT", b.Nombre, "BOTTOMLEFT", 0, -2)
	b.Dinero = K.Texto(b, "numero", "texto")
	b.Dinero:SetPoint("RIGHT", b, "RIGHT", -6, 0)
	b.Dinero:SetJustifyH("RIGHT")
	b:SetScript("OnEnter", function(self) self.velo:Show() end)
	b:SetScript("OnLeave", function(self) self.velo:Hide() end)
	b:SetScript("OnClick", function(self) verPersonaje(self.clave) end)
	K.ConInfo(b, function(self)
		local r = self.r
		if not r then return nil end
		local nombre = tostring(r.nombre or self.clave)
		if self.actual then return nombre, L["Clic para volver a tus bolsas."] end
		return nombre, L["Clic para ver sus bolsas."]
	end)
	f.filas[i] = b
	return b
end

local function grupo(f, i)
	local h = f.grupos[i]
	if h then return h end
	h = CreateFrame("Frame", nil, f.Contenido)
	h:SetHeight(GRUPO_H)
	h.Texto = K.Texto(h, "encabezado", "textoSuave")
	h.Texto:SetPoint("LEFT", h, "LEFT", 8, -2)
	h.Total = K.Texto(h, "numero", "textoSuave")
	h.Total:SetPoint("RIGHT", h, "RIGHT", -6, -2)
	h.Total:SetJustifyH("RIGHT")
	h.Linea = K.Linea(h, "linea")
	h.Linea:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 6, 0)
	h.Linea:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -6, 0)
	f.grupos[i] = h
	return h
end

local function linea(f, i)
	local t = f.lineas[i]
	if t then return t end
	t = K.Texto(f.Contenido, "nota", "textoSuave")
	f.lineas[i] = t
	return t
end

local function crear()
	local f = CreateFrame("Frame", "AlfaBolsasOro", UIParent)
	f:SetFrameStrata("HIGH")
	f:SetFrameLevel(30)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetSize(Or.ANCHO, 200)
	f:Hide()
	f.caja = K.Caja(f, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel })
	f.filas, f.grupos, f.lineas = {}, {}, {}

	f.Icono = K.Icono(f, "ic-oro", 16, "acento")
	f.Icono:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(CAB_H - 16) / 2)
	f.Titulo = K.Texto(f, "subtitulo", "texto")
	f.Titulo:SetPoint("LEFT", f.Icono, "RIGHT", ESP.s, 0)
	K.Escribir(f.Titulo, L["Tu oro"])
	f.Cerrar = K.BotonIcono(f, "ic-cerrar", function() Or.Cerrar() end, { tam = 24, icono = 12, ayuda = L["Cerrar"] })
	f.Cerrar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -ESP.s, -(CAB_H - 24) / 2)
	f.Linea = K.Linea(f, "linea")
	f.Linea:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -CAB_H)
	f.Linea:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -CAB_H)

	f.Desp = K.Desplazable(f)
	f.Desp:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.xs, -(CAB_H + ESP.xs))
	f.Contenido = f.Desp.Contenido

	-- «Toda la cuenta» y «Esta sesión» viven en el contenido, después de las filas.
	f.Total = CreateFrame("Frame", nil, f.Contenido)
	f.Total:SetHeight(TOTAL_H)
	f.Total.Linea = K.Linea(f.Total, "lineaFuerte")
	f.Total.Linea:SetPoint("TOPLEFT", f.Total, "TOPLEFT", 6, -2)
	f.Total.Linea:SetPoint("TOPRIGHT", f.Total, "TOPRIGHT", -6, -2)
	f.Total.Texto = K.Texto(f.Total, "encabezado", "acento")
	f.Total.Texto:SetPoint("LEFT", f.Total, "LEFT", 8, -2)
	K.Escribir(f.Total.Texto, L["Toda la cuenta"])
	f.Total.Dinero = K.Texto(f.Total, "numero", "texto")
	f.Total.Dinero:SetPoint("RIGHT", f.Total, "RIGHT", -6, -2)
	f.Total.Dinero:SetJustifyH("RIGHT")
	f.Sesion = K.Texto(f.Contenido, "encabezado", "texto")
	K.Escribir(f.Sesion, L["Esta sesión"])

	f:SetScript("OnHide", function()
		local win = f.win
		if win and win.Monedas then win.Monedas:SetMarcado(false) end
	end)
	if A.CloseOnEscape then A.CloseOnEscape("AlfaBolsasOro") end
	panel = f
	return f
end

-- Pega el panel a la izquierda de la ventana de bolsas, a la altura del pie.
local function anclar(f)
	f:ClearAllPoints()
	local win = f.win
	if win then
		f:SetPoint("BOTTOMRIGHT", win, "BOTTOMLEFT", -ESP.xs, 0)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

function Or.Pintar()
	local f = panel
	if not (f and f:IsShown()) then return end
	local grupos, total = Or.Grupos()
	local conGrupos = #grupos > 1
	local viendo = f.win and f.win.clave or nil

	-- El ancho: el del oro más largo y un nombre que quepa (sin pasar del tope).
	local maxDinero = 0
	local function medir(fs, texto)
		K.Escribir(fs, texto)
		local w = K.Ajustar(fs)
		if w > maxDinero then maxDinero = w end
		return w
	end
	medir(f.Total.Dinero, N.Dinero(total, true))
	local textos = {}
	for gi, g in ipairs(grupos) do
		textos[gi] = N.Dinero(g.total, true)
		for _, x in ipairs(g.filas) do x.texto = N.Dinero(x.dinero, true) end
	end
	local ancho = Or.ANCHO
	local util -- el ancho del contenido
	local function anchoUtil() return ancho - 2 * ESP.xs - 12 end
	local filasN, gruposN = 0, 0
	local y = 0

	-- Primero se escriben para medirlos; luego se acomodan con el ancho final.
	local puestos = {}
	for gi, g in ipairs(grupos) do
		if conGrupos then
			gruposN = gruposN + 1
			local h = grupo(f, gruposN)
			K.Escribir(h.Texto, Or.TituloGrupo(g))
			medir(h.Total, textos[gi])
			puestos[#puestos + 1] = { tipo = "grupo", h = h }
		end
		for _, x in ipairs(g.filas) do
			filasN = filasN + 1
			local b = fila(f, filasN)
			b.clave, b.r, b.actual = x.clave, x.r, x.actual
			local cr, cg, cb = M.ColorClase(x.r.clase)
			local nombre = tostring(x.r.nombre or x.clave:match("^(.-)%-") or x.clave)
			K.Escribir(b.Nombre, M.Pintado(nombre, cr, cg, cb))
			local partes = {}
			local nivel = tonumber(x.r.nivel)
			if nivel then partes[#partes + 1] = format(L["Nivel %d"], nivel) end
			if x.actual then
				partes[#partes + 1] = L["tú, ahora"]
			else
				partes[#partes + 1] = format(L["visto %s"], M.Hace(x.r.visto))
			end
			K.Escribir(b.Detalle, table.concat(partes, "  \194\183  "))
			medir(b.Dinero, x.texto)
			local esViendo = (viendo == nil and x.actual) or (viendo ~= nil and viendo == x.clave)
			b.Marca:SetShown(esViendo and true or false)
			puestos[#puestos + 1] = { tipo = "fila", b = b }
		end
	end
	ancho = min(Or.ANCHO_MAX, max(Or.ANCHO, maxDinero + NOMBRE_MIN + 8 + 6 + ESP.s + 2 * ESP.xs + 12))
	util = anchoUtil()

	for _, p in ipairs(puestos) do
		if p.tipo == "grupo" then
			local h = p.h
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", f.Contenido, "TOPLEFT", 0, -y)
			h:SetWidth(util)
			local tw = K.AnchoTexto(h.Total)
			K.Ajustar(h.Texto, max(40, util - 8 - 6 - tw - ESP.s - 2)) -- (K.Ajustar suma 1 a cada texto)
			h:Show()
			y = y + GRUPO_H + 2
		else
			local b = p.b
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", f.Contenido, "TOPLEFT", 0, -y)
			b:SetWidth(util)
			local tope = max(40, util - 8 - 6 - K.AnchoTexto(b.Dinero) - ESP.s - 2)
			K.Ajustar(b.Nombre, tope)
			K.Ajustar(b.Detalle, tope)
			b:Show()
			y = y + FILA_H
		end
	end
	for i = filasN + 1, #f.filas do f.filas[i]:Hide() end
	for i = gruposN + 1, #f.grupos do f.grupos[i]:Hide() end

	-- Toda la cuenta.
	y = y + ESP.xs
	f.Total:ClearAllPoints()
	f.Total:SetPoint("TOPLEFT", f.Contenido, "TOPLEFT", 0, -y)
	f.Total:SetWidth(util)
	K.Ajustar(f.Total.Texto, max(40, util - 8 - 6 - K.AnchoTexto(f.Total.Dinero) - ESP.s - 2))
	y = y + TOTAL_H + ESP.s

	-- Esta sesión (y tu farmeo).
	local Se = M.Sesion
	local lineasN = 0
	if Se then
		f.Sesion:ClearAllPoints()
		f.Sesion:SetPoint("TOPLEFT", f.Contenido, "TOPLEFT", 8, -y)
		K.Ajustar(f.Sesion, util - 16)
		f.Sesion:Show()
		y = y + K.AltoTexto(f.Sesion) + ESP.xs
		local todas = Se.Lineas()
		for _, l in ipairs(Se.LineasFarmeo and Se.LineasFarmeo() or {}) do todas[#todas + 1] = l end
		for _, l in ipairs(todas) do
			lineasN = lineasN + 1
			local t = linea(f, lineasN)
			K.Escribir(t, l)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", f.Contenido, "TOPLEFT", 8, -y)
			y = y + K.Parrafo(t, util - 16, 2) + 2
			t:Show()
		end
		y = y + ESP.s
	else
		f.Sesion:Hide()
	end
	for i = lineasN + 1, #f.lineas do f.lineas[i]:Hide() end

	-- El alto: todo, sin pasar del 70 % de la pantalla (lo demás se desplaza).
	local pantalla = (UIParent and tonumber(UIParent:GetHeight())) or 768
	local cuerpo = min(y, max(120, floor(pantalla * 0.7) - CAB_H))
	f:SetSize(ancho, CAB_H + ESP.xs + cuerpo + ESP.xs)
	f.Desp:Acomodar(ancho - 2 * ESP.xs, cuerpo)
	f.Desp:SetAltoContenido(y)
	f.ancho, f.util, f.alto = ancho, util, y
	anclar(f)
end

function Or.Visible() return panel ~= nil and panel:IsShown() end

function Or.Abrir(win)
	local f = panel or crear()
	f.win = win or ventanaBolsas()
	f:Show()
	if f.win and f.win.Monedas then f.win.Monedas:SetMarcado(true) end
	Or.Pintar()
	return f
end

function Or.Cerrar()
	if panel and panel:IsShown() then panel:Hide() end
end

function Or.Alternar(win)
	if Or.Visible() then Or.Cerrar() else Or.Abrir(win) end
end

function Or.Panel() return panel end

-- Al día: el dinero, la sesión (varias veces seguidas: una sola) y los datos guardados.
local function luego()
	if not Or.Visible() then return end
	if N.Una then N.Una("bolsas.oro", 0.2, Or.Pintar) else Or.Pintar() end
end
A.RegisterEvent("PLAYER_MONEY", luego)
M.Escuchar("SESION", luego)
M.Escuchar("DATOS", luego)
M.Escuchar("DINERO", luego)
K.AlRepintar(function() if Or.Visible() then Or.Pintar() end end)
