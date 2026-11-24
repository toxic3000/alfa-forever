-- Prueba de la 1.3.8, área «cierre» (tools/prueba.py la corre con las demás):
-- la tarjeta de «¡Terminaste esta guía!» del rastreador.
--   1. con nombres de guía largos, en la vista amplia, la compacta y la
--      plegada, con la escala de ventanas de 0,8 a 1,3, y en los 10 idiomas:
--      la tarjeta, la mini tarjeta de la que sigue y sus botones quedan
--      dentro del rastreador y de su fondo, y ningún botón es más ancho que
--      su caja;
--   2. la X la cierra: el rastreador queda en su cabecera («Terminada»);
--      vuelve con otra guía o con «¿Qué sigue?»; su clic derecho ofrece
--      «No enseñar al terminar una guía» (rutas.tarjetaFin); en combate la X
--      no toma el ratón; «Seguir con esta guía» abre la que sigue;
--   3. el aviso del fin de guía (GUIDE_END) con «Seguir con <nombre largo>»:
--      su botón no sale de la tarjeta;
--   4. los otros cuadros vacíos (sin guía, sin paso, el de la ventana de
--      detalle y K.Vacio suelto): el botón nunca más ancho que el cuadro
--      (texto corto o dos renglones).
-- Con BANCO_FOTOS=1 dibuja las capturas (tools/banco/shot-138c-*.png).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["138c-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.3.8 cierre", msg) end end
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

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
NOW = NOW + 120

local N = AlfaNucleo
local A = N.A
local K = N.Kit
local E = A.Engine
local Ru = NS_OF("Alfa_Rutas")
local Rs = Ru.Rastreador
if N.Entrando then N.Entrando = function() return false end end
if A.UI.Options.frame then A.UI.Options.frame:Hide() end

-- Una guía terminada con un nombre largo, y la que sigue con otro largo.
local GUIA = { id = "prueba-138c", title = "Los Humedales & Laderas de Trabalomas", minLevel = 29, maxLevel = 30, steps = { {}, {}, {} } }
local GUIA2 = { id = "prueba-138c-otra", title = "Bosque del Ocaso", minLevel = 20, maxLevel = 25, steps = { {}, {} } }
local SIGH = { id = "prueba-138c-sig", title = "Los Humedales & Laderas de Trabalomas del Norte", minLevel = 30, maxLevel = 33, zone = 1437 }
local SIG = { id = SIGH.id, nombre = "Los Humedales & Laderas de Trabalomas del Norte (30–33)" }
local guia = GUIA
local vistas = { { status = "done" }, { status = "done" }, { status = "done" } }
local function motor(extra)
  local t = {
    GetLiveStep = function() return nil end,
    GetGuide = function() return guia end,
    GetStepIndex = function() return nil end,
    GetStepView = function(i) return vistas[i] end,
    GetProgress = function() return 3, 3 end,
    GetStepCount = function() return 3 end,
    SkippedOut = function() return nil end,
    GetRouteChoice = function() return nil end,
    NextGuide = function() return nil end,
    GetTabs = function() return {}, nil end,
  }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end
local GuiasReal = A.Guides.Get
local function conCierre(fn, extra)
  con(E, motor(extra), function()
    con(Ru.Siguiente, { Proponer = function() return SIG end }, function()
      con(A.Guides, { Get = function(id) if id == SIGH.id then return SIGH end return GuiasReal and GuiasReal(id) end }, fn)
    end)
  end)
end

local function F() return rawget(_G, "AlfaRastreador") end
local P = function() return Rs.Piezas() end

