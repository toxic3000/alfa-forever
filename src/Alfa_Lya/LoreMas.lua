-- Alfa - Lya: más lore del mundo y más datos de cada zona (toxic3000 / La Jauría). GPL-3.0.
--
-- Notas propias de Alfa (cortas, con nuestras palabras), con su inglés en Textos.lua.
-- Se suman AL FINAL de M.LORE y de cada lista de M.DATOS_ZONA (Lore.lua), así los
-- ids de las que Lya ya contó no se mueven (l<n> y z<mapa>.<n>). Las nuevas, al final.

local ADDON, M = ...

local ipairs = ipairs

local function sumar(lista, nuevas)
	if type(lista) ~= "table" then return end
	for _, t in ipairs(nuevas) do lista[#lista + 1] = t end
end

-- Lore del mundo: la historia de Azeroth hasta el Clásico (y Burning Crusade de contexto).
sumar(M.LORE, {
	-- Titanes, dragones y elementales
	"Los titanes son seres colosales que recorren el cosmos poniendo orden en los mundos. Los más famosos forman el Panteón, que guiaba Aman'Thul.",
	"Sargeras fue el gran campeón del Panteón. De tanto pelear contra demonios concluyó que la creación no tenía remedio, y fundó la Legión Ardiente.",
	"Los titanes dejaron guardianes de piedra y metal en Azeroth. En Uldaman todavía hay uno despierto: Archaedas.",
	"En Uldaman están los Discos de Norgannon, registros de los titanes que cuentan cómo crearon a los terráneos, los antepasados de piedra de los enanos.",
	"Cada Aspecto guía un vuelo de dragones: Alexstrasza el rojo, Ysera el verde, Nozdormu el bronce, Malygos el azul y Neltharion el negro.",
	"Ysera, la Soñadora, cuida el Sueño Esmeralda: un reflejo de Azeroth como sería sin la mano de los mortales.",
	"Nozdormu, el Atemporal, cuida el curso del tiempo. Dicen que conoce el día de su propia muerte, y aun así sigue con su deber.",
	"Malygos, el Tejehechizos, guía a los dragones azules. La traición de Alamuerte casi acaba con su vuelo, y nunca se repuso del todo.",
	"Alamuerte forjó en secreto el Alma de Demonio, un disco dorado cargado con el poder de los demás Aspectos, que se lo dieron sin saber para qué lo quería.",
	"Siglos después, los orcos Faucedraco usaron el Alma de Demonio para tener presa a Alexstrasza y criar dragones de guerra para la Horda.",
	"El mago Rhonin y el dragón Korialstrasz ayudaron a liberar a Alexstrasza en Grim Batol, y ahí quedó destruida el Alma de Demonio.",
	"Korialstrasz, el consorte de Alexstrasza, anduvo entre los mortales como Krasus, un mago del consejo de Dalaran.",
	"Los dragones negros se disfrazan de humanos para engañar: Onyxia es Lady Katrana Prestor en Ventormenta, y Nefarian se hace llamar Lord Victor Nefarius.",
	"Los dragones cromáticos, con escamas de todos los colores, son experimentos de Nefarian. Su obra más temida es Chromaggus.",
	"Alamuerte se hizo pasar por Lord Daval Prestor, un noble que casi llegó a rey de Alterac. ¡A esa familia le encantan los disfraces!",
	"En el Clásico nadie sabe dónde anda Alamuerte; los que dan la cara son sus hijos, Onyxia y Nefarian.",
	"Los señores elementales servían a los dioses antiguos. Cuando los titanes encerraron a esos dioses, desterraron a los elementales a sus propios planos.",
	"Los cuatro señores elementales son Ragnaros del fuego, Al'Akir del aire, Therazane de la tierra y Neptulon del agua.",
	"Los aqir eran un imperio antiguo de insectos que peleó contra los trols. De ellos vienen los qiraji de Ahn'Qiraj y los nerubianos del norte.",
	"El Sueño Esmeralda se está volviendo pesadilla: algo corrompe a los dragones verdes que lo cuidan.",
	"Los cuatro dragones verdes de la pesadilla, Ysondre, Lethon, Emeriss y Taerar, aparecen junto a los grandes árboles del Sueño.",
	"Eranikus, el consorte de Ysera, quedó atrapado en la pesadilla; su sombra ronda el Templo de Atal'Hakkar.",
	"Vaelastrasz, un dragón rojo, está preso de Nefarian en la Guarida Alanegra. Antes de pelear contra ti, te presta su fuerza.",
	"Los infernales son demonios que la Legión arroja desde el cielo como meteoritos.",

	-- Kalimdor antiguo y la Guerra de los Ancestros
	"Hace más de diez mil años todas las tierras eran un solo continente: Kalimdor, que en élfico quiere decir «tierra de la eterna luz de las estrellas».",
	"En el centro de aquel Kalimdor estaba el Pozo de la Eternidad, un lago de pura magia. Unos trols que vivían a su orilla cambiaron con los siglos y se volvieron los elfos de la noche.",
	"Los Altonato eran la nobleza élfica que vivía para la magia del Pozo. Su reina, Azshara, era tan bella que su pueblo la adoraba.",
	"Lord Xavius, el consejero de Azshara, convenció a los Altonato de abrirle la puerta a Sargeras. Cuando murió, Sargeras lo trajo de vuelta como el primer sátiro.",
	"La Guerra de los Ancestros fue la primera invasión de la Legión Ardiente a Azeroth, hace unos diez mil años.",
	"Malfurion Tempestira fue el primer druida de los elfos de la noche. Aprendió del semidiós Cenarius, a quien llamaba shan'do: «maestro honrado».",
	"Illidan, el gemelo de Malfurion, amaba a Tyrande, pero ella eligió a su hermano. Esa herida lo acompañó por diez mil años.",
	"Para cerrarle el paso a la Legión, Malfurion y sus aliados destruyeron el Pozo de la Eternidad. La explosión hundió el centro de Kalimdor.",
	"Donde antes estaba el Pozo de la Eternidad hoy gira el Maelstrom, un remolino eterno en medio del Gran Mar.",
	"Illidan guardó agua del Pozo antes de su caída y creó uno nuevo en Hyjal. Por eso Malfurion lo encerró bajo tierra durante diez mil años.",
	"Maiev Cantosombrío fue la carcelera de Illidan durante diez mil años, al frente de las Vigilantes.",
	"Mientras los druidas dormían en el Sueño Esmeralda, las Centinelas de Tyrande cuidaron solas los bosques de Kalimdor.",
	"Azshara y los Altonato que se hundieron con su palacio no murieron: se transformaron en los naga.",
	"Lady Vashj, que fue dama de compañía de Azshara, ahora guía a sus naga al servicio de Illidan.",
	"Siglos después de la División, los Altonato que no soltaban la magia arcana fueron desterrados. Cruzaron el mar y fundaron Quel'Thalas: son los altos elfos.",
	"Dath'Remar Caminante del Sol guió a los altos elfos hasta Quel'Thalas. De su linaje viene el príncipe Kael'thas.",
	"La Fuente del Sol, el corazón de Quel'Thalas, nació de un frasco de agua del Pozo de la Eternidad que los altos elfos se llevaron.",
	"Elune, la diosa de la luna, es la fe de los elfos de la noche. Sus sacerdotisas son las Hermanas de Elune, y Tyrande es su suma sacerdotisa.",
	"Cenarius, el señor del bosque, es hijo de Malorne, el Ciervo Blanco. Los druidas de la Alianza y de la Horda lo honran por igual.",
	"Las dríades son hijas de Cenarius, y los guardianes de la arboleda, sus hijos.",
	"Los fuegos fatuos son espíritus de elfos de la noche que siguen cuidando el bosque después de morir.",
	"Entre los druidas están los de la Garra, que se vuelven osos, y los del Espolón, que toman forma de cuervo.",
	"Cuando la Legión volvió en la Tercera Guerra, Malfurion y Tyrande hicieron sonar el Cuerno de Cenarius para despertar a los druidas dormidos.",
	"Theradras, la princesa de la tierra, es hija de Therazane. Amó a Zaetar, hijo de Cenarius, y sus hijos, los centauros, terminaron matándolo.",

	-- Los trols
	"Antes que los elfos, los trols tuvieron grandes imperios en Azeroth, como el Amani en el norte y el Gurubashi en el sur.",
	"La tribu Zandalar se considera la primera de todos los trols. Sus sacerdotes acampan en la Isla de Yojamba para frenar a Hakkar.",
	"Los Gurubashi llamaron a Hakkar, el Desollador de Almas. Cuando vieron lo que hacía, las demás tribus se unieron para echarlo.",
	"Los sacerdotes Atal'ai siguieron adorando a Hakkar en secreto. Los desterraron, y levantaron su templo en el Pantano de las Penas.",
	"Los sumos sacerdotes de Zul'Gurub tomaron el poder de los loa animales: el murciélago, la serpiente, la araña, la pantera y el tigre.",
	"Los Amani pelearon contra los altos elfos durante miles de años. Su capital, Zul'Aman, está en los bosques cerca de Quel'Thalas.",
	"Zul'jin, el gran cazador Amani, se unió a la Horda en la Segunda Guerra con un solo deseo: vengarse de los altos elfos.",
	"En las Guerras Trol, los altos elfos enseñaron magia a cien humanos para vencer juntos a los Amani. Fueron los primeros magos de la humanidad.",
	"Con el tiempo, los magos humanos se reunieron en Dalaran, que se volvió la ciudad de la magia de los Reinos del Este.",

	-- Los reinos humanos
	"Tras las Guerras Trol, el viejo Arathor se repartió en siete reinos: Lordaeron, Ventormenta, Gilneas, Alterac, Stromgarde, Kul Tiras y Dalaran.",
	"Antes, el reino de Ventormenta se llamaba Azeroth, igual que el mundo; Ventormenta era solo el nombre de su capital.",
	"Kul Tiras es un reino isleño de marineros. Su gran almirante, Daelin Valiente, era el padre de Jaina.",
	"El rey Llane Wrynn murió en la Primera Guerra a manos de Garona, la espía de la Horda.",
	"Anduin Lothar, el León de Azeroth, llevó a los refugiados de Ventormenta hasta Lordaeron y fue el primer comandante de la Alianza.",
	"Lothar cayó ante Orgrim Martillo Maldito al pie de la Montaña Roca Negra. Turalyon tomó su lugar y ganó la Segunda Guerra.",
	"Turalyon y Alleria Brisaveloz cruzaron el Portal Oscuro tras la guerra para cerrarles el paso a los orcos, y no regresaron.",
	"Terenas Menethil, rey de Lordaeron, unió a los reinos en la Alianza de Lordaeron. Años después, su propio hijo Arthas lo mató en su trono.",
	"Tras la Segunda Guerra, mantener a los orcos en los campos de internamiento costaba una fortuna. Esos impuestos ayudaron a romper la Alianza.",
	"La Mano de Plata, la orden de paladines, la fundó el arzobispo Alonsus Faol, y Uther fue el primero de sus caballeros.",
	"Tirion Vadín fue expulsado de la Mano de Plata por defender a Eitrigg, un orco que le salvó la vida. Hoy Eitrigg aconseja a Thrall en Orgrimmar.",
	"Khadgar fue el aprendiz de Medivh. Al pelear contra su maestro poseído envejeció de golpe y se quedó con el pelo blanco.",
	"Medivh murió a manos de Khadgar y Lothar, pero años después regresó como el misterioso profeta que llevó a Thrall a Kalimdor.",
	"El Portal Oscuro lo abrieron Medivh y Gul'dan juntos, cada uno desde su lado.",
	"Arthas y Jaina se querían antes de que la plaga los separara.",
	"El pequeño rey Anduin Wrynn lleva su nombre en honor a Anduin Lothar, el héroe que salvó a su pueblo.",

	-- Los orcos y las tres guerras
	"Kil'jaeden engañó a Ner'zhul, el chamán más sabio de Draenor, y su aprendiz Gul'dan terminó de entregar a los orcos a la Legión.",
	"Gul'dan fundó el Consejo de la Sombra, un grupo de brujos que movía a la Horda desde las sombras.",
	"La piel verde de los orcos es una huella de la magia vil que usaron sus brujos en Draenor.",
	"Grom Grito Infernal fue el primer jefe orco en beber la sangre de Mannoroth, y así ató a su pueblo a los demonios.",
	"Durotan y su clan Lobo Gélido se negaron a beber la sangre de Mannoroth. Gul'dan nunca se lo perdonó.",
	"Orgrim Martillo Maldito tomó el mando de la Horda y desarmó el Consejo de la Sombra de Gul'dan.",
	"El primer jefe de guerra de la Horda fue Mano Negra. Su hijo Rend Mano Negra hoy sirve a Nefarian en la Cumbre de Roca Negra.",
	"En plena Segunda Guerra, Gul'dan abandonó a la Horda para buscar la Tumba de Sargeras. Ahí lo despedazaron los demonios que encontró.",
	"En la Segunda Guerra, la Horda sumó a los trols Amani, a los ogros y a dragones rojos esclavizados.",
	"Los primeros caballeros de la muerte los creó Gul'dan: cuerpos de caballeros humanos caídos con almas de brujos orcos.",
	"Ner'zhul abrió varios portales en Draenor y la magia desgarró el planeta. Lo que quedó flota en la nada y se llama Terrallende.",
	"Kil'jaeden encerró el alma de Ner'zhul en un bloque de hielo y lo arrojó a Rasganorte: así nació el Rey Exánime.",
	"El Trono Helado es la armadura de hielo donde quedó atrapado Ner'zhul, en lo alto de la Corona de Hielo.",
	"Thrall nació en Draenor, hijo de Durotan y Draka. Aedelas Blackmoore lo encontró de bebé y lo llamó «Thrall», que quiere decir esclavo.",
	"El verdadero nombre de Thrall es Go'el, el que le dieron sus padres.",
	"Taretha Foxton, una muchacha humana de Durnholde, fue la amiga de Thrall y lo ayudó a escapar.",
	"Drek'Thar, el viejo chamán ciego del clan Lobo Gélido, le enseñó a Thrall a hablar con los espíritus. ¡Un sabio de los lobos!",
	"En orco, «Lok'tar ogar» quiere decir «victoria o muerte».",
	"Rexxar, mitad orco y mitad ogro, es un señor de las bestias que ayudó a fundar Durotar. Siempre lo acompaña su osa Misha.",
	"Algunos orcos nunca siguieron a Thrall: los Roca Negra de la montaña sirven a los dragones negros.",
	"La Tercera Guerra empezó con la plaga del grano en Lordaeron y terminó en Hyjal con la caída de Archimonde.",

	-- La Plaga y Arthas
	"Kel'Thuzad era un archimago de Dalaran. Lo expulsaron por estudiar nigromancia y acabó al servicio del Rey Exánime.",
	"El Culto de los Malditos lo fundó Kel'Thuzad: les prometía a los campesinos de Lordaeron una vida eterna y más justa.",
	"Arthas mató a Kel'Thuzad en Andorhal, pero después lo revivió como liche con el poder de la Fuente del Sol.",
	"Para llegar a la Fuente del Sol, la Plaga de Arthas arrasó Quel'Thalas y su capital, Lunargenta.",
	"Arthas tomó la espada Agonía de Escarcha en Rasganorte creyendo que salvaría a su pueblo. La espada le robó el alma.",
	"Antes de buscar la espada, Arthas mandó quemar sus propios barcos para que sus soldados no pudieran volver a casa.",
	"Muradin Barbabronce acompañó a Arthas a Rasganorte. Cuando Arthas tomó la espada, un trozo de hielo golpeó a Muradin y lo dieron por muerto.",
	"Mal'Ganis, el señor del terror, guió la plaga en Lordaeron. Arthas lo persiguió hasta Rasganorte, y esa cacería lo perdió.",
	"Los señores del terror, como Mal'Ganis, Balnazzar y Varimathras, eran los carceleros que la Legión le puso al Rey Exánime.",
	"El gran cruzado de la Cruzada Escarlata, Saidan Dathrohan, es en realidad el demonio Balnazzar. Lo encuentras en Stratholme.",
	"Varimathras sirve a Sylvanas en Entrañas. Es un señor del terror, así que nadie sabe cuánto le va a durar la lealtad.",
	"El Alba Argenta pelea contra la Plaga sin el fanatismo de los Escarlatas, y recibe por igual a la Alianza y a la Horda.",
	"Los gules, las abominaciones y las gárgolas son los soldados más comunes de la Plaga. Las abominaciones se cosen con partes de muchos cadáveres.",
	"Los espíritus de las elfas caídas que la Plaga esclaviza se vuelven banshees. Sylvanas es la más famosa de todas.",
	"Sylvanas tiene dos hermanas: Alleria, que se fue más allá del Portal Oscuro, y Vereesa, que se casó con el mago Rhonin.",
	"Kel'Thuzad tiene un gato, el señor Bigglesworth, que lo acompaña en Naxxramas. ¡Ni se te ocurra hacerle daño!",
	"En Naxxramas, el gran Alexandros Mograine reaparece como uno de los Cuatro Jinetes de la Plaga. Qué triste destino para un héroe.",
	"Sapphiron, el dragón de escarcha de Naxxramas, fue un dragón azul antes de que la Plaga lo levantara.",
	"El barón Osahendido manda en Stratholme como caballero de la muerte de la Plaga.",
	"La familia Barov le entregó su castillo de Caer Darrow al Culto a cambio de vida eterna. Así nació Scholomance, y así les fue.",
	"Los nerubianos, arañas gigantes de Rasganorte, pelearon contra el Rey Exánime y perdieron; muchos hoy le sirven.",

	-- Burning Crusade, como contexto
	"Tyrande liberó a Illidan para pelear contra la Plaga, y Maiev, su carcelera, nunca se lo perdonó.",
	"Illidan absorbió el poder del Cráneo de Gul'dan y se volvió mitad demonio. Por eso Malfurion lo desterró.",
	"Los altos elfos que sobrevivieron a la Plaga empezaron a llamarse elfos de sangre, en honor a los suyos caídos. Kael'thas los guía.",
	"Illidan se fue a Terrallende, lo que quedó de Draenor, y ahí se hizo de un ejército propio.",
	"Los draenei huyeron de su mundo, Argus, con el profeta Velen. Su nombre quiere decir «los exiliados».",
	"Velen, Kil'jaeden y Archimonde guiaban a los eredar. Los dos últimos aceptaron el poder de Sargeras; Velen huyó.",
	"En Burning Crusade, el Vuelo Bronce pide ayuda en las Cavernas del Tiempo contra dragones que quieren cambiar la historia.",

	-- Otros pueblos y criaturas
	"Los goblins vienen de la isla de Kezan, y su gran ciudad es Minahonda. Le son más leales al oro que a cualquier bando.",
	"El cártel Bonvapor controla Bahía del Botín, Trinquete, Gadgetzan y Vista Eterna. Por eso esos puertos reciben a todos.",
	"Los múrlocs hablan con gorgoteos y burbujas: ese «mrglglgl» es su idioma de verdad.",
	"Los furbolgs eran un pueblo pacífico de hombres oso, pero la corrupción de los demonios enloqueció a muchas de sus tribus.",
	"Algunos ogros tienen dos cabezas, y no siempre se ponen de acuerdo entre ellas.",
	"Los worgen son hombres lobo de origen misterioso. Arugal los trajo a Lordaeron. ¡No me confundas con ellos, eh!",
	"Los dracónidos son los soldados de los dragones; los negros sirven a Nefarian en la Montaña Roca Negra.",
	"Los dracoleones son las monturas voladoras de la Horda; los grifos, las de la Alianza; y los hipogrifos, las de los elfos de la noche.",
	"Los Hierro Negro invocaron a Ragnaros sin querer al final de la Guerra de los Tres Martillos, y desde entonces son sus esclavos.",
	"El emperador Dagran Thaurissan gobierna la Ciudad de Hierro Negro, en las Profundidades de Roca Negra.",
	"La princesa Moira, hija de Magni Barbabronce, vive en las Profundidades de Roca Negra como esposa del emperador Thaurissan.",
	"Los últimos Altonato de Kalimdor siguen en La Masacre: se llaman Shen'dralar y cuidan su vieja biblioteca.",
	"Los Renegados entraron a la Horda gracias a los tauren, que esperaban encontrarles una cura. Muchos orcos aún no se fían de ellos.",
	"En el Clásico, la Horda la forman orcos, trols Lanza Negra, tauren y Renegados; la Alianza, humanos, enanos, gnomos y elfos de la noche.",
	"Los elfos de la noche se unieron a la Alianza después de la Tercera Guerra.",
	"En el Clásico mandan Thrall en Orgrimmar, Cairne en Cima del Trueno, Sylvanas en Entrañas y Vol'jin con los Lanza Negra.",
	"Por la Alianza mandan Bolvar como regente en Ventormenta, Magni en Forjaz, Tyrande en Darnassus y Mekkatorque con los gnomos.",
	"La lengua de la Alianza es el común y la de la Horda, el orco. Por eso lo que le dices al otro bando le llega como palabras raras.",

	-- Lugares legendarios
	"Rasganorte es el continente helado del norte. En su centro está la Corona de Hielo, el trono del Rey Exánime.",
	"Las Profundidades de Roca Negra son una ciudad enana entera bajo la montaña: la capital de los Hierro Negro.",
	"El Núcleo de Magma, en el fondo de la Montaña Roca Negra, es el hogar de Ragnaros, el Señor del Fuego.",
	"El general Drakkisath guarda la entrada a la Guarida Alanegra, en lo alto de la Cumbre de Roca Negra.",
	"Azeroth tiene dos continentes en el Clásico: Kalimdor al oeste y los Reinos del Este. En medio está el Gran Mar.",
	"Khaz Modan es la tierra de los enanos, desde las nieves de Dun Morogh hasta los valles de Loch Modan.",

	-- Objetos famosos
	"Atiesh, el Gran Bastón del Guardián, fue de Medivh. En el Clásico se puede rehacer con fragmentos que caen en Naxxramas.",
	"Sulfuras es el martillo de Ragnaros. Con su ojo, los más valientes pueden forjar una versión legendaria.",
	"Para armar la espada legendaria de Thunderaan, el Buscavientos, hacen falta dos ataduras que sueltan Garr y el barón Geddon en el Núcleo de Magma.",
	"Para templar la espada élfica Quel'Serrar hay que dejarla en el piso y que Onyxia le eche su aliento de fuego encima.",
	"El hacha de Grom Grito Infernal tiene nombre propio, y dicen que aúlla cuando corta el aire. ¡Aullar es cosa seria!",

	-- Facciones y reputación
	"Puedes hacerte amigo de los piratas Velasangre matando goblins de Bahía del Botín... aunque luego los guardias goblin te odiarán.",
	"La Liga de Arathor y los Rapiñadores se pelean la Cuenca de Arathi; las Centinelas Ala de Plata y la Escolta Grito de Guerra, la Garganta Grito de Guerra.",
	"En el Valle de Alterac pelean la Guardia Pico Tormenta de los enanos y el clan Lobo Gélido. Yo ya sé a quién le voy.",
	"Si llegas a exaltado con otra raza de tu bando, te venden sus monturas. ¡Un kodo para un orco o un sable de la noche para un humano!",
	"Con buena reputación, los vendedores de esa facción te hacen descuento.",

	-- Curiosidades
	"En el Clásico, el chat de Los Baldíos era famoso por sus pláticas eternas... y por preguntar dónde estaba la esposa de Mankrik.",
	"Leeroy Jenkins se hizo famoso por lanzarse solo, gritando su nombre, a una sala llena de dragoncitos en la Cumbre de Roca Negra.",
	"En la guarida de Onyxia, a los lados hay nidos con huevos: si alguien los pisa salen dragoncitos... muchísimos.",
	"A Ragnaros no le gusta que lo despierten antes de tiempo, y su mayordomo Executus lo paga caro.",
	"Si le haces el gesto de gallina a una gallina de granja muchas veces, a veces te pide ayuda... y la historia termina en mascota.",
	"En Elwynn, una señora vende gatitos de compañía. ¡Yo me llevo bien con los gatos... casi siempre!",
	"En Entrañas venden cucarachas de mascota. Cada quien sus gustos.",
	"Hay nueve clases en el Clásico, pero solo la Alianza tiene paladines y solo la Horda tiene chamanes.",
	"En el Clásico, el rango de honor 14 es Gran Mariscal para la Alianza y Gran Señor de la Guerra para la Horda.",
	"En sus inicios, una batalla del Valle de Alterac podía durar horas... ¡y hasta días!",
	"En el Clásico, las bandas grandes son de 40 jugadores, y Zul'Gurub y las Ruinas de Ahn'Qiraj, de 20.",
	"En el Clásico, abrir las puertas de Ahn'Qiraj pidió un esfuerzo de guerra de todo el servidor: montañas de materiales y una cadena larguísima.",
	"En el Clásico, quienes terminaron la cadena del cetro y tocaron el gong de Ahn'Qiraj ganaron un título y una montura únicos.",
	"En el Clásico, la Plaga invadió el mundo con necrópolis flotantes antes de que se abriera Naxxramas.",
	"En el Clásico, el nivel máximo es 60 y llegar lleva su tiempo. Por eso cada nivel se festeja.",
	"En Warcraft III, si le das muchos clics a una unidad empieza a decir cosas chistosas. Yo, en cambio, te doy consejos.",

	-- Más historia de Azeroth
	"Medivh era hijo de Aegwynn, la Guardiana, y de Nielas Aran, un mago de la corte de Ventormenta.",
	"Hace siglos, Aegwynn venció a un avatar de Sargeras y escondió su cuerpo en la Tumba de Sargeras, en las Islas Abruptas.",
	"Los altos elfos pelearon con la Alianza en la Segunda Guerra por una vieja deuda de sangre con el linaje de Thoradin.",
	"Anasterian, el rey de los altos elfos, dejó la Alianza tras la Segunda Guerra, y murió frente a Arthas defendiendo la Fuente del Sol.",
	"Kael'thas fue miembro del Kirin Tor de Dalaran antes de guiar a los elfos de sangre.",
	"Los Barbabronce ganaron la Guerra de los Tres Martillos, y por eso Forjaz es suya.",
	"Muradin Barbabronce le enseñó a Arthas a pelear cuando el príncipe era joven.",
	"Bolvar Fordragón, hoy regente de Ventormenta, fue paladín de la Mano de Plata.",
	"El rey Varian Wrynn es hijo de Llane, el rey que murió en la Primera Guerra.",
	"Blackmoore le enseñó a Thrall a leer y a pelear para usarlo como arma... y eso terminó volviéndose en su contra.",
	"Thrall liberó a los orcos de los campos de internamiento con la ayuda de Grom Grito Infernal y de Orgrim Martillo Maldito.",
	"Orgrim Martillo Maldito murió peleando junto a Thrall durante la liberación de un campo de internamiento.",
	"En Vallefresno, Grom volvió a beber sangre demoníaca; Thrall lo rescató y Grom pudo redimirse antes de morir.",
	"Cairne Pezuña de Sangre peleó en el Monte Hyjal junto a Thrall contra la Legión.",
	"Al final de la Tercera Guerra, Arthas subió al Trono Helado, se puso el yelmo y se volvió uno con el Rey Exánime.",
	"Los no-muertos de la Plaga no sienten miedo ni cansancio, y por eso es tan difícil detenerlos.",
	"Los dioses antiguos susurran en la mente de los mortales; muchos cultos, como el Martillo Crepuscular, nacieron de escucharlos.",
	"Las Cavernas del Tiempo guardan los momentos más importantes de la historia, y el Vuelo Bronce no deja que nadie los cambie.",
})

-- Por zona (uiMapID).
local Z = M.DATOS_ZONA
sumar(Z[1411], { -- Durotar
	"Cerrotajo es el primer pueblo orco grande que encuentras en Durotar; desde ahí se cuida el camino entre el Valle de los Retos y Orgrimmar.",
	"En la costa de Durotar, soldados de Kul Tiras ocupan el Fuerte Tiragarde: una espina clavada en la tierra de la Horda.",
	"En Durotar ya te topas con el Filo Ardiente, un culto de brujos orcos que sigue adorando a los demonios.",
})
sumar(Z[1412], { -- Mulgore
	"Al pie de Cima del Trueno está el poblado Pezuña de Sangre, donde Baine, el hijo de Cairne, cuida a su gente.",
	"Las Rocas Rojas de Mulgore son un lugar sagrado: ahí descansan los ancestros de los tauren.",
	"En el Clásico, la Feria de la Luna Negra a veces se instala en Mulgore, cerca del poblado Pezuña de Sangre.",
})
sumar(Z[1413], { -- The Barrens
	"Los oasis de Los Baldíos se están secando y llenando de bestias raras: los Druidas del Colmillo, que salieron de las Cuevas de los Lamentos, los corrompen.",
	"Al sur de Los Baldíos, el Gran Elevador baja hasta Las Mil Agujas. ¡No mires hacia abajo!",
	"El Horado Rajacieno y la Zahúrda Rajacieno son guaridas de los jabaespines, entre Los Baldíos y Las Mil Agujas.",
})
sumar(Z[1416], { -- Alterac Mountains
	"Ravenholdt, la mansión de los pícaros, se esconde en las montañas de Alterac. Si no te invitan, ni la buscas.",
	"Por estas montañas se llega al Valle de Alterac, donde la Guardia Pico Tormenta y el clan Lobo Gélido pelean sin descanso.",
})
sumar(Z[1417], { -- Arathi Highlands
	"El Refugio de la Zaga es el campamento de la Alianza en Arathi, entre ruinas, trols y ogros.",
	"La Cuenca de Arathi, el campo de batalla, está en estas tierras: se pelea por la granja, la mina, el aserradero, los establos y la herrería.",
	"La Muralla de Thoradin separa Arathi de las Laderas de Trabalomas; lleva el nombre del rey que unió a los humanos.",
})
sumar(Z[1418], { -- Badlands
	"En el este de las Tierras Inhóspitas viven dragones negros y sus siervos. Pasa lejitos si no llevas compañía.",
	"Los Hierro Negro también excavan en Uldaman, buscando lo mismo que los enanos de Forjaz.",
	"El sol aquí no perdona: las Tierras Inhóspitas son tierra de coyotes, buitres y basiliscos.",
})
sumar(Z[1419], { -- Blasted Lands
	"Lord Kazzak, un demonio enorme, ronda las Tierras Devastadas; en el Clásico es un jefe de mundo para bandas.",
	"El Portal Oscuro está apagado en el Clásico. En Burning Crusade vuelve a abrirse rumbo a Terrallende.",
	"En Nethergarde, unos magos de sangre te cambian partes de las bestias de aquí por elixires que te potencian un buen rato.",
})
sumar(Z[1420], { -- Tirisfal Glades
	"Los Renegados hicieron de Rémol, un viejo pueblo humano, su primera parada en Tirisfal.",
	"En Tirisfal está la entrada al Monasterio Escarlata, uno de los lugares más visitados por los aventureros de nivel medio.",
	"El camino a Entrañas pasa por las ruinas de la Ciudad Capital de Lordaeron, donde Arthas mató a su padre.",
})
sumar(Z[1421], { -- Silverpine Forest
	"En una aldea del sur del bosque, los vecinos parecen normales de día... y de noche se convierten en worgen.",
	"En Molino Ámbar se refugian magos de Dalaran, y no les gustan nada las visitas de los Renegados.",
	"El lago Lordamere separa el Bosque de Argénteos de las Laderas de Trabalomas y de las Montañas de Alterac.",
})
sumar(Z[1422], { -- Western Plaguelands
	"En el norte de estas tierras, la Cruzada Escarlata domina un pueblo amurallado y lo defiende con fanatismo.",
	"En las granjas del oeste hay calderos de la Plaga que siguen esparciendo la peste; la Alianza manda aventureros a destruirlos.",
	"En Caer Darrow, junto al lago, todavía rondan los fantasmas de sus antiguos vecinos.",
})
sumar(Z[1423], { -- Eastern Plaguelands
	"Tirion Vadín, el paladín expulsado de la orden, vive solo en una cabaña de estas tierras.",
	"En el sureste, la Mano de Tyr es la ciudad más fuerte que le queda a la Cruzada Escarlata.",
})
sumar(Z[1424], { -- Hillsbrad Foothills
	"En el Clásico, Costasur contra Molino Tarren era la pelea entre bandos más famosa del mundo.",
	"En Burning Crusade, las Cavernas del Tiempo te regresan a estas laderas para ver la huida de Thrall de Durnholde.",
	"Las misiones de Molino Tarren mandan a la Horda contra las granjas humanas de las laderas.",
})
sumar(Z[1425], { -- The Hinterlands
	"Unos pocos altos elfos siguen con la Alianza; viven en Quel'Danil, en las Tierras del Interior.",
	"En la costa este vive una tribu trol amiga de la Horda, enemiga de los trols de Jintha'Alor.",
	"En Pico Nidal manda el thane Falstad Martillo Salvaje, señor de los jinetes de grifo.",
})
sumar(Z[1426], { -- Dun Morogh
	"En Kharanos, la posada y la destilería Cebatruenos son la parada obligada para calentarse... por dentro y por fuera.",
	"En las cuevas nevadas de Dun Morogh viven trols de las nieves que no quieren a los enanos ni tantito.",
	"Cerca de Gnomeregan verás gnomos leprosos: los que se quedaron atrás cuando la radiación llenó su ciudad.",
})
sumar(Z[1427], { -- Searing Gorge
	"En el centro de la garganta hay un enorme pozo de lava, la Caldera, donde trabajan esclavos de los Hierro Negro.",
	"Punta de Torio es el campamento de la Hermandad del Torio, y ahí se juntan Alianza y Horda para hacer negocios.",
	"Los elementales de fuego y las arañas de lava son los vecinos de siempre de La Garganta de Fuego.",
})
sumar(Z[1428], { -- Burning Steppes
	"El Vigía de Morgan es el puesto de la Alianza en las estepas, desde donde vigilan la Montaña Roca Negra.",
	"En estas tierras cayó Anduin Lothar, el León de Azeroth, durante la Segunda Guerra.",
	"La Cresta de la Llama es el puesto de la Horda en las estepas, en lo alto de las rocas.",
})
sumar(Z[1429], { -- Elwynn Forest
	"En el Clásico, la Feria de la Luna Negra a veces se instala junto a Villadorada.",
	"Hogger es un gnoll de Elwynn tan temido que, para muchos aventureros, fue su primer gran reto.",
	"La Torre de Azora, en el este de Elwynn, es la casa de Theocritus, un mago al servicio del reino.",
})
sumar(Z[1430], { -- Deadwind Pass
	"El Paso de la Muerte no tiene ni un pueblo: solo ogros, bestias y la sombra de Karazhan.",
	"En Burning Crusade, Karazhan abre sus puertas como banda.",
	"Este paso une el Bosque del Ocaso con el Pantano de las Penas, y casi todos lo cruzan sin detenerse.",
})
sumar(Z[1431], { -- Duskwood
	"Costuras, una abominación enorme, ataca Villa Oscura en una de las misiones más famosas del bosque.",
	"El viejo ermitaño Abercrombie parece amable... hasta que descubres a quién intenta revivir.",
	"Uno de los dragones verdes de la pesadilla aparece en el Bosque del Ocaso, junto a un gran árbol.",
})
sumar(Z[1432], { -- Loch Modan
	"En el este del lago viven ogros que les hacen la vida difícil a los enanos de Thelsamar.",
	"En la excavación de Ironband, los troggs salieron de la tierra y se quedaron con todo.",
	"¡En Thelsamar venden morcilla! La morcilla de Thelsamar es casi una salchicha... ¿me compras una?",
})
sumar(Z[1433], { -- Redridge Mountains
	"Villa del Lago tiene un puente roto que la gente quiere reconstruir, si alguien le echa la mano.",
	"Los orcos Roca Negra ocupan una vieja fortaleza humana al este de las montañas.",
	"En el lago de Villa del Lago hay múrlocs, ¡como en casi todo lago de Azeroth!",
	"Las Montañas Crestagrana deben su nombre a sus rocas rojizas.",
})
sumar(Z[1434], { -- Stranglethorn Vale
	"Grom'gol es el campamento de la Horda en la Vega, con zepelines a Orgrimmar y a Entrañas.",
	"En la Vega se encuentran páginas sueltas de un libro de Nesingwary; junta un capítulo completo y llévaselo.",
	"En la Arena Gurubashi aparece de vez en cuando un cofre que todos se pelean. ¡Sálvese quien pueda!",
})
sumar(Z[1435], { -- Swamp of Sorrows
	"Los Perdidos del pantano son draenei que llegaron de Draenor y quedaron cambiados para siempre.",
	"En la costa del pantano hay naga, y no reciben bien a los curiosos.",
	"Si sigues la historia del Templo Sumergido, en el pantano te espera Itharius, un dragón verde.",
})
sumar(Z[1436], { -- Westfall
	"En la granja de los Saldean, la vieja yegua Blanchy necesita avena. Es de las misiones más tiernitas de los Páramos.",
	"Los Defias usan cosechadores mecánicos que trabajan solos en los campos... y no les gustan las visitas.",
})
sumar(Z[1437], { -- Wetlands
	"Dun Algaz es el túnel enano que une Los Humedales con Loch Modan.",
	"Los orcos Faucedraco siguen en Los Humedales, aunque ya sin la Reina Dragón.",
	"El Puente Thandol, al norte, une Khaz Modan con Arathi; los Hierro Negro lo dejaron medio destruido.",
})
sumar(Z[1438], { -- Teldrassil
	"Dolanaar es la aldea élfica en el camino a Darnassus; su posada huele a bosque.",
	"Rut'theran es el muelle al pie del árbol; de ahí un portal te sube a Darnassus.",
	"Teldrassil es tan grande que entre sus ramas hay colinas, lagos y cuevas.",
})
sumar(Z[1439], { -- Darkshore
	"Los furbolgs de Costa Oscura se están corrompiendo, y los elfos de Auberdine no saben bien por qué.",
	"En Costa Oscura viven lechúcicos, criaturas mitad búho y mitad oso que veneran la luna.",
	"Por Costa Oscura anda un explorador de la Liga muy despistado, que siempre necesita que alguien le eche la mano.",
})
sumar(Z[1440], { -- Ashenvale
	"Astranaar es el pueblo élfico en medio de Vallefresno, en una isla del lago.",
	"El Puesto Hachazo es el campamento de la Horda que tala Vallefresno.",
	"En la costa oeste de Vallefresno, las Cavernas de Brazanegra fueron un templo de Elune; hoy están hundidas y llenas de naga.",
})
sumar(Z[1441], { -- Thousand Needles
	"Si bajas por el Gran Elevador, verás por qué se llama así: cientos de agujas de roca.",
	"En el oeste de Las Mil Agujas anidan dracoleones salvajes.",
	"Los tauren Tótem Siniestro tienen campamentos en Las Mil Agujas, y no son nada amigables.",
})
sumar(Z[1442], { -- Stonetalon Mountains
	"El Valle Calcinado, al sur de la sierra, quedó quemado y lleno de elementales de fuego.",
	"El camino que baja de la sierra hacia Los Baldíos está lleno de arañas. ¡Brrr!",
	"Ventura y Cía. trae máquinas enormes para talar los árboles más viejos de la sierra.",
})
sumar(Z[1443], { -- Desolace
	"En Desolace está el cementerio de los kodos, donde los viejos kodos van a morir.",
	"Rexxar, el señor de las bestias, recorre los caminos de Desolace con su osa Misha.",
	"La Horda tiene una aldea en la costa de Desolace, y la Alianza un campamento en las montañas del norte.",
})
sumar(Z[1444], { -- Feralas
	"El Campamento Mojache es el hogar de la Horda en Feralas.",
	"Por la selva de Feralas caminan gigantes enormes. ¡Cuidado con sus pisadas!",
	"En las cuevas de Feralas viven yetis, y los ogros Gordunni tienen sus campamentos en el norte.",
})
sumar(Z[1445], { -- Dustwallow Marsh
	"La Horda tiene su propio pueblo al norte del marjal, para vigilar Theramore de cerca.",
	"Nat Pagle, el pescador más famoso, vive en una isla del marjal; sus misiones son para pescadores pacientes.",
	"Los dracónidos negros rondan la entrada de la guarida de Onyxia, al sur del marjal.",
})
sumar(Z[1446], { -- Tanaris
	"Gadgetzan tiene una de las casas de subastas neutrales, donde comercian Alianza y Horda.",
	"En la costa de Tanaris se esconden piratas de los Mares del Sur.",
	"En el sur de Tanaris hay colmenas de silítidos, primos de los de Silithus.",
})
sumar(Z[1447], { -- Azshara
	"En una isla de Azshara vive el duque Hydraxis, señor del agua; su gente te ayuda a apagar las runas del Núcleo de Magma.",
	"Las ruinas de Eldarath fueron una ciudad élfica; hoy están llenas de naga.",
	"Los sátiros de Azshara sueltan tela vil, muy buscada por los sastres.",
})
sumar(Z[1448], { -- Felwood
	"En el Santuario Esmeralda, los druidas intentan sanar el bosque enfermo.",
	"Las flores cantoras corrompidas de Frondavil se pueden purificar; al hacerlo te dan una bendición que dura un buen rato.",
	"En un valle de Frondavil cayeron infernales del cielo, y todavía se ven sus cráteres.",
})
sumar(Z[1449], { -- Un'Goro Crater
	"El Refugio del Mariscal es el único campamento del cráter, y lo comparten todos.",
	"En el cráter, un tal Linken perdió la memoria y busca su espada y su escudo: un guiño a cierto héroe de orejas puntiagudas.",
	"El demosaurio es el gran depredador del cráter: si oyes pasos que retumban, escóndete.",
})
sumar(Z[1450], { -- Moonglade
	"El Guardián Remulos, hijo de Cenarius, cuida el Claro de la Luna desde su santuario.",
	"El lago del Claro de la Luna se llama Elune'ara, en honor a la diosa de la luna.",
	"Si no eres druida, al Claro de la Luna se llega por los túneles de los Fauces de Madera, desde Frondavil.",
})
sumar(Z[1451], { -- Silithus
	"El Fuerte Cenarion es la base del Círculo Cenarion en Silithus, frente a los qiraji.",
	"Los cultistas del Martillo Crepuscular usan piedras de viento para invocar a sus señores; con su disfraz, tú también puedes.",
	"En el Clásico, el Cetro de las Arenas Movedizas abrió las puertas de Ahn'Qiraj tras una larguísima cadena de misiones.",
	"En la Guerra de las Arenas Movedizas, el archidruida Fandral perdió a su hijo Valstann a manos de los qiraji.",
})
sumar(Z[1452], { -- Winterspring
	"En las cuevas de Cuna del Invierno viven yetis peludos y gruñones.",
	"Al sur de Cuna del Invierno, una garganta escondida está llena de demonios.",
	"El lago helado de Kel'Theril guarda ruinas de los Altonato.",
	"Vista Eterna tiene casa de subastas neutral, ideal para comerciar con el otro bando.",
})
sumar(Z[1453], { -- Stormwind City
	"Ventormenta está cruzada por canales; los puentes unen sus barrios.",
	"En las Mazmorras de Ventormenta los presos se amotinaron, y la guardia pide ayuda para calmar el desastre.",
	"En el Casco Antiguo está el SI:7, los espías y pícaros al servicio del reino.",
})
sumar(Z[1454], { -- Orgrimmar
	"La Sima Ígnea está bajo Orgrimmar: ahí se esconden brujos de un culto junto con troggs.",
	"En la Fortaleza de Grommash, Thrall recibe a quien venga; muy cerca está Eitrigg, el viejo orco amigo de Tirion.",
	"En el Valle de la Fuerza están el banco y la casa de subastas: el corazón del comercio de la Horda.",
})
sumar(Z[1455], { -- Ironforge
	"En Ciudad Manitas, dentro de Forjaz, viven los gnomos que escaparon de Gnomeregan.",
	"En la sala de la Liga de Expedicionarios de Forjaz hay biblioteca, mapas y un museo con fósiles gigantes.",
	"En el Clásico, la casa de subastas de Forjaz es la más movida de toda la Alianza.",
})
sumar(Z[1456], { -- Thunder Bluff
	"Cada meseta de Cima del Trueno tiene su función: una para los ancianos y los druidas, otra para los espíritus y otra para los cazadores.",
	"En las Pozas de la Visión, bajo una de las mesetas, entrenan los magos y sacerdotes Renegados.",
	"El archidruida Hamuul Tótem de Runa enseña a los druidas tauren, y fue de los primeros tauren aceptados en el Círculo Cenarion.",
})
sumar(Z[1457], { -- Darnassus
	"En el corazón del Templo de la Luna hay un pozo lunar, donde las sacerdotisas rezan a Elune.",
	"El archidruida Fandral Corzocelada enseña en el Enclave Cenarion de Darnassus.",
	"En la Terraza de los Artesanos de Darnassus están los maestros de profesiones.",
})
sumar(Z[1458], { -- Undercity
	"Sylvanas recibe en el Barrio Real de Entrañas, con Varimathras a su lado.",
	"Por los canales de Entrañas corre una baba verde que mejor ni probar.",
	"Entrañas tiene barrios para magos, pícaros, guerreros y boticarios, y en el anillo central están el banco y la casa de subastas.",
})
sumar(Z[2482], { -- Mount Hyjal
	"En la batalla de Hyjal, Malfurion hizo sonar el Cuerno de Cenarius y miles de fuegos fatuos rodearon a Archimonde hasta destruirlo.",
	"Archimonde subió a Hyjal para robar la energía del Árbol del Mundo; en vez de eso, el árbol fue su final.",
})
