-- Alfa - Mundo: el control de capas en el mapa del juego y la tecla del
-- mapa (Toxic / La Jauría). GPL-3.0.
--
-- En el mapa de Blizzard (WorldMapFrame) Alfa solo agrega, nunca reemplaza:
--   * en su menú de rastreo (la lupa), "Alfa: capas del mapa", por el punto
--     de extensión oficial Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING"), como
--     hace el motor con los servicios (Maps/Services.lua);
--   * dos botones pequeños junto a esa lupa (mundo.botonMapa): las capas y
--     el mapa de Alfa. Son marcos de Alfa hijos del mapa, fuera de su lienzo,
--     que solo leen el mapa (GetMapID, la posición de la lupa).
-- Con la interfaz de mando (gamepad) no se agrega nada al mapa del juego:
-- el motor explica por qué en Core/Init.lua (A.GamepadUI).
--
-- La tecla del mapa (mundo.teclaM): sus teclas abren el mapa de Alfa con
-- SetOverrideBinding, fuera de combate; apagarlo las devuelve al juego.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local W, T = A.Widgets, A.Theme
local Capas, Panel, V, Mc = M.Capas, M.Panel, M.Ventana, M.Marcas

local type, ipairs, pcall, tostring = type, ipairs, pcall, tostring

local MJ = {}
M.MapaJuego = MJ

local function mando() return type(A.GamepadUI) == "function" and A.GamepadUI() end
local function oculto() return type(A.Hidden) == "function" and A.Hidden() end

local function mapaDelJuego()
	local mapa = WorldMapFrame
	if mapa and type(mapa.GetMapID) == "function" then
		local ok, id = pcall(mapa.GetMapID, mapa)
		if ok and type(id) == "number" then return id end
	end
	return nil
end

---------------------------------------------------------------------------
-- El menú de rastreo del mapa del juego
---------------------------------------------------------------------------

local function refrescar() return MenuResponse and MenuResponse.Refresh end

local function menu(_, raiz)
	if oculto() or mando() or A.Get("mundo.menuMapa") == false then return end
	if type(raiz) ~= "table" or type(raiz.CreateButton) ~= "function" then return end
	local sub = raiz:CreateButton(L["Alfa: capas del mapa"])
	sub:CreateButton(L["Abrir el mapa de Alfa"], function() V.Abrir(mapaDelJuego()) end)
	sub:CreateCheckbox(L["Modo limpio"], Capas.Limpio, function()
		Capas.AlternarLimpio()
		return refrescar()
	end)
	for _, g in ipairs(Capas.Grupos()) do
		sub:CreateDivider()
		if type(sub.CreateTitle) == "function" then sub:CreateTitle(g.nombre) end
		for _, e in ipairs(g.capas) do
			local cb = sub:CreateCheckbox(e.nombre, function() return Capas.Valor(e) end, function()
				Capas.Alternar(e)
				return refrescar()
			end)
			local libre = Capas.Disponible(e)
			if cb and type(cb.SetEnabled) == "function" then cb:SetEnabled(libre) end
		end
	end
end

---------------------------------------------------------------------------
-- Los botones junto a la lupa del mapa del juego
---------------------------------------------------------------------------

local barra

local function colocarBarra()
	local mapa = WorldMapFrame
	if not (barra and mapa) then return end
	barra:ClearAllPoints()
	local lupa = mapa.WorldMapTrackingOptionsButton
	local host = mapa.ScrollContainer or mapa
	if lupa and lupa.GetPoint then
		-- Lupa arriba a la derecha (diseño principal): los botones a su izquierda;
		-- lupa junto a la barra de navegación: a su derecha.
		local punto = lupa:GetPoint(1)
		if punto == "TOPRIGHT" or punto == "RIGHT" then
			barra:SetPoint("RIGHT", lupa, "LEFT", -2, 0)
		else
			barra:SetPoint("LEFT", lupa, "RIGHT", 4, 0)
		end
		barra:SetFrameLevel((lupa:GetFrameLevel() or 1) + 2)
	else
		barra:SetPoint("TOPRIGHT", host, "TOPRIGHT", -8, -8)
		barra:SetFrameLevel((host:GetFrameLevel() or 1) + 30)
	end
end

local function mostrarBarra()
	if not barra then return end
	local on = A.Get("mundo.botonMapa") ~= false and not oculto() and not mando()
	barra:SetShown(on)
	if on then W.SetIconState(barra.Limpio, Capas.Limpio()) end
end

