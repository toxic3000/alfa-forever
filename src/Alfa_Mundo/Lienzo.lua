-- Alfa - Mundo: el arte del mapa continuo (Toxic / La Jauría). GPL-3.0.
--
-- Un lienzo del tamaño del arte del mundo (947), escalado para el zoom
-- (SetScale, como el ScrollContainer de Blizzard). Capas, de
-- abajo arriba, y el zoom en que entra cada una (1 = el mundo entero cabe):
--   mundo        el arte del mapa del mundo, siempre
--   continentes  su arte (CONT); cubren el mundo con más detalle
--   bases        el arte base de cada zona recortado a su territorio: solo
--                con las texturas de detalle (MapTerritory) presentes
--   zonas        los recuadros de exploración de cada zona (DETALLE), todos
--                si "Zonas sin descubrir" está encendido (datos del motor,
--                UI/ZoneArtOverlays.lua), o solo los explorados
--   ciudades     el mapa de cada ciudad cuando llena parte de la vista
-- Sin las texturas de detalle el mapa sigue completo: entre zona y zona se
-- ve el arte del continente (más suave), nunca un hueco.
--
-- Una zona arma sus texturas la primera vez que entra en la vista, y sus
-- archivos se cargan unos pocos por cuadro (POR_CUADRO), apareciendo con
-- un fundido, para que abrir el mapa no trabe el juego (ver CREDITOS.md).
-- Una zona fuera de la vista se guarda en un marco oculto sin anclas, así
-- el juego no la vuelve a acomodar en cada zoom.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local Geo = M.Geo

local type, pairs, ipairs, pcall, min, max, ceil, floor = type, pairs, ipairs, pcall, math.min, math.max, math.ceil, math.floor

local Lz = {}
M.Lienzo = Lz

-- Texturas de detalle de terceros incluidas en este addon con su licencia
-- (VENDOR.md); su carpeta conserva el nombre de su origen.
local TX = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Territorios\\"
Lz.MEDIA_TEXTURAS = TX
-- Zonas con máscara de territorio (MapTerritory).
local TERRITORIOS = {}
for _, id in ipairs({ 1411, 1412, 1413, 1416, 1417, 1418, 1419, 1420, 1421, 1422, 1423, 1424, 1425, 1426, 1427,
	1428, 1429, 1430, 1431, 1432, 1433, 1434, 1435, 1436, 1437, 1438, 1439, 1440, 1441, 1442, 1443, 1444, 1445,
	1446, 1447, 1448, 1449, 1450, 1451, 1452, 2482, 2521, 2548, 2652 }) do TERRITORIOS[id] = true end
-- Ciudades con su propia máscara (MapCityMask); las demás, el borde redondo.
local CIUDAD_MASCARA = { [1454] = true, [1455] = true, [1456] = true, [1458] = true }

local CONT = { 1.12, 1.6 }      -- zoom en que entra el arte de los continentes
local DETALLE = { 2.4, 3.6 }    -- ... y el de las zonas
local CIUDAD = { 0.16, 0.36 }   -- parte del ancho de la vista que llena una ciudad para mostrarse
local MARGEN = 0.12             -- parte de la vista que se arma de más a cada lado
local POR_CUADRO = 40           -- archivos que se piden por cuadro
local ZONAS_POR_CUADRO = 3      -- zonas que se arman por cuadro (crear sus texturas)
local APARICION = 0.25          -- segundos del fundido al llegar un archivo

local vista, lienzo, sotano
local capa = {}                 -- nombre -> marco
local W, H = 1002, 668
local zonas, ciudades = {}, {}  -- registros por mapa
local contArte = {}             -- continente -> marco con su arte
local hecho = false             -- mundo y registros armados
local ahora = { k = 1, z = 1, x0 = 0, y0 = 0, x1 = 1, y1 = 1, vw = 1, vh = 1 }
local cola, colaEn = {}, 1
local fundiendo, nFundiendo = {}, 0
local cargador
local hayTexturas
local presupuesto, pendiente = ZONAS_POR_CUADRO, false

