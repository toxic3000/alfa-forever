-- Prueba de la 1.4.0, área interfaz (tools/prueba.py la corre con las demás):
--   67  la temática por bando que se nota: paleta del bando en el tema (acento,
--       botones, barras, bordes), cabecera con textura, estandarte en la
--       ventana de Alfa, el saludo de Hoy, la vista previa de los dos bandos,
--       alto contraste y los 3 estilos
--   66  «Alto contraste»: texto y acento con 7:1 sobre cada fondo
--   57  «Tu sesión» en Hoy;  58  el atajo en el globo de los botones
--   59  los 3 estilos con brillo claro y oscuro;  60  sinónimos e ir directo
--   61  Esc cierra las ventanas;  63  la campanita por día y por módulo
--   65  lo nuevo de la 1.4 con «Enséñamelo»
--   Restablecer todos los ajustes, y los textos tras un cambio de pantalla
-- Con BANCO_FOTOS=1 dibuja las capturas (shot-140i-*.png; BANCO_CAPTURAS elige la carpeta).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS or not root then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["140i-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.4.0 interfaz", msg) end end

BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local O = A.UI.Options
local Th = A.Theme
local B = AlfaBienvenida
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
if N.Entrando then N.Entrando = function() return false end end
local In = NS_OF("Alfa_Inicio")
local P = In and In.Pagina

local function limpiarPantalla()
  for _, n in ipairs({ "AlfaLyaLoba", "AlfaInicioAviso", "AlfaRastreador", "AlfaNavArrow" }) do
    local f = rawget(_G, n)
    if type(f) == "table" and f.Hide then f:Hide() end
  end
end
local function fondoNoche(f, mx, my)
  local fondo = CreateFrame("Frame", nil, UIParent)
  fondo:SetFrameStrata("BACKGROUND")
  fondo:SetPoint("TOPLEFT", f, "TOPLEFT", -(mx or 30), my or 30)
  fondo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", mx or 30, -(my or 30))
  local c = fondo:CreateTexture(nil, "BACKGROUND")
  c:SetAllPoints(fondo)
  c:SetTexture("white")
  c:SetGradient("VERTICAL", CreateColor(0.03, 0.05, 0.08, 1), CreateColor(0.1, 0.13, 0.19, 1))
  fondo:Show()
  return fondo
end
local function abrirHoy()
  A.Fire("SHOW_OPTIONS", "inicio") RUN_TIMERS(2)
  local view = P and P.view
  if view then view.alfaSucio = true pcall(N.RehacerPagina, view) end
  RUN_TIMERS(1)
  return O.frame or rawget(_G, "AlfaOptions")
end
local function cerca(a, b) return math.abs(a - b) < 0.02 end

