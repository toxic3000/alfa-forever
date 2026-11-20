-- Prueba de la 1.3.0, Combate (tools/prueba.py la corre con las demás prueba_*.lua):
--   * el aviso para cortar: tu objetivo o tu foco lanza algo que se puede
--     cortar -> tu corte, su tecla y si está listo; lo que no se puede cortar
--     y los oficios no avisan; con datos secretos no se compara (el juego
--     decide con SetAlphaFromBoolean); nunca toma el ratón;
--   * la barra de amenaza: en grupo, avisa antes de quitárselo al tanque y
--     cuando ya te ataca; como tanque, cuando están por quitártelo y cuando lo
--     perdiste; secretos sin errores; sola y sin mascota no sale;
--   * el ícono de rotación más grande, con la tecla grande abajo al centro
--     (también en las que siguen) y su tamaño configurable;
--   * el resumen de la pelea con el medidor del juego (solo tu fila): daño,
--     curación, duración y lo que más te pegó; peleas cortas no; al empezar
--     otra se esconde; "Ver de nuevo"; nunca el registro de combate;
--   * las recargas largas: entran al lanzarlas, con su tiempo; con tiempos
--     secretos se estiman; se ocultan desde la lista; se van al volver;
--   * Lya enseña las cuatro y la página abre sin errores.
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
local function check(cond, msg) if not cond then NOTE("1.3.0 Combate", msg) end end
local function T(n) RUN_TIMERS(n or 1) end

---------------------------------------------------------------------------
-- El juego simulado: un guerrero con Patada, Temeridad e Ira sangrienta
---------------------------------------------------------------------------
local SECRETO = setmetatable({}, { __tostring = function() return "<secreto>" end })
issecretvalue = function(v) return rawequal(v, SECRETO) end

