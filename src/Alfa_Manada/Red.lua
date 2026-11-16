-- Alfa - La Jauría: los mensajes entre los Alfa de la manada.
-- Toxic / La Jauría. GPL-3.0.
--
-- Mensajes de addon ocultos con el prefijo propio "AlfaManada": por el canal
-- de la hermandad (GUILD) y por susurro (WHISPER) a los amigos de tu lista.
-- Nunca por canales públicos. Nada sale dentro de instancias (el juego no lo
-- permite) ni desde una cuenta de prueba (tampoco puede).
--
-- Mensajes (versión 1, campos separados por "|"):
--   1H|<versión>|<comparte 0/1>   saludo: "uso Alfa" (hermandad al entrar;
--                                 amigos conectados, solo si les compartes)
--   1Y|<versión>|<comparte 0/1>   respuesta al saludo
--   1P|<mapa>|<x>|<y>|<nivel>|<CLASE>   dónde estás (x, y en 0-100 del mapa)
--   1X                            dejé de compartir: borra mi pin
--   1J|<versión>                  "¿estás conectado?" a un oficial del clan
--                                 (solo al pulsar "Quiero unirme")
--   1K|<versión>                  "sí, aquí estoy" (respuesta a 1J)
--
-- La posición sale cada ENVIO segundos como mínimo y solo si te moviste más
-- de MOVER yardas; quieto, una vez cada REFRESCO para que tu pin no caduque.
-- Lo que llega de otros caduca solo (Gente.lua: CADUCA).
--
-- Todo envío pasa por una cola: como mucho TOPE mensajes por segundo (con
-- una ráfaga de RAFAGA), y un mensaje nuevo para el mismo destino reemplaza
-- al que esperaba (una posición vieja nunca sale después de una nueva). Si el
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
local TOPE, RAFAGA = 2, 4
local FRENO = 3
local ENVIO, REFRESCO, MOVER = 10, 240, 10
local HOLA_HUECO = 120     -- segundos entre dos saludos a la hermandad
local RESP_HUECO = 30      -- segundos entre dos respuestas a la hermandad
local RESP_AZAR = { 2, 8 } -- espera al azar antes de responder (no todos a la vez)
local OFICIAL_ESPERA = 5   -- segundos esperando que un oficial responda

local RES = Enum and Enum.SendAddonMessageResult
local OK_RES = RES and RES.Success or 0
local FRENOS = {
	[RES and RES.AddonMessageThrottle or 3] = true,
	[RES and RES.ChannelThrottle or 8] = true,
}
local BLOQUEO = RES and RES.AddOnMessageLockdown or 11

local function version() return (tostring(A.version or "dev"):gsub("|", "")) end
local function on(clave) return N.Get(ID, clave) and true or false end

---------------------------------------------------------------------------
-- Estado de envío
---------------------------------------------------------------------------

R.diag = { enviados = 0, frenados = 0, recibidos = 0 }

-- Si se puede enviar ahora: true, o false y la razón (para la página).
-- `despedida`: el último aviso "dejé de compartir" sale aunque la red se
-- acabe de apagar.
function R.PuedeEnviar(despedida)
	if not despedida and not on("red") then return false, "apagado" end
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false, "sinapi" end
	if U.CuentaDePrueba() then return false, "prueba" end
	if U.EnInstancia() then return false, "instancia" end
	if C_ChatInfo.InChatMessagingLockdown then
		local ok, bloqueado = pcall(C_ChatInfo.InChatMessagingLockdown)
		if ok and bloqueado == true then return false, "bloqueo" end
	end
	return true
end

local prefijoListo = false
function R.Prefijo()
	if prefijoListo or not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
	local ya = C_ChatInfo.IsAddonMessagePrefixRegistered and C_ChatInfo.IsAddonMessagePrefixRegistered(R.PREFIJO)
	if not ya then
		local ok, r = pcall(C_ChatInfo.RegisterAddonMessagePrefix, R.PREFIJO)
		R.diag.prefijo = ok and r or "error"
	end
	prefijoListo = true
end

---------------------------------------------------------------------------
-- La cola
---------------------------------------------------------------------------

local cola, orden = {}, {} -- clave -> { texto, canal, destino }; claves en turno
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
		if puede then
			fichas = fichas - 1
			local ok, r = pcall(C_ChatInfo.SendAddonMessage, R.PREFIJO, m.texto, m.canal, m.destino)
			R.diag.enviados = R.diag.enviados + 1
			R.diag.ultimo, R.diag.resultado = m.texto:sub(1, 2), ok and r or "error"
			if ok and FRENOS[r] then
				R.diag.frenados = R.diag.frenados + 1
				devolver(k, m)
				pausaHasta = ahora + FRENO
				return
			elseif ok and r == BLOQUEO then
				devolver(k, m)
				pausaHasta = ahora + 10
				return
			end
		end
	end
end)

