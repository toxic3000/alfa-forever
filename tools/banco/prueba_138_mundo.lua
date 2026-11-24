-- Prueba de la 1.3.8, área «mundo y manada» (tools/prueba.py la corre con las demás):
--   3. «Toma el grifo»: el ahorro de la ruta que vuela y el modo propio (sin
--      la ruta del motor), «Llévame al maestro de vuelo» y la vuelta al aterrizar;
--   5. el peligro del camino: una zona peligrosa en el camino y en el destino;
--   X. la X de las sugerencias del rastreador (pedido de Toxic): la de la ruta
--      del grupo no vuelve para ese compañero salvo con misiones nuevas (una
--      vez), su clic derecho la apaga, y en combate no toma el ratón;
--   6. misiones cercanas por color (una base de misiones de mentira);
--   10. la pausa tras 2 horas seguidas (nunca en combate ni en instancia);
--   11. Lya según tu hora (saludo, calma de noche, el cambio de rato);
--   12. los festejos (pez raro, récord, mazmorra, guía, nivel 60);
--   13. «Busco grupo»: el freno de 2 min, la tarjeta «Me apunto» y quién se apunta;
--   14. la ficha de cada lobo (pedir, contestar solo a la hermandad, la ventana);
--   15. compartir un plan (en trozos) y una guía, con «Aceptar».
-- Con BANCO_FOTOS=1 dibuja las capturas (tools/banco/shot-138m-*.png).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["138m-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.3.8 mundo", msg) end end
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
local Ru = NS_OF("Alfa_Rutas")
local Rs = Ru.Rastreador
local Mu = NS_OF("Alfa_Mundo")
local Ly = NS_OF("Alfa_Lya")
local Ma = NS_OF("Alfa_Manada")
if N.Entrando then N.Entrando = function() return false end end
if A.UI.Options.frame then A.UI.Options.frame:Hide() end

