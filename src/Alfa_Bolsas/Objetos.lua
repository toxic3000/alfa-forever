-- Alfa - Bolsas: lo que se sabe de cada objeto, sus categorías y la búsqueda.
-- GPL-3.0.
--
--   O.Info(id, link) -> { clase, subclase, ranura, icono, nombre, tipo, subtipo, listo }
--   O.Nivel(link) -> nivel de objeto del equipo | nil
--   O.EsEquipo(info) -> bool
--   O.Categoria(rec, info, bolsa) -> clave de O.CATEGORIAS
--   O.Compilar(texto) -> filtro | nil ;  O.Coincide(filtro, entrada) -> bool
--   O.Antes(a, b) -> orden dentro de una categoría
-- Un objeto que el cliente aún no tiene en caché se pide y, al llegar
-- (GET_ITEM_INFO_RECEIVED), se avisa "ITEM" para volver a pintarlo.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local type, pairs, ipairs, tonumber, tostring = type, pairs, ipairs, tonumber, tostring
local floor = math.floor

local O = {}
M.Objetos = O

O.CATEGORIAS = {
	{ clave = "recientes", nombre = L["Recientes"] },
	{ clave = "equipo", nombre = L["Equipo"] },
	{ clave = "consumibles", nombre = L["Consumibles"] },
	{ clave = "misiones", nombre = L["Misiones"] },
	{ clave = "artesania", nombre = L["Artesanía y comercio"] },
	{ clave = "reagentes", nombre = L["Componentes"] },
	{ clave = "monturas", nombre = L["Monturas y mascotas"] },
	{ clave = "chatarra", nombre = L["Chatarra"] },
	{ clave = "otros", nombre = L["Otros"] },
	{ clave = "libre", nombre = L["Espacio libre"] },
}
O.NOMBRE = {}
for i, c in ipairs(O.CATEGORIAS) do
	O.NOMBRE[c.clave] = c.nombre
	c.orden = i
end

local CI = C_Item

---------------------------------------------------------------------------
-- Texto sin acentos y en minúsculas, para comparar.
---------------------------------------------------------------------------

local ACENTOS = {}
do
	local grupos = {
		a = { 160, 161, 162, 163, 164, 165, 128, 129, 130, 131, 132, 133 },
		e = { 168, 169, 170, 171, 136, 137, 138, 139 },
		i = { 172, 173, 174, 175, 140, 141, 142, 143 },
		o = { 178, 179, 180, 181, 182, 146, 147, 148, 149, 150 },
		u = { 185, 186, 187, 188, 153, 154, 155, 156 },
		n = { 177, 145 },
		c = { 167, 135 },
	}
	for letra, bytes in pairs(grupos) do
		for _, b in ipairs(bytes) do ACENTOS["\195" .. string.char(b)] = letra end
	end
end

function O.Doblar(s)
	if type(s) ~= "string" then return "" end
	return (s:lower():gsub("\195[\128-\191]", ACENTOS))
end

---------------------------------------------------------------------------
-- Datos de cada objeto
---------------------------------------------------------------------------

local info, pedidos = {}, {}
local cuantos = 0
local TOPE = 3000

local function pedir(id)
	if pedidos[id] then return end
	pedidos[id] = true
	if CI and CI.RequestLoadItemDataByID then pcall(CI.RequestLoadItemDataByID, id) end
end

function O.Info(id, link)
	id = tonumber(id)
	if not id then return {} end
	local e = info[id]
	if e and e.listo then return e end
	if not e then
		if cuantos >= TOPE then
			info, cuantos = {}, 0
		end
		local _, tipo, subtipo, ranura, icono, clase, subclase = M.Llamar(CI and CI.GetItemInfoInstant, link or id)
		e = {
			clase = M.Num(clase), subclase = M.Num(subclase), ranura = M.Texto(ranura),
			icono = M.Leer(icono), tipo = M.Texto(tipo), subtipo = M.Texto(subtipo),
		}
		info[id] = e
		cuantos = cuantos + 1
	end
	local nombre, _, _, nivel, req, tipo, subtipo, _, _, icono = M.Llamar(CI and CI.GetItemInfo, link or id)
	nombre = M.Texto(nombre)
	if nombre then
		e.nombre = nombre
		e.doblado = O.Doblar(nombre)
		e.nivelBase = M.Num(nivel)
		e.req = M.Num(req)
		e.tipo = M.Texto(tipo) or e.tipo
		e.subtipo = M.Texto(subtipo) or e.subtipo
		e.icono = e.icono or M.Leer(icono)
		e.listo = true
	else
		pedir(id)
	end
	return e
