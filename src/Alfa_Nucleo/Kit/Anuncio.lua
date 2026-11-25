-- Alfa - Kit: el anuncio animado (1.2.7; estilos y turnos, 1.3.7; la franja de cine, 1.4.0). toxic3000 / La Jauría. GPL-3.0.
--
-- 1.4.0 (n.º 77, pedido de Toxic: «los anuncios siguen sin estar centrados,
-- hubo uno que me apareció cerca del mapa ... quiero ver una mejora bastante
-- clara en todos los anuncios»). La identidad nueva, distinta a la de antes
-- (el lobo suelto con su halo) y a la del juego (letras doradas sueltas):
--   * Una franja de cine: un velo oscuro que se abre como telón (de una raya
--     a su alto), con una línea de luz del color del tipo arriba y otra abajo
--     que se dibujan del centro a los lados.
--   * Un medallón sobre la línea de arriba (disco oscuro, aro con cuatro
--     muescas del color del tipo y el dibujo del tipo: tools/anuncios.py),
--     que entra creciendo y girando un poco.
--   * Jerarquía clara: el tipo arriba en mayúsculas y en su color, el nombre
--     grande en claro (rol `cine`, baja de tamaño antes de cortarse) y una
--     línea útil abajo (niveles para tu nivel, de quién es, qué hay).
--   * Siempre centrado en la pantalla: el marco cuelga de un ancla única
--     (K.AnclaAnuncio, relativa al centro de UIParent, nunca de otro marco)
--     que el jugador puede mover (K.Movible, «Acomodar») y que vuelve sola al
--     centro. La placa de la flecha ya no se lo lleva (antes el anuncio se
--     colgaba de la placa y, con la flecha junto al mapa, salía junto al
--     mapa): si la placa estorba, el anuncio baja (o sube) sin dejar el centro.
--   * ui.reduceMotion (o el modo ligero): sin movimiento, solo el fundido.
--
--   K.Anuncio({ sobre, titulo, texto, estilo = "zona", lobo = "aullando" | icono = "ic-mapa",
--               color = "exito", chico = true, segundos = 6, prioridad = 1..4,
--               caduca = GetTime() + s, vigente = fn() -> bool, clave = "zona",
--               sonido = fileID | "NOMBRE_DE_SOUNDKIT" | fn | false, espaciar = 8,
--               cuenta = { hasta = GetTime() + s, formato = "Llega en %s", final = "" },
--               alClic = fn, pista = "Clic: ir de caza", ya = true, enCombate = true })
--   K.QuitarAnuncio()            quita el que se ve y los que esperan
--   K.CerrarAnuncio()            quita solo el que se ve (clic derecho)
--   K.AnuncioEsperando() -> bool    K.AnuncioActual() -> { estilo, titulo, ... } | nil
--   K.AnuncioCola() -> { { estilo, titulo, prioridad }, ... }
--   K.AnuncioChico({ titulo, icono | lobo, color, segundos })   el ícono chico (1.3.7)
--   K.AnuncioPrendido(estilo) -> bool   si ese tipo sale como anuncio (ajustes)
--   K.ESTILOS_ANUNCIO            los estilos: color, dibujo, sonido, duración y animación
--   K.AnclaAnuncio()             el ancla (invisible, no toma el ratón) de donde cuelga
--   K.MoverAnuncio(x, y)         su lugar (desde el centro de la pantalla; anuncios.pos)
--   K.AnclaAnuncioVolver()       de vuelta a su lugar de fábrica
--
-- Los estilos (1.3.7, una animación distinta para cada tipo; 1.4.0, un dibujo):
--   general   sube un poco y aparece        zona      baja con fundido
--   subzona   fundido corto (chico)         descubrir destello dorado y huellas
--   barco     se desliza y ondea            zepelin   baja flotando con balanceo
--   tranvia   entra de lado y frena         raro      salta con rebote
--   tesoro    brillo que gira               mazmorra  sube desde abajo, morado
--   banda     sube desde abajo, ámbar       ciudad    fundido lento y azul
--   peligro   el marco late en rojo         llegada   el lobo aúlla
--   nivel     el medallón aúlla, dorado     manada    huellas que cruzan
-- Todo con un OnUpdate ligero que solo corre mientras se ve.
--
-- Los turnos (1.3.7):
--   * Una cola por prioridad (1 urgente: el barco que llega; 2: un raro, un
--     descubrimiento; 3: una zona; 4: una subzona). Uno no pisa a otro.
--   * Lo vencido caduca (`caduca`, `vigente`).
--   * El sonido suena cuando el anuncio de verdad aparece (y no otra vez al volver).
--   * Solo el contenido toma el ratón (clic: su acción; clic derecho: lo
--     cierra), nunca en combate. La franja y el velo dejan pasar los clics.
--   * Si empieza una pelea, se desvanece rápido y vuelve al terminar si aún vale.
--   * Lo que Alfa pide aguantar (N.Ocupado, Momentos.lua) detiene lo que no es urgente.
--   * Mide lo que la pantalla deja (hasta 860 px): con la interfaz grande o en
--     4:3 se angosta, y un nombre largo baja de tamaño antes de cortarse.
-- El turno con el juego (1.3.1): ZoneTextFrame, SubZoneTextFrame y los
-- estandartes del juego; un anuncio de Alfa nunca se cruza con ellos.

local _, N = ...
local K = N.Kit

local floor, max, min, format, sin, cos, abs, exp = math.floor, math.max, math.min, string.format, math.sin, math.cos, math.abs, math.exp
local type, pairs, ipairs, pcall, tonumber, tostring, rawget = type, pairs, ipairs, pcall, tonumber, tostring, rawget
local tremove, tsort = table.remove, table.sort

local HALO = "Interface\\AddOns\\Alfa_Bienvenida\\Media\\intro-halo"
local MEDIA = "Interface\\AddOns\\Alfa_Nucleo\\Media\\"
local NIEBLA, DISCO, ARO, LUZ = MEDIA .. "anuncio-niebla", MEDIA .. "anuncio-disco", MEDIA .. "anuncio-aro", MEDIA .. "anuncio-luz"
-- 1.4.0 (Toxic: «se distinguen las capas»): el fondo es UNA sola forma, una
-- elipse difuminada en todos sus bordes (anuncio-niebla), o ninguna.
--   anuncios.fondo = "suave" (de fábrica) | "nada" (sin fondo: el texto con
--   contorno y sombra, y un brillo tenue del color del tipo detrás del nombre).
-- 1.4.0 (Toxic, después: «la mancha oscura no me gusta del todo; agrégale más
-- detalle o búscale otra manera»): tres fondos con oficio, sin mancha.
--   placa      una placa ajustada al texto, de esquinas cortadas como las
--              tarjetas de Alfa, canto con luz y borde del color del tipo
--   cinta      una cinta de tela con puntas de pendón detrás del nombre
--   filigrana  sin fondo: el nombre con contorno entre dos ornamentos finos
--   suave      la sombra difuminada de antes;  nada  solo el texto
-- lineas: "todas" | "arriba" | nil (la del medallón y la de abajo).
local FONDOS = {
	placa = { niebla = 0, aura = 0.1 },
	cinta = { niebla = 0, aura = 0, contorno = true },
	filigrana = { niebla = 0, aura = 0.16, contorno = true, lineas = "arriba" },
	suave = { niebla = 0.62, aura = 0.14, lineas = "todas" },
	nada = { niebla = 0, aura = 0.2, contorno = true, lineas = "todas" },
}
local FONDO_FABRICA = "placa"
K.FONDOS_ANUNCIO = FONDOS
local function fondoAnuncio()
	local A = N.A
	local v = A and A.Get and A.Get("anuncios.fondo")
	return FONDOS[v or ""] and v or FONDO_FABRICA
end
K.FondoAnuncio = fondoAnuncio
local SALE_RAPIDO = 0.35
local ESPERA_MAX = 10   -- s: si el juego no suelta la pantalla, sale igual
local ESPERA_PLACA = 4  -- s: una zona espera a la placa de llegada que la estorba
local MIRAR = 0.4       -- s entre una mirada y otra mientras hay cola
local TOPE_COLA = 6
local ANCHO_MAX, ANCHO_MIN = 860, 380
local MED = 64          -- el medallón
local POS_Y = 0.25      -- su lugar de fábrica: un cuarto de pantalla arriba del centro
local f, fc, ancla

---------------------------------------------------------------------------
-- Los estilos
---------------------------------------------------------------------------
-- color: token del Kit (nil: el acento, oro en Clásico); tituloColor: el
-- nombre también va de ese color; caduca: s que puede esperar en la cola;
-- glifo: el dibujo del medallón (Media/anuncio-<glifo>; nil: el lobo);
-- ajuste: el interruptor que lo gobierna (anuncios.<ajuste>; nil: el suyo).
local ESTILOS = {
	general = { prioridad = 2, lobo = "aullando", segundos = 5.5, entra = 0.55, sale = 0.9, anim = "sube", raya = 170 },
	zona = { prioridad = 3, glifo = "zona", segundos = 5, entra = 0.7, sale = 1.0, anim = "baja", raya = 280,
		caduca = 12, espaciar = 8, sonido = "MAP_PING" },
	subzona = { prioridad = 4, chico = true, glifo = "rincon", segundos = 3.5, entra = 0.3, sale = 0.6, anim = "corto", raya = 90,
		caduca = 6, espaciar = 8 },
	descubrir = { prioridad = 2, color = "oro", glifo = "descubrir", segundos = 6, entra = 0.5, sale = 1.0,
		anim = "destello", raya = 220, caduca = 15, huellas = true, sonido = "UI_QUEST_ROLLING_FORWARD_01" },
	barco = { prioridad = 1, color = "pnj", glifo = "barco", segundos = 6, entra = 0.6, sale = 1.0, anim = "desliza", raya = 170 },
	zepelin = { prioridad = 1, color = "aviso", glifo = "zepelin", segundos = 6, entra = 0.9, sale = 1.0, anim = "flota", raya = 170 },
	tranvia = { prioridad = 1, color = "lugar", glifo = "tranvia", segundos = 6, entra = 0.35, sale = 0.8, anim = "frena", raya = 170 },
	raro = { prioridad = 2, color = "raro", glifo = "raro", segundos = 6.5, entra = 0.5, sale = 1.0, anim = "rebote", raya = 170 },
	tesoro = { prioridad = 2, color = "oro", glifo = "tesoro", segundos = 6.5, entra = 0.5, sale = 1.0, anim = "gira", raya = 170 },
	mazmorra = { prioridad = 2, color = "mazmorra", glifo = "mazmorra", segundos = 6, entra = 0.7, sale = 1.0,
		anim = "subeAbajo", raya = 220, caduca = 25, sonido = "IG_SPELLBOOK_OPEN" },
	banda = { prioridad = 2, color = "aviso", glifo = "banda", segundos = 6, entra = 0.8, sale = 1.0,
		anim = "asciende", raya = 260, caduca = 25, sonido = "UI_RAID_BOSS_WHISPER_WARNING", ajuste = "mazmorra" },
	ciudad = { prioridad = 3, color = "pnj", glifo = "ciudad", segundos = 5, entra = 1.1, sale = 1.4, anim = "lento",
		raya = 200, caduca = 12, espaciar = 8, sonido = "IG_MAINMENU_OPEN" },
	peligro = { prioridad = 2, color = "peligro", glifo = "peligro", segundos = 6.5, entra = 0.5, sale = 1.0,
		anim = "late", raya = 220, caduca = 15, tituloColor = true, sonido = "UI_RAID_BOSS_WHISPER_WARNING" },
	llegada = { prioridad = 2, lobo = "aullando", segundos = 5, entra = 0.5, sale = 1.0, anim = "aulla", raya = 170 },
	nivel = { prioridad = 2, color = "oro", glifo = "nivel", segundos = 6.5, entra = 0.6, sale = 1.0, anim = "corona", raya = 260,
		sonido = "UI_WORLDQUEST_COMPLETE" },
	manada = { prioridad = 2, color = "acento", glifo = "manada", segundos = 7, entra = 0.5, sale = 1.0,
		anim = "cruzan", raya = 170, huellas = true, sonido = "IG_PLAYER_INVITE" },
}
K.ESTILOS_ANUNCIO = ESTILOS

