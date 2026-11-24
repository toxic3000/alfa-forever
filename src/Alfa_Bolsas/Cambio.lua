-- Alfa - Bolsas: cambiar de equipo con un clic (toxic3000 / La Jauría).
-- GPL-3.0. 1.3.7.
--
-- Junto a la ventana de tu personaje, un botón pequeño por cada conjunto
-- guardado (Conjuntos.lua). Fuera de combate te pone todo. En combate el
-- juego solo deja cambiar las armas, y solo con un botón seguro: cada botón es
-- un SecureActionButton con un macro «/equipslot 16 item:ID» (mano derecha,
-- izquierda y a distancia) preparado ANTES del combate (los atributos nunca se
-- tocan en combate); lo demás se pone al terminar (N.FueraDeCombate, desde
-- Cj.Poner). Clic derecho: «Ponérmelo al salir de cada combate» (por
-- personaje, N.DatosPersonaje("bolsas").alSalir).
-- La barra se muestra, se esconde y se rehace solo fuera de combate: si la
-- ventana de tu personaje se cierra en combate, los botones se van al terminar.
-- Ajuste bolsas.barraConjuntos (de fábrica, encendido; con bolsas.conjuntos).
-- 1.3.9 (bug 104: «sale un recuadro de pesca en la esquina de arriba a la
-- derecha»): era esta barra, sola y sin título, encimada en la esquina de la
-- ventana. Ahora es un panel con su encabezado («Tus conjuntos»), afuera del
-- borde que se ve de la ventana (sus HitRectInsets: la del juego clásico
-- trae 30 px transparentes a la derecha) y con aire; y no sale cuando no
-- aporta: si tu único conjunto es el que ya llevas puesto (y no espera para
-- el fin del combate). Al cambiarte de equipo con la ventana abierta se
-- vuelve a mirar (fuera de combate).
--   Cb.Armar() ; Cb.Macro(c) -> texto del macro de las armas ; Cb.Barra() ; Cb.AlSalir() -> nombre | nil

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local ESP = K.ESP

local type, ipairs, pairs, tonumber, format, concat = type, ipairs, pairs, tonumber, string.format, table.concat
local floor, max = math.floor, math.max

local Cb = {}
M.Cambio = Cb

local ALTO, ANCHO = 22, 104
local MAX = 10
local PAD, CAB = 6, 20 -- (1.3.9) el margen del panel y la altura de su encabezado
local AIRE = 8         -- (1.3.9) entre el borde que se ve de tu ventana y el panel
local barra
local botones = {}

local function Cj() return M.Conjuntos end
local function enCombate() return M.EnCombate() end
local function encendido() return M.Get("conjuntos") ~= false and M.Get("barraConjuntos") ~= false end

local function datos() return N.DatosPersonaje(M.ID) end
function Cb.AlSalir()
	local n = datos().alSalir
	if type(n) ~= "string" or not (Cj() and Cj().Buscar(n)) then return nil end
	return n
end
function Cb.PonerAlSalir(nombre)
	local d = datos()
	if nombre and d.alSalir == nombre then nombre = nil end -- otro clic lo quita
	d.alSalir = nombre
	if nombre then
		N.Imprimir(format(L["Al salir de cada combate te pongo «%s»."], nombre))
	else
		N.Imprimir(L["Ya no te cambio el equipo al salir de combate."])
	end
	Cb.Pintar()
end

