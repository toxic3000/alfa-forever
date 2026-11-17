-- Alfa - La Jauría: los mensajes entre los Alfa de la manada.
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Mensajes de addon ocultos con el prefijo propio "AlfaManada". Solo hablan
-- quienes aceptaron compartir su ubicación con La Jauría (manada.compartir):
-- quien no comparte no envía ni recibe nada (y su grupo se sigue viendo con
-- la API del juego).
--
-- Por dónde (R.Via):
--   "canal"      el canal oculto de Alfa (Canal.lua): todos los Alfa que
--                comparten, estén o no en tu grupo o tu hermandad
--   "hermandad"  si el canal no está (el juego no dejó entrar, o todavía no
--                entramos), la hermandad, y solo se ve a quien usa Alfa y
--                comparte
-- Nunca canales públicos del juego. Nada sale dentro de instancias, con el
-- bloqueo de mensajes del juego ni desde una cuenta de prueba.
--
-- Mensajes (versión 1, campos separados por "|"):
--   1H|<versión>|1                       "estoy aquí": al entrar al canal
--   1P|<mapa>|<x>|<y>|<nivel>|<CLASE>    dónde estás (x, y en 0-100 del mapa)
--   1X                                   dejé de compartir: borra mi pin
--   1J|<versión>, 1K|<versión>           "Quiero unirme" (susurro a un oficial
--                                        del clan, solo al pulsar el botón)
-- La 0.1.0 también mandaba 1Y (respuesta al saludo): se acepta y se ignora.
--
-- La posición sale cada ENVIO segundos como mínimo y solo si te moviste más
-- de MOVER yardas; quieto, una vez cada REFRESCO para que tu pin no caduque.
-- A un saludo se responde con la posición, tras una espera al azar y como
-- mucho una vez cada RESP_HUECO (no todos a la vez, no más de una vez).
--
-- Todo envío pasa por una cola: como mucho TOPE mensajes por segundo (con
-- una ráfaga de RAFAGA), y un mensaje nuevo del mismo tipo reemplaza al que
-- esperaba (una posición vieja nunca sale después de una nueva). Si el
-- servidor frena (AddonMessageThrottle, ChannelThrottle), la cola espera
-- FRENO segundos y lo vuelve a intentar.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U = M.U
local ID = M.ID

local R = {}
M.Red = R

R.PREFIJO = "AlfaManada"
local V = "1"
local TOPE, RAFAGA = 1, 3
local FRENO = 3
local ENVIO, REFRESCO, MOVER = 10, 240, 10
local RESP_HUECO = 30      -- segundos entre dos respuestas a saludos
local RESP_AZAR = { 2, 8 } -- espera al azar antes de responder
local OFICIAL_ESPERA = 5   -- segundos esperando que un oficial responda

local RES = Enum and Enum.SendAddonMessageResult
local EXITO = RES and RES.Success or 0
local FRENOS = {
	[RES and RES.AddonMessageThrottle or 3] = true,
	[RES and RES.ChannelThrottle or 8] = true,
}
local BLOQUEO = RES and RES.AddOnMessageLockdown or 11
local CANAL_MALO = RES and RES.InvalidChannel or 7

local function version() return (tostring(A.version or "dev"):gsub("|", "")) end
local function on(clave) return N.Get(ID, clave) and true or false end

---------------------------------------------------------------------------
-- Estado de envío
---------------------------------------------------------------------------

R.diag = { enviados = 0, frenados = 0, recibidos = 0 }

-- Si se puede enviar ahora: true, o false y la razón (para la página).
-- `despedida`: el último aviso "dejé de compartir" sale aunque compartir se
-- acabe de apagar.
function R.PuedeEnviar(despedida)
	if not despedida and not on("compartir") then return false, "apagado" end
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false, "sinapi" end
	if U.CuentaDePrueba() then return false, "prueba" end
	if U.EnInstancia() then return false, "instancia" end
	if C_ChatInfo.InChatMessagingLockdown then
		local ok, bloqueado = pcall(C_ChatInfo.InChatMessagingLockdown)
		if ok and U.Leer(bloqueado) == true then return false, "bloqueo" end
	end
	return true
