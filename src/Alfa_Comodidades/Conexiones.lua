-- Alfa - Comodidades: quién se conecta, con su nivel, su clase y dónde anda (1.4.2).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- El juego dice «[Ana] se ha conectado.» y nada más: para saber si está en tu
-- zona o a qué nivel va hay que abrir la lista de amigos o la de la hermandad.
-- Con «conexiones» (de fábrica, sí) la misma línea de tu chat sigue con lo que
-- el juego ya sabe de esa persona:
--   [Ana] se ha conectado. (Guerrera 42 · Durotar · «la del tanque») [Invitar]
--   * de tus amigos (C_FriendList.GetFriendInfo: nivel, clase, zona y tu nota);
--   * si no, de tu hermandad (GetNumGuildMembers / GetGuildRosterInfo, la lista
--     que el juego ya tiene; no se pide nada al servidor por cada línea);
--   * «[Invitar]» (conexionesInvitar, de fábrica, sí): un enlace de Alfa que con
--     un clic la invita a tu grupo (C_PartyInfo.InviteUnit, sin restricciones
--     en la documentación del juego). Solo con tu clic.
-- Todo es solo en TU chat: nada se manda a nadie. Un mensaje secreto pasa tal
-- cual. El molde sale del texto del juego (ERR_FRIEND_ONLINE_SS), así sirve en
-- cualquier idioma.
--
--   Co.Molde() -> patrón ; Co.Nombre(msg) -> nombre | nil
--   Co.Info(nombre) -> { nivel, clase, zona, nota, de = "amigo"|"hermandad" } | nil
--   Co.Linea(msg) -> la línea con lo nuevo | nil ; Co.Filtro(self, evento, msg, ...)
--   Co.AlEnlace(link) -> true si era de Alfa (el clic en «Invitar»)

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local Co = {}
M.Conexiones = Co

local type, pcall, tostring, tonumber, format, select = type, pcall, tostring, tonumber, string.format, select
local gsub, sub, lower, find, concat = string.gsub, string.sub, string.lower, string.find, table.concat

local PREFIJO = "addon:alfainvitar:"
local MOLDE_INGLES = "|Hplayer:%s|h[%s]|h has come online."
local MAX_HERMANDAD = 1000

local secreto = N.Secreto
local function texto(v) return type(v) == "string" and not secreto(v) and v ~= "" and v or nil end
local function numero(v) return N.LeerNumero(v) end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok then return nil end
	return v
end

---------------------------------------------------------------------------
-- El molde del mensaje del juego
---------------------------------------------------------------------------
local molde, de
function Co.Molde()
	local base = texto(rawget(_G, "ERR_FRIEND_ONLINE_SS")) or MOLDE_INGLES
	if molde and de == base then return molde end
	local p = gsub(base, "([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1")
	p = gsub(p, "%%%%%d%%%$s", "(.-)")
	p = gsub(p, "%%%%s", "(.-)")
	molde, de = "^" .. p .. "$", base
	return molde
end

function Co.Nombre(msg)
	msg = texto(msg)
	if not msg then return nil end
	local nombre = msg:match(Co.Molde())
	return texto(nombre)
end

---------------------------------------------------------------------------
-- Lo que se sabe de esa persona
---------------------------------------------------------------------------
local function corto(nombre)
	nombre = texto(nombre)
	if not nombre then return nil end
	return lower(nombre:match("^([^%-]+)") or nombre)
end
Co.Corto = corto

local function deAmigos(nombre)
	local F = rawget(_G, "C_FriendList")
	if type(F) ~= "table" then return nil end
	local info = llamar(F.GetFriendInfo, nombre)
	if type(info) ~= "table" then
		local base = nombre:match("^([^%-]+)")
		if base and base ~= nombre then info = llamar(F.GetFriendInfo, base) end
	end
	if type(info) ~= "table" then return nil end
	return { de = "amigo", nivel = numero(info.level), clase = texto(info.className), zona = texto(info.area), nota = texto(info.notes) }
end

