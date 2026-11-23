-- Alfa - Lya según el momento (1.2.9). toxic3000 / La Jauría. GPL-3.0.
--
--   Lo que Lya dice cuando platica «algo del momento» (Ce.DelMomento, que usan
--   la plática y el latido) ahora también sabe la hora, la fiesta y el lugar:
--     * la hora: la de tu reloj (de madrugada te pide descansar, en la mañana
--       te da los buenos días...) y la de Azeroth (la del servidor: de noche en
--       el Bosque del Ocaso, al amanecer en Elwynn...);
--     * las fiestas del juego: las del calendario (C_Calendar, las de tipo
--       HOLIDAY de hoy) y, si el calendario no responde, las de fecha fija del
--       Clásico (Fuego del Solsticio, Halloween de Azeroth, el Festival de
--       Invierno). La primera vez del día que hay fiesta, Lya te lo dice al
--       entrar;
--     * la zona: unas líneas por zona, de día o de noche.
--   Cada línea, una vez cada 6 horas como mucho (las de la hora, una vez por
--   rato del día). lya.momento lo apaga (quedan los comentarios de siempre).
--
--   Ah.Hora() -> "madrugada" | "manana" | "tarde" | "noche"   (tu reloj)
--   Ah.Noche() -> true si es de noche en Azeroth (hora del servidor)
--   Ah.Fiestas() -> { { clave, nombre }, ... }   Ah.Linea() -> id, texto
--   Ah.Decir(pedido) -> true si habló   Ah.Festejo() -> true si habló

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local type, tonumber, ipairs, pairs, pcall, format, random = type, tonumber, ipairs, pairs, pcall, string.format, math.random

local Ah = {}
M.Ahora = Ah

local REPETIR = 6 * 3600

local function secreto(v) return issecretvalue ~= nil and type(v) ~= "nil" and issecretvalue(v) and true or false end
local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end

local function memoria()
	local d = N.DatosPersonaje(ID)
	d.ahora = type(d.ahora) == "table" and d.ahora or {}
	return d.ahora
end

---------------------------------------------------------------------------
-- La hora
---------------------------------------------------------------------------
function Ah.Hora(h)
	h = tonumber(h) or tonumber(date and date("%H")) or 12
	if h < 5 then return "madrugada" end
	if h < 12 then return "manana" end
	if h < 19 then return "tarde" end
	return "noche"
end

-- De noche en Azeroth: la hora del servidor (GetGameTime), de 20 a 6.
function Ah.Noche()
	local h = GetGameTime and GetGameTime()
	h = not secreto(h) and tonumber(h) or nil
	if not h then h = tonumber(date and date("%H")) or 12 end
	return h >= 20 or h < 6
end

local HORA = {
	madrugada = {
		"Ya es de madrugada, lobo. Una misión más y a dormir, ¿sí? Azeroth sigue aquí mañana.",
		"A estas horas hasta los murlocs duermen. No te desveles mucho, que mañana también se caza.",
		"La luna ya va bajando. Si cabeceas, descansa en una posada y ganas experiencia de descanso.",
	},
	manana = {
		"¡Buenos días! Un buen desayuno y a cazar, que la mañana rinde.",
		"La mañana huele a pan recién hecho en las posadas. ¿Empezamos con las misiones fáciles?",
	},
	tarde = {
		"Buenas tardes. Es buena hora para entregar misiones y ver qué hay de nuevo.",
		"La tarde se presta para una mazmorra con la manada. Hay más gente conectada a estas horas.",
	},
	noche = {
		"Ya es de noche. Una buena cacería antes de dormir y luego a descansar.",
		"Buenas noches, lobo. Si te vas a ir pronto, termina en una posada para descansar bien.",
	},
}

