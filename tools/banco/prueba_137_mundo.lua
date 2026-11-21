-- Prueba de la 1.3.7, área «mundo»: Mazmorras, Mundo, Enciclopedia y La Jauría
-- (tools/prueba.py la corre con las demás):
--   1. Mazmorras recalcula menos (112): QUEST_LOG_UPDATE sin cambios en tu
--      registro no rehace el plan; una misión lista sí;
--   2. la recomendada mira la distancia (108) y ofrece «Recoger sus misiones
--      ya» si la siguiente se abre pronto (109); la tarjeta de Hoy (110) y lo
--      de dentro (111) para otras áreas;
--   3. el cronómetro (192): la vuelta, el récord y el límite de instancias;
--   4. lo que te falta antes de un jefe (184), chico y fuera de combate;
--   5. el botín de tu grupo (186): tiradas y ganadores, sin anunciar nada;
--   6. el mapa de los jefes (181) y las páginas de Mazmorras sin errores;
--   7. el mapa de Alfa: sus atajos la primera vez y sus errores en el mapa (124);
--   8. la Enciclopedia: la experiencia a tu nivel (113), la guía y el circuito
--      de la zona (114) y su tamaño (115);
--   9. La Jauría: las misiones en común en la tarjeta (116);
--  10. los plurales (78).
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
local function check(cond, msg) if not cond then NOTE("1.3.7 mundo", msg) end end
local function T(n) RUN_TIMERS(n or 3) end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
local N = AlfaNucleo
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
NOW = NOW + 120

local Mz = NS_OF("Alfa_Mazmorras")
local D, P, V = Mz.D, Mz.P, Mz.V

-- Cambia campos de una tabla mientras corre fn.
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = t[k] } t[k] = v end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do t[k] = a.v end
  if not ok then error(e, 0) end
end

