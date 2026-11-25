-- Alfa - Bienvenida: acomodar la pantalla (1.3.1; 1.4.0: todo se mueve). toxic3000 / La Jauría. GPL-3.0.
--
-- Un solo modo para mover con el ratón todo lo que Alfa pone en pantalla.
-- 1.4.0 (78): cada cosa se registra en el Kit con K.Movible (Kit/Movible.lua)
-- y este modo enseña la lista entera: la flecha y, aparte, sus placas
-- (llegada, piedra de hogar, viaje), tu guía, los avisos, los anuncios, Lya,
-- la tarjeta de raros, el aviso del barco, la pesca, el aviso de «sal de
-- ahí», «¿Todos listos?», el cronómetro y el resumen de mazmorra, el botón
-- flotante, el cronómetro de vuelo, el de instancias y el panel del grupo;
-- Combate y Curación encienden sus propios marcos para mover.
--
-- Al entrar, el juego se oscurece un poco con una rejilla fina y la cruz del
-- centro; cada cosa sale con su recuadro y su nombre, y lo que no está a la
-- vista (un anuncio, un aviso) sale como un recuadro punteado con una
-- muestra. Se arrastra con imán a la rejilla, a los bordes y al centro (una
-- guía lo marca); clic derecho «Volver a su lugar»; la rueda del ratón
-- cambia el tamaño de lo que lo permite. «Volver todo a su lugar», «Listo»,
-- Esc o entrar en combate lo terminan. Sin el modo, nada atrapa clics:
-- Mayús+arrastre mueve directo lo que está a la vista (acomodar.conMayus).
--
--   /alfa acomodar   ·   menú de Alfa   ·   Ajustes > Estilo y sonido
--   M.Acomodar.Abrir() / .Cerrar() / .Activo() / .Marcas() / .Soltar(clave, x, y)

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, ipairs, pairs, pcall, rawget, tonumber, floor, max, min, wipe =
	type, ipairs, pairs, pcall, rawget, tonumber, math.floor, math.max, math.min, wipe

local Ac = {}
M.Acomodar = Ac

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

---------------------------------------------------------------------------
-- Lo que se registra (cada cosa guarda su lugar con su código de siempre)
---------------------------------------------------------------------------

-- Llama al OnDragStop del marco (o de su primer hijo que lo tenga): así se
-- guarda igual que cuando lo arrastras a mano, con lo que haga además.
local function asaDe(f, hijo)
	if not hijo then return f end
	for _, h in ipairs({ f:GetChildren() }) do
		if h.GetScript and h:GetScript("OnDragStop") then return h end
	end
	return f
end
local function porDragStop(bandera, hijo)
	return function(f)
		if not f then return end
		local asa = asaDe(f, hijo)
		if bandera then asa[bandera] = true end
		local fn = asa.GetScript and asa:GetScript("OnDragStop")
		if fn then fn(asa) end
	end
end

local function punto(f)
	local p, _, rp, x, y = f:GetPoint(1)
	return p, rp or p, floor((tonumber(x) or 0) + 0.5), floor((tonumber(y) or 0) + 0.5)
end

local function ponerEn(f, p, rp, x, y)
	if not f then return end
	f:ClearAllPoints()
	f:SetPoint(p, UIParent, rp, x, y)
end

local function arrow()
	local Nv = rawget(A, "Nav")
	local Ar = type(Nv) == "table" and rawget(Nv, "arrow")
	return type(Ar) == "table" and Ar or nil
end

-- Los que guardan en un ajuste del motor como { "CENTER", dx, dy } (Maps.CompactFrame).
local function compacto(clave)
	return {
		guardar = function(f)
			local cx, cy = f:GetCenter()
			local ux, uy = UIParent:GetCenter()
			local us = UIParent:GetEffectiveScale()
			local s = (f:GetEffectiveScale() or 1) / ((us and us > 0) and us or 1)
			if cx and ux then A.Set(clave, { "CENTER", floor(cx * s - ux + 0.5), floor(cy * s - uy + 0.5) }) end
		end,
		volver = function(f)
			A.Set(clave, nil)
			if f and type(f.Place) == "function" then f.Place() end
		end,
	}
end

local function con(o, extra)
	for k, v in pairs(extra or {}) do o[k] = v end
	return o
end

