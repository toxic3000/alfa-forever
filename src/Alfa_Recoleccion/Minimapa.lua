-- Alfa - Recolección: los nodos en el minimapa (toxic3000 / La Jauría, GPL-3.0).
--
-- La geometría es la del motor (Alfa.Pins.MinimapView y Alfa.Pins.Project:
-- radio a la vista, giro con el jugador, minimapa redondo o cuadrado). Lo
-- que cuesta se hace poco:
--   * la búsqueda de nodos cercanos (R.Cercanos, por cuadrícula) solo
--     cuando te alejas un cuarto del alcance, cambia el zoom o cambian los
--     nodos o los filtros;
--   * mientras te mueves o giras se reubican los pines 30 veces por segundo
--     como mucho, y tras 0.4 s quieto el motor se duerme; moverte, girar,
--     el zoom o un cambio de zona lo despiertan (y un vigía cada 0.5 s).

local _, M = ...
local N = AlfaNucleo
local A = N.A
local R, P = M.R, M.P
local L = N.Textos(M.EN)

local abs = math.abs
local ID = R.ID

local Mini = {}
M.Mini = Mini

local TAM = 13
local FLECHA = 9          -- px: el disco de la flecha del jugador en el centro
local INTERVALO = 1 / 30
local DORMIR = 0.4

local pool = {}
local usados = 0
local cand = { n = 0, idx = {}, i = {}, wx = {}, wy = {} }
local consulta = { version = -1 }
local ultimo = {}
local motor, vigia
local quieto, acumulado = 0, 0

local function activo()
	if N.Get(ID, "minimapa") == false or A.Hidden() then return false end
	if R.AlgunoVisible and not R.AlgunoVisible() then return false end
	if not Minimap or not Minimap:IsVisible() then return false end
	return not R.EnInstancia()
end

local function alEntrar(self)
	if not self.psIdx then return end
	P.Info(self, self.psIdx, self.psI, L["Lugar conocido: el punto del rastreo del juego dice si ahora hay algo."], "ANCHOR_LEFT")
end

local function alSalir(self)
	if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end

local function pin(k)
	local f = pool[k]
	if f then return f end
	f = A.CreateFrameUnder("Frame", nil, Minimap)
	P.Construir(f)
	f:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 4)
	f:EnableMouse(true)
	f:SetScript("OnEnter", alEntrar)
	f:SetScript("OnLeave", alSalir)
	pool[k] = f
	return f
end

local function ocultarDesde(k)
	for j = k, usados do
		local f = pool[j]
		if f then
			f:Hide()
			f.psIdx, f.psI = nil, nil
		end
	end
	if k <= usados then usados = k - 1 end
end

local function ocultarTodo()
	ocultarDesde(1)
	ultimo.c = nil
end

