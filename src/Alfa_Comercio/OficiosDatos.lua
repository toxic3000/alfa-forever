-- Alfa - Comercio: las guías de oficios de 1 a 300 (toxic3000 / La Jauría). GPL-3.0. 1.2.9.
--
-- Una guía por oficio del juego clásico, escrita a mano desde los hechos del
-- juego (recetas, reactivos y rangos). Cada paso es un tramo de habilidad:
--   { desde, hasta, o = objeto que se crea, n = cuántas veces (más o menos),
--     r = { reactivo, cantidad, ... } por cada vez, t = texto propio }
-- Un paso sin `o` es general: dice qué hacer en `t` y sus materiales `r`
-- son el total del tramo (estimado). Los de recolección (`da`, `mapas`) dicen
-- qué sale y en qué zonas (uiMapID). Los números de veces y los totales son
-- orientativos: el juego da puntos por color de receta (naranja siempre,
-- amarillo casi siempre, verde a veces). Si la receta ya la conoces, Alfa
-- usa los reactivos que te da el juego (Recetas.lua) en lugar de estos.
-- Los textos son claves de Textos.lua.

local _, M = ...

local O = {}
M.OFICIOS_GUIA = O

-- Materiales que se repiten (itemID).
local LINO, LANA, SEDA, MAGICO, RUNICO = 2589, 2592, 4306, 4338, 14047
local B_LINO, B_LANA, B_SEDA, B_MAGICO, B_RUNICO = 2996, 2997, 4305, 4339, 14048
local HILO_BASTO, HILO_FINO, HILO_SEDA, HILO_SEDA_GRUESO, HILO_RUNICO = 2320, 2321, 4291, 8343, 14341
local PIEDRA_BASTA, PIEDRA_GRUESA, PIEDRA_PESADA, PIEDRA_SOLIDA, PIEDRA_DENSA = 2835, 2836, 2838, 7912, 12365
local B_COBRE, B_ESTANO, B_BRONCE, B_PLATA, B_HIERRO, B_ORO, B_MITRIL, B_TORIO = 2840, 3576, 2841, 2842, 3575, 3577, 3860, 12359
local FUNDENTE = 2880
local VIAL, VIAL_PLOMO, VIAL_CRISTAL = 3371, 3372, 8925
local SAL = 4289
local POLVO_EXTRANO, POLVO_ALMAS, POLVO_VISION, POLVO_SUENO, POLVO_ILUSION = 10940, 11083, 11137, 11176, 16204
local MAGIA_MENOR, MAGIA_MAYOR, ASTRAL_MAYOR, MISTICA_MAYOR, ABISAL_MAYOR, ETERNA_MENOR = 10938, 10939, 11082, 11135, 11175, 16202

-- Los rangos de cada oficio (el juego clásico): hasta qué habilidad llega
-- cada uno, desde qué habilidad y nivel se aprende el siguiente.
O.RANGOS = {
	{ nombre = "Aprendiz", tope = 75, desde = 1, nivel = 1 },
	{ nombre = "Oficial", tope = 150, desde = 50, nivel = 10 },
	{ nombre = "Experto", tope = 225, desde = 125, nivel = 20 },
	{ nombre = "Artesano", tope = 300, desde = 200, nivel = 35 },
}

-- Orden en la página: los de crear, los de recolección y los secundarios.
O.ORDEN = { 171, 164, 333, 202, 165, 197, 182, 186, 393, 185, 129 }

