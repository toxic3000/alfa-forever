-- Alfa - Lya: el fin de la mazmorra (1.2.8). toxic3000 / La Jauría. GPL-3.0.
--
--   Al salir de una mazmorra de grupo, Lya te cuenta cómo te fue: el tiempo
--   adentro, cuántas veces caíste (PLAYER_DEAD adentro) y lo mejor que
--   sacaste (CHAT_MSG_LOOT, solo lo tuyo, de la calidad más alta). Lo festeja
--   y lo apunta en tu historia como «Última mazmorra» (TuHistoria.lua).
--   La corrida se guarda por personaje (una recarga adentro no la pierde) y
--   cuenta hasta tu último minuto adentro (si te desconectas, no suma horas).
--   Una visita de menos de 3 minutos no cuenta. En las instancias, los textos
--   y nombres pueden ser secretos: lo que no se puede leer, no se lee.
--   lya.finMazmorra lo apaga.
--
--   Fm.Entrar()  Fm.Salir() -> bool   Fm.AlMorir()   Fm.AlBotin(texto, guid)
--   Fm.Resumen(r) -> texto   Fm.Linea(entrada) -> texto (para tu historia)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local type, tonumber, pcall, format, floor, max = type, tonumber, pcall, string.format, math.floor, math.max

local Fm = {}
M.FinMazmorra = Fm

local MINIMO = 180 -- segundos adentro para que cuente
local ADENTRO = 60  -- cada cuánto se apunta que sigues adentro

local function secreto(v) return issecretvalue ~= nil and v ~= nil and issecretvalue(v) and true or false end
local function num(v) if secreto(v) then return nil end return tonumber(v) end
local function texto(v) if secreto(v) or type(v) ~= "string" or v == "" then return nil end return v end
local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end

local function datos() return N.DatosPersonaje(ID) end

local function tipoInstancia()
	if not IsInInstance then return nil end
	local ok, dentro, tipo = pcall(IsInInstance)
	if not ok or secreto(dentro) or secreto(tipo) or dentro ~= true then return nil end
	return type(tipo) == "string" and tipo or "?"
end

local function laMazmorra()
	local nombre, id
	if GetInstanceInfo then
		local ok, n, _, _, _, _, _, _, i = pcall(GetInstanceInfo)
		if ok then nombre, id = texto(n), num(i) end
	end
	return nombre, id
end

local function tiempo(seg)
	local min = floor((tonumber(seg) or 0) / 60 + 0.5)
	if min < 60 then return format(L["%d min"], min) end
	return format(L["%d h %d min"], floor(min / 60), min % 60)
end

---------------------------------------------------------------------------
-- Lo que se cuenta
---------------------------------------------------------------------------
function Fm.Corrida() local r = datos().corrida return type(r) == "table" and r or nil end

function Fm.Entrar()
	local nombre, id = laMazmorra()
	local marca = tostring(id or nombre or "?")
	local r = Fm.Corrida()
	if r and r.marca == marca then
		r.ultimo = reloj() -- la misma (una recarga, o saliste a reparar y volviste)
		return r
	end
	if r then Fm.Salir() end
	r = { marca = marca, nombre = nombre, inicio = reloj(), ultimo = reloj(), muertes = 0 }
	datos().corrida = r
	-- Tu primera mazmorra, en tu historia.
	if M.Diario then
		if nombre then
			M.Diario.Anotar({ clave = "mazmorra", icono = "ic-mazmorra", t = "Tu primera mazmorra: %s", a = { nombre },
				l = "Entramos juntos a lo oscuro. Yo te cuido la espalda." })
		else
			M.Diario.Anotar({ clave = "mazmorra", icono = "ic-mazmorra", t = "Tu primera mazmorra",
				l = "Entramos juntos a lo oscuro. Yo te cuido la espalda." })
		end
	end
	return r
end

function Fm.AlMorir()
	local r = Fm.Corrida()
	if not r or tipoInstancia() ~= "party" then return end
	r.muertes = (tonumber(r.muertes) or 0) + 1
	r.ultimo = reloj()
end

-- La calidad de un objeto (su enlace): la del color del enlace (siempre viene),
-- o la del juego si el color no es uno conocido.
local COLOR = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }
local function calidad(enlace)
	local hex = enlace:match("|c%x%x(%x%x%x%x%x%x)")
	if hex and COLOR[hex:lower()] then return COLOR[hex:lower()] end
	local id = tonumber(enlace:match("|Hitem:(%d+)"))
	local Ci = C_Item
	if id and Ci and Ci.GetItemQualityByID then
		local ok, q = pcall(Ci.GetItemQualityByID, id)
		if ok and num(q) then return num(q) end
	end
	if GetItemInfo then
		local ok, _, _, q = pcall(GetItemInfo, enlace)
		if ok and num(q) then return num(q) end
	end
	return nil
end

