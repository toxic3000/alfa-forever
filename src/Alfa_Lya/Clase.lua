-- Alfa - Lya te enseña tu clase (1.2.9). toxic3000 / La Jauría. GPL-3.0.
--
--   Cuando aprendes un hechizo nuevo de tu clase (con el instructor o al subir
--   de nivel), Lya te dice en una línea para qué sirve y cuándo usarlo. Los
--   principales de las 9 clases del Clásico hasta el nivel 60 (M.HECHIZOS,
--   por su primer rango: un rango nuevo de algo que ya sabías no se cuenta).
--   El nombre lo pone el juego (C_Spell.GetSpellName), en tu idioma.
--   Cómo se entera: LEARNED_SPELL_IN_SKILL_LINE (y LEARNED_SPELL_IN_TAB en
--   clientes viejos) con el id, y SPELLS_CHANGED revisa la lista con
--   C_SpellBook.IsSpellKnown. La primera vez solo anota lo que ya sabes, sin
--   decir nada. Varios de golpe (el instructor): uno por globo, con «¿Y el
--   siguiente?». Nunca en combate. lya.clase lo apaga.
--
--   Cl.Clase() -> "WARRIOR"...   Cl.Linea(id) -> texto | nil   Cl.Sabe(id)
--   Cl.Revisar() -> cuántos nuevos   Cl.Aprendido(id)   Cl.Siguiente() -> true si habló

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local type, tonumber, tostring, ipairs, pairs, pcall, rawget, format = type, tonumber, tostring, ipairs, pairs, pcall, rawget, string.format

local Cl = {}
M.Clase = Cl