-- 1.3.8 (pedido de Toxic: «más cine»): el sonido de cada tipo, distinto y
-- suave (SOUNDKIT del juego, revisados en referencia/), y sus partículas:
-- n, color (nil: el del anuncio), mov = "sube" | "flota" | "lado" | "chispa" | "gira",
-- vel (px/s), tam (px). Los del barco, zepelín y tranvía suenan con su
-- propio sonido del juego (Nav/Alerts.lua); el raro, con el suyo (Rares).
ESTILOS.subzona.sonido = false
ESTILOS.ciudad.sonido = "UI_GARRISON_TOAST_BUILDING_COMPLETE"
ESTILOS.mazmorra.sonido = "UI_WORLDQUEST_START"
ESTILOS.tesoro.sonido = "UI_DIG_SITE_COMPLETION_TOAST"
ESTILOS.llegada.sonido = "UI_WORLDQUEST_COMPLETE"
ESTILOS.nivel.sonido = "UI_LEGENDARY_LOOT_TOAST"
ESTILOS.banda.sonido = "UI_EPICLOOT_TOAST"
local PARTICULAS = {
	general = { n = 6, mov = "sube", vel = 10, tam = 6 },
	zona = { n = 10, mov = "flota", vel = 9, tam = 7 },
	descubrir = { n = 14, color = "oro", mov = "chispa", vel = 26, tam = 6 },
	barco = { n = 10, color = "pnj", mov = "lado", vel = 22, tam = 6 },
	zepelin = { n = 8, mov = "flota", vel = 6, tam = 10 },
	tranvia = { n = 8, color = "aviso", mov = "lado", vel = 60, tam = 4 },
	raro = { n = 10, mov = "chispa", vel = 30, tam = 5 },
	tesoro = { n = 14, color = "oro", mov = "gira", vel = 1.3, tam = 6 },
	mazmorra = { n = 12, mov = "sube", vel = 14, tam = 7 },
	banda = { n = 14, mov = "sube", vel = 18, tam = 6 },
	ciudad = { n = 8, mov = "flota", vel = 5, tam = 8 },
	peligro = { n = 12, mov = "sube", vel = 20, tam = 5 },
	llegada = { n = 8, mov = "chispa", vel = 20, tam = 6 },
	nivel = { n = 14, color = "oro", mov = "chispa", vel = 34, tam = 6 },
	manada = { n = 6, mov = "sube", vel = 10, tam = 6 },
}
K.PARTICULAS_ANUNCIO = PARTICULAS
local MAX_PARTICULAS = 14
-- El orden en que se enseñan (Ajustes).
K.ORDEN_ANUNCIOS = { "zona", "subzona", "descubrir", "ciudad", "mazmorra", "peligro", "barco", "zepelin", "tranvia", "raro", "tesoro", "manada" }

-- Cada tipo se puede apagar (anuncios.<tipo>); la subzona sale chica de fábrica.
do
	local A = N.A
	if A and A.RegisterDefaults then
		local d = { sonido = true, subzonaChica = true, fondo = "placa" }
		for _, e in ipairs(K.ORDEN_ANUNCIOS) do d[e] = true end
		A.RegisterDefaults("anuncios", d)
	end
end

local function ahora() return GetTime and GetTime() or 0 end

function K.AnuncioPrendido(estilo)
	local A = N.A
	if not (A and A.Get) then return true end
	-- Momentos.lua: un solo ajuste manda sobre los anuncios grandes (y la calma).
	local G = rawget(N, "AnunciosGrandes")
	if type(G) == "function" then
		local ok, si = pcall(G)
		if ok and not si then return false end
	else
		if A.Get("bienvenida.anuncios") == false then return false end
	end
	local est = estilo and ESTILOS[estilo]
	if est and A.Get("anuncios." .. (est.ajuste or estilo)) == false then return false end
	return true
end

local function estiloDe(o) return ESTILOS[o and o.estilo or "general"] or ESTILOS.general end
local function prioridad(o) return tonumber(o.prioridad) or estiloDe(o).prioridad or 2 end
local function tono(o, est)
	if o and o.color then return o.color end
	-- 1.3.9: con la temática de tu bando, lo que iba en el acento va en su color.
	if (est.color == nil or est.color == "acento") and K.Bando then
		local B = K.Bando()
		if B then return B.color end
	end
	return est.color or (K.Clasico() and "oro" or "acento")
end

-- 1.4.0: sin movimiento (modo ligero o «Menos movimiento»).
local function quieto()
	if N.Ligero and N.Ligero() then return true end
	local A = N.A
	return (A and A.Get and A.Get("ui.reduceMotion")) and true or false
end

---------------------------------------------------------------------------
-- Lo que no se debe tapar
---------------------------------------------------------------------------
-- Lo que el juego pinta arriba del centro y que un anuncio no debe tapar.
local DEL_JUEGO = { "ZoneTextFrame", "SubZoneTextFrame", "BossBanner", "EventToastManagerFrame", "LevelUpDisplay" }
-- tapa: los del juego que ese anuncio esconde al salir (o.tapaJuego, 1.3.7:
-- el nombre de la zona de Alfa sale en lugar del del juego; no lo espera).
local function juegoOcupado(tapa)
	for _, nombre in ipairs(DEL_JUEGO) do
		local g = rawget(_G, nombre)
		local suyo = false
		if type(tapa) == "table" then for _, t in ipairs(tapa) do if t == nombre then suyo = true end end end
		if not suyo and type(g) == "table" and g.IsShown and g:IsShown() then
			local a = g.GetAlpha and g:GetAlpha()
			if type(a) ~= "number" or a > 0.05 then return true end
		end
	end
	return false
end
K.JuegoOcupaArriba = juegoOcupado

-- PLAYER_REGEN_DISABLED llega antes del bloqueo de combate: entre ese y
-- REGEN_ENABLED cuenta como pelea.
local pelea = false
local function enCombate() return pelea or ((InCombatLockdown and InCombatLockdown()) and true) or false end

-- La placa de llegada de la flecha (Nav/Arrow.lua, Arrow.PlacaMarco).
local function placa()
	local A = N.A
	local Nv = A and rawget(A, "Nav")
	local Ar = type(Nv) == "table" and rawget(Nv, "arrow")
	local fn = type(Ar) == "table" and rawget(Ar, "PlacaMarco")
	if type(fn) ~= "function" then return nil end
	local ok, p = pcall(fn)
	if ok and type(p) == "table" and p.IsShown and p:IsShown() then return p end
	return nil
end

-- Lo que Alfa pide aguantar (Momentos.lua: pantalla de carga, cinemática,
-- hablando con un PNJ, /alfa calma...).
-- (La pelea la cuida este archivo: un anuncio con enCombate sí sale.)
local function ocupado(p)
	local Oc = rawget(N, "Ocupado")
	if type(Oc) ~= "function" then return false end
	local ok, v, motivo = pcall(Oc, "anuncio", p)
	return ok and v and motivo ~= "combate" and true or false
end

-- mostrando: el que ya se ve no caduca por la hora (termina su rato), solo si deja de valer.
local function vigente(o, mostrando)
	if not mostrando and o.caduca and ahora() > o.caduca then return false end
	if type(o.vigente) == "function" then
		local ok, v = pcall(o.vigente)
		if ok and not v then return false end
	end
	return true
end

---------------------------------------------------------------------------
-- El ancla (1.4.0): un solo lugar, relativo al centro de la pantalla
---------------------------------------------------------------------------
local function num(v, d) v = tonumber(v) return (v and v == v) and v or d end
local function tamPantalla()
	local w = UIParent and UIParent.GetWidth and num(UIParent:GetWidth(), 0) or 0
	local h = UIParent and UIParent.GetHeight and num(UIParent:GetHeight(), 0) or 0
	if w <= 0 then w = 1920 end
	if h <= 0 then h = 1080 end
	return w, h
end

-- Dónde va: lo guardado (anuncios.pos = { x, y } desde el centro) o un
-- cuarto de pantalla arriba del centro; siempre dentro de la pantalla.
local function lugarAncla()
	local w, h = tamPantalla()
	local x, y = 0, floor(h * POS_Y + 0.5)
	local A = N.A
	local pos = A and A.Get and A.Get("anuncios.pos")
	if type(pos) == "table" and tonumber(pos.x) and tonumber(pos.y) then x, y = tonumber(pos.x), tonumber(pos.y) end
	local mx, my = max(0, w / 2 - 140), max(0, h / 2 - 70)
	return max(-mx, min(mx, x)), max(-my, min(my, y))
end

local function colocarAncla()
	if not ancla then return end
	local x, y = lugarAncla()
	ancla:ClearAllPoints()
	ancla:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

function K.AnclaAnuncio()
	if ancla then return ancla end
	ancla = CreateFrame("Frame", "AlfaAnuncioAncla", UIParent)
	ancla:SetSize(560, 150)
	ancla:SetFrameStrata("HIGH")
	ancla:EnableMouse(false)
	colocarAncla()
	return ancla
end

function K.MoverAnuncio(x, y)
	local A = N.A
	x, y = tonumber(x), tonumber(y)
	if not (x and y) then return false end
	if A and A.Set then A.Set("anuncios.pos", { x = floor(x + 0.5), y = floor(y + 0.5) }) end
	K.AnclaAnuncio()
	colocarAncla()
	return true
end

function K.AnclaAnuncioVolver()
	local A = N.A
	if A and A.Set then A.Set("anuncios.pos", nil) end
	K.AnclaAnuncio()
	colocarAncla()
	return true
end

-- Lo que mide un marco en unidades de UIParent: l, b, w, h.
local function rectUI(fr)
	if not (fr and fr.GetRect) then return nil end
	local l, b, w, h = fr:GetRect()
	l, b, w, h = num(l), num(b), num(w), num(h)
	if not (l and b and w and h) then return nil end
	local ue = UIParent.GetEffectiveScale and num(UIParent:GetEffectiveScale(), 1) or 1
	local fe = fr.GetEffectiveScale and num(fr:GetEffectiveScale(), ue) or ue
	local k = (ue > 0) and fe / ue or 1
	return l * k, b * k, w * k, h * k
end

