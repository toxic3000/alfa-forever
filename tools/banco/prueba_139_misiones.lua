-- Prueba de la 1.3.9, área misiones (tools/prueba.py la corre con las demás prueba_*.lua):
--   1. «Cerrar mis misiones» desde Hoy con el último atajo en «solo listas»
--      (el bug de Toxic: no hacía nada): 8 misiones sin terminar en 3 zonas,
--      arma con TODAS, la ventana sale al momento con su avance y deja el
--      resumen; la de grupo y la de nivel alto van a «Para después»;
--   2. el mejor orden: cada zona de una vez, las entregas al final de su zona;
--   3. sin la base de misiones o en combate: lo dice y sigue solo;
--   4. «Quitar algunas» (casillas) y los atajos a la vista;
--   5. «Empezar»: la flecha a la primera parada y la ruta en el mapa (capa);
--   6. la ruta se rehace al abandonar una; «¡Lista! Sigue: X»; el festejo;
--   7. el mismo botón en el menú de Alfa, el rastreador y el Escritorio;
--   8. registro casi lleno (27), en común con el grupo (29), el objeto de
--      misión en el rastreador (30), por qué no puedo tomarla (32);
--   9. el rastreador: lo esencial (71), el mismo menú (73), el tiempo (74).
-- Con BANCO_FOTOS=1 dibuja las capturas (tools/banco/shot-139-*.png).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["139-misiones-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.3.9 misiones", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

local NADA = {}
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do
    antes[k] = { v = rawget(t, k) }
    if v == NADA then rawset(t, k, nil) else rawset(t, k, v) end
  end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(t, k, a.v) end
  if not ok then error(e, 0) end
end

-- Un humano de nivel 18 en la Colina del Centinela (Páramos de Poniente).
function UnitFactionGroup() return "Alliance", "Alianza" end
function UnitRace() return "Humano", "Human", 1 end
function UnitLevel() return 18 end
function UnitEffectiveLevel() return 18 end
C_Map.GetBestMapForUnit = function() return 1436 end
C_Map.GetPlayerMapPosition = function() return { x = 0.56, y = 0.47, GetXY = function() return 0.56, 0.47 end } end

-- El registro de misiones del juego, a mano.
local LOG, ORDEN, HECHAS, NIVEL = {}, {}, {}, {}
local function poner(q, listo)
  if not LOG[q] then ORDEN[#ORDEN + 1] = q end
  LOG[q] = { listo = listo, objs = { { text = "Algo: 0/5", type = "monster", finished = listo, numFulfilled = listo and 5 or 0, numRequired = 5 } } }
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
QL.GetQuestObjectives = function(q) return LOG[q] and LOG[q].objs or {} end
QL.GetNumQuestLogEntries = function() return #ORDEN, #ORDEN end
QL.GetInfo = function(i) local q = ORDEN[i] return q and { questID = q, title = "Misión " .. q, isHeader = false, isHidden = false, level = NIVEL[q] or 18 } or nil end
QL.GetLogIndexForQuestID = function(q) for i, x in ipairs(ORDEN) do if x == q then return i end end return nil end
QL.IsQuestFlaggedCompleted = function(q) return HECHAS[q] or false end
QL.GetTitleForQuestID = function(q) return LOG[q] and ("Misión " .. q) or nil end
QL.GetQuestDifficultyLevel = function(q) return NIVEL[q] or 18 end
QL.GetMaxNumQuestsCanAccept = function() return 20 end
local function registro() FIRE_EVENT("QUEST_LOG_UPDATE") T(3) end

-- 8 sin terminar en 3 zonas: Páramos (9, 12, 22, 102), Crestagrana (92, 122,
-- 125) y Elwynn (52). Y dos para después: 19 (pide grupo) y 20 (nivel 24).
local OCHO = { 9, 12, 22, 102, 92, 122, 125, 52 }
for _, q in ipairs(OCHO) do poner(q, false) end
poner(19, false)
poner(20, false) NIVEL[20] = 24

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
registro()

local A = Alfa
local N = AlfaNucleo
local K = AlfaNucleo.Kit
local E = A.Engine
local Ru = NS_OF("Alfa_Rutas")
local Ct, Cr, Rs = Ru.CerrarTodo, Ru.Cerrar, Ru.Rastreador
check(Ct and Ct.Abrir, "falta CerrarTodo.lua")

-- Las tareas de Alfa corren en el OnUpdate de su marco (Tareas.lua).
local marco
local function correr()
  for _ = 1, 4000 do
    T(1)
    if not Ru.Tareas.Alguna() then break end
    if not marco then
      for _, f in ipairs(ALL_FRAMES()) do
        local fn = rawget(f, "_scripts") and f._scripts.OnUpdate
        if fn and (debug.getinfo(fn, "S").source or ""):find("Tareas.lua", 1, true) then marco = f break end
      end
    end
    if marco then FIRE(marco, "OnUpdate", 0.016) end
  end
  T(3)
end
-- Un cuadro de las tareas (para ver el avance a medias).
local function unCuadro()
  T(1)
  if marco then FIRE(marco, "OnUpdate", 0.016) end
end

-- Los textos a la vista dentro de un marco.
local function textos(f, out)
  out = out or {}
  if not f or not f:IsShown() then return out end
  if f._kind == "FontString" and type(f._text) == "string" then out[#out + 1] = f._text end
  for _, h in ipairs(rawget(f, "_children") or {}) do textos(h, out) end
  return out
end
local function dice(f, trozo)
  for _, t in ipairs(textos(f)) do if t:find(trozo, 1, true) then return true end end
  return false
end

-- Los avisos y anuncios, guardados para mirarlos.
local avisos, anuncios = {}, {}
local avisoReal, anuncioReal = K.Aviso, K.Anuncio
K.Aviso = function(o) avisos[#avisos + 1] = o return avisoReal(o) end
K.Anuncio = function(o) anuncios[#anuncios + 1] = o return anuncioReal and anuncioReal(o) end
local function avisoCon(trozo)
  for i = #avisos, 1, -1 do
    local a = avisos[i]
    if tostring(a.titulo):find(trozo, 1, true) or tostring(a.texto):find(trozo, 1, true) then return a end
  end
  return nil
end

local function zonaDe(paso)
  for _, g in ipairs(paso.goals or {}) do if g.map then return g.map end end
  return nil
end

---------------------------------------------------------------------------
-- 1. Desde Hoy, con «solo listas» guardado: arma con todas
---------------------------------------------------------------------------
local ventana
step("Hoy: «Cerrar mis misiones» con el último atajo en «solo listas»", function()
  Cr.SetFiltro("listas")
  -- Lo que la ventana va diciendo (y la captura del avance a medias).
  local dichos, fotoAvance = {}, false
  local pintarYa = Ct.PintarYa
  Ct.PintarYa = function()
    pintarYa()
    local st0 = Ct.Estado()
    dichos[#dichos + 1] = tostring(st0.linea)
    if not fotoAvance and tostring(st0.linea):find("Midiendo caminos", 1, true) and (st0.avance or 0) > 0.3 then
      fotoAvance = true
      SNAP("avance", Ct.Ventana())
    end
  end
  -- El clic de la tarjeta de Hoy (Alfa_Inicio): busca el texto y su botón.
  N.Abrir("inicio")
  T(3)
  local clic
  for _, f0 in ipairs(ALL_FRAMES()) do
    local f
    if f0:IsVisible() then
      for _, r in ipairs(rawget(f0, "_children") or {}) do
        if r._kind == "FontString" and r._text == "Cerrar mis misiones" and r._shown then f = r end
      end
    end
    if f then
      local p = f0
      while p do
        if rawget(p, "_scripts") and (p._scripts.OnClick or p._scripts.OnMouseUp) then clic = p break end
        p = rawget(p, "_parent")
      end
      if clic then break end
    end
  end
  if clic then
    FIRE(clic, clic._scripts.OnClick and "OnClick" or "OnMouseUp", "LeftButton")
  else
    print("AVISO: no encontré la tarjeta de Hoy en el banco; llamo a AlfaRuta.Liberar() como ella")
    AlfaRuta.Liberar()
  end
  ventana = Ct.Ventana()
  check(ventana and ventana:IsShown(), "el clic de Hoy no abrió nada (el bug de Toxic)")
  local st = Ct.Estado()
  check(st.fase == "preparando", "la ventana no empieza con su avance: " .. tostring(st.fase))
  check(dice(ventana, "Preparando tu ruta"), "la ventana no dice «Preparando tu ruta…»")
  check(Cr.Filtro() == "todas", "desde Hoy no volvió a «todas»: " .. tostring(Cr.Filtro()))
  -- Unos cuadros: el avance a medias.
  correr()
  Ct.PintarYa = pintarYa
  local midio = false
  for _, d in ipairs(dichos) do if d:find("Midiendo caminos… %d+ %%") then midio = true end end
  check(midio, "no dijo «Midiendo caminos… N %» mientras armaba: " .. table.concat(dichos, " / "))
  check(st.fase == "resumen", "no llegó al resumen: " .. tostring(st.fase) .. " / " .. tostring(st.grande) .. " / " .. tostring(st.linea))
  local info = st.info or {}
  check(info.misiones == 8, "no entraron las 8: " .. tostring(info.misiones))
  check(#(info.zonas or {}) == 3, "no son 3 zonas: " .. tostring(#(info.zonas or {})))
  check((info.segundos or 0) > 0 and (info.xp or 0) > 0, "el resumen no trae tiempo y XP")
  local texto = Ct.TextoResumen(info)
  check(texto:find("8 misiones", 1, true) and texto:find("3 zonas", 1, true) and texto:find("unos ", 1, true) and texto:find("XP", 1, true),
    "el resumen no dice «8 misiones · 3 zonas · unos N · +N XP»: " .. texto)
  check(dice(ventana, "8 misiones"), "la ventana no muestra el resumen")
  local despues = {}
  for _, d in ipairs(info.despues or {}) do despues[d.id] = d.por end
  check(despues[19] ~= nil, "la de grupo (19) no va en «Para después»")
  check(despues[20] ~= nil and despues[20]:find("24", 1, true), "la de nivel 24 no va en «Para después» con su porqué: " .. tostring(despues[20]))
  check(dice(ventana, K.Mayus("Para después")), "la ventana no muestra «Para después»")
  check(dice(ventana, "Empezar"), "falta «Empezar»")
  check(dice(ventana, "Quitar algunas"), "falta «Quitar algunas»")
  print("  resumen: " .. texto .. " · " .. tostring(st.linea))
  SNAP("resumen", ventana)
end)

---------------------------------------------------------------------------
-- 2. El mejor orden
---------------------------------------------------------------------------
step("El orden: cada zona de una vez y las entregas al final de su zona", function()
  local st = Ct.Estado()
  local def = st.def
  check(def and #def.steps >= 8, "el plan no tiene paradas")
  if not def then return end
  local vistas, antes = {}, nil
  local porZona = {}
  for i, paso in ipairs(def.steps) do
    local z = zonaDe(paso)
    if z and z ~= antes then
      check(not vistas[z], "el plan vuelve a una zona que ya dejó (" .. tostring(z) .. ") en la parada " .. i)
      vistas[z] = true
      antes = z
    end
    local entrega = false
    for _, g in ipairs(paso.goals) do if g.t == "turnin" then entrega = true end end
    porZona[z or 0] = porZona[z or 0] or {}
    local l = porZona[z or 0]
    l[#l + 1] = entrega and "T" or "O"
  end
  for z, l in pairs(porZona) do
    local s = table.concat(l)
    check(not s:find("TO", 1, true), "en la zona " .. tostring(z) .. " hay una entrega antes de lo que falta hacer: " .. s)
  end
  -- Juntar en uno lo que está en el mismo lugar.
  local junto = Cr.JuntarCercanos({
    { title = "A", goals = { { t = "kill", quest = 1, map = 1436, x = 50, y = 50 } } },
    { title = "B", goals = { { t = "collect", quest = 2, map = 1436, x = 50.5, y = 50.2 } } },
    { title = "C", goals = { { t = "turnin", quest = 1, map = 1436, x = 50.5, y = 50.2 } } },
  })
  check(#junto == 2 and junto[1].title:find("Junto aquí", 1, true), "no juntó dos objetivos en el mismo lugar: " .. #junto)
end)

---------------------------------------------------------------------------
-- 3. Sin la base de misiones y en combate
---------------------------------------------------------------------------
step("Sin la base de misiones: lo dice con «Reintentar»; en combate sigue sola", function()
  local I = Ru.Indice
  con(I, { CodexListo = function() return false, "missing" end }, function()
    Ct.Abrir({ origen = "hoy" })
    T(2)
    local st = Ct.Estado()
    check(st.fase == "error", "sin la base no dijo nada: " .. tostring(st.fase))
    check(st.linea == I.TextoMotivo("missing") and st.accion and st.accion.texto == "Reintentar", "no explica por qué ni ofrece «Reintentar»")
  end)
  local pelea = true
  con(_G, { InCombatLockdown = function() return pelea end }, function()
    Ct.Abrir({ origen = "hoy" })
    T(2)
    local st = Ct.Estado()
    check(st.fase == "espera" and dice(ventana, "En cuanto salgas de combate"), "en combate no dice que espera: " .. tostring(st.fase))
    pelea = false
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    T(3)
    correr()
    check(st.fase == "resumen", "al salir de combate no siguió sola: " .. tostring(st.fase))
  end)
end)

---------------------------------------------------------------------------
-- 4. Quitar algunas y los atajos
---------------------------------------------------------------------------
step("«Quitar algunas»: casillas marcadas de fábrica; quitar una rehace el resumen", function()
  local st = Ct.Estado()
  st.vista = "elegir"
  Ct.Pintar()
  check(dice(ventana, K.Mayus("Elige cuáles entran")), "«Quitar algunas» no muestra las casillas")
  SNAP("elegir", ventana)
  Ct.Alternar(52, false)
  T(2)
  correr()
  check(st.fase == "resumen" and st.info.misiones == 7 and #st.info.zonas == 2, "quitar la de Elwynn no rehízo el resumen: "
    .. tostring(st.info and st.info.misiones) .. " misiones, " .. tostring(st.info and #st.info.zonas) .. " zonas")
  Ct.Alternar(52, true)
  T(2)
  correr()
  check(st.info.misiones == 8, "volver a ponerla no la metió")
  st.vista = "paradas"
  -- El atajo «Solo listas» (ninguna lista): lo dice y ofrece «Con todas».
  Cr.SetFiltro("listas")
  Ct.Rehacer()
  correr()
  check(st.fase == "vacio" and st.accion and st.accion.texto == "Con todas", "con «Solo listas» y ninguna lista no dice qué hacer: " .. tostring(st.fase))
  st.accion.alClic()
  correr()
  check(st.fase == "resumen" and Cr.Filtro() == "todas", "«Con todas» no volvió a armar con todas")
end)

---------------------------------------------------------------------------
-- 5. Empezar: la flecha y el mapa
---------------------------------------------------------------------------
local capas = {}
step("«Empezar»: la ruta abierta, la flecha en la primera parada y la ruta en el mapa", function()
  local P = A.Pins
  local setReal = P.SetLayer
  P.SetLayer = function(n, p, o) capas[n] = p return setReal(n, p, o) end
  local st = Ct.Estado()
  local primera = st.paradas and st.paradas[1]
  check(Ct.Empezar(), "«Empezar» no instaló el plan")
  correr()
  local g = E.GetGuide()
  check(g and g.id == Ru.Guias.IdLiberar(), "no se abrió «Cerrar mis misiones»")
  check(not ventana:IsShown(), "la ventana sigue abierta al empezar")
  local wp = E.GetWaypoint and E.GetWaypoint()
  check(wp and wp.stepIndex == 1, "la flecha no apunta a la primera parada: " .. tostring(wp and wp.stepIndex))
  check(primera and E.GetStepView(1).title == primera.titulo, "la primera parada del resumen no es la del plan")
  check(Ct.Cuenta() and Ct.Cuenta().total == 8, "no empezó la cuenta del camino")
  T(2)
  local pines = capas["rutas.cerrarRuta"] or {}
  local numerados = 0
  for _, p in ipairs(pines) do if p.badge then numerados = numerados + 1 end end
  check(numerados >= 8, "la ruta no salió en el mapa con sus paradas numeradas: " .. numerados)
  check(#pines > numerados, "la ruta en el mapa no trae el camino en puntitos")
  -- El mapa de Alfa la registra como capa.
  local Mu = rawget(_G, "AlfaMundo")
  if type(Mu) == "table" and type(Mu.Capas) == "function" then
    local hay = false
    for _, c in ipairs(Mu.Capas()) do if c.id == "rutas.cerrarRuta" then hay = true end end
    check(hay, "la ruta no es una capa del mapa de Alfa")
    if type(Mu.Abrir) == "function" and FOTOS then
      -- El banco no trae las coordenadas del mundo: unas de mentira para los
      -- Reinos del Este (cada zona, un cuadro de 3000 yardas en su lugar).
      local mtw = A.Compat.MapToWorld
      A.Compat.MapToWorld = function(map, x, y, f)
        if map == 1415 then return 0, 8000 + (y / 100) * -20000, 9000 + (x / 100) * -14000 end
        local l, r, t, b = C_Map.GetMapRectOnMap(map, 1415)
        if l and r and t and b and x and y then
          local cx, cy = l + (r - l) * x / 100, t + (b - t) * y / 100
          return 0, 8000 + cy * -20000, 9000 + cx * -14000
        end
        return mtw(map, x, y, f)
      end
      Ct.PintarMapa(true)
      pcall(Mu.Abrir, 1436)
      T(3)
      local W = rawget(_G, "AlfaMundoMapa")
      for _, f in ipairs(ALL_FRAMES()) do
        if f:IsVisible() then
          for _, r in ipairs(rawget(f, "_children") or {}) do
            if r._kind == "FontString" and r._text == "Entendido" and f._scripts and f._scripts.OnClick then FIRE(f, "OnClick", "LeftButton") end
          end
        end
      end
      if W then for _ = 1, 4 do FIRE(W.Vista or W, "OnUpdate", 0.3) end end
      if W and W:IsShown() then SNAP("mapa", W) end
      if type(Mu.Cerrar) == "function" then pcall(Mu.Cerrar) end
      A.Compat.MapToWorld = mtw
      Ct.PintarMapa(true)
    end
  end
  P.SetLayer = setReal
end)

---------------------------------------------------------------------------
-- 6. Se rehace, «¡Lista! Sigue» y el festejo
---------------------------------------------------------------------------
step("Abandonar una del plan lo rehace solo", function()
  quitar(22)
  FIRE_EVENT("QUEST_REMOVED", 22)
  registro()
  check(not Cr.AlDia(), "abandonar una del plan no lo deja «sin estar al día»")
  T(5)
  correr()
  T(5)
  correr()
  local g = E.GetGuide()
  local sigue = false
  for _, s in ipairs(g and g.steps or {}) do
    for _, m in ipairs(s.goals) do if m.quest == 22 then sigue = true end end
  end
  check(not sigue, "el plan sigue con la que abandonaste")
  check(Cr.AlDia(), "el plan no quedó al día")
end)

step("Al entregar: «¡Lista! Sigue: X»; al cerrar la última, el festejo con la cuenta", function()
  avisos = {}
  poner(102, true)
  registro()
  quitar(102) HECHAS[102] = true
  FIRE_EVENT("QUEST_TURNED_IN", 102, 640, 0)
  FIRE_EVENT("QUEST_REMOVED", 102)
  registro()
  T(3)
  local a = avisoCon("¡Lista! Sigue")
  check(a ~= nil, "al entregar no dijo «¡Lista! Sigue: X»")
  check(a and tostring(a.texto):find("6 misiones", 1, true), "no dice cuántas faltan: " .. tostring(a and a.texto))
  check(Ct.Cuenta() and Ct.Cuenta().xp == 640 and Ct.Cuenta().n == 1, "la cuenta no sumó la entrega")
  -- Las demás.
  anuncios = {}
  local faltan = {}
  for _, q in ipairs(OCHO) do if LOG[q] then faltan[#faltan + 1] = q end end
  for _, q in ipairs(faltan) do
    quitar(q) HECHAS[q] = true
    FIRE_EVENT("QUEST_TURNED_IN", q, 500, 0)
    FIRE_EVENT("QUEST_REMOVED", q)
  end
  registro()
  T(4)
  local fin
  for _, o in ipairs(anuncios) do if o.clave == "rutas.cerrarFin" then fin = o end end
  check(fin ~= nil, "al cerrar la última no hubo festejo")
  check(fin and tostring(fin.texto):find("misiones cerradas", 1, true) and tostring(fin.texto):find("XP", 1, true),
    "el festejo no trae la cuenta: " .. tostring(fin and fin.texto))
  check(Ct.Cuenta() == nil, "la cuenta no se cerró")
  print("  festejo: " .. tostring(fin and fin.texto))
  -- De vuelta el registro para lo que sigue.
  for _, q in ipairs(OCHO) do HECHAS[q] = nil poner(q, false) end
  registro()
end)

---------------------------------------------------------------------------
-- 7. El mismo botón en todos lados
---------------------------------------------------------------------------
step("El mismo «Cerrar mis misiones» en el menú de Alfa, el rastreador y el Escritorio", function()
  local O = A.UI and A.UI.Options or nil
  local Opt = rawget(_G, "AlfaOpciones") or O
  local items
  local okM = pcall(function()
    local mod = A.Options or (A.UI and A.UI.Options)
    if mod and mod.MenuItems then items = mod.MenuItems(UIParent) end
  end)
  if okM and items then
    local hay = false
    for _, it in ipairs(items) do if it.text == "Cerrar mis misiones" then hay = true end end
    check(hay, "el menú de Alfa no tiene «Cerrar mis misiones»")
  else
    print("AVISO: no encontré O.MenuItems en el banco")
  end
  -- El del rastreador y el de AlfaRuta abren la misma ventana.
  if ventana then ventana:Cerrar() end
  AlfaRuta.CerrarTodo("escritorio")
  check(ventana:IsShown() and Ct.Estado().opts.origen == "escritorio", "AlfaRuta.CerrarTodo no abrió el resumen")
  correr()
  ventana:Cerrar()
  Ru.Cerrar.Ahora()
  check(ventana:IsShown(), "el «Cerrar mis misiones» del rastreador no abre el mismo resumen")
  correr()
  ventana:Cerrar()
  -- Un filtro dado («Una hora de caza») sigue directo, sin resumen.
  check(type(AlfaRuta.TextoCerrar) == "function" and AlfaRuta.TextoCerrar() == "Cerrar mis misiones", "falta AlfaRuta.TextoCerrar")
end)

---------------------------------------------------------------------------
-- 8. Registro lleno, en común, el objeto y por qué no
---------------------------------------------------------------------------
step("Registro casi lleno: avisa y sugiere cuáles soltar", function()
  local Di = Ru.Diario
  check(Di and Di.Revisar, "falta Diario.lua")
  avisos = {}
  con(QL, { GetMaxNumQuestsCanAccept = function() return #ORDEN + 1 end }, function()
    check(Di.Tope() == #ORDEN + 1, "no lee el tope del registro")
    poner(127, false)
    FIRE_EVENT("QUEST_ACCEPTED", 127)
    T(3)
    local a = avisoCon("Tu registro va")
    check(a ~= nil and a.accion and a.accion.texto == "Ver cuáles", "con el registro casi lleno no avisó")
    local lista
    Di.Sugerencias(function(l) lista = l end)
    correr()
    check(type(lista) == "table" and #lista > 0, "no sugirió cuáles soltar")
    for _, d in ipairs(lista or {}) do
      check(type(d.por) == "string" and d.por ~= "", "una sugerencia sin su porqué")
      check(not (LOG[d.qid] and LOG[d.qid].listo), "sugirió soltar una lista para entregar")
    end
    check(Di.Abrir(), "«Ver cuáles» no abrió la ventana")
    correr()
    local v = rawget(_G, "AlfaRutasDiario")
    if v and v:IsShown() then SNAP("diario", v) v:Hide() end
    quitar(127)
  end)
end)

step("En común con tu grupo: «¿armamos la ruta juntos?»", function()
  local RG = Ru.RutaGrupo
  if RG.Reiniciar then RG.Reiniciar() end
  con(_G, { IsInGroup = function() return true end, IsInRaid = function() return false end, GetNumGroupMembers = function() return 2 end,
    UnitExists = function(u) return u == "player" or u == "party1" end,
    UnitName = function(u) if u == "party1" then return "Yuki" end return "Lobato" end }, function()
    con(A, { Party = { Members = function() return { { name = "Yuki", quests = { [92] = {}, [122] = {}, [125] = {}, [99901] = {} } } } end } }, function()
      local c = RG.EnComun()
      check(#c == 1 and c[1].nombre == "Yuki" and #c[1].ids == 3, "no vio las 3 en común con Yuki")
      local d = RG.Aviso()
      check(d and d.titulo == "Yuki y tú tienen 3 misiones en común" and d.uno and d.uno[1] == "Armar la ruta juntos",
        "el rastreador no ofrece armar la ruta juntos: " .. tostring(d and d.titulo))
      if d and d.uno then d.uno[2]() end
      correr()
      local st = Ct.Estado()
      check(st.fase == "resumen" and st.info.misiones == 3, "la ruta juntos no trae solo las 3 en común: " .. tostring(st.info and st.info.misiones))
      check(st.opts.solo and Cr.Filtro() == "todas", "la ruta juntos cambió tu atajo")
      ventana:Cerrar()
      local d2 = RG.Aviso()
      check(not (d2 and d2.titulo and d2.titulo:find("en común", 1, true)), "ya armada, la sugerencia vuelve")
    end)
  end)
end)

step("El objeto de misión en el rastreador, cerca de su objetivo", function()
  local Ob = Ru.Objeto
  local b = rawget(_G, "AlfaQuestItemButton")
  if not b then b = CreateFrame("Button", "AlfaQuestItemButton", UIParent) end
  b.itemID = 5051
  b:Show()
  b.tint = "far"
  check(not Ob.Cerca(), "lejos de su objetivo dice que estás cerca")
  b.tint = "near"
  check(Ob.Cerca(), "cerca de su objetivo no lo nota")
end)

step("¿Por qué no puedo tomarla? (la cadena)", function()
  local Ca = Ru.Cadena
  local D = Ru.Disp
  con(D, { Estado = function() return false, "nivel", { nivel = 30 } end }, function()
    local t = Ca.PorQueNo({ lista = { { qid = 1, titulo = "Una", estado = "hecha" }, { qid = 2, titulo = "Otra", estado = "falta", siguiente = true } } })
    check(t:find("Para tomar «Otra»", 1, true) and t:find("30", 1, true), "la cadena no dice qué te falta: " .. t)
  end)
end)

---------------------------------------------------------------------------
-- 9. El rastreador
---------------------------------------------------------------------------
step("Rastreador: lo esencial, el mismo menú y el tiempo", function()
  Ct.Abrir({ origen = "hoy" })
  correr()
  Ct.Empezar()
  correr()
  Rs.Mostrar()
  T(2)
  local F = rawget(_G, "AlfaRastreador")
  Rs.Encima(false) T(2)
  Rs.Pintar()
  local function pie()
    for _, h in ipairs({ F:GetChildren() }) do
      if h:IsShown() and dice(h, "Ver detalle") then return true end
    end
    return false
  end
  check(not pie(), "de fábrica el rastreador muestra el pie (no solo lo esencial)")
  SNAP("rastreador-esencial", F)
  Rs.Encima(true)
  Rs.Pintar()
  check(pie(), "con el ratón encima no muestra el pie")
  SNAP("rastreador-encima", F)
  Rs.Encima(false) T(2)
  -- El menú de una meta, siempre en el mismo orden.
  local menu
  con(K, { Menu = function(_, op) menu = op end }, function()
    local fila = CreateFrame("Button", nil, UIParent)
    fila.alfaMeta = { quest = 92, t = "kill", status = "active", index = 1, title = "Misión 92" }
    fila.alfaPaso = 1
    Rs.MenuMeta(fila)
  end)
  local orden = {}
  for i = 1, 4 do orden[i] = menu and menu[i] and menu[i].texto or "-" end
  check(table.concat(orden, "|") == "Llévame|Omitir esta misión|Ver el camino en el mapa|Abandonar misión",
    "el menú no va en el orden de siempre: " .. table.concat(orden, "|"))
  check(menu and menu[5] and menu[5].separador, "lo demás no va debajo de una línea")
  -- El tiempo, con el formato de la flecha.
  check(Rs.Tiempo(80) == "1 min 20 s", "80 s: " .. tostring(Rs.Tiempo(80)))
  check(Rs.Tiempo(725) == "12 min", "725 s: " .. tostring(Rs.Tiempo(725)))
  check(AlfaRuta.Tiempo(45) == "45 s", "AlfaRuta.Tiempo(45): " .. tostring(AlfaRuta.Tiempo(45)))
end)

---------------------------------------------------------------------------
-- 10. Restablecer una guía y empezar desde un paso (pedido de Toxic)
---------------------------------------------------------------------------
step("Restablecer la guía de minería (omitida de más) y empezar desde el paso 5, con Deshacer", function()
  local Rb = Ru.Restablecer
  check(Rb and Rb.Restablecer and Rb.EmpezarDesde and Rb.Deshacer, "falta Restablecer.lua")
  local rango = 30
  local Cp = A.Compat
  local rankReal = Cp.GetSkillRank
  Cp.GetSkillRank = function(l) if l == 186 or l == "Minería" then return rango end return rankReal and rankReal(l) or nil end
  local function hasta(n) return { title = "Minería hasta " .. n, goals = { { t = "skill", skill = "Minería", skillLine = 186, level = n } } } end
  local id = Ru.Guias.IdEspecial("recoger")
  local def = Ru.Guias.Def(id, "Minería de prueba", {
    { title = "Aprende Minería", goals = { { t = "talk", npc = 1681, npcName = "Instructor de minería", map = 1436, x = 50, y = 50 } } },
    hasta(50), hasta(75), hasta(100), hasta(125), hasta(150), hasta(175),
  })
  check(Ru.Guias.Instalar(def), "no se instaló la guía de minería de prueba")
  Ru.Guias.Abrir(id) T(3)
  local g = E.GetGuide()
  check(g and g.id == id, "no se abrió la guía de minería de prueba")
  check(E.GetLiveStep() == 1, "la guía no empieza en el paso 1: " .. tostring(E.GetLiveStep()))
  -- Por error, omite de más: hasta el paso 7.
  for _ = 1, 6 do E.Skip() T(1) end
  check(E.GetLiveStep() == 7, "omitir 6 pasos no dejó la guía en el 7: " .. tostring(E.GetLiveStep()))
  -- Sube a 120 de habilidad y restablece: queda en «Minería hasta 125» (el 5).
  rango = 120
  avisos = {}
  local dialogo
  con(K, { Dialogo = function(o) dialogo = o end }, function() Rb.Restablecer() end)
  check(dialogo and dialogo.alAceptar, "restablecer no pide confirmación")
  if dialogo then dialogo.alAceptar() end
  T(2)
  check(E.GetLiveStep() == 5, "restablecida con habilidad 120 no quedó en el paso de 125 (el 5): " .. tostring(E.GetLiveStep()))
  check(not E.GetStepView(6).skipped, "el paso 6 sigue omitido tras restablecer")
  local a = avisoCon("Restableciste")
  check(a and a.accion and a.accion.texto == "Deshacer", "restablecer no ofrece «Deshacer»")
  check(Rb.Detectar() == 4, "no detectó el 4 como el último hecho: " .. tostring(Rb.Detectar()))
  -- Deshacer: vuelve como estaba (en el 7).
  check(Rb.Deshacer(), "no se pudo deshacer")
  T(2)
  check(E.GetLiveStep() == 7, "deshacer no volvió al paso 7: " .. tostring(E.GetLiveStep()))
  -- Empezar desde el paso 5 (atrás, con los de después omitidos).
  check(Rb.EmpezarDesde(5, true), "«Empezar desde este paso» no hizo nada")
  T(2)
  check(E.GetLiveStep() == 5, "no siguió desde el paso 5: " .. tostring(E.GetLiveStep()))
  -- Y adelante: desde el 7 (los de antes quedan omitidos, sin borrar lo hecho).
  check(Rb.EmpezarDesde(7, true), "empezar desde el 7 no hizo nada")
  T(2)
  check(E.GetLiveStep() == 7 and E.GetStepView(5).skipped, "empezar desde el 7 no omitió el 5 y el 6: " .. tostring(E.GetLiveStep()))
  check(Rb.Deshacer(), "no se pudo deshacer empezar desde el 7")
  T(2)
  check(E.GetLiveStep() == 5, "deshacer no volvió al paso 5: " .. tostring(E.GetLiveStep()))
  -- En los menús: el de la guía y el de un paso.
  local menu
  con(K, { Menu = function(_, op) menu = op end }, function()
    local fila = CreateFrame("Button", nil, UIParent)
    fila.alfaMeta = { t = "skill", status = "active", index = 1, title = "Minería" }
    fila.alfaPaso = 6
    Rs.MenuMeta(fila)
  end)
  local hay = false
  for _, o in ipairs(menu or {}) do if o.texto == "Empezar desde este paso" then hay = true end end
  check(hay, "el clic derecho de un paso no trae «Empezar desde este paso»")
  Cp.GetSkillRank = rankReal
end)

print(("1.3.9 misiones: %d pasos, %d errores"):format(pasos, #ERRORS))
