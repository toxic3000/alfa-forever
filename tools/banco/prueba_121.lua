-- Prueba de la 1.2.1, el mapa (tools/prueba.py la corre con las demás prueba_*.lua):
--   * el terreno: los lados que dan a un hueco se difuminan (la máscara justa
--     según hacia dónde crece la rejilla) y una tanda de texturas que espera
--     a una que no llega aparece sola, sin dejar un hueco;
--   * con el estilo clásico el arte de cada zona sigue; las zonas siguen
--     contando como a la vista para los demás módulos;
--   * la ruta de la flecha se dibuja en el mapa de Alfa, con el aro del
--     destino y la ficha (nombre, distancia y tiempo); su clic encuadra todo;
--   * el vuelo en grifo: al elegirlo se arma con sus escalas, se dibuja en el
--     aire, dice a dónde vas y se va al aterrizar; su capa lo apaga;
--   * tu marca en el mapa: resaltada y con su pulso.
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
local A = Alfa
-- Un mundo en yardas para el banco (su cliente no da GetWorldPosFromMapPos):
-- Kalimdor es el continente 1 y los Reinos del Este el 0, norte arriba.
local MUNDOS = { [1414] = { 1, 12000, 6000, -24000, -16000 }, [1415] = { 0, 8000, 9000, -20000, -14000 } }
local mapToWorldReal = A.Compat.MapToWorld
A.Compat.MapToWorld = function(mapa, x, y, f)
  local m = MUNDOS[mapa]
  if m and f == nil then return m[1], m[2] + (y / 100) * m[4], m[3] + (x / 100) * m[5] end
  return mapToWorldReal(mapa, x, y, f)
end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local Mu = NS_OF("Alfa_Mundo")
local Lz, V, Tr, Mc = Mu.Lienzo, Mu.Ventana, Mu.Trayecto, Mu.Marcas
local S = A.RouteStrokes

local vista
local function cuadros(n)
  for _ = 1, n do
    NOW = NOW + 0.03
    FIRE(vista, "OnUpdate", 0.03)
    for _, hijo in ipairs({ vista:GetChildren() }) do
      if hijo:IsShown() and hijo._scripts and hijo._scripts.OnUpdate then FIRE(hijo, "OnUpdate", 0.03) end
    end
  end
end

-- Un punto de Kalimdor en yardas a partir de su lugar en el mapa (0..100).
local function enKalimdor(x, y)
  local c, wx, wy = A.Compat.MapToWorld(1414, x, y)
  return { c, wx, wy }
end

step("terreno: la máscara de cada mosaico según sus vecinos", function()
  if not Lz.Bordes then error("falta Lienzo.Bordes") end
  local mos = {}
  local function hay(col, fila) mos[col * 64 + fila] = { col = col, fila = fila } end
  hay(10, 10); hay(11, 10) -- el mosaico y su vecino de la columna siguiente
  -- La columna crece a la derecha (bx > 0) y la fila hacia abajo (by > 0):
  -- solo el este tiene vecino; norte (1) + sur (4) + oeste (8) se difuminan.
  local m = mos[10 * 64 + 10]
  local n = Lz.Bordes({ mos = mos, bx = 8, by = 8 }, m)
  if n ~= 13 then error("con el vecino al este la máscara debía ser 13 y fue " .. tostring(n)) end
  -- La rejilla al revés (bx < 0): la columna siguiente queda a la izquierda.
  n = Lz.Bordes({ mos = mos, bx = -8, by = 8 }, m)
  if n ~= 7 then error("con el vecino al oeste la máscara debía ser 7 y fue " .. tostring(n)) end
  -- Un vecino que no cargó (malo) es un hueco.
  mos[11 * 64 + 10].malo = true
  n = Lz.Bordes({ mos = mos, bx = 8, by = 8 }, m)
  if n ~= 15 then error("un vecino que no cargó no cuenta como hueco") end
  -- Rodeado: sin máscara.
  hay(9, 10); hay(10, 9); hay(10, 11); mos[11 * 64 + 10].malo = nil
  if Lz.Bordes({ mos = mos, bx = 8, by = 8 }, m) ~= 0 then error("un mosaico rodeado no debe difuminarse") end
end)

step("terreno: las máscaras existen en el paquete", function()
  for i = 1, 15 do
    local f = io.open("dist/Alfa_Mundo/Media/Borde/borde-" .. i .. ".tga", "rb")
    if not f then error("falta Media/Borde/borde-" .. i .. ".tga (tools/bordes.py)") end
    f:close()
  end
end)

