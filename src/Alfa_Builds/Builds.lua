-- Alfa - Builds: el módulo (Toxic / La Jauría). GPL-3.0.
--
-- La página Talentos de Alfa: qué talento poner ahora y por qué, con
-- Aplicar en un clic fuera de combate; tu objetivo y tu estilo en dos clics;
-- el árbol y el plan por nivel. También el equipo y las estadísticas de tu
-- build y compartirlo con la manada.
--
--   M.Eleccion() -> { objetivo, estilo, build }
--   M.ElegirBuild(objetivo, estilo, spec?)  ;  M.UsarBuild(id)
--   M.BuildElegido() -> build | nil
--   M.SpecActual() -> clave de rama con más puntos | nil
--   M.Estado() -> { build, vivo, foto, res, st, plan }   (lo que leen la página y los avisos)
--   M.PorQue(build, pick) -> texto, propio (true: lo dice el build; false: lo que hace según el juego)
--   M.Siguiente() -> el siguiente talento, con todo lo que hace falta para mostrarlo
--   M.PedirAplicar()   vista previa en un diálogo del Kit y, si aceptas, aplica
--
-- Contrato con otras áreas (docs/PLAN-1.0.md):
--   AlfaBuilds.SiguienteTalento() -> { nombre, icono, porque, ... } | nil
--   AlfaBuilds.Abrir(vista?)  ;  AlfaBuilds.Aplicar()
-- Al cambiar tus talentos, tu build o tus puntos se avisa ALFA_TALENTOS.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local T = M.Arbol

local format, max, floor = string.format, math.max, math.floor

local function datos() return N.DatosPersonaje(M.ID) end
local function nivel() return A.Compat.Readable(UnitLevel("player")) or 1 end

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

local function avisarCambio()
	if A.Fire then A.Fire("ALFA_TALENTOS") end
end

local function alCambiarBuild(b, anterior)
	if not b or (anterior and anterior == b.id) then return end
	if N.Get(M.ID, "escalaAuto") then
		local ok, msg = M.Pesos.Activar(b)
		if not ok then N.Imprimir(msg) end
	end
	avisarCambio()
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
-- El estado de tus talentos frente a tu build
---------------------------------------------------------------------------

function M.Estado()
	local b = M.BuildElegido()
	local vivo, razon = T.Actual()
	local foto = false
	if not vivo then
		vivo = T.VivoDeFoto()
		foto = vivo ~= nil
	end
	local res = b and vivo and T.Resolver(b, vivo) or nil
	local st = res and T.Estado(b, vivo, res) or nil
	local plan = (res and not foto) and T.PlanCompra(b, vivo, res) or nil
	return { build = b, vivo = vivo, razon = razon, foto = foto, res = res, st = st, plan = plan }
end

-- Por qué tomar un talento: lo que dice el build (los del guerrero lo traen),
-- si no, lo que hace según el juego, y si no, su lugar en el build.
local function limpiar(s)
	s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\r\n]+", " "):gsub("%s+", " ")
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	if #s > 220 then
		local corte = s:sub(1, 220):match("^(.*)[%s,;]") or s:sub(1, 220)
		s = corte .. "…"
	end
	return s
end

function T.Descripcion(spell)
	if not (spell and C_Spell and C_Spell.GetSpellDescription) then return nil end
	local ok, d = pcall(C_Spell.GetSpellDescription, spell)
	d = ok and A.Compat.Readable(d) or nil
	if type(d) ~= "string" or d == "" then return nil end
	return limpiar(d)
end

function M.PorQue(b, p)
	if not (b and p) then return nil end
	local t = b.talentos and b.talentos[p.entrada]
	local por = p.por or (t and t[4])
	if not por then
		-- Una entrada que sube un talento ya empezado: el porqué de la primera.
		for _, x in ipairs(b.talentos or {}) do
			if x[1] == p.spell and x[4] then por = x[4] break end
		end
	end
	if por then return por, true end
	local desc = T.Descripcion(p.spell)
	if desc then return format(L["Qué hace: %s"], desc), false end
	return format(L["Es el punto %d de %d de tu build."], p.i, b.total or p.i), false
end

