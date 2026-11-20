-- Prueba de la 1.3.2, Hoy, Bolsas, buzón y Paisaje (tools/prueba.py la corre con las demás prueba_*.lua):
--   1. «Esta sesión»: el oro del buzón va aparte (correo), fuera de lo ganado y
--      del oro por hora, con su línea en el cuadro;
--   2. la página de Bolsas rehace solo lo que cambió (con el oro, solo la
--      tarjeta de la sesión) y los conjuntos comparten una lectura de las bolsas;
--   3. «Acomodar» dice «Detener (x/y)» con el ícono de parar mientras trabaja;
--   4. «Tomar todo» mientras cargan las cartas: «Parar», y otro clic lo cancela;
--   5. el paso «Cierra misiones de %s» y «Llévame» desde otra zona;
--   6. «Qué vender»: lejos del umbral no se hace el análisis completo;
--   7. el grano de Paisaje con el reloj de Alfa (vista.grano), no con OnUpdate.
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
local function check(cond, msg) if not cond then NOTE("1.3.2 hoy", msg) end end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
local N = AlfaNucleo

-- Cambia campos de una tabla mientras corre fn y los devuelve (NADA: a nil).
local NADA = {}
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do
    antes[k] = { v = rawget(t, k) }
    if v == NADA then rawset(t, k, nil) else rawset(t, k, v) end
  end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(t, k, a.v) end
  if not ok then error(e, 0) end
end

---------------------------------------------------------------------------
-- El juego de mentira
---------------------------------------------------------------------------

local OBJ = {
  [2589] = { "Lino", "" }, [2592] = { "Lana", "" }, [4865] = { "Garra rota", "" },
  [9101] = { "Anillo del lobo", "INVTYPE_FINGER" }, [9105] = { "Anillo de la luna", "INVTYPE_FINGER" },
  [9103] = { "Yelmo del alfa", "INVTYPE_HEAD" },
}
local function idDe(x) return tonumber(tostring(x):match("item:(%d+)") or x) end
local function enlace(id)
  local o = OBJ[id]
  return "|cff1eff00|Hitem:" .. id .. "::::::::|h[" .. ((o and o[1]) or ("Objeto " .. id)) .. "]|h|r"
end
C_Item.GetItemInfo = function(x)
  local id = idDe(x)
  local o = OBJ[id]
  if not o then return nil end
  return o[1], enlace(id), 1, 20, 1, "Tipo", "Subtipo", 20, o[2], 134400, 10, 7, 5, 0
end

local TAM = { [0] = 16 }
local bolsas = { [0] = {} }
local leidas = 0
local usados = {}
local function poner(b, s, id, n, calidad)
  bolsas[b][s] = { itemID = id, stackCount = n or 1, quality = calidad or 1, hyperlink = enlace(id), isBound = false }
