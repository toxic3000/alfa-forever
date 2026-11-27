-- Prueba de la 1.4.2: la economía (bolsas, comercio, recolección y pesca).
--
-- Toxic pidió «20 mejoras bastante significativas y 20 en experiencia del
-- usuario». Las de la economía, cada una con su paso:
--   1. «Siempre a la mano»: el comerciante repone lo de siempre con un clic
--      (Comercio/Reponer.lua), y pregunta una vez tras dos compras iguales.
--   2. Lo que falta de tu lista de compras, en el mismo aviso del comerciante.
--   3. Tus subastas: lo que tienes a la venta, lo vendido y cuándo vence, con
--      aviso de lo vendido al abrir la subasta (Comercio/Subastas.lua).
--   4. «La última vez lo pusiste a…» en la ayuda al subastar (Vender.lua).
--   5. «Tienes N (… 3 en la subasta)» en el cuadro de cada objeto (Bolsas/Datos.lua).
--   6. El comerciante que vende barato lo que en la subasta vale más (Comercio/Reventa.lua).
--   7. Dónde subir Minería o Herboristería (Recolección/Subir.lua).
--   8. Lo recolectado hace poco se ve tenue y dice hace cuánto (Recolección/Pines.lua).
--   9. Mayús+clic en un pin del mapa: la ruta por ese recurso (Recolección/Mapa.lua).
--  10. Qué pica aquí y tus lugares que más dejan (Pesca/Aqui.lua).
PRUEBA_AREA("1.4.2 economía")
PRUEBA_ENTRAR()
local A, N = Alfa, AlfaNucleo
local K = N.Kit

local Co = NS_OF("Alfa_Comercio")
local Bo = NS_OF("Alfa_Bolsas")
local Rc = NS_OF("Alfa_Recoleccion")
local Pe = NS_OF("Alfa_Pesca")