local function crearBarra()
	if barra or mando() or not WorldMapFrame then return end
	local crear = A.CreateFrameUnder or function(k, n, p) return CreateFrame(k, n, p) end
	barra = crear("Frame", "AlfaMundoBotonesMapa", WorldMapFrame)
	barra:SetSize(3 * 28 + 4, 28)
	local fondo = barra:CreateTexture(nil, "BACKGROUND")
	fondo:SetAllPoints(barra)
	fondo:SetTexture(T.Media("white"))
	W.Color(fondo, "bg", 0.85)
	barra.Capas = W.IconButton(barra, "layers", 28, L["Capas de Alfa: elige qué se ve en el mapa"], function(self)
		Panel.Alternar(self, { punto = "TOPRIGHT", relativo = "BOTTOMRIGHT", x = 0, y = -4 })
	end, 15)
	barra.Capas:SetPoint("LEFT", barra, "LEFT", 2, 0)
	barra.Limpio = W.IconButton(barra, "compact", 28, L["Modo limpio: solo tú, tu grupo y la guía"], function()
		Capas.AlternarLimpio()
	end, 15)
	barra.Limpio:SetPoint("LEFT", barra.Capas, "RIGHT", 0, 0)
	barra.Abrir = W.IconButton(barra, "icon-explore", 28, L["Abrir el mapa de Alfa (continuo, con zoom)"], function()
		V.Abrir(mapaDelJuego())
	end, 15)
	barra.Abrir:SetPoint("LEFT", barra.Limpio, "RIGHT", 0, 0)
	colocarBarra()
	mostrarBarra()
	-- La lupa se recoloca al abrir el mapa o cambiar su tamaño: los botones la
	-- siguen. La vista del motor (Nav/MapCanvas.lua) lo avisa solo leyendo.
	local MC = A.MapCanvas
	if MC and type(MC.Watch) == "function" then
		MC.Watch(WorldMapFrame, function(_, que)
			if que == "show" or que == "size" then
				colocarBarra()
				mostrarBarra()
			end
		end)
	end
end
MJ.CrearBarra = crearBarra

---------------------------------------------------------------------------
-- La tecla del mapa
---------------------------------------------------------------------------

local dueno
local aplicadas = ""

local function aplicarTecla()
	if not (SetOverrideBinding and ClearOverrideBindings and GetBindingKey) then return end
	dueno = dueno or CreateFrame("Frame", "AlfaMundoTeclas", UIParent)
	local quiero = A.Get("mundo.teclaM") == true and not oculto() and not mando()
	local teclas = quiero and { GetBindingKey("TOGGLEWORLDMAP") } or {}
	local firma = table.concat(teclas, ",")
	if firma == aplicadas then return end
	N.FueraDeCombate(function()
		ClearOverrideBindings(dueno)
		for _, k in ipairs(teclas) do
			if type(k) == "string" and k ~= "" then SetOverrideBinding(dueno, true, k, "ALFA_MUNDO_MAPA") end
		end
		aplicadas = firma
	end)
end
MJ.AplicarTecla = aplicarTecla

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

local function alEntrar()
	if not mando() and Menu and type(Menu.ModifyMenu) == "function" then
		Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", menu)
	end
	crearBarra()
	aplicarTecla()
end

if type(A.OnLogin) == "function" then A.OnLogin(alEntrar) end

A.RegisterEvent("ADDON_LOADED", function(_, nombre)
	if nombre == "Blizzard_WorldMap" and type(A.IsLoggedIn) == "function" and A.IsLoggedIn() then crearBarra() end
end)

A.RegisterEvent("UPDATE_BINDINGS", function() aplicarTecla() end)

A.RegisterEvent("MAP_EXPLORATION_UPDATED", function() V.RehacerArte() end)
A.RegisterEvent("PLAYER_LEVEL_UP", function() Mc.Reestilar() end)

A.On("ALFA_HIDDEN", function()
	mostrarBarra()
	aplicarTecla()
end)

A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" then return end
	if path == "" or path == "mundo" or path == "maps" or path == "maps.reveal" then V.RehacerArte() end
	if path == "" or path == "mundo" or path == "mundo.detalle" then V.Detalle() end
	if path == "" or path == "mundo" or path == "mundo.teclaM" then aplicarTecla() end
	if path == "" or path == "nav" or path == "nav.mapIcons" or path == "maps.zoneLevels" or path == "mundo.nombres" then Mc.Reestilar() end
	mostrarBarra()
end)

if T and type(T.OnChanged) == "function" then T.OnChanged(function() Mc.Reestilar() end) end
