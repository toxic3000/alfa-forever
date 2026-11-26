-- Alfa - Comodidades: el minimapa (cuadrado, botones de addons ocultos y
-- sin el menú de addons). GPL-3.0.
--
--   Cuadrado: la máscara del minimapa pasa a ser un cuadrado (la misma
--     textura blanca que usa el motor para sus capas en un minimapa
--     cuadrado, Nav/Pins.lua), se oculta el aro de Blizzard
--     (MinimapCompassTexture) y se dibuja un borde fino del tema. Se define
--     GetMinimapShape() = "SQUARE", la convención que leen los addons y el
--     propio motor (su botón y sus capas); Blizzard no la define en Forever.
--     Blizzard vuelve a poner su máscara en MinimapCluster:UpdateMinimapConfig
--     (al girar el minimapa, Camelot/Minimap.lua): se engancha con
--     hooksecurefunc y se vuelve a aplicar.
--   Botones de addons: los botones de otros addons alrededor del minimapa
--     (LibDBIcon y los que llevan "Minimap" y "Button"/"Icon" en su nombre)
--     se vuelven invisibles y aparecen al pasar el ratón sobre el minimapa.
--     Solo se cambia su transparencia: nunca se ocultan, se mueven ni se
--     tocan marcos protegidos. El de Alfa (AlfaMinimapButton) siempre queda
--     a la vista (1.3.1): es por donde un jugador nuevo encuentra Alfa.
--   Menú de addons: el botón con el número de addons (AddonCompartmentFrame)
--     se atenúa como los botones (1.3.7) y aparece al pasar el ratón; su
--     UpdateDisplay (enganchado) conserva la transparencia.
--
-- La rueda del ratón ya acerca y aleja el minimapa en Forever
-- (MinimapMixin:OnMouseWheel de Blizzard): no hace falta nada aquí.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local T = A.Theme

local MASCARA_CUADRADA = "Interface\\Buttons\\WHITE8X8"

local function opcion(clave) return M.On("minimapa", clave) end

---------------------------------------------------------------------------
-- Minimapa cuadrado
---------------------------------------------------------------------------

local cuadrado = false   -- lo que está aplicado ahora
local formaPrevia        -- GetMinimapShape de otro addon, si lo había
local borde

local function forma() return "SQUARE" end

local function ponerBorde()
	if borde or not Minimap then return end
	borde = CreateFrame("Frame", nil, Minimap)
	borde:SetAllPoints(Minimap)
	borde:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 2)
	-- Una sombra de dos píxeles por fuera y una línea del tema por dentro.
	local sombra = CreateFrame("Frame", nil, borde)
	sombra:SetAllPoints(borde)
	T.Border(sombra, 0, 0, 0, 0.75, "OVERLAY", 3)
	local linea = CreateFrame("Frame", nil, borde)
	linea:SetAllPoints(borde)
	linea:SetFrameLevel(sombra:GetFrameLevel() + 1)
	borde.Pintar = function()
		local r, g, b = T.Color("textMuted")
		T.Border(linea, r, g, b, 0.55, "OVERLAY")
	end
	borde.Pintar()
	if T.OnChanged then T.OnChanged(function() if borde then borde.Pintar() end end) end
end

local function aplicarMascara()
	if not (cuadrado and Minimap and Minimap.SetMaskTexture) then return end
	pcall(Minimap.SetMaskTexture, Minimap, MASCARA_CUADRADA)
	if MinimapCompassTexture then MinimapCompassTexture:SetAlpha(0) end
	if MinimapCompassTextureUnderlay then MinimapCompassTextureUnderlay:SetAlpha(0) end
	ponerBorde()
	-- Con el estilo del minimapa (MinimapaEstilo.lua) va su bisel en lugar del borde fino.
	borde:SetShown(not (M.EstiloMinimapaActivo and M.EstiloMinimapaActivo()))
end

-- El borde fino según la forma y el estilo (lo llama MinimapaEstilo.lua).
local function refrescarBorde()
	if not borde then return end
	borde:SetShown(cuadrado and not (M.EstiloMinimapaActivo and M.EstiloMinimapaActivo()))
end

-- El botón del motor se coloca según la forma: que se acomode ya.
local function moverBotonAlfa()
	local Maps = A.Maps
	if Maps and Maps.RefreshMinimapButton then M.Seguro(Maps.RefreshMinimapButton) end
end

