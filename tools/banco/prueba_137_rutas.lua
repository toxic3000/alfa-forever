-- Prueba de la 1.3.7, la ruta en orden (tools/prueba.py la corre con las demás prueba_*.lua):
--   1. plurales y tiempos: N.Plural, M.Plural y N.Duracion («1 h», «15 min»);
--   2. la guía con pasos omitidos no está «terminada»; terminada, la página
--      Ruta dice «¡Terminaste!» y no «Faltan 0 pasos»; «Seguir con » nunca
--      vacío; «Recuperar lo omitido»;
--   3. la Biblioteca: «Guías con esta misión» filtra de verdad, recientes,
--      favoritas, el detalle y el estado de cada guía;
--   4. la Vuelta a entregar cuenta igual al ofrecerla y al empezarla, dice
--      cuáles quedaron fuera, no se ofrece si ya entregas, se guarda para
--      /reload y suma la misión que terminas a medio camino;
--   5. el aviso de nivel: la barra hacia la meta y «unos N jabalíes»;
--   6. las notas en inglés se esconden también en francés y en ruso;
--   7. el ritmo no cuenta el vuelo; las capitales cuentan sus misiones;
--      la siguiente guía, solo de tu nivel;
--   8. el menú de una meta: Llévame, Ver en el mapa, Omitir con Deshacer;
--   9. «Ya llegaste» cuando la flecha lo dice; la flecha dice «1 h 13 min».
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
local function check(cond, msg) if not cond then NOTE("1.3.7 rutas", msg) end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local A = AlfaNucleo.A
local N = AlfaNucleo
local K = AlfaNucleo.Kit
local Ru = NS_OF("Alfa_Rutas")
local E = A.Engine
local Nav = A.Nav
local Rs = Ru.Rastreador

local NADA = {}
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do
    antes[k] = { v = rawget(t, k) }
    if v == NADA then rawset(t, k, nil) else rawset(t, k, v) end
  end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(t, k, a.v) end
  if not ok then error(e, 0) end
end

