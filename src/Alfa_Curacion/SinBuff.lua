-- Alfa - Curación: quién no tiene tu hechizo de apoyo, en un ícono (1.4.0,
-- mejora 41). toxic3000 / La Jauría. GPL-3.0.
--
-- El punto azul de cada marco (Marcos.lua, buffFalta) ya dice a quién le
-- falta; con un grupo grande no se ve de un vistazo. Aquí, a la izquierda de
-- tus marcos, un solo ícono chico: el de tu hechizo de apoyo con cuántos no
-- lo tienen («3»). Al pasar el ratón, quiénes son. Nada más: no atrapa clics
-- en combate (en combate ni se ve: los apoyos se reparten antes de pelear),
-- no habla y no suena. Sale solo en grupo, con «Le falta tu hechizo de apoyo»
-- prendido y con curacion.buffIcono (de fábrica, sí).
--   Sb.Faltan() -> { nombre, ... }   Sb.Refrescar()   Sb.Marco()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local type, ipairs, pcall, format, min = type, ipairs, pcall, string.format, math.min

local Sb = {}
M.SinBuff = Sb

local TAM = 20
local CADA = 1.5
local marco

local function opt(k) return N.Get(ID, k) end
local function enGrupo() return IsInGroup and N.Si(IsInGroup()) or false end

local function nombreDe(b)
	local u = b.unidad
	if not u or not UnitName then return "?" end
	local ok, n = pcall(UnitName, u)
	n = ok and N.Leer(n) or nil
	return type(n) == "string" and n or "?"
end

function Sb.Faltan()
	local out = {}
	for _, b in ipairs(M.botones or {}) do
		if b.unidad and b.alfaSinBuff and b:IsVisible() then out[#out + 1] = nombreDe(b) end
	end
	table.sort(out)
	return out
end

local function crear()
	if marco or not M.ancla then return marco end
	marco = CreateFrame("Frame", "AlfaCuracionSinBuff", M.ancla)
	marco:SetSize(TAM, TAM)
	marco:SetPoint("TOPRIGHT", M.ancla, "TOPLEFT", -6, 0)
	marco.fondo = marco:CreateTexture(nil, "BACKGROUND")
	marco.fondo:SetTexture("Interface\\Buttons\\WHITE8x8")
	marco.fondo:SetPoint("TOPLEFT", marco, "TOPLEFT", -1, 1)
	marco.fondo:SetPoint("BOTTOMRIGHT", marco, "BOTTOMRIGHT", 1, -1)
	marco.fondo:SetVertexColor(0.02, 0.025, 0.04, 0.85)
	marco.icono = marco:CreateTexture(nil, "ARTWORK")
	marco.icono:SetAllPoints(marco)
	marco.icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	marco.punto = marco:CreateTexture(nil, "OVERLAY")
	marco.punto:SetTexture("Interface\\Buttons\\WHITE8x8")
	marco.punto:SetSize(5, 5)
	marco.punto:SetPoint("BOTTOMRIGHT", marco, "BOTTOMRIGHT", 1, -1)
	marco.punto:SetVertexColor(0.35, 0.75, 1, 1) -- el azul del punto de cada marco
	marco.cuenta = marco:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	local T = A.Theme
	if T and T.Font then pcall(T.Font, marco.cuenta, "caption") end
	marco.cuenta:SetPoint("TOPLEFT", marco, "TOPLEFT", 1, -1)
	marco.cuenta:SetShadowOffset(1, -1)
	marco.cuenta:SetShadowColor(0, 0, 0, 1)
	marco.cuenta:SetTextColor(1, 1, 1, 1)
	marco:SetScript("OnEnter", function(self)
		if M.EnCombate() then return end
		local faltan = Sb.Faltan()
		local b = M.BuffDeClase and M.BuffDeClase()
		local hechizo = b and M.NombreHechizo and M.NombreHechizo(b.id) or L["tu hechizo de apoyo"]
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(format(L["Les falta %s"], hechizo), 0.35, 0.75, 1)
		for i = 1, min(#faltan, 10) do GameTooltip:AddLine(faltan[i], 1, 1, 1) end
		if #faltan > 10 then GameTooltip:AddLine(format(L["y %d más"], #faltan - 10), 0.7, 0.7, 0.7) end
		GameTooltip:AddLine(L["Dáselo antes de pelear: cada marco con el punto azul lo necesita."], 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	marco:SetScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
	marco:Hide()
	return marco
end

function Sb.Marco() return marco end

function Sb.Refrescar()
	if not crear() then return end
	local quiere = opt("activo") and opt("buffs") and opt("buffIcono") ~= false and enGrupo() and not M.EnCombate()
	local b = quiere and M.BuffDeClase and M.BuffDeClase()
	if not b then marco:Hide() return end
	local n = #Sb.Faltan()
	if n == 0 then marco:Hide() return end
	local tex = M.IconoHechizo and M.IconoHechizo(b.id)
	marco.icono:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
	marco.cuenta:SetText(tostring(n))
	marco:EnableMouse(true)
	marco:Show()
end

local function reloj()
	local quiere = opt("activo") and opt("buffs") and opt("buffIcono") ~= false and enGrupo()
	if quiere and not N.HayTarea("curacion.sinBuff") then
		N.Cada("curacion.sinBuff", CADA, function() if not M.EnCombate() then Sb.Refrescar() end end)
	elseif not quiere then
		if N.HayTarea("curacion.sinBuff") then N.Quitar("curacion.sinBuff") end
		if marco then marco:Hide() end
	end
end
Sb.Reloj = reloj

A.RegisterEvent("GROUP_ROSTER_UPDATE", reloj)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() A.After(4, reloj) end)
-- En combate se esconde (y no toma el ratón); al salir, vuelve a contar.
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() if marco then marco:EnableMouse(false) marco:Hide() end end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() A.After(0.5, Sb.Refrescar) end)
A.On("SETTING_CHANGED", function(path)
	if path == ID .. ".buffIcono" or path == ID .. ".buffs" or path == ID .. ".activo" or path == ID or path == "" then
		reloj()
		Sb.Refrescar()
	end
end)
