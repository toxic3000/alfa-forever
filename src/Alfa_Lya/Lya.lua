-- Alfa - Lya: la loba en pantalla y su globo (toxic3000 / La Jauría). GPL-3.0.
--
-- Lya es un marco chico (lya.tamano, 64 px) que se arrastra y recuerda su
-- lugar (lya.pos; lya.bloqueado lo fija). Dos capas: el pelaje negro con sus
-- colores (Media/lya-<cara>) y el contorno blanco (lya-<cara>-borde) que se
-- tiñe con el acento del estilo (el oro en Clásico WoW), sobre una placa del
-- Kit. Todo se repinta solo al cambiar de estilo (K.Pintar).
--
-- Vida (nada en OnUpdate): respira con un AnimationGroup en bucle (más lento
-- dormida), parpadea con un temporizador al azar, salta con otro grupo, aúlla
-- (la cara de aullido y un salto), se duerme y se despierta. Oculta, todo se
-- detiene. En combate se queda quieta y tenue.
--
-- El globo: una caja del Kit junto a ella, "Lya: texto" en hasta 3 líneas y
-- hasta dos botones; se va solo a los 8 s (12 con botones, no con el ratón
-- encima), con su X o al hacer clic en un botón.
--
--   M.UI.Aplicar()               mostrar u ocultar según los ajustes y la bienvenida
--   M.UI.Hablar(c)               c = { texto, acciones = { { texto, fn }, ... }, cara, salto, aullar, segundos }
--   M.UI.Callar()  M.UI.Hablando()  M.UI.Visible()  M.UI.Frame()
--   M.UI.Dormir(si)  M.UI.Dormida()  M.UI.Saltar()  M.UI.Aullar()  M.UI.Combate(si)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local floor, max, min, random, type, tonumber, ipairs = math.floor, math.max, math.min, math.random, type, tonumber, ipairs

local UI = {}
M.UI = UI

local MEDIA = "Interface\\AddOns\\Alfa_Lya\\Media\\"
local DEFAULT = { "BOTTOMRIGHT", -330, 150 }
local ANCHO_MAX, ANCHO_MIN, PAD = 300, 170, 12

local f, g                       -- Lya y su globo
local cara = "normal"            -- la de fondo: normal, atenta, dormida
local momento                    -- una cara pasajera (aullando, parpadeo) encima de la de fondo
local dormida, combate = false, false
local turnoGlobo, turnoMomento, turnoParpadeo = 0, 0, 0
local actual                     -- lo que dice ahora

local function tam()
	local t = tonumber(N.Get(ID, "tamano")) or 64
	return max(40, min(128, floor(t + 0.5)))
end

function UI.Frame() return f end
function UI.Visible() return f and f:IsShown() and true or false end
function UI.Hablando() return g and g:IsShown() and actual ~= nil end
function UI.Dormida() return dormida end

---------------------------------------------------------------------------
-- Cara
---------------------------------------------------------------------------
local function ponerTextura()
	if not f then return end
	local c = momento or cara
	f.Pelo:SetTexture(MEDIA .. "lya-" .. c)
	f.Borde:SetTexture(MEDIA .. "lya-" .. c .. "-borde")
end

local function pintarLya(x)
	local tono = K.Clasico() and "oro" or "acento"
	x.Borde:SetVertexColor(K.ConAlfa(tono, 0.95))
	x.Pelo:SetVertexColor(1, 1, 1, 1)
	x.caja:Estilo({ fondo = "panel", alfaFondo = K.Cristal() and 0.55 or 0.88, borde = tono, alfaBorde = 0.35 })
end

-- Una cara por un rato (aullando, parpadeo) y de vuelta a la de fondo.
local function cambiarUnRato(c, segundos)
	turnoMomento = turnoMomento + 1
	local mio = turnoMomento
	momento = c
	ponerTextura()
	K.Despues(segundos, function()
		if mio ~= turnoMomento then return end
		momento = nil
		ponerTextura()
	end)
end