-- r se ve entero dentro de `dentro` (con 0,5 px de holgura).
local function adentro(r, dentro, que)
  if not (r and r:IsShown() and r:IsVisible()) then return end
  local l, rr, t, b = r:GetLeft(), r:GetRight(), r:GetTop(), r:GetBottom()
  local L2, R2, T2, B2 = dentro:GetLeft(), dentro:GetRight(), dentro:GetTop(), dentro:GetBottom()
  if not (l and L2) then return end
  check(l >= L2 - 0.5 and rr <= R2 + 0.5 and t <= T2 + 0.5 and b >= B2 - 0.5,
    ("%s se sale: [%.1f, %.1f, %.1f, %.1f] fuera de [%.1f, %.1f, %.1f, %.1f]"):format(que, l, rr, t, b, L2, R2, T2, B2))
end
-- El texto de un botón cabe en el botón (en un renglón, o en dos sin pasarse).
local function botonCabe(b, que)
  if not (b and b:IsShown()) then return end
  local bw = b:GetWidth()
  if b.alfaDosLineas then
    check(b.Texto:GetWidth() <= bw + 0.5, que .. ": el texto en dos renglones es más ancho que el botón")
    check(K.AltoTexto(b.Texto) <= b:GetHeight(), que .. ": el texto en dos renglones es más alto que el botón")
  else
    check(K.AnchoTexto(b.Texto) <= bw + 0.5, ("%s: el texto (%d) no cabe en el botón (%d)"):format(que, K.AnchoTexto(b.Texto), bw))
  end
end

-- La tarjeta completa: todo adentro.
local function revisarTarjeta(que)
  local t = P().fin
  check(t and t:IsShown(), que .. ": no se ve la tarjeta de «¡Terminaste!»")
  if not (t and t:IsShown()) then return end
  local f = F()
  adentro(t, f, que .. ": la tarjeta")
  for _, k in ipairs({ "Sobre", "Titulo", "Texto", "Cerrar", "Accion", "Sig", "Lobo" }) do adentro(t[k], t, que .. ": " .. k) end
  local s = t.Sig
  for _, k in ipairs({ "Nombre", "Meta", "Uno", "Dos", "Icono" }) do adentro(s[k], s, que .. ": la que sigue, " .. k) end
  botonCabe(t.Accion, que .. ": el botón de la tarjeta")
  botonCabe(s.Uno, que .. ": «Seguir»")
  botonCabe(s.Dos, que .. ": «Elegir otra guía»")
  -- La X no se encima con el texto.
  local xl = t.Cerrar:GetLeft()
  for _, k in ipairs({ "Sobre", "Titulo" }) do
    local r = t[k]:GetRight()
    check(not (r and xl) or r <= xl + 0.5, ("%s: %s se encima con la X (%.1f > %.1f)"):format(que, k, r or 0, xl or 0))
  end
  -- El pie del rastreador no se ve, y el fondo cubre la tarjeta.
  check(f:GetBottom() <= t:GetBottom() - 4, que .. ": la tarjeta queda pegada o fuera del fondo de abajo")
end

