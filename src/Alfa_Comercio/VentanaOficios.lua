-- Alfa - Comercio: la ventana de oficios de 1 a 300 (toxic3000 / La Jauría). GPL-3.0. 1.2.9.
--
-- Como la guía de Pesca (Alfa_Pesca/Guia.lua), una por oficio, de arriba abajo:
--   * los oficios en píldoras (los tuyos con su habilidad);
--   * tu siguiente paso: qué hacer ahora con lo que te falta, o el rango que
--     ya puedes aprender con «Llévame con el instructor»;
--   * de 1 a 300: cada tramo con su receta, sus reactivos y cuántas veces;
--     el tuyo marcado, los hechos con su palomita. Clic en uno de crear: a tu
--     lista de compras;
--   * lo que te falta de aquí a 300 (bolsas y banco), con «Agregar todo a mi
--     lista» y de dónde sale cada cosa (Codex);
--   * un consejo del oficio.
-- Lo detallado va aquí; la página de Comercio solo muestra los oficios.
--   M.VentanaOficios.Abrir(línea) ; .Visible() ; .Linea()

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP

local type, ipairs, floor, max, min, format, tostring = type, ipairs, math.floor, math.max, math.min, string.format, tostring
local DOT = "  \194\183  "

local VO = {}
M.VentanaOficios = VO

local v, ui = nil, {}
local actual -- la línea que se ve

local function G() return M.OFICIOS_GUIA end
local function Of() return M.Oficios end

local function iconoDe(id)
	if type(id) ~= "number" then return nil end
	local CI = C_Item
	if CI and CI.GetItemIconByID then
		local ok, t = pcall(CI.GetItemIconByID, id)
		if ok and t then return t end
	end
	return nil
end
VO.Icono = iconoDe

local function nombreMapa(id)
	local C = C_Map
	if C and C.GetMapInfo then
		local ok, info = pcall(C.GetMapInfo, id)
		if ok and type(info) == "table" and type(info.name) == "string" then return info.name end
	end
	return nil
end

