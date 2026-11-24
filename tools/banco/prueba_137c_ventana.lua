-- Prueba de la 1.3.7 (tercera ronda, «la ventana»): moverse por la ventana de Alfa.
--   1. atajos: Ctrl+número (sección), Ctrl+←/→ (página), Ctrl+F (buscador),
--      Alt+← (volver); en combate o apagados, la tecla sigue al juego; cada
--      botón de sección dice su atajo;
--   2. «‹» volver: aparece al cambiar de página, vuelve y se va; al abrir de
--      nuevo la ventana, el historial empieza limpio;
--   3. más alta: SetAlto con sus límites, lo recuerda, doble clic y «Devolverla»;
--      el lugar donde la sueltas;
--   4. el buscador: recientes e ideas al entrar a la caja vacía (cada idea
--      encuentra algo), se esconde al escribir, elegir un resultado lo recuerda;
--   5. sin resultados: las páginas de Alfa a un clic;
--   6. la campanita: filtros por tipo, «Sin ver», el lobo dormido sin avisos,
--      y un aviso con un nombre secreto no truena;
--   7. lo nuevo de la 1.3.7: «Ver» en cada punto que lleva a algún lado.
-- Con BANCO_FOTOS=1 dibuja las capturas (tools/banco/shot-137c-v-*.png).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["137c-v-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.3.7 ventana", msg) end end

BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N, B = AlfaNucleo, AlfaBienvenida
local M = NS_OF("Alfa_Bienvenida")
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
local A = Alfa
local O = A.UI.Options
local K = N.Kit
local Vt = M.Ventana

local ctrl, alt, combate = false, false, false
IsControlKeyDown = function() return ctrl end
IsAltKeyDown = function() return alt end
local combateOrig = InCombatLockdown
InCombatLockdown = function() return combate end
local function tecla(t, conCtrl, conAlt)
  ctrl, alt = conCtrl and true or false, conAlt and true or false
  local r = Vt.Tecla(t)
  ctrl, alt = false, false
  return r
end
local function seccion() return O.page and O.SectionOf(O.page.key) end

