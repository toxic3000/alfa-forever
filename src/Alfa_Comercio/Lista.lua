-- Alfa - Comercio: tu lista de compras (toxic3000 / La Jauría). GPL-3.0. 1.2.9.
--
-- Para una receta o una meta: los materiales, cuántos tienes (bolsas y banco,
-- con los datos de Alfa_Bolsas), cuántos te faltan y de dónde sale cada uno
-- (el Codex del motor: lo venden, botín, se recoge, se fabrica...). Las
-- palomitas cambian solas mientras juntas (BAG_UPDATE_DELAYED) y, si quieres,
-- un aviso cuando completas un material o toda la lista (comercio.listaAviso).
-- La lista es de cada personaje: N.DatosPersonaje("comercio").lista.
--
-- Qué necesita una meta (Li.Receta):
--   1. una receta que conoce este personaje (Recetas.lua, leída del juego);
--   2. la guía de oficios (OficiosDatos.lua);
--   3. si nadie la fabrica, la meta es juntar ese objeto.
--
--   AlfaComercio.Lista.Agregar(itemID, cantidad) -> true | false   (para la Enciclopedia y los demás)
--   AlfaComercio.Lista.AgregarOficio(línea) -> true | false        (lo que falta para subir un oficio)
--   AlfaComercio.Lista.Quitar(i), .Vaciar(), .Metas(), .Materiales(), .Completa()
--   Li.Donde(id) -> «lo venden · botín de criaturas» | nil

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, pairs, ipairs, floor, max, min, ceil, format, tostring = type, pairs, ipairs, math.floor, math.max, math.min, math.ceil, string.format, tostring

local Li = {}
M.Lista = Li

local MAX_METAS = 20

local function datos()
	local d = N.DatosPersonaje(M.ID)
	d.lista = type(d.lista) == "table" and d.lista or {}
	local l = d.lista
	l.metas = type(l.metas) == "table" and l.metas or {}
	return l
end

local function nombreObjeto(id)
	local C = A.Compat
	local n = C and C.GetItemName and C.GetItemName(id)
	if type(n) == "string" and n ~= "" then return n end
	local X = A.Codex
	if X and X.IsLoaded and X.IsLoaded() and X.Name then
		local ok, nombre = pcall(X.Name, "item", id)
		if ok and type(nombre) == "string" then return nombre end
	end
	if C and C.RequestItem then pcall(C.RequestItem, id) end
	return format(L["Objeto %s"], tostring(id))
end
M.NombreObjeto = nombreObjeto

---------------------------------------------------------------------------
-- Qué se necesita para una meta
---------------------------------------------------------------------------

-- -> reactivos { id, cantidad, ... } por vez, rinde por vez, origen ("receta" | "guia") | nil
function Li.Receta(id)
	if type(id) ~= "number" then return nil end
	if M.TodasLasRecetas then
		local ok, todas = pcall(M.TodasLasRecetas)
		if ok and type(todas) == "table" then
			local otra
			for _, e in ipairs(todas) do
				local rec = e.rec
				if type(rec) == "table" and rec.o == id and type(rec.r) == "table" then
					if e.propio then return rec.r, rec.q or 1, "receta" end
					otra = otra or rec
				end
			end
			if otra then return otra.r, otra.q or 1, "receta" end
		end
	end
	local G = M.OFICIOS_GUIA
	for _, linea in ipairs(G.ORDEN) do
		for _, p in ipairs(G[linea].pasos) do
			if p.o == id and p.r then return p.r, 1, "guia" end
		end
	end
	return nil
end

local function cambio()
	M.Cambio()
	A.Fire("ALFA_COMERCIO_LISTA")
end

-- Lo que ya está listo, sin avisos (al cambiar la lista o al entrar).
local foto

