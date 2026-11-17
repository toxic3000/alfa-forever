-- Alfa - Lya: lo que dice (toxic3000 / La Jauría). GPL-3.0.
--
-- Cada frase es una clave en español (su inglés está en Textos.lua). Su id
-- es la categoría y su número ("nivel3"): con él se cuenta cuántas veces la
-- dijo a este personaje (tres a lo más, luego nunca más). Las frases nuevas
-- van AL FINAL de su lista, para no mover los números de las que ya existen.
--
--   M.FRASES[categoria] = { "texto", ... }     ids categoria1, categoria2...
--   M.SABIAS = { { t, cond(), accion = { texto, fn(ancla) } }, ... }   ids sabias1...

local ADDON, M = ...
local N = AlfaNucleo
local L = M.L

local type, rawget = type, rawget

local F = {}
M.FRASES = F

-- La primera vez (después de la bienvenida de Alfa). Una sola vez.
F.presentacion = {
	"¡Hola! Soy Lya, la loba de confianza del Alfa. Cuido a la manada y voy contigo en el camino.",
}

-- Al entrar (%s: tu nombre).
F.bienvenida = {
	"¡Qué gusto verte, %s! La manada ya te esperaba.",
	"¡Hola, %s! Hoy huele a buena cacería.",
	"¡Volviste, %s! Estira las patas y vámonos.",
	"¡Ahí estás, %s! Si quieres un consejo, dame clic.",
	"¡Buenas, %s! Paso a paso se llega lejos.",
	"¡Qué bueno tenerte de vuelta, %s! Aquí sigo, cuidándote la espalda.",
}

-- Al entrar después de varios días (%s: tu nombre).
F.volver = {
	"¡%s! Hace días que no te veía. En Hoy te digo dónde íbamos.",
	"¡Te extrañé, %s! Tu ruta sigue donde la dejaste.",
	"Mucho tiempo sin verte, %s. Repasa tus misiones antes de salir.",
}

-- Subir de nivel (%d: el nivel nuevo).
F.nivel = {
	"¡Nivel %d! ¡Auuu! Así se sube en manada.",
	"¡Nivel %d, bien hecho! Revisa si tu entrenador tiene algo nuevo.",
	"¡Subiste a nivel %d! Cada nivel te hace más fuerte.",
	"¡Nivel %d! Tu esfuerzo se nota. Sigue así.",
	"¡Ya eres nivel %d! La manada aúlla por ti.",
	"¡Nivel %d! Date un momento para presumirlo, te lo ganaste.",
	"¡Arriba, nivel %d! Si tienes un punto de talento libre, no lo olvides.",
	"¡Nivel %d! Paso firme y colmillo afilado.",
}

-- Niveles especiales (una frase cada uno; la acción la pone Cerebro.lua).
F.hito10 = { "¡Nivel 10! Ya tienes talentos: elígelos con calma, Talentos te ayuda." }
F.hito20 = { "¡Nivel 20! Ya puedes con mazmorras de verdad. ¿Armamos grupo?" }
F.hito30 = { "¡Nivel 30! Ya vas a la mitad del camino. ¡Qué orgullo de manada!" }
F.hito40 = { "¡Nivel 40! Ya puedes aprender a montar. ¡Tu primera montura te espera!" }
F.hito50 = { "¡Nivel 50! Ya se huele la cima. Junta oro para lo que viene." }
F.hito60 = { "¡Nivel 60! ¡Lo lograste, alfa! Ahora toca cazar en grande." }

-- Al morir.
F.muerte = {
	"¡Arriba, lobo! Libera tu espíritu: la flecha te dice si conviene tu cuerpo o el sanador.",
	"¡Arriba, lobo! Caer es parte de la cacería. Al revivir, repara tu equipo.",
	"Con calma, nos pasa a todos. Mira qué te pegó y vuelve con todo.",
	"¡Arriba, lobo! Antes de volver a pelear, recupera vida y maná.",
	"Hasta el alfa se cae. Lo importante es levantarse. ¡Vamos!",
	"¡Arriba, lobo! Si eran muchos, la próxima jálalos de uno en uno.",
}

-- Equipo gastado (%d: la pieza más gastada, en %).
F.reparar = {
	"Tu equipo está al %d%%. Mejor repararlo antes de la siguiente pelea.",
	"Ojo: tu equipo anda al %d%%. Un herrero te lo deja como nuevo.",
	"Tu armadura ya no aguanta mucho (%d%%). ¿Vamos a reparar?",
}

-- Bolsas casi llenas (%d: espacios libres).
F.bolsas = {
	"Bolsas casi llenas (%d libres). Vende lo gris y haz lugar para el botín.",
	"Ya casi no cabe nada: %d libres. Lo gris es oro fácil con cualquier vendedor.",
	"Tus bolsas piden auxilio (%d libres). Vende o tira lo que ya no uses.",
}

