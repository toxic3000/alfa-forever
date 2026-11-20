-- Alfa - La Jauría: el módulo. Registra la página, los ajustes y el comando
-- /alfa manada, mueve el pulso (grupo, envío de tu posición, marcas del mapa)
-- y publica el contrato AlfaManada para otras áreas. toxic3000 / La Jauría. GPL-3.0.
--
-- Contrato (global AlfaManada):
--   AlfaManada.PreguntarCompartir(alTerminar)  la ventana "¿Compartes tu
--       ubicación con La Jauría?" (la llama el asistente de primer arranque);
--       alTerminar(comparte) al responder o cerrar
--   AlfaManada.Compartir(si)     enciende o apaga compartir (sin preguntar)
--   AlfaManada.Comparte()        true si compartes tu ubicación
--   AlfaManada.Abrir()           abre la página de La Jauría
--   AlfaManada.Resumen()         { comparte, manada, grupo, siguiendo, via }:
--       cuántos de la manada (sin tu grupo) y de tu grupo se ven ahora, a
--       quién sigues (nombre o nil) y por dónde sale tu rastro
--   AlfaManada.Insignia(nombre)  "alfa" | "jauria" | nil: la insignia de un
--       personaje ("Nombre Apellido", "Nombre-Reino"; la lista y cómo se
--       comparan los nombres: Insignias.lua)
--   AlfaManada.InsigniaDeUnidad(unit)  lo mismo para una unidad del juego
--   AlfaManada.EstiloInsignia(tipo)  { texto, icono, color = { r, g, b } } o
--       nil: cómo se dibuja, para que se vea igual en todas partes
--   AlfaManada.CambiarPlano()    (1.2.9) «Cambiar de plano»: pide a la manada
--       con la guarida abierta en otro plano de tu zona que te invite; avisa
--       si no se puede (y ofrece preguntar a la manada). -> ok, motivo
--   AlfaManada.Plano()           (1.2.9) { capa, nombre, nivel, puntos, texto }
--       o nil: tu plano ahora y cómo está de lleno
--   AlfaManada.Red               (1.3.0) los mensajes ocultos de la manada
--       para otros módulos: .EnviarHermandad(clave, tipo, texto),
--       .EnviarLibre(clave, tipo, texto, destino) (susurro) y
--       .Escuchar(tipo, fn(clave, remitente, campos, canal), libre). `tipo` es
--       una letra que nadie use (Red.lua: la lista); 1Y es de Alfa_Lya.
--   AlfaManada.Tablon(), .Mentor(), .Botin()  (1.3.0) lo que hay: anuncios del
--       tablón, tu mentor y tus aprendices, las sugerencias de regalo
--   AlfaManada.MisionesDe(nombre)  (1.3.1) { [questID] = true } con las
--       misiones que ese lobo dijo a la manada (1M, Juntos.lua), o nil si no
--       se sabe (no compartes, cazarJuntos apagado, no lo dijo o hace más de
--       15 min): con nil, quien pregunta usa lo del juego. "Ana Smith" o
--       "Ana Smith-Reino". (Rutas: MapaGrupo.lua y Grupo.lua)
--
-- Sin asistente de primer arranque (Alfa_Bienvenida), la pregunta sale sola
-- una vez, al poco de entrar, fuera de combate y de instancias.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID
local G, R, S, Mapa, P, C = M.Gente, M.Red, M.Seguir, M.Mapa, M.Pagina, M.Canal

local PULSO = 2       -- segundos: grupo, envío de posición y marcas
local LIMPIEZA = 30   -- segundos: posiciones que caducan
local CONSENTIMIENTO = 2 -- la versión de la pregunta (la 0.1.0 preguntaba por la hermandad)

local function on(clave) return N.Get(ID, clave) and true or false end

