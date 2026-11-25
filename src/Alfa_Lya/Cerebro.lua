-- Alfa - Lya: cuándo habla y qué dice (toxic3000 / La Jauría). GPL-3.0.
--
-- Reglas contra el spam (lo primero):
--   * Un globo cada lya.minutos (5) a lo más; con "pocos", el doble. Solo lo
--     importante (morir, subir de nivel, un logro) se salta la espera.
--   * Cada frase sale 3 veces por personaje como mucho y luego nunca más
--     (N.DatosPersonaje("lya").vistos). "Volver a mostrar los consejos
--     vistos" las devuelve.
--   * Nunca en combate, en instancias ni mientras escribes: lo importante
--     espera a que se pueda (10 minutos como mucho); lo demás se pierde.
--   * Nunca encima del aviso de Hoy (Alfa_Inicio) ni de otro globo suyo.
--     1.3.1: lo importante que llega mientras dice otra cosa importante
--     espera su turno (una cola) y sale cuando se calla; un aviso de Alfa
--     nunca pisa lo importante ni un globo con botones (sale como aviso).
--   * Silenciar 1 hora calla todo menos lo que pides tú (clic).
--   * Mientras falte la bienvenida de Alfa (AlfaBienvenida.Pendiente), Lya
--     no aparece.
--
-- Lo que mira (eventos, sin OnUpdate; un latido de 60 s solo con Lya a la
-- vista, «lya.latido» en el reloj del núcleo): entrar (presentarse la
-- primera vez, saludar, "hace días que no te veía"), subir de nivel (aúlla;
-- 10, 20, 30, 40 la montura, 50 y 60), morir, durabilidad, bolsas,
-- habilidades por entrenar al llegar a una ciudad,
-- misiones listas para entregar, misiones entregadas hoy (10 y 25), la sesión
-- larga (2 y 4 horas), ausente (se duerme) y descansando un rato (también).
-- De vez en cuando y al pedirlo: "¿Sabías que…?" de Alfa, consejos del juego,
-- ánimo y, muy de vez en cuando, una frase de cariño.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local UI = M.UI
local F = M.FRASES

local type, tonumber, ipairs, pairs, pcall, rawget, format = type, tonumber, ipairs, pairs, pcall, rawget, string.format
local floor, max, min, random = math.floor, math.max, math.min, math.random

local Ce = {}
M.Cerebro = Ce

local MAX_VECES = 3
local ESPERA_IMPORTANTE = 600   -- s que algo importante puede esperar
local DORMIR_DESCANSANDO = 300  -- s descansando sin hacer nada para dormirse
local SIN_HABLAR = { muchos = 3 * 60, pocos = 10 * 60 } -- algo suelto tras tanto silencio (se siente viva)

local function ahora() return GetTime and GetTime() or 0 end
local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end
local function num(v) if issecretvalue and issecretvalue(v) then return nil end return tonumber(v) end
local function si(v) if issecretvalue and issecretvalue(v) then return false end return v == true end

local function datos()
	local d = N.DatosPersonaje(ID)
	d.vistos = type(d.vistos) == "table" and d.vistos or {}
	return d
end

---------------------------------------------------------------------------
-- Estado y puertas
---------------------------------------------------------------------------
local function bienvenidaPendiente()
	local B = rawget(_G, "AlfaBienvenida")
	if not (type(B) == "table" and type(B.Pendiente) == "function") then return false end
	local ok, p = pcall(B.Pendiente)
	return ok and p == true
end

function Ce.Activa() return N.Get(ID, "mostrar") ~= false and not bienvenidaPendiente() end

function Ce.Frecuencia()
	local v = N.Get(ID, "frecuencia")
	return (v == "pocos" or v == "importantes") and v or "muchos"
end

function Ce.Silenciada() return (tonumber(datos().silencio) or 0) > reloj() end

-- 1.4.0 (64): «Solo lo importante» de un clic. Recuerda cuántos consejos
-- tenías (lya.frecuenciaAntes) para volver igual con el mismo clic.
function Ce.SoloImportante() return Ce.Frecuencia() == "importantes" end
function Ce.AlternarImportante(si)
	if si == nil then si = not Ce.SoloImportante() end
	if si then
		if not Ce.SoloImportante() then N.Set(ID, "frecuenciaAntes", Ce.Frecuencia()) end
		N.Set(ID, "frecuencia", "importantes")
	else
		local antes = N.Get(ID, "frecuenciaAntes")
		N.Set(ID, "frecuencia", (antes == "pocos" or antes == "muchos") and antes or "muchos")
	end
	return si
end

local function enCombate()
	return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and si(UnitAffectingCombat("player"))) or false
end
local function enInstancia()
	if not IsInInstance then return false end
	local ok, dentro = pcall(IsInInstance)
	return ok and si(dentro)
end
local function escribiendo() return GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() ~= nil or false end
local function avisoDeHoy()
	local a = rawget(_G, "AlfaInicioAviso")
	return type(a) == "table" and a.IsShown and a:IsShown() and true or false
end

-- 1.3.9 (69): con un personaje nuevo (nivel 10 o menos), en la primera hora
-- de la sesión Lya habla la tercera parte (lya.calmaNuevos): hay mucho que
-- aprender del juego y no hace falta que ella sume. Lo importante, igual.
local NOVATO_NIVEL, NOVATO_HORA, NOVATO_VECES = 10, 3600, 3
local inicioSesion = ahora()
function Ce.Novato()
	if N.Get(ID, "calmaNuevos") == false then return false end
	local lv = num(UnitLevel and UnitLevel("player"))
	if not lv or lv > NOVATO_NIVEL then return false end
	return ahora() - inicioSesion < NOVATO_HORA
end
function Ce.EmpezoSesion(t) inicioSesion = t or ahora() end -- (para el banco)

local function intervalo()
	local m = tonumber(N.Get(ID, "minutos")) or 5
	if Ce.Frecuencia() == "pocos" then m = m * 2 end
	if Ce.Novato() then m = m * NOVATO_VECES end
	return max(1, m) * 60
end
Ce.Intervalo = intervalo -- (para el banco)

local function veces(id) return tonumber(datos().vistos[id]) or 0 end
local function contar(id) local d = datos() d.vistos[id] = veces(id) + 1 end

---------------------------------------------------------------------------
-- Decir
--   c = { id (para contar; nil = no se cuenta), texto, acciones, cara,
--         salto, aullar, importante, pedido (lo pidió el jugador),
--         alDecir = fn (cuando de verdad sale) }
--   -> true (lo dijo), "espera" (importante: lo dirá en cuanto se pueda) o false, motivo
---------------------------------------------------------------------------
local ultimo = -1e9 -- GetTime del último globo
local ultimoAullido = -1e9 -- 1.3.7: GetTime del último aullido
local espera        -- { c, hasta }: algo importante que espera su momento
local reintento

-- Lo que nunca se agota: saludos, reacciones a lo que pasa, ánimo, cariño y
-- los comentarios del momento. Entre ellas sale la que hace más que no dice
-- (nunca la misma dos veces seguidas). Los consejos y el "¿Sabías que…?"
-- siguen saliendo 3 veces como mucho: enseñan algo y repetirlos cansa.
local LIBRES = {
	bienvenida = true, volver = true, llegada = true, saludoManana = true, saludoTarde = true, saludoNoche = true,
	nivel = true, muerte = true, reparar = true, bolsas = true, entrenar = true, entregar = true,
	descanso = true, misionesHoy = true, animo = true, carino = true, ambiente = true, zona = true,
	hambre = true, salchichas = true,
	llegadaManana = true, llegadaNoche = true, llegadaMadrugada = true, saludoMadrugada = true, -- 1.3.8
	-- 1.2.7: las mazmorras, los ánimos de racha, la salchicha y la despedida (Momentos.lua)
	mazmorra = true, mazmorraSin = true, consuelo = true, racha = true, pideSalchicha = true,
	gracias = true, graciasTotal = true, antesDeIrte = true, adios = true, adiosSin = true,
}
local function libre(id) return type(id) == "string" and LIBRES[id:match("^(%a+)") or ""] or false end