local REGISTRO = {
	{ "AlfaNavArrow", "flecha", { orden = 10, nombre = "La flecha", mayus = false,
		guardar = function(f)
			local p, rp, x, y = punto(f)
			A.Set("nav.arrowPos", { point = p, relPoint = rp, x = x, y = y })
		end,
		volver = function(f)
			local Nav = A.Nav
			if Nav and Nav.ResetArrowPosition then Nav.ResetArrowPosition() end
			ponerEn(f, "TOP", "TOP", 0, -140)
		end,
		escala = { get = function() return tonumber(A.Get("nav.arrowScale")) or 1 end,
			set = function(v) A.Set("nav.arrowScale", v) end } } },
	{ "AlfaNavPlacas", "placas", { orden = 11, nombre = "Las placas de la flecha",
		muestra = "«Llegaste», «Usa tu piedra de hogar» y los viajes salen aquí.",
		tam = { 264, 72 },
		vista = function() local Ar = arrow() return Ar and Ar.PlacaVista and Ar.PlacaVista() or nil end,
		-- 1.4.0: con Mayús toma el ratón la placa que se ve (no el ancla, que
		-- tapaba sus botones y el área de la flecha). Juntas, Mayús mueve la
		-- flecha con su placa (su propio arrastre): nunca las separa sin querer.
		asa = function() local Ar = arrow() return Ar and Ar.PlacaVista and Ar.PlacaVista() or nil end,
		mayusOtro = function()
			local Ar = arrow()
			if Ar and Ar.PlacasAparte and not Ar.PlacasAparte() then return rawget(_G, "AlfaNavArrow") end
		end,
		alEmpezar = function() local Ar = arrow() if Ar and Ar.SepararPlacas then Ar.SepararPlacas() end end,
		guardar = function(f)
			local p, rp, x, y = punto(f)
			A.Set("nav.placasPos", { point = p, relPoint = rp, x = x, y = y })
		end,
		-- Volver: otra vez con la flecha.
		volver = function() A.Set("nav.placasPos", nil) end } },
	{ "AlfaRastreador", "rastreador", { orden = 20, nombre = "Tu guía", mayus = false,
		guardar = porDragStop(nil, true),
		volver = function(f)
			N.Datos("rutas").rastreador = nil
			ponerEn(f, "TOPRIGHT", "TOPRIGHT", -72, -220)
		end } },
	{ "AlfaInicioAviso", "avisoHoy", { orden = 31, nombre = "Los avisos de Hoy", mayus = false,
		muestra = "Así sale un aviso de Hoy.", tam = { 300, 72 },
		guardar = porDragStop(),
		volver = function(f)
			N.Set("inicio", "avisoPos", nil)
			ponerEn(f, "TOPRIGHT", "TOPRIGHT", -215, -130)
		end } },
	{ "AlfaLyaLoba", "lya", { orden = 40, nombre = "Lya", mayus = false,
		guardar = porDragStop(),
		volver = function(f)
			N.Set("lya", "pos", nil)
			ponerEn(f, "BOTTOMRIGHT", "BOTTOMRIGHT", -330, 150)
		end } },
	{ "AlfaRareToast", "raros", { orden = 45, nombre = "La tarjeta de raros", mayus = false,
		muestra = "Aquí sale la tarjeta de un raro cerca.", tam = { 320, 64 },
		guardar = porDragStop(),
		volver = function(f)
			A.Set("rares.toastPoint", nil)
			ponerEn(f, "TOP", "TOP", 0, -132)
		end } },
	{ "AlfaAlert", "barco", { orden = 46, nombre = "El aviso del barco",
		muestra = "Aquí sale el aviso de barcos y zepelines.", tam = { 300, 56 } } },
	{ "AlfaPescaBarra", "pescaBarra", { orden = 50, nombre = "La barra de pesca", mayus = false,
		guardar = porDragStop("alfaMoviendo"),
		volver = function(f)
			local d = N.Datos("pesca")
			ponerEn(f, "BOTTOM", "BOTTOM", 0, 220)
			-- (su OnDragStop acomoda el botón «A pelear» encima; el lugar de siempre no se guarda)
			porDragStop("alfaMoviendo")(f)
			if type(d.barra) == "table" then d.barra.lugar = nil end
		end } },
	{ "AlfaPescaCanal", "pescaCanal", { orden = 51, nombre = "La barra del lanzado", mayus = false,
		guardar = porDragStop("alfaMoviendo"),
		volver = function(f)
			local d = N.Datos("pesca")
			if type(d.barra) == "table" then d.barra.lugarCanal = nil end
			ponerEn(f, "BOTTOM", "BOTTOM", 0, 240)
		end } },
	{ "AlfaPescaMetas", "pescaMetas", { orden = 52, nombre = "Tus metas de pesca", mayus = false,
		guardar = porDragStop(),
		volver = function(f)
			N.Datos("pesca").metasLugar = nil
			ponerEn(f, "RIGHT", "RIGHT", -60, 80)
		end } },
	{ "AlfaCombateSalDeAhi", "salDeAhi", { orden = 60, nombre = "«¡Sal de ahí!»",
		muestra = "Aquí sale «¡Sal de ahí!».", tam = { 320, 64 } } },
	{ "AlfaCuracionListos", "listos", { orden = 62, nombre = "«¿Todos listos?»",
		muestra = "Aquí sale quién falta antes de empezar.", tam = { 300, 80 } } },
	{ "AlfaMazmorrasEnVivo", "mazmorraVivo", { orden = 70, nombre = "El cronómetro de mazmorra",
		muestra = "Aquí sale el cronómetro de la mazmorra.", tam = { 300, 60 } } },
	{ "AlfaMazmorrasEnVivoLinea", "mazmorraLinea", { orden = 71, nombre = "La línea del cronómetro",
		muestra = "Aquí sale la línea corta del cronómetro.", tam = { 220, 28 } } },
	{ "AlfaMazmorrasResumen", "mazmorraResumen", { orden = 72, nombre = "El resumen de la mazmorra",
		muestra = "Aquí sale el resumen al terminar una mazmorra.", tam = { 340, 200 } } },
	{ "AlfaLauncher", "botonFlotante", { orden = 80, nombre = "El botón flotante de Alfa", mayus = false,
		guardar = porDragStop("psMoving"),
		volver = function(f)
			A.Set("ui.launcherPos", nil)
			ponerEn(f, "CENTER", "TOPRIGHT", -440, -256)
		end } },
	{ "AlfaFlightTimer", "vuelo", con({ orden = 81, nombre = "El cronómetro de vuelo", mayus = false }, compacto("maps.timerPos")) },
	{ "AlfaInstanceTracker", "instancias", con({ orden = 82, nombre = "Tus instancias", mayus = false }, compacto("maps.trackerPos")) },
	{ "AlfaPartyPanel", "grupo", con({ orden = 83, nombre = "El panel del grupo", mayus = false }, compacto("party.panelPos")) },
}

