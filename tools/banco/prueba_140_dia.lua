-- Prueba de la 1.4.0 (plan 75): un día de juego completo, como lo juega
-- cualquiera, con lo que el juego esconde en combate y en mazmorras en
-- secreto (SECRETOS_PRENDER). tools/prueba.py la corre con las demás.
--   entrar · seguir la guía · tomar y entregar misiones · «Cerrar mis
--   misiones» · viajar en barco · recolectar con ruta · combate · mazmorra ·
--   morir y revivir · bolsas (ordenar, vender) · pesca · Dos pantallas ida y
--   vuelta · /reload · salir; y los relojes corriendo un buen rato.
-- Falla con cualquier error de Lua, con una acción que el juego bloquearía
-- (ADDON_ACTION_BLOCKED: un marco protegido tocado en combate, una función
-- restringida, algo mandado solo al chat de otros) y si los marcos, los
-- ganchos o los relojes crecen de un día al siguiente (fugas).
local pasos = 0
local DIAS = 7
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
local function check(cond, msg) if not cond then NOTE("1.4.0 dia", msg) end end
local function T(n) for _ = 1, n or 2 do RUN_TIMERS(2) end end

PANTALLA_SIMULADA(3840, 1080)

---------------------------------------------------------------------------
-- El juego de mentira: lo que el banco no trae
---------------------------------------------------------------------------
local function falta(nombre, fn) if rawget(_G, nombre) == nil then rawset(_G, nombre, fn) end end
local enCombate, muerto, fantasma, adentro, enGrupo = false, false, false, false, false
local function esGrupo(u) return enGrupo and (u == "party1" or u == "raid1") end
falta("UnitIsDead", function(u) return u == "player" and muerto and not fantasma end)
falta("UnitIsGhost", function(u) return u == "player" and fantasma end)
UnitIsDeadOrGhost = function(u) return u == "player" and (muerto or fantasma) end
falta("UnitCanAttack", function(_, u) return u == "target" end)
falta("UnitCanAssist", function(_, u) return u ~= "target" end)
falta("UnitIsFriend", function(_, u) return u ~= "target" end)
falta("UnitIsEnemy", function(_, u) return u == "target" end)
falta("UnitReaction", function(_, u) return u == "target" and 2 or 5 end)
falta("UnitIsConnected", function() return true end)
falta("UnitIsPlayer", function(u) return u == "player" or esGrupo(u) end)
falta("UnitInParty", function(u) return esGrupo(u) end)
falta("UnitInRaid", function() return nil end)
falta("UnitIsGroupLeader", function(u) return u == "player" end)
falta("UnitIsGroupAssistant", function() return false end)
falta("UnitGroupRolesAssigned", function() return "DAMAGER" end)
falta("UnitInRange", function() return true, true end)
falta("UnitIsTapDenied", function() return false end)
falta("UnitIsVisible", function() return true end)
falta("UnitIsPVP", function() return false end)
falta("UnitClassification", function(u) return u == "target" and "elite" or "normal" end)
falta("UnitCreatureType", function(u) return u == "target" and "Bestia" or nil end)
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
falta("UnitCastingInfo", function() return nil end)
falta("UnitChannelInfo", function() return nil end)
falta("GetComboPoints", function() return 0 end)
falta("GetRaidTargetIndex", function() return nil end)
falta("UnitIsUnit", function(a, b) return a == b end)
falta("UnitPlayerControlled", function(u) return u == "player" or esGrupo(u) end)
falta("UnitIsCharmed", function() return false end)
falta("UnitIsAFK", function() return false end)
falta("UnitIsDND", function() return false end)
falta("GetInstanceInfo", function()
  if adentro then return "Las Minas de la Muerte", "party", 1, "Normal", 5, 0, false, 36 end
  return "Kalimdor", "none", 0, "", 0, 0, false, 1
end)
UnitAffectingCombat = function(u) return u == "player" and enCombate end
InCombatLockdown = function() return enCombate end
IsInInstance = function() if adentro then return true, "party" end return false, "none" end
IsInGroup = function() return enGrupo end
GetNumGroupMembers = function() return enGrupo and (adentro and 5 or 2) or 0 end
local exists0, name0, guid0 = UnitExists, UnitName, UnitGUID
local hayObjetivo = false
UnitExists = function(u) return u == "player" or (u == "target" and hayObjetivo) or esGrupo(u) or exists0(u) end
UnitName = function(u)
  if u == "target" and hayObjetivo then return "Jabaespín guardián", nil end
  if esGrupo(u) then return "Nimzy", nil end
  return name0(u)
