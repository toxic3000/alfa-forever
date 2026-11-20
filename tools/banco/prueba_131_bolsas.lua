-- Prueba de la 1.3.1, Hoy y bolsas (tools/prueba.py la corre con las demás prueba_*.lua):
--   * Hoy: «Listo para la mazmorra» y «Comida y agua» cuentan con C_Item
--     (GetItemCount, GetItemSpell, GetItemInfo) y saben tus hechizos con
--     C_SpellBook.IsSpellKnown, sin los globales viejos (en Forever no están:
--     antes los fragmentos de alma y el polvo cegador contaban 0 y solo la
--     comida de la lista fija contaba); con el global, de respaldo, también;
--   * conjuntos: una pieza en su ranura gemela (anillos al revés) cuenta como
--     puesta, y lo que quedó debajo de otra pieza al cambiar de conjunto se
--     pone en la segunda pasada (PLAYER_EQUIPMENT_CHANGED), una vez y nunca en
--     combate;
--   * «Cierra misiones de esta zona» no se da por hecho en otra zona;
--   * «Olvidar» un personaje borra también sus recetas y su Encantamiento en
--     Comercio (la clave con espacios), y el diálogo lo dice;
--   * AlfaBolsas.Cuantos cuenta tus bolsas en una sola pasada (y se borra con
--     BAG_UPDATE, PLAYERBANKSLOTS_CHANGED y BANKFRAME_*);
--   * la lista de compras avisa (ALFA_COMERCIO) solo si cambió lo que está listo;
--   * vender, depositar y «Tomar todo» con el reloj de Alfa (N.Ticker), y los
--     avisos dicen lo que de verdad se movió («N no se movieron»).
-- Las funciones del juego que faltan (bolsas, equipo, objetos) son de mentira
-- y viven aquí.
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
local function check(cond, msg) if not cond then NOTE("1.3.1 hoy y bolsas", msg) end end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit

-- Cambia campos de una tabla mientras corre fn y los devuelve (también a nil).
local NADA = {}
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do
    antes[k] = { v = rawget(t, k) }
    rawset(t, k, v ~= NADA and v or nil)
  end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(t, k, a.v) end
  if not ok then error(e, 0) end
end

---------------------------------------------------------------------------
-- El juego de mentira
---------------------------------------------------------------------------

-- Los globales viejos no existen (como en Forever): solo C_Item.
GetItemCount, GetItemSpell, GetItemInfo, IsPlayerSpell, IsSpellKnown = nil, nil, nil, nil, nil

-- Objetos: id -> { nombre, ranura }
local OBJ = {
  [9101] = { "Anillo del lobo", "INVTYPE_FINGER" },
  [9105] = { "Anillo de la luna", "INVTYPE_FINGER" },
  [9106] = { "Anillo del aullido", "INVTYPE_FINGER" },
  [9107] = { "Colmillo de la manada", "INVTYPE_TRINKET" },
  [9108] = { "Ojo de la loba", "INVTYPE_TRINKET" },
  [9103] = { "Yelmo del alfa", "INVTYPE_HEAD" },
  [2589] = { "Lino", "" },
  [2592] = { "Lana", "" },
  [2318] = { "Cuero ligero", "" },
  [765] = { "Hojaplata", "" },
  [2447] = { "Flor de paz", "" },
  [4865] = { "Garra rota", "" },
}
local function idDe(x) return tonumber(tostring(x):match("item:(%d+)") or x) end
local function enlace(id)
  local o = OBJ[id]
  return "|cff1eff00|Hitem:" .. id .. "::::::::|h[" .. ((o and o[1]) or ("Objeto " .. id)) .. "]|h|r"
end

-- Lo que llevas encima (para C_Item.GetItemCount) y lo que dice el juego de cada objeto.
local cuenta = {}
local nombres = {}
local hechizoDe = {} -- id -> { nombre, spellID }
C_Item.GetItemCount = function(x) return cuenta[idDe(x)] or 0 end
C_Item.GetItemInfo = function(x)
  local id = idDe(x)
  local n = nombres[id] or (OBJ[id] and OBJ[id][1])
  if not n then return nil end
  return n, enlace(id), 2, 20, 1, "Tipo", "Subtipo", 1, OBJ[id] and OBJ[id][2] or "", 134400, 10, 4, 0, 0
end
C_Item.GetItemSpell = function(x)
  local h = hechizoDe[idDe(x)]
  if h then return h[1], h[2] end
  return nil
end
local nombreHechizo = { [433] = "Comida", [430] = "Bebida" }
C_Spell.GetSpellName = function(id) return nombreHechizo[id] end

