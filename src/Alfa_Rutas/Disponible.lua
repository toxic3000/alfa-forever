-- Alfa - Rutas: si una misión se puede tomar ya y, si no, qué falta para
-- tomarla. toxic3000 / La Jauría. GPL-3.0.
--
-- Regla de la ruta: nunca mandarte a una misión que no puedes hacer, a menos
-- de que la ruta agregue lo que falta. Se mira el nivel, las misiones previas
-- ("todas" y "una de"), las excluyentes, la facción, la raza, la clase, las
-- fiestas, la profesión y la reputación, con la base de misiones del motor
-- (A.QuestDB, la más completa) y el Codex (A.Codex: previas, nivel, reputación)
-- y con lo que dice el juego (C_QuestLog: hechas y en el registro; tu nivel,
-- tus profesiones y tus reputaciones).
--
-- Lo que falta se arregla de dos formas, sin preguntar:
--   - se agrega antes (las previas en orden, con sus propias previas; un nivel
--     que falta: misiones de XP y el paso "Llega a nivel N", Plan.lua);
--   - o, si no se arregla haciendo algo (otra facción, raza o clase, una fiesta,
--     una excluyente ya hecha, una profesión que no tienes, una reputación que
--     no alcanzas), la misión queda fuera con su motivo.
--
--   Disp.Cargar() -> bool                      carga la base de misiones (nunca en combate)
--   Disp.Estado(qid, opts) -> ok, motivo, info opts = { usadas = { [qid] = true }, nivel = n }
--       motivo: "registro" (ya la tienes; ok) | "hecha" | "nivel" | "previas" | "excluida"
--               | "profesion" | "reputacion" | "faccion" | "raza" | "clase" | "fiesta"
--               | "gris" | "desconocida"
--       info:   { nivel = mínimo, faltan = { qid, ... }, linea = profesión, rep = { faccion, nivel } }
--   Disp.Texto(motivo, info) -> "Disponible a nivel 20", "Antes: ...", ...
--   Disp.Imposible(motivo) -> bool             no se arregla haciendo algo (facción, clase...)
--   Disp.Resolver(qid, opts) -> res            lo que hay que hacer para tomarla, recursivo
--       res = { ok, cadena = { qid, ... } (en orden, la misión al final), nivel (si pide
--               más que el tuyo), dep = { [qid] = { previas de la cadena } }, motivo, info,
--               bloquea (la misión de la cadena que la cierra) }
--   Disp.Desbloquear(qid) -> { cadena = { qid, ... }, nivel, motivo?, info?, bloquea?, antes? }
--   Disp.TextoAntes(cadena, nivel) -> "«A», «B», nivel 20" | nil (sin la misión misma)
--   Disp.Bloqueo(qid) -> texto | nil           lo que la cierra sin remedio (para el motor)
--   Disp.Resumen(qid) -> antes | nil, noDisponible | nil   (para Mis planes)
--   Disp.Cadena(qid) -> { { quest, title, step, preAll }, ... } | nil
--       los pasos de la cadena que trae qid, para que el motor los meta en una
--       guía que no la da (A.Requisitos.Cadena, Own.alfaFeeder del motor)
--
-- El motor pregunta Bloqueo y Cadena por A.Requisitos (tools/parches.py,
-- REQUISITOS): sin eso todo sigue como antes.

local ADDON, M = ...
local A, L = M.A, M.L
local D = {}
M.Disp = D

local type, ipairs, pairs, tonumber, tostring = type, ipairs, pairs, tonumber, tostring
local floor, max, format, concat = math.floor, math.max, string.format, table.concat

local MAX_PROFUNDO = 10 -- previas de previas que se siguen, como mucho
local REP_NEUTRAL = 4

local function CP() return M.Motor("Compat") end
local function CX() return M.Motor("Codex") end
local function LK() return M.Motor("Lookup") end
local function QD() return M.Motor("QuestDB") end

