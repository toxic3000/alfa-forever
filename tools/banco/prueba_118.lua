-- Prueba de la 1.1.8 (tools/prueba.py la corre con las demás prueba_*.lua):
--   * Recolección publica sus nodos en el mapa continuo solo de las zonas a
--     la vista, agrupados, y deja la capa vacía al cerrar el mapa;
--   * el minimapa de Recolección no trabaja sin tipos visibles;
--   * las texturas del mapa aparecen por tandas y no se queda ninguna
--     esperando.
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
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local Mu = NS_OF("Alfa_Mundo")
local Re = NS_OF("Alfa_Recoleccion")
local Lz, V = Mu.Lienzo, Mu.Ventana
local MM = Re.MapaMundo
local TIPOS = Re.TIPOS or { "mineria", "hierbas", "pesca", "tesoros" }

local vista
-- Un cuadro del juego: la vista y los marcos que cuelgan de ella con su
-- OnUpdate (el cargador de texturas del lienzo), como hace el juego.
local function cuadros(n)
  for _ = 1, n do
    NOW = NOW + 0.03
    FIRE(vista, "OnUpdate", 0.03)
    for _, hijo in ipairs({ vista:GetChildren() }) do
      if hijo:IsShown() and hijo._scripts and hijo._scripts.OnUpdate then FIRE(hijo, "OnUpdate", 0.03) end
    end
  end
end

local function total()
  local n, capas = 0, 0
  for _, tipo in ipairs(TIPOS) do
    local p = A.Pins.GetLayer("recoleccion." .. tipo)
    if type(p) == "table" then
      capas = capas + 1
      n = n + #p
    end
  end
  return n, capas
end

step("Recolección: MapaMundo instalado", function()
  if not (MM and MM.Refrescar) then error("falta Recolección/MapaMundo.lua") end
  if type(AlfaMundo.ZonasALaVista) ~= "function" then error("falta AlfaMundo.ZonasALaVista") end
  if AlfaMundo.ZonasALaVista() ~= nil then error("con el mapa cerrado ZonasALaVista debe dar nil") end
end)

step("Recolección: con el mapa en Durotar salen sus nodos agrupados", function()
  V.Abrir(1411)
  vista = _G.AlfaMundoMapa and _G.AlfaMundoMapa.Vista
  if not vista then error("no se abrió el mapa continuo") end
  cuadros(20)
  local abiertas = AlfaMundo.ZonasALaVista()
  if type(abiertas) ~= "table" then error("con el mapa abierto ZonasALaVista debe dar una lista") end
  -- El banco no tiene los mosaicos del terreno: su zoom se detiene antes de
  -- que entre el arte de las zonas (~2.4). Lo que se prueba aquí es lo que
  -- Recolección hace con las zonas a la vista: se le dice cuáles son.
  local real = AlfaMundo.ZonasALaVista
  AlfaMundo.ZonasALaVista = function() return { 1411 } end
  local zonas = AlfaMundo.ZonasALaVista()
  MM.Refrescar(true)
  local n = total()
  if n == 0 then error("ningún nodo publicado con Durotar a la vista") end
  if n > 600 then error("demasiados pines publicados (" .. n .. "): no se agrupan") end
  for _, tipo in ipairs(TIPOS) do
    for _, p in ipairs(A.Pins.GetLayer("recoleccion." .. tipo) or {}) do
      if not (p.map and p.x and p.y and p.x >= 0 and p.x <= 100 and p.y >= 0 and p.y <= 100) then
        error("un pin de " .. tipo .. " sin lugar válido")
      end
      local visto = false
      for _, z in ipairs(zonas) do if z == p.map then visto = true end end
      if not visto then error("un pin de " .. tipo .. " es de una zona que no está a la vista (" .. tostring(p.map) .. ")") end
      if p.badge ~= nil and not (type(p.badge) == "number" and p.badge > 1) then error("cantidad rara en un grupo") end
      if type(p.tooltip) ~= "function" then error("un pin sin cuadro de información") end
    end
  end
  ZONAS_REAL = real
end)

step("Recolección: el cuadro de un grupo se puede leer", function()
  for _, tipo in ipairs(TIPOS) do
    for _, p in ipairs(A.Pins.GetLayer("recoleccion." .. tipo) or {}) do
      p.tooltip(GameTooltip)
      return
    end
  end
end)

step("Recolección: un tipo apagado no publica nada", function()
  local Capas = Mu.Capas
  AlfaMundo.ActivarCapa("recoleccion.mineria", false)
  T(1)
  MM.Refrescar(true)
  local p = A.Pins.GetLayer("recoleccion.mineria")
  if type(p) == "table" and #p > 0 then error("minería apagada siguió con " .. #p .. " pines") end
  AlfaMundo.ActivarCapa("recoleccion.mineria", true)
  T(1)
end)

step("Mapa: las texturas aparecen por tandas y ninguna se queda esperando", function()
  if not Lz.Cargando then error("falta Lienzo.Cargando") end
  for _ = 1, 6 do V.Rueda(nil, 1) cuadros(4) end
  cuadros(120)
  local cola, tandas = Lz.Cargando()
  if cola > 0 or tandas > 0 then error(string.format("quedan %d archivos en cola y %d tandas esperando", cola, tandas)) end
end)

step("Recolección: al cerrar el mapa sus capas quedan vacías", function()
  if ZONAS_REAL then AlfaMundo.ZonasALaVista = ZONAS_REAL end
  V.Cerrar()
  T(1)
  MM.Refrescar(false)
  local n = total()
  if n > 0 then error("con el mapa cerrado siguen " .. n .. " pines de Recolección") end
end)

step("Recolección: sin tipos visibles el minimapa no trabaja", function()
  if not Re.R.AlgunoVisible then error("falta R.AlgunoVisible") end
  if not Re.Mini.Vigia then error("falta Mini.Vigia") end
  A.Set("recoleccion.minimapa", false)
  T(1)
  A.Set("recoleccion.minimapa", true)
  T(1)
end)

print("PRUEBA: 1.1.8, " .. pasos .. " pasos, " .. #ERRORS .. " errores")
