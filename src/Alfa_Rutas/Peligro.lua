-- Alfa - Rutas: «Zona peligrosa» (toxic3000 / La Jauría). GPL-3.0.
-- 1.2.8
--
-- Al entrar a una zona cuyos enemigos están muy por encima de ti (su nivel
-- más bajo es el tuyo + 4 o más, la misma regla del motor en Nav/Danger.lua),
-- un aviso corto una vez por zona y sesión: «Cuidado: aquí los enemigos son
-- nivel 30–35». Los niveles son los del motor (Maps.GetZoneLevels, solo se
-- leen) y, si faltan, los del cliente (C_Map.GetMapLevels). Una subzona sin
-- niveles propios toma los de su zona. Nunca en instancias ni en combate (lo
-- de una pelea se dice al terminarla). Ajuste rutas.zonaPeligrosa.
--
--   Peligro.Revisar() -> dijo, por qué   lo mira ahora (el banco lo llama)
--   Peligro.Niveles(uiMapID) -> min, max, uiMapID de la zona | nil

local ADDON, M = ...
local A, L = M.A, M.L
local N = M.N
local Pg = {}
M.Peligro = Pg

A.RegisterDefaults(M.ID, { zonaPeligrosa = true })

local type, tonumber, pcall = type, tonumber, pcall
local format = string.format

local ARRIBA = 4  -- niveles: la zona empieza así de arriba del tuyo
local SUBIR = 6   -- cuántos mapas padre se miran (subzona -> zona)

local function enCombate() return InCombatLockdown and InCombatLockdown() or false end
local function secreto(v) return issecretvalue and issecretvalue(v) or false end

local function num(v)
	if secreto(v) then return nil end
	v = tonumber(v)
	return v and v > 0 and v or nil
end

local dichas = {}  -- uiMapID de zona -> true (esta sesión)
local esperaAnuncio = {} -- uiMapID -> true: se espera a ver si salió el anuncio de zona (1.3.8 revisión)
local esperando = false -- llegó en combate: se mira al terminar

local function nivelesDe(id)
	local Mp = A.Maps
	if Mp and type(Mp.GetZoneLevels) == "function" then
		local ok, lo, hi = pcall(Mp.GetZoneLevels, id)
		lo, hi = ok and num(lo), ok and num(hi)
		if lo and hi then return lo, hi end
	end
	local f = C_Map and C_Map.GetMapLevels
	if type(f) == "function" then
		local ok, lo, hi = pcall(f, id)
		lo, hi = ok and num(lo), ok and num(hi)
		if lo and hi and hi >= lo then return lo, hi end
	end
	return nil
end

function Pg.Niveles(id)
	id = num(id)
	for _ = 1, SUBIR do
		if not id then return nil end
		local lo, hi = nivelesDe(id)
		if lo then return lo, hi, id end
		local info = C_Map and C_Map.GetMapInfo and select(2, pcall(C_Map.GetMapInfo, id))
		id = type(info) == "table" and num(info.parentMapID) or nil
	end
	return nil
end

local function mapaJugador()
	local f = C_Map and C_Map.GetBestMapForUnit
	if type(f) ~= "function" then return nil end
	local ok, id = pcall(f, "player")
	return ok and num(id) or nil
end

local function enInstancia()
	if not IsInInstance then return false end
	local ok, dentro = pcall(IsInInstance)
	return ok and N.Si(dentro) -- 1.3.7: secretos
end

local function nivelJugador()
	local ok, n = pcall(UnitLevel, "player")
	return ok and num(n) or nil
end

local function nombreZona(id)
	local n = M.Zona(id)
	if n then return n end
	local f = rawget(_G, "GetZoneText")
	local ok, z = false, nil
	if type(f) == "function" then ok, z = pcall(f) end
	if ok and type(z) == "string" and not secreto(z) and z ~= "" then return z end
	return L["Esta zona"]
end

