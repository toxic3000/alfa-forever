-- Alfa - Combate: los datos del medidor de daño (toxic3000 / La Jauría). GPL-3.0.
--
-- Forever no tiene registro de combate para los addons, pero trae el
-- medidor oficial del juego (Blizzard_DamageMeter) y su API, C_DamageMeter:
--   * GetCombatSessionFromType(Current | Overall, tipo) y
--     GetCombatSessionFromID(id, tipo): las fuentes (tú, tu grupo o banda y
--     sus mascotas) ya ordenadas de mayor a menor, con su total, su valor por
--     segundo, su clase (nunca secreta) y si eres tú (nunca secreto).
--   * GetAvailableCombatSessions: las peleas guardadas (para "la anterior").
--   * Los eventos DAMAGE_METER_* avisan cuando cambian.
--   * En combate, los números (y en mazmorras los nombres) llegan secretos:
--     aquí no se suman, ni se comparan, ni se dividen. Se pasan tal cual a
--     StatusBar:SetValue, FontString:SetText y AbbreviateLargeNumbers, que los
--     aceptan. El orden de la lista sí se puede usar (lo da el juego).
--   * Anunciar en el chat solo con el clic del jugador, fuera de combate y
--     con todo legible: un número secreto no se puede escribir en el chat.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local D = {}
M.Medidor = D

local type, ipairs, pairs, pcall, floor, format, tostring = type, ipairs, pairs, pcall, math.floor, string.format, tostring

-- Los tipos que mostramos y su valor de Enum.DamageMeterType.
D.TIPOS = {
	{ clave = "dps", enum = "Dps", num = 1, texto = L["DPS"], porSeg = true },
	{ clave = "dano", enum = "DamageDone", num = 0, texto = L["Daño"] },
	{ clave = "cps", enum = "Hps", num = 3, texto = L["CPS"], porSeg = true, curacion = true },
	{ clave = "curacion", enum = "HealingDone", num = 2, texto = L["Curación"], curacion = true },
}
local porClave = {}
for _, t in ipairs(D.TIPOS) do porClave[t.clave] = t end
function D.Tipo(clave) return porClave[clave] or porClave.dps end

D.SESIONES = {
	{ clave = "actual", texto = L["Actual"] },
	{ clave = "anterior", texto = L["Anterior"] },
	{ clave = "todo", texto = L["Todo"] },
}

local function enumTipo(t)
	local E = Enum and Enum.DamageMeterType
	return E and type(E[t.enum]) == "number" and E[t.enum] or t.num
end

local function enumSesion(clave)
	local E = Enum and Enum.DamageMeterSessionType
	if clave == "todo" then return E and E.Overall or 0 end
	return E and E.Current or 1
end

---------------------------------------------------------------------------
-- ¿Está?
---------------------------------------------------------------------------
function D.Existe()
	return type(C_DamageMeter) == "table" and type(C_DamageMeter.GetCombatSessionFromType) == "function"
end

-- -> true | false, por qué
function D.Disponible()
	if not D.Existe() then return false, L["Tu cliente no trae el medidor de daño del juego."] end
	if type(C_DamageMeter.IsDamageMeterAvailable) == "function" then
		local si, porque = M.Llamar(C_DamageMeter.IsDamageMeterAvailable)
		si, porque = M.Legible(si), M.Legible(porque)
		if si == false then
			return false, (type(porque) == "string" and porque ~= "") and porque or L["El juego no permite usar el medidor ahora."]
		end
	end
	return true
end

-- El ajuste del juego "Activar el medidor de daño" (CVar damageMeterEnabled):
-- true, false, o nil si el cliente no lo tiene.
function D.Encendido()
	if not GetCVar then return nil end
	local v = M.Llamar(GetCVar, "damageMeterEnabled")
	if v == nil then return nil end
	return v == "1" or v == 1 or v == true
end

-- Con el clic del jugador y fuera de combate: enciende el registro del juego.
function D.Encender()
	N.FueraDeCombate(function()
		local set = (C_CVar and C_CVar.SetCVar) or SetCVar
		M.Llamar(set, "damageMeterEnabled", "1")
		D.Pedir()
		M.Avisar()
	end)
end

---------------------------------------------------------------------------
-- Sesiones: la de ahora, la anterior y todo
---------------------------------------------------------------------------
local idActual -- la pelea de ahora, por los eventos

