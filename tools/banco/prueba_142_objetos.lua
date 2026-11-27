-- Prueba de la 1.4.2: señalar los objetos de tus misiones (Alfa_Rutas/Senalar.lua).
--
-- Toxic: «tenía que darle clic a esas cajas y recuerdo que esos objetos
-- brillaban; me gustaría que los objetos de misión tengan un resplandor que
-- indique que ese es el que le debes dar clic».
--   1. Con una misión que pide tocar objetos, Alfa prende la señal del juego
--      (SoftTargetInteract y SoftTargetIconGameObject); sin ella, nada.
--   2. Al terminar la misión, tus valores vuelven tal cual.
--   3. Si tú cambias esas variables, mandan las tuyas (Alfa ya no las toca).
--   4. En combate, nada; con la pesca puesta, nada (la pesca manda).
--   5. Nunca toca SoftTargetIconInteract (contaminaría las placas de nombre).
PRUEBA_AREA("1.4.2 objetos")

-- Las variables del juego, con sus valores de fábrica; se anota quién escribe.
local cv = { SoftTargetInteract = "1", SoftTargetIconGameObject = "0", SoftTargetIconInteract = "1" }
local escritas = {}
C_CVar.GetCVar = function(n) return cv[n] end
C_CVar.SetCVar = function(n, v) cv[n] = tostring(v) escritas[#escritas + 1] = n FIRE_EVENT("CVAR_UPDATE", n, tostring(v)) return true end
GetCVar, SetCVar = C_CVar.GetCVar, C_CVar.SetCVar

-- El registro: una misión que pide tocar cajas (tipo «object»).
local LOG, ORDEN = {}, {}
local QL = C_QuestLog
QL.GetNumQuestLogEntries = function() return #ORDEN, #ORDEN end
QL.GetInfo = function(i) local q = ORDEN[i] return q and { questID = q, title = "Misión " .. q, isHeader = false } or nil end
QL.GetQuestObjectives = function(q) return LOG[q] or {} end
QL.IsOnQuest = function(q) return LOG[q] ~= nil end
local function tomar(q, tipo, hecho)
  if not LOG[q] then ORDEN[#ORDEN + 1] = q end
  LOG[q] = { { text = "Zarpas asquerosas: 0/6", type = tipo, finished = hecho or false, numFulfilled = 0, numRequired = 6 } }
  FIRE_EVENT("QUEST_LOG_UPDATE")
end
local function soltar(q)
  LOG[q] = nil
  for i = #ORDEN, 1, -1 do if ORDEN[i] == q then table.remove(ORDEN, i) end end
  FIRE_EVENT("QUEST_LOG_UPDATE")
end

PRUEBA_ENTRAR()
local Ru = NS_OF("Alfa_Rutas")
local Sn = Ru and Ru.Senalar

PASO("Sin misiones de objetos, nada; con una, la señal; al terminarla, lo tuyo", function()
  REVISA(Sn, "no existe Rutas/Senalar.lua")
  if not Sn then return end
  tomar(100, "monster")
  RUN_TIMERS(2)
  REVISA(cv.SoftTargetInteract == "1" and cv.SoftTargetIconGameObject == "0", "sin misiones de objetos, Alfa cambió la interacción")
  tomar(200, "object")
  RUN_TIMERS(2)
  REVISA(cv.SoftTargetInteract == "3" and cv.SoftTargetIconGameObject == "1", "con una misión de cajas, no se prendió la señal")
  -- Terminada: tus valores de vuelta.
  LOG[200][1].finished = true
  FIRE_EVENT("QUEST_LOG_UPDATE")
  RUN_TIMERS(2)
  REVISA(cv.SoftTargetInteract == "1" and cv.SoftTargetIconGameObject == "0", "al terminar la misión no volvió lo tuyo: " .. cv.SoftTargetInteract .. "/" .. cv.SoftTargetIconGameObject)
  soltar(200)
  for _, n in ipairs(escritas) do REVISA(n ~= "SoftTargetIconInteract", "Alfa tocó SoftTargetIconInteract (contamina las placas)") end
end)

PASO("En combate y con la pesca, nada", function()
  if not Sn then return end
  local realC = InCombatLockdown
  InCombatLockdown = function() return true end
  tomar(300, "object")
  RUN_TIMERS(2)
  REVISA(cv.SoftTargetInteract == "1", "en combate Alfa cambió la interacción")
  InCombatLockdown = realC
  local P = rawget(_G, "AlfaPesca")
  local real = P and P.TocaVariables
  if P then P.TocaVariables = function() return true end end
  FIRE_EVENT("QUEST_LOG_UPDATE")
  RUN_TIMERS(2)
  REVISA(cv.SoftTargetInteract == "1", "con la pesca puesta Alfa cambió la interacción")
  if P then P.TocaVariables = real end
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  RUN_TIMERS(2)
  REVISA(cv.SoftTargetInteract == "3", "al salir del combate no se prendió la señal")
end)

PASO("Si tú la cambias, manda la tuya", function()
  if not Sn then return end
  -- El jugador apaga la señal desde las opciones del juego.
  cv.SoftTargetInteract = "0"
  FIRE_EVENT("CVAR_UPDATE", "SoftTargetInteract", "0")
  FIRE_EVENT("QUEST_LOG_UPDATE")
  RUN_TIMERS(2)
  REVISA(cv.SoftTargetInteract == "0", "Alfa volvió a prender lo que el jugador apagó")
  soltar(300)
  RUN_TIMERS(2)
  REVISA(cv.SoftTargetInteract == "0", "al terminar, Alfa pisó lo que eligió el jugador")
end)

PRUEBA_FIN()
