-- Alfa - Bienvenida: la intro, un lobo que aúlla a la luna antes de la
-- configuración, de las notas de una versión nueva o como saludo al entrar
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- Sale una vez por sesión. Dura 5,8 s (1.2.1: más larga, para que el aullido
-- largo respire):
--   0,0  la pantalla se oscurece y van saliendo las estrellas, que titilan
--   0,2  la luna sube con su halo, que respira despacio
--   0,6  el lobo sube sobre su peña. 1.3.3: una línea de luz (el color del
--        estilo) recorre su contorno y lo va dibujando; detrás se rellena la
--        silueta, recortada contra la luna
--   0,75 una estrella fugaz cruza el cielo
--   0,9  chispas de luz suben despacio de la peña; la neblina se mueve abajo
--   1,1  sus ojos se encienden con un destello verde (el acento), antes del aullido
--   1,25 el lobo toma aire (el pecho se hincha un poco)
--   1,55 aúlla (el aullido largo: Bienvenida.lua) y de su hocico salen cinco
--        ondas; mientras aúlla, la luna le contesta con su halo
--   2,9  A L F A aparece con su resplandor, una raya de luz se abre debajo
--        y un brillo recorre las letras hasta un destello; luego el lema y,
--        con versión nueva, "Alfa X.Y.Z ya está aquí"
--   3,45 al terminar de aullar, un destello en el ojo del lobo
--   5,2  todo se funde y deja ver lo que sigue (que ya se abrió debajo);
--        1.3.3: el lobo se deshace en chispas de luz que vuelan al botón de
--        Alfa del minimapa (AlfaMinimapButton) o, sin él, al centro de arriba
-- Toda la escena se acerca despacio (la cámara avanza un poco) y las
-- estrellas se quedan quietas: da profundidad.
-- Un clic, Esc, espacio o Enter la saltan. Si entras en combate se corta al
-- momento y lo que sigue recibe "combate" para esperar a que termine.
-- Funciona igual en los 3 estilos: los colores salen del estilo (el acento,
-- o el oro de los títulos en Clásico WoW). Las texturas son propias
-- (tools/intro.py) y el OnUpdate solo corre mientras se ve.
-- Al empezar avisa ALFA_INTRO_INICIO y, cuando deja ver lo que sigue,
-- ALFA_INTRO_FIN (motivo): Lya llega corriendo justo entonces.
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
local DURACION = 5.8
local FUNDIDO = 0.6   -- el final: todo se va y deja ver lo que sigue
local AULLIDO = 1.55  -- cuándo aúlla el lobo
local ONDAS = 5       -- las ondas del aullido
local ESTRELLAS = 44
local CHISPAS = 14
-- El lobo elegido en tools/intro.py: la punta de su hocico y su ojo, en la
-- textura de 512 (esta línea la escribe tools/intro.py).
local LOBO = { hocico = { 395, 75 }, ojo = { 344, 113 } } -- tools/intro.py (de-pie)
-- 1.3.3: su contorno en puntos parejos (x1, y1, x2, y2...), para la línea de luz
-- que lo dibuja (esta línea la escribe tools/intro.py).
local CONTORNO = { 92, 342, 89, 311, 98, 281, 118, 257, 146, 241, 176, 233, 208, 230, 239, 229, 270, 222, 294, 202, 305, 179, 315, 156, 323, 126, 311, 101, 339, 108, 365, 91, 388, 70, 386, 94, 368, 120, 385, 116, 366, 142, 367, 163, 362, 187, 358, 218, 352, 249, 347, 281, 345, 312, 344, 344, 346, 375, 362, 396, 331, 396, 326, 365, 324, 334, 318, 303, 287, 305, 256, 302, 233, 298, 235, 328, 222, 357, 223, 387, 216, 396, 199, 381, 193, 350, 186, 319, 173, 290, 151, 269, 129, 291, 109, 315 } -- tools/intro.py (de-pie)
local TRAZO = 12      -- la línea de luz: su punta y su estela
local POLVO = 18      -- las chispas en que se deshace al final
local DIBUJO = { 0.6, 1.4 } -- cuándo la línea recorre el contorno

