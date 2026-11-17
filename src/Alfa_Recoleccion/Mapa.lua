-- Alfa - Recolección: los nodos y la ruta en el mapa del mundo
-- (toxic3000 / La Jauría, GPL-3.0).
--
-- Va sobre la vista que el motor comparte con todos (Alfa.MapCanvas), con
-- sus mismas reglas para no contaminar el mapa del juego (Nav/MapCanvas.lua
-- y Nav/Pins.lua): marcos propios bajo view.frame, ningún método del mapa
-- que escriba, ningún OnMouseDown/OnMouseUp (el clic se lee con
-- GLOBAL_MOUSE_DOWN/UP sobre el pin bajo el ratón) y el botón derecho pasa
-- al mapa.
--
-- Trabajo por cuadro acotado:
--   * solo la zona que muestra el mapa, y de ella lo que se ve más media
--     pantalla alrededor (se recalcula al salir de esa ventana);
--   * los nodos que en pantalla se pisarían se juntan en un pin con su
--     cantidad (se rehace al hacer zoom), como mucho MAX_PINES pines;
--   * los pines se reutilizan y se crean o pintan unos cuantos por cuadro.

local _, M = ...
local N = AlfaNucleo
local A = N.A
local R, P = M.R, M.P
local L = N.Textos(M.EN)

local floor, max, min = math.floor, math.max, math.min
local ID = R.ID

local Mapa = {}
M.Mapa = Mapa

local NIVEL_PIN, NIVEL_RUTA = "PIN_FRAME_LEVEL_DIG_SITE", "PIN_FRAME_LEVEL_QUEST_BLOB"
local TAM = 16               -- unidades de un pin a escala 1
local MAX_PINES = 450
local CREAR_POR_CUADRO = 50
local PINTAR_POR_CUADRO = 220
local REVISAR_VISTA = 0.25   -- segundos entre lecturas de lo que muestra el mapa

local vista
local pines = {}             -- marcos, en orden de uso
local usados = 0
-- La lista a pintar: pin k en (lx[k], ly[k]) con el grupo lg[k], lc[k] nodos,
-- el nodo li[k] (uno solo) o la celda lk[k] (un grupo).
local lx, ly, lg, lc, li, lk, ltenue = {}, {}, {}, {}, {}, {}, {}
local ln = 0
local listaIdx                -- el índice de la zona de la lista
local celdaX, celdaY = 1, 1   -- tamaño de la celda de agrupado (0..1 del mapa)
local ventana = { 0, 0, 1, 1 }
local sucio, pintado = false, 0
local reloj = 0

local function activo() return N.Get(ID, "mapa") ~= false end

---------------------------------------------------------------------------
-- Lo que muestra el mapa (solo lecturas), en 0..1 del mapa visto.
---------------------------------------------------------------------------
local function rectoVisible()
	local v = vista
	local canvas = v.canvas
	local marco = canvas.GetParent and canvas:GetParent()
	local w, h = v.width or 0, v.height or 0
	if not marco or w <= 0 or h <= 0 then return 0, 0, 1, 1 end
	local cl, ct, cs = canvas:GetLeft(), canvas:GetTop(), canvas:GetEffectiveScale()
	local fl, ft, fr, fb, fs = marco:GetLeft(), marco:GetTop(), marco:GetRight(), marco:GetBottom(), marco:GetEffectiveScale()
	if not (cl and ct and fl and ft and fr and fb and cs and fs and cs > 0) or fr <= fl or ft <= fb then return 0, 0, 1, 1 end
	local kx, ky = 1 / (w * cs), 1 / (h * cs)
	return (fl * fs - cl * cs) * kx, (ct * cs - ft * fs) * ky, (fr * fs - cl * cs) * kx, (ct * cs - fb * fs) * ky
end

local function escala()
	local tam = tonumber(N.Get(ID, "tamanoMapa")) or 1
	return vista:PinScale(0.8, 1.05) * tam
end

---------------------------------------------------------------------------
-- Pines (marcos sin clic propio; ver la cabecera)
---------------------------------------------------------------------------
local raton, presionado, botonPresionado
local pasarPendiente = false

local function pasarDerecho(f)
	if InCombatLockdown and InCombatLockdown() then
		pasarPendiente = true
		return
	end
	if f.SetPassThroughButtons then pcall(f.SetPassThroughButtons, f, "RightButton") end
	f.psPasa = true
