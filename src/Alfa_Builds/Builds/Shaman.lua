-- Alfa - Builds del chamán (toxic3000 / La Jauría). GPL-3.0.
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
	clase = "SHAMAN",
	nombre = L["Chamán"],
	especialidades = {
		elemental = { nombre = L["Elemental"], indice = 1, icono = 16166, rol = "dps" },
		enhancement = { nombre = L["Mejora"], indice = 2, icono = 425336, rol = "dps" },
		restoration = { nombre = L["Restauración"], indice = 3, icono = 408521, rol = "sanador" },
	},
	recomendados = { solo = "enhancement-solo-equilibrado" },
	builds = {
		{
			id = "elemental-solo-equilibrado", spec = "elemental", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Elemental para subir"],
			resumen = L["Rayos y fuego desde lejos: mucho daño de golpe."],
			fuente = "motor",
			talentos = {
				{ 16035, 5, "Concussion" },
				{ 16038, 3, "Call of Flame" },
				{ 16040, 2, "Reverberation" },
				{ 16164, 1, "Elemental Focus" },
				{ 16578, 3, "Elemental Alacrity" },
				{ 16040, 5 },
				{ 29062, 3, "Eye of the Storm" },
				{ 408490, 1, "Lava Burst" },
				{ 408438, 3, "Lightning Overload" },
				{ 28999, 1, "Elemental Reach" },
				{ 16089, 5, "Elemental Fury" },
				{ 16166, 1, "Elemental Mastery" },
				{ 17485, 5, "Ancestral Knowledge" },
				{ 16255, 5, "Thundering Strikes" },
				{ 16261, 3, "Improved Lightning Shield" },
				{ 1223030, 1, "Shamanistic Focus" },
				{ 16258, 2, "Guardian Totems" },
				{ 16262, 2, "Improved Ghost Wolf" },
				{ 16043, 2, "Earth's Grasp" },
			},
			stats = { "sp", "int", "spellCrit", "spellHit", "mp5" },
			consejos = {
				L["Lanza tu hechizo más fuerte primero y remata con un choque."],
				L["Pon un tótem antes de empezar la pelea."],
			},
		},
		{
			id = "enhancement-solo-equilibrado", spec = "enhancement", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Mejora para subir"],
			resumen = L["Cuerpo a cuerpo con tótems y golpes elementales: el chamán que mejor sube."],
			fuente = "motor",
			talentos = {
				{ 16255, 5, "Thundering Strikes" },
				{ 415140, 3, "Mental Dexterity" },
				{ 16262, 2, "Improved Ghost Wolf" },
				{ 16266, 3, "Elemental Weapons" },
				{ 1223030, 1, "Shamanistic Focus" },
				{ 16261, 1, "Improved Lightning Shield" },
				{ 16256, 5, "Flurry" },
				{ 17364, 1, "Stormstrike" },
				{ 30812, 2, "Mental Quickness" },
				{ 1223031, 2, "Improved Stormstrike" },
				{ 408498, 5, "Maelstrom Weapon" },
				{ 425336, 1, "Rage of the Farseer" },
				{ 16035, 5, "Concussion" },
				{ 16040, 5, "Reverberation" },
				{ 16164, 1, "Elemental Focus" },
				{ 16038, 3, "Call of Flame" },
				{ 30160, 3, "Elemental Devastation" },
				{ 16578, 3, "Elemental Alacrity" },
			},
			stats = { "str", "dps", "crit", "hit", "agi", "int" },
			consejos = {
				L["Usa un arma lenta y fuerte: tus mejoras de arma pegan con cada golpe."],
				L["Pon tus tótems al empezar cada pelea grande."],
			},
		},
		{
			id = "restoration-solo-equilibrado", spec = "restoration", objetivo = "solo", estilo = "equilibrado", armas = "escudo",
			titulo = L["Restauración para subir"],
			resumen = L["El sanador de los chamanes: curas en cadena y tótems que ayudan a todo el grupo."],
			fuente = "motor",
			talentos = {
				{ 16179, 5, "Tidal Focus" },
				{ 16173, 5, "Totemic Focus" },
				{ 408510, 1, "Water Shield" },
				{ 1223033, 3, "Mindfulness" },
				{ 16181, 1, "Healing Focus" },
				{ 16187, 5, "Restorative Totems" },
				{ 16188, 1, "Nature's Swiftness" },
				{ 29206, 3, "Healing Way" },
				{ 16190, 1, "Mana Tide Totem" },
				{ 16178, 5, "Purification" },
				{ 408521, 1, "Riptide" },
				{ 16035, 5, "Concussion" },
				{ 16039, 5, "Convection" },
				{ 16038, 3, "Call of Flame" },
				{ 16164, 1, "Elemental Focus" },
				{ 16578, 3, "Elemental Alacrity" },
				{ 16040, 3, "Reverberation" },
			},
			stats = { "heal", "int", "mp5", "spellCrit", "sta" },
			consejos = {
				L["En grupo, deja tus tótems de maná y de curas cerca del grupo."],
				L["En solitario, pelea con choques y cúrate entre monstruos."],
			},
		},
	},
})
