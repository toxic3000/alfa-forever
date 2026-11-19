-- Alfa - Rutas: el rastreador de pasos (toxic3000 / La Jauría). GPL-3.0.
--
-- La ventana de guía de Alfa, hecha con el Kit, en lugar de la del motor
-- (reemplazos GUIDE_FRAME, GUIDE_END y ROUTE_CHOICE, docs/KIT.md).
--
-- Compacta de fábrica: solo lo que está en curso, para no estorbar al jugar.
--   cabecera   la huella, la guía, "Paso 12 de 80 · 15 %", y buscar cerca (Cerca.lua,
--              si rutas.cercaBoton), el menú y cerrar
--   mi plan    la meta de ahora de tu plan (Planes.lua), con Llévame y Hecha
--   aviso      lo único que pide tu atención ahora (uno a la vez): terminaste la
--              guía, una misión que dejó tu registro, una de grupo sin responder,
--              una misión que aún no puedes tomar (con "Armar lo que falta"),
--              o que estás mirando otro paso
--   el paso    su título; la meta de ahora y hasta dos más, una línea cada una
--              (clic: la flecha va ahí; clic derecho: marcar, omitir,
--              Enciclopedia, a tu plan de misiones) y "y N más"
--   flecha     la distancia y el rumbo hasta la flecha (se repinta cada segundo
--              mientras se ve)
--   cerca      una línea de "Mientras estás aquí"
--   pie        Ver detalle · Omitir · Siguiente
-- Con "Mostrar más en el seguimiento" (rutas.seguimientoCompleto) vuelve la
-- vista amplia: las huellas, la nota del paso, todas sus metas con sus
-- grupos y notas, el objeto de misión y hasta tres de "Mientras estás aquí".
-- El ajuste del motor ui.compact deja siempre la compacta; ui.showNotes
-- apaga la nota del paso en la amplia.
--
-- "Ver detalle" (y el menú) abre otra ventana (AlfaRastreadorDetalle, una
-- K.Ventana que recuerda su lugar y se cierra sola con Esc): el paso entero
-- con su nota, sus metas y sus notas, el objeto, lo que hay cerca y tu plan;
-- y "Todos los pasos" de la guía (clic: mirar ese paso). Una nota de la guía
-- que sigue en inglés en un cliente en español no se muestra (no se mezclan
-- idiomas): Rs.SinTraducir.
-- El motor sigue haciendo todo por dentro (pasos, flecha, automatización);
-- estas ventanas solo leen y piden (Alfa.Engine, Alfa.UI).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K
local Rs = {}
M.Rastreador = Rs


-- rutas.seguimientoCompleto: la vista amplia del rastreador (de fábrica, la compacta).
A.RegisterDefaults(M.ID, { seguimientoCompleto = false })

local type, ipairs, pairs, tonumber, tostring = type, ipairs, pairs, tonumber, tostring
local floor, max, min, format = math.floor, math.max, math.min, string.format

local ANCHO = 344
local PAD = K.ESP.m
local CAB = 40
local PIE = 40
local MAX_CERCA = 3
local MAX_COMPACTO = 3 -- la meta de ahora y hasta dos más
local MAX_CERCA_DETALLE = 6

local F -- la ventana
local ui = {}
local cxR -- las piezas de las metas del rastreador
local est = { mostrar = false, fin = nil, pendiente = false }

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

-- La vista compacta (de fábrica) o la amplia.
local function compacto()
	return A.Get(M.ID .. ".seguimientoCompleto") ~= true or A.Get("ui.compact") == true
end
Rs.Compacto = compacto

---------------------------------------------------------------------------
-- Notas de la guía sin traducir
---------------------------------------------------------------------------
-- Las guías traen sus notas en inglés y el paquete de idioma las traduce;
-- la que no tiene traducción llega en inglés. En un cliente en español (o con
-- Alfa en español) esa nota no se muestra: mejor nada que mezclar idiomas.
-- Se reconoce por sus palabras: al menos dos palabras comunes del inglés y
-- más que del español (los nombres del juego ya vienen traducidos).

local INGLES, ESPANOL = {}, {}
for w in ("the by on of and to at from with takes take it its is are inside near top floor north south east west "
	.. "behind upstairs downstairs you your here there next into past up down along around across over under for "
	.. "this that keep then after before first follow road path gate docks tower bridge cave entrance left right "
	.. "kill loot talk accept turn hand in out back across between which who where when while if can will"):gmatch("%a+") do
	INGLES[w] = true
end
for w in ("el la los las de del en y con por para que al una un unos unas junto se su sus tu hacia piso arriba abajo "
	.. "cerca lado entre sobre bajo desde hasta norte sur este oeste dentro fuera puerta camino torre puente cueva"):gmatch("%a+") do
	ESPANOL[w] = true
end
-- "de", "en", "a"... no cuentan para el inglés aunque se escriban igual.
INGLES["in"] = nil

local espanol
local function enEspanol()
	if espanol == nil then
		local f = rawget(_G, "AlfaIdioma")
		local ok, loc = false, nil
		if type(f) == "function" then ok, loc = pcall(f) end
		if not (ok and type(loc) == "string") then loc = GetLocale and GetLocale() or "" end
		espanol = (loc == "esMX" or loc == "esES")
	end
	return espanol
end

-- -> true si el texto parece una nota en inglés que no se tradujo.
function Rs.SinTraducir(s)
	if type(s) ~= "string" or s == "" or not enEspanol() then return false end
	local limpio = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")
	local en, es, primera, posesivo = 0, 0, nil, false
	for w in limpio:lower():gmatch("[%a']+") do
		if primera == nil then primera = w end
		if INGLES[w] then en = en + 1 elseif ESPANOL[w] then es = es + 1 end
		-- "X's hunt targets": el posesivo del inglés (el español no lo usa).
		if w:find("%a's$") then posesivo = true end
	end
	if es > 0 then return en >= 2 and en > es end
	-- Sin ninguna palabra del español: dos del inglés, su posesivo o que
	-- empiece con una del inglés ("Into Vallefresno", "The road north").
	return en >= 2 or posesivo or (primera ~= nil and INGLES[primera] == true)
end

-- Una meta de nota que quedó en inglés: no se muestra.
local function notaEnIngles(g)
	return g ~= nil and g.t == "note" and Rs.SinTraducir(g.text)
end

-- La nota de una meta, sin la que quedó en inglés (para GoalSubline del motor).
local sinNota = setmetatable({}, { __mode = "k" })
local function metaSinNota(g)
	if not (g.note and Rs.SinTraducir(g.note)) then return g end
	local p = sinNota[g]
	if not p then
		p = setmetatable({ note = false }, { __index = g })
		sinNota[g] = p
	end
	return p
end

local function sublinea(g, mapa)
	local u = U()
	if not (u and u.GoalSubline) then return nil end
	local ok, s = pcall(u.GoalSubline, metaSinNota(g), mapa)
	if ok and type(s) == "string" and s ~= "" then return s end
	return nil
end

-- La nota de un paso, si dice algo y está en tu idioma.
local function notaPaso(v)
	local nota = v and (v.why or v.note)
	if type(nota) ~= "string" or nota == "" or Rs.SinTraducir(nota) then return nil end
	return nota
end

-- El título de un paso en tu idioma. Uno del motor que quedó en inglés
-- ("Into Vallefresno", "X's hunt targets") o sin título: lo que pide su meta
-- de ahora (o la primera), como la escribe el motor en tu idioma; sin nada
-- en tu idioma, vacío (no se mezclan idiomas).
local function tituloPaso(v)
	local titulo = v and v.title
	if type(titulo) == "string" and titulo ~= "" and not Rs.SinTraducir(titulo) then return titulo end
	local u = U()
	local plano = u and u.PlainGoalText
	if type(plano) ~= "function" then return "" end
	local meta
	for _, g in ipairs(v and v.goals or {}) do
		if g.status ~= "na" and g.t ~= "note" and not g.header then
			if g.index == v.current then meta = g break end
			meta = meta or g
		end
	end
	if not meta then return "" end
	local ok, s = pcall(plano, meta)
	if ok and type(s) == "string" and s ~= "" and not Rs.SinTraducir(s) then return s end
	return ""
end

-- El número de un paso como lo cuenta la guía (los pasos ocultos no cuentan).
local function numeroPaso(i)
	local u = U()
	return u and u.StepNo and u.StepNo(i) or i
end

