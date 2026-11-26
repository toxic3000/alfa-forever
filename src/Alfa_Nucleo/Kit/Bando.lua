-- Alfa - Kit: la temática por bando (1.3.9, pedido de Toxic). GPL-3.0.
-- toxic3000 / La Jauría.
--
-- Alfa se viste según tu facción, si quieres (nucleo.bando, apagado de
-- fábrica; Alfa lo pregunta una vez con un aviso, la primera vez que abres
-- la ventana de Alfa con un clic, nunca al entrar):
--   la Horda    rojo y bronce, el emblema de la Horda, madera y hierro
--   la Alianza  azul y oro, el emblema de la Alianza, piedra y plata
-- Los emblemas y adornos son dibujos propios (tools/bandos.py), no arte de
-- Blizzard. Se aplica sobre cualquier estilo (no cambia letras ni el acento
-- que elegiste):
--   * el marco de cada ventana del Kit: la línea de la cabecera se vuelve la
--     tira del bando, una escuadra en las dos esquinas sin corte y el emblema
--     chico en la cabecera (K.AdornarBando);
--   * la tarjeta del viaje de la flecha (motor/Alfa/Nav/Arrow.lua);
--   * los anuncios (Kit/Anuncio.lua: K.Anuncio usa K.Bando() para su halo,
--     su línea y su emblema);
--   * Hoy (una tira del bando arriba de la portada, K.TiraBando) y el
--     marcador de La Jauría (Alfa_Manada/Marcador.lua, siempre con los dos).
--
--   K.BANDOS.H / K.BANDOS.A -> { letra, clave, nombre, color, metal, oscuro, emblema, adorno, esquina }
--   K.TemaBando(letra)  el tema de "H" o "A" (también "Horde"/"Alliance")
--   K.BandoMio()        el de tu facción, aunque la temática esté apagada
--   K.Bando()           el de tu facción solo si la temática está prendida
--   K.AdornarBando(v)   viste (o desviste) una ventana
--   K.TiraBando(padre)  una tira del bando (madera o piedra) para una cabecera
--   K.PreguntarBando()  la pregunta de una vez
--   N.FilasBando(grupo) la fila de Estilo y sonido
-- En el banco: K.bandoPrueba = "H" | "A" cambia de facción sin recargar.

local _, N = ...
local K = N.Kit
local A = N.A
local L = K.L

local type, ipairs = type, ipairs
local MEDIA = "Interface\\AddOns\\Alfa_Nucleo\\Media\\"

-- 1.4.0 (67): la paleta de cada bando. color = el acento (rojo sangre / azul
-- real), metal = bronce / oro, fierro = hierro / plata, base = madera / piedra.
K.BANDOS = {
	H = { letra = "H", clave = "horda", nombre = "la Horda", titulo = "La Horda",
		color = { 0.80, 0.16, 0.12 }, metal = { 0.87, 0.60, 0.30 }, fierro = { 0.44, 0.41, 0.39 },
		base = { 0.36, 0.22, 0.13 }, oscuro = { 0.16, 0.06, 0.05 },
		emblema = MEDIA .. "bando-horda", adorno = MEDIA .. "adorno-horda", esquina = MEDIA .. "esquina-horda",
		cabecera = MEDIA .. "cabecera-horda", cabeceraIzq = MEDIA .. "cabecera-horda-izq",
		estandarte = MEDIA .. "estandarte-horda",
		saludo = "¡Lok'tar, %s!", lema = "La Horda caza contigo hoy. Fuerza y honor.",
		-- Un cuerno de guerra del propio juego (el de la bandera de la Horda).
		sonido = 8212 },
	A = { letra = "A", clave = "alianza", nombre = "la Alianza", titulo = "La Alianza",
		color = { 0.20, 0.42, 0.88 }, metal = { 0.96, 0.80, 0.36 }, fierro = { 0.80, 0.82, 0.88 },
		base = { 0.42, 0.44, 0.50 }, oscuro = { 0.05, 0.08, 0.17 },
		emblema = MEDIA .. "bando-alianza", adorno = MEDIA .. "adorno-alianza", esquina = MEDIA .. "esquina-alianza",
		cabecera = MEDIA .. "cabecera-alianza", cabeceraIzq = MEDIA .. "cabecera-alianza-izq",
		estandarte = MEDIA .. "estandarte-alianza",
		saludo = "¡Por la Alianza, %s!", lema = "La Alianza camina contigo hoy. Luz y valor.",
		-- La trompeta del juego (la de la bandera de la Alianza).
		sonido = 8174 },
}

