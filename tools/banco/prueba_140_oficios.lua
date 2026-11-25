-- Prueba de la 1.4.0, oficios, comercio y pesca (tools/prueba.py la corre con las demás):
--   8. recetas reales de Forever: al abrir tu oficio se guarda el recetario de
--      la cuenta (reactivos, gris, colores vistos) y la guía de Sastrería
--      225–300 baja de costo con las recetas que ya sabes (antes ~3,195 telas
--      rúnicas); sin datos del juego queda como estaba;
--  31. «Comprar lo que falta» en el paso de materiales de una guía de oficio:
--      la lista de compras con lo que se compra en la subasta;
--  46. un material de tu lista barato en la subasta: un solo aviso;
--  47. tu semana en la subasta: ventas y compras de las cartas del buzón;
--  48. Recolección: el oro estimado de la sesión y por hora;
--  49. Pesca: la meta del día y el festejo de Lya;
--  50. Pesca: el recordatorio del cebo con su botón seguro;
--  51. Oficios: una receta que pasa a verde avisa y dice cuál sigue.
SNAPSHOTS = {}
local CAPTURAS = os and os.getenv and os.getenv("BANCO_CAPTURAS")
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["140-oficios-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
end
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 900)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.4.0 oficios", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

local N = AlfaNucleo
local A = Alfa
Alfa.Hidden = Alfa.Hidden or function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

-- Habilidades a mano: línea -> { rank, max }
local HAB = {}
C_SkillInfo = C_SkillInfo or {}
local skillReal = C_SkillInfo.GetSkillLineInfoByID
C_SkillInfo.GetSkillLineInfoByID = function(id)
  local h = HAB[id]
  if not h then return nil end
  return { rank = h[1], maxRank = h[2], isHeader = false }
end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end

local Ru = NS_OF("Alfa_Rutas")
local Co = NS_OF("Alfa_Comercio")
local Of = Ru.OficiosGuia
local Cr = Ru.OficiosCrear
local function mover() for _ = 1, 40 do if Co.motorTareas and Co.motorTareas:IsShown() then FIRE(Co.motorTareas, "OnUpdate", 0.05) end end end

local SASTRERIA, RUNICA, ROLLO, HILO = 197, 14047, 14048, 14341

-- Cuánto pide el tramo 4 de un material, con la guía armada y con la clásica.
local function cuanto(ctx, id)
  local ahora = Cr.Demanda(ctx, 4, 225)
  local antes = Cr.Demanda(ctx, 4, 225, false, ctx.craftsGuia[4])
  return math.ceil((ahora[id] or 0) - 0.001), math.ceil((antes[id] or 0) - 0.001)
end

-- Llega a 300 sin huecos ni recetas en gris.
local function llega(def, n)
  local t = Ru.OficiosDatos.TRAMOS[n]
  local x = t[1]
  for _, s in ipairs(def.steps) do
    if s.section == n then
      for _, g in ipairs(s.goals) do
        if g.t == "craft" and g.untilSkill then
          check(Cr.Prob(g, x) > 0, "una receta empieza en gris en " .. x .. ": " .. tostring(s.title))
          x = math.max(x, g.untilSkill)
        end
      end
    end
  end
  return x
end

