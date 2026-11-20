-- Alfa - Rutas: «Llévame a…», de donde estés a donde quieras (toxic3000 /
-- La Jauría). GPL-3.0.
-- 1.3.0
--
-- Una ventana con todos los lugares a los que se viaja: los pueblos con
-- maestro de vuelo, las posadas, los muelles de barcos y zepelines, las
-- estaciones del tranvía y los portales (de los datos de viaje del motor,
-- Nav.GetTravelData, solo los de tu facción o neutrales). 1.3.1: el tranvía
-- salía como «Muelle de Forjaz» y los portales no salían. Eliges uno y la flecha te lleva: el motor arma el
-- camino más rápido con vuelos, barcos, zepelines, portales, tu piedra de
-- hogar y a pie (Nav/Travel.lua) y Alfa te enseña la lista de tramos
-- («1. Vuela a Ventormenta · 3 min»). Ajuste rutas.llevame. Tecla
-- ALFA_RUTAS_LLEVAME y /alfa llevame [lugar].
--
--   Viaje.Destinos() -> { { nombre, zona, map, x, y, f, tipo, clave } }
--   Viaje.Buscar(texto) -> los que coinciden
--   Viaje.Ir(destino) -> ok, motivo   la flecha y el viaje
--   Viaje.Pasos() -> { { texto, segundos, tipo } } | nil   los tramos del viaje en curso
--   Viaje.Abrir()

local ADDON, M = ...
local A, L, K = M.A, M.L, M.K
local Vj = {}
M.Viaje = Vj

A.RegisterDefaults(M.ID, { llevame = true })

local type, ipairs, pairs, tostring = type, ipairs, pairs, tostring
local format, floor = string.format, math.floor

local function encendido() return A.Get(M.ID .. ".llevame") ~= false end

local function faccion()
	local f = UnitFactionGroup and UnitFactionGroup("player")
	if f == "Alliance" then return 1 elseif f == "Horde" then return 2 end
	return 3
end

local function mia(mascara)
	if not mascara or mascara == 0 then return true end
	local f = faccion()
	if f == 3 then return true end
	return (mascara == 3) or (mascara == f)
end

local ICONO = { vuelo = "ic-ruta", posada = "ic-hogar", muelle = "ic-huella", tranvia = "ic-ruta", portal = "ic-cerca" }

