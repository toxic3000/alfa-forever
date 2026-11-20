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

local function intervalo()
	local m = tonumber(N.Get(ID, "minutos")) or 5
	if Ce.Frecuencia() == "pocos" then m = m * 2 end
	return max(1, m) * 60
end

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
	-- 1.2.9: en el modo foco (Foco.lua) se calla; lo importante y lo que pides, sí.
	if UI.EnFoco and UI.EnFoco() and not c.importante and not c.pedido and not c.enMazmorra then return "foco" end
	if not c.importante and not c.pedido then
		if UI.Hablando() or avisoDeHoy() then return "ocupada" end
		if ahora() - ultimo < intervalo() then return "pronto" end
	end
	return nil
end

local function reintentar()
	if not espera then return end
	if ahora() > espera.hasta then espera = nil return end
	if escribiendo() and not enCombate() and (not enInstancia() or espera.c.enMazmorra) and not reintento then -- 1.2.7
		reintento = K.Despues(4, function() reintento = nil reintentar() end)
		return
	end
	local c = espera.c
	if motivo(c) == "esperar" then return end
	espera = nil
	Ce.Decir(c)
end

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
	local por = motivo(c)
	if por == "esperar" and c.importante then
		espera = { c = c, hasta = ahora() + ESPERA_IMPORTANTE }
		reintentar()
		return "espera", por -- verdadero: ya lo dirá en cuanto se pueda
	end
	if por then return false, por end
	-- 1.3.1: lo importante no pisa lo importante: a la cola.
	if c.importante and not c.pedido and hablaImportante() then
		if #cola < MAX_COLA then cola[#cola + 1] = { c = c, hasta = ahora() + ESPERA_IMPORTANTE } end
		N.Una("lya.cola", 3, sacarCola) -- por si acaso: lo normal es al callarse
		return "espera", "cola"
	end
	if c.id then contar(c.id) end
	ultimo = ahora()
	-- 1.2.6: lo que dijo, por si el globo se fue antes de leerlo.
	table.insert(Ce.historial, 1, { texto = c.texto, acciones = c.acciones, hora = date and date("%H:%M") or "" })
	while #Ce.historial > HISTORIAL do table.remove(Ce.historial) end
	UI.Hablar(c)
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
	N.Imprimir(L["La búsqueda de lugares cercanos no está disponible."])
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
		c.cara = "atenta"
		c.acciones = { { texto = L["Llévame a reparar"], fn = function() irA("repair") end } }
		return decirDe("reparar", c, floor(pct + 0.5))
	end,
	function(c)
		local fr, t = bolsasLibres()
		if not fr or not t or t <= 0 or fr > 2 then return false end
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
		local n = porEntrenar()
		if n <= 0 then return false end
		c.cara = "atenta"
		c.acciones = { { texto = L["Llévame con mi entrenador"], fn = function() irA("class") end } }
		local ok = decirDe("entrenar", c, n)
		if ok then d.entrenarNivel = lv end
		return ok
	end,
	function(c)
		local n = listas()
		-- 1.2.6: si entregaste, la cuenta baja (antes se quedaba en lo más alto
		-- y no volvía a avisar hasta pasar ese número).
		if n < listasDichas then listasDichas = n end
		if n < 3 or (n <= listasDichas and not c.pedido) then return false end
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
	local cat = (h >= 5 and h < 12 and "saludoManana") or (h >= 12 and h < 19 and "saludoTarde") or "saludoNoche"
	if random() < 0.35 then cat = "bienvenida" end
	return decirDe(cat, { salto = true }, nombre)
end

-- Clic en Lya o /alfa lya consejo.
function Ce.Pedir()
	if not Ce.Activa() then return end
	if enCombate() then return end
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
	revisarSueno()
	if not UI.Dormida() and not enCombate() then
		if not revisarSesion() and not revisarContexto(false) then
			local gap = SIN_HABLAR[Ce.Frecuencia()]
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
			decirDe("llegada", { cara = "atenta" }, nombre)
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
A.RegisterEvent("PLAYER_LEVEL_UP", function(_, nivel)
	nivel = num(nivel)
	if not nivel then return end
	local c = { importante = true, aullar = true, segundos = 10 }
	if HITOS[nivel] then
		c.acciones = HITOS[nivel]()
		if decirDe("hito" .. nivel, c) then return end
	end
	decirDe("nivel", { importante = true, aullar = true }, nivel)
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
A.RegisterCommand("lya", comando, L["muestra u oculta a Lya, tu loba compañera (también: ayuda, dia, semana, historia, historial, consejo, dato, historias, ajustes)"])
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
	if dijo then dichosAviso[t] = ahora() end
	return dijo
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
-- El recuerdo de Lya (para una línea en otra página): titulo, texto, pie.
function API.Recuerdo() return L[M.RECUERDO_TITULO], L[M.RECUERDO], L[M.RECUERDO_PIE] end
