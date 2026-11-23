-- Alfa - Rutas: modo foco en el rastreador (toxic3000 / La Jauría). GPL-3.0.
-- 1.2.9
--
-- Con el modo foco de Lya prendido (el ajuste lya.foco, lo crea Alfa_Lya), el
-- rastreador se vuelve compacto en mazmorras y en combate, y al salir vuelve
-- a como lo tenías (la vista amplia o la compacta: no se toca tu ajuste). En
-- foco tampoco salen los avisos que pueden esperar (élite, compartir).
--
--   Foco.Activo() -> bool    el rastreador va compacto por el foco ahora

local ADDON, M = ...
local A, N = M.A, M.N
local Fo = {}
M.Foco = Fo

local pelea = false -- entre PLAYER_REGEN_DISABLED y _ENABLED

local function prendido()
	local get = N and N.Get
	if type(get) ~= "function" then return false end
	local ok, v = pcall(get, "lya", "foco")
	return ok and v == true
end

local function enMazmorra()
	if not IsInInstance then return false end
	local ok, dentro, tipo = pcall(IsInInstance)
	if not ok or not N.Si(dentro) then return false end -- 1.3.7: secretos
	local t = N.Leer(tipo)
	return t == "party" or t == "raid" or t == "scenario"
end

local function enCombate()
	return pelea or (InCombatLockdown and InCombatLockdown()) or false
end

function Fo.Activo()
	if not prendido() then return false end
	return enCombate() or enMazmorra()
end

local function repintar()
	local Rs = M.Rastreador
	if Rs and Rs.Luego then Rs.Luego() end
end

A.RegisterEvent("PLAYER_REGEN_DISABLED", function() pelea = true if prendido() then repintar() end end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() pelea = false if prendido() then repintar() end end)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() if prendido() then repintar() end end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() if prendido() then repintar() end end)
A.On("SETTING_CHANGED", function(ruta) if ruta == "lya.foco" then repintar() end end)
