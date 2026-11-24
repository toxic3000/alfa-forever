-- Alfa - Kit: el anuncio animado (1.2.7; estilos y turnos, 1.3.7). toxic3000 / La Jauría. GPL-3.0.
--
-- Un anuncio grande y limpio arriba del centro, con el estilo de la intro de
-- Alfa: el lobo (o el ícono del tipo) con su halo, una línea pequeña arriba
-- («LA MANADA VIAJA»), el nombre en grande con dos rayas de luz que se abren
-- a los lados, y una línea abajo con lo demás. Entra con su animación, se
-- queda unos segundos y se desvanece solo.
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
--   K.ESTILOS_ANUNCIO            los estilos: color, ícono, sonido, duración y animación
--
-- Los estilos (1.3.7, pedido de Toxic: una animación distinta para cada tipo):
--   general   sube un poco y aparece (el de siempre)
--   zona      baja con fundido y rayas largas, con el color de quién es la zona
--   subzona   fundido corto y pequeño
--   descubrir destello dorado y huellas que se dibujan
--   barco     se desliza y ondea          zepelin  baja flotando con balanceo
--   tranvia   entra de lado y frena seco  raro     salta con rebote
--   tesoro    brillo que gira             mazmorra sube desde abajo, morado
--   ciudad    fundido lento y azul        peligro  el borde late en rojo
--   llegada   el lobo aúlla               manada   huellas que cruzan
-- Todo con un OnUpdate ligero que solo corre mientras se ve (al terminar el
-- marco se oculta y deja de correr). En modo ligero, solo el fundido.
-- 1.3.8: más cine para todos (cine/prepararCine: profundidad, la luz que
-- cruza el nombre, polvo o chispas por tipo con K.PARTICULAS_ANUNCIO, salida
-- que sube), un sonido distinto por tipo, un mensaje por suceso (o.suceso,
-- N.YaSeVio: lo que otro canal acaba de decir no sale en grande) y los
-- avisos chicos se acomodan debajo (K.RecolocarAvisos).
--
-- Los turnos (1.3.7):
--   * Una cola por prioridad (1 urgente: el barco que llega; 2: un raro, un
--     descubrimiento; 3: una zona; 4: una subzona). Uno no pisa a otro: el
--     más urgente sale primero y un anuncio menos urgente espera su turno; si
--     llega uno más urgente mientras se ve otro, el que se veía se va y vuelve
--     después con el tiempo que le quedaba.
--   * Lo vencido caduca (`caduca`, `vigente`): un barco que ya zarpó o un raro
--     que ya no está no se anuncian tarde.
--   * El sonido suena cuando el anuncio de verdad aparece (y no otra vez al volver).
--   * Solo el título toma el ratón (clic: su acción; clic derecho: lo cierra);
--     nunca en combate. El resto de la franja deja pasar los clics.
--   * Si empieza una pelea, se desvanece rápido y vuelve al terminar si aún vale.
--   * Lo que Alfa pide aguantar (N.Ocupado, Momentos.lua) detiene lo que no es urgente.
--   * La placa de llegada de la flecha: una zona o subzona espera a que se
--     vaya (unos segundos) y, si se queda, sale debajo de ella, nunca encima.
--   * Mide lo que la pantalla deja (hasta 720 px): con la interfaz grande o en
--     4:3 se angosta, y un nombre largo baja de tamaño antes de cortarse.
--
-- El turno con el juego (1.3.1): arriba del centro el juego escribe el nombre
-- de la zona al llegar (ZoneTextFrame / SubZoneTextFrame) y saca sus
-- estandartes (jefes, subir de nivel, avisos de evento). Un anuncio de Alfa
-- nunca se cruza con ellos: si están a la vista, espera a que se vayan (como
-- mucho ESPERA_MAX s) y sale después; y si el juego saca uno mientras el de
-- Alfa se ve, el de Alfa se va rápido y vuelve en cuanto el juego termina.

local _, N = ...
local K = N.Kit

local floor, max, min, format, sin, cos, abs, exp = math.floor, math.max, math.min, string.format, math.sin, math.cos, math.abs, math.exp
local type, pairs, ipairs, pcall, tonumber, tostring, rawget = type, pairs, ipairs, pcall, tonumber, tostring, rawget
local tremove, tsort = table.remove, table.sort

local HALO = "Interface\\AddOns\\Alfa_Bienvenida\\Media\\intro-halo"
local SALE_RAPIDO = 0.35
local ESPERA_MAX = 10   -- s: si el juego no suelta la pantalla, sale igual
local ESPERA_PLACA = 4  -- s: una zona espera a la placa de llegada; después, debajo de ella
local MIRAR = 0.4       -- s entre una mirada y otra mientras hay cola
local TOPE_COLA = 6
local ANCHO_MAX, ANCHO_MIN = 720, 380
local f, fc

