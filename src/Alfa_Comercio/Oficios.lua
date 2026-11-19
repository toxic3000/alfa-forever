-- Alfa - Comercio: tus oficios de 1 a 300 (toxic3000 / La Jauría). GPL-3.0. 1.2.9.
--
-- La lógica de las guías de OficiosDatos.lua: tu habilidad en cada oficio,
-- los pasos con su estado (hecho, el tuyo, lo que sigue), los materiales de
-- lo que te falta (con lo que tienes en bolsas y banco) y dónde aprender el
-- siguiente rango. La ventana (VentanaOficios.lua) y la página (Pagina.lua,
-- sección Oficios) lo muestran; la lista de compras (Lista.lua) lo usa para
-- «Agregar lo que me falta».
--
--   Of.Lista() -> { { linea, guia, rank, max, conocido }, ... }   (en el orden de la guía)
--   Of.Habilidad(linea) -> rank, max | nil
--   Of.Pasos(linea, rank) -> { { paso, estado = "hecho"|"actual"|"falta", reactivos, veces }, ... }
--   Of.Faltan(linea, rank) -> { { id, necesita, tienes, faltan }, ... }   (lo que pide subir desde rank a 300)
--   Of.Rango(linea, rank, max) -> { titulo, texto, puede, nivel }        (el siguiente rango)
--   M.Tienes(id) -> lo que tienes en bolsas y banco (AlfaBolsas, o el juego)
-- Habilidad: Alfa.Compat.GetSkillRank(línea) del motor (C_SkillInfo).

local _, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local G = M.OFICIOS_GUIA

local type, pairs, ipairs, floor, max, min, ceil, format = type, pairs, ipairs, math.floor, math.max, math.min, math.ceil, string.format

local Of = {}
M.Oficios = Of

local function secreto(v) return v ~= nil and issecretvalue ~= nil and issecretvalue(v) and true or false end
local function num(v) if secreto(v) then return nil end return tonumber(v) end

---------------------------------------------------------------------------
-- Lo que tienes de un objeto (bolsas y banco del personaje)
---------------------------------------------------------------------------

function M.Tienes(id)
	if type(id) ~= "number" then return 0 end
	local B = rawget(_G, "AlfaBolsas")
	if type(B) == "table" and type(B.Cuantos) == "function" then
		local ok, n = pcall(B.Cuantos, id)
		if ok and type(n) == "number" then return n end
	end
	local CI = C_Item
	local f = (CI and CI.GetItemCount) or rawget(_G, "GetItemCount")
	if type(f) == "function" then
		local ok, n = pcall(f, id, true)
		if ok and num(n) then return num(n) end
	end
	return 0
end

---------------------------------------------------------------------------
-- Habilidad
---------------------------------------------------------------------------

function Of.Habilidad(linea)
	local C = A.Compat
	if not (C and C.GetSkillRank) then return nil end
	local ok, r, mx = pcall(C.GetSkillRank, linea)
	r, mx = ok and num(r) or nil, ok and num(mx) or nil
	if not r or not mx or mx <= 0 then return nil end
	return r, mx
end

function Of.Nombre(linea)
	local g = G[linea]
	return g and L[g.nombre] or "?"
end

