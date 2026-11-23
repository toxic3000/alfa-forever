-- Prueba de la 1.3.7 (tercera ronda), área «mundo»: lo que ves mientras
-- juegas, fuera de la ventana de Alfa (tools/prueba.py la corre con las demás):
--   1. el rastreador: la barra del avance de la guía en su cabecera;
--   2. el rastreador plegado con un clic en la cabecera (arrastrar no pliega);
--   3. la flecha parada: «≈ 34 s a pie» / «montado» (también con un secreto);
--   4. la distancia en el cuadro de los pines: «A 100 yd, al norte»;
--   5. el anuncio de zona: «¡Primera vez aquí!» y «3 de tus misiones son de aquí»;
--   6. tu camino de hoy en el mapa de Alfa (anotar, ralear, día nuevo, dibujar);
--   7. Lya brinca al llegar a donde apunta la flecha.
SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[name] = { entries = entries, l = l, b = b, w = w, h = h }
end
-- Con margen abajo (lo que cuelga del marco: la línea de la flecha, la
-- segunda línea del anuncio).
local function SNAP_ABAJO(name, f, abajo)
  local esc = CreateFrame("Frame", nil, UIParent)
  esc:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  esc:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, -abajo)
  esc:Show()
  SNAP(name, esc, { f })
  esc:Hide()
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
local function check(cond, msg) if not cond then NOTE("1.3.7c mundo", msg) end end
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = rawget(t, k) } rawset(t, k, v) end
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
local Nav = A.Nav
local Arrow = Nav.arrow
local Ru = NS_OF("Alfa_Rutas")
local Rs = Ru.Rastreador
local Mu = NS_OF("Alfa_Mundo")
local Ly = NS_OF("Alfa_Lya")
if A.UI.Options.frame then A.UI.Options.frame:Hide() end

---------------------------------------------------------------------------
-- 1 y 2. El rastreador: la barra del avance y plegarlo
---------------------------------------------------------------------------

step("El rastreador: la barra del avance en la cabecera", function()
  Rs.Plegar(false)
  Rs.Mostrar()
  RUN_TIMERS(5)
  local F = rawget(_G, "AlfaRastreador")
  check(F and F:IsShown(), "el rastreador no se ve")
  if not F then return end
  local done, total = A.Engine.GetProgress()
  local c = F:GetChildren()
  -- La cabecera es el primer hijo con Avance.
  local cab
  for _, h in ipairs({ F:GetChildren() }) do if rawget(h, "Avance") then cab = h end end
  check(cab ~= nil, "la cabecera no tiene su barra de avance")
  if not cab then return end
  if total and total > 0 then
    check(cab.Avance:IsShown(), "con una guía de pasos no se ve la barra del avance")
    check(not cab.Linea:IsShown(), "la línea de la cabecera sigue debajo de la barra")
    check(math.abs((cab.Avance.alfaFrac or -1) - done / total) < 0.001, "la barra no dice lo hecho: " .. tostring(cab.Avance.alfaFrac))
  end
  SNAP("137c-rastreador", F)
end)