-- Bolsas: la mochila (0, 16 casillas) y el banco base (6, 28).
local TAM = { [0] = 16, [6] = 28 }
local bolsas = { [0] = {}, [6] = {} }
local function poner(b, s, id, n, link, calidad)
  bolsas[b][s] = { itemID = id, stackCount = n or 1, quality = calidad or 2, hyperlink = link or enlace(id), isBound = true }
end
local function vaciar() bolsas[0], bolsas[6] = {}, {} end
local leidas = 0 -- cuántas veces se leyó una casilla (C_Container.GetContainerItemInfo)
local usados = {}
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
  UseContainerItem = function(b, s) usados[#usados + 1] = { b, s } if bolsas[b] then bolsas[b][s] = nil end end,
  GetContainerItemQuestInfo = function() return { isQuestItem = false } end,
  GetContainerItemLink = function(b, s) local i = bolsas[b] and bolsas[b][s] return i and i.hyperlink end,
  GetContainerItemID = function(b, s) local i = bolsas[b] and bolsas[b][s] return i and i.itemID end,
  ContainerIDToInventoryID = function(b) return b + 19 end,
  GetBagName = function() return nil end,
  GetContainerItemCooldown = function() return 0, 0, 0 end,
}
C_Container = C_Container or {}
for k, v in pairs(falso) do C_Container[k] = v end

