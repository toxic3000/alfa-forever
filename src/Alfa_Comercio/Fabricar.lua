-- Alfa - Comercio: qué fabricar para ganar más oro (toxic3000 / La Jauría). GPL-3.0. 1.3.0.
--
-- Con tus recetas (Recetas.lua: las que leyó Alfa al abrir tu profesión) y
-- los precios de tu reino (Precios.lua: subasta y comerciante), cuánto deja
-- cada receta: lo que vale el producto (lo mejor entre comerciante y subasta
-- neta, M.ValorVenta) menos lo que cuestan sus reactivos (M.CostoCompra). Y
-- cuántas veces la puedes hacer ya con lo que llevas en bolsas y banco
-- (M.Tienes), con lo que ganarías haciéndolas todas.
-- Solo informa: Alfa nunca fabrica, compra ni vende por ti.
-- Ajuste comercio.fabricar (de fábrica, encendido): las que puedes hacer ya
-- van primero en «Tus recetas que dejan ganancia».
--   M.Fabricar({ soloMias }) -> { { e = { rec, id, quien, propio }, valor, costo, gana, veces, conBanco, total }, ... }, incompletas
-- 1.3.3: `veces` cuenta solo lo de tus bolsas; `conBanco`, cuántas más con lo del banco.
--   AlfaComercio.Fabricar() -> lo mismo (solo las tuyas)

local _, M = ...
local N = AlfaNucleo

local type, ipairs, floor, min = type, ipairs, math.floor, math.min

-- 1.3.3: lo que llevas en las bolsas (con eso fabricas ya: lo del banco no
-- se puede usar sin ir por él). AlfaBolsas.Cuantos -> tuyos, en bolsas, ...
function M.EnBolsas(id)
	if type(id) ~= "number" then return 0 end
	local B = rawget(_G, "AlfaBolsas")
	if type(B) == "table" and type(B.Cuantos) == "function" then
		local ok, _, bolsas = pcall(B.Cuantos, id)
		if ok and type(bolsas) == "number" then return bolsas end
	end
	local CI = C_Item
	local f = (CI and CI.GetItemCount) or rawget(_G, "GetItemCount")
	if type(f) == "function" then
		local ok, n = pcall(f, id, false)
		if ok and type(n) == "number" and not (issecretvalue and issecretvalue(n)) then return n end
	end
	return 0
end

local function veces(rec, memo, contar)
	local v
	for i = 1, #rec.r, 2 do
		local id, cant = rec.r[i], rec.r[i + 1]
		if type(id) == "number" and type(cant) == "number" and cant > 0 then
			if memo[id] == nil then memo[id] = contar(id) or 0 end
			local n = floor(memo[id] / cant)
			v = v and min(v, n) or n
		end
	end
	return v or 0
end

-- Cuántas veces alcanza lo que llevas en tus bolsas para una receta (0 si
-- falta algo), y cuántas más con lo del banco.
-- -> veces (bolsas), más (con el banco)
function M.VecesQueAlcanza(rec, memo, memoTodo)
	memo, memoTodo = memo or {}, memoTodo or {}
	if type(rec) ~= "table" or type(rec.r) ~= "table" then return 0, 0 end
	local ya = veces(rec, memo, M.EnBolsas)
	local todo = veces(rec, memoTodo, M.Tienes)
	return ya, math.max(0, todo - ya)
end

-- -> lista (lo que más deja primero), cuántas no se pudieron calcular
function M.Fabricar(opts)
	opts = opts or {}
	local primeroLoQueTienes = M.Ajuste("fabricar") ~= false
	local out, incompletas, memo, memoTodo = {}, 0, {}, {}
	for _, e in ipairs(M.TodasLasRecetas()) do
		if not opts.soloMias or e.propio then
			local valor, costo, completo = M.CuentaReceta(e.rec)
			if completo then
				if valor > costo then
					local x = { e = e, valor = valor, costo = costo, gana = valor - costo, veces = 0, total = 0 }
					if e.propio then
						x.veces, x.conBanco = M.VecesQueAlcanza(e.rec, memo, memoTodo)
						x.total = x.veces * x.gana
					end
					out[#out + 1] = x
				end
			else
				incompletas = incompletas + 1
			end
		end
	end
	table.sort(out, function(a, b)
		if primeroLoQueTienes and (a.total > 0) ~= (b.total > 0) then return a.total > 0 end
		if primeroLoQueTienes and a.total ~= b.total then return a.total > b.total end
		if a.gana ~= b.gana then return a.gana > b.gana end
		return tostring(a.e.rec.n) < tostring(b.e.rec.n)
	end)
	return out, incompletas
end

AlfaComercio = type(AlfaComercio) == "table" and AlfaComercio or {}
AlfaComercio.Fabricar = function() return (M.Fabricar({ soloMias = true })) end