local function traducir(v)
	if type(v) == "string" then return L[v] end
	return v
end

for _, r in ipairs(REGISTRO) do
	local op = r[3]
	op.nombre = traducir(op.nombre)
	op.muestra = traducir(op.muestra)
	K.Movible(r[1], r[2], op)
end

-- Los que traen sus propios marcos para mover: se encienden y se apagan.
local PROPIOS = {
	{ id = "combate", global = "AlfaCombate",
		encender = function(C) if type(C.Mover) == "function" then C.Mover() return true end end,
		apagar = function(C) if type(C.Mover) == "function" then C.Mover() end end },
	{ id = "curacion", global = "AlfaCuracion",
		encender = function(C)
			if type(C.Mover) ~= "function" then return false end
			if type(C.Moviendo) == "function" and C.Moviendo() then return false end
			C.Mover(true)
			return true
		end,
		apagar = function(C) if type(C.Mover) == "function" then C.Mover(false) end end },
}

---------------------------------------------------------------------------
-- El modo
---------------------------------------------------------------------------

local activo = false
local velo, panel
local marcas = {}      -- clave -> el recuadro de cada cosa
local encendidos = {}  -- id de PROPIOS que encendimos nosotros
local bloqueoAntes     -- A.DragLocked de antes (mientras acomodas, nada está bloqueado)
local arrastrado       -- el elemento que se arrastra

K.AcomodarActivo = function() return activo end

local REJILLA_VISTA = 32 -- cada cuánto una línea fina de la rejilla

local function color()
	return K.Color(K.Clasico() and "oro" or "acento")
end

local function pintarMarca(m)
	local r, g, b = color()
	if m.alfaVacia then
		local tr, tg, tb = K.Color("textoSuave")
		m.Fondo:SetColorTexture(tr, tg, tb, m.sobre and 0.16 or 0.08)
		for i, t in ipairs(m.Bordes) do t:SetColorTexture(r, g, b, (m.sobre and 0.9 or 0.55)) end
	else
		m.Fondo:SetColorTexture(r, g, b, m.sobre and 0.22 or 0.12)
		for _, t in ipairs(m.Bordes) do t:SetColorTexture(r, g, b, 0.95) end
	end
end

