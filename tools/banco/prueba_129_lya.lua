-- Prueba de la 1.2.9, Lya, Mundo y Mazmorras (tools/prueba.py la corre con las demás prueba_*.lua):
--   * cuando caes: como espíritu, Lya dice a cuánto está tu cuerpo, lo que
--     cuesta el ángel a tu nivel y qué conviene (lo mismo que el motor); sin
--     el motor pone la flecha en tu cuerpo (0-100); una vez por caída;
--   * la hora, la fiesta y el lugar: los ratos del día, las fiestas fijas y
--     las del calendario, la línea de la zona (de día y de noche), el festejo
--     una vez al día y lo del momento de Cerebro;
--   * tu clase: lo que ya sabías no se cuenta; lo nuevo (por id o al cambiar
--     tus hechizos) sí, con su nombre, uno por globo con «¿Y el siguiente?»;
--   * el modo foco: chiquita, tenue y sin atrapar clics en combate; en
--     mazmorras; al salir vuelve; apagado no hace nada;
--   * el menú: «Cambiar de plano» con la API de la manada, en 10 filas;
--   * Mundo: los rincones por descubrir de tu zona (con la experiencia que
--     dio el último) y los vuelos que te faltan (clic: la flecha);
--   * Mazmorras: la tarjeta del jefe en vivo por tu papel, con tus misiones;
--     nunca atrapa clics, no lee lo secreto y no trabaja en combate.
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
local function check(cond, msg) if not cond then NOTE("1.2.9 Lya", msg) end end

local A = AlfaNucleo.A
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local Ly = NS_OF("Alfa_Lya")
local Mu, Ah, Cl, Fo = Ly.Muerte, Ly.Ahora, Ly.Clase, Ly.Foco
local Mn = NS_OF("Alfa_Mundo")
local Mz = NS_OF("Alfa_Mazmorras")
local datos = function() return AlfaNucleo.DatosPersonaje("lya") end

