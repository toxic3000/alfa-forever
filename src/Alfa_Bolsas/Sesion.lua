-- Alfa - Bolsas: el oro de esta sesión (1.2.8). GPL-3.0.
--
-- Desde que entras al juego, Alfa cuenta cuánto oro ganaste (solo lo que
-- sube), cuánto gastaste y el cambio neto, y saca lo que ganas por hora.
-- Se ve en el pie de la ventana de bolsas (al pasar el ratón) y en la
-- página Bolsas. Nada se guarda: cada sesión empieza en cero.
--   AlfaBolsas.Sesion() -> { oro = cambio neto en cobre, ganado, gastado,
--                            segundos = tiempo de la sesión,
--                            porHora = cobre por hora (de lo ganado) }
-- Cliente: GetMoney, PLAYER_MONEY.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local type, floor, max, format = type, math.floor, math.max, string.format

local Se = {}
M.Sesion = Se

local MIN_SEG = 60 -- antes de un minuto no se calcula por hora

local inicio, base, ultimo
local ganado, gastado = 0, 0

local function dinero() return M.Num(GetMoney and GetMoney()) end
local function ahora() return GetTime and GetTime() or 0 end

local function empezar()
	local d = dinero()
	if not d then return false end
	inicio, base, ultimo = ahora(), d, d
	ganado, gastado = 0, 0
	return true
end

local function alCambiar()
	local d = dinero()
	if not d then return end
	if not ultimo then empezar() return end
	local delta = d - ultimo
	if delta > 0 then ganado = ganado + delta elseif delta < 0 then gastado = gastado - delta end
	ultimo = d
	M.Avisar("SESION")
end

-- -> { oro, ganado, gastado, segundos, porHora }
function Se.Datos()
	if not inicio then empezar() end
	local seg = inicio and max(0, ahora() - inicio) or 0
	local porHora = seg >= MIN_SEG and floor(ganado * 3600 / seg) or 0
	return {
		oro = (ultimo or 0) - (base or 0), ganado = ganado, gastado = gastado,
		segundos = floor(seg), porHora = porHora,
	}
end

-- "Esta sesión: +1g 20s · 2g 40s por hora" (nil si aún no ganaste nada).
function Se.Texto()
	local s = Se.Datos()
	if s.ganado <= 0 then return nil end
	if s.porHora > 0 then
		return format(L["Esta sesión: +%s · %s por hora"], N.Dinero(s.ganado, true), N.Dinero(s.porHora, true))
	end
	return format(L["Esta sesión: +%s"], N.Dinero(s.ganado, true))
end

-- Las líneas del cuadro de información.
function Se.Lineas()
	local s = Se.Datos()
	local out = {}
	out[#out + 1] = format(L["Ganaste: %s"], N.Dinero(s.ganado, true))
	if s.gastado > 0 then out[#out + 1] = format(L["Gastaste: %s"], N.Dinero(s.gastado, true)) end
	local neto = s.oro >= 0 and ("+" .. N.Dinero(s.oro, true)) or N.Dinero(s.oro, true)
	out[#out + 1] = format(L["En total: %s"], neto)
	if s.porHora > 0 then out[#out + 1] = format(L["Por hora: %s"], N.Dinero(s.porHora, true)) end
	out[#out + 1] = format(L["Tiempo: %s"], N.Duracion(s.segundos))
	return out
end

A.RegisterEvent("PLAYER_ENTERING_WORLD", function() if not inicio then empezar() end end)
A.RegisterEvent("PLAYER_MONEY", alCambiar)

-- Para otros módulos (Lya, Inicio): AlfaBolsas.Sesion().
AlfaBolsas = type(rawget(_G, "AlfaBolsas")) == "table" and rawget(_G, "AlfaBolsas") or {}
AlfaBolsas.Sesion = function() return Se.Datos() end
