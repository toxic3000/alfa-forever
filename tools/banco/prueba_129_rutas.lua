-- Prueba de la 1.2.9, lo de Rutas (tools/prueba.py la corre con las demás prueba_*.lua):
--   * la llegada de la flecha con la cara de La Jauría: «Busca por aquí», la
--     acción en palabras llanas, «4 de 6» con su barrita y «Siguiente lugar»
--     (en combate no toma el ratón); el paso de nivel («Sube al nivel 30: te
--     falta 20%») y el texto del motor ya sin «nivel nivel y porcentaje»;
--   * pasos de nivel claros: lo que falta, la barra y dónde rinde más (de tu
--     nivel, que cuenta para una misión; ni élites ni lejos);
--   * misiones de élite: el aviso antes, con «Llamar a la manada»; nada en grupo;
--   * compartir con tu grupo: quien no la tiene, «Compartir» (QuestLogPushQuest
--     solo al clic), con la lista de La Jauría o la del juego;
--   * la siguiente guía sola al terminar una;
--   * el vuelo más cerca de tu paso en el mapa de vuelos (solo se ve);
--   * el modo foco: el rastreador compacto en combate y en mazmorras.
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
local function check(cond, msg) if not cond then NOTE("1.2.9 rutas", msg) end end

-- Lo que Lya aprende al entrar (Pregúntale a Lya).
local ensenadas = {}
do
  local Lya = rawget(_G, "AlfaLya")
  local orig = Lya and Lya.Ensenar
  if orig then
    Lya.Ensenar = function(p) if type(p) == "table" and type(p.id) == "string" then ensenadas[p.id] = p end return orig(p) end
  end
end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local A = AlfaNucleo.A
local N = AlfaNucleo
local K = AlfaNucleo.Kit
local Ru = NS_OF("Alfa_Rutas")
local E = A.Engine
local Nav = A.Nav
local Cp = A.Compat

-- Cambia campos de una tabla mientras corre fn y los devuelve.
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do t[k] = a.v end
  if not ok then error(e) end
end

-- Un mundo de mentira: el mapa 1440 en el continente 1 (100 yardas por punto).
local function mundo(map, x, y)
  if map == 1440 then return 1, y * 100, x * 100 end
  if map == 1453 then return 0, y * 10, x * 10 end
  return nil
end

---------------------------------------------------------------------------
-- 21. La llegada de la flecha
---------------------------------------------------------------------------

local Arrow = Nav and Nav.arrow

local function llegar(target, estado, vista, guia, fn)
  local siguiente = 0
  local ahora = estado
  con(Nav, {
    Sample = function() return ahora, 3, 0 end,
    GetTarget = function() return target end,
    NextSpot = function() siguiente = siguiente + 1 return true end,
    TomTomArrowGuides = function() return false end,
    HandedOff = function() return false end,
    HiddenWithGuide = function() return false end,
  }, function()
    con(E, { GetStepView = function() return vista end, GetGuide = function() return guia end }, function()
      con(A, { ArrowHidden = function() return false end }, function()
        Arrow:OnTarget(target)
        fn(function() return siguiente end)
        -- Te alejas: la flecha vuelve a apuntar y la llegada se quita.
        ahora = "travel"
        Arrow:Refresh()
        check(Arrow.Llegada() == nil and Arrow.distText:IsShown(), "al irse, la llegada no devolvió el texto de la flecha")
        Arrow:OnTarget(nil)
        Arrow.frame:Hide()
      end)
    end)
  end)
end

