-- Alfa - La Jauría: quién es quién. Tu grupo (con la API del juego), tu
-- hermandad (su lista), tus amigos (su lista) y lo que llega de los Alfa que
-- comparten (Red.lua). Toxic / La Jauría. GPL-3.0.
--
--   G.LeerGrupo()        el grupo ahora: una fila por miembro con su posición
--   G.Hermandad(), G.Amigos(), G.Grupo()   las listas para la página
--   G.Oido(clave, remitente, via, datos)   un mensaje de un Alfa
--   G.PosicionDe(fila)   map, x, y, edad: dónde está alguien (o nil)
--
-- Una posición recibida caduca a los CADUCA segundos sin noticias (el que la
-- envía refresca cada 4 minutos aunque esté quieto). Quien dejó de hablar
-- más de OLVIDA segundos se olvida del todo. La última vez que viste a cada
-- miembro de la hermandad se guarda por cuenta (N.Datos("manada").visto),
-- para decir "hace cuánto lo viste" entre sesiones.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U = M.U
local ID = M.ID

local G = {}
M.Gente = G

G.CADUCA = 300
G.VIEJA = 60   -- una posición de más de un minuto se dibuja tenue
local OLVIDA = 3600
local VISTO_DIAS = 90

local alfa = {}       -- clave -> lo oído de un Alfa: { clave, nombre, envio, via = {}, version, comparte, map, x, y, nivel, clase, at, oido }
local hermandad = {}  -- clave -> fila de la lista de la hermandad
local amigos = {}     -- clave -> fila de la lista de amigos (conectados y no)
local grupo = {}      -- filas del grupo, en orden
local enGrupo = {}    -- clave -> fila del grupo

G.version = 0         -- sube con cada cambio: la página y el mapa se rehacen
local function cambio() G.version = G.version + 1 end
G.Cambio = cambio

---------------------------------------------------------------------------
-- Lo que llega de los Alfa
---------------------------------------------------------------------------

function G.Oido(clave, remitente, via, d)
	local e = alfa[clave]
	if not e then
		e = { clave = clave, via = {} }
		alfa[clave] = e
	end
	e.nombre = U.Mostrar(remitente)
	e.envio = remitente
	e.via[via] = true
	e.oido = U.Ahora()
	if d.version then e.version = d.version end
	if d.comparte ~= nil then e.comparte = d.comparte end
	if d.quitar then
		e.map, e.x, e.y, e.at = nil, nil, nil, nil
	elseif d.map then
		e.map, e.x, e.y, e.at = d.map, d.x, d.y, U.Ahora()
		if d.nivel then e.nivel = d.nivel end
		if d.clase then e.clase = d.clase end
	end
	if via == "hermandad" then G.Visto(clave, e.nombre) end
	cambio()
end

function G.Alfa(clave) return clave and alfa[clave] end

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
			hubo = true
		end
	end
	if hubo then cambio() end
end

-- Al salir de la hermandad o apagar la red: se olvida lo oído por ese medio.
function G.OlvidarVia(via)
	for clave, e in pairs(alfa) do
		e.via[via] = nil
		if not next(e.via) then alfa[clave] = nil end
	end
	cambio()
end

function G.OlvidarTodo()
	wipe(alfa)
	cambio()
end

---------------------------------------------------------------------------
-- "Hace cuánto lo viste" (guardado por cuenta)
---------------------------------------------------------------------------

local function vistos()
	local d = N.Datos(ID)
	d.visto = type(d.visto) == "table" and d.visto or {}
	return d.visto
end

function G.Visto(clave, nombre)
	if not clave then return end
	local v = vistos()
	local e = v[clave]
	if type(e) ~= "table" then
		e = {}
		v[clave] = e
	end
	e.t = U.Reloj()
	if nombre then e.n = nombre end
end