end

-- Por dónde sale lo que se difunde: "canal", número | "hermandad" | nil, por qué.
function R.Via()
	local C = M.Canal
	local id = C.Listo() and C.Id()
	if id then return "canal", id end
	if U.EnHermandad() then return "hermandad" end
	local estado = C.Estado()
	if estado == "entrando" or estado == "esperando" then return nil, "entrando" end
	return nil, "sinvia"
end

local prefijoListo = false
function R.Prefijo()
	if prefijoListo or not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
	local esta = C_ChatInfo.IsAddonMessagePrefixRegistered
	if esta and esta(R.PREFIJO) then prefijoListo = true return end
	local ok, r = pcall(C_ChatInfo.RegisterAddonMessagePrefix, R.PREFIJO)
	R.diag.prefijo = ok and r or "error"
	-- Listo solo si de verdad quedó registrado: si no, se reintenta la próxima vez.
	if esta then prefijoListo = esta(R.PREFIJO) and true or false
	else prefijoListo = ok and r ~= false end
end

---------------------------------------------------------------------------
-- La cola
---------------------------------------------------------------------------

local cola, orden = {}, {} -- clave -> { texto, canal, destino, difundir, despedida }; claves en turno
local fichas, pausaHasta = RAFAGA, 0
local motor = CreateFrame("Frame")
motor:Hide()
R.motor = motor -- (para /alfa manada estado y las pruebas)

local function sacar()
	local k = table.remove(orden, 1)
	if not k then return nil end
	local m = cola[k]
	cola[k] = nil
	return k, m
end

local function devolver(k, m)
	if cola[k] then return end -- llegó uno más nuevo: ese sale
	cola[k] = m
	table.insert(orden, 1, k)
end

-- El canal y el destino de un mensaje que se difunde, al momento de salir.
local function destinoDe(m)
	if not m.difundir then return m.canal, m.destino end
	local via, id = R.Via()
	if via == "canal" then return "CHANNEL", tostring(id) end
	if via == "hermandad" then return "GUILD", nil end
	return nil
end

local espera = 0
motor:SetScript("OnUpdate", function(self, dt)
	espera = espera - (tonumber(dt) or 0)
	if espera > 0 then return end
	espera = 0.1
	fichas = math.min(RAFAGA, fichas + TOPE * 0.1)
	local ahora = U.Ahora()
	if ahora < pausaHasta then return end
	while fichas >= 1 do
		local k, m = sacar()
		if not k then self:Hide() return end
		local puede, por = R.PuedeEnviar(m.despedida)
		if not puede and por == "bloqueo" then
			devolver(k, m)
			pausaHasta = ahora + 10
			return
		end
		-- Apagado, en una instancia o sin API: ese mensaje ya no vale (sigue
		-- con el siguiente, que puede ser una despedida).
		local canal, destino = destinoDe(m)
		if puede and canal then
			fichas = fichas - 1
			local ok, r = pcall(C_ChatInfo.SendAddonMessage, R.PREFIJO, m.texto, canal, destino)
			R.diag.enviados = R.diag.enviados + 1
			R.diag.ultimo, R.diag.por = m.texto:sub(1, 2), canal
			if ok then R.diag.resultado = r == nil and "ok" or r else R.diag.resultado = "error" end
			if not ok or r == nil or r == true or r == EXITO then
				-- Salió (o el juego no dice nada más).
			elseif FRENOS[r] then
				R.diag.frenados = R.diag.frenados + 1
				devolver(k, m)
				pausaHasta = ahora + FRENO
				return
			elseif r == BLOQUEO then
				devolver(k, m)
				pausaHasta = ahora + 10
				return
			elseif r == CANAL_MALO and canal == "CHANNEL" and not m.reintento then
				m.reintento = true
				-- El número del canal cambió: se vuelve a leer en el siguiente.
				devolver(k, m)
				pausaHasta = ahora + 1
				return
			end
		end
	end
end)

