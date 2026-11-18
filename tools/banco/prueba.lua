-- Prueba de navegación y funcionalidad de Alfa (tools/prueba.py la corre).
--
-- Usa Alfa como un jugador, con el juego simulado del banco: la bienvenida
-- paso a paso hasta el final, todas las páginas en los 3 estilos, el mapa
-- (zoom, arrastrar con inercia, ir a los bordes, doble clic, marcador con clic
-- derecho, capas, cambiar de tamaño, cerrar y abrir), las ventanas de cada
-- módulo, Lya en todas sus poses, entrar y salir de combate y los eventos del
-- juego más comunes. Cualquier error de Lua que salga en un paso se imprime
-- como "FALLA EN: <paso>" con su traza, y run.py termina con código 1.
SNAPSHOTS = {}
BANCO_LETRA = 0.64
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
local function T(n) RUN_TIMERS(n or 2) end
local function ns(n) return NS_OF(n) end
local function hay(t, k) return type(t) == "table" and type(rawget(t, k)) == "function" end

-- El ratón: el mapa lo lee con GetCursorPosition e IsMouseButtonDown.
local CX, CY, BOTON = 600, 400, nil
GetCursorPosition = function() return CX, CY end
IsMouseButtonDown = function(b) return BOTON ~= nil and (b == nil or b == BOTON) end
local reloj = 1000
GetTime = function() return reloj end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
local A, N = Alfa, AlfaNucleo
local K = N.Kit
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end

---------------------------------------------------------------------------
-- 1. La bienvenida, de principio a fin
---------------------------------------------------------------------------
local B = ns("Alfa_Bienvenida")
step("bienvenida: abrir", function() B.AbrirVentana("asistente") end)
T(2)
local bv = _G.AlfaBienvenidaVentana
local asis = bv and bv.alfaAsistente
if asis then
  for i = 1, #asis.pasos do step("bienvenida: paso " .. i, function() asis:Ir(i) end) T(1) end
  for i = #asis.pasos, 1, -1 do step("bienvenida: atrás " .. i, function() asis:Ir(i) end) end
  step("bienvenida: Siguiente hasta Listo", function()
    asis:Ir(1)
    for _ = 1, #asis.pasos + 1 do asis:Siguiente() T(1) end
  end)
  step("bienvenida: cerrar", function() if bv:IsShown() then bv:Hide() end end)
end
if AlfaBienvenida and AlfaBienvenida.Pendiente and AlfaBienvenida.Pendiente() then
  print("AVISO: la bienvenida sigue pendiente tras Listo; se sigue sin la puerta")
  AlfaBienvenida.Pendiente = function() return false end
end
step("bienvenida: portada", function() B.AbrirVentana("portada") T(1) bv:Hide() end)

-- Las notas de una versión nueva: alguien que ya configuró Alfa y vio una
-- versión vieja entra al juego: la intro del lobo y luego la ventana de notas.
step("notas: actualización (versión vista vieja)", function()
  if not (hay(B, "RevisarNotas") and B.VersionAlfa and B.VersionAlfa()) then
    print("AVISO: el banco no tiene versión de Alfa; las notas no se prueban") return
  end
  local d = N.Datos("bienvenida")
  d.versionVista = "1.0.0"
  if not B.RevisarNotas(0) then error("no hay notas que ver con una versión vista vieja") end
  local intro = _G.AlfaIntro
  if not (intro and intro:IsShown()) then error("la intro del lobo no salió antes de las notas") end
  for _, t in ipairs({ 0.3, 1, 1.6, 2.2, 2.8, 3.3, 3.9, 4.2, 4.7 }) do B.CuadroIntro(t) end
  T(2)
  if intro:IsShown() then error("la intro no terminó") end
  if not B.NotasVisibles() then error("la ventana de notas no se abrió tras la intro") end
  if B.CompararVersion(d.versionVista, B.VersionAlfa()) ~= 0 then error("la versión vista no se guardó") end
  _G.AlfaNotasVersion:Hide()
  if B.RevisarNotas(0) or B.NotasVisibles() then error("las notas salieron dos veces en la misma versión") end
end)
step("notas: abrir y cerrar en los 3 estilos", function()
  for _, estilo in ipairs({ "alfa", "clasico", "cristal" }) do
    K.SetEstilo(estilo) T(1)
    if not B.AbrirNotas() then error("no abrió las notas en " .. estilo) end
    T(1)
    _G.AlfaNotasVersion:Hide()
  end
  K.SetEstilo("alfa")
end)
step("notas: se esconden en combate y vuelven después", function()
  B.AbrirNotas() T(1)
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  if B.NotasVisibles() then error("las notas siguen abiertas en combate") end
  FIRE_EVENT("PLAYER_REGEN_ENABLED") T(3)
  if not B.NotasVisibles() then error("las notas no volvieron al salir del combate") end
  _G.AlfaNotasVersion:Hide()
end)
step("notas: ver todo lo nuevo (la portada)", function()
  B.AbrirNotas() T(1)
  B.Abrir("pedido", "portada") T(1)
  if bv then bv:Hide() end
end)

