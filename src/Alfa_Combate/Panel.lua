-- Alfa - Combate: panel de estadísticas (toxic3000 / La Jauría). GPL-3.0.
--
-- Un cuadro pequeño con tu vida y las estadísticas que más pesan para tu
-- clase, opcional (apagado por omisión) y movible. Solo datos de tu
-- personaje; si el juego oculta un número en combate, se queda el último que
-- se pudo leer (en gris). Se actualiza con los eventos de tus estadísticas,
-- sin OnUpdate.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local Pn = {}
M.Panel = Pn

local type, ipairs, pcall, floor, format, tostring, max = type, ipairs, pcall, math.floor, string.format, tostring, math.max
local ESP = K.ESP
local ANCHO, FILA = 184, 17

local function num(v)
	if M.Secreto(v) or type(v) ~= "number" then return nil end
	return v
end

local function mejorEscuela(fn)
	if type(fn) ~= "function" then return nil end
	local mejor
	for escuela = 2, 7 do
		local v = num(M.Llamar(fn, escuela))
		if v and (not mejor or v > mejor) then mejor = v end
	end
	return mejor
end

local function stat(i) local _, e = M.Llamar(UnitStat, "player", i) e = num(e) return e and tostring(floor(e)) end
local function pct(fn) local v = num(M.Llamar(fn)) return v and format("%.1f %%", v) end

-- clave -> { nombre, lector } ; el lector devuelve el texto o nil.
local LECTOR = {
	vida = { L["Vida"], function() local v = num(M.Llamar(UnitHealthMax, "player")) return v and tostring(v) end },
	fue = { L["Fuerza"], function() return stat(1) end },
	agi = { L["Agilidad"], function() return stat(2) end },
	agu = { L["Aguante"], function() return stat(3) end },
	int = { L["Intelecto"], function() return stat(4) end },
	esp = { L["Espíritu"], function() return stat(5) end },
	armadura = { L["Armadura"], function() local _, e = M.Llamar(UnitArmor, "player") e = num(e) return e and tostring(floor(e)) end },
	ap = { L["Poder de ataque"], function()
		local b, p, n = M.Llamar(UnitAttackPower, "player")
		b, p, n = num(b), num(p), num(n)
		return b and tostring(floor(b + (p or 0) + (n or 0)))
	end },
	apd = { L["Poder a distancia"], function()
		local b, p, n = M.Llamar(UnitRangedAttackPower, "player")
		b, p, n = num(b), num(p), num(n)
		return b and tostring(floor(b + (p or 0) + (n or 0)))
	end },
	critico = { L["Crítico"], function() return pct(GetCritChance) end },
	golpe = { L["Golpe"], function() local v = num(M.Llamar(GetHitModifier)) return v and format("+%d %%", v) end },
	criticoH = { L["Crítico con hechizos"], function() local v = mejorEscuela(GetSpellCritChance) return v and format("%.1f %%", v) end },
	golpeH = { L["Golpe con hechizos"], function() local v = num(M.Llamar(GetSpellHitModifier)) return v and format("+%d %%", v) end },
	poderH = { L["Poder con hechizos"], function() local v = mejorEscuela(GetSpellBonusDamage) return v and tostring(floor(v)) end },
	sanacion = { L["Sanación"], function() local v = num(M.Llamar(GetSpellBonusHealing)) return v and tostring(floor(v)) end },
	mp5 = { L["Maná cada 5 s"], function() local _, c = M.Llamar(GetManaRegen) c = num(c) return c and format("%.0f", c * 5) end },
	esquivar = { L["Esquivar"], function() return pct(GetDodgeChance) end },
	parar = { L["Parar"], function() return pct(GetParryChance) end },
	bloquear = { L["Bloquear"], function() return pct(GetBlockChance) end },
	defensa = { L["Defensa"], function()
		local b, m = M.Llamar(UnitDefense, "player")
		b, m = num(b), num(m)
		return b and tostring(floor(b + (m or 0)))
	end },
	dpsArma = { L["DPS del arma"], function()
		local lo, hi = M.Llamar(UnitDamage, "player")
		local vel = M.Llamar(UnitAttackSpeed, "player")
		lo, hi, vel = num(lo), num(hi), num(vel)
		return lo and hi and vel and vel > 0 and format("%.1f", (lo + hi) / 2 / vel) or nil
	end },
}

