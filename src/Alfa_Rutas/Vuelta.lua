-- Alfa - Rutas: «Vuelta a entregar» (toxic3000 / La Jauría). GPL-3.0.
-- 1.2.8
--
--   Vuelta.Listas(sinCargar) -> { { qid, titulo, p }, ... } | nil, motivo
--       tus misiones listas para entregar, con el PNJ que las recibe (el
--       punto del Codex: { map, x, y, f, z, kind, id, name }, coordenadas
--       0-100). sinCargar: si el Codex no está cargado, no lo carga: usa la
--       base de misiones (1.3.2, Ligero.lua) o da nil si tampoco está.
--   Vuelta.Paradas(lista) -> { { clave, p, nombre, misiones = { qid... } } }
--       las mismas, juntas por PNJ (dos misiones del mismo PNJ: una parada)
--   Vuelta.Ordenar(desde, paradas) -> paradas en orden
--       el vecino más cercano: desde donde estás, la parada más cerca, y desde
--       ahí la que sigue más cerca. En el mismo continente se mide en yardas
--       (Compat.MapToWorld); otro continente va después de todo lo de aquí.
--   Vuelta.Empezar() -> ok, motivo   arma la vuelta y pone la flecha en la primera
--   Vuelta.Cancelar()                la deja (la flecha vuelve a tu guía)
--   Vuelta.Estado() -> { i, total, parada } | nil
--   Vuelta.Aviso() -> el aviso del rastreador (en curso u ofrecerla) | nil
--
-- Con cada entrega (QUEST_TURNED_IN) la parada de esa misión queda hecha
-- cuando ya no le queda ninguna, y la flecha pasa a la siguiente. Una misión
-- que sale de tu registro sin entregarla (abandonada) también se quita.
-- El rastreador la ofrece con 2 o más misiones listas (rutas.vueltaEntregar)
-- y, mientras sigue, dice «Entrega 2 de 4». Nada en combate: la vuelta se
-- arma fuera de él (el Codex no se carga peleando).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local I = M.Indice
local Vt = {}
M.Vuelta = Vt

A.RegisterDefaults(M.ID, { vueltaEntregar = true })

local type, ipairs, pairs, tonumber, tostring = type, ipairs, pairs, tonumber, tostring
local sqrt, format, concat = math.sqrt, string.format, table.concat

local OTRO = 1e6 -- yardas: otro continente (o sin medida) va después de todo lo de aquí
local MIN_LISTAS = 2

local function CX() return M.Motor("Codex") end
local function CP() return M.Motor("Compat") end
local function enCombate() return InCombatLockdown and InCombatLockdown() or false end
local function secreto(v) return issecretvalue and issecretvalue(v) or false end

local est -- la vuelta en curso: { paradas, i, total, objetivo }
local despues = 0 -- «Después»: no se ofrece otra vez hasta tener más listas que estas

local function encendida() return A.Get(M.ID .. ".vueltaEntregar") ~= false end

---------------------------------------------------------------------------
-- Las listas y sus paradas
---------------------------------------------------------------------------

