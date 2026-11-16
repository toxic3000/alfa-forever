-- Alfa - La Jauría: quién es quién. Tu grupo o banda (con la API del juego) y
-- los usuarios de Alfa que aceptaron compartir su ubicación (lo que llega por
-- Red.lua). Nada más: ni la lista de la hermandad ni la de amigos.
-- Toxic / La Jauría. GPL-3.0.
--
--   G.LeerGrupo()        el grupo ahora: una fila por miembro con su posición
--   G.Oido(clave, remitente, via, datos)   un mensaje de un Alfa
--   G.Manada()           la gente a la vista para la página, ya ordenada
--   G.ParaElMapa()       lo mismo con su capa, solo quien tiene posición
--   G.PosicionDe(fila)   map, x, y, edad: dónde está alguien (o nil)
--
-- Una posición recibida caduca a los CADUCA segundos sin noticias (quien la
-- envía refresca cada 4 minutos aunque esté quieto); quien no habla en
-- OLVIDA segundos se olvida del todo. Como mucho se recuerdan MAX personas.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U = M.U
local ID = M.ID

local G = {}
M.Gente = G

G.CADUCA = 300
G.VIEJA = 60   -- una posición de más de un minuto se dice "de hace..."
local OLVIDA = 900
local MAX = 200

local alfa = {}       -- clave -> { clave, nombre, envio, via, version, map, x, y, at, oido, nivel, clase }
local cuantos = 0
local grupo = {}      -- filas del grupo, en orden
local enGrupo = {}    -- clave -> fila del grupo

G.version = 0         -- sube con cada cambio: la página y el mapa se rehacen
local function cambio() G.version = G.version + 1 end
G.Cambio = cambio

---------------------------------------------------------------------------
-- Lo que llega de los Alfa
---------------------------------------------------------------------------

-- Hace lugar para alguien nuevo: olvida a quien lleva más tiempo callado.
local function hacerLugar()
	if cuantos < MAX then return true end
	local viejo, cuando
	for clave, e in pairs(alfa) do
		if not cuando or (e.oido or 0) < cuando then viejo, cuando = clave, e.oido or 0 end
	end
	if not viejo then return false end
	alfa[viejo] = nil
	cuantos = cuantos - 1
	return true
end

function G.Oido(clave, remitente, via, d)
	local e = alfa[clave]
	if not e then
		if not hacerLugar() then return end
		e = { clave = clave }
		alfa[clave] = e
		cuantos = cuantos + 1
	end
	e.nombre = U.Mostrar(remitente)
	e.envio = remitente
	e.via = via
	e.oido = U.Ahora()
	if d.version then e.version = d.version end
	if d.map then
		e.map, e.x, e.y, e.at = d.map, d.x, d.y, U.Ahora()
		if d.nivel then e.nivel = d.nivel end
		if d.clase then e.clase = d.clase end
	end
	cambio()
end

function G.Alfa(clave) return clave and alfa[clave] end

-- Dejó de compartir (1X): su pin se va ya.
function G.Olvidar(clave)
	if clave and alfa[clave] then
		alfa[clave] = nil
		cuantos = cuantos - 1
		cambio()
	end
end

-- Borra posiciones viejas y a quien no habla hace mucho.
function G.Limpiar()
	local ahora, hubo = U.Ahora(), false
	for clave, e in pairs(alfa) do
		if e.at and ahora - e.at > G.CADUCA then
			e.map, e.x, e.y, e.at = nil, nil, nil, nil
			hubo = true
		end
		if ahora - (e.oido or 0) > OLVIDA then
			alfa[clave] = nil
			cuantos = cuantos - 1
			hubo = true
		end
	end
	if hubo then cambio() end
end

-- Al dejar de compartir: no queda nada de nadie.
function G.OlvidarTodo()
	wipe(alfa)
	cuantos = 0
	cambio()
end

---------------------------------------------------------------------------
-- Tu grupo (la API del juego: posiciones solo para tu grupo)
---------------------------------------------------------------------------

