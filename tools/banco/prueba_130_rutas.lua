-- Prueba de la 1.3.0, lo de Rutas (tools/prueba.py la corre con las demás prueba_*.lua):
--   11. el circuito de la zona: vecino más cercano + 2-opt sin romper el orden
--       de cada misión, y la guía «Circuito de <zona>» con lo que llevas y lo
--       que puedes tomar aquí;
--   12. las grises que no valen la pena, con «Abandonar» (pregunta antes);
--   13. el botón del objeto de misión del motor, con nombre, avance y la
--       huella cuando se puede usar (sin otro botón seguro);
--   14. la cadena completa de una misión y su premio final;
--   15. las misiones de tu grupo en el mapa (quién la lleva);
--   16. «Llévame a…»: los lugares, el viaje del motor y sus tramos;
--   17. barcos y zepelines en el mapa, con su cuenta atrás.
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
local function check(cond, msg) if not cond then NOTE("1.3.0 rutas", msg) end end

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
local K = AlfaNucleo.Kit
local Ru = NS_OF("Alfa_Rutas")
local Nav = A.Nav
local Cp = A.Compat

local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do t[k] = a.v end
  if not ok then error(e) end
end

-- El mapa 1440 en el continente 1 (100 yardas por punto).
local function mundo(map, x, y)
  if map == 1440 then return 1, y * 100, x * 100 end
  return nil
end
local function pt(x, y) return { map = 1440, x = x, y = y } end

---------------------------------------------------------------------------
-- 11. El circuito de la zona
---------------------------------------------------------------------------

