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
A.RegisterDefaults(M.ID, { seguimientoCompleto = false, xpEntrega = true, rastreadorEsencial = true,
	avanceTiempo = true, recompensaGuia = true }) -- 1.4.0: avanceTiempo (25), recompensaGuia (28) -- 1.3.9: rastreadorEsencial (71) -- 1.3.7: xpEntrega, «+1,250 XP» en cada entrega

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
	-- 1.3.9 (19): la vista de un paso, compartida con Hoy y el Escritorio (Reloj.lua).
	if fn == "GetStepView" and f and N.VistaPaso then f = N.VistaPaso end
	if type(f) ~= "function" then return nil end
	local ok, a, b, c = pcall(f, ...)
	if ok then return a, b, c end
	return nil
end

local function datos() return N.Datos(M.ID) end

-- 1.3.7: el nombre de una guía (o de su id), nunca vacío: «Seguir con »
-- salía sin nombre cuando la guía que sigue no traía etiqueta (84).
local function nombreGuia(g)
	if type(g) == "string" then
		local G = A.Guides
		local h
		if G and type(G.Get) == "function" then
			local ok, r = pcall(G.Get, g)
			if ok and type(r) == "table" then h = r end
		end
		g = h
	end
	if type(g) ~= "table" then return nil end
	local u = U()
	local s
	if u and type(u.GuideLabel) == "function" then
		local ok, r = pcall(u.GuideLabel, g)
		if ok then s = r end
	end
	if type(s) ~= "string" or s == "" then s = g.title end
	return type(s) == "string" and s ~= "" and s or nil
end
M.NombreGuia = nombreGuia

-- «Seguir con X», o «Seguir con la que sigue» sin nombre.
local function seguirCon(nombre)
	if type(nombre) == "string" and nombre ~= "" then return format(L["Seguir con %s"], nombre) end
	return L["Seguir con la que sigue"]
end
M.SeguirCon = seguirCon

-- 1.3.7: «quedaron 3 pasos» / «quedó 1 paso» (78).
local function quedaron(n)
	return M.Plural(tonumber(n) or 0, L["Llegaste al final; quedó %d paso sin hacer."], L["Llegaste al final; quedaron %d pasos sin hacer."])
end
M.Quedaron = quedaron

---------------------------------------------------------------------------
-- 1.2.7: Omitir, con «Deshacer» un rato
---------------------------------------------------------------------------
-- Solo lo que omites tú con el botón Omitir (del rastreador o de «Ver
-- detalle»); lo que el motor pasa solo no pregunta.
local DESHACER_SEG = 60

function Rs.OfrecerDeshacer(guia, paso)
	if not (guia and type(paso) == "number") then return end
	local cuando = GetTime()
	local v = engine("GetStepView", paso)
	local titulo = type(v) == "table" and Rs.TituloPaso and Rs.TituloPaso(v) or nil
	M.Aviso(L["Omitiste un paso"], (titulo and titulo ~= "") and titulo or nil, {
		icono = "ic-cerrar",
		accion = { texto = L["Deshacer"], alClic = function()
			local e = E()
			local g = e and e.GetGuide and e.GetGuide()
			if not (g and g.id == guia) or GetTime() - cuando > DESHACER_SEG then
				M.Aviso(L["Ya no se puede deshacer"], L["Puedes volver a ese paso desde «Ver detalle»."], { icono = "ic-info" })
				return
			end
			engine("Unskip", paso)
		end },
	})
end

function Rs.Omitir()
	local e = E()
	local g = e and e.GetGuide and e.GetGuide()
	if not g then return end
	local paso = engine("Skip")
	if type(paso) == "number" then Rs.OfrecerDeshacer(g.id, paso) end
end

-- 1.3.7: «Omitir esta misión» con su «Deshacer» (82), igual que un paso.
function Rs.OmitirMision(q, titulo)
	if type(q) ~= "number" then return end
	if not engine("SkipQuest", q, true) then return end
	local cuando = GetTime()
	if type(titulo) ~= "string" or titulo == "" then titulo = M.TituloMision(q) end
	M.Aviso(L["Omitiste una misión"], titulo and M.Citar(titulo) or nil, {
		icono = "ic-cerrar",
		accion = { texto = L["Deshacer"], alClic = function()
			if GetTime() - cuando > DESHACER_SEG then
				M.Aviso(L["Ya no se puede deshacer"], L["Puedes volver a ese paso desde «Ver detalle»."], { icono = "ic-info" })
				return
			end
			engine("SkipQuest", q, false)
		end },
	})
end

-- 1.3.7: el mapa de Alfa encuadrado en el lugar de la flecha (105).
function Rs.VerEnMapa()
	local Mu = rawget(_G, "AlfaMundo")
	if type(Mu) ~= "table" or type(Mu.Abrir) ~= "function" then
		if ToggleWorldMap then pcall(ToggleWorldMap) end
		return false
	end
	local Nav = A.Nav
	local t = Nav and Nav.GetTarget and select(2, pcall(Nav.GetTarget))
	local mapa = type(t) == "table" and tonumber(t.map) or nil
	pcall(Mu.Abrir, mapa)
	return true
end

-- La vista compacta (de fábrica) o la amplia.
-- 1.2.9: con el modo foco de Lya, compacta en mazmorras y en combate (Foco.lua).
local function compacto()
	if M.Foco and M.Foco.Activo() then return true end
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

-- 1.3.7: también en los otros idiomas (83): antes solo se escondían en
-- español y en alemán, francés, portugués, ruso, coreano y chino salían
-- mezcladas. Las palabras comunes de cada idioma de letras latinas; en ruso,
-- coreano y chino, las palabras con letras de su idioma.
local PROPIAS = {
	deDE = "der die das den dem des und mit von zu zum zur im am auf nach bei durch ein eine einen ist sind hier dort oben unten links rechts nord norden sud westen osten hinter vor neben turm brucke hohle",
	frFR = "le la les des du de et avec dans sur vers au aux un une est sont ici pres haut bas nord sud est ouest derriere devant entre tour pont grotte porte chemin",
	ptBR = "o a os as do da dos das de em no na nos nas com para por um uma e sao aqui perto cima baixo norte sul leste oeste atras entre torre ponte caverna porta caminho",
}
local LATINAS = { esMX = ESPANOL, esES = ESPANOL }
for loc, palabras in pairs(PROPIAS) do
	local t = {}
	for w in palabras:gmatch("%a+") do t[w] = true end
	LATINAS[loc] = t
end
local SIN_LATINAS = { ruRU = true, koKR = true, zhCN = true, zhTW = true }

local idioma
local function idiomaDeAlfa()
	if idioma == nil then
		local f = rawget(_G, "AlfaIdioma")
		local ok, loc = false, nil
		if type(f) == "function" then ok, loc = pcall(f) end
		if not (ok and type(loc) == "string") then loc = GetLocale and GetLocale() or "" end
		idioma = loc
	end
	return idioma
end
local function enEspanol()
	local loc = idiomaDeAlfa()
	return loc == "esMX" or loc == "esES"
end
Rs.EnEspanol = enEspanol
function Rs.OlvidarIdioma() idioma = nil end -- (para el banco)

-- -> true si el texto parece una nota en inglés que no se tradujo.
function Rs.SinTraducir(s)
	if type(s) ~= "string" or s == "" then return false end
	local loc = idiomaDeAlfa()
	local propias = LATINAS[loc]
	local sinLatinas = SIN_LATINAS[loc]
	if not (propias or sinLatinas) then return false end
	local limpio = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")
	local en, es, primera, posesivo = 0, 0, nil, false
	if sinLatinas then
		-- Las palabras con letras de su idioma (bytes de más de 127) son suyas.
		for w in limpio:gmatch("[\128-\255]+") do es = es + 1 end
	end
	for w in limpio:lower():gmatch("[%a']+") do
		if primera == nil then primera = w end
		if INGLES[w] then en = en + 1 elseif propias and propias[w] then es = es + 1 end
		-- "X's hunt targets": el posesivo del inglés (el español no lo usa).
		if w:find("%a's$") then posesivo = true end
	end
	if sinLatinas and es > 0 then return en >= 2 and en > es end
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
Rs.TituloPaso = tituloPaso -- 1.2.7 (el aviso de Omitir)
-- 1.3.9 (42): Hoy y el Escritorio lo leen por AlfaRuta.TituloPaso (Contrato.lua).

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

-- 1.3.7c: plegada, el rastreador deja la cabecera (con su barra de avance),
-- el paso de ahora y la línea de la flecha; un clic en la cabecera la abre.
-- Se recuerda entre sesiones.
function Rs.Plegada() return datos().plegada == true end
function Rs.Plegar(si)
	datos().plegada = si and true or nil
	if F and F:IsShown() then Rs.Pintar() end
end

