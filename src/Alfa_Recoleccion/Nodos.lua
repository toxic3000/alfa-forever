-- Alfa - Recolección: los nodos, los filtros y el historial (toxic3000 / La Jauría, GPL-3.0).
--
-- Los nodos de cada zona se arman la primera vez que hacen falta (al abrir
-- el mapa en esa zona o al pasar cerca en el minimapa): los de la base
-- incluida (Base.lua) sin repetidos, más los que tú descubres al
-- recolectar, guardados en N.Datos("recoleccion").nodos[mapa]. Cada zona
-- queda en una cuadrícula de CELDAS x CELDAS para que el mapa y el minimapa
-- lean solo lo que está a la vista.
--
-- Coordenadas: x, y de 0 a 1 en el mapa de la zona. Para distancias se
-- pasan a yardas del mundo con los bordes del mapa (Compat.MapToWorld de dos
-- esquinas): wx crece al norte, wy al oeste.
--
-- La regla de "el mismo nodo" (0.0065 del mapa) y los colores del nivel de
-- habilidad están adaptados de código MIT (ver CREDITOS.md).

local _, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

local floor, abs, max = math.floor, math.abs, math.max
local pairs, ipairs, type, tonumber, pcall = pairs, ipairs, type, tonumber, pcall

local ID = "recoleccion"
local R = { ID = ID, version = 0 }
M.R = R

local CELDAS = 32         -- celdas por lado de la cuadrícula de cada zona
local DUPLICADO = 0.003   -- dos puntos de la base más cerca que esto son uno
local RANGO = 0.0065      -- hasta esta distancia del mapa es el mismo nodo
local RANGO_PESCA = 0.012 -- al pescar estás lejos del banco
local MAX_SESIONES = 12