function G.VistoHace(clave)
	local e = clave and vistos()[clave]
	if type(e) ~= "table" or type(e.t) ~= "number" then return nil end
	return math.max(0, U.Reloj() - e.t)
end

function G.PodarVistos()
	local v, limite = vistos(), U.Reloj() - VISTO_DIAS * 86400
	for clave, e in pairs(v) do
		if type(e) ~= "table" or type(e.t) ~= "number" or e.t < limite then v[clave] = nil end
	end
end

function G.OlvidarVistos()
	local d = N.Datos(ID)
	d.visto = {}
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
		fila.zona = U.ZonaDe(map)
	elseif C.GetUnitZone then
		local okz, z = pcall(C.GetUnitZone, unit)
		fila.zona = okz and U.Numero(z) or nil
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
			if o.clave ~= f.clave or o.map ~= f.map or o.conectado ~= f.conectado or o.nivel ~= f.nivel
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

-- La fila del grupo con su unidad, leída otra vez ahora (para seguir).
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
-- La hermandad (su lista)
---------------------------------------------------------------------------

local pedidoEn = -math.huge
-- Pide al servidor la lista de la hermandad (el juego la limita sola).
function G.PedirHermandad(forzar)
	if not U.EnHermandad() then return end
	local ahora = U.Ahora()
	if not forzar and ahora - pedidoEn < 30 then return end
	pedidoEn = ahora
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		pcall(C_GuildInfo.GuildRoster)
	elseif GuildRoster then
		pcall(GuildRoster)
	end
end

-- "hace 3 días" de la lista de la hermandad (si el juego lo da).
local function ultimaConexion(i)
	if not GetGuildRosterLastOnline then return nil end
	local ok, anos, meses, dias, horas = pcall(GetGuildRosterLastOnline, i)
	if not ok then return nil end
	anos, meses, dias, horas = U.Numero(anos), U.Numero(meses), U.Numero(dias), U.Numero(horas)
	if not (anos or meses or dias or horas) then return nil end
	return (((anos or 0) * 365 + (meses or 0) * 30 + (dias or 0)) * 24 + (horas or 0)) * 3600
end

function G.LeerHermandad()
	local nueva = {}
	if U.EnHermandad() and GetNumGuildMembers and GetGuildRosterInfo then
		local mia = U.MiClave()
		local total = U.Numero((GetNumGuildMembers())) or 0
		for i = 1, total do
			local ok, name, rango, rangoN, nivel, claseNombre, zona, _, _, conectado, _, clase, _, _, movil = pcall(GetGuildRosterInfo, i)
			if not ok then break end
			name = U.Texto(name)
			local clave = U.Clave(name)
			if clave and clave ~= mia and not nueva[clave] then
				local fila = {
					tipo = "hermandad", clave = clave, nombre = U.Mostrar(name), envio = name,
					rango = U.Texto(rango), rangoN = U.Numero(rangoN), nivel = U.Numero(nivel),
					claseNombre = U.Texto(claseNombre), clase = U.Texto(clase), zonaTexto = U.Texto(zona),
					conectado = U.Leer(conectado) and not U.Leer(movil) and true or false,
				}
				if fila.conectado then
					G.Visto(clave, fila.nombre)
				else
					fila.desde = ultimaConexion(i)
				end
				nueva[clave] = fila
			end
		end
	end
	hermandad = nueva
	cambio()
end

function G.Hermandad() return hermandad end
function G.DeHermandad(clave) return clave and hermandad[clave] or nil end

---------------------------------------------------------------------------
-- Amigos (su lista; Battle.net queda fuera por ahora)
---------------------------------------------------------------------------

function G.PedirAmigos()
	if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
end

