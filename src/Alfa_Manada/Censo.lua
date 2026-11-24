-- Alfa - La Jauría: los lobos de tu hermandad que usan Alfa (1.3.9).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Dos pedidos en uno:
--   * «¿Dónde está la manada?» (el panel del Escritorio): quién de tu
--     hermandad con Alfa está conectado, su nivel y su zona.
--   * Quiénes usan Alfa y con qué versión, para saber quién debe actualizar
--     (/alfa lobos, y el mismo panel).
-- Va por la Red de La Jauría (AlfaManada.Red, tipo "k", con la marca de tu
-- facción) y solo a tu hermandad: nunca a canales ni a desconocidos.
--   1k|v|<versión>|<nivel>|<mapa>    lo mío (mapa 0 si no compartes tu ubicación)
--   1k|q                             «¿quién anda?»: cada quien responde una vez, sin prisa
-- Tu versión sale con manada.censo (de fábrica, sí); tu nivel, solo si
-- compartes tu ubicación o tu clase y nivel (manada.botinCompartir); tu zona,
-- solo si compartes tu ubicación con La Jauría (manada.compartir).
-- Se recuerda por cuenta (AlfaNucleoDB.manada.censo): nombre, versión, nivel
-- y cuándo se supo, 30 días como mucho y 300 lobos.
--   Ce.Lista() -> { { clave, nombre, version, nivel, mapa, zona, t, conectado, yo, vieja, nueva } }
--   Ce.Conectados() ; Ce.Nueva() -> versión más nueva que la tuya | nil ; Ce.Comparar(a, b)
-- 1.3.9 (revisión 8): «Hay una versión nueva» solo con una versión de números
-- («1.4.0», nunca «dev») más nueva que la tuya que dicen al menos 2 lobos
-- distintos, o 1 de rango alto de tu hermandad (líder u oficial): un solo
-- lobo no hace saltar el aviso a toda la hermandad con «99.0».

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local U = M.U
local ID = M.ID

local type, ipairs, pairs, tonumber, tostring, format, floor, max, min = type, ipairs, pairs, tonumber, tostring, string.format, math.floor, math.max, math.min

local Ce = {}
M.Censo = Ce

Ce.TIPO = "k"
Ce.CONECTADO = 600      -- se cuenta como conectado si habló hace menos de 10 min
Ce.OLVIDA = 30 * 86400
Ce.MAX = 300
local HUECO = 60        -- lo mío sale como mucho una vez por minuto
local RESP = 120        -- a «¿quién anda?» se responde como mucho una vez cada 2 min

local function activo() return N.Get(ID, "censo") ~= false end
local function compartoZona() return N.Get(ID, "compartir") and true or false end
local function ahora() return time() end
local function red() local Mn = rawget(_G, "AlfaManada") return type(Mn) == "table" and type(Mn.Red) == "table" and Mn.Red or nil end

local function datos()
	local d = N.Datos(ID)
	if type(d.censo) ~= "table" then d.censo = {} end
	return d.censo
end

local function miVersion() return (tostring(A.version or "dev"):gsub("[|%s]", "")) end
Ce.MiVersion = miVersion

