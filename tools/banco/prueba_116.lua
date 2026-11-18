-- Prueba de los arreglos de la 1.1.6 (tools/prueba.py la corre con las demás
-- prueba_*.lua):
--   * Seguir (La Jauría): un destino marcado con Nav.KeepTarget no se suelta
--     cuando la guía cambia de paso, y vuelve solo después de Nav.Hold
--     (camino a tu cuerpo).
--   * "Cerrar lo que la guía no toma" espera cuando otro módulo acaba de
--     pedir algo en la ventana (Automation.Keep).
--   * La barra de vuelo se pide al motor (Maps.GetFlightFrame).
--   * Mazmorras: si al cliente le falta el interruptor general de avisos, los
--     avisos que sí tiene no se quedan apagados.
--   * Las fechas de Inicio salen en el orden de cada idioma.
--   * Talentos y Combate: Protección y Restauración del paladín y el chamán
--     se ven sin la marca de la clave.
SNAPSHOTS = {}
BANCO_LETRA = 0.64
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
local function T(n) RUN_TIMERS(n or 2) end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
local A = Alfa
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end

local Nav = A.Nav

step("Seguir: un destino que se queda no se suelta al cambiar de paso", function()
  if not Nav.KeepTarget then error("falta Nav.KeepTarget (parche de tools/parches.py)") end
  local t = Nav.SetTarget(1429, 0.5, 0.5, "Ana")
  if not Nav.KeepTarget(t) then error("Nav.KeepTarget no aceptó el destino puesto") end
  A.Fire("STEP_CHANGED")
  T(2)
  if Nav.GetTarget() ~= t then error("el paso nuevo le quitó la flecha a un destino que se queda") end
  Nav.ReleaseTarget()
  T(1)
  if Nav.GetTarget() == t then error("ReleaseTarget no soltó el destino") end
end)

step("Un destino normal sí se suelta al cambiar de paso (como siempre)", function()
  local t = Nav.SetTarget(1429, 0.4, 0.4, "Punto")
  A.Fire("STEP_CHANGED")
  T(2)
  if Nav.GetTarget() == t then error("un destino normal ya no se suelta al cambiar de paso") end
  if Nav.KeepTarget({}) then error("Nav.KeepTarget aceptó algo que no es el destino puesto") end
end)

step("Seguir: camino a tu cuerpo la flecha espera y luego vuelve", function()
  local t = Nav.SetTarget(1429, 0.3, 0.3, "Ana")
  Nav.KeepTarget(t)
  local h = Nav.Hold(1429, 0.6, 0.6, "Tu cuerpo")
  if Nav.GetTarget() ~= h then error("Nav.Hold no tomó la flecha") end
  A.Fire("STEP_CHANGED")
  T(2)
  Nav.Unhold()
  if Nav.GetTarget() ~= t then error("al soltar el Hold no volvió el destino de Seguir") end
  Nav.ReleaseTarget()
end)

step("Automation.Keep existe y se puede llamar", function()
  local Au = A.Automation
  if not (Au and Au.Keep) then error("falta Automation.Keep (parche de tools/parches.py)") end
  Au.Keep(2)
  NOW = NOW + 3
end)

step("La barra de vuelo se pide al motor", function()
  local M = A.Maps
  if not (M and M.GetFlightFrame) then error("falta Maps.GetFlightFrame (parche de tools/parches.py)") end
  local f = M.GetFlightFrame()
  if not (f and f.HookScript) then error("Maps.GetFlightFrame no dio un marco") end
  if M.GetFlightFrame() ~= f then error("Maps.GetFlightFrame creó dos marcos") end
end)

step("Mazmorras: sin el interruptor general, los avisos que existen no se apagan", function()
  local Av = NS_OF("Alfa_Mazmorras").Avisos
  if not (Av and Av.Activo) then error("falta Avisos.Activo") end
  local viejo = C_CVar.GetCVar
  C_CVar.GetCVar = function(n)
    if n == "encounterTimelineEnabled" then return "1" end
    return nil -- combatWarningsEnabled no existe en este cliente
  end
  local ok, e = pcall(function()
    if not Av.Activo("combatWarningsEnabled") then error("un interruptor que no existe cuenta como apagado") end
    if not Av.Activo("encounterTimelineEnabled") then error("un aviso prendido salió apagado") end
  end)
  C_CVar.GetCVar = function(n) if n == "combatWarningsEnabled" then return "0" end return "1" end
  local ok2, e2 = pcall(function()
    if Av.Activo("combatWarningsEnabled") then error("un interruptor apagado salió prendido") end
  end)
  C_CVar.GetCVar = viejo
  if not ok then error(e, 0) end
  if not ok2 then error(e2, 0) end
end)

step("Inicio: la fecha en el orden del idioma", function()
  local S = NS_OF("Alfa_Inicio").Sesion
  if not (S and S.Fecha) then error("falta Sesion.Fecha") end
  local f = S.Fecha({ day = 14, month = 11 })
  if f ~= "14/11" and f ~= "11/14" then error("fecha rara: " .. tostring(f)) end
  if f:find("{", 1, true) then error("la fecha dejó la plantilla sin llenar: " .. f) end
  local c = S.Cuando(NOW and (time and time() or 0) - 5 * 86400 or 0)
  if type(c) ~= "string" or c:find("{", 1, true) or c:find("%", 1, true) then error("Cuando salió mal: " .. tostring(c)) end
end)

step("Talentos y Combate: Protección y Restauración sin la marca de la clave", function()
  -- Talentos carga los datos de la clase del personaje; la marca se quita
  -- igual para todas, así que se prueba con los textos y con lo cargado.
  for _, mod in ipairs({ "Alfa_Builds", "Alfa_Combate" }) do
    local L = NS_OF(mod).L
    if not L then error(mod .. " no tiene M.L") end
    for _, k in ipairs({ "Protección [paladín]", "Restauración [chamán]" }) do
      local s = L[k]:gsub(" %[.-%]$", "")
      if s:find("[", 1, true) or s == "" then error(mod .. ": «" .. k .. "» se ve como «" .. s .. "»") end
    end
  end
  local B = NS_OF("Alfa_Builds")
  local d = B.DatosClase and B.DatosClase()
  for clave, e in pairs(d and d.especialidades or {}) do
    if type(e.nombre) ~= "string" or e.nombre:find("[", 1, true) then
      error(clave .. ": nombre con la marca de la clave: " .. tostring(e.nombre))
    end
  end
end)

print("PRUEBA: 1.1.6, " .. pasos .. " pasos, " .. #ERRORS .. " errores")
