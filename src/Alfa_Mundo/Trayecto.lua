-- Alfa - Mundo: tu camino en el mapa de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- (1.2.1) Sobre el arte y bajo los pines del mapa continuo:
--   * la ruta de la flecha: la misma que el motor dibuja en el mapa del juego
--     y en el minimapa (Maps/RouteLines.lua, RouteLines.GetPaths), con su
--     estilo (nav.lineStyle: la línea o los puntos; los destellos van como
--     línea) y empezando donde vas;
--   * mientras vuelas en grifo, el vuelo que tomaste, por donde vuela el
--     maestro de vuelo (FlightTracks), de donde vas hasta donde aterrizas;
--   * el destino, con un aro que late, y arriba a la izquierda una ficha:
--     a dónde vas y cuánto falta (por el camino y en tiempo). Clic: el mapa
--     muestra todo el camino, de ti al destino.
--
-- Las líneas son las de RouteStrokes (Strokes.Map), con una "vista" por
-- continente que cubre solo la ventana (más MARGEN): un camino largo no
-- trabaja ni dibuja fuera de lo que se ve. Se redibujan al mover el mapa, al
-- cambiar la ruta o el estilo, y unas veces por segundo si te mueves.
--
-- Interruptores: la línea, la capa "Línea de la ruta" (nav.routeLines); el
-- vuelo, "Tu vuelo en el mapa" (mundo.vueloEnMapa). Con Alfa oculto
-- (Alfa.Hidden) no se dibuja nada.
--
-- El pintor (pintar: cada trazo en un par de líneas, el contorno debajo)
-- sigue al del motor (Maps/RouteLines.lua), que a su vez sigue el de
-- Shortest Path Forever (UI/Route.lua) de Cillian Berragan,
-- GPL-3.0-or-later, usado con su permiso (CREDITOS.md).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local Geo, Lz = M.Geo, M.Lienzo

local type, ipairs, pairs, pcall, tonumber, min, max, floor, sqrt = type, ipairs, pairs, pcall, tonumber, math.min, math.max, math.floor, math.sqrt
local format = string.format

local Tr = {}
M.Trayecto = Tr

local NAV = "Interface\\AddOns\\Alfa\\Media\\Nav\\"
local DOT, SOFT, ARO = NAV .. "pin-fill", NAV .. "line-soft", NAV .. "ring"
local UNDER_ALPHA, SOFT_ALPHA = 0.5, 0.75 -- los del motor (RouteLines)
local MARGEN = 40           -- unidades de la vista que se dibujan fuera de ella
local ALCANCE = 60          -- yardas: el camino a pie empieza en ti si estás así de cerca
local ALCANCE_VUELO = 250   -- yardas: el vuelo (sus esquinas van recortadas)
local MOVIDO = 4            -- yardas que te mueves antes de volver a dibujar
local DESPEGUE = 20         -- segundos tras elegir el vuelo en que aún se espera despegar
local VIGENCIA = 3600       -- un vuelo guardado vale una hora (un /reload en el aire)
local MARCA_PARADA, MARCA_META = 6, 10 -- radio (unidades) del hueco de los puntos junto a un pin
local FICHA_MAX = 380       -- ancho máximo de la ficha
-- Colores del tema por tipo de tramo (los del motor: Maps/RouteLines.lua).
local TOKEN = { walk = "arrow", flight = "success", boat = "npc", zeppelin = "place", tram = "object", lift = "object" }

local raiz, vista
local duenos = {}          -- continente del juego -> marco con sus líneas
local colores, debajo = {}, { 0.02, 0.03, 0.06 }
for kind in pairs(TOKEN) do colores[kind] = { 1, 1, 1 } end
local paleta = colores
local revision, dibujada = 0, -1
local ultimo = {}          -- c, x, y de tu posición en el último dibujo
local progreso = setmetatable({}, { __mode = "k" }) -- camino -> índice del punto que sigue
local largos = setmetatable({}, { __mode = "k" })   -- camino -> { n, acumulado = {} }
local ficha, aro

local function cambio() revision = revision + 1 end
Tr.Cambio = cambio

---------------------------------------------------------------------------
-- Datos
---------------------------------------------------------------------------

local function oculto() return A.Hidden and A.Hidden() or false end

local function legible(v)
	local C = A.Compat
	if C and C.IsSecret and C.IsSecret(v) then return nil end
	return v
end