end

function O.EsEquipo(e)
	if type(e) ~= "table" then return false end
	if e.clase ~= 2 and e.clase ~= 4 then return false end
	local r = e.ranura
	return r ~= nil and r ~= "" and r ~= "INVTYPE_NON_EQUIP_IGNORE" and r ~= "INVTYPE_NON_EQUIP"
end

local niveles, nNiveles = {}, 0

-- Nivel de objeto de una pieza de equipo (con sus sufijos), por enlace.
function O.Nivel(link)
	if type(link) ~= "string" then return nil end
	local hit = niveles[link]
	if hit then return hit end
	local n = M.Num(M.Llamar(CI and CI.GetDetailedItemLevelInfo, link))
	if n and n > 0 then
		if nNiveles >= TOPE then niveles, nNiveles = {}, 0 end
		niveles[link] = n
		nNiveles = nNiveles + 1
		return n
	end
	return nil
end

A.RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, id)
	id = M.Num(id)
	if not (id and pedidos[id]) then return end
	pedidos[id] = nil
	local e = info[id]
	if e then e.listo = nil end
	M.Avisar("ITEM", id)
end)

---------------------------------------------------------------------------
-- Categorías
---------------------------------------------------------------------------

-- rec: { i, c, l, q, nuevo, mision, sinValor, basura (marcado como chatarra) }; e: O.Info.
function O.Categoria(rec, e, bolsa)
	if rec.nuevo then return "recientes" end
	if (rec.q == 0 or rec.basura) and not rec.sinValor then return "chatarra" end
	local c, s = e.clase, e.subclase
	if rec.mision or c == 12 then return "misiones" end
	if c == 2 or c == 4 then return "equipo" end
	if c == 0 then return "consumibles" end
	if c == 5 or (c == 15 and s == 1) or bolsa == M.Datos.REAGENTES then return "reagentes" end
	if c == 7 or c == 9 or c == 19 or c == 3 or c == 8 or c == 16 then return "artesania" end
	if c == 17 or (c == 15 and (s == 2 or s == 5 or s == 6)) then return "monturas" end
	return "otros"
end

-- La categoría de un objeto por lo que es, sin "Recientes" (para depositar
-- por categoría): la misma regla que O.Categoria.
function O.CategoriaFija(rec, e, bolsa)
	if rec.nuevo then
		local r = {}
		for k, v in pairs(rec) do r[k] = v end
		r.nuevo = nil
		return O.Categoria(r, e, bolsa)
	end
	return O.Categoria(rec, e, bolsa)
end

-- Materiales de oficio: artículos comerciables (7), componentes (5 y 15/1)
-- y gemas (3). Lo que se deposita con "Todos los materiales".
function O.EsMaterial(e)
	if type(e) ~= "table" then return false end
	local c, s = e.clase, e.subclase
	return c == 7 or c == 5 or c == 3 or (c == 15 and s == 1)
end

-- Dentro de una categoría: mejor calidad, mayor nivel, por nombre, por objeto,
-- montones grandes primero y, al final, su lugar en las bolsas.
function O.Antes(a, b)
	local qa, qb = a.rec.q or 1, b.rec.q or 1
	if qa ~= qb then return qa > qb end
	local la, lb = a.nivel or 0, b.nivel or 0
	if la ~= lb then return la > lb end
	local na, nb = a.e.doblado or "", b.e.doblado or ""
	if na ~= nb then return na < nb end
	if a.rec.i ~= b.rec.i then return a.rec.i < b.rec.i end
	local ca, cb = a.rec.c or 1, b.rec.c or 1
	if ca ~= cb then return ca > cb end
	return (a.orden or 0) < (b.orden or 0)
