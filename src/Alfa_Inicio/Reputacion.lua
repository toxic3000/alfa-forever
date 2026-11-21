-- Alfa - Inicio: tu reputación al día (toxic3000 / La Jauría). GPL-3.0.
-- 1.3.7 (177)
--
-- La facción que sigues (la de la barra de reputación del juego): cuánto te
-- falta para el rango que sigue, unas cuántas misiones son eso y qué te da
-- ese rango. En Hoy y en el cuadro de la barra de reputación (Barras.lua).
-- Las misiones salen de lo que de verdad te dan: cada vez que entregas una y
-- tu reputación con esa facción sube, Alfa lo anota (un promedio que se
-- mueve, por personaje: N.DatosPersonaje("inicio").rep[nombre]); sin
-- medidas, unos 250 por misión (lo de casi siempre).
--
--   Rep.Actual() -> { nombre, rango, siguiente (nombre del rango), falta,
--       valor, tope, misiones | nil, desbloquea | nil } | nil
--   Rep.Texto(r) -> «Te faltan 1,200 para Honorable, ~5 misiones» | nil
--   Rep.Lineas() -> { texto, ... } para el cuadro de la barra

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local num, miles = M.num, M.miles

local type, pcall, format, floor, max, ceil = type, pcall, string.format, math.floor, math.max, math.ceil

local Rep = {}
M.Reputacion = Rep

local POR_MISION = 250 -- sin medidas
local PESO = 0.25

-- Los rangos del juego (1 Odiado ... 8 Exaltado), con su nombre traducido.
local function nombreRango(i)
	local s = rawget(_G, "FACTION_STANDING_LABEL" .. tostring(i))
	if type(s) == "string" and s ~= "" then return s end
	local NOMBRES = { L["Odiado"], L["Hostil"], L["Adverso"], L["Neutral"], L["Amistoso"], L["Honorable"], L["Reverenciado"], L["Exaltado"] }
	return NOMBRES[i]
end
Rep.NombreRango = nombreRango

-- Lo que te da cada rango con sus vendedores (los descuentos del juego).
local DESBLOQUEA = {
	[5] = L["un 5 % menos en sus vendedores"],
	[6] = L["un 10 % menos en sus vendedores y sus objetos de Honorable"],
	[7] = L["un 15 % menos en sus vendedores y sus objetos de Reverenciado"],
	[8] = L["un 20 % menos en sus vendedores y lo mejor que ofrecen"],
}

local function db()
	local d = N.DatosPersonaje("inicio")
	if type(d.rep) ~= "table" then d.rep = {} end
	return d.rep
end

-- La facción que sigues: nombre, rango (1-8), mínimo, máximo y valor.
local function vigilada()
	local CR = rawget(_G, "C_Reputation")
	if type(CR) == "table" and type(CR.GetWatchedFactionData) == "function" then
		local ok, d = pcall(CR.GetWatchedFactionData)
		if ok and type(d) == "table" and d.name then
			return d.name, num(d.reaction), num(d.currentReactionThreshold), num(d.nextReactionThreshold), num(d.currentStanding)
		end
	end
	local f = rawget(_G, "GetWatchedFactionInfo")
	if type(f) == "function" then
		local ok, nombre, rango, minimo, maximo, valor = pcall(f)
		if ok and type(nombre) == "string" and nombre ~= "" then return nombre, num(rango), num(minimo), num(maximo), num(valor) end
	end
	return nil
end
Rep.Vigilada = vigilada

function Rep.PorMision(nombre)
	local r = nombre and db()[nombre]
	return (type(r) == "table" and num(r.prom) and r.prom > 0) and r.prom or POR_MISION, type(r) == "table" and (num(r.n) or 0) or 0
end

function Rep.Actual()
	local nombre, rango, minimo, maximo, valor = vigilada()
	if not (nombre and rango and minimo and maximo and valor) then return nil end
	if issecretvalue and (issecretvalue(nombre) or issecretvalue(valor)) then return nil end
	local r = { nombre = nombre, rango = rango, rangoNombre = nombreRango(rango), valor = valor - minimo, tope = maximo - minimo }
	if rango >= 8 then
		r.maximo = true
		return r
	end
	r.falta = max(0, maximo - valor)
	r.siguiente = nombreRango(rango + 1)
	local por = Rep.PorMision(nombre)
	if r.falta > 0 and por > 0 then r.misiones = ceil(r.falta / por) end
	r.desbloquea = DESBLOQUEA[rango + 1]
	return r
end

function Rep.Texto(r)
	r = r or Rep.Actual()
	if not r then return nil end
	if r.maximo then return format(L["%s: ya eres Exaltado"], r.nombre) end
	if not r.siguiente then return nil end
	local t = format(L["Te faltan %s para %s"], miles(r.falta), r.siguiente)
	if r.misiones then t = t .. ", " .. N.Plural(r.misiones, L["~%d misión"], L["~%d misiones"]) end
	return t
end

function Rep.Lineas()
	if N.Get("inicio", "barraRep") == false then return nil end
	local r = Rep.Actual()
	if not r then return nil end
	local out = { Rep.Texto(r) }
	if r.desbloquea and r.siguiente then out[#out + 1] = format(L["%s te da %s."], r.siguiente, r.desbloquea) end
	return out
end

---------------------------------------------------------------------------
-- Cuánto da una misión: lo que sube la facción que sigues justo al entregar
---------------------------------------------------------------------------

local antes -- { nombre, valor }
local entregada = 0

local function leer()
	local nombre, _, _, _, valor = vigilada()
	if nombre and valor then antes = { nombre = nombre, valor = valor } else antes = nil end
end

function Rep.Anotar(nombre, delta)
	delta = num(delta)
	if not (nombre and delta and delta > 0 and delta < 5000) then return end
	local d = db()
	local r = type(d[nombre]) == "table" and d[nombre] or { prom = 0, n = 0 }
	r.n = (num(r.n) or 0) + 1
	local peso = max(1 / r.n, PESO)
	r.prom = (num(r.prom) or 0) + (delta - (num(r.prom) or 0)) * peso
	d[nombre] = r
end

A.RegisterEvent("QUEST_TURNED_IN", function() entregada = GetTime and GetTime() or 0 end)
A.RegisterEvent("UPDATE_FACTION", function()
	local a = antes
	leer()
	local ahora = GetTime and GetTime() or 0
	if a and antes and a.nombre == antes.nombre and ahora - entregada < 3 then
		Rep.Anotar(antes.nombre, antes.valor - a.valor)
		entregada = 0
	end
end)
A.OnLogin(function() leer() end)
