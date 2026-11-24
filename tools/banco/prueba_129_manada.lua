-- Prueba de la 1.2.9, La Jauría (tools/prueba.py la corre con las demás prueba_*.lua):
--   * cambiar de plano: lo lleno (jugadores, presas tomadas, nodos), Lya lo sugiere una vez,
--     «Cambiar de plano» (1L por susurro), el anfitrión invita, «¡Ya estás en otro plano!»,
--     antes y después, nadie en otro plano (1O a la manada) y /alfa plano;
--   * ¿quién tiene...?: 1W por la hermandad, 1U por susurro, solo con permiso, «Susurrar»;
--   * logros de la manada: 1E (nivel 60, primera montura, raro), festejos y permisos;
--   * la semana de la manada: tu semana, 1S y 1F, la suma y los dos órdenes;
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
local function check(cond, msg) if not cond then NOTE("1.2.9 manada", msg) end end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
local N = AlfaNucleo
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local MN = NS_OF("Alfa_Manada")
local R, U, Gu, Pl = MN.Red, MN.U, MN.Guaridas, MN.Plano

-- Lo que sale por la red y los avisos, mientras dura `fn` (con hermandad).
local salidos, avisos = {}, {}
local function conRed(fn, sinCompartir)
  A.Set("manada.compartir", not sinCompartir)
  R.Escuchar()
  local via, envio, av, guild = R.Via, C_ChatInfo.SendAddonMessage, K.Aviso, IsInGuild
  R.Via = function() return "hermandad" end
  IsInGuild = function() return true end
  C_ChatInfo.SendAddonMessage = function(_, t, c, d) salidos[#salidos + 1] = { (t:gsub("|~[HA]$", "")), c, d } end
  K.Aviso = function(o) if o.lya == false then return av(o) end avisos[#avisos + 1] = o return true end
  local ok, e = pcall(fn)
  R.Via, C_ChatInfo.SendAddonMessage, K.Aviso, IsInGuild = via, envio, av, guild
  A.Set("manada.compartir", false)
  if not ok then error(e) end
end
local function vaciarCola() for _ = 1, 60 do FIRE(R.motor, "OnUpdate", 0.2) end end
local function llega(texto, quien, canal) FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", texto .. "|~H", canal or "GUILD", quien) end
local function salio(patron, canal)
  for _, m in ipairs(salidos) do if m[1]:find(patron) and (not canal or m[2] == canal) then return m end end
  return nil
end
local function ultimo() return avisos[#avisos] end

step("Los ajustes de fábrica", function()
  check(A.Get("manada.planoAviso") == true, "la sugerencia de plano no viene prendida")
  check(A.Get("manada.logros") == true, "los festejos no vienen prendidos")
  for _, k in ipairs({ "quienTiene", "logrosCompartir", "semanaCompartir" }) do
    check(A.Get("manada." .. k) == false, "manada." .. k .. " no viene apagado de fábrica")
  end
  check(type(AlfaManada.CambiarPlano) == "function" and type(AlfaManada.Plano) == "function", "falta AlfaManada.CambiarPlano / Plano")
end)

-- Las placas de nombre del banco: criaturas y jugadores a gusto.
local placas = {}
local g = { UnitExists = UnitExists, UnitGUID = UnitGUID, UnitIsPlayer = UnitIsPlayer, UnitIsTapDenied = UnitIsTapDenied,
  UnitIsUnit = UnitIsUnit, UnitIsDead = UnitIsDead, UnitInParty = UnitInParty, UnitInRaid = UnitInRaid, IsInGroup = IsInGroup }
local function conPlacas()
  UnitExists = function(u) return u == "player" or placas[u] ~= nil end
  UnitGUID = function(u) return placas[u] and placas[u].guid or "Player-1-0001" end
  UnitIsPlayer = function(u) return placas[u] ~= nil and placas[u].jugador or false end
  UnitIsTapDenied = function(u) return placas[u] ~= nil and placas[u].tapado or false end
  UnitIsUnit = function(a, b) return a == b end
  UnitIsDead = function() return false end
  UnitInParty = function() return false end
  UnitInRaid = function() return false end
end
local function sinPlacas() for k, v in pairs(g) do _G[k] = v end end
local function capa(n, cuantos, jugadores, tapados)
  wipe(placas)
  local i = 0
  for j = 1, cuantos or 1 do i = i + 1 placas["nameplate" .. i] = { guid = ("Creature-0-5250-0-%d-299-%010d"):format(n, j) } end
  for j = 1, jugadores or 0 do i = i + 1 placas["nameplate" .. i] = { guid = ("Player-1-%08d"):format(j), jugador = true } end
  for j = 1, tapados or 0 do i = i + 1 placas["nameplate" .. i] = { guid = ("Creature-0-5250-0-%d-300-%010d"):format(n, 500 + j), tapado = true } end
end

step("Cambiar de plano", function()
  check(Pl and Pl.Estado and Pl.Revisar and Pl.CambiarYDecir, "falta Plano.lua")
  conPlacas()
  conRed(function()
    Pl.Olvidar()
    capa(7994)
    FIRE_EVENT("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local mia = Gu.Actual()
    check(mia and mia.capa == 7994, "no supo tu plano")
    local map = mia and mia.map or 1429
    check(Pl.Estado().nivel == "tranquilo", "sin gente no dijo tranquilo")
    check(not Pl.Revisar(), "tranquilo, sugirió cambiar")
    -- Se llena: 6 jugadores, 4 presas tomadas, un nodo que se te fue.
    capa(7994, 1, 6, 4)
    Pl.NodoPerdido()
    avisos = {}
    check(not Pl.Revisar(), "sugirió a la primera revisión (debe ser claro: dos seguidas)")
    local e = Pl.Estado()
    check(e.nivel == "lleno" and e.jugadores == 6 and e.tapados == 4 and e.nodos == 1, "no contó lo lleno: " .. tostring(e.nivel) .. " " .. e.jugadores .. "/" .. e.tapados .. "/" .. e.nodos)
    check(Pl.Revisar(), "lleno dos veces, Lya no sugirió")
    local a = avisos[1]
    check(a and a.titulo == "Esto está lleno de cazadores" and a.texto:find("¿Nos cambiamos de plano?", 1, true), "la sugerencia no dice «Esto está lleno de cazadores. ¿Nos cambiamos de plano?»")
    check(a and a.accion and a.accion.texto == "Cambiar de plano", "la sugerencia no trae «Cambiar de plano»")
    check(not Pl.Revisar(), "sugirió otra vez antes de 15 minutos")
    -- Nadie de la manada en otro plano: lo dice y ofrece preguntar.
    avisos = {}
    if a and a.accion then a.accion.alClic() end
    local b = ultimo()
    check(b and b.titulo == "Nadie de la manada anda en otro plano" and b.accion and b.accion.texto == "Preguntar a la manada", "sin nadie en otro plano no lo dijo claro")
    salidos = {}
    if b and b.accion then b.accion.alClic() end
    vaciarCola()
    check(salio("^1O|" .. map .. "|7994$", "GUILD"), "«Preguntar a la manada» no salió (1O)")
    check(select(2, Gu.PreguntarManada()) == "espera", "preguntó dos veces seguidas")
    -- Ana abre su guarida en la 8001: aviso con «Cambiar de plano».
    avisos = {}
    llega("1G|" .. map .. "|8001|1", "Ana Smith")
    check(ultimo() and ultimo().accion and ultimo().accion.texto == "Cambiar de plano" and ultimo().titulo:find("Ana Smith", 1, true), "al abrir Ana su guarida no te avisó")
    llega("1G|" .. map .. "|8002|1", "Beto Ruiz")
    llega("1G|" .. map .. "|7994|1", "Caro Vega") -- (en tu mismo plano: no sirve)
    -- «Cambiar de plano»: 1L por susurro al primero.
    salidos = {}
    local ok = Pl.CambiarYDecir()
    for _ = 1, 60 do FIRE(R.motor, "OnUpdate", 0.2) end
    check(ok, "no empezó a cambiar de plano")
    local q = salio("^1L|" .. map .. "|7994$", "WHISPER")
    check(q, "no pidió el cambio por susurro (1L)")
    check(not salio("^1L|.*", "WHISPER") or not tostring(salio("^1L|", "WHISPER")[3]):find("Caro"), "le pidió a quien está en tu mismo plano")
    check(select(2, Gu.CambiarPlano()) == "pedido", "dejó pedir dos veces")
    local quien = q and tostring(q[3]) or ""
    llega("1R|ok", q and (quien:find("Ana") and "Ana Smith" or "Beto Ruiz") or "Ana Smith", "WHISPER")
    check(Gu.Pedido() and Gu.Pedido().invitado, "no tomó el sí")
    -- El juego te pasa a la 8002 (cualquiera que no sea la tuya vale).
    avisos = {}
    capa(8002, 2)
    Pl.Muestrear()
    FIRE_EVENT("NAME_PLATE_UNIT_ADDED", "nameplate1")
    check(Gu.Actual() and Gu.Actual().capa == 8002 and Gu.Pedido() == nil, "al llegar no cerró el pedido")
    local l = avisos[1]
    check(l and l.titulo == "¡Ya estás en otro plano!" and l.accion and l.accion.texto == "Salir del grupo", "no dijo «¡Ya estás en otro plano!» con «Salir del grupo»")
    -- «Salir del grupo» solo con el clic.
    local salio1 = false
    local lp = C_PartyInfo.LeaveParty
    C_PartyInfo.LeaveParty = function() salio1 = true end
    IsInGroup = function() return true end
    check(not salio1, "salió del grupo sin clic")
    if l and l.accion then l.accion.alClic() end
    check(salio1, "«Salir del grupo» no salió del grupo")
    C_PartyInfo.LeaveParty = lp
    IsInGroup = g.IsInGroup
    -- Antes y después.
    avisos = {}
    RUN_TIMERS(80)
    local c = Pl.ultimaComparacion
    check(c and c.antes.nivel == "lleno" and c.ahora.nivel == "tranquilo", "no comparó antes y después")
    local cmp
    for _, x in ipairs(avisos) do if x.titulo == "Tu plano nuevo" then cmp = x end end
    check(cmp and cmp.texto:find("Antes: lleno", 1, true) and cmp.texto:find("Ahora: tranquilo", 1, true), "el aviso no compara: " .. tostring(cmp and cmp.texto))
    -- Anfitrión: 1L de alguien de otro plano, con la guarida abierta, invita.
    local invitados = {}
    local inv = C_PartyInfo.InviteUnit
    C_PartyInfo.InviteUnit = function(n) invitados[#invitados + 1] = n end
    Gu.Abrir(true)
    salidos = {}
    llega("1L|" .. map .. "|8002", "Dani Paz", "WHISPER") -- (de tu mismo plano: no)
    vaciarCola()
    check(#invitados == 0 and salio("^1R|no|otra", "WHISPER"), "invitó a alguien de tu mismo plano")
    llega("1L|" .. map .. "|7994", "Eli Gil", "WHISPER")
    vaciarCola()
    check(#invitados == 1 and salio("^1R|ok", "WHISPER"), "con la guarida abierta no invitó al de otro plano")
    -- 1O de alguien: con tu guarida abierta, nada (ya te ve).
    avisos = {}
    llega("1O|" .. map .. "|7994", "Fede Luna")
    check(#avisos == 0, "con la guarida abierta te pidió abrirla")
    Gu.Abrir(false)
    llega("1O|" .. map .. "|7994", "Fede Luna")
    check(ultimo() and ultimo().accion and ultimo().accion.texto == "Abrir mi guarida", "1O no te propuso abrir tu guarida")
    llega("1O|" .. map .. "|7994", "Fede Luna")
    check(#avisos == 1, "1O del mismo lobo avisó dos veces")
    C_PartyInfo.InviteUnit = inv
    -- Sin compartir no se puede y lo dice.
  end)
  check(select(2, Gu.CambiarPlano()) == "compartir", "sin compartir dejó cambiar de plano")
  -- /alfa plano
  local dichos = {}
  local imp = N.Imprimir
  N.Imprimir = function(...) dichos[#dichos + 1] = table.concat({ ... }, " ") end
  check(type(A.RunCommand) == "function", "sin A.RunCommand")
  A.RunCommand("plano")
  N.Imprimir = imp
  local dijo = false
  for _, t in ipairs(dichos) do if t:find("deja que te vea", 1, true) then dijo = true end end
  check(dijo, "/alfa plano no respondió: " .. tostring(dichos[1]))
  sinPlacas()
end)

step("¿Quién tiene...?", function()
  local Qt = MN.QuienTiene
  check(Qt and Qt.Buscar and Qt.Mios, "falta QuienTiene.lua")
  -- Tus bolsas (de Alfa_Bolsas).
  local d = N.Datos("bolsas")
  d.personajes = d.personajes or {}
  local antes = d.personajes["Lobato-Forever"]
  d.personajes["Lobato-Forever"] = { bolsas = { [0] = { n = 3,
      [1] = { i = 2589, c = 12, l = "|cffffffff|Hitem:2589::::::::|h[Lino]|h|r" },
      [2] = { i = 2589, c = 8, l = "|cffffffff|Hitem:2589::::::::|h[Lino]|h|r" },
      [3] = { i = 2592, c = 3, l = "|cffffffff|Hitem:2592::::::::|h[Paño de lana]|h|r" } } },
    banco = { [6] = { n = 1, [1] = { i = 2840, c = 20, l = "|cffffffff|Hitem:2840::::::::|h[Barra de cobre]|h|r" } } } }
  local m = Qt.Mios("lino")
  check(#m == 1 and m[1].id == 2589 and m[1].cuantos == 20, "no sumó tu lino de dos casillas")
  check(#Qt.Mios("PANO") == 1 and #Qt.Mios("cobre") == 1, "no buscó sin acentos ni mayúsculas o en el banco")
  conRed(function()
    -- Sin hermandad, no.
    local ig = IsInGuild
    IsInGuild = function() return false end
    check(select(2, Qt.Buscar("Lino")) == "hermandad", "buscó sin hermandad")
    IsInGuild = ig
    check(select(2, Qt.Buscar("li")) == "corto", "buscó con dos letras")
    salidos = {}
    check(Qt.Buscar("Lingote de hierro"), "no buscó")
    vaciarCola()
    local w = salio("^1W|%d+|Lingote de hierro$", "GUILD")
    check(w, "la búsqueda no salió por la hermandad (1W)")
    check(select(2, Qt.Buscar("Lino")) == "espera", "dejó buscar sin esperar")
    local cid = w and w[1]:match("^1W|(%d+)|")
    llega(("1U|%s|3575|7|Lingote de hierro"):format(tostring(cid)), "Ana Smith", "WHISPER")
    llega(("1U|%s|3575|2|Lingote de hierro"):format(tostring(cid)), "Beto Ruiz", "WHISPER")
    llega(("1U|%s|3575|2|Lingote de hierro"):format(tostring(cid)), "Caro Vega") -- (por la hermandad: no)
    llega("1U|999|3575|2|Lingote de hierro", "Dani Paz", "WHISPER") -- (otra consulta)
    llega(("1U|%s|abc|2|Malo"):format(tostring(cid)), "Eli Gil", "WHISPER")
    local res = Qt.Resultados()
    check(#res == 2 and res[1].nombre == "Ana Smith" and res[1].cuantos == 7 and res[2].nombre == "Beto Ruiz", "los resultados no son Ana y Beto por nombre")
    -- «Susurrar» solo abre el cuadro del chat.
    local abierto
    local oc = ChatFrame_OpenChat
    local cfu = ChatFrameUtil
    ChatFrameUtil = nil
    ChatFrame_OpenChat = function(t) abierto = t end
    local env = SendChatMessage
    local mandado = false
    SendChatMessage = function() mandado = true end
    Qt.Susurrar(res[1])
    check(abierto and abierto:find("^/w Ana") and not mandado, "«Susurrar» no abrió el cuadro o mandó algo: " .. tostring(abierto))
    ChatFrame_OpenChat, ChatFrameUtil, SendChatMessage = oc, cfu, env
    -- Contestar: apagado (de fábrica), nada.
    salidos = {}
    llega("1W|5|lino", "Fede Luna")
    vaciarCola()
    check(not salio("^1U|"), "contestó con «¿Quién tiene...?» apagado")
    A.Set("manada.quienTiene", true)
    llega("1W|5|lino", "Fede Luna", "WHISPER") -- (por susurro: no)
    vaciarCola()
    check(not salio("^1U|"), "contestó una pregunta que no llegó por la hermandad")
    llega("1W|5|lino", "Fede Luna")
    vaciarCola()
    local u = salio("^1U|5|2589|20|Lino$", "WHISPER")
    check(u and tostring(u[3]):find("Fede"), "no le contestó a Fede por susurro (1U)")
    check(not salio("^1U|5|2840"), "contestó lo que no coincidía")
    salidos = {}
    llega("1W|6|lino", "Fede Luna")
    vaciarCola()
    check(not salio("^1U|6"), "contestó dos veces seguidas a la misma persona")
    llega("1W|7|espada", "Gael Paz")
    vaciarCola()
    check(not salio("^1U|7"), "contestó algo que no tiene")
    A.Set("manada.quienTiene", false)
  end, true) -- (sin compartir la ubicación: funciona igual)
  d.personajes["Lobato-Forever"] = antes
  Qt.Olvidar()
end)

step("Logros de la manada", function()
  local Lo = MN.Logros
  check(Lo and Lo.Festejar, "falta Logros.lua")
  conRed(function()
    avisos = {}
    llega("1E|n|60", "Ana Smith")
    check(ultimo() and ultimo().titulo == "¡Ana Smith llegó al nivel 60!" and ultimo().lobo == "aullando", "no festejó el 60 de Ana")
    llega("1E|n|60", "Ana Smith")
    check(#avisos == 1, "festejó dos veces el mismo logro")
    llega("1E|n|30", "Beto Ruiz")
    llega("1E|n|60", "Caro Vega", "WHISPER")
    check(#avisos == 1, "festejó un nivel que no es 60 o un logro por susurro")
    llega("1E|m", "Beto Ruiz")
    check(ultimo().titulo == "¡Beto Ruiz tiene su primera montura!", "no festejó la montura")
    llega("1E|r|Mor'Ladim", "Caro Vega")
    check(ultimo().titulo == "¡Caro Vega cazó a Mor'Ladim!", "no festejó el raro")
    A.Set("manada.logros", false)
    llega("1E|r|Otro", "Dani Paz")
    check(#avisos == 3, "con los festejos apagados festejó")
    A.Set("manada.logros", true)
    -- Los tuyos: solo con permiso.
    salidos = {}
    FIRE_EVENT("PLAYER_LEVEL_UP", 60)
    MN.Reloj.Anotar("Rak'shiri", 1429, 50, 50, GetServerTime())
    FIRE_EVENT("NEW_MOUNT_ADDED", 7)
    vaciarCola()
    check(not salio("^1E|"), "compartió tus logros sin permiso")
    A.Set("manada.logrosCompartir", true)
    N.DatosPersonaje("manada").montura = false
    FIRE_EVENT("PLAYER_LEVEL_UP", 60)
    MN.Reloj.Anotar("Gorlash", 1429, 40, 40, GetServerTime())
    FIRE_EVENT("NEW_MOUNT_ADDED", 7)
    FIRE_EVENT("NEW_MOUNT_ADDED", 8)
    vaciarCola()
    check(salio("^1E|n|60$", "GUILD"), "no compartió tu 60 (1E|n)")
    check(salio("^1E|r|Gorlash$", "GUILD"), "no compartió tu raro (1E|r)")
    local n = 0
    for _, m in ipairs(salidos) do if m[1] == "1E|m|" then n = n + 1 end end
    check(n == 1, "la primera montura no salió una vez: " .. n)
    A.Set("manada.logrosCompartir", false)
  end, true) -- (sin compartir la ubicación)
end)

step("La semana de la manada", function()
  local Lo = MN.Logros
  local w = Lo.Semana()
  local m0 = w.misiones
  FIRE_EVENT("QUEST_TURNED_IN", 100, 0, 0)
  FIRE_EVENT("QUEST_TURNED_IN", 101, 0, 0)
  check(Lo.Semana().misiones == m0 + 2, "no contó las misiones entregadas")
  local ii, gi = IsInInstance, GetInstanceInfo
  IsInInstance = function() return true, "party" end
  GetInstanceInfo = function() return "Minas de la Muerte" end
  local z0 = Lo.Semana().mazmorras
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  IsInInstance, GetInstanceInfo = ii, gi
  check(Lo.Semana().mazmorras == z0 + 1, "la misma mazmorra contó dos veces")
  check(Lo.Semana().niveles >= 2 and Lo.Semana().raros >= 2, "no contó tus niveles o raros de la semana")
  local s = Lo.NumeroSemana()
  conRed(function()
    salidos = {}
    check(not Lo.CompartirSemana(true), "compartió tu semana sin permiso")
    llega(("1S|%d|10|1|2|3"):format(s), "Ana Smith")
    llega(("1S|%d|4|0|0|1"):format(s), "Beto Ruiz")
    llega(("1S|%d|99|9|9|9"):format(s - 1), "Caro Vega") -- (la semana pasada)
    llega(("1S|%d|x|0|0|1"):format(s), "Dani Paz")
    llega(("1S|%d|5|0|0|0"):format(s), "Eli Gil", "WHISPER")
    local lista, tot = Lo.Manada("nombre")
    check(#lista == 3 and tot.lobos == 3, "la semana no tiene a ti, Ana y Beto: " .. #lista)
    check(lista[1].tu and lista[2].nombre == "Ana Smith" and lista[3].nombre == "Beto Ruiz", "por nombre no va tú, Ana, Beto")
    check(tot.misiones == Lo.Semana().misiones + 14, "la suma de misiones no cuadra")
    local porAporte = Lo.Manada("aporte")
    check(porAporte[1].aporte >= porAporte[2].aporte and porAporte[2].aporte >= porAporte[3].aporte, "por aporte no va de más a menos")
    check(Lo.TextoCuenta({ misiones = 1, raros = 0, mazmorras = 2, niveles = 0 }) == "1 misión  \194\183  2 mazmorras", "el texto de la cuenta: " .. Lo.TextoCuenta({ misiones = 1, mazmorras = 2 }))
    -- Con permiso: sale tu semana y contestas a 1F.
    A.Set("manada.semanaCompartir", true)
    check(Lo.CompartirSemana(true), "no compartió tu semana")
    vaciarCola()
    check(salio(("^1S|%d|%d|"):format(s, Lo.Semana().misiones), "GUILD"), "tu semana no salió por la hermandad (1S)")
    salidos = {}
    llega(("1F|%d"):format(s), "Gael Paz")
    RUN_TIMERS(10)
    vaciarCola()
    check(salio("^1S|", "GUILD"), "no contestó «¿me dicen su semana?» (1F)")
    A.Set("manada.semanaCompartir", false)
    salidos = {}
    check(Lo.PedirSemanas() or true, "")
    vaciarCola()
  end, true)
end)

step("La página con los bloques nuevos", function()
  local P = MN.Pagina
  conPlacas()
  conRed(function()
    capa(9100, 1, 7, 3)
    FIRE_EVENT("NAME_PLATE_UNIT_ADDED", "nameplate1")
    FIRE_EVENT("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Pl.Muestrear()
    A.Fire("SHOW_OPTIONS", "manada")
    RUN_TIMERS(3)
    local ui = P.ui
    check(ui and ui.quienTiene and ui.semana and ui.guaridas.Plano, "la página no tiene los bloques nuevos")
    if ui and ui.guaridas.Plano then
      ui.guaridas:Llenar()
      check(ui.guaridas.Plano:IsShown() and ui.guaridas.Plano.Texto:GetText() == "Cambiar de plano", "no está «Cambiar de plano» en la página")
      local t = ui.guaridas.PlanoNota:GetText() or ""
      check(t:find("lleno", 1, true) and t:find("7 cazadores", 1, true), "la página no dice cómo está tu plano: " .. t)
      check((ui.guaridas.Titulo:GetText() or ""):find("Guarida", 1, true), "la página no dice tu plano")
      ui.semana:Llenar()
      check(ui.semana.alfaN >= 1, "la semana no muestra tu fila")
      check(not (ui.semana.Titulo:GetText() or ""):find("lugar", 1, true), "la semana habla de lugares")
      ui.quienTiene:Llenar()
      check((ui.quienTiene.Vacio:GetText() or "") ~= "", "«¿Quién tiene...?» sin búsqueda no explica qué hacer")
    end
  end)
  sinPlacas()
end)

print(string.format("PRUEBA: 1.2.9 La Jauría (plano, quién tiene, logros, semana, página), %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
