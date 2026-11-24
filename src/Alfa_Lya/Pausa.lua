-- Alfa - Lya: «¿Una pausa?» (1.3.8). toxic3000 / La Jauría. GPL-3.0.
--
--   Después de TRAMO segundos seguidos jugando, Lya te sugiere una pausa con
--   cariño, una sola vez por tramo. Un tramo empieza al entrar al juego (si
--   estuviste fuera PAUSA o más) y después de una pausa de verdad: ausente
--   (/afk) PAUSA o más. Dicha la sugerencia, empieza otro tramo (a las 4 horas
--   seguidas, otra). «En 30 min» la pospone. Nunca en combate ni en una
--   instancia (mazmorra, banda, campo de batalla): espera a que salgas. Lo
--   mira el latido de Lya (Cerebro.lua, revisarSesion), así que solo con
--   ella a la vista. Ajuste lya.pausa (de fábrica, sí).
--
--   Pa.Revisar() -> true si habló     Pa.Tramo() -> { desde, otraVez? }
--   Pa.NuevoTramo(t)   Pa.Observar()  (la ausencia, cada latido)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local type, tonumber, pcall, format, random = type, tonumber, pcall, string.format, math.random

local Pa = {}
M.Pausa = Pa

local TRAMO = 2 * 3600
local PAUSA = 10 * 60
local OTRA_VEZ = 30 * 60
Pa.TRAMO, Pa.PAUSA = TRAMO, PAUSA

local FRASES = {
	"Llevas %s seguidas de cacería, lobo. ¿Una pausa? Estírate, toma agua y aquí te espero.",
	"Ya van %s sin parar. Hasta las lobas descansan: levántate un ratito, yo cuido tu lugar.",
	"%s seguidas… ¡qué aguante! Unos minutos lejos de la pantalla y vuelves con más fuerza.",
	"Llevas %s jugando. Si te tomas un respiro, prometo no comerme tus salchichas.",
}

local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end
local function datos() return N.DatosPersonaje(ID) end

local function enInstancia()
	if not IsInInstance then return false end
	local ok, dentro = pcall(IsInInstance)
	return ok and N.Si(dentro)
end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

function Pa.Tramo()
	local d = datos()
	if type(d.tramo) ~= "table" or not tonumber(d.tramo.desde) then d.tramo = { desde = reloj() } end
	return d.tramo
end

-- (1.3.8 revisión) inicio: cuándo empezaste a jugar sin pausa de verdad (lo
-- que dice «Llevas…»); desde: el tramo de ahora (cuándo toca otra sugerencia).
-- seguir = true: otro tramo sin pausa (tras la sugerencia), el inicio se queda.
function Pa.NuevoTramo(t, seguir)
	local d = datos()
	local ahora = tonumber(t) or reloj()
	local antes = type(d.tramo) == "table" and (tonumber(d.tramo.inicio) or tonumber(d.tramo.desde)) or nil
	d.tramo = { desde = ahora, inicio = (seguir and antes) or ahora }
end

-- Ausente PAUSA o más: al volver, un tramo nuevo.
local afkDesde
function Pa.Observar()
	local afk = UnitIsAFK and N.Si(UnitIsAFK("player"))
	-- (1.3.8 revisión) La última vez que te vio jugando: salir un minuto no
	-- reinicia el tramo (PLAYER_ENTERING_WORLD lo compara con PAUSA).
	if not afk then datos().ultimaVez = reloj() end
	if afk then
		afkDesde = afkDesde or reloj()
	else
		if afkDesde and reloj() - afkDesde >= PAUSA then Pa.NuevoTramo() end
		afkDesde = nil
	end
	return afkDesde ~= nil
end

function Pa.Revisar()
	if N.Get(ID, "pausa") == false then return false end
	if Pa.Observar() then return false end
	if enCombate() or enInstancia() then return false end
	if N.Ocupado and N.Ocupado("lya") then return false end
	local t = Pa.Tramo()
	local cuando = tonumber(t.otraVez) or (t.desde + TRAMO)
	if reloj() < cuando then return false end
	local Ce = M.Cerebro
	if not Ce then return false end
	local dur = reloj() - (tonumber(t.inicio) or t.desde)
	local texto = format(L[FRASES[random(#FRASES)]], N.Duracion(dur, true))
	local ok = Ce.Decir({ texto = texto, clase = "pausa", cara = "normal", segundos = 14, lineas = 4, ancho = 340,
		acciones = { { texto = L["Recuérdamelo en 30 min"], fn = function() Pa.Tramo().otraVez = reloj() + OTRA_VEZ end } } })
	if ok == true then Pa.NuevoTramo(nil, true) end
	return ok == true
end

-- Al entrar: si estuviste fuera PAUSA o más, el tramo empieza de nuevo.
local entrado = false
A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, esLogin)
	if entrado then return end
	entrado = true
	local d = datos()
	local antes = tonumber(d.ultimaVez)
	if esLogin == true and (not antes or reloj() - antes >= PAUSA) then Pa.NuevoTramo() end
end)

-- Al salir: la última vez que jugaste (si Lya no estaba a la vista, el latido no la anotó).
A.RegisterEvent("PLAYER_LOGOUT", function()
	if afkDesde and reloj() - afkDesde >= PAUSA then Pa.NuevoTramo() end -- (ya descansaste ausente)
	datos().ultimaVez = reloj()
end)

-- Para el banco.
function Pa.Reiniciar() afkDesde, entrado = nil, true datos().tramo = nil end
