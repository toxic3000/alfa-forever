-- Alfa - Builds del brujo (toxic3000 / La Jauría). GPL-3.0.
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
	clase = "WARLOCK",
	nombre = L["Brujo"],
	especialidades = {
		affliction = { nombre = L["Aflicción"], indice = 1, icono = 1316697, rol = "dps" },
		demonology = { nombre = L["Demonología"], indice = 2, icono = 425464, rol = "dps" },
		destruction = { nombre = L["Destrucción"], indice = 3, icono = 412758, rol = "dps" },
	},
	recomendados = { solo = "affliction-solo-equilibrado" },
	builds = {
		{
			id = "affliction-solo-equilibrado", spec = "affliction", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Aflicción para subir"],
			resumen = L["Maldiciones y daño con el tiempo: pones tus hechizos y el monstruo muere solo mientras pasas al siguiente."],
			fuente = "motor",
			talentos = {
				{ 17810, 5, "Improved Corruption" },
				{ 18182, 2, "Improved Life Tap" },
				{ 403511, 3, "Improved Drains" },
				{ 437032, 2, "Soul Harvest" },
				{ 18827, 2, "Improved Bane of Agony" },
				{ 18288, 1, "Amplify Curse" },
				{ 18094, 2, "Nightfall" },
				{ 17783, 3, "Fel Concentration" },
				{ 18265, 1, "Siphon Life" },
				{ 17804, 3, "Soul Siphon" },
				{ 18223, 1, "Curse of Exhaustion" },
				{ 18271, 5, "Shadow Mastery" },
				{ 1316697, 1, "Wrack" },
				{ 18697, 5, "Demonic Embrace" },
				{ 18705, 3, "Improved Voidwalker" },
				{ 18703, 2, "Improved Health Funnel" },
				{ 18788, 1, "Demonic Sacrifice" },
				{ 18709, 2, "Master Summoner" },
				{ 18731, 3, "Fel Vitality" },
				{ 18708, 1, "Fel Domination" },
				{ 1235316, 2, "Demonic Aegis" },
				{ 18769, 1, "Unholy Power" },
			},
			stats = { "sp", "sta", "int", "spi", "spellHit" },
			consejos = {
				L["Pon todos tus hechizos de daño en el tiempo y deja que tu demonio aguante."],
				L["Usa Transfusión de vida para recuperar maná a cambio de vida."],
			},
		},
		{
			id = "demonology-solo-equilibrado", spec = "demonology", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Demonología para subir"],
			resumen = L["Tu demonio es más fuerte y tú más resistente: el brujo más seguro."],
			fuente = "motor",
			talentos = {
				{ 18697, 5, "Demonic Embrace" },
				{ 18705, 3, "Improved Voidwalker" },
				{ 1235316, 2, "Demonic Aegis" },
				{ 18788, 1, "Demonic Sacrifice" },
				{ 18731, 3, "Fel Vitality" },
				{ 18703, 1, "Improved Health Funnel" },
				{ 18709, 2, "Master Summoner" },
				{ 18708, 1, "Fel Domination" },
				{ 1225214, 2, "Demonic Energies" },
				{ 19028, 1, "Soul Link" },
				{ 412732, 3, "Demonic Knowledge" },
				{ 1225217, 1, "Improved Felhunter" },
				{ 23785, 5, "Master Demonologist" },
				{ 425464, 1, "Demonic Pact" },
				{ 17810, 5, "Improved Corruption" },
				{ 403511, 3, "Improved Drains" },
				{ 18182, 2, "Improved Life Tap" },
				{ 437032, 2, "Soul Harvest" },
				{ 18827, 2, "Improved Bane of Agony" },
				{ 18288, 1, "Amplify Curse" },
				{ 18094, 2, "Nightfall" },
				{ 17783, 3, "Fel Concentration" },
			},
			stats = { "sta", "sp", "int", "spi" },
			consejos = {
				L["Tu abisario aguanta los golpes por ti: deja que empiece la pelea."],
				L["El aguante es tu mejor amigo: más vida para más Transfusión de vida."],
			},
		},
		{
			id = "destruction-solo-equilibrado", spec = "destruction", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Destrucción para subir"],
			resumen = L["Daño directo de fuego y sombras: matas antes de que el monstruo llegue."],
			fuente = "motor",
			talentos = {
				{ 17788, 5, "Bane" },
				{ 17778, 3, "Cataclysm" },
				{ 1225220, 2, "Molten Skin" },
				{ 17877, 1, "Shadowburn" },
				{ 17959, 5, "Ruin" },
				{ 1293817, 1, "Conflagrate" },
				{ 18135, 3, "Intensity" },
				{ 1225228, 1, "Bane of Havoc" },
				{ 18073, 2, "Pyroclasm" },
				{ 412751, 3, "Fire and Brimstone" },
				{ 426316, 5, "Shadow and Flame" },
				{ 412758, 1, "Incinerate" },
				{ 17810, 5, "Improved Corruption" },
				{ 403511, 3, "Improved Drains" },
				{ 18182, 2, "Improved Life Tap" },
				{ 437032, 2, "Soul Harvest" },
				{ 18827, 2, "Improved Bane of Agony" },
				{ 18288, 1, "Amplify Curse" },
				{ 18094, 2, "Nightfall" },
				{ 17783, 2, "Fel Concentration" },
			},
			stats = { "sp", "spellCrit", "int", "spellHit", "sta" },
			consejos = {
				L["Lanza tu hechizo más fuerte desde lejos y remata con los instantáneos."],
				L["Usa a tu demonio para frenar al monstruo mientras lanzas."],
			},
		},
	},
})
