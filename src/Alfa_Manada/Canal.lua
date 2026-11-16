-- Alfa - La Jauría: el canal oculto entre los usuarios de Alfa.
-- Toxic / La Jauría. GPL-3.0.
--
-- Un canal de chat propio ("AlfaJauria"), temporal (se deja solo al salir del
-- juego), sin contraseña y sin ventana de chat: por él viajan los mensajes de
-- addon de la manada (Red.lua), así se ven quienes usan Alfa y comparten,
-- estén o no en tu grupo o en tu hermandad.
--
-- Qué dice la interfaz de Forever (referencia/, rama forever, 1.60.1):
--   * C_ChatInfo.SendAddonMessage acepta un chatType y un `target` "solo para
--     canales con destino": con "CHANNEL" el destino es el número del canal.
--     Sus respuestas incluyen InvalidChannel (7) y ChannelThrottle (8), y
--     CHAT_MSG_ADDON trae localID y el nombre del canal: el camino existe.
--   * Las funciones para entrar y salir de canales no están documentadas (son
--     globales clásicas), pero la interfaz de Forever las usa: /join llama a
--     JoinPermanentChannel, /leave a LeaveChannelByName y la ventana de chat a
--     GetChannelName (Blizzard_ChatFrameBase/Shared). JoinTemporaryChannel y
--     JoinChannelByName se buscan al vuelo; si no existen, no hay canal y
--     Red.lua usa la hermandad.
--   * Una ventana de chat solo muestra los canales de su lista; uno sin
--     ventana no imprime nada (ChatFrameOverrides: ChatFrame_CheckAddChannel
--     solo agrega canales regionales). Aun así, un filtro oculta todo lo que
--     diga este canal por si alguien lo agrega a una ventana a mano.
--   * Las cuentas de prueba no pueden usar canales propios (el aviso
--     TRIAL_RESTRICTED) ni enviar mensajes de addon; tampoco se envía nada en
--     instancias ni con el bloqueo de mensajes de Midnight
--     (C_ChatInfo.InChatMessagingLockdown).
--
-- Para no quitarle el /1 al canal General, se entra cuando el juego ya puso
-- los suyos (o a los ESPERA_MAX segundos de entrar).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U = M.U

local C = {}
M.Canal = C

C.NOMBRE = "AlfaJauria"

local ESPERA_MAX = 40   -- segundos esperando a los canales del juego
local VERIFICAR = 12    -- segundos para confirmar que entramos
local REINTENTO = 120   -- segundos antes de volver a intentar
local INTENTOS = 3      -- intentos por sesión

-- "fuera" | "esperando" | "entrando" | "dentro" | "fallo" | "sinapi"
local estado, razon = "fuera", nil
local queremos = false
local intentos = 0
local saliendo = false
C.alEntrar = nil -- fn(): ya estamos dentro (Red.lua saluda)

local function unirFn()
	if type(JoinTemporaryChannel) == "function" then return JoinTemporaryChannel end
	if type(JoinChannelByName) == "function" then return JoinChannelByName end
	return nil
end

function C.Disponible()
	return unirFn() ~= nil and type(GetChannelName) == "function"
		and C_ChatInfo ~= nil and C_ChatInfo.SendAddonMessage ~= nil
end

-- El número del canal (como /5), o nil si no estamos dentro.
function C.Id()
	if type(GetChannelName) ~= "function" then return nil end
	local ok, n = pcall(GetChannelName, C.NOMBRE)
	n = ok and U.Numero(n) or nil
	if n and n > 0 then return n end
	return nil
end

-- Si un nombre de canal ("AlfaJauria", "5. AlfaJauria") es el nuestro.
function C.EsNuestro(nombre)
	nombre = U.Texto(nombre)
	if not nombre then return false end
	nombre = nombre:gsub("^%d+%.%s*", "")
	return nombre:lower() == C.NOMBRE:lower()
end

function C.Listo() return estado == "dentro" and C.Id() ~= nil end
function C.Estado() return estado, razon end
function C.Intentos() return intentos end

---------------------------------------------------------------------------
-- Lo que este canal diga no sale en el chat
---------------------------------------------------------------------------

