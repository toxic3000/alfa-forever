-- Alfa - Lya 2.0: el lore de tus misiones (1.4.0, 12). toxic3000 / La Jauría.
-- GPL-3.0.
--
--   Lya ya sabía de qué va cada misión (Historias.lua, H.TemaDe: la Plaga,
--   los Defias, los múrlocs...). Ahora también cuenta la historia de ese
--   tema: cuando llevas una misión de algo que todavía no te contó, en un
--   rato tranquilo (la ronda de Charla.lua, «mision») sale una nota corta
--   con sus palabras. Cada nota, una vez por personaje (lya.charla.v).
--   Notas propias de Alfa (cortas), con su inglés en Textos.lua; las nuevas
--   van AL FINAL de su lista para no mover los ids (m<id>.<n>).
--   Ajuste lya.loreMisiones (de fábrica, sí); respeta lya.historias.
--
--   Lm.Algo(opts) -> true si habló      Lm.Temas() -> { tema, ... } de tus misiones de ahora
--   M.LORE_TEMA = { { tema, id, notas = { ... } }, ... }

local ADDON, M = ...
local N = AlfaNucleo
local L = M.L
local ID = M.ID

local type, tonumber, ipairs, pairs, pcall, random, format = type, tonumber, ipairs, pairs, pcall, math.random, string.format

local Lm = {}
M.LoreMisiones = Lm

