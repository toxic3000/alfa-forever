-- Prueba de la 1.2.5 (tools/prueba.py la corre con las demás prueba_*.lua):
--   * el aviso de misiones en el chat viene prendido y te sale a ti también;
--   * solo, «¡Misión completada: [Misión]!» sale en tu propio chat al entregar
--     (nada se manda al chat del grupo);
--   * en grupo, la misma línea va al chat del grupo;
--   * los perfiles del asistente ya no lo apagan.
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
local function check(cond, msg) if not cond then NOTE("1.2.5", msg) end end

local A = AlfaNucleo.A
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

step("El aviso al grupo viene apagado; tus líneas, a ti", function()
  -- REGLAS-BLIZZARD.md, regla 3: nada llena el chat de otros sin que lo pidas.
  check(A.Get("party.chat") == false, "mandar tu avance al chat del grupo viene prendido de fábrica")
  check(A.Get("party.chatEcho") == true, "tus propias líneas siguen escondidas (party.chatEcho)")
end)

-- Lo que sale: al chat del grupo (SendChatMessage) o a tu chat (AddMessage).
local enviados, locales = {}, {}
local envioViejo = SendChatMessage
SendChatMessage = function(texto, canal) table.insert(enviados, { texto, canal }) end
if C_ChatInfo then C_ChatInfo.SendChatMessage = nil end
DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME or {}
local addViejo = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(_, texto) table.insert(locales, texto) end
local linkViejo = GetQuestLink
GetQuestLink = function(q) return "|cffffff00|Hquest:" .. q .. ":10|h[El lobo perdido]|h|r" end

local function hay(lista, patron)
  for _, x in ipairs(lista) do
    local t = type(x) == "table" and x[1] or x
    if type(t) == "string" and t:find(patron, 1, true) then return true end
  end
  return false
end

