-- Alfa - Mazmorras: consejos por jefe para principiantes (Toxic / La Jauría). GPL-3.0.
-- Horado Rajacieno (razorfen-kraul). Formato en LEEME.md.
local _, M = ...
M.Consejos = M.Consejos or {}

M.Consejos["razorfen-kraul"] = {
	general = {
		{ "Está lleno de jabaespines y sus túneles de espinos: tiren de pocos a la vez.",
			"Full of quilboars in thorny tunnels: pull a few at a time." },
		{ "Los geomantes lanzan fuego y ponen tótems: interrúmpanlos y rompan los tótems.",
			"Geomancers cast fire and drop totems: interrupt them and break the totems." },
	},
	[6168] = { -- Roogug
		{ "Lanza hechizos de tierra y pone tótems: rompan los tótems primero.",
			"He casts earth spells and drops totems: break the totems first." },
	},
	[4424] = { -- Aggem Thorncurse
		{ "Invoca un espíritu de jabalí: mátenlo o que alguien lo tanquee.",
			"He summons a boar spirit: kill it or have someone tank it." },
		{ "Se cura: interrúmpelo.",
			"He heals himself: interrupt him." },
	},
	[4428] = { -- Death Speaker Jargba
		{ "Puede controlar la mente de un jugador: no lo ataquen, esperen a que se le pase.",
			"He can take control of a player's mind: don't attack that player, wait for it to end." },
		{ "Lanza sombras: interrúmpelo.",
			"He casts shadow spells: interrupt him." },
	},
	[4420] = { -- Overlord Ramtusk
		{ "Llega con guardias: tírenlos aparte si pueden.",
			"He comes with guards: pull them away from him if you can." },
		{ "Golpea a los que tiene alrededor: gíralo lejos del grupo.",
			"He hits those around him: turn him away from the group.", rol = "tanque" },
	},
	[4422] = { -- Agathelos the Raging
		{ "Avienta a todos los que están cerca: si peleas de lejos, aléjate.",
			"He knocks back everyone close to him: ranged players, keep away." },
		{ "Se enfurece al final: guarden su mejor daño.",
			"He enrages at the end: save your best damage." },
	},
	[4421] = { -- Charlga Razorflank
		{ "Cura a sus ayudantes y a sí misma: interrúmpanla.",
			"She heals her helpers and herself: interrupt her." },
		{ "Sus rayos saltan entre jugadores: sepárense.",
			"Her lightning jumps between players: spread out." },
	},
	[4425] = { -- Blind Hunter
		{ "Es raro y está en una cueva escondida. Es un murciélago que pega rápido.",
			"A rare spawn in a hidden cave. A bat that hits fast." },
	},
	[4842] = { -- Earthcaller Halmgar
		{ "Es raro. Pone un tótem de tierra: rómpelo.",
			"A rare spawn. He drops an earth totem: break it." },
	},
}
