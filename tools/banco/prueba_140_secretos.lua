-- Prueba de la pasada de valores secretos de la 1.4.0 (plan 15; tools/prueba.py
-- la corre con las demás prueba_*.lua). La 1.3.7b (prueba_137b_bugs.lua) ya
-- revisa el código de src/ y motor/ y recorre Alfa con algunas funciones en
-- secreto; esta suma lo que faltaba:
--   1. Las funciones del juego que el banco no tenía (y que Alfa usa) se
--      simulan aquí, para que SECRETOS_PRENDER las pueda volver secretas.
--   2. La lista completa de lo que el juego puede dar en secreto en combate y
--      en mazmorras (la documentación de referencia/: SecretWhen*/SecretReturns,
--      más lo que Forever esconde: IsInInstance, UnitAffectingCombat...),
--      también las de tablas (C_UnitAuras, C_Spell.GetSpellCooldown).
--   3. Lo que se arregló en la 1.4.0, llamado directo con secretos: el motor
--      (parches SECRETOS_140 de tools/parches.py: Party, Maps, Death, Rest,
--      UI.FinderLine, Compat) y src/ (Corte.lua, Pesca.lua, RutaGrupo.lua).
--   4. Un recorrido entero con todo en secreto: entrar, objetivo, combate,
--      auras, grupo, mazmorra, banda, morir, cada página; sin un error.
SNAPSHOTS = {}
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 900)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.4.0 secretos", msg) end end

local A, N = Alfa, AlfaNucleo
if N.Entrando then N.Entrando = function() return false end end

---------------------------------------------------------------------------
-- 1. Las funciones que faltaban en el banco (valores de un grupo normal:
--    tú, un compañero en party1 y un enemigo de objetivo)
---------------------------------------------------------------------------
local function falta(nombre, fn) if rawget(_G, nombre) == nil then rawset(_G, nombre, fn) end end
local hayGrupo = false
local function esGrupo(u) return hayGrupo and (u == "party1" or u == "raid1") end
falta("UnitIsDead", function() return false end)
falta("UnitIsGhost", function() return false end)
falta("UnitCanAttack", function(_, u) return u == "target" end)
falta("UnitCanAssist", function(_, u) return u ~= "target" end)
falta("UnitIsFriend", function(_, u) return u ~= "target" end)
falta("UnitIsEnemy", function(_, u) return u == "target" end)
falta("UnitReaction", function(_, u) return u == "target" and 2 or 5 end)
falta("UnitIsConnected", function() return true end)
falta("UnitIsPlayer", function(u) return u == "player" or esGrupo(u) end)
falta("UnitInParty", function(u) return esGrupo(u) end)
falta("UnitInRaid", function(u) return u == "raid1" and hayGrupo and 1 or nil end)
falta("UnitIsGroupLeader", function(u) return u == "player" end)
falta("UnitIsGroupAssistant", function() return false end)
falta("UnitGroupRolesAssigned", function() return "DAMAGER" end)
falta("UnitInRange", function() return true, true end)
falta("UnitIsTapDenied", function() return false end)
falta("UnitIsVisible", function() return true end)
falta("UnitIsPVP", function() return false end)
falta("UnitClassification", function(u) return u == "target" and "rare" or "normal" end)
falta("UnitCreatureType", function(u) return u == "target" and "Bestia" or nil, u == "target" and 1 or nil end)
falta("UnitCreatureFamily", function() return nil end)
falta("UnitPowerType", function() return 1, "RAGE" end)
falta("UnitHealth", function() return 900 end)
falta("UnitHealthMax", function() return 1000 end)
falta("UnitHealthPercent", function() return 0.9 end)
falta("UnitPower", function() return 40 end)
falta("UnitPowerMax", function() return 100 end)
falta("UnitPowerPercent", function() return 0.4 end)
falta("UnitGetIncomingHeals", function() return 0 end)
falta("UnitThreatSituation", function() return 1 end)
falta("UnitDetailedThreatSituation", function() return false, 1, 60, 60, 1000 end)
falta("UnitCastingInfo", function(u)
  if u == "player" then return "Piedra de hogar", "", 134414, 1000, 11000, false, "c1", false, 8690 end
  return "Bola de fuego", "", 135812, 1000, 3000, false, "c2", false, 133
end)
falta("UnitChannelInfo", function() return nil end)
falta("GetComboPoints", function() return 2 end)
falta("GetRaidTargetIndex", function() return nil end)
falta("UnitSex", function() return 2 end)
falta("UnitRace", function() return "Orco", "Orc", 2 end)
falta("UnitFullName", function(u) return UnitName(u) end)
falta("UnitOnTaxi", function() return false end)
falta("UnitIsAFK", function() return false end)
falta("UnitIsDND", function() return false end)
falta("UnitAffectingCombat", function() return false end)
falta("UnitIsCharmed", function() return false end)
falta("UnitInVehicle", function() return false end)
falta("UnitPlayerControlled", function(u) return u == "player" or esGrupo(u) end)
falta("GetInstanceInfo", function() return "Las Minas de la Muerte", "party", 1, "Normal", 5, 0, false, 36 end)

