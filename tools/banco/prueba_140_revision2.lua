-- Prueba de la 1.4.0, área revision2 (tools/prueba.py la corre con las demás prueba_*.lua):
-- los 9 arreglos de la segunda revisión independiente (REVISION-1.4.0b).
--   1. «Acomodar» sigue en el menú después de abrirlo (el panel se llamaba
--      "AlfaAcomodar" y borraba la API global AlfaAcomodar);
--   2. la ventana de Alfa (con su barra lateral) cabe en la pantalla, también
--      con «Escala del menú» grande;
--   3. Mayús+arrastre en las placas: toma el ratón la placa que se ve (nunca
--      el ancla), juntas mueve la flecha y no las separa;
--   4. «Enséñamelo» cierra «Acomodar» al pasar al siguiente paso;
--   5. Mayús+arrastre mueve el anuncio que se ve (y ese clic no lo cierra);
--   6. la flecha no repite el verbo en los 10 idiomas («前往 前往…»);
--   7. la zona de la portada de Hoy se lee por N.Leer antes del «or»;
--   8. la barra de conjuntos nunca queda fuera de la pantalla;
--   9. el reloj kit.movibles no corre toda la sesión por un marco que falta.
local function step(nombre, fn, ...)
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.4.0 revision2", msg) end end
local function T(n) RUN_TIMERS(n or 2) end
local function cerca(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 1.5) end

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
local B = NS_OF("Alfa_Bienvenida")
local Ac = B and B.Acomodar
local Nav = A.Nav
local Arrow = Nav and Nav.arrow

local function shift(abajo)
  IsShiftKeyDown = function() return abajo end
  FIRE_EVENT("MODIFIER_STATE_CHANGED", "LSHIFT", abajo and 1 or 0)
end

---------------------------------------------------------------------------
step("1: la API AlfaAcomodar sobrevive al panel", function()
  local g = rawget(_G, "AlfaAcomodar")
  check(type(g) == "table" and type(rawget(g, "Abrir")) == "function", "falta la API AlfaAcomodar.Abrir")
  check(Ac.Abrir(), "Acomodar no se abrió")
  Ac.Cerrar()
  g = rawget(_G, "AlfaAcomodar")
  check(type(g) == "table" and not g.GetObjectType and type(rawget(g, "Abrir")) == "function"
    and type(rawget(g, "Agregar")) == "function", "tras abrir Acomodar, AlfaAcomodar ya no es la API")
  local p = rawget(_G, "AlfaAcomodarPanel")
  check(type(p) == "table" and p.GetObjectType, "el panel no se llama AlfaAcomodarPanel")
  -- El menú de Alfa sigue ofreciéndolo (Options.lua busca AlfaAcomodar.Abrir).
  local O = A.UI and A.UI.Options
  if O and O.MenuItems then
    local ok, items = pcall(O.MenuItems)
    if ok and type(items) == "table" then
      local hay = false
      local function mirar(t)
        for _, it in ipairs(t) do
          if type(it) == "table" then
            local txt = tostring(it.text or it.texto or it.label or "")
            if txt:find("Acomodar", 1, true) then hay = true end
            if type(it.items) == "table" then mirar(it.items) end
          end
        end
      end
      mirar(items)
      check(hay, "«Acomodar la pantalla» no está en el menú de Alfa después de usarlo")
    end
  end
end)

---------------------------------------------------------------------------
step("2: la ventana de Alfa cabe en la pantalla", function()
  N.Abrir("inicio")
  T(2)
  local f = A.UI.Options and A.UI.Options.frame
  check(f and f.psLateral, "la ventana no tiene su barra lateral")
  if not f then return end
  local function cabe(w, h, escala, que)
    PANTALLA_SIMULADA(w, h)
    A.Set("ui.menuScale", escala)
    FIRE_EVENT("DISPLAY_SIZE_CHANGED")
    local s = f:GetScale() or 1
    check(f:GetWidth() * s <= w - 16 + 0.5 and f:GetHeight() * s <= h - 16 + 0.5,
      string.format("%s: la ventana (%d x %d a %.2f) no cabe en %d x %d", que, f:GetWidth(), f:GetHeight(), s, w, h))
    return s
  end
  cabe(1024, 768, nil, "4:3")
  cabe(1280, 1024, nil, "5:4")
  cabe(1366, 768, 1.3, "1366 con escala 1.3")
  local s = cabe(2560, 1440, 1.2, "2560 con escala 1.2")
  check(cerca(s, 1.2, 0.001), "con lugar de sobra no respetó la escala que elegiste: " .. tostring(s))
  PANTALLA_SIMULADA(1920, 1080)
  A.Set("ui.menuScale", nil)
  FIRE_EVENT("DISPLAY_SIZE_CHANGED")
  check(cerca(f:GetScale(), 1, 0.001), "a 1920 x 1080 la escala de fábrica no es 1: " .. tostring(f:GetScale()))
  f:Hide()
end)