function Li.Agregar(id, cantidad)
	id = tonumber(id)
	cantidad = floor(tonumber(cantidad) or 1)
	if not id or id <= 0 then return false end
	if cantidad < 1 then cantidad = 1 end
	local l = datos()
	-- La misma meta otra vez: se suma.
	for _, m in ipairs(l.metas) do
		if m.id == id and not m.oficio then
			m.n = min(1000, (m.n or 1) + cantidad)
			foto(l)
			cambio()
			return true
		end
	end
	if #l.metas >= MAX_METAS then
		N.Imprimir(L["Tu lista ya tiene 20 metas: termina o quita alguna primero."])
		return false
	end
	local r, q = Li.Receta(id)
	local m = { id = id, n = min(1000, cantidad), t = M.Ahora() }
	if r then m.r, m.q = r, q or 1 end
	l.metas[#l.metas + 1] = m
	foto(l)
	cambio()
	return true
end

-- Lo que falta para subir un oficio desde tu habilidad hasta 300.
function Li.AgregarOficio(linea)
	local G = M.OFICIOS_GUIA
	if not G[linea] or G[linea].tipo ~= "crear" then return false end
	local rank = M.Oficios.Habilidad(linea) or 0
	local faltan = M.Oficios.Faltan(linea, rank)
	local r = {}
	for _, x in ipairs(faltan) do
		r[#r + 1] = x.id
		r[#r + 1] = x.necesita
	end
	if #r == 0 then return false end
	local l = datos()
	for i, m in ipairs(l.metas) do
		if m.oficio == linea then table.remove(l.metas, i) break end
	end
	if #l.metas >= MAX_METAS then
		N.Imprimir(L["Tu lista ya tiene 20 metas: termina o quita alguna primero."])
		return false
	end
	l.metas[#l.metas + 1] = { oficio = linea, n = 1, r = r, q = 1, total = true, desde = rank, t = M.Ahora() }
	foto(l)
	cambio()
	return true
end

function Li.Quitar(i)
	local l = datos()
	if not l.metas[i] then return false end
	table.remove(l.metas, i)
	foto(l)
	cambio()
	return true
end

function Li.Vaciar()
	local l = datos()
	l.metas = {}
	l.listos = nil
	cambio()
end

function Li.Metas() return datos().metas end

function Li.NombreMeta(m)
	if m.oficio then return format(L["Subir %s"], M.Oficios.Nombre(m.oficio)) end
	return nombreObjeto(m.id)
end

-- Cuántas veces se fabrica una meta.
local function veces(m)
	if m.total then return 1 end
	local q = tonumber(m.q) or 1
	if q <= 0 then q = 1 end
	return ceil((m.n or 1) / q)
end

-- -> { { id, necesita, tienes, faltan, listo }, ... }, listos, total
function Li.Materiales()
	local t, orden = {}, {}
	for _, m in ipairs(datos().metas) do
		local r = type(m.r) == "table" and m.r or { m.id, 1 }
		local v = m.r and veces(m) or (m.n or 1)
		for i = 1, #r, 2 do
			local id, q = r[i], r[i + 1]
			if type(id) == "number" and type(q) == "number" then
				if not t[id] then orden[#orden + 1] = id end
				t[id] = (t[id] or 0) + q * v
			end
		end
	end
	local out, listos = {}, 0
	for _, id in ipairs(orden) do
		local necesita = ceil(t[id])
		local tienes = M.Tienes(id)
		local faltan = max(0, necesita - tienes)
		if faltan == 0 then listos = listos + 1 end
		out[#out + 1] = { id = id, necesita = necesita, tienes = tienes, faltan = faltan, listo = faltan == 0 }
	end
	-- Lo que falta primero, luego lo listo.
	table.sort(out, function(a, b)
		if a.listo ~= b.listo then return b.listo end
		return a.faltan > b.faltan
	end)
	return out, listos, #out
end

function Li.Completa()
	local mats, listos, total = Li.Materiales()
	return total > 0 and listos == total
end

-- Lo que cuesta comprar lo que falta (con los precios que conoces).
function Li.Costo(mats)
	local total, completo = 0, true
	for _, x in ipairs(mats or {}) do
		if x.faltan > 0 then
			local c = M.CostoCompra(x.id)
			if c then total = total + c * x.faltan else completo = false end
		end
	end
	return total, completo
end

---------------------------------------------------------------------------
-- De dónde sale cada cosa (el Codex del motor; se carga al ver la lista)
---------------------------------------------------------------------------

local FUENTE = {
	vendor = "lo venden", drop = "botín de criaturas", object = "se recoge en el mundo", quest = "recompensa de misión",
	gift = "te lo da un PNJ", rep = "con reputación", container = "sale de un contenedor", pvp = "JcJ", world = "botín del mundo",
}
local donde = {}

function Li.Codex(cargar)
	local C = A.Codex
	if not C then return nil end
	if C.IsLoaded and C.IsLoaded() then return C end
	if not cargar or (InCombatLockdown and InCombatLockdown()) or not C.Load then return nil end
	local ok, si = pcall(C.Load)
	return ok and si and C or nil
end

function Li.Donde(id)
	if donde[id] ~= nil then return donde[id] or nil end
	local C = Li.Codex(false)
	if not C then return nil end
	local ok, rec = pcall(C.Item, id)
	if not ok or type(rec) ~= "table" then
		donde[id] = false
		return nil
	end
	local partes, vistos = {}, {}
	for _, s in ipairs(rec.sources or {}) do
		local t
		if s.type == "craft" then
			t = s.profession and format(L["se fabrica (%s)"], s.profession) or L["se fabrica"]
		elseif FUENTE[s.type] then
			t = L[FUENTE[s.type]]
		end
		if t and not vistos[t] then
			vistos[t] = true
			partes[#partes + 1] = t
		end
		if #partes >= 3 then break end
	end
	local texto = #partes > 0 and table.concat(partes, " \194\183 ") or false
	donde[id] = texto
	return texto or nil
end

-- «Guíame»: la guía del motor a un objeto (tu clic).
function Li.Guiar(id)
	local Lk = A.Lookup
	if InCombatLockdown and InCombatLockdown() then
		N.Imprimir(L["Se puede al salir de combate."])
		return false
	end
	if not (Lk and Lk.Guide) then
		N.Imprimir(L["El motor no puede armar guías ahora."])
		return false
	end
	local ok, gid = pcall(Lk.Guide, "item", id)
	if ok and gid then
		if N.EmpezarRuta then pcall(N.EmpezarRuta) end
		return true
	end
	N.Imprimir(L["No hay un camino que Alfa pueda guiar para esto."])
	return false
end

---------------------------------------------------------------------------
-- Las palomitas mientras juntas
---------------------------------------------------------------------------

-- ¿Los mismos materiales listos? (a: lo de antes, puede faltar)
local function mismos(a, b)
	if not a then return false end
	for k in pairs(a) do if not b[k] then return false end end
	for k in pairs(b) do if not a[k] then return false end end
	return true
end

local function revisar()
	local l = datos()
	if #l.metas == 0 then
		l.listos = nil
		return
	end
	local mats, listos, total = Li.Materiales()
	local antes = type(l.listos) == "table" and l.listos or nil
	local ahora = {}
	local nuevos = {}
	for _, x in ipairs(mats) do
		if x.listo then
			ahora[x.id] = true
			if antes and not antes[x.id] then nuevos[#nuevos + 1] = x end
		end
	end
	l.listos = ahora
	-- 1.3.1: el aviso a los demás (ALFA_COMERCIO y ALFA_COMERCIO_LISTA) solo si
	-- cambió lo que está listo. Antes salía con cada cambio de tus bolsas y
	-- rehacía de más las sugerencias, la ventana de bolsas y las páginas (que ya
	-- se rehacen solas con BAG_UPDATE_DELAYED para el «Tienes X de Y»).
	if not mismos(antes, ahora) then cambio() end
	if not antes or #nuevos == 0 or N.Get(M.ID, "listaAviso") == false then return end
	local function avisar()
		if listos == total then
			K.Aviso({ titulo = L["¡Tu lista de compras está completa!"], icono = "ic-exito", tono = "exito",
				texto = L["Ya tienes todos los materiales. ¡A trabajar!"],
				accion = { texto = L["Ver mi lista"], alClic = function() N.Abrir(M.ID) end } })
		else
			local x = nuevos[1]
			K.Aviso({ titulo = L["Lista de compras"], icono = "ic-exito", tono = "exito",
				texto = format(L["Ya tienes %d de %s. Te faltan %d de %d materiales."], x.necesita, nombreObjeto(x.id), total - listos, total) })
		end
	end
	if InCombatLockdown and InCombatLockdown() then N.FueraDeCombate("comercio.lista", avisar) else avisar() end
end
Li.Revisar = revisar

local pendiente = false
local function revisarLuego()
	if pendiente then return end
	pendiente = true
	local function ir()
		pendiente = false
		revisar()
	end
	if C_Timer and C_Timer.After then C_Timer.After(0.5, ir) else ir() end
end

A.RegisterEvent("BAG_UPDATE_DELAYED", function()
	if #datos().metas > 0 then revisarLuego() end
end)
function foto(l)
	l = l or datos()
	if #l.metas == 0 then
		l.listos = nil
		return
	end
	local ahora = {}
	for _, x in ipairs((Li.Materiales())) do if x.listo then ahora[x.id] = true end end
	l.listos = ahora
end
Li.Foto = foto
A.OnLogin(function() foto() end)

AlfaComercio = type(AlfaComercio) == "table" and AlfaComercio or {}
AlfaComercio.Lista = {
	Agregar = Li.Agregar, AgregarOficio = Li.AgregarOficio, Quitar = Li.Quitar, Vaciar = Li.Vaciar,
	Metas = Li.Metas, Materiales = Li.Materiales, Completa = Li.Completa,
}

-- Quién de tus personajes usa un objeto en sus recetas (para «Qué guardar»
-- de Alfa_Bolsas): -> { { quien, propio, profesion }, ... }
AlfaComercio.Usan = function(id)
	local out = {}
	local ok, idx = pcall(M.IndiceReactivos)
	local lista = ok and type(idx) == "table" and idx[id] or nil
	for _, e in ipairs(lista or {}) do
		out[#out + 1] = { quien = e.quien, propio = e.propio and true or false, profesion = type(e.rec) == "table" and e.rec.p or nil }
	end
	return out
end
