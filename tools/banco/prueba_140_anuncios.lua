-- Prueba de la 1.4.0, n.º 77: los anuncios rehechos (pedido de Toxic: «los
-- anuncios siguen sin estar centrados, hubo uno que me apareció cerca del
-- mapa, y esos anuncios de pueblos, mapa nuevo, estancia, lugar y demás siguen
-- igual; quiero ver una mejora bastante clara en todos los anuncios»).
--   1. la hoja de todos los tipos (con BANCO_FOTOS; ANUNCIOS_FASE=antes|despues);
--   2. siempre centrado en la pantalla: 1920×1080, 2560×1440 y al volver de
--      Dos pantallas; la placa de la flecha junto al mapa ya no se lo lleva;
--   3. un ancla única que se mueve (K.AnclaAnuncio, K.MoverAnuncio, «Volver»)
--      y nunca queda fuera de la pantalla;
--   4. la identidad nueva: velo de cine, líneas de luz, medallón con el dibujo
--      de cada tipo (uno distinto por tipo), jerarquía tipo / nombre / línea;
--   5. ui.reduceMotion: sin movimiento, solo el fundido;
--   6. nunca atrapa clics (ni la franja, ni en combate) y se va pronto;
--   7. ningún texto cortado en los 10 idiomas.
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local FASE = (os and os.getenv and os.getenv("ANUNCIOS_FASE")) or "despues"
local SOLO_HOJA = os and os.getenv and os.getenv("ANUNCIOS_SOLO_HOJA")
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.4.0 anuncios", msg) end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(5)

local N = AlfaNucleo
local A = N.A
local K = N.Kit
local Z = N.Zonas
A.Set("bienvenida.anuncios", true)
if N.Entrando then N.Entrando = function() return false end end
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end

local function anuncio() return rawget(_G, "AlfaAnuncio") end
local function correr(seg, dt)
  dt = dt or 0.05
  local t = 0
  while t < seg do
    NOW = NOW + dt
    local f = anuncio()
    if f and f:IsShown() then FIRE(f, "OnUpdate", dt) end
    t = t + dt
  end
end
local function limpiar()
  K.QuitarAnuncio()
  NOW = NOW + 10
  if Z and Z.Olvidar then Z.Olvidar() end
  RUN_TIMERS(2)
end
local function cerca(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 1.5) end

-- Los de la hoja: lo que diría Alfa de verdad en cada caso.
local VERDE = K.Hex and ("|c" .. K.Hex("exito")) or "|cff7fd36b"
local MUESTRAS = {
  { "zona", { estilo = "zona", color = "exito", sobre = "Tierra amiga", titulo = "Mulgore",
    texto = "Aldea Pezuña de Sangre  ·  " .. VERDE .. "Niveles 1–10|r\n2 de tus misiones son de aquí" } },
  { "subzona", { estilo = "subzona", color = "exito", sobre = "Mulgore", titulo = "Aldea Pezuña de Sangre", texto = "2 de tus misiones son de aquí" } },
  { "descubrir", { estilo = "descubrir", sobre = "¡Descubriste un lugar nuevo!", titulo = "Lago Mirkfallon",
    texto = "+120 de experiencia  ·  Mulgore\nLya: «Los centauros cuidan estas aguas desde hace siglos.»" } },
  { "ciudad", { estilo = "ciudad", sobre = "Un lugar para descansar", titulo = "Posada de Cima del Trueno",
    texto = "Descanso acumulado: 35% de un nivel" } },
  { "mazmorra", { estilo = "mazmorra", sobre = "Entras a una mazmorra", titulo = "Cuevas de los Lamentos",
    texto = "Niveles 17–24  ·  5 jefes" } },
  { "banda", { estilo = "banda", sobre = "Entras a una banda", titulo = "Núcleo de Magma", texto = "Nivel 60  ·  10 jefes" } },
  { "peligro", { estilo = "peligro", color = "peligro", sobre = "Zona peligrosa", titulo = "Desolace",
    texto = "Zona de nivel 30–40 y tú eres 24: ve con cuidado", alClic = function() end, pista = "Clic: llévame a una zona de mi nivel" } },
  { "barco", { estilo = "barco", sobre = "La manada viaja", titulo = "El barco a Theramore ya viene",
    cuenta = { seg = 95, formato = "Llega en %s", final = "¡Ya llegó!" } } },
  { "zepelin", { estilo = "zepelin", sobre = "La manada viaja", titulo = "El zepelín a Entrañas ya viene",
    cuenta = { seg = 40, formato = "Llega en %s", final = "¡Ya llegó!" } } },
  { "tranvia", { estilo = "tranvia", sobre = "La manada viaja", titulo = "El tranvía a Forjaz ya viene",
    cuenta = { seg = 25, formato = "Llega en %s", final = "¡Ya llegó!" } } },
  { "raro", { estilo = "raro", sobre = "Lya olfateó un raro", titulo = "Mor'Ladim", texto = "Élite  ·  nivel 35  ·  a 120 m",
    alClic = function() end, pista = "Clic: ir de caza" } },
  { "tesoro", { estilo = "tesoro", sobre = "Lya encontró un tesoro", titulo = "Un cofre escondido", texto = "Bosque del Ocaso  ·  a 60 m" } },
  { "manada", { estilo = "manada", sobre = "Un lobo de La Jauría anda cerca", titulo = "Lobato", texto = "También usa Alfa: salúdalo." } },
  { "nivel", { estilo = "nivel", sobre = "La manada aúlla", titulo = "¡Nivel 60!", texto = "Llegaste a la cima, alfa. Lya está orgullosa de ti." } },
  { "llegada", { estilo = "llegada", sobre = "Llegaste", titulo = "Cima del Trueno", texto = "Tu ruta sigue en el elevador del este." } },
}

