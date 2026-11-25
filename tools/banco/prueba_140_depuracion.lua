-- Prueba de la 1.4.0, área depuración (plan 74; tools/prueba.py la corre con
-- las demás prueba_*.lua):
--   1. Indice.lua: un objetivo sin lugar porque su parte del Codex no está
--      leída (en combate, o la parte apagada) NO es «En mazmorra»: la misión
--      no va a «Para después» por ese motivo, sino como «Sin datos»; con los
--      datos leídos y el objetivo de verdad sin lugar, sigue siendo «dentro».
--   2. La X de una sugerencia del rastreador (llamaba a un `luego` global
--      que no existía: «attempt to call a nil value»).
--   3. Los ayudantes del Núcleo con secretos: N.LeerNumero, K.num, M.num de
--      Rutas y la tarjeta del personaje del motor (Theme.Clase).
--   4. Los íconos que no existían (ic-estrella, ic-hogar, lobo «contento»):
--      ahora apuntan a texturas del build (tools/texturas.py lo revisa todo).
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 900)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.4.0 depuracion", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

Alfa.Hidden = Alfa.Hidden or function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(8)
if Alfa.UI.Options.frame then Alfa.UI.Options.frame:Hide() end

local A, N = Alfa, AlfaNucleo
local K = N.Kit
local Ru = NS_OF("Alfa_Rutas")
local I, Cr = Ru.Indice, Ru.Cerrar

