-- Prueba de la 1.3.3, lo de Aventura y Mundo (tools/prueba.py la corre con las demás prueba_*.lua):
--   1. «Usa tu piedra de hogar»: la placa de la flecha con el tramo de la
--      piedra (a dónde, cuántas entregas, cuánto ahorras, después, la piedra,
--      cuánto falta), el botón seguro del motor y Hogar.lua callado;
--   2. seguir la ruta del grupo con dos jugadores simulados: lo que lleva
--      el otro, «Pedírselas», «Seguir su ruta» (la flecha y el mapa),
--      «Compartir» con el clic del que comparte, el freno, nada en banda;
--   3. «Llévame a…»: lo más cerca primero, «≈ N min» u «otro continente»;
--   4. la cadena: «Llévame» a la primera que falta y la de ahora marcada;
--   5. las grises: «Soltar las N», con una sola confirmación que dice cuáles;
--   6. «Zona peligrosa» con «Llévame a una zona de tu nivel»;
--   7. al entrar, en silencio: la piedra de hogar no habla.
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
local function check(cond, msg) if not cond then NOTE("1.3.3 rutas", msg) end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local A = AlfaNucleo.A
local N = AlfaNucleo
local K = AlfaNucleo.Kit
local Ru = NS_OF("Alfa_Rutas")
local E = A.Engine
local Nav = A.Nav
local Cp = A.Compat

local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do t[k] = a.v end
  if not ok then error(e) end
end

local function mundo(map, x, y)
  if map == 1440 then return 1, y * 100, x * 100 end
  if map == 1453 then return 0, y * 10, x * 10 end
  return nil
end
local function pt(map, x, y) return { map = map, x = x, y = y } end

-- Fuera de la entrada en silencio (el banco acaba de entrar).
local NoEntrando = { Entrando = function() return false end }

---------------------------------------------------------------------------
-- 1. «Usa tu piedra de hogar»
---------------------------------------------------------------------------

local Arrow = Nav and Nav.arrow

