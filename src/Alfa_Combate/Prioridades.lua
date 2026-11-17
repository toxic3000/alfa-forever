-- Alfa - Combate: prioridades propias por clase (toxic3000 / La Jauría). GPL-3.0.
--
-- Cuando el cliente no ofrece la ayuda de combate de Blizzard (Forever la
-- trae apagada), Alfa sugiere con su propia lista de prioridad, leída solo
-- con datos de tu personaje (Prioridad.lua). Datos propios de Alfa.
--
-- Cada entrada: id (cualquier rango: se usa el más alto que conozcas, por
-- su nombre), porque (la razón) y sus condiciones:
--   sinBuff = true (te falta ese efecto) | { ids } (te falta cualquiera de esos)
--   cada = s, veces = n   la pusiste en este objetivo hace menos de s segundos (n veces)
--   minPoder / maxPoder   tu ira, energía o maná (en puntos)
--   maxPct                tu maná, en porcentaje
--   minCombo              tus puntos de combo
--   sinArma = true        tu arma no tiene encantamiento temporal
--   aoe = true            solo con varios enemigos; solo = true: solo con uno
--   sinObjetivo = true    no hace falta un enemigo elegido
-- Lo que el juego ya sabe (actitud, forma, arma, alcance, Ejecutar bajo el 20 %,
-- Abrumar tras una esquiva) lo resuelve C_Spell.IsSpellUsable: no se repite aquí.
-- Una lista de clase puede tener ramas: la primera cuya firma conoces manda;
-- la que no tiene firma es la de siempre.

local ADDON, M = ...
local L = M.L

local function e(id, porque, o)
	o = o or {}
	o.id, o.porque = id, porque
	return o
end

-- Guerrero
local GRITO = e(6673, L["Te falta Grito de batalla: más poder de ataque para ti y tu grupo."], { sinBuff = true, sinObjetivo = true })
local CARGA = e(100, L["Abre la pelea: te acerca al enemigo y te da ira."])
local VICTORIA = e(402927, L["Gratis tras vencer a un enemigo, y te cura."])
local EJECUTAR = e(5308, L["Al enemigo le queda poca vida: remátalo."])
local ABRUMAR = e(7384, L["El enemigo esquivó: Abrumar no se puede esquivar y pega fuerte."])
local DESGARRAR = e(772, L["Hace sangrar al enemigo: ponlo al empezar la pelea."], { cada = 15, solo = true })
local ATRONAR = e(6343, L["Golpea y frena a todos los enemigos que tienes cerca."], { aoe = true, sinObjetivo = true })
local HURACAN = e(1680, L["Golpea a varios enemigos a tu alrededor."], { aoe = true, sinObjetivo = true })
local MELLAR = e(845, L["Te sobra ira y hay varios enemigos: tu siguiente golpe alcanza a dos."], { aoe = true, minPoder = 30 })
local BARRIDO = e(12292, L["Tus próximos golpes también alcanzan a otro enemigo."], { aoe = true, sinObjetivo = true })
local HEROICO = e(78, L["Te sobra ira: gástala en tu siguiente golpe."], { minPoder = 45 })
local SANGRE = e(2687, L["Te falta ira: Ira sangrienta te la da gratis."], { maxPoder = 15, soloCombate = true, sinObjetivo = true })

