-- Alfa - Mundo: un solo control de capas para todo lo que se pinta en los
-- mapas (toxic3000 / La Jauría). GPL-3.0.
--
-- Cada capa es un interruptor con nombre, grupo e ícono:
--   * las del motor (guía, misiones, raros, viaje, zonas) están enlazadas a
--     sus propios ajustes (nav.*, qol.*, rares.*, maps.*): no se duplican,
--     moverlas aquí es moverlas en la página Mapa y al revés;
--   * las del mapa de Alfa (tu grupo, nombres de zona) son ajustes de Mundo;
--   * las de otros módulos llegan por AlfaMundo.RegistrarCapa (contrato en
--     LEEME.md) y su estado se guarda en mundo.capas.<id>.
--
-- Modo limpio: de un clic deja solo lo esencial (tú, tu grupo y el
-- siguiente paso de la guía). Apaga las demás capas recordando cómo
-- estaban (mundo.antes / mundo.suprimidas) y al salir las devuelve, salvo
-- las que tocaste mientras tanto.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

local type, pairs, ipairs, pcall, tonumber, tostring, next = type, pairs, ipairs, pcall, tonumber, tostring, next
local sort = table.sort

local ID = "mundo"
local Capas = {}
M.Capas = Capas

local MAPA = "Interface\\AddOns\\Alfa\\Media\\Map\\icon-"
local UI = "Interface\\AddOns\\Alfa\\Media\\UI\\"

local lista, porId, porRuta = {}, {}, {}
local grupos, grupoPorNombre = {}, {}
local porOmision = {} -- llave -> estado inicial de las capas de otros módulos
local reportado = {} -- id -> último estado efectivo dado a alCambiar
local oyentes = {}
local secuencia = 0

-- Ajustes del control de capas (el resto de Mundo los registra Mundo.lua).
A.RegisterDefaults(ID, { capas = porOmision, limpio = false, antes = false, suprimidas = false })

---------------------------------------------------------------------------
-- Grupos
---------------------------------------------------------------------------

