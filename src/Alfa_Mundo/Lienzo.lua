-- Alfa - Mundo: el arte del mapa continuo (toxic3000 / La Jauría). GPL-3.0.
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
--   terreno      los mosaicos del minimapa (TERRENO), con el estilo "terreno"
--                (mundo.estiloMapa): el mismo suelo, tonos y montañas que el
--                minimapa. Donde no hay mosaico (mar abierto) se sigue viendo
--                el arte de Blizzard de abajo
--   ciudades     el mapa de cada ciudad cuando llena parte de la vista (encima
--                del terreno: los mosaicos no traen el interior de las ciudades)
-- Sin las texturas de detalle el mapa sigue completo: entre zona y zona se
-- ve el arte del continente (más suave), nunca un hueco.
--
-- Un mapa de una pieza (1.2.1): con el estilo terreno, las bases y las zonas
-- no se pintan (arteDeZonas: cada zona tiene sus tonos y sus orillas, y
-- juntas se veían como pedazos pegados); del continente se pasa directo al
-- terreno. Cada mosaico del terreno se mete medio texel bajo su vecino (sin
-- rayas) y difumina los lados que dan a un hueco (Lz.Bordes, máscaras de
-- tools/bordes.py). Una tanda de texturas que espera a una que no llega
-- aparece con lo que llegó (ESPERA_TANDA): nunca queda un cuadro vacío.
--
-- El terreno (datos en TerrenoDatos.lua, de TerrainWorldMap, ver CREDITOS.md):
-- cada mosaico mapCC_FF mide 533,33 yardas en una rejilla de 64 x 64; su
-- esquina está en Y = (32 - CC) * 533,33 y X = (32 - FF) * 533,33 del mundo.
-- Se coloca en el lienzo por el mapa del continente (1414, 1415): sus dos
-- esquinas en yardas (C_Map.GetWorldPosFromMapPos, por Compat.MapToWorld) y
-- su rectángulo en 947 (Geo.Rect). Los de la orilla se recortan al
-- rectángulo del continente con SetTexCoord. En Forever los mosaicos solo
-- cargan por su fileID numérico. Solo se cargan los que se ven (por la cola
-- de POR_CUADRO, con su fundido) y se sueltan los que quedan lejos.
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

local type, pairs, ipairs, pcall, min, max, ceil, floor, abs = type, pairs, ipairs, pcall, math.min, math.max, math.ceil, math.floor, math.abs

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
local TERRENO = { 4.5, 7 }      -- zoom en que entra el terreno (los mosaicos del minimapa)
local YARDAS = 1600 / 3         -- lado de un mosaico del minimapa (533,33 yardas)
local TEXELES = 256             -- lado de la textura de un mosaico
local GUARDAR = 0.35            -- parte de la vista, más allá de lo que se arma, en que un mosaico sigue cargado
local TOPE_MOSAICOS = 600       -- con más cargados, se sueltan todos los que no se ven (~43 KB cada uno)
local PRUEBA = 16               -- si fallan los primeros mosaicos, todos, el terreno se apaga solo
local MARGEN = 0.12             -- parte de la vista que se arma de más a cada lado
local POR_CUADRO = 40           -- archivos que se piden por cuadro
local PISO = 6                  -- niveles de marco por capa: la capa y hasta 5 niveles de zona (nivelDe)
Lz.NIVELES = 7 * PISO           -- niveles que ocupa el lienzo sobre la vista (lo de encima va más arriba)
local ZONAS_POR_CUADRO = 3      -- zonas que se arman por cuadro (crear sus texturas)
local APARICION = 0.25          -- segundos del fundido al llegar un archivo
local ESPERA_TANDA = 2          -- segundos que una tanda espera a la última: después aparece lo que llegó
local ENCIMA = 0.5              -- texeles que un mosaico del terreno se mete bajo su vecino (sin rayas)
-- Las orillas de un mosaico junto a un hueco del terreno se difuminan (1.2.1):
-- una máscara por combinación de lados (N = 1, E = 2, S = 4, O = 8).
local BORDES = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Borde\\borde-"

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
local estilo = "terreno"        -- mundo.estiloMapa: "terreno" | "clasico"

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