local sin, cos, max, min, floor, pi = math.sin, math.cos, math.max, math.min, math.floor, math.pi

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

local function avisar(que, motivo)
	if A and A.Fire then pcall(A.Fire, que, motivo) end
end

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
	avisar("ALFA_INTRO_FIN", motivo)
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

-- Un azar con semilla fija: la misma escena cada vez.
local function azarDe(semilla)
	return function()
		semilla = (semilla * 1103515245 + 12345) % 2147483648
		return semilla / 2147483648
	end
end

-- Las estrellas: siempre en el mismo lugar, cada una con su momento para
-- aparecer y su ritmo para titilar.
local function armarEstrellas()
	f.Estrellas = {}
	local azar = azarDe(12345)
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

-- Las chispas: puntitos de luz que suben de la peña, se mecen y se apagan.
local function armarChispas()
	f.Chispas = {}
	local azar = azarDe(777)
	for i = 1, CHISPAS do
		f.Chispas[i] = {
			tex = textura("ARTWORK", 3, "intro-estrella", true),
			x = -0.62 + azar() * 1.1,    -- a lo ancho de la peña (en tamaños del lobo)
			d = 0.9 + azar() * 3.1,      -- cuándo nace
			vida = 1.8 + azar() * 1.2,
			sube = 0.16 + azar() * 0.2,  -- cuánto sube (en tamaños del lobo)
			tam = 4 + floor(azar() * 5),
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
	f.Fugaz = textura("BACKGROUND", 3, "intro-fugaz", true)
	f.Halo = textura("BORDER", 0, "intro-halo", true)
	f.Luna = textura("BORDER", 2, "intro-luna")
	f.Lobo = textura("ARTWORK", 0, "intro-lobo")
	f.Borde = textura("ARTWORK", 2, "intro-lobo-borde", true)
	armarChispas()
	-- la neblina de abajo: el mismo resplandor redondo, aplastado y tenue
	f.Niebla = textura("ARTWORK", 3, "intro-halo")
	f.Ondas = {}
	for i = 1, ONDAS do f.Ondas[i] = textura("ARTWORK", 4, "intro-onda", true) end
	f.Ojo = textura("ARTWORK", 6, "intro-destello", true)
	-- 1.3.3: la línea de luz que dibuja al lobo, sus ojos verdes y el polvo final
	f.Trazo = {}
	for i = 1, TRAZO do f.Trazo[i] = textura("ARTWORK", 7, i == 1 and "intro-destello" or "intro-estrella", true) end
	f.OjoHalo = textura("ARTWORK", 6, "intro-halo", true)
	f.OjoVerde = textura("ARTWORK", 7, "intro-destello", true)
	f.Polvo = {}
	local azar = azarDe(4242)
	for i = 1, POLVO do
		f.Polvo[i] = { tex = textura("OVERLAY", 5, "intro-estrella", true), d = azar() * 0.22, curva = 0.5 + azar(),
			tam = 5 + floor(azar() * 6), punto = 0 }
	end
	f.Llega = textura("OVERLAY", 6, "intro-destello", true)
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
	f.Fugaz:SetVertexColor(pal.estrella[1], pal.estrella[2], pal.estrella[3], 1)
	f.Luna:SetVertexColor(pal.luna[1], pal.luna[2], pal.luna[3], 1)
	f.Halo:SetVertexColor(K.Color(luz))
	f.Lobo:SetVertexColor(pal.silueta[1], pal.silueta[2], pal.silueta[3], 1)
	f.Borde:SetVertexColor(K.Color(luz))
	for _, c in ipairs(f.Chispas) do c.tex:SetVertexColor(K.Color(luz)) end
	f.Niebla:SetVertexColor(pal.luna[1], pal.luna[2], pal.luna[3], 1)
	for _, x in ipairs(f.Ondas) do x:SetVertexColor(K.Color(luz)) end
	f.Ojo:SetVertexColor(pal.luna[1], pal.luna[2], pal.luna[3], 1)
	f.Resplandor:SetVertexColor(K.Color(luz))
	f.Marca:SetVertexColor(K.Color("titulo"))
	for _, x in ipairs(f.Brillo) do x:SetVertexColor(pal.luna[1], pal.luna[2], pal.luna[3], 1) end
	f.Raya:SetVertexColor(K.Color(luz))
	f.Destello:SetVertexColor(pal.luna[1], pal.luna[2], pal.luna[3], 1)
	for _, x in ipairs(f.Trazo) do x:SetVertexColor(K.Color(luz)) end
	f.OjoHalo:SetVertexColor(K.Color(luz))
	f.OjoVerde:SetVertexColor(K.Color(luz))
	for _, x in ipairs(f.Polvo) do x.tex:SetVertexColor(K.Color(luz)) end
	f.Llega:SetVertexColor(K.Color(luz))

	-- La escena mide lo mismo en cualquier pantalla: crece o se achica con su alto.
	local W = K.num(UIParent:GetWidth(), 1366)
	local H = K.num(UIParent:GetHeight(), 768)
	local E = max(0.7, min(1.3, H / 820))
	f.E, f.W, f.H = E, W, H
	f.luna = { x = 40 * E, y = 95 * E, tam = 300 * E, halo = 660 * E }
	f.lobo = { x = -20 * E, y = 5 * E, tam = 400 * E }
	-- el hocico y el ojo en la textura del lobo (LOBO, de tools/intro.py)
	f.hocico = { x = f.lobo.x + (LOBO.hocico[1] / 512 - 0.5) * f.lobo.tam, y = f.lobo.y + (0.5 - LOBO.hocico[2] / 512) * f.lobo.tam }
	f.ojo = { x = f.lobo.x + (LOBO.ojo[1] / 512 - 0.5) * f.lobo.tam, y = f.lobo.y + (0.5 - LOBO.ojo[2] / 512) * f.lobo.tam }
	-- la cresta de la peña (tools/intro.py: el suelo del lobo, y = 395 de 512)
	f.pena = f.lobo.y + (0.5 - 395 / 512) * f.lobo.tam
	f.marca = { y = -168 * E, ancho = 360 * E, alto = 45 * E }
	-- 1.3.3: el contorno en la escena, y a dónde vuela el lobo al final
	f.contorno = {}
	for i = 1, #CONTORNO - 1, 2 do
		f.contorno[#f.contorno + 1] = { x = f.lobo.x + (CONTORNO[i] / 512 - 0.5) * f.lobo.tam,
			y = f.lobo.y + (0.5 - CONTORNO[i + 1] / 512) * f.lobo.tam }
	end
	for i, x in ipairs(f.Polvo) do
		x.punto = #f.contorno > 0 and (floor((i - 1) * #f.contorno / POLVO) + 1) or 0
	end
	f.destino = { x = 0, y = H / 2 - 48 * E }
	local boton = rawget(_G, "AlfaMinimapButton")
	if type(boton) == "table" and boton.IsVisible and boton:IsVisible() and boton.GetCenter then
		local bx, by = boton:GetCenter()
		local ux, uy = UIParent:GetCenter()
		local eb = K.num(boton.GetEffectiveScale and boton:GetEffectiveScale(), 1)
		local eu = K.num(UIParent.GetEffectiveScale and UIParent:GetEffectiveScale(), 1)
		if type(bx) == "number" and type(by) == "number" and type(ux) == "number" and type(uy) == "number" and eu > 0 then
			f.destino = { x = bx * eb / eu - ux, y = by * eb / eu - uy }
		end
	end
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

-- Pone una pieza en (x, y) desde el centro, con su tamaño; z acerca la escena
-- (la cámara que avanza): multiplica la distancia al centro y el tamaño.
local function poner(t, x, y, ancho, alto, z)
	z = z or 1
	t:ClearAllPoints()
	t:SetPoint("CENTER", f, "CENTER", x * z, y * z)
	t:SetSize(max(1, ancho * z), max(1, (alto or ancho) * z))
end

local function girar(t, angulo)
	if t.SetRotation then t:SetRotation(angulo) return true end
	return false
end

---------------------------------------------------------------------------
-- Cada cuadro
---------------------------------------------------------------------------
local function cuadro(self, t)
	local E = self.E
	local fin = 1 - tramo(t, DURACION - FUNDIDO, DURACION)
	-- la cámara avanza despacio durante toda la intro
	local z = 1 + 0.045 * suave(t / DURACION)

	-- el velo entra y al final se va con todo
	self.Velo:SetAlpha(self.velo[4] * tramo(t, 0, 0.45) * fin)

	-- las estrellas aparecen una a una y titilan (no se acercan: están lejos)
	for _, s in ipairs(self.Estrellas) do
		local nace = tramo(t, s.d, s.d + 0.6)
		s.tex:SetAlpha(s.a * nace * (0.62 + 0.38 * sin(t * s.v + s.p)) * fin)
	end

	-- una estrella fugaz cruza el cielo, de la izquierda hacia abajo a la derecha
	local fu = avance(t, 0.75, 1.4)
	if fu <= 0 or fu >= 1 or not self.Fugaz.SetRotation then
		self.Fugaz:SetAlpha(0)
	else
		local ang = -0.42
		local dx, dy = cos(ang), sin(ang)
		local largo = 380 * E
		local x0, y0 = -self.W * 0.40, self.H * 0.42
		local u = frena(fu)
		poner(self.Fugaz, x0 + dx * largo * u, y0 + dy * largo * u, 230 * E, 26 * E)
		girar(self.Fugaz, ang)
		self.Fugaz:SetAlpha(sin(fu * pi) ^ 0.8 * 0.9 * fin)
	end

	-- la luna sube y se acomoda; su halo crece y respira, y contesta al aullido
	local lu = self.luna
	local sube = frena(avance(t, 0.15, 1.5))
	local ly = lu.y - 70 * E * (1 - sube)
	poner(self.Luna, lu.x, ly, lu.tam, nil, z)
	self.Luna:SetAlpha(tramo(t, 0.15, 1.0) * fin)
	local contesta = tramo(t, AULLIDO, AULLIDO + 0.5) * (1 - tramo(t, 3.3, 4.3))
	local h = lu.halo * (0.55 + 0.45 * sube) * (1 + 0.035 * sin(t * 2.4) + 0.06 * contesta)
	poner(self.Halo, lu.x, ly, h, nil, z)
	self.Halo:SetAlpha((0.42 * tramo(t, 0.3, 1.6) + 0.16 * contesta * (0.75 + 0.25 * sin(t * 7.5))) * fin)

	-- el lobo sube sobre su peña; toma aire antes de aullar y lo suelta al final;
	-- la luna le enciende el contorno
	local lo = self.lobo
	local w = frena(avance(t, 0.55, 1.5))
	local aire = tramo(t, 1.2, AULLIDO) * (1 - tramo(t, 3.3, 3.9))
	local dy = -26 * E * (1 - w) + 2.5 * E * aire
	local tl = lo.tam * (1 + 0.014 * aire)
	poner(self.Lobo, lo.x, lo.y + dy, tl, nil, z)
	poner(self.Borde, lo.x, lo.y + dy, tl, nil, z)
	-- 1.3.3: al final se deshace en luz (las chispas del polvo salen de él)
	local deshace = tramo(t, DURACION - FUNDIDO - 0.25, DURACION - FUNDIDO + 0.15)
	local hay = #self.contorno > 1
	-- la línea de luz lo va dibujando (el contorno se enciende detrás de ella)
	-- y luego se rellena la silueta; sin contorno, como antes
	self.Lobo:SetAlpha((hay and tramo(t, 1.2, 1.7) or tramo(t, 0.55, 1.2)) * (1 - deshace) * fin)
	self.Borde:SetAlpha((hay and tramo(t, DIBUJO[1], DIBUJO[2] + 0.1) or tramo(t, 1.15, 1.8))
		* (0.88 + 0.12 * sin(t * 3.1) + 0.1 * contesta) * (1 - deshace) * fin)
	local tr = avance(t, DIBUJO[1], DIBUJO[2])
	for i, x in ipairs(self.Trazo) do
		local u = tr - (i - 1) * 0.014
		if not hay or tr <= 0 or tr >= 1.08 or u <= 0 or u >= 1 then
			x:SetAlpha(0)
		else
			local n = #self.contorno
			local pos = u * n
			local a = floor(pos) % n + 1
			local c = (a % n) + 1
			local k = pos - floor(pos)
			local pa, pc = self.contorno[a], self.contorno[c]
			local px, py = pa.x + (pc.x - pa.x) * k, pa.y + (pc.y - pa.y) * k
			local cabeza = i == 1
			poner(x, px, py + dy, (cabeza and 22 or (9 - i * 0.5)) * E, nil, z)
			if cabeza then girar(x, t * 3) end
			x:SetAlpha((cabeza and 1 or 0.85 * (1 - (i - 1) / TRAZO)) * fin)
		end
	end
	-- los ojos se encienden en verde antes del aullido
	local ov = avance(t, 1.05, AULLIDO + 0.1)
	if ov <= 0 or ov >= 1 then
		self.OjoVerde:SetAlpha(0)
		self.OjoHalo:SetAlpha(0)
	else
		local c = sin(ov * pi)
		poner(self.OjoVerde, self.ojo.x, self.ojo.y + dy, (8 + 26 * c) * E, nil, z)
		girar(self.OjoVerde, ov * 2)
		self.OjoVerde:SetAlpha(c * fin)
		poner(self.OjoHalo, self.ojo.x, self.ojo.y + dy, 64 * E * (0.6 + 0.4 * c), nil, z)
		self.OjoHalo:SetAlpha(0.55 * c * fin)
	end
	-- el polvo: chispas que salen del contorno y vuelan hacia el botón de Alfa
	local de = self.destino
	for _, x in ipairs(self.Polvo) do
		local u = avance(t, DURACION - FUNDIDO - 0.25 + x.d, DURACION - 0.05)
		local p0 = hay and self.contorno[x.punto]
		if not p0 or u <= 0 or u >= 1 then
			x.tex:SetAlpha(0)
		else
			local v = u * u * (3 - 2 * u)
			local ox, oy = p0.x * z, (p0.y + dy) * z
			local px = ox + (de.x - ox) * v
			local py = oy + (de.y - oy) * v + sin(u * pi) * 90 * E * x.curva
			poner(x.tex, px, py, x.tam * E * (1.2 - 0.6 * u))
			x.tex:SetAlpha(sin(u * pi) ^ 0.7 * 0.95)
		end
	end
	local ll = avance(t, DURACION - 0.32, DURACION)
	if not hay or ll <= 0 or ll >= 1 then
		self.Llega:SetAlpha(0)
	else
		local c = sin(ll * pi)
		poner(self.Llega, de.x, de.y, (10 + 34 * c) * E)
		girar(self.Llega, ll * 1.8)
		self.Llega:SetAlpha(c)
	end

	-- las chispas suben de la peña, se mecen y se apagan
	for _, c in ipairs(self.Chispas) do
		local u = avance(t, c.d, c.d + c.vida)
		if u <= 0 or u >= 1 then
			c.tex:SetAlpha(0)
		else
			local x = lo.x + c.x * lo.tam + 9 * E * sin(t * 1.7 + c.p)
			local y = self.pena + c.sube * lo.tam * u
			poner(c.tex, x, y, c.tam * E, nil, z)
			c.tex:SetAlpha(sin(u * pi) * 0.7 * fin)
		end
	end

	-- la neblina, tenue, se mueve despacio frente al pie de la peña
	poner(self.Niebla, lo.x + 30 * E * sin(t * 0.35), self.pena - 40 * E, 1000 * E, 150 * E, z)
	self.Niebla:SetAlpha(0.09 * tramo(t, 0.4, 1.6) * fin)

	-- el aullido, una sola vez (el largo), y sus ondas desde el hocico
	if not self.aullo and t >= AULLIDO then
		self.aullo = true
		if M.Aullar then M.Aullar(true, "intro") end -- en la intro siempre aúlla
	end
	for i, o in ipairs(self.Ondas) do
		local u = avance(t, AULLIDO + (i - 1) * 0.42, AULLIDO + (i - 1) * 0.42 + 1.5)
		if u <= 0 or u >= 1 then
			o:SetAlpha(0)
		else
			local fuerza = 1 - (i - 1) * 0.12 -- las últimas, más suaves
			poner(o, self.hocico.x, self.hocico.y + dy, (46 + 300 * frena(u)) * E, nil, z)
			o:SetAlpha((1 - u) ^ 1.6 * 0.9 * fuerza * fin)
		end
	end

	-- al terminar de aullar, un destello en el ojo del lobo
	local oj = avance(t, 3.4, 4.05)
	if oj <= 0 or oj >= 1 then
		self.Ojo:SetAlpha(0)
	else
		local c = sin(oj * pi)
		poner(self.Ojo, self.ojo.x, self.ojo.y + dy, (6 + 30 * c) * E, nil, z)
		girar(self.Ojo, oj * 1.6)
		self.Ojo:SetAlpha(c * 0.95 * fin)
	end

	-- A L F A, con su resplandor y la raya de luz que se abre debajo
	local ma = self.marca
	local m = tramo(t, 2.9, 3.45)
	local my = ma.y - 10 * E * (1 - m)
	poner(self.Marca, 0, my, ma.ancho, ma.alto)
	self.Marca:SetAlpha(m * fin)
	poner(self.Resplandor, 0, my, ma.ancho * 1.45, ma.alto * 3.2)
	self.Resplandor:SetAlpha((0.3 * tramo(t, 2.9, 3.35) - 0.14 * tramo(t, 3.55, 4.45)) * fin)
	local r = frena(avance(t, 3.2, 3.85))
	poner(self.Raya, 0, my - ma.alto / 2 - 7 * E, ma.ancho * 0.9 * r, max(1, floor(1.5 * E + 0.5)))
	self.Raya:SetAlpha(0.85 * r * fin)

	-- el brillo recorre las letras de izquierda a derecha
	local b = avance(t, 3.45, 4.15)
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
	local d = avance(t, 3.95, 4.6)
	if d <= 0 or d >= 1 then
		self.Destello:SetAlpha(0)
	else
		local c = sin(d * pi)
		poner(self.Destello, ma.ancho * 0.39, my + ma.alto * 0.36, (10 + 40 * c) * E)
		girar(self.Destello, d * 1.4)
		self.Destello:SetAlpha(c * fin)
	end

	-- el lema, la versión y cómo saltarla
	self.Lema:SetAlpha(tramo(t, 3.35, 3.85) * fin)
	self.Version:SetAlpha(0.9 * tramo(t, 3.6, 4.05) * fin)
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
	avisar("ALFA_INTRO_INICIO")
end

-- Si la intro se está viendo ahora (para quien quiera esperar a que termine).
function M.IntroVisible() return f and f:IsShown() and true or false end