N.Modulo({
	id = ID,
	nombre = L["La Jauría"],
	icono = "ic-manada",
	orden = 8,
	subtitulo = L["Tu manada en el mapa: tu grupo y quienes usan Alfa y comparten. Síguelos con la flecha, invítalos y conoce al clan."],
	comando = "manada",
	ajustes = {
		compartir = false,  -- mi ubicación a La Jauría (se pregunta al instalar)
		capaGrupo = true, capaJauria = true,
		minimapa = true,
		invitarMenu = true, -- «Invitar al clan» en el clic derecho de un jugador
		insigniaRetrato = true, -- la insignia de La Jauría en el borde del retrato (1.2.2)
		guaridaAbierta = false, -- invitar a quien pida entrar a tu guarida (capa) (1.2.4)
		rarosManada = true, -- los raros que encuentra la manada, con su guarida (1.2.5)
		guaridaVisible = true, -- tu guarida en el rastreador y el aviso al cambiar (1.2.5)
		llamados = true, -- recibir los llamados de ayuda de la manada (1.2.6)
		marcarRaro = true, -- en grupo, ofrecer la calavera para el raro que seleccionas (1.2.7)
		cazarJuntos = true, -- compartir tus misiones con la manada y ver con quién cazar (1.2.7)
		saludo = true, -- al entrar, quién de tu hermandad anda conectado (1.2.7)
		citas = true, -- proponer y recibir citas de la manada (1.2.8)
		quienVa = true, -- al llegar a una zona con mazmorra, quién de la manada podría ir (1.2.8)
		rarosReloj = true, -- cuándo cazaron un raro y si pudo volver (1.2.8)
		notas = true, -- tus notas en el mapa (1.2.8)
		notasCompartir = false, -- tus notas también para la manada, y las suyas (1.2.8)
		planoAviso = true, -- Lya propone cambiar de plano cuando está lleno (1.2.9)
		quienTiene = false, -- contestar «¿Quién tiene...?» con lo que llevas (1.2.9)
		logros = true, -- festejar los logros de la manada (1.2.9)
		logrosCompartir = false, -- tu hermandad se entera de tus logros (1.2.9)
		semanaCompartir = false, -- tu semana suma en la de la manada (1.2.9)
		spots = true, -- los spots de farmeo en su capa del mapa (1.3.0)
		spotsCompartir = false, -- tus spots también para tu hermandad, y los suyos (1.3.0)
		tablon = true, -- el tablón de la manada: quién busca grupo (1.3.0)
		mentor = true, -- adoptar aprendices y recibir propuestas de mentor (1.3.0)
		botin = true, -- sugerir regalar lo que le sirve a otro lobo (1.3.0)
		botinCompartir = false, -- tu clase y nivel a tu hermandad, para el botín (1.3.0)
		guaridasMapa = true, -- las guaridas de la manada en el mapa (1.3.0)
		calendario = true, -- el calendario de la semana con las citas (1.3.0)
	},
	construir = P.Construir,
})

---------------------------------------------------------------------------
-- El contrato
---------------------------------------------------------------------------

AlfaManada = type(AlfaManada) == "table" and AlfaManada or {}

function AlfaManada.PreguntarCompartir(alTerminar)
	return P.Preguntar({ alTerminar = alTerminar })
end

function AlfaManada.Compartir(si)
	N.Datos(ID).preguntado = true
	N.Set(ID, "compartir", si and true or false)
end

function AlfaManada.Comparte() return on("compartir") end

function AlfaManada.Abrir() P.Abrir() end


function AlfaManada.Resumen()
	local manada, grupo = G.Cuentas()
	local s = S.Actual()
	return { comparte = on("compartir"), manada = manada, grupo = grupo, siguiendo = s and s.nombre or nil, via = (R.Via()) }
end

function AlfaManada.Insignia(nombre) return M.Insignias.De(nombre) end
-- El nombre de tu guarida ahora («Guarida Colmillo»), o nil (1.2.5).
function AlfaManada.Guarida()
	if not on("guaridaVisible") then return nil end
	local a = M.Guaridas and M.Guaridas.Actual()
	return a and M.Guaridas.Nombre(a.capa) or nil
end
function AlfaManada.InsigniaDeUnidad(unit) return M.Insignias.DeUnidad(unit) end
-- 1.2.9: cambiar de plano (Plano.lua). Lo usa el botón de la página, /alfa
-- plano y quien quiera ofrecerlo (el menú de Lya, por ejemplo).
function AlfaManada.CambiarPlano()
	if not M.Plano then return false, "sinplano" end
	return M.Plano.CambiarYDecir()
end
function AlfaManada.Plano()
	local a = M.Guaridas and M.Guaridas.Actual()
	if not (a and M.Plano) then return nil end
	local e = M.Plano.Estado()
	return { capa = a.capa, nombre = M.Guaridas.Nombre(a.capa), nivel = e.nivel, puntos = e.puntos, texto = M.Plano.Texto(e) }
end
function AlfaManada.EstiloInsignia(tipo) return M.Insignias.Estilo(tipo) end