if A and A.RegisterDefaults then A.RegisterDefaults("nucleo", { bando = false }) end

function K.TemaBando(l)
	if l == "Horde" then l = "H" elseif l == "Alliance" then l = "A" end
	return K.BANDOS[l]
end

function K.BandoMio()
	if K.bandoPrueba then return K.TemaBando(K.bandoPrueba) end
	local l = N.FaccionLetra and N.FaccionLetra()
	return l and K.BANDOS[l] or nil
end

function K.Bando()
	if not (A and A.Get and A.Get("nucleo.bando")) then return nil end
	return K.BandoMio()
end

-- Un color del bando como texto con su código: K.HexBando(t, "metal").
function K.HexBando(t, cual)
	local c = t and t[cual or "color"]
	if not c then return "|cffffffff" end
	return ("|cff%02x%02x%02x"):format(c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5)
end

---------------------------------------------------------------------------
-- 1.4.0 (67): la paleta del bando, aplicada de verdad. Un retoque del tema
-- (Theme.Retoque): el acento (botones principales, pestaña activa, barras,
-- íconos, la flecha, Lya y el rastreador) pasa al color del bando, llevado
-- hasta que se lea (4.5:1, 7:1 con alto contraste); el borde de las ventanas
-- al metal; las líneas de las tarjetas, un poco hacia el metal. Tu color de
-- borde y el de la flecha, si los elegiste, mandan. Daltonismo sigue igual
-- (no toca bien, aviso, peligro ni perjuicios).
---------------------------------------------------------------------------
local function mezcla(c, d, t, a)
	return { c[1] + (d[1] - c[1]) * t, c[2] + (d[2] - c[2]) * t, c[3] + (d[3] - c[3]) * t, a or c[4] or 1 }
end
local function esColor(c) return type(c) == "table" and type(c[1]) == "number" end

-- El acento de un bando sobre unos fondos. -> { r, g, b, 1 }
function K.AcentoBando(t, fondos)
	if not t then return nil end
	local min = K.AltoContraste and K.AltoContraste() and 7 or 4.5
	if K.Legible then return K.Legible(t.color, fondos or {}, min) end
	return { t.color[1], t.color[2], t.color[3], 1 }
end

local function retocar(out)
	local t = K.Bando()
	if not t then return end
	local fondos = { out.bg, out.panel, out.panelAlt }
	local ac = K.AcentoBando(t, fondos)
	out.accent = ac
	local r, g, b = ac[1], ac[2], ac[3]
	local Th = A and A.Theme
	if Th and Th.Contrast and esColor(out.text) then
		local tinta = { 0.06, 0.04, 0.03, 1 }
		out.onAccent = (Th.Contrast(tinta, ac) >= Th.Contrast(out.text, ac)) and tinta
			or { out.text[1], out.text[2], out.text[3], 1 }
	end
	local fuerte = K.AltoContraste and K.AltoContraste()
	out.accentLine = { r, g, b, fuerte and 0.6 or 0.35 }
	out.padSelect = { r, g, b, fuerte and 0.22 or 0.14 }
	out.chipAccent = { r, g, b, fuerte and 0.28 or 0.18 }
	local get = A and A.Get
	local m = t.metal
	if not (get and esColor(get("ui.borderColor"))) then out.windowBorder = { m[1], m[2], m[3], 0.85 } end
	if not fuerte then
		if esColor(out.line) then out.line = mezcla(out.line, m, 0.18) end
		if esColor(out.lineStrong) then out.lineStrong = mezcla(out.lineStrong, m, 0.38) end
		if esColor(out.border) then out.border = mezcla(out.border, m, 0.18) end
	end
	if not (get and esColor(get("nav.arrowColor"))) then
		out.arrow = { r, g, b, 1 }
		out.arrowText = { r, g, b, 1 }
	end
