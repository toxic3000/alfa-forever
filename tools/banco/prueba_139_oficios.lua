-- Prueba de la 1.3.9, oficios (tools/prueba.py la corre con las demás):
--   Guías de oficios de Alfa (pedido de Toxic: «están algo genéricas»):
--   * cada oficio arma su guía por tramos (1–75 ... 225–300), con la meta de
--     habilidad en cada paso y su salto por habilidad (`when`), en el paquete
--     alfa-oficios y en la categoría Profesiones de la Biblioteca (sin repetir
--     la del motor);
--   * Minería: la zona de cada tramo la elige Recolección por tu facción y tu
--     nivel, con una vuelta de varios lugares; el instructor de Oficial a 50;
--   * Herrería: recetas con su «hasta N», materiales del tramo con lo de tus
--     otros personajes descontado, sus metas de comprar/juntar;
--   * se arma al abrirla, no al entrar (al cargar solo hay fichas);
--   * el Asistente de profesiones pone tus oficios primero; Comercio > Oficios
--     tiene «Guíame paso a paso».
--   «Llévame» a un material (pedido de Toxic: «buscando plata me manda a un
--   lugar donde no hay»):
--   * plata -> la zona de tu facción y nivel con más vetas de plata y de
--     estaño (donde sale), dicho en una línea;
--   * una ruta de varios puntos; un punto vacío (llegas y no recolectas) se
--     salta solo y lo dice; el clic en la flecha pasa al siguiente;
--   * «plata», «mena de plata», «silver» y «Silver Ore» son lo mismo.
SNAPSHOTS = {}
local CAPTURAS = os and os.getenv and os.getenv("BANCO_CAPTURAS")
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["139-oficios-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.3.9 oficios", msg) end end
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
local Rc = NS_OF("Alfa_Recoleccion")
local Of = Ru.OficiosGuia
local Gd = A.Guides
local E = A.Engine

-- El mundo: cada mapa es un cuadro de 4000 x 4000 yardas en su propio continente.
local mundoReal = A.Compat.MapToWorld
A.Compat.MapToWorld = function(mapa, x, y, f)
  if type(mapa) ~= "number" then return nil end
  return mapa, (y or 0) * 40, (x or 0) * 40
end
local yo = { 1413, 0, 0 }
local posReal = A.Compat.GetPlayerWorldPosition
A.Compat.GetPlayerWorldPosition = function() return yo[1], yo[2], yo[3] end

local function contar(def, t)
  local n = 0
  for _, s in ipairs(def.steps) do for _, g in ipairs(s.goals) do if g.t == t then n = n + 1 end end end
  return n
end
local function pasoCon(def, fn) for i, s in ipairs(def.steps) do if fn(s) then return s, i end end end