---------------------------------------------------------------------------
-- 67. La paleta del bando, de verdad
---------------------------------------------------------------------------
step("67: la paleta del bando en el tema", function()
  check(Th and Th.Retoque and Th.RETOQUES, "falta Theme.Retoque (motor/Alfa/Theme/Theme.lua)")
  check(A.Get("nucleo.bando") == false, "la temática debe venir apagada de fábrica")
  K.ProbarBando("H")
  local r0, g0, b0 = K.Color("acento")
  check(cerca(r0, 0.545) and cerca(g0, 0.878), "apagada, el acento no es el verde de La Jauría")
  A.Set("nucleo.bando", true)
  for _, l in ipairs({ "H", "A" }) do
    K.ProbarBando(l)
    local t = K.Bando()
    local r, g, b = K.Color("acento")
    if l == "H" then check(r > 0.75 and g < 0.45 and b < 0.4, "Horda: el acento no es rojo sangre: " .. r .. "," .. g .. "," .. b)
    else check(b > 0.75 and r < 0.5, "Alianza: el acento no es azul real: " .. r .. "," .. g .. "," .. b) end
    -- Se lee sobre los fondos (4.5:1).
    for _, fondo in ipairs({ "fondo", "panel", "elevado" }) do
      local c = Th.Contrast({ r, g, b }, { K.Color(fondo) })
      check(c >= 4.5, l .. ": el acento no se lee sobre " .. fondo .. " (" .. string.format("%.2f", c) .. ")")
    end
    -- El texto de un botón principal se lee sobre el acento.
    local c2 = Th.Contrast({ K.Color("sobreAcento") }, { r, g, b })
    check(c2 >= 4.5, l .. ": el texto del botón principal no se lee sobre el acento (" .. string.format("%.2f", c2) .. ")")
    -- El borde de las ventanas va en su metal.
    local wr, wg, wb = Th.Color("windowBorder")
    check(cerca(wr, t.metal[1]) and cerca(wg, t.metal[2]), l .. ": el borde de las ventanas no es del metal del bando")
    -- La flecha, del color del bando.
    local ar, ag, ab = Th.Color("arrow")
    check(cerca(ar, r) and cerca(ab, b), l .. ": la flecha no toma el color del bando")
  end
  -- Daltonismo: bien y peligro no cambian con el bando.
  A.Set("nucleo.daltonico", true)
  local e1 = { K.Color("exito") }
  K.ProbarBando("H")
  local e2 = { K.Color("exito") }
  check(cerca(e1[1], e2[1]) and cerca(e1[3], e2[3]), "con daltonismo, el bando cambió el color de lo bueno")
  A.Set("nucleo.daltonico", false)
  A.Set("nucleo.bando", false)
  local r, g = K.Color("acento")
  check(cerca(r, 0.545) and cerca(g, 0.878), "al apagar, el acento no vuelve al verde")
  K.ProbarBando(nil)
end)

---------------------------------------------------------------------------
-- 67. Las ventanas: cabecera con textura, en los 3 estilos
---------------------------------------------------------------------------
local function ventanaDePrueba()
  local v = K.Ventana({ nombre = "AlfaPruebaBando140", titulo = "La Jauría", subtitulo = "Tu manada", icono = "ic-manada", ancho = 440, alto = 230 })
  v:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  local t = K.Texto(v.Cuerpo, "cuerpo", "texto")
  t:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", 24, -16)
  K.Escribir(t, "Así se ve una ventana de Alfa con tu bando.")
  local bt = K.Boton(v, "Seguir", function() end, { tipo = "primario", icono = "ic-flecha" })
  local b2 = K.Boton(v, "Cerrar", function() end, { tipo = "secundario" })
  v:SetPie({ bt }, { b2 })
  return v
end

step("67: la cabecera del bando en las ventanas y los 3 estilos", function()
  local v = ventanaDePrueba()
  v:Show()
  A.Set("nucleo.bando", true)
  for _, l in ipairs({ "H", "A" }) do
    K.ProbarBando(l)
    local t = K.Bando()
    local b = v.alfaBando
    check(b and b.cab:IsShown() and b.cabIzq:IsShown(), l .. ": la cabecera no lleva su textura")
    check(b and b.cab:GetTexture() == t.cabecera, l .. ": la cabecera no es la de su bando")
    check(b and b.emblema:IsShown(), l .. ": falta el emblema en la cabecera")
    if FOTOS then
      local fondo = fondoNoche(v)
      SNAP("bando-ventana-" .. t.clave, fondo, { v })
      fondo:Hide()
    end
  end
  -- Clásico WoW: el marco del juego manda (sin textura, con la tira).
  local antes = K.Estilo()
  K.SetEstilo("clasico")
  RUN_TIMERS(1)
  check(not v.alfaBando.cab:IsShown() and v.alfaBando.tira:IsShown(), "en Clásico WoW la cabecera debe llevar solo la tira")
  if FOTOS then local fondo = fondoNoche(v) SNAP("bando-ventana-clasico", fondo, { v }) fondo:Hide() end
  K.SetEstilo("cristal")
  RUN_TIMERS(1)
  check(v.alfaBando.cab:IsShown(), "en Cristal la cabecera debe llevar su textura")
  if FOTOS then local fondo = fondoNoche(v) SNAP("bando-ventana-cristal", fondo, { v }) fondo:Hide() end
  K.SetEstilo(antes or "alfa")
  RUN_TIMERS(1)
  A.Set("nucleo.bando", false)
  check(not v.alfaBando.cab:IsShown() and v.Cabecera.Linea:IsShown(), "al apagar, la cabecera no vuelve a lo de siempre")
  v:Hide()
  K.ProbarBando(nil)
end)