local NOMBRES = { [6552] = "Patada", [1719] = "Temeridad", [2687] = "Ira sangrienta", [133] = "Bola de Fuego", [11578] = "Cargar" }
local POR_NOMBRE = {}
for id, n in pairs(NOMBRES) do POR_NOMBRE[n] = id end
local conocidos = { [6552] = true, [1719] = true, [2687] = true }
local cds = {}        -- id -> info de recarga
local enRango = true
IsPlayerSpell = function(id) return conocidos[id] == true end
C_SpellBook = { IsSpellKnown = function(id) return conocidos[id] == true end }
C_Spell = {
  GetSpellName = function(id) return NOMBRES[id] end,
  GetSpellInfo = function(x)
    local id = type(x) == "number" and x or POR_NOMBRE[x]
    return id and { spellID = id, name = NOMBRES[id] } or nil
  end,
  GetSpellTexture = function(id) return 100000 + (tonumber(id) or 0) end,
  IsSpellUsable = function(id) return conocidos[id] == true, false end,
  IsSpellInRange = function() return enRango end,
  GetSpellCooldown = function(id)
    return cds[id] or { startTime = 0, duration = 0, isEnabled = true, isActive = false, modRate = 1, isOnGCD = false }
  end,
}
local function recarga(id, dur, desde)
  cds[id] = { startTime = desde or NOW, duration = dur, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
end

-- Tus barras: Patada en la casilla 1 (tecla F) e Ira sangrienta en la 2 (tecla 2).
local CASILLA = { [6552] = 1, [2687] = 2, [1719] = 3 }
local TECLA = { ACTIONBUTTON1 = "F", ACTIONBUTTON2 = "2", ACTIONBUTTON3 = "SHIFT-3" }
for i = 1, 12 do
  local b = rawget(_G, "ActionButton" .. i) or CreateFrame("CheckButton", "ActionButton" .. i, UIParent)
  b.action = i
  b:Show()
end
C_ActionBar = C_ActionBar or {}
C_ActionBar.FindSpellActionButtons = function(id) return CASILLA[id] and { CASILLA[id] } or {} end
GetBindingKey = function(accion) return TECLA[accion] end

-- Tu objetivo y tu foco.
local unidades = { player = true }
local lanza = {}      -- unidad -> { nombre, tex, fin, oficio, inmune, canal }
UnitExists = function(u) return unidades[u] == true end
UnitCanAttack = function(_, u) return u == "target" or u == "focus" end
UnitIsDeadOrGhost = function() return false end
UnitIsUnit = function(a, b) return a == b end
UnitCastingInfo = function(u)
  local c = lanza[u]
  if not c or c.canal then return nil end
  return c.nombre, c.nombre, c.tex or 136197, NOW * 1000, c.fin or (NOW + 2) * 1000, c.oficio or false, "Cast-1", c.inmune, 686
end
UnitChannelInfo = function(u)
  local c = lanza[u]
  if not c or not c.canal then return nil end
  return c.nombre, c.nombre, c.tex or 136197, NOW * 1000, c.fin or (NOW + 3) * 1000, c.oficio or false, c.inmune, 5143
end

-- Combate y grupo.
local combate, grupo, mascota = false, false, false
InCombatLockdown = function() return combate end
UnitAffectingCombat = function() return combate end
IsInGroup = function() return grupo end
local amenaza = { false, 0, 0 }
UnitDetailedThreatSituation = function() return amenaza[1], amenaza[2], amenaza[3], amenaza[3], 1000 end
UnitGroupRolesAssigned = function() return "NONE" end
GetShapeshiftFormID = function() return nil end

-- El medidor del juego.
Enum.DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6,
  DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 }
Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }
local medidor = {
  [0] = { { name = "Grom", isLocalPlayer = false, totalAmount = 20000, amountPerSecond = 666, classFilename = "WARRIOR" },
          { name = "Lobato", isLocalPlayer = true, totalAmount = 12000, amountPerSecond = 400, classFilename = "WARRIOR" } },
  [2] = { { name = "Lobato", isLocalPlayer = true, totalAmount = 3000, amountPerSecond = 100, classFilename = "WARRIOR" } },
}
local golpes = {
  { spellID = 133, totalAmount = 900, amountPerSecond = 30, creatureName = "Mago Defias" },
  { spellID = 0, totalAmount = 1500, amountPerSecond = 50, creatureName = "Bandido Defias" },
}
local pidioGolpes
C_DamageMeter = {
  IsDamageMeterAvailable = function() return true, "" end,
  GetCombatSessionFromType = function(sesion, tipo)
    local f = medidor[tipo] or {}
    return { combatSources = f, maxAmount = 1, totalAmount = 1, durationSeconds = 30 }
  end,
  GetCombatSessionFromID = function() return { combatSources = {} } end,
  GetAvailableCombatSessions = function() return {} end,
  GetSessionDurationSeconds = function() return 30 end,
  GetCombatSessionSourceFromType = function(sesion, tipo, guid)
    pidioGolpes = { sesion = sesion, tipo = tipo, guid = guid }
    return { combatSpells = golpes, maxAmount = 1500, totalAmount = 2400 }
  end,
}

-- Lo que Lya aprende al entrar.
local ensenado = {}
if type(AlfaLya) == "table" and type(AlfaLya.Ensenar) == "function" then
  local orig = AlfaLya.Ensenar
  AlfaLya.Ensenar = function(p) if type(p) == "table" and p.id then ensenado[p.id] = p end return orig(p) end
end

-- Nadie registra el registro de combate (restringido en Forever).
local registroCombate = 0
do
  local probe = CreateFrame("Frame")
  local mt = getmetatable(probe)
  local idx = mt and mt.__index
  if type(idx) == "table" and idx.RegisterEvent then
    local re = idx.RegisterEvent
    idx.RegisterEvent = function(self, ev, ...)
      if ev == "COMBAT_LOG_EVENT_UNFILTERED" or ev == "COMBAT_LOG_EVENT" then registroCombate = registroCombate + 1 end
      return re(self, ev, ...)
    end
  end
end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(8)
local A, N = Alfa, AlfaNucleo
local K = N.Kit
local M = NS_OF("Alfa_Combate")
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local sonidos = 0
local tocar = A.PlaySound
A.PlaySound = function(...) sonidos = sonidos + 1 if tocar then return tocar(...) end end

