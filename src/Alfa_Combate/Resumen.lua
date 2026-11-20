-- Alfa - Combate: el resumen de tu pelea (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.0. Al terminar una pelea (de combate.resumenMin segundos o más), una
-- tarjeta compacta: cuánto duró, tu daño y tu curación (con su valor por
-- segundo) y lo que más te pegó.
-- De dónde salen los números: el registro de combate (COMBAT_LOG_EVENT*) es
-- restringido para los addons en Forever (HasRestrictions, CombatLog
-- Documentation), así que se usa el medidor oficial del juego, C_DamageMeter
-- (como Medidor.lua), solo con tu fila (isLocalPlayer):
--   * DamageDone / HealingDone de la pelea actual: total y por segundo;
--   * DamageTaken con GetCombatSessionSourceFromType(…, tu GUID): el hechizo
--     que más daño te hizo y de quién.
-- Se lee fuera de combate (en combate llega secreto) y un segundo después de
-- terminar, para que el medidor se asiente. Lo secreto (nombres dentro de
-- mazmorras) no se lee: esa línea no sale. Sin medidor, solo la duración.
-- La tarjeta se va sola; si empieza otra pelea, se esconde al momento (nada
-- que atrape clics en combate). Su × la cierra. La última queda guardada
-- (por personaje) para verla otra vez desde la página o con
-- "/alfa combate pelea".

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local Rs = {}
M.Resumen = Rs

local type, ipairs, pcall, floor, max, min, format, tonumber, tostring = type, ipairs, pcall, math.floor, math.max, math.min, string.format, tonumber, tostring
local ESP = K.ESP
local ANCHO = 260
local DURA = 12      -- segundos a la vista
local ENTRE = 4      -- como mucho una cada tantos segundos

local inicio, ultimaVez
local f

local function numero(v)
	if M.Secreto(v) or type(v) ~= "number" then return nil end
	return v
end

local function enumTipo(nombre, num)
	local E = Enum and Enum.DamageMeterType
	return E and type(E[nombre]) == "number" and E[nombre] or num
end

local function actual()
	local E = Enum and Enum.DamageMeterSessionType
	return E and E.Current or 1
end

---------------------------------------------------------------------------
-- Leer tu pelea
---------------------------------------------------------------------------
-- Tu fila de un tipo: total, por segundo (legibles) o nil.
local function tuyo(tipo, num)
	local s = M.Llamar(C_DamageMeter.GetCombatSessionFromType, actual(), enumTipo(tipo, num))
	local fuentes = type(s) == "table" and not M.Secreto(s) and s.combatSources
	if type(fuentes) ~= "table" or M.Secreto(fuentes) then return nil end
	for _, x in ipairs(fuentes) do
		if type(x) == "table" and M.Legible(x.isLocalPlayer) == true then
			return numero(x.totalAmount), numero(x.amountPerSecond)
		end
	end
	return nil
end

-- Lo que más te pegó: { nombre, quien, cuanto } o nil.
local function golpeMayor()
	local fn = C_DamageMeter.GetCombatSessionSourceFromType
	if type(fn) ~= "function" then return nil end
	local guid = M.Legible(M.Llamar(UnitGUID, "player"))
	if type(guid) ~= "string" then return nil end
	local s = M.Llamar(fn, actual(), enumTipo("DamageTaken", 7), guid)
	local lista = type(s) == "table" and not M.Secreto(s) and s.combatSpells
	if type(lista) ~= "table" or M.Secreto(lista) then return nil end
	local mejor
	for _, x in ipairs(lista) do
		local v = type(x) == "table" and numero(x.totalAmount)
		if v and v > 0 and (not mejor or v > mejor.cuanto) then
			local id = numero(x.spellID)
			local nombre = id and id > 0 and M.NombreHechizo(id) or L["Golpes cuerpo a cuerpo"]
			local quien = M.Legible(x.creatureName)
			mejor = { cuanto = v, nombre = nombre, id = id, quien = type(quien) == "string" and quien ~= "" and quien or nil }
		end
	end
	return mejor
end

-- -> el resumen { dur, dano, dps, cura, cps, golpe } (lo que se pudo leer)
function Rs.Leer(dur)
	local r = { dur = dur }
	local D = M.Medidor
	if D and D.Existe() and D.Disponible() then
		local md = C_DamageMeter.GetSessionDurationSeconds and numero(M.Llamar(C_DamageMeter.GetSessionDurationSeconds, actual()))
		if md and md > 0 then r.dur = md end
		r.dano, r.dps = tuyo("DamageDone", 0)
		r.cura, r.cps = tuyo("HealingDone", 2)
		r.golpe = golpeMayor()
		local d = r.dur or 0
		if r.dano and not r.dps and d > 0 then r.dps = r.dano / d end
		if r.cura and not r.cps and d > 0 then r.cps = r.cura / d end
	end
	return r
end

---------------------------------------------------------------------------
-- La tarjeta
---------------------------------------------------------------------------
local function num(v)
	if M.Medidor and M.Medidor.Numero then return M.Medidor.Numero(v) end
	return tostring(floor((v or 0) + 0.5))
end

local function fila(padre)
	local x = {}
	x.Nombre = K.Texto(padre, "pequeno", "textoSuave")
	x.Valor = K.Texto(padre, "numero", "texto")
	x.Valor:SetJustifyH("RIGHT")
	return x
end

local function crear()
	if f then return f end
	f = M.Marco("Resumen", L["Resumen de tu pelea"], ANCHO, 100, { "RIGHT", "RIGHT", -60, 150 })
	f.Fondo = CreateFrame("Frame", nil, f)
	f.Fondo:SetAllPoints(f)
	f.Fondo.caja = K.Caja(f.Fondo, { fondo = "fondo", alfaFondo = 0.9, borde = "linea", corte = K.CORTE.control })
	f.Titulo = K.Texto(f.Fondo, "mayus", "acento")
	f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.m, -ESP.s - 2)
	K.Escribir(f.Titulo, K.Mayus and K.Mayus(L["Tu pelea"]) or L["Tu pelea"]:upper())
	f.Dura = K.Texto(f.Fondo, "numero", "textoSuave")
	f.Dura:SetPoint("TOPRIGHT", f, "TOPRIGHT", -ESP.m - 20, -ESP.s)
	f.Cerrar = K.BotonIcono(f.Fondo, "ic-cerrar", function() f:Hide() end, { tam = 16, ayuda = L["Cerrar"] })
	f.Cerrar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	f.Dano, f.Cura = fila(f.Fondo), fila(f.Fondo)
	f.Golpe = K.Texto(f.Fondo, "nota", "textoSuave")
	f:SetScript("OnHide", function(self) self.alfaHasta = nil end)
	-- 1.3.6: se arrastra directo (fuera de combate), sin «Mover marcos», y
	-- recuerda dónde lo dejas (el OnDragStop de M.Marco lo guarda). Al pasar el
	-- ratón dice que se puede mover. Solo sale fuera de combate (Rs.Empieza lo
	-- quita al empezar una pelea), así que no atrapa clics peleando.
	f:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
	f:SetScript("OnEnter", function(self)
		if not GameTooltip or M.Desbloqueado() then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L["Tu pelea"], 1, 1, 1)
		GameTooltip:AddLine(L["Arrástralo para moverlo."], nil, nil, nil, true)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	f:Hide()
	return f