local function motivo(c)
	if not Ce.Activa() or (A.Hidden and A.Hidden()) or not UI.Visible() then return "oculta" end
	if c.id and not libre(c.id) and veces(c.id) >= MAX_VECES then return "vista" end
	-- 1.2.8: los consejos que le pediste que ya no te diga (Aprende.lua).
	if not c.pedido and M.Aprende and M.Aprende.Callada(c) then return "callada" end
	if Ce.Silenciada() and not c.pedido then return "silencio" end
	if not c.importante and not c.pedido and Ce.Frecuencia() == "importantes" then return "modo" end
	-- 1.2.7: c.enMazmorra deja hablar dentro de una instancia (el consejo de la
	-- mazmorra, la despedida); nunca en combate.
	if enCombate() or (enInstancia() and not c.enMazmorra) or escribiendo() then return "esperar" end
	-- 1.3.7: lo que hace el juego (subir de nivel, una carga, una cinemática,
	-- sus estandartes; Alfa_Nucleo/Momentos.lua): espera. Con No molestar
	-- (/alfa calma, /dnd) se calla; lo importante queda en «Lo que me perdí».
	if not c.pedido and N.Ocupado then
		local oc, m = N.Ocupado("lya", c.importante and 2 or 3)
		if oc then
			if m == "calma" then return "calma" end
			if m == "pnj" then return "ocupada" end
			return "esperar"
		end
	end
	-- 1.2.9: en el modo foco (Foco.lua) se calla; lo importante y lo que pides, sí.
	if UI.EnFoco and UI.EnFoco() and not c.importante and not c.pedido and not c.enMazmorra then return "foco" end
	if not c.importante and not c.pedido then
		if UI.Hablando() or avisoDeHoy() then return "ocupada" end
		if ahora() - ultimo < intervalo() then return "pronto" end
	end
	return nil
end

-- 1.3.7 (41): lo importante que espera es una lista con prioridad (antes, un
-- solo lugar: lo segundo borraba lo primero). Sale de uno en uno, lo más
-- urgente primero; lo que se vence sin decirse queda en «Lo que me perdí».
local esperas = {}
local MAX_ESPERAS = 6
local function vencerEsperas()
	local t = ahora()
	for i = #esperas, 1, -1 do
		local e = esperas[i]
		if t > e.hasta then
			table.remove(esperas, i)
			if N.Perdido then pcall(N.Perdido, { titulo = L["Lya"], texto = e.c.texto, icono = "ic-lobo", origen = "lya" }) end
		end
	end
end
local function esperar(c)
	for i = #esperas, 1, -1 do if esperas[i].c.texto == c.texto then table.remove(esperas, i) end end
	local p = N.Prioridad and N.Prioridad(c.prioridad or 2) or 2
	local e = { c = c, hasta = ahora() + ESPERA_IMPORTANTE, p = p }
	local i = #esperas + 1
	for k, x in ipairs(esperas) do if p < x.p then i = k break end end
	table.insert(esperas, i, e)
	while #esperas > MAX_ESPERAS do
		local viejo = table.remove(esperas)
		if N.Perdido then pcall(N.Perdido, { titulo = L["Lya"], texto = viejo.c.texto, icono = "ic-lobo", origen = "lya" }) end
	end
end
function Ce.Esperas() return esperas end

local function reintentar()
	vencerEsperas()
	espera = esperas[1]
	if not espera then return end
	if escribiendo() and not enCombate() and (not enInstancia() or espera.c.enMazmorra) and not reintento then -- 1.2.7
		reintento = K.Despues(4, function() reintento = nil reintentar() end)
		return
	end
	local c = espera.c
	if motivo(c) == "esperar" then
		-- Lo que hace el juego se acaba solo: se vuelve a mirar cuando esté libre.
		-- (solo si espera por eso: si no, AlLibre correría ya y daría vueltas sin fin)
		if N.AlLibre and N.Ocupado and N.Ocupado("lya", espera.p) then
			N.AlLibre("lya.espera", reintentar, espera.p, { tipo = "lya", caduca = math.max(1, (espera.hasta or 0) - ahora()), alCaducar = vencerEsperas })
		end
		return
	end
	table.remove(esperas, 1)
	espera = nil
	Ce.Decir(c)
	if esperas[1] and N.Una then N.Una("lya.esperas", 4, reintentar) end
end

---------------------------------------------------------------------------
-- (1.3.3) La entrada en silencio: mientras entras (N.Entrando, del núcleo)
-- Lya no habla sola; lo que diría lo guarda (N.GuardarAlEntrar, origen
-- "lya") y te lo cuenta cuando le das clic o, pasada la entrada, uno por
-- latido. Sin N.Entrando (un núcleo viejo), Lya habla como siempre; sin
-- N.GuardarAlEntrar/N.AlEntrar, una lista igual aquí mismo (la reserva).
---------------------------------------------------------------------------
local entrada = { lista = {}, porId = {} } -- la reserva
local guardadas = {} -- id -> lo que iba a decir (con sus botones y su alDecir)

local function nucleo(nombre)
	local fn = rawget(N, nombre)
	return type(fn) == "function" and fn or nil
end

function Ce.Entrando()
	local fn = nucleo("Entrando")
	if fn then
		local ok, v = pcall(fn)
		return ok and v == true
	end
	return false
end

function Ce.AlEntrar()
	local fn = nucleo("AlEntrar")
	if fn then
		local ok, l = pcall(fn)
		return ok and type(l) == "table" and l or {}
	end
	return entrada.lista
end

