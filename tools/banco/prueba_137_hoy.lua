-- Prueba de la 1.3.7, Hoy (tools/prueba.py la corre con las demás prueba_*.lua):
--   1. con pasos omitidos Hoy ya no dice «Guía completa»: dice lo mismo que
--      el rastreador, con «Recuperar lo omitido»; terminada, «Seguir con X»;
--   2. «Cerrar mis misiones» dice «12 · 4 listas» y lo que dan tus listas;
--   3. para subir de nivel: «Nivel N en … a tu ritmo», tu descanso, tu
--      reputación y tu tiempo jugado (sin chat: el chat no oye la respuesta);
--   4. el cuadro de la barra de experiencia trae lo de Alfa;
--   5. «Sigues a X» con la distancia y «Dejar de seguir»;
--   6. tu mazmorra (fuera y dentro) en Hoy y en el rastreador;
--   7. el rato en la subasta o ausente no cuenta para tu ritmo.
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
local function check(cond, msg) if not cond then NOTE("1.3.7 hoy", msg) end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local N = AlfaNucleo
local A = N.A
local K = N.Kit
local In = NS_OF("Alfa_Inicio")
local Ru = NS_OF("Alfa_Rutas")
local P = In.Pagina
local E = A.Engine

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

local function buscar(lista, titulo)
  for _, x in ipairs(lista or {}) do if x.titulo == titulo then return x end end
  return nil
end

---------------------------------------------------------------------------
-- 1. Hoy y el rastreador dicen lo mismo
---------------------------------------------------------------------------

