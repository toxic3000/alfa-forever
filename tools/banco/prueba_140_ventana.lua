-- Prueba de la 1.4.0, área ventana (tools/prueba.py la corre con las demás):
--   82  la ventana de Alfa y Hoy con un salto visual: barra lateral con
--       íconos y secciones, cabecera de página con presencia, la portada
--       nueva de Hoy (saludo, tu personaje, lo primero en grande, tu sesión,
--       tu guía y la manada), transiciones suaves (ui.reduceMotion las
--       quita), los 3 estilos y los dos bandos; Sencillo/Completo y la
--       búsqueda siguen igual
--   84  la bienvenida de la 1.4.0: lo nuevo con «Pruébalo» por punto
-- Con BANCO_FOTOS=1 dibuja las capturas (shot-ventana-<etapa>-*.png;
-- BANCO_ETAPA = antes | despues, BANCO_CAPTURAS elige la carpeta).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local ETAPA = (os and os.getenv and os.getenv("BANCO_ETAPA")) or "despues"
local function SNAP(name, root, extra)
  if not FOTOS or not root then return end
  local entries, l, b, w, h = DUMP(root, extra)
  -- BANCO_ETAPA=galeria: las de la galería de CurseForge (shot-140-ventana-*.png, tools/galeria.py).
  local clave = ETAPA == "galeria" and ("140-ventana-" .. name) or ("ventana-" .. ETAPA .. "-" .. name)
  SNAPSHOTS[clave] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.4.0 ventana", msg) end end

BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local O = A.UI.Options
local W = A.Widgets
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
local function abrir(pagina)
  A.Fire("SHOW_OPTIONS", pagina or "inicio") RUN_TIMERS(2)
  if (pagina or "inicio") == "inicio" then
    local view = P and P.view
    if view then view.alfaSucio = true pcall(N.RehacerPagina, view) end
    RUN_TIMERS(1)
  end
  return O.frame or rawget(_G, "AlfaOptions")
end
local function foto(nombre, f)
  if not (FOTOS and f) then return end
  limpiarPantalla()
  -- El banco no corre el reloj de Anim: los fundidos y el deslizamiento, a su final.
  local Anim = A.Anim
  for _, x in ipairs({ f, O.view }) do
    if x then for _, k in ipairs({ "alpha", "value" }) do if Anim.IsRunning(x, k) then Anim.Stop(x, k) end end end
  end
  local fondo = fondoNoche(f)
  SNAP(nombre, fondo, { f })
  fondo:Hide()
end

---------------------------------------------------------------------------
-- Las capturas (antes y después)
---------------------------------------------------------------------------
step("82: capturas de la ventana", function()
  local f = abrir("inicio")
  check(f and f:IsShown(), "la ventana de Alfa no abre en Hoy")
  foto("hoy", f)
  f = abrir("rutas") foto("rutas", f)
  f = abrir("bolsas") foto("bolsas", f)
  f = abrir("comodidades") foto("ajustes", f)
  A.Set("nucleo.bando", true)
  K.ProbarBando("H") f = abrir("inicio") foto("hoy-horda", f)
  K.ProbarBando("A") f = abrir("inicio") foto("hoy-alianza", f)
  A.Set("nucleo.bando", false)
  K.ProbarBando(nil)
  local antes = K.Estilo()
  K.SetEstilo("clasico") RUN_TIMERS(1) f = abrir("inicio") foto("hoy-clasico", f)
  K.SetEstilo("cristal") RUN_TIMERS(1) f = abrir("inicio") foto("hoy-cristal", f)
  K.SetEstilo(antes or "alfa") RUN_TIMERS(1)
  f = abrir("inicio")
  O.SetQuery("mapa") RUN_TIMERS(1)
  foto("buscar", f)
  O.SetQuery("") RUN_TIMERS(1)
  f:Hide()
end)

---------------------------------------------------------------------------
-- 82. La ventana: barra lateral, cabecera de página, transiciones
---------------------------------------------------------------------------
local function dentro(hijo, padre)
  local l, b, w, h = hijo:GetRect()
  local L2, B2, W2, H2 = padre:GetRect()
  if not (l and L2) then return false end
  return l >= L2 - 0.5 and b >= B2 - 0.5 and l + w <= L2 + W2 + 0.5 and b + h <= B2 + H2 + 0.5