-- ¿Cuánto hay que bajar (o subir) el anuncio para no tapar la placa de la
-- flecha? 0 si no estorba. Medido en unidades del anuncio; nunca deja el centro.
-- alto / ancho: lo que mide el contenido (el velo se desvanece a los lados).
local function desvioPlaca(alto, ancho)
	local p = placa()
	if not p then return 0, false end
	local pl, pb, pw, ph = rectUI(p)
	K.AnclaAnuncio()
	local ax, ay = ancla:GetCenter()
	ax, ay = num(ax), num(ay)
	if not (pl and ax and ay) then return 0, false end
	local ue = UIParent.GetEffectiveScale and num(UIParent:GetEffectiveScale(), 1) or 1
	local fe = (f and f.GetEffectiveScale) and num(f:GetEffectiveScale(), ue) or ue
	local k = (ue > 0) and fe / ue or 1
	local hh, cw = (alto or 170) * k / 2, (ancho or 400) * k / 2
	local top, bottom = ay + hh, ay - hh
	if not (pl < ax + cw and pl + pw > ax - cw and pb < top and pb + ph > bottom) then return 0, false end
	local _, H = tamPantalla()
	local abajo = (pb - 6) - top
	if bottom + abajo >= H * 0.3 then return abajo / k, true end
	local arriba = (pb + ph + 6) - bottom
	if top + arriba <= H - 4 then return arriba / k, true end
	return 0, true
end

---------------------------------------------------------------------------
-- La cola
---------------------------------------------------------------------------
local cola, seq = {}, 0
local actual           -- el `o` del que se ve
local ultimoInicio = -math.huge
local mostrar, revisar -- abajo
local pintarFondo      -- abajo (1.4.0)

-- ¿La placa estorba donde saldría (o donde está) el anuncio?
local function placaEstorba()
	local alto = f and f:IsShown() and f:GetHeight() or 190
	local ancho = f and f.alfaContenidoW or 420
	local _, estorba = desvioPlaca(alto, ancho)
	return estorba
end

local function bloqueo(e)
	local o = e.o
	local A = N.A
	if A and A.Hidden and A.Hidden() then return "oculto" end
	if enCombate() and not o.enCombate then return "combate" end
	local p = prioridad(o)
	if ocupado(p) then return "ocupado" end
	local t = ahora()
	if not o.ya and juegoOcupado(o.tapaJuego) and t - e.desde < ESPERA_MAX then return "juego" end
	if p >= 3 and t - e.desde < ESPERA_PLACA and placaEstorba() then return "placa" end
	if o.espaciar and t - ultimoInicio < o.espaciar then return "espaciar" end
	return nil
end
K.AnuncioBloqueo = function(o) return bloqueo({ o = o, desde = ahora() }) end

local function programar(s)
	if N.Una then N.Una("kit.anuncio", s or MIRAR, function() revisar() end)
	elseif C_Timer and C_Timer.After then C_Timer.After(s or MIRAR, function() revisar() end) end
end

local function ordenar()
	tsort(cola, function(a, b)
		local pa, pb = prioridad(a.o), prioridad(b.o)
		if pa ~= pb then return pa < pb end
		return a.n < b.n
	end)
end

-- 1.3.7 (51): un barco o un raro que se fue sin verse (caducó en la fila,
-- no cupo o se quitó) queda en «Lo que me perdí» (N.Perdido, Momentos.lua).
local PERDIBLES = { barco = true, zepelin = true, tranvia = true, raro = true, tesoro = true }
-- (1.3.8 revisión) o.alPerder(o): quien lo pidió se entera de que no salió
-- (caducó, no cupo o se calló); Zonas.lua devuelve ahí el nombre del juego.
local function avisarPerdido(o)
	if type(o) ~= "table" or type(o.alPerder) ~= "function" or o.alfaAvisoPerdido then return end
	o.alfaAvisoPerdido = true
	K.Llamar(o.alPerder, o)
end
K.AvisarPerdido = avisarPerdido
local function perdidoAnuncio(o)
	avisarPerdido(o)
	if type(o) ~= "table" or o.perdido == false or o.alfaPerdido then return end
	if not PERDIBLES[o.estilo or ""] then return end
	local Pe = rawget(N, "Perdido")
	if type(Pe) ~= "function" then return end
	o.alfaPerdido = true
	local est = ESTILOS[o.estilo]
	local ac
	if type(o.alClic) == "function" and type(o.pista) == "string" and o.pista ~= "" then
		ac = { texto = (o.pista:gsub("^[^:]+:%s*", "")), alClic = o.alClic }
	end
	pcall(Pe, { titulo = o.titulo, texto = o.texto or o.sobre, icono = o.icono or (est and est.icono) or "ic-lobo",
		accion = ac, origen = "anuncio" })
end
K.AnuncioPerdido = perdidoAnuncio -- (para el banco)