step("El rastreador se pliega con un clic en la cabecera (y arrastrar no)", function()
  local F = rawget(_G, "AlfaRastreador")
  if not F then return end
  local cab
  for _, h in ipairs({ F:GetChildren() }) do if rawget(h, "Avance") then cab = h end end
  local alto = F:GetHeight()
  FIRE(cab, "OnMouseDown", "LeftButton")
  FIRE(cab, "OnMouseUp", "LeftButton")
  check(Rs.Plegada(), "el clic en la cabecera no plegó la guía")
  local plegado = F:GetHeight()
  check(plegado < alto, ("plegada no es más chica: %s -> %s"):format(alto, plegado))
  -- Plegada: sin pie ni metas; el paso de ahora sí.
  local pieVisible = false
  for _, h in ipairs({ F:GetChildren() }) do
    if h:IsShown() and h.GetText and (h:GetText() == "Omitir" or h:GetText() == "Ver detalle") then pieVisible = true end
  end
  check(not pieVisible, "plegada sigue con el pie (Ver detalle / Omitir)")
  SNAP("137c-rastreador-plegado", F)
  -- Un arrastre no la despliega.
  FIRE(cab, "OnMouseDown", "LeftButton")
  FIRE(cab, "OnDragStart")
  FIRE(cab, "OnDragStop")
  FIRE(cab, "OnMouseUp", "LeftButton")
  check(Rs.Plegada(), "arrastrar la cabecera desplegó la guía")
  -- Se recuerda (datos de Rutas).
  check(N.Datos("rutas").plegada == true, "plegada no se guarda")
  -- Otro clic: vuelve como estaba.
  FIRE(cab, "OnMouseDown", "LeftButton")
  FIRE(cab, "OnMouseUp", "LeftButton")
  check(not Rs.Plegada(), "el segundo clic no desplegó la guía")
  check(math.abs(F:GetHeight() - alto) < 1, "desplegada no volvió a su alto")
  -- El clic derecho no hace nada.
  FIRE(cab, "OnMouseDown", "RightButton")
  FIRE(cab, "OnMouseUp", "RightButton")
  check(not Rs.Plegada(), "el clic derecho plegó la guía")
end)

---------------------------------------------------------------------------
-- 3. La flecha parada: el estimado a pie o montado
---------------------------------------------------------------------------

local function conFlecha(dist, fn)
  local Target = { label = "Mata 8 jabalíes erizados", map = 1411, x = 50, y = 50 }
  con(Nav, { Sample = function() return "travel", dist, 0.6 end, GetTarget = function() return Target end,
    TomTomArrowGuides = function() return false end, HandedOff = function() return false end, HiddenWithGuide = function() return false end }, function()
    con(A, { ArrowHidden = function() return false end }, function()
      con(Nav.travel, { Active = function() return false end }, function()
        Arrow:OnTarget(Target)
        Arrow.frame:Show()
        for _ = 1, 6 do FIRE(Arrow.frame, "OnUpdate", 0.3) end
        fn()
      end)
    end)
  end)
end

step("La flecha parada dice cuánto te toma a pie o montado", function()
  local eta = Arrow.etaText
  check(Arrow.PASO_A_PIE == 7 and Arrow.ESTIMA_DESDE == 40, "faltan los pasos del estimado")
  con(_G, { IsMounted = function() return false end }, function()
    conFlecha(240, function()
      check(eta:IsShown(), "parado a 240 yd no dice el estimado")
      check(eta:GetText() == "≈ 34 s a pie", "a pie: " .. tostring(eta:GetText()))
      SNAP_ABAJO("137c-flecha", Arrow.frame, 24)
    end)
  end)
  con(_G, { IsMounted = function() return true end }, function()
    conFlecha(240, function()
      check(eta:GetText() == "≈ 21 s montado", "montado: " .. tostring(eta:GetText()))
    end)
  end)
  -- Un secreto no truena y cuenta como a pie.
  con(_G, { IsMounted = function() return SECRETO(true) end }, function()
    conFlecha(900, function()
      check(eta:GetText() == "≈ 2 min 09 s a pie" or (eta:GetText() or ""):find("a pie", 1, true), "con un secreto: " .. tostring(eta:GetText()))
    end)
  end)
  -- Cerca no dice nada.
  con(_G, { IsMounted = function() return false end }, function()
    conFlecha(25, function()
      check(not eta:IsShown(), "a 25 yd sigue el estimado: " .. tostring(eta:GetText()))
    end)
  end)
  Arrow:OnTarget(nil)
  Arrow.frame:Hide()
end)

---------------------------------------------------------------------------
-- 4. La distancia en el cuadro de los pines
---------------------------------------------------------------------------

