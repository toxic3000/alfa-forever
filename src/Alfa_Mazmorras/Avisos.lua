-- Alfa - Mazmorras: los avisos de jefes del propio juego (Toxic / La Jauría). GPL-3.0.
--
-- Forever trae la línea de tiempo de encuentros (C_EncounterTimeline,
-- Blizzard_EncounterTimeline) y los avisos de encuentros (C_EncounterWarnings,
-- Blizzard_EncounterWarnings). Alfa no los reinventa: los expone con una
-- explicación sencilla. Las CVars y sus dependencias son las del panel de
-- opciones de Blizzard (Blizzard_SettingsDefinitions_Frame/AdvancedOptions.lua):
--   combatWarningsEnabled                    todo el sistema de avisos de jefes
--   encounterWarningsEnabled                 mensajes de aviso en pantalla
--   encounterWarningsLevel                   0 leves y más, 1 medianos y más, 2 solo graves
--                                            (Enum.EncounterEventSeverity)
--   encounterWarningsHideIfNotTargetingPlayer
--   encounterTimelineEnabled                 la línea de tiempo del jefe
--   encounterTimelineHideLongCountdowns
--   encounterTimelineHideQueuedCountdowns
--   encounterTimelineHideForOtherRoles
--   encounterTimelineIconographyEnabled      íconos de apoyo (tanque, cura, daño...)
-- Cada una se muestra solo si el cliente la tiene (C_CVar.GetCVar no da nil),
-- y nunca se cambia en combate.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local D = M.D

local type, tostring, pcall, ipairs = type, tostring, pcall, ipairs

local Av = {}
M.Avisos = Av

local function cvar(nombre)
	if not (C_CVar and C_CVar.GetCVar) then return nil end
	local v = D.Legible(D.Llamar(C_CVar.GetCVar, nombre))
	return type(v) == "string" and v or nil
end

function Av.Existe(nombre) return cvar(nombre) ~= nil end

function Av.Bool(nombre)
	local v = cvar(nombre)
	return v ~= nil and v ~= "0" and v ~= "" and v ~= "false"
end

function Av.Numero(nombre)
	return tonumber(cvar(nombre) or "")
end

-- valor: true/false, un número, o nil (el valor por omisión del cliente).
-- -> true si quedó puesto
function Av.Poner(nombre, valor)
	if InCombatLockdown and InCombatLockdown() then
		N.Imprimir(L["Esto no se puede cambiar en combate. Inténtalo al terminar la pelea."])
		return false
	end
	if not (C_CVar and C_CVar.SetCVar) then return false end
	local v
	if valor == nil then
		v = D.Legible(D.Llamar(C_CVar.GetCVarDefault, nombre))
		if type(v) ~= "string" then return false end
	elseif type(valor) == "boolean" then
		v = valor and "1" or "0"
	else
		v = tostring(valor)
	end
	local ok = pcall(C_CVar.SetCVar, nombre, v)
	return ok and cvar(nombre) == v
end

-- Lo que Alfa recomienda a quien empieza: todo prendido, mensajes medianos
-- y graves, íconos de ayuda. -> cuántas quedaron puestas, cuántas existen
local RECOMENDADO = {
	{ "combatWarningsEnabled", true }, { "encounterTimelineEnabled", true },
	{ "encounterTimelineIconographyEnabled", true }, { "encounterWarningsEnabled", true },
	{ "encounterWarningsLevel", 1 }, { "encounterWarningsHideIfNotTargetingPlayer", false },
}
function Av.Recomendado()
	if InCombatLockdown and InCombatLockdown() then
		N.Imprimir(L["Esto no se puede cambiar en combate. Inténtalo al terminar la pelea."])
		return 0, 0
	end
	local puestas, hay = 0, 0
	for _, r in ipairs(RECOMENDADO) do
		if Av.Existe(r[1]) then
			hay = hay + 1
			if Av.Poner(r[1], r[2]) then puestas = puestas + 1 end
		end
	end
	return puestas, hay
end

-- La función existe y responde: true, false o nil (no se sabe).
local function disponible(ns)
	local api = _G[ns]
	if type(api) ~= "table" or type(api.IsFeatureAvailable) ~= "function" then return nil end
	local v = D.Legible(D.Llamar(api.IsFeatureAvailable))
	if type(v) ~= "boolean" then return nil end
	return v
end

function Av.LineaDisponible() return disponible("C_EncounterTimeline") end
function Av.MensajesDisponibles() return disponible("C_EncounterWarnings") end

local function activa(ns)
	local api = _G[ns]
	if type(api) ~= "table" or type(api.IsFeatureEnabled) ~= "function" then return nil end
	local v = D.Legible(D.Llamar(api.IsFeatureEnabled))
	if type(v) ~= "boolean" then return nil end
	return v
end

function Av.LineaActiva() return activa("C_EncounterTimeline") end
function Av.MensajesActivos() return activa("C_EncounterWarnings") end

---------------------------------------------------------------------------
-- Probar la línea de tiempo: tres marcas falsas (AddScriptEvent: eventos
-- puestos por un script) que se borran solas. Solo fuera de
-- combate y fuera de instancias, para no mezclarse con un jefe de verdad.
---------------------------------------------------------------------------

local PRUEBAS = { 6, 11, 16 } -- segundos
local ICONO = 134400 -- Interface\Icons\INV_Misc_QuestionMark

-- -> true, o false y la razón (texto para el jugador)
function Av.Probar()
	local api = C_EncounterTimeline
	if type(api) ~= "table" or type(api.AddScriptEvent) ~= "function" then
		return false, L["Tu cliente no tiene la línea de tiempo de jefes."]
	end
	if InCombatLockdown and InCombatLockdown() then
		return false, L["Espera a salir de combate para probarla."]
	end
	local C = A.Compat
	if C and D.Llamar(C.IsInInstance) then
		return false, L["Pruébala fuera de mazmorras y bandas."]
	end
	if Av.LineaActiva() == false then
		return false, L["Primero prende la línea de tiempo del jefe."]
	end
	local ids = {}
	for i, seg in ipairs(PRUEBAS) do
		local ok, id = pcall(api.AddScriptEvent, {
			spellID = 6673, iconFileID = ICONO, duration = seg, maxQueueDuration = 0,
			overrideName = string.format(L["Prueba de Alfa %d"], i),
		})
		if ok and id ~= nil then ids[#ids + 1] = id end
	end
	if #ids == 0 then return false, L["El juego no aceptó la prueba."] end
	if A.After and type(api.CancelScriptEvent) == "function" then
		A.After(PRUEBAS[#PRUEBAS] + 4, function()
			for _, id in ipairs(ids) do pcall(api.CancelScriptEvent, id) end
		end)
	end
	return true
end

-- Cualquier cambio de estas CVars (desde aquí o desde las opciones del
-- juego) repinta la página.
-- (en minúsculas: el nombre que trae CVAR_UPDATE puede venir con otras mayúsculas)
local MIAS = {}
for _, n in ipairs({ "combatWarningsEnabled", "encounterWarningsEnabled", "encounterWarningsLevel",
	"encounterWarningsHideIfNotTargetingPlayer", "encounterTimelineEnabled",
	"encounterTimelineHideLongCountdowns", "encounterTimelineHideQueuedCountdowns",
	"encounterTimelineHideForOtherRoles", "encounterTimelineIconographyEnabled" }) do
	MIAS[n:lower()] = true
end
A.RegisterEvent("CVAR_UPDATE", function(_, nombre)
	nombre = D.Legible(nombre)
	if type(nombre) == "string" and MIAS[nombre:lower()] then D.Avisar("avisos") end
end)
