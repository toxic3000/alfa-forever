-- Alfa - Builds del mago (toxic3000 / La Jauría). GPL-3.0.
--
-- Un build "Subir solo / Equilibrado" por rama. El orden de talentos sale de
-- los planes de nivelación de Polestar (talents/forever, GPL-3.0, The Polestar
-- authors; ver CREDITOS.md y LICENSE-Polestar.txt), convertido al formato de
-- Alfa: { spellID, rango hasta el que se sube, nombre en inglés }. Los textos
-- en español son de Alfa. Archivo generado: se rehace con la herramienta de
-- datos de Alfa a partir de Alfa/Talents/Builds.lua.

local ADDON, M = ...
local L = M.L

M.Clase({
	clase = "MAGE",
	nombre = L["Mago"],
	especialidades = {
		arcane = { nombre = L["Arcano"], indice = 1, icono = 12042, rol = "dps" },
		fire = { nombre = L["Fuego"], indice = 2, icono = 11129, rol = "dps" },
		frost = { nombre = L["Escarcha"], indice = 3, icono = 11426, rol = "dps" },
	},
	recomendados = { solo = "frost-solo-equilibrado" },
	builds = {
		{
			id = "arcane-solo-equilibrado", spec = "arcane", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Arcano para subir"],
			resumen = L["Mucho maná y hechizos arcanos potentes: el mago que menos descansa."],
			fuente = "motor",
			talentos = {
				{ 11237, 5, "Improved Channeling" },
				{ 11213, 5, "Arcane Concentration" },
				{ 400574, 1, "Arcane Blast" },
				{ 11242, 3, "Arcane Impact" },
				{ 400588, 1, "Missile Barrage" },
				{ 18462, 3, "Arcane Meditation" },
				{ 1326079, 1, "Arcane Wrath" },
				{ 11210, 1, "Arcane Subtlety" },
				{ 400588, 2 },
				{ 12043, 1, "Presence of Mind" },
				{ 11232, 5, "Arcane Mind" },
				{ 15058, 3, "Arcane Instability" },
				{ 11210, 2 },
				{ 12042, 1, "Arcane Power" },
				{ 11070, 5, "Improved Frostbolt" },
				{ 11165, 2, "Improved Frost Nova" },
				{ 11175, 3, "Permafrost" },
				{ 11160, 3, "Frost Channeling" },
				{ 11151, 3, "Piercing Ice" },
				{ 11958, 1, "Ice Block" },
				{ 16757, 1, "Arctic Reach" },
				{ 1312002, 1, "Ice Lance" },
			},
			stats = { "sp", "int", "spellHit", "spellCrit", "spi", "sta" },
			consejos = {
				L["Bebe cuando te quede poco maná, no esperes a vaciarte."],
				L["Usa tus hechizos de control si se te juntan dos monstruos."],
			},
		},
		{
			id = "fire-solo-equilibrado", spec = "fire", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Fuego para subir"],
			resumen = L["El mago que más daño hace: hechizos de fuego y críticos que queman."],
			fuente = "motor",
			talentos = {
				{ 11069, 5, "Improved Fireball" },
				{ 11119, 5, "Ignite" },
				{ 11366, 1, "Pyroblast" },
				{ 18459, 3, "Incineration" },
				{ 11103, 1, "Impact" },
				{ 29074, 3, "Master of Elements" },
				{ 400624, 1, "Heating Up" },
				{ 11103, 2 },
				{ 11115, 3, "Critical Mass" },
				{ 11113, 1, "Blast Wave" },
				{ 11103, 3 },
				{ 11115, 5 },
				{ 11124, 3, "Fire Power" },
				{ 11129, 1, "Combustion" },
				{ 6057, 2, "Wand Specialization" },
				{ 11222, 3, "Arcane Focus" },
				{ 11213, 5, "Arcane Concentration" },
				{ 11210, 2, "Arcane Subtlety" },
				{ 28574, 2, "Arcane Resilience" },
				{ 29441, 1, "Magic Absorption" },
				{ 18462, 3, "Arcane Meditation" },
				{ 29441, 2 },
				{ 11252, 1, "Arcane Shielding" },
			},
			stats = { "sp", "spellCrit", "spellHit", "int", "sta" },
			consejos = {
				L["Empieza con tu hechizo más lento desde lejos y termina con los instantáneos."],
				L["Cuidado con atraer varios a la vez: Fuego no tiene tanto control."],
			},
		},
		{
			id = "frost-solo-equilibrado", spec = "frost", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Escarcha para subir"],
			resumen = L["Congelas y frenas a los monstruos para que nunca te alcancen: el mago más seguro para subir."],
			fuente = "motor",
			talentos = {
				{ 11070, 5, "Improved Frostbolt" },
				{ 11207, 5, "Ice Shards" },
				{ 11151, 3, "Piercing Ice" },
				{ 11165, 2, "Improved Frost Nova" },
				{ 11958, 1, "Ice Block" },
				{ 11170, 3, "Shatter" },
				{ 11175, 1, "Permafrost" },
				{ 12472, 1, "Cold Snap" },
				{ 11160, 3, "Frost Channeling" },
				{ 1312002, 1, "Ice Lance" },
				{ 11180, 5, "Winter's Chill" },
				{ 11426, 1, "Ice Barrier" },
				{ 6057, 2, "Wand Specialization" },
				{ 11222, 3, "Arcane Focus" },
				{ 11213, 5, "Arcane Concentration" },
				{ 11210, 2, "Arcane Subtlety" },
				{ 28574, 2, "Arcane Resilience" },
				{ 29441, 1, "Magic Absorption" },
				{ 18462, 3, "Arcane Meditation" },
				{ 29441, 2 },
				{ 11252, 1, "Arcane Shielding" },
			},
			stats = { "sp", "int", "spellHit", "sta", "spi" },
			consejos = {
				L["Congela al monstruo con Nova de escarcha y aléjate antes de seguir lanzando."],
				L["Tus hechizos de escarcha frenan: el monstruo casi nunca llega a pegarte."],
			},
		},
	},
})