-- Una noche con estrellas y un horizonte (nada de verde liso).
local function fondoNoche(l, b, w, h)
  local fondo = CreateFrame("Frame", nil, UIParent)
  fondo:SetFrameStrata("BACKGROUND")
  fondo:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
  fondo:SetSize(w, h)
  local c = fondo:CreateTexture(nil, "BACKGROUND")
  c:SetAllPoints(fondo)
  c:SetTexture("white")
  c:SetGradient("VERTICAL", CreateColor(0.10, 0.12, 0.14, 1), CreateColor(0.03, 0.05, 0.10, 1))
  for i = 1, math.floor(w * h / 9000) do
    local s = fondo:CreateTexture(nil, "BACKGROUND", nil, 2)
    local t = (i % 3 == 0) and 2 or 1
    s:SetSize(t, t)
    s:SetPoint("TOPLEFT", fondo, "TOPLEFT", (i * 97 + i * i * 7) % w, -((i * 53 + i * 11) % math.floor(h * 0.7)))
    s:SetColorTexture(0.85, 0.87, 0.95, 0.25 + (i % 4) * 0.12)
  end
  -- Las colinas.
  for i = 0, 9 do
    local m = fondo:CreateTexture(nil, "BACKGROUND", nil, 3)
    m:SetColorTexture(0.05, 0.07, 0.07, 1)
    local mw = w / 6
    m:SetSize(mw, h * (0.10 + ((i * 37) % 11) / 100))
    m:SetPoint("BOTTOMLEFT", fondo, "BOTTOMLEFT", i * w / 10 - mw * 0.2, 0)
  end
  fondo:Show()
  return fondo
end

local GRADIENTES = { "RayaI", "RayaD", "BandaI", "BandaD", "LineaI", "LineaD" }
local function paraFoto(f)
  for _, n in ipairs(GRADIENTES) do if f[n] then f[n]._tex = "white" end end
end

