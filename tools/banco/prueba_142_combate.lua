-- Prueba de la 1.4.2: combate, curación y mazmorras (10 mejoras).
--
-- Lo que se revisa (cada una falla con el código de la 1.4.1):
--   1. «¿Qué me tumbó?»: al caer, el golpe final, lo que más pegó y cuánto se
--      podía evitar; con el medidor secreto no lee nada y lo intenta después.
--   2. El medidor trae daño recibido, daño evitable, cortes y limpiezas.
--   3. «Faltan por revivir»: botón seguro por cada caído (y nada si tú caíste).
--   4. Los intentos contra cada jefe: el aviso al caer y al vencer.
--   5. La tarjeta de tu pelea dice cuántos hechizos cortaste, cuántos
--      perjuicios quitaste y el daño evitable que recibiste.
--   6. La rueda del ratón sobre el medidor cambia lo que mide (y en combate
--      suelta la rueda: la cámara es tuya).
--   7. La tarjeta de tu pelea no se va mientras la lees.
--   8. La tarjeta de tu pelea dice cómo te fue contra la anterior.
--   9. /alfa combate con una palabra que no existe dice cuáles hay.
--  10. La tarjeta del jefe en vivo dice en qué intento van.
PRUEBA_AREA("1.4.2 combate")

-- Combate, grupo e instancia, a mano.
local combate, grupo, instancia = false, false, false
InCombatLockdown = function() return combate end
UnitAffectingCombat = function() return combate end
IsInGroup = function() return grupo end
IsInRaid = function() return false end
IsInInstance = function() return instancia, instancia and "party" or "none" end

-- El medidor del juego, con lo que se le pide.
Enum.DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6,
  DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 }
Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }
local porTipo = {}      -- tipo -> fuentes
local hechizosDe = {}   -- tipo -> combatSpells de tu fila
local secretos = false  -- el juego da todo secreto
local function fila(nombre, yo, total, ps)
  return { name = nombre, isLocalPlayer = yo, totalAmount = total, amountPerSecond = ps, classFilename = "PRIEST", sourceGUID = "Player-1-" .. nombre }
end
porTipo[0] = { fila("Lobato", true, 12000, 400), fila("Lobo2", false, 8000, 260) }
porTipo[1] = porTipo[0]
porTipo[2] = { fila("Lobato", true, 3000, 100) }
porTipo[5] = { fila("Lobato", true, 4, 0.1), fila("Lobo2", false, 1, 0) }
porTipo[6] = { fila("Lobato", true, 2, 0.05) }
porTipo[7] = { fila("Lobato", true, 9000, 300), fila("Lobo2", false, 2000, 60) }
porTipo[8] = { fila("Lobato", true, 1500, 50) }
hechizosDe[7] = {
  { spellID = 0, totalAmount = 4000, creatureName = "Ogro Sangrante", overkillAmount = 0, isAvoidable = false, isDeadly = false },
  { spellID = 133, totalAmount = 3000, creatureName = "Mago Defias", overkillAmount = 800, isAvoidable = false, isDeadly = true },
  { spellID = 2120, totalAmount = 2000, creatureName = "Mago Defias", overkillAmount = 0, isAvoidable = true, isDeadly = false },
}
C_DamageMeter = {
  IsDamageMeterAvailable = function() return true, "" end,
  GetCombatSessionFromType = function(_, tipo)
    if secretos then return SECRETO({}) end
    local f = porTipo[tipo] or {}
    local tot, mx = 0, 0
    for _, x in ipairs(f) do tot = tot + x.totalAmount if x.totalAmount > mx then mx = x.totalAmount end end
    return { combatSources = f, maxAmount = mx, totalAmount = tot }
  end,
  GetCombatSessionFromID = function() return { combatSources = {} } end,
  GetCombatSessionSourceFromType = function(_, tipo)
    if secretos then return SECRETO({}) end
    return { combatSpells = hechizosDe[tipo] or {} }
  end,
  GetAvailableCombatSessions = function() return {} end,
  GetSessionDurationSeconds = function() return 40 end,
}
GetCVar = function(n) if n == "damageMeterEnabled" then return "1" end return "0" end
local nombres = { [133] = "Bola de fuego", [2120] = "Fogonazo", [2006] = "Resurrección" }
C_Spell = C_Spell or {}
C_Spell.GetSpellName = function(id) return nombres[id] end

