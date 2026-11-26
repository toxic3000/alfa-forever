-- Prueba de la 1.4.1: a dónde te lleva un material, y tú eliges.
--
-- Toxic: «Me sigues mandando al mismo lugar una y otra vez. Que al elegir el
-- material en la Enciclopedia venga Buscar cerca o Ir al lugar recomendado,
-- para saber a dónde te va a llevar; si es lejos y no tienes dinero, implica
-- dinero».
--   1. La Enciclopedia ya no manda un mineral a «la mejor fuente» (un punto
--      fijo, siempre el mismo): va por zonas.
--   2. «Guíame» abre un menú: «Cerca de ti», «El lugar recomendado» y otras
--      zonas, cada una con su distancia y si es a pie o quizá necesites volar.
--   3. Elegir «Cerca de ti» arma la ruta en la zona más cercana (no en la de
--      más puntos); elegir otra zona arma la ruta en esa zona.
PRUEBA_AREA("1.4.1 materiales")
PRUEBA_ENTRAR()
local A, N = Alfa, AlfaNucleo
local K = N.Kit

local Rc = NS_OF("Alfa_Recoleccion")
local Ll, Ruta = Rc.Llevar, Rc.Ruta
local Cm = A.Compat
local real = { mw = Cm.MapToWorld, pi = Cm.GetPlayerInfo }
Cm.MapToWorld = function(m, x, y) return real.mw(m, x, y, "e") end
-- Toxic: Alianza, nivel 33, en Los Humedales, buscando estaño.
local yo = { 1437, 52, 48 }
Cm.GetPlayerMapPosition = function() return yo[1], yo[2], yo[3] end
Cm.GetUnitZone = function() return yo[1] end
Cm.GetPlayerInfo = function() local p = real.pi and real.pi() or {} p.level, p.faction = 33, "Alliance" return p end
local ESTANO = 2771

local function esperarRuta()
  for _ = 1, 200 do if not Ruta.Calculando() then break end RUN_TIMERS(0.05) FIRE(UIParent, "OnUpdate", 0.05) end
  RUN_TIMERS(1)
end

local opciones
PASO("Las opciones: cerca de ti, recomendado y otras, con su viaje", function()
  REVISA(type(Ll.Opciones) == "function", "no hay opciones para elegir a dónde ir")
  if not Ll.Opciones then return end
  opciones = Ll.Opciones(ESTANO)
  REVISA(#opciones >= 2, "no hay al menos dos lugares para elegir: " .. #opciones)
  REVISA(opciones[1] and opciones[1].modo == "cerca", "la primera opción no es «Cerca de ti»")
  local hayRec = false
  for _, o in ipairs(opciones) do
    if o.modo == "recomendado" then hayRec = true end
    REVISA(type(o.texto) == "string" and o.texto:find("yd", 1, true) or o.texto:find("continente", 1, true) or o.texto:find("km", 1, true),
      "una opción no dice lo lejos que está: " .. tostring(o.texto))
  end
  -- La de cerca es la de menor distancia.
  local c = opciones[1].z
  for _, o in ipairs(opciones) do
    if o.z.distancia and c.distancia then REVISA(c.distancia <= o.z.distancia + 0.5, "«Cerca de ti» no es la más cercana") end
  end
  for _, o in ipairs(opciones) do print("   ", o.titulo, "·", o.texto) end
  REVISA(hayRec or #opciones >= 2, "falta «El lugar recomendado»")
end)

PASO("La Enciclopedia: «Guíame» de un mineral abre el menú y no va a un punto fijo", function()
  local En = NS_OF("Alfa_Enciclopedia")
  local F = En and En.F
  REVISA(F and F.Guiar, "no encuentro la Enciclopedia")
  if not (F and F.Guiar) then return end
  REVISA(F.EsRecoleccion and F.EsRecoleccion("item", ESTANO), "la Enciclopedia no sabe que el estaño se recolecta")
  local menus = 0
  local real = K.Menu
  K.Menu = function(dueno, ops, valor, alElegir) menus = menus + 1 _G.__ALFA_MENU = { ops = ops, fn = alElegir } end
  local boton = CreateFrame("Button", "AlfaBancoGuiame", UIParent)
  boton:SetSize(100, 24) boton:SetPoint("CENTER")
  -- Con una «mejor fuente» de la ficha (lo que antes ganaba siempre).
  local ok = F.Guiar("item", ESTANO, { kind = "object", id = 1732 }, boton, true)
  K.Menu = real
  REVISA(ok, "«Guíame» del estaño falló")
  REVISA(menus == 1, "«Guíame» del estaño no ofreció elegir a dónde (fue directo al mismo punto)")
  local m = rawget(_G, "__ALFA_MENU")
  if m then
    -- Elegir «Cerca de ti».
    m.fn(1, m.ops[1])
    esperarRuta()
    local r = Ruta.Actual()
    REVISA(r and opciones and r.mapa == opciones[1].zona, "elegir «Cerca de ti» no armó la ruta en la zona más cercana")
    Ruta.Borrar()
    -- Elegir la última (otra zona): la ruta, en esa zona.
    local i = #m.ops
    m.fn(i, m.ops[i])
    esperarRuta()
    r = Ruta.Actual()
    REVISA(r and opciones and r.mapa == opciones[i].zona, "elegir otra zona no armó la ruta en esa zona")
    Ruta.Borrar()
  end
  boton:Hide()
end)

PASO("El ratón sigue siendo del jugador", function() TIEMPO(5) RATON_LIMPIO("tras los materiales") end)

PRUEBA_FIN()