local function rampa(v, r)
	if v <= r[1] then return 0 end
	if v >= r[2] then return 1 end
	local t = (v - r[1]) / (r[2] - r[1])
	return t * t * (3 - 2 * t)
end
Lz.Rampa = rampa

---------------------------------------------------------------------------
-- Texturas y carga escalonada
---------------------------------------------------------------------------

local function textura(padre, sub)
	local t = padre:CreateTexture(nil, "ARTWORK", nil, sub or 0)
	if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
	if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
	return t
end

local function encolar(t, archivo)
	t.amArchivo = archivo
	t:SetAlpha(0)
	cola[#cola + 1] = t
	if cargador then cargador:Show() end
end

local function cargar()
	local n, t0 = 0, GetTime and GetTime() or 0
	while colaEn <= #cola and n < POR_CUADRO do
		local t = cola[colaEn]
		colaEn = colaEn + 1
		if t.amArchivo then
			t:SetTexture(t.amArchivo, nil, nil, "TRILINEAR")
			t.amArchivo = nil
			fundiendo[t] = t0
			nFundiendo = nFundiendo + 1
			n = n + 1
		end
	end
	if colaEn > #cola then
		for i = #cola, 1, -1 do cola[i] = nil end
		colaEn = 1
	end
	for t, desde in pairs(fundiendo) do
		local f = (t0 - desde) / APARICION
		if f >= 1 then
			t:SetAlpha(1)
			fundiendo[t] = nil
			nFundiendo = nFundiendo - 1
		else
			t:SetAlpha(f * f * (3 - 2 * f))
		end
	end
	if #cola == 0 and nFundiendo == 0 and cargador then cargador:Hide() end
end

-- Si las texturas de detalle están en la carpeta de Alfa_Mundo. El cliente
-- dice false al poner un archivo que no existe (SetTexture -> success).
local sonda
function Lz.HayTexturas()
	if hayTexturas ~= nil then return hayTexturas end
	sonda = sonda or CreateFrame("Frame")
	sonda:Hide()
	local t = sonda:CreateTexture()
	local ok, si = pcall(t.SetTexture, t, TX .. "MapFeatherRound")
	hayTexturas = ok and si ~= false and si ~= nil
	t:SetTexture(nil)
	return hayTexturas
end

local function detalleFino()
	return A.Get("mundo.detalle") ~= false and Lz.HayTexturas()
end

---------------------------------------------------------------------------
-- Arte de un mapa en un rectángulo (sus mosaicos, como MapCanvasDetailLayer:
-- archivos completos, recortados al borde de la capa)
---------------------------------------------------------------------------

local function mosaicos(padre, mapa, x, y, w, h, mascara, sub)
	local info, archivos = Geo.Capa(mapa)
	if not info then return 0 end
	local tw, th, lw, lh = info.tileWidth, info.tileHeight, info.layerWidth, info.layerHeight
	local sx, sy = w / lw, h / lh
	local cols, filas = ceil(lw / tw), ceil(lh / th)
	local n = 0
	for j = 1, filas do
		local ph = (j < filas) and th or (lh - (filas - 1) * th)
		for k = 1, cols do
			local pw = (k < cols) and tw or (lw - (cols - 1) * tw)
			local archivo = archivos[(j - 1) * cols + k]
			if archivo and pw > 0 and ph > 0 then
				local t = textura(padre, sub)
				t:SetTexCoord(0, pw / tw, 0, ph / th)
				t:SetSize(pw * sx, ph * sy)
				t:SetPoint("TOPLEFT", padre, "TOPLEFT", x + (k - 1) * tw * sx, -(y + (j - 1) * th * sy))
				if mascara then t:AddMaskTexture(mascara) end
				encolar(t, archivo)
				n = n + 1
			end
		end
	end
	return n
end

local function mascara(padre, archivo)
	if not (padre.CreateMaskTexture and archivo) then return nil end
	local m = padre:CreateMaskTexture()
	m:SetTexture(archivo, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	m:SetAllPoints(padre)
	return m
end

---------------------------------------------------------------------------
-- Zonas: los recuadros de exploración (con el motor: todos)
---------------------------------------------------------------------------

local function clave(w, h, x, y) return x .. ":" .. y .. ":" .. w .. ":" .. h end

local function explorados(mapa)
	local X = C_MapExplorationInfo
	if not (type(X) == "table" and type(X.GetExploredMapTextures) == "function") then return nil end
	local ok, lista = pcall(X.GetExploredMapTextures, mapa)
	return ok and type(lista) == "table" and lista or nil
end

-- ctx: el registro de la zona; place(ctx, archivo, x, y, w, h, derecha, abajo)
local function ponerRecuadro(z, archivo, x, y, w, h, derecha, abajo)
	local n = z.n + 1
	z.n = n
	local t = z.tex[n]
	if not t then
		t = textura(z.marco, 0)
		z.tex[n] = t
	end
	t:SetDrawLayer("ARTWORK", z.sub or 0)
	t:SetTexCoord(0, derecha, 0, abajo)
	t:SetSize(w * z.sx, h * z.sy)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", z.marco, "TOPLEFT", x * z.sx, -y * z.sy)
	local c = z.tinte
	if c then t:SetVertexColor(c[1], c[2], c[3], 1) else t:SetVertexColor(1, 1, 1, 1) end
	t:Show()
	encolar(t, archivo)
end

local function tinteSinExplorar()
	local T = A.Theme
	if T and type(T.Color) == "function" then
		local ok, r, g, b = pcall(T.Color, "mapUnexplored")
		if ok and type(r) == "number" then return { r, g, b } end
	end
	return { 0.6, 0.66, 0.9 }
end

local function armarZona(z)
	z.hecho = true
	z.n = 0
	local info = Geo.Capa(z.id)
	if not info then
		z.sinArte = true
		return
	end
	local tw, th = info.tileWidth, info.tileHeight
	z.sx, z.sy = z.w / info.layerWidth, z.h / info.layerHeight
	-- Ciudad: su mapa entero, con su máscara o el borde redondo.
	if z.ciudad then
		if not z.base then
			local m
			if Lz.HayTexturas() then
				m = mascara(z.marco, CIUDAD_MASCARA[z.id] and (TX .. "MapCityMask\\" .. z.id) or (TX .. "MapFeatherRound"))
			end
			mosaicos(z.marco, z.id, 0, 0, z.w, z.h, m, 0)
			z.base = true
		end
		return
	end
	-- El arte base recortado a su territorio, con las texturas de detalle.
	if detalleFino() and TERRITORIOS[z.id] and not z.baseMarco then
		local b = CreateFrame("Frame", nil, sotano)
		b:SetSize(z.w, z.h)
		z.baseMarco = b
		mosaicos(b, z.id, 0, 0, z.w, z.h, mascara(b, TX .. "MapTerritory\\" .. z.id), 0)
	end
	local ZA = A.UI and A.UI.ZoneArt
	local cada = ZA and type(ZA.EachOverlayTile) == "function" and ZA.EachOverlayTile
	if not cada then return end
	local modo = A.Get("maps.reveal")
	local lista = explorados(z.id)
	local todos = modo ~= "off" and type(ZA.FullOverlays) == "function" and ZA.FullOverlays(z.id, tw, th) or nil
	if type(todos) == "table" then
		local visto = {}
		if lista then
			for _, e in ipairs(lista) do
				if type(e) == "table" then visto[clave(e.textureWidth, e.textureHeight, e.offsetX, e.offsetY)] = true end
			end
		end
		local tinte = modo == "tint" and tinteSinExplorar() or nil
		for i = 3, #todos do
			local o = todos[i]
			if type(o) == "table" then
				z.tinte = (tinte and not visto[clave(o[1], o[2], o[3], o[4])]) and tinte or nil
				z.sub = 0
				cada(tw, th, o[1], o[2], o[3], o[4], o, 5, ponerRecuadro, z)
			end
		end
	elseif lista then
		z.tinte = nil
		for _, e in ipairs(lista) do
			if type(e) == "table" and not e.isShownByMouseOver and type(e.fileDataIDs) == "table" then
				z.sub = e.isDrawOnTopLayer and 1 or 0
				cada(tw, th, e.textureWidth or 0, e.textureHeight or 0, e.offsetX or 0, e.offsetY or 0, e.fileDataIDs, 1, ponerRecuadro, z)
			end
		end
	end
	z.tinte = nil
	for i = z.n + 1, #z.tex do z.tex[i]:Hide() end
end

---------------------------------------------------------------------------
-- Armado
---------------------------------------------------------------------------

local function registro(id, ciudad, cont)
	local l, r, t, b = Geo.Rect(id)
	if not l then return nil end
	local z = { id = id, ciudad = ciudad, cont = cont, l = l * W, t = t * H, w = (r - l) * W, h = (b - t) * H, tex = {}, n = 0 }
	z.marco = CreateFrame("Frame", nil, sotano)
	z.marco:SetSize(z.w, z.h)
	return z
end

local function armarRegistros()
	if hecho then return true end
	local info = Geo.Capa(Geo.MUNDO)
	if not info then return false end
	W, H = info.layerWidth, info.layerHeight
	lienzo:SetSize(W, H)
	hecho = true
	mosaicos(capa.mundo, Geo.MUNDO, 0, 0, W, H, nil, 0)
	for _, cont in ipairs(Geo.Continentes()) do
		for _, zona in ipairs(Geo.Zonas(cont)) do
			local z = registro(zona.id, zona.ciudad, cont)
			if z then
				if zona.ciudad then ciudades[#ciudades + 1] = z else zonas[#zonas + 1] = z end
			end
		end
	end
	return true
end

local function armarContinente(cont)
	if contArte[cont] then return end
	local l, r, t, b = Geo.Rect(cont)
	if not l then
		contArte[cont] = false
		return
	end
	local f = CreateFrame("Frame", nil, capa.cont)
	f:SetPoint("TOPLEFT", lienzo, "TOPLEFT", 0, 0)
	f:SetSize(1, 1)
	contArte[cont] = f
	mosaicos(f, cont, l * W, t * H, (r - l) * W, (b - t) * H, nil, 0)
end

function Lz.Crear(padre)
	if vista then return hecho and lienzo or nil end
	vista = padre
	if vista.SetClipsChildren then vista:SetClipsChildren(true) end
	lienzo = CreateFrame("Frame", nil, vista)
	lienzo:SetSize(W, H)
	lienzo:SetPoint("TOPLEFT", vista, "TOPLEFT", 0, 0)
	sotano = CreateFrame("Frame", nil, vista)
	sotano:Hide()
	local base = lienzo:GetFrameLevel()
	for i, nombre in ipairs({ "mundo", "cont", "bases", "zonas", "ciudades" }) do
		local f = CreateFrame("Frame", nil, lienzo)
		f:SetAllPoints(lienzo)
		f:SetFrameLevel(base + i * 2)
		capa[nombre] = f
	end
	cargador = CreateFrame("Frame", nil, vista)
	cargador:Hide()
	cargador:SetScript("OnUpdate", A.Safe and A.Safe(cargar) or cargar)
	if not armarRegistros() then return nil end
	return lienzo
end

function Lz.Tamano() return W, H end
function Lz.Listo() return hecho end

---------------------------------------------------------------------------
-- Colocar la vista: escala, posición, fundidos y qué zonas se ven
---------------------------------------------------------------------------

local function guardar(z)
	if not z.visible then return end
	z.visible = false
	z.marco:SetParent(sotano)
	z.marco:ClearAllPoints()
	if z.baseMarco then
		z.basePuesta = false
		z.baseMarco:SetParent(sotano)
		z.baseMarco:ClearAllPoints()
	end
end

local function colocarBase(z)
	local b = z.baseMarco
	if not b or z.basePuesta then return end
	z.basePuesta = true
	b:SetParent(capa.bases)
	b:SetFrameLevel(capa.bases:GetFrameLevel() + 1)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", lienzo, "TOPLEFT", z.l, -z.t)
end

local function sacar(z, padre)
	if not z.hecho then
		-- Unas pocas por cuadro: abrir el mapa sobre un continente no traba.
		if presupuesto <= 0 then
			pendiente = true
			return
		end
		presupuesto = presupuesto - 1
		armarZona(z)
	end
	if z.visible then return end
	z.visible = true
	z.marco:SetParent(padre)
	z.marco:SetFrameLevel(padre:GetFrameLevel() + 1)
	z.marco:ClearAllPoints()
	z.marco:SetPoint("TOPLEFT", lienzo, "TOPLEFT", z.l, -z.t)
	colocarBase(z)
end

local function cruza(z, x0, y0, x1, y1)
	return z.l < x1 and z.l + z.w > x0 and z.t < y1 and z.t + z.h > y0
end

-- cu, cv: el centro (0..1 del mundo); k: unidades de la vista por unidad del
-- lienzo; vw, vh: el tamaño de la vista; z: el zoom (1 = el mundo cabe).
function Lz.Colocar(cu, cv, k, vw, vh, z)
	if not hecho or not (k and k > 0) then return end
	presupuesto, pendiente = ZONAS_POR_CUADRO, false
	lienzo:SetScale(k)
	lienzo:ClearAllPoints()
	lienzo:SetPoint("TOPLEFT", vista, "TOPLEFT", vw / (2 * k) - cu * W, -(vh / (2 * k) - cv * H))
	local mx, my = vw / (2 * k) * (1 + MARGEN * 2), vh / (2 * k) * (1 + MARGEN * 2)
	local x0, x1, y0, y1 = cu * W - mx, cu * W + mx, cv * H - my, cv * H + my
	ahora.k, ahora.z, ahora.vw, ahora.vh = k, z, vw, vh
	ahora.x0, ahora.x1, ahora.y0, ahora.y1 = x0, x1, y0, y1
	-- Continentes
	local ac = rampa(z, CONT)
	capa.cont:SetAlpha(ac)
	capa.cont:SetShown(ac > 0.003)
	if ac > 0 then
		for _, cont in ipairs(Geo.Continentes()) do armarContinente(cont) end
	end
	-- Zonas
	local ad = rampa(z, DETALLE)
	capa.zonas:SetAlpha(ad)
	capa.bases:SetAlpha(ad)
	capa.zonas:SetShown(ad > 0.003)
	capa.bases:SetShown(ad > 0.003 and detalleFino())
	for _, zz in ipairs(zonas) do
		if ad > 0.003 and cruza(zz, x0, y0, x1, y1) then sacar(zz, capa.zonas) else guardar(zz) end
	end
	-- Ciudades: cuando llenan parte de la vista
	for _, c in ipairs(ciudades) do
		local a = rampa(c.w * k / max(1, vw), CIUDAD)
		if a > 0.003 and cruza(c, x0, y0, x1, y1) then
			sacar(c, capa.ciudades)
			c.marco:SetAlpha(a)
		else
			guardar(c)
		end
	end
end

-- La exploración o "Zonas sin descubrir" cambió: se rearman las zonas (las
-- que se ven ahora, las demás al volver a la vista).
function Lz.Rehacer()
	for _, z in ipairs(zonas) do
		guardar(z)
		z.hecho = false
		for i = 1, #z.tex do z.tex[i]:Hide() end
	end
end

-- Quedan zonas por armar: la vista se vuelve a colocar en el siguiente cuadro.
function Lz.Pendiente() return pendiente end

-- Detalle fino encendido o apagado: las bases se muestran o no.
function Lz.Detalle()
	local on = detalleFino()
	capa.bases:SetShown(on and capa.zonas:IsShown())
	if on then Lz.Rehacer() end
end

-- La zona más pequeña que contiene el punto, por rectángulo (para el zoom).
function Lz.RectZona(mapa)
	for _, z in ipairs(zonas) do if z.id == mapa then return z.l / W, z.t / H, z.w / W, z.h / H end end
	for _, z in ipairs(ciudades) do if z.id == mapa then return z.l / W, z.t / H, z.w / W, z.h / H end end
	local l, r, t, b = Geo.Rect(mapa)
	if l then return l, t, r - l, b - t end
	return nil
end

-- Las zonas armadas, para las etiquetas: { id, l, t, w, h } en unidades del lienzo.
function Lz.Zonas() return zonas end
function Lz.Ciudades() return ciudades end
function Lz.Ahora() return ahora end
