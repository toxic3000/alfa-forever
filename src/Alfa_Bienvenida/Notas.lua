-- Alfa - Bienvenida: las notas de una versión nueva (toxic3000 / La Jauría).
-- GPL-3.0.
--
-- Una ventana chica del Kit, en el centro: "Lo nuevo en Alfa X.Y.Z", el
-- nombre de la versión, un saludo y sus puntos (M.NOTAS en Novedades.lua),
-- con "Seguir jugando" y "Ver todo lo nuevo" (la portada). Se cierra con Esc,
-- con la X o con "Seguir jugando". Cuándo sale lo decide Bienvenida.lua
-- (al entrar, después de la intro del lobo); aquí solo se arma y se mide.
-- Si entras en combate con la ventana abierta, se esconde y vuelve sola al
-- terminar la pelea.
--
--   M.AbrirNotas(nota)      la abre con esas notas (nil: las de tu versión)
--   M.NotasVisibles()       true si está a la vista
--   M.BloquePuntos(padre)   los puntos de una versión, para cualquier pila:
--                           b:Set(nota) ; b:Acomodar(ancho) -> alto

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP

local format = string.format
local max, min, floor = math.max, math.min, math.floor

local ANCHO = 540           -- el de la ventana
local ANCHO_BIENVENIDA = 700 -- 1.4.0 (84): con las tarjetas de una versión grande
local ICONO = 16            -- el de cada punto
local CABECERA, PIE = K.ALTO.cabecera, K.ALTO.pie

---------------------------------------------------------------------------
-- Los puntos de una versión: el ícono a la izquierda, alineado con el primer
-- renglón, y el texto que baja de renglón a su lado.
---------------------------------------------------------------------------
-- 1.3.7: un punto puede llevar a donde se prueba (su 3.er campo, una clave de
-- M.IR_NOTA): sale «Ver» a la derecha y las notas se cierran al ir.
M.IR_NOTA = {
	avisos = function() if N.VerAvisos then N.VerAvisos() end end,
	ventana = function() N.Abrir("inicio") end,
	combate = function() N.Abrir("combate") end,
	pesca = function() N.Abrir("pesca") end,
	anuncios = function() N.Abrir("bienvenida") end,
	-- 1.3.8
	pantallas = function()
		local E = rawget(_G, "AlfaEscritorio")
		if type(E) == "table" and type(E.Abrir) == "function" then E.Abrir() else N.Abrir("pantallas") end
	end,
	manada = function() N.Abrir("manada") end,
	curacion = function() N.Abrir("curacion") end,
	enciclopedia = function()
		local E = rawget(_G, "AlfaEnciclopedia")
		if type(E) == "table" and type(E.Abrir) == "function" then E.Abrir("objeto") else N.Abrir("enciclopedia") end
	end,
	oro = function()
		local B = rawget(_G, "AlfaBolsas")
		if type(B) == "table" and type(B.Abrir) == "function" then B.Abrir() else N.Abrir("bolsas") end
	end,
	-- 1.4.0
	bando = function() if K.VistaBandos then K.VistaBandos() end end,
	buscar = function()
		N.Abrir("inicio")
		local O = A.UI and A.UI.Options
		local w = O and O.frame
		if w and w.Search and w.Search.SetFocus then w.Search:SetFocus() end
	end,
	contraste = function() N.Abrir("bienvenida") end,
	reporte = function() if M.AbrirReporte then M.AbrirReporte() end end,
	-- 1.4.0 (84): los «Pruébalo» de la bienvenida de la 1.4.
	anuncios140 = function()
		local f = rawget(K, "ProbarAnuncio")
		if type(f) == "function" then K.Llamar(f) else N.Abrir("bienvenida") end
	end,
	acomodar = function()
		local Ac = rawget(_G, "AlfaAcomodar")
		if N.CerrarVentana then N.CerrarVentana() end
		if type(Ac) == "table" and type(Ac.Abrir) == "function" then K.Llamar(Ac.Abrir)
		elseif A.RunCommand then K.Llamar(A.RunCommand, "acomodar") end
	end,
	temporada = function()
		if A.RunCommand then K.Llamar(A.RunCommand, "temporada") end
	end,
}

