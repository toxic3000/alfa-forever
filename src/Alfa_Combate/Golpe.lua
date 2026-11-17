-- Alfa - Combate: barra de golpe (toxic3000 / La Jauría). GPL-3.0.
--
-- Cuánto falta para tu siguiente golpe automático, con cada mano (y a
-- distancia), con el evento PLAYER_SWING del cliente: sin registro de
-- combate. Útil para meter Embate o Golpe heroico sin perder golpes.
-- Solo se ve mientras un golpe corre; su OnUpdate vive solo mientras tanto.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local G = {}
M.Golpe = G

local type, pairs, ipairs, max, min, format, tonumber = type, pairs, ipairs, math.max, math.min, string.format, tonumber

local ANCHO, ALTO, GAP = 180, 6, 4
local CUERPO = { WARRIOR = true, ROGUE = true, PALADIN = true, SHAMAN = true, DRUID = true, HUNTER = true }
-- PlayerSwingType: 0 mano principal, 1 secundaria, 2 a distancia.
local TONO = { [0] = "acento", [1] = "claseTexto", [2] = "pnj" }

local f
local manos = {} -- tipo -> { inicio, dur }

local function barra(i)
	local b = CreateFrame("StatusBar", nil, f)
	b:SetSize(ANCHO, ALTO)
	b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(i * (ALTO + GAP)))
	b:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	b:SetMinMaxValues(0, 1)
	b:SetValue(0)
	b.Pista = K.Plano(b, "hundido", "BACKGROUND", 0)
	b.Pista:SetAllPoints(b)
	b.Texto = K.Texto(b, "pequeno", "textoSuave")
	b.Texto:SetPoint("LEFT", b, "RIGHT", 6, 0)
	K.Pintar(b, function(x) x:SetStatusBarColor(K.Color(TONO[i] or "acento")) end)
	b:Hide()
	return b
end

local function alCorrer(self)
	local ahora, alguna = GetTime(), false
	for t, b in pairs(self.Barras) do
		local m = manos[t]
		if m and ahora < m.inicio + m.dur + 0.3 then
			local resta = m.inicio + m.dur - ahora
			b:SetValue(min(1, (ahora - m.inicio) / m.dur))
			b.Texto:SetText(resta > 0 and format("%.1f", resta) or "")
			b:Show()
			alguna = true
		elseif not M.Desbloqueado() then
			manos[t] = nil
			b:Hide()
		end
	end
	if not alguna and not M.Desbloqueado() then
		self:SetScript("OnUpdate", nil)
		self:Hide()
	end
end

local function crear()
	if f then return f end
	f = M.Marco("Golpe", L["Barra de golpe"], ANCHO, 3 * ALTO + 2 * GAP, { "CENTER", "CENTER", 0, -222 })
	f.Barras = { [0] = barra(0), [1] = barra(1), [2] = barra(2) }
	f:Hide()
	return f
end

function G.Golpe(dur, tipo)
	if not M.Opt("golpe") or M.Secreto(dur) or M.Secreto(tipo) then return end
	if not CUERPO[M.Clase() or ""] then return end
	dur, tipo = tonumber(dur), tonumber(tipo) or 0
	if not dur or dur <= 0 or not TONO[tipo] then return end
	manos[tipo] = { inicio = GetTime(), dur = dur }
	crear()
	f:Show()
	f:SetScript("OnUpdate", alCorrer)
end

function G.Ver()
	if M.Desbloqueado() and M.Opt("golpe") then
		crear()
		for t, b in pairs(f.Barras) do
			b:SetValue(t == 0 and 0.6 or 0.3)
			b.Texto:SetText(t == 0 and "1.4" or "")
			b:Show()
		end
		f:SetScript("OnUpdate", nil)
		f:Show()
	elseif f and not f:GetScript("OnUpdate") then
		for _, b in pairs(f.Barras) do b:Hide() end
		f:Hide()
	end
end
