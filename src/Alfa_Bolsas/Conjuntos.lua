-- Alfa - Bolsas: tus conjuntos de equipo (toxic3000 / La Jauría). GPL-3.0. 1.3.0.
--
-- Guarda con un nombre lo que llevas puesto (curar, daño, pesca...) y te lo
-- vuelve a poner con un clic, siempre fuera de combate: en combate el juego
-- no deja cambiar la armadura, así que el cambio espera al final de la pelea
-- (N.FueraDeCombate). Cada pieza se busca en tus bolsas (el mismo enlace o,
-- si no, el mismo objeto) y se pone con C_Item.EquipItemByName(enlace,
-- ranura) (ItemDocumentation.lua: sin HasRestrictions), una tras otra, como
-- «Ponte esto». Lo que no está en tus bolsas (en el banco, vendido) se dice.
-- No usa C_EquipmentSet: el gestor de equipo del juego no está en todas las
-- versiones de Forever, y esto funciona igual en todas.
-- Por personaje: N.DatosPersonaje("bolsas").conjuntos =
--   { { n = nombre, t = time(), p = { [ranura] = { i = id, l = enlace } } }, ... }
-- Ajuste bolsas.conjuntos (de fábrica, encendido).
--   Cj.Lista() ; Cj.Guardar(nombre) ; Cj.Poner(nombre) ; Cj.Olvidar(nombre)
--   Cj.Estado(c) -> puestas, enBolsas, faltan, total ; Cj.Puesto() -> nombre | nil

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local type, pairs, ipairs, tonumber, format, sort = type, pairs, ipairs, tonumber, string.format, table.sort

local Cj = {}
M.Conjuntos = Cj

-- Las ranuras que se guardan: cabeza a la distancia, sin la camisa ni el tabardo.
local RANURAS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local MAX = 10
local ORIGEN = { 0, 1, 2, 3, 4 }

-- Nombres listos para elegir (el menú de la ventana y la página).
Cj.NOMBRES = { L["Curación"], L["Daño"], L["Tanque"], L["Pesca"], L["Recolectar"], L["Ciudad"] }

local function encendido() return M.Get("conjuntos") ~= false end

local function datos()
	local d = N.DatosPersonaje(M.ID)
	if type(d.conjuntos) ~= "table" then d.conjuntos = {} end
	return d.conjuntos
end

local function buscar(nombre)
	if type(nombre) ~= "string" then return nil end
	local lista = datos()
	for i, c in ipairs(lista) do
		if type(c) == "table" and c.n == nombre then return c, i end
	end
	-- Sin distinguir mayúsculas ni acentos (desde el comando).
	local O = M.Objetos
	local buscado = O and O.Doblar(nombre) or nombre:lower()
	for i, c in ipairs(lista) do
		if type(c) == "table" and type(c.n) == "string" and (O and O.Doblar(c.n) or c.n:lower()) == buscado then return c, i end
	end
	return nil
end
Cj.Buscar = buscar