---------------------------------------------------------------------------
step("al cargar solo hay fichas (nada armado)", function()
  check(type(Of) == "table", "falta OficiosGuia")
  for _, linea in ipairs(Ru.OficiosDatos.ORDEN) do
    local g = Gd.Get(Of.Id(linea))
    check(g ~= nil, "falta la ficha de " .. linea)
    local h = g and rawget(g, "steps")
    check(type(h) == "table" and #h == 1, "la ficha de " .. linea .. " no es corta: " .. tostring(h and #h))
    check(g and g.category == "Professions", "la ficha no está en Profesiones")
  end
end)

---------------------------------------------------------------------------
local defMin
step("Minería: tramos, zonas de Recolección, vuelta, instructor y saltos", function()
  HAB[186] = { 1, 75 }
  local def, ctx = Of.Armar(186)
  check(def ~= nil, "Minería no se armó: " .. tostring(ctx))
  if not def then return end
  defMin = def
  check(#def.sections == 4 and def.sections[2].from == 75 and def.sections[4].to == 300, "sin los cuatro tramos")
  local n = 0
  for _, s in ipairs(def.steps) do
    local gotos = 0
    local meta
    for _, g in ipairs(s.goals) do
      if g.t == "goto" then gotos = gotos + 1 end
      if g.t == "skill" then meta = g.level end
    end
    if gotos > 0 then
      n = n + 1
      check(gotos >= 3, "una vuelta con menos de 3 lugares: " .. tostring(s.title))
      check(meta ~= nil, "un paso de recolección sin meta de habilidad: " .. tostring(s.title))
      check(s.when and s.when[1].k == "skill" and s.when[1].neg and s.when[1].n == meta, "un paso no se salta por habilidad: " .. tostring(s.title))
      for _, g in ipairs(s.goals) do
        if g.t == "goto" then
          local f = Rc.Llevar.ZONAS[g.map]
          check(f == "H" or f == "C", "Minería manda a un orco a una zona de la Alianza: " .. tostring(g.map))
        end
      end
    end
  end
  check(n >= 6, "pocos pasos de recolección: " .. n)
  -- El instructor de Oficial va a 50, antes del paso que empieza en 50.
  local _, iOf = pasoCon(def, function(s) for _, g in ipairs(s.goals) do if g.t == "train" and g.rank == 2 then return true end end end)
  check(iOf ~= nil, "sin el paso de Oficial")
  local s1 = def.steps[1]
  local tieneTren, tienePico = false, false
  for _, g in ipairs(s1.goals) do
    if g.t == "train" and g.rank == 1 then tieneTren = true end
    if g.t == "buy" and g.item == 2901 then tienePico = true end
  end
  check(tieneTren and tienePico, "el primer paso no tiene instructor y pico")
  check(def.names["skill:186"] == "Mining", "sin el nombre del token de Minería")
  -- Lo registra y lo abre: los pasos pasados se saltan.
  check(Of.Abrir(186), "no se abrió la guía de Minería")
  T(3)
  local g = E.GetGuide and E.GetGuide()
  check(g and g.id == Of.Id(186), "la guía abierta no es la de Minería: " .. tostring(g and g.id))
  -- Con 130 de habilidad, el paso actual ya no es de los primeros tramos.
  HAB[186] = { 130, 225 }
  A.Fire("SKILL_LINES_CHANGED")
  FIRE_EVENT("SKILL_LINES_CHANGED")
  T(3)
  local i = E.GetStepIndex and E.GetStepIndex()
  local s = i and g.steps[i]
  local cerca = s and s.when and s.when[1] and s.when[1].n
  check(s and (s.section or 0) >= 2, "con 130 la guía sigue en el tramo " .. tostring(s and s.section) .. " (" .. tostring(s and s.title) .. ")")
  check(not cerca or cerca > 130, "el paso actual ya lo pasaste: " .. tostring(cerca))
  local F = rawget(_G, "AlfaRastreador")
  if F then F:Show() T(2) SNAP("mineria", F) end
  print("Minería:", #def.steps, "pasos; actual:", tostring(s and s.title))
end)

---------------------------------------------------------------------------
step("Herrería: recetas por tramo, materiales con tus otros personajes descontados", function()
  HAB[164] = { 40, 75 }
  -- Copper Bar (2840) y Rough Stone (2835): 30 aquí y 50 en «Lobita».
  local bolsasReal = AlfaBolsas and AlfaBolsas.Cuantos
  local quienReal = AlfaBolsas and AlfaBolsas.QuienTiene
  AlfaBolsas = AlfaBolsas or {}
  AlfaBolsas.Cuantos = function(id) if id == 2835 then return 30, 30, 0, 80 end return 0, 0, 0, 0 end
  AlfaBolsas.QuienTiene = function(id)
    if id == 2835 then return { { nombre = "Lobita", bolsas = 50, banco = 0 } } end
    return {}
  end
  local def = Of.Armar(164)
  AlfaBolsas.Cuantos, AlfaBolsas.QuienTiene = bolsasReal, quienReal
  check(def ~= nil, "Herrería no se armó")
  if not def then return end
  local crafts = contar(def, "craft")
  check(crafts >= 8, "pocas recetas: " .. crafts)
  local mat = pasoCon(def, function(s) return s.title:find("75", 1, true) and s.note and s.note:find("Lobita", 1, true) end)
  check(mat ~= nil, "el paso de materiales del primer tramo no dice lo de Lobita")
  if mat then
    check(mat.note:find("{item:2835}", 1, true) ~= nil, "materiales sin la piedra basta")
    for _, g in ipairs(mat.goals) do
      if g.item == 2835 then
        check(g.count and g.count < 200, "la meta de piedra no descuenta a Lobita: " .. tostring(g.count))
      end
    end
    print("Materiales 1-75:", mat.note)
  end
  -- Cada receta «hasta N» se salta con N.
  for _, s in ipairs(def.steps) do
    for _, g in ipairs(s.goals) do
      if g.t == "craft" and g.untilSkill then
        check(s.when and s.when[1].n == g.untilSkill, "receta sin salto: " .. tostring(s.title))
      end
    end
  end
  -- Cada tramo termina con su meta.
  for n, t in ipairs(Ru.OficiosDatos.TRAMOS) do
    local fin = false
    for _, s in ipairs(def.steps) do
      if s.section == n then
        for _, g in ipairs(s.goals) do
          if (g.t == "skill" and g.level == t[2]) or (g.t == "craft" and g.untilSkill == t[2]) then fin = true end
        end
      end
    end
    check(fin, "el tramo " .. n .. " no termina en " .. t[2])
  end
  check(Of.Abrir(164), "no se abrió la guía de Herrería")
  T(3)
  local F = rawget(_G, "AlfaRastreador")
  if F then F:Show() T(2) SNAP("herreria", F) end
  print("Herrería:", #def.steps, "pasos,", crafts, "recetas")
end)

---------------------------------------------------------------------------
step("cada oficio arma su guía (y se registra)", function()
  for _, linea in ipairs(Ru.OficiosDatos.ORDEN) do
    HAB[linea] = HAB[linea] or { 1, 75 }
    local ok, motivo = Of.Instalar(linea)
    check(ok, "no se instaló " .. linea .. ": " .. tostring(motivo))
    local g = Gd.Get(Of.Id(linea))
    local st = g and rawget(g, "steps")
    check(type(st) == "table" and #st > 3, "la guía de " .. linea .. " quedó corta: " .. tostring(st and #st))
  end
end)

---------------------------------------------------------------------------
step("la Biblioteca y el Asistente", function()
  local Gm = Gd.Get("forever/professions/mining")
  check(Gm == nil or Of.Oculta(Gm), "la guía de Minería del motor no se esconde")
  check(not Of.Oculta(Gd.Get("forever/professions/fishing") or {}), "se escondió la de Pesca (no tiene reemplazo)")
  local mios = Of.Mios()
  check(#mios >= 2, "sin tus oficios")
  Ru.Asistente.Abrir("profesiones")
  T(2)
  local v = rawget(_G, "AlfaAsistente")
  if v then SNAP("asistente", v) end
end)

---------------------------------------------------------------------------
-- «Llévame» a la plata
---------------------------------------------------------------------------
local Ll = Rc.Llevar
step("búsqueda: plata, mena de plata, silver y Silver Ore son lo mismo", function()
  for _, t in ipairs({ "plata", "mena de plata", "Silver", "silver ore", "Filón de plata", "veta de plata" }) do
    check(Ll.Buscar(t) == "silver_vein", "«" .. t .. "» no es la plata: " .. tostring(Ll.Buscar(t)))
  end
  check(Ll.Buscar("cobre") == "copper_vein", "cobre")
  check(Ll.Buscar("hojaplata") == "silverleaf", "hojaplata no es la hierba")
  check(Ll.GruposDe(2775)[1] == "silver_vein", "la mena de plata no da su veta")
end)

step("plata: zona de tu facción y nivel con plata y estaño, ruta de varios puntos", function()
  local pd = Ll.Pedido(2775)
  check(pd and pd.anfitriones[1] == "tin_vein", "la plata no cuenta el estaño")
  local zonas = Ll.Zonas({ claves = pd.claves, anfitriones = pd.anfitriones, nivel = 23, faccion = "H" })
  local z = zonas[1]
  check(z ~= nil, "sin zona para la plata")
  if not z then return end
  check(Ll.ZONAS[z.mapa] ~= "A", "la plata manda a un horda a zona de la Alianza: " .. z.mapa)
  check(not z.min or z.min <= 23 + 6, "zona muy por encima del nivel 23: " .. tostring(z.min))
  check((z.anfitrion or 0) > 0, "la zona no tiene estaño contado")
  local motivo = Ll.Motivo(z, pd)
  check(motivo and motivo:find(tostring(z.puntos), 1, true), "el motivo no dice los puntos: " .. tostring(motivo))
  print("Plata:", motivo)
  -- Con nivel 10 no te manda a una zona de nivel 30.
  local z10 = Ll.Zonas({ claves = pd.claves, anfitriones = pd.anfitriones, nivel = 10, faccion = "H" })[1]
  check(z10 and (not z10.min or z10.min <= 16), "con nivel 10 la plata manda a una zona de nivel " .. tostring(z10 and z10.min))
  -- La ruta en esa zona: varios puntos y la flecha al más cercano.
  NS_OF("Alfa_Recoleccion").R.EsConocido = function() return true end
  yo[1] = z.mapa
  local ok = Ll.Llevar(2775, { nivel = 23, faccion = "H" })
  check(ok, "Llevar(plata) falló")
  for _ = 1, 50 do T(1) if not Rc.Ruta.Calculando() then break end end
  local r = Rc.Ruta.Actual()
  check(r and r.n >= 3, "la ruta de plata tiene menos de 3 puntos: " .. tostring(r and r.n))
  check(r and r.mapa == z.mapa, "la ruta no está en la zona elegida")
  check(r and r.guiando, "la ruta no guía")
end)

step("punto vacío: llegas, no recolectas y salta al siguiente (y lo dice)", function()
  local Ruta = Rc.Ruta
  local r = Ruta.Actual()
  if not (r and r.guiando) then return end
  local k = r.siguiente
  yo[1], yo[2], yo[3] = r.c, r.wx[k], r.wy[k]
  local dicho = {}
  local imp = N.Imprimir
  N.Imprimir = function(t) dicho[#dicho + 1] = tostring(t) end
  T(2)
  NOW = NOW + Ruta.ESPERA + 1
  T(2)
  N.Imprimir = imp
  check(r.siguiente ~= k, "el punto vacío no saltó al siguiente")
  check(Ruta.Vacia(k), "el punto no quedó vacío")
  local hay = false
  for _, t in ipairs(dicho) do if t:find("siguiente", 1, true) then hay = true end end
  check(hay, "no dijo que no hay nada y va al siguiente")
  -- Recolectar también lo marca y pasa al siguiente.
  local k2 = r.siguiente
  yo[2], yo[3] = r.wx[k2], r.wy[k2]
  Ruta.Recolectado(r.mapa, r.x[k2], r.y[k2])
  check(r.siguiente ~= k2 and Ruta.Vacia(k2), "recolectar no pasó al siguiente")
end)

step("clic en la flecha: la siguiente parada", function()
  local Ruta = Rc.Ruta
  local r = Ruta.Actual()
  if not (r and r.guiando) then return end
  local Nav = A.Nav
  check(Nav.OtroLugar == Ruta.Gancho, "la ruta no registró el gancho de la flecha")
  local k = r.siguiente
  local flecha = rawget(_G, "AlfaNavArrow")
  if flecha and flecha:GetScript("OnMouseUp") then
    FIRE(flecha, "OnMouseUp", "LeftButton")
  else
    Ruta.Gancho.ir()
  end
  T(1)
  check(r.siguiente ~= k, "el clic en la flecha no pasó a la siguiente parada")
  Ruta.Detener()
  check(Nav.OtroLugar ~= Ruta.Gancho, "al parar no soltó el gancho")
end)

---------------------------------------------------------------------------
-- Revisión 1.3.9 (pedido de Toxic): más rápido y más barato. Herrería
-- 225–300 pedía 1,943 barras de torio y Sastrería 3,195 telas rúnicas
-- (las recetas caras de la guía del motor hasta casi gris); ahora, en cada
-- punto, la receta de la guía que cuesta menos por punto mientras da puntos.
---------------------------------------------------------------------------
local Cr = Ru.OficiosCrear
local TORIO, RUNICA = 12359, 14047

-- Cuánto pide el tramo 4 de un material, con la guía armada y con la clásica.
local function cuanto(ctx, id)
  local ahora = Cr.Demanda(ctx, 4, 225)
  local antes = Cr.Demanda(ctx, 4, 225, false, ctx.craftsGuia[4])
  return math.ceil((ahora[id] or 0) - 0.001), math.ceil((antes[id] or 0) - 0.001)
end

-- Simula subir de 225 a 300 con las recetas del tramo (sus «hasta N»): cada
-- punto, la que toca; llega a 300 sin huecos ni recetas en gris.
local function llega(def, n)
  local t = Ru.OficiosDatos.TRAMOS[n]
  local x = t[1]
  for _, s in ipairs(def.steps) do
    if s.section == n then
      for _, g in ipairs(s.goals) do
        if g.t == "craft" and g.untilSkill then
          check(g.untilSkill > x or g.untilSkill == t[2], "una receta no sube nada: " .. tostring(s.title))
          check(Cr.Prob(g, x) > 0, "una receta empieza en gris en " .. x .. ": " .. tostring(s.title))
          x = math.max(x, g.untilSkill)
        end
      end
    end
  end
  return x
end

-- { oficio, material, nivel, ¿baja? }. Herrería: de nivel 50 las botas
-- imperiales (su misión pide nivel 50); antes, el hacha ornamentada hasta 293
-- y el hacha enorme al final, contra «el hacha enorme hasta 300» que la propia
-- guía dice sin las botas. Sastrería: las tres recetas de tela rúnica que trae
-- la guía ya son las más baratas por punto (de 260 a 300 no hay otra con
-- colores y reactivos conocidos): no baja, pero tampoco sube.
local nivelReal = UnitLevel
for _, caso in ipairs({ { 164, TORIO, 23, true }, { 164, TORIO, 55, true }, { 197, RUNICA, 23, false } }) do
  step(("más barato: %s 225–300 (nivel %d)"):format(caso[1] == 164 and "Herrería" or "Sastrería", caso[3]), function()
    UnitLevel = function() return caso[3] end
    HAB[caso[1]] = { 230, 300 }
    local def, ctx = Of.Armar(caso[1])
    UnitLevel = nivelReal
    check(def ~= nil, "no se armó la guía " .. caso[1])
    if not def then return end
    local ahora, antes = cuanto(ctx, caso[2])
    local co = ctx.costos and ctx.costos[4] or {}
    print(("%d 225-300 nivel %d: %d (antes %d); costo %s -> %s (%s)"):format(caso[1], caso[3], ahora, antes, tostring(co.antes), tostring(co.ahora), tostring(co.modo)))
    check(llega(def, 4) == 300, "la guía ya no llega a 300")
    if not caso[4] then
      check(antes > 0 and ahora <= antes, ("subió: %d de %d"):format(ahora, antes))
      check(co.ahora and co.antes and co.ahora <= co.antes, "el plan cuesta más que la guía clásica")
      return
    end
    check(ctx.optimizado and ctx.optimizado[4], "el tramo 225–300 no se abarató")
    check(antes > 0 and ahora < antes * 0.8, ("no bajó mucho: %d de %d"):format(ahora, antes))
    -- La cabecera de los materiales lo dice.
    local mat
    for _, s in ipairs(def.steps) do if s.section == 4 and s.title:find("225", 1, true) and s.note and s.note:find("guía clásica", 1, true) then mat = s end end
    check(mat ~= nil, "la cabecera del tramo no dice cuánto bajó")
    if mat then
      local linea = mat.note:match("^[^\n]+")
      check(linea:find("{item:" .. caso[2] .. "}", 1, true) and linea:find((tostring(antes):gsub("(%d)(%d%d%d)$", "%1,%2")), 1, true),
        "la cabecera no dice el material y lo de antes: " .. linea)
      print(linea)
    end
    -- Las recetas siguen con su salto por habilidad, y lo intermedio va antes.
    for _, s in ipairs(def.steps) do
      if s.section == 4 then
        local hasta
        for _, g in ipairs(s.goals) do if g.t == "craft" and g.untilSkill then hasta = g.untilSkill end end
        if hasta then check(s.when and s.when[1].n == hasta, "receta sin salto: " .. tostring(s.title)) end
        print("  ", s.title)
        if os.getenv("BANCO_NOTAS") then
          print("     ", s.note)
          for _, g in ipairs(s.goals) do print("       -", g.t, g.spell or g.item, g.count or g.untilSkill or g.level) end
        end
      end
    end
  end)
end

step("más barato: los demás tramos y oficios siguen armándose y llegando", function()
  for _, linea in ipairs({ 164, 171, 197, 165, 202, 333, 185, 129 }) do
    HAB[linea] = { 1, 75 }
    local def, ctx = Of.Armar(linea)
    check(def ~= nil, "no se armó " .. linea)
    if def then
      for n = 1, 4 do
        local co = ctx.costos and ctx.costos[n] or {}
        print(("  %d tramo %d: %s -> %s%s"):format(linea, n, tostring(co.antes and math.floor(co.antes)), tostring(co.ahora and math.floor(co.ahora)), ctx.optimizado[n] and " (más barato)" or ""))
        local x = llega(def, n)
        check(x == Ru.OficiosDatos.TRAMOS[n][2] or not ctx.optimizado[n], ("%d: el tramo %d llega a %d"):format(linea, n, x))
      end
    end
  end
end)

A.Compat.MapToWorld = mundoReal
A.Compat.GetPlayerWorldPosition = posReal
C_SkillInfo.GetSkillLineInfoByID = skillReal
print("PRUEBA: 1.3.9 oficios, " .. pasos .. " pasos, errores: " .. #ERRORS)