end
UnitGUID = function(u)
  if u == "target" and hayObjetivo then return "Creature-0-4372-0-17-3113-0000123456" end
  if esGrupo(u) then return "Player-1-0002" end
  return guid0(u)
end

-- Posición del jugador (Durotar) que cambia durante el día.
local PX, PY, MAPA = 0.52, 0.44, 1411
C_Map.GetBestMapForUnit = function() return MAPA end
C_Map.GetPlayerMapPosition = function() return { x = PX, y = PY, GetXY = function() return PX, PY end } end
local function caminar(dx, dy) PX, PY = PX + (dx or 0.01), PY + (dy or 0.005) end

-- Las misiones del registro.
local LOG, ORDEN, HECHAS = {}, {}, {}
local function poner(q, listo)
  if not LOG[q] then ORDEN[#ORDEN + 1] = q end
  LOG[q] = { listo = listo, objs = { { text = "Jabaespín: " .. (listo and 5 or 0) .. "/5", type = "monster", finished = listo, numFulfilled = listo and 5 or 0, numRequired = 5 } } }
end
local function quitar(q)
  LOG[q] = nil
  for i, x in ipairs(ORDEN) do if x == q then table.remove(ORDEN, i) break end end
end
local QL = C_QuestLog
QL.IsOnQuest = function(q) return LOG[q] ~= nil end
QL.ReadyForTurnIn = function(q) return LOG[q] ~= nil and LOG[q].listo or false end
QL.IsComplete = function(q) return LOG[q] ~= nil and LOG[q].listo or false end
QL.IsFailed = function() return false end
QL.GetQuestObjectives = function(q) return LOG[q] and LOG[q].objs or {} end
QL.GetNumQuestLogEntries = function() return #ORDEN, #ORDEN end
QL.GetInfo = function(i) local q = ORDEN[i] return q and { questID = q, title = "Misión " .. q, isHeader = false, isHidden = false, level = 23 } or nil end
QL.GetLogIndexForQuestID = function(q) for i, x in ipairs(ORDEN) do if x == q then return i end end return nil end
QL.IsQuestFlaggedCompleted = function(q) return HECHAS[q] or false end
QL.GetTitleForQuestID = function(q) return LOG[q] and ("Misión " .. q) or nil end
QL.GetQuestDifficultyLevel = function() return 23 end

-- Las bolsas: la mochila con chatarra, una poción y la caña.
local OBJ = {
  [6948] = { "Piedra de hogar", 1, 1, 0, 15, 0, "" },
  [4865] = { "Garra rota", 0, 1, 5, 15, 0, "" },
  [2589] = { "Lino", 1, 20, 2, 7, 5, "" },
  [118] = { "Poción de sanación menor", 1, 5, 1, 0, 1, "" },
  [6256] = { "Caña de pescar", 1, 1, 20, 2, 20, "INVTYPE_2HWEAPON" },
  [2775] = { "Mena de plata", 2, 20, 75, 7, 23, "" },
}
local function enlace(id)
  local o = OBJ[id]
  return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. (o and o[1] or "?") .. "]|h|r"
end
local function idDe(x) return tonumber(x) or tonumber(tostring(x):match("item:(%d+)")) end
C_Item.GetItemInfo = function(x)
  local id = idDe(x)
  local o = id and OBJ[id]
  if not o then return nil end
  return o[1], enlace(id), o[2], 20, 1, "Tipo", "Subtipo", o[3], o[7], 134400 + id % 50, o[4], o[5], o[6]
end
GetItemInfo = C_Item.GetItemInfo
local bolsa = {}
local function cosa(id, n) return { itemID = id, stackCount = n or 1, quality = OBJ[id][2], hyperlink = enlace(id), isLocked = false } end
local function llenar() bolsa = { [1] = cosa(4865), [2] = cosa(2589, 5), [3] = cosa(118, 3), [4] = cosa(6948), [5] = cosa(4865) } end
llenar()
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end
C_Container.GetContainerNumFreeSlots = function(b)
  if b ~= 0 then return 0, 0 end
  local libres = 0
  for s = 1, 16 do if not bolsa[s] then libres = libres + 1 end end
  return libres, 0
end
C_Container.GetContainerItemInfo = function(b, s) return b == 0 and bolsa[s] or nil end
C_Container.GetContainerItemLink = function(b, s) local i = b == 0 and bolsa[s] return i and i.hyperlink or nil end
C_Container.GetContainerItemID = function(b, s) local i = b == 0 and bolsa[s] return i and i.itemID or nil end
C_Container.GetContainerItemQuestInfo = function() return { isQuestItem = false } end
C_Container.GetContainerItemCooldown = function() return 0, 0, 0 end
local vendidos, tiendaAbierta = 0, false
C_Container.UseContainerItem = function(b, s)
  if b == 0 and bolsa[s] and tiendaAbierta then bolsa[s] = nil vendidos = vendidos + 1 end
end
C_Container.PickupContainerItem = function() end

---------------------------------------------------------------------------
-- Lo que el juego bloquearía (ADDON_ACTION_BLOCKED)
---------------------------------------------------------------------------
-- Un marco seguro (plantilla Secure*) tocado en combate: en el juego sale
-- «Alfa_X se ha bloqueado de una acción...».
local seguros = setmetatable({}, { __mode = "k" })
local creaFrame = CreateFrame
CreateFrame = function(kind, name, parent, template)
  local f = creaFrame(kind, name, parent, template)
  if type(template) == "string" and template:find("Secure", 1, true) then seguros[f] = true end
  if rastrear then origen[f] = quien() end
  return f
end
local mt = getmetatable(creaFrame("Frame"))
local indice0 = mt.__index
local PROTEGIDAS = { SetAttribute = true, Show = true, Hide = true, SetPoint = true, ClearAllPoints = true,
  SetSize = true, SetWidth = true, SetHeight = true, SetParent = true, SetShown = true, EnableMouse = true }
local cuenta = { ganchos = 0, scripts = 0 }
local envoltura = {}
-- Con BANCO_DIA_FUGAS=1, quién crea cada marco o textura nueva del último día.
local FUGAS = os and os.getenv and os.getenv("BANCO_DIA_FUGAS")
local origen = setmetatable({}, { __mode = "k" })
local rastrear = false
local function quien()
  local s = debug.traceback("", 3)
  local out = {}
  for l in s:gmatch("[^\n]+") do
    if (l:find("Alfa", 1, true)) and not l:find("prueba_140_dia", 1, true) then out[#out + 1] = l:gsub("^%s+", "") if #out >= 7 then break end end
  end
  return table.concat(out, " < ")
end
local CREAN = { CreateTexture = true, CreateFontString = true, CreateLine = true, CreateMaskTexture = true }
mt.__index = function(t, k)
  local v = indice0(t, k)
  if type(v) ~= "function" then return v end
  if rastrear and CREAN[k] then
    return function(self, ...) local o = v(self, ...) origen[o] = quien() return o end
  end
  if k == "HookScript" then
    envoltura.HookScript = envoltura.HookScript or function(self, ...) cuenta.ganchos = cuenta.ganchos + 1 return v(self, ...) end
    return envoltura.HookScript
  end
  if PROTEGIDAS[k] and seguros[t] then
    envoltura[k] = envoltura[k] or function(self, ...)
      if enCombate and seguros[self] then NOTE("ADDON_ACTION_BLOCKED", k .. " en un marco seguro en combate (" .. tostring(rawget(self, "_name")) .. ")\n" .. debug.traceback("", 2)) end
      return v(self, ...)
    end
    return envoltura[k]
  end
  return v
end
local hsf = hooksecurefunc
hooksecurefunc = function(...) cuenta.ganchos = cuenta.ganchos + 1 return hsf(...) end
-- Funciones restringidas (HasRestrictions): solo con un clic del jugador.
local function restringida(nombre)
  return function() NOTE("ADDON_ACTION_BLOCKED", nombre .. " llamada sin un clic del jugador\n" .. debug.traceback("", 2)) end
end
SetRaidTarget = restringida("SetRaidTarget")
C_Club = C_Club or {}
C_Club.SendCharacterInvitation = restringida("C_Club.SendCharacterInvitation")
-- Nada se manda solo al chat de otros (REGLAS-BLIZZARD.md, regla 3).
SendChatMessage = function(_, canal)
  NOTE("ADDON_ACTION_BLOCKED", "SendChatMessage al canal " .. tostring(canal) .. " sin pedirlo\n" .. debug.traceback("", 2))
end
-- Los tickers del juego que siguen vivos (C_Timer.NewTicker sin Cancel).
local tickers = setmetatable({}, { __mode = "k" })
local nt = C_Timer.NewTicker
C_Timer.NewTicker = function(s, fn, ...)
  local t = nt(s, fn, ...)
  tickers[t] = true
  return t
end
local function tickersVivos()
  local n = 0
  for t in pairs(tickers) do if not t.cancelled then n = n + 1 end end
  return n
end

---------------------------------------------------------------------------
-- Los secretos: lo que el juego esconde en combate y en mazmorras
---------------------------------------------------------------------------
local SECRETAS = { "UnitHealth", "UnitHealthMax", "UnitHealthPercent", "UnitPower", "UnitPowerMax", "UnitPowerPercent",
  "UnitName", "UnitGUID", "UnitLevel", "UnitClass", "UnitRace", "UnitIsUnit", "UnitInRange", "UnitIsDeadOrGhost",
  "UnitIsDead", "UnitIsGhost", "UnitAffectingCombat", "UnitThreatSituation", "UnitDetailedThreatSituation",
  "UnitCastingInfo", "UnitChannelInfo", "UnitClassification", "UnitCreatureType", "UnitReaction", "UnitCanAttack",
  "UnitIsFriend", "UnitIsEnemy", "UnitGroupRolesAssigned", "UnitIsGroupLeader", "GetUnitSpeed", "GetComboPoints",
  "GetRaidTargetIndex", "IsInInstance", "GetInstanceInfo" }
local prendidos = false
local function prender() if not prendidos then SECRETOS_PRENDER(SECRETAS) prendidos = true end end
local function apagar() if prendidos then SECRETOS_APAGAR() prendidos = false end end

---------------------------------------------------------------------------
-- Entrar
---------------------------------------------------------------------------
AlfaNucleoCharDB = AlfaNucleoCharDB or {}
Alfa.Hidden = Alfa.Hidden or function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
local A, N = Alfa, AlfaNucleo
local K = N.Kit
local E = A.Engine
local Ru = NS_OF("Alfa_Rutas")
local B = NS_OF("Alfa_Bolsas")
local Bv = NS_OF("Alfa_Bienvenida")
local Rc = NS_OF("Alfa_Recoleccion")
local Nav = NS_OF("Alfa").Nav

step("el detector de acciones bloqueadas funciona", function()
  local f = CreateFrame("Button", "PruebaDiaSeguro", UIParent, "SecureActionButtonTemplate")
  local antes = #ERRORS
  enCombate = true
  f:Show()
  f:SetAttribute("type", "macro")
  enCombate = false
  check(#ERRORS == antes + 2, "el detector de ADDON_ACTION_BLOCKED no ve un marco seguro tocado en combate")
  for i = #ERRORS, antes + 1, -1 do table.remove(ERRORS, i) end
end)

-- El mundo: cada mapa, un cuadro de 4000 yardas en su propio continente
-- (como prueba_139_oficios), desde antes de entrar.
do
  local Cp = Alfa.Compat
  Cp.MapToWorld = function(mapa, x, y) if type(mapa) ~= "number" then return nil end return mapa, (y or 0) * 40, (x or 0) * 40 end
  Cp.GetPlayerWorldPosition = function() return MAPA, PY * 4000, PX * 4000 end
end

step("entrar", function()
  FIRE_EVENT("ADDON_LOADED", "Alfa")
  FIRE_EVENT("PLAYER_LOGIN")
  local BvG = rawget(_G, "AlfaBienvenida")
  N.Datos("bienvenida").respondio = BvG and BvG.VERSION or 99
  N.Datos("bienvenida").versionVista = BvG and BvG.VersionAlfa and BvG.VersionAlfa() or "9.9.9"
  N.Datos("bienvenida").recorrido = true
  FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
  T(8)
  if A.UI.Options.frame then A.UI.Options.frame:Hide() end
end)

---------------------------------------------------------------------------
-- El día
---------------------------------------------------------------------------
local QA, QB = 790, 804 -- dos misiones de Durotar
local guiaId
local function guia()
  if guiaId then Ru.Guias.Abrir(guiaId) T(2) return end
  local p = {
    { title = "Ve con el PNJ", goals = { { t = "goto", map = MAPA, x = 52, y = 44, text = "Ve al Valle de los Retos" } } },
    { title = "Toma la misión", goals = { { t = "accept", quest = QA, title = "Misión " .. QA, npc = 3143, npcName = "Gornek", map = MAPA, x = 42, y = 68 } } },
    { title = "Caza", goals = { { t = "goto", map = MAPA, x = 47, y = 52, text = "Caza jabaespines" } } },
    { title = "Entrega", goals = { { t = "turnin", quest = QA, title = "Misión " .. QA, npc = 3143, npcName = "Gornek", map = MAPA, x = 42, y = 68 } } },
  }
  local id = Ru.Guias.IdRuta("prueba140-dia")
  local ok, err = Ru.Guias.Instalar(Ru.Guias.Def(id, "prueba140-dia", p))
  check(ok, "no se instaló la guía del día: " .. tostring(err))
  guiaId = id
  Ru.Guias.Abrir(id) T(3)
end

local function registro() FIRE_EVENT("QUEST_LOG_UPDATE") T(2) end

local function unDia(n)
  step("día " .. n .. ": seguir la guía y tomar una misión", function()
    guia()
    if n == 1 then check(E.GetGuide and E.GetGuide() ~= nil, "no hay guía activa") end
    for _ = 1, 4 do caminar(-0.01, 0.02) T(1) end
    poner(QA, false)
    FIRE_EVENT("QUEST_ACCEPTED", QA)
    registro()
    if E.Skip then E.Skip() end
    T(2)
  end)

  step("día " .. n .. ": combate (con secretos)", function()
    hayObjetivo = true
    FIRE_EVENT("PLAYER_TARGET_CHANGED")
    prender()
    enCombate = true
    FIRE_EVENT("PLAYER_REGEN_DISABLED")
    for _ = 1, 5 do
      for _, u in ipairs({ "player", "target" }) do
        FIRE_EVENT("UNIT_HEALTH", u)
        FIRE_EVENT("UNIT_POWER_UPDATE", u, "RAGE")
        FIRE_EVENT("UNIT_AURA", u, { isFullUpdate = true })
        FIRE_EVENT("UNIT_THREAT_LIST_UPDATE", u)
      end
      FIRE_EVENT("SPELL_UPDATE_COOLDOWN")
      NOW = NOW + 1
      T(1)
    end
    -- Abrir Alfa en plena pelea: nada que atrape clics ni toque lo protegido.
    A.Fire("SHOW_OPTIONS", "inicio")
    T(1)
    if A.UI.Options.frame then A.UI.Options.frame:Hide() end
    enCombate = false
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    apagar()
    hayObjetivo = false
    FIRE_EVENT("PLAYER_TARGET_CHANGED")
    T(3)
    -- la misión se completa y se entrega
    poner(QA, true)
    registro()
    FIRE_EVENT("QUEST_TURNED_IN", QA, 450, 300)
    quitar(QA)
    HECHAS[QA] = (n == DIAS) or nil -- (al día siguiente la vuelve a tomar)
    registro()
    if E.Skip then E.Skip() end
    T(2)
  end)

  step("día " .. n .. ": Cerrar mis misiones", function()
    poner(QB, false)
    FIRE_EVENT("QUEST_ACCEPTED", QB)
    registro()
    if AlfaRuta and AlfaRuta.CerrarTodo then AlfaRuta.CerrarTodo("dia") end
    T(6)
    local Ct = Ru.CerrarTodo
    local v = Ct and Ct.Ventana and Ct.Ventana()
    if n == 1 then check(v and v:IsShown(), "«Cerrar mis misiones» no abrió su resumen") end
    if v then v:Hide() end
    T(2)
    quitar(QB)
    registro()
  end)

  step("día " .. n .. ": viajar en barco", function()
    local X, Tr, Ar = NS_OF("Alfa").Transit, Nav.travel, Nav.arrow
    if not (X and Tr and Ar and Ar.frame) then check(n > 1, "falta la flecha o el viaje del motor") return end
    local guardaNav = {}
    for _, k in ipairs({ "Sample", "GetTarget", "HiddenWithGuide", "TomTomArrowGuides", "HandedOff", "IsHiddenState" }) do guardaNav[k] = Nav[k] end
    Nav.Sample = function() return "instruction", 0 end
    Nav.GetTarget = function() return { label = "Ve al muelle", map = 1434, x = 0.26, y = 0.73 } end
    Nav.HiddenWithGuide = function() return false end
    Nav.TomTomArrowGuides = function() return false end
    Nav.HandedOff = function() return false end
    Nav.IsHiddenState = function() return false end
    A.Set("nav.arrow", true)
    local guardaT = {}
    for _, k in ipairs({ "Active", "CurrentLeg", "NextLeg", "CurrentLabel", "Remaining" }) do guardaT[k] = Tr[k] end
    local guardaX = { Riding = X.Riding, NextDeparture = X.NextDeparture, NextArrival = X.NextArrival }
    local muelle = { name = "Bahía del Botín", c = 0, wx = 0, wy = 0, map = 1434, x = 0.26, y = 0.73 }
    local destino = { name = "Trinquete", c = 1, wx = 1, wy = 1, map = 1413, x = 0.63, y = 0.38 }
    local abordo = nil
    Tr.Active = function() return true end
    Tr.CurrentLeg = function() return { kind = "boat", label = "x", to = destino, from = muelle, transport = { id = "r1" }, side = "a", seconds = 240 } end
    Tr.NextLeg = function() return nil end
    Tr.CurrentLabel = function() return "Toma el barco a Trinquete" end
    Tr.Remaining = function() return 600 end
    X.NextDeparture = function() return 90, 240, true end
    X.NextArrival = function() return 30, 90, true end
    X.Riding = function() if abordo then return { kind = "boat", route = "r1", dock = "Trinquete", arriveIn = abordo } end return nil end
    local f = Ar.frame
    f:Hide() f:Show()
    for i = 1, 12 do
      if i == 5 then abordo = 120 end
      if i == 10 then abordo = 8 end
      NOW = NOW + 0.5
      FIRE(f, "OnUpdate", 0.5)
    end
    if n == 1 then
      local tj = Ar.Tarjeta and Ar.Tarjeta()
      check(tj ~= nil, "no salió la tarjeta del barco")
    end
    abordo = nil
    FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
    for k, fn in pairs(guardaT) do Tr[k] = fn end
    for k, fn in pairs(guardaX) do X[k] = fn end
    for k, fn in pairs(guardaNav) do Nav[k] = fn end
    FIRE(f, "OnUpdate", 0.5)
    T(2)
  end)

  step("día " .. n .. ": recolectar con ruta", function()
    local Ll = Rc and Rc.Llevar
    if Ll and Ll.Llevar and Rc.R then
      local conocido = Rc.R.EsConocido
      Rc.R.EsConocido = function() return true end -- sabes Minería
      local mapa0 = MAPA
      local pd = Ll.Pedido and Ll.Pedido(2775)
      local z = pd and Ll.Zonas({ claves = pd.claves, anfitriones = pd.anfitriones, nivel = 23, faccion = "H" })[1]
      if z then MAPA = z.mapa end
      local ok, por = Ll.Llevar(2775, { nivel = 23, faccion = "H", silencio = true })
      if n == 1 then check(ok, "Llevar(plata) falló: " .. tostring(por)) end
      for _ = 1, 50 do T(1) if not Rc.Ruta.Calculando() then break end end
      for _ = 1, 6 do caminar(0.005, 0.005) T(2) end
      Rc.R.EsConocido = conocido
      MAPA = mapa0
      FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-9", 2575)
      bolsa[8] = cosa(2775, 2)
      FIRE_EVENT("BAG_UPDATE_DELAYED")
      T(2)
      if n == 1 then check(Rc.Ruta and Rc.Ruta.Actual and Rc.Ruta.Actual() ~= nil, "no se armó la ruta de recolección") end
      if Rc.Ruta and Rc.Ruta.Detener then Rc.Ruta.Detener() end
      T(2)
    end
  end)

  step("día " .. n .. ": mazmorra (con secretos)", function()
    adentro, enGrupo = true, true
    prender()
    FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
    FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
    FIRE_EVENT("GROUP_ROSTER_UPDATE")
    T(3)
    enCombate = true
    FIRE_EVENT("PLAYER_REGEN_DISABLED")
    FIRE_EVENT("ENCOUNTER_START", 1, "Glubtok", 1, 5)
    for _ = 1, 4 do
      FIRE_EVENT("UNIT_HEALTH", "boss1")
      FIRE_EVENT("UNIT_HEALTH", "party1")
      NOW = NOW + 2
      T(1)
    end
    FIRE_EVENT("ENCOUNTER_END", 1, "Glubtok", 1, 5, 1)
    enCombate = false
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    T(2)
    -- morir y revivir adentro
    muerto = true
    FIRE_EVENT("PLAYER_DEAD")
    T(2)
    muerto, fantasma = false, true
    FIRE_EVENT("PLAYER_ALIVE")
    T(2)
    fantasma = false
    FIRE_EVENT("PLAYER_UNGHOST")
    FIRE_EVENT("UNIT_AURA", "player", { isFullUpdate = true })
    T(2)
    apagar()
    adentro, enGrupo = false, false
    FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
    FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
    FIRE_EVENT("GROUP_ROSTER_UPDATE")
    T(3)
  end)

  step("día " .. n .. ": morir afuera y volver por tu cuerpo", function()
    muerto = true
    FIRE_EVENT("PLAYER_DEAD")
    T(2)
    muerto, fantasma = false, true
    FIRE_EVENT("PLAYER_ALIVE")
    for _ = 1, 3 do caminar(0.01, 0) T(1) end
    fantasma = false
    FIRE_EVENT("PLAYER_UNGHOST")
    T(2)
  end)

  step("día " .. n .. ": bolsas (ordenar y vender)", function()
    llenar()
    FIRE_EVENT("BAG_UPDATE_DELAYED")
    local V = B and B.Ventana
    local w = V and V.Ventana and V.Ventana("bolsas")
    if w then
      w:Show()
      T(2)
      if w.Ordenar and w.Ordenar:IsShown() then FIRE(w.Ordenar, "OnEnter") FIRE(w.Ordenar, "OnLeave") end
      local Or = B.Ordenar
      if Or and Or.Empezar then pcall(Or.Empezar) T(3) end
    end
    -- la chatarra que el motor reconoce (como prueba_131_bolsas)
    local Q = A.QoL or {}
    A.QoL = Q
    local vendorReal = Q.Vendor
    Q.Vendor = { JunkAt = function(b, s)
      local e = b == 0 and bolsa[s]
      if e and e.quality == 0 then return e.itemID, e.stackCount, 5 end
      return nil
    end }
    A.Set("qol.sellJunk", false)
    tiendaAbierta = true
    FIRE_EVENT("MERCHANT_SHOW")
    T(2)
    local S = B and B.Sugerencias
    if S and S.VenderChatarra then S.VenderChatarra() end
    T(4)
    if n == 1 then check(vendidos > 0, "no se vendió la chatarra") end
    tiendaAbierta = false
    FIRE_EVENT("MERCHANT_CLOSED")
    Q.Vendor = vendorReal
    A.Set("qol.sellJunk", nil)
    if w then w:Hide() end
    T(2)
  end)

  step("día " .. n .. ": pesca", function()
    if AlfaPesca and AlfaPesca.Abrir then AlfaPesca.Abrir() end
    T(2)
    if n == 1 then check(AlfaPesca and AlfaPesca.Activo and AlfaPesca.Activo(), "no se abrió el modo pesca") end
    FIRE_EVENT("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-7", 7620)
    NOW = NOW + 10
    FIRE_EVENT("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-7", 7620)
    FIRE_EVENT("LOOT_OPENED", false)
    FIRE_EVENT("LOOT_CLOSED")
    T(2)
    if AlfaPesca and AlfaPesca.Cerrar then AlfaPesca.Cerrar() end
    T(2)
  end)

  step("día " .. n .. ": Dos pantallas ida y vuelta", function()
    local Es = Bv and Bv.Escritorio
    if not (Es and Es.Aplicar and Es.Apagar) then return end
    Es.Aplicar(Es.Geometria and Es.Geometria({ lado = "derecha", proporcion = "16:9" }) or nil)
    T(4)
    if n == 1 then check(Es.Aplicado and Es.Aplicado(), "Dos pantallas no se aplicó") end
    -- en combate nada se mueve (espera a salir)
    enCombate = true
    FIRE_EVENT("PLAYER_REGEN_DISABLED")
    T(2)
    enCombate = false
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    T(2)
    Es.Apagar(true)
    T(4)
    if n == 1 then check(not (Es.Aplicado and Es.Aplicado()), "Dos pantallas no volvió") end
  end)

  step("día " .. n .. ": abrir cada página de Alfa", function()
    for _, id in ipairs({ "inicio", "rutas", "enciclopedia", "builds", "bolsas", "manada", "mazmorras", "mundo",
      "pesca", "lya", "vista", "comodidades", "comercio", "recoleccion", "combate", "curacion", "bienvenida", "questing", "pantallas" }) do
      A.Fire("SHOW_OPTIONS", id)
      T(1)
    end
    if A.UI.Options.frame then A.UI.Options.frame:Hide() end
    T(1)
  end)

  step("día " .. n .. ": /reload", function()
    FIRE_EVENT("PLAYER_LEAVING_WORLD")
    FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
    T(6)
    if A.UI.Options.frame then A.UI.Options.frame:Hide() end
  end)

  step("día " .. n .. ": los relojes un buen rato", function()
    for _ = 1, 30 do
      NOW = NOW + 10
      caminar(0.001, 0)
      RUN_TIMERS(3)
    end
  end)
end

---------------------------------------------------------------------------
-- Siete días: los primeros arman lo que se arma una vez y llenan las listas
-- con tope (las últimas 5 peleas, el historial...); del sexto al séptimo
-- nada debe crecer.
---------------------------------------------------------------------------
local function tareas() local n = 0 for _ in pairs(N.Reloj and N.Reloj.lista or {}) do n = n + 1 end return n end
-- Los OnUpdate que corren (marcos a la vista con OnUpdate): cada uno cuesta
-- en cada cuadro del juego.
local function conOnUpdate()
  local n, quienes = 0, {}
  for _, f in ipairs(ALL_FRAMES()) do
    local s = rawget(f, "_scripts")
    if s and s.OnUpdate and f.IsVisible and f:IsVisible() then
      n = n + 1
      local i = debug.getinfo(s.OnUpdate, "S")
      quienes[#quienes + 1] = (rawget(f, "_name") or "?") .. " @" .. tostring(i and i.short_src) .. ":" .. tostring(i and i.linedefined)
    end
  end
  return n, quienes
end
local function foto()
  collectgarbage("collect")
  local onu, quienes = conOnUpdate()
  return { marcos = #ALL_FRAMES(), ganchos = cuenta.ganchos, tareas = tareas(), tickers = tickersVivos(), onupdate = onu, quienes = quienes }
end
local medidas = {}
for d = 1, DIAS do
  rastrear = FUGAS and d == DIAS or false
  local desde = #ALL_FRAMES()
  unDia(d)
  if rastrear then
    local por = {}
    local todos = ALL_FRAMES()
    for i = desde + 1, #todos do
      local o = todos[i]
      local c = origen[o] or ("(sin origen) " .. tostring(rawget(o, "_kind")))
      por[c] = (por[c] or 0) + 1
    end
    for c, n in pairs(por) do print(("FUGA %3d  %s"):format(n, c)) end
  end
  medidas[d] = foto()
  print(("DIA %d: %d marcos, %d ganchos, %d tareas del reloj, %d tickers vivos, %d OnUpdate corriendo"):format(d, medidas[d].marcos,
    medidas[d].ganchos, medidas[d].tareas, medidas[d].tickers, medidas[d].onupdate))
  if FUGAS and d == DIAS then for _, q in ipairs(medidas[d].quienes) do print("ONUPDATE", q) end end
end
step("de un día al siguiente nada crece", function()
  local a, b = medidas[DIAS - 1], medidas[DIAS]
  check(b.marcos - a.marcos <= 0, ("los marcos crecen cada día: %d -> %d (+%d)"):format(a.marcos, b.marcos, b.marcos - a.marcos))
  check(b.ganchos - a.ganchos <= 0, ("los ganchos (HookScript/hooksecurefunc) crecen cada día: %d -> %d"):format(a.ganchos, b.ganchos))
  check(b.tareas - a.tareas <= 0, ("las tareas del reloj crecen cada día: %d -> %d"):format(a.tareas, b.tareas))
  check(b.tickers - a.tickers <= 0, ("los tickers vivos crecen cada día: %d -> %d"):format(a.tickers, b.tickers))
  check(b.onupdate - a.onupdate <= 0, ("los OnUpdate que corren crecen cada día: %d -> %d"):format(a.onupdate, b.onupdate))
end)

step("salir", function()
  FIRE_EVENT("PLAYER_LEAVING_WORLD")
  FIRE_EVENT("PLAYER_LOGOUT")
end)

print(("PRUEBA: 1.4.0 un día de juego, %d pasos, %d errores"):format(pasos, #ERRORS))
print("errors: " .. #ERRORS)
