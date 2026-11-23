-- Alfa - Lya: un brinco al llegar (1.3.7c). toxic3000 / La Jauría. GPL-3.0.
--
-- Cuando llegas a donde apunta la flecha (la placa de llegada sale: el motor
-- manda ALFA_LLEGADA desde Nav/Arrow.lua), Lya da un brinco de gusto y se
-- queda atenta un momento. Sin palabras ni sonido: se ve, no estorba.
-- Nunca en combate, ni mientras habla, ni dormida de verdad (la despierta el
-- brinco solo si estaba echada a la vista), ni dos veces por el mismo lugar en
-- REPETIR segundos (la flecha puede ir y venir en la orilla del radio).
-- Ajuste: lya.brincoLlegar (de fábrica, prendido).
--   Ll.AlLlegar(target) -> true si brincó  (para el banco)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local ID = M.ID

local type, tostring, tonumber = type, tostring, tonumber

local Ll = {}
M.Llegada = Ll

local REPETIR = 60
Ll.REPETIR = REPETIR
local ultimo, cuando = nil, -math.huge

local function ahora() return GetTime and GetTime() or 0 end

local function clave(t)
	if type(t) ~= "table" then return "?" end
	return tostring(t.map) .. ":" .. tostring(tonumber(t.x) and math.floor(t.x) or t.x) .. ":" .. tostring(tonumber(t.y) and math.floor(t.y) or t.y) .. ":" .. tostring(t.label)
end

function Ll.AlLlegar(target)
	if N.Get(ID, "brincoLlegar") == false or N.Get(ID, "mostrar") == false then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	if N.Ocupado and N.Ocupado("gesto") then return false end
	local UI = M.UI
	if not (UI and UI.Visible and UI.Visible()) then return false end
	if UI.Hablando and UI.Hablando() then return false end
	local k = clave(target)
	if k == ultimo and ahora() - cuando < REPETIR then return false end
	ultimo, cuando = k, ahora()
	UI.Saltar()
	if N.Una then N.Una("lya.llegada", 0.7, function() if UI.Pose then UI.Pose("atenta", 1.5) end end) end
	return true
end

function Ll.Olvidar() ultimo, cuando = nil, -math.huge end

if A.On then A.On("ALFA_LLEGADA", function(t) Ll.AlLlegar(t) end) end
