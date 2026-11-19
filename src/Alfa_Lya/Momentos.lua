-- Alfa - Lya: los momentos (1.2.7). toxic3000 / La Jauría. GPL-3.0.
--
--   * En una mazmorra (lya.mazmorras): al entrar, fuera de combate, un consejo
--     corto y «Ver la mazmorra» (AlfaMazmorras.Abrir, o la página Mazmorras).
--     Una vez por entrada (la misma mazmorra no se repite en 30 minutos).
--   * Su ánimo: tres caídas en 10 minutos y se sienta a tu lado a consolarte
--     (una vez cada 10 min); dos niveles en 30 minutos y festeja con un aullido
--     de más. Las frases de siempre al morir y al subir siguen saliendo.
--   * La salchicha: cada 45 a 90 minutos de juego (con Lya a la vista, fuera de
--     combate y de instancias, sin silencio) te pide una con «Darle una
--     salchicha»; te las cuenta (N.DatosPersonaje("lya").salchichas).
--   * Antes de irte (/camp, /quit): las misiones listas para entregar o, si no
--     hay, su despedida con tu día de caza. Aunque solo diga lo importante.
--
--   Mo.Mazmorra()  Mo.AlMorir()  Mo.AlSubir(nivel)  Mo.Consolar()  Mo.Festejar(nivel)
--   Mo.Minuto()  Mo.PedirSalchicha()  Mo.DarSalchicha(token)  Mo.Salchichas()
--   Mo.Despedida()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local type, tonumber, tostring, pcall, rawget, format = type, tonumber, tostring, pcall, rawget, string.format
local random = math.random

local Mo = {}
M.Momentos = Mo

local function ahora() return GetTime and GetTime() or 0 end
local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end
local function secreto(v) return issecretvalue ~= nil and v ~= nil and issecretvalue(v) and true or false end
local function num(v) if secreto(v) then return nil end return tonumber(v) end
local function texto(v) if secreto(v) or type(v) ~= "string" or v == "" then return nil end return v end

local function datos() return N.DatosPersonaje(ID) end
local function Ce() return M.Cerebro end

local function enCombate()
	if InCombatLockdown and InCombatLockdown() then return true end
	if UnitAffectingCombat then
		local v = UnitAffectingCombat("player")
		return not secreto(v) and v == true
	end
	return false
end

-- El tipo de instancia donde estás ("party", "raid"...) o nil afuera.
local function tipoInstancia()
	if not IsInInstance then return nil end
	local ok, dentro, tipo = pcall(IsInInstance)
	if not ok or secreto(dentro) or secreto(tipo) or dentro ~= true then return nil end
	return type(tipo) == "string" and tipo or "?"
end

-- Abre algo de Alfa fuera de combate.
local function abrir(fn) N.FueraDeCombate("lya.momentos.abrir", fn) end

---------------------------------------------------------------------------
-- 6. En una mazmorra
---------------------------------------------------------------------------
local turnoMazmorra = 0

local function deLaMazmorra()
	local id, nombre
	if GetInstanceInfo then
		local ok, n, _, _, _, _, _, _, i = pcall(GetInstanceInfo)
		if ok then nombre, id = texto(n), num(i) end
	end
	-- La de Alfa_Mazmorras (su contrato): la que pisas, con su página.
	local key
	local Mz = rawget(_G, "AlfaMazmorras")
	if type(Mz) == "table" and type(Mz.Recomendada) == "function" then
		local ok, r = pcall(Mz.Recomendada)
		if ok and type(r) == "table" and r.modo == "dentro" then
			key = type(r.key) == "string" and r.key or nil
			nombre = texto(r.nombre) or nombre
		end
	end
	return id, nombre, key
end

local function verMazmorra(key)
	return function()
		abrir(function()
			local Mz = rawget(_G, "AlfaMazmorras")
			if key and type(Mz) == "table" and type(Mz.Abrir) == "function" and pcall(Mz.Abrir, key) then return end
			N.Abrir("mazmorras")
		end)
	end
end

