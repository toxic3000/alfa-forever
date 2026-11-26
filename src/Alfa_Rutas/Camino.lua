-- Alfa - Rutas: elegir el camino cuando una guía termina en varias (Toxic /
-- La Jauría). GPL-3.0.
--
-- Reemplaza la elección de camino del motor (ROUTE_CHOICE, docs/KIT.md): una
-- ventana del Kit con la opción que Alfa recomienda en grande (la más rápida
-- para tu nivel, Engine.GetRouteChoice) y las demás en tarjetas, cada una con
-- su zona, sus niveles, cuántas misiones trae y cuánto tarda. Un clic la
-- elige; "Después" la deja para luego (el rastreador la vuelve a ofrecer).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K

local ipairs, format, floor = ipairs, string.format, math.floor

local v, ui, pedido = nil, {}, nil

local function insignias(o, tono)
	local out = {}
	local u = A.UI
	local lv = u and u.LevelRange and u.LevelRange(o.minLevel, o.maxLevel)
	if lv then out[#out + 1] = { format(L["Nivel %s"], lv), tono or "neutro" } end
	if o.quests and o.quests > 0 then out[#out + 1] = { M.Plural(o.quests, L["%d misión"], L["%d misiones"]), "neutro" } end
	if o.seconds and o.seconds > 0 then out[#out + 1] = { format(L["≈ %s"], M.Minutos(o.seconds)), "neutro", "ic-reloj" } end
	if o.chosen then out[#out + 1] = { L["Tu elección"], "acento" } end
	if o.outleveled then out[#out + 1] = { L["Ya la superaste"], "aviso" } end
	return out
end

local function construir()
	v = K.Ventana({ nombre = "AlfaCamino", titulo = L["¿Por dónde sigues?"], subtitulo = L["Tu guía terminó y el camino se abre"],
		icono = "ic-ruta", ancho = 760, alto = 560, desplazar = true,
		alCerrar = function() if pedido and pedido.Despues then local p = pedido pedido = nil p.Despues() end end })
	ui.pila = K.Pila(v.Cuerpo, { espacio = K.ESP.l })
	ui.reco = ui.pila:Agregar(K.Tarjeta(ui.pila, { variante = "accion" }))
	ui.seccion = ui.pila:Agregar(K.Seccion(ui.pila, L["Otros caminos"]))
	ui.rej = ui.pila:Agregar(K.Rejilla(ui.pila, { min = 300, gap = K.ESP.base }), { espacio = K.ESP.m })
	v:SetPie({ K.Boton(v, L["Ahora no"], function() v:Cerrar() end, { tipo = "fantasma" }) })
	v.alAcomodar = function() if v:IsShown() then ui.Acomodar() end end
end

function ui.Acomodar()
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -K.ESP.base)
	local h = ui.pila:Acomodar(v:AnchoCuerpo())
	v:SetAltoContenido(h + 2 * K.ESP.base)
end

local function elegir(id)
	local p = pedido
	pedido = nil
	if v then v:Cerrar() end
	if p and p.Elegir then p.Elegir(id) end
	M.Empezar()
end

local function mostrar(p)
	pedido = p
	if not v then construir() end
	local e = p.eleccion or {}
	local reco, otras = nil, {}
	for _, o in ipairs(e.options or {}) do
		if o.recommended and not reco then reco = o else otras[#otras + 1] = o end
	end
	if reco then
		ui.reco:Set({ icono = "ic-huella", sobre = L["Recomendado"], titulo = reco.zoneName or reco.title, texto = reco.pitch or reco.title,
			insignias = insignias(reco, "acento"),
			accion = { texto = reco.open and L["Continuar"] or L["Seguir por aquí"], icono = "ic-seguir", alClic = function() elegir(reco.id) end } })
	end
	K.Mostrar(ui.reco, reco ~= nil)
	local datos = {}
	for _, o in ipairs(otras) do
		datos[#datos + 1] = { icono = "ic-ruta", titulo = o.zoneName or o.title, texto = o.pitch or o.title, insignias = insignias(o),
			alClic = function() elegir(o.id) end }
	end
	ui.rej:Llenar(datos)
	K.Mostrar(ui.seccion, #datos > 0)
	K.Mostrar(ui.rej, #datos > 0)
	v:SetTitulo(L["¿Por dónde sigues?"], e.joinsAt and format(L["Todos llegan a %s"], e.joinsAt) or L["Tu guía terminó y el camino se abre"], "ic-ruta")
	v:Abrir()
	ui.Acomodar()
end

N.Reemplazar("ROUTE_CHOICE", function(p)
	if p.accion == "ocultar" then
		pedido = nil
		if v and v:IsShown() then v:Hide() end
		return
	end
	mostrar(p)
end, function() return v ~= nil and v:IsShown() end)
