-- Prueba de la 1.3.5 (la manada más ligera): cada cambio hace lo que dice y
-- lo que ya existía responde igual que antes.
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
local function falla(msg) NOTE("1.3.5", msg) end
local function T(n) RUN_TIMERS(n or 3) end

local reloj = 1000
GetTime = function() return reloj end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
print("errores al entrar:", #ERRORS)

local A, N = Alfa, AlfaNucleo
local K = N.Kit

step("N.DeUnidad: solo llega por la unidad pedida", function()
  local veces = 0
  N.DeUnidad("UNIT_AURA", "player", function() veces = veces + 1 end)
  FIRE_EVENT("UNIT_AURA", "raid7")
  FIRE_EVENT("UNIT_AURA", "nameplate3")
  FIRE_EVENT("UNIT_AURA", "player")
  if veces ~= 1 then falla("N.DeUnidad llegó " .. veces .. " veces (debía 1)") end
end)

step("N.Juntar y ns.Coalesced: una vez por cuadro", function()
  local n1, n2, ultimo = 0, 0, nil
  local g = N.Juntar(function(x) n1 = n1 + 1; ultimo = x end)
  g(1) g(2) g(3)
  local h = A.Coalesced(function() n2 = n2 + 1 end)
  h() h() h()
  T(2)
  if n1 ~= 1 or ultimo ~= 3 then falla(("N.Juntar corrió %d veces con %s"):format(n1, tostring(ultimo))) end
  if n2 ~= 1 then falla("ns.Coalesced corrió " .. n2 .. " veces") end
end)

step("cambiar de zona: Nav se recalcula una vez", function()
  local Nav = A.Nav
  local veces = 0
  local orig = Nav.Refresh
  Nav.Refresh = function(...) veces = veces + 1 return orig(...) end
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA") FIRE_EVENT("ZONE_CHANGED") FIRE_EVENT("ZONE_CHANGED_INDOORS")
  T(2)
  Nav.Refresh = orig
  if veces ~= 1 then falla("Nav.Refresh corrió " .. veces .. " veces al cambiar de zona (debía 1)") end
end)

step("N.PorPrefijo: cada mensaje a su dueño", function()
  local mios, otros = 0, 0
  N.PorPrefijo("AlfaPrueba", function(ev, pre, texto) if ev == "CHAT_MSG_ADDON" and pre == "AlfaPrueba" and texto == "hola" then mios = mios + 1 end end)
  N.PorPrefijo("AlfaOtra", function() otros = otros + 1 end)
  FIRE_EVENT("CHAT_MSG_ADDON", "DBM-Core", "x", "RAID", "Alguien")
  FIRE_EVENT("CHAT_MSG_ADDON", "AlfaPrueba", "hola", "PARTY", "Amigo")
  if mios ~= 1 or otros ~= 0 then falla(("PorPrefijo: %d al dueño y %d a otro"):format(mios, otros)) end
end)

step("K.Escribir no repone el mismo texto", function()
  local f = CreateFrame("Frame")
  local fs = K.Texto(f, "normal", "texto")
  local puestas = 0
  local orig = fs.SetText
  fs.SetText = function(self, t) puestas = puestas + 1 return orig(self, t) end
  K.Escribir(fs, "Hola") K.Escribir(fs, "Hola") K.Escribir(fs, "Hola") K.Escribir(fs, "Adiós") K.Escribir(fs, "")
  if puestas ~= 3 then falla("K.Escribir puso el texto " .. puestas .. " veces (debía 3)") end
  if fs:GetText() ~= "" then falla("K.Escribir no dejó el texto vacío") end
end)

step("Names recuerda las criaturas ya vistas", function()
  local Na = A.Names
  if not (Na and Na.Learn and Na.learnGuid) then falla("falta Names.learnGuid") return end
  local veces = 0
  local orig = Na.learnGuid
  Na.learnGuid = function(...) veces = veces + 1 return orig(...) end
  local gOrig, nOrig = UnitGUID, UnitName
  UnitGUID = function() return "Creature-0-1-2-3-3100-0000AAAA" end
  UnitName = function() return "Lobo de prueba" end
  for _ = 1, 5 do Na.Learn("nameplate1") end
  UnitGUID, UnitName = gOrig, nOrig
  Na.learnGuid = orig
  if veces > 1 then falla("Names.Learn partió el mismo GUID " .. veces .. " veces") end
end)

step("modo combate: solo espera lo que no sirve peleando", function()
  local R = N.Reloj
  -- Con las claves de verdad de cada módulo (se guardan y se reponen).
  local ESPERAN = { "lya.latido", "lya.momentos", "inicio.pagina", "manada.pagina", "enciclopedia.avance" }
  local SIGUEN = { "recoleccion.ruta", "recoleccion.minimapa", "rutas.planes", "rutas.rutaGrupo", "manada.pulso",
    "manada.reloj", "manada.seguir", "inicio.sesion", "inicio.camino", "lya.finMazmorra", "lya.cuadros", "lya.minutos",
    "combate.corte", "curacion.mana" }
  local guardadas, cuenta = {}, {}
  for _, l in ipairs({ ESPERAN, SIGUEN }) do
    for _, k in ipairs(l) do
      guardadas[k] = R.lista[k]
      R.lista[k] = nil
      cuenta[k] = 0
      N.Cada(k, 1, function() cuenta[k] = cuenta[k] + 1 end)
    end
  end
  local viejo = InCombatLockdown
  InCombatLockdown = function() return true end
  for _ = 1, 5 do reloj = reloj + 1.1; R.marco:Show(); FIRE(R.marco, "OnUpdate", 1.1) end
  RUN_TIMERS(2) -- el reloj rápido del banco, con las mismas reglas
  InCombatLockdown = viejo
  for _, k in ipairs(ESPERAN) do if cuenta[k] ~= 0 then falla(k .. " corrió " .. cuenta[k] .. " veces en combate") end end
  for _, k in ipairs(SIGUEN) do if cuenta[k] < 3 then falla(k .. " se detuvo en combate (" .. cuenta[k] .. " veces)") end end
  for _ = 1, 3 do reloj = reloj + 1.1; R.marco:Show(); FIRE(R.marco, "OnUpdate", 1.1) end
  for _, k in ipairs(ESPERAN) do if cuenta[k] == 0 then falla(k .. " no volvió al terminar la pelea") end end
  for k, t in pairs(guardadas) do N.Quitar(k); R.lista[k] = t end
  for _, l in ipairs({ ESPERAN, SIGUEN }) do for _, k in ipairs(l) do if not guardadas[k] then N.Quitar(k) end end end
end)

step("la siguiente guía no se suelta aunque se pida", function()
  local E, G = A.Engine, A.Guides
  local g = E.GetGuide and E.GetGuide()
  local nx = g and rawget(g, "next")
  if type(nx) ~= "string" then print("  (sin siguiente)") return end
  local s = G.Get(nx)
  local _ = s and s.steps
  if G.Release(nx) then falla("Guides.Release soltó la siguiente guía de tu pestaña") end
  if not rawget(s, "steps") then falla("la siguiente guía quedó sin pasos") end
end)

step("modo mazmorra: la recolección duerme adentro", function()
  local R = N.Reloj
  local veces = 0
  N.Cada("recoleccion.prueba", 0.5, function() veces = veces + 1 end)
  local viejo = IsInInstance
  IsInInstance = function() return true, "party" end
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  for _ = 1, 6 do reloj = reloj + 1; R.marco:Show(); FIRE(R.marco, "OnUpdate", 1) end
  IsInInstance = viejo
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  if veces > 1 then falla("la recolección corrió " .. veces .. " veces en una mazmorra") end
  for _ = 1, 6 do reloj = reloj + 1; R.marco:Show(); FIRE(R.marco, "OnUpdate", 1) end
  if veces < 2 then falla("la recolección no volvió al salir de la mazmorra") end
  N.Quitar("recoleccion.prueba")
end)

step("modo ligero: lo de fondo a la mitad, los anuncios sin animación", function()
  local R = N.Reloj
  local function cuenta(ligero)
    A.Set("nucleo.ligero", ligero)
    local veces = 0
    N.Cada("manada.pruebaLigero", 1, function() veces = veces + 1 end)
    for _ = 1, 12 do reloj = reloj + 1; R.marco:Show(); FIRE(R.marco, "OnUpdate", 1) end
    N.Quitar("manada.pruebaLigero")
    return veces
  end
  local normal, ligero = cuenta(false), cuenta(true)
  if not (ligero < normal and ligero >= normal / 3) then falla(("modo ligero: %d veces contra %d normal"):format(ligero, normal)) end
  if not N.Ligero() then falla("N.Ligero no dice que está prendido") end
  A.Set("nucleo.ligero", false)
  print(("  en 12 s: %d veces normal, %d en modo ligero"):format(normal, ligero))
end)

step("la siguiente guía queda armada", function()
  local E, G = A.Engine, A.Guides
  local g = E.GetGuide and E.GetGuide()
  local nx = g and rawget(g, "next")
  if type(nx) ~= "string" then print("  (la guía de ahora no tiene siguiente: nada que armar)") return end
  local Sg = NS_OF("Alfa_Rutas").Siguiente
  local armada = (Sg and Sg.ArmarSiguiente and Sg.ArmarSiguiente()) or nil
  if not armada then
    -- Por el reloj, como en el juego.
    A.Fire("GUIDE_CHANGED", g.id)
    reloj = reloj + 4
    T(5)
  end
  local s = G.Get(nx)
  if not (s and rawget(s, "steps")) then falla("la siguiente guía (" .. nx .. ") no quedó armada") return end
  A.Fire("TABS_CHANGED")
  if not rawget(s, "steps") then falla("al limpiar guías se soltó la siguiente de tu ruta") end
end)

step("/alfa rendimiento: carga, memoria y el aviso de Lya", function()
  local rc = A.loadClock
  if type(rc) ~= "table" or not rc.start then falla("falta A.loadClock.start") end
  local Pf = NS_OF("Alfa_Bienvenida").Perfiles
  local avisos = 0
  local va = K.Aviso
  K.Aviso = function(o) avisos = avisos + 1 return va(o) end
  -- Algo que se pasa: Lya avisa. Algo normal: nada.
  local P = Pf
  local pasado = P and P.Pasado
  if pasado then
    if not pasado({ total = 100, lista = { { "Alfa_Prueba", 90 } } }, nil) then falla("Pasado no vio 90 KB/s") end
    if pasado({ total = 5, lista = { { "Alfa_Prueba", 4 } } }, { { "Alfa", 0.2 } }) then falla("Pasado avisó con poco") end
    if not pasado({ total = 1, lista = {} }, { { "Alfa_Lento", 3 } }) then falla("Pasado no vio 3 ms por cuadro") end
  else
    falla("no encontré Perfiles.Pasado")
  end
  local mide = P and P.MedirBasura
  if mide then
    local listo = false
    mide({ "Alfa" }, { { "Alfa_Lento", 3 } }, function() listo = true end)
    reloj = reloj + 11
    T(5)
    if not listo then falla("MedirBasura no terminó") end
    if avisos < 1 then falla("con 3 ms por cuadro Lya no avisó") end
  end
  K.Aviso = va
end)

-- Las mismas respuestas que antes: ClassToast.ClassGuide y Guides.FollowLog
-- con la ficha (qref) contra leer todas las guías.
step("ClassGuide y FollowLog responden igual que antes", function()
  local G, CT = A.Guides, A.UI and A.UI.ClassToast
  local C = A.Compat
  -- Todas armadas, para comparar sin la ficha.
  InCombatLockdown = function() return true end
  for _, h in ipairs(G.List()) do local g = G.Get(h.id); local _ = g and g.steps end
  local quests = {}
  for _, h in ipairs(G.List()) do
    if h.category == "Class" then
      for _, s in ipairs(G.Get(h.id).steps) do
        for _, goal in ipairs(s.goals) do if goal.quest then quests[goal.quest] = true end end
      end
    end
  end
  local n, dif = 0, 0
  if CT and CT.ClassGuide then
    for q in pairs(quests) do
      n = n + 1
      local ahora = CT.ClassGuide(q)
      -- Sin ficha: se le quita la qref a todas un momento.
      local guardadas = {}
      for _, h in ipairs(G.List()) do local g = G.Get(h.id); guardadas[g] = rawget(g, "qref"); rawset(g, "qref", nil) end
      local antes = CT.ClassGuide(q)
      for g, r in pairs(guardadas) do rawset(g, "qref", r) end
      if ahora ~= antes then dif = dif + 1; if dif <= 3 then falla(("ClassGuide(%d): antes %s, ahora %s"):format(q, tostring(antes), tostring(ahora))) end end
    end
  end
  -- FollowLog con un diario de misiones de prueba.
  local lvl = {}
  for _, h in ipairs(G.List()) do if (h.category == nil or h.category == "Leveling") then lvl[#lvl + 1] = h.id end end
  local log = {}
  for i = 1, math.min(3, #lvl) do
    for _, s in ipairs(G.Get(lvl[i]).steps) do
      for _, goal in ipairs(s.goals) do if goal.quest and goal.t == "turnin" and #log < 12 then log[#log + 1] = goal.quest end end
    end
  end
  local viejoLog = C.GetLogQuests
  C.GetLogQuests = function() return log end
  local nf, df = 0, 0
  for _, id in ipairs(lvl) do
    nf = nf + 1
    local ahora = G.FollowLog(id)
    local guardadas = {}
    for _, h in ipairs(G.List()) do local g = G.Get(h.id); guardadas[g] = rawget(g, "qref"); rawset(g, "qref", nil) end
    local antes = G.FollowLog(id)
    for g, r in pairs(guardadas) do rawset(g, "qref", r) end
    if ahora ~= antes then df = df + 1; if df <= 3 then falla(("FollowLog(%s): antes %s, ahora %s"):format(id, tostring(antes), tostring(ahora))) end end
  end
  C.GetLogQuests = viejoLog
  print(("  ClassGuide en %d misiones y FollowLog en %d guías: %d y %d diferencias"):format(n, nf, dif, df))
  if n < 5 then falla("casi no hubo misiones de clase para comparar") end
end)

print(("PRUEBA: 1.3.5 rendimiento, %d pasos, errores: %d"):format(pasos, #ERRORS))
