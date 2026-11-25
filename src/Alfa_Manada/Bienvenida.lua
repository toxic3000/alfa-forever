-- Alfa - La Jauría: la bienvenida a la manada (1.4.0, 52). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Dos tarjetas, sin mandar nada al chat:
--   * Entras a una hermandad con Alfa: un anuncio con el lobo («¡Bienvenido
--     a la manada!») y lo que La Jauría hace por ti, con «Ver La Jauría». Tu
--     Alfa dice su versión a tu nueva hermandad (el censo, Censo.lua, si lo
--     tienes prendido) para que los demás sepan que llegó un lobo con Alfa.
--     La primera vez que Alfa ve a este personaje ya en una hermandad no hay
--     tarjeta (no es nuevo): se anota y ya.
--   * Alguien entra a tu hermandad (el aviso del juego «X se ha unido a la
--     hermandad»): si en ESPERA segundos su Alfa se deja oír por la Red, un
--     aviso «X llegó a la manada con Alfa» con «Darle la bienvenida», que
--     solo abre tu chat con un susurro listo (tú decides si lo mandas).
-- Ajuste manada.bienvenida (de fábrica, sí).
--
--   Bi.Revisar() -> "nueva" | nil   (tu hermandad cambió: la tarjeta)
--   Bi.AlUnirse(nombre)             (el aviso del juego)
--   Bi.RevisarNuevo(clave)          (ESPERA después: ¿trae Alfa?)   Bi.Tarjeta(hermandad)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local type, pairs, ipairs, pcall, format, wipe = type, pairs, ipairs, pcall, string.format, wipe or table.wipe

local Bi = {}
M.Bienvenida = Bi

local ESPERA = 45    -- segundos para oír al Alfa de quien llegó
local NUEVOS = 20    -- llegadas que se esperan a la vez, como mucho

local function activo() return N.Get(ID, "bienvenida") ~= false end
local function datos() return N.DatosPersonaje(ID) end

---------------------------------------------------------------------------
-- Tú llegas a una hermandad
---------------------------------------------------------------------------

function Bi.Tarjeta(hermandad)
	local K = N.Kit
	local abrir = function()
		local Mn = rawget(_G, "AlfaManada")
		if type(Mn) == "table" and type(Mn.Abrir) == "function" then K.Llamar(Mn.Abrir) end
	end
	U.Aviso({ titulo = format(L["¡Bienvenido a %s!"], hermandad or "?"),
		texto = L["Tu hermandad ya es tu manada: ve quién anda conectado, propón citas, pide ayuda y suma tu semana. Todo en La Jauría."],
		icono = "ic-manada", lobo = "aullando", duracion = 25, prioridad = 3,
		accion = { texto = L["Ver La Jauría"], alClic = abrir } })
	return true
end

-- -> "nueva" si llegaste a otra hermandad (y salió la tarjeta), o nil.
function Bi.Revisar()
	local d = datos()
	local en = U.EnHermandad()
	local nombre = en and U.NombreHermandad() or nil
	-- El juego dice que estás en una, pero su nombre todavía no llega: luego.
	if en and not nombre then return nil end
	local antes = d.hermandadVista
	d.hermandadVista = nombre or false
	if antes == nil or not nombre or antes == nombre then return nil end
	if not activo() then return nil end
	Bi.Tarjeta(nombre)
	-- Que la manada nueva sepa que llegó un lobo con Alfa (el censo, con su ajuste).
	N.Una("manada.bienvenidaCenso", 8, function()
		if M.Censo and M.Censo.Enviar and N.Get(ID, "censo") ~= false then pcall(M.Censo.Enviar, true) end
	end)
	return "nueva"
end

---------------------------------------------------------------------------
-- Alguien llega a tu hermandad
---------------------------------------------------------------------------

local nuevos, nNuevos = {}, 0 -- clave -> { nombre, at }