function Vt.Listas(sinCargar)
	if enCombate() then return nil, "combat" end
	local C, Cp = CX(), CP()
	if not (C and Cp and Cp.GetLogQuests) then return nil, "missing" end
	if sinCargar then
		-- 1.3.2: sin el Codex, la base de misiones dice a quién se entrega
		-- (Ligero.lua); sin ninguna de las dos, no se sabe.
		if not (C.IsLoaded and C.IsLoaded()) then
			local Lg = M.Ligero
			if not (Lg and Lg.Listo()) then return nil, "missing" end
			local desde = A.PlayerPoint and A.PlayerPoint() or nil
			local out = {}
			for _, qid in ipairs(Cp.GetLogQuests() or {}) do
				if Cp.IsQuestReadyForTurnIn(qid) then
					out[#out + 1] = { qid = qid, titulo = M.TituloMision(qid), p = Lg.Entrega(qid, desde) }
				end
			end
			return out
		end
	else
		local ok, motivo = I.CodexListo()
		if not ok then return nil, motivo end
	end
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	local p = I.Jugador()
	local out = {}
	for _, qid in ipairs(Cp.GetLogQuests() or {}) do
		if Cp.IsQuestReadyForTurnIn(qid) then
			local q = C.Quest and C.Quest(qid)
			local ok, fin = false, nil
			if q and I.FinDe then ok, fin = pcall(I.FinDe, q["end"], desde, p) end
			out[#out + 1] = { qid = qid, titulo = M.TituloMision(qid), p = ok and fin or nil }
		end
	end
	return out
end

local function claveDe(p)
	if p.id then return tostring(p.kind or "npc") .. ":" .. tostring(p.id) end
	return format("%s:%.1f:%.1f", tostring(p.map), M.num(p.x, 0), M.num(p.y, 0))
end

function Vt.Paradas(lista)
	local out, de = {}, {}
	for _, it in ipairs(lista or {}) do
		local p = it.p
		if p and p.map and p.x and p.y then
			local k = claveDe(p)
			local pa = de[k]
			if not pa then
				pa = { clave = k, p = p, nombre = p.name, misiones = {}, titulos = {} }
				de[k] = pa
				out[#out + 1] = pa
			end
			pa.misiones[#pa.misiones + 1] = it.qid
			pa.titulos[#pa.titulos + 1] = it.titulo or M.TituloMision(it.qid)
		end
	end
	return out
end

local function mundo(p)
	local Cp = CP()
	if not (p and p.map and p.x and p.y and Cp and Cp.MapToWorld) then return nil end
	local ok, c, wx, wy = pcall(Cp.MapToWorld, p.map, p.x, p.y, p.f)
	if ok and c and type(wx) == "number" and type(wy) == "number" then return c, wx, wy end
	return nil
end

local function distancia(a, b)
	if a.c ~= nil and a.c == b.c then
		local dx, dy = a.wx - b.wx, a.wy - b.wy
		return sqrt(dx * dx + dy * dy)
	end
	return OTRO + I.Viaje(a.p, b.p)
end

function Vt.Ordenar(desde, paradas)
	local quedan = {}
	for _, pa in ipairs(paradas or {}) do
		pa.c, pa.wx, pa.wy = mundo(pa.p)
		quedan[#quedan + 1] = pa
	end
	local aqui
	if desde then
		local c, wx, wy = mundo(desde)
		aqui = { p = desde, c = c, wx = wx, wy = wy }
	end
	local out = {}
	while #quedan > 0 do
		local mejor, md = 1, nil
		if aqui then
			for k, pa in ipairs(quedan) do
				local d = distancia(aqui, pa)
				if not md or d < md then mejor, md = k, d end
			end
		end
		local pa = table.remove(quedan, mejor)
		out[#out + 1] = pa
		aqui = pa
	end
	return out
end

---------------------------------------------------------------------------
-- La vuelta
---------------------------------------------------------------------------

local function avisar()
	M.Avisar("VUELTA")
	if M.Rastreador and M.Rastreador.Luego then M.Rastreador.Luego() end
end

local function nombreDe(pa)
	local n = pa and pa.nombre
	if type(n) == "string" and n ~= "" and not secreto(n) then return n end
	return L["Quien recibe la misión"]
end

local function apuntar()
	local pa = est and est.paradas[est.i]
	local Nav = A.Nav
	if not (pa and Nav and type(Nav.SetTarget) == "function") then return false end
	local p = pa.p
	local ok, t = pcall(Nav.SetTarget, p.map, p.x, p.y, nombreDe(pa), p.f, nil, p.z)
	if not (ok and t) then return false end
	est.objetivo = t
	if type(Nav.StartTrip) == "function" then pcall(Nav.StartTrip, t, nombreDe(pa), L["Vuelta a entregar"]) end
	return true
end
Vt.Apuntar = apuntar

local function soltarFlecha()
	local Nav = A.Nav
	local t = est and est.objetivo
	if not (t and Nav and Nav.GetTarget) then return end
	local ok, actual = pcall(Nav.GetTarget)
	if ok and actual == t then
		if Nav.Trip and Nav.Trip() and Nav.EndTrip then pcall(Nav.EndTrip)
		elseif Nav.ReleaseTarget then pcall(Nav.ReleaseTarget) end
	end
end

-- 1.3.7: la vuelta sigue después de /reload o de reconectarte (87): se
-- guarda por personaje (M.Personaje().vuelta) y se retoma al entrar con lo
-- que siga en tu registro.
local function guardar()
	local d = M.Personaje()
	if not est then d.vuelta = nil return end
	local paradas = {}
	for k, pa in ipairs(est.paradas) do
		paradas[k] = { clave = pa.clave, p = pa.p, nombre = pa.nombre, misiones = pa.misiones, titulos = pa.titulos }
	end
	d.vuelta = { paradas = paradas, i = est.i, total = est.total, hechas = est.hechas }
end
Vt.Guardar = guardar

function Vt.Retomar()
	local d = M.Personaje()
	local g = d.vuelta
	if est or type(g) ~= "table" or type(g.paradas) ~= "table" then return false end
	local Cp = CP()
	est = { paradas = {}, i = 1, hechas = type(g.hechas) == "table" and g.hechas or {} }
	for k, pa in ipairs(g.paradas) do
		if type(pa) == "table" and type(pa.p) == "table" and type(pa.misiones) == "table" then
			est.paradas[#est.paradas + 1] = pa
			if k == (tonumber(g.i) or 1) then est.i = #est.paradas end
		end
	end
	est.total = #est.paradas
	-- Lo que ya no está en tu registro (lo entregaste sin Alfa) se salta.
	while est.paradas[est.i] and not (Cp and Cp.IsOnQuest and Vt.Pendiente(est.paradas[est.i], est.hechas)) do est.i = est.i + 1 end
	if est.total == 0 or est.i > est.total then
		est = nil
		d.vuelta = nil
		return false
	end
	apuntar()
	guardar()
	avisar()
	return true
end
A.OnLogin(function() A.After(3, function() if not enCombate() then Vt.Retomar() end end) end)

function Vt.Estado()
	if not est then return nil end
	return { i = est.i, total = est.total, parada = est.paradas[est.i] }
end

function Vt.Empezar()
	if enCombate() then
		M.Aviso(L["Vuelta a entregar"], L["Se puede al salir de combate."], { icono = "ic-aviso", tono = "aviso" })
		return false, "combat"
	end
	local lista, motivo = Vt.Listas()
	if not lista then
		M.Aviso(L["Vuelta a entregar"], I.TextoMotivo(motivo), { icono = "ic-aviso", tono = "aviso" })
		return false, motivo
	end
	-- 1.3.7: cuenta igual al ofrecerla y al empezarla (76): tus misiones
	-- listas del registro. Las que no se sabe dónde se entregan quedan fuera
	-- y se dicen; con una sola que sí se sabe, la vuelta va igual.
	local paradas = Vt.Paradas(lista)
	local n = 0
	for _, pa in ipairs(paradas) do n = n + #pa.misiones end
	local fuera = {}
	local dentro = {}
	for _, pa in ipairs(paradas) do for _, q in ipairs(pa.misiones) do dentro[q] = true end end
	local fueraQ = {}
	for _, it in ipairs(lista) do
		if not dentro[it.qid] then
			fuera[#fuera + 1] = M.Citar(it.titulo or M.TituloMision(it.qid))
			fueraQ[it.qid] = true
		end
	end
	if #lista < MIN_LISTAS or n == 0 then
		local texto = #lista < MIN_LISTAS and format(L["Necesitas al menos %d misiones listas para entregar."], MIN_LISTAS)
			or format(L["No sé dónde se entregan: %s."], table.concat(fuera, ", "))
		M.Aviso(L["Vuelta a entregar"], texto, { icono = "ic-info", tono = "info" })
		return false, "pocas"
	end
	if est then soltarFlecha() end
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	est = { paradas = Vt.Ordenar(desde, paradas), i = 1, fuera = fueraQ }
	est.total = #est.paradas
	apuntar()
	M.Empezar()
	local pa = est.paradas[1]
	local texto = format(L["Entrega 1 de %d: %s."], est.total, nombreDe(pa))
	if #fuera > 0 then texto = texto .. " " .. format(L["Fuera de la vuelta (no sé dónde se entregan): %s."], table.concat(fuera, ", ")) end
	M.Aviso(L["Vuelta a entregar"], texto, { icono = "ic-misiones" })
	guardar()
	avisar()
	return true
end
Vt.MIN = MIN_LISTAS

function Vt.Cancelar(callado)
	if not est then return false end
	soltarFlecha()
	est = nil
	guardar()
	if not callado then M.Aviso(L["Vuelta a entregar"], L["Dejaste la vuelta: la flecha vuelve a tu guía."], { icono = "ic-misiones" }) end
	avisar()
	return true
end

-- ¿A la parada le queda algo por entregar?
local function pendiente(pa, hechas)
	local Cp = CP()
	for _, q in ipairs(pa.misiones) do
		if not hechas[q] and Cp and Cp.IsOnQuest and Cp.IsOnQuest(q) then return true end
	end
	return false
end
Vt.Pendiente = pendiente

-- 1.3.7: la misión que terminas a medio camino se suma a la vuelta (88): a
-- la parada de su PNJ si ya va, o a una nueva en el orden más corto desde
-- donde vas.
function Vt.Sumar()
	if not est or enCombate() then return 0 end
	local Cp = CP()
	if not (Cp and Cp.GetLogQuests and Cp.IsQuestReadyForTurnIn) then return 0 end
	-- 1.3.7: las de «fuera de la vuelta» (no se sabe dónde se entregan) también
	-- cuentan como vistas: si no, cada QUEST_LOG_UPDATE rehacía todo.
	est.fuera = est.fuera or {}
	local ya = {}
	for q in pairs(est.fuera) do ya[q] = true end
	for _, pa in ipairs(est.paradas) do for _, q in ipairs(pa.misiones) do ya[q] = true end end
	local nuevas = false
	for _, q in ipairs(Cp.GetLogQuests() or {}) do
		if not ya[q] and Cp.IsQuestReadyForTurnIn(q) then nuevas = true break end
	end
	if not nuevas then return 0 end
	local C = CX()
	local lista = Vt.Listas(not (C and C.IsLoaded and C.IsLoaded()))
	if not lista then return 0 end
	local sumadas = {}
	local nuevasParadas = {}
	for _, it in ipairs(lista) do
		if not ya[it.qid] and it.p and it.p.map and it.p.x and it.p.y then
			local k = claveDe(it.p)
			local pa
			for j = est.i, est.total do if est.paradas[j] and est.paradas[j].clave == k then pa = est.paradas[j] break end end
			if not pa then
				for _, x in ipairs(nuevasParadas) do if x.clave == k then pa = x break end end
			end
			if not pa then
				pa = { clave = k, p = it.p, nombre = it.p.name, misiones = {}, titulos = {} }
				nuevasParadas[#nuevasParadas + 1] = pa
			end
			pa.misiones[#pa.misiones + 1] = it.qid
			pa.titulos[#pa.titulos + 1] = it.titulo or M.TituloMision(it.qid)
			sumadas[#sumadas + 1] = M.Citar(it.titulo or M.TituloMision(it.qid))
			ya[it.qid] = true
		end
	end
	-- Las listas que no entraron (sin PNJ conocido) quedan anotadas como fuera.
	for _, q in ipairs(Cp.GetLogQuests() or {}) do
		if not ya[q] and Cp.IsQuestReadyForTurnIn(q) then est.fuera[q] = true end
	end
	if #sumadas == 0 then return 0 end
	if #nuevasParadas > 0 then
		-- Lo que queda después de la parada de ahora, otra vez en orden.
		local resto = {}
		for j = est.i + 1, est.total do resto[#resto + 1] = est.paradas[j] end
		for _, x in ipairs(nuevasParadas) do resto[#resto + 1] = x end
		local actual = est.paradas[est.i]
		local orden = Vt.Ordenar(actual and actual.p, resto)
		for j = #est.paradas, est.i + 1, -1 do est.paradas[j] = nil end
		for _, x in ipairs(orden) do est.paradas[#est.paradas + 1] = x end
		est.total = #est.paradas
	end
	M.Aviso(L["Vuelta a entregar"], format(L["Sumé a tu vuelta: %s."], table.concat(sumadas, ", ")), { icono = "ic-misiones" })
	guardar()
	avisar()
	return #sumadas
end
A.RegisterEvent("QUEST_LOG_UPDATE", function()
	if est and N and N.Una then N.Una("rutas.vueltaSumar", 1, Vt.Sumar) end
end)

-- Una misión entregada (o que salió del registro): la vuelta sigue.
function Vt.AlEntregar(qid)
	if not est then return end
	qid = tonumber(qid)
	est.hechas = est.hechas or {}
	if qid then est.hechas[qid] = true end
	local antes = est.i
	while est.paradas[est.i] and not pendiente(est.paradas[est.i], est.hechas) do est.i = est.i + 1 end
	if est.i > est.total then
		soltarFlecha()
		local total = est.total
		est = nil
		guardar()
		M.Aviso(L["¡Vuelta completa!"], format(total == 1 and L["Entregaste todo en %d parada."] or L["Entregaste todo en %d paradas."], total),
			{ lobo = "aullando", tono = "exito" })
		avisar()
		return
	end
	if est.i ~= antes then
		apuntar()
		M.Aviso(L["Vuelta a entregar"], format(L["Entrega %d de %d: %s."], est.i, est.total, nombreDe(est.paradas[est.i])), { icono = "ic-misiones" })
	end
	guardar()
	avisar()
end

A.RegisterEvent("QUEST_TURNED_IN", function(_, q)
	if not est or secreto(q) then return end
	local Cp = CP()
	if Cp and Cp.Readable then q = Cp.Readable(q) end
	-- (el registro se pone al día un instante después de la entrega)
	A.After(0.5, function() Vt.AlEntregar(q) end)
end)
-- Una abandonada: ya no se espera.
A.RegisterEvent("QUEST_REMOVED", function() if est then A.After(0.5, function() Vt.AlEntregar(nil) end) end end)

---------------------------------------------------------------------------
-- En el rastreador
---------------------------------------------------------------------------

local function textoParada(pa)
	local t = pa.titulos or {}
	if #t == 0 then return nombreDe(pa) end
	if #t == 1 then return nombreDe(pa) .. ": " .. M.Citar(t[1]) end
	return format(L["%s: %d misiones"], nombreDe(pa), #t)
end

function Vt.Aviso()
	if est then
		local pa = est.paradas[est.i]
		if not pa then return nil end
		return { tono = "exito", icono = "ic-misiones",
			titulo = format(L["Vuelta a entregar · Entrega %d de %d"], est.i, est.total),
			texto = textoParada(pa),
			uno = { L["Llévame"], function() apuntar() M.Empezar() end },
			dos = { L["Dejar la vuelta"], function() Vt.Cancelar() end } }
	end
	if not encendida() then return nil end
	local n = M.Cerrar and M.Cerrar.ListasAhora() or 0
	if n < MIN_LISTAS then
		despues = 0
		return nil
	end
	if n <= despues then return nil end
	-- 1.3.7: ya las estás entregando con «Cerrar mis misiones» (85).
	if Vt.Entregando() then return nil end
	return { tono = "info", icono = "ic-misiones",
		titulo = format(L["Tienes %d misiones listas"], n),
		texto = L["Alfa las ordena por el camino más corto y te lleva de una en una."],
		uno = { L["Vuelta a entregar"], function() Vt.Empezar() end },
		dos = { L["Después"], function() despues = n avisar() end } }
end

-- 1.3.7: ¿ya estás entregando tus misiones? Con la vuelta en curso o con tu
-- guía de ahora «Cerrar mis misiones» (85).
function Vt.Entregando()
	if est then return true end
	local E = A.Engine
	local g = E and E.GetGuide and E.GetGuide()
	local id = type(g) == "table" and g.id or nil
	return id ~= nil and M.Guias and M.Guias.Especial and M.Guias.Especial(id) == "liberar" or false
end

-- 1.3.7: una sola manera de entregar tus misiones listas (86), con el mismo
-- número en todos lados (Vt.MIN): la vuelta por el camino más corto; con la
-- vuelta apagada, el plan de «Cerrar mis misiones» con solo las listas.
function M.EntregarListas()
	if encendida() then
		local ok, por = Vt.Empezar()
		if ok or por == "combat" or por == "pocas" then return ok end
	end
	M.Cerrar.Ahora("listas")
	return true
end

-- Para el banco.
function Vt.Reiniciar() est, despues = nil, 0 M.Personaje().vuelta = nil end
