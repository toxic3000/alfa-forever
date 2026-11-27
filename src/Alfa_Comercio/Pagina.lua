-- Alfa - Comercio: la página "Comercio" (toxic3000 / La Jauría). GPL-3.0.
--
-- Hecha con el Kit (docs/KIT.md), plantilla Tablero:
--   1. arriba y en grande, qué hacer con lo que llevas: cuánto ganas si sigues
--      los consejos, cuántas cosas vender, subastar, transformar o guardar, y
--      la acción que toca ahora (escanear, ir a la subasta o al comerciante);
--   2. los números: con los consejos, vendiéndolo todo y la diferencia;
--   3. lo que llevas, ordenado por lo que más ganas, con filtros;
--   4. los precios de la subasta (al día o no, y escanear);
--   5. tus recetas que dejan ganancia;
--   6. cómo decide Alfa y los ajustes.
-- 1.2.9: tu lista de compras (Lista.lua) va tras los precios, y Oficios
-- (de 1 a 300, la ventana de VentanaOficios.lua) tras tus recetas.
-- Todo es información: Alfa nunca vende, compra ni publica nada por ti.
--
-- Bolsas: C_Container.GetContainerNumSlots / GetContainerItemInfo
-- (ContainerDocumentation.lua: ContainerItemInfo.itemID, stackCount,
-- isBound, hyperlink), de 0 a NUM_TOTAL_EQUIPPED_BAG_SLOTS (bolsa de
-- reactivos incluida), como el motor (Alfa/QoL/QoL.lua Client.NumBags).

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local ESP = K.ESP
local L = M.L

local type, pairs, ipairs, floor, max, min, format = type, pairs, ipairs, math.floor, math.max, math.min, string.format

local VISIBLES = 10   -- filas de "Lo que llevas" antes de "Ver todo"
local MAX_RECETAS = 8
local FILA_H = 48
local DOT = "  \194\183  "

local pagina          -- la vista, cuando ya se armó
local filtro = "todos"
local verTodo = false

---------------------------------------------------------------------------
-- Bolsas
---------------------------------------------------------------------------

local function ultimaBolsa() return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 end