-- Un compañero y un objetivo de verdad (UnitExists, UnitName, UnitGUID por unidad).
local exists0, name0, guid0 = UnitExists, UnitName, UnitGUID
UnitExists = function(u) return u == "player" or u == "target" or esGrupo(u) or exists0(u) end
UnitName = function(u)
  if u == "target" then return "Lobo sarnoso", nil end
  if esGrupo(u) then return "Nimzy", nil end
  return name0(u)
end
UnitGUID = function(u)
  if u == "target" then return "Creature-0-4372-0-17-3825-0000123456" end
  if esGrupo(u) then return "Player-1-0002" end
  return guid0(u)
end

-- Las auras y las recargas (tablas del juego): se guardan para volverlas secretas.
C_UnitAuras = C_UnitAuras or {}
local AURA = { spellId = 15007, name = "Mal de resurrección", icon = 136153, duration = 600, expirationTime = 700,
  auraInstanceID = 1, dispelName = "Magic", applications = 1 }
local function aura() local t = {} for k, v in pairs(AURA) do t[k] = v end return t end
for n, f in pairs({
  GetPlayerAuraBySpellID = function() return aura() end,
  GetAuraDataByIndex = function(_, i) if i == 1 then return aura() end return nil end,
  GetAuraDataBySpellName = function() return aura() end,
  GetAuraDataByAuraInstanceID = function() return aura() end,
  GetUnitAuraBySpellID = function() return aura() end,
}) do C_UnitAuras[n] = f end
C_Spell = C_Spell or {}
C_Spell.GetSpellCooldown = function() return { startTime = 100, duration = 8, isEnabled = true, modRate = 1 } end
falta("UnitIsUnit", function(a, b) return a == b end)

---------------------------------------------------------------------------
-- 2. Lo que el juego puede dar en secreto
---------------------------------------------------------------------------
local SECRETAS = { "UnitIsAFK", "UnitIsDND", "UnitOnTaxi", "UnitIsDeadOrGhost", "UnitIsDead", "UnitIsGhost",
  "UnitAffectingCombat", "UnitIsUnit", "UnitInRange", "UnitIsConnected", "UnitHealth", "UnitHealthMax",
  "UnitHealthPercent", "UnitPower", "UnitPowerMax", "UnitPowerPercent", "UnitPowerType", "UnitName", "UnitFullName",
  "UnitGUID", "UnitClass", "UnitClassBase", "UnitRace", "UnitSex", "UnitLevel", "UnitCreatureType",
  "UnitCreatureFamily", "UnitClassification", "UnitGroupRolesAssigned", "UnitInRaid", "UnitIsGroupLeader",
  "UnitIsGroupAssistant", "UnitThreatSituation", "UnitDetailedThreatSituation", "UnitCastingInfo", "UnitChannelInfo",
  "UnitIsTapDenied", "UnitGetIncomingHeals", "GetUnitSpeed", "GetComboPoints", "GetRaidTargetIndex",
  "UnitCanAttack", "UnitCanAssist", "UnitIsFriend", "UnitIsEnemy", "UnitReaction", "UnitIsPVP", "UnitIsCharmed",
  "UnitPlayerControlled", "IsInInstance", "GetInstanceInfo" }
local TABLAS = { { C_UnitAuras, { "GetPlayerAuraBySpellID", "GetAuraDataByIndex", "GetAuraDataBySpellName",
  "GetAuraDataByAuraInstanceID", "GetUnitAuraBySpellID" } }, { C_Spell, { "GetSpellCooldown" } } }
local guardadasT = {}
local function prenderTablas()
  for _, par in ipairs(TABLAS) do
    local t = par[1]
    for _, n in ipairs(par[2]) do
      local f = t[n]
      if type(f) == "function" and not guardadasT[f] then
        local orig = f
        t[n] = function(...)
          local r = { orig(...) }
          for i = 1, table.maxn(r) do if r[i] ~= nil then r[i] = SECRETO(r[i]) end end
          return unpack(r, 1, table.maxn(r))
        end
        guardadasT[t[n]] = { t, n, orig }
      end
    end
  end