local function rectDeMarca(m)
	local ul, ub = UIParent:GetLeft() or 0, UIParent:GetBottom() or 0
	local l, b, w, h = m:GetRect()
	if not l then return nil end
	return l - ul, b - ub, w, h
end

-- El rect a la vista de un elemento (lo que se ve, o su ancla) y si se ve.
local function rectDe(e)
	local v = K.MovibleVisible(e)
	if v and v ~= e.marco then
		local us = UIParent:GetEffectiveScale()
		local k = (v:GetEffectiveScale() or 1) / ((us and us > 0) and us or 1)
		local l, b, w, h = v:GetRect()
		if l then
			return l * k - (UIParent:GetLeft() or 0), b * k - (UIParent:GetBottom() or 0), w * k, h * k, true
		end
	end
	local l, b, w, h = K.MovibleRect(e)
	return l, b, w, h, v ~= nil
end

local function colocarMarca(e, m)
	local l, b, w, h, visto = rectDe(e)
	if not l then m:Hide() return false end
	w, h = max(w, 28), max(h, 20)
	m:ClearAllPoints()
	m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
	m:SetSize(w, h)
	m.alfaVacia = not visto
	-- La muestra, dentro del recuadro punteado de lo que no está a la vista.
	local muestra = not visto and K.MovibleMuestra(e) or nil
	m.Muestra:SetShown(muestra ~= nil)
	if muestra then
		m.Muestra:SetWidth(max(20, w - 16))
		K.Escribir(m.Muestra, muestra)
	end
	-- El nombre, arriba; si no cabe arriba de la pantalla, abajo.
	local H = UIParent:GetHeight() or 1080
	m.Etiqueta:ClearAllPoints()
	if b + h + 22 > H then
		m.Etiqueta:SetPoint("TOPLEFT", m, "BOTTOMLEFT", 0, -3)
	else
		m.Etiqueta:SetPoint("BOTTOMLEFT", m, "TOPLEFT", 0, 3)
	end
	pintarMarca(m)
	m:Show()
	return true, visto
end

