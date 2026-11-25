-- Prueba de la 1.4.0, mejoras del día a día (tools/prueba.py la corre con las demás):
--   90. «Aprender todo» en el entrenador (Alfa_Rutas/Entrenador.lua);
--   91. «¿Reiniciar la mazmorra?» al salir (Alfa_Mazmorras/Reiniciar.lua);
--   92. «Tienes algo por abrir» con «Abrir» seguro (Alfa_Bolsas/Abrir.lua);
--   93. «Ya puedes aprender una receta» (Abrir.lua, con el cuadro del juego);
--   94. «¿Lo vendiste sin querer?» con «Recomprar» (Alfa_Comercio/Recompra.lua);
--   95. Alt+clic en el comerciante compra una pila (Alfa_Comercio/Pila.lua);
--   96. un recurso nuevo al subir Minería (Alfa_Recoleccion/Avisos.lua);
--   97. la herramienta que falta (Avisos.lua, por el error del juego);
--   98. lo de tus misiones que está en tu banco, con «Sacarlo» (Alfa_Bolsas/ParaMisiones.lua);
--   99. un vuelo que no conoces, cerca (Alfa_Mundo/VueloCerca.lua);
--  100. los botones seguros del Kit pasan "item" y "spell" (la piedra de hogar del rastreador);
--  101. «Ponte la bolsa» (Alfa_Bolsas/BolsaNueva.lua).
-- Con BANCO_FOTOS=1 dibuja las capturas (shot-140-diario-*.png; BANCO_CAPTURAS elige la carpeta).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["140-diario-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
end
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 900)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.4.0 diario", msg) end end
local function T(n) RUN_TIMERS(n or 2) end
local function fondo(de, extra)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetPoint("TOPLEFT", de, "TOPLEFT", -16, 16)
  f:SetPoint("BOTTOMRIGHT", extra or de, "BOTTOMRIGHT", 16, -16)
  local c = f:CreateTexture(nil, "BACKGROUND")
  c:SetAllPoints(f)
  c:SetTexture("white")
  c:SetGradient("VERTICAL", CreateColor(0.03, 0.04, 0.05, 1), CreateColor(0.09, 0.11, 0.15, 1))
  f:Show()
  return f
end

local N = AlfaNucleo
local A = Alfa
local K = N.Kit
Alfa.Hidden = Alfa.Hidden or function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end

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

local Ru = NS_OF("Alfa_Rutas")
local Mz = NS_OF("Alfa_Mazmorras")
local Bo = NS_OF("Alfa_Bolsas")
local Co = NS_OF("Alfa_Comercio")
local Re = NS_OF("Alfa_Recoleccion")
local Mu = NS_OF("Alfa_Mundo")

