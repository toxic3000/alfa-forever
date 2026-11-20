-- Alfa - Bienvenida: lo que pregunta la configuración (toxic3000 / La Jauría).
-- GPL-3.0.
--
-- Todo lo que Alfa hace sola es una pregunta del asistente, agrupado en
-- pocas pantallas para que quede limpio. Cada fila es un ajuste real (del
-- motor o de un módulo), con una línea que explica qué hace; el interruptor
-- muestra lo que tienes ahora, así que quien ya usaba Alfa ve sus ajustes y
-- quien empieza ve los de fábrica. Solo salen las filas cuyo módulo está
-- cargado y cuyo ajuste existe.
--
-- Una fila:
--   { id, titulo, texto, clave = "qol.sellJunk" }            un interruptor
--   { ..., get = fn() -> bool, set = fn(bool) }               dos o más ajustes
--   { ..., opciones = { { valor, texto } } }                   un desplegable
--   hija = "id"        se atenúa si su fila madre está apagada
--   destacar = true    tiene su propia fila (Sí / No) en el resumen
--   existe = fn()      si la fila sale (por omisión: el ajuste existe)
--   recomendar = fn(rol) -> valor | nil   lo recomendado para tu clase o rol:
--                      se escribe solo la primera vez que alguien configura
--                      Alfa (nunca encima de lo que ya elegiste)
--
-- Las claves que se escriben están en LEEME.md ("Ajustes que escribe").

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L

local function hay(id) return N.ModuloPorId and N.ModuloPorId(id) ~= nil end
local function existe(clave) return A.Get(clave) ~= nil end

---------------------------------------------------------------------------
-- Tu rol: cura, tanque o daño (la rama de talentos del motor y, si no, la
-- especialización del cliente). Lo usan las recomendaciones.
---------------------------------------------------------------------------
local CURA = { PRIEST = { discipline = true, holy = true }, PALADIN = { holy = true },
	SHAMAN = { restoration = true }, DRUID = { restoration = true } }
local TANQUE = { WARRIOR = { protection = true }, PALADIN = { protection = true } }
local ROL_CLIENTE = { HEALER = "cura", TANK = "tanque", DAMAGER = "dano" }

