-- Prueba de la 1.2.9, Bolsas y Comercio:
--   * «Ponte esto»: el aviso con «Ponérmelo» cuando llega equipo mejor (del
--     vigía del motor o mirando las bolsas), nada en combate (sale al
--     terminar) y ponerlo solo con el clic; el ajuste lo apaga;
--   * la lista de compras: una meta por receta (de la guía), cuánto tienes y
--     cuánto falta, las palomitas al juntar con su aviso, sumar, quitar,
--     vaciar, lo que falta para subir un oficio y AlfaComercio.Lista;
--   * oficios de 1 a 300: los pasos, lo que falta, el siguiente rango y la
--     ventana con su guía;
--   * subastar fácil: el panel con el precio sugerido, el historial de días
--     y el aviso de precio bajo;
--   * qué guardar: materiales de las recetas de otro personaje, objetos de
--     las misiones de otro y equipo que tu clase no usa, con «Al banco».
-- Las funciones del juego que faltan (bolsas, banco, subasta, equipo) son de
-- mentira y viven aquí.
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
local function check(cond, msg) if not cond then NOTE("1.2.9 comercio", msg) end end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit

---------------------------------------------------------------------------
-- El juego de mentira: bolsas (0) y banco (6), equipo y subasta
---------------------------------------------------------------------------

local bolsas = { [0] = {}, [6] = {} }
local function poner(b, s, id, n, extra)
  local e = { itemID = id, stackCount = n or 1, quality = 1, hyperlink = "|cffffffff|Hitem:" .. id .. "::::::::|h[Objeto " .. id .. "]|h|r", isBound = false }
  for k, v in pairs(extra or {}) do e[k] = v end
  bolsas[b][s] = e
