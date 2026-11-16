-- Alfa - La Jauría: el módulo. Registra la página, los ajustes y el comando
-- /alfa manada, y mueve todo lo demás: el pulso (grupo, envío de tu posición,
-- pines) y los eventos de la hermandad y los amigos. Toxic / La Jauría. GPL-3.0.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID
local G, R, S, Mapa, P = M.Gente, M.Red, M.Seguir, M.Mapa, M.Pagina

local PULSO = 2       -- segundos: grupo, envío de posición y pines
local LIMPIEZA = 30   -- segundos: posiciones que caducan

N.Modulo({
	id = ID,
	nombre = L["La Jauría"],
	icono = "flag",
	orden = 8,
	subtitulo = L["Tu manada en el mapa: grupo, hermandad y amigos. Síguelos con la flecha y conoce al clan."],
	comando = "manada",
	ajustes = {
		red = true,               -- hablar con los otros Alfa (saludo, respuestas, posiciones)
		compartir = false,        -- mi ubicación a la hermandad (se pregunta la primera vez)
		compartirAmigos = false,  -- mi ubicación a mis amigos con Alfa
		verAmigos = true,         -- ver a los amigos que me comparten
		capaGrupo = true, capaJauria = true, capaAmigos = true,
		minimapa = true,
		verDesconectados = false,
	},
	construir = P.Construir,
})

---------------------------------------------------------------------------
-- Comando: /alfa manada [seguir <nombre> | parar | compartir sí/no | clan | ajustes | estado]
---------------------------------------------------------------------------

local function ayuda()
	U.Decir(L["La Jauría: tus comandos"])
	local hex = N.HEX
	for _, l in ipairs({
		{ "/alfa manada", L["abre la página de La Jauría"] },
		{ "/alfa manada seguir <nombre>", L["la flecha te lleva con esa persona"] },
		{ "/alfa manada parar", L["deja de seguir"] },
		{ "/alfa manada compartir sí|no", L["compartir tu ubicación con la hermandad"] },
		{ "/alfa manada clan", L["la página del clan y cómo unirte"] },
		{ "/alfa manada estado", L["qué se envía y qué se recibe ahora"] },
	}) do
		DEFAULT_CHAT_FRAME:AddMessage("  " .. hex .. l[1] .. "|r  " .. l[2])
	end
end

local SI = { ["si"] = true, ["sí"] = true, ["on"] = true, ["yes"] = true, ["1"] = true }
local NO = { ["no"] = true, ["off"] = true, ["0"] = true }

