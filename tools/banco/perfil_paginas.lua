-- Perfilador de navegación (1.3.6): cuánto tarda y cuánta memoria deja abrir
-- cada página de Alfa, la primera vez y la segunda, y la ventana entera.
-- tools/perfil.py --paginas lo corre con BANCO_PERFIL=1. Tiempos del banco:
-- sirven para comparar, no son los del juego.
local clock = PERFIL_RELOJ or os.clock
collectgarbage("stop")
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
do
  local N, B = AlfaNucleo, AlfaBienvenida
  N.Datos("bienvenida").respondio = B and B.VERSION or 99
  N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
end
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(30)
local N = AlfaNucleo

local function medir(fn)
  local m0, t0 = collectgarbage("count"), clock()
  fn()
  RUN_TIMERS(2)
  return (clock() - t0) * 1000, collectgarbage("count") - m0
end

-- La ventana de Alfa la primera vez (sin página) y cerrarla.
local tv, kv = medir(function() Alfa.Fire("SHOW_OPTIONS") end)
print(("== VENTANA DE ALFA la primera vez: %.1f ms, %.0f KB"):format(tv, kv))
local filas = {}
for _, spec in ipairs(N.modulos or {}) do
  local id = spec.id
  local t1, k1 = medir(function() Alfa.Fire("SHOW_OPTIONS", id) end)
  local t2, k2 = medir(function() Alfa.Fire("SHOW_OPTIONS", id) end)
  filas[#filas + 1] = { id, t1, k1, t2, k2 }
end
table.sort(filas, function(a, b) return a[2] > b[2] end)
print("== PÁGINAS (ms y KB: primera vez | otra vez)")
local tot = 0
for _, f in ipairs(filas) do
  tot = tot + f[2]
  print(("  %-14s %7.1f ms %6.0f KB | %6.1f ms %6.0f KB"):format(f[1], f[2], f[3], f[4], f[5]))
end
print(("  total primera vez: %.0f ms"):format(tot))
print("errors:", #ERRORS)
