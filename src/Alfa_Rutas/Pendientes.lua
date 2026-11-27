-- Alfa - Rutas: «Tienes misiones aquí» al volver a una zona (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Vuelves a una zona (en grifo, en barco, a pie) y ya no te acuerdas de que
-- dejaste misiones a medias ahí. Al llegar, si tienes 2 o más sin terminar
-- en esa zona que tu guía no va a hacer, Alfa te lo dice una vez por zona en
-- la sesión: «Tienes 3 misiones sin terminar aquí: …», con «Llévame a la más
-- cercana» (IrMision.lua) y «Cerrarlas» (Cerrar mis misiones de la zona).
-- Las que tu guía sí lleva no cuentan (AlfaRuta.EsDeMiRuta). Nada dentro de
-- una instancia ni en combate; nada al entrar al juego (solo al cambiar de zona).
--
--   Pe.Lista() -> { qid... }   las de aquí que tu guía no lleva
--   Pe.Revisar() -> true si avisó
-- Ajuste: rutas.pendientesZona (de fábrica, sí).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local Pe = {}
M.Pendientes = Pe

A.RegisterDefaults(M.ID, { pendientesZona = true })

local type, ipairs, pcall = type, ipairs, pcall
local format, concat = string.format, table.concat

local MIN = 2

local dichas = {} -- zona -> true (en esta sesión)

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function secreto(v) return issecretvalue and issecretvalue(v) or false end

local function dentro()
	if type(IsInInstance) ~= "function" then return false end
	local ok, si = pcall(IsInInstance)
	return ok and si == true
end

local function zona()
	local fn = rawget(_G, "GetRealZoneText") or rawget(_G, "GetZoneText")
	if type(fn) ~= "function" then return nil end
	local ok, z = pcall(fn)
	if ok and type(z) == "string" and z ~= "" and not secreto(z) then return z end
	return nil
end

local function deMiRuta(qid)
	local R = rawget(_G, "AlfaRuta")
	if type(R) == "table" and type(R.EsDeMiRuta) == "function" then
		local ok, si = pcall(R.EsDeMiRuta, qid)
		return ok and si and true or false
	end
	return false
end

function Pe.Lista()
	local H = M.Hora
	if not (H and H.PendientesEnZona) then return {} end
	local todas = {}
	H.PendientesEnZona(todas)
	local out = {}
	for _, qid in ipairs(todas) do
		if not deMiRuta(qid) then out[#out + 1] = qid end
	end
	return out
end

function Pe.Revisar()
	if A.Get(M.ID .. ".pendientesZona") == false or enCombate() or dentro() then return false end
	local z = zona()
	if not z or dichas[z] then return false end
	local lista = Pe.Lista()
	if #lista < MIN then return false end
	dichas[z] = true
	local nombres = {}
	for i, qid in ipairs(lista) do
		if i > 3 then break end
		nombres[#nombres + 1] = M.Citar(M.TituloMision(qid))
	end
	local acciones = {}
	if M.IrMision then
		acciones[1] = { texto = L["Llévame a la más cercana"], alClic = function() M.IrMision.MasCerca(lista) end }
	end
	acciones[#acciones + 1] = { texto = L["Cerrarlas"], alClic = function() M.Cerrar.Ahora("zona") end }
	M.Aviso(format(L["Tienes %s aquí"], M.Plural(#lista, L["%d misión sin terminar"], L["%d misiones sin terminar"])),
		concat(nombres, ", ") .. (#lista > 3 and "…" or ""),
		{ icono = "ic-misiones", acciones = acciones, prioridad = 3, caduca = 180 })
	return true
end

-- Para el banco.
function Pe.Olvidar() dichas = {} end

-- Al entrar al juego o en un /reload no se avisa: solo al cambiar de zona.
local callarHasta = 0
local function ahora() return GetTime and GetTime() or 0 end
A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, login, recarga)
	if login or recarga then callarHasta = ahora() + 15 end
end)

A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
	if ahora() < callarHasta then return end
	if N.Una then N.Una("rutas.pendientes", 4, Pe.Revisar) else Pe.Revisar() end
end)
