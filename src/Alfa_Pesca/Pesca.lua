-- Alfa - Pesca (toxic3000 / La Jauría). GPL-3.0.
--
-- El modo pesca: una sola tecla lo hace todo y la misma tecla recoge.
--
-- Cómo funciona (todo con una tecla o un clic del jugador, nunca solo):
--   * AlfaPescaBoton es un botón seguro con una macro que cambia según lo
--     que falta (Equipo.lua, M.Plan): ponerte el equipo de pesca, poner el
--     cebo o lanzar ("/cast [nocombat,noflying] Pesca"). Cada pulsación hace
--     un paso. La macro se rehace fuera de combate cuando cambia tu equipo,
--     tus bolsas o el cebo de la caña.
--   * Con el modo pesca abierto (el botón de la barra, /alfa pesca, su tecla
--     o al ponerte una caña), tu tecla del modo (Espacio por omisión) pulsa
--     ese botón con SetOverrideBindingClick; Mayús+Espacio sigue saltando y
--     Ctrl+Espacio relanza (AlfaPescaRelanzar: suelta el lanzamiento y lanza
--     otra vez, sin preparar nada). Al moverte, Espacio vuelve a saltar.
--   * La tecla fija de los atajos del juego (Alfa > Pescar: lanzar y
--     recoger) sigue funcionando también fuera del modo.
--   * Al empezar el canal de Pesca, fuera de combate, esas teclas pasan a
--     INTERACTTARGET con SetOverrideBinding y la interacción suave (CVars
--     SoftTargetInteract*) apunta al corcho: pulsarlas otra vez lo recoge.
--   * Sonido para oír el chapoteo, nombres ocultos y la interfaz oculta (si
--     lo pides) mientras pescas; todo vuelve a como estaba al cerrar el modo,
--     unos segundos después de pescar sin el modo, al entrar en combate, al
--     recargar y al salir. Los valores originales se guardan en disco
--     mientras están cambiados: si el juego se cierra de golpe, se restauran.
--   * Nunca en combate: al empezar uno, todo se suelta y tus teclas vuelven a
--     ser las de siempre; al terminar, el modo vuelve si seguía abierto.
--   * Si otro addon de pesca está cargado (Compat.lua), Alfa no liga nada ni
--     cambia ajustes y avisa una vez.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID
local Eq = M.Eq
local R = M.R

local ACCION = "CLICK AlfaPescaBoton:LeftButton"
local ACCION_RELANZAR = "CLICK AlfaPescaRelanzar:LeftButton"
M.ACCION, M.ACCION_RELANZAR = ACCION, ACCION_RELANZAR
local DOT_TEXTO = " \194\183 "

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring

-- Los valores por omisión. Las claves de antes siguen igual (activo,
-- autobotin, ocultarNombres, sonido, volumen, dobleClic, velocidad, montado,
-- relanzar, iconoCorcho).
M.AJUSTES = {
	activo = true,           -- interruptor general
	-- Tecla y modo pesca
	tecla = "SPACE",         -- la tecla del modo pesca ("" sin tecla)
	teclaRelanzar = "CTRL-SPACE",
	saltoMayus = true,       -- con la tecla en Espacio, Mayús+Espacio salta
	saltarAlMoverse = true,  -- al moverte, la tecla del modo vuelve a su acción de siempre
	abrirConCana = true,     -- al ponerte una caña se abre el modo pesca
	cerrarAlMontar = true,   -- al montar se cierra el modo pesca
	-- Equipo y cebos
	prepararEquipo = true,   -- la tecla te pone la mejor caña y el equipo de pesca
	prepararCebo = true,     -- la tecla pone el mejor cebo (o el preferido)
	ceboPreferido = 0,       -- 0: el de más bonificación
	restaurarEquipo = true,  -- al cerrar el modo vuelve tu equipo normal
	excluir = {},            -- grupos de ranuras que nunca se cambian
	-- La barra
	barra = true, barraVertical = false, barraEscala = 1, barraPlegar = true,
	vistaMinima = true,      -- al lanzar, una barra fina con el tiempo
	resumen = true,          -- el aviso con lo que sacaste
	metasVentana = true,     -- la ventana de metas cuando tienes alguna
	-- Mientras pescas
	autobotin = true,
	ocultarNombres = true,
	iconoCorcho = true,
	ocultarUI = false, uiMinimapa = true, uiChat = true,
	-- Sonido y avisos
	sonido = true, volumen = 1, musica = 0, ambiente = 0, sonidoFondo = true,
	alertas = true, alertaCaptura = true, alertaEscape = true, alertaInactivo = true,
	inactivoSeg = 25, alertaSonido = "suave",
	-- Doble clic derecho
	dobleClic = false, velocidad = 0.2, montado = false, relanzar = true,
	-- 1.3.7
	avisoPelear = true,      -- al entrar en combate con la caña, un aviso con cómo volver a tus armas
	resumenCerrar = true,    -- al cerrar el modo, lo que pescaste mientras estuvo abierto
	consejos = true,         -- se acabó el cebo, llegaste al tope de tu rango
}

_G["BINDING_NAME_" .. ACCION] = L["Pescar: lanzar y recoger"]
_G["BINDING_NAME_" .. ACCION_RELANZAR] = L["Pescar: volver a lanzar"]
BINDING_NAME_ALFA_PESCA_MODO = L["Abrir o cerrar el modo pesca"]

local GRACIA = 6        -- segundos con sonido y nombres de pesca tras sacar el corcho (sin el modo)
local ESPERA_CLIC = 0.5 -- un doble clic no vuelve a lanzar antes de esto
local CLIC_MIN = 0.04   -- dos clics más juntos que esto son un rebote del ratón