end
local function vaciar() bolsas[0], bolsas[6] = {}, {} end
local usados = {}
-- Se cambian las funciones de la tabla del juego (algunos archivos la guardan al cargar).
local falso = {
  GetContainerNumSlots = function(b) if b == 0 then return 16 elseif b == 6 then return 28 end return 0 end,
  GetContainerNumFreeSlots = function(b)
    local t, n = bolsas[b], 0
    if not t then return 0, 0 end
    for s = 1, (b == 0 and 16 or 28) do if not t[s] then n = n + 1 end end
    return n, 0
  end,
  CalculateTotalNumberOfFreeBagSlots = function() return 10 end,
  GetContainerItemInfo = function(b, s) return bolsas[b] and bolsas[b][s] end,
  GetContainerItemQuestInfo = function() return { isQuestItem = false } end,
  GetContainerItemLink = function(b, s) local i = bolsas[b] and bolsas[b][s] return i and i.hyperlink end,
  GetContainerItemID = function(b, s) local i = bolsas[b] and bolsas[b][s] return i and i.itemID end,
  UseContainerItem = function(b, s) usados[#usados + 1] = { b, s } if bolsas[b] then bolsas[b][s] = nil end end,
  ContainerIDToInventoryID = function(b) return b + 19 end,
  GetBagName = function() return nil end,
}
C_Container = C_Container or {}
for k, v in pairs(falso) do C_Container[k] = v end
local LOC = { [9001] = "INVTYPE_CHEST", [9002] = "INVTYPE_HEAD", [9003] = "INVTYPE_LEGS" }
local instante = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(id)
  id = tonumber(tostring(id):match("item:(%d+)") or id)
  if LOC[id] then return id, "Armadura", "Tela", LOC[id], 134400, 4, 1 end
  if instante then return instante(id) end
  return id, "Objeto", "Objeto", "", 134400, 0, 0
end
C_Item.GetItemMaxStackSizeByID = function() return 20 end
local puestos = {}
C_Item.EquipItemByName = function(link, slot) puestos[#puestos + 1] = { link, slot } end
C_Item.GetItemID = function(loc) return loc and loc.id end
C_Item.DoesItemExist = function(loc) return loc ~= nil end

-- Los avisos se anotan en lugar de verse.
local avisos = {}
local avisoReal = K.Aviso
K.Aviso = function(o) avisos[#avisos + 1] = o return {} end
local function buscarAviso(titulo)
  for i = #avisos, 1, -1 do if avisos[i].titulo == titulo then return avisos[i] end end
  return nil
end

if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local C = NS_OF("Alfa_Comercio")
local B = NS_OF("Alfa_Bolsas")
local Mj, Gu, Li, Of, Ve = B.Mejora, B.Guardar, C.Lista, C.Oficios, C.Vender

local function bolsasCambian()
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(4)
end

---------------------------------------------------------------------------
-- 6. «Ponte esto»
---------------------------------------------------------------------------

local Q = A.QoL or {}
local wearReal = Q.Wear
local oferta
local tomadas = 0
step("Ponte esto: el aviso del vigía del motor y Ponérmelo", function()
  check(Mj and Mj.Revisar, "falta Mejora.lua") if not Mj then return end
  check(A.Get("bolsas.ponteEsto") == true, "bolsas.ponteEsto no viene prendido")
  A.QoL = Q
  Q.Wear = { Offer = function() return oferta end, Take = function() tomadas = tomadas + 1 oferta = nil end }
  A.Set("qol.wearOffer", true)
  avisos = {}
  oferta = { id = 9001, link = "|cff1eff00|Hitem:9001::::::::|h[Túnica del lobo]|h|r", slot = 5, pct = 12 }
  A.Fire("WEAR_OFFER")
  RUN_TIMERS(3)
  local a = buscarAviso("Ponte esto")
  check(a, "no salió «Ponte esto»")
  check(a and a.texto:find("Túnica del lobo", 1, true), "el aviso no nombra la pieza: " .. tostring(a and a.texto))
  check(a and a.accion and a.accion.texto == "Ponérmelo", "el aviso no trae «Ponérmelo»")
  check(tomadas == 0 and #puestos == 0, "se puso algo sin el clic del jugador")
  if a and a.accion then a.accion.alClic() end
  check(tomadas == 1, "Ponérmelo no se lo puso (vigía del motor)")
  -- La misma oferta otra vez: no se repite el aviso.
  local n = #avisos
  oferta = { id = 9001, link = "|cff1eff00|Hitem:9001::::::::|h[Túnica del lobo]|h|r", slot = 5, pct = 12 }
  A.Fire("WEAR_OFFER")
  RUN_TIMERS(3)
  check(#avisos == n, "avisó dos veces de la misma pieza")
  oferta = nil
end)

step("Ponte esto: nada en combate; sale al terminar", function()
  avisos = {}
  local combate = InCombatLockdown
  InCombatLockdown = function() return true end
  oferta = { id = 9002, link = "|cff0070dd|Hitem:9002::::::::|h[Yelmo del alfa]|h|r", slot = 1, pct = 8 }
  A.Fire("WEAR_OFFER")
  RUN_TIMERS(3)
  check(not buscarAviso("Ponte esto"), "salió el aviso en combate")
  InCombatLockdown = combate
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  RUN_TIMERS(2)
  local a = buscarAviso("Ponte esto")
  check(a and a.texto:find("Yelmo del alfa", 1, true), "no salió al terminar el combate")
  -- Clic en combate: espera y se pone al terminar.
  InCombatLockdown = function() return true end
  local r = Mj.Poner({ id = 9002, link = "item:9002", slot = 1 })
  check(r == "espera" and #puestos == 0, "se intentó poner en combate")
  InCombatLockdown = combate
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  RUN_TIMERS(2)
  check(#puestos == 1 and puestos[1][2] == 1, "no se lo puso al terminar el combate")
  oferta = nil
end)

step("Ponte esto: sin el vigía del motor, Alfa mira las bolsas", function()
  local G = A.Gear or {}
  A.Gear = G
  local real = { IsEnabled = G.IsEnabled, IsUpgrade = G.IsUpgrade, CompareToEquipped = G.CompareToEquipped }
  local E = Q.Equip
  local placement = E and E.Placement
  if E then E.Placement = nil end
  G.IsEnabled = function() return true end
  G.IsUpgrade = function(link) if tostring(link):find("item:9003", 1, true) then return true, 10, 15 end return false end
  G.CompareToEquipped = function(link) return { slot = 7, usable = true } end
  A.Set("qol.wearOffer", false)
  RUN_TIMERS(2)
  avisos, puestos = {}, {}
  vaciar()
  bolsasCambian()
  poner(0, 3, 9003, 1, { hyperlink = "|cff1eff00|Hitem:9003::::::::|h[Calzas de cazador]|h|r", quality = 2 })
  bolsasCambian()
  local a = buscarAviso("Ponte esto")
  check(a and a.texto:find("Calzas de cazador", 1, true), "sin el vigía no avisó de la pieza nueva")
  check(#puestos == 0, "se puso sola")
  if a and a.accion then a.accion.alClic() end
  check(#puestos == 1 and puestos[1][2] == 7, "Ponérmelo no llamó a EquipItemByName con su ranura")
  -- Apagado: nada.
  A.Set("bolsas.ponteEsto", false)
  RUN_TIMERS(1)
  avisos = {}
  poner(0, 4, 9003, 1, { hyperlink = "|cff1eff00|Hitem:9003::::::::|h[Calzas de cazador]|h|r", quality = 2 })
  bolsasCambian()
  check(not buscarAviso("Ponte esto"), "avisó con el ajuste apagado")
  A.Set("bolsas.ponteEsto", true)
  A.Set("qol.wearOffer", true)
  G.IsEnabled, G.IsUpgrade, G.CompareToEquipped = real.IsEnabled, real.IsUpgrade, real.CompareToEquipped
  if E then E.Placement = placement end
  Q.Wear = wearReal
  vaciar()
  bolsasCambian()
end)

---------------------------------------------------------------------------
-- 17. La lista de compras
---------------------------------------------------------------------------

local PAZ, HOJA, VIAL, POCION = 2447, 765, 3371, 118
step("Lista de compras: una receta, cuánto tienes y cuánto falta", function()
  check(Li and Li.Agregar, "falta Lista.lua") if not Li then return end
  check(type(AlfaComercio) == "table" and type(AlfaComercio.Lista) == "table" and type(AlfaComercio.Lista.Agregar) == "function", "falta AlfaComercio.Lista.Agregar")
  check(type(AlfaBolsas) == "table" and type(AlfaBolsas.Cuantos) == "function", "falta AlfaBolsas.Cuantos")
  Li.Vaciar()
  vaciar()
  poner(0, 1, PAZ, 3)
  poner(6, 1, HOJA, 2) -- en el banco
  FIRE_EVENT("BANKFRAME_OPENED")
  RUN_TIMERS(2)
  check(AlfaBolsas.Cuantos(HOJA) == 2, "Cuantos no cuenta el banco (" .. tostring(AlfaBolsas.Cuantos(HOJA)) .. ")")
  FIRE_EVENT("BANKFRAME_CLOSED")
  RUN_TIMERS(2)
  check(AlfaComercio.Lista.Agregar(POCION, 5), "no agregó la poción")
  local mats, listos, total = Li.Materiales()
  check(total == 3, "la poción pide 3 materiales y salen " .. total)
  local por = {}
  for _, x in ipairs(mats) do por[x.id] = x end
  check(por[PAZ] and por[PAZ].necesita == 5 and por[PAZ].tienes == 3 and por[PAZ].faltan == 2, "Flor de paz: no cuenta 3 de 5")
  local foto = B.Datos.Actual().banco[6]
  check(por[HOJA] and por[HOJA].tienes == 2, "Hojaplata: no cuenta lo del banco (foto): " .. tostring(por[HOJA] and por[HOJA].tienes) .. " foto " .. tostring(foto and foto.n) .. " " .. tostring(foto and foto[1] and foto[1].i))
  check(por[VIAL] and por[VIAL].faltan == 5, "Vial: no faltan 5")
  check(listos == 0, "algo salió listo sin tenerlo")
  -- La misma meta otra vez se suma.
  Li.Agregar(POCION, 5)
  check(#Li.Metas() == 1 and Li.Metas()[1].n == 10, "la misma meta no se sumó")
  Li.Quitar(1)
  Li.Agregar(POCION, 5)
end)

step("Lista de compras: las palomitas se llenan al juntar", function()
  avisos = {}
  poner(0, 2, PAZ, 2)
  bolsasCambian()
  local mats, listos = Li.Materiales()
  check(listos == 1, "Flor de paz no quedó lista (" .. listos .. ")")
  local a = buscarAviso("Lista de compras")
  check(a and a.texto:find("Te faltan 2 de 3", 1, true), "no avisó del material completo: " .. tostring(a and a.texto))
  poner(0, 3, HOJA, 3)
  poner(0, 4, VIAL, 5)
  bolsasCambian()
  check(Li.Completa(), "la lista no quedó completa")
  check(buscarAviso("¡Tu lista de compras está completa!"), "no avisó de la lista completa")
  -- El ajuste apaga los avisos.
  A.Set("comercio.listaAviso", false)
  avisos = {}
  bolsas[0][4] = nil
  bolsasCambian()
  poner(0, 4, VIAL, 5)
  bolsasCambian()
  check(not buscarAviso("¡Tu lista de compras está completa!"), "avisó con el ajuste apagado")
  A.Set("comercio.listaAviso", true)
  -- Sin receta conocida: la meta es juntar ese objeto.
  Li.Agregar(2589, 20)
  local por = {}
  for _, x in ipairs((Li.Materiales())) do por[x.id] = x end
  check(por[2589] and por[2589].necesita == 20, "una meta sin receta no pide el objeto mismo")
  local donde = Li.Donde(PAZ)
  check(donde == nil or type(donde) == "string", "Donde no devuelve texto")
end)

---------------------------------------------------------------------------
-- 29. Oficios de 1 a 300
---------------------------------------------------------------------------

local compat = A.Compat.GetSkillRank
local habilidades = {}
step("Oficios: pasos, lo que falta y el siguiente rango", function()
  check(Of and Of.Pasos, "falta Oficios.lua") if not Of then return end
  A.Compat.GetSkillRank = function(l) local h = habilidades[l] if h then return h[1], h[2] end return nil end
  local G = C.OFICIOS_GUIA
  for _, linea in ipairs(G.ORDEN) do
    local g = G[linea]
    check(g and #g.pasos >= 4, "la guía de " .. tostring(linea) .. " tiene pocos pasos")
    local ultimo = 1
    for _, p in ipairs(g.pasos) do
      check(p[1] == ultimo or (p[1] == ultimo and p[2] > p[1]), (g.nombre or "?") .. ": un tramo no sigue al anterior (" .. p[1] .. ")")
      check(p[2] > p[1], (g.nombre or "?") .. ": un tramo vacío")
      ultimo = p[2]
    end
    check(ultimo == 300, (g.nombre or "?") .. " no llega a 300")
  end
  check(#G.ORDEN == 11, "no están los 11 oficios")
  -- Sin aprender: «Aprende Alquimia».
  local r = Of.Rango(171, nil, nil)
  check(r.titulo == "Aprende Alquimia", "sin el oficio no dice «Aprende»: " .. tostring(r.titulo))
  -- 60 de 75, nivel 23: ya puede aprender Oficial.
  habilidades[171] = { 60, 75 }
  r = Of.Rango(171, 60, 75)
  check(r.puede and r.titulo:find("Oficial", 1, true), "con 60/75 no dice que ya puede aprender Oficial")
  -- 130 de 150 a nivel 23: Experto pide 125 y nivel 20.
  r = Of.Rango(171, 130, 150)
  check(r.puede and r.titulo:find("Experto", 1, true), "con 130/150 no puede Experto")
  r = Of.Rango(171, 210, 225)
  check(not r.puede and r.texto:find("nivel 35", 1, true), "Artesano no pide el nivel 35: " .. tostring(r.texto))
  local pasosA = Of.Pasos(171, 60)
  check(pasosA[1].estado == "hecho" and pasosA[2].estado == "actual" and pasosA[3].estado == "falta", "los estados de los pasos no salen")
  local faltan = Of.Faltan(171, 60)
  local por = {}
  for _, x in ipairs(faltan) do por[x.id] = x end
  check(por[2450] and por[2450].necesita >= 55, "a Alquimia le falta Zarzaespina")
  check(not por[118], "la poción menor (otro paso) no se cambió por sus materiales")
  check(por[2447] and por[765], "la poción menor no se cambió por Flor de paz y Hojaplata")
  check(#Of.Faltan(171, 300) == 0, "con 300 todavía falta algo")
  check(#Of.Faltan(182, 10) == 0, "Herboristería (de juntar) pide materiales")
  check(Of.Rango(171, 300, 300).tope, "300/300 no es el tope")
end)

step("Oficios: la ventana y Agregar lo que me falta", function()
  local VO = C.VentanaOficios
  check(VO and VO.Abrir, "falta VentanaOficios.lua") if not VO then return end
  check(VO.Abrir(171) and VO.Visible() and VO.Linea() == 171, "la ventana de oficios no abrió en Alquimia")
  RUN_TIMERS(2)
  VO.Abrir(182)
  RUN_TIMERS(2)
  check(VO.Linea() == 182, "no cambió a Herboristería")
  VO.Abrir(393)
  RUN_TIMERS(2)
  Li.Vaciar()
  check(Li.AgregarOficio(171), "no agregó lo que falta para Alquimia")
  local m = Li.Metas()[1]
  check(m and m.oficio == 171 and m.total, "la meta del oficio no quedó")
  check(Li.NombreMeta(m) == "Subir Alquimia", "la meta no se llama «Subir Alquimia»")
  check(not Li.AgregarOficio(182), "agregó materiales para un oficio de juntar")
  VO.Ventana():Cerrar()
  AlfaNucleo.Abrir("comercio")
  RUN_TIMERS(3)
  Li.Vaciar()
  AlfaNucleo.Abrir("comercio")
  RUN_TIMERS(3)
  A.Compat.GetSkillRank = compat
end)

---------------------------------------------------------------------------
-- 30. Subastar fácil
---------------------------------------------------------------------------

local ID = 2772
local enVenta, precio = nil, nil
step("Subastar fácil: precio sugerido, historial y aviso de precio bajo", function()
  check(Ve and Ve.Leer, "falta Vender.lua") if not Ve then return end
  C_AuctionHouse = C_AuctionHouse or {}
  C_AuctionHouse.ReplicateItems = C_AuctionHouse.ReplicateItems or function() end
  C_AuctionHouse.GetNumReplicateItems = C_AuctionHouse.GetNumReplicateItems or function() return 0 end
  C_AuctionHouse.GetReplicateItemInfo = C_AuctionHouse.GetReplicateItemInfo or function() return nil end
  local AH = CreateFrame("Frame", "AuctionHouseFrame", UIParent)
  AH:SetSize(800, 540)
  AH:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -80)
  AH.CommoditiesSellFrame = CreateFrame("Frame", nil, AH)
  AH.ItemSellFrame = CreateFrame("Frame", nil, AH)
  AH.ItemSellFrame:Hide()
  function AH.CommoditiesSellFrame:GetItem() return enVenta end
  function AH.CommoditiesSellFrame:GetUnitPrice() return precio end
  -- El historial: cinco días de precios.
  local r = C.Reino()
  local hoy = time()
  for i, p in ipairs({ 900, 1100, 1000, 1200, 1000 }) do C.Anotar(ID, p, 10, 1, hoy - (5 - i) * 86400, r) end
  local lista, bajo, prom, alto = Ve.Historial(ID)
  check(#lista == 5 and bajo == 900 and alto == 1200 and prom == 1040, "el historial no sale bien (" .. #lista .. ", " .. tostring(prom) .. ")")
  FIRE_EVENT("AUCTION_HOUSE_SHOW")
  RUN_TIMERS(3)
  check(not Ve.Estado(), "el panel salió sin nada en venta")
  enVenta, precio = { id = ID }, 950
  RUN_TIMERS(3)
  local e = Ve.Estado()
  check(e and e.id == ID and e.sugerido == 1000, "no sugiere el último precio (" .. tostring(e and e.sugerido) .. ")")
  check(e and not e.bajo, "avisó de precio bajo con 950 de 1000")
  check(Ve.Panel() and Ve.Panel():IsShown(), "el panel no se ve")
  precio = 500
  RUN_TIMERS(3)
  e = Ve.Estado()
  check(e and e.bajo and math.floor(e.bajo * 100 + 0.5) == 50, "no avisó del precio 50 % más bajo")
  local p = Ve.Panel()
  check(p and p.Aviso:IsShown() and tostring(p.Aviso:GetText()):find("50 %", 1, true), "el panel no dice el aviso: " .. tostring(p and p.Aviso:GetText()))
  check(p and tostring(p.Historia:GetText()):find("5 días", 1, true), "el panel no muestra los 5 días")
  -- El umbral: con 60 % ya no avisa.
  A.Set("comercio.precioBajo", 60)
  RUN_TIMERS(3)
  check(Ve.Estado() and not Ve.Estado().bajo, "avisó con el umbral en 60 %")
  A.Set("comercio.precioBajo", 30)
  -- Apagado: el panel se va.
  A.Set("comercio.vender", false)
  RUN_TIMERS(3)
  check(not (Ve.Panel() and Ve.Panel():IsShown()), "el panel sigue con el ajuste apagado")
  A.Set("comercio.vender", true)
  RUN_TIMERS(3)
  check(Ve.Panel() and Ve.Panel():IsShown(), "el panel no volvió al prenderlo")
  FIRE_EVENT("AUCTION_HOUSE_CLOSED")
  RUN_TIMERS(2)
  check(not Ve.Panel():IsShown(), "el panel siguió con la subasta cerrada")
end)

---------------------------------------------------------------------------
-- 18. Qué guardar
---------------------------------------------------------------------------

step("Qué guardar: recetas y misiones de otro personaje, equipo que no usas", function()
  check(Gu and Gu.Sugerencias, "falta Guardar.lua") if not Gu then return end
  check(A.Get("bolsas.queGuardar") == true, "bolsas.queGuardar no viene prendido")
  -- El otro personaje: sus recetas (Comercio) y sus misiones (Bolsas).
  local d = C.Datos()
  d.recetas = d.recetas or {}
  d.recetas["Brisa-Forever"] = { rk = C.ClaveReino(), nombre = "Brisa", profs = {},
    r = { [3304] = { n = "Fundir cobre", o = 2840, q = 1, r = { 2770, 1 }, p = "Minería" } } }
  C.RecetasCambiaron()
  local Dt = B.Datos
  Dt.Raiz().personajes["Brisa-Forever"] = { nombre = "Brisa", reino = "Forever", clase = "MAGE", nivel = 12, bolsas = {}, banco = {}, equipo = {}, misiones = { 11 } }
  local G = A.Gear or {}
  A.Gear = G
  local comparar = G.CompareToEquipped
  G.CompareToEquipped = function(link) if tostring(link):find("item:9001", 1, true) then return { usable = false } end return { usable = true } end
  vaciar()
  poner(0, 1, 2770, 10)                               -- mena de cobre: para Brisa
  poner(0, 2, 782, 4)                                 -- brazal gnoll: misión de Brisa
  poner(0, 3, 9001, 1, { quality = 2, isBound = false }) -- equipo BoE que no usas
  poner(0, 4, 9001, 1, { quality = 2, isBound = true })  -- ese mismo, ligado: se queda
  poner(0, 5, 6948, 1)                                -- la piedra de hogar nunca
  local lista = Gu.Sugerencias()
  local por = {}
  for _, x in ipairs(lista) do por[x.casilla] = x end
  check(por[1] and por[1].tipo == "oficio" and por[1].motivo:find("Brisa (Minería)", 1, true), "no sugiere la mena para las recetas de Brisa: " .. tostring(por[1] and por[1].motivo))
  check(por[2] and por[2].tipo == "mision" and por[2].motivo:find("Brisa", 1, true), "no sugiere el objeto de la misión de Brisa")
  check(por[3] and por[3].tipo == "equipo", "no sugiere el equipo que tu clase no usa")
  check(not por[4], "sugirió equipo ya ligado")
  check(not por[5], "sugirió la piedra de hogar")
  -- Sin banquero no se mueve nada.
  usados = {}
  check(not Gu.AlBanco(), "depositó sin banquero")
  check(#usados == 0, "movió algo sin banquero")
  -- Con el banquero: «Al banco» con el clic.
  FIRE_EVENT("BANKFRAME_OPENED")
  RUN_TIMERS(2)
  AlfaNucleo.Abrir("bolsas")
  RUN_TIMERS(3)
  check(Gu.AlBanco(), "Al banco no empezó")
  RUN_TIMERS(5)
  check(#usados == 3, "Al banco no depositó las 3 sugerencias (" .. #usados .. ")")
  FIRE_EVENT("BANKFRAME_CLOSED")
  RUN_TIMERS(2)
  -- Apagado: nada que sugerir.
  poner(0, 1, 2770, 10)
  A.Set("bolsas.queGuardar", false)
  check(#Gu.Sugerencias() == 0, "sugiere con el ajuste apagado")
  A.Set("bolsas.queGuardar", true)
  G.CompareToEquipped = comparar
  vaciar()
end)

step("Las páginas de Bolsas y Comercio con todo", function()
  Li.Agregar(POCION, 3)
  AlfaNucleo.Abrir("bolsas")
  RUN_TIMERS(3)
  AlfaNucleo.Abrir("comercio")
  RUN_TIMERS(3)
  Li.Vaciar()
  RUN_TIMERS(2)
end)

K.Aviso = avisoReal
print(string.format("PRUEBA: 1.2.9 comercio y bolsas, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
