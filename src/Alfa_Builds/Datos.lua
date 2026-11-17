-- Alfa - Builds: vocabulario y registro de builds (toxic3000 / La Jauría). GPL-3.0.
--
-- Cada archivo Builds/<Clase>.lua llama a M.Clase({...}) con sus builds.
-- Un build es una lista ordenada de talentos (por spellID, con el nombre en
-- inglés de respaldo) que se resuelve en el juego a los nodos reales del
-- árbol (Arbol.lua). Solo se guarda la clase del personaje: las demás se
-- dejan al recolector de basura, como hace el motor con sus planes.
--
--   M.Clase(def)                 -- registra la clase (desde Builds/*.lua)
--   M.DatosClase(token?) -> def  -- la clase del jugador (o la pedida)
--   M.Build(id) -> build | nil
--   M.Builds() -> lista de builds de la clase (orden del archivo)
--   M.Elegir(objetivo, estilo, spec?) -> build, exacto (bool)
--   M.Recomendado(objetivo) -> build | nil
--
-- build = { id, spec, objetivo, estilo, titulo, resumen, armas, talentos,
--           stats, pesos, profesiones, consejos, picks (expandidos: uno por
--           punto { i, spell, rank, nombre, por, entrada }), total }

local ADDON, M = ...
local N = AlfaNucleo
M.N, M.A = N, N.A
M.EN = M.EN or {}
local L = N.Textos(M.EN)
M.L = L

M.ID = "builds"

---------------------------------------------------------------------------
-- Objetivos y estilos
---------------------------------------------------------------------------

M.OBJETIVOS = {
	{ clave = "solo", nombre = L["Subir solo"], icono = "icon-kill",
		desc = L["Misiones y monstruos por tu cuenta, sin depender de nadie."] },
	{ clave = "mazmorras", nombre = L["Mazmorras"], icono = "icon-dungeon",
		desc = L["Daño en grupo de cinco: pegar fuerte sin robarle los monstruos al tanque."] },
	{ clave = "tanque", nombre = L["Tanque"], icono = "icon-elite",
		desc = L["Tú recibes los golpes y proteges al grupo. Necesitas escudo."] },
	{ clave = "jcj", nombre = L["JcJ"], icono = "flag",
		desc = L["Pelear contra otros jugadores: aguantar, frenar y rematar."] },
}

M.ESTILOS = {
	{ clave = "tranquilo", nombre = L["Tranquilo"], riesgo = 1, icono = "icon-hearth",
		desc = L["Más aguante y seguridad. Matas un poco más lento, pero casi no mueres."] },
	{ clave = "equilibrado", nombre = L["Equilibrado"], riesgo = 2, icono = "compact",
		desc = L["Lo mejor de los dos lados. Si no sabes cuál elegir, elige este."] },
	{ clave = "arriesgado", nombre = L["Arriesgado"], riesgo = 3, icono = "bolt",
		desc = L["Más daño y más riesgo. Matas rápido, pero un error se paga caro."] },
}

local OBJ, EST = {}, {}
for i, o in ipairs(M.OBJETIVOS) do o.orden = i; OBJ[o.clave] = o end
for i, e in ipairs(M.ESTILOS) do e.orden = i; EST[e.clave] = e end
function M.Objetivo(clave) return OBJ[clave] end
function M.Estilo(clave) return EST[clave] end

---------------------------------------------------------------------------
-- Estadísticas: nombre y por qué sirven (claves del motor, Gear.STAT_KEYS)
---------------------------------------------------------------------------

M.STATS = {
	str = { nombre = L["Fuerza"], porque = L["Te da poder de ataque: cada golpe pega más. Para el guerrero también sube el bloqueo con escudo."] },
	agi = { nombre = L["Agilidad"], porque = L["Un poco de golpe crítico, de esquivar y de armadura."] },
	sta = { nombre = L["Aguante"], porque = L["Más vida: aguantas más golpes antes de tener que comer o descansar."] },
	int = { nombre = L["Intelecto"], porque = L["Más maná y algo de crítico con hechizos."] },
	spi = { nombre = L["Espíritu"], porque = L["Recuperas vida y maná más rápido cuando no lanzas hechizos."] },
	armor = { nombre = L["Armadura"], porque = L["Reduce el daño físico que recibes."] },
	ap = { nombre = L["Poder de ataque"], porque = L["Daño directo de tus armas y habilidades."] },
	rap = { nombre = L["Poder de ataque a distancia"], porque = L["Daño de arcos, armas de fuego y ballestas."] },
	sp = { nombre = L["Poder con hechizos"], porque = L["Tus hechizos de daño pegan más."] },
	heal = { nombre = L["Sanación"], porque = L["Tus curas curan más."] },
	crit = { nombre = L["Golpe crítico"], porque = L["Los críticos hacen el doble de daño y al guerrero le dan más ira."] },
	hit = { nombre = L["Precisión"], porque = L["Fallas menos golpes, sobre todo contra monstruos de nivel más alto que el tuyo."] },
	spellCrit = { nombre = L["Crítico con hechizos"], porque = L["Tus hechizos hacen crítico más seguido."] },
	spellHit = { nombre = L["Precisión con hechizos"], porque = L["Tus hechizos fallan menos."] },
	mp5 = { nombre = L["Maná cada 5 s"], porque = L["Recuperas maná incluso mientras peleas."] },
	hp5 = { nombre = L["Salud cada 5 s"], porque = L["Recuperas vida poco a poco, incluso en combate."] },
	defense = { nombre = L["Defensa"], porque = L["Evita golpes críticos y aplastantes: lo más importante para un tanque."] },
	dodge = { nombre = L["Esquivar"], porque = L["A veces el golpe ni te toca."] },
	parry = { nombre = L["Parar"], porque = L["Desvías golpes con tu arma."] },
	block = { nombre = L["Bloqueo"], porque = L["Más golpes bloqueados con el escudo, y cada bloqueo te da ira."] },
	blockValue = { nombre = L["Valor de bloqueo"], porque = L["Cuánto daño quita cada bloqueo; también sube el daño de Embate con escudo."] },
	dps = { nombre = L["Daño del arma"], porque = L["El daño por segundo del arma: para el guerrero, lo que más cuenta al subir."] },
	rdps = { nombre = L["Daño a distancia"], porque = L["El daño por segundo de tu arma a distancia."] },
}

---------------------------------------------------------------------------
-- Profesiones
---------------------------------------------------------------------------

M.PROFESIONES = {
	mining = { nombre = L["Minería"], icono = "Interface\\Icons\\Trade_Mining" },
	blacksmithing = { nombre = L["Herrería"], icono = "Interface\\Icons\\Trade_BlackSmithing" },
	herbalism = { nombre = L["Herboristería"], icono = "Interface\\Icons\\Trade_Herbalism" },
	alchemy = { nombre = L["Alquimia"], icono = "Interface\\Icons\\Trade_Alchemy" },
	skinning = { nombre = L["Desuello"], icono = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
	leatherworking = { nombre = L["Peletería"], icono = "Interface\\Icons\\Trade_LeatherWorking" },
	engineering = { nombre = L["Ingeniería"], icono = "Interface\\Icons\\Trade_Engineering" },
	tailoring = { nombre = L["Sastrería"], icono = "Interface\\Icons\\Trade_Tailoring" },
	enchanting = { nombre = L["Encantamiento"], icono = "Interface\\Icons\\Trade_Engraving" },
	firstaid = { nombre = L["Primeros auxilios"], icono = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
	cooking = { nombre = L["Cocina"], icono = "Interface\\Icons\\INV_Misc_Food_15" },
}

-- Por objetivo y tipo de armadura: dos principales y su porqué.
-- armadura: "placas" (guerrero, paladín), "cuero" (pícaro, druida),
-- "malla" (cazador, chamán), "tela" (mago, sacerdote, brujo).
M.PROF_SUGERIDAS = {
	solo = {
		placas = { "mining", "skinning", L["Las dos se suben solas mientras matas y viajas, y lo que juntas se vende bien: oro para tu montura y tus habilidades."] },
		cuero = { "skinning", "leatherworking", L["Desuellas lo que matas y lo conviertes en armaduras de cuero para ti; lo que sobra se vende."] },
		malla = { "skinning", "mining", L["Dos profesiones de recolección: oro constante sin perder tiempo, justo cuando más lo necesitas."] },
		tela = { "herbalism", "alchemy", L["Recoges hierbas por el camino y haces pociones de vida y maná: menos descanso y más seguridad."] },
	},
	mazmorras = {
		placas = { "mining", "blacksmithing", L["Herrería fabrica armas y armadura de placas muy buenas para tu nivel, y Minería te da el material gratis."] },
		cuero = { "skinning", "leatherworking", L["Peletería hace piezas de cuero con agilidad y aguante; Desuello te da el cuero."] },
		malla = { "skinning", "leatherworking", L["Peletería hace malla para ti; Desuello te da el material sin gastar oro."] },
		tela = { "tailoring", "enchanting", L["Sastrería hace tu ropa con lo que cae en mazmorras, y Encantamiento deshace lo que no usas y mejora tu equipo."] },
	},
	tanque = {
		placas = { "mining", "blacksmithing", L["Herrería fabrica escudos y placas con defensa y aguante, justo lo que un tanque necesita."] },
		cuero = { "skinning", "leatherworking", L["Peletería hace cuero con armadura y aguante para la forma de oso."] },
		malla = { "mining", "blacksmithing", L["Herrería fabrica escudos y piezas resistentes."] },
		tela = { "tailoring", "enchanting", L["Sastrería y Encantamiento: tu equipo siempre al día."] },
	},
	jcj = {
		placas = { "engineering", "mining", L["Ingeniería da granadas, redes y bombas que deciden peleas contra jugadores; Minería da el material."] },
		cuero = { "engineering", "mining", L["Ingeniería da aturdimientos y trucos que ganan duelos; Minería da el material."] },
		malla = { "engineering", "mining", L["Ingeniería da granadas y redes para controlar al rival; Minería da el material."] },
		tela = { "engineering", "tailoring", L["Ingeniería te salva con trucos de escape; Sastrería hace tu ropa."] },
	},
}
M.PROF_SECUNDARIAS = {
	{ "firstaid", L["Vendas para curarte sin gastar maná ni esperar: imprescindible para todos."] },
	{ "cooking", L["Comida que da aguante o fuerza extra, y comes mientras descansas."] },
}

M.ARMADURA = {
	WARRIOR = "placas", PALADIN = "placas", ROGUE = "cuero", DRUID = "cuero",
	HUNTER = "malla", SHAMAN = "malla", MAGE = "tela", PRIEST = "tela", WARLOCK = "tela",
}

---------------------------------------------------------------------------
-- Ajustes de pesos por estilo y objetivo: multiplican los pesos del motor
-- (Gear.WeightsFor) para que la escala refleje la forma de jugar.
---------------------------------------------------------------------------

M.AJUSTE_PESOS = {
	tranquilo = { sta = 1.5, armor = 1.5, dodge = 1.3, parry = 1.3, defense = 1.3, hp5 = 1.5, health = 1.5 },
	equilibrado = {},
	arriesgado = { crit = 1.15, spellCrit = 1.15, str = 1.05, agi = 1.05, sta = 0.75, armor = 0.75 },
	mazmorras = { hit = 1.25, spellHit = 1.25, sta = 0.85 },
	jcj = { sta = 1.4, crit = 1.1, armor = 1.2 },
	tanque = {},
}

---------------------------------------------------------------------------
-- Registro
---------------------------------------------------------------------------

local clases = {} -- token -> def
local porId = {}

local function claseJugador()
	local _, token = UnitClass("player")
	if M.A and M.A.Compat and M.A.Compat.Readable then token = M.A.Compat.Readable(token) end
	return type(token) == "string" and token or nil
end
M.ClaseJugador = claseJugador

-- Expande las entradas { spell, hasta, nombre, por } en picks de un punto.
local function expandir(b)
	local picks, rangos = {}, {}
	for e, t in ipairs(b.talentos or {}) do
		local spell, hasta, nombre, por = t[1], t[2], t[3], t[4]
		local desde = (rangos[spell] or 0) + 1
		for r = desde, hasta do
			picks[#picks + 1] = { i = #picks + 1, spell = spell, rank = r, nombre = nombre, por = (r == desde) and por or nil, entrada = e }
		end
		if hasta > (rangos[spell] or 0) then rangos[spell] = hasta end
	end
	b.picks, b.total = picks, #picks
	return b
end
M.Expandir = expandir

function M.Clase(def)
	if type(def) ~= "table" or type(def.clase) ~= "string" then return end
	local mia = claseJugador()
	if mia and def.clase ~= mia then return end
	def.builds = def.builds or {}
	for _, b in ipairs(def.builds) do
		b.clase = def.clase
		b.data = def
		expandir(b)
		porId[b.id] = b
	end
	clases[def.clase] = def
end

function M.DatosClase(token) return clases[token or claseJugador() or ""] end

function M.Builds(token)
	local d = M.DatosClase(token)
	return d and d.builds or {}
end

-- Un build por id: los de la clase y los importados (Compartir.lua).
function M.Build(id)
	if not id then return nil end
	if porId[id] then return porId[id] end
	if M.Importado then return M.Importado(id) end
end

function M.RegistrarSuelto(b)
	expandir(b)
	porId[b.id] = b
	return b
end
function M.OlvidarSuelto(id) porId[id] = nil end

function M.Recomendado(objetivo)
	local d = M.DatosClase()
	if not d then return nil end
	local id = d.recomendados and d.recomendados[objetivo]
	return id and porId[id] or nil
end

-- El build para un objetivo y un estilo. spec (opcional) prefiere esa rama.
-- Si no existe la combinación exacta: misma rama y objetivo con el estilo más
-- cercano; luego el recomendado del objetivo; luego cualquiera del objetivo.
-- -> build, exacto
function M.Elegir(objetivo, estilo, spec)
	local lista = M.Builds()
	if #lista == 0 then return nil, false end
	local want = EST[estilo] and EST[estilo].riesgo or 2
	local function mejor(filtro)
		local best, bd
		for _, b in ipairs(lista) do
			if filtro(b) then
				local d = math.abs(((EST[b.estilo] or {}).riesgo or 2) - want)
				if not best or d < bd then best, bd = b, d end
			end
		end
		return best
	end
	if spec then
		local b = mejor(function(x) return x.objetivo == objetivo and x.spec == spec end)
		if b then return b, b.estilo == estilo end
	end
	local rec = M.Recomendado(objetivo)
	if rec then
		local b = mejor(function(x) return x.objetivo == objetivo and x.spec == rec.spec end)
		if b then return b, b.estilo == estilo end
	end
	local b = mejor(function(x) return x.objetivo == objetivo end)
	if b then return b, b.estilo == estilo end
	return mejor(function() return true end), false
end

-- ¿Hay builds de esa rama para ese objetivo? (para atenuar opciones)
function M.Hay(objetivo, estilo)
	for _, b in ipairs(M.Builds()) do
		if b.objetivo == objetivo and (not estilo or b.estilo == estilo) then return true end
	end
	return false
end

-- Profesiones de un build: las suyas o las sugeridas por objetivo y armadura.
function M.Profesiones(b)
	if b.profesiones then return b.profesiones end
	local arm = M.ARMADURA[b.clase] or "tela"
	local obj = M.PROF_SUGERIDAS[b.objetivo] or M.PROF_SUGERIDAS.solo
	return obj[arm] or obj.tela
end

-- Nombre de una rama en el idioma del jugador.
function M.NombreSpec(b)
	local d = b and b.data or M.DatosClase()
	local s = d and d.especialidades and d.especialidades[b and b.spec or ""]
	return s and s.nombre or (b and b.spec) or "?"
end
