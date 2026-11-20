-- Alfa - Rutas: misiones de élite y compartir con tu grupo (toxic3000 / La Jauría). GPL-3.0.
-- 1.2.9
--
-- De élite: si tu paso de ahora o el que sigue trae una meta de élite o que
-- pide grupo (la `party` de la vista del motor: "elite" o "group"; las
-- mazmorras tienen su propio camino), el rastreador lo dice antes de llegar,
-- con «Llamar a la manada» (La Jauría: AlfaManada.Llamar si existe, si no su
-- comando «/alfa manada llamar»). Ya en grupo no hace falta: no se dice. Una
-- vez por misión en la sesión («Entendido» la guarda). Ajuste rutas.avisoElite.
--
-- Compartir: en grupo, si alguien no tiene una misión de tu registro que se
-- puede compartir (C_QuestLog.IsPushableQuest) y le alcanza el nivel, el
-- rastreador lo dice con «Compartir» (tu clic: QuestLogPushQuest; nunca solo).
-- Quién la tiene se sabe por la lista que manda su Alfa (La Jauría,
-- AlfaManada.MisionesDe(nombre) si existe) o por el juego
-- (C_QuestLog.IsUnitOnQuest). Lo que no se sabe no se dice. Una vez por
-- misión en la sesión. Ajuste rutas.compartirMisiones.
--
--   Grupo.Elite(v, live) -> { quest, titulo, tipo, paso } | nil
--   Grupo.Llamar() -> ok          pide ayuda a la manada
--   Grupo.Compartibles() -> { { qid, titulo, quienes = { nombre, ... } }, ... }
--   Grupo.Compartir(qid) -> ok    comparte la misión (con el clic del jugador)
--   Grupo.Aviso(v, live) -> el aviso del rastreador | nil

local ADDON, M = ...
local A, L = M.A, M.L
local Gr = {}
M.Grupo = Gr

A.RegisterDefaults(M.ID, { avisoElite = true, compartirMisiones = true })

local type, ipairs, pairs, tonumber, tostring, pcall = type, ipairs, pairs, tonumber, tostring, pcall
local format, concat = string.format, table.concat

local VIGENCIA = 5 -- segundos que vale lo que se sabe del grupo

local function CX() return M.Motor("Codex") end
local function CP() return M.Motor("Compat") end
local function E() return A.Engine end
local function secreto(v) return issecretvalue and issecretvalue(v) or false end
local function leer(v) if secreto(v) then return nil end return v end
local function on(clave) return A.Get(M.ID .. "." .. clave) ~= false end

local function engine(fn, ...)
	local e = E()
	local f = e and e[fn]
	if type(f) ~= "function" then return nil end
	local ok, a, b = pcall(f, ...)
	if ok then return a, b end
	return nil
end

local function enGrupo()
	if IsInGroup then
		local ok, si = pcall(IsInGroup)
		if ok and leer(si) then return true end
	end
	if GetNumGroupMembers then
		local ok, n = pcall(GetNumGroupMembers)
		return ok and (tonumber(leer(n)) or 0) > 1
	end
	return false
end

local function manada()
	local Ma = rawget(_G, "AlfaManada")
	return type(Ma) == "table" and Ma or nil
end

---------------------------------------------------------------------------
-- De élite
---------------------------------------------------------------------------

local TIPOS = { elite = true, group = true }
local vistas = {} -- quest (o "paso:n") -> true: ya dicho y entendido

local function eliteEn(v)
	for _, gv in ipairs(type(v) == "table" and v.goals or {}) do
		local p = type(gv) == "table" and gv.party
		if type(p) == "table" and TIPOS[p.kind] and (gv.status == "active" or gv.status == "pending") then return gv, p end
	end
	return nil
end

function Gr.Elite(v, live)
	if not (v and live and v.index == live) then return nil end
	for paso = live, live + 1 do
		local vv = paso == live and v or engine("GetStepView", paso)
		local gv, p = eliteEn(vv)
		if gv then
			local clave = gv.quest or ("paso:" .. paso)
			if not vistas[clave] then
				local titulo = gv.quest and M.TituloMision(gv.quest) or gv.subject or gv.text
				if secreto(titulo) then titulo = nil end
				return { quest = gv.quest, clave = clave, titulo = titulo, tipo = p.kind, rango = p.rank, tam = p.size, paso = paso, ahora = paso == live }
			end
		end
	end
	return nil
