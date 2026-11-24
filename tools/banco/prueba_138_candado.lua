-- Prueba de la 1.3.8, el candado de objetos (tools/prueba.py la corre con las demás):
--   1. poner y quitar (también por Alt+clic derecho y su menú, y en combate sin
--      menú), la clave por enlace del equipo único y por número de lo que se
--      apila, «en toda la cuenta»;
--   2. borrar con candado: el objeto vuelve (ClearCursor), el cuadro del juego
--      queda con Aceptar apagado y dice «¡Este objeto tiene candado!»; sin
--      candado no se toca nada;
--   3. vender con candado: la capa no deja el clic derecho (no se vende) y sí
--      tomarlo; sin comerciante o en combate, ninguna capa;
--   4. la venta sola de lo gris (el motor, QoL/Vendor.lua) y la sugerencia de
--      qué vender se saltan lo que tiene candado; «Mandar a tu alt» también;
--   5. el automático: lo épico, la piedra de hogar, lo de misión y tus
--      conjuntos; se apaga; quitarle el candado a uno automático;
--   6. lo vendido con candado (pestaña «Recompra») y el comercio avisan.
-- Capturas: el candado en tus bolsas y el cuadro de borrar con su aviso.
SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["138-candado-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.3.8 candado", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

---------------------------------------------------------------------------
-- El juego de mentira: objetos, bolsas, cursor y el cuadro de borrar
---------------------------------------------------------------------------

-- id -> { nombre, calidad, montón, precio, clase }
local OBJ = {
  [2589] = { "Lino", 1, 20, 2, 7 },
  [4865] = { "Garra rota", 0, 1, 5, 15 },
  [4866] = { "Colmillo roto", 0, 1, 3, 15 },
  [9300] = { "Hoja de la luna", 4, 1, 900, 2 },
  [9301] = { "Espada del oso", 2, 1, 120, 2 },
  [6948] = { "Piedra de hogar", 1, 1, 0, 15 },
  [5000] = { "Carta del jefe", 1, 1, 0, 12 },
}
local function enlace(id, sufijo)
  local o = OBJ[id]
  local color = ({ [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [4] = "ffa335ee" })[o[2]] or "ffffffff"
  return "|c" .. color .. "|Hitem:" .. id .. "::::::" .. (sufijo or "") .. "::23:::::|h[" .. o[1] .. (sufijo and " del mono" or "") .. "]|h|r"
end
local function idDe(x) return tonumber(tostring(x):match("item:(%d+)") or x) end
C_Item.GetItemInfo = function(x)
  local id = idDe(x)
  local o = OBJ[id]
  if not o then return nil end
  return o[1], enlace(id), o[2], 20, 1, "Tipo", "Subtipo", o[3], "", 134400, o[4], o[5], 0
end
GetItemInfo = C_Item.GetItemInfo

local ESPADA = enlace(9301, "123")
local bolsa = {}
local function llenar()
  bolsa = {
    [1] = { itemID = 2589, stackCount = 5, quality = 1, hyperlink = enlace(2589) },
    [2] = { itemID = 4865, stackCount = 1, quality = 0, hyperlink = enlace(4865) },
    [3] = { itemID = 4866, stackCount = 1, quality = 0, hyperlink = enlace(4866) },
    [4] = { itemID = 9300, stackCount = 1, quality = 4, hyperlink = enlace(9300) },
    [5] = { itemID = 9301, stackCount = 1, quality = 2, hyperlink = ESPADA },
    [6] = { itemID = 6948, stackCount = 1, quality = 1, hyperlink = enlace(6948) },
    [7] = { itemID = 5000, stackCount = 1, quality = 1, hyperlink = enlace(5000) },
  }
end
llenar()
local usados = {}
local tomados = {}
local CC = {}
for k, v in pairs(C_Container or {}) do CC[k] = v end
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
C_Container.GetContainerItemQuestInfo = function(b, s)
  local i = b == 0 and bolsa[s]
  return { isQuestItem = i and i.itemID == 5000 or false }
end
C_Container.GetContainerItemCooldown = function() return 0, 0, 0 end
C_Container.UseContainerItem = function(b, s) usados[#usados + 1] = b * 100 + s if b == 0 then bolsa[s] = nil end end
C_Container.PickupContainerItem = function(b, s) tomados[#tomados + 1] = b * 100 + s end

local cursor, limpiado = nil, 0
GetCursorInfo = function() if cursor then return "item", cursor[1], cursor[2] end return nil end
CursorHasItem = function() return cursor ~= nil end
ClearCursor = function() limpiado = limpiado + 1 cursor = nil end

-- El cuadro de borrar del juego (StaticPopup), de mentira pero con su forma.
local cuadro = CreateFrame("Frame", "StaticPopup1", UIParent)
cuadro:SetSize(330, 112)
cuadro:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
cuadro:SetFrameStrata("DIALOG")
local fondo = cuadro:CreateTexture(nil, "BACKGROUND")
fondo:SetAllPoints(cuadro)
fondo:SetColorTexture(0.05, 0.05, 0.08, 0.95)
cuadro.text = cuadro:CreateFontString(nil, "ARTWORK", "GameFontNormal")
cuadro.text:SetPoint("TOP", cuadro, "TOP", 0, -16)
cuadro.text:SetWidth(290)
local function boton(texto, x)
  local b = CreateFrame("Button", nil, cuadro)
  b:SetSize(120, 24)
  b:SetPoint("BOTTOM", cuadro, "BOTTOM", x, 14)
  local t = b:CreateTexture(nil, "BACKGROUND")
  t:SetAllPoints(b)
  t:SetColorTexture(0.45, 0.08, 0.06, 1)
  b.Text = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  b.Text:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.Text:SetText(texto)
  b:Enable()
  return b
end
cuadro.button1 = boton("Sí", -66)
cuadro.button2 = boton("No", 66)
cuadro:Hide()
local mostrados = 0
function StaticPopup_Show(cual, a1)
  mostrados = mostrados + 1
  cuadro.which = cual
  cuadro.text:SetText(("¿Quieres destruir %s?"):format(tostring(a1)))
  cuadro.button1:Enable()
  cuadro:Show()
  return cuadro
end
function StaticPopup_FindVisible(cual)
  if cuadro:IsShown() and cuadro.which == cual then return cuadro end
  return nil
end
-- Lo que hace el juego al soltar un objeto fuera de las bolsas.
local function soltarFuera(id, link)
  cursor = { id, link }
  local q = OBJ[id][2]
  StaticPopup_Show(q >= 3 and "DELETE_GOOD_ITEM" or "DELETE_ITEM", link)
  FIRE_EVENT("DELETE_ITEM_CONFIRM", OBJ[id][1], q, 1, 0)
end

-- El comerciante: la pestaña «Recompra».
local recompra = {}
GetNumBuybackItems = function() return #recompra end
GetBuybackItemLink = function(i) return recompra[i] end

---------------------------------------------------------------------------
-- Entrar
---------------------------------------------------------------------------

AlfaNucleoCharDB = AlfaNucleoCharDB or {}
AlfaNucleoCharDB.candado = nil
AlfaNucleoDB = AlfaNucleoDB or {}
AlfaNucleoDB.candado = nil

local N = AlfaNucleo
local A = Alfa
local K = N.Kit
Alfa.Hidden = Alfa.Hidden or function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end

local B = NS_OF("Alfa_Bolsas")
local Co = NS_OF("Alfa_Comercio")
local Cd = B.Candado

-- Lo que se avisa (y sale igual).
local avisos = {}
local avisoOriginal = K.Aviso
K.Aviso = function(o)
  avisos[#avisos + 1] = o
  return avisoOriginal(o)
end
local function ultimoAviso() return avisos[#avisos] or {} end

local function conCombate(fn)
  local antes = InCombatLockdown
  InCombatLockdown = function() return true end
  local ok, e = pcall(fn)
  InCombatLockdown = antes
  if not ok then error(e, 0) end
end

---------------------------------------------------------------------------
-- 1. Poner y quitar
---------------------------------------------------------------------------

step("1. poner y quitar", function()
  check(type(Cd) == "table", "falta Candado.lua")
  if not Cd then return end
  check(B.Get("candado") == true and B.Get("candadoAuto") == true and B.Get("candadoCuenta") == false, "los valores de fábrica no son los pensados")
  -- La clave: lo que se apila por número; el equipo único, por su enlace (sin el nivel).
  check(Cd.Clave(2589, enlace(2589)) == "2589", "la clave del lino no es su número: " .. tostring(Cd.Clave(2589, enlace(2589))))
  check(Cd.Clave(9301, ESPADA) == "9301:123:0", "la espada con sufijo no va por su enlace: " .. tostring(Cd.Clave(9301, ESPADA)))
  check(Cd.Clave(9301, ESPADA:gsub("::23::", "::40::")) == "9301:123:0", "la clave cambia con el nivel del enlace")
  check(not Cd.Tiene(2589, enlace(2589)), "el lino ya traía candado")
  Cd.Poner(2589, enlace(2589), true)
  check(Cd.Tiene(2589, enlace(2589)), "no se le puso el candado al lino")
  check(AlfaNucleoCharDB.candado and AlfaNucleoCharDB.candado.o["2589"] == true, "el candado no quedó en el personaje")
  check(ultimoAviso().titulo == "Le pusiste candado", "no avisó al ponerlo")
  Cd.Poner(2589, enlace(2589), false)
  check(not Cd.Tiene(2589, enlace(2589)), "no se quitó el candado")
  -- La espada: solo esa (por su enlace); otra espada igual sin sufijo, no.
  Cd.Poner(9301, ESPADA, true)
  check(Cd.Tiene(9301, ESPADA) and not Cd.Tiene(9301, enlace(9301)), "el candado de la espada no fue solo para esa")
  check(Cd.ProtegeID(9301), "con solo el número (el motor), la espada no sale protegida")
  -- En toda la cuenta.
  Cd.EnCuenta(9301, ESPADA, true)
  check(AlfaNucleoDB.candado and AlfaNucleoDB.candado.o["9301:123:0"] == true and AlfaNucleoCharDB.candado.o["9301:123:0"] == nil,
    "«En toda la cuenta» no lo pasó a la cuenta")
  local si, motivo = Cd.Tiene(9301, ESPADA)
  check(si and motivo == "cuenta", "el motivo no dice «cuenta»: " .. tostring(motivo))
  Cd.Poner(9301, ESPADA, false)
  check(not Cd.Tiene(9301, ESPADA) and AlfaNucleoDB.candado.o["9301:123:0"] == nil, "no se quitó de la cuenta")

  -- Alt+clic derecho: el menú del objeto («Ponerle candado»).
  local alt, raton, menu = IsAltKeyDown, GetMouseButtonClicked, K.Menu
  local abierto
  IsAltKeyDown = function() return true end
  GetMouseButtonClicked = function() return "RightButton" end
  K.Menu = function(dueno, ops, valor, alElegir) abierto = { dueno = dueno, ops = ops, fn = alElegir } end
  local ok, e = pcall(function()
    check(Cd.AlClic(enlace(2589), 2589), "Alt+clic derecho no hizo nada")
    check(abierto and abierto.ops[1] and abierto.ops[1].texto == "Ponerle candado", "el menú no dice «Ponerle candado»")
    if abierto then abierto.fn("alternar") end
    check(Cd.Tiene(2589, enlace(2589)), "«Ponerle candado» del menú no lo puso")
    abierto = nil
    Cd.AlClic(enlace(2589), 2589)
    check(abierto and abierto.ops[1].texto == "Quitarle el candado" and abierto.ops[2] and abierto.ops[2].texto == "En toda la cuenta",
      "con candado, el menú no dice «Quitarle el candado» y «En toda la cuenta»")
    -- Alt+clic izquierdo es la guía del objeto: el candado no se mete.
    GetMouseButtonClicked = function() return "LeftButton" end
    abierto = nil
    check(not Cd.AlClic(enlace(2589), 2589) and abierto == nil, "Alt+clic izquierdo abrió el menú del candado")
    -- En combate, sin menú: cambia y ya.
    GetMouseButtonClicked = function() return "RightButton" end
    conCombate(function() Cd.AlClic(enlace(2589), 2589) end)
    check(abierto == nil and not Cd.Tiene(2589, enlace(2589)), "en combate abrió el menú o no quitó el candado")
  end)
  IsAltKeyDown, GetMouseButtonClicked, K.Menu = alt, raton, menu
  if not ok then error(e, 0) end
  -- Apagado, nada tiene candado.
  Cd.Poner(2589, enlace(2589), true)
  B.Set("candado", false)
  check(not Cd.Tiene(2589, enlace(2589)) and not Cd.Tiene(9300), "con el candado apagado algo siguió con candado")
  B.Set("candado", nil)
  check(Cd.Tiene(2589, enlace(2589)), "al volver a prenderlo se perdió el candado")
  check(Cd.Cuantos() == 1, "Cuantos no cuenta 1: " .. Cd.Cuantos())
end)

---------------------------------------------------------------------------
-- 2. Borrar
---------------------------------------------------------------------------

step("2. borrar con candado", function()
  if not Cd then return end
  Cd.Enganchar()
  -- Sin candado: el cuadro sale y nada se toca.
  limpiado = 0
  soltarFuera(4866, enlace(4866))
  check(limpiado == 0 and cursor ~= nil, "sin candado, el objeto se regresó")
  check(cuadro:IsShown() and cuadro.button1:IsEnabled(), "sin candado, el cuadro de borrar no quedó como el del juego")
  cuadro:Hide()
  cursor = nil
  -- Con candado (el lino): vuelve a su lugar y el cuadro no deja.
  local antes = #avisos
  soltarFuera(2589, enlace(2589))
  check(limpiado >= 1 and cursor == nil, "con candado, el objeto no volvió (ClearCursor)")
  check(not cuadro.button1:IsEnabled(), "con candado, el botón Aceptar del cuadro siguió prendido")
  check((cuadro.text:GetText() or ""):find("¡Este objeto tiene candado!", 1, true), "el cuadro no dice «¡Este objeto tiene candado!»")
  check(#avisos > antes and ultimoAviso().titulo == "Tiene candado: no se puede borrar", "no avisó que no se puede borrar")
  check((Cd.ultimoAviso or ""):find("Alt+clic derecho", 1, true), "el aviso no dice cómo quitarle el candado")
  -- Lo épico (automático), con el cuadro de lo bueno.
  limpiado = 0
  cuadro:Hide()
  check(cuadro.button1:IsEnabled(), "al cerrarse, el cuadro no devolvió su botón")
  soltarFuera(9300, enlace(9300))
  check(limpiado >= 1 and cuadro.which == "DELETE_GOOD_ITEM" and not cuadro.button1:IsEnabled(), "lo épico se dejó borrar")
  check(Cd.ganchos == 1, "los ganchos del cuadro se pusieron más de una vez: " .. tostring(Cd.ganchos))
  -- Con el candado apagado, se borra como siempre.
  cuadro:Hide()
  limpiado = 0
  B.Set("candado", false)
  soltarFuera(9300, enlace(9300))
  check(limpiado == 0 and cuadro.button1:IsEnabled(), "con el candado apagado no dejó borrar")
  B.Set("candado", nil)
  cuadro:Hide()
  cursor = nil
  soltarFuera(9300, enlace(9300))
  -- La captura: el cuadro apagado y el aviso de Alfa.
  SNAP("borrar", cuadro, {})
  local o = { titulo = "Tiene candado: no se puede borrar", texto = Cd.ultimoAviso, icono = "ic-candado", tono = "aviso", pedido = true, lya = false, duracion = 30 }
  local av = avisoOriginal(o)
  check(type(av) == "table" and av.IsShown and av:IsShown(), "el aviso de no borrar no salió")
  if type(av) == "table" and av.IsShown then SNAP("borrar-aviso", av, {}) end
  cuadro:Hide()
  cursor = nil
end)

---------------------------------------------------------------------------
-- 3. Vender: la capa en tus bolsas
---------------------------------------------------------------------------

local function bombear(w)
  for _ = 1, 80 do
    local fn = w:GetScript("OnUpdate")
    if not fn then break end
    fn(w, 0.02)
  end
end

local function botonDe(w, s)
  for _, fila in pairs(w.vivos or {}) do
    local b = fila[s]
    if b then return b end
  end
  return nil
end

step("3. vender con candado", function()
  if not Cd then return end
  Cd.Poner(4865, enlace(4865), true) -- lo gris también puede llevar candado
  B.Ventana.MostrarBolsas(true)
  local w = B.Ventana.Ventana("bolsas")
  bombear(w)
  -- La marca.
  local marcas = 0
  for b2 in pairs(w.puestos or {}) do
    local p2 = B.Botones.Partes[b2]
    if p2 and p2.candado and p2.candado:IsShown() then marcas = marcas + 1 end
  end
  -- lino, garra, hoja (épica), piedra de hogar y la carta de misión
  check(marcas == 5, "no salieron los 5 candados en tus bolsas: " .. marcas)
  local pGarra = B.Botones.Partes[botonDe(w, 2)]
  check(pGarra and not pGarra.chatarra:IsShown(), "lo gris con candado sigue con la moneda de chatarra")
  -- Sin comerciante, ninguna capa.
  local bLino = botonDe(w, 1)
  check(bLino and not (Cd.Capas[bLino] and Cd.Capas[bLino]:IsShown()), "sin comerciante salió la capa")
  -- Con el comerciante: la capa en lo que tiene candado.
  usados = {}
  FIRE_EVENT("MERCHANT_SHOW")
  T(4)
  bombear(w)
  local capa = Cd.Capas[bLino]
  check(capa and capa:IsShown(), "con el comerciante no salió la capa sobre el lino")
  local bColmillo = botonDe(w, 3)
  check(not (Cd.Capas[bColmillo] and Cd.Capas[bColmillo]:IsShown()), "lo que no tiene candado quedó cubierto")
  if capa then
    local antes = Cd.bloqueadas or 0
    capa:Click("RightButton")
    check((Cd.bloqueadas or 0) == antes + 1 and bolsa[1] ~= nil, "el clic derecho vendió el lino con candado")
    check(ultimoAviso().titulo == "Tiene candado: no se vende", "no avisó que no se vende")
    tomados = {}
    capa:Click("LeftButton")
    check(tomados[1] == 1, "el clic izquierdo no tomó el lino (para moverlo)")
  end
  for _, u in ipairs(usados) do
    check(u ~= 1 and u ~= 2 and u ~= 4, "se vendió algo con candado: casilla " .. u)
  end
  -- En combate, ninguna capa.
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not (capa and capa:IsShown()), "en combate se quedó la capa")
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  T(2)
  bombear(w)
  check(capa and capa:IsShown(), "al salir del combate no volvió la capa")
  w:ClearAllPoints()
  w:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  SNAP("bolsas", w, {})
  FIRE_EVENT("MERCHANT_CLOSED")
  check(not capa:IsShown(), "al cerrar el comerciante se quedó la capa")
  B.Ventana.MostrarBolsas(false)
end)

---------------------------------------------------------------------------
-- 4. La venta de lo gris, la sugerencia y «Mandar a tu alt»
---------------------------------------------------------------------------

step("4. lo gris y lo demás se lo saltan", function()
  if not Cd then return end
  llenar()
  local Q = A.QoL
  local V = Q and Q.Vendor
  check(V and V.JunkAt, "falta la regla del motor (QoL.Vendor.JunkAt)")
  if V and V.JunkAt then
    check(V.JunkAt(0, 2) == nil, "la regla del motor vendería la garra con candado")
    check(V.JunkAt(0, 3) == 4866, "la regla del motor no vende el colmillo gris sin candado")
  end
  check(Q.Marks.Protected(4865) == true and Q.Marks.Protected(4866) ~= true, "Marks.Protected no dice lo del candado")
  -- Marcada como chatarra y con candado: tampoco.
  Q.Marks.Set(2589, "junk")
  check(not Q.Marks.Junk(2589), "el lino con candado marcado como chatarra se vendería")
  Q.Marks.Set(2589, nil)
  -- La venta sola al abrir el comerciante (si está prendida).
  usados = {}
  FIRE_EVENT("MERCHANT_SHOW")
  T(6)
  for _, u in ipairs(usados) do check(u ~= 2 and u ~= 1 and u ~= 4, "la venta sola vendió algo con candado: casilla " .. u) end
  FIRE_EVENT("MERCHANT_CLOSED")
  llenar()
  -- «Vender la chatarra» de las bolsas.
  local S = B.Sugerencias
  local lista = S.ChatarraAhora()
  for _, e in ipairs(lista) do check(e[2] ~= 2, "«Vender la chatarra» incluye la garra con candado") end
  -- La sugerencia de qué vender (y «Separar», «Marcar para vender»).
  S.Invalidar()
  local est = S.Estado()
  for _, g in ipairs(est.vender or {}) do check(g.id ~= 4865 and g.id ~= 2589, "la sugerencia vendería algo con candado: " .. g.id) end
  for _, g in ipairs(est.conservar or {}) do check(g.id ~= 9300, "la sugerencia subastaría la hoja con candado") end
  -- «Mandar a tu alt»: lo que tiene candado no se adjunta.
  local En = Co.Envios
  if En then
    local l = { tipos = {}, ids = { [2589] = true, [4866] = true } }
    local c = En.Candidatos(l)
    local hay = {}
    for _, e in ipairs(c) do hay[e.id] = true end
    check(not hay[2589] and hay[4866], "«Mandar a tu alt» adjuntaría el lino con candado")
  else
    check(false, "falta Comercio.Envios")
  end
end)

---------------------------------------------------------------------------
-- 5. El automático
---------------------------------------------------------------------------

step("5. el automático", function()
  if not Cd then return end
  local si, motivo = Cd.Tiene(9300, enlace(9300))
  check(si and motivo == "epico", "lo épico no trae candado solo: " .. tostring(motivo))
  check(select(2, Cd.Tiene(6948)) == "hogar", "la piedra de hogar no trae candado solo")
  check(select(2, Cd.TieneCasilla(0, 7)) == "mision", "la carta de misión no trae candado solo")
  check(not Cd.Tiene(4866), "lo gris trajo candado solo")
  -- Tus conjuntos.
  local Cj = B.Conjuntos
  local lista = Cj.Lista
  Cj.Lista = function() return { { n = "Daño", p = { [16] = { i = 9301, l = ESPADA } } } } end
  B.Avisar("CONJUNTOS")
  check(select(2, Cd.Tiene(9301, enlace(9301))) == "conjunto", "lo de tus conjuntos no trae candado solo")
  Cj.Lista = lista
  B.Avisar("CONJUNTOS")
  -- Quitarle el candado a uno automático: queda sin candado (y el motor lo sabe).
  Cd.Poner(9300, enlace(9300), false)
  check(not Cd.Tiene(9300, enlace(9300)) and not Cd.ProtegeID(9300), "quitarle el candado a lo épico no lo quitó")
  Cd.Poner(9300, enlace(9300), true)
  check(Cd.Tiene(9300, enlace(9300)), "volver a ponerle candado a lo épico no lo puso")
  -- Apagado el automático.
  B.Set("candadoAuto", false)
  check(not Cd.Tiene(6948) and not Cd.TieneCasilla(0, 7), "con el automático apagado, siguió el candado solo")
  check(Cd.Tiene(9300, enlace(9300)), "apagar el automático quitó un candado puesto a mano")
  B.Set("candadoAuto", nil)
  -- La página de Bolsas trae el grupo «Candado de objetos».
  check(B.AJUSTES.candado ~= nil and B.AJUSTES.candadoAuto ~= nil and B.AJUSTES.candadoCuenta ~= nil, "faltan los ajustes del candado")
end)

---------------------------------------------------------------------------
-- 6. Lo vendido con candado y el comercio
---------------------------------------------------------------------------

step("6. recompra y comercio", function()
  if not Cd then return end
  recompra = {}
  FIRE_EVENT("MERCHANT_SHOW")
  T(2)
  local antes = #avisos
  recompra[1] = enlace(4866)
  FIRE_EVENT("MERCHANT_UPDATE")
  check(#avisos == antes or ultimoAviso().titulo ~= "Vendiste algo con candado", "avisó por vender algo sin candado")
  recompra[2] = enlace(2589)
  FIRE_EVENT("MERCHANT_UPDATE")
  check(ultimoAviso().titulo == "Vendiste algo con candado", "no avisó que vendiste algo con candado")
  FIRE_EVENT("MERCHANT_CLOSED")
  -- El comercio.
  GetTradePlayerItemLink = function(i) if i == 1 then return enlace(9300) end return nil end
  FIRE_EVENT("TRADE_PLAYER_ITEM_CHANGED", 1)
  check(ultimoAviso().titulo == "Ojo: tiene candado" and (ultimoAviso().texto or ""):find("comercio", 1, true), "no avisó del candado en el comercio")
  local n = #avisos
  FIRE_EVENT("TRADE_PLAYER_ITEM_CHANGED", 1)
  check(#avisos == n, "avisó dos veces lo mismo en el comercio")
  FIRE_EVENT("TRADE_CLOSED")
  -- La subasta (Comercio la avisa).
  check(AlfaBolsas.AvisarCandado(9300, nil, "subasta") == true, "AlfaBolsas.AvisarCandado no avisó de la subasta")
  check(AlfaBolsas.TieneCandado(0, 1) == true and AlfaBolsas.TieneCandado(0, 3) == false, "AlfaBolsas.TieneCandado no cuadra")
end)

---------------------------------------------------------------------------
-- 7. Las bolsas del juego (si Alfa no las reemplaza)
---------------------------------------------------------------------------

step("7. las bolsas del juego", function()
  if not Cd then return end
  llenar()
  local R = B.Reemplazo
  local activo = R.Activo
  R.Activo = function() return false end
  local marco = CreateFrame("Frame", "ContainerFrame1", UIParent)
  marco:SetSize(200, 100)
  marco:Show()
  local botones = {}
  for s = 1, 3 do
    local b = CreateFrame("Button", nil, marco)
    b:SetSize(37, 37)
    b:SetPoint("TOPLEFT", marco, "TOPLEFT", (s - 1) * 40, 0)
    b.GetBagID = function() return 0 end
    b.GetID = function() return s end
    botones[s] = b
  end
  function marco:EnumerateValidItems()
    local i = 0
    return function() i = i + 1 if botones[i] then return i, botones[i] end end
  end
  local ok, e = pcall(function()
    check(Cd.Juego() == 2, "en las bolsas del juego no salieron los 2 candados (lino y garra)")
    FIRE_EVENT("MERCHANT_SHOW")
    T(2)
    Cd.Juego()
    local c = Cd.Capas[botones[1]]
    check(c and c:IsShown(), "con el comerciante, la casilla del juego con candado no quedó cubierta")
    check(not (Cd.Capas[botones[3]] and Cd.Capas[botones[3]]:IsShown()), "lo que no tiene candado quedó cubierto en las bolsas del juego")
    FIRE_EVENT("MERCHANT_CLOSED")
    check(not (c and c:IsShown()), "al cerrar el comerciante se quedó la capa en las bolsas del juego")
  end)
  R.Activo = activo
  marco:Hide()
  if not ok then error(e, 0) end
  -- Con las de Alfa, nada en las del juego.
  check(Cd.Juego() == 0, "con las bolsas de Alfa se pintaron candados en las del juego")
end)

for k, v in pairs(CC) do C_Container[k] = v end
K.Aviso = avisoOriginal
print(("prueba_138_candado: %d pasos; borrados parados %d, ventas paradas %d, avisos %d"):format(pasos, Cd and Cd.parados or 0, Cd and Cd.bloqueadas or 0, #avisos))
