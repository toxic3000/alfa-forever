-- Alfa - Inicio: la sesión actual y el diario de sesiones (Toxic / La Jauría). GPL-3.0.
--
-- Una sesión va desde que entras con el personaje hasta que sales: un /reload
-- no la corta (PLAYER_ENTERING_WORLD dice si es la primera entrada o una
-- recarga; si el cliente no lo dice, una sesión vista hace menos de
-- S.SEGUIR segundos sigue). Todo se guarda por personaje en
-- N.DatosPersonaje("inicio"):
--   actual   = { inicio, visto, nivel0, nivel, xp, oro0, oro, ganado, gastado,
--                misiones, niveles, muertes }
--   sesiones = { { inicio, fin, dur, xp, oro, ganado, gastado, misiones,
--                  niveles, muertes, nivel0, nivel }, ... }  (la más nueva al final)
--
-- La XP ganada sale del contador del motor (Alfa.QoL.XP: sessionXP, que ya
-- separa las subidas de nivel) sumado a lo que la sesión traía antes de la
-- recarga; la XP por hora y el tiempo para subir son los del motor (ritmo de
-- los últimos 15 minutos). Sin el motor, se cuenta con UnitXP.
--
--   M.Sesion.Estado() -> tabla reutilizada (léela, no la guardes)
--   M.Sesion.Sesiones() -> la lista del diario
--   M.Sesion.Texto(s) -> "1 h 20 min · +12,340 XP · 8 misiones · ..."
--   M.Sesion.Cuando(ts) -> "hoy a las 18:30" / "ayer a las 22:10" / "el 12/11 a las 21:00"
--   mensaje INICIO_DIARIO cuando el diario cambia

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

local type, tonumber, floor, max, min, format = type, tonumber, math.floor, math.max, math.min, string.format

local S = {}
M.Sesion = S

S.MIN_GUARDAR = 120 -- segundos: una sesión más corta y sin nada ganado no se guarda
S.SEGUIR = 600      -- sin datos del cliente, una sesión vista hace menos que esto sigue
S.VISTO_CADA = 30   -- cada cuánto se anota que la sesión sigue viva

-- Un número del cliente: nil si es secreto o no es número.
local function num(v)
	if v == nil then return nil end
	if issecretvalue and issecretvalue(v) then return nil end
	return tonumber(v)
end
M.num = num

-- Un texto del cliente: nil si es secreto o no es texto.
local function texto(v)
	if v == nil then return nil end
	if issecretvalue and issecretvalue(v) then return nil end
	return type(v) == "string" and v or nil
end
M.texto = texto

-- 1234567 -> "1,234,567"
local function miles(n)
	n = floor((tonumber(n) or 0) + 0.5)
	local signo = n < 0 and "-" or ""
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return signo .. out
end
M.miles = miles

local function ahora() return time() end
local function db() return N.DatosPersonaje("inicio") end
local function nivel() return num(UnitLevel and UnitLevel("player")) end
local function dinero() return num(GetMoney and GetMoney()) end

local function nueva()
	local m = dinero() or 0
	local lv = nivel()
	return {
		inicio = ahora(), visto = ahora(), nivel0 = lv, nivel = lv, xp = 0,
		oro0 = m, oro = m, ganado = 0, gastado = 0, misiones = 0, niveles = 0, muertes = 0,
	}
end

function S.Actual()
	local d = db()
	if type(d.actual) ~= "table" then d.actual = nueva() end
	return d.actual
end

function S.Sesiones()
	local d = db()
	if type(d.sesiones) ~= "table" then d.sesiones = {} end
	return d.sesiones
end

function S.Borrar()
	db().sesiones = {}
	A.Fire("INICIO_DIARIO")
end

---------------------------------------------------------------------------
-- XP: el contador del motor
---------------------------------------------------------------------------

local function statsMotor()
	local Q = A.QoL
	local X = type(Q) == "table" and Q.XP
	if type(X) ~= "table" or type(X.GetStats) ~= "function" then return nil end
	local ok, st = pcall(X.GetStats)
	if ok and type(st) == "table" then return st end
	return nil
end
S.StatsMotor = statsMotor

local motorPrev     -- sessionXP del motor la última vez que se leyó
local propio = {}   -- sin el motor: { nivel, xp, max } de la última lectura

local function leerPropio()
	propio.nivel = nivel()
	propio.xp = num(UnitXP and UnitXP("player"))
	propio.max = num(UnitXPMax and UnitXPMax("player"))
end

local function sumarXP()
	local a = S.Actual()
	local st = statsMotor()
	local sx = st and num(st.sessionXP)
	if sx then
		if motorPrev == nil then
			motorPrev = sx
			return
		end
		local d = sx - motorPrev
		if d < 0 then d = sx end -- el motor reinició su sesión
		motorPrev = sx
		if d > 0 then a.xp = (num(a.xp) or 0) + d end
		return
	end
	local lv = nivel()
	local xp = num(UnitXP and UnitXP("player"))
	local mx = num(UnitXPMax and UnitXPMax("player"))
	if not (lv and xp and mx) then return end
	if propio.nivel and propio.xp and propio.max then
		local d
		if lv > propio.nivel or xp < propio.xp then
			d = max(0, propio.max - propio.xp) + xp
		else
			d = xp - propio.xp
		end
		if d > 0 then a.xp = (num(a.xp) or 0) + d end
	end
	propio.nivel, propio.xp, propio.max = lv, xp, mx
