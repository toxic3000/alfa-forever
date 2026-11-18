-- Alfa - Combate: prioridades propias por clase y especialización (toxic3000 / La Jauría). GPL-3.0.
--
-- Forever trae apagada la ayuda de combate de Blizzard, así que Alfa sugiere
-- con estas listas, leídas solo con datos de tu personaje (Prioridad.lua).
-- Datos propios de Alfa. Las 9 clases de Forever con sus 3 especializaciones
-- (las mismas claves que usa el motor para tus talentos: Gear/SpecData).
--
-- Cada entrada: id (cualquier rango: vale el más alto que conozcas, por su
-- nombre, así que la lista crece contigo al subir de nivel), porque (la razón
-- larga, en la página) y sus condiciones:
--   sinBuff = true | ids     te falta ese efecto (o todos esos)
--   conBuff = ids            tienes alguno de esos efectos (un proc: Claridad, Trance...)
--   sinDebuff = true | ids   el enemigo no tiene tu efecto (si se puede leer; si no, `cada`)
--   cada = s, veces = n      lo pusiste en este objetivo hace menos de s segundos (n veces)
--   conDebuff = { id, cada } el enemigo tiene ese efecto tuyo (o lo pusiste hace menos de cada)
--   minPoder / maxPoder      tu recurso de ahora (ira, energía o maná), en puntos
--   poder = "ira" | "energia" | "mana"   tu recurso de ahora (las formas del druida)
--   minPct / maxPct          tu maná, en porcentaje
--   minCombo / maxCombo      tus puntos de combo
--   sinArma = true           tu arma no tiene encantamiento temporal
--   aoe = true               con 3 o más enemigos a la vista; minEnemigos = n: con n o más
--   solo = true              solo con menos de 3
--   sinObjetivo = true       no hace falta un enemigo elegido
--   soloCombate / fueraCombate
--   remate = true            habilidad para enemigos casi muertos (el juego decide cuándo)
--   bajoVida = %             la vida del enemigo es de ese % o menos (si es secreta: no)
--   sobreVida = %            no si al enemigo le queda menos de eso (si es secreta: sí)
--   vidaPropia = %           tu vida es de ese % o menos; minVidaPropia = %: al menos eso
--   vidaMascota = %          la vida de tu mascota es de ese % o menos
--   sinMascota / conMascota  no tienes mascota / la tienes
--   corta = true             el enemigo lanza algo que se puede interrumpir (si se puede leer)
--   tipoObjetivo = { ids }   el tipo de criatura (3 demonio, 6 no-muerto)
--   enGrupo = true | false   solo en grupo / solo sin grupo
--   minNivel / maxNivel      tu nivel
--   recarga = true           tiene recarga propia (el porqué dice "recarga lista")
--   unico = "grupo"          de un mismo grupo solo sale la primera que pase
--   reaccion = true          se habilita por algo que pasó (una esquiva, un bloqueo)
-- Lo que el juego ya sabe (actitud, forma, arma, alcance, Ejecutar bajo el
-- 20 %, Abrumar tras una esquiva) lo resuelve C_Spell.IsSpellUsable: no se
-- repite aquí. Si el juego hace brillar una habilidad (un efecto la activó),
-- pasa al frente sola.
-- Cómo se elige la especialización: la que elijas en los ajustes; si no, la
-- de tus talentos (el motor cuenta tus puntos); si no, la primera cuya firma
-- conoces; si no, la de tu clase al subir de nivel.

local ADDON, M = ...
local L = M.L

local function e(id, porque, o)
	o = o or {}
	o.id, o.porque = id, porque
	return o
end

---------------------------------------------------------------------------
-- Guerrero
---------------------------------------------------------------------------
local W_GRITO = e(6673, L["Te falta Grito de batalla: más poder de ataque para ti y tu grupo."], { sinBuff = true, sinObjetivo = true })
local W_CARGA = e(100, L["Abre la pelea: te acerca al enemigo y te da ira."])
local W_VICTORIA = e(402927, L["Gratis tras vencer a un enemigo, y te cura."], { reaccion = true })
local W_EJECUTAR = e(5308, L["Al enemigo le queda poca vida: remátalo."], { remate = true })
local W_ABRUMAR = e(7384, L["El enemigo esquivó: Abrumar no se puede esquivar y pega fuerte."], { reaccion = true })
local W_PATADA = e(6552, L["El enemigo está lanzando un hechizo: córtalo."], { corta = true })
local W_ESCUDO = e(72, L["El enemigo está lanzando un hechizo: córtalo con tu escudo."], { corta = true })
local W_DESGARRAR = e(772, L["Hace sangrar al enemigo: ponlo al empezar la pelea."], { sinDebuff = true, cada = 15, solo = true, sobreVida = 30 })
local W_ATRONAR = e(6343, L["Golpea y frena a todos los enemigos que tienes cerca."], { aoe = true, sinObjetivo = true })
local W_DESMORALIZAR = e(1160, L["Los enemigos de alrededor pegan menos."], { minEnemigos = 2, sinDebuff = true, cada = 30, sinObjetivo = true })
local W_MELLAR = e(845, L["Te sobra ira y hay varios enemigos: tu siguiente golpe alcanza a dos."], { minEnemigos = 2, minPoder = 30 })
local W_SANGRE = e(2687, L["Te falta ira: Ira sangrienta te la da gratis."], { maxPoder = 15, soloCombate = true, sinObjetivo = true })

