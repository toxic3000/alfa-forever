-- Alfa - Rutas: «Zona peligrosa» (toxic3000 / La Jauría). GPL-3.0.
-- 1.2.8
--
-- Al entrar a una zona cuyos enemigos están muy por encima de ti (su nivel
-- más bajo es el tuyo + 4 o más, la misma regla del motor en Nav/Danger.lua),
-- un aviso corto una vez por zona y sesión: «Cuidado: aquí los enemigos son
-- nivel 30–35». Los niveles son los del motor (Maps.GetZoneLevels, solo se
-- leen) y, si faltan, los del cliente (C_Map.GetMapLevels). Una subzona sin
-- niveles propios toma los de su zona. Nunca en instancias ni en combate (lo
-- de una pelea se dice al terminarla). Ajuste rutas.zonaPeligrosa.
--
--   Peligro.Revisar() -> dijo, por qué   lo mira ahora (el banco lo llama)
--   Peligro.Niveles(uiMapID) -> min, max, uiMapID de la zona | nil

local ADDON, M = ...
local A, L = M.A, M.L
local Pg = {}
M.Peligro = Pg

A.RegisterDefaults(M.ID, { zonaPeligrosa = true })

local type, tonumber, pcall = type, tonumber, pcall
local format = string.format

local ARRIBA = 4  -- niveles: la zona empieza así de arriba del tuyo
local SUBIR = 6   -- cuántos mapas padre se miran (subzona -> zona)

local function enCombate() return InCombatLockdown and InCombatLockdown() or false end
local function secreto(v) return issecretvalue and issecretvalue(v) or false end

local function num(v)
	if secreto(v) then return nil end
	v = tonumber(v)
	return v and v > 0 and v or nil
end

local dichas = {}  -- uiMapID de zona -> true (esta sesión)
local esperando = false -- llegó en combate: se mira al terminar

local function nivelesDe(id)
	local Mp = A.Maps
	if Mp and type(Mp.GetZoneLevels) == "function" then
		local ok, lo, hi = pcall(Mp.GetZoneLevels, id)
		lo, hi = ok and num(lo), ok and num(hi)
		if lo and hi then return lo, hi end
	end
	local f = C_Map and C_Map.GetMapLevels
	if type(f) == "function" then
		local ok, lo, hi = pcall(f, id)
		lo, hi = ok and num(lo), ok and num(hi)
		if lo and hi and hi >= lo then return lo, hi end
	end
	return nil
end

function Pg.Niveles(id)
	id = num(id)
	for _ = 1, SUBIR do
		if not id then return nil end
		local lo, hi = nivelesDe(id)
		if lo then return lo, hi, id end
		local info = C_Map and C_Map.GetMapInfo and select(2, pcall(C_Map.GetMapInfo, id))
		id = type(info) == "table" and num(info.parentMapID) or nil
	end
	return nil
end

local function mapaJugador()
	local f = C_Map and C_Map.GetBestMapForUnit
	if type(f) ~= "function" then return nil end
	local ok, id = pcall(f, "player")
	return ok and num(id) or nil
end

local function enInstancia()
	if not IsInInstance then return false end
	local ok, dentro = pcall(IsInInstance)
	return ok and dentro == true
end

local function nivelJugador()
	local ok, n = pcall(UnitLevel, "player")
	return ok and num(n) or nil
end

local function nombreZona(id)
	local n = M.Zona(id)
	if n then return n end
	local f = rawget(_G, "GetZoneText")
	local ok, z = false, nil
	if type(f) == "function" then ok, z = pcall(f) end
	if ok and type(z) == "string" and not secreto(z) and z ~= "" then return z end
	return L["Esta zona"]
end

function Pg.Revisar()
	if A.Get(M.ID .. ".zonaPeligrosa") == false then return false, "apagado" end
	if enInstancia() then return false, "instancia" end
	if enCombate() then esperando = true return false, "combate" end
	esperando = false
	local nivel = nivelJugador()
	local lo, hi, zona = Pg.Niveles(mapaJugador())
	if not (nivel and lo) then return false, "sinDatos" end
	if dichas[zona] then return false, "dicha" end
	if lo < nivel + ARRIBA then return false, "segura" end
	dichas[zona] = true
	local rango = lo == hi and tostring(lo) or (lo .. "–" .. hi)
	M.Aviso(nombreZona(zona), format(L["Cuidado: aquí los enemigos son nivel %s."], rango),
		{ icono = "ic-aviso", tono = "aviso", duracion = 8 })
	return true, "aviso"
end

-- Para el banco.
function Pg.Reiniciar() dichas, esperando = {}, false end

local pendiente = false
local function pronto(seg)
	if pendiente then return end
	pendiente = true
	A.After(seg or 2, function()
		pendiente = false
		pcall(Pg.Revisar)
	end)
end

A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() pronto(2) end)
A.RegisterEvent("ZONE_CHANGED", function() pronto(2) end)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() pronto(4) end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() if esperando then pronto(2) end end)
