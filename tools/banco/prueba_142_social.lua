-- Prueba de la 1.4.2, área «social»: tu gente (Comodidades) y La Jauría.
--
-- Toxic: «20 mejoras bastante significativas y 20 en experiencia del usuario».
-- Aquí, las 10 del área social (una prueba por mejora; con el código de la
-- 1.4.1 todas fallan porque nada de esto existía):
--   1. Quién se conecta: la línea «se ha conectado» dice clase, nivel, zona y nota.
--   2. «[Invitar]» en esa línea: un clic invita (y no se mete con otros enlaces).
--   3. Invitar a quien te pide «inv» por susurro (amigos y hermandad; los demás no).
--   4. Lo que te escribieron mientras peleabas: aviso al terminar con «Responder».
--   5. Las flechas en el chat sin Alt (y al apagarlo, como estaba).
--   6. «Copiar el nombre» en el clic derecho de un jugador.
--   7. «Tu amigo» y su nota en el cuadro de información.
--   8. «Avisarme cuando se conecte»: el menú, el aviso con Susurrar/Invitar y /alfa avisame.
--   9. Con quién cazaste: se anota tu grupo y /alfa companeros lo muestra con Invitar.
--  10. Te invita alguien con quien ya cazaste: el aviso dice dónde y cuándo.
PRUEBA_AREA("1.4.2 social")

-- El menú del juego: guarda lo que registra cada etiqueta (como prueba_122).
local REGISTRADOS = {}
Menu = { ModifyMenu = function(tag, fn) REGISTRADOS[tag] = REGISTRADOS[tag] or {}; table.insert(REGISTRADOS[tag], fn) end }
local function nuevaDescripcion(texto, fn)
  local d = { texto = texto, fn = fn, hijos = {}, divisores = 0 }
  function d:CreateButton(t, f) local h = nuevaDescripcion(t, f); table.insert(self.hijos, h); return h end
  function d:CreateDivider() self.divisores = self.divisores + 1 end
  function d:CreateTitle(t) return self:CreateButton(t) end
  return d
end
local function abrirMenu(tag, contexto)
  local raiz = nuevaDescripcion(tag)
  for _, fn in ipairs(REGISTRADOS[tag] or {}) do fn(nil, raiz, contexto) end
  return raiz
end
local function boton(raiz, texto)
  for _, h in ipairs(raiz.hijos) do if h.texto == texto then return h end end
end

-- Tu gente: Ana es tu amiga, Beto es de tu hermandad, Zed no lo conoces.
ERR_FRIEND_ONLINE_SS = "|Hplayer:%s|h[%s]|h se ha conectado."
local ANA = { connected = true, name = "Ana", className = "Guerrera", level = 42, area = "Durotar", notes = "la del tanque", guid = "Player-1-A" }
C_FriendList = {
  GetFriendInfo = function(n) if n == "Ana" then return ANA end end,
  IsFriend = function(g) return g == "Player-1-A" end,
  GetNumFriends = function() return 1 end,
  GetFriendInfoByIndex = function(i) if i == 1 then return ANA end end,
}
function IsInGuild() return true end
function GetNumGuildMembers() return 1 end
function GetGuildRosterInfo(i) if i == 1 then return "Beto", "Oficial", 1, 30, "Mago", "Orgrimmar", "", "", true end end
function IsGuildMember(g) return g == "Player-1-B" end
local INVITADOS = {}
C_PartyInfo = C_PartyInfo or {}
C_PartyInfo.InviteUnit = function(n) INVITADOS[#INVITADOS + 1] = n end
local ABIERTO
ChatFrame_OpenChat = function(t) ABIERTO = t end
ChatFrameUtil = nil
ChatFrame1EditBox.SetAltArrowKeyMode = function(self, v) self.alfaModo = v end
ChatFrame1EditBox.alfaModo = true

PRUEBA_ENTRAR()
local A, N = Alfa, AlfaNucleo
local K = N.Kit
if N.Entrando then N.Entrando = function() return false end end
local CO = NS_OF("Alfa_Comodidades")
local MN = NS_OF("Alfa_Manada")

local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = rawget(t, k) } rawset(t, k, v) end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(t, k, a.v) end
  if not ok then error(e) end