---------------------------------------------------------------------------
-- Los estilos
---------------------------------------------------------------------------
-- color: token del Kit (nil: el acento, oro en Clásico); tituloColor: el
-- nombre también va de ese color; caduca: s que puede esperar en la cola.
local ESTILOS = {
	general = { prioridad = 2, lobo = "aullando", segundos = 6, entra = 0.55, sale = 1.0, anim = "sube", raya = 170 },
	zona = { prioridad = 3, icono = "ic-mapa", segundos = 5, entra = 0.7, sale = 1.2, anim = "baja", raya = 280,
		caduca = 12, espaciar = 8, tituloColor = true, sonido = "MAP_PING" },
	subzona = { prioridad = 4, chico = true, segundos = 3.5, entra = 0.25, sale = 0.6, anim = "corto", raya = 70,
		caduca = 6, espaciar = 8, tituloColor = true },
	descubrir = { prioridad = 2, color = "oro", icono = "ic-descubrir", segundos = 6.5, entra = 0.5, sale = 1.0,
		anim = "destello", raya = 220, caduca = 15, huellas = true, tituloColor = true, sonido = "UI_QUEST_ROLLING_FORWARD_01" },
	barco = { prioridad = 1, lobo = "aullando", segundos = 6, entra = 0.6, sale = 1.0, anim = "desliza", raya = 170 },
	zepelin = { prioridad = 1, lobo = "aullando", segundos = 6, entra = 0.9, sale = 1.0, anim = "flota", raya = 170 },
	tranvia = { prioridad = 1, lobo = "aullando", segundos = 6, entra = 0.35, sale = 0.8, anim = "frena", raya = 170 },
	raro = { prioridad = 2, color = "raro", lobo = "atento", segundos = 7, entra = 0.5, sale = 1.0, anim = "rebote", raya = 170 },
	tesoro = { prioridad = 2, color = "oro", lobo = "atento", segundos = 7, entra = 0.5, sale = 1.0, anim = "gira", raya = 170 },
	mazmorra = { prioridad = 2, color = "mazmorra", icono = "ic-mazmorra", segundos = 6, entra = 0.7, sale = 1.0,
		anim = "subeAbajo", raya = 220, caduca = 25, tituloColor = true, sonido = "IG_SPELLBOOK_OPEN" },
	ciudad = { prioridad = 3, color = "pnj", icono = "ic-hoy", segundos = 5.5, entra = 1.3, sale = 1.6, anim = "lento",
		raya = 200, caduca = 12, espaciar = 8, tituloColor = true, sonido = "IG_MAINMENU_OPEN" },
	peligro = { prioridad = 2, color = "peligro", icono = "ic-alerta", segundos = 6.5, entra = 0.5, sale = 1.0,
		anim = "late", raya = 220, caduca = 15, tituloColor = true, sonido = "UI_RAID_BOSS_WHISPER_WARNING" },
	llegada = { prioridad = 2, lobo = "aullando", segundos = 5, entra = 0.5, sale = 1.0, anim = "aulla", raya = 170 },
	manada = { prioridad = 2, color = "acento", lobo = "aullando", segundos = 7, entra = 0.5, sale = 1.0,
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
	ciudad = { n = 8, mov = "flota", vel = 5, tam = 8 },
	peligro = { n = 12, mov = "sube", vel = 20, tam = 5 },
	llegada = { n = 8, mov = "chispa", vel = 20, tam = 6 },
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
		local d = { sonido = true, subzonaChica = true }
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
	if estilo and ESTILOS[estilo] and A.Get("anuncios." .. estilo) == false then return false end
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
-- La cola
---------------------------------------------------------------------------
local cola, seq = {}, 0
local actual           -- el `o` del que se ve
local ultimoInicio = -math.huge
local mostrar, revisar -- abajo

local function bloqueo(e)
	local o = e.o
	local A = N.A
	if A and A.Hidden and A.Hidden() then return "oculto" end
	if enCombate() and not o.enCombate then return "combate" end
	local p = prioridad(o)
	if ocupado(p) then return "ocupado" end
	local t = ahora()
	if not o.ya and juegoOcupado(o.tapaJuego) and t - e.desde < ESPERA_MAX then return "juego" end
	if p >= 3 and placa() and t - e.desde < ESPERA_PLACA then return "placa" end
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
local ROLES_TITULO = { "anuncio", "portada", "titulo" }
local function ajustarTitulo(fs, texto, maxW, chico)
	fs:SetWordWrap(false)
	fs:SetWidth(maxW)
	for i = chico and 3 or 1, #ROLES_TITULO do
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
	else
		fs:SetWidth(max(1, w + 6))
	end
	return min(w, maxW)
end

local function mmss(s)
	s = max(0, floor((s or 0) + 0.5))
	return format("%d:%02d", floor(s / 60), s % 60)
end

---------------------------------------------------------------------------
-- Las animaciones: (marco, t, e de entrada 0..1, dt) -> dx, dy del contenido
---------------------------------------------------------------------------
local function suave(x) x = max(0, min(1, x)) return x * x * (3 - 2 * x) end
local function halo(self, t, base, vaiven)
	self.Halo:SetAlpha((base or 0.35) + (vaiven or 0.15) * sin(t * 2.2))
end

local ANIM = {}
ANIM.sube = function(self, t, e) halo(self, t) return 0, -(1 - e) * 14 end
ANIM.baja = function(self, t, e) halo(self, t) return 0, (1 - e) * 24 end
ANIM.corto = function() return 0, 0 end
ANIM.lento = function(self, t) halo(self, t * 0.5, 0.3, 0.12) return 0, 0 end
ANIM.destello = function(self, t, e)
	-- El destello: el halo crece y brilla al entrar, y luego respira.
	local d = max(0, 1 - t / 0.7)
	self.Halo:SetSize(150 * (1 + 0.9 * d), 150 * (1 + 0.9 * d))
	self.Halo:SetAlpha(0.35 + 0.6 * d + 0.12 * sin(t * 2.2) * (1 - d))
	-- Las huellas se dibujan una a una.
	if self.Huellas and self.Huellas:IsShown() then
		local n = min(6, floor(max(0, t - 0.3) / 0.28))
		if n ~= self.alfaPasos then self.alfaPasos = n self.Huellas:Set(n, 6) end
	end
	return 0, -(1 - e) * 10
end
ANIM.desliza = function(self, t, e)
	halo(self, t)
	return -(1 - suave(e)) * 70, (e >= 1) and sin(t * 2.4) * 3 or 0
end
ANIM.flota = function(self, t, e)
	halo(self, t)
	if self.Lobo.SetRotation then self.Lobo:SetRotation(0.12 * sin(t * 1.6)) end
	return sin(t * 1.1) * 6, (1 - suave(e)) * 40 + sin(t * 1.6) * 4
end
ANIM.frena = function(self, t, e, entra)
	halo(self, t)
	if t < entra then
		local p = t / entra
		return (1 - p) * (1 - p) * (1 - p) * 160, 0
	end
	local s = t - entra
	return -5 * exp(-s * 10) * cos(s * 38), 0
end
ANIM.rebote = function(self, t)
	halo(self, t)
	return 0, 26 * abs(sin(t * 7)) * max(0, 1 - t / 1.0)
end
ANIM.gira = function(self, t)
	if self.Halo.SetRotation then self.Halo:SetRotation(t * 1.4) end
	self.Halo:SetAlpha(0.45 + 0.2 * sin(t * 3))
	return 0, 0
end
ANIM.subeAbajo = function(self, t, e) halo(self, t) return 0, -(1 - suave(e)) * 44 end
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
	self.Halo:SetSize(150 * (1 + 0.4 * sin(p * math.pi)), 150 * (1 + 0.4 * sin(p * math.pi)))
	halo(self, t)
	return 0, 0
end
ANIM.cruzan = function(self, t)
	halo(self, t)
	local h = self.Huellas
	if h and h:IsShown() then
		local ancho = self:GetWidth()
		local w = h:GetWidth()
		local x = -ancho / 2 - w + ((t * 150) % (ancho + w * 2))
		h:ClearAllPoints()
		h:SetPoint("LEFT", self.C, "TOP", x, -64)
	end
	return 0, 0
end
K.ANIMACIONES_ANUNCIO = ANIM

---------------------------------------------------------------------------
-- 1.3.8: el cine de todos (pedido de Toxic: «más cine: entrada con
-- profundidad, brillo del nombre, partículas o polvo según el tipo, salida
-- elegante»). Todo en el mismo OnUpdate, solo mientras se ve; en modo
-- ligero y en el chico, nada de esto.
--   * Profundidad: el halo llega de lejos (grande) y se asienta; el nombre
--     se acerca un poco (SetTextScale, si el juego lo trae); la línea de
--     arriba y la de abajo aparecen un instante después del nombre.
--   * Brillo: una luz cruza el nombre una vez, al terminar de entrar.
--   * Polvo: sus partículas (PARTICULAS) con semillas fijas, sin azar por cuadro.
--   * Salida: el contenido sube un poco, las rayas se cierran y el halo se abre.
---------------------------------------------------------------------------
local PI = math.pi
local function semilla(i, k)
	local x = sin(i * 12.9898 + k * 78.233) * 43758.5453
	return x - floor(x)
end
local SIN_PROFUNDIDAD = { destello = true, aulla = true, gira = true }
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
	late = { ancho = 260, dura = 0.7, fuerza = 0.6 },
	aulla = { ancho = 280, dura = 1.0, fuerza = 0.55 },
	cruzan = { ancho = 180, dura = 0.9, fuerza = 0.4 },
}
K.ONDA_ANUNCIO = ONDA

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
	local h = max(20, (x.Titulo.GetStringHeight and x.Titulo:GetStringHeight()) or 30)
	if CreateColor then
		x.BrilloI:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(1, 1, 1, 0.6))
		x.BrilloD:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0.6), CreateColor(r, g, b, 0))
	end
	for _, t in ipairs({ x.BrilloI, x.BrilloD }) do t:SetHeight(h) t:Hide() end
	if CreateColor then
		x.BandaI:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.2))
		x.BandaD:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.2), CreateColor(r, g, b, 0))
	end
	x.BandaI:ClearAllPoints()
	x.BandaI:SetPoint("RIGHT", x.Titulo, "CENTER", 0, -2)
	x.BandaD:ClearAllPoints()
	x.BandaD:SetPoint("LEFT", x.Titulo, "CENTER", -1, -2)
	for _, t in ipairs({ x.BandaI, x.BandaD }) do t:SetWidth(1) t:SetShown(x.alfaConBrillo) end
	x.Sobre:SetAlpha(x.alfaConBrillo and 0 or 1)
	x.Texto:SetAlpha(x.alfaConBrillo and 0 or 1)
	x.Pista:SetAlpha(x.alfaConBrillo and 0 or 1)
	if x.Titulo.SetTextScale then pcall(x.Titulo.SetTextScale, x.Titulo, 1) end
