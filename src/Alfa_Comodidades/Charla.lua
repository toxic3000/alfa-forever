-- Alfa - Comodidades: tu chat, más a la mano (1.3.7). toxic3000 / La Jauría. GPL-3.0.
--
-- Cinco cosas, cada una con su interruptor, todas solo en TU chat (nada se
-- manda a nadie, ni se responde nada solo):
--   * La hora en cada línea (chatHora). Con la opción del juego si este
--     cliente la tiene (CVar showTimestamps); si no, un filtro de Alfa la pone.
--   * Los nombres con el color de su clase (chatClase). Con la opción del juego
--     (CVar chatClassColorOverride, o SetChatColorNameByClass por tipo de chat).
--   * Copiar (chatCopiar): las direcciones (http, www, discord.gg) se vuelven
--     un enlace; un clic abre un cuadro para copiarla. Sobre cada ventana de
--     chat, al pasar el ratón, un botón copia sus últimas líneas. /alfa copiar.
--   * Susurros a la vista (susurros): un sonido propio de Alfa al llegarte uno y
--     el historial por persona (AlfaNucleoCharDB, 30 personas, 50 líneas cada
--     una). /alfa susurros.
--   * Filtro de spam (spam): la venta de oro y los mensajes repetidos en los
--     canales no salen; nunca de tus amigos, tu hermandad, tu grupo ni tuyos.
--     Lo escondido se guarda (los últimos 100) para verlo: /alfa filtrado.
--
-- Todo pasa por un solo filtro de mensajes por evento
-- (ChatFrame_AddMessageEventFilter, o ChatFrameUtil.AddMessageEventFilter), que
-- revisa los ajustes en cada mensaje. Un mensaje o un nombre secreto
-- (issecretvalue, mazmorras) pasa tal cual: no se lee. El juego llama al
-- filtro una vez por ventana de chat: la decisión del spam se recuerda por
-- línea (lineID) para que la segunda ventana diga lo mismo.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local ID = M.ID

local Ch = {}
M.Charla = Ch

local type, pairs, ipairs, pcall, tostring, tonumber, format, floor, select = type, pairs, ipairs, pcall, tostring, tonumber, string.format, math.floor, select
local lower, gsub, find, sub = string.lower, string.gsub, string.find, string.sub

local secreto = N.Secreto
local function texto(v) return type(v) == "string" and not secreto(v) and v or nil end
local function ahora() return GetTime and GetTime() or 0 end

---------------------------------------------------------------------------
-- Quién es de confianza (nunca se le filtra nada)
---------------------------------------------------------------------------
local function yo(nombre)
	local mio = UnitName and UnitName("player")
	if not (texto(mio) and nombre) then return false end
	local corto = nombre:match("^([^%-]+)") or nombre
	return corto == mio
end

local function deConfianza(nombre, guid)
	if not nombre or yo(nombre) then return true end
	local corto = nombre:match("^([^%-]+)") or nombre
	local g = texto(guid)
	local F = C_FriendList
	if g and F and type(F.IsFriend) == "function" then
		local ok, si = pcall(F.IsFriend, g)
		if ok and N.Si(si) then return true end
	end
	if g and type(IsGuildMember) == "function" then
		local ok, si = pcall(IsGuildMember, g)
		if ok and N.Si(si) then return true end
	end
	if g and C_BattleNet and type(C_BattleNet.GetGameAccountInfoByGUID) == "function" then
		local ok, info = pcall(C_BattleNet.GetGameAccountInfoByGUID, g)
		if ok and type(info) == "table" then return true end
	end
	for _, fn in ipairs({ "UnitInParty", "UnitInRaid" }) do
		local f = rawget(_G, fn)
		if type(f) == "function" then
			local ok, si = pcall(f, corto)
			if ok and N.Si(si) then return true end
		end
	end
	return false
end
Ch.DeConfianza = deConfianza

