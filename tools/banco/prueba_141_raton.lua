-- Prueba de la 1.4.1: el ratón es del jugador.
--
-- Bug de Toxic con la 1.4.0 instalada:
--   «Si ves un enemigo a lo lejos no le puedes dar clic, te tienes que acercar»
--   «La cámara luego como que se setea, no se puede mover»
--   «No tengo manera de mover el volumen a menos de que desactive el addon»
--   «Le di a la tecla K, se abrieron profesiones y no me deja darle clic a las
--    pestañas (minería, herrería); primeros auxilios sí»
-- Causa: el ancla invisible de los anuncios (560x150, arriba del centro de la
-- pantalla) tomaba el ratón: «Acomodar» (Kit/Movible.lua) le enganchaba
-- OnMouseDown/OnMouseUp, y en el juego eso PRENDE el ratón del marco. Era una
-- pared invisible justo sobre el horizonte, las pestañas de arriba de la
-- ventana de profesiones y los deslizadores de Opciones > Audio.
--
-- El banco ya imita al juego (mock.lua: un script de ratón prende el ratón;
-- un botón nace tomándolo). Esta prueba corre RATON_BARRIDO (raton.lua) en
-- muchos momentos de una sesión y además pone ventanas del juego simuladas
-- debajo (profesiones, Opciones > Audio) y revisa que su clic les llegue.
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
local function check(cond, msg) if not cond then NOTE("1.4.1 ratón", msg) end end
local function T(n) RUN_TIMERS(n or 3) end