end

local function cine(self, t, a, fuera)
	local entra = self.alfaEntra or 0.55
	if self.alfaConBrillo then
		-- La línea de arriba y la de abajo, un instante después del nombre.
		local s1 = min(1, max(0, (t - 0.12) / 0.4))
		local s2 = min(1, max(0, (t - 0.32) / 0.45))
		self.Sobre:SetAlpha(s1)
		self.Texto:SetAlpha(s2)
		self.Pista:SetAlpha(s2)
		-- La banda de luz se abre desde el centro y se cierra al salir.
		local bw = (self.alfaTW or 200) * 0.5 + 120
		local ab = suave(t / (entra * 1.3)) * (1 - suave(fuera or 0))
		local w = max(1, floor(bw * ab + 0.5))
		if w ~= self.alfaBandaW then
			self.alfaBandaW = w
			self.BandaI:SetWidth(w)
			self.BandaD:SetWidth(w)
		end
		-- La luz que cruza el nombre.
		local s = (t - entra * 0.6) / 0.9
		if s > 0 and s < 1 and not fuera then
			local tw = self.alfaTW or 200
			local px = -tw / 2 - 36 + s * (tw + 72)
			local al = sin(s * PI) * a
			self.BrilloI:ClearAllPoints()
			self.BrilloI:SetPoint("RIGHT", self.Titulo, "CENTER", px, 0)
			self.BrilloD:ClearAllPoints()
			self.BrilloD:SetPoint("LEFT", self.Titulo, "CENTER", px, 0)
			self.BrilloI:SetAlpha(al)
			self.BrilloD:SetAlpha(al)
			self.BrilloI:Show()
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
		local s = 150 * (1 + 1.1 * k + 0.35 * abre)
		self.Halo:SetSize(s, s)
		if k > 0 and self.Titulo.SetTextScale then pcall(self.Titulo.SetTextScale, self.Titulo, 1 + 0.16 * k) end
	end
	-- 1.3.9 (105): la onda que se abre desde el lobo al entrar (una vez, más
	-- ancha en lo que se descubre o en el barco que llega), el emblema del bando
	-- que asoma detrás y se asienta, y su tira que se dibuja del centro.
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
		local s = 92 * (1.25 - 0.25 * k)
		self.Emblema:SetSize(s, s)
		self.Emblema:SetAlpha(0.22 * k * a * (1 - (fuera or 0)))
		if self.Tira and self.Tira:IsShown() then
			local w = max(1, floor((self.alfaTiraW or 200) * suave((t - entra * 0.5) / 0.6) * (1 - suave(fuera or 0)) + 0.5))
			if w ~= self.alfaTiraAhora then
				self.alfaTiraAhora = w
				self.Tira:SetWidth(w)
			end
		end
	end
	-- El polvo.
	local p = self.alfaP
	if not p then return end
	local tw = self.alfaTW or 200
	local W = tw + 140
	local cy = self.alfaChico and -30 or -113
	for i = 1, p.n do
		local tex = self.Polvo[i]
		local vida = 1.8 + semilla(i, 1) * 1.4
		local fase = ((t + semilla(i, 2) * vida) % vida) / vida
		local x0 = (semilla(i, 3) - 0.5) * W
		local y0 = cy + (semilla(i, 4) - 0.5) * 56
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
		tex:SetAlpha(sin(fase * PI) * 0.9 * a * (1 - (fuera or 0)))
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
	x.RayaI:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.9))
	x.RayaD:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.9), CreateColor(r, g, b, 0))
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

