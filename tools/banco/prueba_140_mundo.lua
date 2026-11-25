-- Prueba de la 1.4.0, área Mundo (tools/prueba.py la corre con las demás):
--    2. [bug] La meta de la flecha nunca se sale ni se corta a medias: cabe en
--       dos renglones con un «…» limpio, y la flecha sube encima de una
--       ventana de Alfa que la tapa (con una placa para leerse) y vuelve a su
--       capa cuando la ventana se quita.
--   33. La flecha de cada personaje: lugar, tamaño y si la escondiste.
--   35. Mapa: entrenadores de tu clase y tus oficios.
--   36. Mapa: comida, agua y reparación cerca.
--   37. Horarios de barcos compartidos por La Jauría (versión y facción).
--   39. /alfa ir <nombre>.
--   40. Curación: medidas por tamaño de grupo.
--   41. Curación: el ícono de quién no tiene tu buff.
--   42. Combate: el lugar y el tamaño del medidor por personaje.
--   43. Mazmorras: «¿Qué cae aquí para mí?».
--   44. Mazmorras: los jefes en el plano por dentro.
--   45. Tras una muerte, «Vuelve a tu cuerpo».
SNAPSHOTS = {}
BANCO_LETRA = 0.64
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["140-mundo-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
end
local function step(nombre, fn, ...)
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
local function check(cond, msg) if not cond then NOTE("1.4.0 mundo", msg) end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local N = AlfaNucleo
local A = N.A
local E = A.Engine
local Nav = A.Nav
local Arrow = Nav and Nav.arrow

local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do t[k] = a.v end
  if not ok then error(e) end
end

-- Un fondo nocturno (nada de verde liso) para las capturas.
local function fondoNoche(w, h)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetSize(w, h)
  local cielo = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  cielo:SetAllPoints(f)
  cielo:SetTexture("white")
  cielo:SetGradient("VERTICAL", CreateColor(0.035, 0.04, 0.05, 1), CreateColor(0.1, 0.12, 0.16, 1))
  for i, c in ipairs({ { 0.2, 0.45, 0.3 }, { 0.75, 0.5, 0.34 }, { 0.48, 0.58, 0.3 } }) do
    local t = f:CreateTexture(nil, "BACKGROUND", nil, -4)
    t:SetTexture("circle")
    t:SetSize(w * c[2] * 2, h * c[3] * 2)
    t:SetPoint("CENTER", f, "BOTTOMLEFT", w * c[1], -h * 0.08)
    local v = 0.04 + i * 0.01
    t:SetVertexColor(v, v + 0.01, v + 0.02, 1)
  end
  f:Show()
  return f
end

-- La flecha en camino a `target`, a `yardas`.
local function enCamino(target, yardas, fn)
  con(Nav, {
    Sample = function() return "travel", yardas, 0.3 end,
    GetTarget = function() return target end,
    TomTomArrowGuides = function() return false end,
    HandedOff = function() return false end,
    HiddenWithGuide = function() return false end,
  }, function()
    con(A, { ArrowHidden = function() return false end }, function()
      Arrow:OnTarget(target)
      Arrow:Refresh()
      fn()
      Arrow:OnTarget(nil)
      Arrow.frame:Hide()
    end)
  end)
end

---------------------------------------------------------------------------
-- 2. La meta de la flecha
---------------------------------------------------------------------------
step("2: la meta cabe en dos renglones con un «…» limpio", function()
  check(Arrow and Arrow.AcortarMeta and Arrow.Meta, "falta Arrow.AcortarMeta / Arrow.Meta")
  local ancho = Arrow.labelText:GetWidth()
  -- La de la captura de Toxic cabe entera.
  local corta = "Consigue Mena de estaño de Filón de estaño"
  check(Arrow.AcortarMeta(corta) == corta, "la meta de la captura se acortó sin hacer falta: " .. tostring(Arrow.AcortarMeta(corta)))
  -- Una larguísima: dos renglones como mucho, termina en «…», sin palabras partidas.
  local larga = "Consigue Mena de estaño de Filón de estaño en las colinas del norte de los Baldíos, junto al campamento de los centauros Kolkar que custodian la caravana y el pozo seco"
  local m = Arrow.AcortarMeta(larga)
  check(m ~= larga and m:sub(-3) == "\226\128\166", "la meta larga no terminó en «…»: " .. m)
  local sinPuntos = m:sub(1, -4)
  check(larga:sub(1, #sinPuntos) == sinPuntos, "el corte no es el principio de la meta: " .. m)
  local sig = larga:sub(#sinPuntos + 1, #sinPuntos + 1)
  check(sig == " " or sig == ",", "se partió una palabra: «" .. m .. "»")
  local fs = Arrow.labelText
  fs:SetText(m)
  check(fs:GetUnboundedStringWidth() <= ancho * 2, ("la meta acortada mide %d y caben %d"):format(fs:GetUnboundedStringWidth(), ancho * 2))
  -- Con un aviso debajo: la meta en un renglón, el aviso en el otro.
  local dos = Arrow.AcortarMeta(larga .. "\n" .. "Cuidado: el camino pasa por un pueblo de la otra facción, ve rodeando por el río")
  local r1, r2 = dos:match("^(.-)\n(.*)$")
  check(r1 and r2, "con aviso la meta perdió el renglón del aviso: " .. dos)
  if r1 then
    fs:SetText(r1)
    check(fs:GetUnboundedStringWidth() <= ancho, "con aviso la meta no cabe en un renglón")
    check(r2:find("Cuidado", 1, true) == 1, "el aviso no quedó en el segundo renglón")
  end
  -- Una clave de color abierta se cierra al cortar.
  local color = Arrow.AcortarMeta("|cff00ff00" .. larga .. "|r")
  check(color:find("|r", 1, true), "al cortar una meta con color quedó el color abierto: " .. color)
  -- Una palabra sola larguísima se corta por letras, sin partir una letra (UTF-8).
  local palabra = string.rep("ñ", 120)
  local p = Arrow.AcortarMeta(palabra)
  check(p:sub(-3) == "\226\128\166" and p:sub(1, -4):match("^[ñ]+$") ~= nil and (#p - 3) % 2 == 0, "una palabra larga se partió a media letra")
end)

local fondo = fondoNoche(1100, 420)
fondo:SetPoint("TOP", UIParent, "TOP", 0, 0)

step("2: con la meta larga en el juego, el renglón nunca pasa de dos", function()
  local T = { label = "Consigue Mena de estaño de Filón de estaño en las colinas del norte de los Baldíos, junto al campamento de los centauros Kolkar que custodian la caravana", map = 1413, x = 50, y = 50 }
  enCamino(T, 892, function()
    local mostrada, entera = Arrow.Meta()
    check(entera == T.label, "la flecha no guardó la meta entera (para el cuadro)")
    check(mostrada ~= entera and mostrada:sub(-3) == "\226\128\166", "la flecha no acortó la meta larga: " .. tostring(mostrada))
    check(Arrow.labelText:GetNumLines() <= 2, "la meta ocupa más de dos renglones")
    check(Arrow.etaText:IsShown() and (Arrow.etaText:GetText() or ""):find("a pie", 1, true), "sin el «≈ … a pie» debajo")
    SNAP("flecha-meta-larga", fondo, { Arrow.frame })
  end)
end)

step("2: una ventana de Alfa encima de la flecha: la flecha sube y se lee", function()
  -- Una ventana como la de Bolsas, arriba al centro, encima de la meta.
  local v = CreateFrame("Frame", "AlfaPruebaVentanaMundo", UIParent)
  v:SetFrameStrata("HIGH")
  v:SetSize(320, 300)
  v:SetPoint("TOPLEFT", UIParent, "TOP", 40, -150)
  local t = v:CreateTexture(nil, "BACKGROUND")
  t:SetAllPoints(v)
  t:SetColorTexture(0.07, 0.08, 0.1, 0.97)
  local tit = v:CreateFontString(nil, "OVERLAY")
  tit:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
  tit:SetPoint("TOPLEFT", v, "TOPLEFT", 14, -12)
  tit:SetText("Bolsas")
  v:Show()
  Nav.VentanasDeAlfa[#Nav.VentanasDeAlfa + 1] = v
  A.Set("nav.arrowPos", nil)
  local T = { label = "Consigue Mena de estaño de Filón de estaño", map = 1413, x = 50, y = 50 }
  enCamino(T, 892, function()
    Arrow.EvitarVentanas()
    local cual, capa, placa = Arrow.Encima()
    check(cual == "AlfaPruebaVentanaMundo", "la flecha no vio la ventana encima: " .. tostring(cual))
    check(capa == "DIALOG", "la flecha no subió por encima de la ventana: " .. tostring(capa))
    check(placa, "la meta no lleva su placa para leerse sobre la ventana")
    SNAP("flecha-sobre-ventana", fondo, { Arrow.frame, v })
    -- La ventana se va: la flecha vuelve a su capa y sin placa.
    v:Hide()
    Arrow.EvitarVentanas()
    cual, capa, placa = Arrow.Encima()
    check(cual == nil and capa == "MEDIUM" and not placa, "sin la ventana la flecha no volvió a su capa: " .. tostring(capa))
    -- Una ventana de diálogo (capa DIALOG) manda: la flecha no la tapa.
    v:SetFrameStrata("DIALOG")
    v:Show()
    Arrow.EvitarVentanas()
    cual, capa = Arrow.Encima()
    check(cual == nil and capa == "MEDIUM", "la flecha se subió encima de un diálogo")
    -- Lejos de la flecha: nada cambia.
    v:SetFrameStrata("HIGH")
    v:ClearAllPoints()
    v:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -10, 10)
    Arrow.EvitarVentanas()
    cual, capa = Arrow.Encima()
    check(cual == nil and capa == "MEDIUM", "una ventana lejos subió la flecha")
    v:Hide()
  end)
  table.remove(Nav.VentanasDeAlfa)
end)

---------------------------------------------------------------------------
-- 33. La flecha de cada personaje
---------------------------------------------------------------------------
step("33: lugar, tamaño y si la escondiste, por personaje", function()
  check(A.Get("nav.flechaPorPersonaje") == true, "nav.flechaPorPersonaje no viene prendido")
  local s = A.CharState()
  s.flecha = nil
  -- Este personaje la mueve, la agranda y la esconde.
  A.Set("nav.arrowPos", { point = "TOP", relPoint = "TOP", x = 120, y = -80 })
  A.Set("nav.arrowScale", 1.4)
  A.Set("nav.arrow", false)
  local f = Arrow.Propia()
  check(f and f.pos and f.pos.x == 120 and f.escala == 1.4 and f.ver == false, "el personaje no guardó su flecha")
  -- Otro personaje (lo de la cuenta cambia) y vuelves a este: se pone lo suyo.
  A.Set("nav.flechaPorPersonaje", false)
  A.Set("nav.arrowPos", { point = "TOP", relPoint = "TOP", x = 0, y = -140 })
  A.Set("nav.arrowScale", 1)
  A.Set("nav.arrow", true)
  A.Set("nav.flechaPorPersonaje", true)
  check(Arrow.PonerPropia(), "PonerPropia no hizo nada")
  local p = A.Get("nav.arrowPos")
  check(type(p) == "table" and p.x == 120 and A.Get("nav.arrowScale") == 1.4 and A.Get("nav.arrow") == false,
    "al volver al personaje no se puso su flecha")
  -- Restablecer la posición también la olvida en el personaje.
  Nav.ResetArrowPosition()
  check(Arrow.Propia().pos == "nada", "restablecer no olvidó el lugar del personaje")
  A.Set("nav.arrowPos", { point = "TOP", relPoint = "TOP", x = 5, y = -140 })
  Nav.ResetArrowPosition()
  Arrow.PonerPropia()
  check(A.Get("nav.arrowPos") == nil, "tras restablecer, el personaje volvió a un lugar viejo")
  -- Un personaje que nunca la tocó usa la de la cuenta.
  s.flecha = nil
  check(Arrow.PonerPropia() == false, "un personaje sin flecha propia cambió la de la cuenta")
  A.Set("nav.arrow", true)
  A.Set("nav.arrowScale", 1)
  s.flecha = nil
end)

---------------------------------------------------------------------------
-- 69 y 76. La tarjeta del viaje compacta
---------------------------------------------------------------------------
local K = N.Kit
local X = A.Transit
local T = Nav.travel
local horario = { medido = false, llega = nil, sale = nil, espera = 175, viaje = 300, abordo = nil }
local real = { NextArrival = X.NextArrival, NextDeparture = X.NextDeparture, Riding = X.Riding, Now = X.Now }
local DESTINO = { boat = "Trinquete", zeppelin = "Orgrimmar", tram = "Forjaz", portal = "Ventormenta", fly = "Forjaz" }
local function tramo(kind)
  return { kind = kind, label = "x", to = { name = DESTINO[kind], c = 0, wx = 1, wy = 1 },
    from = { name = "Puerto de Menethil", c = 0, wx = 0, wy = 0 },
    transport = kind ~= "fly" and kind ~= "portal" and { id = "r1" } or nil, side = "a", seconds = 91 }
end
local escena = { estado = "muelle", kind = "boat" }
local guardaT, guardaNav = {}, {}
for _, k in ipairs({ "Active", "CurrentLeg", "NextLeg", "CurrentLabel", "Remaining" }) do guardaT[k] = T[k] end
for _, k in ipairs({ "Sample", "GetTarget", "HiddenWithGuide", "TomTomArrowGuides", "HandedOff", "IsHiddenState" }) do guardaNav[k] = Nav[k] end
local function montar()
  X.Now = function() return NOW end
  X.NextArrival = function() if not horario.medido then return nil end return horario.llega, horario.sale, true end
  X.NextDeparture = function() if not horario.medido then return horario.espera, horario.viaje, false end return horario.sale, horario.viaje, true end
  X.Riding = function() if horario.abordo then return { kind = escena.kind, route = "r1", arriveIn = horario.abordo } end return nil end
  T.Active = function() return true end
  T.CurrentLeg = function()
    if escena.estado == "camino" then return { kind = "walk", to = { c = 0, wx = 0, wy = 0 } } end
    return tramo(escena.kind)
  end
  T.NextLeg = function() if escena.estado == "camino" then return tramo(escena.kind) end return nil end
  T.CurrentLabel = function() return "x" end
  T.Remaining = function() return 300 end
  Nav.Sample = function()
    if escena.estado == "camino" then return "travel", 1066, 0.4 end
    return "instruction", 0
  end
  Nav.GetTarget = function() return { label = "Ve con el maestro de vuelo", map = 1437, x = 10, y = 60 } end
  Nav.HiddenWithGuide = function() return false end
  Nav.TomTomArrowGuides = function() return false end
  Nav.HandedOff = function() return false end
  Nav.IsHiddenState = function() return false end
  A.Set("nav.arrow", true)
end
local function desmontar()
  for k, fn in pairs(guardaT) do T[k] = fn end
  for k, fn in pairs(guardaNav) do Nav[k] = fn end
  for k, v in pairs(real) do X[k] = v end
end
local function correr(veces)
  for _ = 1, veces or 8 do NOW = NOW + 0.3 FIRE(Arrow.frame, "OnUpdate", 0.3) end
end
-- Un texto visible dentro de su tarjeta y sin encimarse con otro.
local function revisarTextos(marco, nombre)
  local l, b, w, h = marco:GetRect()
  local vistos = {}
  for _, fs in ipairs({ marco.Sobre, marco.Titulo, marco.Cuenta, marco.Nota, marco.Ruta, marco.CuentaSobre }) do
    if fs and fs:IsShown() and (fs:GetText() or "") ~= "" then
      local fl, fb, fw, fh = fs:GetRect()
      check(fl >= l - 1 and fb >= b - 1 and fl + fw <= l + w + 1 and fb + fh <= b + h + 1,
        nombre .. ": «" .. tostring(fs:GetText()) .. "» se sale de la tarjeta")
      for _, o in ipairs(vistos) do
        local sep = fl >= o[1] + o[3] or o[1] >= fl + fw or fb >= o[2] + o[4] or o[2] >= fb + fh
        check(sep, nombre .. ": «" .. tostring(fs:GetText()) .. "» se encima con «" .. o[5] .. "»")
      end
      vistos[#vistos + 1] = { fl, fb, fw, fh, tostring(fs:GetText()) }
    end
  end
end

step("69: la tarjeta compacta, cerrable y que se va sola a bordo", function()
  check(A.Get("nav.viajeCompacto") == true, "la tarjeta compacta no viene de fábrica")
  montar()
  local f = Arrow.frame
  f:ClearAllPoints()
  f:SetPoint("TOP", UIParent, "TOP", 0, -120)
  local casos = {
    { kind = "fly", estado = "camino", icono = "viaje%-" },
    { kind = "fly", estado = "muelle" },
    { kind = "boat", estado = "muelle", medido = true, llega = 95, sale = 168 },
    { kind = "boat", estado = "muelle" },
    { kind = "zeppelin", estado = "muelle", medido = true, llega = 0, sale = 35 },
    { kind = "tram", estado = "camino" },
    { kind = "portal", estado = "muelle" },
  }
  for _, c in ipairs(casos) do
    Arrow:OnTarget(Nav.GetTarget())
    escena.estado, escena.kind = c.estado, c.kind
    horario.medido, horario.llega, horario.sale, horario.abordo = c.medido and true or false, c.llega, c.sale, nil
    f:Hide() f:Show()
    correr(6)
    local tj = Arrow.Tarjeta()
    local nombre = c.kind .. "-" .. c.estado .. (c.medido and "-medido" or "")
    check(tj and tj.compacta, nombre .. ": no salió la tarjeta compacta")
    if tj and tj.compacta then
      check(tj.icono and tj.icono:find("viaje%-"), nombre .. ": sin el dibujo del transporte")
      check(tj.cerrar, nombre .. ": sin su X")
      check(not tj.viejo, nombre .. ": el texto viejo se ve a la vez")
      local tf = Arrow.tarjeta
      check(tf:GetHeight() <= 56, nombre .. ": la compacta mide " .. tf:GetHeight() .. " de alto (más de dos renglones)")
      check(not tf.Ruta:IsShown() and not tf.Nota:IsShown() and not tf.Pista:IsShown(), nombre .. ": la compacta trae la nota, la ruta o la barra")
      revisarTextos(tf, nombre)
      SNAP("viaje-" .. nombre, fondo, { f })
    end
  end
  -- El dibujo del vuelo de la Horda es el murciélago.
  local real2 = UnitFactionGroup
  UnitFactionGroup = function() return "Horde", "Horda" end
  check(Arrow.IconoViaje({ kind = "fly" }) == "viaje-murcielago", "la Horda no vuela en murciélago")
  UnitFactionGroup = function() return "Alliance", "Alianza" end
  check(Arrow.IconoViaje({ kind = "fly" }) == "viaje-grifo", "la Alianza no vuela en grifo")
  -- La tarjeta del vuelo de un personaje de la Alianza: el grifo, y el renglón corto y completo.
  UnitFactionGroup = function() return "Alliance", "Alianza" end
  for _, est in ipairs({ "muelle", "camino" }) do
    Arrow:OnTarget(Nav.GetTarget())
    escena.estado, escena.kind = est, "fly"
    horario.medido, horario.abordo = false, nil
    f:Hide() f:Show()
    correr(6)
    local tj = Arrow.Tarjeta()
    check(tj and tj.icono and tj.icono:find("viaje%-grifo"), "Alianza " .. est .. ": el vuelo no sale con el grifo: " .. tostring(tj and tj.icono))
    local tf = Arrow.tarjeta
    local dos = tf.Sobre:GetText() or ""
    check(dos:find("Maestro de vuelo", 1, true) and not dos:find("\226\128\166", 1, true), "Alianza " .. est .. ": el renglón no es corto y completo: " .. dos)
    revisarTextos(tf, "alianza-" .. est)
    SNAP("viaje-fly-" .. est .. "-alianza", fondo, { f })
  end
  UnitFactionGroup = real2
  -- El aro no parpadea: el halo se queda quieto.
  escena.estado, escena.kind = "muelle", "boat"
  Arrow:OnTarget(Nav.GetTarget())
  f:Hide() f:Show()
  correr(3)
  local tf = Arrow.tarjeta
  local a1 = tf.Halo:GetAlpha()
  correr(5)
  check(tf.Halo:GetAlpha() == a1, "el halo de la tarjeta sigue latiendo")
  -- Clic derecho: se cierra (y no vuelve en este tramo).
  FIRE(tf, "OnMouseUp", "RightButton")
  correr(3)
  local tj = Arrow.Tarjeta()
  check(tj and tj.cerrada and not tf:IsShown(), "el clic derecho no cerró la tarjeta")
  -- Otro destino: vuelve a salir.
  Arrow:OnTarget(Nav.GetTarget())
  correr(3)
  tj = Arrow.Tarjeta()
  check(tj and tj.compacta and tf:IsShown(), "con otro destino la tarjeta no volvió")
  -- La X también la cierra.
  if tf.Cerrar then FIRE(tf.Cerrar, "OnClick", "LeftButton") end
  correr(2)
  check(not tf:IsShown(), "la X no cerró la tarjeta")
  -- A bordo: unos segundos y se va sola.
  Arrow:OnTarget(Nav.GetTarget())
  horario.abordo = 140
  correr(3)
  check(tf:IsShown(), "a bordo la tarjeta no salió al subir")
  correr(30)
  check(not tf:IsShown(), "a bordo la tarjeta se quedó (debía irse sola)")
  horario.abordo = nil
  -- En combate no toma el ratón.
  Arrow:OnTarget(Nav.GetTarget())
  correr(2)
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  correr(2)
  check(not tf:IsMouseEnabled(), "en combate la tarjeta atrapa clics")
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  -- La grande sigue ahí con el ajuste apagado.
  A.Set("nav.viajeCompacto", false)
  correr(3)
  tj = Arrow.Tarjeta()
  check(tj and not tj.compacta and tf.Ruta:IsShown(), "sin la compacta no vuelve la tarjeta grande")
  A.Set("nav.viajeCompacto", nil)
  T.Active = function() return false end
  Nav.Sample = function() return "travel", 300, 0.2 end
  correr(3)
  f:Hide()
  desmontar()
end)

step("76: la flecha a escala grande: nada se encima ni se sale", function()
  local T2 = { label = "Consigue Mena de estaño de Filón de estaño en las colinas del norte de los Baldíos, junto al campamento", map = 1413, x = 50, y = 50 }
  for _, esc in ipairs({ 1, 1.5 }) do
    A.Set("nav.arrowScale", esc)
    enCamino(T2, 892, function()
      local d, m, e = Arrow.distText, Arrow.labelText, Arrow.etaText
      check(m:GetNumLines() <= 2, esc .. ": la meta pasa de dos renglones")
      local _, db = d:GetRect()
      local _, mb, _, mh = m:GetRect()
      local _, eb, _, eh = e:GetRect()
      check(mb + mh <= db + 1, esc .. ": la meta se encima con la distancia")
      check(eb + eh <= mb + 1, esc .. ": el tiempo se encima con la meta")
    end)
  end
  A.Set("nav.arrowScale", nil)
end)

step("2: tras cambiar la pantalla (Dos pantallas), los textos de la flecha se vuelven a medir", function()
  check(Arrow.Remedir, "falta Arrow.Remedir")
  local T3 = { label = "Consigue Mena de estaño de Filón de estaño", map = 1413, x = 50, y = 50 }
  enCamino(T3, 892, function()
    BANCO_GEN_LETRA = (rawget(_G, "BANCO_GEN_LETRA") or 0) + 1
    FIRE_EVENT("DISPLAY_SIZE_CHANGED")
    for _, fs in ipairs({ Arrow.distText, Arrow.labelText, Arrow.etaText }) do
      local lay = rawget(fs, "_lay")
      check(lay and lay.gen == BANCO_GEN_LETRA, "«" .. tostring(fs:GetText()) .. "» se quedó con la medida de antes")
    end
    check(Arrow.labelText:GetText() == T3.label, "al volver a medir se perdió la meta")
    -- Al volver de Dos pantallas (ALFA_ESCRITORIO "volvio"), igual.
    BANCO_GEN_LETRA = BANCO_GEN_LETRA + 1
    A.Fire("ALFA_ESCRITORIO", "volvio")
    local lay = rawget(Arrow.labelText, "_lay")
    check(lay and lay.gen == BANCO_GEN_LETRA, "al volver de Dos pantallas la meta se quedó con la medida de antes")
  end)
end)

---------------------------------------------------------------------------
-- 72. El mapa sin montones de calaveras
---------------------------------------------------------------------------
local MU = NS_OF("Alfa_Mundo")
step("72: los peligros juntos en un pin con su número, sin los amistosos", function()
  local Pe = MU.Peligros
  check(Pe and Pe.Grupos and Pe.Anotar and Pe.PonerIndice, "falta Peligros.Grupos / Anotar")
  local porZona = {}
  -- Diez élites hostiles juntos, un raro aparte y un guardia de tu facción.
  for i = 1, 10 do
    Pe.Anotar(porZona, 9000 + i, { name = "Ogro " .. i, elite = true, level = 40, levelMax = 41, spawns = { { map = 1426, x = 40 + i * 0.3, y = 50 + i * 0.2 } } })
  end
  Pe.Anotar(porZona, 9100, { name = "Raro lejano", rare = true, level = 45, spawns = { { map = 1426, x = 80, y = 20 } } })
  local mia = UnitFactionGroup and UnitFactionGroup("player")
  local letra = mia == "Horde" and "H" or "A"
  Pe.Anotar(porZona, 9200, { name = "Guardia", elite = true, level = 55, faction = letra, spawns = { { map = 1426, x = 30, y = 30 } } })
  Pe.Anotar(porZona, 9201, { name = "Maestro de armas", elite = true, level = 50, faction = "AH", spawns = { { map = 1426, x = 31, y = 31 } } })
  Pe.PonerIndice(porZona)
  local g = Pe.Grupos(1426, 10)
  check(#g == 2, "los peligros no se juntaron: " .. #g .. " grupos")
  local grande
  for _, x in ipairs(g) do if x.n == 10 then grande = x end end
  check(grande and #grande.criaturas == 10, "el grupo de los diez no tiene su número")
  for _, x in ipairs(g) do
    for _, c in ipairs(x.criaturas) do check(c.name ~= "Guardia" and c.name ~= "Maestro de armas", "un PNJ amistoso salió de peligro") end
  end
  local pines = Pe.Pines(1426)
  local conNumero = false
  for _, p in ipairs(pines) do if p.badge == 10 then conNumero = true end end
  check(conNumero, "el pin del grupo no lleva su número")
  Pe.Olvidar()
end)

---------------------------------------------------------------------------
-- 35, 36. Tus entrenadores y tus provisiones
---------------------------------------------------------------------------
step("35/36: entrenadores de tu clase y oficios, comida y reparación", function()
  local Sv = MU.Servicios
  check(Sv and Sv.Indexar and Sv.Entrenadores and Sv.Provisiones, "falta Servicios.lua")
  local X2 = A.Codex
  if X2 and not X2.IsLoaded() then X2.Load() end
  Sv.Olvidar()
  Sv.Indexar()
  for _ = 1, 400 do if Sv.Listo() then break end RUN_TIMERS(1) end
  check(Sv.Listo(), "los servicios no se leyeron del Codex")
  -- Una zona con el entrenador de tu clase.
  local C = A.Compat
  local clase = C.GetPlayerInfo().class
  local ids = X2.WithRole("class:" .. clase)
  local zona
  for _, id in ipairs(ids) do
    local n = X2.Npc(id)
    if n and n.spawns and n.spawns[1] and (n.faction == "AH" or n.faction == nil or n.faction:find(UnitFactionGroup("player") == "Horde" and "H" or "A")) then zona = n.spawns[1].map break end
  end
  check(zona, "sin zona con entrenador de " .. tostring(clase))
  if zona then
    local e = Sv.Entrenadores(zona)
    check(#e > 0, "no salió el entrenador de tu clase en " .. zona)
    if e[1] then
      check(Sv.QueHace(e[1]) ~= "", "el entrenador no dice qué enseña")
      print("entrenador", e[1].nombre, Sv.QueHace(e[1]))
    end
    local p = Sv.Provisiones(zona)
    print("provisiones en", zona, #p)
  end
  -- Lo que pinta la capa del motor no se repite.
  A.Set("maps.servicePins", true)
  A.Set("maps.serviceFilters.class", true)
  if zona then
    local hay = false
    for _, x in ipairs(Sv.Entrenadores(zona)) do if x.que.clase then hay = true end end
    check(not hay, "con la capa de servicios del motor, el entrenador sale dos veces")
  end
  A.Set("maps.servicePins", nil)
  A.Set("maps.serviceFilters.class", nil)
end)

---------------------------------------------------------------------------
-- 37. Los horarios de La Jauría
---------------------------------------------------------------------------
step("37: horarios de barcos por La Jauría, con versión", function()
  local Ho = MU.Horarios
  check(Ho and Ho.Texto and Ho.Leer and Ho.AlMensaje, "falta Horarios.lua")
  local ahora = X.Now()
  local ruta = "lift-freewind-post"
  local e = X.encode(ruta, { seen = math.floor(ahora) - 30, epoch = (math.floor(ahora) - 30) * 1000 - 4000 })
  check(type(e) == "string", "el motor no sabe escribir el horario de " .. ruta)
  local msgs = Ho.Texto({ e })
  check(#msgs == 1 and msgs[1]:sub(1, 4) == "S|1|", "el mensaje no lleva su versión: " .. tostring(msgs[1]))
  local campos = {}
  for c in (msgs[1] .. "|"):gmatch("([^|]*)|") do campos[#campos + 1] = c end
  check(Ho.Leer(campos) ~= nil, "un mensaje de la misma versión no se lee")
  check(Ho.Leer({ "S", "9", campos[3] }) == nil, "un mensaje de una versión más nueva se leyó")
  check(Ho.Leer({ "S", "1", "algo raro<>" }) == nil, "un mensaje roto se leyó")
  X.ForgetSightings()
  local cambiados = {}
  local antes = A.Get("mundo.horariosManada")
  local n = Ho.AlMensaje("lobito", "Lobito-Reino", campos, "GUILD")
  check(n == 1, "el horario del lobo no se anotó: " .. tostring(n))
  local _, _, medido = X.NextDeparture("lift", ruta, ahora)
  local de
  for id in pairs({ [ruta] = true }) do de = Nav.HorarioDeLaManada and Nav.HorarioDeLaManada(id) end
  print("horario de la manada:", tostring(de), tostring(medido))
  -- Por susurro o por otro canal, nada.
  X.ForgetSightings()
  check((Ho.AlMensaje("lobito", "Lobito", campos, "WHISPER") or 0) == 0, "un horario por susurro se anotó")
  -- Apagado, nada.
  A.Set("mundo.horariosManada", false)
  check((Ho.AlMensaje("lobito", "Lobito", campos, "GUILD") or 0) == 0, "con el ajuste apagado se anotó un horario")
  A.Set("mundo.horariosManada", antes)
  X.ForgetSightings()
end)

---------------------------------------------------------------------------
-- 39. /alfa ir
---------------------------------------------------------------------------
step("39: /alfa ir <nombre>", function()
  local Ir = MU.Ir
  check(Ir and Ir.Buscar and Ir.Ir, "falta Ir.lua")
  local _, por = Ir.Buscar("")
  check(por == "vacio", "sin nombre no dice que falta")
  -- Un marcador tuyo.
  local Mk = MU.Marcadores
  local id = Mk and Mk.Crear and Mk.Crear({ nombre = "Cueva del lobo", mapa = 1429, x = 40, y = 60 })
  local r = Ir.Buscar("cueva del lobo")
  check(r and r.tipo == "marcador", "no encontró tu marcador")
  if id and Mk.Borrar then Mk.Borrar(type(id) == "table" and id.id or id, true) end
  -- Un PNJ: el entrenador de tu clase (sale el más cercano).
  local X2 = A.Codex
  local clase = A.Compat.GetPlayerInfo().class
  local ids = X2.WithRole("class:" .. clase)
  local n = ids[1] and X2.Npc(ids[1])
  if n and n.name then
    local p = Ir.Buscar(n.name)
    check(p and p.tipo == "pnj" and p.mapa and p.x, "no encontró al PNJ «" .. n.name .. "»")
    if p then print("ir:", p.nombre, p.mapa, p.x, p.y) end
  end
  -- Una zona.
  local z = Ir.Buscar("Elwynn")
  print("ir zona:", z and z.tipo, z and z.nombre)
  check(z and z.tipo == "zona", "«Elwynn» no llevó a la zona: " .. tostring(z and z.tipo) .. " " .. tostring(z and z.nombre))
  -- Nada.
  local nada, por2 = Ir.Buscar("zzzqqqxxx")
  check(nada == nil and por2 == "nada", "algo sin sentido encontró un lugar")
  Ir.Ir("zzzqqqxxx")
end)

---------------------------------------------------------------------------
-- 40, 41. Curación
---------------------------------------------------------------------------
local CU = NS_OF("Alfa_Curacion")
step("40: las medidas por tamaño de grupo", function()
  local Tm = CU.Tamanos
  check(Tm and Tm.Cambiar and Tm.BandaCompacta, "falta Tamanos.lua")
  check(N.Get("curacion", "porTamano") == true, "curacion.porTamano no viene prendido")
  CU.Datos().tamanos = nil
  N.Set("curacion", "ancho", 84)
  Tm.Cambiar("solo")
  N.Set("curacion", "ancho", 110)
  check(Tm.Medidas("solo").ancho == 110, "lo que ajustas solo no se guardó en «solo»")
  Tm.Cambiar("banda")
  check(N.Get("curacion", "ancho") == 110, "la banda la primera vez no empezó con tus medidas")
  Tm.BandaCompacta()
  check(N.Get("curacion", "ancho") == 72 and N.Get("curacion", "alto") == 26, "«Banda compacta» no puso los marcos chicos")
  Tm.Cambiar("solo")
  check(N.Get("curacion", "ancho") == 110, "al volver a solo no se pusieron sus medidas")
  Tm.Cambiar("banda")
  check(N.Get("curacion", "ancho") == 72, "al volver a la banda no se pusieron sus medidas")
  check(Tm.Texto():find("72", 1, true), "el texto de las medidas no dice las de la banda")
  print("medidas:", Tm.Texto())
  Tm.Cambiar("solo")
  N.Set("curacion", "ancho", nil)
  N.Set("curacion", "alto", nil)
  CU.Datos().tamanos = nil
end)

step("41: el ícono de quién no tiene tu hechizo de apoyo", function()
  local Sb = CU.SinBuff
  check(Sb and Sb.Faltan, "falta SinBuff.lua")
  local antes = CU.botones
  local function boton(u, falta) return { unidad = u, alfaSinBuff = falta, IsVisible = function() return true end } end
  CU.botones = { boton("party1", true), boton("party2", nil), boton("party3", true) }
  local f = Sb.Faltan()
  check(#f == 2, "no contó a los dos sin tu hechizo: " .. #f)
  CU.botones = antes
end)

---------------------------------------------------------------------------
-- 42. Combate: el medidor por personaje
---------------------------------------------------------------------------
local CO = NS_OF("Alfa_Combate")
step("42: el lugar y el tamaño del medidor, por personaje", function()
  check(CO.LugarDe, "falta M.LugarDe")
  N.Datos("combate").pos = { Medidor = { "BOTTOMRIGHT", "BOTTOMRIGHT", -10, 10 } }
  N.DatosPersonaje("combate").pos = {}
  check(CO.LugarDe("Medidor")[3] == -10, "un personaje sin lugar propio no usa el de la cuenta")
  N.DatosPersonaje("combate").pos = { Medidor = { "TOP", "TOP", 0, -50 } }
  check(CO.LugarDe("Medidor")[1] == "TOP", "el lugar del personaje no manda")
  local V = CO.Ventana
  check(V and V.FijarTamano and V.Escala, "falta el tamaño del medidor")
  V.FijarTamano("grande")
  check(V.Escala() == 1.2 and N.DatosPersonaje("combate").medidorTam == "grande", "el tamaño no se guardó en el personaje")
  local hay = false
  for _, o in ipairs(V.Opciones()) do if o.valor == "tam:grande" and o.icono then hay = true end end
  check(hay, "el clic derecho no ofrece el tamaño")
  V.FijarTamano("normal")
  N.Datos("combate").pos = {}
  N.DatosPersonaje("combate").pos = {}
end)

---------------------------------------------------------------------------
-- 43, 44. Mazmorras
---------------------------------------------------------------------------
local MA = NS_OF("Alfa_Mazmorras")
step("43: ¿Qué cae aquí para mí?", function()
  local Pm, D = MA.ParaMi, MA.D
  check(Pm and Pm.Lista and Pm.Resumen and Pm.Avisar, "falta ParaMi.lua")
  local real3 = D.Mejora
  local key
  for _, d in ipairs(D.Lista() or {}) do if #D.Jefes(d.key) > 0 then key = d.key break end end
  check(key, "sin mazmorra para probar")
  if not key then return end
  local hist = N.Get("mazmorras", "historia")
  N.Set("mazmorras", "historia", false)
  D.Mejora = function() return true, 5 end
  local l = Pm.Lista(key)
  local ya = Pm.Cuenta(l)
  print("para mí:", key, #l, ya, Pm.Resumen(key))
  if #l > 0 then
    check(Pm.Resumen(key):find("para ti", 1, true), "el resumen no lo dice")
    check(Pm.Avisar(key, true), "no avisó lo que te sirve")
    check(#Pm.DeJefe(key, l[1].nombre) > 0, "el jefe no dice qué te sirve de él")
  end
  D.Mejora = function() return false end
  check(Pm.Resumen(key) == nil, "sin mejoras igual dijo algo")
  D.Mejora = real3
  N.Set("mazmorras", "historia", hist)
end)

step("44: los jefes en el plano, donde los encontraste", function()
  local Md = MA.MapaDentro
  check(Md and Md.Aprender and Md.Jefes, "falta aprender jefes en el plano")
  check(Md.Aprender(9999, "Rhahk'Zor", 0.31, 0.42), "no aprendió el lugar del jefe")
  check(not Md.Aprender(9999, SECRETO and SECRETO("Oculto") or nil, 0.2, 0.2), "aprendió un nombre secreto")
  local j = Md.Jefes(9999)
  check(#j == 1 and j[1].nombre == "Rhahk'Zor" and math.abs(j[1].x - 0.31) < 0.001, "el jefe no quedó en el plano")
  N.Datos("mazmorras").jefesPlano[9999] = nil
end)

---------------------------------------------------------------------------
-- 45. Vuelve a tu cuerpo
---------------------------------------------------------------------------
local LY = NS_OF("Alfa_Lya")
step("45: «Vuelve a tu cuerpo» con la flecha y el tiempo", function()
  local Mu = LY.Muerte
  check(Mu and Mu.Flecha and Mu.QuitarFlecha, "falta la flecha al cuerpo")
  local ok = Mu.Flecha({ mapa = 1429, x = 40, y = 50, cuerpoSeg = 50 })
  check(ok, "no puso la flecha al cuerpo")
  local t = Nav.GetTarget()
  check(t and t.label and t.label:find("Vuelve a tu cuerpo", 1, true), "la flecha no dice «Vuelve a tu cuerpo»: " .. tostring(t and t.label))
  check(t and t.label:find("corriendo", 1, true), "la flecha no dice cuánto tardas corriendo")
  Mu.QuitarFlecha()
  check(Nav.GetTarget() == nil, "al revivir la flecha al cuerpo se quedó")
end)

print("140 mundo: fin")
