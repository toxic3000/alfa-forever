-- Alfa - Pesca (toxic3000 / La Jauría). GPL-3.0.
--
-- Pescar con una sola tecla: la tecla lanza Pesca y, mientras el corcho está
-- en el agua, esa misma tecla lo recoge. Además: autobotín, sonido amplificado,
-- nombres ocultos mientras pescas, doble clic derecho e ícono sobre el corcho.
--
-- Cómo funciona (todo con una tecla o un clic del jugador, nunca solo):
--   * AlfaPescaBoton es un botón seguro con "/cast [nocombat,noflying] Pesca".
--     La tecla del jugador lo pulsa (Bindings.xml: CLICK AlfaPescaBoton).
--   * Al empezar el canal de Pesca, fuera de combate, esa tecla pasa a
--     INTERACTTARGET con SetOverrideBinding, y la interacción suave (CVars
--     SoftTargetInteract*) apunta al corcho: pulsarla otra vez lo recoge.
--   * Al terminar el canal la tecla vuelve a lanzar. Sonido, nombres e
--     interacción vuelven a como estaban unos segundos después (por si vuelves
--     a lanzar enseguida), al entrar en combate, al apagar el módulo, al
--     recargar o al salir. Los valores originales también se guardan en disco
--     mientras se pesca: si el juego se cierra de golpe, se restauran al entrar.
--   * Doble clic derecho (opcional): AlfaPescaClic y BUTTON2, el mismo truco.
--   * Si otro addon de pesca está cargado (Compat.lua), Alfa no liga nada ni
--     cambia ajustes y avisa una vez. Recuerda su tecla y la toma sola cuando
--     lo desactives.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
M.L = L

local ID = "pesca"
local ACCION = "CLICK AlfaPescaBoton:LeftButton"
M.ID, M.ACCION = ID, ACCION

-- Valores por omisión: los que usa Toxic al pescar.
M.AJUSTES = {
	activo = true,          -- interruptor general
	autobotin = true,       -- recoger todo lo pescado aunque el botín automático esté apagado
	ocultarNombres = true,  -- ocultar placas y nombres de PNJ (menos hostiles) mientras pescas
	sonido = true,          -- sonido amplificado mientras pescas
	volumen = 1,            -- volumen de efectos y general mientras pescas (0-1)
	dobleClic = false,      -- doble clic derecho para lanzar
	velocidad = 0.2,        -- segundos máximos entre los dos clics
	montado = false,        -- el doble clic también lanza montado
	relanzar = true,        -- doble clic pescando: relanza (con modificador recoge); apagado al revés
	iconoCorcho = true,     -- ícono de interacción sobre el corcho
}

_G["BINDING_NAME_" .. ACCION] = L["Pescar: lanzar y recoger"]

local SKILL_PESCA = 356 -- línea de habilidad de Pesca (también en Alfa.Compat.SKILL_LINES)
local GRACIA = 6        -- segundos con sonido y nombres de pesca tras sacar el corcho
local ESPERA_CLIC = 0.5 -- un doble clic no vuelve a lanzar antes de esto
local CLIC_MIN = 0.04   -- dos clics más juntos que esto son un rebote del ratón