---------------------------------------------------------------------------
-- 1. La hoja de todos los tipos
---------------------------------------------------------------------------
step("1. La hoja de todos los tipos", function()
  PANTALLA_SIMULADA(1920, 1080)
  for _, m in ipairs(MUESTRAS) do
    limpiar()
    local o = {}
    for k, v in pairs(m[2]) do o[k] = v end
    if not K.ESTILOS_ANUNCIO[o.estilo] then o.estilo = (o.estilo == "banda" and "mazmorra") or (o.estilo == "nivel" and "llegada") or "general" end
    o.ya, o.clave, o.espaciar, o.segundos = true, "probar", false, 8
    if o.cuenta then o.cuenta = { hasta = GetTime() + o.cuenta.seg, formato = o.cuenta.formato, final = o.cuenta.final } end
    check(K.Anuncio(o), m[1] .. ": no salió")
    local f = anuncio()
    if f and f:IsShown() then
      correr(1.8)
      check(f:IsShown(), m[1] .. ": se fue antes de verse")
      if FOTOS then
        paraFoto(f)
        local fl, fb, fw, fh = f:GetRect()
        local fondo = fondoNoche(fl - 200, fb - 40, fw + 400, fh + 80)
        SNAP("140-anuncio-" .. FASE .. "-" .. m[1], fondo, { f })
        fondo:Hide()
      end
    end
  end
  -- Toda la pantalla: dónde sale (con la placa de la flecha junto al mapa).
  if FOTOS then
    limpiar()
    if not (A.Nav and A.Nav.arrow) then A.Nav = A.Nav or {} A.Nav.arrow = {} end
    local Ar = A.Nav.arrow
    local real = Ar and Ar.PlacaMarco
    local p = CreateFrame("Frame", "AlfaPruebaPlaca140", UIParent)
    p:SetSize(264, 72) p:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -40) p:Show()
    local pt = p:CreateTexture(nil, "ARTWORK") pt:SetAllPoints(p) pt:SetColorTexture(0.12, 0.14, 0.18, 0.95)
    local pl = K.Texto(p, "cuerpo", "texto") pl:SetPoint("CENTER", p, "CENTER", 0, 0) pl:SetText("Placa de la flecha (junto al mapa)")
    local mm = CreateFrame("Frame", nil, UIParent)
    mm:SetSize(180, 180) mm:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
    local mt = mm:CreateTexture(nil, "ARTWORK") mt:SetAllPoints(mm) mt:SetTexture("circle") mt:SetVertexColor(0.2, 0.3, 0.25, 1)
    if Ar then Ar.PlacaMarco = function() return p end end
    local o = {}
    for k, v in pairs(MUESTRAS[1][2]) do o[k] = v end
    o.ya, o.clave, o.espaciar = true, "probar", false
    K.Anuncio(o)
    RUN_TIMERS(6)
    correr(1.8)
    local f = anuncio()
    if f and f:IsShown() then
      paraFoto(f)
      local fondo = fondoNoche(0, 0, 1920, 1080)
      local cx = fondo:CreateTexture(nil, "BACKGROUND", nil, 4)
      cx:SetColorTexture(1, 1, 1, 0.08) cx:SetSize(1, 1080) cx:SetPoint("TOP", fondo, "TOP", 0, 0)
      SNAP("140-anuncio-" .. FASE .. "-pantalla", fondo, { f, mm, p })
      fondo:Hide()
    end
    if Ar then Ar.PlacaMarco = real end
    p:Hide() mm:Hide()
  end
  limpiar()
end)

---------------------------------------------------------------------------
-- 1b. El fondo sobre 5 lugares (con ANUNCIOS_FONDOS=1: la carpeta de build
-- trae las imágenes de muestra prueba-fondo-*.png; ver el informe).
---------------------------------------------------------------------------
local LUGARES = { "nieve", "desierto", "bosque", "cueva", "barco", "real-barco", "real-camino" }
local FONDOS_ANUNCIO = { "placa", "cinta", "filigrana", "suave", "nada" }
if FOTOS and os.getenv("ANUNCIOS_FONDOS") then
  step("1b. El fondo sobre la nieve, el desierto, el bosque, la cueva y el barco", function()
    PANTALLA_SIMULADA(1920, 1080)
    local modos = (FASE == "antes") and { "velo" } or FONDOS_ANUNCIO
    local tipos = {
      { "zona", { estilo = "zona", color = "aviso", sobre = "Llegas a", titulo = "Marjal Revolcafango",
        texto = "Mare Magnum  ·  " .. (K.Hex and ("|c" .. K.Hex("aviso")) or "") .. "Niveles 35–45|r" } },
      { "subzona", { estilo = "subzona", color = "aviso", sobre = "Marjal Revolcafango", titulo = "Colina de las Brujas" } },
    }
    for _, modo in ipairs(modos) do
      if modo ~= "velo" then A.Set("anuncios.fondo", modo) end
      for _, lugar in ipairs(LUGARES) do
        for _, m in ipairs(tipos) do
          limpiar()
          local o = {}
          for k, v in pairs(m[2]) do o[k] = v end
          o.ya, o.clave, o.espaciar, o.segundos = true, "probar", false, 8
          K.Anuncio(o)
          correr(1.8)
          local f = anuncio()
          if f and f:IsShown() then
            paraFoto(f)
            local fl, fb, fw, fh = f:GetRect()
            local fondo = CreateFrame("Frame", nil, UIParent)
            fondo:SetFrameStrata("BACKGROUND")
            fondo:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", fl - 160, fb - 30)
            fondo:SetSize(fw + 320, fh + 60)
            local t = fondo:CreateTexture(nil, "BACKGROUND")
            t:SetAllPoints(fondo)
            t:SetTexture("Interface\\AddOns\\Alfa_Nucleo\\Media\\prueba-fondo-" .. lugar)
            fondo:Show()
            SNAP("140-fondo-" .. modo .. "-" .. lugar .. "-" .. m[1], fondo, { f })
            fondo:Hide()
          end
        end
      end
    end
    A.Set("anuncios.fondo", nil)
    limpiar()
  end)
end

if SOLO_HOJA then return end

---------------------------------------------------------------------------
-- 2. Siempre centrado en la pantalla
---------------------------------------------------------------------------
local function centroX()
  local f = anuncio()
  local l, _, w = f:GetRect()
  return l + w / 2
