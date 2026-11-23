-- Alfa - Rutas: el plan para cerrar tus misiones ("Liberar"). Toxic / La
-- Jauría. GPL-3.0.
--
-- Revisa tu registro (las listas para entregar y las que faltan por
-- terminar), suma las misiones que agregaste a mano (desde el registro del
-- juego, la ruta o la Enciclopedia) con lo que piden antes, y arma una guía
-- del motor que las cierra por el camino más corto: las paradas se ordenan
-- con el planificador del motor (Dungeons.PlanStops) midiendo el camino de
-- verdad entre zonas (Nav.EstimateTravel: vuelos, barcos y, desde donde
-- estás, la piedra de hogar), se agrupan por PNJ y cada parada dice en qué
-- zona está y si queda lejos. La flecha usa los vuelos y la piedra cuando
-- conviene.
--
--   Cerrar.Revisar(fn(lista | nil, motivo))   tus misiones, revisadas (en segundo plano)
--   Cerrar.Lista() -> la última revisión (o nil)
--   Cerrar.Entra(it, filtro) -> bool           si entra al plan con ese filtro
--   Cerrar.Filtro() / Cerrar.SetFiltro(f)      "todas" | "listas" | "zona"
--   Cerrar.Alternar(qid) / Cerrar.Agregar(qid) / Cerrar.Quitar(qid) / Cerrar.EnPlan(qid)
--   Cerrar.Armar(opts, fn(def | nil, motivo))  opts = { filtro, abrir = true, alAvanzar }
--   Cerrar.Ahora(filtro)                        arma, instala y abre la guía (un clic)
--   Cerrar.Cuentas() -> { listas, faltan, total, fuera }

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local I, T, P, D = M.Indice, M.Tareas, M.Plan, M.Disp
local Cr = {}
M.Cerrar = Cr

local type, ipairs, pairs, tonumber, tostring = type, ipairs, pairs, tonumber, tostring
local floor, max, min, format, concat = math.floor, math.max, math.min, string.format, table.concat

local LEJOS = 600 -- segundos: una parada a más de 10 minutos de camino "queda lejos"
local GRUPO_YARDAS = 120 -- puntos así de cerca se miden como uno
local DIRECTO = 240 -- segundos: lo que está así de cerca se mide en línea recta

local function CX() return M.Motor("Codex") end
local function CP() return M.Motor("Compat") end

local function pj() return M.Personaje() end
local revision -- la última lista revisada

function Cr.Filtro()
	local f = pj().filtro
	if f == "listas" or f == "zona" then return f end
	return "todas"
end

function Cr.SetFiltro(f)
	pj().filtro = (f == "listas" or f == "zona") and f or "todas"
	M.Avisar("CERRAR")
end

local function extras() return pj().extra end

local function esExtra(qid)
	for _, q in ipairs(extras()) do if q == qid then return true end end
	return false
end

---------------------------------------------------------------------------
-- Revisar el registro
---------------------------------------------------------------------------

local function puntoDe(pm, listo)
	return (not listo and pm.objetivo) or pm.fin
end

