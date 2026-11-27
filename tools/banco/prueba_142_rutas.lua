-- Prueba de la 1.4.2: rutas, misiones y la flecha (10 mejoras).
--
-- Lo que se pidió: «mejoras que se noten al jugar». Cada paso es una de ellas
-- y falla con el código de antes (no existía):
--   1. «Alfa: llévame» en el menú del registro de misiones del juego: la flecha
--      va al objetivo que te falta (no al que ya hiciste) o a quien la recibe.
--   2. «La misión más cerca»: de todo tu registro, lo más cerca; registro vacío
--      con salida («Recoger misiones»).
--   3. «¡Lista para entregar!»: una misión que tu guía no entrega, al quedar
--      lista, avisa con «Llévame a entregarla»; las de tu guía no.
--   4. Misiones nuevas al subir de nivel (sin guía): aviso, ventana con la más
--      cerca primero y la flecha a quien la da; con guía, nada.
--   5. «Tienes misiones aquí» al volver a una zona (una vez por zona).
--   6. Clic derecho en la flecha: su menú (y «Esconder la flecha» con «Mostrarla»).
--   7. «Llévame a…» recuerda tus destinos recientes arriba.
--   8. «Llévame a…»: Enter en el buscador te lleva al primero.
--   9. Teclas nuevas: La misión más cerca, Vuelta a entregar, Cerrar mis misiones.
--  10. El viaje sigue después de /reload (y se olvida al llegar).
PRUEBA_AREA("1.4.2 rutas")

-- El menú del registro del juego (Menu.ModifyMenu): se anota quién se engancha.
local REGISTRADOS = {}
Menu = Menu or {}
local modificarViejo = Menu.ModifyMenu
Menu.ModifyMenu = function(tag, fn)
  REGISTRADOS[tag] = REGISTRADOS[tag] or {}
  table.insert(REGISTRADOS[tag], fn)
  if modificarViejo then pcall(modificarViejo, tag, fn) end
end