---------------------------------------------------------------------------
-- 1.4.0 (65): «Enséñamelo», el recorrido de lo nuevo. Cierra las notas y,
-- punto por punto (los que tienen su «Ver»), te lleva a donde está y lo
-- cuenta en un aviso con «Siguiente» y «Ya entendí». Nunca en combate.
--   M.RecorridoNotas(nota) -> cuántos pasos tiene (0: ninguno)
--   M.PasoRecorridoNotas() -> el paso de ahora (o nil)
---------------------------------------------------------------------------
local recorrido
function M.PasosDeNota(nota)
	local pasos = {}
	for _, p in ipairs(nota and nota.puntos or {}) do
		if type(p[3]) == "string" and M.IR_NOTA[p[3]] then pasos[#pasos + 1] = p end
	end
	return pasos
end
local function pasoRecorrido(i)
	if not recorrido then return end
	local p = recorrido.pasos[i]
	if not p then recorrido = nil return end
	if InCombatLockdown and InCombatLockdown() then
		if N.FueraDeCombate then N.FueraDeCombate("bienvenida.recorridoNotas", function() pasoRecorrido(i) end) end
		return
	end
	recorrido.i = i
	-- 1.4.0: «Acomodar la pantalla» (un paso de antes) no se queda abierto
	-- encima de los que siguen: su velo y sus recuadros tapaban la tarjeta.
	local Ac = type(M.Acomodar) == "table" and M.Acomodar or rawget(_G, "AlfaAcomodar")
	if type(Ac) == "table" and type(Ac.Activo) == "function" and Ac.Activo() and type(Ac.Cerrar) == "function" then
		K.Llamar(Ac.Cerrar)
	end
	K.Llamar(M.IR_NOTA[p[3]])
	local ultimo = i == #recorrido.pasos
	local acciones = { { texto = ultimo and L["Listo"] or L["Siguiente"], alClic = function()
		if ultimo then recorrido = nil else pasoRecorrido(i + 1) end
	end } }
	if not ultimo then acciones[2] = { texto = L["Ya entendí"], alClic = function() recorrido = nil end } end
	if K.Aviso then
		K.Aviso({ id = "bienvenida.recorridoNotas", pedido = true, lya = false, icono = p[1] or "ic-lobo", tono = "acento",
			titulo = format(L["Lo nuevo de la %s · %d de %d"], recorrido.version, i, #recorrido.pasos),
			texto = p.titulo and (L[p.titulo] .. ": " .. L[p[2]]) or L[p[2]], acciones = acciones, caduca = 600, historial = false, sonido = false })
	end
end
function M.RecorridoNotas(nota)
	if type(nota) ~= "table" then return 0 end
	local pasos = M.PasosDeNota(nota)
	if #pasos == 0 then return 0 end
	recorrido = { pasos = pasos, version = nota.version, i = 0 }
	if M.CerrarNotas then M.CerrarNotas() end
	pasoRecorrido(1)
	return #pasos
end
function M.PasoRecorridoNotas() return recorrido and recorrido.i or nil end

function M.BloquePuntos(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.filas = {}
	function b:Set(nota)
		local puntos = nota and nota.puntos or {}
		for i, p in ipairs(puntos) do
			local fila = self.filas[i]
			if not fila then
				fila = CreateFrame("Frame", nil, self)
				fila.Icono = K.Icono(fila, "ic-exito", ICONO, "acento")
				fila.Icono:SetPoint("TOPLEFT", fila, "TOPLEFT", 0, -1)
				fila.Texto = K.Texto(fila, "texto", "textoSuave")
				fila.Texto:SetPoint("TOPLEFT", fila, "TOPLEFT", ICONO + ESP.m, 0)
				self.filas[i] = fila
			end
			K.SetIcono(fila.Icono, p[1] or "ic-exito", "acento")
			K.Escribir(fila.Texto, L[p[2]])
			local ir = type(p[3]) == "string" and M.IR_NOTA[p[3]] or nil
			if ir and not fila.Ir then
				fila.Ir = K.Boton(fila, L["Ver"], function(boton)
					local fn = boton.alfaIr
					if M.CerrarNotas then M.CerrarNotas() end
					if fn then K.Llamar(fn) end
				end, { tipo = "secundario", tam = "chico" })
				fila.Ir:SetPoint("TOPRIGHT", fila, "TOPRIGHT", 0, 0)
			end
			if fila.Ir then
				fila.Ir.alfaIr = ir
				K.Mostrar(fila.Ir, ir ~= nil)
			end
			fila:Show()
		end
		for i = #puntos + 1, #self.filas do self.filas[i]:Hide() end
		self.n = #puntos
	end
	function b:Acomodar(ancho)
		local y = 0
		for i = 1, self.n or 0 do
			local fila = self.filas[i]
			local conIr = fila.Ir and fila.Ir:IsShown()
			local tw = max(40, ancho - ICONO - ESP.m - (conIr and (K.num(fila.Ir:GetWidth(), 48) + ESP.m) or 0))
			local h = max(ICONO + 2, K.Parrafo(fila.Texto, tw), conIr and K.ALTO.botonChico or 0)
			fila:ClearAllPoints()
			fila:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			fila:SetSize(ancho, h)
			y = y + h + (i < self.n and ESP.m or 0)
		end
		self:SetHeight(max(1, y))
		return y
	end
	return b
end


---------------------------------------------------------------------------
-- 1.4.0 (84): la bienvenida de una versión grande (nota.bienvenida): sus
-- puntos como tarjetas en dos columnas, cada una con su ícono en una ficha,
-- su título, una línea y «Pruébalo» (lleva a donde se prueba y cierra las
-- notas). En una ventana angosta, una columna.
--   M.BloqueTarjetas(padre): b:Set(nota) ; b:Acomodar(ancho) -> alto
---------------------------------------------------------------------------
local FICHA = 36
function M.BloqueTarjetas(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.tarjetas = {}
	function b:Set(nota)
		local puntos = nota and nota.puntos or {}
		for i, p in ipairs(puntos) do
			local t = self.tarjetas[i]
			if not t then
				t = CreateFrame("Frame", nil, self)
				t.Fondo = K.Plano(t, "elevado", "BACKGROUND", 0)
				t.Fondo:SetAllPoints(t)
				t.Linea = K.Plano(t, "acento", "ARTWORK", 1)
				t.Linea:SetWidth(2)
				t.Linea:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
				t.Linea:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 0)
				t.Ficha = K.Plano(t, "fondo", "ARTWORK", 0)
				t.Ficha:SetSize(FICHA, FICHA)
				t.Ficha:SetPoint("TOPLEFT", t, "TOPLEFT", ESP.base, -ESP.base)
				t.Icono = K.Icono(t, "ic-exito", 18, "acento", "OVERLAY")
				t.Icono:SetPoint("CENTER", t.Ficha, "CENTER", 0, 0)
				t.Titulo = K.Texto(t, "subtitulo", "texto")
				t.Texto = K.Texto(t, "nota", "textoSuave")
				t.Ir = K.Boton(t, L["Pruébalo"], function(boton)
					local fn = boton.alfaIr
					if M.CerrarNotas then M.CerrarNotas() end
					if fn then K.Llamar(fn) end
				end, { tipo = "secundario", tam = "chico", icono = "ic-seguir" })
				self.tarjetas[i] = t
			end
			K.SetIcono(t.Icono, p[1] or "ic-exito", "acento")
			K.Escribir(t.Titulo, p.titulo and L[p.titulo] or "")
			K.Escribir(t.Texto, L[p[2]])
			local ir = type(p[3]) == "string" and M.IR_NOTA[p[3]] or nil
			t.Ir.alfaIr = ir
			K.Mostrar(t.Ir, ir ~= nil)
			t:Show()
		end
		for i = #puntos + 1, #self.tarjetas do self.tarjetas[i]:Hide() end
		self.n = #puntos
	end
	function b:Acomodar(ancho)
		local cols = ancho >= 520 and 2 or 1
		local gap = ESP.m
		local w = floor((ancho - (cols - 1) * gap) / cols)
		local y, i = 0, 1
		while i <= (self.n or 0) do
			local alto = 0
			for c = 0, cols - 1 do
				local t = self.tarjetas[i + c]
				if t then
					local x = ESP.base + FICHA + ESP.m
					local tw = max(40, w - x - ESP.base)
					t.Titulo:ClearAllPoints()
					t.Titulo:SetPoint("TOPLEFT", t, "TOPLEFT", x, -ESP.base)
					local h = ESP.base + K.Parrafo(t.Titulo, tw)
					t.Texto:ClearAllPoints()
					t.Texto:SetPoint("TOPLEFT", t, "TOPLEFT", x, -(h + ESP.xs))
					h = h + ESP.xs + K.Parrafo(t.Texto, tw)
					if t.Ir:IsShown() then
						t.Ir:ClearAllPoints()
						t.Ir:SetPoint("TOPLEFT", t, "TOPLEFT", x, -(h + ESP.s))
						h = h + ESP.s + K.ALTO.botonChico
					end
					t.alfaAlto = max(h + ESP.base, ESP.base * 2 + FICHA)
					alto = max(alto, t.alfaAlto)
				end
			end
			for c = 0, cols - 1 do
				local t = self.tarjetas[i + c]
				if t then
					t:ClearAllPoints()
					t:SetPoint("TOPLEFT", self, "TOPLEFT", c * (w + gap), -y)
					t:SetSize(w, alto)
					-- «Pruébalo» abajo de cada tarjeta: los de una fila quedan parejos.
					if t.Ir:IsShown() then
						t.Ir:ClearAllPoints()
						t.Ir:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", ESP.base + FICHA + ESP.m, ESP.base)
					end
				end
			end
			y = y + alto + gap
			i = i + cols
		end
		y = max(1, y - gap)
		self:SetHeight(y)
		return y
	end
	return b
end

---------------------------------------------------------------------------
-- La cabeza: el lobo que aúlla, el nombre de la versión y el saludo.
---------------------------------------------------------------------------
local LOBO = 44

local function cabeza(padre)
	local c = CreateFrame("Frame", nil, padre)
	c.Lobo = c:CreateTexture(nil, "ARTWORK")
	c.Lobo:SetTexture(K.Lobo("aullando"))
	c.Lobo:SetSize(LOBO, LOBO)
	c.Lobo:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	K.Pintar(c.Lobo, function(t) t:SetVertexColor(K.Color("acento")) end)
	c.Sobre = K.Texto(c, "mayus", "acento")
	c.Titulo = K.Texto(c, "titulo", "titulo")
	c.Saludo = K.Texto(c, "texto", "textoSuave")
	function c:Set(sobre, titulo, saludo)
		K.Escribir(self.Sobre, K.Mayus(sobre or ""))
		K.Escribir(self.Titulo, titulo or "")
		K.Escribir(self.Saludo, saludo or "")
	end
	function c:Acomodar(ancho)
		local x = LOBO + ESP.base
		local tw = max(40, ancho - x)
		local y = 0
		self.Sobre:ClearAllPoints()
		self.Sobre:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
		y = y + K.Parrafo(self.Sobre, tw) + ESP.xs
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
		y = y + K.Parrafo(self.Titulo, tw) + ESP.s
		self.Saludo:ClearAllPoints()
		self.Saludo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
		y = y + K.Parrafo(self.Saludo, tw)
		y = max(y, LOBO)
		self:SetHeight(y)
		return y
	end
	return c
end

-- Una nota tenue que baja de renglón (vacía no ocupa lugar).
local function nota(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Texto = K.Texto(b, "nota", "textoTenue")
	b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	function b:Set(t)
		K.Escribir(self.Texto, t or "")
		K.Mostrar(self, (t or "") ~= "")
	end
	function b:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, ancho)
		self:SetHeight(h)
		return h
	end
	return b
end

-- Una línea de 1 px como bloque de una pila.
local function separador(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Linea = K.Linea(b, "linea")
	b.Linea:SetPoint("LEFT", b, "LEFT", 0, 0)
	b.Linea:SetPoint("RIGHT", b, "RIGHT", 0, 0)
	function b:Acomodar() self:SetHeight(1) return 1 end
	return b
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local v
local ui = {}

local function anchoUtil() return v:AnchoCuerpo() - 8 end -- deja lugar a la barra si hace falta

-- Mide el contenido y ajusta el alto de la ventana (sin pasar de la pantalla).
local function acomodar()
	if not (v and v:IsShown()) or ui.midiendo then return end
	ui.midiendo = true
	local ancho = anchoUtil()
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -ESP.l)
	local h = ui.pila:Acomodar(ancho) + ESP.l * 2
	v:SetAltoContenido(h)
	local tope = K.num(UIParent:GetHeight(), 768) - 2 * ESP.xxl
	local alto = floor(min(tope, CABECERA + h + PIE + 4) + 0.5)
	local anchoV = ui.ancho or ANCHO
	if math.abs(K.num(v:GetHeight(), 0) - alto) > 1 or math.abs(K.num(v:GetWidth(), 0) - anchoV) > 1 then v:SetTamano(anchoV, alto) end
	ui.midiendo = false
end

local function cerrar() if v then v:Cerrar() end end

local function armar()
	v = K.Ventana({
		nombre = "AlfaNotasVersion", titulo = "", icono = "ic-lobo",
		ancho = ANCHO, alto = 420, desplazar = true,
		alCerrar = function()
			if not ui.porCombate then ui.reabrir = nil end
		end,
	})
	v.alAcomodar = acomodar
	ui.pila = K.Pila(v.Cuerpo, { espacio = ESP.base })
	ui.cabeza = ui.pila:Agregar(cabeza(ui.pila))
	ui.pila:Agregar(separador(ui.pila), { espacio = ESP.l })
	ui.puntos = ui.pila:Agregar(M.BloquePuntos(ui.pila), { espacio = ESP.l })
	ui.tarjetas = ui.pila:Agregar(M.BloqueTarjetas(ui.pila), { espacio = ESP.l })
	ui.otras = ui.pila:Agregar(nota(ui.pila), { espacio = ESP.l })
	ui.seguir = K.Boton(v, L["Seguir jugando"], cerrar, { tipo = "primario", icono = "ic-seguir" })
	ui.todo = K.Boton(v, L["Ver todo lo nuevo"], function()
		cerrar()
		M.Abrir("pedido", "portada")
	end, { tipo = "secundario" })
	-- 1.4.0 (65): «Enséñamelo», el recorrido de lo nuevo, a la izquierda.
	ui.recorrido = K.Boton(v, L["Enséñamelo"], function() M.RecorridoNotas(ui.nota) end, { tipo = "fantasma", icono = "ic-seguir" })
	v:SetPie({ ui.todo, ui.seguir }, { ui.recorrido })
	-- Un cambio de estilo cambia la letra y las medidas: se mide de nuevo.
	K.AlRepintar(function() if v:IsShown() then acomodar() K.Despues(0.05, acomodar) end end)

	-- En combate se esconde; vuelve sola al terminar la pelea.
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:SetScript("OnEvent", function(_, evento)
		if evento == "PLAYER_REGEN_DISABLED" then
			if v:IsShown() then
				ui.reabrir = true
				ui.porCombate = true
				v:Cerrar()
				ui.porCombate = nil
			end
		elseif ui.reabrir then
			ui.reabrir = nil
			K.Despues(1, function() if not v:IsShown() then M.AbrirNotas(ui.nota) end end)
		end
	end)
end

-- Las versiones con notas entre la que viste y la que se muestra ("1.1.2, 1.1.3").
local function intermedias(n)
	local vista = M.VersionVista and M.VersionVista()
	if not vista then return nil end
	local lista = {}
	for i = #M.NOTAS, 1, -1 do
		local x = M.NOTAS[i]
		if M.CompararVersion(x.version, vista) > 0 and M.CompararVersion(x.version, n.version) < 0 then
			lista[#lista + 1] = x.version
		end
	end
	return #lista > 0 and table.concat(lista, ", ") or nil
end

function M.NotasVisibles() return v ~= nil and v:IsShown() end
function M.CerrarNotas() if v and v:IsShown() then v:Cerrar() end end

function M.AbrirNotas(n)
	if not n then
		-- las de tu versión o, si no tiene, las más nuevas que no pasen de ella
		for _, x in ipairs(M.NOTAS) do
			if M.CompararVersion(x.version, M.VERSION_ALFA) <= 0 then n = x break end
		end
		n = n or M.NOTAS[#M.NOTAS]
	end
	if not n then return false end
	if not v then armar() end
	local otras = intermedias(n)
	if M.MarcarNotasVistas then M.MarcarNotasVistas() end
	-- 1.3.3: vistas: fuera de lo guardado al entrar y sin su punto en «Lo nuevo».
	if N.OlvidarAlEntrar then N.OlvidarAlEntrar("bienvenida.novedades") end
	local O = A.UI and A.UI.Options
	if O and O.RefreshNav then pcall(O.RefreshNav) end
	ui.nota = n
	v:SetTitulo(format(L["Lo nuevo en Alfa %s"], n.version), nil, "ic-lobo")
	-- 1.4.0 (84): una versión grande trae su bienvenida, más ancha y en tarjetas.
	local grande = n.bienvenida and true or false
	ui.ancho = grande and ANCHO_BIENVENIDA or ANCHO
	ui.cabeza:Set(grande and format(L["Bienvenido a Alfa %s"], n.version) or format(L["Versión %s"], n.version), L[n.titulo],
		grande and L["Alfa cambió por fuera y por dentro. Prueba cada novedad con un clic, o deja que te las enseñe una por una."]
		or L["¡Qué gusto verte de vuelta! Esto es lo que trae esta versión para ti y tu manada."])
	ui.puntos:Set(n)
	ui.tarjetas:Set(n)
	K.Mostrar(ui.puntos, not grande)
	K.Mostrar(ui.tarjetas, grande)
	K.Mostrar(ui.recorrido, #M.PasosDeNota(n) >= 2)
	ui.otras:Set(otras and format(L["Desde tu última visita también hubo cambios en %s: los ves en «Ver todo lo nuevo»."], otras) or nil)
	v:Abrir()
	-- Siempre en el centro, aunque la hayas movido antes.
	v:ClearAllPoints()
	v:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	if v.Desplazable then v.Desplazable:IrArriba() end
	acomodar()
	K.Despues(0.05, acomodar)
	K.Despues(0.3, acomodar)
	return true
end