local function guardarAlEntrar(o)
	local fn = nucleo("GuardarAlEntrar")
	if fn then pcall(fn, o) return end
	local ya = entrada.porId[o.id]
	if ya then
		for i, x in ipairs(entrada.lista) do if x == ya then entrada.lista[i] = o end end
	else
		entrada.lista[#entrada.lista + 1] = o
	end
	entrada.porId[o.id] = o
	if A.Fire then A.Fire("ALFA_ALENTRAR") end
end

function Ce.OlvidarAlEntrar(id)
	guardadas[id] = nil
	local fn = nucleo("OlvidarAlEntrar")
	if fn then pcall(fn, id) return end
	local ya = entrada.porId[id]
	if not ya then return end
	entrada.porId[id] = nil
	for i = #entrada.lista, 1, -1 do if entrada.lista[i] == ya then table.remove(entrada.lista, i) end end
	if A.Fire then A.Fire("ALFA_ALENTRAR") end
end

-- Guarda lo que Lya diría ahora. -> true
local function guardarDicho(c)
	local id = "lya:" .. tostring(c.id or c.clase or c.texto)
	local a = type(c.acciones) == "table" and c.acciones[1] or nil
	local accion = a and not a.seguro and type(a.fn) == "function" and { texto = a.texto, alClic = a.fn } or nil
	guardadas[id] = c
	guardarAlEntrar({ id = id, titulo = L["Lya"], texto = c.texto, icono = "ic-lobo", accion = accion, origen = "lya" })
	-- Ya está guardado: para quien lo pidió, como dicho (no lo reintenta).
	if type(c.alDecir) == "function" then K.Llamar(c.alDecir) end
	return true
end

-- Lo que puede esperar a la entrada: no lo que pediste, ni su presentación.
local GUARDABLE = { oculta = true, esperar = true, ocupada = true, pronto = true, foco = true }
local function guardable(c, por)
	if c.pedido or c.alEntrar or c.importante == "siempre" or c.id == "presentacion1" then return false end
	if por ~= nil and not GUARDABLE[por] then return false end
	return Ce.Entrando()
end

-- (1.3.3) Una sola voz con Hoy: lo que uno ya dijo en la sesión (bolsas
-- llenas, reparar, entregar) el otro no lo repite. La tabla vive en el
-- núcleo (AlfaNucleo.dichosSesion): Hoy la mira y la anota igual.
local function dichosSesion()
	local t = rawget(N, "dichosSesion")
	if type(t) ~= "table" then t = {} N.dichosSesion = t end
	return t
end
function Ce.YaSeDijo(voz) return voz ~= nil and dichosSesion()[voz] ~= nil end
function Ce.Anotar(voz) if voz then dichosSesion()[voz] = ahora() end end

-- (1.3.3) «Te perdiste esto»: un aviso con botón que se fue sin que lo
-- tocaras (otro tomó su lugar o se le acabó el tiempo) queda aquí, con su
-- botón, para «Pregúntale a Lya». El Kit avisa con ALFA_AVISO_PERDIDO.
local MAX_PERDIDOS = 10
Ce.perdidos = {}
function Ce.Perdido(o)
	if type(o) ~= "table" then return false end
	-- 1.3.7: el núcleo los guarda todos (N.Perdido, los últimos 30 por
	-- personaje). Si el Kit ya lo anotó, N.Perdido no lo repite (mismo título y texto).
	if rawget(N, "Perdido") then
		local ac = o.accion
		if not (type(ac) == "table" and type(ac.alClic) == "function" and not ac.seguro) then return false end
		local e = N.Perdido(o)
		if M.Avisar then M.Avisar() end
		return e ~= nil
	end
	local ac = o.accion
	if not (type(ac) == "table" and type(ac.alClic) == "function" and not ac.seguro) then return false end
	local titulo, texto = o.titulo or "", o.texto or ""
	if titulo == "" and texto == "" then return false end
	for i = #Ce.perdidos, 1, -1 do
		local x = Ce.perdidos[i]
		if x.titulo == titulo and x.texto == texto then table.remove(Ce.perdidos, i) end
	end
	table.insert(Ce.perdidos, 1, { titulo = titulo, texto = texto, icono = o.icono, hora = date and date("%H:%M") or "",
		accion = { texto = ac.texto, fn = ac.alClic } })
	while #Ce.perdidos > MAX_PERDIDOS do table.remove(Ce.perdidos) end
	if M.Avisar then M.Avisar() end
	return true
end
function Ce.OlvidarPerdido(x)
	if rawget(N, "OlvidarPerdido") then N.OlvidarPerdido(x) end
	for i = #Ce.perdidos, 1, -1 do if Ce.perdidos[i] == x then table.remove(Ce.perdidos, i) end end
end
-- 1.3.7: la lista de «Te perdiste esto» (la del núcleo, o la de aquí sin él).
function Ce.Perdidos()
	if rawget(N, "Perdidos") then return N.Perdidos() end
	return Ce.perdidos
end
function Ce.AccionPerdido(x)
	if rawget(N, "AccionPerdido") then
		local a = N.AccionPerdido(x)
		return a and { texto = a.texto, fn = a.alClic } or nil
	end
	return x and x.accion
end
if A.On then A.On("ALFA_PERDIDOS", function() if M.Avisar then M.Avisar() end end) end
if A.On then A.On("ALFA_AVISO_PERDIDO", function(o) pcall(Ce.Perdido, o) end) end

-- Lo último que dijo, lo más nuevo primero (esta sesión).
Ce.historial = {}
local HISTORIAL = 20

-- 1.3.1: la cola de lo importante. Lo que llega mientras dice otra cosa
-- importante espera su turno, en orden (10 minutos como mucho), y sale cuando
-- se calla el globo de ahora (M.AlCallarGlobo, de Lya.lua).
local cola = {}
local MAX_COLA = 6
local sacarCola
local function hablaImportante()
	local a = UI.Actual and UI.Actual()
	return type(a) == "table" and a.importante == true
end

function Ce.Decir(c)
	if type(c) ~= "table" or type(c.texto) ~= "string" or c.texto == "" then return false end
	-- 1.3.8: un mensaje por suceso: lo que acaba de salir en un aviso, un
	-- anuncio o el chat no lo repite (un dato de la zona: en 5 min).
	if not c.pedido and N.YaSeVio and N.YaSeVio(c.texto, c.clase == "dato" and 300 or nil, "lya") then return false, "repetido" end
	if c.suceso ~= nil and not c.pedido and N.Suceso and not N.Suceso(c.suceso, c.ventana) then return false, "repetido" end
	local por = motivo(c)
	-- 1.3.3: mientras entras, lo que diría sola se guarda para después.
	if guardable(c, por) then
		if c.voz then Ce.Anotar(c.voz) end
		return guardarDicho(c)
	end
	if por == "esperar" and c.importante then
		esperar(c)
		reintentar()
		return "espera", por -- verdadero: ya lo dirá en cuanto se pueda
	end
	-- 1.3.7: con No molestar, lo importante queda en «Lo que me perdí».
	if por == "calma" and c.importante and N.Perdido then
		pcall(N.Perdido, { titulo = L["Lya"], texto = c.texto, icono = "ic-lobo", origen = "lya" })
		if type(c.alDecir) == "function" then K.Llamar(c.alDecir) end
		return "espera", por
	end
	if por then return false, por end
	-- 1.3.1: lo importante no pisa lo importante: a la cola.
	if c.importante and not c.pedido and hablaImportante() then
		if #cola < MAX_COLA then cola[#cola + 1] = { c = c, hasta = ahora() + ESPERA_IMPORTANTE } end
		N.Una("lya.cola", 3, sacarCola) -- por si acaso: lo normal es al callarse
		return "espera", "cola"
	end
	-- 1.3.7 (35, 36): un solo aullido a la vez: lo que llega a los pocos segundos
	-- de otro aullido (un reto cumplido al subir de nivel) salta en vez de aullar.
	if c.aullar then
		if ahora() - ultimoAullido < 30 then
			c = setmetatable({ aullar = false, salto = true }, { __index = c })
		else
			ultimoAullido = ahora()
		end
	end
	if c.id then contar(c.id) end
	ultimo = ahora()
	-- 1.2.6: lo que dijo, por si el globo se fue antes de leerlo.
	table.insert(Ce.historial, 1, { texto = c.texto, acciones = c.acciones, hora = date and date("%H:%M") or "" })
	while #Ce.historial > HISTORIAL do table.remove(Ce.historial) end
	UI.Hablar(c)
	if N.Visto then N.Visto(c.texto, "lya") end -- 1.3.8
	if c.voz then Ce.Anotar(c.voz) end
	if type(c.alDecir) == "function" then K.Llamar(c.alDecir) end
	return true
end

-- El siguiente de la cola, si ya se puede (si no, lo vuelve a mirar en 3 s).
sacarCola = function()
	local t = ahora()
	while cola[1] and t > cola[1].hasta do table.remove(cola, 1) end
	if not cola[1] then return end
	-- Mientras dice algo importante o viene corriendo a su lugar (la llegada), espera.
	if hablaImportante() or (UI.Llegando and UI.Llegando()) then
		N.Una("lya.cola", 3, sacarCola)
		return
	end
	local x = table.remove(cola, 1)
	Ce.Decir(x.c)
	if cola[1] then N.Una("lya.cola", 3, sacarCola) end
end
M.AlCallarGlobo = function() if cola[1] then N.Una("lya.cola", 1, sacarCola) end end
function Ce.Cola() return cola end

-- 1.3.1: algo que no es importante y no pudo salir (el motivo de Ce.Decir):
-- en cuántos segundos vale la pena volver a intentarlo, o nil (oculta,
-- silenciada, callada, «solo importantes» o ya vista: no se insiste).
function Ce.Reintento(por)
	if por == "pronto" then return max(5, intervalo() - (ahora() - ultimo)) + 1 end
	if por == "ocupada" then return 15 end
	if por == "esperar" or por == "foco" then return 60 end
	return nil
end

-- La frase de una categoría que menos ha dicho (y menos de 3 veces): id, texto.
local function cuando(id)
	local d = datos()
	d.cuando = type(d.cuando) == "table" and d.cuando or {}
	return tonumber(d.cuando[id]) or 0, d.cuando
end

local function frase(cat)
	local lista = F[cat]
	if type(lista) ~= "table" or #lista == 0 then return nil end
	local mejor, mejorN
	local inicio = random(#lista)
	for k = 0, #lista - 1 do
		local i = (inicio + k - 1) % #lista + 1
		local id = cat .. i
		if LIBRES[cat] then
			local t = cuando(id)
			if not mejorN or t < mejorN then mejor, mejorN = i, t end
		else
			local n = veces(id)
			if n < MAX_VECES and (not mejorN or n < mejorN) then mejor, mejorN = i, n end
		end
	end
	if not mejor then return nil end
	if LIBRES[cat] then
		local _, t = cuando(cat .. mejor)
		t[cat .. mejor] = reloj()
	end
	return cat .. mejor, L[lista[mejor]]
end

-- Di una frase de esa categoría (los %s/%d con ...). -> true si habló
local function decirDe(cat, c, ...)
	local id, texto = frase(cat)
	if not id then return false end
	c = c or {}
	c.id = id
	c.texto = select("#", ...) > 0 and format(texto, ...) or texto
	return Ce.Decir(c)
end
Ce.DecirDe = decirDe

---------------------------------------------------------------------------
-- Acciones de los botones
---------------------------------------------------------------------------
local function irA(tipo)
	local Cerca = rawget(_G, "AlfaCerca")
	if type(Cerca) == "table" and type(Cerca.Ir) == "function" then
		local ok, puesto = pcall(Cerca.Ir, tipo)
		if ok and puesto then N.EmpezarRuta() end
		return
	end
	local Nav = A.Nav
	local near = type(Nav) == "table" and Nav.nearby
	if type(near) == "table" and type(near.Go) == "function" then
		local ok, puesto = pcall(near.Go, tipo)
		if ok and puesto then N.EmpezarRuta() end
		return
	end
	N.Imprimir(L["La búsqueda de lugares cercanos no está lista: falta una parte de Alfa. /alfa diagnostico te dice cuál prender."])
end

-- Las bolsas: las de Alfa se abren desde aquí. Las de Blizzard no: abrirlas
-- desde el código de Alfa las dejaría marcadas y el juego bloquearía usar
-- objetos desde ellas; esas las abre el juego con un clic seguro (K.Seguro)
-- en su botón de la mochila.
local function bolsasAlfa()
	local B = rawget(_G, "AlfaBolsas")
	return type(B) == "table" and type(B.Abrir) == "function" and B or nil
end

local function abrirBolsas()
	if InCombatLockdown and InCombatLockdown() then return end
	local B = bolsasAlfa()
	if B and B.Abrir() then return end
	local tecla = N.Kit.TeclaJuego("bolsas")
	N.Imprimir(tecla and string.format(L["Abre tus bolsas con tu tecla (%s)."], tecla) or L["Abre tus bolsas con su tecla o con el botón de la mochila."])
end

-- Con las bolsas de Alfa encendidas, su clic normal (abrirBolsas); si no,
-- el de la mochila del juego.
local function seguroBolsas()
	local B = bolsasAlfa()
	if B and (type(B.Activas) ~= "function" or B.Activas()) then return nil end
	return N.Kit.AbrirJuego("bolsas")
end

local function entregarTodas()
	local R = rawget(_G, "AlfaRuta")
	if type(R) == "table" and type(R.Entregar) == "function" then
		R.Entregar()
		N.EmpezarRuta()
	end
end

---------------------------------------------------------------------------
-- Lo que mira del juego
---------------------------------------------------------------------------
local RANURAS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }
local function peorDurabilidad()
	if not GetInventoryItemDurability then return nil end
	local peor
	for _, slot in ipairs(RANURAS) do
		local ok, cur, mx = pcall(GetInventoryItemDurability, slot)
		cur, mx = ok and num(cur) or nil, ok and num(mx) or nil
		if cur and mx and mx > 0 then
			local pct = cur / mx * 100
			if not peor or pct < peor then peor = pct end
		end
	end
	return peor
end

local function bolsasLibres()
	local Q = A.QoL
	local Sp = type(Q) == "table" and Q.Space
	if type(Sp) == "table" and type(Sp.Free) == "function" then
		local ok, fr, t = pcall(Sp.Free)
		fr, t = ok and num(fr) or nil, ok and num(t) or nil
		if fr and t and t > 0 then return fr, t end
	end
	local C = C_Container
	if not (C and C.GetContainerNumFreeSlots and C.GetContainerNumSlots) then return nil end
	local fr, t = 0, 0
	for bag = 0, NUM_BAG_SLOTS or 4 do
		local libres, familia = C.GetContainerNumFreeSlots(bag)
		libres, familia = num(libres) or 0, num(familia)
		if not familia or familia == 0 then
			fr = fr + libres
			t = t + (num(C.GetContainerNumSlots(bag)) or 0)
		end
	end
	return fr, t
end

local function porEntrenar()
	local Q = A.QoL
	local Sp = type(Q) == "table" and Q.Spells
	local lv = num(UnitLevel and UnitLevel("player"))
	if type(Sp) ~= "table" or type(Sp.NewAt) ~= "function" or not lv then return 0 end
	local n = 0
	for l = 1, lv do
		local ok, lista = pcall(Sp.NewAt, l)
		if ok and type(lista) == "table" then n = n + #lista end
	end
	return n
end

local function listas()
	local R = rawget(_G, "AlfaRuta")
	if type(R) == "table" and type(R.Listas) == "function" then
		local ok, n = pcall(R.Listas)
		if ok and tonumber(n) then return tonumber(n) end
	end
	local Q = C_QuestLog
	if not (Q and Q.GetNumQuestLogEntries and Q.GetInfo and Q.ReadyForTurnIn) then return 0 end
	local n = 0
	for i = 1, num(Q.GetNumQuestLogEntries()) or 0 do
		local info = Q.GetInfo(i)
		if type(info) == "table" and not info.isHeader and info.questID and Q.ReadyForTurnIn(info.questID) then n = n + 1 end
	end
	return n
end

-- Los consejos según cómo estás ahora; el primero que tenga algo que decir.
-- -> true si habló. pedido: lo pidió el jugador (sin espera ni modo).
local listasDichas = 0
local CONTEXTO = {
	function(c)
		local pct = peorDurabilidad()
		if not pct or pct > 30 then return false end
		-- 1.3.3: una sola voz con Hoy (si ya lo dijo en la sesión, no se repite).
		c.voz = "reparar"
		if not c.pedido and Ce.YaSeDijo(c.voz) then return false end
		c.cara = "atenta"
		c.acciones = { { texto = L["Llévame a reparar"], fn = function() irA("repair") end } }
		return decirDe("reparar", c, floor(pct + 0.5))
	end,
	function(c)
		local fr, t = bolsasLibres()
		if not fr or not t or t <= 0 or fr > 2 then return false end
		c.voz = "bolsasLlenas"
		if not c.pedido and Ce.YaSeDijo(c.voz) then return false end
		c.cara = "atenta"
		c.acciones = { { texto = L["Abrir bolsas"], fn = abrirBolsas, seguro = seguroBolsas },
			{ texto = L["Llévame a un vendedor"], fn = function() irA("vendor") end } }
		return decirDe("bolsas", c, fr)
	end,
	function(c)
		if not (IsResting and si(IsResting())) then return false end
		local d = datos()
		local lv = num(UnitLevel and UnitLevel("player"))
		if not lv or (d.entrenarNivel == lv and not c.pedido) then return false end
		-- 1.3.7: una sola voz: si Talentos, Hoy o el resumen de nivel ya lo dijeron en este nivel, no.
		if not c.pedido and Ce.YaSeDijo("entrenador:" .. lv) then return false end
		local n = porEntrenar()
		if n <= 0 then return false end
		c.cara = "atenta"
		c.acciones = { { texto = L["Llévame con mi entrenador"], fn = function() irA("class") end } }
		local ok = decirDe("entrenar", c, n)
		if ok then d.entrenarNivel = lv Ce.Anotar("entrenador:" .. lv) end
		return ok
	end,
	function(c)
		local n = listas()
		-- 1.2.6: si entregaste, la cuenta baja (antes se quedaba en lo más alto
		-- y no volvía a avisar hasta pasar ese número).
		if n < listasDichas then listasDichas = n end
		if n < 3 or (n <= listasDichas and not c.pedido) then return false end
		c.voz = "entregar"
		if not c.pedido and Ce.YaSeDijo(c.voz) then return false end
		local R = rawget(_G, "AlfaRuta")
		if type(R) == "table" and type(R.Entregar) == "function" then
			c.acciones = { { texto = L["Entregar todas"], fn = entregarTodas } }
		end
		c.cara = "atenta"
		local ok = decirDe("entregar", c, n)
		if ok then listasDichas = n end
		return ok
	end,
}

-- 1.3.9 (41): «¿Qué hago ahora?» Tu siguiente mejor acción, en orden: reparar
-- (lo roto primero), vaciar las bolsas, entregar lo listo, entrenar (lo que
-- ganaste en este nivel) y, si no, seguir tu ruta. Siempre con su botón.
--   Ce.SiguienteAccion() -> { clave, texto, acciones }   Ce.QueHagoAhora() -> bool
function Ce.SiguienteAccion()
	local pct = peorDurabilidad()
	if pct and pct <= 30 then
		return { clave = "reparar", texto = format(L["Primero, a reparar: tu equipo está al %d %%. Roto ya no te protege."], floor(pct + 0.5)),
			acciones = { { texto = L["Llévame a reparar"], fn = function() irA("repair") end } } }
	end
	local fr, t = bolsasLibres()
	if fr and t and t > 0 and fr <= 2 then
		return { clave = "vender", texto = N.Plural(fr, L["Tus bolsas están casi llenas (te queda %d lugar). Vende lo que no usas y sigue."],
				L["Tus bolsas están casi llenas (te quedan %d lugares). Vende lo que no usas y sigue."]),
			acciones = { { texto = L["Llévame a un vendedor"], fn = function() irA("vendor") end },
				{ texto = L["Abrir bolsas"], fn = abrirBolsas, seguro = seguroBolsas } } }
	end
	local n = listas()
	if n > 0 then
		local R = rawget(_G, "AlfaRuta")
		local ac = (type(R) == "table" and type(R.Entregar) == "function") and { { texto = L["Entregar todas"], fn = entregarTodas } } or nil
		return { clave = "entregar", texto = N.Plural(n, L["Tienes %d misión lista: ve a entregarla y cobra tu recompensa."],
			L["Tienes %d misiones listas: ve a entregarlas y cobra tus recompensas."]), acciones = ac }
	end
	local lv = num(UnitLevel and UnitLevel("player"))
	if lv and datos().entrenarNivel ~= lv and not Ce.YaSeDijo("entrenador:" .. lv) and porEntrenar() > 0 then
		return { clave = "entrenar", texto = L["Pasa con tu entrenador: puede que tengas habilidades nuevas por aprender."],
			acciones = { { texto = L["Llévame con mi entrenador"], fn = function() irA("class") end } } }
	end
	-- Lo de siempre: tu ruta (la guía que sigues) o Hoy.
	local I = rawget(_G, "AlfaInicio")
	local paso
	if type(I) == "table" and type(I.Paso) == "function" then
		local ok, p = pcall(I.Paso)
		if ok and type(p) == "table" and not p.fin and type(p.titulo) == "string" and p.titulo ~= "" then paso = p.titulo end
	end
	if paso then
		return { clave = "ruta", texto = format(L["Todo en orden. Sigue tu ruta: %s"], paso),
			acciones = { { texto = L["Ver mi ruta"], fn = function() N.Abrir("rutas") end } } }
	end
	return { clave = "hoy", texto = L["Todo en orden. En Hoy te digo qué te conviene: una ruta, una mazmorra o tus oficios."],
		acciones = { { texto = L["Abrir Hoy"], fn = function() N.Abrir("inicio") end } } }
end

-- Una sola voz con Hoy: lo que Lya ya dijo no lo repite otro (1.3.3).
local VOZ_AHORA = { reparar = "reparar", vender = "bolsasLlenas", entregar = "entregar" }
function Ce.QueHagoAhora()
	if not Ce.Activa() or enCombate() then return false end
	local ok, s = pcall(Ce.SiguienteAccion)
	if not ok or type(s) ~= "table" then
		if not ok and geterrorhandler then geterrorhandler()(s) end
		return false
	end
	return Ce.Decir({ texto = s.texto, acciones = s.acciones, pedido = true, cara = "atenta", voz = VOZ_AHORA[s.clave] }) == true
end

local function revisarContexto(pedido)
	for _, fn in ipairs(CONTEXTO) do
		local ok, hablo = pcall(fn, { pedido = pedido })
		if not ok and geterrorhandler then geterrorhandler()(hablo) end
		if ok and hablo then return true end
	end
	return false
end

-- Un "¿Sabías que…?" que aplique a este personaje: id, datos.
local function sabias()
	local mejor, mejorN
	local lista = M.SABIAS
	local inicio = random(#lista)
	for k = 0, #lista - 1 do
		local i = (inicio + k - 1) % #lista + 1
		local s = lista[i]
		local n = veces("sabias" .. i)
		local ok, sirve = pcall(s.cond)
		if ok and sirve and n < MAX_VECES and (not mejorN or n < mejorN) then mejor, mejorN = i, n end
	end
	if not mejor then return nil end
	return "sabias" .. mejor, lista[mejor]
end

local function decirSabias(c)
	local id, s = sabias()
	if not id then return false end
	c.id, c.texto = id, L[s.t]
	if s.accion then
		local fn = s.accion[2]
		c.acciones = { { texto = L[s.accion[1]], fn = fn } }
	end
	return Ce.Decir(c)
end

-- Un consejo suelto: rota entre lo de Alfa, el juego y el ánimo (y rara vez cariño).
local function suelto(pedido)
	local d = datos()
	if random() < 0.12 and decirDe("carino", { pedido = pedido, salto = true }) then return true end
	local orden = { "sabias", "consejo", "animo" }
	d.giro = ((tonumber(d.giro) or 0) % #orden) + 1
	for k = 0, #orden - 1 do
		local cat = orden[(d.giro + k - 1) % #orden + 1]
		local c = { pedido = pedido }
		local ok
		if cat == "sabias" then ok = decirSabias(c) else ok = decirDe(cat, c) end
		if ok then return true end
	end
	return false
end

-- Algo del momento (nunca se agota): que tiene hambre o se le antoja algo
-- (se sienta a pedir), un comentario de la zona donde están o uno suelto.
local function zonaActual()
	local z = GetSubZoneText and GetSubZoneText() or ""
	if (z or "") == "" and GetZoneText then z = GetZoneText() end
	if type(z) ~= "string" or (issecretvalue and issecretvalue(z)) then return "" end
	return z
end
local function delMomento()
	local r = random()
	if r < 0.25 and decirDe("hambre", { pose = "pedir" }) then return true end
	if r < 0.4 and decirDe("salchichas", { pose = "pedir" }) then return true end
	local z = zonaActual()
	if r < 0.6 and z ~= "" and decirDe("zona", {}, z) then return true end
	return decirDe("ambiente", {})
end
-- Para la plática (Charla.lua): algo del momento y un consejo de los de siempre.
Ce.DelMomento = delMomento
Ce.Suelto = suelto

-- El saludo al entrar, según la hora (y a veces uno de los de siempre).
local function saludar(nombre)
	local h = tonumber(date and date("%H")) or 12
	local cat = (h >= 5 and h < 12 and "saludoManana") or (h >= 12 and h < 19 and "saludoTarde") or (h < 5 and "saludoMadrugada") or "saludoNoche"
	if random() < 0.35 then cat = "bienvenida" end
	return decirDe(cat, { salto = true }, nombre)
end

-- Clic en Lya o /alfa lya consejo.
-- (1.3.3) «¿Qué hay de nuevo?»: lo que guardó mientras entrabas, una cosa a
-- la vez, con su botón. `solo`: sin el botón de la siguiente (el latido).
function Ce.QueHayDeNuevo(solo)
	local x = Ce.AlEntrar()[1]
	if not x then return false end
	local c = guardadas[x.id]
	Ce.OlvidarAlEntrar(x.id)
	local texto = x.texto or ""
	if x.origen ~= "lya" and type(x.titulo) == "string" and x.titulo ~= "" then
		texto = texto ~= "" and (x.titulo .. ". " .. texto) or x.titulo
	end
	if texto == "" then return Ce.QueHayDeNuevo(solo) end
	local acciones = {}
	local a = c and type(c.acciones) == "table" and c.acciones[1]
	if a then acciones[1] = a
	elseif type(x.accion) == "table" and type(x.accion.alClic) == "function" then
		acciones[1] = { texto = x.accion.texto, fn = x.accion.alClic }
	end
	local resto = #Ce.AlEntrar()
	if resto > 0 and not solo then
		acciones[#acciones + 1] = { texto = format(L["¿Qué hay de nuevo? (%d)"], resto), fn = function() Ce.QueHayDeNuevo() end }
	end
	return Ce.Decir({ texto = texto, pedido = true, lineas = 5, ancho = 360, cara = "atenta",
		acciones = #acciones > 0 and acciones or nil, voz = c and c.voz }) == true
end

function Ce.Pedir()
	if not Ce.Activa() then return end
	if enCombate() then return end
	-- 1.3.3: lo que guardó al entrar va primero.
	local n = #Ce.AlEntrar()
	if n > 0 then
		Ce.Decir({ texto = n == 1 and L["Mientras entrabas te guardé una cosa."] or format(L["Mientras entrabas te guardé %d cosas."], n),
			pedido = true, cara = "feliz", salto = true,
			acciones = { { texto = format(L["¿Qué hay de nuevo? (%d)"], n), fn = function() Ce.QueHayDeNuevo() end },
				{ texto = L["Luego"], fn = function() UI.Callar() end } } })
		return
	end
	if revisarContexto(true) then return end
	-- A veces, en vez de un consejo, algo de la plática (lore, tu gente, un consejo de amiga).
	local Ch = M.Charla
	local function platica()
		if not (Ch and Ch.Pedido) then return false end
		local ok, h = pcall(Ch.Pedido)
		return ok and h == true
	end
	if random() < 0.4 and platica() then return end
	if suelto(true) then return end
	if platica() then return end
	Ce.Decir({ texto = L[M.AGOTADOS], pedido = true,
		acciones = { { texto = L["Volver a empezar"], fn = function() Ce.OlvidarVistos() end } } })
end

---------------------------------------------------------------------------
-- Ajustes de bolsillo (el menú)
---------------------------------------------------------------------------
function Ce.Silenciar(on)
	datos().silencio = on and (reloj() + 3600) or nil
	if on then
		UI.Callar()
		N.Imprimir(L["Lya se queda calladita una hora. Aquí sigue, cuidándote."])
	else
		N.Imprimir(L["Lya vuelve a hablar."])
	end
	M.Avisar()
end

function Ce.OlvidarVistos()
	datos().vistos = {}
	N.Imprimir(L["Lya vuelve a contarte sus consejos desde el principio."])
	M.Avisar()
end

function Ce.Mostrar(on)
	N.Set(ID, "mostrar", on ~= false)
end

function Ce.Vistos()
	local n, total = 0, 0
	local vistos = datos().vistos
	for _, v in pairs(vistos) do if tonumber(v) and v >= MAX_VECES then n = n + 1 end end
	for cat, lista in pairs(F) do if type(lista) == "table" then total = total + #lista end end
	total = total + #M.SABIAS
	return n, total
end

---------------------------------------------------------------------------
-- Sueño: ausente, o descansando un rato sin nada que hacer
---------------------------------------------------------------------------
local descansoDesde

local function revisarSueno()
	if not UI.Visible() then return end
	local afk = UnitIsAFK and si(UnitIsAFK("player"))
	local descansando = IsResting and si(IsResting())
	if descansando then descansoDesde = descansoDesde or ahora() else descansoDesde = nil end
	local dormir = afk or (descansando and not enCombate() and ahora() - descansoDesde >= DORMIR_DESCANSANDO and not UI.Hablando())
	UI.Dormir(dormir)
end

---------------------------------------------------------------------------
-- El latido (solo con Lya a la vista): sueño, sesión larga y un consejo
-- suelto tras un buen rato sin hablar.
---------------------------------------------------------------------------
local function revisarSesion()
	local d = datos()
	d.ultimaVez = reloj()
	-- 1.3.8: la pausa por tramos (Pausa.lua) y la hora del día (HoraReal.lua).
	if M.Pausa then
		if M.Pausa.Revisar() then return true end
		return M.HoraReal and M.HoraReal.Revisar() or false
	end
	local inicio = tonumber(d.sesionInicio)
	if not inicio then return false end
	local dur = reloj() - inicio
	local dichos = tonumber(d.sesionAvisos) or 0
	local umbral = (dichos == 0 and 2 * 3600) or (dichos == 1 and 4 * 3600) or nil
	if not umbral or dur < umbral then return false end
	local ok = decirDe("descanso", { cara = "normal" }, N.Duracion(dur))
	if ok then d.sesionAvisos = dichos + 1 end
	return ok
end

local function latido()
	if not UI.Visible() then N.Quitar("lya.latido") return end
	-- 1.3.3: pasada la entrada, lo que guardó lo dice una vez, uno por latido.
	if not Ce.Entrando() and Ce.AlEntrar()[1] and not enCombate() and not UI.Hablando() and not Ce.Silenciada()
		and not (UI.Dormida and UI.Dormida()) then
		if Ce.QueHayDeNuevo(true) then return end
	end
	revisarSueno()
	if not UI.Dormida() and not enCombate() then
		if not revisarSesion() and not revisarContexto(false) then
			local gap = SIN_HABLAR[Ce.Frecuencia()]
			if gap and M.HoraReal then gap = M.HoraReal.Espera(gap) end -- 1.3.8: de noche, más tranquila
			if gap and Ce.Novato() then gap = gap * NOVATO_VECES end -- 1.3.9 (69)
			if gap and ahora() - ultimo >= gap then
				-- La plática (Charla.lua): rondas entre el lugar, el lore, lo de tu
				-- raza, clase y profesiones, consejos, el momento y las salchichas.
				-- Sin ella, lo de antes: un dato curioso, algo del momento o un consejo.
				local Ch = M.Charla
				if Ch and Ch.Algo then
					local ok, h = pcall(Ch.Algo)
					if not ok and geterrorhandler then geterrorhandler()(h) end
				else
					local hablo = false
					local Hi = M.Historias
					if random() < 0.65 and Hi and Hi.Suelto then
						local ok, h = pcall(Hi.Suelto)
						hablo = ok and h
					end
					if not hablo then hablo = delMomento() end
					if not hablo then hablo = suelto(false) end
					if not hablo then delMomento() end
				end
			elseif not UI.Hablando() and random() < 0.5 then
				-- Entre globos, un gesto sin palabras (y a veces una pose: correr,
				-- buscarse la cola, sentarse a pedir).
				if UI.Pose and random() < 0.5 then UI.Pose() else UI.Gesto() end
			end
		end
	end
end

-- 1.3.1: en el reloj del núcleo («lya.latido»), solo con Lya a la vista.
Ce.Latido = latido -- (para el banco)
local function arrancarLatido() N.Cada("lya.latido", 60, latido) end

---------------------------------------------------------------------------
-- Mostrar / ocultar
---------------------------------------------------------------------------
local presentarPendiente = false

local function presentarse()
	local d = datos()
	if d.presentada or not UI.Visible() then return false end
	return Ce.Decir({ id = "presentacion1", texto = L[F.presentacion[1]], importante = true, salto = true, segundos = 12,
		alDecir = function() datos().presentada = true end })
end

function Ce.Aplicar()
	local antes = UI.Visible()
	UI.Aplicar()
	local ahoraVisible = UI.Visible()
	if ahoraVisible and not antes then
		arrancarLatido()
		UI.Combate(enCombate())
		revisarSueno()
		if presentarPendiente then
			presentarPendiente = false
			K.Despues(3, presentarse)
		end
	elseif not ahoraVisible then
		N.Quitar("lya.latido")
	end
	M.Avisar()
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local function juntar(espera, fn)
	local pendiente = false
	return function()
		if pendiente then return end
		pendiente = true
		A.After(espera, function()
			pendiente = false
			fn()
		end)
	end
end

local entrado = false

-- La llegada (1.2.1): al entrar al juego (no al recargar), Lya espera a que
-- termine la intro del lobo (ALFA_INTRO_FIN, de Alfa_Bienvenida) y llega
-- corriendo a su lugar a decirte que te extrañó. Sin intro, llega sola a los
-- 9 s; si algo la detiene, a los 30 s como mucho. lya.llegar = false la apaga.
local llegada = { pendiente = false, saludo = nil }

local function introVisible()
	local intro = rawget(_G, "AlfaIntro")
	return type(intro) == "table" and intro.IsShown and intro:IsShown() or false
end

local function llegar()
	if not llegada.pendiente then return end
	llegada.pendiente = false
	local saludo = llegada.saludo
	llegada.saludo = nil
	if not UI.Llegar(saludo) and saludo then saludo() end
end

A.On("ALFA_INTRO_FIN", function()
	if llegada.pendiente then K.Despues(0.15, llegar) end
end)

A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, esLogin, esRecarga)
	reintentar()
	if entrado then return end
	entrado = true
	local d = datos()
	local antes = tonumber(d.ultimaVez)
	-- La sesión: empieza al entrar al juego (una recarga la conserva).
	if esLogin == true or not tonumber(d.sesionInicio) or (antes and reloj() - antes > 900) then
		d.sesionInicio, d.sesionAvisos = reloj(), 0
	end
	Ce.Aplicar()
	local function nombreJugador()
		local nombre = UnitName and UnitName("player") or ""
		if issecretvalue and issecretvalue(nombre) then nombre = "" end
		return nombre
	end
	local function saludoDeEntrada()
		local nombre = nombreJugador()
		if antes and reloj() - antes > 3 * 86400 then
			decirDe("volver", { salto = true, acciones = N.ModuloPorId("inicio") and { { texto = L["Abrir Hoy"], fn = function() N.Abrir("inicio") end } } or nil }, nombre)
		elseif llegada.corrio then
			local cat = M.HoraReal and M.HoraReal.Llegada() or "llegada" -- 1.3.8: según tu hora
			if not decirDe(cat, { cara = "atenta" }, nombre) and cat ~= "llegada" then decirDe("llegada", { cara = "atenta" }, nombre) end
		else
			saludar(nombre)
		end
	end
	-- Ya presentada y a la vista: llega corriendo cuando termina la intro.
	if esLogin == true and d.presentada and N.Get(ID, "llegar") ~= false and UI.EsperarLlegada() then
		llegada.pendiente = true
		llegada.saludo = function()
			llegada.corrio = true
			llegada.saludada = true
			saludoDeEntrada()
		end
		A.After(9, function() if llegada.pendiente and not introVisible() then llegar() end end)
		A.After(30, llegar)
	end
	-- Después de los avisos del motor y de Hoy al entrar.
	A.After(18, function()
		if not d.presentada then
			if UI.Visible() then presentarse() else presentarPendiente = true end
			return
		end
		if esLogin ~= true then return end
		-- la llegada saluda ella misma (ya saludó o saluda en cuanto llegue)
		if llegada.saludada or llegada.pendiente then return end
		saludoDeEntrada()
	end)
end)

-- Terminó la bienvenida de Alfa: Lya aparece y se presenta.
A.On("ALFA_CONFIGURADO", function()
	presentarPendiente = not datos().presentada
	Ce.Aplicar()
end)
A.On("WELCOME_CLOSED", function() Ce.Aplicar() end)

A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" then return end
	if path == ID .. ".mostrar" or path == ID or path == "" then Ce.Aplicar()
	elseif path:sub(1, #ID + 1) == ID .. "." then M.Avisar() end
end)

-- Subir de nivel: aúlla; los niveles especiales traen su consejo.
local HITOS = {
	[10] = function() return N.ModuloPorId("builds") and { { texto = L["Ver Talentos"], fn = function() N.Abrir("builds") end } } or nil end,
	[20] = function() return N.ModuloPorId("mazmorras") and { { texto = L["Ver Mazmorras"], fn = function() N.Abrir("mazmorras") end } } or nil end,
	[30] = function() return nil end,
	[40] = function()
		local E = rawget(_G, "AlfaEnciclopedia")
		if type(E) == "table" and type(E.Abrir) == "function" then
			return { { texto = L["Cómo conseguirla"], fn = function() E.Abrir("guia", "montura") end } }
		end
	end,
	[50] = function() return nil end,
	[60] = function() return nil end,
}
-- 1.3.7 (33, 36): Lya aúlla después de la animación del juego (N.AlLibre,
-- Alfa_Nucleo/Momentos.lua), y el festejo de racha (dos niveles en 30 min)
-- reemplaza al aullido de siempre en vez de sumarse.
local function alSubir(nivel, racha)
	local Mo = M.Momentos
	if racha and Mo and Mo.Festejar and Mo.Festejar(nivel) then return end
	local c = { importante = true, aullar = true, segundos = 10 }
	if HITOS[nivel] then
		c.acciones = HITOS[nivel]()
		if decirDe("hito" .. nivel, c) then return end
	end
	decirDe("nivel", { importante = true, aullar = true }, nivel)
end
A.RegisterEvent("PLAYER_LEVEL_UP", function(_, nivel)
	nivel = num(nivel)
	if not nivel then return end
	local Mo = M.Momentos
	local racha = Mo and Mo.AlSubir and Mo.AlSubir(nivel) or false -- la racha se cuenta al momento
	if N.AlLibre then N.AlLibre("lya.nivel", function() alSubir(nivel, racha) end, 2, { tipo = "lya", caduca = 60 }) else alSubir(nivel, racha) end
end)

A.RegisterEvent("PLAYER_DEAD", function()
	decirDe("muerte", { importante = true, cara = "atenta", segundos = 10 })
end)

-- Misiones entregadas hoy: 10 y 25 son un logro.
A.RegisterEvent("QUEST_TURNED_IN", function()
	local d = datos()
	local hoy = date and date("%Y-%m-%d") or "?"
	if type(d.hoy) ~= "table" or d.hoy.fecha ~= hoy then d.hoy = { fecha = hoy, n = 0 } end
	d.hoy.n = (tonumber(d.hoy.n) or 0) + 1
	if d.hoy.n == 10 or d.hoy.n == 25 then
		decirDe("misionesHoy", { importante = true, salto = true }, d.hoy.n)
	end
end)

local revisarPronto = juntar(3, function()
	if UI.Visible() and not enCombate() then revisarContexto(false) end
end)
A.RegisterEvent("UPDATE_INVENTORY_DURABILITY", revisarPronto)
A.RegisterEvent("BAG_UPDATE_DELAYED", revisarPronto)
A.RegisterEvent("QUEST_LOG_UPDATE", revisarPronto)
A.RegisterEvent("PLAYER_UPDATE_RESTING", function()
	revisarSueno()
	revisarPronto()
end)
A.RegisterEvent("PLAYER_FLAGS_CHANGED", function(_, unit)
	if unit == nil or (not (issecretvalue and issecretvalue(unit)) and unit == "player") then revisarSueno() end
end)

A.RegisterEvent("PLAYER_REGEN_DISABLED", function()
	UI.Combate(true)
	UI.Dormir(false)
end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	UI.Combate(false)
	A.After(1, reintentar)
end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() A.After(2, reintentar) end)
A.RegisterEvent("PLAYER_LOGOUT", function() datos().ultimaVez = reloj() end)

---------------------------------------------------------------------------
-- Comando
---------------------------------------------------------------------------
local function comando(resto)
	local palabra = type(resto) == "string" and resto:lower():match("^%s*(%S*)") or ""
	if not N.Permitido() then return end
	if palabra == "consejo" then
		if not Ce.Activa() then Ce.Mostrar(true) end
		Ce.Pedir()
	elseif palabra == "ajustes" then
		N.Abrir(ID)
	elseif palabra == "ayuda" and M.Guia then
		M.Guia.Abrir()
	elseif palabra == "historial" or palabra == "dijiste" then
		if M.Guia then M.Guia.Abrir(nil, nil, true) end
		elseif palabra == "historia" then
			N.Abrir(ID)
	elseif palabra == "semana" then
		if not Ce.Activa() then Ce.Mostrar(true) end
		if M.Dia then M.Dia.ContarSemana() end
	elseif palabra == "dia" or palabra == "día" then
		if not Ce.Activa() then Ce.Mostrar(true) end
		if M.Dia then M.Dia.Contar() end
	elseif palabra == "historias" and M.Historias then
		M.Historias.Abrir()
	elseif palabra == "importante" or palabra == "importantes" then
		-- 1.4.0 (64): solo lo importante (otra vez: como estaba).
		local si = Ce.AlternarImportante()
		N.Imprimir(si and L["Listo: solo te digo lo importante. Con el mismo clic vuelvo a platicar."] or L["¡De vuelta! Te cuento todo otra vez."])
	elseif palabra == "temporada" and M.Temporada then
		M.Temporada.Abrir()
	elseif (palabra == "recuerdo" or palabra == "recuerdos") and M.Recuerdos then
		if not Ce.Activa() then Ce.Mostrar(true) end
		M.Recuerdos.Contar(true)
	elseif palabra == "dato" and M.Historias then
		if not Ce.Activa() then Ce.Mostrar(true) end
		M.Historias.Contar()
	else
		local mostrar = N.Get(ID, "mostrar") == false
		Ce.Mostrar(mostrar)
		if mostrar then
			N.Imprimir(L["Lya volvió. Dale clic cuando quieras un consejo."])
			K.Despues(0.3, function() UI.Saltar() end)
		else
			N.Imprimir(L["Lya se fue a descansar. Vuelve con /alfa lya."])
		end
	end
end
A.RegisterCommand("lya", comando, L["muestra u oculta a Lya, tu loba compañera (también: ayuda, dia, semana, historia, historial, consejo, dato, historias, importante, recuerdo, temporada, ajustes)"])
A.RegisterCommand("lobito", comando, L["lo mismo que /alfa lya"], true)

---------------------------------------------------------------------------
-- Lo que usan los demás módulos
--   AlfaLya.Decir(texto, { importante = true, accion = { texto, fn }, id = "mio1" })
--   AlfaLya.Mostrar(si)   AlfaLya.Consejo()   AlfaLya.Visible()   AlfaLya.Recuerdo()
---------------------------------------------------------------------------
-- 1.2.5: los avisos pequeños de Alfa (K.Aviso) los dice Lya cuando está a la
-- vista, para que no salgan mensajes por todos lados. Si está oculta,
-- silenciada, en combate o hablando de algo importante, sale el aviso de
-- siempre. lya.avisos lo apaga.
local function unir(titulo, texto)
	titulo = type(titulo) == "string" and titulo or ""
	texto = type(texto) == "string" and texto or ""
	if titulo == "" then return texto end
	if texto == "" then return titulo end
	if titulo:find("[%.!?:…]$") then return titulo .. " " .. texto end
	return titulo .. ". " .. texto
end
local dichosAviso = {} -- texto -> cuándo lo dijo
K.AvisoPorLya = function(o)
	if N.Get(ID, "avisos") == false or Ce.Silenciada() then return false end
	if not (Ce.Activa() and UI.Visible()) or enCombate() then return false end
	-- 1.3.7: mientras el juego hace lo suyo (nivel, carga, cinemática) o con No
	-- molestar, el aviso sigue su camino (K.Aviso lo hace esperar o lo guarda).
	if N.Ocupado and N.Ocupado("lya", o.importante and 2 or 3) and not o.pedido then return false end
	-- 1.2.9: en el modo foco los avisos salen como siempre (Lya está chiquita).
	if UI.EnFoco and UI.EnFoco() then return false end
	local t = unir(o.titulo, o.texto)
	if t == "" then return false end
	-- El mismo aviso dentro de 90 s: ya lo dijo (no se repite ni sale arriba).
	local ya = dichosAviso[t]
	if ya and ahora() - ya < 90 then return true end
	-- 1.3.1: nunca encima de lo importante ni de un globo con botones: sale el aviso de siempre.
	local a = UI.Actual and UI.Actual()
	if type(a) == "table" and (a.importante or (type(a.acciones) == "table" and #a.acciones > 0)) then return false end
	local acciones
	local ac = o.accion
	if type(ac) == "table" and type(ac.texto) == "string" and ac.texto ~= "" then
		acciones = { { texto = ac.texto, fn = function() K.Llamar(ac.alClic) end } }
	elseif type(o.acciones) == "table" then
		-- (los avisos de Hoy: { { texto, fn }, ... }, hasta dos)
		for _, b in ipairs(o.acciones) do if type(b) == "table" and b.seguro then return false end end
		acciones = {}
		for i = 1, math.min(2, #o.acciones) do
			local b = o.acciones[i]
			if type(b) == "table" and type(b.texto) == "string" and type(b.fn) == "function" and not b.seguro then
				acciones[#acciones + 1] = { texto = b.texto, fn = b.fn }
			end
		end
		if #acciones == 0 then acciones = nil end
	end
	local dijo = Ce.Decir({ texto = t, pedido = true, acciones = acciones, lineas = 5, ancho = 360,
		cara = acciones and "atenta" or nil, segundos = tonumber(o.duracion) }) == true
	if dijo then
		-- (1.3.2) Lo de hace más de 90 s ya no frena: se olvida (cada aviso con
		-- un nombre o un número es un texto nuevo y la tabla crecía sin fin).
		local t0 = ahora()
		for k, cuando in pairs(dichosAviso) do
			if t0 - cuando >= 90 then dichosAviso[k] = nil end
		end
		dichosAviso[t] = t0
	end
	return dijo
end
-- Para el banco: cuántos avisos recuerda (1.3.2).
function Ce.AvisosRecordados()
	local n = 0
	for _ in pairs(dichosAviso) do n = n + 1 end
	return n
end

-- Para la guía (Guia.lua, 1.2.4): lo que Lya mira del juego.
Ce.PeorDurabilidad, Ce.BolsasLibres, Ce.EntregarTodas, Ce.AbrirBolsas = peorDurabilidad, bolsasLibres, entregarTodas, abrirBolsas

local API = type(AlfaLya) == "table" and AlfaLya or {}
AlfaLya = API
AlfaLobito = API
API.version = 1

function API.Decir(texto, opts)
	opts = type(opts) == "table" and opts or {}
	if type(texto) ~= "string" then return false end
	local acciones
	if type(opts.accion) == "table" then
		local a = opts.accion
		acciones = { { texto = a.texto or a[1], fn = a.fn or a[2] } }
	elseif type(opts.acciones) == "table" then
		acciones = opts.acciones
	end
	return Ce.Decir({
		texto = texto, importante = opts.importante and true or nil, acciones = acciones,
		id = type(opts.id) == "string" and ("otro:" .. opts.id) or nil,
		salto = opts.salto, cara = opts.cara, aullar = opts.aullar,
	})
end
function API.Mostrar(on) Ce.Mostrar(on ~= false) end
function API.Consejo() Ce.Pedir() end
-- 1.2.7: un dato curioso de una zona (para la ficha de la Enciclopedia), o nil.
-- Uno al azar de los que sabe de esa zona (Lore.lua).
function API.DatoDeZona(mapID)
	local lista = M.DATOS_ZONA and M.DATOS_ZONA[tonumber(mapID) or -1]
	if type(lista) ~= "table" or #lista == 0 then return nil end
	return L[lista[random(#lista)]]
end
-- La tecla de su botón (1.2.6).
function API.Responder() return UI.Responder() end
function API.Visible() return UI.Visible() end
-- 1.3.8: lo último que dijo Lya (el panel de Lya del Escritorio de Alfa):
-- una copia, lo más nuevo primero: { { texto, hora }, ... }.
function API.Historial(n)
	local out = {}
	for i, h in ipairs(Ce.historial or {}) do
		if n and i > n then break end
		if type(h) == "table" and type(h.texto) == "string" then out[#out + 1] = { texto = h.texto, hora = h.hora } end
	end
	return out
end
-- El recuerdo de Lya (para una línea en otra página): titulo, texto, pie.
function API.Recuerdo() return L[M.RECUERDO_TITULO], L[M.RECUERDO], L[M.RECUERDO_PIE] end