---------------------------------------------------------------------------
-- 67. Hoy y la ventana de Alfa: el saludo y el estandarte
---------------------------------------------------------------------------
step("67: el saludo de Hoy y el estandarte de la ventana de Alfa", function()
  check(P and P.NuevoSaludo, "falta el saludo de Hoy (Alfa_Inicio/Inicio.lua)")
  local f = abrirHoy()
  -- (1.4.0, 82: el saludo es ahora la portada de Hoy, que sale siempre; sin la temática no es el del bando.)
  check(not (P.saludo and P.saludo:IsShown() and P.saludo.tema), "sin la temática, Hoy no debe saludar por bando")
  A.Set("nucleo.bando", true)
  for _, l in ipairs({ "H", "A" }) do
    K.ProbarBando(l)
    f = abrirHoy()
    local t = K.Bando()
    check(P.saludo and P.saludo:IsShown(), l .. ": Hoy no saluda con tu bando")
    local txt = P.saludo and P.saludo.Titulo:GetText() or ""
    check(txt:find(l == "H" and "Lok'tar" or "Por la Alianza", 1, true), l .. ": el saludo no es el del bando: " .. txt)
    check(P.tablero.bloques[1] and P.tablero.bloques[1].b == P.saludo, l .. ": el saludo no va arriba de todo")
    local s = f and f.alfaSello
    check(s and s.estandarte and s.estandarte:IsShown() and s.estandarte:GetTexture() == t.estandarte, l .. ": la ventana de Alfa no lleva el estandarte")
    limpiarPantalla()
    if FOTOS and f then SNAP("bando-hoy-" .. t.clave, f) end
  end
  A.Set("nucleo.bando", false)
  f = abrirHoy()
  check(not P.saludo.tema and not (P.saludo.Titulo:GetText() or ""):find("Lok'tar", 1, true), "al apagar, el saludo del bando no se va")
  check(not (f.alfaSello and f.alfaSello.estandarte and f.alfaSello.estandarte:IsShown()), "al apagar, el estandarte no se va")
  if f then f:Hide() end
  K.ProbarBando(nil)
end)