-- clase -> { { { ids del primer rango }, "para qué sirve" }, ... }
M.HECHIZOS = {
	WARRIOR = {
		{ { 100 }, "Corre hacia el enemigo y lo aturde un momento. Úsala para empezar la pelea, desde lejos." },
		{ { 772 }, "Hace sangrar al enemigo un rato. Ponla al inicio de las peleas largas." },
		{ { 6343 }, "Golpea a todos los de alrededor y los hace atacar más lento. Ideal cuando te rodean varios." },
		{ { 1715 }, "Hace más lento al enemigo. Úsala con los que huyen para que no traigan ayuda." },
		{ { 71 }, "Recibes menos daño y generas más amenaza. Es la postura para tanquear en mazmorras." },
		{ { 7386 }, "Le baja la armadura al enemigo y genera mucha amenaza. El golpe básico del tanque." },
		{ { 355 }, "Obliga al enemigo a atacarte. Úsalo cuando se va contra quien cura." },
		{ { 7384 }, "Se enciende cuando el enemigo esquiva: pega fuerte y no se puede esquivar. Úsalo en cuanto brille." },
		{ { 6572 }, "Se enciende tras bloquear, esquivar o parar. Barato y con mucha amenaza: el favorito del tanque." },
		{ { 5308 }, "Remata al enemigo cuando le queda poca vida. Guarda tu ira para el final." },
		{ { 2458 }, "Más golpes críticos, pero recibes más daño. La postura para hacer daño." },
		{ { 1680 }, "Golpea a varios enemigos cerca de ti. Perfecto contra grupos." },
		{ { 6552 }, "Interrumpe un hechizo. Guárdalo para cuando el enemigo lance algo peligroso." },
		{ { 72 }, "Interrumpe un hechizo con tu escudo. Úsalo con magos y curanderos enemigos." },
		{ { 2687 }, "Te da ira a cambio de un poco de vida. Úsala para empezar una pelea con ira." },
		{ { 1160 }, "Los enemigos cercanos pegan menos. Muy útil cuando tanqueas a varios." },
		{ { 845 }, "Golpea a tu objetivo y a otro cercano. Para cuando pelean dos o más." },
		{ { 5246 }, "Asusta a los enemigos cercanos. Cuidado: pueden correr y traer a otros." },
	},
	PALADIN = {
		{ { 635 }, "Tu curación fuerte. Úsala entre peleas o cuando alguien está muy herido." },
		{ { 465 }, "Más armadura para ti y tu grupo cercano. Una buena aura para empezar." },
		{ { 19740 }, "Más poder de ataque por varios minutos. Dásela a los que pelean cuerpo a cuerpo." },
		{ { 20271 }, "Libera tu sello sobre el enemigo para un efecto extra. Pon un sello, juzga y vuelve a ponerlo." },
		{ { 20154, 21084 }, "Tus golpes hacen daño sagrado extra. Tu sello de siempre para pelear solo." },
		{ { 498 }, "Por unos segundos no recibes daño físico. Tu salvavidas cuando las cosas se ponen feas." },
		{ { 853 }, "Aturde al enemigo unos segundos. Úsalo para interrumpir o para escapar." },
		{ { 633 }, "Te cura toda la vida a cambio de tu maná. Guárdalo para una emergencia." },
		{ { 1022 }, "Protege a un aliado de todo daño físico un momento. Salva a quien cura." },
		{ { 7328 }, "Revive a un aliado caído. Úsalo fuera de combate." },
		{ { 19742 }, "Más maná con el tiempo. Ideal para quien cura y para ti." },
		{ { 879 }, "Daño sagrado fuerte contra no-muertos y demonios." },
		{ { 19750 }, "Una curación rápida y barata. Perfecta para mantener a todos de pie." },
		{ { 1152 }, "Quita un veneno o una enfermedad a un aliado." },
		{ { 4987 }, "Quita veneno, enfermedad y magia. Úsalo cuando alguien trae algo malo encima." },
		{ { 642 }, "Te vuelve inmune un rato. Úsalo para salvarte o para escapar." },
		{ { 25780 }, "Tus golpes sagrados generan más amenaza. Préndela si vas a tanquear." },
		{ { 24275 }, "Remata desde lejos al enemigo con poca vida." },
		{ { 1044 }, "Libra a un aliado de raíces y de lentitud." },
	},
	HUNTER = {
		{ { 1978 }, "Envenena al enemigo un rato. Ponla al inicio de cada pelea." },
		{ { 3044 }, "Un disparo instantáneo extra. Úsalo mientras corres o para rematar." },
		{ { 1130 }, "Marca al enemigo y todos le pegan más a distancia. Ponla antes de empezar." },
		{ { 5116 }, "Hace más lento al enemigo. Gana distancia para seguir disparando." },
		{ { 13165 }, "Más poder de ataque a distancia. El aspecto para pelear." },
		{ { 13163 }, "Esquivas más cuerpo a cuerpo. Úsalo si el enemigo te alcanza." },
		{ { 1515 }, "Domestica una bestia para que sea tu compañera. Elige una de tu nivel o menos." },
		{ { 883 }, "Llama a tu mascota a tu lado." },
		{ { 982 }, "Revive a tu mascota caída. Úsalo fuera de combate." },
		{ { 136 }, "Cura a tu mascota poco a poco. Mantenla viva: ella te cuida." },
		{ { 6991 }, "Dale de comer a tu mascota para que esté contenta y pegue más." },
		{ { 2974 }, "Hace lento al enemigo cuerpo a cuerpo. Después aléjate y dispara." },
		{ { 5118 }, "Corres más rápido, pero si te pegan te aturdes. Solo para viajar." },
		{ { 1499 }, "Congela a un enemigo un rato. Ideal para controlar a uno extra en mazmorras." },
		{ { 2643 }, "Le disparas a varios enemigos a la vez. Cuidado con despertar a los dormidos." },
		{ { 5384 }, "Te haces el muerto y los enemigos te olvidan. Tu mejor salida si algo sale mal." },
		{ { 3045 }, "Disparas mucho más rápido un rato. Guárdalo para los jefes." },
		{ { 781 }, "Bajas la amenaza que generas. Úsalo si el enemigo se te viene encima." },
	},
	ROGUE = {
		{ { 1784 }, "Te vuelves invisible al caminar. Acércate sin que te vean y elige cómo empezar." },
		{ { 53 }, "Gran daño por la espalda con daga. Colócate detrás del enemigo." },
		{ { 921 }, "Roba al enemigo sin que se dé cuenta. Hazlo en sigilo antes de atacar." },
		{ { 1776 }, "Incapacita al enemigo un momento. Úsalo para ponerte a su espalda." },
		{ { 5277 }, "Esquivas casi todo unos segundos. Tu salvavidas cuando te pegan muchos." },
		{ { 6770 }, "Duerme a un enemigo sin pelear. Perfecto para controlar uno en las mazmorras." },
		{ { 5171 }, "Atacas más rápido según tus puntos de combo. Mantenlo en las peleas largas." },
		{ { 2983 }, "Corres mucho más rápido un momento. Para huir o para alcanzar a alguien." },
		{ { 1766 }, "Interrumpe un hechizo. Úsalo con magos y curanderos enemigos." },
		{ { 703 }, "Desde el sigilo y por la espalda: lo hace sangrar un buen rato." },
		{ { 8676 }, "Desde el sigilo y por la espalda: un golpe enorme para empezar." },
		{ { 1856 }, "Desapareces y vuelves al sigilo, aun en combate. Tu escape de emergencia." },
		{ { 1833 }, "Desde el sigilo: aturde al enemigo unos segundos para empezar con ventaja." },
		{ { 408 }, "Aturde según tus puntos de combo. Úsalo para interrumpir o rematar." },
		{ { 2094 }, "Ciega a un enemigo un rato. Útil para salir de una pelea mala." },
		{ { 2842 }, "Ya puedes hacer venenos. Ponlos en tus armas: suman mucho daño." },
		{ { 1943 }, "Remate que hace sangrar según tus puntos de combo. Bueno contra enemigos con mucha vida." },
		{ { 1966 }, "Baja tu amenaza. Úsalo en grupo para no quitarle el enemigo al tanque." },
	},
	PRIEST = {
		{ { 2050 }, "Tu primera curación. Úsala entre peleas para no gastar comida." },
		{ { 1243 }, "Más aguante para ti y tus amigos. Dásela a todo el grupo antes de empezar." },
		{ { 589 }, "Daño de sombra durante un rato. Ponla al inicio y sigue con otra cosa." },
		{ { 17 }, "Un escudo que absorbe daño. Ponlo antes de que te peguen o en quien tanquea." },
		{ { 139 }, "Cura poco a poco. Ideal para alguien que recibe daño sin parar." },
		{ { 586 }, "Baja tu amenaza un rato. Úsalo si los enemigos se te vienen encima." },
		{ { 8092 }, "Daño de sombra fuerte. Buen golpe para empezar o para rematar." },
		{ { 2006 }, "Revive a un aliado caído. Úsalo fuera de combate." },
		{ { 588 }, "Más armadura y más poder. Mantenlo siempre puesto." },
		{ { 8122 }, "Asusta a los enemigos cercanos. Te da tiempo para escapar o curarte." },
		{ { 2054 }, "Una curación más fuerte. Para cuando la vida baja mucho." },
		{ { 527 }, "Quita magia mala a un aliado, o magia buena a un enemigo." },
		{ { 2061 }, "Una curación muy rápida pero cara. Para emergencias." },
		{ { 528 }, "Quita una enfermedad. Úsala en lugares llenos de no-muertos." },
		{ { 2060 }, "Tu curación más fuerte. Es lenta: empiézala antes de que sea tarde." },
		{ { 596 }, "Cura a todo tu grupo a la vez. Perfecta cuando a todos les pegan." },
		{ { 15407 }, "Daño de sombra que hace lento al enemigo. Canalízalo mientras se acerca." },
	},
	SHAMAN = {
		{ { 8017 }, "Encanta tu arma para pegar más fuerte. Renuévalo cuando se acabe." },
		{ { 8042 }, "Daño rápido que también interrumpe hechizos. Úsalo con quien lanza magia." },
		{ { 8071 }, "Un tótem que reduce el daño que recibes cuerpo a cuerpo." },
		{ { 331 }, "Tu curación básica. Úsala entre peleas o cuando estés herido." },
		{ { 2484 }, "Un tótem que hace lentos a los enemigos cercanos. Para escapar o pelear con ventaja." },
		{ { 5730 }, "Un tótem que atrae los golpes de los enemigos. Te da un respiro." },
		{ { 324 }, "Rayos que dañan a quien te pegue. Mantenlo puesto." },
		{ { 8050 }, "Daño de fuego que quema un rato. Bueno para empezar la pelea." },
		{ { 8024 }, "Tu arma pega con fuego. Buena para armas lentas." },
		{ { 3599 }, "Un tótem que le dispara fuego al enemigo. Ponlo al empezar." },
		{ { 8075 }, "Más fuerza para ti y tu grupo cercano." },
		{ { 370 }, "Le quita magia buena al enemigo." },
		{ { 2008 }, "Revive a un aliado caído. Úsalo fuera de combate." },
		{ { 2645 }, "Te conviertes en lobo y corres más rápido. ¡Como yo!" },
		{ { 8056 }, "Daño de escarcha que deja lento al enemigo. Perfecto si huye." },
		{ { 5394 }, "Un tótem que cura poco a poco a tu grupo." },
		{ { 8004 }, "Una curación rápida. Para cuando no hay tiempo." },
		{ { 8232 }, "Tu arma a veces da golpes extra. De lo mejor para armas lentas." },
		{ { 421 }, "Un rayo que salta entre varios enemigos." },
		{ { 20608 }, "Puedes revivirte tú solo al morir. Necesitas un ankh." },
		{ { 1064 }, "Una curación que salta entre tus compañeros heridos." },
		{ { 8143 }, "Un tótem que quita el miedo, el sueño y el encanto a tu grupo." },
	},
	MAGE = {
		{ { 5143 }, "Varios misiles que no fallan. Bueno cuando el enemigo no se mueve." },
		{ { 1459 }, "Más intelecto para ti y tus amigos. Dáselo al grupo antes de empezar." },
		{ { 2136 }, "Daño de fuego al instante. Úsalo para rematar o mientras te mueves." },
		{ { 116 }, "Daño de escarcha que deja lento al enemigo. Tu hechizo para mantenerlo lejos." },
		{ { 118 }, "Convierte a un enemigo en oveja un rato. El mejor control en mazmorras." },
		{ { 5504 }, "Haz tu propia agua. Así no gastas oro en bebida." },
		{ { 587 }, "Haz tu propia comida para recuperar vida." },
		{ { 122 }, "Congela en su lugar a los enemigos cercanos. Aléjate y sigue lanzando." },
		{ { 1449 }, "Daño a todos los que están cerca de ti. Para cuando te rodean." },
		{ { 2120 }, "Fuego en un área. Bueno contra grupos que no se mueven." },
		{ { 1953 }, "Te teletransportas unos metros hacia adelante. Para escapar de raíces y aturdimientos." },
		{ { 2139 }, "Interrumpe un hechizo y bloquea esa magia un rato." },
		{ { 475 }, "Quita una maldición a un aliado." },
		{ { 1463 }, "El daño se lo come tu maná en vez de tu vida." },
		{ { 10 }, "Una tormenta de hielo en un área. Ideal contra grupos." },
		{ { 120 }, "Escarcha en cono frente a ti que hace lentos a los enemigos." },
		{ { 12051 }, "Recuperas mucho maná en unos segundos. Úsalo cuando estés casi vacío." },
		{ { 6117 }, "Recuperas maná aun mientras lanzas hechizos." },
		{ { 3561, 3562, 3565, 3563, 3566, 3567 }, "Te teletransporta a tu ciudad. Necesitas una runa de teletransporte." },
	},
	WARLOCK = {
		{ { 688 }, "Tu primer demonio: el diablillo lanza fuego desde lejos." },
		{ { 348 }, "Quema al enemigo de golpe y durante un rato. Buen inicio de pelea." },
		{ { 172 }, "Daño de sombra durante un buen rato. Ponla al inicio." },
		{ { 1454 }, "Cambias vida por maná. Úsalo y luego recupera tu vida comiendo." },
		{ { 702 }, "El enemigo pega menos. Útil cuando te pega a ti o a tu demonio." },
		{ { 980 }, "Mucho daño de sombra que va creciendo. Una maldición por enemigo." },
		{ { 5782 }, "Asusta a un enemigo y lo hace huir. Cuidado: puede traer a otros." },
		{ { 697 }, "Tu abisario: un demonio que aguanta golpes por ti. Perfecto para ir solo." },
		{ { 6201 }, "Una piedra de salud para emergencias. Haz una antes de cada mazmorra." },
		{ { 1120 }, "Remata al enemigo y, si muere, te da un fragmento de alma." },
		{ { 755 }, "Pasas tu vida a tu demonio para curarlo." },
		{ { 689 }, "Le robas vida al enemigo y te curas. Ideal cuando vas solo." },
		{ { 693 }, "Una piedra que deja revivir al morir. Pónsela a quien cura." },
		{ { 712 }, "Tu súcubo: mucho daño y puede seducir a un enemigo para controlarlo." },
		{ { 706 }, "Más armadura y regeneras vida. Mantenla siempre puesta." },
		{ { 5740 }, "Fuego en un área. Para grupos de enemigos." },
		{ { 691 }, "Tu manáfago: quita magia y bloquea hechizos enemigos." },
		{ { 710 }, "Destierra a un demonio o elemental un rato. Buen control en mazmorras." },
		{ { 5484 }, "Asusta a todos los enemigos cercanos." },
		{ { 6789 }, "Asusta un momento al enemigo y te cura. Tu escape de emergencia." },
		{ { 698 }, "Con dos amigos, trae hasta aquí a alguien de tu grupo." },
		{ { 5784 }, "Tu corcel vil: una montura propia de brujo. ¡Felicidades!" },
	},
	DRUID = {
		{ { 1126 }, "Más armadura, atributos y resistencias. Dásela a todo el grupo." },
		{ { 8921 }, "Daño arcano al instante y un rato más. Bueno para empezar o mientras corres." },
		{ { 774 }, "Cura poco a poco. Ponla en quien recibe daño." },
		{ { 467 }, "Quien te pegue cuerpo a cuerpo se lastima. Pónsela al que tanquea." },
		{ { 339 }, "Atrapa al enemigo en su lugar. Para alejarte y lanzar tranquilo." },
		{ { 5487 }, "Te conviertes en oso: más armadura y más vida. Para tanquear y aguantar." },
		{ { 6795 }, "Obliga al enemigo a atacarte. Úsalo en forma de oso." },
		{ { 6807 }, "Un zarpazo fuerte en forma de oso. Genera mucha amenaza." },
		{ { 8936 }, "Cura de golpe y luego un rato más." },
		{ { 5211 }, "Aturde al enemigo en forma de oso. Úsalo para interrumpir." },
		{ { 779 }, "En forma de oso, golpea a varios enemigos cerca." },
		{ { 1066 }, "Te conviertes en foca: nadas rápido y respiras bajo el agua." },
		{ { 770 }, "Le baja la armadura al enemigo y no lo deja volverse invisible." },
		{ { 2637 }, "Duerme a una bestia o a un dragón. Buen control en mazmorras." },
		{ { 768 }, "Te conviertes en felino: mucho daño cuerpo a cuerpo y puedes acechar." },
		{ { 5215 }, "En forma de felino te vuelves sigiloso. Acércate sin que te vean." },
		{ { 1822 }, "En forma de felino, un arañazo que hace sangrar." },
		{ { 1079 }, "Remate en forma de felino: hace sangrar según tus puntos de combo." },
		{ { 5221 }, "En forma de felino y por la espalda: mucho daño." },
		{ { 2782 }, "Quita una maldición a un aliado." },
		{ { 8946 }, "Quita un veneno a un aliado." },
		{ { 783 }, "Te conviertes en guepardo y corres más rápido. Solo al aire libre." },
		{ { 20484 }, "Revive a un aliado en pleno combate. Tarda en volver a estar lista." },
		{ { 740 }, "Una gran curación para todo el grupo mientras canalizas." },
		{ { 29166 }, "Le das mucho maná a un aliado. Dáselo a quien cura o úsalo en ti." },
		{ { 18960 }, "Te lleva al Claro de la Luna, un lugar tranquilo para entrenar." },
	},
}