end

function Gr.PuedeLlamar()
	local Ma = manada()
	if not Ma then return false end
	if type(Ma.Llamar) == "function" then return true end
	return type(A.RunCommand) == "function" and type(Ma.Abrir) == "function"
end

function Gr.Llamar()
	local Ma = manada()
	if not Ma then return false end
	if type(Ma.Llamar) == "function" then
		local ok, r = pcall(Ma.Llamar)
		return ok and r ~= false
	end
	if type(A.RunCommand) == "function" then
		return (pcall(A.RunCommand, "manada llamar"))
	end
	return false
end

local function avisoElite(v, live)
	if not on("avisoElite") or enGrupo() then return nil end
	local el = Gr.Elite(v, live)
	if not el then return nil end
	local nombre = el.titulo and M.Citar(el.titulo) or L["Lo que sigue"]
	local titulo
	if el.tipo == "group" then
		titulo = el.tam and format(L["%s pide un grupo de %d"], nombre, el.tam) or format(L["%s pide grupo"], nombre)
	else
		titulo = format(L["Ojo: %s es de élite"], nombre)
	end
	local puede = Gr.PuedeLlamar()
	local d = { tono = "mazmorra", icono = "ic-manada", titulo = titulo,
		texto = puede and L["Mejor con la manada: llámala y cacen juntos."] or L["Mejor no ir sin compañía: puede salir caro."] }
	local function entendido() vistas[el.clave] = true if M.Rastreador then M.Rastreador.Luego() end end
	if puede then
		d.uno = { L["Llamar a la manada"], function() Gr.Llamar() entendido() end }
		d.dos = { L["Entendido"], entendido }
	else
		d.uno = { L["Entendido"], entendido }
	end
	return d
end

---------------------------------------------------------------------------
-- Compartir con tu grupo
---------------------------------------------------------------------------

-- -> nombre para mostrar, nombre completo. 1.3.1: el completo es el de
-- Compat.UnitFullName («Ana Smith» en Forever, «Ana-Reino» fuera), el que
-- La Jauría reconoce; sin él, nombre y reino de UnitName.
local function nombreDe(unit)
	local Cp = CP()
	if Cp and type(Cp.UnitFullName) == "function" then
		local ok, completo, corto = pcall(Cp.UnitFullName, unit)
		if ok and completo == false then return nil end -- secreto
		if ok and type(completo) == "string" and completo ~= "" then
			return (type(corto) == "string" and corto ~= "") and corto or completo, completo
		end
	end
	if not UnitName then return nil end
	local ok, n, reino = pcall(UnitName, unit)
	n, reino = ok and leer(n), ok and leer(reino)
	if type(n) ~= "string" or n == "" then return nil end
	return n, (type(reino) == "string" and reino ~= "") and (n .. "-" .. reino) or n
end

-- Lo que la manada sabe que lleva: { [qid] = true } | nil (no se sabe).
-- 1.3.1: se pide una vez por lobo (Gr.Compartibles), no una vez por misión.
local function deLaManada(completo)
	local Ma = manada()
	if not (completo and Ma and type(Ma.MisionesDe) == "function") then return nil end
	local ok, lista = pcall(Ma.MisionesDe, completo)
	return ok and type(lista) == "table" and lista or nil
end

-- ¿Tiene esa misión? true | false | nil (no se sabe). misiones: su lista de La Jauría.
local function tiene(unit, misiones, qid)
	if misiones then return misiones[qid] and true or false end
	local QL = C_QuestLog
	if QL and type(QL.IsUnitOnQuest) == "function" then
		local ok, si = pcall(QL.IsUnitOnQuest, unit, qid)
		if ok and not secreto(si) and type(si) == "boolean" then return si end
	end
	return nil
end

local function compartible(qid)
	local QL = C_QuestLog
	if QL and type(QL.IsPushableQuest) == "function" then
		local ok, si = pcall(QL.IsPushableQuest, qid)
		return ok and leer(si) == true
	end
	return false
end

