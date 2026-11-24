-- Revisión visual de la 1.3.9 (mejoras 56, 60 y 61): cada página y cada
-- pestaña de la ventana de Alfa, en un estilo y con o sin letra grande.
-- No es parte de la suite (no empieza con prueba_): se corre a mano y dibuja
-- tools/banco/shot-139r-<estilo>[-grande]-<página>[-<pestaña>].png. El
-- dibujo marca lo que se corta («CORTADO ...») o se sale de su caja.
--   BANCO_ESTILO=alfa|clasico|cristal   (alfa de fábrica)
--   BANCO_GRANDE=1                      letra grande (nucleo.letraGrande)
--   BANCO_PAGINAS=inicio,rutas          solo esas páginas
--   .venv/Scripts/python -I tools/banco/run.py <dist> <módulos> revision139.lua
SNAPSHOTS = {}
local ESTILO = (os and os.getenv and os.getenv("BANCO_ESTILO")) or "alfa"
local GRANDE = (os and os.getenv and os.getenv("BANCO_GRANDE")) and true or false
local PREFIJO = "139r-" .. ESTILO .. (GRANDE and "-grande" or "")
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[PREFIJO .. "-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
end
local function step(nombre, fn, ...)
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 600)) end
  end
end
BANCO_LETRA = 0.64
PANTALLA_SIMULADA(1920, 1500)
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N, B = AlfaNucleo, AlfaBienvenida
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(8)
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
local A = Alfa
local K = N.Kit
local O = A.UI.Options
-- Lo que tapa la foto (Lya, avisos, la flecha).
local function limpiar()
  for _, n in ipairs({ "AlfaLyaLoba", "AlfaInicioAviso", "AlfaRastreador", "AlfaNavArrow" }) do
    local f = rawget(_G, n)
    if type(f) == "table" and f.Hide then f:Hide() end
  end
end
step("estilo", function()
  if ESTILO ~= "alfa" then K.SetEstilo(ESTILO) end
  if GRANDE then A.Set("nucleo.letraGrande", true) end
end)
RUN_TIMERS(3)
local solo = os and os.getenv and os.getenv("BANCO_PAGINAS")
local quiero
if type(solo) == "string" and solo ~= "" then
  quiero = {}
  for p in solo:gmatch("[^,]+") do quiero[p] = true end
end
local function nombre(s)
  s = tostring(s or ""):lower():gsub("[^a-z0-9]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
  return s ~= "" and s or "x"
end
A.Fire("SHOW_OPTIONS", "inicio")
RUN_TIMERS(2)
local f = O.frame or rawget(_G, "AlfaOptions")
-- La ventana alta, para ver la página entera (lo de abajo también se revisa).
local Vt = NS_OF("Alfa_Bienvenida").Ventana
if Vt and Vt.SetAlto then pcall(Vt.SetAlto, 1400) end
local n = 0
for _, p in ipairs(O.Pages()) do
  if not quiero or quiero[p.key] then
    local tabs = #p.tabs > 0 and p.tabs or { "" }
    for _, t in ipairs(tabs) do
      step(p.key .. " " .. tostring(t), function()
        O.Select(p.key, t)
        RUN_TIMERS(2)
        limpiar()
        f = O.frame or rawget(_G, "AlfaOptions")
        if f then
          SNAP(nombre(p.key) .. (t ~= "" and ("-" .. nombre(t)) or ""), f)
          n = n + 1
        end
      end)
    end
  end
end
print(string.format("PRUEBA: revisión 1.3.9 (%s%s), %d vistas, errores: %d", ESTILO, GRANDE and ", letra grande" or "", n, #ERRORS))