end

---------------------------------------------------------------------------
-- Cerrar y empezar sesiones
---------------------------------------------------------------------------

-- La sesión `a` al diario; nil si fue tan corta que no vale la pena.
local function cerrar(a)
	if type(a) ~= "table" or not num(a.inicio) then return nil end
	local fin = num(a.visto) or a.inicio
	local dur = max(0, fin - a.inicio)
	local xp, mis, nv = num(a.xp) or 0, num(a.misiones) or 0, num(a.niveles) or 0
	if dur < S.MIN_GUARDAR and xp == 0 and mis == 0 and nv == 0 then return nil end
	local s = {
		inicio = a.inicio, fin = fin, dur = dur, xp = xp,
		oro = (num(a.oro) or 0) - (num(a.oro0) or 0),
		ganado = num(a.ganado) or 0, gastado = num(a.gastado) or 0,
		misiones = mis, niveles = nv, muertes = num(a.muertes) or 0,
		nivel0 = num(a.nivel0), nivel = num(a.nivel),
	}
	local list = S.Sesiones()
	list[#list + 1] = s
	local keep = tonumber(N.Get("inicio", "diarioMax")) or 30
	while #list > keep do table.remove(list, 1) end
	return s
end

-- Recorta el diario al tamaño elegido (al cambiar el ajuste).
function S.Recortar()
	local list = S.Sesiones()
	local keep = tonumber(N.Get("inicio", "diarioMax")) or 30
	local cut = false
	while #list > keep do
		table.remove(list, 1)
		cut = true
	end
	if cut then A.Fire("INICIO_DIARIO") end
end

local empezado = false
local ticker

function S.Empezada() return empezado end

local function mostrarResumen(s)
	local modo = N.Get("inicio", "resumen")
	if modo == "no" or A.Hidden() then return end
	local cuando = S.Cuando(s.inicio)
	local txt = S.Texto(s)
	if modo == "chat" or modo == "ambos" then
		N.Imprimir(format(L["Tu sesión anterior (%s): %s"], cuando, txt))
	end
	if (modo == "aviso" or modo == "ambos") and M.Aviso then
		M.Aviso.Mostrar({
			clave = "resumen", tipo = "info", icono = "hourglass",
			titulo = L["¡De vuelta con la manada!"],
			linea = format(L["Tu sesión anterior, %s"], cuando),
			texto = txt, segundos = 14,
			botones = { { texto = L["Ver mi diario"], fn = function() N.Abrir("inicio") end } },
		})
	end
end

local function empezar(inicial, recarga)
	if empezado then return end
	empezado = true
	local d = db()
	local a = d.actual
	local seguir
	if recarga == true then
		seguir = type(a) == "table"
	elseif inicial == true then
		seguir = false
	else
		seguir = type(a) == "table" and num(a.visto) ~= nil and ahora() - a.visto < S.SEGUIR
	end
	local previa
	if not seguir then
		previa = cerrar(a)
		d.actual = nueva()
	end
	a = S.Actual()
	a.visto = ahora()
	if not num(a.oro) then a.oro = dinero() or 0 end
	if not num(a.oro0) then a.oro0 = a.oro end
	a.nivel = nivel() or a.nivel
	-- Desde aquí se cuenta: lo que el motor ya traía no es de esta sesión.
	local st = statsMotor()
	motorPrev = st and num(st.sessionXP) or nil
	leerPropio()
	if not ticker then
		ticker = A.NewTicker(S.VISTO_CADA, function()
			if empezado then S.Actual().visto = ahora() end
		end)
	end
	if previa then
		A.Fire("INICIO_DIARIO")
		A.After(8, function() mostrarResumen(previa) end)
	end
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, inicial, recarga)
	empezar(inicial, recarga)
end)

A.RegisterEvent("PLAYER_XP_UPDATE", function(_, unit)
	if empezado and (unit == nil or unit == "player") then sumarXP() end
end)

A.RegisterEvent("PLAYER_MONEY", function()
	if not empezado then return end
	local a = S.Actual()
	local m = dinero()
	if not m then return end
	local prev = num(a.oro) or m
	local d = m - prev
	if d > 0 then
		a.ganado = (num(a.ganado) or 0) + d
	elseif d < 0 then
		a.gastado = (num(a.gastado) or 0) - d
	end
	a.oro = m
end)

A.RegisterEvent("QUEST_TURNED_IN", function()
	if not empezado then return end
	local a = S.Actual()
	a.misiones = (num(a.misiones) or 0) + 1
end)

A.RegisterEvent("PLAYER_LEVEL_UP", function(_, lv)
	if not empezado then return end
	local a = S.Actual()
	a.niveles = (num(a.niveles) or 0) + 1
	a.nivel = num(lv) or nivel() or a.nivel
end)

