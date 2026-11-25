-- Alfa - La Jauría: las guaridas (1.2.4). toxic3000 / La Jauría. GPL-3.0.
--
-- En Forever una zona llena se parte en capas: el mismo lugar con otra gente,
-- otros raros y otros minerales. Alfa le dice a cada capa "guarida" y le da
-- un nombre de la manada (Guarida Colmillo, Guarida Brasa...), para que se
-- pueda hablar de ella. Idea propia de Alfa: se ve quién de la manada anda
-- en cada guarida de tu zona y se le pide entrar a la suya con un clic.
--
-- Cómo se sabe la guarida: el identificador de las criaturas que ves (tu
-- objetivo, el cursor, las placas de nombre) trae el número de la capa en su
-- quinto campo: "Creature-0-servidor-instancia-CAPA-id-aparición". Lo
-- secreto (combate en mazmorras) no se lee; en instancias no hay guaridas.
--
-- Cómo se cambia (lo hace el juego, no Alfa): al unirte al grupo de alguien
-- de otra capa, el juego te pasa a la suya al rato. Alfa solo arregla el
-- encuentro:
--   * Quien abre su guarida (manada.guaridaAbierta, apagado de fábrica)
--     invita a su grupo a quien se la pida (C_PartyInfo.InviteUnit), fuera
--     de combate y si puede invitar.
--   * Quien pide entrar acepta la invitación con el botón del juego. Al
--     llegar, Alfa le avisa con «Salir del grupo» (C_PartyInfo.LeaveParty:
--     su clic) y la guarida nueva se queda.
-- Ninguna de las dos funciones tiene restricciones (PartyInfoDocumentation).
--
-- Mensajes (Red.lua, prefijo AlfaManada, solo entre quienes comparten):
--   1G|<mapa>|<capa>|<abierta 0/1>   mi guarida (al cambiar y cada REFRESCO;
--                                    1.3.1: por susurro no se acepta)
--   1Q|<mapa>|<capa>                 por susurro: ¿me dejas entrar?
--   1R|ok  /  1R|no|<por qué>        por susurro: la respuesta
--   1L|<mapa>|<capa de donde vengo>  por susurro (1.2.9): ¿me pasas a tu
--                                    plano, sea cual sea, si no es el mío?
--   1O|<mapa>|<capa>                 a la manada (1.2.9): busco otro plano,
--                                    ¿alguien me abre su guarida?
--
--   Gu.Actual() -> { capa, map, at } | nil      tu guarida ahora
--   Gu.Nombre(capa) -> "Guarida Colmillo"
--   Gu.Lista() -> { { capa, nombre, gente, abiertas, mia, anfitriones } }  las de tu zona
--   Gu.Pedir(capa) -> ok, motivo               pide entrar
--   Gu.Abrir(si), Gu.Abierta()
--   Gu.DeGuid(guid) -> capa | nil              (para las pruebas)
--   Gu.CambiarPlano(antes) -> ok, motivo       (1.2.9) a cualquier otro plano
--   Gu.PreguntarManada() -> ok, motivo         (1.2.9) 1O: ¿quién me abre?
--   Gu.PorZona() -> { zona }                    (1.3.0) las guaridas de cada zona
--   Gu.PintarMapa(forzar)                       (1.3.0) su marca en el mapa

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Gu = {}
M.Guaridas = Gu

local type, tonumber, tostring, pairs, ipairs, format = type, tonumber, tostring, pairs, ipairs, string.format
local floor, sort = math.floor, table.sort

local V = "1"
local REFRESCO = 120   -- segundos entre dos avisos de mi guarida
local CADUCA = 300     -- lo que dijo otro vale esto
local VIGENTE = 600    -- mi guarida se da por buena esto sin volver a verla
local ESPERA = 8       -- segundos esperando la respuesta de un anfitrión
local INTENTOS = 3     -- anfitriones a probar
local CADA_PERSONA = 60 -- un anfitrión invita a la misma persona una vez por minuto
local CADA_INVITE = 10  -- y a nadie más seguido que esto
local LLEGAR = 90       -- segundos para llegar a la guarida pedida

-- Nombres de la manada: uno por capa (el número de la capa elige).
local NOMBRES = { "Colmillo", "Aullido", "Luna", "Escarcha", "Ceniza", "Sombra", "Bruma", "Garra",
	"Brasa", "Niebla", "Roble", "Trueno", "Nieve", "Piedra", "Ámbar", "Viento" }

local function on(clave) return N.Get(ID, clave) and true or false end