---------------------------------------------------------------------------
-- Avisos internos: el mapa, el minimapa, la ruta y la página escuchan.
--   que: "nodos" | "filtros" | "historial" | "ruta"
---------------------------------------------------------------------------
local oyentes = {}
function R.AlCambiar(fn) oyentes[#oyentes + 1] = fn end
function R.Avisar(que, ...)
	R.version = R.version + 1
	for i = 1, #oyentes do A.SafeCall(oyentes[i], que, ...) end
end

local function secreto(v) return issecretvalue ~= nil and issecretvalue(v) and true or false end
R.Secreto = secreto

---------------------------------------------------------------------------
-- Nombres e íconos
---------------------------------------------------------------------------
function R.Nombre(g)
	local gr = M.GRUPOS[g]
	if not gr then return "?" end
	return N.espanol and gr.es or gr.en
end

local NOMBRE_TIPO = {
	mineria = L["Minería"], hierbas = L["Hierbas"], pesca = L["Bancos de peces"], tesoros = L["Tesoros"],
}
function R.NombreTipo(tipo) return NOMBRE_TIPO[tipo] or tipo end

-- El nombre de la profesión como lo escribe el juego ("Minería"), o el nuestro.
local OFICIO = { [186] = L["Minería"], [182] = L["Herboristería"], [356] = L["Pesca"] }
function R.NombreOficio(tipo)
	local t = M.TIPO[tipo]
	if not (t and t.oficio) then return nil end
	local C = A.Compat
	local nombre = C and C.GetSkillLineName and C.GetSkillLineName(t.oficio)
	return nombre or OFICIO[t.oficio]
end

local GLIFO_TESORO = "Interface\\AddOns\\Alfa\\Media\\Map\\icon-treasure"
local ICONO_DEFECTO = "Interface\\Icons\\INV_Misc_QuestionMark"
local iconos, glifos = {}, {}

-- Ícono del recurso: el del objeto que da (un número de archivo), el del
-- hechizo de su profesión, o el cofre de Alfa para los tesoros (un glifo
-- blanco que se tiñe). -> textura, esGlifo
function R.Icono(g)
	local hecho = iconos[g]
	if hecho then return hecho, glifos[g] end
	local gr = M.GRUPOS[g]
	if not gr then return ICONO_DEFECTO, false end
	local C = A.Compat
	local tex = gr.item and C and C.ItemIcon and C.ItemIcon(gr.item)
	if tex then
		iconos[g] = tex
		return tex, false
	end
	if gr.tipo == "tesoros" then
		iconos[g], glifos[g] = GLIFO_TESORO, true
		return GLIFO_TESORO, true
	end
	local t = M.TIPO[gr.tipo]
	tex = t and t.hechizo and C and C.SpellIcon and C.SpellIcon(t.hechizo)
	return tex or ICONO_DEFECTO, false
end

-- El ícono de un tipo (capas, chips de la página).
function R.IconoTipo(tipo)
	if tipo == "tesoros" then return GLIFO_TESORO, true end
	local t, C = M.TIPO[tipo], A.Compat
	local tex = t and t.hechizo and C and C.SpellIcon and C.SpellIcon(t.hechizo)
	return tex or ICONO_DEFECTO, false
end

---------------------------------------------------------------------------
-- Bordes de un mapa en yardas del mundo (una vez por mapa).
---------------------------------------------------------------------------
local limites = {}
function R.Limites(mapID)
	if not mapID then return nil end
	local b = limites[mapID]
	if b ~= nil then return b or nil end
	local C = A.Compat
	if not (C and C.MapToWorld) then return nil end
	local c1, top, left = C.MapToWorld(mapID, 0, 0)
	local c2, bottom, right = C.MapToWorld(mapID, 100, 100)
	if c1 and c1 == c2 and top ~= bottom and left ~= right then
		b = { c = c1, top = top, left = left, bottom = bottom, right = right,
			ancho = abs(right - left), alto = abs(bottom - top) }
		limites[mapID] = b
		return b
	end
	-- Antes de entrar al mundo el juego puede no responder: se vuelve a intentar.
	if A.IsLoggedIn and A.IsLoggedIn() then limites[mapID] = false end
	return nil
end

-- Un punto (0..1) del mapa en yardas del mundo: c, wx, wy.
function R.AlMundo(b, x, y)
	return b.c, b.top + (b.bottom - b.top) * y, b.left + (b.right - b.left) * x
end

---------------------------------------------------------------------------
-- Datos guardados. Se piden siempre a N.Datos; si la tabla cambió (el
-- juego la devolvió vacía y se creó otra), los índices se rehacen.
---------------------------------------------------------------------------
local mapas = {}        -- mapID -> índice de la zona
local conocidos         -- lista de mapas con nodos (base o descubiertos)
local enConocidos = {}
local refDatos

local function datos()
	local D = N.Datos(ID)
	if D ~= refDatos then
		refDatos = D
		for k in pairs(mapas) do mapas[k] = nil end
		conocidos = nil
	end
	if type(D.nodos) ~= "table" then D.nodos = {} end
	return D
end
R.Datos = datos

local function personaje()
	local P = N.DatosPersonaje(ID)
	if type(P.zonas) ~= "table" then P.zonas = {} end
	if type(P.objetos) ~= "table" then P.objetos = {} end
	if type(P.sesiones) ~= "table" then P.sesiones = {} end
	return P
end
R.Personaje = personaje

function R.MapasConocidos()
	datos()
	if conocidos then return conocidos end
	conocidos = {}
	for k in pairs(enConocidos) do enConocidos[k] = nil end
	local function poner(m)
		if type(m) == "number" and not enConocidos[m] then
			enConocidos[m] = true
			conocidos[#conocidos + 1] = m
		end
	end
	for _, porMapa in pairs(M.BASE or {}) do
		for mapID in pairs(porMapa) do poner(mapID) end
	end
	for mapID in pairs(refDatos.nodos) do poner(mapID) end
	table.sort(conocidos)
	return conocidos
end

function R.EsConocido(mapID)
	R.MapasConocidos()
	return enConocidos[mapID] == true
end

---------------------------------------------------------------------------
-- Índice de una zona
--   idx.n, idx.x[i], idx.y[i], idx.g[i] (grupo), idx.base[i] (viene de la
--   base), idx.d[i] (lo que guardaste de ese nodo, o false), idx.celdas[k]
---------------------------------------------------------------------------
local function celdaDe(v)
	local c = floor(v * CELDAS)
	if c < 0 then return 0 elseif c >= CELDAS then return CELDAS - 1 end
	return c
end
R.CELDAS = CELDAS
R.CeldaDe = celdaDe

local function agregar(idx, x, y, g, rec, base)
	local i = idx.n + 1
	idx.n = i
	idx.x[i], idx.y[i], idx.g[i], idx.d[i], idx.base[i] = x, y, g, rec or false, base and true or false
	local k = celdaDe(x) * CELDAS + celdaDe(y)
	local lista = idx.celdas[k]
	if not lista then
		lista = {}
		idx.celdas[k] = lista
	end
	lista[#lista + 1] = i
	return i
end

-- El nodo del grupo g más cerca de (x, y) dentro de r, o nil.
local function cercano(idx, x, y, g, r)
	local cx, cy = celdaDe(x), celdaDe(y)
	local mejor, mejorD = nil, r * r
	for dx = -1, 1 do
		local gx = cx + dx
		if gx >= 0 and gx < CELDAS then
			for dy = -1, 1 do
				local gy = cy + dy
				local lista = gy >= 0 and gy < CELDAS and idx.celdas[gx * CELDAS + gy]
				if lista then
					for k = 1, #lista do
						local i = lista[k]
						if idx.g[i] == g then
							local ex, ey = idx.x[i] - x, idx.y[i] - y
							local d = ex * ex + ey * ey
							if d <= mejorD then mejor, mejorD = i, d end
						end
					end
				end
			end
		end
	end
	return mejor
end

local function grupoDe(rec)
	if type(rec) ~= "table" then return nil end
	return (rec.k and M.porClave[rec.k]) or (rec.o and M.porObjeto[rec.o]) or nil
end

local function rango(g)
	local gr = M.GRUPOS[g]
	return gr and gr.tipo == "pesca" and RANGO_PESCA or RANGO
end

function R.Indice(mapID)
	local D = datos()
	local idx = mapas[mapID]
	if idx then return idx end
	idx = { mapa = mapID, n = 0, x = {}, y = {}, g = {}, d = {}, base = {}, celdas = {} }
	for obj, porMapa in pairs(M.BASE or {}) do
		local puntos = porMapa[mapID]
		local g = M.porObjeto[obj]
		if puntos and g then
			for i = 1, #puntos - 1, 2 do
				local x, y = puntos[i], puntos[i + 1]
				if not cercano(idx, x, y, g, DUPLICADO) then agregar(idx, x, y, g, nil, true) end
			end
		end
	end
	local propios = D.nodos[mapID]
	if type(propios) == "table" then
		for _, rec in ipairs(propios) do
			local g = grupoDe(rec)
			local x, y = tonumber(rec.x), tonumber(rec.y)
			if g and x and y then
				local j = cercano(idx, x, y, g, rango(g))
				if j and not idx.d[j] then idx.d[j] = rec else agregar(idx, x, y, g, rec, false) end
			end
		end
	end
	mapas[mapID] = idx
	return idx
end

-- El índice de una zona solo si tiene nodos (no arma índices vacíos de
-- ciudades, cuevas o continentes).
function R.IndiceSiHay(mapID)
	if not (mapID and R.EsConocido(mapID)) then return nil end
	return R.Indice(mapID)
end

local function redondear(v) return floor(v * 10000 + 0.5) / 10000 end

-- Un nodo recolectado en (x, y) del mapa: lo une al nodo que ya estaba ahí
-- o crea uno. cuenta: cuántas veces sumar.
-- -> índice del nodo en la zona, lo guardado
local function anotarNodo(g, mapID, x, y, objectID, cuenta, cuando)
	local D = datos()
	local idx = R.Indice(mapID)
	local j = cercano(idx, x, y, g, rango(g))
	local rec = j and idx.d[j] or nil
	if not rec then
		local lista = D.nodos[mapID]
		if type(lista) ~= "table" then
			lista = {}
			D.nodos[mapID] = lista
		end
		rec = { x = redondear(x), y = redondear(y), k = M.GRUPOS[g].clave, o = objectID, n = 0 }
		lista[#lista + 1] = rec
		if j then idx.d[j] = rec else j = agregar(idx, x, y, g, rec, false) end
		if not enConocidos[mapID] then conocidos = nil end
	end
	rec.n = (tonumber(rec.n) or 0) + (cuenta or 1)
	if cuando and (not rec.t or cuando > rec.t) then rec.t = cuando end
	return j, rec
end

function R.Registrar(g, mapID, x, y, objectID)
	if not (M.GRUPOS[g] and mapID and x and y) then return nil end
	local j, rec = anotarNodo(g, mapID, x, y, objectID, 1, time())
	R.Avisar("nodos", mapID)
	return j, rec
end

function R.BorrarDescubiertos()
	local D = datos()
	D.nodos = {}
	for k in pairs(mapas) do mapas[k] = nil end
	conocidos = nil
	R.Avisar("nodos")
end

-- Cuántos puntos trae la base y cuántos descubriste: base, propios, zonas.
function R.Conteos()
	local D = datos()
	local base, propios = 0, 0
	for _, porMapa in pairs(M.BASE or {}) do
		for _, puntos in pairs(porMapa) do base = base + floor(#puntos / 2) end
	end
	for _, lista in pairs(D.nodos) do
		if type(lista) == "table" then propios = propios + #lista end
	end
	return base, propios, #R.MapasConocidos()
end

---------------------------------------------------------------------------
-- Habilidades y filtros
---------------------------------------------------------------------------
local habilidades = {}   -- tipo -> rango efectivo (con bonos) | nil sin la profesión
local listas = false     -- el juego ya dio las habilidades
local visibles = {}      -- grupo -> se muestra
local puede = {}         -- grupo -> tu habilidad alcanza
local usarBase = true

local function leerHabilidad(oficio)
	local S = C_SkillInfo
	if S and S.GetSkillLineInfoByID then
		local ok, info = pcall(S.GetSkillLineInfoByID, oficio)
		if ok and type(info) == "table" and not secreto(info.rank) then
			local rank, maxRank = tonumber(info.rank) or 0, tonumber(info.maxRank) or 0
			if rank > 0 or maxRank > 0 then return rank + (tonumber(info.modifier) or 0) end
			return nil
		end
	end
	local C = A.Compat
	return C and C.GetSkillRank and C.GetSkillRank(oficio) or nil
end

function R.LeerHabilidades()
	local S = C_SkillInfo
	local hay = true
	if S and S.GetNumSkillLines then
		local ok, n = pcall(S.GetNumSkillLines)
		hay = ok and type(n) == "number" and n > 0
	end
	listas = hay
	for _, tipo in ipairs(M.TIPOS) do
		local t = M.TIPO[tipo]
		habilidades[tipo] = t.oficio and hay and leerHabilidad(t.oficio) or nil
	end
end

function R.Habilidad(tipo) return habilidades[tipo] end
function R.HabilidadesListas() return listas end

-- ¿El tipo se muestra? Con Alfa_Mundo manda su capa; si no, el ajuste propio.
function R.TipoActivo(tipo)
	if R.mundo and type(AlfaMundo) == "table" and type(AlfaMundo.CapaActiva) == "function" then
		local ok, v = pcall(AlfaMundo.CapaActiva, "recoleccion." .. tipo)
		if ok and v ~= nil then return v and true or false end
	end
	return N.Get(ID, tipo) ~= false
end

function R.Refiltrar()
	local soloOficio = N.Get(ID, "soloProfesiones") ~= false
	local soloHabilidad = N.Get(ID, "soloHabilidad") == true
	usarBase = N.Get(ID, "base") ~= false
	local activo = {}
	for _, tipo in ipairs(M.TIPOS) do activo[tipo] = R.TipoActivo(tipo) end
	for g, gr in ipairs(M.GRUPOS) do
		local tipo = gr.tipo
		local rank = habilidades[tipo]
		local oficio = M.TIPO[tipo].oficio
		puede[g] = (not gr.niveles) or (rank ~= nil and rank >= gr.niveles[1])
		local on = activo[tipo]
		-- Sin las habilidades del juego todavía, no se esconde nada por profesión.
		if on and soloOficio and oficio and listas and rank == nil then on = false end
		if on and soloHabilidad and listas and not puede[g] then on = false end
		visibles[g] = on
	end
	R.Avisar("filtros")
end

function R.GrupoVisible(g) return visibles[g] == true end
function R.Puede(g) return puede[g] ~= false end

-- ¿Se pinta el nodo i de la zona?
function R.Muestra(idx, i)
	if not visibles[idx.g[i]] then return false end
	return usarBase or not idx.base[i] or idx.d[i] ~= false
end

-- Para una ruta: el tipo elegido aunque su capa esté apagada, sin lo que tu
-- habilidad todavía no alcanza (si tienes la profesión; sin ella se planea
-- con todo) y respetando la base.
function R.ParaRuta(idx, i)
	local g = idx.g[i]
	if listas and not puede[g] and habilidades[M.GRUPOS[g].tipo] ~= nil then return false end
	return usarBase or not idx.base[i] or idx.d[i] ~= false
end

-- Color del nivel necesario con tu habilidad (rojo, naranja, amarillo,
-- verde, gris), como el juego.
function R.ColorNivel(g)
	local gr = M.GRUPOS[g]
	local lv = gr and gr.niveles
	if not lv then return 0.75, 0.75, 0.75 end
	local rank = habilidades[gr.tipo]
	if not rank or rank < lv[1] then return 1, 0.25, 0.2 end
	if lv[4] and rank >= lv[4] then return 0.62, 0.62, 0.62 end
	if lv[3] and rank >= lv[3] then return 0.25, 1, 0.25 end
	if lv[2] and rank >= lv[2] then return 1, 1, 0 end
	if lv[2] then return 1, 0.5, 0.25 end
	return 1, 1, 1
end

---------------------------------------------------------------------------
-- Cerca del jugador (el minimapa): los nodos visibles a menos de `radio`
-- yardas de (c, px, py), en todas las zonas del continente que alcanzan.
-- Llena out.idx[k], out.i[k], out.wx[k], out.wy[k]; out.n = cuántos.
---------------------------------------------------------------------------
function R.Cercanos(c, px, py, radio, out)
	local n = 0
	local r2 = radio * radio
	for _, mapID in ipairs(R.MapasConocidos()) do
		local b = R.Limites(mapID)
		if b and b.c == c then
			local ux = (py - b.left) / (b.right - b.left)
			local uy = (px - b.top) / (b.bottom - b.top)
			local rx, ry = radio / b.ancho, radio / b.alto
			if ux + rx >= 0 and ux - rx <= 1 and uy + ry >= 0 and uy - ry <= 1 then
				local idx = R.Indice(mapID)
				local kx, ky = b.right - b.left, b.bottom - b.top
				for gx = celdaDe(ux - rx), celdaDe(ux + rx) do
					for gy = celdaDe(uy - ry), celdaDe(uy + ry) do
						local lista = idx.celdas[gx * CELDAS + gy]
						if lista then
							for k = 1, #lista do
								local i = lista[k]
								if R.Muestra(idx, i) then
									local wx, wy = b.top + ky * idx.y[i], b.left + kx * idx.x[i]
									local dn, dw = wx - px, wy - py
									if dn * dn + dw * dw <= r2 then
										n = n + 1
										out.idx[n], out.i[n], out.wx[n], out.wy[n] = idx, i, wx, wy
									end
								end
							end
						end
					end
				end
			end
		end
	end
	for k = n + 1, (out.n or 0) do out.idx[k] = nil end
	out.n = n
	return n
end

---------------------------------------------------------------------------
-- Dónde está el jugador, en el mapa de su zona (no el de una cueva o un
-- pueblo): mapID, x, y (0..1), c, wx, wy. nil si el juego no lo dice.
---------------------------------------------------------------------------
function R.PosicionJugador()
	local C = A.Compat
	if not (C and C.GetPlayerMapPosition) then return nil end
	local map, x, y = C.GetPlayerMapPosition()
	if not (type(map) == "number" and type(x) == "number" and type(y) == "number") then return nil end
	local c, wx, wy = C.MapToWorld(map, x, y)
	local zona = C.GetUnitZone and C.GetUnitZone("player")
	if zona and zona ~= map and c and C.WorldToMap then
		local zx, zy = C.WorldToMap(c, wx, wy, zona)
		if zx and zy and zx >= 0 and zx <= 100 and zy >= 0 and zy <= 100 then map, x, y = zona, zx, zy end
	end
	return map, x / 100, y / 100, c, wx, wy
end

function R.EnInstancia()
	local C = A.Compat
	return C and C.IsInInstance and C.IsInInstance() and true or false
end

---------------------------------------------------------------------------
-- Historial, por personaje: total, por zona, objetos y sesiones.
--   P.zonas[mapa] = { total, tipos = { [tipo] = n }, recursos = { [clave] = n } }
--   P.objetos[itemID] = cantidad
--   P.sesiones = { { inicio, fin, total, tipos, recursos, objetos, zonas }, ... }
-- Una sesión sigue tras un /reload (menos de 15 minutos desde su final).
---------------------------------------------------------------------------
local sesion

local function nuevaSesion(ahora)
	return { inicio = ahora, fin = ahora, total = 0, tipos = {}, recursos = {}, objetos = {}, zonas = {} }
end

function R.Sesion()
	local P = personaje()
	local lista = P.sesiones
	if sesion and lista[#lista] == sesion then return sesion end
	local ahora = time()
	local ultima = lista[#lista]
	if type(ultima) == "table" and type(ultima.fin) == "number" and ahora - ultima.fin < 15 * 60 then
		sesion = ultima
	elseif type(ultima) == "table" and (tonumber(ultima.total) or 0) == 0 then
		sesion = nuevaSesion(ahora)
		lista[#lista] = sesion
	else
		sesion = nuevaSesion(ahora)
		lista[#lista + 1] = sesion
		while #lista > MAX_SESIONES do table.remove(lista, 1) end
	end
	for _, campo in ipairs({ "tipos", "recursos", "objetos", "zonas" }) do
		if type(sesion[campo]) ~= "table" then sesion[campo] = {} end
	end
	sesion.total = tonumber(sesion.total) or 0
	return sesion
end

local function sumar(t, k, n) t[k] = (tonumber(t[k]) or 0) + (n or 1) end

function R.Anotar(g, mapID)
	local gr = M.GRUPOS[g]
	if not (gr and mapID) then return end
	local P = personaje()
	P.total = (tonumber(P.total) or 0) + 1
	local z = P.zonas[mapID]
	if type(z) ~= "table" then
		z = { total = 0, tipos = {}, recursos = {} }
		P.zonas[mapID] = z
	end
	z.total = (tonumber(z.total) or 0) + 1
	sumar(z.tipos, gr.tipo)
	sumar(z.recursos, gr.clave)
	local s = R.Sesion()
	s.total = s.total + 1
	s.fin = time()
	sumar(s.tipos, gr.tipo)
	sumar(s.recursos, gr.clave)
	sumar(s.zonas, mapID)
	R.Avisar("historial")
end

function R.AnotarBotin(objetos)
	if type(objetos) ~= "table" or next(objetos) == nil then return end
	local P = personaje()
	local s = R.Sesion()
	for itemID, n in pairs(objetos) do
		sumar(P.objetos, itemID, n)
		sumar(s.objetos, itemID, n)
	end
	R.Avisar("historial")
end

-- Al salir: la sesión se cierra; si quedó vacía, se borra.
function R.CerrarSesion()
	if not sesion then return end
	local P = personaje()
	local lista = P.sesiones
	if lista[#lista] ~= sesion then return end
	if (tonumber(sesion.total) or 0) == 0 then
		lista[#lista] = nil
		sesion = nil
	else
		sesion.fin = time()
	end
end

function R.BorrarHistorial()
	local P = personaje()
	P.zonas, P.objetos, P.sesiones, P.total = {}, {}, {}, 0
	sesion = nil
	R.Sesion()
	R.Avisar("historial")
end
