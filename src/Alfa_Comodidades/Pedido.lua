-- Alfa - Comodidades: invitar a quien te lo pide por susurro (1.4.2).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Armas el grupo y te llueven los «inv»: con «invitarSusurro» (de fábrica,
-- apagado) Alfa invita a tu grupo a quien te susurra solo eso («inv», «invi»,
-- «invitar», «invítame», «invite», «inv pls»…). Nada más: un mensaje con más
-- palabras no cuenta. De fábrica, solo a tus amigos, tu hermandad y tus amigos
-- de Battle.net; «invitarSusurroTodos» (apagado) también a quien no conoces.
-- No invita si no eres líder (o ayudante en banda), si tu grupo de 5 está
-- lleno o si ya está contigo: te lo dice en tu chat. Nada se le contesta a
-- nadie (regla 3 de docs/REGLAS-BLIZZARD.md): solo la invitación, que es la
-- del juego (C_PartyInfo.InviteUnit, sin restricciones en su documentación).
-- Un mensaje o un nombre secreto no se lee.
--
--   Pe.EsPedido(msg) -> bool       Pe.AlSusurro(evento, msg, quien, ...) -> lo que hizo
--   Pe.Confianza(guid) -> bool

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local Pe = {}
M.Pedido = Pe

local type, pcall, format, select, lower, gsub = type, pcall, string.format, select, string.lower, string.gsub

local ESPERA = 10 -- s entre dos invitaciones a la misma persona

local PALABRAS = {
	inv = true, invi = true, invit = true, invite = true, invitar = true, invitame = true,
	inviteme = true, invitacion = true, ["inv pls"] = true, ["inv plz"] = true, ["inv please"] = true,
	["inv porfa"] = true, ["inv por favor"] = true, ["invitame porfa"] = true, ["invitame por favor"] = true,
	["inv me"] = true, ["invite me"] = true, ["inv me pls"] = true, ["invite me pls"] = true,
}
Pe.PALABRAS = PALABRAS

local secreto = N.Secreto
local function texto(v) return type(v) == "string" and not secreto(v) and v ~= "" and v or nil end
local function ahora() return GetTime and GetTime() or 0 end

local ACENTOS = { ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u" }

function Pe.EsPedido(msg)
	msg = texto(msg)
	if not msg or #msg > 40 then return false end
	local s = lower(msg)
	for de, a in pairs(ACENTOS) do s = gsub(s, de, a) end
	s = gsub(s, "[%p¡¿]", " ")
	s = gsub(s, "%s+", " ")
	s = gsub(s, "^ ", "")
	s = gsub(s, " $", "")
	return PALABRAS[s] and true or false
end

function Pe.Confianza(guid)
	guid = texto(guid)
	if not guid then return false end
	local F = rawget(_G, "C_FriendList")
	if type(F) == "table" and N.SiJuego(F.IsFriend, guid) then return true end
	if N.SiJuego(rawget(_G, "IsGuildMember"), guid) then return true end
	local B = rawget(_G, "C_BattleNet")
	if type(B) == "table" and type(B.GetGameAccountInfoByGUID) == "function" then
		local ok, info = pcall(B.GetGameAccountInfoByGUID, guid)
		if ok and type(info) == "table" then return true end
	end
	return false
end

local function enMiGrupo(nombre)
	for _, fn in ipairs({ "UnitInParty", "UnitInRaid" }) do
		if N.SiJuego(rawget(_G, fn), nombre) then return true end
	end
	return false
end

local function puedoInvitar()
	if not N.SiJuego(rawget(_G, "IsInGroup")) then return true end
	if N.SiJuego(rawget(_G, "UnitIsGroupLeader"), "player") then
		if N.SiJuego(rawget(_G, "IsInRaid")) then return true end
		local fn = rawget(_G, "GetNumGroupMembers")
		local ok, v = pcall(fn)
		local n = ok and N.LeerNumero(v, 0) or 0
		return n < 5, "lleno"
	end
	if N.SiJuego(rawget(_G, "IsInRaid")) and N.SiJuego(rawget(_G, "UnitIsGroupAssistant"), "player") then return true end
	return false, "lider"
end

local ultima = {}

function Pe.AlSusurro(_, msg, quien, ...)
	if not M.Get("invitarSusurro") then return nil end
	quien = texto(quien)
	if not quien or not Pe.EsPedido(msg) then return nil end
	local guid = select(10, ...)
	if not M.Get("invitarSusurroTodos") and not Pe.Confianza(guid) then return "desconocido" end
	local destino = quien
	if Ambiguate then
		local ok, v = pcall(Ambiguate, quien, "none")
		if ok and texto(v) then destino = v end
	end
	if enMiGrupo(destino) then return "ya" end
	local t = ahora()
	if ultima[destino] and t - ultima[destino] < ESPERA then return "espera" end
	ultima[destino] = t
	local si, por = puedoInvitar()
	if not si then
		if por == "lleno" then
			N.Imprimir(format(L["%s te pidió que lo invites, pero tu grupo está lleno."], destino))
		else
			N.Imprimir(format(L["%s te pidió que lo invites, pero no eres líder del grupo."], destino))
		end
		return por
	end
	local P = rawget(_G, "C_PartyInfo")
	local ok = false
	if type(P) == "table" and type(P.InviteUnit) == "function" then ok = pcall(P.InviteUnit, destino)
	elseif type(rawget(_G, "InviteUnit")) == "function" then ok = pcall(InviteUnit, destino) end
	if ok then N.Imprimir(format(L["Invité a %s a tu grupo: te lo pidió por susurro."], destino)) end
	return ok and "invitado" or "fallo"
end

local registrado = false
M.AlCambiar({ "invitarSusurro" }, function()
	if registrado or not M.Get("invitarSusurro") then return end
	registrado = true
	A.RegisterEvent("CHAT_MSG_WHISPER", function(...) M.Seguro(Pe.AlSusurro, ...) end)
end)
