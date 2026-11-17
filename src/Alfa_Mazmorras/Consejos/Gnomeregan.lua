-- Alfa - Mazmorras: consejos por jefe para principiantes (toxic3000 / La Jauría). GPL-3.0.
-- Gnomeregan (gnomeregan). Formato en LEEME.md.
local _, M = ...
M.Consejos = M.Consejos or {}

M.Consejos["gnomeregan"] = {
	general = {
		{ "Es larga y tiene muchos robots: algunos ponen bombas o hacen sonar alarmas que traen más enemigos.",
			"Long, with many robots: some drop bombs or sound alarms that bring more enemies." },
		{ "Los enemigos lanzan radiación y veneno: lleven pociones de vida.",
			"Enemies use radiation and poison: bring health potions." },
	},
	[7361] = { -- Grubbis
		{ "Aparece en el evento de la explosivista: protégela mientras llegan oleadas de troggs.",
			"He appears in the blastmaster's event: protect her while waves of troggs arrive." },
		{ "Llega con su perro: una persona debe tanquear a cada uno, o maten al perro primero.",
			"He brings his dog: one person tanks each, or kill the dog first." },
	},
	[7079] = { -- Viscous Fallout
		{ "Lanza veneno a todos: quita el veneno si puedes.",
			"He hits everyone with poison: remove it if you can." },
		{ "Es lento: si peleas de lejos, atácalo mientras se acerca.",
			"He is slow: ranged players can hit him while he approaches." },
	},
	[6235] = { -- Electrocutioner 6000
		{ "Su electricidad salta de un jugador a otro: sepárense.",
			"His lightning jumps between players: spread out." },
		{ "Suelta una llave que abre una puerta más adelante: alguien debe recogerla.",
			"He drops a key that opens a door further on: someone has to pick it up." },
	},
	[6229] = { -- Crowd Pummeler 9-60
		{ "Golpea a todos los que están cerca y los avienta: si peleas cuerpo a cuerpo, cuida tu vida.",
			"He hits and knocks back everyone close: melee players, watch your health." },
		{ "Después de cada golpe, regresa a tu lugar rápido.",
			"After each knockback, get back into position fast.", rol = "tanque" },
	},
	[7800] = { -- Mekgineer Thermaplugg
		{ "Activa máquinas en las paredes que sueltan bombas que caminan: pulsa el botón junto a la máquina para apagarla, o maten las bombas antes de que lleguen.",
			"He turns on wall machines that release walking bombs: press the button next to a machine to shut it off, or kill the bombs before they arrive." },
		{ "Golpea y avienta al tanque: regresa a tu lugar rápido.",
			"He knocks the tank away: get back in place fast.", rol = "tanque" },
	},
	[6228] = { -- Dark Iron Ambassador
		{ "Es raro y aparece pocas veces. Usa fuego a su alrededor.",
			"A rare spawn that seldom appears. He uses fire around him." },
	},
}
