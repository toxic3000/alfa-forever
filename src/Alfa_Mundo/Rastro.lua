-- Alfa - Mundo: tu camino de hoy en el mapa de Alfa (1.3.7c). toxic3000 /
-- La Jauría. GPL-3.0.
--
-- Mientras juegas, Alfa anota por dónde pasas (un punto cada RECORRIDO
-- yardas, revisando cada CADA segundos: nada en combate ni en instancias,
-- nada en grifo). En el mapa de Alfa se dibuja como un rastro de puntitos del
-- color de Alfa, tenues los de la mañana y más vivos los de hace poco; donde
-- empezaste el día, una huella. Se guarda por personaje y se borra solo al
-- cambiar el día. Como mucho MAX puntos (el rastro más viejo se ralea).
--
-- Interruptor: la capa «Tu camino de hoy» (mundo.rastro, de fábrica prendida)
-- en el control de capas del mapa y en Ajustes > Mundo.
--   Ra.Crear(vista)  Ra.Colocar(cu, cv, k, vw, vh, z)  Ra.Latido()
--   Ra.Anotar()      una revisión ya (el reloj la llama)
--   Ra.Puntos() -> n  Ra.Dibujados() -> n  Ra.Olvidar()   (para el banco)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

local type, pcall, tonumber, floor, max, min = type, pcall, tonumber, math.floor, math.max, math.min
local tremove = table.remove

local Ra = {}
M.Rastro = Ra

local CADA = 5          -- s entre revisiones
local RECORRIDO = 25    -- yardas entre un punto y el siguiente
local MAX = 1800        -- puntos guardados como mucho
local MAX_DIBUJO = 700  -- puntos dibujados como mucho
local SEPARA = 6        -- unidades de la vista entre dos puntos dibujados
local TAM = 5           -- lado de un punto (unidades de la vista)
local NAV = "Interface\\AddOns\\Alfa\\Media\\Nav\\"
local UI = "Interface\\AddOns\\Alfa\\Media\\UI\\"
Ra.RECORRIDO, Ra.MAX = RECORRIDO, MAX

local function prendido() return A.Get("mundo.rastro") ~= false end

local function hoy() return date and date("%Y-%m-%d") or "?" end

-- Lo guardado: { dia, c = {}, x = {}, y = {} } (x norte, y oeste, en yardas).
local function datos()
	local d = N.DatosPersonaje("mundo")
	local r = d.rastro
	local dia = hoy()
	if type(r) ~= "table" or r.dia ~= dia or type(r.c) ~= "table" or type(r.x) ~= "table" or type(r.y) ~= "table" then
		r = { dia = dia, c = {}, x = {}, y = {} }
		d.rastro = r
	end
	return r
end

local function numero(v)
	if N.Secreto(v) then return nil end
	return type(v) == "number" and v or nil
end

local function yo()
	local C = A.Compat
	if not (C and type(C.GetPlayerWorldPosition) == "function") then return nil end
	local ok, c, x, y = pcall(C.GetPlayerWorldPosition)
	if not ok then return nil end
	c, x, y = numero(c), numero(x), numero(y)
	if not (c and x and y) then return nil end
	return c, x, y
end

local function quieto()
	if InCombatLockdown and InCombatLockdown() then return true end
	if N.SiJuego(UnitOnTaxi, "player") then return true end
	if N.SiJuego(IsInInstance) then return true end
	return false
end

local revision = 0 -- sube con cada punto nuevo

-- Una revisión: si te moviste lo bastante desde el último punto, otro más.
function Ra.Anotar()
	if not prendido() or quieto() then return false end
	local c, x, y = yo()
	if not c then return false end
	local r = datos()
	local n = #r.c
	if n > 0 and r.c[n] == c then
		local dx, dy = x - r.x[n], y - r.y[n]
		if dx * dx + dy * dy < RECORRIDO * RECORRIDO then return false end
	end
	n = n + 1
	r.c[n], r.x[n], r.y[n] = c, floor(x * 10 + 0.5) / 10, floor(y * 10 + 0.5) / 10
	-- Lleno: uno de cada dos de la primera mitad se va (el rastro viejo se ralea).
	if n > MAX then
		for i = floor(MAX / 2), 2, -2 do
			tremove(r.c, i) tremove(r.x, i) tremove(r.y, i)
		end
	end
	revision = revision + 1
	return true
end

function Ra.Puntos() return #datos().c end
function Ra.Olvidar() N.DatosPersonaje("mundo").rastro = nil revision = revision + 1 end

