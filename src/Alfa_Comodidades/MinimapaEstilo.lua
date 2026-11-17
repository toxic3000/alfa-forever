-- Alfa - Comodidades: el minimapa con el estilo de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- El marco del minimapa y su barra de arriba toman el estilo elegido
-- (Estilo.lua), redondo o cuadrado (el cuadrado es «Minimapa cuadrado», en
-- Minimapa.lua), como la ventana del mapa de Alfa (K.Ventana):
--
--   Cuadrado: un bisel con la forma de Alfa detrás del mapa, 5 px más grande
--     (el fondo, el borde de 1 px); en Clásico WoW, el marco de los cuadros
--     de información. Reemplaza al borde fino de Minimapa.lua.
--   Redondo (Alfa y Cristal): el aro de Blizzard (MinimapCompassTexture) se
--     vuelve transparente y encima va un aro propio (Media/anillo-bisel y
--     anillo-linea) en los colores del estilo. Con el minimapa girando
--     (CVar rotateMinimap) se deja el de Blizzard, que lleva el norte. En
--     Clásico WoW el redondo es el de Blizzard tal cual.
--   La barra de arriba (MinimapCluster.ZoneTextButton, con el nombre de la
--     zona y la hora, Camelot/MinimapZoneTextButton.xml y
--     Blizzard_TimeManagerOverrides.lua): su arte se vuelve transparente y
--     detrás va una caja de Alfa con su marca de acento; la zona y la hora
--     toman la letra del estilo. Los botones de rastreo, calendario y correo
--     son íconos del juego y se quedan como están.
--
-- Solo marcos propios, transparencias y letras; Minimap y MinimapCluster no
-- son protegidos. Se engancha UpdateMinimapConfig (hooksecurefunc) para
-- volver a aplicarse cuando Blizzard rehace el minimapa. Al apagarlo todo
-- vuelve sin /reload.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local BISEL = 5

local function activo() return M.Get("minimapaEstilo") end
local function estilo() return M.EstiloDe("minimapaEstiloTema") end
local function cuadrado()
	local mm = M.Minimapa
	return mm and mm.EsCuadrado and mm.EsCuadrado() and true or false
end

local toques = M.Toques()
local bisel, pielBisel, anillo, cabecera, pielCabecera
local aplicado = false

-- Minimapa.lua pregunta esto para no dibujar su borde fino debajo del bisel.
function M.EstiloMinimapaActivo() return aplicado end

local function nivel(f, d)
	local ok, n = pcall(f.GetFrameLevel, f)
	n = ok and type(n) == "number" and n or 1
	return math.max(0, n + d)
end

local function crear()
	if bisel then return true end
	local mapa = Minimap
	if type(mapa) ~= "table" or not mapa.GetFrameLevel then return false end
	-- El bisel, detrás del mapa.
	bisel = CreateFrame("Frame", nil, mapa:GetParent() or MinimapCluster or UIParent)
	bisel:SetPoint("TOPLEFT", mapa, "TOPLEFT", -BISEL, BISEL)
	bisel:SetPoint("BOTTOMRIGHT", mapa, "BOTTOMRIGHT", BISEL, -BISEL)
	pielBisel = M.Piel(bisel, { corte = K.CORTE.panel })
	bisel:Hide()
	-- El aro, encima del borde del mapa.
	anillo = CreateFrame("Frame", nil, mapa)
	anillo:SetPoint("TOPLEFT", mapa, "TOPLEFT", -6, 6)
	anillo:SetPoint("BOTTOMRIGHT", mapa, "BOTTOMRIGHT", 6, -6)
	anillo.Bisel = anillo:CreateTexture(nil, "ARTWORK", nil, 1)
	anillo.Bisel:SetTexture(MEDIA .. "anillo-bisel")
	anillo.Bisel:SetAllPoints(anillo)
	anillo.Linea = anillo:CreateTexture(nil, "ARTWORK", nil, 2)
	anillo.Linea:SetTexture(MEDIA .. "anillo-linea")
	anillo.Linea:SetAllPoints(anillo)
	anillo:Hide()
	-- La barra de arriba.
	local zona = MinimapCluster and MinimapCluster.ZoneTextButton
	if type(zona) == "table" and zona.GetFrameLevel then
		cabecera = CreateFrame("Frame", nil, MinimapCluster)
		cabecera:SetPoint("TOPLEFT", zona, "TOPLEFT", 0, 0)
		cabecera:SetPoint("BOTTOMRIGHT", zona, "BOTTOMRIGHT", 0, 0)
		pielCabecera = M.Piel(cabecera, { corte = K.CORTE.control, marca = true, anchoMarca = 20 })
		cabecera:Hide()
		-- Blizzard enciende su arte al pasar el ratón: que siga transparente.
		if zona.OnButtonStateChanged and hooksecurefunc then
			hooksecurefunc(zona, "OnButtonStateChanged", function(self)
				if cabecera and cabecera:IsShown() and self.AddTexture then self.AddTexture:SetAlpha(0) end
			end)
		end
	end
	return true