local function encolar(o, desde)
	if o.clave then
		for i = #cola, 1, -1 do if cola[i].o.clave == o.clave then tremove(cola, i) end end
	end
	seq = seq + 1
	cola[#cola + 1] = { o = o, desde = desde or ahora(), n = seq }
	ordenar()
	while #cola > TOPE_COLA do perdidoAnuncio(tremove(cola).o) end
	programar()
end

revisar = function()
	for i = #cola, 1, -1 do
		if not vigente(cola[i].o) then perdidoAnuncio(tremove(cola, i).o) end
	end
	if f and f:IsShown() then
		if #cola > 0 then programar() end
		return
	end
	ordenar()
	for i, e in ipairs(cola) do
		if not bloqueo(e) then
			tremove(cola, i)
			mostrar(e.o)
			break
		end
	end
	if #cola > 0 then programar() end
end

-- El que se ve se va antes de tiempo: vuelve después con lo que le quedaba.
local function reencolar(self, t)
	local o = self.alfaO
	if not o then return end
	local queda = (self.alfaDura or 6) - (t or 0)
	if queda <= 1.5 then return end
	local c = {}
	for k, v in pairs(o) do c[k] = v end
	c.segundos = max(3, queda)
	c.vuelve = true
	encolar(c)
end

---------------------------------------------------------------------------
-- Medidas
---------------------------------------------------------------------------
local function anchoPantalla()
	local w = UIParent and UIParent.GetWidth and tonumber(UIParent:GetWidth()) or 0
	if not w or w <= 0 then w = 1024 end
	return floor(max(ANCHO_MIN, min(ANCHO_MAX, w * 0.62)))
end
K.AnchoAnuncio = anchoPantalla

-- El nombre grande: baja de tamaño antes de cortarse (y si ni así cabe, dos líneas).
local ROLES_TITULO = { "cine", "anuncio", "portada", "titulo" }
local function ajustarTitulo(fs, texto, maxW, chico)
	fs:SetWordWrap(false)
	if fs.SetMaxLines then fs:SetMaxLines(1) end
	fs:SetWidth(maxW)
	local desde = chico and 4 or 1
	if not (K.TIPO and K.TIPO.cine) and desde == 1 then desde = 2 end
	for i = desde, #ROLES_TITULO do
		fs.alfaRol = ROLES_TITULO[i]
		K.Fuente(fs)
		fs:SetText(texto)
		if K.AnchoTexto(fs) <= maxW then break end
	end
	local w = K.AnchoTexto(fs)
	if w > maxW then
		fs:SetWordWrap(true)
		if fs.SetMaxLines then fs:SetMaxLines(2) end
		fs:SetWidth(maxW)
	end
	-- (todo el ancho, centrado: con la letra real nunca se corta por un píxel)
	return min(w, maxW)
end

local function mmss(s)
	s = max(0, floor((s or 0) + 0.5))
	return format("%d:%02d", floor(s / 60), s % 60)
end

local function alto(fs)
	local h = fs.GetStringHeight and num(fs:GetStringHeight(), 0) or 0
	if h <= 0 then h = fs.GetHeight and num(fs:GetHeight(), 0) or 0 end
	return h
end

---------------------------------------------------------------------------
-- Las animaciones: (marco, t, e de entrada 0..1, dt) -> dx, dy del contenido
---------------------------------------------------------------------------
local function suave(x) x = max(0, min(1, x)) return x * x * (3 - 2 * x) end
-- Llega, se pasa un poco y se asienta (el medallón).
local function rebota(x)
	x = max(0, min(1, x))
	return 1 - (1 - x) * (1 - x) * (1 - 2.6 * x)
end
local function halo(self, t, base, vaiven)
	self.Halo:SetAlpha((base or 0.3) + (vaiven or 0.12) * sin(t * 2.2))
end

local ANIM = {}
ANIM.sube = function(self, t, e) halo(self, t) return 0, -(1 - suave(e)) * 14 end
ANIM.baja = function(self, t, e) halo(self, t) return 0, (1 - suave(e)) * 22 end
ANIM.corto = function() return 0, 0 end
ANIM.lento = function(self, t) halo(self, t * 0.5, 0.28, 0.1) return 0, 0 end
ANIM.destello = function(self, t, e)
	-- El destello: el halo crece y brilla al entrar, y luego respira.
	local d = max(0, 1 - t / 0.7)
	self.Halo:SetSize(130 * (1 + 0.9 * d), 130 * (1 + 0.9 * d))
	self.Halo:SetAlpha(0.35 + 0.6 * d + 0.12 * sin(t * 2.2) * (1 - d))
	-- Las huellas se dibujan una a una.
	if self.Huellas and self.Huellas:IsShown() then
		local n = min(6, floor(max(0, t - 0.3) / 0.28))
		if n ~= self.alfaPasos then self.alfaPasos = n self.Huellas:Set(n, 6) end
	end
	return 0, -(1 - suave(e)) * 10
end
ANIM.desliza = function(self, t, e)
	halo(self, t)
	return -(1 - suave(e)) * 60, (e >= 1) and sin(t * 2.4) * 2 or 0
end
ANIM.flota = function(self, t, e)
	halo(self, t)
	if self.Lobo.SetRotation then self.Lobo:SetRotation(0.12 * sin(t * 1.6)) end
	return sin(t * 1.1) * 4, (1 - suave(e)) * 34 + sin(t * 1.6) * 3
end
ANIM.frena = function(self, t, e, entra)
	halo(self, t)
	if t < entra then
		local p = t / entra
		return (1 - p) * (1 - p) * (1 - p) * 110, 0
	end
	local s = t - entra
	return -4 * exp(-s * 10) * cos(s * 38), 0
end
ANIM.rebote = function(self, t)
	halo(self, t)
	return 0, 20 * abs(sin(t * 7)) * max(0, 1 - t / 1.0)
end
ANIM.gira = function(self, t)
	if self.Halo.SetRotation then self.Halo:SetRotation(t * 1.4) end
	self.Halo:SetAlpha(0.45 + 0.2 * sin(t * 3))
	return 0, 0
end
ANIM.subeAbajo = function(self, t, e) halo(self, t) return 0, -(1 - suave(e)) * 40 end
-- 1.4.0: la banda sube más despacio y el aro se enciende al llegar.
ANIM.asciende = function(self, t, e)
	halo(self, t, 0.3 + 0.3 * max(0, 1 - abs(t - 0.9) / 0.4), 0.1)
	return 0, -(1 - suave(e)) * 56
end
ANIM.late = function(self, t)
	local a = 0.3 + 0.7 * abs(sin(t * 3.5))
	for _, b in ipairs(self.Borde) do b:SetAlpha(a) end
	self.RayaI:SetAlpha(a)
	self.RayaD:SetAlpha(a)
	halo(self, t, 0.3, 0.2)
	return 0, 0
end
ANIM.aulla = function(self, t)
	local p = min(1, t / 0.9)
	local s = 1 + 0.3 * sin(p * math.pi)
	self.Lobo:SetSize(self.alfaLoboTam * s, self.alfaLoboTam * s)
	self.Halo:SetSize(130 * (1 + 0.4 * sin(p * math.pi)), 130 * (1 + 0.4 * sin(p * math.pi)))
	halo(self, t)
	return 0, 0
end
-- 1.4.0 (nivel): el medallón late dos veces, como un tambor.
ANIM.corona = function(self, t, e)
	local p = min(1, t / 1.2)
	local s = 1 + 0.22 * abs(sin(p * math.pi * 2))
	self.Lobo:SetSize(self.alfaLoboTam * s, self.alfaLoboTam * s)
	halo(self, t, 0.45, 0.2)
	return 0, -(1 - suave(e)) * 18
end
ANIM.cruzan = function(self, t)
	halo(self, t)
	local h = self.Huellas
	if h and h:IsShown() then
		local ancho = self:GetWidth()
		local w = h:GetWidth()
		local x = -ancho / 2 - w + ((t * 150) % (ancho + w * 2))
		h:ClearAllPoints()
		h:SetPoint("LEFT", self.Velo, "BOTTOM", x, 2)
	end
	return 0, 0
end
K.ANIMACIONES_ANUNCIO = ANIM

---------------------------------------------------------------------------
-- El cine de todos (1.3.8; 1.4.0: el telón, el medallón y las líneas).
-- Todo en el mismo OnUpdate, solo mientras se ve; quieto, nada de esto.
---------------------------------------------------------------------------
local PI = math.pi
local function semilla(i, k)
	local x = sin(i * 12.9898 + k * 78.233) * 43758.5453
	return x - floor(x)
end
local SIN_PROFUNDIDAD = { destello = true, aulla = true, gira = true, corona = true }
-- 1.3.9 (105): la onda de entrada de cada animación: cuánto se abre (px),
-- cuánto dura (s) y qué tan fuerte brilla.
local ONDA = {
	general = { ancho = 160, dura = 0.8, fuerza = 0.45 },
	sube = { ancho = 160, dura = 0.8, fuerza = 0.45 },
	baja = { ancho = 220, dura = 1.0, fuerza = 0.35 },
	corto = { ancho = 80, dura = 0.4, fuerza = 0.25 },
	lento = { ancho = 200, dura = 1.6, fuerza = 0.3 },
	destello = { ancho = 300, dura = 0.9, fuerza = 0.7 },
	desliza = { ancho = 240, dura = 1.1, fuerza = 0.4 },
	flota = { ancho = 180, dura = 1.4, fuerza = 0.35 },
	frena = { ancho = 140, dura = 0.5, fuerza = 0.55 },
	rebote = { ancho = 200, dura = 0.6, fuerza = 0.6 },
	gira = { ancho = 220, dura = 1.0, fuerza = 0.5 },
	subeAbajo = { ancho = 200, dura = 0.9, fuerza = 0.45 },
	asciende = { ancho = 320, dura = 1.2, fuerza = 0.55 },
	late = { ancho = 260, dura = 0.7, fuerza = 0.6 },
	aulla = { ancho = 280, dura = 1.0, fuerza = 0.55 },
	corona = { ancho = 340, dura = 1.1, fuerza = 0.7 },
	cruzan = { ancho = 180, dura = 0.9, fuerza = 0.4 },
}
K.ONDA_ANUNCIO = ONDA

-- El telón: el alto del velo (k de 0 a 1) y las líneas que lo siguen.
local function telon(x, k)
	local h = max(2, floor((x.alfaBandaH or 60) * k + 0.5))
	if h == x.alfaVeloH then return end
	x.alfaVeloH = h
	x.Velo:SetHeight(h)
	-- (más alta que la banda: las líneas de arriba y abajo quedan dentro de su difuminado)
	x.Niebla:SetHeight(max(1, floor(h * (x.alfaChico and 3.4 or 2.1) + 0.5)))
	x.Niebla:SetAlpha((x.alfaNiebla or 0) * min(1, 0.25 + 0.75 * k))
end

-- Las líneas de luz: cuánto se abren (r de 0 a 1).
local function lineas(x, r)
	local w = max(1, floor((x.alfaLineaW or 200) * r + 0.5))
	if w == x.alfaRayaW then return end
	x.alfaRayaW = w
	x.RayaI:SetWidth(w)
	x.RayaD:SetWidth(w)
	local w2 = max(1, floor(((x.alfaLineaW or 200) + (x.alfaHueco or 0)) * r + 0.5))
	x.LineaI:SetWidth(w2)
	x.LineaD:SetWidth(w2)
	if x.Tira and x.Tira:IsShown() then x.Tira:SetWidth(max(1, w2 * 2)) end
	-- La cinta se despliega del centro y la filigrana crece hacia los lados.
	if x.CintaC:IsShown() then
		x.CintaC:SetWidth(max(1, floor((x.alfaCintaW or 100) * (0.12 + 0.88 * r) + 0.5)))
		x.CintaI:SetAlpha(r) x.CintaD:SetAlpha(r)
	end
	if x.FiliI:IsShown() then
		local fw = max(1, floor((x.alfaFiliW or 100) * r + 0.5))
		x.FiliI:SetWidth(fw) x.FiliD:SetWidth(fw)
		local q = 1 - r
		x.FiliI:SetTexCoord(q, 1, 0, 1)
		x.FiliD:SetTexCoord(1, q, 0, 1)
	end
end

local function prepararCine(x, o, est, chico, tw)
	local p = (not chico and not x.alfaLigero) and PARTICULAS[o.estilo or "general"] or nil
	if o.particulas == false then p = nil end
	x.alfaP = p
	x.alfaTW = tw or 200
	x.alfaBandaW = nil
	x.alfaConBrillo = not chico and not x.alfaLigero
	x.alfaProfundo = x.alfaConBrillo and not SIN_PROFUNDIDAD[est.anim or ""]
	local r, g, b = K.Color(tono(o, est))
	local pr, pg, pb = r, g, b
	if p and p.color then pr, pg, pb = K.Color(p.color) end
	for i, t in ipairs(x.Polvo) do
		if p and i <= p.n then
			local s = (p.tam or 6) * (1.0 + 0.9 * semilla(i, 6))
			t:SetSize(s, s)
			t:SetVertexColor(pr, pg, pb, 1)
			t:SetAlpha(0)
			t:Show()
		else
			t:Hide()
		end
	end
	local h = max(20, alto(x.Titulo))
	x.BrilloI:SetSize(min(220, (tw or 200) * 0.45 + 60), h + 14)
	x.BrilloD:SetSize(160, 6)
	x.BrilloI:SetVertexColor(1, 1, 1, 1)
	x.BrilloD:SetVertexColor(r, g, b, 1)
	x.BrilloI:Hide()
	x.BrilloD:Hide()
	-- (1.4.0: los dos rectángulos de luz detrás del nombre ya no se usan:
	-- «se distinguen las capas»; el aura de abajo es una sola elipse.)
	x.BandaI:Hide()
	x.BandaD:Hide()
	x.Tinte:SetVertexColor(r, g, b, 1)
	x.Tinte:SetSize(min((x:GetWidth() or 600) - 20, (tw or 200) + 200), h * 2.6)
	x.Tinte:SetAlpha(x.alfaConBrillo and 0 or (x.alfaAura or 0))
	x.Sobre:SetAlpha(x.alfaConBrillo and 0 or 1)
	x.Texto:SetAlpha(x.alfaConBrillo and 0 or 1)
	x.Pista:SetAlpha(x.alfaConBrillo and 0 or 1)
	if x.Titulo.SetTextScale then pcall(x.Titulo.SetTextScale, x.Titulo, 1) end
end

-- El medallón a su tamaño (s: escala) y su giro.
local function medallon(x, s, giro)
	local m = floor(MED * s + 0.5)
	if m ~= x.alfaMedW then
		x.alfaMedW = m
		x.Disco:SetSize(max(1, m - 4), max(1, m - 4))
		x.Aro:SetSize(max(1, m), max(1, m))
	end
	if x.Aro.SetRotation then x.Aro:SetRotation(giro or 0) end
end

local function cine(self, t, a, fuera)
	local entra = self.alfaEntra or 0.55
	if self.alfaConBrillo then
		-- La línea de arriba y la de abajo, un instante después del nombre.
		local s1 = min(1, max(0, (t - 0.18) / 0.4))
		local s2 = min(1, max(0, (t - 0.36) / 0.45))
		self.Sobre:SetAlpha(s1)
		self.Texto:SetAlpha(s2)
		self.Pista:SetAlpha(s2)
		-- La luz de color detrás del nombre se abre desde el centro y se cierra al salir.
		local ab = suave(t / (entra * 1.3)) * (1 - suave(fuera or 0))
		self.Tinte:SetAlpha((self.alfaAura or 0) * ab * a)
		-- El medallón: llega chico, se pasa un poco, se asienta y gira un poco.
		if not self.alfaChico then
			local q = min(1, t / (entra * 1.1))
			medallon(self, 0.55 + 0.45 * rebota(q), (1 - suave(q)) * -0.9)
		end
		-- La luz que cruza el nombre (y su reflejo en la línea de abajo, al revés).
		local s = (t - entra * 0.7) / 0.85
		if s > 0 and s < 1 and not fuera then
			local tw = self.alfaTW or 200
			local px = -tw / 2 - 40 + s * (tw + 80)
			local al = sin(s * PI) * a
			self.BrilloI:ClearAllPoints()
			self.BrilloI:SetPoint("CENTER", self.Titulo, "CENTER", px, 0)
			self.BrilloI:SetAlpha(al * 0.8)
			self.BrilloI:Show()
			self.BrilloD:ClearAllPoints()
			self.BrilloD:SetPoint("CENTER", self.Velo, "BOTTOM", -px, 0)
			self.BrilloD:SetAlpha(al)
			self.BrilloD:Show()
		elseif self.BrilloI:IsShown() then
			self.BrilloI:Hide()
			self.BrilloD:Hide()
		end
	end
	-- La profundidad: el halo llega grande y se asienta; el nombre se acerca.
	if self.alfaProfundo then
		local k = 1 - suave(t / (entra * 1.6))
		local abre = fuera or 0
		local s = 130 * (1 + 1.1 * k + 0.35 * abre)
		self.Halo:SetSize(s, s)
		if k > 0 and self.Titulo.SetTextScale then pcall(self.Titulo.SetTextScale, self.Titulo, 1 + 0.12 * k) end
	end
	-- 1.3.9 (105): la onda que se abre desde el medallón al entrar, el emblema
	-- del bando que asoma detrás y se asienta.
	local onda = ONDA[self.alfaAnim or ""] or ONDA.general
	if self.Onda:IsShown() then
		local q = t / onda.dura
		if q < 1 then
			local s = 70 + onda.ancho * suave(q)
			self.Onda:SetSize(s, s)
			self.Onda:SetAlpha(onda.fuerza * (1 - q) * (1 - q) * a)
		else
			self.Onda:Hide()
		end
	end
	if self.alfaTema then
		local k = suave((t - 0.15) / (entra * 1.4))
		local s = 100 * (1.25 - 0.25 * k)
		self.Emblema:SetSize(s, s)
		self.Emblema:SetAlpha(0.3 * k * a * (1 - (fuera or 0)))
	end
	-- El polvo.
	local p = self.alfaP
	if not p then return end
	local tw = self.alfaTW or 200
	local W = tw + 160
	local cy = self.alfaCentroY or -100
	for i = 1, p.n do
		local tex = self.Polvo[i]
		local vida = 1.8 + semilla(i, 1) * 1.4
		local fase = ((t + semilla(i, 2) * vida) % vida) / vida
		local x0 = (semilla(i, 3) - 0.5) * W
		local y0 = cy + (semilla(i, 4) - 0.5) * (self.alfaBandaH or 60) * 0.8
		local dx, dy = 0, 0
		local mov = p.mov
		if mov == "sube" then
			dx, dy = sin((t + i) * 1.3) * 4, (fase - 0.3) * p.vel * vida
		elseif mov == "flota" then
			dx, dy = sin(t * 0.7 + i) * p.vel * 1.5, cos(t * 0.5 + i * 2) * p.vel * 0.8 + fase * 6
		elseif mov == "lado" then
			dx, dy = (fase - 0.5) * p.vel * vida * 2, sin(fase * PI * 2 + i) * 3
		elseif mov == "chispa" then
			dx = (semilla(i, 5) - 0.5) * p.vel * vida * fase * 2
			dy = p.vel * vida * fase * (1 - fase) * 2
			x0 = x0 * 0.5
		elseif mov == "gira" then
			local ang = t * p.vel + i * (2 * PI / p.n)
			x0, y0 = 0, cy
			dx, dy = cos(ang) * (tw / 2 + 22), sin(ang) * 24
			fase = 0.5
		end
		tex:ClearAllPoints()
		tex:SetPoint("CENTER", self.C, "TOP", floor(x0 + dx + 0.5), floor(y0 + dy + 0.5))
		tex:SetAlpha(sin(fase * PI) * 0.8 * a * (1 - (fuera or 0)))
	end
end
K.CineAnuncio = cine -- (para el banco)

---------------------------------------------------------------------------
-- El marco
---------------------------------------------------------------------------
local function pintar(x)
	local o = x.alfaO
	local est = estiloDe(o)
	local token = tono(o, est)
	local r, g, b = K.Color(token)
	x.Lobo:SetVertexColor(r, g, b, 1)
	x.Halo:SetVertexColor(r, g, b, 1)
	x.Aro:SetVertexColor(r, g, b, 1)
	x.Tinte:SetVertexColor(r, g, b, 1)
	x.Velo:SetAlpha(0) -- (la banda no se pinta: de ella cuelgan las líneas)
	x.Niebla:SetVertexColor(0, 0, 0, 1)
	x.Disco:SetVertexColor(0.035, 0.045, 0.06, 1)
	x.Disco:SetAlpha(0.96)
	if CreateColor then
		x.RayaI:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.95))
		x.RayaD:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.95), CreateColor(r, g, b, 0))
		x.LineaI:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.6))
		x.LineaD:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.6), CreateColor(r, g, b, 0))
	end
	K.ColorTexto(x.Sobre, token)
	K.ColorTexto(x.Titulo, est.tituloColor and token or "texto")
	for _, t in ipairs(x.Borde) do t:SetColorTexture(r, g, b, 0.9) end
