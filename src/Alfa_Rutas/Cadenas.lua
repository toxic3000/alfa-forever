-- Alfa - Rutas: las cadenas de misiones (toxic3000 / La Jauría). GPL-3.0.
-- 1.2.7
--
--   Cadenas.Siguientes(qid) -> { qid, ... }   las misiones que abre hacerla
--       (las que la piden antes), para tu personaje y que aún no haces
--   Cadenas.Siguiente(qid) -> qid, título | nil
--   M.GrisValiosa(qid) -> motivo | nil   una misión gris que vale la pena:
--       da un objeto raro o mejor, o abre una misión de la cadena que aún no
--       es gris («Vale la pena: …»). El rastreador lo dice bajo su meta.
--
-- Y avisa al abandonar una misión que abre otras: al elegirla para abandonar
-- (C_QuestLog.SetAbandonQuest, la ventana de confirmar del juego), «Si la
-- abandonas, pierdes la cadena…». Solo cuando de verdad hay una que sigue.
-- Lo que abandona Alfa misma (Plan.Abandonar, ya confirmado) no avisa.
--
-- Los datos: la base de misiones del motor (A.QuestDB.FollowUps, su índice) o,
-- sin ella, el Codex (A.Codex.FollowUps). Nunca se cargan aquí, y en combate
-- no se busca nada (el índice se arma la primera vez que se pide).

local ADDON, M = ...
local A, L = M.A, M.L
local Ch = {}
M.Cadenas = Ch

A.RegisterDefaults(M.ID, { avisoCadena = true }) -- 1.4.0 (27)

local type, ipairs, tonumber, pairs = type, ipairs, tonumber, pairs
local format = string.format

local function QD() return M.Motor("QuestDB") end
local function CX() return M.Motor("Codex") end
local function CP() return M.Motor("Compat") end
local function LK() return M.Motor("Lookup") end

local function enCombate() return InCombatLockdown and InCombatLockdown() or false end
local function secreto(v) return issecretvalue and issecretvalue(v) or false end

local function hecha(q)
	local C = CP()
	return C and C.IsQuestCompleted and C.IsQuestCompleted(q) or false
end

local function codexListo()
	local C = CX()
	return C and C.IsLoaded and C.IsLoaded() and true or false
end

local function qdbLista()
	local Q = QD()
	return Q and Q.IsLoaded and Q.IsLoaded() and Q.FollowUps and Q.QuestRecord and true or false
end

---------------------------------------------------------------------------
-- Lo que sigue en la cadena
---------------------------------------------------------------------------

local function paraMi(Q, r, ctx)
	if not (Q.IsEligible and ctx) then return true end
	local ok, si = pcall(Q.IsEligible, r, ctx)
	return not ok or si and true or false
end