end

local function miembros(k)
	local idx = listaIdx
	if not idx then return nil end
	if li[k] then return { li[k] } end
	local clave = lk[k]
	local out = {}
	local gx0, gy0 = floor(clave / 65536), clave % 65536
	local x0, y0 = gx0 * celdaX, gy0 * celdaY
	local x1, y1 = x0 + celdaX, y0 + celdaY
	for cx = R.CeldaDe(x0), R.CeldaDe(x1) do
		for cy = R.CeldaDe(y0), R.CeldaDe(y1) do
			local lista = idx.celdas[cx * R.CELDAS + cy]
			if lista then
				for _, i in ipairs(lista) do
					if R.Muestra(idx, i) and floor(idx.x[i] / celdaX) == gx0 and floor(idx.y[i] / celdaY) == gy0 then
						out[#out + 1] = i
					end
				end
			end
		end
	end
	return out
end

local function alEntrar(self)
	raton = self
	local k = self.psK
	if not (k and listaIdx) then return end
	local pista = not A.GamepadUI() and L["Clic: la flecha te lleva aquí."] or nil
	if li[k] then
		P.Info(self, listaIdx, li[k], pista)
	else
		P.InfoGrupo(self, listaIdx, miembros(k), pista)
	end
end

local function alSalir(self)
	if raton == self then raton = nil end
	if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end

local function pin(k)
	local f = pines[k]
	if f then return f end
	f = A.CreateFrameUnder("Frame", nil, vista.frame)
	P.Construir(f)
	f:EnableMouse(true)
	f:SetScript("OnEnter", alEntrar)
	f:SetScript("OnLeave", alSalir)
	pasarDerecho(f)
	pines[k] = f
	return f
end

A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if not pasarPendiente then return end
	pasarPendiente = false
	for _, f in ipairs(pines) do
		if not f.psPasa then pasarDerecho(f) end
	end
end)

-- El clic izquierdo sobre un pin: la flecha del motor va a ese punto.
A.RegisterEvent("GLOBAL_MOUSE_DOWN", function(_, boton)
	if boton == "RightButton" then return end
	presionado, botonPresionado = raton, boton
end)
A.RegisterEvent("GLOBAL_MOUSE_UP", function(_, boton)
	local f = presionado
	presionado = nil
	if not (f and f == raton and boton == botonPresionado and boton == "LeftButton" and f:IsVisible()) then return end
	local k = f.psK
	if not (k and listaIdx and vista) then return end
	local nombre = R.Nombre(lg[k])
	if lc[k] and lc[k] > 1 then nombre = L["%s y %d más"]:format(nombre, lc[k] - 1) end
	if M.Ruta and M.Ruta.LlevarA then M.Ruta.LlevarA(listaIdx.mapa, lx[k], ly[k], nombre) end
end)

local function colocar(f, x, y, s)
	f:SetScale(s)
	f:ClearAllPoints()
	f:SetPoint("CENTER", vista.canvas, "TOPLEFT", vista.width * x / s, -vista.height * y / s)
end

local function ocultarDesde(k)
	for j = k, usados do
		local f = pines[j]
		if f then
			f:Hide()
			f.psK = nil
		end
	end
	if k <= usados then usados = k - 1 end
end

---------------------------------------------------------------------------
-- Calcular la lista (sin tocar marcos)
---------------------------------------------------------------------------
local cuentas, sumaX, sumaY, primero = {}, {}, {}, {}

