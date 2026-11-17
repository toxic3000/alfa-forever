-- Alfa - Mazmorras: consejos por jefe para principiantes (toxic3000 / La Jauría). GPL-3.0.
-- Monasterio Escarlata (scarlet-monastery). Formato en LEEME.md.
local _, M = ...
M.Consejos = M.Consejos or {}

M.Consejos["scarlet-monastery"] = {
	general = {
		{ "Tiene cuatro partes que se hacen por separado: Cementerio, Biblioteca, Armería y Catedral, de la más fácil a la más difícil.",
			"It has four parts done separately: Graveyard, Library, Armory and Cathedral, from easiest to hardest." },
		{ "Los cruzados escarlata vienen en grupos y algunos curan: interrumpan a los que curan.",
			"Scarlet crusaders come in groups and some heal: interrupt the healers." },
	},
	[3983] = { -- Interrogator Vishas
		{ "Está en el Cementerio. Pone un dolor de sombras que hace daño con el tiempo.",
			"He is in the Graveyard. He casts a shadow pain that hurts over time." },
		{ "Cura a quien tenga el dolor de sombras; la pelea es corta.",
			"Heal whoever has the shadow pain; the fight is short.", rol = "cura" },
	},
	[4543] = { -- Bloodmage Thalnos
		{ "Es el último del Cementerio. Lanza llamas a su alrededor: si peleas de lejos, quédate lejos.",
			"The last boss of the Graveyard. He sends out flames around him: ranged players, stay back." },
	},
	[3974] = { -- Houndmaster Loksey
		{ "Está en la Biblioteca y llega con sus perros: mátenlos primero o usen ataques en área.",
			"In the Library, with his hounds: kill them first or use area attacks." },
	},
	[6487] = { -- Arcanist Doan
		{ "A mitad de la pelea se protege con un escudo y prepara una gran explosión: cuando lo veas brillar, ¡aléjate de él!",
			"Halfway through he shields himself and charges a big explosion: when you see him glow, get away from him!" },
		{ "Lanza ráfagas arcanas: interrúmpelo.",
			"He casts arcane bursts: interrupt him." },
	},
	[3975] = { -- Herod
		{ "Está en la Armería. Cuando grita, gira con su hacha y golpea a todos los que están cerca: aléjate.",
			"In the Armory. When he shouts he spins with his axe and hits everyone close: move away." },
		{ "Al morir llegan muchos aprendices: prepárense para muchos enemigos a la vez.",
			"When he dies many trainees rush in: get ready for lots of enemies at once." },
	},
	[4542] = { -- High Inquisitor Fairbanks
		{ "Está escondido en la Catedral. Pone maldiciones y se cura: interrúmpelo.",
			"Hidden in the Cathedral. He curses and heals himself: interrupt him." },
	},
	[3977] = { -- High Inquisitor Whitemane
		{ "Primero pelean contra el Comandante Mograine; cuando cae, ella llega y lo resucita.",
			"First you fight Commander Mograine; when he falls she arrives and brings him back." },
		{ "Ella duerme a todo el grupo y luego resucita a Mograine: es normal, no se asusten.",
			"She puts the whole group to sleep and then revives Mograine: that's normal, don't panic." },
		{ "En la segunda parte mátenla a ella primero: cura mucho.",
			"In the second part kill her first: she heals a lot.", rol = "dano" },
	},
	[3976] = { -- Scarlet Commander Mograine
		{ "Pega fuerte y se protege con un escudo de luz: empieza con la vida llena.",
			"He hits hard and shields himself with holy light: start at full health.", rol = "tanque" },
	},
	[6488] = { -- Fallen Champion
		{ "Es raro del Cementerio y no siempre aparece.",
			"A rare spawn in the Graveyard, not always there." },
	},
	[6489] = { -- Ironspine
		{ "Es raro del Cementerio y no siempre aparece. Envenena: quita el veneno.",
			"A rare spawn in the Graveyard, not always there. He poisons: remove it." },
	},
	[6490] = { -- Azshir the Sleepless
		{ "Es raro del Cementerio y no siempre aparece. Puede silenciar a quien lanza hechizos.",
			"A rare spawn in the Graveyard, not always there. He can silence casters." },
	},
}
