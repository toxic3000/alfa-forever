-- Prueba de la 1.4.1: «Cerrar mis misiones» con todas para después.
--
-- Toxic: «Tengo 9 misiones en mi registro y le puse que me generara una ruta,
-- pero no hace nada, solo me manda el recuadro (Todas son para después) y ya.
-- Lo que esperaría es que, cuando seleccione esas, abajo salga aceptar y ya
-- se ponga el plan».
--   1. Con todas para después, vienen elegidas (las que se pueden ubicar) y el
--      botón grande dice «Armar la ruta con N»; un clic arma y ARRANCA la ruta.
--   2. Quitando casillas, el número baja; sin ninguna, el botón se apaga.
--   3. En un resumen normal, marcar una de «Para después» cambia el botón a
--      «Sumar 1 y empezar», y ese clic la mete y arranca.
--   4. Nada de esto deja paredes del ratón.
PRUEBA_AREA("1.4.1 misiones")
SNAPSHOTS = {}

function UnitFactionGroup() return "Alliance", "Alianza" end
function UnitRace() return "Humano", "Human", 1 end
function UnitLevel() return 33 end
function UnitEffectiveLevel() return 33 end
C_Map.GetBestMapForUnit = function() return 1437 end
C_Map.GetPlayerMapPosition = function() return { x = 0.10, y = 0.60, GetXY = function() return 0.10, 0.60 end } end

-- El registro: una de mazmorra (Brazanegra) y dos grises sin terminar: las tres «para después».
local LOG, ORDEN, HECHAS, NIVEL = {}, {}, { [169] = true }, { [416] = 11, [418] = 11, [1199] = 25, [1105] = 30, [1176] = 30, [512] = 36 }
local function poner(q, listo)
  if not LOG[q] then ORDEN[#ORDEN + 1] = q end
  LOG[q] = { listo = listo, objs = { { text = "Algo: " .. (listo and "5/5" or "1/5"), type = "monster", finished = listo, numFulfilled = listo and 5 or 1, numRequired = 5 } } }
end
local function quitar(q)
  LOG[q] = nil
  for i = #ORDEN, 1, -1 do if ORDEN[i] == q then table.remove(ORDEN, i) end end
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
for _, q in ipairs({ 416, 418, 1199 }) do poner(q, false) end

PRUEBA_ENTRAR()
FIRE_EVENT("QUEST_LOG_UPDATE")
RUN_TIMERS(3)

local Ru = NS_OF("Alfa_Rutas")
local Ct, Cr = Ru.CerrarTodo, Ru.Cerrar

local marco
local function correr()
  for _ = 1, 4000 do
    RUN_TIMERS(1)
    if not Ru.Tareas.Alguna() then break end
    if not marco then
      for _, f in ipairs(ALL_FRAMES()) do
        local fn = rawget(f, "_scripts") and f._scripts.OnUpdate
        if fn and (debug.getinfo(fn, "S").source or ""):find("Tareas.lua", 1, true) then marco = f break end
      end
    end
    if marco then FIRE(marco, "OnUpdate", 0.016) end
  end
  RUN_TIMERS(3)
end
local function texto(b) local t = b and b.Texto and b.Texto:GetText() return tostring(t or "") end

PASO("Todas para después: vienen elegidas y un clic arma y arranca la ruta", function()
  Ru.Personaje().cerrarCuenta = nil
  Ct.Abrir({ origen = "hoy" })
  correr()
  local st = Ct.Estado()
  REVISA(st.fase == "vacio", "no quedó en «Todas son para después»: " .. tostring(st.fase))
  local d = st.info and st.info.despues or {}
  REVISA(#d == 3, "«Para después» no trae las 3: " .. #d)
  local v = Ct.Ventana()
  local puede = 0
  for _, x in ipairs(d) do if x.puede ~= false then puede = puede + 1 end end
  REVISA(puede > 0, "ninguna de «Para después» se puede ubicar (el banco no las sabe)")
  REVISA(type(Ct.NumElegidas) == "function" and Ct.NumElegidas() == puede, "no vienen elegidas las que pueden entrar")
  REVISA(v.Empezar:IsShown(), "con todas para después no hay botón para armar la ruta (el bug de Toxic)")
  REVISA(texto(v.Empezar):find(tostring(puede), 1, true), "el botón no dice cuántas mete: " .. texto(v.Empezar))
  REVISA(v.Empezar:IsEnabled() ~= false, "el botón de armar está apagado")
  -- Quitar una casilla baja el número; quitar todas apaga el botón.
  Ct.Elegir(d[1].id, false)
  REVISA(Ct.NumElegidas() == puede - 1, "quitar la casilla no bajó el número")
  for _, x in ipairs(d) do Ct.Elegir(x.id, false) end
  REVISA(Ct.NumElegidas() == 0 and v.Empezar:IsEnabled() == false, "sin ninguna elegida el botón sigue prendido")
  for _, x in ipairs(d) do if x.puede ~= false then Ct.Elegir(x.id, true) end end
  -- El clic: mete las elegidas, arma y arranca sola.
  v.Empezar:Click()
  correr()
  REVISA(st.yaEmpezo == true, "«Armar la ruta» no arrancó la ruta (fase " .. tostring(st.fase) .. ")")
  REVISA(type(Ru.Personaje().cerrarCuenta) == "table", "la ruta no quedó en marcha")
  REVISA(not v:IsShown(), "la ventana no se cerró al arrancar la ruta")
  for _, x in ipairs(d) do Ru.Personaje().incluir[x.id] = nil end
end)

PASO("Resumen normal: marcar una de «Para después» la suma y arranca", function()
  poner(1105, false)
  poner(512, true)
  FIRE_EVENT("QUEST_LOG_UPDATE")
  RUN_TIMERS(3)
  Ru.Personaje().cerrarCuenta = nil
  Ct.Abrir({ origen = "hoy" })
  correr()
  local st = Ct.Estado()
  REVISA(st.fase == "resumen", "no llegó al resumen: " .. tostring(st.fase))
  local v = Ct.Ventana()
  REVISA(Ct.NumElegidas() == 0, "en un resumen normal ya venían elegidas las de «Para después»")
  REVISA(texto(v.Empezar) == Ru.L["Empezar"], "el botón no dice «Empezar»: " .. texto(v.Empezar))
  local d, una = st.info.despues or {}, nil
  for _, x in ipairs(d) do if x.puede ~= false then una = x.id break end end
  REVISA(una, "no hay una de «Para después» que pueda entrar")
  if not una then return end
  Ct.Elegir(una, true)
  REVISA(texto(v.Empezar):find("1", 1, true), "con una marcada el botón no dice «Sumar 1…»: " .. texto(v.Empezar))
  v.Empezar:Click()
  correr()
  REVISA(st.yaEmpezo == true, "«Sumar 1 y empezar» no arrancó")
  REVISA(st.sello and st.sello.dentro and st.sello.dentro[una], "la elegida no entró a la ruta")
  Ru.Personaje().incluir[una] = nil
  quitar(1105) quitar(512)
end)

PASO("El ratón sigue siendo del jugador", function() TIEMPO(5) RATON_LIMPIO("tras cerrar mis misiones") end)

PRUEBA_FIN()
