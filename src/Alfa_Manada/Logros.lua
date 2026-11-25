-- Alfa - La Jauría: los logros de la manada y la semana de la manada (1.2.9).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Logros: cuando un lobo de tu hermandad llega al nivel 60, consigue su
-- primera montura o caza un raro, Lya lo festeja (un aviso). Lo comparte solo
-- quien quiere (manada.logrosCompartir, apagado de fábrica); recibirlos viene
-- prendido (manada.logros).
--
-- La semana: Alfa cuenta tu semana (misiones entregadas, raros cazados,
-- mazmorras y niveles ganados) y, si quieres (manada.semanaCompartir, apagado
-- de fábrica), la comparte con tu hermandad. La tarjeta «La semana de la
-- manada» suma la de todos: sin primeros lugares, por nombre o por lo que
-- aportó cada quien. La semana empieza el lunes (hora del servidor).
--
-- Mensajes (Red.lua, solo por la hermandad; salen aunque no compartas tu
-- ubicación, con su propio permiso):
--   1E|n|<nivel>     llegué al nivel máximo
--   1E|m             mi primera montura
--   1E|r|<raro>      cacé un raro
--   1S|<semana>|<misiones>|<raros>|<mazmorras>|<niveles>|<peces>|<ayuda>   mi semana
--                    (1.4.0: peces y ayuda al final; un Alfa 1.3.x no los manda
--                    ni los lee: cuentan 0)
--   1F|<semana>      ¿me dicen su semana? (al abrir la página, cada 10 min)
--
--   Lo.Semana() -> { s, misiones, raros, mazmorras, niveles }   la tuya
--   Lo.Manada(orden) -> lista, totales   orden "nombre" | "aporte"
--   Lo.Festejar(tipo, quien, dato) -> true si lo dijo (para las pruebas)
--   Lo.MandarPendientes() -> n   (1.3.1) los logros que no salieron por estar
--                                en una instancia salen al volver (y cada minuto)
--
-- 1.4.0 (55): los logros de la semana. Tu semana suma también los peces que
-- sacaste (de los datos de Pesca, sin tocarlos) y los lobos que ayudaste
-- (Lo.Ayudar: «¡Voy!» a un llamado, abrir tu guarida, compartir tu plan o tu
-- guía, regalar botín, darle la bienvenida a alguien). Al llegar a una meta
-- (METAS), Lya lo festeja una vez por semana (manada.semanaLogros). Y en «La
-- semana de la manada», lo destacado: quién sacó más peces, quién entregó más
-- misiones y quién ayudó más (Lo.Destacados), con cariño y sin tabla de
-- posiciones.
--   Lo.Ayudar(que) ; Lo.Peces() -> n ; Lo.Destacados() -> { { que, nombre, n, tu } }
--   Lo.Metas() -> { { clave, n, meta, hecho } } ; Lo.RevisarMetas() -> festejadas

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Lo = {}
M.Logros = Lo

local type, pairs, ipairs, tonumber, tostring, format, sort, floor = type, pairs, ipairs, tonumber, tostring, string.format, table.sort, math.floor

local V = "1"
local CADA_LOGRO = 600     -- el mismo logro del mismo lobo, una vez cada tanto
local CADA_SEMANA = 300    -- tu semana sale como mucho cada 5 min
local CADA_PEDIR = 600     -- pedir la semana de los demás, cada 10 min
local CADA_RESPUESTA = 120 -- responder a un «¿me dicen su semana?», cada 2 min
local MAZMORRA_OTRA = 7200 -- la misma mazmorra cuenta otra vez a las 2 h
local NIVEL_MAX = 60

local function on(clave) return N.Get(ID, clave) and true or false end

Lo.version = 0
local function cambio()
	Lo.version = Lo.version + 1
	if M.Avisar then M.Avisar() end
end

local function limpiar(s, largo)
	if type(s) ~= "string" or U.Secreto(s) then return nil end
	s = U.Cortar((s:gsub("[|\n\r]", "")), largo or 48) -- (1.3.1) letras, no bytes
	return s ~= "" and s or nil
end