end
step("2. Centrado a 1920×1080 y 2560×1440, y al volver de Dos pantallas", function()
  check(type(K.AnclaAnuncio) == "function", "falta K.AnclaAnuncio")
  A.Set("anuncios.pos", nil)
  for _, t in ipairs({ { 1920, 1080 }, { 2560, 1440 } }) do
    PANTALLA_SIMULADA(t[1], t[2])
    limpiar()
    K.Anuncio({ estilo = "zona", titulo = "Mulgore", sobre = "Tierra amiga", texto = "Niveles 1–10", ya = true })
    correr(1)
    local f = anuncio()
    check(f and f:IsShown(), t[1] .. ": no salió")
    if f and f:IsShown() then
      check(cerca(centroX(), t[1] / 2), t[1] .. ": no está centrado (" .. tostring(centroX()) .. ")")
      local _, b, _, h = f:GetRect()
      check(b > t[2] * 0.5, t[1] .. ": tapa el centro de la pantalla (abajo en " .. b .. ")")
      check(b + h < t[2] - 20, t[1] .. ": se sale por arriba")
      local _, rel = f:GetPoint(1)
      check(rel == K.AnclaAnuncio(), t[1] .. ": no está anclado a su ancla")
    end
  end
  -- Dos pantallas: UIParent ocupa la mitad izquierda; al volver, la pantalla entera.
  PANTALLA_SIMULADA(3840, 1080)
  UIParent:ClearAllPoints()
  UIParent:SetPoint("BOTTOMLEFT", nil, "BOTTOMLEFT", 0, 0)
  UIParent:SetSize(1920, 1080)
  limpiar()
  K.Anuncio({ estilo = "zona", titulo = "Durotar", ya = true })
  correr(1)
  check(anuncio():IsShown() and cerca(centroX(), 960), "con Dos pantallas no está centrado en la pantalla del juego: " .. tostring(centroX()))
  UIParent:ClearAllPoints()
  UIParent:SetAllPoints(nil)
  UIParent._w, UIParent._h = nil, nil
  PANTALLA_SIMULADA(1920, 1080)
  limpiar()
  K.Anuncio({ estilo = "zona", titulo = "Los Baldíos", ya = true })
  correr(1)
  check(anuncio():IsShown() and cerca(centroX(), 960), "al volver de Dos pantallas no quedó centrado: " .. tostring(centroX()))
  limpiar()
end)

step("2b. La placa de la flecha junto al mapa ya no se lleva el anuncio", function()
  local Ar = A.Nav and A.Nav.arrow
  if not Ar then
    -- (si la flecha no cargó, una de mentira: lo que importa es la placa)
    print("AVISO: la flecha no cargó en el banco; placa de mentira")
    A.Nav = A.Nav or {}
    A.Nav.arrow = {}
    Ar = A.Nav.arrow
  end
  local real = Ar.PlacaMarco
  local p = CreateFrame("Frame", nil, UIParent)
  p:SetSize(264, 80) p:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -30) p:Show()
  Ar.PlacaMarco = function() return p end
  limpiar()
  K.Anuncio({ estilo = "zona", titulo = "Mulgore", ya = true })
  RUN_TIMERS(6)
  correr(0.5)
  local a = K.AnuncioActual()
  check(a and a.titulo == "Mulgore", "con la placa lejos, la zona no salió")
  check(cerca(centroX(), 960), "con la placa junto al mapa el anuncio no está centrado: " .. tostring(centroX()))
  check(not (a and a.bajoPlaca), "se movió por una placa que no estorba")
  -- La placa arriba al centro: el anuncio baja para no taparla, pero sigue centrado.
  p:ClearAllPoints() p:SetPoint("TOP", UIParent, "TOP", 0, -140)
  limpiar()
  K.Anuncio({ estilo = "zona", titulo = "Durotar" })
  RUN_TIMERS(6)
  correr(0.5)
  a = K.AnuncioActual()
  check(a and a.bajoPlaca, "con la placa encima no se acomodó")
  check(cerca(centroX(), 960), "al bajar por la placa dejó de estar centrado")
  local f = anuncio()
  local _, b, _, h = f:GetRect()
  local _, pb = p:GetRect()
  check(b + h <= pb + 1, "el anuncio quedó encima de la placa")
  Ar.PlacaMarco = real
  p:Hide()
  limpiar()
end)

