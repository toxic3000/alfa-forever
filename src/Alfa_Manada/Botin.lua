-- Alfa - La Jauría: el botín de la manada (1.3.0). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Cuando levantas un objeto que se puede regalar (se liga al equiparlo o no
-- se liga) y le queda a un lobo de tu hermandad conectado (por su clase y su
-- nivel), Alfa te lo sugiere: «¡Esto le sirve a Ana!» con «Regalárselo». El
-- clic abre el comercio si está a tu lado; si no, te dice que se lo mandes
-- por correo y, al abrir un buzón, su nombre ya está puesto. Nada se hace
-- solo.
--
-- Para saber a quién le sirve, los lobos que aceptan («Compartir mi clase y
-- nivel», manada.botinCompartir, apagado de fábrica) dicen su clase y su
-- nivel a la hermandad. Nada más.
--
-- Mensajes (Red.lua, solo por la hermandad):
--   1i|<nivel>|<CLASE>   mi clase y nivel (al entrar, al subir y cada REPITE)
--   1i|?                 ¿quién anda? (al entrar): responde quien comparte
-- Ajustes: manada.botin (sugerir regalos) y manada.botinCompartir.
--
--   Bo.Conocidos() -> { { clave, nombre, destino, nivel, clase } }  conectados
--   Bo.LeSirve(info, clase, nivel) -> true | false
--   Bo.Revisar(link) -> sugerencia | nil ; Bo.Sugerencias() ; Bo.Regalar(s)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Bo = {}
M.Botin = Bo

local type, tonumber, tostring, pairs, ipairs, pcall, format, sort = type, tonumber, tostring, pairs, ipairs, pcall, string.format, table.sort

local V = "1"
local REPITE = 600     -- tu clase y nivel, cada 10 minutos
local CONECTADO = 1500 -- sin noticias en 25 minutos, ya no cuenta
local VENTANA = 7      -- un objeto le sirve si pide hasta 7 niveles menos que el suyo
local CADA_AVISO = 60  -- un aviso de regalo por minuto como mucho
local MAX = 5          -- sugerencias guardadas para la página
local CARTA = 1800     -- el nombre para el correo vale media hora

local function on(clave) return N.Get(ID, clave) and true or false end
local function activo() return N.Get(ID, "botin") ~= false end
local function comparte() return on("botinCompartir") end

Bo.version = 0
local function cambio()
	Bo.version = Bo.version + 1
	if M.Avisar then M.Avisar() end
end

local function aviso(o)
	local K = N.Kit
	if K and K.Aviso then return K.Aviso(o) end
	U.Decir(o.titulo .. (o.texto and (" " .. o.texto) or ""))
end

---------------------------------------------------------------------------
-- Quién puede usar qué
---------------------------------------------------------------------------

local TELA, CUERO, MALLA, PLACAS, ESCUDO = 1, 2, 3, 4, 6
local ARMADURA = {
	WARRIOR = function(n) return n >= 40 and PLACAS or MALLA end,
	PALADIN = function(n) return n >= 40 and PLACAS or MALLA end,
	HUNTER = function(n) return n >= 40 and MALLA or CUERO end,
	SHAMAN = function(n) return n >= 40 and MALLA or CUERO end,
	ROGUE = function() return CUERO end,
	DRUID = function() return CUERO end,
	MAGE = function() return TELA end,
	PRIEST = function() return TELA end,
	WARLOCK = function() return TELA end,
}
local ESCUDOS = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local function lista(t) local s = {} for _, v in ipairs(t) do s[v] = true end return s end
local ARMAS = {
	WARRIOR = lista({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }),
	PALADIN = lista({ 0, 1, 4, 5, 6, 7, 8 }),
	HUNTER = lista({ 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 18 }),
	ROGUE = lista({ 2, 3, 4, 7, 13, 15, 16, 18 }),
	PRIEST = lista({ 4, 10, 15, 19 }),
	SHAMAN = lista({ 0, 1, 4, 5, 10, 13, 15 }),
	MAGE = lista({ 7, 10, 15, 19 }),
	WARLOCK = lista({ 7, 10, 15, 19 }),
	DRUID = lista({ 4, 5, 10, 13, 15 }),
}
-- Lo que le sirve a cualquiera.
local TODOS = { INVTYPE_CLOAK = true, INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true, INVTYPE_HOLDABLE = true }

-- info = { minNivel, clase (classID), sub (subclassID), hueco (equipLoc) }
function Bo.LeSirve(info, clase, nivel)
	if type(info) ~= "table" or not (clase and nivel) then return false end
	local pide = tonumber(info.minNivel) or 0
	if pide <= 1 or pide > nivel or pide < nivel - VENTANA then return false end
	if TODOS[info.hueco] then return true end
	if info.clase == 4 then
		if info.sub == ESCUDO then return ESCUDOS[clase] == true end
		local f = ARMADURA[clase]
		return f ~= nil and f(nivel) == info.sub
	elseif info.clase == 2 then
		local a = ARMAS[clase]
		return a ~= nil and a[info.sub] == true
	end
	return false
