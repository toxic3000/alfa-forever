-- Alfa - Lya: datos curiosos de cada zona y lore del mundo (toxic3000 / La Jauría). GPL-3.0.
--
-- Notas propias de Alfa, escritas por nosotros (cortas, una o dos frases), con
-- su inglés en Textos.lua. Lya cuenta una al entrar por primera vez a una zona
-- (no siempre), al pedírselo («Cuéntame algo de aquí») y, muy de vez en cuando,
-- en un rato tranquilo. Cada nota sale una vez por personaje (hist.datos).
--
--   M.DATOS_ZONA[uiMapID] = { "nota", ... }   ids z<mapa>.<n>
--   M.LORE = { "nota", ... }                   ids l<n>
-- Las notas nuevas van AL FINAL de su lista, para no mover los ids.

local ADDON, M = ...

M.DATOS_ZONA = {
	[1411] = { -- Durotar
		"Durotar lleva el nombre de Durotan, el padre de Thrall y jefe del clan Lobo Gélido. Thrall honró su memoria al nombrar así la tierra de los orcos.",
		"Thrall eligió esta tierra roja y seca para que los orcos libres empezaran de nuevo, lejos de los campos de internamiento de los humanos.",
		"Los trols Lanza Negra conocieron a Thrall en las islas donde naufragó su flota rumbo a Kalimdor. Su líder Sen'jin murió ahí, y desde entonces los guía su hijo Vol'jin.",
		"Las Islas del Eco eran el hogar de los Lanza Negra, hasta que el brujo Zalazane sometió a muchos con su vudú y los demás tuvieron que mudarse a tierra firme.",
	},
	[1412] = { -- Mulgore
		"Los tauren vivían como nómadas, acosados por los centauros, hasta que Cairne Pezuña de Sangre se alió con Thrall. Con la ayuda de la Horda encontraron su hogar en Mulgore.",
		"Los tauren honran a la Madre Tierra. Dicen que el sol y la luna son sus ojos: An'she y Mu'sha.",
		"Ventura y Cía. abrió minas en Mulgore sin pedir permiso, y a los tauren eso no les hace ninguna gracia.",
	},
	[1413] = { -- The Barrens
		"El Cruce es un puesto de la Horda justo en medio de Los Baldíos, donde se juntan los caminos principales. De ahí su nombre.",
		"Los centauros dicen descender de Zaetar, hijo del semidiós Cenarius, y de Theradras, la princesa de la tierra. Pelean entre sus clanes casi tanto como contra los demás.",
		"Trinquete es un puerto goblin neutral: ahí se tolera a cualquiera que traiga oro, y su barco lleva hasta Bahía del Botín.",
		"Según su leyenda, los jabaespines nacieron de la sangre de Agamaggan, el gran jabalí semidiós. Por eso viven entre espinas gigantes.",
		"En las Cuevas de los Lamentos, el druida Naralex soñó con devolverle el verdor a Los Baldíos, y su sueño se volvió pesadilla.",
	},
	[1416] = { -- Alterac Mountains
		"El reino humano de Alterac traicionó a la Alianza en la Segunda Guerra: su rey, Aiden Perenolde, se alió con la Horda. Por eso el reino desapareció.",
		"En las ruinas de la ciudad de Alterac hoy mandan los ogros y el Sindicato, la banda de nobles caídos del viejo reino.",
		"El clan Lobo Gélido vive exiliado en el valle de Alterac. Thrall, hijo de su antiguo jefe, los encontró ahí después de escapar de Durnholde.",
		"Al sur está Dalaran, la ciudad de los magos. Archimonde la arrasó en la Tercera Guerra, y sus magos la reconstruyen protegidos bajo una cúpula.",
	},
	[1417] = { -- Arathi Highlands
		"En estas tierras estuvo Strom, la capital de Arathor, el primer gran reino humano.",
		"El rey Thoradin unió a las tribus humanas en Arathor, y los altos elfos les enseñaron magia para vencer juntos a los trols Amani.",
		"Stromgarde, la heredera de Strom, resiste a medias: trols, ogros y el Sindicato se pelean por sus ruinas.",
	},
	[1418] = { -- Badlands
		"Bajo estas tierras está Uldaman, una ciudad de los titanes. Los enanos de la Liga de Expedicionarios creen que ahí están las pistas de su propio origen.",
		"Los troggs salieron de las profundidades de Uldaman. Todo indica que son una creación antigua de los titanes que salió mal.",
		"Kargath, el campamento de la Horda, lleva el nombre de un viejo caudillo orco del clan Mano Destrozada.",
	},
	[1419] = { -- Blasted Lands
		"Aquí está el Portal Oscuro: por él cruzó la Horda desde Draenor para invadir Azeroth en la Primera Guerra.",
		"Antes esto era un pantano. La magia del portal y la guerra lo dejaron rojo, seco y sin vida.",
		"Nethergarde es un bastión de magos de la Alianza que vigila el Portal Oscuro, por si algo vuelve a cruzar.",
	},
	[1420] = { -- Tirisfal Glades
		"Los Claros de Tirisfal guardan las ruinas de Lordaeron, el reino de Arthas. Bajo su antigua capital, los Renegados levantaron Entrañas.",
		"La Cruzada Escarlata tiene aquí su monasterio. Para ellos todo no-muerto debe arder, también los Renegados.",
		"La Orden de Tirisfal, los magos secretos que elegían al Guardián de Azeroth, tomó su nombre de estos claros. Medivh fue el último Guardián.",
	},
	[1421] = { -- Silverpine Forest
		"El Castillo de Colmillo Oscuro fue de Arugal, un mago de Dalaran que convocó a los worgen para pelear contra la Plaga y terminó perdiendo la razón.",
		"Al sur se alza una muralla enorme: el rey Genn Cringris la levantó para aislar Gilneas del resto del mundo.",
		"El Sepulcro es el puesto de los Renegados en el bosque; desde ahí vigilan a los worgen y a los magos de Dalaran.",
	},
	[1422] = { -- Western Plaguelands
		"Andorhal era el granero de Lordaeron. Kel'Thuzad repartió ahí grano apestado y la plaga se extendió por todo el reino.",
		"Scholomance, en la isla de Caer Darrow, es la escuela donde la Plaga enseña nigromancia. Antes fue el hogar de la familia Barov.",
		"Aquí está la tumba de Uther el Iluminado, el maestro de Arthas. Murió a manos de su propio alumno, defendiendo las cenizas del rey Terenas.",
	},
	[1423] = { -- Eastern Plaguelands
		"Arthas purgó Stratholme porque su grano estaba infectado. Esa decisión lo separó para siempre de Uther y de Jaina.",
		"La Capilla de la Esperanza de la Luz resistió a la Plaga en una batalla legendaria; hoy es el gran refugio del Alba Argenta.",
		"Alexandros Mograine empuñaba la Crematoria, y la Plaga le temía como a nadie. Lo traicionó su propio hijo, Renault.",
		"Naxxramas, la necrópolis de Kel'Thuzad, flota sobre estas tierras como una sombra.",
	},
	[1424] = { -- Hillsbrad Foothills
		"En estas laderas está Durnholde, donde Aedelas Blackmoore crió a Thrall como gladiador.",
		"Costasur y Molino Tarren están a un paso uno del otro, y la Alianza y la Horda se miran feo desde siempre.",
		"El Sindicato, los nobles caídos de Alterac, también asalta caminos y granjas por estas tierras.",
	},
	[1425] = { -- The Hinterlands
		"En Pico Nidal viven los enanos Martillo Salvaje, famosos por volar sobre grifos.",
		"Los trols de estas tierras descienden de los Amani, el antiguo imperio de los trols del bosque. En Jintha'Alor siguen levantando sus altares.",
		"En Seradane hay uno de los grandes árboles que llevan al Sueño Esmeralda, y los dragones verdes lo custodian.",
	},
	[1426] = { -- Dun Morogh
		"Forjaz está tallada dentro de la montaña: los enanos Barbabronce la construyeron alrededor de la Gran Forja.",
		"Los troggs invadieron Gnomeregan, y los gnomos inundaron su propia ciudad de radiación al intentar sacarlos. Fue idea del mekigeniero Termochufe.",
		"Barbabronce, Hierro Negro y Martillo Salvaje pelearon la Guerra de los Tres Martillos, que partió a los enanos de Khaz Modan.",
	},
	[1427] = { -- Searing Gorge
		"La Garganta de Fuego quedó así por culpa del Hierro Negro: su hechicero-thane Thaurissan invocó a Ragnaros y la tierra se incendió.",
		"La Montaña Roca Negra se alza entre esta garganta y las Estepas Ardientes. Dentro viven los Hierro Negro, Ragnaros y los dragones negros.",
		"La Hermandad del Torio son enanos Hierro Negro que se separaron de su clan. Son maestros herreros y negocian con quien los respete.",
	},
	[1428] = { -- Burning Steppes
		"Las Estepas Ardientes se incendiaron cuando Ragnaros despertó, y sus brasas siguen sin apagarse.",
		"Los orcos Roca Negra de Rend se adueñaron de la cumbre de la montaña y la llaman su hogar.",
		"En lo más alto de la Montaña Roca Negra manda Nefarian, hijo de Alamuerte.",
	},
	[1429] = { -- Elwynn Forest
		"La Horda arrasó Ventormenta en la Primera Guerra. Los albañiles que la reconstruyeron no recibieron su pago, y de ese enojo nació la Hermandad Defias.",
		"La Abadía de Villanorte es de las más antiguas del reino; ahí empiezan su camino muchos aventureros humanos.",
		"Los kóbolds de las minas de Elwynn cuidan sus velas como un tesoro: bajo tierra, la luz lo es todo.",
	},
	[1430] = { -- Deadwind Pass
		"Karazhan, la torre de Medivh, el último Guardián, se levanta sobre un cruce de líneas de magia natural.",
		"Medivh, poseído por Sargeras, abrió el camino para que la Horda llegara a Azeroth.",
		"Medivh era hijo de Aegwynn, la Guardiana anterior. Ella escondió en él el poder del Guardián sin saber que Sargeras también se escondía ahí.",
	},
	[1431] = { -- Duskwood
		"Dicen que el Bosque del Ocaso se oscureció por estar tan cerca de Karazhan, y desde entonces vive en penumbra.",
		"La Guardia Nocturna es la milicia de Villa Oscura: protege el pueblo de lobos, no-muertos y worgen.",
		"Los cementerios del Ocaso están llenos de no-muertos levantados por nigromantes que se esconden en el bosque.",
	},
	[1432] = { -- Loch Modan
		"El lago de Loch Modan existe gracias a una enorme presa enana. Si se rompiera, el agua arrasaría las tierras de abajo.",
		"Las excavaciones de los enanos despertaron a los troggs, y ahora Thelsamar tiene que cuidarse de ellos.",
		"La Liga de Expedicionarios, los arqueólogos de Forjaz, busca por todo el mundo las ruinas que cuenten el origen de los enanos.",
	},
	[1433] = { -- Redridge Mountains
		"Villa del Lago vive con miedo de los orcos Roca Negra que bajan de las montañas, y también de los gnolls.",
		"Al norte de estas montañas están las Estepas Ardientes y la Montaña Roca Negra, de donde salen los orcos que amenazan Villa del Lago.",
	},
	[1434] = { -- Stranglethorn Vale
		"Zul'Gurub fue la capital del imperio Gurubashi. Sus sacerdotes llamaron a Hakkar, el Desollador de Almas, y casi pierden todo.",
		"Bahía del Botín es el puerto del cártel Bonvapor, y ahí manda el barón Revilgaz.",
		"Hemet Nesingwary organiza safaris por toda la Vega: sus encargos de cazar panteras, tigres y raptores son famosos.",
	},
	[1435] = { -- Swamp of Sorrows
		"En este pantano se hundió el Templo de Atal'Hakkar: los dragones verdes lo hundieron para frenar a los sacerdotes de Hakkar.",
		"Rocal es el gran bastión de la Horda en el sur de los Reinos del Este.",
		"Los dragones verdes siguen vigilando el templo hundido para que nadie vuelva a llamar a Hakkar.",
	},
	[1436] = { -- Westfall
		"Los Páramos de Poniente eran el granero de Ventormenta; hoy muchas de sus granjas están en manos de la Hermandad Defias.",
		"Edwin VanCleef, el jefe Defias, era maestro cantero. Cuando la nobleza no pagó la reconstrucción de Ventormenta, juró venganza.",
		"La Milicia Popular de la Colina del Centinela la formaron los propios granjeros cuando Ventormenta dejó de mandar soldados.",
		"Las Minas de la Muerte esconden el refugio de VanCleef... y hasta un barco pirata.",
	},
	[1437] = { -- Wetlands
		"El Puerto de Menethil lleva el apellido de la familia real de Lordaeron. De ahí salen barcos a Theramore y a Auberdine.",
		"Grim Batol fue una ciudad enana. Después, los orcos Faucedraco la usaron para tener presa a Alexstrasza, la Reina Dragón.",
		"Los enanos Hierro Negro tomaron Dun Modr, al norte de Los Humedales, y desde ahí molestan a quien cruce el puente.",
	},
	[1438] = { -- Teldrassil
		"Teldrassil es un árbol del mundo que los elfos de la noche plantaron sin la bendición de los dragones. Por eso no les dio la inmortalidad.",
		"El archidruida Fandral Corzocelada plantó Teldrassil con la esperanza de recuperar la inmortalidad que los elfos perdieron en el Monte Hyjal.",
		"Algo no anda bien en el árbol: los furbolgs que viven en él se están volviendo agresivos.",
	},
	[1439] = { -- Darkshore
		"Auberdine es el puerto de los elfos de la noche: de ahí salen barcos a Teldrassil y a los Reinos del Este.",
		"Costa Oscura está llena de ruinas élficas, como Ameth'Aran, de una época mucho más antigua.",
		"En Costa Oscura la Liga de Expedicionarios desentierra fósiles gigantes.",
	},
	[1440] = { -- Ashenvale
		"En Vallefresno, Grom Grito Infernal mató al semidiós Cenarius cuando la Horda empezó a talar el bosque.",
		"En un cañón de Vallefresno, Grom mató al señor demonio Mannoroth y liberó a los orcos de su sangre maldita.",
		"Las centinelas de Vallefresno pelean sin descanso contra los leñadores orcos de Grito de Guerra.",
	},
	[1441] = { -- Thousand Needles
		"Los tauren de Viento Libre viven en lo alto de las agujas, unidas por puentes colgantes, a salvo de los centauros de abajo.",
		"En el gran salar del este, goblins y gnomos organizan carreras; la rivalidad es feroz.",
	},
	[1442] = { -- Stonetalon Mountains
		"Ventura y Cía. tala y mina la Sierra Espolón sin piedad, y los druidas hacen lo que pueden por detenerla.",
		"El Refugio Roca del Sol es el hogar de los tauren en estas montañas.",
		"En lo alto de la sierra hay un pico sagrado para los druidas elfos, donde anidan aves enormes.",
	},
	[1443] = { -- Desolace
		"Maraudon es sagrado para los centauros: ahí descansa el espíritu de Zaetar, el padre de su raza.",
		"Los clanes Gelkis y Magram de Desolace pelean entre sí, y ambos buscan aliados entre los aventureros.",
		"En el sur de Desolace, demonios y sátiros se reúnen en un aquelarre.",
	},
	[1444] = { -- Feralas
		"La Masacre fue Eldre'Thalas, una ciudad de los elfos Altonato de antes de la Gran División.",
		"En Feralas está uno de los grandes árboles por los que los dragones verdes entran al Sueño Esmeralda.",
		"El Bastión Plumaluna, en una isla frente a la costa, es el puesto de las centinelas élficas.",
	},
	[1445] = { -- Dustwallow Marsh
		"Theramore la fundó Jaina Valiente con los humanos que salieron de Lordaeron antes de su caída.",
		"La guarida de Onyxia está en este marjal. Onyxia, hija de Alamuerte, se hace pasar por una noble humana en Ventormenta.",
		"El almirante Daelin Valiente, padre de Jaina, cayó en Theramore tras atacar a la Horda. Su hija eligió la paz.",
	},
	[1446] = { -- Tanaris
		"Gadgetzan es la ciudad goblin del desierto: ahí todo se compra y todo se vende, hasta el agua.",
		"En Tanaris están las Cavernas del Tiempo, donde el Vuelo Bronce de Nozdormu vigila la historia.",
		"Zul'Farrak es la ciudad de los trols Furiarena, los trols del desierto.",
	},
	[1447] = { -- Azshara
		"Azshara lleva el nombre de la reina de los elfos que abrió la puerta a la Legión Ardiente. Tras la Gran División se convirtió en la reina de los naga.",
		"En la costa se ven ruinas de antiguos palacios élficos, medio hundidos en el mar.",
		"El dragón azul Azuregos ronda Azshara, cuidando la magia antigua que quedó en sus ruinas.",
	},
	[1448] = { -- Felwood
		"Frondavil era parte del bosque de Vallefresno hasta que los demonios y sus sátiros lo corrompieron.",
		"Los furbolgs Fauces de Madera son de los pocos que no se han corrompido; sus túneles llevan a Cuna del Invierno y al Claro de la Luna.",
		"En Jaedenar se esconde el Consejo de la Sombra, brujos que sirven a la Legión Ardiente.",
	},
	[1449] = { -- Un'Goro Crater
		"Los titanes usaron este cráter como un jardín de pruebas para la vida; por eso hay dinosaurios y plantas gigantes.",
		"Todavía quedan pilones de los titanes en el cráter, y funcionan con cristales de colores.",
		"En el centro del cráter humea un volcán donde viven elementales de fuego.",
	},
	[1450] = { -- Moonglade
		"El Claro de la Luna es un santuario de druidas; ahí se reúne el Círculo Cenarion.",
		"En el pueblo de los druidas del Claro de la Luna conviven Alianza y Horda: el Círculo Cenarion recibe a todos.",
		"En el Festival Lunar, la gente viene al Claro de la Luna a honrar a sus ancestros.",
	},
	[1451] = { -- Silithus
		"Silithus es la puerta de Ahn'Qiraj, donde los silítidos y los qiraji sirven al dios antiguo C'Thun.",
		"Hace mil años, en la Guerra de las Arenas Movedizas, los elfos y los dragones encerraron a los qiraji tras el Muro del Escarabajo.",
		"El Martillo Crepuscular tiene campamentos en Silithus, donde intenta invocar a los señores elementales.",
	},
	[1452] = { -- Winterspring
		"Vista Eterna es un pueblo goblin en medio de la nieve: aunque haga frío, el negocio no para.",
		"Mazthoril es la guarida de los dragones azules, siempre atentos a quién usa la magia.",
		"Las centinelas domestican sables de hielo en Cuna del Invierno, y se los confían solo a quien se gana su respeto.",
	},
	[1453] = { -- Stormwind City
		"El rey Varian desapareció camino a una reunión de paz. Mientras tanto reina su hijo Anduin, todavía niño, con el alto señor Bolvar Fordragón como regente.",
		"La Catedral de la Luz es el corazón de la fe en Ventormenta; sus sacerdotes atienden a toda la Alianza.",
		"A la entrada de Ventormenta, estatuas de los grandes héroes de la Segunda Guerra reciben a los visitantes.",
	},
	[1454] = { -- Orgrimmar
		"Orgrimmar lleva el nombre de Orgrim Martillo Maldito, el jefe de guerra que liberó a Thrall y le dejó su armadura y su martillo.",
		"Orgrimmar está tallada en un cañón, y cada pueblo de la Horda tiene su propio valle dentro de la ciudad.",
		"Thrall gobierna la Horda desde Orgrimmar como jefe de guerra, con la mirada puesta en la paz.",
	},
	[1455] = { -- Ironforge
		"La Gran Forja, en el corazón de Forjaz, nunca se apaga.",
		"El rey Magni Barbabronce gobierna Forjaz; sus hermanos son Muradin y Brann, el explorador.",
		"El Tranvía Subterráneo une Forjaz con Ventormenta por debajo de la tierra. Lo construyeron los gnomos.",
	},
	[1456] = { -- Thunder Bluff
		"Cairne Pezuña de Sangre gobierna desde Cima del Trueno, aunque Magatha, de los Tótem Siniestro, no lo quiere tanto como aparenta.",
		"Las mesetas de Cima del Trueno están unidas por puentes, y a la ciudad se sube en elevadores.",
		"En una de las mesetas, los tauren honran a los espíritus de sus ancestros.",
	},
	[1457] = { -- Darnassus
		"Darnassus está en las ramas de Teldrassil. La suma sacerdotisa Tyrande Susurravientos gobierna desde el Templo de la Luna.",
		"Malfurion Tempestira, el gran druida, está perdido en el Sueño Esmeralda, y Tyrande lo espera.",
		"En el Enclave Cenarion los druidas enseñan a los suyos el camino de la naturaleza.",
	},
	[1458] = { -- Undercity
		"Entrañas son las criptas y catacumbas bajo la antigua capital de Lordaeron.",
		"Lady Sylvanas Brisaveloz gobierna a los Renegados. Fue general forestal de Quel'Thalas antes de que Arthas la matara.",
		"La Sociedad Real de Boticarios trabaja en secreto en una plaga nueva... y no precisamente para los humanos solamente.",
	},
	[2482] = { -- Mount Hyjal
		"En la cima del Monte Hyjal crece Nordrassil, el Árbol del Mundo, que los dragones bendijeron.",
		"En la Tercera Guerra, orcos, humanos y elfos se unieron aquí contra Archimonde, y Nordrassil sacrificó su energía para destruirlo.",
		"Diez mil años atrás, Illidan creó en la cima de Hyjal un nuevo Pozo de la Eternidad, y sobre él se plantó Nordrassil.",
	},
}