end
if A and A.Theme and A.Theme.Retoque then A.Theme.Retoque(retocar) end

-- En el banco: cambia de bando sin recargar y repinta todo.
function K.ProbarBando(l)
	K.bandoPrueba = l
	if A and A.Theme and A.Theme.Refresh then A.Theme.Refresh() end
	if K.AdornarBandoTodas then K.AdornarBandoTodas() end
end

-- El saludo y el lema de tu bando (Hoy). -> saludo, lema | nil
function K.SaludoBando(nombre, t)
	t = t or K.Bando()
	if not t then return nil end
	local SALUDOS = {
		H = { L["¡Lok'tar, %s!"], L["La Horda caza contigo hoy. Fuerza y honor."] },
		A = { L["¡Por la Alianza, %s!"], L["La Alianza camina contigo hoy. Luz y valor."] },
	}
	local s = SALUDOS[t.letra]
	if not s then return nil end
	local quien = type(nombre) == "string" and nombre ~= "" and nombre or L["lobo"]
	return (s[1]):format(quien), s[2]
end

-- El sonido del bando (al prender la temática y en la vista previa).
function K.SonarBando(t, siempre)
	t = t or K.BandoMio()
	if not (t and t.sonido) then return false end
	if siempre then
		if PlaySound then pcall(PlaySound, t.sonido, "SFX") end
		return true
	end
	return N.SonarId and N.SonarId(nil, t.sonido, "bando", 3) or false
end

---------------------------------------------------------------------------
-- Una tira del bando (madera y hierro, o piedra y plata).
---------------------------------------------------------------------------
function K.TiraBando(padre, alto, capa)
	local t = padre:CreateTexture(nil, capa or "ARTWORK", nil, 3)
	t:SetHeight(alto or 4)
	t:Hide()
	function t:Pintar(tema)
		tema = tema or K.Bando()
		if not tema then self:Hide() return false end
		self:SetTexture(tema.adorno)
		self:SetVertexColor(1, 1, 1, 1)
		self:Show()
		return true
	end
	return t
end

---------------------------------------------------------------------------
-- El marco de las ventanas del Kit.
---------------------------------------------------------------------------
local function armar(v)
	local c = v.Cabecera
	local b = {}
	b.tira = K.TiraBando(v, 4, "ARTWORK")
	b.tira:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, -1)
	b.tira:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, -1)
	-- Las escuadras: arriba a la derecha y abajo a la izquierda (las dos
	-- esquinas sin corte del diseño de Alfa).
	b.e1 = v:CreateTexture(nil, "OVERLAY", nil, 2)
	b.e1:SetSize(22, 22)
	b.e1:SetPoint("TOPRIGHT", v, "TOPRIGHT", 0, 0)
	b.e1:SetTexCoord(1, 0, 0, 1)
	b.e2 = v:CreateTexture(nil, "OVERLAY", nil, 2)
	b.e2:SetSize(22, 22)
	b.e2:SetPoint("BOTTOMLEFT", v, "BOTTOMLEFT", 0, 0)
	b.e2:SetTexCoord(0, 1, 1, 0)
	b.emblema = c:CreateTexture(nil, "ARTWORK", nil, 3)
	b.emblema:SetSize(28, 28)
	-- 1.4.0 (67): la cabecera con su textura (madera y hierro / piedra y
	-- plata): la tapa izquierda lleva el corte de Alfa y el resto se estira.
	-- Debajo del ícono y del título (BACKGROUND de la cabecera).
	local alto = K.ALTO.cabecera
	b.cabIzq = c:CreateTexture(nil, "BACKGROUND", nil, 1)
	b.cabIzq:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	b.cabIzq:SetSize(alto, alto)
	b.cab = c:CreateTexture(nil, "BACKGROUND", nil, 1)
	b.cab:SetPoint("TOPLEFT", c, "TOPLEFT", alto, 0)
	b.cab:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
	v.alfaBando = b
	return b
