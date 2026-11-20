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
-- 1.3.1: los pines solo se ven con un mapa abierto (el del juego o el de
-- Alfa), así que con los dos cerrados lo que cambia en el grupo solo deja la
-- capa «pendiente» y se pinta al abrir uno (su OnShow o, el de Alfa, un
-- vistazo por segundo mientras haya algo pendiente). El lugar de cada misión
-- se guarda (lugares[qid], por si está lista para entregar o no) y se
-- olvida al cambiar de zona, al cargar el Codex o al dejar el grupo.
--
--   MapaGrupo.Datos() -> { { qid, titulo, quienes = { nombre... }, tuya, p = { map, x, y, f } } }
--   MapaGrupo.Pintar()       pinta ya (aunque no haya mapa abierto)
--   MapaGrupo.Luego()        lo de los eventos: en 2 s, o «pendiente» si no hay mapa
--   MapaGrupo.Pendiente() -> bool    MapaGrupo.Olvidar()   (los lugares guardados)

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

-- El nombre completo de una unidad («Ana Smith» en Forever, «Ana-Reino»
-- fuera) y el corto para mostrar (Compat.UnitFullName); sin él, UnitName.
local function nombres(u)
	local Cp = CP()
	if Cp and type(Cp.UnitFullName) == "function" then
		local ok, completo, corto = pcall(Cp.UnitFullName, u)
		if ok and completo == false then return nil end -- secreto
		if ok and type(completo) == "string" and completo ~= "" then
			return completo, (type(corto) == "string" and corto ~= "") and corto or completo
		end
	end
	local n, reino = UnitName(u)
	if type(n) ~= "string" or secreto(n) or n == "" then return nil end
	if type(reino) == "string" and not secreto(reino) and reino ~= "" then return n .. "-" .. reino, n end
	return n, n
end

-- Lo que la manada sabe que lleva ese lobo: { [qid] = true } | nil (no se sabe).
local function deLaManada(completo)
	local Ma = rawget(_G, "AlfaManada")
	if not (completo and type(Ma) == "table" and type(Ma.MisionesDe) == "function") then return nil end
	local ok, set = pcall(Ma.MisionesDe, completo)
	return ok and type(set) == "table" and set or nil
end

