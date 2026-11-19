-- Prueba de los dos arreglos de la 1.2.8 que pidió Toxic:
--   * al quitarte la caña (te pones tus armas) el modo pesca se cierra solo;
--   * el aviso de descanso ya no dice «0 %» de XP descansada.
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
local function check(cond, msg) if not cond then NOTE("1.2.8", msg) end end

local A = AlfaNucleo.A
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

step("Pesca: al quitarte la caña se cierra el modo", function()
  local P = NS_OF("Alfa_Pesca")
  local Eq = P.Eq
  check(Eq and P.Modo, "no está el módulo de pesca")
  if not (Eq and P.Modo) then return end
  local cana = true
  local orig = Eq.CanaPuesta
  Eq.CanaPuesta = function() return cana, cana and 6256 or 2131 end
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 16)
  RUN_TIMERS(3)
  if not P.Modo() then P.AbrirModo() end
  check(P.Modo(), "el modo pesca no se abrió con la caña")
  cana = false
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 16)
  RUN_TIMERS(3)
  check(not P.Modo(), "el modo pesca siguió abierto al ponerte las armas")
  -- Abrirlo a mano sin caña no lo cierra solo (la macro te la pone al lanzar).
  P.AbrirModo()
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 1)
  RUN_TIMERS(3)
  check(P.Modo(), "el modo pesca se cerró sin que te quitaras la caña")
  P.CerrarModo()
  Eq.CanaPuesta = orig
end)

step("Descanso: sin «0 %» al entrar a la posada", function()
  local I = NS_OF("Alfa_Inicio")
  local avisos = {}
  local mostrar = I.Aviso.Mostrar
  I.Aviso.Mostrar = function(o) avisos[#avisos + 1] = o end
  A.Set("inicio.recDescanso", true)
  local exh, resting = 0, false
  local gX, gR = rawget(_G, "GetXPExhaustion"), rawget(_G, "IsResting")
  rawset(_G, "GetXPExhaustion", function() return exh end)
  rawset(_G, "IsResting", function() return resting end)
  FIRE_EVENT("PLAYER_UPDATE_RESTING")
  RUN_TIMERS(3)
  resting = true
  FIRE_EVENT("PLAYER_UPDATE_RESTING")
  RUN_TIMERS(3)
  local a = avisos[#avisos]
  check(a and a.clave == "descanso", "no salió el aviso de descanso")
  if a then
    check(not tostring(a.linea):find("0%%"), "el aviso dice 0 %: " .. tostring(a.linea))
    check(tostring(a.linea):find("Empiezas a juntar", 1, true), "sin XP descansada no dice que empiezas a juntarla")
  end
  local estado = I.Rec and I.Rec.Estado and I.Rec.Estado()
  check(estado ~= nil, "no hay estado de recordatorios")
  rawset(_G, "GetXPExhaustion", gX)
  rawset(_G, "IsResting", gR)
  I.Aviso.Mostrar = mostrar
end)

print(string.format("PRUEBA: 1.2.8 pesca y descanso, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
