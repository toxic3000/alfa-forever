-- Alfa - Comercio: qué conviene hacer con cada objeto (toxic3000 / La Jauría). GPL-3.0.
--
-- Compara, por unidad:
--   vender      el precio del comerciante (sellPrice de C_Item.GetItemInfo)
--   subastar    el precio guardado de la subasta menos la comisión (5 % por
--               omisión, ajustable; ESTIMADA: la API no la informa)
--   desencantar el valor esperado de los materiales (tablas de Datos.lua),
--               si tú u otro personaje tuyo del reino tiene Encantamiento
--   receta      lo que vale el producto de una receta que conoces menos lo
--               que cuestan los demás reactivos, repartido por unidad
-- y recomienda el mejor camino cuando gana por lo menos un 10 % a vender;
-- si no, vender. Sin ningún valor: guardar.
--
-- C_Item.GetItemInfo (ItemDocumentation.lua) devuelve: itemName, itemLink,
-- itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
-- itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, ...

local _, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L

local type, floor, max = type, math.floor, math.max

M.MARGEN = 0.10

-- Lo que el cliente sabe del objeto (nil si aún no está en caché: se pide).
function M.InfoObjeto(id)
	if type(id) ~= "number" then return nil end
	local get = C_Item and C_Item.GetItemInfo or GetItemInfo
	if type(get) ~= "function" then return nil end
	local ok, nombre, link, calidad, nivel, _, _, _, pila, _, icono, venta, clase, subclase, ligado = pcall(get, id)
	if not ok or type(nombre) ~= "string" then
		local C = A.Compat
		if C and C.RequestItem then C.RequestItem(id) end
		return nil
	end
	return {
		nombre = nombre, link = link, calidad = calidad or 1, nivel = nivel or 0,
		pila = pila or 1, icono = icono, venta = type(venta) == "number" and venta or 0,
		clase = clase, subclase = subclase, ligado = ligado,
	}
end

-- Lo que te dan por un objeto ya hecho (producto o material): lo mejor entre
-- el comerciante y la subasta neta.
function M.ValorVenta(id)
	local info = M.InfoObjeto(id)
	local venta = info and info.venta or 0
	local bruto = M.PrecioSubasta(id)
	local neto = bruto and M.NetoSubasta(bruto) or 0
	if not info and not bruto then return nil end
	return max(venta, neto), bruto ~= nil
end

---------------------------------------------------------------------------
-- Desencantar
---------------------------------------------------------------------------

local function habilidadPara(nivel)
	return M.FilaPorNivel(M.DE_HABILIDAD, nivel)[2]
end

