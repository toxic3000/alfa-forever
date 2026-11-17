-- Alfa - Mazmorras: consejos por jefe para principiantes (toxic3000 / La Jauría). GPL-3.0.
-- Cavernas de Brazanegra (blackfathom-deeps). Formato en LEEME.md.
local _, M = ...
M.Consejos = M.Consejos or {}

M.Consejos["blackfathom-deeps"] = {
	general = {
		{ "Hay mucha agua: si nadas bajo el agua, mira tu barra de respiración y sube a tomar aire.",
			"There is a lot of water: when swimming under water, watch your breath bar and come up for air." },
		{ "Los nagas y sátiros lanzan escarcha y rayos: interrumpan a los lanzadores primero.",
			"Nagas and satyrs cast frost and lightning: interrupt the casters first." },
	},
	[4887] = { -- Ghamoo-ra
		{ "Es una tortuga gigante con mucha armadura: pega lento pero duro.",
			"A giant, heavily armored turtle: slow but hard hits." },
		{ "Puede pisotear a los que pelean cuerpo a cuerpo: mantén su vida alta.",
			"He can trample melee players: keep their health high.", rol = "cura" },
	},
	[4831] = { -- Lady Sarevess
		{ "Congela en el lugar y lanza rayos: si peleas de lejos, sepárate del grupo.",
			"She roots players in place and casts lightning: ranged players, spread out." },
		{ "Llega con ayudantes naga: mátenlos primero.",
			"She comes with naga helpers: kill them first.", rol = "dano" },
	},
	[6243] = { -- Gelihast
		{ "Lanza una red que deja quieto a un jugador: no es grave, sigue atacando.",
			"He throws a net that holds a player in place: not a problem, keep attacking." },
		{ "Está rodeado de múrlocs: tiren a sus amigos antes que a él.",
			"Murlocs surround him: pull his friends before him." },
	},
	[12902] = { -- Lorgus Jett
		{ "Es un chamán con tótems: rompan los tótems, son fáciles de matar.",
			"A shaman with totems: break the totems, they die quickly." },
		{ "Lo acompañan otros lanzadores: interrúmpanlos.",
			"Other casters come with him: interrupt them." },
	},
	[4830] = { -- Old Serra'kis
		{ "Se pelea bajo el agua: vigila tu barra de respiración y sube a tomar aire si hace falta.",
			"You fight him under water: watch your breath bar and come up for air if needed." },
	},
	[4832] = { -- Twilight Lord Kelris
		{ "Duerme a un jugador y lanza sombras: interrúmpelo.",
			"He puts a player to sleep and casts shadow spells: interrupt him." },
		{ "Después de él se encienden los braseros del altar y llegan oleadas de enemigos: prepárense antes.",
			"After him, lighting the altar braziers brings waves of enemies: get ready first." },
	},
	[4829] = { -- Aku'mai
		{ "Lanza una nube de veneno hacia adelante: gíralo lejos del grupo.",
			"She breathes a poison cloud in front of her: turn her away from the group.", rol = "tanque" },
		{ "Al final se enfurece: guarden su mejor daño para el final.",
			"She enrages at the end: save your best damage for the end." },
	},
	[12876] = { -- Baron Aquanis
		{ "Aparece con una misión de la Horda (un objeto en el agua). Lanza escarcha.",
			"Appears with a Horde quest (an object in the water). He casts frost spells." },
	},
}