local function legible(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end

function M.Clase()
	if not UnitClass then return nil, nil end
	local ok, nombre, clase = pcall(UnitClass, "player")
	if not ok then return nil, nil end
	nombre, clase = legible(nombre), legible(clase)
	return type(clase) == "string" and clase or nil, type(nombre) == "string" and nombre or nil
end

function M.Rol()
	local clase = M.Clase()
	local G = A.Gear
	if type(G) == "table" and type(G.GetSpec) == "function" then
		local ok, k, _, fuente = pcall(G.GetSpec)
		if ok and type(k) == "string" and fuente ~= "custom" then
			if clase and CURA[clase] and CURA[clase][k] then return "cura" end
			if clase and TANQUE[clase] and TANQUE[clase][k] then return "tanque" end
			return "dano"
		end
	end
	local S = C_SpecializationInfo
	if S and S.GetSpecialization and S.GetSpecializationInfo then
		local ok, i = pcall(S.GetSpecialization)
		i = ok and legible(i) or nil
		if type(i) == "number" and i > 0 then
			local ok2, _, _, _, _, rol = pcall(S.GetSpecializationInfo, i)
			if ok2 and ROL_CLIENTE[legible(rol)] then return ROL_CLIENTE[rol] end
		end
	end
	return "dano"
end

---------------------------------------------------------------------------
-- Ayudas para escribir filas
---------------------------------------------------------------------------

-- Un ajuste que no es sí o no: el interruptor encendido es `si`.
local function modo(clave, si, no)
	return {
		get = function() return A.Get(clave) == si end,
		set = function(v) A.Set(clave, v and si or no) end,
		existe = function() return existe(clave) end,
	}
end

-- Varias claves que van juntas (se leen de la primera que tenga valor).
local function juntas(claves, porOmision, existeFn)
	return {
		get = function()
			for _, c in ipairs(claves) do
				local v = A.Get(c)
				if v ~= nil then return v and true or false end
			end
			return porOmision
		end,
		set = function(v) for _, c in ipairs(claves) do A.Set(c, v and true or false) end end,
		existe = existeFn,
	}
end

local function fila(t, extra)
	for k, v in pairs(extra or {}) do if t[k] == nil then t[k] = v end end
	return t
end

---------------------------------------------------------------------------
-- Las pantallas de ajustes (entre el estilo y La Jauría)
---------------------------------------------------------------------------
-- { id, corto (para el resumen), titulo, texto, grupos = { { titulo, filas } } }
function M.PantallasDeAjustes()
	local cura = M.Rol() == "cura"
	return {
		{
			id = "apariencia", corto = "Todo con tu estilo",
			titulo = "Tu pantalla y tu compañera",
			texto = "El estilo que elegiste también puede vestir el chat, el minimapa, las barras de abajo y el mapa. Se apaga cuando quieras y todo vuelve a como estaba.",
			grupos = {
				{ titulo = "Interfaz del juego", filas = {
					{ id = "estiloChat", clave = "comodidades.chat", titulo = "El chat",
						texto = "Fondo, pestañas y caja de escribir con tu estilo.",
						existe = function() return hay("comodidades") and existe("comodidades.chat") end },
					{ id = "estiloMinimapa", clave = "comodidades.minimapaEstilo", titulo = "El minimapa",
						texto = "El aro y la cabecera del minimapa con tu estilo.",
						existe = function() return hay("comodidades") and existe("comodidades.minimapaEstilo") end },
					{ id = "estiloBarras", clave = "comodidades.barras", titulo = "Las barras de abajo",
						texto = "Botones de acción, experiencia, menú y bolsas con tu estilo. Nunca se tocan en combate.",
						existe = function() return hay("comodidades") and existe("comodidades.barras") end },
				} },
				{ titulo = "Tu compañera", filas = {
					{ id = "lya", clave = "lya.mostrar", titulo = "Lya te acompaña",
						texto = "Una loba negra que te da consejos y ánimo en el camino, sin estorbar. En memoria de una gran perrita.",
						existe = function() return rawget(_G, "AlfaLya") ~= nil and existe("lya.mostrar") end },
				} },
				{ titulo = "Mapa de Alfa", filas = {
					fila({ id = "terreno", titulo = "El terreno real en el mapa",
						texto = "Al acercar se ven las montañas y el relieve, igual que en el minimapa. Apagado: el mapa pintado del juego." },
						modo("mundo.estiloMapa", "terreno", "clasico")),
				} },
				{ titulo = "Paisaje", filas = {
					fila({ id = "paisaje", titulo = "Un paisaje más bonito",
						texto = "Más pasto, más horizonte, niebla ligera y rayos de sol, sin pedirle de más a tu PC. Se deshace en Mundo > Paisaje y gráficos (o /alfa paisaje)." },
						{ get = function()
							local V = rawget(_G, "AlfaVista")
							if not V then return false end
							-- "Puesto" aunque el juego haya recortado algún valor (Ultimo).
							return (V.Actual and V.Actual() == "manada") or (V.Ultimo and V.Ultimo() == "manada") or false
						end,
						set = function(v)
							local V = rawget(_G, "AlfaVista")
							if not V then return end
							local puesto = (V.Actual and V.Actual() == "manada") or (V.Ultimo and V.Ultimo() == "manada")
							if v and not puesto then V.AplicarPreset("manada")
							elseif not v and puesto then V.Deshacer() end
						end,
						existe = function() return rawget(_G, "AlfaVista") ~= nil end }),
				} },
			},
		},
		{
			id = "misiones", corto = "Misiones",
			titulo = "¿Qué hace Alfa con tus misiones?",
			texto = "Todo esto lo hace Alfa sola al hablar con quien da o recibe una misión. Mantén presionado Mayús para hacerlo tú en el momento.",
			grupos = {
				{ titulo = "Aceptar y entregar", filas = {
					{ id = "aceptar", clave = "behavior.autoAccept", titulo = "Aceptar las misiones de tu guía",
						texto = "Al hablar con quien da una misión de tu ruta, se acepta sola." },
					{ id = "entregar", clave = "behavior.autoTurnin", titulo = "Entregar las misiones de tu guía",
						texto = "Al volver con una misión lista, se entrega sola. Si hay recompensas para elegir, eliges tú." },
					fila({ id = "soloRuta", titulo = "Solo las misiones de tu ruta",
						texto = "Alfa no toma misiones que no sirven a tu ruta. Tu registro queda limpio." },
						{ get = function() return A.Get("ruta.soloRuta") ~= false end, set = function(v) A.Set("ruta.soloRuta", v and true or false) end,
							existe = function() return existe("ruta.soloRuta") or hay("rutas") end }),
					{ id = "todas", clave = "comodidades.misiones", titulo = "También las que no son de tu guía",
						texto = "Acepta y entrega las demás (normales, diarias y semanales). Nunca las grises ni las que piden oro o materiales.",
						existe = function() return hay("comodidades") and existe("comodidades.misiones") end },
					{ id = "grises", clave = "behavior.skipGrey", titulo = "Saltar las misiones grises",
						texto = "Tu guía deja fuera las misiones que ya no dan experiencia, salvo que otra las necesite." },
					{ id = "cerrarSaltadas", clave = "behavior.closeSkipped", titulo = "Cerrar lo que tu guía salta",
						texto = "Tras aceptar o entregar, cierra la ventana del PNJ si solo ofrece misiones que tu guía no hace." },
					{ id = "avisarCierra", clave = "behavior.warnClosing", titulo = "Avisar antes de una misión que cierra otra",
						texto = "Dice en el chat qué misión perderías y te deja aceptarla a ti.",
						-- Encendido para quien configura Alfa por primera vez (nunca encima de lo que eligió).
						recomendar = function() return true end },
				} },
				{ titulo = "Recompensas", filas = {
					{ id = "mejorRecompensa", clave = "qol.rewardAutoPick", titulo = "Tomar la mejor recompensa",
						texto = "Cuando hay varias para elegir, toma la que más te sirve." },
					{ id = "ponerRecompensa", clave = "qol.rewardEquip", titulo = "Ponerte la recompensa si es mejor",
						texto = "Si lo que te dan mejora tu equipo, te lo pones al salir de combate." },
				} },
				{ titulo = "Para verlas mejor", filas = {
					fila({ id = "resaltar", destacar = true, titulo = "Resaltar lo de misión",
						texto = "Los enemigos de tus misiones marcados sobre su placa de nombre y los objetos de misión brillando en tus bolsas." },
						juntas({ "combate.marcaMision", "bolsas.brilloMision" }, true, function() return hay("combate") or hay("bolsas") end)),
				} },
			},
		},
		{
			id = "guia", corto = "Tu guía",
			titulo = "¿Cuánto decide Alfa por ti en el camino?",
			texto = "Tu guía puede elegir y avanzar sola, o preguntarte en cada cruce.",
			grupos = {
				{ titulo = "Tu guía", filas = {
					{ id = "elegirGuia", clave = "behavior.autoSelectGuide", titulo = "Elegir una guía por ti",
						texto = "Si no tienes ninguna abierta, abre la recomendada para tu nivel." },
					fila({ id = "siguienteGuia", titulo = "Seguir sola con la siguiente guía",
						texto = "Al terminar una guía de nivel, carga la siguiente sin preguntar." }, modo("behavior.guideEnd", "continue", "ask")),
					fila({ id = "zona", titulo = "Ir a la zona recomendada",
						texto = "Donde puedes seguir en varias zonas, toma la recomendada sin preguntar." }, modo("behavior.routeChoice", "recommended", "ask")),
					{ id = "mientras", clave = "behavior.whileHere", titulo = "Mientras estás aquí",
						texto = "Te sugiere objetivos de pasos más adelante que tienes muy cerca." },
					{ id = "clase", clave = "behavior.offerClassQuests", titulo = "Ofrecer las misiones de tu clase",
						texto = "Cuando se abre una misión de clase para ti, te ofrece su guía." },
					{ id = "instructor", clave = "behavior.trainReminder", titulo = "Recordarte ir al instructor",
						texto = "Una nota con el instructor más cercano cuando tienes habilidades nuevas.",
						opciones = { { valor = "2", texto = "Cada 2 niveles" }, { valor = "1", texto = "Cada nivel" }, { valor = "off", texto = "Nunca" } } },
				} },
				{ titulo = "La flecha y el camino", filas = {
					{ id = "flecha", clave = "nav.arrow", titulo = "La flecha que te guía",
						texto = "Una flecha en pantalla que apunta a tu siguiente objetivo, con la distancia. Apagada: tú decides por dónde ir." },
					{ id = "camino", clave = "nav.routeLines", titulo = "El camino en el mapa y el minimapa",
						texto = "Dibuja la ruta hasta tu objetivo: por dónde caminar, volar o navegar." },
				} },
				{ titulo = "Al hablar con un PNJ", filas = {
					{ id = "charla", clave = "qol.skipGossip", titulo = "Saltar la charla de una sola opción",
						texto = "Elige sola la única opción de los PNJ sin misiones." },
					{ id = "pasoPide", clave = "qol.stepGossip", titulo = "Elegir lo que pide tu paso",
						texto = "Elige la opción que nombra tu guía, o abre la tienda o el entrenamiento que necesitas." },
				} },
			},
		},
		{
			id = "comercio", corto = "Comerciantes y viajes",
			titulo = "¿Qué hace Alfa con comerciantes y viajes?",
			texto = "Pequeñas tareas que Alfa hace por ti al abrir un comerciante, al despojar y al viajar.",
			grupos = {
				{ titulo = "Comerciantes", filas = {
					{ id = "vender", clave = "qol.sellJunk", titulo = "Vender lo gris",
						texto = "Vende los objetos grises y lo que marcaste como basura. Nunca lo que marcaste para guardar." },
					{ id = "reparar", clave = "qol.autoRepair", titulo = "Reparar tu equipo",
						texto = "Repara todo en los comerciantes que pueden, si te alcanza." },
					{ id = "repararHermandad", clave = "qol.repairGuild", hija = "reparar", titulo = "Primero con el banco de la hermandad",
						texto = "Si tu rango lo permite, la hermandad paga y tu dinero pone el resto." },
					{ id = "comprar", clave = "qol.buyGoals", titulo = "Comprar lo que pide tu guía",
						texto = "Compra lo que tu paso necesita si el comerciante lo vende. Nada de más de 50 de oro." },
				} },
				{ titulo = "Botín y viajes", filas = {
					{ id = "despojar", clave = "qol.fastLoot", titulo = "Despojar más rápido",
						texto = "Toma todo el botín de una vez cuando tienes el despojo automático." },
					{ id = "mapaVuelo", clave = "qol.flightAutoOpen", titulo = "Abrir el mapa de vuelo",
						texto = "Al hablar con el maestro de vuelo, abre su mapa directamente." },
					{ id = "tomarVuelo", clave = "qol.flightAutoTake", titulo = "Tomar el vuelo de tu ruta",
						texto = "Al abrirse el mapa de vuelo, vuela al destino que marca tu ruta." },
					{ id = "hogar", clave = "qol.autoBind", titulo = "Fijar tu hogar en la posada de tu guía",
						texto = "Cuando tu paso lo pide y hablas con su posadero. Nunca en otra posada." },
				} },
			},
		},
		{
			id = "gente", corto = "Otros jugadores",
			titulo = "¿Qué responde Alfa por ti a otros jugadores?",
			texto = "Lo que Alfa acepta, rechaza o comparte sola. Mantén presionado Mayús para decidir tú en el momento.",
			grupos = {
				{ titulo = "Acepta por ti", filas = {
					{ id = "invocar", clave = "qol.acceptSummon", titulo = "Aceptar invocaciones",
						texto = "Acepta una invocación al momento, salvo en combate." },
					{ id = "resucitar", clave = "qol.acceptResurrect", titulo = "Aceptar resurrecciones",
						texto = "Acepta una resurrección en cuanto se puede. Nunca en Hardcore." },
					{ id = "grupoAmigos", clave = "qol.acceptPartyFriends", titulo = "Unirte al grupo de tus amigos",
						texto = "Acepta invitaciones de grupo de tus amigos y de tu hermandad." },
					{ id = "liberar", clave = "qol.autoReleasePvP", titulo = "Liberar tu espíritu en campos de batalla",
						texto = "Al morir en un campo de batalla, liberas tu espíritu al momento." },
				} },
				{ titulo = "Rechaza por ti", filas = {
					{ id = "extranos", clave = "qol.declinePartyStrangers", titulo = "Invitaciones de grupo de desconocidos",
						texto = "Rechaza las de quien no es tu amigo ni de tu hermandad." },
					{ id = "hermandades", clave = "qol.declineGuildInvites", titulo = "Invitaciones a hermandades",
						texto = "Rechaza las invitaciones a hermandades, salvo de tus amigos." },
					{ id = "duelos", clave = "qol.declineDuels", titulo = "Duelos",
						texto = "Rechaza los duelos, salvo de tus amigos y tu hermandad." },
				} },
				{ titulo = "Comparte por ti", filas = {
					{ id = "progresoGrupo", clave = "party.share", titulo = "Tu avance de misiones con tu grupo",
						texto = "Quienes van contigo y usan Alfa ven cómo vas en las misiones que comparten." },
					{ id = "chatGrupo", clave = "party.chat", titulo = "Avisar a tu grupo cuando completas una misión",
						texto = "«[Misión] está lista para entregar» y «¡Misión completada!» en el chat del grupo, para todos. Apagado, solo te salen a ti." },
					{ id = "barcos", clave = "nav.shareTransit", titulo = "Horarios de barcos y zepelines",
						texto = "Tu hermandad y tu grupo reciben los horarios que tomas, y tú los suyos." },
				} },
			},
		},
		{
			id = "personaje", corto = "Tu personaje",
			titulo = "Ayudas para tu personaje",
			texto = "Ya vienen elegidas según tu clase y tu rol. Cámbialas si prefieres otra cosa.",
			grupos = {
				{ titulo = "En combate", filas = {
					-- Para quien no cura (un guerrero), lo mismo es ver a su grupo y elegirlo.
					{ id = "curar", clave = "curacion.activo", titulo = cura and "Curar con un clic" or "Marcos de grupo de Alfa",
						texto = cura and "Marcos de grupo de Alfa: pasas el ratón sobre un compañero y haces clic para curarlo."
							or "Ves a tu grupo con su vida y lo seleccionas con un clic.",
						existe = function() return hay("curacion") and existe("curacion.activo") end,
						recomendar = function(rol) if rol == "cura" then return true end end },
					{ id = "rotacion", destacar = true, clave = "combate.rotacion", titulo = "Ayuda de rotación",
						texto = "Te sugiere qué habilidad usar ahora y cuáles siguen. Solo sugiere: nunca presiona nada por ti.",
						existe = function() return hay("combate") end,
						recomendar = function(rol) return rol ~= "cura" end },
					{ id = "avisos", clave = "combate.avisos", titulo = "Avisos de reacción",
						texto = "Te avisa cuando tu clase tiene algo que aprovechar ahora, como una habilidad que se encendió.",
						existe = function() return hay("combate") and existe("combate.avisos") end },
				} },
				{ titulo = "En el mundo", filas = {
					fila({ id = "recoleccion", titulo = "Minas, hierbas y tesoros en tu mapa",
						texto = "Solo los de tus profesiones, en el mapa del mundo y en el minimapa." },
						juntas({ "recoleccion.mapa", "recoleccion.minimapa" }, true, function() return hay("recoleccion") end)),
				} },
			},
		},
	}
end

---------------------------------------------------------------------------
-- 1.2.4: el asistente ya no enseña las listas de entrada. Tres perfiles
-- (tarjetas grandes) escriben de un clic las filas de misiones, tu guía,
-- comerciantes y viajes y otros jugadores; las listas siguen detrás de
-- «Afinar cosa por cosa». Un valor nil deja esa fila como está (lo que
-- rechazas de otros jugadores es muy tuyo: ningún perfil lo toca).
---------------------------------------------------------------------------
M.PANTALLAS_PERFIL = { misiones = true, guia = true, comercio = true, gente = true }

-- 1.2.5: tus líneas de misiones («[Misión] está lista para entregar»,
-- «¡Misión completada!») te salen a ti; quien las mandaba al grupo también las
-- ve en su chat. Mandarlas al grupo no se toca: es decisión de cada quien.
N.Migracion(2, function(db)
	local s = type(db.settings) == "table" and db.settings or nil
	if not s then return end
	s.party = type(s.party) == "table" and s.party or {}
	s.party.chatEcho = true
end)

-- 1.2.9: Alfa sencillo o completo (Alfa_Nucleo/Modo.lua). De fábrica,
-- sencillo (quien empieza ve lo esencial); quien ya tenía Alfa sigue con
-- todo Alfa a la vista: se le anota «completo» una vez. Nunca encima de lo
-- que ya eligió. 1.3.1: unos ajustes de antes que se restauran o se aplican
-- (o.vieja, N.MigrarDesde) son de quien ya tenía Alfa aunque la cuenta parezca nueva.
N.Migracion(3, function(db, o)
	local s = type(db.settings) == "table" and db.settings or nil
	if not s then return end
	if not (type(o) == "table" and o.vieja) and A.IsNewAccount and A.IsNewAccount() then return end
	s.bienvenida = type(s.bienvenida) == "table" and s.bienvenida or {}
	if s.bienvenida.modo == nil then s.bienvenida.modo = "completo" end
end)

-- { valor, texto, icono, titulo, explica }: el desplegable de Ajustes y las tarjetas del asistente.
M.MODOS = {
	{ valor = "sencillo", icono = "ic-huella", titulo = "Alfa sencillo", sobre = "Para empezar",
		-- 1.3.6: «Mundo», como la página.
		texto = "Solo lo esencial a la vista: Hoy, Ruta, Mundo, Bolsas, Talentos y Lya, y menos avisos. Lo demás sigue ahí cuando lo busques." },
	{ valor = "completo", icono = "ic-lobo", titulo = "Alfa completo",
		texto = "Todas las páginas de Alfa a la vista: mazmorras, talentos, combate, oficios, la manada y más." },
}
function M.OPCIONES_MODO()
	return { { valor = "sencillo", texto = M.L["Sencillo"] }, { valor = "completo", texto = M.L["Completo"] } }
end

M.PERFILES = {
	{ valor = "manada", icono = "ic-lobo", titulo = "Alfa lo hace por ti",
		texto = "Acepta y entrega tus misiones, elige tu guía y sigue sola, vende, repara y toma tus vuelos. Tú solo juegas.",
		filas = { aceptar = true, entregar = true, soloRuta = true, todas = true, grises = true, cerrarSaltadas = true, avisarCierra = true,
			mejorRecompensa = true, ponerRecompensa = true, elegirGuia = true, siguienteGuia = true, zona = true, mientras = true,
			clase = true, instructor = "2", flecha = true, camino = true, charla = true, pasoPide = true,
			vender = true, reparar = true, repararHermandad = true, comprar = true, despojar = true, mapaVuelo = true,
			tomarVuelo = true, hogar = true, invocar = true, resucitar = true, grupoAmigos = true, liberar = true,
			progresoGrupo = true, barcos = true } },
	{ valor = "equilibrio", icono = "ic-huella", titulo = "Equilibrado", sobre = "Recomendado",
		texto = "Alfa se encarga de lo repetitivo (aceptar, entregar, vender, reparar) y te pregunta en los cruces del camino.",
		filas = { aceptar = true, entregar = true, soloRuta = true, todas = false, grises = true, cerrarSaltadas = false, avisarCierra = true,
			mejorRecompensa = false, ponerRecompensa = true, elegirGuia = true, siguienteGuia = false, zona = false, mientras = true,
			clase = true, instructor = "2", flecha = true, camino = true, charla = true, pasoPide = true,
			vender = true, reparar = true, repararHermandad = true, comprar = false, despojar = true, mapaVuelo = true,
			tomarVuelo = false, hogar = false, invocar = true, resucitar = true, grupoAmigos = true, liberar = true,
			progresoGrupo = true, barcos = true } },
	{ valor = "yo", icono = "ic-personaje", titulo = "Yo decido",
		texto = "Alfa te guía con la flecha y te avisa, pero tú aceptas, entregas, eliges y viajas. Lo mínimo: vender lo gris y reparar.",
		filas = { aceptar = false, entregar = false, soloRuta = true, todas = false, grises = true, cerrarSaltadas = false, avisarCierra = true,
			mejorRecompensa = false, ponerRecompensa = false, elegirGuia = false, siguienteGuia = false, zona = false, mientras = false,
			clase = true, instructor = "2", flecha = true, camino = true, charla = false, pasoPide = false,
			vender = true, reparar = true, repararHermandad = false, comprar = false, despojar = true, mapaVuelo = false,
			tomarVuelo = false, hogar = false, invocar = false, resucitar = false, grupoAmigos = false, liberar = false,
			progresoGrupo = true, barcos = true } },
}

-- Los extras: un mosaico de tarjetas que se prenden con un clic (filas de
-- las pantallas «apariencia» y «personaje», y resaltar lo de misión).
M.EXTRAS = {
	-- 1.2.5: avisar a tu grupo de tus misiones, a la vista (REGLAS-BLIZZARD.md: se pregunta, viene apagado).
	{ "chatGrupo", "ic-manada" },
	{ "rotacion", "ic-nivel" }, { "curar", "ic-curacion" }, { "avisos", "ic-alerta" }, { "resaltar", "ic-misiones" },
	{ "recoleccion", "ic-recoleccion" }, { "terreno", "ic-mapa" }, { "paisaje", "ic-mundo" },
	{ "estiloChat", "ic-conexiones" }, { "estiloMinimapa", "ic-cerca" }, { "estiloBarras", "ic-rejilla" },
}

-- Lo que el resumen y la página dicen de los idiomas: cada uno en el suyo.
M.IDIOMAS = {
	{ "esMX", "Español (Latinoamérica)" },
	{ "esES", "Español (España)" },
	{ "enUS", "English" },
	{ "deDE", "Deutsch" },
	{ "frFR", "Français" },
	{ "ptBR", "Português (Brasil)" },
	{ "ruRU", "Русский" },
	{ "koKR", "한국어" },
	{ "zhCN", "简体中文" },
	{ "zhTW", "繁體中文" },
}

-- La lista de Alfa_Idioma manda, si está.
if type(rawget(_G, "AlfaIdiomas")) == "table" and #AlfaIdiomas > 0 then M.IDIOMAS = AlfaIdiomas end

function M.NombreIdioma(loc)
	for _, x in ipairs(M.IDIOMAS) do if x[1] == loc then return x[2] end end
	return loc
end

-- El idioma del cliente, como uno de la lista (enGB es inglés). Se guarda la
-- función sin llamarla: tools/build.py cambia las llamadas a esa función por
-- el idioma de Alfa, y aquí hace falta el del juego.
local idiomaJuego = GetLocale

function M.IdiomaDelJuego()
	local loc = idiomaJuego and idiomaJuego() or "esMX"
	if loc == "enGB" then return "enUS" end
	for _, x in ipairs(M.IDIOMAS) do if x[1] == loc then return loc end end
	return "enUS"
end

-- El idioma que usa Alfa en esta sesión (Alfa_Idioma: AlfaIdioma) o, sin
-- él, el que elegiste aquí o el del cliente.
function M.IdiomaActual()
	local f = rawget(_G, "AlfaIdioma")
	if type(f) == "function" then
		local ok, loc = pcall(f)
		if ok and type(loc) == "string" then return loc == "enGB" and "enUS" or loc end
	end
	local e = N.Get(M.ID, "idioma")
	if type(e) == "string" and e ~= "" then return e end
	if type(N.locale) == "string" then return N.locale == "enGB" and "enUS" or N.locale end
	return M.IdiomaDelJuego()
end