-- Lya a la vista, y lo que dice.
local dichos = {}
local function conLya(fn, real)
  local Ce, UI = Ly.Cerebro, Ly.UI
  local activa, visible, decir = Ce.Activa, UI.Visible, Ce.Decir
  Ce.Activa = function() return true end
  UI.Visible = function() return true end
  if not real then Ce.Decir = function(c) dichos[#dichos + 1] = c return true end end
  local ok, e = pcall(fn)
  Ce.Activa, UI.Visible, Ce.Decir = activa, visible, decir
  if not ok then error(e) end
end
local function dijo(patron, desde)
  for i = (desde or 0) + 1, #dichos do
    local t = dichos[i].texto
    if type(t) == "string" and t:find(patron, 1, true) then return dichos[i] end
  end
  return nil
end

step("Los archivos nuevos están cargados y sus ajustes, prendidos", function()
  check(type(Mu) == "table" and Mu.Aconsejar and Mu.Consejo, "falta Muerte.lua")
  check(type(Ah) == "table" and Ah.Hora and Ah.Fiestas and Ah.Decir, "falta Ahora.lua")
  check(type(Cl) == "table" and Cl.Revisar and Cl.Siguiente, "falta Clase.lua")
  check(type(Fo) == "table" and Fo.Revisar, "falta Foco.lua")
  check(type(Mn.Descubrir) == "table", "falta Alfa_Mundo/Descubrir.lua")
  check(type(Mz.EnVivo) == "table", "falta Alfa_Mazmorras/EnVivo.lua")
  for _, k in ipairs({ "lya.muerte", "lya.momento", "lya.clase", "lya.foco", "mundo.porDescubrir", "mundo.vuelosFaltan", "mazmorras.enVivo" }) do
    check(A.Get(k) == true, k .. " no viene prendido")
  end
  check(A.Get("mazmorras.enVivoRol") == "auto", "mazmorras.enVivoRol no viene en automático")
  check(type(AlfaLya.EnFoco) == "function", "falta AlfaLya.EnFoco")
end)

---------------------------------------------------------------------------
-- 7. Cuando caes
---------------------------------------------------------------------------
step("Cuando caes: el consejo del motor, con números, una vez por caída", function()
  local g, Q = UnitIsGhost, A.QoL.GetDeathAdvice
  local ul = UnitLevel
  UnitIsGhost = function() return true end
  UnitLevel = function() return 30 end
  A.QoL.GetDeathAdvice = function()
    return { choice = "corpse", corpseYards = 230, corpseSeconds = 33, healerYards = 90, sickness = 600 }
  end
  local n = #dichos
  conLya(function()
    FIRE_EVENT("PLAYER_DEAD")
    FIRE_EVENT("PLAYER_ALIVE")
    RUN_TIMERS(3)
  end)
  local c = dijo("Tu cuerpo está a", n)
  check(c and c.importante, "Lya no dijo a cuánto está tu cuerpo")
  check(c and c.texto:find("25 %", 1, true) and c.texto:find("10 min", 1, true), "no dijo lo que cuesta el ángel a tu nivel: " .. tostring(c and c.texto))
  check(c and c.texto:find("Yo correría por tu cuerpo", 1, true), "no dijo qué conviene")
  check(c and not c.acciones, "con el motor sosteniendo la flecha, Lya ofreció otra")
  local n2 = #dichos
  conLya(function() FIRE_EVENT("PLAYER_ALIVE") RUN_TIMERS(3) end)
  check(not dijo("ángel", n2), "Lya repitió el consejo en la misma caída")
  A.QoL.GetDeathAdvice = function() return { choice = "healer", corpseYards = 900, corpseSeconds = 130, healerYards = 40, sickness = 0 } end
  local n3 = #dichos
  conLya(function() FIRE_EVENT("PLAYER_DEAD") FIRE_EVENT("PLAYER_ALIVE") RUN_TIMERS(3) end)
  local c3 = dijo("conviene el ángel", n3)
  check(c3 and c3.texto:find("no quedas débil", 1, true), "sin debilidad, Lya no dijo que conviene el ángel")
  UnitIsGhost, A.QoL.GetDeathAdvice, UnitLevel = g, Q, ul
end)

step("Cuando caes: sin el motor, la flecha a tu cuerpo en 0-100; apagado, nada", function()
  local g, Q, Di, nav, ul = UnitIsGhost, A.QoL.GetDeathAdvice, C_DeathInfo, A.Nav.SetTarget, UnitLevel
  UnitIsGhost = function() return true end
  UnitLevel = function() return 8 end
  A.QoL.GetDeathAdvice = function() return nil end
  C_DeathInfo = { GetCorpseMapPosition = function(m) return { x = 0.6, y = 0.4, GetXY = function() return 0.6, 0.4 end } end }
  local puesto
  A.Nav.SetTarget = function(map, x, y, nombre) puesto = { map = map, x = x, y = y, nombre = nombre } return {} end
  local n = #dichos
  conLya(function() FIRE_EVENT("PLAYER_DEAD") FIRE_EVENT("PLAYER_ALIVE") RUN_TIMERS(3) end)
  check(puesto and puesto.map == 1411 and math.abs(puesto.x - 60) < 0.01 and math.abs(puesto.y - 40) < 0.01,
    "la flecha no quedó en tu cuerpo en 0-100")
  local c = dijo("no quedas débil", n)
  check(c and c.acciones and c.acciones[1].texto == "Llévame a mi cuerpo", "sin el motor, falta «Llévame a mi cuerpo»")
  A.Set("lya.muerte", false)
  local n2 = #dichos
  conLya(function() FIRE_EVENT("PLAYER_DEAD") FIRE_EVENT("PLAYER_ALIVE") RUN_TIMERS(3) end)
  check(not dijo("ángel", n2), "con lya.muerte apagado Lya dio el consejo")
  A.Set("lya.muerte", true)
  FIRE_EVENT("PLAYER_UNGHOST")
  UnitIsGhost, A.QoL.GetDeathAdvice, C_DeathInfo, A.Nav.SetTarget, UnitLevel = g, Q, Di, nav, ul
end)

---------------------------------------------------------------------------
-- 13. La hora, la fiesta y el lugar
---------------------------------------------------------------------------
step("La hora y las fiestas: los ratos del día, las fijas y las del calendario", function()
  check(Ah.Hora(3) == "madrugada" and Ah.Hora(9) == "manana" and Ah.Hora(15) == "tarde" and Ah.Hora(22) == "noche", "los ratos del día están mal")
  local f = Ah.Fiestas(10, 25)
  check(#f == 1 and f[1].clave == "brujas", "el 25 de octubre no es Halloween de Azeroth")
  check(Ah.Fiestas(12, 31)[1] and Ah.Fiestas(12, 31)[1].clave == "invierno", "el 31 de diciembre no es el Festival de Invierno")
  check(Ah.Fiestas(1, 2)[1] and Ah.Fiestas(1, 2)[1].clave == "invierno", "el Festival de Invierno no cruza el año")
  check(Ah.Fiestas(6, 30)[1] and Ah.Fiestas(6, 30)[1].clave == "solsticio", "el 30 de junio no es el Solsticio")
  local C, T = C_Calendar, C_DateAndTime
  C_DateAndTime = { GetCurrentCalendarTime = function() return { monthDay = 3, month = 2, year = 2026 } end }
  C_Calendar = {
    GetMonthInfo = function() return { month = 2, year = 2026 } end,
    GetNumDayEvents = function() return 2 end,
    GetDayEvent = function(_, _, i)
      if i == 1 then return { calendarType = "HOLIDAY", title = "Festival Lunar" } end
      return { calendarType = "PLAYER", title = "Mi cita" }
    end,
  }
  local l = Ah.Fiestas(2, 3)
  check(#l == 1 and l[1].nombre == "Festival Lunar", "la fiesta del calendario no se leyó (o se coló una cita)")
  C_Calendar.GetMonthInfo = function() return { month = 5, year = 2026 } end
  check(#Ah.Fiestas(2, 3) == 0, "se leyó el calendario de otro mes")
  C_Calendar, C_DateAndTime = C, T
  check(#Ah.Fiestas(3, 10) == 0, "hubo fiesta un día sin fiesta")
end)

step("La hora, la fiesta y el lugar: Lya lo dice, sin repetirse; apagado, nada", function()
  local realDate = date
  date = function(f, t)
    if f == "%m" then return "10" elseif f == "%d" then return "25" elseif f == "%H" then return "15" end
    return realDate(f, t)
  end
  datos().ahora = nil
  local n = #dichos
  conLya(function() check(Ah.Festejo(), "Lya no festejó la fiesta del día") end)
  check(dijo("Halloween", n) or dijo("calabazas", n), "el festejo no habla de Halloween de Azeroth")
  -- alDecir lo anota (el falso Decir no lo llama): a mano.
  datos().ahora.festejo = realDate("%Y-%m-%d")
  conLya(function() check(not Ah.Festejo(), "Lya festejó dos veces el mismo día") end)
  -- Cada línea una vez: la fiesta, la hora y la zona (Durotar, la del banco).
  local vistos = {}
  for _ = 1, 8 do
    local id, t, e = Ah.Linea()
    if id then vistos[id] = t datos().ahora[id] = e.hora or os.time() end
  end
  local zona, hora, fiesta = false, false, false
  for id, t in pairs(vistos) do
    if id:find("^z%.1411") then zona = true end
    if id == "h.tarde" then hora = true end
    if id:find("^f%.brujas") then fiesta = true end
  end
  check(zona and hora and fiesta, "faltó la línea de la zona, de la hora o de la fiesta")
  check(Ah.Linea() == nil, "una línea dicha volvió a salir enseguida")
  -- Lo del momento de Cerebro pasa por aquí.
  datos().ahora = nil
  local r = math.random
  math.random = function(a, b) if a then return a end return 0.1 end
  local n2 = #dichos
  conLya(function() Ly.Cerebro.DelMomento() end)
  math.random = r
  check(#dichos > n2 and dichos[#dichos].clase == "momento", "lo del momento no dijo la hora, la fiesta o el lugar")
  A.Set("lya.momento", false)
  conLya(function() check(not Ah.Decir(true) and not Ah.Festejo(), "con lya.momento apagado Lya habló de la hora") end)
  A.Set("lya.momento", true)
  date = realDate
end)

---------------------------------------------------------------------------
-- 14. Tu clase
---------------------------------------------------------------------------
step("Tu clase: lo que ya sabías no se cuenta; lo nuevo, con su nombre y uno por globo", function()
  local SB, S = C_SpellBook, C_Spell
  local sabe = { [100] = true }
  C_SpellBook = { IsSpellKnown = function(id) return sabe[id] == true end }
  C_Spell = setmetatable({ GetSpellName = function(id)
    return ({ [100] = "Cargar", [71] = "Actitud defensiva", [355] = "Provocar", [6343] = "Atronar" })[id]
  end }, { __index = S })
  local d = datos()
  d.clase, d.claseBase = nil, nil
  local n = #dichos
  conLya(function() Cl.Revisar() RUN_TIMERS(2) end)
  check(#dichos == n and d.claseBase and d.clase["100"], "la primera revisión contó lo que ya sabías")
  sabe[71], sabe[355] = true, true
  conLya(function()
    FIRE_EVENT("LEARNED_SPELL_IN_SKILL_LINE", 71, 1, false)
    FIRE_EVENT("LEARNED_SPELL_IN_SKILL_LINE", 355, 1, false)
    RUN_TIMERS(3)
  end)
  local c = dijo("Aprendiste Actitud defensiva", n)
  check(c and c.texto:find("tanquear", 1, true), "Lya no enseñó para qué sirve la postura defensiva")
  check(c and c.acciones and c.acciones[1].texto == "¿Y el siguiente?", "con dos nuevos falta «¿Y el siguiente?»")
  check(not dijo("Provocar", n), "Lya dijo dos hechizos en un mismo globo")
  if c and c.acciones then conLya(function() c.acciones[1].fn() RUN_TIMERS(2) end) end
  check(dijo("Aprendiste Provocar", n), "«¿Y el siguiente?» no dijo el siguiente")
  -- Al cambiar tus hechizos (sin el id): también.
  sabe[6343] = true
  local n2 = #dichos
  conLya(function() FIRE_EVENT("SPELLS_CHANGED") RUN_TIMERS(3) end)
  check(dijo("Aprendiste Atronar", n2), "SPELLS_CHANGED no enseñó el hechizo nuevo")
  local n3 = #dichos
  conLya(function() FIRE_EVENT("LEARNED_SPELL_IN_SKILL_LINE", 71, 1, false) FIRE_EVENT("SPELLS_CHANGED") RUN_TIMERS(3) end)
  check(#dichos == n3, "Lya repitió un hechizo que ya te enseñó")
  -- Las 9 clases tienen sus hechizos.
  for _, k in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
    check(type(Ly.HECHIZOS[k]) == "table" and #Ly.HECHIZOS[k] >= 15, "faltan los hechizos de " .. k)
  end
  A.Set("lya.clase", false)
  sabe[7386] = true
  local n4 = #dichos
  conLya(function() FIRE_EVENT("LEARNED_SPELL_IN_SKILL_LINE", 7386, 1, false) RUN_TIMERS(3) end)
  check(#dichos == n4, "con lya.clase apagado Lya enseñó")
  A.Set("lya.clase", true)
  C_SpellBook, C_Spell = SB, S
end)

---------------------------------------------------------------------------
-- 20. El modo foco
---------------------------------------------------------------------------
step("Modo foco: chiquita y sin clics en combate, en mazmorras; al salir vuelve", function()
  conLya(function() Ly.UI.Aplicar() end)
  local f = _G.AlfaLyaLoba
  check(f, "no está Lya")
  if not f then return end
  local icl = InCombatLockdown
  InCombatLockdown = function() return true end
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(AlfaLya.EnFoco() and f.Andar:GetScale() < 1, "en combate Lya no se hizo chiquita")
  check(f:IsMouseEnabled() == false, "en combate y en foco Lya atrapa clics")
  InCombatLockdown = icl
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  check(not AlfaLya.EnFoco() and f.Andar:GetScale() == 1 and f:IsMouseEnabled() ~= false, "al salir del combate Lya no volvió")
  local ii = IsInInstance
  IsInInstance = function() return true, "party" end
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  check(AlfaLya.EnFoco(), "en una mazmorra Lya no entró en foco")
  local r, por
  conLya(function() r, por = Ly.Cerebro.Decir({ id = "ambiente1", texto = "Qué bonito." }) end, true)
  check(r == false, "en foco Lya platicó dentro de la mazmorra")
  IsInInstance = ii
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  check(not AlfaLya.EnFoco(), "al salir de la mazmorra Lya siguió en foco")
  A.Set("lya.foco", false)
  InCombatLockdown = function() return true end
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not AlfaLya.EnFoco(), "con lya.foco apagado Lya entró en foco")
  InCombatLockdown = icl
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  A.Set("lya.foco", true)
  check(A.Get("lya.foco") == true and AlfaNucleo.Get("lya", "foco") == true, "el rastreador no puede leer lya.foco")
end)

---------------------------------------------------------------------------
-- El menú: «Cambiar de plano»
---------------------------------------------------------------------------
step("El menú: «Cambiar de plano» con la API de la manada, en 10 filas", function()
  local f = _G.AlfaLyaLoba
  if not f then return end
  local K = AlfaNucleo.Kit
  local menu, opciones, elegir = K.Menu, nil, nil
  K.Menu = function(_, o, _, fn) opciones, elegir = o, fn end
  local antes = rawget(_G, "AlfaManada")
  local cambiado = false
  AlfaManada = setmetatable({ CambiarPlano = function() cambiado = true end }, { __index = antes })
  f:GetScript("OnClick")(f, "RightButton")
  local filas, plano, bloquear = 0, false, false
  for _, o in ipairs(opciones or {}) do
    filas = filas + 1
    if o.valor == "plano" then plano = true end
    if o.valor == "bloquear" then bloquear = true end
  end
  check(plano, "falta «Cambiar de plano» con la API de la manada")
  check(filas <= 10, "el menú pasó de 10 filas: " .. filas)
  check(not bloquear, "con «Cambiar de plano», «Bloquear posición» siguió en el menú")
  if elegir then elegir("plano") end
  check(cambiado, "«Cambiar de plano» no llamó a AlfaManada.CambiarPlano")
  AlfaManada = setmetatable({}, { __index = function(_, k) if k == "CambiarPlano" then return nil end return antes and antes[k] end })
  f:GetScript("OnClick")(f, "RightButton")
  local hay = false
  for _, o in ipairs(opciones or {}) do if o.valor == "plano" then hay = true end end
  check(not hay, "sin la API, «Cambiar de plano» salió en el menú")
  AlfaManada = antes
  K.Menu = menu
end)

---------------------------------------------------------------------------
-- 15 y 16. Mundo: por descubrir y los vuelos que te faltan
---------------------------------------------------------------------------
step("Mundo: los rincones por descubrir de tu zona, con la experiencia que dio el último", function()
  local Ds, Geo = Mn.Descubrir, Mn.Geo
  check(Mn.Capas.PorId("zonas.porDescubrir") and Mn.Capas.PorId("viaje.vuelosFaltan"), "las capas nuevas no están en el control de capas")
  local zonaReal, ZA, X = Ds.Zona, A.UI.ZoneArt, C_MapExplorationInfo
  Ds.Zona = function() return 1411 end
  A.UI.ZoneArt = setmetatable({ FullOverlays = function() return { 256, 256, { 100, 100, 0, 0, 1 }, { 200, 100, 500, 300, 2 } } end }, { __index = ZA })
  C_MapExplorationInfo = { GetExploredMapTextures = function() return { { textureWidth = 100, textureHeight = 100, offsetX = 0, offsetY = 0 } } end }
  local r = Ds.Rincones(1411)
  check(#r == 1 and math.abs(r[1].x - 600 / 1002 * 100) < 0.01 and math.abs(r[1].y - 350 / 668 * 100) < 0.01, "los rincones por descubrir están mal")
  ERR_ZONE_EXPLORED_XP = "Descubierto: %s: %d puntos de experiencia."
  FIRE_EVENT("CHAT_MSG_SYSTEM", "Descubierto: El Valle de las Pruebas: 45 puntos de experiencia.")
  check(AlfaNucleo.DatosPersonaje("mundo").exploracion[1411] == 45, "no se anotó la experiencia del descubrimiento")
  Ds.Refrescar()
  local capa = A.Pins.GetLayer("mundo.porDescubrir")
  check(type(capa) == "table" and #capa == 1 and capa[1].map == 1411, "la capa «Por descubrir» no se publicó")
  if capa and capa[1] then
    local lineas = {}
    local tip = { SetText = function(_, t) lineas[#lineas + 1] = t end, AddLine = function(_, t) lineas[#lineas + 1] = t end }
    capa[1].tooltip(tip)
    check(table.concat(lineas, " "):find("45", 1, true), "el pin no dice la experiencia que dio el último")
  end
  A.Set("mundo.porDescubrir", false)
  RUN_TIMERS(2)
  check(not A.Pins.GetLayer("mundo.porDescubrir") or #A.Pins.GetLayer("mundo.porDescubrir") == 0, "apagada, la capa siguió")
  A.Set("mundo.porDescubrir", true)
  Ds.Zona, A.UI.ZoneArt, C_MapExplorationInfo = zonaReal, ZA, X
end)

step("Mundo: los vuelos que te faltan en tu zona; clic, la flecha", function()
  local Ds, Geo = Mn.Descubrir, Mn.Geo
  local zonaReal, unk, gp, dy, cad, nav = Ds.Zona, A.Nav.UnknownTaxiOn, A.Compat.GetPlayerWorldPosition, Geo.DeYardas, Geo.Cadena, A.Nav.SetTarget
  Ds.Zona = function() return 1411 end
  A.Nav.UnknownTaxiOn = function(c, out)
    out[1] = { id = 99, c = 1, wx = 10, wy = 20, name = "Campamento de prueba" }
    out[2] = { id = 98, c = 1, wx = 99, wy = 99, name = "Otro lado" }
    out[3] = nil
    return out
  end
  A.Compat.GetPlayerWorldPosition = function() return 1, 0, 0 end
  local l, r, t, b = Geo.Rect(1411)
  Geo.DeYardas = function(c, wx) if wx == 10 then return l + (r - l) * 0.3, t + (b - t) * 0.7 end return 0.01, 0.01 end
  Geo.Cadena = function(u) if u > 0.02 then return 1414, 1411 end return 1414, 1413 end
  local puesto
  A.Nav.SetTarget = function(map, x, y, nombre) puesto = { map = map, x = x, y = y, nombre = nombre } return {} end
  Ds.Refrescar()
  local capa = A.Pins.GetLayer("mundo.vuelosFaltan")
  check(type(capa) == "table" and #capa == 1 and capa[1].label == "Campamento de prueba", "la capa de vuelos que te faltan está mal")
  if capa and capa[1] then
    capa[1].onClick("LeftButton")
    check(puesto and puesto.map == 1411 and math.abs(puesto.x - 30) < 0.5 and math.abs(puesto.y - 70) < 0.5, "el clic no puso la flecha en el vuelo (0-100)")
  end
  Ds.Zona, A.Nav.UnknownTaxiOn, A.Compat.GetPlayerWorldPosition, Geo.DeYardas, Geo.Cadena, A.Nav.SetTarget = zonaReal, unk, gp, dy, cad, nav
  Ds.Refrescar()
end)

---------------------------------------------------------------------------
-- 28. Mazmorras: el jefe en vivo
---------------------------------------------------------------------------
step("Mazmorras: la tarjeta del jefe por tu papel, con tus misiones, sin atrapar clics", function()
  local Ev, D, P = Mz.EnVivo, Mz.D, Mz.P
  local ii, guid, listo, actual, jefes, estado, isv, icl = IsInInstance, UnitGUID, D.Listo, D.MazmorraActual, D.Jefes, P.Estado, issecretvalue, InCombatLockdown
  local SECRETO = {}
  local objetivo = "Creature-0-1-2-3-644-00001"
  IsInInstance = function() return true, "party" end
  UnitGUID = function(u) if u == "target" then return objetivo end return "Player-1-0001" end
  issecretvalue = function(v) return v == SECRETO end
  D.Listo = function() return true end
  D.MazmorraActual = function() return "deadmines" end
  D.Jefes = function() return { { id = "644", npc = 644, nombre = "Rhahk'Zor", encuentro = 1443, consejos = Mz.Consejos.deadmines[644] },
    { id = "646", npc = 646, nombre = "Mr. Smite", encuentro = 1444, consejos = Mz.Consejos.deadmines[646] } } end
  local lecturas = 0
  P.Estado = function() lecturas = lecturas + 1 return { lista = {
    { grupo = "registro", q = { title = "Los Defias" }, orden = 3, texto = "Cabezas: 3/10" },
    { grupo = "registro", q = { title = "Oro rojo" }, orden = 1 },
    { grupo = "hechas", q = { title = "Vieja" } },
  } } end
  A.Set("mazmorras.enVivoRol", "tanque")
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  RUN_TIMERS(3)
  check(Ev.Actual() and Ev.Actual().key == "deadmines", "no se indexaron los jefes al entrar")
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  local t = Ev.Marco()
  check(Ev.Visible(), "al apuntar al jefe no salió la tarjeta")
  local todo = {}
  if t then
    check(t:IsMouseEnabled() == false, "la tarjeta atrapa clics")
    todo[#todo + 1] = t.Titulo:GetText()
    todo[#todo + 1] = t.Papel:GetText()
    for _, fs in ipairs(t.lineas) do if fs:IsShown() then todo[#todo + 1] = fs:GetText() end end
  end
  local s = table.concat(todo, " | ")
  check(s:find("Rhahk'Zor", 1, true), "la tarjeta no dice el jefe: " .. s)
  check(s:find("Tanqueas", 1, true) and s:find("de espaldas al grupo", 1, true), "la tarjeta no da el consejo del tanque: " .. s)
  check(s:find("Oro rojo", 1, true) and s:find("ReadyCheck", 1, true) and s:find("Cabezas: 3/10", 1, true), "la tarjeta no marca tus misiones: " .. s)
  check(not s:find("Vieja", 1, true), "la tarjeta mostró una misión ya hecha")
  -- Otro objetivo que no es jefe: se va sola.
  objetivo = "Creature-0-1-2-3-999-00001"
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  RUN_TIMERS(3)
  check(not Ev.Visible(), "la tarjeta se quedó al cambiar a un enemigo que no es jefe")
  -- Un objetivo secreto no se lee; el encuentro sí trae la tarjeta.
  objetivo = SECRETO
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  check(not Ev.Visible(), "con un objetivo secreto salió una tarjeta")
  InCombatLockdown = function() return true end
  local antes = lecturas
  FIRE_EVENT("ENCOUNTER_START", 1444, "Mr. Smite", 1, 5)
  check(Ev.Visible() and t.Titulo:GetText() == "Mr. Smite", "el encuentro no trajo la tarjeta de su jefe")
  objetivo = "Creature-0-1-2-3-644-00001"
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  check(lecturas == antes, "en combate se leyeron las misiones")
  InCombatLockdown = icl
  FIRE_EVENT("ENCOUNTER_END", 1444, "Mr. Smite", 1, 5, 1)
  RUN_TIMERS(3)
  check(not Ev.Visible(), "al terminar el encuentro la tarjeta no se fue")
  -- Tu papel en automático: un sacerdote cura.
  A.Set("mazmorras.enVivoRol", "auto")
  local uc = UnitClass
  UnitClass = function() return "Sacerdote", "PRIEST", 5 end
  check(Ev.Papel() == "cura", "en automático un sacerdote no cura")
  UnitClass = uc
  A.Set("mazmorras.enVivo", false)
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  check(not Ev.Visible(), "con mazmorras.enVivo apagado salió la tarjeta")
  A.Set("mazmorras.enVivo", true)
  IsInInstance, UnitGUID, D.Listo, D.MazmorraActual, D.Jefes, P.Estado, issecretvalue, InCombatLockdown = ii, guid, listo, actual, jefes, estado, isv, icl
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  RUN_TIMERS(3)
end)

step("Las páginas: Lya y los ajustes de Mazmorras abren sin errores", function()
  local ok, e = pcall(function()
    A.Fire("SHOW_OPTIONS", "lya")
    RUN_TIMERS(2)
    A.Fire("SHOW_OPTIONS", "dungeons")
    RUN_TIMERS(2)
    A.Fire("SHOW_OPTIONS", "mundo")
    RUN_TIMERS(2)
  end)
  check(ok, "una página falló: " .. tostring(e))
end)

print(string.format("PRUEBA: 1.2.9 Lya, Mundo y Mazmorras, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
