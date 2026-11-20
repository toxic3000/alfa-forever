-- Prueba de la 1.3.1, lo de Rutas (tools/prueba.py la corre con las demás prueba_*.lua):
--   1. las misiones grises sin el Codex: no se juzgan (la lista no sale, la
--      tarjeta tampoco) y «Misiones grises» carga el Codex con tu clic; una
--      gris que da un objeto raro ya no sale como «no vale la pena»;
--   2. la llegada de la flecha: «Siguiente lugar» deja de tomar el ratón al
--      empezar la pelea (PLAYER_REGEN_DISABLED llega antes del bloqueo de
--      combate: ahí InCombatLockdown todavía es false);
--   3. el mapa de tu grupo con los mapas cerrados: lo que cambia solo queda
--      pendiente y se pinta al abrir el mapa del juego o el de Alfa; el lugar
--      de cada misión se calcula una vez;
--   4. la placa de llegada: con avance que contar se queda; sin él entra,
--      se queda su rato y se desvanece; vuelve un rato corto solo si cambia
--      lo que dice (y si aparece un avance, vuelve y se queda); se ancla una
--      vez y respeta ui.reduceMotion. (Va antes del 3 en el archivo: usa llegar() del 2.)
--   5. Peligros: cada pin guarda el marco de su aparición (f = "e");
--   6. Barcos: N.Cada «rutas.barcos» solo con el mapa abierto, fuera de
--      combate, y la capa solo se publica si cambió;
--   7. «Llévame a…»: «Tranvía de …» en lugar de «Muelle de …» y los portales;
--   8. el mapa del grupo y «Compartir» preguntan a La Jauría con el nombre
--      completo («Ana Smith»), una vez por lobo.
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
local function check(cond, msg) if not cond then NOTE("1.3.1 rutas", msg) end end

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

local function pt(x, y) return { map = 1440, x = x, y = y } end

---------------------------------------------------------------------------
-- 1. Las misiones grises sin el Codex
---------------------------------------------------------------------------