-- El macro de las armas del conjunto ("" si no lleva).
function Cb.Macro(c)
	if type(c) ~= "table" or type(c.p) ~= "table" then return "" end
	local lineas = {}
	for _, r in ipairs({ 16, 17, 18 }) do
		local pieza = c.p[r]
		local id = type(pieza) == "table" and tonumber(pieza.i)
		if id then lineas[#lineas + 1] = format("/equipslot %d item:%d", r, id) end
	end
	return concat(lineas, "\n")
end

local function anclaPersonaje() return rawget(_G, "CharacterFrame") end

local function crearBoton(i)
	local ok, b = pcall(CreateFrame, "Button", "AlfaBolsasCambio" .. i, barra, "SecureActionButtonTemplate")
	if not ok or type(b) ~= "table" then return nil end
	b:SetSize(ANCHO, ALTO)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetAttribute("useOnKeyDown", false)
	b.caja = K.Caja(b, { fondo = "panel", borde = "linea", corte = K.CORTE.chico })
	b.velo = K.Velo(b, K.CORTE.chico, 0.08)
	b.Marca = K.Plano(b, "acento", "ARTWORK", 1)
	b.Marca:SetWidth(2)
	b.Marca:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -4)
	b.Marca:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 4)
	b.Texto = K.Texto(b, "boton", "texto")
	b.Texto:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.Texto:SetJustifyH("CENTER")
	b:SetScript("OnEnter", function(self) self.velo:Show() end)
	b:SetScript("OnLeave", function(self) self.velo:Hide() end)
	b:SetScript("PreClick", function(self, raton)
		self.yaPuesto = nil
		if raton == "RightButton" or not Cj() then return end
		local c = Cj().Buscar(self.nombre)
		if c and not enCombate() then
			local puestas, _, _, total = Cj().Estado(c)
			self.yaPuesto = total > 0 and puestas == total
		end
	end)
	b:SetScript("PostClick", function(self, raton)
		local nombre = self.nombre
		if not nombre then return end
		if raton == "RightButton" then
			if K.Menu then
				local alSalir = Cb.AlSalir() == nombre
				K.Menu(self, {
					{ valor = "salir", texto = alSalir and L["Ya no ponérmelo al salir de combate"] or L["Ponérmelo al salir de cada combate"], icono = "ic-reloj" },
				}, nil, function(v) if v == "salir" then Cb.PonerAlSalir(nombre) end end, 260)
			end
			return
		end
		if self.yaPuesto then
			N.Imprimir(format(L["Ya llevas puesto «%s»."], nombre))
			return
		end
		Cj().Poner(nombre, { armasYa = self.armas })
		Cb.Pintar()
	end)
	K.ConInfo(b, function(self)
		local texto = self.armas and L["Clic: póntelo. En combate te cambia las armas al momento y lo demás al terminar."]
			or L["Clic: póntelo (en combate, al terminar)."]
		texto = texto .. "\n" .. L["Clic derecho: ponértelo al salir de cada combate."]
		if Cb.AlSalir() == self.nombre then texto = texto .. "\n" .. K.Tenir("acento", L["Te lo pongo al salir de cada combate."]) end
		return self.nombre, texto
	end)
	return b
end

-- Lo que se ve (texto y marca), sin tocar nada seguro: vale en combate.
function Cb.Pintar()
	-- Sin la barra a la vista no se leen tus bolsas (Cj.Puesto las recorre).
	if not (barra and barra:IsShown()) then return end
	local actual = Cj() and Cj().Puesto and Cj().Puesto() or nil
	local alSalir = Cb.AlSalir()
	for _, b in ipairs(botones) do
		if b.nombre then
			b.Marca:SetShown(b.nombre == actual)
			K.Escribir(b.Texto, (b.nombre == alSalir and "\194\183 " or "") .. Cj().Cortar(b.nombre, 12))
			K.Ajustar(b.Texto, ANCHO - 12)
		end
	end
end

-- 1.3.9: lo transparente de la ventana a la derecha y arriba (sus HitRectInsets).
local function margenes(ancla)
	local f = ancla.GetHitRectInsets
	if type(f) ~= "function" then return 0, 0 end
	local ok, _, der, arriba = pcall(f, ancla)
	if not ok then return 0, 0 end
	return max(0, K.num(der, 0)), max(0, K.num(arriba, 0))
end
Cb.Margenes = margenes

-- Rehace los botones y sus macros, y muestra u oculta la barra. Solo fuera de combate.
function Cb.Sitio(ancla)
	if not barra or enCombate() or type(ancla) ~= "table" then return false end
	local s = K.num(ancla.GetEffectiveScale and ancla:GetEffectiveScale(), 1)
	local us = max(0.01, K.num(UIParent:GetEffectiveScale(), 1))
	barra:SetScale(s / us)
	local x, y = ancla.GetRight and ancla:GetRight(), ancla.GetTop and ancla:GetTop()
	barra:ClearAllPoints()
	if type(x) == "number" and type(y) == "number" then
		-- 1.3.9: afuera de lo que se ve de la ventana, con aire, alineada con su borde de arriba.
		local der, arriba = margenes(ancla)
		barra:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - der + AIRE, y - arriba - 12)
	else
		barra:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -120)
	end
	return true
end

