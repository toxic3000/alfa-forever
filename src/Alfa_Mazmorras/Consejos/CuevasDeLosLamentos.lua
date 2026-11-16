-- Alfa - Mazmorras: consejos por jefe para principiantes (Toxic / La Jauría). GPL-3.0.
-- Cuevas de los Lamentos (wailing-caverns). Formato en LEEME.md.
local _, M = ...
M.Consejos = M.Consejos or {}

M.Consejos["wailing-caverns"] = {
	general = {
		{ "Es grande y es fácil perderse: sigan a una sola persona y no corran solos.",
			"It is big and easy to get lost in: follow one person and don't run off alone." },
		{ "Muchos enemigos duermen a un jugador: no es grave, el sueño se quita solo.",
			"Many enemies put a player to sleep: it is harmless and wears off by itself." },
		{ "Al final, habla con el Discípulo de Naralex y protégelo mientras camina: así aparece el último jefe.",
			"At the end, talk to the Disciple of Naralex and protect him as he walks: that brings out the last boss." },
	},
	[3671] = { -- Lady Anacondra
		{ "Lanza rayos y se puede curar: interrumpe sus hechizos.",
			"She casts lightning and can heal herself: interrupt her spells." },
		{ "Puede dormir a alguien del grupo: sigue peleando, se despierta solo.",
			"She can put someone to sleep: keep fighting, they wake up on their own." },
	},
	[3669] = { -- Lord Cobrahn
		{ "Envenena y lanza rayos: quita el veneno si puedes.",
			"He poisons and casts lightning: remove the poison if you can." },
		{ "Con poca vida se convierte en serpiente y pega más fuerte: guarda tus mejores ataques para ese momento.",
			"At low health he turns into a serpent and hits harder: save your best attacks for then." },
	},
	[3653] = { -- Kresh
		{ "Es una tortuga muy dura, pero solo golpea: no tiene trucos.",
			"A very tough turtle, but he only hits: no tricks." },
		{ "Camina por el agua: espérenlo en tierra y atráiganlo con un ataque a distancia.",
			"He walks through the water: wait on dry land and pull him with a ranged attack." },
	},
	[3670] = { -- Lord Pythas
		{ "Se cura a sí mismo: interrumpe su curación.",
			"He heals himself: interrupt his heal." },
		{ "Puede dormir a alguien y golpear a todos los que están cerca.",
			"He can put someone to sleep and hit everyone close to him." },
	},
	[3674] = { -- Skum
		{ "Su rayo salta de un jugador a otro: no se queden todos juntos.",
			"His lightning jumps from one player to the next: don't all stand together." },
		{ "Está en el agua, junto a la cascada: llévenlo a tierra antes de pelear.",
			"He is in the water by the waterfall: bring him to dry land before fighting." },
	},
	[3673] = { -- Lord Serpentis
		{ "Igual que los otros señores: lanza rayos y se cura. Interrumpe su curación.",
			"Like the other lords: he casts lightning and heals. Interrupt his heal." },
		{ "Limpien a sus ayudantes antes de empezar con él.",
			"Clear his helpers before you start on him." },
	},
	[5775] = { -- Verdan the Everliving
		{ "Lanza enredaderas que tumban a todos los que están cerca: si peleas de lejos, quédate lejos.",
			"He casts vines that knock down everyone near him: ranged players, stay back." },
		{ "Pega muy fuerte: empieza la pelea con la vida llena.",
			"He hits very hard: start the fight at full health.", rol = "tanque" },
	},
	[3654] = { -- Mutanus the Devourer
		{ "Aparece al final del evento del Discípulo de Naralex: protege al druida mientras camina.",
			"He appears at the end of the Disciple of Naralex event: protect the druid as he walks." },
		{ "Asusta y duerme a los jugadores: si te asusta, intenta no correr hacia más enemigos.",
			"He fears and sleeps players: if you are feared, try not to run into more enemies." },
	},
	[5912] = { -- Deviate Faerie Dragon
		{ "Es raro: no siempre está. Duerme a los jugadores y explota con magia a su alrededor.",
			"A rare spawn: not always there. He sleeps players and explodes with magic around him." },
	},
}