---------------------------------------------------------------------------
-- 8. El recetario del juego
---------------------------------------------------------------------------
-- La ventana de Sastrería de Forever con 230 de habilidad: las tres recetas
-- de la guía (rollo, cinturón y guantes de tela rúnica) y dos que la guía del
-- motor no trae: un «Bolso de tela rúnica» aprendido (naranja; 1 rollo y un
-- hilo, gris en 300) y una receta sin aprender (no compite: no la sabes).
local RECETAS = {
  [18401] = { name = "Bolt of Runecloth", learned = true, dif = 0, trivial = 255, out = ROLLO, r = { { RUNICA, 4 } } },
  [18402] = { name = "Runecloth Belt", learned = true, dif = 0, trivial = 255, out = 13856, r = { { ROLLO, 3 }, { HILO, 1 } } },
  [18417] = { name = "Runecloth Gloves", learned = true, dif = 0, trivial = 275, out = 13863, r = { { ROLLO, 4 }, { 8170, 4 }, { HILO, 1 } } },
  [90001] = { name = "Runecloth Pouch", learned = true, dif = 0, trivial = 300, out = 90002, r = { { ROLLO, 1 }, { HILO, 1 } } },
  [90003] = { name = "Runecloth Shoulders", learned = false, dif = nil, trivial = 300, out = 90004, r = { { ROLLO, 1 } } },
}
local habJuego = 230
local function ventana(recetas, prof)
  return {
    GetRecipeInfo = function(id)
      local r = recetas[id]
      if not r then return nil end
      return { name = r.name, learned = r.learned, relativeDifficulty = r.learned and r.dif or nil, maxTrivialLevel = r.trivial, recipeID = id }
    end,
    GetRecipeSchematic = function(id)
      local r = recetas[id]
      if not r then return nil end
      local slots = {}
      for _, x in ipairs(r.r) do slots[#slots + 1] = { reagentType = 1, quantityRequired = x[2], reagents = { { itemID = x[1] } } } end
      return { outputItemID = r.out, quantityMin = 1, quantityMax = 1, reagentSlotSchematics = slots, name = r.name }
    end,
    GetBaseProfessionInfo = function() return { professionName = "Sastrería", profession = 7, professionID = prof or SASTRERIA, skillLevel = habJuego } end,
    GetAllRecipeIDs = function() local t = {} for id in pairs(recetas) do t[#t + 1] = id end table.sort(t) return t end,
    IsTradeSkillReady = function() return true end,
  }
end

local tsReal = C_TradeSkillUI
local antes8, ctxAntes
step("8. sin datos del juego: la guía de Sastrería 225–300 queda como en la 1.3.9", function()
  HAB[SASTRERIA] = { habJuego, 300 }
  check(Of.RecetasJuego(SASTRERIA) == nil, "ya había recetario antes de abrir el oficio")
  local def, ctx = Of.Armar(SASTRERIA)
  check(def ~= nil, "no se armó Sastrería")
  if not def then return end
  ctxAntes = ctx
  local ahora, clasica = cuanto(ctx, RUNICA)
  antes8 = ahora
  print(("Sastrería 225-300 sin recetario: %d telas rúnicas (clásica %d)"):format(ahora, clasica))
  check(ahora > 2500, "la guía sin recetario ya no pide las telas de siempre: " .. ahora)
  check((ctx.deJuego or 0) == 0, "sumó recetas del juego sin recetario")
end)

step("8. al abrir el oficio se guarda el recetario de la cuenta", function()
  C_TradeSkillUI = ventana(RECETAS)
  FIRE_EVENT("TRADE_SKILL_SHOW")
  T(2) mover() T(1) mover()
  FIRE_EVENT("TRADE_SKILL_CLOSE")
  local cat = N.Datos("comercio").catalogo
  local s = cat and cat[SASTRERIA]
  check(type(s) == "table", "no hay recetario de Sastrería")
  if not s then return end
  local n = 0
  for _ in pairs(s) do n = n + 1 end
  check(n == 5, "el recetario no tiene las 5 recetas (aprendidas y no): " .. n)
  check(s[90003] and s[90003].g == 300, "la receta sin aprender no guardó su gris")
  check(s[90001] and s[90001].yLo == habJuego + 1, "el naranja con 230 no acotó el amarillo: " .. tostring(s[90001] and s[90001].yLo))
  local lista = Of.RecetasJuego(SASTRERIA)
  check(type(lista) == "table" and #lista == 5, "Of.RecetasJuego no ve el recetario")
  for _, r in ipairs(lista or {}) do
    if r.spell == 90001 then
      check(r.sabe == true and r.desde == habJuego, "el bolso no sale como sabido desde 230")
      check(r.yellow and r.yellow > habJuego and r.grey == 300, "colores del bolso: " .. tostring(r.yellow) .. "/" .. tostring(r.grey))
    elseif r.spell == 90003 then
      check(not r.sabe, "la receta sin aprender sale como sabida")
    end
  end
end)

step("8. los colores acotan: amarillo y verde vistos", function()
  local e = { g = 300 }
  Co.AnotarColor(e, 0, 250)
  local y = Co.Colores(e)
  check(y == 270, "sin más datos, 30 antes del gris (y dentro de lo visto): " .. tostring(y))
  Co.AnotarColor(e, 1, 262)
  y = Co.Colores(e)
  check(y and y > 250 and y <= 262, "visto amarillo en 262: el amarillo empieza a más tardar ahí: " .. tostring(y))
  Co.AnotarColor(e, 2, 280)
  local y2 = Co.Colores(e)
  check(y2 and y2 <= 262 and y2 >= 251, "verde en 280 con gris 300: amarillo entre 251 y 262: " .. tostring(y2))
  check(Co.Colores({}) == nil, "sin gris no hay colores")
  -- Un secreto del juego no se lee.
  local e2 = { g = 300 }
  Co.AnotarColor(e2, SECRETO(0), 240)
  check(e2.yLo == nil, "un color secreto se leyó")
end)

step("8. con el recetario, Sastrería 225–300 baja de costo y llega a 300", function()
  local def, ctx = Of.Armar(SASTRERIA)
  check(def ~= nil, "no se armó Sastrería con recetario")
  if not def then return end
  check((ctx.deJuego or 0) >= 1, "no sumó recetas del juego")
  local ahora, clasica = cuanto(ctx, RUNICA)
  local co = ctx.costos and ctx.costos[4] or {}
  print(("Sastrería 225-300 con recetario: %d telas rúnicas (antes %d, clásica %d); costo %s -> %s (%s)"):format(ahora, antes8 or -1, clasica,
    tostring(co.antes and math.floor(co.antes)), tostring(co.ahora and math.floor(co.ahora)), tostring(co.modo)))
  check(ctx.optimizado and ctx.optimizado[4], "el tramo 225–300 no se abarató")
  check(antes8 and ahora < antes8 * 0.7, ("no bajó lo suficiente: %d de %d"):format(ahora, antes8 or 0))
  check(llega(def, 4) == 300, "la guía ya no llega a 300")
  local bolso, sinSaber = false, false
  for _, s in ipairs(def.steps) do
    for _, g in ipairs(s.goals) do
      if g.t == "craft" and g.spell == 90001 and g.untilSkill then
        bolso = true
        check(s.note and s.note:find("Ya la sabes", 1, true), "el paso del bolso no dice que ya la sabes")
        check(g.juego == nil and g.rinde == nil, "la meta del motor lleva campos de Alfa")
      end
      if g.t == "craft" and g.spell == 90003 then sinSaber = true end
    end
    if s.section == 4 then print("  ", s.title) end
  end
  check(bolso, "el bolso que ya sabes no entró al plan")
  check(not sinSaber, "entró una receta que no sabes y la guía no enseña")
end)

step("8. con precios de subasta: la del juego sin precio no compite", function()
  -- Una receta sabida de 1 «Polvo raro» (sin precio) que sería la más barata.
  local d = N.Datos("comercio")
  d.catalogo[SASTRERIA][90005] = { o = 90007, q = 1, r = { 90006, 1 }, g = 300, yLo = 231, n = "Cheap Thing" }
  local ficha = d.recetas[Co.ClavePersonaje()]
  ficha.r[90005] = { n = "Cheap Thing", o = 90007, q = 1, r = { 90006, 1 }, p = "Sastrería", d = 0, s = 230, s0 = 230 }
  local real = AlfaComercio.PrecioSubasta
  AlfaComercio.PrecioSubasta = function(id) if id == 90006 then return nil end return id == RUNICA and 2500 or 150 end
  local def, ctx = Of.Armar(SASTRERIA)
  check(def ~= nil and ctx.costoModo == "precio", "sin modo precio: " .. tostring(ctx and ctx.costoModo))
  if def then
    check(llega(def, 4) == 300, "con precios ya no llega a 300")
    local co = ctx.costos[4]
    check(co.ahora <= co.antes, "con precios el plan cuesta más que la guía clásica")
    for _, s in ipairs(def.steps) do
      for _, g in ipairs(s.goals) do check(not (g.t == "craft" and g.spell == 90005), "entró la receta sin precio") end
    end
  end
  -- Sin precios (modo peso), la misma sí compite.
  AlfaComercio.PrecioSubasta = function() return nil end
  local def2, ctx2 = Of.Armar(SASTRERIA)
  local esta = false
  for _, s in ipairs(def2 and def2.steps or {}) do
    for _, g in ipairs(s.goals) do if g.t == "craft" and g.spell == 90005 then esta = true end end
  end
  check(ctx2 and ctx2.costoModo == "peso" and esta, "en modo peso la receta barata del juego no compite")
  AlfaComercio.PrecioSubasta = real
  d.catalogo[SASTRERIA][90005], ficha.r[90005] = nil, nil
end)

step("8. los demás oficios siguen armándose con un recetario ajeno", function()
  -- Un recetario de Herrería con una receta rara (sin reactivos, gris 0): no rompe nada.
  N.Datos("comercio").catalogo[164] = { [5] = { o = 1, r = {}, g = 0 }, [6] = { o = 2, r = { 2840, 1 } } }
  for _, linea in ipairs({ 164, 171, 197, 165, 202, 333, 185, 129 }) do
    HAB[linea] = { 1, 75 }
    local def, ctx = Of.Armar(linea)
    check(def ~= nil, "no se armó " .. linea)
    if def then
      for n = 1, 4 do
        local x = llega(def, n)
        check(x == Ru.OficiosDatos.TRAMOS[n][2] or not ctx.optimizado[n], ("%d: el tramo %d llega a %d"):format(linea, n, x))
      end
    end
  end
  HAB[SASTRERIA] = { habJuego, 300 }
end)
C_TradeSkillUI = tsReal

---------------------------------------------------------------------------
-- 73. La ruta de recolección de verdad: el caso de Toxic (Alianza, nivel 33,
-- en Los Humedales, «Junta 20 de Mena de estaño»).
---------------------------------------------------------------------------
local Rc = NS_OF("Alfa_Recoleccion")
local Ll, Ruta, Ju = Rc.Llevar, Rc.Ruta, Rc.Junta
local Cm = A.Compat
local real = { mw = Cm.MapToWorld, pmp = Cm.GetPlayerMapPosition, zona = Cm.GetUnitZone, pi = Cm.GetPlayerInfo,
  gg = A.Engine.GetGuide, gw = A.Engine.GetWaypoint, pos = Rc.R.PosicionJugador }
-- Las medidas reales del mundo (las del motor, TravelData) y tú en Los Humedales.
Cm.MapToWorld = function(m, x, y) return real.mw(m, x, y, "e") end
local yo = { 1437, 52, 48 }
Cm.GetPlayerMapPosition = function() return yo[1], yo[2], yo[3] end
Cm.GetUnitZone = function() return yo[1] end
Cm.GetPlayerInfo = function() local p = real.pi and real.pi() or {} p.level, p.faction = 33, "Alliance" return p end
local ESTANO = 2771
local HUMEDALES = 1437

local function aStop(r, k)
  local c, px, py = Cm.GetPlayerWorldPosition()
  local dx, dy = r.wx[k] - px, r.wy[k] - py
  return math.sqrt(dx * dx + dy * dy)
end

local antes73
step("73. antes: la zona de más puntos aunque esté lejos", function()
  local pd = Ll.Pedido(ESTANO)
  -- Sin tu posición se elige como en la 1.3.9.
  Rc.R.PosicionJugador = function() return HUMEDALES end
  local z = Ll.Zonas({ claves = pd.claves, anfitriones = pd.anfitriones, nivel = 33, faccion = "A" })[1]
  Rc.R.PosicionJugador = real.pos
  local c, px, py = Cm.GetPlayerWorldPosition()
  antes73 = z and Ll.Distancia(pd.claves, z.mapa, c, px, py)
  print(("73 antes: %s, la veta más cercana a %s yd"):format(z and Ll.NombreZona(z.mapa) or "?", tostring(antes73 and math.floor(antes73))))
  check(z and z.mapa ~= HUMEDALES, "la prueba ya no reproduce el caso de Toxic (antes elegía otra zona)")
end)

step("73. ahora: tu zona de tu nivel, la veta más cercana y un circuito corto", function()
  local pd = Ll.Pedido(ESTANO)
  local zs = Ll.Zonas({ claves = pd.claves, anfitriones = pd.anfitriones, nivel = 33, faccion = "A" })
  local z = zs[1]
  check(z and z.mapa == HUMEDALES, "no eligió Los Humedales: " .. tostring(z and Ll.NombreZona(z.mapa)))
  for i = 1, math.min(4, #zs) do print("   ", Ll.NombreZona(zs[i].mapa), zs[i].puntos, zs[i].distancia and math.floor(zs[i].distancia), math.floor(zs[i].puntaje)) end
  local ok = Ll.Llevar(ESTANO, { cuenta = 20, nivel = 33, faccion = "A", silencio = true })
  check(ok, "no armó la ruta")
  for _ = 1, 200 do if not Ruta.Calculando() then break end RUN_TIMERS(0.05) FIRE(UIParent, "OnUpdate", 0.05) end
  T(1)
  local r = Ruta.Actual()
  check(r and r.mapa == HUMEDALES and r.guiando, "la ruta no está en Los Humedales guiando")
  if not r then return end
  local primera = aStop(r, r.siguiente)
  local cerca = math.huge
  for k = 1, r.n do cerca = math.min(cerca, aStop(r, k)) end
  print(("73 ahora: Los Humedales, %d paradas de %d, la flecha a %d yd (antes %s yd); vuelta de %d yd"):format(r.n, r.total or 0,
    math.floor(primera), tostring(antes73 and math.floor(antes73)), math.floor(r.largo)))
  check(r.n <= 30 and r.n >= 10, "el circuito no es corto: " .. r.n)
  check(math.abs(primera - cerca) < 1, "la flecha no empieza en la parada más cercana")
  check(antes73 and primera < antes73 / 2, "la flecha no quedó mucho más cerca que antes")
  check(primera < 600, "la primera parada sigue lejos: " .. math.floor(primera))
  Ruta.Borrar()
end)

step("73. un paso «Junta 20 de Mena de estaño» del motor usa la ruta corta", function()
  -- La guía del motor apunta a un lugar lejano (a ~2,000 yardas, como en el juego).
  local paso = { title = "Junta 20 de Mena de estaño", goals = { { t = "collect", item = ESTANO, count = 20, map = 1433, x = 50, y = 50 } } }
  local guia = { id = "prueba/estano", steps = { paso } }
  A.Engine.GetGuide = function() return guia end
  A.Engine.GetWaypoint = function() return { kind = "collect", stepIndex = 1, goalIndex = 1, map = 1433, x = 50, y = 50 } end
  Ju.Olvidar()
  A.Fire("WAYPOINT_CHANGED")
  T(1)
  for _ = 1, 200 do if not Ruta.Calculando() then break end RUN_TIMERS(0.05) FIRE(UIParent, "OnUpdate", 0.05) end
  T(1)
  local r = Ruta.Actual()
  check(r and r.guiando and r.mapa == HUMEDALES and r.deGuia, "el paso de juntar no armó la ruta corta en tu zona")
  check(Ju.ultima and Ju.ultima.n and Ju.ultima.n <= 30, "no anotó la ruta del paso")
  if r then
    local d = aStop(r, r.siguiente)
    print(("73 paso de guía: la flecha a %d yd (la guía apuntaba a otra zona)"):format(math.floor(d)))
    check(d < 600, "la flecha del paso sigue lejos")
    local tgt = A.Nav.GetTarget()
    check(tgt and tgt.map == HUMEDALES, "la flecha no apunta a la ruta")
  end
  -- Otra vez el mismo paso: no la rehace.
  local antes = Ruta.Actual()
  A.Fire("WAYPOINT_CHANGED") T(1)
  check(Ruta.Actual() == antes, "rehízo la ruta del mismo paso")
  -- Apagado: no toca la flecha.
  Ruta.Borrar()
  N.Set("recoleccion", "juntaRuta", false)
  Ju.Olvidar()
  A.Fire("WAYPOINT_CHANGED") T(1)
  check(Ruta.Actual() == nil, "con el ajuste apagado igual armó la ruta")
  N.Set("recoleccion", "juntaRuta", true)
  -- Una meta que no es de un nodo (lana de un bicho) no se toca.
  paso.goals[1].item = 2592
  Ju.Olvidar()
  A.Fire("WAYPOINT_CHANGED") T(1)
  check(Ruta.Actual() == nil, "armó ruta para algo que no se recolecta")
  A.Engine.GetGuide, A.Engine.GetWaypoint = real.gg, real.gw
end)
Cm.MapToWorld, Cm.GetPlayerMapPosition, Cm.GetUnitZone, Cm.GetPlayerInfo = real.mw, real.pmp, real.zona, real.pi
Ruta.Borrar()

-- Los avisos del Kit, anotados.
local K = N.Kit
local avisoReal = K.Aviso
local avisos = {}
K.Aviso = function(o) avisos[#avisos + 1] = o return avisoReal(o) end
local function avisoCon(id) for i = #avisos, 1, -1 do if avisos[i].id == id then return avisos[i] end end end

---------------------------------------------------------------------------
-- 31. «Comprar lo que falta» en el paso de materiales
---------------------------------------------------------------------------
local Oc = Ru.OficiosComprar
local TORIO = 12359
step("31. el paso de materiales ofrece comprar lo que falta y arma la lista", function()
  HAB[164] = { 230, 300 }
  local ok = Of.Instalar(164)
  check(ok, "no se instaló Herrería")
  local id = Of.Id(164)
  local cual
  local g = Of.comprar and Of.comprar[id]
  for i in pairs(g and g.pasos or {}) do if not cual or i > cual then cual = i end end
  check(cual ~= nil, "ningún paso de materiales tiene algo que comprar")
  if not cual then return end
  local def = A.Guides.Get(id)
  check(def.steps[cual].title:find("Tus materiales", 1, true), "el paso de comprar no es el de materiales: " .. tostring(def.steps[cual].title))
  local linea, lista = Oc.Faltan(id, cual)
  check(linea == 164 and #lista > 0, "Oc.Faltan no da lo que falta")
  local hayTorio = false
  for _, x in ipairs(lista or {}) do if x.id == TORIO then hayTorio = true end end
  check(hayTorio, "el torio del tramo 225–300 no está para comprar")
  -- La sugerencia del rastreador.
  local gg = A.Engine.GetGuide
  A.Engine.GetGuide = function() return { id = id } end
  local d = Oc.Aviso({ index = cual }, cual)
  check(d and d.uno and d.uno[1] == "Comprar lo que falta" and d.clave, "sin sugerencia «Comprar lo que falta»")
  check(Oc.Aviso({ index = cual }, cual + 1) == nil, "sugiere comprar mirando otro paso")
  A.Engine.GetGuide = gg
  avisos = {}
  if d then d.uno[2]() end
  local meta
  for _, m in ipairs(AlfaComercio.Lista.Metas()) do if m.oficio == 164 and m.guia then meta = m end end
  check(meta and #meta.r >= 2, "no quedó la meta de Herrería en la lista")
  local a = avisos[#avisos]
  check(a and a.titulo == "Lista de compras", "no avisó que lo puso en la lista")
  Of.comprar[id] = nil
  check(Oc.Faltan(id, cual) == nil, "sin datos del paso igual da algo")
end)

---------------------------------------------------------------------------
-- 46. Lo de tu lista, barato en la subasta
---------------------------------------------------------------------------
step("46. un material de tu lista barato en la subasta: un aviso, una vez", function()
  local abierta = Co.SubastaAbierta
  Co.SubastaAbierta = function() return true end
  FIRE_EVENT("AUCTION_HOUSE_SHOW")
  T(1)
  Co.OlvidarBuscados()
  check(Co.Buscados()[TORIO], "el torio de la lista no sale como buscado")
  avisos = {}
  Co.Anotar(TORIO, 2000, 20, 2)    -- lo que suele valer (el último precio conocido)
  Co.Anotar(TORIO, 1900, 20, 2)    -- 5 % menos: nada
  T(3)
  check(avisoCon("comercio.buscados") == nil, "avisó por un 5 % menos")
  Co.Anotar(TORIO, 1500, 20, 2)    -- 25 % menos: sí
  Co.Anotar(2840, 5, 20, 2)        -- algo que no está en tu lista: no
  T(3)
  local a = avisoCon("comercio.buscados")
  check(a and a.texto:find("te faltan", 1, true) and a.texto:find("Alfa no compra", 1, true), "no avisó del torio barato: " .. tostring(a and a.texto))
  local n = #avisos
  Co.Anotar(TORIO, 1000, 20, 2)
  T(3)
  check(#avisos == n, "volvió a avisar del mismo objeto en la misma visita")
  N.Set("comercio", "buscadosAviso", false)
  FIRE_EVENT("AUCTION_HOUSE_SHOW") T(1)
  Co.Anotar(TORIO, 2000, 20, 2) Co.Anotar(TORIO, 1000, 20, 2) T(3)
  check(#avisos == n, "con el ajuste apagado igual avisó")
  N.Set("comercio", "buscadosAviso", true)
  FIRE_EVENT("AUCTION_HOUSE_CLOSED")
  Co.SubastaAbierta = abierta
end)

---------------------------------------------------------------------------
-- 47. Tu semana en la subasta
---------------------------------------------------------------------------
step("47. las cartas de la subasta: ventas, compras y la semana", function()
  local cartas = {
    [1] = { "seller", "Barra de torio", "Comprador", 50000, 50000, 1000, 2500, 0, 0, 0, 20 },
    [2] = { "buyer", "Mena de torio", "Vendedor", 30000, 30000, 0, 0, 0, 0, 0, 10 },
    [3] = { "seller_temp_invoice", "Algo", "X", 100, 100, 0, 0, 0, 0, 0, 1 },
  }
  GetInboxInvoiceInfo = function(i) local c = cartas[i] if c then return unpack(c) end end
  FIRE_EVENT("MAIL_SHOW")
  Co.RevisarCarta(1) Co.RevisarCarta(1) Co.RevisarCarta(2) Co.RevisarCarta(3) Co.RevisarCarta(9)
  local s = Co.Semana(7)
  check(s.ventas == 1 and s.vendido == 47500, "la venta (menos la comisión): " .. tostring(s.vendido))
  check(s.compras == 1 and s.comprado == 30000, "la compra: " .. tostring(s.comprado))
  check(s.neto == 17500 and #s.lista == 2, "el neto o la lista: " .. tostring(s.neto))
  for _, m in ipairs(N.DatosPersonaje("comercio").semana) do
    check(m.n ~= "Comprador" and m.n ~= "Vendedor", "guardó el nombre de otro jugador")
    for k, v in pairs(m) do check(v ~= "Comprador" and v ~= "Vendedor", "guardó el nombre de otro jugador en " .. k) end
  end
  -- Lo de hace más de una semana no cuenta.
  table.insert(N.DatosPersonaje("comercio").semana, 1, { t = Co.Ahora() - 9 * 86400, k = "v", n = "Viejo", q = 1, c = 99999 })
  check(Co.Semana(7).vendido == 47500, "contó una venta de hace 9 días")
  GetInboxInvoiceInfo = nil
  -- La página de Comercio con su bloque.
  N.Abrir("comercio")
  T(2)
  local F = A.UI and A.UI.Options and A.UI.Options.frame
  if F then SNAP("comercio-semana", F) end
end)

---------------------------------------------------------------------------
-- 48. Recolección: el oro de la sesión
---------------------------------------------------------------------------
step("48. la sesión de recolección dice su oro estimado y por hora", function()
  local R = Rc.R
  R.BorrarHistorial()
  local s = R.Sesion()
  s.inicio = time() - 1800
  s.total = 12
  R.AnotarBotin({ [2771] = 20, [2836] = 4 })
  local real = AlfaComercio.PrecioSubasta
  AlfaComercio.PrecioSubasta = function(id) return id == 2771 and 300 or nil end
  local v = R.ValorSesion(R.Sesion())
  check(v >= 6000, "el oro de la sesión: " .. tostring(v))
  N.Abrir("recoleccion")
  T(2)
  local F = A.UI and A.UI.Options and A.UI.Options.frame
  local hay = false
  local function buscar(f)
    for _, r in ipairs({ f:GetRegions() }) do
      if r.GetText and type(r:GetText()) == "string" and r:GetText():find("Oro estimado", 1, true) then hay = true end
    end
    for _, h in ipairs({ f:GetChildren() }) do buscar(h) end
  end
  if F then buscar(F) SNAP("recoleccion-oro", F) end
  check(hay, "la página no enseña el oro estimado")
  AlfaComercio.PrecioSubasta = real
end)

---------------------------------------------------------------------------
-- 49 y 50. Pesca: la meta del día y el cebo
---------------------------------------------------------------------------
local Pe = NS_OF("Alfa_Pesca")
local Md = Pe.MetaDia
step("49. la meta del día: cuenta, se cumple una vez y Lya la festeja", function()
  HAB[356] = { 150, 225 }
  local habReal = Pe.Habilidad
  Pe.Habilidad = function() return 150, 225 end
  N.DatosPersonaje("pesca").metaDia = nil
  local m = Md.Hoy()
  check(m and m.dia and m.objetivo > 0, "no hay meta del día")
  -- Forzar «peces nuevos» para probar el caso de Toxic.
  m.tipo, m.objetivo, m.hecho, m.cumplida = "nuevos", 3, 0, nil
  check(Md.Texto(m) == "Pesca 3 peces que nunca has sacado", "el texto: " .. tostring(Md.Texto(m)))
  local Lya = rawget(_G, "AlfaLya")
  local dichos, fest = {}, {}
  local decir, festejar = Lya and Lya.Decir, Lya and Lya.Festejar
  if Lya then
    Lya.Decir = function(t, o) dichos[#dichos + 1] = { t, o } return true end
    Lya.Festejar = function(...) fest[#fest + 1] = { ... } return true end
  end
  local diario = Pe.Diario()
  local function sacar(id, nombre)
    Pe.R.Captura({ { id = id, nombre = nombre, cantidad = 1, calidad = 1 } }, {})
  end
  sacar(6291, "Pez A") sacar(6291, "Pez A") -- el segundo ya no es nuevo
  check(Md.Hoy().hecho == 1, "contó un pez repetido como nuevo: " .. tostring(Md.Hoy().hecho))
  sacar(6303, "Pez B") sacar(6289, "Pez C")
  check(Md.Hoy().cumplida, "no se cumplió con 3 peces nuevos")
  check(#dichos == 1 and dichos[1][1]:find("salchicha", 1, true) and dichos[1][2].aullar, "Lya no la festejó (aullando)")
  check(#fest == 1, "no quedó en tu historia")
  sacar(6317, "Pez D")
  check(#dichos == 1, "la festejó dos veces")
  -- La ventanita de metas la pone primero.
  local Me = Pe.Metas
  Me.Alternar(true)
  T(1)
  local fila = Md.Fila()
  check(fila and fila.texto == "3 peces nuevos", "la fila corta: " .. tostring(fila and fila.texto))
  if Me.Marco() then SNAP("pesca-meta-dia", Me.Marco()) end
  Me.Alternar(false)
  -- Otro día, otra meta.
  N.DatosPersonaje("pesca").metaDia.dia = "2000-01-01"
  check(not Md.Hoy().cumplida, "el día nuevo empezó cumplido")
  N.Set("pesca", "metaDia", false)
  check(Md.Hoy() == nil and Md.Fila() == nil, "apagada sigue saliendo")
  N.Set("pesca", "metaDia", true)
  if Lya then Lya.Decir, Lya.Festejar = decir, festejar end
  Pe.Habilidad = habReal
end)

step("50. se acaba el cebo y te queda otro: el recordatorio con su botón seguro", function()
  local Eq = Pe.Eq
  local E = Pe.E
  local real = { mejor = Eq.MejorCebo, cuenta = Eq.Cuenta, modo = E.modo }
  Eq.MejorCebo = function() return { id = 6530, enlace = "|cffffffff|Hitem:6530|h[Nightcrawlers]|h|r", bono = 50 } end
  Eq.Cuenta = function() return 7 end
  E.modo = true
  avisos = {}
  Pe.CeboAcabado()
  local a = avisoCon("pesca.ceboOtra")
  check(a and a.texto:find("Nightcrawlers", 1, true) and a.texto:find("te quedan 7", 1, true), "sin recordatorio: " .. tostring(a and a.texto))
  check(a and a.accion and a.accion.seguro and a.accion.seguro.macrotext:find("item:6530", 1, true) and a.accion.seguro.macrotext:find("/use [nocombat] 16", 1, true),
    "el botón no es seguro o no pone el cebo")
  N.Set("pesca", "ceboRecordar", false)
  avisos = {}
  Pe.CeboAcabado()
  check(avisoCon("pesca.ceboOtra") == nil, "con el ajuste apagado igual recordó")
  N.Set("pesca", "ceboRecordar", true)
  Eq.MejorCebo, Eq.Cuenta, E.modo = real.mejor, real.cuenta, real.modo
end)

---------------------------------------------------------------------------
-- 51. La receta que pasa a verde
---------------------------------------------------------------------------
step("51. la receta que haces pasa a verde: un aviso y cuál sigue", function()
  Co.OlvidarVerdes()
  avisos = {}
  -- Con la ventana abierta: el color real, de amarillo a verde, de la receta que fabricaste.
  Co.AnotarFabricada(18402)
  Co.AlCambiarColores(SASTRERIA, { [18402] = 1, [18401] = 1 }, { [18402] = { n = "Runecloth Belt", d = 2, s = 245, o = 13856 }, [18401] = { n = "Bolt", d = 2, s = 245, o = ROLLO } })
  local a = avisoCon("comercio.verde.18402")
  check(a and a.texto:find("Runecloth Belt", 1, true) and a.texto:find("verde", 1, true), "sin aviso de verde: " .. tostring(a and a.texto))
  check(avisoCon("comercio.verde.18401") == nil, "avisó de una receta que no estás haciendo")
  local n = #avisos
  Co.AlCambiarColores(SASTRERIA, { [18402] = 1 }, { [18402] = { n = "Runecloth Belt", d = 2, s = 246 } })
  check(#avisos == n, "avisó dos veces de la misma receta")
  -- Con la ventana cerrada: por el recetario (amarillo 270, gris 300 -> verde desde 285).
  Co.AnotarFabricada(90001)
  HAB[SASTRERIA] = { 284, 300 }
  Co.RevisarVerdes()
  HAB[SASTRERIA] = { 285, 300 }
  Co.RevisarVerdes()
  check(avisoCon("comercio.verde.90001") ~= nil, "sin aviso por el recetario al llegar al verde")
  N.Set("comercio", "avisoVerde", false)
  Co.OlvidarVerdes()
  avisos = {}
  Co.AnotarFabricada(18402)
  Co.AlCambiarColores(SASTRERIA, { [18402] = 1 }, { [18402] = { n = "Runecloth Belt", d = 2, s = 245 } })
  check(#avisos == 0, "con el ajuste apagado igual avisó")
  N.Set("comercio", "avisoVerde", true)
  HAB[SASTRERIA] = { habJuego, 300 }
end)
K.Aviso = avisoReal

C_SkillInfo.GetSkillLineInfoByID = skillReal
print("PRUEBA: 1.4.0 oficios, " .. pasos .. " pasos, errores: " .. #ERRORS)