end
local function apagarTablas()
  for _, g in pairs(guardadasT) do g[1][g[2]] = g[3] end
  guardadasT = {}
end
local function prender() SECRETOS_PRENDER(SECRETAS) prenderTablas() end
local function apagar() SECRETOS_APAGAR() apagarTablas() end

local function pinta() for _ = 1, 3 do RUN_TIMERS(2) end end
local function sinError(nombre, fn, ...)
  local ok, e = pcall(fn, ...)
  check(ok, nombre .. " tronó con secretos: " .. tostring(e))
  return ok, e
end

local enCombate = false
local icl = InCombatLockdown
InCombatLockdown = function() return enCombate end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(5)

---------------------------------------------------------------------------
-- 3. Lo arreglado en la 1.4.0, directo
---------------------------------------------------------------------------
step("el banco simula lo que faltaba", function()
  for _, n in ipairs(SECRETAS) do check(type(rawget(_G, n)) == "function", "el banco no tiene " .. n) end
  prender()
  check(issecretvalue(UnitHealth("player")), "UnitHealth no salió secreta")
  check(issecretvalue((UnitCastingInfo("player"))), "UnitCastingInfo no salió secreta")
  check(issecretvalue(C_UnitAuras.GetPlayerAuraBySpellID(15007)), "la aura no salió secreta")
  apagar()
  check(not issecretvalue(UnitHealth("player")), "SECRETOS_APAGAR no devolvió UnitHealth")
end)

step("motor: Compat, Party, Maps, Death, Rest y UI.FinderLine con secretos (parches SECRETOS_140)", function()
  hayGrupo = true
  prender()
  local C = A.Compat
  sinError("Compat.InCombat", C.InCombat)
  sinError("Compat.IsInInstance", C.IsInInstance)
  check(C.IsInInstance() == false, "una instancia secreta cuenta como afuera")
  sinError("Compat.IsOnTaxi", C.IsOnTaxi)
  sinError("Compat.UnitFullName(party1)", C.UnitFullName, "party1")
  local P = A.Party
  if P then
    local ok, info = sinError("Party.UnitInfo", P.UnitInfo, "party1", nil)
    if ok and type(info) == "table" then
      check(not issecretvalue(info.level) and not issecretvalue(info.class) and not issecretvalue(info.race),
        "Party.UnitInfo devolvió un secreto")
    end
    sinError("Party.NeedText", P.NeedText, { unit = "party1", name = "Nimzy", need = 2 })
  else
    NOTE("1.4.0 secretos", "no está A.Party")
  end
  local Mp = A.Maps and A.Maps.Client
  if Mp and Mp.GetInstance then sinError("Maps.Client.GetInstance", Mp.GetInstance) end
  local Q = A.QoL
  if Q and Q.Death and Q.Death.ReadSickness then sinError("QoL.Death.ReadSickness", Q.Death.ReadSickness) end
  if Q and Q.Rest then
    for _, n in ipairs({ "Refresh", "Update", "Left", "BagLeft", "Parts" }) do
      if type(Q.Rest[n]) == "function" then sinError("QoL.Rest." .. n, Q.Rest[n]) end
    end
  end
  if A.UI and A.UI.FinderLine then
    sinError("UI.FinderLine", A.UI.FinderLine, { entrance = true, status = "todo", t = "goto" })
  end
  apagar()
  hayGrupo = false
end)

step("src: Corte, Pesca y RutaGrupo con secretos", function()
  prender()
  local Co = NS_OF("Alfa_Combate")
  local Ct = Co and Co.Corte
  if Ct and Ct.Lanza then sinError("Corte.Lanza", Ct.Lanza, "target") end
  local Pe = NS_OF and NS_OF("Alfa_Pesca")
  if Pe and Pe.Pescando then sinError("Pesca.Pescando", Pe.Pescando) end
  -- La Pesca con un canal secreto: no cuenta como pesca (no se sabe).
  local cc = UnitChannelInfo
  UnitChannelInfo = function() return SECRETO("Pescar"), SECRETO(""), SECRETO(136245), SECRETO(1), SECRETO(2), SECRETO(false), SECRETO(false), SECRETO(7620) end
  if Pe and Pe.Pescando then
    local ok, si = sinError("Pesca.Pescando (canal secreto)", Pe.Pescando)
    check(not ok or si == false, "un canal secreto no es pesca")
  end
  UnitChannelInfo = cc
  apagar()
end)

