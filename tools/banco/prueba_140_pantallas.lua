-- Prueba de la 1.4.0, «Dos pantallas» rehecho (plan 3 y 68):
--   1. el bug de la escala (Toxic): un clic de ida y vuelta con la ventana
--      «a pantalla completa en ventana» deja cada ajuste (gxWindow, gxMaximize,
--      gxWindowedResolution, gxFullscreenResolution, gxMonitor, useUiScale,
--      uiScale) y la escala de la interfaz exactamente como estaban; también
--      con «Sí» y luego «Una pantalla», y con un /reload a medias. El juego
--      simulado hace lo que hacía mal: dar un tamaño fijo quita «maximizada» y
--      una ventana normal sube la escala de la interfaz.
--   2. «Reparar mi pantalla»: con confirmación, con lo de antes guardado y sin
--      él (pantalla completa en ventana y escala automática); en combate no;
--      /alfa pantallas reparar, la página y el menú de Alfa.
--   3. el tablero: lo principal resalta, «…»/«×» solo con el ratón, la guía no
--      repite la distancia de la flecha, la flecha alta y grande, la hora y
--      «Una pantalla» en la barra, el tamaño de los paneles.
--   4. la vista previa: el escritorio de verdad sin mover nada, se cierra sola,
--      en combate y con «Probar» sigue la prueba de 15 s.
--   5. volver deja todo limpio: anclas, escala, marcos de Alfa (las bolsas).
--   6. secretos: la velocidad, los ajustes y el tamaño de la ventana.
SNAPSHOTS = {}
local function step(nombre, fn, ...)
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.4.0 pantallas", msg) end end
local function correr(n) for _ = 1, n or 1 do RUN_TIMERS(1) end end
local function cerca(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 1) end

PANTALLA_SIMULADA(1920, 1080)
local A, N = Alfa, AlfaNucleo
local K = N.Kit
local Bv = NS_OF("Alfa_Bienvenida")
local Es, Ed, As, Au, Rp = Bv.Escritorio, Bv.EscritorioEditor, Bv.EscritorioAsistente, Bv.EscritorioAuto, Bv.EscritorioReparar

FIRE_EVENT("PLAYER_LOGIN")
local BvG = rawget(_G, "AlfaBienvenida")
N.Datos("bienvenida").respondio = BvG and BvG.VERSION or 99
N.Datos("bienvenida").versionVista = BvG and BvG.VersionAlfa and BvG.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
correr(6)
if A.UI.Options.frame then A.UI.Options.frame:Hide() end
check(Rp ~= nil, "no hay EscritorioReparar")

local combate = false
local origCombate = InCombatLockdown
InCombatLockdown = function() return combate end

---------------------------------------------------------------------------
-- El juego simulado: ajustes, monitores, ventana y la escala automática.
---------------------------------------------------------------------------
local ESCALA_AUTO = 768 / 1080
local cv = { gxWindow = "1", gxMaximize = "1", gxWindowedResolution = "1920x1080", gxFullscreenResolution = "auto",
  gxMonitor = "0", useUiScale = "0", uiScale = "1.0" }
local pedido, reinicios = nil, 0
local origGetCVar, origSetCVar = GetCVar, SetCVar
GetCVar = function(n) return cv[n] end
SetCVar = function(n, v) cv[n] = tostring(v) end
GetMonitorCount = function() return 2 end
C_VideoOptions = {
  GetDefaultGameWindowSize = function(i) if i < 2 then return { x = 1920, y = 1080 } end return nil end,
  -- Una ventana maximizada mide 1919 x 1079 por dentro (como en la captura de Toxic).
  GetCurrentGameWindowSize = function() local w, h = PANTALLA_TAM() if cv.gxMaximize == "1" then return { x = w - 1, y = h - 1 } end return { x = w, y = h } end,
  -- Dar un tamaño fijo vuelve la ventana una ventana normal (lo que pasaba en la 1.3.9).
  SetGameWindowSize = function(x, y) pedido = { x, y } cv.gxMaximize = "0" end,
}
-- Al reiniciar los gráficos: maximizada o pantalla completa = el monitor y la
-- escala automática; una ventana normal = su tamaño y la interfaz más grande.
RestartGx = function()
  reinicios = reinicios + 1
  if cv.gxWindow == "0" or cv.gxMaximize == "1" then
    PANTALLA_SIMULADA(1920, 1080)
    UIParent:SetScale(ESCALA_AUTO)
  elseif pedido then
    PANTALLA_SIMULADA(pedido[1], pedido[2])
    if pedido[1] < 3000 then UIParent:SetScale(1) end
  end