-- Tu posición en yardas: c, wx, wy (nil sin ella o si es secreta).
local function yo()
	local C = A.Compat
	if not (C and type(C.GetPlayerWorldPosition) == "function") then return nil end
	local ok, c, x, y = pcall(C.GetPlayerWorldPosition)
	if not ok then return nil end
	c, x, y = legible(c), legible(x), legible(y)
	if type(c) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return nil end
	return c, x, y
end

local function enElAire()
	local C = A.Compat
	return C and C.IsOnTaxi and C.IsOnTaxi() and true or false
end

-- Cada continente del mapa continuo: de yardas a unidades del lienzo.
--   x = x0 + (wy - ya) / dy * cw,  y = y0 + (wx - xa) / dx * ch
local proy = {}            -- c del juego -> proyección
local function proyecciones()
	if next(proy) then return proy end
	local C = A.Compat
	if not (C and type(C.MapToWorld) == "function") then return proy end
	local W, H = Lz.Tamano()
	for _, cont in ipairs(Geo.Continentes()) do
		local l, r, t, b = Geo.Rect(cont)
		local ok1, c1, xa, ya = pcall(C.MapToWorld, cont, 0, 0)
		local ok2, c2, xb, yb = pcall(C.MapToWorld, cont, 100, 100)
		if l and ok1 and ok2 and c1 ~= nil and c1 == c2 and type(xa) == "number" and type(ya) == "number"
			and type(xb) == "number" and type(yb) == "number" and xa ~= xb and ya ~= yb then
			proy[c1] = { c = c1, xa = xa, ya = ya, dx = xb - xa, dy = yb - ya, x0 = l * W, y0 = t * H, cw = (r - l) * W, ch = (b - t) * H }
		end
	end
	return proy
end
Tr.Proyecciones = proyecciones

-- Un punto en yardas en la vista de ahora (unidades desde su esquina).
local function aVista(c, wx, wy)
	local p = proyecciones()[c]
	local a = Lz.Ahora()
	if not (p and a and a.k and a.ox) then return nil end
	local lx = p.x0 + (wy - p.ya) / p.dy * p.cw
	local ly = p.y0 + (wx - p.xa) / p.dx * p.ch
	return a.ox + lx * a.k, a.oy + ly * a.k
end
Tr.AVista = aVista

-- Yardas en el mundo continuo (0..1), para encuadrar.
local function aMundo(c, wx, wy)
	local p = proyecciones()[c]
	if not p then return nil end
	local W, H = Lz.Tamano()
	return (p.x0 + (wy - p.ya) / p.dy * p.cw) / W, (p.y0 + (wx - p.xa) / p.dx * p.ch) / H
end

---------------------------------------------------------------------------
-- El vuelo que tomaste
---------------------------------------------------------------------------

local vuelo -- { path, nombre, c, wx, wy (aterrizaje), t (GetTime al elegir), enAire }

local function nodoDe(slot)
	local Maps, Nav = A.Maps, A.Nav
	local Cl = Maps and Maps.Client
	if not (slot and Cl and Cl.TaxiSlot and Nav and Nav.GetTaxiNode) then return nil end
	local ok, id, nombre = pcall(Cl.TaxiSlot, slot)
	if not ok then return nil end
	id = tonumber(id)
	if not id and type(nombre) == "string" and Maps.TaxiNodeByName then
		local ok2, otro = pcall(Maps.TaxiNodeByName, nombre, Maps.Faction and Maps.Faction() or nil)
		if ok2 then id = tonumber(otro) end
	end
	local t = id and Nav.GetTaxiNode(id)
	if type(t) ~= "table" or not (t.c and t.wx and t.wy) then return nil end
	return id, t.c, t.wx, t.wy, type(nombre) == "string" and nombre or nil
end

local function corto(nombre)
	if type(nombre) ~= "string" or nombre == "" then return nil end
	return nombre:match("^([^,]+),") or nombre
end

