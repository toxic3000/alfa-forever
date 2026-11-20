-- Prueba de la 1.3.2, Personaje (Combate, Curación y Talentos; tools/prueba.py la corre con las demás):
--   1. Probar y «Mover marcos» de Combate cierran la ventana de Alfa (sus marcos
--      salían debajo) y dicen en tu chat cómo volver;
--   2. yendo solo en el mundo, el corte no suena (corteSonidoSolo) y el resumen
--      solo sale en peleas de 30 s o más (resumenMinSolo); la migración 4 deja
--      lo suyo a quien ya los había cambiado;
--   3. Curación sin grupo: «Tus marcos aparecen al entrar a un grupo» y «Ver
--      cómo se ven» (los marcos de ejemplo);
--   4. Talentos: «Mayús + clic: ponerlo en el chat» en el cuadro del ratón y las
--      filas del plan sin velo de botón;
--   5. «Mover marcos» / «Fijar marcos» igual en Combate y Curación; «Probar un
--      aviso» una sola vez;
--   6. el asa de los marcos de Curación crece con su texto (alemán, ruso);
--   7. el corte elige su habilidad, tecla e ícono al empezar el lanzamiento y
--      pide la recarga una vez por vuelta;
--   8. curacion.alcance y curacion.mana solo corren con marcos o en grupo.
SNAPSHOTS = {}
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.3.2 personaje", msg) end end
local function T(n) RUN_TIMERS(n or 1) end

---------------------------------------------------------------------------
-- El juego simulado: un guerrero; a ratos en grupo con un sacerdote y una druida
---------------------------------------------------------------------------
local NOMBRES = { [6552] = "Patada", [1719] = "Temeridad", [2687] = "Ira sangrienta", [2054] = "Sanar", [527] = "Disipar magia" }
local POR_NOMBRE = {}
for id, n in pairs(NOMBRES) do POR_NOMBRE[n] = id end
local SABE = { [6552] = true, [1719] = true, [2687] = true }
local cds = {}
IsPlayerSpell = function(id) return SABE[id] == true end
C_SpellBook = { IsSpellKnown = function(id) return SABE[id] == true end }
C_Spell = {
  GetSpellName = function(id) return NOMBRES[id] end,
  GetSpellInfo = function(x)
    local id = type(x) == "number" and x or POR_NOMBRE[x]
    return id and { spellID = id, name = NOMBRES[id] } or nil
  end,
  GetSpellTexture = function(id) return 100000 + (tonumber(id) or 0) end,
  IsSpellUsable = function(id) return SABE[id] == true, false end,
  IsSpellInRange = function() return true end,
  GetSpellCooldown = function(id)
    return cds[id] or { startTime = 0, duration = 0, isEnabled = true, isActive = false, modRate = 1, isOnGCD = false }
  end,
}
for i = 1, 12 do
  local b = rawget(_G, "ActionButton" .. i) or CreateFrame("CheckButton", "ActionButton" .. i, UIParent)
  b.action = i
  b:Show()
end
C_ActionBar = C_ActionBar or {}
C_ActionBar.FindSpellActionButtons = function(id) return id == 6552 and { 1 } or {} end
GetBindingKey = function(accion) return accion == "ACTIONBUTTON1" and "F" or nil end

local CLASES = { player = "WARRIOR", party1 = "PRIEST", party2 = "DRUID" }
local unidades = {}
local lanza = {}
local grupo, instancia, combate = false, false, false
UnitClass = function(u) local c = CLASES[u] if c then return c, c, 1 end return nil end
UnitName = function(u) return ({ player = "Lobato", party1 = "Colmillo", party2 = "Luna" })[u], nil end
UnitExists = function(u) if u == "party1" or u == "party2" then return grupo end return unidades[u] == true or u == "player" end
UnitCanAttack = function(_, u) return u == "target" or u == "focus" end
UnitIsDeadOrGhost = function() return false end
UnitIsUnit = function(a, b) return a == b end
UnitHealth = function() return 100 end
UnitHealthMax = function() return 100 end
UnitPower = function() return 50 end
UnitPowerMax = function() return 100 end
UnitGroupRolesAssigned = function() return "NONE" end
GetNumGroupMembers = function() return grupo and 3 or 0 end
GetShapeshiftFormID = function() return nil end
UnitCastingInfo = function(u)
  local c = lanza[u]
  if not c then return nil end
  return c.nombre, c.nombre, 136197, NOW * 1000, (NOW + 2) * 1000, false, "Cast-1", false, 686