---------------------------------------------------------------------------
-- 2. Todas las páginas, en los 3 estilos
---------------------------------------------------------------------------
local PAGINAS = { "inicio", "rutas", "enciclopedia", "builds", "bolsas", "manada", "mazmorras", "mundo",
  "pesca", "lya", "vista", "comodidades", "comercio", "recoleccion", "combate", "curacion", "bienvenida", "cuero", "placas" }
for _, estilo in ipairs({ "alfa", "clasico", "cristal" }) do
  step("estilo " .. estilo, function() K.SetEstilo(estilo) end)
  T(1)
  for _, id in ipairs(PAGINAS) do
    step("página " .. id .. " (" .. estilo .. ")", function() A.Fire("SHOW_OPTIONS", id) end)
    T(1)
  end
end
step("estilo alfa", function() K.SetEstilo("alfa") end)
step("cerrar ajustes", function() local f = A.UI.Options.frame if f then f:Hide() end end)

---------------------------------------------------------------------------
-- 3. El mapa: navegar de verdad
---------------------------------------------------------------------------
local Mu = ns("Alfa_Mundo")
local V = Mu.Ventana
step("mapa: abrir (/alfa mapa)", function() A.RunCommand("mapa") end)
T(3)
local F = _G.AlfaMundoMapa
local vista = F and F.Vista
local function cuadros(n, dt)
  for _ = 1, n do
    reloj = reloj + (dt or 0.03)
    FIRE(vista, "OnUpdate", dt or 0.03)
  end
end
local function arrastrar(dx, dy, n)
  BOTON = "LeftButton"
  FIRE(vista, "OnMouseDown", "LeftButton")
  for k = 1, n do
    CX, CY = CX + dx / n, CY + dy / n
    cuadros(1, 0.016)
  end
  BOTON = nil
  FIRE(vista, "OnMouseUp", "LeftButton")
  cuadros(40)
