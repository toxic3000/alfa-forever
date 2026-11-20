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
--   Barcos.Lista() -> { { id, tipo, lado, desde, hasta, texto, segundos, map, x, y, f } }
--   Barcos.Pines() -> los pines de la capa
--   Barcos.Pintar()

local ADDON, M = ...
local A, L, K = M.A, M.L, M.K
local Bc = {}
M.Barcos = Bc

A.RegisterDefaults(M.ID, { horarios = true })

local CAPA = "rutas.barcos"
local type, ipairs, tostring, pcall = type, ipairs, tostring, pcall
local format, floor, ceil, max = string.format, math.floor, math.ceil, math.max

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
	return format("%d:%02d", floor(seg / 60), seg % 60)
end
Bc.Cuenta = cuenta

local function nombre(p)
	local T = A.Nav and A.Nav.travel
	return (T and T.PlaceName and T.PlaceName(p)) or (p and p.name) or "?"
end

function Bc.Lista()
	local Nav, X = A.Nav, TR()
	local ok, d = pcall(function() return Nav and Nav.GetTravelData and Nav.GetTravelData() end)
	if not (ok and type(d) == "table") then return {} end
	local ahora = X and X.Now and X.Now() or 0
	local out = {}
	for _, t in ipairs(d.transports or {}) do
		if (t.kind == "boat" or t.kind == "zeppelin") and mia(t.faction) then
			for _, par in ipairs({ { "a", t.a, t.b }, { "b", t.b, t.a } }) do
				local lado, e, otro = par[1], par[2], par[3]
				if e and e.map and e.x and e.y then
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
						local okD, espera = pcall(function() return X and X.NextDeparture and X.NextDeparture(t.kind, t.id, ahora, lado) end)
						espera = okD and espera or nil
						texto = espera and format(L["Espera de unos %d min; va a %s"], max(1, floor(espera / 60 + 0.5)), hasta)
							or format(L["Va a %s"], hasta)
					end
					out[#out + 1] = { id = t.id, tipo = t.kind, lado = lado, desde = nombre(e), hasta = hasta, texto = texto,
						segundos = llega, sale = sale, map = e.map, x = e.x, y = e.y, f = e.f }
				end
			end
		end
	end
	return out
end

local function rgb(nombre)
	local r, g, b = K.Color(nombre)
	return { r, g, b, 1 }
end

function Bc.Pines()
	local out = {}
	for _, h in ipairs(Bc.Lista()) do
		local titulo = format(h.tipo == "zeppelin" and L["Zepelín de %s"] or L["Barco de %s"], h.desde)
		out[#out + 1] = {
			map = h.map, x = h.x, y = h.y, f = h.f,
			icon = h.tipo == "zeppelin" and "map:zeppelin" or "map:boat", size = 15, priority = 2,
			color = rgb(h.segundos and h.segundos <= 60 and "exito" or "acento"),
			badge = h.segundos and (h.segundos <= 0 and L["¡Ya!"] or cuenta(h.segundos)) or nil,
			tooltip = function(tip)
				tip:SetText(titulo, K.Color("texto"))
				tip:AddLine(h.texto, K.Color("acento"))
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

function Bc.Pintar()
	local P = A.Pins
	if not (P and P.SetLayer and P.ClearLayer) then return end
	local mapa = rawget(_G, "WorldMapFrame")
	if not encendido() or not (mapa and mapa:IsShown()) then
		P.ClearLayer(CAPA)
		return
	end
	local pines = Bc.Pines()
	if #pines > 0 then P.SetLayer(CAPA, pines, { world = true, minimap = false, edge = false }) else P.ClearLayer(CAPA) end
end

-- Con el mapa abierto, una vez por segundo.
local reloj
local function vigilar()
	local mapa = rawget(_G, "WorldMapFrame")
	if not mapa or reloj then return end
	reloj = CreateFrame("Frame", nil, mapa)
	local cada = 0
	reloj:SetScript("OnUpdate", function(_, dt)
		cada = cada + (dt or 0)
		if cada < 1 then return end
		cada = 0
		if not (InCombatLockdown and InCombatLockdown()) then Bc.Pintar() end
	end)
	mapa:HookScript("OnShow", function() Bc.Pintar() end)
	mapa:HookScript("OnHide", function() local P = A.Pins if P and P.ClearLayer then P.ClearLayer(CAPA) end end)
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
