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

K.BANDOS = {
	H = { letra = "H", clave = "horda", nombre = "la Horda", titulo = "La Horda",
		color = { 0.80, 0.18, 0.13 }, metal = { 0.87, 0.60, 0.30 }, oscuro = { 0.16, 0.06, 0.05 },
		emblema = MEDIA .. "bando-horda", adorno = MEDIA .. "adorno-horda", esquina = MEDIA .. "esquina-horda" },
	A = { letra = "A", clave = "alianza", nombre = "la Alianza", titulo = "La Alianza",
		color = { 0.23, 0.47, 0.88 }, metal = { 0.96, 0.80, 0.36 }, oscuro = { 0.05, 0.08, 0.17 },
		emblema = MEDIA .. "bando-alianza", adorno = MEDIA .. "adorno-alianza", esquina = MEDIA .. "esquina-alianza" },
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
	b.emblema:SetSize(22, 22)
	v.alfaBando = b
	return b
end

function K.AdornarBando(v)
	if not (v and v.Cabecera) then return end
	local t = K.Bando()
	local b = v.alfaBando
	if not t then
		if b then
			b.tira:Hide() b.e1:Hide() b.e2:Hide() b.emblema:Hide()
			if v.Cabecera.Linea then v.Cabecera.Linea:Show() end
		end
		v.alfaTemaBando = nil
		return
	end
	b = b or armar(v)
	b.tira:Pintar(t)
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
	s.alfaTema = t and t.clave or nil
	return s
end

-- La ventana de Alfa (la del motor): su sello en cuanto existe.
local function selloVentanaAlfa()
	local O = A and A.UI and A.UI.Options
	local v = O and O.frame
	if v and not v.alfaSello then
		K.SelloBando(v, { esquinas = true })
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
			{ texto = L["No, gracias"], alClic = function() N.Datos("kit").bandoElegido = true end },
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
end

if A and A.On then
	A.On("SETTING_CHANGED", function(path)
		if path == "nucleo.bando" then
			adornarTodas()
			if N.PidioJugador and N.PidioJugador() then N.Datos("kit").bandoElegido = true end
		elseif path == "nucleo.temporada" then
			adornarTodas() -- el emblema se hace a un lado del adorno de temporada
		end
	end)
end

if A and A.OnLogin then
	A.OnLogin(function()
		adornarTodas()
	end)
end