---------------------------------------------------------------------------
-- Las fiestas
---------------------------------------------------------------------------
-- Las de fecha fija del Clásico: { clave, desde = { mes, día }, hasta = { mes, día } }
local FIJAS = {
	{ clave = "solsticio", desde = { 6, 21 }, hasta = { 7, 5 } },
	{ clave = "brujas", desde = { 10, 18 }, hasta = { 11, 1 } },
	{ clave = "invierno", desde = { 12, 15 }, hasta = { 1, 2 } },
}
local NOMBRE_FIESTA = {
	solsticio = "el Festival del Fuego del Solsticio de Verano",
	brujas = "Halloween de Azeroth",
	invierno = "el Festival de Invierno",
}
local FIESTA = {
	solsticio = {
		"¡Es el Festival del Fuego del Solsticio! Visita las hogueras de las ciudades y honra su llama.",
		"En el Solsticio cada pueblo prende su hoguera. Me encanta el olor a leña... y a salchicha asada.",
	},
	brujas = {
		"¡Es Halloween de Azeroth! Pide dulces a los posaderos: a veces te disfrazan de algo chistoso.",
		"En estos días las calles se llenan de calabazas y velas. A mí me dan un poquito de miedo.",
	},
	invierno = {
		"¡Llegó el Festival de Invierno! En Forjaz y Orgrimmar el árbol se llena de luces y regalos.",
		"El Festival de Invierno me pone de buenas. Busca al Abuelo Invierno: siempre trae algo para ti.",
	},
}

local function dentro(m, d, desde, hasta)
	local v, a, b = m * 100 + d, desde[1] * 100 + desde[2], hasta[1] * 100 + hasta[2]
	if a <= b then return v >= a and v <= b end
	return v >= a or v <= b -- cruza el año
end