local function hecha(q)
	local C = CP()
	return C and C.IsQuestCompleted and C.IsQuestCompleted(q) or false
end

local function enRegistro(q)
	local C = CP()
	return C and C.IsOnQuest and C.IsOnQuest(q) or false
end

function D.Cargar()
	local Q = QD()
	if not Q then return false end
	if Q.IsLoaded and Q.IsLoaded() then return true end
	if InCombatLockdown and InCombatLockdown() then return false end
	if Q.Load then pcall(Q.Load) end
	return Q.IsLoaded and Q.IsLoaded() or false
end

local function cargada()
	local Q = QD()
	return Q and Q.IsLoaded and Q.IsLoaded() and Q.CheckAvailable and true or false
end

local function codexListo()
	local C = CX()
	return C and C.IsLoaded and C.IsLoaded() and true or false
end

-- El rango de una profesión: 0 si no la tienes, nil si el cliente no lo dice
-- (entonces no se cierra nada por eso).
local function rango(linea)
	local C = CP()
	if not (C and C.GetSkillRank) then return nil end
	if C.Supports and not C.Supports("skill") then return nil end
	local r = C.GetSkillRank(linea)
	return type(r) == "number" and r or 0
end

-- Tu reputación con una facción (1 Odiado .. 8 Exaltado); neutral si el
-- juego no la conoce todavía.
local function reputacion(faccion)
	local C = CP()
	local r = C and C.GetFactionStanding and C.GetFactionStanding(faccion)
	return type(r) == "number" and r or REP_NEUTRAL
end

local function jugador()
	local Lk = LK()
	local p = Lk and Lk.PlayerInfo and Lk.PlayerInfo() or {}
	p.level = M.num(p.level, 1)
	return p
end

-- Los motivos de la base de misiones, en los nuestros.
local DE_QDB = {
	eligibility = "faccion", done = "hecha", active = "registro", level = "nivel", grey = "gris",
	prerequisite = "previas", exclusive = "excluida", skill = "profesion", unknown = "desconocida",
}

