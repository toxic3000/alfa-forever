-- Alfa - Inicio: lo de Alfa en el cuadro de las barras de experiencia y de
-- reputación del juego (toxic3000 / La Jauría). GPL-3.0. -- 1.3.7 (169, 177)
--
-- Al pasar el ratón por la barra de experiencia: «Nivel 34 en 1 h 20 min a
-- tu ritmo», lo que dan tus misiones listas y tu descanso (Subir.lua). Por
-- la de reputación: cuánto te falta para el rango que sigue (Reputacion.lua).
-- Solo se agregan líneas al cuadro (HookScript, nada seguro: también vale en
-- combate). Las barras son las que existan en el cliente: MainMenuExpBar y
-- ReputationWatchBar (las clásicas) o MainStatusTrackingBarContainer y
-- SecondaryStatusTrackingBarContainer (las nuevas, con sus barras dentro).
-- Ajustes inicio.barraXP e inicio.barraRep.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit

local type, pcall, ipairs, pairs = type, pcall, ipairs, pairs

local Bs = {}
M.Barras = Bs

-- ¿De qué es esta barra? "xp" | "rep" | nil
local function tipoDe(f)
	if type(f) ~= "table" then return nil end
	-- Un contenedor nuevo: la barra que muestra ahora.
	local bars = rawget(f, "bars")
	local i = rawget(f, "shownBarIndex")
	if type(bars) == "table" and i and bars[i] then return tipoDe(bars[i]) end
	local nombre = type(f.GetName) == "function" and f:GetName() or nil
	if type(nombre) == "string" then
		if nombre:find("Exp") or nombre:find("XP") then return "xp" end
		if nombre:find("Reputation") then return "rep" end
	end
	if rawget(f, "ExhaustionTick") or rawget(f, "ExhaustionLevelFillBar") then return "xp" end
	if rawget(f, "factionID") ~= nil or rawget(f, "ReputationBar") then return "rep" end
	return nil
end
Bs.TipoDe = tipoDe

function Bs.Lineas(tipo)
	if tipo == "xp" and M.Subir then return M.Subir.Lineas() end
	if tipo == "rep" and M.Reputacion then return M.Reputacion.Lineas() end
	return nil
end

local nuestro -- el marco al que Alfa le abrió el cuadro (para cerrarlo al salir)
local enganchados = setmetatable({}, { __mode = "k" })

-- 1.3.7: el cuadro del juego y el de Alfa ya no pelean. Si el juego arma (o
-- rearma) su cuadro sobre la barra, Alfa solo le agrega sus líneas al final,
-- una vez por cuadro (GameTooltip:Show enganchado); sin cuadro del juego,
-- Alfa abre el suyo.
local puestas = false -- ¿ya van las líneas de Alfa en el cuadro de ahora?
local function agregar(T, f)
	if puestas then return end
	local lineas = Bs.Lineas(tipoDe(f))
	if not lineas then return end
	puestas = true
	if (type(T.NumLines) ~= "function" or T:NumLines() > 0) and nuestro ~= f then T:AddLine(" ") end
	local r, g, b = 0.55, 0.88, 0.31
	if K and K.Color then
		local ok, cr, cg, cb = pcall(K.Color, "acento")
		if ok and cr then r, g, b = cr, cg, cb end
	end
	T:AddLine("Alfa", r, g, b)
	for _, l in ipairs(lineas) do T:AddLine(l, 1, 1, 1, true) end
	T:Show() -- (se acomoda al nuevo alto; el gancho ve «puestas» y no repite)
end
Bs.Agregar = agregar

local cuadroEnganchado = false
local function engancharCuadro(T)
	if cuadroEnganchado or type(T) ~= "table" then return end
	cuadroEnganchado = true
	if type(T.HookScript) == "function" then pcall(T.HookScript, T, "OnTooltipCleared", function() puestas = false end) end
	if hooksecurefunc then
		pcall(hooksecurefunc, T, "Show", function(self)
			local o = type(self.GetOwner) == "function" and self:GetOwner() or nil
			if o and enganchados[o] then agregar(self, o) end
		end)
	end
end

local function alEntrar(f)
	if not Bs.Lineas(tipoDe(f)) then return end
	local T = rawget(_G, "GameTooltip")
	if type(T) ~= "table" then return end
	engancharCuadro(T)
	local suyo = T:IsShown() and (type(T.IsOwned) ~= "function" or T:IsOwned(f) or T:GetOwner() == f)
	if suyo then
		agregar(T, f) -- el del juego ya está: solo las líneas de Alfa
		return
	end
	T:SetOwner(f, "ANCHOR_TOP")
	nuestro = f
	puestas = false
	agregar(T, f)
end

local function alSalir(f)
	if nuestro == f then
		nuestro = nil
		local T = rawget(_G, "GameTooltip")
		if T and T.GetOwner and T:GetOwner() == f then T:Hide() end
	end
end

local function enganchar(f)
	if type(f) ~= "table" or enganchados[f] or type(f.HookScript) ~= "function" then return end
	if type(f.HasScript) == "function" and not f:HasScript("OnEnter") then return end
	enganchados[f] = true
	-- 1.4.1: sin prenderles el ratón a las barras del juego (K.Enganchar): un
	-- contenedor que no lo tomaba se volvía pared sobre el mundo.
	K.Enganchar(f, "OnEnter", alEntrar)
	K.Enganchar(f, "OnLeave", alSalir)
end

local NOMBRES = { "MainMenuExpBar", "ReputationWatchBar", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }

function Bs.Enganchar()
	for _, n in ipairs(NOMBRES) do
		local f = rawget(_G, n)
		if type(f) == "table" then
			enganchar(f)
			-- Las barras de dentro de un contenedor (las que reciben el ratón).
			local bars = rawget(f, "bars")
			if type(bars) == "table" then for _, b in pairs(bars) do enganchar(b) end end
			local sb = rawget(f, "StatusBar")
			if type(sb) == "table" then enganchar(sb) end
		end
	end
end

A.OnLogin(function() N.Una("inicio.barras", 2, function() N.FueraDeCombate("inicio.barras", Bs.Enganchar) end) end)
