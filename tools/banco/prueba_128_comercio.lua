-- Prueba de la 1.2.8, el buzón, el oro de la sesión y las bolsas casi llenas:
--   * el buzón: «Tomar todo» toma dinero y objetos carta por carta, se salta
--     las de pago contra entrega y las de un MJ, se detiene al llenarse las
--     bolsas o al cerrar el buzón, y dice qué recibiste; el aviso de cartas
--     con objetos que vencen en menos de 3 días;
--   * AlfaBolsas.Sesion(): lo ganado, lo gastado, el neto y por hora;
--   * bolsas casi llenas: el aviso con lo primero que puedes soltar, «Vender»
--     con el comerciante y «Ver bolsas» sin él, uno cada 10 minutos salvo al
--     llegar a 0.
-- Las funciones del buzón y de las bolsas son de mentira y viven aquí.
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
local function check(cond, msg) if not cond then NOTE("1.2.8 comercio", msg) end end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit

---------------------------------------------------------------------------
-- El juego de mentira: dinero, bolsas y buzón
---------------------------------------------------------------------------

local dinero = 100000
GetMoney = function() return dinero end
local function cambiarDinero(d)
  dinero = dinero + d
  FIRE_EVENT("PLAYER_MONEY")
end

-- Bolsas: la mochila (0) con 16 casillas; `ocupadas` dice cuántas hay llenas.
local CHATARRA = 4865 -- Garra rota (gris)
local bolsa = {}
local function llenar(ocupadas)
  for s = 1, 16 do bolsa[s] = nil end
  for s = 1, ocupadas do
    bolsa[s] = s == 1 and { itemID = CHATARRA, stackCount = 3, quality = 0, hyperlink = "|cff9d9d9d|Hitem:4865::::::::|h[Garra rota]|h|r" }
      or { itemID = 2589, stackCount = 1, quality = 1, hyperlink = "|cffffffff|Hitem:2589::::::::|h[Lino]|h|r", hasNoValue = true }
  end
end
local function libres() local n = 0 for s = 1, 16 do if not bolsa[s] then n = n + 1 end end return n end
local usados = {}
C_Container = {
  GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end,
  GetContainerNumFreeSlots = function(b) if b == 0 then return libres(), 0 end return 0, 0 end,
  CalculateTotalNumberOfFreeBagSlots = function() return libres() end,
  GetContainerItemInfo = function(b, s) if b ~= 0 then return nil end return bolsa[s] end,
  GetContainerItemQuestInfo = function() return { isQuestItem = false } end,
  GetContainerItemLink = function(b, s) local i = b == 0 and bolsa[s] return i and i.hyperlink end,
  GetContainerItemID = function(b, s) local i = b == 0 and bolsa[s] return i and i.itemID end,
  UseContainerItem = function(b, s) usados[#usados + 1] = { b, s } if b == 0 then bolsa[s] = nil end end,
  ContainerIDToInventoryID = function(b) return b + 19 end,
  GetBagName = function() return nil end,
}
local itemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id)
  id = tonumber(tostring(id):match("item:(%d+)") or id)
  if id == CHATARRA then return "Garra rota", "link", 0, 5, 1, "Chatarra", "Chatarra", 20, "", 134400, 25, 15, 0 end
  if id == 2589 then return "Lino", "link", 1, 5, 1, "Objeto comerciable", "Tela", 20, "", 134400, 0, 7, 5 end
  return itemInfo(id)
end
GetItemInfo = C_Item.GetItemInfo
C_Item.GetItemInfoInstant = function(id)
  id = tonumber(tostring(id):match("item:(%d+)") or id)
  if id == CHATARRA then return id, "Chatarra", "Chatarra", "", 134400, 15, 0 end
  if id == 2589 then return id, "Tela", "Tela", "", 134400, 7, 5 end
  return nil
end