function Cj.Lista()
	local out = {}
	for _, c in ipairs(datos()) do
		if type(c) == "table" and type(c.n) == "string" and type(c.p) == "table" then out[#out + 1] = c end
	end
	return out
end

local function puesto(ranura)
	local id = GetInventoryItemID and M.Num(M.Llamar(GetInventoryItemID, "player", ranura))
	local link = GetInventoryItemLink and M.Texto(M.Llamar(GetInventoryItemLink, "player", ranura))
	return id, link
end

-- -> el conjunto guardado | nil, por qué
function Cj.Guardar(nombre)
	if type(nombre) ~= "string" then return nil end
	nombre = nombre:gsub("^%s+", ""):gsub("%s+$", "")
	if nombre == "" then return nil end
	if #nombre > 40 then nombre = nombre:sub(1, 40) end
	local p, n = {}, 0
	for _, r in ipairs(RANURAS) do
		local id, link = puesto(r)
		if id then
			p[r] = { i = id, l = link }
			n = n + 1
		end
	end
	if n == 0 then
		N.Imprimir(L["No llevas nada puesto que guardar."])
		return nil
	end
	local c = buscar(nombre)
	local lista = datos()
	if not c then
		if #lista >= MAX then
			N.Imprimir(format(L["Ya tienes %d conjuntos: olvida uno primero."], MAX))
			return nil
		end
		c = { n = nombre }
		lista[#lista + 1] = c
	end
	c.p, c.t = p, time and time() or nil
	N.Imprimir(format(L["Guardaste «%s» con %d piezas."], c.n, n))
	M.Avisar("CONJUNTOS")
	return c
end

function Cj.Olvidar(nombre)
	local c, i = buscar(nombre)
	if not c then return false end
	table.remove(datos(), i)
	M.Avisar("CONJUNTOS")
	return true
end

-- Lo que llevas en tus bolsas: -> { { bolsa, casilla, id, link }, ... }
local function enBolsas()
	local C = C_Container
	local out = {}
	if not C then return out end
	for _, b in ipairs(ORIGEN) do
		for s = 1, M.Num(M.Llamar(C.GetContainerNumSlots, b)) or 0 do
			local info = M.Llamar(C.GetContainerItemInfo, b, s)
			local id = type(info) == "table" and M.Num(info.itemID)
			if id then out[#out + 1] = { bolsa = b, casilla = s, id = id, link = M.Texto(info.hyperlink) } end
		end
	end
	return out
end

-- La casilla de una pieza (el mismo enlace primero, luego el mismo objeto).
local function hallar(pieza, lista, usadas)
	for k, x in ipairs(lista) do
		if not usadas[k] and x.id == pieza.i and pieza.l and x.link == pieza.l then return k, x end
	end
	for k, x in ipairs(lista) do
		if not usadas[k] and x.id == pieza.i then return k, x end
	end
	return nil
end

-- Lo que falta de un conjunto: -> puestas, enBolsas, faltan, total
function Cj.Estado(c)
	local puestas, bolsas, faltan, total = 0, 0, 0, 0
	if type(c) ~= "table" or type(c.p) ~= "table" then return 0, 0, 0, 0 end
	local lista, usadas = enBolsas(), {}
	for _, r in ipairs(RANURAS) do
		local pieza = c.p[r]
		if type(pieza) == "table" and pieza.i then
			total = total + 1
			if puesto(r) == pieza.i then
				puestas = puestas + 1
			else
				local k = hallar(pieza, lista, usadas)
				if k then
					usadas[k] = true
					bolsas = bolsas + 1
				else
					faltan = faltan + 1
				end
			end
		end
	end
	return puestas, bolsas, faltan, total
end

-- El conjunto que llevas puesto entero (el primero), o nil.
function Cj.Puesto()
	for _, c in ipairs(Cj.Lista()) do
		local puestas, _, _, total = Cj.Estado(c)
		if total > 0 and puestas == total then return c.n end
	end
	return nil
end

-- -> true (se puso), "espera" (en combate: al terminar), false
function Cj.Poner(nombre)
	if not encendido() then return false end
	local c = buscar(nombre)
	if not c then
		N.Imprimir(format(L["No tienes un conjunto llamado «%s»."], tostring(nombre)))
		return false
	end
	if M.EnCombate() then
		N.Imprimir(format(L["En combate no se puede cambiar el equipo: te pongo «%s» al terminar."], c.n))
		N.FueraDeCombate("bolsas.conjunto", function() Cj.Poner(c.n) end)
		return "espera"
	end
	local CI = C_Item
	if not (CI and CI.EquipItemByName) then return false end
	local lista, usadas = enBolsas(), {}
	local puestas, faltan = 0, 0
	for _, r in ipairs(RANURAS) do
		local pieza = c.p[r]
		if type(pieza) == "table" and pieza.i and puesto(r) ~= pieza.i then
			local k, x = hallar(pieza, lista, usadas)
			if k then
				usadas[k] = true
				M.Seguro(CI.EquipItemByName, x.link or pieza.l or pieza.i, r)
				puestas = puestas + 1
			else
				faltan = faltan + 1
			end
		end
	end
	if puestas == 0 and faltan == 0 then
		N.Imprimir(format(L["Ya llevas puesto «%s»."], c.n))
	else
		local texto = format(L["Te pusiste «%s»: %d piezas."], c.n, puestas)
		if faltan > 0 then texto = texto .. " " .. format(L["Faltan %d que no están en tus bolsas (¿en el banco?)."], faltan) end
		N.Imprimir(texto)
	end
	M.Avisar("CONJUNTOS")
	return true
end

-- El menú de la ventana de bolsas: ponerte un conjunto o guardar lo que llevas.
function Cj.Menu(ancla)
	local K = N.Kit
	if not (K and K.Menu) then return end
	local ops = {}
	local actual = Cj.Puesto()
	for _, c in ipairs(Cj.Lista()) do
		local _, _, faltan = Cj.Estado(c)
		local texto = c.n
		if c.n == actual then texto = texto .. "  " .. L["(puesto)"] end
		if faltan > 0 then texto = texto .. "  " .. format(L["(faltan %d)"], faltan) end
		ops[#ops + 1] = { valor = "poner:" .. c.n, texto = texto, icono = "ic-personaje" }
	end
	if #ops > 0 then ops[#ops + 1] = { separador = true } end
	ops[#ops + 1] = { valor = "guardar", texto = L["Guardar lo que llevas…"], icono = "ic-mas" }
	K.Menu(ancla, ops, nil, function(v)
		if type(v) ~= "string" then return end
		if v == "guardar" then
			M.Luego(0, function() Cj.MenuGuardar(ancla) end)
			return
		end
		local nombre = v:match("^poner:(.+)$")
		if nombre then Cj.Poner(nombre) end
	end, 240)
end

-- Los nombres para guardar: los de siempre y los que ya tienes (se reemplazan).
function Cj.MenuGuardar(ancla)
	local K = N.Kit
	if not (K and K.Menu) then return end
	local ops, vistos = {}, {}
	for _, c in ipairs(Cj.Lista()) do
		vistos[c.n] = true
		ops[#ops + 1] = { valor = c.n, texto = format(L["Reemplazar «%s»"], c.n) }
	end
	for _, n in ipairs(Cj.NOMBRES) do
		if not vistos[n] then ops[#ops + 1] = { valor = n, texto = n } end
	end
	K.Menu(ancla, ops, nil, function(v) Cj.Guardar(v) end, 240)
end
