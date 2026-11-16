-- Alfa - Mazmorras: consejos por jefe para principiantes (Toxic / La Jauría). GPL-3.0.
-- Sima Ígnea (ragefire-chasm). Formato (también en LEEME.md):
--   [id de PNJ del jefe] = { { "español", "English", rol = "tanque"|"cura"|"dano" }, ... }
--   e<id de encuentro> = ... para un grupo sin PNJ propio; general = la mazmorra entera.
local _, M = ...
M.Consejos = M.Consejos or {}

M.Consejos["ragefire-chasm"] = {
	general = {
		{ "Es la primera mazmorra de la Horda: corta y buena para aprender a jugar en grupo.",
			"The Horde's first dungeon: short and a good place to learn group play." },
		{ "Hay muchos troggs y elementales de fuego juntos: tiren de uno o dos grupos a la vez, no más.",
			"Troggs and fire elementals stand close together: pull one or two packs at a time, no more." },
	},
	[11517] = { -- Oggleflint
		{ "Golpea a todos los que tiene enfrente: ataca desde su espalda si peleas cuerpo a cuerpo.",
			"He hits everyone in front of him: attack from behind if you fight in melee." },
		{ "Ponlo de espaldas al grupo para que su golpe solo te dé a ti.",
			"Turn him away from the group so his swing only hits you.", rol = "tanque" },
	},
	[11520] = { -- Taragaman the Hungerer
		{ "Suelta una ola de fuego a su alrededor: si peleas de lejos, quédate lejos de él.",
			"He sends out a ring of fire around him: ranged players, stay away from him." },
		{ "Puede lanzarte por los aires con un gancho: regresa rápido para que no vaya tras quien cura.",
			"His uppercut throws you back: run back fast so he doesn't go after the healer.", rol = "tanque" },
		{ "El fuego pega a todos los de cerca: mantén la vida alta de quienes pelean cuerpo a cuerpo.",
			"The fire hits everyone close by: keep the melee players' health high.", rol = "cura" },
	},
	[11518] = { -- Jergosh the Invoker
		{ "Es un brujo que lanza hechizos: interrúmpelo si tu clase puede (Patada, Golpe de escudo, Choque de tierra...).",
			"He is a caster: interrupt him if your class can (Kick, Shield Bash, Earth Shock...)." },
		{ "Pone una maldición que te debilita y un fuego que quema poco a poco: quita la maldición si puedes.",
			"He casts a weakening curse and a burning spell: remove the curse if you can.", rol = "cura" },
	},
	[11519] = { -- Bazzalan
		{ "Es un sátiro rápido que envenena: si tu clase quita venenos, úsalo.",
			"A quick satyr who poisons: if your class removes poisons, use it." },
		{ "Pega muchas veces seguidas al tanque: no dejes que su vida baje de la mitad.",
			"He hits the tank many times in a row: don't let the tank drop below half health.", rol = "cura" },
	},
}