---------------------------------------------------------------------------
-- 90. «Aprender todo» en el entrenador
---------------------------------------------------------------------------
step("90. el entrenador: aprende lo que alcanza, de lo más barato, del último al primero", function()
  local En = Ru.Entrenador
  check(En ~= nil, "no cargó Entrenador.lua")
  local servicios = {
    { "Golpe heroico", "Rango 3", "available", 100 },
    { "Cargar", "Rango 2", "used", 50 },
    { "Rugido", "Rango 2", "available", 5000 },
    { "Torbellino", nil, "available", 200000 },
    { "Armas", nil, "header", 0 },
  }
  local comprados = {}
  local trainer = CreateFrame("Frame", "ClassTrainerFrame", UIParent)
  trainer:SetSize(384, 512) trainer:SetPoint("CENTER") trainer:Show()
  con({
    GetNumTrainerServices = function() return #servicios end,
    GetTrainerServiceInfo = function(i) local s = servicios[i] return s[1], s[2], s[3] end,
    GetTrainerServiceCost = function(i) return servicios[i][4] end,
    BuyTrainerService = function(i) comprados[#comprados + 1] = i end,
  }, function()
    local lista, total, alcanza = En.Lista()
    check(#lista == 3, "debían salir 3 disponibles, salieron " .. #lista)
    check(total == 205100, "el total no cuadra: " .. tostring(total))
    check(alcanza == 2, "con 12o 34p alcanza para 2, dijo " .. tostring(alcanza))
    FIRE_EVENT("TRAINER_SHOW")
    T(2)
    local b = En.Boton()
    check(b and b:IsShown(), "el botón no salió con el entrenador abierto")
    local txt = b and b.Texto and b.Texto:GetText() or ""
    check(txt:find("2", 1, true) and txt:find("3", 1, true), "el botón no dice «2 de 3»: " .. txt)
    check(txt:find(N.Dinero(5100), 1, true) and not txt:find(N.Dinero(205100), 1, true), "el botón no dice lo que cuesta lo que te alcanza: " .. txt)
    SNAP("entrenador", fondo(trainer, b), { trainer, b })
    local hechos, costo, faltaron = En.Aprender()
    check(hechos == 2 and costo == 5100 and faltaron == 1, ("aprendió %s por %s (faltaron %s)"):format(tostring(hechos), tostring(costo), tostring(faltaron)))
    check(comprados[1] == 3 and comprados[2] == 1, "no compró del último al primero: " .. table.concat(comprados, ","))
    -- Con secretos del juego no truena (el costo secreto cuenta como 0, no se compara).
    SECRETOS_PRENDER({ "GetTrainerServiceCost", "GetTrainerServiceInfo" })
    local ok = pcall(En.Lista)
    SECRETOS_APAGAR()
    check(ok, "En.Lista tronó con valores secretos")
    FIRE_EVENT("TRAINER_CLOSED")
    check(not b:IsShown(), "el botón se quedó al cerrar el entrenador")
  end)
  trainer:Hide()
end)

---------------------------------------------------------------------------
-- 91. «¿Reiniciar la mazmorra?» al salir
---------------------------------------------------------------------------
step("91. al salir de una mazmorra, solo: ofrece reiniciar y el botón la reinicia", function()
  local R = Mz.Reiniciar
  check(R ~= nil, "no cargó Reiniciar.lua")
  local dentro, reinicios, grupo, lider = true, 0, false, false
  limpiar()
  con({
    IsInInstance = function() if dentro then return true, "party" end return false, "none" end,
    GetInstanceInfo = function() if dentro then return "Minas de la Muerte", "party", 1, "", 5, 0, false, 36 end return "Elwynn", "none", 0, "", 0, 0, false, 0 end,
    ResetInstances = function() reinicios = reinicios + 1 end,
    CanShowResetInstances = function() return true end,
    IsInGroup = function() return grupo end,
    UnitIsGroupLeader = function() return lider end,
  }, function()
    FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
    T(4)
    check(avisoCon("mazmorras.reiniciar") == nil, "ofreció reiniciar estando dentro")
    dentro = false
    FIRE_EVENT("PLAYER_LEAVING_WORLD")
    FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
    T(4)
    local o = avisoCon("mazmorras.reiniciar")
    check(o ~= nil, "no ofreció reiniciar al salir")
    check(o and o.texto:find("Minas de la Muerte", 1, true), "el aviso no nombra la mazmorra: " .. tostring(o and o.texto))
    if o then o.acciones[1].alClic() end
    check(reinicios == 1, "el botón no reinició la mazmorra")
    -- En grupo sin ser líder: no se puede, y lo dice.
    grupo = true
    local ok, por = R.Puede()
    check(not ok and por == "grupo", "en grupo sin ser líder dejó reiniciar")
    lider = true
    check(R.Puede() == true, "como líder no dejó reiniciar")
    grupo, lider = false, false
  end)
end)

---------------------------------------------------------------------------
-- Bolsas a mano (92, 93, 98, 101)
---------------------------------------------------------------------------
local bolsas = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }
local numCasillas = { [0] = 16, [1] = 6, [2] = 0, [3] = 8, [4] = 10 }
local usados = {}
local CC = {
  GetContainerNumSlots = function(b) return numCasillas[b] or 0 end,
  GetContainerItemInfo = function(b, s) return bolsas[b] and bolsas[b][s] end,
  GetContainerItemID = function(b, s) local i = bolsas[b] and bolsas[b][s] return i and i.itemID end,
  UseContainerItem = function(b, s) usados[#usados + 1] = { b, s } end,
}
local function objeto(id, n, extra)
  local t = { itemID = id, stackCount = n or 1, hyperlink = "|cffffffff|Hitem:" .. id .. "::::::::|h[Objeto " .. id .. "]|h|r", iconFileID = 134400, quality = 1 }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end
local CLASES = { [5523] = { 15, 0 }, [2555] = { 9, 3 }, [2556] = { 9, 3 }, [4496] = { 1, 0 }, [804] = { 1, 0 } }
local cuadros = {}
local CI = {}
for k, v in pairs(C_Item) do CI[k] = v end
CI.GetItemInfoInstant = function(id) local c = CLASES[id] or { 0, 0 } return id, "", "", "", 0, c[1], c[2] end

step("92. lo que se abre: avisa lo que llega (no lo que ya traías) con «Abrir» seguro y vuelve tras abrir", function()
  local Ab = Bo.Abrir
  check(Ab ~= nil, "no cargó Abrir.lua")
  bolsas[0][1] = objeto(5523, 1, { hasLoot = true }) -- ya la traías
  con({ C_Container = CC, C_Item = CI }, function()
    Ab.Base()
    limpiar()
    Ab.RevisarAhora()
    check(avisoCon("bolsas.porAbrir.abrir") == nil, "avisó lo que ya traías al entrar")
    bolsas[0][2] = objeto(5523, 2, { hasLoot = true })
    Ab.RevisarAhora()
    local o = avisoCon("bolsas.porAbrir.abrir")
    check(o ~= nil, "no avisó la almeja nueva")
    local ac = o and o.acciones and o.acciones[1]
    check(ac and type(ac.seguro) == "table" and ac.seguro.macrotext == "/use [nocombat] item:5523", "el botón «Abrir» no es seguro con /use item: " .. tostring(ac and ac.seguro and ac.seguro.macrotext))
    check(o and o.texto:find("×3", 1, true), "no cuenta las 3 almejas: " .. tostring(o and o.texto))
    -- Abres una (el clic es del juego): vuelve con las que faltan.
    limpiar()
    if ac and ac.trasClic then ac.trasClic() end
    bolsas[0][2] = objeto(5523, 1, { hasLoot = true })
    Ab.RevisarAhora()
    check(avisoCon("bolsas.porAbrir.abrir") ~= nil, "tras abrir una no volvió con las que faltan")
    -- Lo que tiene candado no se toca; una casilla bloqueada tampoco.
    bolsas[0][1], bolsas[0][2] = nil, nil
    bolsas[0][3] = objeto(5523, 1, { hasLoot = true, isLocked = true })
    check(#Ab.Revisar().abrir == 0, "contó una casilla bloqueada")
    bolsas[0][3] = nil
  end)
end)

step("93. las recetas: solo las que ya puedes aprender (sin «Ya lo conoces» ni requisitos en rojo)", function()
  local Ab = Bo.Abrir
  ITEM_SPELL_KNOWN = "Ya lo conoces"
  local TIP = {
    GetBagItem = function(b, s)
      local l = cuadros[b .. ":" .. s]
      return l and { lines = l } or nil
    end,
  }
  con({ C_Container = CC, C_Item = CI, C_TooltipInfo = TIP }, function()
    Ab.Base()
    limpiar()
    bolsas[0][4] = objeto(2555)
    cuadros["0:4"] = { { leftText = "Receta: Poción", leftColor = { r = 1, g = 1, b = 1 } }, { leftText = "Requiere Alquimia (50)", leftColor = { r = 1, g = 0.125, b = 0.125 } } }
    bolsas[0][5] = objeto(2556)
    cuadros["0:5"] = { { leftText = "Receta: Elixir" }, { leftText = "Ya lo conoces", leftColor = { r = 1, g = 0.125, b = 0.125 } } }
    Ab.RevisarAhora()
    check(avisoCon("bolsas.porAbrir.aprender") == nil, "avisó una receta que aún no puedes aprender o que ya conoces")
    cuadros["0:4"][2].leftColor = { r = 1, g = 1, b = 1 }
    bolsas[0][4] = nil
    Ab.RevisarAhora()
    bolsas[0][4] = objeto(2555)
    Ab.RevisarAhora()
    local o = avisoCon("bolsas.porAbrir.aprender")
    check(o ~= nil, "no avisó la receta que ya puedes aprender")
    check(o and o.acciones[1].seguro.macrotext:find("item:2555", 1, true), "«Aprender» no usa la receta")
    -- Sin el cuadro del juego no se adivina.
    bolsas[0][4], bolsas[0][5] = nil, nil
  end)
  ITEM_SPELL_KNOWN = nil
end)

step("101. «Ponte la bolsa»: con hueco, «Ponérmela»; sin hueco y más grande, cómo cambiarla", function()
  local Bn = Bo.BolsaNueva
  check(Bn ~= nil, "no cargó BolsaNueva.lua")
  CONTAINER_SLOTS = "%d Slot %s"
  local equipada
  local CI2 = {}
  for k, v in pairs(CI) do CI2[k] = v end
  CI2.EquipItemByName = function(x) equipada = x end
  local TIP = { GetBagItem = function(b, s) local l = cuadros[b .. ":" .. s] return l and { lines = l } or nil end }
  con({ C_Container = CC, C_Item = CI2, C_TooltipInfo = TIP }, function()
    Bn.Base()
    limpiar()
    bolsas[0][6] = objeto(4496)
    cuadros["0:6"] = { { leftText = "Bolsa de lino" }, { leftText = "10 Slot Bag" } }
    check(Bn.CasillasDe(0, 6) == 10, "no leyó las casillas de la bolsa: " .. tostring(Bn.CasillasDe(0, 6)))
    Bn.RevisarAhora()
    local o = avisoCon("bolsas.bolsaNueva")
    check(o ~= nil and o.acciones and o.acciones[1], "con un hueco libre no ofreció ponérmela")
    check(o and o.texto:find("10", 1, true), "no dice sus casillas: " .. tostring(o and o.texto))
    if o then o.acciones[1].alClic() end
    check(equipada ~= nil, "«Ponérmela» no la equipó")
    -- Sin hueco: si es más grande que la más chica (6), lo dice sin botón.
    numCasillas[2] = 4
    limpiar()
    bolsas[0][7] = objeto(804)
    cuadros["0:7"] = { { leftText = "Bolsa grande" }, { leftText = "12 Slot Bag" } }
    Bn.RevisarAhora()
    o = avisoCon("bolsas.bolsaNueva")
    check(o ~= nil and o.titulo == "Una bolsa más grande", "sin hueco no dijo que es más grande")
    check(o and o.texto:find("12", 1, true) and o.texto:find("4", 1, true), "no compara con la más chica: " .. tostring(o and o.texto))
    numCasillas[2] = 0
    bolsas[0][6], bolsas[0][7] = nil, nil
  end)
end)

step("98. lo de tus misiones en el banco: lo dice con el banco abierto y «Sacarlo» saca solo lo que falta", function()
  local Pm = Bo.ParaMisiones
  check(Pm ~= nil, "no cargó ParaMisiones.lua")
  local Q = A.QuestDB
  local viejo = { Q.ObjectivesForItem, Q.IsRunning, Q.GetQuestTitle }
  Q.IsRunning = function() return true end
  Q.ObjectivesForItem = function(id) if id == 2318 then return { { q = 33, cur = 2, max = 8, done = false } } end return nil end
  Q.GetQuestTitle = function(q) return q == 33 and "Pieles para Eldrin" or nil end
  for b = 6, 8 do bolsas[b] = {} numCasillas[b] = 4 end
  bolsas[6][1] = objeto(2318, 4)
  bolsas[7][2] = objeto(2318, 4)
  bolsas[8][1] = objeto(2318, 2)
  bolsas[8][3] = objeto(999, 5)
  usados = {}
  con({ C_Container = CC, C_Item = CI }, function()
    limpiar()
    FIRE_EVENT("BANKFRAME_OPENED")
    T(3)
    local lista = Pm.Lista(true)
    check(#lista == 1 and lista[1].enBanco == 10 and lista[1].falta == 6, "la lista no cuadra")
    local o = avisoCon("bolsas.paraMisiones")
    check(o ~= nil, "con el banco abierto no avisó")
    check(o and o.texto:find("Pieles para Eldrin", 1, true), "no nombra la misión: " .. tostring(o and o.texto))
    check(o and o.texto:find("×6", 1, true), "no dice cuántos faltan: " .. tostring(o and o.texto))
    if o then o.acciones[1].alClic() end
    T(4)
    check(#usados == 2, "debía sacar 2 montones (4 + 4 para 6), sacó " .. #usados)
    FIRE_EVENT("BANKFRAME_CLOSED")
    T(1)
  end)
  for b = 6, 8 do bolsas[b] = nil numCasillas[b] = nil end
  Q.ObjectivesForItem, Q.IsRunning, Q.GetQuestTitle = viejo[1], viejo[2], viejo[3]
end)

---------------------------------------------------------------------------
-- 94. «¿Lo vendiste sin querer?»
---------------------------------------------------------------------------
step("94. vender algo azul avisa con «Recomprar»; lo gris o una tanda, no", function()
  local Rc = Co.Recompra
  check(Rc ~= nil, "no cargó Recompra.lua")
  local recompra, recomprado = {}, nil
  local CIq = {}
  for k, v in pairs(C_Item) do CIq[k] = v end
  CIq.GetItemInfo = function(link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    local q = (id == 9999) and 3 or 0
    return "x", link, q, 20, 20, "Armadura", "Tela", 1, (id == 9999) and "INVTYPE_CHEST" or ""
  end
  local function link(id) return "|cff0070dd|Hitem:" .. id .. "::::::::|h[Pieza " .. id .. "]|h|r" end
  con({
    C_Item = CIq,
    GetNumBuybackItems = function() return #recompra end,
    GetBuybackItemLink = function(i) return recompra[i] end,
    GetBuybackItemInfo = function(i) return "Pieza", 134400, 12000, 1 end,
    BuybackItem = function(i) recomprado = i end,
  }, function()
    limpiar()
    FIRE_EVENT("MERCHANT_SHOW")
    recompra[#recompra + 1] = link(117) -- algo gris
    FIRE_EVENT("MERCHANT_UPDATE")
    T(1)
    check(avisoCon("comercio.recompra") == nil, "avisó por vender lo gris")
    FIRE_EVENT("MERCHANT_CLOSED")
    FIRE_EVENT("MERCHANT_SHOW")
    recompra[#recompra + 1] = link(9999) -- una pieza azul
    FIRE_EVENT("MERCHANT_UPDATE")
    T(1)
    local o = avisoCon("comercio.recompra")
    check(o ~= nil, "no avisó la pieza azul vendida")
    check(o and o.texto:find("1o 20p", 1, true) or (o and o.texto:find("1", 1, true)), "no dice cuánto te pagaron")
    if o then o.acciones[1].alClic() end
    check(recomprado == 2, "«Recomprar» no recompró la pieza correcta: " .. tostring(recomprado))
    -- Una tanda (tres ventas juntas): a propósito, no avisa.
    FIRE_EVENT("MERCHANT_CLOSED")
    FIRE_EVENT("MERCHANT_SHOW")
    limpiar()
    for _ = 1, 3 do recompra[#recompra + 1] = link(9999) FIRE_EVENT("MERCHANT_UPDATE") end
    T(1)
    check(avisoCon("comercio.recompra") == nil, "avisó en una tanda de ventas")
    FIRE_EVENT("MERCHANT_CLOSED")
  end)
end)

---------------------------------------------------------------------------
-- 95. Alt+clic compra una pila
---------------------------------------------------------------------------
step("95. Alt+clic compra una pila: lo del montón, en compras enteras, sin pasar del dinero", function()
  local Pi = Co.Pila
  check(Pi ~= nil, "no cargó Pila.lua")
  local compras = {}
  local CIp = {}
  for k, v in pairs(C_Item) do CIp[k] = v end
  CIp.GetItemInfo = function() return "Agua", "link", 1, 5, 1, "Consumible", "Bebida", 20 end
  local alt = true
  local boton = CreateFrame("Button", "MerchantItem1ItemButton", UIParent)
  boton.GetID = function() return 1 end
  local MF = CreateFrame("Frame", "MerchantFrame", UIParent)
  MF.selectedTab = 1
  con({
    C_Item = CIp, C_MerchantFrame = false,
    GetMerchantItemInfo = function() return "Agua refrescante", 134400, 25, 1, -1, true, true, false end,
    GetMerchantItemLink = function() return "|Hitem:159::::::::|h[Agua refrescante]|h" end,
    GetMerchantItemMaxStack = function() return 20 end,
    BuyMerchantItem = function(i, n) compras[#compras + 1] = { i, n } end,
    IsAltKeyDown = function() return alt end, IsShiftKeyDown = function() return false end, IsControlKeyDown = function() return false end,
  }, function()
    local n, costo = Pi.Plan(1)
    check(n == 20 and costo == 500, ("el plan no cuadra: %s por %s"):format(tostring(n), tostring(costo)))
    FIRE_EVENT("MERCHANT_SHOW")
    FIRE_EVENT("MERCHANT_SHOW") -- abrir otra vez no pone otro gancho
    FIRE(boton, "OnClick", "LeftButton")
    check(#compras == 1 and compras[1][2] == 20, "Alt+clic no compró la pila una sola vez: " .. #compras)
    alt = false
    FIRE(boton, "OnClick", "LeftButton")
    check(#compras == 1, "un clic sin Alt compró")
    -- En la pestaña de recompra, nada.
    alt, MF.selectedTab = true, 2
    FIRE(boton, "OnClick", "LeftButton")
    check(#compras == 1, "compró en la pestaña de recompra")
  end)
  -- Sin dinero suficiente: lo que alcanza.
  con({ C_Item = CIp, C_MerchantFrame = false, GetMoney = function() return 120 end,
    GetMerchantItemInfo = function() return "Agua refrescante", 134400, 25, 1, -1, true, true, false end,
    GetMerchantItemLink = function() return "|Hitem:159::::::::|h[Agua refrescante]|h" end }, function()
    local n = Pi.Plan(1)
    check(n == 4, "con 1p 20c debían ser 4, salió " .. tostring(n))
  end)
  MF.selectedTab = 1
  MF:Hide()
end)

---------------------------------------------------------------------------
-- 96 y 97. Recolección
---------------------------------------------------------------------------
step("96. al subir Minería de 60 a 70: «Ya puedes minar Filón de estaño» con «Llévame»", function()
  local Av = Re.Avisos
  check(Av ~= nil, "no cargó Avisos.lua de Recolección")
  local R = Re.R
  local nuevos = Av.Nuevos("mineria", 60, 70)
  local hay = false
  for _, g in ipairs(nuevos) do if Re.GRUPOS[g].clave == "tin_vein" then hay = true end end
  check(hay, "el estaño (65) no sale entre 60 y 70")
  check(#Av.Nuevos("mineria", 70, 70) == 0, "sin subir salió algo nuevo")
  local hab, listas = R.Habilidad, R.HabilidadesListas
  local nivel = 60
  R.Habilidad = function(t) if t == "mineria" then return nivel end return nil end
  R.HabilidadesListas = function() return true end
  limpiar()
  Av.Visto("mineria", nil)
  Av.AlSubir() -- la primera vez solo anota
  check(avisoCon("recoleccion.nuevo.mineria") == nil, "avisó al entrar lo que ya podías")
  nivel = 70
  Av.AlSubir()
  local o = avisoCon("recoleccion.nuevo.mineria")
  check(o ~= nil, "no avisó el recurso nuevo")
  check(o and o.texto:find("estaño", 1, true), "no nombra el estaño: " .. tostring(o and o.texto))
  check(o and o.acciones and o.acciones[1] and o.acciones[1].texto == "Llévame", "sin «Llévame»")
  R.Habilidad, R.HabilidadesListas = hab, listas
end)

step("97. el error del juego por el pico: dice qué falta (y si está en tu banco), una vez", function()
  local Av = Re.Avisos
  local CIn = {}
  for k, v in pairs(C_Item) do CIn[k] = v end
  CIn.GetItemNameByID = function(id) if id == 2901 then return "Pico de minero" end if id == 7005 then return "Cuchillo para desollar" end end
  local B = AlfaBolsas
  local cuantos = B and B.Cuantos
  if B then B.Cuantos = function(id) if id == 2901 then return 1, 0, 1, 1 end return 0, 0, 0, 0 end end
  con({ C_Item = CIn }, function()
    limpiar()
    check(Av.AlError("Requiere Hechizo de fuego") == nil, "avisó por otro error")
    FIRE_EVENT("UI_ERROR_MESSAGE", 50, "Requiere Pico de minero")
    local o = avisoCon("recoleccion.herramienta")
    check(o ~= nil, "no explicó la herramienta que falta")
    check(o and o.texto:find("banco", 1, true), "no dice que está en tu banco: " .. tostring(o and o.texto))
    limpiar()
    FIRE_EVENT("UI_ERROR_MESSAGE", 50, "Requiere Pico de minero")
    check(avisoCon("recoleccion.herramienta") == nil, "repitió el aviso")
    -- Un texto secreto no truena.
    check(pcall(Av.AlError, SECRETO("Requiere Cuchillo para desollar")), "tronó con un texto secreto")
  end)
  if B then B.Cuantos = cuantos end
end)

---------------------------------------------------------------------------
-- 99. Un vuelo que no conoces, cerca
---------------------------------------------------------------------------
step("99. a 120 yd de un vuelo que no conoces: un aviso con «Llévame», una vez", function()
  local Vc = Mu.VueloCerca
  check(Vc ~= nil, "no cargó VueloCerca.lua")
  local Ds = Mu.Descubrir
  local vuelos, zona = Ds.Vuelos, Ds.Zona
  local C = A.Compat
  local pos = C.GetPlayerWorldPosition
  local nodo = { id = 77, c = 1, wx = 1000, wy = 2000, name = "Puesto del Cruce, Los Baldíos" }
  Ds.Zona = function() return 1413 end
  Ds.Vuelos = function() return { { nodo = nodo, x = 0.52, y = 0.30 } } end
  local px = 1000 + 400
  C.GetPlayerWorldPosition = function() return 1, px, 2000 end
  Vc.Olvidar()
  limpiar()
  check(Vc.Revisar() == nil and avisoCon("mundo.vueloCerca") == nil, "avisó un vuelo a 400 yd")
  px = 1000 + 120
  Vc.Revisar()
  local o = avisoCon("mundo.vueloCerca")
  check(o ~= nil, "no avisó el vuelo a 120 yd")
  check(o and o.texto:find("120", 1, true), "no dice la distancia: " .. tostring(o and o.texto))
  check(o and o.acciones and o.acciones[1], "sin «Llévame»")
  limpiar()
  Vc.Revisar()
  check(avisoCon("mundo.vueloCerca") == nil, "repitió el aviso del mismo vuelo")
  -- Con la posición secreta, nada (ni truena).
  C.GetPlayerWorldPosition = function() return SECRETO(1), SECRETO(px), SECRETO(2000) end
  Vc.Olvidar()
  check(pcall(Vc.Revisar), "tronó con la posición secreta")
  Ds.Vuelos, Ds.Zona, C.GetPlayerWorldPosition = vuelos, zona, pos
end)

---------------------------------------------------------------------------
-- 100. Los botones seguros del Kit pasan "item" y "spell"
---------------------------------------------------------------------------
step("100. un seguro { type = \"item\" } llega con su objeto (la piedra de hogar)", function()
  local raiz = K.Raiz and K.Raiz() or UIParent
  local b = K.Boton(raiz, "Usar la piedra", function() end)
  b:SetSize(120, 26) b:SetPoint("CENTER") b:Show()
  K.Seguro(b, { type = "item", item = "item:6948" })
  FIRE(b, "OnEnter")
  local s = _G.AlfaKitSeguro
  check(s and s.dueno == b, "el seguro no cubrió el botón")
  check(s and s:GetAttribute("type") == "item" and s:GetAttribute("item") == "item:6948", "el seguro llegó sin su objeto: " .. tostring(s and s:GetAttribute("item")))
  FIRE(s, "OnLeave")
  K.Seguro(b, { type = "spell", spell = "Cocina" })
  FIRE(b, "OnEnter")
  check(s:GetAttribute("spell") == "Cocina", "el seguro llegó sin su hechizo")
  -- Otro seguro de macro no hereda el objeto de antes.
  FIRE(s, "OnLeave")
  K.Seguro(b, { type = "macro", macrotext = "/sit" })
  FIRE(b, "OnEnter")
  check(s:GetAttribute("item") == nil and s:GetAttribute("macrotext") == "/sit", "el seguro de macro se quedó con el objeto de antes")
  FIRE(s, "OnLeave")
  b:Hide()
end)

---------------------------------------------------------------------------
-- Una foto de los avisos (fondo nocturno del banco)
---------------------------------------------------------------------------
step("fotos: los avisos nuevos sin textos cortados", function()
  local DATOS = {
    { "¿Reiniciar la mazmorra?", "Si vas a repetir Minas de la Muerte, reiníciala: los enemigos y el botín vuelven. Esta hora llevas 3 de 5 instancias.", "ic-mazmorra", "Reiniciar" },
    { "Tienes algo por abrir", "Almeja gigante ×3. Ábrelo de un clic y libera espacio.", "ic-bolsas", "Abrir" },
    { "Un vuelo que no conoces", "A 120 yd está Puesto del Cruce. Háblale al maestro de vuelo para aprender el vuelo: luego te ahorra el camino.", "ic-flecha", "Llévame" },
    { "Saca lo de tus misiones", "Piel ligera ×6 para «Pieles para Eldrin». ", "ic-misiones", "Sacarlo" },
  }
  for k, d in ipairs(DATOS) do
    local a = avisoReal({ id = "diario.foto" .. k, titulo = d[1], texto = d[2], icono = d[3], tono = "acento", pedido = true, lya = false,
      duracion = 60, acciones = { { texto = d[4], alClic = function() end } } })
    check(type(a) == "table", "no salió el aviso «" .. d[1] .. "»")
    if type(a) == "table" then
      SNAP("aviso-" .. k, fondo(a), { a })
      if a.Cerrar then pcall(a.Cerrar, a) end
    end
  end
end)

K.Aviso = avisoReal
print("PRUEBA: 1.4.0 diario, " .. pasos .. " pasos, errores: " .. #ERRORS)