O[171] = {
	nombre = "Alquimia", tipo = "crear", icono = 118,
	pasos = {
		{ 1, 60, o = 118, n = 60, r = { 2447, 1, 765, 1, VIAL, 1 } },
		{ 60, 110, o = 858, n = 55, r = { 118, 1, 2450, 1 }, t = "Haz Pociones de sanación menores de más para este tramo." },
		{ 110, 140, o = 929, n = 35, r = { 2453, 1, 2450, 1, VIAL_PLOMO, 1 } },
		{ 140, 155, o = 3385, n = 15, r = { 785, 1, 3820, 1, VIAL, 1 } },
		{ 155, 185, o = 1710, n = 30, r = { 3357, 1, 3356, 1, VIAL_PLOMO, 1 } },
		{ 185, 210, o = 8949, n = 25, r = { 3820, 1, 3821, 1, VIAL_PLOMO, 1 } },
		{ 210, 215, o = 8951, n = 5, r = { 3355, 1, 3821, 1, VIAL_PLOMO, 1 } },
		{ 215, 230, o = 3928, n = 15, r = { 8838, 1, 3358, 1, VIAL_CRISTAL, 1 } },
		{ 230, 250, o = 9154, n = 20, r = { 8836, 1, VIAL_CRISTAL, 1 } },
		{ 250, 265, o = 9187, n = 15, r = { 8838, 1, 3821, 1, VIAL_CRISTAL, 1 } },
		{ 265, 285, o = 13443, n = 20, r = { 8838, 2, 8839, 2, VIAL_CRISTAL, 1 } },
		{ 285, 300, o = 13446, n = 20, r = { 13464, 2, 13465, 1, VIAL_CRISTAL, 1 } },
	},
	nota = "Los frascos los venden los proveedores de alquimia. Herboristería es su mejor pareja: tú juntas las hierbas.",
}

O[164] = {
	nombre = "Herrería", tipo = "crear", icono = 2862,
	pasos = {
		{ 1, 25, o = 2862, n = 25, r = { PIEDRA_BASTA, 1 } },
		{ 25, 45, o = 3470, n = 25, r = { PIEDRA_BASTA, 2 } },
		{ 45, 75, o = 2851, n = 30, r = { B_COBRE, 6 } },
		{ 75, 90, o = 3478, n = 15, r = { PIEDRA_GRUESA, 2 } },
		{ 90, 100, o = 2857, n = 10, r = { B_COBRE, 10 } },
		{ 100, 105, o = 6338, n = 5, r = { B_PLATA, 1, 3470, 2 } },
		{ 105, 125, o = 2865, n = 20, r = { B_BRONCE, 6 } },
		{ 125, 150, o = 3486, n = 25, r = { PIEDRA_PESADA, 3 } },
		{ 150, 155, o = 11128, n = 5, r = { B_ORO, 1, 3478, 2 } },
		{ 155, 180, o = 3835, n = 25, r = { B_HIERRO, 6 } },
		{ 180, 200, t = "Piezas de hierro y de acero que te enseñe tu instructor.", r = { B_HIERRO, 160 } },
		{ 200, 210, o = 7966, n = 10, r = { PIEDRA_SOLIDA, 4 } },
		{ 210, 250, t = "Piezas de mitril: lo que tu instructor te enseña con barras de mitril.", r = { B_MITRIL, 220 } },
		{ 250, 260, o = 12644, n = 10, r = { PIEDRA_DENSA, 4 } },
		{ 260, 300, t = "Piezas de torio: lo que tu instructor te enseña con barras de torio.", r = { B_TORIO, 280 } },
	},
	nota = "Minería es su mejor pareja. Necesitas un martillo de herrero y trabajar junto a un yunque.",
}

