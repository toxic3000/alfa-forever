-- Prueba de la 1.3.7 (quinta tanda), «Planes» y el tope de guías:
--   1. guardar y restaurar 12 guías tras un /reload simulado (CharState.tabs);
--   2. la sección Planes existe entre Hoy y Aventura (barra, Ctrl+2, el menú
--      de Alfa, el buscador, Alfa sencillo), con su número «12/12» y las 12;
--   3. Seguir cambia la activa; Quitar y Deshacer; Fijar;
--   4. abrir la 13.ª quita sola la más vieja que no sigues ni está fijada
--      (a igual, la de menos experiencia), con su aviso, Deshacer y «Ver Planes»;
--   5. con las 12 fijadas, el cuadro «¿cuál quitas?»: al elegir, la nueva arranca;
--   6. «Guíame» de la Enciclopedia (caña de pescar de hierro grande y otros):
--      con espacio y lleno arranca y cierra la Enciclopedia; con todas fijadas,
--      el cuadro de elegir; el ajuste «cerrar al guiar» apagado la deja abierta;
--   7. la barra de pestañas de la ventana de guía con 12 no se desborda («+N»);
--   8. abandonar una misión pide confirmación (Planes y el rastreador).
-- Con BANCO_FOTOS=1 dibuja tools/banco/shot-137e-*.png.
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["137e-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.3.7e planes", msg) end end
local function correr(n) for _ = 1, n or 1 do RUN_TIMERS(1) end end

local A, N = Alfa, AlfaNucleo
local K = N.Kit
local ns = NS_OF("Alfa")
local Ru = NS_OF("Alfa_Rutas")
local En = NS_OF("Alfa_Enciclopedia")
local E, G = A.Engine, A.Guides
local EC = Ru.EnCurso

