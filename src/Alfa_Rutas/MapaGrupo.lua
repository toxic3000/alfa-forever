-- Alfa - Rutas: el mapa de misiones de tu grupo (toxic3000 / La Jauría).
-- GPL-3.0.
-- 1.3.0
--
-- En grupo, un pin en el mapa del mundo donde está lo que pide cada misión
-- que comparten (lo que falta, o su entrega si ya la terminaron), con quién
-- la lleva: «Ana, Beto». Quién la lleva sale del juego
-- (C_QuestLog.IsUnitOnQuest) o, si la manada lo sabe, de La Jauría
-- (AlfaManada.MisionesDe(nombre)); así también salen las misiones que lleva
-- alguien de tu grupo y tú no (con «Solo ellos»). Los lugares, del Codex
-- (Indice.PasosMision), solo si ya está cargado: aquí no se carga. Nada en
-- combate (se pone al día al salir). Ajuste rutas.mapaGrupo.
--
--   MapaGrupo.Datos() -> { { qid, titulo, quienes = { nombre... }, tuya, p = { map, x, y, f } } }
--   MapaGrupo.Pintar()

local ADDON, M = ...
local A, L, K = M.A, M.L, M.K
local Mg = {}
M.MapaGrupo = Mg

A.RegisterDefaults(M.ID, { mapaGrupo = true })

local CAPA = "rutas.grupo"
local type, ipairs, pairs, tonumber, pcall = type, ipairs, pairs, tonumber, pcall
local format, concat = string.format, table.concat

local MAX_PINES = 25

local function CP() return M.Motor("Compat") end
local function CX() return M.Motor("Codex") end
local function encendido() return A.Get(M.ID .. ".mapaGrupo") ~= false end
local function enCombate() return InCombatLockdown and InCombatLockdown() or false end
local function secreto(v) return issecretvalue and issecretvalue(v) or false end

local function enGrupo()
	return IsInGroup and IsInGroup() and not (IsInRaid and IsInRaid()) or false
end

