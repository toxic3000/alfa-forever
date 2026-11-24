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
}

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
	if math.abs(K.num(v:GetHeight(), 0) - alto) > 1 then v:SetTamano(ANCHO, alto) end
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
	ui.otras = ui.pila:Agregar(nota(ui.pila), { espacio = ESP.l })
	ui.seguir = K.Boton(v, L["Seguir jugando"], cerrar, { tipo = "primario", icono = "ic-seguir" })
	ui.todo = K.Boton(v, L["Ver todo lo nuevo"], function()
		cerrar()
		M.Abrir("pedido", "portada")
	end, { tipo = "secundario" })
	v:SetPie({ ui.todo, ui.seguir })
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
	ui.cabeza:Set(format(L["Versión %s"], n.version), L[n.titulo],
		L["¡Qué gusto verte de vuelta! Esto es lo que trae esta versión para ti y tu manada."])
	ui.puntos:Set(n)
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
