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

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, ID = M.U, M.ID
local I = M.Insignias

local R = {}
M.Retrato = R

local type, pairs, pcall = type, pairs, pcall

local ARO = "Interface\\AddOns\\Alfa\\Media\\Map\\medallion-halo"
local TAM = 22 -- el aro; el lobo va a 14

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
	aro:SetPoint("CENTER", retrato, "TOPLEFT", 7, -7)
	local lobo = c:CreateTexture(nil, "OVERLAY", nil, 7)
	lobo:SetSize(14, 14)
	lobo:SetPoint("CENTER", aro, "CENTER", 0, 0)
	aro:Hide()
	lobo:Hide()
	chapas[unit] = { aro = aro, lobo = lobo }
	return chapas[unit]
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
		return nil
	end
	local r, g, b = e.color[1], e.color[2], e.color[3]
	ch.aro:SetVertexColor(r, g, b, 1)
	ch.lobo:SetTexture(e.icono)
	ch.lobo:SetVertexColor(r, g, b, 1)
	ch.aro:Show()
	ch.lobo:Show()
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
A.On("SETTING_CHANGED", function(path)
	if path == ID .. ".insigniaRetrato" or path == ID or path == "" then R.Refrescar() end
end)