-- Tandas (1.1.8): lo que se pide en una misma colocación aparece junto,
-- cuando ya llegó todo, en vez de un cuadrito a la vez (se veía un tablero
-- de ajedrez al acercar o al cargar el terreno).
local tanda = 0            -- la tanda que se arma ahora (sube en cada Lz.Colocar)
local pendientes = {}      -- tanda -> texturas pedidas que aún no llegan
local miembros = {}        -- tanda -> { textura, ... }
local desde = {}           -- tanda -> cuándo se pidió su primera textura

local function empezarFundido(t, t0)
	if not fundiendo[t] then nFundiendo = nFundiendo + 1 end
	fundiendo[t] = t0
end

-- La tanda k aparece con lo que ya llegó (completa, o cansada de esperar).
local function soltarTanda(k, t0)
	pendientes[k], desde[k] = nil, nil
	for _, m in ipairs(miembros[k] or {}) do
		if m.amListo then
			m.amListo = nil
			empezarFundido(m, t0)
		end
	end
	miembros[k] = nil
end

-- Una textura de la tanda llegó (o se soltó sin llegar): si era la última,
-- toda la tanda empieza a aparecer junta. Si su tanda ya apareció sin ella
-- (esperó más de ESPERA_TANDA), aparece sola: nunca queda un hueco (1.2.1).
local function llego(t, t0)
	local k = t.amTanda
	if not k then return end
	t.amTanda = nil
	if pendientes[k] == nil then
		if t.amListo then
			t.amListo = nil
			empezarFundido(t, t0)
		end
		return
	end
	local n = pendientes[k] - 1
	if n > 0 then
		pendientes[k] = n
		return
	end
	soltarTanda(k, t0)
end

