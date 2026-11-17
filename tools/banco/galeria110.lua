-- Escenas de la 1.1.0 para la galería (tools/banco/run.py dist <módulos> galeria110.lua)
-- Datos de muestra inventados (personaje "Lobato"), nada del jugador.
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
-- El banco calcula el ancho de las letras a ojo; con un poco más de margen
-- los textos no se cortan al dibujarlos con la letra real.
BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
C_SkillInfo = { GetSkillLineInfoByID = function(id)
  if id == 356 then return { rank = 126, maxRank = 225, modifier = 25 } end
  if id == 185 then return { rank = 110, maxRank = 150 } end
  return nil
end }
GetRealZoneText = function() return "Bosque de Elwynn" end
GetSubZoneText = function() return "Lago Espejo" end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
local A, N = Alfa, AlfaNucleo
local K = N.Kit
local before = #ERRORS
if A.UI.Options.frame then A.UI.Options.frame:Hide() end

-- Bienvenida: el idioma y "¿Qué es Alfa?"
local B = NS_OF("Alfa_Bienvenida")
step("bienvenida", function() B.AbrirVentana("asistente") end)
RUN_TIMERS(2)
local bv = _G.AlfaBienvenidaVentana
local asis = bv and bv.alfaAsistente
if asis then
  bv:SetTamano(820, 760)
  for i, nombre in ipairs({ "bv-idioma", "bv-quees" }) do
    step(nombre, function() asis:Ir(i) end)
    RUN_TIMERS(1)
    SNAP(nombre, bv)
  end
  bv:Hide()
end
-- Lobato ya terminó su bienvenida: las demás ventanas se abren sin la puerta.
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end

-- Lya: la ventana Historias con tres misiones de ejemplo (textos propios)
step("historias", function()
  local d = N.Datos("lya")
  d.historias = { q = {
    [90001] = { t = "Los lobos de la colina", z = 37, zn = "Bosque de Elwynn", g = "Guardia Thomas", e = "Guardia Thomas", a = 1,
      d = "Algo anda mal en la colina del este. Los lobos bajan cada noche más cerca del camino, y los granjeros ya no se atreven a salir.\n\nAlguien tiene que averiguar qué los está empujando fuera del bosque antes de que lastimen a alguien.",
      o = "Busca el rastro de los lobos en la colina del este y vuelve con lo que encuentres.", u = 3 },
    [90002] = { t = "Velas para la mina", z = 37, zn = "Bosque de Elwynn", g = "Minero Leo", e = "Minero Leo", a = 1, c = 1,
      d = "Los túneles se quedaron a oscuras y nadie quiere bajar sin luz.", o = "Consigue velas para los mineros.",
      r = "Con luz otra vez, los mineros vuelven al trabajo. Te deben una.", u = 2 },
    [90003] = { t = "Un mensaje para el Cruce", z = 10, zn = "Los Baldíos", g = "Mensajera Ana", e = "Tabernero Gorn", a = 1,
      d = "Una carta sellada que tiene que llegar antes del anochecer.", o = "Lleva la carta al Cruce.", u = 1 },
  } }
end)
step("abrir historias", function() AlfaLya.Historias(90001) end)
RUN_TIMERS(3)
local hv = _G.AlfaLyaHistorias or _G.AlfaHistorias
if not hv then for _, n in ipairs({ "AlfaLyaHistoriasVentana", "AlfaHistoriasVentana" }) do hv = hv or rawget(_G, n) end end
if hv then SNAP("lya-historias", hv) hv:Hide() else print("sin ventana de historias") end

