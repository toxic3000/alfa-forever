-- Prueba de la 1.4.0, área acomodar (tools/prueba.py la corre con las demás prueba_*.lua):
--   78. todo lo de Alfa en pantalla se mueve: K.Movible (Kit/Movible.lua) y el
--       modo «Acomodar la pantalla» (Alfa_Bienvenida/Acomodar.lua). Cada cosa
--       registrada se mueve, se guarda, sobrevive un /reload y Dos pantallas,
--       «Volver a su lugar» la regresa; el imán; Mayús+arrastre sin atrapar
--       clics; nada en combate;
--   79. las placas de la flecha aparte de ella y la de la piedra de hogar sin
--       textos cortados («te ahorras 2 min…»).
-- Con BANCO_FOTOS=1 dibuja las capturas (shot-140-acomodar-*.png).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["140-acomodar-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
end
local function step(nombre, fn, ...)
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.4.0 acomodar", msg) end end
local function T(n) RUN_TIMERS(n or 2) end
local function cerca(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 1.5) end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N0 = AlfaNucleo
N0.Datos("bienvenida").respondio = AlfaBienvenida and AlfaBienvenida.VERSION or 99
N0.Datos("bienvenida").versionVista = AlfaBienvenida and AlfaBienvenida.VersionAlfa and AlfaBienvenida.VersionAlfa() or "9.9.9"
N0.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
if Alfa.UI.Options and Alfa.UI.Options.frame then Alfa.UI.Options.frame:Hide() end

local A = Alfa
local N = AlfaNucleo
local K = N.Kit
local B = NS_OF("Alfa_Bienvenida")
local Ac = B and B.Acomodar
local Nav = A.Nav
local Arrow = Nav and Nav.arrow

-- Una noche (nada de verde liso) detrás de las capturas.
local function noche()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetAllPoints(UIParent)
  local t = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetAllPoints(f)
  t:SetTexture("white")
  t:SetGradient("VERTICAL", CreateColor(0.05, 0.055, 0.07, 1), CreateColor(0.12, 0.13, 0.17, 1))
  return f
end

-- Lo que hay en pantalla para acomodar.
local function ponerTodoAlaVista()
  local Ly = NS_OF("Alfa_Lya")
  if Ly and Ly.UI and Ly.UI.Aplicar then pcall(Ly.UI.Aplicar) end
  if Arrow and Arrow.frame then Arrow.frame:Show() end
  local In = NS_OF("Alfa_Inicio")
  if In and In.Aviso and In.Aviso.Probar then pcall(In.Aviso.Probar) end
  if K.AnclaAvisos then pcall(K.AnclaAvisos) end
  if K.AnclaAnuncio then pcall(K.AnclaAnuncio) end
  A.Set("ui.launcher", true)
  T(2)
end

---------------------------------------------------------------------------
step("El registro: la API y todo lo de pantalla", function()
  check(type(K.Movible) == "function" and type(K.MovibleSoltar) == "function" and type(K.MovibleVolver) == "function",
    "falta la API K.Movible / K.MovibleSoltar / K.MovibleVolver")
  check(Ac and Ac.Abrir and Ac.Soltar, "falta Acomodar.lua con Ac.Soltar")
  ponerTodoAlaVista()
  local claves = {}
  for _, e in ipairs(K.MovibleLista()) do claves[e.clave] = e end
  for _, c in ipairs({ "flecha", "placas", "rastreador", "avisoHoy", "lya", "raros", "barco", "pescaBarra", "pescaCanal",
    "pescaMetas", "salDeAhi", "listos", "mazmorraVivo", "mazmorraLinea", "mazmorraResumen", "botonFlotante", "vuelo",
    "instancias", "grupo" }) do
    check(claves[c], "no está registrado: " .. c)
  end
  -- Los que registran otros agentes (anuncios y la pila de avisos), si ya existen.
  if K.AnclaAvisos then check(claves.avisos, "la pila de avisos (K.AnclaAvisos) no se registró") end
  if K.AnclaAnuncio then check(claves.anuncio, "el ancla de anuncios (K.AnclaAnuncio) no se registró") end
  -- Cada uno con su nombre traducible (nada de claves sueltas).
  for c, e in pairs(claves) do
    local n = K.MovibleNombre(e)
    check(type(n) == "string" and n ~= "" and n ~= c, "sin nombre para el jugador: " .. c)
  end
  -- Lo que se ve tiene su marco resuelto.
  for _, c in ipairs({ "flecha", "placas", "lya" }) do
    check(claves[c] and claves[c].marco, "sin marco: " .. c)
  end
end)

---------------------------------------------------------------------------
-- Un marco del Kit (sin guardar propio): se mueve, se guarda, vuelve al
-- mostrarse (/reload), sigue a UIParent en Dos pantallas, nunca queda fuera.
---------------------------------------------------------------------------
step("Un marco del Kit: guardar, /reload, Dos pantallas y volver", function()
  local f = CreateFrame("Frame", "BancoMovible", UIParent)
  f:SetSize(200, 50)
  f:SetPoint("TOP", UIParent, "TOP", 0, -150)
  f:Show()
  local e = K.Movible(f, "bancoPrueba", { nombre = "Banco" })
  A.Set("acomodar.iman", false)
  local pos = K.MovibleSoltar(e, 100, 300)
  local l, b = K.MovibleRect(e)
  check(cerca(l, 100) and cerca(b, 300), "no quedó donde se soltó: " .. tostring(l) .. "," .. tostring(b))
  check(type(pos) == "table" and pos[1] == "BOTTOMLEFT", "el punto más cercano debía ser BOTTOMLEFT: " .. tostring(pos and pos[1]))
  local g = K.MovibleGuardado("bancoPrueba")
  check(g and g[1] == "BOTTOMLEFT" and cerca(g[2], 100) and cerca(g[3], 300), "no se guardó en AlfaNucleoDB.movibles")
  -- /reload: el módulo lo vuelve a poner en su lugar de fábrica y al mostrarse vuelve al guardado.
  f:Hide()
  f:ClearAllPoints()
  f:SetPoint("TOP", UIParent, "TOP", 0, -150)
  f:Show()
  l, b = K.MovibleRect(e)
  check(cerca(l, 100) and cerca(b, 300), "al mostrarse otra vez no volvió a su lugar guardado")
  -- Dos pantallas: UIParent se va a la segunda mitad; el marco va con él.
  PANTALLA_SIMULADA(3840, 1080)
  UIParent:SetSize(1920, 1080)
  UIParent:ClearAllPoints()
  UIParent:SetPoint("BOTTOMLEFT", nil, "BOTTOMLEFT", 1920, 0)
  K.MovibleReaplicar()
  local al = f:GetLeft()
  l, b = K.MovibleRect(e)
  check(cerca(l, 100) and cerca(b, 300) and cerca(al, 2020), "con Dos pantallas no siguió a UIParent: " .. tostring(al))
  -- Y se mueve igual en la pantalla movida.
  K.MovibleSoltar(e, 1600, 900)
  l, b = K.MovibleRect(e)
  check(cerca(l, 1600) and cerca(b, 900), "en Dos pantallas no quedó donde se soltó")
  local g2 = K.MovibleGuardado("bancoPrueba")
  check(g2 and g2[1] == "TOPRIGHT", "arriba a la derecha debía anclarse a TOPRIGHT: " .. tostring(g2 and g2[1]))
  UIParent:ClearAllPoints()
  PANTALLA_SIMULADA(1920, 1080)
  -- Una pantalla más chica: nunca queda fuera.
  PANTALLA_SIMULADA(1024, 768)
  K.MovibleReaplicar()
  l, b = K.MovibleRect(e)
  check(l and l >= -0.5 and l + 200 <= 1024.5 and b + 50 <= 768.5, "con la pantalla chica quedó fuera: " .. tostring(l) .. "," .. tostring(b))
  PANTALLA_SIMULADA(1920, 1080)
  -- Volver a su lugar.
  K.MovibleVolver(e)
  check(K.MovibleGuardado("bancoPrueba") == nil, "«Volver a su lugar» no borró lo guardado")
  local p, rel, rp, x, y = f:GetPoint(1)
  check(p == "TOP" and rp == "TOP" and x == 0 and y == -150, "«Volver a su lugar» no lo regresó a su lugar de fábrica")
  -- Por personaje.
  A.Set("acomodar.porPersonaje", true)
  K.MovibleSoltar(e, 40, 40)
  check(type(N.DatosPersonaje("movibles").bancoPrueba) == "table", "por personaje no se guardó en el personaje")
  check(N.Datos("movibles").bancoPrueba == nil, "por personaje no debía tocar lo de la cuenta")
  K.MovibleVolver(e)
  check(K.MovibleGuardado("bancoPrueba") == nil, "por personaje, volver no lo olvidó")
  A.Set("acomodar.porPersonaje", false)
  f:Hide()
end)

step("El imán: bordes, centro y rejilla", function()
  A.Set("acomodar.iman", true)
  local l, b, gx, gy = K.MovibleIman(7, 1080 - 50 - 5, 200, 50)
  check(l == 0 and b == 1030 and gx == 0 and gy == 1080, "no se pegó a la esquina de arriba a la izquierda: " .. tostring(l) .. "," .. tostring(b))
  l, b, gx = K.MovibleIman(960 - 100 + 6, 403, 200, 50)
  check(l == 860 and gx == 960, "no se pegó al centro: " .. tostring(l))
  check(b == 400 and gy == nil or b == 400, "no se pegó a la rejilla: " .. tostring(b))
  A.Set("acomodar.iman", false)
  l, b = K.MovibleIman(7, 403, 200, 50)
  check(l == 7 and b == 403, "sin imán se movió solo")
end)

---------------------------------------------------------------------------
-- Cada cosa registrada: se mueve con el modo, se guarda con su código de
-- siempre y «Volver a su lugar» la regresa.
---------------------------------------------------------------------------
step("Cada elemento registrado se mueve, se guarda y vuelve", function()
  ponerTodoAlaVista()
  A.Set("acomodar.iman", false)
  check(Ac.Abrir(), "el modo no se abrió")
  local probados, x = 0, 120
  for _, e in ipairs(K.MovibleLista()) do
    if e.marco and e.clave ~= "bancoPrueba" then
      local _, _, w, h = K.MovibleRect(e)
      local destino = 200 + (probados % 6) * 40
      local ok, err = pcall(Ac.Soltar, e.clave, x, destino)
      check(ok, "al soltar " .. e.clave .. ": " .. tostring(err))
      local l, b = K.MovibleRect(e)
      check(cerca(l, x, 2) and cerca(b, destino, 2),
        e.clave .. " no quedó donde se soltó: " .. tostring(l) .. "," .. tostring(b) .. " (quería " .. x .. "," .. destino .. ")")
      local ok2, err2 = pcall(K.MovibleVolver, e)
      check(ok2, "al volver " .. e.clave .. ": " .. tostring(err2))
      probados = probados + 1
      x = x + 8
    end
  end
  check(probados >= 8, "se probaron muy pocos elementos: " .. probados)
  Ac.Cerrar()
end)

step("Lo guardado con su código de siempre (sobrevive /reload)", function()
  A.Set("acomodar.iman", false)
  -- La flecha: nav.arrowPos, y Arrow:OnSettings (lo que corre al entrar) la deja ahí.
  K.MovibleSoltar("flecha", 300, 700)
  local p = A.Get("nav.arrowPos")
  check(type(p) == "table" and p.point == "TOPLEFT", "la flecha no guardó nav.arrowPos")
  Arrow:OnSettings()
  local l, b = K.MovibleRect("flecha")
  check(cerca(l, 300) and cerca(b, 700), "tras /reload la flecha no quedó en su lugar: " .. tostring(l) .. "," .. tostring(b))
  K.MovibleVolver("flecha")
  check(A.Get("nav.arrowPos") == nil, "volver no borró nav.arrowPos")
  -- Lya: lya.pos.
  K.MovibleSoltar("lya", 1500, 200)
  check(type(A.Get("lya.pos")) == "table", "Lya no guardó lya.pos")
  local Ly = NS_OF("Alfa_Lya")
  if Ly and Ly.UI and Ly.UI.Aplicar then Ly.UI.Aplicar() end
  l, b = K.MovibleRect("lya")
  check(cerca(l, 1500, 2) and cerca(b, 200, 2), "tras /reload Lya no quedó en su lugar")
  K.MovibleVolver("lya")
  check(A.Get("lya.pos") == nil, "volver no borró lya.pos")
  -- El aviso de Hoy, la tarjeta de raros, el botón flotante y los marcos compactos del motor.
  K.MovibleSoltar("avisoHoy", 600, 600)
  check(type(A.Get("inicio.avisoPos")) == "table", "el aviso de Hoy no guardó inicio.avisoPos")
  K.MovibleVolver("avisoHoy")
  check(A.Get("inicio.avisoPos") == nil, "volver no borró inicio.avisoPos")
  if K.MovibleDe("raros").marco then
    K.MovibleSoltar("raros", 600, 640)
    check(type(A.Get("rares.toastPoint")) == "table", "la tarjeta de raros no guardó rares.toastPoint")
    K.MovibleVolver("raros")
    check(A.Get("rares.toastPoint") == nil, "volver no borró rares.toastPoint")
  end
  if K.MovibleDe("botonFlotante").marco then
    K.MovibleSoltar("botonFlotante", 800, 800)
    check(type(A.Get("ui.launcherPos")) == "table", "el botón flotante no guardó ui.launcherPos")
    K.MovibleVolver("botonFlotante")
    check(A.Get("ui.launcherPos") == nil, "volver no borró ui.launcherPos")
  end
  if K.MovibleDe("vuelo").marco then
    K.MovibleSoltar("vuelo", 700, 900)
    local v = A.Get("maps.timerPos")
    check(type(v) == "table" and v[1] == "CENTER", "el cronómetro de vuelo no guardó maps.timerPos")
    K.MovibleVolver("vuelo")
    check(not A.Get("maps.timerPos"), "volver no borró maps.timerPos")
  end
end)

---------------------------------------------------------------------------
step("Mayús+arrastre directo, sin atrapar clics fuera de él", function()
  local f = CreateFrame("Frame", "BancoMayus", UIParent)
  f:SetSize(120, 40)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:CreateTexture(nil, "ARTWORK"):SetAllPoints(f) -- algo dibujado (un ancla vacía no cuenta)
  f:EnableMouse(false)
  f:Show()
  local e = K.Movible(f, "bancoMayus", { nombre = "Banco Mayús" })
  check(e.mayus, "un marco sin arrastre propio debía tomar Mayús+arrastre")
  A.Set("acomodar.conMayus", true)
  A.Set("acomodar.iman", false)
  local real = IsShiftKeyDown
  IsShiftKeyDown = function() return true end
  FIRE_EVENT("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
  check(f:IsMouseEnabled(), "con Mayús abajo no tomó el ratón")
  FIRE(f, "OnMouseDown", "LeftButton")
  f:ClearAllPoints()
  f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 64, 64)
  FIRE(f, "OnMouseUp", "LeftButton")
  local g = K.MovibleGuardado("bancoMayus")
  check(g and cerca(g[2], 64) and cerca(g[3], 64), "Mayús+arrastre no guardó el lugar")
  IsShiftKeyDown = function() return false end
  FIRE_EVENT("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
  check(not f:IsMouseEnabled(), "al soltar Mayús se quedó con el ratón (atraparía clics)")
  -- En combate: nada se presta.
  local realC = InCombatLockdown
  InCombatLockdown = function() return true end
  IsShiftKeyDown = function() return true end
  FIRE_EVENT("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
  check(not f:IsMouseEnabled(), "en combate Mayús prestó el ratón")
  InCombatLockdown = realC
  -- Apagado el ajuste: tampoco.
  A.Set("acomodar.conMayus", false)
  FIRE_EVENT("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
  check(not f:IsMouseEnabled(), "con el ajuste apagado Mayús prestó el ratón")
  A.Set("acomodar.conMayus", nil)
  IsShiftKeyDown = real
  K.MovibleVolver(e)
  f:Hide()
end)

step("El modo: no se abre en combate, Esc y una pelea lo cierran, nada se queda", function()
  local realC = InCombatLockdown
  InCombatLockdown = function() return true end
  check(not Ac.Abrir(), "se abrió en combate")
  InCombatLockdown = realC
  check(Ac.Abrir(), "no se abrió")
  local panel = rawget(_G, "AlfaAcomodarPanel")
  FIRE(panel, "OnKeyDown", "ESCAPE")
  check(not Ac.Activo(), "Esc no lo cerró")
  Ac.Abrir()
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not Ac.Activo(), "la pelea no lo cerró")
  -- Si algo esconde el panel, el velo y las guías no se quedan.
  Ac.Abrir()
  panel:Hide()
  check(not Ac.Activo(), "con el panel escondido el modo siguió")
  for _, m in pairs(Ac.Marcas()) do check(not m:IsShown(), "un recuadro se quedó a la vista") end
  -- «Volver todo a su lugar»: dos clics.
  A.Set("acomodar.iman", false)
  Ac.Abrir()
  K.MovibleSoltar("flecha", 300, 700)
  Ac.VolverTodo()
  check(A.Get("nav.arrowPos") ~= nil, "un solo clic en «Volver todo» ya lo regresó todo")
  Ac.VolverTodo()
  check(A.Get("nav.arrowPos") == nil, "«Volver todo a su lugar» no regresó la flecha")
  Ac.Cerrar()
end)

---------------------------------------------------------------------------
-- 79: la placa de la piedra de hogar, entera; las placas aparte de la flecha.
---------------------------------------------------------------------------
local function conPiedra(fn)
  local GT, R = Nav.GetTarget, rawget(_G, "AlfaRuta")
  local ent = R and R.EntregasPiedra
  Nav.GetTarget = function() return { label = "Mata a Espía de la Hermandad para obtener Sello de Alterac" } end
  if R then R.EntregasPiedra = function() return 1 end end
  Arrow.frame:Show()
  local ok, err = pcall(fn)
  Nav.GetTarget = GT
  if R then R.EntregasPiedra = ent end
  if not ok then error(err) end
end

step("79: «Usa tu piedra de hogar» sin textos cortados", function()
  conPiedra(function()
    check(Arrow.PintarPiedra({ kind = "hearth", place = "Mesón Aguahonda", saved = 130 }), "no se pintó la placa de la piedra")
    local f = Arrow.llegada
    local d = Arrow.Llegada()
    check(d and d.piedra and d.accion and d.accion:find("te ahorras 2 min caminando", 1, true), "la acción de la piedra no dice todo: " .. tostring(d and d.accion))
    local col = f.Accion:GetWidth()
    local largo = f.Accion:GetUnboundedStringWidth()
    local maxl = Arrow.PLACA.LINEAS
    check(largo <= col * maxl, ("la acción no cabe: %d de ancho en %d líneas de %d"):format(largo, maxl, col))
    check(f.Accion:GetNumLines() <= maxl, "la acción tiene más líneas de las que caben")
    -- Un lugar con nombre larguísimo: la placa crece (más ancha y más líneas), sin «…».
    Arrow.PintarPiedra({ kind = "hearth", place = "Posada del Ciervo Blanco de la Ciudad de Ventormenta Vieja", saved = 610 })
    col, largo = f.Accion:GetWidth(), f.Accion:GetUnboundedStringWidth()
    check(f:GetWidth() > 264, "con un texto largo la placa no se ensanchó")
    check(f:GetWidth() <= Arrow.PLACA.MAX, "la placa se pasó de su ancho tope")
    check(largo <= col * maxl, "con un texto largo, la acción se corta")
    -- Lo de abajo (después, la piedra, cuándo llegas) cabe en la placa.
    local _, nb = f.Nota:GetRect()
    local _, pb = f:GetRect()
    check(nb and pb and nb >= pb - 0.5, "la nota se sale por abajo de la placa")
    if FOTOS then
      local fondo = noche()
      SNAP("piedra", fondo, { Arrow.frame })
      fondo:Hide()
    end
  end)
end)

step("78/79: las placas, aparte de la flecha o con ella", function()
  A.Set("acomodar.iman", false)
  conPiedra(function()
    Arrow.PintarPiedra({ kind = "hearth", place = "Mesón Aguahonda", saved = 130 })
    local f = Arrow.llegada
    -- Con la flecha: la placa está arriba del disco.
    local fl = f:GetLeft()
    check(not Arrow.PlacasAparte(), "de fábrica las placas debían ir con la flecha")
    -- Moverlas solas (como el modo: se separan al empezar).
    check(Ac.Abrir(), "el modo no se abrió")
    local m = Ac.Marcas().placas
    check(m and m:IsShown() and not m.alfaVacia, "la placa a la vista no tiene su recuadro")
    Ac.Soltar("placas", 1300, 700)
    check(Arrow.PlacasAparte(), "al moverlas no quedaron aparte de la flecha")
    local l = f:GetLeft()
    local t = f:GetTop()
    check(cerca(l, 1300, 2), "la placa no quedó donde se soltó: " .. tostring(l))
    check(type(A.Get("nav.placasPos")) == "table", "no se guardó nav.placasPos")
    -- La flecha no se movió con ellas, y su lugar vacío no atrapa clics.
    Arrow.PintarPiedra({ kind = "hearth", place = "Mesón Aguahonda", saved = 130 })
    check(not Arrow.frame:IsMouseEnabled(), "con las placas aparte, el lugar vacío de la flecha toma el ratón")
    -- Mover la flecha no las mueve.
    Ac.Soltar("flecha", 200, 300)
    check(cerca(f:GetLeft(), l, 2) and cerca(f:GetTop(), t, 2), "al mover la flecha, las placas aparte se movieron")
    -- /reload: Arrow:OnSettings las vuelve a poner en su lugar.
    Arrow:OnSettings()
    check(cerca(f:GetLeft(), l, 2), "tras /reload la placa no quedó en su lugar")
    if FOTOS then
      local fondo = noche()
      SNAP("modo-placas-aparte", fondo, { Arrow.frame, rawget(_G, "AlfaAcomodarPanel") })
      fondo:Hide()
    end
    -- Volver: con la flecha otra vez.
    FIRE(m, "OnClick", "RightButton")
    check(not Arrow.PlacasAparte() and A.Get("nav.placasPos") == nil, "«Volver a su lugar» no las juntó con la flecha")
    K.MovibleVolver("flecha")
    check(cerca(f:GetLeft(), fl, 2) and f:GetPoint(1) == "TOP", "la placa no volvió al disco de la flecha: " .. tostring(f:GetLeft()) .. " / " .. tostring(fl))
    Ac.Cerrar()
  end)
  -- Por personaje, como la flecha (nav.flechaPorPersonaje).
  Arrow.SepararPlacas()
  local s = A.CharState and A.CharState()
  if type(s) == "table" and A.Get("nav.flechaPorPersonaje") then
    check(type(s.flecha) == "table" and type(s.flecha.placas) == "table", "el lugar de las placas no se guardó en el personaje")
  end
  A.Set("nav.placasPos", nil)
end)

---------------------------------------------------------------------------
-- Las capturas del modo (1920 x 1080 y la escala automática 1365 x 768).
---------------------------------------------------------------------------
step("El modo se ve bien (capturas y textos en su caja)", function()
  for _, t in ipairs({ { 1920, 1080, "1080" }, { 1365, 768, "768" } }) do
    PANTALLA_SIMULADA(t[1], t[2])
    ponerTodoAlaVista()
    check(Ac.Abrir(), "no se abrió a " .. t[3])
    local panel = rawget(_G, "AlfaAcomodarPanel")
    -- El texto del panel cabe en el panel.
    local _, pb = panel:GetRect()
    local _, tb = panel.Texto:GetRect()
    check(tb and pb and tb >= pb, "el texto del panel se sale de su caja a " .. t[3])
    local _, lb = panel.Listo:GetRect()
    check(lb and lb >= pb, "«Listo» se sale del panel a " .. t[3])
    -- Cada recuadro con su nombre entero.
    for clave, m in pairs(Ac.Marcas()) do
      if m:IsShown() then
        check(m.Etiqueta:GetWidth() >= m.Nombre:GetStringWidth(), "el nombre de " .. clave .. " no cabe en su etiqueta")
      end
    end
    if FOTOS then
      local fondo = noche()
      local extra = { Ac.Velo(), Arrow.frame, rawget(_G, "AlfaLyaLoba"), rawget(_G, "AlfaAcomodarPanel") }
      for _, m in pairs(Ac.Marcas()) do extra[#extra + 1] = m end
      SNAP("modo-" .. t[3], fondo, extra)
      fondo:Hide()
    end
    Ac.Cerrar()
  end
  PANTALLA_SIMULADA(1920, 1080)
  A.Set("acomodar.iman", nil)
end)

print("PRUEBA: 1.4.0 acomodar, " .. #ERRORS .. " errores")
