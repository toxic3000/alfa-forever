-- Alfa - Builds del druida (Toxic / La Jauría). GPL-3.0.
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
	clase = "DRUID",
	nombre = L["Druida"],
	especialidades = {
		balance = { nombre = L["Equilibrio"], indice = 1, icono = 24858, rol = "dps" },
		feral = { nombre = L["Combate feral"], indice = 2, icono = 417141, rol = "dps" },
		restoration = { nombre = L["Restauración"], indice = 3, icono = 408120, rol = "sanador" },
	},
	recomendados = { solo = "feral-solo-equilibrado" },
	builds = {
		{
			id = "balance-solo-equilibrado", spec = "balance", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Equilibrio para subir"],
			resumen = L["Hechizos desde lejos y raíces para que el monstruo no te alcance. Al final llega la forma de lechúcico."],
			fuente = "motor",
			talentos = {
				{ 16814, 5, "Improved Wrath" },
				{ 16845, 3, "Moonglow" },
				{ 1223082, 2, "Nature's Majesty" },
				{ 1223083, 1, "Nature's Splendor" },
				{ 16918, 3, "Improved Entangling Roots" },
				{ 16819, 2, "Nature's Reach" },
				{ 5570, 1, "Insect Swarm" },
				{ 16850, 3, "Improved Starfire" },
				{ 16880, 1, "Nature's Grace" },
				{ 16821, 2, "Improved Moonfire" },
				{ 16909, 2, "Vengeance" },
				{ 16896, 5, "Moonfury" },
				{ 24858, 1, "Moonkin Form" },
				{ 17063, 5, "Nature's Focus" },
				{ 17069, 5, "Naturalist" },
				{ 17106, 3, "Reflection" },
				{ 17104, 5, "Gift of Nature" },
				{ 414673, 1, "Gift of the Earthmother" },
				{ 16833, 1, "Natural Shapeshifter" },
			},
			stats = { "sp", "int", "spellCrit", "spellHit", "spi", "sta" },
			consejos = {
				L["Enraíza al monstruo y aléjate antes de lanzar tus hechizos largos."],
				L["Cuando te quedes sin maná, cambia a forma felina para terminar la pelea."],
			},
		},
		{
			id = "feral-solo-equilibrado", spec = "feral", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Combate feral para subir"],
			resumen = L["Forma felina para matar rápido y forma de oso para las peleas difíciles; casi nunca necesitas beber."],
			fuente = "motor",
			talentos = {
				{ 16934, 5, "Ferocity" },
				{ 17003, 5, "Heart of the Wild" },
				{ 16998, 2, "Savage Fury" },
				{ 16942, 2, "Sharpened Claws" },
				{ 17002, 2, "Feral Swiftness" },
				{ 16972, 3, "Predatory Strikes" },
				{ 16958, 1, "Blood Frenzy" },
				{ 1223242, 1, "Natural Instinct" },
				{ 16958, 2 },
				{ 17007, 1, "Leader of the Pack" },
				{ 1223242, 2 },
				{ 16966, 1, "Shredding Attacks" },
				{ 1223246, 5, "Rend and Tear" },
				{ 417141, 1, "Berserk" },
				{ 17056, 5, "Furor" },
				{ 17069, 5, "Naturalist" },
				{ 16833, 3, "Natural Shapeshifter" },
				{ 17106, 3, "Reflection" },
				{ 414673, 1, "Gift of the Earthmother" },
				{ 17104, 3, "Gift of Nature" },
			},
			stats = { "str", "agi", "crit", "hit", "sta", "armor" },
			consejos = {
				L["Usa la forma felina con un monstruo y la de oso si vienen varios."],
				L["Cambiar de forma te quita lentitudes y raíces: úsalo para escapar."],
			},
		},
		{
			id = "restoration-solo-equilibrado", spec = "restoration", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Restauración para subir"],
			resumen = L["El sanador de los druidas: curas a cualquier grupo y sobrevives bien, aunque en solitario matas lento."],
			fuente = "motor",
			talentos = {
				{ 17063, 5, "Nature's Focus" },
				{ 17069, 5, "Naturalist" },
				{ 17106, 3, "Reflection" },
				{ 414673, 1, "Gift of the Earthmother" },
				{ 17118, 1, "Subtlety" },
				{ 17111, 3, "Improved Rejuvenation" },
				{ 18562, 1, "Swiftmend" },
				{ 17118, 2 },
				{ 17116, 1, "Nature's Swiftness" },
				{ 1309631, 3, "Living Spirit" },
				{ 24968, 1, "Tranquil Spirit" },
				{ 17074, 5, "Improved Regrowth" },
				{ 408120, 1, "Wild Growth" },
				{ 16814, 5, "Improved Wrath" },
				{ 16845, 3, "Moonglow" },
				{ 1223082, 2, "Nature's Majesty" },
				{ 1223083, 1, "Nature's Splendor" },
				{ 16918, 3, "Improved Entangling Roots" },
				{ 1223081, 5, "Genesis" },
				{ 5570, 1, "Insect Swarm" },
			},
			stats = { "heal", "int", "spi", "mp5", "sta" },
			consejos = {
				L["En solitario, deja curas que duran en el tiempo y pelea con Cólera."],
				L["En grupo, cura antes de que la vida baje mucho: es más barato."],
			},
		},
	},
})
