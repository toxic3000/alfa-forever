-- Alfa - Rutas: el planificador. Elige las misiones de cada tramo, las
-- ordena por el camino más corto con el planificador de paradas del motor
-- (Dungeons.PlanStops, el mismo de "recoger misiones" en los diarios de
-- mazmorra) y las convierte en pasos de guía. toxic3000 / La Jauría. GPL-3.0.
--
--   Plan.De(ruta) -> plan | nil          -- el plan guardado de este personaje, si sigue al día
--   Plan.Armar(ruta, fn(plan | nil, motivo), alAvanzar?)
--   Plan.Compilar(ruta, plan, fn(def | nil, motivo))   -- la guía del motor de toda la ruta
--   Plan.Alternativas(ruta, uid, fn(lista))             -- otras misiones para un tramo
--   Plan.PasosDe(partes, desde, costo) -> pasos         -- paradas en el orden más corto
--   Plan.Abandonar(ids) -> cuántas
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

-- nivel: el nivel que se va ganando en el plan (para medir la XP y la
-- dificultad); real: el de ahora, el único que decide si una misión se
-- puede tomar (la regla de la ruta: nada que no se pueda tomar ya).
local function contexto()
	local p = I.Jugador()
	local pos = A.PlayerPoint and A.PlayerPoint() or nil
	return { p = p, nivel = I.NivelDecimal(p), real = p.level, pos = pos, ancla = pos, usadas = {}, puntos = {}, xp = 0, oro = 0 }
end

-- La XP del plan se cuenta a la baja: si el juego da menos, el plan no se
-- adelanta al nivel de verdad.
local PRUDENCIA = 0.9

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
		if e.lvl <= techo and e.lvl >= piso and not quitar[e.id] and I.Disponible(e, ctx.usadas, ctx.real) then
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
	ctx.nivel = sumarXP(ctx.nivel, floor(ganada * PRUDENCIA))
	if fin then ctx.pos = fin end
end