---------------------------------------------------------------------------
-- 67. Un aviso, un anuncio y Bolsas con los colores del bando
---------------------------------------------------------------------------
step("67: aviso, anuncio y bolsas del bando", function()
  A.Set("nucleo.bando", true)
  local Bo = NS_OF and NS_OF("Alfa_Bolsas")
  for _, l in ipairs({ "H", "A" }) do
    K.ProbarBando(l)
    local t = K.Bando()
    local av = K.Aviso({ titulo = "Tus bolsas están casi llenas", texto = "Te quedan 3 casillas libres.", icono = "ic-bolsas",
      tono = "acento", lya = false, pedido = true, acciones = { { texto = "Ver bolsas", alClic = function() end } } })
    if type(av) == "table" and av.SetAlpha then av:SetAlpha(1) end
    if FOTOS and type(av) == "table" and av.GetObjectType then
      local fondo = fondoNoche(av, 20, 20)
      SNAP("bando-aviso-" .. t.clave, fondo, { av })
      fondo:Hide()
    end
    if type(av) == "table" and av.Hide then av:Hide() end
    K.QuitarAnuncio()
    K.Anuncio({ estilo = "llegada", titulo = l == "H" and "Orgrimmar" or "Ventormenta", sobre = "Llegaste", texto = "La manada te esperaba", ya = true })
    local an = rawget(_G, "AlfaAnuncio")
    if an then for _ = 1, 30 do FIRE(an, "OnUpdate", 0.1) end end
    local a = K.AnuncioActual()
    check(a and a.bando == t.clave, l .. ": el anuncio no lleva el tema del bando")
    if FOTOS and an then
      local fondo = fondoNoche(an, 0, 0)
      SNAP("bando-anuncio-" .. t.clave, fondo, { an })
      fondo:Hide()
    end
    K.QuitarAnuncio()
    local V = Bo and Bo.Ventana
    if V and V.MostrarBolsas then
      pcall(V.MostrarBolsas, true)
      RUN_TIMERS(3)
      local ok, w = pcall(V.Ventana, "bolsas")
      if ok and w and w:IsShown() then
        if FOTOS then local fondo = fondoNoche(w) SNAP("bando-bolsas-" .. t.clave, fondo, { w }) fondo:Hide() end
        w:Hide()
      end
    end
  end
  A.Set("nucleo.bando", false)
  K.ProbarBando(nil)
end)

---------------------------------------------------------------------------
-- 67. La vista previa de los dos bandos
---------------------------------------------------------------------------
step("67: la vista previa de los dos bandos", function()
  K.ProbarBando("H")
  check(K.VistaBandos, "falta K.VistaBandos")
  local v = K.VistaBandos()
  check(v and v:IsShown() and v.H and v.A, "la vista previa no abrió con las dos tarjetas")
  check(v.H.Tuyo:IsShown() and not v.A.Tuyo:IsShown(), "la vista no marca tu bando")
  check(tostring(v.H.Saludo:GetText()):find("Lok'tar", 1, true) and tostring(v.A.Saludo:GetText()):find("Alianza", 1, true), "las tarjetas no llevan su saludo")
  check(v.Prender:IsShown() and tostring(v.Prender.Texto and v.Prender.Texto:GetText() or ""):find("Vestir", 1, true), "falta «Vestir a Alfa de mi bando»")
  if FOTOS then local fondo = fondoNoche(v) SNAP("bando-vista", fondo, { v }) fondo:Hide() end
  v.Prender:Click()
  check(A.Get("nucleo.bando") == true, "«Vestir a Alfa» no prendió la temática")
  check(N.Datos("kit").bandoElegido == true, "no anotó que ya elegiste")
  local r = K.Color("acento")
  check(r > 0.75, "al prender desde la vista, el acento no cambió al instante")
  v.Prender:Click()
  check(A.Get("nucleo.bando") == false, "«Quitar la temática» no la apagó")
  v:Cerrar()
  -- La pregunta de una vez ofrece verlo.
  local d = N.Datos("kit")
  d.bandoPreguntado, d.bandoElegido = nil, nil
  local acciones
  local off = A.On("ALFA_AVISO", function(o) if type(o) == "table" and tostring(o.titulo):find("bando", 1, true) then acciones = o.acciones end end)
  K.PreguntarBando()
  if type(acciones) == "table" then
    local hay = false
    for _, x in ipairs(acciones) do if tostring(x.texto):find("Ver", 1, true) then hay = true end end
    check(hay, "la pregunta no ofrece «Ver cómo se ve»")
  end
  K.ProbarBando(nil)
end)