function Pg.Revisar()
	if A.Get(M.ID .. ".zonaPeligrosa") == false then return false, "apagado" end
	if enInstancia() then return false, "instancia" end
	if enCombate() then esperando = true return false, "combate" end
	esperando = false
	local nivel = nivelJugador()
	local lo, hi, zona = Pg.Niveles(mapaJugador())
	if not (nivel and lo) then return false, "sinDatos" end
	if dichas[zona] then return false, "dicha" end
	if lo < nivel + ARRIBA then return false, "segura" end
	-- (1.3.8 revisión) El anuncio de zona apartó el suceso: se espera a ver si
	-- sale. Si se pierde (combate, caduca), Zonas.lua lo olvida y a la vuelta
	-- este aviso sí lo dice; si salió, ya está dicho.
	local Zs0 = N and N.Zonas
	local suc = Zs0 and Zs0.SucesoPeligro and Zs0.SucesoPeligro(nombreZona(zona))
	if suc and N.SucesoDicho and N.SucesoDicho(suc, 600) then
		if not esperaAnuncio[zona] then
			esperaAnuncio[zona] = true
			N.Una("rutas.peligro.anuncio", 40, function() pcall(Pg.Revisar) end)
			return false, "anuncio"
		end
		esperaAnuncio[zona] = nil
		dichas[zona] = true
		return false, "dicha"
	end
	esperaAnuncio[zona] = nil
	dichas[zona] = true
	local rango = lo == hi and tostring(lo) or (lo .. "–" .. hi)
	-- 1.3.3: con salida: la guía que mejor te queda (Siguiente.lua) te lleva.
	local o = { icono = "ic-aviso", tono = "aviso", duracion = 12 }
	-- 1.3.8: un solo aviso por zona peligrosa: si el anuncio de zona ya lo
	-- dijo en grande (Alfa_Nucleo/Zonas.lua), este se calla.
	local Zs = N and N.Zonas
	if Zs and Zs.SucesoPeligro then o.suceso, o.ventana = Zs.SucesoPeligro(nombreZona(zona)), 600 end
	if M.Siguiente and M.Siguiente.Buscar then
		o.accion = { texto = L["Llévame a una zona de tu nivel"], alClic = function() Pg.Salida() end }
	end
	M.Aviso(nombreZona(zona), format(L["Cuidado: aquí los enemigos son nivel %s."], rango), o)
	return true, "aviso"
end