step("La llegada de un área: «Busca por aquí», la acción, «4 de 6» y «Siguiente lugar»", function()
  check(Arrow and Arrow.Llegada, "falta Arrow.Llegada (motor/Alfa/Nav/Arrow.lua)")
  local T = { label = "Mata a Asaltante Branquiazul", stepIndex = 1, goalIndex = 1, spots = { {}, {} }, map = 1440, x = 50, y = 50 }
  local vista = { index = 1, goals = { { t = "kill", status = "active", progress = { cur = 4, max = 6 } } } }
  llegar(T, "search", vista, nil, function(veces)
    local d = Arrow.Llegada()
    check(d ~= nil, "la llegada de Alfa no salió")
    if not d then return end
    check(d.sobre == K.Mayus("Busca por aquí"), "arriba no dice «BUSCA POR AQUÍ»: " .. tostring(d.sobre))
    check(d.accion == "Mata a Asaltante Branquiazul", "la acción no es la de la meta: " .. tostring(d.accion))
    check(d.avance == "4 de 6", "el avance no dice «4 de 6»: " .. tostring(d.avance))
    check(d.barra, "falta la barrita del avance")
    check(d.siguiente and d.clicable, "falta «Siguiente lugar» o no se puede clicar")
    check(not Arrow.distText:IsShown() and not Arrow.etaText:IsShown(), "el texto viejo del motor sigue a la vista")
    check(not (Arrow.etaText:GetText() or ""):find("flecha", 1, true), "sigue «Haz clic en la flecha para el siguiente lugar»")
    FIRE(Arrow.llegada.Siguiente, "OnClick", "LeftButton")
    check(veces() == 1, "«Siguiente lugar» no pasó al siguiente lugar")
    -- En combate se ve, pero no toma el ratón.
    con(_G, { InCombatLockdown = function() return true end }, function()
      FIRE_EVENT("PLAYER_REGEN_DISABLED")
      local c = Arrow.Llegada()
      check(c and c.siguiente and not c.clicable, "en combate «Siguiente lugar» sigue tomando el ratón")
      FIRE(Arrow.llegada.Siguiente, "OnClick", "LeftButton")
      check(veces() == 1, "en combate «Siguiente lugar» hizo algo")
    end)
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    check(Arrow.Llegada().clicable, "al salir de combate «Siguiente lugar» no volvió a tomar el ratón")
    -- El avance sube mientras estás ahí.
    vista.goals[1].progress.cur = 5
    FIRE_EVENT("PLAYER_XP_UPDATE")
    check(Arrow.Llegada().avance == "5 de 6", "el avance no se puso al día: " .. tostring(Arrow.Llegada().avance))
  end)
end)

step("Llegar a un PNJ: «Llegaste», sin avance ni botón", function()
  local T = { label = "Habla con Gornek", stepIndex = 1, goalIndex = 1, map = 1440, x = 50, y = 50 }
  local vista = { index = 1, goals = { { t = "talk", status = "active" } } }
  llegar(T, "arrived", vista, nil, function()
    local d = Arrow.Llegada()
    check(d and d.sobre == K.Mayus("Llegaste"), "no dice «LLEGASTE»")
    check(d and d.accion == "Habla con Gornek", "no dice «Habla con Gornek»")
    check(d and not d.avance and not d.siguiente and not d.barra, "a un PNJ le salió avance o «Siguiente lugar»")
  end)
end)

step("Un paso de nivel en la llegada: «Sube al nivel 30: te falta 20%»", function()
  local T = { label = "Sube al nivel 30", stepIndex = 2, goalIndex = 1, spots = { {}, {} }, map = 1440, x = 50, y = 50 }
  local vista = { index = 2, goals = { { t = "level", status = "active", xpLeft = 280 } } }
  local guia = { id = "x", steps = { [2] = { goals = { { t = "level", level = 30 } } } } }
  con(A.Levels, { Player = function() return { level = 30, xp = 1120, xpMax = 1400 } end }, function()
    llegar(T, "search", vista, guia, function()
      local d = Arrow.Llegada()
      check(d and d.accion == "Sube al nivel 30: te falta 20%", "el nivel no dice «Sube al nivel 30: te falta 20%»: " .. tostring(d and d.accion))
      check(d and d.barra, "el nivel no trae su barrita")
    end)
    vista.goals[1].xpLeft = 3000
    llegar(T, "search", vista, guia, function()
      local d = Arrow.Llegada()
      check(d and d.accion and d.accion:find("te faltan", 1, true), "con más de un nivel no dice cuánta experiencia falta: " .. tostring(d and d.accion))
    end)
  end)
end)