local function ponerCuadrado(si)
	if si == cuadrado then
		if si then aplicarMascara() end
		return
	end
	cuadrado = si
	if si then
		local actual = rawget(_G, "GetMinimapShape")
		if actual ~= forma then formaPrevia = actual end
		GetMinimapShape = forma
		aplicarMascara()
	else
		if rawget(_G, "GetMinimapShape") == forma then GetMinimapShape = formaPrevia end
		if borde then borde:Hide() end
		if MinimapCompassTexture then MinimapCompassTexture:SetAlpha(1) end
		if MinimapCompassTextureUnderlay then MinimapCompassTextureUnderlay:SetAlpha(1) end
		-- Blizzard vuelve a poner su máscara y su aro.
		local C = MinimapCluster
		if C and C.UpdateMinimapConfig then pcall(C.UpdateMinimapConfig, C) end
	end
	moverBotonAlfa()
	-- El estilo del minimapa cambia de bisel cuadrado a aro redondo.
	if M.AlCambiarFormaMinimapa then M.Seguro(M.AlCambiarFormaMinimapa) end
end

local enganchadoCluster = false
local function engancharCluster()
	if enganchadoCluster then return end
	local C = MinimapCluster
	if C and C.UpdateMinimapConfig and hooksecurefunc then
		hooksecurefunc(C, "UpdateMinimapConfig", function() M.Seguro(aplicarMascara) end)
		enganchadoCluster = true
	end
end

---------------------------------------------------------------------------
-- Botones de addons: invisibles hasta pasar el ratón por el minimapa
---------------------------------------------------------------------------

-- Botones de Blizzard que llevan "Minimap" en el nombre: nunca se tocan.
local BLIZZARD = {
	ExpansionLandingPageMinimapButton = true, GarrisonLandingPageMinimapButton = true,
	MinimapZoomIn = true, MinimapZoomOut = true, MiniMapTrackingButton = true, MiniMapTracking = true,
	MiniMapWorldMapButton = true, MiniMapMailFrame = true, MiniMapBattlefieldFrame = true,
	MiniMapLFGFrame = true, QueueStatusMinimapButton = true, MinimapZoneTextButton = true,
	MiniMapInstanceDifficulty = true, GuildInstanceDifficulty = true, MiniMapChallengeMode = true,
	MinimapBackdrop = true, MinimapCompassTexture = true, MinimapCluster = true,
	GameTimeFrame = true, TimeManagerClockButton = true, AddonCompartmentFrame = true,
	MiniMapMailIcon = true, MinimapZoneText = true, QueueStatusButton = true, MiniMapCraftingOrderIcon = true,
	-- El de Alfa tampoco: es la puerta de entrada a Alfa (1.3.1).
	AlfaMinimapButton = true,
}

local botones = {}    -- marco -> true: los que se atenúan
local visibles = true -- su estado ahora
local alfa = 1

local function esBotonDeAddon(f)
	if type(f) ~= "table" or not f.GetName or not f.SetAlpha then return false end
	local ok, nombre = pcall(f.GetName, f)
	if not ok or type(nombre) ~= "string" or BLIZZARD[nombre] then return false end
	if f.IsForbidden and f:IsForbidden() then return false end
	if f.IsProtected and f:IsProtected() then return false end
	if nombre:find("^LibDBIcon10_") then return true end
	local bajo = nombre:lower()
	if not bajo:find("minimap", 1, true) then return false end
	return bajo:find("button", 1, true) or bajo:find("icon", 1, true) or false
end

-- 1.3.2: sin vigilar cada 0.15 s. El ratón avisa al entrar y al salir del
-- minimapa o de un botón (OnEnter/OnLeave); el reloj solo corre durante el
-- fundido («comodidades.minimapa») y se quita al terminar.
local FUNDIDO = "comodidades.minimapa"
local enganchados = {} -- marco -> true: ya avisa al entrar y salir
local revisar

local function enganchar(f)
	if not (f and f.HookScript) or enganchados[f] then return end
	enganchados[f] = true
	-- 1.4.1: sin prenderle el ratón (K.Enganchar): MinimapCluster, el
	-- contenedor grande de la esquina, se volvía una pared que se comía el
	-- clic y el arrastre de la cámara en toda su área.
	local K = N.Kit
	K.Enganchar(f, "OnEnter", function() revisar() end)
	-- Al pasar del minimapa a un botón suyo, el juego dice «salió» antes de «entró»:
	-- se mira un momento después.
	K.Enganchar(f, "OnLeave", function() N.Una("comodidades.minimapaSalio", 0.05, function() revisar() end) end)
end

local function buscarEn(padre)
	if not (padre and padre.GetChildren) then return end
	for _, f in ipairs({ padre:GetChildren() }) do
		if not botones[f] and esBotonDeAddon(f) then
			botones[f] = true
			if not visibles then f:SetAlpha(alfa) end
			enganchar(f)
		end
	end
end