---------------------------------------------------------------------------
local function conPiedra(fn)
  local GT, R = Nav.GetTarget, rawget(_G, "AlfaRuta")
  local ent = R and R.EntregasPiedra
  Nav.GetTarget = function() return { label = "Mata a Espía de la Hermandad para obtener Sello de Alterac" } end
  if R then R.EntregasPiedra = function() return 1 end end
  Arrow.frame:Show()
  local ok, err = pcall(fn)
  Nav.GetTarget = GT
  if R then R.EntregasPiedra = ent end
  if not ok then error(err) end
end

step("3: Mayús en las placas: la que se ve, sin separarlas", function()
  A.Set("acomodar.conMayus", true)
  A.Set("acomodar.iman", false)
  A.Set("ui.lockHud", true)
  local realShift = IsShiftKeyDown
  conPiedra(function()
    check(Arrow.PintarPiedra({ kind = "hearth", place = "Mesón Aguahonda", saved = 130 }), "no se pintó la placa de la piedra")
    local placa = Arrow.PlacaVista and Arrow.PlacaVista()
    check(placa, "no hay placa a la vista")
    if not placa then return end
    check(not Arrow.PlacasAparte(), "de fábrica las placas debían ir con la flecha")
    local ancla = rawget(_G, "AlfaNavPlacas")
    shift(true)
    check(not ancla:IsMouseEnabled(), "con Mayús el ancla de las placas toma el ratón (tapa la flecha y los botones)")
    check(placa:IsMouseEnabled(), "con Mayús la placa que se ve no toma el ratón")
    -- Juntas: Mayús+arrastre en la placa mueve la flecha con ella.
    FIRE(placa, "OnMouseDown", "LeftButton")
    Arrow.frame:ClearAllPoints()
    Arrow.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 300, 700)
    FIRE(placa, "OnMouseUp", "LeftButton")
    check(not Arrow.PlacasAparte() and A.Get("nav.placasPos") == nil, "Mayús+arrastre separó las placas de la flecha sin querer")
    local ap = A.Get("nav.arrowPos")
    check(type(ap) == "table" and cerca(ap.x, 300) and cerca(ap.y, 700), "Mayús+arrastre en la placa no movió la flecha")
    shift(false)
    check(not placa:IsMouseEnabled(), "al soltar Mayús la placa se quedó con el ratón")
    -- Aparte: Mayús mueve solo las placas (el ancla), y la placa toma el ratón.
    check(Ac.Soltar("placas", 1300, 700), "no se pudieron poner aparte")
    check(Arrow.PlacasAparte(), "no quedaron aparte")
    Arrow.PintarPiedra({ kind = "hearth", place = "Mesón Aguahonda", saved = 130 })
    placa = Arrow.PlacaVista()
    shift(true)
    check(placa and placa:IsMouseEnabled() and not ancla:IsMouseEnabled(), "aparte, con Mayús no toma el ratón la placa")
    FIRE(placa, "OnMouseDown", "LeftButton")
    ancla:ClearAllPoints()
    ancla:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 900, 400)
    FIRE(placa, "OnMouseUp", "LeftButton")
    local pp = A.Get("nav.placasPos")
    check(type(pp) == "table", "aparte, Mayús+arrastre no guardó el lugar de las placas")
    local l, b = ancla:GetLeft(), ancla:GetBottom()
    check(cerca(l, 900, 2) and cerca(b, 400, 2), "las placas no quedaron donde se soltaron: " .. tostring(l) .. ", " .. tostring(b))
    check(cerca(ap.x, A.Get("nav.arrowPos").x), "al mover las placas aparte se movió la flecha")
    shift(false)
    K.MovibleVolver("placas")
    K.MovibleVolver("flecha")
  end)
  IsShiftKeyDown = realShift
  A.Set("ui.lockHud", nil)
  A.Set("acomodar.iman", nil)