---------------------------------------------------------------------------
-- 66. Alto contraste
---------------------------------------------------------------------------
step("66: alto contraste", function()
  check(K.AltoContraste and A.Get("nucleo.altoContraste") == false, "falta «Alto contraste» (apagado de fábrica)")
  for _, estilo in ipairs({ "alfa", "cristal", "nocturno" }) do
    K.SetEstilo(estilo)
    A.Set("nucleo.altoContraste", true)
    for _, bando in ipairs({ false, true }) do
      A.Set("nucleo.bando", bando)
      K.ProbarBando(bando and "H" or nil)
      for _, fondo in ipairs({ "fondo", "panel", "elevado", "hundido" }) do
        local cf = { K.Color(fondo) }
        local ct = Th.Contrast({ K.Color("texto") }, cf)
        local ca = Th.Contrast({ K.Color("acento") }, cf)
        local cs = Th.Contrast({ K.Color("textoTenue") }, cf)
        check(ct >= 7, estilo .. ": con alto contraste el texto no llega a 7:1 sobre " .. fondo)
        check(ca >= 7, estilo .. (bando and " (bando)" or "") .. ": con alto contraste el acento no llega a 7:1 sobre " .. fondo .. string.format(" (%.2f)", ca))
        check(cs >= 7, estilo .. ": con alto contraste el texto tenue no llega a 7:1 sobre " .. fondo)
        check(select(4, K.Color(fondo)) >= 0.99, estilo .. ": con alto contraste el fondo " .. fondo .. " debe ser opaco")
      end
    end
    A.Set("nucleo.bando", false)
    A.Set("nucleo.altoContraste", false)
  end
  K.SetEstilo("alfa")
  K.ProbarBando(nil)
end)

---------------------------------------------------------------------------
-- Restablecer todos los ajustes (Acerca de > Mantenimiento)
---------------------------------------------------------------------------
step("Restablecer todos los ajustes de verdad", function()
  local ns = NS_OF("Alfa")
  check(type(ns.ResetSettings) == "function", "ns.ResetSettings no existe: el botón no hacía nada")
  if not ns.ResetSettings then return end
  A.Set("nucleo.daltonico", true)
  A.Set("nucleo.bando", true)
  A.Set("nucleo.escalaVentanas", 1.2)
  A.Set("bienvenida.modo", "completo")
  local n = ns.ResetSettings()
  check(type(n) == "number" and n > 20, "restablecer no recorrió los ajustes: " .. tostring(n))
  check(A.Get("nucleo.daltonico") == false and A.Get("nucleo.bando") == false, "restablecer no devolvió los ajustes a fábrica")
  check(math.abs((A.Get("nucleo.escalaVentanas") or 1) - 1.2) < 0.001, "restablecer perdió la escala de Alfa")
  check(A.Get("bienvenida.modo") == "completo", "restablecer tocó «Cómo ves Alfa» (noReset)")
  -- En combate espera.
  local ic = InCombatLockdown
  InCombatLockdown = function() return true end
  check(ns.ResetSettings() == false, "en combate no debe restablecer")
  InCombatLockdown = ic
  A.Set("nucleo.escalaVentanas", nil)
  A.Set("bienvenida.modo", nil)
end)

---------------------------------------------------------------------------
-- Tras un cambio de pantalla, los textos se escriben otra vez
---------------------------------------------------------------------------
step("Cambio de pantalla: los textos del Kit se escriben otra vez", function()
  check(K.PantallaCambio and K.ReescribirTextos, "falta K.PantallaCambio")
  local f = abrirHoy()
  local escrito = 0
  local fs
  for x in pairs(K.TEXTOS) do if x:IsVisible() and (x:GetText() or "") ~= "" then fs = x break end end
  if fs then
    local set = fs.SetText
    fs.SetText = function(self, t) escrito = escrito + 1 return set(self, t) end
    local avisado = false
    local off = A.On("ALFA_PANTALLA", function() avisado = true end)
    FIRE_EVENT("UI_SCALE_CHANGED")
    RUN_TIMERS(1)
    fs.SetText = nil
    check(escrito >= 2, "tras UI_SCALE_CHANGED el texto no se escribió otra vez")
    check(avisado, "no avisó ALFA_PANTALLA (Hoy no se acomoda)")
  else
    check(false, "no hay textos del Kit a la vista en Hoy")
  end
  if f then f:Hide() end
end)

