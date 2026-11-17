-- Alfa - Mazmorras: consejos por jefe para principiantes (toxic3000 / La Jauría). GPL-3.0.
-- Zahúrda Rajacieno (razorfen-downs). Formato en LEEME.md.
local _, M = ...
M.Consejos = M.Consejos or {}

M.Consejos["razorfen-downs"] = {
	general = {
		{ "Hay muchos no-muertos y jabaespines: lleven algo para quitar enfermedades si su grupo puede.",
			"Lots of undead and quilboars: bring a way to remove diseases if your group can." },
		{ "Cerca de la entrada hay un gong: tocarlo trae oleadas de arañas y luego un jefe.",
			"There is a gong near the entrance: ringing it brings waves of spiders and then a boss." },
	},
	[7355] = { -- Tuten'kash
		{ "Aparece al tocar el gong por tercera vez, después de dos oleadas de arañas.",
			"He appears on the third ring of the gong, after two waves of spiders." },
		{ "Lanza telarañas y una maldición: quita la maldición si puedes.",
			"He shoots webs and casts a curse: remove the curse if you can." },
	},
	[7356] = { -- Plaguemaw the Rotting
		{ "Pasa enfermedades: quítalas si tu clase puede.",
			"He spreads diseases: remove them if your class can." },
	},
	[7357] = { -- Mordresh Fire Eye
		{ "Lanza bolas de fuego y fuego a su alrededor: interrúmpelo y, si peleas de lejos, aléjate.",
			"He casts fireballs and fire around him: interrupt him and, if ranged, stay away." },
	},
	[7354] = { -- Ragglesnout
		{ "No siempre aparece. Pone un dolor de sombras: cura a quien lo tenga.",
			"Not always there. He casts a shadow pain: heal whoever has it." },
	},
	[8567] = { -- Glutton
		{ "Suelta una nube de enfermedad a su alrededor: quiten enfermedades.",
			"He releases a disease cloud around him: remove diseases." },
		{ "Se enfurece con poca vida: termínenlo rápido.",
			"He enrages at low health: finish him fast." },
	},
	[7358] = { -- Amnennar the Coldbringer
		{ "Congela a los que están cerca: si peleas de lejos, aléjate.",
			"He freezes players close to him: ranged players, stay away." },
		{ "A mitad de la pelea aparecen espectros de hielo: mátenlos rápido o usen ataques en área.",
			"Halfway through, frost spectres appear: kill them fast or use area attacks.", rol = "dano" },
	},
}
