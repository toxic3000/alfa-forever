-- Alfa - Mazmorras: qué misiones de una mazmorra puedes tomar ya y qué le
-- falta a cada una de las demás (toxic3000 / La Jauría). GPL-3.0.
--
-- La regla (docs/PLAN-1.0.md, "Pedidos agregados"): Alfa nunca te manda a una
-- misión que todavía no puedes tomar. «Prepárame» recoge solo las que ya
-- puedes tomar y dice qué les falta a las otras.
--
-- El motor arma el plan (Dungeons.PickupPlan con la regla de la tarjeta de
-- mazmorra: una misión se ofrece desde un nivel debajo del suyo, nunca debajo
-- del que pide el juego) y la guía que las recoge (Dungeons.PickUp con la
-- misma regla); aquí se revisa ese plan una vez más: una misión cuya cadena
-- pasa por una previa de un nivel que aún no tienes espera, con su porqué.
--
--   P.Estado(key) -> e      (en caché hasta que cambie tu registro o tu nivel)
--     e.recoger  = { t, ... }    las que se recogen ahora (t del plan: quest, rec, giver, pre)
--     e.esperan  = { { q, nivel, previa }, ... }   esperan tu nivel o una previa
--     e.listas   = n             en tu registro, listas para entregar fuera
--     e.llevas   = n             de sus misiones en tu registro
--     e.lista    = { fila, ... } todas las tuyas, para la pestaña Misiones:
--        fila = { q, grupo, estado, texto, tono, nivel, llevame = punto | nil, etiqueta }
--        grupo: "recoger" | "registro" | "despues" | "otras" | "hechas"
--   P.Frase(e) -> texto      lo que hará «Prepárame», en una o dos frases
--   P.Preparar(key) -> true  recoge lo que puedes tomar y te lleva a la entrada
--   P.Entregar(key) -> true  la guía para entregar lo que terminaste
--   P.Entrada(key) -> true   solo la flecha a la entrada

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local D = M.D

local type, ipairs, pairs, tostring, format, concat = type, ipairs, pairs, tostring, string.format, table.concat
local max = math.max

local P = {}
M.P = P

local llamar = D.Llamar

local function Dg() return A.Dungeons end

local function hecha(id)
	local C = A.Compat
	return C and llamar(C.IsQuestCompleted, id) == true or false
end

local function enRegistro(id)
	local C = A.Compat
	return C and llamar(C.IsOnQuest, id) == true or false
end

-- «Título» con las comillas del motor (o las nuestras).
local function citar(t)
	if type(t) ~= "string" or t == "" then return "" end
	local q = A.Quoted and llamar(A.Quoted, t)
	return type(q) == "string" and q or ("\194\171" .. t .. "\194\187")
end
P.Citar = citar

-- Una lista de títulos: «A», «B» y «C».
local function titulos(lista)
	local t = {}
	for i, q in ipairs(lista) do t[i] = citar(q.title) end
	if #t <= 1 then return t[1] or "" end
	return format(L["%s y %s"], concat(t, ", ", 1, #t - 1), t[#t])
end

---------------------------------------------------------------------------
-- La caché: se olvida al tomar, entregar o abandonar una misión y al subir
-- de nivel (la página se repinta sola por esos mismos eventos).
---------------------------------------------------------------------------
local cache = {}
function P.Olvidar() cache = {} end
for _, ev in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "QUEST_LOG_UPDATE" }) do
	A.RegisterEvent(ev, function() P.Olvidar() end)
end
A.On("CODEX_LOADED", function() P.Olvidar() end)
A.On("NAMES_LOADED", function() P.Olvidar() end)

---------------------------------------------------------------------------
-- Para quién es una misión (clase, raza)
---------------------------------------------------------------------------
local function nombreClase(c)
	local t = LOCALIZED_CLASS_NAMES_MALE
	return type(t) == "table" and t[c] or c
end

local function soloPara(who)
	if type(who) ~= "table" then return nil end
	if type(who.classes) == "table" and #who.classes > 0 then
		local t = {}
		for i, c in ipairs(who.classes) do t[i] = nombreClase(c) end
		return format(L["Solo para %s."], concat(t, ", "))
	end
	return L["Es para otra raza."]
end