-- ¿Su Alfa ya se dejó oír? (cualquier mensaje de la Red, o el censo)
local function traeAlfa(clave)
	if M.Red and M.Red.VersionDe and M.Red.VersionDe(clave) then return true end
	local Ce = M.Censo
	if Ce and Ce.Lista then
		local ok, l = pcall(Ce.Lista)
		if ok and type(l) == "table" then
			for _, x in ipairs(l) do if x.clave == clave and not x.yo then return true end end
		end
	end
	return false
end

function Bi.Saludar(nombre)
	local quien = U.Mostrar(nombre) or nombre
	local ok = U.Susurrar(nombre, L["¡Bienvenido a la manada! Si necesitas algo, aquí estamos. ¡Auuu!"])
	if ok and M.Logros and M.Logros.Ayudar then M.Logros.Ayudar("bienvenida:" .. tostring(U.Clave(nombre))) end -- (55)
	return ok and quien
end

function Bi.RevisarNuevo(clave)
	local x = nuevos[clave]
	if not x then return false end
	nuevos[clave] = nil
	nNuevos = math.max(0, nNuevos - 1)
	if not activo() or not traeAlfa(clave) then return false end
	local quien = U.Mostrar(x.nombre) or x.nombre
	U.Aviso({ de = clave, titulo = format(L["¡%s llegó a la manada con Alfa!"], quien),
		texto = L["Salúdalo: una bienvenida le alegra el día."], icono = "ic-manada", lobo = "atento", duracion = 20, prioridad = 3,
		accion = { texto = L["Darle la bienvenida"], alClic = function() Bi.Saludar(x.nombre) end } })
	return true
end

function Bi.AlUnirse(nombre)
	if not activo() or type(nombre) ~= "string" or U.Secreto(nombre) then return false end
	local clave = U.Clave(nombre)
	if not clave or clave == U.MiClave() or nuevos[clave] then return false end
	if nNuevos >= NUEVOS then return false end
	nuevos[clave] = { nombre = nombre, at = U.Ahora() }
	nNuevos = nNuevos + 1
	-- Pregúntale «¿quién anda?» a la hermandad: así su Alfa contesta.
	N.Una("manada.bienvenidaPregunta", 5, function()
		if M.Censo and M.Censo.Preguntar then pcall(M.Censo.Preguntar) end
	end)
	N.Una("manada.bienvenida:" .. clave, ESPERA, function() Bi.RevisarNuevo(clave) end)
	return true
end

-- «X se ha unido a la hermandad.» (ERR_GUILD_JOIN_S), como patrón.
local patron
local function quienLlego(msg)
	if type(msg) ~= "string" or U.Secreto(msg) then return nil end
	if patron == nil then
		local s = rawget(_G, "ERR_GUILD_JOIN_S")
		if type(s) ~= "string" or not s:find("%s", 1, true) then patron = false
		else
			s = s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
			patron = "^" .. s:gsub("%%%%s", "(.+)") .. "$"
		end
	end
	if not patron then return nil end
	local n = msg:match(patron)
	if n then n = n:gsub("|H.-|h%[?(.-)%]?|h", "%1"):gsub("^['\"]", ""):gsub("['\"]$", "") end
	return n
end
Bi.QuienLlego = quienLlego -- (para el banco)

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

A.RegisterEvent("CHAT_MSG_SYSTEM", function(_, msg)
	local n = quienLlego(msg)
	if n then Bi.AlUnirse(n) end
end)

local revisar = function() N.Una("manada.bienvenida", 3, function() pcall(Bi.Revisar) end) end
A.RegisterEvent("PLAYER_GUILD_UPDATE", revisar)
A.OnLogin(function()
	-- Al entrar, el nombre de la hermandad llega tarde: se mira al rato.
	N.Una("manada.bienvenidaEntrar", 20, function() pcall(Bi.Revisar) end)
end)

-- Para el banco.
function Bi.Olvidar() wipe(nuevos) nNuevos = 0 end