-- Las peleas guardadas, de la más vieja a la más nueva: { id, nombre, dur }.
function D.Sesiones()
	local out = {}
	if not (D.Existe() and C_DamageMeter.GetAvailableCombatSessions) then return out end
	local lista = M.Llamar(C_DamageMeter.GetAvailableCombatSessions)
	if type(lista) ~= "table" or M.Secreto(lista) then return out end
	for _, s in ipairs(lista) do
		local id = type(s) == "table" and M.Legible(s.sessionID)
		if type(id) == "number" then
			local dur = M.Legible(s.durationSeconds)
			out[#out + 1] = { id = id, nombre = M.Legible(s.name), dur = type(dur) == "number" and dur or nil }
		end
	end
	table.sort(out, function(a, b) return a.id < b.id end)
	return out
end

-- La pelea de antes de la de ahora (o de la última): { id, dur } o nil.
function D.Anterior()
	local lista = D.Sesiones()
	if #lista == 0 then return nil end
	if idActual then
		for i = #lista, 1, -1 do
			if lista[i].id < idActual then return lista[i] end
		end
		return nil
	end
	return lista[#lista - 1]
end

local function duracion(clave)
	if clave == "anterior" then
		local s = D.Anterior()
		return s and s.dur
	end
	if not C_DamageMeter.GetSessionDurationSeconds then return nil end
	local v = M.Legible(M.Llamar(C_DamageMeter.GetSessionDurationSeconds, enumSesion(clave)))
	return type(v) == "number" and v or nil
end

---------------------------------------------------------------------------
-- Leer una sesión
---------------------------------------------------------------------------
-- -> {
--   ok, motivo (sin medidor), vacia (sin peleas), sinAnterior,
--   filas = { { pos, nombre, clase, yo, valor, porSeg, aparte } }  (el top y, si no
--           estás en él, tu fila al final), total, max, secreto, dur, cuantos
-- }
function D.Leer(sesion, tipo, filas)
	local t = D.Tipo(tipo)
	local r = { filas = {}, tipo = t, sesion = sesion }
	local ok, motivo = D.Disponible()
	if not ok then r.motivo = motivo return r end
	r.ok = true
	local s
	if sesion == "anterior" then
		local ant = D.Anterior()
		if not ant then r.sinAnterior = true r.vacia = true return r end
		s = M.Llamar(C_DamageMeter.GetCombatSessionFromID, ant.id, enumTipo(t))
	else
		s = M.Llamar(C_DamageMeter.GetCombatSessionFromType, enumSesion(sesion), enumTipo(t))
	end
	local fuentes = type(s) == "table" and not M.Secreto(s) and s.combatSources
	if type(fuentes) ~= "table" or M.Secreto(fuentes) then r.vacia = true return r end
	r.max, r.total = s.maxAmount, s.totalAmount
	r.secreto = M.Secreto(r.max) or M.Secreto(r.total)
	r.dur = duracion(sesion)
	local n = #fuentes
	r.cuantos = n
	if n == 0 then r.vacia = true return r end
	filas = filas or 10
	local yo
	for i = 1, n do
		local f = fuentes[i]
		if type(f) == "table" then
			local x = {
				pos = i, nombre = f.name, clase = M.Legible(f.classFilename), yo = M.Legible(f.isLocalPlayer) == true,
				valor = f.totalAmount, porSeg = f.amountPerSecond,
			}
			if M.Secreto(x.nombre) or M.Secreto(x.valor) or M.Secreto(x.porSeg) then r.secreto = true end
			if i <= filas then
				r.filas[#r.filas + 1] = x
				if x.yo then yo = true end
			elseif x.yo and not yo then
				x.aparte = true
				r.filas[#r.filas + 1] = x
				yo = true
			end
		end
	end
	return r
end

---------------------------------------------------------------------------
-- Números: el formato del juego (acepta secretos); sin él, el propio.
---------------------------------------------------------------------------
local function propio(v)
	if v >= 1e6 then return format("%.1f M", v / 1e6) end
	if v >= 1e4 then return format("%.1f k", v / 1e3) end
	return tostring(floor(v + 0.5))
end

-- -> texto (secreto si el número lo es): solo para SetText.
function D.Numero(v)
	if v == nil then return "" end
	if type(AbbreviateLargeNumbers) == "function" then
		local ok, s = pcall(AbbreviateLargeNumbers, v)
		if ok and (M.Secreto(s) or type(s) == "string") then return s end
	end
	if M.Secreto(v) or type(v) ~= "number" then return "" end
	return propio(v)
end

function D.Tiempo(seg)
	if type(seg) ~= "number" or seg <= 0 then return nil end
	seg = floor(seg + 0.5)
	return format("%d:%02d", floor(seg / 60), seg % 60)
end

-- "Banda", "Grupo" o "Solo tú".
function D.Contexto()
	if IsInRaid and IsInRaid() then return "banda", L["Banda"] end
	if IsInGroup and IsInGroup() then return "grupo", L["Grupo"] end
	return "solo", L["Solo tú"]
end

function D.Color(clase)
	if type(clase) ~= "string" or clase == "" then return K.Color("textoTenue") end
	local c = C_ClassColor and C_ClassColor.GetClassColor and M.Llamar(C_ClassColor.GetClassColor, clase)
	if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
	c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[clase]
	if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
	return K.Color("textoTenue")
end

---------------------------------------------------------------------------
-- Anunciar el top (solo con el clic del jugador)
---------------------------------------------------------------------------
local function canal()
	local instancia = LE_PARTY_CATEGORY_INSTANCE
	local casa = LE_PARTY_CATEGORY_HOME
	if IsInRaid and IsInRaid() then
		if instancia and IsInRaid(instancia) and not (casa and IsInRaid(casa)) then return "INSTANCE_CHAT" end
		return "RAID"
	end
	if IsInGroup and IsInGroup() then
		if instancia and IsInGroup(instancia) and not (casa and IsInGroup(casa)) then return "INSTANCE_CHAT" end
		return "PARTY"
	end
	return nil
end

-- -> true | false, por qué (para el botón: activo y su ayuda)
function D.PuedeAnunciar(sesion, tipo)
	if InCombatLockdown() or M.EnCombate() then return false, L["Se puede anunciar al salir de combate."] end
	if not canal() then return false, L["Únete a un grupo o banda para anunciar el top."] end
	local r = D.Leer(sesion, tipo, 1)
	if not r.ok then return false, r.motivo end
	if r.vacia then return false, L["Todavía no hay una pelea que anunciar."] end
	if r.secreto then return false, L["El juego todavía oculta los números o los nombres (pasa en combate y dentro de mazmorras). Inténtalo al salir."] end
	return true
end

function D.Anunciar(sesion, tipo)
	local puede, porque = D.PuedeAnunciar(sesion, tipo)
	if not puede then N.Imprimir(porque) return false end
	local cuantos = math.max(1, math.min(10, tonumber(M.Opt("anunciar")) or 5))
	local r = D.Leer(sesion, tipo, cuantos)
	local t = r.tipo
	local quien = (sesion == "anterior" and L["pelea anterior"]) or (sesion == "todo" and L["todas las peleas"]) or L["pelea actual"]
	local dur = D.Tiempo(r.dur)
	local lineas = { format(L["Alfa · Top %d de %s (%s%s)"], #r.filas, t.texto, quien, dur and (", " .. dur) or "") }
	for _, x in ipairs(r.filas) do
		if not x.aparte then
			local principal = t.porSeg and x.porSeg or x.valor
			local otro = t.porSeg and x.valor or x.porSeg
			lineas[#lineas + 1] = format("%d. %s  %s (%s)", x.pos, tostring(x.nombre or "?"), propio(principal or 0), propio(otro or 0))
		end
	end
	local enviar = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	local destino = canal()
	for _, l in ipairs(lineas) do M.Llamar(enviar, l, destino) end
	return true
end

-- Borra todas las peleas (también en la ventana del juego), con su diálogo.
function D.PedirReiniciar()
	K.Dialogo({
		titulo = L["¿Empezar el medidor de cero?"],
		texto = L["Se borran todas las peleas guardadas, también en la ventana del medidor del juego."],
		aceptar = L["Borrar peleas"], peligro = true,
		alAceptar = function()
			if D.Existe() and C_DamageMeter.ResetAllCombatSessions then M.Llamar(C_DamageMeter.ResetAllCombatSessions) end
			D.Borrada()
		end,
	})
end

---------------------------------------------------------------------------
-- Eventos: se juntan y se pinta como mucho dos veces por segundo.
---------------------------------------------------------------------------
local pendiente = false
function D.Pedir()
	if pendiente then return end
	pendiente = true
	A.After(0.5, function()
		pendiente = false
		if M.Ventana then K.Llamar(M.Ventana.Pintar) end
		if M.alMedidor then K.Llamar(M.alMedidor) end
	end)
end

function D.Actualizada(_, id)
	if not M.Secreto(id) and type(id) == "number" and id > 0 then idActual = id end
	D.Pedir()
end

function D.Nueva() D.Pedir() end

function D.Borrada()
	idActual = nil
	D.Pedir()
end