---------------------------------------------------------------------------
-- Pícaro
---------------------------------------------------------------------------
local R_PATADA = e(1766, L["El enemigo está lanzando un hechizo: córtalo."], { corta = true })
local R_RIPOSTE = e(14251, L["Paraste un golpe: el contraataque está listo."], { reaccion = true })
local R_HACHA = e(5171, L["Más velocidad de ataque: mantenlo puesto."], { sinBuff = true, minCombo = 1, soloCombate = true })
local R_EVISC = e(2098, L["Tienes 5 puntos de combo: el remate más fuerte."], { minCombo = 5, minNivel = 20 })
local R_EVISC_BAJO = e(2098, L["A tu nivel los enemigos caen rápido: remata con 3 puntos de combo."], { minCombo = 3, maxNivel = 19 })
local R_SINIESTRO = e(1752, L["Golpe siniestro: suma puntos de combo."])
local R_PUNALADA = e(53, L["Estás en grupo y otro aguanta al enemigo: apuñálalo por la espalda."], { enGrupo = true })
local R_ROMPER = e(1943, L["Hace sangrar mucho: vale la pena con enemigos que duran."], { minCombo = 4, enGrupo = true, sinDebuff = true, cada = 12, sobreVida = 40 })

---------------------------------------------------------------------------
-- Mago
---------------------------------------------------------------------------
local MG_ARMADURAS = { 6117, 7302, 168 }
local MG_INTELECTO = e(1459, L["Te falta Intelecto Arcano: más maná."], { sinBuff = true, sinObjetivo = true })
local MG_ARMADURA_MAGO = e(6117, L["Te falta tu armadura: ponte una."], { sinBuff = MG_ARMADURAS, sinObjetivo = true, unico = "armadura" })
local MG_ARMADURA_HIELO = e(7302, L["Te falta tu armadura: ponte una."], { sinBuff = MG_ARMADURAS, sinObjetivo = true, unico = "armadura" })
local MG_ARMADURA_ESCARCHA = e(168, L["Te falta tu armadura: ponte una."], { sinBuff = MG_ARMADURAS, sinObjetivo = true, unico = "armadura" })
local MG_CONTRA = e(2139, L["El enemigo está lanzando un hechizo: córtalo."], { corta = true })
local MG_EVOCACION = e(12051, L["Te queda muy poco maná: Evocación lo recupera."], { maxPct = 15, soloCombate = true, sinObjetivo = true })
local MG_EXPLOSION = e(1449, L["Varios enemigos cerca: golpéalos a todos a la vez."], { aoe = true, sinObjetivo = true })
local MG_DEFLAGRAR = e(2136, L["Instantánea: úsala cada vez que esté lista."], { recarga = true })
local MG_ESCARCHA = e(116, L["Tu hechizo principal: daño y frena al enemigo."])
local MG_FUEGO = e(133, L["Tu hechizo principal de fuego."])
local MG_VARITA = e(5019, L["Te queda poco maná: usa tu varita."], { maxPct = 20 })

---------------------------------------------------------------------------
-- Brujo
---------------------------------------------------------------------------
local B_ARMADURAS = { 706, 687 }
local B_ARMADURA = e(706, L["Te falta tu armadura demoníaca."], { sinBuff = B_ARMADURAS, sinObjetivo = true, unico = "armadura" })
local B_PIEL = e(687, L["Te falta tu armadura demoníaca."], { sinBuff = B_ARMADURAS, sinObjetivo = true, unico = "armadura" })
local B_ABISARIO = e(697, L["No tienes demonio: el abisario aguanta los golpes por ti."], { sinMascota = true, fueraCombate = true, sinObjetivo = true, unico = "demonio" })
local B_DIABLILLO = e(688, L["No tienes demonio: invoca uno antes de pelear."], { sinMascota = true, fueraCombate = true, sinObjetivo = true, unico = "demonio" })
local B_TRANCE = e(686, L["Se activó Trance de las Sombras: tu Descarga de las Sombras es instantánea."], { conBuff = { 17941 } })
local B_CORRUPCION = e(172, L["Daño con el tiempo: ponla al empezar la pelea."], { sinDebuff = true, cada = 18, sobreVida = 20 })
local B_AGONIA = e(980, L["Maldición que hace cada vez más daño."], { sinDebuff = true, cada = 24, sobreVida = 25 })
local B_INMOLAR = e(348, L["Quema al enemigo un rato."], { sinDebuff = true, cada = 15, sobreVida = 30 })
local B_DRENAR_ALMA = e(1120, L["El enemigo está por caer: drénale el alma y gana un fragmento."], { bajoVida = 25 })
local B_DRENAR_VIDA = e(689, L["Tu vida está baja: róbasela al enemigo."], { vidaPropia = 50 })
local B_TRANSFUSION = e(1454, L["Te queda poco maná y te sobra vida: cambia vida por maná."], { maxPct = 25, minVidaPropia = 50, sinObjetivo = true })
local B_SOMBRAS = e(686, L["Tu hechizo principal."])
local B_LLUVIA = e(5740, L["Varios enemigos juntos: lluvia de fuego sobre ellos."], { aoe = true })
local B_VARITA = e(5019, L["Te queda poco maná: usa tu varita."], { maxPct = 15 })