end
local function volverGraficos() FIRE_EVENT("DISPLAY_SIZE_CHANGED") correr(2) end
local CV0 = {}
for k, v in pairs(cv) do CV0[k] = v end
local function cvIguales()
  for k, v in pairs(CV0) do if cv[k] ~= v then return false, k .. "=" .. tostring(cv[k]) .. " (antes " .. v .. ")" end end
  return true
end
UIParent:SetScale(ESCALA_AUTO)

---------------------------------------------------------------------------
-- 1. El bug de la escala: ida y vuelta con un clic
---------------------------------------------------------------------------
step("Un clic de ida y vuelta deja todo como estaba", function()
  local d = N.Datos("pantallas")
  check(Au.PuedeUnClic(), "con dos monitores no se puede el clic")
  check(Au.UnClic("derecha"), "el clic no arrancó")
  check(type(d.antes) == "table" and d.antes.cvars.gxMaximize == "1" and d.antes.cvars.useUiScale == "0", "no guardó lo de antes completo")
  check(cerca(d.antes.escala, ESCALA_AUTO, 0.001), "no guardó la escala de la interfaz: " .. tostring(d.antes.escala))
  check(d.antes.cvars.gxFullscreenResolution == "auto" and d.antes.cvars.gxMonitor == "0", "no guardó la pantalla completa ni el monitor")
  volverGraficos()
  check(Es.Probando() and cerca(UIParent:GetWidth(), 1920), "no empezó la prueba con el juego en el principal")
  -- Sin contestar: vuelve sola.
  correr(16)
  check(not Es.Probando() and Es.Aplicado() == nil, "la prueba no terminó sola")
  volverGraficos()
  local ok, que = cvIguales()
  check(ok, "un ajuste no volvió: " .. tostring(que))
  check(cerca(UIParent:GetScale(), ESCALA_AUTO, 0.001), "la interfaz quedó de otra escala: " .. tostring(UIParent:GetScale()))
  check(cerca(Es.Pantalla(), 1920), "la ventana no volvió al monitor: " .. tostring(Es.Pantalla()))
  check(d.antes == nil and d.verificar == nil, "lo de antes sigue guardado después de confirmar que volvió")
  -- La 1.3.9 hacía esto mal: maximizada y después un tamaño fijo.
  check(cv.gxMaximize == "1", "la ventana quedó sin maximizar")
end)

step("Con «Sí» y luego «Una pantalla» también", function()
  local d = N.Datos("pantallas")
  Au.UnClic("derecha")
  volverGraficos()
  _G.AlfaEscritorioConfirmar.Si:Click()
  check(Au.Fase() == "hecho" and type(d.antes) == "table", "«Sí» no guardó (o se olvidó lo de antes)")
  -- Toca el botón «Una pantalla» de la barra.
  local b = Es.Marco() and Es.Marco().Barra
  check(b and b.Una and b.Una:IsShown(), "no hay «Una pantalla» en la barra")
  if b and b.Una then b.Una:Click() end
  volverGraficos()
  local ok, que = cvIguales()
  check(ok, "tras «Una pantalla» un ajuste no volvió: " .. tostring(que))
  check(cerca(UIParent:GetScale(), ESCALA_AUTO, 0.001), "tras «Una pantalla» la escala no volvió: " .. tostring(UIParent:GetScale()))
  check(Es.Aplicado() == nil and d.antes == nil, "quedó algo puesto o guardado")
end)