end

function K.AdornarBando(v)
	if not (v and v.Cabecera) then return end
	local t = K.Bando()
	local b = v.alfaBando
	if not t then
		if b then
			b.tira:Hide() b.e1:Hide() b.e2:Hide() b.emblema:Hide() b.cab:Hide() b.cabIzq:Hide()
			if v.Cabecera.Linea then v.Cabecera.Linea:Show() end
		end
		v.alfaTemaBando = nil
		return
	end
	b = b or armar(v)
	-- La textura de la cabecera (en Clásico WoW, el marco del juego manda:
	-- solo la tira de abajo).
	local conCab = not (K.Clasico and K.Clasico())
	if conCab then
		b.cab:SetTexture(t.cabecera)
		b.cabIzq:SetTexture(t.cabeceraIzq)
		-- En Cristal, un poco transparente (se ve el mundo, como el resto).
		local a = (K.Cristal and K.Cristal()) and 0.82 or 1
		b.cab:SetVertexColor(1, 1, 1, a)
		b.cabIzq:SetVertexColor(1, 1, 1, a)
	end
	b.cab:SetShown(conCab)
	b.cabIzq:SetShown(conCab)
	if conCab then b.tira:Hide() else b.tira:Pintar(t) end
	if v.Cabecera.Linea then v.Cabecera.Linea:Hide() end
	for _, e in ipairs({ b.e1, b.e2 }) do
		e:SetTexture(t.esquina)
		e:SetVertexColor(1, 1, 1, 0.95)
		e:Show()
	end
	b.emblema:SetTexture(t.emblema)
	b.emblema:ClearAllPoints()
	-- A la izquierda del adorno de temporada si lo hay, si no, de la X.
	local temp = v.Cabecera.alfaAdorno and v.Cabecera.alfaAdorno:IsShown()
	b.emblema:SetPoint("RIGHT", v.Cabecera, "RIGHT", temp and -72 or -46, 0)
	b.emblema:Show()
	v.alfaTemaBando = t.clave
end

