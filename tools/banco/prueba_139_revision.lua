-- Prueba de la 1.3.9, revisión independiente (tools/prueba.py la corre con las demás):
--   1. «Callar lo repetido» cuenta el texto también: avisos con la misma
--      clave y otro texto («¡Lista! Sigue: X» / «…: Y») siguen saliendo.
--   2. «Ordenar» no «intercambia» dos montones del mismo objeto (el juego los
--      junta y deja el resto en el cursor).
--   3. La flecha: con una ruta propia (Nav.OtroLugar) la placa trae «Siguiente
--      lugar» y se queda; en combate, ya ida la placa, no atrapa el ratón.
--   4. Recolección: peleando junto al nodo no lo da por vacío.
--   5. «Restablecer esta guía» en una guía de niveles: el primer paso que te
--      falta, no el último con una misión de más adelante en tu registro.
--   6. «Cerrar mis misiones» terminado: solo cuentan las que entrarían a un
--      plan (las de «Para después» no).
--   7. Lo que quitaste desde el rastreador se queda fuera al abrir el plan
--      desde otro lado; lo de las casillas del resumen, no.
--   8. Censo: «dev» no es más nueva; un solo lobo no hace saltar el aviso.
--   9. Curación: con 6 mapas, el de tu rama se vuelve a guardar.
--  10. (no era real) «Mandar a…» ya revisa que la casilla tenga el mismo objeto.
--  11. Los planos de mazmorra del Escritorio no toman el ratón en combate.
SNAPSHOTS = {}
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
local function check(cond, msg) if not cond then NOTE("1.3.9 revisión", msg) end end
local function T(n) RUN_TIMERS(n or 2) end
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do t[k] = a.v end
  if not ok then error(e, 0) end
end