step("Un /reload a media prueba devuelve todo", function()
  local d = N.Datos("pantallas")
  Au.UnClic("derecha")
  volverGraficos()
  check(Es.Probando(), "no empezó la prueba")
  -- /reload: el juego pierde la prueba; al entrar, Alfa devuelve todo.
  Es.Rechazar(true)
  d.auto = d.auto or {}
  d.auto.fase = "probando"
  Es.AlEntrar()
  volverGraficos()
  local ok, que = cvIguales()
  check(ok, "tras el /reload un ajuste no volvió: " .. tostring(que))
  check(cerca(UIParent:GetScale(), ESCALA_AUTO, 0.001), "tras el /reload la escala no volvió")
  -- Lo de antes sobrevive al /reload hasta confirmar: se revisa al entrar.
  d.verificar = { foto = { cvars = { gxMaximize = "1" }, escala = ESCALA_AUTO } }
  UIParent:SetScale(1)
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
  correr(4)
  check(cerca(UIParent:GetScale(), ESCALA_AUTO, 0.001) and d.verificar == nil, "al entrar no se revisó lo pendiente")
end)

---------------------------------------------------------------------------
-- 2. «Reparar mi pantalla»
---------------------------------------------------------------------------
step("Reparar mi pantalla", function()
  local d = N.Datos("pantallas")
  -- Como quedó Toxic con la 1.3.9: ventana normal de 1919 x 1079 y la interfaz grande, sin nada guardado.
  d.antes, d.elegido = nil, true
  cv.gxMaximize = "0"
  pedido = { 1919, 1079 }
  RestartGx()
  check(cerca(UIParent:GetScale(), 1, 0.001), "la simulación del bug no subió la escala")
  check(Rp.Ofrecer(), "no se ofrece reparar a quien usó Dos pantallas")
  -- El menú de Alfa lo trae.
  local O = A.UI and A.UI.Options
  local item
  for _, it in ipairs(O.MenuItems(UIParent)) do if it.text == "Reparar mi pantalla" then item = it end end
  check(item ~= nil, "«Reparar mi pantalla» no está en el menú de Alfa")
  -- En combate no.
  combate = true
  check(not Rp.Preguntar(), "en combate se preguntó")
  combate = false
  -- El comando pregunta primero (nada cambia hasta decir que sí).
  local r0 = reinicios
  SlashCmdList.ALFA("pantallas reparar")
  local cu = _G.AlfaEscritorioReparar
  check(cu and cu:IsShown(), "/alfa pantallas reparar no preguntó")
  check(reinicios == r0 and cv.gxMaximize == "0", "cambió algo antes de decir que sí")
  cu.No:Click()
  check(not cu:IsShown() and reinicios == r0, "«Ahora no» hizo algo")
  if item then item.onClick() end
  check(cu:IsShown(), "el menú no preguntó")
  cu.Si:Click()
  volverGraficos()
  check(cv.gxWindow == "1" and cv.gxMaximize == "1" and cv.useUiScale == "0", "sin lo de antes no quedó en pantalla completa con escala automática")
  check(cerca(UIParent:GetScale(), ESCALA_AUTO, 0.001), "reparar no devolvió la escala: " .. tostring(UIParent:GetScale()))
  check(reinicios == r0 + 1, "reparar reinició los gráficos más de una vez: " .. (reinicios - r0))
  -- Con lo de antes guardado: una ventana normal de 1600 x 900 y escala propia.
  d.antes = { cvars = { gxWindow = "1", gxMaximize = "0", gxWindowedResolution = "1600x900", useUiScale = "1", uiScale = "0.9" }, w = 1600, h = 900, escala = 0.9 }
  Rp.Reparar()
  volverGraficos()
  check(cv.gxMaximize == "0" and cv.gxWindowedResolution == "1600x900" and cv.useUiScale == "1" and cv.uiScale == "0.9", "no volvió a lo guardado")
  check(pedido and pedido[1] == 1600 and pedido[2] == 900, "no devolvió el tamaño de la ventana normal")
  check(cerca(UIParent:GetScale(), 0.9, 0.001), "no devolvió la escala guardada: " .. tostring(UIParent:GetScale()))
  check(d.antes == nil, "lo de antes no se olvidó tras reparar")
  -- La página trae el botón.
  A.UI.ShowOptions("pantallas")
  correr(2)
  local enc
  local grupos = O.Search("letra grande") or {}
  for _, g in ipairs(grupos) do
    for _, c in ipairs(g.controls or g.list or g) do if type(c) == "table" and c.label == "Reparar mi pantalla" then enc = true end end
  end
  check(enc, "el buscador no encuentra «Reparar mi pantalla» con «letra grande»")
  if O.frame then O.frame:Hide() end
  -- Todo a como empezó la prueba.
  for k, v in pairs(CV0) do cv[k] = v end
  PANTALLA_SIMULADA(3840, 1080)
  UIParent:SetScale(ESCALA_AUTO)
  FIRE_EVENT("DISPLAY_SIZE_CHANGED")
  correr(2)
end)

