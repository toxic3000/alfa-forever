-- Alfa - La Jauría: los datos del clan que se muestran en su página.
-- Toxic / La Jauría. GPL-3.0.
--
-- Este archivo es para que el clan lo ajuste a su gusto: cambia los textos,
-- la lista de oficiales y el mensaje para pedir invitación. No hace falta
-- tocar nada más del módulo. Guarda el archivo en UTF-8.
--
--   hermandad      el nombre EXACTO de la hermandad en el juego (sin importar
--                  mayúsculas ni acentos), para saber si ya eres parte de ella
--   oficiales      a quién se le pide invitación con "Quiero unirme": nombres
--                  de personaje tal como salen en el juego ("Nombre Apellido")
--   discord        nil usa el enlace de Alfa (Alfa.DiscordURL); pon aquí otro
--                  enlace si el clan tiene uno propio
--   en             los mismos textos en inglés (para clientes que no están en
--                  español); lo que falte se muestra en español

local _, M = ...

M.Clan = {
	nombre = "La Jauría",
	hermandad = "La Jauría",
	lema = "Nadie caza solo.",

	-- Un párrafo por línea. Texto de ejemplo: el clan lo ajusta.
	descripcion = {
		"Somos una manada de jugadores hispanohablantes en WoW Forever. Subimos de nivel juntos, entramos a mazmorras juntos y nos cuidamos la espalda.",
		"No importa si apenas empiezas o si ya conoces cada rincón de Azeroth: aquí siempre hay alguien dispuesto a echarte una mano.",
	},

	-- Lo que encuentras en el clan (texto de ejemplo).
	ofrecemos = {
		"Grupos para mazmorras y misiones de élite",
		"Ayuda y consejos para quien empieza",
		"Eventos de la manada cada semana",
		"Un Discord activo para organizarnos",
	},

	-- A quién pedirle la invitación. Se escribe como lo da el juego; la
	-- comparación acepta "Toxic-Darunia" y "Toxic Darunia" por igual.
	oficiales = {
		"Toxic-Darunia",
	},

	-- Lo que se escribe en el susurro de "Quiero unirme". Quien juega lo ve
	-- antes de enviarlo y lo manda con Intro.
	mensajeUnirse = "¡Hola! Uso Alfa y me gustaría unirme a La Jauría. ¿Me puedes invitar?",

	-- Cómo pedir invitación cuando ningún oficial está conectado.
	comoUnirse = "Pide tu invitación en nuestro Discord o susurra a cualquiera de los oficiales cuando lo veas conectado. Te recibimos con gusto.",

	discord = nil,

	en = {
		lema = "No one hunts alone.",
		descripcion = {
			"We are a pack of Spanish-speaking players on WoW Forever. We level together, run dungeons together and have each other's backs.",
			"Whether you are just starting or know every corner of Azeroth, there is always someone here ready to lend a hand.",
		},
		ofrecemos = {
			"Groups for dungeons and elite quests",
			"Help and tips for new players",
			"Pack events every week",
			"An active Discord to get organised",
		},
		mensajeUnirse = "Hi! I use Alfa and I'd like to join La Jauría. Could you invite me?",
		comoUnirse = "Ask for your invite on our Discord, or whisper any of the officers when you see them online. You're welcome here.",
	},
}