-- Los de tu grupo: { unidad, nombre (para mostrar), completo, misiones }.
-- 1.3.1: el nombre completo, para que La Jauría lo encuentre (antes iba
-- solo el primer valor de UnitName), y su lista una vez por lobo, no una vez
-- por misión.
local function miembros()
	local out = {}
	for i = 1, 4 do
		local u = "party" .. i
		if UnitExists and UnitExists(u) then
			local completo, corto = nombres(u)
			if completo then out[#out + 1] = { u = u, nombre = corto, completo = completo, misiones = deLaManada(completo) } end
		end
	end
	return out
end
Mg.Miembros = miembros

local function laLleva(m, qid)
	if m.misiones then return m.misiones[qid] and true or false end
	local QL = C_QuestLog
	if QL and QL.IsUnitOnQuest then
		local ok, si = pcall(QL.IsUnitOnQuest, m.u, qid)
		if ok and not secreto(si) then return si and true or false end
	end
	return false
end

-- 1.3.1: el lugar ya calculado de cada misión (Indice.PasosMision busca entre
-- todas las apariciones y fuentes: es lo caro). qid -> { lista, p | false }
local lugares = {}
function Mg.Olvidar() lugares = {} end

-- El lugar de la misión: lo que falta o su entrega.
local function lugar(qid, desde)
	local Cp = CP()
	local lista = Cp and Cp.IsOnQuest and Cp.IsOnQuest(qid) and Cp.IsQuestReadyForTurnIn and Cp.IsQuestReadyForTurnIn(qid) and true or false
	local g = lugares[qid]
	if g and g.lista == lista then return g.p or nil end
	local C = CX()
	local q = C and C.Quest(qid)
	local I = M.Indice
	local ok, pm = pcall(I.PasosMision, q, desde)
	local p = ok and pm and ((not lista and pm.objetivo) or pm.fin) or nil
	local out = p and p.map and p.x and p.y and { map = p.map, x = p.x, y = p.y, f = p.f } or nil
	-- 1.3.2: ¿el pin va a la entrega? (lista, o sin lugar para lo que falta)
	if out then out.entrega = p == pm.fin end
	lugares[qid] = { lista = lista, p = out or false }
	return out
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
	-- Lo que la manada sabe que llevan y tú no (la lista ya leída en miembros()).
	for _, m in ipairs(gente) do
		for qid in pairs(m.misiones or {}) do
			qid = tonumber(qid)
			if qid and not (Cp and Cp.IsOnQuest and Cp.IsOnQuest(qid)) then sumar(qid, m.nombre, false) end
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
			icon = d.p.entrega and "map:quest-turnin" or "map:kill", size = 14, -- 1.3.2: la entrega, con su ícono priority = 2, ring = rgb(d.tuya and "acento" or "aviso"),
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

-- 1.3.1: ¿hay un mapa a la vista? El del juego o el de Alfa
-- (AlfaMundo.ZonasALaVista da nil con el mapa de Alfa cerrado).
local function mapaAbierto()
	local w = rawget(_G, "WorldMapFrame")
	if w and w.IsShown and w:IsShown() then return true end
	local Mu = rawget(_G, "AlfaMundo")
	if type(Mu) == "table" and type(Mu.ZonasALaVista) == "function" then
		local ok, z = pcall(Mu.ZonasALaVista)
		if ok and z ~= nil then return true end
	end
	return false
end
Mg.MapaAbierto = mapaAbierto

local RELOJ = "rutas.mapaGrupo"
local programado = false -- la tanda de 2 s ya va en camino
local porPintar = false  -- algo cambió con los mapas cerrados

function Mg.Pendiente() return porPintar end

local function pintarPendiente()
	porPintar = false
	M.N.Quitar(RELOJ)
	Mg.Pintar()
end

-- Mientras haya algo pendiente, un vistazo por segundo (dos IsShown): el
-- mapa de Alfa no avisa al abrirse.
local function vigilar()
	if not porPintar then M.N.Quitar(RELOJ) return end
	if mapaAbierto() then pintarPendiente() end
end

local function luego()
	if programado then return end
	programado = true
	A.After(2, function()
		programado = false
		if not (encendido() and enGrupo()) then
			-- Sin grupo (o apagado): solo se limpia la capa, que no cuesta nada.
			Mg.Olvidar()
			pintarPendiente()
		elseif mapaAbierto() then
			pintarPendiente()
		else
			porPintar = true
			if not M.N.HayTarea(RELOJ) then M.N.Cada(RELOJ, 1, vigilar, { fueraDeCombate = true }) end
		end
	end)
end
Mg.Luego = luego

A.RegisterEvent("GROUP_ROSTER_UPDATE", luego)
A.RegisterEvent("QUEST_ACCEPTED", luego)
A.RegisterEvent("QUEST_REMOVED", luego)
A.RegisterEvent("UNIT_QUEST_LOG_CHANGED", function(_, u) if type(u) == "string" and u:match("^party") then luego() end end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() Mg.Olvidar() luego() end)
A.On("CODEX_LOADED", function() Mg.Olvidar() luego() end)

A.OnLogin(function()
	-- El mapa del juego avisa al abrirse: lo pendiente se pinta ya.
	local w = rawget(_G, "WorldMapFrame")
	if w and w.HookScript then
		w:HookScript("OnShow", function() if porPintar then pintarPendiente() end end)
	end
	local Mu = rawget(_G, "AlfaMundo")
	if type(Mu) == "table" and type(Mu.RegistrarCapa) == "function" then
		pcall(Mu.RegistrarCapa, { id = CAPA, grupo = L["Viajes"], nombre = L["Misiones de tu grupo"],
			ayuda = L["Dónde está lo que pide cada misión de tu grupo y quién la lleva."], color = "acento", activa = encendido(),
			alCambiar = function(on) A.Set(M.ID .. ".mapaGrupo", on and true or false) Mg.Pintar() end })
	end
	luego()
end)