-- Lo que más pesa por clase (la vida va siempre primero).
local POR_CLASE = {
	WARRIOR = { "ap", "critico", "golpe", "armadura", "defensa", "dpsArma" },
	ROGUE = { "ap", "critico", "golpe", "agi", "esquivar", "dpsArma" },
	HUNTER = { "apd", "critico", "golpe", "agi", "armadura" },
	PALADIN = { "ap", "critico", "golpe", "poderH", "sanacion", "armadura" },
	SHAMAN = { "ap", "critico", "poderH", "criticoH", "mp5" },
	DRUID = { "ap", "critico", "poderH", "criticoH", "armadura" },
	MAGE = { "poderH", "criticoH", "golpeH", "int", "mp5" },
	WARLOCK = { "poderH", "criticoH", "golpeH", "agu", "mp5" },
	PRIEST = { "sanacion", "poderH", "criticoH", "esp", "mp5" },
}
local GENERAL = { "fue", "agi", "agu", "int", "armadura" }

local f
local ultimo = {} -- clave -> último texto legible

local function claves()
	local out = { "vida" }
	for _, k in ipairs(POR_CLASE[M.Clase() or ""] or GENERAL) do out[#out + 1] = k end
	return out
end

local function crear()
	if f then return f end
	f = M.Marco("Panel", L["Panel de estadísticas"], ANCHO, 120, { "RIGHT", "RIGHT", -240, 0 })
	f.Fondo = CreateFrame("Frame", nil, f)
	f.Fondo:SetAllPoints(f)
	f.Fondo.caja = K.Caja(f.Fondo, { fondo = "fondo", alfaFondo = 0.85, borde = "linea", corte = K.CORTE.control })
	f.Titulo = K.Texto(f.Fondo, "mayus", "acento")
	f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.m, -ESP.s - 2)
	K.Escribir(f.Titulo, K.Mayus and K.Mayus(L["Tus estadísticas"]) or L["Tus estadísticas"]:upper())
	f.filas = {}
	f:Hide()
	return f
end

function Pn.Actualizar()
	if not (f and f:IsShown()) then return end
	local lista = claves()
	local y = ESP.s + 2 + K.Tamano("mayus") + ESP.s
	for i, k in ipairs(lista) do
		local r = f.filas[i]
		if not r then
			r = { Nombre = K.Texto(f.Fondo, "pequeno", "textoSuave"), Valor = K.Texto(f.Fondo, "numero", "texto") }
			r.Valor:SetJustifyH("RIGHT")
			f.filas[i] = r
		end
		local def = LECTOR[k]
		local ok, texto = pcall(def[2])
		if ok and texto then ultimo[k] = texto end
		K.Escribir(r.Nombre, def[1])
		r.Valor:SetText(ultimo[k] or "\226\128\147")
		K.ColorTexto(r.Valor, (ok and texto) and "texto" or "textoTenue")
		r.Nombre:ClearAllPoints()
		r.Nombre:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.m, -y)
		r.Valor:ClearAllPoints()
		r.Valor:SetPoint("TOPRIGHT", f, "TOPRIGHT", -ESP.m, -y)
		r.Nombre:Show()
		r.Valor:Show()
		y = y + FILA
	end
	for i = #lista + 1, #f.filas do f.filas[i].Nombre:Hide() f.filas[i].Valor:Hide() end
	f:SetHeight(max(48, y + ESP.s))
end

function Pn.Ver()
	if not M.Opt("panel") then
		if f then f:Hide() end
		return
	end
	crear()
	f:Show()
	Pn.Actualizar()
end

local pendiente = false
function Pn.Pedir()
	if pendiente or not (f and f:IsShown()) then return end
	pendiente = true
	A.After(0.3, function()
		pendiente = false
		Pn.Actualizar()
	end)
end

-- Tus estadísticas cambiaron (solo las del jugador).
local ev = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_MAXHEALTH", "UNIT_RESISTANCES", "UNIT_AURA" }) do
	pcall(ev.RegisterUnitEvent, ev, e, "player")
end
for _, e in ipairs({ "COMBAT_RATING_UPDATE", "PLAYER_DAMAGE_DONE_MODS", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP" }) do
	pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() Pn.Pedir() end)
