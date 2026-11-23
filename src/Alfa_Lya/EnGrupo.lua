-- Alfa - Lya: las Lyas de tu grupo se saludan (1.3.0). toxic3000 / La Jauría.
-- GPL-3.0.
--
--   lya.manada (prendido de fábrica): si alguien de tu grupo también trae
--   Alfa, su Lya y la tuya se saludan al juntarse y, de vez en cuando, platican
--   entre ellas (tu Lya dice una parte y la suya contesta).
--
-- Mensajes de addon ocultos, nunca un canal ni el chat que se lee. Por la red
-- de La Jauría (AlfaManada.Red, tipo 1Y, reservado para Lya): un susurro oculto
-- a cada compañero del grupo (como mucho 4). Sin esa API, con el prefijo
-- propio "AlfaLya" al grupo o banda (PARTY/RAID). Lo que se dice:
--   H                   "hola": al juntarse (una vez por compañero y sesión)
--   R                   "hola de vuelta": a un H (nunca responde a un R)
--   C|<n>               una plática: tu Lya dijo la parte n; la suya contesta
-- (por la red: 1Y|H, 1Y|R, 1Y|C|n; con el prefijo propio: 1H, 1R, 1C|n).
-- Ligero y raro: un saludo por compañero por sesión, una plática cada
-- PLATICA segundos como mucho (y solo a veces, al entregar una misión), lo que
-- llega se acepta una vez cada ESCUCHA segundos por persona. Nada en combate
-- ni dentro de instancias. (1.3.1) Nada a quien está desconectado, y la
-- respuesta R va solo a quien saludó.
--
--   Gr.Mensaje(texto, canal, emisor)  (lo que llega; para pruebas)
--   Gr.Platicar()  Gr.Saludar()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local type, tonumber, pcall, ipairs, format = type, tonumber, pcall, ipairs, string.format
local random = math.random

local Gr = {}
M.EnGrupo = Gr

Gr.PREFIJO = "AlfaLya"
local PLATICA = 30 * 60   -- s entre dos pláticas tuyas
local ESCUCHA = 5 * 60    -- s entre dos mensajes aceptados de una misma persona
local PROB_PLATICA = 0.25 -- al entregar una misión en grupo

local function ahora() return GetTime and GetTime() or 0 end
local function secreto(v) return issecretvalue ~= nil and type(v) ~= "nil" and issecretvalue(v) and true or false end
local function activo() return N.Get(ID, "manada") ~= false end

-- Las pláticas: lo que dice tu Lya y lo que contesta la otra.
Gr.PLATICAS = {
	{ "¿Ya viste cómo caza %s? Me cae bien.", "Y la tuya tampoco se queda atrás, ¿eh?" },
	{ "Oye, ¿a la tuya también le gustan las salchichas?", "¡Le encantan! Pero las mías son más ricas." },
	{ "Esta zona huele a aventura. ¿Tú qué hueles?", "Huelo a botín... y a una que otra salchicha." },
	{ "Cuida bien a %s, que la manada lo necesita.", "Tranquila, aquí nadie se queda atrás." },
	{ "¡Auuu! Juntas cazamos mejor.", "¡Auuuu! La manada unida no se rinde." },
}

local function enInstancia()
	if not IsInInstance then return false end
	local ok, dentro = pcall(IsInInstance)
	return ok and not secreto(dentro) and dentro == true
end
local function enCombate()
	return (InCombatLockdown and InCombatLockdown()) and true or false
end

local function canal()
	if IsInRaid and IsInRaid() then return "RAID" end
	if IsInGroup and IsInGroup() then return "PARTY" end
	return nil
end

local prefijoListo = false
local function prefijo()
	if prefijoListo or not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
	local esta = C_ChatInfo.IsAddonMessagePrefixRegistered
	if esta and esta(Gr.PREFIJO) then prefijoListo = true return end
	local ok, r = pcall(C_ChatInfo.RegisterAddonMessagePrefix, Gr.PREFIJO)
	if esta then prefijoListo = esta(Gr.PREFIJO) and true or false
	else prefijoListo = ok and r ~= false end
end