-- Que los nombres no se encimen: cada etiqueta prueba arriba a la
-- izquierda, arriba a la derecha, abajo a la izquierda y abajo a la derecha
-- de su recuadro, y se queda en la primera que no pisa a otra.
local LUGARES_ETIQUETA = {
	{ "BOTTOMLEFT", "TOPLEFT", 0, 3 }, { "BOTTOMRIGHT", "TOPRIGHT", 0, 3 },
	{ "TOPLEFT", "BOTTOMLEFT", 0, -3 }, { "TOPRIGHT", "BOTTOMRIGHT", 0, -3 },
	{ "TOPLEFT", "TOPLEFT", 4, -4 },
}
local function seEnciman(a, b)
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end
local function sinEncimar()
	local H = UIParent:GetHeight() or 1080
	local puestas = {}
	for _, e in ipairs(K.MovibleLista()) do
		local m = marcas[e.clave]
		if m and m:IsShown() then
			local et = m.Etiqueta
			local elegido
			for _, lu in ipairs(LUGARES_ETIQUETA) do
				et:ClearAllPoints()
				et:SetPoint(lu[1], m, lu[2], lu[3], lu[4])
				local l, b, w, h = et:GetRect()
				if l then
					local r = { l, b, w, h }
					local libre = b >= 0 and b + h <= H
					for _, o in ipairs(puestas) do if seEnciman(r, o) then libre = false break end end
					if libre then elegido = r break end
				end
			end
			if not elegido then
				et:ClearAllPoints()
				et:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -4)
				local l, b, w, h = et:GetRect()
				elegido = l and { l, b, w, h } or nil
			end
			if elegido then puestas[#puestas + 1] = elegido end
		end
	end
end

local function refrescarMarcas()
	for clave, m in pairs(marcas) do
		local e = K.MovibleDe(clave)
		if e and m:IsShown() and e ~= arrastrado then colocarMarca(e, m) end
	end
	sinEncimar()
end

local function guias(gx, gy)
	if not velo then return end
	if gx then
		velo.GuiaV:ClearAllPoints()
		velo.GuiaV:SetPoint("TOP", velo, "TOPLEFT", gx, 0)
		velo.GuiaV:SetPoint("BOTTOM", velo, "BOTTOMLEFT", gx, 0)
		velo.GuiaV:Show()
	else
		velo.GuiaV:Hide()
	end
	if gy then
		velo.GuiaH:ClearAllPoints()
		velo.GuiaH:SetPoint("LEFT", velo, "BOTTOMLEFT", 0, gy)
		velo.GuiaH:SetPoint("RIGHT", velo, "BOTTOMRIGHT", 0, gy)
		velo.GuiaH:Show()
	else
		velo.GuiaH:Hide()
	end
end

local function empezar(e, m)
	if enCombate() or arrastrado then return end
	arrastrado = e
	e.arrastrando = true
	if e.op.alEmpezar then pcall(e.op.alEmpezar) end
	m:SetMovable(true)
	m:StartMoving()
	-- Lo de verdad sigue al recuadro mientras lo arrastras.
	local f = e.marco
	if f then
		f:ClearAllPoints()
		f:SetPoint("CENTER", m, "CENTER", 0, 0)
	end
	m:SetScript("OnUpdate", function(self)
		local l, b, w, h = rectDeMarca(self)
		if not l then return end
		local _, _, gx, gy = K.MovibleIman(l, b, w, h)
		guias(gx, gy)
	end)
end

local function soltar(e, m)
	if arrastrado ~= e then return end
	arrastrado = nil
	m:StopMovingOrSizing()
	m:SetScript("OnUpdate", nil)
	if m.SetUserPlaced then pcall(m.SetUserPlaced, m, false) end
	e.arrastrando = false
	guias(nil, nil)
	-- Dónde quedó: lo de verdad (sigue al recuadro); si no, el recuadro.
	local l, b, w, h = K.MovibleRect(e)
	if not l then l, b, w, h = rectDeMarca(m) end
	if l then K.MovibleSoltar(e, l, b, w, h) end
	colocarMarca(e, m)
	refrescarMarcas()
end

local function crearMarca(e)
	local m = CreateFrame("Button", nil, UIParent)
	m:SetFrameStrata("FULLSCREEN_DIALOG")
	m:SetFrameLevel(20)
	m:SetMovable(true)
	m:SetClampedToScreen(true)
	m:RegisterForClicks("RightButtonUp")
	if m.EnableMouseWheel then m:EnableMouseWheel(true) end
	m.Fondo = m:CreateTexture(nil, "BACKGROUND")
	m.Fondo:SetAllPoints(m)
	m.Bordes = {}
	for i, lado in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
		local t = m:CreateTexture(nil, "BORDER")
		t:SetPoint(lado[1], m, lado[1], 0, 0)
		t:SetPoint(lado[2], m, lado[2], 0, 0)
		if lado[3] then t:SetHeight(2) else t:SetWidth(2) end
		m.Bordes[i] = t
	end
	-- El nombre, en una etiqueta oscura arriba del recuadro.
	m.Etiqueta = CreateFrame("Frame", nil, m)
	m.Etiqueta.caja = K.Caja(m.Etiqueta, { fondo = "fondo", borde = "linea" })
	m.Nombre = K.Texto(m.Etiqueta, "nota", "texto")
	m.Nombre:SetPoint("LEFT", m.Etiqueta, "LEFT", 6, 0)
	K.Escribir(m.Nombre, K.MovibleNombre(e))
	m.Etiqueta:SetSize(K.AnchoTexto(m.Nombre) + 12, 18)
	-- La muestra de lo que no está a la vista.
	m.Muestra = K.Texto(m, "nota", "textoSuave")
	m.Muestra:SetPoint("CENTER", m, "CENTER", 0, 0)
	m.Muestra:SetJustifyH("CENTER")
	m.Muestra:SetWordWrap(true)
	m.Muestra:Hide()

	m:SetScript("OnMouseDown", function(self, boton) if boton == "LeftButton" then empezar(e, self) end end)
	m:SetScript("OnMouseUp", function(self, boton) if boton == "LeftButton" then soltar(e, self) end end)
	m:SetScript("OnHide", function(self) soltar(e, self) end)
	m:SetScript("OnClick", function(self, boton)
		if boton ~= "RightButton" or enCombate() then return end
		K.MovibleVolver(e)
		colocarMarca(e, self)
		refrescarMarcas()
	end)
	m:SetScript("OnMouseWheel", function(self, delta)
		if not e.op.escala or enCombate() then return end
		K.MovibleEscala(e, (tonumber(delta) or 0) * 0.05)
		colocarMarca(e, self)
		refrescarMarcas()
	end)
	m:SetScript("OnEnter", function(self)
		self.sobre = true
		pintarMarca(self)
		local t = L["Arrástralo para moverlo. Clic derecho: vuelve a su lugar."]
		if e.op.escala then t = t .. "\n" .. L["Rueda del ratón: más grande o más chico."] end
		if self.alfaVacia then t = t .. "\n" .. L["Ahora no está a la vista: lo acomodas y sale ahí la próxima vez."] end
		K.MostrarInfo(self, K.MovibleNombre(e), t)
	end)
	m:SetScript("OnLeave", function(self)
		self.sobre = nil
		pintarMarca(self)
		K.OcultarInfo(self)
	end)
	return m
end

local function rejilla()
	local W, H = floor((UIParent:GetWidth() or 1920) + 0.5), floor((UIParent:GetHeight() or 1080) + 0.5)
	if velo.alfaW == W and velo.alfaH == H then return end
	velo.alfaW, velo.alfaH = W, H
	for _, t in ipairs(velo.Lineas) do t:Hide() end
	local n = 0
	local function linea(vertical, pos, fuerte)
		n = n + 1
		local t = velo.Lineas[n]
		if not t then
			t = velo:CreateTexture(nil, "ARTWORK")
			velo.Lineas[n] = t
		end
		t:ClearAllPoints()
		if vertical then
			t:SetPoint("TOP", velo, "TOPLEFT", pos, 0)
			t:SetPoint("BOTTOM", velo, "BOTTOMLEFT", pos, 0)
			t:SetWidth(1)
		else
			t:SetPoint("LEFT", velo, "BOTTOMLEFT", 0, pos)
			t:SetPoint("RIGHT", velo, "BOTTOMRIGHT", 0, pos)
			t:SetHeight(1)
		end
		t.alfaFuerte = fuerte
		t:Show()
	end
	local cx, cy = floor(W / 2), floor(H / 2)
	-- Desde el centro hacia los lados: la cruz cae justo en una línea.
	for x = cx % REJILLA_VISTA, W, REJILLA_VISTA do linea(true, x, x == cx) end
	for y = cy % REJILLA_VISTA, H, REJILLA_VISTA do linea(false, y, y == cy) end
	velo.alfaLineas = n
end

local function pintarVelo(x)
	local r, g, b = color()
	for i = 1, x.alfaLineas or 0 do
		local t = x.Lineas[i]
		t:SetColorTexture(r, g, b, t.alfaFuerte and 0.35 or 0.07)
	end
	x.GuiaV:SetColorTexture(r, g, b, 0.9)
	x.GuiaH:SetColorTexture(r, g, b, 0.9)
end

local function crearVelo()
	velo = CreateFrame("Frame", nil, UIParent)
	velo:SetAllPoints(UIParent)
	velo:SetFrameStrata("DIALOG")
	velo:EnableMouse(false)
	velo.Oscuro = velo:CreateTexture(nil, "BACKGROUND")
	velo.Oscuro:SetAllPoints(velo)
	velo.Oscuro:SetColorTexture(0, 0, 0, 0.35)
	velo.Lineas = {}
	velo.GuiaV = velo:CreateTexture(nil, "OVERLAY")
	velo.GuiaV:SetWidth(2)
	velo.GuiaV:Hide()
	velo.GuiaH = velo:CreateTexture(nil, "OVERLAY")
	velo.GuiaH:SetHeight(2)
	velo.GuiaH:Hide()
	velo:Hide()
end

local ANCHO_PANEL = 480

local function acomodarPanel()
	local pad = K.ESP.m
	local col = ANCHO_PANEL - pad * 2
	panel.Texto:SetWidth(col)
	local y = pad + 20 + K.ESP.s + (K.num and K.num(panel.Texto:GetStringHeight(), 28) or 28) + K.ESP.m
	-- La fila de abajo: el imán a la izquierda, los botones a la derecha.
	panel.Iman:ClearAllPoints()
	panel.Iman:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -(y + (K.ALTO.botonChico - K.ALTO.interruptor) / 2))
	panel.ImanTexto:ClearAllPoints()
	panel.ImanTexto:SetPoint("LEFT", panel.Iman, "RIGHT", K.ESP.s, 0)
	panel.Listo:ClearAllPoints()
	panel.Listo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad, -y)
	panel.Todo:ClearAllPoints()
	panel.Todo:SetPoint("RIGHT", panel.Listo, "LEFT", -K.ESP.s, 0)
	-- Si no cabe todo en una fila, los botones van abajo.
	local izq = 36 + K.ESP.s + K.AnchoTexto(panel.ImanTexto) + K.ESP.m
	local der = panel.Listo:GetWidth() + K.ESP.s + panel.Todo:GetWidth()
	if izq + der > col then
		y = y + K.ALTO.botonChico + K.ESP.s
		panel.Listo:ClearAllPoints()
		panel.Listo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad, -y)
	end
	panel:SetSize(ANCHO_PANEL, y + K.ALTO.botonChico + pad)