local function texto(fs) return fs and fs.GetText and tostring(fs:GetText() or "") or "" end
local function visible(f) return f and f:IsShown() and true or false end
-- Ningún marco (ni sus hijos) toma el ratón mientras no se mueven.
local function sinRaton(f, donde)
  local function rec(x, ruta)
    if x.IsMouseEnabled and x:IsMouseEnabled() and x:IsShown() then
      check(false, donde .. ": un marco toma el ratón (" .. ruta .. ")")
      return
    end
    for _, c in ipairs({ x:GetChildren() }) do rec(c, ruta .. ">" .. tostring(c:GetObjectType())) end
  end
  rec(f, donde)
end
local function entrar() combate = true FIRE_EVENT("PLAYER_REGEN_DISABLED") end
local function salir() combate = false FIRE_EVENT("PLAYER_REGEN_ENABLED") end

---------------------------------------------------------------------------
-- 0. Cargado y prendido
---------------------------------------------------------------------------
step("Los archivos nuevos están cargados y sus ajustes, prendidos", function()
  check(type(M.Corte) == "table" and M.Corte.Revisar and M.Corte.Probar, "falta Corte.lua")
  check(type(M.Amenaza) == "table" and M.Amenaza.Ver and M.Amenaza.Leer, "falta Amenaza.lua")
  check(type(M.Resumen) == "table" and M.Resumen.Termina and M.Resumen.VerDeNuevo, "falta Resumen.lua")
  check(type(M.Recargas) == "table" and M.Recargas.Falta and M.Recargas.Conocidas, "falta Recargas.lua")
  for _, k in ipairs({ "corte", "corteFoco", "corteSonido", "amenaza", "amenazaSonido", "resumen", "recargas", "teclaGrande" }) do
    check(A.Get("combate." .. k) == true, "combate." .. k .. " no viene prendido")
  end
  check(A.Get("combate.tam") == 52, "el ícono no viene más grande (combate.tam = " .. tostring(A.Get("combate.tam")) .. ")")
  check(A.Get("combate.amenazaPapel") == "auto", "combate.amenazaPapel no viene en automático")
  check(A.Get("combate.recargasMin") == 30, "combate.recargasMin no viene en 30")
  check(type(AlfaCombate.UltimaPelea) == "function" and type(AlfaCombate.Recargas) == "function", "faltan AlfaCombate.UltimaPelea / Recargas")
  for _, id in ipairs({ "combate.corte", "combate.amenaza", "combate.resumen", "combate.recargas" }) do
    check(ensenado[id] and ensenado[id].pregunta and ensenado[id].respuesta, "Lya no enseña " .. id)
  end
  check(registroCombate == 0, "algo registró el registro de combate (restringido en Forever)")
end)

---------------------------------------------------------------------------
-- 6. Cortar
---------------------------------------------------------------------------
step("Cortar: tu objetivo lanza algo que se puede cortar", function()
  local Co = M.Corte
  check(Co.Habilidad() == 6552, "el corte del guerrero no es Patada: " .. tostring(Co.Habilidad()))
  check(M.Rotacion.Tecla(6552) == "F", "la tecla de Patada no es F: " .. tostring(M.Rotacion.Tecla(6552)))
  unidades.target = true
  lanza.target = { nombre = "Descarga de las Sombras", inmune = false }
  local antes = sonidos
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  local f = _G.AlfaCombateCorte
  check(visible(f), "no salió el aviso para cortar")
  if not f then return end
  check(texto(f.Titulo) == "¡Córtalo!", "el título no es «¡Córtalo!»: " .. texto(f.Titulo))
  check(texto(f.Linea):find("pulsa F", 1, true), "no dice la tecla: " .. texto(f.Linea))
  check(f.Tecla:IsShown() and texto(f.Tecla.Texto) == "F", "la tecla no sale sobre el ícono")
  check(sonidos == antes + 1, "no sonó una vez")
  sinRaton(f, "aviso para cortar")
  -- El mismo lanzamiento no vuelve a sonar.
  FIRE_EVENT("UNIT_SPELLCAST_INTERRUPTIBLE", "target")
  check(sonidos == antes + 1, "el mismo lanzamiento sonó dos veces")
  -- En recarga: cuánto le falta.
  recarga(6552, 10, NOW - 2)
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  check(texto(f.Linea):find("vuelve en 8 s", 1, true), "no dice cuánto le falta a Patada: " .. texto(f.Linea))
  cds[6552] = nil
  -- Lejos.
  enRango = false
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  check(texto(f.Linea):find("Acércate", 1, true), "lejos no dice que te acerques: " .. texto(f.Linea))
  enRango = true
  -- Termina: se va.
  lanza.target = nil
  FIRE_EVENT("UNIT_SPELLCAST_STOP", "target")
  check(not visible(f), "el aviso no se fue al terminar el lanzamiento")
end)

