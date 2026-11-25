-- Alfa - Rutas: qué recompensa elegir en cada misión de tu guía (toxic3000 /
-- La Jauría). GPL-3.0. 1.4.0 (28)
--
-- Bajo una entrega del rastreador: «Elige: Garrote de raíz (+12 %)», la
-- recompensa que le sirve a tu clase y tu especialización. La decide el
-- consejo de equipo del motor (Alfa.Gear: la mejora más grande, o si
-- ninguna mejora, la que mejor puntúa para ti), con la lista de recompensas
-- de cada misión de su base de objetos (Gear.QuestPick). En una misión por
-- tomar solo sale si es una mejora («Al entregarla: …»).
--
-- Se mira poco: una vez por misión (se olvida cuando cambia tu equipo, tu
-- nivel o tu especialización: GEAR_UPDATED) y nunca en combate (en combate
-- se dice lo que ya se sabía). Ajuste rutas.recompensaGuia (de fábrica, sí);
-- también lo apaga el consejo de equipo del motor (gear.rewards).
--
--   Recompensa.De(qid, tipo) -> { id, nombre, mejora, ganancia } | nil
--   Recompensa.Texto(meta) -> «Elige: …» | nil

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local Rc = {}
M.Recompensa = Rc

local type, tonumber, pcall, format, floor = type, tonumber, pcall, string.format, math.floor

local cache = {} -- qid -> resultado | false

local function encendido() return A.Get(M.ID .. ".recompensaGuia") ~= false end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function nombre(id)
	local D = A.ItemDB
	local n = D and D.ItemName and select(2, pcall(D.ItemName, id))
	if type(n) ~= "string" or n == "" then n = M.NombreObjeto(id) end
	return n
end

local function color(id)
	local D = A.ItemDB
	local ok, r = pcall(function() return D and D.Get and D.Get(id) end)
	local q = ok and type(r) == "table" and tonumber(r.quality) or nil
	local CI = rawget(_G, "C_Item")
	if q and type(CI) == "table" and CI.GetItemQualityColor then
		local ok2, cr, cg, cb = pcall(CI.GetItemQualityColor, q)
		if ok2 and type(cr) == "number" then
			return format("ff%02x%02x%02x", floor(cr * 255 + 0.5), floor(cg * 255 + 0.5), floor(cb * 255 + 0.5))
		end
	end
	return nil
end

local function ganancia(e)
	local G = A.Gear
	if not (e and e.upgrade) then return nil end
	if G and G.GainText and e.pct then
		local ok, s = pcall(G.GainText, e.pct)
		if ok and type(s) == "string" and s ~= "" then return s end
	end
	return nil
end

-- La elección del motor para la misión (con sus ajustes de equipo).
local function elegir(qid, tipo)
	local u = A.UI
	local GP = u and u.GearPick
	if GP and GP.PickFor then
		local ok, p = pcall(GP.PickFor, { t = tipo or "turnin", quest = qid, status = "active" })
		if ok then return p end
		return nil
	end
	local G = A.Gear
	if not (G and G.QuestPick and G.IsEnabled and G.IsEnabled()) then return nil end
	local ok, p = pcall(G.QuestPick, qid)
	p = ok and p or nil
	if tipo == "accept" and not (p and p.upgrade) then return nil end
	return p
end

function Rc.De(qid, tipo)
	qid = tonumber(qid)
	if not qid or N.Secreto(qid) or not encendido() then return nil end
	tipo = tipo == "accept" and "accept" or "turnin"
	local k = tipo .. qid
	local c = cache[k]
	if c ~= nil then return c or nil end
	if enCombate() then return nil end
	local p = elegir(qid, tipo)
	local e = type(p) == "table" and p.entry or nil
	local id = e and tonumber(e.id)
	local r = false
	if id then r = { id = id, nombre = nombre(id), mejora = e.upgrade and true or false, ganancia = ganancia(e) } end
	cache[k] = r
	return r or nil
end

function Rc.Texto(g)
	if type(g) ~= "table" then return nil end
	local r = Rc.De(g.quest, g.t)
	if not r then return nil end
	local hex = color(r.id)
	local cosa = hex and ("|c" .. hex .. r.nombre .. "|r") or r.nombre
	if r.ganancia then cosa = cosa .. " (" .. r.ganancia .. ")" end
	if g.t == "accept" then return format(L["Al entregarla, elige: %s"], cosa) end
	return format(L["Elige: %s"], cosa)
end

function Rc.Olvidar() cache = {} end
A.On("GEAR_UPDATED", Rc.Olvidar)
A.On("SETTING_CHANGED", function(ruta)
	if ruta == M.ID .. ".recompensaGuia" or ruta == "gear.rewards" or ruta == "" then Rc.Olvidar() end
end)