function Cb.Armar()
	if enCombate() then
		N.FueraDeCombate("bolsas.cambio", Cb.Armar)
		return false
	end
	local ancla = anclaPersonaje()
	local lista = (encendido() and Cj()) and Cj().Lista() or {}
	if not barra then
		if #lista == 0 then return true end
		barra = CreateFrame("Frame", "AlfaBolsasCambio", UIParent)
		barra:SetSize(ANCHO + 2 * PAD, ALTO + CAB + 2 * PAD)
		barra:SetFrameStrata("MEDIUM")
		barra:Hide()
		-- 1.3.9: un panel con su encabezado, para que se vea de Alfa y a propósito.
		barra.caja = K.Caja(barra, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel })
		barra.Icono = K.Icono(barra, "ic-personaje", 12, "acento")
		barra.Icono:SetPoint("TOPLEFT", barra, "TOPLEFT", PAD + 1, -(PAD + 3))
		barra.Titulo = K.Texto(barra, "pequeno", "textoSuave")
		barra.Titulo:SetPoint("LEFT", barra.Icono, "RIGHT", 4, 0)
		barra.Titulo:SetWidth(ANCHO - 16)
		barra.Titulo:SetJustifyH("LEFT")
		K.Escribir(barra.Titulo, L["Tus conjuntos"])
		K.Ajustar(barra.Titulo, ANCHO - 16)
	end
	local n = 0
	for i, c in ipairs(lista) do
		if i > MAX then break end
		local b = botones[i] or crearBoton(i)
		if b then
			botones[i] = b
			n = i
			b.nombre = c.n
			local macro = Cb.Macro(c)
			b.armas = macro ~= ""
			b:SetAttribute("type1", b.armas and "macro" or nil)
			b:SetAttribute("macrotext1", b.armas and macro or nil)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", barra, "TOPLEFT", PAD, -(PAD + CAB + (i - 1) * (ALTO + ESP.xs)))
			b:Show()
		end
	end
	for i = n + 1, #botones do
		local b = botones[i]
		b.nombre, b.armas = nil, nil
		b:SetAttribute("type1", nil)
		b:SetAttribute("macrotext1", nil)
		b:Hide()
	end
	barra:SetHeight(2 * PAD + CAB + max(ALTO, n * (ALTO + ESP.xs) - ESP.xs))
	barra:ClearAllPoints()
	local visible = n > 0 and type(ancla) == "table" and ancla.IsShown and ancla:IsShown() and Cb.Aporta(lista)
	if type(ancla) == "table" then
		-- A la derecha de la ventana de tu personaje, por fuera de su marco.
		-- 1.3.7: anclada a UIParent con las medidas de esa ventana (fuera de
		-- combate): anclar botones seguros a CharacterFrame lo volvía protegido.
		Cb.Sitio(ancla)
		if visible and N.Una then N.Una("bolsas.cambioSitio", 0.05, function() if not enCombate() then Cb.Sitio(ancla) end end) end
	end
	barra:SetShown(visible and true or false)
	Cb.Pintar()
	return true
end

-- 1.3.9: ¿sirve de algo ahora? No, si tu único conjunto es el que ya llevas
-- puesto y no espera para el fin del combate (solo se mira con la ventana abierta).
function Cb.Aporta(lista)
	lista = lista or (Cj() and Cj().Lista()) or {}
	if #lista == 0 then return false end
	if #lista > 1 or Cb.AlSalir() then return true end
	local actual = Cj().Puesto and Cj().Puesto() or nil
	return actual ~= lista[1].n
end

function Cb.Barra() return barra end
function Cb.Botones() return botones end

-- Al salir de combate: el conjunto elegido (si no esperaba ya otro de un clic).
A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	local n = Cb.AlSalir()
	if not (n and Cj()) or Cj().esperando then return end
	if Cj().Puesto() == n then return end
	-- Un momento después: lo que esperaba del combate va primero.
	if N.Una then N.Una("bolsas.alSalir", 0.5, function() if not enCombate() and Cj().Puesto() ~= n then Cj().Poner(n) end end)
	else Cj().Poner(n) end
end)

local enganchado = false
local function enganchar()
	local f = anclaPersonaje()
	if enganchado or type(f) ~= "table" or not f.HookScript then return end
	enganchado = true
	f:HookScript("OnShow", function() Cb.Armar() end)
	f:HookScript("OnHide", function() Cb.Armar() end)
end

A.RegisterEvent("PLAYER_LOGIN", function()
	enganchar()
	Cb.Armar()
end)
-- 1.3.9: con tu ventana abierta, un cambio de equipo vuelve a mirar si la barra
-- aporta (fuera de combate; en combate solo se pinta).
A.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
	local ancla = anclaPersonaje()
	if not (barra and type(ancla) == "table" and ancla.IsShown and ancla:IsShown()) then return end
	if enCombate() then
		if barra:IsShown() then Cb.Pintar() end
		return
	end
	if N.Una then N.Una("bolsas.cambioEquipo", 0.3, function() Cb.Armar() end) else Cb.Armar() end
end)
M.Escuchar("CONJUNTOS", function() Cb.Armar() end)
A.On("SETTING_CHANGED", function(ruta)
	if ruta == M.ID .. ".barraConjuntos" or ruta == M.ID .. ".conjuntos" or ruta == "" or ruta == M.ID then Cb.Armar() end
end)
