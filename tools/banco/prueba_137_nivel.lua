-- Prueba de la 1.3.7: subir de nivel sin ventanas encimadas (Alfa_Nucleo/Momentos.lua;
-- tools/prueba.py la corre con las demás prueba_*.lua). Pedido de Toxic: «cuando subí
-- de nivel aparecieron algunas ventanas, algunas se encimaron y no me dejó presionar».
-- Con la animación del juego simulada (un LevelUpDisplay a la vista unos segundos):
--   * nada de Alfa sale antes de que termine la animación y pase 1 s (17, 33, 39);
--   * los recálculos del nivel (N.TrasNivel) esperan y se escalonan (37, 38);
--   * un solo resumen de nivel con el talento y lo que hay que aprender, y dos botones (18, 34);
--   * nunca dos cosas a la vez, y ningún velo que tape la pantalla (19, 20, 40);
--   * el talento y el entrenador, una sola vez (55, 56);
--   * sin el estandarte del juego, se espera unos 4 s.
SNAPSHOTS = {}
BANCO_MOMENTOS = true -- los momentos de verdad (las escenas viejas no esperan al juego)
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
local function check(cond, msg) if not cond then NOTE("1.3.7 nivel", msg) end end

local A, N, K = Alfa, AlfaNucleo, AlfaNucleo.Kit
local Ly = NS_OF("Alfa_Lya")

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(8)