M.LORE = {
	"La Legión Ardiente es el ejército de demonios de Sargeras, un titán caído que quiere quemar toda la creación.",
	"Los dioses antiguos son seres de antes de los titanes, encerrados bajo la tierra de Azeroth. C'Thun y Yogg-Saron susurran a quien quiera escuchar.",
	"La Plaga es el ejército no-muerto del Rey Exánime. Kel'Thuzad la extendió por Lordaeron con grano infectado.",
	"Los orcos llegaron de Draenor corrompidos por la sangre de Mannoroth. Thrall los sacó de los campos de internamiento y fundó la nueva Horda.",
	"La Alianza nació en la Segunda Guerra, cuando los reinos humanos, los enanos y los altos elfos se unieron contra la Horda.",
	"Los cinco Aspectos Dragón recibieron su poder de los titanes: Alexstrasza la vida, Ysera el sueño, Nozdormu el tiempo, Malygos la magia y Neltharion la tierra.",
	"Neltharion, el Guardián de la Tierra, escuchó los susurros de los dioses antiguos y se convirtió en Alamuerte.",
	"Cuando el Pozo de la Eternidad explotó, el gran continente antiguo se partió en pedazos. A eso le llaman la Gran División.",
	"Los titanes le dieron forma a Azeroth y dejaron guardianes y ciudades, como Uldaman, para cuidar su obra.",
	"Los elfos de la noche fueron inmortales gracias a Nordrassil, hasta que lo sacrificaron para vencer a Archimonde en el Monte Hyjal.",
	"Los Renegados son no-muertos que recuperaron su voluntad cuando el poder del Rey Exánime se debilitó.",
	"La Cruzada Escarlata nació del dolor de Lordaeron tras la plaga, pero su odio la volvió tan cruel como lo que combate.",
}