-- Un campo de lista de la base (un número o una tabla con huecos al final).
local function lista(v)
	if type(v) == "number" then return { v } end
	local out = {}
	if type(v) == "table" then
		for _, x in ipairs(v) do out[#out + 1] = x end
	end
	return out
end

---------------------------------------------------------------------------
-- La ficha de una misión: sus requisitos, de la base y del Codex
---------------------------------------------------------------------------

local fichas = {} -- qid -> ficha | false (ninguna base la conoce)

-- -> { id, min, preAll, preAny, excl, skill, fiesta, repF, repS, qdb, cx } | nil
-- Nunca carga datos: sin la base ni el Codex cargados no hay ficha.
local function ficha(qid)
	local f = fichas[qid]
	local conQDB = cargada()
	if f ~= nil and (f == false or f.conQDB == conQDB) then return f or nil end
	local Q = conQDB and QD() or nil
	local r = Q and Q.QuestRecord(qid)
	local C = CX()
	local cq = codexListo() and C.Quest(qid) or nil
	if not (r or cq) then
		if conQDB or codexListo() then fichas[qid] = false end
		return nil
	end
	f = { id = qid, conQDB = conQDB }
	if r then
		local F = Q.F
		f.qdb = r
		f.min = tonumber(r[F.MIN])
		f.preAll, f.preAny, f.excl = lista(r[F.PRE_ALL]), lista(r[F.PRE]), lista(r[F.EXCL])
		f.skill = tonumber(r[F.SKILL])
		f.fiesta = r[F.HOLIDAY] and true or nil
	end
	if cq then
		f.cx = cq
		f.min = f.min or tonumber(cq.minLevel)
		if not r then f.preAll, f.preAny, f.excl = lista(cq.pre), lista(cq.preAny), {} end
		f.repF, f.repS = tonumber(cq.repFaction), tonumber(cq.repStanding)
	end
	fichas[qid] = f
	return f
end

-- La clase, la raza o la facción que la cierran: para decirlo claro.
local function porQuien(qid, p)
	local C, Lk = CX(), LK()
	local q = codexListo() and C.Quest(qid)
	if not (q and Lk and Lk.QuestBlock) then return "faccion" end
	local pp = {}
	for k, v in pairs(p or jugador()) do pp[k] = v end
	pp.level = 999
	local why = Lk.QuestBlock(q, pp)
	if why == "race" then return "raza" end
	if why == "class" then return "clase" end
	return "faccion"
end

-- Lo que la cierra a ella misma, sin contar sus previas ni el nivel: lo que
-- no se arregla haciendo otras misiones. usadas: las que la ruta hace antes.
-- -> motivo, info | nil
local function cerrada(f, p, usadas)
	local q = f.id
	if f.qdb then
		local Q = QD()
		local ctx = Q.PlayerContext and Q.PlayerContext(nil, {}) or {}
		if Q.IsEligible and not Q.IsEligible(f.qdb, ctx) then
			if f.fiesta then return "fiesta", {} end
			return porQuien(q, p), {}
		end
	elseif f.cx then
		local Lk = LK()
		if Lk and Lk.QuestBlock then
			local pp = {}
			for k, v in pairs(p) do pp[k] = v end
			pp.level = 999
			local why = Lk.QuestBlock(f.cx, pp)
			if why == "faction" then return "faccion", {} end
			if why == "race" then return "raza", {} end
			if why == "class" then return "clase", {} end
		end
	end
	for _, x in ipairs(f.excl or {}) do
		if hecha(x) or enRegistro(x) or (usadas and usadas[x]) then return "excluida", { por = x } end
	end
	if f.skill and rango(f.skill) == 0 then return "profesion", { linea = f.skill } end
	if f.repF and f.repS and reputacion(f.repF) < f.repS then
		return "reputacion", { rep = { faccion = f.repF, nivel = f.repS } }
	end
	return nil
end

-- Las previas que faltan de una misión (todas las de `preAll` y una de `pre`
-- en la base; todas las de `pre` y una de `preAny` en el Codex).
local function faltanQDB(r, F, hechaFn)
	local out = {}
	for _, p in ipairs(lista(r[F.PRE_ALL])) do if not hechaFn(p) then out[#out + 1] = p end end
	local any = lista(r[F.PRE])
	if #any > 0 then
		local una = false
		for _, p in ipairs(any) do if hechaFn(p) then una = true break end end
		if not una then out[#out + 1] = any[1] end
	end
	return out
end

local function faltanCodex(q, hechaFn)
	local out = {}
	for _, p in ipairs(q.pre or {}) do if not hechaFn(p) then out[#out + 1] = p end end
	local any = q.preAny
	if type(any) == "table" and #any > 0 then
		local una = false
		for _, p in ipairs(any) do if hechaFn(p) then una = true break end end
		if not una then out[#out + 1] = any[1] end
	end
	return out
end

function D.Estado(qid, opts)
	qid = tonumber(qid)
	if not qid then return false, "desconocida", {} end
	opts = opts or {}
	local usadas = opts.usadas or {}
	if enRegistro(qid) then return true, "registro", {} end
	if hecha(qid) or usadas[qid] then return false, "hecha", {} end
	local p = jugador()
	local nivel = floor(M.num(opts.nivel, p.level))
	local function hechaFn(q) return usadas[q] or hecha(q) end
	-- La reputación solo la sabe el Codex: se mira siempre.
	local f = ficha(qid)
	local function conRep(ok, m, info)
		if f and f.repF and f.repS and (ok or m == "previas" or m == "nivel") and reputacion(f.repF) < f.repS then
			return false, "reputacion", { rep = { faccion = f.repF, nivel = f.repS } }
		end
		return ok, m, info
	end
	if cargada() then
		local Q = QD()
		local ctx = Q.PlayerContext and Q.PlayerContext(nil, {}) or {}
		ctx.level = nivel
		local ok, why = Q.CheckAvailable(qid, ctx, hechaFn, function(q) return enRegistro(q) or (usadas[q] and true or false) end,
			{ lowLevel = true, skillRank = rango })
		if ok then return conRep(true, nil, {}) end
		local r = Q.QuestRecord(qid)
		local F = Q.F
		if why ~= "unknown" and r and F then
			local m = DE_QDB[why] or "desconocida"
			local info = { nivel = r[F.MIN], linea = r[F.SKILL] }
			if m == "faccion" then
				if r[F.HOLIDAY] then m = "fiesta" else m = porQuien(qid, p) end
			elseif m == "previas" then
				info.faltan = faltanQDB(r, F, hechaFn)
			end
			return conRep(false, m, info)
		end
	end
	-- Sin la base de misiones: el Codex.
	local C, Lk = CX(), LK()
	local q = codexListo() and C.Quest(qid)
	if not q then return false, "desconocida", {} end
	if Lk and Lk.QuestBlock then
		local pp = {}
		for k, v in pairs(p) do pp[k] = v end
		pp.level = nivel
		local why = Lk.QuestBlock(q, pp)
		if why == "faction" then return false, "faccion", {} end
		if why == "race" then return false, "raza", {} end
		if why == "class" then return false, "clase", {} end
		if why == "done" then return false, "hecha", {} end
		if why == "level" then return conRep(false, "nivel", { nivel = q.minLevel }) end
	end
	local faltan = faltanCodex(q, hechaFn)
	if #faltan > 0 then return conRep(false, "previas", { faltan = faltan, nivel = q.minLevel }) end
	return conRep(true, nil, {})
end

-- Lo que se arregla haciendo algo (subir de nivel, hacer las previas) frente
-- a lo que no (o no haciendo misiones: aprender una profesión, subir una
-- reputación). "desconocida" (las bases no cargaron o no está la misión) no
-- es ninguna de las dos: no se omite ni se bloquea por eso.
local IMPOSIBLE = { faccion = true, raza = true, clase = true, hecha = true, excluida = true, fiesta = true,
	profesion = true, reputacion = true }
function D.Imposible(motivo) return IMPOSIBLE[motivo] or false end

local function nombreProfesion(linea)
	local Lk = LK()
	local en = linea and Lk and Lk.ProfessionName and Lk.ProfessionName(linea)
	if not en then return L["su profesión"] end
	local EL = A.L
	return (type(EL) == "table" and EL[en]) or en
end
D.NombreProfesion = nombreProfesion

local function nombreFaccion(id)
	local C = CP()
	local nombre = C and C.GetFactionStanding and select(5, C.GetFactionStanding(id))
	if type(nombre) == "string" and nombre ~= "" then return nombre end
	local X = CX()
	local f = codexListo() and X.Faction and X.Faction(id)
	return f and f.name or format(L["la facción %d"], tonumber(id) or 0)
end

local function nombreRango(n)
	local f = A.StandingName
	local s = type(f) == "function" and f(n) or nil
	return type(s) == "string" and s ~= "" and s or format(L["rango %d"], tonumber(n) or 0)
end

-- "«A», «B» y más": las misiones de una lista, para un texto corto.
local function citarVarias(ids, tope)
	local t = {}
	for i, q in ipairs(ids or {}) do
		if i > (tope or 2) then t[#t + 1] = L["y más"] break end
		t[#t + 1] = M.Citar(M.TituloMision(q))
	end
	return t
end

function D.Texto(motivo, info)
	info = info or {}
	-- Una de la cadena (no la misión misma) es la que no se puede.
	if info.bloquea and info.objetivo and info.bloquea ~= info.objetivo and IMPOSIBLE[motivo] then
		local sub = {}
		for k, v in pairs(info) do sub[k] = v end
		sub.bloquea, sub.objetivo = nil, nil
		return format(L["Antes pide %s (%s)"], M.Citar(M.TituloMision(info.bloquea)), D.Texto(motivo, sub))
	end
	if motivo == "nivel" then return format(L["Disponible a nivel %d"], M.num(info.nivel, 1)) end
	if motivo == "previas" then
		local t = citarVarias(info.faltan, 2)
		if #t == 0 then return L["Antes hay que hacer otra misión"] end
		return format(L["Antes: %s"], concat(t, ", "))
	end
	if motivo == "profesion" then return format(L["Necesitas %s"], nombreProfesion(info.linea)) end
	if motivo == "reputacion" then
		local rep = info.rep or {}
		return format(L["Necesitas %s con %s"], nombreRango(rep.nivel), nombreFaccion(rep.faccion))
	end
	if motivo == "faccion" then return L["Es de la otra facción"] end
	if motivo == "raza" then return L["No es para tu raza"] end
	if motivo == "clase" then return L["No es para tu clase"] end
	if motivo == "hecha" then return L["Ya la hiciste"] end
	if motivo == "excluida" then return L["Cerrada: hiciste otra que la excluye"] end
	if motivo == "fiesta" then return L["Solo en una fiesta del año"] end
	if motivo == "gris" then return L["Ya no da experiencia"] end
	if motivo == "registro" then return L["Ya está en tu registro"] end
	return L["No sé si se puede tomar"]
end

---------------------------------------------------------------------------
-- Lo que hay que hacer para tomarla: previas de previas, en orden
---------------------------------------------------------------------------

-- Agrega a `a` las de `b` que no estén.
local function sumar(a, b, en)
	for _, q in ipairs(b) do
		if not en[q] then
			en[q] = true
			a[#a + 1] = q
		end
	end
end

-- ctx = { usadas, visitando, memo, dep, p }. Una misión hecha (o que la ruta
-- hace antes) no pide nada; una del registro solo hay que entregarla. Las
-- previas "todas" se hacen todas; de las "una de" basta la que ya tienes en
-- el registro o la más corta que se pueda (la que no pida más nivel primero).
-- Un ciclo en los datos o una cadena muy honda no cierra nada: se sigue
-- hasta ahí. -> ok, lista (en orden, ella al final), nivel, motivo, info
local function visitar(qid, ctx, prof)
	if ctx.usadas[qid] or hecha(qid) then return true, {}, 0 end
	local memo = ctx.memo[qid]
	if memo then return memo[1], memo[2], memo[3], memo[4], memo[5] end
	if ctx.visitando[qid] then return true, {}, 0 end
	if enRegistro(qid) then
		ctx.dep[qid] = ctx.dep[qid] or {}
		return true, { qid }, 0
	end
	local f = ficha(qid)
	if not f then return true, { qid }, 0 end
	local m, info = cerrada(f, ctx.p, ctx.usadas)
	if m then
		info.bloquea = qid
		ctx.memo[qid] = { false, nil, 0, m, info }
		return false, nil, 0, m, info
	end
	if prof >= MAX_PROFUNDO then return true, { qid }, M.num(f.min, 0) end
	ctx.visitando[qid] = true
	local out, en, deps = {}, {}, {}
	local nivel = M.num(f.min, 0)
	local function falla(m2, i2)
		ctx.visitando[qid] = nil
		ctx.memo[qid] = { false, nil, 0, m2, i2 }
		return false, nil, 0, m2, i2
	end
	for _, p in ipairs(f.preAll) do
		local ok, sub, nv, m2, i2 = visitar(p, ctx, prof + 1)
		if not ok then return falla(m2, i2) end
		sumar(out, sub, en)
		nivel = max(nivel, nv)
		if not (ctx.usadas[p] or hecha(p)) then deps[#deps + 1] = p end
	end
	if #f.preAny > 0 then
		local lista0 = false
		for _, p in ipairs(f.preAny) do
			if ctx.usadas[p] or hecha(p) or en[p] then lista0 = true break end
		end
		if not lista0 then
			local mejor, primera
			for _, p in ipairs(f.preAny) do
				local ok, sub, nv, m2, i2 = visitar(p, ctx, prof + 1)
				if ok then
					local costo = #sub + (nv > ctx.p.level and 1000 or 0) - (enRegistro(p) and 500 or 0)
					if not mejor or costo < mejor.costo then mejor = { p = p, sub = sub, nv = nv, costo = costo } end
				elseif not primera then
					primera = { m = m2, i = i2 }
				end
			end
			if not mejor then return falla(primera and primera.m or "previas", primera and primera.i or {}) end
			sumar(out, mejor.sub, en)
			nivel = max(nivel, mejor.nv)
			deps[#deps + 1] = mejor.p
		end
	end
	ctx.visitando[qid] = nil
	sumar(out, { qid }, en)
	ctx.dep[qid] = deps
	ctx.memo[qid] = { true, out, nivel }
	return true, out, nivel
end

function D.Resolver(qid, opts)
	qid = tonumber(qid)
	opts = opts or {}
	local res = { ok = false, cadena = {}, dep = {} }
	if not qid then res.motivo, res.info = "desconocida", {} return res end
	local p = jugador()
	if opts.nivel then p.level = floor(M.num(opts.nivel, p.level)) end
	local usadas = opts.usadas or {}
	if enRegistro(qid) then
		res.ok, res.cadena[1] = true, qid
		return res
	end
	if hecha(qid) or usadas[qid] then res.motivo, res.info = "hecha", {} return res end
	local ctx = { usadas = usadas, visitando = {}, memo = {}, dep = res.dep, p = p }
	local ok, lista0, nivel, motivo, info = visitar(qid, ctx, 0)
	if not ok then
		res.motivo, res.info = motivo, info or {}
		res.bloquea = res.info.bloquea
		res.info.objetivo = qid
		return res
	end
	res.ok, res.cadena = true, lista0
	if (nivel or 0) > p.level then res.nivel = nivel end
	return res
end

-- "«A», «B», nivel 20": lo que la ruta agrega antes de la misión (la última
-- de la cadena), o nil si no agrega nada.
function D.TextoAntes(cadena, nivel)
	local antes = {}
	for i = 1, #(cadena or {}) - 1 do antes[#antes + 1] = cadena[i] end
	local t = citarVarias(antes, 3)
	if nivel then t[#t + 1] = format(L["nivel %d"], nivel) end
	if #t == 0 then return nil end
	return concat(t, ", ")
end

-- Lo que hay que hacer para tomarla, en orden (la misión al final), y el
-- nivel que pide la cadena si es más que el tuyo; motivo cuando no se puede
-- (otra facción, otra clase, cerrada por otra, una de la cadena así).
function D.Desbloquear(qid)
	qid = tonumber(qid)
	local out = { cadena = {}, nivel = nil, linea = nil }
	if not qid then out.motivo = "desconocida" return out end
	local r = D.Resolver(qid)
	if not r.ok then
		out.motivo, out.info, out.bloquea = r.motivo or "desconocida", r.info, r.bloquea
		return out
	end
	out.cadena, out.nivel, out.dep = r.cadena, r.nivel, r.dep
	out.antes = D.TextoAntes(r.cadena, r.nivel)
	return out
end

---------------------------------------------------------------------------
-- Para el motor y para Mis planes (con memoria hasta que algo cambie)
---------------------------------------------------------------------------

local memoBloqueo, memoResumen = {}, {}

function D.Limpiar()
	memoBloqueo, memoResumen = {}, {}
end

-- Lo que la cierra sin remedio para el motor: texto | nil. Ni carga datos
-- ni cierra lo que está en el registro o ya hecho (eso lo ve el motor).
function D.Bloqueo(qid)
	qid = tonumber(qid)
	if not qid then return nil end
	local v = memoBloqueo[qid]
	if v == nil then
		v = false
		if not (enRegistro(qid) or hecha(qid)) then
			local f = ficha(qid)
			if f then
				local m, info = cerrada(f, jugador(), nil)
				if m then v = D.Texto(m, info) end
			elseif not (cargada() or codexListo()) then
				return nil -- sin datos todavía: se vuelve a preguntar
			end
		end
		memoBloqueo[qid] = v
	end
	return v or nil
end

-- Para una meta de misión de Mis planes: lo que se agregará antes y por qué
-- no se puede. -> antes | nil, noDisponible | nil
function D.Resumen(qid)
	qid = tonumber(qid)
	if not qid then return nil end
	local v = memoResumen[qid]
	if v == nil then
		v = false
		if not (enRegistro(qid) or hecha(qid)) and (cargada() or codexListo()) then
			local r = D.Resolver(qid)
			if not r.ok then
				v = { no = D.Texto(r.motivo, r.info) }
			else
				local t = D.TextoAntes(r.cadena, r.nivel)
				if t then v = { antes = t } end
			end
		end
		memoResumen[qid] = v
	end
	if not v then return nil end
	return v.antes, v.no
end

-- Los pasos de una misión de la cadena (los de Indice.PasosMision: el que la
-- da, sus objetivos, el que la recibe). Una de mazmorra o de grupo no entra
-- en una guía de otro: nil.
local function pasoDe(qid, desde)
	local C, I = CX(), M.Indice
	local q = codexListo() and C.Quest(qid)
	if not (q and I and I.PasosMision) then return nil end
	if I.Mazmorra and I.Mazmorra(qid) then return nil end
	local pm = I.PasosMision(q, desde)
	if not pm or pm.grupo or pm.mazmorra then return nil end
	-- Un objetivo sin lugar conocido va sin flecha (dice qué hacer); uno
	-- dentro de una instancia no.
	for _, o in ipairs(q.objectives or {}) do
		local npc = (o.type == "kill" or o.type == "talk") and o.id and C.Npc(o.id)
		if npc and npc.instance then return nil end
	end
	local goals = {}
	if not enRegistro(qid) then
		if not pm.aceptar then return nil end
		goals[1] = M.Copia(pm.aceptar)
	end
	for _, g in ipairs(pm.objetivos) do goals[#goals + 1] = M.Copia(g) end
	goals[#goals + 1] = M.Copia(pm.entregar)
	return { title = q.title, goals = goals }, q.title, pm.fin
end

-- La cadena que trae qid, paso por paso, para una guía del motor que no la
-- da. Toda debe poderse tomar ya (sin nivel de más): si no, nil y el motor la
-- deja fuera como antes.
function D.Cadena(qid)
	qid = tonumber(qid)
	if not (qid and codexListo()) then return nil end
	local r = D.Resolver(qid)
	if not r.ok or r.nivel then return nil end
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	local out = {}
	for _, q in ipairs(r.cadena) do
		local paso, titulo, fin = pasoDe(q, desde)
		if not paso then return nil end
		out[#out + 1] = { quest = q, title = titulo, step = paso, preAll = (r.dep[q] and #r.dep[q] > 0) and r.dep[q] or nil }
		desde = fin or desde
	end
	return #out > 0 and out or nil
end

-- Lo que cambia la respuesta: una misión tomada, entregada o quitada, el
-- nivel, las profesiones, las reputaciones y los datos al cargar.
for _, ev in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "UPDATE_FACTION" }) do
	if A.RegisterEvent then A.RegisterEvent(ev, D.Limpiar) end
end
if A.On then
	A.On("CODEX_LOADED", function() fichas = {} D.Limpiar() end)
	A.On("QUESTDB_LOADED", function() fichas = {} D.Limpiar() end)
end

-- El motor pregunta por aquí (tools/parches.py, REQUISITOS).
do
	local R = A.Requisitos
	if type(R) == "table" then
		R.Bloqueo = D.Bloqueo
		R.Cadena = D.Cadena
	end
end
