-- Prueba de la 1.4.0 (velocidad): guías por tramo de nivel y el Codex por partes.
--
-- Guías (tools/tramos.py): las fichas de todas las guías están al entrar; los
-- pasos viven en paquetes a pedido por tramo y se cargan al leer `g.steps`.
-- 1. Al entrar solo se cargan los paquetes de pasos de lo que se lee.
-- 2. Todas las guías siguen en la lista con su ficha (las búsquedas, la
--    Biblioteca y Planes las ven sin cargar nada).
-- 3. Abrir una guía de otro tramo carga su paquete y da los mismos pasos que
--    dice su ficha (stepCount).
-- 4. En combate, leer los pasos de una guía de un tramo sin cargar funciona.
-- 5. Opciones (calabozos y misiones de grupo) no carga paquetes de pasos.
-- 6. Un paquete de pasos que falta: un paso que lo dice, sin errores.
-- Codex (tools/tramos.py, partir_codex):
-- 7. Cargar el Codex no carga objetos, PNJ ni misiones; preguntar por un
--    objeto carga solo su parte; en combate sin núcleo, nada (como antes).
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
local function falla(msg) NOTE("velocidad", msg) end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
print("errores al entrar:", #ERRORS)

local A = Alfa
local G = A.Guides

local function partesCargadas()
  local out = {}
  for n, v in pairs(LOADED) do
    if v and type(n) == "string" and n:find("_Pasos", 1, true) then out[#out + 1] = n end
  end
  table.sort(out)
  return out
end

step("al entrar solo lo que se lee", function()
  local cargadas = partesCargadas()
  if #cargadas > 3 then falla("al entrar hay " .. #cargadas .. " paquetes de pasos: " .. table.concat(cargadas, ", ")) end
  for _, n in ipairs(cargadas) do
    if n:find("Alliance", 1, true) then falla("se cargaron pasos de la otra facción: " .. n) end
    if n == "Alfa_Guides_Pasos" then falla("se cargó el paquete de oficios y demás al entrar") end
  end
  print("  paquetes de pasos al entrar: " .. table.concat(cargadas, ", "))
end)

step("todas las fichas están", function()
  local total, conParte, sinNada = 0, 0, 0
  for _, h in ipairs(G.List()) do
    total = total + 1
    local g = G.Get(h.id)
    if type(rawget(g, "stepsPart")) == "string" then conParte = conParte + 1 end
    if rawget(g, "steps") == nil and rawget(g, "stepsSrc") == nil and rawget(g, "stepsPart") == nil then sinNada = sinNada + 1 end
    if not (h.title and h.stepCount and h.stepCount > 0) then falla(h.id .. ": ficha sin título o sin pasos") end
  end
  if total < 150 then falla("solo " .. total .. " guías en la lista") end
  if conParte < total * 0.9 then falla(("solo %d de %d guías con paquete de pasos"):format(conParte, total)) end
  if sinNada > 0 then falla(sinNada .. " guías sin pasos ni paquete") end
  print(("  %d guías, %d con su paquete de pasos"):format(total, conParte))
end)

-- Una guía de Horda de un tramo que no se cargó al entrar.
local function guiaSinCargar()
  for _, h in ipairs(G.List()) do
    local g = G.Get(h.id)
    local p = rawget(g, "stepsPart")
    if type(p) == "string" and not LOADED[p] and p:find("Horde", 1, true) then return g, p end
  end
end

step("abrir una guía de otro tramo", function()
  local g, p = guiaSinCargar()
  if not g then falla("no hay guía de un tramo sin cargar") return end
  local pasosG = g.steps
  if type(pasosG) ~= "table" or #pasosG ~= g.stepCount then
    falla(("%s: %s pasos, la ficha dice %s"):format(g.id, tostring(type(pasosG) == "table" and #pasosG), tostring(g.stepCount)))
  end
  if not LOADED[p] then falla(p .. " no se cargó al abrir " .. g.id) end
  if type(rawget(g, "stepsSrc")) ~= "string" then falla("sin stepsSrc tras cargar") end
  -- Soltar y volver a armar da lo mismo (el paquete no se vuelve a cargar).
  G.Release(g.id)
  if rawget(g, "steps") ~= nil and not (A.Engine.TabIds and A.Engine.TabIds()[g.id]) then falla("no se soltó") end
  if #g.steps ~= g.stepCount then falla("al volver a armar cambió") end
  print("  abierta " .. g.id .. " desde " .. p)
end)

-- 1.4.0 (revisión): en combate solo se leen los pasos de una guía que hace
-- falta ya (una pestaña, su plan o la que pide el jugador); las demás esperan
-- al fin del combate (tools/banco/prueba_140_revision.lua lo prueba entero).
step("en combate se pueden leer los pasos de la que pides", function()
  local g, p = guiaSinCargar()
  if not g then print("  (todas cargadas)") return end
  local viejo = InCombatLockdown
  InCombatLockdown = function() return true end
  local ok0, n0 = pcall(function() return #g.steps end)
  local espera = G.FaltanPasos and G.FaltanPasos(g)
  local N = AlfaNucleo
  local pidio = N.PidioJugador
  N.PidioJugador = function() return true end
  local ok, n = pcall(function() return #g.steps end)
  N.PidioJugador = pidio
  InCombatLockdown = viejo
  if not ok0 or n0 ~= 1 or espera ~= "combate" then falla("en combate se leyó una guía que no se pidió: " .. tostring(n0)) end
  if not ok or n ~= g.stepCount then falla("en combate: " .. tostring(n)) end
  if not LOADED[p] then falla("en combate no se cargó " .. p) end
end)

step("Opciones no carga paquetes de pasos", function()
  local antes = #partesCargadas()
  local d = A.Engine.GuideDungeons and A.Engine.GuideDungeons() or {}
  local gq = A.Engine.GroupQuests and A.Engine.GroupQuests() or {}
  local despues = #partesCargadas()
  if despues ~= antes then falla(("calabozos/misiones de grupo cargaron %d paquetes"):format(despues - antes)) end
  local n = 0
  for _ in pairs(d) do n = n + 1 end
  if n == 0 then falla("sin calabozos de las guías (dungeonMaps)") end
  print(("  %d calabozos, %d misiones de grupo, sin cargar pasos"):format(n, #gq))
end)

step("dónde empieza cada guía, sin leer sus pasos (alfaStart)", function()
  local con, iguales, distintas = 0, 0, {}
  local viejo = InCombatLockdown
  InCombatLockdown = function() return true end -- (que nada suelte pasos mientras se compara)
  -- (y en combate solo se leen los pasos que pide el jugador: revisión 1.4.0)
  local pidio = AlfaNucleo.PidioJugador
  AlfaNucleo.PidioJugador = function() return true end
  for _, h in ipairs(G.List()) do
    local g = G.Get(h.id)
    local s = rawget(g, "alfaStart")
    if s ~= nil then
      con = con + 1
      local real = false
      for _, step in ipairs(g.steps) do
        for _, goal in ipairs(step.goals) do
          if goal.map and goal.x and goal.y then real = { map = goal.map, x = goal.x, y = goal.y, f = goal.f } break end
        end
        if real then break end
      end
      local ok = (s == false and real == false) or (type(s) == "table" and type(real) == "table"
        and s.map == real.map and s.x == real.x and s.y == real.y and s.f == real.f)
      if ok then iguales = iguales + 1 else distintas[#distintas + 1] = h.id end
    end
  end
  InCombatLockdown = viejo
  AlfaNucleo.PidioJugador = pidio
  if #distintas > 0 then falla(#distintas .. " guías con alfaStart distinto de sus pasos: " .. table.concat(distintas, ", ", 1, math.min(5, #distintas))) end
  if con < 100 then falla("solo " .. con .. " guías con alfaStart") end
  print(("  %d guías saben dónde empiezan sin leer sus pasos (%d iguales a sus pasos)"):format(con, iguales))
end)

step("un paquete que falta", function()
  local ok = A.RegisterGuide({ id = "forever/prueba/sin-paquete", pack = "guides", title = "Prueba", category = "Leveling",
    minLevel = 1, maxLevel = 2, stepCount = 3, stepsPart = "Alfa_Guides_NoExiste" })
  local g = G.Get("forever/prueba/sin-paquete")
  if not g then print("  (el paquete no aceptó la guía de prueba: " .. tostring(ok) .. ")") return end
  local s = g.steps
  if type(s) ~= "table" or #s ~= 1 then falla("sin paquete: " .. tostring(s)) end
  if rawget(g, "steps") ~= nil then falla("el aviso se guardó como pasos") end
end)

step("el Codex por partes", function()
  local C = A.Codex
  if not (C and C.Load) then falla("sin Codex") return end
  local partes = { "Alfa_Codex_Objetos", "Alfa_Codex_Mundo" }
  for _, p in ipairs(partes) do
    if LOADED[p] then print("  (ya cargado al entrar: " .. p .. ")") end
  end
  C.Load()
  if not C.IsLoaded() then falla("el núcleo del Codex no cargó") return end
  local antesObj = LOADED["Alfa_Codex_Objetos"]
  local it = C.Item(2589) -- Linen Cloth
  if not (it and it.name) then falla("Codex.Item(2589) no respondió") end
  if not LOADED["Alfa_Codex_Objetos"] then falla("Item no cargó la parte de objetos") end
  local q = C.Quest(783) -- A Threat Within
  if not q then falla("Codex.Quest(783) no respondió") end
  local npc = C.Npc(3143) -- Gornek
  if not npc then falla("Codex.Npc(3143) no respondió") end
  for _, p in ipairs(partes) do
    if not LOADED[p] then falla(p .. " no se cargó al preguntar") end
  end
  local n = 0
  C.Each("quest", function() n = n + 1; if n > 10 then return false end end)
  if n == 0 then falla("Each(quest) vacío") end
  if #C.WithRole("vendor") == 0 then falla("WithRole(vendor) vacío") end
  print("  objetos, PNJ y misiones del Codex a pedido")
end)

-- Comercio (plan 6): los precios del reino vacío se juntan también con el
-- reino supuesto (si la cuenta no tiene otro reino de tu facción), y la
-- historia tiene tope.
step("precios: juntar el reino vacío y tope", function()
  local N = AlfaNucleo
  local M = NS_OF("Alfa_Comercio")
  if not (M and M.JuntarReinoSinNombre and M.Podar and M.Datos) then falla("no encuentro Comercio (JuntarReinoSinNombre)") return end
  local d = M.Datos()
  local guardado = d.reinos
  local f = A.Compat.GetPlayerFaction()
  local ahora = M.Ahora()
  local dia = math.floor(ahora / 86400)
  d.reinos = {
    ["?-" .. f] = { p = { [2589] = { 50, ahora, 5, 1 }, [2592] = { 90, ahora - 100, 1, 1 } }, h = { [2589] = (dia - 40) .. ":40," .. dia .. ":50" } },
    ["Forever-" .. f] = { p = { [2589] = { 60, ahora - 1000, 5, 1 } }, h = { [2589] = (dia - 1) .. ":60" } },
  }
  local real = N.Reino
  N.Reino = function() return "Forever", false end
  local n = M.JuntarReinoSinNombre()
  if n ~= 2 or d.reinos["?-" .. f] then falla("con el reino supuesto no se juntó: " .. tostring(n)) end
  local r = d.reinos["Forever-" .. f]
  if not (r and r.p[2589] and r.p[2589][1] == 50 and r.p[2592]) then falla("el precio más nuevo no ganó") end
  -- Con otro reino de tu facción en la cuenta, no se supone nada.
  d.reinos["?-" .. f] = { p = { [1] = { 5, ahora, 1, 1 } }, h = {} }
  d.reinos["Otro-" .. f] = { p = { [1] = { 5, ahora, 1, 1 } }, h = {} }
  if M.JuntarReinoSinNombre() ~= 0 then falla("juntó con dos reinos de tu facción") end
  N.Reino = real
  -- Tope: la historia vieja se va, y un reino no pasa de TOPE_OBJETOS.
  d.reinos["Otro-" .. f], d.reinos["?-" .. f] = nil, nil
  M.Podar(ahora)
  local h = r.h[2589]
  if not h or h:find((dia - 40) .. ":", 1, true) then falla("la historia vieja se quedó: " .. tostring(h)) end
  for i = 1, M.TOPE_OBJETOS + 50 do r.p[100000 + i] = { 10, ahora - i, 1, 1 }; r.h[100000 + i] = dia .. ":10" end
  M.Podar(ahora)
  local cuenta = 0
  for _ in pairs(r.p) do cuenta = cuenta + 1 end
  if cuenta ~= M.TOPE_OBJETOS then falla("el tope dejó " .. cuenta) end
  if r.p[100000 + M.TOPE_OBJETOS + 50] then falla("se quedó el más viejo") end
  if not r.p[2589] then falla("se fue uno reciente") end
  d.reinos = guardado
  print("  precios del reino vacío juntados con el supuesto; historia de " .. M.HISTORIA_DIAS .. " días, tope " .. M.TOPE_OBJETOS)
end)

-- /alfa revisar (plan 14): recorre las páginas, reporta solo lo que falla y
-- nunca sigue en combate.
step("/alfa revisar", function()
  local N = AlfaNucleo
  local R = N.Revisar
  if not (R and R.Empezar) then falla("falta N.Revisar") return end
  local dichos = {}
  local imprimir = N.Imprimir
  N.Imprimir = function(s, ...) dichos[#dichos + 1] = tostring(s) return imprimir(s, ...) end
  -- Un marco con un texto cortado y fuera de la pantalla se reporta.
  local f = CreateFrame("Frame", "AlfaPruebaRevisar", UIParent)
  f:SetSize(200, 50); f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -300, 0); f:Show()
  local fs = f:CreateFontString(nil, "OVERLAY"); fs:SetFontObject(GameFontNormal); fs:SetText("Un texto muy largo"); fs:Show()
  fs.IsTruncated = function() return true end
  local out = R.Revisar(f, "Prueba")
  local hayCorte, hayFuera = false, false
  for _, l in ipairs(out) do
    if l:find("cortado", 1, true) or l:find("cut", 1, true) then hayCorte = true end
    if l:find("pantalla", 1, true) or l:find("screen", 1, true) then hayFuera = true end
  end
  if not hayCorte then falla("no vio el texto cortado: " .. table.concat(out, " | ")) end
  if not hayFuera then falla("no vio la ventana fuera de la pantalla") end
  f:Hide()
  -- La recorrida entera termina con su resumen.
  if not R.Empezar() then falla("no empezó") end
  for _ = 1, 80 do if not R.Corriendo() then break end RUN_TIMERS(1) end
  if R.Corriendo() then falla("la recorrida no terminó") end
  local final = dichos[#dichos] or ""
  local resumen
  for _, d in ipairs(dichos) do if d:find("revisadas", 1, true) or d:find("checked", 1, true) then resumen = d end end
  if not resumen then falla("sin resumen: " .. final) end
  print("  " .. tostring(resumen))
  for _, d in ipairs(dichos) do if d:find("^  · ") then print("  " .. d) end end
  -- En combate no empieza, y si empieza uno a la mitad, para.
  local viejo = InCombatLockdown
  InCombatLockdown = function() return true end
  if R.Empezar() then falla("empezó en combate") end
  InCombatLockdown = viejo
  R.Empezar()
  RUN_TIMERS(1)
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  if R.Corriendo() then falla("siguió en combate") end
  N.Imprimir = imprimir
end)

print(("PRUEBA: velocidad, %d pasos, errores: %d"):format(pasos, #ERRORS))