-- El buzón: cada carta { remitente, dinero, cod, dias, mj, objetos = { {id, cantidad} } }.
local cartas = {}
local tomasDinero, tomasObjeto = 0, 0
local function evento(ev) C_Timer.After(0, function() FIRE_EVENT(ev) end) end
local function quitarSiVacia(i)
  local c = cartas[i]
  if c and c.dinero == 0 and #c.objetos == 0 then table.remove(cartas, i) end
end
GetInboxNumItems = function() return #cartas, #cartas end
GetInboxHeaderInfo = function(i)
  local c = cartas[i]
  if not c then return nil end
  return "icono", nil, c.remitente, "Asunto", c.dinero, c.cod or 0, c.dias or 30, #c.objetos, false, false, false, true, c.mj or false
end
GetInboxItem = function(i, a)
  local c = cartas[i]
  local o = c and c.objetos[a]
  if not o then return nil end
  return "Objeto " .. o[1], o[1], 134400, o[2], 1, true
end
HasInboxItem = function(i, a) local c = cartas[i] return c and c.objetos[a] ~= nil or false end
TakeInboxMoney = function(i)
  local c = cartas[i]
  if not c or c.dinero <= 0 then return end
  tomasDinero = tomasDinero + 1
  cambiarDinero(c.dinero)
  c.dinero = 0
  quitarSiVacia(i)
  evento("MAIL_INBOX_UPDATE")
end
TakeInboxItem = function(i, a)
  local c = cartas[i]
  if not (c and c.objetos[a]) then return end
  if libres() == 0 then evento("MAIL_FAILED") return end
  tomasObjeto = tomasObjeto + 1
  for s = 1, 16 do if not bolsa[s] then bolsa[s] = { itemID = c.objetos[a][1], stackCount = c.objetos[a][2], quality = 1 } break end end
  table.remove(c.objetos, a)
  quitarSiVacia(i)
  evento("MAIL_INBOX_UPDATE")
end
AutoLootMailItem = function(i) end
C_Mail = { IsCommandPending = function() return false end, SetOpeningAll = function() end, HasInboxMoney = function(i) local c = cartas[i] return c and c.dinero > 0 or false end }
ATTACHMENTS_MAX_RECEIVE = 16
MailFrame = CreateFrame("Frame", "MailFrame", UIParent)
MailFrame:SetSize(384, 512)
MailFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -100)