end

-- 1.3.6: de fábrica salía pegado al borde derecho, donde van las barras de
-- acción de la derecha, y quedaba debajo de ellas. Si nunca lo moviste, se
-- busca un lugar que no tape ninguna barra a la vista: a la izquierda de las
-- de la derecha, o más arriba. Lo que tú acomodas siempre se respeta.
local BARRAS = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
	"MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar", "PossessActionBar" }

-- Los rectángulos de las barras a la vista, en píxeles de pantalla.
local function barrasALaVista()
	local out = {}
	for _, n in ipairs(BARRAS) do
		local b = rawget(_G, n)
		if type(b) == "table" and b.IsVisible and b:IsVisible() and b.GetRect then
			local ok, l, bo, w, h = pcall(b.GetRect, b)
			local e = b.GetEffectiveScale and b:GetEffectiveScale() or 1
			if ok and type(l) == "number" and type(w) == "number" and w > 0 and h > 0 then
				out[#out + 1] = { l * e, bo * e, (l + w) * e, (bo + h) * e }
			end
		end
	end
	return out
end

local function tapa(rects)
	local ok, l, bo, w, h = pcall(f.GetRect, f)
	if not (ok and type(l) == "number" and type(w) == "number") then return false end
	local e = f.GetEffectiveScale and f:GetEffectiveScale() or 1
	local x1, y1, x2, y2 = l * e, bo * e, (l + w) * e, (bo + h) * e
	for _, r in ipairs(rects) do
		if x1 < r[3] and x2 > r[1] and y1 < r[4] and y2 > r[2] then return r end
	end
	return false
end

-- Prueba lugares hasta uno libre (o deja el de fábrica si todos tapan algo).
local LUGARES = { { "RIGHT", "RIGHT", -60, 150 }, { "RIGHT", "RIGHT", -150, 150 }, { "RIGHT", "RIGHT", -240, 150 },
	{ "RIGHT", "RIGHT", -330, 150 }, { "RIGHT", "RIGHT", -150, 330 }, { "CENTER", "CENTER", 320, 160 } }
function Rs.Colocar()
	if not f or (M.Posicion and M.Posicion("Resumen")) then return end
	local rects = barrasALaVista()
	if #rects == 0 then return end
	for _, p in ipairs(LUGARES) do
		f:ClearAllPoints()
		f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
		if not tapa(rects) then return p end
	end
	f:ClearAllPoints()
	f:SetPoint(LUGARES[1][1], UIParent, LUGARES[1][2], LUGARES[1][3], LUGARES[1][4])
end

local function ponerFila(x, nombre, valor, y)
	if not valor then x.Nombre:Hide() x.Valor:Hide() return y end
	K.Escribir(x.Nombre, nombre)
	x.Valor:SetText(valor)
	x.Nombre:ClearAllPoints()
	x.Nombre:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.m, -y)
	x.Valor:ClearAllPoints()
	x.Valor:SetPoint("TOPRIGHT", f, "TOPRIGHT", -ESP.m, -y)
	x.Nombre:Show()
	x.Valor:Show()
	return y + 18
