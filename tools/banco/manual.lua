-- Escenas para el manual de usuario (tools/manual.py):
--   .venv/Scripts/python -I tools/banco/run.py dist <módulos de la galería> manual.lua
-- Dibuja tools/banco/shot-manual-*.png: las páginas que la galería no tiene
-- (Curación, Comercio, Recolección, Combate, Comodidades, Lya, Pesca, Ajustes)
-- y la ventana de reportes. Datos de muestra: el personaje "Lobato".
SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[name] = { entries = entries, l = l, b = b, w = w, h = h }
end
local function step(name, fn, ...)
  print("PASO " .. name); io.stdout:flush()
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("step " .. name, e) end
end
BANCO_LETRA = 0.64 -- margen: el banco mide las letras a ojo
Alfa.Hidden = function() return false end
UnitName = function(u) if u == "player" then return "Lobato" end return nil end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
-- Lobato ya terminó su bienvenida: sin la puerta de la configuración.
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
if _G.AlfaIntro then _G.AlfaIntro:Hide() end
local A = Alfa
local before = #ERRORS

local PAGINAS = { "curacion", "comercio", "recoleccion", "combate", "comodidades", "lya", "pesca", "vista", "questing", "bienvenida" }
for _, id in ipairs(PAGINAS) do
  step("abrir " .. id, function() A.Fire("SHOW_OPTIONS", id) end)
  RUN_TIMERS(3)
  local f = A.UI.Options.frame or _G.AlfaOptions
  if f then SNAP("manual-" .. id, f) else print("sin ventana", id) end
end
local O = A.UI.Options.frame
if O then O:Hide() end

step("reportar", function() if AlfaReporte and AlfaReporte.Abrir then AlfaReporte.Abrir("mejora") end end)
RUN_TIMERS(3)
if _G.AlfaReporteVentana then SNAP("manual-reportar", _G.AlfaReporteVentana); _G.AlfaReporteVentana:Hide() end

print("errores en manual:", #ERRORS - before)
for i = before + 1, math.min(#ERRORS, before + 8) do print(tostring(ERRORS[i]):sub(1, 400)) end
