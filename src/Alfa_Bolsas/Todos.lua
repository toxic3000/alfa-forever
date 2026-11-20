-- Alfa - Bolsas: buscar en las bolsas y bancos de todos tus personajes
-- (toxic3000 / La Jauría). GPL-3.0. 1.3.0.
--
-- Lo que guardó Datos.lua de cada personaje (bolsas, banco y equipo) con la
-- misma búsqueda de la ventana (nombre, tipo, calidad, nivel: Objetos.lua) y
-- tres filtros: tipo (las categorías de la ventana), calidad y personaje.
-- Solo lee lo guardado: el personaje actual, al día; los demás, su última foto.
-- Ajuste bolsas.buscarTodos (de fábrica, encendido).
--   Bt.Buscar(texto, { tipo, calidad, clave }) -> { { id, link, q, total, partes = { { clave, r, bolsas, banco, equipo } } }, ... }, cuantos
--   Bt.Texto(x) -> "Lobato: 7 en bolsas · Alt: 5 en banco"

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D, O = M.Datos, M.Objetos

local type, pairs, ipairs, tonumber, format = type, pairs, ipairs, tonumber, string.format

local Bt = {}
M.Todos = Bt

Bt.MAX = 40

-- Las categorías que se pueden elegir (sin Recientes ni Espacio libre).
function Bt.Tipos()
	local out = {}
	for _, c in ipairs(O.CATEGORIAS) do
		if c.clave ~= "recientes" and c.clave ~= "libre" then out[#out + 1] = c end
	end
	return out
end

local function sumar(res, porId, p, rec, campo)
	local id = tonumber(rec.i)
	if not id then return end
	-- Por objeto y nombre: «Espada del oso» y «Espada del mono» van aparte.
	local clave = id .. ":" .. (O.NombreEnlace(rec.l) or "")
	local x = porId[clave]
	if not x then
		x = { id = id, link = rec.l, q = rec.q, total = 0, partes = {}, porClave = {} }
		porId[clave] = x
		res[#res + 1] = x
	end
	if not x.link and rec.l then x.link = rec.l end
	local parte = x.porClave[p.clave]
	if not parte then
		parte = { clave = p.clave, r = p.r, bolsas = 0, banco = 0, equipo = 0 }
		x.porClave[p.clave] = parte
		x.partes[#x.partes + 1] = parte
	end
	local n = tonumber(rec.c) or 1
	parte[campo] = parte[campo] + n
	x.total = x.total + n
end

-- ¿Pasa los filtros? (cada objeto se mira una vez por id)
local function pasa(rec, filtro, opts, cache)
	local id = rec.i
	local k = id .. ":" .. (O.NombreEnlace(rec.l) or "") .. ":" .. tostring(rec.q)
	local hit = cache[k]
	if hit ~= nil then return hit end
	local e = O.Info(id, rec.l)
	local ok = true
	if opts.calidad ~= nil and rec.q ~= opts.calidad then ok = false end
	if ok and opts.tipo then
		ok = O.CategoriaFija({ i = id, q = rec.q, l = rec.l }, e, nil) == opts.tipo
	end
	if ok and filtro then
		local ent = { rec = { i = id, q = rec.q, l = rec.l }, e = e, cat = O.CategoriaFija({ i = id, q = rec.q, l = rec.l }, e, nil) }
		if O.EsEquipo(e) then ent.nivel = O.Nivel(rec.l) or e.nivelBase end
		ok = O.Coincide(filtro, ent)
	end
	cache[k] = ok
	return ok
end

-- -> resultados (los de mejor calidad y más cantidad primero), cuántos en total
function Bt.Buscar(texto, opts)
	opts = opts or {}
	local filtro = O.Compilar(texto)
	local res, porId, cache = {}, {}, {}
	if not filtro and opts.tipo == nil and opts.calidad == nil and opts.clave == nil then return res, 0 end
	for _, p in ipairs(D.Lista()) do
		if opts.clave == nil or opts.clave == p.clave then
			for _, grupo in ipairs({ { p.r.bolsas, "bolsas" }, { p.r.banco, "banco" } }) do
				if type(grupo[1]) == "table" then
					for _, t in pairs(grupo[1]) do
						if type(t) == "table" then
							for s = 1, tonumber(t.n) or 0 do
								local rec = t[s]
								if type(rec) == "table" and type(rec.i) == "number" and pasa(rec, filtro, opts, cache) then
									sumar(res, porId, p, rec, grupo[2])
								end
							end
						end
					end
				end
			end
			if type(p.r.equipo) == "table" then
				for _, rec in pairs(p.r.equipo) do
					if type(rec) == "table" and type(rec.i) == "number" and pasa(rec, filtro, opts, cache) then
						sumar(res, porId, p, { i = rec.i, l = rec.l, q = rec.q, c = 1 }, "equipo")
					end
				end
			end
		end
	end
	table.sort(res, function(a, b)
		local qa, qb = a.q or 1, b.q or 1
		if qa ~= qb then return qa > qb end
		if a.total ~= b.total then return a.total > b.total end
		return a.id < b.id
	end)
	local cuantos = #res
	for i = cuantos, Bt.MAX + 1, -1 do res[i] = nil end
	for _, x in ipairs(res) do x.porClave = nil end
	return res, cuantos
end

-- "Lobato: 7 en bolsas · Alt: 5 en banco"
function Bt.Texto(x)
	local trozos = {}
	for _, p in ipairs(x.partes or {}) do
		local donde = {}
		if p.bolsas > 0 then donde[#donde + 1] = format(L["%d en bolsas"], p.bolsas) end
		if p.banco > 0 then donde[#donde + 1] = format(L["%d en banco"], p.banco) end
		if p.equipo > 0 then donde[#donde + 1] = format(p.equipo == 1 and L["%d equipado"] or L["%d equipados"], p.equipo) end
		trozos[#trozos + 1] = tostring(p.r.nombre or p.clave) .. ": " .. table.concat(donde, L[" y "])
	end
	return table.concat(trozos, " \194\183 ")
end

-- El nombre de un resultado (el del enlace, con su sufijo).
function Bt.Nombre(x)
	return O.NombreEnlace(x.link) or O.Info(x.id, x.link).nombre or ("#" .. tostring(x.id))
end
