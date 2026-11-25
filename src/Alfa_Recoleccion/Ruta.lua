-- Alfa - Recolección: la ruta de farmeo (toxic3000 / La Jauría, GPL-3.0).
--
-- En la zona elegida se juntan los nodos del tipo (o del recurso) elegido
-- en paradas (los que están a menos de JUNTAR yardas son una sola), y se
-- ordenan en una vuelta cerrada corta: primero el vecino más cercano desde
-- donde estás, después la mejora 2-opt (dar vuelta un tramo cuando eso
-- acorta la vuelta) hasta que ya no mejora. El cálculo corre en una
-- corrutina con PRESUPUESTO ms por cuadro, así nunca traba el juego.
--
-- Guiar: la flecha del motor (Alfa.Nav.SetTarget) apunta a la parada más
-- cercana y, al llegar (o al recolectar ahí), pasa a la siguiente de la
-- vuelta. Si la flecha pasa a otra cosa (la guía, un clic en el mapa), la
-- ruta deja de guiar y sigue dibujada.

local _, M = ...
local N = AlfaNucleo
local A = N.A
local R = M.R
local L = N.Textos(M.EN)

local sqrt, floor, max = math.sqrt, math.floor, math.max
local ID = R.ID

local Ruta = {}
M.Ruta = Ruta

local JUNTAR = 35          -- yardas: nodos más cerca que esto son una parada
local MAX_PARADAS = 250
local PRESUPUESTO = 6      -- ms de cálculo por cuadro
local LIMITE_CALCULO = 8   -- segundos como mucho
local LLEGADA = 22         -- yardas: llegaste a la parada
local RECOLECTADO = 45     -- yardas: lo que recolectas cerca de la parada cuenta como llegar
local A_PIE, MONTADO = 7, 11.2 -- yardas por segundo

local ruta       -- la ruta actual (ver Ruta.Actual)
local trabajo    -- la corrutina del cálculo
local motor      -- el marco que la avanza
local vigia      -- el ticker que guía
local reloj = debugprofilestop or function() return GetTime() * 1000 end

function Ruta.Actual() return ruta end
function Ruta.Calculando() return trabajo ~= nil end