---------------------------------------------------------------------------
-- El filtro de spam
---------------------------------------------------------------------------
-- Palabras de la venta de oro (en minúsculas, sin acentos). Es venta de oro
-- si trae una dirección web con dinero real, oro u oferta, o dinero real con
-- oro u oferta. «Vendo X, precio 5 de oro» (el comercio de siempre) no lo es.
local WEB = { "www", "%.com", "%.net", "%.org", "%.ru", "%.cn", "%.shop", "%.store", "dot com", "%[dot%]", "%(dot%)", "c0m", "%.c o m" }
local REAL = { "usd", "%$", "€", "paypal", "euro", "dolar", "dollar", "%f[%a]eur%f[%A]" }
local ORO = { "gold", "%f[%a]oro%f[%A]", "%d+ ?k ?g%f[%A]", "%d+ ?g%f[%A]" }
local OFERTA = { "cheap", "barato", "barata", "delivery", "entrega inmediata", "discount", "descuento", "powerlevel",
	"power level", "boost", "in stock", "en stock", "fast and safe", "rapido y seguro", "best price", "mejor precio" }

local function alguna(s, lista)
	for _, p in ipairs(lista) do if find(s, p) then return true end end
	return false
end

local function normal(s)
	s = lower(s)
	s = gsub(s, "|c%x%x%x%x%x%x%x%x", "")
	s = gsub(s, "|r", "")
	s = gsub(s, "á", "a") s = gsub(s, "é", "e") s = gsub(s, "í", "i") s = gsub(s, "ó", "o") s = gsub(s, "ú", "u")
	return s
end

-- -> true si parece venta de oro
function Ch.EsVentaDeOro(msg)
	local s = texto(msg)
	if not s then return false end
	s = normal(s)
	local real, oro, oferta = alguna(s, REAL), alguna(s, ORO), alguna(s, OFERTA)
	if alguna(s, WEB) and (real or oro or oferta) then return true end
	return real and (oro or oferta)
end

local CANALES = { CHAT_MSG_CHANNEL = true, CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_EMOTE = true, CHAT_MSG_WHISPER = true }
local REPETIDO = 60          -- segundos en que el mismo texto de la misma persona es repetido
local vistos = {}            -- quien \0 texto -> cuándo lo dijo
local decisiones, ordenDec = {}, {} -- lineID -> motivo | false
local filtrados = {}         -- los últimos 100 escondidos: { t, quien, evento, texto, motivo }
local TOPE_FILTRADOS = 100
local avisadoSpam = false

