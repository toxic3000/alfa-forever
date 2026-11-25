-- Prueba de la 1.4.0, Bolsas (tools/prueba.py la corre con las demás):
--   1/17. [BUG] Tras «Restablecer» los números de las casillas salían gigantes
--        y encimados. El banco imita a Forever (mock.lua, _lay): un texto se
--        acomoda con su letra y la pantalla de ese momento (BANCO_GEN_LETRA)
--        solo cuando su texto cambia. Por cada camino (Restablecer página de
--        Bolsas, Restablecer Estilo y sonido, un perfil o respaldo, reinicio de
--        gráficos, cambio de resolución o de escala, Dos pantallas y volver,
--        cerrar y abrir) se mide cada texto de casilla (montón, nivel de objeto,
--        recarga) y de la barra: acomodado con la letra y la pantalla de ahora,
--        su letra entre el 20 y el 36 % de la casilla, sin salirse y sin
--        encimarse.
--   19. «Ordenar» con vista previa al pasar el ratón (nada se mueve).
--   20. La tarjeta de «bolsas llenas» compacta: una línea con «Ver».
--   21. Las secciones plegadas, por personaje.
--   22. Arrastrar un objeto a una sección lo cambia de sección.
--   23. El espacio libre por tipo de bolsa (carcaj).
--   24. Comparar con lo que llevas: «Mejor que lo que llevas:» en una línea.
--   62. La escala de las ventanas de Alfa no se pierde al restablecer.
SNAPSHOTS = {}
BANCO_LETRA = 0.64
BANCO_GEN_LETRA = 0
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["140-bolsas-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.4.0 bolsas", msg) end end
local function bombear(w)
  for _ = 1, 80 do
    local fn = w and w:GetScript("OnUpdate")
    if not fn then break end
    fn(w, 0.02)
  end
end
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
  RUN_TIMERS(1)
end