Alfa.Hidden = function() return false end
-- Cómo trae el ratón cada marco del juego antes de que Alfa entre: Alfa no se
-- lo cambia (un gancho de ratón se lo prendía: MinimapCluster, las barras).
local DEL_JUEGO = { "MinimapCluster", "Minimap", "MinimapBackdrop", "WorldFrame", "UIParent",
  "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "MainMenuExpBar", "ReputationWatchBar" }
for i = 1, 10 do DEL_JUEGO[#DEL_JUEGO + 1] = "ChatFrame" .. i end
local antesJuego = {}
for _, n in ipairs(DEL_JUEGO) do
  local f = rawget(_G, n)
  if type(f) == "table" and rawget(f, "_kind") then
    antesJuego[n] = { clic = f:IsMouseClickEnabled(), paso = f:IsMouseMotionEnabled(), rueda = f:IsMouseWheelEnabled() }
  end
end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
print("errores al entrar:", #ERRORS)
local A, N = Alfa, AlfaNucleo
local K = N.Kit
local intro = rawget(_G, "AlfaIntro")
if intro and intro:IsShown() then intro:Hide() end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
local bv = rawget(_G, "AlfaBienvenidaVentana")
if bv and bv.Hide then bv:Hide() end
local Ly = NS_OF("Alfa_Lya")
if Ly and Ly.UI and Ly.UI.Aplicar then Ly.UI.Aplicar() end
T(5)

---------------------------------------------------------------------------
-- Ventanas del juego simuladas: lo que Toxic no podía clicar
---------------------------------------------------------------------------
local W, H = UIParent:GetWidth(), UIParent:GetHeight()
-- Profesiones (tecla K): a la izquierda, con sus pestañas al costado derecho.
local prof = CreateFrame("Frame", "BancoProfesiones", UIParent)
prof:SetFrameStrata("MEDIUM")
prof:SetSize(1150, 960)
prof:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -70)
prof:EnableMouse(true)
prof:Hide()
local pestanas = {}
for i = 1, 6 do
  local b = CreateFrame("Button", "BancoProfesionesPestana" .. i, prof)
  b:SetSize(70, 70)
  b:SetPoint("TOPLEFT", prof, "TOPRIGHT", 0, -60 - (i - 1) * 95)
  pestanas[i] = b
end
-- Opciones > Audio: al centro, con los deslizadores de volumen arriba.
local opciones = CreateFrame("Frame", "BancoOpciones", UIParent)
opciones:SetFrameStrata("HIGH")
opciones:SetSize(1100, 760)
opciones:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
opciones:EnableMouse(true)
opciones:Hide()
local deslizadores = {}
for i = 1, 6 do
  local s = CreateFrame("Slider", "BancoVolumen" .. i, opciones)
  s:SetSize(420, 26)
  s:SetPoint("TOPRIGHT", opciones, "TOPRIGHT", -60, -90 - (i - 1) * 60)
  deslizadores[i] = s
end
-- El chat, con su botón de volumen.
local volChat = CreateFrame("Button", "BancoBotonVolumen", UIParent)
volChat:SetSize(32, 32)
volChat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 6, 330)

local function centro(f) local l, b, w, h = f:GetRect() return l + w / 2, b + h / 2 end
local function llegaA(f, x, y, que)
  local g = RATON_ARRIBA(x, y, que)
  local p = g
  for _ = 1, 6 do
    if p == f then return true, g end
    p = p and rawget(p, "_parent")
  end
  return false, g
end

local problemas = {}
local function anotar(lista)
  for _, p in ipairs(lista) do problemas[#problemas + 1] = p end
end

-- Lo que el juego tiene que poder clicar en este momento.
local function ventanasDelJuego(momento)
  prof:Show()
  for i, b in ipairs(pestanas) do
    local x, y = centro(b)
    local ok, g = llegaA(b, x, y, "clic")
    if not ok then problemas[#problemas + 1] = ("%s: la pestaña %d de profesiones no recibe el clic (lo toma %s)"):format(momento, i, g and RATON_NOMBRE(g) or "nadie") end
  end
  prof:Hide()
  opciones:Show()
  for i, s in ipairs(deslizadores) do
    local l, b, w, h = s:GetRect()
    for _, fx in ipairs({ 0.1, 0.5, 0.9 }) do
      local ok, g = llegaA(s, l + w * fx, b + h / 2, "clic")
      if not ok then
        problemas[#problemas + 1] = ("%s: el deslizador de volumen %d no recibe el clic (lo toma %s)"):format(momento, i, g and RATON_NOMBRE(g) or "nadie")
        break
      end
    end
  end
  opciones:Hide()
  local x, y = centro(volChat)
  local ok, g = llegaA(volChat, x, y, "clic")
  if not ok then problemas[#problemas + 1] = momento .. ": el botón de volumen del chat no recibe el clic (lo toma " .. (g and RATON_NOMBRE(g) or "nadie") .. ")" end
end

-- Un momento de la sesión: el barrido completo.
local function momento(nombre)
  RATON_ADELANTAR(1.5)
  anotar(RATON_BARRIDO(nombre))
  ventanasDelJuego(nombre)
end

local function shift(si)
  IsShiftKeyDown = function() return si end
  FIRE_EVENT("MODIFIER_STATE_CHANGED", "LSHIFT", si and 1 or 0)
end
local realShift = IsShiftKeyDown
local realCombate = InCombatLockdown

---------------------------------------------------------------------------
step("Al entrar", function() momento("al entrar") end)

step("Un anuncio grande: a la vista y después", function()
  if not K.Anuncio then return end
  K.Anuncio({ titulo = "Bosque de Elwynn", texto = "Tierras de los humanos", clave = "probar" })
  RATON_ADELANTAR(1)
  anotar(RATON_PAREDES())
  -- Que se vaya solo (su tiempo) y, otro, cerrado a mano.
  RATON_ADELANTAR(12)
  momento("después de un anuncio que se fue solo")
  K.Anuncio({ titulo = "Montañas de Alterac", texto = "Otro", clave = "probar" })
  RATON_ADELANTAR(1)
  K.CerrarAnuncio()
  momento("después de un anuncio")
end)

step("Avisos: a la vista y después", function()
  for i = 1, 4 do K.Aviso({ titulo = "Aviso " .. i, texto = "Algo que contar", duracion = 3 }) end
  RATON_ADELANTAR(1)
  anotar(RATON_PAREDES())
  RATON_ADELANTAR(15)
  momento("después de los avisos")
end)

step("Mayús: los tiradores salen y se van", function()
  K.Anuncio({ titulo = "La flecha", texto = "Prueba", clave = "probar" })
  RATON_ADELANTAR(1)
  shift(true)
  T(1)
  anotar(RATON_PAREDES())
  shift(false)
  T(1)
  momento("con Mayús soltada (anuncio a la vista)")
  K.CerrarAnuncio()
  RATON_ADELANTAR(2)
  shift(true)
  shift(false)
  momento("con Mayús soltada")
  IsShiftKeyDown = realShift
end)

step("Acomodar la pantalla: abrir y cerrar", function()
  local Ac = rawget(_G, "AlfaAcomodar")
  if not (Ac and Ac.Abrir) then return end
  Ac.Abrir()
  T(2)
  Ac.Cerrar()
  momento("tras Acomodar")
end)

step("La flecha con destino y su placa", function()
  local Nav = Alfa.Nav
  if Nav and Nav.SetTarget then pcall(Nav.SetTarget, 1429, 45, 60, "Prueba") end
  T(3)
  momento("con la flecha guiando")
  local Arrow = Alfa.Nav and Alfa.Nav.Arrow or rawget(_G, "AlfaArrow")
  if type(Arrow) == "table" and Arrow.PintarPiedra then
    pcall(Arrow.PintarPiedra, { kind = "hearth", place = "Mesón", saved = 60 })
    RATON_ADELANTAR(1)
    anotar(RATON_PAREDES())
  end
  if Nav and Nav.ClearTarget then pcall(Nav.ClearTarget) end
  T(10)
  momento("sin destino")
end)

step("Lya habla y se calla", function()
  local Ce, UI = Ly and Ly.Cerebro, Ly and Ly.UI
  if not (Ce and UI) then return end
  Ce.Decir({ texto = "¡Hola, lobo! ¿Una salchicha?", pedido = true })
  T(2)
  momento("con Lya hablando")
  UI.Callar(true)
  momento("con Lya callada")
end)

step("Combate: entrar y salir", function()
  InCombatLockdown = function() return true end
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  momento("en combate")
  InCombatLockdown = realCombate
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  momento("tras el combate")
end)

step("Pesca: abrir y cerrar el modo", function()
  local P = NS_OF("Alfa_Pesca")
  if not (P and P.AbrirModo) then return end
  P.AbrirModo(true)
  local pv = rawget(_G, "AlfaPescaPrevia")
  if pv and pv.Hide then pv:Hide() end
  T(3)
  momento("con el modo pesca")
  P.CerrarModo(true, true)
  T(3)
  momento("tras pescar")
end)

local PAGINAS = { "inicio", "planes", "rutas", "enciclopedia", "builds", "bolsas", "manada", "mazmorras", "mundo",
  "pesca", "lya", "vista", "comodidades", "comercio", "recoleccion", "combate", "curacion", "bienvenida", "questing" }
step("Cada página de Alfa: abrir y cerrar", function()
  for _, id in ipairs(PAGINAS) do
    A.Fire("SHOW_OPTIONS", id)
    RATON_ADELANTAR(0.6)
    anotar(RATON_PAREDES())
    if N.CerrarVentana then N.CerrarVentana() end
    local o = A.UI and A.UI.Options and A.UI.Options.frame
    if o and o:IsShown() then o:Hide() end
    RATON_ADELANTAR(0.6)
  end
  momento("tras abrir y cerrar todas las páginas")
end)

step("Un /reload a media sesión", function()
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
  T(10)
  momento("tras cambiar de zona")
end)

step("La guardia: si algo le prende el ratón a un ancla, se apaga y se anota", function()
  check(type(K.SinRaton) == "function" and type(K.RevisarRaton) == "function", "falta la guardia del ratón (Kit/Raton.lua)")
  for _, nombre in ipairs({ "AlfaAnuncioAncla", "AlfaAvisosAncla", "AlfaNavPlacas" }) do
    local f = rawget(_G, nombre)
    check(f, "no existe " .. nombre)
    if f then
      f:HookScript("OnMouseDown", function() end) -- como lo hacía la 1.4.0
      check(f:IsMouseEnabled(), "el banco ya no imita que un gancho de ratón prende el ratón")
      local antes = N.Errores and #N.Errores() or 0
      local n = K.RevisarRaton()
      check(n >= 1 and not f:IsMouseEnabled(), "la guardia no le apagó el ratón a " .. nombre)
      check(not N.Errores or #N.Errores() > antes or n == 0, "la guardia no anotó " .. nombre .. " en /alfa errores")
    end
  end
  -- Mayús soltada también la corre.
  local f = rawget(_G, "AlfaAnuncioAncla")
  f:EnableMouse(true)
  shift(true) shift(false)
  IsShiftKeyDown = realShift
  check(not f:IsMouseEnabled(), "al soltar Mayús la guardia no revisó")
  momento("tras la guardia")
end)

step("/alfa raton: dice qué hay bajo el ratón y las paredes de Alfa", function()
  local dichos = {}
  local imp = N.Imprimir
  N.Imprimir = function(t) dichos[#dichos + 1] = tostring(t) end
  local GF, EF = rawget(_G, "GetMouseFoci"), rawget(_G, "EnumerateFrames")
  GetMouseFoci = function() return { WorldFrame } end
  -- Una pared puesta a propósito: la tiene que encontrar.
  local pared = CreateFrame("Frame", "AlfaParedDePrueba", UIParent)
  pared:SetSize(300, 100)
  pared:SetPoint("CENTER")
  pared:EnableMouse(true)
  -- EnumerateFrames como el juego: recorre los marcos (sin texturas ni textos).
  local marcos = {}
  for _, x in ipairs(ALL_FRAMES()) do
    local k = rawget(x, "_kind")
    if k ~= "Texture" and k ~= "FontString" and k ~= "Line" then marcos[#marcos + 1] = x end
  end
  local idx = {}
  for i, x in ipairs(marcos) do idx[x] = i end
  EnumerateFrames = function(prev) if prev == nil then return marcos[1] end return marcos[(idx[prev] or #marcos) + 1] end
  A.RunCommand("raton")
  local todo = table.concat(dichos, " | ")
  check(todo:find("AlfaParedDePrueba", 1, true), "/alfa raton no encontró una pared invisible: " .. todo)
  check(not todo:find("AlfaRastreador", 1, true), "/alfa raton dio por pared un botón dentro del rastreador que se ve: " .. todo)
  dichos = {}
  A.RunCommand("raton arreglar")
  check(not pared:IsMouseEnabled(), "/alfa raton arreglar no le quitó el ratón a la pared")
  pared:Hide()
  N.Imprimir, GetMouseFoci, EnumerateFrames = imp, GF, EF
end)

step("Marcos del juego: Alfa no les prende el ratón", function()
  -- Las opciones que enganchan marcos del juego, prendidas.
  A.Set("comodidades.minimapa", true)
  A.Set("comodidades.minimapaBotones", true)
  A.Set("comodidades.chatCopiar", true)
  RATON_ADELANTAR(2)
  for n, a in pairs(antesJuego) do
    local f = rawget(_G, n)
    local c, p, r = f:IsMouseClickEnabled(), f:IsMouseMotionEnabled(), f:IsMouseWheelEnabled()
    check(c == a.clic and p == a.paso and r == a.rueda,
      ("Alfa le cambió el ratón a %s (clic %s->%s, paso %s->%s, rueda %s->%s)"):format(n, tostring(a.clic), tostring(c), tostring(a.paso), tostring(p), tostring(a.rueda), tostring(r)))
  end
end)

step("Pantalla limpia: lo transparente no toma el ratón y vuelve como estaba", function()
  local Pl = N.PantallaLimpia
  if not Pl then return end
  local cf = ChatFrame1
  local antes = cf:IsMouseEnabled()
  Pl.Alternar(true)
  RATON_ADELANTAR(1)
  check(not cf:IsMouseEnabled() and not cf:IsMouseWheelEnabled(), "con la pantalla limpia el chat invisible sigue tomando el ratón")
  check(not (Minimap:IsMouseEnabled()), "con la pantalla limpia el minimapa invisible sigue tomando el ratón")
  local eb = rawget(_G, "ChatFrame1EditBox")
  check(not eb or (eb:GetAlpha() or 1) > 0.5, "la pantalla limpia dejó invisible el cuadro de escribir del chat")
  Pl.Alternar(false)
  RATON_ADELANTAR(1)
  check(cf:IsMouseEnabled() == antes, "al volver de la pantalla limpia el chat no recuperó su ratón")
  check(Minimap:IsMouseEnabled(), "al volver de la pantalla limpia el minimapa no recuperó su ratón")
end)

step("Un menú abierto en combate no pone capa sobre la pantalla", function()
  local dueno = CreateFrame("Button", "AlfaBancoDueno", UIParent)
  dueno:SetSize(100, 20)
  dueno:SetPoint("CENTER")
  InCombatLockdown = function() return true end
  K.Menu(dueno, { { texto = "Uno", valor = 1 }, { texto = "Dos", valor = 2 } }, nil, function() end)
  RATON_ADELANTAR(0.5)
  anotar(RATON_PAREDES())
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local g = RATON_ARRIBA(W * 0.2, H * 0.8, "clic")
  check(not (g and RATON_DE_ALFA(g)), "con un menú abierto en combate, el clic al mundo lo toma " .. (g and RATON_NOMBRE(g) or ""))
  K.CerrarMenu()
  InCombatLockdown = realCombate
  dueno:Hide()
end)

step("Diálogos y cuadrículas del motor: se apartan al entrar en combate", function()
  local Wd = Alfa.UI and Alfa.UI.Widgets or Alfa.Widgets
  local modal
  if Wd and Wd.Modal then
    pcall(Wd.Modal, { title = "¿Restablecer?", text = "Prueba", action = "Sí", onAccept = function() end })
    modal = rawget(_G, "AlfaModal")
  end
  InCombatLockdown = function() return true end
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not (modal and modal:IsShown()), "el diálogo del motor (AlfaModal) se queda tapando la pantalla en combate")
  anotar(RATON_PAREDES())
  InCombatLockdown = realCombate
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  if modal then
    check(modal:IsShown(), "el diálogo del motor no volvió al salir del combate")
    modal:Hide()
  end
end)

-- Sin repetidos.
local vistos, unicos = {}, {}
for _, p in ipairs(problemas) do
  local clave = p:gsub("^[^:]+: ", "")
  if not vistos[clave] then vistos[clave] = true unicos[#unicos + 1] = p end
end
step("Resultado del barrido", function()
  check(#unicos == 0, #unicos .. " problemas del ratón:\n      " .. table.concat(unicos, "\n      ", 1, math.min(#unicos, 40)))
end)
if #unicos > 0 then print("LO QUE TOMA EL RATÓN AHORA:\n" .. RATON_RESUMEN()) end

print("pasos:", pasos, "errores:", #ERRORS)
for i = 1, #ERRORS do print("ERROR x1 " .. tostring(ERRORS[i]):sub(1, 300)) end
