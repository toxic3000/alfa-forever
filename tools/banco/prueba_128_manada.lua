-- Prueba de la 1.2.8, La Jauría (tools/prueba.py la corre con las demás prueba_*.lua):
--   * la cita de la manada: 1C por la hermandad, «Voy» (1D por susurro), quién va, el recordatorio, cancelar y caducar;
--   * ¿quién va?: una mazmorra de tu nivel en la zona y lobos de nivel parecido cerca, «Invitar», una vez por zona;
--   * raros con reloj: el raro cazado (historial del motor y 1T de la manada), «pudo volver ya», el cuadro y vivo otra vez;
--   * notas del lobo: la nota en tu lugar, su marca en el mapa (clic: flecha), compartir (1N) y borrar;
--   * la página con los bloques nuevos y los ajustes de fábrica.
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
local function check(cond, msg) if not cond then NOTE("1.2.8 manada", msg) end end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
-- La ventana de Alfa se arma (como en prueba_botones).
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local MN = NS_OF("Alfa_Manada")
local R, U = MN.Red, MN.U
local map = A.Compat.GetPlayerMapPosition()

-- El reloj del servidor, para mover el tiempo.
local RELOJ = 1700000000
local servidor = GetServerTime
GetServerTime = function() return RELOJ end

-- Lo que sale por la red y los avisos, mientras dura `fn` (con hermandad).
local salidos, avisos = {}, {}
local function conRed(fn)
  A.Set("manada.compartir", true)
  R.Escuchar()
  local via, envio, av, guild = R.Via, C_ChatInfo.SendAddonMessage, K.Aviso, IsInGuild
  R.Via = function() return "hermandad" end
  IsInGuild = function() return true end
  C_ChatInfo.SendAddonMessage = function(_, t, c, d) salidos[#salidos + 1] = { t, c, d } end
  K.Aviso = function(o) avisos[#avisos + 1] = o return true end
  local ok, e = pcall(fn)
  R.Via, C_ChatInfo.SendAddonMessage, K.Aviso, IsInGuild = via, envio, av, guild
  A.Set("manada.compartir", false)
  if not ok then error(e) end
end
local function vaciarCola() for _ = 1, 60 do FIRE(R.motor, "OnUpdate", 0.2) end end
local function llega(texto, quien, canal) FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", texto, canal or "GUILD", quien) end
local function salio(patron, canal)
  for _, m in ipairs(salidos) do if m[1]:find(patron) and (not canal or m[2] == canal) then return m[1] end end
  return nil
end
local function ultimo() return avisos[#avisos] end

step("Los ajustes de fábrica", function()
  for _, k in ipairs({ "citas", "quienVa", "rarosReloj", "notas" }) do
    check(A.Get("manada." .. k) == true, "manada." .. k .. " no viene prendido de fábrica")
  end
  check(A.Get("manada.notasCompartir") == false, "compartir las notas no viene apagado de fábrica")
end)

step("La cita de la manada", function()
  local Ci = MN.Cita
  check(Ci and Ci.Proponer and Ci.Responder and Ci.Lista, "falta Cita.lua")
  -- Sin hermandad, no sale (1.3.2: ya no pide compartir tu ubicación).
  local ok, por = Ci.Proponer("Minas de la Muerte", RELOJ + 3600)
  check(not ok and (por == "hermandad" or por == "compartir"), "propuso sin hermandad: " .. tostring(por))
  conRed(function()
    salidos, avisos = {}, {}
    check(select(2, Ci.Proponer("", RELOJ + 3600)) == "que", "propuso una cita sin qué")
    check(select(2, Ci.Proponer("Minas", RELOJ - 7200)) == "pasada", "propuso una cita que ya pasó")
    check(Ci.Proponer("Minas de la Muerte", RELOJ + 3600), "no propuso la cita")
    vaciarCola()
    local t = salio("^1C|%d+|" .. (RELOJ + 3600) .. "|Minas de la Muerte$", "GUILD")
    check(t, "la cita no salió por la hermandad (1C)")
    local id = t and t:match("^1C|(%d+)|")
    local mia
    for _, c in ipairs(Ci.Lista()) do if c.mia then mia = c end end
    check(mia and mia.que == "Minas de la Muerte", "tu cita no quedó en la lista")
    -- Ana dice que va; Beto que no.
    llega("1D|" .. tostring(id) .. "|s", "Ana Smith", "WHISPER")
    llega("1D|" .. tostring(id) .. "|n", "Beto Ruiz", "WHISPER")
    local si, no = Ci.Quienes(mia)
    check(#si == 1 and si[1] == "Ana Smith" and #no == 1 and no[1] == "Beto Ruiz", "no anotó quién va y quién no")
    -- Una respuesta por la hermandad (no por susurro): nada.
    llega("1D|" .. tostring(id) .. "|s", "Caro Vega")
    check(#Ci.Quienes(mia) == 1, "aceptó una respuesta que no llegó por susurro")
    -- La cita de otro lobo: el aviso con «Voy».
    avisos = {}
    llega(("1C|7|%d|Vallefresno"):format(RELOJ + 1800), "Elsa Mora")
    local a = avisos[1]
    check(a and a.accion and a.accion.texto == "Voy" and a.texto:find("Vallefresno", 1, true), "la cita de otro no avisó con «Voy»")
    salidos = {}
    if a and a.accion then a.accion.alClic() end
    vaciarCola()
    check(salio("^1D|7|s$", "WHISPER"), "«Voy» no respondió por susurro (1D)")
    -- Otra vez la misma (se repite cada 10 min): sin aviso nuevo.
    llega(("1C|7|%d|Vallefresno"):format(RELOJ + 1800), "Elsa Mora")
    check(#avisos == 1, "la misma cita avisó dos veces")
    -- Por susurro no vale (solo la hermandad); basura tampoco.
    llega(("1C|8|%d|Otra"):format(RELOJ + 1800), "Fede Luna", "WHISPER")
    llega("1C|x|y|z", "Fede Luna")
    llega(("1C|9|%d|Lejos"):format(RELOJ + 30 * 86400), "Fede Luna")
    check(#Ci.Lista() == 2, "aceptó una cita por susurro, rota o muy lejana")
    -- El recordatorio, 15 min antes: la tuya y la de Elsa (dijiste «Voy»).
    avisos = {}
    RELOJ = RELOJ + 1000
    check(Ci.Recordar() == 1, "no recordó la cita de Elsa a 13 minutos")
    check(ultimo() and ultimo().titulo == "Tu cita con la manada", "el recordatorio no dice «Tu cita con la manada»")
    RELOJ = RELOJ + 1800
    check(Ci.Recordar() == 1, "no recordó tu cita")
    check(ultimo() and ultimo().texto:find("Ana Smith", 1, true), "tu recordatorio no dice quién va")
    check(Ci.Recordar() == 0, "recordó dos veces la misma cita")
    -- Elsa la cancela; la tuya se quita y sale cancelada.
    llega("1C|7|0|", "Elsa Mora")
    check(#Ci.Lista() == 1, "la cita cancelada siguió en la lista")
    salidos = {}
    check(Ci.Quitar(mia.llave), "no quitó tu cita")
    vaciarCola()
    check(salio("^1C|" .. tostring(id) .. "|0|$", "GUILD"), "tu cita quitada no salió cancelada")
    -- Una cita vieja se olvida sola.
    llega(("1C|11|%d|Bosque"):format(RELOJ + 600), "Elsa Mora")
    RELOJ = RELOJ + 3 * 3600
    check(#Ci.Lista() == 0, "una cita pasada no se olvidó")
  end)
  -- /alfa cita mañana 21:30 ...
  local que, cuando = Ci.Leer("mañana 21:30 Minas de la Muerte")
  local d = cuando and date("*t", cuando)
  check(que == "Minas de la Muerte" and d and d.hour == 21 and d.min == 30, "no leyó «mañana 21:30 Minas de la Muerte»")
  check(Ci.Leer("Minas sin hora") == nil, "leyó una cita sin hora")
  check(Ci.CuandoTexto(cuando):find("21:30", 1, true), "el texto de la hora no dice 21:30")
end)

step("¿Quién va?", function()
  local Qv = MN.QuienVa
  check(Qv and Qv.Revisar and Qv.Mazmorras, "falta QuienVa.lua")
  local zona = U.ZonaDe(map)
  local dg, nivel, invite, combate = A.Dungeons, UnitLevel, C_PartyInfo and C_PartyInfo.InviteUnit, InCombatLockdown
  A.Dungeons = { List = function() return {
    { name = "Las Minas de la Muerte", zone = zona, minLevel = 17, maxLevel = 26, kind = "dungeon" },
    { name = "Una banda", zone = zona, minLevel = 15, maxLevel = 30, kind = "raid" },
  } end }
  UnitLevel = function() return 20 end
  C_PartyInfo = C_PartyInfo or {}
  local invitados = {}
  C_PartyInfo.InviteUnit = function(n) invitados[#invitados + 1] = n end
  conRed(function()
    local mz = Qv.Mazmorras(zona, 20)
    check(#mz == 1 and mz[1].nombre == "Las Minas de la Muerte", "no halló la mazmorra de la zona (sin bandas)")
    check(#Qv.Mazmorras(zona, 40) == 0, "una mazmorra de otro nivel contó")
    Qv.Olvidar()
    check(select(2, Qv.Revisar()) == "nadie", "habló sin nadie de la manada cerca")
    llega(("1P|%d|41.00|41.00|21|MAGE"):format(map), "Gael Paz")
    llega(("1P|%d|42.00|42.00|45|ROGUE"):format(map), "Hugo Sol")
    avisos = {}
    InCombatLockdown = function() return true end
    check(select(2, Qv.Revisar()) == "combate", "habló en combate")
    InCombatLockdown = combate
    check(Qv.Revisar() == "Las Minas de la Muerte", "no dijo quién va a la mazmorra")
    local a = avisos[1]
    check(a and a.texto:find("Gael Paz", 1, true) and not a.texto:find("Hugo Sol", 1, true), "no dijo solo a los de nivel parecido")
    check(a and a.accion and a.accion.texto == "Invitar", "sin el botón «Invitar»")
    if a and a.accion then a.accion.alClic() end
    check(#invitados == 1, "«Invitar» no invitó con C_PartyInfo.InviteUnit")
    check(select(2, Qv.Revisar()) == "dicho", "habló dos veces en la misma zona")
    A.Set("manada.quienVa", false)
    Qv.Olvidar()
    check(select(2, Qv.Revisar()) == "apagado", "apagado, habló")
    A.Set("manada.quienVa", true)
  end)
  -- Nada en el chat: ningún mensaje de chat salió.
  A.Dungeons, UnitLevel, InCombatLockdown = dg, nivel, combate
  if invite then C_PartyInfo.InviteUnit = invite end
  Qv.Olvidar()
end)

step("Raros con reloj", function()
  local Rl = MN.Reloj
  check(Rl and Rl.Anotar and Rl.Texto, "falta Reloj.lua")
  Rl.Olvidar()
  local Ra = A.Rares
  local hist = Ra and Ra.History
  local h = { ["rare:61"] = { kind = "rare", id = 61, name = "Mor'Ladim", dead = RELOJ, t = RELOJ, map = map, x = 30, y = 40 } }
  if Ra then Ra.History = function() return h end end
  conRed(function()
    A.Set("manada.rarosManada", true)
    salidos = {}
    A.Fire("RARES_HISTORY", "rare:61")
    local x = Rl.De("Mor'Ladim")
    check(x and x.muerto == RELOJ, "no anotó cuándo lo cazaron")
    vaciarCola()
    check(salio("^1T|%d+|30%.00|40%.00|0|Mor'Ladim$"), "no compartió el raro cazado (1T)")
    local t, volver = Rl.Texto("Mor'Ladim")
    check(t and t:find("Lo cazaron", 1, true) and not volver, "recién cazado, dijo otra cosa")
    -- Su cuerpo visto otra vez al rato: la hora no cambia.
    RELOJ = RELOJ + 120
    h["rare:61"].dead, h["rare:61"].t = RELOJ, RELOJ
    A.Fire("RARES_HISTORY", "rare:61")
    check(Rl.De("Mor'Ladim").muerto == RELOJ - 120, "el cuerpo visto otra vez cambió la hora de la caza")
    -- Media hora después: «pudo volver ya» y el aviso, una vez.
    RELOJ = RELOJ + 1800
    t, volver = Rl.Texto("Mor'Ladim")
    check(volver == "pudo volver ya" and t:find("32 min", 1, true), "a la media hora no dijo «pudo volver ya»: " .. tostring(t))
    avisos = {}
    check(Rl.Revisar() == 1, "no avisó que pudo volver")
    local a = avisos[1]
    check(a and a.accion and a.accion.texto == "Ir de caza", "el aviso no trae «Ir de caza»")
    if a and a.accion then
      a.accion.alClic()
      local tgt = A.Nav and A.Nav.GetTarget and A.Nav.GetTarget()
      check(tgt and math.abs((tgt.x or 0) - 30) < 0.01, "«Ir de caza» no puso la flecha donde cayó")
      if A.Nav.ReleaseTarget then A.Nav.ReleaseTarget() end
    end
    check(Rl.Revisar() == 0, "avisó dos veces")
    -- En su cuadro.
    local g = { UnitExists = UnitExists, UnitIsPlayer = UnitIsPlayer, UnitClassification = UnitClassification, UnitName = UnitName }
    UnitExists = function() return true end
    UnitIsPlayer = function() return false end
    UnitClassification = function() return "rare" end
    UnitName = function(u) if u == "mouseover" then return "Mor'Ladim" end return g.UnitName(u) end
    local lineas = {}
    Rl.AlCuadro({ AddLine = function(_, l) lineas[#lineas + 1] = l end }, "mouseover")
    check(lineas[1] and lineas[1]:find("pudo volver ya", 1, true), "el cuadro del raro no dice cuándo lo cazaron")
    for k, v in pairs(g) do _G[k] = v end
    -- La manada cazó otro.
    llega(("1T|%d|50.00|50.00|120|Rak'shiri"):format(map), "Caro Vega")
    local y = Rl.De("Rak'shiri")
    check(y and y.por == "Caro Vega" and y.muerto == RELOJ - 120, "no anotó el raro que cazó la manada")
    llega("1T|abc|1|1|1|x", "Caro Vega")
    llega(("1T|%d|500|50|1|Malo"):format(map), "Caro Vega")
    check(Rl.De("Malo") == nil, "aceptó un 1T roto")
    -- Lo ven vivo otra vez: se olvida.
    RELOJ = RELOJ + 300
    h["rare:61"].t = RELOJ
    A.Fire("RARES_HISTORY", "rare:61")
    check(Rl.De("Mor'Ladim") == nil, "visto vivo, siguió como cazado")
    check(#Rl.Lista() == 1, "la lista de cazados no cuadra")
    A.Set("manada.rarosReloj", false)
    check(Rl.Texto("Rak'shiri") == nil, "apagado, siguió diciendo cuándo lo cazaron")
    A.Set("manada.rarosReloj", true)
  end)
  if Ra then Ra.History = hist end
end)

step("Notas del lobo", function()
  local No = MN.Notas
  check(No and No.Agregar and No.Lista, "falta Notas.lua")
  local P = A.Pins
  local capas = {}
  local setLayer = P and P.SetLayer
  if P then P.SetLayer = function(id, pins) capas[id] = pins end end
  check(select(2, No.Agregar("   ")) == "texto", "dejó una nota vacía")
  conRed(function()
    salidos = {}
    local n = No.Agregar("Aquí sale el mineral")
    check(n and n.map == map and not n.compartida, "no dejó la nota en tu lugar")
    vaciarCola()
    check(not salio("^1N|"), "compartió una nota con compartir apagado")
    if P then
      local pins = capas["manada.notas"] or {}
      check(#pins == 1 and type(pins[1].tooltip) == "function" and type(pins[1].onClick) == "function", "la nota no salió en el mapa")
      if pins[1] then
        local lineas = {}
        pins[1].tooltip({ SetText = function(_, t) lineas[#lineas + 1] = t end, AddLine = function(_, t) lineas[#lineas + 1] = t end })
        check(lineas[1] == "Aquí sale el mineral", "el cuadro de la nota no dice su texto")
        pins[1].onClick("LeftButton")
        local tgt = A.Nav and A.Nav.GetTarget and A.Nav.GetTarget()
        check(tgt and math.abs((tgt.x or 0) - n.x) < 0.01, "el clic en la nota no puso la flecha")
        if A.Nav.ReleaseTarget then A.Nav.ReleaseTarget() end
      end
    end
    -- Con «Compartir con la manada»: sale (1N) y se ven las suyas.
    llega(("1N|%d|20.00|20.00|Tesoro escondido"):format(map), "Dana Ruiz")
    check(#No.Lista() == 1, "con compartir apagado, se vio la nota de otro")
    A.Set("manada.notasCompartir", true)
    salidos = {}
    local m = No.Agregar("Buen lugar para pescar")
    vaciarCola()
    check(m and m.compartida and salio("^1N|%d+|[%d%.]+|[%d%.]+|Buen lugar para pescar$", "GUILD"), "la nota compartida no salió por la hermandad (1N)")
    llega(("1N|%d|20.00|20.00|Tesoro escondido"):format(map), "Dana Ruiz")
    llega(("1N|%d|20.00|20.00|Tesoro escondido"):format(map), "Dana Ruiz")
    local de
    for _, x in ipairs(No.Lista()) do if x.de then de = x end end
    check(de and de.de == "Dana Ruiz" and de.texto == "Tesoro escondido", "no se vio la nota de la manada")
    check(#No.Lista() == 3, "la misma nota de otro salió dos veces")
    llega(("1N|%d|200|20|Rota"):format(map), "Elsa Mora")
    check(#No.Lista() == 3, "aceptó una nota rota")
    if P then check(#(capas["manada.notas"] or {}) == 3, "las notas no están todas en el mapa") end
    A.Set("manada.notasCompartir", false)
    check(#No.Lista() == 2, "apagado compartir, siguieron las notas de otros")
    check(No.Borrar(n.id) and #No.Lista() == 1, "no borró la nota")
  end)
  if P then P.SetLayer = setLayer end
end)

step("La página con los bloques nuevos", function()
  local P = MN.Pagina
  conRed(function()
    MN.Cita.Proponer("Minas de la Muerte", RELOJ + 7200)
    llega(("1C|21|%d|Vallefresno"):format(RELOJ + 3600), "Elsa Mora")
    MN.Reloj.Anotar("Mor'Ladim", map, 30, 40, RELOJ - 600)
    A.Fire("SHOW_OPTIONS", "manada")
    RUN_TIMERS(3)
    local ui = P.ui
    check(ui and ui.citas and ui.notas and ui.cazados, "la página no tiene los bloques nuevos")
    if ui and ui.citas then
      ui.citas:Llenar()
      check(ui.citas.alfaN == 2, "el bloque de citas no muestra las dos citas")
      -- La de Elsa (antes, arriba): «Voy» y «No puedo»; la tuya: «Quitar».
      local f1, f2 = ui.citas.filas[1], ui.citas.filas[2]
      check(f1 and f1.B1:IsShown() and f1.B2:IsShown() and f1.B1.Texto:GetText() == "Voy", "la cita de otro no trae «Voy» y «No puedo»")
      check(f2 and f2.B1:IsShown() and not f2.B2:IsShown(), "tu cita no trae solo «Quitar»")
      ui.notas:Llenar()
      check(ui.notas.alfaN == 1, "el bloque de notas no muestra tu nota")
      ui.cazados:Llenar()
      check(ui.cazados.alfaN == 2, "el bloque de raros no muestra los cazados")
    end
  end)
end)

GetServerTime = servidor
print(string.format("PRUEBA: 1.2.8 La Jauría (cita, quién va, raros con reloj, notas, página), %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