---------------------------------------------------------------------------
-- Entregas de misiones que aún no terminas
---------------------------------------------------------------------------
-- La meta de entregar no mira si la misión está lista: el motor la deja abierta
-- y la flecha va al PNJ. Una misión en tu registro con objetivos (los que lista
-- el juego), ni lista ni fallida, no se entrega todavía.

-- Una meta de entregar (de la vista del motor) cuya misión aún no terminas.
local function sinTerminar(g)
	if not (g and g.t == "turnin" and g.quest and (g.status == "active" or g.status == "pending")) then return false end
	local Cp = A.Compat
	if not (Cp and Cp.IsOnQuest and Cp.IsQuestReadyForTurnIn and Cp.GetQuestObjectives) then return false end
	local q = g.quest
	if not Cp.IsOnQuest(q) or Cp.IsQuestReadyForTurnIn(q) then return false end
	if Cp.IsQuestFailed and Cp.IsQuestFailed(q) then return false end
	-- Sin objetivos en el registro (llevar una carta, hablar con alguien) no hay qué terminar.
	return Cp.GetQuestObjectives(q) ~= nil
end
Rs.SinTerminar = sinTerminar

-- Lo que le falta a la misión q, en palabras del juego: "Asta de hierro (0/1)".
local function faltaDe(q)
	local Cp = A.Compat
	local objs = Cp and Cp.GetQuestObjectives and Cp.GetQuestObjectives(q)
	local partes, resto = {}, 0
	for _, o in ipairs(objs or {}) do
		if not o.finished then
			local nombre = Cp.ObjectiveLabel and Cp.ObjectiveLabel(o.text) or ""
			if nombre ~= "" then
				if #partes < 2 then
					partes[#partes + 1] = format("%s (%d/%d)", nombre, tonumber(o.numFulfilled) or 0, tonumber(o.numRequired) or 1)
				else
					resto = resto + 1
				end
			end
		end
	end
	if #partes == 0 then return nil end
	local s = table.concat(partes, ", ")
	if resto > 0 then s = s .. " " .. format(L["y %d más"], resto) end
	return s
end

-- La entrega sin terminar que el paso v te pide ahora (su meta de ahora). -> meta, lo que falta
local function entregaSinTerminar(v)
	if not (v and v.goals and v.current) then return nil end
	for _, g in ipairs(v.goals) do
		if g.index == v.current and sinTerminar(g) then return g, faltaDe(g.quest) end
	end
	return nil
end

local OBRA = { kill = true, collect = true, interact = true, use = true, talk = true, complete = true }

-- El primer paso de la guía (que no sea `menos`) con trabajo abierto de la misión q. -> índice | nil
local function pasoDeLaObra(q, menos)
	local e = E()
	local g = e and e.GetGuide and e.GetGuide()
	if not (g and type(g.steps) == "table") then return nil end
	for k, paso in ipairs(g.steps) do
		if k ~= menos then
			for gi, meta in ipairs(paso.goals or {}) do
				if meta.quest == q and OBRA[meta.t] and engine("Applies", k, gi) and not engine("GoalDone", k, gi) then return k end
			end
		end
	end
	return nil
end

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
	if e and e.GetGuide and e.GetGuide() then
		op[#op + 1] = { valor = function() Rs.AbrirDetalle() end, texto = L["Ver detalle"], icono = "ic-lista" }
		op[#op + 1] = { valor = function() A.Set(M.ID .. ".seguimientoCompleto", compacto()) end,
			texto = compacto() and L["Mostrar más en el seguimiento"] or L["Mostrar menos en el seguimiento"], icono = "ic-ventana" }
		op[#op + 1] = { separador = true }
	end
	for i, t in ipairs(tabs or {}) do
		op[#op + 1] = { valor = function() if i ~= activa then engine("SelectTab", i) end end,
			texto = (t.title or "?") .. (t.complete and ("  \194\183  " .. L["terminada"]) or ""), icono = i == activa and "ic-huella" or "ic-guia" }
	end
	op[#op + 1] = { valor = function() if M.Biblioteca then M.Biblioteca.Abrir({ pestanaNueva = true }) end end, texto = L["Abrir otra guía..."], icono = "ic-mas" }
	op[#op + 1] = { valor = function() if M.Asistente then M.Asistente.Abrir() end end, texto = L["¿Qué quieres hacer?"], icono = "ic-lobo" }
	op[#op + 1] = { valor = function() M.Cerrar.Ahora() end, texto = L["Cerrar mis misiones"], icono = "ic-misiones" }
	-- Buscar cerca: en el menú solo si su lupa no está en la cabecera.
	if M.Cerca and A.Get(M.ID .. ".cercaBoton") == false then
		op[#op + 1] = { valor = function() M.Cerca.Menu(dueno) end, texto = L["Buscar cerca..."], icono = "ic-cerca" }
	end
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
			op[#op + 1] = { valor = function() M.Cerrar.Quitar(q) end, texto = L["Quitar de Cerrar mis misiones"], icono = "ic-misiones" }
		else
			op[#op + 1] = { valor = function() M.Cerrar.Agregar(q) end, texto = L["Agregar a Cerrar mis misiones"], icono = "ic-misiones" }
		end
		if AlfaEnciclopedia and AlfaEnciclopedia.Abrir then
			op[#op + 1] = { valor = function() AlfaEnciclopedia.Abrir("quest", q) end, texto = L["Ver en la Enciclopedia"], icono = "ic-enciclopedia" }
		end
	end
	if #op == 0 then return end
	K.Menu(fila, op, nil, function(fn) if type(fn) == "function" then fn() end end, 240)
end

---------------------------------------------------------------------------
-- Piezas que comparten el rastreador y la ventana de detalle: cada una vive
-- en su contexto (cx = { padre, metas, grupos, cerca }) y se reutiliza.
---------------------------------------------------------------------------

local function nuevoCx(padre) return { padre = padre, metas = {}, grupos = {}, cerca = {} } end

local function filaMeta(cx, i)
	local f = cx.metas[i]
	if f then return f end
	f = CreateFrame("Button", nil, cx.padre)
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
		if g and g.detail and g.detail ~= "" and not Rs.SinTraducir(g.detail) then
			K.MostrarInfo(self, U() and U().PlainGoalText and U().PlainGoalText(g) or "", g.detail)
		end
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
	cx.metas[i] = f
	return f
end

local function filaCerca(cx, i)
	local f = cx.cerca[i]
	if f then return f end
	f = CreateFrame("Button", nil, cx.padre)
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
	cx.cerca[i] = f
	return f
end

local function textoGrupo(cx, i)
	local t = cx.grupos[i]
	if t then return t end
	t = K.Texto(cx.padre, "mayus", "textoTenue")
	cx.grupos[i] = t
	return t
end

local function ocultarDesde(pool, i)
	for k = i, #pool do pool[k]:Hide() end
end

-- Una fila de meta. lineas: el tope de líneas del texto; conSub: con su
-- línea de abajo (lugar, notas); conBarra: con su barra de avance.
local function pintarFila(cx, n, v, g, x, y, ancho, mapa, lineas, conSub, conBarra)
	local u = U()
	local f = filaMeta(cx, n)
	f.alfaMeta, f.alfaPaso = g, v.index
	local hecha = g.status == "done" or g.status == "skipped"
	-- cx.previa: el paso que miras no es el de ahora; sus metas van atenuadas
	-- y ninguna lleva la raya de "ahora".
	local actual = v.current == g.index and not cx.previa
	local fuera = type(g.noDisponible) == "string" and g.noDisponible ~= ""
	f.Marca.caja:Estilo({ fondo = hecha and "acento" or "hundido", alfaFondo = hecha and 0.18 or nil, borde = (hecha or actual) and "acento" or "lineaFuerte" })
	f.Marca.Ok:SetShown(hecha)
	f.Barra:SetShown(actual)
	local linea = u and u.GoalLine and u.GoalLine(g) or (g.text or "")
	local tw = ancho - 20
	K.Escribir(f.Texto, linea)
	K.ColorTexto(f.Texto, (hecha or fuera or cx.previa or sinTerminar(g)) and "textoTenue" or "texto")
	f.Texto:ClearAllPoints()
	f.Texto:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -2)
	local h = 2 + K.Parrafo(f.Texto, tw, lineas)
	if u and u.FitCounts then pcall(u.FitCounts, f.Texto) end
	local sub
	if conSub and (not hecha or fuera) then
		sub = sublinea(g, mapa)
		if g.unavailableText then sub = g.unavailableText end
		-- Lo que la ruta agregó antes de esta meta, o por qué no se puede.
		if type(g.antes) == "string" and g.antes ~= "" then
			sub = format(L["Antes: %s"], g.antes) .. (sub and ("\n" .. sub) or "")
		end
		if fuera then sub = format(L["No disponible: %s"], g.noDisponible) end
		-- Una entrega de una misión que aún no terminas: qué le falta.
		if not fuera and sinTerminar(g) then
			local falta = faltaDe(g.quest)
			sub = falta and format(L["Aún no está terminada: te falta %s."], falta) or L["Aún no está terminada: termínala antes de entregarla."]
		end
	end
	if sub and sub ~= "" then
		K.Escribir(f.Sub, sub)
		f.Sub:ClearAllPoints()
		f.Sub:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -(h + 2))
		h = h + 2 + K.Parrafo(f.Sub, tw, 3)
		f.Sub:Show()
	else
		f.Sub:Hide()
	end
	local frac = conBarra and not fuera and u and u.GoalBar and u.GoalBar(g)
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
	f:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", x, -y)
	f:SetSize(ancho, h)
	f:Show()
	return y + h + 2
end

-- Todas las metas del paso, con sus grupos (la persona o el lugar) y notas.
local function pintarMetas(cx, v, x, y, ancho, mapa)
	local u = U()
	local n, ng = 0, 0
	local grupos = (u and u.StepGroups and v and #v.groups > 1) and v.groups or nil
	local orden = {}
	if grupos then
		-- El nombre de un grupo solo cuando dice algo nuevo: no el título del
		-- paso ni el mismo de arriba.
		local anterior = v.title
		for _, grp in ipairs(grupos) do
			local cabeza = true
			for _, k in ipairs(grp.goals or {}) do
				local g = v.goals[k]
				if g and g.status ~= "na" and not g.folded and not g.header and not notaEnIngles(g) then
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
			if g.status ~= "na" and not g.folded and not g.header and not notaEnIngles(g) then orden[#orden + 1] = { g = g } end
		end
	end
	for _, o in ipairs(orden) do
		if o.nuevoGrupo then y = y + K.ESP.xs end
		if o.grupo and o.grupo ~= "" then
			ng = ng + 1
			local t = textoGrupo(cx, ng)
			K.Escribir(t, K.Mayus(o.grupo))
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", x, -y)
			t:SetWidth(ancho)
			t:Show()
			y = y + 16
		end
		n = n + 1
		y = pintarFila(cx, n, v, o.g, x, y, ancho, mapa, 3, true, true)
	end
	ocultarDesde(cx.metas, n + 1)
	for k = ng + 1, #cx.grupos do cx.grupos[k]:Hide() end
	return y
end

-- Las metas que siguen abiertas, la de ahora primero.
local function metasAbiertas(v)
	local out = {}
	for _, g in ipairs(v and v.goals or {}) do
		if g.status ~= "na" and g.status ~= "done" and g.status ~= "skipped" and not g.folded and not g.header
			and not (type(g.noDisponible) == "string" and g.noDisponible ~= "") and not notaEnIngles(g) then
			out[#out + 1] = g
		end
	end
	for k, g in ipairs(out) do
		if g.index == v.current then
			if k > 1 then table.remove(out, k) table.insert(out, 1, g) end
			break
		end
	end
	return out
end

-- Compacta: la meta de ahora y hasta dos más, una línea cada una, sin grupos
-- ni notas; las que no se pueden hacer (noDisponible) no salen.
-- -> y, cuántas quedaron fuera, lo que la ruta agregó antes de la de ahora
local function pintarMetasCompacto(cx, v, x, y, ancho)
	local abiertas = metasAbiertas(v)
	local antes = abiertas[1] and type(abiertas[1].antes) == "string" and abiertas[1].antes ~= "" and abiertas[1].antes or nil
	local n = 0
	for k = 1, min(MAX_COMPACTO, #abiertas) do
		n = n + 1
		-- Hasta dos renglones: "Consigue la ruta de vuelo en Puesto del…" no se corta.
		y = pintarFila(cx, n, v, abiertas[k], x, y, ancho, nil, 2, false, k == 1)
	end
	ocultarDesde(cx.metas, n + 1)
	for k = 1, #cx.grupos do cx.grupos[k]:Hide() end
	return y, max(0, #abiertas - n), antes
end

local function pintarObjeto(cx, x, y, ancho)
	local o = cx.objeto
	local Q = A.QoL
	local B = Q and Q.Buttons
	local item
	if B and B.ChooseQuestItem then
		local ok, r = pcall(B.ChooseQuestItem)
		if ok then item = r end
	end
	if not item then
		if o then o:Hide() end
		return y
	end
	if not o then
		o = CreateFrame("Frame", nil, cx.padre)
		cx.objeto = o
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
	end
	o.Icono:SetObjeto(item)
	K.Escribir(o.Nombre, M.NombreObjeto(item))
	K.Escribir(o.Ayuda, L["Objeto de misión: úsalo con su botón o con tu tecla de paso."])
	o:ClearAllPoints()
	o:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", x, -y)
	o:SetWidth(ancho)
	o:Show()
	return y + 42 + K.ESP.s
end

-- "Mientras estás aquí": hasta `tope` cosas. conTitulo: con su encabezado;
-- sin él, una sola línea con el nombre delante.
local function pintarCerca(cx, x, y, ancho, tope, conTitulo)
	local lista = engine("GetWhileHereList") or {}
	local u = U()
	local n = 0
	if not cx.cercaTit then
		cx.cercaTit = K.Texto(cx.padre, "mayus", "acento")
		K.Escribir(cx.cercaTit, K.Mayus(L["Mientras estás aquí"]))
	end
	if #lista > 0 and tope > 0 then
		if conTitulo then
			cx.cercaTit:ClearAllPoints()
			cx.cercaTit:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", x, -y)
			cx.cercaTit:Show()
			y = y + 16
		else
			cx.cercaTit:Hide()
		end
		for i = 1, min(tope, #lista) do
			local v = lista[i]
			n = n + 1
			local f = filaCerca(cx, n)
			f.alfaI = i
			local texto = u and u.HereText and u.HereText(v) or (v.hereText or v.text or "")
			if not conTitulo then texto = format(L["Mientras estás aquí: %s"], texto) end
			K.Escribir(f.Texto, texto)
			local h = K.Parrafo(f.Texto, ancho - 18, conTitulo and 2 or 1)
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", x, -y)
			f:SetSize(ancho, h)
			f:Show()
			y = y + h + 4
		end
		y = y + 4
	else
		cx.cercaTit:Hide()
	end
	ocultarDesde(cx.cerca, n + 1)
	return y
end

local function ocultarPaso(cx)
	ocultarDesde(cx.metas, 1)
	for _, t in ipairs(cx.grupos) do t:Hide() end
	ocultarDesde(cx.cerca, 1)
	if cx.cercaTit then cx.cercaTit:Hide() end
	if cx.objeto then cx.objeto:Hide() end
end

---------------------------------------------------------------------------
-- La flecha: distancia y rumbo, en una línea
---------------------------------------------------------------------------

local RUMBOS = { L["al norte"], L["al noroeste"], L["al oeste"], L["al suroeste"],
	L["al sur"], L["al sureste"], L["al este"], L["al noreste"] }

local function rumbo(dn, dw)
	local grados = math.atan2(dw, dn) * 180 / math.pi -- 0 norte, 90 oeste
	return RUMBOS[floor(((grados + 22.5) % 360) / 45) + 1]
end

-- -> el texto de la línea de la flecha, o nil sin flecha.
local function textoFlecha()
	local Nav = A.Nav
	if type(Nav) ~= "table" or type(Nav.GetTarget) ~= "function" then return nil end
	local ok, t = pcall(Nav.GetTarget)
	if not ok or type(t) ~= "table" then return nil end
	local Cp = A.Compat
	if type(Cp) == "table" then
		if type(Cp.IsInInstance) == "function" and Cp.IsInInstance() then return L["En una instancia: la flecha vuelve al salir"] end
		if type(Cp.IsOnTaxi) == "function" and Cp.IsOnTaxi() then return L["En vuelo: la flecha sigue al bajar"] end
	end
	local dn, dw
	if type(Nav.TargetOffset) == "function" then
		local ok2, a, b = pcall(Nav.TargetOffset)
		if ok2 then dn, dw = tonumber(a), tonumber(b) end
	end
	if not (dn and dw) then
		local zona = type(Nav.GetTargetZoneName) == "function" and Nav.GetTargetZoneName() or nil
		return type(zona) == "string" and zona ~= "" and format(L["Lejos de aquí: %s"], zona) or L["Lejos de aquí"]
	end
	local d = math.sqrt(dn * dn + dw * dw)
	local area = tonumber(t.area)
	if area and area > 0 then d = d > area and d - area or 0 end
	if d <= (tonumber(t.r) or 8) then return L["Ya llegaste"] end
	local txt
	if type(A.FormatDistance) == "function" then
		local ok3, r = pcall(A.FormatDistance, d)
		if ok3 and type(r) == "string" then txt = r end
	end
	return (txt or format("%d yd", floor(d + 0.5))) .. " " .. rumbo(dn, dw)
end

-- Cada segundo, mientras el rastreador compacto se ve: solo el texto; si la
-- línea aparece o se va, se acomoda todo.
local function latido()
	if not (F and F:IsShown() and ui.flecha) then return end
	local t = ui.conFlecha and compacto() and textoFlecha() or nil
	if (t ~= nil) ~= ui.flecha:IsShown() then Rs.Luego() return end
	if t then K.Escribir(ui.flecha.Texto, t) end
end

---------------------------------------------------------------------------
-- Construir el rastreador
---------------------------------------------------------------------------

-- El botón de buscar cerca se ve con rutas.cercaBoton; el título llega hasta
-- el primer botón a la vista.
function Rs.BotonCerca()
	local c = ui.cab
	if not c then return end
	local ver = M.Cerca ~= nil and A.Get(M.ID .. ".cercaBoton") ~= false
	c.Cerca:SetShown(ver)
	-- Hasta el primer botón (cerrar, el menú y buscar cerca: 22 px cada uno),
	-- sin encimarse: el nombre en hasta dos renglones (la cabecera crece,
	-- cabecera()), y entero al pasar el ratón por la cabecera.
	local botones = 8 + 22 + 2 + 22 + (ver and (2 + 22) or 0)
	c.alfaAnchoTitulo = ANCHO - botones - 6 - (PAD + 24)
	c.Titulo:SetJustifyH("LEFT")
	c.Sub:SetJustifyH("LEFT")
	c.Sub:SetWordWrap(false)
	c.Sub:SetWidth(c.alfaAnchoTitulo)
	if F and F:IsShown() and Rs.Luego then Rs.Luego() end
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
	cxR = nuevoCx(F)

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
	-- Buscar cerca (Cerca.lua): el vuelo, la posada, reparar... con la flecha.
	-- Con el pin de ubicación (no una lupa: se confundía con buscar texto).
	c.Cerca = K.BotonIcono(c, "ic-cerca", function(self) if M.Cerca then M.Cerca.Menu(self) end end,
		{ tam = 22, icono = 14, ayuda = L["Buscar cerca"], ayudaTexto = L["El maestro de vuelo, la posada, reparar, el banco y más: el más cercano, con la flecha y la ruta."] })
	c.Cerca:SetPoint("RIGHT", c.Menu, "LEFT", -2, 0)
	c.Titulo = K.Texto(c, "encabezado", "texto")
	c.Titulo:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 24, -7)
	c.Sub = K.Texto(c, "pequeno", "textoTenue")
	c.Sub:SetPoint("TOPLEFT", c.Titulo, "BOTTOMLEFT", 0, -2)
	Rs.BotonCerca()
	-- El nombre completo de la guía (en la cabecera puede ir cortado).
	K.ConInfo(c, function(self) return self.alfaNombre, nil end)
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

	-- Mi plan: la meta de ahora
	local pl = CreateFrame("Button", nil, F)
	ui.plan = pl
	pl:RegisterForClicks("LeftButtonUp")
	pl.caja = K.Caja(pl, { fondo = "panel", borde = "acento", corte = K.CORTE.control })
	pl.caja:Estilo({ alfaBorde = 0.45 })
	pl.Icono = K.Icono(pl, "ic-lista", 16, "acento")
	pl.Icono:SetPoint("TOPLEFT", pl, "TOPLEFT", 10, -10)
	pl.Sobre = K.Texto(pl, "mayus", "acento")
	pl.Titulo = K.Texto(pl, "etiqueta", "texto")
	pl.Titulo:SetWordWrap(true)
	pl.Texto = K.Texto(pl, "pequeno", "textoSuave")
	pl.Progreso = K.Progreso(pl, { alto = 4 })
	pl.Ir = K.Boton(pl, "", nil, { tipo = "acento", tam = "chico", icono = "ic-flecha" })
	pl.Hecha = K.Boton(pl, L["Ya la hice"], nil, { tipo = "fantasma", tam = "chico" })
	pl:SetScript("OnClick", function() if M.VistaPlanes then local d = M.Planes.Tarjeta() if d then M.VistaPlanes.Abrir(d.plan.id) end end end)
	K.ConInfo(pl, L["Mi plan"], L["Clic: abre tu plan para verlo o cambiarlo."])

	-- El paso
	ui.paso = K.Texto(F, "subtitulo", "texto")
	ui.paso:SetWordWrap(true)
	ui.nota = K.Texto(F, "nota", "textoSuave")
	ui.nota:SetWordWrap(true)

	-- "y N más": lleva al detalle
	local mas = CreateFrame("Button", nil, F)
	ui.mas = mas
	mas.Texto = K.Texto(mas, "pequeno", "textoTenue")
	mas.Texto:SetPoint("LEFT", mas, "LEFT", 20, 0)
	mas:SetHeight(16)
	mas:SetScript("OnClick", function() Rs.AbrirDetalle() end)
	mas:SetScript("OnEnter", function(self) K.ColorTexto(self.Texto, "acento") end)
	mas:SetScript("OnLeave", function(self) K.ColorTexto(self.Texto, "textoTenue") end)

	-- La flecha
	local fl = CreateFrame("Frame", nil, F)
	ui.flecha = fl
	fl:SetHeight(16)
	fl.Icono = K.Icono(fl, "ic-flecha", 12, "acento")
	fl.Icono:SetPoint("LEFT", fl, "LEFT", 2, 0)
	fl.Texto = K.Texto(fl, "pequeno", "textoSuave")
	fl.Texto:SetPoint("LEFT", fl, "LEFT", 20, 0)
	fl.Texto:SetPoint("RIGHT", fl, "RIGHT", 0, 0)

	-- Lo que la ruta agregó antes de la meta de ahora (una línea)
	local an = CreateFrame("Frame", nil, F)
	ui.antes = an
	an:SetHeight(16)
	an.Icono = K.Icono(an, "ic-info", 12, "aviso")
	an.Icono:SetPoint("LEFT", an, "LEFT", 2, 0)
	an.Texto = K.Texto(an, "pequeno", "textoSuave")
	an.Texto:SetPoint("LEFT", an, "LEFT", 20, 0)
	an.Texto:SetPoint("RIGHT", an, "RIGHT", 0, 0)

	-- Vacío (sin guía)
	ui.vacio = K.Vacio(F, { lobo = "dormido", titulo = L["No sigues ninguna guía"],
		texto = L["Elige qué quieres hacer y Alfa te lleva paso a paso."],
		accion = { texto = L["¿Qué quieres hacer?"], icono = "ic-lobo", alClic = function() if M.Asistente then M.Asistente.Abrir() end end } })

	-- El pie
	ui.detalle = K.Boton(F, L["Ver detalle"], function() Rs.AlternarDetalle() end,
		{ tipo = "fantasma", tam = "chico", icono = "ic-lista", ayuda = L["Todas las metas, notas y pasos de esta guía en otra ventana."] })
	ui.omitir = K.Boton(F, L["Omitir"], function()
		local e = E()
		if e and e.GetGuide and e.GetGuide() then engine("Skip") end
	end, { tipo = "fantasma", tam = "chico", ayuda = L["Omite este paso: la guía sigue con el siguiente. Puedes volver a él desde «Ver detalle»."] })
	-- Engine.Next solo deja mirar el paso que sigue (la guía avanza sola).
	ui.siguiente = K.Boton(F, L["Ver el siguiente"], function() engine("Next") end,
		{ tipo = "secundario", tam = "chico", ayuda = L["Solo para mirar: tu paso de ahora no cambia. Alfa avanza sola cuando lo cumples."] })
	ui.pieLinea = K.Linea(F, "linea")

	F:SetScript("OnShow", function()
		Rs.Pintar()
		if not ui.reloj then ui.reloj = A.NewTicker(1, latido) end
	end)
	F:SetScript("OnHide", function()
		if ui.reloj then ui.reloj:Cancel() ui.reloj = nil end
	end)
	F:Hide()
	ponerEnSuLugar()
end

---------------------------------------------------------------------------
-- El aviso de arriba: lo que pide atención, uno a la vez
---------------------------------------------------------------------------

-- Una misión del paso de ahora que el motor manda a tomar pero que todavía
-- no se puede tomar (la regla de la ruta). -> qid, texto | nil
-- Misiones bloqueadas que ya se resolvieron solas (una vez por misión y sesión).
local resueltas = {}

local function aceptarBloqueado(v)
	if not (v and v.goals and M.Disp) then return nil end
	for _, g in ipairs(v.goals) do
		if g.t == "accept" and g.quest and (g.status == "active" or g.status == "pending") then
			local ok, motivo, info = M.Disp.Estado(g.quest)
			-- "desconocida": las bases no cargaron o no está; ni se omite ni se bloquea.
			if not ok and motivo ~= "desconocida" then return g.quest, M.Disp.Texto(motivo, info), M.Disp.Imposible(motivo) end
		end
	end
	return nil
end

-- 1.2.6: el fin de guía al día. Si después terminaste lo que quedaba, ya es
-- «terminaste»; si el motor ya no tiene fin (abandonaste la última misión),
-- se quita. Antes se quedaba diciendo «quedaron 3 pasos» con la barra llena.
local function finAlDia()
	local fin = est.fin
	local m = fin and fin.modelo
	if not m then return end
	if not m.complete and M.GuiaTerminada and M.GuiaTerminada() then m.complete = true end
	if not engine("GetGuide") then est.fin = nil end
end
Rs.FinAlDia = finAlDia

local function aviso(v, live)
	finAlDia()
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
			-- Sin preguntar: si se puede, se agrega solo lo que falta; si no, se omite sola.
			-- El aviso solo sale si de verdad se agregó; en combate se reintenta al salir.
			local enCombate = InCombatLockdown and InCombatLockdown()
			if not resueltas[bq] and (imposible or not enCombate) then
				resueltas[bq] = imposible and "lista" or "armando"
				K.Despues(0, function()
					if imposible then engine("SkipQuest", bq, true) return end
					M.Recoger.Desbloquear(bq, function(bien)
						if bien then
							resueltas[bq] = "lista"
							Rs.Pintar()
						elseif InCombatLockdown and InCombatLockdown() then
							resueltas[bq] = nil -- se vuelve a intentar fuera de combate
						else
							resueltas[bq] = "fallo"
						end
					end)
				end)
			end
			if imposible or resueltas[bq] ~= "lista" then return nil end
			return { tono = "info", icono = "ic-ruta", titulo = format(L["Agregué lo que falta para %s"], M.Citar(M.TituloMision(bq))), texto = texto }
		end
	end
	-- La guía te manda a entregar una misión que aún no terminas (un paso que
	-- miras antes de tiempo, el de sus objetivos omitido, un plan viejo): se
	-- dice qué falta y se lleva a eso, nunca solo al PNJ.
	local sin, falta = entregaSinTerminar(v)
	if sin then
		local obra = pasoDeLaObra(sin.quest, v.index)
		local d = { tono = "aviso", icono = "ic-aviso", titulo = format(L["%s aún no está terminada"], M.Citar(sin.title or M.TituloMision(sin.quest))),
			texto = falta and format(L["Antes de entregarla te falta: %s."], falta) or L["Termínala antes de entregarla."] }
		local volver = live and format(L["Volver al paso %d"], numeroPaso(live))
		if obra then
			d.uno = { obra == live and volver or L["Llévame a lo que falta"], function() engine("Goto", obra) end }
		end
		if live and v.index ~= live and obra ~= live then
			d[d.uno and "dos" or "uno"] = { volver, function() engine("Goto", live) end }
		end
		return d
	end
	-- Vista previa: mirar otro paso lleva la flecha a ese paso (el motor la
	-- pone en el paso que se ve), no al de ahora; se dice cuál es el de ahora.
	if v and live and v.index ~= live then
		local ahora = engine("GetStepView", live)
		local nombre = ahora and tituloPaso(ahora) or ""
		local cual = nombre ~= "" and format(L["Tu paso de ahora es el %d: %s."], numeroPaso(live), nombre)
			or format(L["Tu paso de ahora es el %d."], numeroPaso(live))
		return { tono = "neutro", icono = "ic-info", titulo = format(L["Vista previa: paso %d"], numeroPaso(v.index)),
			texto = cual .. " " .. L["La flecha te lleva a este paso, no al de ahora."],
			uno = { format(L["Volver al paso %d"], numeroPaso(live)), function() engine("Goto", live) end } }
	end
	return nil
end

-- La meta de ahora de tu plan, si sigues uno. comp: compacta (el título en
-- una línea, sin su texto). -> alto
local function pintarPlan(ancho, comp)
	local b = ui.plan
	local d = M.Planes and M.Planes.Tarjeta()
	if not d then b:Hide() return 0 end
	local x = 34
	local tw = ancho - x - 10
	K.Escribir(b.Sobre, K.Mayus(d.total > 0 and format(L["Mi plan · %s · %d de %d"], d.nombre, d.hechas, d.total) or format(L["Mi plan · %s"], d.nombre)))
	b.Sobre:ClearAllPoints()
	b.Sobre:SetPoint("TOPLEFT", b, "TOPLEFT", x, -9)
	b.Sobre:SetWidth(tw)
	K.SetIcono(b.Icono, d.icono or "ic-lista", "acento")
	K.Escribir(b.Titulo, d.titulo or "")
	b.Titulo:ClearAllPoints()
	b.Titulo:SetPoint("TOPLEFT", b, "TOPLEFT", x, -24)
	local y = 24 + K.Parrafo(b.Titulo, tw, comp and 1 or 2)
	if not comp and d.texto and d.texto ~= "" then
		K.Escribir(b.Texto, d.texto)
		b.Texto:ClearAllPoints()
		b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", x, -(y + 2))
		y = y + 2 + K.Parrafo(b.Texto, tw, 2)
		b.Texto:Show()
	else
		b.Texto:Hide()
	end
	if d.frac then
		b.Progreso:ClearAllPoints()
		b.Progreso:SetPoint("TOPLEFT", b, "TOPLEFT", x, -(y + 5))
		b.Progreso:Acomodar(tw)
		b.Progreso:Set(d.frac)
		b.Progreso:Show()
		y = y + 9
	else
		b.Progreso:Hide()
	end
	local bx = x
	if d.ir then
		b.Ir:SetTexto(d.ir[1])
		b.Ir.alClic = d.ir[2]
		b.Ir:ClearAllPoints()
		b.Ir:SetPoint("TOPLEFT", b, "TOPLEFT", bx, -(y + 8))
		bx = bx + b.Ir:AnchoNatural() + K.ESP.s
		b.Ir:Show()
	else
		b.Ir:Hide()
	end
	if d.hecha then
		b.Hecha.alClic = d.hecha
		b.Hecha:ClearAllPoints()
		b.Hecha:SetPoint("TOPLEFT", b, "TOPLEFT", bx, -(y + 8))
		b.Hecha:Show()
	else
		b.Hecha:Hide()
	end
	if d.ir or d.hecha then y = y + 8 + K.ALTO.botonChico end
	local h = y + 10
	b:SetSize(ancho, h)
	b:Show()
	return h
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
		y = y + 2 + K.Parrafo(b.Texto, tw, 4)
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
-- Pintar el rastreador
---------------------------------------------------------------------------

-- El nombre de la guía y "Paso 12 de 80 · 15 %". -> nombre, línea, hechos, total
local function resumenGuia(g, v)
	local u = U()
	local nombre = g and (u and u.GuideLabel and u.GuideLabel(g) or g.title) or L["Alfa"]
	-- Un solo número: los pasos hechos (el número del paso que miras lo dice
	-- la vista previa; "Paso 2" junto a "54 %" se contradecía).
	local done, total = engine("GetProgress")
	local linea = (total and total > 0) and format(L["%d de %d pasos hechos"], done or 0, total) or ""
	-- Tu guarida (1.2.5, La Jauría): «· Guarida Colmillo» al final.
	local Ma = rawget(_G, "AlfaManada")
	local guarida = type(Ma) == "table" and type(Ma.Guarida) == "function" and Ma.Guarida()
	local corta = linea
	if type(guarida) == "string" and guarida ~= "" then
		linea = linea ~= "" and (linea .. "  \194\183  " .. guarida) or guarida
	end
	return nombre, linea, done, total, corta
end

local function cabecera(g, v)
	local c = ui.cab
	local nombre, linea, done, total, corta = resumenGuia(g, v)
	c.alfaNombre = g and nombre or nil
	K.Escribir(c.Titulo, nombre)
	K.Escribir(c.Sub, linea)
	-- Con la guarida, solo si cabe entera (nada de textos cortados).
	if linea ~= corta and K.AnchoTexto(c.Sub) > (c.alfaAnchoTitulo or (ANCHO - 120)) then
		linea = corta
		K.Escribir(c.Sub, linea)
	end
	-- El nombre en hasta dos renglones; la cabecera crece con él.
	local ht = K.Parrafo(c.Titulo, c.alfaAnchoTitulo or (ANCHO - 120), 2)
	local hs = linea ~= "" and K.AltoTexto(c.Sub) or 0
	ui.altoCab = max(CAB, 7 + ht + (hs > 0 and (2 + hs) or 0) + 7)
	c:SetHeight(ui.altoCab)
	ui.huellas:Set(done or 0, total or 0)
	return total and total > 0
end

-- Lo que dice el cuadro vacío (1.2.3). Sin guía: elige qué hacer. Con una
-- guía abierta pero sin paso (todo lo que queda está omitido o aún no te
-- toca), antes decía «No sigues ninguna guía» y confundía: ahora dice qué
-- pasa y, si es «Cerrar mis misiones», lo vuelve a armar con un clic.
local VACIO_SIN_GUIA = { lobo = "dormido", titulo = L["No sigues ninguna guía"],
	texto = L["Elige qué quieres hacer y Alfa te lleva paso a paso."],
	accion = { texto = L["¿Qué quieres hacer?"], icono = "ic-lobo", alClic = function() if M.Asistente then M.Asistente.Abrir() end end } }
local VACIO_PLAN = { lobo = "atento", titulo = L["Tu plan se quedó sin paso"],
	texto = L["Lo que tenía ya está hecho, omitido o fuera de tu registro. Ármalo otra vez con las misiones que tienes ahora."],
	accion = { texto = L["Rearmar el plan"], icono = "ic-ruta", alClic = function() if M.Cerrar then M.Cerrar.Ahora() end end } }
local VACIO_GUIA = { lobo = "atento", titulo = L["Esta guía no tiene un paso para ti ahora"],
	texto = L["Puede que hayas omitido lo que queda o que aún no te toque. Elige otra guía o vuelve a esta más adelante."],
	accion = { texto = L["Elegir otra guía"], icono = "ic-guia", alClic = function() A.Fire("SHOW_PICKER") end } }

-- 1.2.6: la guía con todos sus pasos hechos y sin paso vivo está terminada,
-- aunque el motor no haya avisado el fin (las guías especiales, como
-- «Desbloquear», no lo avisan): decía «no tiene un paso para ti» con «2 de 2».
local VACIO_HECHA = { lobo = "aullando", titulo = L["¡Terminaste esta guía!"],
	texto = L["Ya no queda nada por hacer aquí. Elige qué sigue y la manada va contigo."],
	accion = { texto = L["Elegir qué sigue"], icono = "ic-ruta", alClic = function() A.Fire("SHOW_PICKER") end } }
local VACIO_DESBLOQUEADA = { lobo = "aullando", titulo = L["¡Ya la desbloqueaste!"],
	texto = L["Hiciste lo que pedía antes. Búscala con su «!» y tómala, o elige qué sigue."],
	accion = { texto = L["Elegir qué sigue"], icono = "ic-ruta", alClic = function() A.Fire("SHOW_PICKER") end } }

-- Terminada de verdad: sin paso vivo y cada paso suyo hecho (no omitido: sin
-- paso vivo, el motor cuenta los omitidos como hechos en su avance).
local function terminada()
	if engine("GetLiveStep") then return false end
	local g = engine("GetGuide")
	local pasos = type(g) == "table" and type(g.steps) == "table" and g.steps or nil
	if not pasos or #pasos == 0 then return false end
	local alguno = false
	for i = 1, #pasos do
		local v = engine("GetStepView", i)
		if type(v) == "table" and v.status ~= "na" then
			if v.status ~= "done" or v.skipped then return false end
			alguno = true
		end
	end
	return alguno
end
M.GuiaTerminada = terminada

local function cuadroVacio(g)
	if not g then return VACIO_SIN_GUIA end
	local esp = M.Guias and M.Guias.Especial(g.id)
	if terminada() then return esp == "desbloquear" and VACIO_DESBLOQUEADA or VACIO_HECHA end
	if esp == "liberar" then return VACIO_PLAN end
	return VACIO_GUIA
end

-- 1.2.6: «Desbloquear» terminada: de vuelta a la guía de la que venías (una
-- vez), con Lya diciéndolo. Sin guía de antes, el cuadro ofrece qué sigue.
local volviendo = false
local function volverDeDesbloquear()
	if volviendo then return end
	volviendo = true
	A.After(1.5, function()
		volviendo = false
		if not (M.Guias and M.Guias.Volver and M.Guias.Volver()) then return end
		if M.Aviso then M.Aviso(L["¡Ya la desbloqueaste!"], L["Volvemos a tu guía: la misión que esperabas ya está lista para ti."], { lobo = "aullando" }) end
	end)
end

-- Pone en el cuadro vacío lo que toca (solo si cambió).
local function ponerVacio(cuadro, g)
	local o = cuadroVacio(g)
	if o == VACIO_DESBLOQUEADA then volverDeDesbloquear() end
	if cuadro.alfaVacio ~= o then
		cuadro.alfaVacio = o
		cuadro:Set(o)
	end
end

function Rs.Pintar()
	if not (F and F:IsShown()) then return end
	local comp = compacto()
	local e = E()
	local g = e and e.GetGuide and e.GetGuide()
	local i = g and engine("GetStepIndex")
	local live = g and engine("GetLiveStep")
	local v = i and engine("GetStepView", i)
	local x, ancho = PAD, ANCHO - 2 * PAD
	-- Vista previa: miras otro paso que el de ahora.
	local previa = v ~= nil and live ~= nil and v.index ~= live
	cxR.previa = previa
	local conAvance = cabecera(g, v)
	local y = (ui.altoCab or CAB) + K.ESP.s
	if conAvance and not comp then
		ui.huellas:ClearAllPoints()
		ui.huellas:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		ui.huellas:Show()
		y = y + 20
	else
		ui.huellas:Hide()
	end
	local vacio = not (g and v)
	-- Mi plan
	local hp = pintarPlan(ancho, comp)
	if hp > 0 then
		ui.plan:ClearAllPoints()
		ui.plan:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		y = y + hp + K.ESP.m
	end
	local conVacio = vacio and not est.fin and hp == 0
	if conVacio then ponerVacio(ui.vacio, g) end
	ui.vacio:SetShown(conVacio)
	-- El aviso
	local h = pintarAviso(aviso(v, live), ancho)
	if h > 0 then
		ui.aviso:ClearAllPoints()
		ui.aviso:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		y = y + h + K.ESP.m
	end
	ui.paso:SetShown(not vacio)
	ui.nota:Hide()
	ui.mas:Hide()
	ui.flecha:Hide()
	ui.conFlecha = false
	ui.antes:Hide()
	if not vacio then
		K.Escribir(ui.paso, tituloPaso(v))
		ui.paso:ClearAllPoints()
		ui.paso:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		y = y + K.Parrafo(ui.paso, ancho, 2) + 4
		if comp then
			y = y + 2
			local resto, antes
			y, resto, antes = pintarMetasCompacto(cxR, v, x, y, ancho)
			if resto > 0 then
				K.Escribir(ui.mas.Texto, format(L["y %d más"], resto))
				ui.mas:ClearAllPoints()
				ui.mas:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
				ui.mas:SetWidth(ancho)
				ui.mas:Show()
				y = y + 16 + 2
			end
			-- El latido mira lo mismo: si no, repinta todo cada segundo. La
			-- flecha va al paso que se ve (el motor), sea el de ahora u otro.
			ui.conFlecha = live ~= nil
			local t = ui.conFlecha and textoFlecha() or nil
			if t then
				K.Escribir(ui.flecha.Texto, t)
				ui.flecha:ClearAllPoints()
				ui.flecha:SetPoint("TOPLEFT", F, "TOPLEFT", x, -(y + 2))
				ui.flecha:SetWidth(ancho)
				ui.flecha:Show()
				y = y + 20
			end
			if cxR.objeto then cxR.objeto:Hide() end
			-- Una sola línea de contexto: lo que la ruta agregó antes, o
			-- lo que hay cerca.
			if antes then
				K.Escribir(ui.antes.Texto, format(L["Antes: %s"], antes))
				ui.antes:ClearAllPoints()
				ui.antes:SetPoint("TOPLEFT", F, "TOPLEFT", x, -(y + 2))
				ui.antes:SetWidth(ancho)
				ui.antes:Show()
				y = y + 20
				pintarCerca(cxR, x, y, ancho, 0, false)
			else
				y = pintarCerca(cxR, x, y + 2, ancho, 1, false)
			end
		else
			local nota = A.Get("ui.showNotes") ~= false and notaPaso(v) or nil
			if nota then
				K.Escribir(ui.nota, nota)
				ui.nota:ClearAllPoints()
				ui.nota:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
				y = y + K.Parrafo(ui.nota, ancho, 4) + K.ESP.s
				ui.nota:Show()
			end
			y = y + 2
			local here = A.PlayerPoint and A.PlayerPoint()
			y = pintarMetas(cxR, v, x, y, ancho, here and here.map)
			y = y + K.ESP.xs
			y = pintarObjeto(cxR, x, y, ancho)
			y = pintarCerca(cxR, x, y, ancho, MAX_CERCA, true)
		end
	else
		ocultarPaso(cxR)
	end
	if conVacio then
		local vh = ui.vacio:Acomodar(ancho)
		ui.vacio:ClearAllPoints()
		ui.vacio:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		y = y + vh + K.ESP.base
	end
	-- El pie: Ver detalle · Omitir · Siguiente
	local conPie = not vacio
	for _, b in ipairs({ ui.detalle, ui.omitir, ui.siguiente, ui.pieLinea }) do b:SetShown(conPie) end
	-- Omitir salta el paso que se ve (Engine.Skip): en la vista previa no se
	-- ofrece aquí (el detalle dice cuál omite).
	if previa then ui.omitir:Hide() end
	if conPie then
		y = y + K.ESP.xs
		ui.pieLinea:ClearAllPoints()
		ui.pieLinea:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		ui.pieLinea:SetPoint("TOPRIGHT", F, "TOPLEFT", x + ancho, -y)
		local by = y + floor((PIE - K.ALTO.botonChico) / 2)
		ui.detalle:ClearAllPoints()
		ui.detalle:SetPoint("TOPLEFT", F, "TOPLEFT", x - 4, -by)
		ui.siguiente:ClearAllPoints()
		ui.siguiente:SetPoint("TOPRIGHT", F, "TOPLEFT", x + ancho + 4, -by)
		ui.omitir:ClearAllPoints()
		ui.omitir:SetPoint("TOPRIGHT", ui.siguiente, "TOPLEFT", -K.ESP.xs, 0)
		y = y + PIE
	else
		y = y + K.ESP.xs
	end
	F:SetHeight(y)
end

---------------------------------------------------------------------------
-- La ventana de detalle: el paso entero y todos los pasos
---------------------------------------------------------------------------

local D -- la ventana
local dui = {}
local dvista = "paso"

local function construirDetalle()
	D = K.Ventana({ nombre = "AlfaRastreadorDetalle", titulo = L["Detalle de la guía"], icono = "ic-guia", ancho = 460, alto = 600 })
	local cuerpo = D.Cuerpo
	dui.seg = K.Segmentos(cuerpo, { estilo = "segmentos", valor = dvista,
		opciones = { { valor = "paso", texto = L["Este paso"] }, { valor = "pasos", texto = L["Todos los pasos"] } },
		alCambiar = function(valor) if valor ~= dvista then dvista = valor Rs.PintarDetalle() end end })
	dui.scroll = K.Desplazable(cuerpo)
	local C = dui.scroll.Contenido
	dui.cx = nuevoCx(C)
	-- Tu plan
	dui.planSobre = K.Texto(C, "mayus", "acento")
	dui.planTitulo = K.Texto(C, "etiqueta", "texto")
	dui.planTitulo:SetWordWrap(true)
	dui.planVer = K.Boton(C, L["Ver el plan"], function()
		local d = M.Planes and M.Planes.Tarjeta()
		if d and M.VistaPlanes then M.VistaPlanes.Abrir(d.plan.id) end
	end, { tipo = "secundario", tam = "chico", icono = "ic-lista" })
	dui.planLinea = K.Linea(C, "linea")
	-- El paso
	dui.titulo = K.Texto(C, "subtitulo", "texto")
	dui.titulo:SetWordWrap(true)
	dui.nota = K.Texto(C, "nota", "textoSuave")
	dui.nota:SetWordWrap(true)
	dui.vacio = K.Vacio(C, { lobo = "dormido", titulo = L["No sigues ninguna guía"],
		texto = L["Elige qué quieres hacer y Alfa te lleva paso a paso."],
		accion = { texto = L["¿Qué quieres hacer?"], icono = "ic-lobo", alClic = function() if M.Asistente then M.Asistente.Abrir() end end } })
	-- Todos los pasos
	dui.lista = K.Lista(cuerpo, {
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
		alClic = function(i)
			engine("Goto", i)
			dvista = "paso"
			dui.seg:SetValor("paso")
			Rs.PintarDetalle()
		end,
		elegir = false,
	})
	-- El pie: Anterior a la izquierda; Omitir y Siguiente a la derecha.
	dui.atras = K.Boton(D, L["Anterior"], function() engine("Prev") end, { tipo = "fantasma", tam = "chico" })
	dui.omitir = K.Boton(D, L["Omitir"], function()
		local e = E()
		if e and e.GetGuide and e.GetGuide() then engine("Skip") end
	end, { tipo = "fantasma", tam = "chico", ayuda = L["Omite este paso: la guía sigue con el siguiente. Puedes volver a él con Anterior."] })
	dui.siguiente = K.Boton(D, L["Ver el siguiente"], function() engine("Next") end,
		{ tipo = "secundario", tam = "chico", ayuda = L["Solo para mirar: tu paso de ahora no cambia. Alfa avanza sola cuando lo cumples."] })
	D:SetPie({ dui.omitir, dui.siguiente }, { dui.atras })
	D:SetScript("OnShow", function() Rs.PintarDetalle() end)
	D.alAcomodar = function() Rs.PintarDetalle() end
end

function Rs.PintarDetalle()
	if not (D and D:IsShown()) then return end
	local e = E()
	local g = e and e.GetGuide and e.GetGuide()
	local i = g and engine("GetStepIndex")
	local live = g and engine("GetLiveStep")
	local v = i and engine("GetStepView", i)
	local vacio = not (g and v)
	local nombre, linea = resumenGuia(g, v)
	D:SetTitulo(g and nombre or L["Detalle de la guía"], linea, "ic-guia")
	local m = D.margen
	local ancho = D:AnchoCuerpo()
	local y = K.ESP.m
	dui.seg:SetShown(not vacio)
	if not vacio then
		local hs = dui.seg:Acomodar(ancho)
		dui.seg:ClearAllPoints()
		dui.seg:SetPoint("TOPLEFT", D.Cuerpo, "TOPLEFT", m, -y)
		y = y + hs + K.ESP.m
	end
	local alto = max(80, D:AltoCuerpo() - y - K.ESP.s)
	for _, b in ipairs({ dui.atras, dui.omitir, dui.siguiente }) do b:SetActivo(not vacio) end
	if not vacio then dui.atras:SetActivo(i > 1) end
	-- Omitir salta el paso que se ve: en la vista previa dice cuál.
	local previa = v ~= nil and live ~= nil and v.index ~= live
	dui.cx.previa = previa
	local omitir = previa and format(L["Omitir el paso %d"], numeroPaso(v.index)) or L["Omitir"]
	if dui.omitir.alfaRotulo ~= omitir then
		dui.omitir.alfaRotulo = omitir
		dui.omitir:SetTexto(omitir)
	end
	-- Todos los pasos
	if dvista == "pasos" and not vacio then
		dui.scroll:Hide()
		local datosLista = {}
		local u = U()
		for k = 1, engine("GetStepCount") or 0 do
			if not (u and u.StepHidden and u.StepHidden(k)) then datosLista[#datosLista + 1] = k end
		end
		dui.lista:ClearAllPoints()
		dui.lista:SetPoint("TOPLEFT", D.Cuerpo, "TOPLEFT", m - 4, -y)
		dui.lista:Acomodar(ancho + 8, alto)
		dui.lista:SetDatos(datosLista)
		for pos, k in ipairs(datosLista) do if k == live then dui.lista:IrA(pos) end end
		dui.lista:Show()
		return
	end
	dui.lista:Hide()
	dui.scroll:Show()
	dui.scroll:ClearAllPoints()
	dui.scroll:SetPoint("TOPLEFT", D.Cuerpo, "TOPLEFT", m, -y)
	dui.scroll:Acomodar(ancho + 12, alto)
	local cx = dui.cx
	local w = ancho
	local cy = 0
	-- Tu plan
	local d = M.Planes and M.Planes.Tarjeta()
	local conPlan = d ~= nil
	for _, p in ipairs({ dui.planSobre, dui.planTitulo, dui.planVer, dui.planLinea }) do p:SetShown(conPlan) end
	if conPlan then
		K.Escribir(dui.planSobre, K.Mayus(d.total > 0 and format(L["Mi plan · %s · %d de %d"], d.nombre, d.hechas, d.total) or format(L["Mi plan · %s"], d.nombre)))
		dui.planSobre:ClearAllPoints()
		dui.planSobre:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", 0, -cy)
		dui.planSobre:SetWidth(w)
		cy = cy + 16
		K.Escribir(dui.planTitulo, d.titulo or "")
		dui.planTitulo:ClearAllPoints()
		dui.planTitulo:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", 0, -cy)
		cy = cy + K.Parrafo(dui.planTitulo, w) + K.ESP.s
		dui.planVer:ClearAllPoints()
		dui.planVer:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", 0, -cy)
		cy = cy + K.ALTO.botonChico + K.ESP.m
		dui.planLinea:ClearAllPoints()
		dui.planLinea:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", 0, -cy)
		dui.planLinea:SetPoint("TOPRIGHT", cx.padre, "TOPLEFT", w, -cy)
		cy = cy + K.ESP.m
	end
	-- El paso
	if vacio and not conPlan then ponerVacio(dui.vacio, g) end
	dui.vacio:SetShown(vacio and not conPlan)
	dui.titulo:SetShown(not vacio)
	dui.nota:Hide()
	if vacio then
		ocultarPaso(cx)
		if not conPlan then
			local vh = dui.vacio:Acomodar(w)
			dui.vacio:ClearAllPoints()
			dui.vacio:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", 0, -cy)
			cy = cy + vh
		end
	else
		K.Escribir(dui.titulo, tituloPaso(v))
		dui.titulo:ClearAllPoints()
		dui.titulo:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", 0, -cy)
		cy = cy + K.Parrafo(dui.titulo, w) + 4
		local nota = notaPaso(v)
		if nota then
			K.Escribir(dui.nota, nota)
			dui.nota:ClearAllPoints()
			dui.nota:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", 0, -cy)
			cy = cy + K.Parrafo(dui.nota, w) + K.ESP.s
			dui.nota:Show()
		end
		cy = cy + 2
		local here = A.PlayerPoint and A.PlayerPoint()
		cy = pintarMetas(cx, v, 6, cy, w - 6, here and here.map)
		cy = cy + K.ESP.s
		cy = pintarObjeto(cx, 0, cy, w)
		cy = pintarCerca(cx, 0, cy + K.ESP.xs, w, MAX_CERCA_DETALLE, true)
	end
	dui.scroll:SetAltoContenido(cy + K.ESP.base)
end

-- vista: "paso" (por omisión, la que tenías) o "pasos".
function Rs.AbrirDetalle(vista)
	if not D then construirDetalle() end
	if vista == "paso" or vista == "pasos" then
		dvista = vista
		dui.seg:SetValor(vista)
	end
	D:Abrir()
	Rs.PintarDetalle()
end

function Rs.AlternarDetalle()
	if D and D:IsShown() then D:Cerrar() else Rs.AbrirDetalle() end
end

function Rs.DetalleVisible() return D ~= nil and D:IsShown() end

-- Muchas cosas cambian seguido (cada bicho muerto, cada paso): se pinta una
-- vez por tanda, lo que esté a la vista.
local function luego()
	if est.pendiente or not ((F and F:IsShown()) or (D and D:IsShown())) then return end
	est.pendiente = true
	A.After(0.05, function()
		est.pendiente = false
		Rs.Pintar()
		Rs.PintarDetalle()
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
		-- 1.2.6: lo mismo que el rastreador (antes decía «Terminaste» aunque
		-- quedaran pasos, y la página Hoy te mandaba a seguir).
		finAlDia()
		local m = p.modelo or {}
		if m.complete then
			local uno = (m.next and format(L["Seguir con %s"], m.nextLabel or "")) or L["¿Qué sigue?"]
			K.Aviso({ lobo = "aullando", titulo = format(L["¡Bien hecho! %s"], m.label or ""), texto = L["Terminaste esta guía."],
				duracion = 12, accion = { texto = uno, alClic = function() est.fin = nil if p.Empezar then p.Empezar() else M.Empezar() end end } })
		else
			K.Aviso({ lobo = "atento", titulo = format(L["Final de %s"], m.label or ""),
				texto = format(L["Llegaste al final; quedaron %d pasos sin hacer."], m.undone or 0),
				duracion = 12, accion = { texto = L["Ver lo que quedó"], alClic = function() est.fin = nil AlfaNucleo.EmpezarRuta() end } })
		end
	end
end

N.Reemplazar("GUIDE_FRAME", pedidoVentana, function() return F ~= nil and F:IsShown() end)
N.Reemplazar("GUIDE_END", pedidoFin, function() return est.fin ~= nil end)

-- Para la página Hoy (1.2.6): el fin pendiente de la guía, al día.
function Rs.Fin()
	finAlDia()
	return est.fin and est.fin.modelo or nil
end

-- 1.2.6: «Desbloquear» terminada te regresa a tu guía aunque el rastreador
-- esté oculto o muestre otra cosa (antes solo desde su cuadro vacío).
local function revisarDesbloqueo()
	local g = engine("GetGuide")
	local id = type(g) == "table" and g.id
	if M.Guias and M.Guias.Especial(id) == "desbloquear" and M.GuiaTerminada and M.GuiaTerminada() then volverDeDesbloquear() end
end
for _, msg in ipairs({ "GUIDE_COMPLETED", "STEP_CHANGED", "STEP_UPDATED" }) do A.On(msg, revisarDesbloqueo) end
A.RegisterEvent("QUEST_TURNED_IN", function() A.After(1, revisarDesbloqueo) end)

for _, msg in ipairs({ "GUIDE_CHANGED", "STEP_CHANGED", "STEP_UPDATED", "WAYPOINT_CHANGED", "WHILE_HERE_CHANGED",
	"TABS_CHANGED", "GUIDE_COMPLETED", "PINS_CHANGED", "QUEST_TIMER", "STEP_SKIPPED", "ROUTE_CHOSEN" }) do
	A.On(msg, luego)
end
A.RegisterEvent("QUEST_LOG_UPDATE", luego)
A.RegisterEvent("BAG_UPDATE_DELAYED", luego)
-- Al salir de combate: lo que se dejó para después (agregar lo que falta).
A.RegisterEvent("PLAYER_REGEN_ENABLED", luego)
K.AlRepintar(function()
	if F and F:IsShown() then Rs.Pintar() end
	Rs.PintarDetalle()
end)
local VISTA = { [M.ID .. ".seguimientoCompleto"] = true, ["ui.compact"] = true, ["ui.showNotes"] = true }
A.On("SETTING_CHANGED", function(ruta)
	if ruta == M.ID .. ".cercaBoton" then Rs.BotonCerca() end
	if VISTA[ruta] or ruta == "" then luego() end
end)
M.Escuchar("PLANES", luego)
M.Escuchar("PLAN_AVANCE", luego)

function Rs.Visible() return F ~= nil and F:IsShown() end
function Rs.Mostrar() A.Set("ui.shown", true) end