local function secreto(v) return issecretvalue ~= nil and type(v) ~= "nil" and issecretvalue(v) and true or false end

-- id -> línea, para tu clase
local porId, deClase
local function indice()
	local c = Cl.Clase()
	if porId and deClase == c then return porId end
	porId, deClase = {}, c
	for _, e in ipairs(c and M.HECHIZOS[c] or {}) do
		for _, id in ipairs(e[1]) do porId[id] = e[2] end
	end
	return porId
end

function Cl.Clase()
	if not UnitClass then return nil end
	local ok, _, t = pcall(UnitClass, "player")
	if not ok or secreto(t) or type(t) ~= "string" then return nil end
	return t
end

function Cl.Linea(id)
	local t = indice()[tonumber(id) or -1]
	return t and L[t] or nil
end

function Cl.Sabe(id)
	local S = C_SpellBook
	if S and S.IsSpellKnown then
		local ok, si = pcall(S.IsSpellKnown, id)
		if ok and not secreto(si) then return si == true end
	end
	local f = rawget(_G, "IsSpellKnown") or rawget(_G, "IsPlayerSpell")
	if type(f) == "function" then
		local ok, si = pcall(f, id)
		return ok and not secreto(si) and si == true or false
	end
	return false
end

local function nombre(id)
	local S = C_Spell
	if S and S.GetSpellName then
		local ok, n = pcall(S.GetSpellName, id)
		if ok and type(n) == "string" and not secreto(n) and n ~= "" then return n end
	end
	local f = rawget(_G, "GetSpellInfo")
	if type(f) == "function" then
		local ok, n = pcall(f, id)
		if ok and type(n) == "string" and not secreto(n) and n ~= "" then return n end
	end
	return nil