end
if vista then
  step("mapa: zoom adentro", function() for _ = 1, 8 do V.Rueda(nil, 1) cuadros(4) end end)
  step("mapa: zoom afuera", function() for _ = 1, 14 do V.Rueda(nil, -1) cuadros(4) end end)
  step("mapa: arrastrar despacio", function() CX, CY = 600, 400 arrastrar(220, -140, 30) end)
  step("mapa: arrastrar rápido (inercia)", function() arrastrar(-600, 300, 4) end)
  step("mapa: hasta los bordes", function()
    for _, d in ipairs({ { 4000, 0 }, { -8000, 0 }, { 0, 4000 }, { 0, -8000 } }) do arrastrar(d[1], d[2], 10) end
  end)
  step("mapa: zoom máximo y arrastrar", function()
    for _ = 1, 20 do V.Rueda(nil, 1) cuadros(2) end
    arrastrar(300, 300, 15)
    arrastrar(-500, 120, 6)
  end)
  step("mapa: doble clic", function()
    FIRE(vista, "OnMouseDown", "LeftButton") FIRE(vista, "OnMouseUp", "LeftButton")
    reloj = reloj + 0.1
    FIRE(vista, "OnMouseDown", "LeftButton") FIRE(vista, "OnMouseUp", "LeftButton")
    cuadros(30)
  end)
  step("mapa: marcador con clic derecho", function()
    FIRE(vista, "OnMouseDown", "RightButton") FIRE(vista, "OnMouseUp", "RightButton")
    T(2)
    local ed = Mu.Editor
    if hay(ed, "Cerrar") then ed.Cerrar() end
  end)
  step("mapa: capas una por una", function()
    local C = Mu.Capas
    for _, g in ipairs(C.Grupos()) do
      for _, e in ipairs(g.capas) do C.Alternar(e) cuadros(2) C.Alternar(e) end
    end
    C.PonerLimpio(true) cuadros(3) C.PonerLimpio(false) cuadros(3)
  end)
  step("mapa: panel de capas", function() Mu.Panel.Alternar(F) T(1) Mu.Panel.Alternar(F) end)
  step("mapa: cambiar de tamaño", function()
    for _, s in ipairs({ { 520, 360 }, { 1400, 900 }, { 900, 600 } }) do
      F:SetSize(s[1], s[2]) FIRE(vista, "OnSizeChanged") cuadros(3)
    end
  end)
  step("mapa: zoom y arrastre tras cambiar de tamaño", function()
    for _ = 1, 6 do V.Rueda(nil, -1) cuadros(2) end
    arrastrar(120, 60, 10)
  end)
  -- El punto del mundo (0..1) bajo el cursor, sacado de lo que dibuja Marcas.
  local function bajoCursor()
    local Mc = Mu.Marcas
    local x0, y0 = Mc.AVista(0, 0)
    local x1, y1 = Mc.AVista(1, 1)
    local X, Y = CX - vista:GetLeft(), vista:GetTop() - CY
    return (X - x0) / (x1 - x0), (Y - y0) / (y1 - y0)
  end
  local function igual(nombre, u0, v0, tol)
    local u, v = bajoCursor()
    -- Desde la 1.1.7 la esquina del mapa cae en un píxel entero: se acepta
    -- hasta medio píxel en cada medida: un píxel entre dos (más la tolerancia de siempre).
    local Mc = Mu.Marcas
    local ancho = Mc.AVista(1, 1) - Mc.AVista(0, 0)
    local alto = select(2, Mc.AVista(1, 1)) - select(2, Mc.AVista(0, 0))
    local tu = (tol or 1e-4) + (ancho > 0 and 1.0 / ancho or 0)
    local tv = (tol or 1e-4) + (alto > 0 and 1.0 / alto or 0)
    if not (math.abs(u - u0) < tu and math.abs(v - v0) < tv) then
      error(nombre .. string.format(": el punto bajo el cursor se movió (%.5f, %.5f) -> (%.5f, %.5f) [%.1f px, %.1f px]", u0, v0, u, v, (u - u0) * ancho, (v - v0) * alto))
    end
  end
  local function alCentro()
    CX, CY = vista:GetLeft() + vista:GetWidth() / 2, vista:GetTop() - vista:GetHeight() / 2
  end
  -- Un pin del mapa de Alfa a la vista (un Button con su pin del motor).
  local function unPin()
    for _, hijo in ipairs({ vista:GetChildren() }) do
      for _, f in ipairs({ hijo:GetChildren() }) do
        if rawget(f, "amPin") and f:IsShown() and f._scripts.OnMouseDown then return f end
      end
    end
  end
  step("mapa: arrastrar empezando sobre un pin", function()
    A.Set("ui.reduceMotion", true) -- sin inercia: lo que se mide es el arrastre
    alCentro()
    for _ = 1, 6 do V.Rueda(nil, 1) cuadros(6) end
    cuadros(40)
    local pin = unPin()
    if not pin then
      local Mk, Geo = Mu.Marcadores, Mu.Geo
      local u, v = bajoCursor()
      local cont, zona = Geo.Cadena(u, v)
      local mapa = zona or cont
      local px, py = mapa and Geo.AMapa(mapa, u, v)
      if px then Mk.Crear({ mapa = mapa, x = px, y = py, nombre = "prueba" }) end
      T(1) cuadros(3)
      pin = unPin()
    end
    if not pin then print("AVISO: no hay pines en la vista del banco; arrastre sobre pin sin probar") return end
    local p = pin.amPin
    local clics = 0
    local original = rawget(p, "onClick")
    p.onClick = function() clics = clics + 1 end
    -- Arrastrar desde el pin: el mapa se mueve y el punto agarrado sigue bajo el cursor.
    local u0, v0 = bajoCursor()
    BOTON = "LeftButton"
    FIRE(pin, "OnMouseDown", "LeftButton")
    for _ = 1, 10 do CX, CY = CX + 4, CY - 3 cuadros(1, 0.016) end
    igual("arrastre desde un pin", u0, v0)
    BOTON = nil
    FIRE(pin, "OnMouseUp", "LeftButton")
    if pin.amPin ~= p then print("AVISO: el pin salió de la vista al arrastrar; el clic tras arrastrar no se mide") end
    FIRE(pin, "OnClick", "LeftButton")
    if clics ~= 0 then error("el clic del pin se disparó al soltar un arrastre") end
    p.onClick = original
    cuadros(20)
    -- Un clic normal en el pin sigue funcionando.
    p = pin.amPin
    if not p then print("AVISO: el pin ya no está a la vista; el clic normal no se mide") return end
    original = rawget(p, "onClick")
    p.onClick = function() clics = clics + 1 end
    reloj = reloj + 1
    BOTON = "LeftButton"
    FIRE(pin, "OnMouseDown", "LeftButton")
    cuadros(1, 0.016)
    BOTON = nil
    FIRE(pin, "OnMouseUp", "LeftButton")
    FIRE(pin, "OnClick", "LeftButton")
    if clics ~= 1 then error("el clic normal en un pin no se disparó (" .. clics .. ")") end
    p.onClick = original
    cuadros(10)
  end)
  step("mapa: rueda mientras arrastras", function()
    alCentro()
    for _ = 1, 4 do V.Rueda(nil, -1) cuadros(2) end -- lejos del tope: la rueda tiene que acercar
    cuadros(60)
    CX, CY = CX - 150, CY + 100 -- lejos del centro: ahí se nota si el zoom mueve lo agarrado
    cuadros(2)
    local escala0 = Mu.Marcas.AVista(1, 0) - Mu.Marcas.AVista(0, 0)
    local u0, v0 = bajoCursor()
    BOTON = "LeftButton"
    FIRE(vista, "OnMouseDown", "LeftButton")
    for i = 1, 30 do
      CX, CY = CX + 4, CY - 3 -- hacia el centro del mundo (lejos del borde que deja la prueba anterior)
      if i == 10 or i == 20 then V.Rueda(nil, 1) end
      cuadros(1, 0.016)
    end
    if not (Mu.Marcas.AVista(1, 0) - Mu.Marcas.AVista(0, 0) > escala0 * 1.2) then error("la rueda no acercó durante el arrastre") end
    igual("zoom durante el arrastre", u0, v0)
    -- Soltar con el zoom todavía animándose: no salta al ancla vieja.
    V.Rueda(nil, -1)
    cuadros(1, 0.016)
    local u1, v1 = bajoCursor()
    BOTON = nil
    FIRE(vista, "OnMouseUp", "LeftButton")
    cuadros(40)
    igual("zoom tras soltar", u1, v1, 1e-3)
    A.Set("ui.reduceMotion", false)
  end)
  step("mapa: cerrar y abrir", function()
    V.Cerrar() T(1) V.Abrir() T(2) cuadros(5) V.Alternar() T(1) V.Alternar() T(2) cuadros(5)
  end)
  step("mapa: cerrar", function() V.Cerrar() end)
