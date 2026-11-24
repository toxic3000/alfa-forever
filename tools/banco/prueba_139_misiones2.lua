-- Prueba de la 1.3.9, área misiones, ronda 2: lo raro que se veía con el
-- registro real de Toxic (guerrero humano de nivel 33 en Los Humedales, con
-- misiones grises de Loch Modan, de Brazanegra, de Las Mil Agujas y de
-- Alterac, y «Entregar mis misiones» terminada):
--   1. el plan de misiones terminado con misiones en el registro decía
--      «¡Terminaste tu guía! Elige qué sigue»: ahora «¡Plan cumplido! Te
--      quedan N…» con «Cerrar mis N misiones» (rastreador, Ruta y Hoy);
--   2. las grises sin terminar mandaban primero a Loch Modan a nivel 33:
--      ahora van a «Para después», al final, con su porqué;
--   3. las de mazmorra dicen dónde (no solo «Pide grupo»), y si son grises;
--   4. lo que queda fuera es una sola nota, con su porqué de verdad (no
--      «la dejaste fuera» de lo que dejó fuera el atajo «solo listas»);
--   5. la zona de una parada de entrega es la de su PNJ.
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
local function check(cond, msg) if not cond then NOTE("1.3.9 misiones 2", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

function UnitFactionGroup() return "Alliance", "Alianza" end
function UnitRace() return "Humano", "Human", 1 end
function UnitLevel() return 33 end
function UnitEffectiveLevel() return 33 end
C_Map.GetBestMapForUnit = function() return 1437 end
C_Map.GetPlayerMapPosition = function() return { x = 0.10, y = 0.60, GetXY = function() return 0.10, 0.60 end } end

local LOG, ORDEN, HECHAS, NIVEL = {}, {}, { [169] = true }, { [416] = 11, [418] = 11, [1199] = 25, [1105] = 30, [1176] = 30, [512] = 36 }
local function poner(q, listo)
  if not LOG[q] then ORDEN[#ORDEN + 1] = q end
  LOG[q] = { listo = listo, objs = { { text = "Algo: " .. (listo and "5/5" or "1/5"), type = "monster", finished = listo, numFulfilled = listo and 5 or 1, numRequired = 5 } } }
end
local QL = C_QuestLog
QL.IsOnQuest = function(q) return LOG[q] ~= nil end
QL.ReadyForTurnIn = function(q) return LOG[q] ~= nil and LOG[q].listo or false end
QL.IsComplete = function(q) return LOG[q] ~= nil and LOG[q].listo or false end
QL.IsFailed = function() return false end
QL.GetQuestObjectives = function(q) return LOG[q] and LOG[q].objs or {} end
QL.GetNumQuestLogEntries = function() return #ORDEN, #ORDEN end
QL.GetInfo = function(i) local q = ORDEN[i] return q and { questID = q, title = "Misión " .. q, isHeader = false, isHidden = false, level = NIVEL[q] or 33 } or nil end
QL.GetLogIndexForQuestID = function(q) for i, x in ipairs(ORDEN) do if x == q then return i end end return nil end
QL.IsQuestFlaggedCompleted = function(q) return HECHAS[q] or false end
QL.GetTitleForQuestID = function(q) return LOG[q] and ("Misión " .. q) or nil end
QL.GetQuestDifficultyLevel = function(q) return NIVEL[q] or 33 end
local function registro() FIRE_EVENT("QUEST_LOG_UPDATE") T(3) end
for _, q in ipairs({ 416, 418, 1199, 1105, 1176, 512 }) do poner(q, false) end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
registro()

local A = Alfa
local K = AlfaNucleo.Kit
local E = A.Engine
local Ru = NS_OF("Alfa_Rutas")
local Ct, Cr, Rs = Ru.CerrarTodo, Ru.Cerrar, Ru.Rastreador

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
  T(3)
end

---------------------------------------------------------------------------
step("Las grises sin terminar van a «Para después», al final; la de mazmorra dice dónde", function()
  Ct.Abrir({ origen = "hoy" })
  correr()
  local st = Ct.Estado()
  check(st.fase == "resumen", "no llegó al resumen: " .. tostring(st.fase))
  local enPlan = {}
  for qid in pairs(st.sello and st.sello.dentro or {}) do enPlan[qid] = true end
  check(not enPlan[416] and not enPlan[418], "las grises de nivel 11 siguen en la ruta de un nivel 33")
  check(enPlan[1105] and enPlan[1176] and enPlan[512], "las de su nivel no entraron")
  local d = st.info.despues or {}
  local orden = {}
  for i, x in ipairs(d) do orden[i] = x.id end
  check(#d == 3, "«Para después» no trae las 3: " .. table.concat(orden, ","))
  check(d[#d] and (d[#d].id == 416 or d[#d].id == 418), "las grises no van al final de «Para después»: " .. table.concat(orden, ","))
  local maz
  for _, x in ipairs(d) do if x.id == 1199 then maz = x end end
  check(maz and maz.por:find("mazmorra", 1, true) and maz.por:find("ya no da XP", 1, true),
    "la de Brazanegra no dice que es de mazmorra y gris: " .. tostring(maz and maz.por))
  for _, x in ipairs(d) do
    if x.id == 416 then check(x.por:find("experiencia", 1, true), "la gris no dice por qué: " .. tostring(x.por)) end
  end
  -- «Meterla» la mete (tú decides).
  Ct.Meter(416)
  correr()
  local dentro = st.sello and st.sello.dentro or {}
  check(dentro[416], "«Meterla» no metió la gris")
  Ru.Personaje().incluir[416] = nil
  -- La zona de la parada de entrega es la de su PNJ (no la de sus objetivos).
  local Pm
  for _, p in ipairs(st.paradas or {}) do if p.sub:find("Entregar", 1, true) and p.map then Pm = p end end
  check(Pm ~= nil, "no hay paradas de entrega")
  local def = st.def
  for _, paso in ipairs(def and def.steps or {}) do
    for _, g in ipairs(paso.goals) do
      if g.t == "turnin" and g.quest == 512 then
        for _, p in ipairs(st.paradas) do
          if p.titulo == paso.title then check(p.map == g.map, "la parada de la entrega de 512 dice otra zona: " .. tostring(p.map) .. " vs " .. tostring(g.map)) end
        end
      end
    end
  end
  Ct.Ventana():Cerrar()
end)

step("«Entregar mis misiones» (solo listas): lo de fuera, en una nota, con su porqué", function()
  poner(1105, true)
  registro()
  local def, sello
  Cr.Armar({ filtro = "listas" }, function(d, _, _, s) def, sello = d, s end)
  correr()
  check(def ~= nil, "no armó «Entregar mis misiones»")
  local notas = {}
  for _, paso in ipairs(def and def.steps or {}) do
    for _, g in ipairs(paso.goals) do if g.t == "note" and tostring(g.text):find("Fuera de este plan", 1, true) then notas[#notas + 1] = g.text end end
  end
  check(#notas == 1, "lo que queda fuera no va en una sola nota: " .. #notas)
  local n = notas[1] or ""
  check(not n:find("la dejaste fuera", 1, true), "dice «la dejaste fuera» de lo que dejó fuera el atajo: " .. n)
  check(n:find("aún no está lista", 1, true), "no dice que aún no está lista: " .. n)
  check(n:find("y %d+ más") ~= nil, "la nota no se corta con «y N más»: " .. n)
end)

step("El plan de misiones terminado con misiones en el registro: «¡Plan cumplido!» y «Cerrar mis N misiones»", function()
  -- El plan de Toxic: «Entregar mis misiones» con la 169 ya entregada.
  local id = Ru.Guias.IdLiberar()
  local defV = Ru.Guias.Def(id, "Entregar mis misiones", {
    { title = "Magistrado Solomon", goals = { { t = "turnin", quest = 169, title = "SE BUSCA: Gath'Ilzogg", npc = 344, npcName = "Magistrado Solomon", map = 1433, x = 29.7, y = 44.2 } } },
  })
  check(Ru.Guias.Instalar(defV), "no se instaló el plan viejo")
  Ru.Guias.Abrir(id) T(3)
  check(E.GetLiveStep() == nil, "el plan viejo no está terminado")
  local c = Rs.Cierre()
  -- (revisión 6: solo cuentan las que entrarían al plan; las 3 de «Para
  -- después», las grises y la de mazmorra, no)
  local entran = Cr.QuedanParaPlan()
  check(entran == #ORDEN - 3, "las que entrarían a un plan no son " .. (#ORDEN - 3) .. ": " .. tostring(entran))
  check(c and c.cerrar and c.quedan == entran, "el cierre no ofrece cerrar las del registro: " .. tostring(c and c.quedan))
  check(Rs.TextoCierre(c) == ("Cerrar mis " .. entran .. " misiones"), "el botón no dice «Cerrar mis N misiones»: " .. tostring(Rs.TextoCierre(c)))
  check(AlfaRuta.TextoPlanCumplido(c):find("Plan cumplido", 1, true), "Hoy no dice «¡Plan cumplido!»")
  Rs.Mostrar() T(2) Rs.Pintar()
  local F = rawget(_G, "AlfaRastreador")
  local dice = false
  local function ver(f)
    if not f:IsShown() then return end
    if f._kind == "FontString" and f._text and f._text:find("Plan cumplido", 1, true) then dice = true end
    for _, h in ipairs(rawget(f, "_children") or {}) do ver(h) end
  end
  ver(F)
  check(dice, "el rastreador no dice «¡Plan cumplido!»")
  Rs.SeguirCierre(c)
  check(Ct.Ventana() and Ct.Ventana():IsShown(), "«Cerrar mis N misiones» no abrió el resumen")
  correr()
  Ct.Ventana():Cerrar()
end)

print(("1.3.9 misiones 2: %d pasos, %d errores"):format(pasos, #ERRORS))