end

local function cerrar(self)
	if not (f and f:IsShown()) then return end
	f.alfaO = nil
	f:Hide()
end

local function tocar(boton)
	if not (f and f:IsShown()) then return end
	-- 1.4.0: Mayús+arrastre lo mueve (Kit/Movible.lua): ese clic no lo cierra.
	if boton == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() and K.MovibleConMayus and K.MovibleConMayus() then return end
	if boton == "RightButton" then cerrar() return end
	local fn = f.alfaClic
	if fn and not enCombate() then
		K.Llamar(fn)
	end
	cerrar()
end

-- Quién toma el ratón: la franja entera nunca (no estorba los clics alrededor:
-- un PNJ, girar la cámara); el bloque del contenido y su X, solo fuera de
-- combate. Se mira con InCombatLockdown al armar, al mostrar y en cada cambio
-- de pelea, así no depende de si ya peleaste antes.
local function raton()
	if not f then return end
	local si = not enCombate() and not f.alfaSaliendo
	f:EnableMouse(false)
	f.Toque:EnableMouse(si)
	f.X:EnableMouse(si)
end

local function capa(t, nombre, sub)
	if t.SetDrawLayer then t:SetDrawLayer(nombre, sub) end
	return t
end

local function armar()
	f = CreateFrame("Frame", "AlfaAnuncio", K.Raiz())
	f:SetSize(ANCHO_MAX, 190)
	f:SetPoint("CENTER", K.AnclaAnuncio(), "CENTER", 0, 0)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(false)
	f:Hide()
	-- El contenido se mueve entero con la animación.
	f.C = CreateFrame("Frame", nil, f)
	f.C:SetAllPoints(f)
	local C = f.C

	-- 1.4.0: el telón (velo oscuro con bordes suaves) y su tinte del color del tipo.
	-- 1.4.0: la banda (invisible: mide el telón y de ella cuelgan las
	-- líneas), la niebla (una elipse oscura difuminada) y el aura del color
	-- del tipo detrás del nombre (otra elipse, centrada en el nombre).
	f.Velo = C:CreateTexture(nil, "BACKGROUND", nil, -8)
	f.Velo:SetColorTexture(0, 0, 0, 1)
	f.Velo:SetAlpha(0)
	f.Niebla = C:CreateTexture(nil, "BACKGROUND", nil, -7)
	f.Niebla:SetTexture(NIEBLA)
	f.Niebla:SetPoint("CENTER", f.Velo, "CENTER", 0, 0)
	f.Tinte = C:CreateTexture(nil, "BACKGROUND", nil, -6)
	f.Tinte:SetTexture(NIEBLA)
	f.Tinte:SetBlendMode("ADD")
	-- La placa: una forma de esquinas cortadas (K.Forma/K.Borde del Kit) que
	-- cuelga de la banda, más el canto con luz arriba.
	f.PlacaAncla = C:CreateTexture(nil, "BACKGROUND", nil, -8)
	f.PlacaAncla:SetColorTexture(0, 0, 0, 0)
	f.Placa = K.Forma(f.PlacaAncla, K.CORTE.ventana, "BACKGROUND", -5, C)
	f.PlacaBorde = K.Borde(f.PlacaAncla, K.CORTE.ventana, "BORDER", C)
	f.Canto = C:CreateTexture(nil, "BORDER", nil, 7)
	f.Canto:SetColorTexture(1, 1, 1, 1)
	f.Canto:SetHeight(1)
	-- La cinta: el cuerpo de tela y sus dos puntas de pendón.
	f.CintaC = C:CreateTexture(nil, "BACKGROUND", nil, -4)
	f.CintaC:SetTexture(MEDIA .. "anuncio-cinta")
	f.CintaI = C:CreateTexture(nil, "BACKGROUND", nil, -4)
	f.CintaI:SetTexture(MEDIA .. "anuncio-cinta-punta")
	f.CintaD = C:CreateTexture(nil, "BACKGROUND", nil, -4)
	f.CintaD:SetTexture(MEDIA .. "anuncio-cinta-punta")
	f.CintaD:SetTexCoord(1, 0, 0, 1)
	f.CintaI:SetPoint("RIGHT", f.CintaC, "LEFT", 0, 0)
	f.CintaD:SetPoint("LEFT", f.CintaC, "RIGHT", 0, 0)
	-- La filigrana: un ornamento a cada lado del nombre.
	f.FiliI = C:CreateTexture(nil, "ARTWORK", nil, 1)
	f.FiliI:SetTexture(MEDIA .. "anuncio-filigrana")
	f.FiliD = C:CreateTexture(nil, "ARTWORK", nil, 1)
	f.FiliD:SetTexture(MEDIA .. "anuncio-filigrana")
	f.FiliD:SetTexCoord(1, 0, 0, 1)
	for _, t in ipairs({ f.CintaC, f.CintaI, f.CintaD, f.FiliI, f.FiliD, f.Canto }) do t:Hide() end
	f.Placa:Hide()
	f.PlacaBorde:Hide()

	f.Halo = C:CreateTexture(nil, "BACKGROUND", nil, 0)
	f.Halo:SetTexture(HALO)
	f.Halo:SetSize(130, 130)
	f.Halo:SetBlendMode("ADD")
	-- El medallón: disco, aro con muescas y el dibujo del tipo (o el lobo).
	f.Disco = C:CreateTexture(nil, "ARTWORK", nil, 2)
	f.Disco:SetTexture(DISCO)
	f.Aro = C:CreateTexture(nil, "ARTWORK", nil, 3)
	f.Aro:SetTexture(ARO)
	f.Lobo = C:CreateTexture(nil, "ARTWORK", nil, 4)
	f.Lobo:SetSize(32, 32)
	f.Disco:SetPoint("CENTER", f.Halo, "CENTER", 0, 0)
	f.Aro:SetPoint("CENTER", f.Halo, "CENTER", 0, 0)
	f.Lobo:SetPoint("CENTER", f.Halo, "CENTER", 0, 0)

	f.Sobre = K.Texto(C, "subtitulo", "acento")
	f.Sobre:SetJustifyH("CENTER")
	f.Titulo = K.Texto(C, K.TIPO and K.TIPO.cine and "cine" or "anuncio", "texto")
	f.Titulo:SetJustifyH("CENTER")
	f.Texto = K.Texto(C, "globoEnorme", "textoSuave")
	f.Texto:SetJustifyH("CENTER")
	f.Pista = K.Texto(C, "nota", "textoTenue")
	f.Pista:SetJustifyH("CENTER")
	for _, fs in ipairs({ f.Sobre, f.Titulo, f.Texto, f.Pista }) do
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	end

	-- Las líneas de luz: arriba (con el hueco del medallón) y abajo.
	f.RayaI = C:CreateTexture(nil, "ARTWORK", nil, 0)
	f.RayaD = C:CreateTexture(nil, "ARTWORK", nil, 0)
	f.LineaI = C:CreateTexture(nil, "ARTWORK", nil, 0)
	f.LineaD = C:CreateTexture(nil, "ARTWORK", nil, 0)
	for _, t in ipairs({ f.RayaI, f.RayaD, f.LineaI, f.LineaD }) do
		t:SetColorTexture(1, 1, 1, 1)
		t:SetHeight(2)
	end

	-- La luz que cruza el nombre y su reflejo en la línea de abajo.
	f.BrilloI = C:CreateTexture(nil, "OVERLAY")
	f.BrilloD = C:CreateTexture(nil, "OVERLAY")
	for _, t in ipairs({ f.BrilloI, f.BrilloD }) do
		t:SetTexture(LUZ)
		t:SetBlendMode("ADD")
		t:Hide()
	end
	-- La luz de color detrás del nombre (se abre del centro a los lados).
	f.BandaI = C:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.BandaD = C:CreateTexture(nil, "BACKGROUND", nil, 1)
	for _, t in ipairs({ f.BandaI, f.BandaD }) do
		t:SetColorTexture(1, 1, 1, 1)
		t:SetBlendMode("ADD")
		t:SetHeight(48)
		t:Hide()
	end
	f.Polvo = {}
	for i = 1, MAX_PARTICULAS do
		local t = C:CreateTexture(nil, "ARTWORK", nil, -1)
		t:SetTexture(HALO)
		t:SetBlendMode("ADD")
		t:SetSize(6, 6)
		t:Hide()
		f.Polvo[i] = t
	end

	-- 1.3.9 (105): la onda que se abre al entrar (desde el medallón), el
	-- emblema de tu bando detrás y su tira de madera o piedra en la línea de abajo.
	f.Onda = C:CreateTexture(nil, "BACKGROUND", nil, 2)
	f.Onda:SetTexture(HALO)
	f.Onda:SetBlendMode("ADD")
	f.Onda:Hide()
	f.Emblema = C:CreateTexture(nil, "BACKGROUND", nil, -2)
	f.Emblema:SetSize(100, 100)
	f.Emblema:Hide()
	if K.TiraBando then f.Tira = K.TiraBando(C, 3, "ARTWORK") end

	-- El marco que late (peligro): una línea más arriba y abajo y dos corchetes.
	f.Borde = {}
	for i = 1, 4 do
		local t = C:CreateTexture(nil, "ARTWORK", nil, 1)
		t:SetColorTexture(1, 1, 1, 1)
		t:Hide()
		f.Borde[i] = t
	end

	-- El anuncio se cierra con un clic en su contenido (medallón, nombre y
	-- línea: clic derecho siempre cierra; el izquierdo hace su acción si la
	-- tiene y cierra) o en su X. Solo ese bloque toma el ratón, nunca la franja.
	f.Toque = CreateFrame("Button", nil, C)
	f.Toque:SetPoint("TOP", C, "TOP", 0, 0)
	f.Toque:SetSize(200, 120)
	if f.Toque.RegisterForClicks then f.Toque:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
	f.Toque:SetScript("OnClick", function(_, boton) tocar(boton) end)
	f.X = K.BotonIcono(C, "ic-cerrar", function() cerrar() end, { tam = 18, icono = 10, ayuda = K.L and K.L["Cerrar"] or nil })
	f.X:SetFrameLevel(f.Toque:GetFrameLevel() + 2)
	-- 1.4.0 (Toxic: «la × queda flotando pegada al texto»): la × solo se ve al
	-- pasar el ratón por el anuncio; en el chico (los rincones) no hay ×.
	local function verX(si) if f and f.X then f.X:SetAlpha(si and 1 or 0) end end
	f.Toque:SetScript("OnEnter", function() verX(true) end)
	f.Toque:SetScript("OnLeave", function() verX(f.X.IsMouseOver and f.X:IsMouseOver() or false) end)
	if f.X.HookScript then
		f.X:HookScript("OnEnter", function() verX(true) end)
		f.X:HookScript("OnLeave", function() verX(f.Toque.IsMouseOver and f.Toque:IsMouseOver() or false) end)
	end
	verX(false)
	raton()

	f:SetScript("OnHide", function(self)
		if self.Huellas then self.Huellas:Hide() end
		actual = nil
		programar(0.05)
		if K.RecolocarAvisos then K.RecolocarAvisos() end
	end)

	f:SetScript("OnUpdate", function(self, dt)
		dt = tonumber(dt) or 0
		local t = (self.alfaT or 0) + dt
		self.alfaT = t
		local o = self.alfaO
		if not o then self:Hide() return end
		local est = estiloDe(o)
		local dura = self.alfaDura or 6
		local entra, sale = self.alfaEntra, self.alfaSaleNormal
		-- Algo pide la pantalla (el juego, una pelea, la placa de llegada) o
		-- ya no vale: se va rápido y, si aún vale, vuelve después.
		if not self.alfaSaliendo and t < dura then
			local razon
			if not o.ya and juegoOcupado(o.tapaJuego) then razon = "juego"
			elseif enCombate() and not o.enCombate then razon = "combate"
			else
				self.alfaMirar = (self.alfaMirar or 0) - dt
				if self.alfaMirar <= 0 then
					self.alfaMirar = 0.5
					if not vigente(o, true) then razon = "vencido"
					elseif prioridad(o) >= 3 and not self.alfaBajoPlaca and placaEstorba() then razon = "placa" end
				end
			end
			if razon then
				self.alfaSaliendo = true
				if razon ~= "vencido" then reencolar(self, t) end
				self.alfaSale = SALE_RAPIDO
				self.alfaFin = t
				raton()
			end
		end
		local salida = self.alfaSale or sale
		local fin = self.alfaFin or dura
		local a
		if t < entra and not self.alfaSaliendo then a = t / entra
		elseif t < fin then a = 1
		elseif t < fin + salida then a = (self.alfaDesde or 1) * (1 - (t - fin) / salida)
		else self:Hide() return end
		if not self.alfaSaliendo or t <= fin then self.alfaDesde = a end
		self:SetAlpha(a)
		-- Su animación (quieto: solo el fundido).
		local e = min(1, t / entra)
		local dx, dy = 0, 0
		local fn = not self.alfaLigero and ANIM[est.anim] or nil
		if fn then dx, dy = fn(self, t, e, entra) end
		-- La salida: sube un poco mientras el telón se cierra.
		local fuera = (t > fin and salida > 0) and min(1, (t - fin) / salida) or nil
		if fuera and not self.alfaLigero then dy = (dy or 0) + 12 * suave(fuera) end
		dx, dy = floor((dx or 0) + 0.5), floor((dy or 0) + 0.5)
		if dx ~= self.alfaDX or dy ~= self.alfaDY then
			self.alfaDX, self.alfaDY = dx, dy
			self.C:ClearAllPoints()
			self.C:SetPoint("TOPLEFT", self, "TOPLEFT", dx, dy)
			self.C:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", dx, dy)
		end
		-- El telón se abre (y se cierra al salir) y las líneas se dibujan.
		if not self.alfaLigero then
			local k = suave(t / (entra * 0.9))
			if fuera then k = k * (1 - 0.85 * suave(fuera)) end
			telon(self, k)
			local r = min(1, max(0, (t - 0.12) / (est.anim == "baja" and 1.0 or 0.65)))
			if fuera then r = r * (1 - suave(fuera)) end
			lineas(self, suave(r))
			cine(self, t, a, fuera)
		end
		-- La cuenta, al segundo.
		local c = self.alfaCuenta
		if c then
			local queda = (c.hasta or 0) - ahora()
			local s = max(0, floor(queda + 0.5))
			if s ~= self.alfaSeg then
				self.alfaSeg = s
				K.Escribir(self.Texto, queda > 0 and format(c.formato, mmss(queda)) or (c.final or ""))
			end
		end
	end)

	K.Pintar(f, pintar)