O[333] = {
	nombre = "Encantamiento", tipo = "crear", icono = POLVO_EXTRANO,
	pasos = {
		{ 1, 2, o = 6218, n = 1, r = { 6217, 1, POLVO_EXTRANO, 1, MAGIA_MENOR, 1 }, t = "La varilla de cobre la venden los proveedores de encantamiento." },
		{ 2, 90, t = "Encantamientos menores de brazales y pecheras con Polvo extraño.", r = { POLVO_EXTRANO, 100, MAGIA_MENOR, 10 } },
		{ 90, 135, t = "Encantamientos de brazales y capas con Polvo extraño y Esencia mágica mayor.", r = { POLVO_EXTRANO, 80, MAGIA_MAYOR, 15 } },
		{ 135, 185, t = "Encantamientos con Polvo de almas y Esencia astral.", r = { POLVO_ALMAS, 100, ASTRAL_MAYOR, 15 } },
		{ 185, 225, t = "Encantamientos con Polvo de visión y Esencia mística.", r = { POLVO_VISION, 90, MISTICA_MAYOR, 15 } },
		{ 225, 265, t = "Encantamientos con Polvo de sueño y Esencia abisal.", r = { POLVO_SUENO, 100, ABISAL_MAYOR, 15 } },
		{ 265, 300, t = "Encantamientos con Polvo de ilusión y Esencia eterna.", r = { POLVO_ILUSION, 110, ETERNA_MENOR, 20 } },
	},
	nota = "Los polvos y las esencias salen de desencantar equipo verde o mejor. Cada tanto tu instructor te pide una varilla rúnica nueva.",
}

O[202] = {
	nombre = "Ingeniería", tipo = "crear", icono = 4357,
	pasos = {
		{ 1, 30, o = 4357, n = 30, r = { PIEDRA_BASTA, 1 } },
		{ 30, 50, o = 4359, n = 20, r = { B_COBRE, 1 } },
		{ 50, 51, o = 6219, n = 1, r = { B_COBRE, 6 } },
		{ 51, 75, o = 4361, n = 25, r = { B_COBRE, 2, FUNDENTE, 1 } },
		{ 75, 100, o = 4364, n = 30, r = { PIEDRA_GRUESA, 1 } },
		{ 100, 105, o = 4404, n = 5, r = { B_PLATA, 1 } },
		{ 105, 125, o = 4371, n = 20, r = { B_BRONCE, 2, FUNDENTE, 1 } },
		{ 125, 150, o = 4375, n = 25, r = { B_BRONCE, 2, LANA, 1 } },
		{ 150, 160, o = 4377, n = 10, r = { PIEDRA_PESADA, 1 } },
		{ 160, 175, o = 4387, n = 15, r = { B_HIERRO, 2 } },
		{ 175, 195, o = 10505, n = 20, r = { PIEDRA_SOLIDA, 2 } },
		{ 195, 215, o = 10559, n = 20, r = { B_MITRIL, 3 } },
		{ 215, 235, o = 10560, n = 20, r = { B_MITRIL, 1, MAGICO, 1, 10505, 1 } },
		{ 235, 250, o = 10561, n = 15, r = { B_MITRIL, 3 } },
		{ 250, 260, o = 15992, n = 10, r = { PIEDRA_DENSA, 2 } },
		{ 260, 285, o = 15994, n = 25, r = { B_TORIO, 3, RUNICO, 1 } },
		{ 285, 300, o = 16000, n = 15, r = { B_TORIO, 6 } },
	},
	nota = "El fundente débil lo venden los proveedores de comercio. Minería te da las piedras y las barras.",
}

O[165] = {
	nombre = "Peletería", tipo = "crear", icono = 2304,
	pasos = {
		{ 1, 30, o = 2304, n = 35, r = { 2318, 1 } },
		{ 30, 55, t = "Piezas de cuero cosido a mano que te enseñe tu instructor.", r = { 2318, 60, HILO_BASTO, 25 } },
		{ 55, 85, o = 4239, n = 30, r = { 2318, 3, HILO_BASTO, 2 } },
		{ 85, 100, o = 4246, n = 15, r = { 2318, 6, HILO_BASTO, 2 } },
		{ 100, 120, o = 4233, n = 20, r = { 4232, 1, SAL, 1 } },
		{ 120, 150, o = 2313, n = 30, r = { 2319, 4, HILO_BASTO, 1 } },
		{ 150, 165, o = 4265, n = 15, r = { 4234, 5, HILO_FINO, 1 } },
		{ 165, 180, o = 4236, n = 15, r = { 4235, 1, SAL, 3 } },
		{ 180, 200, t = "Piezas de cuero pesado que te enseñe tu instructor.", r = { 4234, 120, HILO_FINO, 25 } },
		{ 200, 220, o = 8173, n = 20, r = { 4304, 5, HILO_SEDA, 1 } },
		{ 220, 250, t = "Piezas de cuero grueso que te enseñe tu instructor.", r = { 4304, 150, HILO_SEDA, 40 } },
		{ 250, 265, o = 15564, n = 15, r = { 8170, 5 } },
		{ 265, 300, t = "Piezas de cuero basto: lo que te enseñe tu instructor o un patrón.", r = { 8170, 250, HILO_RUNICO, 40 } },
	},
	nota = "Desuello es su mejor pareja. Los hilos y la sal los venden los proveedores de peletería.",
}

