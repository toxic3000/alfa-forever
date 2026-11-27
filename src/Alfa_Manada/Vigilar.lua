-- Alfa - La Jauría: «Avisarme cuando se conecte» (1.4.2). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Esperas a alguien para la mazmorra, para darle algo o para cazar juntos y
-- su «se ha conectado» se pierde en el chat. Clic derecho en un jugador (su
-- retrato, su nombre en el chat, tu grupo o tu hermandad) > «Avisarme cuando
-- se conecte»: cuando entre, un aviso (o Lya, si está a la vista) te lo dice
-- con «Susurrar» e «Invitar» a un clic. Al entrar tú, si alguno ya estaba
-- conectado, también te lo dice (una vez). Mismo menú: «Ya no avisarme».
-- También /alfa avisame <nombre> (sin nombre: a quién vigilas).
-- El juego solo avisa de tus amigos y de tu hermandad (ERR_FRIEND_ONLINE_SS):
-- si no es ninguno, Alfa te lo dice al agregarlo. Nada se envía a nadie.
-- Se guarda por cuenta (AlfaNucleoDB.manada.vigilados, hasta MAX). Ajuste
-- manada.vigilar (de fábrica, sí): la opción del menú y los avisos.
--
--   Vi.Esta(nombre) -> bool ; Vi.Poner(nombre, si, unit) ; Vi.Lista() -> { { clave, nombre, t } }
--   Vi.Nombre(msg) -> nombre | nil (de la línea «se ha conectado»)
--   Vi.AlSistema(msg) -> el aviso | nil ; Vi.YaConectados() -> { nombre }

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Vi = {}
M.Vigilar = Vi

local type, pcall, format, ipairs, pairs, concat, sort = type, pcall, string.format, ipairs, pairs, table.concat, table.sort
local gsub, lower = string.gsub, string.lower

local MAX = 50
local OTRA_VEZ = 60 -- s: el mismo lobo no avisa dos veces seguidas
local MOLDE_INGLES = "|Hplayer:%s|h[%s]|h has come online."

A.RegisterDefaults(ID, { vigilar = true })

local function on() return N.Get(ID, "vigilar") ~= false end
local secreto = N.Secreto
local function texto(v) return type(v) == "string" and not secreto(v) and v ~= "" and v or nil end

local function datos()
	local d = N.Datos(ID)
	d.vigilados = type(d.vigilados) == "table" and d.vigilados or {}
	return d.vigilados
end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok then return nil end
	return U.Leer(v)
end

---------------------------------------------------------------------------
-- La lista
---------------------------------------------------------------------------
function Vi.Esta(nombre)
	local c = U.Clave(nombre)
	return c ~= nil and datos()[c] ~= nil
end

