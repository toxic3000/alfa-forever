-- Alfa - Rutas: el planificador. Elige las misiones de cada tramo, las
-- ordena por el camino más corto con el planificador de paradas del motor
-- (Dungeons.PlanStops, el mismo de "recoger misiones" en los diarios de
-- mazmorra) y las convierte en pasos de guía. Toxic / La Jauría. GPL-3.0.
--
--   Plan.De(ruta) -> plan | nil          -- el plan guardado de este personaje, si sigue al día
--   Plan.Armar(ruta, fn(plan | nil, motivo), alAvanzar?)
--   Plan.Compilar(ruta, plan, fn(def | nil, motivo))   -- la guía del motor de toda la ruta
--   Plan.Alternativas(ruta, uid, fn(lista))             -- otras misiones para un tramo
--   Plan.Registro(fn(lista))                            -- tus misiones abiertas, revisadas
--   Plan.Liberar(lista, fn(def | nil, motivo))          -- la guía para entregarlas
--
-- plan = { firma, fecha, desde, hasta, xp, oro, misiones, posicion,
--          tramos = { [uid] = { rama, quests = { id... }, item?, zona?, fuente?, xp, oro, desde, hasta, notas = {...} } } }

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local I, T = M.Indice, M.Tareas
local P = {}
M.Plan = P

local type, ipairs, pairs, tonumber, tostring = type, ipairs, pairs, tonumber, tostring
local floor, max, min, format, concat = math.floor, math.max, math.min, string.format, table.concat

local function LK() return M.Motor("Lookup") end
local function CX() return M.Motor("Codex") end
local function CP() return M.Motor("Compat") end

local function ajuste(clave) return N.Get(M.ID, clave) end

local function conjunto(lista)
	local s = {}
	for _, v in ipairs(lista or {}) do s[v] = true end
	return s
end

-- nivel decimal + xp -> nivel decimal (con la tabla de XP del motor).
local function sumarXP(nivel, xp)
	local Lv = M.Motor("Levels")
	local tabla, tope = Lv and Lv.LEVEL_XP, Lv and M.num(Lv.MAX_LEVEL, 60) or 60
	if type(tabla) ~= "table" or xp <= 0 then return nivel end
	local l = floor(nivel)
	if l >= tope then return tope end
	local need = M.num(tabla[l], 0)
	local actual = (nivel - l) * need + xp
	while l < tope and need > 0 and actual >= need do
		actual = actual - need
		l = l + 1
		need = M.num(tabla[l], 0)
	end
	if l >= tope then return tope end
	return l + (need > 0 and actual / need or 0)
end
P.SumarXP = sumarXP

local function titulo(qid)
	local C, Cp = CX(), CP()
	local t = Cp and Cp.GetQuestTitle and Cp.GetQuestTitle(qid)
	if t then return t end
	local q = C and C.Quest(qid)
	return q and q.title or format(L["Misión %d"], qid)
end
P.Titulo = titulo

---------------------------------------------------------------------------
-- Elegir misiones
---------------------------------------------------------------------------

local function contexto()
	local p = I.Jugador()
	local pos = A.PlayerPoint and A.PlayerPoint() or nil
	return { p = p, nivel = I.NivelDecimal(p), pos = pos, ancla = pos, usadas = {}, puntos = {}, xp = 0, oro = 0 }
end

local function puntosDe(ctx, e)
	local pts = ctx.puntos[e.id]
	if pts == nil then
		local dador, fin = I.Puntos(e, ctx.ancla, ctx.p)
		pts = (fin and (dador or I.EnRegistro(e.id))) and { dador = dador, fin = fin } or false
		ctx.puntos[e.id] = pts
	end
	return pts or nil
end

local function valor(e, modo, nivel, pedir)
	if modo == "oro" then return I.Oro(e, pedir) end
	return I.XPPara(e, nivel)
end