---------------------------------------------------------------------------
-- 3. Un ancla única que se mueve
---------------------------------------------------------------------------
step("3. El ancla se mueve, se recuerda y vuelve al centro", function()
  local an = K.AnclaAnuncio()
  check(an and not an:IsMouseEnabled(), "el ancla atrapa clics")
  K.MoverAnuncio(300, 120)
  local pos = A.Get("anuncios.pos")
  check(type(pos) == "table" and pos.x == 300 and pos.y == 120, "no guardó dónde lo pusiste")
  limpiar()
  K.Anuncio({ estilo = "descubrir", titulo = "Lago Mirkfallon", ya = true })
  correr(1)
  check(cerca(centroX(), 960 + 300), "no salió donde lo pusiste: " .. tostring(centroX()))
  -- Fuera de la pantalla: se queda dentro.
  K.MoverAnuncio(5000, -5000)
  local ax, ay = an:GetCenter()
  check(ax < 1920 and ax > 0 and ay > 0 and ay < 1080, "el ancla quedó fuera de la pantalla")
  K.AnclaAnuncioVolver()
  check(A.Get("anuncios.pos") == nil, "«Volver» no olvidó el lugar")
  ax = an:GetCenter()
  check(cerca(ax, 960), "«Volver» no lo dejó centrado")
  -- En «Acomodar» (Kit/Movible.lua, n.º 78) junto con lo demás.
  if K.MovibleDe then check(K.MovibleDe("anuncio") ~= nil, "el anuncio no está en «Acomodar»") end
  limpiar()
end)

---------------------------------------------------------------------------
-- 4. La identidad nueva
---------------------------------------------------------------------------
step("4. Velo, líneas y medallón con el dibujo de cada tipo", function()
  local vistos = {}
  for _, m in ipairs(MUESTRAS) do
    limpiar()
    local o = {}
    for k, v in pairs(m[2]) do o[k] = v end
    o.ya, o.clave, o.espaciar = true, "probar", false
    K.Anuncio(o)
    correr(1.5)
    local f = anuncio()
    local a = K.AnuncioActual()
    check(a and a.estilo == m[1], m[1] .. ": no salió con su estilo")
    if f and a then
      check(f.Velo and f.Velo:IsShown() and (f.Velo:GetHeight() or 0) > 20, m[1] .. ": sin el velo de cine")
      check(not f.LineaI:IsShown() and not f.RayaI:IsShown(), m[1] .. ": con la placa sobran las líneas de lado a lado")
      -- Una sola forma de fondo (Toxic: «se distinguen las capas»): ni rectángulos
      -- detrás del nombre, ni banda pintada; la niebla difuminada y nada más.
      check(not f.BandaI:IsShown() and not f.BandaD:IsShown(), m[1] .. ": quedan los rectángulos detrás del nombre")
      check((f.Velo:GetAlpha() or 0) == 0, m[1] .. ": la banda se pinta (bloque con bordes)")
      -- De fábrica, la placa (1.4.0: «la mancha oscura no me gusta»): sin niebla.
      check(not f.Niebla:IsShown(), m[1] .. ": de fábrica no debe salir la sombra difuminada")
      check(f.Placa:IsShown() and f.PlacaBorde.on, m[1] .. ": sin la placa de fábrica")
      check((f.X:GetAlpha() or 0) == 0, m[1] .. ": la × se ve sin pasar el ratón")
      if a.chico then check(not f.X:IsShown(), m[1] .. ": el chico trae ×") end
      if not a.chico then
        check(f.Aro and f.Aro:IsShown() and f.Disco:IsShown(), m[1] .. ": sin el medallón")
        local tex = f.Lobo._tex or ""
        check(tex ~= "", m[1] .. ": el medallón no tiene dibujo")
        if a.glifo then
          check(not vistos[a.glifo], m[1] .. " tiene el mismo dibujo que " .. tostring(vistos[a.glifo]))
          vistos[a.glifo] = m[1]
        end
        -- Jerarquía: el tipo arriba (chico), el nombre grande, la línea abajo.
        local _, sb = f.Sobre:GetRect()
        local _, tb, _, th = f.Titulo:GetRect()
        check(sb >= tb + th - 1, m[1] .. ": el tipo no va arriba del nombre")
        local ts, ss = f.Titulo._font and f.Titulo._font[2] or 0, f.Sobre._font and f.Sobre._font[2] or 0
        check(ts > ss + 6, m[1] .. ": el nombre no es claramente más grande que el tipo (" .. ts .. " / " .. ss .. ")")
      end
    end
  end
  local n = 0 for _ in pairs(vistos) do n = n + 1 end
  check(n >= 12, "pocos dibujos distintos: " .. n)
  limpiar()
end)