-- ¿Le alcanza el nivel? (sin saberlo, sí)
local function leAlcanza(unit, qid)
	local C = CX()
	local q = C and C.IsLoaded and C.IsLoaded() and C.Quest and C.Quest(qid)
	local minimo = type(q) == "table" and tonumber(q.minLevel)
	if not minimo or not UnitLevel then return true end
	local ok, n = pcall(UnitLevel, unit)
	n = ok and tonumber(leer(n))
	return not n or n <= 0 or n >= minimo
end

local cacheL, cacheEn = nil, -1e9
local compartidas = {} -- qid -> true: ya compartida o «Ahora no» (esta sesión)

function Gr.Olvidar() cacheL, cacheEn = nil, -1e9 end

function Gr.Compartibles(forzar)
	local ahora = GetTime and GetTime() or 0
	if not forzar and cacheL and ahora - cacheEn < VIGENCIA then return cacheL end
	local out = {}
	cacheL, cacheEn = out, ahora
	if not enGrupo() or (IsInRaid and IsInRaid()) then return out end
	local Cp = CP()
	local unidades = {}
	for i = 1, 4 do
		local u = "party" .. i
		if UnitExists and UnitExists(u) then
			local n, completo = nombreDe(u)
			if n then unidades[#unidades + 1] = { u = u, n = n, completo = completo, misiones = deLaManada(completo) } end
		end
	end
	if #unidades == 0 then return out end
	for _, qid in ipairs(Cp and Cp.GetLogQuests and Cp.GetLogQuests() or {}) do
		if compartible(qid) then
			local quienes = {}
			for _, x in ipairs(unidades) do
				if tiene(x.u, x.misiones, qid) == false and leAlcanza(x.u, qid) then quienes[#quienes + 1] = x.n end
			end
			if #quienes > 0 then out[#out + 1] = { qid = qid, titulo = M.TituloMision(qid), quienes = quienes } end
		end
	end
	return out
end

local function indiceDe(qid)
	local QL = C_QuestLog
	if QL and type(QL.GetLogIndexForQuestID) == "function" then
		local ok, i = pcall(QL.GetLogIndexForQuestID, qid)
		if ok and tonumber(i) then return tonumber(i) end
	end
	if QL and QL.GetNumQuestLogEntries and QL.GetInfo then
		for i = 1, QL.GetNumQuestLogEntries() or 0 do
			local info = QL.GetInfo(i)
			if type(info) == "table" and info.questID == qid then return i end
		end
	end
	return nil
end

-- Solo con el clic del jugador (el botón «Compartir»).
function Gr.Compartir(qid)
	compartidas[qid] = true
	local i = indiceDe(qid)
	if not (i and type(QuestLogPushQuest) == "function") then return false end
	if type(SelectQuestLogEntry) == "function" then pcall(SelectQuestLogEntry, i) end
	local ok = pcall(QuestLogPushQuest, i)
	Gr.Olvidar()
	return ok
end

local function avisoCompartir()
	if not on("compartirMisiones") then return nil end
	for _, c in ipairs(Gr.Compartibles()) do
		if not compartidas[c.qid] then
			local quien = #c.quienes == 1 and c.quienes[1] or concat(c.quienes, ", ")
			return { tono = "acento", icono = "ic-manada",
				titulo = format(L["%s no tiene %s"], quien, M.Citar(c.titulo or "")),
				texto = L["Compártela y la hacen juntos."],
				uno = { L["Compartir"], function() Gr.Compartir(c.qid) if M.Rastreador then M.Rastreador.Luego() end end },
				dos = { L["Ahora no"], function() compartidas[c.qid] = true if M.Rastreador then M.Rastreador.Luego() end end } }
		end
	end
	return nil
end

function Gr.Aviso(v, live)
	return avisoElite(v, live) or avisoCompartir()
end

-- Para el banco.
function Gr.Reiniciar() vistas, compartidas = {}, {} Gr.Olvidar() end

local function cambio()
	Gr.Olvidar()
	if M.Rastreador and M.Rastreador.Luego then M.Rastreador.Luego() end
end
A.RegisterEvent("GROUP_ROSTER_UPDATE", cambio)
A.RegisterEvent("UNIT_QUEST_LOG_CHANGED", function(_, unit) if type(unit) == "string" and unit:find("^party") then cambio() end end)
A.RegisterEvent("QUEST_ACCEPTED", cambio)