function Gu.Nombre(capa)
	capa = tonumber(capa)
	if not capa then return L["Guarida desconocida"] end
	return format(L["Guarida %s"], L[NOMBRES[capa % #NOMBRES + 1]])
end

-- "Guarida Colmillo · 7994": el número desempata dos con el mismo nombre.
function Gu.Etiqueta(capa)
	return Gu.Nombre(capa) .. " \194\183 " .. tostring(capa)
end

---------------------------------------------------------------------------
-- Tu guarida
---------------------------------------------------------------------------

local actual -- { capa, map, at }
Gu.version = 0
local function cambio()
	Gu.version = Gu.version + 1
	if M.Avisar then M.Avisar() end
end

function Gu.DeGuid(guid)
	if type(guid) ~= "string" or U.Secreto(guid) then return nil end
	local tipo, _, _, _, capa = strsplit("-", guid)
	if tipo ~= "Creature" and tipo ~= "Vehicle" then return nil end
	capa = tonumber(capa)
	if not capa or capa <= 0 then return nil end
	return capa
end

local function miMapa()
	local map = U.MiPosicion()
	return map
end

local pedido -- { capa, map, anfitrion, nombre, hasta, invitado }
local candidata -- una capa distinta vista una vez: se cree a la segunda
local esperandoPuerta = -math.huge -- (1.2.9) hasta cuándo avisar si alguien abre su guarida en otro plano
local avisadoCambio = -math.huge -- el aviso de «el juego te pasó», uno cada 2 min
local llegar -- forward

local function ver(capa)
	if not capa or U.EnInstancia() then return end
	local map = miMapa()
	if not map then return end
	local ahora = U.Ahora()
	if actual and actual.capa == capa and actual.map == map then
		actual.at = ahora
		return
	end
	-- Un cambio de capa en la misma zona se cree a la segunda lectura igual
	-- (una criatura de la zona vecina, o una placa de antes de cambiar de
	-- zona, trae otro número).
	-- (1.2.9) Cambiar de plano: cualquier capa que no sea la de antes, ya
	-- invitado, es la buscada.
	local buscada = pedido and pedido.map == map and (pedido.capa == capa
		or (pedido.cualquiera and pedido.invitado and capa ~= pedido.desde))
	if actual and actual.map == map and not buscada then
		if candidata ~= capa then
			candidata = capa
			return
		end
	end
	candidata = nil
	local antes = actual
	actual = { capa = capa, map = map, at = ahora }
	Gu.Anunciar(true)
	cambio()
	if buscada then
		llegar()
	elseif antes and antes.map == map and antes.capa ~= capa and on("guaridaVisible") then
		-- El juego te cambió de capa por su cuenta (1.2.5): Lya te lo dice.
		if ahora - avisadoCambio > 120 then
			avisadoCambio = ahora
			local Lya = rawget(_G, "AlfaLya")
			local t = format(L["El juego te pasó a la %s. Otra gente, otros raros, otros minerales."], Gu.Nombre(capa))
			if not (type(Lya) == "table" and Lya.Decir and Lya.Decir(t)) then U.Decir(t) end
		end
	end
end
Gu.Ver = ver

local function leerUnidad(unit)
	if not (UnitExists and UnitGUID) then return end
	local okE, existe = pcall(UnitExists, unit)
	if not okE or not U.Leer(existe) then return end
	if UnitIsPlayer then
		local okP, jugador = pcall(UnitIsPlayer, unit)
		if okP and U.Leer(jugador) then return end
	end
	local ok, guid = pcall(UnitGUID, unit)
	if not ok then return end
	local capa = Gu.DeGuid(guid)
	ver(capa)
	return capa ~= nil
end
Gu.LeerUnidad = leerUnidad

function Gu.Actual()
	if not actual then return nil end
	if U.Ahora() - actual.at > VIGENTE then return nil end
	if miMapa() ~= actual.map then return nil end
	return actual
end

local function olvidarMia()
	if actual then
		actual = nil
		cambio()
	end
end

---------------------------------------------------------------------------
-- Las guaridas de la manada
---------------------------------------------------------------------------

local vistas = {} -- clave -> { clave, nombre, map, capa, abierta, at }

function Gu.Abierta() return on("guaridaAbierta") end

function Gu.Abrir(si)
	N.Set(ID, "guaridaAbierta", si and true or false)
	Gu.Anunciar(true)
	cambio()
end

local ultimoAnuncio = { at = -math.huge }
function Gu.Anunciar(forzar)
	if not on("compartir") then return end
	local a = Gu.Actual()
	if not a then return end
	local abierta = Gu.Abierta() and 1 or 0
	local ahora = U.Ahora()
	local igual = ultimoAnuncio.capa == a.capa and ultimoAnuncio.map == a.map and ultimoAnuncio.abierta == abierta
	if not forzar and igual and ahora - ultimoAnuncio.at < REFRESCO then return end
	if igual and ahora - ultimoAnuncio.at < 5 then return end
	if M.Red.Enviar("G", format("%sG|%d|%d|%d", V, a.map, a.capa, abierta)) then
		ultimoAnuncio = { capa = a.capa, map = a.map, abierta = abierta, at = ahora }
	end
end

local function numeroEntero(s)
	if type(s) ~= "string" or not s:match("^%d+$") or #s > 12 then return nil end
	return tonumber(s)
end

M.Red.Oyentes.G = function(clave, remitente, _, f, canal)
	if canal == "WHISPER" then return end -- (1.3.1) lo difundido, nunca por susurro
	local map, capa = numeroEntero(f[1]), numeroEntero(f[2])
	if not (map and capa) or map < 1 or map > 100000 or capa < 1 then return end
	local antes = vistas[clave]
	vistas[clave] = { clave = clave, nombre = remitente, map = map, capa = capa, abierta = f[3] == "1", at = U.Ahora() }
	-- (1.2.9) Le preguntaste a la manada: alguien abrió su guarida en otro plano.
	local mia = Gu.Actual()
	if f[3] == "1" and U.Ahora() < esperandoPuerta and mia and mia.map == map and mia.capa ~= capa
		and not (antes and antes.abierta and antes.capa == capa) and not pedido then
		esperandoPuerta = -math.huge
		Gu.AvisarPuerta(remitente, capa)
	end
	cambio()
end

-- Quien deja de compartir se olvida también aquí.
local olvidarGente = M.Gente.Olvidar
M.Gente.Olvidar = function(clave, ...)
	if vistas[clave] then vistas[clave] = nil cambio() end
	return olvidarGente(clave, ...)
end

-- Las guaridas de tu zona: la tuya primero, luego las que más gente tienen.
function Gu.Lista()
	local map = miMapa()
	local mia = Gu.Actual()
	local por = {}
	local lista = {}
	local ahora = U.Ahora()
	local function de(capa)
		local g = por[capa]
		if not g then
			g = { capa = capa, nombre = Gu.Nombre(capa), etiqueta = Gu.Etiqueta(capa), gente = 0, abiertas = 0, anfitriones = {},
				mia = mia and mia.capa == capa or false }
			por[capa] = g
			lista[#lista + 1] = g
		end
		return g
	end
	if mia then de(mia.capa) end
	if map then
		for clave, v in pairs(vistas) do
			if ahora - v.at > CADUCA then
				vistas[clave] = nil
			elseif v.map == map then
				local g = de(v.capa)
				g.gente = g.gente + 1
				if v.abierta then
					g.abiertas = g.abiertas + 1
					g.anfitriones[#g.anfitriones + 1] = v
				end
			end
		end
	end
	for _, g in ipairs(lista) do sort(g.anfitriones, function(a, b) return a.at > b.at end) end
	sort(lista, function(a, b)
		if a.mia ~= b.mia then return a.mia end
		if a.abiertas ~= b.abiertas then return a.abiertas > b.abiertas end
		if a.gente ~= b.gente then return a.gente > b.gente end
		return a.capa < b.capa
	end)
	return lista
end

---------------------------------------------------------------------------
-- Pedir entrar
---------------------------------------------------------------------------

local function enGrupo()
	if not IsInGroup then return false end
	local ok, v = pcall(IsInGroup)
	return ok and U.Leer(v) and true or false
end

local function aviso(o)
	local K = N.Kit
	if M.U and M.U.Aviso then M.U.Aviso(o) else U.Decir(o.titulo .. (o.texto and (" " .. o.texto) or "")) end
end

local function probar()
	local p = pedido
	if not p then return end
	local siguiente = table.remove(p.cola, 1)
	if not siguiente then
		pedido = nil
		local t = p.cualquiera and L["Nadie de la manada respondió desde otro plano. Prueba en un rato o pídelo en el Discord de La Jauría."]
			or format(L["Nadie respondió desde la %s. Prueba en un rato o pídelo en el Discord de La Jauría."], p.nombre)
		aviso({ titulo = L["Nadie abrió la puerta"], texto = t, icono = "ic-manada", duracion = 10 })
		cambio()
		return
	end
	p.anfitrion = siguiente
	p.turno = (p.turno or 0) + 1
	local turno = p.turno
	if p.cualquiera then
		M.Red.Enviar("L:" .. siguiente.clave, format("%sL|%d|%d", V, p.map, p.desde), "WHISPER", U.Destino(siguiente.nombre))
	else
		M.Red.Enviar("Q:" .. siguiente.clave, format("%sQ|%d|%d", V, p.map, p.capa), "WHISPER", U.Destino(siguiente.nombre))
	end
	A.After(ESPERA, function()
		if pedido == p and p.turno == turno and not p.invitado then probar() end
	end)
end

-- Pide entrar a la guarida `capa` de tu zona. ok, o false y por qué.
function Gu.Pedir(capa)
	capa = tonumber(capa)
	if not on("compartir") then return false, "compartir" end
	if enGrupo() then return false, "grupo" end
	if U.EnInstancia() then return false, "instancia" end
	local map = miMapa()
	if not map then return false, "mapa" end
	local mia = Gu.Actual()
	if mia and mia.capa == capa then return false, "ya" end
	local g
	for _, x in ipairs(Gu.Lista()) do if x.capa == capa then g = x end end
	if not (g and #g.anfitriones > 0) then return false, "nadie" end
	local cola = {}
	for i = 1, math.min(INTENTOS, #g.anfitriones) do cola[i] = g.anfitriones[i] end
	pedido = { capa = capa, map = map, nombre = g.nombre, cola = cola, hasta = U.Ahora() + LLEGAR + ESPERA * INTENTOS + 10 }
	aviso({ titulo = format(L["Tocando a la puerta de la %s"], g.nombre),
		texto = L["Si te invitan a su grupo, acepta con el botón del juego: el juego te pasa a su guarida al rato."], icono = "ic-manada", duracion = 8 })
	probar()
	cambio()
	return true
end

function Gu.Pedido() return pedido end

-- (1.2.9) Cambiar de plano: a cualquier otra guarida de tu zona que alguien
-- de la manada tenga abierta. Se le pregunta a uno por uno (1L) y el primero
-- cuyo Alfa dice que sí te invita (su guarida abierta es su permiso).
-- `antes`: cómo estaba de lleno tu plano (Plano.lua), para comparar al llegar.
function Gu.CambiarPlano(antes)
	if not on("compartir") then return false, "compartir" end
	if enGrupo() then return false, "grupo" end
	if U.EnInstancia() then return false, "instancia" end
	local map = miMapa()
	if not map then return false, "mapa" end
	local mia = Gu.Actual()
	if not mia then return false, "sincapa" end
	if pedido then return false, "pedido" end
	local cola = {}
	for _, g in ipairs(Gu.Lista()) do
		if not g.mia and g.capa ~= mia.capa then
			for _, v in ipairs(g.anfitriones) do
				if #cola < INTENTOS + 1 then cola[#cola + 1] = v end
			end
		end
	end
	if #cola == 0 then return false, "nadie" end
	pedido = { cualquiera = true, desde = mia.capa, map = map, nombre = L["otro plano"], cola = cola, antes = antes,
		hasta = U.Ahora() + LLEGAR + ESPERA * (INTENTOS + 1) + 10 }
	aviso({ titulo = L["Buscando otro plano"],
		texto = L["Si te invitan a su grupo, acepta con el botón del juego: el juego te pasa a su plano al rato."], icono = "ic-manada", duracion = 8 })
	probar()
	cambio()
	return true
end

-- (1.2.9) Nadie en otro plano: se le pregunta a la manada de tu zona si
-- alguien abre su guarida (un aviso en su pantalla, nada en el chat).
local CADA_PREGUNTA = 300
local preguntado = -math.huge
function Gu.PreguntarManada()
	if not on("compartir") then return false, "compartir" end
	local mia = Gu.Actual()
	if not mia then return false, "sincapa" end
	local ahora = U.Ahora()
	if ahora - preguntado < CADA_PREGUNTA then return false, "espera" end
	if not M.Red.Enviar("O", format("%sO|%d|%d", V, mia.map, mia.capa)) then return false, "red" end
	preguntado = ahora
	esperandoPuerta = ahora + CADA_PREGUNTA
	return true
end
-- Alguien abrió su guarida en otro plano después de tu pregunta.
function Gu.AvisarPuerta(remitente, capa)
	aviso({ titulo = format(L["%s te abre su guarida"], U.Mostrar(remitente)),
		texto = format(L["Está en la %s, otro plano de tu zona."], Gu.Nombre(capa)), icono = "ic-manada", duracion = 15,
		accion = { texto = L["Cambiar de plano"], alClic = function()
			local P = M.Plano
			if P and P.CambiarYDecir then P.CambiarYDecir() else Gu.CambiarPlano() end
		end } })
end
function Gu.OlvidarPregunta() preguntado, esperandoPuerta = -math.huge, -math.huge end

local MOTIVOS = {
	cerrada = "Su guarida ya no está abierta.",
	combate = "Está en combate. Prueba en un momento.",
	lleno = "Su grupo está lleno o no puede invitar.",
	otra = "Ya no está en esa guarida.",
	espera = "Acaba de abrirle la puerta a alguien. Prueba en un momento.",
}

M.Red.Oyentes.R = function(clave, remitente, _, f, canal)
	if canal ~= "WHISPER" then return end
	local p = pedido
	if not (p and p.anfitrion and p.anfitrion.clave == clave) or p.invitado then return end
	if f[1] == "ok" then
		p.invitado = true
		-- (después del aviso de LLEGAR: ese es el que lo cierra con «Salir del grupo»)
		p.hasta = U.Ahora() + LLEGAR + 15
		aviso({ titulo = format(L["%s te abre la puerta"], U.Mostrar(remitente)),
			texto = L["Acepta su invitación al grupo. Al llegar a su guarida, Alfa te avisa para salir del grupo."], icono = "ic-manada", duracion = 15 })
		A.After(LLEGAR, function()
			if pedido == p then
				pedido = nil
				aviso({ titulo = L["Todavía no cambias de guarida"], texto = L["A veces el juego tarda o no deja mover a nadie más a esa capa. Puedes salir del grupo y probar con otra."],
					icono = "ic-manada", duracion = 12, accion = { texto = L["Salir del grupo"], alClic = function() Gu.SalirDelGrupo() end } })
				cambio()
			end
		end)
	else
		local por = MOTIVOS[f[2] or ""]
		if por then U.Decir(format("%s: %s", U.Mostrar(remitente), L[por])) end
		probar()
	end
	cambio()
end

function Gu.SalirDelGrupo()
	if not enGrupo() then return false end
	if C_PartyInfo and C_PartyInfo.LeaveParty then return pcall(C_PartyInfo.LeaveParty) and true or false end
	if LeaveParty then return pcall(LeaveParty) and true or false end
	return false
end

-- (1.3.3) Llegaste y sigues en el grupo de quien te invitó: cada RECORDAR
-- segundos, hasta QUEDARSE, Lya (o un aviso) te lo recuerda con «Salir del
-- grupo». Se acaba al salir del grupo.
local RECORDAR, QUEDARSE = 120, 600
local recordar -- { nombre, hasta }
local function recordarSalir()
	local r = recordar
	if not r or not enGrupo() or U.Ahora() > r.hasta then
		recordar = nil
		M.Quitar("manada.salirGrupo")
		return
	end
	aviso({ titulo = format(L["Ya estás en la %s: ¿salimos del grupo?"], r.nombre),
		texto = L["La guarida se queda contigo aunque salgas."], icono = "ic-manada", duracion = 15,
		accion = { texto = L["Salir del grupo"], alClic = function() Gu.SalirDelGrupo() end } })
end
Gu.RecordarSalir = recordarSalir -- (para el banco)
function Gu.Recordando() return recordar end
local function empezarARecordar(nombre)
	recordar = { nombre = nombre, hasta = U.Ahora() + QUEDARSE }
	M.Cada("manada.salirGrupo", RECORDAR, recordarSalir)
end

-- Llegaste a la guarida que pediste.
llegar = function()
	local p = pedido
	pedido = nil
	empezarARecordar(actual and Gu.Nombre(actual.capa) or p.nombre)
	if p.cualquiera then
		aviso({ titulo = L["¡Ya estás en otro plano!"],
			texto = format(L["Ahora estás en la %s. Ya puedes salir del grupo: el plano se queda contigo."], actual and Gu.Nombre(actual.capa) or ""),
			lobo = "aullando", duracion = 20, accion = { texto = L["Salir del grupo"], alClic = function() Gu.SalirDelGrupo() end } })
		if M.Plano and M.Plano.AlLlegar then M.Plano.AlLlegar(p.antes) end
		cambio()
		return
	end
	aviso({ titulo = format(L["¡Ya estás en la %s!"], p.nombre), texto = L["Ya puedes salir del grupo: la guarida se queda contigo."],
		lobo = "aullando", duracion = 20, accion = { texto = L["Salir del grupo"], alClic = function() Gu.SalirDelGrupo() end } })
	cambio()
end

---------------------------------------------------------------------------
-- Abrir tu guarida: invitar a quien la pide
---------------------------------------------------------------------------

local invitadoA, ultimoInvite = {}, -math.huge

local function puedoInvitar()
	if not enGrupo() then return true end
	if IsInRaid then
		local ok, v = pcall(IsInRaid)
		if ok and U.Leer(v) then return false end
	end
	if UnitIsGroupLeader then
		local ok, v = pcall(UnitIsGroupLeader, "player")
		if not (ok and U.Leer(v)) then return false end
	end
	if GetNumGroupMembers then
		local ok, n = pcall(GetNumGroupMembers)
		n = ok and U.Numero(n) or 0
		if n >= 5 then return false end
	end
	return true
end

-- La respuesta a «¿me dejas entrar?»: "ok" (y la invitación) o el motivo.
-- `desde` (1.2.9, 1L): cualquier plano sirve si no es ese.
function Gu.Responder(clave, remitente, map, capa, desde)
	local mia = Gu.Actual()
	if not Gu.Abierta() then return "cerrada" end
	if not mia or mia.map ~= map or (capa and mia.capa ~= capa) or (desde and mia.capa == desde) then return "otra" end
	if InCombatLockdown and InCombatLockdown() then return "combate" end
	if not puedoInvitar() then return "lleno" end
	local ahora = U.Ahora()
	if (invitadoA[clave] and ahora - invitadoA[clave] < CADA_PERSONA) or ahora - ultimoInvite < CADA_INVITE then return "espera" end
	if not U.Invitar(remitente) then return "lleno" end
	U.Podar(invitadoA, CADA_PERSONA, ahora) -- (1.3.1)
	invitadoA[clave], ultimoInvite = ahora, ahora
	if M.Logros and M.Logros.Ayudar then M.Logros.Ayudar("guarida:" .. clave) end -- 1.4.0 (55)
	U.Decir(format(L["%s pidió entrar a tu guarida: lo invitaste a tu grupo. Saldrá solo al llegar."], U.Mostrar(remitente)))
	return "ok"
end

M.Red.Oyentes.Q = function(clave, remitente, _, f, canal)
	if canal ~= "WHISPER" or not on("compartir") then return end
	local map, capa = numeroEntero(f[1]), numeroEntero(f[2])
	if not (map and capa) then return end
	local r = Gu.Responder(clave, remitente, map, capa)
	local texto = r == "ok" and (V .. "R|ok") or (V .. "R|no|" .. r)
	M.Red.Enviar("R:" .. clave, texto, "WHISPER", U.Destino(remitente))
end

-- (1.2.9) ¿Me pasas a tu plano? Igual que 1Q, con cualquier plano que no sea
-- el de quien pregunta.
M.Red.Oyentes.L = function(clave, remitente, _, f, canal)
	if canal ~= "WHISPER" or not on("compartir") then return end
	local map, desde = numeroEntero(f[1]), numeroEntero(f[2])
	if not (map and desde) then return end
	local r = Gu.Responder(clave, remitente, map, nil, desde)
	local texto = r == "ok" and (V .. "R|ok") or (V .. "R|no|" .. r)
	M.Red.Enviar("R:" .. clave, texto, "WHISPER", U.Destino(remitente))
end

-- (1.2.9) Un lobo de tu zona busca otro plano: si tu guarida está cerrada y
-- estás en otro, te pregunto si se la abres. Una vez por lobo cada 5 min.
local pidieron = {}
M.Red.Oyentes.O = function(clave, remitente, _, f, canal)
	if canal == "WHISPER" then return end
	local map, capa = numeroEntero(f[1]), numeroEntero(f[2])
	if not (map and capa) then return end
	local mia = Gu.Actual()
	if not mia or mia.map ~= map or mia.capa == capa or Gu.Abierta() then return end
	if InCombatLockdown and InCombatLockdown() then return end
	local ahora = U.Ahora()
	if pidieron[clave] and ahora - pidieron[clave] < CADA_PREGUNTA then return end
	U.Podar(pidieron, CADA_PREGUNTA, ahora) -- (1.3.1)
	pidieron[clave] = ahora
	aviso({ titulo = format(L["%s busca otro plano"], U.Mostrar(remitente)),
		texto = L["Su plano está lleno de gente. Si le abres tu guarida, Alfa lo invita a tu grupo y sale solo al llegar."],
		icono = "ic-manada", duracion = 20,
		accion = { texto = L["Abrir mi guarida"], alClic = function() Gu.Abrir(true) end } })
end

---------------------------------------------------------------------------
-- Raros de la manada (1.2.5): cuando Lya olfatea un raro o un tesoro, la
-- manada de tu zona sabe en qué guarida está. Si es la tuya, «Ir de caza»;
-- si es otra, «Pedir entrar» (si alguien la tiene abierta).
--   1V|<mapa>|<capa>|<r|t>|<mapa del raro>|<x>|<y>|<nombre>
-- x, y en 0-100. Uno por raro cada CADA_RARO segundos; los avisos recibidos,
-- uno por raro cada CADA_RARO también y (1.3.1) uno por lobo cada CADA_LOBO,
-- nunca por susurro. Ajuste manada.rarosManada.
---------------------------------------------------------------------------
local CADA_RARO = 300
local CADA_LOBO = 60
local dichos, oidos, deLobo = {}, {}, {}

local function limpiar(s)
	if type(s) ~= "string" or U.Secreto(s) then return nil end
	s = U.Cortar((s:gsub("[|\n\r]", "")), 48) -- (1.3.1) 48 letras, no bytes
	return s ~= "" and s or nil
end

local function alAvistar(a)
	if type(a) ~= "table" or (a.kind ~= "rare" and a.kind ~= "treasure") then return end
	if a.source == "sample" or not on("compartir") or not on("rarosManada") then return end
	local mia = Gu.Actual()
	local nombre = limpiar(a.name)
	if not (mia and nombre and a.map and a.x and a.y) then return end
	local clave = tostring(a.key or a.id or nombre)
	local ahora = U.Ahora()
	if dichos[clave] and ahora - dichos[clave] < CADA_RARO then return end
	U.Podar(dichos, CADA_RARO, ahora) -- (1.3.1)
	dichos[clave] = ahora
	M.Red.Enviar("V:" .. clave, format("%sV|%d|%d|%s|%d|%.2f|%.2f|%s", V, mia.map, mia.capa,
		a.kind == "treasure" and "t" or "r", a.map, a.x, a.y, nombre)) -- (x, y ya en 0-100, como la flecha)
end
if A.On then A.On("RARE_SPOTTED", alAvistar) end
Gu.AlAvistar = alAvistar

local function numeroDecimal(s)
	if type(s) ~= "string" or not s:match("^%d+%.?%d*$") or #s > 8 then return nil end
	return tonumber(s)
end

M.Red.Oyentes.V = function(clave, remitente, _, f, canal)
	if canal == "WHISPER" or not on("rarosManada") then return end
	local map, capa, rmap = numeroEntero(f[1]), numeroEntero(f[2]), numeroEntero(f[4])
	local x, y = numeroDecimal(f[5]), numeroDecimal(f[6])
	local nombre = limpiar(f[7])
	if not (map and capa and rmap and x and y and nombre) or x > 100 or y > 100 then return end
	if miMapa() ~= map then return end
	local llave = rmap .. ":" .. nombre
	local ahora = U.Ahora()
	if oidos[llave] and ahora - oidos[llave] < CADA_RARO then return end
	-- (1.3.1) Un aviso por lobo cada minuto: nadie llena tu pantalla de raros.
	if deLobo[clave] and ahora - deLobo[clave] < CADA_LOBO then return end
	U.Podar(oidos, CADA_RARO, ahora)
	U.Podar(deLobo, CADA_LOBO, ahora)
	oidos[llave], deLobo[clave] = ahora, ahora
	local tesoro = f[3] == "t"
	local quien = U.Mostrar(remitente)
	local mia = Gu.Actual()
	local K = N.Kit
	local titulo = format(tesoro and L["Tesoro de la manada: %s"] or L["Raro de la manada: %s"], nombre)
	if mia and mia.capa == capa then
		aviso({ titulo = titulo, texto = format(L["%s lo encontró en tu guarida."], quien), icono = "ic-raros", duracion = 15,
			accion = { texto = L["Ir de caza"], alClic = function()
				local Nav = A.Nav
				if Nav and Nav.SetTarget then Nav.SetTarget(rmap, x, y, nombre) N.EmpezarRuta() end
			end } })
	else
		local abierta = false
		for _, g in ipairs(Gu.Lista()) do if g.capa == capa and g.abiertas > 0 then abierta = true end end
		aviso({ titulo = titulo, texto = format(L["%s lo encontró en la %s."], quien, Gu.Nombre(capa)), icono = "ic-raros", duracion = 15,
			accion = abierta and { texto = L["Pedir entrar"], alClic = function()
				local ok, por = Gu.Pedir(capa)
				if not ok and por == "grupo" then U.Decir(L["Sal de tu grupo primero: el juego te pasa a la guarida de quien te invita."]) end
			end } or nil })
	end
	cambio()
end

---------------------------------------------------------------------------
-- Un lobo de la manada (1.2.5): su guarida en su cuadro, y «Pedir entrar a
-- su guarida» en su clic derecho (Invitar.lua).
---------------------------------------------------------------------------

-- Lo último que dijo un lobo de su guarida, si sigue vigente y es de tu zona.
function Gu.DeLobo(nombre)
	local clave = U.Clave(nombre)
	local v = clave and vistas[clave]
	if not v or U.Ahora() - v.at > CADUCA or v.map ~= miMapa() then return nil end
	return v
end

function Gu.AlCuadro(tooltip, unit)
	if not on("guaridaVisible") or type(unit) ~= "string" or not (tooltip and tooltip.AddLine) then return end
	local C = A.Compat
	local ok, nombre = pcall(C.UnitFullName, unit)
	if not ok or type(nombre) ~= "string" then return end
	local v = Gu.DeLobo(nombre)
	if not v then return end
	local mia = Gu.Actual()
	local t = format(L["En la %s"], Gu.Etiqueta(v.capa))
	if mia and mia.capa == v.capa then t = t .. " " .. L["(la tuya)"]
	elseif v.abierta then t = t .. " " .. L["(puerta abierta)"] end
	tooltip:AddLine(t, 0.55, 0.88, 0.31)
end

local H = A.Hooks
if type(H) == "table" and type(H.UnitLines) == "function" then
	H.UnitLines(ADDON .. ":guaridas", function(tooltip, unit) pcall(Gu.AlCuadro, tooltip, unit) end)
end

-- Pide entrar a la guarida de un lobo en particular.
function Gu.PedirA(nombre)
	local v = Gu.DeLobo(nombre)
	if not (v and v.abierta) then return false, "nadie" end
	return Gu.Pedir(v.capa)
end

---------------------------------------------------------------------------
-- 1.3.0: el mapa de guaridas en vivo. Cada zona con lobos de la manada:
-- sus guaridas y cuántos lobos hay en cada una (lo que dicen con 1G). En la
-- página de La Jauría y en el mapa del mundo (una marca por zona, donde
-- andan; capa manada.guaridasMapa, ajuste manada.guaridasMapa).
---------------------------------------------------------------------------

-- { { map (zona), nombre, total, mia, guaridas = { { capa, nombre, lobos, mia } } } }
-- La zona tuya primero, luego las que más lobos tienen.
function Gu.PorZona()
	local zonas, lista = {}, {}
	local ahora = U.Ahora()
	local mia = Gu.Actual()
	local miZona = mia and U.ZonaDe(mia.map)
	local function zona(map)
		local z = U.ZonaDe(map) or map
		local e = zonas[z]
		if not e then
			e = { map = z, nombre = U.NombreMapa(z) or L["Zona desconocida"], total = 0, mia = z == miZona, guaridas = {}, por = {} }
			zonas[z] = e
			lista[#lista + 1] = e
		end
		return e
	end
	local function guarida(e, capa)
		local g = e.por[capa]
		if not g then
			g = { capa = capa, nombre = Gu.Nombre(capa), lobos = 0, mia = mia ~= nil and mia.capa == capa and e.mia }
			e.por[capa] = g
			e.guaridas[#e.guaridas + 1] = g
		end
		return g
	end
	if mia then guarida(zona(mia.map), mia.capa) end
	for clave, v in pairs(vistas) do
		if ahora - v.at > CADUCA then
			vistas[clave] = nil
		else
			local e = zona(v.map)
			local g = guarida(e, v.capa)
			g.lobos = g.lobos + 1
			e.total = e.total + 1
		end
	end
	for _, e in ipairs(lista) do
		e.por = nil
		sort(e.guaridas, function(a, b)
			if a.mia ~= b.mia then return a.mia end
			if a.lobos ~= b.lobos then return a.lobos > b.lobos end
			return a.capa < b.capa
		end)
	end
	sort(lista, function(a, b)
		if a.mia ~= b.mia then return a.mia end
		if a.total ~= b.total then return a.total > b.total end
		return a.nombre < b.nombre
	end)
	return lista
end

-- "Guarida Colmillo: 3 lobos  ·  Guarida Luna: 1 lobo"
function Gu.TextoZona(e)
	local partes = {}
	for _, g in ipairs(e.guaridas) do
		local n = g.lobos == 1 and L["1 lobo"] or format(L["%d lobos"], g.lobos)
		partes[#partes + 1] = format("%s: %s", g.nombre, n) .. (g.mia and (" (" .. L["la tuya"] .. ")") or "")
	end
	return table.concat(partes, "  \194\183  ")
end

local CAPA_MAPA = "manada.guaridasMapa"
local firmaMapa

-- Dónde poner la marca de una zona: el promedio de sus lobos a la vista
-- (en el mismo mapa), o nil.
local function lugarDe(z)
	local G = M.Gente
	if not (G and G.Alfa) then return nil end
	local por = {}
	for clave, v in pairs(vistas) do
		local e = G.Alfa(clave)
		if e and e.map and e.x and e.y and U.ZonaDe(v.map) == z and U.ZonaDe(e.map) == z then
			local s = por[e.map]
			if not s then s = { n = 0, x = 0, y = 0 } por[e.map] = s end
			s.n, s.x, s.y = s.n + 1, s.x + e.x, s.y + e.y
		end
	end
	local mejor, cual
	for map, s in pairs(por) do if not mejor or s.n > mejor.n then mejor, cual = s, map end end
	if not mejor then return nil end
	return cual, mejor.x / mejor.n, mejor.y / mejor.n
end

function Gu.PintarMapa(forzar)
	local P = A.Pins
	if not (P and P.SetLayer) then return end
	local visible = N.Get(ID, "guaridasMapa") ~= false and on("compartir")
	local pins, partes = {}, {}
	if visible then
		local ok, ar, ag, ab = pcall(A.Theme.Accent)
		if not (ok and type(ar) == "number") then ar, ag, ab = 0.545, 0.878, 0.306 end
		local okM, icono = pcall(A.Theme.Media, "ic-huella")
		icono = okM and type(icono) == "string" and icono or "Interface\\AddOns\\Alfa\\Media\\UI\\ic-huella"
		for _, e in ipairs(Gu.PorZona()) do
			local map, x, y = lugarDe(e.map)
			if map and e.total > 0 then
				pins[#pins + 1] = {
					map = map, x = x, y = y,
					icon = icono, color = { ar, ag, ab, 1 }, backdrop = true,
					size = 18, minimapSize = 0, priority = 2, badge = tostring(e.total),
					tooltip = function(tip)
						tip:SetText(format(L["Guaridas de la manada en %s"], e.nombre), ar, ag, ab)
						for _, g in ipairs(e.guaridas) do
							tip:AddLine(format("%s: %s", g.nombre, g.lobos == 1 and L["1 lobo"] or format(L["%d lobos"], g.lobos)), 1, 1, 1)
						end
					end,
				}
				partes[#partes + 1] = format("%d:%.0f:%.0f:%s", map, x, y, Gu.TextoZona(e))
			end
		end
	end
	local f = table.concat(partes, "|")
	if forzar or f ~= firmaMapa then
		firmaMapa = f
		pcall(P.SetLayer, CAPA_MAPA, pins, { world = true, minimap = false, edge = false })
	end
	pcall(P.SetLayerVisible, CAPA_MAPA, visible)
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

local function revisarPlacas()
	if U.EnInstancia() then return end
	for i = 1, 40 do
		local unit = "nameplate" .. i
		local ok, existe = pcall(UnitExists, unit)
		if ok and U.Leer(existe) and leerUnidad(unit) then return end
	end
end

A.RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit) if type(unit) == "string" then leerUnidad(unit) end end)
A.RegisterEvent("PLAYER_TARGET_CHANGED", function() leerUnidad("target") end)
A.RegisterEvent("UPDATE_MOUSEOVER_UNIT", function() leerUnidad("mouseover") end)
-- Otra zona u otra capa: no se sabe hasta ver otra criatura.
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", olvidarMia)
A.RegisterEvent("PLAYER_ENTERING_WORLD", olvidarMia)
-- Al entrar o salir de un grupo la capa puede cambiar: se vuelve a mirar.
A.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	-- (una sola vez por ráfaga de eventos: antes cada uno restaba otra vez)
	if actual then actual.at = math.min(actual.at, U.Ahora() - VIGENTE / 2) end
	A.After(3, revisarPlacas)
end)

M.Cada("manada.guaridas", 10, function() -- un solo reloj (1.2.9)
	revisarPlacas()
	Gu.Anunciar(false)
	pcall(Gu.PintarMapa, false) -- 1.3.0
	if pedido and U.Ahora() > pedido.hasta then pedido = nil cambio() end
end)