local function buscar()
	buscarEn(Minimap)
	buscarEn(MinimapBackdrop)
	buscarEn(MinimapCluster)
end

-- 1.3.7 (154): el menú de addons (AddonCompartmentFrame) ya no se esconde:
-- se atenúa como los botones y aparece al pasar el ratón (sigue a la mano).
local botonesOn, sinMenu = false, false
local function menuAtenuado()
	local f = rawget(_G, "AddonCompartmentFrame")
	return sinMenu and type(f) == "table" and f.SetAlpha and f or nil
end

local function ponerAlfa(a)
	alfa = a
	if botonesOn then
		for f in pairs(botones) do pcall(f.SetAlpha, f, a) end
	end
	local m = menuAtenuado()
	if m then pcall(m.SetAlpha, m, a) end
end

local function encima()
	if MinimapCluster and MinimapCluster:IsMouseOver() then return true end
	if Minimap and Minimap:IsMouseOver() then return true end
	if botonesOn then
		for f in pairs(botones) do
			if f:IsShown() and f:IsMouseOver() then return true end
		end
	end
	local m = menuAtenuado()
	if m and m.IsMouseOver and m:IsShown() and m:IsMouseOver() then return true end
	return false
end

-- Un paso del fundido; al llegar, el reloj se quita.
local function fundir()
	local objetivo = (not visibles and encima()) and 1 or (visibles and 1 or 0)
	if objetivo == alfa then N.Quitar(FUNDIDO) return end
	local paso = 0.5
	ponerAlfa(objetivo > alfa and math.min(1, alfa + paso) or math.max(0, alfa - paso))
	if alfa == objetivo then N.Quitar(FUNDIDO) end
end

revisar = function()
	if visibles then return end
	-- Al entrar al minimapa, de paso, los botones nuevos de otros addons.
	if botonesOn then buscar() end
	local objetivo = encima() and 1 or 0
	if objetivo ~= alfa and not N.HayTarea(FUNDIDO) then N.Cada(FUNDIDO, 0.15, fundir) end
end

-- Atenúa lo que toca (los botones, el menú o los dos) o lo deja todo a la vista.
local function atenuar()
	if botonesOn or sinMenu then
		enganchar(Minimap)
		enganchar(MinimapCluster)
		local m = menuAtenuado()
		if m then enganchar(m) end
		visibles = false
		ponerAlfa(encima() and 1 or 0)
	else
		N.Quitar(FUNDIDO)
		visibles = true
		ponerAlfa(1)
	end
end

local function ponerBotones(si)
	si = si and true or false
	if si then
		botonesOn = true
		buscar()
	elseif botonesOn then
		botonesOn = false
		for f in pairs(botones) do pcall(f.SetAlpha, f, 1) end
	end
end

---------------------------------------------------------------------------
-- Menú de addons (el número en la esquina del minimapa)
---------------------------------------------------------------------------

local enganchadoMenu = false

local function ponerMenu(si)
	si = si and true or false
	local f = rawget(_G, "AddonCompartmentFrame")
	if not f then sinMenu = si return end
	if not enganchadoMenu and f.UpdateDisplay and hooksecurefunc then
		-- (el juego lo repinta: conserva lo atenuado)
		hooksecurefunc(f, "UpdateDisplay", function(self) if sinMenu and self.SetAlpha then self:SetAlpha(alfa) end end)
		enganchadoMenu = true
	end
	if si == sinMenu then return end
	if not si and f.SetAlpha then f:SetAlpha(1) end
	sinMenu = si
	-- Se muestra como el juego quiera (con addons en su lista); solo cambia su transparencia.
	if f.UpdateDisplay then pcall(f.UpdateDisplay, f) elseif f.Show then f:Show() end
end

---------------------------------------------------------------------------

local function aplicar()
	if not Minimap then return end
	engancharCluster()
	ponerCuadrado(opcion("minimapaCuadrado"))
	ponerBotones(opcion("minimapaBotones"))
	ponerMenu(opcion("minimapaMenu"))
	atenuar()
end

M.AlCambiar({ "minimapa", "minimapaCuadrado", "minimapaBotones", "minimapaMenu" }, aplicar)

-- Los botones de otros addons aparecen al entrar o un poco después.
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if not opcion("minimapaBotones") then return end
	buscar()
	A.After(3, function() if opcion("minimapaBotones") then buscar(); ponerAlfa(alfa) end end)
end)

-- Para pruebas.
M.Minimapa = { EsBotonDeAddon = esBotonDeAddon, Botones = botones, Aplicar = aplicar, Revisar = function() revisar() end,
	Alfa = function() return alfa end,
	EsCuadrado = function() return cuadrado end, RefrescarBorde = refrescarBorde }