---------------------------------------------------------------------------
-- El sello: lo mismo para un marco que no es ventana del Kit (la ventana de
-- Alfa, la página Hoy). Encima, sin tocar su acomodo ni tomar el ratón:
--   opts.tira      la tira arriba (de fábrica sí)
--   opts.esquinas  las escuadras (de fábrica no)
--   opts.marca     el emblema grande y tenue arriba a la derecha (tamaño) o nil
---------------------------------------------------------------------------
local SELLOS = {}
function K.SelloBando(marco, opts)
	if not marco then return end
	opts = opts or {}
	local s = marco.alfaSello
	if not s then
		s = CreateFrame("Frame", nil, marco)
		s:SetAllPoints(marco)
		s:EnableMouse(false)
		s:SetFrameLevel((marco.GetFrameLevel and marco:GetFrameLevel() or 1) + (opts.nivel or 8))
		s.opts = opts
		if opts.tira ~= false then
			s.tira = K.TiraBando(s, opts.altoTira or 3, "OVERLAY")
			s.tira:SetPoint("TOPLEFT", s, "TOPLEFT", opts.dentro or 1, -(opts.dentro or 1))
			s.tira:SetPoint("TOPRIGHT", s, "TOPRIGHT", -(opts.dentro or 1), -(opts.dentro or 1))
		end
		if opts.esquinas then
			s.e1 = s:CreateTexture(nil, "OVERLAY", nil, 2)
			s.e1:SetSize(20, 20)
			s.e1:SetPoint("TOPRIGHT", s, "TOPRIGHT", 0, 0)
			s.e1:SetTexCoord(1, 0, 0, 1)
			s.e2 = s:CreateTexture(nil, "OVERLAY", nil, 2)
			s.e2:SetSize(20, 20)
			s.e2:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", 0, 0)
			s.e2:SetTexCoord(0, 1, 1, 0)
		end
		if opts.marca then
			s.marca = s:CreateTexture(nil, "BACKGROUND")
			s.marca:SetSize(opts.marca, opts.marca)
			s.marca:SetPoint("TOPRIGHT", s, "TOPRIGHT", opts.marcaX or -10, opts.marcaY or -10)
		end
		-- 1.4.0 (67): el estandarte grande y muy tenue. Las páginas de la
		-- ventana de Alfa son opacas: va encima, como una marca de agua (no toma
		-- el ratón y es tan tenue que el texto se lee igual).
		if opts.estandarte then
			local e = opts.estandarte
			s.estandarte = s:CreateTexture(nil, "BACKGROUND", nil, 6)
			s.estandarte:SetSize(e.ancho or 150, (e.ancho or 150) * 2)
			s.estandarte:SetPoint(e.punto or "TOPRIGHT", marco, e.punto or "TOPRIGHT", e.x or -24, e.y or -48)
		end
		marco.alfaSello = s
		SELLOS[#SELLOS + 1] = marco
	end
	local t = K.Bando()
	if s.tira then s.tira:Pintar(t) end
	for _, e in ipairs({ s.e1, s.e2 }) do
		if t then e:SetTexture(t.esquina) e:SetVertexColor(1, 1, 1, 0.95) end
		e:SetShown(t ~= nil)
	end
	if s.marca then
		if t then s.marca:SetTexture(t.emblema) s.marca:SetVertexColor(1, 1, 1, s.opts.alfaMarca or 0.12) end
		s.marca:SetShown(t ~= nil)
	end
	if s.estandarte then
		if t then
			s.estandarte:SetTexture(t.estandarte)
			s.estandarte:SetVertexColor(1, 1, 1, (s.opts.estandarte and s.opts.estandarte.alfa) or 0.1)
		end
		s.estandarte:SetShown(t ~= nil)
	end
	s.alfaTema = t and t.clave or nil
	return s
end

-- La ventana de Alfa (la del motor): su sello en cuanto existe.
local function selloVentanaAlfa()
	local O = A and A.UI and A.UI.Options
	local v = O and O.frame
	if v and not v.alfaSello then
		-- 1.4.0 (67): con el estandarte del bando colgado al fondo, a la derecha.
		K.SelloBando(v, { esquinas = true, nivel = 30, estandarte = { ancho = 170, punto = "BOTTOMRIGHT", x = -36, y = 70, alfa = 0.05 } })
		-- La pregunta de una vez: cuando TÚ abres la ventana de Alfa (nunca al
		-- entrar al juego, que es la entrada en silencio de la 1.3.3).
		if v.HookScript then
			v:HookScript("OnShow", function()
				if N.PidioJugador and N.PidioJugador() and N.Una then
					N.Una("kit.bando", 2, function() pcall(K.PreguntarBando) end, { fueraDeCombate = true })
				end
			end)
		end
	elseif v then
		K.SelloBando(v)
	end
end

K.SelloVentanaAlfa = function() pcall(selloVentanaAlfa) end

local function adornarTodas()
	for _, v in ipairs(K.VENTANAS or {}) do K.AdornarBando(v) end
	for _, m in ipairs(SELLOS) do K.SelloBando(m) end
	pcall(selloVentanaAlfa)
	if K.Repintar then pcall(K.Repintar) end
	if A and A.Fire then pcall(A.Fire, "ALFA_BANDO", K.Bando()) end
end
K.AdornarBandoTodas = adornarTodas

-- 1.4.0 (67): las ventanas propias que no son K.Ventana (Bolsas y banco, que
-- se anotan con K.ConEscala) llevan el sello: la tira arriba y las escuadras.
if type(K.ConEscala) == "function" and not K.alfaEscalaBando then
	local conEscala = K.ConEscala
	K.alfaEscalaBando = true
	function K.ConEscala(v)
		conEscala(v)
		if v and v.GetObjectType then pcall(K.SelloBando, v, { esquinas = true, altoTira = 4 }) end
	end
end

-- Cada ventana nueva nace vestida.
if type(K.Ventana) == "function" and not K.alfaVentanaBando then
	local crear = K.Ventana
	K.alfaVentanaBando = true
	function K.Ventana(opts)
		local v = crear(opts)
		K.AdornarBando(v)
		return v
	end
end

---------------------------------------------------------------------------
-- 1.4.0 (67): la vista previa de los dos bandos. Una tarjeta por bando con
-- su cabecera, su emblema, su saludo, un botón principal y una barra en sus
-- colores, sin tocar tus ajustes; abajo, prender o quitar la temática (el
-- cambio se ve al instante en todo Alfa) y escuchar su sonido.
--   K.TarjetaBando(padre, letra, ancho)   una tarjeta
--   K.VistaBandos()                       la ventana con las dos
---------------------------------------------------------------------------
local ALTO_TARJETA = 206

function K.TarjetaBando(padre, l, ancho)
	local t = K.TemaBando(l)
	ancho = ancho or 240
	local f = CreateFrame("Frame", nil, padre)
	f:SetSize(ancho, ALTO_TARJETA)
	f.tema = t
	f.Borde = K.Plano(f, t.metal, "BACKGROUND", 0)
	f.Borde:SetAllPoints(f)
	f.Fondo = K.Plano(f, "panel", "BACKGROUND", 1)
	f.Fondo:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.Fondo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.Estandarte = f:CreateTexture(nil, "BACKGROUND", nil, 3)
	f.Estandarte:SetTexture(t.estandarte)
	f.Estandarte:SetSize(64, 128)
	f.Estandarte:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 26)
	f.Estandarte:SetVertexColor(1, 1, 1, 0.16)
	local H = 40
	f.CabIzq = f:CreateTexture(nil, "BORDER", nil, 0)
	f.CabIzq:SetTexture(t.cabeceraIzq)
	f.CabIzq:SetSize(H, H)
	f.CabIzq:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.Cab = f:CreateTexture(nil, "BORDER", nil, 0)
	f.Cab:SetTexture(t.cabecera)
	f.Cab:SetPoint("TOPLEFT", f, "TOPLEFT", 1 + H, -1)
	f.Cab:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -1, -1 - H)
	f.Emblema = f:CreateTexture(nil, "ARTWORK")
	f.Emblema:SetTexture(t.emblema)
	f.Emblema:SetSize(30, 30)
	f.Emblema:SetPoint("RIGHT", f.Cab, "RIGHT", -8, 0)
	f.Titulo = K.Texto(f, "subtitulo", "texto")
	f.Titulo:SetPoint("LEFT", f, "TOPLEFT", 14, -1 - H / 2)
	K.Escribir(f.Titulo, L[t.titulo])
	local x = 14
	local ac = K.AcentoBando(t, { { K.Color("panel") } })
	f.Saludo = K.Texto(f, "subtitulo", ac)
	f.Saludo:SetPoint("TOPLEFT", f, "TOPLEFT", x, -H - 14)
	f.Saludo:SetWidth(ancho - 2 * x)
	local nombre = UnitName and UnitName("player")
	if issecretvalue and issecretvalue(nombre) then nombre = nil end
	local saludo, lema = K.SaludoBando(nombre, t)
	K.Escribir(f.Saludo, saludo or "")
	f.Lema = K.Texto(f, "nota", "textoSuave")
	f.Lema:SetPoint("TOPLEFT", f.Saludo, "BOTTOMLEFT", 0, -6)
	f.Lema:SetWidth(ancho - 2 * x - 56)
	f.Lema:SetWordWrap(true)
	K.Escribir(f.Lema, lema or "")
	-- Un botón principal y una barra de avance, en sus colores.
	f.Boton = K.Plano(f, ac, "ARTWORK", 0)
	f.Boton:SetSize(104, 28)
	f.Boton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 42)
	local Th = A and A.Theme
	local tinta = { 0.06, 0.04, 0.03, 1 }
	local sobre = (Th and Th.Contrast and Th.Contrast(tinta, ac) < Th.Contrast({ 1, 1, 1, 1 }, ac)) and { 1, 1, 1, 1 } or tinta
	f.BotonTexto = K.Texto(f, "boton", sobre)
	f.BotonTexto:SetPoint("CENTER", f.Boton, "CENTER", 0, 0)
	K.Escribir(f.BotonTexto, L["Seguir"])
	local largo = (ancho - 2 * x) * 0.6
	f.Pista = K.Plano(f, { t.fierro[1], t.fierro[2], t.fierro[3], 0.35 }, "ARTWORK", 0)
	f.Pista:SetSize(largo, 6)
	f.Pista:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 22)
	f.Barra = K.Plano(f, ac, "ARTWORK", 1)
	f.Barra:SetSize(largo * 0.66, 6)
	f.Barra:SetPoint("LEFT", f.Pista, "LEFT", 0, 0)
	-- Tu bando lleva su marca.
	local mio = K.BandoMio()
	f.Tuyo = K.Texto(f, "pequeno", t.metal)
	f.Tuyo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 8)
	K.Escribir(f.Tuyo, L["Tu bando"])
	f.Tuyo:SetShown(mio ~= nil and mio.letra == l)
	return f
