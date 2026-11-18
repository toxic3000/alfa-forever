-- Alfa - Bienvenida: la intro, un lobo que aúlla a la luna antes de la
-- configuración o de las notas de una versión nueva (toxic3000 / La Jauría).
-- GPL-3.0.
--
-- Sale una vez por sesión: cuando la configuración se abre porque falta (la
-- primera vez) o al entrar con una versión nueva de Alfa (antes de sus notas,
-- Notas.lua). Dura 4,6 s:
--   0,0  la pantalla se oscurece y van saliendo las estrellas, que titilan
--   0,2  la luna sube con su halo, que respira despacio
--   0,6  el lobo sube sobre su peña, una silueta recortada contra la luna;
--        la luz de la luna le enciende el contorno (el color del estilo)
--   1,55 aúlla (el aullido de la bienvenida) y del hocico salen tres ondas
--   2,05 A L F A aparece con su resplandor, una raya de luz se abre debajo
--        y un brillo recorre las letras hasta un destello; luego el lema y,
--        con versión nueva, "Alfa X.Y.Z ya está aquí"
--   4,0  todo se funde y deja ver lo que sigue (que ya se abrió debajo)
-- Un clic, Esc, espacio o Enter la saltan. Si entras en combate se corta al
-- momento y lo que sigue recibe "combate" para esperar a que termine.
-- Funciona igual en los 3 estilos: los colores salen del estilo (el acento,
-- o el oro de los títulos en Clásico WoW). Las texturas son propias
-- (tools/intro.py) y el OnUpdate solo corre mientras se ve.
--
--   M.Intro(fn, o)   la muestra y luego llama a fn(motivo): nil (terminó o la
--                    saltaste) o "combate". o = { version = "1.1.4" } añade la
--                    línea de la versión; o = { texto = "..." }, otra línea
--                    (el saludo de cada entrada). Ya vista en la sesión: fn al instante
--                    (salvo con o.otraVez, para verla de nuevo: el banco).

local ADDON, M = ...
local N = AlfaNucleo
local A, K = N.A, N.Kit
local L = M.L or N.Textos(M.EN)

local MEDIA = "Interface\\AddOns\\Alfa_Bienvenida\\Media\\"
local DURACION = 4.6
local FUNDIDO = 0.6   -- el final: todo se va y deja ver lo que sigue
local AULLIDO = 1.55  -- cuándo aúlla el lobo
local ESTRELLAS = 44

local sin, max, min, floor = math.sin, math.max, math.min, math.floor

local f, alTerminar, vista, llamado
local function ahora() return GetTime and GetTime() or 0 end

-- 0..1 suave (entra y sale despacio)
local function suave(t)
	if t <= 0 then return 0 elseif t >= 1 then return 1 end
	return t * t * (3 - 2 * t)
end
-- 0..1 que frena al final (lo que sube y se acomoda)
local function frena(t)
	if t <= 0 then return 0 elseif t >= 1 then return 1 end
	local u = 1 - t
	return 1 - u * u * u
end
local function avance(t, desde, hasta) return (t - desde) / (hasta - desde) end
local function tramo(t, desde, hasta) return suave(avance(t, desde, hasta)) end

-- Llama una sola vez a lo que sigue; desde ahí la intro ya no toma el ratón
-- ni el teclado (lo que sigue se usa mientras ella se funde encima).
local function llamar(motivo)
	if llamado then return end
	llamado = true
	if f then
		f:EnableMouse(false)
		f:EnableKeyboard(false)
	end
	local fn = alTerminar
	alTerminar = nil
	if fn then K.Llamar(fn, motivo) end
end

local function terminar(motivo)
	if not f or not f:IsShown() then return end
	f:SetScript("OnUpdate", nil)
	f:Hide()
	llamar(motivo)
end

---------------------------------------------------------------------------
-- Los colores de cada estilo
---------------------------------------------------------------------------
local PALETAS = {
	--          el velo                      la luna             las estrellas       la silueta
	alfa    = { velo = { 0.02, 0.03, 0.025, 0.9 }, luna = { 0.9, 0.96, 0.88 }, estrella = { 0.88, 0.97, 0.86 }, silueta = { 0.035, 0.05, 0.04 } },
	clasico = { velo = { 0.03, 0.025, 0.018, 0.93 }, luna = { 1, 0.94, 0.8 }, estrella = { 1, 0.95, 0.82 }, silueta = { 0.04, 0.034, 0.026 } },
	cristal = { velo = { 0.02, 0.04, 0.07, 0.82 }, luna = { 0.88, 0.94, 1 }, estrella = { 0.86, 0.93, 1 }, silueta = { 0.03, 0.045, 0.065 } },
}