else
  print("AVISO: el mapa no tiene área de dibujo en el banco (sin arte)")
end

---------------------------------------------------------------------------
-- 4. Las ventanas de cada módulo
---------------------------------------------------------------------------
local En = ns("Alfa_Enciclopedia")
for _, q in ipairs({ { texto = "lobo" }, { texto = "espada" }, { texto = "Ventormenta" }, { kind = "guia", id = "montura" }, { kind = "guia", id = "legado" } }) do
  step("enciclopedia: " .. tostring(q.texto or q.id), function() En.V.Abrir(q) end)
  T(3)
end
step("enciclopedia: cerrar", function() if _G.AlfaEnciclopediaVentana then _G.AlfaEnciclopediaVentana:Hide() end end)

local Ru = ns("Alfa_Rutas")
step("ruta: asistente", function()
  Ru.Asistente.Abrir() T(2)
  local w = _G.AlfaAsistente
  local a = w and (w.alfaAsistente or w.asis)
  if a and a.Siguiente then for _ = 1, 6 do a:Siguiente() T(1) end end
  if w then w:Hide() end
end)
step("ruta: biblioteca", function() if hay(Ru.Biblioteca, "Abrir") then Ru.Biblioteca.Abrir() T(2) end if _G.AlfaBiblioteca then _G.AlfaBiblioteca:Hide() end end)
step("ruta: seguimiento", function() Ru.Rastreador.Mostrar() T(2) end)
step("ruta: buscar cerca", function() if AlfaCerca then AlfaCerca.Menu() T(1) AlfaCerca.Cerrar() end end)
step("ruta: mis planes", function()
  if not AlfaPlanes then return end
  local pl = AlfaPlanes.Nuevo("Prueba")
  if pl then
    AlfaPlanes.AgregarMeta(pl.id, { tipo = "nivel", nivel = 30 })
    AlfaPlanes.AgregarMeta(pl.id, { tipo = "nota", texto = "Nota de prueba" })
    AlfaPlanes.Abrir(pl.id) T(2)
    AlfaPlanes.Seguir(pl.id) T(2)
    AlfaPlanes.Dejar()
  end
  if _G.AlfaPlanEditor then _G.AlfaPlanEditor:Hide() end
end)