end

local vista
function K.PintarVistaBandos()
	if not vista then return end
	local on = A and A.Get and A.Get("nucleo.bando")
	vista.Prender:SetTexto(on and L["Quitar la temática"] or L["Vestir a Alfa de mi bando"])
	vista.Prender:SetIcono(on and "ic-cerrar" or "ic-apariencia")
	vista:SetPie({ vista.Prender }, { vista.Cerrar_, vista.Escuchar })
	K.Mostrar(vista.Escuchar, K.BandoMio() ~= nil)
end

function K.VistaBandos()
	if not vista then
		local ANCHO = 580
		local v = K.Ventana({ nombre = "AlfaVistaBandos", titulo = L["Tu bando en Alfa"],
			subtitulo = L["Así se ven la Horda y la Alianza"], icono = "ic-apariencia", ancho = ANCHO, alto = 390 })
		v:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		v.Nota = K.Texto(v.Cuerpo, "nota", "textoSuave")
		v.Nota:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -14)
		v.Nota:SetWidth(ANCHO - 2 * v.margen)
		v.Nota:SetWordWrap(true)
		K.Escribir(v.Nota, L["Así se vería Alfa con cada bando. Al prenderla, Alfa se viste del tuyo al instante."])
		local ancho = math.floor((ANCHO - 2 * v.margen - 16) / 2)
		v.H = K.TarjetaBando(v.Cuerpo, "H", ancho)
		v.H:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -46)
		v.A = K.TarjetaBando(v.Cuerpo, "A", ancho)
		v.A:SetPoint("TOPLEFT", v.H, "TOPRIGHT", 16, 0)
		v.Prender = K.Boton(v, L["Vestir a Alfa de mi bando"], function()
			if A and A.Set then
				N.Datos("kit").bandoElegido = true
				A.Set("nucleo.bando", not A.Get("nucleo.bando"))
			end
			K.PintarVistaBandos()
		end, { tipo = "primario", icono = "ic-apariencia" })
		v.Escuchar = K.Boton(v, L["Escuchar"], function() K.SonarBando(nil, true) end, { tipo = "fantasma", icono = "ic-lobo" })
		v.Cerrar_ = K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "fantasma" })
		vista = v
	end
	vista:Abrir()
	K.PintarVistaBandos()
	return vista