end

local confirmarTodo = false

local function volverTodo()
	if enCombate() then return end
	if not confirmarTodo then
		-- Dos clics: el primero pregunta (sin ventanas encima del modo).
		confirmarTodo = true
		panel.Todo:SetTexto(L["¿Seguro? Otra vez"])
		N.Una("acomodar.todo", 4, function()
			confirmarTodo = false
			if panel then panel.Todo:SetTexto(L["Volver todo a su lugar"]) end
		end)
		return
	end
	confirmarTodo = false
	N.Quitar("acomodar.todo")
	K.MovibleVolverTodo()
	panel.Todo:SetTexto(L["Volver todo a su lugar"])
	refrescarMarcas()
end
Ac.VolverTodo = volverTodo

local function crearPanel()
	panel = CreateFrame("Frame", "AlfaAcomodarPanel", UIParent)
	panel:SetFrameStrata("FULLSCREEN_DIALOG")
	panel:SetFrameLevel(40)
	panel:SetSize(ANCHO_PANEL, 120)
	-- Abajo del centro: arriba están la flecha, los avisos y los anuncios.
	panel:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:SetClampedToScreen(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
	panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	panel.caja = K.Caja(panel, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.panel })
	panel.Marca = K.Marca(panel, K.CORTE.panel, "acento")
	panel.Icono = K.Icono(panel, "ic-ventana", 18, "acento")
	panel.Icono:SetPoint("TOPLEFT", panel, "TOPLEFT", K.ESP.m, -K.ESP.m)
	panel.Titulo = K.Texto(panel, "encabezado", "texto")
	panel.Titulo:SetPoint("LEFT", panel.Icono, "RIGHT", K.ESP.s, 0)
	K.Escribir(panel.Titulo, L["Acomodar la pantalla"])
	panel.Texto = K.Texto(panel, "nota", "textoSuave")
	panel.Texto:SetPoint("TOPLEFT", panel, "TOPLEFT", K.ESP.m, -(K.ESP.m + 20 + K.ESP.s))
	panel.Texto:SetJustifyH("LEFT")
	panel.Texto:SetWordWrap(true)
	panel.Iman = K.Interruptor(panel, { clave = "acomodar.iman" })
	panel.ImanTexto = K.Texto(panel, "nota", "texto")
	K.Escribir(panel.ImanTexto, L["Imán a la rejilla y al centro"])
	panel.Listo = K.Boton(panel, L["Listo"], function() Ac.Cerrar() end, { tipo = "primario", tam = "chico" })
	panel.Todo = K.Boton(panel, L["Volver todo a su lugar"], volverTodo, { tipo = "secundario", tam = "chico" })
	-- Esc lo termina; las demás teclas siguen siendo del juego.
	panel:EnableKeyboard(true)
	panel:SetScript("OnKeyDown", function(self, tecla)
		local esc = tecla == "ESCAPE"
		if self.SetPropagateKeyboardInput and not enCombate() then self:SetPropagateKeyboardInput(not esc) end
		if esc then Ac.Cerrar() end
	end)
	-- Si algo esconde el panel (la interfaz entera, otra ventana), el modo termina:
	-- ni el velo, ni la rejilla, ni las guías se quedan encima de todo.
	panel:SetScript("OnHide", function() if activo then Ac.Cerrar() end end)
	panel:Hide()