local function armar()
	f = CreateFrame("Frame", "AlfaAnuncio", K.Raiz())
	f:SetSize(ANCHO_MAX, 170)
	f:SetPoint("TOP", UIParent, "TOP", 0, -130)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(false)
	f:Hide()
	-- El contenido se mueve entero con la animación.
	f.C = CreateFrame("Frame", nil, f)
	f.C:SetAllPoints(f)
	local C = f.C

	f.Halo = C:CreateTexture(nil, "BACKGROUND")
	f.Halo:SetTexture(HALO)
	f.Halo:SetSize(150, 150)
	f.Halo:SetBlendMode("ADD")
	f.Lobo = C:CreateTexture(nil, "ARTWORK")
	f.Lobo:SetSize(58, 58)
	f.Lobo:SetPoint("CENTER", f.Halo, "CENTER", 0, 0)

	f.Sobre = K.Texto(C, "mayus", "acento")
	f.Sobre:SetJustifyH("CENTER")
	f.Titulo = K.Texto(C, "anuncio", "texto")
	f.Titulo:SetJustifyH("CENTER")
	f.Texto = K.Texto(C, "globoGrande", "textoSuave")
	f.Texto:SetJustifyH("CENTER")
	f.Pista = K.Texto(C, "nota", "textoTenue")
	f.Pista:SetJustifyH("CENTER")
	for _, fs in ipairs({ f.Sobre, f.Titulo, f.Texto, f.Pista }) do
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 0.9)
	end

	-- Las dos rayas de luz a los lados del nombre.
	f.RayaI = C:CreateTexture(nil, "ARTWORK")
	f.RayaD = C:CreateTexture(nil, "ARTWORK")
	for _, t in ipairs({ f.RayaI, f.RayaD }) do
		t:SetColorTexture(1, 1, 1, 1)
		t:SetHeight(2)
	end

	-- 1.3.8: el brillo que cruza el nombre al entrar (dos medias luces que
	-- se suman) y el polvo o las chispas de cada tipo.
	f.BrilloI = C:CreateTexture(nil, "OVERLAY")
	f.BrilloD = C:CreateTexture(nil, "OVERLAY")
	for _, t in ipairs({ f.BrilloI, f.BrilloD }) do
		t:SetColorTexture(1, 1, 1, 1)
		t:SetBlendMode("ADD")
		t:SetSize(36, 30)
		t:Hide()
	end
	-- La banda de luz detrás del nombre (de cine: se abre del centro a los lados).
	f.BandaI = C:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.BandaD = C:CreateTexture(nil, "BACKGROUND", nil, 1)
	for _, t in ipairs({ f.BandaI, f.BandaD }) do
		t:SetColorTexture(1, 1, 1, 1)
		t:SetHeight(58)
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

	-- 1.3.9 (105): más cine. La onda que se abre al entrar (desde el lobo), el
	-- emblema de tu bando detrás (con la temática, Kit/Bando.lua) y su tira
	-- de madera o piedra que se dibuja bajo el nombre, del centro a los lados.
	f.Onda = C:CreateTexture(nil, "BACKGROUND", nil, 2)
	f.Onda:SetTexture(HALO)
	f.Onda:SetBlendMode("ADD")
	f.Onda:Hide()
	f.Emblema = C:CreateTexture(nil, "BACKGROUND", nil, -2)
	f.Emblema:SetSize(92, 92)
	f.Emblema:Hide()
	if K.TiraBando then f.Tira = K.TiraBando(C, 3, "ARTWORK") end

	-- El borde que late (peligro): cuatro líneas alrededor del nombre y su línea.
	f.Borde = {}
	for i = 1, 4 do
		local t = C:CreateTexture(nil, "ARTWORK")
		t:SetColorTexture(1, 1, 1, 1)
		t:Hide()
		f.Borde[i] = t
	end

	-- El anuncio se cierra con un clic en su contenido (ícono, nombre y línea:
	-- clic derecho siempre cierra; el izquierdo hace su acción si la tiene y
	-- cierra) o en su X. Solo ese bloque toma el ratón, nunca la franja ancha.
	f.Toque = CreateFrame("Button", nil, C)
	f.Toque:SetPoint("TOP", C, "TOP", 0, -10)
	f.Toque:SetSize(200, 120)
	if f.Toque.RegisterForClicks then f.Toque:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
	f.Toque:SetScript("OnClick", function(_, boton) tocar(boton) end)
	f.X = K.BotonIcono(C, "ic-cerrar", function() cerrar() end, { tam = 18, icono = 10, ayuda = K.L and K.L["Cerrar"] or nil })
	f.X:SetPoint("TOPRIGHT", f.Toque, "TOPRIGHT", 0, 0)
	f.X:SetFrameLevel(f.Toque:GetFrameLevel() + 2)
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
			elseif prioridad(o) >= 3 and not self.alfaBajoPlaca and placa() then razon = "placa"
			else
				self.alfaMirar = (self.alfaMirar or 0) - dt
				if self.alfaMirar <= 0 then
					self.alfaMirar = 0.5
					if not vigente(o, true) then razon = "vencido" end
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
		-- Su animación (en modo ligero, solo el fundido).
		local e = min(1, t / entra)
		local dx, dy = 0, 0
		local fn = not self.alfaLigero and ANIM[est.anim] or nil
		if fn then dx, dy = fn(self, t, e, entra) end
		-- 1.3.8: la salida elegante: sube un poco mientras se desvanece.
		local fuera = (t > fin and salida > 0) and min(1, (t - fin) / salida) or nil
		if fuera and not self.alfaLigero then dy = (dy or 0) + 12 * suave(fuera) end
		dx, dy = floor((dx or 0) + 0.5), floor((dy or 0) + 0.5)
		if dx ~= self.alfaDX or dy ~= self.alfaDY then
			self.alfaDX, self.alfaDY = dx, dy
			self.C:ClearAllPoints()
			self.C:SetPoint("TOPLEFT", self, "TOPLEFT", dx, dy)
			self.C:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", dx, dy)
		end
		-- Las rayas se abren.
		local r = min(1, max(0, (t - 0.2) / (est.anim == "baja" and 1.1 or 0.7)))
		if fuera and not self.alfaLigero then r = r * (1 - suave(fuera)) end
		local ancho = max(1, floor(r * (self.alfaRaya or 170) + 0.5))
		if ancho ~= self.alfaRayaW then
			self.alfaRayaW = ancho
			self.RayaI:SetWidth(ancho)
			self.RayaD:SetWidth(ancho)
		end
		if not self.alfaLigero then cine(self, t, a, fuera) end
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

