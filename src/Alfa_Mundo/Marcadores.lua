-- Alfa - Mundo: tus marcadores (toxic3000 / La Jauría). GPL-3.0.
--
-- Un marcador es un punto tuyo con nombre, ícono y color, guardado para la
-- cuenta (N.Datos("mundo").marcadores: los ves con todos tus personajes).
--   * Se ven en el mapa de Alfa, en el del juego y en el minimapa: dos capas
--     de Alfa.Pins del motor ("mundo.marcadores" en los mapas,
--     "mundo.marcadoresMini" en el minimapa), cada una con su interruptor en
--     el control de capas (grupo "Tus marcadores").
--   * Seguir: la flecha del motor y su ruta (Nav.SetTarget, que vuelve a
--     planear el viaje con vuelos y barcos) como un viaje (Nav.StartTrip):
--     al llegar, la flecha vuelve a la guía. Sirve también para cualquier
--     punto o pin del mapa (Mk.SeguirPunto).
--   * Compartir con el grupo: un mensaje de addon oculto (prefijo
--     "AlfaMarca") al grupo o la banda. Quien usa Alfa lo recibe como
--     marcador suyo, con el nombre de quien lo mandó, y un aviso para
--     seguirlo. Dentro de una instancia el juego no deja mandarlo: queda en
--     espera y sale solo al salir.
--
-- Mensaje (versión 1, campos separados por "|"):
--   1|<uiMapID>|<x * 100>|<y * 100>|<ícono>|<color>|<nombre>

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local Geo, Capas = M.Geo, M.Capas

local type, ipairs, pairs, pcall, tonumber, tostring, floor, max, min = type, ipairs, pairs, pcall, tonumber, tostring, math.floor, math.max, math.min
local format = string.format

local Mk = {}
M.Marcadores = Mk

local ID = "mundo"
local CAPA, CAPA_MINI = "mundo.marcadores", "mundo.marcadoresMini"
Mk.CAPA = CAPA
local PREFIJO = "AlfaMarca"
local MAX_MARCADORES = 400
local MAX_RECIBIDOS = 60   -- marcadores que te compartieron, como mucho (1.2.0)
local POR_MINUTO = 3       -- marcadores que acepta de una misma persona por minuto
local LARGO_NOMBRE = 40
local UI = "Interface\\AddOns\\Alfa\\Media\\UI\\"
local MAPA = "Interface\\AddOns\\Alfa\\Media\\Map\\"

-- Los íconos, en el orden del editor.
Mk.ICONOS = {
	{ clave = "huella", nombre = L["Huella"], tex = UI .. "ic-huella" },
	{ clave = "lobo", nombre = L["Lobo"], tex = UI .. "ic-lobo" },
	{ clave = "cofre", nombre = L["Cofre"], tex = MAPA .. "icon-treasure" },
	{ clave = "peligro", nombre = L["Peligro"], tex = UI .. "ic-alerta" },
	{ clave = "mision", nombre = L["Misión"], tex = UI .. "ic-misiones" },
	{ clave = "mazmorra", nombre = L["Mazmorra"], tex = UI .. "ic-mazmorra" },
	{ clave = "raro", nombre = L["Enemigo raro"], tex = UI .. "ic-raros" },
	{ clave = "recurso", nombre = L["Recurso"], tex = UI .. "ic-recoleccion" },
	{ clave = "pesca", nombre = L["Pesca"], tex = UI .. "ic-pesca" },
	{ clave = "oro", nombre = L["Oro"], tex = UI .. "ic-oro" },
	{ clave = "comercio", nombre = L["Comercio"], tex = UI .. "ic-comercio" },
	{ clave = "posada", nombre = L["Posada"], tex = MAPA .. "icon-inn" },
	{ clave = "destino", nombre = L["Destino"], tex = MAPA .. "icon-target" },
}
local porIcono = {}
for _, ic in ipairs(Mk.ICONOS) do porIcono[ic.clave] = ic end

