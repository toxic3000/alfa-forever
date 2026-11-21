-- Prueba de la 1.3.7, el cierre (tools/prueba.py la corre con las demás prueba_*.lua):
--   1. la cola de Momentos no se llama a sí misma sin fin (lo que se vuelve a
--      pedir mientras corre va a la fila) y Lya en una mazmorra con algo
--      importante ya no da «C stack overflow»;
--   2. Cocina no guarda el pescado de respaldo cuando la receta aún no responde (137);
--   3. el menú de addons del minimapa se atenúa en vez de esconderse (154);
--   4. las escalas del vuelo avanzan con el reloj sin tu posición (160);
--   5. consejos callados de Lya: se ve el tope y los que no caben (161);
--   6. «Ver el camino en el mapa» desde Hoy con un paso en marcha (105);
--   7. un barco o un raro que caduca en la fila va a «Lo que me perdí» (51);
--   8. ningún K.Aviso importante de src/ sale sin botón ni «donde» (58).
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
local function check(cond, msg) if not cond then NOTE("1.3.7 cierre", msg) end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local N = AlfaNucleo
local A = N.A
local K = N.Kit
Alfa.Hidden = function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

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

local function sinDesbordar(antes)
  for i = antes + 1, #ERRORS do
    if tostring(ERRORS[i]):find("stack overflow", 1, true) then return false end
  end
  return true
end

---------------------------------------------------------------------------
-- 1. Sin vueltas sin fin
---------------------------------------------------------------------------