-- "Recibes botín: [x]." con el texto del juego (LOOT_ITEM_SELF y _MULTIPLE).
local function esMio(t, guid)
	local yo = texto(UnitGUID and UnitGUID("player"))
	guid = texto(guid)
	if guid and yo then return guid == yo end
	for _, patron in ipairs({ LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_SELF, LOOT_ITEM_PUSHED_SELF_MULTIPLE, LOOT_ITEM_PUSHED_SELF }) do
		if type(patron) == "string" and patron ~= "" then
			local inicio = patron:match("^(.-)%%")
			if inicio and inicio ~= "" and t:sub(1, #inicio) == inicio then return true end
		end
	end
	return false
end

function Fm.AlBotin(t, guid)
	local r = Fm.Corrida()
	t = texto(t)
	if not (r and t) or tipoInstancia() ~= "party" or not esMio(t, guid) then return end
	local enlace = t:match("|c%x+|Hitem:.-|h.-|h|r")
	if not enlace then return end
	local q = calidad(enlace)
	if not q then return end
	if not r.botin or q > (tonumber(r.calidad) or -1) then
		r.botin, r.calidad = enlace, q
	end
end

---------------------------------------------------------------------------
-- El resumen
---------------------------------------------------------------------------
function Fm.Resumen(r)
	local dur = max(0, (tonumber(r.ultimo) or 0) - (tonumber(r.inicio) or 0))
	local partes = {}
	if r.nombre then
		partes[1] = format(L["¡Salimos de %s! %s adentro."], r.nombre, tiempo(dur))
	else
		partes[1] = format(L["¡Salimos de la mazmorra! %s adentro."], tiempo(dur))
	end
	local caidas = tonumber(r.muertes) or 0
	if caidas == 0 then
		partes[#partes + 1] = L["Y sin caer ni una vez. ¡Qué manada!"]
	elseif caidas == 1 then
		partes[#partes + 1] = L["Caíste una vez, pero saliste de pie."]
	else
		partes[#partes + 1] = format(L["Caíste %d veces, pero saliste de pie."], caidas)
	end
	if r.botin and (tonumber(r.calidad) or 0) >= 2 then
		partes[#partes + 1] = format(L["Lo mejor que sacaste: %s."], r.botin)
	end
	return table.concat(partes, " ")
end

-- Para tu historia: la línea de tu última mazmorra.
function Fm.Linea(e)
	local x = type(e.datos) == "table" and e.datos or {}
	local caidas = tonumber(x.muertes) or 0
	local t = format(caidas == 1 and L["%s adentro y %d caída."] or L["%s adentro y %d caídas."], tiempo(x.segundos), caidas)
	if type(x.botin) == "string" then t = t .. " " .. format(L["Lo mejor: %s."], x.botin) end
	return t
end

-- -> true si Lya contó el resumen (o lo dirá en cuanto pueda).
function Fm.Salir()
	local r = Fm.Corrida()
	datos().corrida = nil
	if not r then return false end
	local dur = max(0, (tonumber(r.ultimo) or 0) - (tonumber(r.inicio) or 0))
	if dur < MINIMO then return false end
	if M.Diario then
		M.Diario.Anotar({ clave = "corrida", icono = "ic-mazmorra", reemplaza = true, festejo = false,
			t = r.nombre and "Última mazmorra: %s" or "Última mazmorra", a = r.nombre and { r.nombre } or nil,
			datos = { segundos = dur, muertes = tonumber(r.muertes) or 0,
				botin = (tonumber(r.calidad) or 0) >= 2 and r.botin or nil } })
	end
	if N.Get(ID, "finMazmorra") == false then return false end
	local Ce = M.Cerebro
	if not Ce then return false end
	local ok = Ce.Decir({ texto = Fm.Resumen(r), importante = true, aullar = true, segundos = 14, lineas = 5, ancho = 360 })
	return ok == true or ok == "espera"
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	local tipo = tipoInstancia()
	if tipo == "party" then
		Fm.Entrar()
	elseif Fm.Corrida() then
		-- Afuera (o en otra clase de instancia): tras un respiro, el resumen.
		A.After(3, function()
			if tipoInstancia() == "party" then return end
			local ok, e = pcall(Fm.Salir)
			if not ok and geterrorhandler then geterrorhandler()(e) end
		end)
	end
end)
A.RegisterEvent("PLAYER_DEAD", function() Fm.AlMorir() end)
A.RegisterEvent("CHAT_MSG_LOOT", function(_, t, _, _, _, _, _, _, _, _, _, _, guid)
	local ok, e = pcall(Fm.AlBotin, t, guid)
	if not ok and geterrorhandler then geterrorhandler()(e) end
end)
N.Cada("lya.finMazmorra", ADENTRO, function() -- un solo reloj (1.2.9)
	local r = Fm.Corrida()
	if r and tipoInstancia() == "party" then r.ultimo = reloj() end
end)