-- Las de hoy en el calendario del juego: { nombre, ... } (vacía si no responde).
local function delCalendario()
	local out = {}
	local C, T = C_Calendar, C_DateAndTime
	if not (C and C.GetNumDayEvents and C.GetDayEvent and T and T.GetCurrentCalendarTime) then return out end
	local ok, hoy = pcall(T.GetCurrentCalendarTime)
	if not (ok and type(hoy) == "table" and tonumber(hoy.monthDay)) then return out end
	-- El mes que tiene abierto el calendario debe ser el de hoy (el desfase 0 es ese).
	if C.GetMonthInfo then
		local bien, info = pcall(C.GetMonthInfo, 0)
		if bien and type(info) == "table" and tonumber(info.month) and (info.month ~= hoy.month or info.year ~= hoy.year) then return out end
	end
	local bien, n = pcall(C.GetNumDayEvents, 0, hoy.monthDay)
	n = bien and not secreto(n) and tonumber(n) or 0
	for i = 1, n do
		local ok2, e = pcall(C.GetDayEvent, 0, hoy.monthDay, i)
		if ok2 and type(e) == "table" and e.calendarType == "HOLIDAY" and type(e.title) == "string"
			and not secreto(e.title) and e.title ~= "" then
			out[#out + 1] = e.title
		end
	end
	return out
end

-- -> { { clave = "brujas" | nil, nombre }, ... }
function Ah.Fiestas(m, d)
	m = tonumber(m) or tonumber(date and date("%m")) or 1
	d = tonumber(d) or tonumber(date and date("%d")) or 1
	local out, vistas = {}, {}
	for _, f in ipairs(FIJAS) do
		if dentro(m, d, f.desde, f.hasta) then
			out[#out + 1] = { clave = f.clave, nombre = L[NOMBRE_FIESTA[f.clave]] }
			vistas[f.clave] = true
		end
	end
	-- Las del calendario que no son las de fecha fija (Festival Lunar, Jardín Noble, la Feria...).
	if #out == 0 then
		for _, t in ipairs(delCalendario()) do out[#out + 1] = { nombre = t } end
	end
	return out
end

---------------------------------------------------------------------------
-- La zona (uiMapID del Clásico), de día y de noche
---------------------------------------------------------------------------
local ZONA = {
	[1429] = { dia = "Elwynn de día es pura paz: el río, los campos y el olor a pan de Villadorada.",
		noche = "De noche en Elwynn se oyen los lobos del bosque. Tranquilo: son primos lejanos." },
	[1431] = { dia = "Aun de día el Bosque del Ocaso está oscuro. Aquí nunca sale el sol del todo.",
		noche = "De noche en el Bosque del Ocaso los worgen salen a cazar. No te separes de mí." },
	[1436] = { dia = "En los Páramos de Poniente el viento mueve los molinos. Ojo con los Defias en las granjas.",
		noche = "De noche los Defias se mueven por los Páramos. Mira bien antes de entrar a una granja." },
	[1434] = { dia = "En Tuercespina hace un calor de lobo. Toma agua y cuidado con los tigres entre la hierba.",
		noche = "La selva de Tuercespina de noche suena a mil bichos. Los trols sí ven en la oscuridad." },
	[1411] = { dia = "El sol de Durotar quema la tierra roja. Por algo los orcos son tan duros.",
		noche = "De noche Durotar refresca y se ven muchas estrellas desde Orgrimmar." },
	[1412] = { dia = "Mulgore de día: pasto hasta donde alcanza la vista y kodos pastando. Qué paz.",
		noche = "De noche en Mulgore el viento canta entre las mesetas. Los tauren dicen que es la Madre Tierra." },
	[1420] = { dia = "En Tirisfal casi nunca sale el sol. A los Renegados ni les importa.",
		noche = "La noche en Tirisfal es más fría que el día. Huele a hojas mojadas y a cripta." },
	[1426] = { dia = "En Dun Morogh la nieve brilla con el sol. Abrígate, que aquí hasta los osos tienen frío.",
		noche = "De noche en Dun Morogh la nieve cruje bajo las patas. Me encanta ese sonido." },
	[1438] = { dia = "Teldrassil siempre tiene una luz suave, como si el árbol mismo nos cuidara.",
		noche = "De noche Teldrassil se llena de luciérnagas. Los elfos de la noche están en su hora." },
	[1413] = { dia = "En Los Baldíos el sol pega duro. Las cebras corren por todos lados y yo quiero perseguirlas.",
		noche = "La noche en Los Baldíos es enorme y callada. Se oyen las hienas a lo lejos." },
	[1440] = { dia = "Vallefresno es un bosque precioso. Pero cuida de no enojar a sus espíritus antiguos.",
		noche = "De noche Vallefresno brilla con luz de luna. Los furbolg duermen... casi todos." },
	[1452] = { dia = "En Cuna del Invierno la nieve no se acaba. Los osos y los yetis andan de buen humor.",
		noche = "De noche en Cuna del Invierno la aurora pinta el cielo. Vale la pena verla un ratito." },
	[1446] = { dia = "En Tanaris el sol del desierto no perdona. Gadgetzan es el único lugar con sombra.",
		noche = "De noche en Tanaris la arena se enfría rápido. Cuidado con los escorpiones." },
	[1423] = { dia = "Las Tierras de la Peste del Este siguen tristes aun de día. Aquí la Plaga no descansa.",
		noche = "De noche en las Tierras de la Peste los muertos caminan más. Quédate junto a la luz." },
	[1449] = { dia = "Un'Goro de día: dinosaurios por todas partes. Yo me quedo atrás de ti, ¿va?",
		noche = "De noche Un'Goro ruge. Los diablosaurios del cráter no duermen nunca." },
	[1437] = { dia = "En Los Humedales siempre está húmedo. Mis patas terminan llenas de lodo.",
		noche = "De noche en Los Humedales croan las ranas y los raptores acechan entre los juncos." },
}

---------------------------------------------------------------------------
-- Elegir y decir
---------------------------------------------------------------------------
local function zonaActual()
	local Mp = C_Map
	if not (Mp and Mp.GetBestMapForUnit) then return nil end
	local ok, mapa = pcall(Mp.GetBestMapForUnit, "player")
	if not ok or secreto(mapa) then return nil end
	mapa = tonumber(mapa)
	-- Una cueva o un pueblo: la zona que lo contiene.
	if mapa and not ZONA[mapa] and Mp.GetMapInfo then
		local bien, info = pcall(Mp.GetMapInfo, mapa)
		if bien and type(info) == "table" and tonumber(info.parentMapID) and ZONA[info.parentMapID] then mapa = info.parentMapID end
	end
	return mapa
end

local function libre(id, ventana)
	local t = tonumber(memoria()[id]) or 0
	return reloj() - t >= (ventana or REPETIR)
end

-- Las candidatas de ahora: { { id, texto }, ... }, la fiesta primero.
local function candidatas()
	local out = {}
	for _, f in ipairs(Ah.Fiestas()) do
		local lista = f.clave and FIESTA[f.clave]
		if lista then
			for i, t in ipairs(lista) do
				local id = "f." .. f.clave .. i
				if libre(id) then out[#out + 1] = { id = id, texto = L[t], fiesta = true } end
			end
		else
			local id = "f.cal." .. f.nombre
			if libre(id) then out[#out + 1] = { id = id, texto = format(L["Hoy en Azeroth hay fiesta: %s. ¿Vamos a ver qué hay?"], f.nombre), fiesta = true } end
		end
	end
	local rato = Ah.Hora()
	local lista = HORA[rato]
	local hoy = date and date("%Y-%m-%d") or "?"
	if lista and memoria()["h." .. rato] ~= hoy then
		local t = lista[random(#lista)]
		out[#out + 1] = { id = "h." .. rato, texto = L[t], hora = hoy }
	end
	local z = zonaActual()
	local zl = z and ZONA[z]
	if zl then
		local cual = Ah.Noche() and "noche" or "dia"
		local id = "z." .. z .. "." .. cual
		if zl[cual] and libre(id) then out[#out + 1] = { id = id, texto = L[zl[cual]] } end
	end
	return out
end

function Ah.Linea()
	local lista = candidatas()
	if #lista == 0 then return nil end
	-- La fiesta va primero la mitad de las veces; si no, una al azar.
	local e = lista[1].fiesta and random() < 0.5 and lista[1] or lista[random(#lista)]
	return e.id, e.texto, e
end

function Ah.Decir(pedido)
	if N.Get(ID, "momento") == false then return false end
	local id, t, e = Ah.Linea()
	if not id then return false end
	local Ce = M.Cerebro
	local ok = Ce and Ce.Decir({ texto = t, pedido = pedido, clase = "momento", lineas = 4, ancho = 340, segundos = 10,
		pose = e.fiesta and "sentada" or nil, salto = e.fiesta or nil,
		alDecir = function() memoria()[id] = e.hora or reloj() end })
	return ok == true
end

-- La primera vez del día que hay fiesta: Lya te lo dice al entrar.
-- 1.3.1: si Lya acaba de saludar (no habla de nuevo hasta que pase su espera
-- entre globos), lo vuelve a intentar entonces («lya.fiesta», unas veces).
local INTENTOS_FIESTA = 6
function Ah.Festejo(vez)
	vez = tonumber(vez) or 1
	if N.Get(ID, "momento") == false then return false end
	local f = Ah.Fiestas()[1]
	if not f then return false end
	local hoy = date and date("%Y-%m-%d") or "?"
	local m = memoria()
	if m.festejo == hoy then return false end
	local lista = f.clave and FIESTA[f.clave]
	local t = lista and L[lista[random(#lista)]] or format(L["Hoy en Azeroth hay fiesta: %s. ¿Vamos a ver qué hay?"], f.nombre)
	local Ce = M.Cerebro
	if not Ce then return false end
	local ok, por = Ce.Decir({ texto = t, clase = "momento", salto = true, lineas = 4, ancho = 340, segundos = 12,
		alDecir = function() memoria().festejo = hoy end })
	if ok == true then return true end
	local espera = Ce.Reintento and Ce.Reintento(por)
	if espera and vez < INTENTOS_FIESTA then
		N.Una("lya.fiesta", espera, function()
			local bien, e = pcall(Ah.Festejo, vez + 1)
			if not bien and geterrorhandler then geterrorhandler()(e) end
		end)
	end
	return false
end

-- Lo del momento de Cerebro (plática y latido): a veces, esto primero.
do
	local Ce = M.Cerebro
	local antes = Ce and Ce.DelMomento
	if Ce and type(antes) == "function" then
		Ce.DelMomento = function()
			if N.Get(ID, "momento") ~= false and random() < 0.55 then
				local ok, hablo = pcall(Ah.Decir, false)
				if ok and hablo then return true end
			end
			return antes()
		end
	end
end

if A.OnLogin then
	A.OnLogin(function()
		-- Después del saludo de entrada (18 s) y de la llegada.
		A.After(45, function()
			local ok, e = pcall(Ah.Festejo)
			if not ok and geterrorhandler then geterrorhandler()(e) end
		end)
	end)
end