---------------------------------------------------------------------------
-- Sacerdote
---------------------------------------------------------------------------
local S_ENTEREZA = e(1243, L["Te falta Palabra de poder: entereza: más vida."], { sinBuff = true, sinObjetivo = true })
local S_FUEGO_INTERIOR = e(588, L["Te falta Fuego interior: más armadura."], { sinBuff = true, sinObjetivo = true })
local S_ESCUDO = e(17, L["Tu vida baja: el escudo absorbe el daño."], { sinBuff = { 17, 6788 }, vidaPropia = 80, soloCombate = true, sinObjetivo = true })
local S_RENOVAR = e(139, L["Tu vida baja: Renovar te cura poco a poco."], { sinBuff = true, vidaPropia = 60, soloCombate = true, sinObjetivo = true })
local S_SANAR = e(2061, L["Tu vida está muy baja: cúrate rápido."], { vidaPropia = 35, sinObjetivo = true, unico = "curar" })
local S_SANAR_MENOR = e(2050, L["Tu vida está muy baja: cúrate rápido."], { vidaPropia = 35, sinObjetivo = true, unico = "curar" })
local S_DOLOR = e(589, L["Daño con el tiempo: ponla al empezar la pelea."], { sinDebuff = true, cada = 18, sobreVida = 25 })
local S_MENTAL = e(8092, L["Golpe mental: mucho daño, cada vez que esté listo."], { recarga = true })
local S_PLAGA = e(2944, L["Plaga devoradora: daño fuerte con el tiempo, cada vez que esté lista."], { recarga = true, sobreVida = 30 })
local S_TORTURA = e(15407, L["Tortura mental: daño constante y frena al enemigo."])
local S_CASTIGO = e(585, L["Tu hechizo principal."])
local S_FUEGO_SAGRADO = e(14914, L["Fuego sagrado: abre la pelea con mucho daño."], { recarga = true })
local S_VARITA = e(5019, L["Te queda poco maná: usa tu varita."], { maxPct = 25 })

---------------------------------------------------------------------------
-- Cazador
---------------------------------------------------------------------------
local H_ASPECTOS = { 13165, 13163, 5118, 13159 }
local H_HALCON = e(13165, L["Te falta un aspecto: el del halcón da más poder a distancia."], { sinBuff = H_ASPECTOS, sinObjetivo = true, unico = "aspecto" })
local H_MONO = e(13163, L["Te falta un aspecto: el del mono te ayuda a esquivar."], { sinBuff = H_ASPECTOS, sinObjetivo = true, unico = "aspecto" })
local H_LLAMAR = e(883, L["No tienes mascota: llámala."], { sinMascota = true, sinObjetivo = true, unico = "mascota" })
local H_REVIVIR = e(982, L["No tienes mascota: si murió, revívela."], { sinMascota = true, fueraCombate = true, sinObjetivo = true, unico = "mascota" })
local H_ALIVIAR = e(136, L["Tu mascota tiene poca vida: cúrala."], { vidaMascota = 40, conMascota = true, sinObjetivo = true })
local H_MARCA = e(1130, L["Marca al enemigo: todos le pegan más."], { sinDebuff = true, cada = 120, sobreVida = 40 })
local H_SERPIENTE = e(1978, L["Picadura de serpiente: daño con el tiempo."], { sinDebuff = true, cada = 15, sobreVida = 30 })
local H_ARCANO = e(3044, L["Disparo arcano: instantáneo, úsalo cuando esté listo."], { recarga = true })
local H_MULTI = e(2643, L["Varios enemigos: el disparo alcanza a varios."], { minEnemigos = 2, recarga = true })
local H_RAPIDO = e(3045, L["Fuego rápido: disparas mucho más rápido un rato."], { soloCombate = true, sinObjetivo = true, recarga = true })
local H_MANGOSTA = e(1495, L["El enemigo esquivó: este golpe está listo."], { reaccion = true })
local H_RAPAZ = e(2973, L["El enemigo está encima: golpéalo cuerpo a cuerpo."])

