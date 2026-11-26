-- Ayudantes comunes de las pruebas del banco (1.4.1). Lo carga run.py en todas
-- las escenas, después del juego simulado (mock.lua, api.lua) y del barrido
-- del ratón (raton.lua). Una prueba nueva ya no copia su step/check/T:
--
--   PRUEBA_ENTRAR()            entra al juego: PLAYER_LOGIN, PLAYER_ENTERING_WORLD,
--                              relojes; sin intro, sin bienvenida pendiente, Lya a la vista
--   PASO(nombre, fn, ...)      corre un paso; un error de Lua o una REVISA fallida
--                              sale como «FALLA EN: <nombre>» con sus detalles
--   REVISA(cond, mensaje)      anota un fallo si cond es falso
--   TIEMPO(seg)                pasa el tiempo (reloj del juego, OnUpdate, relojes)
--   RATON_LIMPIO(momento)      REVISA que nada de Alfa tape el ratón sin verse
--   PRUEBA_FIN(nombre)         la línea final que lee tools/prueba.py
--
-- Plantilla: tools/banco/plantilla_prueba.lua (tools/nueva_version.py la copia).

local pasos = 0
local area = "prueba"

function PRUEBA_AREA(nombre) area = tostring(nombre or "prueba") end

function REVISA(cond, msg)
  if not cond then NOTE(area, tostring(msg)) end
  return cond and true or false
end

function PASO(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 900)) end
  end
  return #ERRORS == antes
end

function TIEMPO(seg) RATON_ADELANTAR(seg or 1) end
-- Solo el reloj del juego y los OnUpdate, sin correr los temporizadores (que el
-- banco corre todos al instante): para mirar algo que se va solo a su tiempo.
function TIEMPO_CORTO(seg) RATON_ADELANTAR(seg or 0.3, nil, true) end

function PRUEBA_ENTRAR()
  Alfa.Hidden = function() return false end
  FIRE_EVENT("PLAYER_LOGIN")
  FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
  RUN_TIMERS(10)
  local intro = rawget(_G, "AlfaIntro")
  if intro and intro:IsShown() then intro:Hide() end
  local B = rawget(_G, "AlfaBienvenida")
  if type(B) == "table" and B.Pendiente then B.Pendiente = function() return false end end
  local bv = rawget(_G, "AlfaBienvenidaVentana")
  if bv and bv.Hide then bv:Hide() end
  local Ly = NS_OF("Alfa_Lya")
  if Ly and Ly.UI and Ly.UI.Aplicar then Ly.UI.Aplicar() end
  RUN_TIMERS(5)
  print("errores al entrar:", #ERRORS)
  for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
end

function RATON_LIMPIO(momento)
  local p = RATON_BARRIDO(momento or "ahora")
  return REVISA(#p == 0, #p .. " problemas del ratón: " .. table.concat(p, " | ", 1, math.min(#p, 30)))
end

function PRUEBA_FIN(nombre)
  print(("PRUEBA: %s, %d pasos, %d errores"):format(tostring(nombre or area), pasos, #ERRORS))
  print("errors: " .. #ERRORS)
end
