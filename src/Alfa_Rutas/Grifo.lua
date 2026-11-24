-- Alfa - Rutas: «Toma el grifo» (toxic3000 / La Jauría). GPL-3.0.
-- 1.3.8
--
-- Si vas a caminar lejos y un vuelo te ahorra tiempo, el rastreador lo dice:
-- «Vuela desde Villa Dorada: ahorras 4 min», con «Llévame al maestro de
-- vuelo». Dos casos:
--   * la ruta del motor ya vuela (Nav.GetRoute: una pierna "fly" adelante y
--     solo caminos antes): se dice cuánto ahorra contra ir a pie en línea
--     recta (A.DirectTravelCost x 1,25, la misma cuenta que el motor). El
--     botón pone la flecha y el rastreador a la vista: la flecha ya te lleva;
--   * la ruta del motor está apagada (nav.travel = false): Alfa mira los
--     maestros de vuelo que conoces (Nav.GetKnownTaxiNodes) en tu continente,
--     el más cercano a ti y el más cercano a tu destino, y si caminar a uno,
--     volar al otro y caminar el resto ahorra, lo propone. El botón pone la
--     flecha en el maestro de vuelo; al aterrizar, la flecha vuelve a tu
--     destino de antes.
-- Solo si ahorra AHORRO segundos o más. Nunca en instancias; nada se mide
-- por cuadro (lo pide el rastreador al pintarse, guardado POR_UN_RATO s).
-- «Ahora no» lo calla para ese destino. Sin el rastreador a la vista, un
-- aviso una vez por destino. Ajuste rutas.tomaGrifo.
--
--   Grifo.Calcular() -> { nodo, hacia, ahorro, camina, vuela, punto?, propio? } | nil, motivo
--   Grifo.Aviso() -> el aviso del rastreador | nil
--   Grifo.Llevar(d) -> ok

local ADDON, M = ...
local A, L, K, N = M.A, M.L, M.K, M.N
local Gf = {}
M.Grifo = Gf

A.RegisterDefaults(M.ID, { tomaGrifo = true })

local type, pairs, ipairs, tonumber, tostring, pcall = type, pairs, ipairs, tonumber, tostring, pcall
local sqrt, floor, format = math.sqrt, math.floor, string.format

local AHORRO = 120     -- segundos: menos que esto no vale la pena decirlo
local A_PIE = 7        -- yd/s, como el motor
local RODEO = 1.25     -- una línea recta no se camina: el motor le suma esto
local VUELO = 30       -- yd/s en grifo
local CURVA = 1.3      -- un vuelo no va derecho
local MONTAR = 20      -- segundos de hablar con el maestro, despegar y bajar
local POR_UN_RATO = 4  -- segundos que vale una cuenta

Gf.AHORRO = AHORRO

local function encendido() return A.Get(M.ID .. ".tomaGrifo") ~= false end
local function secreto(v) return N.Secreto and N.Secreto(v) or false end

local function enInstancia()
	if not IsInInstance then return false end
	local ok, dentro = pcall(IsInInstance)
	return ok and N.Si(dentro)
end

local function mundo(p)
	if type(p) ~= "table" then return nil end
	if p.c and p.wx and p.wy then return p.c, p.wx, p.wy end
	local Cp = M.Motor("Compat")
	if not (Cp and Cp.MapToWorld and p.map and p.x and p.y) then return nil end
	local ok, c, wx, wy = pcall(Cp.MapToWorld, p.map, p.x, p.y, p.f)
	if ok and c and type(wx) == "number" and type(wy) == "number" then return c, wx, wy end
	return nil
end

local function yardas(c1, x1, y1, c2, x2, y2)
	if not (c1 and c2) or c1 ~= c2 then return nil end
	local dx, dy = x2 - x1, y2 - y1
	return sqrt(dx * dx + dy * dy)
end

local function nombreNodo(n)
	local T = A.Nav and A.Nav.travel
	if T and type(T.TaxiName) == "function" then
		local ok, s = pcall(T.TaxiName, n, true)
		if ok and type(s) == "string" and s ~= "" and not secreto(s) then return s end
	end
	local s = type(n) == "table" and (n.short or n.name) or nil
	return type(s) == "string" and s ~= "" and (s:match("^([^,]+),") or s) or L["el maestro de vuelo"]
end

-- Lo que tardas a pie, en línea recta (como el motor). -> segundos | nil
local function aPie(desde, hasta)
	local f = A.DirectTravelCost
	if type(f) ~= "function" then return nil end
	local ok, s = pcall(f, desde, hasta)
	s = ok and tonumber(s) or nil
	if not s or s >= (A.TRAVEL_CROSS_CONTINENT or 3600) then return nil end
	return s * RODEO
end