function Vi.Lista()
	local out = {}
	for c, x in pairs(datos()) do
		if type(x) == "table" then out[#out + 1] = { clave = c, nombre = x.nombre or c, t = x.t or 0 } end
	end
	sort(out, function(a, b) return U.Plegar(a.nombre) < U.Plegar(b.nombre) end)
	return out
end

-- ¿El juego me avisa de esta persona? (amigo o de tu hermandad)
function Vi.ElJuegoAvisa(nombre, unit)
	local F = rawget(_G, "C_FriendList")
	if type(F) == "table" and type(llamar(F.GetFriendInfo, U.Destino(nombre) or nombre)) == "table" then return true end
	if unit and llamar(rawget(_G, "UnitIsInMyGuild"), unit) then return true end
	local G = rawget(_G, "C_GuildInfo")
	if type(G) == "table" and llamar(G.MemberExistsByName, U.Destino(nombre) or nombre) then return true end
	return false
end

function Vi.Poner(nombre, si, unit)
	local c = U.Clave(nombre)
	if not c then return false end
	local d = datos()
	if not si then
		d[c] = nil
		U.Decir(format(L["Listo: ya no te aviso cuando %s se conecte."], U.Mostrar(nombre)))
		return true
	end
	local n = 0
	for _ in pairs(d) do n = n + 1 end
	if not d[c] and n >= MAX then
		U.Decir(format(L["Ya vigilas a %d lobos: quita a alguno con /alfa avisame <nombre>."], MAX))
		return false
	end
	d[c] = { nombre = U.Mostrar(nombre), t = time and time() or 0 }
	U.Decir(format(L["Listo: te aviso cuando %s se conecte."], U.Mostrar(nombre)))
	if not Vi.ElJuegoAvisa(nombre, unit) then
		U.Decir(L["Ojo: el juego solo me avisa de tus amigos y de tu hermandad. Agrégalo a tus amigos para que te avise."])
	end
	return true
end

---------------------------------------------------------------------------
-- «se ha conectado»
---------------------------------------------------------------------------
local molde, de
local function elMolde()
	local base = texto(rawget(_G, "ERR_FRIEND_ONLINE_SS")) or MOLDE_INGLES
	if molde and de == base then return molde end
	local p = gsub(base, "([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1")
	p = gsub(p, "%%%%%d%%%$s", "(.-)")
	p = gsub(p, "%%%%s", "(.-)")
	molde, de = "^" .. p, base
	return molde
end

function Vi.Nombre(msg)
	msg = texto(msg)
	if not msg then return nil end
	return texto(msg:match(elMolde()))
end

local avisados = {}

local function avisar(nombre, texto2)
	local mostrar = U.Mostrar(nombre)
	return U.Aviso({
		titulo = format(L["%s se conectó"], mostrar),
		texto = texto2 or L["Me pediste que te avisara."],
		icono = "ic-manada", duracion = 20, prioridad = 2,
		acciones = {
			{ texto = L["Susurrar"], alClic = function() U.Susurrar(nombre) end },
			{ texto = L["Invitar"], alClic = function() U.Invitar(nombre) end },
		},
	})
end

function Vi.AlSistema(msg)
	if not on() then return nil end
	local nombre = Vi.Nombre(msg)
	if not nombre or not Vi.Esta(nombre) then return nil end
	local c = U.Clave(nombre)
	local t = U.Ahora()
	if avisados[c] and t - avisados[c] < OTRA_VEZ then return nil end
	avisados[c] = t
	return avisar(nombre) or true
end

---------------------------------------------------------------------------
-- Al entrar: quién ya estaba conectado
---------------------------------------------------------------------------
function Vi.YaConectados()
	local out, ya = {}, {}
	local d = datos()
	if next(d) == nil then return out end
	local F = rawget(_G, "C_FriendList")
	if type(F) == "table" then
		local n = N.LeerNumero(llamar(F.GetNumFriends), 0)
		for i = 1, math.min(n, 200) do
			local info = llamar(F.GetFriendInfoByIndex, i)
			if type(info) == "table" and U.Leer(info.connected) then
				local c = U.Clave(info.name)
				if c and d[c] and not ya[c] then ya[c] = true out[#out + 1] = U.Mostrar(info.name) end
			end
		end
	end
	if N.SiJuego(rawget(_G, "IsInGuild")) then
		local total = N.LeerNumero(llamar(rawget(_G, "GetNumGuildMembers")), 0)
		local leer = rawget(_G, "GetGuildRosterInfo")
		for i = 1, math.min(total, 1000) do
			local ok, nombre, _, _, _, _, _, _, _, conectado = pcall(leer, i)
			if ok and U.Leer(conectado) then
				local c = U.Clave(nombre)
				if c and d[c] and not ya[c] then ya[c] = true out[#out + 1] = U.Mostrar(nombre) end
			end
		end
	end
	sort(out, function(a, b) return U.Plegar(a) < U.Plegar(b) end)
	return out
end

function Vi.DecirYaConectados()
	if not on() then return nil end
	local lista = Vi.YaConectados()
	if #lista == 0 then return nil end
	local t = U.Ahora()
	for _, n in ipairs(lista) do avisados[U.Clave(n)] = t end
	if #lista == 1 then return avisar(lista[1], L["Ya estaba conectado cuando entraste."]) or true end
	return U.Aviso({ titulo = L["Ya andan conectados"], texto = concat(lista, ", "), icono = "ic-manada", duracion = 15 }) or true
end

---------------------------------------------------------------------------
-- El menú del clic derecho
---------------------------------------------------------------------------
Vi.MENUS = {
	"MENU_UNIT_PLAYER", "MENU_UNIT_FOCUS", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID",
	"MENU_UNIT_FRIEND", "MENU_UNIT_CHAT_ROSTER", "MENU_UNIT_COMMUNITIES_WOW_MEMBER",
	"MENU_UNIT_COMMUNITIES_GUILD_MEMBER", "MENU_UNIT_GUILD",
}

-- Una sola línea antes de lo de Alfa en el menú, aunque varias partes de Alfa
-- agreguen lo suyo (1.4.2): la primera la pone, las demás no.
local function lineaAlfa(raiz)
	local t = rawget(_G, "AlfaMenuLinea")
	if not t then t = setmetatable({}, { __mode = "k" }) AlfaMenuLinea = t end
	if t[raiz] then return end
	t[raiz] = true
	if raiz.CreateDivider then raiz:CreateDivider() end
end

function Vi.Armar(_, raiz, contexto)
	if not on() then return end
	if type(raiz) ~= "table" or type(raiz.CreateButton) ~= "function" then return end
	local I = M.Invitar
	local persona = I and I.Persona and I.Persona(contexto)
	if not persona then return end
	local esta = Vi.Esta(persona.nombre)
	lineaAlfa(raiz)
	raiz:CreateButton(esta and L["Ya no avisarme cuando se conecte"] or L["Avisarme cuando se conecte"], function()
		Vi.Poner(persona.nombre, not esta, persona.unit)
	end)
end

local enganchado = false
function Vi.Enganchar()
	if enganchado then return end
	if A.GamepadUI and A.GamepadUI() then return end
	local Menu = rawget(_G, "Menu")
	if not (type(Menu) == "table" and type(Menu.ModifyMenu) == "function") then return end
	enganchado = true
	for _, etiqueta in ipairs(Vi.MENUS) do
		Menu.ModifyMenu(etiqueta, function(_, raiz, contexto) pcall(Vi.Armar, etiqueta, raiz, contexto) end)
	end
end

A.OnLogin(Vi.Enganchar)
A.RegisterEvent("CHAT_MSG_SYSTEM", function(_, msg) pcall(Vi.AlSistema, msg) end)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, inicial)
	if inicial then N.Una("manada.vigilar.entrar", 40, function() pcall(Vi.DecirYaConectados) end) end
end)

A.RegisterCommand("avisame", function(rest)
	local nombre = texto(rest and rest:gsub("^%s+", ""):gsub("%s+$", "") or nil)
	if nombre then return Vi.Poner(nombre, not Vi.Esta(nombre)) end
	local lista = Vi.Lista()
	if #lista == 0 then
		U.Decir(L["No esperas a nadie. Clic derecho en un jugador > «Avisarme cuando se conecte», o /alfa avisame <nombre>."])
		return
	end
	local nombres = {}
	for _, x in ipairs(lista) do nombres[#nombres + 1] = x.nombre end
	U.Decir(format(L["Te aviso cuando se conecten: %s. Para quitar a alguien: /alfa avisame <nombre>."], concat(nombres, ", ")))
end, L["te avisa cuando un amigo o alguien de tu hermandad se conecta"])
