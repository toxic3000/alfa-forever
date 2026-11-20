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
--   M.Fabricar({ soloMias }) -> { { e = { rec, id, quien, propio }, valor, costo, gana, veces, total }, ... }, incompletas
--   AlfaComercio.Fabricar() -> lo mismo (solo las tuyas)

local _, M = ...
local N = AlfaNucleo

local type, ipairs, floor, min = type, ipairs, math.floor, math.min

-- Cuántas veces alcanza lo que tienes para una receta (0 si falta algo).
function M.VecesQueAlcanza(rec, memo)
	memo = memo or {}
	if type(rec) ~= "table" or type(rec.r) ~= "table" then return 0 end
	local veces
	for i = 1, #rec.r, 2 do
		local id, cant = rec.r[i], rec.r[i + 1]
		if type(id) == "number" and type(cant) == "number" and cant > 0 then
			if memo[id] == nil then memo[id] = M.Tienes(id) or 0 end
			local n = floor(memo[id] / cant)
			veces = veces and min(veces, n) or n
		end
	end
	return veces or 0
end

-- -> lista (lo que más deja primero), cuántas no se pudieron calcular
function M.Fabricar(opts)
	opts = opts or {}
	local primeroLoQueTienes = M.Ajuste("fabricar") ~= false
	local out, incompletas, memo = {}, 0, {}
	for _, e in ipairs(M.TodasLasRecetas()) do
		if not opts.soloMias or e.propio then
			local valor, costo, completo = M.CuentaReceta(e.rec)
			if completo then
				if valor > costo then
					local x = { e = e, valor = valor, costo = costo, gana = valor - costo, veces = 0, total = 0 }
					if e.propio then
						x.veces = M.VecesQueAlcanza(e.rec, memo)
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