-- Los avisos de la ruta, guardados para mirarlos.
local avisos = {}
local function conAvisos(fn)
  avisos = {}
  con(K, { Aviso = function(o) avisos[#avisos + 1] = o return {} end }, fn)
end
local function ultimo() return avisos[#avisos] end

---------------------------------------------------------------------------
-- 1. Plurales y tiempos
---------------------------------------------------------------------------

step("Plurales y tiempos como en todo Alfa", function()
  check(N.Plural(1, "%d misión", "%d misiones") == "1 misión", "N.Plural(1) no dice «1 misión»")
  check(N.Plural(3, "%d misión", "%d misiones") == "3 misiones", "N.Plural(3) no dice «3 misiones»")
  check(Ru.Plural(0, "%d paso", "%d pasos") == "0 pasos", "M.Plural(0) no dice «0 pasos»")
  check(N.Duracion(3600) == "1 h", "una hora no dice «1 h»: " .. N.Duracion(3600))
  check(N.Duracion(900) == "15 min", "15 minutos no dicen «15 min»: " .. N.Duracion(900))
  check(N.Duracion(3900) == "1 h 05 min", "65 minutos: " .. N.Duracion(3900))
  check(N.Duracion(250) == "4 min 10 s", "250 s: " .. N.Duracion(250))
  check(N.Duracion(1510, true) == "25 min", "redondo, 25 min: " .. N.Duracion(1510, true))
  check(N.Duracion(10, true) == "1 min", "redondo, menos de un minuto: " .. N.Duracion(10, true))
  check(Ru.Minutos(4380) == "1 h 13 min", "M.Minutos(73 min): " .. Ru.Minutos(4380))
  check(Ru.Quedaron(1) == "Llegaste al final; quedó 1 paso sin hacer.", "«quedaron 1 pasos»: " .. Ru.Quedaron(1))
  check(Ru.Quedaron(3) == "Llegaste al final; quedaron 3 pasos sin hacer.", "3 pasos: " .. Ru.Quedaron(3))
end)

---------------------------------------------------------------------------
-- 2. La guía terminada de verdad
---------------------------------------------------------------------------

local GUIA = { id = "prueba-137", title = "Durotar", steps = { {}, {}, {} } }
local vistas
local function motorFalso(extra)
  local t = {
    GetLiveStep = function() return nil end,
    GetGuide = function() return GUIA end,
    GetStepView = function(i) return vistas[i] end,
    GetProgress = function() return 3, 3 end,
    SkippedOut = function() return nil end,
    GetRouteChoice = function() return nil end,
    NextGuide = function() return nil end,
  }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end

step("Con pasos omitidos la guía no está terminada; terminada, «¡Terminaste!» y nunca «Seguir con »", function()
  vistas = { { status = "done" }, { status = "done", skipped = true, title = "Mata jabalíes" }, { status = "done" } }
  con(E, motorFalso({ Unskip = function(i) vistas[i].skipped = nil return true end }), function()
    check(AlfaRuta.GuiaTerminada() == false, "con un paso omitido dice que la guía terminó")
    local c = AlfaRuta.Cierre()
    check(c and not c.terminada and c.omitidos == 1, "el cierre no cuenta el omitido")
    check(c and c.recuperar and c.recuperar.step == 2, "no ofrece recuperar el paso omitido")
    conAvisos(function()
      con(Ru, { Empezar = function() end }, function()
        check(AlfaRuta.Recuperar(c), "«Recuperar lo omitido» no lo recuperó")
      end)
    end)
    check(vistas[2].skipped == nil, "el paso sigue omitido")
    check(AlfaRuta.GuiaTerminada() == true, "con todo hecho no dice que terminó")
    -- La página Ruta: «¡Terminaste!», no «Faltan 0 pasos».
    con(Ru.Siguiente, { Proponer = function() return { id = "otra", nombre = "Los Baldíos (10-20)" } end }, function()
      local d = Ru.AccionPagina and Ru.AccionPagina()
      check(d and d.titulo == "¡Terminaste!", "la página Ruta no dice «¡Terminaste!»: " .. tostring(d and d.titulo))
      check(d and not ((d.progreso and d.progreso.texto or ""):find("Faltan 0", 1, true)), "la página Ruta dice «Faltan 0 pasos»")
      check(d and d.accion and d.accion.texto == "Seguir con Los Baldíos (10-20)", "no ofrece «Seguir con X»: " .. tostring(d and d.accion and d.accion.texto))
    end)
  end)
  -- «Seguir con » vacío: nunca.
  check(Ru.SeguirCon(nil) == "Seguir con la que sigue" and Ru.SeguirCon("") == "Seguir con la que sigue", "«Seguir con » sale vacío")
  check(Ru.NombreGuia("no-existe-137") == nil, "el nombre de una guía que no existe no es nil")
end)

step("El camino que se abre en dos: «Elegir mi camino»", function()
  vistas = { { status = "done" }, { status = "done" }, { status = "done" } }
  local ofrecida = false
  con(E, motorFalso({ GetRouteChoice = function() return { options = { "a", "b" } } end, OfferRouteChoice = function() ofrecida = true end }), function()
    local c = AlfaRuta.Cierre()
    check(c and c.elegir, "con dos caminos no ofrece elegir")
    check(AlfaRuta.TextoCierre(c) == "Elegir mi camino", "el botón no dice «Elegir mi camino»")
    AlfaRuta.SeguirCierre(c)
    check(ofrecida, "«Elegir mi camino» no abrió la elección")
  end)
end)

---------------------------------------------------------------------------
-- 3. La Biblioteca
---------------------------------------------------------------------------

step("La Biblioteca: «Guías con esta misión», recientes, favoritas y el detalle", function()
  local B = Ru.Biblioteca
  local G = A.Guides
  -- Las guías que son para este personaje (las que la Biblioteca enseña).
  B.Abrir({ categoria = "todas" })
  local _, lista = B.DatosBanco()
  check(#lista > 2, "el banco no tiene guías para probar")
  local una = lista[1] and lista[1].id
  con(G, { QuestGuides = function(k, q) if k == "q" and q == 4242 then return { una } end return nil end }, function()
    B.Abrir({ mision = 4242 })
    local reco, out = B.DatosBanco()
    check(reco == nil, "con el filtro de la misión sale la recomendada")
    check(#out == 1 and out[1].id == una, "«Guías con esta misión» no filtra: " .. #out .. " guías")
  end)
  -- Recientes y favoritas.
  B.Reciente(lista[2].id)
  B.Favorita(lista[3].id, true)
  check(B.EsFavorita(lista[3].id), "no quedó en favoritas")
  B.Abrir({ categoria = "recientes" })
  local _, rec = B.DatosBanco()
  check(#rec >= 1 and rec[1].id == lista[2].id, "«Recientes» no trae la última que abriste")
  B.Abrir({ categoria = "favoritas" })
  local _, fav = B.DatosBanco()
  local hay = false
  for _, g in ipairs(fav) do if g.id == lista[3].id then hay = true end end
  check(hay, "«Favoritas» no trae tu favorita")
  -- El detalle, sin cargar la guía.
  local d = B.Detalle(lista[3].id)
  check(d and d.v:IsShown(), "«Ver detalle» no abrió")
  local lineas = B.LineasDetalle(lista[3])
  check(#lineas >= 1, "el detalle no dice nada de la guía")
  d.v:Cerrar()
  B.Favorita(lista[3].id, false)
  -- El estado de cada guía.
  con(E, { GetGuideState = function(id) if id == "x1" then return "done" end return "started", 11, 80 end }, function()
    check(B.EstadoDe({ id = "x1" }) == "Terminada", "una guía hecha no dice «Terminada»")
    check(B.EstadoDe({ id = "x2" }) == "Paso 12 de 80", "una guía empezada no dice «Paso 12 de 80»: " .. tostring(B.EstadoDe({ id = "x2" })))
  end)
  -- Tiempo estimado por guía.
  con(Ru.Hora, { EstimadoPasos = function(n) return n * 2 end }, function()
    check(B.TiempoDe({ id = "t", stepCount = 60 }) == "≈ 2 h a tu ritmo", "el tiempo por guía: " .. tostring(B.TiempoDe({ id = "t", stepCount = 60 })))
  end)
  if B.Visible() then B.Abrir({ alternar = true }) end
end)

---------------------------------------------------------------------------
-- 4. La Vuelta a entregar
---------------------------------------------------------------------------

local Vt = Ru.Vuelta
local Cp = A.Compat

step("La Vuelta: cuenta igual, dice cuáles quedaron fuera, se guarda y suma", function()
  Vt.Reiniciar()
  local listas = { [101] = true, [102] = true }
  local enLog = { 101, 102 }
  local puntos = { [101] = { map = 1411, x = 50, y = 50, id = 3143, name = "Gornek" } } -- la 102: no se sabe dónde
  local Cr = Ru.Cerrar
  con(Cp, { GetLogQuests = function() return enLog end, IsQuestReadyForTurnIn = function(q) return listas[q] == true end,
    IsOnQuest = function(q) for _, x in ipairs(enLog) do if x == q then return true end end return false end }, function()
    con(Cr, { ListasAhora = function() local n = 0 for _, q in ipairs(enLog) do if listas[q] then n = n + 1 end end return n end }, function()
      con(Vt, { Listas = function() local o = {} for _, q in ipairs(enLog) do if listas[q] then o[#o + 1] = { qid = q, titulo = "Misión " .. q, p = puntos[q] } end end return o end }, function()
        con(Nav, { SetTarget = function() return {} end, StartTrip = function() end }, function()
          con(Ru, { Empezar = function() end }, function()
            local ofrece = Vt.Aviso()
            check(ofrece and ofrece.uno, "con 2 listas no ofrece la vuelta")
            conAvisos(function()
              local ok = Vt.Empezar()
              check(ok, "la ofreció y al empezarla dijo que no (la 102 no tiene lugar de entrega)")
              local t = ultimo() and ultimo().texto or ""
              check(t:find("Misión 102", 1, true), "no dice cuál quedó fuera: " .. t)
            end)
            -- Se guarda para /reload.
            local g = Ru.Personaje().vuelta
            check(type(g) == "table" and #g.paradas == 1, "la vuelta no se guardó")
            -- Terminas otra a medio camino: se suma.
            enLog[#enLog + 1] = 103
            listas[103] = true
            puntos[103] = { map = 1411, x = 60, y = 40, id = 3144, name = "Thrall" }
            conAvisos(function() check(Vt.Sumar() == 1, "la que terminaste a medio camino no se sumó") end)
            check(Vt.Estado().total == 2, "la vuelta no tiene la parada nueva")
            -- /reload: vuelve con lo de antes.
            Vt.Reiniciar()
            Ru.Personaje().vuelta = g
            g.paradas[#g.paradas + 1] = { clave = "npc:3144", p = puntos[103], nombre = "Thrall", misiones = { 103 }, titulos = { "Misión 103" } }
            check(Vt.Retomar(), "después de /reload la vuelta no siguió")
            check(Vt.Estado() and Vt.Estado().total == 2, "la vuelta retomada no trae sus paradas")
            Vt.Cancelar(true)
            check(Ru.Personaje().vuelta == nil, "al dejarla quedó guardada")
          end)
        end)
      end)
      -- Ya entregando con «Cerrar mis misiones»: no se ofrece otra vez.
      con(E, { GetGuide = function() return { id = "mis-rutas/liberar" } end }, function()
        check(Vt.Entregando(), "con «Cerrar mis misiones» abierta no sabe que ya entregas")
        check(Vt.Aviso() == nil, "la Vuelta se ofrece aunque ya estás entregando")
      end)
    end)
  end)
  -- Con menos de 2 listas, el mismo número en todos lados.
  check(Vt.MIN == 2, "el mínimo de la vuelta no es 2")
  Vt.Reiniciar()
end)

---------------------------------------------------------------------------
-- 5. El aviso de nivel
---------------------------------------------------------------------------

step("El aviso de nivel: la barra hacia la meta y «unos N»", function()
  local Nv = Ru.Nivel
  local Lv = A.Levels
  con(Lv, { LEVEL_XP = setmetatable({}, { __index = function() return 1000 end }) }, function()
    -- Nivel 10 con 500 de 1000; la meta es el 12: lo hecho 500 de 2000.
    local b = Nv.Barra(1500, 500, 1000, 10, 12)
    check(b and math.abs(b - 0.25) < 0.01, "la barra no va hacia la meta: " .. tostring(b))
    local b1 = Nv.Barra(500, 500, 1000, 10, 11)
    check(b1 and math.abs(b1 - 0.5) < 0.01, "con la meta al siguiente nivel la barra cambió: " .. tostring(b1))
  end)
  local v = { index = 4, goals = { { t = "level", status = "active", xpLeft = 1400, subject = "12" } } }
  con(Nv, { DondeRinde = function() return { nombre = "Jabalí", nivel = 10, xp = 100, titulo = "La caza", p = {} } end,
    XPPorHora = function() return 3360 end }, function()
    local d = Nv.Aviso(v, 4)
    check(d and d.texto and d.texto:find("unos 14 Jabalí", 1, true), "no dice «unos 14 Jabalí»: " .. tostring(d and d.texto))
  end)
end)

---------------------------------------------------------------------------
-- 6. Notas en inglés en otros idiomas
---------------------------------------------------------------------------

step("Las notas en inglés se esconden también en francés y en ruso", function()
  local function en(loc, fn)
    con(_G, { AlfaIdioma = function() return loc end }, function()
      Rs.OlvidarIdioma()
      fn()
    end)
    Rs.OlvidarIdioma()
  end
  en("frFR", function()
    check(Rs.SinTraducir("Follow the road north to the tower"), "en francés no esconde la nota en inglés")
    check(not Rs.SinTraducir("Suis le chemin vers la tour au nord"), "en francés esconde una nota en francés")
  end)
  en("ruRU", function()
    check(Rs.SinTraducir("Follow the road north to the tower"), "en ruso no esconde la nota en inglés")
    check(not Rs.SinTraducir("Идите по дороге на север к башне"), "en ruso esconde una nota en ruso")
  end)
  en("enUS", function() check(not Rs.SinTraducir("Follow the road north"), "en inglés esconde las notas") end)
end)

---------------------------------------------------------------------------
-- 7. El ritmo, las capitales y la siguiente guía
---------------------------------------------------------------------------

step("El ritmo no cuenta el vuelo; las capitales; la siguiente, de tu nivel", function()
  local H = Ru.Hora
  local antes = H.Pausa()
  H.Poner("taxi", true)
  RUN_TIMERS(1)
  H.Poner("taxi", false)
  check(H.Pausa() >= antes, "el tiempo en vuelo no se apartó")
  -- Las capitales: el encabezado del registro es otro nombre de aquí.
  con(_G, { GetRealZoneText = function() return "Orgrimmar" end, GetZoneText = function() return "Valle de la Fuerza" end }, function()
    local aqui = H.NombresDeAqui()
    check(aqui[Ru.Plegar("Orgrimmar")] and aqui[Ru.Plegar("Valle de la Fuerza")], "no reconoce los nombres de la capital")
  end)
  -- La siguiente guía, solo de tu nivel.
  local Sg = Ru.Siguiente
  check(Sg.DeTuNivel({ minLevel = 10, maxLevel = 20 }, 15), "una guía de tu nivel no vale")
  check(not Sg.DeTuNivel({ minLevel = 30, maxLevel = 40 }, 18), "una guía de nivel 30 vale para alguien de 18")
  check(Sg.DeTuNivel({ minLevel = 19, maxLevel = 25 }, 18), "una guía que empieza en tu siguiente nivel no vale")
end)

---------------------------------------------------------------------------
-- 8. El menú de una meta
---------------------------------------------------------------------------

step("El menú de una meta: Llévame, Ver en el mapa y Omitir con Deshacer", function()
  local opciones
  con(K, { Menu = function(_, op) opciones = op end }, function()
    -- Una meta sin misión (ir a un lugar).
    Rs.MenuMeta({ alfaMeta = { t = "goto", index = 1, status = "active", text = "Ve a la torre" }, alfaPaso = 3 })
    local textos = {}
    for _, o in ipairs(opciones or {}) do textos[o.texto or ""] = o end
    check(textos["Llévame"], "una meta sin misión no tiene «Llévame»")
    check(textos["Ver el camino en el mapa"], "una meta sin misión no tiene «Ver el camino en el mapa»")
    check(textos["Omitir este paso"], "una meta sin misión no tiene «Omitir»")
  end)
  -- Omitir una misión: con «Deshacer».
  local omitida
  con(E, { SkipQuest = function(q, on) omitida = on and q or nil return true end }, function()
    conAvisos(function()
      Rs.OmitirMision(777, "La caza")
      local o = ultimo()
      check(o and o.accion and o.accion.texto == "Deshacer", "omitir una misión no ofrece «Deshacer»")
      check(omitida == 777, "no la omitió")
      if o and o.accion then o.accion.alClic() end
      check(omitida == nil, "«Deshacer» no la devolvió")
    end)
  end)
end)

---------------------------------------------------------------------------
-- 9. «Ya llegaste» como la flecha
---------------------------------------------------------------------------

step("«Ya llegaste» cuando la flecha lo dice", function()
  local T = { label = "La torre", map = 1411, x = 50, y = 50, r = 8 }
  local modo = "travel"
  con(Nav, { GetTarget = function() return T end, TargetOffset = function() return 5, 0 end, arrow = { GetMode = function() return modo end } }, function()
    con(A, { Compat = { IsInInstance = function() return false end, IsOnTaxi = function() return false end } }, function()
      local t = AlfaRuta.Distancia()
      check(t ~= "Ya llegaste", "dice «Ya llegaste» y la flecha sigue de viaje")
      modo = "arrived"
      check(AlfaRuta.Distancia() == "Ya llegaste", "la flecha llegó y no dice «Ya llegaste»")
    end)
  end)
end)

print(("PRUEBA: 1.3.7 rutas, %d pasos, %d errores"):format(pasos, #ERRORS))
