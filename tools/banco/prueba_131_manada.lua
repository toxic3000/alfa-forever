-- Prueba de la 1.3.1, La Jauría: la red, más cuidadosa (tools/prueba.py la corre con las demás):
--   * susurros a quien no está: el «No hay ningún jugador llamado...» no sale en tu
--     chat y el aprendiz deja de contarle a su mentor desconectado cómo va (1a|e);
--   * las Lyas del grupo no le hablan a quien está desconectado y la respuesta va
--     solo a quien saludó (1Y|R);
--   * lo difundido (1G, 1V, 1A, 1T, 1M) no se acepta por susurro;
--   * frenos por lobo: 1V, 1T y 1B («¡voy!»), y «pudo volver ya» de uno en uno;
--   * AlfaManada.MisionesDe: lo que lleva tu grupo en el mapa (MapaGrupo.Datos).
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
local function check(cond, msg) if not cond then NOTE("1.3.1 manada", msg) end end

-- El aviso del juego para un susurro a alguien desconectado (el banco no lo
-- trae: sin esto da su comodín, que no es texto).
ERR_CHAT_PLAYER_NOT_FOUND_S = "No hay ningún jugador llamado \"%s\" conectado."

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
local N = AlfaNucleo
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local MN = NS_OF("Alfa_Manada")
local Ly = NS_OF("Alfa_Lya")
local Ru = NS_OF("Alfa_Rutas")
local R, U = MN.Red, MN.U
local map = A.Compat.GetPlayerMapPosition()