-- Los avisos se anotan en lugar de verse.
local avisos = {}
local avisoReal = K.Aviso
K.Aviso = function(o) avisos[#avisos + 1] = o return {} end
local function ultimo() return avisos[#avisos] end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)
A.Set("qol.sellJunk", false)

local C = NS_OF("Alfa_Comercio")
local B = NS_OF("Alfa_Bolsas")
local Bz = C.Buzon

---------------------------------------------------------------------------
-- 13. El buzón
---------------------------------------------------------------------------

step("El buzón: barra y aviso de cartas que vencen", function()
  check(Bz and Bz.Tomar, "falta Buzon.lua") if not Bz then return end
  check(A.Get("comercio.buzon") == true and A.Get("comercio.buzonVence") == true, "los ajustes del buzón no vienen prendidos")
  llenar(4)
  cartas = {
    { remitente = "Subasta", dinero = 120000, objetos = {} },
    { remitente = "Alt", dinero = 0, dias = 2.5, objetos = { { 2589, 20 }, { 2592, 5 } } },
    { remitente = "Vendedor", dinero = 0, cod = 5000, objetos = { { 2318, 1 } } },
    { remitente = "MJ", dinero = 0, mj = true, objetos = { { 6948, 1 } } },
    { remitente = "Amigo", dinero = 5000, dias = 0.4, objetos = { { 2770, 10 } } },
  }
  avisos = {}
  FIRE_EVENT("MAIL_SHOW")
  FIRE_EVENT("MAIL_INBOX_UPDATE")
  RUN_TIMERS(2)
  local n, menor = Bz.Vencen()
  check(n == 2 and menor and menor < 1, "no contó bien las cartas que vencen (" .. tostring(n) .. ")")
  local hay
  for _, a in ipairs(avisos) do if a.titulo and a.titulo:find("vencen pronto", 1, true) then hay = a end end
  check(hay, "no avisó de las cartas que vencen")
  check(hay and hay.texto:find("menos de un día", 1, true), "el aviso no dice cuándo vence la primera")
  check(hay and hay.accion and hay.accion.texto == "Tomar todo", "el aviso no trae «Tomar todo»")
  local vistos = #avisos
  FIRE_EVENT("MAIL_INBOX_UPDATE")
  RUN_TIMERS(2)
  check(#avisos == vistos, "avisó otra vez de lo mismo en la misma visita")
end)

step("El buzón: Tomar todo, sin las de contra entrega ni las del MJ", function()
  avisos = {}
  local antes = dinero
  check(Bz.Tomar(), "Tomar todo no empezó")
  check(Bz.Tomando(), "no está tomando")
  RUN_TIMERS(40)
  check(not Bz.Tomando(), "no terminó")
  check(dinero - antes == 125000, "no tomó todo el dinero (" .. (dinero - antes) .. ")")
  check(tomasObjeto == 3, "no tomó los 3 objetos (" .. tomasObjeto .. ")")
  check(#cartas == 2, "quedaron cartas que debía vaciar (" .. #cartas .. ")")
  for _, c in ipairs(cartas) do check((c.cod or 0) > 0 or c.mj, "tomó de una carta que se abre a mano") end
  local a = ultimo()
  check(a and a.titulo == "El buzón", "no dijo qué recibiste")
  check(a and a.texto:find("Recibiste 35 piezas", 1, true), "el resumen no cuenta los objetos: " .. tostring(a and a.texto))
  check(a and a.texto:find("Dejé 2 cartas", 1, true), "el resumen no dice las cartas que dejó")
end)

step("El buzón: se detiene si se llenan las bolsas", function()
  avisos = {}
  tomasObjeto = 0
  llenar(15)
  cartas = {
    { remitente = "Alt", dinero = 0, objetos = { { 2589, 1 }, { 2592, 1 }, { 2770, 1 } } },
    { remitente = "Subasta", dinero = 3000, objetos = {} },
  }
  local antes = dinero
  Bz.Tomar()
  RUN_TIMERS(40)
  check(not Bz.Tomando(), "no terminó con las bolsas llenas")
  check(tomasObjeto == 1, "tomó más objetos de los que caben (" .. tomasObjeto .. ")")
  check(dinero - antes == 3000, "con las bolsas llenas dejó el dinero")
  local a = ultimo()
  check(a and a.texto:find("se llenaron", 1, true), "no dijo que las bolsas se llenaron")
end)

step("El buzón: cerrar a medias y nada en combate", function()
  llenar(2)
  cartas = {}
  for i = 1, 5 do cartas[i] = { remitente = "Alt", dinero = 0, objetos = { { 2589, 1 }, { 2592, 1 } } } end
  avisos = {}
  tomasObjeto = 0
  Bz.Tomar()
  RUN_TIMERS(1)
  FIRE_EVENT("MAIL_CLOSED")
  RUN_TIMERS(10)
  check(not Bz.Tomando(), "siguió tomando con el buzón cerrado")
  check(tomasObjeto < 10, "tomó todo aunque se cerró el buzón")
  local a = ultimo()
  check(a and a.texto:find("Se cerró el buzón", 1, true), "no dijo que se cerró el buzón")
  check(not Bz.Tomar(), "tomó con el buzón cerrado")
  FIRE_EVENT("MAIL_SHOW")
  local combate = InCombatLockdown
  InCombatLockdown = function() return true end
  check(not Bz.Tomar(), "tomó en combate")
  InCombatLockdown = combate
  A.Set("comercio.buzon", false)
  RUN_TIMERS(1)
  A.Set("comercio.buzon", true)
  FIRE_EVENT("MAIL_CLOSED")
end)

---------------------------------------------------------------------------
-- 14. El oro de la sesión
---------------------------------------------------------------------------

step("El oro de la sesión: AlfaBolsas.Sesion()", function()
  check(type(AlfaBolsas) == "table" and type(rawget(AlfaBolsas, "Sesion")) == "function", "falta AlfaBolsas.Sesion")
  local s0 = AlfaBolsas.Sesion()
  check(type(s0.oro) == "number" and type(s0.segundos) == "number" and type(s0.porHora) == "number", "Sesion() no trae oro, segundos y porHora")
  local g0 = s0.ganado
  NOW = NOW + 1800
  cambiarDinero(20000)
  cambiarDinero(-5000)
  local s = AlfaBolsas.Sesion()
  check(s.ganado - g0 == 20000, "no sumó lo ganado (" .. (s.ganado - g0) .. ")")
  check(s.gastado >= 5000, "no sumó lo gastado")
  -- 1.3.2: el oro de las cartas de arriba va aparte (correo), pero sí cuenta en el neto.
  check(s.oro == s.ganado + (s.correo or 0) - s.gastado, "el neto no es lo ganado más lo del buzón menos lo gastado")
  check(s.porHora > 0 and s.porHora == math.floor(s.ganado * 3600 / s.segundos), "por hora no sale de lo ganado")
  local t = B.Sesion.Texto()
  check(t and t:find("Esta sesión: +", 1, true) and t:find("por hora", 1, true), "el texto de la sesión no sale: " .. tostring(t))
  local lineas = B.Sesion.Lineas()
  check(#lineas >= 4, "el cuadro de la sesión trae pocas líneas")
end)

---------------------------------------------------------------------------
-- 15. Bolsas casi llenas
---------------------------------------------------------------------------

local S = B.Sugerencias
local function bolsasCambian()
  S.Invalidar()
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(3)
end
local function avisosCasi()
  local n = 0
  for _, a in ipairs(avisos) do if a.titulo and a.titulo:find("Tus bolsas están", 1, true) then n = n + 1 end end
  return n
end

step("Bolsas casi llenas: aviso con lo primero que puedes soltar", function()
  -- 1.3.3: una sola voz. Si Lya (o Hoy) ya dijo «bolsasLlenas» en la sesión,
  -- Bolsas no lo repite: esta prueba parte sin nada dicho.
  rawset(AlfaNucleo, "dichosSesion", {})
  check(A.Get("bolsas.avisoCasiLleno") == true, "el ajuste avisoCasiLleno no viene prendido")
  avisos = {}
  llenar(10)
  bolsasCambian()
  check(avisosCasi() == 0, "avisó de bolsas casi llenas con 6 casillas libres")
  llenar(14)
  bolsasCambian()
  check(avisosCasi() == 1, "no avisó con 2 casillas libres (" .. avisosCasi() .. ")")
  local a = ultimo()
  check(a and a.titulo == "Tus bolsas están casi llenas", "el título no es «Tus bolsas están casi llenas»")
  check(a and a.texto:find("Garra rota", 1, true), "no dice lo primero que puedes soltar: " .. tostring(a and a.texto))
  check(a and a.accion and a.accion.texto == "Ver bolsas", "sin comerciante, el botón no es «Ver bolsas»")
  if a and a.accion then a.accion.alClic() end
  check(B.Ventana.BolsasVisibles(), "«Ver bolsas» no abrió las bolsas")
  B.Ventana.MostrarBolsas(false)
  -- Sin avisos repetidos durante 10 minutos...
  llenar(15)
  bolsasCambian()
  check(avisosCasi() == 1, "avisó otra vez antes de 10 minutos")
  -- ...salvo al llegar a 0.
  llenar(16)
  bolsasCambian()
  check(avisosCasi() == 2, "no avisó al quedarse sin casillas")
  check(ultimo().titulo == "Tus bolsas están llenas", "con 0 casillas el título no es «Tus bolsas están llenas»")
  llenar(16)
  bolsasCambian()
  check(avisosCasi() == 2, "avisó dos veces de las bolsas llenas")
end)

step("Bolsas casi llenas: «Vender» con el comerciante", function()
  rawset(AlfaNucleo, "dichosSesion", {})
  avisos = {}
  usados = {}
  NOW = NOW + 700
  llenar(14)
  FIRE_EVENT("MERCHANT_SHOW")
  RUN_TIMERS(3)
  local a
  for _, x in ipairs(avisos) do if x.titulo == "Tus bolsas están casi llenas" then a = x end end
  check(a, "no avisó con el comerciante abierto")
  check(a and a.accion and a.accion.texto == "Vender", "con el comerciante, el botón no es «Vender»")
  if a and a.accion then a.accion.alClic() end
  RUN_TIMERS(3)
  check(#usados == 1 and usados[1][2] == 1, "«Vender» no vendió la chatarra (" .. #usados .. ")")
  FIRE_EVENT("MERCHANT_CLOSED")
  RUN_TIMERS(2)
end)

step("Bolsas casi llenas: el ajuste lo apaga", function()
  rawset(AlfaNucleo, "dichosSesion", {})
  A.Set("bolsas.avisoCasiLleno", false)
  avisos = {}
  NOW = NOW + 700
  llenar(15)
  bolsasCambian()
  check(avisosCasi() == 0, "avisó con el ajuste apagado")
  A.Set("bolsas.avisoCasiLleno", true)
  -- Y nada en combate.
  local combate = InCombatLockdown
  InCombatLockdown = function() return true end
  NOW = NOW + 700
  llenar(14)
  bolsasCambian()
  check(avisosCasi() == 0, "avisó en combate")
  InCombatLockdown = combate
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  RUN_TIMERS(4)
  check(avisosCasi() == 1, "no avisó al salir del combate")
end)

step("La página de Bolsas y la ventana con la sesión", function()
  AlfaNucleo.Abrir("bolsas")
  RUN_TIMERS(3)
  B.Ventana.MostrarBolsas(true)
  RUN_TIMERS(3)
  B.Ventana.MostrarBolsas(false)
  AlfaNucleo.Abrir("comercio")
  RUN_TIMERS(3)
end)

K.Aviso = avisoReal
-- 1.3.0, error del juego real: «Tomar todo» pulsado antes de que lleguen las
-- cartas decía «No había nada que tomar» y ese texto se quedaba en la barra
-- aunque después se tomara todo.
step("El buzón: Tomar todo antes de que carguen las cartas", function()
  K.Aviso = function(o) avisos[#avisos + 1] = o return {} end
  FIRE_EVENT("MAIL_CLOSED")
  avisos = {}
  tomasObjeto = 0
  llenar(4)
  cartas = {
    { remitente = "Alt", dinero = 21669, objetos = { { 2589, 20 }, { 2592, 6 } } },
  }
  local cargadas = false
  local real = GetInboxNumItems
  GetInboxNumItems = function() if not cargadas then return 0, 0 end return #cartas, #cartas end
  FIRE_EVENT("MAIL_SHOW")
  local antes = dinero
  check(Bz.Tomar(), "Tomar todo no aceptó el clic mientras cargaba")
  RUN_TIMERS(5)
  for _, x in ipairs(avisos) do
    check(not (x.texto or ""):find("No había nada", 1, true), "dijo «No había nada que tomar» antes de que llegaran las cartas")
  end
  cargadas = true
  FIRE_EVENT("MAIL_INBOX_UPDATE")
  RUN_TIMERS(40)
  GetInboxNumItems = real
  check(dinero - antes == 21669, "no tomó el dinero al llegar las cartas (" .. (dinero - antes) .. ")")
  check(tomasObjeto == 2, "no tomó los objetos al llegar las cartas (" .. tomasObjeto .. ")")
  local u = ultimo()
  check(u and (u.texto or ""):find("Recibiste 26 piezas", 1, true), "el resumen no dice lo que llegó: " .. tostring(u and u.texto))
  K.Aviso = avisoReal
end)

print(string.format("PRUEBA: 1.2.8 buzón, sesión y bolsas llenas, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
