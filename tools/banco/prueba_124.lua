-- Prueba de la 1.2.4 (tools/prueba.py la corre con las demás prueba_*.lua):
--   * el aviso de viaje (Nav/Alerts.lua) habla con la voz de La Jauría: «La
--     manada viaja», el lobo en el aro, el transporte en su chapita y una
--     huellita que camina sobre la barra de tiempo;
--   * la tarjeta de raros (Rares/Toast.lua): Lya la olfateó, con «Ir de caza»,
--     «Su ficha» y «Seleccionarlo»; el tesoro dice «Ir por él»;
--   * ninguno de sus textos se sale de la tarjeta;
--   * el fundador del aviso es Toxic Darunia, no el de Polestar.
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
local function T(n) RUN_TIMERS(n or 2) end
local function check(cond, msg) if not cond then NOTE("1.2.4", msg) end end

local ns = NS_OF("Alfa")
local medidos = 0

-- Los textos a la vista dentro de un marco (y sus hijos).
local function textos(f)
  local out = {}
  local function ver(x)
    for _, h in ipairs(rawget(x, "_children") or {}) do
      if h._kind == "FontString" and h:IsShown() and type(h._text) == "string" and h._text ~= "" then
        out[#out + 1] = h
      end
      ver(h)
    end
  end
  ver(f)
  return out
end
local function tiene(f, texto)
  for _, fs in ipairs(textos(f)) do if fs._text == texto then return true end end
  return false
end
local function dentro(f, quien)
  local fl, fr = f:GetLeft(), f:GetRight()
  check(fl and fr, quien .. ": la tarjeta no tiene lugar en la pantalla")
  check(#textos(f) >= 3, quien .. ": la tarjeta casi no tiene textos")
  if not (fl and fr) then return end
  for _, fs in ipairs(textos(f)) do
    local l, r = fs:GetLeft(), fs:GetRight()
    local w = fs.GetStringWidth and fs:GetStringWidth() or 0
    if l and r then
      medidos = medidos + 1
      check(l >= fl - 0.5 and l + w <= fr + 0.5, quien .. ": «" .. fs._text .. "» se sale de la tarjeta")
    end
  end
end

step("El aviso de viaje habla como La Jauría", function()
  local Al = ns.Nav and ns.Nav.alerts
  check(Al and Al.ShowSample, "no está el aviso de viaje")
  Al.ShowSample()
  T(1)
  local f = _G.AlfaAlert
  check(f and f:IsShown(), "el aviso de muestra no salió")
  check(tiene(f, "La manada viaja"), "falta «La manada viaja»")
  check(tiene(f, "El barco a Puerto de Menethil ya viene") or tiene(f, "El barco a Menethil Harbor ya viene"),
    "el título del barco no es el nuevo")
  local hay = false
  for _, fs in ipairs(textos(f)) do if fs._text:find("^Prepárate: llega en ") then hay = true end end
  check(hay, "falta la cuenta «Prepárate: llega en …»")
  check(f.Paw and f.Paw:IsShown(), "falta la huellita sobre la barra")
  check(f.Badge and f.Badge:IsShown(), "falta la chapita del barco")
  dentro(f, "viaje")
  -- Un aviso propio del motor (sin cuenta) no lleva la línea de La Jauría.
  Al.ShowNotice("Aviso", "Una línea", 5)
  check(not f.Kicker:IsShown(), "el aviso del motor muestra «La manada viaja»")
  f:Hide()
end)

step("La tarjeta de raros: Lya lo olfateó", function()
  local Tt = ns.Rares and ns.Rares.Toast
  check(Tt and Tt.Show, "no está la tarjeta de raros")
  Tt.Show({ kind = "rare", id = 61, name = "Thuros Dedosligeros", level = 29, zone = "Bosque de Elwynn",
    map = 1429, x = 0.5, y = 0.5, yards = 85 })
  local f = _G.AlfaRareToast
  check(f and f:IsShown(), "la tarjeta no salió")
  check(tiene(f, "Lya olfateó un raro"), "falta «Lya olfateó un raro»")
  check(tiene(f, "Ir de caza"), "falta «Ir de caza»")
  check(tiene(f, "Su ficha"), "falta «Su ficha»")
  check(not tiene(f, "Fijar punto de ruta") and not tiene(f, "Set waypoint"), "sigue el botón viejo")
  dentro(f, "raro")
  Tt.Show({ kind = "treasure", id = 9, name = "Cofre maltrecho", zone = "Bosque de Elwynn",
    map = 1429, x = 0.4, y = 0.4, yards = 40 })
  check(tiene(f, "Lya encontró un tesoro"), "falta «Lya encontró un tesoro»")
  check(tiene(f, "Ir por él"), "el tesoro no dice «Ir por él»")
  dentro(f, "tesoro")
  Tt.Hide()
end)

step("El fundador es Toxic", function()
  local R = ns.Rares
  check(R.FOUNDER == "Toxic Darunia", "el fundador es " .. tostring(R.FOUNDER))
  check(R.IsFounder("Toxic Darunia") and R.IsFounder("Toxic Darunia-Reino"), "no reconoce a Toxic")
  check(not R.IsFounder("Fitz Alfa"), "todavía reconoce al de Polestar")
end)

-- Guaridas (Alfa_Manada/Guaridas.lua): la capa sale del identificador de las
-- criaturas, la manada dice la suya, y pedir entrar pasa por un susurro que
-- el anfitrión contesta invitando.
step("Guaridas: tu capa, las de la manada y pedir entrar", function()
  local MN = NS_OF("Alfa_Manada")
  local Gu, R = MN.Guaridas, MN.Red
  local N = AlfaNucleo
  check(Gu and Gu.DeGuid, "no está Guaridas.lua")
  check(Gu.DeGuid("Creature-0-5250-0-7994-299-0000ABCDEF") == 7994, "no lee la capa de una criatura")
  check(Gu.DeGuid("Player-1-0001") == nil, "leyó una capa de un jugador")
  check(Gu.DeGuid(nil) == nil and Gu.DeGuid("Creature-0-1-0-0-1-1") == nil, "aceptó una capa vacía")
  check(Gu.Nombre(7994):find("^Guarida ") ~= nil, "el nombre no es «Guarida …»: " .. tostring(Gu.Nombre(7994)))

  N.Set("manada", "compartir", true)
  R.Escuchar() -- (Manada.lua lo hace al entrar al juego)
  local viaVieja = R.Via
  R.Via = function() return "hermandad" end
  local salidos = {}
  local envioViejo = C_ChatInfo.SendAddonMessage
  C_ChatInfo.SendAddonMessage = function(pre, texto, canal, destino) table.insert(salidos, { texto, canal, destino }) end
  -- La cola de Red.lua sale en su OnUpdate (un mensaje por segundo).
  local function T(n)
    RUN_TIMERS(n or 2)
    for _ = 1, 60 do FIRE(R.motor, "OnUpdate", 0.2) end
  end
  local function salio(patron, canal)
    for _, m in ipairs(salidos) do if m[1]:find(patron) and (not canal or m[2] == canal) then return m end end
  end

  -- Tu capa: una placa de nombre con una criatura.
  local guid = { nameplate1 = "Creature-0-5250-0-7994-299-0000ABCDEF" }
  local ue, ug = UnitExists, UnitGUID
  UnitExists = function(u) return u == "player" or guid[u] ~= nil end
  UnitGUID = function(u) return guid[u] or "Player-1-0001" end
  FIRE_EVENT("NAME_PLATE_UNIT_ADDED", "nameplate1")
  local mia = Gu.Actual()
  check(mia and mia.capa == 7994, "no supo tu guarida por la placa de nombre")
  local map = mia and mia.map or 1429
  T(3)
  check(salio("^1G|" .. map .. "|7994|0"), "no dijo tu guarida a la manada")

  -- La manada: dos en otra guarida, uno con la puerta abierta.
  local function llega(texto, canal, quien) FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", texto, canal, quien) end
  llega("1G|" .. map .. "|8001|1", "GUILD", "Ana Smith")
  llega("1G|" .. map .. "|8001|0", "GUILD", "Beto Ruiz")
  llega("1G|" .. map .. "|nan|1", "GUILD", "Malo Malo")
  llega("1G|99|8002|1", "GUILD", "Lejos Lejano")
  local lista = Gu.Lista()
  check(#lista == 2 and lista[1].mia and lista[2].capa == 8001, "la lista de guaridas no es la tuya y la 8001")
  check(lista[2] and lista[2].gente == 2 and lista[2].abiertas == 1, "la 8001 no cuenta 2 lobos y 1 puerta abierta")

  -- Pedir entrar: susurro a Ana.
  local ok = Gu.Pedir(8001)
  -- Solo la cola: los relojes del banco corren sin esperar y el de 8 s ya
  -- daría por perdido el pedido.
  for _ = 1, 60 do FIRE(R.motor, "OnUpdate", 0.2) end
  check(ok, "no dejó pedir entrar")
  local q = salio("^1Q|" .. map .. "|8001", "WHISPER")
  check(q and tostring(q[3]):find("Ana") ~= nil, "no le pidió entrar a Ana por susurro")
  llega("1R|ok", "WHISPER", "Ana Smith")
  check(Gu.Pedido() and Gu.Pedido().invitado, "no tomó el sí de Ana")
  -- El juego te pasa: la placa dice la 8001.
  guid.nameplate1 = "Creature-0-5250-0-8001-299-0000ABCDEF"
  FIRE_EVENT("NAME_PLATE_UNIT_ADDED", "nameplate1")
  check(Gu.Actual().capa == 8001 and Gu.Pedido() == nil, "al llegar no cerró el pedido")

  -- Anfitrión: cerrada no invita; abierta, invita.
  local invitados = {}
  local inv = C_PartyInfo and C_PartyInfo.InviteUnit
  C_PartyInfo = C_PartyInfo or {}
  C_PartyInfo.InviteUnit = function(n) table.insert(invitados, n) end
  llega("1Q|" .. map .. "|8001", "WHISPER", "Caro Diaz")
  T(3)
  check(#invitados == 0 and salio("^1R|no|cerrada", "WHISPER"), "con la guarida cerrada invitó o no dijo que no")
  Gu.Abrir(true)
  llega("1Q|" .. map .. "|8001", "WHISPER", "Dani Paz")
  T(3)
  check(#invitados == 1 and salio("^1R|ok", "WHISPER"), "con la guarida abierta no invitó")
  llega("1Q|" .. map .. "|7994", "WHISPER", "Eli Gil")
  T(3)
  check(#invitados == 1, "invitó a alguien que pedía otra guarida")
  Gu.Abrir(false)

  C_PartyInfo.InviteUnit = inv
  UnitExists, UnitGUID = ue, ug
  C_ChatInfo.SendAddonMessage = envioViejo
  R.Via = viaVieja
  N.Set("manada", "compartir", false)
end)

-- El asistente visual (Alfa_Bienvenida): 7 pasos sin listas a la vista,
-- y los perfiles escriben los ajustes de un clic.
step("El asistente: pocos pasos y tres perfiles", function()
  local B = NS_OF("Alfa_Bienvenida")
  local A = AlfaNucleo.A
  B.AbrirVentana("asistente")
  RUN_TIMERS(2)
  local v = _G.AlfaBienvenidaVentana
  local a = v and v.alfaAsistente
  check(a and a.pasos, "no se abrió el asistente")
  local ids = {}
  for i, p in ipairs(a.pasos) do ids[i] = p.id end
  local lista = table.concat(ids, ",")
  check(#a.pasos <= 7, "el asistente tiene " .. #a.pasos .. " pasos: " .. lista)
  check(lista:find("perfil", 1, true) and lista:find("extras", 1, true), "faltan los pasos de perfil o extras: " .. lista)
  check(not lista:find("misiones", 1, true), "sigue la pantalla de la lista de misiones: " .. lista)
  -- Cada paso se arma sin error.
  for i = 1, #a.pasos do a:Ir(i) end
  RUN_TIMERS(2)
  B.AplicarPerfil("yo")
  check(A.Get("behavior.autoAccept") == false and A.Get("qol.sellJunk") == true, "«Yo decido» no dejó solo lo mínimo")
  B.AplicarPerfil("manada")
  check(A.Get("behavior.autoAccept") == true and A.Get("qol.flightAutoTake") == true, "«Alfa lo hace por ti» no prendió todo")
  B.AplicarPerfil("equilibrio")
  check(A.Get("behavior.autoAccept") == true and A.Get("qol.flightAutoTake") == false, "«Equilibrado» no quedó a medias")
  v:Cerrar()
end)

-- «Pregúntale a Lya»: responde, lleva y conoce todas las páginas.
step("Pregúntale a Lya", function()
  local Ly = NS_OF("Alfa_Lya")
  check(Ly.Guia and Ly.Guia.Abrir, "no está la guía de Lya")
  -- (en el banco la configuración sigue pendiente: la puerta se abre a mano)
  local permitido = AlfaNucleo.Permitido
  AlfaNucleo.Permitido = function() return true end
  Ly.Guia.Abrir("guaridas")
  AlfaNucleo.Permitido = permitido
  RUN_TIMERS(2)
  local v = _G.AlfaLyaGuia
  check(v and v:IsShown(), "no se abrió «Pregúntale a Lya»")
  if not v then return end
  local hay, tarjetas = false, 0
  local function ver(x) for _, h in ipairs(rawget(x, "_children") or {}) do
    if h._kind == "FontString" and h:IsShown() and type(h._text) == "string" then
      if h._text:find("Pedir entrar", 1, true) then hay = true end
    end
    ver(h) end end
  ver(v)
  check(hay, "Lya no respondió lo de las guaridas")
  check(AlfaLya.Guia and AlfaLya.Ensenar, "falta AlfaLya.Guia o AlfaLya.Ensenar")
  check(AlfaLya.Ensenar({ id = "prueba", pregunta = "¿Una prueba?", respuesta = "Sí, una prueba." }), "no aprendió una pregunta nueva")
  v:Cerrar()
end)

check(medidos >= 8, "se midieron muy pocos textos: " .. medidos)
print(string.format("PRUEBA: 1.2.4 avisos de La Jauría, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