local salidos, avisos = {}, {}
local function conRed(fn, sinCompartir)
  A.Set("manada.compartir", not sinCompartir)
  R.Escuchar()
  local via, envio, av, guild = R.Via, C_ChatInfo.SendAddonMessage, K.Aviso, IsInGuild
  R.Via = function() return "hermandad" end
  IsInGuild = function() return true end
  C_ChatInfo.SendAddonMessage = function(_, t, c, d) salidos[#salidos + 1] = { (t:gsub("|~[HA]$", "")), c, d } end
  K.Aviso = function(o) if o.lya == false then return av(o) end avisos[#avisos + 1] = o return true end
  local ok, e = pcall(fn)
  R.Via, C_ChatInfo.SendAddonMessage, K.Aviso, IsInGuild = via, envio, av, guild
  A.Set("manada.compartir", false)
  if not ok then error(e) end
end
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do t[k] = a.v end
  if not ok then error(e) end
end
local function vaciarCola() for _ = 1, 60 do FIRE(R.motor, "OnUpdate", 0.2) end end
local function llega(texto, quien, canal) FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", texto .. "|~H", canal or "GUILD", quien) end
local function salio(patron, canal, destino)
  for _, m in ipairs(salidos) do
    if m[1]:find(patron) and (not canal or m[2] == canal) and (not destino or m[3] == destino) then return m end
  end
  return nil
end
local function noEsta(nombre) return ERR_CHAT_PLAYER_NOT_FOUND_S:format(nombre) end
local function oculto(msg) return R.FiltroSistema ~= nil and R.FiltroSistema(nil, "CHAT_MSG_SYSTEM", msg) == true end

---------------------------------------------------------------------------
-- 1. Susurros a quien no está
---------------------------------------------------------------------------

step("Tu mentor desconectado: su aviso no sale y no se le cuenta nada", function()
  local Me = MN.Mentor
  conRed(function()
    -- Caro (nivel 40) te adopta.
    llega("1a|p|40", "Caro Vega", "WHISPER")
    local caro = U.Clave("Caro Vega")
    check(Me.Aceptar(caro), "no aceptó a Caro de mentora")
    salidos = {}
    RUN_TIMERS(5)
    vaciarCola()
    check(salio("^1a|e|", "WHISPER", "Caro Vega"), "no le contó a Caro cómo vas (1a|e)")
    -- Caro se desconectó: el juego lo dice en el chat.
    check(oculto(noEsta("Caro Vega")), "el «No hay ningún jugador llamado...» de tu mentora salió en el chat")
    check(not oculto(noEsta("Nadie Nunca")), "ocultó el aviso de alguien a quien Alfa no le susurró")
    FIRE_EVENT("CHAT_MSG_SYSTEM", noEsta("Caro Vega"))
    check(Me.MentorFuera and Me.MentorFuera(), "no se enteró de que su mentora no está conectada")
    -- Ya no se le cuenta nada: ni a los 2 minutos ni forzado.
    salidos = {}
    NOW = NOW + 130
    RUN_TIMERS(1)
    check(not Me.EnviarEstado(false) and not Me.EnviarEstado(true), "le siguió contando a su mentora desconectada")
    vaciarCola()
    check(not salio("^1a|e|"), "salió 1a|e a una mentora desconectada")
    -- Caro habla: está de vuelta.
    llega("1a|p|40", "Caro Vega", "WHISPER")
    check(Me.EnviarEstado(true), "Caro habló y no se le contó cómo vas")
    vaciarCola()
    check(salio("^1a|e|", "WHISPER", "Caro Vega"), "no salió 1a|e al volver Caro")
    -- Otra vez fuera; a los 10 minutos se vuelve a probar.
    FIRE_EVENT("CHAT_MSG_SYSTEM", noEsta("Caro Vega"))
    NOW = NOW + 601
    check(Me.EnviarEstado(false), "a los 10 minutos no volvió a probar")
    -- «Quiero unirme» sigue ocultando a los oficiales que no están.
    local listo
    R.BuscarOficial({ "Oficial Uno" }, function(n) listo = n or false end)
    check(oculto(noEsta("Oficial Uno")), "dejó de ocultar el aviso de un oficial desconectado")
    RUN_TIMERS(6)
    check(listo == false, "la búsqueda de oficiales no terminó")
    Me.Terminar(caro)
  end, true)
end)

step("Las Lyas del grupo: nada a quien está desconectado, la respuesta a quien saludó", function()
  local Gr = Ly.EnGrupo
  check(Gr and Gr.Saludar and Gr.Oir, "falta EnGrupo.lua")
  local nombres = { party1 = "Ana Smith", party2 = "Beto Ruiz", party3 = "Caro Vega" }
  local un = UnitName
  conRed(function()
    con(_G, {
      IsInGroup = function() return true end, IsInRaid = function() return false end,
      UnitName = function(u) if nombres[u] then return nombres[u] end return un(u) end,
      UnitIsConnected = function(u) return u ~= "party2" end,
      UnitInParty = function(n) for _, x in pairs(nombres) do if x == n then return true end end return false end,
    }, function()
      salidos = {}
      check(Gr.Saludar(), "Lya no saludó al grupo")
      vaciarCola()
      check(salio("^1Y|H$", "WHISPER", "Ana Smith"), "no saludó a Ana (1Y|H)")
      check(not salio("^1Y", "WHISPER", "Beto Ruiz"), "le susurró a Beto, que está desconectado")
      -- Caro saluda: la respuesta va solo a ella.
      salidos = {}
      check(Gr.Oir("H", "", "Caro Vega"), "no oyó el saludo de Caro")
      vaciarCola()
      check(salio("^1Y|R$", "WHISPER", "Caro Vega"), "no le contestó el saludo a Caro (1Y|R)")
      check(not salio("^1Y|R$", "WHISPER", "Ana Smith"), "contestó el saludo de Caro también a Ana")
    end)
  end, true)
end)

---------------------------------------------------------------------------
-- 2. Lo difundido no llega por susurro
---------------------------------------------------------------------------

step("1G, 1V, 1A, 1T y 1M no se aceptan por susurro", function()
  local Gu, Rl = MN.Guaridas, MN.Reloj
  Rl.Olvidar()
  for _, sinCompartir in ipairs({ true, false }) do
    conRed(function()
      if MN.Llamado.Olvidar then MN.Llamado.Olvidar() end
      avisos = {}
      Gu.Ver(7001)
      Gu.Ver(7001)
      llega(("1A|%d|45.00|55.00|Mor'Ladim"):format(map), "Malo Uno", "WHISPER")
      llega(("1V|%d|7001|r|%d|40.00|50.00|Raro falso"):format(map, map), "Malo Dos", "WHISPER")
      check(#avisos == 0, "un susurro sacó un aviso de la manada" .. (sinCompartir and " sin compartir" or "") .. ": " .. tostring(avisos[1] and avisos[1].titulo))
      llega(("1T|%d|50.00|50.00|120|Falso del susurro"):format(map), "Malo Tres", "WHISPER")
      check(Rl.De("Falso del susurro") == nil, "un susurro escribió un raro cazado")
      llega(("1G|%d|7002|1"):format(map), "Malo Cuatro", "WHISPER")
      check(Gu.DeLobo("Malo Cuatro") == nil, "un susurro dijo su guarida")
      llega("1M|601,602", "Malo Cinco", "WHISPER")
      check(AlfaManada.MisionesDe == nil or AlfaManada.MisionesDe("Malo Cinco") == nil, "un susurro dijo sus misiones")
    end, sinCompartir)
  end
  -- Por la hermandad, como siempre.
  conRed(function()
    avisos = {}
    llega(("1A|%d|45.00|55.00|Mor'Ladim"):format(map), "Ana Smith")
    check(#avisos == 1 and avisos[1].titulo:find("Ana Smith", 1, true), "un llamado por la hermandad ya no llegó")
    llega(("1G|%d|7002|1"):format(map), "Ana Smith")
    check(Gu.DeLobo("Ana Smith"), "una guarida por la hermandad ya no llegó")
  end)
end)

---------------------------------------------------------------------------
-- 3. Frenos por lobo
---------------------------------------------------------------------------

step("1V: un aviso por lobo cada minuto", function()
  local Gu = MN.Guaridas
  conRed(function()
    Gu.Ver(7001)
    Gu.Ver(7001)
    avisos = {}
    for i = 1, 5 do
      llega(("1V|%d|7001|r|%d|40.00|50.00|Raro %d"):format(map, map, i), "Malo Uno")
    end
    check(#avisos == 1, "un lobo sacó " .. #avisos .. " avisos de raros seguidos")
    llega(("1V|%d|7001|r|%d|41.00|51.00|Otro raro"):format(map, map), "Beto Ruiz")
    check(#avisos == 2, "el freno de un lobo calló a otro")
    NOW = NOW + 61
    llega(("1V|%d|7001|r|%d|42.00|52.00|Raro 9"):format(map, map), "Malo Uno")
    check(#avisos == 3, "al minuto no volvió a escuchar a ese lobo")
  end)
end)

step("1T: uno cada 30 s por lobo y como mucho 5 suyos", function()
  local Rl = MN.Reloj
  Rl.Olvidar()
  conRed(function()
    A.Set("manada.rarosManada", true)
    llega(("1T|%d|50.00|50.00|10|Falso A"):format(map), "Malo Uno")
    llega(("1T|%d|50.00|50.00|10|Falso B"):format(map), "Malo Uno")
    check(Rl.De("Falso A") and not Rl.De("Falso B"), "aceptó dos 1T seguidos del mismo lobo")
    for i = 1, 40 do
      NOW = NOW + 31
      llega(("1T|%d|50.00|50.00|10|Falso %d"):format(map, i), "Malo Uno")
    end
    local suyos = 0
    for _, x in ipairs(Rl.Lista()) do if x.por == "Malo Uno" then suyos = suyos + 1 end end
    check(suyos <= 5, "un lobo dejó " .. suyos .. " raros cazados")
    -- «Pudo volver ya»: de uno en uno.
    Rl.Olvidar()
    for i, quien in ipairs({ "Ana Smith", "Beto Ruiz", "Caro Vega" }) do
      llega(("1T|%d|5%d.00|50.00|1900|Raro viejo %d"):format(map, i, i), quien)
    end
    avisos = {}
    local n1, n2, n3, n4 = Rl.Revisar(), Rl.Revisar(), Rl.Revisar(), Rl.Revisar()
    check(n1 == 1 and n2 == 1 and n3 == 1 and n4 == 0, ("«pudo volver ya» no salió de uno en uno: %s %s %s %s"):format(tostring(n1), tostring(n2), tostring(n3), tostring(n4)))
    check(#avisos == 3, "los tres raros no avisaron, uno por vuelta: " .. #avisos)
    Rl.Olvidar()
  end)
end)

step("1B: «¡voy!» solo a tu llamado de hace poco, uno por lobo", function()
  local Ll = MN.Llamado
  conRed(function()
    if Ll.Olvidar then Ll.Olvidar() end
    avisos = {}
    llega("1B", "Beto Ruiz", "WHISPER")
    check(#avisos == 0, "un «¡voy!» sin haber llamado sacó un aviso")
    check(Ll.Llamar(), "no llamó a la manada")
    avisos = {}
    llega("1B", "Beto Ruiz", "WHISPER")
    llega("1B", "Beto Ruiz", "WHISPER")
    check(#avisos == 1 and avisos[1].titulo:find("Beto Ruiz", 1, true), "el «¡voy!» de Beto no salió una vez: " .. #avisos)
    llega("1B", "Caro Vega", "WHISPER")
    check(#avisos == 2, "el «¡voy!» de Caro no salió")
    NOW = NOW + 301
    llega("1B", "Dani Paz", "WHISPER")
    check(#avisos == 2, "un «¡voy!» de hace más de 5 minutos sacó un aviso")
  end)
end)

---------------------------------------------------------------------------
-- 4. AlfaManada.MisionesDe
---------------------------------------------------------------------------

step("AlfaManada.MisionesDe: las misiones de tu grupo en el mapa", function()
  check(type(AlfaManada.MisionesDe) == "function", "falta AlfaManada.MisionesDe")
  if type(AlfaManada.MisionesDe) ~= "function" then return end
  local Mg = Ru.MapaGrupo
  local Cp = A.Compat
  local un = UnitName
  local pt = function(x, y) return { map = 1440, x = x, y = y } end
  conRed(function()
    llega("1M|601,650", "Beto Ruiz")
    llega("1M|777", "Caro Vega-OtroReino")
    local b = AlfaManada.MisionesDe("Beto Ruiz")
    check(b and b[601] and b[650], "no dijo las misiones de Beto")
    local b2 = AlfaManada.MisionesDe("Beto Ruiz-OtroReino")
    check(b2 and b2[650], "con «Nombre-Reino» no encontró a Beto")
    local c = AlfaManada.MisionesDe("Caro Vega")
    check(c and c[777], "sin el reino no encontró a Caro, que llegó con su reino")
    check(AlfaManada.MisionesDe("Nadie Nunca") == nil, "de quien no dijo nada no devolvió nil")
    if b then b[999] = true end
    check(not AlfaManada.MisionesDe("Beto Ruiz")[999], "devolvió la tabla de adentro (no una copia)")
    -- En el mapa del grupo: Ana por el juego, Beto por la manada.
    con(_G, {
      IsInGroup = function() return true end, IsInRaid = function() return false end,
      UnitExists = function(u) return u == "party1" or u == "party2" or u == "player" end,
      UnitName = function(u) if u == "party1" then return "Ana Smith" elseif u == "party2" then return "Beto Ruiz" end return un(u) end,
    }, function()
      con(C_QuestLog, { IsUnitOnQuest = function(u, q) return u == "party1" and q == 601 end }, function()
        con(A, { Codex = { IsLoaded = function() return true end, Quest = function(q) return { id = q } end } }, function()
          con(Cp, { GetLogQuests = function() return { 601, 602 } end, IsOnQuest = function(q) return q == 601 or q == 602 end,
            IsQuestReadyForTurnIn = function() return false end }, function()
            con(Ru.Indice, { PasosMision = function() return { objetivo = pt(40, 40), fin = pt(45, 45) } end }, function()
              con(Ru, { TituloMision = function(q) return "Misión " .. q end }, function()
                local d = Mg.Datos()
                local por = {}
                for _, x in ipairs(d) do por[x.qid] = x end
                local q601 = por[601]
                check(q601 and #q601.quienes == 2, "la 601 no dice que la llevan Ana (del juego) y Beto (de la manada)")
                -- (Rutas muestra el nombre corto o el completo: los dos sirven)
                check(por[650] and not por[650].tuya and tostring(por[650].quienes[1]):find("^Beto") ~= nil, "no salió la 650, que solo lleva Beto")
                check(not por[602], "la 602 salió sin que nadie del grupo la lleve")
                -- Sin compartir: no se sabe (nil) y queda lo del juego.
                A.Set("manada.compartir", false)
                check(AlfaManada.MisionesDe("Beto Ruiz") == nil, "sin compartir dijo las misiones de Beto")
                local d2 = Mg.Datos()
                check(#d2 == 1 and d2[1].qid == 601 and #d2[1].quienes == 1, "sin compartir no quedó solo lo del juego")
                A.Set("manada.compartir", true)
              end)
            end)
          end)
        end)
      end)
    end)
    -- A los 15 minutos ya no vale.
    NOW = NOW + 901
    check(AlfaManada.MisionesDe("Beto Ruiz") == nil, "lo que dijo Beto hace más de 15 min siguió valiendo")
  end)
end)

---------------------------------------------------------------------------
-- 5. Un raro que viste muerto no es tu caza
---------------------------------------------------------------------------

step("Un raro que viste caído no cuenta como cazado por ti", function()
  local Rl, Lo = MN.Reloj, MN.Logros
  local Ra = A.Rares
  check(Ra and Ra.History, "falta el historial de raros del motor")
  if not (Ra and Ra.History) then return end
  Rl.Olvidar()
  local hist, h = Ra.History, {}
  Ra.History = function() return h end
  local reloj = GetServerTime()
  local un = UnitName
  local function raro(key, nombre) h[key] = { kind = "rare", id = 70, name = nombre, dead = reloj, t = reloj, map = map, x = 30, y = 40 } end
  local function objetivo(nombre, tomado)
    return {
      UnitExists = function(u) return u == "target" or u == "player" end, UnitIsPlayer = function(u) return u == "player" end,
      UnitIsDead = function(u) return u == "target" end,
      UnitName = function(u) if u == "target" then return nombre end return un(u) end,
      UnitIsTapDenied = function(u) return u == "target" and tomado end,
    }
  end
  local ok, e = pcall(conRed, function()
    A.Set("manada.rarosManada", true)
    A.Set("manada.logrosCompartir", true)
    local antes = Lo.Semana().raros
    salidos = {}
    -- De lejos (lo mató otro y pasas junto a su cuerpo).
    raro("rare:71", "Mor'Ladim")
    A.Fire("RARES_HISTORY", "rare:71")
    vaciarCola()
    check(Rl.De("Mor'Ladim"), "el reloj no anotó el raro que viste caído")
    check(salio("^1T|%d+|30%.00|40%.00|%d+|Mor'Ladim$"), "el reloj del raro visto ya no se comparte (1T)")
    check(Lo.Semana().raros == antes, "un raro que solo viste caído contó en tu semana")
    check(not salio("^1E|r|"), "a tu hermandad le llegó que cazaste un raro que solo viste")
    -- Tu objetivo, muerto, pero lo tomó otro.
    con(_G, objetivo("Rak'shiri", true), function()
      raro("rare:72", "Rak'shiri")
      A.Fire("RARES_HISTORY", "rare:72")
    end)
    vaciarCola()
    check(Rl.De("Rak'shiri") and Lo.Semana().raros == antes and not salio("^1E|r|"), "contó como tuyo un raro que tomó otro")
    -- Tu objetivo, muerto y tuyo: sí es tu caza.
    con(_G, objetivo("Gorlash", false), function()
      raro("rare:73", "Gorlash")
      A.Fire("RARES_HISTORY", "rare:73")
    end)
    vaciarCola()
    check(Lo.Semana().raros == antes + 1, "tu caza no contó en tu semana")
    check(salio("^1E|r|Gorlash$", "GUILD"), "tu caza no le llegó a tu hermandad (1E|r)")
    A.Set("manada.logrosCompartir", false)
  end)
  Ra.History = hist
  Rl.Olvidar()
  if not ok then error(e) end
end)

---------------------------------------------------------------------------
-- 6. La página se rehace una vez por ráfaga
---------------------------------------------------------------------------

step("La página de La Jauría se rehace una vez por ráfaga", function()
  local Qt = MN.QuienTiene
  local rehacer, veces = N.RehacerPagina, 0
  conRed(function()
    A.Fire("SHOW_OPTIONS", "manada")
    RUN_TIMERS(3)
    check(MN.Pagina.view, "la página no se armó")
    Qt.Olvidar()
    check(Qt.Buscar("Cobre"), "no buscó «Cobre»")
    local cid = Qt.Consulta() and Qt.Consulta().cid
    N.RehacerPagina = function(...) veces = veces + 1 return rehacer(...) end
    for i = 1, 30 do
      llega(("1U|%s|%d|1|Barra de cobre %d"):format(tostring(cid), 2840 + i, i), ("Lobo%02d Ruiz"):format(i), "WHISPER")
    end
    check(#Qt.Resultados() == 30, "no llegaron las 30 respuestas")
    check(veces <= 1, "30 respuestas rehicieron la página " .. veces .. " veces")
    RUN_TIMERS(1)
    check(veces >= 1 and veces <= 2, "tras la ráfaga la página no se rehizo (una vez): " .. veces)
    N.RehacerPagina = rehacer
    Qt.Olvidar()
  end)
  N.RehacerPagina = rehacer
end)

---------------------------------------------------------------------------
-- 7. El logro que no sale en una instancia, sale al volver
---------------------------------------------------------------------------

step("El logro de nivel 60 dentro de una mazmorra sale al salir", function()
  conRed(function()
    A.Set("manada.logrosCompartir", true)
    salidos = {}
    con(_G, { IsInInstance = function() return true, "party" end }, function()
      FIRE_EVENT("PLAYER_LEVEL_UP", 60)
      vaciarCola()
    end)
    check(not salio("^1E|n|"), "salió un logro dentro de una instancia")
    FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
    RUN_TIMERS(7)
    vaciarCola()
    check(salio("^1E|n|60$", "GUILD"), "al salir de la instancia no salió tu nivel 60 (1E|n)")
    salidos = {}
    RUN_TIMERS(2)
    vaciarCola()
    check(not salio("^1E|n|"), "el logro pendiente salió dos veces")
    A.Set("manada.logrosCompartir", false)
  end)
end)

---------------------------------------------------------------------------
-- 8. Cazar juntos: lo caducado se olvida; tu zona, una vez por vuelta
---------------------------------------------------------------------------

step("Cazar juntos olvida lo caducado y mira tu zona una vez", function()
  check(type(U.Podar) == "function", "falta U.Podar")
  if type(U.Podar) == "function" then
    local t = { a = NOW - 100, b = NOW - 5, c = "raro" }
    U.Podar(t, 60, NOW)
    check(t.a == nil and t.b ~= nil and t.c == nil, "U.Podar no olvidó lo viejo")
  end
  local J = MN.Juntos
  if J.Olvidar then J.Olvidar() end
  conRed(function()
    for i = 1, 30 do llega(("1M|%d"):format(700 + i), ("Lobo%02d Paz"):format(i)) end
    -- (1.3.2: la tarea de 20 s vive en el reloj de La Jauría, MN.Cada; es J.OfrecerATodos)
    local tarea = { fn = function() if J.OfrecerATodos then J.OfrecerATodos() end end }
    check(J.OfrecerATodos, "falta J.OfrecerATodos")
    local mp, veces = U.MiPosicion, 0
    U.MiPosicion = function(...) veces = veces + 1 return mp(...) end
    local ok, e = pcall(tarea.fn, 0)
    U.MiPosicion = mp
    if not ok then error(e) end
    check(veces <= 1, "la vuelta de cazar juntos miró tu posición " .. veces .. " veces (una por lobo)")
    check(J.Cuantos and J.Cuantos() == 30, "no recuerda a los 30 lobos")
    NOW = NOW + 901
    tarea.fn(0)
    check(J.Cuantos and J.Cuantos() == 0, "lo de hace más de 15 min no se olvidó: " .. tostring(J.Cuantos and J.Cuantos()))
  end)
end)

---------------------------------------------------------------------------
-- 9. Cortar por letras, no por bytes
---------------------------------------------------------------------------

step("Los textos se cortan por letras, sin partir ninguna", function()
  local largo = "x" .. ("Ж"):rep(30) -- 31 letras, 61 bytes
  check(type(U.Cortar) == "function", "falta U.Cortar")
  if type(U.Cortar) == "function" then
    check(U.Cortar(largo, 25) == "x" .. ("Ж"):rep(24), "U.Cortar no dejó 25 letras enteras")
    check(U.Cortar("Hola", 10) == "Hola", "U.Cortar cambió un texto corto")
  end
  local Rl, Me = MN.Reloj, MN.Mentor
  Rl.Olvidar()
  conRed(function()
    A.Set("manada.rarosManada", true)
    -- Un raro con nombre en ruso (más de 48 bytes, menos de 48 letras): entero.
    llega(("1T|%d|50.00|50.00|10|%s"):format(map, largo), "Ana Smith")
    local x = Rl.Lista()[1]
    check(x and x.nombre == largo, "el nombre en ruso del raro llegó cortado: " .. tostring(x and #x.nombre))
    -- La misión del aprendiz, en ruso: 50 letras enteras.
    check(Me.Adoptar("Beto Ruiz", 10), "no propuso adoptar a Beto")
    llega("1a|s", "Beto Ruiz", "WHISPER")
    llega("1a|e|10|500|1429|1|3|x" .. ("Ж"):rep(60), "Beto Ruiz", "WHISPER")
    local ap = Me.Aprendices()[1]
    local m = ap and ap.estado and ap.estado.mision or ""
    check(m == "x" .. ("Ж"):rep(49), "la misión del aprendiz no quedó en 50 letras enteras (" .. #m .. " bytes)")
    check(not m:find("[\192-\255]$"), "la misión del aprendiz termina en una letra partida")
    Me.Terminar(U.Clave("Beto Ruiz"))
  end)
  Rl.Olvidar()
end)

print(string.format("PRUEBA: 1.3.1 La Jauría, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