M.LORE_TEMA = {
	{ tema = "la Plaga", id = "plaga", notas = {
		"La Plaga nació de un rey hecho de hielo: el Rey Exánime manda a sus muertos desde Rasganorte sin moverse de su trono.",
		"Antes de la Plaga, Lordaeron era el reino más grande de los humanos. Una peste en el grano lo cambió todo en pocas semanas.",
	} },
	{ tema = "la Hermandad Defias", id = "defias", notas = {
		"Los Defias eran albañiles honrados: reconstruyeron Ventormenta y nunca les pagaron. De ese coraje nació la Hermandad.",
		"Su líder se esconde bajo Villa Oscura, en Las Minas de la Muerte, construyendo un barco de guerra. Paciencia de lobo, pero mala.",
	} },
	{ tema = "los múrlocs", id = "murloc", notas = {
		"Los múrlocs hablan con gorgoteos y viven en las costas desde antes que nadie. Si oyes «mrglglgl», ya es tarde.",
	} },
	{ tema = "los kóbolds", id = "kobold", notas = {
		"Los kóbolds no se separan de su vela: dicen que la oscuridad de las minas está llena de cosas peores que ellos. «¡Tú no toma vela!»",
	} },
	{ tema = "los gnolls", id = "gnoll", notas = {
		"Los gnolls son primos lejanos de las hienas y cazan en manada, como nosotras… pero sin modales.",
	} },
	{ tema = "los trols", id = "trol", notas = {
		"Los trols tuvieron imperios enormes antes que los humanos y los elfos. Zul'Gurub y Zul'Farrak son lo que queda de esa grandeza.",
	} },
	{ tema = "los centauros", id = "centauro", notas = {
		"Los centauros se dicen hijos de Cenarius, el semidiós del bosque. Sus clanes pelean entre ellos tanto como contra los demás.",
	} },
	{ tema = "la Legión Ardiente", id = "legion", notas = {
		"La Legión Ardiente quiere quemar todos los mundos. Los sátiros de los bosques son elfos que le vendieron su alma.",
		"Fue la Legión la que corrompió a los orcos con sangre de demonio. Por eso Thrall pelea tanto para que no vuelva a pasar.",
	} },
	{ tema = "los jabaespines", id = "jabaespin", notas = {
		"Los jabaespines nacieron de la sangre de Agamaggan, un semidiós jabalí. Por eso sus espinas son sagradas para ellos.",
	} },
	{ tema = "los orcos", id = "orco", notas = {
		"Los orcos llegaron de Draenor por el Portal Oscuro. Hoy, con Thrall, buscan honor y no la sangre de los demonios.",
	} },
	{ tema = "los dragones", id = "dragon", notas = {
		"Hay cinco Vuelos de dragones, cada uno con un don de los titanes. El negro, el de Alamuerte, es el que nunca deja de tramar algo.",
	} },
	{ tema = "Ventura y Cía.", id = "ventura", notas = {
		"Ventura y Cía. es de los goblins: talan, minan y venden lo que sea. Donde llegan sus máquinas, el bosque se queda calvo.",
	} },
	{ tema = "el Sindicato", id = "sindicato", notas = {
		"El Sindicato son nobles caídos de Alterac que se volvieron ladrones. Siguen creyendo que el reino les pertenece.",
	} },
	{ tema = "los Renegados", id = "renegado", notas = {
		"Los Renegados son no-muertos que rompieron las cadenas de la Plaga. Sylvanas los guía desde Entrañas, bajo las ruinas de Lordaeron.",
	} },
	{ tema = "el Martillo Crepuscular", id = "crepuscular", notas = {
		"El Martillo Crepuscular adora a los Dioses Antiguos y sueña con el fin del mundo. Sus túnicas moradas siempre traen problemas.",
	} },
	{ tema = "los furbolgs", id = "furbolg", notas = {
		"Los furbolgs eran osos sabios y pacíficos. Muchos enloquecieron por una corrupción en sus bosques; los que quedan sanos agradecen la ayuda.",
	} },
	{ tema = "las arpías", id = "arpia", notas = {
		"Las arpías fueron maldecidas hace mucho y desde entonces odian a todo el que pasa por sus riscos. Cuidado con sus chillidos.",
	} },
	{ tema = "los naga", id = "naga", notas = {
		"Los naga eran elfos de la noche que se hundieron con la Fuente del Poder. Bajo el mar cambiaron… y volvieron con escamas.",
	} },
	{ tema = "los Hierro Negro", id = "hierronegro", notas = {
		"Los enanos Hierro Negro sirven a Ragnaros, el señor del fuego, desde su ciudad en la Montaña Roca Negra. No les gusta que los visiten.",
	} },
	{ tema = "los ogros", id = "ogro", notas = {
		"Algunos ogros tienen dos cabezas y discuten entre ellas. Los magos ogros son los listos… que no es decir mucho.",
	} },
	{ tema = "la Cruzada Escarlata", id = "escarlata", notas = {
		"La Cruzada Escarlata nació para pelear contra la Plaga, pero el odio la volvió loca: hoy ven enemigos en todos lados.",
	} },
	{ tema = "las arañas", id = "arana", notas = {
		"Las arañas de Bosque del Ocaso y de Mulgore no son iguales: unas tejen en la sombra, otras en las cuevas. Ninguna comparte su cena.",
	} },
	{ tema = "los piratas", id = "pirata", notas = {
		"Los Bucaneros Velasangre navegan por todo Azeroth. Bahía del Botín los aguanta porque ahí todo se compra y se vende.",
	} },
	{ tema = "los raptores", id = "raptor", notas = {
		"Los raptores son listos y cazan en grupo. Los trols los domestican desde hace siglos: buenos compañeros, pero no tan bonitos como una loba.",
	} },
	{ tema = "los elementales", id = "elemental", notas = {
		"Los elementales son fuego, agua, tierra y aire con voluntad propia. Los chamanes les hablan con respeto; los demás, de lejitos.",
	} },
	{ tema = "los troggs", id = "trogg", notas = {
		"Los troggs salieron de las profundidades cuando los enanos cavaron demasiado. Dicen que son un error de los titanes.",
	} },
	{ tema = "los silítidos", id = "silitido", notas = {
		"Los silítidos son insectos al servicio de un Dios Antiguo dormido bajo Silithus. Su colmena es más grande de lo que parece.",
	} },
	{ tema = "los Roca Negra", id = "rocanegra", notas = {
		"El clan Roca Negra fue el corazón de la vieja Horda. Hoy sus orcos siguen en la Montaña Roca Negra, fieles a la guerra.",
	} },
	{ tema = "los lobos", id = "lobos", notas = {
		"Los orcos cabalgan lobos desde Draenor. Para ellos, un lobo no es una montura: es un hermano de caza. Yo estoy de acuerdo.",
		"Los worgs son lobos grandes y bravos. Ya sé que te los encargan, pero acuérdate: no todos los lobos son malos. Algunos te cuidan.",
	} },
}

