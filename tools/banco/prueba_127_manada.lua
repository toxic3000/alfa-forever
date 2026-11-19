-- Prueba de la 1.2.7, La Jauría (tools/prueba.py la corre con las demás prueba_*.lua):
--   * el mapa de la manada: la guarida en el cuadro del lobo y la marca del llamado (3 min, clic: flecha);
--   * marcar el raro para todos: el aviso con el botón seguro de la calavera (SetRaidTarget tiene restricciones);
--   * cazar juntos: 1M con tus misiones (una vez por minuto), las comunes y el aviso con «Invitar»;
--   * el saludo de la manada: quién de tu hermandad anda conectado, sin ti, hasta 3 y «y N más»;
--   * los logros de la insignia: la estrella del nivel máximo y los 100 raros.
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
local function check(cond, msg) if not cond then NOTE("1.2.7 manada", msg) end end

-- Los marcos del juego con su retrato (como en prueba_122).
local function marcoConRetrato(nombre, clave, retrato)
  local f = CreateFrame("Frame", nombre, UIParent)
  f[clave] = CreateFrame("Frame", nil, f)
  f[clave][retrato] = f[clave]:CreateTexture()
end
marcoConRetrato("PlayerFrame", "PlayerFrameContainer", "PlayerPortrait")
marcoConRetrato("TargetFrame", "TargetFrameContainer", "Portrait")
marcoConRetrato("FocusFrame", "TargetFrameContainer", "Portrait")

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local MN = NS_OF("Alfa_Manada")
local R = MN.Red
local map = A.Compat.GetPlayerMapPosition()

