-- Alfa - Núcleo: la pantalla limpia (1.3.0). toxic3000 / La Jauría. GPL-3.0.
--
-- Una tecla (ALFA_PANTALLA_LIMPIA, Bindings.xml) deja a la vista solo lo
-- esencial: las ventanas de Alfa, su rastreador y Lya. Lo del juego que el
-- jugador elige (chat, minimapa, auras, menú y bolsas, misiones del juego,
-- barras de acción, retratos) se vuelve transparente, y otra pulsación lo
-- devuelve tal como estaba.
--   N.PantallaLimpia.Alternar([on])  -> bool (si quedó limpia)
--   N.PantallaLimpia.Activa() -> bool
--   N.PantallaLimpia.GRUPOS          los grupos que se pueden esconder
-- Solo transparencia (SetAlpha): nada se oculta ni se mueve. Un marco
-- protegido (barras, retratos) nunca se toca en combate: espera a que acabe
-- (N.FueraDeCombate). Los ajustes: nucleo.limpia<Grupo> (true = se esconde).

local _, N = ...
local A = N.A
local L = N.Kit and N.Kit.L or N.Textos(N.EN)

local type, ipairs, pairs, pcall, rawget = type, ipairs, pairs, pcall, rawget

local Pl = {}
N.PantallaLimpia = Pl

local function chats()
	local t = { "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton",
		"ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "FriendsMicroButton" }
	local n = tonumber(rawget(_G, "NUM_CHAT_WINDOWS")) or 10
	for i = 1, n do
		t[#t + 1] = "ChatFrame" .. i
		t[#t + 1] = "ChatFrame" .. i .. "Tab"
		t[#t + 1] = "ChatFrame" .. i .. "ButtonFrame"
		t[#t + 1] = "ChatFrame" .. i .. "EditBox"
	end
	return t
end

-- id, nombre (clave de L), si se esconde de fábrica, y sus marcos del juego.
Pl.GRUPOS = {
	{ id = "Chat", nombre = "El chat", fabrica = true, marcos = chats() },
	{ id = "Minimapa", nombre = "El minimapa", fabrica = true, marcos = { "MinimapCluster", "Minimap", "MinimapBackdrop" } },
	{ id = "Auras", nombre = "Tus beneficios y perjuicios", fabrica = true,
		marcos = { "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame" } },
	{ id = "Menu", nombre = "El menú y las bolsas del juego", fabrica = true,
		marcos = { "MicroButtonAndBagsBar", "MicroMenuContainer", "MicroMenu", "BagsBar", "MainMenuBarBackpackButton" } },
	{ id = "Misiones", nombre = "Las misiones del juego", fabrica = true,
		marcos = { "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" } },
	{ id = "Barras", nombre = "Las barras de acción", fabrica = false,
		marcos = { "MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
			"StanceBar", "StanceBarFrame", "PetActionBar", "PetActionBarFrame", "MainMenuExpBar", "ReputationWatchBar", "StatusTrackingBarManager" } },
	{ id = "Retratos", nombre = "Tu retrato y el de tu objetivo", fabrica = false,
		marcos = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame" } },
}

do
	local d = {}
	for _, g in ipairs(Pl.GRUPOS) do d["limpia" .. g.id] = g.fabrica end
	if A and A.RegisterDefaults then A.RegisterDefaults("nucleo", d) end
end

local activa = false
local guardados = {} -- marco -> su transparencia de antes

function Pl.Activa() return activa end
function Pl.Esconde(id) return A.Get("nucleo.limpia" .. id) and true or false end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function protegido(m)
	if not m.IsProtected then return false end
	local ok, p = pcall(m.IsProtected, m)
	return ok and p and true or false
end

-- Pone o devuelve un marco; false si tuvo que esperar (protegido en combate).
local function tocar(m, limpiar)
	if protegido(m) and enCombate() then return false end
	if limpiar then
		if guardados[m] == nil then
			local ok, a = pcall(m.GetAlpha, m)
			guardados[m] = (ok and type(a) == "number") and a or 1
		end
		pcall(m.SetAlpha, m, 0)
	elseif guardados[m] ~= nil then
		pcall(m.SetAlpha, m, guardados[m])
		guardados[m] = nil
	end
	return true
end

local aplicar
-- Aplica el estado de ahora a cada grupo; lo protegido en combate, al salir.
aplicar = function()
	local espera = false
	for _, g in ipairs(Pl.GRUPOS) do
		local limpiar = activa and Pl.Esconde(g.id)
		for _, nombre in ipairs(g.marcos) do
			local m = rawget(_G, nombre)
			if type(m) == "table" and m.SetAlpha then
				if not tocar(m, limpiar) then espera = true end
			end
		end
	end
	-- Un marco que dejó de estar en un grupo elegido vuelve como estaba.
	if not activa then
		for m, a in pairs(guardados) do
			if not (protegido(m) and enCombate()) then
				pcall(m.SetAlpha, m, a)
				guardados[m] = nil
			else
				espera = true
			end
		end
	end
	if espera and N.FueraDeCombate then N.FueraDeCombate("pantallaLimpia", aplicar) end
	return not espera
end
Pl.Aplicar = aplicar

-- Cuántos marcos quedaron transparentes (para las pruebas y el aviso).
function Pl.Escondidos()
	local n = 0
	for _ in pairs(guardados) do n = n + 1 end
	return n
end

function Pl.Alternar(on)
	if on == nil then on = not activa end
	activa = on and true or false
	local completo = aplicar()
	local K = N.Kit
	if K and K.Aviso then
		if activa then
			K.Aviso({ titulo = L["Pantalla limpia"], icono = "ic-lobo", duracion = 4, detalle = true,
				texto = completo and L["Solo lo esencial a la vista. Pulsa tu tecla otra vez para ver todo."]
					or L["Solo lo esencial a la vista. Las barras y retratos se esconden al terminar el combate."] })
		else
			K.Aviso({ titulo = L["Todo a la vista otra vez"], icono = "ic-exito", duracion = 3, detalle = true,
				texto = completo and nil or L["Las barras y retratos vuelven al terminar el combate."] })
		end
	end
	return activa
end

BINDING_NAME_ALFA_PANTALLA_LIMPIA = L["Pantalla limpia: solo lo esencial"]

if A then
	-- Un ajuste que cambia con la pantalla limpia puesta se aplica al momento.
	if A.On then
		A.On("SETTING_CHANGED", function(ruta)
			if activa and type(ruta) == "string" and ruta:find("^nucleo%.limpia") then aplicar() end
		end)
	end
	-- Al cambiar de zona el juego puede volver a mostrar algo: se aplica otra vez.
	if A.RegisterEvent then
		A.RegisterEvent("PLAYER_ENTERING_WORLD", function() if activa then aplicar() end end)
	end
	if A.RegisterCommand then
		A.RegisterCommand("limpia", function() Pl.Alternar() end, L["deja a la vista solo lo esencial (otra vez: todo)"])
	end
end