local function aviso(o)
	local K = N.Kit
	if M.U and M.U.Aviso then M.U.Aviso(o) else U.Decir(o.titulo .. (o.texto and (" " .. o.texto) or "")) end
end

local function nivelMax()
	local ok, n = pcall(GetMaxPlayerLevel)
	n = ok and U.Numero(n) or nil
	return n and n > 0 and n or NIVEL_MAX
end

---------------------------------------------------------------------------
-- Tu semana
---------------------------------------------------------------------------

-- Semanas desde el lunes 5 de enero de 1970 (el 1 fue jueves).
function Lo.NumeroSemana(t)
	t = tonumber(t) or U.Reloj()
	return floor((t + 3 * 86400) / 604800)
end

local CAMPOS = { "misiones", "raros", "mazmorras", "niveles" }
local CAMPOS2 = { "peces", "ayuda" } -- 1.4.0: al final del mensaje (un Alfa viejo no los lee)

function Lo.Semana()
	local d = N.DatosPersonaje(ID)
	local s = Lo.NumeroSemana()
	local w = d.semana
	if type(w) ~= "table" or w.s ~= s then
		w = { s = s, misiones = 0, raros = 0, mazmorras = 0, niveles = 0, peces = 0, ayuda = 0 }
		d.semana = w
	end
	w.peces = Lo.Peces(w)
	w.ayuda = tonumber(w.ayuda) or 0
	return w
end

-- 1.4.0: los peces de la semana: lo que sacaste desde que empezó (de los
-- datos de Pesca; la primera vez que se mira, cuenta desde ahora).
local function capturas()
	local d = N.DatosPersonaje("pesca")
	local v = type(d) == "table" and d.vida
	return type(v) == "table" and tonumber(v.capturas) or 0
end
function Lo.Peces(w)
	w = w or N.DatosPersonaje(ID).semana
	if type(w) ~= "table" then return 0 end
	local c = capturas()
	if tonumber(w.pecesBase) == nil or c < w.pecesBase then w.pecesBase = c end
	return math.max(0, c - w.pecesBase)
end

local sucia = false
local function sumar(campo, n)
	local w = Lo.Semana()
	w[campo] = (tonumber(w[campo]) or 0) + (n or 1)
	sucia = true
	cambio()
end
Lo.Sumar = sumar

local ultimaSemana = -math.huge
function Lo.CompartirSemana(forzar)
	if not on("semanaCompartir") then return false end
	local ahora = U.Ahora()
	if not forzar and ahora - ultimaSemana < CADA_SEMANA then return false end
	local w = Lo.Semana()
	if M.Red.EnviarHermandad("S", format("%sS|%d|%d|%d|%d|%d|%d|%d", V, w.s, w.misiones, w.raros, w.mazmorras, w.niveles, w.peces or 0, w.ayuda or 0)) then
		ultimaSemana = ahora
		sucia = false
		return true
	end
	return false
end

local pedida = -math.huge
function Lo.PedirSemanas()
	local ahora = U.Ahora()
	if ahora - pedida < CADA_PEDIR then return false end
	if not M.Red.EnviarHermandad("F", format("%sF|%d", V, Lo.NumeroSemana())) then return false end
	pedida = ahora
	return true
end

---------------------------------------------------------------------------
-- La semana de la manada
---------------------------------------------------------------------------

local function guardadas()
	local d = N.Datos(ID)
	if type(d.semanaManada) ~= "table" then d.semanaManada = {} end
	local s = Lo.NumeroSemana()
	for k, v in pairs(d.semanaManada) do
		if type(v) ~= "table" or v.s ~= s then d.semanaManada[k] = nil end
	end
	return d.semanaManada
end

local function numero(s, max)
	if type(s) ~= "string" or not s:match("^%d+$") or #s > 9 then return nil end
	local n = tonumber(s)
	return n and n <= max and n or nil
end

