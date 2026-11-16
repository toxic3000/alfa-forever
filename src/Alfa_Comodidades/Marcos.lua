-- Alfa - Comodidades: colores de clase en los marcos, los grifos de la barra
-- de acción y la distancia de la cámara (como ClassColFrames, la barra sin
-- grifos y MaxCameraZoom de Leatrix Plus, con código propio). GPL-3.0.
--
--   Colores de clase:
--     * Tu marco: Forever usa el marco moderno (PlayerFrame.PlayerFrameContent.
--       PlayerFrameContentMain, Camelot/PlayerFrame.lua), que no tiene fondo
--       bajo tu nombre. Se le pone uno propio con el arte del fondo del
--       objetivo ("UI-HUD-UnitFrame-Target-PortraitOn-Type"), en espejo y en
--       el lugar simétrico al del objetivo (Camelot/TargetFrame.lua lo pone a
--       82 px del borde y 26 hacia abajo), pintado del color de tu clase.
--     * El objetivo: Blizzard pinta su fondo (ReputationColor) por reacción en
--       TargetFrameMixin:CheckFaction; se engancha con hooksecurefunc y, si el
--       objetivo es un jugador, se pinta del color de su clase. Con valores
--       secretos (combate en mazmorras) se deja como lo puso Blizzard.
--   Grifos: los remates de la barra principal (MainActionBar.EndCaps, de
--     Edit Mode) se vuelven transparentes. No se ocultan ni se mueven, así
--     Edit Mode sigue igual (también tiene su propia opción para ocultarlos).
--   Cámara: la variable cameraDistanceMaxZoomFactor (la de "Distancia máxima
--     de la cámara" en Opciones > Controles, ControlsOverrides de Camelot) al
--     máximo, guardando tu valor para devolverlo al apagar la opción.
--
-- Todo lo que toca marcos de Blizzard se hace fuera de combate.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local T = A.Theme

local legible = M.Legible

local function opcion(clave) return M.On("colores", clave) end

---------------------------------------------------------------------------
-- Tu marco
---------------------------------------------------------------------------

local ATLAS_FONDO = "UI-HUD-UnitFrame-Target-PortraitOn-Type"
local fondo

local function contenidoJugador()
	local f = PlayerFrame
	local c = f and f.PlayerFrameContent
	return c and c.PlayerFrameContentMain
end

local function crearFondo()
	if fondo then return fondo end
	local main = contenidoJugador()
	if not (main and main.CreateTexture) then return nil end
	local t = main:CreateTexture(nil, "BACKGROUND")
	local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ATLAS_FONDO)
	if type(info) == "table" and info.file and info.width then
		-- El arte en espejo: el del objetivo mira hacia su retrato, a la derecha.
		t:SetTexture(info.file)
		t:SetTexCoord(info.rightTexCoord, info.leftTexCoord, info.topTexCoord, info.bottomTexCoord)
		t:SetSize(info.width, info.height)
	elseif t.SetAtlas then
		t:SetAtlas(ATLAS_FONDO, true)
	end
	t:SetPoint("TOPLEFT", main, "TOPLEFT", 82, -26)
	t:Hide()
	fondo = t
	return t
end

local function pintarJugador()
	local si = opcion("coloresJugador")
	if not si then
		if fondo then fondo:Hide() end
		return
	end
	local t = crearFondo()
	if not t then return end
	local r, g, b = T.ClassColor()
	if not r then return t:Hide() end
	t:SetVertexColor(r, g, b, 1)
	t:Show()
end

---------------------------------------------------------------------------
-- El marco del objetivo
---------------------------------------------------------------------------

local function fondoDe(frame)
	local c = frame and frame.TargetFrameContent
	local main = c and c.TargetFrameContentMain
	return main and main.ReputationColor
end

local function colorObjetivo(frame)
	if not opcion("coloresObjetivo") then return end
	local tex = fondoDe(frame)
	local unidad = frame and frame.unit or "target"
	if not (tex and UnitIsPlayer and UnitClass) then return end
	if not legible(UnitIsPlayer(unidad)) then return end
	local _, clase = UnitClass(unidad)
	clase = legible(clase)
	if type(clase) ~= "string" then return end
	local r, g, b = T.ClassColor(clase)
	if r then tex:SetVertexColor(r, g, b) end
end

-- Al apagarlo, el color de Blizzard (lo mismo que hace CheckFaction).
local function colorBlizzard(frame)
	local tex = fondoDe(frame)
	local unidad = frame and frame.unit or "target"
	if not (tex and UnitExists and legible(UnitExists(unidad))) then return end
	local gris = UnitPlayerControlled and UnitIsTapDenied
		and not legible(UnitPlayerControlled(unidad)) and legible(UnitIsTapDenied(unidad))
	if gris then
		tex:SetVertexColor(0.5, 0.5, 0.5)
	elseif UnitSelectionColor then
		pcall(function() tex:SetVertexColor(UnitSelectionColor(unidad)) end)
	end
end

local enganchado = false
local function engancharObjetivo()
	if enganchado then return end
	local f = TargetFrame
	if f and f.CheckFaction and hooksecurefunc then
		hooksecurefunc(f, "CheckFaction", function(self) M.Seguro(colorObjetivo, self) end)
		enganchado = true
	end
end

local pintado = false
local function pintarObjetivo()
	engancharObjetivo()
	local f = TargetFrame
	if not f then return end
	if opcion("coloresObjetivo") then
		pintado = true
		colorObjetivo(f)
	elseif pintado then
		pintado = false
		colorBlizzard(f)
	end
end

M.AlCambiar({ "colores", "coloresJugador", "coloresObjetivo" }, function()
	N.FueraDeCombate(function()
		M.Seguro(pintarJugador)
		M.Seguro(pintarObjetivo)
	end)
end)

---------------------------------------------------------------------------
-- Grifos de la barra de acción
---------------------------------------------------------------------------

local tocados = {}

function M.Remates()
	local barra = MainActionBar or MainMenuBar
	local r = barra and barra.EndCaps
	if not r then return nil end
	return r.LeftEndCap, r.RightEndCap
end

local function ponerGrifos()
	local ocultar = M.Get("grifos")
	local izq, der = M.Remates()
	for _, cap in ipairs({ izq or false, der or false }) do
		local tex = cap and cap.Texture
		if tex and tex.SetAlpha then
			if ocultar then
				tex:SetAlpha(0)
				tocados[tex] = true
			elseif tocados[tex] then
				tex:SetAlpha(1)
				tocados[tex] = nil
			end
		end
	end
end

M.AlCambiar({ "grifos" }, function() N.FueraDeCombate(ponerGrifos) end)

---------------------------------------------------------------------------
-- Cámara
---------------------------------------------------------------------------

M.CVAR_CAMARA = "cameraDistanceMaxZoomFactor"
-- El máximo de la consola en los clientes clásicos; si Forever no lo acepta,
-- el tope de su propio deslizador (Opciones > Controles va de 1 a 2).
local CAMARA_MAX, CAMARA_TOPE = "2.6", "2"

M.AlCambiar({ "camara" }, function()
	M.ForzarCVar(M.CVAR_CAMARA, CAMARA_MAX, M.Get("camara"), CAMARA_TOPE)
end)