step("4b. «Sin fondo»: sin niebla, con contorno y sombra", function()
  A.Set("anuncios.fondo", "nada")
  limpiar()
  K.Anuncio({ estilo = "zona", titulo = "Mulgore", sobre = "Tierra amiga", texto = "Niveles 1–10", ya = true })
  correr(1.5)
  local f = anuncio()
  check(f:IsShown() and not f.Niebla:IsShown(), "sin fondo, la niebla sigue")
  local _, _, banderas = f.Titulo:GetFont()
  check(banderas == "OUTLINE", "sin fondo, el nombre no lleva contorno: " .. tostring(banderas))
  local _, sy = f.Titulo:GetShadowOffset()
  check(sy and sy < 0, "sin fondo, el nombre no lleva sombra")
  A.Set("anuncios.fondo", nil)
  check(K.FondoAnuncio() == "placa", "el fondo de fábrica no es la placa")
  limpiar()
end)

step("4c. Cada fondo con sus piezas, y nada de los otros", function()
  local piezas = {
    placa = function(f) return f.Placa:IsShown() and f.Canto:IsShown() end,
    cinta = function(f) return f.CintaC:IsShown() and f.CintaI:IsShown() and f.CintaD:IsShown() and (f.CintaC:GetWidth() or 0) > 60 end,
    filigrana = function(f) return f.FiliI:IsShown() and f.FiliD:IsShown() and (f.FiliI:GetWidth() or 0) > 30 end,
    suave = function(f) return f.Niebla:IsShown() end,
    nada = function(f) return not f.Niebla:IsShown() end,
  }
  for _, modo in ipairs(FONDOS_ANUNCIO) do
    A.Set("anuncios.fondo", modo)
    for _, chico in ipairs({ false, true }) do
      limpiar()
      K.Anuncio({ estilo = chico and "subzona" or "zona", titulo = "Colina de las Brujas", sobre = "Marjal Revolcafango",
        texto = chico and nil or "Niveles 35–45", ya = true, clave = "probar", espaciar = false })
      correr(2)
      local f = anuncio()
      check(f:IsShown() and piezas[modo](f), modo .. (chico and " (chico)" or "") .. ": faltan sus piezas")
      for otro, fn in pairs(piezas) do
        if otro ~= modo and otro ~= "nada" and otro ~= "suave" and fn(f) then NOTE("1.4.0 anuncios", modo .. ": se ve también " .. otro) end
      end
      local _, _, banderas = f.Titulo:GetFont()
      if K.FONDOS_ANUNCIO[modo].contorno then check(banderas == "OUTLINE", modo .. ": el nombre sin contorno") end
    end
  end
  A.Set("anuncios.fondo", nil)
  limpiar()
end)

---------------------------------------------------------------------------
-- 5. ui.reduceMotion
---------------------------------------------------------------------------
step("5. Con «Menos movimiento», nada se mueve: solo el fundido", function()
  A.Set("ui.reduceMotion", true)
  for _, e in ipairs({ "zona", "barco", "tranvia", "raro", "zepelin" }) do
    limpiar()
    K.Anuncio({ estilo = e, titulo = "Prueba", sobre = "Sobre", texto = "Línea", ya = true })
    local f = anuncio()
    local movio = false
    for _ = 1, 30 do
      correr(0.05)
      local _, _, _, x, y = f.C:GetPoint(1)
      if (x or 0) ~= 0 or (y or 0) ~= 0 then movio = true end
    end
    check(not movio, e .. ": se movió con «Menos movimiento»")
    local polvo = 0
    for _, p in ipairs(f.Polvo) do if p:IsShown() then polvo = polvo + 1 end end
    check(polvo == 0, e .. ": polvo con «Menos movimiento»")
  end
  A.Set("ui.reduceMotion", nil)
  limpiar()
end)

---------------------------------------------------------------------------
-- 6. No atrapa clics y se va pronto
---------------------------------------------------------------------------
step("6. Nunca atrapa clics y no se queda", function()
  for _, m in ipairs(MUESTRAS) do
    limpiar()
    local o = {}
    for k, v in pairs(m[2]) do o[k] = v end
    o.ya, o.clave, o.espaciar, o.cuenta = true, "probar", false, nil
    K.Anuncio(o)
    local f = anuncio()
    check(not f:IsMouseEnabled(), m[1] .. ": la franja atrapa clics")
    check(not (f.Velo and f.Velo.IsMouseEnabled and f.Velo:IsMouseEnabled()), m[1] .. ": el velo atrapa clics")
    correr(9.5)
    check(not f:IsShown(), m[1] .. ": se quedó más de 9 s")
  end
  limpiar()
  InCombatLockdown = function() return true end
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  K.Anuncio({ estilo = "raro", titulo = "Rak'shiri", ya = true, enCombate = true })
  local f = anuncio()
  check(f:IsShown() and not f.Toque:IsMouseEnabled() and not f.X:IsMouseEnabled(), "en combate el anuncio toma el ratón")
  InCombatLockdown = function() return false end
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  limpiar()
end)