-- Hechizos de Pesca (el que se aprende y el canal) de las versiones del juego;
-- si Forever usa otro, se reconoce por el nombre.
local PESCA = {
	[7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true, [51294] = true,
	[88868] = true, [110410] = true, [131474] = true, [131476] = true, [131490] = true, [158743] = true,
}
local RANGOS = { 18248, 7732, 7731, 7620 }

-- Estado de la sesión de pesca (nada de esto se guarda salvo `respaldo`).
local E = {
	otro = false,           -- otro addon de pesca cargado (su entrada de Compat.lua): Alfa en pausa
	respaldo = nil,         -- CVar -> valor original, mientras están cambiados
	puestos = {},           -- cvar en minúsculas -> { nombre, valor } que puso Alfa
	teclaPuesta = false,    -- la tecla está en INTERACTTARGET
	clicArmado = nil,       -- "lanzar" | "recoger": BUTTON2 tomado por el doble clic
	canal = nil,            -- GetTime() al empezar el canal de pesca
	ultimaPesca = nil,      -- GetTime() al terminar el último canal
	ventana = nil,          -- botín de pesca abierto: ranura -> objeto
	turno = 0,              -- cancela restauraciones pendientes
	clicPrevio = nil,
	ultimoLanzamiento = 0,
}
M.E = E

local function opt(k) return N.Get(ID, k) end
M.Opt = opt

local function legible(v)
	if v == nil then return false end
	return not (issecretvalue and issecretvalue(v))
end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function habilitado() return opt("activo") and not E.otro and true or false end
M.Habilitado = habilitado

-- La página se vuelve a dibujar cuando algo cambia (Pagina.lua pone M.alCambiar).
local avisoPendiente = false
function M.Avisar()
	if avisoPendiente or not M.alCambiar then return end
	avisoPendiente = true
	A.After(0.05, function()
		avisoPendiente = false
		if M.alCambiar then M.alCambiar() end
	end)
end

---------------------------------------------------------------------------
-- Datos del jugador: Pesca, la caña, el canal, las teclas
---------------------------------------------------------------------------

-- El nombre de Pesca en el idioma del cliente ("Pesca" en esMX).
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

-- -> rango, máximo, bonificación (cebo o equipo); nil si no sabe Pesca o el
-- cliente no lo dice.
function M.Habilidad()
	local S = C_SkillInfo
	if S and S.GetSkillLineInfoByID then
		local ok, info = pcall(S.GetSkillLineInfoByID, SKILL_PESCA)
		if ok and type(info) == "table" then
			local r, mx = tonumber(info.rank), tonumber(info.maxRank)
			if r and mx and legible(r) and not (r == 0 and mx == 0) then
				return r, mx, tonumber(info.modifier) or 0
			end
		end
	end
	local C = A.Compat
	if C and C.GetSkillRank then
		local ok, r, mx = pcall(C.GetSkillRank, SKILL_PESCA)
		if ok and type(r) == "number" then return r, tonumber(mx) or 0, 0 end
	end
	return nil
end

-- true / false, o nil cuando el cliente no lo puede decir.
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

-- Una caña de pescar en la mano principal. Sin forma de saberlo, no bloquea.
function M.TieneCana()
	if not (GetInventoryItemID and C_Item and C_Item.GetItemInfoInstant) then return true end
	local okId, id = pcall(GetInventoryItemID, "player", INVSLOT_MAINHAND or 16)
	if not okId then return true end
	if not id then return false end
	local ok, _, _, _, _, _, clase, sub = pcall(C_Item.GetItemInfoInstant, id)
	if not ok then return true end
	local arma = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
	local cana = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or 20
	return clase == arma and sub == cana
end

function M.Pescando()
	if not UnitChannelInfo then return false end
	local ok, nombre, _, _, _, _, _, _, spell = pcall(UnitChannelInfo, "player")
	if not ok or nombre == nil then return false end
	if legible(spell) and type(spell) == "number" and PESCA[spell] then return true end
	return legible(nombre) and nombre == M.NombrePesca()
end

-- Las teclas que el jugador dio a "Pescar: lanzar y recoger".
function M.Teclas()
	local t = {}
	if not GetBindingKey then return t end
	local ok, k1, k2 = pcall(GetBindingKey, ACCION)
	if not ok then return t end
	if type(k1) == "string" and k1 ~= "" then t[#t + 1] = k1 end
	if type(k2) == "string" and k2 ~= "" then t[#t + 1] = k2 end
	return t
end

-- "F", "Mayús-F", "Botón del ratón 4" en el idioma del cliente.
function M.TextoTecla(k)
	if type(k) ~= "string" then return nil end
	if GetBindingText then
		local ok, t = pcall(GetBindingText, k)
		if ok and type(t) == "string" and t ~= "" then return t end
	end
	return k
end

local function numBotin()
	if not GetNumLootItems then return 0 end
	local ok, n = pcall(GetNumLootItems)
	return ok and tonumber(n) or 0
end

---------------------------------------------------------------------------
-- Botones seguros
---------------------------------------------------------------------------

-- Sin padre ni tamaño: nadie los ve, solo los pulsa la tecla o el clic. La
-- tecla actúa al bajarla (así, soltarla tras recoger no vuelve a lanzar).
local boton = CreateFrame("Button", "AlfaPescaBoton", nil, "SecureActionButtonTemplate")
boton:RegisterForClicks("AnyDown", "AnyUp")

-- El doble clic: actúa al soltar el segundo clic derecho.
local clic = CreateFrame("Button", "AlfaPescaClic", nil, "SecureActionButtonTemplate")
clic:RegisterForClicks("AnyDown", "AnyUp")

local function prepararBotones()
	local nombre = M.NombrePesca()
	local si = habilitado()
	boton:SetAttribute("useOnKeyDown", true)
	boton:SetAttribute("type", si and "macro" or nil)
	boton:SetAttribute("macrotext", si and ("/cast [nocombat,noflying] " .. nombre) or nil)
	clic:SetAttribute("useOnKeyDown", false)
	clic:SetAttribute("type", si and "macro" or nil)
	clic:SetAttribute("macrotext", si and ("/cast [nocombat,noflying] " .. nombre) or nil)
end
M.PrepararBotones = function() N.FueraDeCombate(prepararBotones) end

-- Mientras pescas: tus teclas recogen el corcho. `firma` dice qué teclas se
-- tomaron: cambiar una ligadura dispara UPDATE_BINDINGS, y sin ella se
-- volverían a poner sin fin.
local function firma(teclas) return table.concat(teclas, "\n") end

local function ponerTecla()
	if enCombate() or not (SetOverrideBinding and ClearOverrideBindings) then return end
	local teclas = M.Teclas()
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

-- Tras lanzar con el doble clic, el clic derecho vuelve a ser el del juego. Si
-- la cámara quedó girando (el juego tomó el primer medio clic), se suelta.
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

-- Mientras Alfa escribe, CVAR_UPDATE no cuenta como un cambio tuyo.
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

-- Las placas de nombre no se pueden cambiar en combate: esperan.
local function protegida(nombre) return nombre:lower():find("^nameplate") ~= nil end

-- Lo que Alfa pone mientras pescas, según tus opciones. -> { { cvar, valor }, ... }
local function deseadas()
	local t = {}
	local function pon(n, v) t[#t + 1] = { n, tostring(v) } end
	local icono = opt("iconoCorcho") and 1 or 0
	pon("SoftTargetInteract", 3)
	pon("SoftTargetInteractArc", 2)
	pon("SoftTargetInteractRange", 60)
	pon("SoftTargetIconGameObject", icono)
	pon("SoftTargetIconInteract", icono)
	if opt("sonido") then
		local v = math.max(0, math.min(1, tonumber(opt("volumen")) or 1))
		pon("Sound_EnableAllSound", 1)
		pon("Sound_EnableSFX", 1)
		pon("Sound_EnableSoundWhenGameIsInBG", 1)
		pon("Sound_EnableAmbience", 0)
		pon("Sound_EnablePetSounds", 0)
		pon("Sound_MusicVolume", 0)
		pon("Sound_SFXVolume", v)
		pon("Sound_MasterVolume", v)
	end
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

-- El respaldo también va al disco: si el juego se cierra pescando, se
-- restaura al volver a entrar con este personaje.
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

-- Cambiaste una opción con los ajustes puestos: vuelve a como estaba solo lo
-- que ya no toca y pone lo nuevo (sin apagar y prender el sonido de golpe).
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

-- Todo a como estaba. En combate, las placas esperan a que termine.
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
	if E.respaldo then N.FueraDeCombate(M.Restaurar) end
end

-- Si cambias tú uno de esos ajustes mientras pescas, tu valor nuevo es el
-- que queda al terminar.
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

local function cancelarRestaurar() E.turno = E.turno + 1 end

local function restaurarLuego()
	E.turno = E.turno + 1
	local mio = E.turno
	A.After(GRACIA, function()
		if mio ~= E.turno or M.Pescando() then return end
		M.Restaurar()
		M.Avisar()
	end)
end

-- Todo fuera: CVars, tecla y doble clic (apagar, otro addon de pesca, combate).
function M.Soltar()
	cancelarRestaurar()
	if E.respaldo then M.Restaurar() end
	quitarTecla()
	M.SoltarClic()
end

local function iniciarPesca()
	if not habilitado() or enCombate() then return end
	cancelarRestaurar()
	M.Aplicar()
	ponerTecla()
end

---------------------------------------------------------------------------
-- El canal de Pesca
---------------------------------------------------------------------------

A.RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", function(_, unidad, _, spell)
	if not legible(unidad) or unidad ~= "player" or not esPesca(spell) then return end
	E.canal = GetTime()
	iniciarPesca()
	M.Avisar()
end)

-- En combate el hechizo puede llegar secreto: si el canal era de pesca, es su final.
A.RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unidad, _, spell)
	if not legible(unidad) or unidad ~= "player" then return end
	if not (E.canal or esPesca(spell)) then return end
	local ahora = GetTime()
	if E.canal then
		local s = M.Sesion()
		s.segundos = s.segundos + math.max(0, ahora - E.canal)
		E.canal = nil
	end
	E.ultimaPesca = ahora
	-- Con el botín abierto la tecla sigue recogiendo (no lanza encima de tu
	-- pez); vuelve a lanzar al cerrarse (LOOT_CLOSED).
	if numBotin() == 0 then quitarTecla() end
	if E.respaldo then restaurarLuego() end
	M.Avisar()
end)

-- Antes de que empiece el combate (aún se puede tocar todo): fuera ayudas.
A.RegisterEvent("PLAYER_REGEN_DISABLED", function()
	if E.respaldo or E.teclaPuesta or E.clicArmado then M.Soltar() end
end)

A.RegisterEvent("PLAYER_LOGOUT", function()
	cancelarRestaurar()
	if E.respaldo then M.Restaurar() end
end)

-- Cambiaste tu tecla mientras pescas: la nueva también recoge.
A.RegisterEvent("UPDATE_BINDINGS", function()
	if E.teclaPuesta and not enCombate() and firma(M.Teclas()) ~= E.firma then ponerTecla() end
	M.Avisar()
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
		-- Relanzar, o recoger con Mayús, Ctrl o Alt (al revés con "relanzar" apagado).
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
	-- Si el clic cayó en la interfaz y no lanzó, el clic derecho vuelve igual.
	A.After(0.1, function()
		if E.clicArmado == "lanzar" then M.SoltarClic() end
	end)
end)

---------------------------------------------------------------------------
-- Botín de pesca: recoger todo y anotar lo pescado en la sesión
---------------------------------------------------------------------------

function M.Sesion()
	local d = N.DatosPersonaje(ID)
	local s = d.sesion
	if type(s) ~= "table" then
		s = {}
		d.sesion = s
	end
	if type(s.objetos) ~= "table" then s.objetos = {} end
	s.inicio = tonumber(s.inicio) or time()
	s.capturas = tonumber(s.capturas) or 0
	s.total = tonumber(s.total) or 0
	s.segundos = tonumber(s.segundos) or 0
	if s.rangoInicial == nil then s.rangoInicial = M.Habilidad() end
	return s
end

function M.NuevaSesion()
	N.DatosPersonaje(ID).sesion = nil
	local s = M.Sesion()
	M.Avisar()
	return s
end

-- Lo que pescaste en la sesión, de lo más a lo menos.
function M.Objetos()
	local lista = {}
	for _, o in pairs(M.Sesion().objetos) do
		if type(o) == "table" and (tonumber(o.cantidad) or 0) > 0 then lista[#lista + 1] = o end
	end
	table.sort(lista, function(a, b)
		if a.cantidad ~= b.cantidad then return a.cantidad > b.cantidad end
		return tostring(a.nombre or "") < tostring(b.nombre or "")
	end)
	return lista
end

local function esBotinDePesca()
	if IsFishingLoot then
		local ok, si = pcall(IsFishingLoot)
		if ok and legible(si) then return si and true or false end
	end
	return E.ultimaPesca ~= nil and GetTime() - E.ultimaPesca < 3
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
					enlace = enlace,
					icono = icono,
					calidad = tonumber(calidad),
					cantidad = math.max(1, tonumber(cantidad) or 1),
				}
			end
		end
	end
	return t
end

local function anotar(o)
	local s = M.Sesion()
	local clave = o.id or o.nombre
	local guardado = s.objetos[clave]
	if type(guardado) ~= "table" then
		guardado = { id = o.id, nombre = o.nombre, cantidad = 0 }
		s.objetos[clave] = guardado
	end
	guardado.nombre, guardado.enlace = o.nombre, o.enlace
	guardado.icono = type(o.icono) ~= "table" and o.icono or nil
	guardado.calidad = o.calidad
	guardado.cantidad = (tonumber(guardado.cantidad) or 0) + o.cantidad
	s.total = s.total + o.cantidad
end

local function alListoBotin()
	if not esBotinDePesca() then return end
	if not E.ventana then
		local s = M.Sesion()
		s.capturas = s.capturas + 1
	end
	E.ventana = leerVentana()
	if not habilitado() then return end
	-- Mientras el botín de pesca está abierto, tu tecla no vuelve a lanzar:
	-- con las bolsas llenas, lanzar cerraría la ventana y perderías el pez.
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
	anotar(o)
end)

