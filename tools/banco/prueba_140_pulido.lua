-- Prueba de la 1.4.0, área «pulido» (mejoras 110 a 121):
--   110. /alfa con un error de dedo: «¿Quisiste decir…?» sin llenar el chat.
--   111. /alfa comandos: la ventana con todos los comandos y su buscador.
--   112. Los botones apagados dicen por qué (globo), en Avisos, Combate y Citas.
--   113. Avisos: con la calma puesta, cuánto falta y «Quitar la calma».
--   114. Pregúntale a Lya sin respuesta: buscarlo en la Enciclopedia o en los ajustes.
--   115. Enciclopedia sin resultados: «Quitar los filtros» o «Borrar la búsqueda».
--   116. La Jauría: «Lobos silenciados» a la vista, con «Quitar el silencio».
--   117. La campanita y el globito del minimapa: lo último que no viste.
--   118. Los diálogos de Alfa aceptan con Enter (salvo los de peligro).
--   119. El buscador: Esc con algo escrito lo borra; otro Esc sale.
-- Con BANCO_FOTOS=1 dibuja las capturas (shot-140-pulido-*.png; BANCO_CAPTURAS elige la carpeta).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["140-pulido-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.4.0 pulido", msg) end end
local function T(n) RUN_TIMERS(n or 3) end

BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N, B = AlfaNucleo, AlfaBienvenida
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
NOW = NOW + 120

local A = Alfa
local K = N.Kit
if N.Entrando then N.Entrando = function() return false end end
if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end

local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = rawget(t, k) } rawset(t, k, v) end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(t, k, a.v) end
  if not ok then error(e) end
end
-- Cuenta las líneas que se escriben en el chat mientras corre fn.
local function lineasChat(fn)
  local n = 0
  con(DEFAULT_CHAT_FRAME, { AddMessage = function() n = n + 1 end }, fn)
  return n
end
local function fondo(de)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetPoint("TOPLEFT", de, "TOPLEFT", -24, 24)
  f:SetPoint("BOTTOMRIGHT", de, "BOTTOMRIGHT", 24, -24)
  local c = f:CreateTexture(nil, "BACKGROUND")
  c:SetAllPoints(f)
  c:SetTexture("white")
  c:SetGradient("VERTICAL", CreateColor(0.03, 0.04, 0.06, 1), CreateColor(0.09, 0.11, 0.16, 1))
  f:Show()
  return f
end
-- ¿Se ve? (él y todos sus padres)
local function visible(f)
  while f do
    if f.IsShown and not f:IsShown() then return false end
    f = rawget(f, "_parent")
  end
  return true
end
-- El primer texto a la vista bajo `raiz` que contiene `t`: -> fontstring, su marco
local function buscarTexto(raiz, t)
  local hallado, dueno
  local function walk(f)
    if hallado or not f or not f:IsShown() then return end
    for _, c in ipairs(rawget(f, "_children") or {}) do
      if hallado then return end
      if c._kind == "FontString" then
        local x = c:GetText()
        if c:IsShown() and type(x) == "string" and x:find(t, 1, true) then hallado, dueno = c, f return end
      elseif c._kind ~= "Texture" then
        walk(c)
      end
    end
  end
  walk(raiz)
  return hallado, dueno
end
-- Lo que diría el globo de un marco (K.MostrarInfo capturado).
local function globo(f)
  local titulo, texto
  con(K, { MostrarInfo = function(_, t, x) titulo, texto = t, x end }, function() FIRE(f, "OnEnter") FIRE(f, "OnLeave") end)
  return titulo, texto
end

