-- Alfa - Bolsas: lo que se sabe de cada objeto, sus categorías y la búsqueda.
-- GPL-3.0.
--
--   O.Info(id, link) -> { clase, subclase, ranura, icono, nombre, tipo, subtipo, listo }
--   O.Nivel(link) -> nivel de objeto del equipo | nil
--   O.EsEquipo(info) -> bool
--   O.Categoria(rec, info, bolsa) -> clave de O.CATEGORIAS
--   O.Compilar(texto) -> filtro | nil ;  O.Coincide(filtro, entrada) -> bool
--   O.Antes(a, b) -> orden dentro de una categoría
-- 1.3.9: la búsqueda también entiende lo que es cada cosa: «arma»,
-- «armadura», «material», «comida», «poción», «receta», «montura»...; y lo
-- que Alfa sabe de ella: «candado», «sin usar» (equipo que no llevas, que no
-- es mejora ni está en un conjunto tuyo, o que aún no puedes usar), «sobra»
-- (para vender) y «subasta». Una palabra con «-» delante quita: «-gris».
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
	{ clave = "misiones", nombre = L["Misiones [bolsas]"] },
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

-- Cirílico (1.1.9): string.lower de WoW no baja las mayúsculas rusas, así
-- que «Медь» no encontraba «медь». Mayúsculas a minúsculas, y Ё ё como е
-- (como hace la búsqueda del motor, Core/Search.lua).
local CIRILICO = {}
do
	for b = 0x90, 0x9F do CIRILICO["\208" .. string.char(b)] = "\208" .. string.char(b + 0x20) end
	for b = 0xA0, 0xAF do CIRILICO["\208" .. string.char(b)] = "\209" .. string.char(b - 0x20) end
	CIRILICO["\208\129"], CIRILICO["\209\145"] = "\208\181", "\208\181"
end

function O.Doblar(s)
	if type(s) ~= "string" then return "" end
	-- 1.3.9: los acentos antes de bajar a minúsculas (un lower() que mire el
	-- idioma del sistema cambiaba el primer byte de «ó» y ya no se encontraba).
	s = s:gsub("\195[\128-\191]", ACENTOS):lower()
	if s:find("[\208\209]") then s = s:gsub("[\208\209][\128-\191]", CIRILICO) end
	return s
end

---------------------------------------------------------------------------
-- Datos de cada objeto
---------------------------------------------------------------------------

local info, pedidos = {}, {}
local cuantos = 0
local TOPE = 3000

-- 1.3.0: un pedido que el juego nunca contestó se repite pasado REPEDIR
-- segundos (antes quedaba pedido para siempre y el objeto, sin nombre).
local REPEDIR = 10
local function ahora() return GetTime and GetTime() or 0 end

