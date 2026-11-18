-- Alfa - Lya: la loba en pantalla y su globo (toxic3000 / La Jauría). GPL-3.0.
--
-- Lya es una loba negra de perfil, con su pañoleta verde de Alfa, en pixel art
-- (tools/lya_cuerpo.py): dos hojas de 1024 x 256 con 39 cuadros de 60 x 54 px
-- (sin escalar: un texel = un pixel del dibujo), una con el pelaje, la pañoleta
-- y la salchicha (Media/lya-cuerpo) y otra en blanco con un contorno de un
-- pixel y sus adornos (Media/lya-cuerpo-borde), que se tiñe con el acento del
-- estilo (el oro en Clásico WoW) para que se lea sobre fondos oscuros. Cada cuadro se
-- elige con SetTexCoord (y se voltea igual): mira siempre hacia el centro de
-- la pantalla. Su marco (tools/lya_marco.py): una sombra ovalada bajo las
-- patas, que va con ella, y en el suelo, en su lugar, una elipse fina del
-- color del acento con el rombo de Alfa que respira despacio. Sin cuadro de
-- fondo. Es un marco chico que se arrastra y recuerda su lugar (lya.pos;
-- lya.bloqueado lo fija); lya.tamano (64) es la escala: a 64, cada pixel del
-- dibujo mide 1 px (ella, unos 57 x 50 parada), con filtro NEAREST para que
-- se vea nítida. Todo se repinta solo al cambiar de estilo (K.Pintar).
--
-- Vida (nada en OnUpdate): un solo temporizador (C_Timer.NewTicker, de 1 a 10
-- cuadros por segundo según la pose) pasa los cuadros, y solo corre con Lya a
-- la vista y fuera de combate. Poses:
--   quieta (respira y mueve la cola), atenta (las orejas paradas, la cola
--   rápida), sentada, pedir (sentada, la manita arriba, la lengua y una
--   salchicha; al final, con las dos manos), correr (un galope de 6 tiempos;
--   va y vuelve hacia el centro y regresa a su lugar; nunca
--   cambia su lugar guardado), cola (se busca la cola dando vueltas), dormir
--   (enroscada, con sus "z"), aullar, saltar y estirarse (la reverencia y un
--   bostezo). Parpadea con otro temporizador al azar. En combate se queda
--   quieta y tenue; oculta, todo se detiene.
--
-- El globo: una caja del Kit junto a su cabeza, "Lya: texto" en hasta 3 líneas
-- y hasta dos botones; se va solo a los 8 s (12 con botones, no con el ratón
-- encima), con su X o al hacer clic en un botón.
--
--   M.UI.Aplicar()               mostrar u ocultar según los ajustes y la bienvenida
--   M.UI.Hablar(c)               c = { texto, acciones = { { texto, fn }, ... }, cara, salto, aullar, segundos, pose }
--   M.UI.Callar()  M.UI.Hablando()  M.UI.Visible()  M.UI.Frame()
--   M.UI.Dormir(si)  M.UI.Dormida()  M.UI.Saltar()  M.UI.Aullar()  M.UI.Combate(si)
--   M.UI.Gesto()                 un gesto sin palabras (un saltito, ponerse atenta)
--   M.UI.Pose(nombre, segundos)  una pose un rato y de vuelta a quieta; sin nombre,
--                                una al azar del momento (cola, correr, estirarse, sentada)

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

---------------------------------------------------------------------------
-- La hoja de cuadros (el mismo orden que ORDEN en tools/lya_cuerpo.py)
---------------------------------------------------------------------------
local CW, CH, HOJA_W, HOJA_H, COLS = 60, 54, 1024, 256, 17 -- celda y hoja, en px de la textura
local DIBUJO_W, DIBUJO_H = 60, 54                          -- el cuadro, en pixeles del dibujo
local PISO = 3                     -- de abajo del cuadro a donde pisan las patas (pixeles del dibujo)
local ORDEN = {
	"quieta1", "quieta2", "quieta3", "quieta4",
	"quieta1-parpadeo", "quieta2-parpadeo", "quieta3-parpadeo", "quieta4-parpadeo",
	"atenta1", "atenta2", "atenta1-parpadeo", "atenta2-parpadeo",
	"sentada1", "sentada2", "sentada1-parpadeo", "sentada2-parpadeo",
	"pedir1", "pedir2", "pedir3",
	"correr1", "correr2", "correr3", "correr4", "correr5", "correr6",
	"cola1", "cola2", "cola3", "cola4",
	"dormir1", "dormir2",
	"aullar1", "aullar2",
	"saltar1", "saltar2", "saltar3",
	"estirarse1", "estirarse2", "estirarse3",
}
local CELDA = {}
for i, n in ipairs(ORDEN) do CELDA[n] = i - 1 end

