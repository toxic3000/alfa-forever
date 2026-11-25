-- Alfa - Rutas: «Aprender todo» en el entrenador (toxic3000 / La Jauría).
-- GPL-3.0. 1.4.0 (diario, 90)
--
-- Al subir de nivel se visita al entrenador y se aprende hechizo por hechizo,
-- clic en cada uno y clic en «Entrenar». Con la ventana del entrenador
-- abierta, un botón de Alfa bajo ella dice cuánto hay y cuánto cuesta:
-- «Aprender todo (4 · 1o 20p)». Un clic tuyo aprende todo lo disponible que
-- te alcanza (de lo más barato a lo más caro); lo que no te alcanza lo dice.
-- Nunca solo: siempre con tu clic. Nada en combate.
--
-- API clásica del entrenador (globales, sin restricciones; las usa el motor
-- en Core/Engine.lua): GetNumTrainerServices(), GetTrainerServiceInfo(i) ->
-- nombre, rango, tipo ("available" | "unavailable" | "used" | "header"),
-- GetTrainerServiceCost(i) -> cobre, BuyTrainerService(i); eventos
-- TRAINER_SHOW, TRAINER_UPDATE, TRAINER_CLOSED. Se compra del último al
-- primero, así la lista que se rehace tras cada compra no mueve los que faltan.
--
--   En.Lista() -> { { i, nombre, rango, costo } }, total, alcanza (cuántos te alcanzan), costo de esos
--   En.Aprender() -> aprendidos, costo, faltaron
--   En.Boton() -> el botón (para el banco)

local ADDON, M = ...
local A, L, K, N = M.A, M.L, M.K, M.N
local En = {}
M.Entrenador = En

A.RegisterDefaults(M.ID, { aprenderTodo = true })

local type, tonumber, pcall, ipairs, format, sort = type, tonumber, pcall, ipairs, string.format, table.sort

local function encendido() return A.Get(M.ID .. ".aprenderTodo") ~= false end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function num(v) return N.LeerNumero and N.LeerNumero(v) or tonumber(N.Leer(v)) end
local function texto(v)
	v = N.Leer(v)
	return type(v) == "string" and v or nil
end
local function dinero() return num(GetMoney and GetMoney()) or 0 end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d
end

function En.Lista()
	local out, total = {}, 0
	local n = num(llamar(rawget(_G, "GetNumTrainerServices"))) or 0
	for i = 1, n do
		local nombre, rango, tipo = llamar(rawget(_G, "GetTrainerServiceInfo"), i)
		if texto(tipo) == "available" then
			local costo = num(llamar(rawget(_G, "GetTrainerServiceCost"), i)) or 0
			out[#out + 1] = { i = i, nombre = texto(nombre) or "?", rango = texto(rango), costo = costo }
			total = total + costo
		end
	end
	-- Lo más barato primero: si no alcanza para todo, que alcance para más.
	local orden = {}
	for k, s in ipairs(out) do orden[k] = s end
	sort(orden, function(a, b) if a.costo ~= b.costo then return a.costo < b.costo end return a.i < b.i end)
	local queda, alcanza, costoAlcanza = dinero(), 0, 0
	for _, s in ipairs(orden) do
		if s.costo <= queda then
			queda = queda - s.costo
			alcanza = alcanza + 1
			costoAlcanza = costoAlcanza + s.costo
			s.alcanza = true
		end
	end
	return out, total, alcanza, costoAlcanza
end

local boton

local function marcoEntrenador()
	for _, n in ipairs({ "ClassTrainerFrame", "TrainerFrame" }) do
		local f = rawget(_G, n)
		if type(f) == "table" and f.IsShown then return f end
	end
	return nil
end

local function textoBoton(lista, total, alcanza, costoAlcanza)
	if #lista == 0 then return L["Nada nuevo para aprender"] end
	if alcanza < #lista then
		return format(L["Aprender %d de %d (%s)"], alcanza, #lista, N.Dinero(costoAlcanza or 0))
	end
	return format(L["Aprender todo (%d · %s)"], #lista, N.Dinero(total))
end

local function pintar()
	if not boton then return end
	local f = marcoEntrenador()
	if not (encendido() and f and f:IsShown()) or enCombate() then
		boton:Hide()
		return
	end
	local lista, total, alcanza, costoAlcanza = En.Lista()
	boton:SetTexto(textoBoton(lista, total, alcanza, costoAlcanza))
	if boton.SetActivo then boton:SetActivo(alcanza > 0) end
	boton.alfaCuantos = alcanza
	boton:ClearAllPoints()
	boton:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -4)
	boton:Show()
end

function En.Aprender()
	if enCombate() then
		M.Aviso(L["Aprender todo"], L["Se puede al salir de combate."], { icono = "ic-aviso", tono = "aviso" })
		return 0, 0, 0
	end
	local lista = En.Lista()
	local queda = dinero()
	-- Del último al primero: la lista se rehace tras cada compra.
	local hechos, costo, faltaron = 0, 0, 0
	local orden = {}
	for k, s in ipairs(lista) do orden[k] = s end
	sort(orden, function(a, b) if a.costo ~= b.costo then return a.costo < b.costo end return a.i < b.i end)
	local comprar = {}
	for _, s in ipairs(orden) do
		if s.costo <= queda then
			queda = queda - s.costo
			comprar[#comprar + 1] = s
		else
			faltaron = faltaron + 1
		end
	end
	sort(comprar, function(a, b) return a.i > b.i end)
	local buy = rawget(_G, "BuyTrainerService")
	for _, s in ipairs(comprar) do
		local ok = type(buy) == "function" and pcall(buy, s.i)
		if ok then
			hechos = hechos + 1
			costo = costo + s.costo
		end
	end
	if hechos > 0 then
		local t = format(L["Aprendiste %s por %s."], N.Plural(hechos, L["%d cosa nueva"], L["%d cosas nuevas"]), N.Dinero(costo))
		if faltaron > 0 then t = t .. " " .. format(L["Para %s más no te alcanzó el dinero."], N.Plural(faltaron, L["%d cosa"], L["%d cosas"])) end
		N.Imprimir(t)
	elseif faltaron > 0 then
		M.Aviso(L["Aprender todo"], L["No te alcanza el dinero para lo que enseña este entrenador."], { icono = "ic-aviso", tono = "aviso" })
	end
	N.Una("rutas.entrenador", 0.3, pintar)
	return hechos, costo, faltaron
end

local function armar()
	if boton or not (K and K.Boton) or enCombate() then return boton end
	boton = K.Boton(UIParent, L["Aprender todo"], function() En.Aprender() end, { tipo = "acento", tam = "chico", icono = "ic-mas" })
	boton:SetFrameStrata("HIGH")
	if K.ConInfo then
		K.ConInfo(boton, L["Aprender todo"], L["Aprende de un clic todo lo que este entrenador te puede enseñar ahora, empezando por lo más barato. Nunca gasta sin tu clic."])
	end
	boton:Hide()
	return boton
end
function En.Boton() return boton end

A.RegisterEvent("TRAINER_SHOW", function()
	if not encendido() then return end
	armar()
	-- La lista del juego llega un instante después.
	N.Una("rutas.entrenador", 0.2, pintar)
end)
A.RegisterEvent("TRAINER_UPDATE", function() if boton then N.Una("rutas.entrenador", 0.1, pintar) end end)
A.RegisterEvent("PLAYER_MONEY", function() if boton and boton:IsShown() then N.Una("rutas.entrenador", 0.1, pintar) end end)
A.RegisterEvent("TRAINER_CLOSED", function() if boton then boton:Hide() end end)
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() if boton then boton:Hide() end end)
