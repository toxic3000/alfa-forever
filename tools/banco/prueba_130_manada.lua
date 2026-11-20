-- Prueba de la 1.3.0, La Jauría: la manada crece (tools/prueba.py la corre con las demás):
--   * spots de farmeo: su tipo, su capa, compartirlos solo con permiso (1N|...|s, sin compartir ubicación);
--   * el tablón: poner, quitar, lo que llega (1b), caduca a la hora, «?» al entrar;
--   * el mentor: adoptar (1a|p), aceptar (1a|s), cómo va (1a|e) y el empujoncito, terminar (1a|x);
--   * el botín: clase y nivel (1i) solo con permiso, la sugerencia «Regalárselo», comercio o correo;
--   * las guaridas en vivo: por zona y su marca en el mapa;
--   * el calendario de la semana, la página con los bloques nuevos y la red para otros módulos (1Y).
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
local function check(cond, msg) if not cond then NOTE("1.3.0 manada", msg) end end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
local N = AlfaNucleo
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local MN = NS_OF("Alfa_Manada")
local R, U = MN.Red, MN.U

local salidos, avisos = {}, {}
local function conRed(fn, sinCompartir)
  A.Set("manada.compartir", not sinCompartir)
  R.Escuchar()
  local via, envio, av, guild = R.Via, C_ChatInfo.SendAddonMessage, K.Aviso, IsInGuild
  R.Via = function() return "hermandad" end
  IsInGuild = function() return true end
  C_ChatInfo.SendAddonMessage = function(_, t, c, d) salidos[#salidos + 1] = { t, c, d } end
  K.Aviso = function(o) if o.lya == false then return av(o) end avisos[#avisos + 1] = o return true end
  local ok, e = pcall(fn)
  R.Via, C_ChatInfo.SendAddonMessage, K.Aviso, IsInGuild = via, envio, av, guild
  A.Set("manada.compartir", false)
  if not ok then error(e) end
end
local function vaciarCola() for _ = 1, 60 do FIRE(R.motor, "OnUpdate", 0.2) end end
local function llega(texto, quien, canal) FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", texto, canal or "GUILD", quien) end
local function salio(patron, canal)
  for _, m in ipairs(salidos) do if m[1]:find(patron) and (not canal or m[2] == canal) then return m end end
  return nil
end
local function ultimo() return avisos[#avisos] end

-- Las capas del mapa que se pintan.
local capas = {}
do
  local P = A.Pins
  if P and P.SetLayer then
    local sl = P.SetLayer
    P.SetLayer = function(nombre, pins, o, ...) capas[nombre] = pins return sl(nombre, pins, o, ...) end
  end
end

step("Los ajustes de fábrica", function()
  for _, k in ipairs({ "spots", "tablon", "mentor", "botin", "guaridasMapa", "calendario" }) do
    check(A.Get("manada." .. k) == true, "manada." .. k .. " no viene prendido de fábrica")
  end
  for _, k in ipairs({ "spotsCompartir", "botinCompartir" }) do
    check(A.Get("manada." .. k) == false, "manada." .. k .. " no viene apagado de fábrica")
  end
  check(MN.Tablon and MN.Mentor and MN.Botin, "faltan Tablon.lua, Mentor.lua o Botin.lua")
end)

step("Spots de farmeo", function()
  local No = MN.Notas
  conRed(function()
    salidos = {}
    local s = No.Agregar("Lobos para pieles", "spot")
    check(s and No.EsSpot(s), "no dejó el spot")
    check(s and not s.compartida, "compartió un spot sin permiso")
    vaciarCola()
    check(not salio("^1N|"), "salió un spot sin permiso")
    local n = No.Agregar("Aquí vive Lya")
    check(n and not No.EsSpot(n), "la nota salió como spot")
    No.Pintar(true)
    local enSpots, enNotas = 0, 0
    for _ in ipairs(capas["manada.spots"] or {}) do enSpots = enSpots + 1 end
    for _ in ipairs(capas["manada.notas"] or {}) do enNotas = enNotas + 1 end
    check(enSpots >= 1 and #No.Lista("spot") == enSpots, "el spot no está en su propia capa")
    check(enNotas == #No.Lista("nota"), "la capa de notas tiene spots")
    -- Con permiso: sale por la hermandad aunque no compartas tu ubicación.
    A.Set("manada.spotsCompartir", true)
    salidos = {}
    local s2 = No.Agregar("Cobre en la cueva", "spot")
    vaciarCola()
    check(s2 and s2.compartida and salio("^1N|%d+|[%d%.]+|[%d%.]+|Cobre en la cueva|s$", "GUILD"), "el spot compartido no salió (1N|...|s)")
    -- Llega uno de Ana (spot) y una nota de Beto (sin compartir ubicación: la nota no).
    local antes = #No.Lista("spot")
    llega("1N|1429|40.00|60.00|Jabalíes|s", "Ana Smith")
    check(#No.Lista("spot") == antes + 1, "no tomó el spot de Ana")
    llega("1N|1429|41.00|61.00|Una nota", "Beto Ruiz")
    local hay = false
    for _, x in ipairs(No.Lista("nota")) do if x.texto == "Una nota" then hay = true end end
    check(not hay, "tomó una nota sin compartir ubicación")
    llega("1N|1429|42.00|62.00|Otro spot|s", "Caro Vega", "WHISPER")
    check(#No.Lista("spot") == antes + 1, "tomó un spot por susurro")
    A.Set("manada.spotsCompartir", false)
    local deOtros = 0
    for _, x in ipairs(No.Lista("spot")) do if x.de then deOtros = deOtros + 1 end end
    check(deOtros == 0, "sin permiso siguió mostrando spots de otros")
    -- Apagar los spots: sin capa y sin dejar más.
    A.Set("manada.spots", false)
    check(select(2, No.Agregar("Nada", "spot")) == "spots", "con los spots apagados dejó uno")
    No.Pintar(true)
    check(#(capas["manada.spots"] or {}) == 0, "con los spots apagados quedó su capa")
    A.Set("manada.spots", true)
    No.Borrar(s.id) No.Borrar(n.id) No.Borrar(s2.id)
  end, true)
end)

step("El tablón de la manada", function()
  local Tb = MN.Tablon
  conRed(function()
    local ig = IsInGuild
    IsInGuild = function() return false end
    check(select(2, Tb.Poner("m", "Minas")) == "hermandad", "puso un anuncio sin hermandad")
    IsInGuild = ig
    check(select(2, Tb.Poner("m", "  ")) == "texto", "puso un anuncio vacío")
    salidos = {}
    check(Tb.Poner("m", "Minas de la Muerte, falta sanador"), "no puso tu anuncio")
    vaciarCola()
    check(salio("^1b|m|23|%d+|Minas de la Muerte, falta sanador$", "GUILD"), "tu anuncio no salió por la hermandad (1b)")
    check(select(2, Tb.Poner("q", "Otra")) == "espera", "dejó poner dos seguidos")
    -- Llegan los de la manada.
    llega("1b|f|30|60|Cobre en Loch Modan", "Ana Smith")
    llega("1b|q|12|0|La cueva de los kobolds", "Beto Ruiz")
    llega("1b|z|12|0|Malo", "Caro Vega")
    llega("1b|m|12|9999|Viejo", "Dani Paz")
    llega("1b|m|12|0|Por susurro", "Eli Gil", "WHISPER")
    local l = Tb.Lista()
    check(#l == 3 and l[1].mio and l[2].nombre == "Beto Ruiz" and l[3].nombre == "Ana Smith", "el tablón no es tú, Beto, Ana: " .. #l)
    check(l[3] and Tb.Dato(l[3]):find("Farmear", 1, true) and Tb.Dato(l[3]):find("nivel 30", 1, true), "el dato no dice para qué y a qué nivel: " .. tostring(l[3] and Tb.Dato(l[3])))
    -- Alguien entra y pregunta: repites el tuyo.
    salidos = {}
    NOW = NOW + 40
    llega("1b|?", "Fede Luna")
    RUN_TIMERS(10)
    vaciarCola()
    check(salio("^1b|m|", "GUILD"), "no repitió tu anuncio al «?»")
    -- Ana lo quita; tú quitas el tuyo.
    llega("1b|x", "Ana Smith")
    check(#Tb.Lista() == 2, "no quitó el de Ana")
    salidos = {}
    check(Tb.Quitar(), "no quitó tu anuncio")
    vaciarCola()
    check(salio("^1b|x$", "GUILD"), "al quitarlo no avisó (1b|x)")
    -- A la hora se va solo.
    NOW = NOW + 3700
    check(#Tb.Lista() == 0, "el anuncio de Beto no caducó a la hora")
    A.Set("manada.tablon", false)
    llega("1b|m|10|0|Apagado", "Gael Paz")
    check(#Tb.Lista() == 0, "con el tablón apagado tomó un anuncio")
    A.Set("manada.tablon", true)
  end, true)
end)

step("El botín para la manada", function()
  local Bo = MN.Botin
  check(Bo.LeSirve({ minNivel = 18, clase = 4, sub = 3, hueco = "INVTYPE_CHEST" }, "WARRIOR", 20), "malla de nivel 18 no le sirve a un guerrero 20")
  check(not Bo.LeSirve({ minNivel = 18, clase = 4, sub = 4, hueco = "INVTYPE_CHEST" }, "WARRIOR", 20), "placas antes del 40 le sirven a un guerrero")
  check(not Bo.LeSirve({ minNivel = 18, clase = 4, sub = 1, hueco = "INVTYPE_CHEST" }, "WARRIOR", 20), "tela le sirve a un guerrero")
  check(Bo.LeSirve({ minNivel = 18, clase = 4, sub = 1, hueco = "INVTYPE_CLOAK" }, "WARRIOR", 20), "una capa no le sirve a cualquiera")
  check(not Bo.LeSirve({ minNivel = 25, clase = 4, sub = 3, hueco = "INVTYPE_CHEST" }, "WARRIOR", 20), "le sirve algo que no puede usar por nivel")
  check(not Bo.LeSirve({ minNivel = 8, clase = 4, sub = 3, hueco = "INVTYPE_CHEST" }, "WARRIOR", 20), "le sirve algo muy bajo para su nivel")
  check(Bo.LeSirve({ minNivel = 15, clase = 2, sub = 19, hueco = "INVTYPE_RANGEDRIGHT" }, "MAGE", 16), "una varita no le sirve a un mago")
  local cotas = "|cff1eff00|Hitem:2000::::::::|h[Cota de malla del lobo]|h|r"
  local ligada = "|cff1eff00|Hitem:2001::::::::|h[Cota ligada]|h|r"
  local gi = C_Item.GetItemInfo
  C_Item.GetItemInfo = function(l)
    if l == cotas then return "Cota de malla del lobo", cotas, 2, 22, 18, "Armadura", "Malla", 1, "INVTYPE_CHEST", 1, 100, 4, 3, 2 end
    if l == ligada then return "Cota ligada", ligada, 2, 22, 18, "Armadura", "Malla", 1, "INVTYPE_CHEST", 1, 100, 4, 3, 1 end
    return nil
  end
  local self = LOOT_ITEM_SELF
  LOOT_ITEM_SELF = "Recibes botín: %s." -- (el banco no lo trae)
  conRed(function()
    -- Compartir tu clase y nivel: solo con permiso.
    salidos = {}
    llega("1i|?", "Ana Smith")
    RUN_TIMERS(10)
    vaciarCola()
    check(not salio("^1i|%d"), "dijo tu clase y nivel sin permiso")
    A.Set("manada.botinCompartir", true)
    RUN_TIMERS(2)
    vaciarCola()
    check(salio("^1i|23|WARRIOR$", "GUILD"), "con permiso no dijo tu clase y nivel (1i)")
    A.Set("manada.botinCompartir", false)
    -- Ana (guerrera 20) y Beto (mago 10).
    llega("1i|20|WARRIOR", "Ana Smith")
    llega("1i|10|MAGE", "Beto Ruiz")
    llega("1i|x|MAGE", "Caro Vega")
    llega("1i|20|WARRIOR", "Dani Paz", "WHISPER")
    check(#Bo.Conocidos() == 2, "no conoce a Ana y Beto: " .. #Bo.Conocidos())
    avisos = {}
    FIRE_EVENT("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(ligada))
    check(#avisos == 0, "sugirió regalar algo que se liga al recogerlo")
    FIRE_EVENT("CHAT_MSG_LOOT", "Ana Smith recibe botín: " .. cotas .. ".")
    check(#avisos == 0, "sugirió el botín de otro")
    FIRE_EVENT("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(cotas))
    local a = ultimo()
    check(a and a.titulo == "¡Esto le sirve a Ana Smith!" and a.accion and a.accion.texto == "Regalárselo", "no sugirió regalárselo a Ana")
    FIRE_EVENT("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(cotas))
    check(#avisos == 1, "sugirió dos veces lo mismo")
    check(#Bo.Sugerencias() == 1, "la sugerencia no quedó para la página")
    -- «Regalárselo»: lejos, correo; al lado, comercio. Nunca solo.
    local comercio
    local it, cid, ue, un = InitiateTrade, CheckInteractDistance, UnitExists, UnitName
    InitiateTrade = function(u) comercio = u end
    CheckInteractDistance = function() return false end
    check(comercio == nil, "abrió el comercio sin clic")
    check(a and a.accion.alClic and Bo.Regalar(Bo.Sugerencias()[1]) == "correo", "lejos no ofreció el correo")
    check(Bo.Carta() and Bo.Carta().destino == "Ana Smith", "no guardó su nombre para el correo")
    UnitExists = function(u) return u == "player" or u == "target" end
    UnitName = function(u) if u == "target" then return "Ana Smith" end return un(u) end
    CheckInteractDistance = function() return true end
    check(Bo.Regalar(Bo.Sugerencias()[1]) == "comercio" and comercio == "target", "a tu lado no abrió el comercio")
    InitiateTrade, CheckInteractDistance, UnitExists, UnitName = it, cid, ue, un
    -- Apagado: nada.
    A.Set("manada.botin", false)
    avisos = {}
    local otra = cotas:gsub("2000", "2002")
    FIRE_EVENT("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(otra))
    check(#avisos == 0, "con el botín apagado sugirió")
    A.Set("manada.botin", true)
  end, true)
  C_Item.GetItemInfo = gi
  LOOT_ITEM_SELF = self
end)

step("El mentor", function()
  local Me = MN.Mentor
  conRed(function()
    -- Beto (nivel 10, de 1i) se puede adoptar; Ana (20) no.
    llega("1i|10|MAGE", "Beto Ruiz")
    llega("1i|20|WARRIOR", "Ana Smith")
    local c = Me.Candidatos()
    local hayBeto, hayAna = false, false
    for _, x in ipairs(c) do
      if x.nombre == "Beto Ruiz" then hayBeto = true end
      if x.nombre == "Ana Smith" then hayAna = true end
    end
    check(hayBeto and not hayAna, "los candidatos no son solo Beto")
    check(select(2, Me.Adoptar("Ana Smith", 20)) == "nivel", "dejó adoptar a alguien de casi tu nivel")
    salidos = {}
    check(Me.Adoptar("Beto Ruiz", 10), "no propuso adoptar a Beto")
    vaciarCola()
    check(salio("^1a|p|23$", "WHISPER"), "la propuesta no salió por susurro (1a|p)")
    check(not salio("^1a|", "GUILD"), "algo del mentor salió por la hermandad")
    -- Beto acepta; un «sí» de quien no se lo pediste no cuenta.
    llega("1a|s", "Caro Vega", "WHISPER")
    avisos = {}
    llega("1a|s", "Beto Ruiz", "WHISPER")
    local ap = Me.Aprendices()
    check(#ap == 1 and ap[1].nombre == "Beto Ruiz", "Beto no quedó de aprendiz")
    check(ultimo() and ultimo().titulo == "¡Beto Ruiz es tu aprendiz!", "no avisó que Beto aceptó")
    -- Cómo va: nivel, zona, misión.
    llega("1a|e|10|500|1429|1|3|Lobos hambrientos", "Beto Ruiz", "WHISPER")
    llega("1a|e|10|500|1429|1|3|Por la hermandad", "Beto Ruiz", "GUILD")
    ap = Me.Aprendices()
    local t = ap[1] and Me.Texto(ap[1]) or ""
    check(t:find("Nivel 10", 1, true) and t:find("Lobos hambrientos (1/3)", 1, true), "no dice cómo va Beto: " .. t)
    -- 20 minutos sin experiencia: el empujoncito, una vez.
    avisos = {}
    NOW = NOW + 600
    llega("1a|e|10|500|1429|1|3|Lobos hambrientos", "Beto Ruiz", "WHISPER")
    check(#avisos == 0, "empujó antes de tiempo")
    NOW = NOW + 700
    llega("1a|e|10|500|1429|2|3|Lobos hambrientos", "Beto Ruiz", "WHISPER")
    local e = ultimo()
    check(e and e.titulo == "Beto Ruiz lleva un rato sin avanzar" and e.accion and e.accion.texto == "Susurrar", "no dio el empujoncito")
    llega("1a|e|10|500|1429|2|3|Lobos hambrientos", "Beto Ruiz", "WHISPER")
    check(#avisos == 1, "empujó dos veces seguidas")
    -- Gana experiencia: el reloj vuelve a empezar.
    NOW = NOW + 1900
    llega("1a|e|10|900|1429|3|3|Lobos hambrientos", "Beto Ruiz", "WHISPER")
    check(#avisos == 1, "empujó aunque ganó experiencia")
    -- Te adoptan a ti: Caro (nivel 40) propone, aceptas.
    avisos = {}
    llega("1a|p|25", "Dani Paz", "WHISPER")
    check(#Me.Propuestas() == 0, "tomó una propuesta de alguien sin 10 niveles más")
    llega("1a|p|40", "Caro Vega", "WHISPER")
    local p = ultimo()
    check(p and p.titulo == "Caro Vega quiere ser tu mentor" and p.accion and p.accion.texto == "Aceptar", "no te propuso aceptar a Caro")
    salidos = {}
    if p and p.accion then p.accion.alClic() end
    RUN_TIMERS(5)
    vaciarCola()
    check(Me.Mentor() and Me.Mentor().nombre == "Caro Vega", "Caro no quedó de mentor")
    check(salio("^1a|s$", "WHISPER"), "el «sí» no salió (1a|s)")
    local est = salio("^1a|e|23|%d+|%d+|%d+|%d+|", "WHISPER")
    check(est and tostring(est[3]):find("Caro"), "no le contó a Caro cómo vas (1a|e)")
    -- Terminar: Caro se va; Beto termina contigo.
    salidos = {}
    check(Me.Terminar(Me.Mentor().clave), "no terminó con tu mentor")
    vaciarCola()
    check(salio("^1a|x$", "WHISPER") and Me.Mentor() == nil, "al terminar no avisó (1a|x)")
    llega("1a|x", "Beto Ruiz", "WHISPER")
    check(#Me.Aprendices() == 0, "Beto terminó y siguió de aprendiz")
    -- Apagado: no llegan propuestas.
    A.Set("manada.mentor", false)
    llega("1a|p|40", "Eli Gil", "WHISPER")
    A.Set("manada.mentor", true)
    check(#Me.Propuestas() == 0, "con el mentor apagado llegó una propuesta")
  end, true)
end)

step("Las guaridas en vivo y el calendario", function()
  local Gu, Ci = MN.Guaridas, MN.Cita
  conRed(function()
    llega("1P|1429|40.00|50.00|20|WARRIOR", "Ana Smith")
    llega("1P|1429|42.00|52.00|10|MAGE", "Beto Ruiz")
    llega("1P|1429|44.00|54.00|12|ROGUE", "Caro Vega")
    llega("1G|1429|7001|0", "Ana Smith")
    llega("1G|1429|7001|1", "Beto Ruiz")
    llega("1G|1429|7002|0", "Caro Vega")
    local z = Gu.PorZona()
    local e
    for _, x in ipairs(z) do if x.map == U.ZonaDe(1429) then e = x end end
    check(e and e.total == 3 and #e.guaridas >= 2, "no contó 3 lobos en 2 guaridas")
    check(e and e.guaridas[1].lobos >= e.guaridas[#e.guaridas].lobos, "las guaridas no van de más a menos")
    local t = e and Gu.TextoZona(e) or ""
    check(t:find("2 lobos", 1, true) and t:find("1 lobo", 1, true), "el texto de la zona: " .. t)
    Gu.PintarMapa(true)
    local m = capas["manada.guaridasMapa"] or {}
    check(#m == 1 and m[1].badge == "3", "la marca de la zona no está en el mapa con 3 lobos")
    -- El calendario: una cita mañana y otra pasado.
    local antes = 0
    for _, d in ipairs(Ci.Semana()) do antes = antes + #d.citas end
    check(Ci.Proponer("Minas de la Muerte", Ci.Cuando(1, 21 * 60)), "no propuso la cita")
    local s = Ci.Semana()
    check(#s == 7 and s[1].titulo == "Hoy" and s[2].titulo == "Mañana", "el calendario no tiene 7 días desde hoy")
    local hay
    for _, x in ipairs(s[2] and s[2].citas or {}) do if x.cita.que == "Minas de la Muerte" and x.hora == "21:00" then hay = true end end
    check(hay, "la cita no está en el día de mañana a las 21:00")
    -- La página.
    A.Fire("SHOW_OPTIONS", "manada")
    RUN_TIMERS(3)
    local ui = MN.Pagina.ui
    check(ui and ui.tablon and ui.mentor and ui.botin and ui.guaridasVivo and ui.calendario, "la página no tiene los bloques nuevos")
    if ui and ui.calendario then
      ui.calendario:Llenar()
      ui.calendario:Acomodar(800)
      local d2 = ui.calendario.dias[2]
      check(d2 and (d2.Citas:GetText() or ""):find("Minas de la Muerte", 1, true), "el calendario de la página no muestra la cita")
      check(ui.calendario:GetHeight() > 60, "el calendario no tiene alto")
      ui.guaridasVivo:Llenar()
      check(ui.guaridasVivo.alfaN >= 1, "las guaridas en vivo no muestran la zona")
      ui.tablon:Llenar()
      check((ui.tablon.Vacio:GetText() or "") ~= "", "el tablón vacío no explica qué hacer")
      ui.notas:Llenar()
      check(ui.notas.Spot and ui.notas.Spot.Texto:GetText() == "Buen lugar aquí", "falta «Buen lugar aquí» en las notas")
    end
    for _, c in pairs(Ci.Lista()) do if c.mia then Ci.Quitar(c.llave) end end
  end)
end)

step("La red para otros módulos", function()
  local Rd = AlfaManada.Red
  check(type(Rd) == "table" and Rd.Escuchar and Rd.EnviarHermandad and Rd.EnviarLibre, "falta AlfaManada.Red")
  check(not Rd.Escuchar("b", function() end), "dejó pisar el tablón (1b)")
  local oido
  check(Rd.Escuchar("Y", function(clave, quien, f, canal) oido = { quien, f[1], canal } end, true), "no dejó escuchar 1Y")
  conRed(function()
    llega("1Y|hola", "Ana Smith")
    check(oido and oido[1] == "Ana Smith" and oido[2] == "hola" and oido[3] == "GUILD", "1Y no llegó a su oyente")
    salidos = {}
    check(Rd.EnviarHermandad("saludo", "Y", "hola"), "no envió por la hermandad")
    vaciarCola()
    check(salio("^1Y|hola$", "GUILD"), "1Y no salió")
  end, true)
end)

print(string.format("PRUEBA: 1.3.0 La Jauría (spots, tablón, mentor, botín, guaridas, calendario, red), %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