-- La red de La Jauría (Alfa_Manada, 1.3.0), si está.
local function red()
	local Ma = rawget(_G, "AlfaManada")
	local R = type(Ma) == "table" and rawget(Ma, "Red")
	if type(R) == "table" and type(R.EnviarLibre) == "function" and type(R.Escuchar) == "function" then return R end
	return nil
end
Gr.Red = red

local function puede()
	if not activo() or enCombate() or enInstancia() then return false end
	if canal() == nil then return false end
	if red() then return true end
	return C_ChatInfo ~= nil and C_ChatInfo.SendAddonMessage ~= nil
end

-- 1.3.1: un compañero desconectado no recibe nada (el susurro haría que el
-- juego dijera «No hay ningún jugador llamado...»). Lo que no se sabe, sí.
local function conectado(u)
	if not UnitIsConnected then return true end
	local ok, si = pcall(UnitIsConnected, u)
	if not ok or secreto(si) then return true end
	return si ~= false
end

-- Los compañeros conectados del grupo (nombre-reino), para el susurro oculto.
local function companeros()
	local out = {}
	for i = 1, 4 do
		local n, reino
		if UnitName then n, reino = UnitName("party" .. i) end
		if type(n) == "string" and not secreto(n) and n ~= "" and not secreto(reino) and conectado("party" .. i) then
			out[#out + 1] = (type(reino) == "string" and reino ~= "") and (n .. "-" .. reino) or n
		end
	end
	return out
end

-- texto: "H", "R" o "C|n". `solo` (1.3.1): por la red, solo a esa persona
-- (la respuesta a un saludo va a quien saludó, no a todo el grupo).
local function enviar(texto, solo)
	if not puede() then return false end
	local R = red()
	if R then
		local alguno = false
		local para = solo and { solo } or companeros()
		for _, quien in ipairs(para) do
			local ok, r = pcall(R.EnviarLibre, "lya:" .. texto:sub(1, 1) .. ":" .. quien, "Y", texto, quien)
			if ok and r then alguno = true end
		end
		return alguno
	end
	prefijo()
	local ok, r = pcall(C_ChatInfo.SendAddonMessage, Gr.PREFIJO, "1" .. texto, canal())
	local RES = Enum and Enum.SendAddonMessageResult
	return ok and (r == nil or r == true or r == (RES and RES.Success or 0))
end
Gr.Enviar = enviar

-- Solo de quien está en tu grupo o banda.
local function delGrupo(emisor)
	if type(emisor) ~= "string" then return false end
	local nombre = Ambiguate and Ambiguate(emisor, "none") or emisor
	local corto = nombre:gsub("%-.*$", "")
	for _, fn in ipairs({ UnitInParty, UnitInRaid }) do
		if type(fn) == "function" then
			for _, n in ipairs({ nombre, corto }) do
				local ok, si = pcall(fn, n)
				if ok and si and not secreto(si) then return true end
			end
		end
	end
	return false
end

local function corto(emisor)
	local n = Ambiguate and Ambiguate(emisor, "short") or emisor
	return (n:gsub("%-.*$", ""))
end

local function miNombre()
	local n = UnitName and UnitName("player")
	return (not secreto(n) and type(n) == "string") and n or ""
end

local function decir(texto, extra)
	local Ce = M.Cerebro
	if not (Ce and Ce.Decir) then return false end
	local c = { texto = texto, salto = true, cara = "feliz" }
	if extra then for k, v in pairs(extra) do c[k] = v end end
	return Ce.Decir(c)
end

---------------------------------------------------------------------------
-- Saludos
---------------------------------------------------------------------------
local saludados = {}   -- nombre -> true (esta sesión)
local oidoDe = {}      -- emisor -> GetTime del último aceptado
local ultimaPlatica = -1e9

function Gr.Saludar()
	if not puede() then return false end
	-- ¿Alguien nuevo en el grupo?
	local nuevo = false
	for i = 1, 4 do
		local u = "party" .. i
		local n = UnitName and UnitName(u)
		-- (1.3.1) A quien está desconectado se le saluda cuando vuelva.
		if type(n) == "string" and not secreto(n) and n ~= "" and not saludados[n] and conectado(u) then
			saludados[n] = true
			nuevo = true
		end
	end
	if not nuevo then return false end
	return enviar("H")
end

function Gr.Platicar()
	if not puede() or ahora() - ultimaPlatica < PLATICA then return false end
	local n = random(#Gr.PLATICAS)
	local p = Gr.PLATICAS[n]
	local ok, t = pcall(format, L[p[1]], miNombre())
	if not ok then return false end
	if decir(t, { id = "manadaPlatica" }) ~= true then return false end
	ultimaPlatica = ahora()
	enviar("C|" .. n)
	return true
end

-- Lo que llega (tipo "H" | "R" | "C", resto = n de la plática), de quien sea.
function Gr.Oir(tipo, resto, emisor)
	if not activo() or secreto(tipo) or secreto(resto) or secreto(emisor) then return false end
	if type(emisor) ~= "string" or type(tipo) ~= "string" then return false end
	local okYo, yo = pcall(function() return A.Compat and A.Compat.SenderIsMe and A.Compat.SenderIsMe(emisor) end)
	if (okYo and yo) or corto(emisor) == miNombre() then return false end
	if not delGrupo(emisor) or enCombate() or enInstancia() then return false end
	local t = oidoDe[emisor]
	if t and ahora() - t < ESCUCHA then return false end
	local quien = corto(emisor)
	if tipo == "H" or tipo == "R" then
		oidoDe[emisor] = ahora()
		saludados[quien] = true
		local frase = tipo == "H" and L["¡La Lya de %s me saludó! Entre lobas nos entendemos."]
			or L["¡La Lya de %s me contestó el saludo! Ya somos manada."]
		decir(format(frase, quien), { id = "manadaHola" })
		if tipo == "H" then enviar("R", emisor) end
		return true
	elseif tipo == "C" then
		local n = tonumber(resto)
		local p = n and Gr.PLATICAS[n]
		if not p then return false end
		oidoDe[emisor] = ahora()
		decir(format(L["La Lya de %s dice algo. Yo le contesto: «%s»"], quien, L[p[2]]), { id = "manadaPlatica" })
		return true
	end
	return false
end

-- Escucha el tipo Y de la red (una vez por red; se repite si la red cambia).
local escuchando
function Gr.Escuchar()
	local R = red()
	if not R or escuchando == R then return R ~= nil end
	local ok, si = pcall(R.Escuchar, "Y", Gr.DeLaRed, false)
	if ok and si then escuchando = R end
	return ok and si and true or false
end

-- Con el prefijo propio, solo del grupo o la banda: "1H", "1R", "1C|n".
function Gr.Mensaje(texto, canalDe, emisor)
	if secreto(texto) or type(texto) ~= "string" then return false end
	if canalDe ~= "PARTY" and canalDe ~= "RAID" then return false end
	local tipo, resto = texto:match("^1(%u)|?(.*)$")
	if not tipo then return false end
	return Gr.Oir(tipo, resto, emisor)
end

-- Por la red de La Jauría (1Y): campos = { "H" | "R" | "C", n }.
function Gr.DeLaRed(_, remitente, campos)
	if type(campos) ~= "table" then return false end
	return Gr.Oir(campos[1], campos[2] or "", remitente)
end

AlfaNucleo.PorPrefijo(Gr.PREFIJO, function(_, pre, texto, canalDe, emisor)
	if secreto(pre) or pre ~= Gr.PREFIJO then return end
	Gr.Mensaje(texto, canalDe, emisor)
end)

local pendiente = false
A.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	if not activo() or pendiente then return end
	pendiente = true
	-- Una espera al azar: que no salgan todos a la vez.
	A.After(3 + random(5), function()
		pendiente = false
		Gr.Saludar()
	end)
end)

A.RegisterEvent("QUEST_TURNED_IN", function()
	if canal() and random() < PROB_PLATICA then A.After(4, Gr.Platicar) end
end)

A.OnLogin(function()
	prefijo()
	Gr.Escuchar()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
		pcall(Lya.Ensenar, { id = "lya.manada", icono = "ic-manada", modulo = "lya",
			pregunta = L["¿Mi Lya conoce a las de mi grupo?"],
			respuesta = L["Si alguien de tu grupo también trae Alfa, nuestras Lyas se saludan al juntarse y a veces platican. Es poquito y nunca en combate. Se apaga en mi página: «Lya y su manada»."] })
	end
end)