---------------------------------------------------------------------------
-- 110. Un comando con un error de dedo
---------------------------------------------------------------------------
step("110: un error de dedo sugiere el comando y no llena el chat", function()
  local Co = N.Comandos
  check(Co and Co.Lista, "falta N.Comandos") if not Co then return end
  local lista = Co.Lista()
  check(#lista >= 40, "la lista de comandos salió corta: " .. #lista)
  check(Co.Existe("comandos") and Co.Existe("pantallas") and Co.Existe("help") and Co.Existe("ayuda"), "faltan comandos conocidos en la lista")
  Co.ultimo = nil
  local n = lineasChat(function() SlashCmdList.ALFA("pantalas") end)
  check(Co.ultimo and Co.ultimo:find("/alfa pantallas", 1, true), "no sugirió /alfa pantallas: " .. tostring(Co.ultimo))
  check(n >= 1 and n <= 2, "llenó el chat: " .. n .. " líneas")
  check(Co.Parecido("temporda") == "temporada", "temporda no sugiere temporada: " .. tostring(Co.Parecido("temporda")))
  check(Co.Parecido("ajustes") == "options", "ajustes no sugiere options")
  check(Co.Parecido("pant") == "pantallas", "un comienzo único no sugiere el comando: " .. tostring(Co.Parecido("pant")))
  Co.ultimo = nil
  SlashCmdList.ALFA("xqzvw")
  check(Co.ultimo and not Co.ultimo:find("Quisiste", 1, true) and Co.ultimo:find("/alfa comandos", 1, true), "lo que no se parece a nada no dice dónde ver todos")
  -- Un comando que sí existe sigue llegando a su dueño (y uno nuevo se aprende).
  local corrio
  A.RegisterCommand("pruebapulido", function(r) corrio = r end, "prueba")
  SlashCmdList.ALFA("pruebapulido hola")
  check(corrio == "hola", "un comando registrado después no llegó: " .. tostring(corrio))
  -- /alfa help sigue escribiendo todo (lo pediste).
  local n2 = lineasChat(function() SlashCmdList.ALFA("help") end)
  check(n2 >= 40, "/alfa help ya no escribe la lista: " .. n2)
end)

---------------------------------------------------------------------------
-- 111. /alfa comandos
---------------------------------------------------------------------------
step("111: la ventana de los comandos, con buscador y clic que lo escribe", function()
  local abierto
  con(_G, { ChatFrame_OpenChat = function(t) abierto = t end }, function()
    SlashCmdList.ALFA("comandos")
    T(2)
    local v = rawget(_G, "AlfaComandos")
    check(v and v:IsShown(), "no abrió la ventana de comandos") if not v then return end
    local fs = buscarTexto(v, "/alfa temporada")
    check(fs ~= nil, "la ventana no lista /alfa temporada")
    local f = fondo(v)
    SNAP("comandos", v)
    f:Hide()
    -- Buscar «pesca».
    SlashCmdList.ALFA("comandos pesca")
    T(2)
    check(buscarTexto(v, "/alfa pesca") ~= nil, "buscar «pesca» no dejó /alfa pesca")
    check(buscarTexto(v, "/alfa temporada") == nil, "buscar «pesca» dejó /alfa temporada")
    local _, tarjeta = buscarTexto(v, "/alfa pesca")
    while tarjeta and not tarjeta:GetScript("OnClick") and not tarjeta:GetScript("OnMouseUp") do tarjeta = rawget(tarjeta, "_parent") end
    if tarjeta then
      if tarjeta:GetScript("OnClick") then FIRE(tarjeta, "OnClick", "LeftButton") else FIRE(tarjeta, "OnMouseUp", "LeftButton") end
    end
    check(abierto and abierto:find("^/alfa pesca"), "el clic no dejó el comando en el chat: " .. tostring(abierto))
    -- Sin nada: el estado vacío con «Ver todos».
    SlashCmdList.ALFA("comandos zzqqxx")
    T(2)
    check(buscarTexto(v, "Ningún comando dice eso") ~= nil, "sin resultados no sale el estado vacío")
    local f2 = fondo(v)
    SNAP("comandos-vacio", v)
    f2:Hide()
    v:Cerrar()
  end)
end)

---------------------------------------------------------------------------
-- 112. Los botones apagados dicen por qué
---------------------------------------------------------------------------
step("112: un botón apagado dice por qué al pasar el ratón", function()
  local p = CreateFrame("Frame", nil, UIParent)
  local b = K.Boton(p, "Probar", function() end)
  b:SetActivo(false, "Porque sí.")
  check(K.PorQueDe(b) == "Porque sí.", "el porqué no quedó")
  local t, x = globo(b)
  check(t == "Probar" and x and x:find("Porque sí.", 1, true), "el globo no dice el porqué: " .. tostring(t) .. " / " .. tostring(x))
  b:SetActivo(true)
  check(K.PorQueDe(b) == nil, "encendido sigue con porqué")
  local t2, x2 = globo(b)
  check(not (x2 and x2:find("Porque sí.", 1, true)), "encendido el globo sigue con el porqué")
  -- Uno con su propio globo: el porqué va debajo, una vez.
  local c = K.Boton(p, "Otro", function() end, { ayuda = "Hace algo." })
  c:SetActivo(false, "No ahora.")
  local _, x3 = globo(c)
  check(x3 and x3:find("Hace algo.", 1, true) and x3:find("No ahora.", 1, true), "con globo propio no se juntan: " .. tostring(x3))
  c:SetActivo(false)
  check(K.PorQueDe(c) == nil, "apagado sin porqué guardó el viejo")
  p:Hide()
  -- En Avisos: «Marcar todo como visto» sin nada por ver.
  N.OlvidarAvisos()
  local v = N.VerAvisos()
  T(1)
  local _, boton = buscarTexto(v, "Marcar todo como visto")
  check(boton and not boton:IsEnabled() and K.PorQueDe(boton), "«Marcar todo como visto» apagado no dice por qué")
  v:Cerrar()
end)

---------------------------------------------------------------------------
-- 113. Avisos con la calma
---------------------------------------------------------------------------
step("113: Avisos dice cuánto falta de calma y la quita", function()
  N.Calma("30")
  local t, modo = N.TextoCalma()
  check(t and modo == "tiempo" and t:find("30 min", 1, true), "N.TextoCalma no dice lo que falta: " .. tostring(t))
  N.Perdido({ titulo = "Bolsas casi llenas", texto = "Te quedan 2 espacios.", icono = "ic-bolsas" })
  local v = N.VerAvisos()
  T(1)
  local fs = buscarTexto(v, "faltan")
  check(fs ~= nil, "la ventana no dice la calma")
  local f = fondo(v)
  SNAP("avisos-calma", v)
  f:Hide()
  local _, boton = buscarTexto(v, "Quitar la calma")
  check(boton ~= nil, "no está «Quitar la calma»")
  if boton then FIRE(boton, "OnClick", "LeftButton") end
  T(1)
  check(not N.EnCalma(), "«Quitar la calma» no la quitó")
  check(buscarTexto(v, "faltan") == nil, "la tarjeta de la calma se quedó")
  N.Calma("sesion")
  check((N.TextoCalma() or ""):find("salgas", 1, true), "la calma de la sesión no lo dice")
  N.Calma("no")
  v:Cerrar()
end)

---------------------------------------------------------------------------
-- 117. Lo último que no viste, en los globos
---------------------------------------------------------------------------
step("117: los globos dicen lo último que no viste", function()
  N.OlvidarAvisos()
  check(N.LineasSinVer(3) == nil, "sin avisos hay renglones")
  for i = 1, 5 do N.Perdido({ titulo = "Aviso número " .. i, texto = "x" }) end
  local l = N.LineasSinVer(3) or ""
  check(l:find("Aviso número 5", 1, true) and l:find("Aviso número 3", 1, true) and not l:find("Aviso número 2", 1, true),
    "no salen los 3 más nuevos: " .. l)
  check(l:find("2 más", 1, true), "no dice cuántos más: " .. l)
  N.Perdido({ titulo = ("Un aviso muy largo que no cabría en el globo de la campanita "):rep(2) })
  local l2 = N.LineasSinVer(1) or ""
  check(l2:find("\226\128\166", 1, true) and #l2 < 120, "un título largo no se acortó: " .. l2)
  -- El globito del minimapa.
  local mb = rawget(_G, "AlfaMinimapButton")
  if mb and N.PintarContadorPerdidos then
    N.PintarContadorPerdidos()
    local c = mb.alfaContador
    check(c ~= nil, "no hay globito en el minimapa")
    if c then
      local _, x = globo(c)
      check(x and x:find("Un aviso muy largo", 1, true), "el globito no dice lo último: " .. tostring(x))
    end
  end
  -- La campanita de la ventana de Alfa.
  local O = A.UI and A.UI.Options
  if O then
    A.Fire("SHOW_OPTIONS")
    T(2)
    local win = O.frame
    local campana
    for _, b in ipairs(win and win.sectionButtons or {}) do if b.psKey == O.CAMPANA and b:IsShown() then campana = b end end
    check(campana and campana.psTipLines and tostring(campana.psTipLines[1]):find("Un aviso muy largo", 1, true), "la campanita no dice lo último")
    win:Hide()
  end
  N.Calma("30")
  check((N.LineasSinVer(3) or ""):find("faltan", 1, true), "el globo no dice la calma")
  N.Calma("no")
  N.OlvidarAvisos()
end)

---------------------------------------------------------------------------
-- 114. Pregúntale a Lya sin respuesta
---------------------------------------------------------------------------
step("114: Lya sin respuesta ofrece buscar en otro lado", function()
  local Ly = AlfaLya
  check(Ly and Ly.Buscar, "falta AlfaLya.Buscar") if not (Ly and Ly.Buscar) then return end
  local E = AlfaEnciclopedia
  local buscado, ajuste
  con(E, { Buscar = function(t) buscado = t return true end }, function()
    con(A.UI.Options, { BuscarDesdeFuera = function(t) ajuste = t return true end }, function()
      Ly.Buscar("zzqqxx")
      T(2)
      local v = rawget(_G, "AlfaLyaGuia")
      check(v and v:IsShown(), "no abrió Pregúntale a Lya") if not v then return end
      local _, b1 = buscarTexto(v, "en la Enciclopedia")
      local _, b2 = buscarTexto(v, "en los ajustes")
      check(b1 and b2, "el estado vacío no ofrece los dos caminos")
      -- 120: lo de adentro usa todo el ancho de la ventana (sin franja vacía a la derecha).
      local caja
      local function buscarCaja(x) if caja then return end if x.Campo and x.Limpiar then caja = x return end for _, h in ipairs({ x:GetChildren() }) do buscarCaja(h) end end
      buscarCaja(v)
      check(caja and math.abs(caja:GetWidth() - v:AnchoCuerpo()) < 2, "el buscador de Lya no usa todo el ancho: " .. tostring(caja and caja:GetWidth()) .. " de " .. v:AnchoCuerpo())
      local f = fondo(v)
      SNAP("lya-sin-respuesta", v)
      f:Hide()
      if b1 then FIRE(b1, "OnClick", "LeftButton") end
      check(buscado == "zzqqxx", "no buscó en la Enciclopedia: " .. tostring(buscado))
      Ly.Buscar("zzqqxx")
      T(2)
      local _, b3 = buscarTexto(v, "en los ajustes")
      if b3 then FIRE(b3, "OnClick", "LeftButton") end
      check(ajuste == "zzqqxx", "no buscó en los ajustes: " .. tostring(ajuste))
      if v:IsShown() then v:Cerrar() end
    end)
  end)
  -- Y la de verdad: la ventana de Alfa queda buscando.
  local O = A.UI.Options
  check(O.BuscarDesdeFuera("escala"), "BuscarDesdeFuera no abrió")
  T(2)
  check(O.frame and O.frame:IsShown() and O.frame.Search and O.frame.Search:GetText() == "escala", "la ventana no quedó buscando «escala»")
  O.frame:Hide()
end)

---------------------------------------------------------------------------
-- 115. Enciclopedia sin resultados
---------------------------------------------------------------------------
step("115: la Enciclopedia sin resultados ofrece el camino", function()
  local E = NS_OF("Alfa_Enciclopedia")
  if not (E and E.V and E.V.Abrir) then print("AVISO: no está la Enciclopedia") return end
  check(E.V.QuitarFiltrosDe and E.V.VacioSin, "faltan V.QuitarFiltrosDe / V.VacioSin")
  local o = E.V.VacioSin("montura", true)
  check(o.accion and o.accion.texto == "Quitar los filtros", "con filtros no ofrece quitarlos")
  E.V.Abrir({ texto = "zzqqxxww", tipo = "objeto" })
  T(30)
  local v = rawget(_G, "AlfaEnciclopediaVentana")
  check(v and v:IsShown(), "la Enciclopedia no abrió") if not v then return end
  local _, b = buscarTexto(v, "Borrar la búsqueda")
  check(b ~= nil and visible(b), "sin resultados no ofrece «Borrar la búsqueda»")
  local f = fondo(v)
  SNAP("enciclopedia-vacia", v)
  f:Hide()
  if b then FIRE(b, "OnClick", "LeftButton") T(5) end
  check(buscarTexto(v, "Borrar la búsqueda") == nil, "«Borrar la búsqueda» no borró")
  -- Monturas empiezan con un filtro («conseguible»): sin nada, «Quitar los filtros».
  E.V.Abrir({ texto = "zzqqxxww", tipo = "montura" })
  T(30)
  local _, q = buscarTexto(v, "Quitar los filtros")
  check(q ~= nil, "con filtros no ofrece «Quitar los filtros»")
  if q then FIRE(q, "OnClick", "LeftButton") T(5) end
  if E.V.Cerrar then E.V.Cerrar() end
end)

---------------------------------------------------------------------------
-- 116. Lobos silenciados
---------------------------------------------------------------------------
step("116: los lobos silenciados a la vista y «Quitar el silencio»", function()
  local MN = NS_OF("Alfa_Manada")
  local Ca = MN and MN.Callados
  check(Ca and Ca.Ventana, "falta Callados.Ventana") if not (Ca and Ca.Ventana) then return end
  Ca.QuitarTodos()
  local v = Ca.Ventana()
  T(1)
  check(buscarTexto(v, "No silenciaste a ningún lobo") ~= nil, "sin nadie no sale el estado vacío")
  local _, todos = buscarTexto(v, "Quitar a todos")
  check(todos and not todos:IsEnabled() and K.PorQueDe(todos), "«Quitar a todos» sin nadie no está apagado con su porqué")
  Ca.Poner("Ana Smith", true)
  Ca.Poner("Beto Ruiz", true)
  Ca.Ventana()
  T(1)
  check(buscarTexto(v, "Ana Smith") and buscarTexto(v, "Beto Ruiz"), "la lista no tiene a los dos")
  local f = fondo(v)
  SNAP("silenciados", v)
  f:Hide()
  local _, quitar = buscarTexto(v, "Quitar el silencio")
  if quitar then FIRE(quitar, "OnClick", "LeftButton") end
  T(1)
  check(#Ca.Lista() == 1, "«Quitar el silencio» no quitó a uno: " .. #Ca.Lista())
  v:Cerrar()
  -- La fila en los ajustes de La Jauría.
  N.Abrir("manada")
  T(3)
  local O = A.UI.Options
  local fs, fila = buscarTexto(O.frame, "Lobos silenciados")
  check(fs ~= nil, "la página de La Jauría no tiene «Lobos silenciados»")
  check(buscarTexto(O.frame, "Ver (1)") ~= nil, "el botón no dice cuántos")
  Ca.QuitarTodos()
  O.frame:Hide()
end)

---------------------------------------------------------------------------
-- 118. Enter en los diálogos
---------------------------------------------------------------------------
step("118: Enter acepta un diálogo (no uno de peligro)", function()
  local aceptado = 0
  K.Dialogo({ titulo = "¿Probar?", texto = "Una prueba.", pedido = true, alAceptar = function() aceptado = aceptado + 1 end })
  local d = rawget(_G, "AlfaKitDialogo")
  check(d and d:IsShown(), "el diálogo no salió") if not d then return end
  local propaga
  con(d, { SetPropagateKeyboardInput = function(_, v) propaga = v end }, function()
    FIRE(d, "OnKeyDown", "W")
    check(propaga == true, "una tecla cualquiera no sigue al juego")
    FIRE(d, "OnKeyDown", "ENTER")
    check(propaga == false, "Enter siguió al juego")
  end)
  check(aceptado == 1, "Enter no aceptó")
  check(not K.DialogoAbierto(), "el diálogo se quedó abierto")
  local peligro = 0
  K.Dialogo({ titulo = "¿Borrar?", pedido = true, peligro = true, alAceptar = function() peligro = peligro + 1 end })
  FIRE(d, "OnKeyDown", "ENTER")
  check(peligro == 0 and K.DialogoAbierto(), "Enter aceptó uno de peligro")
  K.CerrarDialogo()
end)

---------------------------------------------------------------------------
-- 119. Esc en el buscador
---------------------------------------------------------------------------
step("119: Esc en el buscador borra primero", function()
  local p = CreateFrame("Frame", nil, UIParent)
  local cambios = {}
  local b = K.Buscador(p, { retraso = 0, alCambiar = function(t) cambios[#cambios + 1] = t end })
  b:SetTexto("lobo")
  b:Foco()
  FIRE(b.Campo, "OnEscapePressed")
  check(b:Texto() == "", "Esc no borró lo escrito")
  check(cambios[#cambios] == "", "borrar con Esc no avisó del cambio")
  FIRE(b.Campo, "OnEscapePressed")
  check(b:Texto() == "", "el segundo Esc escribió algo")
  p:Hide()
end)

step("112: en Combate, «Anunciar» apagado dice por qué", function()
  local CB = NS_OF("Alfa_Combate")
  if not (CB and CB.Medidor and CB.Medidor.PuedeAnunciar) then print("AVISO: sin Combate") return end
  local puede, porque = CB.Medidor.PuedeAnunciar("actual", "dano", { ok = true, filas = {} })
  check(puede or (type(porque) == "string" and porque ~= ""), "PuedeAnunciar no da un porqué")
end)

print("prueba_140_pulido: " .. pasos .. " pasos")
