-- Prueba de la 1.3.7, los arreglos de la revisión independiente (29 hallazgos;
-- tools/prueba.py la corre con las demás prueba_*.lua). Un paso por arreglo
-- que se puede ver en el banco; los demás se revisan en el juego.
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
local function check(cond, msg) if not cond then NOTE("1.3.7 revisión", msg) end end
local function con(t, campos, fn)
  local viejos = {}
  for k, v in pairs(campos) do viejos[k] = rawget(t, k) rawset(t, k, v) end
  local ok, e = pcall(fn)
  for k in pairs(campos) do rawset(t, k, viejos[k]) end
  if not ok then error(e, 0) end
end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(5)

local N = AlfaNucleo
local A = N.A
local K = N.Kit
local Z = N.Zonas
if N.Entrando then N.Entrando = function() return false end end
A.Set("bienvenida.anuncios", true)

local function correr(seg, dt)
  dt = dt or 0.05
  local t = 0
  while t < seg do
    NOW = NOW + dt
    local f = rawget(_G, "AlfaAnuncio")
    if f and f:IsShown() then FIRE(f, "OnUpdate", dt) end
    t = t + dt
  end
end
local function limpiar()
  K.QuitarAnuncio()
  NOW = NOW + 10
  if Z and Z.Olvidar then Z.Olvidar() end
  RUN_TIMERS(2)
end

---------------------------------------------------------------------------
-- Núcleo y avisos
---------------------------------------------------------------------------
step("1: una película que acaba sin STOP_MOVIE no congela la cola", function()
  local mf = CreateFrame("Frame", nil, UIParent)
  rawset(_G, "MovieFrame", mf)
  mf:Show()
  FIRE_EVENT("PLAY_MOVIE", 1)
  check(N.EnCinematica(), "con la película a la vista no cuenta como cinemática")
  mf:Hide()
  NOW = NOW + 2
  check(not N.EnCinematica(), "la película se cerró sola y Alfa sigue esperando")
  rawset(_G, "MovieFrame", nil)
end)

step("2-3: el nombre del juego se esconde cuando sale el de Alfa", function()
  limpiar()
  local szt = rawget(_G, "SubZoneTextFrame")
  if not (type(szt) == "table" and type(szt.Show) == "function") then
    rawset(_G, "SubZoneTextFrame", nil)
    szt = CreateFrame("Frame", "SubZoneTextFrame", UIParent)
  end
  local salio = 0
  K.Anuncio({ estilo = "zona", titulo = "Durotar", ya = true, alMostrar = function() salio = salio + 1 end })
  check(salio == 1, "alMostrar no se llamó al salir el anuncio")
  szt:Show()
  Z.TaparRincon()
  check(not szt:IsShown(), "con la zona de Alfa a la vista, el rincón del juego salió encima")
  limpiar()
  szt:Show()
  NOW = NOW + 30
  Z.TaparRincon()
  check(szt:IsShown(), "sin anuncio de Alfa se escondió el rincón del juego")
  szt:Hide()
end)

step("4: lo que espera la calma no deja la cola corriendo", function()
  limpiar()
  N.Calma("30")
  local corrio = false
  local r = N.AlLibre("revision.calma", function() corrio = true end, 3, { tipo = "lya" })
  check(r == "espera", "con calma, lo de Lya no esperó")
  N.BombearMomentos()
  check(not N.HayTarea("nucleo.momentos"), "la cola sigue corriendo cada 0,25 s solo por la calma")
  N.Calma("no")
  RUN_TIMERS(3)
  check(corrio, "al acabar la calma no salió lo que esperaba")
end)

step("5: en combate los avisos no atrapan clics", function()
  limpiar()
  local a = K.Aviso({ titulo = "Un aviso", texto = "Para probar", lya = false, pedido = true,
    accion = { texto = "Ver", alClic = function() end } })
  check(type(a) == "table", "no salió el aviso")
  if type(a) ~= "table" then return end
  local icl = InCombatLockdown
  InCombatLockdown = function() return true end
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not a:IsMouseEnabled(), "en combate el aviso atrapa clics")
  check(not (a.Boton and a.Boton:IsMouseEnabled()), "en combate su botón atrapa clics")
  InCombatLockdown = icl
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  check(a:IsMouseEnabled(), "al salir de combate el aviso no volvió a tomar el ratón")
  a:Cerrar()
end)

step("6: el ratón encima no basta para «lo pediste»", function()
  local v = CreateFrame("Frame", nil, UIParent)
  v:Show()
  v.IsMouseOver = function() return true end
  K.VENTANAS = K.VENTANAS or {}
  table.insert(K.VENTANAS, v)
  check(not N.PidioJugador(), "con el ratón encima, sin clic, contó como pedido")
  N.ClicEnAlfa()
  check(N.PidioJugador(), "un clic en la ventana de Alfa no contó como pedido")
  NOW = NOW + 1
  check(not N.PidioJugador(), "un clic de hace 1 s sigue contando como pedido")
  for i, x in ipairs(K.VENTANAS) do if x == v then table.remove(K.VENTANAS, i) break end end
  v:Hide()
end)

