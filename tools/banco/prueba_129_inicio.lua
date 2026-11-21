-- Prueba de la 1.2.9, lo de Hoy (tools/prueba.py la corre con las demás prueba_*.lua):
--   * «¿Cuánto tiempo tienes?»: el plan para 30 min, 1 h y 2 h (entregar,
--     tu zona, la mazmorra si cabe, recolectar, tu guía y la entrega del
--     final), con tu ritmo del diario; «Empezar» pone la flecha en el primer
--     paso, «Siguiente» en el que sigue, un paso que se cumple solo avisa sin
--     poner la flecha, y la tarjeta va hasta arriba de Hoy mientras sigue;
--   * Camino al 60: lo que falta, tu ritmo de tus días, «Hoy avanzaste 1.4
--     niveles», las guías por tramos y las mazmorras en su tramo, la ventana;
--   * listo para la mazmorra: equipo, bolsas, comida, agua, munición y
--     componentes; sola al entrar o con un grupo de 5, una vez; nunca en combate;
--   * comida y agua: avisa al bajar (no a quien nunca lleva), el agua solo
--     con maná, qué comprar a tu nivel y la flecha al vendedor.
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
local function check(cond, msg) if not cond then NOTE("1.2.9 inicio", msg) end end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local N = AlfaNucleo
local A = N.A
local K = N.Kit
local I = NS_OF("Alfa_Inicio")
local Co, Li, TM, CA, R = I.Comida, I.Listo, I.Tiempo, I.Camino, I.Rec

-- Cambia campos de una tabla mientras corre fn y los devuelve (NADA: a nil).
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