---------------------------------------------------------------------------
-- Juntar nodos en paradas
---------------------------------------------------------------------------
local function paradas(idx, b, tipo, recurso, radio)
	local celdas, lista = {}, {}
	local kx, ky = b.right - b.left, b.bottom - b.top
	for i = 1, idx.n do
		local g = idx.g[i]
		local gr = M.GRUPOS[g]
		-- 1.3.9 (oficios): recurso también puede ser un conjunto { clave = true } (la plata y
		-- las vetas de estaño y cobre donde puede salir).
		if gr.tipo == tipo and (recurso == nil or recurso == "todos" or gr.clave == recurso
			or (type(recurso) == "table" and recurso[gr.clave])) and R.ParaRuta(idx, i) then
			local wx, wy = b.top + ky * idx.y[i], b.left + kx * idx.x[i]
			local clave = floor(wx / radio) * 100000 + floor(wy / radio)
			local p = celdas[clave]
			if not p then
				p = { wx = 0, wy = 0, x = 0, y = 0, n = 0, grupos = {} }
				celdas[clave] = p
				lista[#lista + 1] = p
			end
			p.wx, p.wy, p.x, p.y, p.n = p.wx + wx, p.wy + wy, p.x + idx.x[i], p.y + idx.y[i], p.n + 1
			p.grupos[g] = (p.grupos[g] or 0) + 1
		end
	end
	for _, p in ipairs(lista) do
		p.wx, p.wy, p.x, p.y = p.wx / p.n, p.wy / p.n, p.x / p.n, p.y / p.n
		local mejor, mejorN = nil, 0
		for g, n in pairs(p.grupos) do
			if n > mejorN or (n == mejorN and g < mejor) then mejor, mejorN = g, n end
		end
		p.g = mejor
		p.grupos = nil
	end
	return lista
end

---------------------------------------------------------------------------
-- La vuelta: vecino más cercano y 2-opt, en una corrutina.
---------------------------------------------------------------------------
local inicioCuadro = 0
local function pausa()
	if reloj() - inicioCuadro > PRESUPUESTO then coroutine.yield() end
end

local function ordenar(lista, desdeX, desdeY, desde)
	local n = #lista
	local X, Y = {}, {}
	for k = 1, n do X[k], Y[k] = lista[k].wx, lista[k].wy end
	local function d(a, b)
		local dx, dy = X[a] - X[b], Y[a] - Y[b]
		return sqrt(dx * dx + dy * dy)
	end
	-- Empieza en la parada más cercana a ti (o la primera).
	local primero, mejor = 1, math.huge
	if desdeX then
		for k = 1, n do
			local dx, dy = X[k] - desdeX, Y[k] - desdeY
			local dd = dx * dx + dy * dy
			if dd < mejor then primero, mejor = k, dd end
		end
	end
	local t, usado = { primero }, { [primero] = true }
	for paso = 2, n do
		local ult = t[paso - 1]
		local elegido, cerca = nil, math.huge
		for k = 1, n do
			if not usado[k] then
				local dd = d(ult, k)
				if dd < cerca then elegido, cerca = k, dd end
			end
		end
		t[paso] = elegido
		usado[elegido] = true
		pausa()
	end
	-- 2-opt sobre la vuelta cerrada t[1..n] -> t[1].
	-- Se detiene al no mejorar, a las 50 pasadas o a LIMITE_CALCULO segundos:
	-- la vuelta siempre es válida, solo menos pulida.
	local mejoro, pasadas = n > 3, 0
	while mejoro and pasadas < 50 and GetTime() - desde < LIMITE_CALCULO do
		mejoro = false
		pasadas = pasadas + 1
		for i = 1, n - 2 do
			local a, b = t[i], t[i + 1]
			local dab = d(a, b)
			local hasta = (i == 1) and (n - 1) or n
			for j = i + 2, hasta do
				local c, e = t[j], t[j % n + 1]
				if d(a, c) + d(b, e) < dab + d(c, e) - 0.01 then
					local lo, hi = i + 1, j
					while lo < hi do
						t[lo], t[hi] = t[hi], t[lo]
						lo, hi = lo + 1, hi - 1
					end
					b = t[i + 1]
					dab = d(a, b)
					mejoro = true
				end
			end
			pausa()
		end
	end
	local largo = 0
	for k = 1, n do largo = largo + d(t[k], t[k % n + 1]) end
	return t, largo
end

local function terminar(nueva)
	trabajo = nil
	if motor then motor:Hide() end
	if nueva then ruta = nueva end
	R.Avisar("ruta")
	if Ruta.alListo then
		local fn = Ruta.alListo
		Ruta.alListo = nil
		A.SafeCall(fn, ruta)
	end
end

local function avanzarCalculo()
	if not trabajo then return end
	inicioCuadro = reloj()
	local ok, err = coroutine.resume(trabajo.co)
	if not ok then
		-- El cálculo falló: la página deja de decir "Calculando…" (sin ruta nueva).
		Ruta.alListo = nil
		terminar(nil)
		error(err, 0)
	end
	if coroutine.status(trabajo.co) == "dead" then terminar(trabajo.resultado) end
end

---------------------------------------------------------------------------
-- Crear
---------------------------------------------------------------------------
-- La zona donde estás (su mapa), o nil.
function Ruta.ZonaActual()
	local mapID = R.PosicionJugador()
	return mapID
end

-- Los recursos de un tipo que hay en una zona: { { clave, nombre, cuenta }, ... }
function Ruta.RecursosEn(mapID, tipo)
	local out, porG = {}, {}
	local idx = mapID and R.IndiceSiHay(mapID)
	if not idx then return out end
	for i = 1, idx.n do
		local g = idx.g[i]
		if M.GRUPOS[g].tipo == tipo and R.ParaRuta(idx, i) then porG[g] = (porG[g] or 0) + 1 end
	end
	for g, n in pairs(porG) do out[#out + 1] = { clave = M.GRUPOS[g].clave, nombre = R.Nombre(g), cuenta = n, g = g } end
	table.sort(out, function(a, b) return a.nombre < b.nombre end)
	return out
end

-- 1.4.0 (plan 73): las `n` paradas más cercanas a (px, py), en su orden de
-- la lista (para el circuito corto).
local function lasMasCercanas(lista, n, px, py)
	if not (n and px and #lista > n) then return lista end
	local orden = {}
	for k, p in ipairs(lista) do
		local dx, dy = p.wx - px, p.wy - py
		orden[k] = { p = p, d = dx * dx + dy * dy }
	end
	table.sort(orden, function(a, b) return a.d < b.d end)
	local out = {}
	for k = 1, n do out[k] = orden[k].p end
	return out
end
Ruta.MasCercanas = lasMasCercanas

-- Arma la ruta en la zona `mapID` (o la tuya) con el tipo y recurso
-- elegidos. alListo(ruta) cuando termina. -> true | false, motivo
-- op (1.4.0): { cerca = n (solo las n paradas más cercanas a ti), deGuia = true
-- (la pidió un paso de guía: al cambiar de paso se suelta sin decir nada) }
function Ruta.Crear(tipo, recurso, mapID, alListo, op)
	op = op or {}
	mapID = mapID or Ruta.ZonaActual()
	if not mapID then return false, L["No sé en qué zona estás."] end
	local idx = R.IndiceSiHay(mapID)
	local b = R.Limites(mapID)
	if not (idx and b) then return false, L["No hay nodos conocidos en esta zona."] end
	local radio = JUNTAR
	local lista = paradas(idx, b, tipo, recurso, radio)
	while #lista > MAX_PARADAS do
		radio = radio * 1.5
		lista = paradas(idx, b, tipo, recurso, radio)
	end
	if #lista < 3 then
		return false, L["Hacen falta al menos 3 lugares distintos de ese recurso en la zona."]
	end
	Ruta.Detener()
	local C = A.Compat
	local c, px, py = C.GetPlayerWorldPosition()
	if c ~= b.c then px, py = nil, nil end
	local total = #lista
	lista = lasMasCercanas(lista, op.cerca, px, py)
	local desde = GetTime()
	local co = coroutine.create(function()
		local t, largo = ordenar(lista, px, py, desde)
		local nueva = { mapa = mapID, c = b.c, tipo = tipo, recurso = recurso, n = #t, x = {}, y = {}, wx = {}, wy = {},
			g = {}, cuenta = {}, largo = largo, siguiente = 1, guiando = false, creada = time(),
			total = total, deGuia = op.deGuia and true or nil }
		for k, v in ipairs(t) do
			local p = lista[v]
			nueva.x[k], nueva.y[k], nueva.wx[k], nueva.wy[k], nueva.g[k], nueva.cuenta[k] = p.x, p.y, p.wx, p.wy, p.g, p.n
		end
		trabajo.resultado = nueva
	end)
	trabajo = { co = co }
	Ruta.alListo = alListo
	if not motor then
		motor = CreateFrame("Frame", nil, UIParent)
		motor:SetScript("OnUpdate", A.Safe(avanzarCalculo))
	end
	motor:Show()
	R.Avisar("ruta")
	avanzarCalculo()
	return true
end

---------------------------------------------------------------------------
-- Guiar con la flecha del motor
---------------------------------------------------------------------------
local function etiqueta(k)
	local nombre = R.Nombre(ruta.g[k])
	if (ruta.cuenta[k] or 1) > 1 then nombre = L["%s y %d más"]:format(nombre, ruta.cuenta[k] - 1) end
	return L["Ruta %d/%d: %s"]:format(k, ruta.n, nombre)
end

local function apuntar(k)
	if not ruta or ruta.n == 0 then return end
	ruta.siguiente = k
	local Nav = A.Nav
	if Nav and Nav.SetTarget then
		ruta.objetivo = Nav.SetTarget(ruta.mapa, ruta.x[k] * 100, ruta.y[k] * 100, etiqueta(k))
	end
	R.Avisar("ruta")
end
Ruta.Apuntar = function(k) return apuntar(k) end

-- 1.3.9: el clic en la flecha (Arrow.lua: A.Nav.OtroLugar) pasa a la
-- siguiente parada libre mientras esta ruta guía; se suelta al parar.
local gancho
gancho = {
	disponible = function()
		local Nav = A.Nav
		return ruta ~= nil and ruta.guiando and ruta.objetivo ~= nil and Nav and Nav.GetTarget and Nav.GetTarget() == ruta.objetivo or false
	end,
	ir = function()
		if not (ruta and ruta.guiando) then return false end
		local k = ruta.siguiente
		ruta.vacio = ruta.vacio or {}
		ruta.vacio[k] = GetTime()
		ruta.llegada = nil
		local Ruta_ = Ruta
		local sig = Ruta_.SiguienteLibre(k)
		N.Imprimir(L["Voy al siguiente (%d de %d)."]:format(sig, ruta.n))
		Ruta_.Apuntar(sig)
		return true
	end,
}
local ganchoAntes
local function tomarGancho()
	local Nav = A.Nav
	if not Nav then return end
	if Nav.OtroLugar ~= gancho then ganchoAntes = Nav.OtroLugar end
	Nav.OtroLugar = gancho
end
local function soltarGancho()
	local Nav = A.Nav
	if Nav and Nav.OtroLugar == gancho then Nav.OtroLugar = ganchoAntes end
	ganchoAntes = nil
end
Ruta.Gancho = gancho

local function parar(silencio)
	soltarGancho()
	if vigia then
		vigia:Cancel()
		vigia = nil
	end
	if not ruta then return end
	local Nav = A.Nav
	if ruta.guiando and ruta.objetivo and Nav and Nav.GetTarget and Nav.GetTarget() == ruta.objetivo and Nav.ReleaseTarget then
		Nav.ReleaseTarget()
	end
	ruta.guiando, ruta.objetivo = false, nil
	if not silencio then R.Avisar("ruta") end
end

-- 1.3.9 (oficios): puntos vacíos. Al llegar a una parada (CERCA yardas) y no
-- recolectar ahí en ESPERA segundos (o si te vas sin recolectar), queda
-- «vacía» VACIO segundos (lo que tarda en volver a salir) y la flecha pasa a
-- la siguiente libre; lo que recolectas también queda así. Lo dice:
-- «Aquí no hay ahora; voy al siguiente (3 de 12)».
local VACIO, ESPERA, CERCA = 15 * 60, 8, 30
Ruta.VACIO, Ruta.ESPERA, Ruta.CERCA = VACIO, ESPERA, CERCA

local function libre(k, ahora)
	local t = ruta.vacio and ruta.vacio[k]
	return not t or ahora - t >= VACIO
end

-- La siguiente parada libre después de k (con todas vacías, la que lleva más tiempo así).
local function siguienteLibre(k)
	local ahora = GetTime()
	for paso = 1, ruta.n do
		local j = (k + paso - 1) % ruta.n + 1
		if j ~= k and libre(j, ahora) then return j end
	end
	local mejor, viejo = k % ruta.n + 1, math.huge
	for j = 1, ruta.n do
		local t = ruta.vacio and ruta.vacio[j] or 0
		if j ~= k and t < viejo then mejor, viejo = j, t end
	end
	return mejor
end
Ruta.SiguienteLibre = function(k) return ruta and siguienteLibre(k or ruta.siguiente or 1) end
function Ruta.Vacia(k)
	return ruta ~= nil and not libre(k, GetTime())
end

-- motivo: "vacio" (lo dice) | "recolectado" | nil
local function avanzar(motivo)
	if not (ruta and ruta.guiando) then return end
	local k = ruta.siguiente
	ruta.vacio = ruta.vacio or {}
	ruta.vacio[k] = GetTime()
	ruta.llegada = nil
	local sig = siguienteLibre(k)
	if motivo == "vacio" then N.Imprimir(L["Aquí no hay ahora; voy al siguiente (%d de %d)."]:format(sig, ruta.n)) end
	apuntar(sig)
end
Ruta.Avanzar = avanzar

local function vigilar()
	if not (ruta and ruta.guiando) then return parar(true) end
	local Nav = A.Nav
	-- La flecha pasó a otra cosa: la ruta deja de guiar.
	if ruta.objetivo and Nav and Nav.GetTarget and Nav.GetTarget() ~= ruta.objetivo then
		ruta.objetivo = nil
		local deGuia = ruta.deGuia
		parar()
		-- 1.4.0: la que pidió un paso de guía se suelta callada al cambiar de paso.
		if not deGuia then N.Imprimir(L["La flecha ya no sigue tu ruta para juntar."]) end -- 1.3.6: sin «farmeo»
		return
	end
	local C = A.Compat
	local c, px, py = C.GetPlayerWorldPosition()
	if c and c == ruta.c then
		local k = ruta.siguiente
		local dx, dy = ruta.wx[k] - px, ruta.wy[k] - py
		local dd = dx * dx + dy * dy
		if dd <= CERCA * CERCA then
			-- Llegaste: si no recolectas aquí en un rato, está vacía (recolectando, se espera).
			local ahora = GetTime()
			if not ruta.llegada then
				ruta.llegada = ahora
			else
				local lanzando = N.SiJuego(rawget(_G, "UnitCastingInfo"), "player")
				-- 1.3.9: peleando con un bicho junto al nodo tampoco está vacío.
				local peleando = (InCombatLockdown and InCombatLockdown()) or N.SiJuego(rawget(_G, "UnitAffectingCombat"), "player")
				if lanzando or peleando then ruta.llegada = ahora
				elseif ahora - ruta.llegada >= ESPERA then avanzar("vacio") end
			end
		elseif ruta.llegada and dd > (CERCA * 1.6) * (CERCA * 1.6) then
			-- Te fuiste sin recolectar: también cuenta como vacía.
			avanzar("vacio")
		end
	end
end

-- Empieza a guiar desde la parada más cercana a ti.
function Ruta.Guiar()
	if not ruta or ruta.n == 0 or trabajo then return false end
	local C = A.Compat
	local c, px, py = C.GetPlayerWorldPosition()
	local k = ruta.siguiente or 1
	if c and c == ruta.c then
		local mejor = math.huge
		for j = 1, ruta.n do
			local dx, dy = ruta.wx[j] - px, ruta.wy[j] - py
			local dd = dx * dx + dy * dy
			if dd < mejor then k, mejor = j, dd end
		end
	end
	ruta.guiando = true
	apuntar(k)
	tomarGancho()
	if not vigia then vigia = N.Ticker("recoleccion.ruta", 0.5, vigilar) end
	-- cierra las ventanas de Alfa y muestra el seguimiento (1.4.0: no si la pidió el paso de guía que ya sigues)
	if N.EmpezarRuta and not ruta.deGuia then N.EmpezarRuta() end
	return true
end

function Ruta.Detener() parar() end

function Ruta.Borrar()
	parar(true)
	ruta = nil
	R.Avisar("ruta")
end

-- Deteccion.lua: recolectaste en (x, y) de mapID; si es la parada a la que
-- vas (o casi), pasa a la siguiente.
function Ruta.Recolectado(mapID, x, y)
	if not (ruta and ruta.guiando and mapID == ruta.mapa) then return end
	local b = R.Limites(mapID)
	if not b then return end
	local _, wx, wy = R.AlMundo(b, x, y)
	local k = ruta.siguiente
	local dx, dy = ruta.wx[k] - wx, ruta.wy[k] - wy
	if dx * dx + dy * dy <= RECOLECTADO * RECOLECTADO then avanzar("recolectado") end
end

-- Un clic en un pin del mapa: la flecha va ahí (sin ruta).
function Ruta.LlevarA(mapID, x, y, nombre)
	local Nav = A.Nav
	if not (Nav and Nav.SetTarget and mapID and x and y) then return end
	if ruta and ruta.guiando then parar() end
	Nav.SetTarget(mapID, x * 100, y * 100, nombre)
end

-- Texto de la ruta: "24 paradas · 4.2 km · ~10 min a pie (6 min montado)".
function Ruta.Resumen(r)
	r = r or ruta
	if not (r and r.n and r.n > 0) then return nil end
	local dist = A.FormatDistance and A.FormatDistance(r.largo) or (floor(r.largo + 0.5) .. " yd")
	local pie = max(1, floor(r.largo / A_PIE / 60 + 0.5))
	local montado = max(1, floor(r.largo / MONTADO / 60 + 0.5))
	return L["%d paradas · %s · unos %d min a pie (%d montado)"]:format(r.n, dist, pie, montado)
end
