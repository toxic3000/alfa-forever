-- Alfa - Builds del pícaro (toxic3000 / La Jauría). GPL-3.0.
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
	clase = "ROGUE",
	nombre = L["Pícaro"],
	especialidades = {
		assassination = { nombre = L["Asesinato"], indice = 1, icono = 1310703, rol = "dps" },
		combat = { nombre = L["Combate"], indice = 2, icono = 13750, rol = "dps" },
		subtlety = { nombre = L["Sutileza"], indice = 3, icono = 1310721, rol = "dps" },
	},
	recomendados = { solo = "combat-solo-equilibrado" },
	builds = {
		{
			id = "assassination-solo-equilibrado", spec = "assassination", objetivo = "solo", estilo = "equilibrado", armas = "dual",
			titulo = L["Asesinato para subir"],
			resumen = L["Venenos y críticos: matas rápido, sobre todo atacando por la espalda."],
			fuente = "motor",
			talentos = {
				{ 14138, 5, "Malice" },
				{ 14156, 3, "Ruthlessness" },
				{ 14158, 2, "Murder" },
				{ 14179, 1, "Relentless Strikes" },
				{ 14128, 5, "Lethality" },
				{ 14177, 1, "Cold Blood" },
				{ 14113, 3, "Improved Poisons" },
				{ 1310707, 1, "Mutilate" },
				{ 14144, 2, "Remorseless Attacks" },
				{ 14113, 5 },
				{ 14186, 5, "Seal Fate" },
				{ 1310703, 1, "Venom" },
				{ 13732, 2, "Improved Sinister Strike" },
				{ 14162, 3, "Improved Eviscerate" },
				{ 13705, 3, "Precision" },
				{ 13713, 3, "Deflection" },
				{ 14251, 1, "Riposte" },
				{ 1224716, 3, "Puncturing Wounds" },
				{ 13715, 5, "Dual Wield Specialization" },
			},
			stats = { "agi", "dps", "crit", "hit", "ap", "sta" },
			consejos = {
				L["Pon venenos en tus armas siempre."],
				L["Abre desde el sigilo para empezar con ventaja."],
			},
		},
		{
			id = "combat-solo-equilibrado", spec = "combat", objetivo = "solo", estilo = "equilibrado", armas = "dual",
			titulo = L["Combate para subir"],
			resumen = L["El pícaro más fácil para subir: pega de frente, esquiva mucho y aguanta mejor que los demás."],
			fuente = "motor",
			talentos = {
				{ 13732, 2, "Improved Sinister Strike" },
				{ 14162, 3, "Improved Eviscerate" },
				{ 13705, 3, "Precision" },
				{ 13713, 3, "Deflection" },
				{ 14251, 1, "Riposte" },
				{ 1224716, 3, "Puncturing Wounds" },
				{ 13715, 5, "Dual Wield Specialization" },
				{ 13877, 1, "Blade Flurry" },
				{ 13960, 5, "Hack and Slash" },
				{ 30919, 2, "Weapon Expertise" },
				{ 18427, 2, "Aggression" },
				{ 13750, 1, "Adrenaline Rush" },
				{ 14138, 5, "Malice" },
				{ 14156, 3, "Ruthlessness" },
				{ 14158, 2, "Murder" },
				{ 14179, 1, "Relentless Strikes" },
				{ 14128, 5, "Lethality" },
				{ 14165, 2, "Improved Slice and Dice" },
				{ 14144, 2, "Remorseless Attacks" },
			},
			stats = { "agi", "hit", "dps", "crit", "ap", "sta" },
			consejos = {
				L["Usa tu golpe principal para juntar puntos de combo y gástalos en tu remate."],
				L["La precisión es lo más importante: con dos armas fallas mucho sin ella."],
			},
		},
		{
			id = "subtlety-solo-equilibrado", spec = "subtlety", objetivo = "solo", estilo = "equilibrado", armas = "dual",
			titulo = L["Sutileza para subir"],
			resumen = L["Sigilo y emboscadas: tú eliges cuándo pelear y desapareces cuando quieres."],
			fuente = "motor",
			talentos = {
				{ 14057, 2, "Opportunity" },
				{ 13975, 4, "Camouflage" },
				{ 13983, 3, "Setup" },
				{ 14079, 3, "Improved Ambush" },
				{ 14278, 1, "Ghostly Strike" },
				{ 13976, 3, "Initiative" },
				{ 14183, 1, "Premeditation" },
				{ 14171, 3, "Serrated Blades" },
				{ 16511, 1, "Hemorrhage" },
				{ 14185, 1, "Preparation" },
				{ 14082, 2, "Dirty Deeds" },
				{ 13975, 5 },
				{ 1310728, 5, "Quietus" },
				{ 1310721, 1, "Thousand Cuts" },
				{ 13732, 2, "Improved Sinister Strike" },
				{ 14162, 3, "Improved Eviscerate" },
				{ 13705, 3, "Precision" },
				{ 13713, 3, "Deflection" },
				{ 14251, 1, "Riposte" },
				{ 1224716, 3, "Puncturing Wounds" },
				{ 13715, 5, "Dual Wield Specialization" },
			},
			stats = { "agi", "dps", "crit", "hit", "ap", "sta" },
			consejos = {
				L["Abre siempre desde el sigilo con tu ataque más fuerte."],
				L["Si la pelea va mal, desvanécete y vuelve a empezar."],
			},
		},
	},
})
