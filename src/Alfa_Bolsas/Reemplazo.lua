-- Alfa - Bolsas: la ventana de Alfa en lugar de las bolsas y el banco de
-- Blizzard. GPL-3.0.
--
-- Sin reemplazar funciones de Blizzard (eso contamina): todo es
-- hooksecurefunc, que corre después de la función original sin tocarla.
--
--   * Las teclas y botones de las bolsas (B, Mayús+B, la tecla de cada bolsa,
--     los botones de la barra) llaman ToggleAllBags / ToggleBackpack /
--     ToggleBag; los comerciantes, el correo y las ventanas que abren las
--     bolsas, OpenAllBags(marco) / CloseAllBags(marco); las alertas de
--     botín, OpenBag. Cada una se sigue después de que corre: una pulsación
--     puede llamar varias anidadas (ToggleAllBags llama OpenBackpack, que llama
--     ToggleBackpack...), y la de afuera es la última en llegar, así que dentro
--     de un mismo cuadro manda la última, aplicada al estado del principio, y
--     la ventana cambia una sola vez, al cuadro siguiente.
--   * CloseAllBags(marco) solo cierra si ese marco las abrió (como Blizzard).
--   * Las bolsas de Blizzard siguen abriéndose y cerrándose por dentro, pero
--     dentro de un marco oculto (SetParent): no se ven ni se
--     tocan. Se vuelven a ocultar si Blizzard las cambia de padre
--     (ContainerFrame_SetFullScreenFrame).
--   * El banco: BankFrame va al mismo marco oculto antes de abrirlo (si se
--     ocultara abierto, su OnHide cerraría la visita). La primera vez que un
--     personaje visita el banco con Alfa se muestra el de Blizzard (así compra
--     la primera pestaña, que es gratis); desde la siguiente, el de Alfa. Al
--     abrir el banco se abren también tus bolsas.
--   * No se reemplaza nada con la interfaz para mando (sus menús se
--     contaminan) ni si hay otro addon de bolsas activo (Compat.lua).

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D, V = M.Datos, M.Ventana

local type, pairs, ipairs = type, pairs, ipairs

local R = {}
M.Reemplazo = R

local OTROS = M.OTROS and M.OTROS.bolsas or {}

local conflicto -- carpeta del otro addon de bolsas, o false
function R.Conflicto()
	if conflicto == nil then
		conflicto = false
		local C = A.Compat
		if C and C.AddOnPresent then
			for _, n in ipairs(OTROS) do
				local ok, si = pcall(C.AddOnPresent, n)
				if ok and si == true then
					conflicto = n
					break
				end
			end
		end
	end
	return conflicto or nil
end

function R.Mando()
	return A.GamepadUI and A.GamepadUI() == true or false
end

function R.Activo()
	return M.Get("reemplazar") and not R.Mando() and not R.Conflicto() and true or false
end

function R.BancoActivo()
	return R.Activo() and M.Get("banco") and true or false
end

---------------------------------------------------------------------------
-- Las bolsas de Blizzard, dentro de un marco oculto
---------------------------------------------------------------------------

local oculto = CreateFrame("Frame")
oculto:Hide()
local antes = setmetatable({}, { __mode = "k" }) -- marco -> { padre, estrato, nivel }