step("La cola no se llama a sí misma sin fin; Lya en una mazmorra espera sin desbordar", function()
  local antes = #ERRORS
  local veces, seguir = 0, true
  local function yo()
    veces = veces + 1
    if seguir then N.AlLibre("prueba.cierre.yo", yo, 3) end
  end
  N.AlLibre("prueba.cierre.yo", yo, 3)
  check(veces == 1, "lo que se vuelve a pedir corrió otra vez en el acto: " .. veces)
  check(N.Esperando("prueba.cierre.yo"), "lo que se volvió a pedir no quedó en la fila")
  seguir = false
  RUN_TIMERS(3)
  check(veces == 2, "lo de la fila no salió después: " .. veces)
  check(not N.Esperando("prueba.cierre.yo"), "quedó algo en la fila")
  -- Lya dentro de una mazmorra: lo importante espera (y no da vueltas).
  local Ly = NS_OF("Alfa_Lya")
  if AlfaLya and AlfaLya.Mostrar then AlfaLya.Mostrar(true) end
  con(_G, { IsInInstance = function() return true, "party" end }, function()
    for i = 1, 4 do
      AlfaLya.Decir("Algo importante de prueba " .. i, { importante = true })
      if K.Aviso then K.Aviso({ titulo = "Un aviso de prueba " .. i, texto = "dentro de la mazmorra", lya = true }) end
    end
    RUN_TIMERS(3)
  end)
  check(sinDesbordar(antes), "Lya dio «C stack overflow» en la mazmorra")
  check(Ly.Cerebro and #Ly.Cerebro.Esperas() <= 6, "las esperas de Lya crecieron sin tope")
  RUN_TIMERS(3)
end)

---------------------------------------------------------------------------
-- 2. Cocina: el respaldo no se guarda
---------------------------------------------------------------------------

step("Cocina no guarda el pescado de respaldo (137)", function()
  local Pe = NS_OF("Alfa_Pesca")
  local Co = Pe.Cocina
  local r = Pe.RECETAS[1]
  local function ingredientesDe(lista)
    for _, d in ipairs(lista) do if d.r.hechizo == r.hechizo then return d.ingredientes end end
    return nil
  end
  local responde = false
  local TS = { GetRecipeSchematic = function(id)
    if not responde or id ~= r.hechizo then return nil end
    return { reagentSlotSchematics = { { quantityRequired = 2, reagents = { { itemID = 99001 } } },
      { quantityRequired = 1, reagents = { { itemID = 99002 } } } } }
  end }
  con(_G, { C_TradeSkillUI = TS }, function()
    local ing = ingredientesDe(Co.Recetas())
    check(ing and #ing == 1 and ing[1].id == r.crudo, "sin la receta del juego no usó el pescado de respaldo")
    responde = true
    ing = ingredientesDe(Co.Recetas())
    check(ing and #ing == 2 and ing[1].id == 99001 and ing[1].n == 2, "se quedó guardado el respaldo («1 pescado crudo»): " .. tostring(ing and ing[1] and ing[1].id))
  end)
end)

---------------------------------------------------------------------------
-- 3. El menú de addons se atenúa
---------------------------------------------------------------------------

step("El menú de addons del minimapa se atenúa en vez de esconderse (154)", function()
  local Cm = NS_OF("Alfa_Comodidades")
  local f = rawget(_G, "AddonCompartmentFrame") or CreateFrame("Frame", "AddonCompartmentFrame", Minimap or UIParent)
  f:Show()
  f:SetAlpha(1)
  A.Set("comodidades.minimapa", true)
  A.Set("comodidades.minimapaMenu", true)
  Cm.Minimapa.Aplicar()
  check(f:IsShown(), "el menú de addons se escondió")
  check(f:GetAlpha() == 0, "el menú de addons no se atenuó: " .. tostring(f:GetAlpha()))
  A.Set("comodidades.minimapaMenu", false)
  Cm.Minimapa.Aplicar()
  check(f:IsShown() and f:GetAlpha() == 1, "al apagarlo, el menú de addons no volvió como estaba")
  A.Set("comodidades.minimapaMenu", true)
  Cm.Minimapa.Aplicar()
end)

---------------------------------------------------------------------------
-- 4. Las escalas avanzan
---------------------------------------------------------------------------

step("Las escalas del vuelo avanzan con el reloj (160)", function()
  local Cm = NS_OF("Alfa_Comodidades")
  local V = Cm.Vuelo
  check(V and V.PorTiempo, "falta Vuelo.PorTiempo")
  -- Tres tramos de 300 yd: (300 * 1.15) / 30 + 2 = 13.5 s cada uno.
  local v = { origen = { id = 1, c = 1, wx = 0, wy = 0, nombre = "Orgrimmar" }, tramo = 1,
    paradas = { { id = 2, c = 1, wx = 300, wy = 0, nombre = "Cruce" }, { id = 3, c = 1, wx = 600, wy = 0, nombre = "Trinquete" },
      { id = 4, c = 1, wx = 900, wy = 0, nombre = "Tesorería" } } }
  con(A.Nav, { GetTravelData = function() return nil end }, function()
    v.t = time() - 5
    check(V.PorTiempo(v) == 1, "a los 5 s no va en el primer tramo")
    v.t = time() - 20
    check(V.PorTiempo(v) == 2, "a los 20 s las escalas no avanzaron: " .. tostring(V.PorTiempo(v)))
    v.tramo = 3
    v.t = time() - 5
    check(V.PorTiempo(v) == 3, "las escalas volvieron atrás")
  end)
end)

---------------------------------------------------------------------------
-- 5. Los consejos callados de Lya
---------------------------------------------------------------------------

step("Consejos callados de Lya: se ve el tope y los que no caben (161)", function()
  local Ly = NS_OF("Alfa_Lya")
  local Ap = Ly.Aprende
  for i = 1, 18 do Ap.Callar("pruebaCierre" .. string.char(96 + i), "Un consejo de prueba " .. i) end
  check(#Ap.Lista() >= 18, "no se callaron los 18")
  AlfaNucleo.Abrir("lya")
  RUN_TIMERS(3)
  local ui = Ly.paginaUI
  local g = ui and ui.ajustes and ui.ajustes[7]
  check(g and g.mas, "falta la fila de los que no caben")
  if g and g.mas then
    g:Llenar()
    local fuera = #Ap.Lista() - #g.pool
    check(g.mas:IsShown() and g.mas.alfaDatos.titulo == string.format("Y %d más", fuera), "no dice cuántos no caben: " .. tostring(g.mas.alfaDatos.titulo))
    check((g.todos.alfaDatos.titulo or ""):find("(" .. #Ap.Lista() .. ")", 1, true), "«Todos los que callaste» no dice cuántos son")
  end
  Ap.DevolverTodos()
  if g and g.mas then
    g:Llenar()
    check(not g.mas:IsShown(), "sin callados sigue la fila de los que no caben")
  end
end)

---------------------------------------------------------------------------
-- 6. Ver el camino en el mapa desde Hoy
---------------------------------------------------------------------------

step("«Ver el camino en el mapa» desde Hoy (105)", function()
  local In = NS_OF("Alfa_Inicio")
  local P = In.Pagina
  local E = A.Engine
  local function buscar(lista, titulo)
    for _, x in ipairs(lista or {}) do if x.titulo == titulo then return x end end
    return nil
  end
  local abrio = false
  local motor = {
    GetGuide = function() return { id = "prueba-cierre", title = "Durotar", steps = { {}, {}, {} } } end,
    GetProgress = function() return 1, 3 end,
    GetLiveStep = function() return 2 end,
    GetStepIndex = function() return 2 end,
    GetStepView = function() return { title = "Mata jabalíes", goals = {} } end,
  }
  con(E, motor, function()
    con(AlfaRuta, { VerEnMapa = function() abrio = true return true end }, function()
      local d = P.TarjetaPaso()
      check(d and d.titulo, "no salió la tarjeta del paso")
      local c = buscar(P.Misiones(), "Ver el camino en el mapa")
      check(c, "Hoy no ofrece «Ver el camino en el mapa» con un paso en marcha")
      if c and c.alClic then c.alClic() end
      check(abrio, "«Ver el camino en el mapa» no abrió el mapa")
    end)
  end)
  con(E, { GetGuide = function() return nil end }, function()
    P.TarjetaPaso()
    check(not buscar(P.Misiones(), "Ver el camino en el mapa"), "sin guía sale «Ver el camino en el mapa»")
  end)
end)

---------------------------------------------------------------------------
-- 7. Los anuncios que se fueron sin verse
---------------------------------------------------------------------------

step("Un barco o un raro que caduca sin verse va a «Lo que me perdí» (51)", function()
  check(N.Perdidos and K.AnuncioPerdido, "falta N.Perdidos o K.AnuncioPerdido")
  K.QuitarAnuncio()
  K.Anuncio({ estilo = "barco", titulo = "El barco de prueba", texto = "Llega al muelle", ya = true })
  local raro = { estilo = "raro", titulo = "Un raro de prueba", texto = "Cerca de ti", ya = true, caduca = GetTime() + 2,
    alClic = function() end, pista = "Clic: llévame" }
  K.Anuncio(raro)
  local esperando = false
  for _, e in ipairs(K.AnuncioCola()) do if e.titulo == raro.titulo then esperando = true end end
  check(esperando, "el raro no esperó su turno detrás del barco")
  NOW = NOW + 10
  RUN_TIMERS(3)
  local hay
  for _, e in ipairs(N.Perdidos()) do if e.titulo == raro.titulo then hay = e end end
  check(hay and hay.origen == "anuncio", "el raro que caducó no quedó en «Lo que me perdí»")
  local ac = hay and N.AccionPerdido(hay)
  check(ac and ac.texto == "llévame", "el raro perdido no guardó su acción: " .. tostring(ac and ac.texto))
  -- Una zona que caduca no se guarda (solo barcos y raros).
  K.QuitarAnuncio()
  local n = #N.Perdidos()
  K.AnuncioPerdido({ estilo = "zona", titulo = "Durotar" })
  check(#N.Perdidos() == n, "una zona que caducó quedó en «Lo que me perdí»")
  K.QuitarAnuncio()
end)

---------------------------------------------------------------------------
-- 8. Lo importante dice qué hacer (revisión del código)
---------------------------------------------------------------------------

step("Ningún K.Aviso importante sale sin botón ni «donde» (58)", function()
  local lista
  local ok = pcall(function()
    local p = io.popen('dir /b /s "src\\*.lua" 2>nul')
    if not p then return end
    lista = {}
    for l in p:lines() do lista[#lista + 1] = l end
    p:close()
  end)
  if not (ok and lista and #lista > 0) then print("(58: sin io.popen, la revisión del código no corre aquí)") return end
  local malos = {}
  for _, ruta in ipairs(lista) do
    local f = io.open(ruta, "rb")
    local s = f and f:read("*a") or ""
    if f then f:close() end
    local i = 1
    while true do
      local a, b = s:find("K%.Aviso%s*%(", i)
      if not a then break end
      local d, j = 1, b + 1
      while j <= #s and d > 0 do
        local c = s:sub(j, j)
        if c == "(" then d = d + 1 elseif c == ")" then d = d - 1 end
        j = j + 1
      end
      local llamada = s:sub(b + 1, j - 2)
      local importante = llamada:find("importante%s*=%s*true") or llamada:find('importante%s*=%s*"siempre"')
        or llamada:find("prioridad%s*=%s*[12]%f[^%d]") or llamada:find('prioridad%s*=%s*"urgente"') or llamada:find('prioridad%s*=%s*"importante"')
      local pedido = llamada:find("pedido%s*=%s*true")
      if importante and not pedido and not (llamada:find("accion%s*=") or llamada:find("acciones%s*=") or llamada:find("boton%s*=") or llamada:find("donde%s*=")) then
        malos[#malos + 1] = ruta:match("src\\.*$") or ruta
      end
      i = j
    end
  end
  check(#malos == 0, "avisos importantes sin qué hacer: " .. table.concat(malos, ", "))
end)

print(string.format("PRUEBA: 1.3.7 cierre, %d pasos, %d errores", pasos, #ERRORS))