-- Dónde sale: arriba del centro; con la placa de llegada a la vista, debajo de ella.
local function colocar(chico)
	f:ClearAllPoints()
	local p = placa()
	-- 1.3.7: bajo la placa solo si cabe en la mitad de arriba (con la flecha
	-- abajo se saldría de la pantalla); si no, en su lugar de siempre.
	if p then
		local ok, cabe = pcall(function()
			local pb, es, ue = p:GetBottom(), f:GetEffectiveScale(), UIParent:GetEffectiveScale()
			if not (pb and es and es > 0) then return false end
			local abajo = pb * p:GetEffectiveScale() / es + (chico and -6 or 30) - f:GetHeight()
			return abajo >= UIParent:GetHeight() * ue / es / 2
		end)
		if not (ok and cabe) then p = nil end
	end
	f.alfaBajoPlaca = p ~= nil
	if p then
		f:SetPoint("TOP", p, "BOTTOM", 0, chico and -6 or 30)
	else
		f:SetPoint("TOP", UIParent, "TOP", 0, chico and -120 or -130)
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
	f.alfaDX, f.alfaDY, f.alfaRayaW, f.alfaPasos = nil, nil, nil, nil
	f.alfaChico = chico
	f.alfaLigero = N.Ligero and N.Ligero() or false
	f.alfaEntra = tonumber(o.entra) or est.entra or 0.55
	f.alfaSaleNormal = est.sale or 1.0
	f.alfaRaya = chico and min(90, est.raya or 170) or (est.raya or 170)

	local ancho = anchoPantalla()
	f:SetWidth(ancho)
	local util = ancho - 20
	for _, fs in ipairs({ f.Sobre, f.Texto, f.Pista }) do fs:SetWidth(util) end

	-- El lobo o el ícono del tipo.
	local icono = not o.lobo and (o.icono or est.icono) or nil
	if icono then
		f.Lobo:SetTexture(K.Ruta(icono))
		f.alfaLoboTam = 40
	else
		f.Lobo:SetTexture(K.Lobo(o.lobo or est.lobo or "aullando"))
		f.alfaLoboTam = 58
	end
	f.Lobo:SetSize(f.alfaLoboTam, f.alfaLoboTam)
	if f.Lobo.SetRotation then f.Lobo:SetRotation(0) end
	if f.Halo.SetRotation then f.Halo:SetRotation(0) end
	f.Halo:SetSize(150, 150)
	f.Halo:SetAlpha(0.35)
	f.Lobo:SetShown(not chico)
	f.Halo:SetShown(not chico)

	K.Escribir(f.Sobre, o.sobre and K.Mayus(o.sobre) or "")
	f.Texto.alfaRol = chico and "cuerpo" or "globoGrande"
	K.Fuente(f.Texto)
	f.Texto:SetWordWrap(true)
	if f.Texto.SetMaxLines then f.Texto:SetMaxLines(3) end
	K.Escribir(f.Texto, o.texto or "")
	K.Escribir(f.Pista, o.alClic and o.pista or "")
	local tw = ajustarTitulo(f.Titulo, o.titulo, util - 40, chico)

	-- Acomodo: el grande (lobo, sobre, nombre, línea) o el chico (sobre y nombre).
	f.Halo:ClearAllPoints()
	f.Halo:SetPoint("CENTER", f.C, "TOP", 0, -42)
	f.Sobre:ClearAllPoints()
	f.Titulo:ClearAllPoints()
	if chico then
		f.Sobre:SetPoint("TOP", f.C, "TOP", 0, -6)
		f.Titulo:SetPoint("TOP", f.C, "TOP", 0, -20)
	else
		f.Sobre:SetPoint("TOP", f.C, "TOP", 0, -80)
		f.Titulo:SetPoint("TOP", f.C, "TOP", 0, -98)
	end
	f.Texto:ClearAllPoints()
	f.Texto:SetPoint("TOP", f.Titulo, "BOTTOM", 0, chico and -4 or -8)
	f.Pista:ClearAllPoints()
	f.Pista:SetPoint("TOP", f.Texto, "BOTTOM", 0, -6)
	f.RayaI:ClearAllPoints()
	f.RayaI:SetPoint("RIGHT", f.Titulo, "CENTER", -(tw / 2 + 14), 0)
	f.RayaD:ClearAllPoints()
	f.RayaD:SetPoint("LEFT", f.Titulo, "CENTER", tw / 2 + 14, 0)
	f.RayaI:SetAlpha(1)
	f.RayaD:SetAlpha(1)
	f.RayaI:SetWidth(1)
	f.RayaD:SetWidth(1)

	-- El borde (peligro): alrededor del nombre y su línea.
	local conBorde = est.anim == "late" and not f.alfaLigero
	for _, b in ipairs(f.Borde) do b:ClearAllPoints() b:SetShown(conBorde) end
	if conBorde then
		local bw = min(util, tw + 80)
		local arriba, abajo = f.Titulo, (o.texto and o.texto ~= "") and f.Texto or f.Titulo
		local B = f.Borde
		B[1]:SetPoint("BOTTOM", arriba, "TOP", 0, 8) B[1]:SetSize(bw, 2)
		B[2]:SetPoint("TOP", abajo, "BOTTOM", 0, -8) B[2]:SetSize(bw, 2)
		B[3]:SetPoint("TOPRIGHT", B[1], "TOPLEFT", 0, 0) B[3]:SetPoint("BOTTOMRIGHT", B[2], "BOTTOMLEFT", 0, 0) B[3]:SetWidth(2)
		B[4]:SetPoint("TOPLEFT", B[1], "TOPRIGHT", 0, 0) B[4]:SetPoint("BOTTOMLEFT", B[2], "BOTTOMRIGHT", 0, 0) B[4]:SetWidth(2)
	end

	-- Las huellas (descubrir: se dibujan bajo la línea; manada: cruzan).
	if est.huellas and not chico and not f.alfaLigero then
		if not f.Huellas then f.Huellas = K.Huellas(f.C, { tam = 14, max = 8, total = 6, actual = 0 }) end
		f.Huellas:ClearAllPoints()
		if est.anim == "destello" then
			f.Huellas:Set(0, 6)
			f.Huellas:SetPoint("TOP", (o.alClic and o.pista) and f.Pista or f.Texto, "BOTTOM", 0, -6)
		else
			f.Huellas:Set(5, 5)
			f.Huellas:SetPoint("LEFT", f.C, "TOP", -ancho / 2, -64)
		end
		f.Huellas:Show()
	elseif f.Huellas then
		f.Huellas:Hide()
	end

	f:SetHeight(chico and 80 or 170)
	f.C:ClearAllPoints()
	f.C:SetAllPoints(f)
	colocar(chico)
	-- Lo que se toca: solo el bloque del contenido (su ancho, no la franja).
	local abajo = f.Titulo
	if (o.texto or "") ~= "" or o.cuenta then abajo = f.Texto end
	if o.alClic and (o.pista or "") ~= "" then abajo = f.Pista end
	local tocaW = max(tw, K.AnchoTexto(f.Texto), K.AnchoTexto(f.Sobre), K.AnchoTexto(f.Pista), chico and 0 or 58)
	tocaW = min(util, tocaW + 36)
	f.Toque:ClearAllPoints()
	f.Toque:SetPoint("TOP", f.C, "TOP", 0, chico and -2 or -10)
	f.Toque:SetPoint("BOTTOM", abajo, "BOTTOM", 0, -4)
	f.Toque:SetWidth(tocaW)
	f.alfaClic = o.alClic
	f.alfaCuenta = o.cuenta
	f.alfaSeg = nil
	f.alfaDura = tonumber(o.segundos) or est.segundos or 6
	f.alfaT = 0
	-- En combate ni el contenido ni la X toman el ratón.
	raton()
	pintar(f)
	prepararCine(f, o, est, chico, tw)
	-- 1.3.9: el tema de tu bando (emblema y tira) y la onda de entrada.
	local tema = K.Bando and K.Bando() or nil
	f.alfaTema = (not chico) and tema or nil
	f.alfaAnim, f.alfaTiraAhora = est.anim, nil
	local r, g, b = K.Color(tono(o, est))
	f.Onda:ClearAllPoints()
	f.Onda:SetPoint("CENTER", f.Halo, "CENTER", 0, 0)
	f.Onda:SetVertexColor(r, g, b, 1)
	f.Onda:SetShown(f.alfaConBrillo and not chico)
	f.Onda:SetAlpha(0)
	f.Emblema:ClearAllPoints()
	f.Emblema:SetPoint("CENTER", f.Halo, "CENTER", 0, -4)
	if f.alfaTema then
		f.Emblema:SetTexture(tema.emblema)
		f.Emblema:SetVertexColor(1, 1, 1, 1)
		f.Emblema:SetAlpha(f.alfaLigero and 0.2 or 0)
		f.Emblema:SetSize(92, 92)
		f.Emblema:Show()
	else
		f.Emblema:Hide()
	end
	if f.Tira then
		f.Tira:ClearAllPoints()
		f.Tira:SetPoint("TOP", f.Titulo, "BOTTOM", 0, -1)
		f.Tira:SetWidth(1)
		if not (f.alfaTema and f.Tira:Pintar(tema)) then f.Tira:Hide() end
		f.alfaTiraW = min(util, tw + 60)
		if f.alfaLigero and f.Tira:IsShown() then f.Tira:SetWidth(f.alfaTiraW) end
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
	}
