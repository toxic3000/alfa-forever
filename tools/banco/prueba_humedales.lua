-- Prueba (1.2.2): el caso de Toxic, «Cerrar mis misiones» con 7 misiones de
-- Los Humedales, unas listas y otras a medias: el plan las hace y las entrega.
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

-- Toxic: un guerrero de la Alianza, nivel 28, en Los Humedales (14.6, 36.1).
function UnitFactionGroup() return "Alliance", "Alianza" end
function UnitRace() return "Humano", "Human", 1 end
function UnitLevel() return 28 end
function UnitEffectiveLevel() return 28 end
C_Map.GetBestMapForUnit = function() return 1437 end
C_Map.GetPlayerMapPosition = function() return { x = 0.146, y = 0.361, GetXY = function() return 0.146, 0.361 end } end

-- El registro de misiones del juego, a mano.
local LOG, ORDEN, HECHAS = {}, {}, {}
local TITULOS = { [285] = "Inspecciona más casuchas", [98208] = "Flor de los cielos", [472] = "La caída de Dun Modr", [464] = "Estandartes de batalla", [471] = "Deberes de aprendiz", [289] = "La tripulación maldita", [98221] = "Desde las cenizas" }
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
QL.GetInfo = function(i) local q = ORDEN[i] return q and { questID = q, title = TITULOS[q] or "?", isHeader = false, isHidden = false, level = 27 } or nil end
QL.GetLogIndexForQuestID = function(q) for i, x in ipairs(ORDEN) do if x == q then return i end end return nil end
QL.IsQuestFlaggedCompleted = function(q) return HECHAS[q] or false end
QL.GetTitleForQuestID = function(q) return LOG[q] and TITULOS[q] or nil end
QL.GetQuestDifficultyLevel = function() return 27 end
local function registro() FIRE_EVENT("QUEST_LOG_UPDATE") T(3) end


-- Las 7 de su registro (1.2.2): 3 listas para entregar y 4 a medias.
poner(285, true)
poner(98208, true)
poner(472, true)
poner(464, false, { { text = "Estandarte de guerra Faucedraco: 0/8", type = "item", finished = false, numFulfilled = 0, numRequired = 8 } })
poner(471, false, { { text = "Piel de crocolisco gigante: 0/6", type = "item", finished = false, numFulfilled = 0, numRequired = 6 } })
poner(289, false, { { text = "Marinero maldito: 0/13", type = "monster", finished = false, numFulfilled = 0, numRequired = 13 },
  { text = "Marino maldito: 0/5", type = "monster", finished = false, numFulfilled = 0, numRequired = 5 } })
poner(98221, false, { objetivo("Plan de ataque: Puerto de Menethil destruido", false) })

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
local function describir()
  local out = {}
  for i = 1, E.GetStepCount() do
    local v = E.GetStepView(i)
    local m = {}
    for _, g in ipairs(v.goals) do m[#m + 1] = tostring(g.t) .. ":" .. tostring(g.quest) .. ":" .. tostring(g.status) end
    out[#out + 1] = i .. " " .. tostring(v.title) .. " [" .. table.concat(m, ", ") .. "]"
  end
  out[#out + 1] = "vista " .. tostring(E.GetStepIndex()) .. ", viva " .. tostring(E.GetLiveStep())
  return table.concat(out, "\n")
end

step("humedales: el plan de 7 misiones las hace y las entrega", function()
  local avisos, viejo = {}, Ru.Aviso
  Ru.Aviso = function(t, x, o) avisos[#avisos + 1] = tostring(t) .. ": " .. tostring(x) return viejo(t, x, o) end
  Ru.Cerrar.Ahora("todas")
  correr()
  Ru.Aviso = viejo
  for _, a in ipairs(avisos) do print("  aviso: " .. a) end
  local g = E.GetGuide()
  if not (g and g.id == Ru.Guias.IdLiberar()) then error("no se abrió el plan") end
  print(describir())
  if not E.GetStepIndex() then error("el plan no tiene paso") end
  local entregas, hacer = {}, {}
  for _, s in ipairs(g.steps) do
    for _, m in ipairs(s.goals) do
      if m.t == "turnin" then entregas[m.quest] = true end
      if m.quest and m.t ~= "turnin" and m.t ~= "note" then hacer[m.quest] = true end
    end
  end
  for _, q in ipairs({ 285, 98208, 472, 464, 471, 289, 98221 }) do
    if not entregas[q] then NOTE("humedales", "el plan no entrega " .. q) end
  end
  for _, q in ipairs({ 464, 471, 289 }) do
    if not hacer[q] then NOTE("humedales", "el plan no lleva a hacer " .. q) end
  end
end)
print("PRUEBA: humedales, " .. pasos .. " pasos, errores: " .. #ERRORS)
