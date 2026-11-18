-- Alfa - Builds del paladín (toxic3000 / La Jauría). GPL-3.0.
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
	clase = "PALADIN",
	nombre = L["Paladín"],
	especialidades = {
		holy = { nombre = L["Sagrado"], indice = 1, icono = 1310911, rol = "sanador" },
		protection = { nombre = (L["Protección [paladín]"]:gsub(" %[.-%]$", "")), indice = 2, icono = 20925, rol = "tanque" },
		retribution = { nombre = L["Reprensión"], indice = 3, icono = 1310735, rol = "dps" },
	},
	recomendados = { solo = "retribution-solo-equilibrado" },
	builds = {
		{
			id = "holy-solo-equilibrado", spec = "holy", objetivo = "solo", estilo = "equilibrado", armas = "escudo",
			titulo = L["Sagrado para subir"],
			resumen = L["El sanador de los paladines: curas fuertes y mucha armadura, ideal para grupos."],
			fuente = "motor",
			talentos = {
				{ 20257, 5, "Divine Intellect" },
				{ 20224, 3, "Improved Seals" },
				{ 20237, 2, "Healing Light" },
				{ 1310899, 3, "Reverence" },
				{ 20237, 3 },
				{ 20205, 2, "Spiritual Focus" },
				{ 20210, 5, "Illumination" },
				{ 20216, 1, "Divine Favor" },
				{ 1311606, 1, "Holy Shock" },
				{ 426065, 2, "Infusion of Light" },
				{ 5923, 5, "Holy Power" },
				{ 1310911, 1, "Light's Vigil" },
				{ 20101, 5, "Benediction" },
				{ 25956, 2, "Improved Judgement" },
				{ 20117, 5, "Conviction" },
				{ 20375, 1, "Seal of Command" },
				{ 1311074, 3, "Sanctified Judgement" },
				{ 1237268, 2, "Holy Conduit" },
				{ 26022, 2, "Pursuit of Justice" },
			},
			stats = { "heal", "int", "mp5", "spellCrit", "sta" },
			consejos = {
				L["En grupo, cura al tanque antes que a nadie."],
				L["Lleva siempre un sello puesto aunque estés curando."],
			},
		},
		{
			id = "protection-solo-equilibrado", spec = "protection", objetivo = "solo", estilo = "equilibrado", armas = "escudo",
			titulo = (L["Protección para subir [paladín]"]:gsub(" %[.-%]$", "")),
			resumen = L["Escudo y luz sagrada: un tanque muy resistente que recupera su propio maná."],
			fuente = "motor",
			talentos = {
				{ 20127, 5, "Redoubt" },
				{ 20189, 3, "Precision" },
				{ 20096, 2, "Anticipation" },
				{ 1314103, 1, "Improved Seal of Fury" },
				{ 20468, 3, "Improved Righteous Fury" },
				{ 20150, 3, "Shield Specialization" },
				{ 1224697, 2, "Sacred Duty" },
				{ 1310994, 1, "Swift Judgement" },
				{ 20096, 5 },
				{ 1311015, 1, "Templar's Bulwark" },
				{ 20196, 3, "One-Handed Weapon Specialization" },
				{ 1311034, 5, "Iron Creed" },
				{ 20925, 1, "Holy Shield" },
				{ 20143, 5, "Toughness" },
				{ 20487, 3, "Improved Hammer of Justice" },
				{ 20262, 5, "Divine Strength" },
				{ 20224, 3, "Improved Seals" },
				{ 20237, 2, "Healing Light" },
			},
			stats = { "sta", "defense", "armor", "block", "sp", "int" },
			consejos = {
				L["Mantén Furia recta encendida cuando tanquees."],
				L["Junta varios monstruos: tus golpes sagrados alcanzan a todos."],
			},
		},
		{
			id = "retribution-solo-equilibrado", spec = "retribution", objetivo = "solo", estilo = "equilibrado", armas = "2h",
			titulo = L["Reprensión para subir"],
			resumen = L["Arma de dos manos, sellos y juicios: el paladín que mejor sube en solitario."],
			fuente = "motor",
			talentos = {
				{ 20101, 5, "Benediction" },
				{ 25956, 2, "Improved Judgement" },
				{ 20117, 3, "Conviction" },
				{ 20375, 1, "Seal of Command" },
				{ 1311074, 3, "Sanctified Judgement" },
				{ 20117, 5 },
				{ 9452, 3, "Vindication" },
				{ 1311087, 1, "Sacred Arbiter" },
				{ 20049, 3, "Vengeance" },
				{ 20111, 3, "Two-Handed Weapon Specialization" },
				{ 26022, 2, "Pursuit of Justice" },
				{ 1237268, 2, "Holy Conduit" },
				{ 1310735, 1, "Twist of Light" },
				{ 1311085, 2, "Instrument of Law" },
				{ 20262, 5, "Divine Strength" },
				{ 20224, 3, "Improved Seals" },
				{ 20237, 2, "Healing Light" },
				{ 20060, 5, "Deflection" },
				{ 20066, 1, "Repentance" },
				{ 9799, 2, "Eye for an Eye" },
			},
			stats = { "str", "dps", "crit", "hit", "agi", "int" },
			consejos = {
				L["Busca el arma de dos manos más lenta y fuerte: tus sellos pegan con ella."],
				L["Usa el juicio y vuelve a poner tu sello enseguida."],
			},
		},
	},
})
