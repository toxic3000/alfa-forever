-- Alfa - Kit: el anuncio animado (1.2.7). toxic3000 / La Jauría. GPL-3.0.
--
-- Un anuncio grande y limpio arriba del centro, con el estilo de la intro de
-- Alfa: el lobo con su halo, una línea pequeña arriba («LA MANADA VIAJA»), el
-- nombre en grande (a dónde llegas, lo que apareció) con dos rayas de luz
-- que se abren a los lados, y una línea abajo con lo demás. Entra con una
-- animación (sube y aparece), se queda unos segundos y se desvanece solo.
-- Sin cuadros ni botones: si trae una acción, un clic sobre él la hace (y lo
-- dice la pista). En combate no toma clics.
--
--   K.Anuncio({ sobre, titulo, texto, lobo = "aullando", segundos = 6,
--               cuenta = { hasta = GetTime() + s, formato = "Llega en %s" },
--               alClic = fn, pista = "Clic: ir de caza" })
--   K.QuitarAnuncio()
--
-- El turno con el juego (1.3.1): arriba del centro el juego escribe el nombre
-- de la zona al llegar (ZoneTextFrame / SubZoneTextFrame, que se desvanecen
-- solos en unos segundos) y saca sus estandartes (jefes, subir de nivel,
-- avisos de evento). Un anuncio de Alfa nunca se cruza con ellos: si están a
-- la vista, espera a que se vayan (como mucho ESPERA_MAX s) y sale después; y
-- si el juego saca uno mientras el de Alfa se ve, el de Alfa se va rápido y
-- vuelve en cuanto el juego termina, con el tiempo que le quedaba.

local _, N = ...
local K = N.Kit

local floor, max, min, format = math.floor, math.max, math.min, string.format

local HALO = "Interface\\AddOns\\Alfa_Bienvenida\\Media\\intro-halo"
local ENTRA, SALE, SALE_RAPIDO = 0.55, 1.0, 0.35
local ESPERA_MAX = 10   -- s: si el juego no suelta la pantalla, sale igual
local MIRAR = 0.4       -- s entre una mirada y otra mientras espera
local f

-- Lo que el juego pinta arriba del centro y que un anuncio no debe tapar.
local DEL_JUEGO = { "ZoneTextFrame", "SubZoneTextFrame", "BossBanner", "EventToastManagerFrame", "LevelUpDisplay" }
local function juegoOcupado()
	for _, nombre in ipairs(DEL_JUEGO) do
		local g = rawget(_G, nombre)
		if type(g) == "table" and g.IsShown and g:IsShown() then
			local a = g.GetAlpha and g:GetAlpha()
			if type(a) ~= "number" or a > 0.05 then return true end
		end
	end
	return false
end
K.JuegoOcupaArriba = juegoOcupado

local espera       -- { o, desde }: el anuncio que espera su turno
local mostrar      -- abajo
local function despues(s, fn)
	if N.Una then N.Una("kit.anuncio", s, fn)
	elseif C_Timer and C_Timer.After then C_Timer.After(s, fn) end
end
local function revisarEspera()
	local e = espera
	if not e then return end
	local ahora = GetTime and GetTime() or 0
	if juegoOcupado() and ahora - e.desde < ESPERA_MAX then
		despues(MIRAR, revisarEspera)
		return
	end
	espera = nil
	mostrar(e.o)
end
-- Guarda el anuncio para después (si ya había otro esperando, manda el nuevo).
local function esperar(o)
	local ahora = GetTime and GetTime() or 0
	espera = { o = o, desde = espera and espera.desde or ahora }
	despues(MIRAR, revisarEspera)
end

local function mmss(s)
	s = max(0, floor((s or 0) + 0.5))
	return format("%d:%02d", floor(s / 60), s % 60)
end

local function color(fs, token, a)
	local r, g, b = K.Color(token)
	fs:SetTextColor(r, g, b, a or 1)
end

