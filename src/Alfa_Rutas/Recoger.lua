-- Alfa - Rutas: dos guías al momento. toxic3000 / La Jauría. GPL-3.0.
--
--   Recoger: las mejores misiones que ya puedes tomar cerca de ti (las de tu
--     nivel, de tu facción y clase, con sus previas hechas, sin pasarte del
--     espacio de tu registro), en el orden más corto y juntas por PNJ. Solo
--     se toman; después "Cerrar mis misiones" las termina y las entrega.
--   Desbloquear: una misión que aún no puedes tomar, con lo que pide antes:
--     sus previas en orden, misiones de XP hasta el nivel que pide y el paso
--     que espera ese nivel (la regla de la ruta: nunca mandarte a una misión
--     que todavía no se puede tomar).
--
--   Recoger.Ahora()            arma, instala y abre la guía
--   Recoger.Armar(fn(def | nil, motivo, n))
--   Recoger.Desbloquear(qid)   ídem para una misión

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local I, T, P, D = M.Indice, M.Tareas, M.Plan, M.Disp
local R = {}
M.Recoger = R

local type, ipairs, pairs, tonumber = type, ipairs, pairs, tonumber
local floor, max, min, format = math.floor, math.max, math.min, string.format

local CERCA = 420 -- segundos (línea recta): lo que se recoge queda a menos de 7 minutos
local MAXIMO = 10

local function CX() return M.Motor("Codex") end
local function CP() return M.Motor("Compat") end

-- Cuántas caben en el registro.
local function espacio()
	local Cp = CP()
	local tope = Cp and Cp.GetLogCap and Cp.GetLogCap() or 20
	local n = #(Cp and Cp.GetLogQuests and Cp.GetLogQuests() or {})
	return max(0, tope - n)
end