step("7: con la bitácora llena no se anota que actuó", function()
  local d = os and os.getenv and os.getenv("ALFA_DIST")
  local f = io and io.open and io.open((d or "dist") .. "/Alfa/Core/Automation.lua", "rb")
  if not f then return end
  local s = f:read("*a")
  f:close()
  local i = s:find("ns.LogFullHold(q)", 1, true)
  local j = i and s:find("noteActed()", i, true)
  local k = i and s:sub(1, i):find("noteActed%(%)%s*\r?\n%s*if ns.LogFullHold")
  check(i and j and not k, "LogFullHold no va antes de noteActed()")
end)

step("8: bajo la placa de llegada solo si cabe arriba", function()
  limpiar()
  local Ar = A.Nav and A.Nav.arrow
  if not (Ar and Ar.PlacaMarco) then return end
  local real = Ar.PlacaMarco
  local p = CreateFrame("Frame", nil, UIParent)
  p:SetSize(264, 80) p:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 60) p:Show()
  Ar.PlacaMarco = function() return p end
  K.Anuncio({ estilo = "zona", titulo = "Mulgore", ya = true })
  RUN_TIMERS(6)
  correr(0.2)
  local a = K.AnuncioActual()
  check(not (a and a.bajoPlaca), "con la flecha abajo, el anuncio se fue bajo la placa (fuera de la pantalla)")
  Ar.PlacaMarco = real
  p:Hide()
  limpiar()
end)

step("9: tipo apagado o calma: ni tarjeta ni sonido; grandes apagados: tarjeta", function()
  local ns = NS_OF("Alfa")
  local An = ns.Nav and ns.Nav.alerts and ns.Nav.alerts.Anuncio
  if type(An) ~= "function" then return end
  A.Set("anuncios.barco", false)
  check(An("El barco", "Llega en %s", 30, "boat") == "nada", "con el barco apagado iba a salir la tarjeta")
  A.Set("anuncios.barco", nil)
  N.Calma("30")
  check(An("El barco", "Llega en %s", 30, "boat") == "nada", "con No molestar iba a salir la tarjeta")
  N.Calma("no")
  A.Set("bienvenida.anuncios", false)
  check(An("El barco", "Llega en %s", 30, "boat") == false, "con los grandes apagados no sale la tarjeta")
  A.Set("bienvenida.anuncios", true)
  limpiar()
end)

step("10: el modo ligero no apaga los anuncios", function()
  con(N, { Ligero = function() return true end }, function()
    check(N.AnunciosGrandes(), "con el modo ligero no sale ningún anuncio")
  end)
end)

---------------------------------------------------------------------------
-- Aventura
---------------------------------------------------------------------------
local Mz = NS_OF("Alfa_Mazmorras")

step("12: «You won: X» es tuyo, no de «You»", function()
  local Hb = Mz.Historial
  if not Hb then return end
  rawset(_G, "LOOT_ROLL_WON", "%s won: %s")
  rawset(_G, "LOOT_ROLL_YOU_WON", "You won: %s")
  rawset(_G, "LOOT_ITEM", "%s receives loot: %s.")
  rawset(_G, "LOOT_ITEM_SELF", "You receive loot: %s.")
  local link = "|cff0070dd|Hitem:4242::::::::|h[Espada]|h|r"
  local r = Hb.Leer("You won: " .. link)
  check(r and r.tipo == "gane", "«You won» se leyó como de otro: " .. tostring(r and r.tipo) .. " / " .. tostring(r and r.quien))
  local r2 = Hb.Leer("Ana won: " .. link)
  check(r2 and r2.tipo == "gano" and r2.quien == "Ana", "«Ana won» ya no se lee")
end)

step("13: tras reiniciar la instancia, vuelta nueva", function()
  local Cr = Mz.Crono
  if not (Cr and Cr.Empezar) then return end
  local v1 = Cr.Empezar("revision")
  local v2 = Cr.Empezar("revision")
  check(v1 == v2, "volver enseguida empezó otra vuelta")
  v1.visto = v1.visto - 100
  N.Datos("mazmorras").reinicio = v1.visto + 50
  local v3 = Cr.Empezar("revision")
  check(v3 ~= v1, "con la instancia reiniciada siguió la vuelta vieja")
  N.Datos("mazmorras").reinicio = nil
  N.DatosPersonaje("mazmorras").vuelta = nil
end)

step("18: el patrón aguanta los códigos del coreano", function()
  local D = Mz.D
  local p = D.Patron("%s|1이;가; 전리품을 획득했습니다: %s")
  check(p and ("Ana가 전리품을 획득했습니다: X"):find(p), "el patrón coreano no reconoce el texto: " .. tostring(p))
end)