end

step("82: barra lateral con íconos y secciones", function()
  local f = abrir("inicio")
  check(f.psLateral and f.Side and f.Side:IsShown(), "la ventana no tiene barra lateral")
  check(W.SIDE and math.abs(f.BodyWidth - (f:GetWidth() - W.SIDE.width - 2 - W.SHELL.pad * 2)) < 1,
    "la columna de la página cambió de ancho con la barra")
  check(N.AnchoPagina() == f.BodyWidth, "N.AnchoPagina no es el ancho del cuerpo")
  local vistos, arriba, abajo = {}, 0, 0
  for _, b in ipairs(f.sectionButtons) do
    if b:IsShown() then
      vistos[b.psKey] = b
      check(b.Icon:GetTexture() ~= nil, "la sección " .. tostring(b.psKey) .. " no tiene ícono")
      check(dentro(b, f.Side), "la sección " .. tostring(b.psKey) .. " se sale de la barra lateral")
      local _, y = b:GetCenter()
      if b.psKey == "ajustes" or b.psKey == "avisos" then abajo = math.max(abajo, y) else arriba = math.min(arriba == 0 and 1e9 or arriba, y) end
    end
  end
  check(vistos.hoy and vistos.ajustes, "faltan Hoy o Ajustes en la barra")
  check(arriba > abajo, "Ajustes y Avisos no quedaron abajo de las secciones")
  check(vistos.hoy.psOn and vistos.hoy.Bar:IsShown(), "Hoy no se marca como elegida")
  -- Un clic en una sección cambia la página y la marca.
  vistos.aventura:Click() RUN_TIMERS(1)
  check(O.page and O.SectionOf(O.page.key) == "aventura", "el clic en Aventura no abrió su sección")
  check(vistos.aventura.psOn and not vistos.hoy.psOn, "la marca no pasó a Aventura")
  -- La cabecera de la página: ícono, título grande y para qué sirve.
  check(f.PageIcon:IsShown() and f.Title:IsShown(), "la cabecera de la página no tiene ícono o título")
  local _, tam = f.Title:GetFont()
  check(tam and tam >= 20, "el título de la página no es grande: " .. tostring(tam))
  check(f.Subtitle:IsShown() and f.Subtitle:GetText() ~= "", "la página no dice para qué sirve")
  check(dentro(f.Subtitle, f.PageHead), "el subtítulo se sale de la cabecera")
  f:Hide()
end)

step("82: la página siempre tiene donde verse (alto del cuerpo)", function()
  local f = abrir("comodidades")
  local _, ph = f.PageHead:GetSize()
  local esperado = f:GetHeight() - 2 - W.TOP.header - ph - f.PillRow:GetHeight()
    - (f.TabRow:IsShown() and W.TOP.tabs or 0) - (f.Footer:IsShown() and W.TOP.footer or 0)
  check(math.abs((f.psViewH or 0) - esperado) < 1, "el alto visible no cuenta la cabecera: " .. tostring(f.psViewH) .. " / " .. esperado)
  local hay = false
  for _, b in ipairs(f.pillButtons) do if b:IsShown() then hay = true check(dentro(b, f.PillRow), "una pastilla se sale de su fila") end end
  check(hay, "Ajustes no muestra sus páginas como pastillas")
  f:Hide()
end)

step("82: transiciones suaves y ui.reduceMotion", function()
  local Anim = A.Anim
  local f = abrir("inicio")
  A.Set("ui.reduceMotion", false)
  O.Select("rutas")
  local v = O.view
  check(Anim.IsRunning(v, "value") and Anim.IsRunning(v, "alpha"), "la página nueva no entra deslizándose")
  NOW = NOW + 1
  Anim.Stop(v, "value") Anim.Stop(v, "alpha")
  local _, _, _, x = v:GetPoint(1)
  check(math.abs(x or 1) < 0.01, "la página no terminó en su lugar: " .. tostring(x))
  A.Set("ui.reduceMotion", true)
  O.Select("inicio")
  check(not Anim.IsRunning(O.view, "value"), "con «Reducir movimiento» la página se deslizó")
  local _, _, _, x2 = O.view:GetPoint(1)
  check(math.abs(x2 or 1) < 0.01, "con «Reducir movimiento» la página no quedó en su lugar")
  A.Set("ui.reduceMotion", false)
  f:Hide()
end)