local function marcosBolsas()
	local t = {}
	local n = tonumber(NUM_CONTAINER_FRAMES) or 13
	for i = 1, math.max(n, 13) do
		local f = _G["ContainerFrame" .. i]
		if type(f) == "table" and f.SetParent then t[#t + 1] = f end
	end
	local c = _G.ContainerFrameCombinedBags
	if type(c) == "table" and c.SetParent then t[#t + 1] = c end
	return t
end

local function esconder(f)
	if not (f and f.GetParent) or f:GetParent() == oculto then return end
	antes[f] = antes[f] or { f:GetParent(), f:GetFrameStrata(), f:GetFrameLevel() }
	f:SetParent(oculto)
end

local function devolver(f)
	local a = antes[f]
	if not (a and f.GetParent) or f:GetParent() ~= oculto then return end
	-- Un marco que Blizzard cree abierto se cierra antes, con su padre oculto,
	-- para que al volver no se muestre de golpe.
	if f:IsShown() then f:Hide() end
	f:SetParent(a[1] or UIParent)
	if a[2] then f:SetFrameStrata(a[2]) end
	if a[3] then f:SetFrameLevel(a[3]) end
end

local function algunaVisible(lista)
	for _, f in ipairs(lista) do
		if f:IsVisible() and f:GetParent() ~= oculto then return true end
	end
	return false
end

local pendiente = false
local bancoTomado = false

-- El banco se toma si ya lo visitó con Alfa (o el juego dice que tiene
-- pestañas compradas) y no está abierto ahora.
local function bancoListo()
	local r = D.Actual()
	if r and r.bancoVisto then return true end
	local B = C_Bank
	local tipo = Enum and Enum.BankType and Enum.BankType.Character
	if B and B.FetchNumPurchasedBankTabs and tipo then
		local n = M.Num(M.Llamar(B.FetchNumPurchasedBankTabs, tipo))
		if n and n > 0 then return true end
	end
	return false
end

function R.Aplicar()
	if InCombatLockdown and InCombatLockdown() then
		N.FueraDeCombate(R.Aplicar)
		return
	end
	local lista = marcosBolsas()
	if R.Activo() then
		-- Las de Blizzard abiertas a la vista: se espera a que se cierren.
		if algunaVisible(lista) then
			if not pendiente then
				pendiente = true
				M.Luego(1, function()
					pendiente = false
					R.Aplicar()
				end)
			end
		else
			for _, f in ipairs(lista) do esconder(f) end
		end
	else
		for _, f in ipairs(lista) do devolver(f) end
	end
	local bank = _G.BankFrame
	if type(bank) == "table" and bank.SetParent and not D.BancoAbierto() then
		if R.BancoActivo() and bancoListo() then
			if not bank:IsVisible() then
				esconder(bank)
				bancoTomado = true
			end
		elseif bancoTomado then
			devolver(bank)
			bancoTomado = false
		end
	end
end

function R.BancoTomado() return bancoTomado end

---------------------------------------------------------------------------
-- Seguir a las funciones de las bolsas
---------------------------------------------------------------------------

local QUE = {
	ToggleAllBags = "alternar", ToggleBackpack = "alternar", ToggleBag = "alternar",
	OpenAllBags = "abrir", OpenAllBagsMatchingContext = "abrir", OpenBackpack = "abrir", OpenBag = "abrir",
	CloseAllBags = "cerrar", CloseBackpack = "cerrar",
}

local rafaga, inicio, deseado, programado
local abiertaPor -- nombre del marco que abrió las bolsas (OpenAllBags(marco)), o nil

local function aplicarDeseado()
	programado = false
	rafaga = nil -- lo que llegue después es otra pulsación
	if deseado == nil then return end
	local si = deseado
	deseado = nil
	if si ~= V.BolsasVisibles() then V.MostrarBolsas(si) end
end

local function nombreDe(marco)
	if type(marco) == "table" and marco.GetName then
		local ok, n = pcall(marco.GetName, marco)
		if ok and type(n) == "string" then return n end
	end
	return nil
end

local function seguir(que, cual, marco)
	if not R.Activo() then return end
	local ahora = GetTime and GetTime() or 0
	if rafaga ~= ahora then
		rafaga = ahora
		inicio = V.BolsasVisibles()
		if deseado ~= nil then inicio = deseado end
	end
	if que == "alternar" then
		deseado = not inicio
		abiertaPor = nil
	elseif que == "abrir" then
		if (cual == "OpenAllBags" or cual == "OpenAllBagsMatchingContext") and not inicio then abiertaPor = nombreDe(marco) end
		deseado = true
	else
		if cual == "CloseAllBags" and marco ~= nil then
			local n = nombreDe(marco)
			if n ~= abiertaPor then return end
		end
		abiertaPor = nil
		deseado = false
	end
	if not programado then
		programado = true
		M.Luego(0, aplicarDeseado)
	end
end

for cual, que in pairs(QUE) do
	if type(_G[cual]) == "function" and hooksecurefunc then
		hooksecurefunc(cual, function(marco) seguir(que, cual, marco) end)
	end
end

-- Blizzard las devuelve a la pantalla completa: otra vez al marco oculto.
for _, cual in ipairs({ "ContainerFrame_SetFullScreenFrame", "ContainerFrame_ClearFullScreenFrame" }) do
	if type(_G[cual]) == "function" and hooksecurefunc then
		hooksecurefunc(cual, function()
			if R.Activo() then M.Luego(0, R.Aplicar) end
		end)
	end
end

-- La ventana se cerró por su cuenta (X, Escape): nadie la tiene abierta.
M.Escuchar("VENTANA_CERRADA", function(tipo)
	if tipo == "bolsas" then abiertaPor = nil end
end)

---------------------------------------------------------------------------
-- El banco
---------------------------------------------------------------------------

local ABIERTA_POR_BANCO = "AlfaBolsasBanco"

A.RegisterEvent("BANKFRAME_OPENED", function()
	local bank = _G.BankFrame
	if not (bancoTomado and type(bank) == "table" and bank.GetParent and bank:GetParent() == oculto) then return end
	if not R.BancoActivo() then return end
	V.MostrarBanco(nil)
	if not V.BolsasVisibles() then
		abiertaPor = ABIERTA_POR_BANCO
		V.MostrarBolsas(true)
	end
end)

A.RegisterEvent("BANKFRAME_CLOSED", function()
	if abiertaPor == ABIERTA_POR_BANCO then
		abiertaPor = nil
		V.MostrarBolsas(false)
	end
	-- Después de la primera visita, el banco de Alfa toma el lugar del de Blizzard.
	M.Luego(0.5, R.Aplicar)
end)

A.OnLogin(function() M.Luego(0, R.Aplicar) end)

A.On("SETTING_CHANGED", function(ruta)
	if ruta == M.ID .. ".reemplazar" or ruta == M.ID .. ".banco" or ruta == M.ID or ruta == "" then
		if not R.Activo() then V.MostrarBolsas(false) end
		R.Aplicar()
	end
end)