A.RegisterEvent("LOOT_CLOSED", function()
	if E.teclaPuesta and not M.Pescando() then quitarTecla() end
	if not E.ventana then return end
	E.ventana = nil
	M.Avisar()
end)

A.RegisterEvent("SKILL_LINES_CHANGED", function()
	M.Sesion()
	M.Avisar()
end)
A.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() M.Avisar() end)

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

-- La entrada del primer addon de pesca cargado, o false.
local function detectarOtro()
	for _, o in ipairs(OTROS) do
		if cargado(o.carpeta) then return o end
	end
	return false
end

-- La acción de tecla de algún addon de pesca conocido.
local function accionDeOtro(accion)
	for _, o in ipairs(OTROS) do
		if o.accion and o.accion == accion then return true end
	end
	return false
end

-- Sus opciones, una sola vez, como punto de partida.
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

-- Sin el otro addon y sin tecla propia: la que usabas allá, si sigue libre.
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
		M.Avisar()
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
	M.PrepararBotones()
	M.Avisar()
end)

-- Al entrar: sesión nueva (no al recargar) y lo que haya quedado de un cierre
-- de golpe. Tras un /reload pescando, la tecla vuelve a recoger.
A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, inicial)
	if inicial == true then M.NuevaSesion() else M.Sesion() end
	recuperar()
	if habilitado() and M.Pescando() then
		E.canal = E.canal or GetTime()
		iniciarPesca()
	end
	M.Avisar()
