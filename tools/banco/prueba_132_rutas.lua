-- Prueba de la 1.3.2, lo de Aventura y Mundo (tools/prueba.py la corre con las demás prueba_*.lua):
--   1. la piedra de hogar a tiempo sin el Codex (la base de misiones dice a
--      quién se entrega cada una), sin cargarlo;
--   2. «Sube al nivel N»: dónde rinde más sin el Codex;
--   3. «Misiones grises»: sin el Codex, la tarjeta sale sin número;
--   4. los avisos de grupo esperan al final de la pelea;
--   5. en el mapa del grupo, la entrega con el ícono de entregar;
--   6. «Ir al mapa del juego» desde la página: donde estás;
--   7. un solo nombre: «Capas de Alfa» y «Mapa de Alfa»;
--   8. barcos en minutos hasta el último minuto (el texto exacto al pasar el
--      ratón) y el circuito que cede;
--   9. la distancia de respaldo del rastreador, traducida.
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
local function check(cond, msg) if not cond then NOTE("1.3.2 rutas", msg) end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local A = AlfaNucleo.A
local N = AlfaNucleo
local K = AlfaNucleo.Kit
local Ru = NS_OF("Alfa_Rutas")
local Mu = NS_OF("Alfa_Mundo")
local Nav = A.Nav
local Cp = A.Compat

local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do t[k] = a.v end
  if not ok then error(e) end
end

-- Un mundo de mentira: 1440 en el continente 1 y 1453 en el 0.
local function mundo(map, x, y)
  if map == 1440 then return 1, y * 100, x * 100 end
  if map == 1453 then return 0, y * 10, x * 10 end
  return nil
end
local function pt(map, x, y) return { map = map, x = x, y = y } end

-- El Codex sin cargar: si alguien lo carga, se anota.
local cargas = 0
local CODEX_NO = { IsLoaded = function() return false end, Load = function() cargas = cargas + 1 return false, "disabled" end }

-- Una base de misiones de mentira, con la forma de A.QuestDB.
local function base(quests, npcs, objetos)
  return {
    IsLoaded = function() return true end,
    F = { LEVEL = 2, FINISH = 8, OBJ = 12 },
    QuestRecord = function(id) return quests[id] end,
    Each = function(v)
      if type(v) == "table" then return ipairs(v) end
      if v == nil then return function() end, nil, 0 end
      return function(_, i) if i == 0 then return 1, v end end, nil, 0
    end,
    EachSpawn = function(ref, fn, a, b)
      local n = npcs[ref]
      for i, s in ipairs(n and n.spawns or {}) do fn(a, b, s.map, s.f, s.x, s.y, 10, i) end
      return n and #n.spawns or 0
    end,
    EntityName = function(ref) local n = npcs[ref] return n and n.name end,
    GetItemDroppers = function(id) return objetos and objetos[id] end,
  }
end