step("El paso de nivel del motor ya no dice «nivel nivel y porcentaje»", function()
  check(A.T("Sube al nivel") == "Sube al nivel", "falta el texto «Sube al nivel» del motor")
  -- Un paso de nivel de una guía de verdad (si hay alguno a la mano).
  local Gd = A.Guides
  local visto
  for _, h in ipairs(Gd and Gd.List and Gd.List() or {}) do
    if visto then break end
    local g = Gd.Get(h.id)
    local okS, steps = pcall(function() return g and g.steps end)
    for i, s in ipairs(okS and type(steps) == "table" and steps or {}) do
      for gi, goal in ipairs(s.goals or {}) do
        if goal.t == "level" then
          E.SetGuide(h.id)
          local v = E.GetStepView(i)
          local gv = v and v.goals and v.goals[gi]
          visto = gv and (gv.text or "") or ""
          check(gv and gv.verb == "Sube al nivel", "el verbo del paso de nivel no es «Sube al nivel»: " .. tostring(gv and gv.verb))
          check(not visto:find("nivel nivel", 1, true) and not visto:find("porcentaje", 1, true), "el paso de nivel sigue diciendo «nivel nivel y porcentaje»: " .. visto)
          break
        end
      end
      if visto then break end
    end
  end
  print("   paso de nivel del motor: " .. tostring(visto or "(ninguna guía cargada con uno)"))
end)

---------------------------------------------------------------------------
-- 1. Pasos de nivel claros
---------------------------------------------------------------------------

