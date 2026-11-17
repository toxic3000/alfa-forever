-- Alfa - Mazmorras: consejos por jefe para principiantes (toxic3000 / La Jauría). GPL-3.0.
-- Uldaman (uldaman). Formato en LEEME.md.
local _, M = ...
M.Consejos = M.Consejos or {}

M.Consejos["uldaman"] = {
	general = {
		{ "Es larga y tiene dos entradas. Muchos enemigos son de piedra y pegan fuerte.",
			"Long, with two entrances. Many enemies are made of stone and hit hard." },
		{ "Los troggs huyen cuando tienen poca vida y traen amigos: deténganlos antes de que escapen.",
			"Troggs flee at low health and bring friends: stop them before they get away." },
	},
	[6910] = { -- Revelosh
		{ "Es un trogg que lanza rayos: interrúmpelo.",
			"A trogg who casts lightning: interrupt him." },
		{ "Sus rayos saltan entre jugadores: sepárense.",
			"His lightning jumps between players: spread out." },
	},
	e548 = { -- The Lost Dwarves (Baelog, Eric "The Swift", Olaf)
		{ "Son tres enanos que pelean juntos: uno dispara de lejos, otro es muy veloz y otro se protege con escudo. Mátenlos uno por uno.",
			"Three dwarves fighting together: one shoots from range, one is very fast and one shields himself. Kill them one by one." },
	},
	[6906] = { -- Baelog
		{ "Dispara desde lejos: alguien debe ir por él.",
			"He shoots from range: someone has to go get him." },
	},
	[6907] = { -- Eric "The Swift"
		{ "Es muy veloz: frénalo si tu clase puede.",
			"He is very fast: slow him if your class can." },
	},
	[6908] = { -- Olaf
		{ "Se protege con su escudo y aturde: ataquen a los otros dos primero.",
			"He shields himself and stuns: kill the other two first." },
	},
	[7228] = { -- Ironaya
		{ "Avienta y aturde a todos los que están cerca: ponte con la espalda en la pared.",
			"She knocks back and stuns everyone close: stand with your back to a wall.", rol = "tanque" },
		{ "Si peleas de lejos, quédate lejos de ella.",
			"Ranged players, stay away from her." },
	},
	[7023] = { -- Obsidian Sentinel
		{ "Al recibir daño suelta pedazos más pequeños: mátenlos con ataques en área.",
			"As it takes damage it breaks off smaller shards: kill them with area attacks.", rol = "dano" },
	},
	[7206] = { -- Ancient Stone Keeper
		{ "Lanza tormentas de arena que se mueven por la sala: no te pares en ellas.",
			"He creates sandstorms that move around the room: don't stand in them." },
	},
	[7291] = { -- Galgann Firehammer
		{ "Lanza fuego a su alrededor: si peleas de lejos, aléjate de él.",
			"He sends out fire around him: ranged players, stay away from him." },
	},
	[4854] = { -- Grimlok
		{ "Se acelera a sí mismo y lanza rayos: interrúmpelo.",
			"He speeds himself up and casts lightning: interrupt him." },
	},
	[2748] = { -- Archaedas
		{ "Durante la pelea despierta a guardianes de piedra: alguien debe tanquearlos o mátenlos rápido.",
			"During the fight he wakes stone guardians: someone tanks them or kill them fast." },
		{ "Al empezar aturde a quien lo despertó en el altar: es normal.",
			"At the start he stuns whoever woke him at the altar: that's normal." },
	},
}
