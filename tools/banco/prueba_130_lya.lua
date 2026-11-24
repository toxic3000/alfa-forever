-- Prueba de la 1.3.0, Lya y Mundo (tools/prueba.py la corre con las demás prueba_*.lua):
--   * Mundo: los peligros de tu zona (élites y raros del Codex contra tu
--     nivel, capa mundo.peligros) y el modo explorador (rincones descubiertos
--     de cada zona, en la página);
--   * Lya: las Lyas del grupo se saludan y platican (prefijo AlfaLya, solo al
--     grupo, poquito); tus misiones en su voz (dos líneas); tu mascota; los
--     retos de la semana (con su salchicha); los cumpleaños (el tuyo y el de
--     Alfa, una vez al año).
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
local function check(cond, msg) if not cond then NOTE("1.3.0 Lya", msg) end end

local A = AlfaNucleo.A
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local Ly = NS_OF("Alfa_Lya")
local Mn = NS_OF("Alfa_Mundo")
local Gr, Sv, Ma, Re, Cu = Ly.EnGrupo, Ly.SuVoz, Ly.Mascota, Ly.Retos, Ly.Cumple
local Pe, Ds = Mn.Peligros, Mn.Descubrir
local datos = function() return AlfaNucleo.DatosPersonaje("lya") end

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
local function dijo(patron, desde)
  for i = (desde or 0) + 1, #dichos do
    local t = dichos[i].texto
    if type(t) == "string" and t:find(patron, 1, true) then return dichos[i] end
  end
  return nil
end

step("Los archivos nuevos están cargados y sus ajustes, prendidos", function()
  check(type(Gr) == "table" and Gr.Mensaje and Gr.Platicar, "falta EnGrupo.lua")
  check(type(Sv) == "table" and Sv.Resumen, "falta SuVoz.lua")
  check(type(Ma) == "table" and Ma.Revisar, "falta Mascota.lua")
  check(type(Re) == "table" and Re.Lista and Re.Revisar, "falta Retos.lua")
  check(type(Cu) == "table" and Cu.Festejar, "falta Cumple.lua")
  check(type(Pe) == "table" and Pe.Refrescar, "falta Alfa_Mundo/Peligros.lua")
  check(type(Ds.Progreso) == "function" and type(Ds.Explorador) == "function", "falta el modo explorador en Descubrir.lua")
  for _, k in ipairs({ "lya.manada", "lya.misionVoz", "lya.mascota", "lya.retos", "lya.cumple", "mundo.peligros", "mundo.explorador" }) do
    check(A.Get(k) == true, k .. " no viene prendido")
  end
  check(Mn.Capas.PorId("raros.peligros"), "la capa «Peligros» no está en el control de capas")
  check(type(AlfaLya.MisionEnSuVoz) == "function", "falta AlfaLya.MisionEnSuVoz")
end)