-- El siguiente talento del plan, listo para mostrarlo.
-- -> { pick, nombre, icono, porque, rango, max, spell, nivel, libres, ahora,
--      compras, build } | nil (sin build, árbol sin cargar o plan completo)
function M.Siguiente(e)
	e = e or M.Estado()
	local b, st = e.build, e.st
	if e.foto or not (b and st and st.siguiente) then return nil end
	local p = st.siguiente
	local id = e.res.nodo[p.spell]
	local n = id and e.vivo.nodos[id]
	local libres = e.vivo.libres or 0
	local compras = e.plan and #e.plan.compras or 0
	local nv = nivel()
	return {
		pick = p, spell = p.spell, rango = p.rank, max = n and n.max or p.rank,
		nombre = (n and n.nombre) or T.Nombre(p.spell) or p.nombre or "?",
		icono = (n and n.icono) or T.Icono(p.spell),
		porque = M.PorQue(b, p),
		libres = libres, compras = compras, ahora = libres > 0 and compras > 0,
		nivel = libres > 0 and nv or max(10, nv + 1),
		build = b.titulo,
	}
end

---------------------------------------------------------------------------
-- Aplicar con un clic (fuera de combate, con confirmación)
---------------------------------------------------------------------------

local function aviso(titulo, texto_)
	K.Dialogo({ titulo = titulo, texto = texto_, icono = "ic-info", aceptar = L["Entendido"], cancelar = false })
end

