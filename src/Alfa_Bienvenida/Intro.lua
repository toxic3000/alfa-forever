-- Alfa - Bienvenida: la intro, un lobo que aúlla a la luna antes de la
-- configuración (toxic3000 / La Jauría). GPL-3.0.
--
-- Sale una vez por sesión, solo cuando la configuración se abre porque falta
-- (la primera vez o con una versión nueva del asistente). Dura unos 4 s:
-- la pantalla se oscurece, sale la luna, el lobo sube y aúlla (el aullido de
-- la bienvenida, si está encendido), aparece "ALFA · Guía a tu manada" y se
-- funde para dar paso al asistente. Un clic o Esc la salta.
--
--   M.Intro(fn)   la muestra y luego llama a fn (ya vista en la sesión: fn al instante)

local ADDON, M = ...
local N = AlfaNucleo
local A, K = N.A, N.Kit
local L = M.L or N.Textos(M.EN)

local LUNA = "Interface\\AddOns\\Alfa_Bienvenida\\Media\\intro-luna"
local DURACION = 4.2

local f, alTerminar, vista
local function ahora() return GetTime and GetTime() or 0 end

local function terminar()
	if not f or not f:IsShown() then return end
	f:SetScript("OnUpdate", nil)
	f:Hide()
	local fn = alTerminar
	alTerminar = nil
	if fn then K.Llamar(fn) end
end

-- 0..1 suave
local function suave(t)
	if t <= 0 then return 0 elseif t >= 1 then return 1 end
	return t * t * (3 - 2 * t)
end
local function tramo(t, desde, hasta) return suave((t - desde) / (hasta - desde)) end

local function construir()
	f = CreateFrame("Button", "AlfaIntro", UIParent)
	f:SetAllPoints(UIParent)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:EnableMouse(true)
	f:EnableKeyboard(true)
	f:SetScript("OnClick", terminar)
	f:SetScript("OnKeyDown", function(self, tecla)
		if tecla == "ESCAPE" or tecla == "SPACE" or tecla == "ENTER" then terminar() end
		-- En combate SetPropagateKeyboardInput está bloqueado para un addon.
		if self.SetPropagateKeyboardInput and not (InCombatLockdown and InCombatLockdown()) then
			self:SetPropagateKeyboardInput(tecla ~= "ESCAPE" and tecla ~= "SPACE" and tecla ~= "ENTER")
		end
	end)
	-- Si un enemigo te ataca durante la intro, se termina al momento: nunca
	-- te deja sin teclas en combate.
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:SetScript("OnEvent", function() if f:IsShown() then terminar() end end)

	f.Velo = f:CreateTexture(nil, "BACKGROUND")
	f.Velo:SetAllPoints(f)
	f.Velo:SetColorTexture(0.02, 0.03, 0.025, 1)

	f.Luna = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.Luna:SetTexture(LUNA)
	f.Luna:SetSize(340, 340)
	f.Luna:SetPoint("CENTER", f, "CENTER", 70, 70)

	f.Lobo = f:CreateTexture(nil, "ARTWORK", nil, 3)
	f.Lobo:SetTexture(K.Lobo("aullando"))
	f.Lobo:SetSize(190, 190)

	f.Marca = K.Texto(f, "portada", "texto")
	f.Marca:SetJustifyH("CENTER")
	f.Marca:SetPoint("TOP", f, "CENTER", 0, -120)
	f.Lema = K.Texto(f, "subtitulo", "acento")
	f.Lema:SetJustifyH("CENTER")
	f.Lema:SetPoint("TOP", f.Marca, "BOTTOM", 0, -8)
	f.Salto = K.Texto(f, "pequeno", "textoTenue")
	f.Salto:SetJustifyH("CENTER")
	f.Salto:SetPoint("BOTTOM", f, "BOTTOM", 0, 60)
end

local function cuadro(self)
	local t = ahora() - self.inicio
	-- el velo entra y al final se va con todo
	local salida = 1 - tramo(t, DURACION - 0.7, DURACION)
	self.Velo:SetAlpha(0.88 * tramo(t, 0, 0.5) * salida)
	-- la luna aparece
	self.Luna:SetAlpha(tramo(t, 0.2, 1.2) * salida)
	-- el lobo sube desde abajo, del color del acento
	local subir = tramo(t, 0.5, 1.6)
	self.Lobo:ClearAllPoints()
	self.Lobo:SetPoint("CENTER", self, "CENTER", -75, -40 * (1 - subir) - 35)
	self.Lobo:SetAlpha(subir * salida)
	-- el aullido, una sola vez, cuando el lobo ya está arriba
	if not self.aullo and t >= 1.4 then
		self.aullo = true
		if M.Aullar then M.Aullar(true) end -- en la intro siempre aúlla
	end
	-- la marca y el lema
	self.Marca:SetAlpha(tramo(t, 1.8, 2.4) * salida)
	self.Lema:SetAlpha(tramo(t, 2.1, 2.7) * salida)
	self.Salto:SetAlpha(0.6 * tramo(t, 0.8, 1.4) * salida)
	if t >= DURACION then terminar() end
end

function M.Intro(fn)
	-- ya en pantalla: el asistente espera a que termine
	if f and f:IsShown() then
		alTerminar = fn
		return
	end
	if vista or not (GetTime and UIParent) then
		if fn then K.Llamar(fn) end
		return
	end
	vista = true
	alTerminar = fn
	if not f then construir() end
	f.Lobo:SetVertexColor(K.Color("acento"))
	K.Escribir(f.Marca, "A L F A")
	K.Escribir(f.Lema, L["Guía a tu manada"])
	K.Escribir(f.Salto, L["Clic o Esc para saltar"])
	f.inicio, f.aullo = ahora(), false
	for _, r in ipairs({ f.Velo, f.Luna, f.Lobo, f.Marca, f.Lema, f.Salto }) do r:SetAlpha(0) end
	f:Show()
	f:SetScript("OnUpdate", cuadro)
end