local function encolar(t, archivo)
	if t.amArchivo and t.amTanda then
		-- Ya esperaba en una tanda: solo cambia el archivo.
		t.amArchivo = archivo
		return
	end
	t.amArchivo = archivo
	t.amListo = nil
	t:SetAlpha(0)
	t.amTanda = tanda
	pendientes[tanda] = (pendientes[tanda] or 0) + 1
	if not desde[tanda] then desde[tanda] = GetTime and GetTime() or 0 end
	local lista = miembros[tanda]
	if not lista then
		lista = {}
		miembros[tanda] = lista
	end
	lista[#lista + 1] = t
	cola[#cola + 1] = t
	if cargador then cargador:Show() end
end

local function cargar()
	local n, t0 = 0, GetTime and GetTime() or 0
	while colaEn <= #cola and n < POR_CUADRO do
		local t = cola[colaEn]
		colaEn = colaEn + 1
		if t.amArchivo then
			-- CLAMP: el filtro nunca toma la orilla contraria de la textura, que
			-- dejaba una línea fina entre mosaicos (1.1.7).
			local ok = t:SetTexture(t.amArchivo, "CLAMP", "CLAMP", "TRILINEAR")
			t.amArchivo = nil
			n = n + 1
			-- Aparece con su tanda (llego); sin tanda, sola, como antes.
			if t.amTanda then
				t.amListo = true
				llego(t, t0)
			else
				empezarFundido(t, t0)
			end
			if t.amComprobar then t.amComprobar(t, ok) end
		end
	end
	if colaEn > #cola then
		for i = #cola, 1, -1 do cola[i] = nil end
		colaEn = 1
	end
	-- Una tanda que espera demasiado a su última textura aparece con lo que
	-- llegó: si una no llega nunca, el resto no se queda escondido (1.2.1).
	for k, t1 in pairs(desde) do
		if t0 - t1 > ESPERA_TANDA then soltarTanda(k, t0) end
	end
	for t, inicio in pairs(fundiendo) do
		local f = (t0 - inicio) / APARICION
		if f >= 1 then
			t:SetAlpha(1)
			fundiendo[t] = nil
			nFundiendo = nFundiendo - 1
		else
			t:SetAlpha(f * f * (3 - 2 * f))
		end
	end
	if #cola == 0 and nFundiendo == 0 and next(pendientes) == nil and cargador then cargador:Hide() end
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

-- Hasta dónde se lee una textura recortada: `usado` texeles de `total`. Si el
-- recorte queda dentro del archivo, medio texel antes de la orilla, para que
-- el filtro no mezcle el relleno vacío de más allá (un halo oscuro). 1.1.7.
function Lz.Recorte(usado, total)
	if not (usado and total and total > 0) or usado >= total then return 1 end
	return max(0, usado - 0.5) / total
end

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
				t:SetTexCoord(0, Lz.Recorte(pw, tw), 0, Lz.Recorte(ph, th))
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
	-- derecha = w / (ancho del archivo): el mismo medio texel en el recorte.
	local fw = (derecha and derecha > 0) and w / derecha or w
	local fh = (abajo and abajo > 0) and h / abajo or h
	t:SetTexCoord(0, Lz.Recorte(w, fw), 0, Lz.Recorte(h, fh))
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
-- Terreno: los mosaicos del minimapa (estilo "terreno")
---------------------------------------------------------------------------

local terreno             -- { registro de cada continente } (armarTerreno)
local terrenoMalo = false -- ningún mosaico cargó: la capa queda apagada
local probados, buenos = 0, 0
local activos, nActivos = {}, 0 -- mosaicos con su archivo puesto o pedido
local vuelta = 0          -- sube en cada Colocar: qué mosaicos se vieron

local function terrenoActivo() return estilo == "terreno" and not terrenoMalo end

local function soltarMosaico(m)
	if activos[m] then
		activos[m] = nil
		nActivos = nActivos - 1
	end
	m.cargado = false
	local t = m.tex
	if not t then return end
	if fundiendo[t] then
		fundiendo[t] = nil
		nFundiendo = nFundiendo - 1
	end
	t.amArchivo = nil
	t.amListo = nil
	-- Soltada antes de llegar: su tanda no la espera más.
	if t.amTanda then llego(t, GetTime and GetTime() or 0) end
	t:SetTexture(nil)
	t:Hide()
end

local function soltarTerreno()
	for m in pairs(activos) do soltarMosaico(m) end
end

-- Al llegar el archivo de un mosaico: si el cliente no lo pudo poner (false)
-- o la textura quedó sin fileID, ese mosaico se oculta y abajo queda el arte.
-- Si fallan los primeros PRUEBA, todos, el terreno se apaga sin avisar.
local function comprobar(t, ok)
	local m = t.amMosaico
	if not m then return end
	local bien = ok ~= false
	if bien and t.GetTextureFileID then
		local si, id = pcall(t.GetTextureFileID, t)
		if si and id == nil then bien = false end
	end
	probados = probados + 1
	if bien then
		buenos = buenos + 1
		return
	end
	m.malo = true
	soltarMosaico(m)
	if buenos == 0 and probados >= PRUEBA then
		terrenoMalo = true
		soltarTerreno()
		if capa.terreno then capa.terreno:Hide() end
		if type(A.Debug) == "function" then A.Debug("Alfa_Mundo: los mosaicos del terreno no cargan; queda el arte del juego") end
	end
end

-- Cada continente con datos: dónde cae la rejilla de mosaicos en el lienzo.
--   x = ax + bx * col, y = ay + by * fila (la esquina de arriba a la izquierda)
local function armarTerreno()
	if terreno then return terreno end
	terreno = {}
	local datos, C = M.TERRENO, A.Compat
	if type(datos) ~= "table" or not (C and type(C.MapToWorld) == "function") then return terreno end
	for cont, lista in pairs(datos) do
		local l, r, t, b = Geo.Rect(cont)
		-- Las esquinas del mapa del continente en yardas: X (norte) e Y (oeste).
		local ok1, c1, xa, ya = pcall(C.MapToWorld, cont, 0, 0)
		local ok2, c2, xb, yb = pcall(C.MapToWorld, cont, 100, 100)
		if l and ok1 and ok2 and c1 ~= nil and c1 == c2 and type(xa) == "number" and type(ya) == "number"
			and type(xb) == "number" and type(yb) == "number" and xb ~= xa and yb ~= ya then
			local cx0, cy0, cw, ch = l * W, t * H, (r - l) * W, (b - t) * H
			local reg = {
				bx = -YARDAS / (yb - ya) * cw, ax = cx0 + (32 * YARDAS - ya) / (yb - ya) * cw,
				by = -YARDAS / (xb - xa) * ch, ay = cy0 + (32 * YARDAS - xa) / (xb - xa) * ch,
				x0 = cx0, x1 = cx0 + cw, y0 = cy0, y1 = cy0 + ch, mos = {},
			}
			for i = 1, #lista - 3, 4 do
				local col, fila, n, id = lista[i], lista[i + 1], lista[i + 2], lista[i + 3]
				for j = 0, n - 1 do reg.mos[col * 64 + fila + j] = { col = col, fila = fila + j, id = id + j } end
			end
			reg.marco = CreateFrame("Frame", nil, capa.terreno)
			reg.marco:SetPoint("TOPLEFT", lienzo, "TOPLEFT", 0, 0)
			reg.marco:SetSize(1, 1)
			terreno[#terreno + 1] = reg
		end
	end
	return terreno
end

-- Los vecinos de un mosaico en la pantalla (1.2.1): -> hayN, hayE, hayS, hayO.
-- La columna crece hacia la derecha si bx > 0 y la fila hacia abajo si by > 0.
local function vecinos(reg, m)
	local mos = reg.mos
	local function hay(col, fila)
		if col < 0 or col > 63 or fila < 0 or fila > 63 then return false end
		local v = mos[col * 64 + fila]
		return v ~= nil and not v.malo
	end
	local dc, df = reg.bx > 0 and 1 or -1, reg.by > 0 and 1 or -1
	return hay(m.col, m.fila - df), hay(m.col + dc, m.fila), hay(m.col, m.fila + df), hay(m.col - dc, m.fila)
end

-- La máscara de un mosaico: los lados que dan a un hueco (N = 1, E = 2,
-- S = 4, O = 8) se difuminan hacia el arte de abajo, así un hueco no deja
-- un cuadro de orillas duras. 0: ninguno.
function Lz.Bordes(reg, m)
	local n, e, s, o = vecinos(reg, m)
	return (n and 0 or 1) + (e and 0 or 2) + (s and 0 or 4) + (o and 0 or 8), n, e, s, o
end

-- El mosaico en la vista: su textura se arma la primera vez (recortada al
-- rectángulo del continente) y su archivo se pide por la cola.
--
-- Sin rayas entre mosaicos (1.2.1): cada lado que da a un vecino se mete
-- ENCIMA texeles bajo él, leyendo el texel de su orilla (CLAMP: la textura no
-- se estira ni se mueve contra los pines). Los lados que dan a un hueco se
-- difuminan (Lz.Bordes).
local function ponerMosaico(reg, m)
	local t = m.tex
	if not t then
		local tx0, ty0 = reg.ax + reg.bx * m.col, reg.ay + reg.by * m.fila
		local tx1, ty1 = tx0 + reg.bx, ty0 + reg.by
		if tx1 < tx0 then tx0, tx1 = tx1, tx0 end
		if ty1 < ty0 then ty0, ty1 = ty1, ty0 end
		local ix0, ix1 = max(tx0, reg.x0), min(tx1, reg.x1)
		local iy0, iy1 = max(ty0, reg.y0), min(ty1, reg.y1)
		if ix1 - ix0 < 1e-3 or iy1 - iy0 < 1e-3 then
			m.malo = true -- fuera del mapa del continente
			return
		end
		local dw, dh = tx1 - tx0, ty1 - ty0
		local mascara, n, e, s, o = Lz.Bordes(reg, m)
		local ex, ey = dw / TEXELES * ENCIMA, dh / TEXELES * ENCIMA
		-- Solo los lados enteros (no recortados por el continente) con vecino.
		if o and ix0 == tx0 then ix0 = ix0 - ex end
		if e and ix1 == tx1 then ix1 = ix1 + ex end
		if n and iy0 == ty0 then iy0 = iy0 - ey end
		if s and iy1 == ty1 then iy1 = iy1 + ey end
		t = textura(reg.marco, 0)
		t:SetTexCoord((ix0 - tx0) / dw, (ix1 - tx0) / dw, (iy0 - ty0) / dh, (iy1 - ty0) / dh)
		t:SetSize(ix1 - ix0, iy1 - iy0)
		t:SetPoint("TOPLEFT", reg.marco, "TOPLEFT", ix0, -iy0)
		if mascara > 0 and reg.marco.CreateMaskTexture and t.AddMaskTexture then
			local mk = reg.marco:CreateMaskTexture()
			mk:SetTexture(BORDES .. mascara, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mk:SetAllPoints(t)
			t:AddMaskTexture(mk)
			t.amMascara = mascara
		end
		t.amMosaico, t.amComprobar = m, comprobar
		m.tex, m.cx, m.cy = t, (tx0 + tx1) / 2, (ty0 + ty1) / 2
	end
	m.visto = vuelta
	if not m.cargado then
		m.cargado = true
		activos[m] = true
		nActivos = nActivos + 1
		t:Show()
		encolar(t, m.id)
	elseif not t:IsShown() then
		t:Show()
	end
end

-- a: el fundido del terreno; x0..y1: lo que se arma; g*: hasta dónde se guarda.
local function colocarTerreno(a, x0, y0, x1, y1, gx0, gy0, gx1, gy1)
	vuelta = vuelta + 1
	if a > 0.003 then
		for _, reg in ipairs(armarTerreno()) do
			local vx0, vx1 = max(x0, reg.x0), min(x1, reg.x1)
			local vy0, vy1 = max(y0, reg.y0), min(y1, reg.y1)
			if vx1 > vx0 and vy1 > vy0 then
				local c0, c1 = floor((vx0 - reg.ax) / reg.bx), floor((vx1 - reg.ax) / reg.bx)
				local f0, f1 = floor((vy0 - reg.ay) / reg.by), floor((vy1 - reg.ay) / reg.by)
				if c1 < c0 then c0, c1 = c1, c0 end
				if f1 < f0 then f0, f1 = f1, f0 end
				local mos = reg.mos
				for col = max(0, c0), min(63, c1) do
					for fila = max(0, f0), min(63, f1) do
						local m = mos[col * 64 + fila]
						if m and not m.malo then ponerMosaico(reg, m) end
					end
				end
			end
		end
	end
	-- Lo que ya no se ve se oculta; si quedó lejos, o hay demasiados, se suelta.
	local todos = a <= 0.003 or nActivos > TOPE_MOSAICOS
	for m in pairs(activos) do
		if m.visto ~= vuelta then
			if todos or m.cx < gx0 or m.cx > gx1 or m.cy < gy0 or m.cy > gy1 then
				soltarMosaico(m)
			elseif m.tex:IsShown() then
				m.tex:Hide()
			end
		end
	end
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
	-- El nivel de cada zona en su capa (nivelDe): dos zonas que se tocan nunca
	-- comparten nivel, como colorear un mapa. Las grandes primero (abajo), y
	-- por id si empatan, así sale igual en cada sesión.
	for _, lista in ipairs({ zonas, ciudades }) do
		local orden = {}
		for i, z in ipairs(lista) do orden[i] = z end
		table.sort(orden, function(a, b)
			local sa, sb = a.w * a.h, b.w * b.h
			if sa ~= sb then return sa > sb end
			return a.id < b.id
		end)
		for i, z in ipairs(orden) do
			local usados = {}
			for j = 1, i - 1 do
				local o = orden[j]
				if z.l < o.l + o.w and o.l < z.l + z.w and z.t < o.t + o.h and o.t < z.t + z.h then
					usados[o.rango] = true
				end
			end
			local r = 0
			while usados[r] and r < PISO - 2 do r = r + 1 end
			z.rango = r
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
	-- Sus cuatro orillas se funden con el mapa del mundo de abajo (1.2.2): el
	-- rectángulo trae su propio mar y se veía pegado, con la orilla recta.
	-- Una sola máscara del tamaño del continente para todos sus pedazos.
	local x, y, w, h = l * W, t * H, (r - l) * W, (b - t) * H
	local mk
	if f.CreateMaskTexture then
		mk = f:CreateMaskTexture()
		mk:SetTexture(BORDES .. "continente", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mk:SetSize(w, h)
		mk:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
		f.amMascara = mk
	end
	mosaicos(f, cont, x, y, w, h, mk, 0)
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
	for i, nombre in ipairs({ "mundo", "cont", "bases", "zonas", "terreno", "ciudades" }) do
		local f = CreateFrame("Frame", nil, lienzo)
		f:SetAllPoints(lienzo)
		-- Cada capa deja lugar para un nivel propio por zona (ver nivelDe).
		f:SetFrameLevel(base + i * PISO)
		capa[nombre] = f
	end
	cargador = CreateFrame("Frame", nil, vista)
	cargador:Hide()
	cargador:SetScript("OnUpdate", A.Safe and A.Safe(cargar) or cargar)
	Lz.Estilo()
	if not armarRegistros() then return nil end
	return lienzo
end

function Lz.Tamano() return W, H end

-- Lo que falta por aparecer (para pruebas): archivos en cola, tandas
-- esperando y texturas fundiéndose.
function Lz.Cargando()
	local tandas = 0
	for _ in pairs(pendientes) do tandas = tandas + 1 end
	return #cola - colaEn + 1, tandas, nFundiendo
end

-- Píxeles físicos de la pantalla por unidad de la vista.
function Lz.Pixeles()
	local s = vista and vista.GetEffectiveScale and vista:GetEffectiveScale() or 1
	if type(s) ~= "number" or s <= 0 then s = 1 end
	if GetPhysicalScreenSize then
		local ok, _, h = pcall(GetPhysicalScreenSize)
		if ok and type(h) == "number" and h > 0 then return s * h / 768 end
	end
	return s
end
function Lz.Listo() return hecho end

---------------------------------------------------------------------------
-- Colocar la vista: escala, posición, fundidos y qué zonas se ven
---------------------------------------------------------------------------

-- Un nivel de marco propio por zona: dos zonas cuyos rectángulos se tocan ya
-- no comparten nivel (el juego elegía cuál va encima y cambiaba al mover el
-- mapa: parpadeaban las fronteras). Las grandes abajo, las chicas encima.
-- 1.1.7.
local function nivelDe(z, padre)
	return padre:GetFrameLevel() + 1 + min(PISO - 2, z.rango or 0)
end

local function guardar(z)
	if not z.visible then return end
	z.visible = false
	if z.soloVista then
		z.soloVista = nil
		return
	end
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
	b:SetFrameLevel(nivelDe(z, capa.bases))
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", lienzo, "TOPLEFT", z.l, -z.t)
end

-- soloVista: la zona cuenta como a la vista (AlfaMundo.ZonasALaVista) sin
-- poner su arte (el estilo terreno, arteDeZonas).
local function sacar(z, padre, soloVista)
	if soloVista then
		if z.visible and not z.soloVista then guardar(z) end
		z.visible, z.soloVista = true, true
		return
	end
	if z.soloVista then z.visible, z.soloVista = false, nil end
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
	z.marco:SetFrameLevel(nivelDe(z, padre))
	z.marco:ClearAllPoints()
	z.marco:SetPoint("TOPLEFT", lienzo, "TOPLEFT", z.l, -z.t)
	colocarBase(z)
end

local function cruza(z, x0, y0, x1, y1)
	return z.l < x1 and z.l + z.w > x0 and z.t < y1 and z.t + z.h > y0
end

-- El arte de cada zona encima del continente (1.2.1). Cada zona la pintó
-- Blizzard por su lado, con sus tonos y sus orillas: juntas sobre el mapa
-- continuo se veían como pedazos pegados. Con el estilo terreno (y el terreno
-- de verdad disponible) el continente, que es una sola pintura, llega hasta
-- que entra el terreno, que también es continuo. El estilo clásico las sigue
-- mostrando: es el arte pintado de siempre.
local function arteDeZonas()
	return not (terrenoActivo() and #armarTerreno() > 0)
end
Lz.ArteDeZonas = arteDeZonas

-- cu, cv: el centro (0..1 del mundo); k: unidades de la vista por unidad del
-- lienzo; vw, vh: el tamaño de la vista; z: el zoom (1 = el mundo cabe).
function Lz.Colocar(cu, cv, k, vw, vh, z)
	if not hecho or not (k and k > 0) then return end
	presupuesto, pendiente = ZONAS_POR_CUADRO, false
	tanda = tanda + 1
	lienzo:SetScale(k)
	lienzo:ClearAllPoints()
	-- La esquina del lienzo cae en un píxel entero de la pantalla, y los pines
	-- se cuentan desde ahí (Lz.Ahora().ox/oy, Marcas): mapa y pines se mueven
	-- juntos, sin que uno brinque un píxel contra el otro. 1.1.7.
	local px = Lz.Pixeles()
	local ox = floor((vw / 2 - cu * W * k) * px + 0.5) / px
	local oy = floor((vh / 2 - cv * H * k) * px + 0.5) / px
	lienzo:SetPoint("TOPLEFT", vista, "TOPLEFT", ox / k, -(oy / k))
	ahora.ox, ahora.oy, ahora.px = ox, oy, px
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
	-- Zonas (con el estilo terreno solo cuentan como a la vista: arteDeZonas)
	local ad = rampa(z, DETALLE)
	local conArte = arteDeZonas()
	local az = conArte and ad or 0
	capa.zonas:SetAlpha(az)
	capa.bases:SetAlpha(az)
	capa.zonas:SetShown(az > 0.003)
	capa.bases:SetShown(az > 0.003 and detalleFino())
	for _, zz in ipairs(zonas) do
		if ad > 0.003 and cruza(zz, x0, y0, x1, y1) then sacar(zz, capa.zonas, not conArte) else guardar(zz) end
	end
	-- Terreno: encima de las zonas, debajo de las ciudades
	local at = terrenoActivo() and rampa(z, TERRENO) or 0
	capa.terreno:SetAlpha(at)
	capa.terreno:SetShown(at > 0.003)
	local gx, gy = (x1 - x0) * GUARDAR, (y1 - y0) * GUARDAR
	colocarTerreno(at, x0, y0, x1, y1, x0 - gx, y0 - gy, x1 + gx, y1 + gy)
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

---------------------------------------------------------------------------
-- Estilo del mapa y nitidez
---------------------------------------------------------------------------

-- mundo.estiloMapa: "terreno" (como el minimapa) o "clasico" (solo el arte
-- pintado de Blizzard). Se lee al crear el lienzo y al cambiar el ajuste.
function Lz.Estilo()
	local e = A.Get("mundo.estiloMapa")
	estilo = (e == "clasico") and "clasico" or "terreno"
	if not terrenoActivo() then
		soltarTerreno()
		if capa.terreno then capa.terreno:Hide() end
	end
	return estilo
end

-- El terreno se apagó solo porque sus archivos no cargan en este cliente.
function Lz.TerrenoRoto() return terrenoMalo end

-- El registro del continente si hay mosaico de terreno en (x, y) del lienzo.
local function mosaicoEn(x, y)
	for _, reg in ipairs(armarTerreno()) do
		if x >= reg.x0 and x <= reg.x1 and y >= reg.y0 and y <= reg.y1 then
			local m = reg.mos[floor((x - reg.ax) / reg.bx) * 64 + floor((y - reg.ay) / reg.by)]
			if m and not m.malo then return reg end
		end
	end
	return nil
end

-- Texeles por unidad del lienzo de la mejor capa que hay en el punto (u, v
-- del mundo): el terreno donde lo hay; si no, el arte de la zona (o ciudad),
-- el del continente o el del mundo. Así el zoom nunca agranda un texel a más
-- de ~2 píxeles de la pantalla (Ventana.lua).
function Lz.Densidad(u, v)
	if not hecho or type(u) ~= "number" or type(v) ~= "number" then return nil end
	if terrenoActivo() then
		local reg = mosaicoEn(u * W, v * H)
		if reg then return TEXELES / abs(reg.bx) end
	end
	local cont, zona = Geo.Cadena(u, v)
	-- Sin el arte de las zonas (estilo terreno), el del continente es el mejor.
	if not arteDeZonas() then zona = nil end
	for _, mapa in ipairs({ zona or cont or Geo.MUNDO, cont or Geo.MUNDO, Geo.MUNDO }) do
		local info = Geo.Capa(mapa)
		local l, r = Geo.Rect(mapa)
		if info and l and r > l then return info.layerWidth / ((r - l) * W) end
	end
	return nil
end

-- La zona más pequeña que contiene el punto, por rectángulo (para el zoom).
function Lz.RectZona(mapa)
	for _, z in ipairs(zonas) do if z.id == mapa then return z.l / W, z.t / H, z.w / W, z.h / H end end
	for _, z in ipairs(ciudades) do if z.id == mapa then return z.l / W, z.t / H, z.w / W, z.h / H end end
	local l, r, t, b = Geo.Rect(mapa)
	if l then return l, t, r - l, b - t end
	return nil
end

-- Para pruebas: la cola de texturas por dentro (una tanda que se queda
-- esperando, 1.2.1).
Lz.Prueba = {
	Encolar = function(t, archivo) encolar(t, archivo) end,
	Cargar = function() cargar() end,
	NuevaTanda = function() tanda = tanda + 1 end,
}

-- Las zonas armadas, para las etiquetas: { id, l, t, w, h } en unidades del lienzo.
function Lz.Zonas() return zonas end
function Lz.Ciudades() return ciudades end
function Lz.Ahora() return ahora end