local function menuGuia(dueno)
	local e = E()
	local tabs, activa = engine("GetTabs")
	local op = {}
	if e and e.GetGuide and e.GetGuide() then
		op[#op + 1] = { valor = function() Rs.AbrirDetalle() end, texto = L["Ver detalle"], icono = "ic-lista" }
		op[#op + 1] = { valor = function() A.Set(M.ID .. ".seguimientoCompleto", compacto()) end,
			texto = compacto() and L["Mostrar más en el seguimiento"] or L["Mostrar menos en el seguimiento"], icono = "ic-ventana" }
		-- 1.3.8: la tarjeta de «¡Terminaste!» cerrada: vuelve a pedirla.
		if Rs.FinOculta and Rs.FinOculta() then
			op[#op + 1] = { valor = function() Rs.PedirFin() end, texto = L["¿Qué sigue?"], icono = "ic-ruta" }
		end
		-- 1.3.9: restablecerla (te ubica sola por tu oficio, tu nivel y tus misiones).
		if M.Restablecer then
			op[#op + 1] = { valor = function() M.Restablecer.Restablecer() end, texto = L["Restablecer esta guía"], icono = "ic-ruta" }
			if M.Restablecer.PuedeDeshacer() then
				op[#op + 1] = { valor = function() M.Restablecer.Deshacer() end, texto = L["Deshacer el restablecer"], icono = "ic-cerrar" }
			end
		end
		op[#op + 1] = { separador = true }
	end
	for i, t in ipairs(tabs or {}) do
		op[#op + 1] = { valor = function() if i ~= activa then engine("SelectTab", i) end end,
			texto = (t.title or "?") .. (t.complete and ("  \194\183  " .. L["terminada"]) or ""), icono = i == activa and "ic-huella" or "ic-guia" }
	end
	op[#op + 1] = { valor = function() if M.Biblioteca then M.Biblioteca.Abrir({ pestanaNueva = true }) end end, texto = L["Abrir otra guía..."], icono = "ic-mas" }
	op[#op + 1] = { valor = function() if M.Asistente then M.Asistente.Abrir() end end, texto = L["¿Qué quieres hacer?"], icono = "ic-lobo" }
	op[#op + 1] = { valor = function() M.Cerrar.Ahora() end, texto = L["Cerrar mis misiones"], icono = "ic-misiones" }
	-- 1.4.0 (32): tus guías terminadas, con fecha y tiempo (Historial.lua).
	if M.Historial and #M.Historial.Lista() > 0 then
		op[#op + 1] = { valor = function() M.Historial.Abrir() end, texto = L["Guías terminadas"], icono = "ic-exito" }
	end
	-- 1.3.0: el circuito de la zona y «Llévame a…» (Circuito.lua, Viaje.lua).
	if M.Circuito and A.Get(M.ID .. ".circuito") ~= false then
		op[#op + 1] = { valor = function() M.Circuito.Ahora() end, texto = L["Circuito de la zona"], icono = "ic-ruta" }
	end
	if M.Viaje and A.Get(M.ID .. ".llevame") ~= false then
		op[#op + 1] = { valor = function() M.Viaje.Abrir() end, texto = L["Llévame a..."], icono = "ic-huella" }
	end
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

-- 1.3.8: una meta de élite, de grupo o de mazmorra (la vista del motor o la
-- etiqueta de la misión en el juego: 1 grupo, 62 banda, 81 mazmorra).
local TAGS_GRUPO = { [1] = true, [62] = true, [81] = true }
function Rs.DeGrupo(g)
	if type(g) ~= "table" then return false end
	local p = type(g.party) == "table" and g.party
	if p and (p.kind == "elite" or p.kind == "group") then return true end
	local f = C_QuestLog and C_QuestLog.GetQuestTagInfo
	if type(f) ~= "function" or not tonumber(g.quest) then return false end
	local ok, info = pcall(f, tonumber(g.quest))
	if not (ok and type(info) == "table") then return false end
	if N.Leer(info.isElite) == true then return true end
	local id = tonumber(N.Leer(info.tagID))
	return id ~= nil and TAGS_GRUPO[id] == true
end

-- 1.3.9 (73): el clic derecho de cualquier paso o meta, siempre en el
-- mismo orden: «Llévame», «Omitir», «Ver en el mapa», «Abandonar misión»;
-- debajo, lo demás (marcar, compartir, la cadena...).
local function menuMeta(fila)
	local g, s = fila.alfaMeta, fila.alfaPaso
	if not (g and s) then return end
	local op = {}
	local q = g.quest
	local abierta = g.status ~= "done"
	-- 1. Llévame
	if abierta then
		op[#op + 1] = { valor = function()
			local ok, por, titulo = engine("AimGoal", s, g.index)
			if not ok and por == "accept" and titulo then
				M.Aviso(format(L["Primero toma %s"], M.Citar(titulo)), nil, { icono = "ic-flecha" })
			end
		end, texto = L["Llévame"], icono = "ic-flecha" }
	end
	-- 2. Omitir (la misión, la meta opcional o el paso)
	if q then
		-- 1.3.7: con «Deshacer», igual que omitir un paso (82).
		op[#op + 1] = { valor = function() Rs.OmitirMision(q, g.title or g.text) end, texto = L["Omitir esta misión"], icono = "ic-cerrar" }
	elseif g.optional and abierta then
		op[#op + 1] = { valor = function() engine("SkipGoal", s, g.index) end, texto = L["Omitir esta meta"], icono = "ic-cerrar" }
	elseif abierta and g.t ~= "note" then
		-- Sin misión, «Omitir» deja el paso (con su «Deshacer»).
		op[#op + 1] = { valor = function() Rs.Omitir() end, texto = L["Omitir este paso"], icono = "ic-cerrar" }
	end
	-- 3. Ver en el mapa
	if Rs.VerEnMapa then
		op[#op + 1] = { valor = function() Rs.VerEnMapa() end, texto = L["Ver el camino en el mapa"], icono = "ic-mapa" }
	end
	-- 4. Abandonar misión (con confirmación; EnCurso.lua)
	if q and M.Indice.EnRegistro(q) and M.EnCurso and M.EnCurso.AbandonarMision then
		op[#op + 1] = { valor = function() M.EnCurso.AbandonarMision(q) end, texto = L["Abandonar misión"], icono = "ic-cerrar" }
	end
	local extra = {}
	if g.tickable then
		extra[#extra + 1] = { valor = function() engine("ToggleGoal", s, g.index) end, texto = g.ticked and L["Desmarcar"] or L["Marcar como hecha"], icono = "ic-exito" }
	end
	if q and g.optional and abierta then
		extra[#extra + 1] = { valor = function() engine("SkipGoal", s, g.index) end, texto = L["Omitir esta meta"], icono = "ic-cerrar" }
	end
	-- 1.3.9: que la guía siga desde este paso (con Deshacer).
	if M.Restablecer and s ~= engine("GetLiveStep") then
		extra[#extra + 1] = { valor = function() M.Restablecer.EmpezarDesde(s) end, texto = L["Empezar desde este paso"], icono = "ic-huella" }
	end
	if q then
		-- 1.3.7: en grupo, compartirla con un clic tuyo (107).
		local Gr = M.Grupo
		if Gr and Gr.Compartir and IsInGroup and IsInGroup() then
			extra[#extra + 1] = { valor = function()
				if not Gr.Compartir(q) then M.Aviso(L["No la pude compartir"], L["Solo se comparten las misiones de tu registro que se pueden compartir."], { icono = "ic-info" }) end
			end, texto = L["Compartir con mi grupo"], icono = "ic-manada" }
		end
		-- 1.3.8: de élite, de grupo o de mazmorra: «Busco grupo» a tu manada (La Jauría).
		local Ma = rawget(_G, "AlfaManada")
		if type(Ma) == "table" and type(Ma.BuscoGrupo) == "function" and Rs.DeGrupo(g) then
			local titulo = g.title or M.TituloMision(q)
			extra[#extra + 1] = { valor = function() Ma.BuscoGrupo(titulo, "q") end, texto = L["Busco grupo para esta misión"], icono = "ic-manada" }
		end
		if M.Cerrar.EnPlan(q) then
			extra[#extra + 1] = { valor = function() M.Cerrar.Quitar(q, true) end, texto = L["Quitar de Cerrar mis misiones"], icono = "ic-misiones" }
		else
			extra[#extra + 1] = { valor = function() M.Cerrar.Agregar(q) end, texto = L["Agregar a Cerrar mis misiones"], icono = "ic-misiones" }
		end
		if AlfaEnciclopedia and AlfaEnciclopedia.Abrir then
			extra[#extra + 1] = { valor = function() AlfaEnciclopedia.Abrir("quest", q) end, texto = L["Ver en la Enciclopedia"], icono = "ic-enciclopedia" }
		end
		-- 1.3.0: la cadena completa (Cadena.lua).
		if M.Cadena and A.Get(M.ID .. ".cadenaCompleta") ~= false then
			extra[#extra + 1] = { valor = function() M.Cadena.Abrir(q) end, texto = L["Ver la cadena completa"], icono = "ic-ruta" }
		end
	end
	if #op > 0 and #extra > 0 then op[#op + 1] = { separador = true } end
	for _, o in ipairs(extra) do op[#op + 1] = o end
	if #op == 0 then return end
	K.Menu(fila, op, nil, function(fn) if type(fn) == "function" then fn() end end, 240)
end
Rs.MenuMeta = menuMeta -- (para el banco)

---------------------------------------------------------------------------
-- Piezas que comparten el rastreador y la ventana de detalle: cada una vive
-- en su contexto (cx = { padre, metas, grupos, cerca }) y se reutiliza.
---------------------------------------------------------------------------

local function nuevoCx(padre) return { padre = padre, metas = {}, grupos = {}, cerca = {} } end

-- 1.4.0 (80): cada meta con el ícono de lo que pide (en su ficha redonda):
-- matar, conseguir, tomar, entregar, ir, hablar, usar... Hecha, la palomita.
local ICONO_META = {
	kill = "ic-raros", collect = "ic-bolsas", loot = "ic-bolsas", buy = "ic-oro", accept = "ic-misiones",
	turnin = "ic-misiones", ["goto"] = "ic-cerca", travel = "ic-cerca", fly = "ic-ruta", fpath = "ic-ruta",
	talk = "ic-personaje", interact = "ic-mando", use = "ic-oficios", learn = "ic-talentos", train = "ic-talentos",
	hearth = "ic-hoy", level = "ic-nivel", fish = "ic-pesca", gather = "ic-recoleccion", complete = "ic-misiones",
	rep = "ic-comunidad", wait = "ic-reloj", note = "ic-info", dungeon = "ic-mazmorra",
}
Rs.ICONO_META = ICONO_META
function Rs.IconoMeta(g) return ICONO_META[type(g) == "table" and g.t or ""] or "ic-huella" end

-- 1.4.0 (80): el conteo de una meta («0/7») va aparte, alineado a la
-- derecha. Solo si la línea trae uno (una meta de varios objetivos lleva los
-- suyos en su texto). -> línea sin el conteo, conteo, lleno | línea
local function separarConteo(linea)
	if type(linea) ~= "string" then return linea end
	local s, e, color, cuenta = linea:find("  |c(%x%x%x%x%x%x%x%x)(%d+/%d+)|r")
	if not s or linea:find("%d+/%d+", e + 1) or linea:sub(1, s - 1):find("%d+/%d+") then return linea end
	local a, b = cuenta:match("^(%d+)/(%d+)$")
	local lleno = tonumber(a) and tonumber(b) and tonumber(a) >= tonumber(b)
	return linea:sub(1, s - 1) .. linea:sub(e + 1), cuenta, lleno
end
Rs.SepararConteo = separarConteo -- (para el banco)

local IZQ_META = 26 -- 1.4.0 (80): el texto de una meta, tras su ficha

local function filaMeta(cx, i)
	local f = cx.metas[i]
	if f then return f end
	f = CreateFrame("Button", nil, cx.padre)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f.Marca = CreateFrame("Frame", nil, f)
	f.Marca:SetSize(18, 18)
	f.Marca.caja = K.Caja(f.Marca, { fondo = "acento", alfaFondo = 0.12, borde = "acento", alfaBorde = 0.3, corte = K.CORTE.casilla })
	f.Marca.Ok = K.Icono(f.Marca, "ic-exito", 12, "acento")
	f.Marca.Ok:SetPoint("CENTER")
	f.Barra = K.Plano(f, "acento", "ARTWORK", 2)
	f.Barra:SetWidth(2)
	f.Texto = K.Texto(f, "cuerpo", "texto")
	f.Texto:SetWordWrap(true)
	f.Cuenta = K.Texto(f, "numero", "texto")
	f.Cuenta:SetJustifyH("RIGHT")
	f.Cuenta:SetWordWrap(false)
	f.Sub = K.Texto(f, "pequeno", "textoTenue")
	f.Sub:SetWordWrap(true)
	f.Progreso = K.Progreso(f, { alto = 3 })
	f.velo = K.Velo(f, K.CORTE.control, 0.04)
	f.velo:Hide()
	local function info(self)
		local g = self.alfaMeta
		if self.alfaInfoEncima and g and g.detail and g.detail ~= "" and not Rs.SinTraducir(g.detail) then
			K.MostrarInfo(self, U() and U().PlainGoalText and U().PlainGoalText(g) or "", g.detail)
		end
	end
	f:SetScript("OnEnter", function(self)
		self.velo:Show()
		self.alfaInfoEncima = true
		-- 1.4.0 (80): en el rastreador, al lado y solo si el ratón se queda.
		local demora = K.DemoraInfo and K.DemoraInfo(self)
		if demora then N.Una("rutas.infoMeta", demora, function() info(self) end) else info(self) end
	end)
	f:SetScript("OnLeave", function(self) self.velo:Hide() self.alfaInfoEncima = nil K.OcultarInfo(self) end)
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
	-- 1.4.0 (80): la ficha con el ícono de la meta (hecha: la palomita en verde).
	local tonoMarca = hecha and "exito" or ((actual and not fuera) and "acento" or "textoTenue")
	f.Marca.caja:Estilo({ fondo = tonoMarca, alfaFondo = hecha and 0.18 or (actual and 0.16 or 0.08),
		borde = tonoMarca, alfaBorde = (hecha or actual) and 0.45 or 0.25 })
	K.SetIcono(f.Marca.Ok, hecha and "ic-exito" or Rs.IconoMeta(g), tonoMarca)
	f.Marca.Ok:Show()
	f.Barra:SetShown(actual)
	local linea = u and u.GoalLine and u.GoalLine(g) or (g.text or "")
	-- 1.3.7: lo que da una entrega («+1,250 XP») y si con ella subes (97).
	local xpTexto
	if g.t == "turnin" and g.quest and not hecha and A.Get(M.ID .. ".xpEntrega") ~= false then
		local xp = M.XPMision(g.quest)
		if xp then
			xpTexto = format(L["+%s XP"], M.Miles(xp))
			local x, mx = UnitXP and tonumber(UnitXP("player")) or 0, UnitXPMax and tonumber(UnitXPMax("player")) or 0
			if mx > 0 and xp >= mx - x then xpTexto = xpTexto .. "  \194\183  " .. L["¡Con esta subes de nivel!"] end
		end
	end
	if xpTexto and not conSub then linea = linea .. "  \194\183  " .. xpTexto end
	local tw = ancho - IZQ_META
	-- 1.4.0 (80): el conteo («0/7») a la derecha, en su columna.
	local sinCuenta, cuenta, lleno = separarConteo(linea)
	if cuenta and not hecha then
		linea = sinCuenta
		K.Escribir(f.Cuenta, cuenta)
		K.ColorTexto(f.Cuenta, lleno and "exito" or ((fuera or cx.previa) and "textoTenue" or "texto"))
		f.Cuenta:ClearAllPoints()
		f.Cuenta:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
		f.Cuenta:Show()
		tw = tw - K.AnchoTexto(f.Cuenta) - K.ESP.s
	else
		if cuenta then linea = sinCuenta end
		f.Cuenta:Hide()
	end
	K.Escribir(f.Texto, linea)
	K.ColorTexto(f.Texto, (hecha or fuera or cx.previa or sinTerminar(g)) and "textoTenue" or "texto")
	f.Texto:ClearAllPoints()
	f.Texto:SetPoint("TOPLEFT", f, "TOPLEFT", IZQ_META, -2)
	local h = 2 + K.Parrafo(f.Texto, tw, lineas)
	if u and u.FitCounts then pcall(u.FitCounts, f.Texto) end
	tw = ancho - IZQ_META
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
		-- 1.2.7: una misión gris que vale la pena: por qué (Cadenas.lua).
		if not fuera and g.quest and (g.t == "accept" or g.t == "turnin") and M.GrisValiosa then
			local vale = M.GrisValiosa(g.quest)
			if vale then sub = sub and (sub .. "\n" .. vale) or vale end
		end
		if xpTexto then sub = sub and (sub .. "\n" .. xpTexto) or xpTexto end
	end
	-- 1.4.0 (28): qué recompensa elegir para tu clase (Recompensa.lua); en la
	-- vista compacta también, solo en la meta de ahora.
	if not hecha and not fuera and g.quest and (g.t == "turnin" or g.t == "accept") and M.Recompensa
		and (conSub or actual) then
		local elige = M.Recompensa.Texto(g)
		if elige then sub = sub and (sub .. "\n" .. elige) or elige end
	end
	if sub and sub ~= "" then
		K.Escribir(f.Sub, sub)
		f.Sub:ClearAllPoints()
		f.Sub:SetPoint("TOPLEFT", f, "TOPLEFT", IZQ_META, -(h + 2))
		-- 1.3.7: con «Antes», el lugar y «Vale la pena» juntos ya no se corta
		-- (79): una línea por parte y una de holgura por si alguna se dobla.
		local _, partes = sub:gsub("\n", "")
		h = h + 2 + K.Parrafo(f.Sub, tw, max(3, partes + 2))
		f.Sub:Show()
	else
		f.Sub:Hide()
	end
	local frac = conBarra and not fuera and u and u.GoalBar and u.GoalBar(g)
	if frac and not hecha then
		f.Progreso:ClearAllPoints()
		f.Progreso:SetPoint("TOPLEFT", f, "TOPLEFT", IZQ_META, -(h + 4))
		f.Progreso:Acomodar(tw)
		f.Progreso:Set(frac)
		f.Progreso:Show()
		h = h + 8
	else
		f.Progreso:Hide()
	end
	h = h + 4
	f.Marca:ClearAllPoints()
	f.Marca:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)
	f.Barra:ClearAllPoints()
	f.Barra:SetPoint("TOPLEFT", f, "TOPLEFT", x >= 6 and (1 - x) or -4, -1) -- (en el rastreador, en su borde)
	f.Barra:SetHeight(max(10, h - 4))
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

-- soloCerca (1.3.9, 30): en la vista compacta, solo cuando estás cerca de su
-- objetivo; con tu clic se usa (el seguro del Kit hace clic en el botón del
-- motor, fuera de combate).
local function pintarObjeto(cx, x, y, ancho, soloCerca)
	local o = cx.objeto
	local Q = A.QoL
	local B = Q and Q.Buttons
	local item
	if B and B.ChooseQuestItem then
		local ok, r = pcall(B.ChooseQuestItem)
		if ok then item = r end
	end
	local Ob0 = M.Objeto
	if item and soloCerca and not (Ob0 and Ob0.Cerca and Ob0.Cerca()) then item = nil end
	if not item then
		if o then o:Hide() end
		return y
	end
	if not o then
		o = CreateFrame("Button", nil, cx.padre)
		cx.objeto = o
		o:RegisterForClicks("LeftButtonUp")
		K.Seguro(o, function()
			local b = M.Objeto and M.Objeto.Boton()
			if b and b:IsShown() and b.itemID then return { type = "click", clickbutton = b } end
			return nil
		end)
		o.velo = K.Velo(o, K.CORTE.control, 0.05)
		o.velo:Hide()
		o:SetScript("OnEnter", function(self) self.velo:Show() end)
		o:SetScript("OnLeave", function(self) self.velo:Hide() end)
		o.caja = K.Caja(o, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
		o.Icono = K.IconoObjeto(o, 26)
		o.Icono:SetPoint("LEFT", o, "LEFT", 8, 0)
		o.Nombre = K.Texto(o, "etiqueta", "objeto")
		o.Nombre:SetPoint("TOPLEFT", o, "TOPLEFT", 8 + 26 + 10, -7) -- 1.3.7: desde arriba de la caja (81)
		o.Nombre:SetPoint("RIGHT", o, "RIGHT", -8, 0)
		o.Ayuda = K.Texto(o, "pequeno", "textoTenue")
		o.Ayuda:SetPoint("TOPLEFT", o.Nombre, "BOTTOMLEFT", 0, -2)
		o.Ayuda:SetPoint("RIGHT", o, "RIGHT", -8, 0)
		o:SetHeight(42)
	end
	o.Icono:SetObjeto(item)
	-- 1.3.0: con su avance y la tecla que tiene (ObjetoMision.lua).
	local Ob = M.Objeto
	K.Escribir(o.Nombre, Ob and Ob.Texto(item) or M.NombreObjeto(item))
	local tecla = Ob and Ob.Tecla()
	local pelea = InCombatLockdown and InCombatLockdown()
	if not pelea and Ob and Ob.Cerca and Ob.Cerca() then
		-- 1.3.9 (30): cerca de su objetivo, un clic aquí lo usa.
		K.Escribir(o.Ayuda, tecla and format(L["Estás cerca: clic aquí para usarlo (o %s)."], tecla) or L["Estás cerca: clic aquí para usarlo."])
	else
		K.Escribir(o.Ayuda, tecla and format(L["Objeto de misión: úsalo con su botón o con %s."], tecla)
			or L["Objeto de misión: úsalo con su botón o con tu tecla de paso."])
	end
	o:ClearAllPoints()
	o:SetPoint("TOPLEFT", cx.padre, "TOPLEFT", x, -y)
	o:SetWidth(ancho)
	-- 1.3.7: la caja crece con su texto: en alemán y francés se salía (81).
	local tw = ancho - 8 - 26 - 10 - 8
	local hn = K.Parrafo(o.Nombre, tw, 2)
	local ha = K.Parrafo(o.Ayuda, tw, 3)
	local alto = max(42, 7 + hn + 2 + ha + 7)
	o:SetHeight(alto)
	o:Show()
	return y + alto + K.ESP.s
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
			-- 1.3.7: en el compacto, dos líneas: con un nombre largo ya no se corta (80).
			local h = K.Parrafo(f.Texto, ancho - 18, 2)
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
-- 1.3.7: la distancia y el rumbo hasta la flecha, en un solo lugar (104):
-- el rastreador y Hoy (AlfaRuta.Distancia) dicen lo mismo. «Ya llegaste»
-- cuando la flecha lo dice (su modo de llegada, 103); sin flecha a la vista,
-- por el radio del destino. -> texto, tono, a qué (label) | nil sin flecha
function Rs.Distancia()
	local Nav = A.Nav
	if type(Nav) ~= "table" or type(Nav.GetTarget) ~= "function" then return nil end
	local ok, t = pcall(Nav.GetTarget)
	if not ok or type(t) ~= "table" then return nil end
	local label = type(t.label) == "string" and t.label ~= "" and t.label or nil
	local Cp = A.Compat
	if type(Cp) == "table" then
		if type(Cp.IsInInstance) == "function" and Cp.IsInInstance() then return L["En una instancia: la flecha vuelve al salir"], "neutro", nil end
		if type(Cp.IsOnTaxi) == "function" and Cp.IsOnTaxi() then return L["En vuelo: la flecha sigue al bajar"], "neutro", label end
	end
	local dn, dw
	if type(Nav.TargetOffset) == "function" then
		local ok2, a, b = pcall(Nav.TargetOffset)
		if ok2 then dn, dw = tonumber(a), tonumber(b) end
	end
	if not (dn and dw) then
		local zona = type(Nav.GetTargetZoneName) == "function" and Nav.GetTargetZoneName() or nil
		return type(zona) == "string" and zona ~= "" and format(L["Lejos de aquí: %s"], zona) or L["Lejos de aquí"], "neutro", label
	end
	local d = math.sqrt(dn * dn + dw * dw)
	local area = tonumber(t.area)
	if area and area > 0 then d = d > area and d - area or 0 end
	local flecha = Nav.arrow
	local modo = type(flecha) == "table" and type(flecha.GetMode) == "function" and select(2, pcall(flecha.GetMode)) or nil
	if type(modo) ~= "string" then modo = nil end
	local llego
	if modo then llego = (modo == "arrived" or modo == "search") else llego = d <= (tonumber(t.r) or 8) end
	if llego then return L["Ya llegaste"], "exito", label end
	local txt
	if type(A.FormatDistance) == "function" then
		local ok3, r = pcall(A.FormatDistance, d)
		if ok3 and type(r) == "string" then txt = r end
	end
	-- 1.3.9 (74): y en cuánto llegas, a tu paso (corriendo si estás quieto).
	-- (en mazmorras y en combate la velocidad llega secreta: no se compara)
	local vel = GetUnitSpeed and tonumber(N.Leer((GetUnitSpeed("player")))) or nil
	if not vel or vel < 1 then vel = 7 end
	return (txt or format(L["%d yardas"], floor(d + 0.5))) .. " " .. rumbo(dn, dw), "neutro", label, d / vel -- 1.3.2: traducido
end

-- 1.3.9 (74): un tiempo de camino igual en todo Alfa: «45 s», «1 min 20 s»
-- en los últimos dos minutos y «unos 12 min» antes (N.Duracion redondo),
-- como la flecha.
function Rs.Tiempo(seg)
	seg = tonumber(seg)
	if not seg or seg <= 0 then return nil end
	return N.Duracion(seg, seg >= 120)
end

-- La línea de la flecha: la distancia y el rumbo y, si el camino pasa de un
-- minuto, en cuánto llegas («120 yd al norte · 1 min 20 s»).
local function textoFlecha()
	local t, tono, _, seg = Rs.Distancia()
	if t and tono == "neutro" and seg and seg >= 60 then return t .. "  \194\183  " .. Rs.Tiempo(seg), t, Rs.Tiempo(seg) end
	return t, t, nil
end

-- 1.4.0 (80): la línea de la flecha, discreta: la distancia a la izquierda y
-- el tiempo a la derecha (en su columna, como los conteos). Si no caben
-- juntos, una sola línea con «·».
local function escribirFlecha(fl, completo, dist, tiempo)
	if tiempo then
		K.Escribir(fl.Texto, dist)
		K.Escribir(fl.Tiempo, tiempo)
		fl.Tiempo:Show()
		local libre = K.num(fl:GetWidth(), ANCHO) - IZQ_META - K.AnchoTexto(fl.Tiempo) - K.ESP.s
		if K.AnchoTexto(fl.Texto) <= libre then
			fl.Texto:SetPoint("RIGHT", fl.Tiempo, "LEFT", -K.ESP.s, 0)
			return
		end
	end
	fl.Tiempo:Hide()
	fl.Texto:SetPoint("RIGHT", fl, "RIGHT", 0, 0)
	K.Escribir(fl.Texto, completo)
end

-- Cada segundo, mientras el rastreador compacto se ve: solo el texto; si la
-- línea aparece o se va, se acomoda todo.
local function latido()
	if not (F and F:IsShown() and ui.flecha) then return end
	local t, dist, tiempo
	if ui.conFlecha and (compacto() or Rs.Plegada()) then t, dist, tiempo = textoFlecha() end
	if (t ~= nil) ~= ui.flecha:IsShown() then Rs.Luego() return end
	if t then escribirFlecha(ui.flecha, t, dist, tiempo) end
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

local construirFin -- 1.3.8: la tarjeta del cierre (más abajo, junto a su pintado)

local function construir()
	F = CreateFrame("Frame", "AlfaRastreador", K.Raiz())
	F:SetSize(ANCHO, 200)
	F:SetFrameStrata("MEDIUM")
	F:SetClampedToScreen(true)
	F:SetMovable(true)
	F:EnableMouse(true)
	F.caja = K.Caja(F, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel })
	F.caja:Estilo({ alfaFondo = 0.94 })
	-- 1.4.0 (70): sin la rayita corta de arriba: la cabecera es una banda completa (Banda.lua).
	cxR = nuevoCx(F)
	-- 1.4.0 (80): los globos de ayuda del rastreador (la cabecera, sus botones,
	-- las metas) salen a su lado, nunca encima de la cabecera ni de lo que hay
	-- arriba, y solo si el ratón se queda un momento (Kit/Basicos.lua).
	F.alfaInfoLado = F
	F.alfaInfoDemora = 0.6

	-- Cabecera (se arrastra)
	local c = CreateFrame("Frame", nil, F)
	ui.cab = c
	c:SetPoint("TOPLEFT", F, "TOPLEFT", 0, 0)
	c:SetPoint("TOPRIGHT", F, "TOPRIGHT", 0, 0)
	c:SetHeight(CAB)
	-- 1.4.0 (70): el título y sus datos adentro (sin Banda.lua, la rayita de antes)
	if M.Banda then
		c.Banda = M.Banda(c, K.CORTE.panel)
		c.Banda:Acomodar(CAB)
	else
		F.Marca = K.Marca(F, K.CORTE.panel, "acento", 28)
	end
	c:EnableMouse(true)
	c:RegisterForDrag("LeftButton")
	c:SetScript("OnDragStart", function() c.alfaArrastre = true if not (A.DragLocked and A.DragLocked()) then F:StartMoving() end end)
	c:SetScript("OnDragStop", function() F:StopMovingOrSizing() guardarLugar() end)
	-- 1.3.7c: un clic (sin arrastrar) en la cabecera pliega o despliega la guía.
	c:SetScript("OnMouseDown", function() c.alfaArrastre = false end)
	c:SetScript("OnMouseUp", function(_, boton)
		if boton == "LeftButton" and not c.alfaArrastre then Rs.Plegar(not Rs.Plegada()) end
		c.alfaArrastre = false
	end)
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
	-- El nombre completo de la guía (en la cabecera puede ir cortado) y,
	-- 1.3.7c, el clic para plegarla.
	K.ConInfo(c, function(self)
		return self.alfaNombre or L["Tu guía"], Rs.Plegada() and L["Clic: despliega la guía. Arrastra para moverla."]
			or L["Clic: pliega la guía y deja solo el paso de ahora. Arrastra para moverla."]
	end)
	-- (1.4.0: la línea de abajo es la de la banda, de lado a lado)
	c.Linea = c.Banda and c.Banda.Abajo or K.Linea(c, "linea")
	if not c.Banda then
		c.Linea:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", PAD, 0)
		c.Linea:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -PAD, 0)
	end
	-- 1.3.7c: el avance de la guía en la línea de la cabecera (lo lleno es lo
	-- hecho); 1.4.0 (70): en el borde de abajo de la banda, de lado a lado.
	c.Avance = K.Progreso(c, { alto = 3, tono = "acento" })
	c.Avance:SetPoint("BOTTOMLEFT", c.Banda or c, "BOTTOMLEFT", c.Banda and 0 or PAD, 0)
	c.Avance:SetPoint("BOTTOMRIGHT", c.Banda or c, "BOTTOMRIGHT", c.Banda and 0 or -PAD, 0)
	c.Avance:Hide()
	-- 1.4.0 (80): con la temática por bando, su tira (madera o piedra) bajo la
	-- cabecera, como en las ventanas de Alfa y en los avisos.
	if K.TiraBando then
		c.Tira = K.TiraBando(c, 3, "ARTWORK")
		c.Tira:SetPoint("TOPLEFT", c, "BOTTOMLEFT", 1, 0)
		c.Tira:SetPoint("TOPRIGHT", c, "BOTTOMRIGHT", -1, 0)
	end

	ui.huellas = K.Huellas(F, { tam = 11, max = 16, gap = 4 })

	-- El aviso de arriba
	local b = CreateFrame("Frame", nil, F)
	ui.aviso = b
	b.caja = K.Caja(b, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	b.Barra = K.Progreso(b, { alto = 4, tono = "exito" })
	b.Barra:Hide()
	b.Franja = K.Plano(b, "acento", "ARTWORK", 1)
	b.Franja:SetWidth(2)
	-- 1.4.0 (70): de arriba abajo (antes, corta: 6 px adentro de cada lado),
	-- desde el corte de la esquina.
	b.Franja:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -(K.CORTE.control + 1))
	b.Franja:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
	b.Icono = K.Icono(b, "ic-aviso", 16, "aviso")
	b.Icono:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -10)
	b.Titulo = K.Texto(b, "etiqueta", "texto")
	b.Titulo:SetWordWrap(true)
	b.Texto = K.Texto(b, "pequeno", "textoSuave")
	b.Texto:SetWordWrap(true)
	b.Uno = K.Boton(b, "", nil, { tipo = "acento", tam = "chico" })
	b.Dos = K.Boton(b, "", nil, { tipo = "fantasma", tam = "chico" })
	-- 1.3.8: la X de las sugerencias (d.cerrar); su clic derecho, d.menu.
	-- En combate no toma el ratón (pintarAviso y PLAYER_REGEN_*).
	b.Cerrar = K.BotonIcono(b, "ic-cerrar", function(self, boton)
		local d = b.alfaDatos
		if not d then return end
		if boton == "RightButton" then
			if d.menu then K.Menu(self, d.menu, nil, function(fn) if type(fn) == "function" then fn() end end, 240) end
			return
		end
		if type(d.cerrar) == "function" then d.cerrar() end
		-- 1.4.0: `luego` es local más abajo; aquí era un global nil y la X tronaba.
		if Rs.Luego then Rs.Luego() end
	end, { tam = 18, ayuda = L["Cerrar"], ayudaTexto = L["No te lo vuelvo a sugerir en esta sesión."] })
	b.Cerrar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.Cerrar:SetPoint("TOPRIGHT", b, "TOPRIGHT", -5, -5)
	b.Cerrar:Hide()
	-- El clic derecho en la tarjeta: el mismo menú (solo si trae uno y fuera de combate).
	b:SetScript("OnMouseUp", function(self, boton)
		local d = self.alfaDatos
		if boton == "RightButton" and d and d.menu and not (InCombatLockdown and InCombatLockdown()) then
			K.Menu(self.Cerrar, d.menu, nil, function(fn) if type(fn) == "function" then fn() end end, 240)
		end
	end)
	b:EnableMouse(false)

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

	-- El paso (1.4.0, 80: con su sobretítulo «PASO 4 · AHORA»)
	ui.sobrePaso = K.Texto(F, "mayus", "acento")
	ui.sobrePaso:SetJustifyH("LEFT")
	ui.sobrePaso:SetWordWrap(false)
	ui.sobrePaso:Hide()
	ui.paso = K.Texto(F, "subtitulo", "texto")
	ui.paso:SetWordWrap(true)
	-- 1.3.9 (73): clic derecho en el título del paso: el mismo menú que en sus metas.
	local pc = CreateFrame("Button", nil, F)
	ui.pasoClic = pc
	pc:SetAllPoints(ui.paso)
	pc:RegisterForClicks("RightButtonUp")
	pc:SetScript("OnClick", function(self)
		local v = cxR.vista
		if not (v and ui.paso:IsShown()) then return end
		local g = metasAbiertas(v)[1] or (v.goals or {})[1]
		if not g then return end
		self.alfaMeta, self.alfaPaso = g, v.index
		menuMeta(self)
	end)
	-- 1.3.9 (71): con el ratón encima se ve todo; al irse, solo lo esencial.
	F:HookScript("OnEnter", function() Rs.Encima(true) end)
	F:HookScript("OnLeave", function() Rs.Encima(false) end)
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
	fl.Icono = K.Icono(fl, "ic-flecha", 11, "acento")
	fl.Icono:SetPoint("LEFT", fl, "LEFT", 3, 0)
	fl.Texto = K.Texto(fl, "pequeno", "textoTenue")
	fl.Texto:SetPoint("LEFT", fl, "LEFT", IZQ_META, 0)
	fl.Texto:SetPoint("RIGHT", fl, "RIGHT", 0, 0)
	fl.Texto:SetJustifyH("LEFT")
	fl.Texto:SetWordWrap(false)
	-- 1.4.0 (80): el tiempo, a la derecha (en la columna de los conteos).
	fl.Tiempo = K.Texto(fl, "pequeno", "textoTenue")
	fl.Tiempo:SetPoint("RIGHT", fl, "RIGHT", 0, 0)
	fl.Tiempo:SetJustifyH("RIGHT")
	fl.Tiempo:SetWordWrap(false)
	fl.Tiempo:Hide()
	-- Una línea fina arriba la separa de las metas.
	fl.Linea = K.Linea(fl, "linea")
	fl.Linea:SetPoint("TOPLEFT", fl, "TOPLEFT", 0, 4)
	fl.Linea:SetPoint("TOPRIGHT", fl, "TOPRIGHT", 0, 4)

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

	-- 1.3.8: la tarjeta de «¡Terminaste esta guía!» (Rs.PintarFin).
	construirFin()

	-- El pie
	ui.detalle = K.Boton(F, L["Ver detalle"], function() Rs.AlternarDetalle() end,
		{ tipo = "fantasma", tam = "chico", icono = "ic-lista", ayuda = L["Todas las metas, notas y pasos de esta guía en otra ventana."] })
	ui.omitir = K.Boton(F, L["Omitir"], function() Rs.Omitir() end, { tipo = "fantasma", tam = "chico", ayuda = L["Omite este paso: la guía sigue con el siguiente. Puedes volver a él desde «Ver detalle»."] })
	-- Engine.Next solo deja mirar el paso que sigue (la guía avanza sola).
	ui.siguiente = K.Boton(F, L["Ver el siguiente"], function() engine("Next") end,
		{ tipo = "secundario", tam = "chico", ayuda = L["Solo para mirar: tu paso de ahora no cambia. Alfa avanza sola cuando lo cumples."] })
	ui.pieLinea = K.Linea(F, "linea")

	F:SetScript("OnShow", function()
		Rs.Pintar()
		if not ui.reloj then ui.reloj = N.Ticker("rutas.rastreador", 1, latido) end
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
		local texto = m.complete and L["Terminaste esta guía."] or quedaron(m.undone)
		if m.carried and #m.carried > 0 then
			texto = texto .. " " .. M.Plural(#m.carried, L["Guarda %d misión: la entregas en una guía que sigue."], L["Guarda %d misiones: las entregas en una guía que sigue."])
		end
		-- 1.2.9: sin una que siga en el motor, Alfa propone la siguiente para tu nivel (Siguiente.lua).
		-- 1.3.7: también con pasos sin hacer (la siguiente o «Elegir mi camino», 90).
		local sig = not m.choose and not m.next and M.Siguiente and M.Siguiente.Proponer() or nil
		local uno = (m.choose and L["Elegir mi camino"]) or (m.next and seguirCon(m.nextLabel or nombreGuia(m.next)))
			or (sig and seguirCon(sig.nombre)) or L["Elegir otra guía"]
		-- 1.3.8: el nombre de la que sigue va en el texto: si el botón no cabe, dice «Seguir con la siguiente».
		local cual = (m.next and (m.nextLabel or nombreGuia(m.next))) or (sig and sig.nombre)
		if type(cual) == "string" and cual ~= "" then texto = texto .. " " .. format(L["Lo que sigue para tu nivel: %s."], cual) end
		return { tono = m.complete and "exito" or "acento", icono = m.complete and "ic-exito" or "ic-huella",
			titulo = format(m.complete and L["¡Bien hecho! %s"] or L["Final de %s"], m.label or ""), texto = texto,
			uno = { uno, function()
				est.fin = nil
				if sig then M.Siguiente.Seguir(sig) elseif fin.Empezar then fin.Empezar() end
			end, (m.next or sig) and L["Seguir con la siguiente"] or nil }, -- 1.3.8: el texto corto si no cabe
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
	-- 1.2.8: la vuelta a entregar en curso («Entrega 2 de 4», Vuelta.lua).
	local Vt = M.Vuelta
	if Vt and Vt.Estado() then return Vt.Aviso() end
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
	-- 1.2.9: lo que sigue es de élite o alguien de tu grupo no tiene una
	-- misión tuya (Grupo.lua); en modo foco, eso espera.
	-- 1.3.8: las sugerencias de aquí abajo traen su X (Rs.Sugerencia): cerrada,
	-- no vuelve en la sesión y sale la siguiente.
	if not (M.Foco and M.Foco.Activo()) then
		local d = Rs.Sugerencia(M.Grupo and M.Grupo.Aviso(v, live))
		if d then return d end
	end
	-- 1.4.0: la guía va atrás de tu nivel (MiNivel.lua, 26) y, en una guía de
	-- oficio, lo que te falta para el tramo (Comprar.lua, 31).
	do
		local d = Rs.Sugerencia(M.MiNivel and M.MiNivel.Aviso(v, live) or nil)
		if d then return d end
		d = Rs.Sugerencia(M.Comprar and M.Comprar.Aviso(v, live) or nil)
		if d then return d end
	end
	-- 1.2.8: con 2 o más misiones listas, ofrecer la vuelta a entregar.
	local d = Rs.Sugerencia(Vt and Vt.Aviso() or nil)
	if d then return d end
	-- 1.4.0 (plan 31): en el paso de materiales de una guía de oficio, «Comprar lo que falta».
	d = Rs.Sugerencia(M.OficiosComprar and M.OficiosComprar.Aviso(v, live) or nil)
	if d then return d end
	-- 1.3.8: tu camino pasa por una zona peligrosa (Peligro.lua) y un vuelo
	-- que te ahorra camino (Grifo.lua).
	d = Rs.Sugerencia(M.Peligro and M.Peligro.AvisoCamino and M.Peligro.AvisoCamino() or nil)
	if d then return d end
	d = Rs.Sugerencia(M.Grifo and M.Grifo.Aviso() or nil)
	if d then return d end
	-- 1.2.9: un paso de nivel, claro: lo que falta y dónde rinde más (Nivel.lua).
	d = Rs.Sugerencia(M.Nivel and M.Nivel.Aviso(v, live) or nil)
	if d then return d end
	-- 1.3.7: dentro de una mazmorra, su siguiente jefe y lo que te falta ahí (111).
	return Rs.Sugerencia(Rs.AvisoMazmorra()) or nil
end

-- 1.3.8: una sugerencia del rastreador con su X. La que trae su propio
-- d.cerrar (RutaGrupo, Grifo, Peligro) decide sola; a las demás, la X las
-- calla en la sesión por su clave (d.clave, o el texto de su primer botón,
-- o su título). -> d | false (cerrada: pasa a la siguiente) | nil
local calladas = {}
function Rs.Sugerencia(d)
	if type(d) ~= "table" then return nil end
	if d.cerrar ~= nil then return d end
	local clave = d.clave or (type(d.uno) == "table" and d.uno[1]) or d.titulo
	if clave and calladas[clave] then return false end
	d.cerrar = function() if clave then calladas[clave] = true end end
	return d
end
function Rs.OlvidarCerradas() calladas = {} end -- (para el banco)

-- 1.3.7: AlfaMazmorras.Dentro() (área Mundo), protegido y guardado unos
-- segundos (el rastreador se repinta seguido); nada en combate.
local dentroCache, dentroEn = nil, -1e9
function Rs.AvisoMazmorra()
	local Mz = rawget(_G, "AlfaMazmorras")
	if type(Mz) ~= "table" or type(Mz.Dentro) ~= "function" then return nil end
	local t = GetTime and GetTime() or 0
	if t - dentroEn >= 5 and not (InCombatLockdown and InCombatLockdown()) then
		local ok, r = pcall(Mz.Dentro)
		dentroCache, dentroEn = ok and type(r) == "table" and r or nil, t
	end
	local m = dentroCache
	if not m then return nil end
	local partes = {}
	if m.jefe and m.jefe.nombre then
		partes[#partes + 1] = format(L["Siguiente jefe: %s (%d de %d)"], m.jefe.nombre, (m.jefe.vencidos or 0) + 1, m.jefe.total or 0)
	end
	if (m.faltan or 0) > 0 then partes[#partes + 1] = M.Plural(m.faltan, L["Te falta %d misión aquí"], L["Te faltan %d misiones aquí"]) end
	if #partes == 0 then return nil end
	return { tono = "mazmorra", icono = "ic-mazmorra", titulo = m.nombre or L["Tu mazmorra"], texto = table.concat(partes, "\n"),
		uno = type(m.abrir) == "function" and { L["Ver la mazmorra"], function() pcall(m.abrir) end } or nil }
end

-- El aviso que el rastreador mostraría ahora (para el banco y Hoy, 1.2.9).
function Rs.AvisoDeAhora()
	local g = engine("GetGuide")
	local i = g and engine("GetStepIndex")
	local live = g and engine("GetLiveStep")
	return aviso(i and engine("GetStepView", i), live)
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
	if not d then b.alfaDatos = nil b:Hide() return 0 end
	b.alfaDatos = d
	local relleno = K.Tono(d.tono or "aviso")
	b.caja:Estilo({ borde = relleno, alfaBorde = 0.5 })
	K.ColorPlano(b.Franja, relleno)
	K.SetIcono(b.Icono, d.icono or "ic-aviso", relleno)
	local x = 34
	-- 1.3.8: con la X, el título y el texto dejan su lugar (nunca se enciman).
	local conX = type(d.cerrar) == "function"
	local tw = ancho - x - 10 - (conX and 20 or 0)
	local libre = not (InCombatLockdown and InCombatLockdown())
	b.Cerrar:SetShown(conX)
	b.Cerrar:EnableMouse(conX and libre)
	b:EnableMouse((d.menu ~= nil) and libre)
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
	-- 1.2.9: una barrita (la experiencia de un paso de nivel).
	if d.barra and b.Barra then
		b.Barra:ClearAllPoints()
		b.Barra:SetPoint("TOPLEFT", b, "TOPLEFT", x, -(y + 6))
		b.Barra:Acomodar(tw)
		b.Barra:SetTono(d.tono or "exito")
		b.Barra:Set(d.barra)
		b.Barra:Show()
		y = y + 6 + K.num(b.Barra:GetHeight(), 4)
	elseif b.Barra then
		b.Barra:Hide()
	end
	-- 1.3.8: los botones nunca salen de la tarjeta: el que no cabe baja a otra
	-- fila, y uno solo más ancho («Seguir con <nombre largo>») va en dos renglones.
	local bx, by, alto = x, y + 8, 0
	local bw = ancho - x - 10
	for _, k in ipairs({ "Uno", "Dos" }) do
		local bt, dd = b[k], d[k == "Uno" and "uno" or "dos"]
		if dd then
			bt.alClic = dd[2]
			local h1, w1 = K.BotonQueQuepa(bt, dd[1], dd[3], bw)
			if bx > x and bx + w1 > x + bw then
				by = by + alto + K.ESP.xs
				bx, alto = x, 0
			end
			bt:ClearAllPoints()
			bt:SetPoint("TOPLEFT", b, "TOPLEFT", bx, -by)
			bx = bx + w1 + K.ESP.s
			alto = max(alto, h1)
			bt:Show()
		else
			bt:Hide()
		end
	end
	if d.uno or d.dos then y = by + alto end
	local h = y + 10
	b:SetSize(ancho, h)
	b:Show()
	return h
end

---------------------------------------------------------------------------
-- Pintar el rastreador
---------------------------------------------------------------------------

-- 1.4.0 (25): «12 de 80 pasos · 15 % · ≈ 40 min» (largo) y sin el tiempo
-- (medio). El tiempo sale de tu ritmo (Hora.Estimado: nil hasta que hay 5
-- medidas). Ajuste rutas.avanceTiempo. -> largo, medio | nil
function Rs.AvanceTexto(done, total)
	done, total = M.num(done, 0), M.num(total, 0)
	if total <= 0 or A.Get(M.ID .. ".avanceTiempo") == false then return nil end
	local pct = floor(min(1, max(0, done / total)) * 100 + 0.0001)
	if done < total and pct >= 100 then pct = 99 end
	local medio = format(L["%d de %d pasos  ·  %d %%"], done, total, pct)
	local H = M.Hora
	local m = done < total and H and H.Estimado and H.Estimado() or nil
	if not m then return medio, medio end
	if m >= 60 then m = floor(m / 5 + 0.5) * 5 end
	return medio .. "  \194\183  " .. format(L["≈ %s más"], N.Duracion(m * 60, true)), medio
end

-- El nombre de la guía y "Paso 12 de 80 · 15 %". -> nombre, línea, hechos, total
local function resumenGuia(g, v)
	local u = U()
	local nombre = g and (u and u.GuideLabel and u.GuideLabel(g) or g.title) or L["Alfa"]
	-- Un solo número: los pasos hechos (el número del paso que miras lo dice
	-- la vista previa; "Paso 2" junto a "54 %" se contradecía).
	local done, total = engine("GetProgress")
	local linea = (total and total > 0) and format(L["%d de %d pasos hechos"], done or 0, total) or ""
	-- 1.4.0 (25): el % y lo que te falta por tu ritmo (Hora.lua): «12 de 80
	-- pasos · 15 % · ≈ 40 min». Lo que no quepa se quita (primero el tiempo).
	local base = linea
	local largo, medio = Rs.AvanceTexto(done, total)
	if largo then linea, base = largo, medio end
	-- Tu guarida (1.2.5, La Jauría): «· Guarida Colmillo» al final.
	local Ma = rawget(_G, "AlfaManada")
	local guarida = type(Ma) == "table" and type(Ma.Guarida) == "function" and Ma.Guarida()
	local corta = linea
	if type(guarida) == "string" and guarida ~= "" then
		linea = linea ~= "" and (linea .. "  \194\183  " .. guarida) or guarida
	end
	-- Las que se prueban si no cabe: sin la guarida, sin el tiempo, solo los pasos.
	local cortas = { corta }
	if medio and medio ~= corta then cortas[#cortas + 1] = medio end
	if base ~= corta and base ~= medio then cortas[#cortas + 1] = base end
	return nombre, linea, done, total, corta, cortas
end

local function cabecera(g, v, hecha)
	local c = ui.cab
	local nombre, linea, done, total, corta, cortas = resumenGuia(g, v)
	-- 1.3.8: terminada, la cabecera lo dice (también con su tarjeta cerrada).
	if hecha then
		-- 1.4.0: terminada, sin el % ni el tiempo que falta (solo los pasos).
		local solo = cortas and cortas[#cortas] or corta
		corta = solo ~= "" and (L["Terminada"] .. "  \194\183  " .. solo) or L["Terminada"]
		linea = corta
		cortas = nil
	end
	c.alfaNombre = g and nombre or nil
	linea = linea or ""
	K.Escribir(c.Titulo, nombre or "")
	K.Escribir(c.Sub, linea)
	-- Con la guarida, solo si cabe entera (nada de textos cortados); 1.4.0: y
	-- si aún no cabe, sin el tiempo y luego sin el %.
	local tope = c.alfaAnchoTitulo or (ANCHO - 120)
	for _, otra in ipairs(cortas or { corta }) do
		if K.AnchoTexto(c.Sub) <= tope then break end
		if otra ~= linea then
			linea = otra
			K.Escribir(c.Sub, linea)
		end
	end
	-- 1.3.8: terminada y sin lugar para los pasos: solo «Terminada».
	if hecha and linea ~= L["Terminada"] and K.AnchoTexto(c.Sub) > (c.alfaAnchoTitulo or (ANCHO - 120)) then
		linea = L["Terminada"]
		K.Escribir(c.Sub, linea)
	end
	-- El nombre en hasta dos renglones; la cabecera crece con él.
	local ht = K.Parrafo(c.Titulo, c.alfaAnchoTitulo or (ANCHO - 120), 2)
	local hs = linea ~= "" and K.AltoTexto(c.Sub) or 0
	ui.altoCab = max(CAB, 7 + ht + (hs > 0 and (2 + hs) or 0) + 7)
	c:SetHeight(ui.altoCab)
	if c.Banda then c.Banda:Acomodar(ui.altoCab) end
	if c.Tira then c.Tira:Pintar() end
	-- 1.3.7c: la barra del avance en lugar de la línea, con una guía de pasos.
	local conBarra = c.Avance ~= nil and total ~= nil and total > 0
	if conBarra then c.Avance:Set(done or 0, total) end
	if c.Avance then c.Avance:SetShown(conBarra) end
	c.Linea:SetShown(not conBarra)
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

-- 1.3.7: cómo quedó tu guía cuando ya no tiene un paso para ti, lo mismo en
-- Hoy, la página Ruta y el rastreador (73, 74, 89-91). nil con un paso vivo
-- o sin guía; si no:
--   { id, nombre, terminada, omitidos = n, recuperar = { step, title } | nil,
--     elegir = true (un camino para elegir) | nil, sig = { id, nombre, motor } | nil }
-- `sig` es la que sigue en la ruta del motor (motor = true) o, sin ella, la
-- que propone Alfa para tu nivel (Siguiente.lua).
function Rs.Cierre()
	if engine("GetLiveStep") then return nil end
	local g = engine("GetGuide")
	local pasos = type(g) == "table" and type(g.steps) == "table" and g.steps or nil
	if not pasos or #pasos == 0 then return nil end
	local c = { id = g.id, nombre = nombreGuia(g), terminada = terminada(), omitidos = 0 }
	local primera
	for i = 1, #pasos do
		local v = engine("GetStepView", i)
		if type(v) == "table" and v.status ~= "na" and (v.skipped or v.status ~= "done") then
			c.omitidos = c.omitidos + 1
			if v.skipped and not primera then primera = { step = i, title = v.title } end
		end
	end
	local fuera = engine("SkippedOut")
	c.recuperar = (type(fuera) == "table" and fuera.step and fuera) or primera
	local esp = M.Guias and M.Guias.Especial(g.id)
	if not esp then
		local ch = engine("GetRouteChoice", g.id)
		if type(ch) == "table" and type(ch.options) == "table" and #ch.options >= 2 then
			c.elegir = true
		else
			local nid = engine("NextGuide", g.id)
			if type(nid) == "string" then c.sig = { id = nid, nombre = nombreGuia(nid), motor = true } end
		end
	end
	-- 1.3.9 (revisión): «Cerrar/Entregar mis misiones» terminada con misiones
	-- todavía en tu registro: lo que sigue es cerrarlas, no «¡Terminaste tu
	-- guía! Elige qué sigue» (Toxic lo veía con 13 en su registro).
	if esp == "liberar" then
		-- (revisión 6: solo las que entrarían a un plan; con solo las «Para
		-- después», lo que sigue es la guía de tu nivel)
		local n = M.Cerrar and M.Cerrar.QuedanParaPlan and M.Cerrar.QuedanParaPlan() or 0
		if n > 0 then
			c.cerrar, c.quedan = true, n
			c.sig = { id = "cerrar", nombre = L["Cerrar mis misiones"], cerrar = true }
			return c
		end
	end
	if not c.sig and not c.elegir and esp ~= "desbloquear" and M.Siguiente then c.sig = M.Siguiente.Proponer(g.id) end
	return c
end

-- Las acciones del cierre: seguir con la que sigue, elegir el camino o
-- recuperar lo omitido (el paso vuelve a abrirse y la guía sigue).
function Rs.SeguirCierre(c)
	if not c then return false end
	if c.elegir then engine("OfferRouteChoice") return true end
	if c.cerrar and M.CerrarTodo then return M.CerrarTodo.Abrir({ origen = "fin" }) end
	local s = c.sig
	if not s then A.Fire("SHOW_PICKER") return true end
	if s.motor and engine("StartNext", c.id) then M.Empezar() return true end
	return M.Siguiente and M.Siguiente.Seguir(s)
end

function Rs.Recuperar(c)
	local r = c and c.recuperar
	if not (r and r.step) then return false end
	local ok = engine("Unskip", r.step)
	if ok then
		M.Empezar()
		if M.Aviso then M.Aviso(L["Recuperaste lo omitido"], r.title and M.Citar(r.title) or nil, { icono = "ic-huella" }) end
	end
	return ok and true or false
end

-- El texto del botón grande del cierre.
function Rs.TextoCierre(c)
	if c and c.elegir then return L["Elegir mi camino"] end
	if c and c.cerrar then return M.Plural(c.quedan or 0, L["Cerrar mi misión"], L["Cerrar mis %d misiones"]) end
	if c and c.sig then return seguirCon(c.sig.nombre) end
	return L["Elegir otra guía"]
end

local vacioSig -- el cuadro de «terminaste» con la siguiente guía (1.2.9)
local vacioFalta -- 1.3.7: el cuadro de «no tiene un paso» con su porqué
local function cuadroVacio(g)
	if not g then return VACIO_SIN_GUIA end
	local esp = M.Guias and M.Guias.Especial(g.id)
	if terminada() then
		if esp == "desbloquear" then return VACIO_DESBLOQUEADA end
		-- 1.2.9: con la siguiente para tu nivel a un clic (Siguiente.lua).
		-- 1.3.7: primero la que sigue en tu ruta, o el camino para elegir.
		local c = Rs.Cierre()
		if c and (c.sig or c.elegir) then
			local clave = c.elegir and "elegir" or (c.cerrar and ("cerrar" .. (c.quedan or 0))) or c.sig.id
			if not (vacioSig and vacioSig.alfaId == clave) then
				local txt = c.elegir and L["Tu ruta se abre en dos: elige por dónde sigues."] or format(L["Lo que sigue para tu nivel: %s."], c.sig.nombre or "?")
				-- 1.3.9 (revisión): el plan de misiones cumplido, con las que te quedan.
				if c.cerrar then
					txt = M.Plural(c.quedan or 0, L["Te queda %d misión en tu registro: Alfa arma la ruta para cerrarla."],
						L["Te quedan %d misiones en tu registro: Alfa arma la ruta para cerrarlas."])
				end
				vacioSig = { lobo = "aullando", titulo = c.cerrar and L["¡Plan cumplido!"] or VACIO_HECHA.titulo, alfaId = clave,
					texto = txt,
					accion = { texto = Rs.TextoCierre(c), icono = "ic-ruta", alClic = function() Rs.SeguirCierre(c) end,
						corto = c.sig and not c.cerrar and L["Seguir con la siguiente"] or nil } } -- 1.3.8: el nombre ya va arriba
			end
			return vacioSig
		end
		return VACIO_HECHA
	end
	if esp == "liberar" then return VACIO_PLAN end
	-- 1.3.7: por qué no hay paso, y «Recuperar lo omitido» si lo hay (91).
	local c = Rs.Cierre()
	if c and c.recuperar then
		local clave = tostring(c.recuperar.step)
		if not (vacioFalta and vacioFalta.alfaId == clave) then
			vacioFalta = { lobo = "atento", titulo = VACIO_GUIA.titulo, alfaId = clave,
				texto = c.recuperar.title and format(L["Omitiste «%s» y lo que sigue depende de eso. Recupéralo y la guía sigue."], c.recuperar.title)
					or L["Omitiste pasos y lo que queda depende de ellos. Recupéralos y la guía sigue."],
				accion = { texto = L["Recuperar lo omitido"], icono = "ic-huella", alClic = function() Rs.Recuperar(c) end } }
		end
		return vacioFalta
	end
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

---------------------------------------------------------------------------
-- 1.3.8: la tarjeta de «¡Terminaste esta guía!»
---------------------------------------------------------------------------
-- Antes era el cuadro vacío (K.Vacio) con el nombre de la que sigue dentro
-- del botón: con un nombre largo el botón atravesaba el rastreador, el texto
-- quedaba fuera del fondo y no se podía cerrar. Ahora es una tarjeta propia,
-- toda dentro del rastreador: el lobo aullando, el festejo, la que sigue en
-- una mini tarjeta (su nombre, su zona y sus niveles) con «Seguir» dentro, y
-- su X. Cerrada, el rastreador queda en su cabecera («Terminada · ...») hasta
-- que cambies de guía o pidas «¿Qué sigue?» en su menú. Clic derecho en la X
-- o en la tarjeta: «No enseñar al terminar una guía» (rutas.tarjetaFin).
-- En combate ni la X ni la tarjeta toman el ratón.
A.RegisterDefaults(M.ID, { tarjetaFin = true })

local FIN_LOBO = 44
local FIN_PAD = 12

-- est.finCerrada: la guía cuya tarjeta cerraste; est.finPedida: la que
-- pediste ver con «¿Qué sigue?» (aunque el ajuste la apague).
local function idGuia(g) return type(g) == "table" and g.id or nil end

local function finPermitida(g)
	local id = idGuia(g)
	if not id then return false end
	if est.finPedida == id then return true end
	if est.finCerrada == id then return false end
	return A.Get(M.ID .. ".tarjetaFin") ~= false
end

local function guiaDe(id)
	local G = A.Guides
	if type(id) ~= "string" or not (G and type(G.Get) == "function") then return nil end
	local ok, h = pcall(G.Get, id)
	return ok and type(h) == "table" and h or nil
end

-- «Los Humedales · Niveles 30–33», como en la Biblioteca.
local function metaGuia(h)
	local u = U()
	if type(h) ~= "table" or not (u and type(u.GuideMeta) == "function") then return nil end
	local ok, s = pcall(u.GuideMeta, h)
	return ok and type(s) == "string" and s ~= "" and s or nil
end

-- Lo que dice la tarjeta (la guía ya está terminada). -> d
local function datosFin(g)
	local d = { lobo = "aullando", sobre = L["Guía terminada"], titulo = L["¡Terminaste esta guía!"] }
	local esp = M.Guias and M.Guias.Especial(g.id)
	if esp == "desbloquear" then
		volverDeDesbloquear()
		d.titulo, d.texto = VACIO_DESBLOQUEADA.titulo, VACIO_DESBLOQUEADA.texto
		d.uno = { L["Elegir qué sigue"], function() A.Fire("SHOW_PICKER") end }
		return d
	end
	local c = Rs.Cierre()
	if c and c.cerrar then
		d.titulo = L["¡Plan cumplido!"]
		d.texto = M.Plural(c.quedan or 0, L["Te queda %d misión en tu registro: Alfa arma la ruta para cerrarla."],
			L["Te quedan %d misiones en tu registro: Alfa arma la ruta para cerrarlas."])
		d.uno = { Rs.TextoCierre(c), function() est.finPedida = nil Rs.SeguirCierre(c) end }
	elseif c and c.elegir then
		d.texto = L["Tu ruta se abre en dos: elige por dónde sigues."]
		d.uno = { L["Elegir mi camino"], function() Rs.SeguirCierre(c) end }
	elseif c and c.sig then
		d.texto = L["Buena cacería. Esto es lo que sigue para tu nivel:"]
		local h = guiaDe(c.sig.id)
		local meta = metaGuia(h)
		-- Con su zona y niveles aparte, el nombre va sin «(30–33)».
		d.sig = { nombre = (meta and h.title) or c.sig.nombre or nombreGuia(h) or "?", meta = meta,
			uno = { L["Seguir con esta guía"], function() est.finPedida = nil Rs.SeguirCierre(c) end },
			dos = { L["Elegir otra guía"], function() A.Fire("SHOW_PICKER") end } }
	else
		d.texto = VACIO_HECHA.texto
		d.uno = { L["Elegir qué sigue"], function() A.Fire("SHOW_PICKER") end }
	end
	return d
end

function Rs.CerrarFin()
	est.finCerrada = idGuia(engine("GetGuide")) or true
	est.finPedida = nil
	if F and F:IsShown() then Rs.Pintar() end
end

-- «¿Qué sigue?» del menú: la tarjeta vuelve (aunque el ajuste la apague).
function Rs.PedirFin()
	est.finCerrada = nil
	est.finPedida = idGuia(engine("GetGuide"))
	if F and F:IsShown() then Rs.Pintar() end
end

-- La guía está terminada y su tarjeta no se ve (cerrada o apagada).
function Rs.FinOculta()
	local g = engine("GetGuide")
	if not g or est.fin or finPermitida(g) then return false end
	return terminada()
end

function Rs.FinVisible() return ui.fin ~= nil and ui.fin:IsShown() end

local function menuFin(dueno)
	K.Menu(dueno, {
		{ valor = function() Rs.CerrarFin() end, texto = L["Cerrar"], icono = "ic-cerrar" },
		{ valor = function() A.Set(M.ID .. ".tarjetaFin", false) Rs.CerrarFin() end, texto = L["No enseñar al terminar una guía"] },
	}, nil, function(fn) if type(fn) == "function" then fn() end end, 240)
end
Rs.MenuFin = menuFin

construirFin = function()
	local t = CreateFrame("Frame", nil, F)
	ui.fin = t
	t.caja = K.Caja(t, { fondo = "panel", borde = "acento", corte = K.CORTE.tarjeta })
	t.caja:Estilo({ alfaBorde = 0.5 })
	t.Banda = M.Banda and M.Banda(t, K.CORTE.tarjeta, { alfa = 0.12 }) -- 1.4.0 (70): banda completa con el lobo y el título
	t.Lobo = t:CreateTexture(nil, "ARTWORK")
	t.Lobo:SetSize(FIN_LOBO, FIN_LOBO)
	t.Lobo:SetPoint("TOPLEFT", t, "TOPLEFT", FIN_PAD, -FIN_PAD)
	t.Sobre = K.Texto(t, "mayus", "acento")
	t.Titulo = K.Texto(t, "subtitulo", "texto")
	t.Texto = K.Texto(t, "nota", "textoSuave")
	t.Accion = K.Boton(t, "", nil, { tipo = "acento", tam = "chico", icono = "ic-ruta" }) -- (no «Uno»: así se reconoce el aviso)
	t.Cerrar = K.BotonIcono(t, "ic-cerrar", function(self, boton)
		if boton == "RightButton" then menuFin(self) return end
		Rs.CerrarFin()
	end, { tam = 18, ayuda = L["Cerrar"], ayudaTexto = L["Vuelve al cambiar de guía o con «¿Qué sigue?» en el menú. Clic derecho: más opciones."] })
	t.Cerrar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	t.Cerrar:SetPoint("TOPRIGHT", t, "TOPRIGHT", -5, -5)
	t:SetScript("OnMouseUp", function(self, boton)
		if boton == "RightButton" and not (InCombatLockdown and InCombatLockdown()) then menuFin(self.Cerrar) end
	end)
	-- La que sigue: una mini tarjeta con su nombre, su zona y niveles, y «Seguir».
	local s = CreateFrame("Frame", nil, t)
	t.Sig = s
	s.caja = K.Caja(s, { fondo = "elevado", borde = "linea", corte = K.CORTE.control })
	s.Icono = K.Icono(s, "ic-guia", 16, "acento")
	s.Icono:SetPoint("TOPLEFT", s, "TOPLEFT", 10, -10)
	s.Nombre = K.Texto(s, "etiqueta", "texto")
	s.Meta = K.Texto(s, "pequeno", "textoTenue")
	s.Uno = K.Boton(s, "", nil, { tipo = "primario", tam = "chico", icono = "ic-ruta" })
	s.Dos = K.Boton(s, "", nil, { tipo = "fantasma", tam = "chico" })
	t:Hide()
end

-- Los botones en fila dentro de `w` desde (x, y) de su padre: el que no cabe
-- baja a otra fila; uno solo más ancho que `w` va en dos renglones
-- (K.BotonQueQuepa). Nunca salen de la tarjeta. -> la y de abajo
local function filaBotones(padre, botones, x, y, w)
	local bx, alto = x, 0
	for _, par in ipairs(botones) do
		local b, d = par[1], par[2]
		if d then
			b.alClic = d[2]
			local bh, bw = K.BotonQueQuepa(b, d[1], d[3], w)
			if bx > x and bx + bw > x + w then
				y = y + alto + K.ESP.xs
				bx, alto = x, 0
			end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", padre, "TOPLEFT", bx, -y)
			b:Show()
			bx = bx + bw + K.ESP.s
			alto = max(alto, bh)
		else
			b:Hide()
		end
	end
	return y + alto
end

local function pintarFin(d, ancho)
	local t = ui.fin
	t.alfaDatos = d
	local libre = not (InCombatLockdown and InCombatLockdown())
	t.Cerrar:EnableMouse(libre)
	t:EnableMouse(libre)
	t.Lobo:SetTexture(K.Lobo(d.lobo or "aullando"))
	t.Lobo:SetVertexColor(K.Color("acento"))
	-- La columna del texto, a la derecha del lobo y antes de la X.
	local x = FIN_PAD + FIN_LOBO + K.ESP.m
	local tw = ancho - x - FIN_PAD - 14
	-- 1.4.0 (70): el lobo, lo de arriba y el título juntos en la banda, el
	-- texto centrado con el lobo.
	K.Escribir(t.Sobre, K.Mayus(d.sobre or ""))
	local hs = K.Parrafo(t.Sobre, tw)
	K.Escribir(t.Titulo, d.titulo or "")
	local ht = K.Parrafo(t.Titulo, tw)
	local arriba = FIN_PAD + max(0, floor((FIN_LOBO - (hs + 3 + ht)) / 2))
	t.Sobre:ClearAllPoints()
	t.Sobre:SetPoint("TOPLEFT", t, "TOPLEFT", x, -arriba)
	t.Titulo:ClearAllPoints()
	t.Titulo:SetPoint("TOPLEFT", t, "TOPLEFT", x, -(arriba + hs + 3))
	local y = max(arriba + hs + 3 + ht, FIN_PAD + FIN_LOBO) + FIN_PAD
	if t.Banda then t.Banda:Acomodar(y) end
	if d.texto and d.texto ~= "" then
		K.Escribir(t.Texto, d.texto)
		t.Texto:ClearAllPoints()
		t.Texto:SetPoint("TOPLEFT", t, "TOPLEFT", x, -(y + 4))
		y = y + 4 + K.Parrafo(t.Texto, ancho - x - FIN_PAD)
		t.Texto:Show()
	else
		t.Texto:Hide()
	end
	-- Sin la que sigue, el botón va en la columna del texto.
	if d.uno and not d.sig then
		y = filaBotones(t, { { t.Accion, d.uno } }, x, y + K.ESP.s, ancho - x - FIN_PAD)
	else
		t.Accion:Hide()
	end
	y = max(y, FIN_PAD + FIN_LOBO)
	local s = t.Sig
	if d.sig then
		local sw = ancho - 2 * FIN_PAD
		local sx = 10 + 16 + K.ESP.s
		local stw = sw - sx - 10
		K.Escribir(s.Nombre, d.sig.nombre or "")
		s.Nombre:ClearAllPoints()
		s.Nombre:SetPoint("TOPLEFT", s, "TOPLEFT", sx, -10)
		local sy = 10 + K.Parrafo(s.Nombre, stw)
		if d.sig.meta then
			K.Escribir(s.Meta, d.sig.meta)
			s.Meta:ClearAllPoints()
			s.Meta:SetPoint("TOPLEFT", s, "TOPLEFT", sx, -(sy + 2))
			sy = sy + 2 + K.Parrafo(s.Meta, stw)
			s.Meta:Show()
		else
			s.Meta:Hide()
		end
		sy = filaBotones(s, { { s.Uno, d.sig.uno }, { s.Dos, d.sig.dos } }, sx, sy + K.ESP.s, stw) + 10
		y = y + K.ESP.m
		s:SetSize(sw, sy)
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", t, "TOPLEFT", FIN_PAD, -y)
		s:Show()
		y = y + sy
	else
		s:Hide()
	end
	local h = y + FIN_PAD
	t:SetSize(ancho, h)
	t:Show()
	return h
end

-- 1.3.9 (71): ¿el ratón está sobre el rastreador? Al irse, se espera un
-- momento (pasar del rastreador a uno de sus botones también es «irse»).
local encima = false
function Rs.EstaEncima() return encima end
function Rs.Encima(si)
	if si then
		N.Quitar("rutas.rastreadorEncima")
		if not encima then encima = true if A.Get(M.ID .. ".rastreadorEsencial") ~= false then Rs.Luego() end end
		return
	end
	N.Una("rutas.rastreadorEncima", 0.4, function()
		if F and F:IsShown() and F.IsMouseOver and F:IsMouseOver() then return Rs.Encima(false) end
		if encima then encima = false if A.Get(M.ID .. ".rastreadorEsencial") ~= false then Rs.Luego() end end
	end)
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
	cxR.vista = v
	-- 1.3.9 (71): en la vista compacta, solo lo esencial (el paso, sus metas y
	-- la flecha); el pie, «y N más», «Antes» y «Mientras estás aquí», al
	-- pasar el ratón (rutas.rastreadorEsencial).
	local esencial = comp and A.Get(M.ID .. ".rastreadorEsencial") ~= false and not Rs.EstaEncima()
	if ui.pasoClic then
		ui.pasoClic:EnableMouse(not (InCombatLockdown and InCombatLockdown()))
		ui.pasoClic:SetShown(v ~= nil)
	end
	-- 1.3.8: otra guía: la tarjeta del cierre que cerraste vuelve a valer.
	local gid = idGuia(g)
	if est.finCerrada and est.finCerrada ~= gid then est.finCerrada = nil end
	if est.finPedida and est.finPedida ~= gid then est.finPedida = nil end
	local hecha = g ~= nil and v == nil and terminada()
	local conAvance = cabecera(g, v, hecha)
	local y = (ui.altoCab or CAB) + K.ESP.s
	-- 1.3.7c: plegada, solo el paso de ahora y la flecha.
	if Rs.Plegada() and g and v then
		for _, f in ipairs({ ui.huellas, ui.plan, ui.aviso, ui.vacio, ui.nota, ui.mas, ui.antes, ui.flecha,
			ui.detalle, ui.omitir, ui.siguiente, ui.pieLinea, ui.sobrePaso }) do f:Hide() end
		ocultarPaso(cxR)
		-- La meta de ahora, como en la compacta (con su clic); sin metas, el título.
		local abiertas = metasAbiertas(v)
		if abiertas[1] then
			ui.paso:Hide()
			y = pintarFila(cxR, 1, v, abiertas[1], x, y + 2, ancho, nil, 2, false, true)
		else
			K.Escribir(ui.paso, tituloPaso(v))
			ui.paso:ClearAllPoints()
			ui.paso:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
			ui.paso:Show()
			y = y + K.Parrafo(ui.paso, ancho, 2) + 4
		end
		ui.conFlecha = live ~= nil
		local t, dist, tiempo
		if ui.conFlecha then t, dist, tiempo = textoFlecha() end
		if t then
			ui.flecha:ClearAllPoints()
			ui.flecha:SetPoint("TOPLEFT", F, "TOPLEFT", x, -(y + 8))
			ui.flecha:SetWidth(ancho)
			escribirFlecha(ui.flecha, t, dist, tiempo)
			ui.flecha:Show()
			y = y + 26
		end
		F:SetHeight(y + K.ESP.s)
		return
	end
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
	-- 1.3.8: terminada, la tarjeta propia (o nada, si la cerraste) en vez del cuadro vacío.
	local fin = vacio and not est.fin and hp == 0 and hecha
	local dFin = fin and finPermitida(g) and datosFin(g) or nil
	local conVacio = vacio and not est.fin and hp == 0 and not fin
	if conVacio then ponerVacio(ui.vacio, g) end
	ui.vacio:SetShown(conVacio)
	if not dFin then ui.fin:Hide() end
	-- El aviso
	local h = pintarAviso(aviso(v, live), ancho)
	if h > 0 then
		ui.aviso:ClearAllPoints()
		ui.aviso:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		y = y + h + K.ESP.m
	end
	ui.paso:SetShown(not vacio)
	ui.sobrePaso:SetShown(not vacio)
	ui.nota:Hide()
	ui.mas:Hide()
	ui.flecha:Hide()
	ui.conFlecha = false
	ui.antes:Hide()
	if not vacio then
		-- 1.4.0 (80): «PASO 4 · AHORA» (o «solo mirando») sobre el paso, que va grande.
		local num = numeroPaso(v.index)
		K.Escribir(ui.sobrePaso, K.Mayus(previa and format(L["Paso %d · solo mirando"], num) or format(L["Paso %d · ahora"], num)))
		ui.sobrePaso:ClearAllPoints()
		ui.sobrePaso:SetPoint("TOPLEFT", F, "TOPLEFT", x, -(y + 2))
		ui.sobrePaso:SetWidth(ancho)
		y = y + 16
		K.Escribir(ui.paso, tituloPaso(v))
		ui.paso:ClearAllPoints()
		ui.paso:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		y = y + K.Parrafo(ui.paso, ancho, 2) + 4
		if comp then
			y = y + 2
			local resto, antes
			y, resto, antes = pintarMetasCompacto(cxR, v, x, y, ancho)
			if resto > 0 and not esencial then
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
			local t, dist, tiempo
			if ui.conFlecha then t, dist, tiempo = textoFlecha() end
			if t then
				ui.flecha:ClearAllPoints()
				ui.flecha:SetPoint("TOPLEFT", F, "TOPLEFT", x, -(y + 8))
				ui.flecha:SetWidth(ancho)
				escribirFlecha(ui.flecha, t, dist, tiempo)
				ui.flecha:Show()
				y = y + 26
			end
			-- 1.3.9 (30): el objeto de misión, cuando estás cerca de su objetivo.
			local yo = pintarObjeto(cxR, x, y + 2, ancho, true)
			if yo ~= y + 2 then y = yo end
			-- Una sola línea de contexto: lo que la ruta agregó antes, o
			-- lo que hay cerca.
			if esencial then
				pintarCerca(cxR, x, y, ancho, 0, false)
			elseif antes then
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
	if dFin then
		y = y + K.ESP.xs
		local fh = pintarFin(dFin, ancho)
		ui.fin:ClearAllPoints()
		ui.fin:SetPoint("TOPLEFT", F, "TOPLEFT", x, -y)
		y = y + fh + K.ESP.s
	end
	-- Cerrada la tarjeta y sin nada más: solo la cabecera.
	if fin and not dFin and h == 0 then
		for _, b in ipairs({ ui.detalle, ui.omitir, ui.siguiente, ui.pieLinea }) do b:Hide() end
		F:SetHeight(ui.altoCab or CAB)
		return
	end
	-- El pie: Ver detalle · Omitir · Siguiente
	local conPie = not vacio and not esencial
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
		alClic = function(i, _, boton)
			-- 1.3.9: clic derecho: «Empezar desde este paso» y «Restablecer esta guía».
			if boton == "RightButton" then
				if M.Restablecer then
					local fila = dui.lista
					K.Menu(fila, M.Restablecer.Opciones(i), nil, function(fn) if type(fn) == "function" then fn() end end, 260)
				end
				return
			end
			engine("Goto", i)
			dvista = "paso"
			dui.seg:SetValor("paso")
			Rs.PintarDetalle()
		end,
		elegir = false,
	})
	-- El pie: Anterior a la izquierda; Omitir y Siguiente a la derecha.
	dui.atras = K.Boton(D, L["Anterior"], function() engine("Prev") end, { tipo = "fantasma", tam = "chico" })
	dui.omitir = K.Boton(D, L["Omitir"], function() Rs.Omitir() end, { tipo = "fantasma", tam = "chico", ayuda = L["Omite este paso: la guía sigue con el siguiente. Puedes volver a él con Anterior."] })
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
-- 1.3.8 (para el banco): la tarjeta del cierre, el aviso y los cuadros vacíos.
function Rs.Piezas() return { fin = ui.fin, aviso = ui.aviso, vacio = ui.vacio, vacioDetalle = dui.vacio, cab = ui.cab } end

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
			local sig = not m.next and not m.choose and M.Siguiente and M.Siguiente.Proponer() or nil
			local uno = (m.next and seguirCon(m.nextLabel or nombreGuia(m.next))) or (sig and seguirCon(sig.nombre)) or L["¿Qué sigue?"]
			K.Aviso({ lobo = "aullando", titulo = format(L["¡Bien hecho! %s"], m.label or ""), texto = L["Terminaste esta guía."],
				duracion = 12, accion = { texto = uno, alClic = function()
					est.fin = nil
					if sig then M.Siguiente.Seguir(sig) elseif p.Empezar then p.Empezar() else M.Empezar() end
				end } })
		else
			K.Aviso({ lobo = "atento", titulo = format(L["Final de %s"], m.label or ""),
				texto = quedaron(m.undone),
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
-- 1.3.8: en combate, la X y la tarjeta no toman el ratón.
A.RegisterEvent("PLAYER_REGEN_DISABLED", function()
	local b = ui.aviso
	if b then b.Cerrar:EnableMouse(false) b:EnableMouse(false) end
	local t = ui.fin
	if t then t.Cerrar:EnableMouse(false) t:EnableMouse(false) end
end)
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
M.Escuchar("VUELTA", luego)

function Rs.Visible() return F ~= nil and F:IsShown() end
function Rs.Mostrar() A.Set("ui.shown", true) end
