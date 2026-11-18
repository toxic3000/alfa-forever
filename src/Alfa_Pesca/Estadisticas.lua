-- Alfa - Pesca: estadísticas y logros (toxic3000 / La Jauría). GPL-3.0.
--
-- La pestaña Estadísticas: la sesión de ahora (lanzamientos, capturas, éxito,
-- por hora, tiempo medio hasta que pica, tiempo pescando, valor de venta y
-- de subasta), desde siempre, lo pescado en la sesión y las sesiones
-- anteriores con lo que sacaste y dónde.
-- La pestaña Logros: los logros de pesca de Alfa con lo que llevas.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local V = M.V

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring
local ESP = K.ESP
local DOT = " \194\183 "

local function num(v) return tonumber(v) or 0 end

local function hayComercio()
	local C = rawget(_G, "AlfaComercio")
	return type(C) == "table" and type(C.PrecioSubasta) == "function"
end

-- Las tarjetas compactas de una sesión, del historial o de la vida.
local function tarjetas(t)
	local c = M.Cuentas(t)
	local out = {
		{ variante = "compacta", icono = "ic-pesca", titulo = L["Lanzamientos"], valor = tostring(num(t.lanzamientos)) },
		{ variante = "compacta", icono = "ic-exito", titulo = L["Capturas"], valor = tostring(num(t.capturas)),
			texto = num(t.total) > num(t.capturas) and format(L["%d piezas"], num(t.total)) or nil },
		{ variante = "compacta", icono = "ic-nivel", titulo = L["Éxito"], valor = V.Porcentaje(c.exito),
			texto = num(t.escapes) > 0 and format(L["se escaparon %d"], num(t.escapes)) or nil },
		{ variante = "compacta", icono = "ic-reloj", titulo = L["Por hora"], valor = c.porHora and tostring(floor(c.porHora + 0.5)) or "—" },
		{ variante = "compacta", icono = "ic-reloj", titulo = L["Tiempo hasta que pica"], valor = c.medio and format(L["%.1f s"], c.medio) or "—" },
		{ variante = "compacta", icono = "ic-reloj", titulo = L["Pescando"], valor = num(t.activo) >= 1 and N.Duracion(t.activo) or "0 s" },
		{ variante = "compacta", icono = "ic-oro", titulo = L["Valor de venta"], valor = N.Dinero(num(t.valor), true) },
	}
	if hayComercio() then
		out[#out + 1] = { variante = "compacta", icono = "ic-comercio", titulo = L["Valor en la subasta"], valor = N.Dinero(num(t.subasta), true) }
	end
	return out
end

local function topZonas(zonas, n)
	local z = {}
	for nombre, c in pairs(zonas or {}) do z[#z + 1] = { nombre, num(c) } end
	table.sort(z, function(a, b) return a[2] > b[2] end)
	local partes = {}
	for i = 1, min(n or 3, #z) do partes[#partes + 1] = format(L["%s ×%d"], z[i][1], z[i][2]) end
	return table.concat(partes, DOT)
end

local function topObjetos(objetos, n)
	local o = {}
	for id, c in pairs(objetos or {}) do o[#o + 1] = { id, num(c) } end
	table.sort(o, function(a, b) return a[2] > b[2] end)
	local out = {}
	for i = 1, min(n or 3, #o) do
		local id = o[i][1]
		local nombre = type(id) == "number" and V.NombreObjeto(id) or tostring(id)
		out[#out + 1] = { format(L["%s ×%d"], nombre, o[i][2]), M.TONO_CLASE[M.CLASE[id] or "otro"] or "neutro" }
	end
	return out
end

local function tarjetaSesion(h)
	local c = M.Cuentas(h)
	local fin = h.fin and date("%H:%M", h.fin) or "?"
	local texto = format(L["%d capturas de %d lanzamientos (%s)"], num(h.capturas), num(h.lanzamientos), V.Porcentaje(c.exito))
	local donde = topZonas(h.zonas, 3)
	if donde ~= "" then texto = texto .. "\n" .. donde end
	return {
		icono = "ic-pesca", tono = "acento",
		titulo = format(L["%s – %s"], V.Fecha(h.inicio), fin),
		texto = texto, insignias = topObjetos(h.objetos, 3),
		valor = N.Dinero(num(h.valor), true),
		lineas = 3,
	}
end

---------------------------------------------------------------------------
-- Estadísticas
---------------------------------------------------------------------------
local VISIBLES = 12

local function construirEstadisticas(padre)
	local p = V.Pagina(padre)
	local pila = p.pila
	local ui = { verMas = false }
	ui.secSesion = pila:Agregar(K.Seccion(pila, L["Esta sesión"]))
	ui.sesion = pila:Agregar(K.Rejilla(pila, { min = 250, gap = ESP.s }), { espacio = ESP.m })
	ui.secObjetos = pila:Agregar(K.Seccion(pila, L["Lo pescado en esta sesión"]))
	ui.objetos = pila:Agregar(V.RejillaObjetos(pila, 240), { espacio = ESP.m })
	ui.vacio = pila:Agregar(K.Vacio(pila, { lobo = "dormido", titulo = L["Todavía no has pescado nada en esta sesión"],
		texto = L["Abre el modo pesca y pulsa tu tecla: lo que saques aparece aquí."] }), { espacio = ESP.m })
	ui.secVida = pila:Agregar(K.Seccion(pila, L["Desde siempre"]))
	ui.vida = pila:Agregar(K.Rejilla(pila, { min = 250, gap = ESP.s }), { espacio = ESP.m })
	ui.secHist = pila:Agregar(K.Seccion(pila, L["Sesiones anteriores"]))
	ui.hist = pila:Agregar(K.Rejilla(pila, { min = 360, gap = ESP.m }), { espacio = ESP.m })
	ui.histVacio = pila:Agregar(V.Parrafo(pila, "nota", "textoTenue"), { espacio = ESP.s })
	p.antes = function()
		local s = M.Sesion()
		ui.secSesion:Set(L["Esta sesión"], { cuenta = s.inicio and format(L["desde las %s"], date("%H:%M", s.inicio)) or nil,
			enlace = { texto = L["Empezar otra"], alClic = function()
				K.Dialogo({ titulo = L["¿Empezar una sesión nueva?"], texto = L["La de ahora pasa a tus sesiones anteriores. Tu diario y tus logros no cambian."],
					aceptar = L["Empezar otra"], alAceptar = function() M.NuevaSesion() end })
			end } })
		ui.sesion:Llenar(tarjetas(s))
		local lista = M.Objetos()
		ui.objetos:Poner(lista)
		K.Mostrar(ui.secObjetos, #lista > 0)
		K.Mostrar(ui.vacio, #lista == 0)
		ui.vida:Llenar(tarjetas(M.Vida()))
		local v = M.Vida()
		ui.secVida:Set(L["Desde siempre"], { cuenta = format(L["%d sesiones · %d especies"], v.sesiones, M.Especies()) })
		local h = M.Historial()
		local n = ui.verMas and #h or min(#h, VISIBLES)
		local datos = {}
		for i = 1, n do datos[i] = tarjetaSesion(h[i]) end
		ui.hist:Llenar(datos)
		K.Mostrar(ui.hist, n > 0)
		ui.secHist:Set(L["Sesiones anteriores"], { cuenta = #h > 0 and #h or nil,
			enlace = #h > VISIBLES and { texto = ui.verMas and L["Ver menos"] or format(L["Ver todas (%d)"], #h), alClic = function()
				ui.verMas = not ui.verMas
				V.Acomodar()
			end } or nil })
		ui.histVacio:Set(#h == 0 and L["Una sesión termina tras 20 minutos sin lanzar o cuando empiezas otra; entonces aparece aquí con lo que sacaste y dónde."] or nil)
	end
	return p
end

V.Registrar("estadisticas", { nombre = L["Estadísticas [pesca]"], icono = "ic-nivel", orden = 2,
	cambia = { registro = true, captura = true, canal = true }, construir = construirEstadisticas })

---------------------------------------------------------------------------
-- Logros
---------------------------------------------------------------------------
local function tarjetaLogro(lg, hecho)
	local medido = M.R.Medir(lg.que)
	local d = { icono = lg.icono, titulo = lg.nombre, texto = lg.texto, tono = hecho and "exito" or "neutro" }
	if hecho then
		d.insignias = { { format(L["Logrado el %s"], date("%d/%m/%Y", hecho)), "exito", "ic-exito" } }
	else
		local actual = min(medido, lg.n)
		local texto
		if lg.que == "hora" then texto = format(L["%s de %s"], N.Duracion(actual), N.Duracion(lg.n))
		elseif lg.que == "valor" then texto = format(L["%s de %s"], N.Dinero(actual, true), N.Dinero(lg.n, true))
		else texto = format(L["%d de %d"], actual, lg.n) end
		d.progreso = { actual = actual, total = lg.n, texto = texto }
	end
	return d
end

local function construirLogros(padre)
	local p = V.Pagina(padre)
	local pila = p.pila
	local ui = {}
	ui.cab = pila:Agregar(K.Tarjeta(pila, { variante = "estado" }))
	ui.secHechos = pila:Agregar(K.Seccion(pila, L["Logrados"]))
	ui.hechos = pila:Agregar(K.Rejilla(pila, { min = 260, gap = ESP.m }), { espacio = ESP.m })
	ui.secFaltan = pila:Agregar(K.Seccion(pila, L["Por lograr"]))
	ui.faltan = pila:Agregar(K.Rejilla(pila, { min = 260, gap = ESP.m }), { espacio = ESP.m })
	p.antes = function()
		local hechos = M.Logros()
		local si, no = {}, {}
		for _, lg in ipairs(M.LOGROS) do
			if hechos[lg.id] then si[#si + 1] = tarjetaLogro(lg, hechos[lg.id]) else no[#no + 1] = tarjetaLogro(lg) end
		end
		ui.cab:Set({ lobo = #si == #M.LOGROS and "aullando" or "normal", tono = "acento",
			titulo = format(L["%d de %d logros de pesca"], #si, #M.LOGROS),
			texto = L["Los logros de la manada: se ganan pescando, cocinando lo que pescas y explorando aguas nuevas. Cada uno se anuncia una sola vez."],
			progreso = { actual = #si, total = #M.LOGROS, huellas = true } })
		ui.hechos:Llenar(si)
		ui.faltan:Llenar(no)
		K.Mostrar(ui.secHechos, #si > 0)
		K.Mostrar(ui.hechos, #si > 0)
		K.Mostrar(ui.secFaltan, #no > 0)
		K.Mostrar(ui.faltan, #no > 0)
	end
	return p
end

V.Registrar("logros", { nombre = L["Logros"], icono = "ic-raros", orden = 5, cambia = { logros = true, registro = true }, construir = construirLogros })