end

---------------------------------------------------------------------------
-- El ícono chico (1.3.7): un raro en plena pelea o en una mazmorra. Nunca
-- toma el ratón; se va solo.
---------------------------------------------------------------------------
local function armarChico()
	fc = CreateFrame("Frame", "AlfaAnuncioChico", K.Raiz())
	fc:SetSize(220, 30)
	fc:SetPoint("TOP", UIParent, "TOP", 0, -96)
	fc:SetFrameStrata("HIGH")
	fc:EnableMouse(false)
	fc:Hide()
	fc.Icono = fc:CreateTexture(nil, "ARTWORK")
	fc.Icono:SetSize(26, 26)
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
	local token = o.color or (K.Clasico() and "oro" or "acento")
	if o.icono then fc.Icono:SetTexture(K.Ruta(o.icono)) else fc.Icono:SetTexture(K.Lobo(o.lobo or "atento")) end
	fc.Icono:SetVertexColor(K.Color(token))
	K.Escribir(fc.Texto, o.titulo)
	local w = min(anchoPantalla() - 40, K.AnchoTexto(fc.Texto))
	fc.Texto:SetWidth(max(1, w + 2))
	fc:SetWidth(26 + 6 + w + 2)
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
ev:SetScript("OnEvent", function(_, evento)
	if evento == "PLAYER_REGEN_DISABLED" then
		pelea = true
		raton()
	else
		pelea = false
		raton()
		if #cola > 0 then programar(1) end
	end
end)