step("Solo: «¡Misión completada!» en tu chat", function()
  A.Set("party.chat", false)
  A.Set("party.chat", true) -- (vuelve a escuchar)
  RUN_TIMERS(2)
  FIRE_EVENT("QUEST_TURNED_IN", 777, 100, 0)
  RUN_TIMERS(2)
  check(hay(locales, "Misión completada"), "jugando solo no salió «¡Misión completada!» en tu chat")
  check(hay(locales, "El lobo perdido"), "la línea no trae la misión")
  check(#enviados == 0, "jugando solo mandó algo al chat del grupo")
  -- En grupo con party.chat apagado: también solo a ti.
  local g = IsInGroup
  IsInGroup = function(cat) return cat == nil end
  A.Set("party.chat", false)
  RUN_TIMERS(2)
  FIRE_EVENT("QUEST_TURNED_IN", 779, 100, 0)
  RUN_TIMERS(2)
  check(#enviados == 0, "con el aviso al grupo apagado, se mandó al chat del grupo")
  check(hay(locales, "Misión completada"), "con el aviso al grupo apagado, no te salió a ti")
  IsInGroup = g
  A.Set("party.chat", true)
  FIRE_EVENT("QUEST_TURNED_IN", 777, 100, 0)
  local n = 0
  for _, x in ipairs(locales) do if x:find("Misión completada", 1, true) and x:find("quest:777:", 1, true) then n = n + 1 end end
  check(n == 1, "la misma misión se anunció " .. n .. " veces")
end)

step("En grupo: al chat del grupo", function()
  local g = IsInGroup
  IsInGroup = function(cat) return cat == nil end
  A.Set("party.chat", false)
  A.Set("party.chat", true)
  RUN_TIMERS(2)
  FIRE_EVENT("QUEST_TURNED_IN", 778, 100, 0)
  RUN_TIMERS(4)
  check(hay(enviados, "Misión completada"), "en grupo no se mandó al chat del grupo")
  local canal = enviados[1] and enviados[1][2]
  check(canal == "PARTY", "se mandó por " .. tostring(canal) .. ", no por el grupo")
  IsInGroup = g
end)

step("Los perfiles ya no lo apagan", function()
  local B = NS_OF("Alfa_Bienvenida")
  for _, x in ipairs(B.PERFILES) do
    check(x.filas.chatGrupo ~= false, "el perfil «" .. x.valor .. "» apaga el aviso de misiones")
  end
  local antes = A.Get("party.chat")
  B.AplicarPerfil("yo")
  B.AplicarPerfil("manada")
  check(A.Get("party.chat") == antes, "un perfil cambió el aviso al grupo (es decisión de cada quien)")
end)

-- Tu día de caza y los festejos (Alfa_Lya/Dia.lua).
step("Tu día de caza", function()
  local Ly = NS_OF("Alfa_Lya")
  check(Ly.Dia and Ly.Dia.Hoy, "no está Dia.lua")
  local antes = Ly.Dia.Hoy().misiones
  FIRE_EVENT("QUEST_TURNED_IN", 901, 50, 0)
  check(Ly.Dia.Hoy().misiones == antes + 1, "no contó la misión entregada")
  local r = Ly.Dia.Resumen()
  check(type(r) == "string" and r:find("misi", 1, true), "el resumen del día no dice las misiones: " .. tostring(r))
  -- Otro día: el de antes queda como «ayer».
  local d = AlfaNucleo.DatosPersonaje("lya")
  d.dia.fecha = "2000-01-01"
  Ly.Dia.Hoy()
  check(d.diaAyer and d.diaAyer.fecha == "2000-01-01" and d.dia.misiones == 0, "al cambiar de día no guardó el de antes")
end)

step("Lya aúlla cuando alguien del grupo sube de nivel", function()
  local Ly = NS_OF("Alfa_Lya")
  local dichos = {}
  local decir = Ly.Cerebro.Decir
  Ly.Cerebro.Decir = function(c) dichos[#dichos + 1] = c return true end
  local ue, ug, ul, un = UnitExists, UnitGUID, UnitLevel, UnitName
  local nivel = 20
  UnitGUID = function(u) if u == "party1" then return "Player-1-0002" end return ug(u) end
  UnitLevel = function(u) if u == "party1" then return nivel end return ul and ul(u) or 1 end
  UnitName = function(u) if u == "party1" then return "Ana" end return un(u) end
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  nivel = 21
  FIRE_EVENT("UNIT_LEVEL", "party1")
  check(dichos[1] and dichos[1].texto:find("Ana", 1, true) and dichos[1].aullar, "Lya no aulló por el nivel de Ana")
  check(dichos[1] and dichos[1].acciones and dichos[1].acciones[1], "falta «Felicitar en el grupo»")
  UnitExists, UnitGUID, UnitLevel, UnitName = ue, ug, ul, un
  Ly.Cerebro.Decir = decir
end)

-- Raros de la manada, tu guarida en su cuadro y su clic derecho (Guaridas.lua).
step("Raros de la manada y la guarida de un lobo", function()
  local MN = NS_OF("Alfa_Manada")
  local Gu, R = MN.Guaridas, MN.Red
  A.Set("manada.compartir", true)
  R.Escuchar()
  local via = R.Via
  R.Via = function() return "hermandad" end
  local salidos = {}
  local envio = C_ChatInfo.SendAddonMessage
  C_ChatInfo.SendAddonMessage = function(_, t, c, d) salidos[#salidos + 1] = { (t:gsub("|~[HA]$", "")), c, d } end
  local function cola() for _ = 1, 60 do FIRE(R.motor, "OnUpdate", 0.2) end end
  local ue, ug = UnitExists, UnitGUID
  local guid = { nameplate1 = "Creature-0-5250-0-7994-299-0000ABCDEF" }
  UnitExists = function(u) return u == "player" or guid[u] ~= nil end
  UnitGUID = function(u) return guid[u] or "Player-1-0001" end
  FIRE_EVENT("NAME_PLATE_UNIT_ADDED", "nameplate1")
  local mia = Gu.Actual()
  check(mia and mia.capa == 7994, "no supo tu guarida")
  local map = mia and mia.map or 1429
  -- Lya ve un raro: la manada lo sabe.
  Gu.AlAvistar({ kind = "rare", id = 61, key = "rare:61", name = "Thuros", map = map, x = 0.4, y = 0.5, source = "nameplate" })
  cola()
  local v
  for _, m in ipairs(salidos) do if m[1]:find("^1V|") then v = m[1] end end
  check(v and v:find("|7994|r|", 1, true) and v:find("Thuros", 1, true), "no avisó a la manada del raro: " .. tostring(v))
  -- Llega el raro de otro lobo, en otra guarida: aviso con su guarida.
  local K = AlfaNucleo.Kit
  local avisos = {}
  local av = K.Aviso
  K.Aviso = function(o) avisos[#avisos + 1] = o end
  local function llega(t, c, q) FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", t .. "|~H", c, q) end
  llega("1G|" .. map .. "|8001|1", "GUILD", "Ana Smith")
  llega("1V|" .. map .. "|8001|r|" .. map .. "|40.00|50.00|Mor'Ladim", "GUILD", "Ana Smith")
  check(avisos[1] and avisos[1].titulo:find("Mor'Ladim", 1, true), "no llegó el aviso del raro de la manada")
  check(avisos[1] and avisos[1].accion and avisos[1].accion.texto == "Pedir entrar", "el raro en otra guarida no ofrece «Pedir entrar»")
  llega("1V|" .. map .. "|7994|t|" .. map .. "|41.00|51.00|Cofre", "GUILD", "Beto Ruiz")
  check(avisos[2] and avisos[2].accion and avisos[2].accion.texto == "Ir de caza", "el tesoro en tu guarida no ofrece «Ir de caza»")
  llega("1V|" .. map .. "|8001|r|" .. map .. "|40.00|50.00|Mor'Ladim", "GUILD", "Ana Smith")
  check(#avisos == 2, "el mismo raro se avisó dos veces")
  K.Aviso = av
  -- Su guarida en su cuadro.
  local lineas = {}
  local tip = { AddLine = function(_, t) lineas[#lineas + 1] = t end }
  local uf = A.Compat.UnitFullName
  A.Compat.UnitFullName = function(u) if u == "mouseover" then return "Ana Smith" end return uf(u) end
  Gu.AlCuadro(tip, "mouseover")
  check(lineas[1] and lineas[1]:find("8001", 1, true) and lineas[1]:find("puerta abierta", 1, true), "el cuadro de Ana no dice su guarida: " .. tostring(lineas[1]))
  -- Su clic derecho: «Pedir entrar a su guarida».
  local I = MN.Invitar
  local raiz = { hijos = {} }
  function raiz:CreateButton(t, f) self.hijos[#self.hijos + 1] = { t, f } return { CreateButton = function() end } end
  function raiz:CreateDivider() end
  I.Armar("MENU_UNIT_PLAYER", raiz, { name = "Ana Smith" })
  local hay = false
  for _, h in ipairs(raiz.hijos) do if h[1]:find("Pedir entrar a su guarida", 1, true) then hay = true end end
  check(hay, "el clic derecho de Ana no ofrece «Pedir entrar a su guarida»")
  A.Compat.UnitFullName = uf
  UnitExists, UnitGUID = ue, ug
  C_ChatInfo.SendAddonMessage = envio
  R.Via = via
  A.Set("manada.compartir", false)
end)

step("El «?» de una página abre a Lya en su tema", function()
  local Ly = NS_OF("Alfa_Lya")
  local permitido = AlfaNucleo.Permitido
  AlfaNucleo.Permitido = function() return true end
  Ly.Guia.Abrir(nil, "pesca")
  AlfaNucleo.Permitido = permitido
  local v = _G.AlfaLyaGuia
  local dice = false
  local function ver(x) for _, h in ipairs(rawget(x, "_children") or {}) do
    if h._kind == "FontString" and h:IsShown() and type(h._text) == "string" and h._text:find("Estás en Pesca", 1, true) then dice = true end
    ver(h) end end
  if v then ver(v) v:Cerrar() end
  -- 1.3.9 (54): o ya contesta la primera pregunta de esa página.
  local p = Ly.Guia.Dicha
  if type(p) == "table" and p.modulo == "pesca" then dice = true end
  check(dice, "Lya no empezó por la página de Pesca")
  local O = NS_OF("Alfa").Options or (NS_OF("Alfa").UI and NS_OF("Alfa").UI.Options)
  check(O == nil or O.LyaHelp ~= nil, "la ventana de Alfa no tiene el «?» de Lya")
end)

step("Los avisos pequeños los dice Lya", function()
  local Ly = NS_OF("Alfa_Lya")
  local K = AlfaNucleo.Kit
  local Ce, UI = Ly.Cerebro, Ly.UI
  local activa, visible, decir = Ce.Activa, UI.Visible, Ce.Decir
  local dichos = {}
  Ce.Activa = function() return true end
  UI.Visible = function() return true end
  Ce.Decir = function(c) dichos[#dichos + 1] = c return true end
  local r = K.Aviso({ titulo = "Tocando a la puerta", texto = "Acepta la invitación.", accion = { texto = "Llévame", alClic = function() end } })
  check(r == true and dichos[1] and dichos[1].texto:find("Tocando a la puerta. Acepta", 1, true), "Lya no dijo el aviso")
  check(dichos[1] and dichos[1].acciones and dichos[1].acciones[1].texto == "Llévame", "el botón del aviso no pasó al globo de Lya")
  local f = K.Aviso({ titulo = "Con ventanita", lya = false })
  check(type(f) == "table" and f ~= true, "lya = false no dio el aviso de siempre")
  local g = K.Aviso({ titulo = "Abrir algo del juego", accion = { texto = "Abrir", seguro = "comunidades" } })
  check(type(g) == "table", "un aviso con botón seguro no salió como aviso")
  UI.Visible = function() return false end
  local h = K.Aviso({ titulo = "Lya oculta" })
  check(type(h) == "table", "con Lya oculta no salió el aviso de siempre")
  Ce.Activa, UI.Visible, Ce.Decir = activa, visible, decir
  if f.Cerrar then f:Cerrar() end
  if g.Cerrar then g:Cerrar() end
  if h.Cerrar then h:Cerrar() end
end)

SendChatMessage = envioViejo
DEFAULT_CHAT_FRAME.AddMessage = addViejo
GetQuestLink = linkViejo

print(string.format("PRUEBA: 1.2.5 misiones en el chat, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
