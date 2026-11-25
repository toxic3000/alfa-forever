-- Prueba de la 1.3.7 (arreglos): la campanita de avisos y «Lo que sigues».
--   * la campanita está en la barra de secciones, junto a Ajustes, con su número;
--   * cuenta lo mismo que el globito del minimapa (una sola cuenta);
--   * el globito dice qué es y su clic abre la lista; la campanita también;
--   * la lista trae lo perdido y lo reciente, cada uno con su botón;
--   * «Marcar todo como visto» baja la campanita y el minimapa; «Borrar» vacía;
--   * «Lo que sigues» (1.3.7e: la sección Planes) lista 12 guías y tu plan, quita una y la devuelve con
--     Deshacer (en su lugar), quita todas menos la actual y las devuelve;
--   * el aviso de «ya no cabe otra guía» trae «Ver lo que sigues» (Biblioteca,
--     el selector de guías del motor y el aviso de Rutas).
SNAPSHOTS = {}
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
local function check(cond, msg) if not cond then NOTE("1.3.7 notificaciones", msg) end end

local A, N, K = Alfa, AlfaNucleo, AlfaNucleo.Kit
local ns = NS_OF("Alfa")
local Ru = NS_OF("Alfa_Rutas")

FIRE_EVENT("PLAYER_LOGIN")
-- Como alguien que ya terminó la bienvenida (si no, abrir una página abre la bienvenida).
do
  local Bv = rawget(_G, "AlfaBienvenida")
  N.Datos("bienvenida").respondio = Bv and Bv.VERSION or 99
  N.Datos("bienvenida").versionVista = Bv and Bv.VersionAlfa and Bv.VersionAlfa() or "9.9.9"
end
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(8)
local function correr(n) for _ = 1, n do RUN_TIMERS(1) end end