function G.LeerAmigos()
	local nuevos, conectados = {}, {}
	local FL = C_FriendList
	if FL and FL.GetNumFriends and FL.GetFriendInfoByIndex then
		local okN, total = pcall(FL.GetNumFriends)
		total = okN and U.Numero(total) or 0
		for i = 1, total do
			local ok, f = pcall(FL.GetFriendInfoByIndex, i)
			if ok and type(f) == "table" then
				local name = U.Texto(f.name)
				local clave = U.Clave(name)
				if clave and not nuevos[clave] then
					local con = U.Leer(f.connected) and true or false
					local fila = {
						tipo = "amigo", clave = clave, nombre = U.Mostrar(name), envio = name,
						nivel = U.Numero(f.level), claseNombre = U.Texto(f.className),
						zonaTexto = U.Texto(f.area), conectado = con,
					}
					if fila.nivel and fila.nivel <= 0 then fila.nivel = nil end
					fila.clase = U.ClaseDeNombre(fila.claseNombre)
					nuevos[clave] = fila
					if con then conectados[#conectados + 1] = { clave = clave, envio = name } end
				end
			end
		end
	end
	amigos = nuevos
	cambio()
	-- Amigos que no están en mi hermandad: un saludo a quien se conectó (Red.lua).
	local fuera = {}
	for _, f in ipairs(conectados) do
		if not hermandad[f.clave] then fuera[#fuera + 1] = f end
	end
	M.Red.SaludarAmigos(fuera)
end

function G.Amigos() return amigos end
function G.EsAmigo(clave) return clave ~= nil and amigos[clave] ~= nil end

-- Los amigos con Alfa conectados que no están en mi hermandad: clave ->
-- nombre para susurrar (a ellos les va mi posición si les comparto).
function G.AmigosConAlfa()
	local out = {}
	for clave, f in pairs(amigos) do
		local e = alfa[clave]
		if f.conectado and e and e.via.amigo and not hermandad[clave] then out[clave] = e.envio or f.envio end
	end
	return out
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

-- Completa una fila con lo que dicen los Alfa (nivel, clase, zona).
function G.Completar(fila)
	local e = alfa[fila.clave]
	fila.alfa = e ~= nil
	fila.comparte = e and e.comparte and true or false
	if e then
		fila.nivel = fila.nivel or e.nivel
		fila.clase = fila.clase or e.clase
	end
	local map = G.PosicionDe(fila)
	if map and not fila.zona then fila.zona = U.ZonaDe(map) end
	return fila
end

-- Todos los Alfa que comparten y tienen posición fresca, con su capa:
-- "grupo", "hermandad" o "amigo". El grupo va primero; nadie sale dos veces.
function G.ParaElMapa()
	local out, puesto = {}, {}
	for _, f in ipairs(grupo) do
		if f.map then
			out[#out + 1] = { capa = "grupo", fila = f }
			puesto[f.clave] = true
		end
	end
	local ahora = U.Ahora()
	for clave, e in pairs(alfa) do
		if not puesto[clave] and e.map and e.at and ahora - e.at <= G.CADUCA then
			local capa = (e.via.hermandad or hermandad[clave]) and "hermandad" or (e.via.amigo and "amigo") or nil
			if capa then
				local base = hermandad[clave] or amigos[clave]
				local fila = {
					tipo = capa, clave = clave, nombre = (base and base.nombre) or e.nombre, envio = (base and base.envio) or e.envio,
					nivel = e.nivel or (base and base.nivel), clase = e.clase or (base and base.clase),
					claseNombre = base and base.claseNombre, rango = base and base.rango,
				}
				out[#out + 1] = { capa = capa, fila = fila }
				puesto[clave] = true
			end
		end
	end
	return out
end

-- Cuántos usan Alfa en la hermandad (lo oído) y cuántos están conectados.
function G.Cuentas()
	local con, usan = 0, 0
	for clave, f in pairs(hermandad) do
		if f.conectado then con = con + 1 end
		local e = alfa[clave]
		if e and e.via.hermandad then usan = usan + 1 end
	end
	for clave, e in pairs(alfa) do
		if e.via.hermandad and not hermandad[clave] then usan = usan + 1 end
	end
	return con, usan
end
