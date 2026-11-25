-- Alfa - Rutas: «Comprar lo que falta» en las guías de oficios de Alfa
-- (1.4.0, plan 31; toxic3000 / La Jauría). GPL-3.0.
--
-- En el paso «Tus materiales para 225–300» de una guía de oficio, el
-- rastreador sugiere (con su X, Rs.Sugerencia) comprar en la subasta lo que
-- te falta del tramo y no vende ningún comerciante: un clic lo pone en tu
-- lista de compras de Comercio (AlfaComercio.Lista.AgregarCompras), donde ves
-- cuánto cuesta, y con la subasta abierta Comercio te avisa cuando algo de
-- tu lista sale barato (Buscados.lua). Alfa nunca compra: la compra es tuya.
--   Oc.Faltan(id, indice) -> linea, { { id, n, faltan, precio } }, costo, completo, hasta | nil
--   Oc.Aviso(v, live) -> sugerencia del rastreador | nil ; Oc.Comprar(id, indice) -> ok

local ADDON, M = ...
local A, L, N, K = M.A, M.L, M.N, M.K

local type, ipairs, format, max = type, ipairs, string.format, math.max

local Oc = {}
M.OficiosComprar = Oc

local function Of() return M.OficiosGuia end

function Oc.Faltan(id, indice)
	local Ofi = Of()
	local g = Ofi and Ofi.comprar and Ofi.comprar[id]
	local c = g and g.pasos[indice]
	if not c then return nil end
	local out, costo, completo = {}, 0, true
	for _, x in ipairs(c.lista) do
		local otros = Ofi.Otros(x.id)
		local faltan = max(0, x.n - Ofi.Aqui(x.id) - otros)
		if faltan > 0 then
			local p = Ofi.Precio(x.id)
			out[#out + 1] = { id = x.id, n = x.n, faltan = faltan, precio = p }
			if p then costo = costo + p * faltan else completo = false end
		end
	end
	if #out == 0 then return nil end
	return g.linea, out, costo, completo, c.hasta
end

function Oc.Comprar(id, indice)
	local linea, lista, _, _, hasta = Oc.Faltan(id, indice)
	local C = rawget(_G, "AlfaComercio")
	local Li = type(C) == "table" and C.Lista
	if not (linea and type(Li) == "table" and type(Li.AgregarCompras) == "function") then return false end
	local ok, bien = pcall(Li.AgregarCompras, linea, lista, hasta)
	if ok and bien then
		K.Aviso({ titulo = L["Lista de compras"], icono = "ic-exito", tono = "exito", pedido = true,
			texto = N.Plural(#lista, L["Puse %d material en tu lista de compras. Con la subasta abierta te aviso si sale barato."],
				L["Puse %d materiales en tu lista de compras. Con la subasta abierta te aviso si salen baratos."]),
			donde = L["Comercio > Tu lista de compras"] })
		return true
	end
	return false
end

function Oc.Aviso(v, live)
	if not (v and live and v.index == live) then return nil end
	local E = A.Engine
	local g = E and E.GetGuide and E.GetGuide()
	if not (g and Of() and Of().LineaDe(g.id)) then return nil end
	local id, i = g.id, v.index
	local linea, lista, costo, completo = Oc.Faltan(id, i)
	if not linea then return nil end
	local texto = N.Plural(#lista, L["%d material de este tramo no lo vende ningún comerciante: búscalo en la subasta."],
		L["%d materiales de este tramo no los vende ningún comerciante: búscalos en la subasta."])
	if costo > 0 then
		texto = texto .. " " .. format(completo and L["Comprar lo que falta cuesta unos %s."] or L["Comprar lo que falta cuesta más de %s (faltan precios)."],
			N.DineroTexto(costo, true))
	end
	return { tono = "acento", icono = "ic-oro", clave = "oficios.comprar." .. id .. "." .. i, titulo = L["Comprar lo que falta"], texto = texto,
		uno = { L["Comprar lo que falta"], function() Oc.Comprar(id, i) end, L["A mi lista"] } }
end
