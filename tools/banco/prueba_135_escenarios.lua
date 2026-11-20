-- Prueba de aceptación de la 1.3.5: situaciones de jugador de principio a fin.
--
-- 1. Una banda de 40 en combate largo: miles de eventos de los demás, sin
--    errores, y lo tuyo (tus auras, tus hechizos, tu pesca) sigue llegando.
-- 2. Valores secretos (mazmorra, combate): unidades, prefijos y textos
--    secretos no rompen nada de lo nuevo.
-- 3. Entrar y salir de mazmorras en medio de peleas: la recolección duerme
--    adentro y vuelve afuera; las tareas de fondo vuelven al terminar.
-- 4. El modo ligero prendido: todas las páginas de Alfa se abren sin error.
-- 5. /alfa rendimiento de verdad (el comando), con su medición de 10 s.
-- 6. Cambiar de guía varias veces: la siguiente queda armada, las viejas se
--    sueltan, y en combate no se suelta nada.
local pasos = 0
local function step(nombre, fn)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function falla(msg) NOTE("aceptación 1.3.5", msg) end
local function T(n) RUN_TIMERS(n or 3) end

local reloj = 1000
GetTime = function() return reloj end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
print("errores al entrar:", #ERRORS)

local A, N = Alfa, AlfaNucleo
local K = N.Kit
local R = N.Reloj
local function tic(seg, veces)
  for _ = 1, veces or 1 do
    reloj = reloj + seg
    R.marco:Show()
    FIRE(R.marco, "OnUpdate", seg)
  end
end

---------------------------------------------------------------------------
-- 1. Banda de 40
---------------------------------------------------------------------------
step("banda de 40 en combate largo", function()
  local viejos = { IsInRaid = IsInRaid, GetNumGroupMembers = GetNumGroupMembers, UnitExists = UnitExists, InCombatLockdown = InCombatLockdown, IsInGroup = IsInGroup }
  IsInRaid = function() return true end
  IsInGroup = function() return true end
  GetNumGroupMembers = function() return 40 end
  UnitExists = function(u) return u == "player" or (type(u) == "string" and u:match("^raid%d+$") ~= nil) end
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  T(3)
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  InCombatLockdown = function() return true end
  -- Lo tuyo debe seguir llegando: un oyente por unidad del jugador.
  local mios = 0
  N.DeUnidad("UNIT_SPELLCAST_SUCCEEDED", "player", function() mios = mios + 1 end)
  local antes = #ERRORS
  for vuelta = 1, 50 do
    for i = 1, 40 do
      local u = "raid" .. i
      FIRE_EVENT("UNIT_AURA", u)
      FIRE_EVENT("UNIT_HEALTH", u)
      FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", u, "Cast-3-0-0-0-0-0", 2061)
    end
    FIRE_EVENT("UNIT_AURA", "player")
    FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-0-0-0-0-1", 6603)
    FIRE_EVENT("CHAT_MSG_ADDON", "DBM-Core", "V^x", "RAID", "Alguien-Reino")
    FIRE_EVENT("CHAT_MSG_ADDON", "Details", "y", "RAID", "Otro-Reino")
    if vuelta % 10 == 0 then tic(1, 1) end
  end
  if mios ~= 50 then falla("en banda, tus propios hechizos llegaron " .. mios .. " veces de 50") end
  -- Diez minutos de pelea: las tareas de fondo esperan, nada truena.
  tic(1, 600)
  InCombatLockdown = function() return false end
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  tic(1, 15)
  T(5)
  for k, v in pairs(viejos) do _G[k] = v end
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  T(3)
  print(("  2000 eventos de 40 jugadores, 10 min de pelea: %d errores"):format(#ERRORS - antes))
end)

---------------------------------------------------------------------------
-- 2. Valores secretos
---------------------------------------------------------------------------
local SECRETO = "\1secreto\1"
step("valores secretos en lo nuevo", function()
  local real = issecretvalue
  issecretvalue = function(v) return v == SECRETO end
  -- Un texto que antes era secreto, y escribir lo mismo encima.
  local f = CreateFrame("Frame", nil, UIParent)
  local fs = K.Texto(f, "normal", "texto")
  fs:SetText(SECRETO)
  local puso = 0
  local st = fs.SetText
  fs.SetText = function(self, t) puso = puso + 1 return st(self, t) end
  K.Escribir(fs, SECRETO)
  K.Escribir(fs, "normal")
  if puso ~= 2 then falla("K.Escribir con texto secreto puso " .. puso .. " veces (debía 2)") end
  -- Prefijo y unidades secretas.
  FIRE_EVENT("CHAT_MSG_ADDON", SECRETO, SECRETO, "PARTY", SECRETO)
  FIRE_EVENT("UNIT_AURA", SECRETO)
  FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", SECRETO, SECRETO, SECRETO)
  FIRE_EVENT("NAME_PLATE_UNIT_ADDED", SECRETO)
  local gOrig = UnitGUID
  UnitGUID = function() return SECRETO end
  A.Names.Learn("target")
  UnitGUID = gOrig
  issecretvalue = real
end)

---------------------------------------------------------------------------
-- 3. Mazmorras y peleas
---------------------------------------------------------------------------
step("entrar y salir de mazmorras en medio de peleas", function()
  local reco, fondo = 0, 0
  N.Cada("recoleccion.escenario", 0.5, function() reco = reco + 1 end)
  N.Cada("manada.escenario", 2, function() fondo = fondo + 1 end)
  local viejoII, viejoC = IsInInstance, InCombatLockdown
  for vuelta = 1, 3 do
    IsInInstance = function() return true, "party" end
    FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
    local r0 = reco
    tic(1, 10)
    InCombatLockdown = function() return true end
    tic(1, 20)
    InCombatLockdown = viejoC
    tic(1, 5)
    if reco - r0 > 1 then falla(("vuelta %d: la recolección corrió %d veces adentro"):format(vuelta, reco - r0)) end
    IsInInstance = viejoII
    FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
    local r1 = reco
    tic(1, 6)
    if reco == r1 then falla(("vuelta %d: la recolección no volvió afuera"):format(vuelta)) end
  end
  if fondo < 10 then falla("las tareas de fondo casi no corrieron entre peleas: " .. fondo) end
  N.Quitar("recoleccion.escenario") N.Quitar("manada.escenario")
end)

---------------------------------------------------------------------------
-- 4. Modo ligero con todas las páginas
---------------------------------------------------------------------------
step("modo ligero: todas las páginas se abren", function()
  A.Set("nucleo.ligero", true)
  local abiertas = 0
  for _, m in ipairs(N.modulos or {}) do
    local id = type(m) == "table" and (m.id or m.ID) or m
    if type(id) == "string" and N.Abrir then
      N.Abrir(id)
      abiertas = abiertas + 1
      tic(0.5, 4)
    end
  end
  T(5)
  A.Set("nucleo.ligero", false)
  print(("  %d páginas abiertas con el modo ligero"):format(abiertas))
  if abiertas < 10 then falla("solo se abrieron " .. abiertas .. " páginas") end
end)

---------------------------------------------------------------------------
-- 5. /alfa rendimiento
---------------------------------------------------------------------------
step("/alfa rendimiento de verdad", function()
  local lineas = {}
  local viejo = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function(self, t, ...) lineas[#lineas + 1] = tostring(t) return viejo(self, t, ...) end
  local vi = N.Imprimir
  N.Imprimir = function(t, ...) lineas[#lineas + 1] = tostring(t) return vi(t, ...) end
  SlashCmdList.ALFA("rendimiento")
  reloj = reloj + 11
  T(5)
  tic(1, 12)
  DEFAULT_CHAT_FRAME.AddMessage = viejo
  N.Imprimir = vi
  local todo = table.concat(lineas, "\n")
  for _, debe in ipairs({ "memoria", "Midiendo", "juntando" }) do
    if not todo:find(debe, 1, true) then falla("/alfa rendimiento no dijo «" .. debe .. "»") end
  end
end)

---------------------------------------------------------------------------
-- 6. Cambiar de guía varias veces
---------------------------------------------------------------------------
step("cambiar de guía: la siguiente armada, las viejas sueltas", function()
  local E, G = A.Engine, A.Guides
  local lvl = {}
  for _, h in ipairs(G.List()) do
    local g = G.Get(h.id)
    if (h.category == nil or h.category == "Leveling") and g and type(rawget(g, "next")) == "string" then lvl[#lvl + 1] = h.id end
  end
  if #lvl < 3 then print("  (pocas guías con siguiente: " .. #lvl .. ")") return end
  local function armadas()
    local n = 0
    for _, h in ipairs(G.List()) do
      local g = G.Get(h.id)
      if g and rawget(g, "stepsSrc") and rawget(g, "steps") then n = n + 1 end
    end
    return n
  end
  local pico, cambios = 0, 0
  for i = 1, math.min(6, #lvl) do
    E.SetGuide(lvl[i])
    local g = E.GetGuide and E.GetGuide()
    if not (g and g.id == lvl[i]) then falla("SetGuide no cambió a " .. lvl[i]) end
    cambios = cambios + 1
    reloj = reloj + 4
    tic(1, 5)
    T(5)
    local n = armadas()
    if n > pico then pico = n end
    -- La siguiente de la guía de ahora, armada.
    local nx = rawget(G.Get(lvl[i]) or {}, "next")
    local s2 = type(nx) == "string" and G.Get(nx)
    if s2 and not rawget(s2, "steps") then falla("al cambiar a " .. lvl[i] .. ", su siguiente (" .. nx .. ") no quedó armada") end
  end
  if cambios < 3 then falla("solo se cambió de guía " .. cambios .. " veces") end
  print(("  6 cambios de guía: a lo más %d guías armadas a la vez"):format(pico))
  if pico > 14 then falla("se quedaron armadas " .. pico .. " guías al cambiar de guía") end
  -- En combate, limpiar no suelta nada; al terminar, sí.
  local viejo = InCombatLockdown
  InCombatLockdown = function() return true end
  local n0 = armadas()
  A.Fire("TABS_CHANGED")
  if armadas() < n0 then falla("se soltaron guías en combate") end
  InCombatLockdown = viejo
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
end)

print(("PRUEBA: aceptación 1.3.5, %d pasos, errores: %d"):format(pasos, #ERRORS))
