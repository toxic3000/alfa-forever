-- Alfa - Pesca: la ventana de antes de pescar (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.8, lo pidió Toxic: al abrir el modo pesca, un cuadro compacto con
--   * qué caña usar, si tienes varias (ícono, nombre y su bonificación);
--   * qué cebo (los que tienes, con su bonificación y cuántos);
--   * cómo quieres la barra: «Como la tienes ahora» de fábrica; sin eso,
--     horizontal, vertical o mínima y qué botones se ven;
--   * el botón grande «A pescar» y «No volver a preguntar» (se vuelve a abrir
--     con el clic derecho de la barra, «Antes de pescar», o desde Ajustes).
-- Lo que eliges se guarda al momento y por personaje (Equipo.lua: Eq.Eleccion),
-- así tu tecla ya pesca con eso aunque cierres el cuadro sin tocar «A pescar».
-- Si solo tienes una caña y ningún cebo, no pregunta. Nunca en combate: al
-- empezar una pelea el cuadro se cierra.
-- «A pescar» es tu clic: te pone la caña elegida (C_Item.EquipItemByName,
-- fuera de combate, como el menú de equipo de la barra). El cebo lo pone tu
-- tecla, como siempre.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local Eq = M.Eq

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring
local ESP = K.ESP
local DOT = " \194\183 "

local Pv = {}
M.Previa = Pv

local ANCHO = 440

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function eleccion() return Eq.Eleccion() end

-- Los botones de la barra que se pueden esconder (el de «A pelear» y cerrar, nunca).
Pv.BOTONES = {
	{ id = "equipo", icono = "ic-personaje", nombre = L["Equipo de pesca"] },
	{ id = "cebo", icono = "cebo", nombre = L["Cebos"] },
	{ id = "cocina", icono = "fogata", nombre = L["Cocina junto al agua"] },
	{ id = "juguetes", icono = "ic-bolsas", nombre = L["Juguetes y consumibles de pesca"] },
	{ id = "metas", icono = "meta", nombre = L["Metas de pesca"] },
	{ id = "diario", icono = "diario", nombre = L["Diario de pesca"] },
	{ id = "ajustes", icono = "ic-ajustes", nombre = L["Ajustes de pesca"] },
}

---------------------------------------------------------------------------
-- La barra elegida (Barra.lua la lee con M.Previa.Barra)
---------------------------------------------------------------------------
local function barraPropia()
	local b = eleccion().barra
	if type(b) == "table" and b.propia then return b end
	return nil
end

-- k: "barraVertical" | "barraPlegar" | "vistaMinima" | "minima" -> valor | nil (el ajuste de siempre)
function Pv.Barra(k)
	local b = barraPropia()
	if not b then return nil end
	local vista = b.vista or "horizontal"
	if k == "barraVertical" then return vista == "vertical" end
	if k == "minima" then return vista == "minima" end
	if (k == "vistaMinima" or k == "barraPlegar") and vista == "minima" then return true end
	return nil
end

function Pv.Ocultos()
	local b = barraPropia()
	return b and type(b.ocultos) == "table" and b.ocultos or {}
end

-- El «Barra vertical / horizontal» del clic derecho, con la barra elegida. -> true si la cambió
function Pv.AlternarVertical()
	local b = barraPropia()
	if not b then return false end
	b.vista = (b.vista == "vertical") and "horizontal" or "vertical"
	M.Avisar("ajustes")
	return true
end

---------------------------------------------------------------------------
-- Lo que hay para elegir
---------------------------------------------------------------------------
-- Tus cañas: la puesta y las de tus bolsas, sin repetir. -> { { id, enlace, nombre, icono, bono, puesta, usable } }
function Pv.Canas()
	local out, visto = {}, {}
	local tiene, id, enlace = Eq.CanaPuesta()
	if tiene and id then
		visto[id] = true
		out[#out + 1] = { id = id, enlace = enlace, nombre = Eq.Nombre(id, enlace), icono = Eq.Icono(id), bono = (Eq.BonoPuesto(16)), puesta = true, usable = true }
	end
	for _, c in ipairs(Eq.Inventario().canas) do
		if not visto[c.id] then
			visto[c.id] = true
			out[#out + 1] = { id = c.id, enlace = c.enlace, nombre = Eq.Nombre(c.id, c.enlace), icono = Eq.Icono(c.id), bono = c.bono, usable = c.usable }
		end
	end
	table.sort(out, function(a, b)
		if (a.bono or 0) ~= (b.bono or 0) then return (a.bono or 0) > (b.bono or 0) end
		return tostring(a.nombre or "") < tostring(b.nombre or "")
	end)
	return out
end

function Pv.Cebos()
	local out = {}
	for _, c in ipairs(Eq.Cebos()) do if (c.cuenta or 0) > 0 then out[#out + 1] = c end end
	return out
end

-- ¿Hace falta preguntar? Con una sola caña y ningún cebo, no.
function Pv.HayQueElegir()
	return #Pv.Canas() > 1 or #Pv.Cebos() > 0
end

function Pv.Preguntar()
	return M.Opt("previa") and not eleccion().noPreguntar and true or false
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local v, ui

local function guardar()
	Eq.Marcar()
	if M.PrepararBotones then M.PrepararBotones() end
	M.Avisar("ajustes")
end

local function tarjetaCana(c, elegida)
	local partes = {}
	partes[#partes + 1] = (c.bono or 0) > 0 and format(L["+%d de pesca"], c.bono) or L["sin bonificación"]
	if c.puesta then partes[#partes + 1] = L["puesta"] end
	if not c.usable then partes[#partes + 1] = L["todavía no la puedes usar"] end
	return { variante = "compacta", icono = c.icono or "ic-pesca", tenir = c.icono == nil, titulo = c.nombre or "?",
		texto = table.concat(partes, DOT), elegida = elegida, tono = elegida and "acento" or "neutro",
		alClic = c.usable and function() eleccion().cana = c.id guardar() Pv.Pintar() end or nil }
end

local function tarjetaCebo(c, elegida)
	local texto = format(L["+%d · ×%d"], c.bono or 0, c.cuenta or 0)
	if not c.puede and c.motivo then texto = texto .. DOT .. c.motivo end
	return { variante = "compacta", icono = c.icono or M.ICONO.cebo, tenir = c.icono == nil, titulo = c.nombre or "?",
		texto = texto, elegida = elegida, tono = elegida and "acento" or "neutro",
		alClic = function() eleccion().cebo = c.id guardar() Pv.Pintar() end }
end

local function crear()
	v = K.Ventana({ nombre = "AlfaPescaPrevia", titulo = L["Antes de pescar"], subtitulo = L["Elige con qué pescar: tu tecla hace lo demás."],
		icono = "ic-pesca", ancho = ANCHO, alto = 420 })
	ui = {}
	local pila = K.Pila(v.Cuerpo, { espacio = ESP.s })
	ui.pila = pila
	ui.secCana = pila:Agregar(K.Seccion(pila, L["Tu caña"]))
	ui.canas = pila:Agregar(K.Rejilla(pila, { min = 300, gap = ESP.xs, variante = "compacta" }))
	ui.secCebo = pila:Agregar(K.Seccion(pila, L["Tu cebo"]), { espacio = ESP.m })
	ui.cebos = pila:Agregar(K.Rejilla(pila, { min = 300, gap = ESP.xs, variante = "compacta" }))
	ui.secBarra = pila:Agregar(K.Seccion(pila, L["La barra de pesca"]), { espacio = ESP.m })
	-- «Como la tienes ahora»: el interruptor y su texto.
	local fila = CreateFrame("Frame", nil, pila)
	fila.Interruptor = K.Interruptor(fila, {
		get = function() return not barraPropia() end,
		set = function(si)
			local e = eleccion()
			if si then
				if type(e.barra) == "table" then e.barra.propia = nil end
			else
				e.barra = type(e.barra) == "table" and e.barra or {}
				e.barra.propia = true
				e.barra.vista = e.barra.vista or (N.Get(ID, "barraVertical") and "vertical" or "horizontal")
				e.barra.ocultos = type(e.barra.ocultos) == "table" and e.barra.ocultos or {}
			end
			M.Avisar("ajustes")
			Pv.Pintar()
		end,
	})
	fila.Texto = K.Texto(fila, "cuerpo", "texto")
	K.Escribir(fila.Texto, L["Como la tienes ahora"])
	fila.Nota = K.Texto(fila, "nota", "textoTenue")
	function fila:Acomodar(ancho)
		self.Interruptor:ClearAllPoints()
		self.Interruptor:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -2)
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 36 + ESP.m, -1)
		K.Ajustar(self.Texto, ancho - 36 - ESP.m)
		self.Nota:ClearAllPoints()
		self.Nota:SetPoint("TOPLEFT", self.Texto, "BOTTOMLEFT", 0, -2)
		local h = 18 + K.Parrafo(self.Nota, ancho - 36 - ESP.m, 2)
		self:SetSize(ancho, h)
		return h
	end
	ui.comoAhora = pila:Agregar(fila)
	-- La vista: horizontal, vertical o mínima.
	ui.vista = pila:Agregar(K.Segmentos(pila, { estilo = "pildoras", opciones = {
		{ valor = "horizontal", texto = L["Horizontal"] },
		{ valor = "vertical", texto = L["Vertical"] },
		{ valor = "minima", texto = L["Mínima"] },
	}, alCambiar = function(vista)
		local b = barraPropia()
		if b then b.vista = vista end
		M.Avisar("ajustes")
		Pv.Pintar()
	end }), { sangria = 36 + ESP.m })
	-- Los botones que se ven.
	local bots = CreateFrame("Frame", nil, pila)
	bots.Texto = K.Texto(bots, "nota", "textoSuave")
	K.Escribir(bots.Texto, L["Botones de la barra (clic para verlos o esconderlos):"])
	bots.botones = {}
	for i, d in ipairs(Pv.BOTONES) do
		local icono = M.ICONO[d.icono] or d.icono
		local b = K.BotonIcono(bots, icono, function()
			local p = barraPropia()
			if not p then return end
			p.ocultos = type(p.ocultos) == "table" and p.ocultos or {}
			p.ocultos[d.id] = (not p.ocultos[d.id]) and true or nil
			M.Avisar("ajustes")
			Pv.Pintar()
		end, { tam = 28, icono = 15, tipo = "secundario", ayuda = d.nombre })
		b.alfaId = d.id
		bots.botones[i] = b
	end
	function bots:Acomodar(ancho)
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		local h = K.Parrafo(self.Texto, ancho, 2) + ESP.xs
		for i, b in ipairs(self.botones) do
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * (28 + ESP.xs), -h)
		end
		h = h + 28
		self:SetSize(ancho, h)
		return h
	end
	ui.botones = pila:Agregar(bots, { sangria = 36 + ESP.m })
	-- El pie: «No volver a preguntar» a la izquierda y «A pescar», grande, a la derecha.
	local np = CreateFrame("Frame", nil, v)
	np.Interruptor = K.Interruptor(np, {
		get = function() return eleccion().noPreguntar and true or false end,
		set = function(si) eleccion().noPreguntar = si and true or nil end,
	})
	np.Interruptor:SetPoint("LEFT", np, "LEFT", 0, 0)
	np.Texto = K.Texto(np, "pequeno", "textoSuave")
	np.Texto:SetPoint("LEFT", np.Interruptor, "RIGHT", ESP.s, 0)
	K.Escribir(np.Texto, L["No volver a preguntar"])
	np:SetHeight(24)
	ui.noPreguntar = np
	ui.aPescar = K.Boton(v, L["A pescar"], function() Pv.APescar() end, { tipo = "primario", tam = "grande", icono = "ic-pesca" })
	v.alAcomodar = function() Pv.Acomodar() end
	M.VISIBLES[#M.VISIBLES + 1] = v
	return v
end

function Pv.Acomodar()
	if not (v and ui) then return end
	local ancho = ANCHO - 2 * v.margen
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -ESP.base)
	local h = ui.pila:Acomodar(ancho)
	local np = ui.noPreguntar
	np:SetWidth(36 + ESP.s + K.Ajustar(np.Texto, 200) + 2)
	return h
end

-- Pinta lo elegido y mide la ventana.
function Pv.Pintar()
	if not (v and ui) then return end
	local e = eleccion()
	local canas = Pv.Canas()
	local elegida = tonumber(e.cana)
	local hay = false
	for _, c in ipairs(canas) do if c.id == elegida then hay = true end end
	local datos = {}
	datos[1] = { variante = "compacta", icono = "ic-exito", titulo = L["La mejor que tengas"], texto = L["Alfa elige la de más bonificación."],
		elegida = not hay, tono = not hay and "acento" or "neutro", alClic = function() eleccion().cana = nil guardar() Pv.Pintar() end }
	for _, c in ipairs(canas) do datos[#datos + 1] = tarjetaCana(c, hay and c.id == elegida) end
	ui.canas:Llenar(datos)
	local conCanas = #canas > 1
	K.Mostrar(ui.secCana, conCanas)
	K.Mostrar(ui.canas, conCanas)
	local cebos = Pv.Cebos()
	local pref = Eq.CeboElegido()
	local hayCebo = false
	for _, c in ipairs(cebos) do if c.id == pref then hayCebo = true end end
	datos = {}
	datos[1] = { variante = "compacta", icono = "ic-exito", titulo = L["El mejor que tengas"], texto = L["Alfa pone el de más bonificación que puedas usar."],
		elegida = not hayCebo, tono = not hayCebo and "acento" or "neutro", alClic = function() eleccion().cebo = 0 guardar() Pv.Pintar() end }
	for _, c in ipairs(cebos) do datos[#datos + 1] = tarjetaCebo(c, hayCebo and c.id == pref) end
	ui.cebos:Llenar(datos)
	K.Mostrar(ui.secCebo, #cebos > 0)
	K.Mostrar(ui.cebos, #cebos > 0)
	-- La barra.
	local propia = barraPropia()
	ui.comoAhora.Interruptor:SetValor(not propia)
	local vert = N.Get(ID, "barraVertical") and L["vertical"] or L["horizontal"]
	K.Escribir(ui.comoAhora.Nota, propia and L["Elige cómo la quieres al pescar con este personaje."] or format(L["Ahora: %s, con todos sus botones."], vert))
	ui.vista:SetValor(propia and (propia.vista or "horizontal") or nil)
	K.Mostrar(ui.vista, propia ~= nil)
	K.Mostrar(ui.botones, propia ~= nil)
	local ocultos = Pv.Ocultos()
	-- Lo que se ve, encendido; lo escondido, apagado.
	for _, b in ipairs(ui.botones.botones) do
		b:SetMarcado(not ocultos[b.alfaId])
		b:SetAlpha(ocultos[b.alfaId] and 0.4 or 1)
	end
	ui.noPreguntar.Interruptor:SetValor(e.noPreguntar and true or false)
	-- El alto: lo que mide el contenido, la cabecera y el pie.
	local h = Pv.Acomodar() or 0
	v:SetPie({ ui.aPescar }, { ui.noPreguntar })
	v:SetTamano(ANCHO, K.ALTO.cabecera + ESP.base + h + ESP.l + K.ALTO.pie)
end

-- «A pescar»: tu clic te pone la caña elegida (fuera de combate) y cierra.
function Pv.APescar()
	if v then v:Cerrar() end
	if enCombate() then return end
	local elegida = Eq.CanaElegida()
	local _, puesta = Eq.CanaPuesta()
	if elegida and puesta ~= elegida then
		for _, c in ipairs(Eq.Inventario().canas) do
			if c.id == elegida and c.usable then
				local f = (C_Item and C_Item.EquipItemByName) or EquipItemByName
				if type(f) == "function" then pcall(f, c.enlace, 16) end
				break
			end
		end
	end
	guardar()
end

-- forzar: abrirla aunque pediste no verla (la barra, Ajustes, /alfa pesca antes).
function Pv.Abrir(forzar)
	if enCombate() then return false end
	if N.Permitido and not N.Permitido() then return false end
	if not forzar and not (Pv.Preguntar() and Pv.HayQueElegir()) then return false end
	v = v or crear()
	v:Abrir()
	Pv.Pintar()
	return true
end

function Pv.Cerrar() if v and v:IsShown() then v:Cerrar() end end
function Pv.Visible() return v ~= nil and v:IsShown() end
function Pv.Ventana() return v end
function Pv.UI() return ui end -- (para las pruebas)

-- Al abrir el modo pesca (Pesca.lua: M.AbrirModo), un instante después.
function Pv.AlAbrirModo()
	if not Pv.Preguntar() or enCombate() then return end
	A.After(0.2, function()
		if M.Modo() and not enCombate() then Pv.Abrir() end
	end)
end

-- Al empezar una pelea, el cuadro se va (nada en combate).
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() Pv.Cerrar() end)

M.Escuchar(function(m)
	if not Pv.Visible() then return end
	if m.equipo or m.todo then Pv.Pintar() end
	if m.modo and not M.Modo() then Pv.Cerrar() end
end)
