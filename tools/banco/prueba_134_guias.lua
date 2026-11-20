-- Prueba de la 1.3.4: guías con pasos diferidos (docs/DISENO-GUIAS-DIFERIDAS.md).
--
-- 1. Al entrar, casi ninguna guía arma sus pasos.
-- 2. Preguntar qué cierra o qué abre una misión (el diálogo de un PNJ, el
--    globo de una misión) arma solo las guías que la tocan.
-- 3. Los índices por misión (Closes, Unlocks) dan lo mismo que leer los pasos
--    de todas las guías, como hacía la 1.3.3, y la ficha `qref` nunca deja
--    fuera una misión que los pasos sí tienen.
-- 4. Soltar pasos espera a que acabe el combate.
-- (Que los pasos diferidos queden iguales a los de antes lo compara
-- tools/prueba.py con volcar_guias.lua.)
local pasos = 0
local function step(nombre, fn)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function falla(msg) NOTE("guías diferidas", msg) end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
print("errores al entrar:", #ERRORS)

local A = Alfa
local G = A.Guides

local function armadas()
  local n, quien = 0, {}
  for _, h in ipairs(G.List()) do
    local g = G.Get(h.id)
    if g and rawget(g, "stepsSrc") ~= nil and rawget(g, "steps") ~= nil then n = n + 1; quien[#quien + 1] = h.id end
  end
  return n, quien
end

local TOPE_ENTRAR = 8 -- la guía que sigues y las de tu clase (UI/ClassToast.lua)

step("al entrar casi nada se arma", function()
  local total, diferidas = 0, 0
  for _, h in ipairs(G.List()) do
    total = total + 1
    if rawget(G.Get(h.id) or {}, "stepsSrc") then diferidas = diferidas + 1 end
  end
  if diferidas < total * 0.9 then falla(("solo %d de %d guías vienen diferidas"):format(diferidas, total)) end
  local n, quien = armadas()
  if n > TOPE_ENTRAR then falla(("al entrar hay %d guías armadas (tope %d): %s"):format(n, TOPE_ENTRAR, table.concat(quien, ", "))) end
  print(("  %d guías, %d diferidas, %d armadas al entrar"):format(total, diferidas, n))
end)

-- Una misión que cierra otra (closedBy) y una con prerrequisitos.
local unaCierra, unaPre
for _, h in ipairs(G.List()) do
  local ref = rawget(G.Get(h.id) or {}, "qref")
  if ref then
    unaCierra = unaCierra or (ref.c and ref.c[1])
    unaPre = unaPre or (ref.p and ref.p[1])
  end
end

step("preguntar por una misión arma solo sus guías", function()
  local antes = armadas()
  if unaCierra then A.Closes.For(unaCierra) end
  if unaPre then A.Unlocks.For(unaPre) end
  local despues = armadas()
  local candidatas = #(G.QuestGuides("c", unaCierra or -1) or {}) + #(G.QuestGuides("p", unaPre or -1) or {}) + #(G.QuestGuides("q", unaPre or -1) or {})
  if despues - antes > candidatas then
    falla(("Closes/Unlocks armaron %d guías y solo %d la tocan"):format(despues - antes, candidatas))
  end
  print(("  Closes.For(%s) y Unlocks.For(%s): %d guías armadas de más"):format(tostring(unaCierra), tostring(unaPre), despues - antes))
end)

step("el diálogo de un PNJ no arma todo", function()
  local antes = armadas()
  GetQuestID = function() return unaCierra end
  GetTitleText = function() return "Una misión" end
  FIRE_EVENT("QUEST_DETAIL")
  if A.Closes.HoldsOffer then A.Closes.HoldsOffer() end
  local despues = armadas()
  if despues - antes > #(G.QuestGuides("c", unaCierra or -1) or {}) then falla("el diálogo armó " .. (despues - antes) .. " guías") end
end)

step("combate: soltar pasos espera", function()
  local enCombate = true
  local viejo = InCombatLockdown
  InCombatLockdown = function() return enCombate end
  local n0 = armadas()
  A.Fire("TABS_CHANGED")
  local n1 = armadas()
  if n1 < n0 then falla("se soltaron pasos en combate") end
  enCombate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  InCombatLockdown = viejo
end)

-- Desde aquí se arman todas: los índices de la 1.3.3 (leer todas) contra
-- los de ahora (por misión).
local function viejoCloses()
  local index = {}
  for _, h in ipairs(G.List()) do
    local g = G.Get(h.id)
    for _, s in ipairs(g and g.steps or {}) do
      for _, goal in ipairs(s.goals) do
        if goal.t == "accept" and type(goal.closedBy) == "table" then
          for _, by in ipairs(goal.closedBy) do
            index[by] = index[by] or {}
            table.insert(index[by], goal)
          end
        end
      end
    end
  end
  return index
end
local function viejoUnlocks()
  local follow, accepts, turnins = {}, {}, {}
  local function push(m, q, x) m[q] = m[q] or {}; table.insert(m[q], x) end
  for _, h in ipairs(G.List()) do
    local g = G.Get(h.id)
    for _, s in ipairs(g and g.steps or {}) do
      for _, goal in ipairs(s.goals) do
        local q = goal.quest
        if q and goal.t == "accept" then
          push(accepts, q, goal)
          for _, p in ipairs(type(goal.pre) == "table" and goal.pre or {}) do push(follow, p, goal) end
          for _, p in ipairs(type(goal.preAll) == "table" and goal.preAll or {}) do push(follow, p, goal) end
        elseif q and goal.t == "turnin" then
          push(turnins, q, goal)
        end
      end
    end
  end
  return { follow = follow, accepts = accepts, turnins = turnins }
end
local function igual(nombre, viejo, nuevo)
  local malos = 0
  for q, lista in pairs(viejo) do
    local n = nuevo[q] or {}
    local ok = #n == #lista
    for i = 1, #lista do if not (n[i] and n[i].goal == lista[i]) then ok = false end end
    if not ok then
      malos = malos + 1
      if malos <= 3 then falla(("%s[%d]: antes %d, ahora %d"):format(nombre, q, #lista, #n)) end
    end
  end
  return malos
end

step("los índices por misión dan lo mismo que leer todas", function()
  -- Armar todas y que el combate no las suelte mientras se compara.
  InCombatLockdown = function() return true end
  for _, h in ipairs(G.List()) do local g = G.Get(h.id); local _ = g and g.steps end
  A.Fire("GUIDES_REGISTERED") -- índices nuevos sobre los pasos ya armados
  local vc, vu = viejoCloses(), viejoUnlocks()
  local Cl = A.Closes
  -- Closes guarda su índice en un local: se lee por For(), que devuelve
  -- títulos; se compara con la lista de candidatas y el índice de Unlocks.
  local malos = 0
  local function qs(m) local t = {} for q in pairs(m) do t[#t + 1] = q end return t end
  local U = {}
  -- Unlocks expone su índice solo dentro: se reconstruye igual que el parche.
  for _, kind in ipairs({ "accepts", "turnins", "follow" }) do
    local nuevo = setmetatable({}, { __index = function(t, q)
      local list = {}
      for _, id in ipairs(G.QuestGuides(kind == "follow" and "p" or "q", q) or {}) do
        local g = G.Get(id)
        for _, s in ipairs(g and g.steps or {}) do
          for _, goal in ipairs(s.goals) do
            local hit = false
            if kind == "accepts" then hit = goal.quest == q and goal.t == "accept"
            elseif kind == "turnins" then hit = goal.quest == q and goal.t == "turnin" end
            if hit then list[#list + 1] = { goal = goal } end
            if kind == "follow" and goal.quest and goal.t == "accept" then
              for _, x in ipairs(type(goal.pre) == "table" and goal.pre or {}) do if x == q then list[#list + 1] = { goal = goal } end end
              for _, x in ipairs(type(goal.preAll) == "table" and goal.preAll or {}) do if x == q then list[#list + 1] = { goal = goal } end end
            end
          end
        end
      end
      return list
    end })
    malos = malos + igual("Unlocks." .. kind, vu[kind], nuevo)
  end
  -- Closes: la misma búsqueda con su clave (c).
  local nuevoC = setmetatable({}, { __index = function(t, by)
    local list = {}
    for _, id in ipairs(G.QuestGuides("c", by) or {}) do
      local g = G.Get(id)
      for _, s in ipairs(g and g.steps or {}) do
        for _, goal in ipairs(s.goals) do
          if goal.t == "accept" and type(goal.closedBy) == "table" then
            for _, b in ipairs(goal.closedBy) do if b == by then list[#list + 1] = { goal = goal } end end
          end
        end
      end
    end
    return list
  end })
  malos = malos + igual("Closes", vc, nuevoC)
  -- Y Closes.For de verdad: no truena y responde para cada misión que cierra otra.
  for _, by in ipairs(qs(vc)) do Cl.For(by) end
  local nU = 0
  for _, q in ipairs(qs(vu.accepts)) do A.Unlocks.For(q); nU = nU + 1 end
  print(("  índices: %d misiones que cierran, %d con prerrequisito, %d aceptadas; %d diferencias"):format(#qs(vc), #qs(vu.follow), nU, malos))
end)

-- Lo de verdad: Closes.For y Unlocks.For con su índice de ahora contra los
-- mismos For con el índice de la 1.3.3 (cambiando el `guideIndex` que usan).
local function buscarUpvalue(fn, nombre, prof, visto)
  visto = visto or {}
  if visto[fn] or prof < 0 then return nil end
  visto[fn] = true
  for i = 1, 200 do
    local n, v = debug.getupvalue(fn, i)
    if not n then break end
    if n == nombre then return fn, i, v end
    if type(v) == "function" then
      local f, j, w = buscarUpvalue(v, nombre, prof - 1, visto)
      if f then return f, j, w end
    end
  end
end
local function completo(e) return { goal = e, step = nil, guide = nil } end
local function entradasViejas(cl)
  -- El índice viejo con { goal, step, guide }, como lo armaba la 1.3.3.
  local out = {}
  for _, h in ipairs(G.List()) do
    local g = G.Get(h.id)
    for _, s in ipairs(g and g.steps or {}) do
      for _, goal in ipairs(s.goals) do cl(out, goal, s, g) end
    end
  end
  return out
end
local function serial(v, visto)
  visto = visto or {}
  if type(v) ~= "table" then return tostring(v) end
  if visto[v] then return "<" .. tostring(v) .. ">" end
  visto[v] = true
  local k = {}
  for x in pairs(v) do k[#k + 1] = x end
  table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
  local o = {}
  for _, x in ipairs(k) do o[#o + 1] = tostring(x) .. "=" .. serial(v[x], visto) end
  visto[v] = nil
  return "{" .. table.concat(o, ",") .. "}"
end

step("Closes.For y Unlocks.For responden igual que en la 1.3.3", function()
  local Cl, Un = A.Closes, A.Unlocks
  local push = function(m, q, e) m[q] = m[q] or {}; table.insert(m[q], e) end
  local viejoC = entradasViejas(function(out, goal, s, g)
    if goal.t == "accept" and type(goal.closedBy) == "table" then
      for _, by in ipairs(goal.closedBy) do push(out, by, { goal = goal, step = s, guide = g }) end
    end
  end)
  local vf, va, vt = {}, {}, {}
  entradasViejas(function(_, goal, s, g)
    local q = goal.quest
    if q and goal.t == "accept" then
      local e = { goal = goal, step = s, guide = g }
      push(va, q, e)
      for _, p in ipairs(type(goal.pre) == "table" and goal.pre or {}) do push(vf, p, e) end
      for _, p in ipairs(type(goal.preAll) == "table" and goal.preAll or {}) do push(vf, p, e) end
    elseif q and goal.t == "turnin" then
      push(vt, q, { goal = goal, step = s, guide = g })
    end
  end)
  local viejoU = { follow = vf, accepts = va, turnins = vt }

  local fc, ic, nuevoIdxC = buscarUpvalue(Cl.For, "guideIndex", 1)
  local fu, iu, nuevoIdxU = buscarUpvalue(Un.For, "guideIndex", 3)
  if not (fc and fu) then falla("no encontré guideIndex en Closes.For o Unlocks.For") return end
  local quests = {}
  for q in pairs(viejoC) do quests[q] = true end
  for q in pairs(vf) do quests[q] = true end
  for q in pairs(va) do quests[q] = true end
  local lista = {}
  for q in pairs(quests) do lista[#lista + 1] = q end
  table.sort(lista)
  local function respuestas()
    local r = {}
    for _, q in ipairs(lista) do
      local c, t = Cl.For(q)
      r[#r + 1] = serial({ c, t }) .. "|" .. serial(Un.For(q))
    end
    return r
  end
  local ahora = respuestas()
  debug.setupvalue(fc, ic, function() return viejoC end)
  debug.setupvalue(fu, iu, function() return viejoU end)
  local antes = respuestas()
  debug.setupvalue(fc, ic, nuevoIdxC)
  debug.setupvalue(fu, iu, nuevoIdxU)
  local dif = 0
  for i = 1, #lista do
    if ahora[i] ~= antes[i] then
      dif = dif + 1
      if dif <= 3 then falla(("misión %d: 1.3.3 %s / ahora %s"):format(lista[i], antes[i]:sub(1, 200), ahora[i]:sub(1, 200))) end
    end
  end
  local llenas = 0
  for i = 1, #ahora do if ahora[i] ~= "{}|nil" and not ahora[i]:find("^{2=nil}|nil$") then llenas = llenas + 1 end end
  local conUnlocks = 0
  for i = 1, #ahora do if not ahora[i]:find("|nil$") then conUnlocks = conUnlocks + 1 end end
  if conUnlocks < #lista / 10 then falla(("solo %d respuestas de Unlocks traen algo"):format(conUnlocks)) end
  print(("  Unlocks.For responde en %d"):format(conUnlocks))
  if llenas < #lista / 10 then falla(("solo %d de %d respuestas traen algo: la comparación no prueba nada"):format(llenas, #lista)) end
  print(("  Closes.For y Unlocks.For en %d misiones (%d con respuesta): %d diferencias con la 1.3.3"):format(#lista, llenas, dif))
  print("  ejemplo: " .. (ahora[math.floor(#ahora / 2)] or ""):sub(1, 160))
end)

step("qref nunca deja fuera una misión", function()
  local faltan = 0
  for _, h in ipairs(G.List()) do
    local g = G.Get(h.id)
    local ref = g and rawget(g, "qref")
    if ref then
      local set = { q = {}, p = {}, c = {} }
      for k, l in pairs(set) do for _, n in ipairs(ref[k] or {}) do l[n] = true end end
      for _, s in ipairs(g.steps) do
        for _, goal in ipairs(s.goals) do
          local function ver(k, n) if type(n) == "number" and not set[k][n] then faltan = faltan + 1; if faltan <= 3 then falla(("%s: falta %s=%d en qref"):format(h.id, k, n)) end end end
          ver("q", goal.quest)
          for _, n in ipairs(type(goal.pre) == "table" and goal.pre or {}) do ver("p", n) end
          for _, n in ipairs(type(goal.preAll) == "table" and goal.preAll or {}) do ver("p", n) end
          for _, n in ipairs(type(goal.closedBy) == "table" and goal.closedBy or {}) do ver("c", n) end
        end
      end
    end
  end
end)

print(("PRUEBA: guías diferidas, %d pasos, errores: %d"):format(pasos, #ERRORS))