local function revisarUna(qid, desde, aqui, p, enLog)
	local C, Cp = CX(), CP()
	local q = C.Quest(qid)
	local it = { id = qid, titulo = M.TituloMision(qid), enLog = enLog, extra = esExtra(qid), razones = {} }
	it.nivel = (enLog and Cp.GetQuestLevel and Cp.GetQuestLevel(qid)) or (q and q.level)
	if enLog then
		it.listo = Cp.IsQuestReadyForTurnIn(qid) or (q ~= nil and #(q.objectives or {}) == 0 and Cp.GetQuestObjectives(qid) == nil)
		it.fallida = Cp.IsQuestFailed and Cp.IsQuestFailed(qid) or false
		it.gris = it.nivel and Cp.IsQuestTrivial and Cp.IsQuestTrivial(it.nivel, p.level) or false
	else
		-- Una agregada a mano: si se puede tomar y, si no, qué pide.
		local ok, motivo, info = D.Estado(qid)
		if not ok then
			it.bloqueo, it.bloqueoTexto = motivo, D.Texto(motivo, info)
			it.imposible = D.Imposible(motivo)
		end
	end
	if not q then
		it.sinDatos = true
	else
		local pm = I.PasosMision(q, desde)
		if not pm then
			it.sinEntrega = true
		else
			pm.q, pm.listo = q, it.listo
			it.pm = pm
			-- dentro de una mazmorra: por la lista del motor o por la etiqueta del juego
			local dentro = pm.dentro or I.EtiquetaMazmorra(it.id)
			it.grupo, it.dentro = (pm.grupo or dentro) and not it.listo, dentro and not it.listo
			it.mazmorra = pm.mazmorra
			local destino = puntoDe(pm, it.listo)
			it.destino = destino
			it.zona = destino and destino.map
			it.viaje = I.Viaje(desde, destino)
			-- Sin medida (un punto que no se ubica) no se dice nada.
			it.lejos = desde ~= nil and it.viaje >= LEJOS and it.viaje < I.LEJOS
			it.otraZona = aqui ~= nil and it.zona ~= nil and it.zona ~= aqui
		end
	end
	local r = it.razones
	if it.fallida then r[#r + 1] = L["Fallida"] end
	if it.gris then r[#r + 1] = L["Ya no da XP"] end
	if it.grupo then r[#r + 1] = L["Pide grupo"] end
	if it.dentro then r[#r + 1] = it.mazmorra and format(L["Dentro de %s (mazmorra)"], it.mazmorra) or L["En mazmorra"] end
	if it.sinDatos then r[#r + 1] = L["Sin datos"] end
	if it.sinEntrega then r[#r + 1] = L["No sé dónde se entrega"] end
	-- Lo que no vale la pena: fallida, gris o muy lejos sin estar lista.
	if enLog and (it.fallida or (not it.listo and it.gris)) then
		it.sugerencia = "abandonar"
	elseif it.dentro or it.grupo then
		it.sugerencia = "fuera"
	end
	return it
end

local function revisar(ceder)
	local Cp = CP()
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	local aqui = desde and desde.map
	local p = I.Jugador()
	local out, vistos = {}, {}
	for _, qid in ipairs(Cp.GetLogQuests() or {}) do
		vistos[qid] = true
		out[#out + 1] = revisarUna(qid, desde, aqui, p, true)
		ceder()
	end
	-- Las agregadas a mano que no están en el registro (ya entregadas: fuera).
	local lista = extras()
	for i = #lista, 1, -1 do
		local qid = lista[i]
		if I.Hecha(qid) then
			table.remove(lista, i)
		elseif not vistos[qid] then
			vistos[qid] = true
			out[#out + 1] = revisarUna(qid, desde, aqui, p, false)
			ceder()
		end
	end
	table.sort(out, function(a, b)
		local la, lb = a.listo and 1 or 0, b.listo and 1 or 0
		if la ~= lb then return la > lb end
		return M.num(a.viaje, I.LEJOS) < M.num(b.viaje, I.LEJOS)
	end)
	-- Lo que quedó de misiones que ya no están se olvida.
	local marcas, incluir = pj().marcas, pj().incluir
	for qid in pairs(marcas) do if not vistos[qid] then marcas[qid] = nil end end
	for qid in pairs(incluir) do if not vistos[qid] then incluir[qid] = nil end end
	return out
end

local generacion = 0 -- sube con cada cambio del registro (olvidar)

function Cr.Revisar(alTerminar)
	local ok, motivo = I.CodexListo()
	if not ok then return alTerminar(nil, motivo) end
	local gen = generacion
	T.Lanzar("cerrar:revisar", revisar, function(lista, err)
		-- (una revisión que empezó antes de una entrega no pisa a la de después)
		if lista and gen == generacion then revision = lista end
		alTerminar(lista, err and "error" or nil)
		M.Avisar("CERRAR")
	end)
end

function Cr.Lista() return revision end

---------------------------------------------------------------------------
-- Qué entra al plan
---------------------------------------------------------------------------

-- Con el filtro, lo que marcaste a mano y lo que tiene sentido: una de
-- mazmorra o de grupo queda fuera salvo que la pongas tú.
function Cr.Entra(it, filtro)
	if not it then return false end
	local marca = pj().marcas[it.id]
	if marca then return false end
	if it.extra and not it.enLog then return not it.imposible end
	if not it.pm then return false end
	if pj().incluir[it.id] then return true end
	if it.dentro or it.grupo then return false end
	filtro = filtro or Cr.Filtro()
	if filtro == "listas" then return it.listo and true or false end
	if filtro == "zona" then return not it.otraZona end
	return true
end

-- Un clic en la lista: dentro o fuera del plan, sea cual sea el filtro.
function Cr.Alternar(qid)
	local it
	for _, x in ipairs(revision or {}) do if x.id == qid then it = x end end
	if Cr.EnPlan(qid, it) then
		Cr.Quitar(qid)
	else
		Cr.Agregar(qid)
	end
end

function Cr.EnPlan(qid, it)
	qid = tonumber(qid)
	if not qid then return false end
	if not it then
		for _, x in ipairs(revision or {}) do if x.id == qid then it = x end end
	end
	if it then return Cr.Entra(it) end
	if pj().marcas[qid] then return false end
	return esExtra(qid) or pj().incluir[qid] == true
end

-- Agregar una misión al plan: una del registro entra aunque el filtro la
-- deje fuera; otra (de la Enciclopedia) se agrega para tomarla y hacerla,
-- con lo que pide antes. -> true | false, por qué
function Cr.Agregar(qid)
	qid = tonumber(qid)
	if not qid then return false, L["No sé qué misión es."] end
	local p = pj()
	p.marcas[qid] = nil
	if I.EnRegistro(qid) then
		p.incluir[qid] = true
	else
		if I.Hecha(qid) then return false, L["Ya la hiciste."] end
		local ok, motivo, info = D.Estado(qid)
		if not ok and D.Imposible(motivo) then return false, D.Texto(motivo, info) end
		if not esExtra(qid) then p.extra[#p.extra + 1] = qid end
	end
	revision = nil
	M.Avisar("CERRAR")
	return true
end

function Cr.Quitar(qid)
	qid = tonumber(qid)
	if not qid then return false end
	local p = pj()
	p.incluir[qid] = nil
	for i = #p.extra, 1, -1 do if p.extra[i] == qid then table.remove(p.extra, i) end end
	if I.EnRegistro(qid) then p.marcas[qid] = "fuera" end
	revision = nil
	M.Avisar("CERRAR")
	return true
end

-- Para abandonar (con confirmación, en la página).
function Cr.MarcarAbandonar(qid, on)
	local p = pj()
	if on then p.marcas[qid] = "abandonar" elseif p.marcas[qid] == "abandonar" then p.marcas[qid] = nil end
	M.Avisar("CERRAR")
end

function Cr.Cuentas(lista)
	lista = lista or revision or {}
	local c = { listas = 0, faltan = 0, total = 0, entran = 0, fuera = 0, abandonar = 0, lejos = 0, otraZona = 0 }
	for _, it in ipairs(lista) do
		if it.enLog then
			c.total = c.total + 1
			if it.listo then c.listas = c.listas + 1 else c.faltan = c.faltan + 1 end
		end
		if pj().marcas[it.id] == "abandonar" then c.abandonar = c.abandonar + 1 end
		if Cr.Entra(it) then
			c.entran = c.entran + 1
			if it.lejos then c.lejos = c.lejos + 1 end
			if it.otraZona then c.otraZona = c.otraZona + 1 end
		else
			c.fuera = c.fuera + 1
		end
	end
	return c
end

-- Las listas para entregar (para Hoy, la página y los avisos): las de la
-- última revisión, o al momento si no hay.
function Cr.ListasAhora()
	-- 1.2.6: siempre al momento (la revisión guardada no se entera de una
	-- misión que queda lista al matar al último monstruo).
	local Cp = CP()
	local n = 0
	if not (Cp and Cp.GetLogQuests) then return 0 end
	for _, qid in ipairs(Cp.GetLogQuests() or {}) do
		if Cp.IsQuestReadyForTurnIn(qid) then n = n + 1 end
	end
	return n
end

---------------------------------------------------------------------------
-- El camino de verdad entre las paradas
---------------------------------------------------------------------------

local function mundo(p)
	local Cp = CP()
	if not (p and p.map and p.x and p.y and Cp and Cp.MapToWorld) then return nil end
	local c, wx, wy = Cp.MapToWorld(p.map, p.x, p.y, p.f)
	return c, wx, wy
end

-- Un medidor para PlanStops: los puntos cercanos se juntan en grupos, y
-- entre grupos lejanos (otra zona, otro continente) se pregunta al
-- navegador del motor, un camino por cuadro para no trabar el juego.
-- -> costo(a, b), costoDesde(punto) (desde donde estás, con la piedra)
local function medidor(puntos, desde, ceder, alAvanzar)
	local grupos, de = {}, {}
	for _, p in ipairs(puntos) do
		if p and not de[p] then
			local c, wx, wy = mundo(p)
			local g
			if c then
				for _, x in ipairs(grupos) do
					if x.c == c and ((x.wx - wx) ^ 2 + (x.wy - wy) ^ 2) ^ 0.5 <= GRUPO_YARDAS then g = x break end
				end
			end
			if not g then
				g = { p = p, c = c, wx = wx, wy = wy, i = #grupos + 1, fila = {} }
				grupos[#grupos + 1] = g
			end
			de[p] = g
		end
	end
	local Nav = A.Nav
	local estimar = Nav and Nav.EstimateTravel
	local function directo(a, b)
		local f = A.DirectTravelCost
		local ok, t = pcall(f, a, b)
		return ok and type(t) == "number" and t or nil
	end
	local preguntas = 0
	local total = #grupos * (#grupos + 1) / 2
	-- Desde donde estás (con la piedra de hogar si está lista).
	local desdeG = {}
	for _, g in ipairs(grupos) do
		local d = desde and directo(desde, g.p)
		local t = d
		if estimar and (not d or d > DIRECTO) then
			local ok, s = pcall(estimar, nil, g.p)
			if ok and type(s) == "number" then t = d and min(d, s) or s end
			preguntas = preguntas + 1
			ceder()
		end
		desdeG[g.i] = t or I.LEJOS
		if alAvanzar then alAvanzar(preguntas / max(1, total)) end
	end
	for i = 1, #grupos do
		local a = grupos[i]
		for j = i + 1, #grupos do
			local b = grupos[j]
			local d = directo(a.p, b.p)
			local t = d
			if estimar and (not d or d > DIRECTO) and #grupos <= 18 then
				local ok, s = pcall(estimar, a.p, b.p)
				if ok and type(s) == "number" then t = d and min(d, s) or s end
				preguntas = preguntas + 1
				ceder()
				if alAvanzar then alAvanzar(preguntas / max(1, total)) end
			end
			t = t or I.LEJOS
			a.fila[j], b.fila[i] = t, t
		end
	end
	local function costo(a, b)
		if a == nil or b == nil then return I.LEJOS end
		if a == b then return 0 end
		if a == desde then
			local g = de[b]
			return g and desdeG[g.i] or I.LEJOS
		end
		local ga, gb = de[a], de[b]
		if not (ga and gb) then return I.Viaje(a, b) end
		if ga == gb then return I.Viaje(a, b) end
		return ga.fila[gb.i] or I.LEJOS
	end
	local function costoDesde(p)
		local g = de[p]
		return g and desdeG[g.i] or nil
	end
	return costo, costoDesde
end
Cr.Medidor = medidor

-- La nota de una parada: la zona y si queda lejos.
local function notaDe(pm, segundos, aqui)
	local map = pm.fin and pm.fin.map
	local partes = {}
	local zona = map and M.Zona(map)
	if zona and map ~= aqui then partes[#partes + 1] = format(L["En otra zona: %s"], zona) end
	if segundos and segundos >= LEJOS and segundos < I.LEJOS then partes[#partes + 1] = format(L["Queda lejos: unos %s de camino"], M.Minutos(segundos)) end
	if #partes == 0 then return nil end
	return concat(partes, ". ") .. "."
end

---------------------------------------------------------------------------
-- Armar la guía
---------------------------------------------------------------------------

local function armar(lista, filtro, idx, ceder, alAvanzar)
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	local aqui = desde and desde.map
	local marcas = pj().marcas
	local ahora, despues, fuera, notas = {}, {}, {}, {}
	local nivelExtra = 0
	local usadas = {}
	local antesDe = {} -- [qid] = lo que se agregó antes (Disp.TextoAntes)
	for _, it in ipairs(lista) do
		if Cr.Entra(it, filtro) then
			if it.enLog then
				ahora[#ahora + 1] = it.pm
				usadas[it.id] = true
			else
				-- Agregada a mano: su cadena (las previas que falten, en orden).
				local des = D.Desbloquear(it.id)
				if des.motivo then
					notas[#notas + 1] = format(L["%s no entra: %s."], M.Citar(it.titulo), D.Texto(des.motivo, des.info))
				else
					if des.linea then
						notas[#notas + 1] = format(L["%s pide %s: apréndela antes."], M.Citar(it.titulo), D.NombreProfesion(des.linea))
					end
					if des.antes then antesDe[it.id] = des.antes end
					local destino = des.nivel and despues or ahora
					if des.nivel then nivelExtra = max(nivelExtra, des.nivel) end
					for _, qid in ipairs(des.cadena) do
						if not usadas[qid] and not I.Hecha(qid) then
							usadas[qid] = true
							local C = CX()
							local q = C and C.Quest(qid)
							local pm = q and I.PasosMision(q, desde)
							if pm then
								pm.q = q
								destino[#destino + 1] = pm
							else
								notas[#notas + 1] = format(L["No sé dónde se entrega %s: la saqué del plan."], M.Citar(M.TituloMision(qid)))
							end
						end
						ceder()
					end
				end
			end
		elseif it.enLog then
			fuera[#fuera + 1] = it
		end
	end
	if #ahora + #despues == 0 then return nil, "nada" end
	-- Los puntos de todas las paradas, para medir el camino una vez.
	local puntos = { desde }
	for _, grupo in ipairs({ ahora, despues }) do
		for _, pm in ipairs(grupo) do
			for _, k in ipairs({ "dador", "objetivo", "fin" }) do if pm[k] then puntos[#puntos + 1] = pm[k] end end
		end
	end
	local costo, costoDesde = medidor(puntos, desde, ceder, alAvanzar)
	-- Cada parada dice su zona y si queda lejos; el plan avisa una vez cuántas
	-- entregas quedan en otras zonas y cuáles son.
	local zonas, otras, lejos = {}, 0, 0
	for _, grupo in ipairs({ ahora, despues }) do
		for _, pm in ipairs(grupo) do
			local s = pm.fin and costoDesde(pm.fin)
			pm.nota = notaDe(pm, s, aqui)
			local map = pm.fin and pm.fin.map
			if map and map ~= aqui then
				otras = otras + 1
				local z = M.Zona(map)
				if z and not zonas[z] then zonas[z] = true zonas[#zonas + 1] = z end
			end
			if s and s >= LEJOS and s < I.LEJOS then lejos = lejos + 1 end
		end
	end
	if otras > 0 then
		notas[#notas + 1] = format(otras == 1 and L["%d entrega queda en otra zona: %s."] or L["%d entregas quedan en otras zonas: %s."], otras, concat(zonas, ", "))
	end
	if lejos > 0 then
		notas[#notas + 1] = format(lejos == 1 and L["%d parada queda a más de 10 minutos: la flecha te dice si conviene volar o usar tu piedra de hogar."]
			or L["%d paradas quedan a más de 10 minutos: la flecha te dice si conviene volar o usar tu piedra de hogar."], lejos)
	end
	local pasos = P.PasosDe(ahora, desde, costo)
	-- Lo que pide un nivel: misiones de XP para llegar y el paso que lo espera.
	if #despues > 0 then
		if nivelExtra > I.Jugador().level then
			if idx then
				local ctx = { p = I.Jugador(), nivel = I.NivelDecimal(), real = I.Jugador().level, pos = desde, ancla = desde,
					usadas = usadas, puntos = {}, xp = 0, oro = 0 }
				local pt = { quests = {}, notas = notas }
				P.SubirHasta(ctx, nivelExtra, pt, idx, ceder)
				if #pt.antes > 0 then
					local xp = P.PasosMisiones(pt.antes, desde, ceder, notas)
					for _, s in ipairs(xp) do pasos[#pasos + 1] = s end
				end
			end
			pasos[#pasos + 1] = P.PasoNivel(nivelExtra)
		end
		local mas = P.PasosDe(despues, desde, costo)
		for _, s in ipairs(mas) do pasos[#pasos + 1] = s end
	end
	if #pasos == 0 then return nil, "vacio" end
	P.MarcarAntes(pasos, antesDe)
	local ultimo = pasos[#pasos]
	for _, it in ipairs(fuera) do
		local por = marcas[it.id] == "abandonar" and L["la marcaste para abandonar"] or (it.razones[1] or L["la dejaste fuera"])
		ultimo.goals[#ultimo.goals + 1] = { t = "note", text = format(L["Fuera de este plan: %s (%s)."], M.Citar(it.titulo), por) }
	end
	local listas, total = 0, #ahora + #despues
	for _, pm in ipairs(ahora) do if pm.listo then listas = listas + 1 end end
	if listas == total then
		P.Anotar(pasos[1], format(total == 1 and L["%d misión por entregar, en el orden más corto."] or L["%d misiones por entregar, en el orden más corto."], total))
	else
		P.Anotar(pasos[1], format(listas == 1 and L["%d misiones por cerrar (1 lista para entregar), en el orden más corto."]
			or L["%d misiones por cerrar (%d listas para entregar), en el orden más corto."], total, listas))
	end
	P.Anotar(pasos[1], L["La flecha usa vuelos y tu piedra de hogar cuando conviene."])
	local dentro = {}
	for _, grupo in ipairs({ ahora, despues }) do
		for _, pm in ipairs(grupo) do dentro[pm.q.id] = true end
	end
	return pasos, nil, notas, listas == total, dentro
end

-- Lo que el plan vio del registro al armarse: { filtro, log = { [qid] = lista? }, dentro = { [qid] = true } }
-- (Cr.AlDia lo compara con el registro de ahora).
local function selloDe(lista, filtro, dentro)
	local log = {}
	for _, it in ipairs(lista or {}) do
		if it.enLog then log[it.id] = it.listo and true or false end
	end
	return { filtro = filtro, log = log, dentro = dentro or {} }
end

function Cr.Armar(opts, alTerminar)
	opts = opts or {}
	local filtro = opts.filtro or Cr.Filtro()
	local ok, motivo = I.CodexListo()
	if not ok then return alTerminar(nil, motivo) end
	local function conLista(lista)
		local function seguir(idx)
			T.Lanzar("cerrar:armar", function(ceder)
				local pasos, por, notas, soloEntregar, dentro = armar(lista, filtro, idx, ceder, opts.alAvanzar)
				return { pasos = pasos, por = por, notas = notas, solo = soloEntregar, dentro = dentro }
			end, function(res, err)
				if not res or not res.pasos then
					return alTerminar(nil, err and "error" or (res and res.por) or "vacio", nil, selloDe(lista, filtro))
				end
				local mapa
				for _, s in ipairs(res.pasos) do
					for _, g in ipairs(s.goals) do if g.map then mapa = g.map break end end
					if mapa then break end
				end
				local def = M.Guias.Def(M.Guias.IdLiberar(), res.solo and L["Entregar mis misiones"] or L["Cerrar mis misiones"], res.pasos, {
					zone = mapa, pitch = L["Tus misiones abiertas, para terminarlas y entregarlas por el camino más corto."],
				})
				alTerminar(def, nil, res.notas, selloDe(lista, filtro, res.dentro))
			end)
		end
		-- Con agregadas que piden nivel hace falta el índice (misiones de XP).
		local pide = false
		for _, it in ipairs(lista) do if it.extra and not it.enLog and it.bloqueo == "nivel" then pide = true end end
		if pide then I.Pedir(function(idx) seguir(idx) end) else seguir(nil) end
	end
	-- Siempre con el registro de ahora.
	Cr.Revisar(function(lista, m)
		if not lista then return alTerminar(nil, m) end
		conLista(lista)
	end)
end

-- Un clic: arma, instala y abre la guía; avisa qué hizo.
function Cr.Ahora(filtro, alListo)
	M.Aviso(L["Armando «Cerrar mis misiones»..."], L["Alfa mide los caminos (vuelos y piedra de hogar): tarda unos segundos."], { icono = "ic-misiones" })
	Cr.Armar({ filtro = filtro }, function(def, motivo, notas, sello)
		if not def then
			local texto = (motivo == "nada" or motivo == "vacio") and L["No tienes misiones para este plan con ese filtro."] or I.TextoMotivo(motivo)
			M.Aviso(L["No armé el plan"], texto, { icono = "ic-aviso", tono = "aviso" })
			if alListo then alListo(false) end
			return
		end
		-- Pedido con un clic: empieza limpio, sin los pasos que omitiste en
		-- un plan anterior (Guias.Olvidar). El rearmado solo (Cr.Actualizar)
		-- sí conserva lo hecho.
		M.Guias.Olvidar(def.id)
		-- Y las misiones de tu registro que omitiste con «Omitir esta misión»
		-- (1.2.3): el motor las guarda por misión, para todas las guías, y
		-- sin esto cada plan nuevo las seguía saltando y quedaba sin paso.
		-- Pediste cerrarlas: vuelven.
		local Eng = M.Motor("Engine")
		if Eng and Eng.IsQuestSkipped and Eng.SkipQuest then
			for qid in pairs(sello and sello.dentro or {}) do
				if Eng.IsQuestSkipped(qid) then Eng.SkipQuest(qid, false) end
			end
		end
		local ok = M.Guias.Instalar(def)
		if not ok then
			M.Aviso(L["No armé el plan"], L["El motor no aceptó la guía."], { icono = "ic-aviso", tono = "aviso" })
			if alListo then alListo(false) end
			return
		end
		pj().liberarSello = sello
		local i, por = M.Guias.Abrir(def.id)
		-- Que abra en su paso de ahora, no en uno que mirabas del plan viejo
		-- (el motor puede volver a guardar ese paso al cambiar la guía).
		if i and Eng and Eng.GetLiveStep and Eng.GetStepIndex and Eng.Goto then
			local vivo = Eng.GetLiveStep()
			if vivo and Eng.GetStepIndex() ~= vivo then pcall(Eng.Goto, vivo) end
		end
		for k, n in ipairs(notas or {}) do
			if k > 3 then break end
			M.Aviso(L["Ojo con tu plan"], n, { icono = "ic-info", tono = "aviso" })
		end
		if i then
			M.Aviso(L["Plan en marcha"], L["Sigue la flecha: las paradas van en el orden más corto, juntas por PNJ."], { lobo = "aullando" })
		elseif por == "tabs" then
			M.EnCurso.AvisoLleno(L["Es el máximo a la vez. Quita una que ya no uses y vuelve a armar tu plan."])
		end
		M.Avisar("SEGUIR", "liberar")
		if alListo then alListo(i ~= nil) end
	end)
end

-- Abandona las marcadas, con la confirmación del Kit.
function Cr.AbandonarMarcadas()
	local ids, nombres = {}, {}
	for _, it in ipairs(revision or {}) do
		if pj().marcas[it.id] == "abandonar" and it.enLog then
			ids[#ids + 1] = it.id
			if #nombres < 6 then nombres[#nombres + 1] = "\194\183 " .. (it.titulo or "") end
		end
	end
	if #ids == 0 then return false end
	if #ids > #nombres then nombres[#nombres + 1] = format(L["y %d más"], #ids - #nombres) end
	M.K.Dialogo({
		titulo = format(#ids == 1 and L["¿Abandonar %d misión?"] or L["¿Abandonar %d misiones?"], #ids),
		texto = concat(nombres, "\n") .. "\n\n" .. L["Salen de tu registro. Para hacerlas otra vez tendrías que volver a pedirlas."],
		aceptar = L["Abandonar"], peligro = true,
		alAceptar = function()
			local n = P.Abandonar(ids)
			M.Aviso(M.Plural(n, L["Abandonaste %d misión"], L["Abandonaste %d misiones"]), nil, { icono = "ic-exito" })
			revision = nil
			M.Avisar("CERRAR")
		end,
	})
	return true
end

---------------------------------------------------------------------------
-- El plan al día con tu registro
---------------------------------------------------------------------------
-- El plan se arma con el registro de ese momento. Si mientras lo sigues
-- tomas una misión nueva (la que te da el PNJ al entregarle otra, aunque se
-- llame igual) o, en "Entregar mis misiones", una queda lista, el plan
-- abierto se arma otra vez solo, sin preguntar: el motor lleva lo hecho a la
-- guía nueva y la nueva misión entra con sus objetivos antes de su entrega.
-- En combate espera a que termine.

local ESPERA = 3 -- segundos sin cambios en el registro antes de rearmar
local programado, trasCombate, rearmando = false, false, false

-- ¿El registro de ahora trae algo que el plan no vio al armarse?
function Cr.AlDia()
	local s = pj().liberarSello
	if type(s) ~= "table" or type(s.log) ~= "table" then return true end
	local Cp = CP()
	if not (Cp and Cp.GetLogQuests) then return true end
	for _, qid in ipairs(Cp.GetLogQuests() or {}) do
		local antes = s.log[qid]
		if antes == nil and not pj().marcas[qid] then return false end
		if s.filtro == "listas" and antes == false and Cp.IsQuestReadyForTurnIn(qid) then return false end
	end
	return true
end

-- Rearma el plan abierto con el registro de ahora, sin avisos de armado; dice
-- qué entró. fn(bien) al terminar.
function Cr.Actualizar(alListo)
	local s = pj().liberarSello
	-- Un plan de una versión anterior no guardó qué vio: se rearma callado.
	local callado = type(s) ~= "table"
	local antes = not callado and type(s.dentro) == "table" and s.dentro or {}
	rearmando = true
	local filtro = not callado and s.filtro or nil
	if callado then
		local viejo = type(pj().especiales) == "table" and pj().especiales.liberar
		if type(viejo) == "table" and viejo.title == L["Entregar mis misiones"] then filtro = "listas" end
	end
	Cr.Armar({ filtro = filtro }, function(def, motivo, _, sello)
		rearmando = false
		local bien = false
		-- Sin nada que hacer (todo lo demás entregado) el plan se queda como está.
		if def and M.Guias.Instalar(def) then
			bien = true
			local nuevas = {}
			for qid in pairs(sello and sello.dentro or {}) do
				if not antes[qid] then nuevas[#nuevas + 1] = M.Citar(M.TituloMision(qid)) end
			end
			table.sort(nuevas)
			if #nuevas > 0 and not callado then
				local lista = #nuevas > 3 and (concat(nuevas, ", ", 1, 3) .. " " .. format(L["y %d más"], #nuevas - 3)) or concat(nuevas, ", ")
				M.Aviso(L["«Cerrar mis misiones» está al día"], format(#nuevas == 1 and L["Entró %s, con lo que pide antes de entregarla."]
					or L["Entraron %s, con lo que piden antes de entregarlas."], lista), { icono = "ic-misiones" })
			end
		end
		-- Lo visto se guarda aunque no entrara nada: no se vuelve a rearmar por lo mismo.
		if sello then pj().liberarSello = sello end
		if alListo then alListo(bien) end
	end)
end

local function revisarPlanAbierto()
	programado = false
	if not M.Guias.Abierta(M.Guias.IdLiberar()) then return end
	if InCombatLockdown and InCombatLockdown() then trasCombate = true return end
	if rearmando or T.Corriendo("cerrar:armar") or T.Corriendo("cerrar:revisar") then
		programado = true
		A.After(ESPERA, revisarPlanAbierto)
		return
	end
	if type(pj().liberarSello) ~= "table" or not Cr.AlDia() then Cr.Actualizar() end
end

local function programar()
	if programado then return end
	programado = true
	A.After(ESPERA, revisarPlanAbierto)
end

-- El registro cambió: la revisión vieja ya no vale.
local function olvidar()
	revision = nil
	generacion = generacion + 1
	M.Avisar("CERRAR")
	programar()
end
A.RegisterEvent("QUEST_ACCEPTED", olvidar)
A.RegisterEvent("QUEST_REMOVED", olvidar)
A.RegisterEvent("QUEST_TURNED_IN", olvidar)
-- "Entregar mis misiones": una que queda lista entra (la mira el sello, barato).
A.RegisterEvent("QUEST_LOG_UPDATE", function()
	local s = pj().liberarSello
	if type(s) == "table" and s.filtro == "listas" then programar() end
end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if trasCombate then trasCombate = false programar() end
end)