-- 1.3.3: la guía para tu nivel que sugiere el motor (la de tu zona no:
-- es la peligrosa), abierta como cualquier guía: la flecha te lleva.
function Pg.Salida()
	local Sg = M.Siguiente
	local E = A.Engine
	local actual = E and E.GetGuide and E.GetGuide()
	local p = Sg and Sg.Buscar(type(actual) == "table" and actual.id or nil)
	if not p then
		M.Aviso(L["Zona peligrosa"], L["No encontré una guía para tu nivel: abre la biblioteca de guías."], { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	Sg.Seguir(p)
	M.Aviso(L["Zona peligrosa"], format(L["Vamos a una zona de tu nivel: %s."], p.nombre), { icono = "ic-huella" })
	return true
end

-- Para el banco.
function Pg.Reiniciar() dichas, esperando, esperaAnuncio = {}, false, {} end

-- 1.3.8: el anuncio de zona peligrosa ofrece esta misma salida con un clic.
if N then N.SalidaPeligro = function() return Pg.Salida() end end

local pendiente = false
local function pronto(seg)
	if pendiente then return end
	pendiente = true
	A.After(seg or 2, function()
		pendiente = false
		pcall(Pg.Revisar)
	end)
end

---------------------------------------------------------------------------
-- 1.3.8: antes de llegar. La flecha mira tu camino (las piernas a pie de la
-- ruta del motor, Nav.GetRoute; sin ruta, la línea recta a tu destino) cada
-- MUESTRA yardas, y si pasa por una zona peligrosa para tu nivel (la misma
-- regla de arriba) que no es en la que estás, el rastreador lo dice antes de
-- entrar: «Tu camino pasa por Bosque del Ocaso» o «Tu destino está en...».
-- Los vuelos no cuentan (no te tocan). La zona de un punto: la del motor
-- (Nav.danger.ZoneAt, el mapa de caminos) o, sin ella, la del planificador
-- (Nav.travel.ZoneOf). Se mira una vez por destino y versión de la ruta, y
-- solo al pintar el rastreador. «Entendido» lo calla para ese destino. Sin
-- el rastreador a la vista, un aviso una vez por zona y sesión. Ajuste
-- rutas.peligroCamino.
--
--   Peligro.Camino() -> { zona, nombre, rango, destino = bool } | nil, motivo
--   Peligro.AvisoCamino() -> el aviso del rastreador | nil
---------------------------------------------------------------------------

A.RegisterDefaults(M.ID, { peligroCamino = true })

local MUESTRA = 150   -- yardas entre los puntos que se miran
local MUESTRAS = 90   -- puntos como mucho por camino
local sqrt, ceil, floor = math.sqrt, math.ceil, math.floor

local function zonaEn(c, wx, wy)
	local Nav = A.Nav
	local D = Nav and Nav.danger
	if D and type(D.ZoneAt) == "function" then
		local ok, z = pcall(D.ZoneAt, c, wx, wy)
		if ok and num(z) then return num(z) end
	end
	local T = Nav and Nav.travel
	if T and type(T.ZoneOf) == "function" then
		local ok, z = pcall(T.ZoneOf, nil, c, wx, wy)
		if ok and num(z) then return num(z) end
	end
	return nil
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

-- Los tramos a pie que quedan: { { c, x1, y1, x2, y2 }, ... }
local function tramos(yo, destino)
	local out = {}
	local Nav = A.Nav
	local legs, ci
	if Nav and type(Nav.GetRoute) == "function" then legs, ci = Nav.GetRoute() end
	local yc, yx, yy = mundo(yo)
	if type(legs) == "table" and ci and legs[ci] then
		for k = ci, #legs do
			local leg = legs[k]
			if type(leg) == "table" and leg.kind == "walk" then
				local ac, ax, ay
				if k == ci then ac, ax, ay = yc, yx, yy else ac, ax, ay = mundo(leg.from) end
				local bc, bx, by = mundo(leg.to)
				if ac and bc and ac == bc then out[#out + 1] = { ac, ax, ay, bx, by } end
			end
		end
		return out
	end
	local tc, tx, ty = mundo(destino)
	if yc and tc and yc == tc then out[1] = { yc, yx, yy, tx, ty } end
	return out
end

local camino = { clave = nil, r = nil }

local function nombreDe(zona) return M.Zona(zona) or L["Una zona peligrosa"] end

local function claveCamino(t)
	local T = A.Nav and A.Nav.travel
	return format("%s:%s:%s:%s:%s", tostring(t.label or ""), tostring(t.map or 0), tostring(t.x or 0), tostring(t.y or 0),
		tostring(T and T.version or 0))
end

function Pg.Camino()
	if A.Get(M.ID .. ".peligroCamino") == false then return nil, "apagado" end
	if enInstancia() then return nil, "instancia" end
	local Nav = A.Nav
	local t = Nav and Nav.GetTarget and Nav.GetTarget()
	if type(t) ~= "table" then return nil, "sinDestino" end
	local nivel = nivelJugador()
	if not nivel then return nil, "sinDatos" end
	local _, _, aqui = Pg.Niveles(mapaJugador())
	local clave = claveCamino(t) .. ":" .. nivel .. ":" .. tostring(aqui)
	if camino.clave == clave then return camino.r, camino.por end
	local yo = A.PlayerPoint and A.PlayerPoint()
	local r, por = nil, "segura"
	local _, _, zonaDestino = Pg.Niveles(t.map)
	local vistas, n = {}, 0
	for _, s in ipairs(tramos(yo, t)) do
		local c, x1, y1, x2, y2 = s[1], s[2], s[3], s[4], s[5]
		local dx, dy = x2 - x1, y2 - y1
		local pasos = ceil(sqrt(dx * dx + dy * dy) / MUESTRA)
		for i = 1, pasos do
			if n >= MUESTRAS then break end
			n = n + 1
			local f = i / pasos
			local z = zonaEn(c, x1 + dx * f, y1 + dy * f)
			if z and not vistas[z] then
				vistas[z] = true
				local lo, hi, zona = Pg.Niveles(z)
				if lo and zona ~= aqui and not vistas["z" .. zona] then
					vistas["z" .. zona] = true
					if lo >= nivel + ARRIBA then
						r = { zona = zona, nombre = nombreDe(zona), rango = lo == hi and tostring(lo) or (lo .. "–" .. hi), destino = zona == zonaDestino }
						break
					end
				end
			end
		end
		if r then break end
	end
	-- El destino mismo (sin camino que mirar o si no salió en él).
	if not r and zonaDestino and zonaDestino ~= aqui then
		local lo, hi = Pg.Niveles(zonaDestino)
		if lo and lo >= nivel + ARRIBA then
			r = { zona = zonaDestino, nombre = nombreDe(zonaDestino), rango = lo == hi and tostring(lo) or (lo .. "–" .. hi), destino = true }
		end
	end
	if r then por = "peligro" end
	camino.clave, camino.r, camino.por = clave, r, por
	return r, por
end

local calladas = {} -- destino -> true («Entendido»)
local dichasCamino = {} -- zona -> true: el aviso flotante ya salió

local function textoCamino(r)
	local titulo = r.destino and format(L["Tu destino está en %s"], r.nombre) or format(L["Tu camino pasa por %s"], r.nombre)
	return titulo, format(L["Ahí los enemigos son nivel %s: ve con cuidado o con la manada."], r.rango)
end

function Pg.AvisoCamino()
	local r = Pg.Camino()
	if not r then return nil end
	local t = A.Nav and A.Nav.GetTarget and A.Nav.GetTarget()
	local clave = type(t) == "table" and claveCamino(t) .. ":" .. r.zona or nil
	if clave and calladas[clave] then return nil end
	local titulo, texto = textoCamino(r)
	return { tono = "aviso", icono = "ic-aviso", titulo = titulo, texto = texto,
		cerrar = function() if clave then calladas[clave] = true end end,
		uno = { L["Entendido"], function()
			if clave then calladas[clave] = true end
			if M.Rastreador and M.Rastreador.Luego then M.Rastreador.Luego() end
		end } }
end

-- Sin el rastreador a la vista: un aviso, una vez por zona en la sesión.
function Pg.RevisarCamino()
	if enCombate() then return false, "combate" end
	if M.Rastreador and M.Rastreador.Visible and M.Rastreador.Visible() then return false, "rastreador" end
	local r = Pg.Camino()
	if not r or dichasCamino[r.zona] or dichas[r.zona] then return false, "nada" end
	dichasCamino[r.zona] = true
	local titulo, texto = textoCamino(r)
	M.Aviso(titulo, texto, { icono = "ic-aviso", tono = "aviso", duracion = 12, donde = "rastreador" })
	return true
end

function Pg.ReiniciarCamino() camino, calladas, dichasCamino = { clave = nil }, {}, {} end

if A.On then
	A.On("ROUTE_CHANGED", function()
		A.After(1.5, function() pcall(Pg.RevisarCamino) end)
	end)
	A.On("WAYPOINT_CHANGED", function()
		A.After(1.5, function() pcall(Pg.RevisarCamino) end)
	end)
end

A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() pronto(2) end)
A.RegisterEvent("ZONE_CHANGED", function() pronto(2) end)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() pronto(4) end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() if esperando then pronto(2) end end)