step("Cortar: lo que no se puede cortar y los oficios no avisan; el foco sí", function()
  local f = _G.AlfaCombateCorte
  lanza.target = { nombre = "Escudo", inmune = true }
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  check(not visible(f), "avisó de algo que no se puede cortar")
  lanza.target = { nombre = "Cocinar", inmune = false, oficio = true }
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  check(not visible(f), "avisó de un oficio")
  lanza.target = nil
  unidades.focus = true
  lanza.focus = { nombre = "Sanación", inmune = false, canal = true }
  FIRE_EVENT("UNIT_SPELLCAST_CHANNEL_START", "focus")
  check(visible(f) and texto(f.Titulo) == "¡Córtale a tu foco!", "el foco que canaliza no avisó: " .. texto(f.Titulo))
  A.Set("combate.corteFoco", false)
  FIRE_EVENT("UNIT_SPELLCAST_CHANNEL_START", "focus")
  check(not visible(f), "con corteFoco apagado avisó del foco")
  A.Set("combate.corteFoco", true)
  A.Set("combate.corte", false)
  FIRE_EVENT("UNIT_SPELLCAST_CHANNEL_START", "focus")
  check(not visible(f), "con corte apagado salió el aviso")
  A.Set("combate.corte", true)
  lanza.focus, unidades.focus = nil, nil
  FIRE_EVENT("UNIT_SPELLCAST_CHANNEL_STOP", "focus")
  check(not visible(f), "el aviso del foco no se fue")
end)

step("Cortar: en mazmorras (secretos) no se compara y el juego decide si se ve", function()
  local f = _G.AlfaCombateCorte
  local pedido
  f.Cuerpo.SetAlphaFromBoolean = function(self, b, si, no) pedido = { b = b, si = si, no = no } end
  lanza.target = { nombre = SECRETO, inmune = SECRETO, fin = SECRETO, tex = SECRETO }
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  check(visible(f), "con datos secretos no salió el aviso")
  check(texto(f.Titulo) == "¡Está lanzando!", "con secretos el título no es «¡Está lanzando!»: " .. texto(f.Titulo))
  check(pedido and rawequal(pedido.b, SECRETO) and pedido.si == 0 and pedido.no == 1, "no le pasó el secreto a SetAlphaFromBoolean")
  -- Sin fin legible, se va solo a los pocos segundos.
  T(14)
  check(not visible(f), "sin fin legible el aviso se quedó para siempre")
  lanza.target = nil
  f.Cuerpo.SetAlphaFromBoolean = nil
  -- Probar el aviso (la página).
  M.Corte.Probar()
  check(visible(f), "Probar no mostró el aviso")
  T(2)
  check(not visible(f), "el aviso de prueba no se fue")
end)

---------------------------------------------------------------------------
-- 7. Amenaza
---------------------------------------------------------------------------
step("Amenaza: en grupo avisa antes de quitárselo al tanque", function()
  local Am = M.Amenaza
  unidades.target = true
  grupo = true
  entrar()
  amenaza = { false, 0, 50 }
  Am.Ver()
  local f = _G.AlfaCombateAmenaza
  check(visible(f), "en grupo y en combate no salió la barra de amenaza")
  if not f then return end
  check(texto(f.Valor) == "50 %", "la barra no dice 50 %: " .. texto(f.Valor))
  check(texto(f.Aviso) == "", "con 50 % ya avisó: " .. texto(f.Aviso))
  amenaza = { false, 0, 85 }
  FIRE_EVENT("UNIT_THREAT_LIST_UPDATE", "target")
  T(1)
  check(texto(f.Aviso):find("tanque", 1, true), "con 85 % no avisó que casi se lo quitas al tanque: " .. texto(f.Aviso))
  local antes = sonidos
  amenaza = { true, 3, 100 }
  Am.Ver()
  check(texto(f.Aviso):find("atacando a ti", 1, true), "cuando ya te ataca no lo dijo: " .. texto(f.Aviso))
  check(sonidos == antes + 1, "no sonó al pasar a peligro")
  Am.Ver()
  check(sonidos == antes + 1, "volvió a sonar sin cambiar")
  sinRaton(f, "barra de amenaza")
end)