end

-- El aro de Blizzard: transparente bajo el aro propio; si no, como lo deja
-- Minimapa.lua (oculto en el cuadrado).
local function brujula(ocultar)
	local a = ocultar and 0 or (cuadrado() and 0 or 1)
	if MinimapCompassTexture then MinimapCompassTexture:SetAlpha(a) end
	if MinimapCompassTextureUnderlay then MinimapCompassTextureUnderlay:SetAlpha(a) end
end

local function letras(est)
	local zonaTexto = MinimapZoneText
	local hora = TimeManagerClockTicker
	local con = aplicado and M.Get("minimapaCabecera")
	toques:Letra(zonaTexto, con and M.CaraDe(est, "medium") or nil)
	toques:Letra(hora, con and M.CaraDe(est, "semibold") or nil)
end

local function cabeceraArte(mostrar)
	local zona = MinimapCluster and MinimapCluster.ZoneTextButton
	if type(zona) ~= "table" then return end
	if mostrar then
		toques:Ocultar(zona.StateTexture)
		toques:Ocultar(zona.AddTexture)
	else
		toques:DevolverUna(zona.StateTexture)
		toques:DevolverUna(zona.AddTexture)
	end
end

local function aplicar()
	if type(Minimap) ~= "table" then return end
	if not activo() then
		if not aplicado then return end
		aplicado = false
		if bisel then bisel:Hide() pielBisel:Hide() end
		if anillo then anillo:Hide() end
		if cabecera then cabecera:Hide() pielCabecera:Hide() end
		cabeceraArte(false)
		letras(estilo())
		toques:Devolver()
		brujula(false)
	else
		if not crear() then return end
		aplicado = true
		local est = estilo()
		local cuad = cuadrado()
		-- Cuadrado: el bisel.
		bisel:SetFrameLevel(nivel(Minimap, -1))
		bisel:SetShown(cuad)
		pielBisel:SetShown(cuad)
		if cuad then pielBisel:Pintar(est, { fondo = "fondo", borde = "lineaFuerte", opacidad = 1 }) end
		-- Redondo: el aro propio, salvo en Clásico WoW o con el minimapa girando.
		local girando = M.LeerCVar("rotateMinimap") == "1"
		local conAnillo = not cuad and est ~= "clasico" and not girando
		anillo:SetFrameLevel(nivel(Minimap, 2))
		anillo:SetShown(conAnillo)
		if conAnillo then
			anillo.Bisel:SetVertexColor(M.ColorDe(est, "fondo"))
			anillo.Linea:SetVertexColor(M.ColorDe(est, "lineaFuerte"))
		end
		brujula(conAnillo)
		-- La barra de la zona.
		local conCabecera = cabecera and M.Get("minimapaCabecera") and est ~= "clasico"
		if cabecera then
			local zona = MinimapCluster.ZoneTextButton
			cabecera:SetFrameLevel(nivel(zona, -1))
			cabecera:SetShown(conCabecera and true or false)
			pielCabecera:SetShown(conCabecera and true or false)
			if conCabecera then pielCabecera:Pintar(est, { fondo = "panel", borde = "linea", opacidad = 1 }) end
		end
		cabeceraArte(conCabecera)
		letras(est)
	end
	local mm = M.Minimapa
	if mm and mm.RefrescarBorde then mm.RefrescarBorde() end
end

-- Minimapa.lua llama esto al cambiar la forma (cuadrado o redondo).
function M.AlCambiarFormaMinimapa()
	if activo() or aplicado then aplicar() end
end

local enganchado = false
local function enganchar()
	if enganchado then return end
	local C = MinimapCluster
	if type(C) == "table" and C.UpdateMinimapConfig and hooksecurefunc then
		hooksecurefunc(C, "UpdateMinimapConfig", function()
			if aplicado then M.Seguro(aplicar) end
		end)
		enganchado = true
	end
end

M.AlCambiar({ "minimapaEstilo", "minimapaEstiloTema", "minimapaCabecera" }, function()
	enganchar()
	N.FueraDeCombate(aplicar)
end)

M.AlCambiarAspecto(function()
	if activo() then N.FueraDeCombate(aplicar) end
end)

-- La hora (Blizzard_TimeManager) llega un poco después de entrar.
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if not activo() then return end
	A.After(2, function() if activo() then N.FueraDeCombate(aplicar) end end)
end)

-- Para pruebas.
M.MinimapaEstilo = { Aplicar = aplicar }
