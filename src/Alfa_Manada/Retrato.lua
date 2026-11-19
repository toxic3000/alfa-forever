-- Alfa - La Jauría: la insignia en el retrato (1.2.2). toxic3000 / La
-- Jauría. GPL-3.0.
--
-- Quien lleva insignia (Insignias.lua: "alfa" o "jauria") la luce en el
-- borde de su retrato: el tuyo (tu marco), el de tu objetivo y el de tu
-- foco. Es una chapita redonda, el aro teñido del color de su rango y el
-- lobo encima, en la esquina de arriba a la izquierda del retrato (abajo
-- está el nivel y a la izquierda la facción).
--
-- Solo son texturas nuevas sobre el contenedor del marco del juego (nunca un
-- marco nuevo ni nada protegido): mostrarlas o esconderlas está permitido
-- también en combate. Lo secreto (nombres en mazmorras) no se lee: sin
-- insignia. Se apaga en La Jauría > Invitar ("Tu insignia en los retratos").
-- 1.2.7: los logros de la insignia, solo visuales: una estrella si está en el
-- nivel máximo y, en el tuyo, el ícono de raros si llevas 100 raros vistos.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, ID = M.U, M.ID
local I = M.Insignias

local R = {}
M.Retrato = R

local type, pairs, pcall = type, pairs, pcall

local ARO = "Interface\\AddOns\\Alfa\\Media\\Map\\medallion-halo"
local TAM, LOBO = 28, 18 -- el aro y el lobo (1.2.5: un poco más grandes; antes 22 y 14)
-- 1.2.7: los logros (la estrella del juego; sin ella, la del raro de Alfa).
local ESTRELLA = 12
local ATLAS_ESTRELLA = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star"
local ESTRELLA_ALFA = "Interface\\AddOns\\Alfa\\Media\\Map\\icon-rare"
local RAROS = "Interface\\AddOns\\Alfa\\Media\\UI\\ic-raros"
local RAROS_LOGRO = 100

-- unidad -> { contenedor, retrato } del marco del juego (Camelot y moderno).
local function partes(unit)
	if unit == "player" then
		local f = rawget(_G, "PlayerFrame")
		local c = f and f.PlayerFrameContainer
		return c, c and c.PlayerPortrait
	end
	local f = rawget(_G, unit == "target" and "TargetFrame" or "FocusFrame")
	local c = f and f.TargetFrameContainer
	return c, c and c.Portrait
end

local chapas = {} -- unidad -> { aro, lobo }

local function chapa(unit)
	if chapas[unit] then return chapas[unit] end
	local c, retrato = partes(unit)
	if not (c and retrato and c.CreateTexture and retrato.GetObjectType) then return nil end
	local aro = c:CreateTexture(nil, "OVERLAY", nil, 6)
	aro:SetTexture(ARO)
	aro:SetSize(TAM, TAM)
	aro:SetPoint("CENTER", retrato, "TOPLEFT", 9, -9)
	local lobo = c:CreateTexture(nil, "OVERLAY", nil, 7)
	lobo:SetSize(LOBO, LOBO)
	lobo:SetPoint("CENTER", aro, "CENTER", 0, 0)
	aro:Hide()
	lobo:Hide()
	-- 1.2.7: los logros de la insignia, solo visuales. La estrella (nivel
	-- máximo) abajo a la derecha del aro; el raro (100 raros vistos, solo en
	-- el tuyo) arriba a la derecha.
	local estrella = c:CreateTexture(nil, "OVERLAY", nil, 7)
	estrella:SetSize(ESTRELLA, ESTRELLA)
	estrella:SetPoint("CENTER", aro, "BOTTOMRIGHT", -5, 5)
	local CT = C_Texture
	local okA, info = false, nil
	if type(CT) == "table" and type(CT.GetAtlasInfo) == "function" then okA, info = pcall(CT.GetAtlasInfo, ATLAS_ESTRELLA) end
	if okA and type(info) == "table" and estrella.SetAtlas and pcall(estrella.SetAtlas, estrella, ATLAS_ESTRELLA) then
		-- la estrella dorada del juego
	else
		estrella:SetTexture(ESTRELLA_ALFA)
		estrella:SetVertexColor(1, 0.82, 0.2, 1)
	end
	estrella:Hide()
	local raros = c:CreateTexture(nil, "OVERLAY", nil, 7)
	raros:SetSize(ESTRELLA, ESTRELLA)
	raros:SetPoint("CENTER", aro, "TOPRIGHT", -5, -5)
	raros:SetTexture(RAROS)
	raros:Hide()
	chapas[unit] = { aro = aro, lobo = lobo, estrella = estrella, raros = raros }
	return chapas[unit]