-- Lo que sale a la vista, con su momento (NOW).
local salidas = {}
local function anota(tipo, txt) salidas[#salidas + 1] = { tipo = tipo, t = NOW, txt = tostring(txt or "") } end
A.On("ALFA_AVISO", function(o) anota("aviso", (o and o.titulo or "") .. " | " .. (o and o.texto or "")) end)
if Ly.UI and Ly.UI.Hablar then
  local h = Ly.UI.Hablar
  Ly.UI.Hablar = function(c) anota("lya", c and c.texto) return h(c) end
end
if K.Anuncio then
  local an = K.Anuncio
  K.Anuncio = function(o) local r = an(o) if r then anota("anuncio", o and o.titulo) end return r end
end
local dialogos = {}
local dlg = K.Dialogo
K.Dialogo = function(o) dialogos[#dialogos + 1] = { titulo = o and o.titulo, t = NOW } return dlg(o) end

-- Lya a la vista y activa.
local Ce, UI = Ly.Cerebro, Ly.UI
if Ce then Ce.Activa = function() return true end end
if UI then UI.Visible = function() return true end end

-- Un punto de talento y una habilidad nueva para aprender en el nivel 24.
AlfaBuilds = AlfaBuilds or {}
AlfaBuilds.SiguienteTalento = function() return { ahora = true, libres = 1, nombre = "Golpe heroico", porque = "prueba" } end
A.QoL = A.QoL or {}
A.QoL.Spells = A.QoL.Spells or {}
local newAt = A.QoL.Spells.NewAt
A.QoL.Spells.NewAt = function(l) if l == 24 then return { { id = 1 } } end return {} end

-- Un recálculo pesado de prueba (como los de Rutas, Mazmorras, Talentos...).
local recalculos = {}
for i = 1, 5 do
  A.RegisterEvent("PLAYER_LEVEL_UP", N.TrasNivel("prueba" .. i, function() recalculos[#recalculos + 1] = NOW end))
end

-- La animación de nivel del juego (el estandarte).
local LUD = CreateFrame("Frame", "LevelUpDisplay", UIParent)
LUD:SetAlpha(1)
LUD:Hide()

local function nadaAntes(hasta, que)
  for _, s in ipairs(salidas) do
    if s.t < hasta then check(false, que .. ": salió «" .. s.txt:sub(1, 70) .. "» (" .. s.tipo .. ") antes de tiempo") end
  end
end
local function nuncaJuntos()
  local porT = {}
  for _, s in ipairs(salidas) do
    if porT[s.t] then check(false, "salieron dos cosas a la vez: «" .. porT[s.t]:sub(1, 50) .. "» y «" .. s.txt:sub(1, 50) .. "»") end
    porT[s.t] = s.txt
  end
end
local function hay(patron)
  for _, s in ipairs(salidas) do if s.txt:find(patron, 1, true) then return s end end
end
local function cuantos(patron)
  local n = 0
  for _, s in ipairs(salidas) do if s.txt:find(patron, 1, true) then n = n + 1 end end
  return n
end

---------------------------------------------------------------------------
step("El contrato: N.Ocupado, N.AlLibre, N.TrasNivel, N.PRIORIDAD", function()
  check(type(N.Ocupado) == "function" and type(N.AlLibre) == "function" and type(N.TrasNivel) == "function", "falta el contrato de los momentos")
  check(N.PRIORIDAD and N.PRIORIDAD.urgente == 1 and N.PRIORIDAD.detalle == 4, "faltan las cuatro prioridades")
  check(N.MomentosActivos(), "con BANCO_MOMENTOS los momentos deberían estar activos")
  check(not N.Ocupado("aviso"), "sin nada del juego, Alfa no debería estar ocupada: " .. tostring((select(2, N.Ocupado("aviso")))))
  -- Libre: corre ya.
  local corrio = false
  check(N.AlLibre("prueba.ya", function() corrio = true end, 3) == true and corrio, "N.AlLibre no corrió al momento estando libre")
end)

step("Subir de nivel con la animación del juego: nada antes de tiempo", function()
  salidas, recalculos, dialogos = {}, {}, {}
  local inicio = NOW
  LUD:Show()
  FIRE_EVENT("PLAYER_LEVEL_UP", 24)
  check(N.Ocupado("aviso") and select(2, N.Ocupado("aviso")) == "nivel", "subiendo de nivel, Alfa no se dio por ocupada")
  -- Mientras el juego hace su animación, algo que Alfa quiera decir espera.
  local a = K.Aviso({ titulo = "Un aviso cualquiera", texto = "de prueba", lya = false })
  check(a == nil, "un aviso salió encima de la animación del juego")
  -- Un diálogo que nadie pidió no pone el velo: sale como aviso (cuando se pueda).
  local d = K.Dialogo({ titulo = "¿Usar tu hechizo nuevo?", texto = "prueba", aceptar = "Usarlo", cancelar = "Ahora no" })
  check(d == nil, "un diálogo sin clic se abrió con su velo durante la animación")
  for _ = 1, 3 do RUN_TIMERS(1) end
  local velo = rawget(_G, "AlfaKitVelo")
  check(not (velo and velo:IsShown()), "hay un velo que tapa la pantalla al subir de nivel")
  nadaAntes(math.huge, "durante la animación")
  check(#recalculos == 0, "los recálculos del nivel corrieron durante la animación")
  -- Se va el estandarte del juego.
  LUD:Hide()
  local fin = NOW
  for _ = 1, 25 do RUN_TIMERS(1) end
  nadaAntes(fin + 1, "tras la animación (1 s de margen)")
  nuncaJuntos()
  check(#recalculos == 5, "corrieron " .. #recalculos .. " de 5 recálculos del nivel")
  if #recalculos >= 2 then check(recalculos[1] ~= recalculos[#recalculos], "los recálculos del nivel no se escalonaron") end
  for _, t in ipairs(recalculos) do check(t >= fin, "un recálculo corrió antes de que terminara la animación") end
  -- Un solo resumen de nivel con todo.
  local r = hay("¡Nivel 24!")
  check(r, "no salió el resumen de nivel")
  check(cuantos("¡Nivel 24!") == 1, "el resumen de nivel salió más de una vez")
  check(r and r.txt:find("punto de talento", 1, true), "el resumen no dice el punto de talento")
  check(r and r.txt:find("habilidad", 1, true), "el resumen no dice lo que hay que aprender")
  local u = N.UltimoResumenNivel
  check(u and u.nivel == 24 and #u.partes >= 2, "el resumen no guardó sus partes")
  check(not hay("Tienes un punto de talento"), "el talento salió aparte del resumen")
  check(N.YaDicho("talento:24") and N.YaDicho("entrenador:24"), "el resumen no anotó su voz (talento y entrenador)")
  check(hay("Un aviso cualquiera"), "el aviso que esperaba no salió después")
  check(hay("¿Usar tu hechizo nuevo?"), "el diálogo sin clic no salió como aviso")
  local velo2 = rawget(_G, "AlfaKitVelo")
  check(not (velo2 and velo2:IsShown()), "quedó un velo a la vista")
  for _, v in ipairs(K.VelosSinClic or {}) do
    if v.t >= inicio then check(false, "un velo salió sin un clic: " .. tostring(v.titulo)) end
  end
  -- 58: lo importante dice qué hacer.
  for _, t in ipairs(K.AvisosSinQueHacer or {}) do
    if t:find("Nivel", 1, true) then check(false, "el resumen de nivel no trae qué hacer") end
  end
end)

step("El entrenador, una vez por nivel", function()
  local B = NS_OF("Alfa_Builds")
  check(N.YaDicho("entrenador:24"), "el resumen no anotó al entrenador")
  -- Hoy no lo repite (Inicio/Recordatorios.lua): la voz ya está anotada.
  local antes = #salidas
  A.Fire("TRAIN_DUE", 24, nil)
  RUN_TIMERS(3)
  for i = antes + 1, #salidas do
    check(not salidas[i].txt:find("habilidades nuevas", 1, true), "Hoy repitió lo del entrenador en el mismo nivel")
  end
end)

step("Sin el estandarte del juego: unos 4 s de espera", function()
  RUN_TIMERS(10)
  salidas = {}
  local inicio = NOW
  FIRE_EVENT("PLAYER_LEVEL_UP", 25)
  local a = K.Aviso({ titulo = "Otro aviso", lya = false })
  check(a == nil, "sin estandarte, un aviso salió al instante de subir de nivel")
  for _ = 1, 20 do RUN_TIMERS(1) end
  nadaAntes(inicio + 4, "sin estandarte")
  check(hay("Otro aviso"), "el aviso no salió después de la espera (esperan " .. N.EnEspera() .. " / pesado " .. N.EnEspera("pesado")
    .. ", bomba " .. tostring(N.HayTarea("nucleo.momentos")) .. ", ocupado: " .. tostring((select(2, N.Ocupado("aviso")))) .. ")")
  nuncaJuntos()
end)

step("Lo urgente no espera a que se haga lugar; lo demás hace fila", function()
  RUN_TIMERS(30)
  local a1 = K.Aviso({ titulo = "Fila 1", lya = false, duracion = 30 })
  local a2 = K.Aviso({ titulo = "Fila 2", lya = false, duracion = 30 })
  local a3 = K.Aviso({ titulo = "Fila 3", lya = false, duracion = 30 })
  check(a1 and a2 and a3, "tres avisos seguidos no salieron (caben tres)")
  local a4 = K.Aviso({ titulo = "Fila 4", lya = false })
  check(a4 == nil, "el cuarto aviso no esperó su turno")
  local u = K.Aviso({ titulo = "Urgente", lya = false, prioridad = "urgente" })
  check(type(u) == "table", "lo urgente esperó")
  for _, x in ipairs({ a1, a2, a3, u }) do if type(x) == "table" and x.Cerrar then x:Cerrar() end end
  RUN_TIMERS(3)
  check(not N.Esperando("aviso:Fila 4|"), "el cuarto aviso se quedó esperando con lugar libre")
end)

A.QoL.Spells.NewAt = newAt
print("PRUEBA: 1.3.7 subir de nivel sin ventanas encimadas, " .. pasos .. " pasos, " .. #ERRORS .. " errores")