end

local function datos()
	local d = N.DatosPersonaje(ID)
	d.clase = type(d.clase) == "table" and d.clase or {}
	return d
end

-- Lo que falta por contar, en orden de llegada.
local cola = {}

local function enCola(id)
	for _, x in ipairs(cola) do if x == id then return true end end
	return false
end

-- Lo aprendiste: a la cola (una línea por hechizo, una vez por personaje).
function Cl.Aprendido(id)
	id = tonumber(id)
	if not id or secreto(id) or not indice()[id] then return false end
	local d = datos()
	-- Todos los rangos del mismo hechizo cuentan como uno.
	for _, e in ipairs(M.HECHIZOS[deClase] or {}) do
		for _, x in ipairs(e[1]) do
			if x == id then
				for _, y in ipairs(e[1]) do if d.clase[tostring(y)] then return false end end
			end
		end
	end
	d.clase[tostring(id)] = true
	if not enCola(id) then cola[#cola + 1] = id end
	return true
end

-- Revisa lo que sabes. La primera vez solo anota (no te enseña lo que ya sabías).
function Cl.Revisar()
	local d = datos()
	local primera = not d.claseBase
	local n = 0
	for id in pairs(indice()) do
		if not d.clase[tostring(id)] and Cl.Sabe(id) then
			if primera then d.clase[tostring(id)] = true elseif Cl.Aprendido(id) then n = n + 1 end
		end
	end
	if Cl.Clase() then d.claseBase = true end
	return n
end

-- Dice el siguiente de la cola. -> true si habló
function Cl.Siguiente()
	if N.Get(ID, "clase") == false then cola = {} return false end
	local Ce = M.Cerebro
	if not (Ce and #cola > 0) or Ce.Silenciada() then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	local id = cola[1]
	local linea = Cl.Linea(id)
	if not linea then table.remove(cola, 1) return Cl.Siguiente() end
	local n = nombre(id)
	local t = n and format(L["Aprendiste %s. %s"], n, linea) or linea
	local acciones
	if #cola > 1 then
		acciones = { { texto = L["¿Y el siguiente?"], fn = function() K.Despues(0.4, Cl.Siguiente) end } }
	end
	-- pedido: lo aprendiste tú ahorita (no espera su turno de consejos).
	local ok = Ce.Decir({ texto = t, pedido = true, clase = "clase", cara = "atenta", lineas = 5, ancho = 360,
		segundos = 12, acciones = acciones })
	if ok == true then table.remove(cola, 1) return true end
	return false
end
Cl.Cola = function() return cola end

local pendiente = false
local function pronto(espera)
	if pendiente then return end
	pendiente = true
	A.After(espera or 1.5, function()
		pendiente = false
		N.FueraDeCombate("lya.clase", function()
			local ok, e = pcall(function()
				if N.Get(ID, "clase") ~= false and datos().claseBase then Cl.Revisar() end
				Cl.Siguiente()
			end)
			if not ok and geterrorhandler then geterrorhandler()(e) end
		end)
	end)
end

local function aprendio(_, id)
	if N.Get(ID, "clase") == false or not datos().claseBase then return end
	if Cl.Aprendido(id) then pronto() end
end
A.RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", aprendio)
A.RegisterEvent("LEARNED_SPELL_IN_TAB", aprendio)
A.RegisterEvent("SPELLS_CHANGED", function() if datos().claseBase then pronto(3) end end)
-- Lo que quedó en la cola al cerrar un globo de otra cosa: en el latido de siempre.
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() if #cola > 0 then pronto(4) end end)
if A.OnLogin then
	A.OnLogin(function()
		A.After(12, function()
			local ok, e = pcall(Cl.Revisar)
			if not ok and geterrorhandler then geterrorhandler()(e) end
		end)
	end)
end