step("La placa «Usa tu piedra de hogar» con el tramo de la piedra", function()
  check(Arrow and Arrow.PintarPiedra, "falta la placa de la piedra (Arrow.PintarPiedra)")
  local leg = { kind = "hearth", place = "Costasur", saved = 9 * 60 + 20, seconds = 15 }
  local T = Nav.travel
  local Target = { label = "Consigue Cabeza de múrloc", map = 1424, x = 50, y = 50 }
  local estado = "instruction"
  con(N, NoEntrando, function()
    con(T, { CurrentLeg = function() return leg end, Remaining = function() return 130 end, Active = function() return true end,
      CurrentLabel = function() return "Piedra de hogar a Costasur: ahorra 9 min" end }, function()
      con(Nav, { Sample = function() return estado, 3, 0 end, GetTarget = function() return Target end,
        TomTomArrowGuides = function() return false end, HandedOff = function() return false end, HiddenWithGuide = function() return false end }, function()
        con(A, { ArrowHidden = function() return false end }, function()
          con(AlfaRuta, { EntregasPiedra = function() return 3, "Costasur" end }, function()
            con(C_Container, { GetItemCooldown = function() return 0, 0, 1 end }, function()
             con(_G, { C_Item = { GetItemCount = function(id) return id == 6948 and 1 or 0 end } }, function()
              Arrow:OnTarget(Target)
              local d = Arrow.Llegada()
              check(d and d.piedra, "con el tramo de la piedra no salió su placa")
              check(d and d.sobre == K.Mayus("Usa tu piedra de hogar"), "arriba no dice «USA TU PIEDRA DE HOGAR»: " .. tostring(d and d.sobre))
              check(d and d.accion == "Vuelves a Costasur: entregas 3 misiones y te ahorras 9 min caminando.",
                "la línea principal no se entiende: " .. tostring(d and d.accion))
              local nota = d and d.nota or ""
              check(nota:find("Después: Consigue Cabeza de múrloc", 1, true), "no dice lo que sigue después: " .. nota)
              check(nota:find("Tu piedra está lista.", 1, true), "no dice si la piedra está lista")
              check(nota:find("Llegas en unos 3 min", 1, true), "no dice en cuánto llegas")
              check(not Arrow.distText:IsShown() and not Arrow.etaText:IsShown() and not Arrow.legIcon:IsShown(),
                "sigue a la vista lo de antes («2:16 en total», el glifo)")
              -- Se queda mientras dure el tramo.
              for _ = 1, 100 do FIRE(Arrow.llegada, "OnUpdate", 0.1) end
              check(Arrow.Llegada() ~= nil, "la placa de la piedra se fue sola antes de usarla")
              -- Recargándose: lo dice.
              con(C_Container, { GetItemCooldown = function() return GetTime() - 60, 30 * 60, 1 end }, function()
                Arrow.LlegadaAlDia()
                check((Arrow.Llegada() or {}).nota and Arrow.Llegada().nota:find("lista en 29 min", 1, true), "no dice cuándo estará lista la piedra")
              end)
              -- El botón seguro del motor dice sí con este tramo.
              local B = A.QoL and A.QoL.Buttons
              local Cl = A.QoL and A.QoL.Client
              if B and B.WantsHearth and Cl then
                con(Cl, { ItemCount = function() return 1 end }, function()
                  check(B.WantsHearth({ goals = {} }), "el botón de la piedra no sale con el tramo de la ruta")
                end)
              end
              -- Hogar.lua no saca su aviso aparte.
              local dijo, por = Ru.Hogar.Revisar()
              check(not dijo and (por == "ruta" or por == "apagado" or por == "pocas" or por == "sinLugar") , "Hogar habló con la ruta ya en la piedra: " .. tostring(por))
              check(Ru.Hogar.RutaConPiedra(), "Hogar no ve el tramo de la piedra")
              -- Usaste la piedra: el tramo cambia y la placa se va.
              leg = { kind = "fly", label = "Vuela a Ventormenta" }
              Arrow:Refresh()
              check(not (Arrow.Llegada() and Arrow.Llegada().piedra), "al usar la piedra la placa se quedó")
              check(Arrow.distText:IsShown(), "al usar la piedra no volvió el texto del tramo")
              estado = "travel"
              Arrow:Refresh()
              Arrow:OnTarget(nil)
              Arrow.frame:Hide()
             end)
            end)
          end)
        end)
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- 2. Seguir la ruta del grupo (dos jugadores simulados)
---------------------------------------------------------------------------

step("Seguir la ruta del grupo: Pedírselas, Seguir su ruta, Compartir, el freno y nada en banda", function()
  local RG = Ru.RutaGrupo
  check(RG and RG.AlMensaje and RG.Seguir, "falta RutaGrupo.lua")
  RG.Reiniciar()
  local salidos = {}
  local banda = false
  local log = {}
  local compartidas = {}
  local capas = {}
  local avisos = {}
  local puesto, viaje
  local T = { id = "t" }
  con(_G, {
    IsInGroup = function() return true end, IsInRaid = function() return banda end, GetNumGroupMembers = function() return 2 end,
    UnitExists = function(u) return u == "player" or u == "party1" end,
    UnitName = function(u) if u == "party1" then return "Ana" end return "Lobato" end,
  }, function()
    con(C_ChatInfo, { SendAddonMessage = function(p, texto, canal) salidos[#salidos + 1] = { p = p, t = texto, c = canal } return 0 end,
      RegisterAddonMessagePrefix = function() return true end }, function()
      con(Cp, { SenderName = function(s) return s end, SenderIsMe = function(s) return s == "Lobato" end,
        IsOnQuest = function(q) return log[q] or false end, IsQuestCompleted = function() return false end }, function()
        con(A, { Party = { Members = function() return { { name = "Ana", quests = { [99601] = { { 1, 5 } }, [99602] = { { 0, 1 } } } } } end },
          Pins = { SetLayer = function(n, p) capas[n] = p end, ClearLayer = function(n) capas[n] = false end } }, function()
          con(Nav, { SetTarget = function(map, x, y, label, f) puesto = { map = map, x = x, y = y, label = label, f = f } T.map, T.x, T.y = map, x, y return T end,
            StartTrip = function(t, n, l, ends) viaje = { t = t, ends = ends } end, GetTarget = function() return puesto and T or nil end,
            MoveTarget = function(t, map, x, y) puesto.x, puesto.y = x, y return true end,
            Trip = function() return viaje end, EndTrip = function() puesto, viaje = nil, nil end }, function()
            con(Ru, { TituloMision = function(q) return "Misión " .. q end, Aviso = function(t, x, o) avisos[#avisos + 1] = { t = t, x = x, o = o } end }, function()
              con(Ru.Grupo, { Compartir = function(q) compartidas[#compartidas + 1] = q return true end }, function()
                -- Lo que lleva Ana y tú no.
                local q = RG.QueLleva()
                check(#q == 1 and q[1].nombre == "Ana" and #q[1].ids == 2, "no vio las 2 misiones que lleva Ana")
                local d = RG.Aviso()
                check(d and d.titulo == "Ana lleva 2 misiones que tú no tienes" and d.uno[1] == "Pedírselas" and d.dos[1] == "Seguir su ruta",
                  "el rastreador no ofreció «Pedírselas» y «Seguir su ruta»: " .. tostring(d and d.titulo))
                check(Ru.Grupo.Aviso(nil, nil) ~= nil, "Grupo.Aviso no trae lo de la ruta del grupo")
                d.uno[2]()
                local ultimo = salidos[#salidos]
                check(ultimo and ultimo.t == "3P|Ana|99601,99602" and ultimo.c == "PARTY" and ultimo.p == "Alfa", "«Pedírselas» no mandó 3P por el grupo: " .. tostring(ultimo and ultimo.t))
                -- Seguir su ruta.
                check(RG.Seguir("Ana"), "no empezó a seguir a Ana")
                check(salidos[#salidos].t == "3S|1|Ana", "no le dijo a Ana que la sigues")
                check(RG.AlMensaje("3W|1440|50.00|40.00||Mata jabalíes", "Ana"), "no leyó a dónde apunta Ana")
                check(puesto and puesto.map == 1440 and puesto.x == 50 and puesto.label == "Mata jabalíes", "tu flecha no va a donde la de Ana")
                check(viaje and viaje.ends == "follow", "no es un viaje que la sigue")
                check(type(capas["rutas.rutaGrupo"]) == "table" and capas["rutas.rutaGrupo"][1].x == 50, "su destino no salió en tu mapa")
                -- El freno: otro 3W enseguida no cuenta.
                check(not RG.AlMensaje("3W|1440|51.00|40.00||Mata jabalíes", "Ana"), "el freno dejó pasar un 3W enseguida")
                NOW = NOW + 2
                check(RG.AlMensaje("3W|1440|52.00|40.00||Mata jabalíes", "Ana") and puesto.x == 52, "la flecha no se movió con Ana")
                local d2 = RG.Aviso()
                check(d2 and d2.uno[1] == "Dejar de seguir", "mientras la sigues no ofrece «Dejar de seguir»")
                check(RG.Dejar(), "no dejó de seguir")
                check(salidos[#salidos].t == "3S|0|Ana" and puesto == nil, "al dejarla no soltó la flecha ni se lo dijo")
                -- Ahora tú guías: Ana te sigue y le mandas a dónde apunta tu flecha.
                puesto = { map = 1440, x = 30, y = 30, label = "Habla con Gornek" }
                T.map, T.x, T.y, T.label = 1440, 30, 30, "Habla con Gornek"
                NOW = NOW + 2
                check(RG.AlMensaje("3S|1|Lobato", "Ana"), "no leyó que Ana te sigue")
                check(salidos[#salidos].t == "3W|1440|30.00|30.00||Habla con Gornek", "no le mandaste a dónde apunta tu flecha: " .. tostring(salidos[#salidos].t))
                -- Ana te pide la 601: «Compartir» con tu clic (y en la pelea, espera).
                log[99601] = true
                con(C_QuestLog, { IsPushableQuest = function() return true end }, function()
                  FIRE_EVENT("PLAYER_REGEN_DISABLED")
                  local antes = #avisos
                  NOW = NOW + 31
                  check(RG.AlMensaje("3P|Lobato|99601", "Ana"), "no leyó el pedido de Ana")
                  check(#avisos == antes, "en la pelea salió el pedido de Ana")
                  FIRE_EVENT("PLAYER_REGEN_ENABLED")
                  local a = avisos[#avisos]
                  check(a and a.o and a.o.accion and a.o.accion.texto == "Compartir", "al terminar la pelea no salió «Compartir»")
                  check(#compartidas == 0, "compartió sin tu clic")
                  if a and a.o and a.o.accion then a.o.accion.alClic() end
                  check(compartidas[1] == 99601, "«Compartir» no compartió la misión")
                  check(not RG.AlMensaje("3P|Lobato|99601", "Ana"), "el freno dejó pasar otro pedido enseguida")
                end)
                -- En banda: nada.
                banda = true
                local n = #salidos
                NOW = NOW + 40
                check(not RG.AlMensaje("3W|1440|50.00|40.00||x", "Ana"), "en banda leyó la ruta del grupo")
                check(RG.Aviso() == nil and not RG.Seguir("Ana") and #salidos == n, "en banda se activó algo")
                banda = false
                -- Con el ajuste apagado: nada.
                A.Set("rutas.rutaGrupo", false)
                check(RG.Aviso() == nil and not RG.Seguir("Ana"), "con rutas.rutaGrupo apagado siguió")
                A.Set("rutas.rutaGrupo", nil)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
  RG.Reiniciar()
end)

---------------------------------------------------------------------------
-- 3. «Llévame a…»: lo más cerca primero
---------------------------------------------------------------------------

step("«Llévame a…»: lo más cerca primero, con «≈ N min» u «otro continente»", function()
  local Vj = Ru.Viaje
  if Vj.Olvidar then Vj.Olvidar() end
  local D = {
    taxi = {
      { id = 99001, name = "Lejos, Vallefresno", map = 1440, x = 90, y = 50, faction = 2 },
      { id = 99002, name = "Cerca, Vallefresno", map = 1440, x = 52, y = 50, faction = 2 },
      { id = 99003, name = "Al otro lado, Ventormenta", map = 1453, x = 50, y = 50, faction = 2 },
    },
    inns = {}, transports = {},
  }
  con(_G, { UnitFactionGroup = function() return "Horde", "Horda" end }, function()
    con(Nav, { GetTravelData = function() return D end }, function()
      con(Cp, { MapToWorld = mundo }, function()
        con(A, { PlayerPoint = function() return pt(1440, 50, 50) end }, function()
          local l = Vj.Buscar("")
          local orden = {}
          for i, d in ipairs(l) do orden[i] = d.nombre end
          check(l[1] and l[1].nombre == "Cerca, Vallefresno" and l[2].nombre == "Lejos, Vallefresno" and l[3].nombre == "Al otro lado, Ventormenta",
            "no va lo más cerca primero: " .. table.concat(orden, " / "))
          check(Vj.Distancia(l[1]):find("min", 1, true) and Vj.Distancia(l[1]):find("\226\137\136", 1, true), "la fila no dice «≈ N min»: " .. Vj.Distancia(l[1]))
          check(Vj.Distancia(l[3]) == "otro continente", "lo de otro continente no lo dice: " .. Vj.Distancia(l[3]))
          Vj.Olvidar()
        end)
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- 4. La cadena: «Llévame» a la primera que falta
---------------------------------------------------------------------------

step("La cadena: «Llévame» a la primera que falta y la de ahora marcada", function()
  local Ca = Ru.Cadena
  local Q = { [1] = { id = 1, level = 10 }, [2] = { id = 2, level = 11, pre = { 1 } }, [3] = { id = 3, level = 12, pre = { 2 }, start = { npc = { 77 } } } }
  local puesto
  con(A, { Codex = { IsLoaded = function() return true end, Quest = function(q) return Q[q] end } }, function()
    con(Cp, { IsQuestCompleted = function(q) return q == 1 end, IsOnQuest = function(q) return q == 2 end }, function()
      con(Ru.Indice, { CodexListo = function() return true end, FinDe = function() return { map = 1440, x = 33, y = 44, name = "Grunt Mojka" } end,
        Jugador = function() return { level = 11 } end }, function()
        con(Ru.Cadenas, { Siguientes = function(q) if q == 2 then return { 3 } end return {} end }, function()
          con(Ru, { TituloMision = function(q) return "Misión " .. q end, Aviso = function() end, Empezar = function() end }, function()
            con(Nav, { SetTarget = function(map, x, y, label) puesto = { map = map, x = x, label = label } return puesto end, StartTrip = function() end }, function()
              check(Ca.Abrir(2), "no abrió la cadena")
              local v = rawget(_G, "AlfaRutasCadena")
              local filas = v and v.Lista and v.Lista.filas or {}
              local ahora, boton
              for _, f in ipairs(filas) do
                if f:IsShown() and f.alfaDato then
                  if f.alfaDato.qid == 2 then ahora = f.Texto:GetText() end
                  if f.Boton and f.Boton:IsShown() then boton = f end
                end
              end
              check(ahora and ahora:find("ahora", 1, true), "la de ahora no está marcada: " .. tostring(ahora))
              check(boton and boton.alfaDato.qid == 3, "«Llévame» no está en la primera que falta")
              if boton then FIRE(boton.Boton, "OnClick", "LeftButton") end
              check(puesto and puesto.x == 33 and puesto.label == "Grunt Mojka", "«Llévame» no puso la flecha en quien la da")
              if v then v:Hide() end
            end)
          end)
        end)
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- 5. Las grises: «Soltar las N»
---------------------------------------------------------------------------

step("Las grises: «Soltar las N» con una sola confirmación que nombra cuáles", function()
  local Gr = Ru.Grises
  local dialogo, soltadas = nil, nil
  con(A, { Codex = { IsLoaded = function() return true end, Load = function() return true end } }, function()
    con(Cp, { GetLogQuests = function() return { 801, 802 } end, IsQuestReadyForTurnIn = function() return false end }, function()
      con(Ru.Cadenas, { EsGris = function() return true, 5 end }, function()
        con(Ru, { GrisValiosa = function() return nil end, TituloMision = function(q) return "Misión " .. q end, Aviso = function() end }, function()
          con(Ru.Indice, { CodexListo = function() return true end }, function()
            con(K, { Dialogo = function(o) dialogo = o end }, function()
              con(Ru.Plan, { Abandonar = function(ids) soltadas = ids return #ids end }, function()
                check(Gr.Abrir(), "no abrió «Misiones grises»")
                local v = rawget(_G, "AlfaRutasGrises")
                local b = v and v.BotonArriba
                check(b and b:IsShown() and b.Texto:GetText() == "Soltar las 2", "no salió «Soltar las 2»")
                if b then FIRE(b, "OnClick", "LeftButton") end
                check(dialogo and dialogo.titulo == "¿Soltar estas 2 misiones?" and dialogo.peligro, "no preguntó una sola vez")
                check(dialogo and dialogo.texto:find("Misión 801", 1, true) and dialogo.texto:find("Misión 802", 1, true), "la confirmación no dice cuáles")
                check(soltadas == nil, "soltó sin confirmar")
                if dialogo then dialogo.alAceptar() end
                check(soltadas and #soltadas == 2, "al confirmar no soltó las dos")
                if v then v:Hide() end
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- 6. «Zona peligrosa» con salida
---------------------------------------------------------------------------

step("«Zona peligrosa» con «Llévame a una zona de tu nivel»", function()
  local Pg = Ru.Peligro
  Pg.Reiniciar()
  local aviso, seguida
  con(N, NoEntrando, function()
    con(C_Map, { GetBestMapForUnit = function() return 1434 end }, function()
      con(A, { Maps = { GetZoneLevels = function() return 30, 35 end } }, function()
        con(Ru, { Aviso = function(t, x, o) aviso = { t = t, x = x, o = o } end }, function()
          con(Ru.Siguiente, { Buscar = function() return { id = "durotar", nombre = "Durotar 10-20" } end, Seguir = function(p) seguida = p end }, function()
            local dijo = Pg.Revisar()
            check(dijo and aviso and aviso.x:find("30", 1, true), "no avisó de la zona peligrosa")
            local a = aviso and aviso.o and aviso.o.accion
            check(a and a.texto == "Llévame a una zona de tu nivel", "el aviso no trae «Llévame a una zona de tu nivel»")
            if a then a.alClic() end
            check(seguida and seguida.id == "durotar", "el botón no abrió la guía para tu nivel")
          end)
        end)
      end)
    end)
  end)
  Pg.Reiniciar()
end)

---------------------------------------------------------------------------
-- 7. Al entrar, en silencio
---------------------------------------------------------------------------

step("Al entrar, la piedra de hogar a tiempo no habla", function()
  local Hg = Ru.Hogar
  Hg.Reiniciar()
  con(N, { Entrando = function() return true end }, function()
    local dijo, por = Hg.Revisar()
    check(not dijo and por == "entrando", "al entrar la piedra de hogar habló: " .. tostring(por))
  end)
end)

print(string.format("PRUEBA: 1.3.3 rutas, %d pasos, %d errores", pasos, #ERRORS))
