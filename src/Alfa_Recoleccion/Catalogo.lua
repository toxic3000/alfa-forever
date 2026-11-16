-- Alfa - Recolección: el catálogo de recursos (Toxic / La Jauría, GPL-3.0).
--
-- La lista de recursos, sus IDs de objeto de Forever, los niveles de
-- habilidad y los nombres en español e inglés vienen de GatherLite
-- (scripts/nodes.lua y scripts/locales/*.lua), Copyright (c) 2019 Wuild,
-- licencia MIT: ver LICENSE-GatherLite.txt en esta carpeta.
--
-- Cada grupo es un recurso tal como lo ve quien juega ("Filón de cobre"):
--   tipo     "mineria" | "hierbas" | "pesca" | "tesoros"
--   clave    nombre estable (el de GatherLite), se guarda en los datos
--   ids      IDs de objeto del juego que son este recurso
--   niveles  { mínimo, amarillo, verde, gris } de la habilidad (o solo el mínimo)
--   item     objeto cuyo ícono lo representa en el mapa (C_Item.GetItemIconByID)
--   es, en   nombre en español (esMX) e inglés
--   alias    otros nombres con que el juego lo llama (para reconocerlo al recolectar)

local _, M = ...

M.TIPOS = { "mineria", "hierbas", "pesca", "tesoros" }

-- Por tipo: la habilidad (skill line), el hechizo que lo representa y su color en el mapa.
M.TIPO = {
	mineria = { oficio = 186, hechizo = 2575, color = { 0.96, 0.63, 0.34 } },
	hierbas = { oficio = 182, hechizo = 2366, color = { 0.46, 0.86, 0.42 } },
	pesca = { oficio = 356, hechizo = 7620, color = { 0.42, 0.74, 1.00 } },
	tesoros = { hechizo = 3365, color = { 1.00, 0.82, 0.32 } },
}

M.GRUPOS = {}
M.porObjeto = {} -- objectID -> índice del grupo
M.porClave = {}  -- clave -> índice del grupo

local function R(tipo, clave, ids, niveles, item, es, en, alias, mapa)
	local g = #M.GRUPOS + 1
	M.GRUPOS[g] = { tipo = tipo, clave = clave, ids = ids, niveles = niveles, item = item, es = es, en = en, alias = alias, mapa = mapa }
	M.porClave[clave] = g
	for i = 1, #ids do
		if not M.porObjeto[ids[i]] then M.porObjeto[ids[i]] = g end
	end
end

---------------------------------------------------------------------------
-- Minería
---------------------------------------------------------------------------
R("mineria", "copper_vein", { 1731, 2055, 3763, 103713, 103714, 562111 }, { 1, 25, 50, 100 }, 2770,
	"Filón de cobre", "Copper Vein", { "Veta de cobre débil", "Filón de cobre escasa", "Filón de cobre pobre", "Weak Copper Vein", "Poor Copper Vein" })
R("mineria", "tin_vein", { 1732, 3764, 2054, 103711, 103709 }, { 65, 90, 115, 165 }, 2771,
	"Filón de estaño", "Tin Vein")
R("mineria", "silver_vein", { 1733, 105569, 73940 }, { 75, 100, 125, 175 }, 2775,
	"Filón de plata", "Silver Vein", { "Veta de plata cubierta de moco", "Filón de plata cubierto de moco", "Ooze Covered Silver Vein" })
R("mineria", "iron_deposit", { 1735, 103710, 103712, 73939 }, { 125, 150, 175, 225 }, 2772,
	"Depósito de hierro", "Iron Deposit")
R("mineria", "gold_vein", { 1734, 150080, 181109, 73941 }, { 155, 180, 205, 255 }, 2776,
	"Filón de oro", "Gold Vein", { "Veta de oro cubierta de moco", "Filón de oro cubierto de moco", "Ooze Covered Gold Vein" })
R("mineria", "mithril_deposit", { 2040, 150079, 176645, 123310 }, { 175, 200, 225, 275 }, 3858,
	"Depósito de mitril", "Mithril Deposit", { "Depósito de mitril cubierto de moco", "Ooze Covered Mithril Deposit" })
R("mineria", "truesilver_deposit", { 2047, 150081, 181108, 123309 }, { 230, 255, 280, 330 }, 7911,
	"Depósito de veraplata", "Truesilver Deposit", { "Depósito de veraplata cubierto de moco", "Depósito de veraplata cubierta de moco", "Ooze Covered Truesilver Deposit" })
R("mineria", "dark_iron_deposit", { 165658 }, { 230, 255, 280, 330 }, 11370,
	"Depósito de hierro negro", "Dark Iron Deposit", { "Depósito de los Hierro Negro" })
R("mineria", "small_thorium_vein", { 324, 150082, 176643, 123848 }, { 245, 270, 295, 345 }, 10620,
	"Filón pequeño de torio", "Small Thorium Vein", { "Filón de torio cubierto de moco", "Ooze Covered Thorium Vein" })
R("mineria", "rich_thorium_vein", { 175404, 176644, 177388 }, { 275, 290, 300, 350 }, 10620,
	"Filón de torio enriquecido", "Rich Thorium Vein", { "Filón de torio enriquecido cubierto de moco", "Ooze Covered Rich Thorium Vein" })
-- Recursos de Forever: GatherLite solo conoce su nivel mínimo.
R("mineria", "cold_iron_deposit", { 439558 }, { 125 }, 2772, "Depósito de hierro frío", "Cold Iron Deposit")
R("mineria", "fools_gold_vein", { 439628 }, { 175 }, 2776, "Filón de oro de tontos", "Fool's Gold Vein", { "Filón de oro falso" })
R("mineria", "starsilver_vein", { 439778 }, { 245 }, 7911, "Veta de plata estelar", "Starsilver Vein", { "Filón de plataestelar" })
R("mineria", "greater_moonstone_formation", { 439815 }, { 245 }, 2775,
	"Formación de piedra lunar grande", "Greater Moonstone Formation", { "Formación de piedra lunar superior" })
R("mineria", "incendicite_mineral_vein", { 1610, 1667 }, { 65 }, 3340, "Filón de incendicita", "Incendicite Mineral Vein")
R("mineria", "lesser_bloodstone_deposit", { 2653 }, { 75 }, 4278,
	"Depósito de sangrita inferior", "Lesser Bloodstone Deposit", { "Depósito de Petrosangre inferior" })
R("mineria", "indurium_mineral_vein", { 19903 }, { 150 }, 5833, "Filón de indurio", "Indurium Mineral Vein")
R("mineria", "hakkari_thorium_vein", { 180215 }, { 275 }, 10620, "Veta de torio Hakkari", "Hakkari Thorium Vein", { "Filon de torio de Hakkari", "Filón de torio de Hakkari" })
R("mineria", "small_obsidian_chunk", { 181068 }, { 305 }, 22202,
	"Fragmento pequeño de obsidiana", "Small Obsidian Chunk", { "Trozo pequeño de obsidiano" })
R("mineria", "large_obsidian_chunk", { 181069 }, { 305 }, 22203,
	"Fragmento grande de obsidiana", "Large Obsidian Chunk", { "Trozo de Obsidiano grande" })
R("mineria", "heavy_thorium_vein", { 566779 }, { 300 }, 10620, "Filón de torio pesado", "Heavy Thorium Vein")
R("mineria", "chunk_of_amber", { 656332 }, { 1 }, 2770, "Trozo de ámbar", "Chunk of Amber")
R("mineria", "large_chunk_of_amber", { 656333 }, { 1 }, 2770, "Trozo de ámbar grande", "Large Chunk of Amber")

---------------------------------------------------------------------------
-- Herboristería
---------------------------------------------------------------------------
R("hierbas", "silverleaf", { 1617, 3725, 656161 }, { 1, 25, 50, 100 }, 765,
	"Hojaplata", "Silverleaf", { "Hojaplata atrofiada", "Stunted Silverleaf" })
R("hierbas", "peacebloom", { 1618, 3724, 656160 }, { 1, 25, 50, 100 }, 2447,
	"Flor de paz", "Peacebloom", { "Flor de paz marchita", "Wilted Peacebloom" })
R("hierbas", "earthroot", { 1619, 3726 }, { 15, 40, 65, 115 }, 2449, "Raíz de tierra", "Earthroot")
R("hierbas", "mageroyal", { 1620, 3727 }, { 50, 75, 100, 150 }, 785, "Marregal", "Mageroyal")
R("hierbas", "briarthorn", { 1621, 3729 }, { 70, 95, 120, 170 }, 2450, "Brezospina", "Briarthorn")
R("hierbas", "stranglekelp", { 2045 }, { 85, 110, 135, 185 }, 3820, "Alga estranguladora", "Stranglekelp")
R("hierbas", "bruiseweed", { 1622, 3730 }, { 100, 125, 150, 200 }, 2453, "Hierba cardenal", "Bruiseweed")
R("hierbas", "wild_steelbloom", { 1623 }, { 115, 140, 165, 215 }, 3355, "Acérita salvaje", "Wild Steelbloom")
R("hierbas", "grave_moss", { 1628 }, { 120, 145, 170, 220 }, 3369, "Musgo de tumba", "Grave Moss")
R("hierbas", "kingsblood", { 1624 }, { 125, 150, 175, 225 }, 3356, "Sangrerregia", "Kingsblood")
R("hierbas", "liferoot", { 2041 }, { 150, 175, 200, 250 }, 3357, "Vidarraíz", "Liferoot")
R("hierbas", "fadeleaf", { 2042 }, { 160, 185, 210, 260 }, 3818, "Pálida", "Fadeleaf")
R("hierbas", "goldthorn", { 2046 }, { 170, 195, 220, 270 }, 3821, "Espina de oro", "Goldthorn")
R("hierbas", "khadgars_whisker", { 2043 }, { 185, 210, 235, 285 }, 3358, "Mostacho de Khadgar", "Khadgar's Whisker", { "Vibrisa de Khadgar" })
R("hierbas", "wintersbite", { 2044 }, { 195, 220, 245, 295 }, 3819, "Invernalia", "Wintersbite")
R("hierbas", "firebloom", { 2866 }, { 205, 230, 255, 305 }, 4625, "Flor de fuego", "Firebloom")
R("hierbas", "purple_lotus", { 142140, 180165 }, { 210, 235, 260, 310 }, 8831, "Loto cárdeno", "Purple Lotus")
R("hierbas", "arthas_tears", { 142141, 176642 }, { 220, 245, 270, 320 }, 8836, "Lágrimas de Arthas", "Arthas' Tears")
R("hierbas", "sungrass", { 142142, 176636, 180164 }, { 230, 255, 280, 330 }, 8838, "Solea", "Sungrass")
R("hierbas", "blindweed", { 142143, 183046 }, { 235, 260, 285, 335 }, 8839, "Carolina", "Blindweed")
R("hierbas", "ghost_mushroom", { 142144 }, { 245, 270, 295, 345 }, 8845, "Champiñón fantasma", "Ghost Mushroom")
R("hierbas", "gromsblood", { 142145, 176637 }, { 250, 275, 300, 350 }, 8846, "Gromsanguina", "Gromsblood")
R("hierbas", "golden_sansam", { 176583, 176638, 180167 }, { 260, 285, 310, 360 }, 13464, "Sansam dorado", "Golden Sansam")
R("hierbas", "dreamfoil", { 176584, 176639, 180168 }, { 270, 295, 320, 370 }, 13463, "Hojasueño", "Dreamfoil")
R("hierbas", "mountain_silversage", { 176586, 176640, 180166 }, { 280, 305, 330, 380 }, 13465, "Salviargenta de montaña", "Mountain Silversage")
R("hierbas", "plaguebloom", { 176587, 176641 }, { 285, 310, 335, 385 }, 13466, "Flor de plaga", "Plaguebloom", { "flor de peste" })
R("hierbas", "icecap", { 176588 }, { 290, 315, 340, 390 }, 13467, "Setelo", "Icecap")
R("hierbas", "black_lotus", { 176589 }, { 300, 325, 350, 400 }, 13468, "Loto negro", "Black Lotus")
R("hierbas", "nightmare_moss", { 439557 }, { 125 }, 3369, "Musgo de pesadilla", "Nightmare Moss", { "Musgo de la Pesadilla" })
R("hierbas", "dreamroot", { 439627 }, { 205 }, 2449, "Raíz onírica", "Dreamroot", { "Raíz del Sueño" })
R("hierbas", "moonroot", { 439810 }, { 250 }, 13463, "Lunarraíz", "Moonroot", { "Raíz lunar" })
R("hierbas", "star_lotus", { 439762 }, { 250 }, 13468, "Loto estelar", "Star Lotus")
R("hierbas", "hyjal_silphium", { 654624 }, { 1 }, 2447, "Silfio de Hyjal", "Hyjal Silphium")
R("hierbas", "tomb_weed", { 694732 }, { 1 }, 3369, "Tumbalíseas", "Tomb Weed")
R("hierbas", "demonsage", { 566786 }, { 300 }, 13465, "Salvia demoníaca", "Demonsage")

---------------------------------------------------------------------------
-- Tesoros (cofres, baúles y almejas que se abren)
---------------------------------------------------------------------------
R("tesoros", "battered_chest", { 106319, 2843, 106318, 2849 }, nil, nil, "Cofre maltrecho", "Battered Chest")
R("tesoros", "large_battered_chest", { 75293 }, nil, nil, "Cofre grande abollado", "Large Battered Chest")
R("tesoros", "solid_chest", { 2850, 153453, 153454, 2855, 153451, 2852, 2857, 4149 }, nil, nil, "Cofre macizo", "Solid Chest", { "Cofre sólido" })
R("tesoros", "large_solid_chest", { 74448, 153464, 75300, 153463, 75299, 75298, 153462, 153461 }, nil, nil,
	"Cofre macizo grande", "Large Solid Chest", { "Cofre sólido grande" })
R("tesoros", "giant_clam", { 2744, 19018, 19017 }, nil, 5523, "Almeja gigante", "Giant Clam")
R("tesoros", "ungoro_dirt_pile", { 157936 }, nil, 11018, "Montón de porquería de Un'Goro", "Un'Goro Dirt Pile")
R("tesoros", "practice_lockbox", { 178244, 178245, 178246 }, nil, nil, "Arcón de prácticas", "Practice Lockbox")
R("tesoros", "buccaneers_strongbox", { 123330, 123331, 123332, 123333 }, nil, nil, "Caja fuerte de bucanero", "Buccaneer's Strongbox")
R("tesoros", "battered_footlocker", { 179486, 179488, 179490 }, nil, nil, "Baúl maltrecho", "Battered Footlocker")
R("tesoros", "waterlogged_footlocker", { 179487, 179489, 179491 }, nil, nil, "Baúl con marcas de agua", "Waterlogged Footlocker")
R("tesoros", "dented_footlocker", { 179492, 179494, 179496 }, nil, nil, "Baúl abollado", "Dented Footlocker")
R("tesoros", "mossy_footlocker", { 179493, 179497 }, nil, nil, "Baúl mohoso", "Mossy Footlocker")
R("tesoros", "scarlet_footlocker", { 179498 }, nil, nil, "Baúl Escarlata", "Scarlet Footlocker")
R("tesoros", "alliance_strongbox", { 3714, 105570 }, nil, nil, "Caja fuerte de la Alianza", "Alliance Strongbox")
R("tesoros", "large_mithril_bound_chest", { 153468, 131978, 153469 }, nil, nil, "Cofre reforzado con mitril grande", "Large Mithril Bound Chest")
-- Los dos cofres comparten nombre en coreano; GatherLite reconoce este solo en la isla Zephras.
R("tesoros", "dented_chest", { 626718, 626752 }, nil, nil, "Cofre abollado", "Dented Chest", nil, 2521)

---------------------------------------------------------------------------
-- Pesca (bancos de peces y restos que se pescan)
---------------------------------------------------------------------------
R("pesca", "floating_battered_chest", { 180902, 180683, 180657, 180752 }, nil, nil, "Cofre maltrecho flotante", "Floating Battered Chest")
R("pesca", "fish_pool_debris", { 180655 }, nil, nil, "Desechos flotantes", "Floating Debris")
R("pesca", "fish_pool_wreckage", { 180685, 180662, 180901, 180751 }, nil, nil, "Restos flotantes", "Floating Wreckage")
R("pesca", "fish_pool_oily_blackmouth", { 180750, 180900, 180682, 180664, 180582 }, nil, 6358,
	"Banco de pez de boquerón aceitoso", "Oily Blackmouth School")
R("pesca", "fish_pool_sagefish", { 180656, 180663 }, nil, 21071, "Banco de pargos", "Sagefish School")
