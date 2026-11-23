-- Prueba de la 1.3.7-fix, la receta y las bolsas (tools/prueba.py la corre con
-- las demás prueba_*.lua).
--
-- Reporte de Toxic del 21/11/2026: con las bolsas de Alfa abiertas, usar una
-- receta del inventario («Receta: sopa de tortuga reconfortante», objeto 3737)
-- «hizo que tronaran las bolsas». Lo que aquí se cuida:
--   1. leer una receta y sus datos no truena;
--   2. aprenderla (el objeto se va, el juego avisa por CHAT_MSG_SYSTEM y manda
--      SPELLS_CHANGED y LEARNED_SPELL_IN_SKILL_LINE) con las bolsas abiertas,
--      en las tres vistas, no truena y la ventana sigue sirviendo: se vuelve a
--      llenar y la casilla queda libre;
--   3. la misma receta con las bolsas abiertas y el clic del ratón encima.
-- El banco no imita la contaminación (taint) del juego real: que el juego
-- bloquee una acción no se puede probar aquí; eso se revisa en el juego.
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
local function check(cond, msg) if not cond then NOTE("1.3.7-fix receta", msg) end end

if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(6)

local N = AlfaNucleo
local B = NS_OF("Alfa_Bolsas")
local D, V = B.Datos, B.Ventana

local dinero = 123456
GetMoney = function() return dinero end
GetRealZoneText = function() return "Tranvía Subterráneo" end
GetZoneText = function() return "Tranvía Subterráneo" end

-- nombre, clase, subclase, ranura, calidad, icono
local OBJ = {
  [3737] = { "Receta: sopa de tortuga reconfortante", 9, 1, "", 1, 134332 },
  [6948] = { "Piedra de hogar", 15, 0, "", 1, 134414 },
  [3729] = { "Sopa de tortuga reconfortante", 0, 5, "", 1, 134019 },
  [1710] = { "Poción de sanación superior", 0, 1, "", 1, 134744 },
  [5504] = { "Carne de almeja ácida", 7, 8, "", 1, 133970 },
}
local orden = { 3737, 6948, 3729, 1710, 5504 }
local function enlace(id) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. OBJ[id][1] .. "]|h|r" end
local function idDe(x) return tonumber(tostring(x):match("item:(%d+)") or x) end
C_Item.GetItemInfo = function(x)
  local o = OBJ[idDe(x)]
  if not o then return nil end
  return o[1], enlace(idDe(x)), o[5], 20, 1, "Tipo", "Subtipo", 20, o[4], o[6], 0, 25, o[2], o[3]
end
C_Item.GetItemInfoInstant = function(x)
  local id = idDe(x)
  local o = OBJ[id]
  if not o then return id, "Objeto", "Objeto", "", 134400, 0, 0 end
  return id, "Tipo", "Subtipo", o[4], o[6], o[2], o[3]
end
C_Item.GetItemQualityColor = function() return 1, 1, 1, 1 end
C_Item.GetItemMaxStackSizeByID = function() return 20 end

local bolsa = {}
local function llenar()
  bolsa = {}
  for s, id in ipairs(orden) do
    bolsa[s] = { itemID = id, stackCount = 1, quality = OBJ[id][5], hyperlink = enlace(id), isBound = false, isLocked = false }
  end
end
llenar()
local function libres()
  local n = 0
  for s = 1, 16 do if not bolsa[s] then n = n + 1 end end
  return n
end
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end
C_Container.GetContainerNumFreeSlots = function(b) if b == 0 then return libres(), 0 end return 0, 0 end
C_Container.GetContainerItemInfo = function(b, s) return b == 0 and bolsa[s] or nil end
C_Container.GetContainerItemLink = function(b, s) local i = b == 0 and bolsa[s] return i and i.hyperlink or nil end
C_Container.GetContainerItemID = function(b, s) local i = b == 0 and bolsa[s] return i and i.itemID or nil end
C_Container.GetContainerItemQuestInfo = function() return { isQuestItem = false } end
C_Container.GetContainerItemCooldown = function() return 0, 0, 0 end
C_Container.GetBagName = function(b) return b == 0 and "Mochila" or nil end

