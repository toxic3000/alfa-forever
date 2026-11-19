-- Alfa - La Jauría: el saludo de la manada (1.2.7). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Al poco de entrar (ESPERA segundos, una vez por sesión), Lya o un aviso
-- dicen quién de tu hermandad anda conectado y dónde: hasta TOPE nombres con
-- su zona y «y N más». Sin nadie conectado (o sin hermandad), nada. Se apaga
-- con manada.saludo. Solo lee la lista de la hermandad del juego
-- (C_GuildInfo.GuildRoster la pide; GetNumGuildMembers y GetGuildRosterInfo
-- la leen); no envía nada a nadie.
--
--   Sa.Lista() -> { { nombre, zona } }, total   quién anda conectado (sin ti)
--   Sa.Texto() -> texto | nil                   lo que se dice
--   Sa.Decir() -> true si lo dijo

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Sa = {}
M.Saludo = Sa

local type, pcall, format, concat = type, pcall, string.format, table.concat

local ESPERA = 30
local TOPE = 3
local MAX_FILAS = 1000

local function encendido() return N.Get(ID, "saludo") ~= false end

function Sa.Lista()
	local out, total = {}, 0
	if not U.EnHermandad() or type(GetNumGuildMembers) ~= "function" or type(GetGuildRosterInfo) ~= "function" then return out, 0 end
	local ok, n = pcall(GetNumGuildMembers)
	n = ok and U.Numero(n) or 0
	local yo = U.MiClave()
	for i = 1, math.min(n, MAX_FILAS) do
		-- nombre, rango, n.º de rango, nivel, clase, zona, nota, nota de oficial, conectado, estado, CLASE, ..., en el móvil (14)
		local okI, nombre, _, _, _, _, zona, _, _, conectado, _, _, _, _, movil = pcall(GetGuildRosterInfo, i)
		if okI and U.Leer(conectado) == true and U.Leer(movil) ~= true then
			nombre = U.Texto(nombre)
			if nombre and U.Clave(nombre) ~= yo then
				total = total + 1
				if #out < TOPE then out[#out + 1] = { nombre = U.Mostrar(nombre), zona = U.Texto(zona) } end
			end
		end
	end
	return out, total
end

function Sa.Texto()
	local lista, total = Sa.Lista()
	if total == 0 then return nil end
	local partes = {}
	for i, p in ipairs(lista) do
		partes[i] = p.zona and format(L["%s (%s)"], p.nombre, p.zona) or p.nombre
	end
	local texto = concat(partes, ", ")
	if total > #lista then texto = format(L["%s y %d más"], texto, total - #lista) end
	return format(L["Andan conectados: %s."], texto)
end

local dicho = false
function Sa.Decir()
	if dicho or not encendido() then return false end
	local texto = Sa.Texto()
	if not texto then return false end
	dicho = true
	local K = N.Kit
	local o = { titulo = L["La manada te saluda"], texto = texto, icono = "ic-manada", duracion = 12, detalle = true }
	if K and K.Aviso then K.Aviso(o) else U.Decir(o.titulo .. " " .. texto) end
	return true
end

-- Para el banco.
function Sa.Olvidar() dicho = false end

local function pedirLista()
	local GI = C_GuildInfo
	if type(GI) == "table" and type(GI.GuildRoster) == "function" then pcall(GI.GuildRoster)
	elseif type(GuildRoster) == "function" then pcall(GuildRoster) end
end

local function intentar(intento)
	if dicho or not encendido() or not U.EnHermandad() then return end
	-- En combate, en un rato (nada se abre en medio de una pelea).
	if (InCombatLockdown and InCombatLockdown()) or (intento == 1 and select(2, Sa.Lista()) == 0) then
		if intento < 3 then
			pedirLista()
			A.After(15, function() intentar(intento + 1) end)
		end
		return
	end
	Sa.Decir()
end

A.OnLogin(function()
	A.After(ESPERA - 8, pedirLista)
	A.After(ESPERA, function() intentar(1) end)
end)