local EVENTOS_CHAT = { "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER",
	"CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }

-- (marco, evento, texto, autor, idioma, "5. AlfaJauria", autor2, banderas,
-- zona, número, "AlfaJauria", ...)
local function filtro(_, _, _, _, _, canal, _, _, _, _, base)
	if U.Secreto(canal) or U.Secreto(base) then return false end
	return C.EsNuestro(base) or C.EsNuestro(canal)
end

local filtrado = false
local function filtrar()
	if filtrado then return end
	filtrado = true
	local CFU = ChatFrameUtil
	for _, ev in ipairs(EVENTOS_CHAT) do
		if type(CFU) == "table" and type(CFU.AddMessageEventFilter) == "function" then
			pcall(CFU.AddMessageEventFilter, ev, filtro)
		elseif type(ChatFrame_AddMessageEventFilter) == "function" then
			pcall(ChatFrame_AddMessageEventFilter, ev, filtro)
		end
	end
end

---------------------------------------------------------------------------
-- Entrar y salir
---------------------------------------------------------------------------

local function marcarDentro()
	local antes = estado
	estado, razon = "dentro", nil
	intentos = 0
	if antes ~= "dentro" and C.alEntrar then C.alEntrar() end
end

local function fallar(por)
	estado, razon = "fallo", por
	if M.Gente then M.Gente.Cambio() end
	if intentos < INTENTOS and queremos then
		A.After(REINTENTO, function()
			if queremos and estado == "fallo" then
				estado = "fuera"
				C.Entrar()
			end
		end)
	end
end

-- Los canales del juego ya están (el General es el /1), o ya esperamos bastante.
local function canalesDelJuego()
	if type(GetChannelName) ~= "function" then return true end
	local ok, n = pcall(GetChannelName, 1)
	n = ok and U.Numero(n) or nil
	return n ~= nil and n > 0
end

local desde -- U.Ahora() del primer intento de esta sesión

function C.Entrar()
	if not queremos then return false end
	if C.Id() then
		filtrar()
		marcarDentro()
		return true
	end
	if estado == "entrando" or estado == "esperando" then return false end
	local unir = unirFn()
	if not (unir and type(GetChannelName) == "function") then
		estado, razon = "sinapi", "sinapi"
		return false
	end
	if U.CuentaDePrueba() then
		estado, razon = "fallo", "prueba"
		return false
	end
	desde = desde or U.Ahora()
	if not canalesDelJuego() and U.Ahora() - desde < ESPERA_MAX then
		estado = "esperando"
		A.After(3, function()
			if estado == "esperando" then
				estado = "fuera"
				C.Entrar()
			end
		end)
		return false
	end
	filtrar()
	intentos = intentos + 1
	estado, razon = "entrando", nil
	-- Sin contraseña y sin ventana de chat: no se muestra en ninguna.
	pcall(unir, C.NOMBRE)
	A.After(VERIFICAR, function()
		if estado ~= "entrando" then return end
		if C.Id() then marcarDentro() else fallar("noentra") end
	end)
	return true
end

function C.Salir()
	if estado == "esperando" or estado == "entrando" then estado = "fuera" end
	if not C.Id() then
		estado = "fuera"
		return
	end
	saliendo = true
	if type(LeaveChannelByName) == "function" then pcall(LeaveChannelByName, C.NOMBRE) end
	estado, razon = "fuera", nil
	A.After(5, function() saliendo = false end)
end

-- Compartir encendido: entrar; apagado: salir.
function C.Querer(si)
	queremos = si and true or false
	if queremos then
		if estado == "fallo" then estado = "fuera" end
		C.Entrar()
	else
		C.Salir()
	end
end

---------------------------------------------------------------------------
-- Lo que dice el juego del canal
---------------------------------------------------------------------------

-- Avisos que dicen que no se pudo entrar (o que nos sacaron).
local NO_ENTRA = {
	WRONG_PASSWORD = true, BANNED = true, TRIAL_RESTRICTED = true, INVALID_NAME = true,
	NOT_ALLOWED = true, THROTTLED = true, KICKED = true,
}

-- (evento, tipo, autor, idioma, "5. AlfaJauria", autor2, banderas, zona, número, "AlfaJauria")
A.RegisterEvent("CHAT_MSG_CHANNEL_NOTICE", function(_, tipo, _, _, canal, _, _, _, _, base)
	if U.Secreto(tipo) or U.Secreto(canal) or U.Secreto(base) then return end
	if not (C.EsNuestro(base) or C.EsNuestro(canal)) then return end
	tipo = U.Texto(tipo)
	if tipo == "YOU_JOINED" or tipo == "YOU_CHANGED" then
		if queremos then marcarDentro() end
	elseif tipo == "YOU_LEFT" then
		estado = "fuera"
		if queremos and not saliendo then
			-- Salimos sin pedirlo (el juego, otro addon, un /leave): de vuelta en un rato.
			A.After(30, function() if queremos and estado == "fuera" then C.Entrar() end end)
		end
	elseif tipo and NO_ENTRA[tipo] then
		fallar(tipo == "TRIAL_RESTRICTED" and "prueba" or tipo:lower())
	end
end)

-- El menú de canales cambió: ¿seguimos dentro?
A.RegisterEvent("CHANNEL_UI_UPDATE", function()
	if not queremos then return end
	if estado == "dentro" and not C.Id() then
		estado = "fuera"
	elseif (estado == "entrando" or estado == "fuera") and C.Id() then
		marcarDentro()
	end
end)