-- 1.3.0: la red de la manada para otros módulos (Lya se saluda con 1Y).
local externos = {}
local function tipoValido(tipo)
	return type(tipo) == "string" and #tipo == 1 and tipo:match("^%a$") ~= nil
end
AlfaManada.Red = {
	EnviarHermandad = function(clave, tipo, texto)
		if not tipoValido(tipo) or type(texto) ~= "string" then return false end
		return R.EnviarHermandad("ext:" .. tostring(clave), "1" .. tipo .. "|" .. texto)
	end,
	EnviarLibre = function(clave, tipo, texto, destino)
		if not tipoValido(tipo) or type(texto) ~= "string" then return false end
		return R.EnviarLibre("ext:" .. tostring(clave), "1" .. tipo .. "|" .. texto, destino)
	end,
	-- fn(clave, remitente, campos, canal). `libre`: llega por la hermandad
	-- aunque no compartas tu ubicación (cada quien revisa su propio ajuste).
	Escuchar = function(tipo, fn, libre)
		if not tipoValido(tipo) or type(fn) ~= "function" then return false end
		-- Un tipo de La Jauría no se pisa; uno de fuera, sí (su dueño lo renueva).
		if R.Oyentes[tipo] and not externos[tipo] then return false end
		externos[tipo] = true
		R.Oyentes[tipo] = function(clave, remitente, _, campos, canal) pcall(fn, clave, remitente, campos, canal) end
		if libre then R.Libres[tipo] = true end
		return true
	end,
}
function AlfaManada.Tablon() return M.Tablon and M.Tablon.Lista() or {} end
function AlfaManada.Mentor()
	if not M.Mentor then return nil end
	return { mentor = M.Mentor.Mentor(), aprendices = M.Mentor.Aprendices() }
end
function AlfaManada.Botin() return M.Botin and M.Botin.Sugerencias() or {} end
-- 1.3.1: las misiones de un lobo (Juntos.lua), o nil si no se sabe.
function AlfaManada.MisionesDe(nombre)
	if not (M.Juntos and M.Juntos.De) then return nil end
	return M.Juntos.De(nombre)
end

---------------------------------------------------------------------------
-- Comando: /alfa manada [seguir <nombre> | parar | compartir sí/no | estado]
---------------------------------------------------------------------------

local function ayuda()
	U.Decir(L["La Jauría: tus comandos"])
	local hex = N.HEX
	for _, l in ipairs({
		{ "/alfa manada", L["abre la página de La Jauría"] },
		{ "/alfa manada seguir <nombre>", L["la flecha te lleva con esa persona"] },
		{ "/alfa manada parar", L["deja de seguir"] },
		{ "/alfa manada compartir sí|no", L["que la manada vea a tu personaje en el mapa"] },
		{ "/alfa manada estado", L["qué se envía y qué se recibe ahora"] },
		{ "/alfa manada llamar", L["pide ayuda a los lobos de tu zona"] },
		{ "/alfa plano", L["pásate al plano de un lobo de la manada"] },
		{ "/alfa manada tiene <objeto>", L["pregunta a tu hermandad quién lo tiene"] },
		{ "/alfa cita mañana 21:30 <qué>", L["propón una salida a la manada"] },
		{ "/alfa nota <texto>", L["deja una nota en tu mapa donde estás"] },
		{ "/alfa spot <texto>", L["marca un spot de farmeo donde estás"] },
		{ "/alfa manada tablon <texto>", L["pon tu anuncio en el tablón de la manada"] },
	}) do
		DEFAULT_CHAT_FRAME:AddMessage("  " .. hex .. l[1] .. "|r  " .. l[2])
	end
end

local SI = { ["si"] = true, ["sí"] = true, ["on"] = true, ["yes"] = true, ["1"] = true }
local NO = { ["no"] = true, ["off"] = true, ["0"] = true }

local VIAS = { canal = "el canal oculto de Alfa", hermandad = "tu hermandad" }

