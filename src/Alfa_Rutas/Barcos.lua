-- Alfa - Rutas: barcos y zepelines en el mapa, con su cuenta atrás
-- (toxic3000 / La Jauría). GPL-3.0.
-- 1.3.0
--
-- Cada muelle y torre de zepelines de tu facción (o neutral) lleva un pin en
-- el mapa del mundo con cuánto falta para que llegue («1:20») y, al pasar el
-- ratón, a dónde va y cuándo sale. Los horarios son los del motor
-- (Nav/Transit.lua: el aviso de barcos lee lo mismo): un barco que alguien
-- ya tomó tiene la hora exacta; si no, «espera de unos 3 min» (sin cuenta
-- atrás, porque nadie lo ha medido). Los muelles salen de los datos de viaje
-- (Nav.GetTravelData().transports). Mientras el mapa está abierto la cuenta
-- se pone al día cada segundo; cerrado, nada corre. Ajuste rutas.horarios.
--
-- 1.3.1: el segundo lo da el reloj de Alfa (N.Cada "rutas.barcos", fuera de
-- combate), que empieza al abrir el mapa y se quita al cerrarlo. Y la capa
-- solo se publica si cambió lo que dice (su firma: cada muelle, su cuenta y
-- su texto): sin horario medido, el texto no cambia y antes se redibujaban
-- el mapa entero y el minimapa cada segundo.
--
--   Barcos.Lista() -> { { id, tipo, lado, desde, hasta, texto, segundos, map, x, y, f } }
--   Barcos.Pines([lista]) -> los pines de la capa
--   Barcos.Pintar()

local ADDON, M = ...
local A, L, K, N = M.A, M.L, M.K, M.N
local Bc = {}
M.Barcos = Bc

A.RegisterDefaults(M.ID, { horarios = true })

local CAPA = "rutas.barcos"
local RELOJ = "rutas.barcos"
local type, ipairs, tostring, pcall = type, ipairs, tostring, pcall
local format, floor, ceil, max, concat = string.format, math.floor, math.ceil, math.max, table.concat

local function encendido() return A.Get(M.ID .. ".horarios") ~= false end
local function TR() return M.Motor("Transit") end

local function faccion()
	local f = UnitFactionGroup and UnitFactionGroup("player")
	if f == "Alliance" then return 1 elseif f == "Horde" then return 2 end
	return 3
end

local function mia(m)
	local f = faccion()
	return not m or m == 3 or f == 3 or m == f
end

local function cuenta(seg)
	seg = max(0, ceil(seg))
	return N.Duracion(seg) -- 1.3.7: como en todo Alfa («4 min 10 s», 101)
end
Bc.Cuenta = cuenta

local function nombre(p)
	local T = A.Nav and A.Nav.travel
	return (T and T.PlaceName and T.PlaceName(p)) or (p and p.name) or "?"
end

-- 1.3.4: sin tablas ni funciones nuevas que no hagan falta (corre cada
-- segundo con el mapa abierto).
local function agregar(out, t, lado, e, otro, X, ahora)
	if not (e and e.map and e.x and e.y) then return end
	local llega, sale, texto
	if X and X.NextArrival then
		local okA, a, s = pcall(X.NextArrival, t.kind, t.id, ahora, lado)
		if okA then llega, sale = a, s end
	end
	local hasta = nombre(otro)
	if llega then
		if llega <= 0 then texto = format(L["En el muelle: sale en %s hacia %s"], cuenta(sale or 0), hasta)
		else texto = format(L["Llega en %s; va a %s"], cuenta(llega), hasta) end
	else
		local espera
		if X and X.NextDeparture then
			local okD, v = pcall(X.NextDeparture, t.kind, t.id, ahora, lado)
			espera = okD and v or nil
		end
		texto = espera and format(L["Espera de unos %s; va a %s"], N.Duracion(espera, true), hasta)
			or format(L["Va a %s"], hasta)
	end
	out[#out + 1] = { id = t.id, tipo = t.kind, lado = lado, desde = nombre(e), hasta = hasta, texto = texto,
		segundos = llega, sale = sale, map = e.map, x = e.x, y = e.y, f = e.f }
end

function Bc.Lista()
	local Nav, X = A.Nav, TR()
	if not (Nav and Nav.GetTravelData) then return {} end
	local ok, d = pcall(Nav.GetTravelData)
	if not (ok and type(d) == "table") then return {} end
	local ahora = X and X.Now and X.Now() or 0
	local out = {}
	for _, t in ipairs(d.transports or {}) do
		if (t.kind == "boat" or t.kind == "zeppelin") and mia(t.faction) then
			agregar(out, t, "a", t.a, t.b, X, ahora)
			agregar(out, t, "b", t.b, t.a, X, ahora)
		end
	end
	return out
end

local function rgb(nombre)
	local r, g, b = K.Color(nombre)
	return { r, g, b, 1 }
end