---------------------------------------------------------------------------
-- 1. «No sé dónde está» no es «está en una mazmorra»
---------------------------------------------------------------------------
-- Un Codex de mentira: la misión 990001 pide un objeto (de la parte de
-- objetos), la 990002 matar un PNJ (de la parte del mundo) y la 990003 un
-- objeto que de verdad no tiene lugar en el mundo.
local C, Lk, Cp = A.Codex, A.Lookup, A.Compat
local guarda = {}
local function guardar(t, nombres) for _, n in ipairs(nombres) do guarda[#guarda + 1] = { t, n, t[n] } end end
local function devolver() for i = #guarda, 1, -1 do local g = guarda[i] g[1][g[2]] = g[3] end guarda = {} end
local leida = { item = true, npc = true, object = true, quest = true }
local FIN = { map = 1411, x = 0.5, y = 0.5 }
local MISIONES = {
  [990001] = { id = 990001, title = "Colmillos", level = 10, objectives = { { type = "item", id = 70001, count = 5 } }, start = { npc = { 80001 } }, ["end"] = { npc = { 80001 } } },
  [990002] = { id = 990002, title = "Jabaespines", level = 10, objectives = { { type = "kill", id = 80002, count = 5 } }, start = { npc = { 80001 } }, ["end"] = { npc = { 80001 } } },
  [990003] = { id = 990003, title = "El cofre perdido", level = 10, objectives = { { type = "item", id = 70003, count = 1 } }, start = { npc = { 80001 } }, ["end"] = { npc = { 80001 } } },
}
local function montar()
  guardar(C, { "Quest", "Item", "Npc", "Object", "NeedGroup", "IsLoaded", "Name" })
  guardar(Lk, { "QuestEnd", "Nearest" })
  guardar(Cp, { "GetLogQuests", "IsOnQuest", "IsQuestReadyForTurnIn", "GetQuestLevel", "IsQuestFailed", "IsQuestTrivial", "GetQuestObjectives", "IsQuestCompleted" })
  C.IsLoaded = function() return true end
  C.NeedGroup = function(g) return leida[g] ~= false end
  C.Quest = function(id) if not leida.quest then return nil end return MISIONES[id] end
  C.Item = function(id)
    if not leida.item then return nil end
    if id == 70001 then return { id = id, name = "Colmillo", sources = { { type = "drop", npc = 80002, chance = 40 } } } end
    if id == 70003 then return { id = id, name = "Cofre", sources = {} } end
    return nil
  end
  C.Npc = function(id)
    if not leida.npc then return nil end
    if id == 80001 then return { id = id, name = "Gornek", spawns = { { map = 1411, x = 0.42, y = 0.68 } } } end
    if id == 80002 then return { id = id, name = "Jabaespín", spawns = { { map = 1411, x = 0.47, y = 0.52 } } } end
    return nil
  end
  C.Object = function() return nil end
  C.Name = function(_, id) return "Cosa " .. tostring(id) end
  Lk.Nearest = function(spawns) return spawns and spawns[1] or nil end
  Lk.QuestEnd = function() return { spawn = FIN, npc = 80001, name = "Gornek" } end
  Cp.GetLogQuests = function() return { 990001, 990002, 990003 } end
  Cp.IsOnQuest = function(q) return MISIONES[q] ~= nil end
  Cp.IsQuestReadyForTurnIn = function() return false end
  Cp.GetQuestLevel = function() return 10 end
  Cp.IsQuestFailed = function() return false end
  Cp.IsQuestTrivial = function() return false end
  Cp.GetQuestObjectives = function() return { { text = "x", finished = false } } end
  Cp.IsQuestCompleted = function() return false end
end

step("1: Indice.Objetivo distingue «sin datos leídos» de «dentro de una mazmorra»", function()
  montar()
  -- con todo leído: la 990001 tiene lugar; la 990003 de verdad no (dentro)
  leida.item, leida.npc = true, true
  local lugar, _, dentro, sinCargar = I.Objetivo({ id = 990001 })
  check(lugar ~= nil and not dentro and not sinCargar, "con todo leído, la 990001 no tiene lugar o sale «dentro»")
  lugar, _, dentro, sinCargar = I.Objetivo({ id = 990003 })
  check(lugar == nil and dentro == true and not sinCargar, "un objeto de verdad sin lugar dejó de contar como «dentro»")
  -- la parte de objetos sin leer (en combate): ni lugar, ni «dentro»
  leida.item = false
  lugar, _, dentro, sinCargar = I.Objetivo({ id = 990001 })
  check(lugar == nil and not dentro and sinCargar == true, ("sin la parte de objetos la 990001 sale dentro=%s sinCargar=%s"):format(tostring(dentro), tostring(sinCargar)))
  -- la parte del mundo sin leer: matar un PNJ tampoco es «dentro»
  leida.item, leida.npc = true, false
  lugar, _, dentro, sinCargar = I.Objetivo({ id = 990002 })
  check(not dentro and sinCargar == true, "sin la parte del mundo la 990002 sale «dentro»")
  -- el objeto se lee, pero quien lo suelta (la parte del mundo) no
  lugar, _, dentro, sinCargar = I.Objetivo({ id = 990001 })
  check(not dentro and sinCargar == true, "sin el PNJ que suelta el objeto la 990001 sale «dentro»")
  leida.item, leida.npc = true, true
  devolver()
end)

step("1: Indice.PasosMision marca sinCargar, no dentro", function()
  montar()
  leida.item = false
  local pm = I.PasosMision(MISIONES[990001], FIN)
  check(pm ~= nil, "sin la parte de objetos no armó los pasos de la 990001")
  if pm then check(not pm.dentro and pm.sinCargar == true, ("pasos de la 990001: dentro=%s sinCargar=%s"):format(tostring(pm.dentro), tostring(pm.sinCargar))) end
  leida.item = true
  pm = I.PasosMision(MISIONES[990003], FIN)
  check(pm and pm.dentro == true and not pm.sinCargar, "un objeto de verdad sin lugar dejó de contar como «dentro» en los pasos")
  pm = I.PasosMision(MISIONES[990001], FIN)
  check(pm and not pm.dentro and not pm.sinCargar, "con todo leído la 990001 sale dentro o sin datos")
  devolver()
end)

step("1: «Cerrar mis misiones» no manda a «En mazmorra» lo que no está leído", function()
  montar()
  local T0 = Ru.Tareas
  local lanzar = T0.Lanzar
  -- la revisión corre de una vez (en el juego, por pedacitos)
  T0.Lanzar = function(_, fn, fin) local ok, res = pcall(fn, function() end) fin(ok and res or nil, not ok and res or nil) if not ok then NOTE("revisar", res) end end
  leida.item = false
  local lista
  Cr.Revisar(function(l) lista = l end)
  T0.Lanzar = lanzar
  check(type(lista) == "table" and #lista == 3, "la revisión no dio las 3 misiones")
  for _, it in ipairs(lista or {}) do
    if it.id == 990001 then
      check(not it.dentro, "la 990001 (objeto sin leer) quedó «En mazmorra»")
      check(it.sinDatos and it.despues and not it.despues:find("mazmorra", 1, true), "la 990001 no dice «Sin datos»: " .. tostring(it.despues))
    elseif it.id == 990002 then
      check(not it.dentro and not it.sinDatos, "la 990002 (PNJ leído) quedó fuera de la ruta")
    elseif it.id == 990003 then
      check(not it.dentro and it.sinDatos, "la 990003 sin la parte de objetos quedó «En mazmorra»")
    end
  end
  -- con todo leído, la que de verdad no tiene lugar sigue yendo como mazmorra
  leida.item = true
  T0.Lanzar = function(_, fn, fin) local ok, res = pcall(fn, function() end) fin(ok and res or nil, not ok and res or nil) if not ok then NOTE("revisar", res) end end
  Cr.Revisar(function(l) lista = l end)
  T0.Lanzar = lanzar
  for _, it in ipairs(lista or {}) do
    if it.id == 990003 then check(it.dentro and it.despues and not it.sinDatos, "la 990003 (sin lugar de verdad) dejó de ir a «Para después» como mazmorra") end
    if it.id == 990001 then check(not it.dentro and not it.sinDatos, "con todo leído la 990001 quedó fuera") end
  end
  devolver()
end)

---------------------------------------------------------------------------
-- 2. La X de una sugerencia del rastreador
---------------------------------------------------------------------------
step("2: la X de una sugerencia no truena", function()
  local Rs = Ru.Rastreador
  if Rs.Mostrar then Rs.Mostrar() end
  T(2)
  local b = Rs.Piezas().aviso
  check(b and b.Cerrar, "no encontré el aviso del rastreador")
  if not (b and b.Cerrar) then return end
  local cerrada = false
  b.alfaDatos = { titulo = "Una sugerencia", cerrar = function() cerrada = true end }
  local antes = #ERRORS
  FIRE(b.Cerrar, "OnClick", "LeftButton")
  T(2)
  check(cerrada, "la X no llamó a cerrar")
  check(#ERRORS == antes, "la X tronó")
end)

---------------------------------------------------------------------------
-- 3. Los ayudantes con secretos
---------------------------------------------------------------------------
step("3: N.LeerNumero, K.num y M.num con secretos", function()
  check(N.LeerNumero(5) == 5 and N.LeerNumero("7") == 7, "N.LeerNumero no lee un número")
  check(N.LeerNumero(nil, 3) == 3 and N.LeerNumero("x", 3) == 3 and N.LeerNumero(0 / 0, 3) == 3, "N.LeerNumero no da el de repuesto")
  check(N.LeerNumero(SECRETO(9), 1) == 1, "N.LeerNumero dejó pasar un secreto")
  check(K.num(SECRETO(9), 2) == 2 and K.num(4, 2) == 4, "K.num dejó pasar un secreto")
  check(Ru.num(SECRETO(9), 2) == 2 and Ru.num(4, 2) == 4, "M.num de Rutas dejó pasar un secreto")
  -- el patrón viejo «N.Leer and N.Leer(x) or x» devolvía el secreto
  local s = SECRETO(9)
  check(issecretvalue(N.Leer and N.Leer(s) or s), "(el banco ya no imita el problema del «or»)")
end)

step("3: la tarjeta del personaje y las guías sugeridas con el nivel y la clase en secreto", function()
  SECRETOS_PRENDER({ "UnitClass", "UnitLevel", "UnitName" })
  local Th = NS_OF("Alfa").Theme
  local ok, c = pcall(Th.Clase)
  check(ok and type(c) == "table" and not issecretvalue(c.nombre) and not issecretvalue(c.archivo), "Theme.Clase devolvió un secreto: " .. tostring(c))
  local Sg = Ru.Siguiente
  if Sg and Sg.Buscar then
    local ok2, e = pcall(Sg.Buscar)
    check(ok2, "Siguiente.Buscar tronó con el nivel en secreto: " .. tostring(e))
  end
  A.Fire("SHOW_OPTIONS", "inicio")
  T(2)
  if A.UI.Options.frame then A.UI.Options.frame:Hide() end
  SECRETOS_APAGAR()
end)

---------------------------------------------------------------------------
-- 4. Los íconos que no existían
---------------------------------------------------------------------------
step("4: los íconos arreglados apuntan a texturas de verdad", function()
  check(K.Ruta("star") == "Interface\\AddOns\\Alfa\\Media\\UI\\star", "K.Ruta cambió")
  local Vj = Ru.Viaje
  -- (tools/texturas.py revisa cada nombre fijo contra el build; aquí solo
  -- que las ventanas que los usan abren sin error)
  if AlfaRuta and AlfaRuta.Grises then pcall(AlfaRuta.Grises) T(2) end
  local v = rawget(_G, "AlfaRutasGrises")
  if v then v:Hide() end
end)

print(("PRUEBA: 1.4.0 depuracion, %d pasos, %d errores"):format(pasos, #ERRORS))
print("errors: " .. #ERRORS)
