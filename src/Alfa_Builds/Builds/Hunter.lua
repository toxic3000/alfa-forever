-- Alfa - Builds del cazador (Toxic / La Jauría). GPL-3.0.
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
	clase = "HUNTER",
	nombre = L["Cazador"],
	especialidades = {
		beastmastery = { nombre = L["Dominio de bestias"], indice = 1, icono = 19574, rol = "dps" },
		marksmanship = { nombre = L["Puntería"], indice = 2, icono = 1310687, rol = "dps" },
		survival = { nombre = L["Supervivencia"], indice = 3, icono = 1310533, rol = "dps" },
	},
	recomendados = { solo = "beastmastery-solo-equilibrado" },
	builds = {
		{
			id = "beastmastery-solo-equilibrado", spec = "beastmastery", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Dominio de bestias para subir"],
			resumen = L["Tu mascota hace gran parte del trabajo y aguanta los golpes: la forma más fácil y segura de subir con cazador."],
			fuente = "motor",
			talentos = {
				{ 19552, 5, "Deadly Aspects" },
				{ 1223755, 2, "Focused Fire" },
				{ 19583, 3, "Endurance Training" },
				{ 19616, 5, "Unleashed Fury" },
				{ 19596, 1, "Bestial Swiftness" },
				{ 19598, 5, "Ferocity" },
				{ 19577, 1, "Intimidation" },
				{ 19578, 2, "Spirit Bond" },
				{ 19583, 4 },
				{ 19621, 5, "Frenzy" },
				{ 19574, 1, "Bestial Wrath" },
				{ 19426, 5, "Lethal Attacks" },
				{ 1223984, 5, "Careful Aim" },
				{ 415405, 2, "Rapid Killing" },
				{ 19416, 3, "Efficiency" },
				{ 19485, 5, "Mortal Shots" },
			},
			stats = { "agi", "rdps", "crit", "hit", "ap", "sta" },
			consejos = {
				L["Deja que tu mascota empiece la pelea y dispara cuando el monstruo la esté atacando."],
				L["Dale de comer a tu mascota para que esté contenta y pegue más."],
			},
		},
		{
			id = "marksmanship-solo-equilibrado", spec = "marksmanship", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Puntería para subir"],
			resumen = L["Mucho daño con tu arma a distancia: disparos fuertes antes de que el monstruo llegue."],
			fuente = "motor",
			talentos = {
				{ 19426, 5, "Lethal Attacks" },
				{ 1223984, 5, "Careful Aim" },
				{ 415405, 2, "Rapid Killing" },
				{ 1310661, 3, "Improved Stings" },
				{ 19485, 5, "Mortal Shots" },
				{ 1299346, 1, "Trueshot Aura" },
				{ 1223987, 2, "Rapid Recuperation" },
				{ 19461, 2, "Barrage" },
				{ 19507, 5, "Ranged Weapon Specialization" },
				{ 1310687, 1, "Sniper Shot" },
				{ 19552, 5, "Deadly Aspects" },
				{ 19583, 5, "Endurance Training" },
				{ 1223755, 2, "Focused Fire" },
				{ 19616, 5, "Unleashed Fury" },
				{ 19596, 1, "Bestial Swiftness" },
				{ 19559, 2, "Pathfinding" },
			},
			stats = { "agi", "rdps", "crit", "hit", "rap", "int" },
			consejos = {
				L["Busca siempre el arco, arma de fuego o ballesta con más daño por segundo."],
				L["Mantén al monstruo lejos: tu mascota lo detiene mientras disparas."],
			},
		},
		{
			id = "survival-solo-equilibrado", spec = "survival", objetivo = "solo", estilo = "equilibrado",
			titulo = L["Supervivencia para subir"],
			resumen = L["Trampas, golpes cuerpo a cuerpo de emergencia y mucha agilidad: el cazador más difícil de atrapar."],
			fuente = "motor",
			talentos = {
				{ 24293, 5, "Improved Tracking" },
				{ 19255, 5, "Survivalist" },
				{ 19263, 1, "Deterrence" },
				{ 19290, 3, "Surefooted" },
				{ 19159, 2, "Savage Strikes" },
				{ 19306, 1, "Counterattack" },
				{ 1310627, 3, "Predator's Edge" },
				{ 1310532, 2, "Expose Prey" },
				{ 1310627, 5 },
				{ 1317257, 1, "Strider Kick" },
				{ 19168, 5, "Lightning Reflexes" },
				{ 1310533, 1, "Lacerating Strikes" },
				{ 19426, 5, "Lethal Attacks" },
				{ 1223984, 5, "Careful Aim" },
				{ 415405, 2, "Rapid Killing" },
				{ 19416, 3, "Efficiency" },
				{ 19485, 5, "Mortal Shots" },
			},
			stats = { "agi", "crit", "rdps", "hit", "sta", "ap" },
			consejos = {
				L["Pon una trampa antes de empezar la pelea y lleva al monstruo hacia ella."],
				L["Si te alcanzan, usa tus golpes cuerpo a cuerpo y aléjate otra vez."],
			},
		},
	},
})