---------------------------------------------------------------------------
-- 4. El recorrido con todo en secreto
---------------------------------------------------------------------------
prender()

step("entrar y cambiar de objetivo con secretos", function()
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  FIRE_EVENT("UPDATE_MOUSEOVER_UNIT")
  FIRE_EVENT("NAME_PLATE_UNIT_ADDED", "nameplate1")
  pinta()
end)

step("combate con secretos (vida, poder, auras, lanzamientos, amenaza)", function()
  enCombate = true
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  for _, u in ipairs({ "player", "target", "party1" }) do
    FIRE_EVENT("UNIT_HEALTH", u)
    FIRE_EVENT("UNIT_MAXHEALTH", u)
    FIRE_EVENT("UNIT_POWER_UPDATE", u, "MANA")
    FIRE_EVENT("UNIT_POWER_FREQUENT", u, "RAGE")
    FIRE_EVENT("UNIT_AURA", u, { isFullUpdate = true })
    FIRE_EVENT("UNIT_SPELLCAST_START", u, "Cast-1", 133)
    FIRE_EVENT("UNIT_SPELLCAST_CHANNEL_START", u, "Cast-2", 7620)
    FIRE_EVENT("UNIT_THREAT_LIST_UPDATE", u)
    FIRE_EVENT("UNIT_THREAT_SITUATION_UPDATE", u)
  end
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  FIRE_EVENT("SPELL_UPDATE_COOLDOWN")
  FIRE_EVENT("UNIT_COMBO_POINTS", "player")
  NOW = NOW + 5
  pinta()
  enCombate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  pinta()
end)

step("en grupo con secretos", function()
  hayGrupo = true
  local ig, gn = IsInGroup, GetNumGroupMembers
  IsInGroup = function() return true end
  GetNumGroupMembers = function() return 2 end
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  FIRE_EVENT("UNIT_CONNECTION", "party1", true)
  FIRE_EVENT("PARTY_LEADER_CHANGED")
  pinta()
  IsInGroup, GetNumGroupMembers = ig, gn
  hayGrupo = false
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  pinta()
end)

step("mazmorra y banda con secretos", function()
  local ii, ir, ig, gn = IsInInstance, IsInRaid, IsInGroup, GetNumGroupMembers
  IsInInstance = function() return SECRETO(true), SECRETO("party") end
  IsInGroup = function() return true end
  GetNumGroupMembers = function() return 5 end
  hayGrupo = true
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  enCombate = true
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  FIRE_EVENT("ENCOUNTER_START", 1, "Jefe", 1, 5)
  FIRE_EVENT("UNIT_HEALTH", "boss1")
  pinta()
  FIRE_EVENT("ENCOUNTER_END", 1, "Jefe", 1, 5, 1)
  enCombate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  IsInInstance = function() return SECRETO(true), SECRETO("raid") end
  IsInRaid = function() return true end
  GetNumGroupMembers = function() return 25 end
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  pinta()
  IsInInstance, IsInRaid, IsInGroup, GetNumGroupMembers = ii, ir, ig, gn
  hayGrupo = false
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  pinta()
end)

step("morir y volver con secretos", function()
  FIRE_EVENT("PLAYER_DEAD")
  FIRE_EVENT("PLAYER_ALIVE")
  FIRE_EVENT("PLAYER_UNGHOST")
  FIRE_EVENT("UNIT_AURA", "player", { isFullUpdate = true })
  pinta()
end)

step("abrir cada página con secretos", function()
  local PAGINAS = { "inicio", "rutas", "enciclopedia", "builds", "bolsas", "manada", "mazmorras", "mundo",
    "pesca", "lya", "vista", "comodidades", "comercio", "recoleccion", "combate", "curacion", "bienvenida", "questing" }
  for _, id in ipairs(PAGINAS) do
    local antes = #ERRORS
    A.Fire("SHOW_OPTIONS", id)
    pinta()
    if #ERRORS > antes then print("  (al abrir " .. id .. ")") end
  end
  local o = A.UI and A.UI.Options and A.UI.Options.frame
  if o then o:Hide() end
end)

apagar()
InCombatLockdown = icl

print(("PRUEBA: 1.4.0 secretos, %d pasos, %d funciones en secreto, %d errores"):format(pasos, #SECRETAS, #ERRORS))
print("errors: " .. #ERRORS)