local Pe = ns("Alfa_Pesca")
for _, tab in ipairs({ "diario", "estadisticas", "guia", "cocina", "logros" }) do
  step("pesca: " .. tab, function() Pe.V.Abrir(tab) end)
  T(2)
end
step("pesca: modo", function() Pe.AbrirModo() T(2) Pe.CerrarModo() end)
step("pesca: cerrar", function() if _G.AlfaPescaVentana then _G.AlfaPescaVentana:Hide() end end)

step("paisaje: abrir, preajuste y deshacer", function()
  if not AlfaVista then return end
  AlfaVista.Abrir() T(2)
  AlfaVista.AplicarPreset("manada") T(2)
  AlfaVista.Deshacer() T(2)
  if _G.AlfaVistaVentana then _G.AlfaVistaVentana:Hide() end
end)

step("reportar", function()
  if AlfaReporte and AlfaReporte.Abrir then AlfaReporte.Abrir("error") T(1) end
  if _G.AlfaReporteVentana then _G.AlfaReporteVentana:Hide() end
end)

---------------------------------------------------------------------------
-- 5. Lya
---------------------------------------------------------------------------
local Ly = ns("Alfa_Lya")
local UI = Ly and Ly.UI
if UI then
  step("lya: mostrar", function() N.Set("lya", "mostrar", true) if Ly.Cerebro and Ly.Cerebro.Aplicar then Ly.Cerebro.Aplicar() end T(2) end)
  for _, p in ipairs({ "cola", "correr", "sentada", "pedir", "estirarse", "aullar", "dormir" }) do
    step("lya: pose " .. p, function() if UI.Pose then UI.Pose(p, 1.5) end T(3) end)
  end
  step("lya: pose al azar y gesto", function() if UI.Pose then UI.Pose() end UI.Gesto() T(3) end)
  step("lya: hablar con hambre", function() UI.Hablar({ texto = "Tengo hambre", pose = "pedir" }) T(3) UI.Callar() end)
  step("lya: dormir y despertar", function() UI.Dormir(true) T(2) UI.Dormir(false) T(2) end)
  step("lya: aullar", function() UI.Aullar() T(4) end)
  step("lya: pedir consejo", function() if Ly.Cerebro and Ly.Cerebro.Pedir then Ly.Cerebro.Pedir() end T(3) end)
  step("lya: historias", function() if AlfaLya and AlfaLya.Historias then AlfaLya.Historias() T(2) end if _G.AlfaLyaHistorias then _G.AlfaLyaHistorias:Hide() end end)
end

---------------------------------------------------------------------------
-- 6. Combate y eventos del juego
---------------------------------------------------------------------------
local enCombate = false
InCombatLockdown = function() return enCombate end
step("combate: entrar", function() enCombate = true FIRE_EVENT("PLAYER_REGEN_DISABLED") T(3) end)
step("combate: salir", function() enCombate = false FIRE_EVENT("PLAYER_REGEN_ENABLED") T(3) end)
for _, ev in ipairs({ { "BAG_UPDATE", 0 }, { "BAG_UPDATE_DELAYED" }, { "QUEST_LOG_UPDATE" }, { "ZONE_CHANGED_NEW_AREA" },
  { "ZONE_CHANGED" }, { "PLAYER_LEVEL_UP", 24 }, { "PLAYER_XP_UPDATE", "player" }, { "UPDATE_EXHAUSTION" },
  { "UNIT_AURA", "player" }, { "PLAYER_MONEY" }, { "MERCHANT_SHOW" }, { "MERCHANT_CLOSED" }, { "PLAYER_DEAD" },
  { "PLAYER_ALIVE" }, { "PLAYER_UNGHOST" }, { "UPDATE_INVENTORY_DURABILITY" }, { "GROUP_ROSTER_UPDATE" } }) do
  step("evento " .. ev[1], function() FIRE_EVENT(ev[1], select(2, unpack(ev))) T(2) end)
end
T(20)
print(("PRUEBA: %d pasos, %d errores"):format(pasos, #ERRORS))