end

-- Dónde sale: centrado en su ancla (relativa a la pantalla). Si la placa de
-- la flecha estorba ahí, baja o sube lo justo, sin dejar el centro.
local function colocar()
	K.AnclaAnuncio()
	colocarAncla()
	f:ClearAllPoints()
	f:SetPoint("CENTER", ancla, "CENTER", 0, 0)
	local dy, estorba = desvioPlaca(f:GetHeight(), f.alfaContenidoW)
	f.alfaBajoPlaca = (estorba and dy ~= 0) or false
	if dy ~= 0 then
		f:ClearAllPoints()
		f:SetPoint("CENTER", ancla, "CENTER", 0, dy)
	end
end

local function sonar(o, est)
	if o.vuelve then return end
	local s = o.sonido
	if s == nil then s = est.sonido end
	if not s then return end
	local Sp = rawget(N, "SonidoPermitido")
	if type(Sp) == "function" then
		local ok, si = pcall(Sp, prioridad(o))
		if ok and not si then return end
	end
	if type(s) == "function" then K.Llamar(s) return end
	local A = N.A
	if A and A.Get and A.Get("anuncios.sonido") == false then return end
	if A and A.Hidden and A.Hidden() then return end
	if type(s) == "string" then
		local id = type(SOUNDKIT) == "table" and rawget(SOUNDKIT, s)
		if type(id) == "number" and PlaySound then pcall(PlaySound, id, "SFX") end
	elseif type(s) == "number" and PlaySoundFile then
		pcall(PlaySoundFile, s, "SFX") -- 1.3.9 (70): el mismo canal que los demás sonidos de Alfa
	end
end

-- 1.4.0: las piezas del fondo elegido (placa, cinta o filigrana).
pintarFondo = function(x, modo, chico, tw, tocaW, util)
	local o = x.alfaO
	local token = tono(o, estiloDe(o))
	local r, g, b = K.Color(token)
	-- La placa: del ancho de lo que dice, del alto de la banda.
	local esPlaca = modo == "placa"
	x.Placa:SetShown(esPlaca)
	x.PlacaBorde:SetShown(esPlaca)
	x.Canto:SetShown(esPlaca)
	if esPlaca then
		x.PlacaAncla:ClearAllPoints()
		x.PlacaAncla:SetPoint("TOP", x.Velo, "TOP", 0, 0)
		x.PlacaAncla:SetPoint("BOTTOM", x.Velo, "BOTTOM", 0, 0)
		x.PlacaAncla:SetWidth(min(util + 20, tocaW + (chico and 28 or 48)))
		x.Placa:RGBA(0.035, 0.045, 0.06, 0.82)
		x.PlacaBorde:Color(token, 0.8)
		x.Canto:ClearAllPoints()
		x.Canto:SetPoint("TOPLEFT", x.PlacaAncla, "TOPLEFT", K.CORTE.ventana + 2, -1)
		x.Canto:SetPoint("TOPRIGHT", x.PlacaAncla, "TOPRIGHT", -(K.CORTE.ventana + 2), -1)
		if CreateColor and x.Canto.SetGradient then
			x.Canto:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0.05), CreateColor(1, 1, 1, 0.35))
		end
	end
	-- La cinta: detrás del nombre, de su color pero más oscura.
	local esCinta = modo == "cinta"
	for _, t in ipairs({ x.CintaC, x.CintaI, x.CintaD }) do t:SetShown(esCinta) end
	if esCinta then
		local h = alto(x.Titulo) + (chico and 10 or 16)
		x.alfaCintaW = min(util - 40, tw + (chico and 30 or 44))
		x.CintaC:ClearAllPoints()
		x.CintaC:SetPoint("CENTER", x.Titulo, "CENTER", 0, -1)
		x.CintaC:SetSize(x.alfaLigero and x.alfaCintaW or 1, h)
		x.CintaI:SetSize(floor(h * 0.6 + 0.5), h)
		x.CintaD:SetSize(floor(h * 0.6 + 0.5), h)
		local k = 0.62
		for _, t in ipairs({ x.CintaC, x.CintaI, x.CintaD }) do t:SetVertexColor(r * k, g * k, b * k, 0.97) end
	end
	-- La filigrana: un ornamento a cada lado del nombre.
	local esFili = modo == "filigrana"
	x.FiliI:SetShown(esFili)
	x.FiliD:SetShown(esFili)
	if esFili then
		x.alfaFiliW = max(40, min(chico and 120 or 210, floor((util - tw) / 2) - 16))
		local h = chico and 22 or 32
		x.FiliI:ClearAllPoints()
		x.FiliI:SetPoint("RIGHT", x.Titulo, "CENTER", -(tw / 2 + 12), 0)
		x.FiliD:ClearAllPoints()
		x.FiliD:SetPoint("LEFT", x.Titulo, "CENTER", tw / 2 + 12, 0)
		for _, t in ipairs({ x.FiliI, x.FiliD }) do
			t:SetSize(x.alfaLigero and x.alfaFiliW or 1, h)
			t:SetVertexColor(r, g, b, 0.95)
		end
		if x.alfaLigero then x.FiliI:SetTexCoord(0, 1, 0, 1) x.FiliD:SetTexCoord(1, 0, 0, 1) end
	end
end

-- El dibujo del medallón: el del tipo; un ícono pedido; o el lobo.
local function dibujo(o, est)
	if o.icono then return K.Ruta(o.icono), 30, nil end
	if est.glifo then return MEDIA .. "anuncio-" .. est.glifo, 32, est.glifo end
	if est.icono then return K.Ruta(est.icono), 30, nil end
	return K.Lobo(o.lobo or est.lobo or "aullando"), 44, "lobo"
end