local function rangoTxt(n, desde, hasta, max_)
	if desde == 0 then return format("%s %d/%d", n, hasta, max_) end
	return format("%s %d/%d \226\134\146 %d/%d", n, desde, max_, hasta, max_)
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
		g.hasta = max(g.hasta, c.rank)
	end
	local lineas = {}
	for i, g in ipairs(orden) do
		if i > 8 then
			lineas[#lineas + 1] = format(L["... y %d talentos más"], #orden - 8)
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

local function refrescar()
	T.Invalidar()
	if M.Pagina then M.Pagina.Rehacer() end
	avisarCambio()
end
M.Refrescar = refrescar

local function alTerminar(bien, resumen)
	T.Invalidar()
	if bien then
		local n = resumen and resumen.compradas or 0
		K.Aviso({ lobo = "aullando", tono = "exito", duracion = 6,
			titulo = n == 1 and L["Listo: aprendiste 1 rango de talento"] or format(L["Listo: aprendiste %d rangos de talento"], n),
			texto = textoFallos(resumen) })
		if A.PlaySound and SOUNDKIT then pcall(A.PlaySound, SOUNDKIT.UI_TALENT_COMMIT or SOUNDKIT.IG_QUEST_LIST_COMPLETE or 878, "SFX") end
	else
		aviso(L["No se aplicaron los talentos"], T.RAZONES.confirmar)
	end
	refrescar()
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
			msg = format(L["No tienes puntos libres. El siguiente talento del plan (%s) te toca en el nivel %d."], T.Nombre(st.siguiente.spell) or st.siguiente.nombre or "?", max(10, nivel() + 1))
		else
			msg = L["Los talentos que siguen en el plan no están en tu árbol o no se pueden tomar todavía. Ponlos a mano en la ventana de talentos del juego o elige otro build."]
		end
		aviso(L["Nada que aplicar"], msg)
		return
	end
	local partes = {}
	partes[#partes + 1] = #plan.compras == 1 and format(L["Con tu punto libre se compra 1 rango de %s:"], b.titulo or "")
		or format(L["Con tus %d puntos libres se compran %d rangos de %s:"], vivo.libres or 0, #plan.compras, b.titulo or "")
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
	K.Dialogo({
		titulo = L["¿Aplicar estos talentos?"], icono = "ic-talentos", texto = table.concat(partes, "\n\n"),
		aceptar = L["Aplicar"], cancelar = L["Cancelar"], ancho = 460,
		alAceptar = function()
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
-- El aviso del talento que toca (al subir de nivel y, una vez, al entrar)
---------------------------------------------------------------------------

-- El ícono del juego en un aviso del Kit (que tiñe los suyos).
function M.IconoEnAviso(a, tex)
	if not (a and a.Icono and tex) then return end
	a.Icono:SetTexture(tex)
	a.Icono:SetVertexColor(1, 1, 1, 1)
end

local avisadoAlEntrar = false

local function avisarTalento(alEntrar)
	if not N.Get(M.ID, "aviso") then return end
	local s = M.Siguiente()
	if not (s and s.ahora) then return end
	local titulo
	if s.libres == 1 then
		titulo = format(L["Tienes un punto de talento: %s"], s.nombre)
	else
		titulo = format(L["Tienes %d puntos de talento: empieza por %s"], s.libres, s.nombre)
	end
	local a = K.Aviso({
		titulo = titulo, texto = s.porque, icono = "ic-talentos", tono = "acento", duracion = alEntrar and 10 or 14,
		accion = { texto = s.compras > 1 and format(L["Aplicar %d puntos"], s.compras) or L["Aplicar"], alClic = function() M.PedirAplicar() end },
	})
	M.IconoEnAviso(a, s.icono)
end
M.AvisarTalento = avisarTalento

---------------------------------------------------------------------------
-- La página y el contrato
---------------------------------------------------------------------------

N.Modulo({
	id = M.ID, nombre = L["Talentos"], icono = "ic-talentos", orden = 14,
	subtitulo = L["Qué talento poner ahora y por qué, tu build en dos clics, tu árbol y tu equipo."],
	ajustes = { aviso = true, escalaAuto = true },
	construir = function(view) M.Pagina.Construir(view) end,
})

AlfaBuilds = AlfaBuilds or {}
-- -> { nombre, icono, porque, rango, max, spell, nivel, libres, ahora, build } | nil
function AlfaBuilds.SiguienteTalento()
	local ok, s = pcall(M.Siguiente)
	if not (ok and s) then return nil end
	return { nombre = s.nombre, icono = s.icono, porque = s.porque, rango = s.rango, max = s.max, spell = s.spell,
		nivel = s.nivel, libres = s.libres, ahora = s.ahora, build = s.build }
end
-- vista: nil (Talentos), "equipo", "compartir"
function AlfaBuilds.Abrir(vista) M.Pagina.Ir(vista or "talentos") N.Abrir(M.ID) end
function AlfaBuilds.Aplicar() M.PedirAplicar() end

A.RegisterCommand("builds", function(resto)
	local sub = type(resto) == "string" and resto:match("^%s*(%a+)") or nil
	sub = sub and sub:lower()
	if sub == "mover" and AlfaCombate and AlfaCombate.Mover then
		-- Las ayudas de combate son del área de combate: se le pasa.
		AlfaCombate.Mover()
	elseif sub == "aplicar" then
		N.Abrir(M.ID)
		M.PedirAplicar()
	elseif sub == "equipo" or sub == "compartir" then
		AlfaBuilds.Abrir(sub)
	else
		AlfaBuilds.Abrir()
	end
end, L["Talentos: qué poner ahora y tu build (/alfa builds aplicar | equipo | compartir)"])
A.RegisterCommand("talentos", function() AlfaBuilds.Abrir() end, L["abre Talentos"])

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

A.RegisterEvent("TRAIT_CONFIG_UPDATED", function(ev, id) T.OnConfigActualizada(ev, id); refrescar() end)
A.RegisterEvent("CONFIG_COMMIT_FAILED", function(ev, id) T.OnConfirmacionFallida(ev, id); refrescar() end)
for _, ev in ipairs({ "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "TRAIT_CONFIG_LIST_UPDATED" }) do
	A.RegisterEvent(ev, refrescar)
end
A.RegisterEvent("PLAYER_LEVEL_UP", function()
	A.After(1.5, function()
		T.Invalidar()
		if not InCombatLockdown() then M.Pesos.Renovar() end
		avisarTalento(false)
		refrescar()
	end)
end)
-- Una vez por sesión, al entrar con puntos sin gastar.
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if avisadoAlEntrar then return end
	avisadoAlEntrar = true
	A.After(8, function() T.Invalidar() avisarTalento(true) end)
end)
-- Aplicar se puede o no según el combate: la página lo dice.
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() if M.Pagina then M.Pagina.Rehacer() end end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() if M.Pagina then M.Pagina.Rehacer() end end)
A.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() if M.Pagina then M.Pagina.Rehacer() end end)
-- Las descripciones de los talentos llegan después la primera vez.
A.RegisterEvent("SPELL_TEXT_UPDATE", function() if M.Pagina then M.Pagina.Rehacer() end end)

A.On("SETTING_CHANGED", function(path)
	if type(path) == "string" and path:find("^gear%.") and M.Pagina then M.Pagina.Rehacer() end
end)

A.OnLogin(function()
	-- Alfa avisa el talento que toca con su propio aviso: el recordatorio del
	-- motor en el chat decía lo mismo otra vez (a veces de otro plan). Se apaga
	-- una sola vez; quien lo quiera lo vuelve a encender en Ajustes.
	local d = N.Datos(M.ID)
	if not d.recordatorioMotor then
		d.recordatorioMotor = true
		if A.Get("talents.reminder") then A.Set("talents.reminder", false) end
	end
end)