local function conAvisos(fn)
  local avisos = {}
  con(K, { Aviso = function(o) avisos[#avisos + 1] = o end, PorLya = function() return false end }, fn)
  return avisos
end

---------------------------------------------------------------------------
-- 1. La piedra de hogar a tiempo, sin el Codex
---------------------------------------------------------------------------

step("La piedra de hogar a tiempo sale sin el Codex (con la base de misiones) y no lo carga", function()
  local Hg = Ru.Hogar
  check(Ru.Ligero and Ru.Ligero.Entrega, "falta Ligero.lua")
  local quests = { [911] = { [8] = 21 }, [912] = { [8] = 22 }, [913] = { [8] = 23 }, [914] = { [8] = 24 } }
  local npcs = {
    [21] = { name = "Thrall", spawns = { pt(1453, 40, 40) } }, [22] = { name = "Nazgrel", spawns = { pt(1453, 41, 41) } },
    [23] = { name = "Rehgar", spawns = { pt(1453, 42, 39) } }, [24] = { name = "Gornek", spawns = { pt(1440, 50, 50) } },
  }
  cargas = 0
  Hg.Reiniciar()
  con(A, { Codex = CODEX_NO, QuestDB = base(quests, npcs), PlayerPoint = function() return pt(1440, 50, 50) end }, function()
    con(Cp, { MapToWorld = mundo, GetLogQuests = function() return { 911, 912, 913, 914 } end,
      IsQuestReadyForTurnIn = function() return true end,
      GetItemCount = function(id) return id == 6948 and 1 or 0 end,
      GetPlayerWorldPosition = function() return 1, 5000, 5000 end }, function()
      con(A.Nav, { BoundInn = function() return { c = 0, wx = 400, wy = 400 } end }, function()
        con(C_Container, { GetItemCooldown = function() return 0, 0, 1 end }, function()
          con(Ru, { TituloMision = function(q) return "Misión " .. q end }, function()
            local l = Ru.Vuelta.Listas(true)
            check(l and #l == 4 and l[1].p and l[1].p.name == "Thrall", "sin el Codex no supo a quién se entrega cada misión")
            local dijo, por
            local avisos = conAvisos(function() dijo, por = Hg.Revisar() end)
            check(dijo and por == "aviso", "sin el Codex la piedra de hogar no avisó: " .. tostring(por))
            check(avisos[1] and avisos[1].texto:find("3 de tus 4", 1, true), "el aviso no dice «3 de tus 4»")
          end)
        end)
      end)
    end)
  end)
  check(cargas == 0, "la piedra de hogar cargó el Codex")
  Hg.Reiniciar()
end)

---------------------------------------------------------------------------
-- 2. «Sube al nivel N» sin el Codex
---------------------------------------------------------------------------

step("«Sube al nivel N»: dónde rinde más, sin el Codex", function()
  local Nv = Ru.Nivel
  local quests = { [801] = { [2] = 12, [12] = { 1, 21, 8 } }, [802] = { [2] = 13, [12] = { 2, 500, 5 } } }
  local npcs = {
    [21] = { name = "Jabalí moteado", spawns = { pt(1440, 52, 50) } },  -- 200 yd
    [31] = { name = "Ladrón Mano Negra", spawns = { pt(1440, 51, 50) } }, -- 100 yd, suelta el objeto de 802
  }
  local objetos = { [500] = { { id = 31, name = "Ladrón Mano Negra", chance = 40 } } }
  cargas = 0
  con(A, { Codex = CODEX_NO, QuestDB = base(quests, npcs, objetos), PlayerPoint = function() return pt(1440, 50, 50) end }, function()
    con(Cp, { MapToWorld = mundo, GetLogQuests = function() return { 801, 802 } end, IsQuestReadyForTurnIn = function() return false end,
      GetQuestLevel = function(q) return quests[q] and quests[q][2] end }, function()
      con(Ru.Indice, { Jugador = function() return { level = 12, xp = 600, xpMax = 1000 } end }, function()
        Nv.Olvidar()
        local r = Nv.DondeRinde(true)
        check(r and r.npc == 31 and r.mision == 802, "sin el Codex no dijo dónde rinde más: " .. tostring(r and r.nombre))
        check(r and r.p and r.p.x == 51, "el lugar no es el del enemigo")
        local d = Nv.Aviso({ index = 4, goals = { { t = "level", status = "active", xpLeft = 400, subject = "13" } } }, 4)
        check(d and d.texto and d.texto:find("Ladrón Mano Negra", 1, true) and d.uno, "el aviso de nivel no dice dónde rinde más")
      end)
    end)
  end)
  check(cargas == 0, "«Sube al nivel» cargó el Codex")
  Nv.Olvidar()
end)

---------------------------------------------------------------------------
-- 3. «Misiones grises» sin el Codex
---------------------------------------------------------------------------

step("Sin el Codex la tarjeta de grises sale sin número; su clic lo carga", function()
  local Gr = Ru.Grises
  check(Gr and Gr.SinJuzgar and Ru.OpcionesPagina, "faltan Grises.SinJuzgar y la lista de la página")
  local abrio = 0
  con(A, { Codex = CODEX_NO }, function()
    con(Cp, { GetLogQuests = function() return { 8131, 8132 } end, IsQuestReadyForTurnIn = function() return false end }, function()
      con(Ru.Cadenas, { EsGris = function(q) return q == 8131, 5 end }, function()
        con(Gr, { Abrir = function() abrio = abrio + 1 return true end }, function()
          check(Gr.Cuantas() == 0 and Gr.SinJuzgar() == 1, "sin el Codex no supo que tienes 1 gris")
          local tarjeta
          for _, o in ipairs(Ru.OpcionesPagina and Ru.OpcionesPagina() or {}) do
            if o.titulo == "Misiones grises" then tarjeta = o end
          end
          check(tarjeta and not tarjeta.texto:find("%d") and tarjeta.texto:find("grises", 1, true), "sin el Codex no salió la tarjeta sin número")
          if tarjeta then tarjeta.alClic() end
          check(abrio == 1, "la tarjeta no abre «Misiones grises» (que carga el Codex)")
        end)
      end)
    end)
  end)
  check(cargas == 0, "la página cargó el Codex")
end)

---------------------------------------------------------------------------
-- 4. Los avisos de grupo esperan a que termine la pelea
---------------------------------------------------------------------------

step("Los avisos de grupo no salen en la pelea y vuelven al terminar", function()
  local Gr = Ru.Grupo
  Gr.Reiniciar()
  local repintes = 0
  con(_G, {
    IsInGroup = function() return true end, GetNumGroupMembers = function() return 2 end,
    UnitExists = function(u) return u == "player" or u == "party1" end,
    UnitName = function(u) if u == "party1" then return "Ana" end return "Lobato" end,
  }, function()
    con(C_QuestLog, { IsPushableQuest = function() return true end, IsUnitOnQuest = function() return false end }, function()
      con(Cp, { GetLogQuests = function() return { 902 } end }, function()
        con(Ru, { TituloMision = function(q) return "Misión " .. q end }, function()
          con(Ru.Rastreador, { Luego = function() repintes = repintes + 1 end }, function()
            check(Gr.Aviso(nil, nil) ~= nil, "fuera de combate no ofreció compartir")
            FIRE_EVENT("PLAYER_REGEN_DISABLED") -- (como en el juego: aún sin bloqueo)
            Gr.Olvidar()
            check(Gr.Aviso(nil, nil) == nil, "en la pelea salió el aviso de compartir")
            con(_G, { InCombatLockdown = function() return true end }, function()
              check(Gr.Aviso(nil, nil) == nil, "con el bloqueo de combate salió el aviso")
            end)
            local antes = repintes
            FIRE_EVENT("PLAYER_REGEN_ENABLED")
            check(repintes > antes, "al terminar la pelea no repintó el rastreador")
            check(Gr.Aviso(nil, nil) ~= nil, "al terminar la pelea el aviso no volvió")
          end)
        end)
      end)
    end)
  end)
  Gr.Reiniciar()
end)

---------------------------------------------------------------------------
-- 5. El mapa del grupo: la entrega con su ícono
---------------------------------------------------------------------------

step("En el mapa del grupo la entrega usa el ícono de entregar", function()
  local Mg = Ru.MapaGrupo
  local lista = false
  Mg.Olvidar()
  con(_G, { IsInGroup = function() return true end, IsInRaid = function() return false end,
    UnitExists = function(u) return u == "player" or u == "party1" end,
    UnitName = function(u) if u == "party1" then return "Ana" end return "Lobato" end }, function()
    con(C_QuestLog, { IsUnitOnQuest = function(u, q) return u == "party1" and q == 601 end }, function()
      con(A, { Codex = { IsLoaded = function() return true end, Quest = function(q) return { id = q } end } }, function()
        con(Cp, { GetLogQuests = function() return { 601 } end, IsOnQuest = function(q) return q == 601 end,
          IsQuestReadyForTurnIn = function() return lista end }, function()
          con(Ru.Indice, { PasosMision = function() return { objetivo = pt(1440, 40, 40), fin = pt(1440, 45, 45) } end }, function()
            con(Ru, { TituloMision = function(q) return "Misión " .. q end }, function()
              local p = Mg.Pines()
              check(p[1] and p[1].icon == "map:kill", "lo que falta no usa el ícono de siempre")
              lista = true
              p = Mg.Pines()
              check(p[1] and p[1].x == 45 and p[1].icon == "map:quest-turnin", "la entrega no usa «map:quest-turnin»: " .. tostring(p[1] and p[1].icon))
            end)
          end)
        end)
      end)
    end)
  end)
  Mg.Olvidar()
end)

---------------------------------------------------------------------------
-- 6. «Ir al mapa del juego» desde la página
---------------------------------------------------------------------------

step("«Ir al mapa del juego» con el mapa de Alfa cerrado abre donde estás", function()
  local V = Mu.Ventana
  check(V and V.AlMapaDelJuego, "falta Ventana.AlMapaDelJuego")
  if V.Visible() then V.Cerrar() end
  local abierto
  con(Cp, { CanOpenWorldMap = function() return true end, OpenWorldMap = function(m) abierto = m or "nada" return true end,
    GetPlayerMapPosition = function() return 1411, 50, 50 end }, function()
    V.AlMapaDelJuego()
  end)
  check(abierto == 1411, "abrió el mapa del juego en otra zona: " .. tostring(abierto))
end)

---------------------------------------------------------------------------
-- 7. Un solo nombre
---------------------------------------------------------------------------

step("Un solo nombre: «Capas de Alfa» y «Mapa de Alfa» en la lupa, el botón, el panel y la ventana", function()
  local MJ = Mu.MapaJuego
  -- La lupa del mapa del juego.
  local hechos = {}
  local function menu()
    local m = {}
    function m:CreateButton(t) hechos[#hechos + 1] = t return menu() end
    function m:CreateCheckbox(t) hechos[#hechos + 1] = t return { SetEnabled = function() end } end
    function m:CreateDivider() end
    function m:CreateTitle(t) end
    return m
  end
  check(MJ and MJ.Menu, "falta MapaJuego.Menu")
  if MJ and MJ.Menu then MJ.Menu(nil, menu()) end
  local tiene = {}
  for _, t in ipairs(hechos) do tiene[t] = true end
  check(tiene["Capas de Alfa"], "la lupa no dice «Capas de Alfa»: " .. table.concat(hechos, ", "))
  check(tiene["Mapa de Alfa"], "la lupa no dice «Mapa de Alfa»")
  -- El botón y el panel.
  if MJ and MJ.CrearBarra then MJ.CrearBarra() end
  local barra = rawget(_G, "AlfaMundoBotonesMapa")
  check(barra and barra.Abrir and barra.Abrir.Texto:GetText() == "Mapa de Alfa", "el botón del mapa del juego no dice «Mapa de Alfa»")
  local P = Mu.Panel
  if P and P.Alternar then P.Alternar(UIParent, {}) end
  local panel = rawget(_G, "AlfaMundoCapas")
  check(panel and panel.Titulo and panel.Titulo:GetText() == "Capas de Alfa", "el panel no se llama «Capas de Alfa»")
  if P and P.Ocultar then P.Ocultar() end
  -- La ventana del mapa de Alfa.
  local V = Mu.Ventana
  V.Abrir()
  local w = rawget(_G, "AlfaMundoMapa")
  check(w and w.Cabecera and w.Cabecera.Titulo:GetText() == "Mapa de Alfa", "la ventana no se llama «Mapa de Alfa»: "
    .. tostring(w and w.Cabecera and w.Cabecera.Titulo:GetText()))
  V.Cerrar()
end)

---------------------------------------------------------------------------
-- 8. Barcos en minutos y el circuito que cede
---------------------------------------------------------------------------

local DATOS = {
  taxi = {}, inns = {},
  transports = {
    { id = "zeppelin-orgrimmar-undercity", kind = "zeppelin", faction = 2,
      a = { name = "Orgrimmar", map = 1411, x = 50.8, y = 13.5 }, b = { name = "Undercity", map = 1420, x = 60.7, y = 58.9 } },
  },
}

step("Barcos: «4 min» hasta el último minuto, el texto exacto al pasar el ratón", function()
  local Bc = Ru.Barcos
  check(Bc.Insignia and Bc.Insignia(230) == "4 min" and Bc.Insignia(80) == "2 min" and Bc.Insignia(45) == "0:45"
    and Bc.Insignia(0) == "¡Ya!", "la insignia no va en minutos hasta el último minuto")
  local sets, t0 = 0, GetTime()
  local llega = 300
  local X = {
    Now = function() return GetTime() end,
    NextArrival = function(kind, id, now, lado) if lado == "a" then return llega - (now - t0), llega + 30 - (now - t0), true end return nil end,
    NextDeparture = function() return 175, 100, false end,
  }
  local pines
  WorldMapFrame:Hide()
  con(Nav, { GetTravelData = function() return DATOS end }, function()
    con(A, { Transit = X, Pins = { SetLayer = function(n, p) if n == "rutas.barcos" then sets = sets + 1 pines = p end end, ClearLayer = function() end } }, function()
      WorldMapFrame:Show()
      check(sets == 1, "al abrir el mapa no puso la capa")
      RUN_TIMERS(3)
      check(sets == 1, "con más de un minuto la capa se volvió a publicar cada segundo (" .. sets .. ")")
      -- El cuadro del ratón: el texto exacto de ahora.
      local lineas = {}
      local tip = { SetText = function(_, t) lineas[#lineas + 1] = t end, AddLine = function(_, t) lineas[#lineas + 1] = t end }
      local conCuenta
      for _, p in ipairs(pines or {}) do if p.badge then conCuenta = p end end
      check(conCuenta and conCuenta.badge:find("min", 1, true), "la insignia no dice los minutos")
      if conCuenta then conCuenta.tooltip(tip) end
      local exacto = Bc.TextoDe("zeppelin-orgrimmar-undercity", "a") or ""
      check(lineas[2] == exacto and exacto:find("%d:%d%d"), "el cuadro del ratón no trae el texto exacto: " .. tostring(lineas[2]))
      -- En el último minuto, al segundo.
      llega = 50 + (GetTime() - t0)
      RUN_TIMERS(1)
      local antes = sets
      RUN_TIMERS(3)
      check(sets >= antes + 2, "en el último minuto no se puso al día cada segundo")
      WorldMapFrame:Hide()
    end)
  end)
end)

step("El circuito cede mientras ordena (el 2-opt no traba el juego)", function()
  local Ci = Ru.Circuito
  local paradas = {}
  for i = 1, 12 do paradas[i] = { inP = pt(1440, 10 + i * 3 % 37, 50), outP = pt(1440, 10 + i * 3 % 37, 50), deps = {} } end
  local veces = 0
  local orden
  con(Cp, { MapToWorld = mundo }, function()
    orden = Ci.Ordenar(paradas, pt(1440, 50, 50), function() veces = veces + 1 end)
  end)
  check(orden and #orden == 12, "el circuito perdió paradas")
  check(veces >= 12, "el circuito no cedió al ordenar (" .. veces .. " veces)")
end)

---------------------------------------------------------------------------
-- 9. La distancia de respaldo, traducida
---------------------------------------------------------------------------

step("La distancia de respaldo del rastreador sale de una clave traducida", function()
  local L = Ru.L
  check(L and L["%d yardas"] ~= nil, "falta la clave «%d yardas»")
  -- En el banco el idioma es esMX: «120 yardas».
  check(format(L["%d yardas"], 120) == "120 yardas", "la distancia no dice «120 yardas»: " .. tostring(format(L["%d yardas"], 120)))
end)

print(string.format("PRUEBA: 1.3.2 rutas, %d pasos, %d errores", pasos, #ERRORS))