end
function K.VistaBandosUI() return vista end

---------------------------------------------------------------------------
-- La pregunta de una vez y la fila de Estilo y sonido.
---------------------------------------------------------------------------
function K.PreguntarBando()
	if A and A.Get and A.Get("nucleo.bando") then return false end
	local t = K.BandoMio()
	if not t then return false end
	local d = N.Datos("kit")
	if d.bandoPreguntado or d.bandoElegido then return false end
	d.bandoPreguntado = true
	if not K.Aviso then return false end
	K.Aviso({ titulo = L["¿Vestimos a Alfa de tu bando?"], icono = "ic-apariencia", tono = "acento", prioridad = 4,
		texto = (L["Los colores, el emblema y los adornos de %s en las ventanas, los anuncios, Hoy y el marcador de La Jauría. Lo cambias en Estilo y sonido."]):format(L[t.nombre]),
		acciones = {
			{ texto = L["Sí, vístelo"], alClic = function()
				N.Datos("kit").bandoElegido = true
				if A.Set then A.Set("nucleo.bando", true) end
			end },
			-- 1.4.0 (67): verlo antes de decidir (los avisos llevan dos botones:
			-- «No» es cerrarlo; la vista previa también la quita o la pone).
			{ texto = L["Ver cómo se ve"], alClic = function() K.VistaBandos() end },
		} })
	return true