---------------------------------------------------------------------------
-- 57. «Tu sesión» en Hoy
---------------------------------------------------------------------------
step("57: la tarjeta «Tu sesión»", function()
  check(P and P.TarjetaSesion, "falta P.TarjetaSesion")
  local e = { dur = 4380, ritmo = 12400, prom = 9000, ganado = 23456, gastado = 1200, misiones = 6, xp = 15000, inicio = 1700000000 - 4380 }
  local c = P.TarjetaSesion(e)
  check(c.titulo == "Tu sesión", "el título no es «Tu sesión»")
  check(tostring(c.valor):find("1 h", 1, true), "no dice el tiempo de la sesión: " .. tostring(c.valor))
  check(tostring(c.texto):find("XP/h", 1, true) and tostring(c.texto):find("oro", 1, true), "no dice la XP por hora y el oro: " .. tostring(c.texto))
  check(tostring(c.texto):find("6 misiones", 1, true), "no dice las misiones")
  e.maximo = true
  c = P.TarjetaSesion(e)
  check(not tostring(c.texto):find("XP/h", 1, true), "a nivel máximo no debe decir la XP por hora")
  -- En Hoy, entre los números, y se repinta al pasar el tiempo.
  local hay = false
  for _, x in ipairs(P.Numeros()) do if x.titulo == "Tu sesión" then hay = true end end
  check(hay, "Hoy no enseña «Tu sesión»")
end)

---------------------------------------------------------------------------
-- 58. El atajo en el globo de los botones
---------------------------------------------------------------------------
step("58: la tecla en el globo del botón", function()
  local gk = GetBindingKey
  GetBindingKey = function(a) if a == "ALFA_ZEN" or a == "ALFA_NEXT" then return "CTRL-Z" end return nil end
  local b = K.Boton(UIParent, "Probar", function() end, { tecla = "ALFA_ZEN" })
  b:SetPoint("CENTER")
  b:Show()
  FIRE(b, "OnEnter")
  local info = rawget(_G, "AlfaKitInfo")
  local txt = ""
  if info and info.Cuerpo then txt = tostring(info.Cuerpo:GetText()) end
  check(txt:find("Atajo", 1, true) and txt:find("Z", 1, true), "el globo del botón no dice su atajo: " .. txt)
  FIRE(b, "OnLeave")
  b:Hide()
  -- El motor: la ventana de guía y la X de la ventana de Alfa.
  local Wd = NS_OF("Alfa").Widgets
  check(Wd and Wd.TeclaDe, "falta W.TeclaDe (motor)")
  if Wd and Wd.TeclaDe then
    check(Wd.TeclaDe({ psTecla = "ALFA_NEXT" }) ~= nil, "W.TeclaDe no encuentra la tecla")
    check(Wd.TeclaDe({ psTecla = "ALFA_PREV" }) == nil, "W.TeclaDe inventa una tecla")
  end
  check(O.frame and O.frame.Close and O.frame.Close.psTecla == "ALFA_OPTIONS", "la X de la ventana de Alfa no lleva su tecla")
  GetBindingKey = gk
end)

---------------------------------------------------------------------------
-- 60. La búsqueda: sinónimos y directo al ajuste
---------------------------------------------------------------------------
step("60: la búsqueda entiende sinónimos y va directo", function()
  check(O.SINONIMOS and O.IrAlMejor and O.IrAlAjuste, "faltan los sinónimos o ir directo")
  local function hay(q, clave)
    local grupos = O.Search(q)
    for _, g in ipairs(grupos or {}) do
      for _, c in ipairs(g.controls) do if c.key == clave then return true, g end end
    end
    return false
  end
  check(hay("contraste", "nucleo.altoContraste"), "«contraste» no encuentra el alto contraste")
  check(hay("faccion", "nucleo.bando"), "«faccion» (sinónimo) no encuentra la temática del bando")
  check(hay("daltonismo", "nucleo.daltonico"), "«daltonismo» no encuentra los colores para daltonismo")
  A.Fire("SHOW_OPTIONS", "inicio") RUN_TIMERS(1)
  local ok = O.IrAlMejor("alto contraste")
  check(ok, "Enter no fue directo al ajuste")
  local r = O.resaltado
  local clave = r and ((r.psControl and r.psControl.key) or (rawget(r, "Control") and r.Control.alfaClave))
  check(O.page and clave == "nucleo.altoContraste" and r.psResalte:IsShown(),
    "no se abrió la página con el ajuste resaltado")
  if FOTOS and O.frame then SNAP("buscar-directo", O.frame) end
  O.frame:Hide()
end)