-- Los avisos que salen (K.Aviso; Lya no se mete).
local MIOS = { "^Te ", "^Antes de", "^¡Todo listo", "^Listo%. Ahora", "^¡Plan cumplido" }
local function conAvisos(fn)
  local avisos = {}
  con(K, { Aviso = function(o)
    local t = tostring(o and o.titulo or "")
    for _, p in ipairs(MIOS) do
      if t:find(p) then avisos[#avisos + 1] = o break end
    end
    return {}
  end }, function() fn(avisos) end)
  return avisos
end

-- La flecha de Buscar cerca: a qué tipo se pidió.
local idas = {}
local CercaFalsa = { Ir = function(tipo) idas[#idas + 1] = tipo return true end, Tipos = function() return {} end }

-- Unas bolsas de mentira: { [id] = cantidad }.
local function bolsas(cosas)
  local lista = {}
  for id, n in pairs(cosas) do lista[#lista + 1] = { itemID = id, stackCount = n } end
  return {
    GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
    GetContainerItemInfo = function(bag, slot) return bag == 0 and lista[slot] or nil end,
    GetContainerNumFreeSlots = function() return 10, 0 end,
  }
end

---------------------------------------------------------------------------
-- Los ajustes
---------------------------------------------------------------------------

step("Los ajustes nuevos con sus valores de fábrica", function()
  for clave, v in pairs({ horaPlan = true, horaMin = 60, horaAuto = true, camino = true, listoAuto = true, listoDur = 50,
    listoBolsas = 6, listoComida = 10, comidaAviso = true, comidaMin = 5 }) do
    check(A.GetDefault("inicio." .. clave) == v, "inicio." .. clave .. " no viene en " .. tostring(v))
  end
  check(type(AlfaInicio) == "table" and type(AlfaInicio.RevisarMazmorra) == "function" and type(AlfaInicio.Camino) == "function",
    "falta el contrato AlfaInicio")
end)

---------------------------------------------------------------------------
-- 9. Comida y agua
---------------------------------------------------------------------------

step("Comida y agua: avisa al bajar, con lo de tu nivel", function()
  check(Co.Sugerencia(23).comida == 4542 and Co.Sugerencia(23).agua == 1205, "a nivel 23 no sugiere el pan de maíz y el jugo de melón")
  check(Co.Sugerencia(1).agua == 159 and Co.Sugerencia(60).agua == 8766, "las sugerencias por nivel no van de punta a punta")
  idas = {}
  con(_G, { AlfaCerca = CercaFalsa, UnitPowerMax = function() return 0 end }, function()
    -- Un guerrero con 12 panes: nada que decir.
    con(_G, { C_Container = bolsas({ [4542] = 12 }) }, function()
      Co.Reiniciar()
      local a = conAvisos(function() Co.Revisar() end)
      check(#a == 0, "avisó en la primera cuenta")
      local comida, agua = Co.Contar()
      check(comida == 12 and agua == 0, "no contó los 12 panes: " .. comida)
    end)
    -- Le quedan 3: el aviso, con qué comprar y la flecha.
    con(_G, { C_Container = bolsas({ [4542] = 3, [1205] = 1 }) }, function()
      local a = conAvisos(function() Co.Revisar() end)
      check(#a == 1, "no avisó al quedarle 3 panes")
      local o = a[1] or {}
      check(o.titulo == "Te queda poca comida", "el guerrero no tiene que oír del agua: " .. tostring(o.titulo))
      check(tostring(o.texto):find("Pan de maíz húmedo", 1, true) and tostring(o.texto):find("Te quedan 3", 1, true), "no dice qué comprar a tu nivel: " .. tostring(o.texto))
      check(o.accion and o.accion.texto == "Llévame a comprar", "sin «Llévame a comprar»")
      if o.accion then o.accion.alClic() end
      check(idas[#idas] == "food", "la flecha no fue al vendedor de comida")
      check(Co.Bajo(), "Hoy no muestra la alerta de comida")
      -- Otra vez igual: no se repite.
      a = conAvisos(function() Co.Revisar() end)
      check(#a == 0, "repitió el aviso sin que bajara más")
    end)
    -- Sin nada: «Te quedaste sin comida».
    con(_G, { C_Container = bolsas({}) }, function()
      local a = conAvisos(function() Co.Revisar() end)
      check(a[1] and a[1].titulo == "Te quedaste sin comida", "al acabarse no dijo que te quedaste sin comida")
    end)
  end)
  -- A quien nunca lleva comida no se le dice nada (ni en Hoy).
  con(_G, { C_Container = bolsas({}), UnitPowerMax = function() return 0 end }, function()
    Co.Reiniciar()
    local a = conAvisos(function() Co.Revisar() Co.Revisar() end)
    check(#a == 0 and not Co.Bajo(), "molestó a quien nunca lleva comida")
  end)
  -- Un mago: también el agua.
  con(_G, { C_Container = bolsas({ [4542] = 20, [1205] = 20 }), UnitPowerMax = function() return 900 end }, function()
    Co.Reiniciar()
    Co.Revisar()
    check(Co.NecesitaAgua(), "con maná no cuenta el agua")
    con(_G, { C_Container = bolsas({ [4542] = 20, [1205] = 2 }) }, function()
      local a = conAvisos(function() Co.Revisar() end)
      check(a[1] and a[1].titulo == "Te queda poca agua" and tostring(a[1].texto):find("Jugo de melón", 1, true), "al mago no le dijo del agua")
    end)
  end)
  -- En combate espera.
  con(_G, { C_Container = bolsas({ [4542] = 20 }), UnitPowerMax = function() return 0 end }, function()
    Co.Reiniciar()
    Co.Revisar()
    local pelea = true
    con(_G, { InCombatLockdown = function() return pelea end, C_Container = bolsas({ [4542] = 1 }) }, function()
      local a = conAvisos(function() Co.Revisar() end)
      check(#a == 0, "avisó en combate")
      a = conAvisos(function()
        pelea = false
        FIRE_EVENT("PLAYER_REGEN_ENABLED")
        RUN_TIMERS(2)
      end)
      check(#a == 1, "no avisó al salir de combate")
    end)
  end)
  Co.Reiniciar()
end)

---------------------------------------------------------------------------
-- 8. Listo para la mazmorra
---------------------------------------------------------------------------

-- 1.3.1: forma = "c_item" (lo de Forever: C_Item.GetItemCount, sin el global)
-- o "global" (solo el GetItemCount viejo, de respaldo). Las dos deben contar igual.
local function conMazmorra(clase, cosas, fn, extra, forma)
  local items = function(id) return (cosas.items or {})[id] or 0 end
  local g = { UnitClass = function() return "X", clase, 1 end, AlfaCerca = CercaFalsa,
    C_Container = bolsas(cosas.bolsas or {}), UnitPowerMax = function() return cosas.mana and 900 or 0 end,
    GetItemCount = forma == "global" and items or NADA,
    IsPlayerSpell = function(id) return (cosas.hechizos or {})[id] or false end,
    GetInventoryItemCount = function(u, slot) return slot == 0 and (cosas.municion or 0) or 0 end }
  for k, v in pairs(extra or {}) do g[k] = v end
  con(_G, g, function()
    con(C_Item, { GetItemCount = forma == "global" and NADA or items }, function()
      con(R, { LeerDurabilidad = function() return cosas.dur and { { slot = 5, pct = cosas.dur } } or {} end,
        Bolsas = function() return cosas.libres or 12, 16 end }, fn)
    end)
  end)
end

for _, forma in ipairs({ "c_item", "global" }) do
step("Listo para la mazmorra: lo que falta, lo urgente primero (" .. forma .. ")", function()
  idas = {}
  conMazmorra("ROGUE", { dur = 30, libres = 2, bolsas = { [4542] = 3 }, items = { [5140] = 1 }, hechizos = { [1856] = true } }, function()
    local f = Li.Faltas()
    local claves = {}
    for i, x in ipairs(f) do claves[i] = x.clave end
    check(table.concat(claves, ",") == "reparar,comida,componente,bolsas", "faltas en otro orden: " .. table.concat(claves, ","))
    check(f[1] and f[1].texto:find("30 %", 1, true), "no dice cómo va tu equipo: " .. tostring(f[1] and f[1].texto))
    check(f[3] and f[3].texto:find("Polvo cegador", 1, true), "al pícaro no le pidió polvo cegador")
    check(f[3] and f[3].texto:find("llevas 1 de 5", 1, true), "no contó el polvo cegador que llevas (" .. forma .. "): " .. tostring(f[3] and f[3].texto))
    local a = conAvisos(function() Li.Revisar("boton", "Sima ígnea") end)
    local o = a[1] or {}
    check(o.titulo == "Antes de Sima ígnea te falta:", "el aviso no dice de qué mazmorra: " .. tostring(o.titulo))
    check(o.accion and o.accion.texto == "Llévame a reparar", "lo primero no fue reparar")
    if o.accion then o.accion.alClic() end
    check(idas[#idas] == "repair", "la flecha no fue a reparar")
  end, nil, forma)
  -- Sin el hechizo, no pide el componente; un guerrero no pide agua.
  conMazmorra("ROGUE", { dur = 90, bolsas = { [4542] = 20 }, hechizos = {} }, function()
    check(#Li.Faltas() == 0, "pidió polvo cegador sin saber Esfumarse")
    local a = conAvisos(function() Li.Revisar("boton") end)
    check(a[1] and a[1].titulo == "¡Todo listo para la mazmorra!", "con todo, el botón no dijo «¡Todo listo!»")
    a = conAvisos(function() Li.Revisar("entrar") end)
    check(#a == 0, "sola, sin faltas, salió un aviso")
  end, nil, forma)
  -- 1.3.1: el brujo con sus fragmentos de alma no oye que le faltan.
  conMazmorra("WARLOCK", { dur = 90, bolsas = { [4542] = 20 }, items = { [6265] = 10 } }, function()
    for _, x in ipairs(Li.Faltas()) do
      check(x.clave ~= "componente", "al brujo con 10 fragmentos le dijo (" .. forma .. "): " .. tostring(x.texto))
    end
  end, { UnitLevel = function() return 30 end }, forma)
  -- El cazador y su munición; el sacerdote y su agua.
  conMazmorra("HUNTER", { dur = 90, bolsas = { [4542] = 20, [1205] = 20 }, mana = true, municion = 150 }, function()
    local f = Li.Faltas()
    check(f[1] and f[1].clave == "municion" and f[1].ir == "arrows", "al cazador no le pidió flechas")
  end, nil, forma)
  conMazmorra("PRIEST", { dur = 90, bolsas = { [4542] = 20, [1205] = 2 }, mana = true }, function()
    local f = Li.Faltas()
    check(f[1] and f[1].clave == "agua", "al sacerdote no le pidió agua")
  end, nil, forma)
end)
end

step("Listo para la mazmorra: sola al entrar y con tu grupo, nunca en combate", function()
  Li.Reiniciar()
  local dentro, grupo, pelea = false, 0, false
  conMazmorra("WARRIOR", { dur = 20, bolsas = { [4542] = 20 } }, function()
    local a = conAvisos(function()
      FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
      RUN_TIMERS(5)
    end)
    check(#a == 0, "avisó fuera de una mazmorra")
    a = conAvisos(function()
      dentro = true
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      RUN_TIMERS(5)
      FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
      RUN_TIMERS(5)
    end)
    check(#a == 1, "al entrar a la mazmorra no avisó una vez: " .. #a)
    -- Con un grupo de 5, una vez (y en combate espera).
    a = conAvisos(function(av)
      dentro = false
      FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
      grupo, pelea = 5, true
      FIRE_EVENT("GROUP_ROSTER_UPDATE")
      RUN_TIMERS(5)
      check(#av == 0, "avisó en combate")
      pelea = false
      FIRE_EVENT("PLAYER_REGEN_ENABLED")
      RUN_TIMERS(2)
      FIRE_EVENT("GROUP_ROSTER_UPDATE")
      RUN_TIMERS(5)
    end)
    check(#a == 1, "con el grupo de 5 no avisó una vez: " .. #a)
    -- Apagado: nada.
    A.Set("inicio.listoAuto", false)
    a = conAvisos(function()
      dentro = true
      Li.Reiniciar()
      FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
      RUN_TIMERS(5)
    end)
    check(#a == 0, "con el ajuste apagado revisó solo")
    A.Set("inicio.listoAuto", true)
  end, { IsInInstance = function() return dentro, dentro and "party" or "none" end,
    GetNumGroupMembers = function() return grupo end, InCombatLockdown = function() return pelea end })
  Li.Reiniciar()
end)

---------------------------------------------------------------------------
-- 26. ¿Cuánto tiempo tienes?
---------------------------------------------------------------------------

local llamadas = {}
local RutaFalsa = {
  Listas = function() return 3 end,
  VueltaEntregar = function() llamadas[#llamadas + 1] = "vuelta" return true end,
  Entregar = function() llamadas[#llamadas + 1] = "entregar" end,
  Liberar = function(f) llamadas[#llamadas + 1] = "liberar:" .. tostring(f) end,
  Recoger = function() llamadas[#llamadas + 1] = "recoger" end,
}
local MazFalsa = {
  Recomendada = function() return { key = "rfc", nombre = "Sima ígnea", modo = "ahora" } end,
  Preparar = function(k) llamadas[#llamadas + 1] = "preparar:" .. k end,
}
local LOG = {
  { isHeader = true, title = "Durotar" }, { questID = 801, title = "Una" }, { questID = 802, title = "Otra" },
  { isHeader = true, title = "Los Baldíos" }, { questID = 803, title = "Lejos" },
}
local QLFalso = setmetatable({ GetNumQuestLogEntries = function() return #LOG, #LOG end, GetInfo = function(i) return LOG[i] end }, { __index = C_QuestLog })

local function conPlan(fn, listas)
  local ruta = setmetatable({ Listas = function() return listas() end }, { __index = RutaFalsa })
  con(_G, { AlfaRuta = ruta, AlfaMazmorras = MazFalsa, C_QuestLog = QLFalso, IsPlayerSpell = function(id) return id == 2575 end }, function()
    con(A, { Dungeons = { List = function() return { { key = "rfc", bosses = 5 } } end } }, function()
      con(I.Sesion, { Sesiones = function() return { { dur = 3600, misiones = 12 }, { dur = 1800, misiones = 3 } } end }, fn)
    end)
  end)
end

step("El plan para tu tiempo, con tu ritmo", function()
  conPlan(function()
    local mpm, fuente = TM.MinPorMision()
    check(fuente == "diario" and math.abs(mpm - 6) < 0.6, "el ritmo no salió de tu diario: " .. tostring(mpm) .. " " .. tostring(fuente))
    check(TM.EnZona() == 2, "no contó las 2 de tu zona: " .. TM.EnZona())
    local p = TM.Armar(120)
    local tipos, suma = {}, 0
    for i, x in ipairs(p.pasos) do tipos[i] = x.tipo suma = suma + x.min end
    local dicho = table.concat(tipos, ",")
    check(dicho == "entregar,zona,mazmorra,recolectar,guia,final" or dicho == "entregar,zona,mazmorra,recolectar,recoger,final",
      "el plan de 2 h no tiene sus pasos en orden: " .. dicho)
    check(suma == 120, "el plan de 2 h no suma 120 min: " .. suma)
    local p30 = TM.Armar(30)
    local t30 = {}
    for i, x in ipairs(p30.pasos) do t30[i] = x.tipo end
    check(not table.concat(t30, ","):find("mazmorra") and not table.concat(t30, ","):find("final"), "en 30 min metió mazmorra o la entrega del final: " .. table.concat(t30, ","))
    local s = 0
    for _, x in ipairs(p30.pasos) do s = s + x.min end
    check(s <= 30, "el plan de 30 min se pasa: " .. s)
    local t, txt = TM.Textos(p.pasos[1])
    check(t == "Entrega tus misiones listas" and txt:find("3 listas", 1, true), "el paso de entregar no dice cuántas: " .. tostring(txt))
    check(TM.Minutos(90) == "1 h 30 min" and TM.Minutos(45) == "45 min" and TM.Minutos(120) == "2 h", "los minutos no se dicen bien")
  end, function() return 3 end)
end)

step("Empezar, Siguiente y el paso que se cumple solo", function()
  local nl = 3
  conPlan(function()
    llamadas = {}
    local plan = TM.Armar(120)
    check(TM.Empezar(plan), "no empezó el plan")
    check((llamadas[1] == "vuelta" or llamadas[1] == "entregar"), "1.3.7 (AlfaRuta.Entregar ya es la Vuelta): «Empezar» no llevó a entregar las listas: " .. tostring(llamadas[1]))
    local h = TM.Actual()
    check(h and h.i == 1 and #h.pasos == #plan.pasos, "el plan no quedó guardado")
    check(type(N.DatosPersonaje("inicio").hora) == "table", "el plan no se guardó por personaje")
    -- Las entregas se acaban: pasa solo al siguiente, con aviso y sin poner la flecha.
    llamadas = {}
    nl = 0
    local a = conAvisos(function()
      FIRE_EVENT("QUEST_TURNED_IN", 801, 0, 0)
      RUN_TIMERS(3)
    end)
    check(TM.Actual().i == 2, "al acabarse las listas no pasó a tu zona")
    check(#llamadas == 0, "el avance solo puso la flecha sin tu clic")
    check(a[1] and tostring(a[1].titulo):find("Cierra misiones de Durotar", 1, true), "el aviso no dice qué sigue: " .. tostring(a[1] and a[1].titulo))
    if a[1] and a[1].accion then a[1].accion.alClic() end
    check(llamadas[1] == "liberar:zona", "«Llévame» no armó las de tu zona: " .. tostring(llamadas[1]))
    -- Siguiente: la mazmorra.
    llamadas = {}
    TM.Siguiente()
    check(TM.Actual().pasos[TM.Actual().i].tipo == "mazmorra" and llamadas[1] == "preparar:rfc", "«Siguiente» no llevó a la mazmorra")
    -- Hasta el final: «¡Plan cumplido!».
    a = conAvisos(function()
      for _ = 1, 10 do if TM.Actual() then TM.Siguiente(false) end end
    end)
    check(TM.Actual() == nil, "el plan no terminó")
    check(a[#a] and a[#a].titulo == "¡Plan cumplido!", "al terminar no dijo «¡Plan cumplido!»")
    TM.Empezar(TM.Armar(60))
    TM.Dejar()
    check(TM.Actual() == nil, "«Dejar el plan» no lo dejó")
  end, function() return nl end)
end)

step("En Hoy: el plan en marcha va arriba, con su avance", function()
  local P = I.Pagina
  conPlan(function()
    A.Set("inicio.horaMin", 60)
    A.Fire("SHOW_OPTIONS", "inicio")
    RUN_TIMERS(3)
    check(P.hora and P.hora:IsShown(), "no está «¿Cuánto tiempo tienes?» en Hoy")
    if not (P.hora and P.hora:IsShown()) then return end
    check(P.hora.Elegir:IsShown() and P.hora.Elegir:Valor() == 60, "no está elegida 1 h")
    check(#P.hora.Pasos.elementos >= 3, "Hoy no muestra los pasos del plan")
    check(P.hora.Pie:IsShown() and (P.hora.Pie.Texto:GetText() or ""):find("6 min por misión", 1, true), "el pie no dice tu ritmo: " .. tostring(P.hora.Pie.Texto:GetText()))
    -- Otro: la barra de minutos.
    P.hora.Elegir.alCambiar("otro")
    RUN_TIMERS(2)
    check(P.hora.Otro:IsShown(), "«Otro» no mostró la barra de minutos")
    P.hora.Elegir.alCambiar(120)
    RUN_TIMERS(2)
    check(A.Get("inicio.horaMin") == 120 and not P.hora.Otro:IsShown(), "2 h no quedó elegida")
    -- Empezar desde el pie.
    llamadas = {}
    P.hora.Pie.Boton:Click()
    RUN_TIMERS(3)
    check(TM.Actual() ~= nil and (llamadas[1] == "vuelta" or llamadas[1] == "entregar"), "«Empezar» de Hoy no empezó el plan")
    A.Fire("SHOW_OPTIONS", "inicio")
    RUN_TIMERS(3)
    check(P.tablero.bloques[1] and P.tablero.bloques[1].b == P.hora, "con el plan en marcha, no va hasta arriba de Hoy")
    check(P.hora.Ahora:IsShown() and not P.hora.Elegir:IsShown(), "en marcha no muestra el paso de ahora")
    local s = P.hora.Seccion
    TM.Dejar()
    RUN_TIMERS(3)
    A.Set("inicio.horaPlan", false)
    RUN_TIMERS(3)
    check(not P.hora:IsShown(), "apagado, «¿Cuánto tiempo tienes?» sigue en Hoy")
    A.Set("inicio.horaPlan", true)
    A.Set("inicio.horaMin", 60)
    RUN_TIMERS(3)
  end, function() return 3 end)
end)

---------------------------------------------------------------------------
-- 27. Camino al 60
---------------------------------------------------------------------------

local GUIAS = {
  { id = "g1", title = "Los Baldíos 1", zoneName = "Los Baldíos", minLevel = 12, maxLevel = 22 },
  { id = "g2", title = "Sierra Espolón", zoneName = "Sierra Espolón", minLevel = 22, maxLevel = 28 },
  { id = "g3", title = "Laderas", zoneName = "Laderas de Trabalomas", minLevel = 28, maxLevel = 35, category = "Leveling" },
  { id = "gp", title = "Minería", minLevel = 1, maxLevel = 60, category = "Professions" },
  { id = "g4", title = "Tanaris", zoneName = "Tanaris", minLevel = 40, maxLevel = 50 },
  { id = "g5", title = "Cuna del Invierno", zoneName = "Cuna del Invierno", minLevel = 50, maxLevel = 60 },
}
local MAZ = {
  { key = "wc", name = "Cuevas de los Lamentos", kind = "dungeon", minLevel = 17, maxLevel = 24 },
  { key = "sm", name = "Monasterio Escarlata", kind = "dungeon", minLevel = 28, maxLevel = 45 },
  { key = "mc", name = "Núcleo de Magma", kind = "raid", minLevel = 60, maxLevel = 60 },
}

step("Camino al 60: lo que falta, tu ritmo y tus tramos", function()
  local c = N.DatosPersonaje("inicio")
  local hoy, ayer = date("%Y%m%d"), date("%Y%m%d", time() - 86400)
  c.camino = { dias = {
    [hoy] = { t = time(), desde = 22.0, hasta = 23.42, xp = 20000, seg = 3600 },
    [ayer] = { t = time() - 86400, desde = 21.0, hasta = 22.0, xp = 20000, seg = 3600 },
  } }
  local r = CA.Resumen()
  check(r and math.abs(r.faltan - 36.58) < 0.01, "no sabe cuántos niveles faltan")
  local falta = 10000 - 4200
  for l = 24, 59 do falta = falta + CA.XP[l] end
  check(r and r.xp == falta, "la XP que falta no cuadra: " .. tostring(r and r.xp))
  check(r and r.fuente == "dias" and math.abs(r.ritmo - 20000) < 1, "el ritmo no salió de tus días: " .. tostring(r and r.ritmo))
  check(r and math.abs(r.horas - falta / 20000) < 0.01, "las horas no son a tu ritmo")
  check(r and r.dias and r.dias >= 1, "no dice en cuántos días llegas")
  check(r and math.abs(r.hoy - 1.42) < 0.01, "no sabe cuánto avanzaste hoy")
  -- Un minuto más de juego suma a hoy.
  local S = I.Sesion
  local a = S.Actual()
  local antes = c.camino.dias[hoy].xp
  CA.Anotar()
  a.xp = (a.xp or 0) + 500
  NOW = NOW + 60
  CA.Anotar()
  check(c.camino.dias[hoy].xp == antes + 500, "el minuto de juego no sumó la XP de hoy")
  -- Los tramos con las guías y las mazmorras.
  con(A, { Guides = setmetatable({ List = function() return GUIAS end, GuideMatches = function() return true end, SuggestSource = false },
    { __index = A.Guides }) }, function()
    con(A, { Dungeons = { List = function() return MAZ end, BestAt = function(k) return ({ wc = 20, sm = 34, mc = 60 })[k] end,
      EnemyCapital = function() return nil end } }, function()
      local t = CA.Tramos()
      local d = {}
      for i, x in ipairs(t) do d[i] = x.desde .. "-" .. x.hasta .. ":" .. x.id end
      check(table.concat(d, " ") == "23-28:g2 29-35:g3 40-50:g4 51-60:g5", "los tramos no van de tu nivel al 60: " .. table.concat(d, " "))
      local m = CA.Mazmorras()
      check(#m == 1 and m[1].key == "sm", "las mazmorras del camino no son las de tu nivel en adelante (sin bandas): " .. #m)
      check(t[2] and t[2].mazmorras[1] and t[2].mazmorras[1].key == "sm", "el Monasterio no quedó en su tramo")
      -- La tarjeta y la ventana.
      local P = I.Pagina
      A.Fire("SHOW_OPTIONS", "inicio")
      RUN_TIMERS(3)
      check(P.camino and P.camino:IsShown(), "no está «Camino al 60» en Hoy")
      local tx = P.camino and P.camino.Tarjeta and P.camino.Tarjeta.Texto and P.camino.Tarjeta.Texto:GetText() or ""
      check(tx:find("Hoy avanzaste 1.4 niveles", 1, true), "la tarjeta no dice «Hoy avanzaste 1.4 niveles»: " .. tx)
      P.AbrirCamino()
      RUN_TIMERS(2)
      local VC = P.Camino
      check(VC.v and VC.v:IsShown(), "no se abrió la ventana del camino")
      check(#VC.rejTramos.elementos == 4 and #VC.rejMaz.elementos == 1 and #VC.rejDias.elementos == 2, "la ventana no tiene tus tramos, mazmorras y días")
      VC.v:Cerrar()
    end)
  end)
  A.Set("inicio.camino", false)
  RUN_TIMERS(3)
  check(not I.Pagina.camino:IsShown(), "apagado, «Camino al 60» sigue en Hoy")
  A.Set("inicio.camino", true)
  RUN_TIMERS(1)
end)

print(string.format("PRUEBA: 1.2.9 inicio, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