local function estado()
	local diag = R.diag
	local puede, por = R.PuedeEnviar()
	U.Decir(L["La Jauría: estado"])
	local lineas = {
		L["Conexión con la manada: %s"]:format(N.Get(ID, "red") and L["encendida"] or L["apagada"]),
		L["Compartir con la hermandad: %s · con amigos: %s"]:format(N.Get(ID, "compartir") and L["sí"] or L["no"], N.Get(ID, "compartirAmigos") and L["sí"] or L["no"]),
		L["Se puede enviar ahora: %s"]:format(puede and L["sí"] or (L["no"] .. " (" .. tostring(por) .. ")")),
		L["Mensajes enviados: %d (frenados: %d) · recibidos: %d · en cola: %d"]:format(diag.enviados, diag.frenados, diag.recibidos, R.Pendientes()),
	}
	local env = R.UltimoEnvio()
	if env then lineas[#lineas + 1] = L["Última posición enviada %s."]:format(U.Hace(env)) end
	local con, usan = G.Cuentas()
	lineas[#lineas + 1] = L["Hermandad: %d conectados, %d con Alfa · grupo: %d"]:format(con, usan, #G.Grupo())
	local s = S.Actual()
	if s then lineas[#lineas + 1] = L["Siguiendo a %s."]:format(s.nombre or "?") end
	for _, l in ipairs(lineas) do DEFAULT_CHAT_FRAME:AddMessage("  " .. l) end
end

A.RegisterCommand("manada", function(rest)
	local cmd, arg = tostring(rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = U.Plegar(cmd or "")
	if cmd == "" then
		P.Abrir()
	elseif cmd == "seguir" or cmd == "follow" then
		if arg == "" then P.Abrir("manada") else S.PorNombre(arg) end
	elseif cmd == "parar" or cmd == "stop" then
		if not S.Parar() then U.Decir(L["No estás siguiendo a nadie."]) end
	elseif cmd == "compartir" or cmd == "share" then
		local v = U.Plegar(arg)
		if SI[v] then
			N.Set(ID, "compartir", true)
			N.Datos(ID).preguntado = true
			U.Decir(L["Compartes tu ubicación con tu hermandad."])
		elseif NO[v] then
			N.Set(ID, "compartir", false)
			N.Datos(ID).preguntado = true
			U.Decir(L["Ya no compartes tu ubicación con tu hermandad."])
		else
			U.Decir(N.Get(ID, "compartir") and L["Compartes tu ubicación con tu hermandad."] or L["No compartes tu ubicación con tu hermandad."])
		end
	elseif cmd == "clan" or cmd == "unirme" or cmd == "unirse" or cmd == "join" then
		P.Abrir("clan")
	elseif cmd == "ajustes" or cmd == "settings" then
		P.Abrir("ajustes")
	elseif cmd == "estado" or cmd == "status" then
		estado()
	else
		ayuda()
	end
end, L["La Jauría: tu manada en el mapa, Seguir y la página del clan (/alfa manada ayuda)"])

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
	R.Tick(G.AmigosConAlfa())
	Mapa.Refrescar()
end

A.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	luego("grupo", 0.5, function()
		G.LeerGrupo()
		Mapa.Refrescar(true)
	end)
end)

A.RegisterEvent("GUILD_ROSTER_UPDATE", function()
	luego("hermandad", 2, G.LeerHermandad)
end)

local enHermandad
A.RegisterEvent("PLAYER_GUILD_UPDATE", function()
	luego("mihermandad", 1, function()
		local ahora = U.EnHermandad()
		if enHermandad and not ahora then G.OlvidarVia("hermandad") end
		if ahora and enHermandad == false then
			-- Recién llegado a una hermandad: saluda y pide su lista.
			R.SaludarHermandad(true)
			G.PedirHermandad(true)
		end
		enHermandad = ahora
		G.LeerHermandad()
		P.Rehacer()
	end)
end)

A.RegisterEvent("FRIENDLIST_UPDATE", function()
	luego("amigos", 1, G.LeerAmigos)
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

-- Ajustes: lo que se apaga se avisa ya; lo que se enciende saluda.
local antes = {}
local function leerAjustes()
	local t = {}
	for _, k in ipairs({ "red", "compartir", "compartirAmigos", "verAmigos" }) do t[k] = N.Get(ID, k) and true or false end
	return t
end

A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" then return end
	if not (path == "" or path == ID or path:sub(1, #ID + 1) == ID .. ".") then return end
	local ahora = leerAjustes()
	R.Escuchar()
	R.AlCambiarAjustes()
	if antes.red and not ahora.red then G.OlvidarTodo() end
	if antes.verAmigos and not ahora.verAmigos then G.OlvidarVia("amigo") end
	if ahora.red and antes.red == false then R.SaludarHermandad(true) end
	if ahora.compartirAmigos and not antes.compartirAmigos then
		R.OlvidarSaludos()
		G.LeerAmigos()
	end
	if ahora.compartir and not antes.compartir then R.ForzarPosicion() end
	antes = ahora
	Mapa.AlCambiarAjustes()
	P.Rehacer()
end)

A.OnLogin(function()
	antes = leerAjustes()
	enHermandad = U.EnHermandad()
	dentro = U.EnInstancia()
	R.Escuchar()
	G.PodarVistos()
	Mapa.RegistrarEnMundo()
	A.NewTicker(PULSO, alPulso)
	A.NewTicker(LIMPIEZA, function()
		G.Limpiar()
		Mapa.Refrescar(true)
	end)
	A.After(5, function()
		G.PedirHermandad(true)
		G.PedirAmigos()
		G.LeerAmigos()
	end)
	A.After(20, function() R.SaludarHermandad() end)
	-- La pregunta de privacidad: un minuto después de entrar, solo en una hermandad.
	A.After(60, function()
		if U.EnHermandad() and not U.EnInstancia() then P.Preguntar() end
	end)
end)