function Ch.Siguientes(qid)
	qid = tonumber(qid)
	local out = {}
	if not qid or enCombate() then return out end
	if qdbLista() then
		local Q = QD()
		local ctx = Q.PlayerContext and select(2, pcall(Q.PlayerContext, nil, {})) or nil
		if type(ctx) ~= "table" then ctx = nil end
		local ok, lista = pcall(Q.FollowUps, qid)
		for _, f in ipairs(ok and type(lista) == "table" and lista or {}) do
			local r = Q.QuestRecord(f)
			if r and f ~= qid and paraMi(Q, r, ctx) and not hecha(f) then out[#out + 1] = f end
		end
		return out
	end
	local C = CX()
	if codexListo() and C.FollowUps then
		local Lk = LK()
		local p
		if Lk and Lk.PlayerInfo and Lk.QuestBlock then
			p = {}
			for k, v in pairs(Lk.PlayerInfo() or {}) do p[k] = v end
			p.level = 999 -- el nivel no cierra una cadena: se llega
		end
		local ok, lista = pcall(C.FollowUps, qid)
		for _, q in ipairs(ok and type(lista) == "table" and lista or {}) do
			local f = tonumber(q.id)
			local cierra = p and Lk.QuestBlock(q, p)
			if f and f ~= qid and not cierra and not hecha(f) then out[#out + 1] = f end
		end
	end
	return out
end

function Ch.Siguiente(qid)
	local f = Ch.Siguientes(qid)[1]
	if not f then return nil end
	return f, M.TituloMision(f)
end

---------------------------------------------------------------------------
-- Misiones grises que valen la pena
---------------------------------------------------------------------------

local CALIDAD_RARA = 3

-- El nivel de una misión: el del registro, el del Codex o el de la base.
local function nivelDe(qid)
	local Cp = CP()
	local n = Cp and Cp.GetQuestLevel and Cp.GetQuestLevel(qid)
	if type(n) == "number" and n > 0 then return n end
	local C = CX()
	local q = codexListo() and C.Quest(qid)
	if q and type(q.level) == "number" and q.level > 0 then return q.level end
	if qdbLista() then
		local Q = QD()
		local r = Q.QuestRecord(qid)
		local v = r and Q.F and r[Q.F.LEVEL]
		if type(v) == "number" and v > 0 then return v end
	end
	return nil
end

local function gris(nivelMision, nivel)
	local Cp = CP()
	if not (nivelMision and Cp and Cp.IsQuestTrivial) then return false end
	return Cp.IsQuestTrivial(nivelMision, nivel) and true or false
end

local function jugadorNivel()
	local I = M.Indice
	local p = I and I.Jugador and I.Jugador()
	return p and M.num(p.level, 1) or 1
end

-- El mejor objeto raro (o mejor) que da: itemID | nil.
local function premio(qid)
	local C = CX()
	if not (codexListo() and C.Item) then return nil end
	local q = C.Quest(qid)
	if not q then return nil end
	local mejor, calidad
	for _, lista in ipairs({ q.rewards or {}, q.choices or {} }) do
		for _, id in ipairs(lista) do
			local it = C.Item(id)
			local cal = it and tonumber(it.quality)
			if cal and cal >= CALIDAD_RARA and (not calidad or cal > calidad) then mejor, calidad = id, cal end
		end
	end
	return mejor
end

-- 1.3.0: ¿es gris para ti? (Grises.lua) y su nivel.
function Ch.EsGris(qid)
	qid = tonumber(qid)
	if not qid then return false end
	local n = nivelDe(qid)
	return gris(n, jugadorNivel()), n
end
Ch.Nivel = nivelDe

local cacheGris = {} -- qid -> { nivel, motivo | false }

local function calcularGris(qid, nivel)
	if not gris(nivelDe(qid), nivel) then return nil end
	local item = premio(qid)
	if item then return format(L["Vale la pena: da %s"], M.NombreObjeto(item)) end
	for _, f in ipairs(Ch.Siguientes(qid)) do
		local nf = nivelDe(f)
		if nf and not gris(nf, nivel) then
			return format(L["Vale la pena: abre “%s”"], M.TituloMision(f))
		end
	end
	return nil
end

function M.GrisValiosa(qid)
	qid = tonumber(qid)
	if not qid or secreto(qid) then return nil end
	local nivel = jugadorNivel()
	local c = cacheGris[qid]
	if c and c.nivel == nivel then return c.motivo or nil end
	-- En combate no se busca (lo de antes sí se dice).
	if enCombate() then return nil end
	-- Sin datos todavía: no se guarda, se vuelve a preguntar.
	if not (codexListo() or qdbLista()) then return nil end
	local ok, motivo = pcall(calcularGris, qid, nivel)
	motivo = ok and motivo or nil
	cacheGris[qid] = { nivel = nivel, motivo = motivo or false }
	return motivo
end

-- Lo que llega de otra base (más datos cargados) se vuelve a mirar.
A.On("CODEX_LOADED", function() cacheGris = {} end)

---------------------------------------------------------------------------
-- Al abandonar una misión
---------------------------------------------------------------------------

local dicho = { qid = nil, t = 0 }

local function alAbandonar()
	if M.abandonando then return end -- Plan.Abandonar: ya lo confirmaste
	local QL = C_QuestLog
	if not (QL and QL.GetAbandonQuest) then return end
	local ok, qid = pcall(QL.GetAbandonQuest)
	if not ok or secreto(qid) then return end
	qid = tonumber(qid)
	if not qid or qid <= 0 then return end
	local ahora = GetTime()
	if dicho.qid == qid and ahora - dicho.t < 5 then return end -- (el juego puede llamarla dos veces)
	if A.Get(M.ID .. ".avisoCadena") == false then return end
	local f, titulo = Ch.Siguiente(qid)
	if not f then return end
	dicho.qid, dicho.t = qid, ahora
	-- 1.4.0 (27): cuánto vale lo que pierdes (Ch.Valor): cuántas siguen, la
	-- experiencia y el premio del final, con «Ver la cadena».
	local val = Ch.Valor(qid)
	local texto = format(L["Si la abandonas, pierdes la cadena: después sigue “%s”."], titulo or "")
	local valiosa = val and val.valiosa
	if val and val.texto then texto = texto .. " " .. val.texto end
	local Ca = M.Cadena
	M.Aviso(valiosa and L["Antes de abandonarla: abre una cadena valiosa"] or L["Antes de abandonarla"], texto,
		{ icono = "ic-aviso", tono = "aviso", duracion = valiosa and 14 or nil, importante = valiosa and "siempre" or nil,
			accion = Ca and Ca.Abrir and A.Get(M.ID .. ".cadenaCompleta") ~= false
				and { texto = L["Ver la cadena"], alClic = function() Ca.Abrir(qid) end } or nil })
end
Ch.AlAbandonar = alAbandonar

-- 1.4.0 (27): lo que vale la cadena que abre una misión. -> { siguen, xp,
-- premio = itemID | nil, valiosa = bool, texto } | nil (sin datos o sin cadena)
-- Valiosa: 2 o más misiones después, o un premio raro (o mejor) al final.
function Ch.Valor(qid)
	qid = tonumber(qid)
	local Ca = M.Cadena
	if not qid or enCombate() or not (Ca and Ca.De) then return nil end
	local ok, d = pcall(Ca.De, qid)
	if not ok or type(d) ~= "table" then return nil end
	local siguen, xp, vistaEsta = 0, 0, false
	local C = CX()
	for _, x in ipairs(d.lista or {}) do
		if x.estado == "esta" then
			vistaEsta = true
		elseif vistaEsta and x.estado ~= "hecha" then
			siguen = siguen + 1
			local r = C and C.Quest and C.Quest(x.qid)
			xp = xp + (r and tonumber(r.xp) or 0)
		end
	end
	if siguen == 0 then return nil end
	local mejor, calidad
	for _, it in ipairs(d.premio or {}) do
		local i = C and C.Item and C.Item(it)
		local cal = i and tonumber(i.quality)
		if cal and cal >= CALIDAD_RARA and (not calidad or cal > calidad) then mejor, calidad = it, cal end
	end
	local partes = { M.Plural(siguen, L["Abre %d misión más"], L["Abre %d misiones más"]) }
	if xp > 0 then partes[#partes + 1] = format(L["+%s XP"], M.Miles(xp)) end
	if mejor then partes[#partes + 1] = format(L["al final da %s"], M.NombreObjeto(mejor)) end
	return { siguen = siguen, xp = xp, premio = mejor, valiosa = siguen >= 2 or mejor ~= nil,
		texto = table.concat(partes, "  \194\183  ") .. "." }
end

A.OnLogin(function()
	local QL = C_QuestLog
	local deQL = QL and type(QL.SetAbandonQuest) == "function" and QL.SetAbandonQuest or nil
	if deQL then hooksecurefunc(QL, "SetAbandonQuest", alAbandonar) end
	local global = rawget(_G, "SetAbandonQuest")
	if type(global) == "function" and global ~= deQL then hooksecurefunc("SetAbandonQuest", alAbandonar) end
end)