mostrar = function(o)
	local A = N.A
	if A and A.Hidden and A.Hidden() then return false end
	if not f then armar() end
	local est = estiloDe(o)
	local chico = o.chico
	if chico == nil then
		chico = est.chico or false
		if o.estilo == "subzona" and A and A.Get and A.Get("anuncios.subzonaChica") == false then chico = false end
	end
	f.alfaO = o
	actual = o
	ultimoInicio = ahora()
	f.alfaSaliendo, f.alfaSale, f.alfaFin, f.alfaDesde, f.alfaMirar = nil, nil, nil, nil, nil
	f.alfaDX, f.alfaDY, f.alfaRayaW, f.alfaPasos, f.alfaVeloH, f.alfaMedW = nil, nil, nil, nil, nil, nil
	f.alfaChico = chico
	f.alfaLigero = quieto()
	f.alfaEntra = tonumber(o.entra) or est.entra or 0.55
	f.alfaSaleNormal = est.sale or 1.0

	local ancho = anchoPantalla()
	f:SetWidth(ancho)
	local util = ancho - 40
	for _, fs in ipairs({ f.Sobre, f.Texto, f.Pista }) do fs:SetWidth(util) end

	-- El medallón.
	local ruta, tam, glifo = dibujo(o, est)
	f.Lobo:SetTexture(ruta)
	f.alfaLoboTam = tam
	f.alfaGlifo = glifo
	f.Lobo:SetSize(tam, tam)
	if f.Lobo.SetRotation then f.Lobo:SetRotation(0) end
	if f.Halo.SetRotation then f.Halo:SetRotation(0) end
	if f.Aro.SetRotation then f.Aro:SetRotation(0) end
	f.Halo:SetSize(130, 130)
	f.Halo:SetAlpha(0.3)
	for _, t in ipairs({ f.Lobo, f.Halo, f.Disco, f.Aro }) do t:SetShown(not chico) end
	medallon(f, 1, 0)

	-- Los textos: el tipo arriba, el nombre grande, la línea útil y la pista.
	K.Escribir(f.Sobre, o.sobre and K.Mayus(o.sobre) or "")
	-- 1.4.0: un escalón más grandes que antes, para leerse a 1920×1080.
	f.Sobre.alfaRol = chico and "encabezado" or "subtitulo"
	K.Fuente(f.Sobre)
	f.Sobre:SetWordWrap(false)
	if K.AnchoTexto(f.Sobre) > util then
		f.Sobre:SetWordWrap(true)
		if f.Sobre.SetMaxLines then f.Sobre:SetMaxLines(2) end
	end
	f.Texto.alfaRol = chico and "globoGrande" or "globoEnorme"
	K.Fuente(f.Texto)
	f.Texto:SetWordWrap(true)
	if f.Texto.SetMaxLines then f.Texto:SetMaxLines(3) end
	-- Con una cuenta, el texto empieza ya con lo que falta (no en blanco).
	local texto = o.texto or ""
	if o.cuenta and o.cuenta.formato then
		local queda = (o.cuenta.hasta or 0) - ahora()
		texto = queda > 0 and format(o.cuenta.formato, mmss(queda)) or (o.cuenta.final or "")
	end
	K.Escribir(f.Texto, texto)
	f.Pista:SetWordWrap(true)
	if f.Pista.SetMaxLines then f.Pista:SetMaxLines(2) end
	K.Escribir(f.Pista, o.alClic and o.pista or "")
	local tw = ajustarTitulo(f.Titulo, o.titulo, util - 20, chico)
	-- 1.4.0: el fondo (una niebla suave o ninguno) y cómo se realza el texto
	-- para leerse sobre nieve, desierto, bosque o una cueva: siempre una sombra
	-- (K.Fuente la quita en el diseño de Alfa) y, sin fondo, un contorno fino.
	local modo = fondoAnuncio()
	f.alfaFondo = modo
	f.alfaNiebla = FONDOS[modo].niebla
	f.alfaAura = FONDOS[modo].aura
	for _, fs in ipairs({ f.Sobre, f.Titulo, f.Texto, f.Pista }) do
		local ruta, tam = fs:GetFont()
		if ruta and tam then pcall(fs.SetFont, fs, ruta, tam, FONDOS[modo].contorno and "OUTLINE" or "") end
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, FONDOS[modo].contorno and 1 or 0.9)
	end

	-- El acomodo, de arriba abajo (y desde ahí, el alto del telón).
	local hayTexto = texto ~= ""
	local hayPista = (f.Pista:GetText() or "") ~= ""
	local haySobre = (f.Sobre:GetText() or "") ~= ""
	local bandaTop = chico and 2 or floor(MED / 2) + 2
	local y = chico and (bandaTop + 10) or (bandaTop + floor(MED / 2) + 10)
	f.Halo:ClearAllPoints()
	f.Halo:SetPoint("CENTER", f.C, "TOP", 0, -bandaTop)
	f.Sobre:ClearAllPoints()
	if haySobre then
		f.Sobre:SetPoint("TOP", f.C, "TOP", 0, -y)
		y = y + alto(f.Sobre) + (chico and 2 or 5)
	end
	local aireCinta = (modo == "cinta") and (chico and 4 or 7) or 0
	y = y + aireCinta
	f.Titulo:ClearAllPoints()
	f.Titulo:SetPoint("TOP", f.C, "TOP", 0, -y)
	y = y + alto(f.Titulo) + aireCinta
	f.Texto:ClearAllPoints()
	f.Texto:SetPoint("TOP", f.Titulo, "BOTTOM", 0, (chico and -3 or -8) - aireCinta)
	if hayTexto then y = y + (chico and 3 or 8) + alto(f.Texto) end
	f.Pista:ClearAllPoints()
	f.Pista:SetPoint("TOP", f.Texto, "BOTTOM", 0, -5)
	if hayPista then y = y + 5 + alto(f.Pista) end

	-- Las huellas (descubrir: se dibujan bajo la línea; manada: cruzan la de abajo).
	if est.huellas and not chico and not f.alfaLigero then
		if not f.Huellas then f.Huellas = K.Huellas(f.C, { tam = 14, max = 8, total = 6, actual = 0 }) end
		f.Huellas:ClearAllPoints()
		if est.anim == "destello" then
			f.Huellas:Set(0, 6)
			f.Huellas:SetPoint("TOP", hayPista and f.Pista or (hayTexto and f.Texto or f.Titulo), "BOTTOM", 0, -6)
			y = y + 6 + floor(14 * 1.4)
		else
			f.Huellas:Set(5, 5)
		end
		f.Huellas:Show()
	elseif f.Huellas then
		f.Huellas:Hide()
	end

	local bandaH = (y + (chico and 9 or 16)) - bandaTop
	f.alfaBandaH = bandaH
	f.alfaCentroY = -(bandaTop + bandaH / 2)
	f:SetHeight(bandaTop + bandaH + 4)
	f.C:ClearAllPoints()
	f.C:SetAllPoints(f)

	-- El telón y sus líneas.
	f.Velo:ClearAllPoints()
	f.Velo:SetPoint("CENTER", f.C, "TOP", 0, f.alfaCentroY)
	f.Velo:SetWidth(ancho + 240)
	telon(f, f.alfaLigero and 1 or 0.04)
	local hueco = chico and 0 or floor(MED / 2) + 6
	f.alfaHueco = hueco
	f.alfaLineaW = floor(ancho / 2 + 40 - hueco)
	f.RayaI:ClearAllPoints()
	f.RayaI:SetPoint("RIGHT", f.Velo, "TOP", -hueco, 0)
	f.RayaD:ClearAllPoints()
	f.RayaD:SetPoint("LEFT", f.Velo, "TOP", hueco, 0)
	f.LineaI:ClearAllPoints()
	f.LineaI:SetPoint("RIGHT", f.Velo, "BOTTOM", 0, 0)
	f.LineaD:ClearAllPoints()
	f.LineaD:SetPoint("LEFT", f.Velo, "BOTTOM", 0, 0)
	for _, t in ipairs({ f.RayaI, f.RayaD, f.LineaI, f.LineaD }) do t:SetAlpha(1) t:Show() end
	lineas(f, f.alfaLigero and 1 or 0)
	if est.huellas and not chico and est.anim ~= "destello" and f.Huellas and f.Huellas:IsShown() then
		f.Huellas:SetPoint("LEFT", f.Velo, "BOTTOM", -ancho / 2, 2)
	end

	-- Las dos líneas que laten (peligro): dentro del telón.
	local conBorde = est.anim == "late" and not f.alfaLigero
	for _, b in ipairs(f.Borde) do b:ClearAllPoints() b:SetShown(conBorde) end
	if conBorde then
		local bw = min(util, max(tw, K.AnchoTexto(f.Texto), K.AnchoTexto(f.Pista)) + 70)
		local B = f.Borde
		-- (por dentro del telón: el medallón tapa la de arriba en su centro)
		B[1]:SetPoint("TOP", f.Velo, "TOP", 0, -6) B[1]:SetSize(bw, 1)
		B[2]:SetPoint("BOTTOM", f.Velo, "BOTTOM", 0, 6) B[2]:SetSize(bw, 1)
		-- (1.4.0: sin los lados: nada de rectángulos, solo dos líneas que laten)
		B[3]:Hide()
		B[4]:Hide()
	end

	-- Lo que se toca: solo el bloque del contenido (su ancho, no la franja).
	local abajo = f.Titulo
	if hayTexto or o.cuenta then abajo = f.Texto end
	if hayPista then abajo = f.Pista end
	local tocaW = max(tw, K.AnchoTexto(f.Texto), K.AnchoTexto(f.Sobre), K.AnchoTexto(f.Pista), chico and 0 or MED)
	tocaW = min(util, tocaW + 36)
	f.alfaContenidoW = tocaW
	f.Toque:ClearAllPoints()
	f.Toque:SetPoint("TOP", f.C, "TOP", 0, chico and 0 or -2)
	f.Toque:SetPoint("BOTTOM", abajo, "BOTTOM", 0, -4)
	f.Toque:SetWidth(tocaW)
	-- La niebla, del ancho de lo que dice (no de la franja entera) y el aura en el nombre.
	f.Niebla:SetWidth(floor(min(ancho + 200, max(chico and 380 or 620, tocaW + (chico and 260 or 420)))))
	f.Niebla:SetShown(f.alfaNiebla > 0)
	f.Tinte:ClearAllPoints()
	f.Tinte:SetPoint("CENTER", f.Titulo, "CENTER", 0, -1)
	f.Tinte:SetShown(not chico)
	f.X:ClearAllPoints()
	f.X:SetPoint("BOTTOMLEFT", f.Toque, "TOPRIGHT", -4, -(bandaTop + 2))
	f.X:SetShown(not chico)
	f.X:SetAlpha(0)
	-- Las líneas según el fondo; en el chico (los rincones) nunca (Toxic: «se
	-- ve como una barra pegada sobre el juego»).
	local lin = FONDOS[modo].lineas
	if chico or lin == nil then
		for _, t in ipairs({ f.RayaI, f.RayaD, f.LineaI, f.LineaD }) do t:Hide() end
	elseif lin == "arriba" then
		f.LineaI:Hide()
		f.LineaD:Hide()
	end
	pintarFondo(f, modo, chico, tw, tocaW, util)
	colocar()
	f.alfaClic = o.alClic
	f.alfaCuenta = o.cuenta
	f.alfaSeg = nil
	f.alfaDura = tonumber(o.segundos) or est.segundos or 6
	f.alfaT = 0
	-- En combate ni el contenido ni la X toman el ratón.
	raton()
	pintar(f)
	prepararCine(f, o, est, chico, tw)
	-- 1.3.9: el tema de tu bando (emblema detrás del medallón y su tira en la
	-- línea de abajo) y la onda de entrada.
	local tema = K.Bando and K.Bando() or nil
	f.alfaTema = (not chico) and tema or nil
	f.alfaAnim = est.anim
	local r, g, b = K.Color(tono(o, est))
	f.Onda:ClearAllPoints()
	f.Onda:SetPoint("CENTER", f.Halo, "CENTER", 0, 0)
	f.Onda:SetVertexColor(r, g, b, 1)
	f.Onda:SetShown(f.alfaConBrillo and not chico)
	f.Onda:SetAlpha(0)
	f.Emblema:ClearAllPoints()
	f.Emblema:SetPoint("CENTER", f.Halo, "CENTER", 0, 0)
	if f.alfaTema then
		f.Emblema:SetTexture(tema.emblema)
		f.Emblema:SetVertexColor(1, 1, 1, 1)
		f.Emblema:SetAlpha(f.alfaLigero and 0.3 or 0)
		f.Emblema:SetSize(100, 100)
		f.Emblema:Show()
	else
		f.Emblema:Hide()
	end
	if f.Tira then
		f.Tira:ClearAllPoints()
		f.Tira:SetPoint("TOP", f.Velo, "BOTTOM", 0, 1)
		f.Tira:SetWidth(1)
		if not (f.alfaTema and f.Tira:Pintar(tema)) then f.Tira:Hide() end
		if f.Tira:IsShown() then
			-- La tira acompaña a la línea de abajo, que queda casi sin luz.
			f.LineaI:SetAlpha(0.25)
			f.LineaD:SetAlpha(0.25)
			f.Tira:SetWidth(max(1, (f.alfaLigero and 1 or 0) * (f.alfaLineaW + hueco) * 2))
		end
	end
	f:SetAlpha(0)
	f:Show()
	sonar(o, est)
	-- 1.3.8: lo que dijo queda anotado (nadie más lo repite) y los avisos chicos
	-- se acomodan debajo.
	if not o.vuelve and N.Visto and not (N.Secreto and (N.Secreto(o.titulo) or N.Secreto(o.texto))) then
		N.Visto(o.titulo, "anuncio")
		if type(o.texto) == "string" and o.texto ~= "" then N.Visto(o.titulo .. " " .. o.texto, "anuncio") end
	end
	if K.RecolocarAvisos then K.RecolocarAvisos() end
	-- Quien lo pidió se entera de que salió de verdad (Zonas.lua esconde ahí el nombre del juego).
	if type(o.alMostrar) == "function" then K.Llamar(o.alMostrar, o) end
	return true