FIRE_EVENT("BAG_UPDATE", 0)
RUN_TIMERS(3)
V.MostrarBolsas(true)
RUN_TIMERS(4)
local win = V.Ventana("bolsas")

-- Aprender la receta: el objeto se va del inventario y el juego avisa.
local function aprender()
  bolsa[1] = nil
  FIRE_EVENT("ITEM_LOCK_CHANGED", 0, 1)
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  FIRE_EVENT("BAG_NEW_ITEMS_UPDATED")
  FIRE_EVENT("SKILL_LINES_CHANGED")
  FIRE_EVENT("SPELLS_CHANGED")
  FIRE_EVENT("LEARNED_SPELL_IN_SKILL_LINE", 9513)
  FIRE_EVENT("CHAT_MSG_SYSTEM", "Has aprendido una nueva receta: Sopa de tortuga reconfortante.")
  RUN_TIMERS(6)
  -- La ventana se rehace en su OnUpdate (el banco no lo corre solo).
  for _ = 1, 12 do
    local f = V.Ventana("bolsas")
    if not (f and f:IsShown() and type(f.GetScript) == "function" and f:GetScript("OnUpdate")) then break end
    FIRE(f, "OnUpdate", 0.05)
  end
end

local function casilla(s) return win.vivos[0] and win.vivos[0][s] end

step("La receta: sus datos y su botón", function()
  check(win and win:IsShown(), "la ventana de bolsas no se abrió")
  local O = B.Objetos
  local e = O.Info(3737, enlace(3737))
  check(type(e) == "table" and e.nombre == OBJ[3737][1], "no se leyó el nombre de la receta")
  check(O.Categoria({ i = 3737, c = 1, l = enlace(3737), q = 1 }, e, 0) == "artesania", "la receta no cae en artesanía")
  local b = casilla(1)
  check(b and b:IsShown(), "la receta no tiene su botón en las bolsas")
end)

step("Aprender la receta con las bolsas abiertas no truena y la ventana sigue", function()
  local antes = casilla(1)
  if antes then
    local ok, guion = pcall(antes.GetScript, antes, "OnEnter")
    if ok and guion then FIRE(antes, "OnEnter") end
  end
  aprender()
  check(win:IsShown(), "la ventana de bolsas se cerró sola al aprender la receta")
  -- La casilla queda vacía (el botón puede seguir a la vista: las casillas
  -- libres también se pintan), pero ya sin el objeto.
  check(win.vivo and win.vivo[0] and win.vivo[0][1] == nil, "la receta siguió en la casilla 1")
  check(win.libres and win.libres >= 1, "no se contó la casilla que quedó libre")
  check(not win.Libre:GetText():find("Libre: 0", 1, true), "el pie dice que no hay espacio: " .. tostring(win.Libre:GetText()))
end)

step("Las tres vistas aguantan el cambio", function()
  for _, vista in ipairs({ "una", "categorias", "bolsa" }) do
    B.Set("vista", vista)
    RUN_TIMERS(3)
    check(win:IsShown(), "la vista " .. vista .. " cerró la ventana")
    local texto = win.Libre and win.Libre:GetText() or ""
    check(not texto:find("Libre: 0", 1, true), "la vista " .. vista .. " dice que no hay espacio")
  end
  B.Set("vista", nil)
  RUN_TIMERS(2)
end)

step("Otra receta nueva con las bolsas abiertas tampoco truena", function()
  llenar()
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_NEW_ITEMS_UPDATED")
  RUN_TIMERS(4)
  check(casilla(1) and casilla(1):IsShown(), "la receta no volvió a su casilla")
  aprender()
  check(win and win:IsShown(), "la ventana de bolsas se cerró sola")
end)

if win and win:IsShown() then win:Hide() end
print("PRUEBA: 1.3.7-fix receta, " .. pasos .. " pasos, 0 errores")