-- Cada pose: sus cuadros en orden, cada cuánto pasa uno (s), si tiene
-- parpadeo y si se hace una sola vez (y luego vuelve a la de fondo).
local POSES = {
	quieta    = { cada = 0.35, parpadeo = true, "quieta1", "quieta2", "quieta3", "quieta4" },
	atenta    = { cada = 0.2, parpadeo = true, "atenta1", "atenta2" },
	sentada   = { cada = 0.7, parpadeo = true, "sentada1", "sentada2" },
	pedir     = { cada = 0.25, "pedir1", "pedir2", "pedir1", "pedir2", "pedir3", "pedir3" },
	correr    = { cada = 0.1, "correr1", "correr2", "correr3", "correr4", "correr5", "correr6" },
	cola      = { cada = 0.12, "cola1", "cola2", "cola3", "cola4" },
	dormir    = { cada = 1.1, "dormir1", "dormir2" },
	aullar    = { cada = 0.45, "aullar1", "aullar2" },
	saltar    = { cada = 0.1, unaVez = true, "saltar1", "saltar2", "saltar2", "saltar2", "saltar3" },
	estirarse = { cada = 0.2, unaVez = true, "estirarse1", "estirarse2", "estirarse2", "estirarse2",
		"estirarse2", "estirarse3", "estirarse3", "estirarse3", "estirarse3" },
}
-- Cuánto dura cada una (s) si no se dice; las de una vez duran lo que sus cuadros.
local DURA = { cola = 2.4, correr = 2.4, sentada = 8, pedir = 4, aullar = 3.5, atenta = 3, dormir = 8 }
-- Las del momento, para que se sienta viva entre globos.
local DEL_MOMENTO = { "cola", "correr", "estirarse", "sentada" }

local f, g                       -- Lya y su globo
local fondo = "quieta"           -- la pose de fondo: quieta o dormir
local hablaPose                  -- la pose mientras habla (pedir, atenta...)
local pasajera                   -- una pose por un rato, encima de las demás
local actualPose, cuadro = nil, 1
local ticker, tickerCada
local parpadeando = false
local alReves = false            -- mira a la izquierda (está en la mitad derecha)
local vuelta = false             -- de regreso de una carrera (mira al otro lado)
local dormida, combate = false, false
local turnoGlobo, turnoPose, turnoParpadeo = 0, 0, 0
local actual                     -- lo que dice ahora

local function tam()
	local t = tonumber(N.Get(ID, "tamano")) or 64
	return max(40, min(128, floor(t + 0.5)))
end
-- Un pixel del dibujo, en px de la pantalla (1 a tamaño 64).
local function px() return tam() / 64 end

function UI.Frame() return f end
function UI.Visible() return f and f:IsShown() and true or false end
function UI.Hablando() return g and g:IsShown() and actual ~= nil end
function UI.Dormida() return dormida end

---------------------------------------------------------------------------
-- Dibujar el cuadro de ahora
---------------------------------------------------------------------------
local function poseAhora()
	return pasajera or hablaPose or fondo
end

local function dibujar()
	if not f then return end
	local p = POSES[actualPose] or POSES.quieta
	local nombre = p[cuadro] or p[1]
	if parpadeando and p.parpadeo and CELDA[nombre .. "-parpadeo"] then nombre = nombre .. "-parpadeo" end
	local i = CELDA[nombre] or 0
	local col, fila = i % COLS, floor(i / COLS)
	local l, r = col * CW / HOJA_W, (col + 1) * CW / HOJA_W
	local t, b = fila * CH / HOJA_H, (fila + 1) * CH / HOJA_H
	if alReves ~= vuelta then l, r = r, l end -- mirar a la izquierda: el espejo
	f.Pelo:SetTexCoord(l, r, t, b)
	f.Borde:SetTexCoord(l, r, t, b)
end

local function parar()
	if ticker then ticker:Cancel() end
	ticker, tickerCada = nil, nil
