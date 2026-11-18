-- Escena de la 1.2.0 para la galería (tools/banco/run.py dist <módulos> galeria120.lua):
-- la intro del lobo y la luna con el lobo redibujado y el saludo de cada entrada.
-- Datos de muestra: el personaje "Lobato", nada del jugador.
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
BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
UnitName = function(u) if u == "player" then return "Lobato" end return nil end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
RUN_TIMERS(10)
local A, N = Alfa, AlfaNucleo
if A.UI.Options.frame then A.UI.Options.frame:Hide() end

local B = NS_OF("Alfa_Bienvenida")
step("intro", function()
  -- la configuración pendiente del banco ya abrió una intro: se cierra antes
  if _G.AlfaIntro then _G.AlfaIntro:Hide() end
  B.Intro(nil, { otraVez = true, texto = string.format(B.L["¡De vuelta en la manada, %s!"], "Lobato") })
  -- el momento en que A L F A, el lema y el saludo ya están, con el lobo aullando
  B.CuadroIntro(3.3)
  SNAP("intro", _G.AlfaIntro)
end)
print("errores:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