-- Lo que sale en avisos (K.Aviso) se anota para mirarlo.
local avisos = {}
local avisoReal = K.Aviso
K.Aviso = function(o) avisos[#avisos + 1] = o return avisoReal(o) end
local function ultimoAviso() return avisos[#avisos] end

---------------------------------------------------------------------------
-- 3. Toma el grifo
---------------------------------------------------------------------------

local Gf = Ru.Grifo
local destino = { label = "Matar 10 múrlocs", map = 1429, x = 20, y = 80 }
local legsVuelo = {
  { kind = "walk", seconds = 60, rest = 140, to = { name = "Villa Dorada" } },
  { kind = "fly", seconds = 110, rest = 30, stops = { { id = 90002, name = "Villa Dorada, Elwynn", short = "Villa Dorada" }, { id = 90004, name = "Colina del Centinela, Páramos de Poniente", short = "Colina del Centinela" } } },
  { kind = "walk", seconds = 30, rest = 0 },
}
local function conRuta(legs, ci, fn, extra)
  local campos = { GetTarget = function() return destino end, GetRoute = function() return legs, ci end }
  for k, v in pairs(extra or {}) do campos[k] = v end
  con(Nav, campos, function()
    -- 2400 yd a pie en línea recta: 343 s a 7 yd/s, x1,25 = 428 s
    con(A, { PlayerPoint = function() return { map = 1429, x = 50, y = 50 } end, DirectTravelCost = function() return 2400 / 7 end }, fn)
  end)
end

step("Toma el grifo: la ruta del motor ya vuela", function()
  Gf.Reiniciar()
  conRuta(legsVuelo, 1, function()
    local d, por = Gf.Calcular()
    check(d ~= nil, "con la ruta que vuela no propone el grifo: " .. tostring(por))
    if not d then return end
    check(d.nodo == "Villa Dorada", "el maestro de vuelo no es el de la ruta: " .. tostring(d.nodo))
    check(math.abs(d.ahorro - (2400 / 7 * 1.25 - 200)) < 1, "el ahorro no cuadra: " .. tostring(d.ahorro))
    local a = Gf.Aviso()
    check(a and a.titulo:find("Villa Dorada", 1, true) and a.titulo:find("ahorras", 1, true), "el aviso no dice desde dónde volar")
    check(a and type(a.cerrar) == "function", "el aviso del grifo no trae su X")
    check(a and a.uno and a.uno[1] == "Llévame al maestro de vuelo", "falta «Llévame al maestro de vuelo»")
  end)
  Gf.Olvidar()
  conRuta(legsVuelo, 2, function() check(select(2, Gf.Calcular()) == "volando", "volando se propone el grifo") end)
  Gf.Olvidar()
  -- Poco ahorro: nada.
  conRuta({ { kind = "walk", seconds = 300, rest = 100 }, { kind = "fly", seconds = 10, rest = 0, stops = { {} } } }, 1, function()
    check(select(2, Gf.Calcular()) == "noConviene", "con 28 s de ahorro se propone el grifo")
  end)
  Gf.Olvidar()
  -- Apagado.
  A.Set("rutas.tomaGrifo", false)
  conRuta(legsVuelo, 1, function() check(select(2, Gf.Calcular()) == "apagado", "rutas.tomaGrifo no lo apaga") end)
  A.Set("rutas.tomaGrifo", true)
  Gf.Olvidar()
end)

step("Toma el grifo: sin la ruta del motor, los vuelos que conoces", function()
  Gf.Reiniciar()
  A.Set("nav.travel", false)
  local puesto
  local taxi = {
    { id = 90002, c = 0, wx = 0, wy = 0, map = 1429, x = 48, y = 48, name = "Villa Dorada, Elwynn", short = "Villa Dorada" },
    { id = 90004, c = 0, wx = 2300, wy = 0, map = 1436, x = 56, y = 52, name = "Colina del Centinela, Páramos de Poniente", short = "Colina del Centinela" },
    { id = 90009, c = 0, wx = 900, wy = 0, map = 1433, x = 30, y = 58, name = "Lakeshire", short = "Lakeshire" },
  }
  local Cp = A.Compat
  con(Cp, { MapToWorld = function(map, x, y) if map == 1429 and x == 50 then return 0, 30, 0 end return 0, 2380, 0 end }, function()
    conRuta(nil, nil, function()
      local d, por = Gf.Calcular()
      check(d ~= nil and d.propio, "sin la ruta del motor no mira los vuelos que conoces: " .. tostring(por))
      if not d then return end
      check(d.nodo == "Villa Dorada" and d.hacia == "Colina del Centinela", "no eligió el vuelo cercano a ti y a tu destino")
      check(Gf.Llevar(d), "«Llévame al maestro de vuelo» falló")
      check(puesto and puesto[1] == 1429 and puesto[2] == 48, "la flecha no fue al maestro de vuelo")
      check(Gf.Vuelta() ~= nil, "no recuerda tu destino de antes")
    end, { GetKnownTaxiNodes = function() return { [90002] = true, [90004] = true } end,
      GetTravelData = function() return { taxi = taxi } end,
      SetTarget = function(map, x, y, label) puesto = { map, x, y, label } return true end })
  end)
  -- Al aterrizar: vuelve a la guía (el destino era de la guía, no manual).
  local soltada = false
  con(Nav, { ReleaseTarget = function() soltada = true end }, function()
    con(_G, { UnitOnTaxi = function() return false end }, function() Gf.Aterrizar() end)
  end)
  check(soltada and Gf.Vuelta() == nil, "al aterrizar la flecha no volvió a tu destino")
  A.Set("nav.travel", true)
  Gf.Reiniciar()
end)

---------------------------------------------------------------------------
-- 5. El peligro del camino
---------------------------------------------------------------------------

local Pg = Ru.Peligro
local NIVELES = { [1429] = { 1, 10 }, [1433] = { 15, 25 }, [1431] = { 18, 30 } }
local function conPeligro(fn)
  con(A.Maps, { GetZoneLevels = function(id) local n = NIVELES[id] if n then return n[1], n[2] end end }, function()
    con(_G, { UnitLevel = function() return 8 end }, function()
      con(C_Map, { GetBestMapForUnit = function() return 1429 end }, function()
        con(Nav, { danger = { ZoneAt = function(_, x) return x < 1000 and 1429 or (x < 2000 and 1433 or 1429) end } }, function()
          con(Nav, { GetTarget = function() return { label = "Ir", map = 1429, x = 90, y = 90 } end,
            GetRoute = function() return { { kind = "walk", from = { c = 0, wx = 0, wy = 0 }, to = { c = 0, wx = 2500, wy = 0 } } }, 1 end }, function()
            con(A, { PlayerPoint = function() return { map = 1429, x = 10, y = 10 } end }, function()
              con(A.Compat, { MapToWorld = function() return 0, 0, 0 end }, fn)
            end)
          end)
        end)
      end)
    end)
  end)
end

step("El peligro del camino: una zona peligrosa en el camino", function()
  Pg.ReiniciarCamino()
  conPeligro(function()
    local r, por = Pg.Camino()
    check(r ~= nil, "el camino pasa por una zona de nivel 15 y no lo dice: " .. tostring(por))
    if not r then return end
    check(r.zona == 1433 and not r.destino, "la zona del camino no es la peligrosa: " .. tostring(r.zona))
    local d = Pg.AvisoCamino()
    check(d and d.titulo:find("Tu camino pasa por", 1, true), "el aviso no dice «Tu camino pasa por»")
    check(d and d.texto:find("15", 1, true), "el aviso no dice el nivel de la zona")
    check(d and type(d.cerrar) == "function", "el aviso del camino no trae su X")
    d.cerrar()
    check(Pg.AvisoCamino() == nil, "cerrado, el aviso del camino vuelve")
  end)
  Pg.ReiniciarCamino()
  -- El destino en una zona peligrosa (sin camino a pie).
  NIVELES[1429] = { 1, 10 }
  con(A.Maps, { GetZoneLevels = function(id) local n = NIVELES[id] if n then return n[1], n[2] end end }, function()
    con(_G, { UnitLevel = function() return 8 end }, function()
      con(C_Map, { GetBestMapForUnit = function() return 1429 end }, function()
        con(Nav, { GetTarget = function() return { label = "Ir", map = 1431, x = 50, y = 50 } end, GetRoute = function() return nil end }, function()
          con(A, { PlayerPoint = function() return nil end }, function()
            local r = Pg.Camino()
            check(r and r.destino and r.zona == 1431, "el destino en una zona peligrosa no se dice")
            local d = Pg.AvisoCamino()
            check(d and d.titulo:find("Tu destino está en", 1, true), "el aviso del destino no dice «Tu destino está en»")
          end)
        end)
      end)
    end)
  end)
  -- Apagado.
  A.Set("rutas.peligroCamino", false)
  Pg.ReiniciarCamino()
  conPeligro(function() check(select(2, Pg.Camino()) == "apagado", "rutas.peligroCamino no lo apaga") end)
  A.Set("rutas.peligroCamino", true)
  Pg.ReiniciarCamino()
end)

---------------------------------------------------------------------------
-- X. La X de las sugerencias del rastreador
---------------------------------------------------------------------------

local RG = Ru.RutaGrupo
local queLleva = {}
step("La X: la tarjeta del grupo se cierra y no vuelve para ese compañero", function()
  RG.Reiniciar()
  Rs.OlvidarCerradas()
  local lleva = { { nombre = "Yuki", completo = "Yuki Smith", ids = { 11, 12, 13, 14 } } }
  con(RG, { QueLleva = function() return lleva end }, function()
    con(_G, { IsInGroup = function() return true end, IsInRaid = function() return false end }, function()
      local d = RG.Aviso()
      check(d and d.titulo:find("Yuki", 1, true), "sin la tarjeta de la ruta del grupo (¿enGrupo?)")
      if not d then return end
      check(type(d.cerrar) == "function", "la tarjeta del grupo no trae su X")
      check(type(d.menu) == "table" and d.menu[1] and d.menu[1].texto == "No sugerir rutas de mi grupo", "su clic derecho no ofrece «No sugerir rutas de mi grupo»")
      -- El rastreador la pinta con su X, sin encimar el título.
      Rs.Plegar(false)
      Rs.Mostrar()
      con(Ru.Grupo, { Aviso = function() return RG.Aviso() end }, function()
        RUN_TIMERS(3)
        Rs.Pintar()
        local F = rawget(_G, "AlfaRastreador")
        local b
        for _, h in ipairs({ F:GetChildren() }) do if rawget(h, "Cerrar") and rawget(h, "Uno") then b = h end end
        check(b and b:IsShown(), "el rastreador no pinta la tarjeta")
        if not b then return end
        check(b.Cerrar:IsShown(), "la tarjeta no muestra la X")
        local tl = b.Titulo:GetLeft() + b.Titulo:GetWidth()
        check(tl <= b.Cerrar:GetLeft() + 0.5, ("el título se encima con la X: %.1f > %.1f"):format(tl, b.Cerrar:GetLeft()))
        check(b.Cerrar:IsMouseEnabled(), "fuera de combate la X no toma el clic")
        SNAP("rastreador-x", F)
        -- En combate no atrapa clics.
        con(_G, { InCombatLockdown = function() return true end }, function()
          FIRE_EVENT("PLAYER_REGEN_DISABLED")
          check(not b.Cerrar:IsMouseEnabled() and not b:IsMouseEnabled(), "en combate la X o la tarjeta toman el ratón")
          Rs.Pintar()
          check(not b.Cerrar:IsMouseEnabled(), "en combate, al repintar, la X toma el ratón")
        end)
        FIRE_EVENT("PLAYER_REGEN_ENABLED")
        Rs.Pintar()
        -- Clic en la X: se va.
        FIRE(b.Cerrar, "OnClick", "LeftButton")
        RUN_TIMERS(2)
        check(RG.Aviso() == nil, "cerrada, la tarjeta de Yuki vuelve")
      end)
      -- Con una misión nueva no vuelve; con dos, sí (una vez).
      lleva[1].ids = { 11, 12, 13, 14, 15 }
      check(RG.Aviso() == nil, "con una sola misión nueva la tarjeta vuelve")
      lleva[1].ids = { 11, 12, 13, 14, 15, 16 }
      local d2 = RG.Aviso()
      check(d2 ~= nil, "con dos misiones nuevas la tarjeta no vuelve")
      if d2 then d2.cerrar() end
      lleva[1].ids = { 11, 12, 13, 14, 15, 16, 17, 18, 19 }
      check(RG.Aviso() == nil, "la tarjeta volvió más de una vez")
      -- Otro compañero sí sale.
      lleva[2] = { nombre = "Ana", completo = "Ana Smith", ids = { 30 } }
      local d3 = RG.Aviso()
      check(d3 and d3.titulo:find("Ana", 1, true), "cerrar la de Yuki calló la de otro compañero")
      -- «No sugerir rutas de mi grupo» la apaga (y su ajuste la prende).
      d3.menu[1].valor()
      check(A.Get("rutas.sugerirRutaGrupo") == false and RG.Aviso() == nil, "«No sugerir rutas de mi grupo» no la apaga")
      A.Set("rutas.sugerirRutaGrupo", true)
      check(RG.Aviso() ~= nil, "el ajuste no la vuelve a prender")
    end)
  end)
  RG.Reiniciar()
  -- Las demás sugerencias también traen su X (Rs.Sugerencia) y se callan en la sesión.
  local d = Rs.Sugerencia({ titulo = "Vuelta a entregar", uno = { "Empezar", function() end } })
  check(d and type(d.cerrar) == "function", "una sugerencia sin X")
  d.cerrar()
  check(Rs.Sugerencia({ titulo = "Otra", uno = { "Empezar", function() end } }) == false, "cerrada, la sugerencia vuelve en la sesión")
  Rs.OlvidarCerradas()
end)

---------------------------------------------------------------------------
-- 6. Misiones cercanas por color
---------------------------------------------------------------------------

local Mc2 = Mu.MisionesColor
step("Misiones por color: los colores y la capa", function()
  check(Mc2.Color(20, 20) == "buena" and Mc2.Color(23, 20) == "dificil" and Mc2.Color(25, 20) == "peligrosa"
    and Mc2.Color(17, 20) == "facil" and Mc2.Color(12, 20) == nil, "los colores por nivel no son los del juego")
  local F = { TITLE = 1, LEVEL = 2, MIN = 3, START = 7, HOLIDAY = 16 }
  local Q = {
    F = F, IsLoaded = function() return true end, QuestIds = function() return { 1, 2, 3, 4, 5 } end,
    QuestRecord = function(q) return ({ [1] = { "A", 20, 18, nil, nil, nil, 101 }, [2] = { "B", 24, 20, nil, nil, nil, 102 },
      [3] = { "C", 26, 22, nil, nil, nil, 103 }, [4] = { "D", 17, 14, nil, nil, nil, 104 }, [5] = { "E", 10, 5, nil, nil, nil, 105 } })[q] end,
    Each = function(v) if type(v) == "table" then return ipairs(v) end return ipairs({ v }) end,
    EachSpawn = function(ref, fn, a, b) fn(a, b, 1433, nil, 10 + ref % 100 * 10, 50) return 1 end,
    IsEligible = function() return true end,
    CheckAvailable = function(q, ctx) return q ~= 3 or ctx.level >= 22 end,
    PlayerContext = function(_, ctx) ctx.level = 20 return ctx end,
    GetQuestTitle = function(q) return "Misión " .. q end,
    GreyLevel = function(n) return n - 5 - math.floor(n / 10) end,
    Load = function() return true end,
  }
  con(A, { QuestDB = Q }, function()
    con(Mu.Descubrir, { Zona = function() return 1433 end }, function()
      con(_G, { UnitLevel = function() return 20 end }, function()
        Mc2.Olvidar()
        Mc2.Login()
        check(Mc2.Preparar(), "no se preparó la capa")
        RUN_TIMERS(5)
        check(Mc2.Listo(), "el índice de misiones no se armó")
        local l = Mc2.Lista(1433, 20)
        local colores = {}
        for _, e in ipairs(l) do colores[e.q] = e.color end
        check(colores[1] == "buena" and colores[2] == "dificil" and colores[4] == "facil", "los colores de las misiones no cuadran")
        check(colores[3] == nil, "salió una misión que todavía no puedes tomar")
        check(colores[5] == nil, "salió una misión gris")
        local pines = Mc2.Pines(1433)
        check(#pines == 3 and pines[1].color == Mc2.COLORES.dificil, "los pines no van de la más difícil a la más fácil")
        Mc2.Refrescar()
        local capa = A.Pins.GetLayer and A.Pins.GetLayer("mundo.misionesColor")
        check(type(capa) == "table" and #capa == 3, "la capa no se publicó en Alfa.Pins")
        A.Set("mundo.misionesColor", false)
        Mc2.Refrescar()
        local vacia = A.Pins.GetLayer("mundo.misionesColor")
        check(not vacia or #vacia == 0, "apagada, la capa sigue en el mapa")
        A.Set("mundo.misionesColor", true)
      end)
    end)
  end)
  check(Mu.Capas.PorId("misiones.color") ~= nil, "la capa no está en el control de capas")
  Mc2.Olvidar()
end)

---------------------------------------------------------------------------
-- 10. La pausa
---------------------------------------------------------------------------

local Pa = Ly.Pausa
local Ce = Ly.Cerebro
local dicho
local function conLya(fn)
  con(Ce, { Decir = function(c) dicho = c return true end }, fn)
end

step("La pausa: a las 2 horas seguidas, una vez por tramo", function()
  Pa.Reiniciar()
  local reloj = 1700000000
  con(_G, { GetServerTime = function() return reloj end }, function()
    conLya(function()
      Pa.NuevoTramo(reloj)
      dicho = nil
      check(not Pa.Revisar() and dicho == nil, "a los 0 min sugiere la pausa")
      reloj = reloj + 2 * 3600 + 5
      con(_G, { InCombatLockdown = function() return true end }, function()
        check(not Pa.Revisar(), "en combate sugiere la pausa")
      end)
      con(_G, { IsInInstance = function() return true, "party" end }, function()
        check(not Pa.Revisar(), "en una mazmorra sugiere la pausa")
      end)
      check(Pa.Revisar() and dicho and dicho.texto:find("2 h", 1, true), "a las 2 horas no sugiere la pausa: " .. tostring(dicho and dicho.texto))
      check(dicho and dicho.acciones and dicho.acciones[1].texto == "Recuérdamelo en 30 min", "falta «Recuérdamelo en 30 min»")
      dicho = nil
      check(not Pa.Revisar(), "la pausa se sugiere dos veces en el mismo tramo")
      -- «En 30 min»: a los 30 minutos otra vez.
      local Pe = dicho
      reloj = reloj + 60
      Pa.Tramo().otraVez = reloj + 1800
      reloj = reloj + 1801
      check(Pa.Revisar(), "«Recuérdamelo en 30 min» no la recuerda")
      -- Ausente 10 min: tramo nuevo.
      local antes = Pa.Tramo().desde
      con(_G, { UnitIsAFK = function() return true end }, function() check(not Pa.Revisar(), "ausente sugiere la pausa") end)
      reloj = reloj + 700
      Pa.Observar()
      check(Pa.Tramo().desde > antes, "tras 10 min ausente no empieza un tramo nuevo")
      -- Apagado.
      A.Set("lya.pausa", false)
      reloj = reloj + 3 * 3600
      check(not Pa.Revisar(), "lya.pausa no la apaga")
      A.Set("lya.pausa", true)
    end)
  end)
end)

---------------------------------------------------------------------------
-- 11. Lya según tu hora
---------------------------------------------------------------------------

local Hr = Ly.HoraReal
step("Lya según tu hora: saludos, calma de noche y el cambio de rato", function()
  local hora = 23
  con(_G, { date = function(f) if f == "%H" then return tostring(hora) end return "2026-11-23" end }, function()
    check(Hr.Rato() == "noche" and Hr.Tranquila(), "a las 23 no está tranquila")
    check(Hr.Espera(180) > 180, "de noche platica igual de seguido")
    check(Hr.Llegada() == "llegadaNoche", "de noche no saluda de noche")
    local p = Hr.Pose()
    check(p == "sentada" or p == "estirarse", "de noche corre o se busca la cola: " .. tostring(p))
    hora = 9
    check(not Hr.Tranquila() and Hr.Espera(180) == 180 and Hr.Llegada() == "llegadaManana" and Hr.Pose() == nil, "de mañana sigue tranquila")
    hora = 3
    check(Hr.Llegada() == "llegadaMadrugada", "de madrugada no saluda bajito")
    -- Las frases existen y llevan el nombre.
    for _, cat in ipairs({ "llegadaManana", "llegadaNoche", "llegadaMadrugada", "saludoMadrugada" }) do
      local lista = Ly.FRASES[cat]
      check(type(lista) == "table" and #lista >= 2 and lista[1]:find("%s", 1, true), "faltan las frases " .. cat)
    end
    -- El cambio de rato, una vez al día.
    conLya(function()
      hora = 18
      Hr.Reiniciar(nil)
      dicho = nil
      check(not Hr.Revisar(), "al entrar dice el cambio de rato")
      hora = 20
      check(Hr.Revisar() and dicho and dicho.texto:find("noche", 1, true), "al caer la noche no lo dice")
      Hr.Reiniciar("tarde")
      dicho = nil
      check(not Hr.Revisar(), "la noche se dice dos veces el mismo día")
    end)
    A.Set("lya.horaReal", false)
    hora = 23
    check(not Hr.Tranquila() and Hr.Llegada() == nil, "lya.horaReal no lo apaga")
    A.Set("lya.horaReal", true)
  end)
end)

---------------------------------------------------------------------------
-- 12. Los festejos
---------------------------------------------------------------------------

local Fe = Ly.Festejos
local Di = Ly.Diario
step("Los festejos: pez raro, récord, mazmorra, guía y nivel 60", function()
  Di.Empezar()
  local p = N.DatosPersonaje("pesca")
  p.vida = { mejorRacha = 5, mejorValor = 100, mejorHora = 0 }
  p.logros = {}
  p.diario = { [6292] = { n = 1, primera = 100, nombre = "Pargo de Ventormenta" } }
  N.DatosPersonaje("lya").festejos = nil
  check(not Fe.Revisar(), "la primera vez festeja lo que ya tenías")
  p.logros.trofeo = 1700000000
  p.diario[6363] = { n = 1, primera = 200, nombre = "Trucha cabeza de mithril" }
  Fe.Revisar()
  check(Di.Tiene("pezRaro"), "el primer pez raro no queda en tu historia")
  local e = Di.Lista()[1]
  check(e and Di.Titulo(e):find("Trucha cabeza de mithril", 1, true), "la página no dice qué pez fue")
  p.vida.mejorRacha = 6
  Fe.Revisar()
  check(Di.Tiene("recordPesca"), "el primer récord de pesca no se festeja")
  check(Fe.Mazmorra({ nombre = "Las Minas de la Muerte" }) and Di.Tiene("mazmorraFin"), "la primera mazmorra terminada no se festeja")
  check(not Fe.Mazmorra({ nombre = "Otra" }), "la segunda mazmorra también se festeja")
  con(_G, { AlfaRuta = { NombreGuia = function() return "Elwynn 1-10" end } }, function()
    check(Fe.Guia("elwynn") and Di.Tiene("guia"), "la primera guía completa no se festeja")
  end)
  local anuncio
  con(K, { Anuncio = function(o) anuncio = o end }, function()
    check(not Fe.Nivel(59), "el nivel 59 sale como el 60")
    check(Fe.Nivel(60) and anuncio and anuncio.titulo == "¡Nivel 60!", "el nivel 60 no sale con su anuncio")
    anuncio = nil
    check(not Fe.Nivel(60) and anuncio == nil, "el anuncio del 60 sale dos veces")
  end)
end)

---------------------------------------------------------------------------
-- 13. Busco grupo
---------------------------------------------------------------------------

local Tb = Ma.Tablon
local Red = Ma.Red
local enviados = {}
local function conRed(fn)
  con(Red, { EnviarHermandad = function(clave, texto) enviados[#enviados + 1] = { clave = clave, texto = texto, canal = "GUILD" } return true end,
    EnviarLibre = function(clave, texto, destino) enviados[#enviados + 1] = { clave = clave, texto = texto, destino = destino } return true end }, fn)
end

step("Busco grupo: el freno, la tarjeta y quién se apunta", function()
  Tb.Olvidar()
  Tb.Quitar()
  enviados = {}
  conRed(function()
    con(Ma.U, { EnHermandad = function() return true end }, function()
      check(AlfaManada.BuscoGrupo("Las Minas de la Muerte", "m"), "«Busco grupo» no puso el anuncio")
      check(enviados[1] and enviados[1].texto:find("Las Minas de la Muerte", 1, true), "el anuncio no salió a la hermandad")
      local ok, por = Tb.Poner("m", "Otra cosa")
      check(not ok and por == "espera", "dos anuncios seguidos pasan el freno de 2 minutos")
      NOW = NOW + 121
      check(Tb.Poner("q", "La Hermandad Defias"), "a los 2 minutos no se puede poner otro")
      -- Llega el de otro lobo: la tarjeta con «Me apunto».
      avisos = {}
      Red.Oyentes.b("ana smith", "Ana Smith", "hermandad", { "q", "24", "5", "Hogger" }, "GUILD")
      local a = ultimoAviso()
      check(a and a.titulo:find("Ana Smith", 1, true) and a.accion and a.accion.texto == "Me apunto", "no salió la tarjeta con «Me apunto»")
      -- El mismo anuncio repetido no trae otra tarjeta.
      local n = #avisos
      NOW = NOW + 10
      Red.Oyentes.b("ana smith", "Ana Smith", "hermandad", { "q", "24", "15", "Hogger" }, "GUILD")
      check(#avisos == n, "el mismo anuncio repetido trae otra tarjeta")
      -- «Me apunto»: un susurro oculto a Ana, nada al chat.
      enviados = {}
      a.accion.alClic()
      check(enviados[1] and enviados[1].destino == "Ana Smith" and enviados[1].texto == "1b|s", "«Me apunto» no le avisa a Ana")
      -- A ti te llega quién se apunta, con «Invitar».
      avisos = {}
      -- (1.3.8 revisión: solo de tu hermandad; prueba_138_revision.lua prueba a un extraño)
      con(Ma.Ficha, { DeMiHermandad = function(n) return n == "Yuki" end }, function()
        Red.Oyentes.b("yuki", "Yuki", "susurro", { "s" }, "WHISPER")
        local b = ultimoAviso()
        check(b and b.titulo:find("Yuki", 1, true) and b.accion and b.accion.texto == "Invitar", "no te llega quién se apunta")
        Red.Oyentes.b("yuki", "Yuki", "susurro", { "s" }, "WHISPER")
        check(#avisos == 1, "el mismo lobo se apunta dos veces al mismo anuncio")
      end)
      -- Apagado: sin tarjeta.
      A.Set("manada.tablonAviso", false)
      avisos = {}
      Red.Oyentes.b("leo", "Leo", "hermandad", { "m", "30", "1", "Zul'Farrak" }, "GUILD")
      check(#avisos == 0, "manada.tablonAviso no apaga la tarjeta")
      A.Set("manada.tablonAviso", true)
    end)
  end)
  Tb.Quitar()
  Tb.Olvidar()
  -- El menú de la misión en el rastreador lo ofrece para las de élite.
  check(Rs.DeGrupo({ party = { kind = "elite" } }) and not Rs.DeGrupo({ quest = 5 }), "Rs.DeGrupo no reconoce una meta de élite")
end)

---------------------------------------------------------------------------
-- 14. La ficha
---------------------------------------------------------------------------

local Fi = Ma.Ficha
step("La ficha: pedirla, contestar solo a la hermandad y la ventana", function()
  Fi.Olvidar()
  enviados = {}
  conRed(function()
    -- Contestar: a alguien que no es de tu hermandad ni de tu grupo, nada.
    con(Ma.U, { EnHermandad = function() return true end, EnMiGrupo = function() return false end }, function()
      con(_G, { GetNumGuildMembers = function() return 1 end, GetGuildRosterInfo = function() return "Ana Smith" end }, function()
        Red.Oyentes.h("leo", "Leo", "susurro", { "?" }, "WHISPER")
        check(#enviados == 0, "le contestó su ficha a alguien de fuera")
        Red.Oyentes.h("ana smith", "Ana Smith", "susurro", { "?" }, "WHISPER")
        check(enviados[1] and enviados[1].destino == "Ana Smith" and enviados[1].texto:match("^1h|f|%d+|"), "no le contestó su ficha a alguien de la hermandad")
        A.Set("manada.ficha", false)
        enviados = {}
        NOW = NOW + 60
        Red.Oyentes.h("ana smith", "Ana Smith", "susurro", { "?" }, "WHISPER")
        check(#enviados == 0, "manada.ficha no la apaga")
        A.Set("manada.ficha", true)
      end)
    end)
    -- Pedir y recibir.
    enviados = {}
    local f = { clave = "yuki", nombre = "Yuki", envio = "Yuki", nivel = 34, clase = "WARRIOR", map = 1436 }
    check(Fi.Abrir(f), "la ficha no se abre")
    check(enviados[1] and enviados[1].texto == "1h|?", "abrirla no le pregunta a su Alfa")
    local t = Fi.Texto(f)
    check(t.cabeza:find("34", 1, true) and t.estado ~= nil, "mientras espera no dice lo que ya sabe ni que pregunta")
    -- Una respuesta sin pedirla no cuenta; la pedida, sí.
    Red.Oyentes.h("otro", "Otro", "susurro", { "f", "20", "MAGE", "197:150:225", "" }, "WHISPER")
    check(Fi.De("otro") == nil, "aceptó una ficha que no pidió")
    con(C_Item or {}, { GetItemNameByID = function(id) return id == 2575 and "Camisa roja de lino" or nil end }, function()
      Red.Oyentes.h("yuki", "Yuki", "susurro", { "f", "34", "WARRIOR", "164:210:225,186:180:225", "2575,9999" }, "WHISPER")
      local x = Fi.De("yuki")
      check(x and #x.oficios == 2 and x.oficios[1].r == 210, "la ficha no trae sus oficios")
      t = Fi.Texto(f)
      check(t.oficios and t.oficios:find("210 de 225", 1, true), "la ficha no dice la habilidad: " .. tostring(t.oficios))
      check(t.objetos and t.objetos:find("Camisa roja de lino", 1, true) and t.objetos:find("1 más", 1, true), "la ficha no dice lo que fabrica")
      Fi.Pintar()
      SNAP("ficha", Fi.Ventana())
    end)
    -- Basura: no rompe.
    Red.Oyentes.h("yuki", "Yuki", "susurro", { "f", "x", "1nv", "164:abc", "|" }, "WHISPER")
    Fi.Ventana():Cerrar()
  end)
  Fi.Olvidar()
end)

---------------------------------------------------------------------------
-- 15. Compartir un plan o una guía
---------------------------------------------------------------------------

local Co = Ma.Compartir
step("Compartir: un plan en trozos y una guía, con «Aceptar»", function()
  Co.Olvidar()
  local metas = {
    { tipo = "objeto", item = 2589, cantidad = 20, nombre = "Paño de lino" },
    { tipo = "oro", cobre = 100000 },
    { tipo = "lugar", modo = "punto", mapa = 1429, x = 41.5, y = 65.2, nombre = "Villadorada; | & = raro" },
    { tipo = "mision", quest = 176, verbo = "turnin", titulo = "Se busca: Hogger" },
    { tipo = "nota", texto = string.rep("Una nota larga. ", 20) },
  }
  for i = 1, 14 do metas[#metas + 1] = { tipo = "nivel", nivel = 10 + i } end
  local texto = Co.Codificar("Mi plan | de prueba", metas)
  check(not texto:find("|", 1, true), "el plan codificado lleva «|»")
  local nombre, de = Co.Decodificar(texto)
  check(nombre == "Mi plan de prueba" or nombre == "Mi plan   de prueba" or nombre:find("Mi plan", 1, true), "el nombre del plan no vuelve")
  check(#de == #metas and de[1].item == 2589 and de[3].x == 41.5 and de[4].quest == 176, "las metas no vuelven iguales")
  -- Enviar: en trozos, por susurro.
  enviados = {}
  local recibido
  conRed(function()
    con(_G, { AlfaPlanes = { Activo = function() return { id = "p1", nombre = "Mi plan", metas = metas } end,
      Recibir = function(n, m) recibido = { n, m } return { id = "p2", nombre = n, metas = m } end, Seguir = function() end } }, function()
      local f = { clave = "ana smith", nombre = "Ana", envio = "Ana Smith" }
      check(Co.Plan(f), "no compartió el plan")
      check(#enviados >= 2, "un plan largo no sale en trozos (" .. #enviados .. ")")
      local ok2, por = Co.Plan(f)
      check(not ok2 and por == "espera", "compartir dos veces seguidas pasa el freno")
      -- Del otro lado: los trozos en desorden y la tarjeta con «Aceptar».
      avisos = {}
      con(Ma.U, { EnMiGrupo = function() return true end }, function()
        for i = #enviados, 1, -1 do
          local campos = {}
          for c in (enviados[i].texto:gsub("^1r|", "") .. "|"):gmatch("([^|]*)|") do campos[#campos + 1] = c end
          Red.Oyentes.r("toxic", "Toxic", "susurro", campos, "WHISPER")
        end
        local a = ultimoAviso()
        check(a and a.titulo:find("Toxic", 1, true) and a.accion and a.accion.texto == "Aceptar", "no llegó la tarjeta del plan")
        if a then a.accion.alClic() end
        check(recibido and #recibido[2] == #metas, "«Aceptar» no guardó el plan con sus metas")
        -- Una guía.
        con(_G, { AlfaRuta = { GuiaActual = function() return { id = "elwynn-1", nombre = "Elwynn" } end,
          NombreGuia = function() return "Elwynn" end, SeguirGuia = function(id) recibido = id return true end } }, function()
          enviados = {}
          check(Co.Guia(f) and enviados[1].texto:match("^1r|g|elwynn%-1|"), "no compartió la guía")
          NOW = NOW + 61
          avisos = {}
          Red.Oyentes.r("leo", "Leo", "susurro", { "g", "elwynn-1", "3" }, "WHISPER")
          local g = ultimoAviso()
          check(g and g.accion and g.accion.texto == "Aceptar", "no llegó la tarjeta de la guía")
          if g then g.accion.alClic() end
          check(recibido == "elwynn-1", "«Aceptar» no abrió la guía")
        end)
      end)
      -- De alguien de fuera: nada.
      avisos = {}
      con(Ma.U, { EnMiGrupo = function() return false end, EnHermandad = function() return false end }, function()
        Red.Oyentes.r("extrano", "Extraño", "susurro", { "g", "elwynn-1", "3" }, "WHISPER")
      end)
      check(#avisos == 0, "aceptó una guía de alguien de fuera")
    end)
  end)
  Co.Olvidar()
end)

---------------------------------------------------------------------------
-- Las fotos (BANCO_FOTOS=1): el rastreador con el grifo y con el peligro,
-- las tarjetas de la manada y el globo de Lya con la pausa.
---------------------------------------------------------------------------
K.Aviso = avisoReal
if FOTOS then
  step("Fotos", function()
    Gf.Reiniciar()
    Pg.ReiniciarCamino()
    Rs.OlvidarCerradas()
    local F = rawget(_G, "AlfaRastreador")
    con(Ru.Grupo, { Aviso = function() return nil end }, function()
      con(Ru.Vuelta, { Aviso = function() return nil end, Estado = function() return nil end }, function()
        conRuta(legsVuelo, 1, function()
          con(Pg, { AvisoCamino = function() return nil end }, function()
            Rs.Pintar()
            SNAP("rastreador-grifo", F)
          end)
        end)
        con(Gf, { Aviso = function() return nil end }, function()
          conPeligro(function()
            Rs.Pintar()
            SNAP("rastreador-peligro", F)
          end)
        end)
      end)
    end)
    local function tarjeta(nombre, o)
      local fr = K.Aviso(setmetatable({ lya = false, pedido = true }, { __index = o }))
      if type(fr) == "table" and fr.GetObjectType then SNAP(nombre, fr) end
    end
    tarjeta("busco-grupo", { icono = "ic-manada", tono = "acento", titulo = "Ana Smith busca grupo: Misión", texto = "«Hogger» · nivel 24",
      accion = { texto = "Me apunto", alClic = function() end }, acciones = { { texto = "Susurrar", alClic = function() end } } })
    tarjeta("se-apunta", { icono = "ic-manada", tono = "exito", titulo = "Yuki se apunta", texto = "A tu anuncio: «Las Minas de la Muerte, falta sanador».",
      accion = { texto = "Invitar", alClic = function() end }, acciones = { { texto = "Susurrar", alClic = function() end } } })
    tarjeta("plan-compartido", { icono = "ic-lista", tono = "acento", titulo = "Toxic te comparte su plan", texto = "«Mi plan»: 19 metas.",
      accion = { texto = "Aceptar", alClic = function() end } })
    -- La pausa en el globo de Lya.
    local UI = Ly.UI
    Ce.Mostrar(true)
    RUN_TIMERS(1)
    Ce.Decir({ texto = "Llevas 2 h seguidas de cacería, lobo. ¿Una pausa? Estírate, toma agua y aquí te espero.", pedido = true,
      lineas = 4, ancho = 340, acciones = { { texto = "Recuérdamelo en 30 min", fn = function() end } } })
    local f = UI.Frame and UI.Frame()
    local g = rawget(_G, "AlfaLyaGlobo")
    if g and g:IsShown() then SNAP("lya-pausa", g, f and { f } or nil) end
  end)
end
print(("prueba_138_mundo: %d pasos"):format(pasos))
