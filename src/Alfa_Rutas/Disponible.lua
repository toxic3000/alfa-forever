-- Alfa - Rutas: si una misión se puede tomar ya y, si no, qué falta para
-- tomarla. toxic3000 / La Jauría. GPL-3.0.
--
-- Regla de la ruta: nunca proponer una misión que aún no se puede tomar.
-- Antes de ponerla en un plan se mira el nivel, las misiones previas, las
-- excluyentes, la facción, la raza, la clase y la profesión, con la base de
-- misiones del motor (A.QuestDB, la más completa: previas "todas" y "una de",
-- excluyentes y profesión) y, si no está cargada, con el Codex (A.Codex y
-- Lookup.QuestBlock). Lo que falta se arma después: las previas en orden
-- (Lookup.QuestChain) y el nivel que pide (misiones de XP antes, Plan.lua).
--
--   Disp.Cargar() -> bool                      carga la base de misiones (nunca en combate)
--   Disp.Estado(qid, opts) -> ok, motivo, info opts = { usadas = { [qid] = true }, nivel = n }
--       motivo: "registro" (ya la tienes; ok) | "hecha" | "nivel" | "previas" | "excluida"
--               | "profesion" | "faccion" | "raza" | "clase" | "fiesta" | "gris" | "desconocida"
--       info:   { nivel = mínimo, faltan = { qid, ... }, linea = profesión }
--   Disp.Texto(motivo, info) -> "Disponible a nivel 20", "Antes: ...", ...
--   Disp.Imposible(motivo) -> bool             no se arregla haciendo algo (facción, clase...)
--   Disp.Desbloquear(qid) -> { cadena = { qid, ... }, nivel, linea, motivo? }
--       lo que hay que hacer, en orden, para poder tomarla (la misión al final);
--       motivo cuando no se puede (otra facción, otra clase, cerrada por otra)

local ADDON, M = ...
local A, L = M.A, M.L
local D = {}
M.Disp = D

local type, ipairs, pairs, tonumber, tostring = type, ipairs, pairs, tonumber, tostring
local floor, max, format, concat = math.floor, math.max, string.format, table.concat

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

local function rango(linea)
	local C = CP()
	local r = C and C.GetSkillRank and C.GetSkillRank(linea)
	return type(r) == "number" and r or 0
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