-- Las mejores candidatas para el siguiente lugar del tramo, mejor primero.
-- -> { { e, s, dador, fin, obj, grupo, tiempo, valor }, ... }
local function candidatas(ctx, modo, quitar, idx, ceder, cuantas)
	local nivel = ctx.nivel
	local margen = M.num(ajuste("margen"), 2)
	local techo = floor(nivel) + margen
	local piso = modo == "oro" and 1 or floor(nivel) - 9
	local pre = {}
	for i, e in ipairs(idx.lista) do
		if e.lvl <= techo and e.lvl >= piso and not quitar[e.id] and I.Disponible(e, ctx.usadas, nivel) then
			local pts = puntosDe(ctx, e)
			if pts then
				local d = pts.dador or ctx.pos
				local t = I.Viaje(ctx.pos, d) + I.Viaje(d, pts.fin) + 60 + 25 * (e.nobj or 0)
				local v = valor(e, modo, nivel, false)
				if v > 0 then pre[#pre + 1] = { e = e, s = v / (t + 30), dador = pts.dador, fin = pts.fin } end
			end
		end
		if i % 30 == 0 then ceder() end
	end
	table.sort(pre, function(a, b) return a.s > b.s end)
	local evitar = ajuste("evitarGrupo") ~= false
	local out = {}
	for k = 1, min(cuantas or 10, #pre) do
		local c = pre[k]
		local d = c.dador or ctx.pos
		local obj, grupo, dentro = I.Objetivo(c.e, d)
		if not dentro then
			local tiempo = I.Viaje(ctx.pos, d) + I.Viaje(d, obj or d) + I.Viaje(obj or d, c.fin) + I.Esfuerzo(c.e)
			local v = valor(c.e, modo, nivel, true)
			local s = v / (tiempo + 30)
			if c.e.lvl > nivel + 1 then s = s * 0.8 end
			if grupo and evitar then s = s * 0.15 end
			if I.EnRegistro(c.e.id) then s = s * 1.3 end
			out[#out + 1] = { e = c.e, s = s, dador = c.dador, fin = c.fin, obj = obj, grupo = grupo, tiempo = tiempo, valor = v }
		end
		ceder()
	end
	table.sort(out, function(a, b) return a.s > b.s end)
	return out
end

local function tomar(ctx, pt, e, fin)
	pt.quests[#pt.quests + 1] = e.id
	ctx.usadas[e.id] = true
	local ganada = I.XPPara(e, ctx.nivel)
	ctx.xp = ctx.xp + ganada
	ctx.oro = ctx.oro + I.Oro(e, false)
	ctx.nivel = sumarXP(ctx.nivel, ganada)
	if fin then ctx.pos = fin end
end

local function elegirMisiones(ctx, tramo, pt, modo, idx, ceder)
	local quitar = conjunto(tramo.quitar)
	for _, qid in ipairs(tramo.fijas or {}) do
		local e = idx.porId[qid]
		if e and not quitar[qid] and #pt.quests < tramo.cantidad and not ctx.usadas[qid] and not I.Hecha(qid) then
			local pts = puntosDe(ctx, e)
			tomar(ctx, pt, e, pts and pts.fin)
		end
	end
	while #pt.quests < tramo.cantidad do
		local lista = candidatas(ctx, modo, quitar, idx, ceder, 10)
		local mejor = lista[1]
		if not mejor then break end
		tomar(ctx, pt, mejor.e, mejor.fin)
		ceder()
	end
	if #pt.quests < tramo.cantidad then
		pt.notas[#pt.notas + 1] = format(L["Solo encontré %d misiones que te sirvan ahora."], #pt.quests)
	end
end

-- Misiones de clase: la cadena más corta que termina en una recompensa
-- (el "objeto único"), con sus misiones previas en orden.
local function elegirClase(ctx, tramo, pt, idx, ceder)
	local Lk, C = LK(), CX()
	local quitar = conjunto(tramo.quitar)
	local margen = M.num(ajuste("margen"), 2)
	local function agregar(qid)
		local e = idx.porId[qid]
		if e then
			local pts = puntosDe(ctx, e)
			tomar(ctx, pt, e, pts and pts.fin)
		else
			pt.quests[#pt.quests + 1] = qid
			ctx.usadas[qid] = true
		end
	end
	for _, qid in ipairs(tramo.fijas or {}) do
		if not quitar[qid] and not ctx.usadas[qid] and not I.Hecha(qid) and #pt.quests < tramo.cantidad then agregar(qid) end
	end
	local premios = {}
	local vueltas = 0
	while #pt.quests < tramo.cantidad and vueltas < 6 do
		vueltas = vueltas + 1
		local mejor
		for _, e in ipairs(idx.lista) do
			if e.clase and not quitar[e.id] and not ctx.usadas[e.id] and not I.Hecha(e.id) and e.lvl <= floor(ctx.nivel) + margen + 3 then
				local cadena = Lk.QuestChain and Lk.QuestChain(e.id, ctx.p) or {}
				local faltan, bien = {}, true
				for _, q in ipairs(cadena) do
					if not ctx.usadas[q.id] and not I.Hecha(q.id) then
						if M.num(q.minLevel, 1) > floor(ctx.nivel) + 2 then bien = false end
						faltan[#faltan + 1] = q.id
					end
				end
				if bien and #faltan > 0 then
					local premio = (#(e.rew or {}) + #(e.cho or {})) > 0 and 3 or 1
					local s = premio / #faltan / (1 + max(0, e.lvl - ctx.nivel))
					if not mejor or s > mejor.s then mejor = { s = s, faltan = faltan, e = e } end
				end
				ceder()
			end
		end
		if not mejor then break end
		for _, qid in ipairs(mejor.faltan) do
			if not ctx.usadas[qid] then agregar(qid) end
		end
		for _, id in ipairs(mejor.e.rew or {}) do premios[#premios + 1] = id end
		for _, id in ipairs(mejor.e.cho or {}) do premios[#premios + 1] = id end
	end
	if #premios > 0 then pt.premios = premios end
	if #pt.quests == 0 then
		local proximo
		for _, e in ipairs(idx.lista) do
			if e.clase and not I.Hecha(e.id) and (e.min or 1) > floor(ctx.nivel) then
				proximo = proximo and min(proximo, e.min) or e.min
			end
		end
		if proximo then
			pt.notas[#pt.notas + 1] = format(L["Aún no hay misiones de clase para ti: la próxima abre a nivel %d."], proximo)
		else
			pt.notas[#pt.notas + 1] = L["No encontré misiones de clase para ti ahora."]
		end
	end
	-- Para seguir midiendo el camino: donde se entrega la última.
	local ultima = pt.quests[#pt.quests]
	if ultima and C then
		local q = C.Quest(ultima)
		local fin = q and I.FinDe(q["end"], ctx.pos, ctx.p)
		if fin then ctx.pos = fin end
	end
end

-- "Botín de Edwin VanCleef · Las Minas de la Muerte": de dónde sale, en una línea.
local function textoFuente(item)
	local Lk = LK()
	if not (Lk and Lk.Sources) then return nil end
	local C = CX()
	local rec = C and C.Item(item)
	local ok, lista = pcall(Lk.Sources, rec and rec.kind or "item", item, true)
	if not ok or type(lista) ~= "table" then return nil end
	local fila = Lk.BestSource and Lk.BestSource(lista) or lista[1]
	if not fila then return nil end
	if fila.detail and fila.label then return fila.label .. " \194\183 " .. fila.detail end
	return fila.label or fila.detail
end
P.TextoFuente = textoFuente

local function armarPlan(ruta, idx, ceder)
	local ctx = contexto()
	local plan = { firma = M.Firma(ruta), fecha = time and time() or 0, desde = ctx.nivel, tramos = {}, xp = 0, oro = 0,
		misiones = 0, posicion = ctx.pos ~= nil }
	for i, t in ipairs(ruta.tramos) do
		local pt = { rama = t.rama, quests = {}, notas = {}, desde = ctx.nivel }
		local xp0, oro0 = ctx.xp, ctx.oro
		if t.rama == "xp" or t.rama == "oro" then
			elegirMisiones(ctx, t, pt, t.rama, idx, ceder)
		elseif t.rama == "clase" then
			elegirClase(ctx, t, pt, idx, ceder)
		elseif t.rama == "prof" then
			pt.item = t.item or I.MaterialSugerido()
			local lugar = pt.item and I.Recoleccion(pt.item, ctx.pos)
			if lugar then
				pt.zona = lugar.map
				ctx.pos = lugar
			else
				pt.notas[#pt.notas + 1] = L["No sé dónde se junta este material."]
			end
			if pt.item then ctx.oro = ctx.oro + I.Venta(pt.item) * t.cantidad end
		elseif t.rama == "objeto" then
			pt.item = t.item
			if t.item then pt.fuente = textoFuente(t.item) else pt.notas[#pt.notas + 1] = L["Elige el objeto en el catálogo."] end
		end
		pt.xp, pt.oro, pt.hasta = ctx.xp - xp0, ctx.oro - oro0, ctx.nivel
		plan.misiones = plan.misiones + #pt.quests
		plan.tramos[t.uid] = pt
		T.Avance("plan:" .. ruta.id, i / max(1, #ruta.tramos))
		ceder()
	end
	plan.hasta, plan.xp, plan.oro = ctx.nivel, ctx.xp, ctx.oro
	return plan
end

function P.De(ruta)
	if not ruta then return nil end
	local plan = M.Personaje().planes[ruta.id]
	if type(plan) == "table" and plan.firma == M.Firma(ruta) and type(plan.tramos) == "table" then return plan end
	return nil
end

-- Lo que vale la pena guardar (los planes van a las variables guardadas).
local function guardar(ruta, plan)
	M.Personaje().planes[ruta.id] = plan
end

-- Quien espera el plan de cada ruta: si se pide otra vez mientras se arma
-- (la página y "Agregar a mi ruta" a la vez), la tarea vuelve a empezar con
-- la ruta al día y al terminar avisa a todos, no solo al último.
local esperas = {} -- rutaId -> { fn, ... }

local function avisarPlan(rutaId, plan, motivo)
	local lista = esperas[rutaId] or {}
	esperas[rutaId] = nil
	for _, fn in ipairs(lista) do
		local ok, err = pcall(fn, plan, motivo)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
end

function P.Armar(ruta, alTerminar, alAvanzar)
	if not ruta then return alTerminar(nil, "noruta") end
	local id = ruta.id
	esperas[id] = esperas[id] or {}
	esperas[id][#esperas[id] + 1] = alTerminar
	I.Pedir(function(idx, motivo)
		if not idx then return avisarPlan(id, nil, motivo) end
		T.Lanzar("plan:" .. id, function(ceder) return armarPlan(ruta, idx, ceder) end, function(plan, err)
			if plan and M.Ruta(id) then guardar(ruta, plan) end
			avisarPlan(id, plan, err and "error" or nil)
		end, alAvanzar)
	end, alAvanzar)
end

-- Otras misiones que caben en un tramo (para cambiar una a mano): las de su
-- rama, desde donde estás, sin las que la ruta ya usa.
function P.Alternativas(ruta, uid, alTerminar)
	local tramo
	for _, t in ipairs(ruta and ruta.tramos or {}) do if t.uid == uid then tramo = t end end
	if not tramo then return alTerminar({}) end
	local plan = P.De(ruta)
	I.Pedir(function(idx)
		if not idx then return alTerminar({}) end
		T.Lanzar("alternativas", function(ceder)
			local ctx = contexto()
			if plan then
				for _, pt in pairs(plan.tramos) do
					for _, q in ipairs(pt.quests or {}) do ctx.usadas[q] = true end
				end
				local pt = plan.tramos[uid]
				if pt and pt.desde then ctx.nivel = max(ctx.nivel, pt.desde) end
			end
			local quitar = conjunto(tramo.quitar)
			if tramo.rama == "clase" then
				local out = {}
				for _, e in ipairs(idx.lista) do
					if e.clase and not ctx.usadas[e.id] and not quitar[e.id] and I.Disponible(e, ctx.usadas, ctx.nivel + 3) then
						out[#out + 1] = { e = e, valor = I.XPPara(e, ctx.nivel) }
					end
				end
				table.sort(out, function(a, b) return a.e.lvl < b.e.lvl end)
				return out
			end
			return candidatas(ctx, tramo.rama == "oro" and "oro" or "xp", quitar, idx, ceder, 12)
		end, function(lista) alTerminar(lista or {}) end)
	end)
end

---------------------------------------------------------------------------
-- De misiones a pasos de guía
---------------------------------------------------------------------------

local MAX_PARADAS = 15

local function claveNpc(g)
	if g.npc then return "n" .. g.npc end
	if g.object then return "o" .. g.object end
	return nil
end

-- Sin el planificador del motor: la parada más cercana lista, una tras otra.
local function ordenSimple(paradas, desde)
	local orden, hechas, aqui = {}, {}, desde
	for _ = 1, #paradas do
		local bi, bc
		for i, s in ipairs(paradas) do
			if not hechas[i] then
				local lista = true
				for _, d in ipairs(s.deps) do if not hechas[d] then lista = false end end
				if lista then
					local c = I.Viaje(aqui, s.inP)
					if not bc or c < bc then bi, bc = i, c end
				end
			end
		end
		if not bi then break end
		hechas[bi] = true
		orden[#orden + 1] = bi
		aqui = paradas[bi].outP or aqui
	end
	return orden
end

local function ordenar(paradas, desde)
	if #paradas == 0 then return {} end
	local D = M.Motor("Dungeons")
	if D and type(D.PlanStops) == "function" then
		local ok, orden = pcall(D.PlanStops, paradas, desde, nil, I.Viaje)
		if ok and type(orden) == "table" and #orden == #paradas then return orden end
	end
	return ordenSimple(paradas, desde)
end
P.Ordenar = ordenar

-- partes: { { q, aceptar?, objetivos, entregar, dador, objetivo, fin, listo? } }
-- -> pasos, punto final. finas: una parada por aceptar, hacer y entregar
-- (se aceptan juntas las de un mismo PNJ y se entregan juntas); si son
-- muchas, una parada por misión entera.
local function pasosDe(partes, desde)
	local paradas, porQuest = {}, {}
	local finas = 0
	for _, pm in ipairs(partes) do
		local aceptar = pm.aceptar and not I.EnRegistro(pm.q.id)
		finas = finas + (aceptar and 1 or 0) + ((#pm.objetivos > 0 and not pm.listo) and 1 or 0) + 1
	end
	finas = finas <= MAX_PARADAS
	for _, pm in ipairs(partes) do
		local enLog = I.EnRegistro(pm.q.id)
		local hacer = #pm.objetivos > 0 and not pm.listo
		if finas then
			local a, o
			if pm.aceptar and not enLog then
				local pt = pm.dador or pm.objetivo or pm.fin
				paradas[#paradas + 1] = { tipo = "A", pm = pm, inP = pt, outP = pt, deps = {} }
				a = #paradas
			end
			if hacer then
				local pt = pm.objetivo or pm.dador or pm.fin
				paradas[#paradas + 1] = { tipo = "O", pm = pm, inP = pt, outP = pt, deps = a and { a } or {} }
				o = #paradas
			end
			local antes = o or a
			paradas[#paradas + 1] = { tipo = "T", pm = pm, inP = pm.fin, outP = pm.fin, deps = antes and { antes } or {} }
			porQuest[pm.q.id] = { a = a, t = #paradas }
		else
			local entra = (not enLog and pm.dador) or (hacer and pm.objetivo) or pm.fin
			paradas[#paradas + 1] = { tipo = "Q", pm = pm, inP = entra, outP = pm.fin, deps = {} }
			porQuest[pm.q.id] = { a = #paradas, t = #paradas }
		end
	end
	-- Una misión que pide otra de este mismo grupo se acepta después de entregar esa.
	for _, pm in ipairs(partes) do
		local mio = porQuest[pm.q.id]
		if mio and mio.a then
			local function pide(pid)
				local otro = porQuest[pid]
				if otro and otro.t ~= mio.a then
					local deps = paradas[mio.a].deps
					deps[#deps + 1] = otro.t
				end
			end
			for _, pid in ipairs(pm.q.pre or {}) do pide(pid) end
			for _, pid in ipairs(pm.q.preAny or {}) do pide(pid) end
		end
	end
	local orden = ordenar(paradas, desde)
	local pasos, ultimo, aqui = {}, nil, desde
	local function conPnj(meta, tituloPaso)
		local k = claveNpc(meta)
		if ultimo and k and ultimo.clave == k then
			local goals = ultimo.paso.goals
			goals[#goals + 1] = meta
			return
		end
		local paso = { title = meta.npcName or meta.objName or tituloPaso, goals = { meta } }
		pasos[#pasos + 1] = paso
		ultimo = k and { clave = k, paso = paso } or nil
	end
	for _, i in ipairs(orden) do
		local s = paradas[i]
		local pm = s.pm
		if s.tipo == "A" then
			conPnj(M.Copia(pm.aceptar), pm.q.title)
		elseif s.tipo == "O" then
			pasos[#pasos + 1] = { title = pm.q.title, goals = M.Copia(pm.objetivos) }
			ultimo = nil
		elseif s.tipo == "T" then
			conPnj(M.Copia(pm.entregar), pm.q.title)
		else
			local goals = {}
			if pm.aceptar and not I.EnRegistro(pm.q.id) then goals[#goals + 1] = M.Copia(pm.aceptar) end
			if not pm.listo then
				for _, g in ipairs(pm.objetivos) do goals[#goals + 1] = M.Copia(g) end
			end
			goals[#goals + 1] = M.Copia(pm.entregar)
			pasos[#pasos + 1] = { title = pm.q.title, goals = goals }
			ultimo = nil
		end
		aqui = s.outP or aqui
	end
	return pasos, aqui
end
P.PasosDe = pasosDe

local function pasosMisiones(ids, desde, ceder, notas)
	local C = CX()
	local partes = {}
	for _, qid in ipairs(ids) do
		local q = C and C.Quest(qid)
		local pm = q and I.PasosMision(q, desde)
		if pm and not I.Hecha(qid) then
			pm.q = q
			local Cp = CP()
			pm.listo = I.EnRegistro(qid) and Cp and Cp.IsQuestReadyForTurnIn and Cp.IsQuestReadyForTurnIn(qid) or nil
			partes[#partes + 1] = pm
		elseif not I.Hecha(qid) then
			notas[#notas + 1] = format(L["No sé dónde se entrega %s: la saqué de la ruta."], A.Quoted and A.Quoted(titulo(qid)) or titulo(qid))
		end
		ceder()
	end
	return pasosDe(partes, desde)
end

local function nombreProfesion(linea)
	local Lk = LK()
	local en = Lk and Lk.ProfessionName and Lk.ProfessionName(linea)
	if not en then return L["la profesión"] end
	local EL = A.L
	return (type(EL) == "table" and EL[en]) or en
end

local function pasosRecoleccion(item, cantidad, desde)
	local nombre = M.NombreObjeto(item)
	local meta = { t = "collect", item = item, itemName = nombre, count = cantidad }
	local lugar = I.Recoleccion(item, desde)
	if lugar then
		for _, k in ipairs({ "map", "x", "y", "f", "spots", "spread", "from", "fromId", "fromKind" }) do meta[k] = lugar[k] end
	end
	local paso = { title = format(L["Junta %d de %s"], cantidad, nombre), goals = { meta } }
	local linea = I.LineaDe(item)
	local Cp = CP()
	if linea and Cp and Cp.GetSkillRank and not Cp.GetSkillRank(linea) then
		paso.note = format(L["Necesitas %s para juntarlo: apréndela con un instructor de profesiones."], nombreProfesion(linea))
	elseif not lugar then
		paso.note = L["No sé dónde se junta: búscalo en el catálogo para ver de dónde sale."]
	else
		paso.note = L["La flecha te lleva de un lugar al siguiente."]
	end
	return { paso }, lugar or desde
end

local function pasosObjeto(item, cantidad, notas)
	local Lk, C = LK(), CX()
	local nombre = M.NombreObjeto(item)
	local rec = C and C.Item(item)
	local kind = rec and rec.kind or "item"
	if Lk and Lk.BuildGuide then
		local ok, def, motivo = pcall(Lk.BuildGuide, kind, item)
		if ok and type(def) == "table" and type(def.steps) == "table" and #def.steps > 0 then
			local pasos = M.Copia(def.steps)
			if cantidad > 1 then
				for _, s in ipairs(pasos) do
					for _, g in ipairs(s.goals or {}) do
						if g.t == "collect" and g.item == item then g.count = cantidad end
					end
				end
			end
			return pasos
		end
		notas[#notas + 1] = format(L["Alfa no pudo armar el camino a %s (%s). Míralo en el Buscador."], nombre, tostring(ok and motivo or "error"))
	end
	return { { title = nombre, goals = { { t = "collect", item = item, itemName = nombre, count = cantidad } },
		note = L["Mira en el catálogo de dónde sale."] } }
end

local function anotar(paso, texto)
	if not (paso and texto and texto ~= "") then return end
	paso.note = paso.note and (texto .. " " .. paso.note) or texto
end

local function compilar(ruta, plan, ceder)
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	local pasos, avisos = {}, {}
	local total = #ruta.tramos
	local primerMapa
	for i, t in ipairs(ruta.tramos) do
		local pt = plan.tramos[t.uid] or { quests = {} }
		local nuevos, notas = {}, {}
		if t.rama == "prof" then
			local item = pt.item or t.item or I.MaterialSugerido()
			if item then nuevos, desde = pasosRecoleccion(item, t.cantidad, desde) end
		elseif t.rama == "objeto" then
			if t.item then nuevos = pasosObjeto(t.item, t.cantidad, notas) end
		else
			nuevos, desde = pasosMisiones(pt.quests or {}, desde, ceder, notas)
		end
		local cabeza = format(L["Tramo %d de %d: %s."], i, total, M.TituloTramo(t))
		if #nuevos == 0 then
			nuevos = { { title = M.TituloTramo(t), goals = { { t = "note", text = (pt.notas and pt.notas[1]) or L["Este tramo quedó vacío."] } } } }
		end
		anotar(nuevos[1], cabeza)
		for _, n in ipairs(notas) do avisos[#avisos + 1] = n end
		for _, s in ipairs(nuevos) do
			pasos[#pasos + 1] = s
			if not primerMapa then
				for _, g in ipairs(s.goals or {}) do if g.map then primerMapa = g.map break end end
			end
		end
		T.Avance("compilar:" .. ruta.id, i / max(1, total))
		ceder()
	end
	if #pasos == 0 then return nil end
	local ultimo = pasos[#pasos]
	ultimo.goals[#ultimo.goals + 1] = { t = "note", text = L["Fin de tu ruta. Arma la siguiente en /alfa rutas."] }
	return { pasos = pasos, avisos = avisos, mapa = primerMapa }
end

function P.Compilar(ruta, plan, alTerminar)
	if not (ruta and plan) then return alTerminar(nil, "noplan") end
	local ok, motivo = I.CodexListo()
	if not ok then return alTerminar(nil, motivo) end
	T.Lanzar("compilar:" .. ruta.id, function(ceder) return compilar(ruta, plan, ceder) end, function(res, err)
		if not res then return alTerminar(nil, err and "error" or "vacio") end
		local def = M.Guias.Def(M.Guias.IdRuta(ruta.id), ruta.nombre, res.pasos, {
			minLevel = floor(plan.desde or 1), maxLevel = max(floor(plan.desde or 1), floor((plan.hasta or 1) + 0.999)),
			zone = res.mapa, pitch = L["Tu ruta personalizada, armada por Alfa con tus tramos."],
			collects = (function()
				local c = {}
				for _, t in ipairs(ruta.tramos) do if t.rama == "objeto" and t.item then c[#c + 1] = t.item end end
				return #c > 0 and c or nil
			end)(),
		})
		alTerminar(def, nil, res.avisos)
	end)
end

---------------------------------------------------------------------------
-- Liberar misiones: tu registro, revisado, y la guía para entregarlo todo
---------------------------------------------------------------------------

local LEJOS_SEG = 900 -- 15 minutos de camino (en línea recta) es "muy lejos"

local function revisar(ceder)
	local C, Cp = CX(), CP()
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	local p = I.Jugador()
	local out = {}
	for _, qid in ipairs(Cp.GetLogQuests() or {}) do
		local q = C.Quest(qid)
		local it = { id = qid, titulo = titulo(qid), nivel = (Cp.GetQuestLevel and Cp.GetQuestLevel(qid)) or (q and q.level), razones = {} }
		it.listo = Cp.IsQuestReadyForTurnIn(qid) or (q ~= nil and #(q.objectives or {}) == 0 and Cp.GetQuestObjectives(qid) == nil)
		it.fallida = Cp.IsQuestFailed and Cp.IsQuestFailed(qid) or false
		it.gris = it.nivel and Cp.IsQuestTrivial and Cp.IsQuestTrivial(it.nivel, p.level) or false
		if not q then
			it.sinDatos = true
		else
			local pm = I.PasosMision(q, desde)
			if not pm then
				it.sinEntrega = true
			else
				pm.q, pm.listo = q, it.listo
				it.pm = pm
				it.grupo, it.dentro = pm.grupo and not it.listo, pm.dentro and not it.listo
				local destino = (not it.listo and pm.objetivo) or pm.fin
				it.viaje = I.Viaje(desde, destino)
				it.lejos = desde ~= nil and it.viaje >= LEJOS_SEG
			end
		end
		local r = it.razones
		if it.fallida then r[#r + 1] = L["Fallida"] end
		if it.gris then r[#r + 1] = L["Ya no da XP"] end
		if it.lejos then r[#r + 1] = L["Muy lejos"] end
		if it.grupo then r[#r + 1] = L["Pide grupo"] end
		if it.dentro then r[#r + 1] = L["En mazmorra"] end
		if it.sinDatos then r[#r + 1] = L["Sin datos"] end
		if it.sinEntrega then r[#r + 1] = L["Entrega desconocida"] end
		-- Lo que no vale la pena: fallida, gris o muy lejos sin estar lista.
		if it.fallida or (not it.listo and (it.gris or it.lejos)) then
			it.sugerencia = "abandonar"
		elseif it.dentro or it.grupo then
			it.sugerencia = "fuera"
		end
		out[#out + 1] = it
		ceder()
	end
	table.sort(out, function(a, b)
		if (a.listo and true or false) ~= (b.listo and true or false) then return a.listo and true or false end
		return M.num(a.viaje, I.LEJOS) < M.num(b.viaje, I.LEJOS)
	end)
	-- Las marcas de misiones que ya no están en el registro se olvidan.
	local marcas, siguen = M.Personaje().marcas, {}
	for _, it in ipairs(out) do siguen[it.id] = true end
	for qid in pairs(marcas) do if not siguen[qid] then marcas[qid] = nil end end
	return out
end

function P.Registro(alTerminar)
	local ok, motivo = I.CodexListo()
	if not ok then return alTerminar(nil, motivo) end
	T.Lanzar("registro", revisar, function(lista, err) alTerminar(lista, err and "error" or nil) end)
end

-- lista: la de Plan.Registro; se dejan fuera las marcadas.
function P.Liberar(lista, alTerminar)
	local marcas = M.Personaje().marcas
	local partes, fuera = {}, {}
	for _, it in ipairs(lista or {}) do
		if marcas[it.id] then
			fuera[#fuera + 1] = it
		elseif it.pm then
			partes[#partes + 1] = it.pm
		else
			fuera[#fuera + 1] = it
		end
	end
	if #partes == 0 then return alTerminar(nil, "nada") end
	T.Lanzar("liberar", function()
		local pasos = pasosDe(partes, A.PlayerPoint and A.PlayerPoint() or nil)
		if #pasos == 0 then return nil end
		local ultimo = pasos[#pasos]
		for _, it in ipairs(fuera) do
			local por = marcas[it.id] == "abandonar" and L["la marcaste para abandonar"] or (it.razones[1] or L["la dejaste fuera"])
			ultimo.goals[#ultimo.goals + 1] = { t = "note", text = format(L["Fuera de esta ruta: %s (%s)."], A.Quoted and A.Quoted(it.titulo) or it.titulo, por) }
		end
		anotar(pasos[1], format(L["%d misiones por entregar, en el orden más corto."], #partes))
		return pasos
	end, function(pasos)
		if not pasos then return alTerminar(nil, "vacio") end
		local mapa
		for _, s in ipairs(pasos) do
			for _, g in ipairs(s.goals) do if g.map then mapa = g.map break end end
			if mapa then break end
		end
		alTerminar(M.Guias.Def(M.Guias.IdLiberar(), L["Liberar mis misiones"], pasos, {
			zone = mapa, pitch = L["Todas tus misiones abiertas, para completarlas y entregarlas por el camino más corto."],
		}))
	end)
end

-- Abandona estas misiones (ya confirmadas por el jugador) -> cuántas.
function P.Abandonar(ids)
	local QL = C_QuestLog
	if not (QL and QL.SetSelectedQuest and QL.SetAbandonQuest and QL.AbandonQuest) then return 0 end
	local n = 0
	for _, qid in ipairs(ids or {}) do
		local puede = true
		if QL.CanAbandonQuest then
			local ok, si = pcall(QL.CanAbandonQuest, qid)
			puede = not ok or si ~= false
		end
		if puede and I.EnRegistro(qid) then
			local ok = pcall(function()
				QL.SetSelectedQuest(qid)
				QL.SetAbandonQuest()
				QL.AbandonQuest()
			end)
			if ok then
				n = n + 1
				M.Personaje().marcas[qid] = nil
			end
		end
	end
	return n
end