local function zonas(mapas)
	local out = {}
	for _, m in ipairs(mapas or {}) do
		local n = nombreMapa(m)
		if n then out[#out + 1] = n end
	end
	return table.concat(out, ", ")
end

-- "2 Flor de paz, 1 Vial vacío"
local function textoReactivos(r)
	local partes = {}
	for i = 1, #(r or {}), 2 do
		local id, q = r[i], r[i + 1]
		if type(id) == "number" then partes[#partes + 1] = format(L["%d %s"], q or 1, M.NombreObjeto(id)) end
	end
	return table.concat(partes, ", ")
end

local function nombresDe(ids)
	local partes = {}
	for _, id in ipairs(ids or {}) do partes[#partes + 1] = M.NombreObjeto(id) end
	return table.concat(partes, ", ")
end

---------------------------------------------------------------------------
-- Las secciones
---------------------------------------------------------------------------

local function opciones()
	local ops = {}
	for _, o in ipairs(Of().Lista()) do
		ops[#ops + 1] = { valor = o.linea, texto = L[o.guia.nombre], cuenta = o.rank }
	end
	return ops
end

local function siguientePaso(linea)
	local g = G()[linea]
	local rank, mx = Of().Habilidad(linea)
	local d = { icono = "ic-oficios", tono = "acento", sobre = L["Tu siguiente paso"] }
	local rango = Of().Rango(linea, rank, mx or 0)
	if not rank then
		d.titulo, d.texto = rango.titulo, rango.texto
		d.accion = { texto = L["Llévame con el instructor"], icono = "ic-flecha", alClic = function() Of().Instructor(linea) end }
		return d
	end
	d.progreso = { actual = rank, total = max(1, mx), texto = format(L["%d de %d"], rank, mx) }
	if rango.tope then
		d.titulo, d.texto, d.tono = rango.titulo, rango.texto, "exito"
		return d
	end
	if rango.puede then
		d.titulo = rango.titulo
		d.texto = rango.texto
		d.accion = { texto = L["Llévame con el instructor"], icono = "ic-flecha", alClic = function() Of().Instructor(linea) end }
		return d
	end
	local p = Of().PasoActual(linea, rank)
	if not p then
		d.titulo, d.texto = rango.titulo, rango.texto
		return d
	end
	if rank >= mx and mx < 300 then
		d.titulo, d.tono = format(L["Llegaste al tope: %d de %d"], rank, mx), "aviso"
		d.texto = rango.texto
		return d
	end
	if g.tipo == "juntar" then
		d.titulo = p.t and L[p.t] or format(L["De %d a %d"], p[1], p[2])
		d.texto = format(L["Busca %s en: %s."], nombresDe(p.da), zonas(p.mapas))
		d.texto = d.texto .. " " .. rango.texto
		return d
	end
	local r, veces = p.r or {}, 0
	for _, x in ipairs(Of().Pasos(linea, rank)) do
		if x.paso == p then r, veces = x.reactivos, x.veces or 0 end
	end
	if p.o then
		d.titulo = veces == 1 and format(L["Haz %s: una vez"], M.NombreObjeto(p.o)) or format(L["Haz %s: unas %d veces"], M.NombreObjeto(p.o), veces)
		d.texto = format(L["Cada vez: %s."], textoReactivos(r))
		if p.t then d.texto = d.texto .. " " .. L[p.t] end
	else
		d.titulo = format(L["De %d a %d"], p[1], p[2])
		d.texto = L[p.t] .. " " .. format(L["Unos materiales: %s."], textoReactivos(r))
	end
	d.texto = d.texto .. " " .. rango.texto
	d.lineas = 5
	d.accion = { texto = L["Agregar lo que me falta"], icono = "ic-mas", alClic = function()
		if M.Lista.AgregarOficio(linea) then
			K.Aviso({ titulo = L["Lista de compras"], icono = "ic-exito", tono = "exito",
				texto = format(L["Agregué lo que te falta para subir %s. Lo ves en Comercio."], Of().Nombre(linea)) })
		end
	end }
	d.secundaria = { texto = L["Ver mi lista"], alClic = function() N.Abrir(M.ID) end }
	-- 1.3.8: con un tope menor a 300, la lista de compras va solo hasta tu tope.
	if mx and mx < 300 and rank < mx then
		d.accion.texto = format(L["Agregar lo que falta hasta %d"], mx)
		local meta = mx
		d.accion.alClic = function()
			if M.Lista.AgregarOficio(linea, meta) then
				K.Aviso({ titulo = L["Lista de compras"], icono = "ic-exito", tono = "exito",
					texto = format(L["Agregué lo que te falta para subir %s a %d. Lo ves en Comercio."], Of().Nombre(linea), meta) })
			end
		end
	end
	return d
end

local function tarjetasPasos(linea)
	local g = G()[linea]
	local rank = Of().Habilidad(linea) or 0
	local out = {}
	for _, x in ipairs(Of().Pasos(linea, rank)) do
		local p = x.paso
		local d = { sobre = format(L["%d a %d"], p[1], p[2]), elegida = x.estado == "actual", lineas = 4 }
		if x.estado == "hecho" then d.insignias = { { L["Hecho"], "exito", "ic-exito" } } end
		if g.tipo == "juntar" then
			d.icono, d.tenir = iconoDe(p.da and p.da[1]) or "ic-recoleccion", false
			d.titulo = nombresDe(p.da)
			d.texto = (p.t and (L[p.t] .. " ") or "") .. format(L["Zonas: %s."], zonas(p.mapas))
		elseif p.o then
			d.icono, d.tenir = iconoDe(p.o) or "ic-oficios", false
			d.titulo = M.NombreObjeto(p.o)
			local veces = x.estado == "hecho" and (p.n or 1) or (x.veces or p.n or 1)
			d.texto = veces == 1 and format(L["%s · una vez"], textoReactivos(x.reactivos)) or format(L["%s · unas %d veces"], textoReactivos(x.reactivos), veces)
			if x.estado ~= "hecho" then
				d.alClic = function()
					if M.Lista.Agregar(p.o, veces) then
						K.Aviso({ titulo = L["Lista de compras"], icono = "ic-exito", tono = "exito",
							texto = format(L["Agregué %s ×%d a tu lista."], M.NombreObjeto(p.o), veces) })
					end
				end
				d.ayuda = L["Clic: agregarlo a tu lista de compras."]
			end
		else
			d.icono = "ic-oficios"
			d.titulo = L[p.t]
			d.texto = format(L["Unos materiales: %s."], textoReactivos(p.r))
		end
		out[#out + 1] = d
	end
	return out
end

local function tarjetasFaltan(linea)
	local rank = Of().Habilidad(linea) or 0
	local Li = M.Lista
	Li.Codex(true)
	local out = {}
	for _, x in ipairs(Of().Faltan(linea, rank)) do
		local donde = Li.Donde(x.id)
		-- 1.3.8: lo de tus otros personajes también cuenta (ListaCuenta.lua).
		local otros = M.TienesOtros and M.TienesOtros(x.id) or 0
		x.faltan = math.max(0, x.faltan - otros)
		out[#out + 1] = {
			variante = "compacta", icono = iconoDe(x.id) or "ic-bolsas", tenir = false,
			titulo = M.NombreObjeto(x.id),
			-- 1.3.8: de dónde sale, en la ayuda (en una línea no cabía).
			texto = M.TextoTienes and M.TextoTienes(x) or format(L["Tienes %d de %d"], x.tienes, x.necesita),
			valor = x.faltan > 0 and format(L["Faltan %d"], x.faltan) or L["Listo"],
			tono = x.faltan > 0 and "acento" or "exito",
			alClic = x.faltan > 0 and function() Li.Guiar(x.id) end or nil,
			ayuda = (donde or x.faltan > 0) and ((donde and (donde .. ". ") or "") .. (x.faltan > 0 and L["Clic: Guíame a conseguirlo."] or "")) or nil,
		}
	end
	return out
end

-- 1.3.8: las recetas de vendedor que te faltan, cerca de ti (RecetasZona.lua).
local function tarjetasRecetas(linea)
	local Rz = M.RecetasZona
	if not Rz then return {}, nil end
	local rank = Of().Habilidad(linea)
	if not rank then return {}, "sinOficio" end
	local lista, motivo = Rz.Buscar(linea, rank)
	local out = {}
	for _, x in ipairs(lista) do
		local partes = { format(L["Vende: %s"], x.vendedor) }
		if x.zona then partes[#partes + 1] = x.aqui and format(L["aquí, en %s"], x.zona) or x.zona end
		local d = {
			variante = "normal", icono = iconoDe(x.id) or "ic-oficios", tenir = false, lineas = 3,
			titulo = x.nombre, texto = table.concat(partes, DOT),
			insignias = { x.puede and { L["Ya puedes"], "exito", "ic-exito" } or { format(L["Con habilidad %d"], x.req), "neutro" } },
			alClic = function() M.RecetasZona.Ir(x) end,
			ayuda = x.limitada and L["Clic: la flecha a su vendedor. Vende pocas a la vez: puede no tenerla."] or L["Clic: la flecha a su vendedor."],
		}
		out[#out + 1] = d
	end
	return out, motivo
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------

local function llenar()
	if not (v and actual) then return end
	local g = G()[actual]
	ui.oficios:SetOpciones(opciones())
	ui.oficios:SetValor(actual)
	ui.paso:Set(siguientePaso(actual))
	ui.secPasos:Set(format(L["%s de 1 a 300"], L[g.nombre]))
	ui.pasos:Llenar(tarjetasPasos(actual))
	local crear = g.tipo == "crear"
	local faltan = crear and tarjetasFaltan(actual) or {}
	ui.secFaltan:Set(L["Lo que te falta para llegar a 300"], {
		cuenta = #faltan > 0 and #faltan or nil,
		enlace = #faltan > 0 and { texto = L["Agregar todo a mi lista"], alClic = function()
			if M.Lista.AgregarOficio(actual) then
				K.Aviso({ titulo = L["Lista de compras"], icono = "ic-exito", tono = "exito",
					texto = format(L["Agregué lo que te falta para subir %s. Lo ves en Comercio."], Of().Nombre(actual)) })
			end
		end } or nil })
	ui.faltan:Llenar(faltan)
	K.Mostrar(ui.secFaltan, #faltan > 0)
	K.Mostrar(ui.faltan, #faltan > 0)
	-- 1.3.8: recetas cerca de ti y tu instructor.
	local recetas, motivo = tarjetasRecetas(actual)
	local linea = actual
	ui.secRecetas:Set(L["Recetas que te faltan cerca de ti"], {
		cuenta = #recetas > 0 and #recetas or nil,
		enlace = motivo ~= "sinOficio" and { texto = L["Tu instructor más cercano"], alClic = function() Of().Instructor(linea) end } or nil })
	if #recetas == 0 then
		local texto
		if motivo == "cargando" then texto = L["Buscando las recetas de vendedor de tu zona…"]
		elseif motivo == "combate" then texto = L["Las busco al terminar el combate."]
		elseif motivo == "codex" then texto = L["Faltan los datos del mundo de Alfa para buscarlas."]
		else texto = L["No hay recetas de vendedor que te falten en tu zona ni cerca. Tu instructor te enseña las demás."] end
		recetas = { { variante = "normal", icono = "ic-info", titulo = L["Recetas de vendedor"], texto = texto, lineas = 4 } }
		if motivo == "cargando" and M.RecetasZona then
			M.RecetasZona.Preparar(function() if VO.Visible() and actual == linea and VO.Rehacer then VO.Rehacer() end end)
		end
	end
	ui.recetas:Llenar(recetas)
	K.Mostrar(ui.secRecetas, motivo ~= "sinOficio")
	K.Mostrar(ui.recetas, motivo ~= "sinOficio")
	ui.nota:Set({ icono = "ic-info", tono = "neutro", titulo = L["Un consejo"], lineas = 6,
		texto = L[g.nota] .. " " .. L["Los números son orientativos: cada receta da puntos según su color (naranja siempre, amarillo casi siempre, verde a veces)."] })
end

local function acomodar()
	if not (v and v:IsShown() and ui.pila) then return end
	local ancho = v:AnchoCuerpo() - 2 * v.margen
	local h = ui.pila:Acomodar(ancho)
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -v.margen)
	v:SetAltoContenido(h + 2 * v.margen)
end

local function armar()
	v = K.Ventana({ nombre = "AlfaComercioOficios", titulo = L["Oficios"], icono = "ic-oficios", ancho = 820, alto = 640, desplazar = true })
	v:SetTitulo(L["Oficios"], L["De 1 a 300: qué hacer, con qué y dónde aprender"], "ic-oficios")
	v.alAcomodar = acomodar
	local p = K.Pila(v.Cuerpo, { espacio = ESP.base })
	ui.pila = p
	ui.oficios = p:Agregar(K.Segmentos(p, { estilo = "pildoras", opciones = {}, alCambiar = function(linea)
		actual = linea
		llenar()
		acomodar()
	end }))
	ui.paso = p:Agregar(K.Tarjeta(p, { variante = "accion" }), { espacio = ESP.l })
	ui.secPasos = p:Agregar(K.Seccion(p, ""), { espacio = ESP.l })
	ui.pasos = p:Agregar(K.Rejilla(p, { min = 300, gap = ESP.m }), { espacio = ESP.m })
	ui.secFaltan = p:Agregar(K.Seccion(p, ""), { espacio = ESP.l })
	ui.faltan = p:Agregar(K.Rejilla(p, { min = 300, gap = ESP.s, variante = "compacta" }), { espacio = ESP.m })
	ui.secRecetas = p:Agregar(K.Seccion(p, ""), { espacio = ESP.l })
	ui.recetas = p:Agregar(K.Rejilla(p, { min = 300, gap = ESP.m }), { espacio = ESP.m })
	ui.nota = p:Agregar(K.Tarjeta(p, { variante = "normal" }), { espacio = ESP.l })
end

function VO.Abrir(linea)
	if N.Permitido and not N.Permitido() then return false end
	local Gd = G()
	if not (linea and Gd[linea]) then
		-- El primero que conoces, o Alquimia.
		linea = actual
		if not linea then
			for _, o in ipairs(Of().Lista()) do if o.conocido then linea = o.linea break end end
		end
		linea = linea or Gd.ORDEN[1]
	end
	actual = linea
	if not v then armar() end
	v:Abrir()
	llenar()
	K.Despues(0.05, acomodar)
	return true
end

function VO.Visible() return v ~= nil and v:IsShown() end
-- 1.3.8: rehacerla ya (las recetas de la zona llegan después).
function VO.Rehacer() if VO.Visible() then llenar() acomodar() end end
function VO.Linea() return actual end
function VO.Ventana() return v end

-- Lo que cambia mientras la ventana está abierta.
local pendiente = false
local function rehacer()
	if not VO.Visible() or pendiente then return end
	pendiente = true
	K.Despues(0.4, function()
		pendiente = false
		if VO.Visible() then llenar() acomodar() end
	end)
end
A.RegisterEvent("SKILL_LINES_CHANGED", rehacer)
A.RegisterEvent("BAG_UPDATE_DELAYED", rehacer)
A.On("ALFA_COMERCIO_LISTA", rehacer)
-- 1.3.8: las recetas cerca de ti cambian con la zona.
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", rehacer)