-- Reubica los pines si algo cambió. -> true si dibujó
local function dibujar(forzar)
	if not activo() then
		if usados > 0 then ocultarTodo() end
		return false
	end
	local C = A.Compat
	local c, px, py = C.GetPlayerWorldPosition()
	if not c then
		if usados > 0 then ocultarTodo() end
		return false
	end
	local radio, giro, cuadrado = A.Pins.MinimapView()
	local mitad = Minimap:GetWidth() / 2
	local tam = TAM * (tonumber(N.Get(ID, "tamanoMinimapa")) or 1)
	local u = ultimo
	if not forzar and u.c == c and u.x == px and u.y == py and u.giro == giro and u.radio == radio
		and u.mitad == mitad and u.cuadrado == cuadrado and u.tam == tam and u.version == consulta.version
		and consulta.version == R.versionNodos then
		return false
	end
	-- ¿Hace falta buscar otra vez?
	local alcance = radio * (cuadrado and 1.42 or 1) + 20
	local q = consulta
	if q.version ~= R.versionNodos or q.c ~= c or abs(px - q.x) + abs(py - q.y) > alcance * 0.25
		or alcance > q.alcance or alcance < q.alcance * 0.6 then
		q.alcance = alcance
		q.c, q.x, q.y, q.version = c, px, py, R.versionNodos
		R.Cercanos(c, px, py, alcance * 1.3, cand)
	end
	u.c, u.x, u.y, u.giro, u.radio, u.mitad, u.cuadrado, u.tam, u.version = c, px, py, giro, radio, mitad, cuadrado, tam, q.version
	local limite = mitad - tam * 0.45
	local limite2 = limite * limite
	local Project = A.Pins.Project
	local k = 0
	for j = 1, cand.n do
		local x, y = Project(cand.wx[j] - px, cand.wy[j] - py, giro, radio, mitad, giro ~= nil, cuadrado, nil)
		local dentro
		if cuadrado then dentro = abs(x) <= limite and abs(y) <= limite else dentro = x * x + y * y <= limite2 end
		if dentro then
			k = k + 1
			local f = pin(k)
			local idx, i = cand.idx[j], cand.i[j]
			f.psIdx, f.psI = idx, i
			local g = idx.g[i]
			local tenue = not R.Puede(g)
			P.Aplicar(f, g, tam, tenue, nil)
			-- El juego dibuja tu flecha bajo todo lo del minimapa: lo que la tapa se aclara.
			local r = FLECHA + tam * 0.5
			f:SetAlpha((tenue and 0.6 or 1) * ((x * x + y * y < r * r) and 0.35 or 1))
			f:ClearAllPoints()
			f:SetPoint("CENTER", Minimap, "CENTER", x, y)
			if not f:IsShown() then f:Show() end
		end
	end
	if k > usados then usados = k end
	ocultarDesde(k + 1)
	return true
end

local function despertar()
	if motor and not motor:IsShown() then
		quieto, acumulado = 0, 0
		motor:Show()
	end
end
Mini.Despertar = despertar

function Mini.Instalar()
	if motor or not Minimap then return end
	R.versionNodos = R.versionNodos or 0
	-- El motor cuelga de la capa de Alfa: si Alfa se oculta, se detiene solo.
	motor = CreateFrame("Frame", nil, A.UIParent)
	motor:Hide()
	motor:SetScript("OnUpdate", A.Safe(function(self, elapsed)
		acumulado = acumulado + elapsed
		if acumulado < INTERVALO then return end
		local paso = acumulado
		acumulado = 0
		if dibujar(false) then
			quieto = 0
		else
			quieto = quieto + paso
			if quieto >= DORMIR then self:Hide() end
		end
	end))
	Mini.Vigia()
	for _, evento in ipairs({
		"PLAYER_STARTED_MOVING", "PLAYER_STARTED_TURNING", "MINIMAP_UPDATE_ZOOM", "CVAR_UPDATE",
		"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",
	}) do
		A.RegisterEvent(evento, despertar)
	end
	dibujar(true)
end

-- El vigía (cada medio segundo mira si hay que despertar) solo corre con el
-- minimapa de Recolección encendido: apagado, no gasta nada. 1.1.8.
function Mini.Vigia()
	local on = N.Get(ID, "minimapa") ~= false
	if on and not vigia then
		vigia = N.Ticker("recoleccion.minimapa", 0.5, function()
			if dibujar(false) then despertar() end
		end)
	elseif not on and vigia then
		vigia:Cancel()
		vigia = nil
	end
end

function Mini.Refrescar()
	R.versionNodos = (R.versionNodos or 0) + 1
	if motor then
		dibujar(true)
		despertar()
	end
end

R.AlCambiar(function(que)
	if que == "nodos" or que == "filtros" then Mini.Refrescar() end
end)

local PROPIOS = { ["recoleccion.minimapa"] = true, ["recoleccion.tamanoMinimapa"] = true }
A.On("SETTING_CHANGED", function(path)
	if PROPIOS[path] or path == "" or path == ID then
		if motor then Mini.Vigia() end
		Mini.Refrescar()
	end
end)

A.On("ALFA_HIDDEN", function(oculto)
	if oculto then ocultarTodo() else Mini.Refrescar() end
end)