end
UnitChannelInfo = function() return nil end
InCombatLockdown = function() return combate end
UnitAffectingCombat = function() return combate end
IsInGroup = function() return grupo end
IsInRaid = function() return false end
IsInInstance = function() return instancia, instancia and "party" or "none" end
UnitDetailedThreatSituation = function() return false, 0, 0, 0, 0 end
C_UnitAuras = {
  GetUnitAuraInstanceIDs = function() return {} end,
  GetAuraDataByAuraInstanceID = function() return nil end,
  GetAuraDataBySpellName = function() return nil end,
}
Enum.DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6,
  DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 }
Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }
C_DamageMeter = {
  IsDamageMeterAvailable = function() return true, "" end,
  GetCombatSessionFromType = function(_, tipo)
    local f = tipo == 0 and { { name = "Lobato", isLocalPlayer = true, totalAmount = 9000, amountPerSecond = 300 } } or {}
    return { combatSources = f, maxAmount = 1, totalAmount = 1, durationSeconds = 30 }
  end,
  GetCombatSessionFromID = function() return { combatSources = {} } end,
  GetAvailableCombatSessions = function() return {} end,
  GetSessionDurationSeconds = function() return nil end,
  GetCombatSessionSourceFromType = function() return { combatSpells = {}, maxAmount = 1, totalAmount = 1 } end,
}

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
local A, N = Alfa, AlfaNucleo
local K = N.Kit
local Co = NS_OF("Alfa_Combate")
local Cu = NS_OF("Alfa_Curacion")
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local sonidos = 0
local tocar = A.PlaySound
A.PlaySound = function(...) sonidos = sonidos + 1 if tocar then return tocar(...) end end
local dicho = {}
local imprimir = N.Imprimir
N.Imprimir = function(t, ...) dicho[#dicho + 1] = tostring(t) return imprimir(t, ...) end
local function dijo(trozo)
  for _, t in ipairs(dicho) do if t:find(trozo, 1, true) then return true end end
  return false
end

local function texto(fs) return fs and fs.GetText and tostring(fs:GetText() or "") or "" end
local function visible(f) return f and f:IsShown() and true or false end
local function ventana() local O = A.UI and A.UI.Options return O and O.frame end
local function abierta() local v = ventana() return v and v:IsShown() and true or false end
local function abrir(id) A.Fire("SHOW_OPTIONS", id) T(2) end
-- Los botones a la vista con ese texto.
local function botones(t)
  local out = {}
  for _, f in ipairs(ALL_FRAMES()) do
    local tx = rawget(f, "Texto")
    if type(tx) == "table" and tx.GetText and tx:GetText() == t and f:IsVisible() then out[#out + 1] = f end
  end
  return out
end
local function boton(t) return botones(t)[1] end
local function aLaVistaTexto(t)
  for _, f in ipairs(ALL_FRAMES()) do
    if f.GetText and f:IsVisible() and f:GetText() == t then return true end
  end
  return false
end
-- (Sin correr los relojes: el banco correría también los que esconden lo que se prueba.)
local function clic(b) if b then b:Click("LeftButton") end end
local function entrar() combate = true FIRE_EVENT("PLAYER_REGEN_DISABLED") end
local function salir() combate = false FIRE_EVENT("PLAYER_REGEN_ENABLED") end

---------------------------------------------------------------------------
-- 1 y 5. Combate: probar y mover a la vista; los mismos nombres
---------------------------------------------------------------------------
step("Combate: «Probar el aviso» cierra la ventana y dice cómo volver", function()
  abrir("combate")
  check(abierta(), "la ventana de Alfa no se abrió en Combate")
  local b = boton("Probar el aviso")
  check(b, "no está el botón «Probar el aviso»")
  dicho = {}
  clic(b)
  check(not abierta(), "«Probar el aviso» dejó la ventana abierta (el aviso sale debajo)")
  check(visible(rawget(_G, "AlfaCombateCorte")), "no salió el aviso de prueba")
  check(dijo("/alfa combate"), "no dijo en tu chat cómo volver a Combate")
  -- Probar un aviso de reacción, igual.
  abrir("combate")
  check(#botones("Probar un aviso") == 1, "«Probar un aviso» sale " .. #botones("Probar un aviso") .. " veces (una sola)")
  dicho = {}
  clic(boton("Probar un aviso"))
  check(not abierta() and dijo("/alfa combate"), "«Probar un aviso» no cerró la ventana o no dijo cómo volver")
end)

step("Combate: «Mover marcos» / «Fijar marcos», con la ventana cerrada para verlos", function()
  abrir("combate")
  check(not aLaVistaTexto("Mover el ícono") and not aLaVistaTexto("Listo, fijarlos"), "siguen los nombres viejos «Mover el ícono» / «Listo, fijarlos»")
  local b = boton("Mover marcos")
  check(b, "Combate no tiene «Mover marcos»")
  dicho = {}
  clic(b)
  check(Co.Desbloqueado(), "«Mover marcos» no desbloqueó los marcos")
  check(not abierta(), "al mover, la ventana tapa los marcos")
  check(dijo("/alfa combate mover"), "no dijo cómo fijarlos")
  abrir("combate")
  check(boton("Fijar marcos"), "moviendo, Combate no ofrece «Fijar marcos»")
  clic(boton("Fijar marcos"))
  check(not Co.Desbloqueado(), "«Fijar marcos» no los fijó")
  -- En combate no se mueven: la ventana se queda.
  abrir("combate")
  combate = true
  clic(boton("Mover marcos"))
  check(not Co.Desbloqueado() and abierta(), "en combate se movieron o se cerró la ventana")
  combate = false
  local v = ventana() if v then v:Hide() end
end)

---------------------------------------------------------------------------
-- 2. Solo en el mundo: sin sonido de corte y solo las peleas largas
---------------------------------------------------------------------------
step("Solo: el corte no suena; en grupo o instancia sí; con «También yendo solo», también", function()
  check(A.Get("combate.corteSonidoSolo") == false, "combate.corteSonidoSolo no viene apagado")
  check(A.Get("combate.resumenMinSolo") == 30, "combate.resumenMinSolo no viene en 30")
  unidades.target = true
  local function lanzar()
    lanza.target = nil
    FIRE_EVENT("UNIT_SPELLCAST_STOP", "target")
    lanza.target = { nombre = "Descarga de las Sombras" }
    NOW = NOW + 3 -- otro lanzamiento, otro momento
    local antes = sonidos
    FIRE_EVENT("UNIT_SPELLCAST_START", "target")
    return sonidos - antes
  end
  check(lanzar() == 0, "yendo solo, el corte sonó")
  grupo = true
  check(lanzar() == 1, "en grupo, el corte no sonó")
  grupo, instancia = false, true
  check(lanzar() == 1, "en una instancia, el corte no sonó")
  instancia = false
  A.Set("combate.corteSonidoSolo", true)
  check(lanzar() == 1, "con «También yendo solo», el corte no sonó")
  A.Set("combate.corteSonidoSolo", false)
  lanza.target, unidades.target = nil, nil
  FIRE_EVENT("UNIT_SPELLCAST_STOP", "target")
end)

step("Solo: el resumen solo sale en peleas de 30 s o más; en grupo, desde 10 s", function()
  local function pelea(seg)
    local f = rawget(_G, "AlfaCombateResumen")
    if f then f:Hide() end
    NOW = NOW + 10
    entrar()
    NOW = NOW + seg
    salir()
    T(1) -- (una vuelta: la segunda correría también el que la esconde)
    f = rawget(_G, "AlfaCombateResumen")
    return visible(f)
  end
  check(not pelea(20), "yendo solo, salió el resumen de una pelea de 20 s")
  check(pelea(35), "yendo solo, no salió el resumen de una pelea de 35 s")
  grupo = true
  check(pelea(15), "en grupo, no salió el resumen de una pelea de 15 s")
  grupo = false
end)

step("Migración 4: quien ya había cambiado el sonido o el mínimo conserva lo suyo", function()
  check(type(Co.Migracion132) == "function", "falta el paso de la migración 4 (Co.Migracion132)")
  local db = A.DB and A.DB()
  check(db and type(db.alfaMigraciones) == "table" and db.alfaMigraciones[4] == true, "la migración 4 no se anotó como hecha")
  local viejo = { settings = { combate = { corteSonido = true, resumenMin = 0 } } }
  Co.Migracion132(viejo)
  check(viejo.settings.combate.corteSonidoSolo == true, "con el sonido prendido a mano, no siguió sonando solo")
  check(viejo.settings.combate.resumenMinSolo == 0, "con su mínimo de 0 s, el de solo no quedó igual")
  local nuevo = { settings = { combate = {} } }
  Co.Migracion132(nuevo)
  check(nuevo.settings.combate.corteSonidoSolo == nil and nuevo.settings.combate.resumenMinSolo == nil, "a quien no tocó nada le escribió ajustes")
  local apagado = { settings = { combate = { corteSonido = false } } }
  Co.Migracion132(apagado)
  check(apagado.settings.combate.corteSonidoSolo == nil, "con el sonido apagado le prendió el de solo")
  Co.Migracion132({})
end)

---------------------------------------------------------------------------
-- 3. Curación sin grupo
---------------------------------------------------------------------------
step("Curación sin grupo: dice cuándo aparecen y ofrece verlos", function()
  grupo = false
  N.Set("curacion", "solo", false)
  abrir("curacion")
  check(aLaVistaTexto("Tus marcos aparecen al entrar a un grupo"), "sin grupo no dice cuándo aparecen tus marcos")
  check(aLaVistaTexto("Sin grupo") and boton("Configurar con el asistente"), "sin grupo se perdió la insignia o el asistente")
  local b = boton("Ver cómo se ven")
  check(b, "no está «Ver cómo se ven»")
  clic(b)
  check(Cu.EnPrueba() == 5, "«Ver cómo se ven» no puso los 5 marcos de ejemplo")
  Cu.Prueba(nil)
  Cu.Mover(false)
  -- En grupo, otra vez lo de siempre, con «Mover marcos».
  grupo = true
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  T(1)
  check(not aLaVistaTexto("Tus marcos aparecen al entrar a un grupo"), "en grupo sigue diciendo que aparecen al entrar a uno")
  check(boton("Mover marcos"), "Curación en grupo no tiene «Mover marcos»")
  -- Solo, con «Verte a ti estando solo», tampoco.
  grupo = false
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  N.Set("curacion", "solo", true)
  T(1)
  check(not aLaVistaTexto("Tus marcos aparecen al entrar a un grupo"), "con «Verte a ti estando solo» sigue el aviso de sin grupo")
  N.Set("curacion", "solo", false)
  local v = ventana() if v then v:Hide() end
end)

---------------------------------------------------------------------------
-- 4. Talentos
---------------------------------------------------------------------------
step("Talentos: el cuadro dice Mayús + clic y las filas no parecen botón", function()
  local lineas = {}
  local add = GameTooltip.AddLine
  GameTooltip.AddLine = function(self, t, ...) lineas[#lineas + 1] = tostring(t) end
  abrir("builds")
  local filas, nodos, sinHint, conVelo = 0, 0, 0, 0
  for _, f in ipairs(ALL_FRAMES()) do
    if rawget(f, "spell") and f:IsVisible() and f.GetScript and f:GetScript("OnEnter") then
      local esFila = rawget(f, "Por") ~= nil
      if esFila then filas = filas + 1 else nodos = nodos + 1 end
      if esFila and rawget(f, "velo") then conVelo = conVelo + 1 end
      lineas = {}
      f:GetScript("OnEnter")(f)
      local hay = false
      for _, l in ipairs(lineas) do if l == "Mayús + clic: ponerlo en el chat" then hay = true end end
      if not hay then sinHint = sinHint + 1 end
      if f:GetScript("OnLeave") then f:GetScript("OnLeave")(f) end
    end
  end
  GameTooltip.AddLine = add
  check(filas > 0 and nodos > 0, ("no encontré filas del plan (%d) o talentos del árbol (%d)"):format(filas, nodos))
  check(sinHint == 0, sinHint .. " talentos no dicen «Mayús + clic: ponerlo en el chat»")
  check(conVelo == 0, conVelo .. " filas del plan siguen con el velo de botón")
  local v = ventana() if v then v:Hide() end
end)

---------------------------------------------------------------------------
-- 6. El asa de los marcos de Curación
---------------------------------------------------------------------------
step("El asa crece con su texto: nada se corta en alemán ni en ruso", function()
  Cu.Mover(true)
  local asa = Cu.asa
  check(asa and asa:IsShown(), "no salió el asa al mover los marcos de Curación")
  if not asa then return end
  check(asa.caja and asa.listo and asa.listo.Texto, "el asa no está hecha con el Kit (caja y botón)")
  for _, t in ipairs({ "Curación: arrastra para mover", "Heilung: zum Verschieben ziehen",
      "Исцеление: перетащите, чтобы передвинуть", "Тест на 20: перетащите, чтобы передвинуть" }) do
    Cu.TextoAsa(t)
    local w = K.AnchoTexto(asa.texto)
    local libre = asa:GetWidth() - 10 - asa.listo:GetWidth() - 3
    check(w <= asa.texto:GetWidth() + 0.5 and w <= libre, ("«%s» no cabe en el asa (%d px de texto, %d libres)"):format(t, w, libre))
  end
  Cu.Mover(false)
end)

---------------------------------------------------------------------------
-- 7. El corte elige al empezar el lanzamiento
---------------------------------------------------------------------------
step("Corte: habilidad, tecla e ícono al empezar; la recarga una vez por vuelta", function()
  local habil, teclas, faltas, vueltas = 0, 0, 0, 0
  local oH, oT, oF, oR = Co.Corte.Habilidad, Co.Rotacion.Tecla, Co.Recargas.Falta, Co.Corte.Revisar
  Co.Corte.Habilidad = function(...) habil = habil + 1 return oH(...) end
  Co.Rotacion.Tecla = function(...) teclas = teclas + 1 return oT(...) end
  Co.Recargas.Falta = function(...) faltas = faltas + 1 return oF(...) end
  Co.Corte.Revisar = function(...) vueltas = vueltas + 1 return oR(...) end
  unidades.target = true
  lanza.target = { nombre = "Descarga de las Sombras" }
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  T(3)
  local f = rawget(_G, "AlfaCombateCorte")
  check(visible(f), "no salió el aviso para cortar")
  check(vueltas >= 2, "el reloj del aviso no dio vueltas: " .. vueltas)
  check(habil == 1, "eligió la habilidad " .. habil .. " veces en un solo lanzamiento")
  check(teclas == 1, "buscó la tecla " .. teclas .. " veces en un solo lanzamiento")
  check(faltas == vueltas, ("pidió la recarga %d veces en %d vueltas (una por vuelta)"):format(faltas, vueltas))
  check(f and texto(f.Linea):find("pulsa F", 1, true), "el aviso perdió la tecla: " .. texto(f and f.Linea))
  -- Cambias tus barras: se vuelve a buscar la tecla.
  FIRE_EVENT("ACTIONBAR_SLOT_CHANGED", 1)
  T(1)
  check(teclas == 2, "al cambiar tus barras no volvió a buscar la tecla: " .. teclas)
  -- Un lanzamiento nuevo: se vuelve a elegir.
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  check(habil == 3, "un lanzamiento nuevo no volvió a elegir la habilidad: " .. habil)
  Co.Corte.Habilidad, Co.Rotacion.Tecla, Co.Recargas.Falta, Co.Corte.Revisar = oH, oT, oF, oR
  lanza.target, unidades.target = nil, nil
  FIRE_EVENT("UNIT_SPELLCAST_STOP", "target")
end)

---------------------------------------------------------------------------
-- 8. Los relojes de Curación
---------------------------------------------------------------------------
step("curacion.alcance y curacion.mana solo corren con marcos o en grupo", function()
  grupo = false
  N.Set("curacion", "solo", false)
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  T(1)
  check(not N.HayTarea("curacion.alcance"), "sin marcos ni grupo sigue el reloj curacion.alcance")
  check(not N.HayTarea("curacion.mana"), "sin grupo sigue el reloj curacion.mana")
  grupo = true
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  T(1)
  check(N.HayTarea("curacion.alcance") and N.HayTarea("curacion.mana"), "en grupo no volvieron los relojes de Curación")
  grupo = false
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  N.Set("curacion", "solo", true)
  T(1)
  check(N.HayTarea("curacion.alcance"), "con «Verte a ti estando solo» no corre el alcance")
  check(not N.HayTarea("curacion.mana"), "solo, con tu marco, corre el maná")
  N.Set("curacion", "activo", false)
  T(1)
  check(not N.HayTarea("curacion.alcance"), "con los marcos apagados sigue el alcance")
  N.Set("curacion", "activo", true)
  N.Set("curacion", "solo", false)
  T(1)
  check(not N.HayTarea("curacion.alcance"), "al volver a solo sin marcos sigue el alcance")
end)

print(string.format("PRUEBA: 1.3.2 personaje, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