-- 1.3.2: la insignia en minutos («4 min») mientras falte más de un minuto y
-- «m:ss» solo en el último: así el mapa no se redibuja cada segundo. El
-- texto exacto sale en el cuadro del ratón, leído al pasarlo.
local function insignia(seg)
	if not seg then return nil end
	if seg <= 0 then return L["¡Ya!"] end
	if seg <= 60 then return cuenta(seg) end
	return N.Duracion(ceil(seg / 60) * 60, true)
end
Bc.Insignia = insignia

-- El texto de ahora de un muelle (para el cuadro del ratón).
function Bc.TextoDe(id, lado)
	for _, h in ipairs(Bc.Lista()) do
		if h.id == id and h.lado == lado then return h.texto end
	end
	return nil
end

local function tonoDe(h) return h.segundos and h.segundos <= 60 and "exito" or "acento" end

-- 1.3.1: lo que dice un muelle (Bc.Pintar solo publica si cambia).
-- (1.3.2: con cuenta atrás el texto cambia cada segundo: no entra en la firma)
local partesFirma = {}
local function firmaDeMuelle(h)
	partesFirma[1], partesFirma[2], partesFirma[3] = tostring(h.id), h.lado, tonoDe(h)
	partesFirma[4], partesFirma[5] = insignia(h.segundos) or "", h.segundos and "" or (h.texto or "")
	partesFirma[6], partesFirma[7], partesFirma[8] = tostring(h.map), tostring(h.x), tostring(h.y)
	return concat(partesFirma, "|")
end

function Bc.Pines(lista)
	local out = {}
	for _, h in ipairs(lista or Bc.Lista()) do
		local titulo = format(h.tipo == "zeppelin" and L["Zepelín de %s"] or L["Barco de %s"], h.desde)
		out[#out + 1] = {
			map = h.map, x = h.x, y = h.y, f = h.f,
			icon = h.tipo == "zeppelin" and "map:zeppelin" or "map:boat", size = 15, priority = 2,
			color = rgb(tonoDe(h)),
			badge = insignia(h.segundos),
			alfaFirma = firmaDeMuelle(h),
			tooltip = function(tip)
				tip:SetText(titulo, K.Color("texto"))
				tip:AddLine(Bc.TextoDe(h.id, h.lado) or h.texto, K.Color("acento"))
				tip:AddLine(L["Clic: la flecha te lleva al muelle."], K.Color("textoTenue"))
			end,
			onClick = function(boton)
				if boton ~= "LeftButton" then return end
				if M.Viaje then M.Viaje.Ir({ nombre = titulo, map = h.map, x = h.x, y = h.y, f = h.f }) end
			end,
		}
	end
	return out
end

local firma -- 1.3.1: lo último publicado (nil: la capa está vacía)

-- 1.3.4: la firma sale de la lista, sin armar los pines (sus funciones y
-- colores) cada segundo; los pines se arman solo cuando la firma cambia.
local function firmaDe(lista)
	local partes = {}
	for i, h in ipairs(lista) do partes[i] = firmaDeMuelle(h) end
	return concat(partes, ";")
end

-- Sin mapa (o apagado): la capa vacía y el reloj quieto.
local function quitar(P)
	N.Quitar(RELOJ)
	firma = nil
	if P and P.ClearLayer then P.ClearLayer(CAPA) end
end

function Bc.Pintar()
	local P = A.Pins
	if not (P and P.SetLayer and P.ClearLayer) then return end
	local mapa = rawget(_G, "WorldMapFrame")
	if not encendido() or not (mapa and mapa:IsShown()) then
		quitar(P)
		return
	end
	-- Con el mapa abierto, una vez por segundo (en combate espera).
	if not N.HayTarea(RELOJ) then N.Cada(RELOJ, 1, function() Bc.Pintar() end, { fueraDeCombate = true }) end
	local lista = Bc.Lista()
	local nueva = firmaDe(lista)
	if nueva == firma then return end
	firma = nueva
	local pines = Bc.Pines(lista)
	if #pines > 0 then P.SetLayer(CAPA, pines, { world = true, minimap = false, edge = false }) else P.ClearLayer(CAPA) end
end

-- El mapa del juego dice cuándo se abre y se cierra.
local vigilado = false
local function vigilar()
	local mapa = rawget(_G, "WorldMapFrame")
	if not mapa or vigilado then return end
	vigilado = true
	mapa:HookScript("OnShow", function() Bc.Pintar() end)
	mapa:HookScript("OnHide", function() quitar(A.Pins) end)
	if mapa:IsShown() then Bc.Pintar() end
end

A.OnLogin(function()
	vigilar()
	local Mu = rawget(_G, "AlfaMundo")
	if type(Mu) == "table" and type(Mu.RegistrarCapa) == "function" then
		pcall(Mu.RegistrarCapa, { id = CAPA, grupo = L["Viajes"], nombre = L["Barcos y zepelines"],
			ayuda = L["Cada muelle con cuánto falta para que llegue."], color = "acento", activa = encendido(),
			alCambiar = function(on) A.Set(M.ID .. ".horarios", on and true or false) Bc.Pintar() end })
	end
end)
