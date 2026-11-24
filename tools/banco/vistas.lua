-- Capturas para la prueba visual (1.3.9): cada página de Alfa y las
-- ventanas propias que más se usan, siempre en el mismo estado, para que
-- tools/regresion.py las compare con las de la versión anterior
-- (tools/banco/referencia/vistas.json.gz) y avise lo que cambió.
--
-- Corre con BANCO_CAPTURAS=<carpeta> y BANCO_VOLCAR=1 (lo pone regresion.py):
-- run.py deja ahí un PNG y un JSON por captura, nunca en tools/banco.
-- BANCO_VISTAS=inicio,rutas captura solo esas páginas.
SNAPSHOTS = {}
local function SNAP(nombre, raiz)
  local entries, l, b, w, h = DUMP(raiz)
  SNAPSHOTS[nombre] = { entries = entries, l = l, b = b, w = w, h = h }
end
local function paso(nombre, fn, ...)
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("vistas " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 500)) end
  end
end

-- Siempre lo mismo: la misma suerte, el mapa cerrado y la bienvenida ya vista.
math.randomseed(139)
BANCO_LETRA = 0.64
if WorldMapFrame and WorldMapFrame.Hide then WorldMapFrame:Hide() end
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
do
  local N, B = AlfaNucleo, AlfaBienvenida
  N.Datos("bienvenida").respondio = B and B.VERSION or 99
  N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
end
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
local N, A = AlfaNucleo, Alfa
if N.Entrando then N.Entrando = function() return false end end
-- Lya y los avisos no se cruzan en las capturas (cambian con la suerte).
if AlfaLya and AlfaLya.Callar then pcall(AlfaLya.Callar, true) end

local solo
do
  local s = os.getenv and os.getenv("BANCO_VISTAS")
  if s and s ~= "" then
    solo = {}
    for id in s:gmatch("[^,]+") do solo[id] = true end
  end
end

local n = 0
for _, spec in ipairs(N.modulos or {}) do
  local id = spec.id
  if not solo or solo[id] then
    paso("abrir " .. id, function() A.Fire("SHOW_OPTIONS", id) end)
    RUN_TIMERS(3)
    local f = A.UI.Options.frame or rawget(_G, "AlfaOptions")
    if f and f:IsShown() then
      SNAP("pagina-" .. id, f)
      n = n + 1
    else
      print("AVISO VISUAL: la página " .. id .. " no abrió")
    end
  end
end
if A.UI.Options.frame then A.UI.Options.frame:Hide() end

-- Ventanas propias (solo sin BANCO_VISTAS).
local function ventana(nombre, abrir, global)
  paso("ventana " .. nombre, abrir)
  RUN_TIMERS(3)
  local f = rawget(_G, global)
  if f and f:IsShown() then
    SNAP("ventana-" .. nombre, f)
    n = n + 1
    f:Hide()
  end
end
if not solo then
  ventana("rastreador", function() NS_OF("Alfa_Rutas").Rastreador.Mostrar() end, "AlfaRastreador")
  ventana("mapa", function() NS_OF("Alfa_Mundo").Ventana.Abrir() end, "AlfaMundoMapa")
  ventana("reporte", function() AlfaReporte.Abrir("error") end, "AlfaReporteVentana")
end
print("VISTAS capturadas: " .. n)
