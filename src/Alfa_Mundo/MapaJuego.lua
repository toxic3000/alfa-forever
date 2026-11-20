-- Alfa - Mundo: el control de capas en el mapa del juego y la tecla del
-- mapa (toxic3000 / La Jauría). GPL-3.0.
--
-- En el mapa de Blizzard (WorldMapFrame) Alfa solo agrega, nunca reemplaza:
--   * en su menú de rastreo (la lupa), "Alfa: capas del mapa", por el punto
--     de extensión oficial Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING"), como
--     hace el motor con los servicios (Maps/Services.lua);
--   * junto a esa lupa (mundo.botonMapa): las capas, el modo limpio y
--     "Mapa de Alfa" para cambiar al de Alfa en la misma zona. Son marcos de
--     Alfa hijos del mapa, fuera de su lienzo, que solo leen el mapa
--     (GetMapID, la posición de la lupa);
--   * Mayús+clic derecho en el mapa pone un marcador ahí (el clic derecho
--     solo sigue alejando el mapa, como siempre). Es un manejador de clics
--     del lienzo (AddCanvasClickHandler), igual que el que ya pone el motor
--     para Mayús+clic (Nav/Journey.lua): solo toma ese clic y devuelve
--     false para todos los demás.
-- Con la interfaz de mando (gamepad) no se agrega nada al mapa del juego:
-- el motor explica por qué en Core/Init.lua (A.GamepadUI) y
-- Nav/MapCanvas.lua.
--
-- La tecla del mapa (mundo.teclaM): sus teclas abren el mapa de Alfa con
-- SetOverrideBinding, fuera de combate; apagarlo las devuelve al juego.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local K = N.Kit
local T = A.Theme
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
	local sub = raiz:CreateButton(L["Capas de Alfa"])
	sub:CreateButton(L["Mapa de Alfa"], function() V.Abrir(mapaDelJuego()) end)
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
MJ.Menu = menu -- (1.3.2: para el banco)

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
	if on then barra.Limpio:SetMarcado(Capas.Limpio()) end
end

local function crearBarra()
	if barra or mando() or not WorldMapFrame then return end
	local crear = A.CreateFrameUnder or function(k, n, p) return CreateFrame(k, n, p) end
	barra = crear("Frame", "AlfaMundoBotonesMapa", WorldMapFrame)
	barra.caja = K.Caja(barra, { fondo = "fondo", borde = "linea", corte = K.CORTE.chico })
	barra.Capas = K.BotonIcono(barra, "ic-comunidad", function(self)
		Panel.Alternar(self, { punto = "TOPRIGHT", relativo = "BOTTOMRIGHT", x = 0, y = -4, mapa = mapaDelJuego() })
	end, { tam = 26, icono = 15, ayuda = L["Capas de Alfa: elige qué se ve en el mapa"] })
	barra.Capas:SetPoint("LEFT", barra, "LEFT", 2, 0)
	barra.Limpio = K.BotonIcono(barra, "ic-descubrir", function() Capas.AlternarLimpio() end,
		{ tam = 26, icono = 15, ayuda = L["Modo limpio: solo tú, tu grupo, tus marcadores y la guía"] })
	barra.Limpio:SetPoint("LEFT", barra.Capas, "RIGHT", 0, 0)
	barra.Abrir = K.Boton(barra, L["Mapa de Alfa"], function() V.Abrir(mapaDelJuego()) end,
		{ tipo = "acento", tam = "chico", icono = "ic-mundo",
		  ayuda = L["Cambia al mapa de Alfa en esta zona: todo el mundo en un solo mapa, con zoom y tus marcadores."] })
	barra.Abrir:SetPoint("LEFT", barra.Limpio, "RIGHT", 4, 0)
	barra:SetSize(2 + 26 * 2 + 4 + barra.Abrir:GetWidth() + 3, 30)
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
			elseif que == "hide" then
				-- La ficha de un marcador abierta desde este mapa se va con él.
				local E = M.Editor
				if E and E.Visible() and not V.Visible() then E.Cerrar() end
				if Panel.Visible() and not V.Visible() then Panel.Ocultar() end
			end
		end)
	end