step("Amenaza: como tanque avisa al estar por perderlo y al perderlo", function()
  local Am, f = M.Amenaza, _G.AlfaCombateAmenaza
  A.Set("combate.amenazaPapel", "tanque")
  amenaza = { true, 3, 100 }
  Am.Ver()
  check(texto(f.Aviso) == "", "tanque seguro y avisó: " .. texto(f.Aviso))
  amenaza = { true, 2, 100 }
  Am.Ver()
  check(texto(f.Aviso):find("quitártelo", 1, true), "no avisó que están por quitártelo: " .. texto(f.Aviso))
  amenaza = { false, 0, 70 }
  Am.Ver()
  check(texto(f.Aviso):find("Perdiste", 1, true), "no avisó que lo perdiste: " .. texto(f.Aviso))
  -- Automático: la actitud defensiva cuenta como tanque.
  A.Set("combate.amenazaPapel", "auto")
  GetShapeshiftFormID = function() return 18 end
  check(Am.Papel() == "tanque", "en actitud defensiva no se tomó como tanque")
  GetShapeshiftFormID = function() return nil end
  check(Am.Papel() == "dano", "sin actitud defensiva se tomó como tanque")
  -- Secretos: sin errores y sin aviso.
  amenaza = { SECRETO, SECRETO, SECRETO }
  Am.Ver()
  check(visible(f) and texto(f.Aviso) == "" and texto(f.Valor) == "", "con secretos la barra comparó o avisó")
  -- Sola y sin mascota no importa.
  grupo = false
  amenaza = { false, 0, 50 }
  Am.Ver()
  check(not visible(f), "sin grupo ni mascota salió la barra")
  grupo = true
  salir()
  Am.Ver()
  check(not visible(f), "fuera de combate siguió la barra")
end)

---------------------------------------------------------------------------
-- 8. El ícono de rotación, más grande y con la tecla grande
---------------------------------------------------------------------------
step("Rotación: el ícono crece, con la tecla grande abajo y en las que siguen", function()
  A.Set("combate.tam", 80)
  A.Set("combate.despues", 2)
  unidades.target = true
  entrar()
  M.Rotacion.Ver()
  local f = _G.AlfaCombateRotacion
  check(visible(f), "el ícono de rotación no salió en combate")
  if not f then return end
  local w = f.Principal:GetWidth()
  check(w == 80, "el ícono principal no mide 80: " .. tostring(w))
  local s1 = f.Siguientes[1]
  check(s1:GetWidth() == 56, "las que siguen no miden el 70 %: " .. tostring(s1:GetWidth()))
  check(f.Tecla.alfaRol == "cifra", "la tecla de un ícono de 80 no es grande: " .. tostring(f.Tecla.alfaRol))
  local p = f.Tecla:GetPoint(1)
  check(p == "BOTTOM", "la tecla grande no va abajo al centro: " .. tostring(p))
  if f.Tecla:IsShown() then
    check(texto(f.Tecla.Texto) ~= "", "la tecla sale vacía")
  end
  -- Las que siguen también llevan su tecla (si están en tu barra).
  local alguna = false
  for _, s in ipairs(f.Siguientes) do
    if s:IsShown() and s.Tecla:IsShown() then alguna = true end
  end
  local hay = 0
  for _, s in ipairs(f.Siguientes) do if s:IsShown() then hay = hay + 1 end end
  if hay > 0 then check(alguna, "ninguna de las que siguen lleva su tecla") end
  A.Set("combate.tamDespues", 1)
  M.Rotacion.Ver()
  check(f.Siguientes[1]:GetWidth() == 80, "tamDespues al 100 % no hizo las que siguen del mismo tamaño")
  A.Set("combate.teclaGrande", false)
  M.Rotacion.Ver()
  check(f.Tecla.alfaRol == "insignia" and f.Tecla:GetPoint(1) == "TOPRIGHT", "sin tecla grande no volvió a la esquina")
  A.Set("combate.teclaGrande", true)
  A.Set("combate.tamDespues", 0.7)
  A.Set("combate.tam", 52)
  M.Rotacion.Ver()
  check(f.Tecla.alfaRol == "numero", "con 52 la tecla no usa la letra de número: " .. tostring(f.Tecla.alfaRol))
  salir()
  unidades.target = nil
  M.Rotacion.Ver()
end)

