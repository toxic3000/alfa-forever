-- Alfa - Mazmorras: consejos por jefe para principiantes (toxic3000 / La Jauría). GPL-3.0.
-- Minas de la Muerte (deadmines). Formato en LEEME.md.
local _, M = ...
M.Consejos = M.Consejos or {}

M.Consejos["deadmines"] = {
	general = {
		{ "Es la primera mazmorra grande de la Alianza: avancen despacio y tiren un grupo a la vez.",
			"The Alliance's first big dungeon: go slowly and pull one pack at a time." },
		{ "En la cueva del barco hay muchos piratas: no bajen todos de golpe al muelle.",
			"The ship cave is full of pirates: don't all jump down to the dock at once." },
		{ "Los goblins de la fundición tienen ayudantes cerca: miren alrededor antes de atacar.",
			"The goblins in the foundry have helpers nearby: look around before you attack." },
	},
	[644] = { -- Rhahk'Zor
		{ "Pega fuerte pero no tiene trucos: es un buen jefe para aprender.",
			"He hits hard but has no tricks: a good boss to learn on." },
		{ "Ponlo de espaldas al grupo y aguanta: la pelea es corta.",
			"Turn him away from the group and hold on: the fight is short.", rol = "tanque" },
	},
	[643] = { -- Sneed
		{ "Primero sale su trituradora; al romperla, Sneed baja y pelea a pie.",
			"First comes his shredder; when it breaks, Sneed jumps out and fights on foot." },
		{ "La trituradora tira a la gente: vuelve a llamar su atención rápido.",
			"The shredder knocks people around: get its attention back fast.", rol = "tanque" },
	},
	[642] = { -- Sneed's Shredder
		{ "Es la máquina de Sneed: rómpela y él saldrá a pelear.",
			"Sneed's machine: break it and he comes out to fight." },
	},
	[3586] = { -- Miner Johnson
		{ "No siempre aparece en la mina: si lo ves, es un jefe más con buen botín.",
			"He does not always show up in the mine: if you see him, he is an extra boss with good loot." },
		{ "Hace heridas que sangran: vigila la vida del tanque.",
			"He causes bleeding wounds: watch the tank's health.", rol = "cura" },
	},
	[1763] = { -- Gilnid
		{ "Está rodeado de goblins que trabajan: tiren a esos goblins primero, de uno en uno.",
			"Working goblins stand around him: pull them first, one at a time." },
		{ "Lanza metal fundido: si no tanqueas, no te quedes pegado a él.",
			"He throws molten metal: if you're not the tank, don't stand next to him." },
	},
	[647] = { -- Captain Greenskin
		{ "Golpea a todos los que tiene enfrente: si peleas cuerpo a cuerpo, ataca por detrás.",
			"He hits everyone in front of him: melee, attack from behind." },
		{ "Su arpón envenena: quita el veneno si puedes.",
			"His harpoon poisons: remove the poison if you can.", rol = "cura" },
	},
	[646] = { -- Mr. Smite
		{ "Cuando le baja la vida aturde a todos y corre a su cofre a cambiar de arma: espérenlo, no lo persigan.",
			"As his health drops he stuns everyone and runs to his chest to switch weapons: wait, don't chase him." },
		{ "Con dos armas pega más rápido: guarda maná para el final.",
			"With two weapons he hits faster: save mana for the end.", rol = "cura" },
	},
	[645] = { -- Cookie
		{ "Se cura comiendo: mátenlo rápido.",
			"He heals himself by eating: kill him fast." },
		{ "Es sencillo: buen momento para beber agua antes del último jefe.",
			"An easy one: a good moment to drink before the last boss.", rol = "cura" },
	},
	[639] = { -- Edwin VanCleef
		{ "Con poca vida llama a dos ayudantes: si a él le queda poco, terminen con él; si no, maten a los ayudantes.",
			"At low health he calls two helpers: if he is almost dead, finish him; if not, kill the helpers." },
		{ "Pega varias veces seguidas: empieza con la vida llena.",
			"He strikes several times in a row: start at full health.", rol = "tanque" },
		{ "Suelta una carta que empieza una misión: revisa su botín.",
			"He drops a letter that starts a quest: check his loot." },
	},
	[1725] = { -- Defias Watchman
		{ "Es un enemigo fuerte de la mina: trátenlo como un jefe pequeño.",
			"A strong enemy in the mine: treat him like a small boss." },
	},
}
