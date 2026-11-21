-- Prueba de la 1.2.7, Lya (tools/prueba.py la corre con las demás prueba_*.lua):
--   * en una mazmorra: un consejo con «Ver la mazmorra», una vez por entrada,
--     y Cerebro solo habla en una instancia con c.enMazmorra (nunca en combate);
--   * su ánimo: tres caídas en 10 min la sientan a consolarte; dos niveles en
--     30 min, un aullido de más;
--   * la salchicha: la pide a su hora, «Darle una salchicha» la cuenta una vez;
--   * antes de irte: las misiones listas o la despedida, aunque solo diga lo importante;
--   * el globo compacto: una sola línea, con sus botones.
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
local function check(cond, msg) if not cond then NOTE("1.2.7 Lya", msg) end end

local A = AlfaNucleo.A
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local Ly = NS_OF("Alfa_Lya")
local Mo = Ly.Momentos

-- Lya a la vista, y lo que dice.
local dichos = {}
local function conLya(fn)
  local Ce, UI = Ly.Cerebro, Ly.UI
  local activa, visible, decir = Ce.Activa, UI.Visible, Ce.Decir
  Ce.Activa = function() return true end
  UI.Visible = function() return true end
  Ce.Decir = function(c) dichos[#dichos + 1] = c return true end
  local ok, e = pcall(fn)
  Ce.Activa, UI.Visible, Ce.Decir = activa, visible, decir
  if not ok then error(e) end
end
local function ultimo() return dichos[#dichos] end

step("Momentos.lua está cargado", function()
  check(type(Mo) == "table" and Mo.Mazmorra and Mo.AlMorir and Mo.AlSubir and Mo.Minuto and Mo.DarSalchicha and Mo.Despedida,
    "falta Momentos.lua o sus funciones")
  check(A.Get("lya.mazmorras") == true, "lya.mazmorras no viene prendido")
  check(A.Get("lya.compacto") == false, "lya.compacto no viene apagado")
end)

step("Cerebro habla en una instancia solo con enMazmorra, y nunca en combate", function()
  local Ce, UI = Ly.Cerebro, Ly.UI
  local activa, visible = Ce.Activa, UI.Visible
  local ii, icl = IsInInstance, InCombatLockdown
  Ce.Activa = function() return true end
  UI.Visible = function() return true end
  IsInInstance = function() return true, "party" end
  local r1, p1 = Ce.Decir({ texto = "Prueba en la mazmorra", pedido = true })
  local r2 = Ce.Decir({ texto = "Prueba en la mazmorra", pedido = true, enMazmorra = true })
  InCombatLockdown = function() return true end
  local r3 = Ce.Decir({ texto = "Prueba en la mazmorra", pedido = true, enMazmorra = true })
  IsInInstance, InCombatLockdown = ii, icl
  Ce.Activa, UI.Visible = activa, visible
  Ly.UI.Callar(true)
  check(r1 == false and p1 == "esperar", "Lya habló en una instancia sin enMazmorra")
  check(r2 == true, "con enMazmorra Lya no habló en la instancia")
  check(r3 ~= true, "con enMazmorra Lya habló en combate")
end)

step("En una mazmorra: un consejo con «Ver la mazmorra», una vez por entrada", function()
  local ii, gi = IsInInstance, GetInstanceInfo
  IsInInstance = function() return true, "party" end
  GetInstanceInfo = function() return "Minas de la Muerte", "party", 1, "Normal", 5, 0, false, 36 end
  local n = #dichos
  conLya(function() Mo.Mazmorra() end)
  local c = ultimo()
  check(#dichos == n + 1 and c.enMazmorra == true, "Lya no dio su consejo al entrar a la mazmorra")
  check(c and c.acciones and c.acciones[1] and c.acciones[1].texto == "Ver la mazmorra", "falta «Ver la mazmorra»")
  check(c and type(c.texto) == "string" and c.texto ~= "" and not c.texto:find("%s", 1, true), "el consejo salió vacío o sin nombre")
  conLya(function() Mo.Mazmorra() end)
  check(#dichos == n + 1, "Lya repitió el consejo de la misma mazmorra")
  GetInstanceInfo = function() return "Cavernas de Brazanegra", "party", 1, "Normal", 5, 0, false, 48 end
  conLya(function() Mo.Mazmorra() end)
  check(#dichos == n + 2, "en otra mazmorra Lya no dio su consejo")
  -- Una banda no es una mazmorra de grupo; apagado, nada.
  IsInInstance = function() return true, "raid" end
  GetInstanceInfo = function() return "Núcleo de Magma", "raid", 1, "Normal", 40, 0, false, 409 end
  conLya(function() Mo.Mazmorra() end)
  IsInInstance = function() return true, "party" end
  A.Set("lya.mazmorras", false)
  GetInstanceInfo = function() return "Uldaman", "party", 1, "Normal", 5, 0, false, 70 end
  conLya(function() Mo.Mazmorra() end)
  A.Set("lya.mazmorras", true)
  check(#dichos == n + 2, "Lya habló en una banda o con lya.mazmorras apagado")
  IsInInstance, GetInstanceInfo = ii, gi
end)

step("Tres caídas en 10 minutos: se sienta a consolarte", function()
  NOW = NOW + 5000
  local n = #dichos
  conLya(function()
    check(Mo.AlMorir() == false, "consoló a la primera caída")
    NOW = NOW + 60
    check(Mo.AlMorir() == false, "consoló a la segunda caída")
    NOW = NOW + 60
    check(Mo.AlMorir() == true, "no notó tres caídas en 10 minutos")
    RUN_TIMERS(2)
  end)
  local consuelo
  for i = n + 1, #dichos do if dichos[i].pose == "sentada" then consuelo = dichos[i] end end
  check(consuelo and consuelo.importante, "Lya no se sentó a consolarte")
  conLya(function()
    NOW = NOW + 60
    check(Mo.AlMorir() == false, "volvió a consolar antes de 10 minutos")
  end)
end)

-- 1.3.7: el festejo de racha reemplaza al aullido de siempre (antes se sumaba).
step("Dos niveles en 30 minutos: el festejo de racha en vez del aullido de siempre", function()
  NOW = NOW + 5000
  local n = #dichos
  conLya(function()
    FIRE_EVENT("PLAYER_LEVEL_UP", 24)
    RUN_TIMERS(3)
    NOW = NOW + 600
    FIRE_EVENT("PLAYER_LEVEL_UP", 25)
    RUN_TIMERS(3)
  end)
  local racha, del25 = nil, 0
  for i = n + 1, #dichos do
    if type(dichos[i].texto) == "string" and dichos[i].texto:find("25", 1, true) then
      del25 = del25 + 1
      if dichos[i].aullar then racha = dichos[i] end
    end
  end
  check(racha, "Lya no aulló por la racha de niveles")
  check(del25 == 1, "con la racha salieron " .. del25 .. " frases del nivel 25 (el festejo debe reemplazar al aullido)")
  NOW = NOW + 5000
  check(Mo.AlSubir(26) == false, "la racha siguió sin dos niveles nuevos")
end)

step("La salchicha: la pide a su hora y la cuenta una vez", function()
  local d = AlfaNucleo.DatosPersonaje("lya")
  d.salchichas, d.salchichaFaltan, d.silencio = nil, 1, nil
  local pidio
  conLya(function() pidio = Mo.Minuto() end)
  local c = ultimo()
  check(pidio and c and c.pose == "pedir", "Lya no pidió su salchicha con la pose de pedir")
  check(c and c.acciones and c.acciones[1].texto == "Darle una salchicha", "falta «Darle una salchicha»")
  local f = tonumber(d.salchichaFaltan) or 0
  check(f >= 45 and f <= 90, "la siguiente salchicha no quedó entre 45 y 90 minutos: " .. tostring(d.salchichaFaltan))
  conLya(function() c.acciones[1].fn() end)
  check(Mo.Salchichas() == 1, "no contó la salchicha")
  check(ultimo().texto:find("primera", 1, true), "no agradeció su primera salchicha")
  conLya(function() c.acciones[1].fn() end) -- el mismo botón otra vez (el historial)
  check(Mo.Salchichas() == 1, "el mismo botón contó dos salchichas")
  conLya(function() for _ = 1, 9 do Mo.DarSalchicha() end end)
  check(Mo.Salchichas() == 10, "no llegó a 10 salchichas")
  check(ultimo().texto:find("10", 1, true), "en la décima no dijo cuántas van")
  -- En combate no pide.
  d.salchichaFaltan = 1
  local icl = InCombatLockdown
  InCombatLockdown = function() return true end
  conLya(function() pidio = Mo.Minuto() end)
  InCombatLockdown = icl
  check(not pidio, "Lya pidió su salchicha en combate")
  d.salchichaFaltan = 60
end)

step("Antes de irte: lo pendiente o la despedida, aunque solo diga lo importante", function()
  local R = AlfaRuta
  local listas = R and R.Listas
  A.Set("lya.frecuencia", "importantes")
  NOW = NOW + 100
  if R then R.Listas = function() return 2 end end
  conLya(function() FIRE_EVENT("PLAYER_CAMPING") end)
  local c = ultimo()
  if R then check(c and c.importante and c.texto:find("2", 1, true), "al acampar no dijo las 2 misiones listas") end
  NOW = NOW + 100
  if R then R.Listas = function() return 0 end end
  local n = #dichos
  conLya(function() FIRE_EVENT("PLAYER_QUITING") end)
  check(#dichos == n + 1 and ultimo().importante, "al salir Lya no se despidió")
  check(ultimo().enMazmorra == true, "la despedida no sale dentro de una instancia")
  n = #dichos
  conLya(function() FIRE_EVENT("PLAYER_CAMPING") end)
  check(#dichos == n, "se despidió dos veces seguidas")
  if R then R.Listas = listas end
  A.Set("lya.frecuencia", "muchos")
end)

step("El globo compacto: una sola línea, con sus botones", function()
  A.Set("lya.compacto", true)
  conLya(function() Ly.UI.Aplicar() end)
  Ly.UI.Hablar({ texto = "Una frase larga, larga, larguísima, para ver que el globo compacto la deja en una sola línea con sus tres puntos.",
    acciones = { { texto = "Uno", fn = function() end }, { texto = "Dos", fn = function() end } } })
  local g = _G.AlfaLyaGlobo
  if g and g.Texto then
    check(g.Texto._max == 1 and g.Texto._wrap == false, "el globo compacto no quedó en una sola línea")
    check(g.B1:IsShown() and g.B2:IsShown(), "el globo compacto perdió sus botones")
  end
  A.Set("lya.compacto", false)
  Ly.UI.Hablar({ texto = "Otra vez normal." })
  if g and g.Texto then check(g.Texto._wrap == true and (g.Texto._max or 0) >= 3, "el globo normal no volvió a sus líneas") end
  Ly.UI.Callar(true)
end)

print(string.format("PRUEBA: 1.2.7 Lya en mazmorras, su ánimo, la salchicha y la despedida, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