-- Habilidades por aprender (%d: cuántas).
F.entrenar = {
	"Habilidades nuevas por aprender: %d. Tu entrenador te espera.",
	"Tienes habilidades sin aprender (%d). Aprenderlas te hace más fuerte.",
	"Estás en la ciudad y hay habilidades por entrenar (%d). ¡Aprovecha!",
}

-- Misiones listas para entregar (%d: cuántas, 3 o más).
F.entregar = {
	"Tienes %d misiones listas para entregar. ¿Las juntamos en una ruta?",
	"%d misiones listas. Entregarlas de una vez ahorra mucho camino.",
	"¡Ya terminaste %d misiones! Vamos a cobrar la recompensa.",
}

-- Sesión larga (%s: cuánto llevas, "2 h 05 min").
F.descanso = {
	"Llevas %s jugando. Estírate, toma agua y regresas con más fuerza.",
	"Ya van %s de cacería. Un descanso corto también es de lobos sabios.",
	"Llevas %s. Si cierras sesión en una posada, ganas XP descansada.",
	"Llevas %s. La manada te espera aunque te tomes un respiro.",
}

-- Misiones entregadas hoy (%d: cuántas).
F.misionesHoy = {
	"¡%d misiones entregadas hoy! Así se caza en manada.",
	"¡%d misiones hoy! Estás que no te para nadie.",
}

-- Consejos del juego (al pedir uno o de vez en cuando).
F.consejo = {
	"Come y bebe entre peleas: recuperas vida y maná mucho más rápido.",
	"Antes de atacar, mira quién está cerca. Pelear con uno a la vez es más seguro.",
	"Habla con el maestro de vuelo de cada pueblo nuevo: así aprendes la ruta.",
	"Tu piedra de hogar te regresa a tu posada. Úsala para ahorrar caminata.",
	"Vende lo gris cada vez que pases por un pueblo: es oro fácil y libera espacio.",
	"Las profesiones de recolección dan oro desde el nivel 1. ¡Hierbas o minería!",
	"Primeros auxilios sirve a cualquier clase: unas vendas te sacan de apuros.",
	"Si una misión se pone difícil, pide ayuda en el chat. En manada todo pesa menos.",
	"Lee los objetivos de la misión antes de salir: te ahorras vueltas.",
	"Pon tu piedra de hogar en la posada donde tengas más misiones.",
	"Retirarse a tiempo también es estrategia. Corre hacia tus aliados.",
	"Consigue bolsas más grandes en cuanto puedas: más espacio, más botín.",
	"Las misiones grises dan poca XP. Entrégalas y sigue adelante.",
	"Junta misiones de la misma zona: haces varias en un solo viaje.",
	"Revisa tu equipo al subir de nivel: una mejora pequeña también cuenta.",
}

-- Ánimo.
F.animo = {
	"Vas muy bien. Cada paso cuenta, aunque no lo parezca.",
	"La manada es fuerte porque cada lobo lo es. Y tú lo eres.",
	"Si hoy cuesta, mañana sale. Aquí sigo contigo.",
	"Me encanta cazar contigo. ¡Vamos por la siguiente!",
	"No hay prisa: el camino también se disfruta.",
	"¡Qué buena racha traes! Sigue así.",
	"Cada misión que terminas te hace más fuerte.",
	"Respira, enfócate y a darle. Tú puedes.",
}

-- Cariño (muy de vez en cuando).
F.carino = {
	"Gracias por dejarme acompañarte.",
	"Me gusta cuidarte la espalda. Para eso estoy.",
	"Aquí estoy, como siempre. Nunca dejo a nadie atrás.",
}

-- Cuando ya dijo todo (no se cuenta).
M.AGOTADOS = "Ya te conté todo lo que sé por ahora. Con clic derecho puedo empezar de nuevo."

---------------------------------------------------------------------------
-- ¿Sabías que…? Lo que Alfa puede hacer. Solo las que existen en este
-- juego (cond) y con un botón que lo abre.
---------------------------------------------------------------------------
local function hay(nombre, fn)
	local g = rawget(_G, nombre)
	return type(g) == "table" and (not fn or type(g[fn]) == "function")
end
local function modulo(id) return N.ModuloPorId(id) ~= nil end
local function llamar(nombre, fn, ...)
	local g = rawget(_G, nombre)
	if type(g) == "table" and type(g[fn]) == "function" then return g[fn](...) end
end