end

-- Lo que hace falta del objeto, o nil si no se puede regalar.
local function infoDe(link)
	if type(link) ~= "string" or U.Secreto(link) then return nil end
	local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	if type(fn) ~= "function" then return nil end
	local ok, nombre, enlace, calidad, _, minNivel, _, _, _, hueco, _, _, clase, sub, liga = pcall(fn, link)
	if not ok or not U.Texto(nombre) then return nil end
	calidad, minNivel, clase, sub, liga = U.Numero(calidad), U.Numero(minNivel), U.Numero(clase), U.Numero(sub), U.Numero(liga)
	hueco = U.Texto(hueco)
	if not (hueco and calidad and calidad >= 2) then return nil end
	-- 1 = se liga al recogerlo, 4 = de misión: no se puede regalar.
	if liga == 1 or liga == 4 then return nil end
	if hueco == "INVTYPE_BAG" or hueco == "INVTYPE_AMMO" or hueco == "INVTYPE_QUIVER" then return nil end
	return { nombre = nombre, link = U.Texto(enlace) or link, calidad = calidad, minNivel = minNivel or 0, clase = clase, sub = sub, hueco = hueco }
end
Bo.Info = infoDe

---------------------------------------------------------------------------
-- La manada conectada
---------------------------------------------------------------------------

local conocidos = {} -- clave -> { clave, nombre, destino, nivel, clase, at }