M.PRIORIDADES = {
	WARRIOR = {
		{ clave = "armas", nombre = L["Armas"], firma = { 12294 }, lista = {
			GRITO, CARGA, VICTORIA, EJECUTAR, ABRUMAR,
			e(12294, L["Golpe mortal: tu golpe más fuerte, cada vez que esté listo."]),
			BARRIDO, ATRONAR, HURACAN, DESGARRAR, MELLAR,
			e(1464, L["Embate: un golpe fuerte entre golpe y golpe."], { minPoder = 20 }),
			HEROICO, SANGRE,
		} },
		{ clave = "furia", nombre = L["Furia"], firma = { 23881 }, lista = {
			GRITO, CARGA, VICTORIA, EJECUTAR,
			e(23881, L["Sed de sangre: tu golpe más fuerte, cada vez que esté listo."]),
			e(1680, L["Huracán: golpea a todos a tu alrededor."], { sinObjetivo = true }),
			ABRUMAR, MELLAR,
			e(78, L["Te sobra ira: gástala en tu siguiente golpe."], { minPoder = 40, solo = true }),
			SANGRE,
		} },
		{ clave = "proteccion", nombre = L["Protección"], firma = { 23922 }, lista = {
			GRITO, CARGA, VICTORIA,
			e(6572, L["Revancha: barata y con mucha amenaza tras bloquear o esquivar."]),
			e(23922, L["Embate con escudo: mucho daño y amenaza."]),
			e(1160, L["Los enemigos de alrededor pegan menos."], { aoe = true, cada = 30, sinObjetivo = true }),
			ATRONAR,
			e(7386, L["Hender armadura: amenaza constante y el enemigo recibe más daño."], { cada = 25, veces = 5 }),
			MELLAR,
			e(78, L["Te sobra ira: gástala en tu siguiente golpe."], { minPoder = 40, solo = true }),
			SANGRE,
		} },
		{ clave = "general", lista = {
			GRITO, CARGA, VICTORIA, EJECUTAR, ABRUMAR, DESGARRAR, ATRONAR, MELLAR,
			e(78, L["Golpe heroico: tu golpe más fuerte mientras subes."], { minPoder = 25 }),
			SANGRE,
		} },
	},
	ROGUE = {
		{ clave = "general", lista = {
			e(14251, L["Paraste un golpe: el contraataque está listo."]),
			e(5171, L["Más velocidad de ataque: mantenlo puesto."], { sinBuff = true, minCombo = 1 }),
			e(13877, L["Varios enemigos: tus golpes alcanzan a otro más."], { aoe = true, sinBuff = true, sinObjetivo = true }),
			e(2098, L["Tienes 5 puntos de combo: el remate más fuerte."], { minCombo = 5 }),
			e(1752, L["Golpe siniestro: suma puntos de combo."]),
		} },
	},
	MAGE = {
		{ clave = "general", lista = {
			e(1459, L["Te falta Intelecto Arcano: más maná."], { sinBuff = true, sinObjetivo = true }),
			e(1449, L["Varios enemigos cerca: golpéalos a todos a la vez."], { aoe = true, sinObjetivo = true }),
			e(2136, L["Instantánea: úsala cada vez que esté lista."]),
			e(116, L["Tu hechizo principal: daño y frena al enemigo."]),
			e(133, L["Tu hechizo principal de fuego."]),
		} },
	},
	WARLOCK = {
		{ clave = "general", lista = {
			e(172, L["Daño con el tiempo: ponla al empezar la pelea."], { cada = 18 }),
			e(980, L["Maldición que hace cada vez más daño."], { cada = 24 }),
			e(348, L["Quema al enemigo un rato."], { cada = 15, solo = true }),
			e(1454, L["Te queda poco maná: cambia vida por maná."], { maxPct = 25, sinObjetivo = true }),
			e(686, L["Tu hechizo principal."]),
		} },
	},
	PRIEST = {
		{ clave = "general", lista = {
			e(1243, L["Te falta Palabra de poder: entereza: más vida."], { sinBuff = true, sinObjetivo = true }),
			e(588, L["Te falta Fuego interior: más armadura."], { sinBuff = true, sinObjetivo = true }),
			e(589, L["Daño con el tiempo: ponla al empezar la pelea."], { cada = 18 }),
			e(8092, L["Golpe mental: mucho daño, cada vez que esté listo."]),
			e(15407, L["Tortura mental: daño constante y frena al enemigo."]),
			e(585, L["Tu hechizo principal."]),
		} },
	},
	HUNTER = {
		{ clave = "general", lista = {
			e(13165, L["Te falta Aspecto del halcón: más poder a distancia."], { sinBuff = true, sinObjetivo = true }),
			e(1130, L["Marca al enemigo: todos le pegan más."], { cada = 120 }),
			e(1978, L["Picadura de serpiente: daño con el tiempo."], { cada = 15, solo = true }),
			e(19434, L["Disparo apuntado: tu disparo más fuerte."]),
			e(2643, L["Varios enemigos: el disparo alcanza a varios."], { aoe = true }),
			e(3044, L["Disparo arcano: instantáneo, úsalo cuando esté listo."]),
			e(1495, L["El enemigo esquivó: este golpe está listo."]),
			e(2973, L["El enemigo está encima: golpéalo cuerpo a cuerpo."]),
		} },
	},
	PALADIN = {
		{ clave = "general", lista = {
			e(19740, L["Te falta Bendición de poderío: más poder de ataque."], { sinBuff = true, sinObjetivo = true }),
			e(21084, L["No tienes un sello puesto: ponte uno."], { sinBuff = { 21084, 20375, 21082, 20164, 20165, 20166 }, sinObjetivo = true }),
			e(24275, L["Al enemigo le queda poca vida: remátalo."]),
			e(20271, L["Libera tu sello en el enemigo: daño extra."]),
			e(20925, L["Te falta Escudo sagrado: bloqueas más."], { sinBuff = true, sinObjetivo = true }),
			e(26573, L["Varios enemigos: consagra el suelo bajo ti."], { aoe = true, sinObjetivo = true }),
		} },
	},
	SHAMAN = {
		{ clave = "mejora", nombre = L["Mejora"], firma = { 17364 }, lista = {
			e(324, L["Te falta Escudo de relámpagos."], { sinBuff = true, sinObjetivo = true }),
			e(8232, L["Tu arma no tiene encantamiento: Viento furioso."], { sinArma = true, sinObjetivo = true }),
			e(8024, L["Tu arma no tiene encantamiento: Lengua de fuego."], { sinArma = true, sinObjetivo = true }),
			e(8017, L["Tu arma no tiene encantamiento: Muerdepiedras."], { sinArma = true, sinObjetivo = true }),
			e(17364, L["Ataque de tormenta: mucho daño, cada vez que esté listo."]),
			e(8050, L["Daño de fuego con el tiempo."], { cada = 12, solo = true }),
			e(8042, L["Choque: daño instantáneo."]),
		} },
		{ clave = "general", lista = {
			e(324, L["Te falta Escudo de relámpagos."], { sinBuff = true, sinObjetivo = true }),
			e(8024, L["Tu arma no tiene encantamiento: Lengua de fuego."], { sinArma = true, sinObjetivo = true }),
			e(8017, L["Tu arma no tiene encantamiento: Muerdepiedras."], { sinArma = true, sinObjetivo = true }),
			e(8050, L["Daño de fuego con el tiempo."], { cada = 12, solo = true }),
			e(421, L["Varios enemigos: el rayo salta entre ellos."], { aoe = true }),
			e(8042, L["Choque: daño instantáneo."]),
			e(403, L["Tu hechizo principal."]),
		} },
	},
	DRUID = {
		{ clave = "general", lista = {
			e(1126, L["Te falta Marca de lo Salvaje."], { sinBuff = true, sinObjetivo = true }),
			e(467, L["Te falta Espinas."], { sinBuff = true, sinObjetivo = true }),
			-- Felino
			e(22568, L["Tienes 5 puntos de combo: muerde fuerte."], { minCombo = 5 }),
			e(1822, L["Arañazo: sangrado con el tiempo."], { cada = 9 }),
			e(1082, L["Garra: suma puntos de combo."]),
			-- Oso
			e(779, L["Varios enemigos: golpéalos a todos."], { aoe = true, minPoder = 20, sinObjetivo = true }),
			e(6807, L["Te sobra ira: tu siguiente golpe es más fuerte."], { minPoder = 15 }),
			-- Lanzador
			e(8921, L["Daño con el tiempo: ponla al empezar la pelea."], { cada = 12 }),
			e(5570, L["Más daño con el tiempo."], { cada = 12, solo = true }),
			e(5176, L["Tu hechizo principal."]),
		} },
	},
}
