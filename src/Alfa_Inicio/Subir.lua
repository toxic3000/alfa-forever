-- Alfa - Inicio: cuánto te falta para subir de nivel (toxic3000 / La Jauría).
-- GPL-3.0. -- 1.3.7
--
-- «Nivel 34 en 1 h 20 min a tu ritmo» (169) y tu descanso a la vista (99),
-- en Hoy y en el cuadro de la barra de experiencia del juego (Barras.lua).
-- La cuenta, a tu ritmo de los últimos minutos (M.Sesion.Estado().ritmo):
--   * lo que dan tus misiones listas (AlfaRuta.XPListas) se resta: con
--     entregarlas ya avanzas sin cazar;
--   * el descanso duplica lo que ganas cazando hasta gastarlo: lo que falta
--     se cuenta con esa ayuda (una estimación: el ritmo ya trae algo de ella).
--
--   Subir.Datos() -> { nivel, siguiente, falta, listas, listasXP, descanso,
--       segundos | nil, maximo } | nil
--   Subir.Texto(d) -> «Nivel 34 en 1 h 20 min a tu ritmo» | nil
--   Subir.Descanso(d) -> «Descansado: doble experiencia hasta el 45 % del nivel 34» | nil
--   Subir.Lineas() -> { texto, ... } para el cuadro de la barra

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local num, miles = M.num, M.miles

local type, pcall, format, floor, max, min = type, pcall, string.format, math.floor, math.max, math.min

local Sb = {}
M.Subir = Sb

local function deRuta(nombre)
	local R0 = rawget(_G, "AlfaRuta")
	local fn = type(R0) == "table" and R0[nombre]
	return type(fn) == "function" and fn or nil
end

local MAX_SEG = 360000 -- más de 99 h ya no se dice

function Sb.Datos()
	local S = M.Sesion
	if not (S and S.Estado) then return nil end
	local e = S.Estado()
	if e.maximo then return { maximo = true, nivel = e.nivel } end
	local d = { nivel = e.nivel or 1, siguiente = (e.nivel or 1) + 1, falta = e.falta or 0, descanso = e.descanso or 0,
		xpAhora = e.xpAhora or 0, xpMax = e.xpMax or 0, listas = 0, listasXP = 0 }
	local fx = deRuta("XPListas")
	if fx then
		local ok, r = pcall(fx)
		if ok and type(r) == "table" then d.listas, d.listasXP = num(r.n) or 0, num(r.xp) or 0 end
	end
	local resto = max(0, d.falta - d.listasXP)
	d.resto = resto
	-- El descanso: lo que cazas cuenta doble hasta gastarlo.
	local cazar = resto
	if d.descanso > 0 then cazar = d.descanso * 2 >= resto and resto / 2 or resto - d.descanso end
	d.cazar = cazar
	local ritmo = num(e.ritmo)
	if resto <= 0 then
		d.segundos = 0
	elseif ritmo and ritmo > 0 then
		local s = cazar / ritmo * 3600
		if s < MAX_SEG then d.segundos = s end
	end
	return d
end

function Sb.Texto(d)
	d = d or Sb.Datos()
	if not d or d.maximo then return nil end
	if d.segundos == 0 and d.listas > 0 then
		return format(L["Entrega tus misiones listas y llegas al nivel %d"], d.siguiente)
	end
	if not d.segundos then return nil end
	return format(L["Nivel %d en %s a tu ritmo"], d.siguiente, N.Duracion(max(60, d.segundos), true))
end

-- «hasta el 45 % del nivel 34»: dónde termina tu descanso en tu barra.
function Sb.Descanso(d)
	d = d or Sb.Datos()
	if not d or d.maximo or (d.descanso or 0) <= 0 or (d.xpMax or 0) <= 0 then return nil end
	local hasta = (d.xpAhora or 0) + d.descanso
	local nivel = d.nivel
	if hasta >= d.xpMax then
		hasta = hasta - d.xpMax
		nivel = nivel + 1
	end
	local pct = min(99, floor(hasta / d.xpMax * 100 + 0.5))
	return format(L["Descansado: doble experiencia por cazar hasta el %d %% del nivel %d"], pct, nivel)
end

function Sb.Lineas()
	if N.Get("inicio", "barraXP") == false then return nil end
	local d = Sb.Datos()
	if not d or d.maximo then return nil end
	local out = {}
	local t = Sb.Texto(d)
	if t then out[#out + 1] = t end
	if d.listas > 0 and d.listasXP > 0 then
		out[#out + 1] = d.listas == 1 and format(L["Tu misión lista da unos %s XP"], miles(d.listasXP))
			or format(L["Tus %d misiones listas dan unos %s XP"], d.listas, miles(d.listasXP))
	end
	local r = Sb.Descanso(d)
	if r then out[#out + 1] = r end
	return #out > 0 and out or nil
end
