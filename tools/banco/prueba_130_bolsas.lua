-- Prueba de la 1.3.0, Bolsas y Comercio:
--   * los fallos de la mochila (cada uno con su paso, antes del arreglo):
--     1. el carcaj y las bolsas especiales contaban como espacio libre;
--     2. «Todo lo que no sea equipo» se llevaba las flechas del carcaj y los
--        fragmentos de alma al banco;
--     3. lo bloqueado al depositar o vender gastaba sus reintentos en la misma
--        vuelta y se quedaba sin mover;
--     4. «Ponérmelo» pedido en combate volvía a ponerte lo que ya llevabas
--        (movía anillos y abalorios de ranura);
--     5. la búsqueda no encontraba el sufijo del enlace («Espada del mono»);
--     6. un objeto cuyo pedido el juego nunca contestó no se volvía a pedir;
--     7. PLAYERBANKSLOTS_CHANGED se leía como pestaña y el banco base no se
--        releía;
--     8. un motor sin Marks.Get dejaba vacía la sugerencia de qué vender;
--   * conjuntos de equipo, comparar con lo que llevas, buscar en todos tus
--     personajes, «Acomodar» y qué fabricar con lo que tienes (Comercio).
-- Las funciones del juego que faltan (bolsas, banco, equipo, objetos) son de
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
local function check(cond, msg) if not cond then NOTE("1.3.0 bolsas", msg) end end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit

---------------------------------------------------------------------------
-- El juego de mentira
---------------------------------------------------------------------------

-- Objetos: id -> { nombre, clase, subclase, ranura, calidad, venta }
local OBJ = {
  [2589] = { "Lino", 7, 5, "", 1, 13 },
  [2512] = { "Flecha tosca", 6, 2, "INVTYPE_AMMO", 1, 1 },
  [6265] = { "Fragmento de alma", 15, 0, "", 1, 0 },
  [4865] = { "Garra rota", 15, 0, "", 0, 5 },
  [9101] = { "Anillo del lobo", 4, 0, "INVTYPE_FINGER", 2, 100 },
  [9102] = { "Yelmo viejo", 4, 1, "INVTYPE_HEAD", 1, 50 },
  [9103] = { "Yelmo del alfa", 4, 1, "INVTYPE_HEAD", 2, 80 },
  [9104] = { "Caña de pescar", 2, 20, "INVTYPE_2HWEAPON", 1, 10 },
  [9200] = { "Espada del oso", 2, 7, "INVTYPE_WEAPON", 2, 200 },
  [1251] = { "Venda de lino", 0, 7, "", 1, 10 },
}
local function idDe(x) return tonumber(tostring(x):match("item:(%d+)") or x) end
local function enlace(id, nombre)
  local o = OBJ[id]
  return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. (nombre or (o and o[1]) or ("Objeto " .. id)) .. "]|h|r"
end
local sinRespuesta = {} -- ids que el juego "nunca" contesta
local pedidos = 0
C_Item.GetItemInfo = function(x)
  local id = idDe(x)
  local o = OBJ[id]
  if not o or sinRespuesta[id] then return nil end
  return o[1], enlace(id), o[5], 20, 1, "Tipo", "Subtipo", 20, o[4], 134400, o[6], o[2], o[3], 0
end
C_Item.GetItemInfoInstant = function(x)
  local id = idDe(x)
  local o = OBJ[id]
  if not o then return id, "Objeto", "Objeto", "", 134400, 0, 0 end
  return id, "Tipo", "Subtipo", o[4], 134400, o[2], o[3]
end
C_Item.RequestLoadItemDataByID = function() pedidos = pedidos + 1 end
C_Item.GetItemMaxStackSizeByID = function(id) local o = OBJ[id] return (o and (o[2] == 2 or o[2] == 4)) and 1 or 20 end
C_Item.GetDetailedItemLevelInfo = function() return nil end