---------------------------------------------------------------------------
-- 21. Las Lyas de tu grupo
---------------------------------------------------------------------------
-- Por la red de La Jauría (AlfaManada.Red, tipo 1Y): un susurro oculto a cada compañero.
step("Lya en grupo: por la red de La Jauría, 1Y en susurro oculto a cada compañero", function()
  local Mnd = rawget(_G, "AlfaManada")
  check(type(Mnd) == "table" and type(Mnd.Red) == "table" and Mnd.Red.EnviarLibre, "falta AlfaManada.Red (la red de La Jauría)")
  local real = Mnd and Mnd.Red
  local ig, un, uip = IsInGroup, UnitName, UnitInParty
  local enviados, oyente = {}, nil
  Mnd.Red = { EnviarLibre = function(clave, tipo, texto, destino) enviados[#enviados + 1] = { tipo = tipo, texto = texto, destino = destino } return true end,
    Escuchar = function(tipo, fn) if tipo == "Y" then oyente = fn end return true end, EnviarHermandad = function() return true end }
  IsInGroup = function() return true end
  UnitName = function(u)
    if u == "party1" then return "Rio", "Reino" elseif u == "party2" then return "Mar" elseif u == "player" then return "Toxic" end
    return nil
  end
  UnitInParty = function(n) return n == "Rio" or n == "Mar" end
  check(Ly.EnGrupo.Escuchar(), "no se pudo escuchar en la red")
  check(oyente == Ly.EnGrupo.DeLaRed, "no escucha el tipo Y en la red")
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  RUN_TIMERS(10)
  check(#enviados == 2 and enviados[1].tipo == "Y" and enviados[1].texto == "H" and enviados[1].destino == "Rio-Reino" and enviados[2].destino == "Mar",
    "el saludo no salió en 1Y a cada compañero: " .. #enviados .. " " .. tostring(enviados[1] and enviados[1].destino))
  local n = #dichos
  conLya(function() check(oyente and oyente("rio", "Rio-Reino", { "H" }, "WHISPER"), "no aceptó el saludo de la red") end)
  check(dijo("La Lya de Rio me saludó", n), "Lya no dijo el saludo que llegó por la red")
  check(enviados[#enviados].texto == "R", "no contestó por la red")
  conLya(function() check(not (oyente and oyente("x", "Lejano-Reino", { "H" }, "WHISPER")), "aceptó por la red a quien no está en tu grupo") end)
  Mnd.Red = real
  IsInGroup, UnitName, UnitInParty = ig, un, uip
end)

-- Sin la red: el prefijo propio, solo al grupo.
local redReal = rawget(_G, "AlfaManada") and AlfaManada.Red
if AlfaManada then AlfaManada.Red = nil end

step("Lya en grupo: saluda una vez al juntarse, solo al grupo, y contesta el saludo", function()
  local ig, un, uip, ii, CI = IsInGroup, UnitName, UnitInParty, IsInInstance, C_ChatInfo
  local enviados = {}
  C_ChatInfo = setmetatable({ SendAddonMessage = function(p, t, c, d) enviados[#enviados + 1] = { p = p, t = (t:gsub("|~[HA]$", "")), c = c, d = d } return true end }, { __index = CI })
  IsInGroup = function() return true end
  UnitName = function(u) if u == "party1" then return "Ana" end if u == "player" then return "Toxic" end return nil end
  UnitInParty = function(n) return n == "Ana" or n == "Eva" end
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  RUN_TIMERS(10)
  check(#enviados == 1 and enviados[1].p == "AlfaLya" and enviados[1].t == "1H" and enviados[1].c == "PARTY", "no saludó al grupo con 1H por PARTY")
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  RUN_TIMERS(10)
  check(#enviados == 1, "saludó dos veces a la misma persona")
  for _, e in ipairs(enviados) do check(e.c == "PARTY" or e.c == "RAID", "un mensaje salió por " .. tostring(e.c)) end
  -- Lo que llega
  local n = #dichos
  conLya(function()
    check(Gr.Mensaje("1H", "PARTY", "Eva-Reino"), "no aceptó el saludo de alguien del grupo")
  end)
  check(dijo("La Lya de Eva me saludó", n), "Lya no dijo que la saludó la Lya de Eva")
  check(enviados[#enviados].t == "1R", "no contestó el saludo con 1R")
  local m = #enviados
  conLya(function()
    check(not Gr.Mensaje("1H", "PARTY", "Eva-Reino"), "aceptó otro saludo de la misma persona enseguida")
    check(not Gr.Mensaje("1H", "PARTY", "Bob-Reino"), "aceptó un saludo de quien no está en tu grupo")
    check(not Gr.Mensaje("1H", "WHISPER", "Ana-Reino"), "aceptó un saludo por susurro")
    check(not Gr.Mensaje("1H", "PARTY", "Toxic"), "se escuchó a sí misma")
  end)
  check(#enviados == m, "respondió a algo que no debía")
  -- A un 1R no se responde (sin ping-pong).
  conLya(function() check(Gr.Mensaje("1R", "PARTY", "Ana-Reino"), "no aceptó la respuesta al saludo") end)
  check(#enviados == m and dijo("me contestó el saludo", n), "1R hizo ping-pong o Lya no lo dijo")
  IsInGroup, UnitName, UnitInParty, IsInInstance, C_ChatInfo = ig, un, uip, ii, CI
end)

step("Lya en grupo: platican poquito, nunca en combate ni en instancias; apagado, nada", function()
  local ig, un, uip, ii, CI, icl = IsInGroup, UnitName, UnitInParty, IsInInstance, C_ChatInfo, InCombatLockdown
  local enviados = {}
  C_ChatInfo = setmetatable({ SendAddonMessage = function(p, t, c) enviados[#enviados + 1] = { p = p, t = (t:gsub("|~[HA]$", "")), c = c } return true end }, { __index = CI })
  IsInGroup = function() return true end
  UnitName = function(u) if u == "player" then return "Toxic" end return nil end
  UnitInParty = function(n) return n == "Luz" or n == "Sol" end
  local n = #dichos
  conLya(function() check(Gr.Platicar(), "Lya no platicó en grupo") end)
  check(#enviados == 1 and enviados[1].t:match("^1C|%d$"), "la plática no salió como 1C|n")
  check(#dichos > n, "Lya no dijo su parte de la plática")
  conLya(function() check(not Gr.Platicar(), "Lya platicó dos veces seguidas") end)
  local k = #dichos
  conLya(function() check(Gr.Mensaje("1C|5", "PARTY", "Luz-Reino"), "no contestó una plática") end)
  check(dijo("La Lya de Luz dice algo", k) and dijo("La manada unida no se rinde", k), "no contestó con la parte de la otra Lya")
  conLya(function() check(not Gr.Mensaje("1C|99", "PARTY", "Sol-Reino"), "aceptó una plática que no existe") end)
  -- En combate y en instancias, nada.
  InCombatLockdown = function() return true end
  conLya(function() check(not Gr.Mensaje("1H", "PARTY", "Sol-Reino"), "escuchó en combate") end)
  InCombatLockdown = icl
  IsInInstance = function() return true, "party" end
  local e = #enviados
  check(not Gr.Enviar("1H"), "envió dentro de una instancia")
  IsInInstance = ii
  A.Set("lya.manada", false)
  conLya(function() check(not Gr.Mensaje("1H", "PARTY", "Sol-Reino"), "con lya.manada apagado escuchó") end)
  check(not Gr.Enviar("1H") and #enviados == e, "con lya.manada apagado envió")
  A.Set("lya.manada", true)
  IsInGroup = function() return false end
  check(not Gr.Enviar("1H"), "sin grupo envió")
  IsInGroup, UnitName, UnitInParty, IsInInstance, C_ChatInfo, InCombatLockdown = ig, un, uip, ii, CI, icl
end)

if AlfaManada then AlfaManada.Red = redReal end

---------------------------------------------------------------------------
-- 22. Tus misiones en su voz
---------------------------------------------------------------------------
step("Misiones en su voz: dos líneas, de los objetivos; sin objetivos, el recado", function()
  local Q = C_QuestLog
  local objetivos = {
    [501] = { { type = "monster", text = "Jabalí moteado asesinado: 0/8", numRequired = 8 }, { type = "item", text = "Colmillo de jabalí: 0/5", numRequired = 5 } },
    [502] = {},
  }
  C_QuestLog = setmetatable({
    GetQuestObjectives = function(q) return objetivos[q] end,
    GetTitleForQuestID = function(q) return ({ [501] = "Los jabalíes", [502] = "Una carta" })[q] end,
  }, { __index = Q })
  local r = Sv.Resumen(501)
  check(r and r:find("«Los jabalíes»: toca cazar Jabalí moteado asesinado (8) y juntar Colmillo de jabalí (5).", 1, true), "la primera línea está mal: " .. tostring(r))
  local _, saltos = (r or ""):gsub("\n", "")
  check(saltos == 1, "no son dos líneas: " .. tostring(r))
  local cierre = r and r:match("\n(.*)$")
  local esDeCaza = false
  for _, t in ipairs(Sv.CIERRES.monster) do if t == cierre then esDeCaza = true end end
  check(esDeCaza, "la segunda línea no es de caza: " .. tostring(cierre))
  check(Sv.Resumen(501) == r, "la misma misión no da la misma frase")
  local r2 = Sv.Resumen(502)
  check(r2 and r2:find("hay que llevar el recado", 1, true), "sin objetivos no habló del recado: " .. tostring(r2))
  check(AlfaLya.MisionEnSuVoz(501) == r, "AlfaLya.MisionEnSuVoz no da el resumen")
  -- Al tomarla, Lya lo dice (después del gancho de Historias).
  local n = #dichos
  conLya(function() FIRE_EVENT("QUEST_ACCEPTED", 501) RUN_TIMERS(8) end)
  check(dijo("«Los jabalíes»", n), "al tomar la misión Lya no la resumió")
  A.Set("lya.misionVoz", false)
  local m = #dichos
  conLya(function() FIRE_EVENT("QUEST_ACCEPTED", 502) RUN_TIMERS(8) end)
  check(not dijo("recado", m), "con lya.misionVoz apagado Lya resumió")
  A.Set("lya.misionVoz", true)
  C_QuestLog = Q
end)

---------------------------------------------------------------------------
-- 23. Lya y tu mascota
---------------------------------------------------------------------------
step("Tu mascota: la saluda una vez; al cazador le avisa del hambre y la tristeza", function()
  local ue, un, ucf, uc, CP, icl = UnitExists, UnitName, UnitCreatureFamily, UnitClass, C_PetInfo, InCombatLockdown
  local feliz = 3
  UnitExists = function(u) return u == "player" or u == "pet" end
  UnitName = function(u) if u == "pet" then return "Colmillo" end return "Toxic" end
  UnitCreatureFamily = function(u) if u == "pet" then return "Lobo" end end
  UnitClass = function() return "Cazador", "HUNTER", 3 end
  C_PetInfo = { GetPetHappiness = function() return feliz, 0, 0 end }
  local n = #dichos
  conLya(function() FIRE_EVENT("UNIT_PET", "player") RUN_TIMERS(3) end)
  local c = dijo("Colmillo", n)
  check(c and c.texto:find("Lobo", 1, true), "Lya no saludó a tu mascota por su nombre y familia")
  local m = #dichos
  conLya(function() FIRE_EVENT("UNIT_PET", "player") RUN_TIMERS(3) end)
  check(#dichos == m, "Lya saludó dos veces a la misma mascota")
  feliz = 2
  conLya(function() FIRE_EVENT("UNIT_HAPPINESS", "pet") end)
  check(dijo("tiene hambre", m), "no avisó que tu mascota tiene hambre")
  feliz = 1
  local k = #dichos
  conLya(function() FIRE_EVENT("UNIT_HAPPINESS", "pet") end)
  local t = dijo("está triste", k)
  check(t and t.importante, "no avisó (importante) que tu mascota está triste")
  feliz = 3
  local j = #dichos
  conLya(function() FIRE_EVENT("UNIT_HAPPINESS", "pet") end)
  check(dijo("ya está feliz", j), "no festejó que tu mascota volvió a estar feliz")
  -- En combate espera.
  feliz = 2
  InCombatLockdown = function() return true end
  local h = #dichos
  conLya(function() FIRE_EVENT("UNIT_HAPPINESS", "pet") end)
  check(#dichos == h, "Lya habló de tu mascota en combate")
  InCombatLockdown = icl
  conLya(function() FIRE_EVENT("PLAYER_REGEN_ENABLED") end)
  check(dijo("tiene hambre", h), "al terminar el combate no avisó del hambre")
  -- Un brujo no da de comer.
  UnitClass = function() return "Brujo", "WARLOCK", 9 end
  UnitName = function(u) if u == "pet" then return "Kirix" end return "Toxic" end
  UnitCreatureFamily = function() return "Diablillo" end
  local b = #dichos
  conLya(function() FIRE_EVENT("UNIT_PET", "player") RUN_TIMERS(3) end)
  feliz = 1
  conLya(function() FIRE_EVENT("UNIT_HAPPINESS", "pet") end)
  check(dijo("Kirix", b) and not dijo("triste", b), "con brujo: no saludó o habló de comida")
  A.Set("lya.mascota", false)
  UnitName = function(u) if u == "pet" then return "Nuevo" end return "Toxic" end
  local o = #dichos
  conLya(function() FIRE_EVENT("UNIT_PET", "player") RUN_TIMERS(3) end)
  check(#dichos == o, "con lya.mascota apagado Lya saludó")
  A.Set("lya.mascota", true)
  UnitExists, UnitName, UnitCreatureFamily, UnitClass, C_PetInfo, InCombatLockdown = ue, un, ucf, uc, CP, icl
end)

---------------------------------------------------------------------------
-- 24. Los retos de la semana
---------------------------------------------------------------------------
step("Retos: la semana empieza el lunes; tres retos, siempre misiones y raros", function()
  local miercoles = os.time({ year = 2026, month = 11, day = 18, hour = 12 })
  check(Re.Semana(miercoles) == "2026-11-16", "el lunes de la semana está mal: " .. tostring(Re.Semana(miercoles)))
  local domingo = os.time({ year = 2026, month = 11, day = 22, hour = 12 })
  check(Re.Semana(domingo) == "2026-11-16", "el domingo no es de la misma semana")
  local l = Re.Elegir("2026-11-16")
  check(#l == 3 and l[1].clave == "misiones" and l[2].clave == "raros", "los retos no son tres con misiones y raros")
  local l2 = Re.Elegir("2026-11-16")
  check(l2[3].clave == l[3].clave and l2[1].meta == l[1].meta, "la misma semana da retos distintos")
end)

step("Retos: el avance sale de tu día de caza; cumplido, se festeja una vez con su salchicha", function()
  local d = datos()
  local hoy = Ly.Dia.Hoy()
  local semana = Re.Semana()
  d.retos = nil
  hoy.misiones, hoy.raros = 0, 0
  -- Un día de la semana pasada no cuenta; uno de esta, sí.
  d.dias = { { fecha = "2000-01-03", misiones = 99, raros = 99 }, { fecha = semana, misiones = 3, raros = 1 } }
  local lista = Re.Lista()
  check(lista[1].avance == 3 and lista[2].avance == 1, "el avance contó la semana pasada o no sumó esta: " .. lista[1].avance)
  local meta = lista[1].meta
  hoy.misiones = meta - 3
  local n = #dichos
  local hechos
  conLya(function() hechos = Re.Revisar() end)
  check(hechos == 1 and Re.Premios() == 1, "el reto de misiones cumplido no se festejó con su premio")
  local c = dichos[#dichos]
  check(#dichos > n and c.importante and c.texto:find(Re.Lista()[1].titulo, 1, true), "Lya no festejó el reto por su nombre")
  conLya(function() hechos = Re.Revisar() end)
  check(hechos == 0 and Re.Premios() == 1, "el mismo reto se festejó dos veces")
  -- Una mazmorra cuenta al entrar (no dos veces la misma enseguida).
  local ii, gi = IsInInstance, GetInstanceInfo
  IsInInstance = function() return true, "party" end
  GetInstanceInfo = function() return "Minas de la Muerte" end
  local antes = tonumber(Ly.Dia.Hoy().mazmorras) or 0
  conLya(function()
    FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false) RUN_TIMERS(3)
    FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false) RUN_TIMERS(3)
  end)
  check((tonumber(Ly.Dia.Hoy().mazmorras) or 0) == antes + 1, "la mazmorra no contó una sola vez")
  IsInInstance, GetInstanceInfo = ii, gi
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  RUN_TIMERS(3)
  A.Set("lya.retos", false)
  hoy.raros = 50
  conLya(function() check(Re.Revisar() == 0, "con lya.retos apagado se festejó") end)
  A.Set("lya.retos", true)
  hoy.raros = 0
end)

---------------------------------------------------------------------------
-- 25. Los cumpleaños
---------------------------------------------------------------------------
step("Cumpleaños: el tuyo y el de Alfa, una vez al año; apagado, nada", function()
  local d = datos()
  d.nacio, d.cumple, d.historia = "2025-11-20", nil, nil
  check(Cu.Nacio() == "2025-11-20", "no guardó tu primer día")
  check(Cu.Hoy("2026-11-20").tuyo == 1 and not Cu.Hoy("2026-11-21").tuyo, "tu cumpleaños no cae en su día")
  check(not Cu.Hoy("2025-11-20").tuyo, "el primer día ya contó como cumpleaños")
  -- Si tu historia empezó antes, esa fecha manda.
  d.historia = { empezado = "2024-03-05" }
  check(Cu.Nacio() == "2024-03-05", "no tomó la fecha de tu historia, que es más vieja")
  check(Cu.Hoy("2026-03-05").tuyo == 2, "los años del cumpleaños están mal")
  local ka, n = AlfaNucleo.Kit.Anuncio, #dichos
  local anuncios = 0
  AlfaNucleo.Kit.Anuncio = function() anuncios = anuncios + 1 end
  local hizo
  conLya(function() hizo = Cu.Festejar("2026-03-05") end)
  check(hizo and dijo("2 años cazando juntos", n) and anuncios == 1, "no festejó tu cumpleaños con anuncio")
  conLya(function() hizo = Cu.Festejar("2026-03-05") end)
  check(not hizo, "festejó dos veces el mismo año")
  -- Alfa: el 16 de noviembre.
  AlfaNucleo.Datos("lya").cumpleAlfa = nil
  check(Cu.Hoy("2027-11-16").alfa == 1 and not Cu.Hoy("2026-11-16").alfa, "el cumpleaños de Alfa está mal")
  local m = #dichos
  conLya(function() hizo = Cu.Festejar("2027-11-16") end)
  check(hizo and dijo("Alfa cumple 1 año", m), "no festejó el cumpleaños de Alfa")
  conLya(function() hizo = Cu.Festejar("2027-11-16") end)
  check(not hizo, "festejó dos veces a Alfa el mismo año")
  A.Set("lya.cumple", false)
  AlfaNucleo.Datos("lya").cumpleAlfa = nil
  conLya(function() hizo = Cu.Festejar("2028-11-16") end)
  check(not hizo, "con lya.cumple apagado festejó")
  A.Set("lya.cumple", true)
  AlfaNucleo.Kit.Anuncio = ka
end)

---------------------------------------------------------------------------
-- 19. Los peligros de tu zona
---------------------------------------------------------------------------
step("Peligros: élites y raros del Codex contra tu nivel, en tu zona, sin lo de mazmorras", function()
  check(Pe.Peligro({ elite = true, level = 21, levelMax = 23 }, 20) == "alto", "un élite 3 arriba no es peligro alto")
  check(Pe.Peligro({ elite = true, level = 20, levelMax = 22 }, 20) == "medio", "un élite 2 arriba no es peligro medio")
  check(Pe.Peligro({ elite = true, level = 18, levelMax = 19 }, 20) == "medio", "un élite de tu nivel no es peligro")
  check(Pe.Peligro({ elite = true, level = 10, levelMax = 11 }, 30) == nil, "un élite gris salió como peligro")
  check(Pe.Peligro({ rare = true, level = 21 }, 20) == nil, "un raro 1 arriba salió como peligro")
  check(Pe.Peligro({ rare = true, level = 24 }, 20) == "alto", "un raro 4 arriba no es peligro alto")
  check(Pe.Peligro({ level = 40 }, 20) == nil, "una criatura normal salió como peligro")
  local npcs = {
    [11] = { name = "Ogro élite", level = 22, levelMax = 23, elite = true, spawns = { { map = 1411, x = 40, y = 40 }, { map = 1411, x = 41, y = 41 }, { map = 1411, x = 70, y = 20 } } },
    [12] = { name = "Raro feroz", level = 25, rare = true, spawns = { { map = 1411, x = 10, y = 10 } } },
    [13] = { name = "Jabalí", level = 25, spawns = { { map = 1411, x = 20, y = 20 } } },
    [14] = { name = "Jefe de mazmorra", level = 25, elite = true, instance = "deadmines", spawns = { { map = 1411, x = 30, y = 30 } } },
    [15] = { name = "Élite viejo", level = 5, elite = true, spawns = { { map = 1411, x = 50, y = 50 } } },
    [16] = { name = "Élite de otra zona", level = 25, elite = true, spawns = { { map = 1413, x = 50, y = 50 } } },
  }
  local cargas = 0
  local Cx = {
    IsLoaded = function() return true end, Load = function() cargas = cargas + 1 return true end,
    Each = function(kind, fn) if kind == "npc" then for id in pairs(npcs) do fn(id, npcs[id].name) end else fn(12, "Raro feroz") end end,
    Npc = function(id) return npcs[id] end,
  }
  local C, ul, zona = A.Codex, UnitLevel, Ds.Zona
  A.Codex = Cx
  UnitLevel = function() return 20 end
  local gn = Mn.Geo.NivelJugador
  Mn.Geo.NivelJugador = function() return 20 end
  Ds.Zona = function() return 1411 end
  Pe.Olvidar()
  Pe.Refrescar()
  RUN_TIMERS(5)
  check(Pe.Listo(), "el índice de peligros no se armó")
  local l = Pe.Lista(1411)
  local nombres = {}
  for _, e in ipairs(l) do nombres[e.c.name] = e end
  check(nombres["Ogro élite"] and nombres["Raro feroz"], "faltó un élite o un raro peligroso")
  check(not nombres["Jabalí"] and not nombres["Jefe de mazmorra"] and not nombres["Élite viejo"] and not nombres["Élite de otra zona"],
    "salió una criatura normal, de mazmorra, gris o de otra zona")
  check(nombres["Ogro élite"] and #nombres["Ogro élite"].c.puntos == 2, "las apariciones cercanas no se juntaron")
  check(l[1] and l[1].peligro == "alto", "los más peligrosos no van primero")
  local capa = A.Pins.GetLayer("mundo.peligros")
  check(type(capa) == "table" and #capa == 3, "la capa «Peligros» no se publicó con sus 3 pines: " .. tostring(capa and #capa))
  if capa and capa[1] then
    local lineas = {}
    local tip = { SetText = function(_, t) lineas[#lineas + 1] = t end, AddLine = function(_, t) lineas[#lineas + 1] = t end }
    capa[1].tooltip(tip)
    local s = table.concat(lineas, " ")
    check(s:find("nivel", 1, true) and s:find("peligroso", 1, true), "el pin no dice su nivel y el peligro: " .. s)
  end
  -- Al abrir el mapa con el Codex sin cargar, se carga por los peligros.
  local apagados = {}
  for _, k in ipairs({ "maps.dungeonPins", "maps.servicePins", "rares.worldRares", "rares.worldTreasures" }) do apagados[k] = A.Get(k) A.Set(k, false) end
  Cx.IsLoaded = function() return false end
  Mn.Marcas.PrepararDatos()
  check(cargas == 1, "al abrir el mapa no se cargó el Codex para los peligros")
  for k, v in pairs(apagados) do A.Set(k, v) end
  Cx.IsLoaded = function() return true end
  A.Set("mundo.peligros", false)
  RUN_TIMERS(2)
  check(not A.Pins.GetLayer("mundo.peligros") or #A.Pins.GetLayer("mundo.peligros") == 0, "apagada, la capa siguió")
  A.Set("mundo.peligros", true)
  RUN_TIMERS(2)
  -- En combate, el índice espera.
  Pe.Olvidar()
  local icl = InCombatLockdown
  InCombatLockdown = function() return true end
  Pe.Indexar()
  RUN_TIMERS(3)
  check(not Pe.Listo(), "el índice se armó en combate")
  InCombatLockdown = icl
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  RUN_TIMERS(5)
  check(Pe.Listo(), "al terminar el combate el índice no se armó")
  A.Codex, UnitLevel, Ds.Zona, Mn.Geo.NivelJugador = C, ul, zona, gn
  Pe.Olvidar()
  Pe.Refrescar()
  RUN_TIMERS(3)
end)

---------------------------------------------------------------------------
-- 20. El modo explorador
---------------------------------------------------------------------------
step("Modo explorador: rincones descubiertos de cada zona, tu zona primero", function()
  local Geo = Mn.Geo
  local ZA, X, zonas, zona, jug, cad = A.UI.ZoneArt, C_MapExplorationInfo, Geo.Zonas, Ds.Zona, Geo.Jugador, Geo.Cadena
  local arte = {
    [1411] = { 256, 256, { 100, 100, 0, 0, 1 }, { 200, 100, 500, 300, 2 } },
    [1412] = { 256, 256, { 100, 100, 0, 0, 1 }, { 100, 100, 100, 0, 2 }, { 100, 100, 200, 0, 3 } },
    [1413] = { 256, 256, { 100, 100, 0, 0, 1 } },
  }
  local vistos = {
    [1411] = { { textureWidth = 100, textureHeight = 100, offsetX = 0, offsetY = 0 } },
    [1412] = { { textureWidth = 100, textureHeight = 100, offsetX = 0, offsetY = 0 } },
    [1413] = { { textureWidth = 100, textureHeight = 100, offsetX = 0, offsetY = 0 } },
  }
  A.UI.ZoneArt = setmetatable({ FullOverlays = function(z) return arte[z] end }, { __index = ZA })
  C_MapExplorationInfo = { GetExploredMapTextures = function(z) return vistos[z] end }
  Geo.Zonas = function() return { { id = 1412 }, { id = 1413 }, { id = 1411 }, { id = 9999 } } end
  Ds.Zona = function() return 1411 end
  Geo.Jugador = function() return 0.5, 0.5 end
  Geo.Cadena = function() return 1414, 1411 end
  local h, t = Ds.Progreso(1411)
  check(h == 1 and t == 2, "el avance de tu zona está mal: " .. tostring(h) .. "/" .. tostring(t))
  local lista, r = Ds.Explorador()
  check(#lista == 3 and lista[1].zona == 1411 and lista[1].mia, "tu zona no va primero (o se coló una zona sin datos)")
  check(lista[3] and lista[3].zona == 1413, "las zonas completas no van al final")
  check(r.completas == 1 and r.zonas == 3 and r.hechos == 3 and r.total == 6, "el resumen del explorador está mal")
  -- La página lo enseña.
  local ok, e = pcall(function() A.Fire("SHOW_OPTIONS", "mundo") RUN_TIMERS(2) end)
  check(ok, "la página Mundo falló: " .. tostring(e))
  A.Set("mundo.explorador", false)
  ok, e = pcall(function() A.Fire("SHOW_OPTIONS", "mundo") RUN_TIMERS(2) end)
  check(ok, "la página Mundo falló con el explorador apagado: " .. tostring(e))
  A.Set("mundo.explorador", true)
  A.UI.ZoneArt, C_MapExplorationInfo, Geo.Zonas, Ds.Zona, Geo.Jugador, Geo.Cadena = ZA, X, zonas, zona, jug, cad
end)

step("Las páginas: Lya (con sus retos) y Mundo abren sin errores", function()
  local ok, e = pcall(function()
    A.Fire("SHOW_OPTIONS", "lya")
    RUN_TIMERS(2)
    A.Set("lya.retos", false)
    A.Fire("SHOW_OPTIONS", "lya")
    RUN_TIMERS(2)
    A.Set("lya.retos", true)
    A.Fire("SHOW_OPTIONS", "mundo")
    RUN_TIMERS(2)
  end)
  check(ok, "una página falló: " .. tostring(e))
end)

print(string.format("PRUEBA: 1.3.0 Lya y Mundo, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