end

-- 1.2.7: ¿está en el nivel máximo?
local function nivelMaximo(unit)
	if not UnitLevel then return false end
	local ok, n = pcall(UnitLevel, unit)
	n = ok and U.Numero(n) or nil
	if not n then return false end
	local tope = 60
	if GetMaxPlayerLevel then
		local okT, t = pcall(GetMaxPlayerLevel)
		t = okT and U.Numero(t) or nil
		if t and t > 0 then tope = t end
	end
	return n >= tope
end

-- 1.2.7: cuántos raros distintos llevas vistos (el historial de raros del
-- motor, A.Rares.History: de la cuenta en este reino). Solo se lee.
local cuentaRaros
function R.RarosVistos()
	if cuentaRaros then return cuentaRaros end
	local Ra = A.Rares
	if not (type(Ra) == "table" and type(Ra.History) == "function") then return 0 end
	local ok, h = pcall(Ra.History)
	if not ok or type(h) ~= "table" then return 0 end
	local n = 0
	for _, e in pairs(h) do
		if type(e) == "table" and e.kind == "rare" then n = n + 1 end
	end
	cuentaRaros = n
	return n
end

local function encendida() return N.Get(ID, "insigniaRetrato") ~= false end

-- La insignia de una unidad en su retrato (o nada).
function R.Pintar(unit)
	local tipo = encendida() and I.Hay() and I.DeUnidad(unit) or nil
	local e = tipo and I.Estilo(tipo)
	local ch = (e or chapas[unit]) and chapa(unit)
	if not ch then return nil end
	if not e then
		ch.aro:Hide()
		ch.lobo:Hide()
		ch.estrella:Hide()
		ch.raros:Hide()
		return nil
	end
	local r, g, b = e.color[1], e.color[2], e.color[3]
	ch.aro:SetVertexColor(r, g, b, 1)
	ch.lobo:SetTexture(e.icono)
	ch.lobo:SetVertexColor(r, g, b, 1)
	ch.aro:Show()
	ch.lobo:Show()
	-- 1.2.7: los logros.
	ch.estrella:SetShown(nivelMaximo(unit))
	if unit == "player" and R.RarosVistos() >= RAROS_LOGRO then
		ch.raros:SetVertexColor(r, g, b, 1)
		ch.raros:Show()
	else
		ch.raros:Hide()
	end
	return tipo
end

function R.Refrescar()
	for _, unit in pairs({ "player", "target", "focus" }) do pcall(R.Pintar, unit) end
end

-- Para el banco: la chapa de una unidad ({ aro, lobo } o nil).
function R.Chapa(unit) return chapas[unit] end

A.OnLogin(function() A.After(1, R.Refrescar) end)
A.RegisterEvent("PLAYER_TARGET_CHANGED", function() pcall(R.Pintar, "target") end)
A.RegisterEvent("PLAYER_FOCUS_CHANGED", function() pcall(R.Pintar, "focus") end)
-- 1.2.7: al subir de nivel, la estrella; con un raro nuevo, la cuenta.
A.RegisterEvent("PLAYER_LEVEL_UP", function() A.After(1, function() pcall(R.Pintar, "player") end) end)
A.On("RARES_HISTORY", function()
	cuentaRaros = nil
	pcall(R.Pintar, "player")
end)
A.On("SETTING_CHANGED", function(path)
	if path == ID .. ".insigniaRetrato" or path == ID or path == "" then R.Refrescar() end
end)