end

local terminarPasajera

local function paso()
	local p = POSES[actualPose]
	if not p then return end
	cuadro = cuadro + 1
	if cuadro > #p then
		if p.unaVez and pasajera == actualPose then
			cuadro = #p
			terminarPasajera()
			return
		end
		cuadro = 1
	end
	dibujar()
end

-- El temporizador de los cuadros: solo con Lya a la vista y fuera de combate.
local function andar()
	local p = POSES[actualPose]
	if not (f and f:IsVisible()) or combate or not p or #p < 2 then parar() return end
	if ticker and tickerCada == p.cada then return end
	parar()
	if C_Timer and C_Timer.NewTicker then
		tickerCada = p.cada
		ticker = C_Timer.NewTicker(p.cada, paso)
	end
end

-- Pone la pose que toca (si cambió, desde su primer cuadro).
local function ponerPose()
	if not f then return end
	local nueva = poseAhora()
	if combate then nueva = dormida and "dormir" or "quieta" end
	if nueva ~= actualPose then
		actualPose, cuadro = nueva, 1
		parar()
	end
	dibujar()
	andar()
end

---------------------------------------------------------------------------
-- Mirar hacia el centro
---------------------------------------------------------------------------
local function mirar()
	if not f then return end
	local x = f:GetCenter()
	local w = UIParent and UIParent:GetWidth()
	alReves = type(x) == "number" and type(w) == "number" and x > w / 2 or false
	dibujar()
end

---------------------------------------------------------------------------
-- Poses pasajeras
---------------------------------------------------------------------------
local function pararCarrera()
	if f and f.Carrera then f.Carrera:Stop() end
	vuelta = false
end

terminarPasajera = function()
	turnoPose = turnoPose + 1
	pasajera = nil
	pararCarrera()
	ponerPose()
end

-- Correr: va hacia el centro de la pantalla y regresa a su lugar (la carrera
-- mueve solo el dibujo; su lugar guardado no cambia). Sin espacio, en su sitio.
local function carrera()
	if not (f and f.Carrera) or UI.Hablando() then return end
	local d = floor(tam() * 0.9)
	local w = UIParent and UIParent:GetWidth()
	local izq, der = f:GetLeft(), f:GetRight()
	if type(w) == "number" and type(izq) == "number" and type(der) == "number" then
		d = alReves and min(d, floor(izq)) or min(d, floor(w - der))
	end
	if d < 12 then return end
	local dx = alReves and -d or d
	f.Ida:SetOffset(dx, 0)
	f.Regreso:SetOffset(-dx, 0)
	vuelta = false
	f.Carrera:Stop()
	f.Carrera:Play()
end

local function llegando() return f and f.Llegada and f.Llegada:IsPlaying() or false end

