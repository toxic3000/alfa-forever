-- Prueba de la 1.2.8, lo de Rutas y la recompensa (tools/prueba.py la corre con las demás prueba_*.lua):
--   * «Vuelta a entregar»: el orden por el vecino más cercano (otro continente
--     al final), la flecha de una en una con cada entrega, «Entrega 2 de 4»,
--     dejarla y ofrecerla en el rastreador con 2 o más listas;
--   * la piedra de hogar a tiempo: solo con 3 o más listas y el 60 % en tu
--     pueblo, lejos, con la piedra lista, fuera de combate, cada 20 minutos;
--     el botón es seguro (type = item) y con Lya a la vista lo dice ella;
--   * la zona peligrosa: una vez por zona, la subzona toma los niveles de su
--     zona, nada en instancias ni en combate;
--   * elegir la recompensa: la mejora para ti o la que más vale, marcada con
--     la huella y «Alfa te recomienda», sin elegir nunca.
SNAPSHOTS = {}
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
local function check(cond, msg) if not cond then NOTE("1.2.8 rutas", msg) end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
local Ru = NS_OF("Alfa_Rutas")
local Co = NS_OF("Alfa_Comodidades")
local Cp = A.Compat
C_Container = C_Container or {}
A.Maps = A.Maps or {}