end

---------------------------------------------------------------------------
-- Búsqueda: palabras (nombre, tipo, calidad, categoría, ranura) y números
-- de nivel de objeto: "20", ">20", "<=30", "20-30". Todas deben coincidir.
---------------------------------------------------------------------------

local RELLENO = { nivel = true, nv = true, ilvl = true, lvl = true, level = true, de = true, del = true, ["la"] = true, ["el"] = true }

-- Palabras de cada calidad que un principiante puede escribir.
local COLORES = {
	[0] = { L["gris"], L["pobre"], L["chatarra"] },
	[1] = { L["blanco"], L["común"] },
	[2] = { L["verde"], L["poco común"] },
	[3] = { L["azul"], L["raro"] },
	[4] = { L["morado"], L["épico"] },
	[5] = { L["naranja"], L["legendario"] },
}

function O.Compilar(texto)
	if type(texto) ~= "string" then return nil end
	local t = O.Doblar(texto)
	t = t:gsub("^%s+", ""):gsub("%s+$", "")
	if t == "" then return nil end
	local f = { palabras = {}, numeros = {} }
	for tok in t:gmatch("%S+") do
		local op, n = tok:match("^([<>]=?)(%d+)$")
		local a, b = tok:match("^(%d+)%-(%d+)$")
		if op then
			f.numeros[#f.numeros + 1] = { op, tonumber(n) }
		elseif a then
			local x, y = tonumber(a), tonumber(b)
			if x > y then x, y = y, x end
			f.numeros[#f.numeros + 1] = { "entre", x, y }
		elseif tok:match("^%d+$") then
			f.numeros[#f.numeros + 1] = { "=", tonumber(tok) }
		elseif not RELLENO[tok] then
			f.palabras[#f.palabras + 1] = tok
		end
	end
	if #f.palabras == 0 and #f.numeros == 0 then return nil end
	return f
end

local function pajar(ent)
	if ent.pajar and ent.pajarListo == (ent.e.listo and true or false) then return ent.pajar end
	local e, rec = ent.e, ent.rec
	local partes = { e.doblado or "", O.Doblar(e.tipo), O.Doblar(e.subtipo), O.Doblar(O.NOMBRE[ent.cat] or "") }
	local q = rec.q
	if type(q) == "number" then
		partes[#partes + 1] = O.Doblar(_G["ITEM_QUALITY" .. q .. "_DESC"])
		for _, w in ipairs(COLORES[q] or {}) do partes[#partes + 1] = O.Doblar(w) end
	end
	if e.ranura and e.ranura ~= "" then partes[#partes + 1] = O.Doblar(_G[e.ranura]) end
	if ent.mejora then partes[#partes + 1] = O.Doblar(L["mejora"]) end
	if rec.nuevo then partes[#partes + 1] = O.Doblar(L["nuevo"]) end
	if rec.mision then partes[#partes + 1] = O.Doblar(L["misión"]) end
	ent.pajar = " " .. table.concat(partes, " ") .. " "
	ent.pajarListo = e.listo and true or false
	return ent.pajar
end

function O.Coincide(f, ent)
	if not f then return true end
	if not (ent and ent.rec) then return false end
	for _, c in ipairs(f.numeros) do
		local n = ent.nivel
		if not n then return false end
		local op, x, y = c[1], c[2], c[3]
		if op == "=" then if n ~= x then return false end
		elseif op == ">" then if not (n > x) then return false end
		elseif op == ">=" then if not (n >= x) then return false end
		elseif op == "<" then if not (n < x) then return false end
		elseif op == "<=" then if not (n <= x) then return false end
		elseif op == "entre" then if n < x or n > y then return false end
		end
	end
	if #f.palabras > 0 then
		local h = pajar(ent)
		for _, w in ipairs(f.palabras) do
			if not h:find(w, 1, true) then return false end
		end
	end
	return true
end