N.Cada("mundo.rastro", CADA, function() Ra.Anotar() end)

---------------------------------------------------------------------------
-- En el mapa de Alfa
---------------------------------------------------------------------------

-- Para no rehacer 700 texturas en cada cuadro al arrastrar el mapa: cada
-- punto se pasa una vez a unidades del lienzo (lienzoX/Y, se rehace solo con
-- puntos nuevos); se dibuja dentro de «capa», pegada a la esquina del lienzo,
-- con un margen de media vista alrededor. Al arrastrar sin cambiar el zoom
-- solo se mueve la capa; si te sales del margen, cambia el zoom o llegan
-- puntos, se vuelve a dibujar (y cada textura solo cambia lo que cambió).
local raiz, capa
local puntos = {}
local usados = 0
local dibujada = -1
local vista = {}
local lienzoX, lienzoY, lienzoRev = {}, {}, -1
local hecho = {}   -- lo del último dibujo completo: k, vw, vh, ox, oy, color...

local function acento()
	local T = A.Theme
	if T and type(T.Accent) == "function" then
		local ok, r, g, b = pcall(T.Accent)
		if ok and type(r) == "number" then return r, g, b end
	end
	return 0.545, 0.878, 0.306
end

local function punto(i)
	local t = puntos[i]
	if t then return t end
	t = capa:CreateTexture(nil, "ARTWORK")
	puntos[i] = t
	return t
end

-- Cada punto en unidades del lienzo (sin zoom ni arrastre): un pcall por
-- punto, solo cuando cambian los puntos. -> true si se pudo
local function aLienzo(r)
	if lienzoRev == revision then return true end
	local Tr, Lz = M.Trayecto, M.Lienzo
	local a = Lz and Lz.Ahora and Lz.Ahora()
	if not (Tr and Tr.AVista and a and a.ox and type(a.k) == "number" and a.k > 0) then return false end
	local ox, oy, k = a.ox, a.oy, a.k
	local bien = 0
	for i = 1, #r.c do
		local ok, vx, vy = pcall(Tr.AVista, r.c[i], r.x[i], r.y[i])
		if ok and type(vx) == "number" and type(vy) == "number" then
			bien = bien + 1
			lienzoX[i], lienzoY[i] = (vx - ox) / k, (vy - oy) / k
		else
			lienzoX[i], lienzoY[i] = false, false
		end
	end
	for i = #r.c + 1, #lienzoX do lienzoX[i], lienzoY[i] = nil, nil end
	-- (sin proyección todavía, se vuelve a intentar en el siguiente dibujo)
	if bien > 0 or #r.c == 0 then lienzoRev = revision end
	return true
end

-- Una textura: solo se toca lo que cambió.
local function pintar(t, huella, alfa, x, y, cr, cg, cb)
	if t.alfaHuella ~= huella then
		t.alfaHuella = huella
		if huella then
			t:SetTexture(UI .. "ic-huella")
			t:SetDrawLayer("OVERLAY")
			t:SetSize(TAM * 2.6, TAM * 2.6)
		else
			t:SetTexture(NAV .. "pin-fill")
			t:SetDrawLayer("ARTWORK")
			t:SetSize(TAM, TAM)
		end
		t.alfaA = nil
	end
	if t.alfaA ~= alfa or t.alfaR ~= cr or t.alfaG ~= cg or t.alfaB ~= cb then
		t.alfaA, t.alfaR, t.alfaG, t.alfaB = alfa, cr, cg, cb
		t:SetVertexColor(cr, cg, cb, alfa)
	end
	if t.alfaX ~= x or t.alfaY ~= y then
		t.alfaX, t.alfaY = x, y
		t:ClearAllPoints()
		t:SetPoint("CENTER", capa, "TOPLEFT", x, -y)
	end
	if not t.alfaVisible then t.alfaVisible = true t:Show() end
end

local function esconder(t)
	if t.alfaVisible ~= false then t.alfaVisible = false t:Hide() end
end

-- La capa pegada a la esquina del lienzo (en un píxel entero, como Lz.Colocar).
local function moverCapa(ox, oy)
	if hecho.cx == ox and hecho.cy == oy then return end
	hecho.cx, hecho.cy = ox, oy
	capa:ClearAllPoints()
	capa:SetPoint("TOPLEFT", raiz, "TOPLEFT", ox, -oy)
	capa:SetSize(1, 1)
end