-- Los colores: tokens del Kit (cada jugador los ve con su tema).
Mk.COLORES = {
	{ clave = "acento", nombre = L["Verde de la manada"] }, { clave = "oro", nombre = L["Oro"] },
	{ clave = "aviso", nombre = L["Ámbar"] }, { clave = "peligro", nombre = L["Rojo"] },
	{ clave = "raro", nombre = L["Naranja"] }, { clave = "lugar", nombre = L["Arena"] },
	{ clave = "pnj", nombre = L["Azul"] }, { clave = "mazmorra", nombre = L["Violeta"] },
	{ clave = "objeto", nombre = L["Lavanda"] }, { clave = "texto", nombre = L["Blanco"] },
}
local porColor = {}
for _, c in ipairs(Mk.COLORES) do porColor[c.clave] = c end

function Mk.Textura(icono) return (porIcono[icono] or porIcono.huella).tex end
function Mk.Color(m) return K.Color(porColor[m and m.color] and m.color or "acento") end

---------------------------------------------------------------------------
-- Avisos: la página, el mapa y el panel se rearman cuando algo cambia.
---------------------------------------------------------------------------
local oyentes = {}
function Mk.AlCambiar(fn) if type(fn) == "function" then oyentes[#oyentes + 1] = fn end end

local publicar -- (abajo)
local pendienteAviso = false
local function vaciar()
	pendienteAviso = false
	publicar()
	for i = 1, #oyentes do K.Llamar(oyentes[i]) end
end
local function avisar()
	if pendienteAviso then return end
	pendienteAviso = true
	if type(A.After) == "function" then A.After(0, vaciar) else vaciar() end
end
Mk.Avisar = avisar

---------------------------------------------------------------------------
-- Datos
---------------------------------------------------------------------------
local function datos()
	local d = N.Datos(ID)
	if type(d.marcadores) ~= "table" then d.marcadores = {} end
	d.siguienteMarca = tonumber(d.siguienteMarca) or 1
	return d
end

local function valido(m)
	return type(m) == "table" and type(m.mapa) == "number" and type(m.x) == "number" and type(m.y) == "number"
end

-- La lista (de lo más nuevo a lo más viejo), sin los que se dañaron.
function Mk.Lista()
	local lista = datos().marcadores
	for i = #lista, 1, -1 do if not valido(lista[i]) then table.remove(lista, i) end end
	return lista
end

function Mk.Cuantos() return #Mk.Lista() end

function Mk.PorId(id)
	for i, m in ipairs(Mk.Lista()) do if m.id == id then return m, i end end
	return nil
end

-- Un nombre de usar y tirar: sin "|" (rompe el chat y el mensaje), sin
-- saltos de línea, recortado sin partir una letra con tilde.
local function limpiar(nombre)
	nombre = tostring(nombre or ""):gsub("[|\r\n\t]", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if #nombre > LARGO_NOMBRE then
		nombre = nombre:sub(1, LARGO_NOMBRE)
		-- Quita una letra partida (bytes 0x80-0xBF al final sin su inicio).
		nombre = nombre:gsub("[\192-\255][\128-\191]*$", "")
	end
	return nombre
end
Mk.Limpiar = limpiar

-- La zona de un punto: los marcadores se guardan en el mapa de su zona (o
-- del continente sobre el mar), así su nombre y sus coordenadas son las que
-- ves en el juego. -> mapa, x, y
local function enZona(mapa, x, y)
	local u, v = Geo.DeMapa(mapa, x, y)
	if not u then return mapa, x, y end
	local cont, zona = Geo.Cadena(u, v)
	local destino = zona or cont
	if not destino or destino == mapa then return mapa, x, y end
	local zx, zy = Geo.AMapa(destino, u, v)
	if not (zx and zy and zx >= 0 and zx <= 100 and zy >= 0 and zy <= 100) then return mapa, x, y end
	return destino, zx, zy
end
Mk.EnZona = enZona

function Mk.NombreLugar(m)
	return (m and Geo.Nombre(m.mapa)) or L["Lugar desconocido"]
end

function Mk.TextoCoords(x, y)
	local Maps = A.Maps
	if Maps and type(Maps.FormatCoords) == "function" then return Maps.FormatCoords(x, y) end
	return format("%.1f, %.1f", x or 0, y or 0)
end

-- "Bosque de Elwynn · 45.2, 33.1"
function Mk.Donde(m)
	return Mk.NombreLugar(m) .. "  \194\183  " .. Mk.TextoCoords(m.x, m.y)
end

-- 1.3.9 (79): la nota de un marcador (opcional, una línea, sin códigos).
Mk.LARGO_NOTA = 120
function Mk.LimpiarNota(t)
	if type(t) ~= "string" then return nil end
	if issecretvalue and issecretvalue(t) then return nil end
	t = t:gsub("[|\r\n\t]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if t == "" then return nil end
	if #t > Mk.LARGO_NOTA then t = t:sub(1, Mk.LARGO_NOTA):gsub("[\192-\255][\128-\191]*$", "") end
	return t
end

-- spec = { mapa, x, y (0-100), nombre, icono, color, de, nota } -> el marcador
function Mk.Crear(spec)
	if type(spec) ~= "table" then return nil end
	local mapa, x, y = tonumber(spec.mapa), tonumber(spec.x), tonumber(spec.y)
	if not (mapa and x and y) then return nil end
	mapa, x, y = enZona(mapa, x, y)
	local d = datos()
	local nombre = limpiar(spec.nombre)
	if nombre == "" then nombre = Geo.Nombre(mapa) or L["Marcador"] end
	local m = {
		id = d.siguienteMarca, nombre = nombre, mapa = mapa,
		x = floor(x * 100 + 0.5) / 100, y = floor(y * 100 + 0.5) / 100,
		icono = porIcono[spec.icono] and spec.icono or "huella",
		color = porColor[spec.color] and spec.color or "acento",
		creado = time and time() or 0,
		de = type(spec.de) == "string" and spec.de ~= "" and spec.de or nil,
		nota = Mk.LimpiarNota(spec.nota), -- 1.3.9 (79)
	}
	d.siguienteMarca = d.siguienteMarca + 1
	-- Lo que te compartieron nunca saca a tus propios marcadores (1.2.0): si
	-- hay demás, se va primero el compartido más viejo.
	local function quitarCompartidoViejo()
		for i = #d.marcadores, 1, -1 do
			if d.marcadores[i].de then
				table.remove(d.marcadores, i)
				return true
			end
		end
		return false
	end
	if m.de then
		local recibidos = 0
		for _, x in ipairs(d.marcadores) do if x.de then recibidos = recibidos + 1 end end
		while recibidos >= MAX_RECIBIDOS and quitarCompartidoViejo() do recibidos = recibidos - 1 end
	end
	table.insert(d.marcadores, 1, m)
	while #d.marcadores > MAX_MARCADORES do
		if not quitarCompartidoViejo() then table.remove(d.marcadores) end
	end
	avisar()
	return m
end

-- cambios = { nombre, icono, color }
function Mk.Cambiar(id, cambios)
	local m = Mk.PorId(id)
	if not (m and type(cambios) == "table") then return nil end
	if cambios.nombre ~= nil then
		local nombre = limpiar(cambios.nombre)
		m.nombre = nombre ~= "" and nombre or (Geo.Nombre(m.mapa) or L["Marcador"])
	end
	if porIcono[cambios.icono] then m.icono = cambios.icono end
	if porColor[cambios.color] then m.color = cambios.color end
	if cambios.nota ~= nil then m.nota = Mk.LimpiarNota(cambios.nota) end -- 1.3.9 (79)
	avisar()
	return m
end

-- Borra y avisa con "Deshacer" (se recupera en el mismo lugar de la lista).
function Mk.Borrar(id, callado)
	local m, i = Mk.PorId(id)
	if not m then return false end
	if Mk.Siguiendo(id) then Mk.Dejar(true) end
	table.remove(datos().marcadores, i)
	avisar()
	if not callado then
		K.Aviso({
			titulo = L["Marcador borrado"], texto = m.nombre, icono = "ic-huella", tono = "neutro", duracion = 6,
			accion = { texto = L["Deshacer"], alClic = function()
				local lista = datos().marcadores
				table.insert(lista, min(i, #lista + 1), m)
				avisar()
			end },
		})
	end
	return true
end

function Mk.BorrarTodos()
	Mk.Dejar(true)
	datos().marcadores = {}
	avisar()
end

---------------------------------------------------------------------------
-- Seguir: la flecha y la ruta del motor
---------------------------------------------------------------------------
local seguido -- { id, objetivo } del marcador al que va la flecha
local desdeOtroModulo = false -- AlfaMundo.SeguirPunto / SeguirMarcador: ese módulo decide qué ventanas cierra

-- A un punto cualquiera: mapa, x, y (0-100), nombre, marco (f = "e" para
-- las coordenadas de la era, las de algunos pines del motor). -> true | false
-- 1.3.7: lo que sale mal, en el mapa de Alfa si está abierto (Ventana.lua, V.Decir).
local function error_(texto)
	local d = M.Decir
	if type(d) == "function" then return d(texto) end
	N.Imprimir(texto)
end

function Mk.SeguirPunto(mapa, x, y, nombre, marco, id)
	local Nav = A.Nav
	if not (Nav and type(Nav.SetTarget) == "function") then return false end
	nombre = (nombre and nombre ~= "") and nombre or (Geo.Nombre(mapa) or L["Destino"])
	local t = Nav.SetTarget(mapa, x, y, nombre, marco)
	if not t then
		error_(L["Ahí no se puede poner la flecha."])
		return false
	end
	if type(Nav.StartTrip) == "function" then Nav.StartTrip(t, nombre, L["Marcador"], "arrive") end
	seguido = id and { id = id, objetivo = t } or nil
	if A.Get("nav.arrow") == false then
		N.Imprimir(format(L["La ruta te lleva a %s. La flecha está apagada: enciéndela en Ajustes > Guía para verla."], nombre))
	else
		N.Imprimir(format(L["La flecha te lleva a %s."], nombre))
	end
	avisar()
	-- Empieza el seguimiento: se cierran el mapa y las ventanas de Alfa y se
	-- ve el rastreador (N.EmpezarRuta, del núcleo). Toda acción del jugador
	-- que sigue algo pasa por aquí: pines, fichas, la lista, el aviso, Ctrl+clic.
	if not desdeOtroModulo and type(N.EmpezarRuta) == "function" then N.EmpezarRuta() end
	return true
end

function Mk.Seguir(id)
	local m = type(id) == "table" and id or Mk.PorId(id)
	if not m then return false end
	return Mk.SeguirPunto(m.mapa, m.x, m.y, m.nombre, nil, m.id)
end

-- Si la flecha va a ese marcador (o a alguno, sin id).
function Mk.Siguiendo(id)
	if not seguido then return false end
	local Nav = A.Nav
	local t = Nav and Nav.GetTarget and Nav.GetTarget()
	if t ~= seguido.objetivo then
		seguido = nil
		return false
	end
	return id == nil or seguido.id == id
end

-- Deja de seguirlo: la flecha vuelve a la guía.
function Mk.Dejar(callado)
	if not Mk.Siguiendo() then return end
	seguido = nil
	local Nav = A.Nav
	if callado then
		if Nav and Nav.ReleaseTarget then Nav.ReleaseTarget() end
	elseif Nav and Nav.BackToGuide then
		Nav.BackToGuide()
	end
	avisar()
end

function Mk.AlternarSeguir(id)
	if Mk.Siguiendo(id) then Mk.Dejar() else Mk.Seguir(id) end
end

-- La flecha cambió de destino (otra cosa, o llegaste): la lista lo refleja.
A.On("WAYPOINT_CHANGED", function()
	if seguido and not Mk.Siguiendo() then avisar() end
end)

---------------------------------------------------------------------------
-- Compartir con el grupo
---------------------------------------------------------------------------
local function canal()
	if IsInRaid and IsInRaid() then return "RAID" end
	if IsInGroup and IsInGroup() then return "PARTY" end
	return nil
end

local function cuentaDePrueba()
	for _, fn in ipairs({ IsTrialAccount or false, IsVeteranTrialAccount or false }) do
		if type(fn) == "function" then
			local ok, si = pcall(fn)
			if ok and si == true then return true end
		end
	end
	return false
end

local function enInstancia()
	local C = A.Compat
	return C and C.IsInInstance and C.IsInInstance() and true or false
end

-- -> true | false, por qué ("grupo", "prueba", "instancia", "api")
function Mk.PuedeCompartir()
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false, "api" end
	if not canal() then return false, "grupo" end
	if cuentaDePrueba() then return false, "prueba" end
	if enInstancia() then return false, "instancia" end
	return true
end

function Mk.PorQueNo(por)
	if por == "grupo" then return L["Únete a un grupo para compartir tus marcadores."] end
	if por == "prueba" then return L["Las cuentas de prueba no pueden compartir: el juego no lo permite."] end
	if por == "instancia" then return L["Dentro de una instancia el juego no deja compartir: sale solo cuando salgas."] end
	return L["Este cliente no deja compartir marcadores."]
end

local prefijoListo = false
local function prefijo()
	if prefijoListo or not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
	local esta = C_ChatInfo.IsAddonMessagePrefixRegistered
	if esta and esta(PREFIJO) then prefijoListo = true return end
	local ok, r = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIJO)
	-- Listo solo si de verdad quedó registrado: si no, se reintenta al enviar.
	if esta then prefijoListo = esta(PREFIJO) and true or false
	else prefijoListo = ok and r ~= false end
end

local function mensaje(m)
	return table.concat({ "1", tostring(m.mapa), tostring(floor(m.x * 100 + 0.5)), tostring(floor(m.y * 100 + 0.5)),
		m.icono or "huella", m.color or "acento", limpiar(m.nombre) }, "|")
end

local enEspera = {} -- ids que esperan salir de la instancia

local function enviar(m)
	prefijo()
	local c = canal()
	if not c then return false end
	local ok, r = pcall(C_ChatInfo.SendAddonMessage, PREFIJO, mensaje(m), c)
	local RES = Enum and Enum.SendAddonMessageResult
	local exito = RES and RES.Success or 0
	return ok and (r == nil or r == true or r == exito)
end

function Mk.Compartir(id)
	local m = type(id) == "table" and id or Mk.PorId(id)
	if not m then return false end
	local puede, por = Mk.PuedeCompartir()
	if not puede then
		if por == "instancia" then
			enEspera[m.id] = true
			N.Imprimir(format(L["%s se compartirá con tu grupo al salir de la instancia."], m.nombre))
		else
			error_(Mk.PorQueNo(por))
		end
		return false
	end
	if enviar(m) then
		N.Imprimir(format(L["Compartiste %s con tu grupo."], m.nombre))
		return true
	end
	-- El servidor frenó: un segundo intento enseguida.
	if type(A.After) == "function" then
		A.After(2, function()
			if enviar(m) then N.Imprimir(format(L["Compartiste %s con tu grupo."], m.nombre))
			else error_(L["El juego no dejó compartir el marcador ahora. Prueba en un momento."]) end
		end)
	end
	return false
end

local function vaciarEspera()
	if not next(enEspera) or not Mk.PuedeCompartir() then return end
	local ids = enEspera
	enEspera = {}
	for id in pairs(ids) do
		local m = Mk.PorId(id)
		if m and enviar(m) then N.Imprimir(format(L["Compartiste %s con tu grupo."], m.nombre)) end
	end
end

-- Lo que llega de otro jugador del grupo con Alfa.
local recientes = {} -- firma -> momento (no repetir el mismo marcador)
local porPersona = {} -- quien -> { momentos de lo que aceptó en el último minuto }

-- Solo del grupo o la banda en que estás (1.2.0): un susurro, la hermandad o
-- un canal no traen marcadores, y quien los manda tiene que estar contigo.
local CANALES = { PARTY = true, RAID = true, INSTANCE_CHAT = true }
local function delGrupo(emisor)
	if type(emisor) ~= "string" then return false end
	local nombre = Ambiguate and Ambiguate(emisor, "none") or emisor
	for _, fn in ipairs({ UnitInParty, UnitInRaid }) do
		if type(fn) == "function" then
			local ok, si = pcall(fn, nombre)
			if ok and si then return true end
		end
	end
	return false
end

-- No más de POR_MINUTO por persona; lo viejo se olvida.
local function dentroDelLimite(quien, ahora)
	local t = porPersona[quien] or {}
	local vivos = {}
	for _, m in ipairs(t) do if ahora - m < 60 then vivos[#vivos + 1] = m end end
	if #vivos >= POR_MINUTO then porPersona[quien] = vivos return false end
	vivos[#vivos + 1] = ahora
	porPersona[quien] = vivos
	for firma, cuando in pairs(recientes) do
		if ahora - cuando >= 60 then recientes[firma] = nil end
	end
	return true
end

local function alRecibir(_, pre, texto, tipoCanal, emisor)
	if pre ~= PREFIJO or type(texto) ~= "string" then return end
	local C = A.Compat
	if C and C.IsSecret and (C.IsSecret(texto) or C.IsSecret(emisor) or C.IsSecret(tipoCanal)) then return end
	if C and C.SenderIsMe and C.SenderIsMe(emisor) then return end
	if A.Get("mundo.recibirMarcadores") == false then return end
	if not CANALES[tipoCanal] or not delGrupo(emisor) then return end
	local v, mapa, x, y, icono, color, nombre = strsplit("|", texto, 7)
	if v ~= "1" then return end
	-- Solo dígitos: tonumber acepta "nan", "inf" o "1e300", que rompen el mapa.
	if not (type(mapa) == "string" and mapa:match("^%d+$") and type(x) == "string" and x:match("^%d+$")
		and type(y) == "string" and y:match("^%d+$")) then return end
	mapa, x, y = tonumber(mapa), tonumber(x), tonumber(y)
	if not (mapa and x and y and mapa >= 1 and mapa <= 100000 and x >= 0 and x <= 10000 and y >= 0 and y <= 10000) then return end
	x, y = x / 100, y / 100
	local quien = (C and C.SenderName and C.SenderName(emisor)) or (type(emisor) == "string" and emisor) or "?"
	nombre = limpiar(nombre)
	local firma = table.concat({ quien, mapa, floor(x), floor(y), nombre }, ":")
	local ahora = GetTime and GetTime() or 0
	if recientes[firma] and ahora - recientes[firma] < 60 then return end
	if not dentroDelLimite(quien, ahora) then return end
	recientes[firma] = ahora
	-- Ya lo tienes (te lo mandaron antes): no se duplica.
	for _, m in ipairs(Mk.Lista()) do
		if m.de == quien and m.nombre == nombre and math.abs(m.x - x) < 0.2 and math.abs(m.y - y) < 0.2 then return end
	end
	local m = Mk.Crear({ mapa = mapa, x = x, y = y, nombre = nombre, icono = icono, color = color, de = quien })
	if not m then return end
	K.Aviso({
		titulo = format(L["%s compartió un marcador"], quien), texto = m.nombre .. "  \194\183  " .. Mk.NombreLugar(m),
		icono = "ic-huella", tono = "acento", duracion = 10,
		accion = { texto = L["Seguir"], alClic = function() Mk.Seguir(m.id) end },
	})
end

AlfaNucleo.PorPrefijo(PREFIJO, alRecibir)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() prefijo() vaciarEspera() end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", vaciarEspera)
-- El grupo solo cambia si se puede compartir: los pines no se rehacen y los
-- oyentes (página, panel, ficha) se avisan solo si cambió el canal.
local ultimoCanal = false
A.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	local c = canal() or false
	if c == ultimoCanal then return end
	ultimoCanal = c
	for i = 1, #oyentes do K.Llamar(oyentes[i]) end
end)

---------------------------------------------------------------------------
-- Los pines (mapa de Alfa, mapa del juego y minimapa)
---------------------------------------------------------------------------
local function linea(tt, texto, token)
	local r, g, b = K.Color(token)
	tt:AddLine(texto, r, g, b, true)
end

local function tooltip(m)
	return function(tt)
		local r, g, b = Mk.Color(m)
		tt:SetText(m.nombre, r, g, b)
		linea(tt, Mk.Donde(m), "textoSuave")
		if m.nota then linea(tt, m.nota, "texto") end -- 1.3.9 (79)
		if m.de then linea(tt, format(L["Compartido por %s"], m.de), "textoTenue") end
		if Mk.Siguiendo(m.id) then linea(tt, L["La flecha te lleva aquí."], "acento") end
		linea(tt,L["Clic: opciones  \194\183  Mayús+clic: seguir"], "textoTenue")
	end
end

-- Clic en el pin de un marcador (cualquier mapa): Mayús+clic lo sigue;
-- si no, se abre su ficha junto al pin.
function Mk.AlClicPin(id, boton, dueno)
	local m = Mk.PorId(id)
	if not m then return end
	if boton == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
		Mk.AlternarSeguir(id)
		return
	end
	local E = M.Editor
	if E and E.Abrir then E.Abrir({ marcador = m, ancla = dueno }) end
end

local function pinDe(m, mini)
	local r, g, b = Mk.Color(m)
	local foco = Mk.Siguiendo(m.id)
	return {
		map = m.mapa, x = m.x, y = m.y, icon = Mk.Textura(m.icono),
		size = mini and 15 or 18, minimapSize = 15,
		color = { r, g, b, 1 }, backdrop = true, ring = { r, g, b, foco and 1 or 0.85 }, glow = foco or nil,
		priority = 120, tooltip = tooltip(m), amMarcador = m.id,
		onClick = function(boton, dueno) Mk.AlClicPin(m.id, boton, dueno) end,
	}
end

function publicar()
	local Pins = A.Pins
	if not (Pins and type(Pins.SetLayer) == "function") then return end
	local mapas, mini = {}, {}
	for i, m in ipairs(Mk.Lista()) do
		mapas[i] = pinDe(m, false)
		mini[i] = pinDe(m, true)
	end
	Pins.SetLayer(CAPA, mapas, { world = true, minimap = false })
	Pins.SetLayer(CAPA_MINI, mini, { world = false, minimap = true })
	if type(Pins.SetLayerVisible) == "function" then
		local e1, e2 = Capas.PorId("marcadores.mapas"), Capas.PorId("marcadores.minimapa")
		Pins.SetLayerVisible(CAPA, not e1 or Capas.Activa(e1))
		Pins.SetLayerVisible(CAPA_MINI, not e2 or Capas.Activa(e2))
	end
	if M.Ventana and M.Ventana.Repintar then M.Ventana.Repintar() end
end
Mk.Publicar = publicar

-- Las dos capas en el control de capas (Capas.lua): esenciales, porque son
-- tuyas; el modo limpio las deja.
Capas.Registrar({
	id = "marcadores.mapas", grupo = "marcadores", nombre = L["En los mapas"], esencial = true,
	icono = UI .. "ic-huella", color = "accent", pines = CAPA, zoom = 0, activa = true,
	ayuda = L["Tus marcadores en el mapa de Alfa y en el del juego."],
	alCambiar = function(on)
		local Pins = A.Pins
		if Pins and Pins.SetLayerVisible then Pins.SetLayerVisible(CAPA, on) end
	end,
})
Capas.Registrar({
	id = "marcadores.minimapa", grupo = "marcadores", nombre = L["En el minimapa"], esencial = true,
	icono = UI .. "ic-huella", color = "textDim", activa = true,
	ayuda = L["Tus marcadores también en el minimapa, cuando estás cerca."],
	alCambiar = function(on)
		local Pins = A.Pins
		if Pins and Pins.SetLayerVisible then Pins.SetLayerVisible(CAPA_MINI, on) end
	end,
})

-- Al entrar, y cuando cambian los colores del tema.
if type(A.OnLogin) == "function" then A.OnLogin(function() prefijo() publicar() end) end
if K.AlRepintar then K.AlRepintar(function() avisar() end) end

---------------------------------------------------------------------------
-- Cualquier pin del mapa de Alfa (Marcas.lua): clic derecho abre este menú
-- para seguirlo o guardarlo como marcador tuyo.
---------------------------------------------------------------------------

-- El nombre que dice un pin: su etiqueta, su texto o la primera línea de su cuadro.
local function nombreDePin(p)
	if type(p.label) == "string" and p.label ~= "" then return p.label end
	-- Un maestro de vuelo (Maps/TravelPins.lua): el nombre de su nodo, en tu idioma.
	if p.nodeID then
		local Nv = A.Nav
		local ok, d = false, nil
		if Nv and type(Nv.GetTravelData) == "function" then ok, d = pcall(Nv.GetTravelData) end
		local nodo = ok and type(d) == "table" and type(d.taxiById) == "table" and d.taxiById[p.nodeID] or nil
		if type(nodo) == "table" then
			local T = Nv.travel
			local nombre = T and type(T.TaxiName) == "function" and T.TaxiName(nodo) or nodo.name
			if type(nombre) == "string" and nombre ~= "" then return nombre end
		end
	end
	-- (DistanciaPines.lua envuelve el cuadro en una función y deja el texto en alfaTipTexto)
	local tip = p.alfaTipTexto or p.tooltip
	if type(tip) == "string" then
		local linea = tip:match("^([^\n]+)")
		if linea then return (linea:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	end
	return nil
end

Mk.NombreDePin = nombreDePin

-- El pin en el mapa de su zona: mapa, x, y | nil
local function lugarDePin(p)
	local u, v = Geo.DePin(p)
	if not u then return nil end
	local cont, zona = Geo.Cadena(u, v)
	local mapa = zona or cont
	if not mapa then return nil end
	local x, y = Geo.AMapa(mapa, u, v)
	if not x then return nil end
	return mapa, x, y
end

function Mk.MenuPin(dueno, p)
	if type(p) ~= "table" then return end
	local mapa, x, y = lugarDePin(p)
	if not mapa then return end
	local nombre = nombreDePin(p) or Geo.Nombre(mapa) or L["Destino"]
	K.Menu(dueno, {
		{ valor = "seguir", texto = L["Seguir (flecha y ruta)"], icono = "ic-seguir" },
		{ valor = "guardar", texto = L["Guardar como marcador"], icono = "ic-huella" },
	}, nil, function(que)
		if que == "seguir" then
			if type(p.map) == "number" and type(p.x) == "number" and type(p.y) == "number" then
				Mk.SeguirPunto(p.map, p.x, p.y, nombre, p.f)
			else
				Mk.SeguirPunto(mapa, x, y, nombre)
			end
		elseif que == "guardar" then
			local E = M.Editor
			if E and E.Abrir then E.Abrir({ nuevo = { mapa = mapa, x = x, y = y, nombre = nombre }, ancla = dueno }) end
		end
	end, 220)
end

---------------------------------------------------------------------------
-- Para otros módulos (LEEME.md, "Marcadores")
---------------------------------------------------------------------------
local API = AlfaMundo
API.Marcadores = function()
	local out = {}
	for i, m in ipairs(Mk.Lista()) do
		out[i] = { id = m.id, nombre = m.nombre, mapa = m.mapa, x = m.x, y = m.y, icono = m.icono, color = m.color, de = m.de, nota = m.nota }
	end
	return out
end
API.PonerMarcador = function(spec)
	local m = Mk.Crear(spec)
	return m and m.id or nil
end
local function deOtroModulo(fn, ...)
	desdeOtroModulo = true
	local ok, r = pcall(fn, ...)
	desdeOtroModulo = false
	if not ok then
		if geterrorhandler then geterrorhandler()(r) end
		return false
	end
	return r
end
API.SeguirMarcador = function(id) return deOtroModulo(Mk.Seguir, id) end
API.SeguirPunto = function(mapa, x, y, nombre) return deOtroModulo(Mk.SeguirPunto, tonumber(mapa), tonumber(x), tonumber(y), nombre) end