local function calcular()
	ln = 0
	listaIdx = nil
	local v = vista
	if not (v and v.shown and activo()) or A.Hidden() then return end
	local idx = R.IndiceSiHay(v.mapID)
	if not idx then return end
	listaIdx = idx
	local x0, y0, x1, y1 = rectoVisible()
	local mx, my = (x1 - x0) * 0.5, (y1 - y0) * 0.5
	ventana[1], ventana[2], ventana[3], ventana[4] = x0 - mx, y0 - my, x1 + mx, y1 + my
	local s = escala()
	local agrupar = N.Get(ID, "agrupar") ~= false
	-- Dos pines se pisan si sus centros están a menos de un pin en pantalla.
	celdaX = max(1e-4, TAM * s * 0.85 / max(1, v.width))
	celdaY = max(1e-4, TAM * s * 0.85 / max(1, v.height))
	if not agrupar then celdaX, celdaY = 1e-4, 1e-4 end
	for k in pairs(cuentas) do cuentas[k] = nil end
	local wx0, wy0, wx1, wy1 = ventana[1], ventana[2], ventana[3], ventana[4]
	local orden = 0
	for cx = R.CeldaDe(wx0), R.CeldaDe(wx1) do
		for cy = R.CeldaDe(wy0), R.CeldaDe(wy1) do
			local lista = idx.celdas[cx * R.CELDAS + cy]
			if lista then
				for _, i in ipairs(lista) do
					local x, y = idx.x[i], idx.y[i]
					if x >= wx0 and x <= wx1 and y >= wy0 and y <= wy1 and R.Muestra(idx, i) then
						local clave = floor(x / celdaX) * 65536 + floor(y / celdaY)
						local c = cuentas[clave]
						if not c then
							orden = orden + 1
							cuentas[clave] = 1
							sumaX[clave], sumaY[clave], primero[clave] = x, y, i
						else
							cuentas[clave] = c + 1
							sumaX[clave], sumaY[clave] = sumaX[clave] + x, sumaY[clave] + y
						end
					end
				end
			end
		end
	end
	for clave, c in pairs(cuentas) do
		if ln >= MAX_PINES then break end
		ln = ln + 1
		local i = primero[clave]
		lx[ln], ly[ln], lc[ln], lg[ln] = sumaX[clave] / c, sumaY[clave] / c, c, idx.g[i]
		li[ln] = c == 1 and i or nil
		lk[ln] = clave
		ltenue[ln] = not R.Puede(idx.g[i])
	end
	for k = ln + 1, #lx do lx[k], ly[k], lg[k], lc[k], li[k], lk[k], ltenue[k] = nil, nil, nil, nil, nil, nil, nil end
	for k in pairs(sumaX) do
		if not cuentas[k] then sumaX[k], sumaY[k], primero[k] = nil, nil, nil end
	end
end

---------------------------------------------------------------------------
-- Pintar unos cuantos por cuadro
---------------------------------------------------------------------------
local function pintar()
	local s = escala()
	local nivel = vista:Level(NIVEL_PIN)
	local creados, hechos = 0, 0
	local k = pintado + 1
	while k <= ln do
		local f = pines[k]
		if not f then
			if creados >= CREAR_POR_CUADRO then break end
			f = pin(k)
			creados = creados + 1
		end
		f.psK = k
		P.Aplicar(f, lg[k], TAM, ltenue[k], lc[k])
		f:SetFrameLevel(nivel)
		colocar(f, lx[k], ly[k], s)
		f:Show()
		if k > usados then usados = k end
		pintado = k
		hechos = hechos + 1
		k = k + 1
		if hechos >= PINTAR_POR_CUADRO then break end
	end
	if pintado >= ln then
		ocultarDesde(ln + 1)
		return true
	end
	return false
end

local function reescalar()
	local s = escala()
	for k = 1, min(pintado, ln) do
		local f = pines[k]
		if f and f:IsShown() then colocar(f, lx[k], ly[k], s) end
	end
end

---------------------------------------------------------------------------
-- La ruta de farmeo: líneas bajo los pines, en unidades del lienzo.
---------------------------------------------------------------------------
local marcoRuta, lineas, bordes = nil, {}, {}
local lineasUsadas = 0

local function ocultarRuta()
	for j = 1, lineasUsadas do
		lineas[j]:Hide()
		bordes[j]:Hide()
	end
	lineasUsadas = 0
end