---------------------------------------------------------------------------
-- Paladín
---------------------------------------------------------------------------
local P_BENDICIONES = { 19740, 19742, 20911, 20217 }
local P_SELLOS = { 21084, 20154, 20375, 21082, 20164, 20165, 20166 }
local P_PODERIO = e(19740, L["Te falta una bendición: Poderío da más poder de ataque."], { sinBuff = P_BENDICIONES, sinObjetivo = true, unico = "bendicion" })
local P_SABIDURIA = e(19742, L["Te falta una bendición: Sabiduría te devuelve maná."], { sinBuff = P_BENDICIONES, sinObjetivo = true, unico = "bendicion" })
local P_SANTUARIO = e(20911, L["Te falta una bendición: Santuario reduce el daño que recibes."], { sinBuff = P_BENDICIONES, sinObjetivo = true, unico = "bendicion" })
local P_MANDO = e(20375, L["No tienes un sello puesto: ponte uno."], { sinBuff = P_SELLOS, sinObjetivo = true, unico = "sello" })
local P_RECTITUD = e(21084, L["No tienes un sello puesto: ponte uno."], { sinBuff = P_SELLOS, sinObjetivo = true, unico = "sello" })
local P_RECTITUD2 = e(20154, L["No tienes un sello puesto: ponte uno."], { sinBuff = P_SELLOS, sinObjetivo = true, unico = "sello" })
local P_SENTENCIA = e(20271, L["Libera tu sello en el enemigo: daño extra."], { conBuff = P_SELLOS, recarga = true })
local P_COLERA = e(24275, L["Al enemigo le queda poca vida: remátalo."], { remate = true })
local P_EXORCISMO = e(879, L["Contra no-muertos y demonios: Exorcismo pega muy fuerte."], { tipoObjetivo = { 3, 6 }, recarga = true })
local P_CONSAGRAR = e(26573, L["Varios enemigos: consagra el suelo bajo ti."], { aoe = true, sinObjetivo = true })
local P_JUSTICIA = e(853, L["El enemigo está lanzando un hechizo: aturdirlo lo corta."], { corta = true })
local P_IMPOSICION = e(633, L["Tu vida está a punto de acabarse: Imposición de manos te cura entero."], { vidaPropia = 15, soloCombate = true, sinObjetivo = true })
local P_DESTELLO = e(19750, L["Tu vida está baja: cúrate rápido."], { vidaPropia = 40, sinObjetivo = true, unico = "curar" })
local P_LUZ = e(635, L["Tu vida está baja: cúrate."], { vidaPropia = 40, sinObjetivo = true, unico = "curar" })

---------------------------------------------------------------------------
-- Chamán
---------------------------------------------------------------------------
local C_RELAMPAGOS = e(324, L["Te falta Escudo de relámpagos."], { sinBuff = true, sinObjetivo = true })
local C_VIENTO = e(8232, L["Tu arma no tiene encantamiento: Viento furioso."], { sinArma = true, sinObjetivo = true, unico = "arma" })
local C_LENGUA = e(8024, L["Tu arma no tiene encantamiento: Lengua de fuego."], { sinArma = true, sinObjetivo = true, unico = "arma" })
local C_MUERDE = e(8017, L["Tu arma no tiene encantamiento: Muerdepiedras."], { sinArma = true, sinObjetivo = true, unico = "arma" })
local C_CORTE = e(8042, L["El enemigo está lanzando un hechizo: Choque de tierra lo corta."], { corta = true })
local C_LLAMA = e(8050, L["Daño de fuego con el tiempo."], { sinDebuff = true, cada = 12, solo = true, sobreVida = 30 })
local C_TIERRA = e(8042, L["Choque: daño instantáneo."], { recarga = true })
local C_ABRASADOR = e(3599, L["Pon tu tótem abrasador: dispara al enemigo por ti."], { cada = 30, soloCombate = true })
local C_MAGMA = e(8190, L["Varios enemigos cerca: el tótem de magma los quema a todos."], { aoe = true, cada = 20, soloCombate = true, sinObjetivo = true })
local C_CADENA = e(421, L["Varios enemigos: el rayo salta entre ellos."], { minEnemigos = 2, recarga = true })
local C_RAYO = e(403, L["Tu hechizo principal."])
local C_RAYO_ABRE = e(403, L["Abre la pelea a distancia antes de que llegue."], { fueraCombate = true })
local C_OLA_MENOR = e(8004, L["Tu vida está baja: cúrate."], { vidaPropia = 40, sinObjetivo = true, unico = "curar" })
local C_OLA = e(331, L["Tu vida está baja: cúrate."], { vidaPropia = 40, sinObjetivo = true, unico = "curar" })

