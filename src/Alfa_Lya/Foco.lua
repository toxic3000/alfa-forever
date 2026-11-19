-- Alfa - Lya: el modo foco (1.2.9). toxic3000 / La Jauría. GPL-3.0.
--
--   lya.foco (prendido de fábrica): en una mazmorra o una banda y en combate,
--   Lya se hace chiquita y tenue, se calla (solo lo importante espera a que
--   termine) y en combate no atrapa clics (UI.Foco en Lya.lua). Al salir del
--   combate y de la instancia vuelve como estaba. El rastreador hace lo suyo
--   leyendo el mismo ajuste (N.Get("lya", "foco")).
--
--   Fo.Toca() -> true si ahora toca el foco    Fo.Revisar()
--   AlfaLya.EnFoco() -> true si Lya está en foco ahora

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local pcall, type, rawget = pcall, type, rawget

local Fo = {}
M.Foco = Fo

local function secreto(v) return issecretvalue ~= nil and v ~= nil and issecretvalue(v) and true or false end

local combate = false

local function enInstancia()
	if not IsInInstance then return false end
	local ok, dentro, tipo = pcall(IsInInstance)
	if not ok or secreto(dentro) or secreto(tipo) or dentro ~= true then return false end
	return tipo == "party" or tipo == "raid"
end

local function peleando()
	if combate then return true end
	if InCombatLockdown and InCombatLockdown() then return true end
	if UnitAffectingCombat then
		local v = UnitAffectingCombat("player")
		return not secreto(v) and v == true
	end
	return false
end

function Fo.Toca()
	if N.Get(ID, "foco") == false then return false end
	return peleando() or enInstancia()
end

function Fo.Revisar()
	local UI = M.UI
	if UI and UI.Foco then UI.Foco(Fo.Toca()) end
end

A.RegisterEvent("PLAYER_REGEN_DISABLED", function() combate = true Fo.Revisar() end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() combate = false Fo.Revisar() end)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() combate = false Fo.Revisar() end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() Fo.Revisar() end)
A.On("SETTING_CHANGED", function(path)
	if path == ID .. ".foco" or path == ID or path == "" then Fo.Revisar() end
end)

local API = rawget(_G, "AlfaLya")
if type(API) == "table" then
	function API.EnFoco() local UI = M.UI return UI and UI.EnFoco and UI.EnFoco() or false end
end