local function armarVuelo(pts, nodos, nombre)
	local S = A.RouteStrokes
	if not (S and #pts >= 2) then return nil end
	local fin = pts[#pts]
	return {
		path = S.Path("flight", pts, false, A.FlightTracks, nodos), nombre = corto(nombre),
		c = fin[1], wx = fin[2], wy = fin[3], pts = pts, nodos = nodos,
	}
end

local function guardarVuelo()
	local d = N.DatosPersonaje("mundo")
	if vuelo then
		d.vuelo = { pts = vuelo.pts, nodos = vuelo.nodos, nombre = vuelo.nombre, t = time and time() or 0 }
	else
		d.vuelo = nil
	end
end

local function soltarVuelo()
	if not vuelo then return end
	vuelo = nil
	guardarVuelo()
	cambio()
end

-- Al elegir el destino en el mapa de vuelo (TakeTaxiNode, enganchado, nunca
-- reemplazado): sus escalas con GetNumRoutes y TaxiGetNodeSlot, como hace el
-- motor para dibujarla en el mapa de vuelo.
local function alTomar(slot)
	slot = tonumber(slot)
	if not slot then return end
	vuelo = nil
	local pts, nodos = {}, {}
	local function poner(s)
		local id, c, wx, wy = nodoDe(s)
		if not id then return false end
		pts[#pts + 1], nodos[#nodos + 1] = { c, wx, wy }, id
		return true
	end
	local tramos = GetNumRoutes and tonumber(legible(GetNumRoutes(slot))) or 0
	local bien = true
	if tramos >= 1 and TaxiGetNodeSlot then
		bien = poner(TaxiGetNodeSlot(slot, 1, true))
		for i = 1, tramos do bien = bien and poner(TaxiGetNodeSlot(slot, i, false)) end
	else
		-- Sin los tramos: del maestro de vuelo donde estás al destino.
		local Cl = A.Maps and A.Maps.Client
		local actual
		if Cl and Cl.TaxiCurrent and NumTaxiNodes and TaxiNodeGetType then
			for i = 1, NumTaxiNodes() or 0 do
				if TaxiNodeGetType(i) == "CURRENT" then actual = i break end
			end
		end
		bien = actual and poner(actual) and poner(slot) or false
	end
	local _, _, _, _, nombre = nodoDe(slot)
	if bien then
		vuelo = armarVuelo(pts, nodos, nombre)
		if vuelo then vuelo.t = GetTime and GetTime() or 0 end
	end
	guardarVuelo()
	cambio()
end
Tr.AlTomar = alTomar

if TakeTaxiNode and hooksecurefunc then
	hooksecurefunc("TakeTaxiNode", function(slot)
		local ok, err = pcall(alTomar, slot)
		if not ok and A.Debug then A.Debug("Alfa_Mundo: " .. tostring(err)) end
	end)
end

-- Despegó, aterrizó o nunca subió.
local function vigilarVuelo()
	if not vuelo then return end
	if enElAire() then
		if not vuelo.enAire then
			vuelo.enAire = true
			cambio()
		end
	elseif vuelo.enAire or (GetTime and GetTime() or 0) - (vuelo.t or 0) > DESPEGUE then
		soltarVuelo()
	end
end

-- El reloj de vuelo del motor avisa al despegar y al aterrizar aunque el mapa
-- esté cerrado (vigilarVuelo solo corre con el mapa abierto).
A.On("FLIGHT_STARTED", function()
	if vuelo and not vuelo.enAire then
		vuelo.enAire = true
		cambio()
	end
end)
A.On("FLIGHT_ENDED", function() soltarVuelo() end)

-- Un /reload en el aire: el vuelo guardado sigue si es reciente y sano.
A.OnLogin(function()
	local d = N.DatosPersonaje("mundo")
	local g = d.vuelo
	local sano = type(g) == "table" and type(g.pts) == "table" and type(g.nodos) == "table" and #g.pts >= 2
	if sano then
		for _, p in ipairs(g.pts) do
			if type(p) ~= "table" or type(p[1]) ~= "number" or type(p[2]) ~= "number" or type(p[3]) ~= "number" then sano = false break end
		end
	end
	local ahora = time and time() or 0
	if sano and enElAire() and ahora - (tonumber(g.t) or 0) < VIGENCIA then
		vuelo = armarVuelo(g.pts, g.nodos, g.nombre)
		if vuelo then vuelo.enAire, vuelo.t = true, GetTime and GetTime() or 0 end
	else
		d.vuelo = nil
	end
end)

local function vueloVisible()
	return vuelo ~= nil and A.Get("mundo.vueloEnMapa") ~= false and not oculto()
end

---------------------------------------------------------------------------
-- La ruta de la flecha
---------------------------------------------------------------------------

local function rutaVisible()
	if not A.Get("nav.routeLines") or oculto() then return nil end
	local Nav, RL = A.Nav, A.RouteLines
	if not (Nav and Nav.GetTarget and Nav.GetTarget() and RL and type(RL.GetPaths) == "function") then return nil end
	local paths = RL.GetPaths()
	if type(paths) ~= "table" or #paths == 0 then return nil end
	return paths
end

-- Lo que se dibuja, en orden: el vuelo (si vas en uno) y la ruta. Con el
-- vuelo, el tramo de vuelo de la ruta que va ahora sobra: es el mismo.
local lista = {}
local function caminos()
	for i = #lista, 1, -1 do lista[i] = nil end
	local v = vueloVisible() and vuelo or nil
	if v then lista[1] = v.path end
	local ruta = rutaVisible()
	if ruta then
		for _, p in ipairs(ruta) do
			if not (v and p.kind == "flight" and not p.later) then lista[#lista + 1] = p end
		end
	end
	return lista, v
end
Tr.Caminos = caminos

-- El destino: mientras vas en grifo, donde aterrizas (lo que importa en el
-- aire; la ruta sigue dibujada para después); si no, el de la flecha.
-- -> c, wx, wy, nombre, esVuelo
local function meta()
	local v = vueloVisible() and vuelo or nil
	if v then return v.c, v.wx, v.wy, v.nombre, true end
	local ruta = rutaVisible()
	local Nav = A.Nav
	if ruta and Nav and Nav.GetTargetWorld then
		local c, x, y = Nav.GetTargetWorld()
		if c and x and y then
			local t = Nav.GetTarget()
			local nombre = type(t) == "table" and type(t.label) == "string" and t.label or nil
			return c, x, y, nombre, false
		end
	end
	return nil
end
Tr.Meta = meta

-- Yardas a lo largo de un camino, acumuladas por punto (una vez por camino).
local function acumulado(path)
	local a = largos[path]
	if a and a.n == path.n then return a end
	a = { n = path.n, [1] = 0 }
	local cs, xs, ys = path.c, path.x, path.y
	for i = 2, path.n do
		local d = 0
		if cs[i] == cs[i - 1] then
			local dx, dy = xs[i] - xs[i - 1], ys[i] - ys[i - 1]
			d = sqrt(dx * dx + dy * dy)
		end
		a[i] = a[i - 1] + d
	end
	largos[path] = a
	return a
end

-- Lo que falta por el camino, en yardas, desde (c, x, y). En el aire, solo
-- el vuelo: la ficha habla de donde aterrizas.
local soloVuelo = {}
local function falta(caminosAhora, c, x, y, esVuelo)
	if esVuelo and caminosAhora[1] then
		soloVuelo[1] = caminosAhora[1]
		caminosAhora = soloVuelo
	end
	local total = 0
	for i, path in ipairs(caminosAhora) do
		local a = acumulado(path)
		local desde = 1
		if i == 1 then
			local k = progreso[path]
			if k and c and path.c[k] == c then
				local dx, dy = path.x[k] - x, path.y[k] - y
				total = total + sqrt(dx * dx + dy * dy)
				desde = k
			elseif c and path.c[1] == c then
				local dx, dy = path.x[1] - x, path.y[1] - y
				total = total + sqrt(dx * dx + dy * dy)
			end
		end
		total = total + (a[path.n] or 0) - (a[desde] or 0)
	end
	return total
end
Tr.Falta = falta

-- Segundos que faltan: el vuelo, del reloj de vuelo del motor; la ruta, de su
-- plan de viaje (lo mismo que dice la flecha).
local function segundos(esVuelo)
	if esVuelo then
		local Maps = A.Maps
		if Maps and Maps.GetFlight then
			local ok, _, s = pcall(Maps.GetFlight)
			if ok and type(s) == "number" then return max(0, s) end
		end
		return nil
	end
	local T = A.Nav and A.Nav.travel
	if not (T and T.Progress and T.Remaining) then return nil end
	local ok, s = pcall(function()
		local _, y = T.Progress()
		return T.Remaining(y, true)
	end)
	if ok and type(s) == "number" and s >= 0 and s < 36000 then return s end
	return nil
end

---------------------------------------------------------------------------
-- Pintar: cada trazo en su par de líneas (el contorno debajo del centro)
---------------------------------------------------------------------------

local function textura(dueno, i, punto, suave)
	local uso = punto and "punto" or suave and "suave" or "plano"
	if dueno.usos[i] == uso then return end
	dueno.usos[i] = uso
	local linea, borde = dueno.lineas[i], dueno.bordes[i]
	if punto then
		linea:SetTexture(DOT)
		borde:SetTexture(DOT)
	else
		linea:SetColorTexture(1, 1, 1, 1)
		if suave then borde:SetTexture(SOFT) else borde:SetColorTexture(1, 1, 1, 1) end
	end
	linea:SetTexCoord(0, 1, 0, 1)
	borde:SetTexCoord(0, 1, 0, 1)
end

local function pintar(dueno, s)
	local lineas, bordes = dueno.lineas, dueno.bordes
	local n = s.n
	for i = 1, n do
		local linea, borde = lineas[i], bordes[i]
		if not linea then
			borde = dueno:CreateLine(nil, "ARTWORK", nil, -1)
			linea = dueno:CreateLine(nil, "ARTWORK")
			lineas[i], bordes[i] = linea, borde
		end
		local suave = s.soft[i]
		textura(dueno, i, s.dot[i], suave)
		local x1, y1, x2, y2 = s.x1[i], s.y1[i], s.x2[i], s.y2[i]
		local ux, uy, alfa = s.ux[i], s.uy[i], s.alpha[i]
		local grueso = s.under[i]
		if grueso > 0 then
			borde:SetAlpha(alfa * (suave and SOFT_ALPHA or UNDER_ALPHA))
			borde:SetThickness(grueso)
			borde:SetStartPoint("TOPLEFT", dueno, x1 - ux, y1 - uy)
			borde:SetEndPoint("TOPLEFT", dueno, x2 + ux, y2 + uy)
			borde:SetVertexColor(debajo[1], debajo[2], debajo[3])
			borde:Show()
		else
			borde:Hide()
		end
		local col = s.color[i]
		linea:SetVertexColor(col[1], col[2], col[3])
		linea:SetAlpha(alfa)
		linea:SetThickness(s.width[i])
		linea:SetStartPoint("TOPLEFT", dueno, x1, y1)
		linea:SetEndPoint("TOPLEFT", dueno, x2, y2)
		linea:Show()
	end
	for i = n + 1, dueno.usados do
		lineas[i]:Hide()
		bordes[i]:Hide()
	end
	dueno.usados = n
end

local function dueno(c)
	local d = duenos[c]
	if d then return d end
	local S = A.RouteStrokes
	d = CreateFrame("Frame", nil, raiz)
	d:EnableMouse(false)
	d.lineas, d.bordes, d.usos, d.usados = {}, {}, {}, 0
	d.trazos = S.New()
	d.vista = { marks = {}, markCount = 0 }
	duenos[c] = d
	return d
end

local function limpiar(d)
	d.trazos.n = 0
	pintar(d, d.trazos)
	d:Hide()
end

local function recolorear()
	local T = A.Theme
	if T and type(T.Color) == "function" then
		for kind, token in pairs(TOKEN) do
			local c = colores[kind]
			local ok, r, g, b = pcall(T.Color, token)
			if ok and type(r) == "number" then c[1], c[2], c[3] = r, g, b end
		end
		local ok, r, g, b = pcall(T.Color, "scrim")
		if ok and type(r) == "number" then debajo[1], debajo[2], debajo[3] = r, g, b end
	end
	-- nav.dotColor: un solo color para lo que se camina (como el motor).
	local RL = A.RouteLines
	local tinte = RL and RL.DOT_COLORS and RL.DOT_COLORS[A.Get("nav.dotColor")]
	if tinte then
		paleta = {}
		for kind, c in pairs(colores) do paleta[kind] = kind == "walk" and tinte or c end
	else
		paleta = colores
	end
end

-- El estilo del motor: "line" (también por los destellos) o nil (puntos).
local function estilo()
	local RL = A.RouteLines
	local e = RL and RL.Style and RL.Style() or A.Get("nav.lineStyle")
	if e == "dots" then return nil end
	return "line"
end

local function grosor()
	local S = A.RouteStrokes
	local w = tonumber(A.Get("nav.lineWidth")) or S.LINE_WIDTH
	local r = S.LINE_WIDTHS
	return max(r[1], min(r[2], w))
end

---------------------------------------------------------------------------
-- El destino y la ficha
---------------------------------------------------------------------------

local function crearAro()
	local latir = M.Marcas.Latir
	aro = CreateFrame("Frame", nil, raiz)
	aro:SetSize(30, 30)
	aro:EnableMouse(false)
	aro.fijo = aro:CreateTexture(nil, "ARTWORK")
	aro.fijo:SetTexture(ARO)
	aro.fijo:SetAllPoints()
	aro.pulso = CreateFrame("Frame", nil, aro)
	aro.pulso:SetSize(30, 30)
	aro.pulso:SetPoint("CENTER")
	aro.pulso.t = aro.pulso:CreateTexture(nil, "ARTWORK")
	aro.pulso.t:SetTexture(ARO)
	aro.pulso.t:SetAllPoints()
	latir(aro.pulso, 1, 2.4, 1.6)
	aro.punto = aro:CreateTexture(nil, "OVERLAY")
	aro.punto:SetTexture(DOT)
	aro.punto:SetSize(9, 9)
	aro.punto:SetPoint("CENTER")
	aro:Hide()
end

-- El aro del destino: latiendo (fijo con "menos movimiento"). El punto del
-- centro solo con el vuelo: la ruta ya tiene el pin del destino del motor.
local function ponerAro(x, y, esVuelo)
	if not aro then crearAro() end
	local r, g, b = 1, 0.8, 0.3
	local T = A.Theme
	if T and T.Color then
		local ok, cr, cg, cb = pcall(T.Color, esVuelo and "success" or "accent")
		if ok and type(cr) == "number" then r, g, b = cr, cg, cb end
	end
	aro.fijo:SetVertexColor(r, g, b, 0.9)
	aro.pulso.t:SetVertexColor(r, g, b, 1)
	aro.punto:SetVertexColor(r, g, b, 1)
	aro.punto:SetShown(esVuelo and true or false)
	local Mc = M.Marcas
	local px = Mc and Mc.AlPixel or function(v) return v end
	aro:ClearAllPoints()
	aro:SetPoint("CENTER", raiz, "TOPLEFT", px(x), -px(y))
	aro:Show()
	M.Marcas.Latiendo(aro.pulso)
end

local function quitarAro()
	if not aro then return end
	if aro.pulso.latido and aro.pulso.latido:IsPlaying() then aro.pulso.latido:Stop() end
	aro:Hide()
end

local function crearFicha()
	ficha = CreateFrame("Button", nil, vista)
	ficha:SetHeight(30)
	ficha:SetFrameLevel(vista:GetFrameLevel() + (Lz.NIVELES or 30) + 120)
	ficha:SetPoint("TOPLEFT", vista, "TOPLEFT", K.ESP.m, -K.ESP.m)
	ficha.caja = K.Caja(ficha, { fondo = "fondo", borde = "linea", corte = K.CORTE.control, alfaFondo = 0.92 })
	ficha.Icono = K.Icono(ficha, "ic-ruta", 14, "acento")
	ficha.Icono:SetPoint("LEFT", ficha, "LEFT", K.ESP.s + 2, 0)
	ficha.Nombre = K.Texto(ficha, "etiqueta", "texto")
	ficha.Nombre:SetPoint("LEFT", ficha.Icono, "RIGHT", K.ESP.s, 0)
	ficha.Datos = K.Texto(ficha, "numero", "acento")
	ficha.Datos:SetPoint("LEFT", ficha.Nombre, "RIGHT", K.ESP.s, 0)
	ficha:RegisterForClicks("LeftButtonUp")
	ficha:SetScript("OnClick", function()
		if Tr.alVerCamino then Tr.alVerCamino() end
	end)
	K.ConInfo(ficha, L["Tu camino [mapa]"], L["Clic: el mapa muestra todo el camino, de ti al destino."])
	ficha:Hide()
end

local mostrado = {}
local function ponerFicha(nombre, yardas, segs, esVuelo)
	if not ficha then crearFicha() end
	local titulo = esVuelo and format(L["En vuelo a %s"], nombre or L["tu destino"]) or (nombre or L["Destino"])
	local partes = {}
	if yardas and yardas >= 1 then
		local fmt = A.FormatDistance
		partes[#partes + 1] = fmt and fmt(yardas, { round = yardas >= 200 and 10 or 1 }) or format(L["%d yd"], floor(yardas + 0.5))
	end
	if segs then
		local Maps = A.Maps
		local t = Maps and Maps.FormatTime and Maps.FormatTime(segs) or tostring(floor(segs + 0.5))
		partes[#partes + 1] = "~" .. t
	end
	local datos = table.concat(partes, "  \194\183  ")
	if titulo ~= mostrado.titulo or datos ~= mostrado.datos or esVuelo ~= mostrado.vuelo then
		mostrado.titulo, mostrado.datos, mostrado.vuelo = titulo, datos, esVuelo
		K.SetIcono(ficha.Icono, esVuelo and "icon-fly" or "ic-ruta", esVuelo and "exito" or "acento")
		K.Escribir(ficha.Nombre, titulo)
		ficha.Datos:SetText(datos)
		-- El nombre se corta antes de que la ficha pase de FICHA_MAX.
		ficha.Nombre:SetWidth(0)
		local wd = datos ~= "" and (ficha.Datos:GetStringWidth() or 0) + K.ESP.s or 0
		local libre = FICHA_MAX - (K.ESP.s + 2 + 14 + K.ESP.s) - wd - K.ESP.m
		local wn = min(ficha.Nombre:GetStringWidth() or 0, libre)
		ficha.Nombre:SetWidth(max(20, wn))
		ficha:SetWidth(floor(K.ESP.s + 2 + 14 + K.ESP.s + max(20, wn) + wd + K.ESP.m + 0.5))
	end
	ficha:Show()
end

local function quitarFicha()
	if ficha then ficha:Hide() end
	mostrado.titulo = nil
end

---------------------------------------------------------------------------
-- Dibujar
---------------------------------------------------------------------------

local vistaAhora = {}

-- La vista de Strokes.Map para el continente c: la ventana (más MARGEN) como
-- si fuera un mapa, con sus yardas en las esquinas.
local function vistaDe(d, p, a, vw, vh)
	local v = d.vista
	local X0, Y0, X1, Y1 = -MARGEN, -MARGEN, vw + MARGEN, vh + MARGEN
	local function wy(X) return p.ya + ((X - a.ox) / a.k - p.x0) * p.dy / p.cw end
	local function wx(Y) return p.xa + ((Y - a.oy) / a.k - p.y0) * p.dx / p.ch end
	local l, r, t, b = wy(X0), wy(X1), wx(Y0), wx(Y1)
	if r == l or b == t then return nil end
	v.c, v.left, v.top, v.kx, v.ky = p.c, l, t, 1 / (r - l), 1 / (b - t)
	v.width, v.height = X1 - X0, Y1 - Y0
	v.scale = d:GetEffectiveScale() or 1
	if not (v.scale > 0) then v.scale = 1 end
	v.small = (vistaAhora.z or 1) < 3
	v.colors = paleta
	v.style, v.lineWidth, v.chevrons = estilo(), grosor(), false
	d:ClearAllPoints()
	d:SetPoint("TOPLEFT", raiz, "TOPLEFT", X0, -Y0)
	d:SetSize(v.width, v.height)
	return v
end

-- Las marcas donde los puntos dejan hueco (los pines de cada parada y el destino).
local function marcas(v, lst)
	local m, n = v.marks, 0
	for i, path in ipairs(lst) do
		local k = path.n
		if k >= 1 and path.c[k] == v.c then
			m[n * 3 + 1] = (path.y[k] - v.left) * v.kx
			m[n * 3 + 2] = (path.x[k] - v.top) * v.ky
			m[n * 3 + 3] = i == #lst and MARCA_META or MARCA_PARADA
			n = n + 1
		end
	end
	v.markCount = n
end

-- El punto del primer camino que sigue a tu posición (nunca para atrás).
local function avanzar(lst, c, x, y, esVuelo)
	local first = lst[1]
	if not (first and c) then return nil end
	if not (esVuelo or (first.kind == "walk" and not first.later)) then return nil end
	local S = A.RouteStrokes
	local i = S.Live(first, c, x, y, progreso[first], esVuelo and ALCANCE_VUELO or ALCANCE)
	if i then progreso[first] = i end
	return progreso[first]
end

local function dibujar()
	if not raiz then return end
	dibujada = revision
	local S = A.RouteStrokes
	local a = Lz.Ahora()
	local vw, vh = vistaAhora.vw, vistaAhora.vh
	local lst, v = caminos()
	local c, x, y = yo()
	ultimo.c, ultimo.x, ultimo.y = c, x, y
	if not (S and a and a.k and a.ox and vw and #lst > 0) then
		for _, d in pairs(duenos) do limpiar(d) end
		quitarAro()
		quitarFicha()
		return
	end
	local desde = avanzar(lst, c, x, y, v ~= nil)
	local usados = {}
	for pc, p in pairs(proyecciones()) do
		-- Solo los continentes que cruzan la ventana y por donde pasa el camino.
		local sx0, sy0 = a.ox + p.x0 * a.k, a.oy + p.y0 * a.k
		local sx1, sy1 = sx0 + p.cw * a.k, sy0 + p.ch * a.k
		local cruza = sx0 < vw + MARGEN and sx1 > -MARGEN and sy0 < vh + MARGEN and sy1 > -MARGEN
		local pasa = false
		if cruza then
			for _, path in ipairs(lst) do
				for i = 1, path.n do if path.c[i] == pc then pasa = true break end end
				if pasa then break end
			end
		end
		if pasa then
			local d = dueno(pc)
			local vista2 = vistaDe(d, p, a, vw, vh)
			if vista2 then
				marcas(vista2, lst)
				local from = desde ~= nil and c == pc
				vista2.from, vista2.fromIndex, vista2.fromC, vista2.fromX, vista2.fromY = from, desde, c, x, y
				S.Map(d.trazos, lst, vista2)
				pintar(d, d.trazos)
				d:Show()
				usados[pc] = true
			end
		end
	end
	for pc, d in pairs(duenos) do
		if not usados[pc] then limpiar(d) end
	end
	-- El destino y la ficha.
	local mc, mx, my, nombre, esVuelo = meta()
	local dx, dy
	if mc then dx, dy = aVista(mc, mx, my) end
	if dx and dx >= -20 and dy >= -20 and dx <= vw + 20 and dy <= vh + 20 then
		ponerAro(dx, dy, esVuelo)
	else
		quitarAro()
	end
	if mc then
		ponerFicha(nombre, falta(lst, c, x, y, esVuelo), segundos(esVuelo), esVuelo)
	else
		quitarFicha()
	end
end

---------------------------------------------------------------------------
-- Entrada
---------------------------------------------------------------------------

function Tr.Crear(padre)
	if raiz then return raiz end
	vista = padre
	raiz = CreateFrame("Frame", nil, padre)
	raiz:SetAllPoints(padre)
	raiz:EnableMouse(false)
	-- Sobre todas las capas del lienzo y debajo de los pines (Marcas: NIVELES + 10).
	raiz:SetFrameLevel(padre:GetFrameLevel() + (Lz.NIVELES or 30) + 4)
	recolorear()
	local T = A.Theme
	if T and type(T.OnChanged) == "function" then
		T.OnChanged(function()
			recolorear()
			cambio()
		end)
	end
	return raiz
end

-- Tras cada cambio de la vista (mover, zoom, tamaño).
function Tr.Colocar(cu, cv, k, vw, vh, z)
	if not raiz then return end
	vistaAhora.cu, vistaAhora.cv, vistaAhora.k, vistaAhora.vw, vistaAhora.vh, vistaAhora.z = cu, cv, k, vw, vh, z
	dibujar()
end

-- Unas veces por segundo con el mapa quieto: si cambió la ruta o el vuelo,
-- o te moviste, se vuelve a dibujar; si no, solo la ficha (el tiempo corre).
function Tr.Latido()
	if not (raiz and vistaAhora.vw) then return end
	vigilarVuelo()
	local c, x, y = yo()
	local movido = c ~= ultimo.c or (x and ultimo.x and ((x - ultimo.x) ^ 2 + (y - ultimo.y) ^ 2 >= MOVIDO * MOVIDO))
	if revision ~= dibujada or movido then
		dibujar()
		return
	end
	local mc, _, _, nombre, esVuelo = meta()
	if mc and ficha and ficha:IsShown() then
		local lst = caminos()
		ponerFicha(nombre, falta(lst, c, x, y, esVuelo), segundos(esVuelo), esVuelo)
	end
end

-- El rectángulo (0..1 del mundo) de ti y el destino, con el camino: para el
-- clic en la ficha. -> u0, v0, u1, v1 | nil
function Tr.Encuadre()
	local u0, v0, u1, v1
	local function sumar(u, v)
		if not u then return end
		u0, v0 = min(u0 or u, u), min(v0 or v, v)
		u1, v1 = max(u1 or u, u), max(v1 or v, v)
	end
	local c, x, y = yo()
	if c then sumar(aMundo(c, x, y)) end
	local mc, mx, my = meta()
	if mc then sumar(aMundo(mc, mx, my)) end
	local lst = caminos()
	for _, path in ipairs(lst) do
		local paso = max(1, floor(path.n / 40))
		for i = 1, path.n, paso do sumar(aMundo(path.c[i], path.x[i], path.y[i])) end
		sumar(aMundo(path.c[path.n], path.x[path.n], path.y[path.n]))
	end
	if not u0 then return nil end
	return u0, v0, u1, v1
end

-- Para pruebas.
function Tr.Vuelo() return vuelo end
function Tr.Dibujados()
	local n = 0
	for _, d in pairs(duenos) do if d:IsShown() then n = n + d.usados end end
	return n
end
function Tr.Ficha() return ficha end
function Tr.Trazos(c) local d = duenos[c] return d and d.trazos, MARGEN end
function Tr.Aro() return aro end

A.On("NAV_ROUTE_GEOMETRY", cambio)
local MIRAR = {
	["nav.routeLines"] = true, ["nav.lineStyle"] = true, ["nav.lineWidth"] = true, ["nav.dotColor"] = true,
	["nav"] = true, [""] = true, ["mundo.vueloEnMapa"] = true, ["ui.reduceMotion"] = true,
}
A.On("SETTING_CHANGED", function(path)
	if MIRAR[path] then
		if path == "nav.dotColor" or path == "nav" or path == "" then recolorear() end
		cambio()
	end
end)