step("Sin el Codex las grises no se juzgan; «Misiones grises» lo carga y la del objeto raro no sale", function()
  local Gr = Ru.Grises
  check(Gr and Gr.Lista and Gr.Abrir, "falta Grises.lua")
  -- 8131 da un objeto raro (vale la pena); 8132 no da nada.
  local cargado, llamadasCarga = false, 0
  local Cx = {
    IsLoaded = function() return cargado end,
    Load = function() llamadasCarga = llamadasCarga + 1 cargado = true return true end,
    Quest = function(q)
      if q == 8131 then return { id = 8131, title = "Gris con premio", level = 5, rewards = { 5001 } } end
      if q == 8132 then return { id = 8132, title = "Gris sin nada", level = 5, rewards = {} } end
      return nil
    end,
    Item = function(id) if id == 5001 then return { id = 5001, quality = 3 } end return nil end,
    Name = function(kind, id) if kind == "item" and id == 5001 then return "Espada azul" end return nil end,
  }
  local avisos = {}
  con(A, { Codex = Cx, QuestDB = { IsLoaded = function() return false end } }, function()
    con(Cp, { GetLogQuests = function() return { 8131, 8132 } end, IsQuestReadyForTurnIn = function() return false end,
      GetQuestLevel = function() return 5 end, IsQuestTrivial = function() return true end }, function()
      con(Ru.Cadenas, { EsGris = function(q) return q == 8131 or q == 8132, 5 end }, function()
        con(Ru, { TituloMision = function(q) return "Misión " .. q end,
          Aviso = function(t, x) avisos[#avisos + 1] = { t, x } end }, function()
          -- Sin el Codex: ni lista ni tarjeta (hoy decía que las dos no valen la pena).
          local l, motivo = Gr.Lista()
          check(l == nil and motivo == "sinDatos", "sin el Codex armó la lista de grises: " .. tostring(l and #l) .. " " .. tostring(motivo))
          check(Gr.Cuantas() == 0, "sin el Codex la tarjeta cuenta grises: " .. tostring(Gr.Cuantas()))
          check(llamadasCarga == 0, "la lista o la tarjeta cargaron el Codex (eso es solo con el clic)")
          -- El clic carga el Codex y ya se juzga: la del objeto raro no sale.
          check(Gr.Abrir(), "«Misiones grises» no abrió")
          check(llamadasCarga == 1, "«Misiones grises» no cargó el Codex")
          local v = _G.AlfaRutasGrises
          check(v and v:IsShown(), "la ventana de grises no está a la vista")
          local datos = v and v.Lista and v.Lista.datos or {}
          check(#datos == 1 and datos[1].qid == 8132, "la lista no es solo la que no da nada: " .. tostring(#datos)
            .. (datos[1] and (" " .. tostring(datos[1].qid)) or ""))
          check(Gr.Cuantas() == 1, "con el Codex la tarjeta no cuenta 1")
          if v then v:Hide() end
          -- Si el Codex no se puede cargar: un aviso con el motivo y nada más.
          cargado = false
          con(Cx, { Load = function() return false, "disabled" end }, function()
            local antes = #avisos
            check(not Gr.Abrir(), "abrió sin poder cargar el Codex")
            check(#avisos == antes + 1, "no avisó por qué no se puede")
            check(not (v and v:IsShown()), "la ventana se abrió sin el Codex")
          end)
        end)
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- 2. La llegada de la flecha al empezar la pelea
---------------------------------------------------------------------------

local Arrow = Nav and Nav.arrow

local function llegar(target, estado, vista, fn)
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
    con(E, { GetStepView = function() return vista end, GetGuide = function() return nil end }, function()
      con(A, { ArrowHidden = function() return false end }, function()
        Arrow:OnTarget(target)
        fn(function() return siguiente end)
        ahora = "travel"
        Arrow:Refresh()
        Arrow:OnTarget(nil)
        Arrow.frame:Hide()
      end)
    end)
  end)
end

step("«Siguiente lugar» no toma el ratón desde que empieza la pelea", function()
  check(Arrow and Arrow.Llegada, "falta Arrow.Llegada (motor/Alfa/Nav/Arrow.lua)")
  local T = { label = "Mata a Asaltante Branquiazul", stepIndex = 1, goalIndex = 1, spots = { {}, {} }, map = 1440, x = 50, y = 50 }
  local vista = { index = 1, goals = { { t = "kill", status = "active", progress = { cur = 4, max = 6 } } } }
  llegar(T, "search", vista, function(veces)
    local d = Arrow.Llegada()
    check(d and d.siguiente and d.clicable, "fuera de combate «Siguiente lugar» no se puede clicar")
    -- Como en el juego: el evento llega y el bloqueo todavía no (InCombatLockdown = false).
    FIRE_EVENT("PLAYER_REGEN_DISABLED")
    local c = Arrow.Llegada()
    check(c and c.siguiente and not c.clicable, "al empezar la pelea «Siguiente lugar» sigue tomando el ratón")
    check(Arrow.EnPelea and Arrow.EnPelea(), "la flecha no sabe que empezó la pelea")
    FIRE(Arrow.llegada.Siguiente, "OnClick", "LeftButton")
    check(veces() == 0, "en la pelea «Siguiente lugar» pasó de lugar")
    -- Ya con el bloqueo, el avance se pone al día y sigue sin ratón.
    con(_G, { InCombatLockdown = function() return true end }, function()
      vista.goals[1].progress.cur = 5
      FIRE_EVENT("PLAYER_XP_UPDATE")
      local c2 = Arrow.Llegada()
      check(c2 and c2.avance == "5 de 6" and not c2.clicable, "en combate la llegada no se puso al día o tomó el ratón")
    end)
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    check(Arrow.Llegada() and Arrow.Llegada().clicable, "al salir de combate «Siguiente lugar» no volvió a tomar el ratón")
    check(not (Arrow.EnPelea and Arrow.EnPelea()), "al salir de combate la flecha sigue creyendo que pelea")
    FIRE(Arrow.llegada.Siguiente, "OnClick", "LeftButton")
    check(veces() == 1, "fuera de combate «Siguiente lugar» no pasó al siguiente lugar")
  end)
end)

---------------------------------------------------------------------------
-- 4. La placa de llegada: con avance se queda, sin él se va sola
---------------------------------------------------------------------------

-- El reloj de la placa: su OnUpdate, de dt en dt, hasta completar seg.
local function pasar(seg, dt)
  dt = dt or 0.1
  local t = 0
  while t < seg - 1e-6 do
    FIRE(Arrow.llegada, "OnUpdate", dt)
    t = t + dt
  end
end

-- Cuenta las veces que la placa se vuelve a anclar.
local function contarAnclas()
  local f = Arrow.llegada
  local n = 0
  local orig = f.ClearAllPoints
  rawset(f, "ClearAllPoints", function(self, ...) n = n + 1 return orig(self, ...) end)
  return function() return n end, function() n = 0 end, function() rawset(f, "ClearAllPoints", nil) end
end

step("La placa de llegada: con avance se queda; sin avance se va sola y vuelve solo si algo cambia", function()
  check(Arrow and Arrow.Llegada and Arrow.PLACA, "falta la placa de llegada con su rato (Arrow.PLACA)")
  local P = Arrow.PLACA or { QUEDA = 6, QUEDA_CAMBIO = 3.5, SALE = 0.6 }
  -- a) Con algo que contar («Busca por aquí», «4 de 6»): se queda mientras dure.
  local T = { label = "Mata a Asaltante Branquiazul", stepIndex = 1, goalIndex = 1, spots = { {}, {} }, map = 1440, x = 50, y = 50 }
  local vista = { index = 1, goals = { { t = "kill", status = "active", progress = { cur = 4, max = 6 } } } }
  llegar(T, "search", vista, function(veces)
    check(Arrow.Llegada() ~= nil and Arrow.frame:IsMouseEnabled(), "al llegar no salió la placa")
    -- Se ancla mientras entra, y ya no: nada se vuelve a anclar en cada cuadro.
    local anclas, cero, soltar = contarAnclas()
    pasar(0.5, 0.05)
    cero()
    pasar(1, 0.05)
    check(anclas() == 0, "ya entrada, la placa se volvió a anclar " .. anclas() .. " veces en 20 cuadros")
    soltar()
    pasar(P.QUEDA + P.SALE + 3)
    local d = Arrow.Llegada()
    check(d and d.avance == "4 de 6" and not d.seVa, "con avance que contar la placa se fue")
    check(d and d.clicable, "con avance, «Siguiente lugar» dejó de funcionar")
    FIRE(Arrow.llegada.Siguiente, "OnClick", "LeftButton")
    check(veces() == 1, "«Siguiente lugar» no pasó de lugar")
  end)
  check(Arrow.frame:IsMouseEnabled(), "al irte, la flecha no volvió a tomar el ratón")
  -- b) Sin avance («Completa …»): sale entera, se queda su rato y se va sola.
  local T2 = { label = "Completa «Campamento básico: Peletería»", stepIndex = 2, goalIndex = 1, map = 1440, x = 60, y = 40 }
  local vista2 = { index = 2, goals = { { t = "complete", status = "active" } } }
  llegar(T2, "arrived", vista2, function()
    local d = Arrow.Llegada()
    check(d and d.sobre == K.Mayus("Llegaste") and d.seVa, "sin avance no salió «LLEGASTE» que se va sola")
    pasar(P.QUEDA - 1.5)
    check(Arrow.Llegada() ~= nil, "al llegar la placa duró menos que su rato (" .. P.QUEDA .. " s)")
    pasar(1.5 + P.SALE + 0.3)
    check(not Arrow.llegada:IsShown() and Arrow.Llegada() == nil, "la placa sin avance se quedó en pantalla")
    check(not Arrow.distText:IsShown() and not Arrow.ring:IsShown() and not Arrow.wolfPaw:IsShown(),
      "al irse la placa volvió la llegada de antes")
    check(not Arrow.frame:IsMouseEnabled(), "ida la placa, la flecha sigue tomando el ratón (un área invisible)")
    -- Un repintado igual, o el mismo destino otra vez, no la trae de vuelta.
    FIRE_EVENT("PLAYER_XP_UPDATE")
    Arrow.LlegadaAlDia() -- (lo que hace STEP_UPDATED del motor)
    Arrow:OnTarget(T2)
    check(Arrow.Llegada() == nil, "un repintado sin cambios volvió a mostrar la placa")
    check(not Arrow.ring:IsShown() and not Arrow.wolfPaw:IsShown() and not Arrow.distText:IsShown(),
      "el mismo destino otra vez sacó la llegada de antes")
    -- Aparece un avance: vuelve y se queda («1 de 10», con su barra).
    vista2.goals[1] = { t = "kill", status = "active", progress = { cur = 1, max = 10 } }
    FIRE_EVENT("PLAYER_XP_UPDATE")
    d = Arrow.Llegada()
    check(d and d.avance == "1 de 10" and d.barra and not d.seVa, "con el avance la placa no volvió a salir para quedarse")
    check(Arrow.frame:IsMouseEnabled(), "con la placa de vuelta, la flecha no toma el ratón")
    pasar(P.QUEDA + P.SALE + 3)
    check(Arrow.Llegada() ~= nil, "la placa con avance se fue sola")
    -- Otro paso sin avance en el mismo lugar: un rato corto y se va.
    vista2.goals[1] = { t = "complete", status = "active" }
    T2.label, T2.stepIndex = "Habla con Grunt Mojka", 3
    Arrow.LlegadaAlDia() -- (lo que hace STEP_UPDATED del motor)
    d = Arrow.Llegada()
    check(d and d.accion == "Habla con Grunt Mojka" and d.seVa, "el paso nuevo sin avance no salió o no se va")
    pasar(P.QUEDA_CAMBIO - 0.5)
    check(Arrow.Llegada() ~= nil, "el paso nuevo se fue antes de su rato corto")
    pasar(0.5 + P.SALE + 0.3)
    check(Arrow.Llegada() == nil, "el paso nuevo sin avance se quedó en pantalla")
  end)
  check(Arrow.frame:IsMouseEnabled(), "al irte, la flecha no volvió a tomar el ratón")
  -- c) Con ui.reduceMotion: ni sube, ni respira; aparece y se va.
  T2.label, T2.stepIndex = "Completa «Campamento básico: Peletería»", 2
  A.Set("ui.reduceMotion", true)
  local anclas, _, soltar = contarAnclas()
  llegar(T2, "arrived", vista2, function()
    check(Arrow.Llegada() ~= nil, "con menos movimiento no salió la placa")
    local tam = Arrow.llegada.Lobo:GetWidth()
    local igual = true
    for _ = 1, 20 do
      FIRE(Arrow.llegada, "OnUpdate", 0.05)
      if math.abs((Arrow.llegada.Lobo:GetWidth() or 0) - (tam or 0)) > 1e-6 then igual = false end
    end
    check(anclas() <= 1, "con menos movimiento la placa se movió (" .. anclas() .. " anclas)")
    check(igual, "con menos movimiento el lobo siguió respirando")
    pasar(P.QUEDA + 1)
    check(Arrow.Llegada() == nil, "con menos movimiento la placa sin avance se quedó en pantalla")
  end)
  soltar()
  A.Set("ui.reduceMotion", nil)
end)

---------------------------------------------------------------------------
-- 3. El mapa de tu grupo con los mapas cerrados
---------------------------------------------------------------------------

step("El mapa del grupo: con los mapas cerrados queda pendiente y se pinta al abrir uno", function()
  local Mg = Ru.MapaGrupo
  check(Mg and Mg.Datos, "falta MapaGrupo.lua")
  check(type(Mg.Pendiente) == "function" and type(Mg.Olvidar) == "function", "faltan MapaGrupo.Pendiente y MapaGrupo.Olvidar")
  local sets, capa, calculos = 0, nil, 0
  local enGrupo, lista, alfaAbierto = true, false, false
  local Mu = rawget(_G, "AlfaMundo") or {}
  if Mg.Olvidar then Mg.Olvidar() end
  WorldMapFrame:Hide()
  con(_G, {
    IsInGroup = function() return enGrupo end, IsInRaid = function() return false end,
    UnitExists = function(u) return u == "player" or (enGrupo and u == "party1") end,
    UnitName = function(u) if u == "party1" then return "Ana" end return "Lobato" end,
  }, function()
    con(C_QuestLog, { IsUnitOnQuest = function(u, q) return u == "party1" and q == 601 end }, function()
      con(A, { Codex = { IsLoaded = function() return true end, Quest = function(q) return { id = q } end },
        Pins = { SetLayer = function(n, p) if n == "rutas.grupo" then sets = sets + 1 capa = p end end,
          ClearLayer = function(n) if n == "rutas.grupo" then capa = false end end } }, function()
        con(Cp, { GetLogQuests = function() return { 601 } end, IsOnQuest = function(q) return q == 601 end,
          IsQuestReadyForTurnIn = function() return lista end }, function()
          con(Ru.Indice, { PasosMision = function() calculos = calculos + 1 return { objetivo = pt(40, 40), fin = pt(45, 45) } end }, function()
            con(Ru, { TituloMision = function(q) return "Misión " .. q end }, function()
              con(Mu, { ZonasALaVista = function() return alfaAbierto and {} or nil end }, function()
                -- Ana avanza su misión con los dos mapas cerrados: nada se calcula.
                FIRE_EVENT("UNIT_QUEST_LOG_CHANGED", "party1")
                RUN_TIMERS(3)
                check(calculos == 0, "con los mapas cerrados calculó los lugares (" .. calculos .. " veces)")
                check(sets == 0, "con los mapas cerrados pintó la capa")
                check(Mg.Pendiente and Mg.Pendiente(), "no quedó pendiente")
                check(N.HayTarea("rutas.mapaGrupo"), "no vigila la apertura del mapa (N.Cada «rutas.mapaGrupo»)")
                -- Abres el mapa del juego: se pinta al momento.
                WorldMapFrame:Show()
                check(sets == 1 and type(capa) == "table" and capa[1] and capa[1].x == 40, "al abrir el mapa no pintó la capa del grupo")
                check(calculos == 1, "al abrir el mapa no calculó el lugar una vez: " .. calculos)
                check(not (Mg.Pendiente and Mg.Pendiente()), "siguió pendiente después de pintar")
                check(not N.HayTarea("rutas.mapaGrupo"), "siguió vigilando después de pintar")
                -- Con el mapa abierto se pone al día, pero el lugar ya está calculado.
                FIRE_EVENT("UNIT_QUEST_LOG_CHANGED", "party1")
                RUN_TIMERS(3)
                check(sets == 2, "con el mapa abierto no se puso al día")
                check(calculos == 1, "volvió a calcular el lugar de la misma misión: " .. calculos)
                -- Lista para entregar: el pin va a la entrega (eso sí se recalcula).
                lista = true
                Mg.Pintar()
                check(calculos == 2 and capa and capa[1] and capa[1].x == 45, "lista para entregar, el pin no fue a la entrega")
                -- Al cambiar de zona se olvida lo calculado.
                FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
                Mg.Pintar()
                check(calculos == 3, "al cambiar de zona no volvió a calcular el lugar")
                WorldMapFrame:Hide()
                -- El mapa de Alfa no avisa al abrirse: el vistazo por segundo lo encuentra.
                local antes = sets
                FIRE_EVENT("UNIT_QUEST_LOG_CHANGED", "party1")
                RUN_TIMERS(3)
                check(sets == antes and Mg.Pendiente and Mg.Pendiente(), "con los mapas cerrados no quedó pendiente otra vez")
                alfaAbierto = true
                RUN_TIMERS(2)
                check(sets == antes + 1, "al abrir el mapa de Alfa no pintó la capa del grupo")
                check(not N.HayTarea("rutas.mapaGrupo"), "siguió vigilando con el mapa de Alfa abierto")
                alfaAbierto = false
                -- Dejas el grupo: la capa se quita aunque los mapas estén cerrados.
                enGrupo = false
                FIRE_EVENT("GROUP_ROSTER_UPDATE")
                RUN_TIMERS(3)
                check(capa == false, "al dejar el grupo no quitó la capa")
                check(not (Mg.Pendiente and Mg.Pendiente()) and not N.HayTarea("rutas.mapaGrupo"), "sin grupo siguió pendiente")
              end)
            end)
          end)
        end)
      end)
    end)
  end)
  WorldMapFrame:Hide()
end)

---------------------------------------------------------------------------
-- 5. Peligros: el marco Era de cada aparición (B3)
---------------------------------------------------------------------------

step("Peligros: cada pin guarda el marco de su aparición (f = \"e\" del Codex)", function()
  local Mu = NS_OF("Alfa_Mundo")
  local Pe = Mu.Peligros
  check(Pe and Pe.Indexar and Mu.Descubrir, "falta Peligros.lua")
  local capas = {}
  local npcs = {
    [9001] = { name = "Ogro élite", elite = true, level = 30, levelMax = 31, spawns = {
      { map = 1440, x = 50, y = 50, f = "e" }, { map = 1440, x = 51, y = 51, f = "e" }, -- juntas: un pin
      { map = 1440, x = 50.5, y = 50.5 },                                              -- otro marco: aparte
      { map = 1440, x = 20, y = 20 } } },
  }
  local X = { IsLoaded = function() return true end,
    Each = function(tipo, fn) if tipo == "npc" then for id in pairs(npcs) do fn(id) end end end,
    Npc = function(id) return npcs[id] end }
  Pe.Olvidar()
  con(A, { Codex = X, Pins = { SetLayer = function(n, p) capas[n] = p end, ClearLayer = function(n) capas[n] = false end } }, function()
    con(Mu.Descubrir, { Zona = function() return 1440 end }, function()
      Pe.Indexar()
      RUN_TIMERS(5)
      check(Pe.Listo(), "no armó el índice de peligros")
      Pe.Refrescar()
      local pines = capas["mundo.peligros"]
      check(type(pines) == "table" and #pines == 3, "no salieron 3 pines (uno por grupo y marco): " .. tostring(type(pines) == "table" and #pines))
      local era, vivo
      for _, p in ipairs(type(pines) == "table" and pines or {}) do
        if p.x == 50 then era = p elseif p.x == 20 then vivo = p end
      end
      check(era and era.f == "e", "el pin del Codex perdió su marco Era (f = \"e\")")
      check(vivo and vivo.f == nil, "un punto sin marco salió con marco")
    end)
  end)
  Pe.Olvidar()
end)

---------------------------------------------------------------------------
-- 6. Barcos: el reloj de Alfa y la capa solo si cambia (B6)
---------------------------------------------------------------------------

local DATOS = {
  taxi = {}, inns = {},
  transports = {
    { id = "zeppelin-orgrimmar-undercity", kind = "zeppelin", faction = 2,
      a = { name = "Orgrimmar", map = 1411, x = 50.8, y = 13.5 }, b = { name = "Undercity", map = 1420, x = 60.7, y = 58.9 } },
  },
}

step("Barcos: N.Cada con el mapa abierto, nada con el mapa cerrado y la capa solo si cambia", function()
  local Bc = Ru.Barcos
  check(Bc and Bc.Pintar, "falta Barcos.lua")
  local sets, medido = 0, false
  local X = {
    Now = function() return GetTime() end,
    NextArrival = function(kind, id, now, lado) if medido and lado == "a" then return 2000 - now, 2030 - now, true end return nil end,
    NextDeparture = function() return 175, 100, false end,
  }
  WorldMapFrame:Hide()
  con(Nav, { GetTravelData = function() return DATOS end }, function()
    con(A, { Transit = X, Pins = { SetLayer = function(n) if n == "rutas.barcos" then sets = sets + 1 end end, ClearLayer = function() end } }, function()
      check(not N.HayTarea("rutas.barcos"), "con el mapa cerrado corre el reloj de los barcos")
      WorldMapFrame:Show()
      check(sets == 1, "al abrir el mapa no puso la capa: " .. sets)
      check(N.HayTarea("rutas.barcos"), "con el mapa abierto no corre N.Cada «rutas.barcos»")
      RUN_TIMERS(3)
      check(sets == 1, "sin horario medido volvió a publicar la capa sin cambios (" .. sets .. " veces)")
      medido = true
      RUN_TIMERS(3)
      check(sets >= 3, "con la cuenta atrás no se puso al día cada segundo (" .. sets .. " veces)")
      local antes = sets
      con(_G, { InCombatLockdown = function() return true end }, function() RUN_TIMERS(2) end)
      check(sets == antes, "en combate se puso al día")
      WorldMapFrame:Hide()
      check(not N.HayTarea("rutas.barcos"), "al cerrar el mapa siguió el reloj de los barcos")
    end)
  end)
end)

---------------------------------------------------------------------------
-- 7. «Llévame a…»: el tranvía y los portales (B7)
---------------------------------------------------------------------------

step("«Llévame a…»: el tranvía no es un muelle y los portales salen", function()
  local Vj = Ru.Viaje
  check(Vj and Vj.Destinos, "falta Viaje.lua")
  local D = {
    taxi = {}, inns = {},
    transports = {
      { id = "tram-stormwind-ironforge", kind = "tram", faction = 1,
        a = { name = "Stormwind", map = 1453, x = 69.6, y = 30.3 }, b = { name = "Ironforge", map = 1455, x = 78, y = 51.4 } },
      { id = "boat-stormwind-auberdine", kind = "boat", faction = 1,
        a = { name = "Stormwind Harbor", map = 1453, x = 21.8, y = 56.9 }, b = { name = "Auberdine", map = 1439, x = 30.5, y = 40.9 } },
    },
    portals = {
      { id = "portal-ruttheran", kind = "portal", name = "Rut'theran Village", faction = 3,
        a = { name = "Darnassus", map = 1457, x = 29.1, y = 41.2 }, b = { name = "Rut'theran Village", map = 1438, x = 55.9, y = 89.7 } },
    },
  }
  -- Otra facción: Destinos se arma de nuevo (guarda lo de cada facción).
  con(_G, { UnitFactionGroup = function() return "Alliance", "Alianza" end }, function()
    con(Nav, { GetTravelData = function() return D end }, function()
      local por = {}
      for _, d in ipairs(Vj.Destinos()) do por[d.nombre] = d end
      check(por["Tranvía de Stormwind"] and por["Tranvía de Stormwind"].tipo == "tranvia", "el tranvía no salió como «Tranvía de Stormwind»")
      check(not por["Muelle de Ironforge"] and not por["Muelle de Stormwind"], "el tranvía sigue saliendo como muelle")
      check(por["Muelle de Stormwind Harbor"], "el muelle de verdad ya no sale")
      local p = por["Portal a Rut'theran Village"]
      check(p and p.tipo == "portal" and p.map == 1457, "el portal de Darnassus no salió (con su entrada)")
      check(#Vj.Buscar("portal a rut") == 1, "buscar «portal a rut» no encontró el portal")
    end)
  end)
end)

---------------------------------------------------------------------------
-- 8. Tu grupo y La Jauría: el nombre completo, una vez por lobo
---------------------------------------------------------------------------

step("El mapa del grupo y «Compartir» preguntan a La Jauría con el nombre completo, una vez por lobo", function()
  local Mg, Gr = Ru.MapaGrupo, Ru.Grupo
  local pedidos = {}
  local Ma = rawget(_G, "AlfaManada") or {}
  if Mg.Olvidar then Mg.Olvidar() end
  con(_G, {
    IsInGroup = function() return true end, IsInRaid = function() return false end, GetNumGroupMembers = function() return 3 end,
    UnitExists = function(u) return u == "player" or u == "party1" or u == "party2" end,
    -- Forever: nombre y apellido.
    UnitName = function(u)
      if u == "party1" then return "Ana", "Smith" elseif u == "party2" then return "Beto", "Ruiz" end
      return "Lobato", "Fiero"
    end,
  }, function()
    con(C_QuestLog, { IsUnitOnQuest = function(u, q) return u == "party1" and q == 601 end, IsPushableQuest = function() return true end }, function()
      con(A, { Codex = { IsLoaded = function() return true end, Quest = function(q) return { id = q } end } }, function()
        con(Cp, { GetLogQuests = function() return { 601, 602, 603 } end, IsOnQuest = function(q) return q >= 601 and q <= 603 end,
          IsQuestReadyForTurnIn = function() return false end }, function()
          con(Ru.Indice, { PasosMision = function() return { objetivo = pt(40, 40), fin = pt(45, 45) } end }, function()
            con(Ru, { TituloMision = function(q) return "Misión " .. q end }, function()
              con(Ma, { MisionesDe = function(n)
                pedidos[#pedidos + 1] = n
                if n == "Beto Ruiz" then return { [601] = true, [650] = true } end
                return nil
              end }, function()
                local d = Mg.Datos()
                check(#pedidos == 2, "el mapa del grupo preguntó a La Jauría " .. #pedidos .. " veces (una por lobo: 2)")
                local vistos = {}
                for _, n in ipairs(pedidos) do vistos[n] = true end
                check(vistos["Ana Smith"] and vistos["Beto Ruiz"], "no preguntó por el nombre completo: " .. table.concat(pedidos, ", "))
                local solo, juntas
                for _, x in ipairs(d) do
                  if x.qid == 650 then solo = x elseif x.qid == 601 then juntas = x end
                end
                check(solo and not solo.tuya and solo.quienes[1] == "Beto", "no mostró la que solo lleva Beto (por su nombre corto)")
                check(juntas and #juntas.quienes == 2, "la 601 no dice que la llevan Ana y Beto")
                -- «Compartir»: igual, una vez por lobo y con su nombre completo.
                pedidos = {}
                Gr.Reiniciar()
                local l = Gr.Compartibles(true)
                check(#pedidos == 2, "«Compartir» preguntó a La Jauría " .. #pedidos .. " veces (una por lobo: 2)")
                local beto
                for _, c in ipairs(l) do
                  if c.qid == 602 then for _, q in ipairs(c.quienes) do if q == "Beto" then beto = true end end end
                end
                check(beto, "«Compartir» no usó la lista de La Jauría para Beto Ruiz")
                Gr.Reiniciar()
              end)
            end)
          end)
        end)
      end)
    end)
  end)
  if Mg.Olvidar then Mg.Olvidar() end
end)

print(string.format("PRUEBA: 1.3.1 rutas, %d pasos, %d errores", pasos, #ERRORS))