-- Tu registro de misiones, de mentira.
local LOG, ORDEN, LISTA, OBJ = {}, {}, {}, {}
local QL = C_QuestLog
QL.GetNumQuestLogEntries = function() return #ORDEN, #ORDEN end
QL.GetInfo = function(i) local q = ORDEN[i] return q and { questID = q, title = "Misión " .. q, isHeader = false } or nil end
QL.IsOnQuest = function(q) return LOG[q] ~= nil end
QL.ReadyForTurnIn = function(q) return LISTA[q] == true end
QL.IsComplete = function(q) return LISTA[q] == true end
QL.GetQuestObjectives = function(q) return OBJ[q] or {} end
QL.GetTitleForQuestID = function(q) return LOG[q] end
local function tomar(q, titulo, objs)
  if not LOG[q] then ORDEN[#ORDEN + 1] = q end
  LOG[q] = titulo
  OBJ[q] = objs or { { text = "Algo: 0/5", type = "monster", finished = false } }
end
local function vaciar() LOG, ORDEN, LISTA, OBJ = {}, {}, {}, {} end

PRUEBA_ENTRAR()
local A, N = Alfa, AlfaNucleo
local K = N.Kit
local Ru = NS_OF("Alfa_Rutas")
local Ix = Ru and Ru.Indice

-- Cambia campos de una tabla mientras corre fn.
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do t[k] = a.v end
  if not ok then error(e, 0) end
end

-- Los avisos que salen.
local function conAvisos(fn)
  local avisos = {}
  local av, pl = K.Aviso, K.PorLya
  K.Aviso = function(o) avisos[#avisos + 1] = o return nil end
  K.PorLya = function() return false end
  local ok, e = pcall(fn, avisos)
  K.Aviso, K.PorLya = av, pl
  if not ok then error(e, 0) end
  return avisos
end

-- La flecha, de mentira: anota a dónde apunta.
local flecha = {}
local function conFlecha(fn)
  local Nav = A.Nav
  flecha.actual, flecha.puestas = nil, {}
  con(Nav, {
    SetTarget = function(map, x, y, label, f, stop, z)
      flecha.actual = { map = map, x = x, y = y, label = label }
      flecha.puestas[#flecha.puestas + 1] = flecha.actual
      return flecha.actual
    end,
    StartTrip = function(t) return { target = t } end,
    GetTarget = function() return flecha.actual end,
    IsOverride = function() return flecha.actual ~= nil end,
    Trip = function() return flecha.actual and { target = flecha.actual } or nil end,
    ReleaseTarget = function() flecha.actual = nil end,
  }, fn)
end

-- El mundo: la distancia es la diferencia de x (en segundos).
local AQUI = { map = 1440, x = 50, y = 50 }
local function lejos(a, b) return math.abs((a and a.x or 0) - (b and b.x or 0)) * 10 end
local function punto(x, nombre) return { map = 1440, x = x, y = 40, name = nombre } end

-- El Codex, de mentira (ya leído): lo que pide cada misión y dónde.
local PARTES = {}
local FINES = {}
local function conDatos(fn)
  local nada = function() return nil end
  local codex = { IsLoaded = function() return true end, Npc = nada, Object = nada, Item = nada, Name = nada, Each = nada, Quest = function(id) return { id = id, objectives = PARTES[id] and PARTES[id].codex or {} , ["end"] = { id = id } } end,
    Load = function() return true end }
  con(A, { Codex = codex, PlayerPoint = function() return AQUI end }, function()
    con(Ix, {
      Viaje = lejos,
      CodexListo = function() return true end,
      PasosMision = function(q) local p = PARTES[q.id] return p and { objetivos = p.objetivos } or { objetivos = {} } end,
      FinDe = function(lista) return lista and FINES[lista.id] or nil end,
    }, function() conFlecha(fn) end)
  end)
end

local function botonesDelMenu(qid)
  local botones = {}
  local root = {
    CreateDivider = function() end, CreateTitle = function() end,
    CreateButton = function(_, texto, alClic) botones[#botones + 1] = { texto = texto, alClic = alClic } end,
  }
  for _, fn in ipairs(REGISTRADOS["MENU_QUEST_MAP_LOG_TITLE"] or {}) do pcall(fn, { questID = qid }, root) end
  return botones
end
local function boton(lista, texto)
  for _, b in ipairs(lista) do if b.texto == texto then return b end end
  return nil
end

---------------------------------------------------------------------------
PASO("1. «Alfa: llévame» desde tu registro: al objetivo que te falta o a quien la recibe", function()
  REVISA(Ru and Ru.IrMision, "no existe Rutas/IrMision.lua")
  if not (Ru and Ru.IrMision) then return end
  vaciar()
  -- Dos objetivos: el primero ya hecho (los jabalíes), falta el segundo (las zarpas, en x=80).
  tomar(101, "Pieles y zarpas", { { text = "Jabalíes: 6/6", finished = true }, { text = "Zarpas: 0/4", finished = false } })
  PARTES[101] = { codex = { {}, {} }, objetivos = {
    { oi = 1, map = 1440, x = 52, y = 40, target = "Jabalí" },
    { oi = 2, map = 1440, x = 80, y = 40, itemName = "Zarpa" },
  } }
  tomar(102, "Cartas perdidas")
  LISTA[102] = true
  FINES[102] = punto(30, "Gornek")
  conDatos(function()
    local b = boton(botonesDelMenu(101), "Alfa: llévame")
    REVISA(b, "el clic derecho en una misión del registro no trae «Alfa: llévame»")
    if b then
      conAvisos(function() b.alClic() end)
      REVISA(flecha.actual and flecha.actual.x == 80, "la flecha no fue al objetivo que falta (las zarpas): " .. tostring(flecha.actual and flecha.actual.x))
    end
    local e = boton(botonesDelMenu(102), "Alfa: llévame a entregarla")
    REVISA(e, "una misión lista no dice «Alfa: llévame a entregarla»")
    if e then
      local av = conAvisos(function() e.alClic() end)
      REVISA(flecha.actual and flecha.actual.x == 30 and flecha.actual.label == "Gornek", "la flecha no fue con quien la recibe (Gornek)")
      REVISA(av[1] and tostring(av[1].texto):find("Gornek", 1, true), "el aviso no dice con quién se entrega")
    end
  end)
end)

---------------------------------------------------------------------------
PASO("2. «La misión más cerca» de todo tu registro (y el registro vacío tiene salida)", function()
  local Ir = Ru and Ru.IrMision
  if not Ir then return end
  -- 101 queda en x=80 (30 de aquí), 102 se entrega en x=30 (20), 103 en x=55 (5).
  tomar(103, "Escorpiones", { { text = "Escorpiones: 0/8", finished = false } })
  PARTES[103] = { codex = { {} }, objetivos = { { oi = 1, map = 1440, x = 55, y = 40, target = "Escorpión" } } }
  conDatos(function()
    local ok, q
    conAvisos(function() ok, q = Ir.MasCerca() end)
    REVISA(ok and q == 103 and flecha.actual and flecha.actual.x == 55, "no eligió la más cerca (Escorpiones): " .. tostring(q))
  end)
  local guardado = { LOG, ORDEN, LISTA, OBJ }
  vaciar()
  conDatos(function()
    local av = conAvisos(function() Ir.MasCerca() end)
    local a = av[1]
    REVISA(a and a.accion and a.accion.texto == "Recoger misiones", "con el registro vacío no ofreció «Recoger misiones»")
  end)
  LOG, ORDEN, LISTA, OBJ = guardado[1], guardado[2], guardado[3], guardado[4]
end)

---------------------------------------------------------------------------
PASO("3. «¡Lista para entregar!» de una misión que tu guía no entrega", function()
  local La = Ru and Ru.ListaAviso
  REVISA(La, "no existe Rutas/ListaAviso.lua")
  if not La then return end
  NOW = NOW + 10 -- pasado el rato de entrar (solo se aprende)
  La.Revisar()
  tomar(104, "Pieles de jabalí")
  FINES[104] = punto(60, "Zureetha")
  local R = AlfaRuta
  conDatos(function()
    con(R, { EsDeMiRuta = function(q) return q == 105 end }, function()
      local av = conAvisos(function()
        LISTA[104] = true
        FIRE_EVENT("QUEST_LOG_UPDATE")
        RUN_TIMERS(2)
      end)
      local a = av[1]
      REVISA(a and a.titulo == "¡Lista para entregar!", "al quedar lista no salió «¡Lista para entregar!»")
      REVISA(a and tostring(a.texto):find("Zureetha", 1, true), "el aviso no dice con quién se entrega")
      local b = a and a.acciones and a.acciones[1]
      REVISA(b and b.texto == "Llévame a entregarla", "el aviso no trae «Llévame a entregarla»")
      if b then b.alClic() REVISA(flecha.actual and flecha.actual.x == 60, "«Llévame a entregarla» no puso la flecha con Zureetha") end
      REVISA(a and a.acciones[2] and a.acciones[2].texto:find("Vuelta a entregar", 1, true), "con 2 listas no ofreció «Vuelta a entregar»")
      -- La de tu guía: la guía ya te lleva, nada.
      tomar(105, "De la guía")
      av = conAvisos(function()
        LISTA[105] = true
        FIRE_EVENT("QUEST_LOG_UPDATE")
        RUN_TIMERS(2)
      end)
      REVISA(#av == 0, "avisó una misión que tu guía ya va a entregar")
    end)
  end)
end)

---------------------------------------------------------------------------
PASO("4. Misiones nuevas al subir de nivel (sin guía)", function()
  local Su = Ru and Ru.AlSubir
  REVISA(Su, "no existe Rutas/AlSubir.lua")
  if not Su then return end
  local indice = { lista = {
    { id = 201, min = 12, lvl = 13 }, { id = 202, min = 11, lvl = 12 }, { id = 203, min = 12, lvl = 12 },
  } }
  local DADOR = { [201] = punto(90, "Lejano"), [203] = punto(52, "Cercano") }
  local E = A.Engine
  con(Ix, {
    Listo = function() return indice end,
    Pedir = function(fn) return fn(indice) end,
    Disponible = function() return true end,
    EnRegistro = function() return false end,
    Puntos = function(e) return DADOR[e.id] end,
  }, function()
    conDatos(function()
      con(E, { GetGuide = function() return nil end }, function()
        local av = conAvisos(function() FIRE_EVENT("PLAYER_LEVEL_UP", 12) RUN_TIMERS(3) end)
        local a
        for _, o in ipairs(av) do if o.titulo == "Nivel 12: misiones nuevas" then a = o end end
        REVISA(a and a.titulo == "Nivel 12: misiones nuevas", "al subir de nivel no dijo «Nivel 12: misiones nuevas»")
        REVISA(a and tostring(a.texto):find("2 misiones", 1, true), "no dijo cuántas se abren (2): " .. tostring(a and a.texto))
        local ver = a and a.acciones and a.acciones[1]
        REVISA(ver and ver.texto == "Ver cuáles", "el aviso no trae «Ver cuáles»")
        if ver then
          ver.alClic()
          local v = Su.Ventana()
          local l
          Su.Lista(12, function(x) l = x end)
          REVISA(l and #l == 2 and l[1].id == 203, "la lista no trae las 2 nuevas con la más cerca primero")
          REVISA(v and v:IsShown(), "«Ver cuáles» no abrió la ventana")
          if v then v:Hide() end
        end
      end)
      -- Con una guía en curso, la guía te lleva: nada.
      con(E, { GetGuide = function() return { id = "g" } end }, function()
        con(Ru, { GuiaTerminada = function() return false end }, function()
          local av = conAvisos(function() FIRE_EVENT("PLAYER_LEVEL_UP", 13) RUN_TIMERS(3) end)
          local dicho = false
          for _, o in ipairs(av) do if o.titulo == "Nivel 13: misiones nuevas" then dicho = true end end
          REVISA(not dicho, "con una guía en curso avisó las misiones nuevas")
        end)
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
PASO("5. «Tienes misiones aquí» al volver a una zona", function()
  local Pe = Ru and Ru.Pendientes
  REVISA(Pe, "no existe Rutas/Pendientes.lua")
  if not Pe then return end
  NOW = NOW + 30
  local H = Ru.Hora
  local enZona = { 101, 103, 104 }
  local zonaReal = GetRealZoneText
  GetRealZoneText = function() return "Durotar" end
  con(H, { PendientesEnZona = function(l) for _, q in ipairs(enZona) do l[#l + 1] = q end return #enZona end }, function()
    con(AlfaRuta, { EsDeMiRuta = function() return false end }, function()
      local av = conAvisos(function() FIRE_EVENT("ZONE_CHANGED_NEW_AREA") RUN_TIMERS(5) end)
      local a = av[1]
      REVISA(a and tostring(a.titulo):find("3 misiones sin terminar", 1, true), "al llegar a la zona no dijo «Tienes 3 misiones sin terminar aquí»")
      REVISA(a and a.acciones and a.acciones[1] and a.acciones[1].texto == "Llévame a la más cercana", "el aviso no trae «Llévame a la más cercana»")
      av = conAvisos(function() FIRE_EVENT("ZONE_CHANGED_NEW_AREA") RUN_TIMERS(5) end)
      REVISA(#av == 0, "lo dijo dos veces en la misma zona")
      enZona = { 101 }
      GetRealZoneText = function() return "Los Baldíos" end
      av = conAvisos(function() FIRE_EVENT("ZONE_CHANGED_NEW_AREA") RUN_TIMERS(5) end)
      REVISA(#av == 0, "con una sola misión en la zona también avisó")
    end)
  end)
  GetRealZoneText = zonaReal
end)

---------------------------------------------------------------------------
PASO("6. Clic derecho en la flecha: su menú", function()
  local f = rawget(_G, "AlfaNavArrow")
  REVISA(f, "no está la flecha")
  if not f then return end
  local abierto
  local menuViejo = K.Menu
  K.Menu = function(dueno, opciones, valor, alElegir) abierto = { dueno = dueno, op = opciones, elegir = alElegir } end
  FIRE(f, "OnMouseUp", "RightButton")
  K.Menu = menuViejo
  REVISA(abierto and abierto.dueno == f, "el clic derecho en la flecha no abrió su menú")
  if not abierto then return end
  local textos, esconder = {}, nil
  for _, o in ipairs(abierto.op) do
    if o.texto then textos[#textos + 1] = o.texto end
    if o.texto == "Esconder la flecha" then esconder = o end
  end
  local dicho = table.concat(textos, " | ")
  REVISA(dicho:find("La misión más cerca", 1, true), "el menú de la flecha no trae «La misión más cerca»: " .. dicho)
  REVISA(dicho:find("Llévame a…", 1, true), "el menú de la flecha no trae «Llévame a…»")
  REVISA(esconder, "el menú de la flecha no trae «Esconder la flecha»")
  if esconder then
    local av = conAvisos(function() abierto.elegir(esconder.valor) end)
    REVISA(A.Get("nav.arrow") == false, "«Esconder la flecha» no la escondió")
    local m = av[1] and av[1].acciones and av[1].acciones[1]
    REVISA(m and m.texto == "Mostrarla", "el aviso no trae «Mostrarla»")
    if m then m.alClic() end
    REVISA(A.Get("nav.arrow") ~= false, "«Mostrarla» no la volvió a mostrar")
  end
end)

---------------------------------------------------------------------------
local DESTINOS = {
  { nombre = "Orgrimmar", zona = "Durotar", map = 1440, x = 45, y = 10, tipo = "vuelo", clave = "vuelo:Orgrimmar", plegado = "orgrimmar durotar" },
  { nombre = "Cruce", zona = "Los Baldíos", map = 1440, x = 51, y = 30, tipo = "vuelo", clave = "vuelo:Cruce", plegado = "cruce los baldios" },
  { nombre = "Ventormenta", zona = "Elwynn", map = 1440, x = 90, y = 30, tipo = "vuelo", clave = "vuelo:Ventormenta", plegado = "ventormenta elwynn" },
}
local function conDestinos(fn)
  local Vj = Ru.Viaje
  local copia = {}
  for i, d in ipairs(DESTINOS) do local c = {} for k, v in pairs(d) do c[k] = v end copia[i] = c end
  con(Vj, { Destinos = function() return copia end }, function() conFlecha(function() fn(Vj) end) end)
end

PASO("7. «Llévame a…» recuerda tus destinos recientes", function()
  if not (Ru and Ru.Viaje) then return end
  conDestinos(function(Vj)
    conAvisos(function()
      Vj.Ir(Vj.Buscar("Ventormenta")[1])
      Vj.Ir(Vj.Buscar("Orgrimmar")[1])
    end)
    local l = Vj.Buscar("")
    REVISA(l[1] and l[1].nombre == "Orgrimmar" and l[1].reciente, "el último destino no salió arriba como «Reciente»")
    REVISA(l[2] and l[2].nombre == "Ventormenta" and l[2].reciente, "el destino de antes no salió segundo como «Reciente»")
    REVISA(l[3] and l[3].nombre == "Cruce" and not l[3].reciente, "lo que no es reciente no siguió por cercanía")
    local b = Vj.Buscar("cru")
    REVISA(b[1] and not b[1].reciente, "al buscar, «Reciente» siguió marcado")
  end)
end)

PASO("8. «Llévame a…»: Enter te lleva al primero", function()
  if not (Ru and Ru.Viaje) then return end
  conDestinos(function(Vj)
    Vj.Abrir()
    local v = rawget(_G, "AlfaRutasLlevame")
    local campo = v and v.Buscador and v.Buscador.Campo
    REVISA(campo, "no está el buscador de «Llévame a…»")
    if not campo then return end
    campo:SetText("ventor")
    RUN_TIMERS(1)
    conAvisos(function() FIRE(campo, "OnEnterPressed") RUN_TIMERS(1) end)
    REVISA(flecha.actual and flecha.actual.label == "Ventormenta", "Enter no llevó la flecha al primero (Ventormenta)")
    v:Hide()
  end)
end)

---------------------------------------------------------------------------
PASO("9. Teclas nuevas: la misión más cerca, vuelta a entregar y cerrar mis misiones", function()
  for _, n in ipairs({ "ALFA_RUTAS_MAS_CERCA", "ALFA_RUTAS_ENTREGAR", "ALFA_RUTAS_CERRAR" }) do
    local nombre = rawget(_G, "BINDING_NAME_" .. n)
    REVISA(type(nombre) == "string" and nombre ~= "", "falta el nombre de la tecla " .. n)
  end
  REVISA(type(AlfaRuta.MisionMasCerca) == "function", "falta AlfaRuta.MisionMasCerca (la tecla)")
  REVISA(type(AlfaRuta.Entregar) == "function" and type(AlfaRuta.CerrarTodo) == "function", "faltan las funciones de las teclas")
  -- La tecla hace lo mismo que el menú.
  conDatos(function()
    conAvisos(function() AlfaRuta.MisionMasCerca() end)
    REVISA(flecha.actual and flecha.actual.x == 55, "la tecla de la misión más cerca no movió la flecha")
  end)
end)

---------------------------------------------------------------------------
PASO("10. El viaje sigue después de /reload (y se olvida al llegar)", function()
  local Ir = Ru and Ru.IrMision
  if not Ir then return end
  conDatos(function()
    conAvisos(function() Ir.Ir(103) end)
    FIRE_EVENT("PLAYER_LOGOUT")
    REVISA(Ru.Personaje().viajeVivo and Ru.Personaje().viajeVivo.qid == 103, "al salir no se guardó el viaje")
    -- /reload: la flecha vuelve vacía.
    flecha.actual = nil
    REVISA(Ir.Retomar() and flecha.actual and flecha.actual.x == 55, "tras /reload la flecha no volvió a la misión")
    -- Otra cosa toma la flecha (llegaste, otro destino): se olvida al salir.
    flecha.actual = { map = 1, x = 1, y = 1 }
    FIRE_EVENT("PLAYER_LOGOUT")
    REVISA(Ru.Personaje().viajeVivo == nil, "se quedó guardado un viaje que ya no seguías")
    -- Y la misión entregada también lo borra.
    conAvisos(function() Ir.Ir(103) end)
    FIRE_EVENT("QUEST_TURNED_IN", 103, 0, 0)
    REVISA(Ru.Personaje().viajeVivo == nil, "al entregar la misión el viaje siguió guardado")
  end)
end)

-- Siempre al final: nada de Alfa se queda tapando el ratón.
PASO("el ratón sigue siendo del jugador", function() vaciar() TIEMPO(5) RATON_LIMPIO("al final") end)

PRUEBA_FIN()