---------------------------------------------------------------------------
-- Respirar, parpadear, saltar
---------------------------------------------------------------------------
local function respirar()
	if not (f and f:IsShown()) then return end
	local r = f.Respirar
	r:Stop()
	if combate then return end
	f.RespirarT:SetOffset(0, dormida and 1 or 2)
	f.RespirarT:SetDuration(dormida and 2.6 or 1.5)
	r:Play()
end

local parpadear
local function programarParpadeo()
	turnoParpadeo = turnoParpadeo + 1
	local mio = turnoParpadeo
	K.Despues(3 + random() * 4, function()
		if mio ~= turnoParpadeo then return end
		parpadear(mio)
	end)
end

parpadear = function(mio)
	if not (f and f:IsShown()) or dormida or combate then return end -- se reprograma al despertar / mostrarse
	if not momento and cara ~= "dormida" then
		cambiarUnRato("parpadeo", 0.13)
		-- a veces dos seguidos
		if random() < 0.25 then
			K.Despues(0.3, function() if mio == turnoParpadeo and not momento then cambiarUnRato("parpadeo", 0.12) end end)
		end
	end
	programarParpadeo()
end

function UI.Saltar()
	if not (f and f:IsShown()) or combate then return end
	if f.Salto:IsPlaying() then return end
	f.Respirar:Stop()
	f.Salto:Play()
end

function UI.Aullar()
	if not f then return end
	UI.Dormir(false)
	cambiarUnRato("aullando", 3.5)
	UI.Saltar()
end

function UI.Dormir(si)
	si = si and true or false
	if si == dormida then return end
	dormida = si
	cara = si and "dormida" or "normal"
	momento = nil
	ponerTextura()
	respirar()
	if not si then programarParpadeo() end
end

function UI.Combate(si)
	combate = si and true or false
	if not f then return end
	f:SetAlpha(combate and 0.45 or 1)
	if combate then
		f.Respirar:Stop()
		f.Salto:Stop()
	else
		respirar()
		programarParpadeo()
	end
end