---------------------------------------------------------------------------
-- 61. Esc cierra las ventanas de Alfa
---------------------------------------------------------------------------
step("61: Esc cierra las ventanas de Alfa", function()
  local en = {}
  for _, n in ipairs(UISpecialFrames or {}) do en[n] = true end
  for _, n in ipairs({ "AlfaPerdidos", "AlfaReporteVentana", "AlfaVistaBandos", "AlfaOptions", "AlfaKitMenu", "AlfaMazmorrasResumen", "AlfaBolsasPrevia" }) do
    if rawget(_G, n) or n:find("Kit") or n:find("Previa") or n:find("Resumen") then
      check(en[n], n .. " no se cierra con Esc")
    end
  end
end)

---------------------------------------------------------------------------
-- 63. La campanita por día y por módulo
---------------------------------------------------------------------------
step("63: la campanita agrupa por día y por módulo", function()
  check(N.AgruparAvisos and N.NombreDiaAviso, "falta agrupar los avisos")
  N.OlvidarAvisos()
  local hoy = GetServerTime()
  local l = {
    { titulo = "Bolsas casi llenas", texto = "a", icono = "ic-bolsas", t = hoy },
    { titulo = "Misión lista", texto = "b", icono = "ic-misiones", t = hoy - 60 },
    { titulo = "Vende lo gris", texto = "c", icono = "ic-bolsas", t = hoy - 120 },
    { titulo = "Un raro", texto = "d", icono = "ic-raros", t = hoy - 86400 },
    { titulo = "Viejo", texto = "e", icono = "ic-bolsas", t = hoy - 5 * 86400 },
  }
  local g = N.AgruparAvisos(l)
  check(#g == 3, "no son 3 días: " .. #g)
  check(g[1] and g[1].nombre == "Hoy" and g[2].nombre == "Ayer", "los días no dicen Hoy y Ayer")
  check(g[3] and tostring(g[3].nombre):find("/", 1, true), "un día viejo no dice su fecha: " .. tostring(g[3] and g[3].nombre))
  check(g[1] and #g[1].modulos == 2 and g[1].modulos[1].clave == "bolsas" and #g[1].modulos[1].lista == 2, "hoy no junta Bolsas (2) y Ruta")
  -- La ventana.
  for i = #l, 1, -1 do N.Perdido(l[i]) end
  for _, e in ipairs(N.Perdidos()) do
    for _, x in ipairs(l) do if x.titulo == e.titulo then e.t = x.t end end
  end
  local v = N.VerAvisos()
  RUN_TIMERS(1)
  check(v and v:IsShown(), "no se abrió la campanita")
  if FOTOS and v then local fondo = fondoNoche(v) SNAP("avisos-por-dia", fondo, { v }) fondo:Hide() end
  if v then v:Hide() end
  N.OlvidarAvisos()
end)

---------------------------------------------------------------------------
-- 65. Lo nuevo de la 1.4 con su recorrido
---------------------------------------------------------------------------
step("65: lo nuevo de la 1.4 y «Enséñamelo»", function()
  local Bv = NS_OF("Alfa_Bienvenida")
  local nota
  for _, x in ipairs(Bv.NOTAS or {}) do if x.version == "1.4.0" then nota = x end end
  check(nota, "no están las notas de la 1.4.0")
  if not nota then return end
  for _, p in ipairs(nota.puntos) do
    if p[3] then check(Bv.IR_NOTA[p[3]] ~= nil, "el punto lleva a «" .. p[3] .. "», que no existe") end
  end
  check(Bv.AbrirNotas(nota), "no abrió las notas")
  RUN_TIMERS(1)
  local nv = rawget(_G, "AlfaNotasVersion")
  check(nv and nv:IsShown(), "no se ven las notas")
  if FOTOS and nv then local fondo = fondoNoche(nv) SNAP("notas-140", fondo, { nv }) fondo:Hide() end
  local avisos = {}
  local off = A.On("ALFA_AVISO", function(o) if type(o) == "table" and o.id == "bienvenida.recorridoNotas" then avisos[#avisos + 1] = o end end)
  local n = Bv.RecorridoNotas(nota)
  check(n >= 5, "el recorrido tiene muy pocos pasos: " .. n)
  check(not nv:IsShown(), "las notas no se cerraron al empezar el recorrido")
  check(Bv.PasoRecorridoNotas() == 1 and #avisos == 1, "no salió el primer paso")
  if avisos[1] then
    check(tostring(avisos[1].titulo):find("1 de", 1, true), "el paso no dice «1 de N»")
    avisos[1].acciones[1].alClic()
    check(Bv.PasoRecorridoNotas() == 2, "«Siguiente» no fue al paso 2")
  end
  local ultimo = avisos[#avisos]
  if ultimo and ultimo.acciones[2] then ultimo.acciones[2].alClic() end
  check(Bv.PasoRecorridoNotas() == nil, "«Ya entendí» no terminó el recorrido")
  for _, nombre in ipairs({ "AlfaVistaBandos", "AlfaOptions", "AlfaPerdidos", "AlfaReporteVentana" }) do
    local f = rawget(_G, nombre)
    if f and f.Hide then f:Hide() end
  end
end)

---------------------------------------------------------------------------
-- 59 y 66. Los 3 estilos, claro u oscuro, con letra grande y alto contraste:
-- el texto se lee en todo; cada página nueva abre sin errores.
---------------------------------------------------------------------------
step("59/66: estilos, brillo, letra grande y alto contraste", function()
  for _, estilo in ipairs({ "alfa", "clasico", "cristal" }) do
    K.SetEstilo(estilo)
    for _, brillo in ipairs({ -1, 0, 1 }) do
      A.Set("ui.brightness", brillo)
      for _, fondo in ipairs({ "fondo", "panel", "elevado" }) do
        local cf = { K.Color(fondo) }
        local ct = Th.Contrast({ K.Color("texto") }, cf)
        check(ct >= 4.5, estilo .. " brillo " .. brillo .. ": el texto no se lee sobre " .. fondo .. string.format(" (%.2f)", ct))
      end
    end
    A.Set("ui.brightness", nil)
  end
  K.SetEstilo("alfa")
  A.Set("nucleo.letraGrande", true)
  A.Set("nucleo.altoContraste", true)
  for _, pagina in ipairs({ "inicio", "bienvenida", "rutas", "bolsas", "manada" }) do
    local antes = #ERRORS
    A.Fire("SHOW_OPTIONS", pagina) RUN_TIMERS(1)
    check(#ERRORS == antes, pagina .. ": error al abrir con letra grande y alto contraste")
  end
  if FOTOS and O.frame then
    A.Fire("SHOW_OPTIONS", "inicio") RUN_TIMERS(2)
    limpiarPantalla()
    SNAP("hoy-alto-contraste", O.frame)
  end
  A.Set("nucleo.letraGrande", false)
  A.Set("nucleo.altoContraste", false)
  if O.frame then O.frame:Hide() end
end)

print(string.format("PRUEBA: 1.4.0 interfaz, %d pasos, %d errores", pasos, #ERRORS))