function Mapa.DibujarRuta()
	if not (vista and vista.shown) then return end
	local ruta = M.Ruta and M.Ruta.Actual()
	if not (ruta and ruta.n and ruta.n >= 2 and ruta.mapa == vista.mapID) or A.Hidden() then return ocultarRuta() end
	if not marcoRuta then
		marcoRuta = A.CreateFrameUnder("Frame", nil, vista.frame)
		marcoRuta:SetAllPoints(vista.canvas)
	end
	marcoRuta:SetFrameLevel(vista:Level(NIVEL_RUTA))
	marcoRuta:Show()
	local w, h, s = vista.width, vista.height, vista.scale or 1
	local r, g, b = A.Theme.Accent()
	local sr, sg, sb = A.Theme.Color("scrim")
	local n = ruta.n
	for j = 1, n do
		local k2 = j % n + 1
		local linea, borde = lineas[j], bordes[j]
		if not linea then
			borde = marcoRuta:CreateLine(nil, "ARTWORK", nil, -1)
			linea = marcoRuta:CreateLine(nil, "ARTWORK", nil, 1)
			borde:SetColorTexture(1, 1, 1, 1)
			linea:SetColorTexture(1, 1, 1, 1)
			lineas[j], bordes[j] = linea, borde
		end
		local x1, y1, x2, y2 = w * ruta.x[j], -h * ruta.y[j], w * ruta.x[k2], -h * ruta.y[k2]
		borde:SetThickness(5.5 / s)
		borde:SetStartPoint("TOPLEFT", marcoRuta, x1, y1)
		borde:SetEndPoint("TOPLEFT", marcoRuta, x2, y2)
		borde:SetVertexColor(sr or 0, sg or 0, sb or 0, 0.55)
		borde:Show()
		linea:SetThickness(2.5 / s)
		linea:SetStartPoint("TOPLEFT", marcoRuta, x1, y1)
		linea:SetEndPoint("TOPLEFT", marcoRuta, x2, y2)
		-- El tramo hacia la parada que sigue va entero; los demás, más suaves.
		local siguiente = ruta.guiando and k2 == ruta.siguiente
		linea:SetVertexColor(r, g, b, siguiente and 1 or 0.7)
		linea:Show()
	end
	for j = n + 1, lineasUsadas do
		lineas[j]:Hide()
		bordes[j]:Hide()
	end
	lineasUsadas = n
end

---------------------------------------------------------------------------
-- La vista del mapa
---------------------------------------------------------------------------
local function pedir()
	sucio = true
end

local function alVer(_, que, elapsed)
	if que == "tick" then
		reloj = reloj + (elapsed or 0)
		if not sucio and reloj >= REVISAR_VISTA and listaIdx then
			reloj = 0
			local x0, y0, x1, y1 = rectoVisible()
			local w = ventana
			if x0 < w[1] or y0 < w[2] or x1 > w[3] or y1 > w[4] or (x1 - x0) * 4 < (w[3] - w[1]) then sucio = true end
		end
		if sucio then
			sucio = false
			calcular()
			pintado = 0
			Mapa.DibujarRuta()
		end
		if pintado < ln or (ln == 0 and usados > 0) then pintar() end
	elseif que == "show" or que == "map" or que == "size" then
		ocultarDesde(1)
		pintado = 0
		sucio = true
	elseif que == "scale" then
		-- Al hacer zoom cambian los grupos: primero se reubican, luego se rehacen.
		reescalar()
		sucio = true
	elseif que == "hide" then
		if GameTooltip and raton and GameTooltip:GetOwner() == raton then GameTooltip:Hide() end
		raton, presionado = nil, nil
	end
end

local function instalar()
	if vista then return true end
	local MC = A.MapCanvas
	if not (WorldMapFrame and MC and MC.Watch) then return false end
	vista = MC.Watch(WorldMapFrame, alVer)
	return vista ~= nil
end

function Mapa.Instalar()
	if instalar() then return end
	local function alCargar(_, nombre)
		if nombre == "Blizzard_WorldMap" and instalar() then A.UnregisterEvent("ADDON_LOADED", alCargar) end
	end
	A.RegisterEvent("ADDON_LOADED", alCargar)
end

-- El mapa abierto vuelve a pintar todo en su próximo cuadro.
function Mapa.Refrescar()
	if vista and vista.shown then pedir() end
end

R.AlCambiar(function(que)
	if que == "ruta" then
		Mapa.DibujarRuta()
	elseif que == "nodos" or que == "filtros" then
		Mapa.Refrescar()
	end
end)

-- Los filtros llegan como "filtros"; aquí, lo que solo toca al mapa.
local PROPIOS = { ["recoleccion.mapa"] = true, ["recoleccion.tamanoMapa"] = true, ["recoleccion.agrupar"] = true }
A.On("SETTING_CHANGED", function(path)
	if PROPIOS[path] or path == "" or path == ID then Mapa.Refrescar() end
end)