---------------------------------------------------------------------------
-- Druida
---------------------------------------------------------------------------
local D_MARCA = e(1126, L["Te falta Marca de lo Salvaje."], { sinBuff = true, sinObjetivo = true })
local D_ESPINAS = e(467, L["Te falta Espinas."], { sinBuff = true, sinObjetivo = true })
local D_REJUV = e(774, L["Tu vida baja: Rejuvenecimiento te cura poco a poco."], { sinBuff = true, vidaPropia = 65, soloCombate = true, sinObjetivo = true })
local D_RECRECER = e(8936, L["Tu vida está baja: cúrate."], { sinBuff = true, vidaPropia = 45, sinObjetivo = true, unico = "curar" })
local D_TOQUE = e(5185, L["Tu vida está baja: cúrate."], { vidaPropia = 45, sinObjetivo = true, unico = "curar" })
local D_INERVAR = e(29166, L["Te queda muy poco maná: Estimular lo recupera."], { maxPct = 20, soloCombate = true, sinObjetivo = true })
local D_FUEGO_LUNAR = e(8921, L["Daño con el tiempo: ponla al empezar la pelea."], { sinDebuff = true, cada = 12, sobreVida = 25, poder = "mana" })
local D_ENJAMBRE = e(5570, L["Más daño con el tiempo."], { sinDebuff = true, cada = 12, solo = true, sobreVida = 30, poder = "mana" })
local D_FUEGO_ESTELAR = e(2912, L["Fuego estelar: tu hechizo más fuerte."], { poder = "mana" })
local D_CLARIDAD = e(2912, L["Se activó Claridad: tu siguiente hechizo es gratis."], { conBuff = { 16870 }, poder = "mana" })
local D_COLERA = e(5176, L["Tu hechizo principal."], { poder = "mana" })
local D_HURACAN = e(16914, L["Varios enemigos juntos: el huracán los golpea a todos."], { aoe = true, poder = "mana" })
-- Felino (energía) y oso (ira): el juego solo deja usar cada una en su forma.
local D_MORDISCO = e(22568, L["Tienes 5 puntos de combo: muerde fuerte."], { minCombo = 5 })
local D_DESTRIPAR = e(1079, L["Tienes 5 puntos de combo y estás en grupo: el sangrado rinde más."], { minCombo = 5, enGrupo = true, sinDebuff = true, cada = 12, sobreVida = 40, unico = "remateFelino" })
local D_ARANAZO = e(1822, L["Arañazo: sangrado con el tiempo."], { sinDebuff = true, cada = 9, sobreVida = 30 })
local D_TRIZAR = e(5221, L["Estás en grupo y otro aguanta al enemigo: trízalo por la espalda."], { enGrupo = true })
local D_GARRA = e(1082, L["Garra: suma puntos de combo."])
local D_GOLPE_FERAL = e(5211, L["El enemigo está lanzando un hechizo: el golpe lo corta."], { corta = true })
local D_ENFURECER = e(5229, L["Te falta ira: Enfurecer te la da."], { maxPoder = 10, soloCombate = true, sinObjetivo = true, poder = "ira" })
local D_RUGIDO = e(99, L["Los enemigos de alrededor pegan menos."], { minEnemigos = 2, sinDebuff = true, cada = 30, sinObjetivo = true, poder = "ira" })
local D_VAPULEAR = e(779, L["Varios enemigos: golpéalos a todos."], { minEnemigos = 2, minPoder = 15, sinObjetivo = true })
local D_MAZAZO = e(6807, L["Te sobra ira: tu siguiente golpe es más fuerte."], { minPoder = 15 })
local D_HADAS_FERAL = e(16857, L["Fuego feérico: el enemigo recibe más daño."], { sinDebuff = true, cada = 40, sobreVida = 40 })