local function grupo(nombre, orden)
	local g = grupoPorNombre[nombre]
	if g then return g end
	secuencia = secuencia + 1
	g = { nombre = nombre, orden = orden or (1000 + secuencia), capas = {} }
	grupoPorNombre[nombre] = g
	grupos[#grupos + 1] = g
	sort(grupos, function(a, b) return a.orden < b.orden end)
	return g
end

local G_ESENCIAL = grupo(L["Lo esencial"], 1)
local G_MARCAS = grupo(L["Tus marcadores"], 1.5)
local G_GUIA = grupo(L["Guía"], 2)
local G_MISIONES = grupo(L["Misiones"], 3)
local G_RAROS = grupo(L["Raros y tesoros"], 4)
local G_ENTRADAS = grupo(L["Entradas y salidas"], 4.5)
local G_VIAJE = grupo(L["Viaje y servicios"], 5)
local G_ZONAS = grupo(L["Zonas"], 6)
-- Nombres que otros módulos pueden usar para caer en un grupo de aquí.
local ALIAS = {
	esencial = G_ESENCIAL, marcadores = G_MARCAS, guia = G_GUIA, ["guía"] = G_GUIA, misiones = G_MISIONES,
	raros = G_RAROS, viaje = G_VIAJE, zonas = G_ZONAS, entradas = G_ENTRADAS, ["entradas y salidas"] = G_ENTRADAS,
}

local function agregar(g, e)
	secuencia = secuencia + 1
	e.seq = secuencia
	e.grupo = g
	local cs = g.capas
	cs[#cs + 1] = e
	sort(cs, function(a, b)
		if (a.orden or 0) ~= (b.orden or 0) then return (a.orden or 0) < (b.orden or 0) end
		return a.seq < b.seq
	end)
end

---------------------------------------------------------------------------
-- Valores
---------------------------------------------------------------------------

local function apagado(e)
	if e.apagado ~= nil then return e.apagado end
	return false
end

-- Lo que vale encendida (las zonas sin descubrir guardan "tint" u "on":
-- vuelve el último que tenía).
local function encendido(e)
	if e.ultimo ~= nil then return e.ultimo end
	if type(e.encendido) == "function" then return e.encendido() end
	if e.encendido ~= nil then return e.encendido end
	return true
end

local function limpio() return A.Get(ID .. ".limpio") == true end
Capas.Limpio = limpio

local function suprimida(id)
	if not limpio() then return false end
	local s = A.Get(ID .. ".suprimidas")
	return type(s) == "table" and s[id] == true
end

-- La capa existe en este motor (su ajuste tiene valor por omisión).
local function existe(e)
	if e.tipo ~= "ajuste" or e.propia then return true end
	if type(A.GetDefault) ~= "function" then return true end
	return A.GetDefault(e.ruta) ~= nil
end
Capas.Existe = existe

-- El estado guardado (lo que muestra el interruptor).
function Capas.Valor(e)
	if e.tipo == "ajuste" then
		local v = A.Get(e.ruta)
		if e.leer then return e.leer(v) and true or false end
		return v ~= nil and v ~= false and v ~= apagado(e)
	end
	return A.Get(ID .. ".capas." .. e.llave) ~= false
end

-- El estado que manda: el guardado, salvo lo que el modo limpio apagó.
function Capas.Activa(e)
	if not Capas.Valor(e) then return false end
	if e.tipo == "modulo" and suprimida(e.id) then return false end
	return true
end

-- Una capa que depende de otra cosa (la base de misiones, los raros):
-- -> false, por qué
function Capas.Disponible(e)
	if type(e.requiere) ~= "function" then return true end
	local ok, si, porque = pcall(e.requiere)
	if not ok then return true end
	return si and true or false, porque
end

---------------------------------------------------------------------------
-- Avisos
---------------------------------------------------------------------------

local pendiente = false

local function avisarModulo(e)
	if e.tipo ~= "modulo" or not e.alCambiar then return end
	local act = Capas.Activa(e)
	if reportado[e.id] == act then return end
	reportado[e.id] = act
	local ok, err = pcall(e.alCambiar, act)
	if not ok and geterrorhandler then geterrorhandler()(err) end
end

local function vaciar()
	pendiente = false
	for _, e in ipairs(lista) do avisarModulo(e) end
	for i = 1, #oyentes do
		local ok, err = pcall(oyentes[i])
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
end

-- Todo lo que cambió en este cuadro se avisa una vez, en el siguiente.
local function avisar()
	if pendiente then return end
	pendiente = true
	if type(A.After) == "function" then A.After(0, vaciar) else vaciar() end
end
Capas.Avisar = avisar

-- fn() cuando cambia cualquier capa, el modo limpio o la lista.
function Capas.AlCambiar(fn)
	if type(fn) == "function" then oyentes[#oyentes + 1] = fn end
end

---------------------------------------------------------------------------
-- Cambiar
---------------------------------------------------------------------------

local function copiaSin(t, clave)
	if type(t) ~= "table" then return false end
	local out = {}
	for k, v in pairs(t) do if k ~= clave then out[k] = v end end
	return next(out) and out or false
end

-- mundo.suprimidas: id -> true (el modo limpio la apagó) | false (la
-- encendiste tú durante el modo limpio: se respeta aunque el módulo se
-- vuelva a registrar tras un /reload).
local function marcarSuprimida(id, valor)
	local s = A.Get(ID .. ".suprimidas")
	local out = {}
	if type(s) == "table" then for k, v in pairs(s) do out[k] = v end end
	out[id] = valor
	A.Set(ID .. ".suprimidas", out)
end

function Capas.Poner(e, on)
	if type(e) == "string" then e = porId[e] end
	if type(e) ~= "table" then return false end
	on = on and true or false
	if e.tipo == "ajuste" then
		-- Tocarla en modo limpio la saca de lo que se devolverá al salir.
		local antes = A.Get(ID .. ".antes")
		if type(antes) == "table" and antes[e.ruta] ~= nil then A.Set(ID .. ".antes", copiaSin(antes, e.ruta)) end
		local ahora = A.Get(e.ruta)
		if not on and e.leer and e.leer(ahora) then e.ultimo = ahora end
		A.Set(e.ruta, on and encendido(e) or apagado(e))
	else
		if limpio() then marcarSuprimida(e.id, false) end
		A.Set(ID .. ".capas." .. e.llave, on)
	end
	avisar()
	return true
end

function Capas.Alternar(e)
	if type(e) == "string" then e = porId[e] end
	if type(e) ~= "table" then return false end
	return Capas.Poner(e, not Capas.Valor(e))
end

-- Modo limpio: apaga lo que no es esencial y recuerda cómo estaba.
function Capas.PonerLimpio(on)
	on = on and true or false
	if on == limpio() then return end
	if on then
		local antes, sup = {}, {}
		for _, e in ipairs(lista) do
			if not e.esencial and existe(e) and Capas.Valor(e) then
				if e.tipo == "ajuste" then
					antes[e.ruta] = A.Get(e.ruta)
				else
					sup[e.id] = true
				end
			end
		end
		A.Set(ID .. ".antes", next(antes) and antes or false)
		A.Set(ID .. ".suprimidas", next(sup) and sup or false)
		A.Set(ID .. ".limpio", true)
		for ruta in pairs(antes) do
			local e = porRuta[ruta]
			A.Set(ruta, e and apagado(e) or false)
		end
	else
		local antes = A.Get(ID .. ".antes")
		A.Set(ID .. ".limpio", false)
		A.Set(ID .. ".antes", false)
		A.Set(ID .. ".suprimidas", false)
		if type(antes) == "table" then
			for ruta, v in pairs(antes) do
				local e = porRuta[ruta]
				-- Solo lo que sigue apagado: lo que encendiste a mano se queda.
				if A.Get(ruta) == (e and apagado(e) or false) then A.Set(ruta, v) end
			end
		end
	end
	avisar()
end

function Capas.AlternarLimpio() Capas.PonerLimpio(not limpio()) end

-- Cuántas capas apagó el modo limpio (para el texto de los botones).
function Capas.CuantasOcultas()
	if not limpio() then return 0 end
	local n = 0
	local antes, sup = A.Get(ID .. ".antes"), A.Get(ID .. ".suprimidas")
	if type(antes) == "table" then for _ in pairs(antes) do n = n + 1 end end
	if type(sup) == "table" then for _, v in pairs(sup) do if v == true then n = n + 1 end end end
	return n
end

---------------------------------------------------------------------------
-- Lectura
---------------------------------------------------------------------------

function Capas.PorId(id) return porId[id] end

-- Las capas de otros módulos, en orden de registro.
local modulos = {}
function Capas.Modulos()
	for i = #modulos, 1, -1 do modulos[i] = nil end
	for _, e in ipairs(lista) do if e.tipo == "modulo" then modulos[#modulos + 1] = e end end
	return modulos
end

-- Sube cada vez que se registra una capa (las páginas se rearman).
Capas.version = 0

-- La ruta de ajustes de una capa (para marcar las que no están como vienen).
function Capas.Ruta(e)
	if e.tipo == "ajuste" then return e.ruta end
	return ID .. ".capas." .. e.llave
end

-- Cómo viene la capa de fábrica.
function Capas.PorOmision(e)
	if e.tipo == "ajuste" then
		local d = type(A.GetDefault) == "function" and A.GetDefault(e.ruta)
		if e.leer then return e.leer(d) and true or false end
		return d ~= nil and d ~= false and d ~= apagado(e)
	end
	return porOmision[e.llave] ~= false
end

-- Los grupos con sus capas existentes: { { nombre, capas = { e, ... } }, ... }
function Capas.Grupos()
	local out = {}
	for _, g in ipairs(grupos) do
		local cs = {}
		for _, e in ipairs(g.capas) do
			if existe(e) then cs[#cs + 1] = e end
		end
		if #cs > 0 then out[#out + 1] = { nombre = g.nombre, capas = cs } end
	end
	return out
end

---------------------------------------------------------------------------
-- Las capas del motor y las del mapa de Alfa
---------------------------------------------------------------------------

local function motor(g, id, ruta, nombre, ayuda, icono, color, extra)
	local e = { id = id, tipo = "ajuste", ruta = ruta, nombre = nombre, ayuda = ayuda, icono = icono, color = color }
	if extra then for k, v in pairs(extra) do e[k] = v end end
	lista[#lista + 1] = e
	porId[id] = e
	porRuta[ruta] = e
	agregar(g, e)
	return e
end

local function ajuste(ruta) return function() return A.Get(ruta) and true or false end end
local function conBase() return ajuste("qol.questDB")() , L["Necesita la base de misiones (página Misiones)."] end
local function conRaros() return ajuste("rares.enabled")(), L["Los raros están apagados (página Descubrir)."] end

-- Lo esencial: siempre se queda en modo limpio.
motor(G_ESENCIAL, "esencial.grupo", ID .. ".grupo", L["Tu grupo"],
	L["Tus compañeros de grupo y de banda en el mapa de Alfa."], MAPA .. "pin-small", "personName",
	{ esencial = true, propia = true, orden = 1 })
motor(G_ESENCIAL, "guia.mapa", "nav.worldPins", L["Siguiente paso de la guía"],
	L["El destino de la flecha, su camino y las otras metas del paso, en el mapa."], MAPA .. "target", "accent",
	{ esencial = true, orden = 2 })

-- Guía
motor(G_GUIA, "guia.ruta", "nav.routeLines", L["Línea de la ruta"],
	L["El camino hasta el destino dibujado en el mapa."], UI .. "icon-goto", "accent", { esencial = true })
motor(G_GUIA, "guia.siguientes", "nav.upcomingPins", L["Pasos que siguen, numerados"],
	L["Un pin pequeño con su número donde te llevan los próximos pasos."], MAPA .. "pin", "accent")
motor(G_GUIA, "guia.minimapa", "nav.minimapPins", L["La guía en el minimapa"],
	L["El destino de la flecha y sus zonas en el minimapa."], MAPA .. "target", "accent", { esencial = true })
motor(G_GUIA, "guia.rutaMinimapa", "nav.minimapRoute", L["Ruta en el minimapa"],
	L["La línea del camino también en el minimapa."], UI .. "icon-goto", "accent",
	{ esencial = true, requiere = function() return A.Get("nav.minimapPins") and true or false, L["Enciende primero la guía en el minimapa."] end })

-- Misiones
motor(G_MISIONES, "misiones.disponibles", "qol.availableQuests", L["Misiones que puedes aceptar"],
	L["Un signo de exclamación sobre quien te da misiones de tu nivel."], MAPA .. "quest-available", "quest", { requiere = conBase })
motor(G_MISIONES, "misiones.entregas", "qol.turnInMarkers", L["Dónde entregar"],
	L["Un signo de interrogación sobre quien recibe una misión ya lista."], MAPA .. "quest-turnin", "quest", { requiere = conBase })
motor(G_MISIONES, "misiones.objetivos", "qol.mapObjectives", L["Objetivos de tus misiones"],
	L["Zonas de enemigos, objetos y lugares de las misiones de tu registro."], MAPA .. "kill", "quest", { requiere = conBase })
motor(G_MISIONES, "misiones.minimapa", "qol.minimapObjectives", L["Misiones en el minimapa"],
	L["Los mismos marcadores de misiones en el minimapa."], MAPA .. "quest-available", "textDim", { requiere = conBase })

-- Raros y tesoros
motor(G_RAROS, "raros.mapa", "rares.worldRares", L["Raros en el mapa"],
	L["Cada lugar conocido donde aparece un enemigo raro."], MAPA .. "rare", "rare", { requiere = conRaros })
motor(G_RAROS, "raros.tesoros", "rares.worldTreasures", L["Tesoros en el mapa"],
	L["Cada cofre o tesoro conocido."], MAPA .. "treasure", "quest", { requiere = conRaros })
motor(G_RAROS, "raros.minimapa", "rares.minimapRares", L["Raros en el minimapa"],
	L["Los raros también en el minimapa."], MAPA .. "rare", "textDim", { requiere = conRaros })
motor(G_RAROS, "raros.tesorosMinimapa", "rares.minimapTreasures", L["Tesoros en el minimapa"],
	L["Los tesoros también en el minimapa."], MAPA .. "treasure", "textDim", { requiere = conRaros })

-- Entradas y salidas: mazmorras y barcos (capas del motor, con sus ids de
-- siempre), las salidas de cada zona y los portales (Entradas.lua).
motor(G_ENTRADAS, "viaje.mazmorras", "maps.dungeonPins", L["Entradas de mazmorras"],
	L["Cada entrada de mazmorra y banda con su rango de niveles. Clic: su página; Mayús+clic: la flecha te lleva."],
	MAPA .. "dungeon", "dungeon", { orden = 1 })
motor(G_ENTRADAS, "entradas.salidas", ID .. ".salidas", L["Salidas de zona"],
	L["Por dónde se pasa a otra zona (caminos, pasos, túneles y puertas), con una flecha hacia ella y su rango de niveles. Se ven al acercarte a una zona."],
	MAPA .. "pass", "link", { propia = true, orden = 2,
	  requiere = function()
		local E = M.Entradas
		return (E and E.HayDatos()) and true or false, L["Necesita las rutas a pie de Alfa (Alfa_Nav), que se cargan solas con «Seguir caminos reales» encendido."]
	  end })
motor(G_ENTRADAS, "entradas.portales", ID .. ".portales", L["Portales"],
	L["Los portales a pie que puedes usar, con a dónde llevan."], MAPA .. "portal", "link", { propia = true, orden = 4 })
motor(G_VIAJE, "viaje.vuelo", "maps.taxiPins", L["Puntos de vuelo"],
	L["Los maestros de vuelo de tu facción y los neutrales: verdes si ya los conoces, ámbar con «?» si te falta descubrirlos. Clic: seguirlo con la flecha."],
	MAPA .. "flightmaster", "success")
motor(G_ENTRADAS, "viaje.barcos", "maps.dockPins", L["Barcos, zepelines y tranvía"],
	L["Muelles y torres de zepelín, con a dónde van."], MAPA .. "boat", "link", { orden = 3 })
motor(G_VIAJE, "viaje.posadas", "maps.innPins", L["Posadas"],
	L["Posaderos; se marca el de tu piedra de hogar."], MAPA .. "inn", "place")
motor(G_VIAJE, "viaje.servicios", "maps.servicePins", L["Servicios"],
	L["Buzones, entrenadores, banco, subasta, reparar..."], MAPA .. "mailbox", "npc")
motor(G_VIAJE, "viaje.minimapa", "maps.travelMinimap", L["Iconos de viaje en el minimapa"],
	L["Vuelos, barcos y posadas también en el minimapa."], MAPA .. "flightmaster", "textDim")
motor(G_VIAJE, "viaje.serviciosMinimapa", "maps.serviceMinimap", L["Servicios en el minimapa"],
	L["Los servicios también en el minimapa."], MAPA .. "mailbox", "textDim",
	{ requiere = function() return A.Get("maps.servicePins") and true or false, L["Enciende primero los servicios."] end })

-- Zonas
motor(G_ZONAS, "zonas.descubrir", "maps.reveal", L["Zonas sin descubrir"],
	L["Muestra lo que aún no exploras, con un tono más frío para distinguirlo."], UI .. "icon-explore", "accent",
	{ esencial = true, apagado = "off",
	  leer = function(v) return v == "on" or v == "tint" end,
	  encendido = function() return "tint" end })
motor(G_ZONAS, "zonas.niveles", "maps.zoneLevels", L["Niveles de zona"],
	L["El rango de niveles de cada zona, con color según tu nivel."], UI .. "icon-level", "quest")
motor(G_ZONAS, "zonas.nombres", ID .. ".nombres", L["Nombres de zona"],
	L["El nombre de cada zona sobre el mapa de Alfa."], UI .. "icon-note", "textDim", { propia = true })
motor(G_ZONAS, "zonas.coordenadas", "maps.coords", L["Coordenadas en el mapa"],
	L["Tu posición y la del cursor bajo el mapa."], UI .. "qol-target", "textDim", { esencial = true })
motor(G_ZONAS, "zonas.coordMinimapa", "maps.minimapCoords", L["Coordenadas en el minimapa"],
	L["Tu posición en la parte de abajo del minimapa."], UI .. "qol-target", "textDim", { esencial = true })

---------------------------------------------------------------------------
-- Capas de otros módulos (contrato en LEEME.md)
---------------------------------------------------------------------------

local function llave(id) return (id:gsub("[^%w]", "_")) end

-- spec = { id, grupo, nombre, icono?, activa? (true), alCambiar?, ayuda?,
--          esencial?, color?, orden? } -> id | nil, error
function Capas.Registrar(spec)
	if type(spec) ~= "table" or type(spec.id) ~= "string" or spec.id == "" then
		return nil, "RegistrarCapa: falta id"
	end
	if type(spec.nombre) ~= "string" or spec.nombre == "" then return nil, "RegistrarCapa: falta nombre" end
	local e = porId[spec.id]
	if e and e.tipo ~= "modulo" then return nil, "RegistrarCapa: id ocupado: " .. spec.id end
	local nuevo = not e
	if nuevo then
		e = { id = spec.id, tipo = "modulo", llave = llave(spec.id) }
		porId[spec.id] = e
		lista[#lista + 1] = e
	end
	e.nombre = spec.nombre
	e.ayuda = type(spec.ayuda) == "string" and spec.ayuda or (type(spec.descripcion) == "string" and spec.descripcion or nil)
	e.icono = (type(spec.icono) == "string" or type(spec.icono) == "number") and spec.icono or nil
	e.color = type(spec.color) == "string" and spec.color or nil
	e.esencial = spec.esencial == true
	e.orden = tonumber(spec.orden)
	e.alCambiar = type(spec.alCambiar) == "function" and spec.alCambiar or nil
	e.pines = type(spec.pines) == "string" and spec.pines or nil
	e.zoom = tonumber(spec.zoom)
	-- El estado de fábrica es el de la primera vez que se registró: muchos
	-- módulos pasan en `activa` su propio ajuste, que es copia del de aquí
	-- (alCambiar), y si cambiara el valor por omisión cambiaría lo guardado.
	local datos = N.Datos(ID)
	if type(datos.fabrica) ~= "table" then datos.fabrica = {} end
	if datos.fabrica[e.llave] == nil then datos.fabrica[e.llave] = spec.activa ~= false end
	porOmision[e.llave] = datos.fabrica[e.llave] ~= false
	Capas.version = Capas.version + 1
	if nuevo then
		local nombreGrupo = type(spec.grupo) == "string" and spec.grupo ~= "" and spec.grupo or L["Otros"]
		agregar(ALIAS[nombreGrupo:lower()] or grupo(nombreGrupo), e)
		-- Llega en pleno modo limpio por primera vez: también se oculta.
		if limpio() and not e.esencial and Capas.Valor(e) then
			local sup = A.Get(ID .. ".suprimidas")
			if not (type(sup) == "table" and sup[e.id] ~= nil) then marcarSuprimida(e.id, true) end
		end
	end
	-- La primera vez el módulo oye su estado guardado, en el siguiente cuadro.
	reportado[e.id] = nil
	avisar()
	return e.id
end

---------------------------------------------------------------------------
-- Cualquier ajuste de una capa que cambie fuera de aquí (la página Mapa,
-- el menú del mapa del juego, /alfa reset) repinta los controles.
---------------------------------------------------------------------------

A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" then return end
	-- Las zonas sin descubrir recuerdan su último modo encendido ("on" o "tint").
	local e = porRuta[path]
	if e and e.leer then
		local v = A.Get(path)
		if e.leer(v) then e.ultimo = v end
	end
	if path == "" or porRuta[path] or path:sub(1, #ID + 1) == ID .. "." or path == ID
		or path == "maps" or path == "nav" or path == "qol" or path == "rares"
		or path == "qol.questDB" or path == "rares.enabled" then
		avisar()
	end
end)

---------------------------------------------------------------------------
-- AlfaMundo: lo que otros módulos usan (LEEME.md, "Contrato de capas").
-- Si un módulo cargó antes que Mundo y dejó sus capas en
-- AlfaMundo.pendientes = { spec, ... }, se registran ahora.
---------------------------------------------------------------------------

local API = type(AlfaMundo) == "table" and AlfaMundo or {}
AlfaMundo = API
local pendientes = rawget(API, "pendientes")
API.pendientes = nil
API.version = 1

-- -> id | nil, error (el error se devuelve: nunca salta una ventana de
-- error al jugador por un registro mal hecho; con /alfa debug se anota)
function API.RegistrarCapa(spec)
	local id, err = Capas.Registrar(spec)
	if not id and type(A.Debug) == "function" then A.Debug(err) end
	return id, err
end

-- El estado que manda (el modo limpio incluido). Una capa que no existe: false.
function API.CapaActiva(id)
	local e = porId[id]
	return e and Capas.Activa(e) or false
end

-- Desde otro módulo: pedir el estado que ya manda no cambia nada. Así un
-- módulo que copia en su ajuste lo que oyó en alCambiar y lo devuelve no
-- convierte el modo limpio en una decisión tuya.
function API.ActivarCapa(id, on)
	local e = porId[id]
	if not e then return false end
	on = on and true or false
	if Capas.Activa(e) == on then return true end
	return Capas.Poner(e, on)
end
API.PonerCapa = API.ActivarCapa
function API.ModoLimpio() return limpio() end
function API.PonerModoLimpio(on) Capas.PonerLimpio(on) end

-- Una copia de la lista: { { id, grupo, nombre, activa, esencial }, ... }
function API.Capas()
	local out = {}
	for _, g in ipairs(Capas.Grupos()) do
		for _, e in ipairs(g.capas) do
			out[#out + 1] = { id = e.id, grupo = g.nombre, nombre = e.nombre, activa = Capas.Activa(e), esencial = e.esencial and true or false }
		end
	end
	return out
end

if type(pendientes) == "table" then
	for _, spec in ipairs(pendientes) do API.RegistrarCapa(spec) end
end