local function pedir(id)
	local cuando = pedidos[id]
	if cuando and ahora() - cuando < REPEDIR then return end
	pedidos[id] = ahora()
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
	if a.rec.i == b.rec.i and a.rec.l ~= b.rec.l then
		na, nb = O.Doblar(O.NombreEnlace(a.rec.l) or na), O.Doblar(O.NombreEnlace(b.rec.l) or nb)
	end
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
	local f = { palabras = {}, numeros = {}, sin = {} }
	for tok in t:gmatch("%S+") do
		local op, n = tok:match("^([<>]=?)(%d+)$")
		local a, b = tok:match("^(%d+)%-(%d+)$")
		local quita = tok:match("^%-(.+)$")
		if quita and not quita:match("^%d") then
			-- 1.3.9: «-gris» quita lo gris.
			if not RELLENO[quita] then f.sin[#f.sin + 1] = quita end
		elseif op then
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
	if #f.palabras == 0 and #f.numeros == 0 and #f.sin == 0 then return nil end
	return f
end

-- 1.3.9: las palabras de lo que es cada objeto (por su clase y subclase).
local function porClase(e)
	local out = {}
	local c, s = e.clase, e.subclase
	if c == 2 then out[#out + 1] = L["arma"] end
	if c == 4 then out[#out + 1] = L["armadura"] end
	if c == 0 then
		out[#out + 1] = L["consumible"]
		if s == 5 then out[#out + 1] = L["comida"] out[#out + 1] = L["bebida"] end
		if s == 1 or s == 2 or s == 3 then out[#out + 1] = L["poción"] end
	end
	if O.EsMaterial(e) then out[#out + 1] = L["material"] end
	if c == 9 then out[#out + 1] = L["receta"] end
	if c == 1 then out[#out + 1] = L["bolsa"] end
	if c == 15 and s == 5 then out[#out + 1] = L["montura"] end
	return out
end

-- Lo que Alfa sabe de él (cambia con el candado, la sugerencia y tus conjuntos:
-- por eso lleva su versión, O.version).
O.version = 0
local enConjuntos, conjuntosVer = nil, -1
local function enUnConjunto(id)
	if conjuntosVer ~= O.version or not enConjuntos then
		enConjuntos, conjuntosVer = {}, O.version
		local Cj = M.Conjuntos
		if Cj and Cj.Lista and M.Get("conjuntos") ~= false then
			local ok, lista = pcall(Cj.Lista)
			for _, c in ipairs(ok and lista or {}) do
				for _, pieza in pairs(c.p or {}) do
					local i = type(pieza) == "table" and tonumber(pieza.i)
					if i then enConjuntos[i] = true end
				end
			end
		end
	end
	return enConjuntos[id] == true
end

local function deAlfa(ent)
	local out = {}
	local e, rec = ent.e, ent.rec
	local id = tonumber(rec.i)
	local Cd = M.Candado
	if Cd and id and Cd.Tiene(id, rec.l, { q = rec.q, mision = rec.mision }) then out[#out + 1] = L["candado"] end
	if O.EsEquipo(e) and id then
		local nivel = UnitLevel and tonumber(UnitLevel("player")) or nil
		local noPuedes = e.req and nivel and e.req > nivel
		if noPuedes or (not ent.mejora and not enUnConjunto(id)) then out[#out + 1] = L["sin usar"] end
	end
	local Sp = M.Separar
	local clase = Sp and Sp.Clase and id and Sp.Clase(id) or nil
	if clase == "vendedor" then out[#out + 1] = L["sobra"] out[#out + 1] = L["vender"] end
	if clase == "subasta" then out[#out + 1] = L["subasta"] end
	return out
end

-- El nombre que trae el enlace: con su sufijo ("del oso"), que el de la caché
-- por id (el primero que se vio) no tiene.
function O.NombreEnlace(link)
	return type(link) == "string" and link:match("|h%[(.-)%]|h") or (type(link) == "string" and link:match("%[(.-)%]")) or nil
end

local function pajar(ent)
	if ent.pajar and ent.pajarListo == (ent.e.listo and true or false) and ent.pajarVer == O.version then return ent.pajar end
	local e, rec = ent.e, ent.rec
	local partes = { e.doblado or "", O.Doblar(e.tipo), O.Doblar(e.subtipo), O.Doblar(O.NOMBRE[ent.cat] or "") }
	-- 1.3.0: el nombre del enlace, con su sufijo («Espada del mono»).
	local propio = O.NombreEnlace(rec.l)
	if propio then partes[#partes + 1] = O.Doblar(propio) end
	local q = rec.q
	if type(q) == "number" then
		partes[#partes + 1] = O.Doblar(_G["ITEM_QUALITY" .. q .. "_DESC"])
		for _, w in ipairs(COLORES[q] or {}) do partes[#partes + 1] = O.Doblar(w) end
	end
	if e.ranura and e.ranura ~= "" then partes[#partes + 1] = O.Doblar(_G[e.ranura]) end
	if ent.mejora then partes[#partes + 1] = O.Doblar(L["mejora"]) end
	if rec.nuevo then partes[#partes + 1] = O.Doblar(L["nuevo"]) end
	if rec.mision then partes[#partes + 1] = O.Doblar(L["misión"]) end
	for _, w in ipairs(porClase(e)) do partes[#partes + 1] = O.Doblar(w) end
	for _, w in ipairs(deAlfa(ent)) do partes[#partes + 1] = O.Doblar(w) end
	ent.pajar = " " .. table.concat(partes, " ") .. " "
	ent.pajarListo = e.listo and true or false
	ent.pajarVer = O.version
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
	if #f.palabras > 0 or #(f.sin or {}) > 0 then
		local h = pajar(ent)
		for _, w in ipairs(f.palabras) do
			if not h:find(w, 1, true) then return false end
		end
		for _, w in ipairs(f.sin or {}) do
			if h:find(w, 1, true) then return false end
		end
	end
	return true
end

-- 1.3.9: lo que Alfa sabe cambió: las búsquedas lo vuelven a mirar.
local function otraVersion() O.version = O.version + 1 end
M.Escuchar("CANDADO", otraVersion)
M.Escuchar("SUGERENCIAS", otraVersion)
M.Escuchar("CONJUNTOS", otraVersion)