-- Pone un mensaje en la cola; `clave` identifica su destino y tipo.
-- `despedida`: el aviso "dejé de compartir", que sale aunque la red se apague.
function R.Enviar(clave, texto, canal, destino, despedida)
	if not R.PuedeEnviar(despedida) then return false end
	R.Prefijo()
	if not cola[clave] then orden[#orden + 1] = clave end
	cola[clave] = { texto = texto, canal = canal, destino = destino, despedida = despedida or nil }
	motor:Show()
	return true
end

function R.Pendientes() return #orden end

---------------------------------------------------------------------------
-- Saludos
---------------------------------------------------------------------------

local holaEn = -math.huge
local respPendiente, respEn = false, -math.huge
local amigosSaludados = {} -- clave -> true: ya les saludé en esta sesión

local function comparteCon(canal)
	if canal == "GUILD" then return on("compartir") end
	return on("compartirAmigos")
end

function R.SaludarHermandad(forzar)
	if not (on("red") and U.EnHermandad()) then return false end
	local ahora = U.Ahora()
	if not forzar and ahora - holaEn < HOLA_HUECO then return false end
	holaEn = ahora
	return R.Enviar("H:G", "1H|" .. version() .. "|" .. (comparteCon("GUILD") and "1" or "0"), "GUILD")
end

local function responderHermandad()
	if respPendiente then return end
	local ahora = U.Ahora()
	local cuando = math.max(0, respEn + RESP_HUECO - ahora) + RESP_AZAR[1] + math.random() * (RESP_AZAR[2] - RESP_AZAR[1])
	respPendiente = true
	A.After(cuando, function()
		respPendiente = false
		respEn = U.Ahora()
		if not (on("red") and U.EnHermandad()) then return end
		if on("compartir") then
			-- Quien comparte responde con su posición: dice lo mismo y más.
			R.ForzarPosicion()
		end
		R.Enviar("Y:G", "1Y|" .. version() .. "|" .. (on("compartir") and "1" or "0"), "GUILD")
	end)
end

-- Saluda por susurro a los amigos conectados que aún no saludé (solo si les
-- compartes tu ubicación). `lista`: { { clave, envio }, ... }
function R.SaludarAmigos(lista)
	if not (on("red") and on("compartirAmigos")) then return end
	for _, f in ipairs(lista or {}) do
		if f.clave and f.envio and not amigosSaludados[f.clave] then
			amigosSaludados[f.clave] = true
			R.Enviar("H:W:" .. f.clave, "1H|" .. version() .. "|1", "WHISPER", f.envio)
		end
	end
end

-- Olvida a quién saludé (al volver a encender compartir con amigos).
function R.OlvidarSaludos() wipe(amigosSaludados) end

---------------------------------------------------------------------------
-- Mi posición
---------------------------------------------------------------------------

local ultimo = { at = -math.huge } -- c, wx, wy, map, at: lo último que envié
local compartiendo = { guild = false, amigos = {} } -- a quién le llegó mi posición

function R.ForzarPosicion() ultimo.at = -math.huge; ultimo.forzar = true end

-- Lo que la página dice del envío: hace cuánto salió la última posición.
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

-- Avisa a quienes tenían mi posición que ya no comparto (una despedida:
-- sale aunque la red se acabe de apagar).
local function retirar(guild, amigos)
	if guild and compartiendo.guild then
		compartiendo.guild = false
		if U.EnHermandad() then R.Enviar("P:G", "1X", "GUILD", nil, true) end
	end
	for clave, envio in pairs(amigos or {}) do
		if compartiendo.amigos[clave] then
			compartiendo.amigos[clave] = nil
			R.Enviar("P:W:" .. clave, "1X", "WHISPER", envio, true)
		end
	end
end

-- Cada pocos segundos (Manada.lua): envía mi posición si toca.
-- `amigos`: clave -> nombre para susurrar, los amigos con Alfa conectados
-- que no están en mi hermandad (Gente.AmigosConAlfa).
function R.Tick(amigos)
	amigos = amigos or {}
	local guild = on("compartir") and U.EnHermandad()
	local aAmigos = on("compartirAmigos") and amigos or {}
	-- Lo que dejó de valer: la hermandad, o amigos que ya no reciben. A quien
	-- se desconectó no se le susurra (el juego avisaría que no está): solo se
	-- olvida; a quien sigue conectado se le avisa.
	if not guild then retirar(true, nil) end
	local fuera
	for clave in pairs(compartiendo.amigos) do
		if not aAmigos[clave] then
			if amigos[clave] then
				fuera = fuera or {}
				fuera[clave] = amigos[clave]
			else
				compartiendo.amigos[clave] = nil
			end
		end
	end
	if fuera then retirar(false, fuera) end
	if not guild and not next(aAmigos) then return end
	if not R.PuedeEnviar() then return end
	local map, x, y = U.MiPosicion()
	if not map then return end
	local c, wx, wy = U.AlMundo(map, x, y)
	local ahora = U.Ahora()
	local movido = ultimo.forzar or not c or c ~= ultimo.c or map ~= ultimo.map
	if not movido then
		local dx, dy = wx - ultimo.wx, wy - ultimo.wy
		movido = dx * dx + dy * dy >= MOVER * MOVER
	end
	-- Alguien nuevo que aún no tiene mi posición.
	local nuevo = guild and not compartiendo.guild
	for clave in pairs(aAmigos) do
		if not compartiendo.amigos[clave] then nuevo = true end
	end
	local hueco = ahora - ultimo.at
	if not nuevo and not ((movido and hueco >= ENVIO) or hueco >= REFRESCO) then return end
	local nivel, clase = nivelYClase()
	local texto = ("1P|%d|%.2f|%.2f|%d|%s"):format(map, x, y, nivel, clase)
	ultimo.c, ultimo.wx, ultimo.wy, ultimo.map, ultimo.at, ultimo.forzar = c, wx, wy, map, ahora, nil
	if guild then
		R.Enviar("P:G", texto, "GUILD")
		compartiendo.guild = true
	end
	for clave, envio in pairs(aAmigos) do
		R.Enviar("P:W:" .. clave, texto, "WHISPER", envio)
		compartiendo.amigos[clave] = envio
	end
end

-- Al apagar compartir (o toda la red): el aviso sale ya, sin esperar al
-- siguiente tick, y quienes tenían tu pin lo borran.
function R.AlCambiarAjustes()
	local red = on("red")
	if not red or not on("compartir") then retirar(true, nil) end
	if not red or not on("compartirAmigos") then retirar(false, compartiendo.amigos) end
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
-- Solo al pulsar el botón: nunca solo.
function R.BuscarOficial(nombres, alListo)
	local puede = R.PuedeEnviar()
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
			R.Enviar("J:" .. clave, "1J|" .. version(), "WHISPER", U.Destino(nombre))
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

local function alMensaje(_, prefijo, texto, canal, remitente)
	if U.Secreto(prefijo) or U.Secreto(texto) or U.Secreto(canal) or U.Secreto(remitente) then return end
	if prefijo ~= R.PREFIJO or type(texto) ~= "string" or type(remitente) ~= "string" then return end
	if canal ~= "GUILD" and canal ~= "WHISPER" then return end
	if not on("red") then return end
	local C = A.Compat
	local okYo, yo = pcall(C.SenderIsMe, remitente)
	if okYo and yo then return end
	local clave = U.Clave(remitente)
	if not clave or clave == U.MiClave() then return end
	local tipo, resto = texto:match("^" .. V .. "(%u)|?(.*)$")
	if not tipo then return end
	R.diag.recibidos = R.diag.recibidos + 1
	local G = M.Gente
	local f = dividir(resto or "")

	-- "Quiero unirme": respondo si soy de la hermandad del clan, a cualquiera,
	-- una vez por minuto por persona.
	if tipo == "J" then
		if canal ~= "WHISPER" or not U.EnElClan() then return end
		local ahora = U.Ahora()
		if respOficialEn[clave] and ahora - respOficialEn[clave] < 60 then return end
		respOficialEn[clave] = ahora
		R.Enviar("K:" .. clave, "1K|" .. version(), "WHISPER", remitente)
		return
	elseif tipo == "K" then
		if canal ~= "WHISPER" or not busqueda or U.Ahora() > busqueda.hasta then return end
		local nombre = busqueda.nombres[clave]
		if not nombre then return end
		local fin = busqueda.alListo
		busqueda = nil
		fin(nombre)
		return
	end

	-- Por susurro, solo de amigos de mi lista.
	local via = canal == "GUILD" and "hermandad" or "amigo"
	if via == "amigo" and not (G and G.EsAmigo(clave)) then return end

	if tipo == "H" or tipo == "Y" then
		G.Oido(clave, remitente, via, { version = f[1], comparte = f[2] == "1" })
		if tipo == "H" then
			if via == "hermandad" then
				responderHermandad()
			elseif on("verAmigos") then
				-- Un amigo me comparte: le digo que uso Alfa y que acepto verlo.
				R.Enviar("Y:W:" .. clave, "1Y|" .. version() .. "|" .. (on("compartirAmigos") and "1" or "0"), "WHISPER", remitente)
			end
		end
	elseif tipo == "P" then
		if via == "amigo" and not on("verAmigos") then return end
		local map, x, y = tonumber(f[1]), tonumber(f[2]), tonumber(f[3])
		if not (map and x and y) or map <= 0 or map ~= math.floor(map) or x < 0 or x > 100 or y < 0 or y > 100 then return end
		local nivel = tonumber(f[4])
		local clase = f[5] and f[5]:match("^%u+$") or nil
		G.Oido(clave, remitente, via, {
			comparte = true, map = map, x = x, y = y,
			nivel = nivel and nivel > 0 and nivel <= 200 and nivel or nil, clase = clase,
		})
	elseif tipo == "X" then
		G.Oido(clave, remitente, via, { comparte = false, quitar = true })
	end
end

local escuchando = false
function R.Escuchar()
	local quiere = on("red")
	if quiere == escuchando then return end
	escuchando = quiere
	if quiere then
		R.Prefijo()
		A.RegisterEvent("CHAT_MSG_ADDON", alMensaje)
	else
		A.UnregisterEvent("CHAT_MSG_ADDON", alMensaje)
	end
end
