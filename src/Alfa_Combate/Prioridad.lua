-- Alfa - Combate: la prioridad propia de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- Lee la lista de tu clase (Prioridades.lua) con datos de tu personaje y
-- devuelve, en orden, lo que conviene presionar: nada más. No aprieta nada.
--   * Cada habilidad se busca por su nombre: vale el rango más alto que conozcas.
--   * C_Spell.IsSpellUsable decide lo que el juego ya sabe (actitud, forma,
--     recurso, Ejecutar, Abrumar...), y C_Spell.IsSpellInRange el alcance.
--   * Tus efectos (C_UnitAuras.GetAuraDataBySpellName en "player"), tu ira,
--     energía, maná y puntos de combo, el encantamiento de tu arma y lo que
--     lanzaste a este objetivo (UNIT_SPELLCAST_SUCCEEDED del jugador).
--   * La situación: con 3 o más enemigos peleando a la vista (sus placas de
--     nombre) entran las habilidades de área.
-- Lo secreto o lo que no se puede leer cuenta como "no se sabe": esa
-- condición no se cumple y la habilidad no se sugiere por ella.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local P = {}
M.Prioridad = P

local type, ipairs, pairs, max, floor = type, ipairs, pairs, math.max, math.floor
local GCD = 1.6
local VARIOS = 3

local lista   -- las entradas que conoces: { def, id, nombre, buffs }
local rama    -- la rama elegida de tu clase
local lanzado = {} -- nombre -> { t, veces, serie }
local serie = 0    -- cambia con cada objetivo

local function numero(v)
	if M.Secreto(v) or type(v) ~= "number" then return nil end
	return v
end

-- El id del rango más alto que conoces, por el nombre de cualquier rango.
local function resolver(id)
	local nombre = M.NombreHechizo(id)
	if not nombre then return nil end
	local sid
	if C_Spell and C_Spell.GetSpellInfo then
		local info = M.Llamar(C_Spell.GetSpellInfo, nombre)
		if type(info) == "table" and not M.Secreto(info) then sid = numero(info.spellID) end
	end
	if sid and M.Conoce(sid) then return sid, nombre end
	if M.Conoce(id) then return id, nombre end
	return nil
end