local function deHermandad(nombre)
	if not N.SiJuego(rawget(_G, "IsInGuild")) then return nil end
	local total = numero(llamar(rawget(_G, "GetNumGuildMembers")))
	local leer = rawget(_G, "GetGuildRosterInfo")
	if not total or type(leer) ~= "function" then return nil end
	local busco = corto(nombre)
	for i = 1, math.min(total, MAX_HERMANDAD) do
		local ok, n, _, _, nivel, clase, zona, nota = pcall(leer, i)
		if ok and corto(n) == busco then
			return { de = "hermandad", nivel = numero(nivel), clase = texto(clase), zona = texto(zona), nota = texto(nota) }
		end
	end
	return nil
end

function Co.Info(nombre)
	nombre = texto(nombre)
	if not nombre then return nil end
	return deAmigos(nombre) or deHermandad(nombre)
end

---------------------------------------------------------------------------
-- La línea
---------------------------------------------------------------------------
local function enlaceInvitar(nombre)
	return "|cff8be04e|H" .. PREFIJO .. nombre .. "|h[" .. L["Invitar"] .. "]|h|r"
end
Co.EnlaceInvitar = enlaceInvitar

function Co.Linea(msg)
	if not M.Get("conexiones") then return nil end
	local nombre = Co.Nombre(msg)
	if not nombre then return nil end
	local info = Co.Info(nombre)
	local partes = {}
	if info then
		if info.clase and info.nivel and info.nivel > 0 then partes[#partes + 1] = format("%s %d", info.clase, info.nivel)
		elseif info.nivel and info.nivel > 0 then partes[#partes + 1] = format(L["nivel %d"], info.nivel)
		elseif info.clase then partes[#partes + 1] = info.clase end
		if info.zona then partes[#partes + 1] = info.zona end
		if info.nota then partes[#partes + 1] = "«" .. info.nota .. "»" end
	end
	local extra = ""
	if #partes > 0 then extra = " |cff9d9d9d(" .. concat(partes, " \194\183 ") .. ")|r" end
	if M.Get("conexionesInvitar") then extra = extra .. " " .. enlaceInvitar(nombre) end
	if extra == "" then return nil end
	return msg .. extra
end

function Co.Filtro(_, evento, msg, ...)
	if evento ~= "CHAT_MSG_SYSTEM" or type(msg) ~= "string" or secreto(msg) then return false end
	local ok, nuevo = pcall(Co.Linea, msg)
	if ok and type(nuevo) == "string" and nuevo ~= msg then return false, nuevo, ... end
	return false
end

---------------------------------------------------------------------------
-- El clic en «Invitar»
---------------------------------------------------------------------------
function Co.Invitar(nombre)
	nombre = texto(nombre)
	if not nombre then return false end
	local P = rawget(_G, "C_PartyInfo")
	local ok = false
	if type(P) == "table" and type(P.InviteUnit) == "function" then
		ok = pcall(P.InviteUnit, nombre)
	elseif type(rawget(_G, "InviteUnit")) == "function" then
		ok = pcall(InviteUnit, nombre)
	end
	if ok then N.Imprimir(format(L["Invitación enviada a %s."], nombre)) end
	return ok and true or false
end

function Co.AlEnlace(link)
	link = texto(link)
	if not link or sub(link, 1, #PREFIJO) ~= PREFIJO then return false end
	Co.Invitar(sub(link, #PREFIJO + 1))
	return true
end

---------------------------------------------------------------------------
-- Engancharse (una vez, al encenderlo)
---------------------------------------------------------------------------
local listo = false
local function enganchar()
	if listo then return end
	local CU = rawget(_G, "ChatFrameUtil")
	local add = type(CU) == "table" and CU.AddMessageEventFilter or nil
	if type(add) ~= "function" then add = rawget(_G, "ChatFrame_AddMessageEventFilter") end
	if type(add) ~= "function" then return end
	listo = true
	pcall(add, "CHAT_MSG_SYSTEM", Co.Filtro)
	local ER = rawget(_G, "EventRegistry")
	if type(ER) == "table" and type(ER.RegisterCallback) == "function" then
		pcall(ER.RegisterCallback, ER, "SetItemRef", function(_, l) M.Seguro(Co.AlEnlace, l) end, Co)
	elseif type(rawget(_G, "SetItemRef")) == "function" then
		hooksecurefunc("SetItemRef", function(l) M.Seguro(Co.AlEnlace, l) end)
	end
end
Co.Enganchar = enganchar

M.AlCambiar({ "conexiones", "conexionesInvitar" }, function()
	if M.Get("conexiones") then enganchar() end
end)
