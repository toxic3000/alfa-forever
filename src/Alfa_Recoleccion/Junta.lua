-- Alfa - Recolección: los pasos de guía que piden juntar un mineral o una
-- hierba (toxic3000 / La Jauría, GPL-3.0). 1.4.0, plan 73 (Toxic: «buscando
-- Mena de estaño a nivel 33 en Los Humedales la flecha me mandaba a casi
-- 2,000 yardas»).
--
-- Un paso «Junta 20 de Mena de estaño» (de una guía de oficio de Alfa, de una
-- misión o de cualquier guía del motor) usaba el punto del motor: el lugar
-- que traía la guía, aunque hubiera vetas junto a ti. Ahora, cuando la
-- flecha va a juntar algo que sale de un nodo (Llevar.GruposDe), Alfa arma su
-- ruta: la zona más cercana a ti que sea de tu nivel y tenga ese nodo
-- (Llevar.Zonas, con la distancia) y un circuito corto por las paradas más
-- cercanas (Ruta.Crear con `cerca`), empezando por la más cercana. Al cambiar
-- de paso la flecha vuelve a la guía sola (el motor suelta lo puesto) y la
-- ruta se suelta sin decir nada (deGuia).
-- Una vez por paso; nunca en combate (espera a que termine); ajuste
-- recoleccion.juntaRuta (de fábrica, sí).
--   Ju.Revisar() ; Ju.MetaDeAhora() -> goal, stepIndex, goalIndex | nil

local _, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local ID = M.R.ID

local type, format = type, string.format

local Ju = {}
M.Junta = Ju

local hecha -- clave del paso que ya armó su ruta

local function Engine() return A.Engine end

-- La meta «juntar» a la que va la flecha del motor ahora (de un nodo).
function Ju.MetaDeAhora()
	local E = Engine()
	if not (E and E.GetGuide and E.GetWaypoint) then return nil end
	local g = E.GetGuide()
	local wp = E.GetWaypoint()
	if not (g and type(wp) == "table" and wp.kind == "collect" and wp.stepIndex and wp.goalIndex) then return nil end
	local paso = g.steps and g.steps[wp.stepIndex]
	local goal = paso and paso.goals and paso.goals[wp.goalIndex]
	if not (type(goal) == "table" and type(goal.item) == "number") then return nil end
	if #M.Llevar.GruposDe(goal.item) == 0 then return nil end
	return goal, wp.stepIndex, wp.goalIndex, g.id
end

local function clave(id, s, gi, item) return tostring(id) .. ":" .. tostring(s) .. ":" .. tostring(gi) .. ":" .. tostring(item) end

local function armar()
	if N.Get(ID, "juntaRuta") == false then return end
	local goal, s, gi, gid = Ju.MetaDeAhora()
	if not goal then return end
	local k = clave(gid, s, gi, goal.item)
	if hecha == k then return end
	-- Ya hay una ruta de Alfa guiando a ese mismo recurso: se deja.
	local r = M.Ruta.Actual()
	if r and r.guiando then return end
	hecha = k
	local cuenta = tonumber(goal.count) or nil
	local ok = M.Llevar.Llevar(goal.item, { cuenta = cuenta, silencio = true, deGuia = true, alListo = function(rt, z)
		Ju.ultima = { paso = k, mapa = z.mapa, n = rt.n, distancia = z.distancia }
		local K = N.Kit
		if K and K.Aviso then
			K.Aviso({ id = "recoleccion.junta", icono = "ic-flecha", tono = "acento", detalle = true, duracion = 6,
				titulo = format(L["Ruta corta en %s"], M.Llevar.NombreZona(z.mapa)),
				texto = format(L["%d paradas cerca de ti, empezando por la más cercana. Al terminar el paso, la flecha vuelve a tu guía."], rt.n) })
		end
	end })
	if not ok then Ju.ultima = { paso = k, fallo = true } end
end

-- Un momento después: al cambiar de paso, el motor suelta antes lo puesto (Nav).
function Ju.Revisar()
	if N.Una then N.Una("recoleccion.junta", 0.5, armar, { fueraDeCombate = true }) else armar() end
end
function Ju.Olvidar() hecha = nil end -- (para el banco)

if A.On then
	A.On("WAYPOINT_CHANGED", function() Ju.Revisar() end)
	A.On("STEP_CHANGED", function() hecha = nil Ju.Revisar() end)
end