end

function K.Anuncio(o)
	if type(o) ~= "table" or type(o.titulo) ~= "string" then return false end
	local A = N.A
	if A and A.Hidden and A.Hidden() then avisarPerdido(o) return false end
	local est = estiloDe(o)
	if o.caduca == nil and est.caduca then o.caduca = ahora() + est.caduca end
	if o.espaciar == nil and est.espaciar then o.espaciar = est.espaciar end
	if not vigente(o) then avisarPerdido(o) return false end
	-- 1.3.8: un mensaje por suceso. Lo que otro canal acaba de decir (un aviso,
	-- Lya) no sale además en grande; o.suceso: el primero que lo cuenta gana.
	local Sec = rawget(N, "Secreto")
	if o.clave ~= "probar" and not (type(Sec) == "function" and (Sec(o.titulo) or Sec(o.texto))) then
		local Su = rawget(N, "Suceso")
		if o.suceso ~= nil and type(Su) == "function" and not Su(o.suceso, o.ventana) then avisarPerdido(o) return true end
		local Ya = rawget(N, "YaSeVio")
		if type(Ya) == "function" and Ya(o.titulo .. ((type(o.texto) == "string" and o.texto ~= "") and (" " .. o.texto) or ""), nil, "anuncio") then
			avisarPerdido(o)
			return true
		end
	end
	local e = { o = o, desde = ahora(), n = 0 }
	if f and f:IsShown() and actual then
		-- Lo mismo que ya se ve no se repite.
		if o.clave and actual.clave == o.clave and actual.titulo == o.titulo then return true end
		-- Uno más urgente: el que se ve vuelve después.
		if prioridad(o) < prioridad(actual) and not bloqueo(e) then
			reencolar(f, f.alfaT)
			return mostrar(o)
		end
		encolar(o)
		return true
	end
	if bloqueo(e) or #cola > 0 then
		encolar(o)
		if #cola > 0 and not (f and f:IsShown()) then revisar() end
		return true
	end
	return mostrar(o)
end

function K.QuitarAnuncio()
	for _, e in ipairs(cola) do perdidoAnuncio(e.o) end
	cola = {}
	if f then f.alfaO = nil f:Hide() end
	if fc then fc:Hide() end
end
function K.CerrarAnuncio() cerrar() end
-- 1.3.7: quita solo ese anuncio (el que se ve o el que espera), no los demás.
function K.QuitarEsteAnuncio(o)
	if type(o) ~= "table" then return false end
	local hubo = false
	for i = #cola, 1, -1 do if cola[i].o == o then table.remove(cola, i) hubo = true end end
	if f and f:IsShown() and f.alfaO == o then cerrar() hubo = true end
	return hubo
end
function K.AnuncioEsperando() return #cola > 0 end
function K.AnuncioCola()
	local out = {}
	for i, e in ipairs(cola) do out[i] = { estilo = e.o.estilo or "general", titulo = e.o.titulo, prioridad = prioridad(e.o) } end
	return out
end
function K.AnuncioActual()
	if not (f and f:IsShown() and f.alfaO) then return nil end
	local o = f.alfaO
	local est = estiloDe(o)
	return {
		estilo = o.estilo or "general", titulo = o.titulo, sobre = o.sobre, texto = o.texto, chico = f.alfaChico,
		prioridad = prioridad(o), color = tono(o, est), anim = est.anim, bajoPlaca = f.alfaBajoPlaca or nil,
		ancho = f:GetWidth(), toca = f.Toque:IsMouseEnabled() or nil, marcoToca = f:IsMouseEnabled() or nil,
		x = f.X:IsMouseEnabled() or nil, tocaAncho = f.Toque:GetWidth(),
		huellas = f.Huellas ~= nil and f.Huellas:IsShown() or nil, borde = f.Borde[1]:IsShown() or nil,
		rolTitulo = f.Titulo.alfaRol, vuelve = o.vuelve or nil,
		bando = f.alfaTema and f.alfaTema.clave or nil, -- 1.3.9
		emblema = f.Emblema:IsShown() or nil, tira = f.Tira ~= nil and f.Tira:IsShown() or nil,
		glifo = f.alfaGlifo, quieto = f.alfaLigero or nil, -- 1.4.0
	}
end

---------------------------------------------------------------------------
-- El ícono chico (1.3.7): un raro en plena pelea o en una mazmorra. Nunca
-- toma el ratón; se va solo. 1.4.0: con su propio velo, en el ancla.
---------------------------------------------------------------------------
local function armarChico()
	fc = CreateFrame("Frame", "AlfaAnuncioChico", K.Raiz())
	fc:SetSize(220, 30)
	fc:SetFrameStrata("HIGH")
	fc:EnableMouse(false)
	fc:Hide()
	fc.Velo = fc:CreateTexture(nil, "BACKGROUND")
	fc.Velo:SetTexture(NIEBLA)
	fc.Velo:SetVertexColor(0.02, 0.025, 0.035, 1)
	fc.Velo:SetAlpha(0.55)
	fc.Velo:SetPoint("TOPLEFT", fc, "TOPLEFT", -70, 16)
	fc.Velo:SetPoint("BOTTOMRIGHT", fc, "BOTTOMRIGHT", 70, -16)
	fc.Icono = fc:CreateTexture(nil, "ARTWORK")
	fc.Icono:SetSize(24, 24)
	fc.Icono:SetPoint("LEFT", fc, "LEFT", 0, 0)
	fc.Texto = K.Texto(fc, "pequeno", "texto")
	fc.Texto:SetPoint("LEFT", fc.Icono, "RIGHT", 6, 0)
	fc.Texto:SetShadowOffset(1, -1)
	fc.Texto:SetShadowColor(0, 0, 0, 0.9)
	fc:SetScript("OnUpdate", function(self, dt)
		local t = (self.alfaT or 0) + (tonumber(dt) or 0)
		self.alfaT = t
		local dura = self.alfaDura or 6
		local a
		if t < 0.3 then a = t / 0.3 elseif t < dura then a = 1 elseif t < dura + 0.6 then a = 1 - (t - dura) / 0.6 else self:Hide() return end
		self:SetAlpha(a)
	end)
end

function K.AnuncioChico(o)
	if type(o) ~= "table" or type(o.titulo) ~= "string" then return false end
	local A = N.A
	if A and A.Hidden and A.Hidden() then return false end
	if not fc then armarChico() end
	K.AnclaAnuncio()
	colocarAncla()
	fc:ClearAllPoints()
	fc:SetPoint("CENTER", ancla, "CENTER", 0, 40)
	local token = o.color or (K.Clasico() and "oro" or "acento")
	if o.icono then fc.Icono:SetTexture(K.Ruta(o.icono)) else fc.Icono:SetTexture(K.Lobo(o.lobo or "atento")) end
	fc.Icono:SetVertexColor(K.Color(token))
	K.Escribir(fc.Texto, o.titulo)
	local w = min(anchoPantalla() - 40, K.AnchoTexto(fc.Texto))
	fc.Texto:SetWidth(max(1, w + 2))
	fc:SetWidth(24 + 6 + w + 2)
	fc.alfaDura = tonumber(o.segundos) or 6
	fc.alfaT = 0
	fc:SetAlpha(0)
	fc:Show()
	return true
end
function K.AnuncioChicoVisible() return fc ~= nil and fc:IsShown() or false end

-- En combate deja pasar los clics (no atrapa nada), y al terminar vuelve lo que esperaba.
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
ev:RegisterEvent("UI_SCALE_CHANGED")
ev:SetScript("OnEvent", function(_, evento)
	if evento == "PLAYER_REGEN_DISABLED" then
		pelea = true
		raton()
	elseif evento == "PLAYER_REGEN_ENABLED" then
		pelea = false
		raton()
		if #cola > 0 then programar(1) end
	elseif evento == "PLAYER_LOGIN" then
		-- 1.4.0 (78): el anuncio se acomoda con los demás en «Acomodar» (Kit/Movible.lua).
		local an = K.AnclaAnuncio()
		colocarAncla()
		if type(K.Movible) == "function" and not an.alfaMovible then
			an.alfaMovible = true
			local L = K.L or {}
			pcall(K.Movible, an, "anuncio", {
				nombre = L["Los anuncios"],
				muestra = L["Así se verá un anuncio"],
				guardar = function(_, pos) if type(pos) == "table" then K.MoverAnuncio(pos.cx, pos.cy) end end,
				-- 1.4.0: el anuncio es hijo de la raíz, no del ancla: sin esto
				-- nunca contaba «a la vista» y Mayús+arrastre no lo movía. Con
				-- Mayús toma el ratón su bloque (f.Toque), y el clic no lo cierra.
				vista = function()
					local a = rawget(_G, "AlfaAnuncio")
					return a and a:IsShown() and not a.alfaSaliendo and a or nil
				end,
				asa = function()
					local a = rawget(_G, "AlfaAnuncio")
					return a and a:IsShown() and not a.alfaSaliendo and a.Toque or nil
				end,
				volver = function() K.AnclaAnuncioVolver() end,
			})
		end
	else
		-- La pantalla cambió de tamaño (o de escala): el ancla vuelve a su lugar.
		colocarAncla()
	end
end)
