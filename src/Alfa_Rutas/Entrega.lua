-- Alfa - Rutas: el PNJ de la entrega, marcado en el minimapa (toxic3000 / La
-- Jauría). GPL-3.0. 1.4.0 (29)
--
-- Cuando tu paso de ahora es entregar una misión y ya estás cerca de quien la
-- recibe (unas 120 yardas), el minimapa lo marca con el signo de entrega
-- dentro de su medallón, un aro y su nombre al pasar el ratón: en un pueblo
-- lleno de gente se ve al momento a quién hablarle. Al entregarla, al
-- alejarte o al cambiar de paso, la marca se va sola.
--
-- Sale de la vista del paso del motor (la meta de entrega trae su mapa y su
-- lugar). Se revisa cada segundo, solo mientras una entrega es la meta de
-- ahora (con la guía parada no corre nada) y nunca dentro de una instancia.
-- Ajuste rutas.entregaMinimapa (de fábrica, sí).
--
--   Entrega.Meta() -> la meta de entrega de ahora (vista del motor) | nil
--   Entrega.Revisar() -> true si la marca está puesta
--   Entrega.Pin() -> el pin puesto | nil (para el banco)

local ADDON, M = ...
local A, L, N, K = M.A, M.L, M.N, M.K
local En = {}
M.Entrega = En

A.RegisterDefaults(M.ID, { entregaMinimapa = true })

local type, ipairs, pcall, tostring, sqrt, format = type, ipairs, pcall, tostring, math.sqrt, string.format

local CAPA = "rutas.entrega"
local CERCA = 120 -- yardas
local SALIR = 150 -- yardas: se quita más lejos (sin parpadeo en el borde)
local CADA = 1

local function E() return A.Engine end
local function CP() return M.Motor("Compat") end
local function encendido() return A.Get(M.ID .. ".entregaMinimapa") ~= false and not (A.Hidden and A.Hidden()) end

local function enInstancia()
	if not IsInInstance then return false end
	local ok, dentro = pcall(IsInInstance)
	return ok and N.Si(dentro) or false
end

function En.Meta()
	local e = E()
	if not (e and e.GetLiveStep and e.GetStepView) then return nil end
	local vivo = e.GetLiveStep()
	local v = vivo and e.GetStepView(vivo)
	if type(v) ~= "table" or not v.current then return nil end
	local g = v.goals and v.goals[v.current]
	if type(g) ~= "table" or g.t ~= "turnin" or not (g.map and g.x and g.y) then return nil end
	if g.status == "done" or g.status == "skipped" or g.status == "na" then return nil end
	return g, v
end

-- Yardas de ti a la meta (en el mismo continente). -> yardas | nil
local function distancia(g)
	local Cp = CP()
	if not (Cp and Cp.MapToWorld and Cp.GetPlayerWorldPosition) then return nil end
	local ok, c, wx, wy = pcall(Cp.MapToWorld, g.map, g.x, g.y, g.f)
	if not (ok and c and type(wx) == "number") then return nil end
	local ok2, c2, px, py = pcall(Cp.GetPlayerWorldPosition)
	if not ok2 then return nil end
	-- La posición puede llegar secreta (combate, mazmorras): sin leerla no se mide.
	c2, px, py = N.Leer(c2), N.Leer(px), N.Leer(py)
	if c2 ~= c or type(px) ~= "number" or type(py) ~= "number" then return nil end
	return sqrt((px - wx) ^ 2 + (py - wy) ^ 2)
end

local puesto -- { clave, pin }

local function quitar()
	if not puesto then return end
	puesto = nil
	local P = A.Pins
	if P and P.ClearLayer then pcall(P.ClearLayer, CAPA) end
end

local function nombreDe(g, v)
	for _, gr in ipairs(type(v.groups) == "table" and v.groups or {}) do
		for _, i in ipairs(gr.goals or {}) do
			if i == v.current and type(gr.name) == "string" and gr.name ~= "" then return gr.name end
		end
	end
	if type(g.npcName) == "string" and g.npcName ~= "" then return g.npcName end
	return nil
end

local function poner(g, v)
	local clave = tostring(g.quest) .. ":" .. tostring(g.map) .. ":" .. tostring(g.x) .. ":" .. tostring(g.y)
	if puesto and puesto.clave == clave then return true end
	local P = A.Pins
	if not (P and P.SetLayer) then return false end
	local r, gg, b = K.Color("acento")
	local quien = nombreDe(g, v)
	local mision = (type(g.title) == "string" and g.title ~= "") and g.title or (g.quest and M.TituloMision(g.quest)) or ""
	local pin = { map = g.map, x = g.x, y = g.y, f = g.f, icon = "map:quest-turnin", size = 18, minimapSize = 20,
		color = { r or 1, gg or 0.8, b or 0.2, 1 }, ring = { r or 1, gg or 0.8, b or 0.2, 0.8 }, glow = true, state = "focus", priority = 5,
		tooltip = function(tip)
			tip:SetText(quien or L["Entrega aquí"], K.Color("texto"))
			if mision ~= "" then tip:AddLine(format(L["Entrégale: %s"], mision), K.Color("acento")) end
			tip:AddLine(L["Alfa lo marca porque ya estás cerca."], K.Color("textoSuave"))
		end }
	local ok = pcall(P.SetLayer, CAPA, { pin }, { world = false, minimap = true, edge = false })
	if ok then puesto = { clave = clave, pin = pin, quien = quien } end
	return ok
end

function En.Revisar()
	if not encendido() or enInstancia() then quitar() return false end
	local g, v = En.Meta()
	if not g then quitar() return false end
	local d = distancia(g)
	if not d then return puesto ~= nil end -- sin medida (secreta): se queda como estaba
	local tope = puesto and SALIR or CERCA
	if d > tope then quitar() return false end
	return poner(g, v)
end

function En.Pin() return puesto and puesto.pin or nil, puesto and puesto.quien or nil end

-- El reloj corre solo mientras la meta de ahora es una entrega.
local corriendo = false
local function vigilar()
	local quiere = encendido() and En.Meta() ~= nil
	if quiere and not corriendo then
		corriendo = true
		N.Cada("rutas.entrega", CADA, function() En.Revisar() end)
	elseif not quiere and corriendo then
		corriendo = false
		N.Quitar("rutas.entrega")
	end
	En.Revisar()
end
En.Vigilar = vigilar

for _, msg in ipairs({ "GUIDE_CHANGED", "STEP_CHANGED", "STEP_UPDATED", "STEP_SKIPPED" }) do
	A.On(msg, function() N.Una("rutas.entregaVer", 0.2, vigilar) end)
end
A.RegisterEvent("QUEST_TURNED_IN", function() N.Una("rutas.entregaVer", 0.5, vigilar) end)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() N.Una("rutas.entregaVer", 1, vigilar) end)
A.On("SETTING_CHANGED", function(ruta)
	if ruta == M.ID .. ".entregaMinimapa" or ruta == "" then quitar() vigilar() end
end)