end
local function vaciar() bolsas[0] = {} end
local falso = {
  GetContainerNumSlots = function(b) return TAM[b] or 0 end,
  GetContainerNumFreeSlots = function(b)
    local t = bolsas[b]
    if not t then return 0, 0 end
    local n = 0
    for s = 1, TAM[b] do if not t[s] then n = n + 1 end end
    return n, 0
  end,
  CalculateTotalNumberOfFreeBagSlots = function() return 10 end,
  GetContainerItemInfo = function(b, s) leidas = leidas + 1 return bolsas[b] and bolsas[b][s] end,
  GetContainerItemQuestInfo = function() return { isQuestItem = false } end,
  GetContainerItemLink = function(b, s) local i = bolsas[b] and bolsas[b][s] return i and i.hyperlink end,
  GetContainerItemID = function(b, s) local i = bolsas[b] and bolsas[b][s] return i and i.itemID end,
  UseContainerItem = function(b, s) usados[#usados + 1] = { b, s } if bolsas[b] then bolsas[b][s] = nil end end,
  ContainerIDToInventoryID = function(b) return b + 19 end,
  GetBagName = function() return nil end,
  GetContainerItemCooldown = function() return 0, 0, 0 end,
}
C_Container = C_Container or {}
for k, v in pairs(falso) do C_Container[k] = v end

local equipo = {}
GetInventoryItemID = function(u, r) local e = equipo[r] return e and e.id end
GetInventoryItemLink = function(u, r) local e = equipo[r] return e and e.link end
local function llevar(r, id) equipo[r] = id and { id = id, link = enlace(id) } or nil end

local dinero = 100000
GetMoney = function() return dinero end
local function cobrar(n)
  dinero = dinero + n
  FIRE_EVENT("PLAYER_MONEY")
end

local avisos = {}
local avisoReal = K.Aviso
K.Aviso = function(o) avisos[#avisos + 1] = o return {} end

if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(6)

local B = NS_OF("Alfa_Bolsas")
local C = NS_OF("Alfa_Comercio")
local I = NS_OF("Alfa_Inicio")
local Vi = NS_OF("Alfa_Vista")
local Se, Cj, S, V, Ac = B.Sesion, B.Conjuntos, B.Sugerencias, B.Ventana, B.Acomodar

---------------------------------------------------------------------------
-- 1. El oro del buzón, aparte
---------------------------------------------------------------------------

step("Sesión: el oro del buzón no cuenta como ganado ni por hora", function()
  FIRE_EVENT("MAIL_CLOSED")
  NOW = NOW + 10
  local s0 = Se.Datos()
  cobrar(2000) -- matando lobos
  local s1 = Se.Datos()
  check(s1.ganado - s0.ganado == 2000, "lo ganado fuera del buzón no se sumó")
  -- Tomas 5 de oro de tu otro personaje.
  FIRE_EVENT("MAIL_SHOW")
  cobrar(50000)
  FIRE_EVENT("MAIL_CLOSED")
  -- El oro del buzón llega un momento después de cerrarlo: también es del correo.
  cobrar(700)
  local s2 = Se.Datos()
  check(s2.ganado == s1.ganado, "el oro del buzón se contó como ganado: " .. (s2.ganado - s1.ganado))
  check(s2.correo - (s1.correo or 0) == 50700, "el oro del buzón no va en su cuenta: " .. tostring(s2.correo))
  check(s2.oro - s1.oro == 50700, "el neto no cuenta el oro del buzón")
  NOW = NOW + 120
  local s3 = Se.Datos()
  check(s3.porHora == math.floor(s3.ganado * 3600 / s3.segundos), "el oro por hora no sale solo de lo ganado")
  local linea
  for _, l in ipairs(Se.Lineas()) do if l:find("Del buzón", 1, true) then linea = l end end
  check(linea and linea:find("no cuenta por hora", 1, true), "el cuadro no tiene la línea del buzón: " .. tostring(linea))
  -- Pasada la espera, lo que sube ya es ganado.
  NOW = NOW + 10
  cobrar(300)
  check(Se.Datos().ganado - s3.ganado == 300, "después del buzón, lo ganado no se sumó")
end)

---------------------------------------------------------------------------
-- 2. La página de Bolsas: solo lo que cambió
---------------------------------------------------------------------------

step("Bolsas: con el oro solo cambia la tarjeta de la sesión", function()
  vaciar()
  equipo = {}
  llevar(11, 9101) llevar(12, 9105) llevar(1, 9103)
  Cj.Guardar("Daño") Cj.Guardar("Curación") Cj.Guardar("Pesca")
  AlfaNucleo.Abrir("bolsas")
  RUN_TIMERS(3)
  local P = B.Pagina
  check(P.view and P.view:IsVisible(), "la página de Bolsas no está a la vista")
  local Gu = B.Guardar
  local sug, ses, lecturas = 0, 0, 0
  local sugReal, sesReal, leerReal = Gu.Sugerencias, Se.Datos, Cj.LeerBolsas
  Gu.Sugerencias = function(...) sug = sug + 1 return sugReal(...) end
  Se.Datos = function(...) ses = ses + 1 return sesReal(...) end
  Cj.LeerBolsas = function(...) lecturas = lecturas + 1 return leerReal(...) end
  local ok, e = pcall(function()
    -- Cambia el oro: solo la sesión.
    sug, ses, lecturas = 0, 0, 0
    B.Avisar("SESION")
    RUN_TIMERS(2)
    check(ses >= 1, "con el oro no se rehizo la tarjeta de la sesión")
    check(sug == 0 and lecturas == 0, "con el oro se rehizo toda la página (qué guardar " .. sug .. ", conjuntos " .. lecturas .. ")")
    -- Cambian tus conjuntos: los tres, con una sola lectura de las bolsas.
    sug, lecturas, leidas = 0, 0, 0
    B.Avisar("CONJUNTOS")
    RUN_TIMERS(2)
    check(lecturas == 1, "los conjuntos no compartieron la lectura de tus bolsas: " .. lecturas)
    check(leidas <= TAM[0], "leyó " .. leidas .. " casillas para tres conjuntos (una pasada son " .. TAM[0] .. ")")
    check(sug == 0, "con los conjuntos se rehizo «Qué guardar»")
    -- Cambian tus bolsas: también «Qué guardar».
    sug = 0
    B.Avisar("DATOS", "Lobato-Forever")
    RUN_TIMERS(2)
    check(sug >= 1, "con tus bolsas no se rehizo «Qué guardar»")
    -- Un ajuste: todo.
    sug, ses = 0, 0
    A.Set("bolsas.marcaNivel", false)
    RUN_TIMERS(2)
    A.Set("bolsas.marcaNivel", nil)
    RUN_TIMERS(2)
    check(sug >= 1 and ses >= 1, "un ajuste no rehízo toda la página")
  end)
  Gu.Sugerencias, Se.Datos, Cj.LeerBolsas = sugReal, sesReal, leerReal
  if not ok then error(e, 0) end
  Cj.Olvidar("Daño") Cj.Olvidar("Curación") Cj.Olvidar("Pesca")
  equipo = {}
end)

---------------------------------------------------------------------------
-- 3. «Acomodar» dice su avance
---------------------------------------------------------------------------

step("Acomodar: «Detener (x/y)» con el ícono de parar mientras vende", function()
  vaciar()
  for s = 1, 8 do poner(0, s, 4865, 2, 0) end
  local Q = A.QoL or {}
  A.QoL = Q
  local vendorReal = Q.Vendor
  Q.Vendor = { JunkAt = function(b, s)
    local e = bolsas[b] and bolsas[b][s]
    if e and e.quality == 0 then return e.itemID, e.stackCount, 10 end
    return nil
  end }
  A.Set("qol.sellJunk", false)
  FIRE_EVENT("MERCHANT_SHOW")
  RUN_TIMERS(2)
  V.MostrarBolsas(true)
  local f = V.Ventana("bolsas")
  RUN_TIMERS(2)
  check(f.Acomodar and f.Acomodar:IsShown(), "no sale «Acomodar» con el comerciante")
  check(Ac.Hacer(), "«Acomodar» no empezó")
  local texto = f.Acomodar.Texto:GetText()
  check(texto == "Detener (6/8)", "mientras vende no dice su avance: " .. tostring(texto))
  check(f.Acomodar.alfaIcono == "ic-cerrar", "mientras vende no lleva el ícono de parar: " .. tostring(f.Acomodar.alfaIcono))
  RUN_TIMERS(4)
  check(f.Acomodar.Texto:GetText() == "Acomodar" and f.Acomodar.alfaIcono == nil, "al terminar no volvió a «Acomodar»: " .. tostring(f.Acomodar.Texto:GetText()))
  -- Depositar desde su botón no cambia «Acomodar».
  check(Ac.Avance() == nil, "sin tanda de «Acomodar», Avance dice algo")
  V.MostrarBolsas(false)
  FIRE_EVENT("MERCHANT_CLOSED")
  RUN_TIMERS(2)
  Q.Vendor = vendorReal
  A.Set("qol.sellJunk", nil)
  vaciar()
end)

---------------------------------------------------------------------------
-- 4. «Tomar todo» mientras cargan las cartas
---------------------------------------------------------------------------

step("Buzón: sin barra; mientras cargan, otro clic lo cancela", function()
  local Bz = C.Buzon
  local cartas = {}
  local cargadas = false
  local marco = rawget(_G, "MailFrame") or CreateFrame("Frame", "MailFrame", UIParent)
  con(_G, {
    MailFrame = marco,
    GetInboxNumItems = function() if not cargadas then return 0, 0 end return #cartas, #cartas end,
    GetInboxHeaderInfo = function(i)
      local c = cartas[i]
      if not c then return nil end
      return nil, nil, "Alt", "Oro", c.dinero, 0, 20, 0, false, false, false, false, false
    end,
    GetInboxItem = function() return nil end,
    HasInboxItem = function() return false end,
    TakeInboxMoney = function(i) if cartas[i] then table.remove(cartas, i) end end,
    TakeInboxItem = function() end,
    CheckInbox = function() end,
    C_Mail = { IsCommandPending = function() return false end, SetOpeningAll = function() end, HasInboxMoney = function() return false end },
  }, function()
    cartas = { { dinero = 900 } }
    FIRE_EVENT("MAIL_SHOW")
    -- 1.3.2 (Toxic): ya no sale ninguna barra bajo el buzón.
    check(Bz.Barra() == nil, "salió la barra bajo el buzón")
    check(Bz.Tomar(), "no aceptó «Tomar todo» mientras cargaba")
    check(Bz.Pendiente(), "no quedó pedido")
    -- Otro clic: cancelado.
    Bz.Tomar()
    check(not Bz.Pendiente(), "el segundo clic no lo canceló")
    cargadas = true
    FIRE_EVENT("MAIL_INBOX_UPDATE")
    RUN_TIMERS(3)
    check(not Bz.Tomando() and #cartas == 1, "cancelado, igual tomó las cartas al llegar")
    -- Y si no se cancela, se toma al llegar (como en la 1.3.0).
    FIRE_EVENT("MAIL_CLOSED")
    cargadas = false
    FIRE_EVENT("MAIL_SHOW")
    Bz.Tomar()
    cargadas = true
    FIRE_EVENT("MAIL_INBOX_UPDATE")
    RUN_TIMERS(10)
    check(#cartas == 0, "pedido sin cancelar, no tomó la carta al llegar")
    FIRE_EVENT("MAIL_CLOSED")
    RUN_TIMERS(1)
  end)
end)

---------------------------------------------------------------------------
-- 5. El paso de tu zona, con su nombre
---------------------------------------------------------------------------

step("Tiempo: «Cierra misiones de %s» y «Llévame» desde otra zona", function()
  local TM = I.Tiempo
  local llamadas = {}
  local zona = "Durotar"
  con(_G, { AlfaRuta = { Liberar = function(f) llamadas[#llamadas + 1] = tostring(f) end, Listas = function() return 0 end },
    GetRealZoneText = function() return zona end, GetZoneText = function() return zona end }, function()
    local p = { tipo = "zona", n = 2, zona = "Durotar" }
    local titulo = TM.Textos(p)
    check(titulo == "Cierra misiones de Durotar", "el paso no dice su zona: " .. tostring(titulo))
    check(TM.Textos({ tipo = "zona", n = 2 }) == "Cierra misiones de esta zona", "un plan viejo sin zona cambió su texto")
    avisos = {}
    zona = "Orgrimmar"
    TM.Ir(p)
    check(#llamadas == 0, "desde otra zona «Llévame» armó las misiones de la zona equivocada")
    local a = avisos[#avisos]
    check(a and a.titulo == "Vuelve a Durotar", "desde otra zona no avisó que hay que volver: " .. tostring(a and a.titulo))
    zona = "Durotar"
    TM.Ir(p)
    check(llamadas[1] == "zona", "en su zona «Llévame» no armó sus misiones")
  end)
end)

---------------------------------------------------------------------------
-- 6. «Qué vender»: lo barato primero
---------------------------------------------------------------------------

step("Qué vender: lejos del umbral no se hace el análisis completo", function()
  V.MostrarBolsas(false)
  AlfaNucleo.Abrir("inicio")
  RUN_TIMERS(3)
  local consejos = 0
  local CM = rawget(_G, "AlfaComercio")
  local real = CM and CM.Consejo
  if CM then CM.Consejo = function(...) consejos = consejos + 1 return real(...) end end
  local ok, e = pcall(function()
    vaciar()
    poner(0, 1, 2589, 5) poner(0, 2, 2592, 3)
    consejos = 0
    FIRE_EVENT("BAG_UPDATE", 0)
    FIRE_EVENT("BAG_UPDATE_DELAYED")
    RUN_TIMERS(3)
    check(consejos == 0, "con 14 casillas libres analizó cada objeto (" .. consejos .. " consejos)")
    -- Cerca del umbral (4 libres o menos), sí.
    for s = 3, 13 do poner(0, s, 2589, 1) end
    consejos = 0
    avisos = {}
    FIRE_EVENT("BAG_UPDATE", 0)
    FIRE_EVENT("BAG_UPDATE_DELAYED")
    RUN_TIMERS(3)
    check(consejos > 0, "cerca del umbral no analizó tus bolsas")
    local dijo = false
    for _, a in ipairs(avisos) do if tostring(a.titulo):find("bolsas", 1, true) then dijo = true end end
    check(dijo, "cerca del umbral no avisó que tus bolsas se llenan")
  end)
  if CM then CM.Consejo = real end
  if not ok then error(e, 0) end
  vaciar()
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(3)
end)

---------------------------------------------------------------------------
-- 7. El grano, con el reloj de Alfa
---------------------------------------------------------------------------

step("Paisaje: el grano se mueve con vista.grano y se quita al apagarlo", function()
  local F = Vi.Filtros
  check(F and F.Aplicar, "falta Filtros.lua") if not F then return end
  A.Set("vista.grano", true)
  RUN_TIMERS(1)
  local raiz = rawget(_G, "AlfaVistaFiltros")
  check(N.HayTarea("vista.grano"), "con el grano prendido no hay tarea vista.grano")
  check(raiz and raiz:GetScript("OnUpdate") == nil, "el grano sigue con un OnUpdate")
  A.Set("vista.granoMover", false)
  RUN_TIMERS(1)
  check(not N.HayTarea("vista.grano"), "con el grano quieto la tarea sigue")
  A.Set("vista.granoMover", nil)
  RUN_TIMERS(1)
  check(N.HayTarea("vista.grano"), "al volver a moverlo no volvió la tarea")
  A.Set("vista.grano", false)
  RUN_TIMERS(1)
  check(not N.HayTarea("vista.grano"), "al apagar el grano la tarea vista.grano siguió")
  A.Set("vista.grano", nil)
end)

K.Aviso = avisoReal
print(string.format("PRUEBA: 1.3.2 Hoy, bolsas, buzón y paisaje, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
