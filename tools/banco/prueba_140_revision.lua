-- Prueba de la 1.4.0, revisión independiente (docs: REVISION-1.4.0.md). Los 8
-- arreglos, cada uno con lo suyo:
--   1. Una guía cuyo paquete de pasos falta (o está apagado): el paso de
--      relleno no toca nada del avance guardado. Sola: con un avance sembrado.
--      Con BANCO_FASE (tools/prueba.py, 3 corridas con las mismas variables
--      guardadas): «a» abre la guía y anota avance; «b» entra sin su paquete;
--      «c» lo vuelve a poner: el avance sigue igual en las dos.
--   2. «Faltan partes» y «Activar módulo» conocen las carpetas nuevas; si falta
--      el paquete de tu facción no se carga el de la otra.
--   3. Nada pesado en combate: el Codex por partes y los pasos de una guía que
--      no sigues esperan al fin del combate; un fallo en combate no se reintenta.
--   4. Semana de la subasta: dos ventas iguales se anotan las dos.
--   5. Dos pantallas: lo de antes se renueva al empezar y respeta tus cambios.
--   6. La flecha subida encima de una ventana de Alfa no toma el ratón.
--   7. La X y el menú de los paneles de Dos pantallas sin ratón mientras no se ven.
--   8. Curación: Restablecer también olvida las medidas por situación.
local FASE = os and os.getenv and os.getenv("BANCO_FASE") or "sola"
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  else
    print("bien: " .. nombre)
  end
end
local function check(cond, msg) if not cond then NOTE("1.4.0 revisión", msg) end end

local A = Alfa
local ns = NS_OF("Alfa")
local G, E = A.Guides, A.Engine

-- Una guía de subir de nivel de la Horda cuyos pasos viven en `parte`.
local function guiaDe(parte)
  for _, h in ipairs(G.List() or {}) do
    local g = G.Get(h.id)
    if g and rawget(g, "stepsPart") == parte and (g.category == nil or g.category == "Leveling") then return h.id, g end
  end
end
local function guiaConEstrella(parte)
  for _, h in ipairs(G.List() or {}) do
    local g = G.Get(h.id)
    local p = g and rawget(g, "stepsPart")
    if type(p) == "string" and p:find("*", 1, true) and p:gsub("%*", "Horde") == parte then return h.id, g end
  end
end