-- Pesca: diario y guía con datos de muestra
local P = NS_OF("Alfa_Pesca")
step("pesca datos", function()
  local d = N.DatosPersonaje("pesca")
  local ahora = time()
  d.diario = {
    [6303] = { n = 132, primera = ahora - 86400 * 9, ultima = ahora - 600, hab = 12, zonas = { ["Bosque de Elwynn"] = 90, ["Durotar"] = 42 }, nombre = "Caballa escurridiza cruda", calidad = 1 },
    [6291] = { n = 58, primera = ahora - 86400 * 10, ultima = ahora - 3600, hab = 1, zonas = { ["Bosque de Elwynn"] = 58 }, nombre = "Pececillo brillante crudo", calidad = 1 },
    [6289] = { n = 21, primera = ahora - 86400 * 2, ultima = ahora - 7200, hab = 80, zonas = { ["Páramos de Poniente"] = 21 }, nombre = "Pargo de barro mandíbula larga crudo", calidad = 1 },
    [21071] = { n = 12, primera = ahora - 86400, ultima = ahora - 1200, hab = 110, zonas = { ["Loch Modan"] = 12 }, nombre = "Pargo crudo", calidad = 1 },
    [6292] = { n = 1, primera = ahora - 5000, ultima = ahora - 5000, hab = 118, zonas = { ["Loch Modan"] = 1 }, nombre = "Pargo de barro de 10 libras", calidad = 1 },
  }
  d.vida = { lanzamientos = 812, capturas = 640, total = 671, escapes = 41, segundos = 15000, activo = 21000, valor = 33100, subasta = 52000,
    sesiones = 9, cebos = 12, bancos = 30, lotes = 4, cocinado = 66, mejorRacha = 22, mejorHora = 3700, mejorValor = 5100, primera = ahora - 86400 * 12 }
  d.logros = { primera = ahora - 86400 * 12, cien = ahora - 86400 * 6, especies5 = ahora - 86400 }
end)
for _, tab in ipairs({ "diario", "guia" }) do
  step("pesca " .. tab, function() P.V.Abrir(tab) end)
  RUN_TIMERS(3)
  if _G.AlfaPescaVentana then SNAP("pesca-" .. tab, _G.AlfaPescaVentana) end
end
if _G.AlfaPescaVentana then _G.AlfaPescaVentana:Hide() end
step("pesca modo", function() P.AbrirModo() end)
RUN_TIMERS(2)
local barra = _G.AlfaPescaBarra
if barra then SNAP("pesca-barra", barra) end
step("pesca cerrar", function() P.CerrarModo() end)

-- Paisaje y gráficos
step("paisaje", function() AlfaVista.Abrir() end)
RUN_TIMERS(3)
if _G.AlfaVistaVentana then SNAP("vista", _G.AlfaVistaVentana) _G.AlfaVistaVentana:Hide() end

-- Mis planes
step("plan", function()
  local pl = AlfaPlanes.Nuevo("Mi primera montura")
  if pl then
    for _, m in ipairs({
      { tipo = "nivel", nivel = 40 },
      { tipo = "oro", cobre = 1000000 },
      { tipo = "objeto", item = 2589, cantidad = 20, nombre = "Paño de lino" },
      { tipo = "nota", texto = "Pedirle a la manada que me acompañe a Ventormenta." },
    }) do AlfaPlanes.AgregarMeta(pl.id, m) end
    AlfaPlanes.Abrir(pl.id)
  end
end)
RUN_TIMERS(5)
if _G.AlfaPlanEditor then SNAP("planes", _G.AlfaPlanEditor) _G.AlfaPlanEditor:Hide() end

-- Monturas en la Enciclopedia
step("monturas", function() NS_OF("Alfa_Enciclopedia").V.Abrir({ kind = "guia", id = "montura" }) end)
RUN_TIMERS(5)
if _G.AlfaEnciclopediaVentana then SNAP("monturas", _G.AlfaEnciclopediaVentana) _G.AlfaEnciclopediaVentana:Hide() end

-- Buscar cerca
step("cerca", function() AlfaCerca.Menu() end)
RUN_TIMERS(2)
for _, n in ipairs({ "AlfaCercaMenu", "AlfaCerca" }) do
  local f = rawget(_G, n)
  if type(f) == "table" and f.IsShown and f:IsShown() then SNAP("cerca", f) break end
end

print("errores en galeria 1.1.0:", #ERRORS - before)
for i = before + 1, math.min(#ERRORS, before + 8) do print(ERRORS[i]) end