local function encendido()
	if N.Get(ID, "loreMisiones") == false then return false end
	local H = M.Historias
	local modo = H and H.Modo and H.Modo() or "aveces"
	return modo == "siempre" or modo == "aveces"
end

local function porTema()
	local t = {}
	for _, e in ipairs(M.LORE_TEMA) do t[e.tema] = e end
	return t
end

-- Los temas de tus misiones de ahora (las que tomaste y no entregaste, de las
-- últimas 2 semanas: lo que guardó Historias.lua).
-- 1.4.0 (control): el tema de cada misión se calcula una vez (H.TemaDe lee
-- todo su texto con unos 60 patrones: 5 ms por latido con 15 misiones
-- abiertas) y se recuerda mientras su texto no cambie.
local temaCache = setmetatable({}, { __mode = "k" }) -- r -> { firma, tema }
local function firma(r) return #(r.t or "") .. ":" .. #(r.d or "") .. ":" .. #(r.o or "") end
-- Como mucho POR_VEZ misiones nuevas por llamada (con 30 misiones largas
-- recién tomadas eran 60 ms de un jalón): las demás, en el siguiente latido.
local POR_VEZ = 3
local presupuesto = POR_VEZ
local function temaDe(H, r)
	local f = firma(r)
	local c = temaCache[r]
	if c and c[1] == f then return c[2] end
	if presupuesto <= 0 then return false end
	presupuesto = presupuesto - 1
	local ok, tema = pcall(H.TemaDe, r)
	tema = ok and tema or false
	temaCache[r] = { f, tema }
	return tema
end

function Lm.Temas()
	local H = M.Historias
	if not (H and H.Todas and H.TemaDe) then return {} end
	local ahora = (GetServerTime and GetServerTime()) or (time and time()) or 0
	local vistos, out = {}, {}
	presupuesto = POR_VEZ
	for _, r in pairs(H.Todas() or {}) do
		if type(r) == "table" and r.a and not r.c and ahora - (tonumber(r.a) or 0) < 14 * 86400 then
			local tema = temaDe(H, r)
			local ok = tema ~= false
			if ok and tema and not vistos[tema] then vistos[tema] = true out[#out + 1] = tema end
		end
	end
	return out
end

local function memoria()
	local d = N.DatosPersonaje(ID)
	d.charla = type(d.charla) == "table" and d.charla or {}
	d.charla.v = type(d.charla.v) == "table" and d.charla.v or {}
	return d.charla.v
end

-- -> e (la entrada del tema), i (la nota), id | nil: una nota nueva de tus temas.
function Lm.Elegir(temas)
	local t = porTema()
	local v = memoria()
	local opciones = {}
	for _, tema in ipairs(temas or Lm.Temas()) do
		local e = t[tema]
		if e then
			for i, _ in ipairs(e.notas) do
				local id = "m" .. e.id .. "." .. i
				if not v[id] then opciones[#opciones + 1] = { e, i, id } end
			end
		end
	end
	if #opciones == 0 then return nil end
	local o = opciones[random(#opciones)]
	return o[1], o[2], o[3]
end

function Lm.Algo(opts)
	opts = opts or {}
	if not encendido() and not opts.pedido then return false end
	local e, i, id = Lm.Elegir()
	if not e then return false end
	local Ce = M.Cerebro
	if not (Ce and Ce.Decir) then return false end
	local texto = format(L["De tu misión de %s: %s"], L[e.tema], L[e.notas[i]])
	local ok, por = Ce.Decir({ texto = texto, pedido = opts.pedido, lineas = 5, ancho = 360, clase = "charla",
		segundos = 10 + math.floor(#texto / 28),
		alDecir = function() memoria()[id] = (GetServerTime and GetServerTime()) or 1 end })
	return ok == true, por
end
