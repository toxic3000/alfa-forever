-- Escena de la intro del lobo (1.2.1) y de la llegada de Lya al entrar:
--   .venv/Scripts/python -I tools/banco/run.py dist <módulos de la galería> lobo.lua
-- Dibuja tools/banco/shot-lobo-<momento>.png (la estrella fugaz, el aullido
-- con sus ondas, el destello del ojo con A L F A) y recorre la llegada de
-- Lya (la espera, ALFA_INTRO_FIN, la carrera y el saludo) buscando errores.
-- El banco no anima: las animaciones del juego aquí no se mueven.
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
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
local A, N = Alfa, AlfaNucleo
local before = #ERRORS

-- Lya ya se presentó: al entrar espera su llegada.
local Ly = NS_OF("Alfa_Lya")
step("lya presentada", function()
  N.DatosPersonaje("lya").presentada = true
  if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
end)

local B = NS_OF("Alfa_Bienvenida")
step("intro", function()
  if _G.AlfaIntro then _G.AlfaIntro:Hide() end
  B.Intro(nil, { otraVez = true, texto = string.format(B.L["¡De vuelta en la manada, %s!"], "Lobato") })
end)
for _, m in ipairs({ { "fugaz", 1.0 }, { "aullido", 2.4 }, { "ojo", 3.75 } }) do
  step("intro " .. m[1], function()
    B.CuadroIntro(m[2])
    SNAP("lobo-" .. m[1], _G.AlfaIntro)
  end)
end
step("aullidos", function()
  for _, cual in ipairs({ "intro", "corto", "largo", "manada" }) do
    assert(B.Aullar(true, cual) ~= nil, "Aullar " .. cual)
  end
  RUN_TIMERS(30)
end)
step("comando aullido", function()
  SlashCmdList = SlashCmdList or {}
  A.RunCommand = A.RunCommand or nil
  B.Aullar(true, "intro")
end)

-- La llegada: Lya espera, termina la intro y llega corriendo.
step("llegada", function()
  local UI = Ly.UI
  local Ce = Ly.Cerebro
  if Ce and Ce.Aplicar then Ce.Aplicar() end
  print("visible", UI.Visible(), "esperando", UI.Esperando and UI.Esperando())
  if UI.Visible() and not UI.Esperando() then UI.EsperarLlegada() end
  print("esperando tras EsperarLlegada", UI.Esperando())
  local llamado = false
  assert(UI.Llegar(function() llamado = true end), "Llegar")
  print("llegando (el banco no anima: la carrera no termina sola)")
  -- en combate, aparece en su lugar y dice lo suyo
  UI.Combate(true)
  print("combate: llamado", llamado)
  UI.Combate(false)
  -- el evento de fin de la intro con una llegada pendiente
  A.Fire("ALFA_INTRO_FIN")
  RUN_TIMERS(40)
end)
print("errores en lobo:", #ERRORS - before)
for i = before + 1, math.min(#ERRORS, before + 8) do print(tostring(ERRORS[i]):sub(1, 500)) end