-- Todo aviso que pasa por el Kit (salga en pantalla, lo diga Lya o espere).
local dichos = {}
local avisoOrig = K.Aviso
K.Aviso = function(o) dichos[#dichos + 1] = o return avisoOrig(o) end
local function ultimoDicho(titulo)
  for i = #dichos, 1, -1 do
    local o = dichos[i]
    if type(o) == "table" and (not titulo or o.titulo == titulo) then return o end
  end
end

local function texto(fs) return fs and fs.GetText and (fs:GetText() or "") or "" end
local function campana()
  local O = ns.UI.Options
  local win = O.frame
  for _, b in ipairs(win and win.sectionButtons or {}) do
    if b:IsShown() and b.psKey == O.CAMPANA then return b end
  end
end
local function boton(key)
  local win = ns.UI.Options.frame
  for _, b in ipairs(win and win.sectionButtons or {}) do
    if b:IsShown() and b.psKey == key then return b end
  end
end
local function tarjetasVisibles(v)
  local n = 0
  local function recorrer(f, prof)
    if prof > 8 or not f.GetChildren then return end
    for _, c in ipairs({ f:GetChildren() }) do
      if c.alfaDatos and c:IsShown() then n = n + 1 end
      recorrer(c, prof + 1)
    end
  end
  recorrer(v, 0)
  return n
end

---------------------------------------------------------------------------
step("La campanita está en la barra, junto a Ajustes, y cuenta lo que no viste", function()
  N.OlvidarAvisos()
  ns.UI.ShowOptions()
  local b = campana()
  check(b ~= nil, "no hay campanita en la barra de secciones")
  if not b then return end
  local aj = boton("ajustes")
  check(aj ~= nil, "no está el botón de Ajustes")
  local p1, _, _, xb = b:GetPoint(1)
  local p2, _, _, xa = aj:GetPoint(1)
  -- (1.4.0, 82: con la barra lateral, abajo de la barra, justo encima de Ajustes.)
  if ns.UI.Options.frame.psLateral then
    check(p1 == "BOTTOMLEFT" and p2 == "BOTTOMLEFT" and b:GetBottom() > aj:GetBottom(), "la campanita no queda abajo, junto a Ajustes")
  else
    check(p1 == "RIGHT" and p2 == "RIGHT" and xb < xa, "la campanita no queda a la derecha, junto a Ajustes")
  end
  check(not (b.psCuenta and b.psCuenta:IsShown()), "sin avisos la campanita enseña un número")
  N.Perdido({ titulo = "Aviso uno", texto = "Algo pasó", icono = "ic-misiones" })
  N.Perdido({ titulo = "Aviso dos", texto = "Otra cosa" })
  N.Perdido({ titulo = "Aviso tres", texto = "Y otra" })
  check(N.AvisosSinVer() == 3, "la cuenta no es 3: " .. N.AvisosSinVer())
  b = campana()
  check(b.psCuenta and b.psCuenta:IsShown() and texto(b.psCuenta.Texto) == "3", "la campanita no dice 3: " .. texto(b and b.psCuenta and b.psCuenta.Texto))
  check(type(b.psTip) == "string" and b.psTip:find("3 avisos sin ver", 1, true), "el cuadro de la campanita no dice qué es: " .. tostring(b.psTip))
end)

step("El globito del minimapa: la misma cuenta, dice qué es y abre la lista", function()
  local mm = rawget(_G, "AlfaMinimapButton") or CreateFrame("Button", "AlfaMinimapButton", UIParent)
  N.PintarContadorPerdidos()
  local c = mm.alfaContador
  check(c and c:IsShown() and texto(c.Texto) == "3", "el minimapa no dice 3")
  check(N.TextoSinVer() == "3 avisos sin ver", "el texto del globito no es «3 avisos sin ver»: " .. N.TextoSinVer())
  check(c and c:GetScript("OnEnter") ~= nil, "el globito no tiene cuadro al pasar el ratón")
  if c then FIRE(c, "OnEnter") FIRE(c, "OnLeave") end
  -- El cuadro del botón del minimapa también lo cuenta.
  local Maps = ns.Maps
  if Maps and Maps.ButtonTip then Maps.ButtonTip(mm, nil, true) end
  local v = rawget(_G, "AlfaPerdidos")
  if v then v:Hide() end
  if c then FIRE(c, "OnClick", "LeftButton") end
  v = rawget(_G, "AlfaPerdidos")
  check(v and v:IsShown(), "el clic en el globito no abrió la lista de avisos")
  check(N.AvisosSinVer() == 3, "abrir la lista marcó todo como visto (eso es del botón)")
  if v then v:Hide() end
  -- El clic derecho y el arrastre pasan al botón de Alfa (menú, moverlo).
  if c then
    local viejos = { mm:GetScript("OnClick"), mm:GetScript("OnDragStart"), mm:GetScript("OnDragStop") }
    local vio = {}
    mm:SetScript("OnClick", function(_, bt) vio[#vio + 1] = "clic:" .. tostring(bt) end)
    mm:SetScript("OnDragStart", function() vio[#vio + 1] = "arrastra" end)
    mm:SetScript("OnDragStop", function() vio[#vio + 1] = "suelta" end)
    c.IsMouseOver = function() return true end
    FIRE(c, "OnMouseUp", "RightButton")
    FIRE(c, "OnMouseUp", "LeftButton")
    FIRE(c, "OnDragStart", "LeftButton")
    FIRE(c, "OnDragStop")
    c.IsMouseOver = nil
    mm:SetScript("OnClick", viejos[1]) mm:SetScript("OnDragStart", viejos[2]) mm:SetScript("OnDragStop", viejos[3])
    check(table.concat(vio, ",") == "clic:RightButton,arrastra,suelta", "el globito no pasa el clic derecho y el arrastre al botón: " .. table.concat(vio, ","))
  end
end)

step("La lista: lo perdido y lo reciente, cada uno con hora y su botón", function()
  K.Aviso({ titulo = "Lo viste en pantalla", texto = "reciente", lya = false, pedido = true,
    accion = { texto = "Ir ahí", alClic = function() end } })
  local hay
  for _, e in ipairs(N.Avisos()) do if e.titulo == "Lo viste en pantalla" then hay = e end end
  check(hay and hay.visto and hay.reciente, "un aviso que salió en pantalla no quedó en la lista como visto")
  check(hay and N.IrDeAviso(hay) and N.IrDeAviso(hay).texto == "Ir ahí", "el aviso reciente perdió su botón")
  check(N.AvisosSinVer() == 3, "un aviso visto subió la cuenta")
  local uno
  for _, e in ipairs(N.Avisos()) do if e.titulo == "Aviso uno" then uno = e end end
  local ir = uno and N.IrDeAviso(uno)
  check(ir and ir.texto:find("Ruta", 1, true), "el aviso de misiones no ofrece ir a Ruta: " .. tostring(ir and ir.texto))
  check(type(uno and uno.hora) == "string" and uno.hora ~= "", "el aviso no trae su hora")
  -- La campanita abre la lista.
  local b = campana()
  local v = rawget(_G, "AlfaPerdidos")
  if v then v:Hide() end
  FIRE(b, "OnClick", "LeftButton")
  v = rawget(_G, "AlfaPerdidos")
  check(v and v:IsShown(), "la campanita no abrió la lista")
  check(v and tarjetasVisibles(v) >= 4, "la lista no enseña los 4 avisos: " .. (v and tarjetasVisibles(v) or 0))
  check(ns.UI.Options.frame:IsShown(), "abrir los avisos cerró la ventana de Alfa")
  -- El botón «Ir» de uno lo marca visto: baja a 2.
  if ir then
    local seguiaPagina = false
    local orig = N.Abrir
    N.Abrir = function() seguiaPagina = true end
    for _, e in ipairs(N.Avisos()) do
      if e == uno then
        local a = N.IrDeAviso(e)
        N.MarcarVisto(e)
        a.alClic()
      end
    end
    N.Abrir = orig
    check(seguiaPagina, "«Ver en Ruta» no abrió la página")
    check(N.AvisosSinVer() == 2, "ir a un aviso no lo marcó visto: " .. N.AvisosSinVer())
  end
end)

step("«Marcar todo como visto» baja la campanita y el minimapa", function()
  local v = rawget(_G, "AlfaPerdidos")
  local pie = v and v.Pie
  local marcar
  for _, bt in ipairs(pie and pie.izquierda or {}) do
    if texto(bt.Texto or bt.Label):find("Marcar todo como visto", 1, true) or (bt.GetTexto and bt:GetTexto() == "Marcar todo como visto") then marcar = bt end
  end
  marcar = marcar or (pie and pie.izquierda and pie.izquierda[2])
  check(marcar ~= nil, "no está «Marcar todo como visto»")
  if marcar then FIRE(marcar, "OnClick", "LeftButton") end
  if N.AvisosSinVer() ~= 0 then N.MarcarAvisosVistos() check(false, "el botón «Marcar todo como visto» no marcó") end
  local mm = rawget(_G, "AlfaMinimapButton")
  check(not mm.alfaContador:IsShown(), "el minimapa sigue con su número")
  local b = campana()
  check(not (b.psCuenta and b.psCuenta:IsShown()), "la campanita sigue con su número")
  check(#N.Avisos() >= 4, "marcar como visto borró avisos")
  N.Perdido({ titulo = "Uno nuevo", texto = "después" })
  check(N.AvisosSinVer() == 1 and campana().psCuenta:IsShown(), "un aviso nuevo después de marcar no volvió a contar")
  N.OlvidarAvisos()
  check(#N.Avisos() == 0 and N.AvisosSinVer() == 0, "«Borrar» no vació la lista")
  if v then v:Hide() end
  -- El menú de Alfa trae «Avisos» y Planes (1.3.7e: «Lo que sigues» es la sección Planes).
  local hayA, hayS = false, false
  for _, it in ipairs(ns.UI.Options.MenuItems(UIParent)) do
    if type(it.text) == "string" and it.text:find("Avisos", 1, true) then hayA = true end
    if it.seccion == "planes" then hayS = true end
  end
  check(hayA, "el menú de Alfa no trae «Avisos»")
  check(hayS, "el menú de Alfa no trae Planes")
  ns.UI.Options.frame:Hide()
end)

---------------------------------------------------------------------------
-- «Lo que sigues» (1.3.7e: la sección Planes, hasta 12 guías)
---------------------------------------------------------------------------
local E, G = A.Engine, A.Guides
local EC = Ru.EnCurso
local O = ns.UI.Options
local ids = {}
local MAXI = E.MAX_TABS or 12

local function abiertas()
  local t = {}
  for i, x in ipairs(E.GetTabs() or {}) do t[i] = x.guideId end
  return t
end
local function tarjetasPlanes()
  local n = 0
  for _, v in ipairs(O.Views("planes")) do
    local function cuenta(f)
      for _, c in ipairs({ f:GetChildren() }) do
        if c.alfaDatos and c.alfaDatos.alfaIt and c:IsShown() then n = n + 1 end
        cuenta(c)
      end
    end
    cuenta(v)
  end
  return n
end

step("Doce guías abiertas y tu plan: Planes las enseña todas", function()
  check(EC ~= nil and AlfaRuta and AlfaRuta.EnCurso, "no está «Lo que sigues» (Alfa_Rutas/EnCurso.lua)")
  for i = #(E.GetTabs() or {}), 1, -1 do E.CloseTab(i, true) end
  for _, h in ipairs(G.List() or {}) do
    if #ids >= MAXI + 2 then break end
    if G.Get(h.id) then ids[#ids + 1] = h.id end
  end
  check(#ids >= MAXI + 2, "el banco no tiene " .. (MAXI + 2) .. " guías: " .. #ids)
  for i = 1, MAXI do check(E.OpenTab(ids[i], i == 1), "no se abrió la guía " .. i) end
  check(#abiertas() == MAXI, "no quedaron " .. MAXI .. " pestañas: " .. #abiertas())
  local Pl = Ru.Planes
  local pl = Pl.Nuevo("Plan de prueba", { { tipo = "nota", texto = "Comprar bolsas" }, { tipo = "nota", texto = "Ir al banco" } })
  Pl.Seguir(pl.id)
  local lista = EC.Lista()
  local guias, plan = 0, nil
  for _, it in ipairs(lista) do
    if it.tipo == "guia" then
      guias = guias + 1
      check(type(it.nombre) == "string" and it.nombre ~= "", "una guía sin nombre")
      check(EC.Linea(it):find("aso", 1, true) or not ((it.pasos or 0) > 0 or (it.total or 0) > 0), "la línea no dice el paso: " .. EC.Linea(it))
    else plan = it end
  end
  check(guias == MAXI, "la lista no trae las " .. MAXI .. " guías: " .. guias)
  check(plan and plan.nombre == "Plan de prueba" and plan.total == 2, "la lista no trae tu plan")
  local activas = 0
  for _, it in ipairs(lista) do if it.activa then activas = activas + 1 end end
  check(activas == 1, "no hay una sola marcada como la que sigues: " .. activas)
  RUN_TIMERS(2) -- (seguir tu plan cierra las ventanas de Alfa en el siguiente cuadro)
  AlfaRuta.EnCurso()
  RUN_TIMERS(2)
  check(O.frame and O.frame:IsShown() and O.page and O.page.key == "planes", "no se abrió Planes")
  check(tarjetasPlanes() == MAXI + 1, "Planes no enseña " .. (MAXI + 1) .. " tarjetas: " .. tarjetasPlanes())
  check(EC.Cuantas() == MAXI and select(3, EC.Cuantas()), "no sabe que está lleno")
  -- La tarjeta de la página Ruta.
  local hay
  for _, o in ipairs(Ru.OpcionesPagina()) do if o.titulo == "Lo que sigues" then hay = o end end
  check(hay and hay.tono == "aviso" and hay.texto:find(MAXI .. " de " .. MAXI, 1, true), "la página Ruta no trae «Lo que sigues» lleno: " .. tostring(hay and hay.texto))
end)

step("Quitar una guía y deshacer: vuelve a su lugar y sigues con la tuya", function()
  local antes = abiertas()
  local activa = E.GetGuide().id
  local it
  for _, x in ipairs(EC.Lista()) do if x.tipo == "guia" and not x.activa and x.indice == 3 then it = x end end
  check(it ~= nil, "no encontré la tercera guía")
  if not it then return end
  dichos = {}
  check(EC.Quitar(it), "no la quitó")
  check(#abiertas() == MAXI - 1, "no quedaron " .. (MAXI - 1))
  for _, id in ipairs(abiertas()) do check(id ~= it.id, "la guía quitada sigue abierta") end
  local o = ultimoDicho("Guía quitada")
  check(o and o.acciones and o.acciones[1] and o.acciones[1].texto == "Deshacer", "el aviso de quitar no trae «Deshacer»")
  check(EC.Deshacer(), "Deshacer no hizo nada")
  local despues = abiertas()
  check(#despues == MAXI and despues[3] == it.id, "la guía no volvió a su lugar: " .. table.concat(despues, ","))
  check(E.GetGuide().id == activa, "después de deshacer no sigues con la de antes")
  for i = 1, MAXI do check(antes[i] == despues[i], "el orden cambió en la " .. i) end
end)

step("Quitar todas menos la actual y deshacer; tu plan también", function()
  local activa = E.GetGuide().id
  check(EC.QuitarOtras(true) == MAXI - 1, "no quitó las otras")
  local ab = abiertas()
  check(#ab == 1 and ab[1] == activa, "no quedó solo la actual")
  check(EC.Deshacer(), "no deshizo")
  check(#abiertas() == MAXI and E.GetGuide().id == activa, "no volvieron todas o cambió la actual")
  -- Tu plan
  local Pl = Ru.Planes
  local plan
  for _, it in ipairs(EC.Lista()) do if it.tipo == "plan" then plan = it end end
  check(plan and EC.Quitar(plan) and Pl.Activo() == nil, "no dejó de seguir tu plan")
  check(EC.Deshacer() and Pl.Activo() and Pl.Activo().id == plan.id, "Deshacer no devolvió tu plan")
  -- La confirmación al quitar varias.
  EC.QuitarOtras()
  check(#abiertas() == MAXI, "sin confirmar ya quitó")
  if K.CerrarDialogo then K.CerrarDialogo() end
end)

step("Ya no cabe otra (todas fijadas): «Editar planes» y el cuadro de elegir", function()
  RUN_TIMERS(2) -- (lo que dejó pendiente el paso anterior: seguir tu plan cierra las ventanas)
  O.frame:Hide()
  dichos = {}
  EC.AvisoLleno()
  local o = dichos[#dichos]
  check(o and o.acciones and o.acciones[1] and o.acciones[1].texto == "Editar planes", "el aviso del límite no trae «Editar planes»")
  if o and o.acciones and o.acciones[1] then o.acciones[1].alClic() end
  RUN_TIMERS(2)
  check(O.frame:IsShown() and O.page.key == "planes", "«Editar planes» no abrió Planes")
  O.frame:Hide()
  for _, id in ipairs(abiertas()) do EC.Fijar(id, true) end
  -- Desde la Biblioteca de guías (pestaña nueva): el cuadro de elegir.
  Ru.Biblioteca.Seguir(ids[MAXI + 1], true)
  local v = rawget(_G, "AlfaRutasElegir")
  check(v and v:IsShown(), "la Biblioteca llena no abre el cuadro de elegir")
  if v then v:Hide() end
  -- Desde el selector de guías del motor.
  if ns.UI.Picker and ns.UI.Picker.Load then ns.UI.Picker.Load(ids[MAXI + 1], true) end
  v = rawget(_G, "AlfaRutasElegir")
  check(v and v:IsShown(), "el selector del motor lleno no abre el cuadro de elegir")
  if v then v:Hide() end
  check(#abiertas() == MAXI, "se abrió una de más")
  -- La pestaña + de la ventana de guía, llena y todo fijado, abre Planes.
  local GF = ns.UI and ns.UI.GuideFrame
  A.Set("ui.shown", true)
  A.Fire("TABS_CHANGED")
  correr(2)
  if GF and GF.RenderTabs then GF.RenderTabs() end
  local F = rawget(_G, "AlfaGuideFrame")
  local add = F and F.psStrip and F.psStrip.Add
  check(add and add.psFull, "la ventana de guía no sabe que las pestañas están llenas")
  if add and add.psFull then
    check(add:IsEnabled(), "el + lleno quedó apagado")
    FIRE(add, "OnClick", "LeftButton")
    RUN_TIMERS(2)
    check(O.frame:IsShown() and O.page.key == "planes", "el + lleno no abrió Planes")
    O.frame:Hide()
  end
  for _, id in ipairs(abiertas()) do EC.Fijar(id, false) end
  for i = #(E.GetTabs() or {}), 1, -1 do E.CloseTab(i, true) end
  Ru.Planes.Dejar()
end)

print(("notificaciones 1.3.7: %d pasos"):format(pasos))