function P.Preparar()
	lista, rama = {}, nil
	local defs = M.PRIORIDADES[M.Clase() or ""]
	if not defs then return end
	for _, r in ipairs(defs) do
		local vale = r.firma == nil
		for _, id in ipairs(r.firma or {}) do
			if M.Conoce(id) then vale = true break end
		end
		if vale then rama = r break end
	end
	if not rama then return end
	for _, d in ipairs(rama.lista) do
		local sid, nombre = resolver(d.id)
		if sid then
			local x = { def = d, id = sid, nombre = nombre }
			if d.sinBuff == true then
				x.buffs = { nombre }
			elseif type(d.sinBuff) == "table" then
				x.buffs = {}
				for _, b in ipairs(d.sinBuff) do
					local n = M.NombreHechizo(b)
					if n then x.buffs[#x.buffs + 1] = n end
				end
			end
			lista[#lista + 1] = x
		end
	end
end

function P.Lista()
	if not lista then P.Preparar() end
	return lista
end

-- La rama elegida: { clave, nombre } o nil.
function P.Rama()
	if not lista then P.Preparar() end
	return rama
end

function P.Hay() return #P.Lista() > 0 end

function P.Olvidar() lista, rama = nil, nil end

---------------------------------------------------------------------------
-- Lo que se lee de tu personaje
---------------------------------------------------------------------------
-- true (lo tienes), false (no), nil (no se puede saber)
local function tieneEfecto(nombres)
	local porNombre = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
	if not porNombre then return nil end
	for _, n in ipairs(nombres) do
		local ok, a = pcall(porNombre, "player", n, "HELPFUL")
		if not ok or M.Secreto(a) then return nil end
		if a ~= nil then return true end
	end
	return false
end

local function poder() return numero(M.Llamar(UnitPower, "player")) end

local function manaPct()
	local v, t = numero(M.Llamar(UnitPower, "player", 0)), numero(M.Llamar(UnitPowerMax, "player", 0))
	if not (v and t and t > 0) then return nil end
	return v * 100 / t
end

local function combo()
	local tipo = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
	local v = numero(M.Llamar(UnitPower, "player", tipo))
	if v == nil and GetComboPoints then v = numero(M.Llamar(GetComboPoints, "player", "target")) end
	return v
end

local function armaEncantada()
	if not GetWeaponEnchantInfo then return nil end
	local si = M.Legible(M.Llamar(GetWeaponEnchantInfo))
	if si == nil then return false end
	return si and true or false
end

-- Varios enemigos peleando a la vista (por sus placas de nombre).
function P.Varios()
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then return false end
	local placas = M.Llamar(C_NamePlate.GetNamePlates)
	if type(placas) ~= "table" or M.Secreto(placas) then return false end
	local n = 0
	for _, p in ipairs(placas) do
		local u = type(p) == "table" and (rawget(p, "namePlateUnitToken") or (p.UnitFrame and p.UnitFrame.unit))
		if type(u) == "string" and not M.Secreto(u) then
			local ataca = M.Legible(M.Llamar(UnitCanAttack, "player", u))
			local pelea = M.Legible(M.Llamar(UnitAffectingCombat, u))
			if ataca == true and pelea == true then
				n = n + 1
				if n >= VARIOS then return true end
			end
		end
	end
	return false
end

-- Lo pusiste en este objetivo hace poco (las veces que pide).
local function reciente(x, ahora)
	local d = x.def
	if not d.cada then return false end
	local c = lanzado[x.nombre]
	if not (c and c.serie == serie) then return false end
	return ahora - c.t < d.cada and c.veces >= (d.veces or 1)
end

-- Lo que lanzaste tú (solo el jugador).
function P.Lanzaste(spellID)
	if M.Secreto(spellID) or type(spellID) ~= "number" then return end
	local nombre = M.NombreHechizo(spellID)
	if not nombre then return end
	local ahora = GetTime()
	local c = lanzado[nombre]
	if c and c.serie == serie and ahora - c.t < 40 then
		c.veces = c.veces + 1
		c.t = ahora
	else
		lanzado[nombre] = { t = ahora, veces = 1, serie = serie }
	end
end

function P.NuevoObjetivo() serie = serie + 1 end

---------------------------------------------------------------------------
-- Calcular
---------------------------------------------------------------------------
-- -> lista ordenada de { id, nombre, porque, grupo (1 lista, 2 espera recurso,
--    3 en recarga), resta }, y si hay varios enemigos.
function P.Calcular(n)
	local out = {}
	local entradas = P.Lista()
	if #entradas == 0 then return out, false end
	local ahora = GetTime()
	local hay, combate, varios = M.HayEnemigo(), M.EnCombate(), P.Varios()
	local ira, mana, cp, arma
	local vistos = {}
	for i, x in ipairs(entradas) do
		local d = x.def
		local pasa = not vistos[x.id]
		if pasa and not d.sinObjetivo and not hay then pasa = false end
		if pasa and d.soloCombate and not combate then pasa = false end
		if pasa and d.aoe and not varios then pasa = false end
		if pasa and d.solo and varios then pasa = false end
		if pasa and (d.minPoder or d.maxPoder) then
			if ira == nil then ira = poder() or false end
			if not ira or (d.minPoder and ira < d.minPoder) or (d.maxPoder and ira > d.maxPoder) then pasa = false end
		end
		if pasa and d.maxPct then
			if mana == nil then mana = manaPct() or false end
			if not mana or mana > d.maxPct then pasa = false end
		end
		if pasa and d.minCombo then
			if cp == nil then cp = combo() or false end
			if not cp or cp < d.minCombo then pasa = false end
		end
		if pasa and d.sinArma then
			if arma == nil then arma = armaEncantada() end
			if arma ~= false then pasa = false end
		end
		if pasa and x.buffs and tieneEfecto(x.buffs) ~= false then pasa = false end
		if pasa and reciente(x, ahora) then pasa = false end
		if pasa then
			local usable, sinPoder = M.Llamar(C_Spell and C_Spell.IsSpellUsable, x.id)
			usable, sinPoder = M.Legible(usable), M.Legible(sinPoder)
			if usable == true or sinPoder == true then
				local alcance
				if hay and not d.sinObjetivo and C_Spell and C_Spell.IsSpellInRange then
					alcance = M.Legible(M.Llamar(C_Spell.IsSpellInRange, x.id, "target"))
				end
				if alcance ~= false then
					local inicio, dur = A.Compat.GetSpellCooldown(x.id)
					local resta = dur > GCD and max(0, inicio + dur - ahora) or 0
					vistos[x.id] = true
					out[#out + 1] = { id = x.id, nombre = x.nombre, porque = d.porque, orden = i, resta = resta,
						grupo = resta > 0 and 3 or (usable == true and 1 or 2) }
				end
			end
		end
	end
	table.sort(out, function(a, b)
		if a.grupo ~= b.grupo then return a.grupo < b.grupo end
		if a.grupo == 3 and a.resta ~= b.resta then return a.resta < b.resta end
		return a.orden < b.orden
	end)
	for i = (n or #out) + 1, #out do out[i] = nil end
	return out, varios
end

-- Tus lanzamientos, solo los del jugador.
local ev = CreateFrame("Frame")
pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
ev:SetScript("OnEvent", function(_, _, _, _, spellID) K.Llamar(P.Lanzaste, spellID) end)