M.SABIAS = {
	{ t = "¿Sabías que…? Buscar cerca te lleva al herrero, al banco o al vuelo más cercano.",
		cond = function() return hay("AlfaCerca", "Menu") end,
		accion = { "Buscar cerca", function(ancla) llamar("AlfaCerca", "Menu", ancla) end } },
	{ t = "¿Sabías que…? En Mis planes armas tu propia lista de metas y la flecha te guía.",
		cond = function() return hay("AlfaPlanes") and modulo("rutas") end,
		accion = { "Ver mis planes", function() N.Abrir("rutas") end } },
	{ t = "¿Sabías que…? La Enciclopedia te dice dónde sale cada objeto, PNJ o misión.",
		cond = function() return hay("AlfaEnciclopedia", "Abrir") end,
		accion = { "Abrir la Enciclopedia", function() llamar("AlfaEnciclopedia", "Abrir") end } },
	{ t = "¿Sabías que…? Alt+clic en un objeto lo abre en la Enciclopedia.",
		cond = function() return hay("AlfaEnciclopedia", "Abrir") end },
	{ t = "¿Sabías que…? El mapa de Alfa muestra el terreno, tus marcadores y lo que hay cerca.",
		cond = function() return hay("AlfaMundo", "Abrir") end,
		accion = { "Abrir el mapa", function() llamar("AlfaMundo", "Abrir") end } },
	{ t = "¿Sabías que…? Con /alfa reportar le cuentas a toxic3000 de un error o una idea.",
		cond = function() return hay("AlfaReporte", "Abrir") end,
		accion = { "Reportar algo", function() llamar("AlfaReporte", "Abrir") end } },
	{ t = "¿Sabías que…? Alfa junta tus misiones listas en una sola ruta corta.",
		cond = function() return hay("AlfaRuta", "Entregar") and modulo("rutas") end,
		accion = { "Ver mi ruta", function() N.Abrir("rutas") end } },
	{ t = "¿Sabías que…? La página Hoy te dice qué hacer ahora y lo urgente de tu personaje.",
		cond = function() return modulo("inicio") end,
		accion = { "Abrir Hoy", function() N.Abrir("inicio") end } },
	{ t = "¿Sabías que…? En Talentos ves qué talento poner ahora y por qué.",
		cond = function() return modulo("builds") end,
		accion = { "Ver Talentos", function() N.Abrir("builds") end } },
	{ t = "¿Sabías que…? En Bolsas ves tus bolsas, tu banco y lo de todos tus personajes.",
		cond = function() return modulo("bolsas") end,
		accion = { "Ver Bolsas", function() N.Abrir("bolsas") end } },
	{ t = "¿Sabías que…? Con Pesca lanzas y recoges con una sola tecla.",
		cond = function() return modulo("pesca") end,
		accion = { "Ver Pesca", function() N.Abrir("pesca") end } },
	{ t = "¿Sabías que…? Mazmorras te dice cuál te toca y cómo prepararte.",
		cond = function() return modulo("mazmorras") end,
		accion = { "Ver Mazmorras", function() N.Abrir("mazmorras") end } },
	{ t = "¿Sabías que…? Comercio te dice si algo conviene venderlo, subastarlo o convertirlo.",
		cond = function() return modulo("comercio") end,
		accion = { "Ver Comercio", function() N.Abrir("comercio") end } },
	{ t = "¿Sabías que…? Recolección te marca en el mapa minerales, hierbas y bancos de peces.",
		cond = function() return modulo("recoleccion") end,
		accion = { "Ver Recolección", function() N.Abrir("recoleccion") end } },
	{ t = "¿Sabías que…? Alfa tiene tres estilos: Alfa, Clásico WoW y Cristal. Y yo me pongo el que elijas.",
		cond = function() return N.Kit and N.Kit.ESTILOS ~= nil end },
	{ t = "¿Sabías que…? Con el botón del minimapa ocultas todo Alfa y lo vuelves a traer.",
		cond = function() return true end },
	{ t = "¿Sabías que…? Con clic derecho sobre mí puedes silenciarme una hora o pedirme menos consejos.",
		cond = function() return true end },
	{ t = "¿Sabías que…? En La Jauría ves a tu grupo y a la manada que usa Alfa.",
		cond = function() return modulo("manada") end,
		accion = { "Ver La Jauría", function() N.Abrir("manada") end } },
}

-- El recuerdo de Lya (la tarjeta de su página; AlfaLya.Recuerdo()).
M.RECUERDO_TITULO = "Sobre Lya"
M.RECUERDO = "Lya fue una gran perrita: noble, leal y siempre al lado de los suyos, la gordita consentida de la casa. Alfa la recuerda así, como la loba que cuida a la manada y nunca deja a nadie atrás."
M.RECUERDO_PIE = "En memoria de una gran perrita"

-- Para que la clave quede a mano de L (y de tools/textos.py) sin traducir aquí.
M.T = function(clave) return L[clave] end
