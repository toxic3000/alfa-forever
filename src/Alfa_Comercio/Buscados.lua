-- Alfa - Comercio: lo de tu lista, barato en la subasta (1.4.0, plan 46; toxic3000 / La Jauría). GPL-3.0.
--
-- Con la subasta abierta, cuando aparece (en tus búsquedas o en el escaneo de
-- Alfa) un material que te falta de tu lista de compras a un buen precio, un
-- aviso: «Mena de torio a 45p c/u (suele valer 70p) · te faltan 12». Buen
-- precio: por lo menos un 15 % bajo lo que suele valer (el historial de días
-- anteriores, Gangas.lua) o, sin historial, bajo el último precio conocido.
-- Un aviso por objeto en cada visita a la subasta; los que llegan juntos (un
-- escaneo) van en uno solo. Alfa nunca compra: la compra es tuya.
-- Ajuste comercio.buscadosAviso (de fábrica, sí).
--   M.Buscados() -> { [itemID] = faltan } (lo que te falta de tu lista)
--   M.RevisarBuscado(id, precio, antes) -> hallazgo | nil

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, pairs, ipairs, floor, min, format = type, pairs, ipairs, math.floor, math.min, string.format

M.BUSCADO_BARATO = 0.15

local buscados      -- itemID -> faltan (se rehace al abrir la subasta o al cambiar la lista)
local avisados = {} -- itemID -> true en esta visita a la subasta
local pendientes = {}

local function activo() return M.Ajuste("buscadosAviso") ~= false end

function M.Buscados()
	if buscados then return buscados end
	buscados = {}
	local Li = M.Lista
	if Li and Li.Materiales then
		local ok, mats = pcall(Li.Materiales)
		for _, x in ipairs(ok and type(mats) == "table" and mats or {}) do
			if (x.faltan or 0) > 0 then buscados[x.id] = x.faltan end
		end
	end
	return buscados
end
function M.OlvidarBuscados() buscados = nil end

local function mostrar()
	local lista = pendientes
	pendientes = {}
	if #lista == 0 then return end
	table.sort(lista, function(a, b) return (a.ahorro or 0) > (b.ahorro or 0) end)
	local lineas = {}
	for i = 1, min(3, #lista) do
		local h = lista[i]
		local nombre = M.NombreObjeto and M.NombreObjeto(h.id) or ("#" .. h.id)
		lineas[i] = format(L["%s a %s c/u (suele valer %s) · te faltan %d"], nombre, M.Dinero(h.precio), M.Dinero(h.normal), h.faltan)
	end
	if #lista > 3 then lineas[#lineas + 1] = format(L["y %d más"], #lista - 3) end
	lineas[#lineas + 1] = L["La compra es tuya: Alfa no compra ni puja."]
	K.Aviso({ id = "comercio.buscados", icono = "ic-oro", tono = "exito", duracion = 10,
		titulo = #lista == 1 and L["Lo de tu lista, barato en la subasta"] or format(L["%d cosas de tu lista, baratas en la subasta"], #lista),
		texto = table.concat(lineas, "\n"), donde = L["Comercio > Tu lista de compras"] })
end

-- antes: el último precio conocido (antes de anotar este).
function M.RevisarBuscado(id, precio, antes)
	if not (activo() and M.SubastaAbierta and M.SubastaAbierta()) then return nil end
	if type(id) ~= "number" or type(precio) ~= "number" or precio <= 0 or avisados[id] then return nil end
	local faltan = M.Buscados()[id]
	if not faltan then return nil end
	local normal = M.ValorNormal and M.ValorNormal(id) or nil
	normal = normal or antes
	if not (normal and normal > 0 and precio <= normal * (1 - M.BUSCADO_BARATO)) then return nil end
	avisados[id] = true
	local h = { id = id, precio = floor(precio), normal = floor(normal), faltan = faltan, ahorro = floor((normal - precio) * faltan) }
	pendientes[#pendientes + 1] = h
	N.Una("comercio.buscados", 1.5, mostrar)
	return h
end

-- Cada precio que se anota pasa antes por aquí (después de las gangas).
local anotar = M.Anotar
function M.Anotar(id, precio, cantidad, fuente, fecha, r)
	if type(id) == "number" and type(precio) == "number" and buscados ~= false and activo() then
		local rr = r or M.Reino()
		local e = type(rr.p) == "table" and rr.p[id] or nil
		local antes = type(e) == "table" and tonumber(e[1]) or nil
		pcall(M.RevisarBuscado, id, floor(precio), antes)
	end
	return anotar(id, precio, cantidad, fuente, fecha, r)
end

A.RegisterEvent("AUCTION_HOUSE_SHOW", function() avisados, buscados = {}, nil end)
A.RegisterEvent("AUCTION_HOUSE_CLOSED", function() buscados = nil end)
A.On("ALFA_COMERCIO_LISTA", function() buscados = nil end)
A.RegisterEvent("BAG_UPDATE_DELAYED", function() buscados = nil end)
