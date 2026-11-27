-- Alfa - Comercio: lo que el comerciante vende más barato que la subasta (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Algunos comerciantes venden barato lo que en la subasta vale mucho más:
-- recetas de existencias limitadas, bolsas, tintes, algún material. Al
-- hablar con uno, Alfa compara su precio con el de la subasta que conoce
-- (Precios.lua, al día y menos la comisión) y, si vale la pena, un aviso lo
-- dice: «Receta: Capa de lino rojo, 40p aquí; en la subasta vale 3o».
-- Nunca compra: Alt+clic compra una pila (Pila.lua) o la compras como siempre.
--
-- Cuándo avisa: lo que te deja (subasta menos comisión menos su precio) es
-- por lo menos la mitad de lo que cuesta y suma al menos 1 oro con lo que
-- tiene (o con una pila, si no se acaba); sin precios viejos ni objetos que
-- se pagan con otra cosa. Un aviso por comerciante y por día.
-- Ajuste comercio.reventa (sí).
--
--   Rv.Buscar() -> { { i, id, nombre, precio, vale, gana, cuantos } } (lo que más deja primero)

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, ipairs, pcall, tonumber, floor, max, min, format = type, ipairs, pcall, tonumber, math.floor, math.max, math.min, string.format

local Rv = {}
M.Reventa = Rv

Rv.MARGEN = 0.50   -- lo que te deja, contra lo que cuesta
Rv.MINIMO = 10000  -- cobre: 1 oro en total

local function num(v) return N.LeerNumero and N.LeerNumero(v) or tonumber(N.Leer(v)) end
local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d, e, f, g, h
end

local function venta(i)
	local CM = rawget(_G, "C_MerchantFrame")
	if type(CM) == "table" and type(CM.GetItemInfo) == "function" then
		local info = llamar(CM.GetItemInfo, i)
		if type(info) ~= "table" then return nil end
		return N.Leer(info.name), num(info.price), num(info.stackCount), num(info.numAvailable), N.Si(info.hasExtendedCost)
	end
	local nombre, _, precio, porCompra, hay, _, _, otra = llamar(rawget(_G, "GetMerchantItemInfo"), i)
	return N.Leer(nombre), num(precio), num(porCompra), num(hay), N.Si(otra)
end

local function monton(id)
	local CI = rawget(_G, "C_Item")
	local f = (type(CI) == "table" and CI.GetItemInfo) or rawget(_G, "GetItemInfo")
	local _, _, _, _, _, _, _, m = llamar(f, id)
	return max(1, num(m) or 1)
end

function Rv.Buscar()
	local out = {}
	local n = num(llamar(rawget(_G, "GetMerchantNumItems"))) or 0
	for i = 1, min(n, 200) do
		local id = num(llamar(rawget(_G, "GetMerchantItemID"), i))
		local nombre, precio, porCompra, hay, otra = venta(i)
		if id and precio and precio > 0 and not otra then
			local unidad = precio / max(1, porCompra or 1)
			local bruto, fecha = M.PrecioSubasta(id)
			local vale = bruto and not M.Viejo(fecha) and M.NetoSubasta(bruto) or nil
			if vale and vale > unidad then
				local gana = vale - unidad
				-- Lo que se puede comprar: lo que tiene o, sin límite, una pila.
				local cuantos = (hay and hay > 0) and hay * max(1, porCompra or 1) or monton(id)
				if gana >= unidad * Rv.MARGEN and gana * cuantos >= Rv.MINIMO then
					out[#out + 1] = { i = i, id = id, nombre = nombre or ("#" .. id), precio = floor(unidad + 0.5),
						vale = vale, gana = floor(gana + 0.5), cuantos = cuantos, limitado = hay and hay > 0 or false }
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.gana * a.cuantos > b.gana * b.cuantos end)
	return out
end

local avisados = {} -- "comerciante:día" -> true

local function quien()
	local g = N.Leer(llamar(rawget(_G, "UnitGUID"), "npc"))
	if type(g) == "string" then return g:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)") or g end
	return N.Leer(llamar(rawget(_G, "UnitName"), "npc")) or "?"
end

function Rv.Avisar()
	if M.Ajuste("reventa") == false or not (K and K.Aviso) then return nil end
	if InCombatLockdown and InCombatLockdown() then return nil end
	local lista = Rv.Buscar()
	if #lista == 0 then return nil end
	local clave = tostring(quien()) .. ":" .. floor(M.Ahora() / 86400)
	if avisados[clave] then return nil end
	avisados[clave] = true
	local partes = {}
	for k, e in ipairs(lista) do
		if k > 3 then break end
		partes[#partes + 1] = format(L["%s: %s aquí, en la subasta %s"], e.nombre, M.Dinero(e.precio), M.Dinero(e.vale))
	end
	local o = {
		id = "comercio.reventa", icono = "ic-oro", tono = "exito", duracion = 14, prioridad = "util",
		titulo = N.Plural(#lista, L["Este comerciante vende %d cosa barata"], L["Este comerciante vende %d cosas baratas"]),
		texto = table.concat(partes, " · ") .. ". " .. L["Ya con la comisión. Alt+clic compra una pila."],
		donde = L["La ventana del comerciante"],
	}
	K.Aviso(o)
	return o
end

-- Después de que Precios.lua lee los precios (0,3 s) y del aviso de reponer (0,5 s).
A.RegisterEvent("MERCHANT_SHOW", function() N.Una("comercio.reventa", 0.8, Rv.Avisar) end)