-- Los avisos que salen (sin Lya, salvo que la prueba la pida).
local function conAvisos(fn)
  local avisos = {}
  local av, pl = K.Aviso, K.PorLya
  K.Aviso = function(o) avisos[#avisos + 1] = o return {} end
  K.PorLya = function() return false end
  local ok, e = pcall(fn, avisos)
  K.Aviso, K.PorLya = av, pl
  if not ok then error(e) end
  return avisos
end

-- Cambia campos de una tabla mientras corre fn y los devuelve.
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do t[k] = a.v end
  if not ok then error(e) end
end

-- Un mundo de mentira: el mapa 1440 en el continente 1 (100 yardas por
-- punto), el 1453 en el continente 0.
local function mundo(map, x, y)
  if map == 1440 then return 1, y * 100, x * 100 end
  if map == 1453 then return 0, y * 10, x * 10 end
  return nil
end
local function punto(map, x, y, id, nombre) return { map = map, x = x, y = y, kind = "npc", id = id, name = nombre } end

---------------------------------------------------------------------------
-- 5. Vuelta a entregar
---------------------------------------------------------------------------

local LOG
local LISTAS = {
  { qid = 901, titulo = "Pieles de jabalí", p = punto(1440, 52, 50, 11, "Gornek") },
  { qid = 902, titulo = "Cartas perdidas", p = punto(1440, 80, 50, 12, "Zureetha") },
  { qid = 903, titulo = "Más cartas", p = punto(1440, 80, 50, 12, "Zureetha") },
  { qid = 904, titulo = "Escorpiones", p = punto(1440, 60, 50, 13, "Galgar") },
  { qid = 905, titulo = "Al otro lado del mar", p = punto(1453, 40, 40, 14, "Thrall") },
}

local function conVuelta(fn)
  local Vt = Ru.Vuelta
  local Nav = A.Nav
  local flecha = { puestas = {}, soltada = 0 }
  local actual
  LOG = { [901] = true, [902] = true, [903] = true, [904] = true, [905] = true }
  con(Vt, { Listas = function() return LISTAS end }, function()
    con(Cp, { MapToWorld = mundo, IsOnQuest = function(q) return LOG[q] or false end }, function()
      con(A, { PlayerPoint = function() return { map = 1440, x = 50, y = 50 } end }, function()
        con(Nav, {
          SetTarget = function(map, x, y, label) actual = { map = map, x = x, y = y, label = label } flecha.puestas[#flecha.puestas + 1] = actual return actual end,
          StartTrip = function() return {} end,
          GetTarget = function() return actual end,
          Trip = function() return nil end,
          ReleaseTarget = function() actual = nil flecha.soltada = flecha.soltada + 1 end,
        }, function() fn(Vt, flecha, function() return actual end) end)
      end)
    end)
  end)
  Vt.Reiniciar()
end

step("La vuelta va por el vecino más cercano", function()
  local Vt = Ru.Vuelta
  check(Vt and Vt.Ordenar and Vt.Paradas, "falta Vuelta.lua")
  con(Cp, { MapToWorld = mundo }, function()
    local paradas = Vt.Paradas(LISTAS)
    check(#paradas == 4, "no juntó las dos misiones de Zureetha en una parada: " .. #paradas)
    local orden = Vt.Ordenar({ map = 1440, x = 50, y = 50 }, paradas)
    local nombres = {}
    for i, pa in ipairs(orden) do nombres[i] = pa.nombre end
    local dicho = table.concat(nombres, ", ")
    check(dicho == "Gornek, Galgar, Zureetha, Thrall", "el orden no fue el más corto (otro continente al final): " .. dicho)
  end)
end)

step("La flecha sigue cada entrega: «Entrega 2 de 4»", function()
  conVuelta(function(Vt, flecha, actual)
    local avisos = conAvisos(function() check(Vt.Empezar() == true, "no empezó la vuelta") end)
    local e = Vt.Estado()
    check(e and e.i == 1 and e.total == 4, "la vuelta no tiene 4 entregas")
    check(actual() and actual().x == 52, "la flecha no fue a la primera (Gornek)")
    check(avisos[1] and avisos[1].texto:find("Entrega 1 de 4", 1, true), "no dijo «Entrega 1 de 4»")
    check(AlfaRuta.Vuelta() and AlfaRuta.Vuelta().i == 1, "AlfaRuta.Vuelta no dice la vuelta")
    local d = Vt.Aviso()
    check(d and d.titulo:find("Entrega 1 de 4", 1, true) and d.dos, "el rastreador no dice «Entrega 1 de 4» con «Dejar la vuelta»")
    -- Entrega a Gornek: a Galgar.
    LOG[901] = nil
    conAvisos(function() Vt.AlEntregar(901) end)
    check(Vt.Estado().i == 2 and actual().x == 60, "tras la primera entrega la flecha no pasó a Galgar")
    check(Vt.Aviso().titulo:find("Entrega 2 de 4", 1, true), "el rastreador no dice «Entrega 2 de 4»")
    -- Con el evento del juego, como en el juego.
    LOG[904] = nil
    conAvisos(function() FIRE_EVENT("QUEST_TURNED_IN", 904, 0, 0) RUN_TIMERS(2) end)
    check(Vt.Estado().i == 3 and actual().x == 80, "QUEST_TURNED_IN no movió la flecha a Zureetha")
    -- Zureetha tiene dos: con una entregada, la flecha sigue ahí.
    LOG[902] = nil
    conAvisos(function() Vt.AlEntregar(902) end)
    check(Vt.Estado().i == 3, "se fue de Zureetha con una misión suya sin entregar")
    LOG[903] = nil
    conAvisos(function() Vt.AlEntregar(903) end)
    check(Vt.Estado().i == 4 and actual().map == 1453, "no pasó a la del otro continente")
    -- La última: vuelta completa y la flecha suelta.
    LOG[905] = nil
    avisos = conAvisos(function() Vt.AlEntregar(905) end)
    check(Vt.Estado() == nil, "la vuelta siguió después de la última entrega")
    check(avisos[1] and avisos[1].titulo == "¡Vuelta completa!", "no dijo «¡Vuelta completa!»")
    check(flecha.soltada >= 1, "no soltó la flecha al terminar")
  end)
end)

step("Dejar la vuelta suelta la flecha", function()
  conVuelta(function(Vt, flecha)
    conAvisos(function() Vt.Empezar() end)
    local d = Vt.Aviso()
    conAvisos(function() d.dos[2]() end)
    check(Vt.Estado() == nil, "«Dejar la vuelta» no la dejó")
    check(flecha.soltada == 1, "al dejarla no soltó la flecha")
    check(AlfaRuta.CancelarVuelta() == false, "dejó dos veces la misma vuelta")
    -- Con una sola lista no se arma.
    local una = { LISTAS[1] }
    con(Vt, { Listas = function() return una end }, function()
      local avisos = conAvisos(function() check(Vt.Empezar() == false, "armó una vuelta con una sola misión") end)
      check(avisos[1] and avisos[1].texto:find("al menos 2", 1, true), "no dijo que hacen falta 2")
    end)
    -- En combate, tampoco.
    con(_G, { InCombatLockdown = function() return true end }, function()
      conAvisos(function() check(Vt.Empezar() == false, "armó la vuelta en combate") end)
    end)
  end)
end)

step("El rastreador ofrece la vuelta con 2 o más listas", function()
  local Vt, Cr = Ru.Vuelta, Ru.Cerrar
  Vt.Reiniciar()
  con(Cr, { ListasAhora = function() return 1 end }, function()
    check(Vt.Aviso() == nil, "ofreció la vuelta con una sola lista")
  end)
  local n = 3
  con(Cr, { ListasAhora = function() return n end }, function()
    local d = Vt.Aviso()
    check(d and d.titulo == "Tienes 3 misiones listas" and d.uno[1] == "Vuelta a entregar", "no ofreció «Vuelta a entregar» con 3 listas")
    d.dos[2]() -- Después
    check(Vt.Aviso() == nil, "«Después» no la guardó")
    n = 4
    check(Vt.Aviso() ~= nil, "con una lista más no la volvió a ofrecer")
    A.Set("rutas.vueltaEntregar", false)
    check(Vt.Aviso() == nil, "la ofreció con el ajuste apagado")
    A.Set("rutas.vueltaEntregar", nil)
  end)
  -- La de verdad (con el Codex del banco) no truena.
  local ok, e = pcall(Vt.Listas)
  check(ok, "Vuelta.Listas tronó: " .. tostring(e))
  Vt.Reiniciar()
end)

---------------------------------------------------------------------------
-- 6. Piedra de hogar a tiempo
---------------------------------------------------------------------------

-- 3 de 4 se entregan junto a la posada de Orgrimmar (continente 0, en 400, 400).
local HOGAR = {
  { qid = 911, p = punto(1453, 40, 40, 21, "Thrall") },
  { qid = 912, p = punto(1453, 41, 41, 22, "Nazgrel") },
  { qid = 913, p = punto(1453, 42, 39, 23, "Rehgar") },
  { qid = 914, p = punto(1440, 50, 50, 24, "Gornek") },
}

local function conHogar(fn, opts)
  opts = opts or {}
  local Hg, Vt = Ru.Hogar, Ru.Vuelta
  Hg.Reiniciar()
  local lista = opts.lista or HOGAR
  con(Vt, { Listas = function() return lista end }, function()
    con(Ru.Cerrar, { ListasAhora = function() return #lista end }, function()
      con(Cp, {
        MapToWorld = mundo,
        GetItemCount = function(id) return id == 6948 and (opts.sinPiedra and 0 or 1) or 0 end,
        GetPlayerWorldPosition = function() if opts.cerca then return 0, 405, 400 end return 1, 5000, 5000 end,
      }, function()
        con(A.Nav, { BoundInn = function() return { c = 0, wx = 400, wy = 400 } end }, function()
          con(C_Container, { GetItemCooldown = function() if opts.recargando then return NOW - 10, 3600, 1 end return 0, 0, 1 end }, function()
            fn(Hg)
          end)
        end)
      end)
    end)
  end)
  Hg.Reiniciar()
end

step("La piedra de hogar a tiempo", function()
  check(Ru.Hogar and Ru.Hogar.Revisar, "falta Hogar.lua")
  conHogar(function(Hg)
    local dijo, por
    local avisos = conAvisos(function() dijo, por = Hg.Revisar() end)
    check(dijo and por == "aviso", "no sugirió la piedra: " .. tostring(por))
    local a = avisos[1]
    check(a and a.texto:find("3 de tus 4", 1, true) and a.texto:find("Orgrimmar", 1, true), "el aviso no dice «3 de tus 4 … Orgrimmar»")
    check(a and a.accion and a.accion.seguro and a.accion.seguro.type == "item" and a.accion.seguro.item == "item:6948",
      "el botón de la piedra no es seguro (type = item, 6948)")
    -- Una vez cada 20 minutos.
    avisos = conAvisos(function() dijo, por = Hg.Revisar() end)
    check(not dijo and por == "pronto" and #avisos == 0, "la volvió a sugerir enseguida")
    NOW = NOW + 1201
    avisos = conAvisos(function() dijo, por = Hg.Revisar() end)
    check(dijo, "no la sugirió pasados 20 minutos")
  end)
  -- Con Lya a la vista lo dice ella (sin el aviso con botón).
  conHogar(function(Hg)
    local av, pl = K.Aviso, K.PorLya
    local salio = 0
    K.Aviso = function() salio = salio + 1 end
    K.PorLya = function(o) return o.titulo == "Piedra de hogar a tiempo" end
    local dijo, por = Hg.Revisar()
    K.Aviso, K.PorLya = av, pl
    check(dijo and por == "lya" and salio == 0, "con Lya a la vista no lo dijo ella: " .. tostring(por))
  end)
  local casos = {
    { { recargando = true }, "recargando", "con la piedra recargándose" },
    { { sinPiedra = true }, "recargando", "sin la piedra en las bolsas" },
    { { cerca = true }, "cerca", "estando en el pueblo" },
    { { lista = { HOGAR[1], HOGAR[2], HOGAR[4], HOGAR[4] } }, "pocas", "con solo la mitad en el pueblo" },
    { { lista = { HOGAR[1], HOGAR[2] } }, "pocas", "con solo 2 listas" },
  }
  for _, c in ipairs(casos) do
    conHogar(function(Hg)
      local dijo, por
      local avisos = conAvisos(function() dijo, por = Hg.Revisar() end)
      check(not dijo and por == c[2] and #avisos == 0, "sugirió la piedra " .. c[3] .. ": " .. tostring(por))
    end, c[1])
  end
  conHogar(function(Hg)
    con(_G, { InCombatLockdown = function() return true end }, function()
      local dijo, por = Hg.Revisar()
      check(not dijo and por == "combate", "sugirió la piedra en combate")
    end)
    con(_G, { IsInInstance = function() return true, "party" end }, function()
      local dijo = Hg.Revisar()
      check(not dijo, "sugirió la piedra en una instancia")
    end)
    A.Set("rutas.piedraHogar", false)
    local dijo = Hg.Revisar()
    A.Set("rutas.piedraHogar", nil)
    check(not dijo, "sugirió la piedra con el ajuste apagado")
  end)
end)

---------------------------------------------------------------------------
-- 7. Zona peligrosa
---------------------------------------------------------------------------

step("Zona peligrosa: una vez por zona", function()
  local Pg = Ru.Peligro
  check(Pg and Pg.Revisar, "falta Peligro.lua")
  Pg.Reiniciar()
  local NIVELES = { [2001] = { 30, 35 }, [2002] = { 22, 28 } }
  local PADRE = { [3001] = 2001 } -- 3001: una subzona de 2001, sin niveles propios
  local aqui = 3001
  con(A.Maps, { GetZoneLevels = function(id) local v = NIVELES[id] if v then return v[1], v[2] end end }, function()
    con(C_Map, { GetBestMapForUnit = function() return aqui end,
      GetMapInfo = function(id) return { mapID = id, name = id == 2001 and "Desolace" or "Zona " .. id, parentMapID = PADRE[id] or 0 } end,
      GetMapLevels = function() return nil end }, function()
      local dijo, por
      local avisos = conAvisos(function() dijo, por = Pg.Revisar() end)
      check(dijo, "no avisó de una zona 7 niveles arriba: " .. tostring(por))
      local a = avisos[1]
      check(a and a.texto == "Cuidado: aquí los enemigos son nivel 30–35.", "el aviso no dice «nivel 30–35»: " .. tostring(a and a.texto))
      -- Una vez por zona y sesión (también desde la zona misma).
      aqui = 2001
      avisos = conAvisos(function() dijo, por = Pg.Revisar() end)
      check(not dijo and por == "dicha" and #avisos == 0, "avisó dos veces de la misma zona")
      -- Una zona apenas arriba de ti: nada.
      aqui = 2002
      avisos = conAvisos(function() dijo, por = Pg.Revisar() end)
      check(not dijo and por == "segura", "avisó de una zona de 22–28 a nivel 23")
      -- En instancia o en combate: nada.
      Pg.Reiniciar()
      aqui = 2001
      con(_G, { IsInInstance = function() return true, "party" end }, function()
        avisos = conAvisos(function() dijo, por = Pg.Revisar() end)
        check(not dijo and por == "instancia", "avisó dentro de una instancia")
      end)
      con(_G, { InCombatLockdown = function() return true end }, function()
        avisos = conAvisos(function() dijo, por = Pg.Revisar() end)
        check(not dijo and por == "combate", "avisó en combate")
      end)
      -- Al salir del combate, sí.
      avisos = conAvisos(function() FIRE_EVENT("PLAYER_REGEN_ENABLED") RUN_TIMERS(4) end)
      check(#avisos >= 1, "no avisó al terminar el combate")
      Pg.Reiniciar()
      A.Set("rutas.zonaPeligrosa", false)
      avisos = conAvisos(function() dijo, por = Pg.Revisar() end)
      A.Set("rutas.zonaPeligrosa", nil)
      check(not dijo and por == "apagado", "avisó con el ajuste apagado")
    end)
  end)
  Pg.Reiniciar()
end)

---------------------------------------------------------------------------
-- 8. Elegir la recompensa
---------------------------------------------------------------------------

local NOMBRES = { "Espada de la manada", "Escudo de roble", "Anillo de colmillo" }
local botones = {}
local panel = CreateFrame("Frame", nil, UIParent)
panel.RewardButtons = {}
for i = 1, 3 do
  local b = CreateFrame("Button", nil, panel)
  b.type, b.objectType = "choice", "item"
  b.GetID = function() return i end
  b:Show()
  botones[i] = b
  panel.RewardButtons[i] = b
end
panel:Show()

local function conRecompensas(lista, completa, fn, sinMotor)
  local Mi = Co.Misiones
  local R = A.QoL and A.QoL.Rewards
  local rank = R and R.Rank
  local qi = QuestInfoFrame
  QuestInfoFrame = { rewardsFrame = panel }
  con(_G, {
    GetNumQuestChoices = function() return #lista end,
    GetQuestItemInfo = function(_, i) return NOMBRES[i], 0, 1 end,
    GetQuestItemLink = function(_, i) return "item:" .. (7000 + i) end,
  }, function()
    if sinMotor or not R then
      local q = A.QoL
      if q then
        local antes = q.Rewards
        q.Rewards = nil
        local ok, e = pcall(fn, Mi)
        q.Rewards = antes
        if not ok then error(e) end
      else
        fn(Mi)
      end
    else
      con(R, { ReadChoices = function() return lista, completa end, Rank = rank }, function() fn(Mi) end)
    end
  end)
  QuestInfoFrame = qi
end

step("Elegir la recompensa: la mejora para ti", function()
  local Mi = Co.Misiones
  check(Mi and Mi.MarcarRecompensa, "falta la recompensa en Misiones.lua")
  local lista = {
    { index = 1, value = 500, upgrade = false },
    { index = 2, value = 100, upgrade = true, delta = 8 },
    { index = 3, value = 900, upgrade = true, delta = 3 },
  }
  conRecompensas(lista, true, function()
    local i = Mi.MarcarRecompensa()
    check(i == 2, "no marcó la mayor mejora: " .. tostring(i))
    local m, l = Mi.Rec.marca, Mi.Rec.linea
    check(m and m:IsShown() and m:GetParent() == botones[2], "la huella no quedó sobre el botón de la mejora")
    check(l and l:IsShown() and l.Titulo:GetText() == "Alfa te recomienda: Escudo de roble", "no dijo «Alfa te recomienda: Escudo de roble»")
    check(l.Texto:GetText() == "Es una mejora para ti.", "no dijo que es una mejora")
  end)
end)

step("Elegir la recompensa: sin mejoras, la que más vale", function()
  local Mi = Co.Misiones
  local lista = {
    { index = 1, value = 500 }, { index = 2, value = 100 }, { index = 3, value = 900 },
  }
  conRecompensas(lista, true, function()
    check(Mi.MarcarRecompensa() == 3, "sin mejoras no marcó la que más vale")
    check(Mi.Rec.linea.Texto:GetText() == "Es la que más vale al venderla.", "no dijo que es la que más vale")
  end)
  -- Datos que faltan: espera, no adivina.
  conRecompensas(lista, false, function()
    check(Mi.MarcarRecompensa() == nil, "marcó una sin tener todos los datos")
    check(not Mi.Rec.linea:IsShown(), "dejó la línea de otra misión")
  end)
  -- Todo vale 0 y nada es mejora: nada que recomendar.
  conRecompensas({ { index = 1, value = 0 }, { index = 2, value = 0 } }, true, function()
    check(Mi.MarcarRecompensa() == nil, "recomendó algo sin razón")
  end)
  -- Sin el motor: por el precio de venta del juego.
  local precios = { ["item:7001"] = 30, ["item:7002"] = 70, ["item:7003"] = 10 }
  con(_G, { GetItemInfo = function(l) return "x", l, 2, 10, 1, "Armadura", "Tela", 1, "INVTYPE_CHEST", 0, precios[l] end }, function()
    con(C_Item, { GetItemInfo = function(l) return "x", l, 2, 10, 1, "Armadura", "Tela", 1, "INVTYPE_CHEST", 0, precios[l] end }, function()
      conRecompensas(lista, true, function()
        check(Mi.MarcarRecompensa() == 2, "sin el motor no marcó la de mejor precio")
      end, true)
    end)
  end)
  -- Apagado: nada.
  A.Set("comodidades.recompensa", false)
  conRecompensas(lista, true, function()
    check(Mi.MarcarRecompensa() == nil and not Mi.Rec.linea:IsShown(), "marcó con el ajuste apagado")
  end)
  A.Set("comodidades.recompensa", nil)
  -- Con el evento del juego, y nunca elige: GetQuestReward no se llama.
  local elegida
  con(_G, { GetQuestReward = function(i) elegida = i end }, function()
    conRecompensas(lista, true, function()
      FIRE_EVENT("QUEST_COMPLETE")
      RUN_TIMERS(2)
      check(Mi.Rec.mejor == 3, "QUEST_COMPLETE no marcó la recompensa")
      FIRE_EVENT("QUEST_FINISHED")
      check(not Mi.Rec.linea:IsShown(), "la línea siguió al cerrar la ventana")
    end)
  end)
  check(elegida == nil, "Alfa eligió la recompensa por ti")
end)

step("Los ajustes están en Misiones y vienen encendidos", function()
  for _, k in ipairs({ "rutas.vueltaEntregar", "rutas.piedraHogar", "rutas.zonaPeligrosa", "comodidades.recompensa" }) do
    check(A.Get(k) == true, k .. " no viene encendido")
  end
end)

print(string.format("PRUEBA: 1.2.8 rutas (vuelta a entregar, piedra, zona peligrosa, recompensa), %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
