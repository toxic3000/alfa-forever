-- Alfa - Mazmorras: consejos por jefe para principiantes (toxic3000 / La Jauría). GPL-3.0.
-- Castillo de Colmillo Oscuro (shadowfang-keep). Formato en LEEME.md.
local _, M = ...
M.Consejos = M.Consejos or {}

M.Consejos["shadowfang-keep"] = {
	general = {
		{ "Hay enemigos que se convierten en lobos y otros que asustan: no corran si los asustan, esperen.",
			"Some enemies turn into wolves and others cause fear: don't panic when feared, wait it out." },
		{ "Después del primer jefe, un prisionero de tu facción abre la puerta: háblale.",
			"After the first boss a prisoner of your faction opens the door: talk to him." },
	},
	[3914] = { -- Rethilgore
		{ "Es el primer jefe y es sencillo. Al morir, el prisionero de tu facción abre la puerta del patio.",
			"The first boss and an easy one. When he dies, your faction's prisoner opens the courtyard door." },
	},
	[3886] = { -- Razorclaw the Butcher
		{ "Golpea fuerte con su cuchilla y hace sangrar: vigila la vida del tanque.",
			"He hits hard with his cleaver and causes bleeding: watch the tank's health.", rol = "cura" },
	},
	[3887] = { -- Baron Silverlaine
		{ "Pone una maldición que baja la curación que recibes: quítala si tu clase puede.",
			"He casts a curse that lowers the healing you receive: remove it if your class can." },
		{ "Mientras tenga la maldición, cura antes de que la vida baje mucho.",
			"While the curse is up, heal early, before health gets low.", rol = "cura" },
	},
	[4278] = { -- Commander Springvale
		{ "Es un paladín: se cura con luz sagrada. Interrumpe su curación.",
			"He is a paladin who heals himself with holy light. Interrupt his heal." },
		{ "Aturde al tanque con su martillo: mantén la vida del tanque alta.",
			"He stuns the tank with his hammer: keep the tank's health high.", rol = "cura" },
	},
	[4279] = { -- Odo the Blindwatcher
		{ "Se enfurece y pega más fuerte con el tiempo: mátenlo rápido.",
			"He gets angrier and hits harder over time: kill him quickly." },
		{ "Llega con lobos: elimínenlos primero.",
			"He comes with wolves: kill them first.", rol = "dano" },
	},
	[4274] = { -- Fenrus the Devourer
		{ "Su mordida envenena: quita el veneno si puedes.",
			"His bite is poisonous: remove the poison if you can." },
		{ "Al morir aparecen cuatro abisarios que caminan juntos por el patio: prepárense para pelear con varios.",
			"When he dies, four voidwalkers appear and walk through the courtyard together: get ready for several." },
	},
	[3927] = { -- Wolf Master Nandos
		{ "Llama a varios lobos al empezar: usen ataques en área o maten primero a los lobos.",
			"He calls several wolves at the start: use area attacks or kill the wolves first." },
	},
	[4275] = { -- Archmage Arugal
		{ "Se teletransporta a las orillas de la sala: si peleas cuerpo a cuerpo, síguelo.",
			"He teleports to the edges of the room: melee players, follow him." },
		{ "Puede convertir a alguien en huargo: no ataquen a ese jugador, se le pasa solo.",
			"He can turn a player into a worgen: don't attack that player, it wears off." },
		{ "Sus bolas de sombra pegan mucho: interrúmpelo.",
			"His shadow bolts hit hard: interrupt him." },
	},
	[3872] = { -- Deathsworn Captain
		{ "Es raro y no siempre está. Golpea fuerte a todos los que tiene enfrente.",
			"A rare spawn, not always there. He hits everyone in front of him hard." },
	},
}