-- Hechizos de Pesca (el que se aprende y el canal) de las versiones del juego;
-- si Forever usa otro, se reconoce por el nombre.
local PESCA = {
	[7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true, [51294] = true,
	[88868] = true, [110410] = true, [131474] = true, [131476] = true, [131490] = true, [158743] = true,
}
local RANGOS = { 18248, 7732, 7731, 7620 }

local E = {
	otro = false,           -- otro addon de pesca cargado (Compat.lua): Alfa en pausa
	modo = false,           -- el modo pesca abierto
	modoPuesto = false,     -- sus teclas están puestas ahora
	respaldo = nil,         -- CVar -> valor original, mientras están cambiados
	puestos = {},           -- cvar en minúsculas -> { nombre, valor } que puso Alfa
	teclaPuesta = false,    -- la tecla está en INTERACTTARGET
	clicArmado = nil,       -- "lanzar" | "recoger": BUTTON2 tomado por el doble clic
	canal = nil,            -- GetTime() al empezar el canal de pesca
	canalFin = nil,         -- GetTime() en que termina el canal
	ultimaPesca = nil,      -- GetTime() al terminar el último canal
	ventana = nil,          -- botín de pesca abierto: ranura -> objeto
	tomados = nil,          -- lo tomado de esa ventana
	banco = nil,            -- el banco de peces de esa ventana
	turno = 0,              -- cancela restauraciones pendientes
	clicPrevio = nil,
	ultimoLanzamiento = 0,
	fase = nil,             -- lo que dice la barra: listo, lanzado, corcho, lejos, capturado, escapado, inactivo
	ultimo = nil,           -- la última captura (para la barra)
	plan = nil,             -- el paso de la tecla (Equipo.lua)
	ui = nil,               -- la interfaz oculta: { minimapa, chat }
	prepararAlSalir = false,    -- rehacer la macro ya está encolado para el fin del combate
	restaurarPendiente = false, -- devolver las CVar ya está encolado para el fin del combate
}
M.E = E

local function opt(k) return N.Get(ID, k) end
M.Opt = opt

local function legible(v)
	if v == nil then return false end
	return not (issecretvalue and issecretvalue(v))
end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
M.EnCombate = enCombate

local function habilitado() return opt("activo") and not E.otro and true or false end
M.Habilitado = habilitado

---------------------------------------------------------------------------
-- Datos del jugador: Pesca, la caña, el canal, las teclas
---------------------------------------------------------------------------

function M.NombrePesca()
	local S = C_Spell
	if S and S.GetSpellName then
		local ok, n = pcall(S.GetSpellName, 7620)
		if ok and type(n) == "string" and n ~= "" and legible(n) then return n end
	end
	return N.espanol and "Pesca" or "Fishing"
end

local function esPesca(spell)
	if not legible(spell) or type(spell) ~= "number" then return false end
	if PESCA[spell] then return true end
	local S = C_Spell
	if S and S.GetSpellName then
		local ok, n = pcall(S.GetSpellName, spell)
		if ok and legible(n) and n == M.NombrePesca() then return true end
	end
	return false
end

-- -> rango, máximo, bonificación (cebo o equipo); nil si no sabe Pesca.
function M.Habilidad()
	local S = C_SkillInfo
	if S and S.GetSkillLineInfoByID then
		local ok, info = pcall(S.GetSkillLineInfoByID, M.SKILL)
		if ok and type(info) == "table" then
			local r, mx = tonumber(info.rank), tonumber(info.maxRank)
			if r and mx and legible(r) and not (r == 0 and mx == 0) then
				return r, mx, tonumber(info.modifier) or 0
			end
		end
	end
	local C = A.Compat
	if C and C.GetSkillRank then
		local ok, r, mx = pcall(C.GetSkillRank, M.SKILL)
		if ok and type(r) == "number" then return r, tonumber(mx) or 0, 0 end
	end
	return nil
end

function M.SabePesca()
	if M.Habilidad() then return true end
	local B, C, puede = C_SpellBook, A.Compat, false
	for _, id in ipairs(RANGOS) do
		if B and B.IsSpellKnown then
			local ok, si = pcall(B.IsSpellKnown, id)
			if ok and si == true then return true end
			if ok and si == false then puede = true end
		end
		if C and C.IsPlayerSpell then
			local ok, si = pcall(C.IsPlayerSpell, id)
			if ok and si == true then return true end
		end
	end
	if puede and C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then return false end
	return nil
end

function M.TieneCana()
	if not (GetInventoryItemID and C_Item and C_Item.GetItemInfoInstant) then return true end
	return Eq.CanaPuesta() and true or false
end

function M.Pescando()
	if not UnitChannelInfo then return false end
	local ok, nombre, _, _, _, _, _, _, spell = pcall(UnitChannelInfo, "player")
	if not ok or nombre == nil then return false end
	if legible(spell) and type(spell) == "number" and PESCA[spell] then return true end
	return legible(nombre) and nombre == M.NombrePesca()
end

-- Las teclas fijas que el jugador dio a "Pescar: lanzar y recoger".
function M.Teclas()
	local t = {}
	if not GetBindingKey then return t end
	local ok, k1, k2 = pcall(GetBindingKey, ACCION)
	if not ok then return t end
	if type(k1) == "string" and k1 ~= "" then t[#t + 1] = k1 end
	if type(k2) == "string" and k2 ~= "" then t[#t + 1] = k2 end
	return t
end

-- Nombres propios de las teclas comunes, en el idioma de Alfa (que puede no ser
-- el del juego). Lo demás lo nombra el juego.
local NOMBRES = {
	SPACE = "Espacio", SHIFT = "Mayús", CTRL = "Ctrl", ALT = "Alt",
	BUTTON3 = "Botón central", BUTTON4 = "Botón 4 del ratón", BUTTON5 = "Botón 5 del ratón",
	MOUSEWHEELUP = "Rueda arriba", MOUSEWHEELDOWN = "Rueda abajo",
}

function M.TextoTecla(k)
	if type(k) ~= "string" or k == "" then return nil end
	local partes, todas = {}, true
	for p in k:gmatch("[^-]+") do
		if NOMBRES[p] then partes[#partes + 1] = L[NOMBRES[p]]
		elseif #p == 1 then partes[#partes + 1] = p
		else todas = false break end
	end
	if todas and #partes > 0 then return table.concat(partes, "+") end
	if GetBindingText then
		local ok, t = pcall(GetBindingText, k)
		if ok and type(t) == "string" and t ~= "" then return t end
	end
	return k
end

-- La tecla con la que pescas ahora (la del modo si está abierto, si no la fija).
function M.TeclaAhora()
	local k = opt("tecla")
	if E.modo and type(k) == "string" and k ~= "" then return M.TextoTecla(k) end
	local t = M.Teclas()
	return t[1] and M.TextoTecla(t[1]) or nil
end

local function numBotin()
	if not GetNumLootItems then return 0 end
	local ok, n = pcall(GetNumLootItems)
	return ok and tonumber(n) or 0
end

function M.MapaJugador()
	local C = C_Map
	if not (C and C.GetBestMapForUnit) then return nil end
	local ok, m = pcall(C.GetBestMapForUnit, "player")
	return ok and tonumber(m) or nil
end

---------------------------------------------------------------------------
-- Botones seguros (sin padre ni tamaño: solo los pulsa tu tecla o tu clic)
---------------------------------------------------------------------------
local boton = CreateFrame("Button", "AlfaPescaBoton", nil, "SecureActionButtonTemplate")
boton:RegisterForClicks("AnyDown", "AnyUp")
local relanzar = CreateFrame("Button", "AlfaPescaRelanzar", nil, "SecureActionButtonTemplate")
relanzar:RegisterForClicks("AnyDown", "AnyUp")
local clic = CreateFrame("Button", "AlfaPescaClic", nil, "SecureActionButtonTemplate")
clic:RegisterForClicks("AnyDown", "AnyUp")
-- Dueños de las teclas del modo pesca y de las de recoger.
local modoTeclas = CreateFrame("Frame")

local function prepararBotones()
	local nombre = M.NombrePesca()
	local si = habilitado()
	local lanzar = "/cast [nocombat,noflying] " .. nombre
	local macro = lanzar
	E.plan = nil
	if si and (E.modo or #M.Teclas() > 0) then
		local ok, p = pcall(Eq.Plan)
		if ok and p then
			E.plan = p
			macro = Eq.Macro(p, nombre)
		end
	end
	boton:SetAttribute("useOnKeyDown", true)
	boton:SetAttribute("type", si and "macro" or nil)
	boton:SetAttribute("macrotext", si and macro or nil)
	relanzar:SetAttribute("useOnKeyDown", true)
	relanzar:SetAttribute("type", si and "macro" or nil)
	relanzar:SetAttribute("macrotext", si and ("/stopcasting\n" .. lanzar) or nil)
	clic:SetAttribute("useOnKeyDown", false)
	clic:SetAttribute("type", si and "macro" or nil)
	clic:SetAttribute("macrotext", si and lanzar or nil)
end

-- Rehace la macro poco después (cambios seguidos de equipo y bolsas: una vez).
local preparando = false
function M.PrepararBotones()
	if preparando then return end
	preparando = true
	A.After(0.2, function()
		preparando = false
		-- En combate se encola una sola vez, aunque se pida muchas veces.
		if E.prepararAlSalir then return end
		E.prepararAlSalir = true
		N.FueraDeCombate(function()
			E.prepararAlSalir = false
			prepararBotones()
			M.Avisar("plan")
		end)
	end)
end

boton:SetScript("PostClick", function(_, _, abajo)
	if abajo == false then return end
	if E.plan and E.plan.fase ~= "lanzar" then
		M.PrepararBotones()
		-- 1.3.7: una pieza que no entra no atora la tecla: un momento después
		-- se rehace la macro sin ella y la siguiente pulsación lanza.
		if E.plan.fase == "equipo" then
			Eq.Intentado(E.plan.equipar)
			A.After(1.2, M.PrepararBotones)
		end
	end
end)

---------------------------------------------------------------------------
-- Teclas: las del modo pesca y las de recoger
---------------------------------------------------------------------------
local function firma(teclas) return table.concat(teclas, "\n") end

-- Las teclas que recogen mientras el corcho está en el agua.
local function teclasDeRecoger()
	local t = M.Teclas()
	local k = opt("tecla")
	if E.modoPuesto and type(k) == "string" and k ~= "" then
		local ya = false
		for _, x in ipairs(t) do if x == k then ya = true end end
		if not ya then t[#t + 1] = k end
	end
	return t
end

local function ponerTecla()
	if enCombate() or not (SetOverrideBinding and ClearOverrideBindings) then return end
	local teclas = teclasDeRecoger()
	E.firma = firma(teclas)
	ClearOverrideBindings(boton)
	for i = 1, #teclas do SetOverrideBinding(boton, true, teclas[i], "INTERACTTARGET") end
	E.teclaPuesta = #teclas > 0
end

local function quitarTecla()
	if not E.teclaPuesta then return end
	N.FueraDeCombate(function()
		E.teclaPuesta, E.firma = false, nil
		if ClearOverrideBindings then ClearOverrideBindings(boton) end
	end)
end

local function ponerTeclasModo()
	if enCombate() or not (SetOverrideBindingClick and ClearOverrideBindings) then return end
	ClearOverrideBindings(modoTeclas)
	E.modoPuesto = false
	if not (E.modo and habilitado()) then return end
	local k, kr = opt("tecla"), opt("teclaRelanzar")
	if type(k) == "string" and k ~= "" then
		SetOverrideBindingClick(modoTeclas, false, k, "AlfaPescaBoton", "LeftButton")
		if k == "SPACE" and opt("saltoMayus") and SetOverrideBinding then SetOverrideBinding(modoTeclas, false, "SHIFT-SPACE", "JUMP") end
		E.modoPuesto = true
	end
	if type(kr) == "string" and kr ~= "" and kr ~= k then
		SetOverrideBindingClick(modoTeclas, false, kr, "AlfaPescaRelanzar", "LeftButton")
	end
end

local function quitarTeclasModo()
	N.FueraDeCombate(function()
		if ClearOverrideBindings then ClearOverrideBindings(modoTeclas) end
		E.modoPuesto = false
	end)
end

-- modo "lanzar": el clic derecho pulsa AlfaPescaClic; "recoger": INTERACTTARGET.
local function armarClic(modo)
	if enCombate() or not (ClearOverrideBindings and SetOverrideBinding and SetOverrideBindingClick) then return false end
	ClearOverrideBindings(clic)
	if modo == "lanzar" then
		SetOverrideBindingClick(clic, true, "BUTTON2", "AlfaPescaClic", "LeftButton")
	else
		SetOverrideBinding(clic, true, "BUTTON2", "INTERACTTARGET")
	end
	E.clicArmado = modo
	return true
end

function M.SoltarClic()
	if not E.clicArmado then return end
	N.FueraDeCombate(function()
		if ClearOverrideBindings then ClearOverrideBindings(clic) end
		E.clicArmado = nil
	end)
end

clic:SetScript("PostClick", function(_, _, abajo)
	if abajo then return end
	if MouselookStop then pcall(MouselookStop) end
	M.SoltarClic()
end)

---------------------------------------------------------------------------
-- CVars: sonido, nombres e interacción mientras pescas
---------------------------------------------------------------------------
local function leerCVar(nombre)
	local ok, v
	if C_CVar and C_CVar.GetCVar then
		ok, v = pcall(C_CVar.GetCVar, nombre)
	elseif GetCVar then
		ok, v = pcall(GetCVar, nombre)
	end
	if not ok then return nil end
	if type(v) == "number" then return tostring(v) end
	return type(v) == "string" and v or nil
end

local escribiendo = false
local function ponerCVar(nombre, valor)
	local ok
	escribiendo = true
	if C_CVar and C_CVar.SetCVar then
		ok = pcall(C_CVar.SetCVar, nombre, tostring(valor))
	elseif SetCVar then
		ok = pcall(SetCVar, nombre, tostring(valor))
	end
	escribiendo = false
	return ok and true or false
end

local function igual(a, b)
	if a == b then return true end
	local x, y = tonumber(a), tonumber(b)
	return x ~= nil and y ~= nil and math.abs(x - y) < 1e-4
end

local function protegida(nombre) return nombre:lower():find("^nameplate") ~= nil end

local function entre(v, a, b, d) return math.max(a, math.min(b, tonumber(v) or d)) end

-- Lo que Alfa pone mientras pescas, según tus opciones. -> { { cvar, valor }, ... }
local function deseadas()
	local t = {}
	local function pon(n, v) t[#t + 1] = { n, tostring(v) } end
	local icono = opt("iconoCorcho") and 1 or 0
	pon("SoftTargetInteract", 3)
	pon("SoftTargetInteractArc", 2)
	pon("SoftTargetInteractRange", 60)
	-- El corcho es un objeto del mundo: su ícono es SoftTargetIconGameObject.
	-- SoftTargetIconInteract no se toca: es de las que CVarCallbackRegistry
	-- guarda en caché (Blizzard_NamePlates.lua) y, cambiada desde Alfa, las
	-- placas de nombre la leerían contaminada en combate (CVAR_UPDATE es síncrono).
	pon("SoftTargetIconGameObject", icono)
	if opt("sonido") then
		local v = entre(opt("volumen"), 0, 1, 1)
		local musica = entre(opt("musica"), 0, 1, 0)
		local ambiente = entre(opt("ambiente"), 0, 1, 0)
		pon("Sound_EnableAllSound", 1)
		pon("Sound_EnableSFX", 1)
		-- Con "Sonidos de mascotas" de Comodidades callados, esa CVar es suya:
		-- Pesca no la toca (al terminar no las devolvería) (1.2.0).
		if A.Get("comodidades.silenciarMascotas") ~= true then pon("Sound_EnablePetSounds", 0) end
		pon("Sound_MusicVolume", musica)
		if ambiente <= 0 then pon("Sound_EnableAmbience", 0) else pon("Sound_AmbienceVolume", ambiente) end
		pon("Sound_SFXVolume", v)
		-- 1.3.7: el volumen general es el tuyo (antes se subía al 100 %); si lo
		-- tienes en cero, uno bajo para que se oiga el chapoteo.
		local general = tonumber((E.respaldo and E.respaldo.Sound_MasterVolume) or leerCVar("Sound_MasterVolume"))
		if general and general <= 0 then pon("Sound_MasterVolume", 0.3) end
	end
	if opt("sonidoFondo") then pon("Sound_EnableSoundWhenGameIsInBG", 1) end
	if opt("ocultarNombres") then
		pon("nameplateShowEnemies", 0)
		pon("nameplateShowFriendlyPlayers", 0)
		pon("UnitNameNPC", 0)
		pon("UnitNameNonCombatCreatureName", 0)
		pon("UnitNameInteractiveNPC", 0)
		pon("UnitNameFriendlySpecialNPCName", 0)
		pon("UnitNameHostleNPC", 1) -- así se llama en el juego
	end
	return t
end

local function guardarRespaldo()
	local d = N.DatosPersonaje(ID)
	if E.respaldo and next(E.respaldo) then
		local c = {}
		for k, v in pairs(E.respaldo) do c[k] = v end
		d.respaldo = c
	else
		d.respaldo = nil
	end
end

local function recuperar()
	if E.respaldo then return end
	local d = N.DatosPersonaje(ID)
	if type(d.respaldo) ~= "table" or next(d.respaldo) == nil then return end
	local r = {}
	for k, v in pairs(d.respaldo) do
		if type(k) == "string" and type(v) == "string" then r[k] = v end
	end
	E.respaldo = next(r) and r or nil
	if E.respaldo then M.Restaurar() else d.respaldo = nil end
end

function M.Aplicar()
	if enCombate() then return end
	recuperar()
	E.respaldo = E.respaldo or {}
	for _, par in ipairs(deseadas()) do
		local nombre, valor = par[1], par[2]
		local actual = leerCVar(nombre)
		if actual ~= nil then
			if E.respaldo[nombre] == nil then E.respaldo[nombre] = actual end
			E.puestos[nombre:lower()] = { nombre = nombre, valor = valor }
			if not igual(actual, valor) then ponerCVar(nombre, valor) end
		end
	end
	if next(E.respaldo) == nil then E.respaldo = nil end
	guardarRespaldo()
end

function M.Reaplicar()
	local r = E.respaldo
	if not r or enCombate() then return end
	local quiero = {}
	for _, par in ipairs(deseadas()) do quiero[par[1]] = true end
	for nombre, valor in pairs(r) do
		if not quiero[nombre] then
			if not igual(leerCVar(nombre), valor) then ponerCVar(nombre, valor) end
			r[nombre] = nil
			E.puestos[nombre:lower()] = nil
		end
	end
	M.Aplicar()
end

function M.Restaurar()
	local r = E.respaldo
	if not r then
		guardarRespaldo()
		return
	end
	local combate = enCombate()
	for nombre, valor in pairs(r) do
		if not (combate and protegida(nombre)) then
			if not igual(leerCVar(nombre), valor) then ponerCVar(nombre, valor) end
			r[nombre] = nil
			E.puestos[nombre:lower()] = nil
		end
	end
	if next(r) == nil then E.respaldo = nil end
	guardarRespaldo()
	-- Lo que el combate no dejó devolver, al salir (encolado una sola vez).
	if E.respaldo and not E.restaurarPendiente then
		E.restaurarPendiente = true
		N.FueraDeCombate(function()
			E.restaurarPendiente = false
			M.Restaurar()
		end)
	end
end

A.RegisterEvent("CVAR_UPDATE", function(_, nombre)
	if escribiendo or type(nombre) ~= "string" or not E.respaldo then return end
	local p = E.puestos[nombre:lower()]
	if not p then return end
	local actual = leerCVar(p.nombre)
	if actual == nil or igual(actual, p.valor) then return end
	E.respaldo[p.nombre] = actual
	E.puestos[nombre:lower()] = nil
	guardarRespaldo()
end)

---------------------------------------------------------------------------
-- La interfaz oculta mientras pescas (fuera de combate; se ve el mundo)
---------------------------------------------------------------------------
-- Los marcos que siguen a la vista: la barra de pesca y lo que pidas.
M.VISIBLES = {}

local function marcosChat()
	local out = {}
	local n = tonumber(NUM_CHAT_WINDOWS) or 10
	for i = 1, n do
		local f = rawget(_G, "ChatFrame" .. i)
		if f then out[#out + 1] = f end
		local tab = rawget(_G, "ChatFrame" .. i .. "Tab")
		if tab then out[#out + 1] = tab end
	end
	for _, nombre in ipairs({ "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton" }) do
		local f = rawget(_G, nombre)
		if f then out[#out + 1] = f end
	end
	return out
end

local SIEMPRE_VISIBLES = {
	"LootFrame", "GroupLootContainer", "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
	"GameMenuFrame", "GameTooltip", "UIErrorsFrame",
	-- Las colas y los avisos de grupo (1.2.0): sin ellos se perdía la cola
	-- mientras pescabas quieto.
	"LFGDungeonReadyPopup", "LFGDungeonReadyDialog", "LFDRoleCheckPopup", "ReadyCheckFrame",
	"PVPReadyDialog", "LFGListInviteDialog", "PetBattleQueueReadyFrame",
}

local function ignorar(f, si)
	if f and f.SetIgnoreParentAlpha then pcall(f.SetIgnoreParentAlpha, f, si and true or false) end
end

function M.OcultarUI()
	if E.ui or enCombate() or not opt("ocultarUI") or not UIParent then return end
	local quedan = {}
	for _, f in ipairs(M.VISIBLES) do quedan[#quedan + 1] = f end
	-- Lo del juego que siempre tiene que verse: el botín, los diálogos, el
	-- menú, los cuadros de ayuda y los errores en pantalla.
	for _, nombre in ipairs(SIEMPRE_VISIBLES) do
		local f = rawget(_G, nombre)
		if f then quedan[#quedan + 1] = f end
	end
	if opt("uiMinimapa") then quedan[#quedan + 1] = rawget(_G, "MinimapCluster") end
	if opt("uiChat") then for _, f in ipairs(marcosChat()) do quedan[#quedan + 1] = f end end
	for _, f in ipairs(quedan) do ignorar(f, true) end
	E.ui = { quedan = quedan, alfa = UIParent:GetAlpha() }
	UIParent:SetAlpha(0)
end

function M.MostrarUI()
	local u = E.ui
	if not u then return end
	E.ui = nil
	if UIParent then UIParent:SetAlpha(u.alfa or 1) end
	for _, f in ipairs(u.quedan) do ignorar(f, false) end
end

-- Una cola lista, una revisión de listos o de rol: la interfaz vuelve sola
-- para que no se pierda mientras pescas quieto (1.2.0).
for _, evento in ipairs({ "LFG_PROPOSAL_SHOW", "READY_CHECK", "LFG_ROLE_CHECK_SHOW", "PET_BATTLE_QUEUE_PROPOSE_MATCH" }) do
	A.RegisterEvent(evento, function() if E.ui then M.MostrarUI() end end)
end

---------------------------------------------------------------------------
-- Avisos con sonido (suaves, sin repetirse)
---------------------------------------------------------------------------
local ultimoSonido = {}
function M.Alerta(tipo, kit)
	if not opt("alertas") then return end
	if tipo == "captura" and not opt("alertaCaptura") then return end
	if tipo == "escape" and not opt("alertaEscape") then return end
	if tipo == "inactivo" and not opt("alertaInactivo") then return end
	local ahora = GetTime and GetTime() or 0
	if ultimoSonido[tipo] and ahora - ultimoSonido[tipo] < 2 then return end
	ultimoSonido[tipo] = ahora
	local s = M.SONIDO_DE[opt("alertaSonido") or "suave"] or M.SONIDOS[1]
	if PlaySound then pcall(PlaySound, kit or s.kit, "Master") end
end

-- El aviso de "¿lanzas otra vez?": una vez por pausa, si sigues en el modo.
local turnoInactivo = 0
local function vigilarInactivo()
	turnoInactivo = turnoInactivo + 1
	local mio = turnoInactivo
	local seg = entre(opt("inactivoSeg"), 5, 300, 25)
	A.After(seg, function()
		if mio ~= turnoInactivo or not E.modo or M.Pescando() or enCombate() or numBotin() > 0 then return end
		if IsPlayerMoving and IsPlayerMoving() then return end
		E.fase = "inactivo"
		M.Alerta("inactivo")
		M.Avisar("estado")
	end)
end

---------------------------------------------------------------------------
-- Restaurar lo de pesca
---------------------------------------------------------------------------
local function cancelarRestaurar() E.turno = E.turno + 1 end

local function restaurarLuego()
	E.turno = E.turno + 1
	local mio = E.turno
	A.After(GRACIA, function()
		if mio ~= E.turno or M.Pescando() then return end
		M.MostrarUI()
		if not E.modo then M.Restaurar() end
		M.Avisar("estado")
	end)
end

-- Todo fuera (apagar, otro addon de pesca, combate).
function M.Soltar()
	cancelarRestaurar()
	M.MostrarUI()
	if E.respaldo then M.Restaurar() end
	quitarTecla()
	M.SoltarClic()
end

local function iniciarPesca()
	if not habilitado() or enCombate() then return end
	cancelarRestaurar()
	M.Aplicar()
	ponerTecla()
	M.OcultarUI()
end

---------------------------------------------------------------------------
-- El modo pesca
---------------------------------------------------------------------------
function M.Modo() return E.modo end

local function guardarModo() N.DatosPersonaje(ID).modo = E.modo or nil end

function M.AbrirModo(auto)
	if not habilitado() then
		if not auto and E.otro then N.Imprimir(L["Otro addon de pesca está activo. Para que no choquen, la pesca de Alfa queda en pausa: desactiva uno de los dos en la lista de addons."]) end
		return false
	end
	if enCombate() then
		if not auto then N.Imprimir(L["El modo pesca se abre al salir de combate."]) end
		N.FueraDeCombate(function() M.AbrirModo(true) end)
		return false
	end
	if E.modo then return true end
	E.modo = true
	E.fase = nil
	guardarModo()
	Eq.Marcar()
	Eq.OlvidarIntentos()
	M.MarcarInicioModo()
	E.avisoCebo = nil
	prepararBotones()
	ponerTeclasModo()
	M.Aplicar()
	M.Avisar("modo")
	return true
end

-- auto: lo cerró algo que no fue tu clic ni tu tecla (montar, apagar). Entonces
-- tu equipo no se cambia solo: un aviso ofrece volver a él con un clic.
-- sinCana (1.2.8): te quitaste la caña tú; ya traes tu equipo, no hay nada que ofrecer.
function M.CerrarModo(auto, sinCana)
	if not E.modo then return end
	E.modo = false
	E.fase = nil
	guardarModo()
	turnoInactivo = turnoInactivo + 1
	quitarTeclasModo()
	M.MostrarUI()
	if not M.Pescando() then
		cancelarRestaurar()
		M.Restaurar()
	end
	if opt("restaurarEquipo") and Eq.HayNormal() and not sinCana then
		if not auto then
			Eq.Restaurar()
		elseif N.Kit and N.Kit.Aviso then
			N.Kit.Aviso({ titulo = L["Modo pesca cerrado"], texto = L["Sigues con tu equipo de pesca."], icono = "ic-pesca", duracion = 8,
				accion = { texto = L["Volver a mi equipo"], alClic = function() Eq.Restaurar() end } })
		end
	end
	N.FueraDeCombate(prepararBotones)
	M.ResumenModo()
	M.Avisar("modo")
end

---------------------------------------------------------------------------
-- 1.3.7: lo que pescaste mientras el modo estuvo abierto, al cerrarlo
---------------------------------------------------------------------------
function M.MarcarInicioModo()
	local s = M.Sesion()
	local especies = {}
	for k, o in pairs(s.objetos) do if type(o) == "table" then especies[k] = tonumber(o.cantidad) or 0 end end
	E.inicioModo = { t = time(), total = s.total, capturas = s.capturas, valor = s.valor, especies = especies, inicio = s.inicio }
end

-- -> { total, especies, valor, segundos } o nil si no sacaste nada.
function M.LoDelModo()
	local i = E.inicioModo
	if not i then return nil end
	local s = M.Sesion()
	-- La sesión cambió a mitad (una nueva a mano o tras una pausa larga): cuenta toda la de ahora.
	local misma = s.inicio == i.inicio
	local total = s.total - (misma and i.total or 0)
	if total <= 0 then return nil end
	local especies = 0
	for k, o in pairs(s.objetos) do
		if type(o) == "table" and (tonumber(o.cantidad) or 0) > ((misma and i.especies[k]) or 0) then especies = especies + 1 end
	end
	return { total = total, especies = especies, valor = s.valor - (misma and i.valor or 0), segundos = max(0, time() - i.t) }
end

function M.ResumenModo()
	local r = M.LoDelModo()
	E.inicioModo = nil
	if not (r and opt("resumenCerrar") and N.Kit and N.Kit.Aviso) then return end
	local partes = { N.Plural(r.total, L["%d captura"], L["%d capturas"]) }
	if r.especies > 1 then partes[#partes + 1] = N.Plural(r.especies, L["%d especie"], L["%d especies"]) end
	if r.valor > 0 and N.DineroTexto then partes[#partes + 1] = N.DineroTexto(r.valor, true) end
	local texto = format(L["En %s: %s."], (M.DuracionCorta and M.DuracionCorta(r.segundos, true)) or N.Duracion(r.segundos), table.concat(partes, DOT_TEXTO))
	N.Kit.Aviso({ id = "pesca.resumen", icono = "ic-pesca", titulo = L["Así te fue pescando"], texto = texto, duracion = 7, detalle = true,
		accion = { texto = L["Ver estadísticas"], alClic = function() if M.V then M.V.Abrir("estadisticas") end end } })
end

function M.Alternar()
	if E.modo then M.CerrarModo() else M.AbrirModo() end
end

AlfaPesca = type(AlfaPesca) == "table" and AlfaPesca or {}
AlfaPesca.Alternar = function() M.Alternar() end
AlfaPesca.Abrir = function() return M.AbrirModo() end
AlfaPesca.Cerrar = function() M.CerrarModo() end
AlfaPesca.Activo = function() return E.modo end

-- Al moverte, la tecla del modo vuelve a ser la de siempre (Espacio salta).
A.RegisterEvent("PLAYER_STARTED_MOVING", function()
	if E.modo and E.modoPuesto and opt("saltarAlMoverse") and not M.Pescando() and not enCombate() then
		quitarTeclasModo()
	end
	if E.fase == "inactivo" then E.fase = nil M.Avisar("estado") end
	if E.ui and not M.Pescando() then M.MostrarUI() end
end)
A.RegisterEvent("PLAYER_STOPPED_MOVING", function()
	if not (E.modo and not E.modoPuesto) then return end
	A.After(0.25, function()
		if E.modo and not E.modoPuesto and not enCombate() and not (IsPlayerMoving and IsPlayerMoving()) then ponerTeclasModo() end
	end)
end)

---------------------------------------------------------------------------
-- El canal de Pesca
---------------------------------------------------------------------------
local turnoCorcho = 0

AlfaNucleo.DeUnidad("UNIT_SPELLCAST_CHANNEL_START", "player", function(_, unidad, _, spell)
	if not legible(unidad) or unidad ~= "player" or not esPesca(spell) then return end
	E.canal = GetTime()
	local ok, _, _, _, ini, fin = pcall(UnitChannelInfo, "player")
	E.canalFin = (ok and legible(fin) and tonumber(fin)) and tonumber(fin) / 1000 or (E.canal + 30)
	-- 1.3.7: lo que dura de verdad este lanzamiento (la barra ya no supone 30 s).
	local dur = (ok and legible(ini) and legible(fin) and tonumber(ini) and tonumber(fin)) and (tonumber(fin) - tonumber(ini)) / 1000 or nil
	E.canalDur = (dur and dur > 0.5 and dur < 120) and dur or max(1, E.canalFin - E.canal)
	E.fase, E.corcho = "lanzado", nil
	turnoInactivo = turnoInactivo + 1
	R.Lanzamiento()
	iniciarPesca()
	-- Sin corcho a la vista en un par de segundos: cayó lejos.
	turnoCorcho = turnoCorcho + 1
	local mio = turnoCorcho
	A.After(2.5, function()
		if mio == turnoCorcho and E.canal and E.fase == "lanzado" then
			E.fase = "lejos"
			M.Avisar("estado")
		end
	end)
	M.Avisar("canal")
end)

-- 1.3.7: solo el corcho cuenta como «Buen lanzamiento». Antes bastaba con
-- que la interacción apuntara a cualquier cosa (un PNJ, un buzón, un banco de
-- peces bajo el ratón). El corcho es un objeto del mundo: el suyo (35591) o,
-- si Forever usa otro, un objeto que no es banco y aparece al caer la línea.
M.CORCHOS = { [35591] = true }
function M.EsCorcho(guid)
	if type(guid) ~= "string" or not legible(guid) then return false end
	local tipo, _, _, _, _, objeto = strsplit("-", guid)
	objeto = tonumber(objeto)
	if tipo ~= "GameObject" or not objeto then return false end
	if M.CORCHOS[objeto] then return true end
	if M.BANCOS[objeto] then return false end
	return E.canal ~= nil and GetTime() - E.canal <= 4
end

A.RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED", function(_, _, nuevo)
	if not E.canal then return end
	if nuevo ~= nil and M.EsCorcho(nuevo) and (E.fase == "lanzado" or E.fase == "lejos") then
		E.fase, E.corcho = "corcho", true
		M.Avisar("estado")
	end
end)

AlfaNucleo.DeUnidad("UNIT_SPELLCAST_CHANNEL_STOP", "player", function(_, unidad, _, spell)
	if not legible(unidad) or unidad ~= "player" then return end
	if not (E.canal or esPesca(spell)) then return end
	local ahora = GetTime()
	local dur = E.canal and max(0, ahora - E.canal) or 0
	E.canal, E.canalFin = nil, nil
	E.ultimaPesca = ahora
	turnoCorcho = turnoCorcho + 1
	local botin = numBotin() > 0
	R.FinCanal(dur, botin)
	if not botin then
		quitarTecla()
		if E.fase ~= "escapado" then E.fase = "listo" end
		if E.modo then vigilarInactivo() end
	end
	restaurarLuego()
	M.Avisar("canal")
end)

-- "Se te escapó" y "no ha picado nada" (los textos del juego).
A.RegisterEvent("UI_ERROR_MESSAGE", function(_, _, mensaje)
	if not legible(mensaje) or type(mensaje) ~= "string" then return end
	if mensaje == rawget(_G, "ERR_FISH_ESCAPED") then
		R.Escape()
		E.fase = "escapado"
		M.Alerta("escape")
		M.Avisar("estado")
	elseif mensaje == rawget(_G, "ERR_FISH_NOT_HOOKED") then
		E.fase = "pronto"
		M.Avisar("estado")
	end
end)

-- Antes de que empiece el combate (aún se puede tocar todo): fuera ayudas.
A.RegisterEvent("PLAYER_REGEN_DISABLED", function()
	if E.respaldo or E.teclaPuesta or E.clicArmado or E.ui then M.Soltar() end
	if E.modoPuesto and ClearOverrideBindings then
		ClearOverrideBindings(modoTeclas)
		E.modoPuesto = false
	end
	turnoInactivo = turnoInactivo + 1
	M.Avisar("estado")
end)

A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if E.modo and habilitado() then
		prepararBotones()
		ponerTeclasModo()
	end
	M.Avisar("estado")
end)

A.RegisterEvent("PLAYER_LOGOUT", function()
	cancelarRestaurar()
	M.MostrarUI()
	if E.respaldo then M.Restaurar() end
end)

A.RegisterEvent("UPDATE_BINDINGS", function()
	if E.teclaPuesta and not enCombate() and firma(teclasDeRecoger()) ~= E.firma then ponerTecla() end
	M.Avisar("teclas")
end)

---------------------------------------------------------------------------
-- Doble clic derecho
---------------------------------------------------------------------------
local function puedeLanzarConClic()
	if enCombate() or not M.TieneCana() then return false end
	if IsPlayerMoving and IsPlayerMoving() then return false end
	if IsMounted and IsMounted() and not opt("montado") then return false end
	if (IsFlying and IsFlying()) or (IsFalling and IsFalling()) then return false end
	if (IsStealthed and IsStealthed()) or (IsSwimming and IsSwimming()) or (IsSubmerged and IsSubmerged()) then return false end
	if UnitHasVehicleUI and UnitHasVehicleUI("player") then return false end
	if HasFullControl and not HasFullControl() then return false end
	if M.Pescando() then
		local mod = IsModifierKeyDown and IsModifierKeyDown() and true or false
		if opt("relanzar") then return not mod end
		return mod
	end
	return true
end

A.RegisterEvent("GLOBAL_MOUSE_DOWN", function(_, boton2)
	if boton2 ~= "RightButton" or not opt("dobleClic") or not habilitado() then return end
	if enCombate() or (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then return end
	if numBotin() > 0 then return end
	local ahora = GetTime()
	local previo = E.clicPrevio
	E.clicPrevio = ahora
	if not previo or ahora - (E.ultimoLanzamiento or 0) < ESPERA_CLIC then return end
	local dt = ahora - previo
	if dt < CLIC_MIN or dt > (tonumber(opt("velocidad")) or 0.2) then return end
	E.clicPrevio = nil
	if puedeLanzarConClic() then
		if armarClic("lanzar") then E.ultimoLanzamiento = ahora end
	elseif M.Pescando() then
		armarClic("recoger")
	end
end)

A.RegisterEvent("GLOBAL_MOUSE_UP", function(_, boton2)
	if boton2 ~= "RightButton" or not E.clicArmado then return end
	if E.clicArmado == "recoger" then
		M.SoltarClic()
		return
	end
	A.After(0.1, function()
		if E.clicArmado == "lanzar" then M.SoltarClic() end
	end)
end)

---------------------------------------------------------------------------
-- Botín de pesca: recoger todo y anotarlo
---------------------------------------------------------------------------
local function esBotinDePesca()
	if IsFishingLoot then
		local ok, si = pcall(IsFishingLoot)
		if ok and legible(si) then return si and true or false end
	end
	return E.ultimaPesca ~= nil and GetTime() - E.ultimaPesca < 3
end

-- El banco de peces del que salió (por el GUID de su fuente).
local function bancoDe(ranura)
	if not GetLootSourceInfo then return nil end
	local ok, guid = pcall(GetLootSourceInfo, ranura)
	if not ok or type(guid) ~= "string" or not legible(guid) then return nil end
	local tipo, _, _, _, _, objeto = strsplit("-", guid)
	objeto = tonumber(objeto)
	if tipo == "GameObject" and objeto and M.BANCOS[objeto] then return objeto, guid end
	return nil
end

local function leerVentana()
	local t = {}
	if not (GetLootSlotLink and GetLootSlotInfo) then return t end
	for ranura = 1, numBotin() do
		local okE, enlace = pcall(GetLootSlotLink, ranura)
		if okE and type(enlace) == "string" and legible(enlace) then
			local ok, icono, nombre, cantidad, _, calidad = pcall(GetLootSlotInfo, ranura)
			if ok then
				t[ranura] = {
					id = tonumber(enlace:match("item:(%d+)")),
					nombre = (type(nombre) == "string" and nombre) or enlace:match("%[(.-)%]") or "?",
					enlace = enlace, icono = icono, calidad = tonumber(calidad),
					cantidad = math.max(1, tonumber(cantidad) or 1),
				}
			end
			if not E.banco then E.banco, E.bancoGuid = bancoDe(ranura) end
		end
	end
	return t
end

local function alListoBotin()
	if not esBotinDePesca() then return end
	if not E.ventana then
		E.tomados = {}
		E.banco, E.bancoGuid = nil, nil
	end
	E.ventana = leerVentana()
	if not habilitado() then return end
	if not E.teclaPuesta and not enCombate() then ponerTecla() end
	if not opt("autobotin") or not LootSlot then return end
	for ranura = numBotin(), 1, -1 do pcall(LootSlot, ranura) end
end

A.RegisterEvent("LOOT_READY", alListoBotin)
A.RegisterEvent("LOOT_OPENED", function() if not E.ventana then alListoBotin() end end)

A.RegisterEvent("LOOT_SLOT_CLEARED", function(_, ranura)
	local o = E.ventana and E.ventana[ranura]
	if type(o) ~= "table" then return end
	E.ventana[ranura] = nil
	E.tomados = E.tomados or {}
	E.tomados[#E.tomados + 1] = o
end)

A.RegisterEvent("LOOT_CLOSED", function()
	if E.teclaPuesta and not M.Pescando() then quitarTecla() end
	if not E.ventana then return end
	E.ventana = nil
	local tomados = E.tomados or {}
	E.tomados = nil
	if #tomados > 0 then
		local nuevo = R.Captura(tomados, { banco = E.banco, bancoGuid = E.bancoGuid })
		E.ultimo = tomados
		E.fase = "capturado"
		local trofeo = false
		for _, x in ipairs(nuevo) do
			local c = x.o.id and M.CLASE[x.o.id]
			if c == "trofeo" or c == "concurso" or (x.o.calidad or 0) >= 3 then trofeo = true end
		end
		M.Alerta("captura", trofeo and M.SONIDO_TROFEO or nil)
		if M.MostrarCaptura then M.MostrarCaptura(tomados, nuevo) end
	end
	E.banco, E.bancoGuid = nil, nil
	if E.modo then vigilarInactivo() end
	M.Avisar("captura")
end)

-- El cebo que entra en la caña cuenta para tus logros.
local habiaCebo = nil
AlfaNucleo.DeUnidad("UNIT_INVENTORY_CHANGED", "player", function(_, unidad)
	if not legible(unidad) or unidad ~= "player" then return end
	local ahora = Eq.CeboActivo() ~= nil
	if habiaCebo == false and ahora then R.Cebo() end
	if habiaCebo == true and not ahora and E.modo and Eq.CanaPuesta() then N.FueraDeCombate("pesca.cebo", M.CeboAcabado) end
	habiaCebo = ahora
	if E.modo then M.PrepararBotones() end
end)

A.RegisterEvent("SKILL_LINES_CHANGED", function()
	M.Sesion()
	M.RevisarTope()
	M.Avisar("habilidad")
end)

---------------------------------------------------------------------------
-- 1.3.7: consejos breves (ajuste consejos): se acabó el cebo y no queda otro;
-- llegaste al tope de tu rango. Una vez, nunca en combate.
---------------------------------------------------------------------------
function M.CeboAcabado()
	if not (opt("consejos") and E.modo and N.Kit and N.Kit.Aviso) or E.avisoCebo then return end
	Eq.Marcar()
	if Eq.MejorCebo() then return end -- te queda otro: tu tecla lo pone
	E.avisoCebo = true
	N.Kit.Aviso({ id = "pesca.cebo", icono = M.ICONO and M.ICONO.cebo or "ic-pesca", titulo = L["Se acabó tu cebo"],
		texto = L["Ya no te quedan cebos que puedas usar. Los venden los vendedores de suministros de pesca."], duracion = 6, detalle = true })
end

-- -> rango, tope, nombre del rango, siguiente rango (nombre) y desde cuándo se aprende
function M.Rango()
	local r, mx = M.Habilidad()
	if not r then return nil end
	local nombre = M.NombreRango(mx)
	local actual, sig
	for i, x in ipairs(M.RANGOS) do
		if (mx or 0) <= x.tope then actual, sig = x, M.RANGOS[i + 1] break end
	end
	return r, mx, nombre, sig and mx < 300 and sig.nombre or nil, actual and actual.siguiente or nil
end

-- El cuadro de tu habilidad en la barra: cuánto te falta y qué sigue.
function M.InfoHabilidad()
	local r, mx, nombre, sig, desde = M.Rango()
	if not r then return L["Pesca"], L["Aprende Pesca con un instructor"] end
	local lineas = {}
	if r < mx then
		lineas[#lineas + 1] = format(L["Te faltan %d puntos para el tope de %s (%d)."], mx - r, nombre, mx)
	elseif sig then
		lineas[#lineas + 1] = format(L["Llegaste al tope de %s: aprende %s con un instructor para seguir subiendo."], nombre, sig)
	else
		lineas[#lineas + 1] = L["Tienes la Pesca al máximo."]
	end
	if sig and desde and r < mx then
		if r >= desde then
			lineas[#lineas + 1] = format(L["Ya puedes aprender %s con un instructor."], sig)
		else
			lineas[#lineas + 1] = format(L["Desde %d puedes aprender %s con un instructor."], desde, sig)
		end
	end
	local _, _, bono = M.Habilidad()
	if (bono or 0) > 0 then lineas[#lineas + 1] = format(L["Tu equipo y tu cebo suman +%d."], bono) end
	lineas[#lineas + 1] = L["Clic derecho en la barra: más opciones."]
	return format(L["%s %d/%d"], nombre, r, mx), table.concat(lineas, "\n")
end

function M.RevisarTope()
	local r, mx, nombre, sig = M.Rango()
	if not (r and sig and r >= mx and opt("consejos") and N.Kit and N.Kit.Aviso) then return end
	local d = N.DatosPersonaje(ID)
	if d.avisoTope == mx then return end
	d.avisoTope = mx
	N.FueraDeCombate("pesca.tope", function()
		N.Kit.Aviso({ id = "pesca.tope", icono = "ic-pesca", titulo = format(L["Pesca al tope de %s"], nombre),
			texto = format(L["Tu Pesca ya no sube hasta que aprendas %s con un instructor de pesca."], sig), duracion = 8, detalle = true,
			accion = { texto = L["Abrir la guía"], alClic = function() if M.V then M.V.Abrir("guia") end end } })
	end)
end

-- Tu equipo cambió: la macro se rehace y, con una caña nueva, se abre el modo.
-- 1.2.8: y al quitarte la caña (te pusiste tus armas) el modo se cierra solo:
-- antes seguían los mensajes y las teclas de pesca con las armas en la mano.
local function cerrarSiSinCana()
	if E.modo and not Eq.restaurando and not Eq.CanaPuesta() then M.CerrarModo(true, true) end
end
A.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, ranura)
	if ranura == 16 or ranura == 17 then
		local antes = E.conCana
		E.conCana = Eq.CanaPuesta() and true or false
		if ranura == 16 and habilitado() and opt("abrirConCana") and not E.modo and not Eq.restaurando and E.conCana then
			M.AbrirModo(true)
		elseif antes and not E.conCana and E.modo and not Eq.restaurando then
			-- Un instante después: al cambiar de arma el juego puede avisar dos veces.
			A.After(0.3, function()
				if enCombate() then N.FueraDeCombate(cerrarSiSinCana) else cerrarSiSinCana() end
			end)
		end
	end
	M.PrepararBotones()
	M.Avisar("equipo")
end)
A.RegisterEvent("BAG_UPDATE_DELAYED", function() if E.modo then M.PrepararBotones() end end)

-- Al montar se cierra el modo (con tu equipo de vuelta, si lo pides).
A.RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", function()
	if E.modo and opt("cerrarAlMontar") and IsMounted and IsMounted() then M.CerrarModo(true) end
end)

---------------------------------------------------------------------------
-- Lo que dice la barra ahora: { fase, texto, tono, titulo }
---------------------------------------------------------------------------
local DOT = " \194\183 "

function M.Estado()
	local tecla = M.TeclaAhora()
	local relanza = M.TextoTecla(opt("teclaRelanzar"))
	local d = { tono = "acento" }
	local function pulsa(que)
		if tecla then return format(L["Pulsa %s %s"], tecla, que) end
		return que
	end
	if E.otro then
		d.fase, d.tono, d.texto = "pausa", "aviso", L["En pausa: hay otro addon de pesca activo"]
	elseif not opt("activo") then
		d.fase, d.tono, d.texto = "apagado", "neutro", L["La pesca de Alfa está apagada"]
	elseif M.SabePesca() == false then
		d.fase, d.tono, d.texto = "aprender", "aviso", L["Aprende Pesca con un instructor"]
	elseif enCombate() then
		d.fase, d.tono, d.texto = "combate", "aviso", L["En combate · la pesca espera"]
		if Eq.CanaPuesta() and #Eq.Armas() > 0 then d.texto = L["En combate · «A pelear» te pone tus armas"] end
	elseif E.canal then
		local f = E.fase
		if f == "corcho" then
			d.texto = L["Buen lanzamiento"] .. DOT .. pulsa(L["al salpicar"])
		elseif f == "lejos" then
			d.tono = "aviso"
			d.texto = relanza and format(L["El corcho quedó lejos · relanza con %s"], relanza) or L["El corcho quedó lejos · vuelve a lanzar"]
		else
			d.texto = L["Lanzado"] .. DOT .. pulsa(L["al salpicar"])
		end
		d.fase = "pescando"
	else
		local p = E.plan
		if p and p.fase == "equipo" then
			d.fase, d.texto = "equipo", pulsa(L["para ponerte el equipo de pesca"])
		elseif p and p.fase == "cebo" then
			d.fase, d.texto = "cebo", pulsa(format(L["para poner %s"], p.cebo and p.cebo.nombre or L["el cebo"]))
		elseif not M.TieneCana() then
			d.fase, d.tono, d.texto = "cana", "aviso", L["Equipa tu caña de pescar"]
		elseif not tecla and not opt("dobleClic") then
			d.fase, d.tono, d.texto = "tecla", "aviso", L["Elige tu tecla para pescar"]
		elseif E.fase == "capturado" and E.ultimo and E.ultimo[1] then
			local o = E.ultimo[1]
			d.fase, d.tono = "capturado", "exito"
			d.texto = format(L["¡Lo tienes! %s ×%d"], o.nombre or "?", o.cantidad or 1) .. DOT .. pulsa(L["para lanzar"])
		elseif E.fase == "escapado" then
			d.fase, d.tono, d.texto = "escapado", "aviso", L["Se escapó"] .. DOT .. pulsa(L["para volver a lanzar"])
		elseif E.fase == "pronto" then
			d.fase, d.tono, d.texto = "pronto", "aviso", L["Aún no picaba"] .. DOT .. pulsa(L["al salpicar"])
		elseif E.fase == "inactivo" then
			d.fase, d.tono, d.texto = "inactivo", "aviso", L["¿Otra vez?"] .. DOT .. pulsa(L["para lanzar"])
		else
			d.fase, d.texto = "listo", pulsa(L["para lanzar"])
		end
	end
	return d
end

-- "Experto 126/225" y su avance.
function M.TextoHabilidad()
	local r, mx, bono = M.Habilidad()
	if not r then return L["Sin Pesca"], 0, 1, 0 end
	local nombre = M.NombreRango(mx)
	return format(L["%s %d/%d"], nombre, r, mx), r, max(1, mx), bono or 0
end

-- Lo que dura el lanzamiento de ahora (1.3.7: el del juego, no 30 s fijos).
function M.DuracionCanal() return E.canalDur or 30 end

-- Segundos que le quedan al canal (o nil).
function M.Restante()
	if not E.canal then return nil end
	return max(0, (E.canalFin or (E.canal + 30)) - GetTime())
end

---------------------------------------------------------------------------
-- El concurso de pesca de Tuercespina (los domingos, hora del reino)
---------------------------------------------------------------------------
-- La hora del reino -> { año, mes, día, día de la semana, hora, minuto }
local function horaReino()
	local C = C_DateAndTime
	if C and C.GetCurrentCalendarTime then
		local ok, t = pcall(C.GetCurrentCalendarTime)
		if ok and type(t) == "table" and t.year then return t end
	end
	local d = date("*t")
	return { year = d.year, month = d.month, monthDay = d.day, weekday = d.wday, hour = d.hour, minute = d.min }
end

-- La diferencia entre la hora del reino y la tuya (segundos, de 15 en 15 min).
local function desfase(t)
	local reino = time({ year = t.year, month = t.month, day = t.monthDay, hour = t.hour, min = t.minute, sec = 0 })
	local dif = reino - time()
	return floor(dif / 900 + 0.5) * 900
end

-- -> enCurso (bool), inicio (tu hora, epoch), fin (tu hora, epoch)
function M.Concurso()
	local t = horaReino()
	local c = M.CONCURSO
	local dias = (c.dia - (t.weekday or 1)) % 7
	local ahoraMin = (t.hour or 0) * 60 + (t.minute or 0)
	local enCurso = dias == 0 and ahoraMin >= c.desde * 60 and ahoraMin < c.hasta * 60
	if dias == 0 and ahoraMin >= c.hasta * 60 then dias = 7 end
	local off = desfase(t)
	local base = time({ year = t.year, month = t.month, day = t.monthDay + dias, hour = c.desde, min = 0, sec = 0 })
	local inicio = base - off
	local fin = inicio + (c.hasta - c.desde) * 3600
	if enCurso then
		local hoy = time({ year = t.year, month = t.month, day = t.monthDay, hour = c.desde, min = 0, sec = 0 }) - off
		inicio, fin = hoy, hoy + (c.hasta - c.desde) * 3600
	end
	return enCurso, inicio, fin
end

function M.EnConcurso() return (M.Concurso()) end

---------------------------------------------------------------------------
-- Otro addon de pesca (Compat.lua): no chocar, tomar sus opciones y, al
-- dejarlo, su tecla
---------------------------------------------------------------------------
local OTROS = M.OTROS and M.OTROS.pesca or {}

local function cargado(carpeta)
	local f = C_AddOns and C_AddOns.IsAddOnLoaded
	if not (f and carpeta) then return false end
	local ok, si = pcall(f, carpeta)
	return ok and si == true
end

local function detectarOtro()
	for _, o in ipairs(OTROS) do
		if cargado(o.carpeta) then return o end
	end
	return false
end

local function accionDeOtro(accion)
	for _, o in ipairs(OTROS) do
		if o.accion and o.accion == accion then return true end
	end
	return false
end

local function importarOtro(o)
	local d = N.Datos(ID)
	local db = o.guardado and rawget(_G, o.guardado)
	if d.importadoOtro or type(db) ~= "table" then return end
	for _, par in ipairs(o.opciones or {}) do N.Set(ID, par[2], db[par[1]] == true) end
	if o.volumen and type(db[o.volumen]) == "number" then
		N.Set(ID, "volumen", math.max(0, math.min(1, db[o.volumen])))
	end
	if o.velocidad and type(db[o.velocidad]) == "number" then
		N.Set(ID, "velocidad", math.max(0.1, math.min(0.8, db[o.velocidad])))
	end
	if o.sinIcono then N.Set(ID, "iconoCorcho", db[o.sinIcono] ~= true) end
	d.importadoOtro = true
end

local function recordarTeclasOtro(o)
	if not (GetBindingKey and o.accion) then return end
	local ok, k1, k2 = pcall(GetBindingKey, o.accion)
	if not ok then return end
	local t = {}
	if type(k1) == "string" and k1 ~= "" then t[#t + 1] = k1 end
	if type(k2) == "string" and k2 ~= "" then t[#t + 1] = k2 end
	if #t > 0 then N.Datos(ID).teclasOtro = t end
end

local function tomarTeclasOtro()
	local d = N.Datos(ID)
	local lista = d.teclasOtro
	if type(lista) ~= "table" then return end
	if #M.Teclas() > 0 or not (SetBinding and GetBindingAction) then
		d.teclasOtro = nil
		return
	end
	N.FueraDeCombate(function()
		local hechas = {}
		for _, k in ipairs(lista) do
			if type(k) == "string" then
				local ok, accion = pcall(GetBindingAction, k)
				accion = ok and type(accion) == "string" and accion or ""
				if accion == "" or accionDeOtro(accion) then
					local okB, res = pcall(SetBinding, k, ACCION)
					if okB and res ~= false then hechas[#hechas + 1] = M.TextoTecla(k) end
				end
			end
		end
		d.teclasOtro = nil
		if #hechas == 0 then return end
		if SaveBindings then
			local okS, set = pcall(GetCurrentBindingSet)
			pcall(SaveBindings, okS and set or 1)
		end
		N.Imprimir(string.format(L["La tecla que usabas en tu otro addon de pesca (%s) ahora pesca con Alfa."], table.concat(hechas, ", ")))
		M.Avisar("teclas")
	end)
end

A.OnLogin(function()
	E.otro = detectarOtro()
	local d = N.Datos(ID)
	if E.otro then
		importarOtro(E.otro)
		recordarTeclasOtro(E.otro)
		if not d.avisoOtro then
			d.avisoOtro = true
			N.Imprimir(L["Otro addon de pesca está activo. Para que no choquen, la pesca de Alfa queda en pausa: desactiva uno de los dos en la lista de addons."])
		end
		M.Soltar()
	else
		d.avisoOtro = nil
		tomarTeclasOtro()
	end
	Eq.Foto()
	habiaCebo = Eq.CeboActivo() ~= nil
	M.PrepararBotones()
	M.Avisar("todo")
end)

-- Al entrar: la sesión vieja pasa al historial si quedó atrás; lo que haya
-- quedado de un cierre de golpe se restaura; tras un /reload el modo sigue.
A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, inicial)
	E.conCana = Eq.CanaPuesta() and true or false
	R.Revisar()
	recuperar()
	local d = N.DatosPersonaje(ID)
	if d.modo and habilitado() and not E.modo then
		local enInstancia = IsInInstance and N.Leer((select(2, IsInInstance())))
		if enInstancia and enInstancia ~= "none" then
			d.modo = nil
		else
			N.FueraDeCombate(function() M.AbrirModo(true) end)
		end
	end
	if habilitado() and M.Pescando() then
		E.canal = E.canal or GetTime()
		iniciarPesca()
	end
	M.Avisar("todo")
end)

A.On("SETTING_CHANGED", function(path)
	path = type(path) == "string" and path or ""
	if path ~= "" and path ~= ID and path:sub(1, #ID + 1) ~= ID .. "." then return end
	if path == ID .. ".excluir" or path == ID .. ".prepararEquipo" or path == ID .. ".prepararCebo" or path == ID .. ".ceboPreferido" then Eq.Marcar() end
	M.PrepararBotones()
	if not habilitado() then
		if E.modo then M.CerrarModo(true) end
		M.Soltar()
	else
		if E.modo then N.FueraDeCombate(ponerTeclasModo) end
		if E.respaldo then M.Reaplicar() end
		if path == ID .. ".ocultarUI" and not opt("ocultarUI") then M.MostrarUI() end
	end
	M.Avisar("ajustes")
end)

---------------------------------------------------------------------------
-- /alfa pesca: abre o cierra el modo pesca. Con algo más:
--   ajustes · diario · guia · cocina · metas · estadisticas · logros
--   on · off (el interruptor) · reiniciar (sesión nueva)
---------------------------------------------------------------------------
local ENCENDER = { on = true, encender = true, prender = true, activar = true }
local APAGAR = { off = true, apagar = true, desactivar = true }
local REINICIAR = { reiniciar = true, reset = true, nuevo = true, nueva = true }
local VENTANA = { diario = "diario", guia = "guia", ["guía"] = "guia", cocina = "cocina", metas = "metas",
	estadisticas = "estadisticas", ["estadísticas"] = "estadisticas", logros = "logros", historial = "estadisticas" }

function M.Comando(resto)
	resto = (type(resto) == "string" and resto or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if resto == "" or resto == "modo" then
		M.Alternar()
	elseif ENCENDER[resto] then
		N.Set(ID, "activo", true)
		N.Imprimir(E.otro and L["Pesca de Alfa encendida, pero en pausa mientras otro addon de pesca esté activo."] or L["Pesca de Alfa encendida."])
	elseif APAGAR[resto] then
		N.Set(ID, "activo", false)
		N.Imprimir(L["Pesca de Alfa apagada. Tu tecla y tus ajustes quedan como siempre."])
	elseif REINICIAR[resto] then
		M.NuevaSesion()
		N.Imprimir(L["Sesión de pesca nueva."])
	elseif VENTANA[resto] then
		if VENTANA[resto] == "metas" and M.Metas then M.Metas.Alternar(true)
		elseif M.V then M.V.Abrir(VENTANA[resto]) end
	else
		N.Abrir(ID)
	end
end