function UI.Pose(nombre, segundos)
	if not (f and f:IsVisible()) or combate or llegando() then return false end
	if nombre == nil then
		if dormida or UI.Hablando() then return false end
		nombre = DEL_MOMENTO[random(#DEL_MOMENTO)]
	end
	local p = POSES[nombre]
	if not p then return false end
	-- "quieta" deja la pose de ahora; "dormir" es una siesta (no la despierta)
	if nombre == "quieta" then terminarPasajera() return true end
	if nombre ~= "dormir" and dormida then UI.Dormir(false) end
	turnoPose = turnoPose + 1
	local mio = turnoPose
	pararCarrera()
	pasajera = nombre
	actualPose = nil -- empieza desde su primer cuadro aunque ya estuviera
	ponerPose()
	if nombre == "correr" then carrera() end
	if not p.unaVez then
		local s = tonumber(segundos) or DURA[nombre] or 3
		if nombre == "sentada" then s = tonumber(segundos) or (6 + random() * 6) end
		K.Despues(s, function()
			if mio == turnoPose and pasajera == nombre then terminarPasajera() end
		end)
	end
	return true
end

---------------------------------------------------------------------------
-- Parpadear, saltar, aullar, dormir
---------------------------------------------------------------------------
local parpadear
local function programarParpadeo()
	turnoParpadeo = turnoParpadeo + 1
	local mio = turnoParpadeo
	K.Despues(3 + random() * 4, function()
		if mio ~= turnoParpadeo then return end
		parpadear(mio)
	end)
end

local function cerrarOjos(segundos)
	parpadeando = true
	dibujar()
	K.Despues(segundos, function()
		parpadeando = false
		dibujar()
	end)
end

parpadear = function(mio)
	if not (f and f:IsVisible()) or dormida or combate then return end -- se reprograma al despertar / mostrarse
	local p = POSES[actualPose]
	if p and p.parpadeo and not parpadeando then
		cerrarOjos(0.13)
		-- a veces dos seguidos
		if random() < 0.25 then
			K.Despues(0.3, function() if mio == turnoParpadeo and not parpadeando then cerrarOjos(0.12) end end)
		end
	end
	programarParpadeo()
end

function UI.Saltar()
	if not (f and f:IsVisible()) or combate then return end
	if f.Salto:IsPlaying() or f.Carrera:IsPlaying() or llegando() then return end
	if dormida then UI.Dormir(false) end
	f.Salto:Play()
	UI.Pose("saltar")
end

-- Un gesto sin palabras para que se sienta viva: un saltito, ponerse atenta
-- (las orejas arriba) o las dos cosas. Nunca dormida, en combate ni con otra pose.
function UI.Gesto()
	if not (f and f:IsVisible()) or dormida or combate or pasajera or llegando() then return end
	local r = random()
	if r < 0.4 then
		UI.Saltar()
	elseif r < 0.8 then
		UI.Pose("atenta", 2 + random() * 2)
	else
		UI.Saltar()
		K.Despues(0.6, function() if not pasajera then UI.Pose("atenta", 1.5) end end)
	end
end

function UI.Aullar()
	if not f then return end
	UI.Dormir(false)
	UI.Pose("aullar", 3.5)
end

function UI.Dormir(si)
	si = si and true or false
	if si == dormida then return end
	dormida = si
	fondo = si and "dormir" or "quieta"
	turnoPose = turnoPose + 1
	pasajera = nil
	pararCarrera()
	parpadeando = false
	ponerPose()
	if not si then programarParpadeo() end
end

---------------------------------------------------------------------------
-- La llegada (1.2.1): al entrar al juego, Lya llega corriendo desde la orilla
-- de la pantalla que tiene detrás (mira hacia el centro: corre hacia él)
-- hasta su lugar, da un saltito y luego dice lo suyo. Mientras espera su
-- momento (la intro del lobo), solo se ve su lugar en el suelo. Su lugar
-- guardado no cambia: se mueve solo el dibujo (f.Andar), como en la carrera.
--   UI.EsperarLlegada()  la esconde hasta que llegue
--   UI.Llegar(fn)        llega corriendo y luego llama a fn (en combate, oculta
--                        o sin espacio: aparece en su lugar y llama a fn)
---------------------------------------------------------------------------
local esperando = false

-- El dibujo vuelve a su lugar, a la vista, sin desplazamiento.
local function enSuLugar()
	esperando = false
	if not f then return end
	if f.Llegada then f.Llegada:Stop() end
	f.alLlegar = nil
	f.Andar:ClearAllPoints()
	f.Andar:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.Andar:SetAlpha(1)
end

function UI.EsperarLlegada()
	if not (f and f:IsShown()) then return false end
	esperando = true
	f.Andar:SetAlpha(0)
	return true
end
function UI.Esperando() return esperando end

function UI.Llegar(fn)
	if not f then return false end
	local function listo()
		enSuLugar()
		if fn then K.Llamar(fn) end
	end
	if not esperando then return false end
	local w = UIParent and UIParent:GetWidth()
	local izq, der = f:GetLeft(), f:GetRight()
	if not f:IsVisible() or combate or type(w) ~= "number" or type(izq) ~= "number" or type(der) ~= "number" then
		listo()
		return true
	end
	mirar()
	-- entra por la orilla que tiene detrás: por la derecha si mira a la izquierda
	local ancho = der - izq
	local dx = alReves and floor(w - izq + ancho * 0.6) or -floor(der + ancho * 0.6)
	if dx == 0 then listo() return true end
	local dura = max(1.1, min(2.6, (dx < 0 and -dx or dx) / 650))
	if UI.Hablando() then UI.Callar(true) end
	UI.Dormir(false)
	f.Andar:ClearAllPoints()
	f.Andar:SetPoint("CENTER", f, "CENTER", dx, 0)
	f.Andar:SetAlpha(1)
	f.Viaje:SetOffset(-dx, 0)
	f.Viaje:SetDuration(dura)
	f.alLlegar = fn
	esperando = false
	-- galopa todo el camino (y frena al llegar)
	turnoPose = turnoPose + 1
	pararCarrera()
	pasajera = "correr"
	actualPose = nil
	ponerPose()
	f.Llegada:Play()
	return true
end

function UI.Combate(si)
	combate = si and true or false
	if not f then return end
	f:SetAlpha(combate and 0.45 or 1)
	if combate then
		-- en combate no corre: aparece en su lugar (lo que iba a decir espera)
		if llegando() then
			local fn = f.alLlegar
			enSuLugar()
			if pasajera == "correr" then terminarPasajera() end
			if fn then K.Llamar(fn) end
		end
		f.Salto:Stop()
		pararCarrera()
		f.Pulso:Stop()
	elseif f:IsShown() then
		f.Pulso:Play()
		programarParpadeo()
	end
	ponerPose()
end

---------------------------------------------------------------------------
-- El menú del clic derecho
---------------------------------------------------------------------------
local function menu()
	local Ce = M.Cerebro
	local silencio = Ce.Silenciada()
	local bloqueado = N.Get(ID, "bloqueado") and true or false
	local Hi = M.Historias
	local Ch = M.Charla
	-- Cuántos consejos: una sola fila que va pasando de muchos a pocos y a solo importantes.
	local FREC = { muchos = "Consejos: muchos", pocos = "Consejos: pocos", importantes = "Consejos: solo importantes" }
	local SIGUE = { muchos = "pocos", pocos = "importantes", importantes = "muchos" }
	local frec = Ce.Frecuencia()
	local grupos = {
		{ { valor = "silencio", texto = silencio and L["Quitar el silencio"] or L["Silenciar 1 hora"], icono = "ic-reloj" } },
		{},
		{ { valor = "frec", texto = L[FREC[frec]], icono = "ic-filtro" } },
		{ { valor = "bloquear", texto = bloqueado and L["Desbloquear posición"] or L["Bloquear posición"], icono = "ic-seguir" },
		  { valor = "vistos", texto = L["Volver a mostrar los consejos vistos"], icono = "ic-lista" },
		  { valor = "ajustes", texto = L["Ajustes de Lya"], icono = "ic-ajustes" },
		  { valor = "ocultar", texto = L["Ocultar a Lya"], icono = "ic-cerrar" } },
	}
	local hist = grupos[2]
	if Hi and Hi.Modo() ~= "nunca" then hist[#hist + 1] = { valor = "dato", texto = L["Cuéntame algo de aquí"], icono = "ic-mundo" } end
	if Ch then
		hist[#hist + 1] = { valor = "algo", texto = L["Cuéntame algo"], icono = "ic-info" }
		hist[#hist + 1] = { valor = "gente", texto = L["Háblame de mi gente"], icono = "ic-manada" }
	end
	if Hi then hist[#hist + 1] = { valor = "historias", texto = L["Historias de tus misiones"], icono = "ic-misiones" } end
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
	K.Menu(f, opciones, nil, function(v)
		if v == "silencio" then Ce.Silenciar(not silencio)
		elseif v == "dato" then Hi.Contar()
		elseif v == "algo" then Ch.Contar()
		elseif v == "gente" then Ch.Gente()
		elseif v == "frec" then
			local nueva = SIGUE[frec] or "muchos"
			N.Set(ID, "frecuencia", nueva)
			N.Imprimir(L[FREC[nueva]])
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
local function pintarLya(x)
	local tono = K.Clasico() and "oro" or "acento"
	-- El contorno de color: lo justo para que la loba negra se lea en lo oscuro.
	x.Borde:SetVertexColor(K.ConAlfa(tono, K.Cristal() and 0.5 or 0.6))
	x.Pelo:SetVertexColor(1, 1, 1, 1)
	x.Suelo:SetVertexColor(K.ConAlfa(tono, 1))
	x.Sombra:SetVertexColor(1, 1, 1, K.Cristal() and 0.6 or 0.85)
end

local function lugar()
	local p = N.Get(ID, "pos")
	if type(p) ~= "table" or type(p[1]) ~= "string" then p = DEFAULT end
	f:ClearAllPoints()
	f:SetPoint(p[1], UIParent, p[1], tonumber(p[2]) or 0, tonumber(p[3]) or 0)
	mirar()
end

local function medir()
	local t, u = tam(), px()
	local w, h = floor(DIBUJO_W * u + 0.5), floor(DIBUJO_H * u + 0.5)
	f:SetSize(w, h)
	f.Andar:SetSize(w, h)
	f.Cuerpo:SetSize(w, h)
	-- Las patas tocan el suelo a PISO pixeles del dibujo del borde de abajo; la
	-- sombra y la elipse (64 x 16 pixeles, como los del dibujo) se centran ahí.
	local sw, sh, sy = floor(64 * u + 0.5), floor(16 * u + 0.5), floor(PISO * u + 0.5)
	f.Sombra:SetSize(sw, sh)
	f.Sombra:ClearAllPoints()
	f.Sombra:SetPoint("CENTER", f.Andar, "BOTTOM", 0, sy)
	f.Suelo:SetSize(sw, sh)
	f.Suelo:ClearAllPoints()
	f.Suelo:SetPoint("CENTER", f, "BOTTOM", 0, sy)
	f.Salto1:SetOffset(0, floor(t * 0.14))
	f.Salto2:SetOffset(0, -floor(t * 0.14))
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

	-- Su lugar en el suelo (tools/lya_marco.py): una elipse fina con el rombo
	-- de Alfa, del color del estilo, que respira despacio. Se queda aunque ella
	-- corra: es su sitio.
	f.Base = CreateFrame("Frame", nil, f)
	f.Base:SetAllPoints(f)
	f.Suelo = f.Base:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.Suelo:SetTexture(MEDIA .. "lya-suelo")
	local pulso = f.Base:CreateAnimationGroup()
	pulso:SetLooping("BOUNCE")
	local pa = pulso:CreateAnimation("Alpha")
	pa:SetFromAlpha(0.35)
	pa:SetToAlpha(0.8)
	pa:SetDuration(2.6)
	pa:SetSmoothing("IN_OUT")
	f.Pulso = pulso

	-- Ella: su sombra ovalada (va con ella al correr, no al saltar) y las dos
	-- capas del dibujo.
	f.Andar = CreateFrame("Frame", nil, f)
	f.Andar:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.Sombra = f.Andar:CreateTexture(nil, "BACKGROUND", nil, 2)
	f.Sombra:SetTexture(MEDIA .. "lya-sombra")
	f.Cuerpo = CreateFrame("Frame", nil, f.Andar)
	f.Cuerpo:SetPoint("CENTER", f.Andar, "CENTER", 0, 0)
	f.Borde = f.Cuerpo:CreateTexture(nil, "ARTWORK", nil, 1)
	f.Borde:SetAllPoints(f.Cuerpo)
	f.Borde:SetTexture(MEDIA .. "lya-cuerpo-borde", nil, nil, "NEAREST")
	f.Pelo = f.Cuerpo:CreateTexture(nil, "ARTWORK", nil, 2)
	f.Pelo:SetAllPoints(f.Cuerpo)
	f.Pelo:SetTexture(MEDIA .. "lya-cuerpo", nil, nil, "NEAREST")
	for _, tx in ipairs({ f.Borde, f.Pelo }) do
		if tx.SetSnapToPixelGrid then tx:SetSnapToPixelGrid(true) end
		if tx.SetTexelSnappingBias then tx:SetTexelSnappingBias(0) end
	end

	-- Saltar: arriba y abajo, y uno chiquito (con la pose de saltar).
	local s = f.Cuerpo:CreateAnimationGroup()
	local s1 = s:CreateAnimation("Translation")
	s1:SetOffset(0, 10) s1:SetDuration(0.16) s1:SetSmoothing("OUT") s1:SetOrder(1)
	local s2 = s:CreateAnimation("Translation")
	s2:SetOffset(0, -10) s2:SetDuration(0.18) s2:SetSmoothing("IN") s2:SetOrder(2)
	local s3 = s:CreateAnimation("Translation")
	s3:SetOffset(0, 4) s3:SetDuration(0.1) s3:SetSmoothing("OUT") s3:SetOrder(3)
	local s4 = s:CreateAnimation("Translation")
	s4:SetOffset(0, -4) s4:SetDuration(0.12) s4:SetSmoothing("IN") s4:SetOrder(4)
	f.Salto, f.Salto1, f.Salto2 = s, s1, s2

	-- Correr: ida, la vuelta (se voltea) y regreso a su lugar.
	local c = f.Andar:CreateAnimationGroup()
	local ida = c:CreateAnimation("Translation")
	ida:SetDuration(1.1) ida:SetSmoothing("IN_OUT") ida:SetOrder(1)
	ida:SetScript("OnFinished", function() vuelta = true dibujar() end)
	local regreso = c:CreateAnimation("Translation")
	regreso:SetDuration(1.1) regreso:SetSmoothing("IN_OUT") regreso:SetOrder(2)
	c:SetScript("OnFinished", function()
		vuelta = false
		if pasajera == "correr" then terminarPasajera() else dibujar() end
	end)
	f.Carrera, f.Ida, f.Regreso = c, ida, regreso

	-- Llegar (al entrar al juego): desde la orilla de la pantalla hasta su
	-- lugar, frenando al final; luego un saltito y lo que tenga que decir.
	local lle = f.Andar:CreateAnimationGroup()
	local viaje = lle:CreateAnimation("Translation")
	viaje:SetDuration(1.6) viaje:SetSmoothing("OUT")
	lle:SetScript("OnFinished", function()
		local fn = f.alLlegar
		enSuLugar()
		if pasajera == "correr" then terminarPasajera() end
		UI.Saltar()
		if fn then K.Despues(0.45, function() K.Llamar(fn) end) end
	end)
	f.Llegada, f.Viaje = lle, viaje

	K.Pintar(f, pintarLya)
	medir()

	f:SetScript("OnDragStart", function(self)
		if N.Get(ID, "bloqueado") or (A.DragLocked and A.DragLocked()) then return end
		self.alfaArrastre = true
		K.OcultarInfo(self)
		pararCarrera()
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
		if not combate then f.Pulso:Play() end
		mirar()
		ponerPose()
		if not dormida then programarParpadeo() end
	end)
	f:SetScript("OnHide", function()
		parar()
		enSuLugar()
		f.Salto:Stop()
		f.Pulso:Stop()
		turnoPose = turnoPose + 1
		pasajera = nil
		pararCarrera()
		parpadeando = false
		turnoParpadeo = turnoParpadeo + 1
		UI.Callar(true)
	end)
	actualPose = nil
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
	-- Una acción que abre algo del juego la hace el juego (K.Seguro); después
	-- Lya se calla como con cualquier otro botón.
	K.SeguroDe(b, a)
	if a and a.seguro then b.alfaTrasClic = function() if actual then UI.Callar() end end end
	if not a then b:Hide() return 0 end
	b:SetTexto(a.texto or "")
	b:Show()
	return b:AnchoNatural()
end

-- Del lado al que mira (hacia el centro de la pantalla), arriba de su cabeza:
-- la esquina del globo queda frente a su nariz, 4 pixeles del dibujo bajo el
-- borde de arriba del cuadro (sin tapar la salchicha cuando pide).
function UI.Acomodar()
	if not (g and f) then return end
	g:ClearAllPoints()
	local y = -floor(4 * px() + 0.5)
	if alReves then
		g:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", 0, y)
	else
		g:SetPoint("BOTTOMLEFT", f, "TOPRIGHT", 0, y)
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
	local estaba = g:IsShown()
	g:Show()
	if not estaba then g.Entra:Stop() g.Entra:Play() end

	-- La pose mientras habla: la que pida (pedir con hambre), atenta si te
	-- ofrece algo, el aullido en una celebración. Se despierta para hablar y
	-- deja de correr (el globo va pegado a ella); si venía llegando o la
	-- estaban esperando, ya está en su lugar.
	if llegando() or esperando then
		enSuLugar()
		if pasajera == "correr" then pasajera = nil end
	end
	UI.Dormir(false)
	pararCarrera()
	if pasajera and pasajera ~= "saltar" then
		turnoPose = turnoPose + 1
		pasajera = nil
	end
	local pose = type(c.pose) == "string" and POSES[c.pose] and c.pose or nil
	hablaPose = pose or ((c.cara == "atenta" or w1 > 0) and "atenta") or nil
	ponerPose()
	UI.Acomodar()
	if c.aullar then
		UI.Aullar()
	elseif c.salto then
		UI.Saltar()
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
	if f and hablaPose then
		hablaPose = nil
		ponerPose()
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
		pararCarrera()
		medir()
		lugar()
		if UI.Hablando() then UI.Acomodar() end
	end
end)