local GUIA = { id = "prueba-137-hoy", title = "Durotar", steps = { {}, {}, {} } }
local vistas
local function motorFalso(extra)
  local t = {
    GetLiveStep = function() return nil end,
    GetStepIndex = function() return 3 end,
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

step("Con pasos omitidos Hoy no dice «Guía completa»; terminada, «Seguir con X»", function()
  vistas = { { status = "done" }, { status = "done", skipped = true, title = "Mata jabalíes" }, { status = "done" } }
  con(E, motorFalso(), function()
    con(Ru.Rastreador, { Fin = function() return nil end }, function()
      local d = P.TarjetaPaso()
      check(d and not d.fin, "Hoy dice que la guía terminó con un paso omitido")
      check(d and d.titulo ~= "¡Terminaste tu guía!", "Hoy dice «¡Terminaste tu guía!»: " .. tostring(d and d.titulo))
      check(d and (d.texto or ""):find("quedó 1 paso", 1, true), "no dice «quedó 1 paso sin hacer»: " .. tostring(d and d.texto))
      check(d and d.secundaria and d.secundaria.texto == "Recuperar lo omitido", "no ofrece «Recuperar lo omitido»")
      -- Terminada de verdad: la que sigue a un clic.
      vistas[2].skipped = nil
      con(Ru.Siguiente, { Proponer = function() return { id = "otra", nombre = "Los Baldíos (10-20)" } end }, function()
        local d2 = P.TarjetaPaso()
        check(d2 and d2.fin, "con todo hecho Hoy no dice que terminó")
        check(d2 and d2.accion and d2.accion.texto == "Seguir con Los Baldíos (10-20)", "Hoy no propone la que sigue: " .. tostring(d2 and d2.accion and d2.accion.texto))
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- 2. Cerrar mis misiones
---------------------------------------------------------------------------

step("«Cerrar mis misiones» dice «12 · 4 listas» y lo que dan", function()
  con(C_QuestLog, { GetNumQuestLogEntries = function() return 14, 12 end }, function()
    con(AlfaRuta, { XPListas = function() return { n = 4, xp = 3200, conocidas = 4, subes = true } end }, function()
      local c = buscar(P.Misiones(), "Cerrar mis misiones")
      check(c, "no salió «Cerrar mis misiones»")
      check(c and c.valor == "12  \194\183  4 listas", "el número no dice «12 · 4 listas»: " .. tostring(c and c.valor))
      check(c and (c.texto or ""):find("3,200", 1, true) and c.texto:find("subes de nivel", 1, true), "no dice lo que dan tus listas: " .. tostring(c and c.texto))
    end)
  end)
end)

---------------------------------------------------------------------------
-- 3. Subir de nivel, descanso, reputación y tiempo jugado
---------------------------------------------------------------------------

step("Para subir de nivel: «Nivel N en … a tu ritmo», el descanso, la reputación y el tiempo jugado", function()
  local S = In.Sesion
  local e = { maximo = false, nivel = 33, falta = 6000, descanso = 1000, xpAhora = 4000, xpMax = 10000, ritmo = 9000,
    prom = 8000, xp = 100, dur = 600, misiones = 0, inicio = time() }
  con(S, { Estado = function() return e end }, function()
    con(AlfaRuta, { XPListas = function() return { n = 2, xp = 1000 } end }, function()
      local d = In.Subir.Datos()
      -- 6000 - 1000 de las listas = 5000; con 1000 de descanso: 4000 cazando; a 9000 por hora, 26.7 min.
      check(d and math.abs(d.segundos - 1600) < 2, "el tiempo para subir no cuenta las listas y el descanso: " .. tostring(d and d.segundos))
      check(In.Subir.Texto(d) == "Nivel 34 en 27 min a tu ritmo", "no dice «Nivel 34 en 27 min a tu ritmo»: " .. tostring(In.Subir.Texto(d)))
      check((In.Subir.Descanso(d) or ""):find("50 %% del nivel 33"), "el descanso no dice hasta dónde: " .. tostring(In.Subir.Descanso(d)))
      local lista = P.Numeros()
      local s = buscar(lista, "Para subir de nivel")
      check(s and s.texto == "Nivel 34 en 27 min a tu ritmo", "Hoy no dice el tiempo para subir: " .. tostring(s and s.texto))
      check(buscar(lista, "Descansado"), "Hoy no enseña tu descanso")
    end)
  end)
  -- La reputación.
  con(_G, { GetWatchedFactionInfo = function() return "Orgrimmar", 5, 3000, 9000, 7800 end, C_Reputation = NADA }, function()
    local r = In.Reputacion.Actual()
    check(r and r.falta == 1200 and r.misiones == 5, "la reputación no cuenta lo que falta: " .. tostring(r and r.falta))
    check(In.Reputacion.Texto(r) == "Te faltan 1,200 para Honorable, ~5 misiones", "la reputación dice: " .. tostring(In.Reputacion.Texto(r)))
    In.Reputacion.Anotar("Orgrimmar", 600)
    check(In.Reputacion.Actual().misiones == 2, "lo que da una misión no se aprende")
    local c = buscar(P.Numeros(), "Orgrimmar")
    check(c and c.valor == "Amistoso", "Hoy no enseña tu reputación")
  end)
  -- El tiempo jugado, sin chat.
  local chat = CreateFrame("Frame", "ChatFrame1")
  chat:RegisterEvent("TIME_PLAYED_MSG")
  local pedido = false
  con(_G, { ChatFrame1 = chat, NUM_CHAT_WINDOWS = 1, RequestTimePlayed = function() pedido = true end }, function()
    local J = In.Jugado
    check(J.Pedir(), "no pidió el tiempo jugado")
    check(pedido, "no llamó a RequestTimePlayed")
    check(not chat:IsEventRegistered("TIME_PLAYED_MSG"), "el chat iba a escribir el tiempo jugado")
    FIRE_EVENT("TIME_PLAYED_MSG", 90000, 3600)
    RUN_TIMERS(1)
    check(chat:IsEventRegistered("TIME_PLAYED_MSG"), "el chat ya no oye /played")
    local d = J.Datos()
    check(d and d.total >= 90000, "no guardó el tiempo jugado")
    check(J.Corto(90000) == "1 d 1 h", "el tiempo jugado largo: " .. J.Corto(90000))
    check(buscar(P.Numeros(), "Tiempo jugado"), "Hoy no enseña tu tiempo jugado")
  end)
end)

---------------------------------------------------------------------------
-- 4. El cuadro de la barra de experiencia
---------------------------------------------------------------------------

step("El cuadro de la barra de experiencia trae lo de Alfa", function()
  local barra = rawget(_G, "MainMenuExpBar")
  if type(barra) ~= "table" or tostring(barra) == "comodin" or not barra._scripts then
    rawset(_G, "MainMenuExpBar", nil)
    barra = CreateFrame("StatusBar", "MainMenuExpBar", UIParent)
  end
  barra:SetScript("OnEnter", function() end)
  barra:EnableMouse(true)
  In.Barras.Enganchar()
  check(In.Barras.TipoDe(barra) == "xp", "no sabe que es la barra de experiencia")
  local lineas = {}
  con(In.Subir, { Lineas = function() return { "Nivel 34 en 27 min a tu ritmo" } end }, function()
    con(GameTooltip, { AddLine = function(_, t) lineas[#lineas + 1] = t end }, function()
      FIRE(barra, "OnEnter")
    end)
  end)
  local hay = false
  for _, l in ipairs(lineas) do if l == "Nivel 34 en 27 min a tu ritmo" then hay = true end end
  check(hay, "el cuadro de la barra no dice cuánto falta para subir")
  FIRE(barra, "OnLeave")
end)

---------------------------------------------------------------------------
-- 5. «Sigues a X»
---------------------------------------------------------------------------

step("«Sigues a X» con la distancia y «Dejar de seguir»", function()
  local dejo = false
  local Ma = rawget(_G, "AlfaManada")
  if type(Ma) ~= "table" then return end
  con(Ma, { Resumen = function() return { comparte = true, manada = 2, grupo = 1, siguiendo = "Ana" } end,
    DejarDeSeguir = function() dejo = true end }, function()
    con(AlfaRuta, { Distancia = function() return "120 yd al norte", "neutro", "Ana" end }, function()
      local c = buscar(P.Numeros(), "Tu manada")
      check(c and c.texto:find("Sigues a Ana", 1, true) and c.texto:find("120 yd", 1, true), "no dice a quién sigues ni qué tan lejos: " .. tostring(c and c.texto))
      check(c and (c.ayuda or ""):find("Dejar de seguir", 1, true), "no ofrece «Dejar de seguir»")
      if c and c.alClic then c.alClic() end
      check(dejo, "«Dejar de seguir» no dejó de seguir")
    end)
  end)
end)

---------------------------------------------------------------------------
-- 6. Tu mazmorra
---------------------------------------------------------------------------

step("Tu mazmorra en Hoy y en el rastreador", function()
  local preparada = false
  local fuera = { titulo = "Tu mazmorra", texto = "Minas de la Muerte · 3 misiones para recoger", accion = { texto = "Prepárame", alClic = function() preparada = true end } }
  con(_G, { AlfaMazmorras = { Tarjeta = function() return fuera end, Dentro = function() return nil end } }, function()
    local c = buscar(P.Misiones(), "Tu mazmorra")
    check(c and c.ayuda == "Prepárame" and c.alClic, "Hoy no enseña tu mazmorra con «Prepárame»")
    if c and c.alClic then c.alClic() end
    check(preparada, "«Prepárame» no hizo nada")
  end)
  local dentro = { nombre = "Minas de la Muerte", jefe = { nombre = "Rhahk'Zor", vencidos = 0, total = 6 }, faltan = 2, misiones = {} }
  con(_G, { AlfaMazmorras = { Tarjeta = function() return nil end, Dentro = function() return dentro end } }, function()
    local c = buscar(P.Misiones(), "Minas de la Muerte")
    check(c and c.texto:find("Siguiente jefe: Rhahk'Zor (1 de 6)", 1, true), "Hoy no dice el siguiente jefe: " .. tostring(c and c.texto))
    RUN_TIMERS(6)
    local a = Ru.Rastreador.AvisoMazmorra()
    check(a and a.texto:find("Te faltan 2 misiones aquí", 1, true), "el rastreador no dice lo que te falta ahí: " .. tostring(a and a.texto))
  end)
  -- Sin el área de mazmorras, nada se rompe.
  con(_G, { AlfaMazmorras = NADA }, function() P.Misiones() end)
end)

---------------------------------------------------------------------------
-- 7. El ritmo sin la subasta
---------------------------------------------------------------------------

step("El rato en la subasta o ausente no cuenta para tu ritmo", function()
  local S = In.Sesion
  FIRE_EVENT("AUCTION_HOUSE_SHOW")
  check(S.Pausado(), "en la subasta el rato cuenta como de misiones")
  FIRE_EVENT("AUCTION_HOUSE_CLOSED")
  con(_G, { UnitIsAFK = function() return true end }, function() check(S.Pausado(), "ausente el rato cuenta como de misiones") end)
  con(_G, { UnitIsAFK = function() return false end, UnitOnTaxi = function() return false end, IsInInstance = function() return false end }, function()
    check(not S.Pausado(), "jugando normal cuenta como pausa")
  end)
end)

print(("PRUEBA: 1.3.7 Hoy, %d pasos, %d errores"):format(pasos, #ERRORS))