-- La ruta del motor ya vuela: cuánto ahorra.
local function deLaRuta(legs, ci, camina)
	local primera
	for k = ci, #legs do
		local leg = legs[k]
		local tipo = type(leg) == "table" and leg.kind
		if tipo == "fly" then primera = k break end
		if tipo ~= "walk" and tipo ~= "lift" then return nil, "otraRuta" end
	end
	if not primera then return nil, "sinVuelo" end
	if primera == ci then return nil, "volando" end
	local actual = legs[ci]
	local total = (tonumber(actual.seconds) or 0) + (tonumber(actual.rest) or 0)
	local vuelo = legs[primera]
	local paradas = type(vuelo.stops) == "table" and vuelo.stops or {}
	local desde = paradas[1] or vuelo.from
	local hacia = paradas[#paradas] or vuelo.to
	return {
		nodo = nombreNodo(desde), hacia = hacia and nombreNodo(hacia) or nil,
		ahorro = camina - total, camina = camina, vuela = total,
	}
end

-- Sin la ruta del motor: los vuelos que conoces en tu continente.
local function propio(yo, destino, camina)
	local Nav = A.Nav
	if not (Nav and type(Nav.GetKnownTaxiNodes) == "function" and type(Nav.GetTravelData) == "function") then return nil, "sinDatos" end
	local okC, conocidos = pcall(Nav.GetKnownTaxiNodes)
	local okD, datos = pcall(Nav.GetTravelData)
	if not (okC and okD and type(conocidos) == "table" and type(datos) == "table" and type(datos.taxi) == "table") then return nil, "sinDatos" end
	local yc, yx, yy = mundo(yo)
	local tc, tx, ty = mundo(destino)
	if not (yc and tc) or yc ~= tc then return nil, "lejos" end
	local a, da, b, db
	for _, n in ipairs(datos.taxi) do
		if type(n) == "table" and n.id and conocidos[n.id] and n.c == yc then
			local d1 = yardas(yc, yx, yy, n.c, n.wx, n.wy)
			local d2 = yardas(tc, tx, ty, n.c, n.wx, n.wy)
			if d1 and (not da or d1 < da) then a, da = n, d1 end
			if d2 and (not db or d2 < db) then b, db = n, d2 end
		end
	end
	if not (a and b) or a == b then return nil, "sinVuelo" end
	local entre = yardas(a.c, a.wx, a.wy, b.c, b.wx, b.wy) or 0
	local total = da * RODEO / A_PIE + entre * CURVA / VUELO + MONTAR + db * RODEO / A_PIE
	local punto = a.map and a.x and a.y and { map = a.map, x = a.x, y = a.y, f = a.f } or nil
	if not punto then return nil, "sinDatos" end
	return {
		nodo = nombreNodo(a), hacia = nombreNodo(b), ahorro = camina - total, camina = camina, vuela = total,
		punto = punto, propio = true,
	}
end

local cache, cacheEn, cacheClave = nil, -1e9, nil

local function claveDe(t)
	if type(t) ~= "table" then return nil end
	return format("%s:%s:%.1f:%.1f", tostring(t.label or ""), tostring(t.map or 0), tonumber(t.x) or 0, tonumber(t.y) or 0)
end
Gf.Clave = claveDe

function Gf.Calcular()
	if not encendido() then return nil, "apagado" end
	if enInstancia() then return nil, "instancia" end
	local Nav = A.Nav
	local t = Nav and Nav.GetTarget and Nav.GetTarget()
	if type(t) ~= "table" then return nil, "sinDestino" end
	local yo = A.PlayerPoint and A.PlayerPoint()
	if type(yo) ~= "table" then return nil, "sinLugar" end
	local camina = aPie(yo, t)
	if not camina then return nil, "lejos" end
	if camina < AHORRO then return nil, "cerca" end
	local d, motivo
	local legs, ci
	if type(Nav.GetRoute) == "function" then legs, ci = Nav.GetRoute() end
	if type(legs) == "table" and #legs > 0 and ci then
		d, motivo = deLaRuta(legs, ci, camina)
		-- Una ruta de un solo camino con la del motor apagada: Alfa mira los vuelos.
		if not d and motivo == "sinVuelo" and #legs == 1 and A.Get("nav.travel") == false then d, motivo = propio(yo, t, camina) end
	elseif A.Get("nav.travel") == false then
		d, motivo = propio(yo, t, camina)
	else
		return nil, "sinRuta"
	end
	if not d then return nil, motivo end
	if d.ahorro < AHORRO then return nil, "noConviene" end
	d.clave = claveDe(t)
	d.destino = t
	return d
end

-- Guardada unos segundos (el rastreador se pinta seguido).
local function calcular()
	local ahora = GetTime and GetTime() or 0
	local Nav = A.Nav
	local clave = claveDe(Nav and Nav.GetTarget and Nav.GetTarget())
	if clave == cacheClave and ahora - cacheEn < POR_UN_RATO then return cache end
	local ok, d = pcall(Gf.Calcular)
	cache, cacheEn, cacheClave = ok and d or nil, ahora, clave
	return cache
end

function Gf.Olvidar() cache, cacheEn, cacheClave = nil, -1e9, nil end

---------------------------------------------------------------------------
-- Llevarte al maestro de vuelo
---------------------------------------------------------------------------

local callados = {} -- clave del destino -> true («Ahora no» o ya lo tomaste)
local vuelta -- { map, x, y, label, f }: tu destino de antes (modo propio)

function Gf.Llevar(d)
	if type(d) ~= "table" then return false end
	if d.clave then callados[d.clave] = true end
	local Nav = A.Nav
	if d.propio and d.punto and Nav and type(Nav.SetTarget) == "function" then
		local t = d.destino
		vuelta = type(t) == "table" and t.kind == "manual" and { map = t.map, x = t.x, y = t.y, label = t.label, f = t.f } or { guia = true }
		local ok = pcall(Nav.SetTarget, d.punto.map, d.punto.x, d.punto.y, format(L["Maestro de vuelo: %s"], d.nodo), d.punto.f)
		if not ok then vuelta = nil return false end
	end
	M.Empezar()
	M.Aviso(L["Toma el grifo"], format(L["La flecha te lleva al maestro de vuelo de %s."], d.nodo), { icono = "ic-huella" })
	if M.Rastreador and M.Rastreador.Luego then M.Rastreador.Luego() end
	return true
end

-- Al aterrizar (modo propio): la flecha vuelve a donde ibas.
-- (1.3.8 revisión) Solo si de verdad volaste: PLAYER_CONTROL_GAINED también
-- llega al pasarse un miedo o un aturdimiento camino al maestro de vuelo.
Gf.enVuelo = false
local function aterrizar(forzar)
	if not vuelta then return end
	if UnitOnTaxi and N.Si(UnitOnTaxi("player")) then return end
	if not (forzar or Gf.enVuelo) then return end
	Gf.enVuelo = false
	local v = vuelta
	vuelta = nil
	local Nav = A.Nav
	if not Nav then return end
	if v.guia then
		if type(Nav.ReleaseTarget) == "function" then pcall(Nav.ReleaseTarget) end
	elseif type(Nav.SetTarget) == "function" then
		pcall(Nav.SetTarget, v.map, v.x, v.y, v.label, v.f)
	end
end
Gf.Aterrizar = function() return aterrizar(true) end -- (a mano y en el banco)
function Gf.Vuelta() return vuelta end
local function revisarVuelo()
	if vuelta and UnitOnTaxi and N.Si(UnitOnTaxi("player")) then Gf.enVuelo = true end
end
Gf.RevisarVuelo = revisarVuelo

---------------------------------------------------------------------------
-- El aviso del rastreador (y uno flotante si el rastreador no se ve)
---------------------------------------------------------------------------

local dichos = {} -- clave -> true: el aviso flotante ya salió

local function textoDe(d)
	local titulo = format(L["Vuela desde %s: ahorras %s"], d.nodo, N.Duracion(d.ahorro, true))
	local texto = format(L["A pie son unos %s; con el vuelo, unos %s."], N.Duracion(d.camina, true), N.Duracion(d.vuela, true))
	return titulo, texto
end

function Gf.Aviso()
	local d = calcular()
	if not d or callados[d.clave] then return nil end
	local titulo, texto = textoDe(d)
	return { tono = "info", icono = "ic-huella", titulo = titulo, texto = texto,
		cerrar = function() callados[d.clave] = true end,
		uno = { L["Llévame al maestro de vuelo"], function() Gf.Llevar(d) end },
		dos = { L["Ahora no"], function()
			callados[d.clave] = true
			if M.Rastreador and M.Rastreador.Luego then M.Rastreador.Luego() end
		end } }
end

-- Sin el rastreador a la vista: un aviso, una vez por destino.
function Gf.Revisar()
	if InCombatLockdown and InCombatLockdown() then return false, "combate" end
	if M.Rastreador and M.Rastreador.Visible and M.Rastreador.Visible() then return false, "rastreador" end
	local d = calcular()
	if not d or callados[d.clave] or dichos[d.clave] then return false, "nada" end
	dichos[d.clave] = true
	local titulo, texto = textoDe(d)
	M.Aviso(titulo, texto, { icono = "ic-huella", tono = "info", duracion = 12, prioridad = 3,
		accion = { texto = L["Llévame al maestro de vuelo"], alClic = function() Gf.Llevar(d) end } })
	return true
end

-- Para el banco.
function Gf.Reiniciar() callados, dichos, vuelta = {}, {}, nil Gf.enVuelo = false Gf.Olvidar() end

local function cambio()
	Gf.Olvidar()
	if M.Rastreador and M.Rastreador.Luego then M.Rastreador.Luego() end
	A.After(1, function() pcall(Gf.Revisar) end)
end

if A.On then
	A.On("ROUTE_CHANGED", cambio)
	A.On("WAYPOINT_CHANGED", cambio)
	A.On("SETTING_CHANGED", function(ruta)
		if ruta == M.ID .. ".tomaGrifo" or ruta == "nav.travel" then cambio() end
	end)
end
A.RegisterEvent("PLAYER_CONTROL_LOST", function() revisarVuelo() A.After(0.5, revisarVuelo) end)
A.RegisterEvent("PLAYER_CONTROL_GAINED", function() A.After(1, function() aterrizar() end) end)
