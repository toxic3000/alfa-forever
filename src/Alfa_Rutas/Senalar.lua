-- Alfa - Rutas: señalar los objetos de tus misiones (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Pedido de Toxic: «en algunas misiones tengo que darle clic a ciertas cosas
-- (unas cajas) y recuerdo que esos objetos brillaban; me gustaría que los
-- objetos de misión tengan un resplandor que indique que ese es el que le
-- debes dar clic». El destello de los objetos de misión lo dibuja el juego
-- (y puede apagarse con poca densidad de partículas); un addon no puede
-- pintar sobre los objetos del mundo. Lo que sí puede es prender la señal
-- del propio juego para lo que se toca: con SoftTargetInteract y
-- SoftTargetIconGameObject, el objeto con el que puedes interactuar frente a
-- ti lleva su ícono encima (y la tecla de interactuar lo toma).
--
-- Solo mientras haga falta: si una de tus misiones pide tocar objetos (un
-- objetivo de tipo «object» sin terminar) o tu paso de la guía es tomar o
-- usar algo. Al dejar de hacer falta, tus valores vuelven tal cual. Nunca:
-- en combate, mientras la pesca tiene puestas las suyas (Pesca.lua), ni si tú
-- cambiaste esas variables (entonces mandan las tuyas hasta el próximo /reload).
-- SoftTargetIconInteract no se toca: el juego la guarda en caché para las
-- placas de nombre y, cambiada desde un addon, las contaminaría en combate.
--
--   Sn.HaceFalta() -> bool, por qué ("mision" | "guia" | nil)
--   Sn.Revisar()   pone o devuelve según haga falta (fuera de combate)
--   Sn.Puesto() -> bool
-- Ajuste: rutas.senalarObjetos (de fábrica, prendido).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local Sn = {}
M.Senalar = Sn

local type, ipairs, pairs, pcall, tonumber, tostring = type, ipairs, pairs, pcall, tonumber, tostring

A.RegisterDefaults(M.ID, { senalarObjetos = true })

-- Lo que Alfa pone mientras hace falta.
Sn.PONE = { SoftTargetInteract = "3", SoftTargetIconGameObject = "1" }

local escribiendo = false
local soltado = false -- el jugador cambió una de estas: no se vuelve a tocar en la sesión

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function leer(n)
	local f = (C_CVar and C_CVar.GetCVar) or rawget(_G, "GetCVar")
	if type(f) ~= "function" then return nil end
	local ok, v = pcall(f, n)
	if not ok or v == nil then return nil end
	return tostring(v)
end
local function poner(n, v)
	local f = (C_CVar and C_CVar.SetCVar) or rawget(_G, "SetCVar")
	if type(f) ~= "function" then return false end
	escribiendo = true
	local ok = pcall(f, n, v)
	escribiendo = false
	return ok
end
local function igual(a, b)
	if a == b then return true end
	local x, y = tonumber(a), tonumber(b)
	return x ~= nil and y ~= nil and x == y
end

-- Lo guardado vive en la cuenta: si el juego se cierra con la señal puesta,
-- al volver se devuelve lo tuyo.
local function datos()
	local d = N.Datos(M.ID)
	d.senalar = type(d.senalar) == "table" and d.senalar or {}
	return d.senalar
end
function Sn.Puesto() return type(datos().antes) == "table" end

local function pescaLasTiene()
	local P = rawget(_G, "AlfaPesca")
	return type(P) == "table" and type(P.TocaVariables) == "function" and P.TocaVariables() and true or false
end

---------------------------------------------------------------------------
-- ¿Hace falta?
---------------------------------------------------------------------------
local TOMAR = { interact = true, use = true, loot = true, collect = true }

local function objetivosDeObjeto()
	local QL = C_QuestLog
	if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo and QL.GetQuestObjectives) then return false end
	local ok, n = pcall(QL.GetNumQuestLogEntries)
	if not ok then return false end
	for i = 1, tonumber(n) or 0 do
		local okI, info = pcall(QL.GetInfo, i)
		local qid = okI and type(info) == "table" and not info.isHeader and N.LeerNumero(info.questID, nil)
		if qid then
			local okO, objs = pcall(QL.GetQuestObjectives, qid)
			for _, o in ipairs(okO and type(objs) == "table" and objs or {}) do
				local tipo, hecho = N.Leer(o.type), N.Leer(o.finished)
				if tipo == "object" and hecho ~= true then return true end
			end
		end
	end
	return false
end

local function pasoDeTomar()
	local E = A.Engine
	local ok, w = pcall(function() return E and E.GetWaypoint and E.GetWaypoint() end)
	if not (ok and type(w) == "table") then return false end
	-- (un enemigo no: eso lo marca su placa de nombre)
	return TOMAR[w.kind] == true and not w.npc and not w.unit
end

function Sn.HaceFalta()
	if A.Get(M.ID .. ".senalarObjetos") == false then return false end
	if objetivosDeObjeto() then return true, "mision" end
	if pasoDeTomar() then return true, "guia" end
	return false
end

---------------------------------------------------------------------------
-- Poner y devolver
---------------------------------------------------------------------------
local function devolver()
	local d = datos()
	local antes = d.antes
	if type(antes) ~= "table" then return end
	for n, v in pairs(antes) do
		-- Solo si sigue como la dejó Alfa (si la cambiaste, se queda la tuya).
		if igual(leer(n), Sn.PONE[n]) then poner(n, v) end
	end
	d.antes = nil
end

local function ponerSenal()
	local d = datos()
	if type(d.antes) == "table" then return end
	local antes = {}
	for n in pairs(Sn.PONE) do
		local v = leer(n)
		if v == nil then return end -- (un cliente sin estas variables: nada)
		antes[n] = v
	end
	d.antes = antes
	for n, v in pairs(Sn.PONE) do
		if not igual(leer(n), v) then poner(n, v) end
	end
end

function Sn.Revisar()
	if enCombate() or soltado then return end
	if pescaLasTiene() then return end
	if Sn.HaceFalta() then ponerSenal() else devolver() end
end

local function pronto() if N.Una then N.Una("rutas.senalar", 0.5, Sn.Revisar) else Sn.Revisar() end end

for _, ev in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
	A.RegisterEvent(ev, pronto)
end
if A.On then
	A.On("WAYPOINT_CHANGED", pronto)
	A.On("SETTING_CHANGED", function(ruta) if ruta == M.ID .. ".senalarObjetos" or ruta == M.ID or ruta == "" then pronto() end end)
end

-- Si tú cambias una de estas (Opciones del juego, otro addon), manda la tuya.
A.RegisterEvent("CVAR_UPDATE", function(_, nombre)
	if escribiendo or type(nombre) ~= "string" or not Sn.Puesto() then return end
	for n in pairs(Sn.PONE) do
		if n:lower() == nombre:lower() then
			-- (la pesca escribe las suyas: eso no es tuyo)
			if pescaLasTiene() then return end
			soltado = true
			datos().antes = nil
			return
		end
	end
end)

-- Al salir del juego, lo tuyo de vuelta.
A.RegisterEvent("PLAYER_LOGOUT", function() if not enCombate() then devolver() end end)

AlfaRuta = type(rawget(_G, "AlfaRuta")) == "table" and rawget(_G, "AlfaRuta") or {}
AlfaRuta.SenalarObjetos = function() return Sn.HaceFalta() end