O[197] = {
	nombre = "Sastrería", tipo = "crear", icono = B_LINO,
	pasos = {
		{ 1, 50, o = B_LINO, n = 50, r = { LINO, 2 } },
		{ 50, 75, o = 4307, n = 25, r = { B_LINO, 2, HILO_BASTO, 1 } },
		{ 75, 110, o = B_LANA, n = 40, r = { LANA, 3 } },
		{ 110, 125, t = "Prendas de lana que te enseñe tu instructor.", r = { B_LANA, 30, HILO_FINO, 15 } },
		{ 125, 145, o = B_SEDA, n = 25, r = { SEDA, 4 } },
		{ 145, 175, t = "Prendas de seda que te enseñe tu instructor.", r = { B_SEDA, 60, HILO_SEDA, 30 } },
		{ 175, 185, o = B_MAGICO, n = 15, r = { MAGICO, 5 } },
		{ 185, 250, t = "Prendas de tejido mágico que te enseñe tu instructor.", r = { B_MAGICO, 120, HILO_SEDA_GRUESO, 60 } },
		{ 250, 260, o = B_RUNICO, n = 15, r = { RUNICO, 5 } },
		{ 260, 300, t = "Prendas de tela rúnica que te enseñe tu instructor.", r = { B_RUNICO, 100, HILO_RUNICO, 50 } },
	},
	nota = "La tela sale de los enemigos humanoides de tu nivel. Los hilos los venden los proveedores de sastrería.",
}

O[182] = {
	nombre = "Herboristería", tipo = "juntar", icono = 2447,
	pasos = {
		{ 1, 50, da = { 2447, 765, 2449 }, mapas = { 1429, 1411, 1412, 1438, 1426, 1420 } },
		{ 50, 100, da = { 785, 2450, 3820 }, mapas = { 1436, 1413, 1439, 1421, 1432, 1433 } },
		{ 100, 150, da = { 2453, 3355, 3369, 3356 }, mapas = { 1424, 1437, 1440, 1442, 1431 } },
		{ 150, 205, da = { 3357, 3818, 3821, 3358, 3819 }, mapas = { 1417, 1434, 1443, 1435, 1445 } },
		{ 205, 250, da = { 4625, 8831, 8836, 8838, 8839, 8845 }, mapas = { 1446, 1444, 1425, 1418 } },
		{ 250, 300, da = { 8846, 13464, 13463, 13465, 13466, 13467 }, mapas = { 1449, 1448, 1452, 1422, 1423, 1428 } },
	},
	nota = "Cada hierba pide más habilidad que la anterior: recoge todo lo que puedas y sube sola. Enciende el rastreo de hierbas.",
}

O[186] = {
	nombre = "Minería", tipo = "juntar", icono = 2770,
	pasos = {
		{ 1, 65, da = { 2770, PIEDRA_BASTA }, mapas = { 1429, 1411, 1426, 1412, 1420, 1439 } },
		{ 65, 125, da = { 2771, 2775, PIEDRA_GRUESA }, mapas = { 1436, 1413, 1433, 1421, 1424, 1442, 1437 } },
		{ 125, 175, da = { 2772, 2776, PIEDRA_PESADA }, mapas = { 1417, 1443, 1441, 1434, 1418, 1416 } },
		{ 175, 245, da = { 3858, 7911, PIEDRA_SOLIDA }, mapas = { 1418, 1427, 1446, 1425, 1444, 1447 } },
		{ 245, 300, da = { 10620, PIEDRA_DENSA }, mapas = { 1449, 1428, 1452, 1423, 1451, 1448 } },
	},
	nota = "Funde lo que sacas en una forja: también sube Minería. Necesitas un pico de minero y encender el rastreo de minerales.",
}