-- -> { { id, cantidad, ligado, link }, ... } agrupado por objeto y ligado.
local function leerBolsas()
	local C = C_Container
	local out, por = {}, {}
	if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return out end
	for bolsa = 0, ultimaBolsa() do
		local n = C.GetContainerNumSlots(bolsa)
		for ranura = 1, (type(n) == "number" and n or 0) do
			local info = C.GetContainerItemInfo(bolsa, ranura)
			local id = type(info) == "table" and info.itemID
			if type(id) == "number" then
				local ligado = info.isBound == true
				local clave = id .. (ligado and ":l" or "")
				local g = por[clave]
				if not g then
					g = { id = id, cantidad = 0, ligado = ligado, link = info.hyperlink }
					por[clave] = g
					out[#out + 1] = g
				end
				g.cantidad = g.cantidad + (type(info.stackCount) == "number" and info.stackCount or 1)
			end
		end
	end
	return out
end

-- Consejo de cada grupo y totales. -> lista, totales, pendientes
local function analizar()
	local lista = leerBolsas()
	local out, pendientes = {}, 0
	local tot = {
		consejo = 0, comerciante = 0, sinPrecio = 0,
		cuenta = { todos = 0, vender = 0, subastar = 0, transformar = 0, guardar = 0 },
		valor = { vender = 0, subastar = 0, transformar = 0, guardar = 0 },
	}
	for _, g in ipairs(lista) do
		local c = M.Consejo(g.id, { ligado = g.ligado, link = g.link })
		if not c then
			pendientes = pendientes + 1
		else
			g.c = c
			g.total = c.valor * g.cantidad
			out[#out + 1] = g
			if c.mejor ~= "guardar" then tot.consejo = tot.consejo + g.total end
			tot.comerciante = tot.comerciante + c.venta * g.cantidad
			local cat = (c.mejor == "desencantar" or c.mejor == "receta") and "transformar" or c.mejor
			g.cat = cat
			tot.cuenta[cat] = (tot.cuenta[cat] or 0) + 1
			tot.valor[cat] = (tot.valor[cat] or 0) + g.total
			tot.cuenta.todos = tot.cuenta.todos + 1
			if not c.ligado and not c.subasta and c.info.clase ~= M.CLASE_MISION then tot.sinPrecio = tot.sinPrecio + 1 end
		end
	end
	table.sort(out, function(a, b)
		local ga, gb = a.c.mejor == "guardar", b.c.mejor == "guardar"
		if ga ~= gb then return gb end
		if a.total ~= b.total then return a.total > b.total end
		return tostring(a.c.info.nombre) < tostring(b.c.info.nombre)
	end)
	return out, tot, pendientes
end
M.AnalizarBolsas = analizar
if type(AlfaComercio) == "table" then AlfaComercio.AnalizarBolsas = analizar end

---------------------------------------------------------------------------
-- Ir a un lugar con la flecha del motor (Alfa.Nav.nearby)
---------------------------------------------------------------------------

local function irA(clase)
	local Nav = A.Nav
	local cerca = Nav and Nav.nearby
	if cerca and cerca.Go then
		local ok, r = pcall(cerca.Go, clase)
		if ok then return r end
	end
	N.Imprimir(L["No pude buscar el lugar más cercano. Prueba de nuevo en un momento; si sigue, /alfa diagnostico lo revisa."])
	return false
end

---------------------------------------------------------------------------
-- Piezas de texto
---------------------------------------------------------------------------

local function colorCalidad(calidad)
	local r, g, b
	if K.ColorDeCalidad then r, g, b = K.ColorDeCalidad(calidad) end
	if r and A.Theme and A.Theme.Legible then
		local ok, x, y, z = pcall(A.Theme.Legible, r, g, b)
		if ok and type(x) == "number" then r, g, b = x, y, z end
	end
	if not r then return K.Hex("texto") end
	return ("ff%02x%02x%02x"):format(floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local function nombreObjeto(id)
	local C = A.Compat
	return (C and C.GetItemName and C.GetItemName(id)) or ("#" .. tostring(id))
end

local function iconoObjeto(id)
	local VO = M.VentanaOficios
	return VO and VO.Icono and VO.Icono(id) or nil
end

local function detalleDe(c)
	local partes = {}
	if c.venta > 0 then
		partes[#partes + 1] = L["Comerciante"] .. " " .. M.Dinero(c.venta)
	else
		partes[#partes + 1] = L["El comerciante no lo compra"]
	end
	if c.subasta then
		local s = L["Subasta"] .. " " .. M.Dinero(c.subasta.bruto)
		if c.subasta.fecha then
			local edad = "(" .. M.Hace(c.subasta.fecha) .. ")"
			s = s .. " " .. (c.subasta.viejo and K.Tenir("aviso", edad) or edad)
		end
		local t = M.Tendencia(c.id)
		if t and math.abs(t) >= 0.05 then
			local cuanto = (M.Porcentaje(math.abs(t)):gsub("^%+", ""))
			s = s .. " " .. (t > 0 and L["sube %s"] or L["baja %s"]):format(cuanto)
		end
		partes[#partes + 1] = s
	elseif c.ligado then
		partes[#partes + 1] = L["Ligado: no se subasta"]
	end
	if c.desencantar then partes[#partes + 1] = L["Desencantar ≈ %s"]:format(M.Dinero(c.desencantar.valor)) end
	if c.receta then partes[#partes + 1] = L["Crear %s ≈ %s"]:format(nombreObjeto(c.receta.producto), M.Dinero(c.receta.valor)) end
	if c.mejor == "guardar" and c.motivo then partes[#partes + 1] = c.motivo end
	return table.concat(partes, DOT)
end

-- Lo que el cuadro del objeto agrega en la lista.
local function lineasExtra(tip, g)
	local c = g.c
	if not c then return end
	local r, gg, b = K.Color("textoSuave")
	tip:AddLine(" ")
	if g.cantidad > 1 then tip:AddDoubleLine(L["Tienes"], tostring(g.cantidad), r, gg, b, 1, 1, 1) end
	if c.mejor ~= "guardar" then tip:AddDoubleLine(L["Si sigues el consejo"], M.Dinero(g.total), r, gg, b, 1, 1, 1) end
	if c.venta > 0 and g.cantidad > 0 then tip:AddDoubleLine(L["Al comerciante"], M.Dinero(c.venta * g.cantidad), r, gg, b, 1, 1, 1) end
	local de = c.desencantar
	if de then
		local quien = (de.propio or not de.quien) and "" or (" " .. L["(con %s)"]:format(de.quien))
		tip:AddLine(L["Desencantar: ≈ %s por objeto%s. Pide Encantamiento %d."]:format(M.Dinero(de.valor), quien, de.habilidad or 1), r, gg, b, true)
		if de.incompleto then
			local wr, wg, wb = K.Color("aviso")
			tip:AddLine(L["Faltan precios de algunos materiales."], wr, wg, wb, true)
		end
	end
	local re = c.receta
	if re then
		local quien = (re.propio or not re.quien) and "" or (" " .. L["(con %s)"]:format(re.quien))
		tip:AddLine(L["Receta: %s%s. Cada unidad rinde ≈ %s."]:format(re.rec.n or "?", quien, M.Dinero(re.valor)), r, gg, b, true)
	end
	tip:AddLine(L["Comisión de la subasta estimada: %d %%."]:format(floor(M.Comision() * 100 + 0.5)), r, gg, b, true)
end

---------------------------------------------------------------------------
-- 1. Qué hacer con lo que llevas
---------------------------------------------------------------------------

local function precios()
	local fecha = M.Escaneo()
	local cuantos = M.CuantosPrecios()
	if cuantos == 0 then return "sin" end
	if not fecha then return "pocos" end
	if M.Viejo(fecha) then return "viejos" end
	return "aldia"
end

local function accionEscanear()
	local texto, activo = M.BotonEscaneo()
	if not activo then return nil end
	return { texto = L["Escanear ahora"], icono = "ic-buscar", alClic = function() M.Escanear() M.Cambio() end }
end

local function queHacer(datos, tot, pendientes)
	local d = { icono = "ic-comercio", sobre = L["Qué hacer con lo que llevas"] }
	if #datos == 0 then
		if pendientes > 0 then
			d.titulo, d.tono = L["Leyendo tus bolsas…"], "neutro"
			d.texto = L["El juego todavía no tiene los datos de algunos objetos. En un momento aparecen."]
		else
			d.titulo, d.tono = L["Tus bolsas están vacías"], "neutro"
			d.texto = L["Cuando lleves algo, Alfa te dice si conviene venderlo, subastarlo o transformarlo, y cuánto ganas."]
		end
		return d
	end
	local cu, va = tot.cuenta, tot.valor
	d.tono = "acento"
	d.titulo = tot.consejo > 0 and format(L["Si sigues los consejos ganas %s"], M.Dinero(tot.consejo)) or L["Por ahora, guárdalo todo"]
	local partes = {}
	if cu.vender > 0 then partes[#partes + 1] = format(L["vende %d al comerciante (%s)"], cu.vender, M.Dinero(va.vender)) end
	if cu.subastar > 0 then partes[#partes + 1] = format(L["subasta %d (%s)"], cu.subastar, M.Dinero(va.subastar)) end
	if cu.transformar > 0 then partes[#partes + 1] = format(L["transforma %d (%s)"], cu.transformar, M.Dinero(va.transformar)) end
	if cu.guardar > 0 then partes[#partes + 1] = format(L["guarda %d"], cu.guardar) end
	local texto = ""
	if #partes > 0 then
		local ultimo = table.remove(partes)
		texto = #partes > 0 and (table.concat(partes, ", ") .. " " .. L["y"] .. " " .. ultimo) or ultimo
		texto = texto:gsub("^%l", string.upper) .. "."
	end
	local extra = tot.consejo - tot.comerciante
	if extra > 0 then texto = texto .. " " .. format(L["Son %s más que venderlo todo al comerciante."], M.Dinero(extra)) end
	local p = precios()
	if p == "sin" then
		texto = texto .. " " .. L["Aún no tienes precios de la subasta: escanéala para saber cuánto vale de verdad."]
	elseif p == "viejos" then
		texto = texto .. " " .. L["Tus precios de la subasta son viejos: escanéala otra vez."]
	end
	d.texto = texto
	d.lineas = 4
	local insignias = {}
	if cu.vender > 0 then insignias[#insignias + 1] = { format(L["Vender %d"], cu.vender), "oro" } end
	if cu.subastar > 0 then insignias[#insignias + 1] = { format(L["Subastar %d"], cu.subastar), "exito" } end
	if cu.transformar > 0 then insignias[#insignias + 1] = { format(L["Transformar %d"], cu.transformar), "mazmorra" } end
	if cu.guardar > 0 then insignias[#insignias + 1] = { format(L["Guardar %d"], cu.guardar), "neutro" } end
	d.insignias = insignias
	-- La acción que toca ahora.
	local abierta = M.SubastaAbierta()
	local escanear = abierta and accionEscanear()
	if escanear and (p ~= "aldia") then
		d.accion = escanear
	elseif cu.subastar > 0 and not abierta and p ~= "sin" then
		d.accion = { texto = L["Llévame a la subasta"], icono = "ic-flecha", alClic = function() irA("auction") end }
		if cu.vender > 0 then d.secundaria = { texto = L["Llévame al comerciante"], alClic = function() irA("vendor") end } end
	elseif p == "sin" or p == "viejos" then
		d.accion = abierta and escanear or { texto = L["Llévame a la subasta"], icono = "ic-flecha", alClic = function() irA("auction") end }
		if cu.vender > 0 then d.secundaria = { texto = L["Llévame al comerciante"], alClic = function() irA("vendor") end } end
	elseif cu.vender > 0 then
		d.accion = { texto = L["Llévame al comerciante"], icono = "ic-flecha", alClic = function() irA("vendor") end }
	end
	return d
end

-- 2. Los números, en tarjetas compactas.
local function numeros(tot)
	if tot.cuenta.todos == 0 then return {} end
	local extra = tot.consejo - tot.comerciante
	local lista = {
		{ variante = "compacta", icono = "ic-oro", titulo = L["Si sigues los consejos"], valor = M.Dinero(tot.consejo), tono = "acento",
			texto = N.Plural(tot.cuenta.todos, L["%d objeto distinto"], L["%d objetos distintos"]) },
		{ variante = "compacta", icono = "ic-comercio", titulo = L["Si vendes todo al comerciante"], valor = M.Dinero(tot.comerciante),
			texto = L["lo más fácil"] },
	}
	-- La diferencia, solo si la hay.
	if extra > 0 then
		lista[#lista + 1] = { variante = "compacta", icono = "ic-nivel", titulo = L["Ganas de más"], valor = "+" .. M.Dinero(extra), tono = "exito",
			texto = tot.comerciante > 0 and format(L["%s contra el comerciante"], M.Porcentaje(extra / tot.comerciante)) or nil }
	end
	return lista
end

---------------------------------------------------------------------------
-- Filas de objetos (lo que llevas y las recetas)
---------------------------------------------------------------------------

local function nuevaFila(padre)
	local f = CreateFrame("Button", nil, padre)
	f:SetHeight(FILA_H)
	f:RegisterForClicks("LeftButtonUp")
	f.velo = K.Velo(f, K.CORTE.chico, 0.04)
	f.Icono = K.IconoObjeto(f, 32)
	f.Icono:EnableMouse(false)
	f.Icono:SetPoint("LEFT", f, "LEFT", ESP.base, 0)
	f.Nombre = K.Texto(f, "cuerpo", "texto")
	f.Detalle = K.Texto(f, "pequeno", "textoTenue")
	f.Valor = K.Texto(f, "numero", "texto")
	f.Valor:SetJustifyH("RIGHT")
	f.Extra = K.Texto(f, "pequeno", "exito")
	f.Extra:SetJustifyH("RIGHT")
	f.Chip = K.Insignia(f, "", "neutro")
	f:SetScript("OnEnter", function(self)
		self.velo:Show()
		local d = self.dato
		if not (d and d.id and GameTooltip) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink("item:" .. d.id)
		if d.grupo then lineasExtra(GameTooltip, d.grupo) end
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function(self)
		self.velo:Hide()
		if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
	end)
	f:SetScript("OnClick", function(self)
		local d = self.dato
		if d and d.alClic and not (IsModifiedClick and IsModifiedClick()) then K.Llamar(d.alClic, self) return end
		if not (d and d.id and IsModifiedClick and IsModifiedClick()) then return end
		local C = A.Compat
		local link = (d.grupo and d.grupo.link) or (C and C.ItemLink and C.ItemLink(d.id))
		if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
	end)
	function f:Set(d)
		self.dato = d
		self.Icono:SetObjeto({ id = d.id, cantidad = d.cantidad })
		K.Escribir(self.Nombre, d.nombre or "")
		K.Escribir(self.Detalle, d.detalle or "")
		K.Escribir(self.Valor, d.valor or "")
		K.Escribir(self.Extra, d.extra or "")
		K.ColorTexto(self.Extra, d.colorExtra or "exito")
		self.Chip:Set(d.chip, d.tono or "neutro")
	end
	function f:Acomodar(ancho)
		self:SetSize(ancho, FILA_H)
		local x = ESP.base + 32 + ESP.m
		local vw = max(K.Ajustar(self.Valor, 140), K.Ajustar(self.Extra, 140))
		self.Valor:ClearAllPoints()
		self.Valor:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ESP.base, -9)
		self.Extra:ClearAllPoints()
		self.Extra:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -ESP.base, 9)
		local cw = self.Chip:IsShown() and K.num(self.Chip:GetWidth(), 0) or 0
		self.Chip:ClearAllPoints()
		self.Chip:SetPoint("RIGHT", self, "RIGHT", -(ESP.base + vw + ESP.base), 0)
		local tw = max(60, ancho - x - ESP.base - vw - ESP.base - (cw > 0 and cw + ESP.m or 0))
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("TOPLEFT", self, "TOPLEFT", x, -9)
		self.Nombre:SetWidth(tw)
		self.Detalle:ClearAllPoints()
		self.Detalle:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, 9)
		self.Detalle:SetWidth(tw)
		return FILA_H
	end
	return f
end

-- Un panel con filas: -> bloque con :Llenar(datos) y :Acomodar(ancho)
local function panelDeFilas(padre)
	local p = CreateFrame("Frame", nil, padre)
	p.caja = K.Caja(p, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	p.filas, p.lineas, p.datos = {}, {}, {}
	function p:Llenar(datos)
		self.datos = datos or {}
		for i, d in ipairs(self.datos) do
			local f = self.filas[i] or nuevaFila(self)
			self.filas[i] = f
			f:Set(d)
			f:Show()
		end
		for i = #self.datos + 1, #self.filas do self.filas[i]:Hide() end
	end
	function p:Acomodar(ancho)
		local y = 0
		for i = 1, #self.datos do
			local f = self.filas[i]
			if i > 1 then
				local ln = self.lineas[i - 1] or K.Linea(self, "linea")
				self.lineas[i - 1] = ln
				ln:ClearAllPoints()
				ln:SetPoint("TOPLEFT", self, "TOPLEFT", ESP.base, -y)
				ln:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ESP.base, -y)
				ln:Show()
			end
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			y = y + f:Acomodar(ancho)
		end
		for i = max(1, #self.datos), #self.lineas do self.lineas[i]:Hide() end
		self:SetSize(ancho, max(1, y))
		return y
	end
	return p
end

local function filaDeObjeto(g)
	local c = g.c
	local chip, _, tono = M.ChipDe(c)
	local d = {
		id = g.id, cantidad = g.cantidad, grupo = g, chip = chip, tono = tono,
		nombre = "|c" .. colorCalidad(c.info.calidad) .. tostring(c.info.nombre) .. "|r"
			.. ((c.mejor ~= "vender" and c.mejor ~= "guardar") and K.Tenir("textoTenue", DOT .. M.TextoMejor(c)) or ""),
		detalle = detalleDe(c),
	}
	if c.mejor == "guardar" then
		d.valor = K.Tenir("textoTenue", "—")
	else
		d.valor = M.Dinero(g.total)
		if c.ganancia and c.ganancia > 0.005 then
			d.extra = M.Porcentaje(c.ganancia)
		elseif c.mejor == "vender" then
			d.extra, d.colorExtra = L["al comerciante"], "textoTenue"
		end
	end
	return d
end

---------------------------------------------------------------------------
-- 3. Lo que llevas
---------------------------------------------------------------------------

local FILTROS = {
	{ "todos", "Todos" }, { "vender", "Vender" }, { "subastar", "Subastar" }, { "transformar", "Transformar" }, { "guardar", "Guardar [conservar]" },
}

local function bloqueLista(ui, padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Lo que llevas"]))
	b.Filtros = b:Agregar(K.Segmentos(b, { estilo = "pildoras", valor = filtro, opciones = {}, alCambiar = function(v)
		filtro = v
		verTodo = false
		M.Cambio()
	end }))
	b.Panel = b:Agregar(panelDeFilas(b), { espacio = ESP.s })
	b.Vacio = b:Agregar(K.Vacio(b, { lobo = "vacio", titulo = L["Nada en este grupo"], texto = L["Prueba con otro filtro."] }), { espacio = ESP.base })
	b.Mas = b:Agregar(K.Boton(b, "", function() verTodo = not verTodo M.Cambio() end, { tipo = "fantasma", tam = "chico" }), { espacio = ESP.s })
	b.Mas.alfaAnchoPropio = true
	function b:Llenar(datos, tot)
		local ops = {}
		for _, f in ipairs(FILTROS) do
			local n = f[1] == "todos" and tot.cuenta.todos or (tot.cuenta[f[1]] or 0)
			if f[1] == "todos" or n > 0 then ops[#ops + 1] = { valor = f[1], texto = L[f[2]], cuenta = n } end
		end
		local valido = false
		for _, o in ipairs(ops) do if o.valor == filtro then valido = true end end
		if not valido then filtro = "todos" end
		self.Filtros:SetOpciones(ops)
		self.Filtros:SetValor(filtro)
		local visibles = {}
		for _, g in ipairs(datos) do
			if filtro == "todos" or g.cat == filtro then visibles[#visibles + 1] = g end
		end
		self.Seccion:Set(L["Lo que llevas"], { cuenta = #visibles > 0 and #visibles or nil })
		local n = verTodo and #visibles or min(#visibles, VISIBLES)
		local filas = {}
		for i = 1, n do filas[i] = filaDeObjeto(visibles[i]) end
		self.Panel:Llenar(filas)
		K.Mostrar(self.Panel, n > 0)
		K.Mostrar(self.Vacio, #visibles == 0)
		local mas = #visibles > VISIBLES
		K.Mostrar(self.Mas, mas)
		if mas then self.Mas:SetTexto(verTodo and L["Ver menos"] or format(L["Ver todo (%d)"], #visibles)) end
		-- Sin nada en las bolsas, la tarjeta de arriba ya lo dice: el bloque no se muestra.
		K.Mostrar(self, #datos > 0)
	end
	return b
end

---------------------------------------------------------------------------
-- 4. Los precios de la subasta
---------------------------------------------------------------------------

local function bloquePrecios(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Precios de la subasta"]))
	b.Tarjeta = b:Agregar(K.Tarjeta(b, { variante = "estado" }))
	function b:Llenar(tot)
		local fecha, objetos = M.Escaneo()
		local cuantos = M.CuantosPrecios()
		local d = { icono = "ic-oro" }
		local p = precios()
		if p == "sin" then
			d.titulo, d.tono = L["Sin precios todavía"], "aviso"
			d.texto = L["Abre la casa de subastas y pulsa «Escanear con Alfa» para saber cuánto valen tus objetos."]
			d.estado = { texto = L["Sin precios"], tono = "aviso" }
		elseif p == "pocos" then
			d.titulo, d.tono = L["Pocos precios"], "aviso"
			d.texto = L["Tienes %s precios de tus búsquedas. Para conocer todos, escanea en la casa de subastas."]:format(M.Miles(cuantos))
			d.estado = { texto = L["Pocos"], tono = "aviso" }
		elseif p == "viejos" then
			d.titulo, d.tono = L["Precios viejos"], "aviso"
			d.texto = L["Tu último escaneo fue %s. Escanea otra vez en la casa de subastas para tener precios al día."]:format(M.Hace(fecha))
			d.estado = { texto = L["Viejos"], tono = "aviso" }
		else
			d.titulo, d.tono = L["Precios al día"], "exito"
			d.texto = L["Último escaneo %s · %s objetos con precio."]:format(M.Hace(fecha), M.Miles(objetos or cuantos))
			d.estado = { texto = L["Al día"], tono = "exito" }
		end
		if tot.sinPrecio > 0 then
			d.texto = d.texto .. " " .. L["%d de tus objetos aún no tienen precio de subasta."]:format(tot.sinPrecio)
		end
		if M.SubastaAbierta() then
			local texto, activo = M.BotonEscaneo()
			d.accion = { texto = activo and L["Escanear ahora"] or texto, icono = "ic-buscar", alClic = function() M.Escanear() M.Cambio() end }
		elseif p ~= "aldia" then
			d.accion = { texto = L["Llévame a la subasta"], icono = "ic-flecha", alClic = function() irA("auction") end }
		end
		self.Tarjeta:Set(d)
		if d.accion and self.Tarjeta.Accion then self.Tarjeta.Accion:SetActivo(not M.SubastaAbierta() or (select(2, M.BotonEscaneo()))) end
	end
	return b
end

---------------------------------------------------------------------------
-- 5. Tus recetas que dejan ganancia
---------------------------------------------------------------------------

local function bloqueRecetas(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Tus recetas que dejan ganancia"]))
	b.Panel = b:Agregar(panelDeFilas(b), { espacio = ESP.s })
	b.Nota = b:Agregar(K.Vacio(b, { lobo = "dormido" }), { espacio = ESP.base })
	function b:Llenar()
		local todas = M.TodasLasRecetas()
		-- 1.3.0: M.Fabricar (Fabricar.lua) dice además cuántas puedes hacer ya
		-- con lo que llevas; con comercio.fabricar, esas van primero.
		local buenas, incompletas = M.Fabricar()
		local filas = {}
		for i = 1, min(#buenas, MAX_RECETAS) do
			local x = buenas[i]
			local rec, e = x.e.rec, x.e
			local quien = e.propio and "" or (DOT .. L["con %s"]:format(e.quien or "?"))
			local detalle = L["Reactivos %s  ·  el producto vale %s"]:format(M.Dinero(x.costo), M.Dinero(x.valor))
			if x.veces > 0 and M.Ajuste("fabricar") ~= false then
				detalle = L["Con lo que tienes haces %d: +%s en total"]:format(x.veces, M.Dinero(x.total))
				-- 1.3.3: «Hazlo ya» es con lo de tus bolsas; lo del banco, aparte.
				if (x.conBanco or 0) > 0 then detalle = detalle .. " " .. L["(con lo del banco: %d más)"]:format(x.conBanco) end
			elseif (x.conBanco or 0) > 0 and M.Ajuste("fabricar") ~= false then
				detalle = detalle .. DOT .. L["(con lo del banco: %d más)"]:format(x.conBanco)
			end
			filas[i] = {
				id = rec.o, cantidad = rec.q and floor(rec.q) or 1, chip = x.veces > 0 and L["Hazlo ya"] or L["Transformar"],
				tono = x.veces > 0 and "exito" or "mazmorra",
				nombre = tostring(rec.n) .. K.Tenir("textoTenue", DOT .. tostring(rec.p or "") .. quien),
				detalle = detalle,
				valor = "+" .. M.Dinero(x.gana), extra = x.costo > 0 and M.Porcentaje(x.gana / x.costo) or nil,
			}
		end
		self.Panel:Llenar(filas)
		K.Mostrar(self.Panel, #filas > 0)
		local nota
		if #todas == 0 then
			nota = { titulo = L["Todavía no conozco tus recetas"], texto = L["Abre la ventana de tu profesión una vez y Alfa leerá tus recetas para decirte cuáles te dejan ganancia."] }
		elseif #filas == 0 then
			nota = { titulo = L["Ninguna receta deja ganancia"], texto = L["Ninguna de tus recetas deja ganancia con los precios que tienes."] }
		end
		if incompletas > 0 then
			local t = N.Plural(incompletas, L["%d receta no se puede calcular porque faltan precios de sus reactivos o su producto."], L["%d recetas no se pueden calcular porque faltan precios de sus reactivos o su producto."])
			if nota then nota.texto = nota.texto .. " " .. t else nota = { titulo = L["Faltan precios"], texto = t } end
		end
		if nota then
			nota.lobo = #filas > 0 and "atento" or "dormido"
			self.Nota:Set(nota)
		end
		K.Mostrar(self.Nota, nota ~= nil)
	end
	return b
end

---------------------------------------------------------------------------
-- 1.2.9: tu lista de compras
---------------------------------------------------------------------------

local MAX_MATERIALES = 20

-- El menú de «Agregar»: lo que falta para subir tus oficios y tus recetas.
local function menuAgregar(dueno)
	local ops = {}
	for _, o in ipairs(M.Oficios.Lista()) do
		if o.conocido and o.guia.tipo == "crear" and (o.rank or 0) < 300 then
			ops[#ops + 1] = { valor = "oficio:" .. o.linea, texto = format(L["Lo que falta para subir %s"], L[o.guia.nombre]), icono = "ic-oficios" }
		end
	end
	local recetas, vistos = {}, {}
	for _, e in ipairs(M.TodasLasRecetas()) do
		local rec = e.rec
		if e.propio and type(rec.o) == "number" and not vistos[rec.o] then
			vistos[rec.o] = true
			recetas[#recetas + 1] = { valor = "receta:" .. rec.o, texto = tostring(rec.n or nombreObjeto(rec.o)) }
		end
	end
	table.sort(recetas, function(a, b) return a.texto < b.texto end)
	if #ops > 0 and #recetas > 0 then ops[#ops + 1] = { separador = true } end
	for _, r in ipairs(recetas) do ops[#ops + 1] = r end
	if #ops == 0 then
		-- Sin recetas ni oficios: la guía de oficios, para elegir uno.
		M.VentanaOficios.Abrir()
		return
	end
	K.Menu(dueno, ops, nil, function(v)
		local tipo, id = tostring(v):match("^(%a+):(%d+)$")
		id = tonumber(id)
		if tipo == "oficio" then M.Lista.AgregarOficio(id)
		elseif tipo == "receta" then M.Lista.Agregar(id, 1) end
	end, 280)
end
M.MenuAgregar = menuAgregar

local function bloqueCompras(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Tu lista de compras"]))
	b.Tarjeta = b:Agregar(K.Tarjeta(b, { variante = "estado" }))
	b.Panel = b:Agregar(panelDeFilas(b), { espacio = ESP.s })
	b.Metas = b:Agregar(K.Rejilla(b, { min = 220, gap = ESP.s, variante = "compacta" }), { espacio = ESP.s })
	function b:Llenar()
		local Li = M.Lista
		local metas = Li.Metas()
		if #metas > 0 then Li.Codex(true) end
		local mats, listos, total = Li.Materiales()
		local d = { icono = "ic-lista" }
		local tarjeta = self.Tarjeta
		local function agregar() menuAgregar(tarjeta.Accion or tarjeta) end
		if #metas == 0 then
			d.titulo, d.tono = L["Tu lista está vacía"], "neutro"
			d.texto = L["Elige una receta o un oficio y Alfa te dice qué materiales te faltan y de dónde sale cada uno. También desde la Enciclopedia."]
			d.estado = { texto = L["Vacía"], tono = "neutro" }
			d.accion = { texto = L["Agregar a mi lista"], icono = "ic-mas", alClic = agregar }
		else
			local nombres = {}
			for i, m in ipairs(metas) do
				if i > 4 then nombres[#nombres + 1] = format(L["%d más"], #metas - 4) break end
				nombres[#nombres + 1] = (m.oficio or (m.n or 1) <= 1) and Li.NombreMeta(m) or format(L["%s ×%d"], Li.NombreMeta(m), m.n)
			end
			local costo, completo = Li.Costo(mats)
			if listos == total then
				d.titulo, d.tono = L["¡Tienes todo!"], "exito"
				d.estado = { texto = L["Completa"], tono = "exito" }
			else
				d.titulo, d.tono = format(total - listos == 1 and L["Te falta %d de %d materiales"] or L["Te faltan %d de %d materiales"], total - listos, total), "acento"
			end
			d.texto = format(L["Para: %s."], table.concat(nombres, ", "))
			if costo > 0 then
				d.texto = d.texto .. " " .. format(completo and L["Comprar lo que falta cuesta unos %s."] or L["Comprar lo que falta cuesta más de %s (faltan precios)."], M.Dinero(costo))
			end
			d.lineas = 4
			d.progreso = { actual = listos, total = max(1, total), texto = format(L["%d de %d listos"], listos, total) }
			d.accion = { texto = L["Agregar a mi lista"], icono = "ic-mas", alClic = agregar }
			d.secundaria = { texto = L["Vaciar la lista"], alClic = function()
				K.Dialogo({ titulo = L["¿Vaciar tu lista de compras?"], texto = L["Se quitan todas las metas. Tus objetos no se tocan."],
					aceptar = L["Vaciar"], peligro = true, alAceptar = function() Li.Vaciar() end })
			end }
		end
		self.Seccion:Set(L["Tu lista de compras"], { cuenta = total > 0 and total or nil })
		self.Tarjeta:Set(d)
		local filas = {}
		for i = 1, min(#mats, MAX_MATERIALES) do
			local x = mats[i]
			local donde = Li.Donde(x.id)
			local costo = x.faltan > 0 and M.CostoCompra(x.id) or nil
			filas[i] = {
				id = x.id, cantidad = x.necesita, nombre = nombreObjeto(x.id),
				detalle = (M.TextoTienes and M.TextoTienes(x) or format(L["Tienes %d de %d"], x.tienes, x.necesita)) .. (donde and (DOT .. donde) or ""),
				chip = x.listo and L["Listo"] or format(L["Faltan %d"], x.faltan), tono = x.listo and "exito" or "aviso",
				valor = costo and M.Dinero(costo * x.faltan) or nil,
				extra = costo and L["si lo compras"] or nil, colorExtra = "textoTenue",
				alClic = not x.listo and function() Li.Guiar(x.id) end or nil,
			}
		end
		self.Panel:Llenar(filas)
		K.Mostrar(self.Panel, #filas > 0)
		local tarjetas = {}
		for i, m in ipairs(metas) do
			local nombre = Li.NombreMeta(m)
			local icono = m.id and iconoObjeto(m.id)
			tarjetas[i] = {
				variante = "compacta", icono = icono or "ic-oficios", tenir = icono and false or nil,
				titulo = nombre, valor = (not m.oficio and (m.n or 1) > 1) and format(L["×%d"], m.n) or nil,
				ayuda = L["Clic: quitarla de tu lista."],
				alClic = function()
					K.Dialogo({ titulo = L["¿Quitar de tu lista?"], texto = format(L["Se quita %s de tu lista de compras."], nombre),
						aceptar = L["Quitar"], alAceptar = function()
							for j, x in ipairs(Li.Metas()) do if x == m then Li.Quitar(j) break end end
						end })
				end,
			}
		end
		self.Metas:Llenar(tarjetas)
		K.Mostrar(self.Metas, #tarjetas > 0)
	end
	return b
end

---------------------------------------------------------------------------
-- 1.4.0 (plan 47): tu semana en la subasta (Semana.lua)
---------------------------------------------------------------------------

local MAX_SEMANA = 6

local function bloqueSemana(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Tu semana en la subasta"]))
	b.Tarjeta = b:Agregar(K.Tarjeta(b, { variante = "estado" }))
	b.Panel = b:Agregar(panelDeFilas(b), { espacio = ESP.s })
	function b:Llenar()
		local s = M.Semana(7)
		local d = { icono = "ic-oro", lineas = 3 }
		if #s.lista == 0 then
			d.titulo, d.tono = L["Sin ventas ni compras esta semana"], "neutro"
			d.texto = L["Lo que vendes y compras en la subasta se anota al tomar sus cartas del buzón."]
			d.estado = { texto = L["Vacía"], tono = "neutro" }
		else
			local neto = s.neto
			d.titulo = format(neto >= 0 and L["Te quedaron %s esta semana"] or L["Gastaste %s más de lo que vendiste"], M.Dinero(math.abs(neto)))
			d.tono = neto >= 0 and "exito" or "aviso"
			d.texto = format(L["Vendiste %s (%s) y compraste %s (%s)."],
				N.Plural(s.ventas, L["%d cosa"], L["%d cosas"]):format(s.ventas), M.Dinero(s.vendido),
				N.Plural(s.compras, L["%d cosa"], L["%d cosas"]):format(s.compras), M.Dinero(s.comprado))
			d.estado = { texto = L["7 días"], tono = "neutro" }
		end
		self.Seccion:Set(L["Tu semana en la subasta"], { cuenta = #s.lista > 0 and #s.lista or nil })
		self.Tarjeta:Set(d)
		local filas = {}
		for i = 1, min(#s.lista, MAX_SEMANA) do
			local m = s.lista[i]
			local vendio = m.k == "v"
			filas[i] = {
				id = m.id, cantidad = m.q, nombre = m.n or L["Objeto"],
				detalle = (vendio and L["Vendiste"] or L["Compraste"]) .. DOT .. M.Hace(m.t),
				chip = vendio and L["Venta"] or L["Compra"], tono = vendio and "exito" or "neutro",
				valor = (vendio and "+" or "-") .. M.Dinero(m.c or 0),
			}
		end
		self.Panel:Llenar(filas)
		K.Mostrar(self.Panel, #filas > 0)
		K.Mostrar(self, M.Ajuste("semana") ~= false)
	end
	return b
end

---------------------------------------------------------------------------
-- 1.2.9: Oficios de 1 a 300
---------------------------------------------------------------------------

local function bloqueOficios(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Oficios: de 1 a 300"]))
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 240, gap = ESP.s, variante = "compacta" }))
	function b:Llenar()
		local Of = M.Oficios
		local conocidos, otros = {}, {}
		for _, o in ipairs(Of.Lista()) do
			if o.conocido then conocidos[#conocidos + 1] = o else otros[#otros + 1] = o end
		end
		for _, o in ipairs(otros) do conocidos[#conocidos + 1] = o end
		local tarjetas = {}
		for _, o in ipairs(conocidos) do
			local linea = o.linea
			local texto
			if o.conocido then
				local p = Of.PasoActual(linea, o.rank)
				if o.rank >= 300 then texto = L["¡Al máximo!"]
				elseif p and p.o then texto = format(L["Ahora: %s"], nombreObjeto(p.o))
				elseif p and p.da then texto = format(L["Ahora: %s"], nombreObjeto(p.da[1]))
				else texto = L["Sigue con los pasos de la guía"] end
			else
				texto = o.guia.secundario and L["Secundario: no cuenta en tus dos"] or L["Aún no lo aprendes"]
			end
			local icono = iconoObjeto(o.guia.icono)
			tarjetas[#tarjetas + 1] = {
				icono = icono or "ic-oficios", tenir = icono and false or nil,
				titulo = L[o.guia.nombre], texto = texto,
				valor = o.conocido and format(L["%d/%d"], o.rank, o.max) or nil,
				alClic = function() M.VentanaOficios.Abrir(linea) end, ayuda = L["Clic: abrir su guía de 1 a 300."],
			}
		end
		self.Seccion:Set(L["Oficios: de 1 a 300"], { enlace = { texto = L["Abrir la guía"], alClic = function() M.VentanaOficios.Abrir() end } })
		self.Rejilla:Llenar(tarjetas)
		K.Mostrar(self, M.Ajuste("oficios") ~= false)
	end
	return b
end

---------------------------------------------------------------------------
-- 6. Cómo decide Alfa y los ajustes
---------------------------------------------------------------------------

-- 1.4.2: tus subastas (Subastas.lua): lo que tienes a la venta en toda tu cuenta.
local MAX_SUBASTAS = 6
local function bloqueSubastas(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Tus subastas"]))
	b.Tarjeta = b:Agregar(K.Tarjeta(b, { variante = "estado" }))
	b.Panel = b:Agregar(panelDeFilas(b), { espacio = ESP.s })
	function b:Llenar()
		local Su = M.Subastas
		local r = Su.Resumen()
		local todas = Su.Todas()
		local d = { icono = "ic-oro", lineas = 3 }
		if #todas == 0 then
			d.titulo, d.tono = L["Nada a la venta"], "neutro"
			d.texto = L["Cuando abras la casa de subastas, Alfa recordará lo que tienes a la venta, lo que ya se vendió y cuándo vence, en todos tus personajes."]
			d.estado = { texto = L["Vacía"], tono = "neutro" }
		else
			d.titulo = format(L["%s a la venta, por unos %s"], N.Plural(r.activas, L["%d cosa"], L["%d cosas"]), M.Dinero(r.valor))
			d.tono = r.vendidas > 0 and "exito" or "acento"
			local partes = {}
			if r.vendidas > 0 then partes[#partes + 1] = format(L["Ya se vendieron %d (%s): el dinero te espera en el buzón."], r.vendidas, M.Dinero(r.vendido)) end
			if r.vencidas > 0 then partes[#partes + 1] = format(L["%d vencieron y vuelven por el buzón."], r.vencidas) end
			if r.proxima then partes[#partes + 1] = format(L["La primera %s."], Su.Vence(r.proxima)) end
			if r.personajes > 1 then partes[#partes + 1] = format(L["De %d de tus personajes."], r.personajes) end
			d.texto = table.concat(partes, " ")
			d.estado = r.vendidas > 0 and { texto = L["Vendidas"], tono = "exito" } or { texto = L["En venta"], tono = "acento" }
		end
		self.Seccion:Set(L["Tus subastas"], { cuenta = #todas > 0 and #todas or nil })
		self.Tarjeta:Set(d)
		local filas = {}
		local ahora = M.Ahora()
		for i = 1, min(#todas, MAX_SUBASTAS) do
			local o = todas[i]
			local quien = o.propio and "" or (tostring(o.nombre) .. DOT)
			local vencida = o.v ~= 1 and o.fin and o.fin <= ahora
			filas[i] = {
				id = o.id, cantidad = o.q, nombre = o.n or L["Objeto"],
				detalle = quien .. (o.v == 1 and L["Vendida: el dinero está en tu buzón"] or Su.Vence(o.fin)),
				chip = o.v == 1 and L["Vendida"] or (vencida and L["Venció"] or L["En venta"]),
				tono = o.v == 1 and "exito" or (vencida and "aviso" or "neutro"),
				valor = o.u and M.Dinero(o.u * (o.q or 1)) or "—",
			}
		end
		self.Panel:Llenar(filas)
		K.Mostrar(self.Panel, #filas > 0)
		K.Mostrar(self, M.Ajuste("subastas") ~= false)
	end
	return b
end

-- 1.4.2: «Siempre a la mano» (Reponer.lua): lo que el comerciante te repone con un clic.
local CANTIDADES = { 5, 10, 20, 40, 60, 100, 200 }
local function menuReponer(dueno, e)
	local ops = {}
	for _, n in ipairs(CANTIDADES) do ops[#ops + 1] = { valor = n, texto = format(L["Hasta %d"], n) } end
	ops[#ops + 1] = { valor = 0, texto = L["Quitar de la lista"], icono = "ic-cerrar" }
	K.Menu(dueno, ops, e.quieres, function(n) M.Reponer.Poner(e.id, n) end, 220)
end

local function bloqueReponer(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Siempre a la mano"]))
	b.Tarjeta = b:Agregar(K.Tarjeta(b, { variante = "estado" }))
	b.Panel = b:Agregar(panelDeFilas(b), { espacio = ESP.s })
	function b:Llenar()
		local lista = M.Reponer.Lista()
		local d = { icono = "ic-comercio", lineas = 3 }
		local faltan = 0
		for _, e in ipairs(lista) do if e.tienes < e.quieres then faltan = faltan + 1 end end
		if #lista == 0 then
			d.titulo, d.tono = L["Nada «siempre a la mano» todavía"], "neutro"
			d.texto = L["Si compras lo mismo en dos visitas, te pregunto si quieres tenerlo siempre; luego cada comerciante que lo venda te ofrece reponerlo con un clic. También: /alfa comercio reponer <objeto> <cantidad>."]
			d.estado = { texto = L["Vacía"], tono = "neutro" }
		elseif faltan > 0 then
			d.titulo, d.tono = N.Plural(faltan, L["Te falta reponer %d cosa"], L["Te falta reponer %d cosas"]), "acento"
			d.texto = L["El próximo comerciante que lo venda te lo ofrece con un clic. Clic en una fila: cambiar la cantidad o quitarla."]
			d.estado = { texto = L["Por reponer"], tono = "acento" }
		else
			d.titulo, d.tono = L["Llevas todo lo de siempre"], "exito"
			d.texto = L["Clic en una fila: cambiar la cantidad o quitarla."]
			d.estado = { texto = L["Al día"], tono = "exito" }
		end
		self.Seccion:Set(L["Siempre a la mano"], { cuenta = #lista > 0 and #lista or nil })
		self.Tarjeta:Set(d)
		local filas = {}
		for i, e in ipairs(lista) do
			if i > MAX_MATERIALES then break end
			local listo = e.tienes >= e.quieres
			filas[i] = {
				id = e.id, cantidad = e.tienes, nombre = tostring(e.nombre),
				detalle = format(L["Llevas %d de %d"], e.tienes, e.quieres),
				chip = listo and L["Al día"] or format(L["Faltan %d"], e.quieres - e.tienes), tono = listo and "exito" or "acento",
				valor = "", alClic = function(fila) menuReponer(fila, e) end,
			}
		end
		self.Panel:Llenar(filas)
		K.Mostrar(self.Panel, #filas > 0)
		K.Mostrar(self, M.Ajuste("reponer") ~= false)
	end
	return b
end

local function bloqueComo(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Cómo decide Alfa"]))
	b.Tarjeta = b:Agregar(K.Tarjeta(b, { variante = "normal" }))
	function b:Llenar()
		self.Tarjeta:Set({
			icono = "ic-info", tono = "neutro", titulo = L["Tres caminos para cada objeto"], lineas = 10,
			texto = table.concat({
				L["Para cada objeto Alfa compara tres caminos: venderlo al comerciante, ponerlo en la subasta o transformarlo (con una receta que conoces o desencantándolo)."],
				L["En la subasta cuenta el precio más bajo que vio, menos la comisión (%d %%, estimada). Al desencantar usa tablas del juego clásico, también estimadas."]:format(floor(M.Comision() * 100 + 0.5)),
				L["Recomienda el camino que te deja más oro, si gana por lo menos un 10 % a venderlo. Si nada da oro, te dice que lo guardes. Alfa nunca vende ni compra por ti."],
			}, " "),
		})
	end
	return b
end

local function ruta(clave) return M.ID .. "." .. clave end

local function grupos(padre)
	local juego = K.GrupoAjustes(padre, { titulo = L["En el juego"] })
	juego:Fila({ titulo = L["Consejo en el cuadro de los objetos"], control = function(f) return K.Interruptor(f, { clave = ruta("tooltip") }) end,
		texto = L["Al pasar el ratón sobre un objeto: su precio en la subasta, lo que paga el comerciante y qué te conviene."] })
	juego:Fila({ titulo = L["Con todo el detalle"], hija = true, activa = function() return M.Ajuste("tooltip") and true or false end,
		control = function(f) return K.Interruptor(f, { clave = ruta("tooltipDetalle") }) end,
		texto = L["Dos líneas: el precio en la subasta, lo que paga el comerciante y lo que conviene. Apagado, una sola línea; con Mayús ves el detalle."] })
	juego:Fila({ titulo = L["Barra de Alfa en la casa de subastas"], control = function(f) return K.Interruptor(f, { clave = ruta("boton") }) end,
		texto = L["El botón «Escanear con Alfa» bajo la ventana de la subasta."] })
	juego:Fila({ titulo = L["Aprender de tus búsquedas"], control = function(f) return K.Interruptor(f, { clave = ruta("busquedas") }) end,
		texto = L["Cuando buscas algo en la subasta, Alfa guarda el precio más bajo que ves."] })
	juego:Fila({ titulo = L["Gangas en la subasta"], control = function(f) return K.Interruptor(f, { clave = ruta("gangas") }) end,
		texto = L["Te señala lo que cuesta menos de lo que suele valer o lo que deja ganancia al desencantarlo. La compra siempre es tuya."] })
	juego:Fila({ titulo = L["Avisar si lo de tu lista sale barato"], control = function(f) return K.Interruptor(f, { clave = ruta("buscadosAviso") }) end,
		texto = L["Con la subasta abierta, un aviso cuando un material que te falta de tu lista cuesta por lo menos un 15 % menos de lo que suele valer."] })
	juego:Fila({ titulo = L["Avisar de cartas que vencen"], control = function(f) return K.Interruptor(f, { clave = ruta("buzonVence") }) end,
		texto = L["Al abrir el buzón, un aviso si una carta con objetos vence en menos de 3 días."] })
	juego:Fila({ titulo = L["Avisar si vendes algo valioso"], control = function(f) return K.Interruptor(f, { clave = ruta("recompra") }) end,
		texto = L["Si le vendes al comerciante algo azul o mejor, un aviso con «Recomprar» por si fue sin querer."] })
	juego:Fila({ titulo = L["Alt+clic compra una pila"], control = function(f) return K.Interruptor(f, { clave = ruta("pila") }) end,
		texto = L["En el comerciante, Alt+clic sobre algo compra una pila entera (lo que te alcance y lo que tenga)."] })
	-- 1.4.2: Reponer.lua, Reventa.lua y Subastas.lua
	juego:Fila({ titulo = L["Reponer lo de siempre en el comerciante"], control = function(f) return K.Interruptor(f, { clave = ruta("reponer") }) end,
		texto = L["Al hablar con un comerciante que vende lo que tienes «siempre a la mano», un aviso con lo que falta y «Comprar». La compra es tu clic."] })
	juego:Fila({ titulo = L["También lo que falta de tu lista de compras"], hija = true, activa = function() return M.Ajuste("reponer") ~= false end,
		control = function(f) return K.Interruptor(f, { clave = ruta("reponerLista") }) end,
		texto = L["Si ese comerciante vende un material que te falta de tu lista (el hilo, el fundente), también te lo ofrece."] })
	juego:Fila({ titulo = L["Avisar si el comerciante vende barato"], control = function(f) return K.Interruptor(f, { clave = ruta("reventa") }) end,
		texto = L["Si un comerciante vende algo que en la subasta vale mucho más (ya con la comisión), un aviso lo dice. La compra siempre es tuya."] })
	juego:Fila({ titulo = L["Recordar tus subastas"], control = function(f) return K.Interruptor(f, { clave = ruta("subastas") }) end,
		texto = L["Lo que tienes a la venta, lo vendido y cuándo vence, en esta página y en el cuadro de cada objeto. Se lee al abrir la casa de subastas."] })
	juego:Fila({ titulo = L["Mandar a tu alt desde el buzón"], control = function(f) return K.Interruptor(f, { clave = ruta("buzonAlt") }) end,
		texto = L["En la pestaña de enviar, un botón por cada lista: pone el nombre y adjunta lo de esa lista. El clic en «Enviar» es tuyo. Las listas: /alfa comercio alt."] })
	juego:Fila({ titulo = L["Ayuda al subastar"], control = function(f) return K.Interruptor(f, { clave = ruta("vender") }) end,
		texto = L["Al poner algo a la venta en la subasta: su precio sugerido, su historial de 14 días y un aviso si lo das muy barato."] })
	juego:Fila({ titulo = L["Avisar si lo das más barato de"], hija = true, activa = function() return M.Ajuste("vender") ~= false end,
		texto = L["Cuánto por debajo de lo que vale tiene que estar tu precio para avisarte."],
		control = function(f)
			local d = K.Deslizador(f, { min = 10, max = 70, paso = 5, clave = ruta("precioBajo"), formato = function(v) return ("%d %%"):format(floor((v or 0) + 0.5)) end })
			d.alfaAnchoFila = 220
			return d
		end })

	local compras = K.GrupoAjustes(padre, { titulo = L["Lista de compras y oficios"] })
	compras:Fila({ titulo = L["Avisar al juntar lo de tu lista"], control = function(f) return K.Interruptor(f, { clave = ruta("listaAviso") }) end,
		texto = L["Un aviso cuando juntas todo lo de un material o la lista entera."] })
	-- 1.3.8: lo de tus otros personajes (ListaCuenta.lua).
	compras:Fila({ titulo = L["Contar lo de tus otros personajes"], control = function(f) return K.Interruptor(f, { clave = ruta("listaCuenta") }) end,
		texto = L["Lo que ya tienen en sus bolsas y su banco no sale como «falta», y cada material dice quién lo tiene."] })
	compras:Fila({ titulo = L["Oficios de 1 a 300 en esta página"], control = function(f) return K.Interruptor(f, { clave = ruta("oficios") }) end,
		texto = L["Tus oficios con su paso de ahora y la guía de cada uno. La guía también se abre con /alfa comercio oficios."] })
	compras:Fila({ titulo = L["Avisar cuando una receta pasa a verde"], control = function(f) return K.Interruptor(f, { clave = ruta("avisoVerde") }) end,
		texto = L["Mientras subes un oficio, un aviso cuando la receta que haces ya solo da puntos a veces, y cuál sigue."] })
	compras:Fila({ titulo = L["Tu semana en la subasta"], control = function(f) return K.Interruptor(f, { clave = ruta("semana") }) end,
		texto = L["Lo que vendiste y compraste estos 7 días, en esta página. Se anota al tomar las cartas de la subasta del buzón. También: /alfa comercio semana."] })
	-- 1.3.0 (Fabricar.lua)
	compras:Fila({ titulo = L["Qué fabricar con lo que tienes"], control = function(f) return K.Interruptor(f, { clave = ruta("fabricar") }) end,
		texto = L["En tus recetas que dejan ganancia, primero las que ya puedes hacer con lo que llevas, y cuánto ganarías haciéndolas todas."] })

	local cuentas = K.GrupoAjustes(padre, { titulo = L["Las cuentas"] })
	cuentas:Fila({ titulo = L["Comisión de la subasta"],
		texto = L["Lo que se queda la subasta de cada venta. Suele ser 5 % en la de tu facción y 15 % en la neutral. Es un estimado."],
		control = function(f)
			local d = K.Deslizador(f, { min = 0, max = 15, paso = 1, clave = ruta("comision"), formato = function(v) return ("%d %%"):format(floor((v or 0) + 0.5)) end })
			d.alfaAnchoFila = 220
			return d
		end })
	cuentas:Fila({ titulo = L["Considerar desencantar"], texto = L["«Siempre» sirve si un amigo encantador te ayuda. Las tablas de desencantar son estimadas."],
		control = function(f)
			return K.Desplegable(f, { clave = ruta("desencantar"), ancho = 220, opciones = {
				{ valor = "auto", texto = L["Si tú o tus personajes pueden"] },
				{ valor = "siempre", texto = L["Siempre"] },
				{ valor = "nunca", texto = L["Nunca"] },
			} })
		end })
	cuentas:Fila({ titulo = L["Avisar cuando los precios tengan más de"], texto = L["Los precios cambian: después de estos días Alfa te recuerda escanear otra vez."],
		control = function(f)
			local d = K.Deslizador(f, { min = 1, max = 14, paso = 1, clave = ruta("diasViejo"), formato = function(v) local n = floor((v or 0) + 0.5) return N.Plural(n, L["%d día"], L["%d días"]) end })
			d.alfaAnchoFila = 220
			return d
		end })

	local datos = K.GrupoAjustes(padre, { titulo = L["Tus datos"] })
	datos:Fila({ titulo = L["Borrar los precios de este reino"], texto = L["Se borran los precios guardados de la subasta de este reino y facción. Tus recetas se quedan."],
		control = function(f)
			return K.Boton(f, L["Borrar"], function()
				K.Dialogo({
					titulo = L["¿Borrar los precios?"],
					texto = L["Se borran los precios guardados de la subasta de este reino y facción. Tus recetas se quedan."],
					aceptar = L["Borrar"], peligro = true, alAceptar = function() M.Olvidar() end,
				})
			end, { tipo = "peligro", icono = "ic-cerrar" })
		end })
	return { juego, compras, cuentas, datos }
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

local function construir(view)
	pagina = view
	local ui = {}
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "accion", tituloOpciones = L["Tus números"], min = 240 })
	ui.lista = t:AgregarBloque(bloqueLista(ui, t.Extra))
	ui.precios = t:AgregarBloque(bloquePrecios(t.Extra))
	ui.compras = t:AgregarBloque(bloqueCompras(t.Extra))
	ui.reponer = t:AgregarBloque(bloqueReponer(t.Extra)) -- 1.4.2
	ui.recetas = t:AgregarBloque(bloqueRecetas(t.Extra))
	ui.oficios = t:AgregarBloque(bloqueOficios(t.Extra))
	ui.subastas = t:AgregarBloque(bloqueSubastas(t.Extra)) -- 1.4.2
	ui.semana = t:AgregarBloque(bloqueSemana(t.Extra))
	ui.como = t:AgregarBloque(bloqueComo(t.Extra))
	ui.ajustes = grupos(t.Extra)
	for i, g in ipairs(ui.ajustes) do t:AgregarBloque(g, { espacio = i == 1 and ESP.xl or ESP.l }) end
	K.EnPagina(view, t, function()
		local datos, tot, pendientes = analizar()
		t:SetAccion(queHacer(datos, tot, pendientes))
		t:SetOpciones(numeros(tot), L["Tus números"])
		ui.lista:Llenar(datos, tot)
		ui.precios:Llenar(tot)
		ui.compras:Llenar()
		ui.reponer:Llenar()
		ui.recetas:Llenar()
		ui.oficios:Llenar()
		ui.subastas:Llenar()
		ui.semana:Llenar()
		ui.como:Llenar()
		for _, g in ipairs(ui.ajustes) do g:Refrescar() end
	end)
end

local pendienteRehacer = false
local function rehacerLuego()
	if not (pagina and pagina:IsVisible()) or pendienteRehacer then return end
	pendienteRehacer = true
	local function ir()
		pendienteRehacer = false
		if pagina then N.RehacerPagina(pagina) end
	end
	N.Una("comercio.pagina", 0.4, ir)
end

---------------------------------------------------------------------------
-- Para la búsqueda de ajustes de la ventana de Alfa (la página es propia):
-- los ajustes de "En el juego" y "Las cuentas". Borrar los precios no va.
---------------------------------------------------------------------------
local CONTROLES = {
	{ kind = "toggle", key = ruta("tooltip"), label = L["Consejo en el cuadro de los objetos"],
		help = L["Al pasar el ratón sobre un objeto: su precio en la subasta, lo que paga el comerciante y qué te conviene."],
		search = "tooltip, item price, auction price, vendor price" },
	{ kind = "toggle", key = ruta("tooltipDetalle"), label = L["Con todo el detalle"], child = true,
		help = L["Dos líneas: el precio en la subasta, lo que paga el comerciante y lo que conviene. Apagado, una sola línea; con Mayús ves el detalle."],
		search = "tooltip detail, two lines, shift" },
	{ kind = "toggle", key = ruta("boton"), label = L["Barra de Alfa en la casa de subastas"],
		help = L["El botón «Escanear con Alfa» bajo la ventana de la subasta."], search = "auction house, scan button, ah" },
	{ kind = "toggle", key = ruta("busquedas"), label = L["Aprender de tus búsquedas"],
		help = L["Cuando buscas algo en la subasta, Alfa guarda el precio más bajo que ves."], search = "auction search, learn prices" },
	{ kind = "toggle", key = ruta("gangas"), label = L["Gangas en la subasta"],
		help = L["Te señala lo que cuesta menos de lo que suele valer o lo que deja ganancia al desencantarlo. La compra siempre es tuya."],
		search = "auction deals, bargains, cheap, flip, disenchant profit" },
	{ kind = "toggle", key = ruta("buscadosAviso"), label = L["Avisar si lo de tu lista sale barato"],
		help = L["Con la subasta abierta, un aviso cuando un material que te falta de tu lista cuesta por lo menos un 15 % menos de lo que suele valer."],
		search = "shopping list, cheap, auction, deal, lista barata" },
	{ kind = "toggle", key = ruta("avisoVerde"), label = L["Avisar cuando una receta pasa a verde"],
		help = L["Mientras subes un oficio, un aviso cuando la receta que haces ya solo da puntos a veces, y cuál sigue."],
		search = "recipe green, skill up, profession, receta verde" },
	{ kind = "toggle", key = ruta("semana"), label = L["Tu semana en la subasta"],
		help = L["Lo que vendiste y compraste estos 7 días, en esta página. Se anota al tomar las cartas de la subasta del buzón. También: /alfa comercio semana."],
		search = "auction history, sales, purchases, week, ventas, compras" },
	{ kind = "toggle", key = ruta("buzonVence"), label = L["Avisar de cartas que vencen"],
		help = L["Al abrir el buzón, un aviso si una carta con objetos vence en menos de 3 días."], search = "mail expires, expiring mail" },
	-- 1.4.0 (diario)
	{ kind = "toggle", key = ruta("recompra"), label = L["Avisar si vendes algo valioso"],
		help = L["Si le vendes al comerciante algo azul o mejor, un aviso con «Recomprar» por si fue sin querer."],
		search = "buyback, sold by mistake, recomprar, vendí sin querer" },
	{ kind = "toggle", key = ruta("pila"), label = L["Alt+clic compra una pila"],
		help = L["En el comerciante, Alt+clic sobre algo compra una pila entera (lo que te alcance y lo que tenga)."],
		search = "buy stack, alt click, merchant, comprar pila, comerciante" },
	-- 1.4.2
	{ kind = "toggle", key = ruta("reponer"), label = L["Reponer lo de siempre en el comerciante"],
		help = L["Al hablar con un comerciante que vende lo que tienes «siempre a la mano», un aviso con lo que falta y «Comprar». La compra es tu clic."],
		search = "restock, reagents, ammo, water, reponer, siempre a la mano, comprar" },
	{ kind = "toggle", key = ruta("reponerLista"), label = L["También lo que falta de tu lista de compras"], child = true,
		help = L["Si ese comerciante vende un material que te falta de tu lista (el hilo, el fundente), también te lo ofrece."],
		search = "shopping list, vendor, thread, flux, lista de compras" },
	{ kind = "toggle", key = ruta("reventa"), label = L["Avisar si el comerciante vende barato"],
		help = L["Si un comerciante vende algo que en la subasta vale mucho más (ya con la comisión), un aviso lo dice. La compra siempre es tuya."],
		search = "vendor flip, cheap vendor, limited recipe, reventa, barato" },
	{ kind = "toggle", key = ruta("subastas"), label = L["Recordar tus subastas"],
		help = L["Lo que tienes a la venta, lo vendido y cuándo vence, en esta página y en el cuadro de cada objeto. Se lee al abrir la casa de subastas."],
		search = "my auctions, sold, expired, mis subastas, vendidas" },
	{ kind = "toggle", key = ruta("buzonAlt"), label = L["Mandar a tu alt desde el buzón"],
		help = L["En la pestaña de enviar, un botón por cada lista: pone el nombre y adjunta lo de esa lista. El clic en «Enviar» es tuyo. Las listas: /alfa comercio alt."],
		search = "mail alt, send to alt, mail lists, herbs to alchemist" },
	{ kind = "toggle", key = ruta("vender"), label = L["Ayuda al subastar"],
		help = L["Al poner algo a la venta en la subasta: su precio sugerido, su historial de 14 días y un aviso si lo das muy barato."],
		search = "auction sell, suggested price, price history, undercut" },
	{ kind = "slider", key = ruta("precioBajo"), label = L["Avisar si lo das más barato de"], min = 10, max = 70, step = 5,
		format = function(v) return ("%d %%"):format(floor((v or 0) + 0.5)) end,
		help = L["Cuánto por debajo de lo que vale tiene que estar tu precio para avisarte."], search = "low price warning, cheap" },
	{ kind = "toggle", key = ruta("listaAviso"), label = L["Avisar al juntar lo de tu lista"],
		help = L["Un aviso cuando juntas todo lo de un material o la lista entera."], search = "shopping list, materials, reagents" },
	{ kind = "toggle", key = ruta("listaCuenta"), label = L["Contar lo de tus otros personajes"],
		help = L["Lo que ya tienen en sus bolsas y su banco no sale como «falta», y cada material dice quién lo tiene."],
		search = "shopping list, alts, other characters, bank, account, lista de compras, otros personajes" },
	{ kind = "toggle", key = ruta("fabricar"), label = L["Qué fabricar con lo que tienes"],
		help = L["En tus recetas que dejan ganancia, primero las que ya puedes hacer con lo que llevas, y cuánto ganarías haciéndolas todas."],
		search = "crafting profit, what to craft, profession gold" },
	{ kind = "toggle", key = ruta("oficios"), label = L["Oficios de 1 a 300 en esta página"],
		help = L["Tus oficios con su paso de ahora y la guía de cada uno. La guía también se abre con /alfa comercio oficios."],
		search = "professions, leveling guide, 1-300, crafting" },
	{ kind = "slider", key = ruta("comision"), label = L["Comisión de la subasta"], min = 0, max = 15, step = 1,
		format = function(v) return ("%d %%"):format(floor((v or 0) + 0.5)) end,
		help = L["Lo que se queda la subasta de cada venta. Suele ser 5 % en la de tu facción y 15 % en la neutral. Es un estimado."],
		search = "auction cut, fee, commission" },
	{ kind = "dropdown", key = ruta("desencantar"), label = L["Considerar desencantar"],
		help = L["«Siempre» sirve si un amigo encantador te ayuda. Las tablas de desencantar son estimadas."],
		choices = { { value = "auto", label = L["Si tú o tus personajes pueden"] }, { value = "siempre", label = L["Siempre"] },
			{ value = "nunca", label = L["Nunca"] } },
		search = "disenchant, enchanting" },
	{ kind = "slider", key = ruta("diasViejo"), label = L["Avisar cuando los precios tengan más de"], min = 1, max = 14, step = 1,
		format = function(v) local n = floor((v or 0) + 0.5) return N.Plural(n, L["%d día"], L["%d días"]) end,
		help = L["Los precios cambian: después de estos días Alfa te recuerda escanear otra vez."], search = "old prices, stale, days, scan reminder" },
}

---------------------------------------------------------------------------
-- Módulo, comandos y avisos
---------------------------------------------------------------------------

N.Modulo({
	id = M.ID, nombre = L["Comercio"], icono = "ic-comercio", orden = 45, comando = M.ID,
	subtitulo = L["¿Vender, subastar o transformar? Lo que más oro te deja con cada objeto."],
	ajustes = {
		tooltip = true, boton = true, busquedas = true, buzon = true, buzonVence = true,
		comision = 5, desencantar = "auto", diasViejo = 3,
		vender = true, precioBajo = 30, listaAviso = true, oficios = true,
		fabricar = true, -- 1.3.0: Fabricar.lua
		gangas = true, -- 1.3.7: Gangas.lua
		buzonAlt = true, -- 1.3.7: Envios.lua
		listaCuenta = true, -- 1.3.8: ListaCuenta.lua
		tooltipDetalle = false, -- 1.3.9: el consejo del cuadro en dos líneas (de fábrica, una; con Mayús, dos)
		buscadosAviso = true, -- 1.4.0: lo de tu lista, barato en la subasta (Buscados.lua)
		avisoVerde = true, -- 1.4.0: la receta que pasa a verde (RecetasVerde.lua)
		semana = true, -- 1.4.0: tu semana en la subasta en esta página (Semana.lua)
		recompra = true, -- 1.4.0 (diario): lo valioso que vendiste sin querer (Recompra.lua)
		pila = true, -- 1.4.0 (diario): Alt+clic en el comerciante compra una pila (Pila.lua)
		reponer = true, reponerLista = true, -- 1.4.2: «Siempre a la mano» (Reponer.lua)
		reventa = true, -- 1.4.2: lo que el comerciante vende barato (Reventa.lua)
		subastas = true, -- 1.4.2: tus subastas (Subastas.lua)
	},
	controles = CONTROLES,
	construir = construir,
})

-- /alfa comercio [escanear | precio <objeto>]
local function comando(resto)
	resto = type(resto) == "string" and resto or ""
	local verbo, arg = resto:match("^%s*(%S*)%s*(.-)%s*$")
	verbo = (verbo or ""):lower()
	if verbo == "escanear" or verbo == "scan" then
		M.Escanear()
		return
	end
	if verbo == "oficios" or verbo == "professions" then
		M.VentanaOficios.Abrir()
		return
	end
	-- 1.3.7: listas para mandar a tus personajes (Envios.lua) y las gangas (Gangas.lua).
	if verbo == "alt" then
		M.Envios.Comando(arg)
		return
	end
	if verbo == "gangas" or verbo == "deals" then
		M.ImprimirGangas()
		return
	end
	-- 1.4.2: «Siempre a la mano» (Reponer.lua).
	if verbo == "reponer" or verbo == "restock" then
		M.Reponer.Comando(arg)
		return
	end
	-- 1.4.0: tu semana en la subasta (Semana.lua).
	if verbo == "semana" or verbo == "week" then
		M.ImprimirSemana()
		return
	end
	if verbo == "precio" or verbo == "price" then
		local id = tonumber((arg or ""):match("item:(%d+)") or arg)
		-- 1.3.7: también con el nombre del objeto («/alfa comercio precio lino»).
		if not id and arg and arg ~= "" then id = M.BuscarPorNombre(arg) end
		if not id then
			N.Imprimir(L["Uso: /alfa comercio precio <objeto o su nombre>"])
			return
		end
		local c = M.Consejo(id)
		local uno, dos = M.LineasCuadro(c)
		if not uno then
			N.Imprimir(L["Aún no conozco ese objeto. Pásale el ratón encima y vuelve a intentarlo."])
			return
		end
		N.Imprimir((c.info.link or c.info.nombre or "") .. "  " .. uno)
		N.Imprimir(dos)
		return
	end
	N.Abrir(M.ID)
end
A.RegisterCommand(M.ID, comando, L["¿Vender, subastar o transformar? (escanear, precio <objeto>, oficios, gangas, alt)"])

-- 1.2.9: Lya sabe contar lo nuevo de Comercio (Pregúntale a Lya).
A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) ~= "table" or type(Lya.Ensenar) ~= "function" then return end
	for _, p in ipairs({
		{ id = "comercio.lista", icono = "ic-lista", pregunta = L["¿Qué me falta para una receta?"],
			respuesta = L["En Comercio, en «Tu lista de compras», agrega una receta o un oficio: te digo cuánto tienes, cuánto te falta y de dónde sale. Se va llenando sola mientras juntas."] },
		{ id = "comercio.oficios", icono = "ic-oficios", pregunta = L["¿Cómo subo mi oficio de 1 a 300?"],
			respuesta = L["En Comercio, en «Oficios», cada uno tiene su guía de 1 a 300: qué hacer en cada tramo, lo que te falta y dónde aprender el siguiente rango."] },
		{ id = "comercio.fabricar", icono = "ic-oficios", pregunta = L["¿Qué fabrico para ganar oro?"],
			respuesta = L["En Comercio, «Tus recetas que dejan ganancia» te dice cuánto deja cada receta con los precios de tu reino, y primero las que ya puedes hacer con lo que llevas."] },
		{ id = "comercio.vender", icono = "ic-oro", pregunta = L["¿A cuánto vendo en la subasta?"],
			respuesta = L["Pon tu objeto en la pestaña de vender: a un lado te digo su precio sugerido, cómo le fue estos días y te aviso si lo das muy barato. El precio lo pones tú."] },
	}) do
		p.modulo = M.ID
		pcall(Lya.Ensenar, p)
	end
end)

A.On("ALFA_COMERCIO", rehacerLuego)
A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" or path == "" or path:sub(1, #M.ID + 1) == M.ID .. "." then
		M.Cambio()
	end
end)
A.RegisterEvent("BAG_UPDATE_DELAYED", rehacerLuego)
A.RegisterEvent("GET_ITEM_INFO_RECEIVED", rehacerLuego)
A.RegisterEvent("AUCTION_HOUSE_SHOW", rehacerLuego)
A.RegisterEvent("AUCTION_HOUSE_CLOSED", rehacerLuego)