---------------------------------------------------------------------------
-- 9. El resumen de la pelea
---------------------------------------------------------------------------
step("Resumen: al terminar, tu daño, tu curación y lo que más te pegó", function()
  local Rs = M.Resumen
  entrar()
  NOW = NOW + 30
  salir()
  T(1)
  local f = _G.AlfaCombateResumen
  check(visible(f), "no salió el resumen de la pelea")
  if not f then return end
  check(pidioGolpes and pidioGolpes.tipo == 7 and pidioGolpes.guid == UnitGUID("player"), "no pidió el daño recibido con tu GUID")
  local dano = texto(f.Dano.Valor)
  check(dano:find("12", 1, true) and dano:find("400", 1, true), "tu daño no salió (solo tu fila): " .. dano)
  check(not dano:find("20", 1, true), "contó el daño de otro")
  check(texto(f.Cura.Valor):find("100", 1, true), "tu curación no salió: " .. texto(f.Cura.Valor))
  check(texto(f.Golpe):find("Golpes cuerpo a cuerpo", 1, true) and texto(f.Golpe):find("Bandido Defias", 1, true),
    "no dijo lo que más te pegó: " .. texto(f.Golpe))
  check(texto(f.Dura) == "0:30", "la duración no es 0:30: " .. texto(f.Dura))
  local u = Rs.Ultima()
  check(u and u.dano == 12000 and u.golpe and u.golpe.quien == "Bandido Defias", "la última pelea no quedó guardada")
  check(AlfaCombate.UltimaPelea() == u, "AlfaCombate.UltimaPelea no da la última")
  -- Otra pelea empieza: se esconde al momento (nada que atrape clics en combate).
  entrar()
  check(not visible(f), "el resumen siguió a la vista al empezar otra pelea")
  -- Una pelea corta no deja resumen.
  NOW = NOW + 3
  salir()
  T(1)
  check(not visible(f), "una pelea de 3 s dejó resumen")
  -- Ver de nuevo.
  check(Rs.VerDeNuevo() == true and visible(f), "Ver de nuevo no mostró la última")
  f:Hide()
end)

step("Resumen: nombres secretos no se leen y apagado no sale", function()
  local Rs, f = M.Resumen, _G.AlfaCombateResumen
  golpes = { { spellID = 133, totalAmount = 900, creatureName = SECRETO } }
  entrar()
  NOW = NOW + 20
  salir()
  T(1)
  check(visible(f), "no salió el resumen con un nombre secreto")
  check(texto(f.Golpe):find("Bola de Fuego", 1, true) and not texto(f.Golpe):find(", de ", 1, true), "leyó un nombre secreto: " .. texto(f.Golpe))
  f:Hide()
  T(3)
  A.Set("combate.resumen", false)
  entrar()
  NOW = NOW + 20
  salir()
  T(1)
  check(not visible(f), "con resumen apagado salió la tarjeta")
  A.Set("combate.resumen", true)
end)