end)

---------------------------------------------------------------------------
step("4: «Enséñamelo» cierra Acomodar al seguir", function()
  local nota
  for _, x in ipairs(B.NOTAS or {}) do if x.version == "1.4.0" then nota = x end end
  check(nota, "no están las notas de la 1.4.0")
  if not nota then return end
  local pasos = B.PasosDeNota(nota)
  local iAc
  for i, p in ipairs(pasos) do if p[3] == "acomodar" then iAc = i end end
  check(iAc and iAc < #pasos, "el recorrido no tiene el paso de Acomodar antes de otro")
  if not iAc then return end
  local avisos = {}
  local off = A.On("ALFA_AVISO", function(o) if type(o) == "table" and o.id == "bienvenida.recorridoNotas" then avisos[#avisos + 1] = o end end)
  B.RecorridoNotas(nota)
  for _ = 1, iAc - 1 do
    local a = avisos[#avisos]
    if a then a.acciones[1].alClic() end
  end
  check(B.PasoRecorridoNotas() == iAc, "no llegó al paso de Acomodar")
  check(Ac.Activo(), "el paso de Acomodar no lo abrió")
  local a = avisos[#avisos]
  if a then a.acciones[1].alClic() end
  check(B.PasoRecorridoNotas() == iAc + 1, "«Siguiente» no pasó al paso que sigue")
  check(not Ac.Activo(), "Acomodar se quedó abierto encima del resto del recorrido")
  local v = rawget(_G, "AlfaAcomodarPanel")
  check(not (v and v:IsShown()), "el panel de Acomodar sigue a la vista")
  a = avisos[#avisos]
  if a and a.acciones[2] then a.acciones[2].alClic() end
  if type(off) == "function" then off() end
  for _, nombre in ipairs({ "AlfaVistaBandos", "AlfaOptions", "AlfaPerdidos", "AlfaReporteVentana" }) do
    local f = rawget(_G, nombre)
    if f and f.Hide then f:Hide() end
  end
end)

---------------------------------------------------------------------------
step("5: Mayús+arrastre mueve el anuncio que se ve", function()
  A.Set("acomodar.conMayus", true)
  A.Set("acomodar.iman", false)
  local realShift = IsShiftKeyDown
  A.Set("bienvenida.anuncios", true)
  local entrando = N.Entrando
  if N.Entrando then N.Entrando = function() return false end end
  if K.QuitarAnuncio then K.QuitarAnuncio() end
  -- (la placa de la piedra del paso 3 haría esperar al anuncio)
  local pl = Arrow.PlacaVista and Arrow.PlacaVista()
  if pl then pl:Hide() end
  Arrow.frame:Hide()
  NOW = NOW + 10
  T(2)
  K.Anuncio({ estilo = "zona", titulo = "Mulgore", texto = "Niveles 1–10", ya = true, segundos = 60, clave = "probar", espaciar = false })
  for _ = 1, 20 do
    NOW = NOW + 0.05
    local x = rawget(_G, "AlfaAnuncio")
    if x and x:IsShown() then FIRE(x, "OnUpdate", 0.05) end
  end
  N.Entrando = entrando
  local an = rawget(_G, "AlfaAnuncio")
  check(an and an:IsShown(), "no se ve el anuncio de prueba (espera: " .. tostring(K.AnuncioBloqueo and K.AnuncioBloqueo({ titulo = "x", ya = true }) or "?") .. ")")
  if not (an and an:IsShown()) then return end
  local e = K.MovibleDe("anuncio")
  check(e and K.MovibleVisible(e) == an, "el anuncio a la vista no cuenta como «a la vista»")
  shift(true)
  local toque = an.Toque
  check(toque and toque:IsMouseEnabled(), "con Mayús el bloque del anuncio no toma el ratón")
  local ancla = rawget(_G, "AlfaAnuncioAncla")
  check(not ancla:IsMouseEnabled(), "con Mayús el ancla invisible del anuncio toma el ratón")
  FIRE(toque, "OnMouseDown", "LeftButton")
  check(e.arrastrando, "Mayús+clic en el anuncio no empezó a moverlo")
  ancla:ClearAllPoints()
  ancla:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 300)
  FIRE(toque, "OnMouseUp", "LeftButton")
  FIRE(toque, "OnClick", "LeftButton")
  check(an:IsShown() and not an.alfaSaliendo, "el clic de Mayús+arrastre cerró el anuncio")
  shift(false)
  local l, b = K.MovibleRect("anuncio")
  check(cerca(l, 200, 2) and cerca(b, 300, 2), "el anuncio no quedó donde se soltó: " .. tostring(l) .. ", " .. tostring(b))
  -- Sin Mayús, el clic sí lo cierra (como siempre).
  FIRE(toque, "OnClick", "RightButton")
  T(3)
  K.MovibleVolver("anuncio")
  IsShiftKeyDown = realShift
  A.Set("acomodar.iman", nil)
end)

---------------------------------------------------------------------------
step("6: la flecha no repite el verbo en los 10 idiomas", function()
  local verbo = A.EmpiezaConVerbo
  check(type(verbo) == "function", "falta EmpiezaConVerbo")
  if type(verbo) ~= "function" then return end
  local L = A.L
  local real = rawget(L, "Go to")
  local IDIOMAS = {
    { "enUS", "Go to", " the camp" }, { "esMX", "Ve a", "l lugar 1" }, { "esES", "Ve a", " la posada" },
    { "deDE", "Geh zu", " dem Lager" }, { "frFR", "Aller à", " la tour" }, { "ptBR", "Ir até", " o acampamento" },
    { "ruRU", "Идти к", " лагерю" }, { "koKR", "이동", " 골드샤이어" }, { "zhCN", "前往", "暴风城" }, { "zhTW", "前往", "暴風城" },
  }
  for _, t in ipairs(IDIOMAS) do
    rawset(L, "Go to", t[2])
    check(verbo(t[2] .. t[3]), t[1] .. ": «" .. t[2] .. t[3] .. "» no cuenta como que ya empieza con el verbo")
    check(not verbo("Campamento del norte"), t[1] .. ": un lugar sin verbo cuenta como verbo")
  end
  rawset(L, "Go to", "Aller à")
  check(verbo("Va au camp") and verbo("Rends-toi à la tour"), "frFR: «Va…» o «Rends-toi…» no cuentan como verbo")
  rawset(L, "Go to", "Ve a")
  check(not verbo("Vea"), "«Vea» cuenta como «Ve a»")
  rawset(L, "Go to", real)
end)

---------------------------------------------------------------------------
step("7: la zona secreta no rompe la portada de Hoy", function()
  local In = NS_OF("Alfa_Inicio")
  local P = In and In.Pagina
  N.Abrir("inicio")
  T(2)
  local b = P and P.saludo
  check(b and b.Llenar and b.Linea, "no está la portada de Hoy")
  if not b then return end
  local GR, GZ = GetRealZoneText, GetZoneText
  GetRealZoneText = function() return SECRETO("Bosque de Elwynn") end
  GetZoneText = function() return "Villadorada" end
  N.Set("inicio", "portada", true)
  local ok, err = pcall(b.Llenar, b)
  check(ok, "la portada truena con la zona secreta: " .. tostring(err))
  local txt = b.Linea and b.Linea:GetText() or ""
  check(not issecretvalue(txt) and tostring(txt):find("Villadorada", 1, true), "con la zona real secreta no usa la otra: " .. tostring(txt))
  GetZoneText = function() return SECRETO("Villadorada") end
  ok, err = pcall(b.Llenar, b)
  check(ok and not issecretvalue(b.Linea:GetText()), "con las dos zonas secretas truena o escribe un secreto: " .. tostring(err))
  GetRealZoneText, GetZoneText = GR, GZ
  if A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end
end)

---------------------------------------------------------------------------
step("8: la barra de conjuntos nunca queda fuera de la pantalla", function()
  local Bo = NS_OF("Alfa_Bolsas")
  local Cb, Cj = Bo and Bo.Cambio, Bo and Bo.Conjuntos
  check(Cb and Cj, "falta la barra de conjuntos")
  if not (Cb and Cj) then return end
  local cf = rawget(_G, "CharacterFrame") or CreateFrame("Frame", "CharacterFrame", UIParent)
  cf:SetSize(384, 512)
  cf:ClearAllPoints()
  cf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -100)
  cf:Show()
  A.Set("bolsas.barraConjuntos", true)
  local orig = { GetInventoryItemID, GetInventoryItemLink }
  local puestoEn = { [16] = 9201, [1] = 9103 }
  GetInventoryItemID = function(u, r) return puestoEn[r] end
  GetInventoryItemLink = function(u, r) return puestoEn[r] and ("|cff1eff00|Hitem:" .. puestoEn[r] .. "::::::::|h[x]|h|r") or nil end
  Cj.Guardar("Banco uno")
  puestoEn[1] = 9104
  Cj.Guardar("Banco dos")
  Cb.Armar()
  local barra = Cb.Barra()
  check(barra, "no se armó la barra")
  if not barra then return end
  check(barra:IsClampedToScreen(), "la barra no está pegada a la pantalla")
  -- Guardada a 1920 en la orilla derecha; ahora la pantalla es de 1024.
  N.DatosPersonaje(Bo.ID).pos = { "BOTTOMLEFT", 1800, 900 }
  PANTALLA_SIMULADA(1024, 768)
  Cb.Sitio(cf)
  local l, b, w, h = barra:GetRect()
  check(l and l >= -0.5 and l + w <= 1024 + 0.5 and b >= -0.5 and b + h <= 768 + 0.5,
    string.format("la barra quedó fuera de la pantalla: %s, %s (%s x %s)", tostring(l), tostring(b), tostring(w), tostring(h)))
  PANTALLA_SIMULADA(1920, 1080)
  N.DatosPersonaje(Bo.ID).pos = nil
  cf:Hide()
  Cb.Armar()
  Cj.Olvidar("Banco uno")
  Cj.Olvidar("Banco dos")
  GetInventoryItemID, GetInventoryItemLink = orig[1], orig[2]
  A.Set("bolsas.barraConjuntos", nil)
end)

---------------------------------------------------------------------------
step("9: kit.movibles no corre toda la sesión", function()
  check(K.MOVIBLE_BUSCAR and K.MOVIBLE_BUSCAR.veces, "falta K.MOVIBLE_BUSCAR")
  K.Movible("AlfaBancoQueFalta", "banco.falta", { nombre = "Banco que falta", tam = { 100, 40 } })
  check(N.HayTarea("kit.movibles"), "un marco que falta no echó a andar la búsqueda")
  for _ = 1, (K.MOVIBLE_BUSCAR.veces or 10) + 3 do T(1) end
  check(not N.HayTarea("kit.movibles"), "kit.movibles sigue corriendo sin fin por un marco que no existe")
  -- Aparece después: lo encuentran los eventos, sin reloj.
  local f = CreateFrame("Frame", "AlfaBancoQueFalta", UIParent)
  f:SetSize(100, 40)
  FIRE_EVENT("ADDON_LOADED", "Alfa_Banco")
  T(3)
  check(K.MovibleDe("banco.falta").marco == f, "al cargar un addon no se encontró el marco que faltaba")
  -- Y Mayús también busca.
  K.Movible("AlfaBancoQueFalta2", "banco.falta2", { nombre = "Banco que falta 2", tam = { 100, 40 } })
  for _ = 1, (K.MOVIBLE_BUSCAR.veces or 10) + 3 do T(1) end
  local f2 = CreateFrame("Frame", "AlfaBancoQueFalta2", UIParent)
  local realShift = IsShiftKeyDown
  shift(true)
  shift(false)
  IsShiftKeyDown = realShift
  check(K.MovibleDe("banco.falta2").marco == f2, "Mayús no buscó el marco que faltaba")
end)

---------------------------------------------------------------------------
-- 10. Esperando el barco (o con el maestro de vuelo) la tarjeta no parpadea.
-- En el muelle Travel:Refresh sube Travel.version cada segundo (la cuenta de
-- la salida en su texto) y un plan nuevo del mismo viaje también; antes cada
-- subida volvía a armar el modo de la flecha: la tarjeta se escondía y volvía
-- a entrar con su fundido. Aquí: 30 s con la flecha a 20 veces por segundo,
-- la versión sube cada segundo y cada 5 s llega un plan nuevo (tablas nuevas,
-- el mismo viaje). La tarjeta (y las placas) se muestran una vez y se quedan.
---------------------------------------------------------------------------
step("10: la tarjeta del viaje no parpadea esperando", function()
  local Ar, T, X = Arrow, Nav.travel, A.Transit
  check(Ar and T and X, "falta la flecha, Travel o Transit")
  if not (Ar and T and X) then return end
  local guardaT, guardaNav, guardaX = {}, {}, {}
  for _, k in ipairs({ "Active", "CurrentLeg", "NextLeg", "CurrentLabel", "Remaining" }) do guardaT[k] = T[k] end
  for _, k in ipairs({ "Sample", "GetTarget", "HiddenWithGuide", "TomTomArrowGuides", "HandedOff", "IsHiddenState" }) do guardaNav[k] = Nav[k] end
  for _, k in ipairs({ "NextArrival", "NextDeparture", "Riding", "Now" }) do guardaX[k] = X[k] end
  local version0 = T.version
  local DESTINO = { boat = "Isla Theramore", zeppelin = "Orgrimmar", tram = "Forjaz", fly = "Bahía del Botín", hearth = "Villadorada" }
  local MUELLE = { boat = "Menethil", zeppelin = "Entrañas", tram = "Ventormenta", fly = "Villa Oscura", hearth = "Aquí" }
  local esc = { kind = "boat", estado = "muelle", plan = 0, abordo = nil }
  local legs = {}
  local function tramo(kind)
    local k = kind .. "#" .. esc.plan
    legs[k] = legs[k] or { kind = kind, label = "x", to = { name = DESTINO[kind], c = 0, wx = 1, wy = 1 },
      from = { name = MUELLE[kind], c = 0, wx = 0, wy = 0 },
      transport = (kind == "boat" or kind == "zeppelin" or kind == "tram") and { id = "r1" } or nil, side = "a", seconds = 240 }
    return legs[k]
  end
  local paseo = {}
  T.Active = function() return true end
  T.CurrentLeg = function()
    if esc.estado == "camino" then paseo[esc.plan] = paseo[esc.plan] or { kind = "walk", to = { c = 0, wx = 0, wy = 0 } } return paseo[esc.plan] end
    return tramo(esc.kind)
  end
  T.NextLeg = function() if esc.estado == "camino" then return tramo(esc.kind) end return nil end
  T.CurrentLabel = function() return "Toma el barco a Isla Theramore\nSale en " .. math.floor(180 - NOW % 60) .. " s" end
  T.Remaining = function() return 1500 end
  Nav.Sample = function()
    if esc.estado == "camino" then return "travel", 120, 0.4 end
    if esc.estado == "llegada" then return "arrived", 2 end
    return "instruction", 0
  end
  Nav.GetTarget = function() return { label = "Ve a 23.8, 77.3", map = 1445, x = 0.238, y = 0.773 } end
  Nav.HiddenWithGuide = function() return false end
  Nav.TomTomArrowGuides = function() return false end
  Nav.HandedOff = function() return false end
  Nav.IsHiddenState = function() return false end
  X.Now = function() return NOW end
  X.NextArrival = function() return 95, 168, true end
  X.NextDeparture = function() return 168, 300, true end
  X.Riding = function()
    if esc.abordo then return { kind = esc.kind, route = "r1", dock = DESTINO[esc.kind], arriveIn = esc.abordo } end
    return nil
  end
  A.Set("nav.arrow", true)
  A.Set("nav.viajeCompacto", nil)
  local f = Ar.frame

  -- Cuenta cuántas veces se muestra, se esconde y vuelve a entrar.
  local function contar(marco)
    local c = { show = 0, hide = 0, entradas = 0 }
    if marco and not marco.alfaContado then
      marco.alfaContado = true
      marco:HookScript("OnShow", function() if marco.alfaCuenta then marco.alfaCuenta.show = marco.alfaCuenta.show + 1 end end)
      marco:HookScript("OnHide", function() if marco.alfaCuenta then marco.alfaCuenta.hide = marco.alfaCuenta.hide + 1 end end)
    end
    if marco then marco.alfaCuenta = c end
    return c
  end
  local function correr(seg, marco)
    local ultimo = NOW
    local t = 0
    local tPrevio = marco and marco.alfaT or 0
    while t < seg do
      NOW = NOW + 0.05
      t = t + 0.05
      if NOW - ultimo >= 1 then
        ultimo = NOW
        T.version = T.version + 1 -- Travel:Refresh: la cuenta de la salida
        if math.floor(t + 0.001) % 5 == 0 then esc.plan = esc.plan + 1 T.version = T.version + 1 end -- un plan nuevo del mismo viaje
        if esc.abordo then esc.abordo = math.max(0, esc.abordo - 1) end
      end
      FIRE(f, "OnUpdate", 0.05)
      local m = marco
      if m and m:IsShown() then
        if m.alfaT and m.alfaT < tPrevio then m.alfaCuenta.entradas = m.alfaCuenta.entradas + 1 end
        tPrevio = m.alfaT or 0
      end
    end
  end
  local function caso(nombre, kind, estado, marcoDe, permitido)
    esc.kind, esc.estado, esc.abordo = kind, estado, nil
    if estado == "abordo" then esc.estado, esc.abordo = "muelle", 140 end
    if estado == "llegando" then esc.estado, esc.abordo = "muelle", 12 end
    for k in pairs(Ar.cerradas) do Ar.cerradas[k] = nil end
    if Ar.tarjeta then Ar.tarjeta.alfaBordo = nil end
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f:Hide()
    if Ar.OnTarget then Ar:OnTarget(Nav.GetTarget()) end
    f:Show()
    -- Que entre (1 s), y luego 30 s de espera.
    correr(1)
    local m = marcoDe()
    check(m and m:IsShown(), nombre .. ": no salió")
    if not (m and m:IsShown()) then return end
    local c = contar(m)
    correr(30, m)
    local maxHide = permitido or 0
    check(c.hide <= maxHide and c.show <= 0, string.format("%s: se escondió %d y volvió a salir %d veces en 30 s (parpadea)", nombre, c.hide, c.show))
    check(c.entradas == 0, string.format("%s: volvió a entrar con su fundido %d veces en 30 s", nombre, c.entradas))
    if maxHide == 0 then check(m:IsShown(), nombre .. ": ya no se ve al final de la espera") end
    m.alfaCuenta = nil
  end
  local function tarjeta() return Ar.tarjeta end
  caso("barco, caminando al muelle", "boat", "camino", tarjeta)
  caso("barco, esperando en el muelle", "boat", "muelle", tarjeta)
  caso("barco, a bordo", "boat", "abordo", tarjeta, 1)   -- (a bordo se va sola a los 6 s, una vez)
  caso("zepelín, esperando en la torre", "zeppelin", "muelle", tarjeta)
  caso("tranvía, esperando en el andén", "tram", "muelle", tarjeta)
  caso("vuelo, caminando al maestro de vuelo", "fly", "camino", tarjeta)
  caso("vuelo, hablando con el maestro de vuelo", "fly", "muelle", tarjeta)
  caso("vuelo, en el aire", "fly", "abordo", tarjeta, 1)
  caso("vuelo, al aterrizar", "fly", "llegando", tarjeta, 1)
  -- La placa de la piedra de hogar, con la misma espera.
  local R = rawget(_G, "AlfaRuta")
  local ent = R and R.EntregasPiedra
  if R then R.EntregasPiedra = function() return 1 end end
  caso("la placa de la piedra", "hearth", "muelle", function() return Ar.llegada end, 1) -- (sin avance se va sola, una vez)
  if R then R.EntregasPiedra = ent end
  -- La placa de llegada.
  caso("la placa de llegada", "boat", "llegada", function() return Ar.llegada end, 1)

  for k, fn in pairs(guardaT) do T[k] = fn end
  for k, fn in pairs(guardaNav) do Nav[k] = fn end
  for k, fn in pairs(guardaX) do X[k] = fn end
  T.version = version0
  f:Hide()
end)

print(string.format("PRUEBA: 1.4.0 revision2, errores: %d", #ERRORS))
