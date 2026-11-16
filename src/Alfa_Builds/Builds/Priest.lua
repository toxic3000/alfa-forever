-- Alfa - Builds del sacerdote (Toxic / La Jauría). GPL-3.0.
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
	clase = "PRIEST",
	nombre = L["Sacerdote"],
	especialidades = {
		discipline = { nombre = L["Disciplina"], indice = 1, icono = 10060, rol = "sanador" },
		holy = { nombre = L["Sagrado"], indice = 2, icono = 401859, rol = "sanador" },
		shadow = { nombre = L["Sombra"], indice = 3, icono = 15473, rol = "dps" },
	},
	recomendados = { solo = "shadow-solo-equilibrado" },
	builds = {
		{
			id = "discipline-solo-equilibrado", spec = "discipline", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Disciplina para subir"],
			resumen = L["Escudos y curas preventivas: aguantas mucho y apoyas al grupo."],
			fuente = "motor",
			talentos = {
				{ 1309969, 5, "Power in Light" },
				{ 1225132, 5, "Twin Disciplines" },
				{ 14748, 3, "Improved Power Word: Shield" },
				{ 14520, 3, "Mental Agility" },
				{ 402000, 1, "Soul Warding" },
				{ 14521, 3, "Meditation" },
				{ 402174, 1, "Penance" },
				{ 425280, 5, "Renewed Hope" },
				{ 431622, 3, "Divine Aegis" },
				{ 14751, 1, "Inner Focus" },
				{ 10060, 1, "Power Infusion" },
				{ 15270, 5, "Spirit Tap" },
				{ 15275, 2, "Improved Shadow Word: Pain" },
				{ 15260, 3, "Shadow Focus" },
				{ 15407, 1, "Mind Flay" },
				{ 1225139, 2, "Improved Mind Flay" },
				{ 15273, 5, "Improved Mind Blast" },
				{ 15326, 2, "Blackout" },
			},
			stats = { "heal", "int", "spi", "mp5", "sta" },
			consejos = {
				L["Ponte un escudo antes de empezar cada pelea."],
				L["Usa tu varita cuando quieras ahorrar maná."],
			},
		},
		{
			id = "holy-solo-equilibrado", spec = "holy", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Sagrado para subir"],
			resumen = L["El sanador puro: curas grandes y curas para todo el grupo."],
			fuente = "motor",
			talentos = {
				{ 14889, 5, "Holy Specialization" },
				{ 18530, 5, "Divine Fury" },
				{ 15237, 1, "Holy Nova" },
				{ 14892, 1, "Inspiration" },
				{ 14908, 3, "Improved Renew" },
				{ 14909, 2, "Searing Light" },
				{ 14912, 3, "Improved Healing" },
				{ 20711, 1, "Spirit of Redemption" },
				{ 401937, 1, "Binding Heal" },
				{ 14901, 5, "Spiritual Guidance" },
				{ 14898, 3, "Spiritual Healing" },
				{ 401859, 1, "Prayer of Mending" },
				{ 14524, 2, "Wand Specialization" },
				{ 1225132, 5, "Twin Disciplines" },
				{ 14531, 2, "Martyrdom" },
				{ 1309957, 1, "Holy Precision" },
				{ 14748, 3, "Improved Power Word: Shield" },
				{ 14521, 3, "Meditation" },
				{ 402000, 1, "Soul Warding" },
				{ 14751, 1, "Inner Focus" },
				{ 18551, 2, "Mental Strength" },
			},
			stats = { "heal", "int", "spi", "mp5", "spellCrit" },
			consejos = {
				L["En grupo, cura al tanque primero y no saques monstruos tú."],
				L["En solitario es lento: usa la varita para rematar."],
			},
		},
		{
			id = "shadow-solo-equilibrado", spec = "shadow", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Sombra para subir"],
			resumen = L["Hechizos de sombras que hacen daño con el tiempo: el sacerdote que mejor sube en solitario, casi sin descansar."],
			fuente = "motor",
			talentos = {
				{ 15270, 5, "Spirit Tap" },
				{ 15275, 2, "Improved Shadow Word: Pain" },
				{ 15273, 3, "Improved Mind Blast" },
				{ 15407, 1, "Mind Flay" },
				{ 1225139, 2, "Improved Mind Flay" },
				{ 15273, 5 },
				{ 15260, 3, "Shadow Focus" },
				{ 15286, 1, "Vampiric Embrace" },
				{ 15257, 3, "Shadow Weaving" },
				{ 1309950, 2, "Devouring Contagion" },
				{ 15260, 4 },
				{ 15259, 5, "Darkness" },
				{ 15473, 1, "Shadowform" },
				{ 14524, 2, "Wand Specialization" },
				{ 1225132, 5, "Twin Disciplines" },
				{ 14531, 2, "Martyrdom" },
				{ 1309957, 1, "Holy Precision" },
				{ 14748, 3, "Improved Power Word: Shield" },
				{ 14521, 3, "Meditation" },
				{ 402000, 1, "Soul Warding" },
				{ 14751, 1, "Inner Focus" },
				{ 18551, 2, "Mental Strength" },
			},
			stats = { "sp", "spi", "sta", "int", "spellHit" },
			consejos = {
				L["Pon tu escudo y tu daño en el tiempo antes de que el monstruo llegue."],
				L["El espíritu te devuelve maná rápido: descansas muy poco."],
			},
		},
	},
})