function Bo.Conocidos()
	local out, ahora = {}, U.Ahora()
	for clave, x in pairs(conocidos) do
		if ahora - x.at > CONECTADO then conocidos[clave] = nil
		else out[#out + 1] = x end
	end
	sort(out, function(a, b) return a.nombre < b.nombre end)
	return out
end

local function miNivelYClase()
	local nivel = UnitLevel and U.Numero(UnitLevel("player")) or 0
	local clase = ""
	if UnitClass then
		local _, file = UnitClass("player")
		file = U.Texto(file)
		if file and file:match("^%u+$") then clase = file end
	end
	return nivel or 0, clase
end

local ultimoEnvio = -math.huge
function Bo.Compartir(forzar)
	if not (comparte() and U.EnHermandad()) then return false end
	if not forzar and U.Ahora() - ultimoEnvio < REPITE then return false end
	local nivel, clase = miNivelYClase()
	if clase == "" then return false end
	if M.Red.EnviarHermandad("i", format("%si|%d|%s", V, nivel, clase)) then
		ultimoEnvio = U.Ahora()
		return true
	end
	return false
end

local respondiendo = false
M.Red.Oyentes.i = function(clave, remitente, _, f, canal)
	if canal ~= "GUILD" then return end
	if f[1] == "?" then
		if comparte() and not respondiendo and U.Ahora() - ultimoEnvio > 30 then
			respondiendo = true
			A.After(2 + math.random() * 6, function()
				respondiendo = false
				Bo.Compartir(true)
			end)
		end
		return
	end
	local s = f[1] or ""
	local nivel = s:match("^%d+$") and #s <= 3 and tonumber(s) or nil
	local clase = f[2] and f[2]:match("^%u+$") and #f[2] <= 12 and f[2] or nil
	if not (nivel and nivel >= 1 and nivel <= 200 and clase) then return end
	conocidos[clave] = { clave = clave, nombre = U.Mostrar(remitente), destino = remitente, nivel = nivel, clase = clase, at = U.Ahora() }
	cambio()
end
M.Red.Libres.i = true

---------------------------------------------------------------------------
-- Lo que levantas
---------------------------------------------------------------------------

local sugerencias = {} -- { link, nombre, para = { nombre, destino, clave }, at }
local dichos = {}      -- link -> true: ya sugerido en esta sesión
local ultimoAviso = -math.huge

function Bo.Sugerencias() return sugerencias end

-- A quién le sirve `link` (el de nivel más cercano), o nil.
function Bo.ParaQuien(link)
	local info = infoDe(link)
	if not info then return nil end
	local mejor, dif
	for _, x in ipairs(Bo.Conocidos()) do
		if Bo.LeSirve(info, x.clase, x.nivel) then
			local d = x.nivel - info.minNivel
			if not dif or d < dif or (d == dif and x.nombre < mejor.nombre) then mejor, dif = x, d end
		end
	end
	return mejor, info
end

function Bo.Revisar(link)
	if not activo() then return nil end
	if type(link) ~= "string" or dichos[link] then return nil end
	local x, info = Bo.ParaQuien(link)
	if not x then return nil end
	dichos[link] = true
	local s = { link = info.link, nombre = info.nombre, para = { nombre = x.nombre, destino = x.destino, clave = x.clave }, at = U.Ahora() }
	table.insert(sugerencias, 1, s)
	for i = #sugerencias, MAX + 1, -1 do sugerencias[i] = nil end
	cambio()
	local ahora = U.Ahora()
	if ahora - ultimoAviso >= CADA_AVISO then
		ultimoAviso = ahora
		aviso({
			titulo = format(L["¡Esto le sirve a %s!"], x.nombre),
			texto = format(L["%s le queda a su clase y su nivel (%d). ¿Se lo regalas?"], info.link, x.nivel),
			icono = "ic-bolsas",
			accion = { texto = L["Regalárselo"], alClic = function() Bo.Regalar(s) end },
		})
	end
	return s
end

-- Lo tuyo en el chat del botín: "Recibes botín: [objeto]."
local patrones
local function misPatrones()
	if patrones and #patrones > 0 then return patrones end
	patrones = {}
	for _, g in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }) do
		local s = rawget(_G, g)
		if type(s) == "string" and s:find("%s", 1, true) then
			s = s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)"):gsub("%%%%d", "%%d+")
			patrones[#patrones + 1] = "^" .. s .. "$"
		end
	end
	return patrones
end

function Bo.AlBotin(msg)
	if type(msg) ~= "string" or U.Secreto(msg) or not activo() then return end
	local mio = false
	for _, p in ipairs(misPatrones()) do
		if msg:match(p) then mio = true break end
	end
	if not mio then return end
	local link = msg:match("(|c%x+|Hitem:.-|h.-|h|r)")
	if link then Bo.Revisar(link) end
end

---------------------------------------------------------------------------
-- Regalárselo (solo con tu clic)
---------------------------------------------------------------------------

local carta -- { destino, nombre, at }: para el correo

local function unidadDe(destino)
	local G = M.Gente
	local clave = U.Clave(destino)
	local unit = G and G.UnidadDe and clave and G.UnidadDe(clave)
	if unit then return unit end
	-- Tu objetivo, si es esa persona.
	if UnitExists and UnitName and UnitExists("target") then
		local ok, n = pcall(UnitName, "target")
		n = ok and U.Texto(n)
		if n and U.Clave(n) == clave then return "target" end
	end
	return nil
end

local function ponerNombreEnCorreo()
	local caja = rawget(_G, "SendMailNameEditBox")
	if not (carta and caja and caja.SetText) then return false end
	if U.Ahora() - carta.at > CARTA then carta = nil return false end
	pcall(caja.SetText, caja, carta.destino)
	return true
end

function Bo.Regalar(s)
	if not (s and s.para) then return false end
	if InCombatLockdown and InCombatLockdown() then
		U.Decir(L["Cuando termine el combate."])
		return false
	end
	local destino = s.para.destino
	local unit = unidadDe(destino)
	local cerca = false
	if unit and CheckInteractDistance then
		local ok, v = pcall(CheckInteractDistance, unit, 2)
		cerca = ok and U.Leer(v) and true or false
	end
	if cerca and InitiateTrade then
		pcall(InitiateTrade, unit)
		return "comercio"
	end
	carta = { destino = destino, nombre = s.para.nombre, at = U.Ahora() }
	local Mail = rawget(_G, "MailFrame")
	if Mail and Mail.IsShown and Mail:IsShown() then
		ponerNombreEnCorreo()
		U.Decir(format(L["Su nombre ya está en el correo: pon %s y envíalo."], s.link or s.nombre or ""))
	else
		U.Decir(format(L["%s no está a tu lado: mándaselo por correo. Al abrir un buzón, su nombre ya estará puesto."], s.para.nombre))
	end
	return "correo"
end

function Bo.Carta() return carta end

A.RegisterEvent("MAIL_SHOW", function()
	if carta then A.After(0.2, ponerNombreEnCorreo) end
end)

A.RegisterEvent("CHAT_MSG_LOOT", function(_, msg) Bo.AlBotin(msg) end)

A.OnLogin(function()
	M.Cada("manada.botin", 60, function() Bo.Compartir(false) end)
	A.RegisterEvent("PLAYER_LEVEL_UP", function() A.After(3, function() Bo.Compartir(true) end) end)
	A.After(30, function()
		if not U.EnHermandad() then return end
		Bo.Compartir(true)
		if activo() then M.Red.EnviarHermandad("i?", V .. "i|?") end
	end)
end)

A.On("SETTING_CHANGED", function(path)
	if path == ID .. ".botinCompartir" and comparte() then Bo.Compartir(true) end
end)