---------------------------------------------------------------------------
-- Las piezas
---------------------------------------------------------------------------
local function textura(capa, sub, archivo, aditiva)
	local t = f:CreateTexture(nil, capa, nil, sub)
	t:SetTexture(MEDIA .. archivo)
	if aditiva and t.SetBlendMode then t:SetBlendMode("ADD") end
	return t
end

-- Las estrellas: siempre en el mismo lugar (una semilla fija), cada una con
-- su momento para aparecer y su ritmo para titilar.
local function armarEstrellas()
	f.Estrellas = {}
	local semilla = 12345
	local function azar()
		semilla = (semilla * 1103515245 + 12345) % 2147483648
		return semilla / 2147483648
	end
	for i = 1, ESTRELLAS do
		local t = textura("BACKGROUND", 2, "intro-estrella", true)
		f.Estrellas[i] = {
			tex = t,
			x = azar() * 2 - 1,          -- -1..1 del ancho
			y = 0.02 + azar() * 0.96,    -- 0..1 de la mitad de arriba (y un poco más)
			tam = 6 + floor(azar() * azar() * 14),
			a = 0.35 + azar() * 0.6,     -- su brillo
			d = 0.1 + azar() * 1.1,      -- cuándo aparece
			v = 1.6 + azar() * 3.2,      -- qué tan rápido titila
			p = azar() * 6.28,
		}
	end
end

local function construir()
	f = CreateFrame("Button", "AlfaIntro", UIParent)
	f:SetAllPoints(UIParent)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetScript("OnClick", function() terminar() end)
	f:SetScript("OnKeyDown", function(self, tecla)
		local salta = tecla == "ESCAPE" or tecla == "SPACE" or tecla == "ENTER"
		-- En combate SetPropagateKeyboardInput está bloqueado para un addon.
		if self.SetPropagateKeyboardInput and not (InCombatLockdown and InCombatLockdown()) then
			self:SetPropagateKeyboardInput(not salta)
		end
		if salta then terminar() end
	end)
	-- Si un enemigo te ataca durante la intro, se termina al momento: nunca
	-- te deja sin teclas en combate.
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:SetScript("OnEvent", function() if f:IsShown() then terminar("combate") end end)

	f.Velo = f:CreateTexture(nil, "BACKGROUND", nil, 0)
	f.Velo:SetAllPoints(f)
	f.Velo:SetColorTexture(1, 1, 1, 1)
	armarEstrellas()
	f.Halo = textura("BORDER", 0, "intro-halo", true)
	f.Luna = textura("BORDER", 2, "intro-luna")
	f.Lobo = textura("ARTWORK", 0, "intro-lobo")
	f.Borde = textura("ARTWORK", 2, "intro-lobo-borde", true)
	f.Ondas = {}
	for i = 1, 3 do f.Ondas[i] = textura("ARTWORK", 4, "intro-onda", true) end
	f.Resplandor = textura("ARTWORK", 5, "intro-halo", true)
	f.Marca = textura("OVERLAY", 0, "intro-marca")
	-- El brillo que recorre las letras: tres franjas de la misma marca (sus
	-- coordenadas la recortan), la del centro más clara.
	f.Brillo = {}
	for i = 1, 3 do f.Brillo[i] = textura("OVERLAY", 2, "intro-marca", true) end
	f.Raya = f:CreateTexture(nil, "OVERLAY", nil, 1)
	f.Raya:SetColorTexture(1, 1, 1, 1)
	f.Destello = textura("OVERLAY", 4, "intro-destello", true)

	f.Lema = K.Texto(f, "subtitulo", "acento")
	f.Lema:SetJustifyH("CENTER")
	f.Version = K.Texto(f, "pequeno", "textoSuave")
	f.Version:SetJustifyH("CENTER")
	f.Salto = K.Texto(f, "pequeno", "textoTenue")
	f.Salto:SetJustifyH("CENTER")
	f.Salto:SetPoint("BOTTOM", f, "BOTTOM", 0, 60)
end