M.PRIORIDADES = {
	WARRIOR = {
		{ clave = "arms", nombre = L["Armas"], firma = { 12294 }, lista = {
			W_GRITO, W_CARGA, W_PATADA, W_VICTORIA, W_EJECUTAR, W_ABRUMAR,
			e(12294, L["Golpe mortal: tu golpe más fuerte, cada vez que esté listo."], { recarga = true }),
			e(12292, L["Tus próximos golpes también alcanzan a otro enemigo."], { minEnemigos = 2, sinObjetivo = true, soloCombate = true }),
			e(1680, L["Huracán: golpea a todos a tu alrededor."], { minEnemigos = 2, sinObjetivo = true, recarga = true }),
			W_ATRONAR, W_DESMORALIZAR, W_DESGARRAR, W_MELLAR,
			e(1464, L["Embate: un golpe fuerte entre golpe y golpe."], { minPoder = 25, solo = true }),
			e(78, L["Te sobra ira: gástala en tu siguiente golpe."], { minPoder = 50 }),
			W_SANGRE,
		} },
		{ clave = "fury", nombre = L["Furia"], firma = { 23881 }, lista = {
			W_GRITO, W_CARGA, W_PATADA, W_VICTORIA, W_EJECUTAR,
			e(23881, L["Sed de sangre: tu golpe más fuerte, cada vez que esté listo."], { recarga = true }),
			e(1680, L["Huracán: golpea a todos a tu alrededor."], { sinObjetivo = true, recarga = true }),
			e(12328, L["Deseo de muerte: mucho más daño un rato; úsalo en peleas largas."], { soloCombate = true, sinObjetivo = true, sobreVida = 50 }),
			e(18499, L["Te falta ira: esta habilidad te la da al recibir golpes."], { maxPoder = 20, soloCombate = true, sinObjetivo = true }),
			W_ABRUMAR, W_MELLAR,
			e(78, L["Te sobra ira: gástala en tu siguiente golpe."], { minPoder = 45, solo = true }),
			W_SANGRE,
		} },
		{ clave = "protection", nombre = L["Protección"], firma = { 23922 }, lista = {
			W_GRITO, W_CARGA, W_ESCUDO, W_PATADA, W_VICTORIA,
			e(2565, L["Bloqueo con escudo: bloqueas los golpes y activa Revancha."], { sinBuff = true, soloCombate = true, sinObjetivo = true }),
			e(6572, L["Revancha: barata y con mucha amenaza tras bloquear o esquivar."], { reaccion = true }),
			e(23922, L["Embate con escudo: mucho daño y amenaza."], { recarga = true }),
			W_DESMORALIZAR,
			e(6343, L["Golpea y frena a todos los enemigos que tienes cerca."], { minEnemigos = 2, sinDebuff = true, cada = 26, sinObjetivo = true }),
			e(7386, L["Hender armadura: amenaza constante y el enemigo recibe más daño."], { sinDebuff = true, cada = 25, veces = 5 }),
			W_MELLAR, W_EJECUTAR,
			e(78, L["Te sobra ira: gástala en tu siguiente golpe."], { minPoder = 40, solo = true }),
			W_SANGRE,
		} },
	},
	ROGUE = {
		{ clave = "assassination", nombre = L["Asesinato"], firma = { 14177 }, lista = {
			e(8676, L["Estás en sigilo: abre con Emboscada por la espalda."]),
			e(1833, L["Estás en sigilo: aturde al enemigo al abrir."]),
			R_PATADA, R_RIPOSTE,
			e(14177, L["Sangre fría: tu siguiente remate es crítico seguro."], { minCombo = 5, soloCombate = true, sinObjetivo = true }),
			R_HACHA, R_ROMPER, R_EVISC, R_EVISC_BAJO, R_PUNALADA, R_SINIESTRO,
		} },
		{ clave = "combat", nombre = L["Combate"], firma = { 13877, 13750 }, lista = {
			e(1833, L["Estás en sigilo: aturde al enemigo al abrir."]),
			R_PATADA, R_RIPOSTE,
			e(13877, L["Varios enemigos: tus golpes alcanzan a otro más."], { minEnemigos = 2, sinBuff = true, soloCombate = true, sinObjetivo = true }),
			e(13750, L["Subidón de adrenalina: recuperas energía mucho más rápido."], { maxPoder = 40, soloCombate = true, sinObjetivo = true, sobreVida = 50 }),
			R_HACHA, R_EVISC, R_EVISC_BAJO, R_SINIESTRO,
		} },
		{ clave = "subtlety", nombre = L["Sutileza"], firma = { 16511 }, lista = {
			e(14183, L["Estás en sigilo: Premeditación te da puntos de combo."]),
			e(8676, L["Estás en sigilo: abre con Emboscada por la espalda."]),
			e(1833, L["Estás en sigilo: aturde al enemigo al abrir."]),
			R_PATADA, R_RIPOSTE, R_HACHA, R_EVISC, R_EVISC_BAJO,
			e(14278, L["Golpe fantasmal: daño y esquivas más, cada vez que esté listo."], { recarga = true }),
			e(16511, L["Hemorragia: suma puntos de combo y el enemigo recibe más daño."]),
			R_PUNALADA, R_SINIESTRO,
		} },
	},
	MAGE = {
		{ clave = "arcane", nombre = L["Arcano"], firma = { 12042, 12043 }, lista = {
			MG_INTELECTO, MG_ARMADURA_MAGO, MG_ARMADURA_HIELO, MG_ARMADURA_ESCARCHA, MG_CONTRA, MG_EVOCACION,
			e(12042, L["Poder arcano: más daño un rato, mientras te sobre maná."], { minPct = 40, soloCombate = true, sinObjetivo = true }),
			e(12043, L["Presencia mental: tu siguiente hechizo es instantáneo."], { soloCombate = true, sinObjetivo = true }),
			e(5143, L["Se activó Claridad: tus Misiles arcanos salen gratis."], { conBuff = { 12536 } }),
			MG_EXPLOSION, MG_DEFLAGRAR, MG_VARITA,
			e(5143, L["Misiles arcanos: daño constante que no se interrumpe fácil."], { minPct = 50 }),
			MG_ESCARCHA, MG_FUEGO,
		} },
		{ clave = "fire", nombre = L["Fuego"], firma = { 11366, 11129 }, lista = {
			MG_INTELECTO, MG_ARMADURA_MAGO, MG_ARMADURA_HIELO, MG_ARMADURA_ESCARCHA, MG_CONTRA, MG_EVOCACION,
			e(11366, L["Antes de pelear: abre con Piroexplosión, tu hechizo más fuerte."], { fueraCombate = true }),
			e(11129, L["Combustión: tus hechizos de fuego hacen más críticos un rato."], { soloCombate = true, sinObjetivo = true }),
			e(11113, L["Varios enemigos cerca: la ola los golpea y los frena."], { minEnemigos = 2, sinObjetivo = true, recarga = true }),
			e(2120, L["Varios enemigos juntos: quémalos a todos a la vez."], { aoe = true }),
			e(5019, L["Te queda poco maná: usa tu varita."], { maxPct = 20 }),
			MG_DEFLAGRAR, MG_FUEGO, MG_ESCARCHA,
		} },
		{ clave = "frost", nombre = L["Escarcha"], firma = { 11426, 12472 }, lista = {
			MG_INTELECTO, MG_ARMADURA_HIELO, MG_ARMADURA_ESCARCHA, MG_ARMADURA_MAGO, MG_CONTRA, MG_EVOCACION,
			e(11426, L["Barrera de hielo: absorbe el daño que te llega."], { sinBuff = true, soloCombate = true, sinObjetivo = true }),
			e(120, L["Varios enemigos cerca: el cono los golpea y los frena."], { minEnemigos = 2, recarga = true }),
			e(10, L["Varios enemigos juntos: la ventisca los golpea a todos."], { aoe = true }),
			e(2136, L["Al enemigo le queda poca vida: remátalo al instante."], { bajoVida = 15 }),
			MG_VARITA, MG_ESCARCHA, MG_DEFLAGRAR, MG_FUEGO,
		} },
	},
	WARLOCK = {
		{ clave = "affliction", nombre = L["Aflicción"], firma = { 18265 }, lista = {
			B_ARMADURA, B_PIEL, B_ABISARIO, B_DIABLILLO, B_TRANCE, B_DRENAR_ALMA,
			B_CORRUPCION, B_AGONIA,
			e(18265, L["Succionar vida: daño con el tiempo que te cura."], { sinDebuff = true, cada = 30, sobreVida = 30 }),
			B_INMOLAR, B_DRENAR_VIDA, B_TRANSFUSION, B_LLUVIA, B_VARITA, B_SOMBRAS,
		} },
		{ clave = "demonology", nombre = L["Demonología"], firma = { 18708 }, lista = {
			B_ARMADURA, B_PIEL,
			e(18708, L["No tienes demonio: invócalo al instante, aun peleando."], { sinMascota = true, soloCombate = true, sinObjetivo = true }),
			B_ABISARIO, B_DIABLILLO, B_TRANCE, B_DRENAR_ALMA,
			B_CORRUPCION, B_AGONIA, B_INMOLAR, B_DRENAR_VIDA, B_TRANSFUSION, B_LLUVIA, B_VARITA, B_SOMBRAS,
		} },
		{ clave = "destruction", nombre = L["Destrucción"], firma = { 17962, 17877 }, lista = {
			B_ARMADURA, B_PIEL, B_DIABLILLO, B_ABISARIO, B_TRANCE,
			e(17877, L["Al enemigo le queda poca vida: Quemadura de las Sombras lo remata."], { bajoVida = 20 }),
			B_DRENAR_ALMA, B_INMOLAR,
			e(17962, L["Conflagrar: consume tu Inmolar para un golpe fuerte."], { conDebuff = { id = 348, cada = 15 }, recarga = true }),
			B_CORRUPCION, B_AGONIA, B_TRANSFUSION, B_LLUVIA, B_VARITA, B_SOMBRAS,
		} },
	},
	PRIEST = {
		{ clave = "discipline", nombre = L["Disciplina"], firma = { 10060, 14751 }, lista = {
			S_ENTEREZA, S_FUEGO_INTERIOR, S_ESCUDO, S_SANAR, S_SANAR_MENOR, S_RENOVAR,
			e(14751, L["Enfoque interno: tu siguiente hechizo es gratis y más crítico."], { soloCombate = true, sinObjetivo = true }),
			S_FUEGO_SAGRADO, S_DOLOR, S_MENTAL, S_PLAGA, S_VARITA, S_CASTIGO,
		} },
		{ clave = "holy", nombre = L["Sagrado"], firma = { 15237 }, lista = {
			S_ENTEREZA, S_FUEGO_INTERIOR, S_ESCUDO, S_SANAR, S_SANAR_MENOR, S_RENOVAR,
			e(15237, L["Varios enemigos cerca: Nova sagrada los golpea a todos."], { aoe = true, sinObjetivo = true }),
			S_FUEGO_SAGRADO, S_DOLOR, S_MENTAL, S_PLAGA, S_VARITA, S_CASTIGO,
		} },
		{ clave = "shadow", nombre = L["Sombra"], firma = { 15473, 15407 }, lista = {
			S_ENTEREZA, S_FUEGO_INTERIOR,
			e(15473, L["Te falta la forma de las Sombras: más daño de sombras y menos daño recibido."], { sinBuff = true, sinObjetivo = true }),
			S_ESCUDO, S_SANAR, S_SANAR_MENOR, S_RENOVAR,
			e(15286, L["Abrazo vampírico: tu daño de sombras te cura."], { sinDebuff = true, cada = 60, sobreVida = 40 }),
			S_DOLOR, S_MENTAL, S_PLAGA, S_VARITA, S_TORTURA, S_CASTIGO,
		} },
	},
	HUNTER = {
		{ clave = "beastmastery", nombre = L["Bestias"], firma = { 19574, 19577 }, lista = {
			H_HALCON, H_MONO, H_LLAMAR, H_REVIVIR, H_ALIVIAR, H_MARCA,
			e(19574, L["Cólera de las bestias: tu mascota pega mucho más un rato."], { conMascota = true, soloCombate = true, sinObjetivo = true }),
			e(19577, L["Intimidación: tu mascota aturde al enemigo."], { conMascota = true, recarga = true }),
			H_RAPIDO, H_MULTI, H_SERPIENTE, H_ARCANO, H_MANGOSTA, H_RAPAZ,
		} },
		{ clave = "marksmanship", nombre = L["Puntería"], firma = { 19434, 19506 }, lista = {
			H_HALCON, H_MONO,
			e(19506, L["Te falta Aura de disparo certero: más poder a distancia para tu grupo."], { sinBuff = true, sinObjetivo = true }),
			H_LLAMAR, H_REVIVIR, H_ALIVIAR, H_MARCA, H_RAPIDO,
			e(19434, L["Disparo apuntado: tu disparo más fuerte."], { recarga = true }),
			H_MULTI, H_SERPIENTE, H_ARCANO, H_MANGOSTA, H_RAPAZ,
		} },
		{ clave = "survival", nombre = L["Supervivencia"], firma = { 19306, 19386 }, lista = {
			H_HALCON, H_MONO, H_LLAMAR, H_REVIVIR, H_ALIVIAR, H_MARCA,
			e(19306, L["Paraste un golpe: tu contraataque inmoviliza al enemigo."], { reaccion = true }),
			H_MANGOSTA, H_RAPAZ, H_MULTI, H_SERPIENTE, H_ARCANO, H_RAPIDO,
		} },
	},
	PALADIN = {
		{ clave = "holy", nombre = L["Sagrado"], firma = { 20473 }, lista = {
			P_SABIDURIA, P_PODERIO, P_RECTITUD, P_RECTITUD2, P_JUSTICIA, P_IMPOSICION, P_DESTELLO, P_LUZ, P_COLERA,
			e(20473, L["Choque sagrado: daño instantáneo, cada vez que esté listo."], { recarga = true }),
			P_SENTENCIA, P_EXORCISMO, P_CONSAGRAR,
		} },
		{ clave = "protection", nombre = (L["Protección [paladín]"]:gsub(" %[.-%]$", "")), firma = { 20925 }, lista = {
			e(25780, L["En grupo y aguantando: Furia justa te da más amenaza."], { sinBuff = true, enGrupo = true, sinObjetivo = true }),
			P_SANTUARIO, P_PODERIO, P_RECTITUD, P_RECTITUD2, P_JUSTICIA, P_IMPOSICION,
			e(20925, L["Te falta Escudo sagrado: bloqueas más."], { sinBuff = true, soloCombate = true, sinObjetivo = true }),
			e(26573, L["Varios enemigos: consagra el suelo bajo ti."], { minEnemigos = 2, sinObjetivo = true }),
			P_SENTENCIA, P_COLERA, P_EXORCISMO, P_DESTELLO, P_LUZ,
		} },
		{ clave = "retribution", nombre = L["Reprensión"], firma = { 20375 }, lista = {
			P_PODERIO, P_MANDO, P_RECTITUD, P_RECTITUD2, P_JUSTICIA, P_IMPOSICION, P_COLERA,
			P_SENTENCIA, P_EXORCISMO, P_CONSAGRAR, P_DESTELLO, P_LUZ,
		} },
	},
	SHAMAN = {
		{ clave = "elemental", nombre = L["Elemental"], firma = { 16166 }, lista = {
			C_RELAMPAGOS, C_LENGUA, C_MUERDE, C_CORTE, C_OLA_MENOR, C_OLA,
			e(16166, L["Maestría elemental: tu siguiente hechizo es crítico y gratis."], { soloCombate = true, sinObjetivo = true }),
			C_LLAMA, C_CADENA, C_ABRASADOR, C_MAGMA, C_TIERRA, C_RAYO,
		} },
		{ clave = "enhancement", nombre = L["Mejora"], firma = { 17364 }, lista = {
			C_RELAMPAGOS, C_VIENTO, C_LENGUA, C_MUERDE, C_CORTE, C_OLA_MENOR, C_OLA, C_RAYO_ABRE,
			e(8075, L["Te falta el tótem de Fuerza de la tierra: más fuerza."], { sinBuff = true, soloCombate = true, sinObjetivo = true }),
			e(17364, L["Ataque de tormenta: mucho daño, cada vez que esté listo."], { recarga = true }),
			C_LLAMA, C_TIERRA, C_ABRASADOR, C_MAGMA,
		} },
		{ clave = "restoration", nombre = (L["Restauración [chamán]"]:gsub(" %[.-%]$", "")), firma = { 16190, 16188 }, lista = {
			C_RELAMPAGOS, C_LENGUA, C_MUERDE, C_CORTE, C_OLA_MENOR, C_OLA,
			C_LLAMA, C_CADENA, C_ABRASADOR, C_MAGMA, C_TIERRA, C_RAYO,
		} },
	},
	DRUID = {
		{ clave = "balance", nombre = L["Equilibrio"], firma = { 24858 }, lista = {
			D_MARCA, D_ESPINAS,
			e(24858, L["Te falta la forma de lechúcico lunar: más daño con tus hechizos."], { sinBuff = true, sinObjetivo = true, poder = "mana" }),
			D_REJUV, D_RECRECER, D_TOQUE, D_INERVAR,
			e(770, L["Fuego feérico: el enemigo recibe más daño."], { sinDebuff = true, cada = 40, sobreVida = 40, poder = "mana" }),
			D_CLARIDAD, D_FUEGO_LUNAR, D_ENJAMBRE, D_HURACAN, D_FUEGO_ESTELAR, D_COLERA,
		} },
		{ clave = "feral", nombre = L["Feral"], firma = { 16857, 16979 }, lista = {
			D_MARCA, D_ESPINAS, D_REJUV, D_RECRECER, D_TOQUE,
			-- Felino
			D_HADAS_FERAL, D_DESTRIPAR, D_MORDISCO, D_ARANAZO, D_TRIZAR, D_GARRA,
			-- Oso
			D_GOLPE_FERAL, D_ENFURECER, D_RUGIDO, D_VAPULEAR, D_MAZAZO,
			-- Sin forma (antes de aprenderlas)
			D_FUEGO_LUNAR, D_COLERA,
		} },
		{ clave = "restoration", nombre = L["Restauración"], firma = { 17116, 18562 }, lista = {
			D_MARCA, D_ESPINAS, D_REJUV, D_RECRECER, D_TOQUE, D_INERVAR,
			D_CLARIDAD, D_FUEGO_LUNAR, D_ENJAMBRE, D_HURACAN, D_FUEGO_ESTELAR, D_COLERA,
		} },
	},
}