---------------------------------------------------------------------------
-- 10. Recargas largas
---------------------------------------------------------------------------
step("Recargas: Temeridad entra a la barra con su tiempo y se puede ocultar", function()
  local Rg = M.Recargas
  recarga(1719, 1800)
  FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 1719)
  T(1)
  local f = _G.AlfaCombateRecargas
  check(visible(f), "Temeridad no entró a la barra de recargas")
  if not f then return end
  local b = f.cuadros[1]
  check(b and b:IsShown() and texto(b.Texto):find(":", 1, true), "el tiempo de Temeridad no sale en minutos: " .. (b and texto(b.Texto) or "?"))
  sinRaton(f, "barra de recargas")
  local lista = Rg.Conocidas()
  check(#lista == 1 and lista[1].nombre == "Temeridad", "la lista de recargas largas no tiene a Temeridad")
  check(#AlfaCombate.Recargas() == 1, "AlfaCombate.Recargas no da la que corre")
  -- Una recarga corta (Cargar, 15 s) no entra.
  conocidos[11578] = true
  recarga(11578, 15)
  FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 11578)
  T(1)
  check(#Rg.Activas() == 1, "una recarga de 15 s entró a la barra")
  -- Ocultarla desde la lista.
  Rg.Ocultar("Temeridad", true)
  check(not visible(f), "oculta, Temeridad siguió en la barra")
  check(Rg.Conocidas()[1].oculta == true, "la lista no la marca oculta")
  Rg.Ocultar("Temeridad", false)
  FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", 1719)
  T(1)
  check(visible(f), "al volver a mostrarla no regresó")
  -- Vuelve a estar lista: se va.
  cds[1719] = nil
  T(2)
  check(not visible(f), "lista otra vez, Temeridad siguió en la barra")
end)

step("Recargas: con tiempos secretos se estima con lo que ya se vio; con 60 s mínimo no entra una de 60", function()
  local Rg, f = M.Recargas, _G.AlfaCombateRecargas
  -- Ira sangrienta: primero legible (se aprende que dura 60 s).
  recarga(2687, 60)
  FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-5", 2687)
  T(1)
  check(visible(f), "Ira sangrienta (60 s) no entró")
  cds[2687] = nil
  T(2)
  -- Ahora secreta (en una mazmorra).
  cds[2687] = { startTime = SECRETO, duration = SECRETO, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
  FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-6", 2687)
  T(1)
  check(visible(f), "con tiempos secretos Ira sangrienta no entró")
  local a = Rg.Activas()[1]
  check(a and a.falta > 50 and a.falta <= 60, "no estimó lo que falta con los 60 s vistos: " .. tostring(a and a.falta))
  cds[2687] = nil
  T(2)
  A.Set("combate.recargasMin", 120)
  recarga(2687, 60)
  FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-7", 2687)
  T(1)
  check(not visible(f), "con mínimo de 120 s entró una de 60")
  A.Set("combate.recargasMin", 30)
  cds[2687] = nil
  T(2)
end)

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
step("La página de Combate abre con sus ayudas nuevas y sin errores", function()
  local ok, e = pcall(function()
    A.Fire("SHOW_OPTIONS", "combate")
    RUN_TIMERS(2)
  end)
  check(ok, "la página falló: " .. tostring(e))
  local ui = M.ui
  check(ui and ui.recargas, "la página no tiene el bloque de recargas largas")
  if ui and ui.recargas then check(ui.recargas:IsShown(), "el bloque de recargas largas no sale con Temeridad aprendida") end
  -- Comandos.
  A.RunCommand("combate corte")
  check(visible(_G.AlfaCombateCorte), "/alfa combate corte no mostró el aviso")
  A.RunCommand("combate pelea")
  check(visible(_G.AlfaCombateResumen), "/alfa combate pelea no mostró la última pelea")
  -- Mover: los marcos nuevos se ven y luego se fijan.
  M.Desbloquear(true)
  for _, n in ipairs({ "Corte", "Amenaza", "Recargas", "Resumen" }) do
    check(visible(_G["AlfaCombate" .. n]), "al mover no se ve el marco " .. n)
  end
  M.Desbloquear(false)
  check(not visible(_G.AlfaCombateAmenaza) and not visible(_G.AlfaCombateRecargas), "al fijar siguieron a la vista la amenaza o las recargas")
end)

print(string.format("PRUEBA: 1.3.0 Combate, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