O[393] = {
	nombre = "Desuello", tipo = "juntar", icono = 2318,
	pasos = {
		{ 1, 75, da = { 2934, 2318, 783 }, mapas = { 1429, 1411, 1412, 1426, 1436, 1413 }, t = "Bestias hasta el nivel 15." },
		{ 75, 150, da = { 2318, 2319, 4232 }, mapas = { 1413, 1442, 1424, 1437, 1440, 1441 }, t = "Bestias de nivel 15 a 30." },
		{ 150, 225, da = { 4234, 4235, 4304 }, mapas = { 1417, 1434, 1443, 1418, 1445 }, t = "Bestias de nivel 30 a 45." },
		{ 225, 300, da = { 4304, 8169, 8170 }, mapas = { 1446, 1444, 1425, 1449, 1452, 1428 }, t = "Bestias de nivel 45 a 60." },
	},
	nota = "Desde el nivel 20, desuellas bestias de hasta tu habilidad dividida entre 5. Necesitas un cuchillo de desollar.",
}

O[185] = {
	nombre = "Cocina", tipo = "crear", icono = 2681, secundario = true,
	pasos = {
		{ 1, 50, o = 2681, n = 50, r = { 769, 1 } },
		{ 50, 90, o = 2684, n = 40, r = { 2673, 1 } },
		{ 90, 130, o = 5525, n = 40, r = { 5503, 1, 159, 1 } },
		{ 130, 175, o = 3665, n = 45, r = { 3685, 1, 2692, 1 } },
		{ 175, 225, o = 12210, n = 50, r = { 12184, 1, 2692, 1 } },
		{ 225, 275, o = 12218, n = 50, r = { 12207, 1, 3713, 2 } },
		{ 275, 300, o = 13931, n = 25, r = { 13759, 1, 159, 1 } },
	},
	rangos = "El rango Experto viene en un libro que venden los proveedores de cocina; el Artesano, con una misión de Dirge Quikcleave en Gadgetzan.",
	nota = "Las especias y el agua las venden los taberneros y proveedores de cocina. Pesca te da mucho de lo que cocinas.",
}

O[129] = {
	nombre = "Primeros auxilios", tipo = "crear", icono = 1251, secundario = true,
	pasos = {
		{ 1, 40, o = 1251, n = 45, r = { LINO, 1 } },
		{ 40, 80, o = 2581, n = 45, r = { LINO, 2 } },
		{ 80, 115, o = 3530, n = 40, r = { LANA, 1 } },
		{ 115, 150, o = 3531, n = 40, r = { LANA, 2 } },
		{ 150, 180, o = 6450, n = 35, r = { SEDA, 1 } },
		{ 180, 210, o = 6451, n = 35, r = { SEDA, 2 } },
		{ 210, 240, o = 8544, n = 35, r = { MAGICO, 1 } },
		{ 240, 260, o = 8545, n = 25, r = { MAGICO, 2 } },
		{ 260, 290, o = 14529, n = 35, r = { RUNICO, 1 } },
		{ 290, 300, o = 14530, n = 15, r = { RUNICO, 2 } },
	},
	rangos = "El rango Experto viene en un libro de Deneb Walker (Tierras Altas de Arathi) o de Balai Lok'Wein (Marjal Revolcafango); el Artesano, con la misión «Triaje» en Theramore o en Sentencia.",
	nota = "Solo pide tela: guarda la que te sale de los enemigos y sube mientras viajas.",
}