local cache
function Vj.Destinos()
	if cache and cache.f == faccion() then return cache.lista end
	local Nav = A.Nav
	local T = Nav and Nav.travel
	local ok, d = pcall(function() return Nav and Nav.GetTravelData and Nav.GetTravelData() end)
	local lista, visto = {}, {}
	local function agregar(p, nombre, tipo)
		if not (p and p.map and p.x and p.y and type(nombre) == "string" and nombre ~= "") then return end
		local clave = tipo .. ":" .. nombre
		if visto[clave] then return end
		visto[clave] = true
		local zona = M.Zona(p.map)
		lista[#lista + 1] = { nombre = nombre, zona = zona, map = p.map, x = p.x, y = p.y, f = p.f, tipo = tipo, clave = clave,
			plegado = M.Plegar(nombre .. " " .. (zona or "")) }
	end
	if ok and type(d) == "table" then
		for _, n in ipairs(d.taxi or {}) do
			if mia(n.faction) and not n.class then
				agregar(n, (T and T.TaxiName and T.TaxiName(n)) or n.name, "vuelo")
			end
		end
		for _, inn in ipairs(d.inns or {}) do
			agregar(inn, format(L["Posada de %s"], (T and T.PlaceName and T.PlaceName(inn)) or inn.name), "posada")
		end
		for _, t in ipairs(d.transports or {}) do
			if mia(t.faction) then
				for _, e in ipairs({ t.a, t.b }) do
					local lugar = (T and T.PlaceName and T.PlaceName(e)) or e.name
					-- 1.3.1: el tranvía (Ventormenta-Forjaz) no es un muelle.
					if t.kind == "tram" then
						agregar(e, format(L["Tranvía de %s"], tostring(lugar)), "tranvia")
					else
						agregar(e, format(t.kind == "zeppelin" and L["Torre de zepelines de %s"] or L["Muelle de %s"], tostring(lugar)), "muelle")
					end
				end
			end
		end
		-- 1.3.1: los portales (Darnassus-Rut'theran y los de Forever): la
		-- entrada de cada uno, con el lugar al que lleva.
		for _, t in ipairs(d.portals or {}) do
			if mia(t.faction) and type(t.a) == "table" and type(t.b) == "table" then
				local destino = (T and T.PlaceName and T.PlaceName(t.b)) or t.b.name or t.name
				agregar(t.a, format(L["Portal a %s"], tostring(destino)), "portal")
			end
		end
	end
	table.sort(lista, function(a, b) return a.plegado < b.plegado end)
	cache = { f = faccion(), lista = lista }
	return lista
end

function Vj.Buscar(texto)
	local q = M.Plegar(texto or "")
	local out = {}
	for _, d in ipairs(Vj.Destinos()) do
		if q == "" or d.plegado:find(q, 1, true) then out[#out + 1] = d end
	end
	return out
end

local viaje -- { destino, objetivo }

function Vj.Ir(d)
	if not encendido() then return false, "apagado" end
	local Nav = A.Nav
	if not (type(d) == "table" and d.map and d.x and d.y and Nav and type(Nav.SetTarget) == "function") then return false, "dato" end
	local nombre = d.nombre or L["Tu destino"]
	local ok, t = pcall(Nav.SetTarget, d.map, d.x, d.y, nombre, d.f)
	if not (ok and t) then return false, "flecha" end
	if type(Nav.StartTrip) == "function" then pcall(Nav.StartTrip, t, nombre, L["Llévame a..."]) end
	viaje = { destino = d, objetivo = t }
	M.Empezar()
	M.Aviso(L["Llévame a..."], format(L["Vamos a %s: sigue la flecha."], nombre), { icono = "ic-huella" })
	return true
end

-- El viaje sigue mientras la flecha apunte a su destino.
local function vivo()
	if not viaje then return false end
	local Nav = A.Nav
	local ok, t = pcall(function() return Nav and Nav.GetTarget and Nav.GetTarget() end)
	if ok and t == viaje.objetivo then return true end
	viaje = nil
	return false
end

local TIPO = { walk = "pie", fly = "vuelo", taxi = "vuelo", boat = "barco", zeppelin = "zepelin", tram = "tranvia",
	portal = "portal", hearth = "hogar", teleport = "hechizo", lift = "elevador" }

function Vj.Pasos()
	if not vivo() then return nil end
	local Nav = A.Nav
	local ok, legs, ci = pcall(function() return Nav.GetRoute() end)
	if not ok or type(legs) ~= "table" then return {} end
	local out = {}
	for i = ci or 1, #legs do
		local leg = legs[i]
		local texto = type(leg.label) == "string" and leg.label ~= "" and leg.label or L["Camina"]
		if issecretvalue and issecretvalue(texto) then texto = L["Camina"] end
		out[#out + 1] = { texto = texto, segundos = M.num(leg.seconds, 0), tipo = TIPO[leg.kind] or "pie", actual = i == ci }
	end
	return out
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------

local ventana
local buscado = ""

local function llenar()
	if not (ventana and ventana:IsShown()) then return end
	local pasos = buscado == "" and Vj.Pasos() or nil
	if pasos and #pasos > 0 then
		local total = 0
		for _, p in ipairs(pasos) do total = total + p.segundos end
		ventana.modo = "pasos"
		ventana:Llenar(pasos, L["Llévame a..."], viaje.destino.nombre,
			format(L["Tu camino: %d tramos, %s. Escribe arriba para ir a otro lugar."], #pasos, M.Minutos(total)))
		return
	end
	ventana.modo = "destinos"
	local lista = Vj.Buscar(buscado)
	ventana:Llenar(lista, L["Llévame a..."], format(L["%d lugares"], #lista),
		L["Elige a dónde ir: Alfa arma el camino con vuelos, barcos, zepelines, portales y a pie."])
end
Vj.Refrescar = llenar

local function armar()
	ventana = M.VentanaSimple({
		nombre = "AlfaRutasLlevame", titulo = L["Llévame a..."], icono = "ic-huella", ancho = 440, alto = 520,
		buscador = { ayuda = L["Buscar un lugar..."], alCambiar = function(t) buscado = t or "" llenar() end },
		vacio = { lobo = "atento", titulo = L["No encontré ese lugar"], texto = L["Prueba con el nombre del pueblo o de la zona."] },
		crear = function(fila)
			fila.Icono = K.Icono(fila, "ic-ruta", 14, "acento")
			fila.Icono:SetPoint("LEFT", fila, "LEFT", 10, 0)
			fila.Texto = K.Texto(fila, "cuerpo", "texto")
			fila.Texto:SetPoint("LEFT", fila, "LEFT", 32, 0)
			fila.Extra = K.Texto(fila, "pequeno", "textoTenue")
			fila.Extra:SetPoint("RIGHT", fila, "RIGHT", -10, 0)
			fila.Extra:SetJustifyH("RIGHT")
			fila.Texto:SetPoint("RIGHT", fila.Extra, "LEFT", -8, 0)
		end,
		pintar = function(fila, d, i)
			if ventana.modo == "pasos" then
				K.SetIcono(fila.Icono, d.actual and "ic-seguir" or "ic-huella", d.actual and "acento" or "textoTenue")
				K.Escribir(fila.Texto, format(L["%d. %s"], i, d.texto))
				K.Escribir(fila.Extra, d.segundos > 0 and M.Minutos(d.segundos) or "")
				K.ColorTexto(fila.Texto, d.actual and "acento" or "texto")
			else
				K.SetIcono(fila.Icono, ICONO[d.tipo] or "ic-ruta", "acento")
				K.Escribir(fila.Texto, d.nombre)
				K.Escribir(fila.Extra, d.zona or "")
				K.ColorTexto(fila.Texto, "texto")
			end
		end,
		alClic = function(d)
			if ventana.modo ~= "destinos" then return end
			if Vj.Ir(d) then
				buscado = ""
				if ventana.Buscador and ventana.Buscador.SetTexto then ventana.Buscador:SetTexto("") end
				A.After(0.5, llenar)
			end
		end,
	})
end

function Vj.Abrir()
	if not encendido() then return false end
	if not ventana then armar() end
	ventana:Abrir()
	llenar()
	return true
end

A.On("ROUTE_CHANGED", function() if ventana and ventana:IsShown() and ventana.modo ~= "destinos" then A.After(0.1, llenar) end end)

BINDING_NAME_ALFA_RUTAS_LLEVAME = L["Llévame a... (el camino a cualquier lugar)"]

A.RegisterCommand("llevame", function(resto)
	local texto = type(resto) == "string" and resto:match("^%s*(.-)%s*$") or ""
	if texto ~= "" then
		local l = Vj.Buscar(texto)
		if #l == 1 then return Vj.Ir(l[1]) end
		buscado = texto
	end
	Vj.Abrir()
	if texto ~= "" and ventana and ventana.Buscador and ventana.Buscador.SetTexto then ventana.Buscador:SetTexto(texto) end
end)
