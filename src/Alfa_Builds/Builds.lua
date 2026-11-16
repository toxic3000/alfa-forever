-- Alfa - Builds: el módulo (Toxic / La Jauría). GPL-3.0.
--
-- Reemplaza a Sonah (rotación y guía de talentos) y a Pawn (comparar
-- equipo) con piezas propias: asistente de builds por objetivo y estilo,
-- talentos aplicables con un clic fuera de combate, pesos que alimentan las
-- flechas de mejora del motor, equipo meta con "cómo conseguirlo", ayudas
-- de combate oficiales y builds para compartir.
--
--   M.Eleccion() -> { objetivo, estilo, spec, build, exacto }
--   M.ElegirBuild(objetivo, estilo, spec?)  ;  M.UsarBuild(id)
--   M.BuildElegido() -> build | nil
--   M.SpecActual() -> clave de rama con más puntos | nil
--   M.PedirAplicar()   vista previa en un W.Modal y, si aceptas, aplica

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local W = A.Widgets
local T = M.Arbol

local format = string.format

local function datos() return N.DatosPersonaje(M.ID) end

---------------------------------------------------------------------------
-- Elección del build
---------------------------------------------------------------------------

function M.SpecActual()
	local vivo = T.Actual()
	local dc = M.DatosClase()
	if not (vivo and dc) then return nil end
	local mejor, puntos = nil, 0
	for i, s in ipairs(vivo.specs) do
		if (s.gastado or 0) > puntos then mejor, puntos = i, s.gastado end
	end
	if not mejor then return nil end
	for clave, sp in pairs(dc.especialidades or {}) do
		if sp.indice == mejor then return clave end
	end
	return nil
end

function M.Eleccion()
	local d = datos()
	d.eleccion = type(d.eleccion) == "table" and d.eleccion or {}
	local e = d.eleccion
	e.objetivo = M.Objetivo(e.objetivo) and e.objetivo or "solo"
	e.estilo = M.Estilo(e.estilo) and e.estilo or "equilibrado"
	return e
end

function M.EleccionExacta()
	local e = M.Eleccion()
	local b = M.BuildElegido()
	return b == nil or b.importado or (b.objetivo == e.objetivo and b.estilo == e.estilo)
end

function M.BuildElegido()
	local e = M.Eleccion()
	local b = e.build and M.Build(e.build)
	if b then return b end
	-- Sin elección guardada: Subir solo / Equilibrado en tu rama (o la recomendada).
	local spec = M.SpecActual()
	return (M.Elegir(e.objetivo, e.estilo, spec))
end

local function alCambiarBuild(b, anterior)
	if not b or (anterior and anterior == b.id) then return end
	if N.Get(M.ID, "escalaAuto") then
		local ok, msg = M.Pesos.Activar(b)
		if not ok then N.Imprimir(msg) end
	end
	if M.Combate then M.Combate.Refrescar() end
end

function M.ElegirBuild(objetivo, estilo, spec)
	local e = M.Eleccion()
	local anterior = e.build
	e.objetivo = M.Objetivo(objetivo) and objetivo or e.objetivo
	e.estilo = M.Estilo(estilo) and estilo or e.estilo
	-- Si no se pidió rama, se queda la del build actual cuando sirve para
	-- el nuevo objetivo; si no, la de tus puntos; si no, la recomendada.
	if not spec then
		local actual = anterior and M.Build(anterior)
		if actual and M.Hay(e.objetivo) then
			for _, b in ipairs(M.Builds()) do
				if b.objetivo == e.objetivo and b.spec == actual.spec then spec = actual.spec break end
			end
		end
		spec = spec or M.SpecActual()
	end
	local b = M.Elegir(e.objetivo, e.estilo, spec)
	e.build = b and b.id or nil
	alCambiarBuild(b, anterior)
	return b
end

function M.UsarBuild(id)
	local b = M.Build(id)
	if not b then return end
	local e = M.Eleccion()
	local anterior = e.build
	e.build, e.objetivo, e.estilo = b.id, b.objetivo or e.objetivo, b.estilo or e.estilo
	alCambiarBuild(b, anterior)
end

---------------------------------------------------------------------------
-- Aplicar con un clic (fuera de combate, con confirmación)
---------------------------------------------------------------------------

local function aviso(titulo, texto_)
	W.Modal({ title = titulo, text = texto_, icon = "info", action = L["Entendido"], cancel = L["Cerrar"] })
end

local function rangoTxt(n, desde, hasta, max)
	if desde == 0 then return format("%s %d/%d", n, hasta, max) end
	return format("%s %d/%d \226\134\146 %d/%d", n, desde, max, hasta, max)
end