end
-- Los avisos y lo que sale en tu chat mientras corre fn.
local function mirar(fn)
  local avisos, chat = {}, {}
  con(K, { Aviso = function(o) avisos[#avisos + 1] = o return {} end }, function()
    con(N, { Imprimir = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end }, fn)
  end)
  return avisos, chat
end
local function hay(lista, trozo)
  for _, t in ipairs(lista) do if tostring(t):find(trozo, 1, true) then return true end end
  return false
end
local function invitado(n) for _, x in ipairs(INVITADOS) do if x == n then return true end end return false end

PASO("1. quién se conecta, con clase, nivel, zona y nota", function()
  local Co = CO.Conexiones
  REVISA(Co, "no existe Comodidades/Conexiones.lua")
  if not Co then return end
  REVISA(N.Get("comodidades", "conexiones") == true, "«Quién se conecta» no viene encendido")
  local _, linea = Co.Filtro(nil, "CHAT_MSG_SYSTEM", "|Hplayer:Ana|h[Ana]|h se ha conectado.")
  REVISA(type(linea) == "string" and linea:find("Guerrera 42", 1, true) and linea:find("Durotar", 1, true) and linea:find("la del tanque", 1, true),
    "la línea de Ana no dice su clase, nivel, zona y nota: " .. tostring(linea))
  local _, beto = Co.Filtro(nil, "CHAT_MSG_SYSTEM", "|Hplayer:Beto|h[Beto]|h se ha conectado.")
  REVISA(type(beto) == "string" and beto:find("Mago 30", 1, true) and beto:find("Orgrimmar", 1, true), "la de Beto (hermandad) no dice lo suyo: " .. tostring(beto))
  REVISA(Co.Filtro(nil, "CHAT_MSG_SYSTEM", "Has descubierto Durotar.") == false, "se metió con otro mensaje del sistema")
  A.Set("comodidades.conexiones", false)
  local _, apagado = Co.Filtro(nil, "CHAT_MSG_SYSTEM", "|Hplayer:Ana|h[Ana]|h se ha conectado.")
  REVISA(apagado == nil, "apagado, siguió cambiando la línea")
  A.Set("comodidades.conexiones", true)
end)

PASO("2. «[Invitar]» en la línea, a un clic", function()
  local Co = CO.Conexiones
  if not Co then return REVISA(false, "sin Conexiones") end
  local _, linea = Co.Filtro(nil, "CHAT_MSG_SYSTEM", "|Hplayer:Ana|h[Ana]|h se ha conectado.")
  REVISA(linea and linea:find("addon:alfainvitar:Ana", 1, true), "la línea no trae «[Invitar]»")
  INVITADOS = {}
  local _, chat = mirar(function() REVISA(Co.AlEnlace("addon:alfainvitar:Ana"), "el clic en «Invitar» no se atendió") end)
  REVISA(invitado("Ana"), "el clic no invitó a Ana")
  REVISA(hay(chat, "Ana"), "no dijo en tu chat que la invitó")
  REVISA(not Co.AlEnlace("item:1234"), "se metió con un enlace del juego")
end)

PASO("3. invitar a quien te pide «inv»", function()
  local Pe = CO.Pedido
  REVISA(Pe, "no existe Comodidades/Pedido.lua")
  if not Pe then return end
  REVISA(Pe.EsPedido("inv") and Pe.EsPedido("Invítame!") and Pe.EsPedido("inv pls") and not Pe.EsPedido("inv para la mina mañana?"),
    "no reconoce bien un «inv»")
  A.Set("comodidades.invitarSusurro", true)
  INVITADOS = {}
  local susurro = function(msg, quien, guid) FIRE_EVENT("CHAT_MSG_WHISPER", msg, quien, "", "", quien, "", 0, 0, "", 0, 1, guid) end
  con(_G, { IsInGroup = function() return false end }, function()
    local _, chat = mirar(function() susurro("inv", "Ana", "Player-1-A") end)
    REVISA(invitado("Ana"), "no invitó a su amiga que le pidió «inv»")
    REVISA(hay(chat, "te lo pidió por susurro"), "no dijo en tu chat a quién invitó")
    susurro("inv", "Zed", "Player-1-Z")
    REVISA(not invitado("Zed"), "invitó a un desconocido sin «También a quien no conoces»")
    A.Set("comodidades.invitarSusurroTodos", true)
    susurro("inv", "Zed", "Player-1-Z")
    REVISA(invitado("Zed"), "con «También a quien no conoces», no invitó")
    A.Set("comodidades.invitarSusurroTodos", false)
  end)
  con(_G, { IsInGroup = function() return true end, UnitIsGroupLeader = function() return false end, IsInRaid = function() return false end }, function()
    INVITADOS = {}
    local _, chat = mirar(function() susurro("inv", "Beto", "Player-1-B") end)
    REVISA(#INVITADOS == 0 and hay(chat, "no eres líder"), "sin ser líder intentó invitar o no lo dijo")
  end)
  A.Set("comodidades.invitarSusurro", false)
  INVITADOS = {}
  con(_G, { IsInGroup = function() return false end }, function() susurro("inv", "Ana", "Player-1-A") end)
  REVISA(#INVITADOS == 0, "apagado, siguió invitando")
end)

PASO("4. lo que te escribieron mientras peleabas", function()
  local Pd = CO.Pendientes
  REVISA(Pd, "no existe Comodidades/Pendientes.lua")
  if not Pd then return end
  Pd.Olvidar()
  local avisos = mirar(function()
    con(_G, { InCombatLockdown = function() return true end }, function()
      FIRE_EVENT("CHAT_MSG_WHISPER", "¿vienes a la mina cuando termines?", "Ana", "", "", "Ana", "", 0, 0, "", 0, 2, "Player-1-A")
      FIRE_EVENT("CHAT_MSG_WHISPER", "oye, ¿tienes cobre?", "Beto", "", "", "Beto", "", 0, 0, "", 0, 3, "Player-1-B")
    end)
    REVISA(#Pd.Lista() == 2, "no anotó los susurros de la pelea")
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    TIEMPO(2)
  end)
  local a
  for _, o in ipairs(avisos) do if o.titulo == "Te escribieron mientras peleabas" then a = o end end
  REVISA(a, "al terminar la pelea no salió el aviso")
  if not a then return end
  REVISA(a.texto:find("Ana", 1, true) and a.texto:find("Beto", 1, true), "el aviso no dice quién escribió")
  REVISA(a.acciones and a.acciones[1] and a.acciones[1].texto == "Responder a Beto", "el botón no es «Responder» al último")
  ABIERTO = nil
  a.acciones[1].alClic()
  REVISA(ABIERTO == "/w Beto ", "«Responder» no abrió la caja con /w: " .. tostring(ABIERTO))
  REVISA(#Pd.Lista() == 0, "la lista no se vació al avisar")
  -- Sin pelea, nada se anota.
  FIRE_EVENT("CHAT_MSG_WHISPER", "hola", "Ana", "", "", "Ana", "", 0, 0, "", 0, 4, "Player-1-A")
  REVISA(#Pd.Lista() == 0, "anotó un susurro fuera de la pelea")
end)

PASO("5. las flechas en el chat sin Alt", function()
  REVISA(CO.Flechas, "no existe Comodidades/Flechas.lua")
  REVISA(N.Get("comodidades", "chatFlechas") == false, "las flechas no vienen apagadas de fábrica")
  A.Set("comodidades.chatFlechas", true)
  REVISA(ChatFrame1EditBox.alfaModo == false, "encendido, la caja sigue pidiendo Alt")
  A.Set("comodidades.chatFlechas", false)
  REVISA(ChatFrame1EditBox.alfaModo == true, "al apagarlo no volvió como estaba")
end)

PASO("6. «Copiar el nombre» en el clic derecho", function()
  local raiz = abrirMenu("MENU_UNIT_FRIEND", { name = "Ana" })
  local b = boton(raiz, "Copiar el nombre")
  REVISA(b, "el menú de un nombre del chat no trae «Copiar el nombre»")
  if not b then return end
  REVISA(raiz.divisores == 1, "lo de Alfa en el menú lleva " .. raiz.divisores .. " líneas (debe ser una sola)")
  local copiado
  con(A.UI, { ShowCopy = function(titulo, t) copiado = t end }, function() b.fn() end)
  REVISA(copiado == "Ana", "no abrió el cuadro de copiar con el nombre: " .. tostring(copiado))
  A.Set("comodidades.copiarNombre", false)
  REVISA(not boton(abrirMenu("MENU_UNIT_FRIEND", { name = "Ana" }), "Copiar el nombre"), "apagado, siguió en el menú")
  A.Set("comodidades.copiarNombre", true)
end)

PASO("7. «Tu amigo» en el cuadro", function()
  local Cu = CO.Cuadro
  REVISA(Cu and Cu.LineaAmigo, "el cuadro no sabe decir «Tu amigo»")
  if not (Cu and Cu.LineaAmigo) then return end
  local lineas = {}
  con(A.Hooks, { AddLine = function(_, t) lineas[#lineas + 1] = t end }, function()
    con(_G, { UnitIsPlayer = function() return true end, UnitIsUnit = function() return false end,
      UnitGUID = function() return "Player-1-A" end, UnitName = function() return "Ana" end }, function()
      Cu.Lineas(GameTooltip, "mouseover")
    end)
  end)
  REVISA(hay(lineas, "Tu amigo: «la del tanque»"), "el cuadro de Ana no dice «Tu amigo» con su nota: " .. table.concat(lineas, " | "))
end)

PASO("8. «Avisarme cuando se conecte»", function()
  local Vi = MN.Vigilar
  REVISA(Vi, "no existe Manada/Vigilar.lua")
  if not Vi then return end
  local b = boton(abrirMenu("MENU_UNIT_FRIEND", { name = "Ana" }), "Avisarme cuando se conecte")
  REVISA(b, "el menú no trae «Avisarme cuando se conecte»")
  if not b then return end
  local _, chat = mirar(function() b.fn() end)
  REVISA(Vi.Esta("Ana"), "no la anotó")
  REVISA(hay(chat, "te aviso cuando Ana se conecte"), "no dijo que la vigila")
  REVISA(boton(abrirMenu("MENU_UNIT_FRIEND", { name = "Ana" }), "Ya no avisarme cuando se conecte"), "el menú no ofrece quitarla")
  local avisos = mirar(function() FIRE_EVENT("CHAT_MSG_SYSTEM", "|Hplayer:Ana|h[Ana]|h se ha conectado.") end)
  local a = avisos[1]
  REVISA(a and a.titulo == "Ana se conectó", "al conectarse Ana no salió el aviso")
  if a then
    REVISA(a.acciones and a.acciones[1].texto == "Susurrar" and a.acciones[2].texto == "Invitar", "el aviso no trae Susurrar e Invitar")
    INVITADOS = {}
    a.acciones[2].alClic()
    REVISA(invitado("Ana"), "«Invitar» del aviso no invitó")
  end
  local otra = mirar(function() FIRE_EVENT("CHAT_MSG_SYSTEM", "|Hplayer:Beto|h[Beto]|h se ha conectado.") end)
  REVISA(#otra == 0, "avisó de alguien que no vigilas")
  REVISA(hay(Vi.YaConectados(), "Ana"), "al entrar no sabe que Ana ya estaba conectada")
  local _, chat2 = mirar(function() Vi.Poner("Zed", true) end)
  REVISA(hay(chat2, "solo me avisa de tus amigos"), "con un desconocido no explicó que el juego no avisa")
  local _, lista = mirar(function() A.RunCommand("avisame") end)
  REVISA(hay(lista, "Ana") and hay(lista, "Zed"), "/alfa avisame no dice a quién vigilas")
  mirar(function() A.RunCommand("avisame Zed") end)
  REVISA(not Vi.Esta("Zed"), "/alfa avisame Zed no lo quitó")
end)

-- Tu grupo: Ceci (sacerdotisa 25) en Las Minas de la Muerte.
local GRUPO = {
  IsInGroup = function() return true end, IsInRaid = function() return false end,
  UnitExists = function(u) return u == "party1" end, UnitIsPlayer = function(u) return u == "party1" end,
  UnitIsUnit = function() return false end, UnitName = function(u) if u == "party1" then return "Ceci" end end,
  UnitClass = function(u) if u == "party1" then return "Sacerdotisa", "PRIEST" end end,
  UnitLevel = function(u) if u == "party1" then return 25 end end,
  IsInInstance = function() return true end, GetInstanceInfo = function() return "Las Minas de la Muerte" end,
}

PASO("9. con quién cazaste", function()
  local Cp = MN.Companeros
  REVISA(Cp, "no existe Manada/Companeros.lua")
  if not Cp then return end
  con(_G, GRUPO, function()
    FIRE_EVENT("GROUP_ROSTER_UPDATE")
    TIEMPO(4)
  end)
  local x = Cp.De("Ceci")
  REVISA(x and x.zona == "Las Minas de la Muerte" and x.nivel == 25 and x.veces == 1, "no anotó a Ceci con su nivel y dónde cazaron")
  -- Sale del grupo y vuelve otro día: dos veces.
  con(_G, { IsInGroup = function() return false end }, function() Cp.Anotar() end)
  con(_G, GRUPO, function() Cp.Anotar() end)
  x = Cp.De("Ceci")
  REVISA(x and x.veces == 2, "no cuenta las veces que cazaron juntos")
  A.RunCommand("companeros")
  TIEMPO(1)
  REVISA(Cp.Visible(), "/alfa companeros no abrió la ventana")
  local t = Cp.Tarjetas()[1]
  REVISA(t and t.titulo:find("Ceci", 1, true) and t.texto:find("Sacerdotisa 25", 1, true), "la tarjeta de Ceci no dice quién es")
  if t then
    INVITADOS = {}
    t.accion.alClic()
    REVISA(invitado("Ceci"), "«Invitar» de la tarjeta no invitó")
    ABIERTO = nil
    t.secundaria.alClic()
    REVISA(ABIERTO and ABIERTO:find("/w Ceci", 1, true), "«Susurrar» no abrió la caja")
  end
  local v = Cp.Ventana()
  if v and v.Cerrar then v:Cerrar() elseif v then v:Hide() end
end)

PASO("10. te invita alguien con quien ya cazaste", function()
  local avisos = mirar(function()
    FIRE_EVENT("PARTY_INVITE_REQUEST", "Ceci", false, false, false, true, false, false, "Player-1-C", false)
  end)
  local a = avisos[1]
  REVISA(a and a.titulo == "Te invita Ceci" and a.texto:find("Las Minas de la Muerte", 1, true), "el aviso no recuerda con quién cazaste")
  local otro = mirar(function()
    FIRE_EVENT("PARTY_INVITE_REQUEST", "Ana", false, false, false, true, false, false, "Player-1-A", false)
  end)
  REVISA(#otro == 0, "avisó de una amiga (a esa ya la conoces)")
end)

PASO("las páginas abren sin errores", function()
  N.Abrir("comodidades") TIEMPO(1)
  N.Abrir("manada") TIEMPO(1)
  if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end
end)

-- Siempre al final: nada de Alfa se queda tapando el ratón.
PASO("el ratón sigue siendo del jugador", function() TIEMPO(5) RATON_LIMPIO("al final") end)

PRUEBA_FIN()