-- Pone un mensaje en la cola; `clave` identifica su tipo y destino.
-- Sin `canal`, se difunde a la manada por R.Via().
function R.Enviar(clave, texto, canal, destino, despedida)
	if not R.PuedeEnviar(despedida) then return false end
	R.Prefijo()
	if not cola[clave] then orden[#orden + 1] = clave end
	cola[clave] = { texto = texto, canal = canal, destino = destino, difundir = canal == nil, despedida = despedida or nil }
	motor:Show()
	return true
end

function R.Pendientes() return #orden end

---------------------------------------------------------------------------
-- Mi posición
---------------------------------------------------------------------------

local ultimo = { at = -math.huge } -- c, wx, wy, map, at, via: lo último que envié
local compartiendo = false          -- mi posición está en el aire

function R.ForzarPosicion() ultimo.at = -math.huge; ultimo.forzar = true end

-- Hace cuánto salió la última posición (para la página y el estado).
function R.UltimoEnvio()
	if ultimo.at == -math.huge then return nil end
	return U.Ahora() - ultimo.at
end

local function nivelYClase()
	local nivel = UnitLevel and U.Numero(UnitLevel("player")) or 0
	local clase = ""
	if UnitClass then
		local _, file = UnitClass("player")
		file = U.Texto(file)
		if file and file:match("^%u+$") then clase = file end
	end
	return nivel or 0, clase
end

-- Cada pocos segundos (Manada.lua): envía mi posición si toca.
function R.Tick()
	if not on("compartir") then return end
	if not R.PuedeEnviar() then return end
	local via = R.Via()
	if not via then return end
	local map, x, y = U.MiPosicion()
	if not map then return end
	local c, wx, wy = U.AlMundo(map, x, y)
	local ahora = U.Ahora()
	local movido = ultimo.forzar or not c or c ~= ultimo.c or map ~= ultimo.map or via ~= ultimo.via
	if not movido then
		local dx, dy = wx - ultimo.wx, wy - ultimo.wy
		movido = dx * dx + dy * dy >= MOVER * MOVER
	end
	local hueco = ahora - ultimo.at
	if not ((movido and hueco >= ENVIO) or hueco >= REFRESCO or ultimo.forzar) then return end
	local nivel, clase = nivelYClase()
	local texto = ("%sP|%d|%.2f|%.2f|%d|%s"):format(V, map, x, y, nivel, clase)
	ultimo.c, ultimo.wx, ultimo.wy, ultimo.map, ultimo.at, ultimo.forzar, ultimo.via = c, wx, wy, map, ahora, nil, via
	if R.Enviar("P", texto) then compartiendo = true end
end

-- "Estoy aquí": al entrar al canal (o a la hermandad, sin canal). Los demás
-- responden con su posición.
function R.Saludar()
	if not on("compartir") then return false end
	R.ForzarPosicion()
	return R.Enviar("H", V .. "H|" .. version() .. "|1")
end

-- Al apagar compartir: quienes tenían mi pin lo borran ya.
-- Sale por donde salía mi posición ahora mismo (luego se deja el canal).
function R.Despedir()
	if not compartiendo then return end
	compartiendo = false
	wipe(cola)
	wipe(orden)
	local via, id = R.Via()
	if via == "canal" then
		R.Enviar("X", V .. "X", "CHANNEL", tostring(id), true)
	elseif via == "hermandad" then
		R.Enviar("X", V .. "X", "GUILD", nil, true)
	end
end

local respPendiente, respEn = false, -math.huge
local function responder()
	if respPendiente then return end
	local ahora = U.Ahora()
	if ahora - respEn < RESP_HUECO then return end
	respPendiente = true
	A.After(RESP_AZAR[1] + math.random() * (RESP_AZAR[2] - RESP_AZAR[1]), function()
		respPendiente = false
		respEn = U.Ahora()
		if on("compartir") then R.ForzarPosicion() end
	end)
end

---------------------------------------------------------------------------
-- "Quiero unirme": ¿qué oficial está conectado?
---------------------------------------------------------------------------

local busqueda -- { nombres = { clave -> nombre }, hasta, alListo }
local silencio -- { nombres = { clave -> true }, hasta }: avisos "no está conectado" a ocultar

-- El aviso del juego para un susurro a alguien desconectado, como patrón.
local patronNoEsta
local function patron()
	if patronNoEsta ~= nil then return patronNoEsta end
	local s = type(ERR_CHAT_PLAYER_NOT_FOUND_S) == "string" and ERR_CHAT_PLAYER_NOT_FOUND_S or nil
	if not s then patronNoEsta = false return false end
	s = s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
	patronNoEsta = "^" .. s:gsub("%%%%s", "(.+)") .. "$"
	return patronNoEsta
end

-- Oculta en el chat el aviso "no hay ningún jugador llamado..." de los
-- oficiales a los que se les preguntó en silencio (los desconectados).
local function filtroSistema(_, _, msg, ...)
	if not silencio or U.Ahora() > silencio.hasta then return false end
	if type(msg) ~= "string" or U.Secreto(msg) then return false end
	local p = patron()
	local quien = p and msg:match(p)
	if quien then
		quien = quien:gsub("^['\"]", ""):gsub("['\"]$", "")
		if silencio.nombres[U.Clave(quien) or ""] then return true end
	end
	return false
end

local filtroPuesto = false
local function ponerFiltro()
	if filtroPuesto then return end
	filtroPuesto = true
	local CFU = ChatFrameUtil
	if type(CFU) == "table" and type(CFU.AddMessageEventFilter) == "function" then
		pcall(CFU.AddMessageEventFilter, "CHAT_MSG_SYSTEM", filtroSistema)
	elseif ChatFrame_AddMessageEventFilter then
		pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_SYSTEM", filtroSistema)
	end
end

-- Pregunta en silencio a los oficiales si están conectados; alListo(nombre)
-- con el primero que responde, o alListo(nil) si nadie responde a tiempo.
-- Solo al pulsar el botón: nunca solo. (Va por susurro: no depende de
-- compartir la ubicación.)
function R.BuscarOficial(nombres, alListo)
	local puede = R.PuedeEnviar(true)
	if not puede then alListo(nil, "nopuede") return false end
	local mia = U.MiClave()
	busqueda = { nombres = {}, hasta = U.Ahora() + OFICIAL_ESPERA, alListo = alListo }
	silencio = { nombres = {}, hasta = U.Ahora() + OFICIAL_ESPERA + 5 }
	ponerFiltro()
	local n = 0
	for _, nombre in ipairs(nombres or {}) do
		local clave = U.Clave(nombre)
		if clave and clave ~= mia and not busqueda.nombres[clave] and n < 6 then
			n = n + 1
			busqueda.nombres[clave] = nombre
			silencio.nombres[clave] = true
			R.Enviar("J:" .. clave, V .. "J|" .. version(), "WHISPER", U.Destino(nombre), true)
		end
	end
	if n == 0 then
		busqueda = nil
		alListo(nil, "nadie")
		return false
	end
	local esta = busqueda
	A.After(OFICIAL_ESPERA, function()
		if busqueda == esta then
			busqueda = nil
			alListo(nil, "nadie")
		end
	end)
	return true
end

function R.Buscando() return busqueda ~= nil end

---------------------------------------------------------------------------
-- Lo que llega
---------------------------------------------------------------------------

local partes = {}
local function dividir(s)
	wipe(partes)
	for p in (s .. "|"):gmatch("([^|]*)|") do partes[#partes + 1] = p end
	return partes
end

local respOficialEn = {} -- clave -> GetTime(): a quién respondí "aquí estoy"

-- (evento, prefijo, texto, canal, remitente, destino, zona, número del canal, nombre del canal)
local function alMensaje(_, prefijo, texto, canal, remitente, _, _, localID, nombreCanal)
	if U.Secreto(prefijo) or U.Secreto(texto) or U.Secreto(canal) or U.Secreto(remitente) then return end
	if prefijo ~= R.PREFIJO or type(texto) ~= "string" or type(remitente) ~= "string" then return end
	local C = M.Canal
	local via
	if canal == "CHANNEL" then
		if U.Secreto(localID) or U.Secreto(nombreCanal) then return end
		if not (C.EsNuestro(nombreCanal) or (localID ~= nil and localID == C.Id())) then return end
		via = "canal"
	elseif canal == "GUILD" then
		via = "hermandad"
	elseif canal ~= "WHISPER" then
		return
	end
	local okYo, yo = pcall(A.Compat.SenderIsMe, remitente)
	if okYo and yo then return end
	local clave = U.Clave(remitente)
	if not clave or clave == U.MiClave() then return end
	local tipo, resto = texto:match("^" .. V .. "(%u)|?(.*)$")
	if not tipo then return end
	R.diag.recibidos = R.diag.recibidos + 1

	-- "Quiero unirme", por susurro: respondo si soy de la hermandad del clan,
	-- a cualquiera, una vez por minuto por persona.
	if canal == "WHISPER" then
		if tipo == "J" then
			if not U.EnElClan() then return end
			local ahora = U.Ahora()
			if respOficialEn[clave] and ahora - respOficialEn[clave] < 60 then return end
			respOficialEn[clave] = ahora
			R.Enviar("K:" .. clave, V .. "K|" .. version(), "WHISPER", remitente, true)
		elseif tipo == "K" then
			if not busqueda or U.Ahora() > busqueda.hasta then return end
			local nombre = busqueda.nombres[clave]
			if not nombre then return end
			local fin = busqueda.alListo
			busqueda = nil
			fin(nombre)
		end
		return
	end

	-- La manada: solo entre quienes comparten.
	if not on("compartir") then return end
	local G = M.Gente
	local f = dividir(resto or "")
	if tipo == "H" then
		G.Oido(clave, remitente, via, { version = f[1] })
		-- Responde por donde hablo yo (un saludo de la hermandad, si hablo
		-- por el canal, ya lo escuchó por el canal).
		if via == R.Via() then responder() end
	elseif tipo == "P" then
		-- Solo dígitos: tonumber acepta "nan", "inf", "1e300" o "0x10", que
		-- rompen la capa del mapa y el orden de la gente.
		local s1, s2, s3 = f[1] or "", f[2] or "", f[3] or ""
		-- (el "-" solo deja pasar "-0.00" del borde del mapa; el rango corta el resto).
		if not (s1:match("^%d+$") and s2:match("^%-?%d+%.?%d*$") and s3:match("^%-?%d+%.?%d*$")) then return end
		local map, x, y = tonumber(s1), tonumber(s2), tonumber(s3)
		if not (map and x and y) or map < 1 or map > 100000 or x < 0 or x > 100 or y < 0 or y > 100 then return end
		local nivel = tonumber(f[4])
		local clase = f[5] and f[5]:match("^%u+$") or nil
		G.Oido(clave, remitente, via, {
			map = map, x = x, y = y,
			nivel = nivel and nivel > 0 and nivel <= 200 and nivel or nil, clase = clase,
		})
	elseif tipo == "X" then
		G.Olvidar(clave)
	end
end

-- El prefijo y el evento quedan siempre: "Quiero unirme" funciona aunque no
-- compartas, y lo de la manada se descarta arriba si no compartes.
local escuchando = false
function R.Escuchar()
	if escuchando then return end
	escuchando = true
	R.Prefijo()
	A.RegisterEvent("CHAT_MSG_ADDON", alMensaje)
end

-- Al entrar al canal: saludar.
M.Canal.alEntrar = function()
	if M.Gente then M.Gente.Cambio() end
	R.Saludar()
end