-- Un intento: -> true si habló (o no tiene nada que decir aquí).
function Mo.Mazmorra()
	if N.Get(ID, "mazmorras") == false or tipoInstancia() ~= "party" then return true end
	local id, nombre, key = deLaMazmorra()
	local marca = tostring(id or nombre or "?")
	local d = datos()
	local antes = type(d.mazmorra) == "table" and d.mazmorra or nil
	if antes and antes.marca == marca and reloj() - (tonumber(antes.hora) or 0) < 1800 then return true end
	if enCombate() then return false end
	local hay = key or rawget(_G, "AlfaMazmorras") or N.ModuloPorId("mazmorras")
	local c = { enMazmorra = true, cara = "atenta", segundos = 12,
		acciones = hay and { { texto = L["Ver la mazmorra"], fn = verMazmorra(key) } } or nil }
	local ok
	if nombre then ok = Ce().DecirDe("mazmorra", c, nombre) else ok = Ce().DecirDe("mazmorraSin", c) end
	if ok == true then d.mazmorra = { marca = marca, hora = reloj() } end
	return ok == true
end

-- Al entrar: lo intenta unas veces (si estabas peleando, hablando u otro globo).
local function intentarMazmorra(mio, vez)
	if mio ~= turnoMazmorra then return end
	local ok, hecho = pcall(Mo.Mazmorra)
	if not ok and geterrorhandler then geterrorhandler()(hecho) end
	if (ok and hecho) or vez >= 8 then return end
	K.Despues(15, function() intentarMazmorra(mio, vez + 1) end)
end

A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	turnoMazmorra = turnoMazmorra + 1
	local mio = turnoMazmorra
	A.After(4, function() intentarMazmorra(mio, 1) end)
end)

---------------------------------------------------------------------------
-- 7. Su ánimo: rachas de caídas y de niveles
---------------------------------------------------------------------------
local muertes, niveles = {}, {}
local consueloEn = -1e9

local function podar(lista, ventana)
	local t = ahora()
	for i = #lista, 1, -1 do if t - lista[i] > ventana then table.remove(lista, i) end end
end