-- Los colores y las medidas de ahora (el estilo y el tamaño de la pantalla).
local function preparar(o)
	local pal = PALETAS[K.Estilo()] or PALETAS.alfa
	local luz = K.Clasico() and "titulo" or "acento"
	f.velo = pal.velo
	f.Velo:SetVertexColor(pal.velo[1], pal.velo[2], pal.velo[3], 1)
	for _, s in ipairs(f.Estrellas) do s.tex:SetVertexColor(pal.estrella[1], pal.estrella[2], pal.estrella[3], 1) end
	f.Luna:SetVertexColor(pal.luna[1], pal.luna[2], pal.luna[3], 1)
	f.Halo:SetVertexColor(K.Color(luz))
	f.Lobo:SetVertexColor(pal.silueta[1], pal.silueta[2], pal.silueta[3], 1)
	f.Borde:SetVertexColor(K.Color(luz))
	for _, x in ipairs(f.Ondas) do x:SetVertexColor(K.Color(luz)) end
	f.Resplandor:SetVertexColor(K.Color(luz))
	f.Marca:SetVertexColor(K.Color("titulo"))
	for _, x in ipairs(f.Brillo) do x:SetVertexColor(pal.luna[1], pal.luna[2], pal.luna[3], 1) end
	f.Raya:SetVertexColor(K.Color(luz))
	f.Destello:SetVertexColor(pal.luna[1], pal.luna[2], pal.luna[3], 1)

	-- La escena mide lo mismo en cualquier pantalla: crece o se achica con su alto.
	local W = K.num(UIParent:GetWidth(), 1366)
	local H = K.num(UIParent:GetHeight(), 768)
	local E = max(0.7, min(1.3, H / 820))
	f.E, f.W, f.H = E, W, H
	f.luna = { x = 40 * E, y = 95 * E, tam = 300 * E, halo = 660 * E }
	f.lobo = { x = -20 * E, y = 5 * E, tam = 400 * E }
	-- el hocico en la textura del lobo (tools/intro.py, HOCICO = 350, 76 de 512)
	f.hocico = { x = f.lobo.x + (350 / 512 - 0.5) * f.lobo.tam, y = f.lobo.y + (0.5 - 76 / 512) * f.lobo.tam }
	f.marca = { y = -168 * E, ancho = 360 * E, alto = 45 * E }
	f.Marca:SetSize(f.marca.ancho, f.marca.alto)
	f.Destello:SetSize(1, 1)
	for _, s in ipairs(f.Estrellas) do
		s.tex:SetSize(s.tam * E, s.tam * E)
		s.tex:ClearAllPoints()
		s.tex:SetPoint("CENTER", f, "CENTER", s.x * (W / 2 - 30), s.y * (H / 2 - 20) - H * 0.04)
	end
	f.Lema:ClearAllPoints()
	f.Lema:SetPoint("TOP", f, "CENTER", 0, f.marca.y - f.marca.alto / 2 - 18 * E)
	f.Version:ClearAllPoints()
	f.Version:SetPoint("TOP", f.Lema, "BOTTOM", 0, -8)

	K.Escribir(f.Lema, L["Guía a tu manada"])
	-- la línea de abajo: la versión nueva, o el saludo de cada entrada (o.texto)
	K.Escribir(f.Version, (o and o.version and string.format(L["Alfa %s ya está aquí"], o.version)) or (o and o.texto) or "")
	K.Escribir(f.Salto, L["Clic o Esc para saltar"])
end

local function poner(t, x, y, ancho, alto)
	t:ClearAllPoints()
	t:SetPoint("CENTER", f, "CENTER", x, y)
	t:SetSize(max(1, ancho), max(1, alto or ancho))
end

