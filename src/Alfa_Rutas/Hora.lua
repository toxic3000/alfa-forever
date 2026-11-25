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
local N = M.N
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

-- 1.3.7: los nombres con que el registro puede agrupar las misiones de aquí
-- (118). En una capital el encabezado no siempre es el texto de la zona
-- («Ciudad de Ventormenta» y «Ventormenta», o la zona que la rodea): vale el
-- texto de la zona, el del mapa y el del mapa de arriba si es una zona.
local function nombresDeAqui()
	local out = {}
	local function poner(z)
		if not secreto(z) and type(z) == "string" and z ~= "" then out[M.Plegar(z)] = true end
	end
	for _, n in ipairs({ "GetRealZoneText", "GetZoneText" }) do
		local fn = rawget(_G, n)
		if type(fn) == "function" then
			local ok, z = pcall(fn)
			if ok then poner(z) end
		end
	end
	local Mp = rawget(_G, "C_Map")
	if type(Mp) == "table" and type(Mp.GetBestMapForUnit) == "function" and type(Mp.GetMapInfo) == "function" then
		local ok, id = pcall(Mp.GetBestMapForUnit, "player")
		local info = ok and type(id) == "number" and select(2, pcall(Mp.GetMapInfo, id)) or nil
		if type(info) == "table" then
			poner(info.name)
			local ok2, padre = pcall(Mp.GetMapInfo, info.parentMapID or 0)
			-- El de arriba solo si es una zona (mapType 3), no el continente.
			if ok2 and type(padre) == "table" and padre.mapType == 3 then poner(padre.name) end
		end
	end
	return out
end
H.NombresDeAqui = nombresDeAqui

function H.PendientesEnZona()
	local QL = C_QuestLog
	local Cp = M.Motor("Compat")
	if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo and Cp) then return 0 end
	local zona = zonaActual()
	if not zona then return 0 end
	local aqui = nombresDeAqui()
	local ok, n = pcall(QL.GetNumQuestLogEntries)
	n = ok and M.num(n, 0) or 0
	local enZona, cuenta = false, 0
	for i = 1, n do
		local okI, info = pcall(QL.GetInfo, i)
		if okI and type(info) == "table" then
			if info.isHeader then
				local t = info.title
				enZona = type(t) == "string" and not secreto(t) and (t == zona or aqui[M.Plegar(t)] == true)
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
	if (Cr.ListasAhora() or 0) >= M.Vuelta.MIN then
		M.EntregarListas()
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

-- 1.3.7: el tiempo en vuelo (grifo, barco), ausente o en la subasta no es
-- tiempo de tu guía (120): se aparta de cada medida. H.Pausa() -> los
-- segundos apartados desde que cargó Alfa (solo crece).
local pausa = { suma = 0, desde = nil, taxi = false, afk = false, subasta = false }
local function pausado() return pausa.taxi or pausa.afk or pausa.subasta end
local function poner(clave, valor)
	local antes = pausado()
	pausa[clave] = valor and true or false
	local t = GetTime()
	if not antes and pausado() then pausa.desde = t
	elseif antes and not pausado() and pausa.desde then
		pausa.suma = pausa.suma + max(0, t - pausa.desde)
		pausa.desde = nil
	end
end
function H.Pausa()
	return pausa.suma + (pausa.desde and max(0, GetTime() - pausa.desde) or 0)
end
H.Poner = poner -- (para el banco)
local function revisarTaxi()
	-- 1.3.7: nunca `== true` con lo que da el juego (puede ser secreto).
	poner("taxi", N.SiJuego(rawget(_G, "UnitOnTaxi"), "player"))
end
A.RegisterEvent("PLAYER_CONTROL_LOST", function() A.After(0.5, revisarTaxi) end)
A.RegisterEvent("PLAYER_CONTROL_GAINED", revisarTaxi)
A.RegisterEvent("PLAYER_FLAGS_CHANGED", function()
	poner("afk", N.SiJuego(rawget(_G, "UnitIsAFK"), "player"))
end)
A.RegisterEvent("AUCTION_HOUSE_SHOW", function() poner("subasta", true) end)
A.RegisterEvent("AUCTION_HOUSE_CLOSED", function() poner("subasta", false) end)

local marca -- { guia, paso, t, p }: dónde y cuándo empezó el paso vivo (p: H.Pausa() de entonces)

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
		local fuera = H.Pausa() - (marca.p or H.Pausa())
		if pasos <= MAX_SALTO then H.Muestra(max(0, ahora - marca.t - fuera) / pasos) end
	end
	if not marca or marca.guia ~= id or vivo ~= marca.paso then
		marca = { guia = id, paso = vivo, t = ahora, p = H.Pausa() }
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

-- 1.3.7: cuánto te tomaría una guía de `pasos` pasos a tu ritmo (la
-- Biblioteca, 96). -> minutos | nil (pocas medidas)
function H.EstimadoPasos(pasos)
	local r = ritmo()
	pasos = M.num(pasos, 0)
	if r.n < MIN_MEDIDAS or r.prom <= 0 or pasos <= 0 then return nil end
	return max(1, floor(pasos * r.prom / 60 + 0.5))
end

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