step("15: Dentro() fuera de una instancia no carga nada", function()
  if not (AlfaMazmorras and AlfaMazmorras.Dentro) then return end
  local cargo = false
  con(Mz.D, { Listo = function() cargo = true return false end }, function()
    check(AlfaMazmorras.Dentro() == nil, "fuera de una instancia Dentro() dio algo")
  end)
  check(not cargo, "fuera de una instancia Dentro() preguntó por el Codex")
end)

step("16: el tiempo jugado no suma lo desconectado", function()
  local J = NS_OF("Alfa_Inicio").Jugado
  if not J then return end
  N.DatosPersonaje("inicio").jugado = { total = 1000, nivel = 100, en = (time and time() or 0) - 7200, lv = UnitLevel("player") }
  local d = J.Datos()
  check(d and d.total == 1000, "sumó el tiempo de otra sesión: " .. tostring(d and d.total))
  -- En plena pelea se pide al terminarla.
  local pidio = false
  con(_G, { RequestTimePlayed = function() pidio = true end, InCombatLockdown = function() return true end }, function()
    check(not J.Pedir(), "pidió el tiempo jugado en plena pelea")
  end)
  con(_G, { RequestTimePlayed = function() pidio = true end }, function()
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    RUN_TIMERS(1)
  end)
  check(pidio, "al terminar la pelea no volvió a pedir el tiempo jugado")
  FIRE_EVENT("TIME_PLAYED_MSG", 2000, 50)
  RUN_TIMERS(1)
  local d2 = J.Datos()
  check(d2 and d2.total >= 2000, "la medida de esta sesión no quedó")
end)

---------------------------------------------------------------------------
-- Personaje y oficios
---------------------------------------------------------------------------
step("20: la comida de clásico cuenta (la de Inicio)", function()
  local Li = NS_OF("Alfa_Curacion").Listos
  if not (Li and Li.Comida) then return end
  con(_G, { AlfaInicio = { Comida = function() return 7, 3 end } }, function()
    local n = Li.Comida()
    check(n and n >= 10, "no cuenta la comida y el agua de Inicio: " .. tostring(n))
  end)
end)

step("22: «Ver su equipo» no abre la inspección del juego", function()
  local In = NS_OF("Alfa_Builds").Inspeccion
  if not (In and In.Ver) then return end
  local abrio, pidio = false, false
  con(_G, { InspectUnit = function() abrio = true end, NotifyInspect = function() pidio = true end,
    UnitIsPlayer = function() return true end, CanInspect = function() return true end }, function()
    In.Ver("party1")
  end)
  check(not abrio, "el menú de Alfa llamó a InspectUnit")
  check(pidio, "no le pidió su equipo al juego (NotifyInspect)")
end)

step("25: cancelar la cuenta no quita otro anuncio", function()
  limpiar()
  local Cu = NS_OF("Alfa_Combate").Cuenta
  if not (Cu and Cu.Empieza) then return end
  con(NS_OF("Alfa_Combate"), { Opt = function() return true end }, function()
    Cu.Empieza(2, "Grom")
  end)
  correr(6)
  RUN_TIMERS(3)
  K.Anuncio({ estilo = "raro", titulo = "Thuros", ya = true })
  local a = K.AnuncioActual()
  check(a and a.titulo == "Thuros", "no salió el raro de prueba")
  Cu.Cancela()
  a = K.AnuncioActual()
  check(a and a.titulo == "Thuros", "cancelar la cuenta (ya terminada) quitó otro anuncio")
  limpiar()
end)

step("26: una lectura secreta no es «se acabó»", function()
  local E = NS_OF("Alfa_Combate").Efectos
  if not (E and E.Leer) then return end
  local viejo = issecretvalue
  issecretvalue = function(v) return v == "secreto" end
  con(C_UnitAuras, { GetAuraDataByIndex = function(_, i) if i == 1 then return { spellId = "secreto", icon = 1, duration = 5, expirationTime = 10 } end end }, function()
    local l = E.Leer("target", "HARMFUL|PLAYER")
    check(l.secretos, "la lectura secreta no quedó marcada")
  end)
  issecretvalue = viejo
end)

step("29: quien dirige la banda conserva la pestaña del juego", function()
  local Cm = NS_OF("Alfa_Curacion")
  if not Cm.Diriges then return end
  con(_G, { UnitIsGroupLeader = function() return true end }, function()
    check(Cm.Diriges(), "el jefe de la banda no cuenta como quien dirige")
  end)
  con(_G, { UnitIsGroupLeader = function() return false end, UnitIsGroupAssistant = function() return false end }, function()
    check(not Cm.Diriges(), "sin mando cuenta como quien dirige")
  end)
end)

print(("PRUEBA: 1.3.7 revisión, %d pasos, %d errores"):format(pasos, #ERRORS))
