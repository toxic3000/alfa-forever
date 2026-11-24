-- Alfa - Comercio: tu lista de compras con lo de todos tus personajes
-- (toxic3000 / La Jauría). GPL-3.0. 1.3.8.
--
-- Lo que ya tienen tus otros personajes (bolsas, banco y equipo, la última
-- foto que guardó Alfa_Bolsas) se descuenta de lo que te falta comprar, y
-- cada material dice quién lo tiene: «Lobato: 4 · Alt: 2». Ajuste
-- comercio.listaCuenta (de fábrica, sí). Solo se lee lo guardado: nada se
-- mueve ni se manda solo (para traerlo, el buzón y «Mandar a tu alt»).
--
--   M.TienesOtros(id) -> lo de tus otros personajes (0 con el ajuste apagado)
--   M.TextoOtros(id, max) -> «Lobato: 4 · Alt: 2» | nil

local _, M = ...
local N = AlfaNucleo
local L = M.L

local type, ipairs, pcall, format, sort, concat = type, ipairs, pcall, string.format, table.sort, table.concat

local function quienes(id)
	local B = rawget(_G, "AlfaBolsas")
	if type(id) ~= "number" or type(B) ~= "table" or type(B.QuienTiene) ~= "function" then return {} end
	local ok, lista = pcall(B.QuienTiene, id)
	if not ok or type(lista) ~= "table" then return {} end
	return lista
end

local function cuenta() return M.Ajuste("listaCuenta") ~= false end

function M.TienesOtros(id)
	if not cuenta() then return 0 end
	local n = 0
	for _, x in ipairs(quienes(id)) do
		n = n + (tonumber(x.bolsas) or 0) + (tonumber(x.banco) or 0) + (tonumber(x.equipo) or 0)
	end
	return n
end

function M.TextoOtros(id, maximo)
	if not cuenta() then return nil end
	local lista = {}
	for _, x in ipairs(quienes(id)) do
		local n = (tonumber(x.bolsas) or 0) + (tonumber(x.banco) or 0) + (tonumber(x.equipo) or 0)
		if n > 0 then lista[#lista + 1] = { nombre = tostring(x.nombre or "?"), n = n } end
	end
	if #lista == 0 then return nil end
	sort(lista, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.nombre < b.nombre end)
	maximo = maximo or 2
	local partes = {}
	for i, x in ipairs(lista) do
		if i > maximo then
			partes[#partes + 1] = format(L["%d más"], #lista - maximo)
			break
		end
		partes[#partes + 1] = format(L["%s: %d"], x.nombre, x.n)
	end
	return concat(partes, " \194\183 ")
end

-- «Tienes 5 de 12 · Alt: 4» (lo tuyo y, si hay, lo de tus otros personajes).
function M.TextoTienes(x)
	local t = format(L["Tienes %d de %d"], x.tienes or 0, x.necesita or 0)
	local otros = M.TextoOtros(x.id)
	if otros then t = t .. " \194\183 " .. otros end
	return t
end