-- Las previas que faltan de una misión (todas las de `preAll` y una de `pre`
-- en la base; todas las de `pre` y una de `preAny` en el Codex).
local function faltanQDB(r, F, hechaFn)
	local out = {}
	local all = r[F.PRE_ALL]
	if type(all) == "table" then
		for _, p in ipairs(all) do if p and not hechaFn(p) then out[#out + 1] = p end end
	end
	local any = r[F.PRE]
	if type(any) == "table" and #any > 0 then
		local una = false
		for _, p in ipairs(any) do if p and hechaFn(p) then una = true break end end
		if not una and any[1] then out[#out + 1] = any[1] end
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

-- La clase, la raza o la facción que la cierran: para decirlo claro.
local function porQuien(qid)
	local C, Lk = CX(), LK()
	local q = C and C.IsLoaded and C.IsLoaded() and C.Quest(qid)
	if not (q and Lk and Lk.QuestBlock) then return "faccion" end
	local why = Lk.QuestBlock(q, jugador())
	if why == "race" then return "raza" end
	if why == "class" then return "clase" end
	return "faccion"
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
	if cargada() then
		local Q = QD()
		local ctx = Q.PlayerContext and Q.PlayerContext(nil, {}) or {}
		ctx.level = nivel
		local ok, why = Q.CheckAvailable(qid, ctx, hechaFn, function(q) return enRegistro(q) or (usadas[q] and true or false) end,
			{ lowLevel = true, skillRank = rango })
		if ok then return true, nil, {} end
		local r = Q.QuestRecord(qid)
		local F = Q.F
		if why ~= "unknown" and r and F then
			local m = DE_QDB[why] or "desconocida"
			local info = { nivel = r[F.MIN], linea = r[F.SKILL] }
			if m == "faccion" then
				if r[F.HOLIDAY] then m = "fiesta" else m = porQuien(qid) end
			elseif m == "previas" then
				info.faltan = faltanQDB(r, F, hechaFn)
			end
			return false, m, info
		end
	end
	-- Sin la base de misiones: el Codex.
	local C, Lk = CX(), LK()
	local q = C and C.IsLoaded and C.IsLoaded() and C.Quest(qid)
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
		if why == "level" then return false, "nivel", { nivel = q.minLevel } end
	end
	local faltan = faltanCodex(q, hechaFn)
	if #faltan > 0 then return false, "previas", { faltan = faltan, nivel = q.minLevel } end
	return true, nil, {}
end

-- Lo que se arregla haciendo algo (subir de nivel, hacer las previas,
-- aprender la profesión) frente a lo que no.
local IMPOSIBLE = { faccion = true, raza = true, clase = true, hecha = true, excluida = true, fiesta = true, desconocida = true }
function D.Imposible(motivo) return IMPOSIBLE[motivo] or false end

local function nombreProfesion(linea)
	local Lk = LK()
	local en = linea and Lk and Lk.ProfessionName and Lk.ProfessionName(linea)
	if not en then return L["su profesión"] end
	local EL = A.L
	return (type(EL) == "table" and EL[en]) or en
end
D.NombreProfesion = nombreProfesion

function D.Texto(motivo, info)
	info = info or {}
	if motivo == "nivel" then return format(L["Disponible a nivel %d"], M.num(info.nivel, 1)) end
	if motivo == "previas" then
		local t = {}
		for i, q in ipairs(info.faltan or {}) do
			if i > 2 then t[#t + 1] = L["y más"] break end
			t[#t + 1] = M.Citar(M.TituloMision(q))
		end
		if #t == 0 then return L["Antes hay que hacer otra misión"] end
		return format(L["Antes: %s"], concat(t, ", "))
	end
	if motivo == "profesion" then return format(L["Necesitas %s"], nombreProfesion(info.linea)) end
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

-- Lo que hay que hacer para tomarla. Las previas salen de Lookup.QuestChain
-- (todas las que faltan, en el orden en que se hacen). Cada una se revisa:
-- una de otra facción o clase hace imposible la cadena.
function D.Desbloquear(qid)
	qid = tonumber(qid)
	local out = { cadena = {}, nivel = nil, linea = nil }
	if not qid then out.motivo = "desconocida" return out end
	local ok, motivo, info = D.Estado(qid)
	if ok then
		out.cadena[1] = qid
		return out
	end
	if D.Imposible(motivo) then
		out.motivo = motivo
		return out
	end
	local Lk = LK()
	local lista = Lk and Lk.QuestChain and Lk.QuestChain(qid, jugador()) or {}
	if #lista == 0 then lista = { { id = qid } } end
	local usadas = {}
	local nivel = 1
	for _, q in ipairs(lista) do
		local id = q.id
		if id and not hecha(id) then
			local bien, m, inf = D.Estado(id, { usadas = usadas, nivel = 999 })
			if not bien and m ~= "previas" and m ~= "registro" then
				if D.Imposible(m) then
					out.motivo = m
					out.bloquea = id
					return out
				elseif m == "profesion" then
					out.linea = out.linea or inf.linea
				end
			end
			local _, _, li = D.Estado(id, { usadas = usadas, nivel = 0 })
			nivel = max(nivel, M.num(li and li.nivel, 1), M.num(q.minLevel, 1))
			out.cadena[#out.cadena + 1] = id
			usadas[id] = true
		end
	end
	-- La misión misma, al final (por si la cadena no la trae).
	if out.cadena[#out.cadena] ~= qid then out.cadena[#out.cadena + 1] = qid end
	nivel = max(nivel, M.num(info and info.nivel, 1))
	if nivel > jugador().level then out.nivel = nivel end
	return out
end
