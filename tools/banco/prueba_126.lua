-- Prueba de la 1.2.6 (tools/prueba.py la corre con las demás prueba_*.lua):
--   * los avisos de Hoy (también los de al entrar) los dice Lya, con sus botones;
--   * la letra de Lya viene grande y se cambia (lya.letra);
--   * «Desbloquear» recuerda de qué guía venías y te regresa;
--   * Lya vuelve a avisar de las misiones listas cuando la cuenta baja y sube.
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
local function check(cond, msg) if not cond then NOTE("1.2.6", msg) end end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local Ly = NS_OF("Alfa_Lya")

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

step("Los avisos de Hoy los dice Lya, con sus botones", function()
  local Av = NS_OF("Alfa_Inicio").Aviso
  local cerrado = false
  conLya(function()
    Av.Mostrar({ clave = "bienvenida", tipo = "info", titulo = "Bienvenido de vuelta", linea = "Tu guía te espera.",
      texto = "Sigue donde te quedaste.", botones = { { texto = "Seguir", fn = function() end }, { texto = "Después", fn = function() end } },
      alCerrar = function() cerrado = true end })
  end)
  local d = dichos[#dichos]
  check(d and d.texto:find("Bienvenido de vuelta", 1, true) and d.texto:find("Tu guía te espera", 1, true), "Lya no dijo el aviso de Hoy")
  check(d and d.acciones and #d.acciones == 2 and d.acciones[1].texto == "Seguir", "los botones del aviso no pasaron a Lya")
  check(cerrado, "el aviso que dijo Lya no avisó que se cerró")
  check(not (_G.AlfaInicioAviso and _G.AlfaInicioAviso:IsShown()), "además salió el aviso de Hoy")
  -- El mismo aviso otra vez, enseguida: no se repite.
  local n = #dichos
  conLya(function()
    Av.Mostrar({ clave = "bienvenida", tipo = "info", titulo = "Bienvenido de vuelta", linea = "Tu guía te espera.",
      texto = "Sigue donde te quedaste.", botones = {} })
  end)
  check(#dichos == n, "Lya repitió el mismo aviso enseguida")
end)

step("La letra de Lya: grande y a tu gusto", function()
  check(A.Get("lya.letra") == "grande", "la letra de Lya no viene en grande: " .. tostring(A.Get("lya.letra")))
  check(K.TIPO.globoGrande and K.TIPO.globoEnorme, "faltan los tamaños del globo en la escala del Kit")
  A.Set("lya.letra", "enorme")
  Ly.UI.Hablar({ texto = "Prueba de letra" })
  local g = _G.AlfaLyaGlobo
  if g and g.Texto then check(g.Texto.alfaRol == "globoEnorme", "el globo no usó la letra muy grande") end
  A.Set("lya.letra", "grande")
end)

step("Desbloquear te regresa a tu guía", function()
  local Ru = NS_OF("Alfa_Rutas")
  local G = Ru.Guias
  check(G.RecordarVuelta and G.Volver, "faltan RecordarVuelta y Volver")
  local E = A.Engine
  local gg = E.GetGuide
  E.GetGuide = function() return { id = "Alfa/bosque-del-ocaso" } end
  G.RecordarVuelta()
  E.GetGuide = function() return { id = G.IdEspecial("desbloquear") } end
  G.RecordarVuelta() -- (desde el propio «Desbloquear» no se pisa)
  E.GetGuide = gg
  check(Ru.Personaje().vuelta == "Alfa/bosque-del-ocaso", "no recordó la guía de la que venías")
  local abierta
  local ab = G.Abrir
  G.Abrir = function(id) abierta = id return 1 end
  check(G.Volver() and abierta == "Alfa/bosque-del-ocaso", "no te regresó a tu guía")
  check(Ru.Personaje().vuelta == nil, "la vuelta se quedó guardada")
  G.Abrir = ab
end)

step("Hoy y el rastreador dicen lo mismo de una guía sin paso", function()
  local R = AlfaRuta
  check(type(R.FinGuia) == "function", "falta AlfaRuta.FinGuia")
end)

step("Lo que dijo Lya y la tecla de su botón", function()
  local Ce, UI = Ly.Cerebro, Ly.UI
  check(type(Ce.historial) == "table", "falta el historial de Lya")
  local n0 = #Ce.historial
  local activa, visible = Ce.Activa, UI.Visible
  Ce.Activa = function() return true end
  UI.Visible = function() return true end
  local hecho = false
  Ce.Decir({ texto = "Prueba del historial", pedido = true, acciones = { { texto = "Hazlo", fn = function() hecho = true end } } })
  Ce.Activa, UI.Visible = activa, visible
  check(Ce.historial[1] and Ce.historial[1].texto == "Prueba del historial", "lo que dijo no quedó en el historial")
  check(#Ce.historial <= 20, "el historial pasa de 20")
  check(type(AlfaLya.Responder) == "function", "falta AlfaLya.Responder (la tecla de su botón)")
  local hablando = UI.Hablando
  UI.Hablando = function() return true end
  AlfaLya.Responder()
  UI.Hablando = hablando
  if _G.AlfaLyaGlobo then check(hecho, "la tecla no hizo lo del botón del globo") end
end)

step("Llamar a la manada", function()
  local MN = NS_OF("Alfa_Manada")
  local Ll, R = MN.Llamado, MN.Red
  check(Ll and Ll.Llamar, "falta Llamado.lua")
  A.Set("manada.compartir", true)
  R.Escuchar()
  local via = R.Via
  R.Via = function() return "hermandad" end
  local salidos = {}
  local envio = C_ChatInfo.SendAddonMessage
  C_ChatInfo.SendAddonMessage = function(_, t, c, d) salidos[#salidos + 1] = { (t:gsub("|~[HA]$", "")), c, d } end
  local ok = Ll.Llamar()
  for _ = 1, 60 do FIRE(R.motor, "OnUpdate", 0.2) end
  local a
  for _, m in ipairs(salidos) do if m[1]:find("^1A|") then a = m[1] end end
  check(ok and a, "no llamó a la manada")
  check(not Ll.Llamar(), "dejó llamar otra vez enseguida")
  -- Llega un llamado de otro lobo de tu zona: aviso con «¡Voy!».
  local avisos = {}
  local av = K.Aviso
  K.Aviso = function(o) avisos[#avisos + 1] = o end
  local map = AlfaNucleo.A.Compat.GetPlayerMapPosition()
  FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", "1A|" .. tostring(map) .. "|45.00|55.00|Mor'Ladim|~H", "GUILD", "Ana Smith")
  check(avisos[1] and avisos[1].accion and avisos[1].accion.texto == "¡Voy!" and avisos[1].texto:find("Mor'Ladim", 1, true), "no llegó el llamado con «¡Voy!»")
  if avisos[1] and avisos[1].accion then avisos[1].accion.alClic() end
  for _ = 1, 60 do FIRE(R.motor, "OnUpdate", 0.2) end
  local b = false
  for _, m in ipairs(salidos) do if m[1] == "1B" and m[2] == "WHISPER" then b = true end end
  check(b, "«¡Voy!» no le avisó a quien llamó")
  local tgt = A.Nav and A.Nav.GetTarget and A.Nav.GetTarget()
  check(tgt and math.abs((tgt.x or 0) - 45) < 0.01, "la flecha no apunta a donde llamaron (0-100)")
  FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", "1B|~H", "WHISPER", "Beto Ruiz")
  check(avisos[#avisos] and avisos[#avisos].titulo:find("Beto Ruiz", 1, true), "no te avisó quién va en camino")
  K.Aviso = av
  C_ChatInfo.SendAddonMessage = envio
  R.Via = via
  A.Set("manada.compartir", false)
end)

step("Tu semana y tu récord", function()
  local Di = Ly.Dia
  check(Di.Semana and Di.Record and Di.ContarSemana, "faltan Semana, Record o ContarSemana")
  local d = AlfaNucleo.DatosPersonaje("lya")
  d.record = { misiones = 2, fecha = "2000-01-01" }
  local h = Di.Hoy()
  h.misiones, h.recordDicho = 4, nil
  local dichos = {}
  local decir = Ly.Cerebro.Decir
  Ly.Cerebro.Decir = function(c) dichos[#dichos + 1] = c return true end
  FIRE_EVENT("QUEST_TURNED_IN", 902, 10, 0)
  Ly.Cerebro.Decir = decir
  check(d.record.misiones == 5, "no guardó el récord nuevo")
  check(dichos[1] and dichos[1].texto:find("récord", 1, true), "Lya no dijo el récord nuevo")
  local s = Di.Semana()
  check(s.misiones >= 5, "la semana no suma el día de hoy")
end)

step("Seguir no se suelta al llegar", function()
  local Nav = A.Nav
  local t = Nav.SetTarget(1429, 40, 40, "Ana")
  local trip = Nav.StartTrip(t, "Ana", "La Jauría", "follow")
  check(trip and trip.ends == "follow", "el viaje no quedó como «follow»")
  A.Fire("NAV_ARRIVED", t)
  RUN_TIMERS(2)
  check(Nav.Trip() ~= nil, "el viaje de seguir se cayó")
  Nav.ReleaseTarget()
end)

print(string.format("PRUEBA: 1.2.6 Lya dice los avisos y el seguimiento, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