local impresos = {}
local imprimirReal = AlfaNucleo.Imprimir
AlfaNucleo.Imprimir = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  impresos[#impresos + 1] = table.concat(t, " ")
  return imprimirReal(...)
end

-- El registro de misiones de mentira (como prueba_139_misiones2).
local LOG, ORDEN, HECHAS = {}, {}, {}
local function poner(q, listo)
  if not LOG[q] then ORDEN[#ORDEN + 1] = q end
  LOG[q] = { listo = listo }
end
local function quitar(q)
  LOG[q] = nil
  for i = #ORDEN, 1, -1 do if ORDEN[i] == q then table.remove(ORDEN, i) end end
end
local QL = C_QuestLog
QL.IsOnQuest = function(q) return LOG[q] ~= nil end
QL.ReadyForTurnIn = function(q) return LOG[q] ~= nil and LOG[q].listo or false end
QL.IsComplete = function(q) return LOG[q] ~= nil and LOG[q].listo or false end
QL.IsFailed = function() return false end
QL.GetQuestObjectives = function() return {} end
QL.GetNumQuestLogEntries = function() return #ORDEN, #ORDEN end
QL.GetInfo = function(i) local q = ORDEN[i] return q and { questID = q, title = "Misión " .. q, isHeader = false, isHidden = false, level = 23 } or nil end
QL.GetLogIndexForQuestID = function(q) for i, x in ipairs(ORDEN) do if x == q then return i end end return nil end
QL.IsQuestFlaggedCompleted = function(q) return HECHAS[q] or false end
QL.GetTitleForQuestID = function(q) return LOG[q] and ("Misión " .. q) or nil end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
if Alfa.UI and Alfa.UI.Options and Alfa.UI.Options.frame then Alfa.UI.Options.frame:Hide() end

local N = AlfaNucleo
local K = N.Kit
local A = Alfa
local E = A.Engine
local Ru = NS_OF("Alfa_Rutas")

---------------------------------------------------------------------------
-- 1. Callar lo repetido: la clave y el texto
---------------------------------------------------------------------------
step("1: la misma clave con otro texto no se calla", function()
  check(N.Repeticion, "falta N.Repeticion")
  for i = 1, 8 do
    local r = N.Repeticion({ clave = "rutas.cerrarSigue", titulo = "¡Lista! Sigue: Misión número " .. string.char(64 + i), texto = "Sigue: " .. string.char(64 + i) })
    check(r == "sale", "el «Sigue» " .. i .. " (otra misión) se calló: " .. tostring(r))
  end
  -- El mismo aviso con la misma clave sí se calla (los números no cuentan).
  local r
  for i = 1, N.REPETIR_MAX + 1 do r = N.Repeticion({ clave = "bolsas.llenas", titulo = "Bolsas llenas (" .. i .. ")", texto = "Te quedan " .. i }) end
  check(r == "ultima", "el mismo aviso repetido no se calló a la " .. (N.REPETIR_MAX + 1) .. ".ª: " .. tostring(r))
  r = N.Repeticion({ clave = "bolsas.llenas", titulo = "Bolsas llenas (9)", texto = "Te quedan 9" })
  check(r == "callado", "después de callarlo sigue saliendo: " .. tostring(r))
  N.ReactivarTodos()
end)

---------------------------------------------------------------------------
-- 2. Ordenar: dos montones del mismo objeto
---------------------------------------------------------------------------
local B = NS_OF("Alfa_Bolsas")
local Ord = B.Ordenar
local OBJ = { [2589] = { "Lino", 1, 20 }, [118] = { "Poción de sanación menor", 1, 5 }, [9301] = { "Espada del oso", 2, 1 } }
local function enlace(id) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. OBJ[id][1] .. "]|h|r" end
local bolsa, cursor = {}, nil
local function cosa(id, n) return { itemID = id, stackCount = n or 1, quality = OBJ[id][2], hyperlink = enlace(id), isLocked = false } end
local function bolsasDeMentira(fn)
  local CCo, CI = C_Container, C_Item
  local guarda = {}
  for _, k in ipairs({ "GetContainerNumSlots", "GetContainerNumFreeSlots", "GetContainerItemInfo", "GetContainerItemLink", "GetContainerItemID", "PickupContainerItem" }) do guarda[k] = CCo[k] end
  local infoReal = CI.GetItemInfo
  local cursorReal = rawget(_G, "CursorHasItem")
  CCo.GetContainerNumSlots = function(b) return b == 0 and 8 or 0 end
  CCo.GetContainerNumFreeSlots = function(b) if b ~= 0 then return 0, 0 end local n = 0 for s = 1, 8 do if not bolsa[s] then n = n + 1 end end return n, 0 end
  CCo.GetContainerItemInfo = function(b, s) return b == 0 and bolsa[s] or nil end
  CCo.GetContainerItemLink = function(b, s) local i = b == 0 and bolsa[s] return i and i.hyperlink or nil end
  CCo.GetContainerItemID = function(b, s) local i = b == 0 and bolsa[s] return i and i.itemID or nil end
  -- Como el juego: soltar un montón sobre otro del mismo objeto los JUNTA (lo
  -- que no cabe se queda en el cursor); sobre otro objeto, los cambia.
  -- (En la versión de antes, «5 antes de 20» dejaba 5 en el cursor.)
  CCo.PickupContainerItem = function(b, s)
    if b ~= 0 then return end
    if not cursor then
      if bolsa[s] then cursor = { de = s, item = bolsa[s] } bolsa[s] = nil end
      return
    end
    local c = cursor
    local d = bolsa[s]
    if not d then bolsa[s] = c.item cursor = nil return end
    if d.itemID == c.item.itemID and OBJ[d.itemID][3] > 1 then
      local cabe = OBJ[d.itemID][3] - d.stackCount
      local pasa = math.min(cabe, c.item.stackCount)
      d.stackCount = d.stackCount + pasa
      c.item.stackCount = c.item.stackCount - pasa
      if c.item.stackCount <= 0 then cursor = nil end
      return
    end
    -- Otro objeto: se cambian de lugar (el de aquí va a donde estaba el otro).
    bolsa[s] = c.item
    if bolsa[c.de] == nil then bolsa[c.de] = d cursor = nil else cursor = { de = s, item = d } end
  end
  CI.GetItemInfo = function(x)
    local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)"))
    local o = id and OBJ[id]
    if not o then return nil end
    return o[1], enlace(id), o[2], 20, 1, "Tipo", "Subtipo", o[3], "", 134400, 1, 7, 5
  end
  CursorHasItem = function() return cursor ~= nil end
  local ok, e = pcall(fn)
  for k, v in pairs(guarda) do CCo[k] = v end
  CI.GetItemInfo = infoReal
  CursorHasItem = cursorReal
  cursor = nil
  if not ok then error(e, 0) end
end
local function linos()
  local t, n = 0, 0
  for s = 1, 8 do if bolsa[s] and bolsa[s].itemID == 2589 then t = t + bolsa[s].stackCount n = n + 1 end end
  return t, n
end

step("2: ordenar no deja un montón pegado al cursor", function()
  check(Ord and Ord.Paso, "falta Ordenar.lua")
  N.Set("bolsas", "ordenarModo", "nombre")
  bolsasDeMentira(function()
    for _, caso in ipairs({
      { "5 antes de 20", { [1] = cosa(2589, 5), [2] = cosa(2589, 20) } },
      { "18 y 19 (no caben juntos)", { [1] = cosa(2589, 18), [2] = cosa(2589, 19) } },
      { "la poción primero", { [1] = cosa(118, 3), [2] = cosa(2589, 5), [3] = cosa(2589, 20) } },
    }) do
      bolsa = caso[2]
      local antes = linos()
      local r
      for _ = 1, 20 do
        r = Ord.Paso()
        if r ~= "movi" then break end
      end
      check(r == "hecho", caso[1] .. ": ordenar terminó con «" .. tostring(r) .. "»")
      check(cursor == nil, caso[1] .. ": quedó algo en el cursor")
      local t = linos()
      check(t == antes, caso[1] .. ": se perdió lino: " .. t .. " de " .. antes)
      check(bolsa[1] and bolsa[1].itemID == 2589, caso[1] .. ": el lino no quedó primero (por nombre)")
    end
  end)
  N.Set("bolsas", "ordenarModo", nil)
end)

---------------------------------------------------------------------------
-- 3. La flecha con una ruta propia
---------------------------------------------------------------------------
local Nav = A.Nav
local Arrow = Nav and Nav.arrow
local function pasaElRato()
  local f = Arrow.llegada
  if not f then return end
  local fn = f:GetScript("OnUpdate")
  for _ = 1, 400 do if fn then fn(f, 0.1) end end
end
local function llegar(target, estado, fn)
  con(Nav, {
    Sample = function() return estado, 3, 0 end,
    GetTarget = function() return target end,
    NextSpot = function() return false end,
    TomTomArrowGuides = function() return false end,
    HandedOff = function() return false end,
    HiddenWithGuide = function() return false end,
  }, function()
    con(E, { GetStepView = function() return { index = 1, goals = { { t = "kill", status = "active" } } } end, GetGuide = function() return nil end }, function()
      con(A, { ArrowHidden = function() return false end }, function()
        Arrow:OnTarget(target)
        fn()
        Arrow:OnTarget(nil)
        Arrow.frame:Hide()
      end)
    end)
  end)
end

step("3: la ruta de Recolección trae «Siguiente lugar» y en combate nada invisible atrapa clics", function()
  check(Arrow and Arrow.Llegada, "falta la flecha")
  local hay = true
  Nav.OtroLugar = { disponible = function() return hay end, ir = function() return true end }
  local Tg = { label = "Ruta 3/12: Veta de estaño", map = 1440, x = 50, y = 50 }
  for _, estado in ipairs({ "arrived", "search" }) do
    hay = true
    llegar(Tg, estado, function()
      local f = Arrow.llegada
      check(f and f:IsShown(), estado .. ": la placa no salió")
      check(f and f.Siguiente and f.Siguiente:IsShown(), estado .. ": la placa no trae «Siguiente lugar» con la ruta de Recolección")
      pasaElRato()
      check(f:IsShown(), estado .. ": con «Siguiente lugar» la placa se fue sola")
      -- En combate: el botón no toma el ratón, y si la placa se va, la flecha tampoco.
      FIRE_EVENT("PLAYER_REGEN_DISABLED")
      check(not f.Siguiente:IsMouseEnabled(), estado .. ": en combate «Siguiente lugar» toma el ratón")
      f.alfaQueda = -100
      pasaElRato()
      check(not f:IsShown(), estado .. ": la placa no se fue")
      check(not Arrow.frame:IsMouseEnabled(), estado .. ": en combate, ya ida la placa, la flecha atrapa el ratón")
      -- Al repintar en combate con lo mismo, tampoco.
      if Arrow.LlegadaAlDia then Arrow.LlegadaAlDia() end
      if not f:IsShown() then check(not Arrow.frame:IsMouseEnabled(), estado .. ": al repintar en combate atrapa el ratón") end
      FIRE_EVENT("PLAYER_REGEN_ENABLED")
    end)
  end
  Nav.OtroLugar = nil
end)

---------------------------------------------------------------------------
-- 4. Recolección: peleando junto al nodo
---------------------------------------------------------------------------
local Rc = NS_OF("Alfa_Recoleccion")
step("4: si te atacan junto al nodo, la ruta no lo da por vacío", function()
  local Ll, Ruta = Rc.Llevar, Rc.Ruta
  check(Ll and Ruta, "falta Recolección")
  if not (Ll and Ruta) then return end
  local mundoReal, posReal = A.Compat.MapToWorld, A.Compat.GetPlayerWorldPosition
  A.Compat.MapToWorld = function(mapa, x, y) if type(mapa) ~= "number" then return nil end return mapa, (y or 0) * 40, (x or 0) * 40 end
  local yo = { 1413, 0, 0 }
  A.Compat.GetPlayerWorldPosition = function() return yo[1], yo[2], yo[3] end
  local conocido = Rc.R.EsConocido
  Rc.R.EsConocido = function() return true end
  local pd = Ll.Pedido(2775)
  local z = pd and Ll.Zonas({ claves = pd.claves, anfitriones = pd.anfitriones, nivel = 23, faccion = "H" })[1]
  check(z ~= nil, "sin zona para la plata")
  if z then
    yo[1] = z.mapa
    check(Ll.Llevar(2775, { nivel = 23, faccion = "H" }), "Llevar(plata) falló")
    for _ = 1, 50 do T(1) if not Ruta.Calculando() then break end end
    local r = Ruta.Actual()
    check(r and r.guiando, "la ruta no guía")
    if r and r.guiando then
      local k = r.siguiente
      yo[1], yo[2], yo[3] = r.c, r.wx[k], r.wy[k]
      impresos = {}
      -- Llegas y te ataca un bicho: más de su espera peleando, sin lanzar nada.
      con(_G, { InCombatLockdown = function() return true end, UnitAffectingCombat = function() return true end }, function()
        T(2)
        for _ = 1, 3 do NOW = NOW + Ruta.ESPERA + 1 T(2) end
      end)
      check(r.siguiente == k, "peleando junto al nodo lo dio por vacío")
      check(not Ruta.Vacia(k), "peleando el nodo quedó marcado vacío")
      -- Ya sin pelea, si no recolectas, sí.
      T(2)
      NOW = NOW + Ruta.ESPERA + 1
      T(2)
      check(r.siguiente ~= k and Ruta.Vacia(k), "sin pelea y sin recolectar no pasó al siguiente")
      Ruta.Detener()
    end
  end
  Rc.R.EsConocido = conocido
  A.Compat.MapToWorld, A.Compat.GetPlayerWorldPosition = mundoReal, posReal
end)

---------------------------------------------------------------------------
-- 5. Restablecer una guía de niveles
---------------------------------------------------------------------------
step("5: restablecer una guía de niveles va al primer paso que te falta", function()
  local Rb = Ru.Restablecer
  check(Rb and Rb.Detectar, "falta Restablecer.lua")
  local function mision(t, q) return { t = t, quest = q, title = "Misión " .. q, npc = 1000 + q, npcName = "PNJ " .. q, map = 1429, x = 40 + q % 10, y = 50 } end
  local pasos = {
    { title = "Toma la 5001", goals = { mision("accept", 5001) } },
    { title = "Entrega la 5001", goals = { mision("turnin", 5001) } },
    { title = "Toma la 5002", goals = { mision("accept", 5002) } },
    { title = "Entrega la 5002", goals = { mision("turnin", 5002) } },
    { title = "Toma la 5003", goals = { mision("accept", 5003) } },
    { title = "Entrega la 5003", goals = { mision("turnin", 5003) } },
    { title = "Sube a 30", goals = { { t = "level", level = 30 } } },
    { title = "Toma la 5009", goals = { mision("accept", 5009) } },
    { title = "Entrega la 5009", goals = { mision("turnin", 5009) } },
  }
  local id = Ru.Guias.IdEspecial("prueba139niveles")
  local def = Ru.Guias.Def(id, "Niveles de prueba", pasos)
  check(Ru.Guias.Instalar(def), "no se instaló la guía de niveles de prueba")
  -- Ya entregaste la 5001, llevas la 5002 (sin terminar) y la 5009 (de mucho más adelante).
  HECHAS[5001] = true
  poner(5002, false)
  poner(5009, false)
  FIRE_EVENT("QUEST_LOG_UPDATE") T(2)
  Ru.Guias.Abrir(id) T(3)
  local g = E.GetGuide()
  check(g and g.id == id, "no se abrió la guía de niveles de prueba")
  check(Rb.Detectar() == 3, "no se ubicó antes de la primera que falta (entregar la 5002): " .. tostring(Rb.Detectar()))
  check(Rb.Restablecer(true), "no restableció")
  T(2)
  check(E.GetLiveStep() == 4, "restablecida no quedó en «Entrega la 5002» (el 4): " .. tostring(E.GetLiveStep()))
  -- Sin nada hecho, no salta nada.
  HECHAS[5001] = nil
  quitar(5002)
  FIRE_EVENT("QUEST_LOG_UPDATE") T(2)
  check(Rb.Detectar() == nil, "sin nada hecho se ubicó en " .. tostring(Rb.Detectar()))
  quitar(5009)
  FIRE_EVENT("QUEST_LOG_UPDATE") T(2)
end)

---------------------------------------------------------------------------
-- 6 y 7. «Cerrar mis misiones»: lo que cuenta y lo que quitaste
---------------------------------------------------------------------------
step("6: con solo las de «Para después» en tu registro, el cierre ya no ofrece cerrarlas", function()
  local Cr, Rs = Ru.Cerrar, Ru.Rastreador
  check(Cr.QuedanParaPlan and Rs.Cierre, "falta Cerrar.QuedanParaPlan")
  poner(6101, false) poner(6102, false)
  FIRE_EVENT("QUEST_LOG_UPDATE") T(2)
  -- El plan las vio y las dejó fuera (élite, grises...).
  local p = Ru.Personaje()
  p.liberarSello = { filtro = "todas", log = { [6101] = false, [6102] = false }, dentro = {} }
  HECHAS[6100] = true
  local idL = Ru.Guias.IdLiberar()
  check(Ru.Guias.Instalar(Ru.Guias.Def(idL, "Cerrar mis misiones", {
    { title = "Entrega", goals = { { t = "turnin", quest = 6100, title = "Misión 6100", npc = 344, npcName = "Magistrado", map = 1433, x = 29.7, y = 44.2 } } },
  })), "no se instaló el plan")
  Ru.Guias.Abrir(idL) T(3)
  check(E.GetLiveStep() == nil, "el plan no está terminado")
  check(Cr.QuedanParaPlan() == 0, "las de «Para después» cuentan: " .. tostring(Cr.QuedanParaPlan()))
  local c = Rs.Cierre()
  check(c and not c.cerrar, "el cierre sigue ofreciendo cerrar las de «Para después»")
  -- Una nueva sí cuenta.
  poner(6103, false)
  FIRE_EVENT("QUEST_LOG_UPDATE") T(2)
  check(Cr.QuedanParaPlan() == 1, "la nueva no cuenta: " .. tostring(Cr.QuedanParaPlan()))
  c = Rs.Cierre()
  check(c and c.cerrar and c.quedan == 1, "con una nueva no ofrece cerrarla: " .. tostring(c and c.quedan))
end)

step("7: lo que quitaste desde el rastreador se queda fuera", function()
  local Cr, Ct = Ru.Cerrar, Ru.CerrarTodo
  local p = Ru.Personaje()
  Cr.Quitar(6103, true)
  Cr.Quitar(6101)
  check(p.marcas[6103] == "quitada" and p.marcas[6101] == "fuera", "las marcas no son «quitada» y «fuera»")
  check(Cr.QuedanParaPlan() == 0, "la quitada cuenta para un plan")
  Ct.Abrir({ origen = "hoy" })
  check(p.marcas[6103] == "quitada", "abrir desde Hoy volvió a meter la que quitaste desde el rastreador")
  check(p.marcas[6101] == nil, "abrir desde Hoy no volvió a meter la de las casillas")
  if Ct.Ventana() then Ct.Ventana():Cerrar() end
  T(2)
  -- Agregarla otra vez a mano la mete.
  Cr.Agregar(6103)
  check(p.marcas[6103] == nil, "agregarla no quitó la marca")
  for _, q in ipairs({ 6101, 6102, 6103 }) do quitar(q) end
  p.liberarSello = nil
  FIRE_EVENT("QUEST_LOG_UPDATE") T(2)
end)

---------------------------------------------------------------------------
-- 8. Censo: versiones de mentira
---------------------------------------------------------------------------
step("8: «dev» y un solo lobo no hacen saltar «Hay una versión nueva»", function()
  local Ce = NS_OF("Alfa_Manada").Censo
  check(Ce and Ce.Nueva, "falta Censo.lua")
  local versionReal = A.version
  A.version = "1.3.9"
  N.Datos("manada").censo = {}
  N.Datos("manada").censoAvisada = nil
  local avisos = {}
  con(K, { Aviso = function(o) avisos[#avisos + 1] = o return nil end }, function()
    local function nuevas() local n = 0 for _, a in ipairs(avisos) do if a.id == "manada.censoNueva" then n = n + 1 end end return n end
    check(Ce.Comparar("dev", "1.3.9") == 0 and Ce.Comparar("1.3.9", "dev") == 0, "«dev» se compara con la tuya")
    Ce.AlMensaje("Prueba-Reino", "Prueba-Reino", { "v", "dev", "30", "0" }, "GUILD")
    Ce.AlMensaje("Otro-Reino", "Otro-Reino", { "v", "dev", "30", "0" }, "GUILD")
    T(2)
    check(nuevas() == 0 and Ce.Nueva() == nil, "«dev» cuenta como una versión nueva")
    Ce.AlMensaje("Bromista-Reino", "Bromista-Reino", { "v", "99.0", "30", "0" }, "GUILD")
    Ce.AlMensaje("Solo-Reino", "Solo-Reino", { "v", "1.4.0", "30", "0" }, "GUILD")
    T(2)
    check(nuevas() == 0 and Ce.Nueva() == nil, "un solo lobo (o «99.0» sin tres números) hizo saltar el aviso")
    Ce.AlMensaje("Segundo-Reino", "Segundo-Reino", { "v", "1.4.0", "30", "0" }, "GUILD")
    T(2)
    check(Ce.Nueva() == "1.4.0", "con dos lobos con la 1.4.0 no la reconoce: " .. tostring(Ce.Nueva()))
    check(nuevas() == 1, "con dos lobos no avisó (o avisó de más): " .. nuevas())
    -- Uno de rango alto (oficial) basta.
    con(_G, {
      GetNumGuildMembers = function() return 2, 2 end,
      GetGuildRosterInfo = function(i) if i == 1 then return "Jefa-Reino", "Oficial", 1 end return "Solo-Reino", "Lobo", 5 end,
    }, function()
      Ce.AlMensaje("Jefa-Reino", "Jefa-Reino", { "v", "1.5.0", "30", "0" }, "GUILD")
      T(2)
      check(Ce.Nueva() == "1.5.0", "la versión de una oficial no cuenta: " .. tostring(Ce.Nueva()))
      check(nuevas() == 2, "la oficial no hizo saltar el aviso: " .. nuevas())
    end)
  end)
  N.Datos("manada").censo = {}
  N.Datos("manada").censoAvisada = nil
  A.version = versionReal
end)

---------------------------------------------------------------------------
-- 9. Curación: el mapa de tu rama con seis guardados
---------------------------------------------------------------------------
step("9: con seis mapas, «Guardar este» actualiza el de tu rama", function()
  local Cu = NS_OF("Alfa_Curacion")
  check(Cu and Cu.GuardarMapa and Cu.MapasGuardados, "falta Curación")
  if not (Cu and Cu.GuardarMapa) then return end
  local lista = Cu.MapasGuardados()
  for i = #lista, 1, -1 do lista[i] = nil end
  for i = 1, Cu.MAX_MAPAS do lista[i] = { id = "p" .. i, nombre = "Rama " .. i, rama = "r" .. i, mapa = {}, t = 0 } end
  local ramaReal = Cu.RamaActual
  Cu.RamaActual = function() return "r3", "Rama 3" end
  local id, por = Cu.GuardarMapa()
  check(id == "p3", "con seis mapas no actualizó el de tu rama: " .. tostring(id) .. " " .. tostring(por))
  check(#lista == Cu.MAX_MAPAS, "se agregó uno de más")
  Cu.RamaActual = function() return "r9", "Rama nueva" end
  id, por = Cu.GuardarMapa()
  check(id == nil and por == "lleno", "con seis y una rama nueva no dijo «lleno»")
  Cu.RamaActual = ramaReal
  for i = #lista, 1, -1 do lista[i] = nil end
end)

---------------------------------------------------------------------------
-- 10. (no era real) los lotes revisan el objeto de la casilla
---------------------------------------------------------------------------
step("10: «Mandar a…» salta una casilla que ya no tiene el mismo objeto", function()
  local Lt = B.Lotes
  check(Lt and Lt.Iniciar, "falta Lotes.lua")
  if not (Lt and Lt.Iniciar) then return end
  bolsasDeMentira(function()
    bolsa = { [1] = cosa(118, 3), [2] = cosa(2589, 5) }
    local movidos = {}
    -- La lista se armó con lino en la 1 y en la 2; en la 1 ya hay una poción.
    Lt.Iniciar({ nombre = "prueba.revision", lista = { { 0, 1, 2589 }, { 0, 2, 2589 } },
      mover = function(b, s) movidos[#movidos + 1] = s end })
    for _ = 1, 20 do T(1) end
    check(#movidos == 1 and movidos[1] == 2, "se movió una casilla que ya no tenía el objeto: " .. table.concat(movidos, ","))
  end)
end)

---------------------------------------------------------------------------
-- 11. Los planos del Escritorio en combate
---------------------------------------------------------------------------
step("11: los planos de mazmorra del Escritorio no toman el ratón en combate", function()
  local crear = AlfaMazmorras and AlfaMazmorras.CrearPlano
  check(type(crear) == "function", "falta AlfaMazmorras.CrearPlano")
  if type(crear) ~= "function" then return end
  local padre = CreateFrame("Frame", nil, UIParent)
  padre:SetSize(300, 300)
  local p = crear(padre)
  local rueda = true
  local ruedaReal = p.EnableMouseWheel
  p.EnableMouseWheel = function(self, si) rueda = si and true or false return ruedaReal(self, si) end
  check(p:IsMouseEnabled(), "fuera de combate el plano no toma el ratón")
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not p:IsMouseEnabled() and not rueda, "en combate el plano del Escritorio sigue tomando el ratón (o la rueda)")
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  check(p:IsMouseEnabled() and rueda, "al salir de combate el plano no volvió a tomar el ratón")
  -- Uno creado en combate nace sin ratón.
  con(_G, { InCombatLockdown = function() return true end }, function()
    local q = crear(padre)
    check(not q:IsMouseEnabled(), "un plano creado en combate toma el ratón")
  end)
  padre:Hide()
end)

AlfaNucleo.Imprimir = imprimirReal
print(("PRUEBA: 1.3.9 revisión, %d pasos, errores: %d"):format(pasos, #ERRORS))
