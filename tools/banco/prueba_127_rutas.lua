-- Prueba de la 1.2.7, lo de Rutas (tools/prueba.py la corre con las demás prueba_*.lua):
--   * «Una hora de caza» elige: entregar, cerrar lo de tu zona o recoger;
--   * al abandonar una misión que abre otra, el aviso de la cadena;
--   * una misión gris que vale la pena dice por qué;
--   * Omitir ofrece «Deshacer» un minuto;
--   * el ritmo por paso y lo que falta de tu guía.
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
local function check(cond, msg) if not cond then NOTE("1.2.7 rutas", msg) end end

-- El juego elige la misión para abandonar (antes de entrar, para que Alfa lo escuche).
local QL = C_QuestLog
local abandonar = 0
QL.SetAbandonQuest = function() end
QL.GetAbandonQuest = function() return abandonar end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
local Ru = NS_OF("Alfa_Rutas")
local E = A.Engine

-- Los avisos que salen (sin Lya).
local function conAvisos(fn)
  local avisos = {}
  local av = K.Aviso
  K.Aviso = function(o) avisos[#avisos + 1] = o end
  local ok, e = pcall(fn, avisos)
  K.Aviso = av
  if not ok then error(e) end
  return avisos
end

-- Una base de misiones de mentira: 990001 (nivel 10) abre 990002 (nivel 22).
local NIVELES = { [990001] = 10, [990002] = 22, [990003] = 23 }
local SIGUEN = { [990001] = { 990002 } }
local QDB_FALSA = {
  F = { LEVEL = 2 },
  IsLoaded = function() return true end,
  FollowUps = function(q) return SIGUEN[q] end,
  QuestRecord = function(q) return NIVELES[q] and { [2] = NIVELES[q] } or nil end,
  IsEligible = function() return true end,
  PlayerContext = function() return {} end,
}
local function conBase(fn)
  local antes = A.QuestDB
  A.QuestDB = QDB_FALSA
  local ok, e = pcall(fn)
  A.QuestDB = antes
  if not ok then error(e) end
end

step("Una hora de caza elige lo que más rinde", function()
  local R = AlfaRuta
  check(type(R.UnaHora) == "function", "falta AlfaRuta.UnaHora")
  local Cr, Rc, H = Ru.Cerrar, Ru.Recoger, Ru.Hora
  local listas, ahora, recoger = Cr.ListasAhora, Cr.Ahora, Rc.Ahora
  local pedido
  Cr.Ahora = function(f) pedido = f end
  Rc.Ahora = function() pedido = "recoger" end
  local entregar = Ru.EntregarListas
  Ru.EntregarListas = function() pedido = "listas" end -- 1.3.7: la misma manera de entregar en todos lados
  -- 2 listas: a entregar.
  Cr.ListasAhora = function() return 2 end
  check(R.UnaHora() == "entregar" and pedido == "listas", "con 2 listas no fue a entregar")
  -- 1 lista y una sin terminar en tu zona (bajo el encabezado «Durotar»).
  Cr.ListasAhora = function() return 1 end
  local num, info, en, lista = QL.GetNumQuestLogEntries, QL.GetInfo, QL.IsOnQuest, QL.ReadyForTurnIn
  local LOG = { { isHeader = true, title = "Durotar" }, { questID = 4641 }, { isHeader = true, title = "Los Baldíos" }, { questID = 840 } }
  QL.GetNumQuestLogEntries = function() return #LOG, 2 end
  QL.GetInfo = function(i) return LOG[i] end
  QL.IsOnQuest = function(q) return q == 4641 or q == 840 end
  QL.ReadyForTurnIn = function() return false end
  check(H.PendientesEnZona() == 1, "no contó la misión sin terminar de tu zona: " .. tostring(H.PendientesEnZona()))
  pedido = nil
  check(R.UnaHora() == "zona" and pedido == "zona", "con una sin terminar en tu zona no fue a cerrarla")
  -- Nada en tu zona: a recoger.
  LOG = { { isHeader = true, title = "Los Baldíos" }, { questID = 840 } }
  pedido = nil
  check(R.UnaHora() == "recoger" and pedido == "recoger", "sin nada cerca no fue a recoger")
  QL.GetNumQuestLogEntries, QL.GetInfo, QL.IsOnQuest, QL.ReadyForTurnIn = num, info, en, lista
  Cr.ListasAhora, Cr.Ahora, Rc.Ahora = listas, ahora, recoger
  Ru.EntregarListas = entregar
end)

step("Abandonar una misión que abre otra avisa de la cadena", function()
  local Ch = Ru.Cadenas
  check(Ch and Ch.Siguientes, "falta Cadenas.lua")
  conBase(function()
    local s = Ch.Siguientes(990001)
    check(s[1] == 990002, "no encontró la misión que sigue")
    check(#Ch.Siguientes(990003) == 0, "encontró cadena donde no hay")
    -- El jugador la elige para abandonar.
    abandonar = 990001
    local avisos = conAvisos(function() QL.SetAbandonQuest() end)
    local a = avisos[1]
    check(a and a.texto and a.texto:find("pierdes la cadena", 1, true), "no avisó que se pierde la cadena")
    -- Una sin cadena: nada.
    abandonar = 990003
    avisos = conAvisos(function() QL.SetAbandonQuest() end)
    check(#avisos == 0, "avisó de una cadena que no existe")
    -- Lo que abandona Alfa misma (ya confirmado): nada.
    abandonar = 990001
    NOW = NOW + 10
    Ru.abandonando = true
    avisos = conAvisos(function() QL.SetAbandonQuest() end)
    Ru.abandonando = nil
    check(#avisos == 0, "avisó al abandonar desde Alfa")
  end)
  abandonar = 0
end)

step("Una gris que vale la pena dice por qué", function()
  check(type(Ru.GrisValiosa) == "function", "falta M.GrisValiosa")
  conBase(function()
    local v = Ru.GrisValiosa(990001)
    check(type(v) == "string" and v:find("Vale la pena", 1, true), "la gris con cadena no dijo «Vale la pena»: " .. tostring(v))
    check(Ru.GrisValiosa(990003) == nil, "una misión que no es gris salió como «Vale la pena»")
  end)
end)

step("Omitir ofrece deshacer un minuto", function()
  local Rs = Ru.Rastreador
  check(Rs.Omitir and Rs.OfrecerDeshacer, "faltan Rastreador.Omitir y OfrecerDeshacer")
  local gg, sk, un, vw = E.GetGuide, E.Skip, E.Unskip, E.GetStepView
  local deshecho
  E.GetGuide = function() return { id = "Alfa/prueba" } end
  E.Skip = function() return 3 end
  E.Unskip = function(i) deshecho = i return true end
  E.GetStepView = function() return { title = "Habla con Gornek", goals = {} } end
  local avisos = conAvisos(function() Rs.Omitir() end)
  local a = avisos[1]
  check(a and a.titulo == "Omitiste un paso" and a.accion and a.accion.texto == "Deshacer", "no salió «Omitiste un paso» con «Deshacer»")
  if a and a.accion then a.accion.alClic() end
  check(deshecho == 3, "«Deshacer» no devolvió el paso omitido")
  -- Pasado el minuto: ya no.
  deshecho = nil
  avisos = conAvisos(function() Rs.Omitir() end)
  NOW = NOW + 61
  if avisos[1] and avisos[1].accion then conAvisos(function() avisos[1].accion.alClic() end) end
  check(deshecho == nil, "deshizo después de un minuto")
  -- Otra guía: tampoco.
  avisos = conAvisos(function() Rs.Omitir() end)
  E.GetGuide = function() return { id = "Alfa/otra" } end
  if avisos[1] and avisos[1].accion then conAvisos(function() avisos[1].accion.alClic() end) end
  check(deshecho == nil, "deshizo en otra guía")
  E.GetGuide, E.Skip, E.Unskip, E.GetStepView = gg, sk, un, vw
end)

step("El ritmo por paso y lo que falta", function()
  local H = Ru.Hora
  check(type(AlfaRuta.Estimado) == "function", "falta AlfaRuta.Estimado")
  Ru.Personaje().ritmo = nil
  local gg, gp, lv = E.GetGuide, E.GetProgress, E.GetLiveStep
  E.GetGuide = function() return { id = "Alfa/ritmo" } end
  E.GetProgress = function() return 10, 30 end
  check(AlfaRuta.Estimado() == nil, "estimó sin medidas")
  for _ = 1, 4 do H.Muestra(120) end
  check(AlfaRuta.Estimado() == nil, "estimó con solo 4 medidas")
  H.Muestra(120)
  check(AlfaRuta.Estimado() == 40, "20 pasos a 2 min no dieron 40 min: " .. tostring(AlfaRuta.Estimado()))
  -- El paso vivo avanza: una medida más.
  local vivo = 5
  E.GetLiveStep = function() return vivo end
  H.AlCambiarPaso()
  local n = H.Ritmo().n
  NOW = NOW + 60
  vivo = 6
  H.AlCambiarPaso()
  check(H.Ritmo().n == n + 1, "no midió el paso hecho")
  -- 20 minutos sin avanzar: no cuenta.
  NOW = NOW + 1200
  vivo = 7
  H.AlCambiarPaso()
  check(H.Ritmo().n == n + 1, "contó un paso de 20 minutos (AFK)")
  -- Un paso omitido no cuenta.
  NOW = NOW + 30
  vivo = 8
  H.AlCambiarPaso()
  H.AlOmitir()
  check(H.Ritmo().n == n + 1, "contó un paso omitido")
  E.GetGuide, E.GetProgress, E.GetLiveStep = gg, gp, lv
  Ru.Personaje().ritmo = nil
end)

print(string.format("PRUEBA: 1.2.7 rutas (una hora, cadenas, grises, deshacer, ritmo), %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
