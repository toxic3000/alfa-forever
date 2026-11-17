-- Alfa - Combate: la prioridad propia de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- Lee la lista de tu clase y especialización (Prioridades.lua) con datos de
-- tu personaje y devuelve, en orden, lo que conviene presionar: nada más. No
-- aprieta nada.
--   * Cada habilidad se busca por su nombre: vale el rango más alto que
--     conozcas, y solo entra lo que ya aprendiste (la lista crece contigo).
--   * C_Spell.IsSpellUsable decide lo que el juego ya sabe (actitud, forma,
--     recurso, Ejecutar, Abrumar...) y C_Spell.IsSpellInRange el alcance.
--   * La recarga: C_Spell.GetSpellCooldown. Si sus tiempos llegan secretos,
--     isActive e isOnGCD (que nunca lo son) dicen si está en recarga, y lo que
--     falta se estima con tu último lanzamiento y la duración que Alfa vio
--     cuando sí se podía leer (se guarda por personaje).
--   * Los procs: el brillo oficial del hechizo (SPELL_ACTIVATION_OVERLAY_GLOW_
--     SHOW/HIDE y C_SpellActivationOverlay.IsSpellOverlayed) lo pasa al frente;
--     tus efectos se leen con C_UnitAuras.GetAuraDataBySpellName en "player".
--   * Tu ira, energía, maná y puntos de combo, el encantamiento de tu arma, tu
--     mascota, tu vida y la del enemigo (si se puede leer), lo que lanza el
--     enemigo (para cortarlo) y lo que lanzaste a este objetivo.
--   * Cuántos enemigos pelean a la vista (sus placas de nombre): con 2 o 3 o
--     más entran las habilidades de área.
-- Lo secreto o lo que no se puede leer cuenta como "no se sabe": esa
-- condición no se cumple (salvo `sobreVida`, que entonces no estorba).

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local P = {}
M.Prioridad = P

local type, ipairs, pairs, max, min, floor, tonumber, format = type, ipairs, pairs, math.max, math.min, math.floor, tonumber, string.format
local GCD = 1.6       -- una recarga más corta que esto es la global
local VARIOS = 3      -- enemigos para las de área
local INCIERTA = 30   -- una recarga secreta de la que no sabemos cuánto falta
local NADA = {}

local lista    -- las entradas que conoces: { def, id, nombre, buffs, con, deb, conDeb }
local rama     -- la rama elegida de tu clase
local origen   -- cómo se eligió: "ajuste", "talentos" o "clase"
local lanzado = {}  -- nombre -> { t, veces, serie } en este objetivo
local ultimo = {}   -- nombre -> cuándo lo lanzaste (cualquier objetivo)
local serie = 0     -- cambia con cada objetivo
local brillan = {}  -- nombre -> true mientras el juego lo hace brillar
local respaldo = {} -- recargas vistas, si no hay datos guardados

local function numero(v)
	if M.Secreto(v) or type(v) ~= "number" then return nil end
	return v
end

-- Las duraciones de recarga que Alfa vio (nombre -> segundos), por personaje.
local function recargas()
	local d = N.DatosPersonaje(M.ID)
	if type(d) ~= "table" then return respaldo end
	if type(d.recargas) ~= "table" then d.recargas = {} end
	return d.recargas
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

