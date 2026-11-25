-- Prueba de la 1.4.0, área hud (tools/prueba.py la corre con las demás prueba_*.lua):
--   80. el rastreador renovado: jerarquía (guía y avance, el paso grande, las
--       metas con su ícono y su conteo a la derecha, la distancia discreta),
--       el globo de ayuda al lado (nunca encima de la cabecera) y solo tras
--       quedarse el ratón, textos completos, letra grande;
--   81. los avisos (K.Aviso) con su estilo nuevo: firma del módulo, botones,
--       un solo lugar (junto a la flecha, sin tapar el rastreador ni la
--       flecha), la pila ordenada, sin atrapar clics en combate.
-- Con BANCO_FOTOS=1 dibuja las capturas (shot-140-hud-*.png); con
-- BANCO_HUD_ANTES=1 solo las capturas (para comparar con la versión de antes).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local ANTES = os and os.getenv and os.getenv("BANCO_HUD_ANTES")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["140-hud-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not ANTES and not cond then NOTE("1.4.0 hud", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

-- La pantalla de un 1920 x 1080 con la escala automática del juego: la
-- interfaz mide 1365 x 768.
PANTALLA_SIMULADA(1365, 768)

function UnitFactionGroup() return "Alliance", "Alianza" end
function UnitLevel() return 33 end
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
local E = A.Engine
local Ru = NS_OF("Alfa_Rutas")
local Rs = Ru.Rastreador

---------------------------------------------------------------------------
-- El escenario: una noche (nada de verde liso)
---------------------------------------------------------------------------
local function escenario(w, h, punto, x, y)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetSize(w, h)
  f:SetPoint(punto or "TOPRIGHT", UIParent, punto or "TOPRIGHT", x or 0, y or 0)
  local t = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  t:SetAllPoints(f)
  t:SetTexture("white")
  t:SetGradient("VERTICAL", CreateColor(0.05, 0.055, 0.07, 1), CreateColor(0.12, 0.13, 0.17, 1))
  local semilla = 11
  for _ = 1, math.floor(w * h / 9000) do
    semilla = (semilla * 1103515245 + 12345) % 2147483648
    local a = semilla / 2147483648
    semilla = (semilla * 1103515245 + 12345) % 2147483648
    local b = semilla / 2147483648
    local s = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    s:SetSize(1.5, 1.5)
    s:SetPoint("TOPLEFT", f, "TOPLEFT", a * w, -b * h * 0.6)
    s:SetColorTexture(0.8, 0.82, 0.9, 0.35)
  end
  return f
end

---------------------------------------------------------------------------
-- Una guía como la del juego: «Cerrar mis misiones», 13 pasos, en «Muertes
-- nobles» con «Mata a Espía de la Hermandad para obtener Sello de Alterac 0/7».
---------------------------------------------------------------------------
local function guia(nombre, pasos)
  local id = Ru.Guias.IdRuta(nombre)
  local ok = Ru.Guias.Instalar(Ru.Guias.Def(id, nombre, pasos))
  check(ok, "no se instaló la guía " .. nombre)
  Ru.Guias.Abrir(id) T(3)
  return id
end
local p = {}
for i = 1, 13 do p[i] = { title = "Paso " .. i, goals = { { t = "goto", map = 1436, x = 10 + i * 3, y = 85, text = "Ve al lugar " .. i } } } end
p[1].title = "Muertes nobles"
guia("Cerrar mis misiones", p)

-- Las metas del paso de ahora, como las da el motor en el juego.
local gsv = E.GetStepView
local METAS
local function vistaJuego(i)
  local v = gsv(i)
  if v and METAS and v.index == 1 then
    local goals = {}
    for k, g in ipairs(METAS) do
      local c = {}
      for a, b in pairs(g) do c[a] = b end
      c.index = k
      goals[k] = c
    end
    v.goals, v.current = goals, 1
    v.groups = { { goals = {} } }
    for k = 1, #goals do v.groups[1].goals[k] = k end
  end
  return v
end
E.GetStepView = vistaJuego
METAS = {
  { t = "collect", status = "active", text = "Mata a Espía de la Hermandad para obtener Sello de Alterac", progress = { cur = 0, max = 7 } },
  { t = "kill", status = "active", text = "Mata a Jabalí moteado", progress = { cur = 3, max = 8 } },
  { t = "turnin", status = "pending", text = "Entrega Muertes nobles a Mariscal Dughan" },
}
-- La flecha: lejos, al norte.
local Nav = A.Nav
local gt, to = Nav.GetTarget, Nav.TargetOffset
Nav.GetTarget = function() return { label = "Espía de la Hermandad", r = 8 } end
Nav.TargetOffset = function() return 5549, 0 end
local FS = A.FormatDistance
A.FormatDistance = function(d) return string.format("%d yd", math.floor(d + 0.5)) end

local function rect(f) return f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop() end
local function seEnciman(a, b, m)
  m = m or 0
  local al, ar, ab, at = rect(a)
  local bl, br, bb, bt = rect(b)
  if not (al and bl) then return false end
  return al < br - m and ar > bl + m and ab < bt - m and at > bb + m
end
-- Cada texto a la vista bajo el rastreador queda adentro de él (nada se sale).
local function textosAdentro(F, que)
  local l, r = F:GetLeft(), F:GetRight()
  local function walk(f)
    if not f:IsShown() then return end
    for _, c in ipairs(f._children) do
      if c._kind == "FontString" then
        if c._shown and c._text and c._text ~= "" then
          local cl, cr = c:GetLeft(), c:GetRight()
          if cl and cr then check(cl >= l - 0.5 and cr <= r + 0.5, que .. ": un texto se sale del rastreador: " .. c._text) end
        end
      elseif c._kind ~= "Texture" then
        walk(c)
      end
    end
  end
  walk(F)
end
-- Las filas de metas a la vista: su conteo a la derecha, sin encimarse con su texto.
local function revisarMetas(F, que)
  local n = 0
  for _, f in ipairs(F._children) do
    if f.Cuenta and f.Marca and f:IsShown() then
      n = n + 1
      if f.Cuenta:IsShown() then
        check(math.abs(f.Cuenta:GetRight() - f:GetRight()) < 1, que .. ": el conteo no va pegado a la derecha")
        check(f.Texto:GetRight() <= f.Cuenta:GetLeft() + 0.5, que .. ": el texto de la meta se encima con su conteo")
        check(not f.Texto._text:find("%d+/%d+"), que .. ": el conteo sigue también en el texto: " .. f.Texto._text)
      end
      check(f.Marca.Ok:IsShown(), que .. ": la meta no lleva su ícono")
    end
  end
  return n
end

---------------------------------------------------------------------------
step("80: el rastreador renovado", function()
  -- Lo de adentro: el conteo aparte y el ícono de cada meta.
  local l, c, lleno = Rs.SepararConteo("Mata a Jabalí moteado  |cffe8eee63/8|r")
  check(l == "Mata a Jabalí moteado" and c == "3/8" and not lleno, "el conteo no se separa: " .. tostring(l) .. " / " .. tostring(c))
  l, c, lleno = Rs.SepararConteo("Junta Carne  |cff6bd99a6/6|r  |cfff0b34aopcional|r")
  check(c == "6/6" and lleno and l == "Junta Carne  |cfff0b34aopcional|r", "el conteo lleno no se separa bien: " .. tostring(l))
  l, c = Rs.SepararConteo("Objetivos: Lobos 2/5\nOsos 1/3")
  check(c == nil, "una meta con varios conteos no debe partirse")
  check(Rs.IconoMeta({ t = "kill" }) == "ic-raros" and Rs.IconoMeta({ t = "turnin" }) == "ic-misiones"
    and Rs.IconoMeta({ t = "rara" }) == "ic-huella", "los íconos de las metas no son los esperados")

  Rs.Mostrar() T(2)
  local F = rawget(_G, "AlfaRastreador")
  check(F and F:IsShown(), "el rastreador no se ve")
  Rs.Pintar()
  local fondo = escenario(760, 560, "TOPRIGHT", 0, -170)
  SNAP("rastreador", fondo, { F })
  check(revisarMetas(F, "compacto") >= 2, "el rastreador no pinta las metas del paso")
  textosAdentro(F, "compacto")
  -- Con el ratón encima (la vista completa del compacto) y el globo de la cabecera.
  local c = Rs.Piezas().cab
  K.OcultarInfo()
  FIRE(F, "OnEnter")
  FIRE(c, "OnEnter")
  local info = rawget(_G, "AlfaKitInfo")
  -- Pasar por encima no lo abre: sale solo si el ratón se queda.
  check(not (info and info:IsShown()), "el globo de la cabecera sale al instante (debe esperar al ratón)")
  T(2)
  info = rawget(_G, "AlfaKitInfo")
  check(info and info:IsShown(), "el globo de la cabecera no salió al quedarse el ratón")
  if os.getenv("HUD_DBG") then dofile(os.getenv("HUD_DBG")) end
  SNAP("rastreador-globo", fondo, { F, info })
  if info and info:IsShown() then
    -- Nunca encima del rastreador ni de lo que hay arriba de él: al lado.
    check(info:GetRight() <= F:GetLeft() + 0.5 or info:GetLeft() >= F:GetRight() - 0.5,
      "el globo de la cabecera se encima con el rastreador")
    check(info:GetBottom() < c:GetTop(), "el globo queda arriba de la cabecera (donde tapa lo de arriba)")
  end
  -- La flecha: la distancia a la izquierda, el tiempo a la derecha.
  local fl
  for _, x in ipairs(F._children) do if x.Tiempo and x.Icono and x:IsShown() then fl = x end end
  check(fl and fl.Tiempo:IsShown() and fl.Tiempo._text == "13 min", "el tiempo de la flecha no va a la derecha: " .. tostring(fl and fl.Tiempo._text))
  if fl and fl.Tiempo:IsShown() then
    check(fl.Texto:GetRight() <= fl.Tiempo:GetLeft() + 0.5, "la distancia se encima con el tiempo")
    check(fl.Texto._text:find("5549", 1, true) and not fl.Texto._text:find("min", 1, true), "la distancia trae el tiempo: " .. fl.Texto._text)
  end
  -- El sobretítulo del paso.
  local sobre = false
  for _, x in ipairs(F._children) do
    if x._kind == "FontString" and x._shown and type(x._text) == "string" and x._text:find("PASO 1", 1, true) then sobre = true end
  end
  check(sobre, "el paso no lleva su sobretítulo «PASO 1 · AHORA»")
  revisarMetas(F, "con el ratón encima")
  textosAdentro(F, "con el ratón encima")
  FIRE(c, "OnLeave")
  check(not info:IsShown(), "el globo no se fue al salir el ratón")
  -- Un paso por encima y fuera antes del tiempo: no sale.
  FIRE(c, "OnEnter")
  FIRE(c, "OnLeave")
  T(2)
  check(not info:IsShown(), "el globo salió aunque el ratón ya se había ido")
  -- Los botones de la cabecera también, al lado.
  FIRE(c.Menu, "OnEnter")
  T(2)
  if info:IsShown() then
    check(info:GetRight() <= F:GetLeft() + 0.5 or info:GetLeft() >= F:GetRight() - 0.5, "el globo de un botón de la cabecera se encima")
  end
  FIRE(c.Menu, "OnLeave")
  FIRE(F, "OnLeave")
  T(2)

  -- Letra grande: nada se sale ni se encima.
  A.Set("nucleo.letraGrande", true) T(2)
  FIRE(F, "OnEnter") T(1)
  Rs.Pintar()
  revisarMetas(F, "letra grande")
  textosAdentro(F, "letra grande")
  SNAP("rastreador-letra-grande", fondo, { F })
  FIRE(F, "OnLeave") T(2)
  A.Set("nucleo.letraGrande", false) T(2)

  -- La temática por bando: su tira bajo la cabecera.
  if K.ProbarBando and c.Tira then
    A.Set("nucleo.bando", true)
    K.ProbarBando("H") T(1)
    Rs.Pintar()
    check(c.Tira:IsShown(), "con la temática de la Horda, el rastreador no lleva su tira")
    SNAP("rastreador-horda", fondo, { F })
    K.ProbarBando("A") T(1)
    Rs.Pintar()
    SNAP("rastreador-alianza", fondo, { F })
    A.Set("nucleo.bando", false)
    K.ProbarBando(nil) T(1)
    Rs.Pintar()
    check(not c.Tira:IsShown(), "sin la temática, la tira sigue")
  end

  -- Se mueve igual que siempre: arrastrando la cabecera, y recuerda su lugar.
  local d = N.Datos("rutas")
  local antes = d.rastreador
  d.rastreador = nil
  FIRE(c, "OnMouseDown", "LeftButton")
  FIRE(c, "OnDragStart")
  FIRE(c, "OnDragStop")
  FIRE(c, "OnMouseUp", "LeftButton")
  check(type(d.rastreador) == "table", "al soltar la cabecera no guardó su lugar")
  check(not Rs.Plegada(), "arrastrar la cabecera la plegó")
  d.rastreador = antes
end)

---------------------------------------------------------------------------
-- 81. Los avisos
---------------------------------------------------------------------------
local function avisosDePrueba()
  local a1 = K.Aviso({ pedido = true, lya = false, modulo = "ruta", titulo = "3 misiones listas para entregar",
    texto = "Mariscal Dughan, Guardia Thomas y William Pestle te esperan en Villadorada.",
    accion = { texto = "Llévame", alClic = function() end }, acciones = { { texto = "Luego", alClic = function() end } }, duracion = 60 })
  local a2 = K.Aviso({ pedido = true, lya = false, modulo = "bolsas", titulo = "Tus bolsas casi llenas", texto = "Te quedan 2 espacios. Vende lo gris con un clic.",
    accion = { texto = "Vender lo gris", alClic = function() end }, duracion = 60 })
  local a3 = K.Aviso({ pedido = true, lya = false, modulo = "pesca", titulo = "¡Récord!", texto = "Tu pez más grande: Pargo rojo de 4,2 kg.", duracion = 60 })
  return a1, a2, a3
end

step("81: los avisos con su estilo y su lugar", function()
  local F = rawget(_G, "AlfaRastreador")
  Rs.Mostrar() Rs.Pintar()
  local flecha = rawget(_G, "AlfaNavArrow")
  if flecha and not flecha:IsShown() then flecha:Show() end
  check(K.AnclaAvisos and K.AnclaAvisos() == rawget(_G, "AlfaAvisosAncla"), "la pila de avisos no tiene su ancla con nombre")
  local a1, a2, a3 = avisosDePrueba()
  check(type(a1) == "table" and type(a2) == "table" and type(a3) == "table", "los avisos de prueba no salieron")
  if not (type(a1) == "table" and type(a2) == "table" and type(a3) == "table") then return end
  -- La pila ordenada: el más nuevo arriba, sin encimarse.
  check(a3:GetBottom() >= a2:GetTop() - 0.5 and a2:GetBottom() >= a1:GetTop() - 0.5, "la pila de avisos no va en orden o se encima")
  -- Ni el rastreador ni la flecha quedan debajo de un aviso.
  for _, a in ipairs({ a1, a2, a3 }) do
    check(not seEnciman(a, F), "un aviso tapa al rastreador: " .. tostring(a.Titulo._text))
    if flecha and flecha:IsShown() then check(not seEnciman(a, flecha), "un aviso tapa la flecha: " .. tostring(a.Titulo._text)) end
  end
  -- Y el lugar de fábrica de la flecha (arriba al centro, a -140, 200 x 130).
  local w, h = PANTALLA_TAM()
  for _, a in ipairs({ a1, a2, a3 }) do
    local al, ar, ab, at = rect(a)
    local fl, fr, ft, fb = w / 2 - 100, w / 2 + 100, h - 140, h - 140 - 130
    check(not (al < fr and ar > fl and ab < ft and at > fb), "un aviso cae donde va la flecha de fábrica")
  end
  -- La firma de cada módulo en su banda; los botones a la derecha, el principal al final.
  check(a1.FirmaNombre._text == "RUTA" and a2.FirmaNombre._text == "BOLSAS" and a3.FirmaNombre._text == "PESCA",
    "la banda no dice de qué módulo viene: " .. tostring(a1.FirmaNombre._text))
  check(a1.Firma:IsShown() and a1.Baldosa:IsShown(), "sin el ícono de la firma o su baldosa")
  check(a1.Boton:IsShown() and a1.Boton2:IsShown() and a1.Boton:GetLeft() > a1.Boton2:GetRight(), "el botón principal no va a la derecha")
  check(math.abs(a1.Boton:GetRight() - (a1:GetRight() - K.ESP.m)) < 1, "los botones no van alineados a la derecha")
  for _, a in ipairs({ a1, a2, a3 }) do
    for _, fs in ipairs({ a.Titulo, a.Texto }) do
      if fs:IsShown() and fs._text ~= "" then
        check(fs:GetRight() <= a:GetRight() + 0.5 and fs:GetBottom() >= a:GetBottom() - 0.5, "un texto se sale de su aviso: " .. fs._text)
        check(fs:GetTop() <= a.Banda:GetBottom() + 0.5, "un texto se mete en la banda del aviso: " .. fs._text)
      end
    end
    if a.Boton and a.Boton:IsShown() then
      check(a.Boton:GetBottom() >= a:GetBottom() - 0.5, "un botón se sale de su aviso")
      check(a.Boton:GetTop() <= a.Texto:GetBottom() + 0.5, "un botón se encima con el texto")
    end
  end
  -- En combate no atrapan clics (ni la X ni sus botones).
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not a1:IsMouseEnabled() and not a1.BotonCerrar:IsMouseEnabled() and not a1.Boton:IsMouseEnabled(), "en combate un aviso atrapa clics")
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  check(a1:IsMouseEnabled(), "al acabar el combate el aviso no toma el ratón otra vez")
  -- Capturas: la pantalla entera (1920 x 1080 con escala automática) y los avisos de cerca.
  local pantalla = escenario(1365, 768, "TOPLEFT", 0, 0)
  local extra = { F }
  if flecha and flecha:IsShown() then extra[#extra + 1] = flecha end
  for _, a in ipairs({ a1, a2, a3 }) do extra[#extra + 1] = a end
  SNAP("pantalla", pantalla, extra)
  local cerca = escenario(440, 420, "TOPLEFT", (a1:GetLeft() or 0) - 40, -((h - (a3:GetTop() or 0)) - 20))
  SNAP("avisos", cerca, { a1, a2, a3 })
  -- Con la temática de la Alianza.
  if K.ProbarBando then
    A.Set("nucleo.bando", true)
    K.ProbarBando("A") T(1)
    for _, a in ipairs({ a1, a2, a3 }) do a:Cerrar() end
    local b1, b2, b3 = avisosDePrueba()
    if type(b1) == "table" and b1.Tira then
      check(b1.Tira:IsShown(), "con la temática por bando, el aviso no lleva su tira")
      SNAP("avisos-alianza", cerca, { b1, b2, b3 })
    end
    for _, a in ipairs({ b1, b2, b3 }) do if type(a) == "table" then a:Cerrar() end end
    A.Set("nucleo.bando", false)
    K.ProbarBando(nil) T(1)
  end
  -- Cerrar: se va (en el banco, al instante) y el de abajo sube.
  local x1, x2 = avisosDePrueba()
  if type(x1) == "table" and type(x2) == "table" then
    local arriba = x2:GetTop()
    x2:Cerrar()
    check(not x2:IsShown() and not x2.alfaVivo, "el aviso no se fue al cerrarlo")
    check(math.abs(x1:GetTop() - arriba) < 1, "al irse uno, el de abajo no subió a su lugar")
  end
  for _, a in ipairs(K.Avisos and K.Avisos() or {}) do if a.alfaVivo then a:Cerrar() end end
  -- Un aviso con el lobo y sin texto, y uno de peligro: se arman sin errores y caben.
  local lobo = K.Aviso({ pedido = true, lya = false, titulo = "Lya te espera", lobo = "aullando" })
  local peligro = K.Aviso({ pedido = true, lya = false, titulo = "¡Cuidado!", texto = "Un élite camina hacia ti.", tono = "peligro" })
  check(type(lobo) == "table" and lobo:GetHeight() >= K.AVISO_BANDA + K.AVISO_BALDOSA, "el aviso del lobo no cabe")
  if type(lobo) == "table" then lobo:Cerrar() end
  if type(peligro) == "table" then peligro:Cerrar() end
end)

Nav.GetTarget, Nav.TargetOffset, A.FormatDistance = gt, to, FS
E.GetStepView = gsv

