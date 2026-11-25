-- Prueba de la 1.3.9, Bolsas (tools/prueba.py la corre con las demás):
--   104. La ventana de tu personaje con un conjunto «Pesca»: la barra de tus
--        conjuntos sale como panel con su título, afuera del borde que se ve
--        de la ventana (nada encima de su esquina ni de su botón de cerrar), y
--        no sale si tu único conjunto es el que ya llevas puesto (la caña).
--        La espada «A pelear» de Pesca no sale con tu ventana.
--   13. Candado automático en herramientas de oficio y objetos de viaje.
--   14. El número de la recarga («55m» de la piedra de hogar) cabe en su
--       casilla, con la letra de Alfa, a 28 y a 36 px.
--   16. «Separar»: lo épico con candado a la subasta, solo con su ajuste.
--   45. «Lo que me sobra»: vender (sin lo que tiene candado) y mandar a otro
--       personaje (pone el nombre y adjunta; «Enviar» es tuyo).
--   81. Búsqueda: arma, material, candado, sin usar, sobra, «-gris».
--   82. Ordenar a tu manera: por tipo, junta montones, lo del candado quieto.
--   83. La cabecera igual en bolsas y banco (y en las de otro personaje): el
--       banco tiene «Bolsas», el título de otro personaje no se corta.
--   17. Dos pantallas en un clic con el otro monitor a la izquierda.
SNAPSHOTS = {}
BANCO_LETRA = 0.64
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["139-bolsas-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
end
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
local function check(cond, msg) if not cond then NOTE("1.3.9 bolsas", msg) end end
local function bombear(w)
  for _ = 1, 80 do
    local fn = w and w:GetScript("OnUpdate")
    if not fn then break end
    fn(w, 0.02)
  end
end
-- El reloj y el trabajo por lotes de las ventanas de bolsas (su OnUpdate).
local function T(n)
  RUN_TIMERS(n or 3)
  local B0 = NS_OF and NS_OF("Alfa_Bolsas")
  local V0 = B0 and B0.Ventana
  if V0 and V0.Ventana then
    for _, t in ipairs({ "bolsas", "banco" }) do
      local ok, w = pcall(V0.Ventana, t)
      if ok and w and w:IsShown() then bombear(w) end
    end
  end
end
local function cerca(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 1) end

local impresos = {}
AlfaNucleo.Imprimir = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  impresos[#impresos + 1] = table.concat(t, " ")
end
local function dijo(texto)
  for _, t in ipairs(impresos) do if t:find(texto, 1, true) then return true end end
  return false
end

---------------------------------------------------------------------------
-- El juego de mentira: objetos, equipo, una bolsa de 16, cursor y buzón
---------------------------------------------------------------------------
-- id -> { nombre, calidad, montón, precio, clase, subclase, ranura }
local OBJ = {
  [6948] = { "Piedra de hogar", 1, 1, 0, 15, 0, "" },
  [2589] = { "Lino", 1, 20, 2, 7, 5, "" },
  [4865] = { "Garra rota", 0, 1, 5, 15, 0, "" },
  [9300] = { "Hoja de la luna", 4, 1, 900, 2, 7, "INVTYPE_WEAPON" },
  [9301] = { "Espada del oso", 2, 1, 120, 2, 7, "INVTYPE_WEAPON" },
  [2901] = { "Pico de minero", 1, 1, 4, 2, 14, "INVTYPE_WEAPON" },
  [6256] = { "Caña de pescar", 1, 1, 6, 2, 20, "INVTYPE_2HWEAPON" },
  [5656] = { "Riendas del lobo", 3, 1, 0, 15, 5, "" },
  [118] = { "Poción de sanación menor", 1, 5, 1, 0, 1, "" },
  [9201] = { "Espada del lobo", 2, 1, 100, 2, 7, "INVTYPE_WEAPON" },
  [9103] = { "Gorro", 1, 1, 10, 4, 1, "INVTYPE_HEAD" },
  [9104] = { "Sombrero de pesca", 2, 1, 10, 4, 1, "INVTYPE_HEAD" },
}
local CANA, ESPADA, GORRO, SOMBRERO = 6256, 9201, 9103, 9104
local function enlace(id)
  local o = OBJ[id]
  local color = ({ [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee" })[o[2]] or "ffffffff"
  return "|c" .. color .. "|Hitem:" .. id .. "::::::::|h[" .. o[1] .. "]|h|r"
end
local function idDe(x) return tonumber(x) or tonumber(tostring(x):match("item:(%d+)")) end
C_Item.GetItemInfo = function(x)
  local id = idDe(x)
  local o = id and OBJ[id]
  if not o then return nil end
  return o[1], enlace(id), o[2], 20, 1, "Tipo", "Subtipo", o[3], o[7], 134400 + id % 50, o[4], o[5], o[6]
end
GetItemInfo = C_Item.GetItemInfo
C_Item.GetItemInfoInstant = function(x)
  local id = idDe(x)
  local o = id and OBJ[id]
  if not o then return nil end
  return id, "Tipo", "Subtipo", o[7], 134400 + id % 50, o[5], o[6]
end

local puesto = { [16] = enlace(ESPADA), [1] = enlace(GORRO) }
GetInventoryItemLink = function(_, r) return puesto[r] end
GetInventoryItemID = function(_, r) local l = puesto[r] return l and idDe(l) end

local bolsa = {}
local function cosa(id, n) return { itemID = id, stackCount = n or 1, quality = OBJ[id][2], hyperlink = enlace(id), isLocked = false } end
local function llenar()
  bolsa = {
    [1] = cosa(4865), [2] = cosa(2589, 5), [3] = cosa(9300), [4] = cosa(118, 3),
    [5] = cosa(6948), [6] = cosa(2589, 7), [7] = cosa(9301), [8] = cosa(2901),
    [9] = cosa(5656), [10] = cosa(6256),
  }
end
llenar()
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end
C_Container.GetContainerNumFreeSlots = function(b)
  if b ~= 0 then return 0, 0 end
  local n = 0
  for s = 1, 16 do if not bolsa[s] then n = n + 1 end end
  return n, 0
end
C_Container.GetContainerItemInfo = function(b, s) return b == 0 and bolsa[s] or nil end
C_Container.GetContainerItemLink = function(b, s) local i = b == 0 and bolsa[s] return i and i.hyperlink or nil end
C_Container.GetContainerItemID = function(b, s) local i = b == 0 and bolsa[s] return i and i.itemID or nil end
C_Container.GetContainerItemQuestInfo = function() return { isQuestItem = false } end
-- La piedra de hogar: le faltan 55 minutos.
C_Container.GetContainerItemCooldown = function(b, s)
  local i = b == 0 and bolsa[s]
  if i and i.itemID == 6948 then return GetTime() - 300, 3600, 1 end
  return 0, 0, 0
end
local usados = {}
C_Container.UseContainerItem = function(b, s) usados[#usados + 1] = s if b == 0 then bolsa[s] = nil end end
-- El cursor: tomar y soltar intercambia (o junta montones).
local cursor, adjuntos = nil, {}
C_Container.PickupContainerItem = function(b, s)
  if b ~= 0 then return end
  if not cursor then
    if bolsa[s] then cursor = s end
    return
  end
  local de = cursor
  cursor = nil
  if de == s then return end
  local a, d = bolsa[de], bolsa[s]
  if d and a and d.itemID == a.itemID and OBJ[a.itemID][3] > 1 and d.stackCount + a.stackCount <= OBJ[a.itemID][3] then
    d.stackCount = d.stackCount + a.stackCount
    bolsa[de] = nil
  else
    bolsa[de], bolsa[s] = d, a
  end
end
CursorHasItem = function() return cursor ~= nil end
ClearCursor = function() cursor = nil end
HasSendMailItem = function(i) return adjuntos[i] ~= nil end
ClickSendMailItemButton = function(i)
  if cursor and not adjuntos[i] then adjuntos[i] = bolsa[cursor] bolsa[cursor] = nil cursor = nil end
end
local buzon = CreateFrame("Frame", "SendMailFrame", UIParent)
buzon:Hide()
local nombreCarta = CreateFrame("EditBox", "SendMailNameEditBox", buzon)

-- La ventana de tu personaje, como la del juego clásico: 384 x 512 con 30 px
-- transparentes a la derecha (HitRectInsets), en el lugar de las de la izquierda.
local fondo = CreateFrame("Frame", nil, UIParent)
fondo:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
fondo:SetSize(720, 640)
local ft = fondo:CreateTexture(nil, "BACKGROUND")
ft:SetAllPoints(fondo)
ft:SetColorTexture(0.05, 0.07, 0.1, 1)
fondo:Hide()
local cf = rawget(_G, "CharacterFrame") or CreateFrame("Frame", "CharacterFrame", UIParent)
cf:SetSize(384, 512)
cf:ClearAllPoints()
cf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
rawset(cf, "GetHitRectInsets", function() return 0, 30, 0, 75 end)
local arte = cf:CreateTexture(nil, "BACKGROUND")
arte:SetPoint("TOPLEFT", cf, "TOPLEFT", 10, -12)
arte:SetSize(342, 425)
arte:SetColorTexture(0.32, 0.27, 0.2, 1)
local cerrar = cf:CreateTexture(nil, "ARTWORK")
cerrar:SetSize(24, 24)
cerrar:SetPoint("CENTER", cf, "TOPRIGHT", -44, -25)
cerrar:SetColorTexture(0.6, 0.1, 0.1, 1)
cf:Hide()

AlfaNucleoCharDB = AlfaNucleoCharDB or {}
AlfaNucleoCharDB.candado = nil
Alfa.Hidden = Alfa.Hidden or function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
do
  local Bv = rawget(_G, "AlfaBienvenida")
  AlfaNucleo.Datos("bienvenida").respondio = Bv and Bv.VERSION or 99
  AlfaNucleo.Datos("bienvenida").versionVista = Bv and Bv.VersionAlfa and Bv.VersionAlfa() or "9.9.9"
  AlfaNucleo.Datos("bienvenida").recorrido = true
end
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(8)
if Alfa.UI and Alfa.UI.Options and Alfa.UI.Options.frame then Alfa.UI.Options.frame:Hide() end

local N, K = AlfaNucleo, AlfaNucleo.Kit
local B = NS_OF("Alfa_Bolsas")
local Cb, Cj, Cd, O, V, Sp, Sg = B.Cambio, B.Conjuntos, B.Candado, B.Objetos, B.Ventana, B.Separar, B.Sugerencias
local Sb, Ord, Bt = B.Sobra, B.Ordenar, B.Botones
local Pe = NS_OF("Alfa_Pesca").Pelear
check(Sb and Ord, "faltan Sobra.lua u Ordenar.lua")

---------------------------------------------------------------------------
-- 104. La ventana de tu personaje
---------------------------------------------------------------------------
step("104: la barra de tus conjuntos junto a la ventana de tu personaje", function()
  fondo:Show()
  -- (1.4.0: el panel viene apagado de fábrica; aquí lo pide el jugador.)
  Alfa.Set("bolsas.barraConjuntos", true)
  -- Guardas «Pesca» con la caña y el sombrero; vuelves a la espada y el gorro.
  puesto[16], puesto[1] = enlace(CANA), enlace(SOMBRERO)
  Cj.Guardar("Pesca")
  puesto[16], puesto[1] = enlace(ESPADA), enlace(GORRO)
  cf:Show()
  T(2)
  local barra = Cb.Barra()
  check(barra and barra:IsShown(), "con la espada puesta, «Pesca» no salió junto a tu personaje")
  if not barra then return end
  -- Afuera de lo que se ve de la ventana (su borde visible: derecha - 30) y con título.
  local borde = cf:GetRight() - 30
  check(barra:GetLeft() >= borde + 4, ("la barra se encima en la ventana: empieza en %s y el borde está en %s"):format(tostring(barra:GetLeft()), borde))
  check(barra:GetTop() <= cf:GetTop(), "la barra sale más arriba que la ventana")
  check(barra.Titulo and barra.Titulo:IsShown() and barra.Titulo:GetText() == "Tus conjuntos", "la barra no tiene su título")
  check(not (Pe and Pe.boton:IsShown()), "la espada «A pelear» salió con tu ventana")
  SNAP("personaje-espada", fondo, { cf, barra, Pe and Pe.boton or false })
  -- Con la caña puesta, tu único conjunto ya está puesto: no aporta, no sale.
  puesto[16], puesto[1] = enlace(CANA), enlace(SOMBRERO)
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 16, true)
  T(2)
  check(not barra:IsShown(), "con «Pesca» puesto (tu único conjunto) la barra sigue")
  check(not (Pe and Pe.boton:IsShown()), "la espada «A pelear» salió con la caña puesta")
  SNAP("personaje-cana", fondo, { cf, barra, Pe and Pe.boton or false })
  -- Con otro conjunto, sí sale (para volver a la espada).
  puesto[16], puesto[1] = enlace(ESPADA), enlace(GORRO)
  Cj.Guardar("Pelea")
  puesto[16], puesto[1] = enlace(CANA), enlace(SOMBRERO)
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 16, true)
  T(2)
  check(barra:IsShown(), "con dos conjuntos la barra no salió")
  SNAP("personaje-dos", fondo, { cf, barra, Pe and Pe.boton or false })
  -- En combate nada se mueve ni se rehace (solo se pinta).
  local antes = barra:IsShown()
  InCombatLockdown = function() return true end
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 16, true)
  T(1)
  check(barra:IsShown() == antes, "en combate la barra cambió")
  InCombatLockdown = function() return false end
  cf:Hide()
  T(1)
  check(not barra:IsShown(), "con tu ventana cerrada la barra sigue")
  Cj.Olvidar("Pesca")
  Cj.Olvidar("Pelea")
  puesto[16], puesto[1] = enlace(ESPADA), enlace(GORRO)
  fondo:Hide()
end)

---------------------------------------------------------------------------
-- 13. Herramientas de oficio y objetos de viaje
---------------------------------------------------------------------------
step("13: candado automático en herramientas y viaje", function()
  check(Cd.Auto(2901) == "herramienta", "el pico de minero no lleva candado: " .. tostring(Cd.Auto(2901)))
  check(Cd.Auto(6256) == "herramienta", "la caña (arma, subclase 20) no lleva candado: " .. tostring(Cd.Auto(6256)))
  check(Cd.Auto(5656) == "viaje", "la montura no lleva candado: " .. tostring(Cd.Auto(5656)))
  check(Cd.Auto(18984) == "viaje", "el desgarrador dimensional no lleva candado")
  check(Cd.Auto(9301) == nil and Cd.Auto(2589) == nil, "algo que no es herramienta lleva candado")
  check(Cd.TextoMotivo("herramienta") and Cd.TextoMotivo("viaje"), "faltan los textos de los motivos")
  check(Cd.TieneCasilla(0, 8) and Cd.TieneCasilla(0, 10), "las casillas del pico y la caña no tienen candado")
  -- Quitarle el candado a mano gana; el automático apagado no pone nada.
  Cd.Poner(2901, enlace(2901), false)
  check(not Cd.Tiene(2901, enlace(2901)), "quitarle el candado al pico no se respetó")
  Cd.Lista(false)["2901"] = nil
  N.Set("bolsas", "candadoAuto", false)
  check(Cd.Auto(6256) == nil, "con el automático apagado la caña lleva candado")
  N.Set("bolsas", "candadoAuto", nil)
  check(Cd.Tiene(2901, enlace(2901)), "el pico no recuperó su candado automático")
end)

---------------------------------------------------------------------------
-- 14. El número de la recarga en tus bolsas
---------------------------------------------------------------------------
local function parteDe(id)
  for b, p in pairs(Bt.Partes) do
    if b:IsVisible() and p.ent and p.ent.rec and tonumber(p.ent.rec.i) == id then return p, b end
  end
end
step("14: «55m» cabe en su casilla", function()
  V.MostrarBolsas(true)
  T(4)
  local win = V.Ventana("bolsas")
  for _, tam in ipairs({ 36, 28 }) do
    N.Set("bolsas", "tamIcono", tam)
    T(4)
    local p = parteDe(6948)
    check(p and p.recarga and p.recarga:IsShown(), "la piedra de hogar no lleva su número de recarga (" .. tam .. " px)")
    if p and p.recarga then
      check(p.recarga:GetText() == "55m", "la recarga no dice 55m: " .. tostring(p.recarga:GetText()))
      local w = p.recarga:GetStringWidth()
      check(w <= p.tam - 4, ("«55m» mide %s y la casilla %s"):format(tostring(w), tostring(p.tam)))
      local fuente = p.recarga:GetFont()
      check(type(fuente) == "string" and fuente:find("Alfa", 1, true), "la recarga no usa la letra de Alfa: " .. tostring(fuente))
    end
    SNAP("recarga-" .. tam, win)
  end
  N.Set("bolsas", "tamIcono", nil)
  -- El reloj pasa: a 58.5 s dice «59»; al terminar, nada.
  local p = parteDe(6948)
  if p then
    p.finRecarga = GetTime() + 58.5
    Bt.Recargas[select(2, parteDe(6948))] = p
    Bt.TicRecargas()
    check(p.recarga:GetText() == "59", "a 58.5 s no dice 59: " .. tostring(p.recarga:GetText()))
    p.finRecarga = GetTime() - 1
    Bt.TicRecargas()
    check(not p.recarga:IsShown(), "al terminar, el número sigue")
  end
  T(2)
end)

---------------------------------------------------------------------------
-- 81. La búsqueda
---------------------------------------------------------------------------
local function ent(s)
  local i = bolsa[s]
  local rec = { i = i.itemID, q = i.quality, l = i.hyperlink, c = i.stackCount }
  local e = O.Info(i.itemID, i.hyperlink)
  return { rec = rec, e = e, cat = O.Categoria(rec, e), nivel = nil }
end
local function busca(texto, s) return O.Coincide(O.Compilar(texto), ent(s)) end
step("81: buscar por lo que es y por lo que Alfa sabe", function()
  Sg.Invalidar()
  check(busca("arma", 7) and not busca("arma", 2), "«arma» no encuentra la espada (o encuentra el lino)")
  check(busca("material", 2) and not busca("material", 7), "«material» no encuentra el lino")
  check(busca("pocion", 4), "«pocion» no encuentra la poción")
  check(busca("montura", 9), "«montura» no encuentra las riendas")
  check(busca("candado", 3) and busca("candado", 8) and not busca("candado", 2), "«candado» no encuentra lo que tiene candado")
  check(busca("sin usar", 7) and not busca("sin usar", 2), "«sin usar» no encuentra la espada que no llevas")
  check(busca("sobra", 1) and not busca("sobra", 7), "«sobra» no encuentra la garra gris")
  check(not busca("-gris", 1) and busca("-gris", 2), "«-gris» no quita lo gris")
  check(busca("lino -candado", 2) and not busca("arma -candado", 3), "«-candado» no quita lo que tiene candado")
end)

---------------------------------------------------------------------------
-- 16. «Separar»: lo épico con candado
---------------------------------------------------------------------------
step("16: lo épico con candado a la subasta, con su ajuste", function()
  local C = rawget(_G, "AlfaComercio")
  check(C and C.Consejo, "falta el consejo de Comercio")
  if not C then return end
  local orig = C.Consejo
  C.Consejo = function(id, o)
    if id == 9300 then return { mejor = "subastar", valor = 50000 } end
    return orig(id, o)
  end
  Sg.Invalidar()
  check(Sp.Clase(9300) == nil, "sin el ajuste, lo épico con candado sale en «Separar»")
  N.Set("bolsas", "separarEpicos", true)
  T(1)
  Sg.Invalidar()
  check(Sp.Clase(9300) == "subasta", "con el ajuste, lo épico con candado no sale con el martillo")
  local vende = false
  for _, g in ipairs(Sg.Estado().vender) do if g.id == 9300 then vende = true end end
  check(not vende, "lo épico con candado salió para vender")
  check(Cd.TieneCasilla(0, 3), "lo épico perdió su candado")
  Sp.Alternar(V.Ventana("bolsas"), true)
  T(4)
  SNAP("separar-epico", V.Ventana("bolsas"))
  Sp.Alternar(V.Ventana("bolsas"), false)
  N.Set("bolsas", "separarEpicos", nil)
  C.Consejo = orig
  Sg.Invalidar()
end)

---------------------------------------------------------------------------
-- 45. «Lo que me sobra»
---------------------------------------------------------------------------
step("45: lo que me sobra: vender y mandar", function()
  local win = V.Ventana("bolsas")
  T(2)
  check(win.Sobra and win.Sobra:IsShown(), "no está el botón «Lo que me sobra»")
  Sg.Invalidar()
  local r = Sb.Lista()
  local garra = false
  for _, g in ipairs(r.vender) do
    if g.id == 4865 then garra = true end
    check(not Cd.Tiene(g.id, g.link, { q = g.q }), "para vender salió algo con candado: " .. tostring(g.nombre))
  end
  check(garra, "la garra gris no salió para vender")
  -- Sin comerciante: te lleva a uno.
  impresos = {}
  Sb.Vender()
  check(dijo("Habla con un comerciante"), "sin comerciante no dijo qué hacer")
  -- Con comerciante: se vende por lotes, sin tocar lo del candado.
  FIRE_EVENT("MERCHANT_SHOW")
  T(2)
  usados = {}
  if bolsa[1] then
    check(Sb.Vender(), "con el comerciante no empezó a vender")
    T(4)
    check(bolsa[1] == nil, "la garra no se vendió")
    check(dijo("Vendiste lo que te sobraba"), "no dijo lo que vendió")
  end
  for _, s in ipairs(usados) do check(s ~= 3 and s ~= 8 and s ~= 10, "se vendió algo con candado (casilla " .. s .. ")") end
  FIRE_EVENT("MERCHANT_CLOSED")
  T(1)
  -- Para otro personaje (lo que piden sus recetas): pone el nombre y adjunta.
  local Gu = B.Guardar
  local origGu = Gu.Sugerencias
  Gu.Sugerencias = function()
    local out = {}
    for s = 1, 16 do
      local i = bolsa[s]
      if i and i.itemID == 2589 then out[#out + 1] = { bolsa = 0, casilla = s, id = 2589, link = i.hyperlink, cantidad = i.stackCount, para = "Luna (Sastrería)", nombre = "Luna", tipo = "oficio" } end
    end
    -- Algo con candado nunca se manda.
    out[#out + 1] = { bolsa = 0, casilla = 3, id = 9300, nombre = "Luna", para = "Luna" }
    return out
  end
  r = Sb.Lista()
  local luna
  for _, a in ipairs(r.alts) do if a.nombre == "Luna" then luna = a end end
  check(luna and #luna.piezas == 2, "Luna no tiene sus 2 montones de lino (sin lo del candado)")
  impresos = {}
  Sb.Mandar("Luna")
  check(dijo("Abre el buzón"), "sin el buzón no dijo qué hacer")
  buzon:Show()
  adjuntos = {}
  check(Sb.Mandar("Luna"), "con el buzón no empezó")
  T(4)
  check(nombreCarta:GetText() == "Luna", "no puso el nombre en la carta: " .. tostring(nombreCarta:GetText()))
  local n = 0
  for _, x in pairs(adjuntos) do n = n + 1 check(x.itemID == 2589, "se adjuntó algo que no es lino") end
  check(n == 2, "no adjuntó los 2 montones: " .. n)
  check(dijo("Revísala y dale «Enviar»"), "no dijo que «Enviar» es tuyo")
  buzon:Hide()
  -- El menú del botón.
  llenar()
  Sg.Invalidar()
  T(3)
  win.Sobra:Click()
  T(1)
  local menu = rawget(_G, "AlfaKitMenu")
  check(menu and menu:IsShown(), "el botón no abrió su menú")
  if menu then SNAP("sobra-menu", menu) menu:Hide() end
  if K.CerrarMenu then K.CerrarMenu() end
  Gu.Sugerencias = origGu
end)

---------------------------------------------------------------------------
-- 82. Ordenar a tu manera
---------------------------------------------------------------------------
step("82: ordenar por tipo, juntar montones y dejar quieto lo del candado", function()
  llenar()
  -- Huecos: que haya que mover de verdad.
  bolsa[11], bolsa[1] = bolsa[1], nil
  N.Set("bolsas", "ordenarModo", "tipo")
  N.Set("bolsas", "ordenarCandado", true)
  check(Ord.Usar(), "con «por tipo» no ordena Alfa")
  local quietos = {}
  for s = 1, 16 do if bolsa[s] and Cd.TieneCasilla(0, s) then quietos[s] = bolsa[s].itemID end end
  local win = V.Ventana("bolsas")
  V.Ordenar(win)
  T(30)
  check(not Ord.Activo(), "no terminó de ordenar")
  for s, id in pairs(quietos) do check(bolsa[s] and bolsa[s].itemID == id, "se movió algo con candado (casilla " .. s .. ")") end
  -- El lino quedó en un montón de 12.
  local linos = 0
  for s = 1, 16 do if bolsa[s] and bolsa[s].itemID == 2589 then linos = linos + 1 check(bolsa[s].stackCount == 12, "el lino no se juntó") end end
  check(linos == 1, "quedaron " .. linos .. " montones de lino")
  -- Lo demás, en orden de tipo y la chatarra al final; los huecos al final.
  local ORDEN = { equipo = 1, consumibles = 2, misiones = 3, artesania = 4, reagentes = 5, monturas = 6, otros = 7, chatarra = 9 }
  local ultimo, hueco = 0, false
  local vistos = {}
  for s = 1, 16 do
    if not quietos[s] then
      local i = bolsa[s]
      if i then
        check(not hueco, "hay un hueco antes de la casilla " .. s)
        local rec = { i = i.itemID, q = i.quality, l = i.hyperlink }
        local c = ORDEN[O.CategoriaFija(rec, O.Info(i.itemID, i.hyperlink))] or 8
        check(c >= ultimo, "la casilla " .. s .. " rompe el orden por tipo")
        ultimo = c
        vistos[#vistos + 1] = i.itemID
      else
        hueco = true
      end
    end
  end
  print("82 orden", table.concat(vistos, ","))
  -- En combate se detiene.
  llenar()
  bolsa[12], bolsa[2] = bolsa[2], nil
  local tickerReal = N.Ticker
  N.Ticker = function(clave, seg, fn) return tickerReal(clave, 99, fn) end -- (que no termine solo antes del combate)
  V.Ordenar(win)
  N.Ticker = tickerReal
  check(Ord.Activo(), "no empezó a ordenar")
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not Ord.Activo(), "al entrar en combate no se detuvo")
  check(dijo("entraste en combate"), "no dijo por qué se detuvo")
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  -- Como el juego: el orden del juego (SortBags).
  N.Set("bolsas", "ordenarModo", nil)
  N.Set("bolsas", "ordenarCandado", nil)
  local juego = 0
  local origSort = C_Container.SortBags
  C_Container.SortBags = function() juego = juego + 1 end
  check(not Ord.Usar(), "como el juego, ordena Alfa")
  V.Ordenar(win)
  check(juego == 1, "como el juego, no se llamó SortBags")
  C_Container.SortBags = origSort
  llenar()
  T(3)
end)

---------------------------------------------------------------------------
-- 83. La misma cabecera en bolsas y banco, tuyos y de otro personaje
---------------------------------------------------------------------------
step("83: bolsas y banco con la misma cabecera", function()
  local D = B.Datos
  local pers = D.Raiz().personajes
  pers["Garramaestra-Forever"] = { nombre = "Garramaestra", reino = "Forever", faccion = "Horde", clase = "HUNTER", nivel = 40, dinero = 50000,
    visto = time() - 3 * 86400, bolsas = {}, banco = {}, equipo = {} }
  D.GuardarCabecera()
  local win = V.Ventana("bolsas")
  V.Ver(win, nil)
  T(3)
  SNAP("cabecera-bolsas", win)
  V.MostrarBanco(nil)
  T(3)
  local banco = V.Ventana("banco")
  check(banco.BotonBolsas and banco.BotonBolsas:IsShown(), "el banco no tiene el botón «Bolsas»")
  SNAP("cabecera-banco", banco)
  -- Otro personaje: el título no se corta (los botones que no aplican no dejan hueco).
  V.Ver(win, "Garramaestra-Forever")
  T(3)
  check(not win.Sobra:IsShown() and not win.Separar:IsShown() and not win.Conjuntos:IsShown(), "en las bolsas de otro personaje salen tus botones")
  local tr = win.Titulo:GetRight()
  check(tr and win.GrupoVistas and tr <= win.GrupoVistas:GetLeft(), "el título se encima en las vistas")
  SNAP("cabecera-otro", win)
  V.MostrarBanco("Garramaestra-Forever")
  T(3)
  SNAP("cabecera-otro-banco", banco)
  -- «Bolsas» en el banco de otro: sus bolsas.
  banco.BotonBolsas:Click()
  T(2)
  check(win:IsShown() and win.clave == "Garramaestra-Forever", "«Bolsas» del banco no abrió las bolsas del mismo personaje")
  V.Ver(win, nil)
  V.CerrarBanco()
  V.MostrarBolsas(false)
  T(2)
end)

---------------------------------------------------------------------------
-- 17. Dos pantallas: el otro monitor a la izquierda
---------------------------------------------------------------------------
step("17: dos pantallas con el otro monitor a la izquierda", function()
  local Bv = NS_OF("Alfa_Bienvenida")
  local Es, Au = Bv.Escritorio, Bv.EscritorioAuto
  if not (Es and Au) then check(false, "falta el escritorio") return end
  PANTALLA_SIMULADA(1920, 1080)
  local cv = { gxWindow = "0", gxMaximize = "1", gxWindowedResolution = "1920x1080", gxMonitor = "0" }
  local pedido, reinicios = nil, 0
  local og, os = GetCVar, SetCVar
  GetCVar = function(n) return cv[n] or "0" end
  SetCVar = function(n, v) cv[n] = tostring(v) end
  GetMonitorCount = function() return 2 end
  C_VideoOptions = {
    GetDefaultGameWindowSize = function(i) if i < 2 then return { x = 1920, y = 1080 } end return nil end,
    GetCurrentGameWindowSize = function() local w, h = PANTALLA_TAM() return { x = w, y = h } end,
    SetGameWindowSize = function(x, y) pedido = { x, y } end,
  }
  RestartGx = function() reinicios = reinicios + 1 if pedido then PANTALLA_SIMULADA(pedido[1], pedido[2]) end end
  local d = N.Datos("pantallas")
  d.autoPreguntado, d.noPreguntar, d.ladoOtro = nil, nil, nil
  check(Au.Lado() == "derecha", "de fábrica el otro monitor no está a la derecha")
  local of = Au.Ofrecer()
  T(1)
  check(of.Lado and of.Lado:IsShown(), "el aviso no pregunta de qué lado está tu otro monitor")
  SNAP("dos-pantallas-oferta", of)
  -- Eliges «A la izquierda» y «Sí, en un clic».
  for _, b in ipairs(of.Lado.botones or {}) do if b.alfaValorOpcion == "izquierda" then b:Click() end end
  check(of.Lado:Valor() == "izquierda" and Au.Lado() == "izquierda", "elegir «A la izquierda» no se guardó")
  of.Si:Click()
  check(pedido and pedido[1] == 3840, "no pidió la ventana de los dos monitores")
  check(d.auto and d.auto.lado == "izquierda", "no anotó el lado")
  FIRE_EVENT("DISPLAY_SIZE_CHANGED")
  T(3)
  check(Es.Probando(), "no empezó la prueba")
  -- El juego, a la derecha (en tu monitor principal); tus paneles, a la izquierda.
  check(cerca(UIParent:GetLeft(), 1920, 2), "el juego no quedó a la derecha: " .. tostring(UIParent:GetLeft()))
  check(Es.Marco() and cerca(Es.Marco():GetLeft(), 0, 2), "el escritorio no quedó a la izquierda")
  local conf = rawget(_G, "AlfaEscritorioConfirmar")
  check(conf and (conf.Texto:GetText() or ""):find("el de la izquierda", 1, true), "la prueba no dice cómo dejar la ventana con el monitor a la izquierda")
  if conf then conf.Si:Click() end
  check(Au.Fase() == "hecho" and N.Get("pantallas", "lado") == "izquierda", "«Sí» no guardó el lado izquierdo")
  Es.Apagar(true)
  FIRE_EVENT("DISPLAY_SIZE_CHANGED")
  T(2)
  check(Au.Fase() == nil and cv.gxMaximize == "1", "volver a una pantalla no devolvió la ventana")
  d.ladoOtro = nil
  N.Set("pantallas", "lado", nil)
  N.Set("pantallas", "activo", nil)
  GetCVar, SetCVar = og, os
  PANTALLA_SIMULADA(1920, 1080)
end)

print(("PRUEBA: 1.3.9 bolsas, %d pasos, %d errores"):format(pasos, #ERRORS))