end

function N.FilasBando(grupo)
	if not (grupo and grupo.Fila) then return end
	local t = K.BandoMio()
	grupo:Fila({ titulo = L["Temática de tu bando"],
		texto = t and (L["Alfa se viste de %s: colores, emblema y adornos en las ventanas, los anuncios, Hoy y el marcador."]):format(L[t.nombre])
			or L["Alfa se viste de tu bando: colores, emblema y adornos en las ventanas, los anuncios, Hoy y el marcador."],
		control = function(fila) return K.Interruptor(fila, { clave = "nucleo.bando" }) end })
	-- 1.4.0 (67): la vista previa de los dos bandos.
	grupo:Fila({ titulo = L["Así se ven los dos bandos"], hija = true,
		texto = L["La Horda en rojo sangre, bronce, hierro y madera; la Alianza en azul real, oro, plata y piedra."],
		control = function(fila) return K.Boton(fila, L["Ver"], function() K.VistaBandos() end, { tipo = "secundario", icono = "ic-apariencia" }) end })
end

if A and A.On then
	A.On("SETTING_CHANGED", function(path)
		if path == "nucleo.bando" then
			adornarTodas()
			if N.PidioJugador and N.PidioJugador() then
				N.Datos("kit").bandoElegido = true
				-- Al prenderla tú, el sonido de tu bando (una vez).
				if A.Get("nucleo.bando") then K.SonarBando() end
			end
			K.PintarVistaBandos()
		elseif path == "nucleo.temporada" then
			adornarTodas() -- el emblema se hace a un lado del adorno de temporada
		end
	end)
end

-- 1.4.0 (67): al cambiar de estilo (Clásico WoW lleva el marco del juego en
-- la cabecera), cada ventana se viste otra vez.
if K.AlRepintar then
	K.AlRepintar(function()
		for _, v in ipairs(K.VENTANAS or {}) do K.AdornarBando(v) end
	end)
end

if A and A.OnLogin then
	A.OnLogin(function()
		adornarTodas()
	end)
end