-- Los de tu grupo: { unidad, nombre }.
local function miembros()
	local out = {}
	for i = 1, 4 do
		local u = "party" .. i
		if UnitExists and UnitExists(u) then
			local n = UnitName(u)
			if type(n) == "string" and not secreto(n) and n ~= "" then out[#out + 1] = { u = u, nombre = n } end
		end
	end
	return out
end

local function laLleva(m, qid)
	local Ma = rawget(_G, "AlfaManada")
	if type(Ma) == "table" and type(Ma.MisionesDe) == "function" then
		local ok, set = pcall(Ma.MisionesDe, m.nombre)
		if ok and type(set) == "table" then return set[qid] and true or false end
	end
	local QL = C_QuestLog
	if QL and QL.IsUnitOnQuest then
		local ok, si = pcall(QL.IsUnitOnQuest, m.u, qid)
		if ok and not secreto(si) then return si and true or false end
	end
	return false
end

-- El lugar de la misión: lo que falta o su entrega.
local function lugar(qid, desde)
	local C = CX()
	local q = C and C.Quest(qid)
	local I = M.Indice
	local ok, pm = pcall(I.PasosMision, q, desde)
	if not (ok and pm) then return nil end
	local Cp = CP()
	local lista = Cp and Cp.IsOnQuest and Cp.IsOnQuest(qid) and Cp.IsQuestReadyForTurnIn and Cp.IsQuestReadyForTurnIn(qid)
	local p = (not lista and pm.objetivo) or pm.fin
	if p and p.map and p.x and p.y then return { map = p.map, x = p.x, y = p.y, f = p.f } end
	return nil
end

function Mg.Datos()
	if not (encendido() and enGrupo()) or enCombate() then return {} end
	local C = CX()
	if not (C and C.IsLoaded and C.IsLoaded()) then return {} end
	local Cp = CP()
	local gente = miembros()
	if #gente == 0 then return {} end
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	local porId, orden = {}, {}
	local function sumar(qid, nombre, tuya)
		local d = porId[qid]
		if not d then
			d = { qid = qid, quienes = {}, tuya = tuya }
			porId[qid] = d
			orden[#orden + 1] = d
		end
		if nombre then d.quienes[#d.quienes + 1] = nombre end
	end
	for _, qid in ipairs(Cp and Cp.GetLogQuests and Cp.GetLogQuests() or {}) do
		qid = tonumber(qid)
		if qid then
			for _, m in ipairs(gente) do
				if laLleva(m, qid) then sumar(qid, m.nombre, true) end
			end
		end
	end
	-- Lo que la manada sabe que llevan y tú no.
	local Ma = rawget(_G, "AlfaManada")
	if type(Ma) == "table" and type(Ma.MisionesDe) == "function" then
		for _, m in ipairs(gente) do
			local ok, set = pcall(Ma.MisionesDe, m.nombre)
			for qid in pairs(ok and type(set) == "table" and set or {}) do
				qid = tonumber(qid)
				if qid and not (Cp and Cp.IsOnQuest and Cp.IsOnQuest(qid)) then sumar(qid, m.nombre, false) end
			end
		end
	end
	local out = {}
	for _, d in ipairs(orden) do
		if #out >= MAX_PINES then break end
		if #d.quienes > 0 then
			d.p = lugar(d.qid, desde)
			if d.p then
				d.titulo = M.TituloMision(d.qid)
				table.sort(d.quienes)
				out[#out + 1] = d
			end
		end
	end
	return out
end

local function rgb(nombre)
	local r, g, b = K.Color(nombre)
	return { r, g, b, 1 }
end

function Mg.Pines(datos)
	local out = {}
	for _, d in ipairs(datos or Mg.Datos()) do
		local quienes = concat(d.quienes, ", ")
		out[#out + 1] = {
			map = d.p.map, x = d.p.x, y = d.p.y, f = d.p.f,
			icon = "map:kill", size = 14, priority = 2, ring = rgb(d.tuya and "acento" or "aviso"),
			color = rgb(d.tuya and "acento" or "aviso"), badge = tostring(#d.quienes),
			tooltip = function(tip)
				tip:SetText(d.titulo, K.Color("texto"))
				tip:AddLine(format(L["La llevan: %s"], quienes), K.Color("acento"))
				if not d.tuya then tip:AddLine(L["Solo ellos: tú no la tienes."], K.Color("aviso")) end
			end,
		}
	end
	return out
end

function Mg.Pintar()
	local P = A.Pins
	if not (P and P.SetLayer and P.ClearLayer) then return end
	if enCombate() then
		M.N.FueraDeCombate("rutas:mapaGrupo", Mg.Pintar)
		return
	end
	local pines = Mg.Pines()
	if #pines > 0 then P.SetLayer(CAPA, pines, { world = true, minimap = false, edge = false }) else P.ClearLayer(CAPA) end
end

local pendiente = false
local function luego()
	if pendiente then return end
	pendiente = true
	A.After(2, function() pendiente = false Mg.Pintar() end)
end
Mg.Luego = luego

A.RegisterEvent("GROUP_ROSTER_UPDATE", luego)
A.RegisterEvent("QUEST_ACCEPTED", luego)
A.RegisterEvent("QUEST_REMOVED", luego)
A.RegisterEvent("UNIT_QUEST_LOG_CHANGED", function(_, u) if type(u) == "string" and u:match("^party") then luego() end end)
A.On("CODEX_LOADED", luego)

A.OnLogin(function()
	local Mu = rawget(_G, "AlfaMundo")
	if type(Mu) == "table" and type(Mu.RegistrarCapa) == "function" then
		pcall(Mu.RegistrarCapa, { id = CAPA, grupo = L["Viajes"], nombre = L["Misiones de tu grupo"],
			ayuda = L["Dónde está lo que pide cada misión de tu grupo y quién la lleva."], color = "acento", activa = encendido(),
			alCambiar = function(on) A.Set(M.ID .. ".mapaGrupo", on and true or false) Mg.Pintar() end })
	end
	luego()
end)
