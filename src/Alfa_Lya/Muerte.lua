-- Alfa - Lya: cuando caes (1.2.9). toxic3000 / La Jauría. GPL-3.0.
--
--   Ya como espíritu (al liberar), Lya te dice qué conviene: correr por tu
--   cuerpo o revivir con el ángel. Lo cuenta con números: a cuánto está tu
--   cuerpo y cuánto tardas, lo que cuesta el ángel (25 % de durabilidad en
--   todo tu equipo y la debilidad de resurrección a tu nivel) y cómo va ya tu
--   equipo. Una vez por caída; siempre fuera de combate (un espíritu no pelea).
--
--   La flecha: con «Cuerpo o ángel» del motor encendido (qol.deathHelper), el
--   motor ya la apunta y la sostiene a lo que conviene (QoL/Death.lua); Lya
--   lee su consejo (A.QoL.GetDeathAdvice) para que digan lo mismo. Sin él,
--   Lya pone la flecha en tu cuerpo (C_DeathInfo.GetCorpseMapPosition, en
--   0-100 para Nav.SetTarget) y te ofrece «Llévame a mi cuerpo».
--   lya.muerte lo apaga.
--
--   Mu.Consejo() -> { cuerpoYd, cuerpoSeg, choice, sickness, via, mapa, x, y, motor } | nil
--   Mu.Aconsejar() -> true si habló   Mu.Flecha(c) -> true si puso la flecha

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local type, tonumber, pcall, rawget, format, floor, sqrt = type, tonumber, pcall, rawget, string.format, math.floor, math.sqrt

local Mu = {}
M.Muerte = Mu

local ANGEL = 25          -- % de durabilidad que cuesta el ángel (en todo el equipo)
local CORRER = 7          -- yardas por segundo de un espíritu, si el juego no lo dice
local DEBIL = 600         -- s de debilidad de resurrección desde el nivel 11 (Forever)

local function secreto(v) return issecretvalue ~= nil and type(v) ~= "nil" and issecretvalue(v) and true or false end
local function num(v) if secreto(v) then return nil end return tonumber(v) end
local function si(v) return not secreto(v) and v == true end

local function esEspiritu() return UnitIsGhost and si(UnitIsGhost("player")) or false end

local function nivel() return num(UnitLevel and UnitLevel("player")) or 1 end

-- La debilidad a tu nivel: la que da el motor (lo que el juego te dio la última vez).
local function debilidad()
	local Q = A.QoL
	local D = type(Q) == "table" and Q.Death
	if type(D) == "table" and type(D.Sickness) == "function" then
		local st = type(Q.State) == "function" and Q.State() or nil
		local ok, s = pcall(D.Sickness, nivel(), type(st) == "table" and st.resSickness or nil)
		if ok and tonumber(s) then return tonumber(s) end
	end
	return nivel() <= 10 and 0 or DEBIL
end

local function distancia(yd)
	if type(A.FormatDistance) == "function" then
		local ok, t = pcall(A.FormatDistance, yd)
		if ok and type(t) == "string" then return t end
	end
	return format(L["%d yardas"], floor(yd + 0.5))
end

local function tiempo(seg)
	seg = floor((tonumber(seg) or 0) + 0.5)
	if seg < 60 then return format(L["%d s"], seg) end
	return format(L["%d min"], floor(seg / 60 + 0.5))
end

-- Tu cuerpo, sin el motor: el mapa donde estás y su punto en 0-100.
local function vector(x, y)
	if type(CreateVector2D) == "function" then return CreateVector2D(x, y) end
	return { x = x, y = y, GetXY = function(s) return s.x, s.y end }
end
local function xy(v)
	if type(v) ~= "table" then return nil end
	if type(v.GetXY) == "function" then return v:GetXY() end
	return v.x, v.y
end

local function cuerpoPropio()
	local Mp, Di = C_Map, C_DeathInfo
	if not (Mp and Mp.GetBestMapForUnit and Di and Di.GetCorpseMapPosition) then return nil end
	local ok, mapa = pcall(Mp.GetBestMapForUnit, "player")
	mapa = ok and num(mapa) or nil
	if not mapa then return nil end
	local bien, pos = pcall(Di.GetCorpseMapPosition, mapa)
	local cx, cy = xy(bien and pos or nil)
	cx, cy = num(cx), num(cy)
	if not (cx and cy) then return nil end
	local c = { mapa = mapa, x = cx * 100, y = cy * 100 }
	-- Las yardas: los dos puntos en el mundo.
	if Mp.GetPlayerMapPosition and Mp.GetWorldPosFromMapPos then
		local ok2, yo = pcall(Mp.GetPlayerMapPosition, mapa, "player")
		local px, py = xy(ok2 and yo or nil)
		px, py = num(px), num(py)
		if px and py then
			local a1, _, w1 = pcall(Mp.GetWorldPosFromMapPos, mapa, vector(px, py))
			local a2, _, w2 = pcall(Mp.GetWorldPosFromMapPos, mapa, vector(cx, cy))
			local x1, y1 = xy(a1 and w1 or nil)
			local x2, y2 = xy(a2 and w2 or nil)
			if num(x1) and num(y1) and num(x2) and num(y2) then
				c.yd = sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
			end
		end
	end
	return c