local function cuadro()
  local t = { lineas = {} }
  function t:SetText(s) self.lineas = { s } end
  function t:AddLine(s) self.lineas[#self.lineas + 1] = s end
  function t:AddDoubleLine(a) self.lineas[#self.lineas + 1] = a end
  return t
end

step("Cada pin dice a qué distancia está y hacia dónde", function()
  local DP = Mu.DistanciaPines
  check(DP and DP.Linea, "falta DistanciaPines")
  if not DP then return end
  local yo = { 0, 1000, 1000 }
  con(A.Compat, { GetPlayerWorldPosition = function() return yo[1], yo[2], yo[3] end }, function()
    check(DP.Linea({ c = 0, wx = 1100, wy = 1000 }) == "A 100 yd, al norte", "al norte: " .. tostring(DP.Linea({ c = 0, wx = 1100, wy = 1000 })))
    check(DP.Linea({ c = 0, wx = 900, wy = 900 }) == "A 141 yd, al sureste", "al sureste: " .. tostring(DP.Linea({ c = 0, wx = 900, wy = 900 })))
    check(DP.Linea({ c = 0, wx = 1005, wy = 1000 }) == "Aquí mismo", "aquí mismo")
    check(DP.Linea({ c = 1, wx = 1100, wy = 1000 }) == nil, "otro continente dice distancia")
    -- Por la capa: el cuadro de antes y la línea al final.
    local pin = { c = 0, wx = 1000, wy = 1300, tooltip = "Posada" }
    local cuenta = 0
    local pin2 = { c = 0, wx = 1000, wy = 700, tooltip = function(tt) cuenta = cuenta + 1 tt:SetText("Maestro de vuelo") end }
    A.Pins.SetLayer("prueba.137c", { pin, pin2 }, { minimap = true })
    check(type(pin.tooltip) == "function", "el pin no se envolvió")
    local t = cuadro()
    pin.tooltip(t)
    check(t.lineas[1] == "Posada" and t.lineas[2] == "A 300 yd, al oeste", "el cuadro de la posada: " .. table.concat(t.lineas, " | "))
    t = cuadro()
    pin2.tooltip(t)
    check(cuenta == 1 and t.lineas[1] == "Maestro de vuelo" and t.lineas[2] == "A 300 yd, al este", "el cuadro del vuelo: " .. table.concat(t.lineas, " | "))
    -- Publicar la misma tabla otra vez no la envuelve dos veces.
    A.Pins.SetLayer("prueba.137c", { pin, pin2 }, { minimap = true })
    t = cuadro()
    pin2.tooltip(t)
    check(#t.lineas == 2 and cuenta == 2, "se envolvió dos veces: " .. table.concat(t.lineas, " | "))
    -- Apagado: el cuadro como antes.
    A.Set("mundo.distanciaPines", false)
    t = cuadro()
    pin.tooltip(t)
    check(#t.lineas == 1, "apagado sigue la distancia")
    A.Set("mundo.distanciaPines", true)
    -- La Jauría ya lo dice: no se toca.
    local lobo = { c = 0, wx = 1100, wy = 1000, tooltip = "Lobato" }
    A.Pins.SetLayer("manada.jauria", { lobo }, {})
    check(lobo.tooltip == "Lobato", "se envolvió un pin de La Jauría")
    A.Pins.ClearLayer("manada.jauria")
    -- Tu posición secreta: sin línea y sin errores.
    yo = { SECRETO(0), SECRETO(1000), SECRETO(1000) }
    t = cuadro()
    pin.tooltip(t)
    check(#t.lineas == 1, "con la posición secreta salió una distancia")
    A.Pins.ClearLayer("prueba.137c")
  end)
end)

---------------------------------------------------------------------------
-- 5. El anuncio de zona: primera vez y tus misiones de aquí
---------------------------------------------------------------------------

step("El anuncio de zona: «¡Primera vez aquí!» y tus misiones de aquí", function()
  local Z = N.Zonas
  Z.Olvidar()
  local explorado = {}
  local log = {
    { isHeader = true, title = "Los Baldíos" }, { questID = 1 }, { questID = 2 }, { questID = 3, isHidden = true },
    { isHeader = true, title = "Durotar" }, { questID = 4 },
  }
  con(_G, {
    GetRealZoneText = function() return "Los Baldíos" end, GetZoneText = function() return "Los Baldíos" end,
    GetSubZoneText = function() return "El Cruce" end, IsResting = function() return false end,
    UnitLevel = function() return 14 end, IsInInstance = function() return false, "none" end,
    UnitOnTaxi = function() return false end,
    C_MapExplorationInfo = { GetExploredMapTextures = function() return explorado end },
    C_QuestLog = setmetatable({ GetNumQuestLogEntries = function() return #log end, GetInfo = function(i) return log[i] end }, { __index = C_QuestLog }),
  }, function()
    con(Z, { MapaZona = function() return 1413 end }, function()
      con(A.Maps or {}, { GetZoneLevels = function() return 10, 25 end }, function()
        check(Z.MisionesDe("Los Baldíos") == 2, "no cuenta tus 2 misiones de Los Baldíos: " .. Z.MisionesDe("Los Baldíos"))
        check(Z.MisionesDe("Durotar") == 1, "Durotar: " .. Z.MisionesDe("Durotar"))
        local o = Z.Zona()
        check(o and o.sobre == "¡Primera vez aquí!", "no dice que es tu primera vez: " .. tostring(o and o.sobre))
        check(o and o.texto:find("2 de tus misiones son de aquí", 1, true), "no dice tus misiones de aquí: " .. tostring(o and o.texto))
        check(o and o.texto:find("Niveles 10", 1, true), "se perdieron los niveles: " .. tostring(o and o.texto))
        -- El anuncio en la pantalla.
        K.QuitarAnuncio()
        K.Anuncio(o)
        local f = rawget(_G, "AlfaAnuncio")
        if f and f:IsShown() then
          for _ = 1, 40 do NOW = NOW + 0.05 FIRE(f, "OnUpdate", 0.05) end
          for _, tx in ipairs({ f.RayaI, f.RayaD }) do if tx then tx._tex = "white" end end
          SNAP_ABAJO("137c-zona", f, 40)
        else
          NOTE("1.3.7c mundo", "no salió el anuncio de la zona")
        end
        K.QuitarAnuncio()
        -- Ya anunciada: la segunda vez no es «primera vez».
        Z.Visitada(1413)
        o = Z.Zona()
        check(o and o.sobre ~= "¡Primera vez aquí!", "la segunda vez sigue siendo «primera vez»")
        -- Un personaje que ya anduvo ahí (varios rincones explorados) no la ve nueva.
        Z.Olvidar()
        explorado = { {}, {}, {} }
        o = Z.Zona()
        check(o and o.sobre ~= "¡Primera vez aquí!", "con la zona explorada dice «primera vez»")
        -- Una misión sola: singular.
        log = { { isHeader = true, title = "Los Baldíos" }, { questID = 1 } }
        o = Z.Zona()
        check(o and o.texto:find("1 de tus misiones es de aquí", 1, true), "singular: " .. tostring(o and o.texto))
        -- Un encabezado secreto no truena.
        log = { { isHeader = SECRETO(true), title = SECRETO("Los Baldíos") }, { questID = 1 } }
        check(Z.MisionesDe("Los Baldíos") >= 0, "con secretos")
      end)
    end)
  end)
  Z.Olvidar()
end)

---------------------------------------------------------------------------
-- 6. Tu camino de hoy
---------------------------------------------------------------------------

step("Tu camino de hoy: anotar, ralear, día nuevo y dibujarlo en el mapa", function()
  local Ra = Mu.Rastro
  check(Ra and Ra.Anotar, "falta Rastro")
  if not Ra then return end
  Ra.Olvidar()
  local pos = { 0, 0, 0 }
  local pelea = false
  con(A.Compat, { GetPlayerWorldPosition = function() return pos[1], pos[2], pos[3] end }, function()
    con(_G, { InCombatLockdown = function() return pelea end, UnitOnTaxi = function() return false end,
      IsInInstance = function() return false, "none" end }, function()
      pos = { 0, -2000, 800 }
      check(Ra.Anotar(), "el primer punto no se anotó")
      pos = { 0, -2010, 800 }
      check(not Ra.Anotar(), "a 10 yd se anotó otro punto")
      pos = { 0, -2030, 800 }
      check(Ra.Anotar(), "a 30 yd no se anotó")
      pelea = true
      pos = { 0, -2100, 800 }
      check(not Ra.Anotar(), "en combate se anotó")
      pelea = false
      pos = { SECRETO(0), SECRETO(-2200), SECRETO(800) }
      check(not Ra.Anotar(), "con la posición secreta se anotó")
      -- Un camino largo por Durotar (para verlo en el mapa).
      for i = 1, 120 do
        pos = { 0, -2030 - i * 30, 800 + math.sin(i / 8) * 260 }
        Ra.Anotar()
      end
      check(Ra.Puntos() == 122, "puntos: " .. Ra.Puntos())
      -- Lleno: se ralea, nunca pasa del tope.
      local tope = Ra.MAX
      local r = N.DatosPersonaje("mundo").rastro
      for i = #r.c + 1, tope do r.c[i], r.x[i], r.y[i] = 0, -6000 - i, 0 end
      pos = { 0, -9000, 0 }
      Ra.Anotar()
      check(Ra.Puntos() <= tope and Ra.Puntos() > tope / 2, "al llenarse: " .. Ra.Puntos())
      -- Día nuevo: empieza de cero.
      N.DatosPersonaje("mundo").rastro.dia = "2001-01-01"
      check(Ra.Puntos() == 0, "un día nuevo no empezó de cero")
      pos = {} -- (sin posición mientras se abre el mapa: el reloj no anota)
      -- En el mapa de Alfa: el banco no trae las coordenadas del mundo; una
      -- de mentira (cada continente de 10000 yd de lado).
      local mtw = A.Compat.MapToWorld
      A.Compat.MapToWorld = function(_, x, y) return 1, 5000 - y * 100, 5000 - x * 100 end
      Mu.Ventana.Abrir()
      RUN_TIMERS(5)
      local W = rawget(_G, "AlfaMundoMapa")
      if W then for _ = 1, 3 do FIRE(W.Vista or W, "OnUpdate", 0.3) end end
      local P = Mu.Trayecto.Proyecciones()[1]
      local a = Mu.Lienzo.Ahora()
      check(W and W:IsShown() and P and a and a.ox, "no se abrió el mapa de Alfa con su proyección")
      if W and W:IsShown() and P and a and a.ox then
        -- Un paseo que cruza la vista: de la vista (unidades) a yardas.
        local function aYardas(vx, vy)
          local lx, ly = (vx - a.ox) / a.k, (vy - a.oy) / a.k
          return P.xa + (ly - P.y0) / P.ch * P.dx, P.ya + (lx - P.x0) / P.cw * P.dy
        end
        for i = 0, 160 do
          local wx, wy = aYardas(380 + i * 4.2, 560 - i * 1.6 + math.sin(i / 7) * 40)
          pos = { 1, wx, wy }
          Ra.Anotar()
        end
        for _ = 1, 4 do FIRE(W.Vista or W, "OnUpdate", 0.3) end
        print("rastro: dibujados", Ra.Dibujados(), "puntos", Ra.Puntos())
        check(Ra.Dibujados() > 20, "el camino de hoy no se dibujó en el mapa: " .. Ra.Dibujados())
        SNAP("137c-rastro", W)
        -- 1.3.7d: arrastrar o repintar sin puntos nuevos no vuelve a pasar
        -- cada punto por la proyección (era un pcall por punto en cada cuadro).
        local Tr = Mu.Trayecto
        local av, llamadas = Tr.AVista, 0
        Tr.AVista = function(...) llamadas = llamadas + 1 return av(...) end
        local dib = Ra.Dibujados()
        for _ = 1, 5 do
          if Mu.Ventana.Repintar then Mu.Ventana.Repintar() end
          FIRE(W.Vista or W, "OnUpdate", 0.3)
        end
        Tr.AVista = av
        check(llamadas == 0, "el rastro volvió a proyectar sus puntos sin puntos nuevos: " .. llamadas)
        check(Ra.Dibujados() == dib, "el rastro cambió sin moverse: " .. Ra.Dibujados() .. " de " .. dib)
        A.Set("mundo.rastro", false)
        for _ = 1, 3 do FIRE(W.Vista or W, "OnUpdate", 0.3) end
        check(Ra.Dibujados() == 0, "apagado sigue dibujado")
        A.Set("mundo.rastro", true)
        W:Hide()
      end
      A.Compat.MapToWorld = mtw
    end)
  end)
end)

---------------------------------------------------------------------------
-- 7. Lya brinca al llegar
---------------------------------------------------------------------------

step("Lya brinca al llegar a donde apunta la flecha", function()
  local Ll = Ly.Llegada
  local UI = Ly.UI
  check(Ll and Ll.AlLlegar, "falta Lya/Llegada.lua")
  if not (Ll and UI) then return end
  Ll.Olvidar()
  local brincos = 0
  con(UI, { Visible = function() return true end, Hablando = function() return false end,
    Saltar = function() brincos = brincos + 1 end, Pose = function() end }, function()
    -- La flecha llega: el motor avisa y Lya brinca.
    local Target = { label = "La posada", map = 1411, x = 51.5, y = 41.2 }
    local estado = "travel"
    con(Nav, { Sample = function() return estado, 3, 0 end, GetTarget = function() return Target end,
      TomTomArrowGuides = function() return false end, HandedOff = function() return false end, HiddenWithGuide = function() return false end }, function()
      con(A, { ArrowHidden = function() return false end }, function()
        Arrow:OnTarget(Target)
        Arrow.frame:Show()
        FIRE(Arrow.frame, "OnUpdate", 0.3)
        estado = "arrived"
        FIRE(Arrow.frame, "OnUpdate", 0.3)
        check(brincos == 1, "al llegar Lya no brincó: " .. brincos)
        -- Ir y volver en la orilla del radio no la hace brincar otra vez.
        estado = "travel"
        FIRE(Arrow.frame, "OnUpdate", 0.3)
        estado = "arrived"
        FIRE(Arrow.frame, "OnUpdate", 0.3)
        check(brincos == 1, "brincó dos veces por el mismo lugar")
        Arrow:OnTarget(nil)
        Arrow.frame:Hide()
      end)
    end)
    -- Otro lugar sí.
    check(Ll.AlLlegar({ label = "El vuelo", map = 1411, x = 10, y = 10 }), "en otro lugar no brincó")
    -- En combate, no.
    con(_G, { InCombatLockdown = function() return true end }, function()
      check(not Ll.AlLlegar({ label = "Otro", map = 1, x = 1, y = 1 }), "brincó en combate")
    end)
    -- Apagado, no.
    A.Set("lya.brincoLlegar", false)
    check(not Ll.AlLlegar({ label = "Y otro", map = 2, x = 1, y = 1 }), "apagado brincó")
    A.Set("lya.brincoLlegar", true)
  end)
  con(UI, { Visible = function() return false end }, function()
    check(not Ll.AlLlegar({ label = "Escondida", map = 3, x = 1, y = 1 }), "brincó escondida")
  end)
end)

print(("1.3.7c mundo: %d pasos"):format(pasos))
