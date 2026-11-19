-- Alfa - Rutas: «Una hora de caza» y cuánto te falta (toxic3000 / La Jauría).
-- GPL-3.0. -- 1.2.7
--
--   Hora.UnaHora() -> "entregar" | "zona" | "recoger"
--       un plan corto con lo que más rinde cerca de ti: con 2 o más misiones
--       listas, entregarlas; si no, con misiones sin terminar en tu zona,
--       cerrarlas; si no, recoger misiones nuevas.
--   Hora.PendientesEnZona() -> n   misiones de tu registro sin terminar, bajo
--       el encabezado de tu zona (el registro del juego las agrupa por zona)
--   Hora.Estimado() -> minutos | nil   lo que te falta de tu guía: los pasos
--       que quedan por lo que tardas en cada uno (nil con menos de 5 medidas)
--   Hora.Muestra(segundos)   una medida más del ritmo (lo usa el banco)
--
-- El ritmo se mide solo: cada vez que el paso vivo de tu guía avanza (no al
-- mirar otro paso ni al omitir uno), el tiempo desde el paso anterior. Más de
-- 15 minutos no cuenta (te fuiste a otra cosa). Es un promedio que se mueve,
-- por personaje (N.DatosPersonaje("rutas").ritmo = { prom, n }).

local ADDON, M = ...
local A = M.A
local H = {}
M.Hora = H

local type, tonumber, ipairs = type, tonumber, ipairs
local floor, max, min = math.floor, math.max, math.min

local AFK = 900       -- segundos: más que esto entre dos pasos no cuenta
local MIN_MEDIDAS = 5 -- con menos, no se estima
local MAX_SALTO = 3   -- un avance de más pasos de golpe no es un paso hecho
local PESO = 0.15     -- cuánto pesa una medida nueva (cuando ya hay varias)

local function E() return A.Engine end

local function secreto(v) return issecretvalue and issecretvalue(v) or false end

---------------------------------------------------------------------------
-- ¿Qué hago con una hora?
---------------------------------------------------------------------------

local function zonaActual()
	for _, fn in ipairs({ rawget(_G, "GetRealZoneText"), rawget(_G, "GetZoneText") }) do
		if type(fn) == "function" then
			local ok, z = pcall(fn)
			if ok and type(z) == "string" and not secreto(z) and z ~= "" then return z end
		end
	end
	return nil
end

function H.PendientesEnZona()
	local QL = C_QuestLog
	local Cp = M.Motor("Compat")
	if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo and Cp) then return 0 end
	local zona = zonaActual()
	if not zona then return 0 end
	local ok, n = pcall(QL.GetNumQuestLogEntries)
	n = ok and M.num(n, 0) or 0
	local enZona, cuenta = false, 0
	for i = 1, n do
		local okI, info = pcall(QL.GetInfo, i)
		if okI and type(info) == "table" then
			if info.isHeader then
				local t = info.title
				enZona = type(t) == "string" and not secreto(t) and t == zona
			elseif enZona and not info.isHidden then
				local q = Cp.Readable and Cp.Readable(info.questID) or info.questID
				if type(q) == "number" and q > 0 and not secreto(q) and not Cp.IsQuestReadyForTurnIn(q) then
					cuenta = cuenta + 1
				end
			end
		end
	end
	return cuenta
end

function H.UnaHora()
	local Cr = M.Cerrar
	if (Cr.ListasAhora() or 0) >= 2 then
		Cr.Ahora("listas")
		return "entregar"
	end
	if H.PendientesEnZona() > 0 then
		Cr.Ahora("zona")
		return "zona"
	end
	M.Recoger.Ahora()
	return "recoger"
end

---------------------------------------------------------------------------
-- El ritmo: cuánto tardas por paso
---------------------------------------------------------------------------

local function ritmo()
	local d = M.Personaje()
	if type(d.ritmo) ~= "table" then d.ritmo = { prom = 0, n = 0 } end
	local r = d.ritmo
	r.prom, r.n = M.num(r.prom, 0), M.num(r.n, 0)
	return r
end
H.Ritmo = ritmo

local ultima -- la última medida, para quitarla si fue un paso omitido

function H.Muestra(seg)
	seg = M.num(seg, nil)
	if not seg or seg < 0 or seg > AFK then return false end
	local r = ritmo()
	ultima = { t = GetTime(), prom = r.prom, n = r.n }
	-- Las primeras, un promedio simple; después, la nueva pesa poco.
	local peso = max(1 / (r.n + 1), PESO)
	r.prom = r.prom + (seg - r.prom) * peso
	r.n = min(r.n + 1, 9999)
	return true
end

local marca -- { guia, paso, t }: dónde y cuándo empezó el paso vivo

local function alCambiarPaso()
	local e = E()
	if not (e and e.GetGuide and e.GetLiveStep) then return end
	local okG, g = pcall(e.GetGuide)
	local okV, vivo = pcall(e.GetLiveStep)
	local id = okG and type(g) == "table" and g.id or nil
	vivo = okV and tonumber(vivo) or nil
	local ahora = GetTime()
	if not (id and vivo) then marca = nil return end
	if marca and marca.guia == id and vivo > marca.paso then
		local pasos = vivo - marca.paso
		if pasos <= MAX_SALTO then H.Muestra((ahora - marca.t) / pasos) end
	end
	if not marca or marca.guia ~= id or vivo ~= marca.paso then
		marca = { guia = id, paso = vivo, t = ahora }
	end
end
H.AlCambiarPaso = alCambiarPaso

A.On("STEP_CHANGED", alCambiarPaso)
A.On("GUIDE_CHANGED", function() marca = nil alCambiarPaso() end)
-- Un paso omitido no es un paso hecho: el motor avisa después de mover el
-- paso vivo (Engine.Skip: STEP_CHANGED y luego PLAYER_SKIPPED_STEP), así que
-- la medida de ese mismo instante se quita.
function H.AlOmitir()
	if ultima and ultima.t == GetTime() then
		local r = ritmo()
		r.prom, r.n = ultima.prom, ultima.n
	end
	ultima = nil
end
A.On("PLAYER_SKIPPED_STEP", function() H.AlOmitir() end)

function H.Estimado()
	local r = ritmo()
	if r.n < MIN_MEDIDAS or r.prom <= 0 then return nil end
	local e = E()
	if not (e and e.GetGuide and e.GetProgress and e.GetGuide()) then return nil end
	local ok, hechos, todos = pcall(e.GetProgress)
	if not ok then return nil end
	local quedan = M.num(todos, 0) - M.num(hechos, 0)
	if quedan <= 0 then return nil end
	return max(1, floor(quedan * r.prom / 60 + 0.5))
end