---------------------------------------------------------------------------
-- 7. Los 10 idiomas: ningún texto cortado
---------------------------------------------------------------------------
local IDIOMAS = { "esMX", "esES", "enUS", "deDE", "frFR", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
local DIST = (os.getenv and os.getenv("ALFA_DIST")) or "dist"
-- Pares "clave": "valor" de un JSON plano (como prueba_139_calidad.lua).
local function leerJson(ruta)
  local fh = io and io.open(ruta, "rb")
  if not fh then return {} end
  local s = fh:read("*a") fh:close()
  local out = {}
  local function cadena(i)
    local partes = {}
    i = i + 1
    while true do
      local c = s:sub(i, i)
      if c == "" then return table.concat(partes), i end
      if c == '"' then return table.concat(partes), i + 1 end
      if c == "\\" then
        local e = s:sub(i + 1, i + 1)
        if e == "n" then partes[#partes + 1] = "\n"
        elseif e == "u" then
          local cp = tonumber(s:sub(i + 2, i + 5), 16) or 63
          if cp < 0x80 then partes[#partes + 1] = string.char(cp)
          elseif cp < 0x800 then partes[#partes + 1] = string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
          else partes[#partes + 1] = string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64) end
          i = i + 4
        else partes[#partes + 1] = e end
        i = i + 2
      else
        partes[#partes + 1] = c
        i = i + 1
      end
    end
  end
  local i = 1
  while true do
    local a = s:find('"', i, true)
    if not a then break end
    local k, j = cadena(a)
    local dos = s:find(":", j, true)
    local b = dos and s:find('"', dos, true)
    if not b then break end
    local v, j2 = cadena(b)
    out[k] = v
    i = j2
  end
  return out
end
local function diccionario(loc)
  local d = {}
  if loc == "esMX" or loc == "esES" then return d end
  if loc == "enUS" then
    for _, nombre in ipairs(ARCHIVOS_CARGADOS or {}) do
      local mod = nombre:match("^(Alfa_[%w_]+)\\Textos%.lua$")
      if mod then
        local f = loadfile(DIST .. "/" .. nombre:gsub("\\", "/"))
        local M2 = {}
        if f and pcall(f, mod, M2) and type(M2.EN) == "table" then for k, v in pairs(M2.EN) do d[k] = v end end
      end
    end
    return d
  end
  local f = loadfile("src/Alfa_Nucleo/Idiomas/" .. loc .. ".lua")
  if f then
    local gl, prev = GetLocale, rawget(_G, "AlfaNucleoIdiomas")
    GetLocale = function() return loc end
    AlfaNucleoIdiomas = {}
    pcall(f)
    d = AlfaNucleoIdiomas[loc] or {}
    GetLocale, AlfaNucleoIdiomas = gl, prev
  end
  for k, v in pairs(leerJson("textos/" .. loc .. "/Alfa_1.4.0-anuncios.json")) do if d[k] == nil then d[k] = v end end
  return d
end
-- Ancho estimado de cada letra (CJK y hangul casi un cuadro).
local function anchoDe(s, tam)
  s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local m = 0
  for linea in (s .. "\n"):gmatch("(.-)\n") do
    local w = 0
    for ch in linea:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
      local b = ch:byte(1)
      if #ch >= 3 and b >= 0xE1 then w = w + tam elseif ch:match("%u") then w = w + tam * 0.66
      elseif ch == " " then w = w + tam * 0.28 else w = w + tam * 0.56 end
    end
    if w > m then m = w end
  end
  return m
end

step("7. Ningún texto cortado en los 10 idiomas", function()
  PANTALLA_SIMULADA(1920, 1080)
  local malos, revisados = {}, 0
  local nombreLargo = "Las Tierras Altas de Arathi del Norte"
  for _, loc in ipairs(IDIOMAS) do
    local d = diccionario(loc)
    local function tr(s) if not s then return nil end return d[s] or s end
    for _, m in ipairs(MUESTRAS) do
      limpiar()
      local o = {}
      for k, v in pairs(m[2]) do o[k] = v end
      o.sobre, o.texto, o.pista = tr(o.sobre), tr(o.texto), tr(o.pista)
      if m[1] == "zona" or m[1] == "subzona" then o.titulo = nombreLargo end
      o.ya, o.clave, o.espaciar = true, "probar", false
      K.Anuncio(o)
      correr(1)
      local f = anuncio()
      if f and f:IsShown() then
        revisados = revisados + 1
        for _, n in ipairs({ "Sobre", "Titulo", "Texto", "Pista" }) do
          local fs = f[n]
          local txt = fs:GetText()
          if txt and txt ~= "" then
            local tam = fs._font and fs._font[2] or 12
            local w = fs._w or 0
            if w > 0 and not fs._wrap and anchoDe(txt, tam) > w + 2 then
              malos[#malos + 1] = loc .. " " .. m[1] .. "." .. n .. ": " .. txt
            end
            if fs._wrap and fs._max and fs._max > 0 and w > 0 then
              local lineas = 0
              for parrafo in (txt .. "\n"):gmatch("(.-)\n") do lineas = lineas + math.max(1, math.ceil(anchoDe(parrafo, tam) / w)) end
              if lineas > fs._max then malos[#malos + 1] = loc .. " " .. m[1] .. "." .. n .. " (" .. lineas .. " renglones): " .. txt end
            end
            -- Que no se salga de la pantalla.
            local l, _, ww = fs:GetRect()
            if l and (l < 0 or l + ww > 1920) then malos[#malos + 1] = loc .. " " .. m[1] .. "." .. n .. " se sale de la pantalla" end
          end
        end
      end
    end
  end
  print(("ANUNCIOS: %d revisados en %d idiomas; %d cortados"):format(revisados, #IDIOMAS, #malos))
  for i = 1, math.min(#malos, 20) do print("   cortado: " .. malos[i]) end
  check(#malos == 0, #malos .. " textos de anuncios se cortan en algún idioma")
  limpiar()
end)

---------------------------------------------------------------------------
-- 8. Cada uno dice algo útil y distinto (pedido de Toxic tras verlos en el juego)
---------------------------------------------------------------------------
step("8. Lo útil de cada tipo: descanso, tu nivel, misiones, Lya corta, raro sin repetir la zona", function()
  local reales = { GetRealZoneText = GetRealZoneText, GetZoneText = GetZoneText, GetSubZoneText = GetSubZoneText,
    IsResting = IsResting, UnitLevel = UnitLevel, GetXPExhaustion = rawget(_G, "GetXPExhaustion"), UnitXPMax = UnitXPMax }
  local mundo = { zona = "Marjal Revolcafango", sub = "Colina de las Brujas", resting = false, nivel = 30 }
  GetRealZoneText = function() return mundo.zona end
  GetZoneText = function() return mundo.zona end
  GetSubZoneText = function() return mundo.sub end
  IsResting = function() return mundo.resting end
  UnitLevel = function() return mundo.nivel end
  GetXPExhaustion = function() return 3500 end
  UnitXPMax = function() return 10000 end
  Z.Olvidar()
  -- La posada: el descanso que llevas.
  mundo.resting = true
  local o = Z.Subzona()
  check(o and o.texto and o.texto:find("35", 1, true), "en la posada, el rincón no dice tu descanso: " .. tostring(o and o.texto))
  -- Fuera: tus misiones de la zona (si hay).
  mundo.resting = false
  local real = Z.MisionesDe
  Z.MisionesDe = function() return 3 end
  o = Z.Subzona()
  check(o and o.texto and o.texto:find("3 de tus misiones", 1, true), "el rincón no dice tus misiones de la zona: " .. tostring(o and o.texto))
  Z.MisionesDe = function() return 0 end
  o = Z.Subzona()
  check(o and (o.texto == nil or o.texto == ""), "sin misiones, el rincón no debe traer línea")
  Z.MisionesDe = real
  -- Lya, corta.
  local largo = string.rep("Los centauros cuidan estas aguas ", 8)
  local c = Z.Corto(largo)
  check(#c <= 115 and #c < #largo, "Lya no se acorta en el anuncio: " .. #c)
  -- La zona peligrosa dice tu nivel.
  local mz, gl = Z.MapaZona, A.Maps and A.Maps.GetZoneLevels
  Z.MapaZona = function() return 1411 end
  if A.Maps then A.Maps.GetZoneLevels = function() return 40, 45 end end
  o = Z.Zona()
  check(o and o.estilo == "peligro" and o.texto and o.texto:find("30", 1, true), "la zona peligrosa no dice tu nivel: " .. tostring(o and o.texto))
  Z.MapaZona = mz
  if A.Maps then A.Maps.GetZoneLevels = gl end
  -- El raro: la zona donde ya estás no se repite.
  local ns = NS_OF("Alfa")
  local Tt = ns.Rares and ns.Rares.Toast
  if Tt and Tt.Show then
    limpiar()
    Tt.Show({ kind = "rare", id = 61, name = "Thuros", level = 29, zone = "Marjal Revolcafango", map = 1429, x = 50, y = 50, yards = 85 })
    local a = K.AnuncioActual()
    check(a and a.texto and not a.texto:find("Marjal Revolcafango", 1, true), "el raro repite la zona donde estás: " .. tostring(a and a.texto))
  end
  for k, v in pairs(reales) do _G[k] = v end
  Z.Olvidar()
  limpiar()
end)