step("82: Sencillo y Completo, y la búsqueda", function()
  A.Set("bienvenida.modo", "sencillo")
  local f = abrir("inicio")
  O.RefreshNav()
  local n1 = 0
  for _, b in ipairs(f.sectionButtons) do if b:IsShown() then n1 = n1 + 1 end end
  A.Set("bienvenida.modo", "completo")
  O.RefreshNav()
  local n2 = 0
  for _, b in ipairs(f.sectionButtons) do if b:IsShown() then n2 = n2 + 1 end end
  check(n2 >= n1 and n1 >= 3, "Sencillo/Completo no cambian la barra: " .. n1 .. " / " .. n2)
  O.SetQuery("mapa") RUN_TIMERS(1)
  check(f.Title:GetText() ~= "" and f.PageIcon:IsShown(), "buscando, la cabecera quedó vacía")
  for _, b in ipairs(f.sectionButtons) do if b:IsShown() then check(not b.psOn, "buscando, una sección sigue marcada") end end
  O.SetQuery("") RUN_TIMERS(1)
  check(O.page and O.page.key == "inicio", "al borrar la búsqueda no volvió a Hoy")
  f:Hide()
end)

step("82: la portada de Hoy", function()
  local f = abrir("inicio")
  local s = P and P.saludo
  check(s and s:IsShown() and P.tablero.bloques[1].b == s, "la portada no va arriba de todo en Hoy")
  check(s and (s.Titulo:GetText() or ""):find("Lobato", 1, true), "la portada no te saluda por tu nombre")
  check(s and (s.Linea:GetText() or "") ~= "", "la portada no dice tu personaje")
  check(s and s.alfaN == 3, "la portada no trae sus tres cifras: " .. tostring(s and s.alfaN))
  local claves = {}
  for i = 1, s.alfaN or 0 do
    local c = s.cifras[i]
    claves[c.alfaClave] = c
    check(dentro(c, s), "la cifra " .. tostring(c.alfaClave) .. " se sale de la portada")
    check((c.Valor:GetText() or "") ~= "", "la cifra " .. tostring(c.alfaClave) .. " no tiene valor")
  end
  check(claves.sesion and claves.guia and claves.manada, "faltan tu sesión, tu guía o la manada")
  check(claves.guia and (claves.guia.Valor:GetText() or ""):find("%%"), "tu guía no dice su avance")
  -- Secretos: en una mazmorra el nombre llega secreto y no se lee.
  if SECRETOS_PRENDER then
    SECRETOS_PRENDER({ "UnitName", "UnitClass", "UnitLevel", "GetRealZoneText", "GetZoneText" }) -- (1.4.0: sin la real, se lee GetZoneText si se puede)
    s:Llenar()
    check(not (s.Titulo:GetText() or ""):find("Lobato", 1, true), "con el nombre secreto, la portada lo leyó")
    check(not (s.Linea:GetText() or ""):find("Durotar", 1, true), "con la zona secreta, la portada la leyó")
    SECRETOS_APAGAR()
  end
  -- Se apaga en los ajustes de Hoy.
  A.Set("inicio.portada", false)
  f = abrir("inicio")
  check(not s:IsShown(), "con la portada apagada, sigue en Hoy")
  A.Set("inicio.portada", true)
  f = abrir("inicio")
  check(s:IsShown(), "la portada no volvió al prenderla")
  -- Angosta: las cifras bajan y nada se sale.
  s:Acomodar(420)
  for i = 1, s.alfaN do check(dentro(s.cifras[i], s), "angosta, una cifra se sale de la portada") end
  s:Acomodar(N.AnchoPagina())
  -- Con la temática del bando, el saludo del bando.
  A.Set("nucleo.bando", true)
  K.ProbarBando("H")
  f = abrir("inicio")
  check(s.tema and (s.Titulo:GetText() or ""):find("Lok'tar", 1, true), "con la Horda, la portada no saluda con su bando")
  A.Set("nucleo.bando", false)
  K.ProbarBando(nil)
  f:Hide()
end)