local impresos = {}
AlfaNucleo.Imprimir = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  impresos[#impresos + 1] = table.concat(t, " ")
end

---------------------------------------------------------------------------
-- El juego de mentira: la mochila (16) y un carcaj (bolsa 1, 6 casillas)
---------------------------------------------------------------------------
local OBJ = {
  [6948] = { "Piedra de hogar", 1, 1, 0, 15, 0, "" },
  [2589] = { "Lino", 1, 20, 2, 7, 5, "" },
  [4865] = { "Garra rota", 0, 1, 5, 15, 0, "" },
  [9300] = { "Hoja de la luna", 4, 1, 900, 2, 7, "INVTYPE_WEAPON" },
  [9301] = { "Espada del oso", 2, 1, 120, 2, 7, "INVTYPE_WEAPON" },
  [118] = { "Poción de sanación menor", 1, 5, 1, 0, 1, "" },
  [9103] = { "Gorro", 1, 1, 10, 4, 1, "INVTYPE_HEAD" },
  [2512] = { "Flecha tosca", 1, 200, 0, 6, 2, "INVTYPE_AMMO" },
}
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
C_Item.GetDetailedItemLevelInfo = function(x)
  local id = idDe(x)
  local o = id and OBJ[id]
  if o and (o[5] == 2 or o[5] == 4) then return 20 + id % 9 end
  return nil
end
local puesto = { [16] = enlace(9301), [1] = enlace(9103) }
GetInventoryItemLink = function(_, r) return puesto[r] end
GetInventoryItemID = function(_, r) local l = puesto[r] return l and idDe(l) end

local bolsa, carcaj = {}, {}
local function cosa(id, n) return { itemID = id, stackCount = n or 1, quality = OBJ[id][2], hyperlink = enlace(id), isLocked = false } end
local function llenar()
  bolsa = {
    [1] = cosa(4865), [2] = cosa(2589, 5), [3] = cosa(9300), [4] = cosa(118, 3),
    [5] = cosa(6948), [6] = cosa(2589, 7), [7] = cosa(9301), [8] = cosa(118, 2),
    [9] = cosa(9103),
  }
  carcaj = { [1] = cosa(2512, 200), [2] = cosa(2512, 120) }
end
llenar()
local function de(b) return b == 0 and bolsa or b == 1 and carcaj or nil end
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 16 or b == 1 and 6 or 0 end
C_Container.GetContainerNumFreeSlots = function(b)
  local t, n = de(b), b == 0 and 16 or b == 1 and 6 or 0
  if not t then return 0, 0 end
  local libres = 0
  for s = 1, n do if not t[s] then libres = libres + 1 end end
  return libres, b == 1 and 1 or 0
end
C_Container.GetContainerItemInfo = function(b, s) local t = de(b) return t and t[s] or nil end
C_Container.GetContainerItemLink = function(b, s) local t = de(b) local i = t and t[s] return i and i.hyperlink or nil end
C_Container.GetContainerItemID = function(b, s) local t = de(b) local i = t and t[s] return i and i.itemID or nil end
C_Container.GetContainerItemQuestInfo = function() return { isQuestItem = false } end
C_Container.GetContainerItemCooldown = function(b, s)
  local t = de(b)
  local i = t and t[s]
  if i and i.itemID == 6948 then return GetTime() - 300, 3600, 1 end
  return 0, 0, 0
end
local movidos = 0
C_Container.PickupContainerItem = function() movidos = movidos + 1 end
local cursor
GetCursorInfo = function() if cursor then return "item", cursor, enlace(cursor) end return nil end
ClearCursor = function() cursor = nil end
CursorHasItem = function() return cursor ~= nil end

AlfaNucleoCharDB = AlfaNucleoCharDB or {}
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

local A, N, K = Alfa, AlfaNucleo, AlfaNucleo.Kit
local Op = A.UI.Options
local B = NS_OF("Alfa_Bolsas")
local V, Bt, O, D, Co, Pv, Ba = B.Ventana, B.Botones, B.Objetos, B.Datos, B.Comparar, B.Previa, B.Barra
check(Pv and Bt.Refrescar and D.Plegadas and O.PonerSeccion and Co.Veredicto, "faltan las piezas de la 1.4.0 (Previa, Refrescar, Plegadas, PonerSeccion, Veredicto)")

---------------------------------------------------------------------------
-- La medida de cada texto de casilla
---------------------------------------------------------------------------
local function lleno(fs) return fs and fs:IsShown() and (fs:GetText() or "") ~= "" end
local function medir(etapa)
  local gen = BANCO_GEN_LETRA
  local n, malos = 0, 0
  local function uno(p, nombre, fs, minimo)
    n = n + 1
    local cara, s = fs:GetFont()
    local lay = fs._lay
    local txt = tostring(fs:GetText())
    local ok = true
    if not (lay and lay.gen == gen) then ok = false check(false, ("%s: «%s» (%s) quedó dibujado con la pantalla de antes"):format(etapa, txt, nombre)) end
    if not (lay and lay.size == s and lay.path == cara) then
      ok = false
      check(false, ("%s: «%s» (%s) quedó acomodado con la letra de antes (%s en vez de %s)"):format(etapa, txt, nombre, tostring(lay and lay.size), tostring(s)))
    end
    local rel = s / p.tam
    if rel < (minimo or 0.2) or rel > 0.36 then ok = false check(false, ("%s: «%s» (%s) con letra %s en una casilla de %s (%.0f %%)"):format(etapa, txt, nombre, s, p.tam, rel * 100)) end
    local w = fs:GetUnboundedStringWidth()
    if w > p.tam - 4 then ok = false check(false, ("%s: «%s» (%s) mide %.1f y la casilla %s"):format(etapa, txt, nombre, w, p.tam)) end
    if not ok then malos = malos + 1 end
  end
  for b, p in pairs(Bt.Partes) do
    if b:IsVisible() and (p.tam or 0) > 0 then
      if lleno(p.nivel) then uno(p, "nivel", p.nivel) end
      if lleno(p.cuenta) then uno(p, "montón", p.cuenta) end
      if lleno(p.recarga) then uno(p, "recarga", p.recarga, 0.2) end
      if lleno(p.nivel) and lleno(p.cuenta) then
        local fin = p.nivel:GetLeft() + p.nivel:GetUnboundedStringWidth()
        local ini = p.cuenta:GetRight() - p.cuenta:GetUnboundedStringWidth()
        check(fin <= ini, etapa .. ": el nivel y el montón se enciman")
      end
      if lleno(p.recarga) and lleno(p.cuenta) then
        local _, rs = p.recarga:GetFont()
        local abajoR = select(2, p.recarga:GetCenter()) - rs / 2
        local _, cs = p.cuenta:GetFont()
        check(abajoR >= p.cuenta:GetBottom() + cs * 0.8 - 1, etapa .. ": la recarga se encima con el montón")
      end
    end
  end
  local nb = 0
  for _, c in ipairs(Ba.Todas or {}) do
    if c:IsVisible() and lleno(c.Cuenta) then
      nb = nb + 1
      local cara, s = c.Cuenta:GetFont()
      local lay = c.Cuenta._lay
      check(lay and lay.gen == gen and lay.size == s and lay.path == cara, etapa .. ": el número de la barra («" .. tostring(c.Cuenta:GetText()) .. "») quedó con la medida de antes")
      check(s / c:GetWidth() <= 0.36, etapa .. ": el número de la barra es muy grande")
    end
  end
  check(n >= 8, etapa .. ": se midieron muy pocos textos de casilla: " .. n)
  check(nb >= 1, etapa .. ": no se midió la barra")
  return n, malos
end

local win
step("abrir: los números de las casillas en su medida", function()
  V.MostrarBolsas(true)
  T(4)
  win = V.Ventana("bolsas")
  check(win and win:IsShown(), "la ventana de bolsas no abrió")
  medir("al abrir")
  SNAP("abrir", win)
end)

---------------------------------------------------------------------------
-- 1. Cada camino de «restablecer»
---------------------------------------------------------------------------
step("1: Restablecer página de Bolsas (con casillas de 48)", function()
  N.Set("bolsas", "tamIcono", 48)
  T(4)
  medir("casillas de 48")
  Op.ResetPage("bolsas")
  T(4)
  check(N.Get("bolsas", "tamIcono") == nil or N.Get("bolsas", "tamIcono") == 36, "tamIcono no volvió")
  medir("Restablecer página de Bolsas")
  SNAP("restablecer-bolsas", win)
end)

step("1: Restablecer Estilo y sonido (estilo Clásico)", function()
  A.Set("ui.skin", "clasico")
  T(4)
  medir("estilo Clásico")
  Op.ResetPage("bienvenida")
  T(4)
  medir("Restablecer Estilo y sonido")
end)

step("1: un perfil o un respaldo (todo de una vez)", function()
  A.Fire("SETTING_CHANGED", "")
  if K.Repintar then K.Repintar() end
  T(4)
  medir("perfil o respaldo")
end)

for _, ev in ipairs({ "GX_RESTARTED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
  step("1: " .. ev, function()
    BANCO_GEN_LETRA = BANCO_GEN_LETRA + 1
    FIRE_EVENT(ev)
    T(4)
    medir(ev)
  end)
end

step("1: Dos pantallas y volver", function()
  local Es = NS_OF("Alfa_Bienvenida").Escritorio
  BANCO_GEN_LETRA = BANCO_GEN_LETRA + 1
  PANTALLA_SIMULADA(3840, 1080)
  if Es and Es.Aplicar then pcall(Es.Aplicar) end
  FIRE(UIParent, "OnSizeChanged")
  T(4)
  medir("en Dos pantallas")
  BANCO_GEN_LETRA = BANCO_GEN_LETRA + 1
  if Es and Es.Volver then pcall(Es.Volver) end
  PANTALLA_SIMULADA(1920, 1080)
  FIRE(UIParent, "OnSizeChanged")
  T(4)
  medir("al volver de Dos pantallas")
  SNAP("volver-dos-pantallas", win)
end)

step("1: cerrar, cambiar la pantalla y abrir", function()
  V.MostrarBolsas(false)
  T(2)
  BANCO_GEN_LETRA = BANCO_GEN_LETRA + 1
  FIRE_EVENT("DISPLAY_SIZE_CHANGED")
  T(2)
  V.MostrarBolsas(true)
  T(4)
  medir("al abrir otra vez")
end)

---------------------------------------------------------------------------
-- 62. La escala de Alfa
---------------------------------------------------------------------------
step("62: la escala de Alfa no se pierde al restablecer", function()
  A.Set("nucleo.escalaVentanas", 1.2)
  T(3)
  check(math.abs((win:GetScale() or 1) - 1.2) < 0.001, "la ventana de bolsas no sigue el tamaño de las ventanas de Alfa: " .. tostring(win:GetScale()))
  medir("escala 1,2")
  Op.ResetPage("bienvenida")
  T(3)
  check(A.Get("nucleo.escalaVentanas") == 1.2, "Restablecer Estilo y sonido borró la escala de Alfa: " .. tostring(A.Get("nucleo.escalaVentanas")))
  -- Un restablecer general o un perfil que no la trae: vuelve sola.
  AlfaDB.settings.nucleo.escalaVentanas = nil
  A.Fire("SETTING_CHANGED", "")
  T(3)
  check(A.Get("nucleo.escalaVentanas") == 1.2, "un restablecer general perdió la escala de Alfa: " .. tostring(A.Get("nucleo.escalaVentanas")))
  check(math.abs((win:GetScale() or 1) - 1.2) < 0.001, "tras el restablecer general la ventana no volvió a su escala")
  -- Elegir 100 % a propósito se respeta.
  A.Set("nucleo.escalaVentanas", nil)
  T(3)
  AlfaDB.settings.nucleo.escalaVentanas = nil
  A.Fire("SETTING_CHANGED", "")
  T(3)
  check(A.Get("nucleo.escalaVentanas") == 1 and math.abs((win:GetScale() or 1) - 1) < 0.001, "volver a 100 % no se respetó")
  medir("escala 1")
end)

---------------------------------------------------------------------------
-- 19. Ordenar con vista previa
---------------------------------------------------------------------------
step("19: Ordenar con vista previa", function()
  N.Set("bolsas", "ordenarModo", "tipo")
  T(2)
  movidos = 0
  FIRE(win.Ordenar, "OnEnter")
  local p = rawget(_G, "AlfaBolsasPrevia")
  check(p and p:IsShown(), "al pasar por «Ordenar» no sale la vista previa")
  local lista, exacto = Pv.Resultado()
  check(exacto, "con «Por tipo» la vista previa no es exacta")
  -- Lino 5 + 7 = un montón de 12; la poción 3 + 2 = 5.
  local lino, pocion = 0, 0
  for _, x in ipairs(lista) do
    if x.id == 2589 then lino = lino + 1 check(x.n == 12, "el lino no sale junto: " .. tostring(x.n)) end
    if x.id == 118 then pocion = pocion + 1 end
  end
  check(lino == 1 and pocion == 1, "los montones no salen juntos en la vista previa")
  check(lista[1] and (lista[1].id == 9300 or lista[1].id == 9301 or lista[1].id == 9103), "por tipo, el equipo no va primero")
  check(movidos == 0, "la vista previa movió objetos")
  if p then
    check(p:GetWidth() > 100 and p:GetHeight() > 40, "la vista previa no tiene tamaño")
    check(not p:IsMouseEnabled(), "la vista previa atrapa clics")
    SNAP("ordenar-previa", p)
  end
  FIRE(win.Ordenar, "OnLeave")
  check(not (p and p:IsShown()), "la vista previa no se va al quitar el ratón")
  N.Set("bolsas", "ordenarModo", nil)
  T(2)
  FIRE(win.Ordenar, "OnEnter")
  local _, exacto2 = Pv.Resultado()
  check(not exacto2 and p:IsShown(), "con el orden del juego no sale la vista aproximada")
  FIRE(win.Ordenar, "OnLeave")
end)

---------------------------------------------------------------------------
-- 20. La tarjeta de bolsas llenas
---------------------------------------------------------------------------
step("20: tarjeta compacta con «Ver»", function()
  for s = 10, 14 do bolsa[s] = cosa(4865) end -- quedan 2
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  T(5)
  local c = win.Consejo
  check(c and c:IsShown(), "con 2 casillas libres no sale la tarjeta")
  if not c then return end
  check(c:GetHeight() <= 40, "la tarjeta compacta es alta: " .. tostring(c:GetHeight()))
  check((c.Titulo:GetText() or ""):find("2", 1, true), "la tarjeta no dice cuántas casillas quedan: " .. tostring(c.Titulo:GetText()))
  check(not c.Texto:IsShown(), "la tarjeta compacta enseña el párrafo")
  check(c.Ver:IsShown() and c.Ver:GetRight() <= c:GetRight() and c.Ver:GetLeft() >= c.Titulo:GetLeft() + c.Titulo:GetStringWidth(), "«Ver» se encima con el título o se sale")
  SNAP("tarjeta-compacta", win)
  c.Ver:Click()
  T(4)
  check(c.Texto:IsShown() and c:GetHeight() > 60, "«Ver» no abre la tarjeta")
  check((c.Texto._max or 0) >= 6, "el texto de la tarjeta abierta se corta en pocas líneas")
  SNAP("tarjeta-abierta", win)
  c.Ver:Click()
  T(3)
  check(not c.Texto:IsShown(), "«Menos» no la vuelve a una línea")
  for s = 10, 14 do bolsa[s] = nil end
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  T(4)
end)

---------------------------------------------------------------------------
-- 21. Secciones plegadas por personaje
---------------------------------------------------------------------------
step("21: secciones plegadas por personaje", function()
  local raiz = D.Raiz()
  raiz.ui.plegadas["bolsas:otros"] = true -- lo de la cuenta, de antes
  raiz.ui.plegadasPJ = nil
  local t = D.Plegadas()
  check(t["bolsas:otros"] == true, "el personaje no empezó con lo que ya tenías plegado")
  local h
  for _, x in ipairs(win.cabs) do if x:IsShown() and x.cat == "equipo" then h = x end end
  check(h, "no encontré la cabecera de Equipo")
  if not h then return end
  h:Click()
  T(3)
  check(D.Plegadas()["bolsas:equipo"] == true, "plegar Equipo no se guardó en tu personaje")
  check(raiz.ui.plegadas["bolsas:equipo"] == nil, "plegar Equipo cambió lo de toda la cuenta")
  local k = D.Clave()
  check(raiz.ui.plegadasPJ and raiz.ui.plegadasPJ[k], "no hay plegadas por personaje")
  -- Otro personaje: empieza con lo de la cuenta, no con lo tuyo.
  raiz.ui.plegadasPJ["Otro-Reino"] = nil
  local otro = {}
  for cat, v in pairs(raiz.ui.plegadas) do otro[cat] = v end
  check(otro["bolsas:equipo"] == nil, "lo tuyo pasó a los demás")
  h:Click()
  T(3)
  check(not D.Plegadas()["bolsas:equipo"], "desplegar no se guardó")
end)

---------------------------------------------------------------------------
-- 22. Arrastrar un objeto a otra sección
---------------------------------------------------------------------------
local function seccionDe(id)
  for b, p in pairs(Bt.Partes) do
    if b:IsVisible() and p.ent and p.ent.rec and tonumber(p.ent.rec.i) == id then return p.ent.cat end
  end
end
step("22: arrastrar la poción a Artesanía", function()
  check(seccionDe(118) == "consumibles", "la poción no empieza en Consumibles: " .. tostring(seccionDe(118)))
  local h
  for _, x in ipairs(win.cabs) do if x:IsShown() and x.cat == "artesania" then h = x end end
  check(h, "no encontré la cabecera de Artesanía")
  if not h then return end
  local plegada = D.Plegadas()["bolsas:artesania"]
  cursor = 118
  FIRE(h, "OnReceiveDrag")
  T(4)
  check(cursor == nil, "el objeto se quedó en el cursor")
  check(O.SeccionPropia(118) == "artesania", "no se guardó la sección elegida")
  check(seccionDe(118) == "artesania", "la poción no se ve en Artesanía: " .. tostring(seccionDe(118)))
  check(D.Plegadas()["bolsas:artesania"] == plegada, "soltar plegó o desplegó la sección")
  SNAP("seccion-propia", win)
  -- Soltarla otra vez en Artesanía la devuelve (Consumibles ya no tiene cabecera).
  for _, x in ipairs(win.cabs) do if x:IsShown() and x.cat == "artesania" then h = x end end
  cursor = 118
  h:Click()
  T(4)
  check(O.SeccionPropia(118) == nil and seccionDe(118) == "consumibles", "soltarla otra vez en su sección no la devolvió")
end)

---------------------------------------------------------------------------
-- 23. Espacio libre por tipo de bolsa
---------------------------------------------------------------------------
step("23: el carcaj con su espacio", function()
  N.Set("bolsas", "columnas", 14)
  T(4)
  local fams = V.Familias(win)
  local hay
  for _, x in ipairs(fams) do if x.nombre == "Carcaj" then hay = x end end
  check(hay and hay.libres == 4 and hay.total == 6, "el carcaj no cuenta su espacio: " .. tostring(hay and hay.libres) .. "/" .. tostring(hay and hay.total))
  local t = win.Libre:GetText() or ""
  check(t:find("Carcaj", 1, true), "el pie no dice el espacio del carcaj: " .. t)
  check(win.Libre:GetRight() <= win:GetRight(), "el pie se sale de la ventana")
  check(V.NombreFamilia(32) == "Hierbas" and V.NombreFamilia(4) == "Bolsa de almas", "los nombres de las bolsas especiales")
  check(win.Libre:GetLeft() >= (win.Sobra:IsShown() and win.Sobra:GetRight() or win.Dinero:GetRight()), "el pie se encima con «Lo que me sobra»")
  SNAP("pie-carcaj", win)
  -- Angosta: sin lugar, solo «Libre» (el carcaj sigue en el cuadro del pie).
  N.Set("bolsas", "columnas", 6)
  T(4)
  check(win.Libre:GetLeft() >= (win.Sobra:IsShown() and win.Sobra:GetRight() or win.Dinero:GetRight()), "angosta, el pie se encima")
  N.Set("bolsas", "columnas", nil)
  T(4)
end)

---------------------------------------------------------------------------
-- 24. Comparar: mejor o peor en una línea
---------------------------------------------------------------------------
step("24: «Mejor que lo que llevas:»", function()
  check(Co.Veredicto({ puntos = 3 }) == "mejor" and Co.Veredicto({ puntos = -2 }) == "peor" and Co.Veredicto({ puntos = 0.1 }) == nil and Co.Veredicto({}) == nil,
    "el veredicto no sale bien")
  local G0 = A.Gear
  A.Gear = {
    CompareToEquipped = function() return { slot = 16 } end,
    GetItemInfo = function(l) if l == enlace(9300) then return { stats = { str = 8, sta = 2 } } end return { stats = { str = 3, sta = 4 } } end,
    GetWeights = function() return { str = 1, sta = 0.5 } end,
  }
  local linea = Co.Linea(enlace(9300)) or ""
  check(linea:find("Mejor que lo que llevas:", 1, true) and linea:find("Fuerza", 1, true), "la línea no dice «Mejor»: " .. linea)
  A.Gear.GetItemInfo = function(l) if l == enlace(9300) then return { stats = { str = 1 } } end return { stats = { str = 6 } } end
  linea = Co.Linea(enlace(9300)) or ""
  check(linea:find("Peor que lo que llevas:", 1, true), "la línea no dice «Peor»: " .. linea)
  A.Gear = G0
end)

print(("PRUEBA: 1.4.0 bolsas, %d pasos, %d errores"):format(pasos, #ERRORS))