function Mo.Consolar()
	local acciones = {}
	local Cerca = rawget(_G, "AlfaCerca")
	if type(Cerca) == "table" and type(Cerca.Ir) == "function" then
		acciones[#acciones + 1] = { texto = L["Llévame a reparar"], fn = function()
			local ok, puesto = pcall(Cerca.Ir, "repair")
			if ok and puesto then N.EmpezarRuta() end
		end }
	end
	if N.ModuloPorId("manada") then
		acciones[#acciones + 1] = { texto = L["Pedir ayuda a la manada"], fn = function() abrir(function() N.Abrir("manada") end) end }
	end
	-- Sentadita a tu lado: la pose más suave.
	return Ce().DecirDe("consuelo", { importante = true, pose = "sentada", segundos = 14, lineas = 4,
		acciones = #acciones > 0 and acciones or nil })
end

-- -> true si es la tercera caída en 10 minutos (y lo dirá en un momento).
function Mo.AlMorir()
	local t = ahora()
	muertes[#muertes + 1] = t
	podar(muertes, 600)
	if #muertes < 3 or t - consueloEn < 600 then return false end
	consueloEn = t
	-- Después del «¡Arriba, lobo!» de siempre (dura 10 s).
	K.Despues(11, Mo.Consolar)
	return true
end

function Mo.Festejar(nivel)
	return Ce().DecirDe("racha", { importante = true, aullar = true, salto = true, segundos = 10 }, nivel)
end

-- -> true si es el segundo nivel en 30 minutos.
function Mo.AlSubir(nivel)
	nivel = num(nivel)
	if not nivel then return false end
	niveles[#niveles + 1] = ahora()
	podar(niveles, 1800)
	if #niveles < 2 then return false end
	niveles = {} -- la próxima racha, con dos niveles nuevos
	-- Después del aullido de siempre (que espera a que termine el combate).
	K.Despues(12, function()
		N.FueraDeCombate("lya.momentos.racha", function() K.Despues(12, function() Mo.Festejar(nivel) end) end)
	end)
	return true
end

A.RegisterEvent("PLAYER_DEAD", function() Mo.AlMorir() end)
A.RegisterEvent("PLAYER_LEVEL_UP", function(_, nivel) Mo.AlSubir(nivel) end)

---------------------------------------------------------------------------
-- 8. La salchicha
---------------------------------------------------------------------------
local pendiente -- la salchicha que pidió y todavía no le das

local function nuevaEspera() return random(45, 90) end

function Mo.Salchichas() return tonumber(datos().salchichas) or 0 end

function Mo.PedirSalchicha(pedido)
	local token = {}
	local c = { pose = "pedir", segundos = 14, pedido = pedido,
		acciones = { { texto = L["Darle una salchicha"], fn = function() Mo.DarSalchicha(token) end } } }
	local ok = Ce().DecirDe("pideSalchicha", c) == true
	if ok then pendiente = token end
	return ok
end

-- token: el de su pedido (el botón de un globo viejo ya no cuenta otra).
function Mo.DarSalchicha(token)
	local C = Ce()
	if token ~= nil and token ~= pendiente then
		return C.Decir({ texto = L["Esa ya me la diste, ¡gracias! Guárdame la siguiente."], pedido = true })
	end
	pendiente = nil
	local d = datos()
	local n = Mo.Salchichas() + 1
	d.salchichas = n
	if M.Avisar then M.Avisar() end
	local c = { pedido = true, salto = true, segundos = 9 }
	if n == 1 then
		c.texto = L["¡Mi primera salchicha contigo! Esta no la voy a olvidar nunca."]
		return C.Decir(c)
	end
	if n % 10 == 0 or random() < 0.3 then return C.DecirDe("graciasTotal", c, n) end
	return C.DecirDe("gracias", c)
end

-- Cada minuto de juego con Lya a la vista; al llegar su hora, pide.
function Mo.Minuto()
	local C, UI = Ce(), M.UI
	if not (C and UI and C.Activa() and UI.Visible()) then return false end
	local d = datos()
	local faltan = (tonumber(d.salchichaFaltan) or nuevaEspera()) - 1
	d.salchichaFaltan = faltan
	if faltan > 0 then return false end
	if enCombate() or tipoInstancia() or C.Silenciada() or UI.Hablando() or UI.Dormida() then return false end
	if Mo.PedirSalchicha() then
		d.salchichaFaltan = nuevaEspera()
		return true
	end
	return false
end

if A.NewTicker then
	A.NewTicker(60, function()
		local ok, e = pcall(Mo.Minuto)
		if not ok and geterrorhandler then geterrorhandler()(e) end
	end)
end

---------------------------------------------------------------------------
-- 9. Antes de irte
---------------------------------------------------------------------------
local despedidaEn = -1e9

local function listas()
	local R = rawget(_G, "AlfaRuta")
	if type(R) == "table" and type(R.Listas) == "function" then
		local ok, n = pcall(R.Listas)
		if ok then return num(n) or 0 end
	end
	return 0
end

function Mo.Despedida()
	if ahora() - despedidaEn < 60 then return false end
	local C = Ce()
	-- importante: también con «Solo importantes»; enMazmorra: también en una instancia.
	local c = { importante = true, enMazmorra = true, segundos = 18, lineas = 4 }
	local n = listas()
	local ok
	if n > 0 then
		c.cara = "atenta"
		local R = rawget(_G, "AlfaRuta")
		if type(R) == "table" and type(R.Entregar) == "function" and C.EntregarTodas then
			c.acciones = { { texto = L["Entregar todas"], fn = C.EntregarTodas } }
		end
		if n == 1 then
			c.texto = L["Antes de irte: tienes una misión lista para entregar. ¿Pasamos a cobrarla?"]
			ok = C.Decir(c)
		else
			ok = C.DecirDe("antesDeIrte", c, n)
		end
	else
		local r = M.Dia and M.Dia.Resumen and M.Dia.Resumen()
		if type(r) == "string" and r ~= "" then ok = C.DecirDe("adios", c, r) else ok = C.DecirDe("adiosSin", c) end
	end
	if ok then despedidaEn = ahora() end
	return ok
end

A.RegisterEvent("PLAYER_CAMPING", function() Mo.Despedida() end)
A.RegisterEvent("PLAYER_QUITING", function() Mo.Despedida() end)