end)

-- Tus opciones: los botones se rehacen y, si estás pescando, se aplican ya.
A.On("SETTING_CHANGED", function(path)
	path = type(path) == "string" and path or ""
	if path ~= "" and path ~= ID and path:sub(1, #ID + 1) ~= ID .. "." then return end
	M.PrepararBotones()
	if not habilitado() then
		M.Soltar()
	elseif E.respaldo then
		M.Reaplicar()
	end
	M.Avisar()
end)

---------------------------------------------------------------------------
-- /alfa pesca [on | off | reiniciar]
---------------------------------------------------------------------------

local ENCENDER = { on = true, encender = true, prender = true, activar = true }
local APAGAR = { off = true, apagar = true, desactivar = true }
local REINICIAR = { reiniciar = true, reset = true, nuevo = true, borrar = true }

function M.Comando(resto)
	resto = (type(resto) == "string" and resto or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if ENCENDER[resto] then
		N.Set(ID, "activo", true)
		N.Imprimir(E.otro and L["Pesca de Alfa encendida, pero en pausa mientras otro addon de pesca esté activo."] or L["Pesca de Alfa encendida."])
	elseif APAGAR[resto] then
		N.Set(ID, "activo", false)
		N.Imprimir(L["Pesca de Alfa apagada. Tu tecla y tus ajustes quedan como siempre."])
	elseif REINICIAR[resto] then
		M.NuevaSesion()
		N.Imprimir(L["Registro de pesca nuevo."])
	else
		N.Abrir(ID)
	end
end
