-- Perfilador de Alfa (tools/perfil.py lo corre con BANCO_PERFIL=1).
--
-- Carga solo los addons que el juego carga al entrar (los LoadOnDemand
-- entran si Alfa los pide), entra al mundo y luego simula un rato de juego:
-- ráfagas de los eventos que más se repiten y cuadros de OnUpdate. Imprime
-- lo que más tarda en cada fase. Los tiempos son del banco (Lua 5.1 de lupa),
-- no del juego: sirven para comparar, no como milisegundos reales.
local clock = PERFIL_RELOJ
collectgarbage("stop") -- la basura de cada manejador se ve completa
local function limpiar() for k in pairs(PERFIL_KB) do PERFIL_KB[k] = nil end for k in pairs(PERFIL_T) do PERFIL_T[k] = nil end for k in pairs(PERFIL_N) do PERFIL_N[k] = nil end for k in pairs(PERFIL_EV) do PERFIL_EV[k] = nil end end
local function top(titulo, n, total)
  local l = {}
  for k, t in pairs(PERFIL_T) do l[#l + 1] = { k, t, PERFIL_N[k] } end
  table.sort(l, function(a, b) return a[2] > b[2] end)
  print(("== %s: %.1f ms en total"):format(titulo, (total or 0) * 1000))
  for i = 1, math.min(n, #l) do
    print(("  %8.2f ms  x%-5d %s"):format(l[i][2] * 1000, l[i][3], l[i][1]))
  end
end
local function topEv(n)
  local l = {}
  for k, t in pairs(PERFIL_EV) do l[#l + 1] = { k, t } end
  table.sort(l, function(a, b) return a[2] > b[2] end)
  for i = 1, math.min(n, #l) do print(("  %8.2f ms  evento %s"):format(l[i][2] * 1000, l[i][1])) end
end

-- Cuántas guías tienen sus pasos leídos (las diferidas solo cuando se usan).
local function guiasLeidas(cuando)
  local G = Alfa and Alfa.Guides
  if not (G and G.List) then return end
  local n, leidas, quien = 0, 0, {}
  for _, h in ipairs(G.List()) do
    n = n + 1
    local g = G.Get(h.id)
    if g and rawget(g, "steps") ~= nil and rawget(g, "stepsSrc") ~= nil then leidas = leidas + 1; quien[#quien + 1] = h.id end
  end
  print(("  GUÍAS %s: %d registradas, %d diferidas con los pasos ya leídos%s"):format(cuando, n, leidas, #quien > 0 and (": " .. table.concat(quien, ", ", 1, math.min(#quien, 12))) or ""))
end
local function memoria() return collectgarbage and collectgarbage("count") or 0 end

-- 1. Carga de archivos (ya ocurrió antes de esta escena).
local porAddon, total = {}, 0
for _, c in ipairs(PERFIL_CARGA or {}) do porAddon[c[3]] = (porAddon[c[3]] or 0) + c[2]; total = total + c[2] end
local la = {}
for k, v in pairs(porAddon) do la[#la + 1] = { k, v } end
table.sort(la, function(a, b) return a[2] > b[2] end)
print(("== CARGA de archivos: %.1f ms"):format(total * 1000))
for i = 1, math.min(15, #la) do print(("  %8.2f ms  %s"):format(la[i][2] * 1000, la[i][1])) end
table.sort(PERFIL_CARGA, function(a, b) return a[2] > b[2] end)
print("  -- archivos más lentos:")
for i = 1, math.min(15, #PERFIL_CARGA) do print(("  %8.2f ms  %s"):format(PERFIL_CARGA[i][2] * 1000, PERFIL_CARGA[i][1])) end

-- 2. Entrar al mundo.
limpiar()
local t0 = clock()
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(30)
top("ENTRAR (PLAYER_LOGIN + ENTERING_WORLD + 30 relojes)", 25, clock() - t0)
topEv(8)
local cargados = {}
for k in pairs(LOADED) do cargados[#cargados + 1] = k end
table.sort(cargados)
print("  addons cargados después de entrar: " .. table.concat(cargados, ", "))
for _, p in ipairs(PERFIL_PIDIO or {}) do
  local traza = p[3]:gsub("\n%s*%[C%][^\n]*", ""):gsub("\n", "\n      ")
  print(("  LoadAddOn %s: %.1f ms%s"):format(p[1], p[2] * 1000, traza:sub(1, 900)))
end

guiasLeidas("al entrar")

-- Las tareas del reloj de Alfa (N.Cada), cada una por su clave.
local function envolverTareas()
  local R = AlfaNucleo and AlfaNucleo.Reloj
  for clave, t in pairs(R and R.lista or {}) do
    if not t._perfil then
      local fn, k = t.fn, "tarea " .. tostring(clave) .. " (cada " .. tostring(t.cada) .. " s)"
      t.fn = function(...) local m0, t0 = PERFIL_MARCA(), PERFIL_RELOJ(); local r = { fn(...) }; PERFIL_SUMAR(k, PERFIL_RELOJ() - t0, m0); return unpack(r) end
      t._perfil = true
    end
  end
end
envolverTareas()
limpiar()
do
  local m0 = collectgarbage("count")
  RUN_TIMERS(60)
  local l = {}
  for k, v in pairs(PERFIL_KB) do if k:find("^tarea") or k:find("^reloj Alfa") then l[#l + 1] = { k, v, PERFIL_T[k], PERFIL_N[k] } end end
  table.sort(l, function(a, b) return a[2] > b[2] end)
  print(("== RELOJ 60 s sin hacer nada: basura %.0f KB"):format(collectgarbage("count") - m0))
  for i = 1, math.min(15, #l) do print(("  %7.0f KB  %6.2f ms  x%-3d %s"):format(l[i][2], l[i][3] * 1000, l[i][4], l[i][1])) end
end

-- 3. Un rato de juego: ráfagas de eventos.
local RAFAGAS = {
  { "BAG_UPDATE_DELAYED" }, { "QUEST_LOG_UPDATE" }, { "UNIT_AURA", "player" },
  { "PLAYER_TARGET_CHANGED" }, { "UPDATE_MOUSEOVER_UNIT" }, { "UNIT_HEALTH", "target" },
  { "BAG_UPDATE", 0 }, { "UNIT_POWER_UPDATE", "player", "MANA" }, { "ZONE_CHANGED" },
  { "CHAT_MSG_ADDON", "ALFA", "x", "GUILD", "Otro-Reino" },
}
for _, r in ipairs(RAFAGAS) do
  -- Uno antes, sin medir: el primero de la sesión hace trabajo de una sola vez.
  FIRE_EVENT(unpack(r)); RUN_TIMERS(5)
  limpiar()
  local m0, t = memoria(), clock()
  for _ = 1, 100 do FIRE_EVENT(unpack(r)) end
  RUN_TIMERS(5)
  local dt = clock() - t
  print(("== RÁFAGA x100 %-22s %8.2f ms  basura %.0f KB"):format(r[1], dt * 1000, memoria() - m0))
  local l = {}
  for k, v in pairs(PERFIL_T) do l[#l + 1] = { k, v, PERFIL_N[k] } end
  table.sort(l, function(a, b) return a[2] > b[2] end)
  for i = 1, math.min(4, #l) do print(("      %8.2f ms  x%-4d %6.0f KB  %s"):format(l[i][2] * 1000, l[i][3], PERFIL_KB[l[i][1]] or 0, l[i][1])) end
  local b = {}
  for k, v in pairs(PERFIL_KB) do if not k:find("^OnEvent Alfa\Core\Init") and not k:find("N.Reloj") then b[#b + 1] = { k, v } end end
  table.sort(b, function(x, y) return x[2] > y[2] end)
  for i = 1, math.min(3, #b) do print(("      basura %6.0f KB  %s"):format(b[i][2], b[i][1])) end
end

-- 4. Cuadros: OnUpdate de todo lo visible, 300 cuadros (5 s a 60 fps).
limpiar()
local vivos = 0
local m0, t = memoria(), clock()
for _ = 1, 300 do
  vivos = 0
  for _, f in ipairs(ALL_FRAMES()) do
    if f._scripts and f._scripts.OnUpdate and f:IsVisible() then vivos = vivos + 1; FIRE(f, "OnUpdate", 1 / 60) end
  end
end
top(("CUADROS x300, %d OnUpdate vivos"):format(vivos), 15, clock() - t)
print(("  basura en 5 s de cuadros: %.0f KB"):format(memoria() - m0))

-- 5. Combate: entrar, 50 golpes de eventos, salir.
limpiar()
t = clock()
FIRE_EVENT("PLAYER_REGEN_DISABLED")
for _ = 1, 50 do
  FIRE_EVENT("UNIT_HEALTH", "target"); FIRE_EVENT("UNIT_AURA", "player"); FIRE_EVENT("UNIT_POWER_UPDATE", "player", "MANA")
end
FIRE_EVENT("PLAYER_REGEN_ENABLED")
RUN_TIMERS(10)
top("COMBATE (entrar, 50 golpes, salir)", 12, clock() - t)
guiasLeidas("al final")
print(("MEMORIA Lua al final: %.1f MB"):format(memoria() / 1024))
