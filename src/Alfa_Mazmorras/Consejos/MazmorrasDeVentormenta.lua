-- Alfa - Mazmorras: consejos por jefe para principiantes (toxic3000 / La Jauría). GPL-3.0.
-- Mazmorras de Ventormenta (stormwind-stockade). Formato en LEEME.md.
local _, M = ...
M.Consejos = M.Consejos or {}

M.Consejos["stormwind-stockade"] = {
	general = {
		{ "Es corta y está dentro de Ventormenta. Los presos están en celdas a los lados: avancen despacio.",
			"Short, and inside Stormwind. Prisoners stand in cells on both sides: move slowly." },
		{ "Si alguien huye, puede traer a más presos: deténganlo con un ataque que lo frene.",
			"A fleeing enemy can bring more prisoners: stop it with a snare." },
	},
	[1696] = { -- Targorr the Dread
		{ "Al final de la pelea se enfurece y pega más rápido: guarda curación para ese momento.",
			"Near the end he enrages and hits faster: save some healing for then.", rol = "cura" },
	},
	[1666] = { -- Kam Deepfury
		{ "Es un enano con escudo: aguanta mucho pero no tiene trucos.",
			"A dwarf with a shield: tough, but no tricks." },
	},
	[1717] = { -- Hamhock
		{ "Su rayo salta de un jugador a otro: sepárense un poco.",
			"His lightning jumps between players: spread out a little." },
		{ "Se acelera a sí mismo: interrúmpelo si puedes.",
			"He speeds himself up: interrupt him if you can." },
	},
	[1663] = { -- Dextren Ward
		{ "Asusta a todos los que están cerca: si te asusta, intenta no correr hacia otras celdas.",
			"He fears everyone nearby: if feared, try not to run into other cells." },
	},
	[1716] = { -- Bazil Thredd
		{ "Lanza bombas de humo que aturden: sal del humo.",
			"He throws smoke bombs that stun: get out of the smoke." },
		{ "Es el jefe que pide una misión de la Alianza: revisa tus misiones antes de entrar.",
			"An Alliance quest asks for him: check your quests before going in." },
	},
	[1720] = { -- Bruegal Ironknuckle
		{ "Es raro y no siempre aparece. Pega muy fuerte para su nivel: tírenlo con cuidado.",
			"A rare spawn. He hits very hard for his level: pull him carefully." },
	},
}