local function recordar(lineID, motivo)
	if not lineID then return end
	decisiones[lineID] = motivo
	ordenDec[#ordenDec + 1] = lineID
	if #ordenDec > 300 then
		decisiones[table.remove(ordenDec, 1)] = nil
	end
end

local function limpiarVistos(t)
	local n = 0
	for k, cuando in pairs(vistos) do
		if t - cuando > REPETIDO then vistos[k] = nil else n = n + 1 end
	end
	return n
end

local ultimaLimpieza = 0

-- -> el motivo ("oro" | "repetido") si hay que esconderlo, o nil
function Ch.Spam(evento, msg, quien, lineID, guid)
	if not (M.Get("spam") and CANALES[evento]) then return nil end
	local m, q = texto(msg), texto(quien)
	if not (m and q) then return nil end
	local id = not secreto(lineID) and tonumber(lineID) or nil
	if id and decisiones[id] ~= nil then return decisiones[id] or nil end
	local motivo
	if not deConfianza(q, guid) then
		if Ch.EsVentaDeOro(m) then
			motivo = "oro"
		elseif M.On("spam", "spamRepetidos") and evento ~= "CHAT_MSG_WHISPER" then
			local t = ahora()
			if t - ultimaLimpieza > 30 then ultimaLimpieza = t limpiarVistos(t) end
			local clave = q .. "\0" .. normal(m)
			local antes = vistos[clave]
			if antes and t - antes <= REPETIDO then motivo = "repetido" end
			vistos[clave] = t
		end
	end
	recordar(id, motivo or false)
	if motivo then
		filtrados[#filtrados + 1] = { t = time and time() or 0, quien = q, evento = evento, texto = m, motivo = motivo }
		if #filtrados > TOPE_FILTRADOS then table.remove(filtrados, 1) end
		if not avisadoSpam then
			avisadoSpam = true
			N.Imprimir(L["Alfa escondió un mensaje de spam de tu chat. Para ver lo filtrado: /alfa filtrado."])
		end
	end
	return motivo
end

---------------------------------------------------------------------------
-- Direcciones que se copian con un clic
---------------------------------------------------------------------------
local PREFIJO = "addon:alfacopiar:"
local PATRONES = {
	"https?://[%w%-%._~:/%?#%[%]@!%$&'%*%+,;=%%]+",
	"www%.[%w%-]+%.[%w%-%._~/%?#=&%%]+",
	"discord%.gg/[%w%-]+",
}

local function enlace(url)
	-- La dirección termina antes de un punto o una coma finales.
	local fin = url:match("[%.,;:!%?]+$")
	local cuerpo = fin and url:sub(1, #url - #fin) or url
	return "|cff8be04e|H" .. PREFIJO .. cuerpo .. "|h[" .. cuerpo .. "]|h|r" .. (fin or "")
end

function Ch.ConEnlaces(msg)
	local s = texto(msg)
	if not s then return msg end
	if not (find(s, "http", 1, true) or find(s, "www.", 1, true) or find(s, "discord.gg", 1, true)) then return msg end
	-- Cada dirección una sola vez: se marcan con un hueco y luego se arman.
	local guardadas = {}
	for _, p in ipairs(PATRONES) do
		s = gsub(s, p, function(u)
			guardadas[#guardadas + 1] = u
			return "\1" .. #guardadas .. "\1"
		end)
	end
	if #guardadas == 0 then return msg end
	s = gsub(s, "\1(%d+)\1", function(i) return enlace(guardadas[tonumber(i)]) end)
	return s
end

local function mostrarCopia(titulo, t, pista)
	local UI = A.UI
	if UI and UI.ShowCopy then
		pcall(UI.ShowCopy, titulo, t, { hint = pista or L["Ya está seleccionado: cópialo con Ctrl+C y luego presiona Esc. Nada se envía."] })
		return true
	end
	return false
end
Ch.MostrarCopia = mostrarCopia

-- El clic en un enlace de Alfa.
local function alEnlace(link)
	link = texto(link)
	if not link or sub(link, 1, #PREFIJO) ~= PREFIJO then return false end
	mostrarCopia(L["Copiar la dirección"], sub(link, #PREFIJO + 1))
	return true
end
Ch.AlEnlace = alEnlace

local enlacesListos = false
local function engancharEnlaces()
	if enlacesListos then return end
	enlacesListos = true
	local ER = rawget(_G, "EventRegistry")
	if type(ER) == "table" and type(ER.RegisterCallback) == "function" then
		pcall(ER.RegisterCallback, ER, "SetItemRef", function(_, link) M.Seguro(alEnlace, link) end, Ch)
	elseif type(rawget(_G, "SetItemRef")) == "function" then
		hooksecurefunc("SetItemRef", function(link) M.Seguro(alEnlace, link) end)
	end
end

---------------------------------------------------------------------------
-- Copiar las últimas líneas de una ventana de chat
---------------------------------------------------------------------------
local function sinCodigos(s)
	s = gsub(s, "|c%x%x%x%x%x%x%x%x", "")
	s = gsub(s, "|r", "")
	s = gsub(s, "|H.-|h(.-)|h", "%1")
	s = gsub(s, "|T.-|t", "")
	s = gsub(s, "|A.-|a", "")
	s = gsub(s, "|K.-|k", "?")
	s = gsub(s, "||", "|")
	return s
end
Ch.SinCodigos = sinCodigos

-- -> el texto de las últimas `cuantas` líneas de la ventana (los secretos, «…»)
function Ch.TextoDe(cf, cuantas)
	if type(cf) ~= "table" or type(cf.GetNumMessages) ~= "function" or type(cf.GetMessageInfo) ~= "function" then return "" end
	local ok, n = pcall(cf.GetNumMessages, cf)
	n = ok and tonumber(texto(n) or n) or 0
	local desde = math.max(1, n - (cuantas or 150) + 1)
	local lineas = {}
	for i = desde, n do
		local okI, m = pcall(cf.GetMessageInfo, cf, i)
		if okI and m ~= nil then
			lineas[#lineas + 1] = texto(m) and sinCodigos(m) or "…"
		end
	end
	return table.concat(lineas, "\n")
end

function Ch.CopiarVentana(cf)
	cf = cf or rawget(_G, "SELECTED_CHAT_FRAME") or DEFAULT_CHAT_FRAME
	local t = Ch.TextoDe(cf, 150)
	if t == "" then
		N.Imprimir(L["Esta ventana de chat no tiene líneas para copiar."])
		return false
	end
	return mostrarCopia(L["Copiar del chat"], t)
end

local botones = {} -- ventana de chat -> botón de copiar

local function botonDe(cf)
	if botones[cf] or type(cf) ~= "table" or not cf.HookScript then return botones[cf] end
	local b = K.BotonIcono(cf, "ic-lista", function() Ch.CopiarVentana(cf) end, { tam = 22, icono = 12, ayuda = L["Copiar del chat"] })
	b:SetPoint("TOPRIGHT", cf, "TOPRIGHT", 0, 0)
	b:SetFrameLevel((cf.GetFrameLevel and cf:GetFrameLevel() or 1) + 6)
	b:SetAlpha(0.9)
	b:Hide()
	-- Solo a la vista (y recibiendo el ratón) mientras el ratón está sobre el
	-- chat, y nunca en combate: escondido no tapa nada.
	local function mostrar()
		if M.Get("chatCopiar") and not (InCombatLockdown and InCombatLockdown()) then b:Show() end
	end
	local function quizaEsconder()
		N.Una("comodidades.copiar", 0.15, function()
			local sobre = (cf.IsMouseOver and cf:IsMouseOver()) or (b.IsMouseOver and b:IsMouseOver())
			if not sobre then b:Hide() end
		end)
	end
	cf:HookScript("OnEnter", mostrar)
	cf:HookScript("OnLeave", quizaEsconder)
	b:HookScript("OnLeave", quizaEsconder)
	botones[cf] = b
	return b
end

local function ventanas()
	local lista = {}
	for i = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
		local cf = rawget(_G, "ChatFrame" .. i)
		if type(cf) == "table" and cf.GetObjectType then lista[#lista + 1] = cf end
	end
	return lista
end

local function aplicarCopiar()
	local si = M.Get("chatCopiar")
	if si then engancharEnlaces() end
	for _, cf in ipairs(ventanas()) do
		local b = si and botonDe(cf) or botones[cf]
		if b and not si then b:Hide() end
	end
end

---------------------------------------------------------------------------
-- La hora y los colores de clase
---------------------------------------------------------------------------
local FORMATO_HORA = "%H:%M "
local horaPropia = false -- true: este cliente no tiene la opción y la pone el filtro

local function aplicarHora()
	local si = M.Get("chatHora")
	horaPropia = false
	if not M.ForzarCVar("showTimestamps", FORMATO_HORA, si) then horaPropia = si end
end

function Ch.ConHora(msg)
	local s = texto(msg)
	if not s then return msg end
	return "|cff8a998b" .. (date and date("%H:%M") or "") .. "|r " .. s
end

local TIPOS_CLASE = { "SAY", "EMOTE", "YELL", "GUILD", "OFFICER", "WHISPER", "WHISPER_INFORM", "PARTY", "PARTY_LEADER",
	"RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
	"CHANNEL1", "CHANNEL2", "CHANNEL3", "CHANNEL4", "CHANNEL5", "CHANNEL6", "CHANNEL7", "CHANNEL8", "CHANNEL9", "CHANNEL10" }

local function aplicarClase()
	local si = M.Get("chatClase")
	if M.ForzarCVar("chatClassColorOverride", "0", si) then return end
	-- Sin esa opción: el color de clase por tipo de chat, como lo hace el
	-- menú del juego; al apagarlo vuelve como lo tenías.
	local poner = rawget(_G, "SetChatColorNameByClass")
	if type(poner) ~= "function" then return end
	N.FueraDeCombate("comodidades.chatClase", function()
		local d = N.Datos(ID)
		d.claseAntes = type(d.claseAntes) == "table" and d.claseAntes or {}
		local info = rawget(_G, "ChatTypeInfo")
		for _, t in ipairs(TIPOS_CLASE) do
			if si then
				if d.claseAntes[t] == nil then
					local i = type(info) == "table" and info[t]
					d.claseAntes[t] = type(i) == "table" and i.colorNameByClass and true or false
				end
				pcall(poner, t, true)
			elseif d.claseAntes[t] ~= nil then
				pcall(poner, t, d.claseAntes[t])
				d.claseAntes[t] = nil
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Los susurros
---------------------------------------------------------------------------
local TOPE_PERSONAS, TOPE_LINEAS = 30, 50
local SONIDO = (SOUNDKIT and SOUNDKIT.MAP_PING) or 3175
local ultimoSonido = {}

local function historial()
	local d = N.DatosPersonaje(ID)
	if type(d.susurros) ~= "table" then d.susurros = {} end
	return d.susurros
end

local function podar(h)
	local n, viejo, cuando = 0, nil, math.huge
	for nombre, p in pairs(h) do
		n = n + 1
		local u = tonumber(p.ultimo) or 0
		if u < cuando then viejo, cuando = nombre, u end
	end
	if n > TOPE_PERSONAS and viejo then h[viejo] = nil end
end

function Ch.Anotar(nombre, msg, mio)
	nombre, msg = texto(nombre), texto(msg)
	if not (nombre and msg) or not M.Get("susurros") then return false end
	local h = historial()
	local p = h[nombre]
	if type(p) ~= "table" then
		p = { lineas = {} }
		h[nombre] = p
	end
	local t = time and time() or 0
	p.lineas[#p.lineas + 1] = { t = t, mio = mio and true or nil, m = sinCodigos(msg) }
	while #p.lineas > TOPE_LINEAS do table.remove(p.lineas, 1) end
	p.ultimo = t
	podar(h)
	return true
end

local function sonar(nombre)
	if not M.On("susurros", "susurrosSonido") then return end
	local t = ahora()
	if ultimoSonido[nombre] and t - ultimoSonido[nombre] < 8 then return end
	ultimoSonido[nombre] = t
	local tocar = rawget(_G, "PlaySound")
	if type(tocar) == "function" then pcall(tocar, SONIDO, "Master") end
	Ch.sonidos = (Ch.sonidos or 0) + 1
end

-- -> las personas, la más reciente primero: { { nombre, ultimo, n }, ... }
function Ch.Personas()
	local out = {}
	for nombre, p in pairs(historial()) do
		if type(p) == "table" and type(p.lineas) == "table" then
			out[#out + 1] = { nombre = nombre, ultimo = tonumber(p.ultimo) or 0, n = #p.lineas }
		end
	end
	table.sort(out, function(a, b) return a.ultimo > b.ultimo end)
	return out
end

function Ch.Conversacion(nombre)
	local p = historial()[nombre]
	if type(p) ~= "table" then return "" end
	local mio = UnitName and texto(UnitName("player")) or L["Tú"]
	local lineas = {}
	for _, l in ipairs(p.lineas or {}) do
		local cuando = date and date("%d/%m %H:%M", tonumber(l.t) or 0) or ""
		lineas[#lineas + 1] = format("[%s] %s: %s", cuando, l.mio and mio or nombre, tostring(l.m))
	end
	return table.concat(lineas, "\n")
end

function Ch.VerSusurros(dueno, nombre)
	if nombre then
		local t = Ch.Conversacion(nombre)
		if t == "" then return false end
		return mostrarCopia(format(L["Tus susurros con %s"], nombre), t, L["Solo tú ves esto. Cópialo con Ctrl+C; Esc para cerrar."])
	end
	local gente = Ch.Personas()
	if #gente == 0 then
		N.Imprimir(L["Todavía no hay susurros guardados. Se guardan mientras «Susurros a la vista» está encendido."])
		return false
	end
	if #gente == 1 or not (dueno and K.Menu) then return Ch.VerSusurros(nil, gente[1].nombre) end
	local opciones = {}
	for _, g in ipairs(gente) do
		opciones[#opciones + 1] = { valor = g.nombre, texto = g.nombre .. "  " .. K.Tenir("textoTenue", N.Plural(g.n, L["%d línea"], L["%d líneas"])) }
	end
	K.Menu(dueno, opciones, nil, function(v) Ch.VerSusurros(nil, v) end, 240)
	return true
end

function Ch.VerFiltrado()
	if #filtrados == 0 then
		N.Imprimir(L["El filtro de spam no ha escondido nada en esta sesión."])
		return false
	end
	local lineas = {}
	for i = #filtrados, 1, -1 do
		local f = filtrados[i]
		local cuando = date and date("%H:%M", f.t) or ""
		local por = f.motivo == "oro" and L["venta de oro"] or L["repetido"]
		lineas[#lineas + 1] = format("[%s] %s (%s): %s", cuando, f.quien, por, sinCodigos(f.texto))
	end
	return mostrarCopia(L["Lo que escondió el filtro de spam"], table.concat(lineas, "\n"),
		L["Solo esta sesión, lo más nuevo arriba. Nada se borró del juego: solo no salió en tu chat."])
end

---------------------------------------------------------------------------
-- El filtro de mensajes
---------------------------------------------------------------------------
local EVENTOS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM" }
local SIN_ENLACES = { CHAT_MSG_LOOT = true, CHAT_MSG_SYSTEM = true }

function Ch.Filtro(_, evento, msg, quien, ...)
	if secreto(msg) or type(msg) ~= "string" then return false end
	local lineID, guid = select(9, ...), select(10, ...)
	if Ch.Spam(evento, msg, quien, lineID, guid) then return true end
	local nuevo = msg
	if M.Get("chatCopiar") and not SIN_ENLACES[evento] then nuevo = Ch.ConEnlaces(nuevo) end
	if horaPropia and M.Get("chatHora") then nuevo = Ch.ConHora(nuevo) end
	if nuevo ~= msg then return false, nuevo, quien, ... end
	return false
end

local filtrosListos = false
local function engancharFiltros()
	if filtrosListos then return true end
	local CU = rawget(_G, "ChatFrameUtil")
	local add = type(CU) == "table" and CU.AddMessageEventFilter or nil
	if type(add) ~= "function" then add = rawget(_G, "ChatFrame_AddMessageEventFilter") end
	if type(add) ~= "function" then return false end
	filtrosListos = true
	for _, ev in ipairs(EVENTOS) do pcall(add, ev, Ch.Filtro) end
	return true
end
Ch.EngancharFiltros = engancharFiltros

local function alSusurro(evento, msg, quien, ...)
	if not M.Get("susurros") then return end
	local mio = evento == "CHAT_MSG_WHISPER_INFORM"
	-- Lo que el filtro de spam esconde tampoco se guarda ni suena.
	if not mio and Ch.Spam(evento, msg, quien, select(9, ...), select(10, ...)) then return end
	if Ch.Anotar(quien, msg, mio) and not mio then sonar(texto(quien)) end
end

local eventosSusurro = false
local function aplicar()
	local alguno = M.Get("chatHora") or M.Get("chatCopiar") or M.Get("spam")
	aplicarHora()
	aplicarClase()
	aplicarCopiar()
	if alguno then engancharFiltros() end
	if M.Get("susurros") and not eventosSusurro then
		eventosSusurro = true
		A.RegisterEvent("CHAT_MSG_WHISPER", function(...) M.Seguro(alSusurro, ...) end)
		A.RegisterEvent("CHAT_MSG_WHISPER_INFORM", function(...) M.Seguro(alSusurro, ...) end)
	end
end
Ch.Aplicar = aplicar

M.AlCambiar({ "chatHora", "chatClase", "chatCopiar", "susurros", "susurrosSonido", "spam", "spamRepetidos" }, aplicar)

A.RegisterCommand("copiar", function() Ch.CopiarVentana() end, L["copia las últimas líneas de tu chat (nada se envía)"])
A.RegisterCommand("susurros", function(arg)
	arg = texto(arg)
	if arg and arg ~= "" then
		if not Ch.VerSusurros(nil, strtrim and strtrim(arg) or arg) then N.Imprimir(format(L["No hay susurros guardados con %s."], arg)) end
	else
		Ch.VerSusurros(nil)
	end
end, L["tus susurros guardados, por persona"])
A.RegisterCommand("filtrado", function() Ch.VerFiltrado() end, L["lo que escondió el filtro de spam"])

-- Para pruebas.
Ch.Filtrados = filtrados
Ch.Decisiones = decisiones
Ch.Botones = botones
Ch.HoraPropia = function() return horaPropia end
