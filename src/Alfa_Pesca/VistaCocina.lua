-- Alfa - Pesca: la pestaña Cocina (toxic3000 / La Jauría). GPL-3.0.
--
-- Arriba, la cola: qué sigue y el botón "Cocinar el siguiente lote" (cada
-- clic tuyo cocina un lote; si la Cocina del juego no está abierta, ese clic
-- la abre) y "Encender una fogata". Debajo, tu cola y las recetas de
-- pescado: si la sabes, la habilidad que pide, los ingredientes que tienes y
-- para cuántas alcanza, con "A la cola" o "Guíame a la receta".

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local V = M.V
local Co = M.Cocina

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring
local ESP = K.ESP
local DOT = " \194\183 "

local function avisar(texto, tono)
	K.Aviso({ titulo = L["Cocina junto al agua"], texto = texto, icono = M.ICONO.fogata, tono = tono or "acento", duracion = 4 })
end

local function cocinar()
	local ok, texto = Co.CocinarLote()
	if not ok and texto then avisar(texto, "aviso") end
end

local function tarjetaCola()
	local c = Co.Siguiente()
	local d = { icono = M.ICONO.fogata, tono = "acento", sobre = L["Cocina junto al agua"] }
	if c then
		d.titulo = format(L["Siguiente: %s (%d de %d)"], c.nombre or "?", c.hechas, c.cantidad)
		d.texto = Co.Abierta() and L["Pulsa Cocinar: cada clic hace un lote. Tienes que estar junto a un fuego."]
			or L["El primer clic abre la Cocina del juego; el siguiente cocina el lote. Tienes que estar junto a un fuego."]
		d.accion = { texto = L["Cocinar el siguiente lote"], icono = "ic-seguir", alClic = cocinar }
		d.progreso = { actual = c.hechas, total = max(1, c.cantidad), texto = format(L["%d de %d"], c.hechas, c.cantidad) }
	else
		d.titulo = L["Tu cola de cocina está vacía"]
		d.texto = L["Elige abajo qué cocinar y cuánto: la cola espera tu clic para cada lote."]
	end
	local r, mx = Co.Habilidad()
	if r then d.estado = { texto = format(L["Cocina %d/%d"], r, mx), tono = "neutro" } end
	if Co.SabeFogata() then d.secundaria = { texto = L["Encender una fogata"], alClic = function() end } end
	return d
end

local function textoIngredientes(d)
	local partes = {}
	for _, x in ipairs(d.ingredientes) do
		partes[#partes + 1] = format(L["%s ×%d (tienes %d)"], x.nombre or "?", x.n, x.tienes)
	end
	return table.concat(partes, DOT)
end

local function tarjetaReceta(d)
	local t = {
		icono = d.icono or "ic-oficios", tenir = false, titulo = d.nombre,
		texto = textoIngredientes(d) .. (d.motivo and ("\n" .. d.motivo) or ""),
		insignias = { { format(L["Cocina %d"], d.habilidad), "neutro" },
			{ d.aprendida and L["La sabes"] or L["Sin aprender"], d.aprendida and "exito" or "aviso" } },
	}
	if d.puede then
		t.insignias[#t.insignias + 1] = { format(L["Alcanza para %d"], d.alcanza), "acento" }
		local n = min(5, d.alcanza)
		t.accion = { texto = format(L["%d a la cola"], n), alClic = function() Co.Encolar(d, n) end }
		if d.alcanza > n then t.secundaria = { texto = format(L["Todas (%d)"], d.alcanza), alClic = function() Co.Encolar(d, d.alcanza) end } end
	elseif not d.aprendida then
		t.secundaria = { texto = L["Guíame a la receta"], alClic = function() V.Guiar("item", d.r.receta) end }
	end
	return t
end

local function construir(padre)
	local p = V.Pagina(padre)
	local pila = p.pila
	local ui = {}
	ui.cola = pila:Agregar(K.Tarjeta(pila, { variante = "accion" }))
	ui.secCola = pila:Agregar(K.Seccion(pila, L["Tu cola"]))
	ui.lista = pila:Agregar(K.Rejilla(pila, { min = 260, gap = ESP.s }), { espacio = ESP.m })
	ui.secRecetas = pila:Agregar(K.Seccion(pila, L["Recetas de pescado"]))
	ui.recetas = pila:Agregar(K.Rejilla(pila, { min = 380, gap = ESP.m }), { espacio = ESP.m })
	local envuelto = false
	p.antes = function()
		ui.cola:Set(tarjetaCola())
		-- Los botones de la tarjeta hacen algo protegido: el botón seguro los cubre.
		if not envuelto and ui.cola.Accion then
			M.ConSeguro(ui.cola.Accion, function() return Co.Atributos() end)
			ui.cola.Accion.alfaTrasClic = function() if Co.Abierta() then cocinar() end end
			envuelto = true
		end
		if ui.cola.Secundaria and not ui.cola.Secundaria.alfaSeguro then
			M.ConSeguro(ui.cola.Secundaria, function()
				local n = Co.NombreFogata()
				return n and { type = "spell", spell = n } or nil
			end)
		end
		local cola = {}
		for i, c in ipairs(Co.cola) do
			local idx = i
			cola[#cola + 1] = { variante = "compacta", icono = c.icono or "ic-oficios", tenir = false, titulo = c.nombre,
				valor = format(L["%d/%d"], c.hechas, c.cantidad), ayuda = L["Clic: quitar de la cola."],
				alClic = function() Co.Quitar(idx) end }
		end
		ui.lista:Llenar(cola)
		K.Mostrar(ui.lista, #cola > 0)
		ui.secCola:Set(L["Tu cola"], { cuenta = #cola > 0 and #cola or nil,
			enlace = #cola > 0 and { texto = L["Vaciar"], alClic = function() Co.Vaciar() end } or nil })
		K.Mostrar(ui.secCola, #cola > 0)
		local recetas = {}
		for _, d in ipairs(Co.Recetas()) do recetas[#recetas + 1] = tarjetaReceta(d) end
		ui.recetas:Llenar(recetas)
	end
	return p
end

V.Registrar("cocina", { nombre = L["Cocina"], icono = M.ICONO.fogata, orden = 4, cambia = { cocina = true, captura = true }, construir = construir })