-- Lo que el motor guarda de una guía (todo lo que el relleno no debe tocar).
local CAMPOS = { "manual", "skipped", "when", "pins", "shapes", "stepKeys", "shapeVersions", "ownShapes", "skipStored", "lostQuests", "guideEnds" }
local function copia(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = copia(x) end
  return t
end
local function foto(id)
  local s = ns.CharState()
  local out = {}
  for _, c in ipairs(CAMPOS) do out[c] = copia(type(s[c]) == "table" and s[c][id] or nil) end
  return out
end
local function igual(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not igual(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
local function difiere(a, b)
  local out = {}
  for _, c in ipairs(CAMPOS) do if not igual(a[c], b[c]) then out[#out + 1] = c end end
  return table.concat(out, ", ")
end
local function abierta(id)
  for i, t in ipairs(E.GetTabs() or {}) do if t.guideId == id then return i end end
end
local function entrar()
  FIRE_EVENT("PLAYER_LOGIN")
  FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
  RUN_TIMERS(6)
end

---------------------------------------------------------------------------
-- 1 en tres corridas (tools/prueba.py): el avance de verdad, ida y vuelta.
---------------------------------------------------------------------------
if FASE ~= "sola" then
  local PARTE = "Alfa_Guides_Horde_Pasos2"
  local id, g = guiaDe(PARTE)
  check(id ~= nil, "no hay guía de subir de nivel en " .. PARTE)
  if FASE == "b" then BANCO_SIN_ADDON[PARTE] = "falta" end
  local s = ns.CharState()
  local guardado = type(s.alfaPruebaRevision) == "table" and s.alfaPruebaRevision or nil
  entrar()
  step("1 (fase " .. FASE .. "): el avance de una guía sin su paquete", function()
    if not id then return end
    if FASE == "a" then
      local i = abierta(id) or E.OpenTab(id, true)
      check(i ~= nil, "no se abrió " .. id)
      RUN_TIMERS(2)
      local st = ns.CharState()
      -- Avance: una palomita a mano, un paso omitido y la vista en otro paso.
      st.manual[id] = st.manual[id] or {}
      st.manual[id]["3:1"] = true
      st.skipped[id] = st.skipped[id] or {}
      st.skipped[id][2] = true
      E.SelectTab(abierta(id) or 1)
      RUN_TIMERS(3)
      local f = foto(id)
      check(f.shapes ~= nil and type(f.stepKeys) == "table" and #f.stepKeys == g.stepCount, "no se guardó la forma de la guía")
      check(f.manual and f.manual["3:1"] and f.skipped and f.skipped[2], "no quedó el avance anotado")
      st.alfaPruebaRevision = { id = id, foto = f }
      print(("  %s: %d pasos, avance anotado"):format(id, g.stepCount))
      return
    end
    check(guardado and guardado.id == id, "la fase a no dejó lo suyo")
    if not guardado then return end
    check(abierta(id) ~= nil, "la pestaña de " .. id .. " no volvió")
    local i = abierta(id)
    if i then E.SelectTab(i) end
    RUN_TIMERS(3)
    local gg = G.Get(id)
    if FASE == "b" then
      check(not LOADED[PARTE], "se cargó el paquete que falta")
      check(G.FaltanPasos(gg) == "falta", "la guía no enseña el relleno marcado: " .. tostring(G.FaltanPasos(gg)))
      check(#gg.steps == 1, "el relleno no es un solo paso")
      local falt = A.Data.CheckInstall()
      local esta = false
      for _, n in ipairs(falt) do if n == PARTE then esta = true end end
      check(esta, "el chequeo de la instalación no dice que falta " .. PARTE)
    else
      check(LOADED[PARTE], "con el paquete de vuelta no se cargó")
      check(G.FaltanPasos(gg) == nil and #gg.steps >= g.stepCount, "con el paquete de vuelta la guía no tiene sus pasos")
    end
    local f = foto(id)
    local d = difiere(guardado.foto, f)
    check(d == "", "fase " .. FASE .. ": cambió lo guardado de la guía: " .. d)
    print(("  fase %s: el avance de %s sigue igual"):format(FASE, id))
  end)
  print(("PRUEBA: revisión 1.4.0 (fase %s), %d pasos, errores: %d"):format(FASE, pasos, #ERRORS))
  return
end

---------------------------------------------------------------------------
-- Sola: antes de entrar, una instalación a medias.
---------------------------------------------------------------------------
local FALTA = "Alfa_Guides_Horde_Pasos3"
BANCO_SIN_ADDON[FALTA] = "falta"
BANCO_SIN_ADDON["Alfa_Codex_Mundo"] = "falta"
local idFalta = guiaDe(FALTA)
local sembrado
do
  -- Un avance guardado de la sesión anterior, con su forma (la de los pasos de
  -- verdad, que este relleno no tiene).
  local s = ns.CharState()
  if idFalta then
    s.tabs = { idFalta }
    s.activeTab = 1
    s.shapes = { [idFalta] = "45-123456" }
    s.stepKeys = { [idFalta] = { 11, 22, 33, 44, 55, 66 } }
    s.shapeVersions = { [idFalta] = "1.4.0" }
    s.ownShapes = { [idFalta] = "45-123456" }
    s.manual[idFalta] = { ["3:1"] = true, ["5:2"] = true }
    s.skipped[idFalta] = { [2] = true, [4] = true }
    s.when[idFalta] = { [6] = true }
    s.pins = { [idFalta] = { step = 5, done = false } }
    sembrado = foto(idFalta)
  end
end
-- Se entra en combate (un /reload a media pelea): nada pesado se carga.
local cargas = {}
local loadOrig = C_AddOns.LoadAddOn
C_AddOns.LoadAddOn = function(n, ...) cargas[#cargas + 1] = n return loadOrig(n, ...) end
local function cargo(n) for _, x in ipairs(cargas) do if x == n then return true end end return false end
local combate = true
local icl = InCombatLockdown
InCombatLockdown = function() return combate end
entrar()
local cargadasEnCombate = {}
for _, n in ipairs(cargas) do cargadasEnCombate[#cargadasEnCombate + 1] = n end

step("1: la guía sin su paquete no borra el avance guardado", function()
  check(idFalta ~= nil, "no hay guía en " .. FALTA)
  if not idFalta then return end
  local i = abierta(idFalta)
  check(i ~= nil, "la pestaña guardada no volvió")
  if i then E.SelectTab(i) end
  RUN_TIMERS(3)
  local g = G.Get(idFalta)
  check(G.FaltanPasos(g) ~= nil, "sin paquete, la guía no trae el relleno marcado")
  check(rawget(g, "steps") == nil, "el relleno se guardó como pasos")
  -- Todo lo guardado sigue (antes: se borraban palomitas, omitidos y la vista).
  local d = difiere(sembrado, foto(idFalta))
  check(d == "", "el relleno cambió lo guardado: " .. d)
  -- Y ninguna caché se queda con la forma del relleno.
  local otra = G.FaltanPasos(G.Get(idFalta)) and #G.Get(idFalta).steps
  check(otra == 1, "el relleno no se vuelve a pedir")
end)

---------------------------------------------------------------------------
-- 2. La instalación a medias, dicha
---------------------------------------------------------------------------
step("2: «Faltan partes» y «Activar módulo» con las carpetas nuevas", function()
  local falt = A.Data.CheckInstall()
  local hay = {}
  for _, n in ipairs(falt) do hay[n] = true end
  check(hay[FALTA], "el chequeo al entrar no dice que falta " .. FALTA)
  check(hay["Alfa_Codex_Mundo"], "el chequeo al entrar no dice que falta Alfa_Codex_Mundo")
  check(not hay["Alfa_Guides_Horde_Pasos1"] and not hay["Alfa_Codex_Objetos"], "dice que falta algo que sí está")
  check(not hay["Alfa_Guides_Alliance_Pasos1"], "pide los pasos de la otra facción")
  local Bv = NS_OF("Alfa_Bienvenida")
  local Dg = Bv.Diagnostico
  BANCO_SIN_ADDON["Alfa_Guides_Pasos"] = "apagado"
  local faltan, apagadas
  for _, r in ipairs(Dg.Revisar()) do
    if r.id == "partes.faltan" then faltan = r end
    if r.id == "partes.apagadas" then apagadas = r end
  end
  check(faltan and faltan.texto:find(FALTA, 1, true) and faltan.texto:find("Alfa_Codex_Mundo", 1, true), "«Revisar Alfa» no dice qué partes faltan")
  check(apagadas and apagadas.texto:find("Alfa_Guides_Pasos", 1, true) and apagadas.arreglo, "«Revisar Alfa» no ofrece activar Alfa_Guides_Pasos apagado")
  BANCO_SIN_ADDON["Alfa_Guides_Pasos"] = nil
  -- Sin el paquete de tu facción, nada de la otra.
  local idE, gE = guiaConEstrella(FALTA)
  if idE then
    local _ = gE.steps
    check(G.FaltanPasos(gE) ~= nil, "una guía de clase sin su paquete no trae el relleno")
    check(not LOADED["Alfa_Guides_Alliance_Pasos3"] and not LOADED["Alfa_Guides_Alliance"], "sin tu paquete se cargó el de la otra facción")
  else
    print("  (no hay guía de clase con «*» en el tramo 3)")
  end
end)

---------------------------------------------------------------------------
-- 3. En combate, nada pesado
---------------------------------------------------------------------------

step("3: los pasos de una guía que no sigues esperan al fin del combate", function()
  local PARTE = "Alfa_Guides_Horde_Pasos2"
  local id, g = guiaDe(PARTE)
  check(id ~= nil and not LOADED[PARTE], "en combate se cargó " .. PARTE .. " al entrar (no es de la guía que sigues)")
  if not id or LOADED[PARTE] then return end
  combate = true
  cargas = {}
  local s = g.steps
  check(G.FaltanPasos(g) == "combate" and #s == 1, "en combate se leyeron los pasos de una guía que no sigues")
  check(not cargo(PARTE) and not LOADED[PARTE], "en combate se cargó " .. PARTE)
  check(s[1].goals[1].text:find("combate", 1, true), "el relleno no dice que espera al combate: " .. tostring(s[1].goals[1].text))
  -- La que pide el jugador (un clic en Alfa), sí, aunque sea en combate.
  local N = AlfaNucleo
  local pidio = N.PidioJugador
  N.PidioJugador = function() return true end
  local s2 = g.steps
  N.PidioJugador = pidio
  check(LOADED[PARTE] and #s2 == g.stepCount, "en combate no se leyó la guía que pidió el jugador")
end)

step("3: el Codex por partes no se carga en combate", function()
  local C = A.Codex
  C.Load()
  check(C.IsLoaded(), "el núcleo del Codex no cargó")
  for _, n in ipairs(cargadasEnCombate) do
    check(not n:find("Codex_", 1, true), "al entrar en combate se cargó " .. n)
  end
  check(not LOADED["Alfa_Codex_Objetos"], "en combate se cargó la parte de objetos al entrar")
  cargas = {}
  check(C.Item(2589) == nil, "en combate el Codex leyó un objeto de una parte sin cargar")
  check(C.Item(2589) == nil and C.Item(2592) == nil, "en combate respondió")
  check(not cargo("Alfa_Codex_Objetos") and not LOADED["Alfa_Codex_Objetos"], "en combate se cargó la parte de objetos")
  local pedidas = table.concat(C.PartsWanted(), ",")
  check(pedidas:find("Alfa_Codex_Objetos", 1, true), "no anotó la parte pedida en combate: " .. pedidas)
  local avisado = 0
  local quitar = A.On and A.On("CODEX_LOADED", function() avisado = avisado + 1 end)
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  RUN_TIMERS(2)
  check(LOADED["Alfa_Codex_Objetos"], "al salir de combate no se cargó lo pedido")
  check(avisado > 0, "al cargar lo pedido no avisó (CODEX_LOADED)")
  local it = C.Item(2589)
  check(it and it.name, "después del combate el objeto no se lee")
  -- Precargar (al abrir el Buscador o Mazmorras): fuera de combate, ya; la
  -- parte que falta (Mundo) no rompe nada.
  check(C.Preload({ "item" }) == true, "Preload de objetos no dio que está")
  check(C.Preload({ "npc" }) == false, "Preload dio por cargada la parte que falta")
end)

step("3: un fallo al cargar en combate no se reintenta en cada lectura", function()
  local PARTE = "Alfa_Guides_Pasos"
  local id, g
  for _, h in ipairs(G.List() or {}) do
    local x = G.Get(h.id)
    if x and rawget(x, "stepsPart") == PARTE and rawget(x, "steps") == nil then id, g = h.id, x break end
  end
  check(id ~= nil and not LOADED[PARTE], "no hay guía de " .. PARTE .. " sin cargar")
  if not id or LOADED[PARTE] then return end
  BANCO_SIN_ADDON[PARTE] = "apagado"
  local N = AlfaNucleo
  local pidio = N.PidioJugador
  N.PidioJugador = function() return true end
  combate = true
  cargas = {}
  local _ = g.steps
  local primera = #cargas
  _ = g.steps
  _ = g.steps
  check(primera == 1 and #cargas == 1, "en combate se reintentó la carga en cada lectura: " .. #cargas)
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  N.PidioJugador = pidio
  BANCO_SIN_ADDON[PARTE] = nil
  local s = g.steps
  check(LOADED[PARTE] and #s == g.stepCount, "al salir de combate no se volvió a intentar")
  -- Fuera de combate la guía cuyo paquete falta lo dice (y su avance sigue).
  if idFalta then
    local i = abierta(idFalta)
    if i then E.SelectTab(i) end
    RUN_TIMERS(3)
    check(G.FaltanPasos(G.Get(idFalta)) == "falta", "fuera de combate la guía sin paquete no dice que falta")
    local d = difiere(sembrado, foto(idFalta))
    check(d == "", "después del combate el relleno cambió lo guardado: " .. d)
  end
end)
C_AddOns.LoadAddOn = loadOrig
InCombatLockdown = icl

---------------------------------------------------------------------------
-- 4. Semana de la subasta
---------------------------------------------------------------------------
step("4: dos ventas iguales tomadas desde arriba se anotan las dos", function()
  local M = NS_OF("Alfa_Comercio")
  check(M and M.RevisarCarta and M.Semana, "falta Comercio (RevisarCarta / Semana)")
  if not (M and M.RevisarCarta) then return end
  local buzon = {
    { "seller", "Paño de lino", nil, 100, nil, nil, 5, nil, nil, nil, 20 },
    { "seller", "Paño de lino", nil, 100, nil, nil, 5, nil, nil, nil, 20 },
    { "seller", "Paño de lana", nil, 300, nil, nil, 15, nil, nil, nil, 10 },
  }
  local gInv, gNum = rawget(_G, "GetInboxInvoiceInfo"), rawget(_G, "GetInboxNumItems")
  GetInboxInvoiceInfo = function(i) local c = buzon[i] if not c then return nil end return unpack(c, 1, 11) end
  GetInboxNumItems = function() return #buzon, #buzon end
  local antes = M.Semana(7).ventas
  FIRE_EVENT("MAIL_SHOW")
  -- Tomar la carta 1 (dos clics seguidos: una sola venta), luego el servidor la quita.
  local function tomar()
    M.RevisarCarta(1)
    M.RevisarCarta(1)
    table.remove(buzon, 1)
    FIRE_EVENT("MAIL_INBOX_UPDATE")
  end
  tomar()
  tomar()
  tomar()
  local despues = M.Semana(7).ventas
  check(despues - antes == 3, "de 3 ventas (2 iguales) se anotaron " .. (despues - antes))
  GetInboxInvoiceInfo, GetInboxNumItems = gInv, gNum
end)

---------------------------------------------------------------------------
-- 5. Dos pantallas: lo de antes
---------------------------------------------------------------------------
step("5: lo de antes se renueva al empezar y respeta lo que cambias", function()
  local Bv = NS_OF("Alfa_Bienvenida")
  local Rp, Es = Bv.EscritorioReparar, Bv.Escritorio
  local N = AlfaNucleo
  local d = N.Datos("pantallas")
  local cv = { gxWindow = "1", gxMaximize = "1", gxWindowedResolution = "1920x1080", gxFullscreenResolution = "auto",
    gxMonitor = "0", useUiScale = "1", uiScale = "0.9" }
  local gc, sc = GetCVar, SetCVar
  GetCVar = function(n) return cv[n] end
  SetCVar = function(n, v) cv[n] = tostring(v) end
  -- Una foto vieja de una vuelta que no quedó exacta.
  d.antes = { cvars = { gxWindow = "1", gxMaximize = "0", gxWindowedResolution = "1280x720", useUiScale = "1", uiScale = "0.7" }, w = 1280, h = 720, escala = 0.7 }
  d.verificar, d.auto = nil, nil
  local f = Rp.Guardar()
  check(f.cvars.uiScale == "0.9" and f.cvars.gxMaximize == "1", "al empezar se quedó la foto vieja: " .. tostring(f.cvars.uiScale))
  -- Con una vuelta pendiente sin verificar, lo guardado manda.
  local vieja = { cvars = { uiScale = "0.7" }, escala = 0.7 }
  d.antes, d.verificar = vieja, { foto = vieja }
  check(Rp.Guardar() == vieja, "con una vuelta pendiente se renovó lo de antes")
  d.verificar = nil
  -- Mientras usas Dos pantallas cambias la escala: se respeta.
  d.antes = Rp.Foto()
  local aplicado = Es.Aplicado
  Es.Aplicado = function() return {} end
  NOW = NOW + 60 -- (lo que hizo Alfa hace rato ya no cuenta)
  check(not Rp.EsPropio(), "un cambio viejo de Alfa sigue contando como suyo")
  cv.uiScale = "1.1"
  FIRE_EVENT("CVAR_UPDATE", "uiScale", "1.1")
  check(d.antes.cvars.uiScale == "1.1", "tu cambio de escala no pasó a lo de antes: " .. tostring(d.antes.cvars.uiScale))
  -- Lo que cambia Alfa no cuenta.
  Rp.MarcarPropio()
  cv.uiScale = "0.5"
  FIRE_EVENT("CVAR_UPDATE", "uiScale", "0.5")
  check(d.antes.cvars.uiScale == "1.1", "un cambio de Alfa pasó por tuyo")
  Es.Aplicado = aplicado
  -- Una vuelta correcta lo olvida.
  cv.uiScale = "1.1"
  d.verificar = { foto = d.antes, intentos = 1 }
  NOW = NOW + 60
  Rp.Verificar()
  check(d.antes == nil and d.verificar == nil, "tras una vuelta correcta lo de antes se quedó")
  GetCVar, SetCVar = gc, sc
end)

---------------------------------------------------------------------------
-- 6. La flecha encima de una ventana de Alfa
---------------------------------------------------------------------------
step("6: la flecha subida encima de una ventana no toma el ratón", function()
  local Nav = A.Nav
  local Arrow = Nav and Nav.arrow
  check(Arrow and Arrow.EvitarVentanas and Arrow.TomaRaton, "falta Arrow.TomaRaton")
  if not (Arrow and Arrow.TomaRaton) then return end
  local function con(t, campos, fn)
    local antes = {}
    for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
    local ok, e = pcall(fn)
    for k, a in pairs(antes) do t[k] = a.v end
    if not ok then error(e) end
  end
  local T = { label = "Consigue Mena de estaño de Filón de estaño", map = 1413, x = 50, y = 50 }
  local v = CreateFrame("Frame", "AlfaPruebaVentanaRevision", UIParent)
  v:SetFrameStrata("HIGH")
  v:SetSize(320, 300)
  v:SetPoint("TOPLEFT", UIParent, "TOP", 40, -150)
  v:Show()
  Nav.VentanasDeAlfa[#Nav.VentanasDeAlfa + 1] = v
  A.Set("nav.arrowPos", nil)
  con(Nav, { Sample = function() return "travel", 892, 0.3 end, GetTarget = function() return T end,
    TomTomArrowGuides = function() return false end, HandedOff = function() return false end,
    HiddenWithGuide = function() return false end }, function()
    con(A, { ArrowHidden = function() return false end }, function()
      Arrow:OnTarget(T)
      Arrow:Refresh()
      v:Hide()
      Arrow.EvitarVentanas()
      check(Arrow.TomaRaton() == true, "sin ventana encima la flecha no toma el ratón")
      v:Show()
      Arrow.EvitarVentanas()
      local cual = Arrow.Encima()
      check(cual == "AlfaPruebaVentanaRevision", "la flecha no subió encima de la ventana: " .. tostring(cual))
      local toma, quiere = Arrow.TomaRaton()
      check(toma == false, "encima de la ventana la flecha sigue tomando el ratón")
      -- Lo que pida la flecha mientras está encima se recuerda para cuando baje.
      Arrow.frame:EnableMouse(true)
      check(Arrow.TomaRaton() == false, "un EnableMouse de la flecha le devolvió el ratón encima de la ventana")
      v:Hide()
      Arrow.EvitarVentanas()
      check(Arrow.TomaRaton() == true, "al quitarse la ventana la flecha no volvió a tomar el ratón")
      Arrow:OnTarget(nil)
      Arrow.frame:Hide()
    end)
  end)
end)

---------------------------------------------------------------------------
-- 7. La cabecera de los paneles de Dos pantallas
---------------------------------------------------------------------------
step("7: la X y el menú invisibles no toman el ratón", function()
  local Bv = NS_OF("Alfa_Bienvenida")
  local Es = Bv.Escritorio
  check(Es and Es.BotonesCabecera, "falta Es.BotonesCabecera")
  if not (Es and Es.Aplicar) then return end
  Es.Aplicar()
  RUN_TIMERS(2)
  local p
  for _, x in pairs(Es.Marcos or {}) do if x.Cab and x:IsShown() then p = x break end end
  check(p ~= nil, "no hay paneles en el escritorio")
  if p then
    local c = p.Cab
    p.IsMouseOver = function() return false end
    Es.RevisarRaton()
    check(c.Cerrar:GetAlpha() == 0 and not c.Cerrar:IsMouseEnabled(), "la X invisible toma el ratón")
    check(c.Menu:GetAlpha() == 0 and not c.Menu:IsMouseEnabled(), "el menú invisible toma el ratón")
    p.IsMouseOver = function() return true end
    Es.RevisarRaton()
    check(c.Cerrar:GetAlpha() == 1 and c.Cerrar:IsMouseEnabled() and c.Menu:IsMouseEnabled(), "con el ratón encima la X y el menú no se ven o no toman el clic")
    p.IsMouseOver = nil
  end
  Es.Volver()
end)

---------------------------------------------------------------------------
-- 8. Curación: Restablecer
---------------------------------------------------------------------------
step("8: Restablecer de Curación olvida las medidas por situación", function()
  local M = NS_OF("Alfa_Curacion")
  local Tm = M and M.Tamanos
  check(Tm and Tm.Restablecer, "falta Tamanos.Restablecer")
  if not (Tm and Tm.Restablecer) then return end
  local N = AlfaNucleo
  local fabrica = A.GetDefault("curacion.ancho")
  M.Datos().tamanos = { solo = { ancho = 140, alto = 44, porColumna = 5, crecer = "abajo" },
    grupo = { ancho = 150, alto = 50, porColumna = 5, crecer = "abajo" }, banda = { ancho = 60, alto = 20, porColumna = 5, crecer = "abajo" } }
  local O = A.UI and A.UI.Options
  O.ResetPage("curacion")
  local t = M.Datos().tamanos
  check(t.grupo == nil and t.banda == nil, "Restablecer dejó las medidas de grupo o banda")
  -- Al pasar a grupo no vuelven las de antes.
  local ig = IsInGroup
  IsInGroup = function() return true end
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  check(Tm.Actual() == "grupo", "no pasó a grupo")
  check(N.Get("curacion", "ancho") == fabrica, "en grupo volvieron las medidas viejas: " .. tostring(N.Get("curacion", "ancho")))
  IsInGroup = ig
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  -- Todos los ajustes de Curación de vuelta (ResetSettings) también.
  M.Datos().tamanos.banda = { ancho = 60, alto = 20, porColumna = 5, crecer = "abajo" }
  A.Fire("SETTING_CHANGED", "curacion")
  check(M.Datos().tamanos.banda == nil, "restablecer todo Curación dejó las medidas de banda")
end)

print(("PRUEBA: revisión 1.4.0, %d pasos, errores: %d"):format(pasos, #ERRORS))