-- Lo que sale por la red y los avisos, mientras dura `fn`.
local salidos, avisos = {}, {}
local function conRed(fn)
  A.Set("manada.compartir", true)
  R.Escuchar()
  local via, envio, av = R.Via, C_ChatInfo.SendAddonMessage, K.Aviso
  R.Via = function() return "hermandad" end
  C_ChatInfo.SendAddonMessage = function(_, t, c, d) salidos[#salidos + 1] = { t, c, d } end
  K.Aviso = function(o) avisos[#avisos + 1] = o return true end
  local ok, e = pcall(fn)
  R.Via, C_ChatInfo.SendAddonMessage, K.Aviso = via, envio, av
  A.Set("manada.compartir", false)
  if not ok then error(e) end
end
local function vaciarCola() for _ = 1, 60 do FIRE(R.motor, "OnUpdate", 0.2) end end
local function llega(texto, quien) FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", texto, "GUILD", quien) end
local function salio(patron)
  for _, m in ipairs(salidos) do if m[1]:find(patron) then return m[1] end end
  return nil
end

step("El mapa: la guarida en el cuadro y la marca del llamado", function()
  local Mapa = MN.Mapa
  check(Mapa.Llamado and Mapa.Llamados and Mapa.PintarLlamados, "faltan Mapa.Llamado, Llamados o PintarLlamados")
  conRed(function()
    local P = A.Pins
    local capas = {}
    local setLayer = P and P.SetLayer
    if P then P.SetLayer = function(id, pins) capas[id] = pins end end
    -- Un lobo de tu zona en su guarida.
    llega(("1P|%d|40.00|40.00|30|WARRIOR"):format(map), "Dana Ruiz")
    llega(("1G|%d|7|1"):format(map), "Dana Ruiz")
    Mapa.Refrescar(true)
    local pin
    for _, p in ipairs(capas["manada.jauria"] or {}) do if p.badge == "Dana" then pin = p end end
    if P then
      check(pin and type(pin.tooltip) == "function", "el lobo no salió en el mapa")
      if pin then
        local lineas = {}
        local tip = { SetText = function(_, t) lineas[#lineas + 1] = t end, AddLine = function(_, t) lineas[#lineas + 1] = t end }
        pin.tooltip(tip)
        local guarida = false
        for _, l in ipairs(lineas) do if tostring(l):find("Guarida", 1, true) then guarida = true end end
        check(guarida, "el cuadro del lobo no dice su guarida")
      end
    end
    -- Un llamado de ayuda: una marca en ese lugar.
    llega(("1A|%d|45.00|55.00|Mor'Ladim"):format(map), "Caro Vega")
    local l = Mapa.Llamados()
    check(#l == 1 and math.abs(l[1].x - 45) < 0.01 and l[1].quien == "Caro Vega", "el llamado no dejó su marca en el mapa")
    if P then
      local lp = capas["manada.llamados"] or {}
      check(#lp == 1 and type(lp[1].onClick) == "function", "la marca del llamado no está en su capa")
      if lp[1] then
        lp[1].onClick("LeftButton")
        local tgt = A.Nav and A.Nav.GetTarget and A.Nav.GetTarget()
        check(tgt and math.abs((tgt.x or 0) - 45) < 0.01, "el clic en la marca del llamado no puso la flecha ahí")
        if A.Nav.ReleaseTarget then A.Nav.ReleaseTarget() end
      end
    end
    -- A los 3 minutos se va.
    NOW = NOW + 200
    Mapa.PintarLlamados()
    check(#Mapa.Llamados() == 0, "la marca del llamado no se fue a los 3 minutos")
    if P then P.SetLayer = setLayer end
  end)
end)

step("Marcar el raro para todos", function()
  local Ra = MN.Raro
  check(Ra and Ra.Revisar and Ra.Boton, "falta Raro.lua")
  local g = { UnitExists = UnitExists, UnitIsPlayer = UnitIsPlayer, UnitIsDeadOrGhost = UnitIsDeadOrGhost,
    UnitClassification = UnitClassification, GetRaidTargetIndex = GetRaidTargetIndex, UnitName = UnitName,
    UnitGUID = UnitGUID, IsInGroup = IsInGroup, IsInRaid = IsInRaid, CanBeRaidTarget = CanBeRaidTarget,
    SetRaidTarget = SetRaidTarget }
  local clase, marca, grupo = "rare", nil, true
  local llamoSet = false
  UnitExists = function(u) return u == "player" or u == "target" end
  UnitIsPlayer = function(u) return u == "player" end
  UnitIsDeadOrGhost = function() return false end
  UnitClassification = function(u) return u == "target" and clase or "normal" end
  GetRaidTargetIndex = function() return marca end
  UnitName = function(u) if u == "target" then return "Mor'Ladim" end return g.UnitName(u) end
  UnitGUID = function(u) if u == "target" then return "Creature-0-1-2-3-522-0001" end return g.UnitGUID(u) end
  IsInGroup = function() return grupo end
  IsInRaid = function() return false end
  CanBeRaidTarget = function() return true end
  SetRaidTarget = function() llamoSet = true end
  local av = K.Aviso
  local dichos = {}
  K.Aviso = function(o) dichos[#dichos + 1] = o return true end
  Ra.Olvidar()
  local nombre = Ra.Revisar()
  local d = dichos[1]
  check(nombre == "Mor'Ladim" and d and d.accion, "no ofreció marcar el raro")
  local s = d and d.accion and d.accion.seguro
  check(s and s.type == "click" and s.clickbutton, "el botón no es el seguro del juego")
  local b = s and s.clickbutton
  check(b and b:GetAttribute("type") == "raidtarget" and tonumber(b:GetAttribute("marker")) == 8
    and b:GetAttribute("action") == "set-unmarked" and b:GetAttribute("unit") == "target", "el botón seguro no pone la calavera al objetivo")
  check(not llamoSet, "Alfa llamó a SetRaidTarget (tiene restricciones)")
  -- Otra vez el mismo: no se repite. Uno marcado, sin grupo o común: nada.
  check(Ra.Revisar() == nil and #dichos == 1, "ofreció dos veces el mismo raro")
  Ra.Olvidar()
  marca = 8
  check(Ra.Revisar() == nil, "ofreció marcar un raro ya marcado")
  marca, grupo = nil, false
  check(Ra.Revisar() == nil, "ofreció marcar sin grupo")
  grupo, clase = true, "normal"
  check(Ra.Revisar() == nil, "ofreció marcar a uno que no es raro")
  clase = "rareelite"
  A.Set("manada.marcarRaro", false)
  check(Ra.Revisar() == nil, "apagado, siguió ofreciendo")
  A.Set("manada.marcarRaro", true)
  check(Ra.Revisar() == "Mor'Ladim", "no ofreció marcar un raro élite")
  K.Aviso = av
  for k, v in pairs(g) do _G[k] = v end
  Ra.Olvidar()
end)

step("Cazar juntos", function()
  local J = MN.Juntos
  check(J and J.AlDiario and J.Comunes, "falta Juntos.lua")
  local Q = C_QuestLog
  local num, info = Q.GetNumQuestLogEntries, Q.GetInfo
  local diario = { { title = "Bosque de Elwynn", isHeader = true, questID = 0 },
    { title = "Lobos de Elwynn", questID = 101 }, { title = "Los kobolds", questID = 102 } }
  Q.GetNumQuestLogEntries = function() return #diario, 2 end
  Q.GetInfo = function(i) return diario[i] end
  conRed(function()
    J.Olvidar()
    J.AlDiario()
    vaciarCola()
    check(salio("^1M|101,102$"), "no salieron tus misiones (1M)")
    local n = #salidos
    diario[#diario + 1] = { title = "Mineral", questID = 103 }
    J.AlDiario()
    vaciarCola()
    check(#salidos == n, "salió otra lista antes de un minuto")
    -- Un lobo de tu zona con una misión en común.
    llega(("1P|%d|42.00|42.00|12|MAGE"):format(map), "Elsa Mora")
    avisos = {}
    llega("1M|101,555", "Elsa Mora")
    local clave = MN.U.Clave("Elsa Mora")
    check(J.Comunes(clave) == 1, "no contó la misión en común")
    local a = avisos[1]
    check(a and a.accion and a.accion.texto == "Invitar" and a.texto:find("Lobos de Elwynn", 1, true), "no propuso cazar juntos con «Invitar»")
    llega("1M|101", "Elsa Mora")
    check(#avisos == 1, "propuso cazar juntos dos veces con el mismo lobo")
    -- Sin nada en común, nada.
    llega(("1P|%d|43.00|43.00|12|MAGE"):format(map), "Fede Luna")
    llega("1M|999", "Fede Luna")
    check(J.Comunes(MN.U.Clave("Fede Luna")) == 0 and #avisos == 1, "contó misiones que no son comunes")
    -- Basura: se ignora.
    llega("1M|abc,1e9", "Fede Luna")
  end)
  Q.GetNumQuestLogEntries, Q.GetInfo = num, info
  J.Olvidar()
end)

step("El saludo de la manada", function()
  local Sa = MN.Saludo
  check(Sa and Sa.Decir and Sa.Texto, "falta Saludo.lua")
  local g = { IsInGuild = IsInGuild, GetNumGuildMembers = GetNumGuildMembers, GetGuildRosterInfo = GetGuildRosterInfo }
  local yo = A.Compat.UnitFullName("player") or "Lobato"
  local filas = {
    { yo, true, "Ventormenta" },
    { "Ana Smith", true, "Bosque de Elwynn" },
    { "Beto Ruiz", true, "Durotar" },
    { "Caro Vega", false, "Páramos" },
    { "Dana Ruiz", true, "Los Baldíos" },
    { "Elsa Mora", true, "Montañas de Alterac" },
  }
  IsInGuild = function() return true end
  GetNumGuildMembers = function() return #filas, 5 end
  GetGuildRosterInfo = function(i)
    local f = filas[i]
    if not f then return nil end
    return f[1], "Lobo", 1, 30, "Guerrero", f[3], "", "", f[2], 0, "WARRIOR", 0, 0, false
  end
  local av = K.Aviso
  local dichos = {}
  K.Aviso = function(o) dichos[#dichos + 1] = o return true end
  Sa.Olvidar()
  check(Sa.Decir(), "no saludó con la manada conectada")
  local t = dichos[1] and dichos[1].texto or ""
  check(t:find("Ana Smith (Bosque de Elwynn)", 1, true), "no dijo quién y dónde: " .. t)
  check(t:find("1 más", 1, true), "no dijo cuántos más: " .. t)
  check(not t:find("Ventormenta", 1, true), "te contó a ti mismo: " .. t)
  check(not t:find("Caro Vega", 1, true), "contó a alguien desconectado: " .. t)
  check(not Sa.Decir(), "saludó dos veces en la sesión")
  -- Sin nadie conectado: nada. Apagado: nada.
  Sa.Olvidar()
  filas = { { yo, true, "Ventormenta" } }
  check(not Sa.Decir(), "saludó sin nadie conectado")
  filas = { { "Ana Smith", true, "Durotar" } }
  A.Set("manada.saludo", false)
  check(not Sa.Decir(), "apagado, saludó")
  A.Set("manada.saludo", true)
  K.Aviso = av
  for k, v in pairs(g) do _G[k] = v end
  Sa.Olvidar()
end)

step("Los logros de la insignia en el retrato", function()
  local Rt, I = MN.Retrato, MN.Insignias
  local de, hay, nivel = I.DeUnidad, I.Hay, UnitLevel
  I.DeUnidad = function(u) return u == "player" and "alfa" or nil end
  I.Hay = function() return true end
  UnitLevel = function() return 60 end
  Rt.Refrescar()
  local ch = Rt.Chapa("player")
  check(ch and ch.aro:IsShown() and ch.estrella and ch.estrella:IsShown(), "sin la estrella del nivel máximo")
  UnitLevel = function() return 23 end
  Rt.Refrescar()
  check(ch and not ch.estrella:IsShown(), "la estrella sale antes del nivel máximo")
  local Ra = A.Rares
  if Ra and Ra.History then
    local hist = Ra.History
    Ra.History = function()
      local h = {}
      for i = 1, 100 do h["rare:" .. i] = { kind = "rare" } end
      h["treasure:1"] = { kind = "treasure" }
      return h
    end
    A.Fire("RARES_HISTORY", "rare:1")
    check(Rt.RarosVistos() == 100, "no contó los raros vistos")
    check(ch and ch.raros:IsShown(), "sin el detalle de los 100 raros")
    Ra.History = hist
    A.Fire("RARES_HISTORY", "rare:1")
  end
  -- Sin insignia, nada.
  I.DeUnidad = function() return nil end
  Rt.Refrescar()
  check(ch and not ch.aro:IsShown() and not ch.estrella:IsShown() and not ch.raros:IsShown(), "sin insignia quedaron sus logros")
  I.DeUnidad, I.Hay, UnitLevel = de, hay, nivel
  Rt.Refrescar()
end)

print(string.format("PRUEBA: 1.2.7 La Jauría (mapa, raro, cazar juntos, saludo, logros), %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