-- Bolsas: 0 (mochila, 16), 1 (carcaj, 8, familia 1), 6 (banco base, 28).
local TAM = { [0] = 16, [1] = 8, [6] = 28 }
local FAM = { [1] = 1 }
local bolsas = { [0] = {}, [1] = {}, [6] = {} }
local function poner(b, s, id, n, extra)
  local e = { itemID = id, stackCount = n or 1, quality = (OBJ[id] and OBJ[id][5]) or 1, hyperlink = enlace(id), isBound = false }
  for k, v in pairs(extra or {}) do e[k] = v end
  bolsas[b][s] = e
  return e
end
local function vaciar() for b in pairs(bolsas) do bolsas[b] = {} end end
local usados = {}
local falso = {
  GetContainerNumSlots = function(b) return TAM[b] or 0 end,
  GetContainerNumFreeSlots = function(b)
    local t = bolsas[b]
    if not t then return 0, 0 end
    local n = 0
    for s = 1, TAM[b] do if not t[s] then n = n + 1 end end
    return n, FAM[b] or 0
  end,
  CalculateTotalNumberOfFreeBagSlots = function() return 10 end,
  GetContainerItemInfo = function(b, s) return bolsas[b] and bolsas[b][s] end,
  GetContainerItemQuestInfo = function() return { isQuestItem = false } end,
  GetContainerItemLink = function(b, s) local i = bolsas[b] and bolsas[b][s] return i and i.hyperlink end,
  GetContainerItemID = function(b, s) local i = bolsas[b] and bolsas[b][s] return i and i.itemID end,
  UseContainerItem = function(b, s) usados[#usados + 1] = { b, s } if bolsas[b] then bolsas[b][s] = nil end end,
  ContainerIDToInventoryID = function(b) return b + 19 end,
  GetBagName = function(b) if b == 1 then return "Carcaj ligero" end return nil end,
  GetContainerItemCooldown = function() return 0, 0, 0 end,
}
C_Container = C_Container or {}
for k, v in pairs(falso) do C_Container[k] = v end

-- Lo que llevas puesto: ranura -> { id, link }; EquipItemByName lo cambia.
local equipo = {}
local puestos = {}
GetInventoryItemID = function(u, r) local e = equipo[r] return e and e.id end
GetInventoryItemLink = function(u, r) local e = equipo[r] return e and e.link end
C_Item.EquipItemByName = function(link, slot)
  puestos[#puestos + 1] = { link, slot }
  local id = idDe(link)
  for _, b in ipairs({ 0, 1 }) do
    for s = 1, TAM[b] do
      local e = bolsas[b][s]
      if e and e.itemID == id then
        local viejo = equipo[slot]
        equipo[slot] = { id = id, link = e.hyperlink }
        bolsas[b][s] = viejo and poner(b, s, viejo.id, 1, { hyperlink = viejo.link }) or nil
        return
      end
    end
  end
end

-- Los marcos de mentira no traen SetID/GetID (los portas de la ventana los usan).
do
  local mt = getmetatable(CreateFrame("Frame"))
  local viejo = mt.__index
  local extra = {
    SetID = function(self, n) rawset(self, "_id", n) end,
    GetID = function(self) return rawget(self, "_id") or 0 end,
  }
  mt.__index = function(t, k)
    local v = viejo(t, k)
    if v == nil then v = extra[k] end
    return v
  end
end

-- Los avisos se anotan en lugar de verse.
local avisos = {}
local avisoReal = K.Aviso
K.Aviso = function(o) avisos[#avisos + 1] = o return {} end
local impresos = {}
local imprimirReal = AlfaNucleo.Imprimir
AlfaNucleo.Imprimir = function(...) impresos[#impresos + 1] = table.concat({ tostringall and tostringall(...) or tostring((...)) }, " ") if imprimirReal then imprimirReal(...) end end

if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local B = NS_OF("Alfa_Bolsas")
local C = NS_OF("Alfa_Comercio")
local D, V, O, S, Bc, Lo, Mj = B.Datos, B.Ventana, B.Objetos, B.Sugerencias, B.Banco, B.Lotes, B.Mejora
local Cj, Co, Bt, Ac = B.Conjuntos, B.Comparar, B.Todos, B.Acomodar

local function bolsasCambian()
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE", 1)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(4)
end

-- Las ventanas trabajan en su OnUpdate: aquí se les da cuerda.
local function bombear(f)
  for _ = 1, 60 do
    local fn = f:GetScript("OnUpdate")
    if not fn then break end
    fn(f, 0.02)
  end
end

---------------------------------------------------------------------------
-- Los fallos de la mochila
---------------------------------------------------------------------------

step("Fallo 1: el carcaj no cuenta como espacio libre", function()
  vaciar()
  for s = 1, 16 do poner(0, s, 2589, 1) end      -- la mochila, llena
  poner(1, 1, 2512, 200)                           -- el carcaj, casi vacío
  local t = D.Escanear(1)
  check(t.f == 1, "la foto del carcaj no guarda su familia: " .. tostring(t.f))
  check(D.Escanear(0).f == nil, "la mochila guardó una familia")
  V.MostrarBolsas(true)
  local f = V.Ventana("bolsas")
  bombear(f)
  check(f.libres == 0, "el pie cuenta el carcaj como espacio libre: " .. tostring(f.libres))
  check(f.totalE == 8 and f.libresE == 7, "el carcaj no va aparte: " .. tostring(f.libresE) .. "/" .. tostring(f.totalE))
  check(S.Espacio() == 0, "Sugerencias cuenta el carcaj")
  V.MostrarBolsas(false)
end)

step("Fallo 2: depositar no se lleva flechas ni fragmentos de alma", function()
  vaciar()
  poner(0, 1, 2589, 5)    -- lino: sí
  poner(0, 2, 2512, 200)  -- flechas sueltas: no
  poner(0, 3, 6265, 1)    -- fragmento de alma: no
  poner(1, 1, 2512, 200)  -- flechas del carcaj: no
  FIRE_EVENT("BANKFRAME_OPENED")
  RUN_TIMERS(2)
  local plan = Bc.Plan("noEquipo")
  check(#plan.lista == 1 and plan.lista[1][3] == 2589, "«Todo lo que no sea equipo» se lleva munición: " .. #plan.lista)
  local cuentas, cats = Bc.Cuentas()
  check(cuentas.noEquipo == 1, "el menú cuenta la munición: " .. tostring(cuentas.noEquipo))
  for _, c in ipairs(cats) do check(c.clave ~= "otros" or c.n == 0, "la categoría Otros trae munición") end
  FIRE_EVENT("BANKFRAME_CLOSED")
  RUN_TIMERS(2)
end)

step("Fallo 3: lo bloqueado espera a la siguiente vuelta", function()
  vaciar()
  local e = poner(0, 4, 2589, 5, { isLocked = true })
  local movidos = {}
  local ok = Lo.Iniciar({ nombre = "prueba", lista = { { 0, 4, 2589 } },
    mover = function(b, s) movidos[#movidos + 1] = { b, s } end })
  check(ok, "la tanda no empezó")
  check(#movidos == 0, "movió algo bloqueado")
  e.isLocked = false -- el juego lo suelta
  RUN_TIMERS(3)
  check(#movidos == 1, "lo bloqueado se quedó sin mover (gastó sus reintentos en la misma vuelta)")
  check(not Lo.Activo("prueba"), "la tanda no terminó")
end)

step("Fallo 4: «Ponérmelo» en combate no te vuelve a poner lo que ya llevas", function()
  vaciar()
  equipo, puestos = {}, {}
  local combate = InCombatLockdown
  InCombatLockdown = function() return true end
  local r = Mj.Poner({ id = 9101, link = enlace(9101), slot = 12 })
  check(r == "espera", "no esperó al fin del combate")
  equipo[12] = { id = 9101, link = enlace(9101) } -- te lo pusiste tú
  InCombatLockdown = combate
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  RUN_TIMERS(2)
  check(#puestos == 0, "volvió a poner el anillo que ya llevabas")
  equipo = {}
end)

step("Fallo 5: la búsqueda encuentra el sufijo del enlace", function()
  local link = enlace(9200, "Espada del mono")
  local e = O.Info(9200, enlace(9200))
  check(e.nombre == "Espada del oso", "la caché por objeto no tiene el nombre esperado")
  local ent = { rec = { i = 9200, l = link, q = 2 }, e = e, cat = "equipo" }
  check(O.Coincide(O.Compilar("mono"), ent), "«mono» no encuentra la «Espada del mono»")
  check(not O.Coincide(O.Compilar("tigre"), ent), "encontró lo que no es")
end)

step("Fallo 6: un objeto sin respuesta se vuelve a pedir", function()
  sinRespuesta[7777] = true
  OBJ[7777] = { "Objeto lento", 15, 0, "", 1, 1 }
  local antes = pedidos
  O.Info(7777)
  O.Info(7777)
  check(pedidos == antes + 1, "pidió dos veces seguidas: " .. (pedidos - antes))
  NOW = NOW + 11
  O.Info(7777)
  check(pedidos == antes + 2, "no lo volvió a pedir pasado un rato")
  sinRespuesta[7777] = nil
end)

step("Fallo 7: un cambio en el banco base se relee", function()
  vaciar()
  FIRE_EVENT("BANKFRAME_OPENED")
  RUN_TIMERS(3)
  poner(6, 3, 2589, 7)
  FIRE_EVENT("PLAYERBANKSLOTS_CHANGED", 3)
  RUN_TIMERS(3)
  local r = D.Actual()
  local t = r and r.banco and r.banco[6]
  check(t and t[3] and t[3].i == 2589 and t[3].c == 7, "el banco base no se releyó con PLAYERBANKSLOTS_CHANGED(3)")
  local lista = D.CambioBanco(3)
  check(lista and lista[1] == 6, "D.CambioBanco no marca el banco base")
  FIRE_EVENT("BANKFRAME_CLOSED")
  RUN_TIMERS(2)
  vaciar()
end)

step("Fallo 8: un motor sin Marks.Get no deja vacía la sugerencia", function()
  vaciar()
  poner(0, 1, 4865, 3, { quality = 0 }) -- garra rota, gris
  local Q = A.QoL or {}
  A.QoL = Q
  local real = Q.Marks
  Q.Marks = { Junk = function() return false end, Set = function() end }
  S.Invalidar()
  local est = S.Estado()
  check(#est.vender == 1 and est.vender[1].id == 4865, "sin Marks.Get no sugiere vender la chatarra")
  Q.Marks = real
  S.Invalidar()
  vaciar()
end)

---------------------------------------------------------------------------
-- 31. Conjuntos de equipo
---------------------------------------------------------------------------

step("Conjuntos: guardar, ponerse con un clic y en combate al terminar", function()
  check(A.Get("bolsas.conjuntos") == true, "bolsas.conjuntos no viene prendido")
  vaciar()
  equipo, puestos = {}, {}
  equipo[1] = { id = 9103, link = enlace(9103) }
  equipo[11] = { id = 9101, link = enlace(9101) }
  check(Cj.Guardar("Daño"), "no guardó el conjunto")
  check(#Cj.Lista() == 1 and Cj.Puesto() == "Daño", "el conjunto recién guardado no sale puesto")
  -- Te cambias: el yelmo viejo puesto y el bueno en la mochila.
  equipo[1] = { id = 9102, link = enlace(9102) }
  poner(0, 5, 9103, 1)
  local puestas, enBolsas, faltan, total = Cj.Estado(Cj.Buscar("Daño"))
  check(puestas == 1 and enBolsas == 1 and faltan == 0 and total == 2, "el estado del conjunto no cuadra")
  check(Cj.Poner("daño") == true, "no lo encontró sin acentos ni mayúsculas")
  check(#puestos == 1 and puestos[1][2] == 1 and idDe(puestos[1][1]) == 9103, "no se puso el yelmo en su ranura")
  check(equipo[1].id == 9103 and Cj.Puesto() == "Daño", "no quedó puesto")
  -- Pesca, en combate: espera.
  equipo[16] = nil
  poner(0, 6, 9104, 1)
  equipo[16] = { id = 9104, link = enlace(9104) }
  bolsas[0][6] = nil
  check(Cj.Guardar("Pesca"), "no guardó Pesca")
  equipo[16] = nil
  poner(0, 6, 9104, 1)
  puestos = {}
  local combate = InCombatLockdown
  InCombatLockdown = function() return true end
  check(Cj.Poner("Pesca") == "espera", "no esperó al fin del combate")
  check(#puestos == 0, "cambió el equipo en combate")
  InCombatLockdown = combate
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  RUN_TIMERS(2)
  check(#puestos == 1 and puestos[1][2] == 16, "no se puso la caña al terminar el combate")
  -- Lo que no está en tus bolsas se dice.
  equipo[16] = nil
  bolsas[0][6] = nil
  impresos = {}
  Cj.Poner("Pesca")
  local dice = false
  for _, t in ipairs(impresos) do if t:find("Faltan 1", 1, true) then dice = true end end
  check(dice, "no dijo que falta la caña")
  -- Reemplazar y olvidar.
  check(Cj.Guardar("Daño") and #Cj.Lista() == 2, "reemplazar duplicó el conjunto")
  check(Cj.Olvidar("Pesca") and #Cj.Lista() == 1, "no olvidó Pesca")
  -- El menú de la ventana de bolsas.
  V.MostrarBolsas(true)
  local f = V.Ventana("bolsas")
  bombear(f)
  check(f.Conjuntos and f.Conjuntos:IsShown(), "falta el botón de conjuntos en tus bolsas")
  Cj.Menu(f.Conjuntos)
  K.CerrarMenu()
  V.MostrarBolsas(false)
  -- Apagado: nada.
  A.Set("bolsas.conjuntos", false)
  check(Cj.Poner("Daño") == false, "se puso con el ajuste apagado")
  A.Set("bolsas.conjuntos", true)
  equipo = {}
end)

---------------------------------------------------------------------------
-- 32. Comparar con lo que llevas
---------------------------------------------------------------------------

step("Comparar: +/- contra lo que llevas, en el cuadro", function()
  check(A.Get("bolsas.comparar") == true, "bolsas.comparar no viene prendido")
  local G = A.Gear or {}
  A.Gear = G
  local real = { IsEnabled = G.IsEnabled, CompareToEquipped = G.CompareToEquipped, GetItemInfo = G.GetItemInfo, GetWeights = G.GetWeights }
  local STATS = { [9103] = { str = 10, sta = 2, armor = 40 }, [9102] = { str = 5, sta = 5, armor = 40 } }
  G.IsEnabled = function() return true end
  G.CompareToEquipped = function(link)
    local id = idDe(link)
    if id == 9103 then return { slot = 1, usable = true, pct = 12, delta = 3 } end
    if id == 9102 then return { slot = 1, usable = true, equipped = true } end
    return nil
  end
  G.GetItemInfo = function(link) local id = idDe(link) return STATS[id] and { id = id, inv = 1, stats = STATS[id] } or nil end
  G.GetWeights = function() return { str = 1, sta = 0.5 } end
  equipo[1] = { id = 9102, link = enlace(9102) }
  local dif = Co.Diferencias(enlace(9103))
  check(dif and #dif == 2, "las diferencias no son 2 (la armadura igual no cuenta): " .. tostring(dif and #dif))
  check(dif and dif[1].clave == "str" and dif[1].delta == 5, "lo que más pesa no va primero")
  local linea = Co.Linea(enlace(9103)) or ""
  check(linea:find("+5 Fuerza", 1, true) and linea:find("\226\136\1463 Aguante", 1, true), "la línea no dice +5 Fuerza y −3 Aguante: " .. linea)
  check(Co.Linea(enlace(9102)) == nil, "comparó la pieza que ya llevas")
  equipo[1] = nil
  local vacia = Co.Linea(enlace(9103)) or ""
  check(vacia == "", "con la ranura vacía y sin «empty» no debía decir nada")
  G.CompareToEquipped = function() return { slot = 1, usable = true, empty = true } end
  vacia = Co.Linea(enlace(9103)) or ""
  check(vacia:find("Ranura vacía", 1, true) and vacia:find("+10 Fuerza", 1, true), "la ranura vacía no suma todo: " .. vacia)
  A.Set("bolsas.comparar", false)
  check(Co.Linea(enlace(9103)) == nil, "comparó con el ajuste apagado")
  A.Set("bolsas.comparar", true)
  for k, v in pairs(real) do G[k] = v end
end)

---------------------------------------------------------------------------
-- 34. Buscar en todos tus personajes
---------------------------------------------------------------------------

step("Buscar en todos: bolsas, bancos y equipo con filtros", function()
  check(A.Get("bolsas.buscarTodos") == true, "bolsas.buscarTodos no viene prendido")
  vaciar()
  poner(0, 1, 2589, 3)
  bolsasCambian()
  D.Actual().banco = {}
  D.Actual().v = (D.Actual().v or 0) + 1
  D.Raiz().personajes["Brisa-Forever"] = { nombre = "Brisa", reino = "Forever", clase = "MAGE", nivel = 12, v = 1,
    bolsas = { [0] = { n = 16, [1] = { i = 2589, c = 5, l = enlace(2589), q = 1 }, [2] = { i = 9200, c = 1, l = enlace(9200, "Espada del mono"), q = 2 } } },
    banco = { [6] = { n = 28, [1] = { i = 2589, c = 7, l = enlace(2589), q = 1 } } },
    equipo = { [1] = { i = 9103, l = enlace(9103), q = 2 } } }
  local res, n = Bt.Buscar("lino")
  check(n == 1 and res[1].total == 15, "el lino de todos no suma 15: " .. tostring(res[1] and res[1].total))
  local texto = res[1] and Bt.Texto(res[1]) or ""
  check(texto:find("Brisa: 5 en bolsas y 7 en banco", 1, true) and texto:find("Lobato: 3 en bolsas", 1, true), "el texto no dice quién lo tiene: " .. texto)
  res, n = Bt.Buscar("lino", { clave = "Brisa-Forever" })
  check(n == 1 and res[1].total == 12, "el filtro de personaje no funciona")
  res, n = Bt.Buscar("", { calidad = 2 })
  check(n == 2, "el filtro de calidad no da la espada y el yelmo: " .. n)
  res, n = Bt.Buscar("mono")
  check(n == 1 and res[1].id == 9200, "no encontró el sufijo en otro personaje")
  res, n = Bt.Buscar("", { tipo = "artesania" })
  check(n == 1 and res[1].id == 2589, "el filtro de tipo no da el lino")
  res, n = Bt.Buscar("")
  check(n == 0, "sin búsqueda ni filtros no debe listar nada")
  -- La página con la búsqueda escrita.
  AlfaNucleo.Abrir("bolsas")
  RUN_TIMERS(3)
  D.Raiz().personajes["Brisa-Forever"] = nil
end)

---------------------------------------------------------------------------
-- 35. Acomodar
---------------------------------------------------------------------------

step("Acomodar: chatarra con el comerciante, materiales con el banquero", function()
  check(A.Get("bolsas.acomodar") == true, "bolsas.acomodar no viene prendido")
  vaciar()
  poner(0, 1, 4865, 3, { quality = 0 })
  poner(0, 2, 2589, 10)
  local Q = A.QoL or {}
  A.QoL = Q
  local vendorReal = Q.Vendor
  Q.Vendor = { JunkAt = function(b, s)
    local e = bolsas[b] and bolsas[b][s]
    if e and e.quality == 0 then return e.itemID, e.stackCount, 5 end
    return nil
  end }
  A.Set("qol.sellJunk", false) -- que el motor no la venda solo al abrir
  check(Ac.Que() == nil, "sin comerciante ni banco hay algo que acomodar")
  check(Ac.Hacer() == false, "acomodó lejos de todo")
  FIRE_EVENT("MERCHANT_SHOW")
  RUN_TIMERS(2)
  local que, n = Ac.Que()
  check(que == "vender" and n == 1, "con el comerciante no ofrece vender: " .. tostring(que))
  V.MostrarBolsas(true)
  local f = V.Ventana("bolsas")
  bombear(f)
  check(f.Acomodar and f.Acomodar:IsShown(), "no sale «Acomodar» en tus bolsas con el comerciante")
  usados = {}
  check(Ac.Hacer(), "Acomodar no vendió")
  RUN_TIMERS(3)
  check(#usados == 1 and usados[1][1] == 0 and usados[1][2] == 1, "no vendió la garra rota")
  FIRE_EVENT("MERCHANT_CLOSED")
  RUN_TIMERS(2)
  FIRE_EVENT("BANKFRAME_OPENED")
  RUN_TIMERS(2)
  que, n = Ac.Que()
  check(que == "banco" and n == 1, "con el banquero no ofrece guardar los materiales: " .. tostring(que))
  usados = {}
  check(Ac.Hacer(), "Acomodar no depositó")
  RUN_TIMERS(3)
  check(#usados == 1 and usados[1][2] == 2, "no guardó el lino")
  A.Set("bolsas.acomodar", false)
  poner(0, 2, 2589, 10)
  check(Ac.Que() == nil, "acomoda con el ajuste apagado")
  bombear(f)
  check(not f.Acomodar:IsShown(), "el botón sigue con el ajuste apagado")
  A.Set("bolsas.acomodar", true)
  FIRE_EVENT("BANKFRAME_CLOSED")
  RUN_TIMERS(2)
  V.MostrarBolsas(false)
  Q.Vendor = vendorReal
  A.Set("qol.sellJunk", nil)
  vaciar()
end)

---------------------------------------------------------------------------
-- 33. Qué fabricar con lo que tienes (Comercio)
---------------------------------------------------------------------------

step("Fabricar: lo que más deja y cuántas puedes hacer ya", function()
  check(A.Get("comercio.fabricar") == true, "comercio.fabricar no viene prendido")
  vaciar()
  poner(0, 1, 2589, 10) -- lino para 5 vendas
  local d = C.Datos()
  d.recetas = d.recetas or {}
  d.recetas[C.ClavePersonaje()] = { rk = C.ClaveReino(), nombre = "Lobato", profs = {},
    r = { [3275] = { n = "Venda de lino", o = 1251, q = 1, r = { 2589, 2 }, p = "Primeros auxilios" },
          [3276] = { n = "Venda cara", o = 9103, q = 1, r = { 9102, 1 }, p = "Primeros auxilios" } } }
  C.RecetasCambiaron()
  local r = C.Reino()
  r.p[1251] = { 500, time(), 1, 1 }
  r.p[2589] = { 100, time(), 1, 1 }
  r.p[9103] = { 2000, time(), 1, 1 }
  r.p[9102] = { 100, time(), 1, 1 }
  local lista = C.Fabricar()
  check(#lista == 2, "no salen las 2 recetas con ganancia: " .. #lista)
  local x = lista[1]
  check(x and x.e.rec.o == 1251 and x.veces == 5, "la que puedes hacer ya no va primero: " .. tostring(x and x.e.rec.n))
  check(x and x.total == x.gana * 5, "el total no es 5 veces la ganancia")
  check(lista[2] and lista[2].veces == 0 and lista[2].gana > x.gana, "la otra receta no deja más por vez")
  A.Set("comercio.fabricar", false)
  lista = C.Fabricar()
  check(lista[1].e.rec.o == 9103, "con el ajuste apagado no ordena solo por ganancia")
  A.Set("comercio.fabricar", true)
  check(type(AlfaComercio.Fabricar) == "function" and #AlfaComercio.Fabricar() == 2, "falta AlfaComercio.Fabricar")
  AlfaNucleo.Abrir("comercio")
  RUN_TIMERS(3)
  d.recetas[C.ClavePersonaje()] = nil
  C.RecetasCambiaron()
  vaciar()
end)

step("Las páginas de Bolsas y Comercio con todo", function()
  equipo[1] = { id = 9103, link = enlace(9103) }
  Cj.Guardar("Curación")
  AlfaNucleo.Abrir("bolsas")
  RUN_TIMERS(3)
  AlfaNucleo.Abrir("comercio")
  RUN_TIMERS(3)
  Cj.Olvidar("Curación")
  Cj.Olvidar("Daño")
  equipo = {}
end)

K.Aviso = avisoReal
AlfaNucleo.Imprimir = imprimirReal
print(string.format("PRUEBA: 1.3.0 bolsas y comercio, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