-- "1.3.9" contra "1.3.10": -1, 0 o 1. Lo que no es número («dev») no se
-- puede comparar: cuenta como igual (ni más nueva ni vieja).
function Ce.Comparar(a, b)
	a, b = tostring(a or ""), tostring(b or "")
	if a == b then return 0 end
	local pa, pb = {}, {}
	for x in a:gmatch("%d+") do pa[#pa + 1] = tonumber(x) end
	for x in b:gmatch("%d+") do pb[#pb + 1] = tonumber(x) end
	if #pa == 0 or #pb == 0 then return 0 end
	for i = 1, max(#pa, #pb) do
		local x, y = pa[i] or 0, pb[i] or 0
		if x ~= y then return x < y and -1 or 1 end
	end
	return 0
end

---------------------------------------------------------------------------
-- Enviar
---------------------------------------------------------------------------
local ultimoEnvio, ultimaResp = -math.huge, -math.huge

local function miMapa()
	if not compartoZona() then return 0 end
	local C = C_Map
	if not (C and C.GetBestMapForUnit) then return 0 end
	local ok, m = pcall(C.GetBestMapForUnit, "player")
	m = ok and tonumber(N.Leer(m)) or nil
	return m and U.ZonaDe(m) or m or 0
end

-- Tu nivel solo si compartes tu ubicación o tu clase y nivel (manada.botinCompartir).
local function comparteNivel() return compartoZona() or N.Get(ID, "botinCompartir") and true or false end

function Ce.Mensaje()
	local nivel = comparteNivel() and UnitLevel and tonumber(N.Leer(UnitLevel("player"))) or 0
	return format("v|%s|%d|%d", miVersion(), nivel or 0, tonumber(miMapa()) or 0)
end

function Ce.Enviar(forzar)
	if not activo() then return false end
	local R = red()
	if not (R and R.EnviarHermandad) then return false end
	local t = GetTime and GetTime() or ahora()
	if not forzar and t - ultimoEnvio < HUECO then return false end
	ultimoEnvio = t
	return R.EnviarHermandad("censo", Ce.TIPO, Ce.Mensaje()) and true or false
end

function Ce.Preguntar()
	if not activo() then return false end
	local R = red()
	if not (R and R.EnviarHermandad) then return false end
	return R.EnviarHermandad("censo.q", Ce.TIPO, "q") and true or false
end

---------------------------------------------------------------------------
-- Recibir
---------------------------------------------------------------------------
local function podar()
	local d = datos()
	local t, n = ahora(), 0
	local lista = {}
	for k, x in pairs(d) do
		if type(x) ~= "table" or t - (tonumber(x.t) or 0) > Ce.OLVIDA then d[k] = nil
		else n = n + 1 lista[#lista + 1] = { k, tonumber(x.t) or 0 } end
	end
	if n > Ce.MAX then
		table.sort(lista, function(a, b) return a[2] < b[2] end)
		for i = 1, n - Ce.MAX do d[lista[i][1]] = nil end
	end
end
Ce.Podar = podar

function Ce.AlMensaje(clave, remitente, campos, canal)
	if not activo() or canal ~= "GUILD" or type(campos) ~= "table" then return end
	if campos[1] == "q" then
		local t = GetTime and GetTime() or ahora()
		if t - ultimaResp < RESP then return end
		ultimaResp = t
		N.Una("manada.censo.resp", 2 + math.random() * 8, function() Ce.Enviar(true) end)
		return
	end
	if campos[1] ~= "v" then return end
	local version = type(campos[2]) == "string" and campos[2]:match("^[%w%.%-]+$") and campos[2]:sub(1, 16) or nil
	local nivel = tonumber(campos[3])
	local mapa = tonumber(campos[4])
	if not version or (campos[3] and not nivel) or (campos[4] and not mapa) then return end
	if type(clave) ~= "string" or clave == "" then return end
	if nivel and (nivel < 1 or nivel > 200) then nivel = nil end -- 0: no lo comparte
	if mapa and (mapa <= 0 or mapa > 100000) then mapa = nil end
	local d = datos()
	d[clave] = { nombre = U.Mostrar(remitente), version = version, nivel = nivel, mapa = mapa, t = ahora() }
	podar()
	if A.Fire then A.Fire("ALFA_MANADA_CENSO") end
	-- Alguien trae una versión más nueva que la tuya: se dice una vez por
	-- versión, cuando la confirman 2 lobos (o 1 de rango alto).
	if Ce.Comparar(version, miVersion()) > 0 then
		local nueva, quien = Ce.Nueva()
		if nueva then Ce.AvisarNueva(nueva, quien) end
	end
end

local avisada = {}
function Ce.AvisarNueva(version, quien)
	if avisada[version] or not (K and K.Aviso) then return false end
	local dn = N.Datos(ID)
	if dn.censoAvisada == version then avisada[version] = true return false end
	avisada[version] = true
	dn.censoAvisada = version
	local libre = N.AlLibre or function(_, f) f() end
	libre("manada.censo.nueva", function()
		K.Aviso({ id = "manada.censoNueva", icono = "ic-manada", tono = "acento", duracion = 8, prioridad = 4, detalle = true,
			titulo = format(L["Hay una versión nueva de Alfa: %s"], version),
			texto = format(L["%s ya la usa. Tú tienes la %s: búscala en CurseForge o con Instalar-Alfa."], quien or "?", miVersion()) })
	end, 4)
	return true
end

---------------------------------------------------------------------------
-- Leer
---------------------------------------------------------------------------
function Ce.Lista()
	local out = {}
	local t = ahora()
	local mia = miVersion()
	local yo = U.Clave(UnitName and N.Leer(UnitName("player")) or "")
	for clave, x in pairs(datos()) do
		if type(x) == "table" and clave ~= yo then
			local e = { clave = clave, nombre = x.nombre or clave, version = x.version, nivel = x.nivel, mapa = x.mapa, t = x.t,
				conectado = t - (tonumber(x.t) or 0) <= Ce.CONECTADO }
			e.zona = e.mapa and U.NombreMapa(e.mapa) or nil
			local c = Ce.Comparar(e.version, mia)
			e.vieja, e.nueva = c < 0 or nil, c > 0 or nil
			out[#out + 1] = e
		end
	end
	table.sort(out, function(a, b)
		if a.conectado ~= b.conectado then return a.conectado end
		if (a.nivel or 0) ~= (b.nivel or 0) then return (a.nivel or 0) > (b.nivel or 0) end
		return tostring(a.nombre) < tostring(b.nombre)
	end)
	return out
end

function Ce.Conectados()
	local out = {}
	for _, e in ipairs(Ce.Lista()) do if e.conectado then out[#out + 1] = e end end
	return out
end

-- Una versión de verdad: solo números, «1.4.0».
local function numerica(v) return type(v) == "string" and v:match("^%d+%.%d+%.%d+$") ~= nil end
Ce.Numerica = numerica

-- ¿Es líder u oficial de tu hermandad? (rango 0 o 1 en tu lista de la hermandad)
local function rangoAlto(nombre)
	if type(GetNumGuildMembers) ~= "function" or type(GetGuildRosterInfo) ~= "function" then return false end
	local clave = U.Clave(nombre)
	if not clave then return false end
	local ok, n = pcall(GetNumGuildMembers)
	n = ok and tonumber(N.Leer(n)) or 0
	for i = 1, min(n, 1000) do
		local okI, quien, _, rango = pcall(GetGuildRosterInfo, i)
		if okI and type(quien) == "string" and not N.Secreto(quien) and U.Clave(quien) == clave then
			rango = tonumber(N.Leer(rango))
			return rango ~= nil and rango <= 1
		end
	end
	return false
end
Ce.RangoAlto = rangoAlto

-- La versión más nueva que la tuya que la manada confirma: la que tienen (o
-- pasan) al menos 2 lobos distintos, o la de un lobo de rango alto. Solo
-- versiones de números. -> versión, quién | nil
function Ce.Nueva()
	local mia = miVersion()
	local nuevas = {}
	for _, e in ipairs(Ce.Lista()) do
		if numerica(e.version) and Ce.Comparar(e.version, mia) > 0 then nuevas[#nuevas + 1] = e end
	end
	if #nuevas == 0 then return nil end
	table.sort(nuevas, function(a, b) return Ce.Comparar(a.version, b.version) > 0 end)
	-- La segunda más alta: al menos 2 lobos la tienen o la pasan.
	local mejor, quien
	if nuevas[2] then mejor, quien = nuevas[2].version, nuevas[2].nombre end
	for _, e in ipairs(nuevas) do
		if mejor and Ce.Comparar(e.version, mejor) <= 0 then break end
		if rangoAlto(e.nombre) then mejor, quien = e.version, e.nombre break end
	end
	return mejor, quien
end

-- Cuántos con cada versión -> { { version, n } } (la más nueva primero), con la tuya.
function Ce.Versiones()
	local por = { [miVersion()] = 1 }
	for _, e in ipairs(Ce.Lista()) do if e.version then por[e.version] = (por[e.version] or 0) + 1 end end
	local out = {}
	for v, n in pairs(por) do out[#out + 1] = { version = v, n = n } end
	table.sort(out, function(a, b) return Ce.Comparar(a.version, b.version) > 0 end)
	return out
end

---------------------------------------------------------------------------
-- La ventana «Lobos con Alfa» (/alfa lobos)
---------------------------------------------------------------------------
local v, ui = nil, {}

local function hace(t)
	local s = max(0, ahora() - (tonumber(t) or 0))
	if s < 120 then return L["hace un momento"] end
	if s < 3600 then return format(L["hace %d min"], floor(s / 60)) end
	if s < 86400 then return format(L["hace %d h"], floor(s / 3600)) end
	return N.Plural(floor(s / 86400), L["hace %d día"], L["hace %d días"])
end
Ce.Hace = hace

function Ce.Tarjetas()
	local out = {}
	for _, e in ipairs(Ce.Lista()) do
		local partes = {}
		if e.nivel then partes[#partes + 1] = format(L["Nivel %d"], e.nivel) end
		if e.conectado and e.zona then partes[#partes + 1] = e.zona end
		partes[#partes + 1] = e.conectado and L["Conectado"] or hace(e.t)
		if e.vieja then partes[#partes + 1] = L["Debe actualizar"] elseif e.nueva then partes[#partes + 1] = L["Más nueva"] end
		out[#out + 1] = { variante = "compacta", icono = "ic-manada", tono = e.vieja and "aviso" or (e.conectado and "exito" or "neutro"),
			titulo = e.nombre, texto = table.concat(partes, "  \194\183  "),
			valor = e.version and format(L["Alfa %s"], e.version) or "?",
			ayuda = e.vieja and L["Tiene una versión de Alfa más vieja que la tuya: dile que actualice."]
				or (e.nueva and L["Tiene una versión más nueva que la tuya."] or nil) }
	end
	return out
end

local function llenar()
	if not (v and v:IsShown()) then return end
	local lista = Ce.Tarjetas()
	local conectados = #Ce.Conectados()
	local nueva = Ce.Nueva()
	local d = { icono = "ic-manada", tono = nueva and "acento" or "exito", sobre = L["Tu versión"], titulo = format(L["Alfa %s"], miVersion()) }
	if not activo() then
		d.tono, d.texto = "neutro", L["Está apagado: no compartes tu versión ni ves la de los demás. Préndelo en Ajustes > La Jauría."]
	elseif not U.EnHermandad() then
		d.tono, d.texto = "neutro", L["Para ver a los lobos con Alfa necesitas estar en una hermandad."]
	elseif nueva then
		d.texto = format(L["Alguien de tu hermandad ya usa la %s: te conviene actualizar."], nueva)
	else
		d.texto = #lista > 0 and L["Tienes la más nueva que se ve en tu hermandad."] or L["Todavía no llega nadie. Los lobos con Alfa aparecen al conectarse."]
	end
	local vs = {}
	for _, x in ipairs(Ce.Versiones()) do vs[#vs + 1] = { format(L["%s: %d"], x.version, x.n), x.version == miVersion() and "acento" or "neutro" } end
	d.insignias = vs
	ui.estado:Set(d)
	ui.sec:Set(L["Lobos de tu hermandad con Alfa"], { cuenta = #lista > 0 and format(L["%d conectados de %d"], conectados, #lista) or nil,
		enlace = { texto = L["Preguntar ahora"], alClic = function() Ce.Preguntar() N.Una("manada.censo.ver", 4, llenar) end } })
	ui.lista:Llenar(lista)
	K.Mostrar(ui.lista, #lista > 0)
	local h = ui.pila:Acomodar(v:AnchoCuerpo() - 2 * v.margen)
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -v.margen)
	v:SetAltoContenido(h + 2 * v.margen)
end
Ce.Llenar = llenar

function Ce.Abrir()
	if N.Permitido and not N.Permitido() then return false end
	if not v then
		v = K.Ventana({ nombre = "AlfaManadaLobos", titulo = L["Lobos con Alfa"], subtitulo = L["Quién de tu hermandad usa Alfa, su versión y dónde anda"],
			icono = "ic-manada", ancho = 620, alto = 520, desplazar = true })
		v.alAcomodar = llenar
		local p = K.Pila(v.Cuerpo, { espacio = K.ESP.base })
		ui.pila = p
		ui.estado = p:Agregar(K.Tarjeta(p, { variante = "estado" }))
		ui.sec = p:Agregar(K.Seccion(p, ""), { espacio = K.ESP.l })
		ui.lista = p:Agregar(K.Rejilla(p, { min = 420, gap = K.ESP.xs, variante = "compacta" }), { espacio = K.ESP.s })
	end
	v:Abrir()
	llenar()
	Ce.Preguntar()
	return true
end
function Ce.Visible() return v ~= nil and v:IsShown() end

---------------------------------------------------------------------------
-- Cuándo
---------------------------------------------------------------------------
local escuchando = false
function Ce.Escuchar()
	if escuchando then return true end
	local R = red()
	if not (R and R.Escuchar) then return false end
	local ok, si = pcall(R.Escuchar, Ce.TIPO, Ce.AlMensaje, true)
	escuchando = ok and si and true or false
	return escuchando
end

A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, inicial)
	Ce.Escuchar()
	podar()
	if inicial then
		N.Una("manada.censo.envio", 25, function() Ce.Enviar(true) end)
		N.Una("manada.censo.pregunta", 35, Ce.Preguntar)
	end
end)
A.RegisterEvent("PLAYER_LEVEL_UP", function() N.Una("manada.censo.envio", 5, function() Ce.Enviar(true) end) end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
	if compartoZona() then N.Una("manada.censo.envio", 15, function() Ce.Enviar() end) end
end)
if A.On then A.On("ALFA_MANADA_CENSO", function() if Ce.Visible() then N.Una("manada.censo.ver", 0.5, llenar) end end) end

A.RegisterCommand("lobos", function() Ce.Abrir() end, L["quién de tu hermandad usa Alfa, su versión y dónde anda"])

AlfaManada = type(AlfaManada) == "table" and AlfaManada or {}
AlfaManada.Censo = function() return Ce.Lista() end
AlfaManada.Conectados = function() return Ce.Conectados() end
AlfaManada.AbrirLobos = function() return Ce.Abrir() end