local function estado()
	local diag = R.diag
	local puede, por = R.PuedeEnviar()
	local via, porVia = R.Via()
	local ce, cr = C.Estado()
	U.Decir(L["La Jauría: estado"])
	local lineas = {
		L["La manada te ve en el mapa: %s"]:format(on("compartir") and L["sí"] or L["no"]),
		L["Se puede enviar ahora: %s"]:format(puede and L["sí"] or (L["no"] .. " (" .. tostring(por) .. ")")),
		L["Por dónde sale: %s"]:format(via and L[VIAS[via]] or (L["ninguno"] .. " (" .. tostring(porVia) .. ")")),
		L["Canal oculto: %s (%s, número %s, intentos %d)"]:format(C.NOMBRE, tostring(ce) .. (cr and ("/" .. tostring(cr)) or ""), tostring(C.Id() or "-"), C.Intentos()),
		L["Mensajes enviados: %d (frenados: %d) · recibidos: %d · en cola: %d"]:format(diag.enviados, diag.frenados, diag.recibidos, R.Pendientes()),
	}
	if diag.resultado ~= nil then lineas[#lineas + 1] = L["Último envío: %s por %s, respuesta %s"]:format(tostring(diag.ultimo), tostring(diag.por), tostring(diag.resultado)) end
	local env = R.UltimoEnvio()
	if env then lineas[#lineas + 1] = L["Última posición enviada %s."]:format(U.Hace(env)) end
	local manada, grupo = G.Cuentas()
	lineas[#lineas + 1] = L["A la vista: %d de la manada · %d de tu grupo"]:format(manada, grupo)
	if C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted then
		local ok, r = pcall(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)
		if ok and U.Leer(r) ~= nil then lineas[#lineas + 1] = L["El reino limita los mensajes de addon salientes: %s"]:format(U.Leer(r) and L["sí"] or L["no"]) end
	end
	local s = S.Actual()
	if s then lineas[#lineas + 1] = L["Siguiendo a %s."]:format(s.nombre or "?") end
	for _, l in ipairs(lineas) do DEFAULT_CHAT_FRAME:AddMessage("  " .. l) end
end

A.RegisterCommand("manada", function(rest)
	local cmd, arg = tostring(rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = U.Plegar(cmd or "")
	if cmd == "" then
		P.Abrir()
	elseif cmd == "llamar" or cmd == "call" then
		if M.Llamado then M.Llamado.LlamarYDecir() end
	elseif cmd == "plano" or cmd == "layer" then
		AlfaManada.CambiarPlano()
	elseif (cmd == "tiene" or cmd == "quien" or cmd == "quién" or cmd == "who") and M.QuienTiene then
		if arg == "" then P.Abrir() else M.QuienTiene.BuscarYDecir(arg) end
	elseif cmd == "seguir" or cmd == "follow" then
		if arg == "" then P.Abrir() else S.PorNombre(arg) end
	elseif cmd == "parar" or cmd == "stop" then
		if not S.Parar() then U.Decir(L["No estás siguiendo a nadie."]) end
	elseif cmd == "compartir" or cmd == "share" then
		local v = U.Plegar(arg)
		if SI[v] then
			AlfaManada.Compartir(true)
			U.Decir(L["La manada ya ve a tu personaje en el mapa del juego."])
		elseif NO[v] then
			AlfaManada.Compartir(false)
			U.Decir(L["La manada ya no ve a tu personaje en el mapa."])
		else
			U.Decir(on("compartir") and L["La manada ya ve a tu personaje en el mapa del juego."] or L["La manada no ve a tu personaje en el mapa."])
		end
	elseif cmd == "estado" or cmd == "status" then
		estado()
	elseif cmd == "cita" and M.Cita then
		if arg == "" then P.Abrir() else
			local que, cuando = M.Cita.Leer(arg)
			if que then M.Cita.ProponerYDecir(que, cuando) else U.Decir(L["Así: /alfa cita mañana 21:30 Minas de la Muerte"]) end
		end
	elseif (cmd == "tablon" or cmd == "tablón" or cmd == "board") and M.Tablon then
		if arg == "" then P.Abrir() else M.Tablon.PonerYDecir("m", arg) end
	elseif cmd == "spot" and M.Notas then
		if arg == "" then U.Decir(L[M.Notas.MOTIVOS.textoSpot]) else M.Notas.AgregarYDecir(arg, "spot") end
	elseif cmd == "nota" and M.Notas then
		if arg == "" then U.Decir(L[M.Notas.MOTIVOS.texto]) else M.Notas.AgregarYDecir(arg) end
	else
		ayuda()
	end
end, L["La Jauría: tu manada en el mapa, Seguir y el clan (/alfa manada ayuda)"])

-- 1.2.9: /alfa plano (sin más: cambiar de plano; «estado»: cómo está el tuyo).
A.RegisterCommand("plano", function(rest)
	local cmd = U.Plegar(tostring(rest or ""))
	if cmd == "estado" or cmd == "status" then
		local p = AlfaManada.Plano()
		U.Decir(p and L["Estás en la %s. Cómo está: %s."]:format(p.nombre, p.texto) or L[M.Plano.MOTIVOS.sincapa])
	else
		AlfaManada.CambiarPlano()
	end
end, L["Cambiar de plano: te pasa al de un lobo de la manada con su guarida abierta"])

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

local pendiente = {}
local function luego(clave, seg, fn)
	if pendiente[clave] then return end
	pendiente[clave] = true
	A.After(seg, function()
		pendiente[clave] = nil
		fn()
	end)
end

local function alPulso()
	G.LeerGrupo()
	R.Tick()
	Mapa.Refrescar()
end

A.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	luego("grupo", 0.5, function()
		G.LeerGrupo()
		Mapa.Refrescar(true)
	end)
end)

-- Sin canal, la hermandad es el camino: al llegar a una, saludar.
A.RegisterEvent("PLAYER_GUILD_UPDATE", function()
	luego("hermandad", 2, function()
		if on("compartir") and R.Via() == "hermandad" then R.Saludar() end
		M.Avisar()
	end)
end)

-- Al salir de una instancia, la posición sale ya (la de antes ya caducó).
local dentro = false
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	local ahora = U.EnInstancia()
	if dentro and not ahora then R.ForzarPosicion() end
	dentro = ahora
	luego("grupo", 1, function()
		G.LeerGrupo()
		Mapa.Refrescar(true)
	end)
end)

-- Compartir: al encenderlo se entra al canal y se saluda; al apagarlo, la
-- despedida sale primero y luego se deja el canal.
local function salirDelCanal(intento)
	if on("compartir") then return end
	if R.Pendientes() > 0 and intento < 6 then
		A.After(1, function() salirDelCanal(intento + 1) end)
		return
	end
	C.Querer(false)
end

local antes
A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" then return end
	if not (path == "" or path == ID or path:sub(1, #ID + 1) == ID .. ".") then return end
	local ahora = on("compartir")
	if antes ~= nil and ahora ~= antes then
		if ahora then
			C.Querer(true)
			R.Saludar()
		else
			R.Despedir()
			G.OlvidarTodo()
			A.After(1, function() salirDelCanal(1) end)
		end
	end
	antes = ahora
	Mapa.AlCambiarAjustes()
	M.Avisar()
end)

---------------------------------------------------------------------------
-- Al entrar
---------------------------------------------------------------------------

local function hayBienvenida()
	if type(rawget(_G, "AlfaBienvenida")) == "table" then return true end
	local CA = C_AddOns
	if CA and CA.IsAddOnLoaded then
		local ok, v = pcall(CA.IsAddOnLoaded, "Alfa_Bienvenida")
		return ok and U.Leer(v) and true or false
	end
	return false
end

-- La pregunta, una sola vez, cuando no estorba.
local function preguntarSola(intento)
	local d = N.Datos(ID)
	if d.preguntado or on("compartir") or hayBienvenida() then return end
	local velo = rawget(_G, "AlfaKitVelo")
	local Kit = N.Kit
	local abierto = (Kit and Kit.DialogoAbierto and Kit.DialogoAbierto()) or (velo and velo.IsShown and velo:IsShown())
	local ocupado = U.EnInstancia() or (InCombatLockdown and InCombatLockdown()) or abierto
	if ocupado then
		if intento < 20 then A.After(30, function() preguntarSola(intento + 1) end) end
		return
	end
	P.Preguntar()
end

A.OnLogin(function()
	-- La 0.1.0 preguntaba por compartir con la hermandad: La Jauría es otra
	-- cosa (todos los que usan Alfa), así que se vuelve a preguntar.
	local d = N.Datos(ID)
	if d.consentimiento ~= CONSENTIMIENTO then
		d.consentimiento = CONSENTIMIENTO
		d.preguntado = nil
		d.visto = nil
		if on("compartir") then N.Set(ID, "compartir", false) end
	end
	antes = on("compartir")
	dentro = U.EnInstancia()
	R.Escuchar()
	Mapa.RegistrarEnMundo()
	N.Cada("manada.pulso", PULSO, alPulso)
	N.Cada("manada.limpieza", LIMPIEZA, function()
		G.Limpiar()
		Mapa.Refrescar(true)
	end)
	-- El canal, cuando el juego ya puso los suyos (Canal.lua espera al General).
	A.After(8, function()
		if on("compartir") then C.Querer(true) end
	end)
	-- Sin canal todavía, la hermandad: un saludo para ver ya a quien comparte.
	A.After(20, function()
		if on("compartir") and R.Via() == "hermandad" then R.Saludar() end
	end)
	A.After(20, function() preguntarSola(1) end)
	-- 1.2.8: Lya sabe contar lo nuevo de la manada (Pregúntale a Lya).
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
		for _, p in ipairs({
			{ id = "manada.cita", icono = "ic-reloj", pregunta = L["¿Cómo junto a la manada para una mazmorra?"],
				respuesta = L["En La Jauría, en «Citas de la manada», escribe qué, elige día y hora y pulsa «Proponer». A tu hermandad le llega con «Voy» y yo te recuerdo 15 minutos antes."] },
			{ id = "manada.quienva", icono = "ic-mazmorra", pregunta = L["¿Quién de la manada puede ir a una mazmorra conmigo?"],
				respuesta = L["Al llegar a una zona con una mazmorra para tu nivel, te digo quién de la manada anda cerca y va a tu nivel, con «Invitar»."] },
			{ id = "manada.reloj", icono = "ic-raros", pregunta = L["¿Cuándo vuelve un raro?"],
				respuesta = L["Cuando ves caer a un raro, me acuerdo: en su cuadro y en La Jauría te digo hace cuánto lo cazaron y si pudo volver ya (a la media hora, más o menos)."] },
			{ id = "manada.notas", icono = "icon-note", pregunta = L["¿Puedo dejar notas en el mapa?"],
				respuesta = L["Sí: escribe /alfa nota y tu texto, o usa «Nota aquí» en La Jauría. Sale en tu mapa donde estás; un clic y la flecha te lleva."] },
			-- 1.2.9
			{ id = "manada.plano", icono = "ic-manada", pregunta = L["¿Cómo me cambio de plano si hay mucha gente?"],
				respuesta = L["Pulsa «Cambiar de plano» en La Jauría o escribe /alfa plano: le pido a un lobo con su guarida abierta en otro plano que te invite. Acepta, y al llegar sales del grupo."] },
			{ id = "manada.quientiene", icono = "ic-bolsas", pregunta = L["¿Alguien de la manada tiene lo que busco?"],
				respuesta = L["En La Jauría, en «¿Quién tiene...?», escribe el objeto y pulsa «Buscar». Te contestan los lobos de tu hermandad que lo permiten, con «Susurrar» para pedírselo."] },
			{ id = "manada.semana", icono = "ic-reloj", pregunta = L["¿Qué hizo la manada esta semana?"],
				respuesta = L["En La Jauría está «La semana de la manada»: misiones, raros, mazmorras y niveles de los lobos que la comparten. Nadie compite: todo suma."] },
			-- 1.3.0
			{ id = "manada.spots", icono = "ic-recoleccion", pregunta = L["¿Dónde farmea la manada?"],
				respuesta = L["Marca un spot con «Spot aquí» en La Jauría o /alfa spot. Sale dorado en tu mapa y, si lo compartes, también en el de tu hermandad."] },
			{ id = "manada.tablon", icono = "ic-lista", pregunta = L["¿Cómo encuentro grupo en la manada?"],
				respuesta = L["En La Jauría está «El tablón de la manada»: pon qué buscas y a tu hermandad le llega. Se quita solo en una hora."] },
			{ id = "manada.mentor", icono = "ic-manada", pregunta = L["¿Puedo cuidar a un lobo nuevo?"],
				respuesta = L["Sí: en «Mentor», pulsa «Adoptar» junto a un lobo 10 niveles menor. Si acepta, ves cómo va y te aviso si se atora."] },
			{ id = "manada.botin", icono = "ic-bolsas", pregunta = L["¿Y si me sale algo que le sirve a otro lobo?"],
				respuesta = L["Te aviso con «Regalárselo»: abre el comercio si está a tu lado o te deja su nombre en el correo. Necesitan compartir su clase y nivel."] },
			{ id = "manada.guaridasvivo", icono = "ic-huella", pregunta = L["¿En qué guarida anda la manada?"],
				respuesta = L["En La Jauría, «Las guaridas de la manada» dice cuántos lobos hay en cada guarida de cada zona. En el mapa también sale."] },
			{ id = "manada.calendario", icono = "ic-reloj", pregunta = L["¿Qué citas tiene la manada esta semana?"],
				respuesta = L["En La Jauría, «El calendario de la manada» acomoda las citas de los próximos siete días."] },
		}) do
			p.modulo = ID
			pcall(Lya.Ensenar, p)
		end
	end
end)