local function dibujar()
	if not raiz then return end
	dibujada = revision
	local n = 0
	local oculto = A.Hidden and A.Hidden()
	local a = M.Lienzo and M.Lienzo.Ahora and M.Lienzo.Ahora()
	local r = datos()
	if prendido() and not oculto and vista.vw and a and a.ox and aLienzo(r) then
		local total = #r.c
		local vw, vh, k = vista.vw, vista.vh, a.k
		local mx, my = vw / 2, vh / 2 -- el margen: media vista alrededor
		local cr, cg, cb = acento()
		local px = M.Marcas and M.Marcas.AlPixel or function(v) return v end
		local ox, oy = px(a.ox), px(a.oy)
		moverCapa(ox, oy)
		hecho.k, hecho.vw, hecho.vh, hecho.ox, hecho.oy, hecho.color = k, vw, vh, a.ox, a.oy, cr .. "," .. cg .. "," .. cb
		local lx, ly
		local function uno(i)
			local cx, cy = lienzoX[i], lienzoY[i]
			if not cx then return end
			local x, y = cx * k, cy * k -- desde la esquina del lienzo
			local vx, vy = x + a.ox, y + a.oy
			if vx < -mx or vy < -my or vx > vw + mx or vy > vh + my then return end
			if i ~= 1 and lx and (vx - lx) ^ 2 + (vy - ly) ^ 2 < SEPARA * SEPARA then return end
			lx, ly = vx, vy
			n = n + 1
			local edad = total > 1 and (i - 1) / (total - 1) or 1 -- 0 el primero, 1 el último
			if i == 1 then
				pintar(punto(n), true, 0.95, px(x), px(y), cr, cg, cb)
			else
				pintar(punto(n), false, floor((0.3 + 0.5 * edad) * 50 + 0.5) / 50, px(x), px(y), cr, cg, cb)
			end
		end
		-- Del más nuevo al más viejo: si hay que cortar, se queda lo reciente;
		-- donde empezaste el día (la huella, el punto 1) sale siempre.
		for i = total, 2, -1 do
			if n >= MAX_DIBUJO - 1 then break end
			uno(i)
		end
		if total >= 1 then uno(1) end
	end
	for i = n + 1, usados do esconder(puntos[i]) end
	usados = n
end

-- Tras mover la vista: si solo se arrastró (mismo zoom, mismo tamaño, sin
-- puntos nuevos) y no se salió del margen, basta con mover la capa.
local function alMover()
	if not raiz then return end
	local a = M.Lienzo and M.Lienzo.Ahora and M.Lienzo.Ahora()
	if dibujada == revision and lienzoRev == revision and a and a.ox and hecho.k == a.k
		and hecho.vw == vista.vw and hecho.vh == vista.vh and prendido() and not (A.Hidden and A.Hidden())
		and hecho.color == table.concat({ acento() }, ",")
		and math.abs(a.ox - hecho.ox) < vista.vw / 2 and math.abs(a.oy - hecho.oy) < vista.vh / 2 then
		local px = M.Marcas and M.Marcas.AlPixel or function(v) return v end
		moverCapa(px(a.ox), px(a.oy))
		return
	end
	dibujar()
end

function Ra.Crear(padre)
	if raiz then return raiz end
	raiz = CreateFrame("Frame", nil, padre)
	raiz:SetAllPoints(padre)
	raiz:EnableMouse(false)
	capa = CreateFrame("Frame", nil, raiz)
	capa:SetPoint("TOPLEFT", raiz, "TOPLEFT", 0, 0)
	capa:SetSize(1, 1)
	capa:EnableMouse(false)
	-- Sobre el arte, junto a la ruta (Trayecto: NIVELES + 4) y debajo de los pines.
	raiz:SetFrameLevel(padre:GetFrameLevel() + (M.Lienzo and M.Lienzo.NIVELES or 30) + 3)
	capa:SetFrameLevel(raiz:GetFrameLevel())
	return raiz
end

function Ra.Colocar(cu, cv, k, vw, vh, z)
	vista.vw, vista.vh, vista.z = vw, vh, z
	alMover()
end

-- Con el mapa quieto: solo si llegaron puntos nuevos.
function Ra.Latido()
	if raiz and vista.vw and dibujada ~= revision then dibujar() end
end

function Ra.Dibujados() return usados end

A.On("SETTING_CHANGED", function(path)
	if path == "mundo.rastro" or path == "" then
		revision = revision + 1
		Ra.Latido()
	end
end)
