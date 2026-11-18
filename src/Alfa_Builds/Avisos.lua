-- Alfa - Builds: las ventanas y avisos del motor que toma Talentos (toxic3000 / La Jauría). GPL-3.0.
--
-- Reemplazos (docs/KIT.md, "Reemplazos"):
--   SHOW_TALENTS  la sección de talentos del motor: abre la página Talentos de Alfa.
--   SPELL_CARDS   los avisos de hechizos nuevos al subir de nivel y de rangos
--                 viejos en tus barras: un aviso del Kit que dice qué aprender,
--                 cuánto cuesta y con qué entrenador, con «Llévame».
--   CLASS_CARD    la tarjeta de misión de clase de la ventana de guía: un aviso
--                 del Kit (una vez por misión y por etapa) con lo que te enseña,
--                 quién te la da y «Llévame».
-- El motor sigue decidiendo cuándo y cuál; aquí solo se dice con las frases de
-- Alfa. Un aviso de SPELL_CARDS que se va (lo cierras, vence o lo usas) le
-- avisa al motor (pedido.Cerrar) para que pase el siguiente.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit

local format, max, concat = string.format, math.max, table.concat

local function nombreHechizo(id)
	return M.Arbol.Nombre(id) or ("#" .. tostring(id))
end

-- "Golpe heroico, Rugido de batalla y 2 más"
local function listaDeNombres(nombres, cuantos)
	cuantos = cuantos or 2
	if #nombres == 0 then return "" end
	if #nombres == 1 then return nombres[1] end
	if #nombres <= cuantos then
		return format(L["%s y %s"], concat(nombres, ", ", 1, #nombres - 1), nombres[#nombres])
	end
	return format(L["%s y %d más"], concat(nombres, ", ", 1, cuantos), #nombres - cuantos)
end

---------------------------------------------------------------------------
-- SHOW_TALENTS
---------------------------------------------------------------------------

N.Reemplazar("SHOW_TALENTS", function()
	AlfaBuilds.Abrir()
end, function() return M.Pagina.Visible() end)

---------------------------------------------------------------------------
-- SPELL_CARDS
---------------------------------------------------------------------------

local tarjeta -- { aviso, turno, cerrar }

-- El aviso se fue: el motor deja pasar el siguiente.
local function soltar()
	local t = tarjeta
	tarjeta = nil
	if t and t.cerrar then K.Llamar(t.cerrar) end
end

-- a:Cerrar(turno) es la función del aviso del Kit (su X es a.BotonCerrar):
-- solo lo cierra si sigue mostrando este mensaje.
local function quitarAviso(t)
	local a = t and t.aviso
	if a and a.alfaVivo and type(a.Cerrar) == "function" then a:Cerrar(t.turno) end
end

local function vigilar(a, duracion)
	if not a.alfaBuildsGancho then
		a.alfaBuildsGancho = true
		a:HookScript("OnHide", function(self)
			local t = tarjeta
			if t and t.aviso == self and t.turno == self.alfaTurno then soltar() end
		end)
	end
	-- Si otro aviso tomó su lugar (hay tres a la vez), también se fue.
	local t = tarjeta
	A.After((duracion or 20) + 3, function()
		if tarjeta == t and t and t.aviso and (not t.aviso.alfaVivo or t.aviso.alfaTurno ~= t.turno) then soltar() end
	end)
end

-- Dónde entrenar, como lo dice el motor (Engine.TrainingAdvice).
local function dondeEntrenar()
	local E = A.Engine
	local ok, adv = pcall(function() return E and E.TrainingAdvice and E.TrainingAdvice() end)
	adv = ok and type(adv) == "table" and adv or {}
	if adv.guide then
		if (adv.steps or 0) <= 1 then return L["Tu guía te lleva a entrenar en este paso."], false end
		return format(L["Tu guía te lleva a entrenar en %d pasos."], adv.steps), false
	end
	local t = adv.trainer
	if t and t.npcName then
		local zona = t.map and A.Compat.GetMapName and A.Compat.GetMapName(t.map)
		return zona and format(L["Entrenador: %s, en %s."], t.npcName, zona) or format(L["Entrenador: %s."], t.npcName), true
	end
	return L["Apréndelos con el entrenador de tu clase, en cualquier capital."], false
end

local function avisoHechizos(p)
	local m = p.modelo or {}
	local nombres, costo = {}, 0
	for _, s in ipairs(m.spells or {}) do
		local n = nombreHechizo(s.id)
		if s.rank then n = format(L["%s (rango %d)"], n, s.rank) end
		nombres[#nombres + 1] = n
		costo = costo + (s.cost or 0)
	end
	local cuantos = #nombres
	-- El nivel del aviso (el motor lo trae en su cabecera); si no, el tuyo.
	local nv = tonumber(tostring(m.head or ""):match("(%d+)")) or A.Compat.Readable(UnitLevel("player")) or 1
	local titulo = cuantos == 1 and format(L["Nivel %d: un hechizo nuevo para aprender"], nv)
		or format(L["Nivel %d: %d hechizos nuevos para aprender"], nv, cuantos)
	local donde, llevar = dondeEntrenar()
	local partes = { listaDeNombres(nombres) .. ".", donde }
	if costo > 0 then
		local dinero = A.Compat.Readable(GetMoney and GetMoney()) or 0
		partes[#partes + 1] = dinero >= costo and format(L["Cuestan %s: te alcanza."], N.Dinero(costo, true))
			or format(L["Cuestan %s; llevas %s."], N.Dinero(costo, true), N.Dinero(dinero, true))
	end
	local accion
	if m.act and not m.noAct and llevar then
		accion = { texto = L["Llévame"], alClic = function() if p.Actuar then p.Actuar() end end }
	end
	return { titulo = titulo, texto = concat(partes, " "), icono = "ic-nivel", tono = "acento", duracion = m.hideAfter or 20, accion = accion },
		m.spells and m.spells[1] and A.Compat.SpellIcon(m.spells[1].id) or nil
end

local function avisoRangos(p)
	local m = p.modelo or {}
	local nombres = {}
	for _, s in ipairs(m.spells or {}) do nombres[#nombres + 1] = nombreHechizo(s.bestId or s.id) end
	local cuantos = #nombres
	local titulo = cuantos == 1 and L["Un hechizo de tus barras tiene un rango viejo"]
		or format(L["%d hechizos de tus barras tienen un rango viejo"], cuantos)
	local texto = listaDeNombres(nombres, 3) .. ". " .. L["Alfa los cambia por el rango nuevo sin moverlos de lugar."]
	return { titulo = titulo, texto = texto, icono = "ic-nivel", tono = "acento", duracion = 20,
		accion = m.act and { texto = L["Actualizar mis barras"], alClic = function() if p.Actuar then p.Actuar() end end } or nil },
		m.spells and m.spells[1] and A.Compat.SpellIcon(m.spells[1].bestId or m.spells[1].id) or nil
end

N.Reemplazar("SPELL_CARDS", function(p)
	if p.accion == "ocultar" then
		local t = tarjeta
		tarjeta = nil
		quitarAviso(t)
		return
	end
	-- Uno nuevo reemplaza al de antes (el motor ya lo dio por cerrado).
	if tarjeta then
		local t = tarjeta
		tarjeta = nil
		quitarAviso(t)
	end
	local m = p.modelo or {}
	local datos, tex
	if m.kind == "oldRanks" then datos, tex = avisoRangos(p) else datos, tex = avisoHechizos(p) end
	local a = K.Aviso(datos)
	M.IconoEnAviso(a, tex)
	tarjeta = { aviso = a, turno = a.alfaTurno, cerrar = p.Cerrar }
	vigilar(a, datos.duracion)
end)

---------------------------------------------------------------------------
-- CLASS_CARD
---------------------------------------------------------------------------

local vistas = {} -- guía:misión -> etapa ya avisada ("aceptar" | "tomada")

local function llevarA(goal, quien)
	local Nv = A.Nav
	if not (goal and goal.map and goal.x and goal.y and Nv and Nv.SetTarget) then return end
	local t = Nv.SetTarget(goal.map, goal.x, goal.y, quien or L["Misión de clase"], goal.f, nil, goal.z)
	if t and Nv.StartTrip then Nv.StartTrip(t, nil, L["Misión de clase"]) end
	if t and N.EmpezarRuta then N.EmpezarRuta() end -- cierra las ventanas de Alfa y muestra el seguimiento
end

N.Reemplazar("CLASS_CARD", function(p)
	local m = p.modelo
	if not m then return end
	local clave = tostring(p.guia and p.guia.id) .. ":" .. tostring(m.mision)
	local etapa = m.tomada and "tomada" or "aceptar"
	if vistas[clave] == etapa then return end
	vistas[clave] = etapa
	-- Lo que enseña o da la cadena.
	local CC = A.UI and A.UI.ClassCard
	local premio, aprende
	if CC and CC.RewardName and m.recompensa then premio, aprende = CC.RewardName(m.recompensa) end
	local partes = {}
	if premio then partes[#partes + 1] = aprende and format(L["Te enseña %s."], premio) or format(L["Te da %s."], premio) end
	-- Quién te la da (la meta de aceptar del paso).
	local step = p.guia and p.guia.steps and p.guia.steps[p.indice]
	local goal = step and m.aceptar and step.goals[m.aceptar] or nil
	local quien
	if goal then
		local Nm = A.Names
		quien = (Nm and Nm.Npc and goal.npc and Nm.Npc(goal.npc)) or goal.npcName or goal.objName
	end
	local accion
	if m.tomada then
		partes[#partes + 1] = m.entregaA and format(L["Ya la tienes: entrégala a %s."], m.entregaA) or L["Ya la tienes: tu guía te lleva a entregarla."]
	else
		local zona = goal and goal.map and A.UI and A.UI.MapName and A.UI.MapName(goal.map)
		if quien then
			partes[#partes + 1] = zona and format(L["Te la da %s, en %s."], quien, zona) or format(L["Te la da %s."], quien)
		else
			partes[#partes + 1] = L["Tu guía te lleva a tomarla."]
		end
		if goal and goal.map and goal.x then
			accion = { texto = L["Llévame"], alClic = function() llevarA(goal, quien) end }
		end
	end
	local a = K.Aviso({
		titulo = format(L["Misión de clase: %s"], m.titulo or ""), texto = concat(partes, " "),
		icono = "ic-misiones", tono = "clase", duracion = 12, accion = accion,
	})
	M.IconoEnAviso(a, m.icono)
end)
