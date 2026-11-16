-- Alfa - Rutas: el rastreador de pasos (Toxic / La Jauría). GPL-3.0.
--
-- La ventana de guía de Alfa, hecha con el Kit, en lugar de la del motor
-- (reemplazos GUIDE_FRAME, GUIDE_END y ROUTE_CHOICE, docs/KIT.md). Compacta
-- y en este orden:
--   cabecera   la huella, la guía, "Paso 12 de 80 · 15 %", y la lista, el menú y cerrar
--   huellas    el avance de la guía
--   aviso      lo único que pide tu atención ahora (uno a la vez): terminaste la
--              guía, una misión que dejó tu registro, una de grupo sin responder,
--              una misión que aún no puedes tomar (con "Armar lo que falta"),
--              o que estás mirando otro paso
--   el paso    su título, su nota y sus metas (clic: la flecha va ahí; clic
--              derecho: marcar, omitir, Enciclopedia, a tu plan de misiones)
--   objeto     el objeto de misión del paso (se usa con el botón del motor)
--   cerca      "Mientras estás aquí": hasta 3 cosas de paso (clic: la flecha)
--   pie        Anterior · Omitir · Siguiente
-- La lista (el botón de lista) muestra todos los pasos: clic va a ese paso.
-- El motor sigue haciendo todo por dentro (pasos, flecha, automatización);
-- esta ventana solo lee y pide (Alfa.Engine, Alfa.UI).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K
local Rs = {}
M.Rastreador = Rs

local type, ipairs, pairs, tonumber, tostring = type, ipairs, pairs, tonumber, tostring
local floor, max, min, format = math.floor, math.max, math.min, string.format

local ANCHO = 344
local PAD = K.ESP.m
local CAB = 40
local PIE = 40
local MAX_CERCA = 3

local F -- la ventana
local ui = { metas = {}, cerca = {} }
local est = { lista = false, mostrar = false, fin = nil, pendiente = false }

local function E() return A.Engine end
local function U() return A.UI end

local function engine(fn, ...)
	local e = E()
	local f = e and e[fn]
	if type(f) ~= "function" then return nil end
	local ok, a, b, c = pcall(f, ...)
	if ok then return a, b, c end
	return nil
end

local function datos() return N.Datos(M.ID) end

---------------------------------------------------------------------------
-- Lugar en la pantalla
---------------------------------------------------------------------------

local function guardarLugar()
	local l, t = F:GetLeft(), F:GetTop()
	if l and t then datos().rastreador = { floor(l + 0.5), floor(t + 0.5) } end
end

local function ponerEnSuLugar()
	F:ClearAllPoints()
	local p = datos().rastreador
	if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" then
		F:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2])
	else
		F:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -72, -220)
	end
end

---------------------------------------------------------------------------
-- Acciones
---------------------------------------------------------------------------

function Rs.Ocultar()
	A.Set("ui.shown", false)
end