end
MJ.CrearBarra = crearBarra

---------------------------------------------------------------------------
-- Mayús+clic derecho en el mapa del juego: un marcador ahí
---------------------------------------------------------------------------

local enganchado = false

local function chatAbierto()
	local activo = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow) or ChatEdit_GetActiveWindow
	return activo ~= nil and activo() ~= nil
end

local function alClicLienzo(lienzo, boton)
	if boton ~= "RightButton" or not (IsShiftKeyDown and IsShiftKeyDown()) then return false end
	if (IsControlKeyDown and IsControlKeyDown()) or (IsAltKeyDown and IsAltKeyDown()) or chatAbierto() then return false end
	if oculto() or A.Get("mundo.marcarEnMapaJuego") == false then return false end
	local ok, mapa = pcall(lienzo.GetMapID, lienzo)
	local ok2, x, y = pcall(lienzo.GetNormalizedCursorPosition, lienzo)
	if not (ok and ok2 and type(mapa) == "number" and type(x) == "number" and type(y) == "number") then return false end
	local E = M.Editor
	if not (E and E.Abrir) then return false end
	E.Abrir({ nuevo = { mapa = mapa, x = x * 100, y = y * 100 } })
	return true
end

local function engancharLienzo()
	local mapa = WorldMapFrame
	if enganchado or mando() or not (mapa and mapa.AddCanvasClickHandler and mapa.GetNormalizedCursorPosition) then return end
	mapa:AddCanvasClickHandler(alClicLienzo)
	enganchado = true
end

---------------------------------------------------------------------------
-- La tecla del mapa
---------------------------------------------------------------------------

local dueno
local aplicadas = ""

-- Dentro de una mazmorra, banda o campo de batalla la tecla abre el mapa del
-- juego (el de Alfa no tiene los interiores): 1.2.0.
local function enInstancia()
	local C = A.Compat
	local ok, si = pcall(function() return C and C.IsInInstance and C.IsInInstance() end)
	return ok and si and true or false
end

local function aplicarTecla()
	if not (SetOverrideBinding and ClearOverrideBindings and GetBindingKey) then return end
	dueno = dueno or CreateFrame("Frame", "AlfaMundoTeclas", UIParent)
	local quiero = A.Get("mundo.teclaM") == true and not oculto() and not mando() and not enInstancia()
	local teclas = {}
	if quiero then
		for _, k in ipairs({ GetBindingKey("TOGGLEWORLDMAP") }) do
			if type(k) == "string" and k ~= "" then teclas[#teclas + 1] = k end
		end
	end
	local firma = table.concat(teclas, ",")
	if firma == aplicadas then return end
	N.FueraDeCombate("mundo.teclaM", function()
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
	engancharLienzo()
	aplicarTecla()
end

if type(A.OnLogin) == "function" then A.OnLogin(alEntrar) end

A.RegisterEvent("ADDON_LOADED", function(_, nombre)
	if nombre == "Blizzard_WorldMap" and type(A.IsLoggedIn) == "function" and A.IsLoggedIn() then
		crearBarra()
		engancharLienzo()
	end
end)

A.RegisterEvent("UPDATE_BINDINGS", function() aplicarTecla() end)
-- Al entrar o salir de una instancia (en la pantalla de carga se puede).
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() aplicarTecla() end)

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
	if path == "" or path == "mundo" or path == "mundo.estiloMapa" then V.Estilo() end
	if path == "" or path == "mundo" or path == "mundo.teclaM" then aplicarTecla() end
	if path == "" or path == "nav" or path == "nav.mapIcons" or path == "maps.zoneLevels" or path == "mundo.nombres" then Mc.Reestilar() end
	mostrarBarra()
end)

if T and type(T.OnChanged) == "function" then T.OnChanged(function() Mc.Reestilar() end) end