PRUEBA_ENTRAR()
local A, N = Alfa, AlfaNucleo
local K = N.Kit
local M = NS_OF("Alfa_Combate")
local Cu = NS_OF("Alfa_Curacion")
local Mz = NS_OF("Alfa_Mazmorras")

-- Los avisos que se piden (Lya puede decirlos: aquí se mira lo que se pidió).
local avisos = {}
local avisoBase = K.Aviso
K.Aviso = function(o) avisos[#avisos + 1] = o return avisoBase(o) end
local function ultimoAviso(id)
  for i = #avisos, 1, -1 do if avisos[i].id == id then return avisos[i] end end
  return nil
end
local function pelea(seg)
  combate = true
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  TIEMPO_CORTO(seg or 1)
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
end

PASO("1. al caer: el golpe final, lo que más pegó y lo que se podía evitar", function()
  REVISA(M.Caida ~= nil, "no hay «¿Qué me tumbó?» (M.Caida)")
  if not M.Caida then return end
  avisos = {}
  pelea(3)
  FIRE_EVENT("PLAYER_DEAD")
  RUN_TIMERS(5)
  local u = M.Caida.Ultima()
  REVISA(u ~= nil, "no se guardó la caída")
  if not u then return end
  REVISA(u.final and u.final.nombre == "Bola de fuego" and u.final.quien == "Mago Defias", "el golpe final no es la Bola de fuego del Mago Defias: " .. tostring(u.final and u.final.nombre))
  REVISA(#u.golpes == 3 and u.golpes[1].nombre == "Golpes cuerpo a cuerpo" and u.golpes[1].quien == "Ogro Sangrante", "los golpes no van de mayor a menor")
  REVISA(u.evitable == 2000 and u.total == 9000, "el daño evitable no se sumó bien: " .. tostring(u.evitable))
  local a = ultimoAviso("combate.caida")
  REVISA(a ~= nil, "no salió el aviso al caer")
  if a then
    REVISA(a.texto:find("Mago Defias", 1, true) and a.texto:find("22 %%", 1, false), "el aviso no dice quién ni el 22 % evitable: " .. tostring(a.texto))
    REVISA(a.donde ~= nil, "el aviso no dice dónde verlo otra vez")
  end
end)

PASO("1b. con el medidor secreto no se lee nada (y se intenta luego)", function()
  if not M.Caida then return end
  N.DatosPersonaje(M.ID).ultimaCaida = nil
  secretos = true
  FIRE_EVENT("PLAYER_DEAD")
  RUN_TIMERS(2)
  REVISA(M.Caida.Ultima() == nil, "guardó algo de un medidor secreto")
  secretos = false
  RUN_TIMERS(10)
  REVISA(M.Caida.Ultima() ~= nil, "no lo volvió a intentar cuando el medidor ya se podía leer")
  -- A pedido (menú, comando): sale aunque el ajuste esté apagado.
  M.SetOpt("caida", false)
  avisos = {}
  M.Comando("caida")
  REVISA(ultimoAviso("combate.caida") ~= nil, "/alfa combate caida no lo mostró")
  M.SetOpt("caida", true)
  local hay = false
  for _, o in ipairs(M.Ventana.Opciones()) do if o.valor == "caida" and not o.apagada then hay = true end end
  REVISA(hay, "el menú del medidor no ofrece «Ver lo que me tumbó»")
end)

PASO("2. el medidor trae daño recibido, evitable, cortes y limpiezas", function()
  local D = M.Medidor
  for _, c in ipairs({ "recibido", "evitable", "cortes", "limpiezas" }) do
    REVISA(D.Tipo(c).clave == c, "el medidor no tiene el tipo " .. c)
  end
  local r = D.Leer("actual", "cortes", 5)
  REVISA(r.ok and #r.filas == 2 and r.filas[1].valor == 4, "los cortes no se leen del medidor del juego")
  grupo = true
  M.SetOpt("medidorModo", "siempre")
  M.SetOpt("tipo", "cortes")
  RUN_TIMERS(2)
  M.Ventana.Pintar(true)
  local v = rawget(_G, "AlfaCombateMedidor")
  REVISA(v and v:IsShown(), "el medidor no salió")
  if v and v.filas[1] then
    REVISA(v.filas[1].Valor:GetText() ~= nil and v.filas[1].Valor:GetText() ~= "", "la fila de cortes no dice cuántos")
  end
  local t = M.Ventana.Opciones()
  local tiene = false
  for _, o in ipairs(t) do if o.valor == "tipo:evitable" then tiene = true end end
  REVISA(tiene, "el clic derecho del medidor no ofrece «Daño evitable»")
end)

PASO("6. la rueda sobre el medidor cambia lo que mide; en combate la suelta", function()
  local v = rawget(_G, "AlfaCombateMedidor")
  if not v then REVISA(false, "no hay medidor") return end
  M.SetOpt("tipo", "dps")
  local s = v:GetScript("OnMouseWheel")
  REVISA(s ~= nil, "el medidor no escucha la rueda")
  if s then s(v, -1) end
  REVISA(M.Opt("tipo") == "dano", "la rueda hacia abajo no pasó de DPS a Daño: " .. tostring(M.Opt("tipo")))
  if s then s(v, 1) s(v, 1) end
  REVISA(M.Opt("tipo") == "limpiezas", "la rueda hacia arriba no dio la vuelta: " .. tostring(M.Opt("tipo")))
  REVISA(v:IsMouseWheelEnabled(), "fuera de combate la rueda no responde")
  combate = true
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  REVISA(not v:IsMouseWheelEnabled(), "en combate el medidor se queda con la rueda (la cámara no haría zoom)")
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  RUN_TIMERS(2)
  M.SetOpt("tipo", "dps")
end)

PASO("5 y 8. la tarjeta de tu pelea: cortes, limpiezas, daño evitable y contra la anterior", function()
  local Rs = M.Resumen
  local r = Rs.Leer(40)
  REVISA(r.cortes == 4 and r.limpiezas == 2 and r.evitable == 1500, "no lee tus cortes, limpiezas o daño evitable: "
    .. tostring(r.cortes) .. " " .. tostring(r.limpiezas) .. " " .. tostring(r.evitable))
  local d = N.DatosPersonaje(M.ID)
  d.peleas = { { dps = 200, dur = 40 } }
  M.SetOpt("resumen", true)
  M.SetOpt("resumenMinSolo", 0)
  M.SetOpt("resumenMin", 0)
  pelea(3)
  RUN_TIMERS(3)
  local u = Rs.Ultima()
  REVISA(u and u.cortes == 4, "la última pelea no guardó los cortes")
  REVISA(u and type(u.dif) == "number" and u.dif > 0.9, "la última pelea no sabe cómo te fue contra la anterior: " .. tostring(u and u.dif))
  -- (RUN_TIMERS corre también el reloj que la esconde a los 12 s: se pinta otra vez.)
  REVISA(rawget(_G, "AlfaCombateResumen") ~= nil, "la tarjeta no salió")
  if u then Rs.Pintar(u) end
  local f = rawget(_G, "AlfaCombateResumen")
  REVISA(f and f:IsShown(), "la tarjeta no se pinta")
  if f then
    REVISA(f.Cortes and f.Cortes.Valor:IsShown() and tostring(f.Cortes.Valor:GetText()):find("4"), "la tarjeta no dice los cortes")
    REVISA(f.Evitable and f.Evitable.Valor:IsShown(), "la tarjeta no dice el daño evitable")
    REVISA(f.Dif and f.Dif.Valor:IsShown() and tostring(f.Dif.Valor:GetText()):find("+", 1, true), "la tarjeta no dice «+100 %» contra la anterior")
  end
end)

PASO("7. la tarjeta de tu pelea no se va mientras la lees", function()
  local f = rawget(_G, "AlfaCombateResumen")
  if not (f and f:IsShown()) then REVISA(false, "no hay tarjeta") return end
  f.IsMouseOver = function() return true end
  M.Resumen.Irse(f.alfaHasta)
  REVISA(f:IsShown(), "se fue con el ratón encima")
  f.IsMouseOver = function() return false end
  M.Resumen.Irse(f.alfaHasta)
  REVISA(not f:IsShown(), "no se fue al quitar el ratón")
  M.SetOpt("resumen", false)
end)

PASO("9. /alfa combate con algo que no existe dice cuáles hay", function()
  local dicho = {}
  local imprimir = N.Imprimir
  N.Imprimir = function(t) dicho[#dicho + 1] = tostring(t) end
  M.Comando("muerto123")
  N.Imprimir = imprimir
  local ok = false
  for _, t in ipairs(dicho) do if t:find("caida", 1, true) and t:find("medidor", 1, true) then ok = true end end
  REVISA(ok, "no dijo los comandos que hay: " .. table.concat(dicho, " | "))
  N.CerrarVentana()
end)

PASO("3. faltan por revivir: un botón seguro por cada caído", function()
  REVISA(Cu.Revivir ~= nil, "no hay «Faltan por revivir» (Curación)")
  if not Cu.Revivir then return end
  grupo = true
  local muertos = { party1 = true }
  local yoMuerto = false
  GetNumGroupMembers = function() return 3 end
  UnitExists = function(u) return u == "player" or u == "party1" or u == "party2" or u == "target" end
  UnitIsDeadOrGhost = function(u) if u == "player" then return yoMuerto end return muertos[u] == true end
  UnitIsConnected = function() return true end
  UnitIsGhost = function() return false end
  local nombre = UnitName
  UnitName = function(u) if u == "party1" then return "Colmillo" end if u == "party2" then return "Aullido" end return nombre(u) end
  local conocido = Cu.Conocido
  Cu.Conocido = function(k) if k == "resurreccion" then return 2006 end return nil end
  avisos = {}
  pelea(2)
  RUN_TIMERS(5)
  local a = ultimoAviso("curacion.revivir")
  REVISA(a ~= nil, "no avisó que Colmillo quedó caído")
  if a then
    local b = a.acciones and a.acciones[1]
    REVISA(b and b.seguro and b.seguro.type == "macro" and b.seguro.macrotext:find("@party1,dead,nocombat", 1, true)
      and b.seguro.macrotext:find("Resurrección", 1, true), "el botón no es seguro con /cast [@party1,dead,nocombat] Resurrección")
    REVISA(a.acciones[2] == nil, "ofreció revivir a quien está vivo")
    REVISA(a.titulo:find("Colmillo", 1, true), "el aviso no dice a quién: " .. tostring(a.titulo))
  end
  -- Tú caído: no puedes lanzar, no avisa.
  yoMuerto = true
  avisos = {}
  pelea(2)
  RUN_TIMERS(5)
  REVISA(ultimoAviso("curacion.revivir") == nil, "avisó estando tú caído")
  yoMuerto = false
  -- Apagado: nada.
  N.Set(Cu.ID, "revivir", false)
  avisos = {}
  pelea(2)
  RUN_TIMERS(5)
  REVISA(ultimoAviso("curacion.revivir") == nil, "avisó con el ajuste apagado")
  N.Set(Cu.ID, "revivir", true)
  muertos = {}
  Cu.Conocido = conocido
  UnitName = nombre
  GetNumGroupMembers = function() return 0 end
  grupo = false
end)

PASO("4 y 10. los intentos contra cada jefe", function()
  local Iv = Mz.Intentos
  REVISA(Iv ~= nil, "no hay intentos (Mazmorras)")
  if not Iv then return end
  local D = Mz.D
  local jefe = { id = "644", nombre = "Rhahk'Zor", encuentro = 1051,
    consejos = { { "Salgan del fuego que deja en el suelo.", "Get out of the fire.", rol = "dano" } } }
  local actual, jefes = D.MazmorraActual, D.Jefes
  D.MazmorraActual = function() return "deadmines" end
  D.Jefes = function(k) if k == "deadmines" then return { jefe } end return {} end
  instancia = true
  avisos = {}
  FIRE_EVENT("ENCOUNTER_END", 1051, "Rhahk'Zor", 1, 5, 0)
  RUN_TIMERS(2)
  local a = ultimoAviso("mazmorras.intentos")
  REVISA(a and a.titulo:find("Rhahk'Zor", 1, true), "no avisó que cayeron ante el jefe")
  REVISA(a and a.texto:find("fuego", 1, true), "el aviso no dice lo que más importa de la pelea: " .. tostring(a and a.texto))
  REVISA(a and a.acciones and a.acciones[1], "el aviso no trae «Ver sus consejos»")
  FIRE_EVENT("ENCOUNTER_END", 1051, "Rhahk'Zor", 1, 5, 0)
  RUN_TIMERS(2)
  REVISA(Iv.EnVuelta("deadmines", "644") == 2, "no lleva la cuenta: " .. tostring(Iv.EnVuelta("deadmines", "644")))
  -- 10: la tarjeta del jefe dice en qué intento van.
  local Ev = Mz.EnVivo
  REVISA(Ev.Intento("deadmines", jefe) == 3, "la tarjeta del jefe no sabe que van en el intento 3")
  Ev.Mostrar("deadmines", jefe)
  local tl = rawget(_G, "AlfaMazmorrasEnVivoLinea")
  REVISA(tl and tostring(tl.Texto:GetText()):find("3", 1, true), "la línea del jefe no dice «Intento 3»: " .. tostring(tl and tl.Texto:GetText()))
  Ev.Ocultar()
  -- Un fin secreto no cuenta.
  FIRE_EVENT("ENCOUNTER_END", 1051, "Rhahk'Zor", 1, 5, SECRETO(0))
  RUN_TIMERS(2)
  REVISA(Iv.EnVuelta("deadmines", "644") == 2, "contó un final secreto")
  avisos = {}
  FIRE_EVENT("ENCOUNTER_END", 1051, "Rhahk'Zor", 1, 5, 1)
  RUN_TIMERS(2)
  local v = ultimoAviso("mazmorras.intentos")
  REVISA(v and v.titulo:find("3", 1, true) and v.tono == "exito", "al vencer no dijo «al intento 3»: " .. tostring(v and v.titulo))
  REVISA(Iv.EnVuelta("deadmines", "644") == 0, "la cuenta no empezó de nuevo al vencerlo")
  local h = Iv.Historial("deadmines", "644")
  REVISA(h and h.victorias == 1 and h.caidas == 2, "el historial del jefe no se guardó")
  D.MazmorraActual, D.Jefes = actual, jefes
  instancia = false
end)

PASO("la página de Combate se arma con la caída", function()
  N.Abrir(M.ID)
  RUN_TIMERS(2)
  N.CerrarVentana()
end)

-- Siempre al final: nada de Alfa se queda tapando el ratón.
PASO("el ratón sigue siendo del jugador", function()
  local v = rawget(_G, "AlfaCombateMedidor")
  if v then v:Hide() end
  TIEMPO(5)
  RATON_LIMPIO("al final")
end)

K.Aviso = avisoBase
PRUEBA_FIN()