local avisos = {}
local function conAvisos(fn)
  avisos = {}
  con(K, { Aviso = function(o) avisos[#avisos + 1] = o return true end }, fn)
end

---------------------------------------------------------------------------
-- 1. Recalcula menos
---------------------------------------------------------------------------
step("112: el botín no rehace el plan de la mazmorra", function()
  local registro = { { questID = 100 }, { questID = 101 } }
  local listas = {}
  con(C_QuestLog, {
    GetNumQuestLogEntries = function() return #registro, #registro end,
    GetInfo = function(i) return registro[i] end,
    IsComplete = function(id) return listas[id] == true end,
  }, function()
    FIRE_EVENT("QUEST_LOG_UPDATE")
    P.Estado("deadmines")
    local antes = P.recalculos
    for _ = 1, 5 do FIRE_EVENT("QUEST_LOG_UPDATE") P.Estado("deadmines") end
    check(P.recalculos == antes, "con cada QUEST_LOG_UPDATE sin cambios se rehízo el plan (" .. (P.recalculos - antes) .. " veces)")
    listas[101] = true
    FIRE_EVENT("QUEST_LOG_UPDATE")
    P.Estado("deadmines")
    check(P.recalculos == antes + 1, "una misión que quedó lista no rehízo el plan")
    FIRE_EVENT("QUEST_ACCEPTED", 1, 102)
    P.Estado("deadmines")
    check(P.recalculos == antes + 2, "tomar una misión no rehízo el plan")
  end)
  -- El texto de una misión en curso se lee al momento.
  check(P.Texto({ texto = "fijo" }) == "fijo", "P.Texto sin vivo no devolvió su texto")
end)

---------------------------------------------------------------------------
-- 2. La recomendada, «Recoger sus misiones ya», Hoy y dentro
---------------------------------------------------------------------------
local LISTA = {
  { key = "lejos", name = "Mazmorra lejana", kind = "dungeon", minLevel = 17, maxLevel = 24, entrance = { map = 1, x = 50, y = 50 }, quests = { A = 0, H = 0 } },
  { key = "cerca", name = "Mazmorra cercana", kind = "dungeon", minLevel = 18, maxLevel = 25, entrance = { map = 2, x = 50, y = 50 }, quests = { A = 0, H = 0 } },
  { key = "pronto", name = "Mazmorra de después", kind = "dungeon", minLevel = 30, maxLevel = 38, entrance = { map = 2, x = 40, y = 40 }, quests = { A = 0, H = 0 } },
}
local function estadoVacio(recoger)
  local r = {}
  for i = 1, recoger or 0 do r[i] = { quest = { id = 900 + i, title = "M" .. i } } end
  return { key = "x", recoger = r, esperan = {}, listas = 0, llevas = 0, lista = {}, camino = {} }
end
local function conMazmorras(campos, fn)
  local base = {
    Listo = function() return true end, Lista = function() return LISTA end, MazmorraActual = function() return nil end,
    Nivel = function() return 21 end, Lado = function() return "H" end, Hecha = function() return nil end,
    Cuenta = function() return 0, 3 end, Info = function(k) for _, d in ipairs(LISTA) do if d.key == k then return d end end end,
  }
  for k, v in pairs(campos or {}) do base[k] = v end
  con(D, base, fn)
end

step("108: entre dos de tu nivel, la de tu continente", function()
  conMazmorras(nil, function()
    con(A, { PlayerPoint = function() return { map = 2, x = 10, y = 10 } end,
      DirectTravelCost = function(_, en) return en.map == 2 and 120 or 3600 end }, function()
      con(P, { Estado = function() return estadoVacio(0) end }, function()
        local r = AlfaMazmorras.Recomendada()
        check(r and r.key == "cerca", "la recomendada te mandó a otro continente: " .. tostring(r and r.key))
        check(V.Lejania(LISTA[1], { map = 2 }) == 3600, "V.Lejania no midió")
      end)
    end)
  end)
end)

step("109/110: la siguiente que se abre pronto ofrece «Recoger sus misiones ya»; la tarjeta de Hoy", function()
  conMazmorras({ Nivel = function() return 28 end }, function()
    con(P, { Estado = function() return estadoVacio(2) end }, function()
      local t = AlfaMazmorras.Tarjeta()
      check(t and t.key == "pronto" and t.modo == "pronto", "no salió la siguiente mazmorra")
      check(t and t.accion and t.accion.texto == "Recoger sus misiones ya", "la tarjeta no ofrece «Recoger sus misiones ya»: " .. tostring(t and t.accion and t.accion.texto))
      check(t and t.texto:find("2 misiones para recoger", 1, true), "la tarjeta no dice cuántas recoge: " .. tostring(t and t.texto))
    end)
  end)
  conMazmorras(nil, function()
    con(P, { Estado = function() return estadoVacio(1) end }, function()
      local t = AlfaMazmorras.Tarjeta()
      check(t and t.texto:find("1 misión para recoger", 1, true), "plural: " .. tostring(t and t.texto))
      check(t and t.accion.texto == "Prepárame", "la de tu nivel no dice «Prepárame»")
    end)
  end)
end)

step("111: dentro de una mazmorra, el siguiente jefe y tus misiones de ahí", function()
  local jefes = { { id = "1", npc = 1, nombre = "Uno", indice = 1 }, { id = "2", npc = 2, nombre = "Dos", indice = 2 }, { id = "3", npc = 3, nombre = "Tres", final = true, indice = 3 } }
  conMazmorras({ MazmorraActual = function() return "cerca" end, Jefes = function() return jefes end,
    Vencido = function(_, id) return id == "1" and { t = 1 } or nil end, Descubierto = function() return true end,
    Cuenta = function() return 1, 3 end }, function()
    con(Mz.EnVivo, { LeerMisiones = function() return { { texto = "«A»", lista = true }, { texto = "«B»: 2/5", lista = false } } end }, function()
      local enInst = IsInInstance
      IsInInstance = function() return true, "party" end -- (1.3.7: fuera de una instancia ni pregunta)
      local t = AlfaMazmorras.Dentro()
      IsInInstance = enInst
      check(AlfaMazmorras.Dentro() == nil, "fuera de una instancia, Dentro() debe salir sin cargar nada")
      check(t and t.jefe and t.jefe.nombre == "Dos" and t.jefe.n == 2, "no dice el siguiente jefe")
      check(t and #t.misiones == 2 and t.faltan == 1, "no dice tus misiones de ahí")
      -- El mapa de los jefes: el vencido en verde, el siguiente marcado.
      local m = V.DatosMapa("cerca")
      check(#m == 3 and m[1].vencido and m[2].siguiente and not m[3].siguiente, "el mapa de jefes no marca vencido y siguiente")
      local f = Mz.Pz.MapaJefes(UIParent)
      f:Set(m)
      local h = f:Acomodar(500)
      check(h > 20, "el mapa de jefes no tiene alto")
      local h2 = f:Acomodar(150)
      check(h2 > h, "con poco ancho, el mapa de jefes no pasó a otra fila")
    end)
  end)
end)

---------------------------------------------------------------------------
-- 3. El cronómetro
---------------------------------------------------------------------------
step("192: tu récord y el límite de instancias por hora", function()
  local Cr = Mz.Crono
  N.Datos("mazmorras").horas = {}
  N.DatosPersonaje("mazmorras").crono = {}
  N.DatosPersonaje("mazmorras").vuelta = nil
  local mapa = 36
  INSTANCE_RESET_SUCCESS = type(rawget(_G, "INSTANCE_RESET_SUCCESS")) == "string" and INSTANCE_RESET_SUCCESS or "%s has been reset."
  con(_G, { IsInInstance = function() return true, "party" end, GetServerTime = function() return NOW end,
    GetInstanceInfo = function() return "Minas", "party", 1, "", 5, 0, false, mapa end }, function()
    conMazmorras({ MazmorraActual = function() return "cerca" end }, function()
      Cr.AlEntrar()
      check(Cr.Estado().hora == 1, "la primera entrada no contó")
      Cr.AlEntrar()
      check(Cr.Estado().hora == 1, "volver a la misma instancia contó otra vez")
      NOW = NOW + 25 * 60
      local r = Cr.Fin("cerca")
      check(r and r.seg >= 25 * 60 and r.primera, "la vuelta no midió su tiempo")
      check(Cr.Record("cerca") == r.seg, "no guardó el récord")
      -- Otra vuelta, más rápida: récord nuevo.
      FIRE_EVENT("CHAT_MSG_SYSTEM", INSTANCE_RESET_SUCCESS:format("Minas"))
      NOW = NOW + 5
      Cr.AlEntrar()
      check(Cr.Estado().hora == 2, "tras reiniciarla, la entrada no contó como nueva")
      NOW = NOW + 20 * 60
      local r2 = Cr.Fin("cerca")
      check(r2 and r2.record, "una vuelta más rápida no fue récord")
      -- Cinco instancias en la hora: «puedes entrar a otra en ...».
      for i = 1, 3 do mapa = 100 + i Cr.AlEntrar() end
      local e = Cr.Estado()
      check(e.hora == 5 and e.libreEn and e.libreEn > 0, "con 5 instancias no dice cuándo puedes entrar")
      local linea = Cr.Linea()
      check(linea and linea:find("puedes entrar a otra en", 1, true), "la línea del límite: " .. tostring(linea))
      NOW = NOW + 3700
      check(Cr.Estado().hora == 0, "las entradas de hace más de una hora siguen contando")
    end)
  end)
end)

---------------------------------------------------------------------------
-- 4. Antes de un jefe
---------------------------------------------------------------------------
step("184: lo que te falta antes de un jefe, una vez y fuera de combate", function()
  local Co = Mz.Consumibles
  Co.Olvidar()
  local bufos = {}
  con(_G, { C_UnitAuras = { GetAuraDataByIndex = function(_, i) return bufos[i] end },
    UnitClass = function() return "Cazador", "HUNTER", 3 end,
    GetInventoryItemCount = function() return 120 end,
    IsInInstance = function() return true, "party" end }, function()
    conMazmorras({ Nivel = function() return 40 end, Vencido = function() return nil end }, function()
      conAvisos(function()
        local f = Co.Faltas(false)
        local s = table.concat(f, " | ")
        check(s:find("Bien alimentado", 1, true) and s:find("te quedan 120", 1, true), "no dijo comida y munición: " .. s)
        check(not s:find("elixir", 1, true), "fuera de banda pidió elixir")
        Co.AlJefe("cerca", { id = "1", nombre = "Uno" })
        T(2)
        check(#avisos == 1 and avisos[1].titulo:find("Uno", 1, true), "no salió el aviso antes del jefe")
        Co.AlJefe("cerca", { id = "1", nombre = "Uno" })
        T(2)
        check(#avisos == 1, "el aviso del mismo jefe salió dos veces")
        bufos[1] = { spellId = 19705, icon = 136000, name = "Bien alimentado" }
        check(not table.concat(Co.Faltas(false), " "):find("alimentado", 1, true), "con «Bien alimentado» pidió comida")
        con(_G, { InCombatLockdown = function() return true end }, function()
          check(Co.AlJefe("cerca", { id = "2", nombre = "Dos" }) == false, "en combate se revisó")
        end)
        A.Set("mazmorras.consumibles", false)
        check(Co.AlJefe("cerca", { id = "3", nombre = "Tres" }) == false, "apagado, igual avisó")
        A.Set("mazmorras.consumibles", true)
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- 5. El botín de tu grupo
---------------------------------------------------------------------------
step("186: quién se llevó qué y con qué tirada, sin anunciar nada", function()
  local Hb = Mz.Historial
  Hb.Borrar()
  LOOT_ROLL_ROLLED_NEED = type(rawget(_G, "LOOT_ROLL_ROLLED_NEED")) == "string" and LOOT_ROLL_ROLLED_NEED or "Need Roll - %d for %s by %s"
  LOOT_ROLL_ROLLED_GREED = type(rawget(_G, "LOOT_ROLL_ROLLED_GREED")) == "string" and LOOT_ROLL_ROLLED_GREED or "Greed Roll - %d for %s by %s"
  LOOT_ROLL_WON = type(rawget(_G, "LOOT_ROLL_WON")) == "string" and LOOT_ROLL_WON or "%s won: %s"
  LOOT_ITEM = type(rawget(_G, "LOOT_ITEM")) == "string" and LOOT_ITEM or "%s receives loot: %s."
  local espada = "|cff0070dd|Hitem:2000::::::::|h[Espada azul]|h|r"
  local gris = "|cff9d9d9d|Hitem:2001::::::::|h[Basura]|h|r"
  local enviados = 0
  con(_G, { IsInGroup = function() return true end, SendChatMessage = function() enviados = enviados + 1 end }, function()
    con(A.Compat, { IsInInstance = function() return true end }, function()
      conMazmorras({ MazmorraActual = function() return "cerca" end }, function()
        FIRE_EVENT("CHAT_MSG_LOOT", LOOT_ROLL_ROLLED_NEED:format(87, espada, "Ana"))
        FIRE_EVENT("CHAT_MSG_LOOT", LOOT_ROLL_ROLLED_GREED:format(40, espada, "Beto"))
        FIRE_EVENT("CHAT_MSG_LOOT", LOOT_ROLL_WON:format("Ana", espada))
        FIRE_EVENT("CHAT_MSG_LOOT", LOOT_ITEM:format("Ana", espada))
        FIRE_EVENT("CHAT_MSG_LOOT", LOOT_ITEM:format("Beto", gris))
      end)
    end)
  end)
  local l = Hb.Lista()
  check(#l == 1, "el historial no tiene una entrada (tiene " .. #l .. ")")
  local e = l[1]
  check(e and e.quien == "Ana" and e.tirada == 87 and e.tipo == "necesidad" and e.k == "cerca", "no guardó quién, tirada y mazmorra")
  check(e and Hb.Linea(e) == "Ana \194\183 Necesidad 87", "la línea: " .. tostring(e and Hb.Linea(e)))
  check(enviados == 0, "se mandó algo al chat")
  -- Un texto con los huecos en otro orden (otro idioma).
  local p, orden = D.PatronOrden("%2$s por %1$s")
  check(p and orden[1] == 2 and orden[2] == 1, "PatronOrden no leyó el orden de los huecos")
end)

---------------------------------------------------------------------------
-- 6. Las páginas de Mazmorras
---------------------------------------------------------------------------
step("181: las páginas de Mazmorras se pintan sin errores", function()
  local ok, e = pcall(function()
    AlfaMazmorras.Abrir()
    T(2)
    V.Ir("progreso")
    T(2)
    local lista = D.Lista()
    if lista[1] then
      V.AbrirMazmorra(lista[1].key, "jefes")
      T(2)
      V.Pestana("resumen")
      T(2)
    end
  end)
  check(ok, "una vista de Mazmorras falló: " .. tostring(e))
end)

---------------------------------------------------------------------------
-- 7. El mapa de Alfa
---------------------------------------------------------------------------
step("124: el mapa enseña sus atajos la primera vez y sus errores salen en el mapa", function()
  local Mu = NS_OF("Alfa_Mundo")
  local Vm = Mu.Ventana
  N.Datos("mundo").atajosVistos = nil
  Vm.Abrir()
  T(1)
  check(Vm.AtajosVisibles(), "la primera vez no salieron los atajos del mapa")
  local antes = rawget(_G, "PRINTED") or 0
  Vm.Decir("Ahí no se puede poner la flecha.")
  check((rawget(_G, "PRINTED") or 0) == antes, "con el mapa abierto el error salió en el chat")
  check(Vm.mensaje == "Ahí no se puede poner la flecha.", "el error no salió en el mapa")
  T(5)
  check(Vm.mensaje == nil, "el letrero del mapa no se fue solo")
  Vm.OcultarAtajos(true)
  Vm.Cerrar()
  Vm.Abrir()
  T(1)
  check(not Vm.AtajosVisibles(), "los atajos volvieron a salir")
  Vm.Cerrar()
  Vm.Decir("x")
  check((rawget(_G, "PRINTED") or 0) > antes, "con el mapa cerrado el error no salió en el chat")
end)

---------------------------------------------------------------------------
-- 8. La Enciclopedia
---------------------------------------------------------------------------
step("113/114/115: la experiencia a tu nivel, la guía de la zona y el tamaño", function()
  local En = NS_OF("Alfa_Enciclopedia")
  local F = En.F
  local q = { xp = 1250, level = 20 }
  check(F.XPTuya(q, 22) == 1250, "a 2 niveles arriba no da toda la experiencia")
  local x = F.XPTuya(q, 27)
  check(x and x < 1250 and x > 0, "7 niveles arriba no da menos: " .. tostring(x))
  check(F.XPTuya(q, 60) == 0, "al 60 dio experiencia")
  local _, gris = F.XPTuya(q, 40)
  check(gris == true, "una misión 20 niveles abajo no salió gris")
  con(A, { Guides = { List = function() return {
      { id = "g1", zone = 1411, minLevel = 1, maxLevel = 6 }, { id = "g2", zone = 1411, minLevel = 6, maxLevel = 12 },
      { id = "otra", zone = 1413, minLevel = 10, maxLevel = 20 } } end, GuideMatches = function() return true end } }, function()
    con(En, { MiNivel = function() return 9 end }, function()
      check(F.GuiaDeZona(1411) == "g2", "no eligió la guía de la zona de tu nivel: " .. tostring(F.GuiaDeZona(1411)))
      check(F.GuiaDeZona(1440) == nil, "sin guía de esa zona devolvió una")
    end)
  end)
  -- El tamaño: nunca más grande que la pantalla.
  local Ve = En.V
  N.Datos("enciclopedia").tam = { 5000, 5000 }
  local w, h = Ve.Tamano()
  check(w <= K.num(UIParent:GetWidth(), 1920) and h <= K.num(UIParent:GetHeight(), 1080), "la enciclopedia no cabe en la pantalla: " .. w .. "x" .. h)
  N.Datos("enciclopedia").tam = { 100, 100 }
  w, h = Ve.Tamano()
  check(w >= 720 and h >= 460, "la enciclopedia quedó más chica que su mínimo")
  N.Datos("enciclopedia").tam = nil
end)

---------------------------------------------------------------------------
-- 9. La Jauría
---------------------------------------------------------------------------
step("116: la tarjeta de un lobo dice qué misiones tienen en común", function()
  local J = NS_OF("Alfa_Manada").Juntos
  con(J, { Mias = J.Mias }, function()
    local mias = J.Mias()
    for k in pairs(mias) do mias[k] = nil end
    mias[1], mias[2], mias[3], mias[4] = "Los Defias", "Oro rojo", "La Hermandad", "El fin"
    local t = J.Titulos({ 1, 2 }, 2)
    check(t == "“Los Defias” y “Oro rojo”", "dos títulos: " .. tostring(t))
    t = J.Titulos({ 1, 2, 3, 4 }, 2)
    check(t == "“Los Defias”, “Oro rojo” y 2 más", "con más: " .. tostring(t))
    check(J.Titulos({ 1 }) == "“Los Defias”", "uno")
    for k in pairs(mias) do mias[k] = nil end
  end)
end)

---------------------------------------------------------------------------
-- 10. Los plurales
---------------------------------------------------------------------------
step("78: ningún texto dice «1 capas» ni «1 niveles»", function()
  check(N.Plural(1, "%d capa oculta", "%d capas ocultas") == "1 capa oculta", "N.Plural uno")
  local Lm = N.Textos(NS_OF("Alfa_Mazmorras").EN)
  check(N.Plural(1, Lm["te falta %d nivel"], Lm["te faltan %d niveles"]) == "te falta 1 nivel", "te falta 1 nivel")
  check(N.Plural(3, Lm["%d jefe"], Lm["%d jefes"]) == "3 jefes", "3 jefes")
end)

print(string.format("PRUEBA: 1.3.7 mundo, %d pasos, %d errores", pasos, #ERRORS))