end

-- El texto de lo que más te pegó (o nil).
function Rs.TextoGolpe(g)
	if type(g) ~= "table" or not g.nombre then return nil end
	if g.quien then return format(L["Lo que más te pegó: %s, de %s (%s)."], g.nombre, g.quien, num(g.cuanto)) end
	return format(L["Lo que más te pegó: %s (%s)."], g.nombre, num(g.cuanto))
end

function Rs.Pintar(r)
	crear()
	f.Dura:SetText(M.Medidor and M.Medidor.Tiempo(r.dur) or "")
	local y = ESP.s + 2 + K.Tamano("mayus") + ESP.s + 2
	y = ponerFila(f.Dano, L["Tu daño"], r.dano and r.dano > 0 and format(L["%s (%s por s)"], num(r.dano), num(r.dps or 0)) or nil, y)
	y = ponerFila(f.Cura, L["Tu curación"], r.cura and r.cura > 0 and format(L["%s (%s por s)"], num(r.cura), num(r.cps or 0)) or nil, y)
	local g = Rs.TextoGolpe(r.golpe)
	if not (r.dano and r.dano > 0) and not (r.cura and r.cura > 0) and not g then
		g = L["El medidor del juego no tiene números de esta pelea."]
	end
	if g then
		K.Escribir(f.Golpe, g)
		f.Golpe:ClearAllPoints()
		f.Golpe:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.m, -(y + 2))
		y = y + 2 + K.Parrafo(f.Golpe, ANCHO - 2 * ESP.m, 3) + 2
		f.Golpe:Show()
	else
		f.Golpe:Hide()
	end
	f:SetHeight(max(48, y + ESP.s))
	-- 1.3.6: que se pueda arrastrar (M.Desbloquear le quita el ratón al fijar
	-- los marcos) y, si nunca lo moviste, que no tape tus barras.
	f:EnableMouse(true)
	f:Show()
	Rs.Colocar()
	local hasta = GetTime() + DURA
	f.alfaHasta = hasta
	A.After(DURA, function() if f and f.alfaHasta == hasta and not M.Desbloqueado() then f:Hide() end end)