step("la ventana se abre y Ventana.lua la conecta", function()
  check(Vt ~= nil, "no hay M.Ventana")
  A.Fire("SHOW_OPTIONS", "inicio")
  RUN_TIMERS(3)
  check(O.frame and O.frame:IsShown(), "no se abrió la ventana")
  check(O.SinResultados ~= nil, "Options no tiene O.SinResultados")
  check(Vt.BotonVolver and Vt.Asa and Vt.Teclas and Vt.Panel, "faltan piezas (volver, asa, teclas, panel)")
  check(#Vt.Historial() == 0, "el historial no empieza vacío")
end)
SNAP("hoy", O.frame)

---------------------------------------------------------------------------
step("atajos de teclado", function()
  local secs = Vt.Secciones()
  check(#secs >= 3 and secs[1] == "hoy" and secs[#secs] == "ajustes", "las secciones no van de Hoy a Ajustes")
  check(tecla("2", true) == true and seccion() == secs[2], "Ctrl+2 no fue a la segunda sección")
  check(tecla("1", true) == true and seccion() == "hoy", "Ctrl+1 no volvió a Hoy")
  check(tecla(tostring(#secs), true) and seccion() == "ajustes", "Ctrl+último no fue a Ajustes")
  check(tecla("9", true) == false or #secs >= 9, "Ctrl+9 sin sección dijo que era suya")
  -- Ctrl+→ y Ctrl+←: la página siguiente y de vuelta.
  tecla("1", true)
  local antes = O.page.key
  check(tecla("RIGHT", true) and O.page.key ~= antes, "Ctrl+→ no cambió de página")
  check(tecla("LEFT", true) and O.page.key == antes, "Ctrl+← no regresó")
  -- Desde la última página, Ctrl+→ da la vuelta a Hoy.
  tecla(tostring(#secs), true)
  local ult = O.PagesOf("ajustes")
  O.Select(ult[#ult].key)
  tecla("RIGHT", true)
  check(O.page.key == O.PagesOf("hoy")[1].key, "Ctrl+→ desde la última página no dio la vuelta")
  -- Sin Ctrl, nada (la tecla es del juego).
  check(tecla("2") == false, "un 2 sin Ctrl fue de Alfa")
  check(tecla("LEFT") == false, "← sin modificador fue de Alfa")
  -- Ctrl+F: el buscador.
  check(tecla("F", true) and O.frame.Search:HasFocus(), "Ctrl+F no puso el cursor en el buscador")
  O.frame.Search:ClearFocus()
  -- El marco de teclas: la tecla de Alfa no sigue, la otra sí.
  local propagar
  local f = Vt.Teclas
  f.SetPropagateKeyboardInput = function(_, v) propagar = v end
  ctrl = true
  FIRE(f, "OnKeyDown", "2")
  ctrl = false
  check(propagar == false, "Ctrl+2 siguió al juego")
  FIRE(f, "OnKeyUp", "2")
  check(propagar == true, "al soltar, las teclas no volvieron al juego")
  FIRE(f, "OnKeyDown", "W")
  check(propagar == true, "W no siguió al juego")
  -- En combate, nada es de Alfa.
  combate = true
  propagar = nil
  ctrl = true
  FIRE(f, "OnKeyDown", "1")
  ctrl = false
  check(propagar == nil, "en combate se tocó la propagación")
  check(tecla("1", true) == false, "en combate Ctrl+1 fue de Alfa")
  combate = false
  FIRE(f, "OnEvent", "PLAYER_REGEN_DISABLED")
  check(propagar == true, "al empezar la pelea las teclas no quedaron sueltas")
  -- Apagado en Ajustes.
  A.Set("bienvenida.atajosVentana", false)
  check(tecla("2", true) == false, "con los atajos apagados Ctrl+2 hizo algo")
  A.Set("bienvenida.atajosVentana", nil)
  check(tecla("1", true) == true, "los atajos no volvieron")
  -- La pista en los botones de sección.
  O.RefreshNav()
  local visto = 0
  for _, b in ipairs(O.frame.sectionButtons) do
    if b:IsShown() and b.psKey == "hoy" then
      visto = visto + 1
      check(b.psTip ~= nil and b.psTipLines and b.psTipLines[1] == "Atajo: Ctrl+1", "Hoy no dice «Atajo: Ctrl+1»")
    end
    if b:IsShown() and b.psKey == O.CAMPANA then
      check(b.psTipLines == nil, "la campanita dice un atajo que no tiene")
    end
  end
  check(visto == 1, "no está el botón de Hoy")
end)

---------------------------------------------------------------------------
step("volver a la página de antes", function()
  O.frame:Hide()
  A.Fire("SHOW_OPTIONS", "inicio")
  RUN_TIMERS(2)
  check(#Vt.Historial() == 0, "al abrir otra vez el historial no empezó limpio")
  check(not Vt.BotonVolver:IsShown(), "«‹» salió sin historial")
  -- Lo que se corre el título (o la primera pastilla) desde el borde de su fila.
  local function xFila()
    local t = O.frame.Title
    if t:IsShown() then return select(4, t:GetPoint(1)) end
    for _, b in ipairs(O.frame.pillButtons) do if b:IsShown() then return select(4, b:GetPoint(1)) end end
  end
  local x0 = xFila()
  O.Select("rutas")
  check(Vt.BotonVolver:IsShown(), "«‹» no salió al cambiar de página")
  local x1 = xFila()
  check(x1 and x0 and x1 > x0, "el título no se recorrió para «‹»")
  local _, _, _, xc = O.frame.Content:GetPoint(1)
  check(xc == 0, "la página se movió con «‹»")
  local info = Vt.BotonVolver.alfaInfo
  check(info and type(info[1]) == "string" and info[1]:find("Hoy"), "«‹» no dice a dónde vuelve")
  O.Select("bienvenida")
  check(#Vt.Historial() == 2, "el historial no tiene las dos páginas")
  -- Alt+← vuelve una.
  check(tecla("LEFT", false, true) and O.page.key == "rutas", "Alt+← no volvió a Ruta")
  Vt.BotonVolver:Click()
  check(O.page.key == "inicio", "«‹» no volvió a Hoy")
  check(not Vt.BotonVolver:IsShown(), "«‹» sigue sin nada a dónde volver")
  check(xFila() == x0, "la fila del título no regresó a su lugar")
  -- Lo mismo dos veces no se apila.
  O.Select("inicio")
  check(#Vt.Historial() == 0, "elegir la misma página la apiló")
  O.Select("rutas")
end)
SNAP("volver", O.frame)
step("volver: limpio", function() Vt.Atras() end)

---------------------------------------------------------------------------
step("más alta, y recuerda alto y lugar", function()
  local win = O.frame
  local h0 = win:GetHeight()
  local v0 = win.psViewH
  check(Vt.SetAlto(h0 + 120, true), "SetAlto falló")
  check(math.abs(win:GetHeight() - (h0 + 120)) < 1, "no se hizo más alta")
  check(win.psViewH and v0 and win.psViewH > v0, "la página no ganó alto visible")
  check(N.Datos("bienvenida").ventana and N.Datos("bienvenida").ventana.h == h0 + 120, "no recordó el alto")
  Vt.SetAlto(50, true)
  check(win:GetHeight() >= 600, "se hizo más chica que el mínimo")
  Vt.SetAlto(h0 + 60, true)
  FIRE(Vt.Asa, "OnDoubleClick")
  check(math.abs(win:GetHeight() - h0) < 1, "el doble clic no la devolvió a su alto")
  check(N.Datos("bienvenida").ventana.h == nil, "el alto de siempre quedó guardado")
  -- Su lugar al soltarla.
  win:ClearAllPoints()
  win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 120, 700)
  FIRE(win.Header, "OnDragStop")
  local d = N.Datos("bienvenida").ventana
  check(d and d.x == 120 and d.y == 700, "no recordó dónde la dejaste")
  -- Sin recordar: no se guarda.
  A.Set("bienvenida.recordarVentana", false)
  N.Datos("bienvenida").ventana = nil
  FIRE(win.Header, "OnDragStop")
  check(N.Datos("bienvenida").ventana == nil, "guardó el lugar con «Recordar» apagado")
  A.Set("bienvenida.recordarVentana", nil)
  Vt.SetAlto(h0 + 140, true)
  Vt.Restablecer()
  check(N.Datos("bienvenida").ventana == nil and math.abs(win:GetHeight() - h0) < 1, "«Devolverla» no la devolvió")
  check(win:GetPoint(1) == "CENTER", "«Devolverla» no la centró")
  Vt.SetAlto(h0 + 140)
end)
SNAP("alta", O.frame)
step("alto de siempre", function() Vt.Restablecer() end)

---------------------------------------------------------------------------
step("el buscador: recientes e ideas", function()
  local s = O.frame.Search
  Vt.OlvidarRecientes()
  s:SetText("")
  s:SetFocus()
  check(Vt.Panel:IsShown(), "al entrar a la caja vacía no salieron las ideas")
  check(not Vt.Panel.TituloRec:IsShown(), "«Lo que buscaste» salió sin búsquedas")
  -- Cada idea encuentra algo.
  for _, b in ipairs(Vt.Panel.ideas) do
    if b:IsShown() then
      local q = b.alfaTexto
      local _, n = O.Search(q)
      O.SetQuery(q)
      check(n > 0 or #O.SearchPages() > 0, "la idea «" .. tostring(q) .. "» no encuentra nada")
    end
  end
  O.SetQuery("")
  s:SetText("")
  -- Escribir la esconde; borrar la devuelve.
  s:SetText("pes")
  check(not Vt.Panel:IsShown(), "las ideas siguen al escribir")
  s:SetText("")
  check(Vt.Panel:IsShown(), "al borrar no volvieron las ideas")
  -- Elegir una idea busca y la recuerda.
  local idea = Vt.Panel.ideas[1]
  idea:Click()
  check(s:GetText() == idea.alfaTexto, "la idea no se escribió en la caja")
  check(Vt.Recientes()[1] == idea.alfaTexto, "la idea no quedó en tus búsquedas")
  -- Elegir un resultado recuerda lo buscado.
  s:SetText("pesca")
  O.SetQuery("pesca")
  RUN_TIMERS(2)
  O.Select("bienvenida")
  check(Vt.Recientes()[1] == "pesca", "elegir un resultado no recordó «pesca»")
  check(s:GetText() == "", "la caja no quedó limpia")
  for i = 1, 8 do Vt.Recordar("busca" .. i) end
  check(#Vt.Recientes() == 5, "guarda más de 5 búsquedas")
  Vt.Recordar("Busca8")
  check(#Vt.Recientes() == 5 and Vt.Recientes()[1] == "Busca8", "una búsqueda repetida se duplicó")
  check(not Vt.Recordar("a"), "recordó una sola letra")
  s:ClearFocus()
  s:SetFocus()
  check(Vt.Panel.TituloRec:IsShown() and Vt.Panel.filas[1]:IsShown(), "no salen tus búsquedas recientes")
end)
SNAP("buscar-foco", O.frame, { Vt.Panel })
step("buscar: una reciente", function()
  local f = Vt.Panel.filas[2]
  local t = f.alfaTexto
  f:Click()
  check(O.frame.Search:GetText() == t, "la búsqueda reciente no se escribió")
  check(not Vt.Panel:IsShown(), "las ideas siguen después de elegir")
  Vt.Panel.Borrar:Click()
  check(#Vt.Recientes() == 0, "«Borrar» no olvidó tus búsquedas")
  O.frame.Search:ClearFocus()
  RUN_TIMERS(2)
  O.SetQuery("") O.frame.Search:SetText("")
end)

---------------------------------------------------------------------------
step("sin resultados: las páginas a un clic", function()
  O.frame.Search:SetText("zzqx")
  O.SetQuery("zzqx")
  RUN_TIMERS(3)
  local s = Vt.SinRes
  check(s and s:IsShown(), "sin resultados no salen las páginas")
  local n = 0
  for _, b in ipairs(s and s.botones or {}) do if b:IsShown() then n = n + 1 end end
  check(n >= 3, "salen menos de 3 páginas")
end)
SNAP("buscar-nada", O.frame)
step("sin resultados: abrir una página", function()
  local s = Vt.SinRes
  local b = s.botones[2]
  b:Click()
  check(O.page.key == b.alfaPagina, "el botón no abrió su página")
  check(O.frame.Search:GetText() == "", "la búsqueda no se limpió")
  check(not s:IsVisible(), "las páginas siguen a la vista fuera de la búsqueda")
  O.frame.Search:SetText("pesca")
  O.SetQuery("pesca")
  check(not s:IsShown(), "con resultados salen las páginas de «sin resultados»")
  O.SetQuery("") O.frame.Search:SetText("")
  O.frame:Hide()
end)

---------------------------------------------------------------------------
step("la campanita: vacía, con filtros y secretos", function()
  N.OlvidarAvisos()
  N.VerAvisos()
  RUN_TIMERS(2)
  local v = rawget(_G, "AlfaPerdidos")
  check(v and v:IsShown(), "no se abrió Avisos")
end)
SNAP("avisos-vacio", rawget(_G, "AlfaPerdidos"))
step("la campanita: filtros", function()
  local v = rawget(_G, "AlfaPerdidos")
  v:Hide()
  K.Aviso({ titulo = "Bolsas casi llenas", texto = "Te quedan 3 lugares.", icono = "ic-bolsas" })
  K.Aviso({ titulo = "Vende lo gris", texto = "Tienes 12 objetos grises.", icono = "ic-bolsas" })
  K.Aviso({ titulo = "Misión lista", texto = "«Lobos de la sierra» ya se puede entregar.", icono = "ic-misiones" })
  N.Perdido({ titulo = "Un raro cerca", texto = "Lya olió a Gruñón al norte.", icono = "ic-raros" })
  -- Un nombre que el juego da en secreto (en mazmorra) no truena la lista.
  pcall(N.AvisoReciente, { titulo = SECRETO("Nimzy"), texto = "te saluda", icono = "ic-manada" })
  RUN_TIMERS(2)
  N.FiltroAvisos("todos")
  N.VerAvisos()
  RUN_TIMERS(2)
  local O2 = v
  local seg
  local function buscar(f, prof)
    if prof > 6 or seg then return end
    for _, c in ipairs({ f:GetChildren() }) do
      if c.SetOpciones and c.opciones then seg = c return end
      buscar(c, prof + 1)
    end
  end
  buscar(O2, 0)
  check(seg and seg:IsShown(), "no salen los filtros")
  local valores = {}
  for _, o in ipairs(seg and seg.opciones or {}) do valores[o.valor] = o.cuenta end
  check(valores.todos and valores.todos >= 4, "«Todos» no cuenta los avisos")
  check(valores.sinver == 1, "«Sin ver» no cuenta 1")
  check(valores.bolsas == 2, "no hay filtro de Bolsas con 2")
  -- Elegir «Bolsas» deja solo esas.
  for _, b in ipairs(seg.botones) do if b:IsShown() and b.alfaValorOpcion == "bolsas" then b:Click() end end
  check(N.FiltroAvisos() == "bolsas", "el filtro no cambió a Bolsas")
  local n = 0
  local function contar(f, prof)
    if prof > 8 then return end
    for _, c in ipairs({ f:GetChildren() }) do
      if c.alfaDatos and c:IsShown() and c.alfaDatos.titulo then n = n + 1 end
      contar(c, prof + 1)
    end
  end
  contar(O2, 0)
  check(n == 2, "con el filtro de Bolsas se ven " .. n .. " avisos, no 2")
end)
SNAP("avisos", rawget(_G, "AlfaPerdidos"))
step("la campanita: sin ver y lo que se acaba", function()
  N.FiltroAvisos("sinver")
  N.VerAvisos()
  N.MarcarAvisosVistos()
  RUN_TIMERS(2)
  check(N.FiltroAvisos() == "todos", "«Sin ver» vacío no volvió a «Todos»")
  local v = rawget(_G, "AlfaPerdidos")
  if v then v:Hide() end
end)

---------------------------------------------------------------------------
step("lo nuevo de la 1.3.7 con «Ver»", function()
  -- 1.3.8: ya no es la primera; se busca por su versión
  local nota
  for _, x in ipairs(M.NOTAS) do if x.version == "1.3.7" then nota = x end end
  check(nota ~= nil, "no está la nota de la 1.3.7")
  nota = nota or M.NOTAS[1]
  check(M.AbrirNotas(nota), "no abrió las notas")
  RUN_TIMERS(2)
  local nv = rawget(_G, "AlfaNotasVersion")
  check(nv and nv:IsShown(), "no se ven las notas")
  for _, p in ipairs(nota.puntos) do
    check(not p[2]:find("Lo que me perdí", 1, true), "las notas aún dicen «Lo que me perdí»")
  end
  for _, x in ipairs(M.NOTAS) do
    for _, p in ipairs(x.puntos) do
      if p[3] then check(M.IR_NOTA[p[3]] ~= nil, x.version .. ": el punto lleva a «" .. p[3] .. "», que no existe") end
    end
  end
end)
SNAP("notas", rawget(_G, "AlfaNotasVersion"))
step("lo nuevo: «Ver» lleva a la campanita", function()
  local nv = rawget(_G, "AlfaNotasVersion")
  local boton
  local function buscar(f, prof)
    if prof > 8 or boton then return end
    for _, c in ipairs({ f:GetChildren() }) do
      if c.alfaIr == M.IR_NOTA.avisos and c:IsShown() then boton = c return end
      buscar(c, prof + 1)
    end
  end
  buscar(nv, 0)
  check(boton ~= nil, "el punto de los avisos no tiene «Ver»")
  if boton then boton:Click() end
  check(not nv:IsShown(), "las notas no se cerraron al ir")
  local v = rawget(_G, "AlfaPerdidos")
  check(v and v:IsShown(), "«Ver» no abrió la campanita")
  if v then v:Hide() end
end)

InCombatLockdown = combateOrig
print(string.format("prueba_137c_ventana: %d errores", #ERRORS))