end

---------------------------------------------------------------------------
-- Entrar y salir
---------------------------------------------------------------------------

function Ac.Activo() return activo end
function Ac.Marcas() return marcas end
function Ac.Velo() return velo end -- (para las capturas del banco)

function Ac.Abrir()
	if activo then return true end
	if enCombate() then
		N.Imprimir(L["Los marcos se mueven fuera de combate."])
		return false
	end
	if not velo then crearVelo() end
	if not panel then crearPanel() end
	activo = true
	-- Mayús+arrastre no presta el ratón mientras acomodas (ya está todo a la mano).
	if K.MoviblePrestarRaton then K.MoviblePrestarRaton() end
	-- Mientras acomodas, nada está bloqueado (la flecha con «Fijar» incluida).
	bloqueoAntes = A.DragLocked
	A.DragLocked = function() return false end
	-- El ancla de los avisos existe aunque no haya salido ninguno.
	if K.AnclaAvisos then pcall(K.AnclaAvisos) end
	if K.AnclaAnuncio then pcall(K.AnclaAnuncio) end
	local vistos, muestras = 0, 0
	for _, e in ipairs(K.MovibleLista()) do
		if e.marco then
			local m = marcas[e.clave] or crearMarca(e)
			marcas[e.clave] = m
			local ok, visto = colocarMarca(e, m)
			-- Lo que no está a la vista sale solo si trae su muestra (anuncios,
			-- avisos...); si no, no estorba.
			if ok and not visto and not K.MovibleMuestra(e) then m:Hide() ok = false end
			if ok then
				if visto then vistos = vistos + 1 else muestras = muestras + 1 end
			end
		elseif marcas[e.clave] then
			marcas[e.clave]:Hide()
		end
	end
	sinEncimar()
	wipe(encendidos)
	for _, p in ipairs(PROPIOS) do
		local C = rawget(_G, p.global)
		if type(C) == "table" then
			local ok, si = pcall(p.encender, C)
			if ok and si then encendidos[p.id] = C vistos = vistos + 1 end
		end
	end
	local texto = L["Arrastra lo que quieras: se pega a la rejilla, a los bordes y al centro. Clic derecho en uno: vuelve a su lugar."]
	if muestras > 0 then texto = texto .. " " .. L["Los recuadros punteados son lo que ahora no está a la vista, con una muestra."] end
	K.Escribir(panel.Texto, texto)
	if panel.Iman.Leer then panel.Iman:Leer() end
	confirmarTodo = false
	panel.Todo:SetTexto(L["Volver todo a su lugar"])
	rejilla()
	pintarVelo(velo)
	acomodarPanel()
	velo:Show()
	panel:Show()
	return true