local function elegirMisiones(ctx, tramo, pt, modo, idx, ceder)
	local quitar = conjunto(tramo.quitar)
	for _, qid in ipairs(tramo.fijas or {}) do
		local e = idx.porId[qid]
		if e and not quitar[qid] and #pt.quests < tramo.cantidad and not ctx.usadas[qid] and not I.Hecha(qid) then
			if I.Disponible(e, ctx.usadas, ctx.real) then
				local pts = puntosDe(ctx, e)
				tomar(ctx, pt, e, pts and pts.fin)
			else
				local _, motivo, info = M.Disp.Estado(qid, { usadas = ctx.usadas, nivel = ctx.real })
				pt.notas[#pt.notas + 1] = format(L["%s no entra todavía: %s."], M.Citar(titulo(qid)), M.Disp.Texto(motivo, info))
			end
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
		pt.notas[#pt.notas + 1] = M.Plural(#pt.quests, L["Solo encontré %d misión que te sirva ahora."], L["Solo encontré %d misiones que te sirvan ahora."])
	end
end

-- Lo que falta para llegar a un nivel: las mejores misiones de XP que ya se
-- pueden tomar, antes de lo que pide ese nivel. -> cuántas agregó
local function subirHasta(ctx, objetivo, pt, idx, ceder)
	pt.antes = pt.antes or {}
	local n = 0
	while ctx.nivel < objetivo and #pt.antes < 30 do
		local mejor = candidatas(ctx, "xp", {}, idx, ceder, 8)[1]
		if not mejor then break end
		pt.antes[#pt.antes + 1] = mejor.e.id
		ctx.usadas[mejor.e.id] = true
		local ganada = I.XPPara(mejor.e, ctx.nivel)
		ctx.xp = ctx.xp + ganada
		ctx.nivel = sumarXP(ctx.nivel, floor(ganada * PRUDENCIA))
		if mejor.fin then ctx.pos = mejor.fin end
		n = n + 1
		ceder()
	end
	pt.nivel = max(M.num(pt.nivel, 0), objetivo)
	if ctx.nivel < objetivo then
		pt.notas[#pt.notas + 1] = format(L["Te faltan niveles para llegar a %d: la guía te lo marca y sigues subiendo con tu ruta."], objetivo)
	end
	return n
end
P.SubirHasta = subirHasta

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
				-- Lo que pide: sus previas en orden y el nivel más alto de la
				-- cadena (Disponible.lua). Una de otra facción, raza o clase,
				-- o cerrada por otra, no entra.
				local des = M.Disp.Desbloquear(e.id)
				local faltan = {}
				for _, q in ipairs(des.cadena) do
					if not ctx.usadas[q] and not I.Hecha(q) then faltan[#faltan + 1] = q end
				end
				local necesita = M.num(des.nivel, 1)
				if not des.motivo and not des.linea and #faltan > 0 and necesita <= ctx.real + 3 then
					local premio = (#(e.rew or {}) + #(e.cho or {})) > 0 and 3 or 1
					local s = premio / #faltan / (1 + max(0, e.lvl - ctx.nivel)) / (1 + max(0, necesita - ctx.real))
					if not mejor or s > mejor.s then mejor = { s = s, faltan = faltan, e = e, nivel = necesita } end
				end
				ceder()
			end
		end
		if not mejor then break end
		-- Si la cadena pide más nivel del que tienes, antes van misiones de XP
		-- y un paso que espera ese nivel.
		if mejor.nivel > ctx.real then subirHasta(ctx, mejor.nivel, pt, idx, ceder) end
		for _, qid in ipairs(mejor.faltan) do
			if not ctx.usadas[qid] then agregar(qid) end
		end
		-- La misión de clase dice lo que se agregó antes (sus previas, el nivel).
		pt.antesDe = pt.antesDe or {}
		pt.antesDe[mejor.e.id] = M.Disp.TextoAntes(mejor.faltan, mejor.nivel > ctx.real and mejor.nivel or nil)
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

-- La fuente con la que se armaría la guía de un objeto (Lookup.BestSource:
-- la primera a tu alcance que se pueda guiar).
local function mejorFuente(item)
	local Lk = LK()
	if not (Lk and Lk.Sources and Lk.BestSource) then return nil end
	local C = CX()
	local rec = C and C.Item(item)
	local ok, lista = pcall(Lk.Sources, rec and rec.kind or "item", item)
	if not ok or type(lista) ~= "table" then return nil end
	return Lk.BestSource(lista)
end
P.MejorFuente = mejorFuente

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
			if t.item then
				pt.fuente = textoFuente(t.item)
				-- La mejor forma de conseguirlo que ya está a tu alcance; si
				-- ninguna lo está, lo que falta (el nivel: misiones de XP antes).
				local fila = mejorFuente(t.item)
				if fila and not fila.available then
					local necesita = fila.why == "level" and tonumber(tostring(fila.whyText or ""):match("(%d+)"))
					if necesita and necesita > ctx.real then
						subirHasta(ctx, necesita, pt, idx, ceder)
					elseif fila.whyText then
						pt.notas[#pt.notas + 1] = format(L["Todavía no puedes conseguirlo: %s."], fila.whyText)
					end
				elseif not fila then
					pt.notas[#pt.notas + 1] = L["No sé de dónde sale este objeto."]
				end
			else
				pt.notas[#pt.notas + 1] = L["Elige el objeto en la Enciclopedia."]
			end
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
					if e.clase and not ctx.usadas[e.id] and not quitar[e.id] and I.Disponible(e, ctx.usadas, ctx.real) then
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

-- La guarda de una entrega: la meta "complete" de su misión, en el lugar de
-- sus objetivos. Se cumple sola cuando la misión queda lista; mientras no,
-- es la meta de ahora del paso y la flecha va a lo que falta, nunca al PNJ
-- de la entrega: así pasa al mirar el paso antes de tiempo (Siguiente, la
-- lista de pasos), al omitir o marcar a mano el paso de los objetivos y con
-- un plan viejo que se quedó atrás.
local function guarda(pm)
	local g = { t = "complete", quest = pm.q.id, title = pm.q.title }
	local o = pm.objetivo
	if o and o.map and o.x and o.y then g.map, g.x, g.y, g.f = o.map, o.x, o.y, o.f end
	return g
end
P.Guarda = guarda

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

-- costo(a, b) -> segundos: el camino entre dos puntos (por omisión, en
-- línea recta; Cerrar.lua le da uno con vuelos y la piedra de hogar).
local function ordenar(paradas, desde, costo)
	if #paradas == 0 then return {} end
	local D = M.Motor("Dungeons")
	if D and type(D.PlanStops) == "function" then
		local ok, orden = pcall(D.PlanStops, paradas, desde, nil, costo or I.Viaje)
		if ok and type(orden) == "table" and #orden == #paradas then return orden end
	end
	return ordenSimple(paradas, desde)
end
P.Ordenar = ordenar

-- partes: { { q, aceptar?, objetivos, entregar, dador, objetivo, fin, listo? } }
-- -> pasos, punto final. finas: una parada por aceptar, hacer y entregar
-- (se aceptan juntas las de un mismo PNJ y se entregan juntas); si son
-- muchas, una parada por misión entera.
-- ordenFn(paradas, desde, costo) -> orden (1.3.0: el circuito de la zona da el suyo).
local function pasosDe(partes, desde, costo, ordenFn)
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
			-- guarda: la entrega lleva antes "Completa la misión" (Plan.Guarda).
			paradas[#paradas + 1] = { tipo = "T", pm = pm, inP = pm.fin, outP = pm.fin, deps = antes and { antes } or {}, guarda = hacer }
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
	local orden = (ordenFn or ordenar)(paradas, desde, costo)
	local pasos, ultimo, aqui = {}, nil, desde
	local function conPnj(meta, tituloPaso)
		local k = claveNpc(meta)
		if ultimo and k and ultimo.clave == k then
			local goals = ultimo.paso.goals
			goals[#goals + 1] = meta
			return ultimo.paso
		end
		local paso = { title = meta.npcName or meta.objName or tituloPaso, goals = { meta } }
		pasos[#pasos + 1] = paso
		ultimo = k and { clave = k, paso = paso } or nil
		return paso
	end
	-- La nota de la parada (Cerrar.lua: en qué zona y si queda lejos).
	local function notar(paso, pm)
		if paso and pm.nota and not paso.note then paso.note = pm.nota end
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
			local paso = conPnj(M.Copia(pm.entregar), pm.q.title)
			-- Justo antes de su entrega: "Completa" (hecha sola al quedar lista).
			if s.guarda then table.insert(paso.goals, #paso.goals, guarda(pm)) end
			notar(paso, pm)
		else
			local goals = {}
			if pm.aceptar and not I.EnRegistro(pm.q.id) then goals[#goals + 1] = M.Copia(pm.aceptar) end
			if not pm.listo then
				for _, g in ipairs(pm.objetivos) do goals[#goals + 1] = M.Copia(g) end
			end
			goals[#goals + 1] = M.Copia(pm.entregar)
			pasos[#pasos + 1] = { title = pm.q.title, goals = goals }
			notar(pasos[#pasos], pm)
			ultimo = nil
		end
		aqui = s.outP or aqui
	end
	return pasos, aqui
end
P.PasosDe = pasosDe

local function pasosMisiones(ids, desde, ceder, notas, costo)
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
	return pasosDe(partes, desde, costo)
end
P.PasosMisiones = pasosMisiones

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
		paso.note = L["No sé dónde se junta: búscalo en la Enciclopedia para ver de dónde sale."]
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
		notas[#notas + 1] = format(L["Alfa no pudo armar el camino a %s. Míralo en la Enciclopedia."], nombre)
	end
	return { { title = nombre, goals = { { t = "collect", item = item, itemName = nombre, count = cantidad } },
		note = L["Mira en la Enciclopedia de dónde sale."] } }
end

local function anotar(paso, texto)
	if not (paso and texto and texto ~= "") then return end
	paso.note = paso.note and (texto .. " " .. paso.note) or texto
end
P.Anotar = anotar

-- Lo que la ruta agregó antes de una misión (Disp.TextoAntes), en su meta de
-- aceptar: el rastreador lo dice ("Antes: ..."). marcas: { [qid] = texto }.
function P.MarcarAntes(pasos, marcas)
	if type(marcas) ~= "table" or next(marcas) == nil then return end
	for _, s in ipairs(pasos or {}) do
		for _, g in ipairs(s.goals or {}) do
			if g.t == "accept" and g.quest and marcas[g.quest] then g.antes = marcas[g.quest] end
		end
	end
end

-- El paso que espera un nivel (la meta "level" del motor: se cumple sola al
-- llegar), con lo que falta en XP.
local function pasoNivel(nivel)
	return { title = format(L["Llega a nivel %d"], nivel),
		goals = { { t = "level", level = nivel } },
		note = L["Lo que sigue pide este nivel: hasta entonces, la guía no te manda allá."] }
end
P.PasoNivel = pasoNivel

local function compilar(ruta, plan, ceder)
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	local pasos, avisos = {}, {}
	local total = #ruta.tramos
	local primerMapa
	for i, t in ipairs(ruta.tramos) do
		local pt = plan.tramos[t.uid] or { quests = {} }
		local nuevos, notas = {}, {}
		-- Lo que hace falta antes (misiones de XP hasta el nivel que pide el tramo).
		if pt.antes and #pt.antes > 0 then
			nuevos, desde = pasosMisiones(pt.antes, desde, ceder, notas)
		end
		if pt.nivel and pt.nivel > I.Jugador().level then nuevos[#nuevos + 1] = pasoNivel(pt.nivel) end
		local resto
		if t.rama == "prof" then
			local item = pt.item or t.item or I.MaterialSugerido()
			if item then resto, desde = pasosRecoleccion(item, t.cantidad, desde) end
		elseif t.rama == "objeto" then
			if t.item then resto = pasosObjeto(t.item, t.cantidad, notas) end
		else
			resto, desde = pasosMisiones(pt.quests or {}, desde, ceder, notas)
			P.MarcarAntes(resto, pt.antesDe)
		end
		for _, s in ipairs(resto or {}) do nuevos[#nuevos + 1] = s end
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
	ultimo.goals[#ultimo.goals + 1] = { t = "note", text = L["Fin de tu ruta: arma la siguiente en la página Ruta de Alfa."] }
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
-- Abandonar (Cerrar.lua arma el plan para cerrar tus misiones)
---------------------------------------------------------------------------

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
			-- 1.2.7: ya lo confirmaste: sin el aviso de la cadena (Cadenas.lua).
			M.abandonando = true
			local ok = pcall(function()
				QL.SetSelectedQuest(qid)
				QL.SetAbandonQuest()
				QL.AbandonQuest()
			end)
			M.abandonando = nil
			if ok then
				n = n + 1
				M.Personaje().marcas[qid] = nil
			end
		end
	end
	return n
end