step("El orden del circuito: más corto que el vecino más cercano y sin romper las reglas", function()
  local Ci = Ru.Circuito
  check(Ci and Ci.Ordenar, "falta Circuito.lua")
  con(Cp, { MapToWorld = mundo }, function()
    -- En línea: 10, 20, 30 ... el vecino más cercano desde 21 va a 20, luego 30 y vuelve: 2-opt lo arregla.
    local paradas = {
      { inP = pt(10, 50), outP = pt(10, 50), deps = {} },
      { inP = pt(20, 50), outP = pt(20, 50), deps = {} },
      { inP = pt(30, 50), outP = pt(30, 50), deps = {} },
      { inP = pt(40, 50), outP = pt(40, 50), deps = { 1 } }, -- entrega de lo que se toma en 1
      { inP = pt(22, 50), outP = pt(22, 50), deps = {} },
    }
    local desde = pt(21, 50)
    local orden = Ci.Ordenar(paradas, desde)
    check(#orden == 5, "el circuito perdió paradas")
    check(Ci.Valido(orden, paradas), "el circuito entrega antes de tomar")
    local pos = {}
    for k, i in ipairs(orden) do pos[i] = k end
    check(pos[1] < pos[4], "la entrega (4) va antes de tomarla (1)")
    -- El vecino más cercano solo (sin 2-opt), para comparar.
    local greedy = { 5, 2, 1, 3, 4 }
    local cG = Ci.Costo(greedy, paradas, { c = 1, wx = 5000, wy = 2100 })
    local cC = Ci.Costo(orden, paradas, { c = 1, wx = 5000, wy = 2100 })
    check(cC <= cG + 1, "el 2-opt no dejó el camino más corto: " .. cC .. " contra " .. cG)
    -- Un caso que el vecino más cercano hace mal: zigzag.
    local zz = {}
    for i, x in ipairs({ 50, 48, 56, 44, 62, 38, 70 }) do zz[i] = { inP = pt(x, 50), outP = pt(x, 50), deps = {} } end
    local o2 = Ci.Ordenar(zz, pt(50, 50))
    local soloNN = { 1, 2, 3, 4, 5, 6, 7 }
    check(Ci.Costo(o2, zz, { c = 1, wx = 5000, wy = 5000 }) < Ci.Costo(soloNN, zz, { c = 1, wx = 5000, wy = 5000 }),
      "el 2-opt no mejoró el zigzag")
  end)
end)

step("El circuito arma la guía de la zona: lo que llevas y lo que puedes tomar aquí", function()
  local Ci, I, G = Ru.Circuito, Ru.Indice, Ru.Guias
  local instalada, abierta
  local Q = { [701] = { id = 701, title = "La que llevo" }, [702] = { id = 702, title = "Una nueva" }, [703] = { id = 703, title = "Otra zona" } }
  local function pm(q, d, o, f)
    return { aceptar = d and { t = "accept", quest = q.id, npc = 1, map = 1440, x = d.x, y = d.y } or nil,
      objetivos = { { t = "kill", quest = q.id, map = 1440, x = o.x, y = o.y } },
      entregar = { t = "turnin", quest = q.id, npc = 2, map = f.map or 1440, x = f.x, y = f.y },
      dador = d, objetivo = o, fin = f }
  end
  con(A, { PlayerPoint = function() return pt(50, 50) end, Codex = { IsLoaded = function() return true end, Quest = function(q) return Q[q] end } }, function()
    con(Cp, { MapToWorld = mundo, GetLogQuests = function() return { 701, 703 } end, IsQuestReadyForTurnIn = function() return false end,
      IsOnQuest = function(q) return q == 701 or q == 703 end, MapName = function() return "Durotar" end }, function()
      con(I, {
        CodexListo = function() return true end,
        Pedir = function(fn) fn({ lista = { { id = 702, lvl = 10 }, { id = 701, lvl = 10 } } }) end,
        Disponible = function() return true end,
        EnRegistro = function(q) return q == 701 end,
        Jugador = function() return { level = 10 } end,
        Puntos = function(e) return e.id == 702 and pt(55, 50) or nil end,
        PasosMision = function(q)
          if q.id == 701 then return pm(q, nil, pt(60, 50), pt(52, 50)) end
          if q.id == 702 then return pm(q, pt(55, 50), pt(58, 50), pt(55, 50)) end
          return pm(q, nil, { map = 1, x = 1, y = 1 }, { map = 1, x = 2, y = 2 })
        end,
      }, function()
        con(Ru.Tareas, { Lanzar = function(_, fn, fin) fin(fn(function() end)) end }, function()
          con(G, { Instalar = function(def) instalada = def return true end, Abrir = function(id) abierta = id return 1 end }, function()
            Ci.Ahora()
          end)
        end)
      end)
    end)
  end)
  check(instalada and instalada.id == G.IdEspecial("circuito"), "no instaló la guía del circuito")
  check(abierta == G.IdEspecial("circuito"), "no abrió la guía del circuito")
  check(G.Especial(G.IdEspecial("circuito")) == "circuito", "la guía del circuito no cuenta como especial")
  if instalada then
    check(instalada.title == "Circuito de Durotar", "el título no es «Circuito de Durotar»: " .. tostring(instalada.title))
    local visto, tomar, entregar = {}, nil, nil
    for k, s in ipairs(instalada.steps) do
      for _, g in ipairs(s.goals) do
        if g.quest then visto[g.quest] = true end
        if g.quest == 702 and g.t == "accept" then tomar = k end
        if g.quest == 702 and g.t == "turnin" then entregar = k end
      end
    end
    check(visto[701] and visto[702], "el circuito no trae la que llevas y la nueva")
    check(not visto[703], "metió una misión de otra zona")
    check(tomar and entregar and tomar < entregar, "la nueva se entrega antes de tomarla")
  end
  A.Set("rutas.circuito", false)
  local motivo
  Ci.Armar(function(def, m) motivo = m end)
  check(motivo == "apagado", "armó el circuito con rutas.circuito apagado")
  A.Set("rutas.circuito", nil)
end)

---------------------------------------------------------------------------
-- 12. Misiones grises
---------------------------------------------------------------------------

step("Las grises que no valen la pena, con «Abandonar» que pregunta", function()
  local Gr = Ru.Grises
  check(Gr and Gr.Lista, "falta Grises.lua")
  local abandonadas, dialogo = {}, nil
  con(Cp, { GetLogQuests = function() return { 801, 802, 803, 804 } end,
    IsQuestReadyForTurnIn = function(q) return q == 804 end }, function()
    con(Ru.Cadenas, { EsGris = function(q) return q ~= 803, 5 end }, function()
      con(Ru, { GrisValiosa = function(q) return q == 802 and "Vale la pena: da algo" or nil end,
        TituloMision = function(q) return "Misión " .. q end }, function()
        local l = Gr.Lista()
        check(#l == 1 and l[1].qid == 801, "la lista no es solo la gris sin valor (ni la valiosa, ni la de tu nivel, ni la lista para entregar)")
        check(Gr.Cuantas() == 1, "no contó 1 gris")
        con(K, { Dialogo = function(o) dialogo = o end }, function()
          con(Ru.Plan, { Abandonar = function(ids) for _, q in ipairs(ids) do abandonadas[#abandonadas + 1] = q end return #ids end }, function()
            check(Gr.Abrir(), "no abrió la ventana")
            local v = _G.AlfaRutasGrises
            check(v and v:IsShown(), "la ventana de grises no está a la vista")
            local fila = v and v.Lista.filas and v.Lista.filas[1]
            check(fila and fila.Boton, "la fila no tiene «Abandonar»")
            if fila and fila.Boton then FIRE(fila.Boton, "OnClick", "LeftButton") end
            check(dialogo and dialogo.peligro, "«Abandonar» no preguntó antes")
            check(#abandonadas == 0, "abandonó sin confirmar")
            if dialogo then dialogo.alAceptar() end
            check(abandonadas[1] == 801, "al confirmar no abandonó la misión")
            if v then v:Hide() end
          end)
        end)
        A.Set("rutas.grises", false)
        check(Gr.Cuantas() == 0, "contó grises con rutas.grises apagado")
        A.Set("rutas.grises", nil)
      end)
    end)
  end)
  con(_G, { InCombatLockdown = function() return true end }, function()
    check(Gr.Lista() == nil, "buscó grises en combate")
  end)
end)

---------------------------------------------------------------------------
-- 13. El botón del objeto de misión
---------------------------------------------------------------------------

step("El botón del objeto del motor: nombre, avance, tecla y la huella al poder usarlo", function()
  local Ob = Ru.Objeto
  check(Ob and Ob.Pintar, "falta ObjetoMision.lua")
  local b = _G.AlfaQuestItemButton
  local propio = false
  if not b then
    propio = true
    b = CreateFrame("Button", "AlfaQuestItemButton", UIParent)
    b.Label = b:CreateFontString(nil, "OVERLAY")
  end
  check(_G.AlfaPasoObjeto == nil, "Alfa hizo otro botón seguro del objeto")
  b.itemID = 9001
  b:Show()
  con(A.QoL, { CurrentStep = function() return { goals = { { t = "use", item = 9001, status = "active", progress = { cur = 2, max = 5 } } } } end }, function()
    con(Ru, { NombreObjeto = function() return "Antorcha" end }, function()
      Ob.Enganchar()
      Ob.Pintar()
      check(b.Label:GetText() == "Antorcha · 2 de 5", "la etiqueta no dice «Antorcha · 2 de 5»: " .. tostring(b.Label:GetText()))
      check(b.alfaAro ~= nil, "no puso la huella")
      con(_G, { UnitExists = function(u) return u == "target" end }, function()
        b.tint = "near"
        check(Ob.Listo(b), "al alcance y sin espera no dice que se puede usar")
        Ob.Pintar()
        check(b.alfaAro:IsShown(), "la huella no salió al poder usarlo")
        b.tint = "far"
        check(not Ob.Listo(b), "lejos dice que se puede usar")
      end)
      con(_G, { GetBindingKey = function(k) return k == "CLICK AlfaQuestItemButton:LeftButton" and "F" or nil end }, function()
        check(Ob.Tecla() == "F", "no leyó la tecla del botón: " .. tostring(Ob.Tecla()))
      end)
      A.Set("rutas.objetoBoton", false)
      Ob.Pintar()
      check((b.Label:GetText() or "") == "", "con rutas.objetoBoton apagado siguió la etiqueta")
      A.Set("rutas.objetoBoton", nil)
    end)
  end)
  b.itemID, b.tint = nil, nil
  if propio then b:Hide() end
end)

---------------------------------------------------------------------------
-- 14. La cadena completa
---------------------------------------------------------------------------

step("La cadena completa: antes, la que miras, lo que sigue y el premio final", function()
  local Ca = Ru.Cadena
  check(Ca and Ca.De, "falta Cadena.lua")
  local Q = {
    [901] = { id = 901, level = 10 },
    [902] = { id = 902, level = 11, pre = { 901 } },
    [903] = { id = 903, level = 12, pre = { 902 } },
    [904] = { id = 904, level = 13, pre = { 903 }, rewards = { 5001 }, choices = { 5002 } },
  }
  local SIG = { [902] = { 903 }, [903] = { 904 } }
  con(A, { Codex = { IsLoaded = function() return true end, Quest = function(q) return Q[q] end, Load = function() return true end } }, function()
    con(Cp, { IsQuestCompleted = function(q) return q == 901 end, IsOnQuest = function(q) return q == 902 end }, function()
      con(Ru.Cadenas, { Siguientes = function(q) return SIG[q] or {} end }, function()
        con(Ru, { TituloMision = function(q) return "M" .. q end, NombreObjeto = function(i) return "Obj" .. i end }, function()
          local d = Ca.De(903)
          check(d and #d.lista == 4, "la cadena no tiene sus 4 misiones")
          if d then
            check(d.lista[1].qid == 901 and d.lista[1].estado == "hecha", "la primera no sale hecha")
            check(d.lista[2].estado == "llevas", "la que llevas no sale como tuya")
            check(d.lista[3].estado == "esta", "la que miras no sale marcada")
            check(d.lista[4].estado == "falta" and d.final == 904, "el final no es la 904")
            check(Ca.TextoPremio(d) == "Premio final: Obj5001, Obj5002", "el premio final no es el de la última: " .. Ca.TextoPremio(d))
          end
          con(Ru.Indice, { CodexListo = function() return true end }, function()
            check(Ca.Abrir(903), "no abrió la ventana de la cadena")
          end)
          local v = _G.AlfaRutasCadena
          check(v and v:IsShown() and #v.Lista.datos == 4, "la ventana no muestra la cadena")
          if v then v:Hide() end
          A.Set("rutas.cadenaCompleta", false)
          check(not Ca.Abrir(903), "abrió la cadena con rutas.cadenaCompleta apagado")
          A.Set("rutas.cadenaCompleta", nil)
        end)
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- 15. Las misiones de tu grupo en el mapa
---------------------------------------------------------------------------

step("Las misiones de tu grupo en el mapa, con quién la lleva", function()
  local Mg = Ru.MapaGrupo
  check(Mg and Mg.Datos, "falta MapaGrupo.lua")
  local capas = {}
  con(_G, {
    IsInGroup = function() return true end, IsInRaid = function() return false end,
    UnitExists = function(u) return u == "party1" or u == "party2" end,
    UnitName = function(u) return u == "party1" and "Ana" or "Beto" end,
  }, function()
    con(C_QuestLog, { IsUnitOnQuest = function(u, q) return (u == "party1" and q == 601) or (u == "party2" and q == 601) end }, function()
      con(A, { Codex = { IsLoaded = function() return true end, Quest = function(q) return { id = q } end },
        Pins = { SetLayer = function(n, p) capas[n] = p end, ClearLayer = function(n) capas[n] = false end } }, function()
        con(Cp, { GetLogQuests = function() return { 601, 602 } end, IsOnQuest = function(q) return q == 601 or q == 602 end,
          IsQuestReadyForTurnIn = function() return false end }, function()
          con(Ru.Indice, { PasosMision = function(q) return { objetivo = pt(40, 40), fin = pt(45, 45) } end }, function()
            con(Ru, { TituloMision = function(q) return "Misión " .. q end }, function()
              local d = Mg.Datos()
              check(#d == 1 and d[1].qid == 601, "no vio la misión que lleva el grupo (y la 602 nadie)")
              check(d[1] and #d[1].quienes == 2 and d[1].quienes[1] == "Ana", "no dice quién la lleva")
              check(d[1] and d[1].p.x == 40, "el pin no va donde falta")
              -- Con La Jauría: lo que lleva Beto y tú no.
              con(AlfaManada or {}, { MisionesDe = function(n) if n == "Beto" then return { [601] = true, [650] = true } end return { [601] = true } end }, function()
                local d2 = Mg.Datos()
                local solo
                for _, x in ipairs(d2) do if x.qid == 650 then solo = x end end
                check(solo and not solo.tuya and solo.quienes[1] == "Beto", "no mostró la que solo lleva Beto")
              end)
              Mg.Pintar()
              check(type(capas["rutas.grupo"]) == "table" and capas["rutas.grupo"][1].badge == "2", "no puso el pin con «2»")
              con(_G, { InCombatLockdown = function() return true end }, function()
                check(#Mg.Datos() == 0, "buscó en combate")
              end)
              A.Set("rutas.mapaGrupo", false)
              check(#Mg.Datos() == 0, "con rutas.mapaGrupo apagado siguió")
              A.Set("rutas.mapaGrupo", nil)
            end)
          end)
        end)
      end)
    end)
  end)
  check(#Mg.Datos() == 0, "solo, sin grupo, mostró misiones de grupo")
end)

---------------------------------------------------------------------------
-- 16. Llévame a…
---------------------------------------------------------------------------

local DATOS = {
  taxi = {
    { id = 23, name = "Orgrimmar, Durotar", map = 1454, x = 45, y = 63, faction = 2 },
    { id = 2, name = "Stormwind, Elwynn", map = 1453, x = 66, y = 62, faction = 1 },
    { id = 99, name = "Nighthaven", map = 1450, x = 1, y = 1, faction = 3, class = "DRUID" },
  },
  inns = { { name = "Razor Hill", map = 1411, x = 51, y = 41 } },
  transports = {
    { id = "zeppelin-orgrimmar-undercity", kind = "zeppelin", faction = 2,
      a = { name = "Orgrimmar", map = 1411, x = 50.8, y = 13.5 }, b = { name = "Undercity", map = 1420, x = 60.7, y = 58.9 } },
    { id = "boat-menethil-theramore", kind = "boat", faction = 1,
      a = { name = "Menethil Harbor", map = 1437, x = 4.7, y = 63.8 }, b = { name = "Theramore", map = 1445, x = 71.7, y = 56.7 } },
  },
}

step("«Llévame a…»: los lugares de tu facción, el viaje y sus tramos", function()
  local Vj = Ru.Viaje
  check(Vj and Vj.Ir, "falta Viaje.lua")
  local puesto, viaje
  local T = { id = "t" }
  con(Nav, {
    GetTravelData = function() return DATOS end,
    SetTarget = function(map, x, y, label) puesto = { map = map, x = x, label = label } return T end,
    StartTrip = function(t, n, l) viaje = { t = t, l = l } end,
    GetTarget = function() return puesto and T or nil end,
    GetRoute = function() return { { kind = "walk", label = "Camina al maestro de vuelo", seconds = 60 },
      { kind = "fly", label = "Vuela a Orgrimmar", seconds = 180 } }, 1 end,
  }, function()
    local l = Vj.Destinos()
    local nombres = {}
    for _, d in ipairs(l) do nombres[d.nombre] = d end
    check(nombres["Orgrimmar, Durotar"], "no está el vuelo de tu facción")
    check(not nombres["Stormwind, Elwynn"], "salió un vuelo de la otra facción")
    check(not nombres["Nighthaven"], "salió el vuelo de una sola clase")
    check(nombres["Posada de Razor Hill"], "no está la posada")
    check(nombres["Torre de zepelines de Orgrimmar"] and not nombres["Muelle de Menethil Harbor"], "los muelles no son los de tu facción")
    check(#Vj.Buscar("orgri") >= 2, "buscar «orgri» no encontró Orgrimmar")
    check(Vj.Ir(nombres["Orgrimmar, Durotar"]), "no empezó el viaje")
    check(puesto and puesto.x == 45 and puesto.label == "Orgrimmar, Durotar", "la flecha no apunta al destino")
    check(viaje and viaje.t == T and viaje.l == "Llévame a...", "no empezó el viaje del motor")
    local p = Vj.Pasos()
    check(p and #p == 2 and p[2].texto == "Vuela a Orgrimmar" and p[1].actual, "los tramos no son los del motor")
    check(Vj.Abrir(), "no abrió la ventana")
    local v = _G.AlfaRutasLlevame
    check(v and v:IsShown() and v.modo == "pasos" and #v.Lista.datos == 2, "la ventana no muestra los tramos del viaje")
    if v then v:Hide() end
  end)
  A.Set("rutas.llevame", false)
  check(not Vj.Ir({ map = 1, x = 1, y = 1 }), "viajó con rutas.llevame apagado")
  A.Set("rutas.llevame", nil)
end)

---------------------------------------------------------------------------
-- 17. Barcos y zepelines en el mapa
---------------------------------------------------------------------------

step("Barcos y zepelines en el mapa, con su cuenta atrás", function()
  local Bc = Ru.Barcos
  check(Bc and Bc.Lista, "falta Barcos.lua")
  local capas = {}
  local X = {
    Now = function() return 1000 end,
    NextArrival = function(kind, id, now, lado) if lado == "a" then return 80, 110, true end return nil end,
    NextDeparture = function() return 175, 100, false end,
  }
  con(Nav, { GetTravelData = function() return DATOS end }, function()
    con(A, { Transit = X, Pins = { SetLayer = function(n, p) capas[n] = p end, ClearLayer = function(n) capas[n] = false end } }, function()
      local l = Bc.Lista()
      check(#l == 2, "no salieron los dos lados del zepelín de tu facción (y nada de la otra)")
      local a, b
      for _, h in ipairs(l) do if h.lado == "a" then a = h else b = h end end
      check(a and a.segundos == 80 and a.texto:find("1 min 20 s", 1, true), "1.3.7: el lado medido no dice «1 min 20 s»: " .. tostring(a and a.texto))
      check(b and not b.segundos and b.texto:find("unos 3 min", 1, true), "sin medir no dice la espera de siempre: " .. tostring(b and b.texto))
      local pines = Bc.Pines()
      check(pines[1] and pines[1].icon == "map:zeppelin", "el pin no es de zepelín")
      local conCuenta
      -- 1.3.2: con más de un minuto, en minutos («2 min»); el texto exacto va en el cuadro del ratón.
      for _, p in ipairs(pines) do if p.badge == "2 min" then conCuenta = p end end
      check(conCuenta, "ningún pin lleva la cuenta atrás en minutos")
      WorldMapFrame:Show()
      Bc.Pintar()
      check(type(capas["rutas.barcos"]) == "table", "con el mapa abierto no puso la capa")
      WorldMapFrame:Hide()
      Bc.Pintar()
      check(capas["rutas.barcos"] == false, "con el mapa cerrado siguió la capa")
      A.Set("rutas.horarios", false)
      WorldMapFrame:Show()
      Bc.Pintar()
      check(capas["rutas.barcos"] == false, "con rutas.horarios apagado puso la capa")
      WorldMapFrame:Hide()
      A.Set("rutas.horarios", nil)
    end)
  end)
end)

---------------------------------------------------------------------------
-- Ajustes y Lya
---------------------------------------------------------------------------

step("Los ajustes nuevos vienen prendidos y Lya los cuenta", function()
  for _, k in ipairs({ "circuito", "grises", "objetoBoton", "cadenaCompleta", "mapaGrupo", "llevame", "horarios" }) do
    check(A.Get("rutas." .. k) == true, "rutas." .. k .. " no viene prendido de fábrica")
  end
  if rawget(_G, "AlfaLya") then
    for _, id in ipairs({ "rutas.circuito", "rutas.grises", "rutas.cadena", "rutas.llevame", "rutas.barcos" }) do
      local p = ensenadas[id]
      check(p and p.modulo == "rutas" and p.pregunta ~= "" and p.respuesta ~= "", "Lya no aprendió " .. id)
    end
  end
  for _, f in ipairs({ "Circuito", "Grises", "AbrirGrises", "Cadena", "VerCadena", "Llevame", "AbrirLlevame", "Pasos", "Horarios" }) do
    check(type(AlfaRuta[f]) == "function", "falta AlfaRuta." .. f)
  end
  check(BINDING_NAME_ALFA_RUTAS_LLEVAME ~= nil, "falta el nombre de la tecla de «Llévame a…»")
end)

print(string.format("PRUEBA: 1.3.0 rutas, %d pasos, %d errores", pasos, #ERRORS))