-- Dónde empieza una misión que no se recoge afuera.
local function empiezaDentro(q)
	local s = q.start
	if q.inside or (type(s) == "table" and s.inside) then return true end
	return false
end

-- Cerrada para siempre: una de las que la cierran (su grupo excluyente, la
-- misión a la que lleva) ya está hecha o en tu registro.
local function cerrada(q)
	for _, id in ipairs(type(q.closedBy) == "table" and q.closedBy or {}) do
		if hecha(id) or enRegistro(id) then return true end
	end
	return false
end

-- La primera misión de su cadena que todavía no haces.
local function primeraPendiente(key, q)
	local Dgx = Dg()
	for _, id in ipairs(type(q.chain) == "table" and q.chain or {}) do
		if not hecha(id) and not enRegistro(id) then
			local cq = Dgx.Quest and llamar(Dgx.Quest, key, id)
			return cq
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- El estado de una mazmorra
---------------------------------------------------------------------------
function P.Estado(key)
	if type(key) ~= "string" then return nil end
	local e = cache[key]
	if e then return e end
	local Dgx = Dg()
	e = { key = key, recoger = {}, esperan = {}, listas = 0, llevas = 0, lista = {}, camino = {} }
	if not (Dgx and Dgx.Quests) then
		cache[key] = e
		return e
	end
	local nivel, lado = D.Nivel(), D.Lado()
	local plan = Dgx.PickupPlan and llamar(Dgx.PickupPlan, key, true) or nil
	local entrega = Dgx.HandinPlan and llamar(Dgx.HandinPlan, key) or nil
	e.plan = type(plan) == "table" and plan or nil
	e.entrega = type(entrega) == "table" and entrega or nil

	-- Lo que el plan recoge ahora, revisado: la misión y cada previa de su
	-- cadena, de tu nivel (una en tu registro ya la tienes).
	local porId = {}
	for _, t in ipairs(e.plan and e.plan.take or {}) do
		local q = t.quest
		local espera
		local lvl = (t.rec and t.rec.minLevel) or q.minLevel or 1
		if lvl > nivel then espera = { q = q, nivel = lvl } end
		for _, r in ipairs(t.pre or {}) do
			if not espera and (r.minLevel or 1) > nivel and not enRegistro(r.id) then
				espera = { q = q, nivel = r.minLevel, previa = r }
			end
		end
		if espera then
			e.esperan[#e.esperan + 1] = espera
			porId[q.id] = { espera = espera }
		else
			e.recoger[#e.recoger + 1] = t
			porId[q.id] = { toma = t }
			for _, r in ipairs(t.pre or {}) do e.camino[r.id] = q end
		end
	end
	for _, w in ipairs(e.plan and e.plan.waiting or {}) do
		local espera = { q = w.quest, nivel = w.level, previa = w.needs }
		e.esperan[#e.esperan + 1] = espera
		porId[w.quest.id] = porId[w.quest.id] or { espera = espera }
	end
	local listas, dentro = {}, {}
	for _, h in ipairs(e.entrega and e.entrega.hand or {}) do listas[h.quest.id] = h end
	for _, q in ipairs(e.entrega and e.entrega.inside or {}) do dentro[q.id] = true end

	-- Cada misión tuya, con su estado y lo que le falta.
	for _, q in ipairs(llamar(Dgx.Quests, key, lado) or {}) do
		local f = { q = q, nivel = q.level }
		local who, why
		if Dgx.QuestFor then who, why = llamar(Dgx.QuestFor, q) end
		local p = porId[q.id]
		if hecha(q.id) then
			f.grupo, f.estado, f.tono = "hechas", L["Hecha"], "exito"
		elseif enRegistro(q.id) then
			e.llevas = e.llevas + 1
			f.grupo = "registro"
			local h = listas[q.id]
			if h then
				e.listas = e.listas + 1
				f.estado, f.tono, f.orden = L["Lista para entregar"], "exito", 1
				local quien = h.ender and h.ender.name
				f.texto = quien and format(L["Entrégala a %s."], quien) or L["Ya puedes entregarla."]
				f.llevame, f.etiqueta = h.ender, quien
			elseif dentro[q.id] then
				f.estado, f.tono, f.orden = L["Se entrega dentro"], "mazmorra", 2
				f.texto = L["Ya la terminaste: entrégala dentro de la mazmorra."]
			else
				f.estado, f.tono, f.orden = L["En curso"], "acento", 3
				f.texto = Dgx.ObjectiveText and llamar(Dgx.ObjectiveText, q) or nil
			end
		elseif p and p.toma then
			local t = p.toma
			f.grupo, f.estado, f.tono, f.orden = "recoger", L["La recoges ahora"], "acento", 1
			local g = t.giver
			local partes = {}
			if g and g.kind == "drop" then
				partes[1] = format(L["Empieza con %s, que suelta %s."], g.itemName or L["un objeto"], g.name or "?")
			elseif g and g.name then
				partes[1] = format(L["Te la da %s."], g.name)
			end
			if #(t.pre or {}) > 0 then partes[#partes + 1] = format(L["Antes: %s."], titulos(t.pre)) end
			f.texto = concat(partes, " ")
			f.llevame, f.etiqueta = g and g.kind ~= "drop" and g or nil, g and g.name
		elseif e.camino[q.id] then
			f.grupo, f.estado, f.tono, f.orden = "recoger", L["En el camino"], "acento", 2
			f.texto = format(L["La haces de paso: abre %s."], citar(e.camino[q.id].title))
		elseif p and p.espera then
			local w = p.espera
			f.grupo, f.tono, f.orden = "despues", "aviso", 1
			if w.previa then
				f.estado = format(L["Espera · nivel %d"], w.nivel or 0)
				f.texto = format(L["Primero necesitas %s, que se toma a nivel %d."], citar(w.previa.title), w.previa.minLevel or w.nivel or 0)
			else
				f.estado = format(L["Desde nivel %d"], w.nivel or 0)
				f.texto = w.nivel and w.nivel > nivel and format(L["Te faltan %d niveles para tomarla."], w.nivel - nivel) or nil
			end
		elseif cerrada(q) then
			f.grupo, f.estado, f.tono = "otras", L["Ya no aplica"], "neutro"
			f.texto = L["Tomaste otra misión de su grupo: esta ya no se abre."]
		elseif why == "class" or why == "race" then
			f.grupo, f.estado, f.tono = "otras", L["No es para ti"], "neutro"
			f.texto = soloPara(who)
		elseif empiezaDentro(q) then
			f.grupo, f.estado, f.tono, f.orden = "despues", L["Empieza dentro"], "mazmorra", 2
			f.texto = L["Se toma dentro de la mazmorra: ahí la verás."]
		elseif q.startItem then
			f.grupo, f.estado, f.tono, f.orden = "despues", L["La empieza un objeto"], "mazmorra", 3
			f.texto = format(L["Empieza con %s, que se consigue en la mazmorra."], (q.startItem and q.startItem.name) or L["un objeto"])
		else
			local previa = primeraPendiente(key, q)
			f.grupo, f.tono, f.orden = "despues", "neutro", 4
			if previa then
				f.estado = L["Después de otra"]
				f.texto = format(L["Se abre al terminar %s."], citar(previa.title))
			else
				f.estado = L["Todavía no"]
				f.texto = L["Todavía no se puede tomar: Alfa la recoge cuando se abra."]
			end
		end
		e.lista[#e.lista + 1] = f
	end
	cache[key] = e
	return e
end

---------------------------------------------------------------------------
-- Lo que hará «Prepárame», en palabras
---------------------------------------------------------------------------
local function cuantas(n, una, varias) return n == 1 and una or format(varias, n) end

-- Lo que esperan las demás, en corto: "2 esperan: «A» (nivel 25) y «B» (antes «C»)."
local function frasesEspera(e, tope)
	local partes = {}
	for i, w in ipairs(e.esperan) do
		if i > (tope or 2) then break end
		if w.previa then
			partes[#partes + 1] = format(L["%s (antes %s)"], citar(w.q.title), citar(w.previa.title))
		else
			partes[#partes + 1] = format(L["%s (nivel %d)"], citar(w.q.title), w.nivel or 0)
		end
	end
	if #partes == 0 then return nil end
	local resto = #e.esperan - #partes
	local lista = #partes == 1 and partes[1] or format(L["%s y %s"], concat(partes, ", ", 1, #partes - 1), partes[#partes])
	if resto > 0 then lista = format(L["%s y %d más"], concat(partes, ", "), resto) end
	return format(#e.esperan == 1 and L["Espera: %s."] or L["Esperan: %s."], lista)
end
P.FrasesEspera = frasesEspera

function P.Frase(e)
	if not e then return "" end
	local n = #e.recoger
	local partes = {}
	if n > 0 then
		partes[1] = cuantas(n, L["Recoges 1 misión en el camino y te llevo a la entrada."],
			L["Recoges %d misiones en el camino y te llevo a la entrada."])
	elseif e.llevas > 0 then
		partes[1] = cuantas(e.llevas, L["Ya llevas 1 de sus misiones: te llevo a la entrada."],
			L["Ya llevas %d de sus misiones: te llevo a la entrada."])
	else
		partes[1] = L["No hay misiones que puedas tomar ahora: te llevo a la entrada."]
	end
	local w = frasesEspera(e)
	if w then partes[#partes + 1] = w end
	return concat(partes, " ")
end

---------------------------------------------------------------------------
-- Acciones
---------------------------------------------------------------------------
local function aviso(o)
	if K and K.Aviso then K.Aviso(o) else N.Imprimir(o.titulo .. (o.texto and (" " .. o.texto) or "")) end
end

local function porque(razon)
	if razon == "tabs" then return L["Tienes seis guías abiertas: cierra una y vuelve a intentarlo."] end
	if razon == "off" then return L["El diario de mazmorras del motor está apagado (Ajustes > Descubrir > Mazmorras)."] end
	if razon == "combat" then return L["Espera a salir de combate."] end
	return format(L["No se pudo armar la guía (%s)."], tostring(razon or "?"))
end

function P.Entrada(key)
	local Dgx = Dg()
	if not (Dgx and Dgx.GuideTo) then return false end
	if llamar(Dgx.GuideTo, key) then return true end
	aviso({ titulo = L["No conozco la entrada de esta mazmorra"], icono = "ic-alerta", tono = "aviso" })
	return false
end

function P.Preparar(key)
	local Dgx = Dg()
	if not (Dgx and type(key) == "string") then return false end
	P.Olvidar()
	local e = P.Estado(key)
	local nombre = D.Nombre(key)
	if #e.recoger > 0 and Dgx.PickUp then
		local gid, razon = llamar(Dgx.PickUp, key, true)
		if gid then
			if N.EmpezarRuta then N.EmpezarRuta() else A.Set("ui.shown", true) end
			aviso({ titulo = format(L["En marcha hacia %s"], nombre), lobo = "atento", tono = "acento", duracion = 9,
				texto = P.Frase(e) })
			return true
		end
		if razon ~= "nothing" then
			aviso({ titulo = L["No pude preparar la ruta"], texto = porque(razon), icono = "ic-alerta", tono = "aviso" })
			return false
		end
	end
	if P.Entrada(key) then
		aviso({ titulo = format(L["Te llevo a %s"], nombre), lobo = "atento", tono = "acento", duracion = 9, texto = P.Frase(e) })
		return true
	end
	return false
end

function P.Entregar(key)
	local Dgx = Dg()
	if not (Dgx and Dgx.HandIn) then return false end
	local gid, razon = llamar(Dgx.HandIn, key)
	if gid then
		if N.EmpezarRuta then N.EmpezarRuta() else A.Set("ui.shown", true) end
		aviso({ titulo = L["A entregar tus misiones"], lobo = "aullando", tono = "exito", duracion = 6,
			texto = L["La guía te lleva a quien recibe cada una."] })
		return true
	end
	local plan = Dgx.HandinPlan and llamar(Dgx.HandinPlan, key)
	local texto = razon ~= "nothing" and porque(razon) or (plan and Dgx.HandinText and llamar(Dgx.HandinText, plan)) or nil
	aviso({ titulo = L["Nada que entregar todavía"], texto = texto, icono = "ic-info", tono = "neutro" })
	return false
end

-- Pone la flecha en un punto (quien da o recibe una misión).
function P.Llevame(punto, nombre)
	local Dgx = Dg()
	if not (Dgx and Dgx.GuideToPoint and type(punto) == "table") then return false end
	return llamar(Dgx.GuideToPoint, punto, nombre or punto.name) and true or false
end
