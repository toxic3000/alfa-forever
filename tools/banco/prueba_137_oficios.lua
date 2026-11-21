-- Prueba de la 1.3.7, oficios y personaje (Comercio, Talentos, Curación, Paisaje
-- y Recolección; tools/prueba.py la corre con las demás):
--   1. el separador de miles sigue al idioma (coma en español, punto en alemán);
--   2. el consejo no sale en la piedra de hogar, objetos de misión ni equipo
--      ligado, y dice lo que vale la pila («×20: ...»);
--   3. gangas: un precio un 30 % bajo lo de siempre se marca; el de siempre, no;
--   4. /alfa comercio precio <nombre> encuentra el objeto en tus bolsas;
--   5. «Guíame» dice el motivo del motor;
--   6. el escaneo (M.Tarea) espera al combate;
--   7. las recetas no se releen si la lista no cambió (TRADE_SKILL_LIST_UPDATE);
--   8. el buzón: «Tomar todo» enseña cómo va, dice «piezas», y «Parar» lo corta;
--   9. mandar a tu alt: la lista por comando, «Preparar» pone el nombre y
--      adjunta lo de la lista (el clic en Enviar no se toca);
--  10. Talentos: dos armas solo si puedes, importar dos veces no duplica, cortar
--      sin romper letras;
--  11. Curación: la venda que tu Primeros auxilios deja usar, el aviso sin
--      vendas, una línea en marcos bajos, «¿Listos?» con lo que falta y el
--      botón para dar tu apoyo;
--  12. Paisaje: «Deshacer» suelta lo que no elegiste y el reinicio de gráficos
--      solo se pide si de verdad cambió algo;
--  13. Recolección: mapa y minimapa dicen cuál cambió; los puntos del minimapa
--      no toman el ratón en combate;
--  14. ver el equipo de un compañero: nivel medio, piezas flojas y lo que le sirve.
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
local function check(cond, msg) if not cond then NOTE("1.3.7 oficios", msg) end end
local function T(n) RUN_TIMERS(n or 1) end

local N = AlfaNucleo
local A = N.A
local K = N.Kit