---------------------------------------------------------------------------
-- 1. Las 12 guardadas de la sesión anterior vuelven al entrar
---------------------------------------------------------------------------
local ids = {}
for _, h in ipairs(G.List() or {}) do
  if #ids >= 16 then break end
  local g = G.Get(h.id)
  if g and (g.category == nil or g.category == "" or g.category == "Leveling") then ids[#ids + 1] = h.id end
end
check(#ids >= 14, "el banco no tiene 14 guías de subir de nivel: " .. #ids)
do
  local s = ns.CharState()
  s.tabs = {}
  for i = 1, 12 do s.tabs[i] = ids[i] end
  s.activeTab = 5
end

FIRE_EVENT("PLAYER_LOGIN")
local Bv = rawget(_G, "AlfaBienvenida")
N.Datos("bienvenida").respondio = Bv and Bv.VERSION or 99
N.Datos("bienvenida").versionVista = Bv and Bv.VersionAlfa and Bv.VersionAlfa() or "9.9.9"
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
correr(10)

local function abiertas()
  local t = {}
  for i, x in ipairs(E.GetTabs() or {}) do t[i] = x.guideId end
  return t
end
local function abierta(id) for _, x in ipairs(abiertas()) do if x == id then return true end end return false end

step("Guardar y restaurar 12 guías tras un /reload", function()
  check(E.MAX_TABS == 12, "el tope del motor no es 12: " .. tostring(E.MAX_TABS))
  local ab = abiertas()
  check(#ab == 12, "no se restauraron las 12 pestañas: " .. #ab)
  for i = 1, 12 do check(ab[i] == ids[i], "la pestaña " .. i .. " no volvió en su lugar") end
  check(E.GetGuide() and E.GetGuide().id == ids[5], "la activa no volvió (la 5.ª)")
  local s = ns.CharState()
  check(type(s.tabs) == "table" and #s.tabs == 12, "no se guardan las 12: " .. tostring(s.tabs and #s.tabs))
  check(s.activeTab == 5, "no se guarda cuál sigues: " .. tostring(s.activeTab))
  -- Reabrir una cerrada con 11 abiertas (el tope viejo era 6).
  local cerrada = ids[9]
  E.CloseTab(9)
  check(#abiertas() == 11, "no se cerró")
  check(E.ReopenClosedTab(cerrada) ~= nil and abiertas()[9] == cerrada, "no se reabrió en su lugar con 11")
  E.SelectTab(5)
end)

---------------------------------------------------------------------------
-- 2. La sección Planes
---------------------------------------------------------------------------
local O = ns.UI.Options
local function botonSeccion(key)
  for _, b in ipairs(O.frame and O.frame.sectionButtons or {}) do
    if b:IsShown() and b.psKey == key then return b end
  end
end
local function tarjetasVisibles()
  local n = 0
  for _, f in ipairs(O.Views("planes")) do
    local function cuenta(fr)
      for _, c in ipairs({ fr:GetChildren() }) do
        if c.alfaDatos and c.alfaDatos.alfaIt and c:IsShown() then n = n + 1 end
        cuenta(c)
      end
    end
    cuenta(f)
  end
  return n
end

step("La sección Planes está entre Hoy y Aventura, con su número y las 12", function()
  local S = O.SECCIONES
  check(S[1].key == "hoy" and S[2].key == "planes" and S[3].key == "aventura", "Planes no va entre Hoy y Aventura")
  ns.UI.ShowOptions("planes")
  correr(2)
  check(O.page and O.page.key == "planes", "no abrió la página Planes")
  check(O.SectionOf("planes") == "planes", "la página no vive en su sección")
  local b = botonSeccion("planes")
  check(b ~= nil, "no hay botón Planes en la barra")
  -- En orden: Hoy, Planes, Aventura (de izquierda a derecha).
  local bh, ba = botonSeccion("hoy"), botonSeccion("aventura")
  if b and bh and ba then
    -- (1.4.0, 82: con la barra lateral, de arriba abajo.)
    if O.frame and O.frame.psLateral then
      check(bh:GetTop() > b:GetTop() and b:GetTop() > ba:GetTop(), "la barra no los pone en orden")
    else
      check(bh:GetLeft() < b:GetLeft() and b:GetLeft() < ba:GetLeft(), "la barra no los pone en orden")
    end
  end
  check(b and b.psPlanes and b.psPlanes:IsShown() and b.psPlanes.Texto:GetText() == "12/12", "la sección no dice «12/12»")
  check(tarjetasVisibles() == 12, "la página no enseña las 12 guías: " .. tarjetasVisibles())
  -- Ctrl+2 es Planes; el menú de Alfa la trae; Sencillo también.
  local Vt = NS_OF("Alfa_Bienvenida").Ventana
  check(Vt and Vt.Secciones()[2] == "planes", "Ctrl+2 no es Planes")
  local hay
  for _, it in ipairs(O.MenuItems(UIParent)) do if it.seccion == "planes" then hay = it end end
  check(hay ~= nil, "el menú de Alfa no trae Planes")
  A.Set("bienvenida.modo", "sencillo")
  check(N.PaginaVisible("planes"), "Planes no sale en Alfa sencillo")
  A.Set("bienvenida.modo", nil)
  -- El buscador la encuentra.
  O.SetQuery("Planes")
  local enc
  for _, p in ipairs(O.SearchPages()) do if p.key == "planes" then enc = true end end
  check(enc, "el buscador no encuentra Planes")
  O.SetQuery("")
  -- AlfaRuta.EnCurso() abre esta página (no una ventana aparte).
  ns.UI.ShowOptions("inicio")
  AlfaRuta.EnCurso()
  correr(2)
  check(O.page and O.page.key == "planes", "AlfaRuta.EnCurso() no abre Planes")
  SNAP("planes", O.frame)
end)

---------------------------------------------------------------------------
-- 3. Seguir, Quitar y Deshacer, Fijar
---------------------------------------------------------------------------
step("Seguir cambia la activa; Quitar y Deshacer; Fijar", function()
  local it
  for _, x in ipairs(EC.Lista()) do if x.tipo == "guia" and x.id == ids[8] then it = x end end
  check(it and not it.activa, "no encontré la 8.ª")
  check(EC.Seguir(it) and E.GetGuide().id == ids[8], "Seguir no la puso como activa")
  E.SelectTab(5)
  local antes = abiertas()
  for _, x in ipairs(EC.Lista()) do if x.id == ids[3] then it = x end end
  check(EC.Quitar(it) and not abierta(ids[3]), "Quitar no la quitó")
  check(EC.PuedeDeshacer() and EC.Deshacer(), "no se pudo deshacer")
  local d = abiertas()
  for i = 1, 12 do check(d[i] == antes[i], "Deshacer no la devolvió a su lugar (" .. i .. ")") end
  check(E.GetGuide().id == ids[5], "después de deshacer no sigues con la de antes")
  check(EC.Fijar(ids[2], true) and EC.Fijada(ids[2]), "no se fijó")
end)

---------------------------------------------------------------------------
-- 4. La 13.ª quita sola la más vieja
---------------------------------------------------------------------------
local dichos = {}
local avisoOrig = K.Aviso
K.Aviso = function(o) dichos[#dichos + 1] = o return avisoOrig(o) end
local function ultimoDicho() return dichos[#dichos] end
local function tocarTodas(base)
  local d = Ru.Personaje()
  d.tocadas = d.tocadas or {}
  for i = 1, 12 do d.tocadas[ids[i]] = base + i * 100 end
end

step("Abrir la 13.ª quita sola la más vieja que no sigues ni fijaste; Deshacer la devuelve", function()
  -- La 1.ª es la que sigues (la más vieja), la 2.ª está fijada: se va la 3.ª.
  E.SelectTab(1)
  tocarTodas(1000)
  Ru.Personaje().tocadas[ids[1]] = 1
  dichos = {}
  check(EC.Candidata() and EC.Candidata().id == ids[3], "la candidata no es la 3.ª: " .. tostring(EC.Candidata() and EC.Candidata().id))
  local i = E.OpenTab(ids[13], true)
  check(i ~= nil, "la 13.ª no se abrió")
  check(#abiertas() == 12, "no quedaron 12: " .. #abiertas())
  check(not abierta(ids[3]), "no quitó la más vieja (la 3.ª)")
  check(abierta(ids[1]) and abierta(ids[2]), "quitó la que sigues o la fijada")
  check(E.GetGuide().id == ids[13], "la nueva no es la activa")
  local o = ultimoDicho()
  local textos = {}
  for _, a in ipairs(o and o.acciones or {}) do textos[a.texto] = a end
  check(o and type(o.titulo) == "string" and o.titulo:find("para hacer lugar", 1, true), "no avisó «Quité … para hacer lugar»: " .. tostring(o and o.titulo))
  check(textos["Deshacer"] and textos["Ver Planes"], "el aviso no trae Deshacer y Ver Planes")
  -- El aviso de «pestaña cerrada» del motor no sale encima (su Reabrir no cabría).
  local GF = ns.UI.GuideFrame
  check(not (GF.notices and GF.notices.closedTab), "salió el aviso de pestaña cerrada del motor")
  if textos["Deshacer"] then textos["Deshacer"].alClic() end
  check(abierta(ids[3]) and not abierta(ids[13]), "Deshacer no devolvió la 3.ª")
  check(abiertas()[3] == ids[3], "la 3.ª no volvió a su lugar")
  check(E.GetGuide().id == ids[1], "Deshacer no volvió a la que seguías")
  if textos["Ver Planes"] then
    textos["Ver Planes"].alClic()
    correr(2)
    check(O.frame:IsShown() and O.page.key == "planes", "«Ver Planes» no abrió Planes")
  end
end)

step("A igual antigüedad, se va la que da menos experiencia", function()
  tocarTodas(5000)
  for i = 1, 12 do Ru.Personaje().tocadas[ids[i]] = 5000 end
  -- Una guía de un objeto (casi no da experiencia) entre las abiertas.
  local gid = A.Lookup.Guide("item", 6256)
  check(type(gid) == "string" and abierta(gid), "no se abrió la guía de la caña")
  check(#abiertas() == 12, "al abrir la de la caña no se hizo lugar")
  Ru.Personaje().tocadas[gid] = 5000
  E.SelectTab(1)
  local c = EC.Candidata()
  check(c and c.id == gid, "la candidata no es la que da menos experiencia: " .. tostring(c and c.id))
  -- Volver a las 12 de siempre.
  EC.Quitar({ tipo = "guia", id = gid, nombre = "caña" })
  for i = 1, 12 do if not abierta(ids[i]) then E.OpenTab(ids[i], false) end end
  E.SelectTab(1)
end)

---------------------------------------------------------------------------
-- 5. Las 12 fijadas: «¿cuál quitas?»
---------------------------------------------------------------------------
local function filasElegir()
  local v = rawget(_G, "AlfaRutasElegir")
  local out = {}
  local function buscar(f)
    for _, c in ipairs({ f:GetChildren() }) do
      if c.Boton and c.Titulo and c:IsShown() then out[#out + 1] = c end
      buscar(c)
    end
  end
  if v then buscar(v) end
  return out, v
end

step("Con las 12 fijadas, el cuadro de elegir: al elegir, la nueva arranca", function()
  check(#abiertas() == 12, "no hay 12 abiertas: " .. #abiertas())
  for i = 1, 12 do EC.Fijar(abiertas()[i], true) end
  check(EC.Candidata() == nil, "con todas fijadas aún hay candidata")
  check(not (AlfaRuta.PuedeAbrir()), "dice que cabe otra")
  check(E.OpenTab(ids[14], true) == nil, "el motor abrió una 13.ª con todas fijadas")
  AlfaRuta.AvisoLleno()
  correr(1)
  local filas, v = filasElegir()
  check(v and v:IsShown(), "no salió el cuadro de elegir")
  check(#filas == 12, "el cuadro no lista las 12: " .. #filas)
  SNAP("elegir", v)
  local cual = abiertas()[4]
  if filas[4] then FIRE(filas[4].Boton, "OnClick", "LeftButton") end
  correr(1)
  check(not abierta(cual), "no quitó la elegida")
  check(abierta(ids[14]) and E.GetGuide().id == ids[14], "la nueva no arrancó")
  check(not (v and v:IsShown()), "el cuadro no se cerró")
  check(not EC.Fijada(cual), "la quitada sigue fijada")
  for _, id in ipairs(abiertas()) do EC.Fijar(id, false) end
end)

---------------------------------------------------------------------------
-- 6. «Guíame» de la Enciclopedia
---------------------------------------------------------------------------
local F = En.F
local function ventanaEnc() return rawget(_G, "AlfaEnciclopediaVentana") end
local function botonGuiame()
  local v = ventanaEnc()
  local hallado
  local function buscar(f)
    for _, c in ipairs({ f:GetChildren() }) do
      if not hallado and c.Texto and c.alClic and c:IsVisible() and c.Texto.GetText and c.Texto:GetText() == "Guíame" then hallado = c end
      buscar(c)
    end
  end
  if v then buscar(v) end
  return hallado
end
local function guiarDesdeEnciclopedia(item)
  AlfaEnciclopedia.Abrir("item", item)
  correr(2)
  local b = botonGuiame()
  check(b ~= nil, "la ficha del objeto " .. item .. " no tiene «Guíame»")
  if b then FIRE(b, "OnClick", "LeftButton") end
  correr(2)
end

step("«Guíame» con espacio: la caña y otros objetos arrancan y cierran la Enciclopedia", function()
  -- Con lugar: se quitan cuatro.
  for k = 1, 4 do local t = abiertas() E.CloseTab(#t, true) end
  check(#abiertas() == 8, "no quedaron 8")
  -- Caña de pescar de hierro grande (se pesca), la fuerte (se compra), la de siempre y la de Blump (misión).
  for _, item in ipairs({ 6367, 6365, 6256, 12225 }) do
    ns.UI.ShowOptions("enciclopedia")
    guiarDesdeEnciclopedia(item)
    local g = E.GetGuide()
    check(g and g.id == "lookup/item/" .. item, "«Guíame» no arrancó la guía de " .. item .. ": " .. tostring(g and g.id))
    check(not (ventanaEnc() and ventanaEnc():IsShown()), "la Enciclopedia no se cerró al guiar (" .. item .. ")")
    check(not O.frame:IsShown(), "la ventana de Alfa no se cerró al guiar (" .. item .. ")")
    check(A.Get("ui.shown"), "la ventana de guía no quedó a la vista")
  end
end)

local function sinLookups()
  for i = #abiertas(), 1, -1 do if abiertas()[i]:find("^lookup/") then E.CloseTab(i, true) end end
end

step("«Guíame» con las 12: quita la más vieja, arranca y cierra la Enciclopedia", function()
  sinLookups()
  for _, id in ipairs(ids) do if #abiertas() < 12 and not abierta(id) then E.OpenTab(id, false) end end
  check(#abiertas() == 12, "no hay 12 abiertas")
  dichos = {}
  guiarDesdeEnciclopedia(6367)
  local g = E.GetGuide()
  check(g and g.id == "lookup/item/6367", "lleno, «Guíame» no arrancó: " .. tostring(g and g.id))
  check(#abiertas() == 12, "no siguen 12")
  check(not (ventanaEnc() and ventanaEnc():IsShown()), "lleno, la Enciclopedia no se cerró")
  local hizo
  for _, o in ipairs(dichos) do if type(o.titulo) == "string" and o.titulo:find("para hacer lugar", 1, true) then hizo = true end end
  check(hizo, "no avisó qué quitó")
end)

step("«Guíame» con las 12 fijadas: el cuadro de elegir, y al elegir arranca y cierra", function()
  sinLookups()
  for _, id in ipairs(ids) do if #abiertas() < 12 and not abierta(id) then E.OpenTab(id, false) EC.Fijar(id, true) end end
  check(#abiertas() == 12, "no hay 12")
  for _, id in ipairs(abiertas()) do EC.Fijar(id, true) end
  guiarDesdeEnciclopedia(6365)
  local filas, v = filasElegir()
  check(v and v:IsShown() and #filas == 12, "no salió el cuadro de elegir desde la Enciclopedia")
  if filas[2] then FIRE(filas[2].Boton, "OnClick", "LeftButton") end
  correr(2)
  local g = E.GetGuide()
  check(g and g.id == "lookup/item/6365", "al elegir, la nueva no arrancó: " .. tostring(g and g.id))
  check(not (ventanaEnc() and ventanaEnc():IsShown()), "al elegir, la Enciclopedia no se cerró")
  for _, id in ipairs(abiertas()) do EC.Fijar(id, false) end
end)

step("Con «Cerrar la Enciclopedia al darle Guíame» apagado, se queda abierta", function()
  check(A.Get("enciclopedia.cerrarAlGuiar") == true, "el ajuste no viene prendido de fábrica")
  A.Set("enciclopedia.cerrarAlGuiar", false)
  guiarDesdeEnciclopedia(6256)
  check(E.GetGuide().id == "lookup/item/6256", "no arrancó")
  check(ventanaEnc() and ventanaEnc():IsShown(), "se cerró aunque el ajuste está apagado")
  A.Set("enciclopedia.cerrarAlGuiar", nil)
  if ventanaEnc() then ventanaEnc():Hide() end
end)

---------------------------------------------------------------------------
-- 7. La barra de pestañas con 12
---------------------------------------------------------------------------
step("La barra de pestañas de la ventana de guía con 12 no se desborda", function()
  for _, id in ipairs(ids) do if #abiertas() < 12 and not abierta(id) then E.OpenTab(id, false) end end
  check(#abiertas() == 12, "no hay 12")
  A.Set("ui.shown", true)
  A.Fire("TABS_CHANGED")
  correr(2)
  local GF = ns.UI.GuideFrame
  GF.RenderTabs()
  local Fr = rawget(_G, "AlfaGuideFrame")
  local strip = Fr and Fr.psStrip
  check(strip ~= nil, "no hay barra de pestañas")
  if not strip then return end
  local der = strip:GetRight()
  for _, c in ipairs({ strip:GetChildren() }) do
    if c:IsShown() and c.GetRight and c:GetRight() and der then
      check(c:GetRight() <= der + 0.5, "algo se sale de la barra de pestañas")
      if c.psIndex then check(c:GetWidth() >= 29.5, "una pestaña quedó más angosta que su ícono: " .. c:GetWidth()) end
    end
  end
  check(strip.More and strip.More:IsShown(), "con 12 no sale «+N»")
  check(strip.Add:IsShown() and not strip.Add.psFull, "el + quedó lleno aunque se puede hacer lugar")
  if not Fr:IsShown() then Fr:Show() end
  SNAP("pestanas", Fr)
end)

---------------------------------------------------------------------------
-- 8. Abandonar una misión
---------------------------------------------------------------------------
step("Abandonar una misión pide confirmación (Planes y el rastreador)", function()
  local QL = C_QuestLog
  local log, abandonada = { 4321 }, nil
  local orig = {}
  for k, v in pairs(QL) do orig[k] = v end
  QL.GetNumQuestLogEntries = function() return #log, #log end
  QL.GetInfo = function(i) return log[i] and { questID = log[i], title = "La caza del lobo" } or nil end
  QL.IsOnQuest = function(q) for _, x in ipairs(log) do if x == q then return true end end return false end
  QL.GetTitleForQuestID = function(q) return q == 4321 and "La caza del lobo" or nil end
  QL.CanAbandonQuest = function() return true end
  local sel
  QL.SetSelectedQuest = function(q) sel = q end
  QL.SetAbandonQuest = function() end
  QL.AbandonQuest = function() abandonada = sel log = {} end
  -- El menú de una meta del rastreador.
  local opciones
  local menuOrig = K.Menu
  K.Menu = function(_, op) opciones = op end
  Ru.Rastreador.MenuMeta({ alfaMeta = { t = "turnin", quest = 4321, index = 1, status = "active", text = "Entrega" }, alfaPaso = 1 })
  K.Menu = menuOrig
  local ab
  for _, o in ipairs(opciones or {}) do if o.texto == "Abandonar misión" then ab = o end end
  check(ab ~= nil, "el menú de la meta no trae «Abandonar misión»")
  if ab then ab.valor() end
  check(K.DialogoAbierto(), "abandonar no pidió confirmación")
  check(abandonada == nil, "abandonó sin confirmar")
  K.CerrarDialogo()
  -- Desde Planes: su menú de misiones.
  ns.UI.ShowOptions("planes")
  correr(2)
  local qs
  K.Menu = function(_, op, _, alElegir) qs = { op = op, fn = alElegir } end
  local b
  local function buscar(f)
    for _, c in ipairs({ f:GetChildren() }) do
      if not b and c.Texto and c.alClic and c:IsVisible() and c.Texto:GetText() == "Abandonar una misión…" then b = c end
      buscar(c)
    end
  end
  for _, v in ipairs(O.Views("planes")) do buscar(v) end
  check(b ~= nil, "Planes no tiene «Abandonar una misión…»")
  if b then FIRE(b, "OnClick", "LeftButton") end
  K.Menu = menuOrig
  check(qs and #qs.op == 1 and qs.op[1].valor == 4321, "el menú no lista tu misión")
  if qs then qs.fn(4321) end
  check(K.DialogoAbierto(), "desde Planes no pidió confirmación")
  -- Aceptar: la abandona.
  local d = K.Dialogo
  local Kd = rawget(_G, "AlfaKitDialogo")
  local aceptar
  local function buscarAceptar(f)
    for _, c in ipairs({ f:GetChildren() }) do
      if not aceptar and c.Texto and c.alClic and c:IsVisible() and c.Texto:GetText() == "Abandonar" then aceptar = c end
      buscarAceptar(c)
    end
  end
  buscarAceptar(UIParent)
  if K.Raiz then buscarAceptar(K.Raiz()) end
  check(aceptar ~= nil, "no encontré el botón «Abandonar» del diálogo")
  if aceptar then FIRE(aceptar, "OnClick", "LeftButton") end
  check(abandonada == 4321, "al aceptar no la abandonó")
  for k in pairs(QL) do QL[k] = orig[k] end
  K.CerrarDialogo()
end)

K.Aviso = avisoOrig
print(("planes 1.3.7e: %d pasos"):format(pasos))