local function conCodex(npcs, quests, fn)
  local Cx = {
    IsLoaded = function() return true end,
    Quest = function(q) return quests[q] end,
    Npc = function(n) return npcs[n] end,
    Item = function(i)
      if i == 500 then return { sources = { { type = "drop", npc = 31, chance = 40 }, { type = "drop", npc = 32, chance = 10, instance = "x" } } } end
      return nil
    end,
  }
  con(A, { Codex = Cx, PlayerPoint = function() return { map = 1440, x = 50, y = 50 } end }, function()
    con(Cp, { MapToWorld = mundo, GetLogQuests = function() local t = {} for q in pairs(quests) do t[#t + 1] = q end table.sort(t) return t end,
      IsQuestReadyForTurnIn = function() return false end }, function()
      con(Ru.Indice, { Jugador = function() return { level = 12, xp = 600, xpMax = 1000 } end }, fn)
    end)
  end)
end

step("Pasos de nivel: lo que falta, la barra y dónde rinde más", function()
  local Nv = Ru.Nivel
  check(Nv and Nv.Aviso and Nv.DondeRinde, "falta Nivel.lua")
  local npcs = {
    [21] = { name = "Jabalí moteado", level = 12, spawns = { { map = 1440, x = 52, y = 50 } } },     -- 200 yd, cuenta para 801
    [22] = { name = "Ogro élite", level = 12, elite = true, spawns = { { map = 1440, x = 50, y = 51 } } },
    [23] = { name = "Lejano", level = 13, spawns = { { map = 1440, x = 90, y = 90 } } },              -- muy lejos
    [31] = { name = "Ladrón Mano Negra", level = 13, spawns = { { map = 1440, x = 51, y = 50 } } },  -- suelta el objeto de 802
  }
  local quests = {
    [801] = { objectives = { { type = "kill", id = 21, count = 8 }, { type = "kill", id = 22, count = 1 } } },
    [802] = { objectives = { { type = "item", id = 500, count = 5 } } },
    [803] = { objectives = { { type = "kill", id = 23, count = 5 } } },
  }
  local v = { index = 4, goals = { { t = "level", status = "active", xpLeft = 400, subject = "13" } } }
  conCodex(npcs, quests, function()
    Nv.Olvidar()
    local r = Nv.DondeRinde(true)
    check(r and r.npc == 31, "no eligió al de tu nivel más cerca que cuenta para una misión: " .. tostring(r and r.nombre))
    check(r and r.mision == 802, "no dijo para qué misión cuenta")
    local d = Nv.Aviso(v, 4)
    check(d and d.titulo == "Te faltan 400 de experiencia para el nivel 13", "el título no dice lo que falta: " .. tostring(d and d.titulo))
    check(d and d.barra and math.abs(d.barra - 0.6) < 0.01, "la barra no es la de tu nivel de ahora")
    check(d and d.texto and d.texto:find("Ladrón Mano Negra", 1, true), "no dice dónde rinde más")
    -- «Llévame»: la flecha al lugar.
    local puesto
    con(Nav, { SetTarget = function(map, x, y, label) puesto = { map = map, x = x, label = label } return puesto end, StartTrip = function() end }, function()
      d.uno[2]()
    end)
    check(puesto and puesto.x == 51 and puesto.label == "Ladrón Mano Negra", "«Llévame» no puso la flecha en el enemigo")
    -- Sin misiones que cuenten: el consejo de siempre.
    Nv.Olvidar()
    conCodex({}, {}, function()
      local d2 = Nv.Aviso(v, 4)
      check(d2 and not d2.uno and d2.texto:find("grises", 1, true), "sin enemigos que cuenten no dio el consejo")
    end)
    -- Mirando otro paso (vista previa) o con el ajuste apagado: nada.
    check(Nv.Aviso(v, 3) == nil, "salió el aviso de nivel en un paso que no es el de ahora")
    A.Set("rutas.nivelClaro", false)
    check(Nv.Aviso(v, 4) == nil, "salió con rutas.nivelClaro apagado")
    A.Set("rutas.nivelClaro", nil)
    -- El rastreador lo muestra con su barrita.
    con(E, { GetGuide = function() return { id = "x", steps = {} } end, GetStepIndex = function() return 4 end,
      GetLiveStep = function() return 4 end, GetStepView = function() return v end,
      LostQuestion = function() return nil end, GroupQuestion = function() return nil end }, function()
      con(Ru.Vuelta, { Aviso = function() return nil end, Estado = function() return nil end }, function()
        Nv.Olvidar()
        local a = Ru.Rastreador.AvisoDeAhora()
        check(a and a.barra and a.titulo:find("Te faltan", 1, true), "el rastreador no muestra el paso de nivel claro")
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- 2. Misiones de élite
---------------------------------------------------------------------------

step("Antes de una de élite: el aviso con «Llamar a la manada»", function()
  local Gr = Ru.Grupo
  check(Gr and Gr.Aviso and Gr.Elite, "falta Grupo.lua")
  Gr.Reiniciar()
  local ahora = { index = 7, goals = { { t = "goto", status = "active" } } }
  local sigue = { index = 8, goals = { { t = "kill", status = "pending", quest = 7701, party = { kind = "elite", rank = 1 } } } }
  local llamado = 0
  con(E, { GetStepView = function(i) return i == 8 and sigue or ahora end }, function()
    con(Ru, { TituloMision = function() return "El jefe kobold" end }, function()
      con(AlfaManada, { Llamar = function() llamado = llamado + 1 return true end }, function()
        local d = Gr.Aviso(ahora, 7)
        check(d and d.titulo == "Ojo: " .. Ru.Citar("El jefe kobold") .. " es de élite", "no avisó antes de la de élite: " .. tostring(d and d.titulo))
        check(d and d.uno and d.uno[1] == "Llamar a la manada", "no ofreció «Llamar a la manada»")
        d.uno[2]()
        check(llamado == 1, "«Llamar a la manada» no llamó a la manada")
        check(Gr.Aviso(ahora, 7) == nil, "después de llamar siguió el aviso")
        Gr.Reiniciar()
        -- En grupo ya no hace falta.
        con(_G, { IsInGroup = function() return true end, GetNumGroupMembers = function() return 3 end }, function()
          local g = Gr.Elite(ahora, 7) and Gr.Aviso(ahora, 7)
          check(not (g and g.titulo and g.titulo:find("élite", 1, true)), "en grupo avisó de la de élite")
        end)
        -- Con el ajuste apagado, nada.
        A.Set("rutas.avisoElite", false)
        check(Gr.Aviso(ahora, 7) == nil, "avisó con rutas.avisoElite apagado")
        A.Set("rutas.avisoElite", nil)
        -- «Entendido» la guarda.
        local e = Gr.Aviso(ahora, 7)
        e.dos[2]()
        check(Gr.Aviso(ahora, 7) == nil, "«Entendido» no la guardó")
      end)
    end)
  end)
  Gr.Reiniciar()
end)

---------------------------------------------------------------------------
-- 3. Compartir con tu grupo
---------------------------------------------------------------------------

step("En grupo: quien no tiene tu misión, con «Compartir» al clic", function()
  local Gr = Ru.Grupo
  Gr.Reiniciar()
  local empujadas, elegida = {}, nil
  local QL = C_QuestLog
  local tieneAna = { [901] = true }
  con(_G, {
    IsInGroup = function() return true end, GetNumGroupMembers = function() return 3 end,
    UnitExists = function(u) return u == "player" or u == "party1" or u == "party2" end,
    UnitName = function(u) if u == "party1" then return "Ana" elseif u == "party2" then return "Beto" end return "Lobato" end,
    UnitLevel = function() return 20 end,
    QuestLogPushQuest = function(i) empujadas[#empujadas + 1] = i end,
    SelectQuestLogEntry = function(i) elegida = i end,
  }, function()
    con(QL, {
      IsPushableQuest = function(q) return q ~= 903 end,
      IsUnitOnQuest = function(u, q) if u == "party1" then return tieneAna[q] or false end return true end,
      GetLogIndexForQuestID = function(q) return q - 900 end,
    }, function()
      con(Cp, { GetLogQuests = function() return { 901, 902, 903 } end }, function()
        con(Ru, { TituloMision = function(q) return "Misión " .. q end }, function()
          local lista = Gr.Compartibles(true)
          check(#lista == 1 and lista[1].qid == 902 and lista[1].quienes[1] == "Ana", "no vio que a Ana le falta la 902 (y la 903 no se comparte)")
          check(#empujadas == 0, "compartió sin que hicieras clic")
          local d = Gr.Aviso(nil, nil)
          check(d and d.titulo == "Ana no tiene " .. Ru.Citar("Misión 902") and d.uno[1] == "Compartir", "el rastreador no ofreció «Compartir»: " .. tostring(d and d.titulo))
          d.uno[2]()
          check(empujadas[1] == 2 and elegida == 2, "«Compartir» no compartió la misión de tu registro")
          check(Gr.Aviso(nil, nil) == nil, "después de compartirla siguió el aviso")
          -- La lista que manda La Jauría manda sobre la del juego.
          Gr.Reiniciar()
          con(AlfaManada, { MisionesDe = function(nombre) if nombre == "Beto" then return { [901] = true } end return nil end }, function()
            local l2 = Gr.Compartibles(true)
            local beto = false
            for _, c in ipairs(l2) do for _, q in ipairs(c.quienes) do if q == "Beto" and c.qid == 902 then beto = true end end end
            check(beto, "no usó la lista de La Jauría para saber que a Beto le falta la 902")
          end)
          -- Apagado, nada.
          Gr.Reiniciar()
          A.Set("rutas.compartirMisiones", false)
          check(Gr.Aviso(nil, nil) == nil, "ofreció compartir con el ajuste apagado")
          A.Set("rutas.compartirMisiones", nil)
          -- «Ahora no».
          local d3 = Gr.Aviso(nil, nil)
          d3.dos[2]()
          check(Gr.Aviso(nil, nil) == nil, "«Ahora no» no la guardó")
        end)
      end)
    end)
  end)
  Gr.Reiniciar()
  check(#Gr.Compartibles(true) == 0, "solo, sin grupo, ofreció compartir")
end)

---------------------------------------------------------------------------
-- 4. La siguiente guía sola
---------------------------------------------------------------------------

step("Al terminar una guía, la siguiente para tu nivel a un clic", function()
  local Sg = Ru.Siguiente
  check(Sg and Sg.Proponer, "falta Siguiente.lua")
  local Gd = A.Guides
  local abierta
  local H = { actual = { id = "actual", title = "Durotar" }, hecha = { id = "hecha", title = "Ya hecha" }, otra = { id = "otra", title = "Los Baldíos" } }
  con(Gd, { Suggestions = function() return { "actual", "hecha", "otra" } end, Get = function(id) return H[id] end }, function()
    con(E, { GetGuide = function() return { id = "actual" } end, GetGuideState = function(id) return id == "hecha" and "done" or "new" end }, function()
      con(Ru.Biblioteca, { Seguir = function(id) abierta = id end }, function()
        Sg.Olvidar()
        local p = Sg.Proponer()
        check(p and p.id == "otra", "no propuso la siguiente (ni la de ahora ni una hecha): " .. tostring(p and p.id))
        -- El fin del motor con el rastreador oculto: el aviso flotante.
        local fin = A.Reemplazo and A.Reemplazo("GUIDE_END")
        check(fin ~= nil, "no hay reemplazo de GUIDE_END")
        local avisos = {}
        local av, pl = K.Aviso, K.PorLya
        K.Aviso = function(o) avisos[#avisos + 1] = o return {} end
        con(Ru.Rastreador, { Visible = function() return false end }, function()
          local F = rawget(_G, "AlfaRastreador")
          local visto = F and F:IsShown()
          if F then F:Hide() end
          pcall(fin, { modelo = { complete = true, label = "Durotar" } })
          if F and visto then F:Show() end
        end)
        K.Aviso = av
        local a = avisos[1]
        check(a and a.accion and a.accion.texto == "Seguir con Los Baldíos", "el fin de guía no ofreció «Seguir con Los Baldíos»: " .. tostring(a and a.accion and a.accion.texto))
        if a and a.accion then a.accion.alClic() end
        check(abierta == "otra", "«Seguir con…» no abrió la siguiente guía")
        pcall(fin, { accion = "ocultar" })
        A.Set("rutas.siguienteGuia", false)
        check(Sg.Proponer() == nil, "propuso con rutas.siguienteGuia apagado")
        A.Set("rutas.siguienteGuia", nil)
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- 5. El vuelo más cerca de tu paso
---------------------------------------------------------------------------

step("En el mapa de vuelos, la marca del destino más cerca de tu paso", function()
  local Vu = Ru.Vuelo
  check(Vu and Vu.Marcar, "falta Vuelo.lua")
  local NODOS = { [1] = { id = 11, c = 1, wx = 5000, wy = 5000 }, [2] = { id = 12, c = 1, wx = 1200, wy = 8900 }, [3] = { id = 13, c = 1, wx = 4000, wy = 4000 } }
  local TIPO = { "CURRENT", "REACHABLE", "REACHABLE" }
  local tf = CreateFrame("Frame", "TaxiFrame", UIParent)
  tf:Show()
  for i = 1, 3 do
    local b = CreateFrame("Button", "TaxiButton" .. i, tf)
    b:SetSize(16, 16)
    b:Show()
  end
  local Fl = A.QoL and A.QoL.Flight
  con(_G, {
    NumTaxiNodes = function() return 3 end,
    TaxiNodeGetType = function(i) return TIPO[i] end,
    TaxiNodeName = function(i) return "Nodo " .. i .. ", Zona" end,
    GetTaxiMapID = function() return 1414 end,
    C_TaxiMap = { GetAllTaxiNodes = function() return { { slotIndex = 1, nodeID = 11 }, { slotIndex = 2, nodeID = 12 }, { slotIndex = 3, nodeID = 13 } } end },
  }, function()
    con(Nav, { GetTaxiNode = function(id) for _, n in pairs(NODOS) do if n.id == id then return n end end end,
      -- Tu paso: en x = 90, y = 10 del mapa 1440 (wx 9000... no: wx = y * 100 = 1000, wy = x * 100 = 9000).
      GetTarget = function() return { map = 1440, x = 90, y = 10 } end }, function()
      con(A, { PlayerPoint = function() return { map = 1440, x = 50, y = 50 } end }, function()
        con(Cp, { MapToWorld = mundo }, function()
          con(Fl or {}, { node = nil }, function()
            FIRE_EVENT("TAXIMAP_OPENED")
            RUN_TIMERS(2)
            check(Vu.marcado == 2, "no marcó el destino más cerca de tu paso: " .. tostring(Vu.marcado))
            local m = Vu.marca
            check(m and m:IsShown() and m:GetParent() == _G.TaxiButton2, "la marca no está sobre el destino")
            check(m and not m:IsMouseEnabled(), "la marca toma el ratón")
            check(m and m.Texto:GetText() == "Más cerca de tu paso", "la marca no dice «Más cerca de tu paso»")
            FIRE_EVENT("TAXIMAP_CLOSED")
            check(not m:IsShown(), "al cerrar el mapa siguió la marca")
          end)
          -- La ruta del motor ya marcó su vuelo: Alfa no pone otra.
          if Fl then
            con(Fl, { node = 3 }, function()
              local slot, por = Vu.Marcar()
              check(slot == nil and por == "motor", "marcó otro vuelo encima del de la ruta")
            end)
          end
          -- Tu paso está aquí al lado: no hace falta volar.
          con(Nav, { GetTarget = function() return { map = 1440, x = 51, y = 50 } end }, function()
            local slot, por = Vu.Mejor()
            check(slot == nil and por == "cerca", "propuso volar con tu paso al lado")
          end)
          A.Set("rutas.vueloListo", false)
          check(Vu.Mejor() == nil, "marcó con rutas.vueloListo apagado")
          A.Set("rutas.vueloListo", nil)
        end)
      end)
    end)
  end)
  tf:Hide()
end)

---------------------------------------------------------------------------
-- 20. Modo foco en el rastreador
---------------------------------------------------------------------------

step("Modo foco: compacto en combate y en mazmorras, y vuelve después", function()
  local Rs, Fo = Ru.Rastreador, Ru.Foco
  check(Fo and Fo.Activo, "falta Foco.lua")
  A.Set("rutas.seguimientoCompleto", true)
  check(Rs.Compacto() == false, "con la vista amplia el rastreador no está amplio")
  N.Set("lya", "foco", true)
  check(Rs.Compacto() == false, "con foco y sin pelea, se volvió compacto")
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(Rs.Compacto() == true, "con foco, en combate no se volvió compacto")
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  check(Rs.Compacto() == false, "al salir de combate no volvió a la vista amplia")
  con(_G, { IsInInstance = function() return true, "party" end }, function()
    check(Rs.Compacto() == true, "con foco, en una mazmorra no se volvió compacto")
  end)
  N.Set("lya", "foco", false)
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(Rs.Compacto() == false, "sin foco, el combate cambió la vista")
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  N.Set("lya", "foco", nil)
  A.Set("rutas.seguimientoCompleto", nil)
end)

---------------------------------------------------------------------------
-- Ajustes y Lya
---------------------------------------------------------------------------

step("Los ajustes nuevos están en Misiones y Lya los cuenta", function()
  for _, k in ipairs({ "nivelClaro", "avisoElite", "compartirMisiones", "siguienteGuia", "vueloListo" }) do
    check(A.Get("rutas." .. k) == true, "rutas." .. k .. " no viene prendido de fábrica")
  end
  if rawget(_G, "AlfaLya") then
    for _, id in ipairs({ "rutas.nivel", "rutas.compartir", "rutas.siguiente", "rutas.vuelo" }) do
      local p = ensenadas[id]
      check(p and p.modulo == "rutas" and p.pregunta ~= "" and p.respuesta ~= "", "Lya no aprendió " .. id)
    end
  end
end)

print(string.format("PRUEBA: 1.2.9 rutas, %d pasos, %d errores", pasos, #ERRORS))