---------------------------------------------------------------------------
-- 3. El tablero
---------------------------------------------------------------------------
step("El tablero: jerarquía, ruido, la flecha y la barra", function()
  N.Set("pantallas", "auto", false)
  Es.Aplicar(Es.Geometria({ lado = "derecha", proporcion = "16:9" }))
  Es.Usar("aventura", "jugador")
  correr(2)
  local M = Es.Marcos
  check(M.rastreador and M.rastreador.protagonista and M.flecha and M.flecha.protagonista, "la guía y la flecha no son lo principal")
  check(M.hoy and not M.hoy.protagonista, "Hoy salió como principal")
  check(not Es.TienePanel("reloj"), "Aventura trae otra vez el reloj (va en la barra)")
  -- «…» y «×» solo con el ratón encima.
  check(M.hoy.Cab.Menu:GetAlpha() == 0 and M.hoy.Cab.Cerrar:GetAlpha() == 0, "«…» y «×» se ven sin el ratón")
  M.hoy.IsMouseOver = function() return true end
  Es.RevisarRaton()
  check(M.hoy.Cab.Menu:GetAlpha() == 1, "con el ratón encima no salen «…» y «×»")
  M.hoy.IsMouseOver = nil
  Es.RevisarRaton()
  check(M.hoy.Cab.Menu:GetAlpha() == 0, "al salir el ratón no se esconden")
  Ed.Abrir()
  Es.RevisarRaton()
  check(M.hoy.Cab.Menu:GetAlpha() == 1, "al editar no se ven «…» y «×»")
  Ed.Cerrar()
  -- La guía no repite la distancia (la flecha la dice en grande).
  local I = rawget(_G, "AlfaInicio")
  local paso, dist = I.Paso, I.Distancia
  I.Paso = function() return { guia = "Durotar", hechos = 1, todos = 4, num = 2, total = 4, titulo = "Entrega «Carne de jabalí» a Grimtak", metas = { { t = "kill", texto = "Jabalíes: 6/8" } } } end
  I.Distancia = function() return "142 yardas al noreste", "neutro", "Grimtak" end
  A.Nav = A.Nav or {}
  local gt, to = A.Nav.GetTarget, A.Nav.TargetOffset
  A.Nav.GetTarget = function() return { label = "Grimtak" } end
  A.Nav.TargetOffset = function() return 100, -100 end
  Es.PintarPanel(M.flecha, true)
  Es.PintarPanel(M.rastreador, true)
  check(not M.rastreador.Dist:IsShown(), "la guía repite la distancia de la flecha")
  local _, tam = M.flecha.Dist:GetFont()
  check((tam or 0) >= 22, "la distancia de la flecha no está en grande: " .. tostring(tam))
  local _, tamPaso = M.rastreador.Paso:GetFont()
  check((tamPaso or 0) >= 18, "el paso de la guía no está en grande: " .. tostring(tamPaso))
  check((M.flecha.Llega:GetText() or ""):find("Llegas en", 1, true) and not (M.flecha.Llega:GetText() or ""):find("unos 1 ", 1, true), "«Llegas en…» raro: " .. tostring(M.flecha.Llega:GetText()))
  -- Secretos: la velocidad y el rumbo pueden venir secretos.
  local vel = GetUnitSpeed
  GetUnitSpeed = function() return 7 end
  SECRETOS_PRENDER({ "GetUnitSpeed", "GetPlayerFacing" })
  combate = true
  Es.PintarPanel(M.flecha, true)
  combate = false
  SECRETOS_APAGAR()
  GetUnitSpeed = vel
  -- Sin la flecha a la vista, la guía sí dice la distancia.
  Es.QuitarPanel("flecha")
  Es.PintarPanel(M.rastreador, true)
  check(M.rastreador.Dist:IsShown(), "sin la flecha la guía no dice la distancia")
  Es.Restablecer()
  I.Paso, I.Distancia, A.Nav.GetTarget, A.Nav.TargetOffset = paso, dist, gt, to
  -- La barra: la hora, el desplegable y nada encimado.
  local b = Es.Marco().Barra
  check(b.Hora:IsShown() and (b.Hora:GetText() or "") ~= "", "la barra no trae la hora")
  check(b.Lista:IsShown(), "la barra no trae el desplegable")
  check(b.Lista:GetRight() <= b.Hora:GetLeft() and b.Hora:GetRight() <= b.AutoTexto:GetLeft(), "la hora se encima en la barra")
  -- El tamaño de los paneles.
  N.Set("pantallas", "tamano", "enorme")
  Es.PonerEscala()
  check(cerca(Es.Marco().Area:GetScale(), 1.3, 0.001), "«Muy grande» no agrandó los paneles")
  N.Set("pantallas", "tamano", "normal")
  Es.PonerEscala()
  check(cerca(Es.Marco().Area:GetScale(), 1, 0.001), "«Normal» no volvió al tamaño de siempre")
  N.Set("pantallas", "tamano", "grande")
  Es.PonerEscala()
  -- El fondo: una noche (cielo, estrellas, luna) y se apaga con su ajuste.
  local cielo = Es.Marco().Cielo
  check(cielo and cielo.Estrellas and #cielo.Estrellas > 20 and cielo.Luna, "el escritorio no trae su noche")
  -- Una franja angosta: la barra no se encima y los paneles no crecen.
  Es.Volver()
  PANTALLA_SIMULADA(2560, 1080)
  N.Set("pantallas", "tamano", "enorme")
  Es.Aplicar(Es.Geometria({ lado = "derecha", proporcion = "medida", medida = 66 }))
  correr(2)
  check(cerca(Es.Marco().Area:GetScale(), 1, 0.001), "en una franja angosta los paneles crecieron")
  local bb = Es.Marco().Barra
  local derecha = bb.Editar:GetLeft()
  check(bb.Lista:GetRight() <= derecha, "en la barra angosta el desplegable se encima con «Editar»")
  N.Set("pantallas", "tamano", "grande")
  Es.Volver()
  PANTALLA_SIMULADA(3840, 1080)
  FIRE_EVENT("DISPLAY_SIZE_CHANGED")
  correr(2)
end)

---------------------------------------------------------------------------
-- 4. La vista previa
---------------------------------------------------------------------------
step("La vista previa: de verdad y sin mover nada", function()
  local m0, u0 = Es.Anclas(WorldFrame), Es.Anclas(UIParent)
  As.Abrir()
  As.Paso(2)
  check(As.VistaPrevia(), "«Ver cómo queda» no abrió la vista previa")
  check(Es.EnVista() and not As.Visible(), "no se ve la vista previa (o el asistente sigue encima)")
  local d = Es.Marco()
  check(d:IsVisible() and cerca(d:GetLeft(), 1920) and cerca(d:GetWidth(), 1920), "el escritorio no quedó donde va")
  check(cerca(WorldFrame:GetWidth(), 3840) and cerca(UIParent:GetWidth(), 3840), "la vista previa movió el mundo o la interfaz")
  check(Es.Aplicado() == nil, "la vista previa lo dejó puesto")
  local velo = _G.AlfaEscritorioVista
  check(velo and velo:IsShown() and cerca(velo:GetRight(), 1920), "el velo no tapa el lado del juego")
  -- Se cierra sola y vuelve el asistente.
  correr(31)
  check(not Es.EnVista() and not d:IsShown(), "la vista previa no se cerró sola")
  check(As.Visible(), "al cerrarse no volvió el asistente")
  -- En combate se cierra y no se abre.
  As.VistaPrevia()
  combate = true
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not Es.EnVista(), "la vista previa siguió en combate")
  check(not Es.VistaPrevia({}), "en combate se abrió la vista previa")
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  -- «Probar 15 segundos» sigue con la prueba de siempre.
  As.Paso(2)
  As.VistaPrevia()
  velo.Tarjeta.Probar:Click()
  check(not Es.EnVista() and Es.Probando(), "«Probar» desde la vista previa no probó")
  Es.Rechazar(true)
  correr(1)
  check(#Es.Anclas(WorldFrame) == #m0 and #Es.Anclas(UIParent) == #u0, "después de la vista previa quedaron otras anclas")
  As.Cerrar()
end)

---------------------------------------------------------------------------
-- 5. Volver deja todo limpio
---------------------------------------------------------------------------
step("Volver deja todo limpio (anclas, escala, marcos de Alfa)", function()
  local Bo = rawget(_G, "AlfaBolsas")
  if Bo and Bo.Abrir then pcall(Bo.Abrir) end
  correr(2)
  -- La medida de cada marco de Alfa hijo de UIParent.
  local function medidas()
    local t = {}
    for _, c in ipairs({ UIParent:GetChildren() }) do
      local n = c.GetName and c:GetName()
      if type(n) == "string" and n:find("^Alfa") and c:IsShown() then
        t[n] = string.format("%.2f %.1f %.1f", c:GetScale() or 1, c:GetWidth() or 0, c:GetHeight() or 0)
      end
    end
    return t
  end
  local antes = medidas()
  local esc = UIParent:GetScale()
  Es.Aplicar(Es.Geometria({ lado = "derecha", proporcion = "16:9" }))
  correr(2)
  Es.Apagar(true)
  correr(2)
  check(Es.Limpio(), "al volver el mundo o la interfaz no llenan la ventana")
  check(cerca(UIParent:GetScale(), esc, 0.0001), "al volver cambió la escala de la interfaz")
  local despues = medidas()
  for n, v in pairs(antes) do
    if despues[n] and despues[n] ~= v then NOTE("1.4.0 pantallas", "el marco " .. n .. " cambió al volver: " .. v .. " -> " .. despues[n]) end
  end
  -- Si algo dejó el mundo achicado mientras estaba puesto, volver lo arregla
  -- (si antes llenaba la ventana).
  Es.Aplicar(Es.Geometria({ lado = "derecha", proporcion = "16:9" }))
  correr(1)
  local orig = Es.Original()
  orig.mundo = { { "TOPLEFT", nil, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", nil, "TOPLEFT", 100, -100 } }
  Es.Volver()
  check(cerca(WorldFrame:GetWidth(), 3840), "volver no arregló un mundo que antes llenaba la ventana")
end)

---------------------------------------------------------------------------
-- 6. Secretos en los ajustes y la ventana
---------------------------------------------------------------------------
step("Secretos en los ajustes y la ventana", function()
  local gv, gw = GetCVar, C_VideoOptions.GetCurrentGameWindowSize
  GetCVar = function(n) return SECRETO(cv[n]) end
  C_VideoOptions.GetCurrentGameWindowSize = function() return SECRETO({ x = 1920, y = 1080 }) end
  local ok, f = pcall(Rp.Foto)
  check(ok and type(f) == "table", "la foto truena con ajustes secretos: " .. tostring(f))
  local ok2, dif = pcall(Rp.Diferencias, { cvars = { gxMaximize = "1" } })
  check(ok2, "comparar con ajustes secretos truena: " .. tostring(dif))
  GetCVar, C_VideoOptions.GetCurrentGameWindowSize = gv, gw
end)

GetCVar, SetCVar = origGetCVar, origSetCVar
C_VideoOptions, GetMonitorCount, RestartGx = nil, nil, nil
InCombatLockdown = origCombate
print("PRUEBA: 1.4.0 pantallas", #ERRORS == 0 and "bien" or ("con " .. #ERRORS .. " errores"))
