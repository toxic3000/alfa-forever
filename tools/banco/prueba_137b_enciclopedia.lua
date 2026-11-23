-- Prueba de la 1.3.7 (segunda tanda), área «enciclopedia»:
--   1. el cuadro de un objeto no sale antes del retraso (0,6 s quieto), ni si
--      el ratón se sigue moviendo, y sale sin las comparaciones del juego;
--      con Mayús sale el del juego (que compara solo); «nunca» y «ya»;
--   2. el clic derecho trae su menú (comparar con mi equipo, comparar con…,
--      ver ficha, guíame, lista de compras, vincular) y comparar pone tu pieza
--      al lado y se queda hasta que sale otro cuadro;
--   3. las filas de la lista de la Enciclopedia usan lo mismo (retraso y menú);
--   4. Comercio: la barra de la subasta no se encima en las pestañas
--      (Comprar, Vender, Subastas), no sale con la ventana del vendedor, se
--      encoge sola al terminar y nunca corta su texto.
SNAPSHOTS = {}
local function step(nombre, fn, ...)
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.3.7b enciclopedia", msg) end end
local function T(n) RUN_TIMERS(n or 1) end

local N = AlfaNucleo
local A = N.A
local K = N.Kit
-- Entrar como alguien que ya terminó la bienvenida (si no, abre la bienvenida).
FIRE_EVENT("PLAYER_LOGIN")
local Bv = rawget(_G, "AlfaBienvenida")
N.Datos("bienvenida").respondio = Bv and Bv.VERSION or 99
N.Datos("bienvenida").versionVista = Bv and Bv.VersionAlfa and Bv.VersionAlfa() or "9.9.9"
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
local En = NS_OF("Alfa_Enciclopedia")
local Cu = En.Cuadro