---------------------------------------------------------------------------
-- Cada cuadro
---------------------------------------------------------------------------
local function cuadro(self, t)
	local E = self.E
	local fin = 1 - tramo(t, DURACION - FUNDIDO, DURACION)

	-- el velo entra y al final se va con todo
	self.Velo:SetAlpha(self.velo[4] * tramo(t, 0, 0.45) * fin)

	-- las estrellas aparecen una a una y titilan
	for _, s in ipairs(self.Estrellas) do
		local nace = tramo(t, s.d, s.d + 0.6)
		s.tex:SetAlpha(s.a * nace * (0.62 + 0.38 * sin(t * s.v + s.p)) * fin)
	end

	-- la luna sube y se acomoda; su halo crece y respira
	local lu = self.luna
	local sube = frena(avance(t, 0.15, 1.5))
	local ly = lu.y - 70 * E * (1 - sube)
	poner(self.Luna, lu.x, ly, lu.tam)
	self.Luna:SetAlpha(tramo(t, 0.15, 1.0) * fin)
	local h = lu.halo * (0.55 + 0.45 * sube) * (1 + 0.035 * sin(t * 2.4))
	poner(self.Halo, lu.x, ly, h)
	self.Halo:SetAlpha(0.42 * tramo(t, 0.3, 1.6) * fin)

	-- el lobo sube sobre su peña; la luna le enciende el contorno
	local lo = self.lobo
	local w = frena(avance(t, 0.55, 1.5))
	local dy = -26 * E * (1 - w)
	poner(self.Lobo, lo.x, lo.y + dy, lo.tam)
	poner(self.Borde, lo.x, lo.y + dy, lo.tam)
	self.Lobo:SetAlpha(tramo(t, 0.55, 1.2) * fin)
	self.Borde:SetAlpha(tramo(t, 1.15, 1.8) * (0.88 + 0.12 * sin(t * 3.1)) * fin)

	-- el aullido, una sola vez, y sus tres ondas desde el hocico
	if not self.aullo and t >= AULLIDO then
		self.aullo = true
		if M.Aullar then M.Aullar(true) end -- en la intro siempre aúlla
	end
	for i, o in ipairs(self.Ondas) do
		local u = avance(t, AULLIDO + (i - 1) * 0.28, AULLIDO + (i - 1) * 0.28 + 1.25)
		if u <= 0 or u >= 1 then
			o:SetAlpha(0)
		else
			poner(o, self.hocico.x, self.hocico.y + dy, (46 + 270 * frena(u)) * E)
			o:SetAlpha((1 - u) ^ 1.6 * 0.9 * fin)
		end
	end

	-- A L F A, con su resplandor y la raya de luz que se abre debajo
	local ma = self.marca
	local m = tramo(t, 2.05, 2.6)
	local my = ma.y - 10 * E * (1 - m)
	poner(self.Marca, 0, my, ma.ancho, ma.alto)
	self.Marca:SetAlpha(m * fin)
	poner(self.Resplandor, 0, my, ma.ancho * 1.45, ma.alto * 3.2)
	self.Resplandor:SetAlpha((0.3 * tramo(t, 2.05, 2.5) - 0.14 * tramo(t, 2.7, 3.6)) * fin)
	local r = frena(avance(t, 2.35, 3.0))
	poner(self.Raya, 0, my - ma.alto / 2 - 7 * E, ma.ancho * 0.9 * r, max(1, floor(1.5 * E + 0.5)))
	self.Raya:SetAlpha(0.85 * r * fin)

	-- el brillo recorre las letras de izquierda a derecha
	local b = avance(t, 2.6, 3.3)
	local izq = -ma.ancho / 2
	for i, x in ipairs(self.Brillo) do
		local centro = -0.12 + 1.24 * b + (i - 2) * 0.07
		local u0, u1 = max(0, centro - 0.035), min(1, centro + 0.035)
		if b <= 0 or b >= 1 or u1 <= u0 then
			x:SetAlpha(0)
		else
			x:SetTexCoord(u0, u1, 0, 1)
			x:ClearAllPoints()
			x:SetPoint("LEFT", f, "CENTER", izq + u0 * ma.ancho, my)
			x:SetSize(max(1, (u1 - u0) * ma.ancho), ma.alto)
			x:SetAlpha((i == 2 and 0.95 or 0.45) * fin)
		end
	end

	-- el destello al final del brillo, arriba de la última letra
	local d = avance(t, 3.1, 3.75)
	if d <= 0 or d >= 1 then
		self.Destello:SetAlpha(0)
	else
		local c = sin(d * math.pi)
		poner(self.Destello, ma.ancho * 0.39, my + ma.alto * 0.36, (10 + 40 * c) * E)
		if self.Destello.SetRotation then self.Destello:SetRotation(d * 1.4) end
		self.Destello:SetAlpha(c * fin)
	end

	-- el lema, la versión y cómo saltarla
	self.Lema:SetAlpha(tramo(t, 2.5, 3.0) * fin)
	self.Version:SetAlpha(0.9 * tramo(t, 2.75, 3.2) * fin)
	self.Salto:SetAlpha(0.6 * tramo(t, 0.8, 1.4) * (1 - tramo(t, DURACION - FUNDIDO - 0.3, DURACION - FUNDIDO)))

	-- lo que sigue se abre debajo mientras todo se funde
	if not llamado and t >= DURACION - FUNDIDO then llamar() end
	if t >= DURACION then terminar() end
end
M.CuadroIntro = function(t) if f then cuadro(f, t) end end -- el banco dibuja momentos sueltos

function M.Intro(fn, o)
	-- ya en pantalla: lo que sigue espera a que termine
	if f and f:IsShown() then
		alTerminar = fn
		llamado = false
		return
	end
	if (vista and not (o and o.otraVez)) or not (GetTime and UIParent) then
		if fn then K.Llamar(fn) end
		return
	end
	vista = true
	alTerminar, llamado = fn, false
	if not f then construir() end
	preparar(o)
	f:EnableMouse(true)
	f:EnableKeyboard(true)
	f.inicio, f.aullo = ahora(), false
	cuadro(f, 0)
	f:Show()
	f:SetScript("OnUpdate", function(self) cuadro(self, ahora() - self.inicio) end)
end