---------------------------------------------------------------------------
-- El juego simulado: bolsas, objetos, chat
---------------------------------------------------------------------------
local impreso = {}
local imprimirReal = N.Imprimir
N.Imprimir = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end impreso[#impreso + 1] = table.concat(t, " ") end
local function dijo(texto)
  for _, l in ipairs(impreso) do if l:find(texto, 1, true) then return true end end
  return false
end

-- Objetos: id -> { nombre, calidad, nivel, pila, equipLoc, venta, clase, subclase, ligado }
local OBJ = {
  [6948] = { "Piedra de hogar", 1, 1, 1, "", 0, 15, 0, 1 },
  [2589] = { "Lino", 1, 5, 20, "", 13, 7, 5, 0 },
  [765] = { "Hojaplata", 1, 5, 20, "", 5, 7, 9, 0 },
  [2447] = { "Flor de paz", 1, 5, 20, "", 5, 7, 9, 0 },
  [5000] = { "Carta de misión", 1, 5, 1, "", 0, 12, 0, 4 },
  [7000] = { "Coraza ligada", 2, 30, 1, "INVTYPE_CHEST", 500, 4, 4, 1 },
  [2581] = { "Venda de lino gruesa", 1, 10, 20, "", 10, 0, 7, 0 },
  [3530] = { "Venda de lana", 1, 20, 20, "", 20, 0, 7, 0 },
  [4540] = { "Pan duro", 1, 5, 20, "", 1, 0, 5, 0 },
  [8000] = { "Guantes de tela verde", 2, 30, 1, "INVTYPE_HAND", 300, 4, 1, 2 },
  [8001] = { "Guantes de placas", 2, 30, 1, "INVTYPE_HAND", 300, 4, 4, 2 },
}
local function enlace(id) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. OBJ[id][1] .. "]|h|r" end
local itemInfoReal = C_Item.GetItemInfo
C_Item.GetItemInfo = function(x)
  local id = tonumber(tostring(x):match("item:(%d+)") or x)
  local o = id and OBJ[id]
  if not o then return itemInfoReal(x) end
  return o[1], enlace(id), o[2], o[3], 1, "Tipo", "Subtipo", o[4], o[5], 134400, o[6], o[7], o[8], o[9]
end
GetItemInfo = C_Item.GetItemInfo
C_Item.GetItemInfoInstant = function(x)
  local id = tonumber(tostring(x):match("item:(%d+)") or x)
  if not id then
    for k, o in pairs(OBJ) do if o[1] == x then id = k end end
  end
  local o = id and OBJ[id]
  if not o then return nil end
  return id, "Tipo", "Subtipo", o[5], 134400, o[7], o[8]
end
C_Item.GetDetailedItemLevelInfo = function(x)
  local id = tonumber(tostring(x):match("item:(%d+)") or x)
  return id and OBJ[id] and OBJ[id][3] or nil
end

local bolsa = {}
local function poner(lista)
  for s = 1, 16 do bolsa[s] = nil end
  for s, e in ipairs(lista) do
    bolsa[s] = { itemID = e[1], stackCount = e[2] or 1, hyperlink = enlace(e[1]), isBound = e[3] == true, isLocked = false, quality = OBJ[e[1]][2] }
  end
end
local recogido -- lo que está en el cursor
C_Container = {
  GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end,
  GetContainerNumFreeSlots = function(b) if b ~= 0 then return 0, 0 end local n = 0 for s = 1, 16 do if not bolsa[s] then n = n + 1 end end return n, 0 end,
  CalculateTotalNumberOfFreeBagSlots = function() local n = 0 for s = 1, 16 do if not bolsa[s] then n = n + 1 end end return n end,
  GetContainerItemInfo = function(b, s) if b ~= 0 then return nil end return bolsa[s] end,
  GetContainerItemID = function(b, s) local i = b == 0 and bolsa[s] return i and i.itemID end,
  GetContainerItemLink = function(b, s) local i = b == 0 and bolsa[s] return i and i.hyperlink end,
  PickupContainerItem = function(b, s) recogido = { b, s } end,
  UseContainerItem = function() end,
}
CursorHasItem = function() return false end

local avisos = {}
local avisoReal = K.Aviso
K.Aviso = function(o) avisos[#avisos + 1] = o return {} end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(3)

local C = NS_OF("Alfa_Comercio")
-- Las tareas por lotes de Comercio (escaneo, recetas) las mueve su propio OnUpdate.
local function mover() if C.motorTareas and C.motorTareas:IsShown() then FIRE(C.motorTareas, "OnUpdate", 0.05) end end
local B = NS_OF("Alfa_Builds")
local Cu = NS_OF("Alfa_Curacion")
local V = NS_OF("Alfa_Vista")

---------------------------------------------------------------------------
-- Comercio
---------------------------------------------------------------------------
step("1. El separador de miles sigue al idioma", function()
  check(C.Miles(1234567) == "1,234,567", "en español: " .. tostring(C.Miles(1234567)))
  -- El build cambia GetLocale() por (AlfaIdioma or GetLocale)(): el idioma que eliges en Alfa.
  local real = rawget(_G, "AlfaIdioma")
  AlfaIdioma = function() return "deDE" end
  check(C.Miles(1234567) == "1.234.567", "en alemán: " .. tostring(C.Miles(1234567)))
  AlfaIdioma = function() return "frFR" end
  check(C.Miles(-12345) == "-12 345", "en francés: " .. tostring(C.Miles(-12345)))
  AlfaIdioma = real
  check(C.Miles(999) == "999", "con menos de mil")
end)

step("2. El consejo: sin piedra de hogar, misión ni equipo ligado; la pila", function()
  check(C.SinConsejo(C.Consejo(6948)), "la piedra de hogar lleva consejo")
  check(C.SinConsejo(C.Consejo(5000)), "un objeto de misión lleva consejo")
  check(C.SinConsejo(C.Consejo(7000, { ligado = true }), true), "un equipo ligado lleva consejo")
  local c = C.Consejo(2589)
  check(c and not C.SinConsejo(c, nil), "el lino ya no lleva consejo")
  local _, dos = C.LineasCuadro(c)
  check(dos and dos:find("×20:", 1, true), "no dice lo que vale la pila: " .. tostring(dos))
end)

step("3. Gangas en la subasta", function()
  check(A.Get("comercio.gangas") == true, "las gangas no vienen prendidas")
  local r = C.Reino()
  local hoy = math.floor(C.Ahora() / 86400)
  r.h[2589] = (hoy - 3) .. ":10000," .. (hoy - 2) .. ":12000," .. (hoy - 1) .. ":11000"
  C.OlvidarGangas()
  C.Anotar(2589, 4000, 20, 2)
  local g = C.GangaDe(2589)
  check(g and g.tipo == "barato", "no marcó la ganga a 40p contra 1o 10p")
  check(g and C.TextoGanga(g):find("64 % menos de lo que suele valer", 1, true), "el texto de la ganga: " .. tostring(g and C.TextoGanga(g)))
  check(#C.Gangas() == 1, "la lista de gangas")
  C.Anotar(2589, 10500, 20, 2)
  check(C.GangaDe(2589) == nil, "un precio normal se quedó como ganga")
  A.Set("comercio.gangas", false)
  C.Anotar(2589, 3000, 20, 2)
  check(C.GangaDe(2589) == nil, "con las gangas apagadas se marcó una")
  A.Set("comercio.gangas", true)
end)

step("4. /alfa comercio precio con el nombre", function()
  poner({ { 2589, 20 } })
  check(C.BuscarPorNombre("Lino") == 2589, "no encontró «Lino»")
  check(C.BuscarPorNombre("lin") == 2589, "no encontró «lin» en tus bolsas")
  check(C.BuscarPorNombre("nada de nada") == nil, "encontró algo que no existe")
end)

step("5. «Guíame» dice el motivo del motor", function()
  local Li = C.Lista
  check(Li and Li.TextoMotivo, "falta Lista.TextoMotivo") if not (Li and Li.TextoMotivo) then return end
  check(Li.TextoMotivo("tabs"):find("6 guías", 1, true), "el motivo «tabs»")
  check(Li.TextoMotivo("nolocation"):find("mapa", 1, true), "el motivo «nolocation»")
  check(Li.TextoMotivo("raro") == "No hay un camino que Alfa pueda guiar para esto.", "un motivo desconocido")
end)

step("6. El escaneo espera al combate", function()
  local real = InCombatLockdown
  local corrio = false
  InCombatLockdown = function() return true end
  C.Tarea("prueba137", function() corrio = true end)
  for _ = 1, 3 do mover() end
  check(not corrio, "la tarea corrió en combate")
  InCombatLockdown = real
  for _ = 1, 3 do mover() end
  check(corrio, "la tarea no corrió al salir de combate")
end)

step("7. Las recetas no se releen si la lista no cambió", function()
  local leidas = 0
  local real = C_TradeSkillUI
  C_TradeSkillUI = {
    GetRecipeInfo = function(id) return { learned = true, name = "Receta " .. id } end,
    GetRecipeSchematic = function(id) if id >= 101 and id <= 103 then leidas = leidas + 1 end return { outputItemID = 2589, quantityMin = 1, quantityMax = 1,
      reagentSlotSchematics = { { reagentType = 1, quantityRequired = 2, reagents = { { itemID = 765 } } } } } end,
    GetBaseProfessionInfo = function() return { professionName = "Sastrería", profession = 2, skillLevel = 50 } end,
    GetAllRecipeIDs = function() return { 101, 102, 103 } end,
    IsTradeSkillReady = function() return true end,
  }
  FIRE_EVENT("TRADE_SKILL_SHOW")
  T(2) for _ = 1, 5 do mover() end
  check(leidas == 3, "no leyó las 3 recetas al abrir (" .. leidas .. ")")
  FIRE_EVENT("TRADE_SKILL_LIST_UPDATE")
  T(2) for _ = 1, 5 do mover() end
  check(leidas == 3, "releyó toda la profesión al fabricar (" .. leidas .. ")")
  FIRE_EVENT("NEW_RECIPE_LEARNED")
  T(2) for _ = 1, 5 do mover() end
  check(leidas == 6, "no releyó al aprender una receta (" .. leidas .. ")")
  FIRE_EVENT("TRADE_SKILL_CLOSE")
  C_TradeSkillUI = real
end)

-- El buzón
local cartas = {}
local function evento(ev) C_Timer.After(0, function() FIRE_EVENT(ev) end) end
GetInboxNumItems = function() return #cartas, #cartas end
GetInboxHeaderInfo = function(i)
  local c = cartas[i]
  if not c then return nil end
  return "icono", nil, "Alt", "Asunto", c.dinero, 0, 30, #c.objetos, false, false, false, true, false
end
GetInboxItem = function(i, a)
  local o = cartas[i] and cartas[i].objetos[a]
  if not o then return nil end
  return "Objeto", o[1], 134400, o[2], 1, true
end
HasInboxItem = function(i, a) return cartas[i] and cartas[i].objetos[a] ~= nil or false end
TakeInboxMoney = function(i) local c = cartas[i] if c then c.dinero = 0 if #c.objetos == 0 then table.remove(cartas, i) end end evento("MAIL_INBOX_UPDATE") end
TakeInboxItem = function(i, a)
  local c = cartas[i]
  if not (c and c.objetos[a]) then return end
  table.remove(c.objetos, a)
  if c.dinero == 0 and #c.objetos == 0 then table.remove(cartas, i) end
  evento("MAIL_INBOX_UPDATE")
end
C_Mail = { IsCommandPending = function() return false end, SetOpeningAll = function() end, HasInboxMoney = function() return false end }
local mail = rawget(_G, "MailFrame")
if not (type(mail) == "table" and type(mail.GetObjectType) == "function") then
  mail = CreateFrame("Frame", "MailFrame", UIParent)
  mail:SetSize(384, 512)
  mail:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -100)
end

step("8. El buzón: cómo va «Tomar todo», piezas y Parar", function()
  local Bz = C.Buzon
  poner({})
  cartas = {
    { dinero = 0, objetos = { { 2589, 20 } } },
    { dinero = 0, objetos = { { 765, 1 } } },
    { dinero = 0, objetos = { { 2447, 3 } } },
  }
  avisos = {}
  FIRE_EVENT("MAIL_SHOW")
  FIRE_EVENT("MAIL_INBOX_UPDATE")
  T(2)
  check(Bz.Tomar(), "Tomar todo no empezó")
  local p = Bz.Placa()
  check(p and p:IsShown(), "no se ve cómo va")
  local txt = p and p.Texto:GetText() or ""
  check(txt:find("Tomando tus cartas:", 1, true) and txt:find("de 3", 1, true), "la placa no dice cómo va: " .. txt)
  T(40)
  check(not Bz.Tomando(), "no terminó")
  check(not (p and p:IsShown()), "la placa se quedó al terminar")
  local a = avisos[#avisos]
  check(a and a.texto:find("Recibiste 24 piezas", 1, true), "el resumen no dice piezas: " .. tostring(a and a.texto))
  check(Bz.TextoResumen(1, 0) == "Recibiste 1 pieza.", "una pieza: " .. Bz.TextoResumen(1, 0))
  -- Parar
  cartas = { { dinero = 0, objetos = { { 2589, 1 } } }, { dinero = 0, objetos = { { 765, 1 } } } }
  FIRE_EVENT("MAIL_INBOX_UPDATE")
  T(1)
  Bz.Tomar()
  Bz.Tomar()
  check(not Bz.Tomando(), "«Parar» no lo cortó")
  a = avisos[#avisos]
  check(a and a.texto:find("Paraste", 1, true), "no dijo que paraste: " .. tostring(a and a.texto))
  FIRE_EVENT("MAIL_CLOSED")
end)

step("9. Mandar a tu alt desde el buzón", function()
  local En = C.Envios
  check(En and En.Comando, "falta Envios.lua") if not En then return end
  check(A.Get("comercio.buzonAlt") == true, "mandar a tu alt no viene prendido")
  impreso = {}
  En.Comando("alquimista hierbas")
  check(dijo("En la lista de Alquimista"), "el comando no armó la lista: " .. table.concat(impreso, " | "))
  local l = En.Lista("Alquimista")
  check(l and l.tipos.hierbas, "la lista no tiene hierbas")
  poner({ { 765, 20 }, { 2589, 10 }, { 2447, 5 }, { 765, 3, true } })
  local cand = En.Candidatos(l)
  check(#cand == 2, "las hierbas sin ligar de tus bolsas deberían ser 2 (" .. #cand .. ")")
  -- La pestaña de enviar abierta.
  local envio = CreateFrame("Frame", "SendMailFrame", mail)
  envio:Show()
  local caja = CreateFrame("EditBox", "SendMailNameEditBox", envio)
  local adjuntos = {}
  HasSendMailItem = function(i) return adjuntos[i] ~= nil end
  ClickSendMailItemButton = function(i) if recogido then adjuntos[i] = recogido recogido = nil end end
  local enviado = false
  SendMail = function() enviado = true end
  FIRE_EVENT("MAIL_SHOW")
  T(2)
  local placa = En.Placa()
  check(placa and placa:IsShown(), "no salió la placa de mandar a tu alt")
  check(En.Preparar("Alquimista"), "Preparar no empezó")
  T(3)
  check(caja:GetText() == "Alquimista", "no puso el nombre: " .. tostring(caja:GetText()))
  local n = 0 for _ in pairs(adjuntos) do n = n + 1 end
  check(n == 2, "no adjuntó las 2 pilas de hierbas (" .. n .. ")")
  check(not enviado, "Alfa mandó la carta sola")
  check(placa.estado and placa.estado:find("Revisa la carta", 1, true), "no dice que revises y envíes: " .. tostring(placa.estado))
  En.Comando("alquimista quitar")
  check(En.Lista("Alquimista") == nil, "no borró la lista")
  FIRE_EVENT("MAIL_CLOSED")
  envio:Hide()
end)

---------------------------------------------------------------------------
-- Talentos
---------------------------------------------------------------------------
step("10. Talentos: dos armas, importar dos veces y cortar letras", function()
  local E = B.Equipo
  local real = rawget(_G, "CanDualWield")
  CanDualWield = function() return false end
  check(E.PuedeDosArmas() == false, "dice que puedes usar dos armas")
  CanDualWield = function() return true end
  check(E.PuedeDosArmas() == true, "no ve que puedes usar dos armas")
  CanDualWield = real
  check(B.Cortar("Plan del Ñandú", 11) == "Plan del Ña", "cortó mal: " .. tostring(B.Cortar("Plan del Ñandú", 11)))
  check(B.Cortar("Árbol", 1) == "Á", "partió la Á")
  local S = B.Compartir
  local clase = B.ClaseJugador and B.ClaseJugador() or "WARRIOR"
  local cadena = "ALFA1;" .. clase .. ";x;solo;equilibrado;Prueba 137;12282-1,12285-2"
  local a = S.Importar(cadena)
  local b2, como = S.Importar(cadena)
  if a then
    check(b2 and b2.id == a.id and como == "repetido", "importar dos veces lo duplicó")
    S.Borrar(a.id)
  end
end)

---------------------------------------------------------------------------
-- Curación
---------------------------------------------------------------------------
step("11a. La venda que tu Primeros auxilios deja usar", function()
  local rango = 40
  local realRango = A.Compat.GetSkillRank
  A.Compat.GetSkillRank = function(id) if id == 129 then return rango end return realRango and realRango(id) end
  poner({ { 3530, 5 }, { 2581, 5 } })
  check(Cu.MejorVenda() == 2581, "eligió una venda que pide más nivel (" .. tostring(Cu.MejorVenda()) .. ")")
  rango = 60
  check(Cu.MejorVenda() == 3530, "no eligió la mejor que puedes usar")
  rango = 5
  check(Cu.MejorVenda() == nil and Cu.LlevasVendas(), "con 5 de Primeros auxilios no hay venda que sirva")
  -- El clic de venda sin venda lo dice.
  local mapa = Cu.Mapa()
  local antes = mapa["shift-1"]
  mapa["shift-1"] = { t = "venda" }
  Cu.venda = nil
  impreso = {}
  local realShift = IsShiftKeyDown
  IsShiftKeyDown = function() return true end
  check(Cu.AlClic(nil, "LeftButton"), "el clic de venda sin venda no avisó")
  check(dijo("Primeros auxilios"), "el aviso no dice por qué")
  IsShiftKeyDown = realShift
  mapa["shift-1"] = antes
  A.Compat.GetSkillRank = realRango
end)

step("11b. Marcos bajos: nombre y estado en una línea", function()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(88, 24)
  local c = Cu.CrearCuerpo(f)
  Cu.AjustarCuerpo(c, 88, 24)
  check(c.bajo == true, "un marco de 24 de alto no va en una línea")
  c.nombre:SetText("Colmillo")
  c.estado:SetText("45%")
  c.estado:Show()
  local p1 = { c.nombre:GetPoint(1) }
  local p2 = { c.estado:GetPoint(1) }
  check(p1[1] == "LEFT" and p2[1] == "RIGHT", "nombre y estado no van a los lados")
  check(c.nombre:GetWidth() + c.estado:GetWidth() <= 88 - 8 + 0.5, "nombre y estado se enciman")
  Cu.AjustarCuerpo(c, 88, 36)
  check(c.bajo == false, "un marco alto quedó en una línea")
end)

step("11c. «¿Listos?»: lo tuyo y los apoyos del grupo", function()
  local Li = Cu.Listos
  check(Li and Li.Mostrar, "falta Listos.lua") if not Li then return end
  check(A.Get("curacion.listos") == true, "«¿Listos?» no viene prendido")
  poner({ { 4540, 10 } })
  local cosas = Li.MisCosas()
  local hayComida
  for _, x in ipairs(cosas) do if x.texto:find("Comida y bebida: 10", 1, true) then hayComida = true end end
  check(hayComida, "no contó la comida")
  -- Un grupo: tú eres sacerdote y a la maga le falta tu Entereza.
  local real = { UnitClass = UnitClass, UnitName = UnitName, IsInGroup = IsInGroup, GetNumSubgroupMembers = GetNumSubgroupMembers,
    UnitExists = UnitExists, UnitIsConnected = UnitIsConnected, UnitIsDeadOrGhost = UnitIsDeadOrGhost, UnitPowerType = UnitPowerType,
    C_UnitAuras = C_UnitAuras, C_Spell = C_Spell, IsPlayerSpell = IsPlayerSpell, IsSpellKnown = IsSpellKnown, C_SpellBook = C_SpellBook }
  local CL = { player = "PRIEST", party1 = "MAGE" }
  UnitClass = function(u) local c = CL[u] if c then return c, c, 1 end return nil end
  UnitName = function(u) return u == "player" and "Toxic" or "Luna" end
  IsInGroup = function() return true end
  GetNumSubgroupMembers = function() return 1 end
  UnitExists = function(u) return CL[u] ~= nil end
  UnitIsConnected = function() return true end
  UnitIsDeadOrGhost = function() return false end
  UnitPowerType = function() return 0 end
  C_Spell = { GetSpellName = function(id) if id == 1243 then return "Palabra de poder: entereza" end if id == 21562 then return "Rezo de entereza" end
    if id == 1459 then return "Intelecto Arcano" end if id == 23028 then return "Brillo Arcano" end return nil end }
  IsPlayerSpell = function(id) return id == 1243 end
  IsSpellKnown = IsPlayerSpell
  C_SpellBook = { IsSpellKnown = IsPlayerSpell }
  local tiene = { player = { ["Palabra de poder: entereza"] = true, ["Intelecto Arcano"] = true }, party1 = { ["Intelecto Arcano"] = true } }
  C_UnitAuras = { GetAuraDataBySpellName = function(u, n) return tiene[u] and tiene[u][n] and { name = n } or nil end }
  if Cu.OlvidarConocidos then Cu.OlvidarConocidos() end
  local faltan = Li.Faltan()  local ent
  for _, e in ipairs(faltan) do if e.bufo.id == "entereza" then ent = e end end
  check(ent and #ent.faltan == 1 and ent.faltan[1].nombre == "Luna", "no vio que a Luna le falta Entereza")
  for _, e in ipairs(faltan) do check(e.bufo.id ~= "marca", "pidió Marca sin druida en el grupo") end
  avisos = {}
  FIRE_EVENT("READY_CHECK", "Colmillo", 30)
  local p = Li.Placa()
  check(p and p:IsShown(), "«¿Listos?» no sacó la placa")
  check(ent and ent.mio and ent.mio.hechizo == "Palabra de poder: entereza", "no vio que la Entereza es tuya")
  if p and ent and ent.mio then
    check(p.Dar:IsShown(), "no salió el botón para dar tu Entereza")
    local atrib = type(p.Dar.alfaSeguro) == "function" and p.Dar.alfaSeguro(p.Dar)
    check(atrib and atrib.type == "macro" and atrib.macrotext == "/cast [@party1] Palabra de poder: entereza", "el botón seguro no lanza tu Entereza en Luna")
    check(p.dar and p.dar.unidad == "party1", "el botón no es para Luna")
  end
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not p:IsShown(), "la placa se quedó en combate")
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  for k, v in pairs(real) do _G[k] = v end
end)

---------------------------------------------------------------------------
-- Paisaje
---------------------------------------------------------------------------
step("12. Paisaje: Deshacer suelta lo que no elegiste; el reinicio solo si hace falta", function()
  if not (V and V.AplicarPreset and V.FILA) then check(false, "falta Paisaje") return end
  local cvars = {}
  local getReal, setReal, infoReal = C_CVar.GetCVar, C_CVar.SetCVar, C_CVar.GetCVarInfo
  local p = V.PRESET and V.PRESET.alto or V.PRESETS[1]
  for cvar in pairs(p.valores) do cvars[cvar] = "0" end
  C_CVar.GetCVar = function(k) return cvars[k] or (getReal and getReal(k)) end
  C_CVar.SetCVar = function(k, v) cvars[k] = tostring(v) return true end
  C_CVar.GetCVarInfo = function(k) if cvars[k] then return cvars[k], "0", false, false, false, false, false end return infoReal and infoReal(k) end
  local d = V.Datos()
  d.valores, d.deshacer = {}, nil
  local ok = V.AplicarPreset(p.id)
  check(ok, "no aplicó el preajuste")
  check(next(d.valores) ~= nil, "el preajuste no quedó elegido")
  V.Deshacer()
  local quedan = 0
  for cvar in pairs(p.valores) do if d.valores[cvar] ~= nil then quedan = quedan + 1 end end
  check(quedan == 0, "Deshacer dejó " .. quedan .. " ajustes que no elegiste")
  -- Reinicio: cambiar y volver al valor de antes no lo pide.
  local conReinicio
  for cvar, f in pairs(V.FILA) do if f.reinicio then conReinicio = cvar break end end
  if conReinicio then
    cvars[conReinicio] = cvars[conReinicio] or "0"
    local antes = cvars[conReinicio]
    V.Pedir(conReinicio, antes == "0" and 1 or 0, true, true)
    check(V.NecesitaReinicio(), "no pidió reiniciar tras cambiar " .. conReinicio)
    V.Pedir(conReinicio, antes, true, true)
    check(not V.NecesitaReinicio(), "pidió reiniciar aunque volviste al valor de antes")
  end
  C_CVar.GetCVar, C_CVar.SetCVar, C_CVar.GetCVarInfo = getReal, setReal, infoReal
end)

---------------------------------------------------------------------------
-- Recolección
---------------------------------------------------------------------------
step("13. Recolección: mapa y minimapa; los puntos y el combate", function()
  impreso = {}
  check(A.RunCommand, "no encuentro cómo correr un comando de Alfa")
  local cmd = nil
  local ejecutar = function(s) if A.RunCommand then A.RunCommand("recoleccion " .. s) elseif cmd then cmd(s) end end
  if A.RunCommand or cmd then
    ejecutar("mapa")
    check(dijo("mapa del mundo"), "«mapa» no dijo qué cambió: " .. table.concat(impreso, " | "))
    impreso = {}
    ejecutar("minimapa")
    check(dijo("minimapa"), "«minimapa» no dijo qué cambió: " .. table.concat(impreso, " | "))
    ejecutar("mapa") ejecutar("minimapa")
  end
  local R = NS_OF("Alfa_Recoleccion")
  local pool = R and R.MinimapaPines and R.MinimapaPines()
  if pool then
    local f = CreateFrame("Frame", nil, UIParent)
    f:EnableMouse(true)
    pool[999] = f
    FIRE_EVENT("PLAYER_REGEN_DISABLED")
    check(not f:IsMouseEnabled(), "un punto del minimapa toma el ratón en combate")
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    check(f:IsMouseEnabled(), "el punto no volvió a tomar el ratón al salir de combate")
    pool[999] = nil
  end
end)

---------------------------------------------------------------------------
-- Ver el equipo de un compañero
---------------------------------------------------------------------------
step("14. El equipo de un compañero", function()
  local In = B.Inspeccion
  check(In and In.Resumen, "falta Inspeccion.lua") if not In then return end
  local realLink, realClass, realLevel, realName = GetInventoryItemLink, UnitClass, UnitLevel, UnitName
  local suyo = { [5] = enlace(7000), [10] = nil }
  for _, s in ipairs({ 1, 2, 3, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16 }) do suyo[s] = enlace(7000) end
  GetInventoryItemLink = function(u, s) if u == "party1" then return suyo[s] end return realLink and realLink(u, s) end
  UnitClass = function(u) if u == "party1" then return "Mago", "MAGE", 8 end return realClass(u) end
  UnitLevel = function(u) if u == "party1" then return 30 end return realLevel(u) end
  UnitName = function(u) if u == "party1" then return "Luna" end return realName(u) end
  poner({ { 8000 }, { 8001 } })
  local titulo, lineas = In.Resumen("party1")
  local todo = table.concat(lineas, "\n")
  check(titulo == "El equipo de Luna", "el título: " .. tostring(titulo))
  check(todo:find("Nivel de objeto medio: 30", 1, true), "no dice el nivel medio: " .. todo)
  check(todo:find("Manos (vacío)", 1, true), "no dice la ranura vacía: " .. todo)
  check(todo:find("Guantes de tela verde", 1, true), "no ofrece los guantes de tela: " .. todo)
  check(not todo:find("Guantes de placas", 1, true), "ofreció placas a una maga: " .. todo)
  GetInventoryItemLink, UnitClass, UnitLevel, UnitName = realLink, realClass, realLevel, realName
end)

K.Aviso = avisoReal
N.Imprimir = imprimirReal
print(("PRUEBA: 1.3.7 oficios, %d pasos, %d errores"):format(pasos, #ERRORS))