end

---------------------------------------------------------------------------
-- La pelea
---------------------------------------------------------------------------
function Rs.Empieza()
	inicio = GetTime()
	if f and f:IsShown() and not M.Desbloqueado() then f:Hide() end
end

function Rs.Termina()
	if not inicio then return end
	local dur = GetTime() - inicio
	inicio = nil
	if not M.Opt("resumen") then return end
	-- 1.3.2: yendo solo en el mundo, solo las peleas largas (resumenMinSolo).
	local enGrupo = M.EnGrupo()
	local minimo = max(0, tonumber(M.Opt(enGrupo and "resumenMin" or "resumenMinSolo")) or (enGrupo and 10 or 30))
	if dur < minimo then return end
	A.After(1, function()
		if M.EnCombate() then return end -- ya empezó otra: no se lee (llegaría secreto)
		local ahora = GetTime()
		if ultimaVez and ahora - ultimaVez < ENTRE then return end
		local r = Rs.Leer(dur)
		local hay = (r.dano and r.dano > 0) or (r.cura and r.cura > 0) or r.golpe
		if not hay and M.Medidor and M.Medidor.Existe() then return end
		ultimaVez = ahora
		local d = N.DatosPersonaje(M.ID)
		d.ultimaPelea = { dur = r.dur, dano = r.dano, dps = r.dps, cura = r.cura, cps = r.cps,
			golpe = r.golpe and { nombre = r.golpe.nombre, quien = r.golpe.quien, cuanto = r.golpe.cuanto } or nil,
			cuando = time and time() or nil }
		Rs.Pintar(r)
		M.Avisar()
	end)
end

function Rs.Ultima()
	local u = N.DatosPersonaje(M.ID).ultimaPelea
	return type(u) == "table" and u or nil
end

-- Desde la página o "/alfa combate pelea": la última otra vez (fuera de combate).
function Rs.VerDeNuevo()
	if M.EnCombate() then N.Imprimir(L["El resumen se ve al salir de combate."]) return false end
	local u = Rs.Ultima()
	if not u then N.Imprimir(L["Todavía no hay una pelea que resumir."]) return false end
	Rs.Pintar(u)
	return true
end

function Rs.Ver()
	if not M.Opt("resumen") then
		if f then f:Hide() end
		return
	end
	if M.Desbloqueado() then
		Rs.Pintar(Rs.Ultima() or { dur = 42, dano = 12500, dps = 298, golpe = { nombre = L["Golpes cuerpo a cuerpo"], cuanto = 1800 } })
	elseif f and f:IsShown() and not f.alfaHasta then
		f:Hide()
	end
end

A.OnLogin(function()
	M.Ensenar({ id = "combate.resumen", icono = "ic-lista",
		pregunta = L["¿Cómo me fue en la pelea?"],
		respuesta = L["Al terminar una pelea, Alfa te deja una tarjeta pequeña con cuánto duró, tu daño y tu curación por segundo y lo que más te pegó. Usa el medidor oficial del juego y solo cuenta lo tuyo."] })
end)
