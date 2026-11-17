-- Escenas de la 1.0 para la galería (tools/banco/run.py ... galeria.lua)
SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[name] = { entries = entries, l = l, b = b, w = w, h = h }
end
local function step(name, fn, ...)
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("step " .. name, e) end
end
BANCO_LETRA = 0.64 -- margen: el banco mide las letras a ojo
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
-- Lobato ya terminó su bienvenida: sin la puerta de la configuración.
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
local A = Alfa
local before = #ERRORS
for _, id in ipairs(rawget(_G, "BANCO_PAGINAS") or { "inicio", "rutas", "enciclopedia", "builds", "bolsas", "manada", "mazmorras", "mundo" }) do
  step("abrir " .. id, function() A.Fire("SHOW_OPTIONS", id) end)
  RUN_TIMERS(3)
  local f = A.UI.Options.frame or _G.AlfaOptions; if f then SNAP("g-" .. id, f) else print("sin ventana", id) end
end
print("errores en galeria:", #ERRORS - before)
for i = before + 1, math.min(#ERRORS, before + 8) do print(ERRORS[i]) end

-- Ventanas propias de los módulos
local function ns(n) return NS_OF(n) end
local O = A.UI.Options.frame
if O then O:Hide() end
step("asistente", function() ns("Alfa_Rutas").Asistente.Abrir() end)
RUN_TIMERS(3)
if _G.AlfaAsistente then SNAP("v-asistente", _G.AlfaAsistente); _G.AlfaAsistente:Hide() end
step("enciclopedia", function() ns("Alfa_Enciclopedia").V.Abrir({ texto = "lobo" }) end)
RUN_TIMERS(5)
if _G.AlfaEnciclopediaVentana then SNAP("v-enciclopedia", _G.AlfaEnciclopediaVentana); _G.AlfaEnciclopediaVentana:Hide() end
step("rastreador", function() ns("Alfa_Rutas").Rastreador.Mostrar() end)
RUN_TIMERS(5)
if _G.AlfaRastreador then SNAP("v-rastreador", _G.AlfaRastreador) end
step("biblioteca", function() local B = ns("Alfa_Rutas").Biblioteca; if B and B.Abrir then B.Abrir() end end)
RUN_TIMERS(3)
if _G.AlfaBiblioteca then SNAP("v-biblioteca", _G.AlfaBiblioteca); _G.AlfaBiblioteca:Hide() end
step("mapa", function() ns("Alfa_Mundo").Ventana.Abrir() end)
RUN_TIMERS(5)
if _G.AlfaMundoMapa then SNAP("v-mapa", _G.AlfaMundoMapa); _G.AlfaMundoMapa:Hide() end
print("errores en ventanas:", #ERRORS - before)
for i = before + 1, math.min(#ERRORS, before + 8) do print(ERRORS[i]) end