local function menuGuia(dueno)
	local e = E()
	local tabs, activa = engine("GetTabs")
	local op = {}
	for i, t in ipairs(tabs or {}) do
		op[#op + 1] = { valor = function() if i ~= activa then engine("SelectTab", i) end end,
			texto = (t.title or "?") .. (t.complete and ("  \194\183  " .. L["terminada"]) or ""), icono = i == activa and "ic-huella" or "ic-guia" }
	end
	op[#op + 1] = { valor = function() if M.Biblioteca then M.Biblioteca.Abrir({ pestanaNueva = true }) end end, texto = L["Abrir otra guía..."], icono = "ic-mas" }
	op[#op + 1] = { valor = function() if M.Asistente then M.Asistente.Abrir() end end, texto = L["¿Qué quieres hacer?"], icono = "ic-lobo" }
	op[#op + 1] = { valor = function() M.Cerrar.Ahora() end, texto = L["Cerrar mis misiones"], icono = "ic-misiones" }
	if activa and e then
		op[#op + 1] = { valor = function() engine("CloseTab", activa) end, texto = L["Cerrar esta pestaña"], icono = "ic-cerrar" }
	end
	op[#op + 1] = { valor = function() N.Abrir(M.ID) end, texto = L["Página Ruta"], icono = "ic-ruta" }
	K.Menu(dueno, op, nil, function(fn) if type(fn) == "function" then fn() end end, 240)
end

local function menuMeta(fila)
	local g, s = fila.alfaMeta, fila.alfaPaso
	if not (g and s) then return end
	local op = {}
	if g.tickable then
		op[#op + 1] = { valor = function() engine("ToggleGoal", s, g.index) end, texto = g.ticked and L["Desmarcar"] or L["Marcar como hecha"], icono = "ic-exito" }
	end
	if g.optional and g.status ~= "done" then
		op[#op + 1] = { valor = function() engine("SkipGoal", s, g.index) end, texto = L["Omitir esta meta"], icono = "ic-cerrar" }
	end
	if g.quest then
		local q = g.quest
		op[#op + 1] = { valor = function() engine("SkipQuest", q, true) end, texto = L["Omitir esta misión"], icono = "ic-cerrar" }
		if M.Cerrar.EnPlan(q) then
			op[#op + 1] = { valor = function() M.Cerrar.Quitar(q) end, texto = L["Quitar de mi plan de misiones"], icono = "ic-misiones" }
		else
			op[#op + 1] = { valor = function() M.Cerrar.Agregar(q) end, texto = L["Agregar a mi plan de misiones"], icono = "ic-misiones" }
		end
		if AlfaEnciclopedia and AlfaEnciclopedia.Abrir then
			op[#op + 1] = { valor = function() AlfaEnciclopedia.Abrir("quest", q) end, texto = L["Ver en la Enciclopedia"], icono = "ic-enciclopedia" }
		end
	end
	if #op == 0 then return end
	K.Menu(fila, op, nil, function(fn) if type(fn) == "function" then fn() end end, 240)
end

---------------------------------------------------------------------------
-- Piezas
---------------------------------------------------------------------------

local function filaMeta(i)
	local f = ui.metas[i]
	if f then return f end
	f = CreateFrame("Button", nil, F)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f.Marca = CreateFrame("Frame", nil, f)
	f.Marca:SetSize(12, 12)
	f.Marca.caja = K.Caja(f.Marca, { fondo = "hundido", borde = "lineaFuerte", corte = K.CORTE.casilla })
	f.Marca.Ok = K.Icono(f.Marca, "ic-exito", 12, "acento")
	f.Marca.Ok:SetPoint("CENTER")
	f.Barra = K.Plano(f, "acento", "ARTWORK", 2)
	f.Barra:SetWidth(2)
	f.Texto = K.Texto(f, "cuerpo", "texto")
	f.Texto:SetWordWrap(true)
	f.Sub = K.Texto(f, "pequeno", "textoTenue")
	f.Sub:SetWordWrap(true)
	f.Progreso = K.Progreso(f, { alto = 4 })
	f.velo = K.Velo(f, K.CORTE.control, 0.04)
	f.velo:Hide()
	f:SetScript("OnEnter", function(self)
		self.velo:Show()
		local g = self.alfaMeta
		if g and g.detail and g.detail ~= "" then K.MostrarInfo(self, U() and U().PlainGoalText and U().PlainGoalText(g) or "", g.detail) end
	end)
	f:SetScript("OnLeave", function(self) self.velo:Hide() K.OcultarInfo(self) end)
	f:SetScript("OnClick", function(self, boton)
		if boton == "RightButton" then return menuMeta(self) end
		local g, s = self.alfaMeta, self.alfaPaso
		if g and s then
			local ok, por, titulo = engine("AimGoal", s, g.index)
			if not ok and por == "accept" and titulo then
				M.Aviso(format(L["Primero toma %s"], M.Citar(titulo)), nil, { icono = "ic-flecha" })
			end
		end
	end)
	ui.metas[i] = f
	return f
end

local function filaCerca(i)
	local f = ui.cerca[i]
	if f then return f end
	f = CreateFrame("Button", nil, F)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f.Icono = K.Icono(f, "ic-flecha", 12, "acento")
	f.Icono:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)
	f.Texto = K.Texto(f, "nota", "textoSuave")
	f.Texto:SetWordWrap(true)
	f.Texto:SetPoint("TOPLEFT", f, "TOPLEFT", 18, 0)
	f:SetScript("OnClick", function(self, boton)
		if boton == "RightButton" then engine("DismissWhileHere", self.alfaI) else engine("AimWhileHere", self.alfaI) end
	end)
	K.ConInfo(f, L["Mientras estás aquí"], L["Clic: la flecha te lleva. Clic derecho: ya no mostrarla."])
	ui.cerca[i] = f
	return f
end

local function construir()
	F = CreateFrame("Frame", "AlfaRastreador", K.Raiz())
	F:SetSize(ANCHO, 200)
	F:SetFrameStrata("MEDIUM")
	F:SetClampedToScreen(true)
	F:SetMovable(true)
	F:EnableMouse(true)
	F.caja = K.Caja(F, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel })
	F.caja:Estilo({ alfaFondo = 0.94 })
	F.Marca = K.Marca(F, K.CORTE.panel, "acento", 28)

	-- Cabecera (se arrastra)
	local c = CreateFrame("Frame", nil, F)
	ui.cab = c
	c:SetPoint("TOPLEFT", F, "TOPLEFT", 0, 0)
	c:SetPoint("TOPRIGHT", F, "TOPRIGHT", 0, 0)
	c:SetHeight(CAB)
	c:EnableMouse(true)
	c:RegisterForDrag("LeftButton")
	c:SetScript("OnDragStart", function() if not (A.DragLocked and A.DragLocked()) then F:StartMoving() end end)
	c:SetScript("OnDragStop", function() F:StopMovingOrSizing() guardarLugar() end)
	c.Icono = K.Icono(c, "ic-huella", 16, "acento")
	c.Icono:SetPoint("LEFT", c, "LEFT", PAD, 0)
	c.Cerrar = K.BotonIcono(c, "ic-cerrar", function() Rs.Ocultar() end, { tam = 22, icono = 10, ayuda = L["Ocultar la guía"] })
	c.Cerrar:SetPoint("RIGHT", c, "RIGHT", -8, 0)
	c.Menu = K.BotonIcono(c, "ic-mas", function(self) menuGuia(self) end, { tam = 22, icono = 12, ayuda = L["Guías y planes"] })
	c.Menu:SetPoint("RIGHT", c.Cerrar, "LEFT", -2, 0)
	c.Lista = K.BotonIcono(c, "ic-lista", function() est.lista = not est.lista Rs.Pintar() end, { tam = 22, icono = 12, ayuda = L["Todos los pasos"] })
	c.Lista:SetPoint("RIGHT", c.Menu, "LEFT", -2, 0)
	c.Titulo = K.Texto(c, "encabezado", "texto")
	c.Titulo:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 24, -7)
	c.Titulo:SetPoint("RIGHT", c.Lista, "LEFT", -6, 0)
	c.Sub = K.Texto(c, "pequeno", "textoTenue")
	c.Sub:SetPoint("TOPLEFT", c.Titulo, "BOTTOMLEFT", 0, -2)
	c.Sub:SetPoint("RIGHT", c.Lista, "LEFT", -6, 0)
	c.Linea = K.Linea(c, "linea")
	c.Linea:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", PAD, 0)
	c.Linea:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -PAD, 0)

	ui.huellas = K.Huellas(F, { tam = 11, max = 16, gap = 4 })

	-- El aviso de arriba
	local b = CreateFrame("Frame", nil, F)
	ui.aviso = b
	b.caja = K.Caja(b, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	b.Franja = K.Plano(b, "acento", "ARTWORK", 1)
	b.Franja:SetWidth(2)
	b.Franja:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -6)
	b.Franja:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 6)
	b.Icono = K.Icono(b, "ic-aviso", 16, "aviso")
	b.Icono:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -10)
	b.Titulo = K.Texto(b, "etiqueta", "texto")
	b.Titulo:SetWordWrap(true)
	b.Texto = K.Texto(b, "pequeno", "textoSuave")
	b.Texto:SetWordWrap(true)
	b.Uno = K.Boton(b, "", nil, { tipo = "acento", tam = "chico" })
	b.Dos = K.Boton(b, "", nil, { tipo = "fantasma", tam = "chico" })

	-- El paso
	ui.paso = K.Texto(F, "subtitulo", "texto")
	ui.paso:SetWordWrap(true)
	ui.nota = K.Texto(F, "nota", "textoSuave")
	ui.nota:SetWordWrap(true)
	ui.grupos = {}

	-- El objeto de misión
	local o = CreateFrame("Frame", nil, F)
	ui.objeto = o
	o.caja = K.Caja(o, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	o.Icono = K.IconoObjeto(o, 26)
	o.Icono:SetPoint("LEFT", o, "LEFT", 8, 0)
	o.Nombre = K.Texto(o, "etiqueta", "objeto")
	o.Nombre:SetPoint("TOPLEFT", o.Icono, "TOPRIGHT", 10, -1)
	o.Nombre:SetPoint("RIGHT", o, "RIGHT", -8, 0)
	o.Ayuda = K.Texto(o, "pequeno", "textoTenue")
	o.Ayuda:SetPoint("TOPLEFT", o.Nombre, "BOTTOMLEFT", 0, -2)
	o.Ayuda:SetPoint("RIGHT", o, "RIGHT", -8, 0)
	o:SetHeight(42)

	-- Mientras estás aquí
	ui.cercaTit = K.Texto(F, "mayus", "acento")
	K.Escribir(ui.cercaTit, L["Mientras estás aquí"]:upper())

	-- Vacío (sin guía)
	ui.vacio = K.Vacio(F, { lobo = "dormido", titulo = L["No sigues ninguna guía"],
		texto = L["Elige qué quieres hacer y Alfa te lleva paso a paso."],
		accion = { texto = L["¿Qué quieres hacer?"], icono = "ic-lobo", alClic = function() if M.Asistente then M.Asistente.Abrir() end end } })

	-- La lista de pasos
	ui.lista = K.Lista(F, {
		alto = K.ALTO.filaCompacta,
		crear = function(fila)
			fila.Num = K.Texto(fila, "numero", "textoTenue")
			fila.Num:SetPoint("LEFT", fila, "LEFT", 8, 0)
			fila.Num:SetWidth(28)
			fila.Num:SetJustifyH("RIGHT")
			fila.Hecho = K.Icono(fila, "ic-exito", 12, "acento")
			fila.Hecho:SetPoint("LEFT", fila, "LEFT", 42, 0)
			fila.Texto = K.Texto(fila, "etiqueta", "texto")
			fila.Texto:SetPoint("LEFT", fila, "LEFT", 60, 0)
			fila.Texto:SetPoint("RIGHT", fila, "RIGHT", -8, 0)
		end,
		pintar = function(fila, i)
			local v = engine("GetStepView", i)
			local u = U()
			fila.Num:SetText(tostring(u and u.StepNo and u.StepNo(i) or i))
			local resumen = v and u and u.StepSummary and u.StepSummary(v) or ""
			K.Escribir(fila.Texto, resumen)
			local actual = i == engine("GetLiveStep")
			local hecho = v and (v.status == "done" or v.skipped)
			fila.Hecho:SetShown(hecho and true or false)
			K.ColorTexto(fila.Texto, actual and "acento" or (hecho and "textoTenue" or "texto"))
		end,
		alClic = function(i) engine("Goto", i) est.lista = false Rs.Pintar() end,
		elegir = false,
	})

	-- El pie
	ui.atras = K.Boton(F, L["Anterior"], function() engine("Prev") end, { tipo = "fantasma", tam = "chico" })
	ui.omitir = K.Boton(F, L["Omitir"], function()
		local e = E()
		if e and e.GetGuide and e.GetGuide() then engine("Skip") end
	end, { tipo = "fantasma", tam = "chico", ayuda = L["Omite este paso: la guía sigue con el siguiente. Puedes volver a él con Anterior."] })
	ui.siguiente = K.Boton(F, L["Siguiente"], function() engine("Next") end, { tipo = "secundario", tam = "chico" })
	ui.pieLinea = K.Linea(F, "linea")

	F:SetScript("OnShow", function() Rs.Pintar() end)
	F:Hide()
	ponerEnSuLugar()
end

---------------------------------------------------------------------------
-- El aviso de arriba: lo que pide atención, uno a la vez
---------------------------------------------------------------------------

-- Una misión del paso de ahora que el motor manda a tomar pero que todavía
-- no se puede tomar (la regla de la ruta). -> qid, texto | nil
local function aceptarBloqueado(v)
	if not (v and v.goals and M.Disp) then return nil end
	for _, g in ipairs(v.goals) do
		if g.t == "accept" and g.quest and (g.status == "active" or g.status == "pending") then
			local ok, motivo, info = M.Disp.Estado(g.quest)
			if not ok then return g.quest, M.Disp.Texto(motivo, info), M.Disp.Imposible(motivo) end
		end
	end
	return nil
end

local function aviso(v, live)
	local fin = est.fin
	if fin and fin.modelo then
		local m = fin.modelo
		local texto = m.complete and L["Terminaste esta guía."] or format(L["Llegaste al final; quedaron %d pasos sin hacer."], m.undone or 0)
		if m.carried and #m.carried > 0 then texto = texto .. " " .. format(L["Guarda %d misiones: las entregas en una guía que sigue."], #m.carried) end
		local uno = (m.choose and L["Elegir mi camino"]) or (m.next and format(L["Seguir con %s"], m.nextLabel or "")) or L["Elegir otra guía"]
		return { tono = m.complete and "exito" or "acento", icono = m.complete and "ic-exito" or "ic-huella",
			titulo = format(m.complete and L["¡Bien hecho! %s"] or L["Final de %s"], m.label or ""), texto = texto,
			uno = { uno, function() est.fin = nil if fin.Empezar then fin.Empezar() end end },
			dos = { L["Después"], function() est.fin = nil if fin.Despues then fin.Despues() end Rs.Pintar() end } }
	end
	local q, titulo = engine("LostQuestion")
	if q then
		return { tono = "aviso", icono = "ic-aviso", titulo = format(L["%s ya no está en tu registro"], M.Citar(titulo or M.TituloMision(q))),
			texto = L["¿La vuelves a tomar o la sacas de la ruta?"],
			uno = { L["La tomo otra vez"], function() engine("AnswerLost", q, "back") end },
			dos = { L["Sacarla"], function() engine("AnswerLost", q, "skip") end } }
	end
	q, titulo = engine("GroupQuestion")
	if q then
		return { tono = "mazmorra", icono = "ic-manada", titulo = format(L["%s pide grupo"], M.Citar(titulo or M.TituloMision(q))),
			texto = L["¿La haces con tu manada o la saltas?"],
			uno = { L["La haré"], function() engine("AnswerGroup", q, "do") end },
			dos = { L["Saltarla"], function() engine("AnswerGroup", q, "skip") end } }
	end
	if v and live and v.index == live then
		local bq, texto, imposible = aceptarBloqueado(v)
		if bq then
			return { tono = "aviso", icono = "ic-alerta", titulo = format(L["Aún no puedes tomar %s"], M.Citar(M.TituloMision(bq))), texto = texto,
				uno = not imposible and { L["Armar lo que falta"], function() M.Recoger.Desbloquear(bq) end } or nil,
				dos = { L["Omitirla"], function() engine("SkipQuest", bq, true) end } }
		end
	end
	if v and live and v.index ~= live then
		return { tono = "neutro", icono = "ic-info", titulo = L["Estás mirando otro paso"], texto = L["La flecha sigue en el paso de ahora."],
			uno = { L["Volver al paso de ahora"], function() engine("Goto", live) end } }
	end
	return nil
end

local function pintarAviso(d, ancho)
	local b = ui.aviso
	if not d then b:Hide() return 0 end
	local relleno = K.Tono(d.tono or "aviso")
	b.caja:Estilo({ borde = relleno, alfaBorde = 0.5 })
	K.ColorPlano(b.Franja, relleno)
	K.SetIcono(b.Icono, d.icono or "ic-aviso", relleno)
	local x = 34
	local tw = ancho - x - 10
	K.Escribir(b.Titulo, d.titulo or "")
	b.Titulo:ClearAllPoints()
	b.Titulo:SetPoint("TOPLEFT", b, "TOPLEFT", x, -9)
	local y = 9 + K.Parrafo(b.Titulo, tw, 2)
	if d.texto and d.texto ~= "" then
		K.Escribir(b.Texto, d.texto)
		b.Texto:ClearAllPoints()
		b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", x, -(y + 2))
		y = y + 2 + K.Parrafo(b.Texto, tw, 3)
		b.Texto:Show()
	else
		b.Texto:Hide()
	end
	local bx = x
	for _, k in ipairs({ "Uno", "Dos" }) do
		local bt, dd = b[k], d[k == "Uno" and "uno" or "dos"]
		if dd then
			bt:SetTexto(dd[1])
			bt.alClic = dd[2]
			bt:ClearAllPoints()
			bt:SetPoint("TOPLEFT", b, "TOPLEFT", bx, -(y + 8))
			bx = bx + bt:AnchoNatural() + K.ESP.s
			bt:Show()
		else
			bt:Hide()
		end
	end
	if d.uno or d.dos then y = y + 8 + K.ALTO.botonChico end
	local h = y + 10
	b:SetSize(ancho, h)
	b:Show()
	return h
end

---------------------------------------------------------------------------
-- Pintar
---------------------------------------------------------------------------

local function ocultarDesde(pool, i)
	for k = i, #pool do pool[k]:Hide() end
end

local function textoGrupo(i)
	local t = ui.grupos[i]
	if t then return t end
	t = K.Texto(F, "mayus", "textoTenue")
	ui.grupos[i] = t
	return t
end

local function pintarMetas(v, x, y, ancho, mapa)
	local u = U()
	local n, ng = 0, 0
	local grupos = (u and u.StepGroups and v and #v.groups > 1) and v.groups or nil
	local orden = {}
	if grupos then
		-- El nombre de un grupo (la persona o el lugar) solo cuando dice algo
		-- nuevo: no el título del paso ni el mismo de arriba.
		local anterior = v.title
		for _, grp in ipairs(grupos) do
			local cabeza = true
			for _, k in ipairs(grp.goals or {}) do
				local g = v.goals[k]
				if g and g.status ~= "na" and not g.folded and not g.header then
					local nombre = cabeza and u.GroupName and u.GroupName(v, grp) or nil
					if nombre == anterior then nombre = nil end
					if cabeza and nombre then anterior = nombre end
					orden[#orden + 1] = { g = g, grupo = nombre, nuevoGrupo = cabeza and #orden > 0 }
					cabeza = false
				end
			end
		end
	else
		for _, g in ipairs(v and v.goals or {}) do
			if g.status ~= "na" and not g.folded and not g.header then orden[#orden + 1] = { g = g } end
		end
	end
	for _, o in ipairs(orden) do
		local g = o.g
		if o.nuevoGrupo then y = y + K.ESP.xs end
		if o.grupo and o.grupo ~= "" then
			ng = ng + 1
			local t = textoGrupo(ng)
			K.Escribir(t, o.grupo:upper())
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
			t:SetWidth(ancho)
			t:Show()
			y = y + 16
		end
		n = n + 1
		local f = filaMeta(n)
		f.alfaMeta, f.alfaPaso = g, v.index
		local hecha = g.status == "done" or g.status == "skipped"
		local actual = v.current == g.index
		f.Marca.caja:Estilo({ fondo = hecha and "acento" or "hundido", alfaFondo = hecha and 0.18 or nil, borde = (hecha or actual) and "acento" or "lineaFuerte" })
		f.Marca.Ok:SetShown(hecha)
		f.Barra:SetShown(actual)
		local linea = u and u.GoalLine and u.GoalLine(g) or (g.text or "")
		local tw = ancho - 20
		K.Escribir(f.Texto, linea)
		K.ColorTexto(f.Texto, hecha and "textoTenue" or "texto")
		f.Texto:ClearAllPoints()
		f.Texto:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -2)
		local h = 2 + K.Parrafo(f.Texto, tw, 3)
		if u and u.FitCounts then pcall(u.FitCounts, f.Texto) end
		local sub = not hecha and u and u.GoalSubline and u.GoalSubline(g, mapa) or nil
		if g.unavailableText and not hecha then sub = g.unavailableText end
		if sub and sub ~= "" then
			K.Escribir(f.Sub, sub)
			f.Sub:ClearAllPoints()
			f.Sub:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -(h + 2))
			h = h + 2 + K.Parrafo(f.Sub, tw, 3)
			f.Sub:Show()
		else
			f.Sub:Hide()
		end
		local frac = u and u.GoalBar and u.GoalBar(g)
		if frac and not hecha then
			f.Progreso:ClearAllPoints()
			f.Progreso:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -(h + 4))
			f.Progreso:Acomodar(tw)
			f.Progreso:Set(frac)
			f.Progreso:Show()
			h = h + 8
		else
			f.Progreso:Hide()
		end
		h = h + 4
		f.Marca:ClearAllPoints()
		f.Marca:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -4)
		f.Barra:ClearAllPoints()
		f.Barra:SetPoint("TOPLEFT", f, "TOPLEFT", -6, -2)
		f.Barra:SetHeight(max(10, h - 6))
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		f:SetSize(ancho, h)
		f:Show()
		y = y + h + 2
	end
	ocultarDesde(ui.metas, n + 1)
	for k = ng + 1, #ui.grupos do ui.grupos[k]:Hide() end
	return y
end

local function pintarObjeto(v, x, y, ancho)
	local o = ui.objeto
	local Q = A.QoL
	local B = Q and Q.Buttons
	local item
	if B and B.ChooseQuestItem then
		local ok, r = pcall(B.ChooseQuestItem)
		if ok then item = r end
	end
	if not item then o:Hide() return y end
	o.Icono:SetObjeto(item)
	K.Escribir(o.Nombre, M.NombreObjeto(item))
	K.Escribir(o.Ayuda, L["Objeto de misión: úsalo con su botón o con tu tecla de paso."])
	o:ClearAllPoints()
	o:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
	o:SetWidth(ancho)
	o:Show()
	return y + 42 + K.ESP.s
end

local function pintarCerca(x, y, ancho)
	local lista = engine("GetWhileHereList") or {}
	local u = U()
	local n = 0
	if #lista > 0 then
		ui.cercaTit:ClearAllPoints()
		ui.cercaTit:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		ui.cercaTit:Show()
		y = y + 16
		for i = 1, min(MAX_CERCA, #lista) do
			local v = lista[i]
			n = n + 1
			local f = filaCerca(n)
			f.alfaI = i
			K.Escribir(f.Texto, u and u.HereText and u.HereText(v) or (v.hereText or v.text or ""))
			local h = K.Parrafo(f.Texto, ancho - 18, 2)
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
			f:SetSize(ancho, h)
			f:Show()
			y = y + h + 4
		end
		y = y + 4
	else
		ui.cercaTit:Hide()
	end
	ocultarDesde(ui.cerca, n + 1)
	return y
end

local function cabecera(g, v)
	local c = ui.cab
	K.Escribir(c.Titulo, g and (U() and U().GuideLabel and U().GuideLabel(g) or g.title) or L["Alfa"])
	local done, total = engine("GetProgress")
	local partes = {}
	local u = U()
	if v then
		local i = v.index
		local tot = u and u.StepTotal and u.StepTotal() or engine("GetStepCount") or 0
		partes[#partes + 1] = format(L["Paso %d de %d"], u and u.StepNo and u.StepNo(i) or i, tot)
	end
	if total and total > 0 then partes[#partes + 1] = format("%d %%", floor((done or 0) / total * 100)) end
	K.Escribir(c.Sub, table.concat(partes, "  \194\183  "))
	c.Lista:SetMarcado(est.lista)
	ui.huellas:Set(done or 0, total or 0)
	return total and total > 0
end

function Rs.Pintar()
	if not (F and F:IsShown()) then return end
	local e = E()
	local g = e and e.GetGuide and e.GetGuide()
	local i = g and engine("GetStepIndex")
	local live = g and engine("GetLiveStep")
	local v = i and engine("GetStepView", i)
	local x, ancho = PAD, ANCHO - 2 * PAD
	local conAvance = cabecera(g, v)
	local y = CAB + K.ESP.s
	if conAvance then
		ui.huellas:ClearAllPoints()
		ui.huellas:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		ui.huellas:Show()
		y = y + 20
	else
		ui.huellas:Hide()
	end
	local vacio = not (g and v)
	ui.vacio:SetShown(vacio and not est.fin)
	-- El aviso
	local h = pintarAviso(aviso(v, live), ancho)
	if h > 0 then
		ui.aviso:ClearAllPoints()
		ui.aviso:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		y = y + h + K.ESP.m
	end
	local mostrarPaso = not vacio and not est.lista
	ui.lista:SetShown(est.lista and not vacio)
	if est.lista and not vacio then
		local datosLista = {}
		local u = U()
		for k = 1, engine("GetStepCount") or 0 do
			if not (u and u.StepHidden and u.StepHidden(k)) then datosLista[#datosLista + 1] = k end
		end
		local alto = min(360, #datosLista * K.ALTO.filaCompacta)
		ui.lista:ClearAllPoints()
		ui.lista:SetPoint("TOPLEFT", F, "TOPLEFT", x - 4, -y)
		ui.lista:Acomodar(ancho + 8, max(K.ALTO.filaCompacta, alto))
		ui.lista:SetDatos(datosLista)
		for pos, k in ipairs(datosLista) do if k == live then ui.lista:IrA(pos) end end
		y = y + max(K.ALTO.filaCompacta, alto) + K.ESP.s
	end
	ui.paso:SetShown(mostrarPaso)
	ui.nota:Hide()
	if mostrarPaso then
		local u = U()
		local titulo = v.title
		if (not titulo or titulo == "") and u and u.StepSummary then titulo = u.StepSummary(v) end
		K.Escribir(ui.paso, titulo or "")
		ui.paso:ClearAllPoints()
		ui.paso:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		y = y + K.Parrafo(ui.paso, ancho, 2) + 4
		local nota = v.why or v.note
		if nota and nota ~= "" then
			K.Escribir(ui.nota, nota)
			ui.nota:ClearAllPoints()
			ui.nota:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
			y = y + K.Parrafo(ui.nota, ancho, 4) + K.ESP.s
			ui.nota:Show()
		end
		y = y + 2
		local here = A.PlayerPoint and A.PlayerPoint()
		y = pintarMetas(v, x, y, ancho, here and here.map)
		y = y + K.ESP.xs
		y = pintarObjeto(v, x, y, ancho)
		y = pintarCerca(x, y, ancho)
	else
		ocultarDesde(ui.metas, 1)
		for _, t in ipairs(ui.grupos) do t:Hide() end
		ocultarDesde(ui.cerca, 1)
		ui.cercaTit:Hide()
		ui.objeto:Hide()
	end
	if vacio and not est.fin then
		local vh = ui.vacio:Acomodar(ancho)
		ui.vacio:ClearAllPoints()
		ui.vacio:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		y = y + vh + K.ESP.base
	end
	-- El pie
	local conPie = not vacio
	for _, b in ipairs({ ui.atras, ui.omitir, ui.siguiente, ui.pieLinea }) do b:SetShown(conPie) end
	if conPie then
		y = y + K.ESP.xs
		ui.pieLinea:ClearAllPoints()
		ui.pieLinea:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		ui.pieLinea:SetPoint("TOPRIGHT", F, "TOPLEFT", x + ancho, -y)
		local by = y + floor((PIE - K.ALTO.botonChico) / 2)
		ui.atras:ClearAllPoints()
		ui.atras:SetPoint("TOPLEFT", F, "TOPLEFT", x - 4, -by)
		ui.siguiente:ClearAllPoints()
		ui.siguiente:SetPoint("TOPRIGHT", F, "TOPLEFT", x + ancho + 4, -by)
		ui.omitir:ClearAllPoints()
		ui.omitir:SetPoint("TOP", F, "TOPLEFT", x + floor(ancho / 2), -by)
		ui.atras:SetActivo(i ~= nil and i > 1)
		y = y + PIE
	else
		y = y + K.ESP.xs
	end
	F:SetHeight(y)
end

-- Muchas cosas cambian seguido (cada bicho muerto, cada paso): se pinta una
-- vez por tanda.
local function luego()
	if est.pendiente or not (F and F:IsShown()) then return end
	est.pendiente = true
	A.After(0.05, function()
		est.pendiente = false
		Rs.Pintar()
	end)
end
Rs.Luego = luego

---------------------------------------------------------------------------
-- Los reemplazos
---------------------------------------------------------------------------

-- GUIDE_FRAME: el motor dice si la ventana de guía se ve (ui.shown y sus
-- reglas de combate e instancias).
local function pedidoVentana(p)
	if not F then construir() end
	est.mostrar = p.mostrar and true or false
	if est.mostrar then
		if not F:IsShown() then ponerEnSuLugar() end
		F:Show()
		Rs.Pintar()
	else
		F:Hide()
	end
end

-- GUIDE_END: el fin de una guía va en el aviso del rastreador (y en un
-- aviso flotante si el rastreador está oculto).
local function pedidoFin(p)
	if p.accion == "ocultar" then
		est.fin = nil
		luego()
		return
	end
	est.fin = p
	if F and F:IsShown() then
		Rs.Pintar()
	else
		local m = p.modelo or {}
		K.Aviso({ lobo = "aullando", titulo = format(L["¡Bien hecho! %s"], m.label or ""), texto = L["Terminaste esta guía."],
			duracion = 12, accion = { texto = L["¿Qué sigue?"], alClic = function() A.Set("ui.shown", true) end } })
	end
end

N.Reemplazar("GUIDE_FRAME", pedidoVentana, function() return F ~= nil and F:IsShown() end)
N.Reemplazar("GUIDE_END", pedidoFin, function() return est.fin ~= nil end)

for _, msg in ipairs({ "GUIDE_CHANGED", "STEP_CHANGED", "STEP_UPDATED", "WAYPOINT_CHANGED", "WHILE_HERE_CHANGED",
	"TABS_CHANGED", "GUIDE_COMPLETED", "PINS_CHANGED", "QUEST_TIMER", "STEP_SKIPPED", "ROUTE_CHOSEN" }) do
	A.On(msg, luego)
end
A.RegisterEvent("QUEST_LOG_UPDATE", luego)
A.RegisterEvent("BAG_UPDATE_DELAYED", luego)
K.AlRepintar(function() if F and F:IsShown() then Rs.Pintar() end end)

function Rs.Visible() return F ~= nil and F:IsShown() end
function Rs.Mostrar() A.Set("ui.shown", true) end