A.RegisterEvent("PLAYER_DEAD", function()
	if not empezado then return end
	local a = S.Actual()
	a.muertes = (num(a.muertes) or 0) + 1
end)

A.RegisterEvent("PLAYER_LOGOUT", function()
	if empezado then S.Actual().visto = ahora() end
end)

A.On("SETTING_CHANGED", function(path)
	if path == "inicio.diarioMax" then S.Recortar() end
end)

---------------------------------------------------------------------------
-- Lo que muestran la página y el chat
---------------------------------------------------------------------------

local estado = {}

-- La sesión de ahora, con el ritmo del motor. Una tabla reutilizada.
function S.Estado()
	local a = S.Actual()
	local t = ahora()
	local e = estado
	e.inicio = num(a.inicio) or t
	e.dur = max(0, t - e.inicio)
	e.xp = num(a.xp) or 0
	e.prom = e.dur >= 60 and e.xp / e.dur * 3600 or 0
	local m = dinero() or num(a.oro) or 0
	e.oro = m - (num(a.oro0) or m)
	e.ganado, e.gastado = num(a.ganado) or 0, num(a.gastado) or 0
	e.misiones, e.niveles, e.muertes = num(a.misiones) or 0, num(a.niveles) or 0, num(a.muertes) or 0
	e.nivel0 = num(a.nivel0)

	local st = statsMotor()
	local lv = nivel() or 1
	local xpNow = num(UnitXP and UnitXP("player")) or 0
	local xpMax = num(UnitXPMax and UnitXPMax("player")) or 0
	local rested = num(GetXPExhaustion and GetXPExhaustion()) or 0
	local maxLv = num(GetMaxPlayerLevel and GetMaxPlayerLevel())
	e.nivel, e.xpAhora, e.xpMax, e.descanso = lv, xpNow, xpMax, rested
	e.maximo = xpMax <= 0 or (maxLv ~= nil and lv >= maxLv)
	e.falta = e.maximo and 0 or max(0, xpMax - xpNow)
	e.ritmo, e.subir, e.motor = nil, nil, st ~= nil
	if st then
		local rate = num(st.rate)
		if rate and rate > 0 then e.ritmo = rate end
		e.subir = num(st.timeToLevel)
		if st.maxed == true then e.maximo = true end
	end
	if not e.ritmo and e.prom > 0 then e.ritmo = e.prom end
	if not e.subir and not e.maximo and e.ritmo and e.ritmo > 0 then e.subir = e.falta / e.ritmo * 3600 end
	return e
end

-- Una sesión del diario (o la de ahora) en una línea corta.
function S.Texto(s)
	local parts = { N.Duracion(s.dur or 0) }
	local xp = tonumber(s.xp) or 0
	if xp > 0 then parts[#parts + 1] = "+" .. miles(xp) .. " XP" end
	local nv = tonumber(s.niveles) or 0
	if nv > 0 then parts[#parts + 1] = nv == 1 and L["1 nivel"] or format(L["%d niveles"], nv) end
	local mis = tonumber(s.misiones) or 0
	if mis > 0 then parts[#parts + 1] = mis == 1 and L["1 misión"] or format(L["%d misiones"], mis) end
	local oro = tonumber(s.oro) or 0
	if oro ~= 0 then parts[#parts + 1] = (oro > 0 and "+" or "") .. N.Dinero(oro) end
	local mu = tonumber(s.muertes) or 0
	if mu > 0 then parts[#parts + 1] = mu == 1 and L["1 muerte"] or format(L["%d muertes"], mu) end
	return table.concat(parts, "  \194\183  ")
end

local function mismoDia(a, b) return a.year == b.year and a.yday == b.yday end

function S.Cuando(ts)
	ts = tonumber(ts) or ahora()
	local t = date("*t", ts)
	local hora = format("%02d:%02d", t.hour, t.min)
	if mismoDia(t, date("*t", ahora())) then return format(L["hoy a las %s"], hora) end
	if mismoDia(t, date("*t", ahora() - 86400)) then return format(L["ayer a las %s"], hora) end
	return format(L["el %d/%d a las %s"], t.day, t.month, hora)
end

-- "14/11" (o "Hoy") para las etiquetas de la gráfica.
function S.Dia(ts)
	ts = tonumber(ts) or ahora()
	local t = date("*t", ts)
	if mismoDia(t, date("*t", ahora())) then return L["Hoy"] end
	return format("%d/%d", t.day, t.month)
end

-- /alfa sesion: la sesión de ahora en el chat.
A.RegisterCommand("sesion", function()
	local e = S.Estado()
	N.Imprimir(format(L["Esta sesión: %s"], S.Texto(e)))
	if e.ritmo and e.ritmo > 0 then
		local subir = e.subir and N.Duracion(e.subir) or "?"
		N.Imprimir(format(L["Ritmo: %s XP por hora; subes de nivel en %s."], miles(e.ritmo), subir))
	end
end, L["tu sesión de ahora en el chat"], true)