step("mapa: una tanda que espera a una textura que no llega aparece sola", function()
  local P = Lz.Prueba
  if not P then error("falta Lienzo.Prueba") end
  local f = CreateFrame("Frame", nil, UIParent)
  local mala, a, b = f:CreateTexture(), f:CreateTexture(), f:CreateTexture()
  rawset(mala, "SetTexture", function() error("archivo dañado") end)
  P.NuevaTanda()
  P.Encolar(mala, 1); P.Encolar(a, 2); P.Encolar(b, 3)
  pcall(P.Cargar) -- falla en la mala: se queda sin llegar nunca
  P.Cargar()
  NOW = NOW + 0.1
  P.Cargar()
  if a:GetAlpha() > 0 or b:GetAlpha() > 0 then error("aparecieron antes de que su tanda se cansara de esperar") end
  NOW = NOW + 2.5
  P.Cargar()
  NOW = NOW + 0.5
  P.Cargar()
  if a:GetAlpha() < 1 or b:GetAlpha() < 1 then error("la tanda se quedó escondida esperando a la textura que no llega") end
  local _, tandas = Lz.Cargando()
  if tandas > 0 then error("quedó una tanda esperando") end
end)

step("mapa: con el estilo clásico vuelve el arte de cada zona", function()
  A.Set("mundo.estiloMapa", "clasico")
  Lz.Estilo()
  if not Lz.ArteDeZonas() then error("con el estilo clásico el arte de las zonas debe verse") end
  A.Set("mundo.estiloMapa", "terreno")
  Lz.Estilo()
end)

-- La ruta de prueba: de donde estás (Durotar en el banco) a un punto al norte.
local INICIO, META = enKalimdor(60, 52), enKalimdor(64, 40)
local caminoA = S.Path("walk", { INICIO, enKalimdor(61, 48), enKalimdor(63, 44), META }, false)
local caminoB = S.Path("boat", { META, enKalimdor(70, 30) }, true)
local yoAhora = { INICIO[1], INICIO[2], INICIO[3] }
A.Compat.GetPlayerWorldPosition = function() return yoAhora[1], yoAhora[2], yoAhora[3] end
local pathsReal = A.RouteLines.GetPaths
local function conRuta(on)
  if on then
    A.Nav.GetTarget = function() return { label = "Puerto de prueba" } end
    A.Nav.GetTargetWorld = function() return META[1], META[2], META[3] end
    A.RouteLines.GetPaths = function() return { caminoA, caminoB } end
  else
    -- Sin destino (el banco trae el de la guía: aquí se quita).
    A.Nav.GetTarget = function() return nil end
    A.Nav.GetTargetWorld = function() return nil end
    A.RouteLines.GetPaths = pathsReal
  end
  Tr.Cambio()
end

step("ruta: se dibuja en el mapa de Alfa con su destino y su ficha", function()
  A.Set("nav.routeLines", true)
  conRuta(true)
  V.Abrir(1414)
  vista = _G.AlfaMundoMapa and _G.AlfaMundoMapa.Vista
  if not vista then error("no se abrió el mapa") end
  cuadros(20)
  if next(Tr.Proyecciones()) == nil then error("sin proyección de yardas al mapa continuo") end
  V.VerCamino()
  cuadros(60)
  if Tr.Dibujados() == 0 then error("la ruta no se dibujó en el mapa de Alfa") end
  local aro = Tr.Aro()
  if not (aro and aro:IsShown()) then error("el destino no tiene su aro") end
  local ficha = Tr.Ficha()
  if not (ficha and ficha:IsShown()) then error("no salió la ficha del camino") end
  if ficha.Nombre:GetText() ~= "Puerto de prueba" then error("la ficha no dice a dónde vas: " .. tostring(ficha.Nombre:GetText())) end
  local datos = ficha.Datos:GetText() or ""
  if not (datos:find("yd") or datos:find(" m")) then error("la ficha no dice cuánto falta: " .. datos) end
  if ficha:GetWidth() > 380 + 1 then error("la ficha se pasa de su ancho") end
  -- La ventana pintada (tools/banco/shot-mapa121.png): la ficha no se corta ni se sale.
  local entries, l, b, w, h = DUMP(_G.AlfaMundoMapa)
  SNAPSHOTS["mapa121"] = { entries = entries, l = l, b = b, w = w, h = h }
end)

step("ruta: la línea empieza justo donde estás (yardas bien puestas en el mapa)", function()
  A.Set("nav.lineStyle", "line")
  cuadros(4)
  local s, margen = Tr.Trazos(INICIO[1])
  if not (s and s.n > 0) then error("sin trazos en Kalimdor") end
  local px, py = Tr.AVista(yoAhora[1], yoAhora[2], yoAhora[3])
  -- El dueño de las líneas tiene su esquina en (-margen, -margen) de la vista;
  -- sus trazos van con y negativa hacia abajo.
  local x, y = -margen + s.x1[1], -margen - s.y1[1]
  if math.abs(x - px) > 2 or math.abs(y - py) > 2 then
    error(string.format("la línea empieza en (%.1f, %.1f) y tú estás en (%.1f, %.1f)", x, y, px, py))
  end
  -- Y termina en el destino del último tramo dibujado en este continente.
  local mx, my = Tr.AVista(META[1], META[2], META[3])
  local cerca = false
  for i = 1, s.n do
    local ex, ey = -margen + s.x2[i], -margen - s.y2[i]
    if math.abs(ex - mx) < 3 and math.abs(ey - my) < 3 then cerca = true break end
  end
  if not cerca then error("ningún trazo llega al destino") end
end)