local function unidades()
	local out = {}
	local raid = IsInRaid and IsInRaid() and true or false
	if raid then
		local n = GetNumGroupMembers and U.Numero(GetNumGroupMembers()) or 0
		for i = 1, n do out[#out + 1] = "raid" .. i end
	elseif IsInGroup and IsInGroup() then
		local n = GetNumSubgroupMembers and U.Numero(GetNumSubgroupMembers()) or 0
		for i = 1, n do out[#out + 1] = "party" .. i end
	end
	return out
end

local function esYo(unit)
	if not UnitIsUnit then return false end
	local ok, v = pcall(UnitIsUnit, unit, "player")
	return ok and U.Leer(v) and true or false
end

local function leerUnidad(unit)
	local C = A.Compat
	local ok, full = pcall(C.UnitFullName, unit)
	full = ok and U.Texto(full) or nil
	if not full then return nil end
	local fila = { tipo = "grupo", unit = unit, clave = U.Clave(full), nombre = U.Mostrar(full), envio = full }
	if UnitClass then
		local _, file = UnitClass(unit)
		fila.clase = U.Texto(file)
	end
	fila.nivel = UnitLevel and U.Numero(UnitLevel(unit)) or nil
	if fila.nivel and fila.nivel <= 0 then fila.nivel = nil end
	local conectado = UnitIsConnected and U.Leer(UnitIsConnected(unit))
	fila.conectado = conectado ~= false
	fila.muerto = UnitIsDeadOrGhost and U.Leer(UnitIsDeadOrGhost(unit)) and true or false
	local map, x, y = U.PosUnidad(unit)
	if map then
		fila.map, fila.x, fila.y, fila.at = map, x, y, U.Ahora()
	end
	return fila
end

-- Lee el grupo; true si algo cambió (quién está o dónde).
function G.LeerGrupo()
	local nuevo, porClave = {}, {}
	for _, unit in ipairs(unidades()) do
		if not esYo(unit) then
			local fila = leerUnidad(unit)
			if fila and fila.clave and not porClave[fila.clave] then
				nuevo[#nuevo + 1] = fila
				porClave[fila.clave] = fila
			end
		end
	end
	local distinto = #nuevo ~= #grupo
	if not distinto then
		for i, f in ipairs(nuevo) do
			local o = grupo[i]
			if o.clave ~= f.clave or o.map ~= f.map or o.conectado ~= f.conectado or o.nivel ~= f.nivel or o.muerto ~= f.muerto
				or math.abs((o.x or 0) - (f.x or 0)) + math.abs((o.y or 0) - (f.y or 0)) > 0.05 then
				distinto = true
				break
			end
		end
	end
	grupo, enGrupo = nuevo, porClave
	if distinto then cambio() end
	return distinto
end

function G.Grupo() return grupo end
function G.EnGrupo(clave) return clave and enGrupo[clave] or nil end

-- La unidad del grupo de alguien, leída otra vez ahora (para seguir).
function G.UnidadDe(clave)
	for _, unit in ipairs(unidades()) do
		local C = A.Compat
		local ok, full = pcall(C.UnitFullName, unit)
		full = ok and U.Texto(full) or nil
		if full and U.Clave(full) == clave then return unit end
	end
	return nil
end

---------------------------------------------------------------------------
-- Juntar: lo que se sabe de cada persona
---------------------------------------------------------------------------

-- Dónde está alguien: map, x, y y hace cuánto se supo; nil si no se sabe o
-- caducó. Para el grupo manda la API del juego.
function G.PosicionDe(fila)
	if not fila then return nil end
	local g = enGrupo[fila.clave]
	if g and g.map then return g.map, g.x, g.y, U.Ahora() - (g.at or U.Ahora()) end
	local e = alfa[fila.clave]
	if e and e.map and e.at then
		local edad = U.Ahora() - e.at
		if edad <= G.CADUCA then return e.map, e.x, e.y, edad end
	end
	return nil
end

-- Una fila lista para mostrar: dónde, a qué distancia, de hace cuánto.
local function completar(f)
	local e = alfa[f.clave]
	f.alfa = e ~= nil
	if e then
		f.nivel = f.nivel or e.nivel
		f.clase = f.clase or e.clase
	end
	local map, x, y, edad = G.PosicionDe(f)
	f.map, f.x, f.y, f.edad = map, x, y, edad
	f.dist, f.otro, f.zona = nil, nil, nil
	if map then
		f.zona = U.NombreMapa(U.ZonaDe(map))
		local yd, otro = U.Distancia(map, x, y)
		f.dist, f.otro = yd, otro == "otro" or nil
	end
	return f
end

-- La gente a la vista: tu grupo (siempre) y quienes comparten con posición
-- fresca. Nadie sale dos veces. Orden: a quien sigues, luego por distancia
-- (los de otro continente y sin posición al final), y por nombre.
function G.Manada()
	local out, puesto = {}, {}
	for _, f in ipairs(grupo) do
		local fila = {}
		for k, v in pairs(f) do fila[k] = v end
		out[#out + 1] = completar(fila)
		puesto[f.clave] = true
	end
	if N.Get(ID, "compartir") then
		local ahora = U.Ahora()
		for clave, e in pairs(alfa) do
			if not puesto[clave] and e.map and e.at and ahora - e.at <= G.CADUCA then
				out[#out + 1] = completar({
					tipo = "manada", clave = clave, nombre = e.nombre, envio = e.envio,
					nivel = e.nivel, clase = e.clase, conectado = true, via = e.via,
				})
				puesto[clave] = true
			end
		end
	end
	local S = M.Seguir
	local sigue = S and S.Actual()
	local sclave = sigue and sigue.clave
	table.sort(out, function(a, b)
		local sa, sb = a.clave == sclave, b.clave == sclave
		if sa ~= sb then return sa end
		local da, db = a.dist ~= nil, b.dist ~= nil
		if da ~= db then return da end
		if da and a.dist ~= b.dist then return a.dist < b.dist end
		local ma, mb = a.map ~= nil, b.map ~= nil
		if ma ~= mb then return ma end
		return (a.nombre or "") < (b.nombre or "")
	end)
	return out
end

-- Para el mapa: { capa = "grupo" | "manada", fila } de quien tiene posición.
function G.ParaElMapa()
	local out = {}
	for _, f in ipairs(G.Manada()) do
		if f.map then out[#out + 1] = { capa = f.tipo == "grupo" and "grupo" or "manada", fila = f } end
	end
	return out
end

-- Cuántos se ven: de la manada (sin tu grupo) y de tu grupo.
function G.Cuentas()
	local manada, enElGrupo = 0, #grupo
	if N.Get(ID, "compartir") then
		local ahora = U.Ahora()
		for clave, e in pairs(alfa) do
			if not enGrupo[clave] and e.map and e.at and ahora - e.at <= G.CADUCA then manada = manada + 1 end
		end
	end
	return manada, enElGrupo
end
