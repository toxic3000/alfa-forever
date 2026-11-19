-- Prueba del área de rutas (tools/prueba.py la corre): el plan "Cerrar mis
-- misiones" con una misión del registro sin terminar, como en el juego.
--
-- El caso de un probador: la cadena "La limpieza de Raene" de Vallefresno (991,
-- 1023, 1024, 1026, 1027... todas con el mismo título; 1026 y 1027 las da y las
-- recibe Shael'dryn). Con 1026 en el registro sin el Asta de hierro, la guía
-- nunca debe mandarte a entregarla: ni en su paso, ni al mirar el paso de la
-- entrega con Siguiente (la flecha va al paso que miras), ni con un plan viejo
-- sin la guarda. Al entregar 1026 y tomar 1027 el plan se pone al día solo.
-- Cualquier error sale como "FALLA EN: <paso>" y run.py termina con código 1.
SNAPSHOTS = {}
local pasos = 0
-- Las trampas (como tools/banco/prueba_kit.lua): abrir desde el código de
-- Alfa una ventana de Blizzard que el juego luego bloquea es el error; se
-- anota (Alfa podría llamarla en un pcall) y se revisa al final de cada paso.
local mal, abiertas = {}, {}
local function trampa(nombre)
  return function() mal[#mal + 1] = nombre error("Alfa abrió desde su código: " .. nombre .. " (usa K.Seguro)") end
end
ToggleLegacySystemUI = trampa("ToggleLegacySystemUI")
-- El botón del juego que sí puede "clicar" el botón seguro.
local function micro(nombre)
  local b = CreateFrame("Button", nombre, UIParent)
  b:SetScript("OnClick", function() abiertas[nombre] = (abiertas[nombre] or 0) + 1 end)
  return b
end
micro("LegacyMicroButton")
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #mal > 0 then
    NOTE("paso " .. nombre, "Alfa abrió desde su código: " .. table.concat(mal, ", ") .. " (usa K.Seguro)")
    for i = #mal, 1, -1 do mal[i] = nil end
  end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function T(n) RUN_TIMERS(n or 2) end

-- Un personaje de la Alianza en Astranaar, junto a Shael'dryn.
function UnitFactionGroup() return "Alliance", "Alianza" end
function UnitRace() return "Elfo de la noche", "NightElf", 4 end
function UnitLevel() return 24 end
function UnitEffectiveLevel() return 24 end
C_Map.GetBestMapForUnit = function() return 1440 end
C_Map.GetPlayerMapPosition = function() return { x = 0.535, y = 0.47, GetXY = function() return 0.535, 0.47 end } end

-- El registro de misiones del juego, a mano.
local LOG, ORDEN, HECHAS = {}, {}, {}
local function poner(q, listo, objs)
  if not LOG[q] then ORDEN[#ORDEN + 1] = q end
  LOG[q] = { listo = listo, objs = objs or {} }
end
local function quitar(q)
  LOG[q] = nil
  for i = #ORDEN, 1, -1 do if ORDEN[i] == q then table.remove(ORDEN, i) end end
end
local function objetivo(texto, hecho) return { text = texto .. (hecho and ": 1/1" or ": 0/1"), type = "item", finished = hecho, numFulfilled = hecho and 1 or 0, numRequired = 1 } end
local QL = C_QuestLog
QL.IsOnQuest = function(q) return LOG[q] ~= nil end
QL.ReadyForTurnIn = function(q) return LOG[q] ~= nil and LOG[q].listo or false end
QL.IsComplete = function(q) return LOG[q] ~= nil and LOG[q].listo or false end
QL.IsFailed = function() return false end
QL.GetQuestObjectives = function(q) return LOG[q] and LOG[q].objs or {} end
QL.GetNumQuestLogEntries = function() return #ORDEN, #ORDEN end
QL.GetInfo = function(i) local q = ORDEN[i] return q and { questID = q, title = "La limpieza de Raene", isHeader = false, isHidden = false, level = 27 } or nil end
QL.GetLogIndexForQuestID = function(q) for i, x in ipairs(ORDEN) do if x == q then return i end end return nil end
QL.IsQuestFlaggedCompleted = function(q) return HECHAS[q] or false end
QL.GetTitleForQuestID = function(q) return LOG[q] and "La limpieza de Raene" or nil end
QL.GetQuestDifficultyLevel = function() return 27 end
local function registro() FIRE_EVENT("QUEST_LOG_UPDATE") T(3) end

for _, q in ipairs({ 991, 1023, 1024 }) do HECHAS[q] = true end
poner(1026, false, { objetivo("Asta de hierro", false) })

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
registro()
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end

local A = Alfa
local E = A.Engine
local Ru = NS_OF("Alfa_Rutas")

-- Las tareas de Alfa corren en el OnUpdate de su marco (Tareas.lua).
local marco
local function correr()
  for _ = 1, 4000 do
    T(1)
    if not Ru.Tareas.Alguna() then break end
    if not marco then
      for _, f in ipairs(ALL_FRAMES()) do
        local fn = rawget(f, "_scripts") and f._scripts.OnUpdate
        if fn and (debug.getinfo(fn, "S").source or ""):find("Tareas.lua", 1, true) then marco = f break end
      end
    end
    if marco then FIRE(marco, "OnUpdate", 0.016) end
  end
  T(5)
end

local function meta(s, g)
  local guia = E.GetGuide()
  return guia and guia.steps[s] and guia.steps[s].goals[g]
end
-- La meta a la que apunta la flecha.
local function metaFlecha()
  local wp = E.GetWaypoint()
  return wp and meta(wp.stepIndex, wp.goalIndex), wp
end
local function describir()
  local out = {}
  for i = 1, E.GetStepCount() do
    local v = E.GetStepView(i)
    local m = {}
    for _, g in ipairs(v.goals) do m[#m + 1] = tostring(g.t) .. ":" .. tostring(g.quest) .. ":" .. tostring(g.status) end
    out[#out + 1] = i .. " " .. tostring(v.title) .. " [" .. table.concat(m, ", ") .. "]"
  end
  local g, wp = metaFlecha()
  out[#out + 1] = "vista " .. tostring(E.GetStepIndex()) .. ", viva " .. tostring(E.GetLiveStep()) .. ", flecha " .. tostring(wp and wp.label) .. " (" .. tostring(g and g.t) .. ")"
  return table.concat(out, "\n")
end
-- Los textos a la vista dentro de un marco (el rastreador).
local function textos(f, out)
  out = out or {}
  if not f or not f:IsShown() then return out end
  if f._kind == "FontString" and type(f._text) == "string" then out[#out + 1] = f._text end
  for _, h in ipairs(rawget(f, "_children") or {}) do textos(h, out) end
  return out
end
local function rastreadorDice(trozo)
  Ru.Rastreador.Pintar()
  for _, t in ipairs(textos(_G.AlfaRastreador)) do
    if t:find(trozo, 1, true) then return true end
  end
  return false
end
-- El paso de la entrega de q y su índice de meta.
local function entrega(q)
  local guia = E.GetGuide()
  for s, paso in ipairs(guia and guia.steps or {}) do
    for g, m in ipairs(paso.goals) do
      if m.t == "turnin" and m.quest == q then return s, g end
    end
  end
end

---------------------------------------------------------------------------
-- 1. El plan con 1026 sin terminar
---------------------------------------------------------------------------
step("rutas: armar «Cerrar mis misiones» con una misión sin terminar", function()
  Ru.Cerrar.Ahora("todas")
  correr()
  local guia = E.GetGuide()
  if not (guia and guia.id == Ru.Guias.IdLiberar()) then error("no se abrió el plan para cerrar tus misiones") end
  Ru.Rastreador.Mostrar() T(2)
  local s, g = entrega(1026)
  if not s then error("el plan no entrega La limpieza de Raene (1026)\n" .. describir()) end
  local antes = meta(s, g - 1)
  if not (antes and antes.t == "complete" and antes.quest == 1026) then
    error("la entrega de 1026 no lleva antes «Completa la misión»\n" .. describir())
  end
  local fl = metaFlecha()
  if not fl or fl.t == "turnin" then error("la flecha manda a entregar una misión sin terminar\n" .. describir()) end
end)

step("rutas: Siguiente al paso de la entrega no manda al PNJ", function()
  local s = entrega(1026)
  local live = E.GetLiveStep()
  if not (s and live and s ~= live) then error("el paso de la entrega debía venir después del de ahora\n" .. describir()) end
  E.Goto(s) T(2)
  local fl = metaFlecha()
  if not fl or fl.t == "turnin" then error("mirando el paso de la entrega, la flecha va al PNJ\n" .. describir()) end
  if fl.quest ~= 1026 then error("la flecha no va a lo que le falta a 1026\n" .. describir()) end
  if not rastreadorDice("La flecha te lleva a este paso") then error("el aviso no dice que la flecha va al paso que miras") end
  if not rastreadorDice("Vista previa: paso") then error("el aviso no dice que es una vista previa") end
  if not rastreadorDice("Tu paso de ahora es el") then error("el aviso no dice cuál es el paso de ahora") end
  if not rastreadorDice("Ver el siguiente") then error("el botón «Siguiente» no dice que solo es para mirar") end
  if rastreadorDice("Omitir") then error("en la vista previa, «Omitir» saltaría el paso que miras") end
  E.Goto(live) T(2)
  if not rastreadorDice("Omitir") then error("en el paso de ahora no está «Omitir»") end
  if E.GetStepIndex() ~= live then error("«Volver al paso de ahora» no volvió") end
end)

---------------------------------------------------------------------------
-- 2. Un plan viejo (sin la guarda) o una guía del motor: solo "Entrega"
---------------------------------------------------------------------------
step("rutas: una entrega sin terminar dice qué falta", function()
  local id = Ru.Guias.IdEspecial("recoger")
  local def = Ru.Guias.Def(id, "Plan viejo", {
    { title = "Shael'dryn", goals = { { t = "turnin", quest = 1026, title = "La limpieza de Raene", npc = 3916, npcName = "Shael'dryn", map = 1440, x = 53.5, y = 46.2 } } },
  })
  if not Ru.Guias.Instalar(def) then error("no se instaló la guía de prueba") end
  Ru.Guias.Abrir(id) T(3)
  local g = E.GetGuide()
  if not (g and g.id == id) then error("no se abrió la guía de prueba") end
  Ru.Rastreador.Mostrar() T(2)
  if not rastreadorDice("aún no está terminada") then error("el rastreador no avisa que la misión no está terminada\n" .. describir()) end
  if not rastreadorDice("Asta de hierro (0/1)") then error("el aviso no dice qué falta") end
  -- Lista: el aviso se va.
  LOG[1026].objs = { objetivo("Asta de hierro", true) } LOG[1026].listo = true
  registro()
  if rastreadorDice("aún no está terminada") then error("con la misión lista, el aviso sigue") end
  LOG[1026].objs = { objetivo("Asta de hierro", false) } LOG[1026].listo = false
  registro()
  Ru.Guias.Abrir(Ru.Guias.IdLiberar()) T(3)
end)

---------------------------------------------------------------------------
-- 3. El registro cambia: entregas 1026 y tomas 1027 (mismo título y PNJ)
---------------------------------------------------------------------------
step("rutas: terminar 1026 y entregarla", function()
  LOG[1026].objs = { objetivo("Asta de hierro", true) } LOG[1026].listo = true
  registro()
  local fl = metaFlecha()
  if not (fl and fl.t == "turnin" and fl.quest == 1026) then error("con 1026 lista, la flecha no va a entregarla\n" .. describir()) end
  if rastreadorDice("aún no está terminada") then error("avisa que no está terminada una misión lista") end
  quitar(1026) HECHAS[1026] = true
  FIRE_EVENT("QUEST_TURNED_IN", 1026, 0, 0)
  FIRE_EVENT("QUEST_REMOVED", 1026)
  registro()
  local s, g = entrega(1026)
  if not (s and E.GoalDone(s, g)) then error("la entrega de 1026 no quedó hecha (por id)\n" .. describir()) end
end)

step("rutas: tomar 1027 pone el plan al día solo", function()
  poner(1027, false, { objetivo("Pomo de hierro", false) })
  FIRE_EVENT("QUEST_ACCEPTED", 1027)
  registro()
  correr()
  T(5)
  correr()
  local g = E.GetGuide()
  if not (g and g.id == Ru.Guias.IdLiberar()) then error("el plan ya no es la guía activa") end
  local s = entrega(1027)
  if not s then error("el plan no se puso al día con 1027\n" .. describir()) end
  local fl = metaFlecha()
  if not fl or fl.t == "turnin" or fl.quest ~= 1027 then error("la flecha no va a lo que falta de 1027\n" .. describir()) end
  local sello = Ru.Personaje().liberarSello
  if not (sello and sello.log and sello.log[1027] == false) then error("el plan no guardó lo que vio del registro") end
  if not Ru.Cerrar.AlDia() then error("el plan sigue sin estar al día") end
end)

---------------------------------------------------------------------------
-- 3b. (1.2.2) Omitir todos los pasos y volver a pedir el plan: antes el
-- motor les devolvía lo omitido (los reconoce por su contenido) y el plan
-- quedaba sin paso, ni terminado ni con algo que seguir.
---------------------------------------------------------------------------
step("rutas: un plan pedido otra vez no hereda los pasos omitidos", function()
  local n = 0
  while E.GetStepIndex() and n < 40 do E.Skip() n = n + 1 T(1) end
  if E.GetStepIndex() then error("no se pudieron omitir todos los pasos") end
  local hechos, todos = E.GetProgress()
  print("  todo omitido: " .. tostring(hechos) .. " de " .. tostring(todos) .. " hechos, sin paso")
  Ru.Cerrar.Ahora("todas")
  correr()
  T(3)
  local g = E.GetGuide()
  if not (g and g.id == Ru.Guias.IdLiberar()) then error("el plan nuevo no es la guía activa") end
  if not E.GetStepIndex() then error("el plan pedido otra vez sigue sin paso (heredó lo omitido)\n" .. describir()) end
end)

---------------------------------------------------------------------------
-- 4. Una misión sin objetivos en el Codex que el registro sí lista
---------------------------------------------------------------------------
step("rutas: objetivos que solo da el registro", function()
  quitar(1027) HECHAS[1027] = true
  -- 1028: el Codex no le da objetivos; aquí el juego lista uno sin hacer.
  poner(1028, false, { objetivo("Ofrenda en el santuario", false) })
  registro()
  local C = A.Codex
  local q = C.Quest(1028)
  if not q or #(q.objectives or {}) > 0 then print("AVISO: 1028 trae objetivos en el Codex; la prueba no aplica") return end
  local pm = Ru.Indice.PasosMision(q, A.PlayerPoint())
  if not (pm and pm.objetivos[1] and pm.objetivos[1].t == "complete") then error("sin objetivos en el Codex, el plan no pide completarla") end
  -- Y en una ruta: sus pasos piden completarla antes de entregarla.
  local pasosR = Ru.Plan.PasosMisiones({ 1028 }, A.PlayerPoint(), function() end, {})
  local vista = {}
  for _, p in ipairs(pasosR) do for _, m in ipairs(p.goals) do vista[#vista + 1] = m.t end end
  local hecha, entregada = nil, nil
  for i, t in ipairs(vista) do
    if t == "complete" and not hecha then hecha = i end
    if t == "turnin" then entregada = i end
  end
  if not (hecha and entregada and hecha < entregada) then error("la ruta entrega 1028 sin pedir completarla: " .. table.concat(vista, ", ")) end
end)

-- Títulos y notas del motor que quedaron en inglés: no se muestran.
step("rutas: textos en inglés del motor", function()
  local S = Ru.Rastreador.SinTraducir
  for _, s in ipairs({ "Into Vallefresno", "Ve a The road north to Astranaar", "Gornek's hunt targets", "Kill the boars near the farm" }) do
    if not S(s) then error("no reconoce como inglés: " .. s) end
  end
  for _, s in ipairs({ "La limpieza de Raene", "Shael'dryn", "Llega a nivel 24", "Consigue Asta de hierro de Cofre desgastado", "Raene Correlobo" }) do
    if S(s) then error("toma como inglés: " .. s) end
  end
end)

---------------------------------------------------------------------------
-- 5. La Enciclopedia: «Abrir el Legado del juego» lo abre el juego
---------------------------------------------------------------------------
-- Con el botón seguro (clic en LegacyMicroButton); el clic normal solo dice
-- cómo abrirla. Nunca ToggleLegacySystemUI desde Alfa (la trampa).
local K = AlfaNucleo.Kit
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
local function clicSeguro(s)
  s:Click("LeftButton")
  if s:GetAttribute("type") ~= "click" then error("el botón seguro no hace clic en un botón del juego") end
  local d = s:GetAttribute("clickbutton")
  if not d then error("el botón seguro no tiene clickbutton") end
  d:Click("LeftButton")
end
step("enciclopedia: el Legado del juego con el botón seguro, sin abrirlo desde Alfa", function()
  local En = AlfaEnciclopedia
  if not En then print("AVISO: sin Enciclopedia") return end
  A.RunCommand("legado") T(2)
  if not (En.Visible and En.Visible()) then error("/alfa legado no abrió la Enciclopedia") end
  local b
  for _, f in ipairs(ALL_FRAMES()) do
    local tx = rawget(f, "Texto")
    if type(tx) == "table" and tx.GetText and tx:GetText() == "Abrir el Legado del juego" and f:IsVisible() then b = f end
  end
  if not b then error("la guía del Legado no tiene el botón «Abrir el Legado del juego»") end
  -- Con el ratón encima: el botón seguro lo cubre y el clic lo hace el juego.
  local antes = abiertas.LegacyMicroButton or 0
  FIRE(b, "OnEnter")
  local s = _G.AlfaKitSeguro
  if not (s and s:IsShown() and s.dueno == b) then error("el botón seguro no cubrió «Abrir el Legado del juego»") end
  if s:GetAttribute("clickbutton") ~= _G.LegacyMicroButton then error("el botón seguro no apunta a LegacyMicroButton") end
  clicSeguro(s)
  FIRE(s, "OnLeave")
  if (abiertas.LegacyMicroButton or 0) ~= antes + 1 then error("el clic no llegó al botón del Legado del juego") end
  -- El clic normal (sin botón seguro): solo un aviso que dice cómo abrirla.
  local avisos, viejo = {}, K.Aviso
  K.Aviso = function(o) avisos[#avisos + 1] = o return viejo(o) end
  local ok, e = pcall(FIRE, b, "OnClick", "LeftButton")
  K.Aviso = viejo
  if not ok then error(e) end
  local texto = avisos[#avisos] and tostring(avisos[#avisos].texto or "") or ""
  if not texto:find("men", 1, true) then error("sin botón seguro no dice cómo abrir la ventana del Legado: " .. texto) end
  T(1)
  if En.Cerrar then En.Cerrar() end
end)

print("PRUEBA: rutas, " .. pasos .. " pasos, errores: " .. #ERRORS)