step("ruta: al caminar, el camino empieza donde vas y la distancia baja", function()
  local antes = Tr.Falta(Tr.Caminos(), yoAhora[1], yoAhora[2], yoAhora[3])
  local p = enKalimdor(61.5, 46)
  yoAhora[2], yoAhora[3] = p[2], p[3]
  NOW = NOW + 0.2
  cuadros(6)
  local despues = Tr.Falta(Tr.Caminos(), yoAhora[1], yoAhora[2], yoAhora[3])
  if not (despues < antes) then error(string.format("la distancia no bajó al avanzar (%.0f -> %.0f)", antes, despues)) end
end)

step("ruta: con la línea de la ruta apagada no se dibuja", function()
  A.Set("nav.routeLines", false)
  cuadros(4)
  if Tr.Dibujados() > 0 then error("se dibujó con la línea de la ruta apagada") end
  A.Set("nav.routeLines", true)
  conRuta(false)
  cuadros(4)
  if Tr.Dibujados() > 0 then error("sin destino quedó una línea") end
  if Tr.Ficha():IsShown() then error("sin destino quedó la ficha") end
end)

-- El vuelo de prueba: tres maestros de vuelo, dos escalas.
local NODOS = { [101] = enKalimdor(60, 52), [102] = enKalimdor(55, 40), [103] = enKalimdor(48, 30) }
local enAire = false
A.Compat.IsOnTaxi = function() return enAire end
A.Maps.Client.TaxiSlot = function(slot) return 100 + slot, "Nodo " .. slot .. ", Kalimdor" end
A.Nav.GetTaxiNode = function(id) local p = NODOS[id] return p and { c = p[1], wx = p[2], wy = p[3] } end
GetNumRoutes = function() return 2 end
TaxiGetNodeSlot = function(slot, i, origen) if origen then return i end return i + 1 end
A.Maps.GetFlight = function() return "Nodo 3", 42, "estimate" end

step("vuelo: al elegirlo se arma con sus escalas", function()
  Tr.AlTomar(3)
  local v = Tr.Vuelo()
  if not v then error("no se armó el vuelo") end
  if v.path.kind ~= "flight" or v.path.n < 3 then error("el vuelo no tiene sus escalas") end
  if v.nombre ~= "Nodo 3" then error("el destino del vuelo no es el último nodo: " .. tostring(v.nombre)) end
  local d = NS_OF("Alfa_Nucleo") and AlfaNucleo.DatosPersonaje("mundo")
  if not (d and type(d.vuelo) == "table") then error("el vuelo no se guardó para un /reload en el aire") end
end)

step("vuelo: en el aire se dibuja y la ficha dice a dónde vas", function()
  enAire = true
  local p = enKalimdor(57, 46)
  yoAhora[2], yoAhora[3] = p[2], p[3]
  NOW = NOW + 0.2
  cuadros(6)
  if Tr.Dibujados() == 0 then error("el vuelo no se dibujó en el mapa") end
  local ficha = Tr.Ficha()
  if not ficha:IsShown() then error("sin ficha en el aire") end
  local titulo = ficha.Nombre:GetText() or ""
  if not titulo:find("Nodo 3", 1, true) then error("la ficha no dice a dónde vuelas: " .. titulo) end
  if not (ficha.Datos:GetText() or ""):find("0:42", 1, true) then error("la ficha no dice el tiempo de vuelo") end
end)

step("vuelo: su capa lo apaga", function()
  A.Set("mundo.vueloEnMapa", false)
  cuadros(4)
  if Tr.Dibujados() > 0 then error("se dibujó el vuelo con su capa apagada") end
  A.Set("mundo.vueloEnMapa", true)
  cuadros(4)
  if Tr.Dibujados() == 0 then error("el vuelo no volvió al encender su capa") end
end)

step("vuelo: al aterrizar se va", function()
  enAire = false
  NOW = NOW + 0.2
  cuadros(6)
  if Tr.Vuelo() then error("el vuelo siguió después de aterrizar") end
  if Tr.Dibujados() > 0 then error("quedó la línea del vuelo") end
  if AlfaNucleo.DatosPersonaje("mundo").vuelo ~= nil then error("quedó guardado el vuelo") end
end)

step("tú: resaltado en el mapa, con su pulso", function()
  local yo = Mc.Yo()
  if not (yo and yo:IsShown()) then error("no está tu marca en el mapa") end
  if not (yo.pulso and yo.pulso.latido and yo.sombra and yo.aro) then error("tu marca no tiene su pulso, su sombra y su aro") end
  A.Set("ui.reduceMotion", true)
  cuadros(4)
  if yo.pulso:IsShown() then error("con menos movimiento tu pulso siguió") end
  A.Set("ui.reduceMotion", false)
  cuadros(4)
end)

V.Cerrar()
print("PRUEBA: 1.2.1, " .. pasos .. " pasos, " .. #ERRORS .. " errores")