local function armar(idx, ceder)
	local C = CX()
	local p = I.Jugador()
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	if not desde then return nil, "lugar" end
	local cupo = min(MAXIMO, espacio())
	if cupo <= 0 then return nil, "lleno" end
	local Q = M.Motor("QuestDB")
	local gris = Q and Q.GreyLevel and Q.GreyLevel(p.level) or (p.level - 6)
	local nivel = I.NivelDecimal(p)
	local usadas = {}
	local elegidas = {}
	for i, e in ipairs(idx.lista) do
		if e.lvl > gris and e.lvl <= p.level + 2 and not I.EnRegistro(e.id) and I.Disponible(e, usadas, p.level) then
			local q = C.Quest(e.id)
			local dador = q and I.FinDe(q.start, desde, p)
			if dador then
				local t = I.Viaje(desde, dador)
				if t <= CERCA then
					local _, grupo, dentro, sinCargar = I.Objetivo(e, dador)
					if not dentro and not sinCargar then
						local v = I.XPPara(e, nivel) / (t + 60)
						if grupo then v = v * 0.2 end
						elegidas[#elegidas + 1] = { e = e, q = q, dador = dador, v = v }
					end
				end
			end
		end
		if i % 40 == 0 then ceder() end
	end
	table.sort(elegidas, function(a, b) return a.v > b.v end)
	local paradas = {}
	for k = 1, min(cupo, #elegidas) do
		local c = elegidas[k]
		local pm = I.PasosMision(c.q, desde)
		if pm and pm.aceptar then
			paradas[#paradas + 1] = { inP = c.dador, outP = c.dador, deps = {}, meta = pm.aceptar }
		end
		ceder()
	end
	if #paradas == 0 then return nil, "nada" end
	local orden = P.Ordenar(paradas, desde)
	local pasos, ultimo = {}, nil
	for _, i in ipairs(orden) do
		local meta = M.Copia(paradas[i].meta)
		local k = meta.npc and ("n" .. meta.npc) or (meta.object and ("o" .. meta.object)) or nil
		if ultimo and k and ultimo.k == k then
			ultimo.paso.goals[#ultimo.paso.goals + 1] = meta
		else
			local paso = { title = meta.npcName or meta.objName or meta.title, goals = { meta } }
			pasos[#pasos + 1] = paso
			ultimo = k and { k = k, paso = paso } or nil
		end
	end
	P.Anotar(pasos[1], M.Plural(#paradas, L["%d misión para tomar cerca de ti. Después, ciérrala con «Cerrar mis misiones»."], L["%d misiones para tomar cerca de ti. Después, ciérralas con «Cerrar mis misiones»."]))
	return pasos, nil, #paradas
end

function R.Armar(alTerminar)
	local ok, motivo = I.CodexListo()
	if not ok then return alTerminar(nil, motivo) end
	I.Pedir(function(idx, m)
		if not idx then return alTerminar(nil, m) end
		T.Lanzar("recoger", function(ceder)
			local pasos, por, n = armar(idx, ceder)
			return { pasos = pasos, por = por, n = n }
		end, function(res, err)
			if not (res and res.pasos) then return alTerminar(nil, err and "error" or (res and res.por) or "nada") end
			local def = M.Guias.Def(M.Guias.IdEspecial("recoger"), L["Recoger misiones"], res.pasos, {
				zone = (A.PlayerPoint and A.PlayerPoint() or {}).map,
				pitch = L["Las mejores misiones que ya puedes tomar cerca de ti, en el orden más corto."],
			})
			alTerminar(def, nil, res.n)
		end)
	end)
end

local function instalarYAbrir(def, exito)
	if not M.Guias.Instalar(def) then
		M.Aviso(L["No armé la guía"], L["No pude abrir la guía. Prueba en un momento; si sigue, cuéntanos con /alfa reportar."], { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	local i, por = M.Guias.Abrir(def.id)
	if i then
		M.Aviso(exito, L["Sigue la flecha."], { lobo = "aullando" })
	elseif por == "tabs" then
		M.EnCurso.AvisoLleno()
	end
	return i ~= nil
end

function R.Ahora()
	M.Aviso(L["Buscando misiones cerca…"], nil, { icono = "ic-misiones" })
	R.Armar(function(def, motivo, n)
		if not def then
			local texto = (motivo == "lleno" and L["Tu registro está lleno: cierra algunas misiones primero."])
				or (motivo == "nada" and L["No hay misiones para ti cerca de aquí. Prueba en el pueblo más cercano o sigue tu ruta."])
				or (motivo == "lugar" and L["No pude leer dónde estás."])
				or I.TextoMotivo(motivo)
			M.Aviso(L["Nada que recoger"], texto, { icono = "ic-info", tono = "neutro" })
			return
		end
		instalarYAbrir(def, M.Plural(n or 0, L["%d misión para recoger"], L["%d misiones para recoger"]))
		M.Avisar("SEGUIR", "recoger")
	end)
end

---------------------------------------------------------------------------
-- Desbloquear una misión
---------------------------------------------------------------------------

function R.Desbloquear(qid, alTerminar)
	qid = tonumber(qid)
	alTerminar = alTerminar or function() end
	if not qid then return alTerminar(false) end
	local ok, motivo = I.CodexListo()
	if not ok then
		M.Aviso(L["No armé la guía"], I.TextoMotivo(motivo), { icono = "ic-aviso", tono = "aviso" })
		return alTerminar(false)
	end
	local des = D.Desbloquear(qid)
	if des.motivo then
		M.Aviso(format(L["%s no se puede tomar"], M.Citar(M.TituloMision(qid))), D.Texto(des.motivo, des.info), { icono = "ic-aviso", tono = "aviso" })
		return alTerminar(false)
	end
	I.Pedir(function(idx)
		T.Lanzar("desbloquear", function(ceder)
			local desde = A.PlayerPoint and A.PlayerPoint() or nil
			local notas, pasos = {}, {}
			local real = I.Jugador().level
			-- Lo que ya se puede tomar va primero; si la cadena pide más nivel,
			-- misiones de XP y el paso que lo espera.
			local ya, luego = {}, {}
			local usadas = {}
			for _, q in ipairs(des.cadena) do
				local bien = D.Estado(q, { usadas = usadas, nivel = real })
				if bien and #luego == 0 then ya[#ya + 1] = q else luego[#luego + 1] = q end
				usadas[q] = true
			end
			local s1 = P.PasosMisiones(ya, desde, ceder, notas)
			for _, s in ipairs(s1) do pasos[#pasos + 1] = s end
			if #luego > 0 then
				if des.nivel and des.nivel > real and idx then
					local ctx = { p = I.Jugador(), nivel = I.NivelDecimal(), real = real, pos = desde, ancla = desde,
						usadas = usadas, puntos = {}, xp = 0, oro = 0 }
					local pt = { quests = {}, notas = notas }
					P.SubirHasta(ctx, des.nivel, pt, idx, ceder)
					local xp = P.PasosMisiones(pt.antes or {}, desde, ceder, notas)
					for _, s in ipairs(xp) do pasos[#pasos + 1] = s end
				end
				if des.nivel and des.nivel > real then pasos[#pasos + 1] = P.PasoNivel(des.nivel) end
				local s2 = P.PasosMisiones(luego, desde, ceder, notas)
				for _, s in ipairs(s2) do pasos[#pasos + 1] = s end
			end
			-- La misión dice lo que se agregó antes (el rastreador: "Antes: ...").
			P.MarcarAntes(pasos, { [qid] = des.antes })
			if des.linea then
				P.Anotar(pasos[1], format(L["Necesitas %s para esta cadena: apréndela con un instructor."], D.NombreProfesion(des.linea)))
			end
			return pasos
		end, function(pasos)
			if not (pasos and #pasos > 0) then
				M.Aviso(L["No armé la guía"], L["No encontré cómo llegar a esa misión."], { icono = "ic-aviso", tono = "aviso" })
				return alTerminar(false)
			end
			local titulo = format(L["Desbloquear %s"], M.TituloMision(qid))
			P.Anotar(pasos[1], format(L["Lo que pide %s antes, en orden."], M.Citar(M.TituloMision(qid))))
			local def = M.Guias.Def(M.Guias.IdEspecial("desbloquear"), titulo, pasos, {
				pitch = L["Las misiones previas y el nivel que pide, para poder tomarla."],
			})
			-- 1.2.6: de qué guía venías, para regresarte a ella al terminar
			-- (Rastreador.lua: antes te quedabas en «no tiene un paso para ti»).
			M.Guias.RecordarVuelta()
			alTerminar(instalarYAbrir(def, L["Guía para desbloquearla en marcha"]))
		end)
	end)
end