---------------------------------------------------------------------------
-- Los 10 idiomas: el diccionario de cada uno (el que arma tools/textos.py y
-- los textos nuevos de esta área), el inglés del módulo, y el español.
---------------------------------------------------------------------------
local function leerJson(ruta)
  local f = io and io.open(ruta, "rb")
  if not f then return {} end
  local s = f:read("*a")
  f:close()
  local out = {}
  local function cadena(i)
    local partes = {}
    i = i + 1
    while true do
      local c = s:sub(i, i)
      if c == '"' then return table.concat(partes), i + 1 end
      if c == "\\" then
        local e = s:sub(i + 1, i + 1)
        if e == "n" then partes[#partes + 1] = "\n" elseif e == "t" then partes[#partes + 1] = "\t"
        elseif e == "u" then
          local cp = tonumber(s:sub(i + 2, i + 5), 16)
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
    local b = s:find('"', s:find(":", j, true), true)
    local v, j2 = cadena(b)
    out[k] = v
    i = j2
  end
  return out
end

local function diccionario(loc)
  if loc == "esMX" or loc == "esES" then return {} end
  if loc == "enUS" then
    local M2 = {}
    local f = loadfile and loadfile("src/Alfa_Rutas/Textos.lua")
    if f then pcall(f, "Alfa_Rutas", M2) end
    return M2.EN or {}
  end
  local d = {}
  local f = loadfile and loadfile("src/Alfa_Nucleo/Idiomas/" .. loc .. ".lua")
  if f then
    local gl, prev = GetLocale, rawget(_G, "AlfaNucleoIdiomas")
    GetLocale = function() return loc end
    AlfaNucleoIdiomas = {}
    pcall(f)
    d = AlfaNucleoIdiomas[loc] or {}
    GetLocale, AlfaNucleoIdiomas = gl, prev
  end
  for k, v in pairs(leerJson("textos/" .. loc .. "/Alfa_1.3.8-cierre.json")) do d[k] = v end
  return d
end

local L = Ru.L
local mtReal = getmetatable(L)
local function vaciarL() for k in pairs(L) do rawset(L, k, nil) end end
local function conIdioma(loc, fn)
  local d = diccionario(loc)
  vaciarL()
  setmetatable(L, { __index = function(_, k) return d[k] or N.SinContexto(k) end })
  local ok, e = pcall(fn, d)
  vaciarL()
  setmetatable(L, mtReal)
  if not ok then error(e, 0) end
end
local IDIOMAS = { "esMX", "esES", "enUS", "deDE", "frFR", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }

---------------------------------------------------------------------------
-- 1. Dentro del rastreador en las tres vistas, con la escala y en 10 idiomas
---------------------------------------------------------------------------

local VISTAS = {
  { "amplia", function() A.Set("rutas.seguimientoCompleto", true) Rs.Plegar(false) end },
  { "compacta", function() A.Set("rutas.seguimientoCompleto", false) Rs.Plegar(false) end },
  { "plegada", function() A.Set("rutas.seguimientoCompleto", false) Rs.Plegar(true) end },
}
local completoAntes, plegadaAntes = A.Get("rutas.seguimientoCompleto"), Rs.Plegada()

step("La tarjeta dentro del rastreador: 3 vistas, escala y 10 idiomas", function()
  Rs.Mostrar()
  RUN_TIMERS(2)
  check(F() and F():IsShown(), "el rastreador no se ve")
  conCierre(function()
    for _, loc in ipairs(IDIOMAS) do
      conIdioma(loc, function(d)
        if loc == "deDE" then check(d["Seguir con esta guía"] ~= nil, "falta el alemán de «Seguir con esta guía»") end
        for _, vista in ipairs(VISTAS) do
          vista[2]()
          for _, esc in ipairs({ 1, 0.8, 1.3 }) do
            A.Set("nucleo.escalaVentanas", esc)
            if K.EscalarTodas then K.EscalarTodas() end
            Rs.Pintar()
            revisarTarjeta(("%s, %s, escala %.1f"):format(loc, vista[1], esc))
          end
          A.Set("nucleo.escalaVentanas", 1)
          if loc == "esMX" or loc == "deDE" or loc == "ruRU" or loc == "frFR" then SNAP("tarjeta-" .. vista[1] .. "-" .. loc, F()) end
        end
        -- El texto de la tarjeta va en el idioma.
        local t = P().fin
        if loc == "deDE" then check(t.Sig.Uno.Texto:GetText() == d["Seguir con esta guía"], "el botón no va en alemán: " .. tostring(t.Sig.Uno.Texto:GetText())) end
      end)
    end
  end)
  A.Set("rutas.seguimientoCompleto", completoAntes)
  Rs.Plegar(plegadaAntes)
end)

step("La que sigue: nombre, zona y niveles; «Seguir con esta guía» la abre", function()
  A.Set("rutas.seguimientoCompleto", false)
  Rs.Plegar(false)
  local abierta
  conCierre(function()
    con(Ru.Siguiente, { Seguir = function(p) abierta = p and p.id return true end }, function()
      Rs.Pintar()
      local t = P().fin
      check(t:IsShown(), "no se ve la tarjeta")
      check(t.Titulo:GetText() == "¡Terminaste esta guía!", "el título no festeja: " .. tostring(t.Titulo:GetText()))
      check(t.Sig:IsShown() and t.Sig.Nombre:GetText() == SIGH.title, "la mini tarjeta no dice el nombre (sin los niveles): " .. tostring(t.Sig.Nombre:GetText()))
      local meta = t.Sig.Meta:IsShown() and t.Sig.Meta:GetText() or ""
      check(meta:find("30", 1, true) and meta:find("33", 1, true), "la mini tarjeta no dice los niveles: " .. meta)
      check(P().cab.Sub:GetText():find("Terminada", 1, true), "la cabecera no dice «Terminada»: " .. tostring(P().cab.Sub:GetText()))
      check(not P().vacio:IsShown(), "el cuadro vacío viejo sale junto con la tarjeta")
      FIRE(t.Sig.Uno, "OnClick", "LeftButton")
      check(abierta == SIGH.id, "«Seguir con esta guía» no abrió la que sigue")
    end)
    -- El camino que se abre en dos y sin la que sigue: el botón en la tarjeta.
    con(E, { GetRouteChoice = function() return { options = { "a", "b" } } end }, function()
      Rs.Pintar()
      local t = P().fin
      check(not t.Sig:IsShown() and t.Accion:IsShown() and t.Accion.Texto:GetText() == "Elegir mi camino", "con dos caminos no ofrece «Elegir mi camino»")
      revisarTarjeta("dos caminos")
    end)
    con(Ru.Siguiente, { Proponer = function() return nil end }, function()
      Rs.Pintar()
      local t = P().fin
      check(t.Accion:IsShown() and t.Accion.Texto:GetText() == "Elegir qué sigue", "sin la que sigue no ofrece «Elegir qué sigue»")
      revisarTarjeta("sin la que sigue")
      SNAP("tarjeta-sin-siguiente", F())
    end)
  end)
end)

---------------------------------------------------------------------------
-- 2. La X
---------------------------------------------------------------------------

step("La X: el rastreador queda en su cabecera y la tarjeta vuelve con otra guía", function()
  A.Set("rutas.seguimientoCompleto", false)
  Rs.Plegar(false)
  conCierre(function()
    guia = GUIA
    Rs.Pintar()
    local t = P().fin
    check(t:IsShown() and t.Cerrar:IsShown(), "la tarjeta no trae su X")
    check(t.Cerrar:IsMouseEnabled(), "fuera de combate la X no toma el clic")
    SNAP("tarjeta-x", F())
    FIRE(t.Cerrar, "OnClick", "LeftButton")
    check(not t:IsShown(), "la X no cierra la tarjeta")
    local cab = P().cab
    check(math.abs(F():GetHeight() - cab:GetHeight()) < 0.5, ("cerrada, el rastreador no queda en su cabecera (%.1f, cabecera %.1f)"):format(F():GetHeight(), cab:GetHeight()))
    check(cab.Sub:GetText():find("Terminada", 1, true), "cerrada, la cabecera no dice «Terminada»")
    check(not P().vacio:IsShown(), "cerrada, sale el cuadro vacío viejo")
    check(Rs.FinOculta(), "Rs.FinOculta no lo sabe")
    SNAP("tarjeta-cerrada", F())
    Rs.Pintar()
    check(not t:IsShown(), "al repintar, la tarjeta cerrada vuelve")
    -- «¿Qué sigue?» del menú la trae.
    Rs.PedirFin()
    check(t:IsShown(), "«¿Qué sigue?» no trae la tarjeta")
    Rs.CerrarFin()
    -- Otra guía (también terminada): la tarjeta vuelve.
    guia = GUIA2
    Rs.Pintar()
    check(t:IsShown(), "con otra guía la tarjeta no vuelve")
    guia = GUIA
    -- Clic derecho: «No enseñar al terminar una guía».
    local menu
    con(K, { Menu = function(_, op) menu = op end }, function()
      FIRE(t.Cerrar, "OnClick", "RightButton")
    end)
    check(menu and menu[2] and menu[2].texto == "No enseñar al terminar una guía", "el clic derecho no ofrece «No enseñar al terminar una guía»")
    if menu then menu[2].valor() end
    check(A.Get("rutas.tarjetaFin") == false and not t:IsShown(), "«No enseñar al terminar una guía» no la apaga")
    guia = GUIA2
    Rs.Pintar()
    check(not t:IsShown(), "apagada, la tarjeta sale con otra guía")
    Rs.PedirFin()
    check(t:IsShown(), "apagada, «¿Qué sigue?» no la trae")
    guia = GUIA
    Rs.Pintar()
    check(not t:IsShown(), "apagada, sale al volver a la guía")
    A.Set("rutas.tarjetaFin", true)
    Rs.Pintar()
    check(t:IsShown(), "prendida otra vez, no sale")
    -- En combate ni la X ni la tarjeta toman el ratón.
    con(_G, { InCombatLockdown = function() return true end }, function()
      FIRE_EVENT("PLAYER_REGEN_DISABLED")
      check(not t.Cerrar:IsMouseEnabled() and not t:IsMouseEnabled(), "en combate la X o la tarjeta toman el ratón")
      Rs.Pintar()
      check(not t.Cerrar:IsMouseEnabled(), "en combate, al repintar, la X toma el ratón")
    end)
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    Rs.Pintar()
    check(t.Cerrar:IsMouseEnabled(), "al salir de combate la X no vuelve a tomar el clic")
  end)
end)

---------------------------------------------------------------------------
-- 3. El aviso del fin de guía
---------------------------------------------------------------------------

step("El aviso del fin de guía: «Seguir con <nombre largo>» no sale de su tarjeta", function()
  local fin = A.Reemplazo and A.Reemplazo("GUIDE_END")
  check(fin ~= nil, "no hay reemplazo de GUIDE_END")
  if not fin then return end
  conCierre(function()
    for _, loc in ipairs({ "esMX", "deDE", "ruRU" }) do
      conIdioma(loc, function()
        pcall(fin, { modelo = { complete = true, label = GUIA.title } })
        Rs.Pintar()
        local b = P().aviso
        check(b:IsShown(), loc .. ": no sale el aviso del fin")
        adentro(b, F(), loc .. ": el aviso")
        adentro(b.Uno, b, loc .. ": su botón")
        adentro(b.Dos, b, loc .. ": «Después»")
        botonCabe(b.Uno, loc .. ": su botón")
        check(not P().fin:IsShown(), loc .. ": la tarjeta sale junto con el aviso del fin")
        if loc == "deDE" then SNAP("aviso-fin-deDE", F()) end
        pcall(fin, { accion = "ocultar" })
        RUN_TIMERS(1)
      end)
    end
  end)
end)

---------------------------------------------------------------------------
-- 4. Los otros cuadros vacíos
---------------------------------------------------------------------------

step("Los otros cuadros vacíos: el botón nunca más ancho que el cuadro", function()
  A.Set("rutas.seguimientoCompleto", false)
  Rs.Plegar(false)
  -- Sin guía.
  con(E, motor({ GetGuide = function() return nil end }), function()
    for _, loc in ipairs({ "esMX", "deDE", "ruRU", "frFR" }) do
      conIdioma(loc, function()
        local v = P().vacio
        v.alfaVacio = nil
        Rs.Pintar()
        check(v:IsShown(), loc .. ": sin guía no sale el cuadro vacío")
        adentro(v, F(), loc .. ": el cuadro sin guía")
        adentro(v.Accion, v, loc .. ": el botón sin guía")
        botonCabe(v.Accion, loc .. ": el botón sin guía")
        if loc == "deDE" then SNAP("sin-guia-deDE", F()) end
      end)
    end
  end)
  -- Sin paso (algo omitido): «Recuperar lo omitido».
  local vs = { { status = "done" }, { status = "done", skipped = true, title = "Mata a los raptores de las Tierras Altas de Arathi" }, { status = "done" } }
  con(E, motor({ GetStepView = function(i) return vs[i] end }), function()
    local v = P().vacio
    v.alfaVacio = nil
    Rs.Pintar()
    check(v:IsShown() and not P().fin:IsShown(), "sin paso no sale el cuadro de «no tiene un paso»")
    adentro(v.Accion, v, "el botón de «Recuperar lo omitido»")
    botonCabe(v.Accion, "el botón de «Recuperar lo omitido»")
  end)
  -- La ventana de detalle con la guía terminada: el cuadro con «Seguir con…».
  conCierre(function()
    Rs.AbrirDetalle()
    Rs.PintarDetalle()
    local v = P().vacioDetalle
    check(v and v:IsShown(), "el detalle no enseña el cuadro de la guía terminada")
    if v and v:IsShown() then
      check(v.Accion:GetWidth() <= v:GetWidth() + 0.5, "en el detalle el botón es más ancho que el cuadro")
      botonCabe(v.Accion, "el botón del detalle")
    end
    local D = rawget(_G, "AlfaRastreadorDetalle")
    if D then D:Hide() end
  end)
  -- K.Vacio suelto, angosto: el texto corto; sin corto, dos renglones.
  local padre = CreateFrame("Frame", nil, UIParent)
  padre:SetSize(220, 400)
  padre:SetPoint("CENTER")
  local largo = "Seguir con Los Humedales & Laderas de Trabalomas del Norte (30–33)"
  local v = K.Vacio(padre, { lobo = "aullando", titulo = "¡Terminaste esta guía!", texto = "Prueba",
    accion = { texto = largo, corto = "Seguir con la siguiente", icono = "ic-ruta", alClic = function() end } })
  v:SetPoint("TOPLEFT", padre, "TOPLEFT")
  v:Acomodar(220)
  check(v.Accion.Texto:GetText() == "Seguir con la siguiente", "K.Vacio no usa el texto corto: " .. tostring(v.Accion.Texto:GetText()))
  check(v.Accion:GetWidth() <= 220.5, "K.Vacio deja el botón más ancho que el cuadro")
  v:Set({ lobo = "aullando", titulo = "x", accion = { texto = largo, icono = "ic-ruta", alClic = function() end } })
  v:Acomodar(220)
  check(v.Accion.alfaDosLineas and v.Accion:GetWidth() <= 220.5, "sin texto corto, el botón no baja a dos renglones")
  check(v.Accion.Texto:GetText() == largo, "en dos renglones el texto no va entero")
  botonCabe(v.Accion, "K.Vacio en dos renglones")
  -- Al pulsarlo sigue en dos renglones.
  FIRE(v.Accion, "OnMouseDown", "LeftButton")
  FIRE(v.Accion, "OnMouseUp", "LeftButton")
  check(v.Accion:GetWidth() <= 220.5 and v.Accion.alfaDosLineas, "al pulsarlo, el botón vuelve a crecer")
  -- Un texto que cabe: vuelve a su ancho natural y a un renglón.
  v:Set({ lobo = "aullando", titulo = "x", accion = { texto = "Seguir con Durotar", icono = "ic-ruta", alClic = function() end } })
  v:Acomodar(220)
  check(not v.Accion.alfaDosLineas and v.Accion.Texto:GetText() == "Seguir con Durotar", "un texto que cabe sigue en dos renglones")
  botonCabe(v.Accion, "K.Vacio de vuelta en un renglón")
  v:Set({ lobo = "aullando", titulo = "x", accion = { texto = largo, icono = "ic-ruta", alClic = function() end } })
  v:Acomodar(220)
  SNAP("kvacio-angosto", padre)
  padre:Hide()
end)

print(("prueba_138_cierre: %d pasos"):format(pasos))