---------------------------------------------------------------------------
-- El menú del clic derecho
---------------------------------------------------------------------------
local function menu()
	local Ce = M.Cerebro
	local silencio = Ce.Silenciada()
	local bloqueado = N.Get(ID, "bloqueado") and true or false
	local Hi = M.Historias
	local grupos = {
		{ { valor = "silencio", texto = silencio and L["Quitar el silencio"] or L["Silenciar 1 hora"], icono = "ic-reloj" } },
		{},
		{ { valor = "frec:muchos", texto = L["Consejos: muchos"] },
		  { valor = "frec:pocos", texto = L["Consejos: pocos"] },
		  { valor = "frec:importantes", texto = L["Consejos: solo importantes"] } },
		{ { valor = "bloquear", texto = bloqueado and L["Desbloquear posición"] or L["Bloquear posición"], icono = "ic-seguir" },
		  { valor = "vistos", texto = L["Volver a mostrar los consejos vistos"], icono = "ic-lista" },
		  { valor = "ajustes", texto = L["Ajustes de Lya"], icono = "ic-ajustes" },
		  { valor = "ocultar", texto = L["Ocultar a Lya"], icono = "ic-cerrar" } },
	}
	if Hi then
		local hist = grupos[2]
		if Hi.Modo() ~= "nunca" then hist[#hist + 1] = { valor = "dato", texto = L["Cuéntame algo de aquí"], icono = "ic-mundo" } end
		hist[#hist + 1] = { valor = "historias", texto = L["Historias de tus misiones"], icono = "ic-misiones" }
	end
	-- El menú muestra 10 filas sin desplazarse: las líneas entre grupos, mientras quepan.
	local n, hay = 0, 0
	for _, gr in ipairs(grupos) do if #gr > 0 then n = n + #gr hay = hay + 1 end end
	local lineas = max(0, min(hay - 1, 10 - n))
	local opciones = {}
	for _, gr in ipairs(grupos) do
		if #gr > 0 then
			if #opciones > 0 and lineas > 0 then
				opciones[#opciones + 1] = { separador = true }
				lineas = lineas - 1
			end
			for _, o in ipairs(gr) do opciones[#opciones + 1] = o end
		end
	end
	K.Menu(f, opciones, "frec:" .. Ce.Frecuencia(), function(v)
		if v == "silencio" then Ce.Silenciar(not silencio)
		elseif v == "dato" then Hi.Contar()
		elseif v == "historias" then Hi.Abrir()
		elseif v == "bloquear" then N.Set(ID, "bloqueado", not bloqueado)
		elseif v == "vistos" then Ce.OlvidarVistos()
		elseif v == "ajustes" then N.Abrir(ID)
		elseif v == "ocultar" then Ce.Mostrar(false)
		elseif type(v) == "string" and v:find("^frec:") then N.Set(ID, "frecuencia", v:sub(6))
		end
	end, 250)
end

---------------------------------------------------------------------------
-- Construir
---------------------------------------------------------------------------
local function lugar()
	local p = N.Get(ID, "pos")
	if type(p) ~= "table" or type(p[1]) ~= "string" then p = DEFAULT end
	f:ClearAllPoints()
	f:SetPoint(p[1], UIParent, p[1], tonumber(p[2]) or 0, tonumber(p[3]) or 0)
end

local function medir()
	local t = tam()
	f:SetSize(t, t)
	f.Cuerpo:SetSize(t - 2, t - 2)
	f.Salto1:SetOffset(0, floor(t * 0.16))
	f.Salto2:SetOffset(0, -floor(t * 0.16))
end

local function construirLya()
	f = CreateFrame("Button", "AlfaLyaLoba", K.Raiz()) -- no "AlfaLya": ese nombre es el contrato
	f:SetFrameStrata("MEDIUM")
	f:SetFrameLevel(30)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f:RegisterForDrag("LeftButton")
	f.caja = K.Caja(f, { fondo = "panel", borde = "acento", corte = K.CORTE.panel })

	f.Cuerpo = CreateFrame("Frame", nil, f)
	f.Cuerpo:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.Borde = f.Cuerpo:CreateTexture(nil, "ARTWORK", nil, 1)
	f.Borde:SetAllPoints(f.Cuerpo)
	f.Pelo = f.Cuerpo:CreateTexture(nil, "ARTWORK", nil, 2)
	f.Pelo:SetAllPoints(f.Cuerpo)

	-- Respirar: sube y baja un poco, en bucle.
	local r = f.Cuerpo:CreateAnimationGroup()
	r:SetLooping("BOUNCE")
	local t = r:CreateAnimation("Translation")
	t:SetOffset(0, 2)
	t:SetDuration(1.5)
	t:SetSmoothing("IN_OUT")
	f.Respirar, f.RespirarT = r, t

	-- Saltar: arriba y abajo, y uno chiquito.
	local s = f.Cuerpo:CreateAnimationGroup()
	local s1 = s:CreateAnimation("Translation")
	s1:SetOffset(0, 10) s1:SetDuration(0.16) s1:SetSmoothing("OUT") s1:SetOrder(1)
	local s2 = s:CreateAnimation("Translation")
	s2:SetOffset(0, -10) s2:SetDuration(0.18) s2:SetSmoothing("IN") s2:SetOrder(2)
	local s3 = s:CreateAnimation("Translation")
	s3:SetOffset(0, 4) s3:SetDuration(0.1) s3:SetSmoothing("OUT") s3:SetOrder(3)
	local s4 = s:CreateAnimation("Translation")
	s4:SetOffset(0, -4) s4:SetDuration(0.12) s4:SetSmoothing("IN") s4:SetOrder(4)
	s:SetScript("OnFinished", respirar)
	f.Salto, f.Salto1, f.Salto2 = s, s1, s2

	K.Pintar(f, pintarLya)
	medir()
	ponerTextura()

	f:SetScript("OnDragStart", function(self)
		if N.Get(ID, "bloqueado") or (A.DragLocked and A.DragLocked()) then return end
		self.alfaArrastre = true
		K.OcultarInfo(self)
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint(1)
		if point then N.Set(ID, "pos", { point, floor((x or 0) + 0.5), floor((y or 0) + 0.5) }) end
		lugar()
		K.Despues(0.05, function() self.alfaArrastre = nil end)
		if UI.Hablando() then UI.Acomodar() end
	end)
	f:SetScript("OnClick", function(self, boton)
		if self.alfaArrastre then return end
		K.OcultarInfo(self)
		if boton == "RightButton" then
			menu()
			return
		end
		if dormida then
			UI.Dormir(false)
			UI.Saltar()
		end
		M.Cerebro.Pedir()
	end)
	f:SetScript("OnEnter", function(self)
		local texto = N.Get(ID, "bloqueado") and L["Clic: un consejo. Clic derecho: mis opciones."]
			or L["Clic: un consejo. Clic derecho: mis opciones. Arrástrame para moverme."]
		K.MostrarInfo(self, L["Lya, la loba de confianza del Alfa"], texto)
	end)
	f:SetScript("OnLeave", function(self) K.OcultarInfo(self) end)
	f:SetScript("OnShow", function()
		respirar()
		if not dormida then programarParpadeo() end
	end)
	f:SetScript("OnHide", function()
		f.Respirar:Stop()
		f.Salto:Stop()
		turnoParpadeo = turnoParpadeo + 1
		UI.Callar(true)
	end)
	lugar()
	f:Hide()
end

---------------------------------------------------------------------------
-- El globo
---------------------------------------------------------------------------
local function clicBoton(b)
	local a = b.alfaAccion
	if not (actual and a) then return end
	UI.Callar()
	if type(a.fn) == "function" then K.Llamar(a.fn, f) end
end

local function construirGlobo()
	g = CreateFrame("Frame", "AlfaLyaGlobo", K.Raiz())
	g:SetFrameStrata("MEDIUM")
	g:SetFrameLevel(40)
	g:SetClampedToScreen(true)
	g:EnableMouse(true)
	g:SetSize(ANCHO_MIN, 48)
	g.caja = K.Caja(g, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.panel })
	g.Marca = K.Marca(g, K.CORTE.panel, "acento")
	g.Texto = K.Texto(g, "nota", "texto")
	g.Texto:SetJustifyH("LEFT")
	g.Cerrar = K.BotonIcono(g, "ic-cerrar", function() UI.Callar() end, { tam = 18, icono = 9, ayuda = L["Cerrar"] })
	g.Cerrar:SetPoint("TOPRIGHT", g, "TOPRIGHT", -4, -4)
	g.B1 = K.Boton(g, "", clicBoton, { tipo = "acento", tam = "chico" })
	g.B2 = K.Boton(g, "", clicBoton, { tipo = "fantasma", tam = "chico" })

	local entra = g:CreateAnimationGroup()
	local a1 = entra:CreateAnimation("Alpha")
	a1:SetFromAlpha(0) a1:SetToAlpha(1) a1:SetDuration(0.18) a1:SetSmoothing("OUT")
	g.Entra = entra
	local sale = g:CreateAnimationGroup()
	local a2 = sale:CreateAnimation("Alpha")
	a2:SetFromAlpha(1) a2:SetToAlpha(0) a2:SetDuration(0.35) a2:SetSmoothing("IN")
	sale:SetScript("OnFinished", function() g:Hide() g:SetAlpha(1) end)
	g.Sale = sale
	g:Hide()
end

local function ponerBoton(b, a)
	b.alfaAccion = a
	if not a then b:Hide() return 0 end
	b:SetTexto(a.texto or "")
	b:Show()
	return b:AnchoNatural()
end

-- Junto a Lya, del lado de la pantalla con más espacio.
function UI.Acomodar()
	if not (g and f) then return end
	g:ClearAllPoints()
	local x = f:GetCenter()
	local w = UIParent and UIParent:GetWidth()
	if type(x) == "number" and type(w) == "number" and x > w / 2 then
		g:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", -6, -floor(tam() * 0.35))
	else
		g:SetPoint("BOTTOMLEFT", f, "TOPRIGHT", 6, -floor(tam() * 0.35))
	end
end

local function vencer(mio)
	if mio ~= turnoGlobo or not (g and g:IsShown()) then return end
	if g:IsMouseOver() or (f and f:IsMouseOver()) then
		K.Despues(2, function() vencer(mio) end)
		return
	end
	UI.Callar()
end

function UI.Hablar(c)
	if not f then return end
	if not g then construirGlobo() end
	actual = c
	turnoGlobo = turnoGlobo + 1
	local mio = turnoGlobo
	g.Sale:Stop()
	g:SetAlpha(1)

	local acciones = type(c.acciones) == "table" and c.acciones or {}
	local w1 = ponerBoton(g.B1, acciones[1])
	local w2 = ponerBoton(g.B2, acciones[2])
	K.Escribir(g.Texto, K.Tenir(K.Clasico() and "oro" or "acento", L["Lya"] .. ":") .. " " .. (c.texto or ""))
	local botones = w1 + (w2 > 0 and w2 + 6 or 0)
	local natural = K.AnchoTexto(g.Texto) + 2 * PAD + 16
	-- Un dato curioso pide un globo un poco más ancho y alto (c.ancho, c.lineas).
	local tope = max(ANCHO_MAX, min(420, tonumber(c.ancho) or ANCHO_MAX))
	local ancho = max(ANCHO_MIN, min(tope, natural), botones + 2 * PAD)
	ancho = min(tope + 40, ancho)
	g:SetWidth(ancho)
	local y = PAD
	g.Texto:ClearAllPoints()
	g.Texto:SetPoint("TOPLEFT", g, "TOPLEFT", PAD, -y)
	y = y + K.Parrafo(g.Texto, ancho - 2 * PAD - 14, max(3, min(6, tonumber(c.lineas) or 3)))
	if w1 > 0 then
		y = y + 8
		g.B1:ClearAllPoints()
		g.B1:SetPoint("TOPLEFT", g, "TOPLEFT", PAD, -y)
		if w2 > 0 then
			g.B2:ClearAllPoints()
			g.B2:SetPoint("LEFT", g.B1, "RIGHT", 6, 0)
		end
		y = y + K.ALTO.botonChico
	end
	g:SetHeight(y + PAD)
	UI.Acomodar()
	local estaba = g:IsShown()
	g:Show()
	if not estaba then g.Entra:Stop() g.Entra:Play() end

	-- La cara: atenta si pide algo, el aullido en una celebración (al hablar
	-- abre los ojos: se olvida un parpadeo o un aullido de antes).
	UI.Dormir(false)
	turnoMomento = turnoMomento + 1
	momento = nil
	if c.aullar then
		UI.Aullar()
	else
		if c.cara == "atenta" or w1 > 0 then cara = "atenta" else cara = "normal" end
		ponerTextura()
		if c.salto then UI.Saltar() end
	end
	if N.Get(ID, "sonido") and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
		pcall(A.PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
	end
	local secs = tonumber(c.segundos) or 8
	if w1 > 0 then secs = secs + 4 end
	K.Despues(secs, function() vencer(mio) end)
end

-- Se calla (con su fundido; ya = sin fundido).
function UI.Callar(ya)
	actual = nil
	turnoGlobo = turnoGlobo + 1
	if f and cara == "atenta" then
		cara = "normal"
		ponerTextura()
	end
	if not (g and g:IsShown()) then return end
	if ya then
		g.Sale:Stop()
		g:Hide()
		g:SetAlpha(1)
	else
		g.Sale:Play()
	end
end

---------------------------------------------------------------------------
-- Mostrar u ocultar
---------------------------------------------------------------------------
function UI.Aplicar()
	local ver = M.Cerebro and M.Cerebro.Activa() or false
	if ver and not f then construirLya() end
	if not f then return end
	medir()
	lugar()
	f:SetShown(ver)
end

-- Un ajuste cambió: el tamaño, el lugar o el estilo del borde.
A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" or not f then return end
	if path == ID .. ".tamano" or path == ID .. ".pos" or path == ID or path == "" then
		medir()
		lugar()
		if UI.Hablando() then UI.Acomodar() end
	end
end)