end

function Ac.Cerrar()
	if not activo then return end
	for clave, m in pairs(marcas) do
		local e = K.MovibleDe(clave)
		if e then soltar(e, m) end
		m:Hide()
	end
	activo = false
	for _, p in ipairs(PROPIOS) do
		local C = encendidos[p.id]
		if C then pcall(p.apagar, C) end
	end
	wipe(encendidos)
	if bloqueoAntes ~= nil then A.DragLocked = bloqueoAntes end
	bloqueoAntes = nil
	N.Quitar("acomodar.todo")
	if velo then velo:Hide() end
	if panel then panel:Hide() end
end

function Ac.Alternar() if activo then Ac.Cerrar() else Ac.Abrir() end end

-- Para el banco: suelta el elemento con su esquina de abajo a la izquierda
-- en (x, y) de UIParent, como al arrastrarlo con el ratón.
function Ac.Soltar(clave, x, y)
	local e = K.MovibleDe(clave)
	local m = marcas[clave]
	if not (e and e.marco) then return nil end
	if m and activo then
		empezar(e, m)
		local _, _, w, h = K.MovibleRect(e)
		m:ClearAllPoints()
		m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
		m:SetSize(w or 200, h or 48)
		soltar(e, m)
		return K.MovibleGuardado(clave) or true
	end
	local _, _, w, h = K.MovibleRect(e)
	return K.MovibleSoltar(e, x, y, w, h)
end

-- Una pelea lo termina: en combate no se mueve nada.
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() if activo then Ac.Cerrar() end end)

A.RegisterCommand("acomodar", function() Ac.Alternar() end, L["acomoda con el ratón lo de Alfa en tu pantalla"])

AlfaAcomodar = type(AlfaAcomodar) == "table" and AlfaAcomodar or {}
function AlfaAcomodar.Abrir() return Ac.Abrir() end
function AlfaAcomodar.Cerrar() return Ac.Cerrar() end
function AlfaAcomodar.Activo() return activo end
-- 1.3.7: otro módulo suma lo suyo (la barra de información de Comodidades):
-- { id, titulo (ya traducido), marco (nombre global), restablecer = fn(f) }.
-- 1.4.0: pasa a K.Movible y guarda con el OnDragStop de su marco.
function AlfaAcomodar.Agregar(el)
	if type(el) ~= "table" or type(el.id) ~= "string" or type(el.marco) ~= "string" then return false end
	if K.MovibleDe(el.id) then return true end
	K.Movible(el.marco, el.id, { nombre = el.titulo or el.id, mayus = false, orden = 55,
		guardar = porDragStop(),
		volver = el.restablecer and function(f) el.restablecer(f) end or nil })
	return true
end