---------------------------------------------------------------------------
-- El juego simulado: los cuadros (el propio y los del juego), el equipo y las bolsas
---------------------------------------------------------------------------
local vistos = {}
local function cuadroFalso(nombre)
  local t = CreateFrame("Frame", nombre, UIParent)
  t:Hide()
  function t:SetOwner(o) self._owner = o self.lineas = {} end
  function t:GetOwner() return self._owner end
  function t:SetHyperlink(l) self.link = l vistos[#vistos + 1] = nombre .. "=" .. tostring(l) end
  function t:SetSpellByID(id) self.link = "spell:" .. id end
  function t:SetInventoryItem(u, s) self.link = "puesto:" .. s return true end
  function t:SetBagItem(b, s) self.link = "bolsa:" .. b .. ":" .. s end
  function t:AddLine(x) self.lineas[#self.lineas + 1] = x end
  return t
end
local propio = cuadroFalso("AlfaEnciclopediaCuadro")
local cmp1 = cuadroFalso("AlfaEnciclopediaCuadroCompara1")
cuadroFalso("AlfaEnciclopediaCuadroCompara2")
local compra1 = cuadroFalso("ShoppingTooltip1")
local compra2 = cuadroFalso("ShoppingTooltip2")
-- El cuadro del juego compara solo (como con «comparar siempre»).
local tip = GameTooltip
tip:Hide()
local setOwnerReal = tip.SetOwner
tip.SetOwner = function(self, o) self._owner = o end
tip.SetHyperlink = function(self, l) self.link = l compra1:Show() compra2:Show() end
tip.SetSpellByID = function(self, id) self.link = "spell:" .. id end
tip:HookScript("OnHide", function() compra1:Hide() compra2:Hide() end)

local mayus = false
IsShiftKeyDown = function() return mayus end
local cx, cy = 300, 300
GetCursorPosition = function() return cx, cy end

-- Una espada (mano principal y secundaria), una caña (dos manos), un anillo.
local LOC = { [100] = "INVTYPE_WEAPON", [101] = "INVTYPE_2HWEAPON", [102] = "INVTYPE_FINGER", [200] = "INVTYPE_WEAPON", [201] = "INVTYPE_2HWEAPON", [202] = "INVTYPE_HEAD", [6256] = "INVTYPE_2HWEAPON" }
local instantReal = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(x)
  local id = tonumber(x)
  if id and LOC[id] then return id, "Arma", "Sub", LOC[id] end
  if instantReal then return instantReal(x) end
end
local puesto = { [16] = "|cff1eff00|Hitem:200::::::::|h[Espada puesta]|h|r" }
GetInventoryItemLink = function(u, s) return puesto[s] end
local bolsa = { [1] = { itemID = 201, hyperlink = "|cffffffff|Hitem:201::::::::|h[Caña vieja]|h|r" }, [2] = { itemID = 202, hyperlink = "|cffffffff|Hitem:202::::::::|h[Casco]|h|r" } }
C_Container = C_Container or {}
local ccReal = { C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo }
C_Container.GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end
C_Container.GetContainerItemInfo = function(b, s) if b == 0 then return bolsa[s] end end

local reloj = N.Reloj and N.Reloj.marco
local function tic(seg)
  NOW = NOW + (seg or 0)
  FIRE(reloj, "OnUpdate", seg or 0.1)
end

local fila = CreateFrame("Button", nil, UIParent)
fila:SetSize(300, 40)
fila:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)

---------------------------------------------------------------------------
-- 1. El retraso y sin comparaciones
---------------------------------------------------------------------------
BANCO_RELOJ_REAL = true
step("el cuadro espera 0,6 s quieto y sale sin comparar", function()
  check(Cu and Cu.Entrar, "falta Cuadro.lua") if not Cu then return end
  A.Set("enciclopedia.cuadro", "normal")
  check(Cu.Retraso() == 0.6, "el retraso de fábrica no es 0,6 s: " .. tostring(Cu.Retraso()))
  Cu.Entrar(fila, { item = 100 })
  check(not propio:IsShown() and not tip:IsShown(), "el cuadro salió en cuanto entró el ratón")
  check(Cu.Estado().pendiente, "no quedó esperando")
  tic(0.3)
  check(not propio:IsShown(), "el cuadro salió a los 0,3 s")
  tic(0.4)
  check(propio:IsShown(), "el cuadro no salió a los 0,7 s")
  check(propio.link == "item:100" and propio:GetOwner() == fila, "el cuadro no es del objeto ni de su fila")
  check(not compra1:IsShown() and not compra2:IsShown() and not tip:IsShown(), "salieron las comparaciones del juego sin Mayús")
  Cu.Salir(fila)
  check(not propio:IsShown(), "el cuadro no se fue al salir el ratón")
end)

step("si el ratón se sigue moviendo, espera a que se quede quieto", function()
  Cu.Entrar(fila, { item = 100 })
  cx = cx + 40
  tic(0.7)
  check(not propio:IsShown(), "salió con el ratón en movimiento")
  tic(0.3)
  check(propio:IsShown(), "no salió al quedarse quieto")
  Cu.Salir(fila)
  -- Salir antes del retraso: no sale nada después.
  Cu.Entrar(fila, { item = 100 })
  Cu.Salir(fila)
  tic(1)
  check(not propio:IsShown() and not tip:IsShown(), "salió un cuadro después de irse el ratón")
end)

step("con Mayús sale el del juego, que compara (como en tus bolsas)", function()
  Cu.Entrar(fila, { item = 100 })
  tic(0.1)
  mayus = true
  FIRE_EVENT("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
  check(tip:IsShown() and tip.link == "item:100", "Mayús no abrió el cuadro del juego al momento")
  check(compra1:IsShown(), "con Mayús no compara")
  check(not propio:IsShown(), "el cuadro propio siguió junto al del juego")
  mayus = false
  FIRE_EVENT("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
  check(propio:IsShown() and not tip:IsShown() and not compra1:IsShown(), "al soltar Mayús no volvió al cuadro sin comparar")
  Cu.Salir(fila)
  -- Entrar con Mayús ya apretada: al momento.
  mayus = true
  Cu.Entrar(fila, { item = 100 })
  check(tip:IsShown() and compra1:IsShown(), "entrar con Mayús no lo abrió al momento")
  mayus = false
  Cu.Salir(fila)
  check(not tip:IsShown() and not compra1:IsShown(), "el cuadro del juego no se fue al salir")
end)

step("el ajuste: «ya» y «nunca»", function()
  A.Set("enciclopedia.cuadro", "ya")
  Cu.Entrar(fila, { item = 100 })
  check(propio:IsShown(), "«al instante» no lo abrió al momento")
  Cu.Salir(fila)
  A.Set("enciclopedia.cuadro", "nunca")
  Cu.Entrar(fila, { item = 100 })
  tic(2)
  check(not propio:IsShown(), "«solo con Mayús» lo abrió solo")
  mayus = true
  FIRE_EVENT("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
  check(tip:IsShown(), "con «nunca» Mayús no lo abrió")
  mayus = false
  Cu.Salir(fila)
  A.Set("enciclopedia.cuadro", "normal")
  -- Un texto (filas de la ficha sin objeto) también espera.
  Cu.Entrar(fila, { titulo = "Un PNJ", texto = "Vendedor" })
  check(Cu.Estado().pendiente, "el cuadro de texto no espera")
  Cu.Salir(fila)
end)

---------------------------------------------------------------------------
-- 2. El menú del clic derecho y comparar
---------------------------------------------------------------------------
step("el menú del clic derecho y comparar con tu equipo", function()
  local fichas = 0
  local ops = Cu.Menu("item", 100, { dueno = fila, verFicha = function() fichas = fichas + 1 end })
  check(type(ops) == "table", "el menú no se armó") if type(ops) ~= "table" then return end
  local por = {}
  for _, o in ipairs(ops) do if o.valor then por[o.valor] = o end end
  for _, v in ipairs({ "equipo", "con", "ficha", "guiar", "compra", "vincular" }) do
    check(por[v] ~= nil, "al menú le falta «" .. v .. "»")
  end
  local menu = rawget(_G, "AlfaKitMenu")
  check(menu and menu:IsShown(), "el menú no se ve")
  check(por.equipo and not por.equipo.apagada, "«Comparar con mi equipo» apagado con una espada puesta")
  -- Elegirlo como lo hace el jugador (el clic en la fila del menú).
  local k
  for i, o in ipairs(menu.lista.datos) do if o.valor == "equipo" then k = i end end
  K.Llamar(menu.lista.alClic, menu.lista.datos[k])
  check(propio:IsShown() and propio.link == "item:100", "comparar no puso el cuadro del objeto")
  check(cmp1:IsShown() and cmp1.link == "puesto:16", "comparar no puso tu espada puesta al lado: " .. tostring(cmp1.link))
  check(not compra1:IsShown(), "comparar usó la comparación del juego (protegida)")
  check(Cu.Estado().fijo, "la comparación no se quedó")
  -- Se queda al pasar el ratón por otra fila, hasta que sale el cuadro de esa.
  local otra = CreateFrame("Button", nil, UIParent)
  Cu.Entrar(otra, { item = 101 })
  check(cmp1:IsShown(), "la comparación se fue al tocar otra fila")
  tic(0.7)
  check(not cmp1:IsShown() and propio.link == "item:101", "la comparación no dejó su lugar al cuadro nuevo")
  Cu.Salir(otra)
  -- Ver ficha.
  K.Llamar(por.ficha.fn)
  check(fichas == 1, "«Ver ficha» no abrió la ficha")
end)

step("comparar con… una pieza de tus bolsas", function()
  local piezas = Cu.Piezas(101)
  check(#piezas == 2, "la caña no encontró la espada puesta y la caña de la bolsa (" .. #piezas .. ")")
  local ops = Cu.Menu("item", 101, { dueno = fila })
  local con
  for _, o in ipairs(ops) do if o.valor == "con" then con = o end end
  check(con and not con.apagada, "«Comparar con…» apagado") if not con then return end
  local menu = rawget(_G, "AlfaKitMenu")
  local k
  for i, o in ipairs(menu.lista.datos) do if o.valor == "con" then k = i end end
  K.Llamar(menu.lista.alClic, menu.lista.datos[k])
  check(menu:IsShown() and #menu.lista.datos == 2, "no salió la lista de tus piezas")
  local deBolsa
  for _, o in ipairs(menu.lista.datos) do if o.pieza and o.pieza.bolsa then deBolsa = o end end
  check(deBolsa and tostring(deBolsa.texto):find("Caña vieja", 1, true), "la pieza de la bolsa no dice su nombre")
  K.Llamar(menu.lista.alClic, deBolsa)
  check(cmp1:IsShown() and cmp1.link == "bolsa:0:1", "no comparó con la caña de tu bolsa: " .. tostring(cmp1.link))
  Cu.Cerrar()
  check(not cmp1:IsShown() and not propio:IsShown(), "Cerrar no quitó la comparación")
  -- Un objeto que no se equipa: sin comparar, con lo demás.
  local o2 = Cu.Opciones("item", 4540, {})
  for _, o in ipairs(o2) do check(o.valor ~= "equipo" and o.valor ~= "con", "un objeto que no se equipa ofrece comparar") end
  -- Sin nada puesto en esa ranura: apagado y dice por qué.
  local o3 = Cu.Opciones("item", 102, {})
  for _, o in ipairs(o3) do
    if o.valor == "equipo" then check(o.apagada and o.motivo, "sin anillo puesto, «Comparar con mi equipo» no se apaga con su motivo") end
  end
  K.CerrarMenu()
end)

---------------------------------------------------------------------------
-- 3. La lista de la Enciclopedia
---------------------------------------------------------------------------
step("las filas de la lista: retraso y menú", function()
  local V = En.V
  V.Abrir({ texto = "espada" })
  BANCO_RELOJ_REAL = nil
  for _ = 1, 600 do
    if En.Cat.Listo(V.est.tipo) and not next(En.tareas) then break end
    T(1)
  end
  V.Filtrar()
  T(2)
  BANCO_RELOJ_REAL = true
  local lista = V.ui.lf and V.ui.lf.Lista
  local f = lista and lista.filas and lista.filas[1]
  if not (f and f.alfaI) then print("AVISO: la lista de la enciclopedia quedó vacía en el banco") V.Cerrar() return end
  local c = En.Cat.Col(V.est.tipo)
  local i = lista.datos[f.alfaI]
  FIRE(f, "OnEnter")
  local kind = c and En.Cat.Kind(c, i)
  if En.ES_OBJETO[kind] or kind == "mountspell" then
    check(Cu.Estado().pendiente and not propio:IsShown(), "la fila abrió el cuadro sin esperar")
    tic(0.7)
    check(propio:IsShown(), "la fila no abrió el cuadro tras el retraso")
    check(not compra1:IsShown(), "la fila abrió las comparaciones")
  end
  FIRE(f, "OnLeave")
  check(not propio:IsShown(), "el cuadro de la fila no se fue")
  f.alfaSobre = true
  FIRE(f, "OnClick", "RightButton")
  local menu = rawget(_G, "AlfaKitMenu")
  check(menu and menu:IsShown(), "el clic derecho en la fila no abrió el menú")
  local hay = false
  for _, o in ipairs(menu and menu.lista.datos or {}) do if o.valor == "ficha" then hay = true end end
  check(hay, "el menú de la fila no trae «Ver ficha»")
  K.CerrarMenu()
  f.alfaSobre = nil
  V.Cerrar()
  check(not propio:IsShown(), "al cerrar la ventana quedó un cuadro")
end)
BANCO_RELOJ_REAL = nil

GameTooltip.SetOwner = setOwnerReal
C_Item.GetItemInfoInstant = instantReal
C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo = ccReal[1], ccReal[2]

---------------------------------------------------------------------------
-- 4. Comercio: la barra de la subasta
---------------------------------------------------------------------------
local function rect(f) return f:GetLeft(), f:GetBottom(), f:GetRight(), f:GetTop() end
local function encima(a, b)
  local al, ab, ar, at = rect(a)
  local bl, bb, br, bt = rect(b)
  return al < br and ar > bl and ab < bt and at > bb
end

step("la barra de la subasta no se encima en las pestañas ni con el vendedor", function()
  local C = NS_OF("Alfa_Comercio")
  local n, items = 0, {}
  C_AuctionHouse = C_AuctionHouse or {}
  C_AuctionHouse.ReplicateItems = function() end
  C_AuctionHouse.GetNumReplicateItems = function() return n end
  C_AuctionHouse.GetReplicateItemInfo = function(i) local it = items[i + 1] if it then return "x", 1, it[2], 1, true, 1, 0, 1, 1, it[3], 0, false, nil, "a", "a", 0, it[1] end end
  local AH = rawget(_G, "AuctionHouseFrame") or CreateFrame("Frame", "AuctionHouseFrame", UIParent)
  AH:ClearAllPoints()
  AH:SetSize(800, 540)
  AH:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -80)
  AH:Show()
  local tabs = {}
  for k, nombre in ipairs({ "AuctionHouseFrameBuyTab", "AuctionHouseFrameSellTab", "AuctionHouseFrameAuctionsTab" }) do
    local t = rawget(_G, nombre) or CreateFrame("Button", nombre, AH)
    t:SetSize(110, 32)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", AH, "BOTTOMLEFT", 20 + (k - 1) * 114, 2)
    t:Show()
    tabs[k] = t
  end
  A.Set("comercio.boton", true)
  FIRE_EVENT("AUCTION_HOUSE_SHOW")
  T(3)
  local b = C.Barra and C.Barra()
  check(b and b:IsShown(), "la barra no salió con la subasta") if not b then return end
  for _, t in ipairs(tabs) do check(not encima(b, t), "la barra tapa la pestaña " .. tostring(t._name)) end
  check(b:GetHeight() <= 32, "la barra no es compacta: " .. tostring(b:GetHeight()))
  check(b:GetRight() <= AH:GetRight() + 0.5, "la barra se sale de la subasta por la derecha")
  -- Una subasta angosta: la barra baja de las pestañas.
  AH:SetSize(480, 540)
  C.RefrescarBarra()
  for _, t in ipairs(tabs) do check(not encima(b, t), "en una subasta angosta la barra tapa la pestaña " .. tostring(t._name)) end
  check(b:GetTop() <= tabs[1]:GetBottom() + 0.5, "en una subasta angosta la barra no bajó de las pestañas")
  AH:SetSize(800, 540)
  C.RefrescarBarra()
  -- Con la ventana del vendedor, no se queda pegada.
  local MF = rawget(_G, "MerchantFrame") or CreateFrame("Frame", "MerchantFrame", UIParent)
  MF:Show()
  C.RefrescarBarra()
  check(not b:IsShown(), "la barra se quedó con la ventana del vendedor abierta")
  MF:Hide()
  C.RefrescarBarra()
  check(b:IsShown(), "la barra no volvió al cerrar al vendedor")
  -- La subasta se esconde sin avisar: la barra se va con ella.
  AH:Hide()
  check(not b:IsShown(), "la barra siguió sin la subasta")
  AH:Show()
  T(2)
  check(b:IsShown(), "la barra no volvió con la subasta")

  -- Un escaneo: el avance discreto y, al terminar, se encoge sola.
  for k = 1, 450 do items[k] = { 1000 + k, 1, 500 + k } end
  n = #items
  C.Reino().pedido = 0
  check(C.Escanear(), "no pidió el escaneo")
  C.RefrescarBarra()
  check(b.Estado:IsShown() and not b.quieta, "mientras escanea la barra no dice nada")
  FIRE_EVENT("REPLICATE_ITEM_LIST_UPDATE")
  C.RefrescarBarra()
  local vioAvance = b.Progreso:IsShown()
  for _ = 1, 40 do
    if C.EstadoEscaneo() == "listo" then break end
    FIRE(C.motorTareas, "OnUpdate", 0.1)
    if b.Progreso:IsShown() then vioAvance = true end
    C.RefrescarBarra()
  end
  check(C.EstadoEscaneo() == "listo", "el escaneo no terminó")
  check(vioAvance, "no se vio el avance mientras leía")
  T(3)
  local est, _, msg = C.EstadoEscaneo()
  check(msg == nil, "el mensaje de «¡Listo!» no se fue solo: " .. tostring(msg))
  C.RefrescarBarra()
  check(b.quieta and not b.Estado:IsShown() and not b.Progreso:IsShown(), "al terminar la barra no se encogió")
  for _, t in ipairs(tabs) do check(not encima(b, t), "al encogerse la barra tapa la pestaña " .. tostring(t._name)) end
  check(b:GetWidth() < 300, "quieta, la barra sigue ancha: " .. tostring(b:GetWidth()))
  -- Sin precios: lo dice corto (y entero en su cuadro), sin cortarse.
  C.Reino().escaneo = nil
  C.RefrescarBarra()
  check(not b.quieta and b.infoEstado and b.infoEstado:find("Escanear con Alfa", 1, true), "sin precios no lo dice")
  if b.Estado:IsShown() then
    local cabe = K.num(b.Estado:GetWidth(), 0)
    check(K.AnchoTexto(b.Estado) <= cabe + 1 or cabe == 0, "el texto de la barra se corta")
  end
  FIRE_EVENT("AUCTION_HOUSE_CLOSED")
  T(1)
  check(not b:IsShown(), "la barra siguió con la subasta cerrada")
  AH:Hide()
end)

print("prueba_137b_enciclopedia: listo")