-- Las compras juntas por talento: "Golpe heroico mejorado 0 -> 3/3".
local function resumenCompras(plan, vivo)
	local orden, por = {}, {}
	for _, c in ipairs(plan.compras) do
		local g = por[c.nodo]
		if not g then
			local n = vivo.nodos[c.nodo]
			g = { nombre = c.nombre or "?", desde = n and n.activo or 0, hasta = c.rank, max = n and n.max or c.rank }
			por[c.nodo] = g
			orden[#orden + 1] = g
		end
		g.hasta = math.max(g.hasta, c.rank)
	end
	local lineas = {}
	for i, g in ipairs(orden) do
		if i > 10 then
			lineas[#lineas + 1] = format(L["... y %d talentos más"], #orden - 10)
			break
		end
		lineas[#lineas + 1] = "\226\128\162 " .. rangoTxt(g.nombre, g.desde, g.hasta, g.max)
	end
	return table.concat(lineas, "\n")
end

local function textoFallos(resumen)
	if not (resumen and resumen.fallos and #resumen.fallos > 0) then return nil end
	local vistos, out = {}, {}
	for _, f in ipairs(resumen.fallos) do
		local n = f.compra.nombre or "?"
		if not vistos[n] then
			vistos[n] = true
			out[#out + 1] = format("%s (%s)", n, T.RAZONES[f.razon] or f.razon)
		end
	end
	return format(L["No se pudo comprar: %s"], table.concat(out, "; "))
end

local function alTerminar(bien, resumen)
	T.Invalidar()
	if bien then
		N.Imprimir(format(L["Listo: aprendiste %d rangos de talento."], resumen and resumen.compradas or 0))
		local f = textoFallos(resumen)
		if f then N.Imprimir(f) end
		if A.PlaySound and SOUNDKIT then pcall(A.PlaySound, SOUNDKIT.UI_TALENT_COMMIT or SOUNDKIT.IG_QUEST_LIST_COMPLETE or 878, "SFX") end
	else
		aviso(L["No se aplicaron los talentos"], T.RAZONES.confirmar)
	end
	if M.Vista then M.Vista.Relayout() end
end

function M.PedirAplicar()
	local b = M.BuildElegido()
	if not b then return end
	if InCombatLockdown() then
		aviso(L["Ahora no se puede"], T.RAZONES.combate)
		return
	end
	T.Invalidar()
	local vivo, razon = T.Leer()
	if not vivo then
		aviso(L["Ahora no se puede"], T.RAZONES[razon] or T.RAZONES.sinconfig)
		return
	end
	local puede, r, textoJuego = T.PuedeEditar(vivo.config)
	if not puede then
		aviso(L["Ahora no se puede"], (T.RAZONES[r] or r) .. (textoJuego and textoJuego ~= "" and (": " .. textoJuego) or "."))
		return
	end
	local res = T.Resolver(b, vivo)
	local st = T.Estado(b, vivo, res)
	local plan = T.PlanCompra(b, vivo, res)
	if #plan.compras == 0 then
		local msg
		if not st.siguiente then
			msg = L["Ya tienes todos los talentos de este build. ¡Bien hecho!"]
		elseif (vivo.libres or 0) == 0 and #st.fuera > 0 then
			msg = L["Todos tus puntos ya están gastados y parte de ellos fuera de este build. Para cambiarte a este build, reinicia tus talentos con tu entrenador de clase; después Alfa te los aplica con un clic."]
		elseif (vivo.libres or 0) == 0 then
			local nivel = math.max(9 + st.siguiente.i, (UnitLevel("player") or 1) + 1)
			msg = format(L["No tienes puntos libres. El siguiente talento del plan (%s) te toca hacia el nivel %d."], T.Nombre(st.siguiente.spell) or st.siguiente.nombre or "?", nivel)
		else
			msg = L["Los talentos que siguen en el plan no están en tu árbol o no se pueden tomar todavía. Revisa la pestaña Talentos."]
		end
		aviso(L["Nada que aplicar"], msg)
		return
	end
	local partes = {}
	partes[#partes + 1] = format(L["Con tus %d puntos libres se compran %d rangos de %s:"], vivo.libres or 0, #plan.compras, b.titulo or "")
	partes[#partes + 1] = resumenCompras(plan, vivo)
	if plan.pendientes > 0 then
		partes[#partes + 1] = format(L["Los otros %d puntos del plan llegan con tus próximos niveles."], plan.pendientes)
	end
	if #res.faltan > 0 then
		partes[#partes + 1] = format(L["Se saltan (no están en tu árbol): %s."], table.concat(res.faltan, ", "))
	end
	if #st.fuera > 0 then
		partes[#partes + 1] = L["Tienes puntos fuera del plan: Alfa no los quita, solo agrega."]
	end
	if vivo.cambiosPendientes then
		partes[#partes + 1] = L["Tienes cambios sin confirmar en la ventana de talentos: se descartan antes de aplicar."]
	end
	partes[#partes + 1] = L["Los talentos confirmados no se quitan gratis: revisa la lista antes de aceptar."]
	W.Modal({
		title = L["¿Aplicar estos talentos?"], icon = "icon-learn", text = table.concat(partes, "\n\n"),
		action = L["Aplicar"], cancel = L["Cancelar"],
		onAccept = function()
			-- Se vuelve a leer: entre la vista previa y el clic pudo cambiar algo.
			if InCombatLockdown() then aviso(L["Ahora no se puede"], T.RAZONES.combate) return end
			T.Invalidar()
			local v2 = T.Leer()
			if not v2 then aviso(L["Ahora no se puede"], T.RAZONES.sinconfig) return end
			local plan2 = T.PlanCompra(b, v2, T.Resolver(b, v2))
			local ok, razon2, tj, resumen = T.Aplicar(plan2, alTerminar)
			if not ok then
				local msg = (T.RAZONES[razon2] or tostring(razon2)) .. (tj and tj ~= "" and (": " .. tj) or "")
				local f = textoFallos(resumen)
				aviso(L["No se aplicaron los talentos"], f and (msg .. "\n\n" .. f) or msg)
			end
		end,
	})
end

---------------------------------------------------------------------------
-- Recordatorio al subir de nivel
---------------------------------------------------------------------------

local function recordar()
	if not N.Get(M.ID, "aviso") then return end
	local b = M.BuildElegido()
	local vivo = T.Actual()
	if not (b and vivo) or (vivo.libres or 0) <= 0 then return end
	local st = T.Estado(b, vivo, T.Resolver(b, vivo))
	local p = st.siguiente
	if not p then return end
	local libres = vivo.libres or 1
	local cabeza = libres == 1 and L["Tienes un punto de talento."] or format(L["Tienes %d puntos de talento."], libres)
	N.Imprimir(cabeza .. " " .. format(L["Tu build %s sugiere %s (rango %d). Escribe /alfa builds para aplicarlo con un clic."],
		b.titulo or "", T.Nombre(p.spell) or p.nombre or "?", p.rank))
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

N.Modulo({
	id = M.ID, nombre = L["Builds"], icono = "icon-skill", orden = 14,
	subtitulo = L["Te ayuda a armar tu personaje aunque no sepas por dónde empezar: talentos, estadísticas, equipo y profesiones, con el porqué de cada cosa."],
	ajustes = {
		sugerencia = true, sugerenciaFuera = false, sugerenciaNombre = false, resaltado = true, tamSugerencia = 52,
		alertas = true, alertasSonido = true, alertasPorque = true,
		golpe = true, panel = false,
		aviso = true, escalaAuto = true,
	},
	construir = function(view) M.Vista.Construir(view) end,
})

A.RegisterCommand("builds", function(resto)
	local sub = type(resto) == "string" and resto:match("^%s*(%a+)") or nil
	sub = sub and sub:lower()
	if sub == "mover" then
		M.Combate.Desbloquear(not M.Combate.Desbloqueado())
	elseif sub == "aplicar" then
		N.Abrir(M.ID)
		M.PedirAplicar()
	elseif sub == "alerta" then
		M.Combate.ProbarAlerta()
	else
		N.Abrir(M.ID)
	end
end, L["Builds: talentos, estadísticas y equipo (/alfa builds mover | aplicar | alerta)"])

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

local function refrescar()
	T.Invalidar()
	if M.Vista then M.Vista.Relayout() end
end

A.RegisterEvent("TRAIT_CONFIG_UPDATED", function(ev, id) T.OnConfigActualizada(ev, id); refrescar() end)
A.RegisterEvent("CONFIG_COMMIT_FAILED", function(ev, id) T.OnConfirmacionFallida(ev, id); refrescar() end)
for _, ev in ipairs({ "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "TRAIT_CONFIG_LIST_UPDATED" }) do
	A.RegisterEvent(ev, refrescar)
end
A.RegisterEvent("PLAYER_LEVEL_UP", function()
	A.After(1.5, function()
		T.Invalidar()
		if not InCombatLockdown() then M.Pesos.Renovar() end
		recordar()
		if M.Vista then M.Vista.Relayout() end
	end)
end)
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() M.Combate.EntrarCombate() end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() M.Combate.SalirCombate() end)
A.RegisterEvent("PLAYER_SWING", function(ev, dur, tipo) M.Combate.OnGolpe(ev, dur, tipo) end)
A.RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function(ev, id) M.Combate.OnBrillo(ev, id) end)
A.RegisterEvent("SPELLS_CHANGED", function() if not InCombatLockdown() then M.Combate.PrepararReacciones() end end)
A.RegisterEvent("PLAYER_TARGET_CHANGED", function() if not InCombatLockdown() then M.Combate.Refrescar() end end)
A.RegisterEvent("ACTIONBAR_SLOT_CHANGED", function() M.Combate.OlvidarResaltado() end)
A.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() if M.Vista then M.Vista.Relayout() end end)

A.On("SETTING_CHANGED", function(path)
	if path == "" or (type(path) == "string" and path:find("^builds%.")) then M.Combate.Refrescar() end
	if type(path) == "string" and path:find("^gear%.") and M.Vista then M.Vista.Relayout() end
end)

A.OnLogin(function()
	M.Combate.Iniciar()
end)