-- Lo que llevas puesto: ranura -> { id, link }. EquipItemByName lo toma de la
-- mochila y deja lo que llevabas en esa casilla (como el juego).
local equipo = {}
local puestos = {}
GetInventoryItemID = function(u, r) local e = equipo[r] return e and e.id end
GetInventoryItemLink = function(u, r) local e = equipo[r] return e and e.link end
C_Item.EquipItemByName = function(link, slot)
  puestos[#puestos + 1] = { link, slot }
  local id = idDe(link)
  for s = 1, TAM[0] do
    local e = bolsas[0][s]
    if e and e.itemID == id then
      local viejo = equipo[slot]
      equipo[slot] = { id = id, link = e.hyperlink }
      if viejo then poner(0, s, viejo.id, 1, viejo.link) else bolsas[0][s] = nil end
      return
    end
  end
end
local function llevar(r, id) equipo[r] = id and { id = id, link = enlace(id) } or nil end

-- Los avisos y lo impreso se anotan en lugar de verse.
local avisos = {}
local avisoReal = K.Aviso
K.Aviso = function(o) avisos[#avisos + 1] = o return {} end
local impresos = {}
local imprimirReal = AlfaNucleo.Imprimir
AlfaNucleo.Imprimir = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  impresos[#impresos + 1] = table.concat(t, " ")
end
local function dijo(texto)
  for _, t in ipairs(impresos) do if t:find(texto, 1, true) then return true end end
  return false
end

if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(6)

local I = NS_OF("Alfa_Inicio")
local B = NS_OF("Alfa_Bolsas")
local Li, Co, R = I.Listo, I.Comida, I.Rec
local Cj = B.Conjuntos
local C = NS_OF("Alfa_Comercio")
local N = AlfaNucleo

---------------------------------------------------------------------------
-- 1. Hoy: Listo y Comida con C_Item y C_SpellBook
---------------------------------------------------------------------------

-- Un personaje de clase y nivel dados, con su libro de hechizos.
local function como(clase, nivel, sabidos, fn)
  con(_G, {
    UnitClass = function() return "X", clase, 1 end,
    UnitLevel = function() return nivel end,
    UnitPowerMax = function() return 0 end,
    C_SpellBook = { IsSpellKnown = function(id) return (sabidos or {})[id] == true end },
  }, function()
    con(R, { LeerDurabilidad = function() return {} end, Bolsas = function() return 12, 16 end }, fn)
  end)
end

local function componente(faltas, id)
  for _, c in ipairs(faltas) do if c.item == id then return c end end
  return nil
end

step("Listo: los fragmentos de alma y el polvo cegador se cuentan con C_Item", function()
  check(rawget(_G, "GetItemCount") == nil, "la escena tiene que correr sin el GetItemCount global")
  -- Un brujo con 10 fragmentos: no le falta nada de su clase.
  cuenta = { [6265] = 10 }
  como("WARLOCK", 30, {}, function()
    check(componente(Li.Componentes(), 6265) == nil, "al brujo con 10 fragmentos le pidió fragmentos de alma (contó 0)")
    for _, f in ipairs(Li.Faltas()) do
      check(f.clave ~= "componente", "con 10 fragmentos, Listo dice: " .. tostring(f.texto))
    end
  end)
  -- Con 1, sí, y dice cuántos lleva de verdad.
  cuenta = { [6265] = 1 }
  como("WARLOCK", 30, {}, function()
    local c = componente(Li.Componentes(), 6265)
    check(c and c.tienes == 1, "no dijo que el brujo lleva 1 fragmento: " .. tostring(c and c.tienes))
  end)
  -- El pícaro que sabe Esfumarse (C_SpellBook) y lleva 20 polvos: listo.
  cuenta = { [5140] = 20 }
  como("ROGUE", 30, { [1856] = true }, function()
    check(componente(Li.Componentes(), 5140) == nil, "al pícaro con 20 polvos le pidió polvo cegador")
  end)
  -- Con 2 polvos, se los pide, con el nombre que da C_Item.
  cuenta = { [5140] = 2 }
  nombres[5140] = "Polvo del juego"
  como("ROGUE", 30, { [1856] = true }, function()
    local c = componente(Li.Componentes(), 5140)
    check(c and c.tienes == 2, "con 2 polvos no los pidió bien: " .. tostring(c and c.tienes))
    local texto
    for _, f in ipairs(Li.Faltas()) do if f.clave == "componente" then texto = f.texto end end
    check(texto and texto:find("Polvo del juego: llevas 2 de 5", 1, true), "el nombre no salió de C_Item.GetItemInfo: " .. tostring(texto))
  end)
  nombres[5140] = nil
  -- Sin saber Esfumarse (C_SpellBook dice que no), no lo pide.
  cuenta = {}
  como("ROGUE", 30, {}, function()
    check(componente(Li.Componentes(), 5140) == nil, "pidió polvo cegador a un pícaro que no sabe Esfumarse")
  end)
  -- Con IsPlayerSpell también basta (habilidades sin libro).
  con(_G, { IsPlayerSpell = function(id) return id == 1856 end }, function()
    como("ROGUE", 30, {}, function()
      check(componente(Li.Componentes(), 5140) ~= nil, "con IsPlayerSpell diciendo que sí, no pidió el polvo")
    end)
  end)
  -- Sin C_Item.GetItemCount, el global de respaldo.
  con(C_Item, { GetItemCount = NADA }, function()
    con(_G, { GetItemCount = function(id) return id == 6265 and 7 or 0 end }, function()
      check(Li.Cuantos(6265) == 7, "sin C_Item no usó el GetItemCount de respaldo")
    end)
  end)
  cuenta = {}
end)

step("Comida: la de cocina y la de botín cuentan (C_Item.GetItemSpell)", function()
  vaciar()
  -- Brochetas de lobo (cocina, no están en la lista fija) y un jugo de botín.
  hechizoDe = { [2680] = { "Comida", 433 }, [90001] = { "Bebida", 430 } }
  poner(0, 1, 2680, 20)
  poner(0, 2, 90001, 5)
  poner(0, 3, 9101, 1) -- un anillo: ni comida ni bebida
  local comida, agua = Co.Contar()
  check(comida == 20, "no contó las 20 brochetas de cocina: " .. tostring(comida))
  check(agua == 5, "no contó los 5 jugos de botín: " .. tostring(agua))
  check(Co.Tipo(9101) == nil, "el anillo salió como comida o bebida")
  -- Con eso, Listo no pide comida.
  con(_G, { UnitClass = function() return "X", "WARRIOR", 1 end, UnitLevel = function() return 30 end, UnitPowerMax = function() return 0 end }, function()
    con(R, { LeerDurabilidad = function() return {} end, Bolsas = function() return 12, 16 end }, function()
      for _, f in ipairs(Li.Faltas()) do
        check(f.clave ~= "comida", "con 20 brochetas, Listo dice: " .. tostring(f.texto))
      end
    end)
  end)
  -- El nombre de lo que conviene comprar sale de C_Item.GetItemInfo.
  nombres[4542] = "Pan del juego"
  check(Co.Nombre(4542) == "Pan del juego", "el nombre no salió de C_Item.GetItemInfo: " .. tostring(Co.Nombre(4542)))
  nombres[4542] = nil
  check(Co.Nombre(4542) == "Pan de maíz húmedo", "sin nombre del juego no usó el suyo")
  vaciar()
  hechizoDe = {}
  Co.Reiniciar()
end)

---------------------------------------------------------------------------
-- 2. Conjuntos y las ranuras gemelas
---------------------------------------------------------------------------

step("Conjuntos: los anillos y abalorios al revés cuentan como puestos", function()
  vaciar()
  equipo, puestos = {}, {}
  llevar(1, 9103)
  llevar(11, 9101) llevar(12, 9105)
  llevar(13, 9107) llevar(14, 9108)
  check(Cj.Guardar("Anillos"), "no guardó el conjunto")
  -- Te los pones al revés.
  llevar(11, 9105) llevar(12, 9101)
  llevar(13, 9108) llevar(14, 9107)
  local puestas, enBolsas, faltan, total = Cj.Estado(Cj.Buscar("Anillos"))
  check(faltan == 0 and puestas == total and total == 5, string.format("al revés: %d puestas, %d en bolsas, %d faltan de %d", puestas, enBolsas, faltan, total))
  check(Cj.Puesto() == "Anillos", "los anillos al revés no salen como puestos")
  impresos, puestos = {}, {}
  Cj.Poner("Anillos")
  check(#puestos == 0, "movió piezas que ya llevabas al revés")
  check(dijo("Ya llevas puesto «Anillos»"), "no dijo que ya lo llevas: " .. tostring(impresos[1]))
  check(not dijo("Faltan"), "dijo que faltan piezas que llevas puestas")
  -- Dos anillos iguales: uno puesto no cuenta por los dos.
  llevar(11, 9101) llevar(12, 9101)
  Cj.Guardar("Gemelos")
  llevar(11, 9106) llevar(12, 9101)
  local p2, b2, f2, t2 = Cj.Estado(Cj.Buscar("Gemelos"))
  check(p2 == t2 - 1 and f2 == 1, "un solo anillo contó por los dos: " .. p2 .. "/" .. t2 .. ", faltan " .. f2)
  Cj.Olvidar("Gemelos")
  Cj.Olvidar("Anillos")
  equipo = {}
end)

-- Dos conjuntos con el mismo anillo en ranuras distintas: «Daño» lleva el
-- anillo del lobo en la 11; «Curación», en la 12 (y el del aullido en la 11).
local function dosConjuntos()
  vaciar()
  equipo, puestos = {}, {}
  llevar(11, 9106) llevar(12, 9101)
  poner(0, 1, 9105, 1)
  Cj.Guardar("Curación")
  -- Ahora «Daño»: el lobo en la 11 y la luna en la 12; el aullido a la mochila.
  equipo = {}
  vaciar()
  llevar(11, 9101) llevar(12, 9105)
  poner(0, 1, 9106, 1)
  Cj.Guardar("Daño")
end

step("Conjuntos: lo que quedó debajo de otra pieza se pone en la segunda pasada", function()
  dosConjuntos()
  local _, _, faltan = Cj.Estado(Cj.Buscar("Curación"))
  check(faltan == 0, "«Curación» dice que falta el anillo del lobo, que llevas puesto en la otra mano: faltan " .. faltan)
  impresos, puestos = {}, {}
  check(Cj.Poner("Curación") == true, "no se puso «Curación»")
  check(not dijo("Faltan"), "la primera pasada dijo que falta el anillo que llevabas: " .. tostring(impresos[1]))
  check(dijo("Te pusiste «Curación»: 2 piezas"), "no contó las dos piezas: " .. tostring(impresos[1]))
  check(Cj.SegundaPendiente(), "no quedó pendiente la segunda pasada")
  check(equipo[11] and equipo[11].id == 9106, "no se puso el anillo del aullido en la 11")
  -- El juego avisa que cambió tu equipo: el anillo del lobo, que cayó a la
  -- mochila, va a la 12.
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 11, false)
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 11, true)
  RUN_TIMERS(2)
  check(equipo[12] and equipo[12].id == 9101, "la segunda pasada no puso el anillo del lobo en la 12")
  check(Cj.Puesto() == "Curación", "después de la segunda pasada «Curación» no sale puesto")
  check(not Cj.SegundaPendiente() and not AlfaNucleo.HayTarea("bolsas.conjuntoSegunda"), "la segunda pasada quedó pendiente")
  -- Una sola vez: otro cambio de equipo no vuelve a mover nada.
  local n = #puestos
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 12, true)
  RUN_TIMERS(2)
  check(#puestos == n, "hubo una tercera pasada")
  -- Y de vuelta a «Daño», igual.
  Cj.Poner("Daño")
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 12, true)
  RUN_TIMERS(2)
  check(Cj.Puesto() == "Daño", "de vuelta, «Daño» no quedó puesto")
end)

step("Conjuntos: la segunda pasada nunca en combate y no espera para siempre", function()
  dosConjuntos()
  Cj.Poner("Curación")
  local n = #puestos
  local pelea = true
  con(_G, { InCombatLockdown = function() return pelea end }, function()
    FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 11, true)
    RUN_TIMERS(2)
    check(#puestos == n, "la segunda pasada cambió el equipo en combate")
    check(AlfaNucleo.HayTarea("bolsas.conjuntoSegunda"), "la segunda pasada no esperó al fin del combate")
    pelea = false
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    RUN_TIMERS(2)
  end)
  check(#puestos == n + 1 and equipo[12] and equipo[12].id == 9101, "al salir del combate no se puso el anillo del lobo")
  -- Si el juego no avisa a tiempo, ya no se pone sola.
  dosConjuntos()
  Cj.Poner("Curación")
  n = #puestos
  NOW = NOW + 10 -- el reloj del banco: diez segundos sin noticias del juego
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 11, true)
  RUN_TIMERS(2)
  check(#puestos == n, "la segunda pasada corrió mucho después del clic")
  Cj.Olvidar("Curación")
  Cj.Olvidar("Daño")
  equipo = {}
  vaciar()
end)

step("La página de Bolsas con los conjuntos", function()
  dosConjuntos()
  AlfaNucleo.Abrir("bolsas")
  RUN_TIMERS(3)
  AlfaNucleo.Abrir("inicio")
  RUN_TIMERS(3)
  Cj.Olvidar("Curación")
  Cj.Olvidar("Daño")
  equipo = {}
  vaciar()
end)

---------------------------------------------------------------------------
-- 3. «¿Cuánto tiempo tienes?»: el paso de tu zona, solo en tu zona
---------------------------------------------------------------------------

step("Tiempo: «Cierra misiones de esta zona» no se da por hecho en otra zona", function()
  local TM = I.Tiempo
  local llamadas = {}
  local RutaFalsa = {
    Listas = function() return 0 end,
    Liberar = function(f) llamadas[#llamadas + 1] = "liberar:" .. tostring(f) end,
    Recoger = function() llamadas[#llamadas + 1] = "recoger" end,
    Entregar = function() llamadas[#llamadas + 1] = "entregar" end,
  }
  local LOG = {
    { isHeader = true, title = "Durotar" }, { questID = 801, title = "Una" }, { questID = 802, title = "Otra" },
    { isHeader = true, title = "Los Baldíos" }, { questID = 803, title = "Lejos" },
  }
  local QL = setmetatable({ GetNumQuestLogEntries = function() return #LOG, #LOG end, GetInfo = function(i) return LOG[i] end }, { __index = C_QuestLog })
  local zona = "Durotar"
  con(_G, { AlfaRuta = RutaFalsa, C_QuestLog = QL, GetRealZoneText = function() return zona end, GetZoneText = function() return zona end }, function()
    TM.Dejar()
    local plan = TM.Armar(60)
    local p1 = plan.pasos[1]
    check(p1 and p1.tipo == "zona" and p1.zona == "Durotar", "el paso de tu zona no guardó su zona: " .. tostring(p1 and p1.tipo) .. " " .. tostring(p1 and p1.zona))
    check(TM.Empezar(plan), "no empezó el plan")
    check(TM.Actual().pasos[1].zona == "Durotar", "el plan guardado no lleva la zona del paso")
    -- Vas a Orgrimmar a entrenar: el paso sigue.
    avisos = {}
    zona = "Orgrimmar"
    FIRE_EVENT("QUEST_LOG_UPDATE")
    RUN_TIMERS(3)
    check(TM.Actual() and TM.Actual().i == 1, "en otra zona dio por hecho el paso de Durotar")
    for _, a in ipairs(avisos) do
      check(not tostring(a.titulo):find("Listo. Ahora", 1, true), "en otra zona avisó: " .. tostring(a.titulo))
    end
    check(TM.EnZona("Durotar") == 2, "desde otra zona no cuenta las 2 de Durotar: " .. TM.EnZona("Durotar"))
    -- De vuelta en Durotar y con sus misiones hechas: ahora sí, solo.
    zona = "Durotar"
    table.remove(LOG, 3) table.remove(LOG, 2)
    avisos = {}
    FIRE_EVENT("QUEST_LOG_UPDATE")
    RUN_TIMERS(3)
    check(TM.Actual() == nil or TM.Actual().i == 2, "en Durotar, sin misiones, no pasó al siguiente")
    local dijo = false
    for _, a in ipairs(avisos) do if tostring(a.titulo):find("Listo. Ahora", 1, true) then dijo = true end end
    check(dijo, "al cerrar las de Durotar no avisó lo que sigue")
    TM.Dejar()
  end)
end)

---------------------------------------------------------------------------
-- 4. «Olvidar» un personaje: también lo que sabe Comercio
---------------------------------------------------------------------------

local function buscarFila(f, clave, prof)
  if prof > 30 or type(f) ~= "table" or not f.GetChildren then return nil end
  for _, h in ipairs({ f:GetChildren() }) do
    if rawget(h, "clave") == clave and rawget(h, "Control") then return h end
    local x = buscarFila(h, clave, prof + 1)
    if x then return x end
  end
  return nil
end

step("Olvidar: las recetas y el Encantamiento de Comercio se van con el personaje", function()
  local D = B.Datos
  local cd = N.Datos("comercio")
  cd.recetas = type(cd.recetas) == "table" and cd.recetas or {}
  cd.encantar = type(cd.encantar) == "table" and cd.encantar or {}
  local rk = C.ClaveReino()
  local receta = function(quien) return { rk = rk, nombre = quien, profs = {}, r = { [3914] = { o = 2580, q = 1, n = "Paño de lino", p = "Sastrería", r = { 2589, 2 } } } } end
  -- Alt (mismo reino), Brisa (un reino con espacio) y Otro, que se queda.
  D.Raiz().personajes["Alt-Forever"] = { nombre = "Alt", reino = "Forever", bolsas = {}, banco = {}, equipo = {}, v = 1 }
  D.Raiz().personajes["Brisa-ReinoLobo"] = { nombre = "Brisa", reino = "Reino Lobo", bolsas = {}, banco = {}, equipo = {}, v = 1 }
  D.Raiz().personajes["Nube-ReinoLobo"] = { nombre = "Nube", bolsas = {}, banco = {}, equipo = {}, v = 1 } -- sin reino guardado
  cd.recetas["Alt-Forever"] = receta("Alt")
  cd.encantar["Alt-Forever"] = { rk = rk, s = 300, nombre = "Alt" }
  cd.recetas["Brisa-Reino Lobo"] = receta("Brisa")
  cd.recetas["Nube-Reino Lobo"] = receta("Nube")
  cd.recetas["Otro-Forever"] = receta("Otro")
  C.RecetasCambiaron()
  local function usan(quien)
    for _, e in ipairs(AlfaComercio.Usan(2589)) do if e.quien == quien then return true end end
    return false
  end
  check(usan("Alt") and usan("Otro"), "antes de olvidar, Comercio no sabe que Alt usa el lino")
  check(C.Encantador() and C.Encantador().nombre == "Alt", "antes de olvidar, Alt no es el encantador")
  -- El diálogo de la página lo dice; aceptar olvida.
  AlfaNucleo.Abrir("bolsas")
  RUN_TIMERS(3)
  local P = B.Pagina
  local fila = P and P.view and buscarFila(P.view, "Alt-Forever", 0)
  check(fila, "no encontré la fila de Alt en la página")
  local dialogo
  con(K, { Dialogo = function(o) dialogo = o return {} end }, function()
    local b = fila and fila.Control and fila.Control.Olvidar
    if b and b.alClic then b.alClic(b) end
  end)
  check(dialogo and tostring(dialogo.texto):find("sus recetas de Comercio", 1, true), "el diálogo no dice que se olvidan sus recetas: " .. tostring(dialogo and dialogo.texto))
  if dialogo and dialogo.alAceptar then dialogo.alAceptar() end
  check(D.Personaje("Alt-Forever") == nil, "no olvidó a Alt en Bolsas")
  check(cd.recetas["Alt-Forever"] == nil and cd.encantar["Alt-Forever"] == nil, "Comercio sigue guardando lo de Alt")
  check(not usan("Alt") and usan("Otro"), "«Qué guardar» sigue contando con las recetas de Alt")
  check(not (C.Encantador() and C.Encantador().nombre == "Alt"), "Alt sigue como encantador")
  -- La clave de Comercio con espacios, y sin el reino guardado en Bolsas.
  check(D.Olvidar("Brisa-ReinoLobo") and cd.recetas["Brisa-Reino Lobo"] == nil, "no olvidó las recetas de Brisa (reino con espacio)")
  check(D.Olvidar("Nube-ReinoLobo") and cd.recetas["Nube-Reino Lobo"] == nil, "sin reino guardado no olvidó las recetas de Nube")
  check(cd.recetas["Otro-Forever"] ~= nil, "olvidó de más")
  -- A ti no.
  local mia = cd.recetas[C.ClavePersonaje()]
  cd.recetas[C.ClavePersonaje()] = receta("Lobato")
  check(AlfaComercio.OlvidarPersonaje("Lobato", "Forever") == false and cd.recetas[C.ClavePersonaje()] ~= nil, "olvidó tus propias recetas")
  cd.recetas[C.ClavePersonaje()] = mia
  cd.recetas["Otro-Forever"] = nil
  C.RecetasCambiaron()
  RUN_TIMERS(2)
end)

---------------------------------------------------------------------------
-- 5. AlfaBolsas.Cuantos en una sola pasada
---------------------------------------------------------------------------

step("Cuantos: tus bolsas se cuentan una vez para muchos objetos", function()
  local D = B.Datos
  vaciar()
  poner(0, 1, 2589, 5) poner(0, 2, 2592, 3) poner(0, 3, 2318, 7) poner(0, 4, 765, 2) poner(0, 5, 2447, 4)
  FIRE_EVENT("BAG_UPDATE", 0)
  leidas = 0
  local ids = { 2589, 2592, 2318, 765, 2447 }
  local suma = 0
  for _, id in ipairs(ids) do suma = suma + AlfaBolsas.Cuantos(id) end
  check(suma == 21, "no contó lo que llevas: " .. suma)
  check(leidas <= TAM[0], "leyó " .. leidas .. " casillas para 5 objetos (una pasada son " .. TAM[0] .. ")")
  -- Cambia la mochila: BAG_UPDATE borra la cuenta.
  poner(0, 6, 2589, 10)
  FIRE_EVENT("BAG_UPDATE", 0)
  local total, enBolsas = AlfaBolsas.Cuantos(2589)
  check(enBolsas == 15, "después de BAG_UPDATE no contó el lino nuevo: " .. tostring(enBolsas))
  -- El banco abierto, en vivo; PLAYERBANKSLOTS_CHANGED y BANKFRAME_* lo borran.
  poner(6, 1, 2589, 4)
  FIRE_EVENT("BANKFRAME_OPENED")
  RUN_TIMERS(2)
  local _, _, banco = AlfaBolsas.Cuantos(2589)
  check(banco == 4, "con el banco abierto no contó el lino del banco: " .. tostring(banco))
  poner(6, 2, 2589, 2)
  FIRE_EVENT("PLAYERBANKSLOTS_CHANGED", 2)
  _, _, banco = AlfaBolsas.Cuantos(2589)
  check(banco == 6, "después de PLAYERBANKSLOTS_CHANGED no contó el lino nuevo del banco: " .. tostring(banco))
  RUN_TIMERS(2) -- la foto del banco (Datos.lua) antes de cerrarlo
  FIRE_EVENT("BANKFRAME_CLOSED")
  RUN_TIMERS(2)
  -- Con el banco cerrado, su foto; y lo de tus otros personajes.
  D.Raiz().personajes["Brisa-Forever"] = { nombre = "Brisa", reino = "Forever", v = 1, equipo = {},
    bolsas = { [0] = { n = 16, [1] = { i = 2589, c = 8 } } }, banco = {} }
  local todo, bolsasYa, bancoFoto, cuenta = AlfaBolsas.Cuantos(2589)
  check(bolsasYa == 15 and bancoFoto == 6 and todo == 21, "con el banco cerrado no usó su foto: " .. tostring(bancoFoto))
  check(cuenta == 29, "no sumó lo de Brisa: " .. tostring(cuenta))
  D.Raiz().personajes["Brisa-Forever"] = nil
  vaciar()
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(3)
end)

---------------------------------------------------------------------------
-- 6. La lista de compras avisa solo si cambió lo que está listo
---------------------------------------------------------------------------

step("Lista de compras: ALFA_COMERCIO solo cuando cambia lo que está listo", function()
  local Lc = C.Lista
  local avisa, avisaLista = 0, 0
  local contar = true
  A.On("ALFA_COMERCIO", function() if contar then avisa = avisa + 1 end end)
  A.On("ALFA_COMERCIO_LISTA", function() if contar then avisaLista = avisaLista + 1 end end)
  vaciar()
  Lc.Vaciar()
  Lc.Agregar(2589, 20) -- juntar 20 de lino
  RUN_TIMERS(3)
  avisa, avisaLista = 0, 0
  -- Juntas 3: aún no está listo; nada que avisar.
  poner(0, 1, 2589, 3)
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(3)
  check(avisa == 0 and avisaLista == 0, "con cada cambio de bolsas avisó (ALFA_COMERCIO " .. avisa .. ", ALFA_COMERCIO_LISTA " .. avisaLista .. ")")
  -- Juntas 20: ya está listo; ahora sí.
  poner(0, 2, 2589, 17)
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(3)
  check(avisa >= 1 and avisaLista >= 1, "al completar el lino no avisó")
  contar = false
  Lc.Vaciar()
  vaciar()
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(3)
end)

---------------------------------------------------------------------------
-- 7 y 8. Vender, depositar y el buzón con el reloj de Alfa, y lo que de verdad se movió
---------------------------------------------------------------------------

local tickersSueltos = 0
local nuevoTickerReal = C_Timer.NewTicker
local function contarTickers(fn)
  tickersSueltos = 0
  C_Timer.NewTicker = function(...) tickersSueltos = tickersSueltos + 1 return nuevoTickerReal(...) end
  local ok, e = pcall(fn)
  C_Timer.NewTicker = nuevoTickerReal
  if not ok then error(e, 0) end
end

step("Vender la chatarra: con N.Ticker, y el aviso dice lo vendido de verdad", function()
  local S = B.Sugerencias
  vaciar()
  for s = 1, 8 do poner(0, s, 4865, 2, nil, 0) end
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
  impresos, usados = {}, {}
  contarTickers(function() S.VenderChatarra() end)
  check(tickersSueltos == 0, "la venta usó un C_Timer.NewTicker suelto")
  check(N.HayTarea("bolsas.lote.vender"), "la venta no va con el reloj de Alfa (bolsas.lote.vender)")
  check(#usados == 6, "la primera vuelta no vendió 6: " .. #usados)
  -- El motor (o tú) vende una mientras tanto.
  bolsas[0][7] = nil
  RUN_TIMERS(4)
  check(not N.HayTarea("bolsas.lote.vender") and not B.Lotes.Activo("vender"), "la venta no terminó")
  check(#usados == 7, "no vendió las que quedaban: " .. #usados)
  local esperado = N.Dinero(7 * 2 * 10, true)
  check(dijo("Vendiste 7 objetos de chatarra por unos " .. esperado), "el aviso no dice lo vendido de verdad: " .. tostring(impresos[1]) .. " / " .. tostring(impresos[2]))
  check(dijo("1 no se movió"), "el aviso no dice la que no se vendió")
  FIRE_EVENT("MERCHANT_CLOSED")
  RUN_TIMERS(2)
  Q.Vendor = vendorReal
  A.Set("qol.sellJunk", nil)
  vaciar()
end)

step("Depositar: el aviso dice cuántas no se movieron", function()
  local Bc = B.Banco
  vaciar()
  poner(0, 1, 2589, 5) poner(0, 2, 2589, 5)
  poner(0, 3, 4865, 1) -- el plan pedía lino aquí, pero ya no está
  FIRE_EVENT("BANKFRAME_OPENED")
  RUN_TIMERS(2)
  impresos, usados = {}, {}
  contarTickers(function() Bc.Mandar({ lista = { { 0, 1, 2589 }, { 0, 2, 2589 }, { 0, 3, 2589 } }, noCaben = 0 }) end)
  RUN_TIMERS(3)
  check(#usados == 2, "no guardó el lino: " .. #usados)
  check(dijo("Guardaste 2 objetos en el banco."), "no dijo cuántos guardó: " .. tostring(impresos[1]))
  check(dijo("1 no se movió"), "no dijo la que no se movió")
  -- Nada movido: no dice «Guardaste 0».
  impresos = {}
  Bc.Mandar({ lista = { { 0, 3, 2589 } }, noCaben = 0 })
  RUN_TIMERS(2)
  check(not dijo("Guardaste 0"), "dijo «Guardaste 0 objetos»")
  check(dijo("1 no se movió"), "sin nada movido no dijo por qué")
  FIRE_EVENT("BANKFRAME_CLOSED")
  RUN_TIMERS(2)
  vaciar()
end)

step("Buzón: «Tomar todo» con N.Ticker", function()
  local Bz = C.Buzon
  local cartas = { { dinero = 500 } }
  local function quitar(i) if cartas[i] and (cartas[i].dinero or 0) <= 0 then table.remove(cartas, i) end end
  con(_G, {
    GetInboxNumItems = function() return #cartas, #cartas end,
    GetInboxHeaderInfo = function(i)
      local c = cartas[i]
      if not c then return nil end
      return nil, nil, "Subasta", "Venta", c.dinero, 0, 20, 0, false, false, false, false, false
    end,
    GetInboxItem = function() return nil end,
    HasInboxItem = function() return false end,
    TakeInboxMoney = function(i) if cartas[i] then cartas[i].dinero = 0 quitar(i) end end,
    TakeInboxItem = function() end,
    C_Mail = { IsCommandPending = function() return false end, SetOpeningAll = function() end, HasInboxMoney = function() return false end },
  }, function()
    FIRE_EVENT("MAIL_SHOW")
    FIRE_EVENT("MAIL_INBOX_UPDATE")
    RUN_TIMERS(2)
    contarTickers(function() Bz.Tomar() end)
    check(tickersSueltos == 0, "«Tomar todo» usó un C_Timer.NewTicker suelto")
    check(Bz.Tomando() and N.HayTarea("comercio.buzon"), "«Tomar todo» no va con el reloj de Alfa (comercio.buzon)")
    FIRE_EVENT("MAIL_INBOX_UPDATE")
    RUN_TIMERS(10)
    check(not Bz.Tomando() and not N.HayTarea("comercio.buzon"), "«Tomar todo» no terminó o su paso siguió corriendo")
    check(Bz.ultimo and Bz.ultimo.dinero == 500, "no contó el dinero de la carta: " .. tostring(Bz.ultimo and Bz.ultimo.dinero))
    FIRE_EVENT("MAIL_CLOSED")
    RUN_TIMERS(1)
  end)
end)

K.Aviso = avisoReal
AlfaNucleo.Imprimir = imprimirReal
print(string.format("PRUEBA: 1.3.1 Hoy y bolsas, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