local function nombres(ids)
	if type(ids) ~= "table" then ids = { ids } end
	local out = {}
	for _, b in ipairs(ids) do
		local n = M.NombreHechizo(b)
		if n then out[#out + 1] = n end
	end
	return out
end

local function nivel() return numero(M.Llamar(UnitLevel, "player")) end

---------------------------------------------------------------------------
-- La especialización
---------------------------------------------------------------------------
function P.Ramas() return M.PRIORIDADES[M.Clase() or ""] or {} end

-- La de tus talentos según el motor (Gear cuenta tus puntos): clave, fuente.
local function claveMotor()
	local G = A.Gear
	if type(G) ~= "table" or type(G.GetSpec) ~= "function" then return nil end
	local ok, k, _, fuente = pcall(G.GetSpec)
	if ok and type(k) == "string" then return k, fuente end
	return nil
end

local function elegir(defs)
	local quiero = M.Opt("rama")
	if type(quiero) == "string" and quiero ~= "auto" then
		for _, r in ipairs(defs) do if r.clave == quiero then return r, "ajuste" end end
	end
	local k, fuente = claveMotor()
	if k and fuente == "talents" then
		for _, r in ipairs(defs) do if r.clave == k then return r, "talentos" end end
	end
	for _, r in ipairs(defs) do
		for _, id in ipairs(r.firma or {}) do
			if M.Conoce(id) then return r, "talentos" end
		end
	end
	if k then
		for _, r in ipairs(defs) do if r.clave == k then return r, "clase" end end
	end
	return defs[1], "clase"
end

function P.Preparar()
	lista, rama, origen = {}, nil, nil
	local defs = P.Ramas()
	if #defs == 0 then return end
	rama, origen = elegir(defs)
	if not rama then return end
	local nv = nivel()
	for _, d in ipairs(rama.lista) do
		local porNivel = not ((d.minNivel and (not nv or nv < d.minNivel)) or (d.maxNivel and nv and nv > d.maxNivel))
		local sid, nombre
		if porNivel then sid, nombre = resolver(d.id) end
		if sid then
			local x = { def = d, id = sid, nombre = nombre }
			if d.sinBuff == true then x.buffs = { nombre }
			elseif type(d.sinBuff) == "table" then x.buffs = nombres(d.sinBuff) end
			if d.conBuff then x.con = nombres(d.conBuff) end
			if d.sinDebuff == true or d.cada then x.deb = { nombre }
			elseif type(d.sinDebuff) == "table" then x.deb = nombres(d.sinDebuff) end
			if type(d.conDebuff) == "table" then
				local otro = M.NombreHechizo(d.conDebuff.id)
				if otro then x.conDeb = { nombre = otro, cada = d.conDebuff.cada or 15 } end
			end
			lista[#lista + 1] = x
		end
	end
end

function P.Lista()
	if not lista then P.Preparar() end
	return lista
end

-- La rama elegida: { clave, nombre } o nil, y cómo se eligió.
function P.Rama()
	if not lista then P.Preparar() end
	return rama, origen
end

function P.Hay() return #P.Lista() > 0 end

function P.Olvidar() lista, rama, origen = nil, nil, nil end

---------------------------------------------------------------------------
-- Lo que se lee de tu personaje y del enemigo
---------------------------------------------------------------------------
-- true (lo tienes), false (no), nil (no se puede saber). Mira tus efectos
-- y también lo que te pusieron (Alma debilitada).
local function tieneEfecto(lista_)
	local porNombre = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
	if not porNombre then return nil end
	for _, n in ipairs(lista_) do
		for _, filtro in ipairs({ "HELPFUL", "HARMFUL" }) do
			local ok, a = pcall(porNombre, "player", n, filtro)
			if not ok or M.Secreto(a) then return nil end
			if a ~= nil then return true end
		end
	end
	return false
end

-- Tu efecto en el enemigo: "si", "vence" (quedan menos de 2 s) o nil (no
-- está o no se puede saber), y sus cargas si se pueden leer.
local function enObjetivo(lista_, ahora)
	local porNombre = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
	if not porNombre then return nil end
	for _, n in ipairs(lista_) do
		local ok, a = pcall(porNombre, "target", n, "HARMFUL|PLAYER")
		if ok and not M.Secreto(a) and type(a) == "table" then
			local fin = numero(a.expirationTime)
			local cargas = numero(a.applications)
			if fin and fin > 0 and fin - ahora < 2 then return "vence", cargas end
			return "si", cargas
		end
	end
	return nil
end

local function poder() return numero(M.Llamar(UnitPower, "player")) end

local TIPOS_PODER = { [0] = "mana", [1] = "ira", [3] = "energia" }
local function tipoPoder()
	local t = numero(M.Llamar(UnitPowerType, "player"))
	return t and TIPOS_PODER[t] or nil
end

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

-- La vida de una unidad en %, o nil si es secreta o no se puede leer.
local function vidaPct(unidad)
	local v, t = numero(M.Llamar(UnitHealth, unidad)), numero(M.Llamar(UnitHealthMax, unidad))
	if v and t and t > 0 then return v * 100 / t end
	return nil
end

-- true: tienes mascota; false: no; nil: no se sabe.
local function mascota()
	local hay = M.Legible(M.Llamar(UnitExists, "pet"))
	if hay == nil then return nil end
	if hay ~= true then return false end
	local muerta = M.Legible(M.Llamar(UnitIsDead, "pet"))
	if muerta == true then return false end
	return true
end

local function enGrupo()
	local si = M.Legible(M.Llamar(IsInGroup))
	if si ~= nil then return si and true or false end
	local n = numero(M.Llamar(GetNumGroupMembers))
	if n then return n > 0 end
	return nil
end

-- El enemigo lanza algo que se puede interrumpir: true, o nil si no se sabe.
local function objetivoLanza()
	local nombre, _, _, _, _, _, _, inmune = M.Llamar(UnitCastingInfo, "target")
	if not M.Secreto(nombre) and nombre == nil then
		local n2, _, _, _, _, _, inm2 = M.Llamar(UnitChannelInfo, "target")
		nombre, inmune = n2, inm2
	end
	if M.Secreto(nombre) or M.Secreto(inmune) or nombre == nil then return nil end
	if inmune == true then return false end
	return true
end

local function tipoObjetivo()
	local _, id = M.Llamar(UnitCreatureType, "target")
	return numero(id)
end

-- Varios enemigos peleando a la vista (por sus placas de nombre).
function P.Enemigos()
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then return 0 end
	local placas = M.Llamar(C_NamePlate.GetNamePlates)
	if type(placas) ~= "table" or M.Secreto(placas) then return 0 end
	local n = 0
	for _, p in ipairs(placas) do
		local u = type(p) == "table" and (rawget(p, "namePlateUnitToken") or (p.UnitFrame and p.UnitFrame.unit))
		if type(u) == "string" and not M.Secreto(u) then
			local ataca = M.Legible(M.Llamar(UnitCanAttack, "player", u))
			local pelea = M.Legible(M.Llamar(UnitAffectingCombat, u))
			if ataca == true and pelea == true then
				n = n + 1
				if n >= 9 then return n end
			end
		end
	end
	return n
end

function P.Varios() return P.Enemigos() >= VARIOS end

-- Lo pusiste en este objetivo hace poco (las veces que pide).
local function reciente(x, ahora)
	local d = x.def
	if not d.cada then return false end
	local c = lanzado[x.nombre]
	if not (c and c.serie == serie) then return false end
	return ahora - c.t < d.cada and c.veces >= (d.veces or 1)
end

-- El enemigo ya tiene tu efecto (no hace falta ponerlo otra vez).
local function puesto(x, ahora)
	local d = x.def
	local estado, cargas = enObjetivo(x.deb, ahora)
	if estado == "vence" then return false end
	if estado == "si" then
		if d.veces and cargas and cargas < d.veces then return false end
		return true
	end
	-- No está o no se puede leer: lo que lanzaste a este objetivo manda.
	return reciente(x, ahora)
end

-- El enemigo tiene el efecto que necesita esta habilidad (Inmolar para Conflagrar).
local function conDebuff(x, ahora)
	local cd = x.conDeb
	if enObjetivo({ cd.nombre }, ahora) then return true end
	local c = lanzado[cd.nombre]
	return c ~= nil and c.serie == serie and ahora - c.t < cd.cada
end

local function leer(c, k, fn)
	local v = c[k]
	if v == nil then
		v = fn()
		if v == nil then v = NADA end
		c[k] = v
	end
	if v == NADA then return nil end
	return v
end

local function cumple(x, c)
	local d = x.def
	if not d.sinObjetivo and not c.hay then return false end
	if d.soloCombate and not c.combate then return false end
	if d.fueraCombate and c.combate then return false end
	if d.aoe and c.enemigos < VARIOS then return false end
	if d.minEnemigos and c.enemigos < d.minEnemigos then return false end
	if d.solo and c.enemigos >= VARIOS then return false end
	if d.enGrupo ~= nil and leer(c, "grupo", enGrupo) ~= d.enGrupo then return false end
	if d.sinMascota and leer(c, "mascota", mascota) ~= false then return false end
	if d.conMascota and leer(c, "mascota", mascota) ~= true then return false end
	if d.vidaMascota then
		local v = leer(c, "vidaMascota", function() return vidaPct("pet") end)
		if not v or v > d.vidaMascota then return false end
	end
	if d.poder and leer(c, "tipoPoder", tipoPoder) ~= d.poder then return false end
	if d.minPoder or d.maxPoder then
		local p = leer(c, "poder", poder)
		if not p or (d.minPoder and p < d.minPoder) or (d.maxPoder and p > d.maxPoder) then return false end
	end
	if d.minPct or d.maxPct then
		local m = leer(c, "mana", manaPct)
		if not m or (d.minPct and m < d.minPct) or (d.maxPct and m > d.maxPct) then return false end
	end
	if d.minCombo or d.maxCombo then
		local cp = leer(c, "combo", combo)
		if not cp or (d.minCombo and cp < d.minCombo) or (d.maxCombo and cp > d.maxCombo) then return false end
	end
	if d.sinArma and leer(c, "arma", armaEncantada) ~= false then return false end
	if d.vidaPropia or d.minVidaPropia then
		local v = leer(c, "vida", function() return vidaPct("player") end)
		if not v or (d.vidaPropia and v > d.vidaPropia) or (d.minVidaPropia and v < d.minVidaPropia) then return false end
	end
	if d.bajoVida or d.sobreVida then
		local v = leer(c, "vidaObjetivo", function() return vidaPct("target") end)
		if d.bajoVida and (not v or v > d.bajoVida) then return false end
		if d.sobreVida and v and v < d.sobreVida then return false end
	end
	if d.corta and leer(c, "lanza", objetivoLanza) ~= true then return false end
	if d.tipoObjetivo then
		local t, vale = leer(c, "tipo", tipoObjetivo), false
		for _, x in ipairs(d.tipoObjetivo) do if t == x then vale = true break end end
		if not vale then return false end
	end
	if x.buffs and tieneEfecto(x.buffs) ~= false then return false end
	if x.con and tieneEfecto(x.con) ~= true then return false end
	if x.conDeb and not conDebuff(x, c.ahora) then return false end
	if x.deb and puesto(x, c.ahora) then return false end
	return true
end

---------------------------------------------------------------------------
-- La recarga
---------------------------------------------------------------------------
-- -> segundos que faltan (0: lista), y si tiene recarga propia (más que la global)
local function recarga(x, ahora)
	local nombre = x.nombre
	local guardadas = recargas()
	local vista = tonumber(guardadas[nombre])
	local propia = (vista ~= nil and vista > GCD) or x.def.recarga == true
	local fn = C_Spell and C_Spell.GetSpellCooldown
	if fn then
		local info = M.Llamar(fn, x.id)
		if type(info) == "table" and not M.Secreto(info) then
			local s, d = numero(info.startTime), numero(info.duration)
			if s and d then
				if d > GCD then
					if not vista or vista < d - 0.5 or vista > d + 0.5 then guardadas[nombre] = d end
					return max(0, s + d - ahora), true
				end
				return 0, propia
			end
			-- Tiempos secretos: isActive e isOnGCD nunca lo son.
			local activa, global = M.Legible(info.isActive), M.Legible(info.isOnGCD)
			if activa == true and global ~= true then
				local t = ultimo[nombre]
				if t and vista then
					local r = t + vista - ahora
					return r > 0 and r or 0.5, true
				end
				return INCIERTA, true
			end
			return 0, propia
		end
	end
	local s, d = A.Compat.GetSpellCooldown(x.id)
	if d > GCD then return max(0, s + d - ahora), true end
	return 0, propia
end

local function brilla(x)
	if brillan[x.nombre] then return true end
	local f = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
	if not f then return false end
	return M.Legible(M.Llamar(f, x.id)) == true
end

---------------------------------------------------------------------------
-- El porqué corto ("Golpe mortal: recarga lista")
---------------------------------------------------------------------------
local MOTIVOS = {
	brillo = L["%s: el juego la activó"],
	corta = L["%s: el enemigo está lanzando"],
	reaccion = L["%s: ya se puede usar"],
	remate = L["%s: el enemigo está por caer"],
	vida = L["%s: tu vida está baja"],
	vidaMascota = L["%s: tu mascota tiene poca vida"],
	mascota = L["%s: no tienes mascota"],
	efecto = L["%s: te falta el efecto"],
	proc = L["%s: aprovecha el efecto"],
	debuff = L["%s: ponla en el enemigo"],
	area = L["%s: %d enemigos cerca"],
	combo = L["%s: %d puntos de combo"],
	mana = L["%s: te queda poco maná"],
	falta = L["%s: te falta recurso"],
	sobra = L["%s: te sobra recurso"],
	recarga = L["%s: recarga lista"],
	principal = L["%s: tu habilidad de relleno"],
	espera = L["%s: espera tu recurso"],
	casi = L["%s: casi lista"],
}

local function motivo(x, c, propia, brillando)
	local d = x.def
	if brillando then return "brillo" end
	if d.corta then return "corta" end
	if d.reaccion then return "reaccion" end
	if d.remate or d.bajoVida then return "remate" end
	if d.vidaPropia then return "vida" end
	if d.vidaMascota then return "vidaMascota" end
	if d.sinMascota then return "mascota" end
	if x.buffs then return "efecto" end
	if x.con then return "proc" end
	if x.deb and not d.veces then return "debuff" end
	if d.aoe or d.minEnemigos then return "area", c.enemigos end
	if d.minCombo then return "combo", leer(c, "combo", combo) or d.minCombo end
	if d.maxPct then return "mana" end
	if d.maxPoder then return "falta" end
	if d.minPoder then return "sobra" end
	if propia then return "recarga" end
	return "principal"
end

-- El texto corto de una sugerencia (de Calcular).
function P.Corto(s)
	if type(s) ~= "table" or not s.nombre then return nil end
	local clave = s.motivo or "principal"
	if s.grupo == 2 then clave = "espera" elseif s.grupo == 3 then clave = "casi" end
	local t = MOTIVOS[clave] or MOTIVOS.principal
	if clave == "area" or clave == "combo" then return format(t, s.nombre, floor(tonumber(s.valor) or 0)), clave end
	return format(t, s.nombre), clave
end

---------------------------------------------------------------------------
-- Lo que lanzas y lo que brilla
---------------------------------------------------------------------------
function P.Lanzaste(spellID)
	if M.Secreto(spellID) or type(spellID) ~= "number" then return end
	local nombre = M.NombreHechizo(spellID)
	if not nombre then return end
	local ahora = GetTime()
	ultimo[nombre] = ahora
	local c = lanzado[nombre]
	if c and c.serie == serie and ahora - c.t < 40 then
		c.veces = c.veces + 1
		c.t = ahora
	else
		lanzado[nombre] = { t = ahora, veces = 1, serie = serie }
	end
end

function P.NuevoObjetivo() serie = serie + 1 end

-- El juego hizo brillar (o apagó) una habilidad tuya.
function P.Brillo(spellID, on)
	if M.Secreto(spellID) or type(spellID) ~= "number" then return end
	local nombre = M.NombreHechizo(spellID)
	if nombre then brillan[nombre] = on and true or nil end
end

---------------------------------------------------------------------------
-- Calcular
---------------------------------------------------------------------------
-- -> lista ordenada de { id, nombre, porque, motivo, valor, grupo (0 brilla,
--    1 lista, 2 espera recurso, 3 en recarga), resta, brilla }, si hay
--    varios enemigos y cuántos.
function P.Calcular(n)
	local out = {}
	local entradas = P.Lista()
	if #entradas == 0 then return out, false, 0 end
	local c = { ahora = GetTime(), hay = M.HayEnemigo(), combate = M.EnCombate(), enemigos = P.Enemigos() }
	local vistos, unicos = {}, {}
	local usableFn = C_Spell and C_Spell.IsSpellUsable
	for i, x in ipairs(entradas) do
		local d = x.def
		if not vistos[x.id] and not (d.unico and unicos[d.unico]) and cumple(x, c) then
			local usable, sinPoder = M.Llamar(usableFn, x.id)
			usable, sinPoder = M.Legible(usable), M.Legible(sinPoder)
			if usable == true or sinPoder == true then
				local alcance
				if c.hay and not d.sinObjetivo and C_Spell and C_Spell.IsSpellInRange then
					alcance = M.Legible(M.Llamar(C_Spell.IsSpellInRange, x.id, "target"))
				end
				if alcance ~= false then
					local resta, propia = recarga(x, c.ahora)
					local luz = usable == true and resta <= 0 and brilla(x)
					vistos[x.id] = true
					if d.unico then unicos[d.unico] = true end
					local mot, valor = motivo(x, c, propia, luz)
					out[#out + 1] = { id = x.id, nombre = x.nombre, porque = d.porque, orden = i, resta = resta,
						brilla = luz, motivo = mot, valor = valor,
						grupo = resta > 0 and 3 or (usable == true and (luz and 0 or 1) or 2) }
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
	return out, c.enemigos >= VARIOS, c.enemigos
end

-- Tus lanzamientos, solo los del jugador.
local ev = CreateFrame("Frame")
pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
ev:SetScript("OnEvent", function(_, _, _, _, spellID) K.Llamar(P.Lanzaste, spellID) end)
