-- Prueba de la 1.3.9, el clic en la flecha (tools/prueba.py la corre con las demás):
--   * en un área con varios lugares, la placa con «Siguiente lugar» se queda y
--     un clic en la flecha pasa al siguiente lugar aunque haya pasado el rato;
--   * una ruta propia (Nav.OtroLugar) también toma el clic de la flecha;
--   * sin otro lugar, la placa se va y la flecha no atrapa clics.
SNAPSHOTS = {}
local function step(nombre, fn, ...)
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.3.9 flecha", msg) end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local A = AlfaNucleo.A
local E = A.Engine
local Nav = A.Nav
local Arrow = Nav and Nav.arrow

local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do t[k] = a.v end
  if not ok then error(e) end
end

-- Corre la placa hasta mucho después de su rato.
local function pasaElRato()
  local f = Arrow.llegada
  if not f then return end
  local fn = f:GetScript("OnUpdate")
  for _ = 1, 400 do if fn then fn(f, 0.1) end end
end

local function llegar(target, estado, fn)
  local veces = 0
  con(Nav, {
    Sample = function() return estado, 3, 0 end,
    GetTarget = function() return target end,
    NextSpot = function() if target.spots then veces = veces + 1 return true end return false end,
    TomTomArrowGuides = function() return false end,
    HandedOff = function() return false end,
    HiddenWithGuide = function() return false end,
  }, function()
    con(E, { GetStepView = function() return { index = 1, goals = { { t = "kill", status = "active" } } } end, GetGuide = function() return nil end }, function()
      con(A, { ArrowHidden = function() return false end }, function()
        Arrow:OnTarget(target)
        fn(function() return veces end)
        Arrow:OnTarget(nil)
        Arrow.frame:Hide()
      end)
    end)
  end)
end

step("Área con varios lugares: el clic en la flecha sigue sirviendo después del rato", function()
  check(Arrow and Arrow.Llegada, "falta Arrow.Llegada")
  local T = { label = "Busca Mena de plata", stepIndex = 1, goalIndex = 1, spots = { {}, {}, {} }, map = 1440, x = 50, y = 50 }
  llegar(T, "search", function(veces)
    check(Arrow.Llegada() ~= nil, "la placa de llegada no salió")
    pasaElRato()
    check(Arrow.llegada:IsShown(), "con «Siguiente lugar» la placa se fue sola")
    check(Arrow.frame:IsMouseEnabled(), "tras el rato la flecha ya no toma el ratón")
    local up = Arrow.frame:GetScript("OnMouseDown")
    if up then up(Arrow.frame, "LeftButton") end
    FIRE(Arrow.frame, "OnMouseUp", "LeftButton")
    check(veces() == 1, "el clic en la flecha no pasó al siguiente lugar")
  end)
end)

step("Ruta propia (Nav.OtroLugar): el clic en la flecha va a su siguiente parada", function()
  local idas = 0
  Nav.OtroLugar = { disponible = function() return true end, ir = function() idas = idas + 1 return true end }
  local T = { label = "Ruta 3/12: Veta de estaño", map = 1440, x = 50, y = 50 }
  llegar(T, "search", function()
    pasaElRato()
    check(Arrow.frame:IsMouseEnabled(), "con una ruta propia la flecha no toma el ratón tras el rato")
    FIRE(Arrow.frame, "OnMouseDown", "LeftButton")
    FIRE(Arrow.frame, "OnMouseUp", "LeftButton")
    check(idas == 1, "el clic no llamó a Nav.OtroLugar.ir")
  end)
  Nav.OtroLugar = nil
end)

step("Sin otro lugar: la placa se va y nada invisible atrapa clics", function()
  local T = { label = "Habla con Gornek", map = 1440, x = 50, y = 50 }
  llegar(T, "search", function()
    pasaElRato()
    check(not Arrow.llegada:IsShown(), "sin nada que contar la placa no se fue")
    check(not Arrow.frame:IsMouseEnabled(), "ya ida, la flecha sigue atrapando clics")
  end)
end)

-- 1.3.9 (juego real): Rastreador.lua:1007 comparaba GetUnitSpeed, que en
-- combate y en mazmorras llega secreta.
step("La distancia del rastreador con la velocidad secreta no truena", function()
  local Ru = NS_OF("Alfa_Rutas")
  local Rs = Ru and Ru.Rastreador
  check(Rs and Rs.Distancia, "falta Rastreador.Distancia")
  local T = { label = "Mena de plata", map = 1440, x = 50, y = 50 }
  local vieja = GetUnitSpeed
  SECRETOS_PRENDER({ "GetUnitSpeed" })
  con(Nav, {
    GetTarget = function() return T end,
    TargetOffset = function() return 300, 200 end,
  }, function()
    local ok, txt, tono, _, seg = pcall(Rs.Distancia)
    check(ok, "Rs.Distancia truena con la velocidad secreta: " .. tostring(txt))
    check(ok and type(txt) == "string" and type(seg) == "number", "sin texto o sin tiempo con la velocidad secreta")
  end)
  SECRETOS_APAGAR()
  check(GetUnitSpeed == vieja, "GetUnitSpeed no volvió")
end)