local function armar()
	f = CreateFrame("Frame", "AlfaAnuncio", K.Raiz())
	f:SetSize(720, 170)
	f:SetPoint("TOP", UIParent, "TOP", 0, -130)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(false)
	f:Hide()

	f.Halo = f:CreateTexture(nil, "BACKGROUND")
	f.Halo:SetTexture(HALO)
	f.Halo:SetSize(150, 150)
	f.Halo:SetPoint("CENTER", f, "TOP", 0, -42)
	f.Halo:SetBlendMode("ADD")
	f.Lobo = f:CreateTexture(nil, "ARTWORK")
	f.Lobo:SetSize(58, 58)
	f.Lobo:SetPoint("CENTER", f.Halo, "CENTER", 0, 0)

	f.Sobre = K.Texto(f, "mayus", "acento")
	f.Sobre:SetJustifyH("CENTER")
	f.Titulo = K.Texto(f, "anuncio", "texto")
	f.Titulo:SetJustifyH("CENTER")
	f.Texto = K.Texto(f, "globoGrande", "textoSuave")
	f.Texto:SetJustifyH("CENTER")
	f.Pista = K.Texto(f, "nota", "textoTenue")
	f.Pista:SetJustifyH("CENTER")
	for _, fs in ipairs({ f.Sobre, f.Titulo, f.Texto, f.Pista }) do
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 0.9)
		fs:SetWidth(700)
	end

	-- Las dos rayas de luz a los lados del nombre.
	f.RayaI = f:CreateTexture(nil, "ARTWORK")
	f.RayaD = f:CreateTexture(nil, "ARTWORK")
	for _, t in ipairs({ f.RayaI, f.RayaD }) do
		t:SetColorTexture(1, 1, 1, 1)
		t:SetHeight(2)
	end

	f:SetScript("OnMouseUp", function(self)
		local fn = self.alfaClic
		if fn and not (InCombatLockdown and InCombatLockdown()) then
			K.Llamar(fn)
			self:Hide()
		end
	end)

	f:SetScript("OnUpdate", function(self, dt)
		local t = (self.alfaT or 0) + (tonumber(dt) or 0)
		self.alfaT = t
		local dura = self.alfaDura or 6
		-- El juego sacó lo suyo (llegaste a una zona, un jefe…): este se va rápido
		-- y vuelve después con el tiempo que le quedaba.
		if not self.alfaSaliendo and t < dura and juegoOcupado() then
			self.alfaSaliendo = true
			local queda = dura - t
			if self.alfaO and queda > 1.5 then
				local o = {}
				for k, v in pairs(self.alfaO) do o[k] = v end
				o.segundos = max(3, queda)
				esperar(o)
			end
			self.alfaSale = SALE_RAPIDO
			self.alfaFin = t
		end
		local sale = self.alfaSale or SALE
		local fin = self.alfaFin or dura
		local a
		if t < ENTRA and not self.alfaSaliendo then a = t / ENTRA
		elseif t < fin then a = 1
		elseif t < fin + sale then a = (self.alfaDesde or 1) * (1 - (t - fin) / sale)
		else self:Hide() return end
		if not self.alfaSaliendo or t <= fin then self.alfaDesde = a end
		self:SetAlpha(a)
		-- Entra subiendo un poco; el halo respira; las rayas se abren.
		local sube = t < ENTRA and (1 - t / ENTRA) * 14 or 0
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOP", self, "TOP", 0, -98 - sube)
		local r = min(1, max(0, (t - 0.2) / 0.7))
		local ancho = floor(r * 170 + 0.5)
		local tw = min(560, K.AnchoTexto(self.Titulo))
		self.RayaI:ClearAllPoints()
		self.RayaI:SetPoint("RIGHT", self.Titulo, "CENTER", -(tw / 2 + 14), 0)
		self.RayaD:ClearAllPoints()
		self.RayaD:SetPoint("LEFT", self.Titulo, "CENTER", tw / 2 + 14, 0)
		self.RayaI:SetWidth(max(1, ancho))
		self.RayaD:SetWidth(max(1, ancho))
		self.Halo:SetAlpha(0.35 + 0.15 * math.sin(t * 2.2))
		-- La cuenta, al segundo.
		local c = self.alfaCuenta
		if c then
			local queda = (c.hasta or 0) - (GetTime and GetTime() or 0)
			local s = max(0, floor(queda + 0.5))
			if s ~= self.alfaSeg then
				self.alfaSeg = s
				K.Escribir(self.Texto, queda > 0 and format(c.formato, mmss(queda)) or (c.final or ""))
			end
		end
	end)

	K.Pintar(f, function(x)
		local r, g, b = K.Color(K.Clasico() and "oro" or "acento")
		x.Lobo:SetVertexColor(r, g, b, 1)
		x.Halo:SetVertexColor(r, g, b, 1)
		x.RayaI:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.9))
		x.RayaD:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.9), CreateColor(r, g, b, 0))
	end)
end

function K.Anuncio(o)
	if type(o) ~= "table" or type(o.titulo) ~= "string" then return false end
	local A = N.A
	if A and A.Hidden and A.Hidden() then return false end
	-- El juego está escribiendo arriba (el nombre de la zona, un estandarte):
	-- este sale cuando termine.
	if juegoOcupado() then
		esperar(o)
		return true
	end
	return mostrar(o)
end

mostrar = function(o)
	local A = N.A
	if A and A.Hidden and A.Hidden() then return false end
	if not f then armar() end
	f.alfaO = o
	f.alfaSaliendo, f.alfaSale, f.alfaFin, f.alfaDesde = nil, nil, nil, nil
	f.Lobo:SetTexture(K.Lobo(o.lobo or "aullando"))
	K.Escribir(f.Sobre, o.sobre and K.Mayus(o.sobre) or "")
	K.Escribir(f.Titulo, o.titulo)
	K.Escribir(f.Texto, o.texto or "")
	K.Escribir(f.Pista, o.alClic and o.pista or "")
	f.Sobre:ClearAllPoints()
	f.Sobre:SetPoint("TOP", f, "TOP", 0, -80)
	f.Texto:ClearAllPoints()
	f.Texto:SetPoint("TOP", f, "TOP", 0, -136)
	f.Pista:ClearAllPoints()
	f.Pista:SetPoint("TOP", f.Texto, "BOTTOM", 0, -6)
	f.alfaClic = o.alClic
	f.alfaCuenta = o.cuenta
	f.alfaSeg = nil
	f.alfaDura = tonumber(o.segundos) or 6
	f.alfaT = 0
	f:EnableMouse(o.alClic ~= nil and not (InCombatLockdown and InCombatLockdown()))
	f:SetAlpha(0)
	f:Show()
	return true
end

function K.QuitarAnuncio()
	espera = nil
	if f then f:Hide() end
end
function K.AnuncioEsperando() return espera ~= nil end

-- En combate deja pasar los clics (no atrapa nada).
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function() if f then f:EnableMouse(false) end end)