function Of.Lista()
	local out = {}
	for _, linea in ipairs(G.ORDEN) do
		local r, mx = Of.Habilidad(linea)
		out[#out + 1] = { linea = linea, guia = G[linea], rank = r, max = mx, conocido = r ~= nil }
	end
	return out
end

---------------------------------------------------------------------------
-- Pasos y materiales
---------------------------------------------------------------------------

-- Tus recetas aprendidas (las de este personaje), por producto: para usar
-- los reactivos que da el juego en lugar de los de la guía.
local function recetasPropias()
	local por = {}
	if not M.TodasLasRecetas then return por end
	local ok, todas = pcall(M.TodasLasRecetas)
	if not ok or type(todas) ~= "table" then return por end
	for _, e in ipairs(todas) do
		local rec = e.rec
		if e.propio and type(rec) == "table" and type(rec.o) == "number" and type(rec.r) == "table" then por[rec.o] = rec end
	end
	return por
end

-- Los reactivos de una vez de un paso: { id, cantidad, ... }
local function reactivos(p, propias)
	if p.o and propias and propias[p.o] then return propias[p.o].r end
	return p.r or {}
end
Of.Reactivos = reactivos

-- Cuántas veces quedan de un paso según tu habilidad (proporcional).
local function vecesQueFaltan(p, rank)
	local desde, hasta = p[1], p[2]
	if rank >= hasta then return 0 end
	local total = p.n or 1
	if rank <= desde then return total end
	return max(1, ceil(total * (hasta - rank) / max(1, hasta - desde)))
end

function Of.Pasos(linea, rank)
	local g = G[linea]
	if not g then return {} end
	rank = rank or 0
	local propias = recetasPropias()
	local out = {}
	for _, p in ipairs(g.pasos) do
		local estado = rank >= p[2] and "hecho" or ((rank >= p[1] or (p[1] == 1 and rank < 1)) and "actual" or "falta")
		out[#out + 1] = { paso = p, estado = estado, reactivos = reactivos(p, propias), veces = p.o and vecesQueFaltan(p, rank) or nil }
	end
	return out
end

-- Los productos de la guía: un reactivo que la misma guía crea en otro paso
-- se cambia por sus propios materiales (Pociones menores para las inferiores,
-- rollos de tela para los guantes...).
local function productos(g, propias)
	local por = {}
	for _, p in ipairs(g.pasos) do
		if p.o and not por[p.o] then por[p.o] = { r = reactivos(p, propias), q = 1 } end
	end
	return por
end

local function sumar(t, orden, id, n, prods, hondo)
	local pr = prods[id]
	if pr and hondo < 3 then
		for i = 1, #pr.r, 2 do
			local rid, q = pr.r[i], pr.r[i + 1]
			if type(rid) == "number" and type(q) == "number" then sumar(t, orden, rid, n * q, prods, hondo + 1) end
		end
		return
	end
	if not t[id] then orden[#orden + 1] = id end
	t[id] = (t[id] or 0) + n
end

function Of.Faltan(linea, rank)
	local g = G[linea]
	if not g or g.tipo ~= "crear" then return {} end
	rank = rank or 0
	local propias = recetasPropias()
	local prods = productos(g, propias)
	local t, orden = {}, {}
	for _, p in ipairs(g.pasos) do
		if rank < p[2] then
			local r = reactivos(p, propias)
			if p.o then
				local veces = vecesQueFaltan(p, rank)
				for i = 1, #r, 2 do
					local id, q = r[i], r[i + 1]
					if type(id) == "number" and type(q) == "number" then sumar(t, orden, id, veces * q, prods, 0) end
				end
			else
				-- Un paso general: sus materiales ya son el total del tramo.
				local parte = rank > p[1] and (p[2] - rank) / max(1, p[2] - p[1]) or 1
				for i = 1, #r, 2 do
					local id, q = r[i], r[i + 1]
					if type(id) == "number" and type(q) == "number" then sumar(t, orden, id, max(1, ceil(q * parte)), prods, 0) end
				end
			end
		end
	end
	local out = {}
	for _, id in ipairs(orden) do
		local tienes = M.Tienes(id)
		out[#out + 1] = { id = id, necesita = t[id], tienes = tienes, faltan = max(0, t[id] - tienes) }
	end
	return out
end

---------------------------------------------------------------------------
-- El siguiente rango
---------------------------------------------------------------------------

local function nivelJugador()
	local n = UnitLevel and num(UnitLevel("player"))
	return n or 0
end

-- -> { titulo, texto, puede = bool, tope = bool }
function Of.Rango(linea, rank, mx)
	local g = G[linea]
	local nombre = Of.Nombre(linea)
	if not rank then
		return { titulo = format(L["Aprende %s"], nombre), texto = L["Te lo enseña cualquier instructor de este oficio en las ciudades. Puedes tener dos oficios principales; Cocina y Primeros auxilios no cuentan."], puede = true }
	end
	if mx >= 300 then
		if rank >= 300 then return { titulo = format(L["%s al máximo"], nombre), texto = L["Ya no hay nada más que aprender. ¡Qué orgullo!"], tope = true } end
		return { titulo = L["Ya tienes el rango más alto"], texto = format(L["Sube hasta %d con los pasos de abajo."], mx) }
	end
	local sig
	for _, x in ipairs(G.RANGOS) do
		if x.tope > mx then sig = x break end
	end
	if not sig then return { titulo = "", texto = "" } end
	local extra = g and g.rangos and (" " .. L[g.rangos]) or ""
	local lv = nivelJugador()
	if rank >= sig.desde and lv >= sig.nivel then
		return { titulo = format(L["Ya puedes aprender el rango %s"], L[sig.nombre]),
			texto = format(L["Con él tu tope sube a %d."], sig.tope) .. extra, puede = true }
	end
	local partes = {}
	if rank < sig.desde then partes[#partes + 1] = format(L["habilidad %d"], sig.desde) end
	if lv < sig.nivel then partes[#partes + 1] = format(L["nivel %d"], sig.nivel) end
	return { titulo = format(L["Siguiente rango: %s"], L[sig.nombre]),
		texto = format(L["Lo aprendes con %s. Tu tope sube a %d."], table.concat(partes, " " .. L["y"] .. " "), sig.tope) .. extra }
end

-- «Llévame con el instructor»: la flecha de Alfa (AlfaCerca, de Alfa_Rutas).
function Of.Instructor(linea)
	local Ce = rawget(_G, "AlfaCerca")
	if type(Ce) == "table" and type(Ce.Ir) == "function" then
		local ok, si = pcall(Ce.Ir, "trainer", linea)
		if ok and si then
			if N.EmpezarRuta then pcall(N.EmpezarRuta) end
			return true
		end
	end
	N.Imprimir(L["No se pudo buscar el lugar más cercano."])
	return false
end

-- El paso en el que vas: -> paso, índice
function Of.PasoActual(linea, rank)
	local g = G[linea]
	if not g then return nil end
	rank = rank or 0
	for i, p in ipairs(g.pasos) do
		if rank < p[2] then return p, i end
	end
	return nil
end