local avisoReal = K.Aviso
local avisos = {}
K.Aviso = function(o) avisos[#avisos + 1] = o return avisoReal(o) end
local function avisoCon(id) for i = #avisos, 1, -1 do if avisos[i].id == id then return avisos[i] end end end
local function limpiar() avisos = {} end

-- Pone globales por un rato y las devuelve.
local function con(t, fn)
  local antes = {}
  for k, v in pairs(t) do antes[k] = { v = rawget(_G, k) } rawset(_G, k, v) end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(_G, k, a.v) end
  if not ok then error(e, 0) end
end

---------------------------------------------------------------------------
-- Un comerciante de mentiras: agua (25c, sin límite) y una receta limitada.
---------------------------------------------------------------------------
local AGUA, RECETA, HILO = 159, 6270, 2320
local VENDE = {
  { id = AGUA, nombre = "Agua refrescante", precio = 25, por = 1, hay = -1, clase = 0 },
  { id = RECETA, nombre = "Patrón: túnica azul", precio = 4000, por = 1, hay = 1, clase = 9 },
  { id = HILO, nombre = "Hilo grueso", precio = 10, por = 1, hay = -1, clase = 7 },
}
local compras = {}
local dinero = 100000
local MF = rawget(_G, "MerchantFrame") or CreateFrame("Frame", "MerchantFrame", UIParent)
MF.selectedTab = 1
local CIp = {}
for k, v in pairs(C_Item) do CIp[k] = v end
CIp.GetItemInfo = function(id)
  id = tonumber(tostring(id):match("(%d+)") or id)
  for _, v in ipairs(VENDE) do
    if v.id == id then return v.nombre, "|Hitem:" .. id .. "|h[" .. v.nombre .. "]|h", 1, 5, 1, "x", "y", 20, "", 134400, 1, v.clase end
  end
  return "Objeto " .. tostring(id), nil, 1, 5, 1, "x", "y", 20, "", 134400, 1, 7
end
local COMERCIANTE = {
  C_Item = CIp, C_MerchantFrame = false,
  GetMoney = function() return dinero end,
  GetMerchantNumItems = function() return #VENDE end,
  GetMerchantItemID = function(i) return VENDE[i] and VENDE[i].id end,
  GetMerchantItemInfo = function(i) local v = VENDE[i] return v.nombre, 134400, v.precio, v.por, v.hay, true, true, false end,
  GetMerchantItemMaxStack = function() return 20 end,
  BuyMerchantItem = function(i, n) compras[#compras + 1] = { i, n } dinero = dinero - VENDE[i].precio * n end,
}
local tengo = {}
Co.EnBolsas = function(id) return tengo[id] or 0 end

PASO("1. «Siempre a la mano»: el comerciante te ofrece reponer y «Comprar» lo repone con un clic", function()
  local Rp = Co.Reponer
  REVISA(Rp and Rp.Plan, "no existe Comercio/Reponer.lua") if not Rp then return end
  REVISA(A.Get("comercio.reponer") == true, "comercio.reponer no viene prendido de fábrica")
  Rp.Poner(AGUA, 40)
  tengo[AGUA] = 5
  con(COMERCIANTE, function()
    MF:Show()
    limpiar()
    FIRE_EVENT("MERCHANT_SHOW")
    TIEMPO(1)
    local o = avisoCon("comercio.reponer")
    REVISA(o, "al abrir el comerciante no salió el aviso de reponer")
    REVISA(o and tostring(o.texto):find("×35", 1, true), "el aviso no dice que faltan 35 de agua: " .. tostring(o and o.texto))
    REVISA(o and o.acciones and o.acciones[1], "el aviso no trae el botón «Comprar»")
    REVISA(#compras == 0, "Alfa compró sin tu clic")
    if o and o.acciones and o.acciones[1] then o.acciones[1].alClic() end
    local n = 0
    for _, c in ipairs(compras) do if c[1] == 1 then n = n + c[2] end end
    REVISA(n == 35, "«Comprar» no repuso 35 de agua, compró " .. n)
    for _, c in ipairs(compras) do REVISA(c[2] <= 20, "compró más de una pila de un jalón: " .. c[2]) end
    -- Sin dinero: lo que alcanza.
    compras, dinero = {}, 250
    local plan = Rp.Plan()
    REVISA(plan[1] and plan[1].objetos == 10, "sin dinero no se limita a lo que alcanza: " .. tostring(plan[1] and plan[1].objetos))
    dinero = 100000
    -- En combate no compra.
    local enComb = InCombatLockdown
    InCombatLockdown = function() return true end
    compras = {}
    Rp.Comprar()
    InCombatLockdown = enComb
    REVISA(#compras == 0, "compró en combate")
    FIRE_EVENT("MERCHANT_CLOSED")
    MF:Hide()
  end)
  Rp.Quitar(AGUA)
  REVISA(Rp.Cantidad(AGUA) == nil, "«Quitar» no lo quitó de la lista")
end)

PASO("1b. Dos compras iguales en dos visitas: «¿Siempre a la mano?», una sola vez", function()
  local Rp = Co.Reponer if not Rp then return end
  tengo[AGUA] = 20
  con(COMERCIANTE, function()
    limpiar()
    MF:Show()
    FIRE_EVENT("MERCHANT_SHOW")
    BuyMerchantItem(1, 20)
    TIEMPO(1)
    REVISA(not avisoCon("comercio.reponerPregunta"), "preguntó con una sola compra")
    FIRE_EVENT("MERCHANT_CLOSED")
    FIRE_EVENT("MERCHANT_SHOW")
    BuyMerchantItem(1, 20)
    TIEMPO(1)
    local o = avisoCon("comercio.reponerPregunta")
    REVISA(o, "tras comprar lo mismo en dos visitas no preguntó «¿Siempre a la mano?»")
    if o and o.acciones then o.acciones[1].alClic() end
    REVISA(Rp.Cantidad(AGUA) == 20, "«Sí, hasta 20» no lo puso en la lista: " .. tostring(Rp.Cantidad(AGUA)))
    -- Una receta (clase 9) nunca se ofrece.
    limpiar()
    FIRE_EVENT("MERCHANT_SHOW")
    BuyMerchantItem(2, 1)
    FIRE_EVENT("MERCHANT_SHOW")
    BuyMerchantItem(2, 1)
    TIEMPO(1)
    REVISA(not avisoCon("comercio.reponerPregunta"), "ofreció tener «siempre a la mano» una receta")
    -- El hilo sí (material, clase 7).
    FIRE_EVENT("MERCHANT_SHOW")
    BuyMerchantItem(3, 1)
    FIRE_EVENT("MERCHANT_SHOW")
    BuyMerchantItem(3, 1)
    TIEMPO(1)
    REVISA(avisoCon("comercio.reponerPregunta"), "el hilo comprado dos veces no se ofreció")
    limpiar()
    FIRE_EVENT("MERCHANT_SHOW")
    BuyMerchantItem(3, 1)
    TIEMPO(1)
    REVISA(not avisoCon("comercio.reponerPregunta"), "preguntó dos veces por lo mismo")
    FIRE_EVENT("MERCHANT_CLOSED")
    MF:Hide()
  end)
  Rp.Quitar(AGUA)
end)

PASO("2. Lo que falta de tu lista de compras sale en el aviso del comerciante", function()
  local Rp = Co.Reponer if not Rp then return end
  local real = Co.Lista.Materiales
  Co.Lista.Materiales = function() return { { id = HILO, faltan = 6, necesita = 6, tienes = 0 } }, 0, 1 end
  con(COMERCIANTE, function()
    local plan = Rp.Plan()
    local hilo
    for _, p in ipairs(plan) do if p.id == HILO then hilo = p end end
    REVISA(hilo and hilo.objetos == 6 and hilo.motivo == "lista", "el hilo que falta de tu lista no está en el plan")
    MF:Show()
    limpiar()
    local o = Rp.Ofrecer()
    REVISA(o and tostring(o.titulo):find("lo que te falta", 1, true), "el aviso no dice que el comerciante tiene lo que te falta: " .. tostring(o and o.titulo))
    A.Set("comercio.reponerLista", false)
    plan = Rp.Plan()
    REVISA(#plan == 0, "con el ajuste apagado siguió ofreciendo lo de la lista")
    A.Set("comercio.reponerLista", true)
    MF:Hide()
  end)
  Co.Lista.Materiales = real
end)

---------------------------------------------------------------------------
-- La subasta: tus subastas
---------------------------------------------------------------------------
local HIERRO = 2772
local MIAS = {}
local pedidas = 0
C_AuctionHouse = C_AuctionHouse or {}
C_AuctionHouse.ReplicateItems = C_AuctionHouse.ReplicateItems or function() end
C_AuctionHouse.GetNumReplicateItems = C_AuctionHouse.GetNumReplicateItems or function() return 0 end
C_AuctionHouse.GetReplicateItemInfo = C_AuctionHouse.GetReplicateItemInfo or function() return nil end
C_AuctionHouse.QueryOwnedAuctions = function() pedidas = pedidas + 1 end
C_AuctionHouse.GetOwnedAuctions = function() return MIAS end

PASO("3. Tus subastas: lo que tienes a la venta, lo vendido y cuándo vence; aviso de lo vendido", function()
  local Su = Co.Subastas
  REVISA(Su and Su.Leer, "no existe Comercio/Subastas.lua") if not Su then return end
  Co.Anotar(HIERRO, 1000, 10, 1, time())
  MIAS = {
    { auctionID = 1, itemKey = { itemID = HIERRO }, itemLink = "|Hitem:2772|h[Mena de hierro]|h", status = 0, quantity = 5, timeLeftSeconds = 3 * 3600, buyoutAmount = 1100 },
    { auctionID = 2, itemKey = { itemID = HIERRO }, itemLink = "|Hitem:2772|h[Mena de hierro]|h", status = 0, quantity = 1, timeLeftSeconds = 20 * 3600, buyoutAmount = 1200 },
  }
  limpiar()
  FIRE_EVENT("AUCTION_HOUSE_SHOW")
  TIEMPO(2)
  REVISA(pedidas >= 1, "al abrir la subasta no se pidió la lista de tus subastas")
  FIRE_EVENT("OWNED_AUCTIONS_UPDATED")
  TIEMPO(1)
  local r = Su.Resumen()
  REVISA(r.activas == 2 and r.valor == 1100 * 5 + 1200, ("el resumen no cuadra: %d activas, %s"):format(r.activas, tostring(r.valor)))
  REVISA(r.proxima and r.proxima - time() <= 3 * 3600 + 5, "no sabe cuál vence primero")
  REVISA(Su.EnSubasta(HIERRO) == 6, "no cuenta 6 menas en la subasta: " .. Su.EnSubasta(HIERRO))
  REVISA(not avisoCon("comercio.subastasVendidas"), "avisó de ventas sin que se vendiera nada")
  FIRE_EVENT("AUCTION_HOUSE_CLOSED")
  -- Otra visita: una ya se vendió.
  MIAS[1].status, MIAS[1].timeLeftSeconds = 1, nil
  FIRE_EVENT("AUCTION_HOUSE_SHOW")
  TIEMPO(2)
  FIRE_EVENT("OWNED_AUCTIONS_UPDATED")
  TIEMPO(1)
  local o = avisoCon("comercio.subastasVendidas")
  REVISA(o and tostring(o.titulo):find("1", 1, true), "al abrir la subasta no avisó de la que se vendió")
  REVISA(Su.EnSubasta(HIERRO) == 1, "lo vendido sigue contando como en venta: " .. Su.EnSubasta(HIERRO))
  limpiar()
  FIRE_EVENT("OWNED_AUCTIONS_UPDATED")
  TIEMPO(1)
  REVISA(not avisoCon("comercio.subastasVendidas"), "avisó otra vez de la misma venta")
  -- La página: la sección «Tus subastas».
  N.Abrir("comercio")
  TIEMPO(1)
  FIRE_EVENT("AUCTION_HOUSE_CLOSED")
end)

PASO("4. La ayuda al subastar dice a cuánto lo pusiste la última vez", function()
  local Ve, Su = Co.Vender, Co.Subastas
  if not (Ve and Su) then return end
  -- Lo que pone la ventana de vender (como en prueba_129_comercio.lua).
  C_Item.GetItemID = C_Item.GetItemID or function(loc) return loc and loc.id end
  C_Item.DoesItemExist = C_Item.DoesItemExist or function(loc) return loc ~= nil end
  local u = Su.UltimoPrecio(HIERRO)
  REVISA(u == 1200, "no recuerda el último precio que pusiste: " .. tostring(u))
  local AH = rawget(_G, "AuctionHouseFrame") or CreateFrame("Frame", "AuctionHouseFrame", UIParent)
  AH:SetSize(800, 540)
  AH:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -80)
  AH.CommoditiesSellFrame = AH.CommoditiesSellFrame or CreateFrame("Frame", nil, AH)
  AH.ItemSellFrame = AH.ItemSellFrame or CreateFrame("Frame", nil, AH)
  AH.ItemSellFrame:Hide()
  AH:Show()
  AH.CommoditiesSellFrame:Show()
  function AH.CommoditiesSellFrame:GetItem() return { id = HIERRO } end
  function AH.CommoditiesSellFrame:GetUnitPrice() return 1150 end
  FIRE_EVENT("AUCTION_HOUSE_SHOW")
  RUN_TIMERS(3)
  local e = Ve.Estado()
  REVISA(e and e.ultimo == 1200, "el panel no sabe el último precio: " .. tostring(e and e.ultimo))
  local p = Ve.Panel()
  REVISA(p and p.Ultima and p.Ultima:IsShown() and tostring(p.Ultima:GetText()):find("La última vez", 1, true),
    "el panel no dice «La última vez lo pusiste a…»: " .. tostring(p and p.Ultima and p.Ultima:GetText()))
  FIRE_EVENT("AUCTION_HOUSE_CLOSED")
  RUN_TIMERS(2)
  AH:Hide()
end)

PASO("5. El cuadro del objeto cuenta lo que tienes en la subasta", function()
  local D = Bo.Datos
  REVISA(D and D.LineaCuadro, "no encuentro Bolsas/Datos.lua") if not D then return end
  local t = D.LineaCuadro(HIERRO)
  REVISA(t and t:find("1 en la subasta", 1, true), "el cuadro no dice «1 en la subasta»: " .. tostring(t))
  A.Set("comercio.subastas", false)
  t = D.LineaCuadro(HIERRO)
  REVISA(not (t and t:find("en la subasta", 1, true)), "con el ajuste apagado sigue diciendo lo de la subasta")
  A.Set("comercio.subastas", true)
end)

PASO("6. El comerciante que vende barato: un aviso, una vez", function()
  local Rv = Co.Reventa
  REVISA(Rv and Rv.Buscar, "no existe Comercio/Reventa.lua") if not Rv then return end
  Co.Anotar(RECETA, 30000, 1, 1, time())
  Co.Anotar(AGUA, 30, 20, 1, time()) -- casi lo mismo que en el comerciante: no es ganga
  con(COMERCIANTE, function()
    local lista = Rv.Buscar()
    REVISA(#lista == 1 and lista[1].id == RECETA, "no encontró solo la receta barata: " .. #lista)
    limpiar()
    MF:Show()
    FIRE_EVENT("MERCHANT_SHOW")
    TIEMPO(2)
    local o = avisoCon("comercio.reventa")
    REVISA(o and tostring(o.texto):find("túnica", 1, true), "no avisó de la receta barata: " .. tostring(o and o.texto))
    limpiar()
    FIRE_EVENT("MERCHANT_CLOSED")
    FIRE_EVENT("MERCHANT_SHOW")
    TIEMPO(2)
    REVISA(not avisoCon("comercio.reventa"), "avisó otra vez en el mismo día y comerciante")
    FIRE_EVENT("MERCHANT_CLOSED")
    MF:Hide()
  end)
end)

---------------------------------------------------------------------------
-- Recolección
---------------------------------------------------------------------------
local Ruta = Rc.Ruta
local Cm = A.Compat
local real = { mw = Cm.MapToWorld, pi = Cm.GetPlayerInfo, pos = Cm.GetPlayerMapPosition, zona = Cm.GetUnitZone }
Cm.MapToWorld = function(m, x, y) return real.mw(m, x, y, "e") end
local yo = { 1437, 52, 48 } -- Los Humedales
Cm.GetPlayerMapPosition = function() return yo[1], yo[2], yo[3] end
Cm.GetUnitZone = function() return yo[1] end
Cm.GetPlayerInfo = function() local p = real.pi and real.pi() or {} p.level, p.faction = 30, "Alliance" return p end
local function esperarRuta()
  for _ = 1, 200 do if not Ruta.Calculando() then break end RUN_TIMERS(0.05) FIRE(UIParent, "OnUpdate", 0.05) end
  RUN_TIMERS(1)
end
local habilidad = { mineria = 70 }
local habReal = Rc.R.Habilidad
Rc.R.Habilidad = function(t) return habilidad[t] end

PASO("7. Dónde subir Minería: lo que te da puntos, en la mejor zona, con su ruta", function()
  local Su = Rc.Subir
  REVISA(Su and Su.Llevar, "no existe Recolección/Subir.lua") if not Su then return end
  local fuertes, flojas = Su.Claves("mineria", 70)
  local set = {}
  for _, c in ipairs(fuertes) do set[c] = "f" end
  for _, c in ipairs(flojas) do set[c] = "v" end
  REVISA(set.tin_vein == "f", "con 70 el estaño no cuenta como lo que da puntos")
  REVISA(set.copper_vein == "v", "con 70 el cobre (verde) no cuenta la mitad")
  REVISA(set.iron_deposit == nil, "con 70 ofreció hierro (no lo puedes minar)")
  limpiar()
  local ok, z = Su.Llevar("mineria")
  REVISA(ok and z, "no armó la ruta para subir Minería")
  esperarRuta()
  local r = Ruta.Actual()
  REVISA(r and type(r.recurso) == "table" and r.recurso.tin_vein, "la ruta no pasa por el estaño")
  REVISA(r and r.guiando, "la ruta para subir no empezó a guiar")
  local o = avisoCon("recoleccion.subir")
  REVISA(o and tostring(o.texto):find("Filón de estaño", 1, true), "el aviso no dice qué te da puntos: " .. tostring(o and o.texto))
  Ruta.Borrar()
  -- La página de Recolección con «Subir Minería» en su tarjeta (sin errores).
  N.Abrir("recoleccion")
  TIEMPO(1)
  habilidad.mineria = 300
  ok = Su.Llevar("mineria")
  REVISA(not ok, "con 300 de Minería quiso llevarte a subir")
  habilidad.mineria = nil
  ok = Su.Llevar("mineria")
  REVISA(not ok, "sin Minería quiso llevarte a subir")
  habilidad.mineria = 70
end)

PASO("8. Lo que recolectaste hace poco se ve tenue y su cuadro dice hace cuánto", function()
  local P, R = Rc.P, Rc.R
  REVISA(P and P.Reciente, "Pines.lua no sabe lo reciente") if not (P and P.Reciente) then return end
  local g = Rc.porClave.tin_vein
  local j, rec = R.Registrar(g, 1437, 0.5123, 0.4321, 1732)
  REVISA(rec and P.Reciente(rec) == 0, "lo recién recolectado no cuenta como reciente")
  local f = CreateFrame("Frame", nil, UIParent)
  P.Construir(f)
  P.Aplicar(f, g, 16, false, nil, true)
  REVISA(math.abs(f:GetAlpha() - 0.38) < 0.01, "el pin recién recolectado no se ve tenue: " .. f:GetAlpha())
  P.Aplicar(f, g, 16, false, nil, false)
  REVISA(f:GetAlpha() == 1, "el pin no volvió a verse normal")
  -- El cuadro.
  local lineas = {}
  local add = GameTooltip.AddLine
  GameTooltip.AddLine = function(self, t, ...) lineas[#lineas + 1] = tostring(t) return add(self, t, ...) end
  P.Info(f, R.Indice(1437), j)
  GameTooltip.AddLine = add
  REVISA(table.concat(lineas, "|"):find("hace un momento", 1, true), "el cuadro no dice que lo recolectaste hace un momento: " .. table.concat(lineas, " | "))
  rec.t = time() - 9 * 60
  REVISA(P.Reciente(rec) == nil, "tras 9 minutos sigue contando como reciente")
  rec.t = time() - 3 * 60
  REVISA(P.Reciente(rec) == 3, "no dice hace 3 minutos")
  A.Set("recoleccion.recientes", false)
  REVISA(P.Reciente(rec) == nil, "con el ajuste apagado sigue atenuando")
  A.Set("recoleccion.recientes", true)
  f:Hide()
end)

PASO("9. Mayús+clic en un pin del mapa arma la ruta por ese recurso", function()
  local Mp = Rc.Mapa
  REVISA(Mp and Mp.RutaDe, "Mapa.lua no sabe armar la ruta de un pin") if not (Mp and Mp.RutaDe) then return end
  local g = Rc.porClave.tin_vein
  REVISA(Mp.RutaDe(g, 1437), "Mayús+clic no armó la ruta del estaño en Los Humedales")
  esperarRuta()
  local r = Ruta.Actual()
  REVISA(r and r.recurso == "tin_vein" and r.mapa == 1437, "la ruta no es la del estaño en esa zona")
  REVISA(r and r.guiando, "la ruta del pin no empezó a guiar")
  Ruta.Borrar()
end)
Rc.R.Habilidad = habReal
Cm.MapToWorld, Cm.GetPlayerInfo, Cm.GetPlayerMapPosition, Cm.GetUnitZone = real.mw, real.pi, real.pos, real.zona

---------------------------------------------------------------------------
-- Pesca
---------------------------------------------------------------------------
PASO("10. Qué pica aquí: tus capturas en este lugar y tus lugares que más dejan", function()
  local Aq = Pe.Aqui
  REVISA(Aq and Aq.Aqui, "no existe Pesca/Aqui.lua") if not Aq then return end
  local d = N.DatosPersonaje("pesca")
  d.lugares = { "Bosque de Elwynn", "Lago de Cristal", "Páramos de Poniente", "La costa" }
  d.registro = {}
  local BAGRE, SALMON, CAJA = 6309, 6361, 6351
  local function capturas(id, n, z, s) for _ = 1, n do d.registro[#d.registro + 1] = { t = time(), id = id, n = 1, z = z, s = s } end end
  capturas(BAGRE, 9, 1, 2) capturas(SALMON, 6, 1, 2) capturas(CAJA, 3, 3, 4) capturas(BAGRE, 15, 3, 4)
  Pe.Diario()[BAGRE] = { n = 24, nombre = "Bagre" }
  Pe.Diario()[SALMON] = { n = 6, nombre = "Salmón" }
  local valor = Pe.ValorDe
  Pe.ValorDe = function(id) if id == CAJA then return 500, 2000 end return 10, nil end
  local lugar = Pe.Lugar
  Pe.Lugar = function() return "Bosque de Elwynn", "Lago de Cristal" end
  local a = Aq.Aqui()
  REVISA(a.total == 15 and a.lugar == "Lago de Cristal", ("no cuenta las 15 capturas del lago: %d en %s"):format(a.total, tostring(a.lugar)))
  REVISA(a.lista[1] and a.lista[1].nombre == "Bagre" and math.floor(a.lista[1].pct * 100 + 0.5) == 60, "el bagre no sale primero con 60 %")
  REVISA(Aq.Corto(a, 2) == "Bagre 60 %, Salmón 40 %", "el resumen corto no cuadra: " .. Aq.Corto(a, 2))
  local m = Aq.Mejores(3)
  REVISA(m[1] and m[1].lugar:find("La costa", 1, true), "tu mejor lugar no es la costa (cajas de 20p): " .. tostring(m[1] and m[1].lugar))
  -- En la barra: la fila «Qué pica aquí» en «Más de la pesca», y su menú.
  local B = Pe.Barra
  local c = B.MENUS.mas()
  REVISA(c.filas[1] and c.filas[1].nombre == "Qué pica aquí" and tostring(c.filas[1].valor):find("Bagre 60", 1, true),
    "«Más de la pesca» no trae «Qué pica aquí»: " .. tostring(c.filas[1] and c.filas[1].nombre))
  local mm = B.MENUS.aqui()
  REVISA(mm and mm.titulo:find("Lago de Cristal", 1, true) and #mm.filas >= 2, "el menú de «Qué pica aquí» no sale bien")
  -- Abrir el menú desde la fila (no se rompe).
  if c.filas[1] and c.filas[1].alClic then c.filas[1].alClic(c.filas[1], "LeftButton") end
  B.CerrarMenu()
  -- Donde nunca pescaste, lo dice.
  Pe.Lugar = function() return "Tanaris", nil end
  a = Aq.Aqui()
  REVISA(a.total == 0, "contó capturas donde nunca pescaste")
  REVISA(B.MENUS.aqui().nota:find("Aún no pescas aquí", 1, true), "el menú vacío no dice qué hacer")
  -- /alfa pesca aqui
  Pe.Lugar = function() return "Bosque de Elwynn", "Lago de Cristal" end
  Pe.Comando("aqui")
  Pe.ValorDe, Pe.Lugar = valor, lugar
end)

-- Siempre al final: nada de Alfa se queda tapando el ratón.
PASO("el ratón sigue siendo del jugador", function() TIEMPO(5) RATON_LIMPIO("al final") end)

PRUEBA_FIN()