step("82: los 3 estilos", function()
  local antes = K.Estilo()
  for _, e in ipairs({ "clasico", "cristal", "alfa" }) do
    K.SetEstilo(e) RUN_TIMERS(1)
    local f = abrir("inicio")
    check(f.Side:IsShown() and f.PageHead:IsShown(), e .. ": falta la barra o la cabecera")
    local n = 0
    for _, b in ipairs(f.sectionButtons) do if b:IsShown() and b.psOn then n = n + 1 end end
    check(n == 1, e .. ": la sección elegida no se marca (" .. n .. ")")
    f:Hide()
  end
  K.SetEstilo(antes or "alfa") RUN_TIMERS(1)
end)

---------------------------------------------------------------------------
-- 84. La bienvenida de la 1.4.0
---------------------------------------------------------------------------
step("84: la bienvenida de la 1.4 con «Pruébalo»", function()
  local Bv = NS_OF("Alfa_Bienvenida")
  local nota = Bv.NotaDe("1.4.0")
  check(nota and nota.bienvenida, "la 1.4.0 no trae su bienvenida")
  if not nota then return end
  local quiere = { anuncios140 = true, acomodar = true, bando = true, temporada = true, pantallas = true }
  for _, p in ipairs(nota.puntos) do
    check(p.titulo, "un punto de la 1.4.0 no tiene título")
    check(Bv.IR_NOTA[p[3]], "el punto «" .. tostring(p[3]) .. "» no tiene «Pruébalo»")
    quiere[p[3]] = nil
  end
  for k in pairs(quiere) do check(false, "a la bienvenida le falta: " .. k) end
  check(Bv.AbrirNotas(nota), "no abrió la bienvenida") RUN_TIMERS(1)
  local nv = rawget(_G, "AlfaNotasVersion")
  check(nv and nv:IsShown() and nv:GetWidth() >= 680, "la bienvenida no es la ventana ancha")
  local bt = Bv.BloqueTarjetas and nil
  local hechas = 0
  local llamado
  local viejo = Bv.IR_NOTA.temporada
  Bv.IR_NOTA.temporada = function() llamado = true end
  Bv.AbrirNotas(nota) RUN_TIMERS(1)
  local function buscar(f)
    for _, h in ipairs({ f:GetChildren() }) do
      if rawget(h, "Ir") and rawget(h, "Titulo") and h:IsShown() then
        hechas = hechas + 1
        check(h.Ir:IsShown(), "una tarjeta no tiene «Pruébalo»")
        check(dentro(h.Ir, h), "«Pruébalo» se sale de su tarjeta")
        if (h.Titulo:GetText() or ""):find("temporada") then bt = h end
      end
      buscar(h)
    end
  end
  buscar(nv)
  check(hechas == #nota.puntos, "no salieron todas las tarjetas: " .. hechas)
  if FOTOS then local fondo = fondoNoche(nv) SNAP("bienvenida", fondo, { nv }) fondo:Hide() end
  check(bt, "no está la tarjeta de tu temporada")
  if bt then
    bt.Ir.alfaIr = Bv.IR_NOTA.temporada
    bt.Ir:Click()
    check(llamado, "«Pruébalo» no llevó a tu temporada")
    check(not nv:IsShown(), "«Pruébalo» no cerró la bienvenida")
  end
  Bv.IR_NOTA.temporada = viejo
  -- «Enséñamelo» sigue recorriendo los puntos.
  check(Bv.RecorridoNotas(nota) == #nota.puntos, "«Enséñamelo» no recorre todos los puntos")
  -- Una versión vieja sigue con su lista de siempre.
  local vieja = Bv.NotaDe("1.3.8")
  Bv.AbrirNotas(vieja) RUN_TIMERS(1)
  check(nv:GetWidth() < 600, "las notas de una versión vieja quedaron anchas")
  if Bv.CerrarNotas then Bv.CerrarNotas() end
end)

print(string.format("prueba_140_ventana: %d pasos, %d errores", pasos, #ERRORS))