end

-- Lo que conviene. Primero lo del motor (para que la flecha y Lya digan lo mismo).
function Mu.Consejo()
	local Q = A.QoL
	if type(Q) == "table" and type(Q.GetDeathAdvice) == "function" then
		local ok, a = pcall(Q.GetDeathAdvice)
		if ok and type(a) == "table" and a.choice then
			return { motor = true, choice = a.choice, cuerpoYd = num(a.corpseYards), cuerpoSeg = num(a.corpseSeconds),
				angelYd = num(a.healerYards), sickness = num(a.sickness) or debilidad(), via = type(a.via) == "string" and a.via or nil,
				mapa = num(a.corpseMap), x = num(a.corpseX), y = num(a.corpseY) }
		end
	end
	local c = cuerpoPropio()
	if not c then return nil end
	local s = debilidad()
	local seg = c.yd and c.yd / CORRER or nil
	-- Correr gana si llegas antes de lo que dura la debilidad (o si no la hay, siempre: el ángel cuesta durabilidad).
	local choice = (not seg or s == 0 or seg <= s) and "corpse" or "healer"
	return { motor = false, choice = choice, cuerpoYd = c.yd, cuerpoSeg = seg, sickness = s, mapa = c.mapa, x = c.x, y = c.y }
end

function Mu.Flecha(c)
	c = c or Mu.Consejo()
	local Nav = A.Nav
	if not (type(c) == "table" and c.mapa and c.x and c.y and type(Nav) == "table" and type(Nav.SetTarget) == "function") then return false end
	local t = Nav.SetTarget(c.mapa, c.x, c.y, L["Tu cuerpo"])
	if t and type(Nav.StartTrip) == "function" then pcall(Nav.StartTrip, t, L["Tu cuerpo"], L["Lya"], "arrive") end
	return t and true or false
end

local function texto(c)
	local partes = {}
	if c.via then
		partes[#partes + 1] = format(L["Tu cuerpo quedó dentro de %s: corre a su entrada."], c.via)
	elseif c.cuerpoYd then
		partes[#partes + 1] = format(L["Tu cuerpo está a %s, como %s corriendo."], distancia(c.cuerpoYd), tiempo(c.cuerpoSeg))
	end
	if (c.sickness or 0) > 0 then
		partes[#partes + 1] = format(L["El ángel te revive ya, pero tu equipo pierde %d %% de durabilidad y quedas débil %s."], ANGEL, tiempo(c.sickness))
	else
		partes[#partes + 1] = format(L["El ángel te revive ya y a tu nivel no quedas débil, pero tu equipo pierde %d %% de durabilidad."], ANGEL)
	end
	local Ce = M.Cerebro
	local pct = Ce and Ce.PeorDurabilidad and Ce.PeorDurabilidad()
	if pct and pct <= 40 then
		partes[#partes + 1] = format(L["Tu equipo ya va en %d %%: cuídalo."], floor(pct + 0.5))
	end
	partes[#partes + 1] = c.choice == "healer" and L["Esta vez conviene el ángel."] or L["Yo correría por tu cuerpo."]
	return table.concat(partes, " ")
end

local dicho = false -- ya habló en esta caída

function Mu.Aconsejar()
	if N.Get(ID, "muerte") == false or dicho or not esEspiritu() then return false end
	local c = Mu.Consejo()
	if not c then return false end
	local acciones
	-- Sin el motor, Lya pone la flecha ella misma (si conviene el cuerpo).
	if not c.motor and c.mapa then
		if c.choice == "corpse" then Mu.Flecha(c) end
		acciones = { { texto = L["Llévame a mi cuerpo"], fn = function() Mu.Flecha(c) end } }
	end
	local Ce = M.Cerebro
	local ok = Ce and Ce.Decir({ texto = texto(c), importante = true, cara = "atenta", segundos = 16, lineas = 5, ancho = 360,
		clase = "muerte", acciones = acciones })
	if ok == true or ok == "espera" then dicho = true return true end
	return false
end

local turno = 0
local function intentar(mio, vez)
	if mio ~= turno or dicho or not esEspiritu() then return end
	local ok, hablo = pcall(Mu.Aconsejar)
	if not ok and geterrorhandler then geterrorhandler()(hablo) end
	if ok and hablo or vez >= 4 then return end
	K.Despues(3, function() intentar(mio, vez + 1) end)
end

-- Al liberar el espíritu el juego te devuelve "vivo" como espíritu.
A.RegisterEvent("PLAYER_ALIVE", function()
	if not esEspiritu() then dicho = false return end
	turno = turno + 1
	local mio = turno
	-- Que el motor alcance a decidir (revisa cada segundo).
	A.After(2, function() intentar(mio, 1) end)
end)
A.RegisterEvent("PLAYER_DEAD", function() dicho = false end)
A.RegisterEvent("PLAYER_UNGHOST", function() dicho = false turno = turno + 1 end)