-- Resultados posibles: { { id, probabilidad, cantidad promedio }, ... }
local function resultados(info)
	local nivel, q = info.nivel or 0, info.calidad
	local out = {}
	if q == 2 then
		local f = M.FilaPorNivel(M.DE_VERDE, nivel)
		local polvo, esencia, frag = f[2], f[3], f[4]
		local pf = frag and frag[2] or 0
		local menor = pf >= 0.10 and 0.15 or 0.20
		local pPolvo, pEsencia
		if info.clase == 2 then
			pPolvo, pEsencia = menor, 1 - menor - pf
		else
			pEsencia, pPolvo = menor, 1 - menor - pf
		end
		out[#out + 1] = { polvo[1], pPolvo, (polvo[2] + polvo[3]) / 2 }
		out[#out + 1] = { esencia[1], pEsencia, (esencia[2] + esencia[3]) / 2 }
		if frag then out[#out + 1] = { frag[1], pf, 1 } end
	elseif q == 3 or q == 4 then
		local tabla = q == 3 and M.DE_AZUL or M.DE_MORADO
		local f = M.FilaPorNivel(tabla, nivel)
		for _, r in ipairs(f[2]) do out[#out + 1] = { r[1], r[2], (r[3] + r[4]) / 2 } end
	end
	return out
end

-- Se puede desencantar (por clase y calidad, sin mirar quién).
function M.Desencantable(info)
	if not info or not M.DE_CLASES[info.clase] then return false end
	local no = M.DE_SUBCLASE_NO[info.clase]
	if no and no[info.subclase] then return false end
	return info.calidad == 2 or info.calidad == 3 or info.calidad == 4
end

-- -> { valor por objeto, incompleto, habilidad pedida, quien, propio, materiales } | nil
function M.Desencantar(id, info, ligado)
	info = info or M.InfoObjeto(id)
	if not M.Desencantable(info) then return nil end
	local modo = M.Ajuste("desencantar") or "auto"
	if modo == "nunca" then return nil end
	local pide = habilidadPara(info.nivel or 0)
	local quien, propio
	if modo ~= "siempre" then
		local mio = M.MiEncantamiento()
		if mio >= pide then
			quien, propio = M.NombrePersonaje(), true
		elseif not ligado then
			local e = M.Encantador()
			if e and e.s >= pide then quien, propio = e.nombre, e.propio end
		end
		if not quien then return nil end
	end
	local valor, incompleto, materiales = 0, false, {}
	for _, r in ipairs(resultados(info)) do
		local v, conPrecio = M.ValorVenta(r[1])
		if not v or not conPrecio then incompleto = true end
		valor = valor + (v or 0) * r[2] * r[3]
		materiales[#materiales + 1] = { id = r[1], p = r[2], q = r[3], valor = v }
	end
	if valor <= 0 then return nil end
	return { valor = floor(valor), incompleto = incompleto, habilidad = pide, quien = quien, propio = propio, materiales = materiales }
end

---------------------------------------------------------------------------
-- Recetas
---------------------------------------------------------------------------

-- Ganancia de una receta: valor del producto, costo de los reactivos.
-- -> valor, costo, completo, faltan { itemID, ... }
function M.CuentaReceta(rec, excepto)
	local valor, conPrecio = M.ValorVenta(rec.o)
	local completo = valor ~= nil and conPrecio
	valor = (valor or 0) * (rec.q or 1)
	local costo, faltan = 0, {}
	for i = 1, #rec.r, 2 do
		local id, cant = rec.r[i], rec.r[i + 1]
		if id ~= excepto then
			local c = M.CostoCompra(id)
			if c then
				costo = costo + c * cant
			else
				completo = false
				faltan[#faltan + 1] = id
			end
		end
	end
	return valor, costo, completo, faltan
end

-- La mejor receta para usar este objeto como reactivo.
-- -> { valor por unidad del reactivo, rec, quien, propio, producto } | nil
function M.MejorReceta(id, ligado)
	local lista = M.IndiceReactivos()[id]
	if not lista then return nil end
	local mejor
	for _, e in ipairs(lista) do
		if e.propio or not ligado then
			local rec = e.rec
			local cant
			for i = 1, #rec.r, 2 do
				if rec.r[i] == id then cant = rec.r[i + 1] end
			end
			if cant and cant > 0 then
				local valor, costo, completo = M.CuentaReceta(rec, id)
				local porUnidad = (valor - costo) / cant
				if completo and porUnidad > 0 and (not mejor or porUnidad > mejor.valor) then
					mejor = { valor = floor(porUnidad), rec = rec, quien = e.quien, propio = e.propio, producto = rec.o }
				end
			end
		end
	end
	return mejor
end

---------------------------------------------------------------------------
-- El consejo
---------------------------------------------------------------------------

-- chip: su nombre; color: el del tema (cuadro del objeto); tono: el del Kit (insignias).
M.TIPOS = {
	vender = { chip = "Vender", color = "quest", tono = "oro" },
	subastar = { chip = "Subastar", color = "success", tono = "exito" },
	desencantar = { chip = "Transformar", color = "dungeon", tono = "mazmorra" },
	receta = { chip = "Transformar", color = "dungeon", tono = "mazmorra" },
	guardar = { chip = "Guardar", color = "textDim", tono = "neutro" },
}

-- opts = { ligado = bool (nil: según el tipo de ligado), link = string }
-- -> c = {
--   id, info, venta, subasta = { bruto, neto, fecha, fuente, cantidad, viejo } | nil,
--   desencantar = {...} | nil, receta = {...} | nil,
--   mejor = "vender" | "subastar" | "desencantar" | "receta" | "guardar",
--   valor (por unidad), ganancia (fracción contra vender, nil si no se vende),
--   motivo (texto, para guardar), ligado,
-- } | nil si el objeto aún no está en caché
function M.Consejo(id, opts)
	opts = opts or {}
	local info = M.InfoObjeto(id)
	if not info then return nil end
	local ligado = opts.ligado
	if ligado == nil then ligado = info.ligado == 1 or info.ligado == 4 end
	local c = { id = id, info = info, venta = info.venta, ligado = ligado }
	if info.clase == M.CLASE_MISION then
		c.mejor, c.valor, c.motivo = "guardar", 0, L["Es de una misión."]
		return c
	end
	if not ligado then
		local bruto, fecha, cantidad, fuente = M.PrecioSubasta(id)
		if bruto then
			c.subasta = { bruto = bruto, neto = M.NetoSubasta(bruto), fecha = fecha, cantidad = cantidad, fuente = fuente, viejo = M.Viejo(fecha) }
		end
	end
	c.desencantar = M.Desencantar(id, info, ligado)
	c.receta = M.MejorReceta(id, ligado)
	-- La mejor alternativa a vender.
	local alt, altValor = nil, 0
	if c.subasta and c.subasta.neto > altValor then alt, altValor = "subastar", c.subasta.neto end
	if c.desencantar and not c.desencantar.incompleto and c.desencantar.valor > altValor then
		alt, altValor = "desencantar", c.desencantar.valor
	end
	if c.receta and c.receta.valor > altValor then alt, altValor = "receta", c.receta.valor end
	local venta = info.venta
	if alt and (venta <= 0 or altValor >= venta * (1 + M.MARGEN)) then
		c.mejor, c.valor = alt, altValor
	elseif venta > 0 then
		c.mejor, c.valor = "vender", venta
	else
		c.mejor, c.valor = "guardar", 0
		if ligado then
			c.motivo = L["No se puede vender."]
		elseif c.desencantar and c.desencantar.incompleto then
			c.motivo = L["Faltan precios de sus materiales: escanea la subasta."]
		else
			c.motivo = L["Sin precio todavía: escanea la subasta."]
		end
	end
	if venta > 0 then c.ganancia = (c.valor - venta) / venta end
	return c
end

-- Texto corto de la mejor opción: "subastar", "desencantar", "crear X"...
function M.TextoMejor(c)
	if c.mejor == "vender" then return L["vender al comerciante"] end
	if c.mejor == "subastar" then return L["subastar"] end
	if c.mejor == "desencantar" then
		if c.desencantar and not c.desencantar.propio and c.desencantar.quien then
			return L["desencantar (con %s)"]:format(c.desencantar.quien)
		end
		return L["desencantar"]
	end
	if c.mejor == "receta" and c.receta then
		local nombre = (A.Compat.GetItemName and A.Compat.GetItemName(c.receta.producto)) or c.receta.rec.n or "?"
		if not c.receta.propio and c.receta.quien then
			return L["crear %s (con %s)"]:format(nombre, c.receta.quien)
		end
		return L["crear %s"]:format(nombre)
	end
	return L["guardar"]
end

-- -> nombre, color del tema, tono del Kit
function M.ChipDe(c)
	local t = M.TIPOS[c.mejor] or M.TIPOS.guardar
	return L[t.chip], t.color, t.tono
end

---------------------------------------------------------------------------
-- Para los demás módulos de Alfa (Bolsas sugiere qué vender con esto):
--   AlfaComercio.Consejo(id, opts) -> c | nil ; AlfaComercio.TextoMejor(c) -> texto
--   AlfaComercio.ValorVenta(id) -> cobre, conPrecio ; AlfaComercio.PrecioSubasta(id) -> bruto, fecha
---------------------------------------------------------------------------
AlfaComercio = type(AlfaComercio) == "table" and AlfaComercio or {}
AlfaComercio.Consejo = M.Consejo
AlfaComercio.TextoMejor = M.TextoMejor
AlfaComercio.ChipDe = M.ChipDe
AlfaComercio.ValorVenta = M.ValorVenta
AlfaComercio.PrecioSubasta = M.PrecioSubasta