M.Red.Oyentes.S = function(clave, remitente, _, f, canal)
	if canal ~= "GUILD" then return end
	local s = numero(f[1], 10000000)
	local v = {}
	for i, campo in ipairs(CAMPOS) do
		v[campo] = numero(f[i + 1], 10000)
		if not v[campo] then return end
	end
	if s ~= Lo.NumeroSemana() then return end
	-- 1.4.0: peces y ayuda (un Alfa 1.3.x no los manda: 0).
	for i, campo in ipairs(CAMPOS2) do v[campo] = numero(f[#CAMPOS + 1 + i], 100000) or 0 end
	v.s, v.nombre = s, U.Mostrar(remitente)
	guardadas()[clave] = v
	cambio()
end

local respondida = -math.huge
M.Red.Oyentes.F = function(_, _, _, f, canal)
	if canal ~= "GUILD" or not on("semanaCompartir") then return end
	if numero(f[1], 10000000) ~= Lo.NumeroSemana() then return end
	local ahora = U.Ahora()
	if ahora - respondida < CADA_RESPUESTA then return end
	respondida = ahora
	A.After(2 + math.random() * 6, function() Lo.CompartirSemana(true) end)
end

-- La lista de la tarjeta y lo que suma la manada. Tú vas siempre (tu semana
-- no sale de tu computadora si no la compartes).
function Lo.Manada(orden)
	local lista = {}
	local tot = { misiones = 0, raros = 0, mazmorras = 0, niveles = 0, peces = 0, ayuda = 0, lobos = 0 }
	local function agregar(v, tu)
		local x = { nombre = tu and L["Tú"] or v.nombre, tu = tu, aporte = 0 }
		for _, c in ipairs(CAMPOS) do
			x[c] = tonumber(v[c]) or 0
			tot[c] = tot[c] + x[c]
			x.aporte = x.aporte + x[c]
		end
		-- 1.4.0: los peces y la ayuda se suman aparte (no pesan en «lo que aportó»).
		for _, c in ipairs(CAMPOS2) do
			x[c] = tonumber(v[c]) or 0
			tot[c] = tot[c] + x[c]
		end
		tot.lobos = tot.lobos + 1
		lista[#lista + 1] = x
	end
	agregar(Lo.Semana(), true)
	for _, v in pairs(guardadas()) do agregar(v, false) end
	sort(lista, function(a, b)
		if orden == "aporte" and a.aporte ~= b.aporte then return a.aporte > b.aporte end
		if a.tu ~= b.tu then return a.tu end
		return tostring(a.nombre) < tostring(b.nombre)
	end)
	return lista, tot
end

-- "12 misiones · 1 raro · 2 mazmorras · 3 niveles" (solo lo que no es cero).
local FORMAS = {
	misiones = { "%d misión", "%d misiones" }, raros = { "%d raro", "%d raros" },
	mazmorras = { "%d mazmorra", "%d mazmorras" }, niveles = { "%d nivel", "%d niveles" },
	peces = { "%d pez", "%d peces" }, ayuda = { "%d ayuda", "%d ayudas" },
}
function Lo.TextoCuenta(v, sep)
	local partes = {}
	for _, lista in ipairs({ CAMPOS, CAMPOS2 }) do
		for _, c in ipairs(lista) do
			local n = tonumber(v[c]) or 0
			if n > 0 then partes[#partes + 1] = format(L[FORMAS[c][n == 1 and 1 or 2]], n) end
		end
	end
	if #partes == 0 then return L["Aún nada esta semana"] end
	return table.concat(partes, sep or "  \194\183  ")
end

---------------------------------------------------------------------------
-- 1.4.0 (55): los logros de la semana
---------------------------------------------------------------------------

-- Ayudaste a un lobo (una vez por cosa y lobo cada tanto: lo cuenta quien ayuda).
local ayudados = {}
function Lo.Ayudar(que)
	que = tostring(que or "?")
	local ahora = U.Ahora()
	if ayudados[que] and ahora - ayudados[que] < 60 then return false end
	U.Podar(ayudados, 60, ahora)
	ayudados[que] = ahora
	sumar("ayuda")
	N.Una("manada.semanaMetas", 2, function() pcall(Lo.RevisarMetas) end)
	return true
end

-- Las metas de la semana, de la más fácil a la más grande en cada cosa.
Lo.METAS = {
	{ clave = "misiones", meta = 50, titulo = "Cazador de la semana", texto = "¡%d misiones esta semana! La manada aúlla por ti." },
	{ clave = "misiones", meta = 150, titulo = "Leyenda de la semana", texto = "¡%d misiones en una semana! Eso ya es de leyenda." },
	{ clave = "peces", meta = 50, titulo = "Pescador de la semana", texto = "¡%d peces esta semana! Me guardas uno, ¿verdad?" },
	{ clave = "peces", meta = 200, titulo = "Señor del agua", texto = "¡%d peces en una semana! El lago ya te conoce." },
	{ clave = "ayuda", meta = 3, titulo = "Buen lobo", texto = "Ayudaste a la manada %d veces esta semana. Así se caza en manada." },
	{ clave = "ayuda", meta = 10, titulo = "Corazón de la manada", texto = "¡%d veces ayudaste a la manada esta semana! Eres de los que hacen manada." },
	{ clave = "mazmorras", meta = 5, titulo = "Explorador de las profundidades", texto = "¡%d mazmorras esta semana! Y volviste para contarlo." },
}

function Lo.Metas()
	local w = Lo.Semana()
	local out = {}
	local hechas = type(w.metas) == "table" and w.metas or {}
	for i, m in ipairs(Lo.METAS) do
		local n = tonumber(w[m.clave]) or 0
		out[#out + 1] = { i = i, clave = m.clave, n = n, meta = m.meta, hecho = n >= m.meta, festejada = hechas[i] and true or false,
			titulo = L[m.titulo] }
	end
	return out
end

-- Lya festeja (una vez por semana cada meta) lo que alcanzaste. -> cuántas.
function Lo.RevisarMetas()
	if N.Get(ID, "semanaLogros") == false then return 0 end
	local w = Lo.Semana()
	w.metas = type(w.metas) == "table" and w.metas or {}
	local n = 0
	for i, m in ipairs(Lo.METAS) do
		local v = tonumber(w[m.clave]) or 0
		if v >= m.meta and not w.metas[i] then
			w.metas[i] = true
			n = n + 1
			local titulo, texto = L[m.titulo], format(L[m.texto], v)
			local Lya = rawget(_G, "AlfaLya")
			local dicho = false
			if type(Lya) == "table" and type(Lya.Decir) == "function" then
				local ok, r = pcall(Lya.Decir, format(L["¡Logro de la semana: %s! %s"], titulo, texto), { importante = true, aullar = true, id = "manada.semana" .. i })
				dicho = ok and (r == true or r == "espera")
			end
			if not dicho then aviso({ titulo = format(L["¡Logro de la semana: %s!"], titulo), texto = texto, lobo = "aullando", duracion = 12, detalle = true }) end
		end
	end
	if n > 0 then cambio() end
	return n
end

-- Lo destacado de la semana entre los lobos que la comparten (y tú): quién
-- sacó más peces, quién entregó más misiones y quién ayudó más. Solo si hay
-- dos lobos o más y algo que contar. -> { { que, titulo, nombre, n, tu } }
local DESTACA = {
	{ que = "peces", titulo = "Más peces" },
	{ que = "misiones", titulo = "Más misiones" },
	{ que = "ayuda", titulo = "Más ayuda" },
}
function Lo.Destacados()
	local lista, tot = Lo.Manada("nombre")
	local out = {}
	if tot.lobos < 2 then return out end
	for _, d in ipairs(DESTACA) do
		local mejor
		for _, x in ipairs(lista) do
			local n = tonumber(x[d.que]) or 0
			if n > 0 and (not mejor or n > mejor.n) then mejor = { nombre = x.nombre, n = n, tu = x.tu } end
		end
		if mejor then out[#out + 1] = { que = d.que, titulo = L[d.titulo], nombre = mejor.nombre, n = mejor.n, tu = mejor.tu } end
	end
	return out
end

-- "Más peces: Ana (80) · Más misiones: Tú (120)" | nil
function Lo.TextoDestacados(sep)
	local d = Lo.Destacados()
	if #d == 0 then return nil end
	local partes = {}
	for _, x in ipairs(d) do partes[#partes + 1] = format(L["%s: %s (%d)"], x.titulo, x.nombre, x.n) end
	return table.concat(partes, sep or "  \194\183  ")
end

---------------------------------------------------------------------------
-- Los logros
---------------------------------------------------------------------------

-- (1.3.1) Lo que no pudo salir por estar en una instancia (o con el bloqueo de
-- mensajes del juego): se guarda por personaje y sale al volver. Hasta
-- PENDIENTES_MAX, y lo de más de un día ya no.
local PENDIENTES_MAX, PENDIENTES_DURA = 10, 86400

local function pendientes()
	local d = N.DatosPersonaje(ID)
	if type(d.logrosPendientes) ~= "table" then d.logrosPendientes = {} end
	return d.logrosPendientes
end

local function enviarLogro(tipo, dato)
	-- (la clave lleva el dato: dos raros seguidos no se pisan en la cola)
	return M.Red.EnviarHermandad("E:" .. tipo .. ":" .. tostring(dato or ""), format("%sE|%s|%s", V, tipo, dato or ""))
end

local function compartirLogro(tipo, dato)
	if not on("logrosCompartir") then return false end
	if enviarLogro(tipo, dato) then return true end
	local _, por = M.Red.PuedeEnviar(true)
	if (por == "instancia" or por == "bloqueo") and U.EnHermandad() then
		local p = pendientes()
		local n = 0
		for _ in pairs(p) do n = n + 1 end
		local llave = tipo .. ":" .. tostring(dato or "")
		if p[llave] or n < PENDIENTES_MAX then p[llave] = { tipo = tipo, dato = dato, at = U.Reloj() } end
	end
	return false
end
Lo.CompartirLogro = compartirLogro

-- Manda lo que quedó pendiente, si ya se puede. -> cuántos salieron.
function Lo.MandarPendientes()
	local d = N.DatosPersonaje(ID)
	local p = d.logrosPendientes
	if type(p) ~= "table" or next(p) == nil then return 0 end
	if not on("logrosCompartir") then wipe(p) return 0 end
	if not (M.Red.PuedeEnviar(true) and U.EnHermandad()) then return 0 end
	local n, t = 0, U.Reloj()
	for llave, x in pairs(p) do
		if type(x) ~= "table" or t - (tonumber(x.at) or 0) > PENDIENTES_DURA then
			p[llave] = nil
		elseif enviarLogro(x.tipo, x.dato) then
			p[llave] = nil
			n = n + 1
		end
	end
	return n
end

local festejados = {}
function Lo.Festejar(tipo, quien, dato)
	if not on("logros") then return false end
	local llave = tostring(quien) .. ":" .. tipo .. ":" .. tostring(dato or "")
	local ahora = U.Ahora()
	if festejados[llave] and ahora - festejados[llave] < CADA_LOGRO then return false end
	U.Podar(festejados, CADA_LOGRO, ahora) -- (1.3.1)
	festejados[llave] = ahora
	local titulo, texto
	if tipo == "n" then
		titulo, texto = format(L["¡%s llegó al nivel %d!"], quien, dato), L["¡Auuu! Toda la manada está de fiesta."]
	elseif tipo == "m" then
		titulo, texto = format(L["¡%s tiene su primera montura!"], quien), L["Ahora corre más que la manada. ¡Auuu!"]
	elseif tipo == "r" then
		titulo, texto = format(L["¡%s cazó a %s!"], quien, dato), L["Otro trofeo para la manada. ¡Auuu!"]
	else
		return false
	end
	aviso({ titulo = titulo, texto = texto, lobo = "aullando", duracion = 12, detalle = true }) -- un festejo (1.2.9: no en Alfa sencillo)
	return true
end

M.Red.Oyentes.E = function(_, remitente, _, f, canal)
	if canal ~= "GUILD" or not on("logros") then return end
	local tipo = f[1]
	local quien = U.Mostrar(remitente)
	if tipo == "n" then
		local n = numero(f[2], 200)
		if n and n == nivelMax() then Lo.Festejar("n", quien, n) end
	elseif tipo == "m" then
		Lo.Festejar("m", quien)
	elseif tipo == "r" then
		local raro = limpiar(f[2])
		if raro then Lo.Festejar("r", quien, raro) end
	end
end
M.Red.Libres.E, M.Red.Libres.S, M.Red.Libres.F = true, true, true

-- Un raro que cazaste (Reloj.lua, cuando lo ves caer).
function Lo.Raro(nombre)
	nombre = limpiar(nombre)
	if not nombre then return end
	sumar("raros")
	compartirLogro("r", nombre)
end

---------------------------------------------------------------------------
-- Tus monturas: ¿ya tenías alguna?
---------------------------------------------------------------------------

local function tieneMontura()
	local MJ = C_MountJournal
	if not (MJ and MJ.GetMountIDs and MJ.GetMountInfoByID) then return nil end
	local ok, ids = pcall(MJ.GetMountIDs)
	if not ok or type(ids) ~= "table" then return nil end
	for _, id in ipairs(ids) do
		local okI, _, _, _, _, _, _, _, _, _, _, coleccionada = pcall(MJ.GetMountInfoByID, id)
		if okI and U.Leer(coleccionada) == true then return true end
	end
	return false
end
Lo.TieneMontura = tieneMontura

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

A.RegisterEvent("QUEST_TURNED_IN", function()
	sumar("misiones")
	N.Una("manada.semanaMetas", 2, function() pcall(Lo.RevisarMetas) end)
end)

-- 1.3.7: tras la animación del juego y escalonado con los demás mensajes de La Jauría.
A.RegisterEvent("PLAYER_LEVEL_UP", (N.TrasNivel or function(_, f) return f end)("manada.logros", function(_, nivel)
	nivel = U.Numero(nivel)
	sumar("niveles")
	if nivel and nivel == nivelMax() then compartirLogro("n", tostring(nivel)) end
end))

A.RegisterEvent("NEW_MOUNT_ADDED", function()
	local d = N.DatosPersonaje(ID)
	if d.montura then return end
	d.montura = true
	compartirLogro("m")
end)

A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if not IsInInstance then return end
	local ok, dentro, tipo = pcall(IsInInstance)
	-- (1.3.1) Afuera otra vez: sale lo que se quedó en la instancia (al ratito,
	-- cuando la hermandad ya está a la mano).
	-- Con «dentro» secreto no se sabe: no se manda nada (U.Leer daría nil).
	if ok and not N.Secreto(dentro) and not dentro then
		N.Una("manada.logrosPendientes", 5, function() pcall(Lo.MandarPendientes) end)
		return
	end
	if not (ok and U.Leer(dentro) and U.Leer(tipo) == "party") then return end
	local okN, nombre = pcall(GetInstanceInfo)
	nombre = okN and limpiar(nombre) or "?"
	local d = N.DatosPersonaje(ID)
	local t = U.Reloj()
	if d.mazmorra == nombre and t - (tonumber(d.mazmorraEn) or 0) < MAZMORRA_OTRA then return end
	d.mazmorra, d.mazmorraEn = nombre, t
	sumar("mazmorras")
end)

A.OnLogin(function()
	local d = N.DatosPersonaje(ID)
	if d.montura == nil then
		-- La primera vez: si ya tenías montura, la siguiente no es «la primera».
		local t = tieneMontura()
		if t == nil then
			local okL, nv = pcall(UnitLevel, "player")
			t = (okL and U.Numero(nv) or 0) >= 40
		end
		d.montura = t
	end
	Lo.Semana()
	M.Cada("manada.logros", 60, function()
		pcall(Lo.RevisarMetas) -- 1.4.0: los peces llegan de Pesca: se mira cada minuto
		if sucia then pcall(Lo.CompartirSemana, false) end
		pcall(Lo.MandarPendientes) -- (1.3.1) por si salir de la instancia no lo mandó
	end)
	A.After(45, function() if on("semanaCompartir") then Lo.CompartirSemana(true) end end)
end)
