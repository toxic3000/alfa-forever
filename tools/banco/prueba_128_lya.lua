-- Prueba de la 1.2.8, Lya (tools/prueba.py la corre con las demás prueba_*.lua):
--   * tu historia: la primera página dice desde dónde empezamos (sin festejar lo
--     que ya tenías); los niveles, la primera montura, el primer raro cazado y
--     tu mejor día se apuntan una vez, y Lya festeja cada página nueva;
--   * Lya aprende: tres veces cerrado con la X el mismo tipo de consejo y
--     pregunta una vez; «Ya no» lo calla (sale en su página y se devuelve),
--     «Sí, sígueme diciendo» vuelve a contar; lo importante nunca se cuenta;
--   * tus oficios: al tope de un rango, el siguiente y dónde está tu
--     instructor, una vez por rango; el nivel que pide; 300 en tu historia;
--   * el fin de la mazmorra: el tiempo adentro, tus caídas y lo mejor que
--     sacaste (solo lo tuyo), con nombres secretos sin leerlos.
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
local function check(cond, msg) if not cond then NOTE("1.2.8 Lya", msg) end end

local A = AlfaNucleo.A
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local Ly = NS_OF("Alfa_Lya")
local Di, Ap, Of, Fm = Ly.Diario, Ly.Aprende, Ly.Oficios, Ly.FinMazmorra
local datos = function() return AlfaNucleo.DatosPersonaje("lya") end

-- Lya a la vista, y lo que dice.
local dichos = {}
local function conLya(fn, real)
  local Ce, UI = Ly.Cerebro, Ly.UI
  local activa, visible, decir = Ce.Activa, UI.Visible, Ce.Decir
  Ce.Activa = function() return true end
  UI.Visible = function() return true end
  if not real then Ce.Decir = function(c) dichos[#dichos + 1] = c return true end end
  local ok, e = pcall(fn)
  Ce.Activa, UI.Visible, Ce.Decir = activa, visible, decir
  if not ok then error(e) end
end
local function ultimo() return dichos[#dichos] end
local function dijo(patron, desde)
  for i = (desde or 0) + 1, #dichos do
    local t = dichos[i].texto
    if type(t) == "string" and t:find(patron, 1, true) then return dichos[i] end
  end
  return nil
end

step("Los archivos nuevos están cargados y sus ajustes, prendidos", function()
  check(type(Di) == "table" and Di.Anotar and Di.Empezar and Di.Lista, "falta TuHistoria.lua")
  check(type(Ap) == "table" and Ap.AlCerrar and Ap.Callada and Ap.Devolver, "falta Aprende.lua")
  check(type(Of) == "table" and Of.Leer and Of.Revisar, "falta Oficios.lua")
  check(type(Fm) == "table" and Fm.Entrar and Fm.Salir, "falta FinMazmorra.lua")
  for _, k in ipairs({ "historia", "finMazmorra", "oficios", "aprende" }) do
    check(A.Get("lya." .. k) == true, "lya." .. k .. " no viene prendido")
  end
end)

---------------------------------------------------------------------------
-- 9. Tu historia
---------------------------------------------------------------------------
step("Tu historia: la primera página, sin festejar lo que ya tenías", function()
  datos().historia = nil
  local ul = UnitLevel
  UnitLevel = function() return 12 end
  local n = #dichos
  conLya(function() Di.Empezar() RUN_TIMERS(3) end)
  UnitLevel = ul
  local lista = Di.Lista()
  check(#lista == 1 and lista[1].clave == "inicio", "la primera página no es «inicio»")
  check(Di.Titulo(lista[1]):find("12", 1, true), "la primera página no dice desde qué nivel empezamos")
  check(Di.Tiene("nivel10") and not Di.Tiene("nivel20"), "los niveles que ya tenías no quedaron como hechos")
  check(#dichos == n, "Lya festejó la primera página")
  conLya(function() Di.Empezar() end)
  check(#Di.Lista() == 1, "la primera página se escribió dos veces")
end)

step("Tu historia: el nivel 20 se apunta y se festeja una vez", function()
  local n = #dichos
  conLya(function()
    FIRE_EVENT("PLAYER_LEVEL_UP", 20)
    FIRE_EVENT("PLAYER_LEVEL_UP", 10) -- ya lo tenías
    RUN_TIMERS(3)
  end)
  check(Di.Tiene("nivel20"), "el nivel 20 no se apuntó")
  check(Di.Lista()[1].clave == "nivel20" and Di.Linea(Di.Lista()[1]) ~= "", "el nivel 20 no quedó arriba con la línea de Lya")
  local f = dijo("Nueva página", n)
  check(f and f.importante and f.acciones and f.acciones[1].texto == "Ver tu historia", "Lya no festejó la página nueva con «Ver tu historia»")
  local n2 = #dichos
  conLya(function() FIRE_EVENT("PLAYER_LEVEL_UP", 20) RUN_TIMERS(3) end)
  check(not dijo("Nueva página", n2), "Lya festejó dos veces el mismo nivel")
  local cuantos = 0
  for _, e in ipairs(Di.Lista()) do if e.clave == "nivel10" then cuantos = cuantos + 1 end end
  check(cuantos == 0, "se apuntó un nivel que ya tenías")
end)

step("Tu historia: la primera montura y el primer raro cazado", function()
  local im = IsMounted
  IsMounted = function() return true end
  conLya(function() FIRE_EVENT("PLAYER_MOUNT_DISPLAY_CHANGED") RUN_TIMERS(2) end)
  IsMounted = im
  check(Di.Tiene("montura"), "la primera montura no se apuntó")

  local g, uc, un, ud, ua = UnitGUID, UnitClassification, UnitName, UnitIsDead, UnitCanAttack
  local muerto = false
  UnitGUID = function(u) if u == "target" then return "Creature-0-1-2-3-61-0000AAAA" end return "Player-1-0001" end
  UnitClassification = function(u) return u == "target" and "rare" or "normal" end
  UnitName = function(u) if u == "target" then return "Mor'Ladim" end return "Lobato" end
  UnitIsDead = function() return muerto end
  UnitCanAttack = function() return true end
  conLya(function()
    FIRE_EVENT("PLAYER_TARGET_CHANGED")
    FIRE_EVENT("UNIT_HEALTH", "target")
    check(not Di.Tiene("raro"), "el raro se apuntó antes de caer")
    muerto = true
    FIRE_EVENT("UNIT_HEALTH", "target")
    RUN_TIMERS(2)
  end)
  UnitGUID, UnitClassification, UnitName, UnitIsDead, UnitCanAttack = g, uc, un, ud, ua
  check(Di.Tiene("raro"), "el primer raro cazado no se apuntó")
  check(Di.Titulo(Di.Lista()[1]):find("Mor'Ladim", 1, true), "el raro no lleva su nombre")
end)

step("Tu historia: tu mejor día, al día y sin repetirse", function()
  local hoy = os.date("%Y-%m-%d")
  datos().record = { misiones = 11, fecha = hoy }
  conLya(function() FIRE_EVENT("QUEST_TURNED_IN") RUN_TIMERS(1) end)
  check(Di.Tiene("record"), "tu mejor día no se apuntó")
  datos().record = { misiones = 14, fecha = hoy }
  conLya(function() FIRE_EVENT("QUEST_TURNED_IN") RUN_TIMERS(1) end)
  local n = 0
  for _, e in ipairs(Di.Lista()) do if e.clave == "record" then n = n + 1 end end
  check(n == 1, "tu mejor día quedó repetido")
  check(Di.Titulo(Di.Lista()[1]):find("14", 1, true), "tu mejor día no se puso al día")
end)

step("Tu historia: apagada, no apunta nada", function()
  A.Set("lya.historia", false)
  local antes = #Di.Lista()
  check(Di.Anotar({ clave = "prueba", t = "Nivel %d", a = { 1 } }) == false and #Di.Lista() == antes, "con lya.historia apagado se apuntó una página")
  A.Set("lya.historia", true)
end)

---------------------------------------------------------------------------
-- 10. Lya aprende
---------------------------------------------------------------------------
step("Lya aprende: tres veces cerrado y pregunta una vez; «Ya no» lo calla", function()
  local d = datos()
  d.callados, d.cerrados, d.preguntados = nil, nil, nil
  local n = #dichos
  conLya(function()
    for i = 1, 3 do Ap.AlCerrar({ id = "consejo" .. i, texto = "Un consejo del juego, de prueba." }) end
    RUN_TIMERS(2)
  end)
  local p = dijo("Ya no quieres", n)
  check(p and p.acciones and p.acciones[1].texto == "Ya no" and p.acciones[2].texto == "Sí, sígueme diciendo",
    "Lya no preguntó con «Ya no» y «Sí, sígueme diciendo»")
  check(p and p.texto:find("Consejos del juego", 1, true), "la pregunta no dice qué consejo es")
  conLya(function() p.acciones[1].fn() end)
  check(Ap.Callada({ id = "consejo7" }), "«Ya no» no calló esos consejos")
  local lista = Ap.Lista()
  check(#lista == 1 and lista[1].nombre == "Consejos del juego", "el consejo callado no sale en la lista")
  -- Cerebro ya no lo dice solo; si lo pides, sí.
  local r1, por
  conLya(function() r1, por = Ly.Cerebro.Decir({ id = "consejo2", texto = "Uno callado" }) end, true)
  local r2
  conLya(function() r2 = Ly.Cerebro.Decir({ id = "consejo2", texto = "Uno pedido", pedido = true }) end, true)
  Ly.UI.Callar(true)
  check(r1 == false and por == "callada", "Lya dijo un consejo callado")
  check(r2 == true, "Lya no dijo un consejo callado que le pediste")
  local n2 = #dichos
  conLya(function()
    for i = 1, 3 do Ap.AlCerrar({ id = "consejo1", texto = "Otra vez" }) end
    RUN_TIMERS(2)
  end)
  check(not dijo("Ya no quieres", n2), "Lya volvió a preguntar por algo ya callado")
  Ap.Devolver("consejo")
  check(not Ap.Callada({ id = "consejo1" }) and #Ap.Lista() == 0, "«Devolver» no devolvió el consejo")
end)

step("Lya aprende: «Sí, sígueme diciendo», lo importante y apagado", function()
  local n = #dichos
  conLya(function()
    for _ = 1, 3 do Ap.AlCerrar({ id = "bolsas1", texto = "Bolsas" }) end
    RUN_TIMERS(2)
  end)
  local p = dijo("Ya no quieres", n)
  check(p, "Lya no preguntó por las bolsas")
  if p then conLya(function() p.acciones[2].fn() end) end
  check(not Ap.Callada({ id = "bolsas1" }), "«Sí, sígueme diciendo» calló el consejo")
  local n2 = #dichos
  conLya(function()
    for _ = 1, 4 do Ap.AlCerrar({ id = "bolsas2", texto = "Bolsas" }) end
    for _ = 1, 4 do Ap.AlCerrar({ id = "muerte1", texto = "Arriba", importante = true }) end
    for _ = 1, 4 do Ap.AlCerrar({ texto = "Pedido", pedido = true, id = "animo1" }) end
    RUN_TIMERS(2)
  end)
  check(not dijo("Ya no quieres", n2), "Lya preguntó otra vez, o por algo importante o pedido")
  A.Set("lya.aprende", false)
  local n3 = #dichos
  conLya(function()
    for _ = 1, 3 do Ap.AlCerrar({ clase = "charla", texto = "Lore" }) end
    RUN_TIMERS(2)
  end)
  check(not dijo("Ya no quieres", n3), "con lya.aprende apagado Lya preguntó")
  A.Set("lya.aprende", true)
end)

step("Lya aprende: la X del globo cuenta y un botón no", function()
  local d = datos()
  d.cerrados = {}
  conLya(function() Ly.UI.Aplicar() end)
  Ly.UI.Hablar({ id = "zona2", texto = "Qué bonito huele aquí." })
  local g = _G.AlfaLyaGlobo
  check(g and g.Cerrar, "no hay globo con su X")
  if g and g.Cerrar then
    g.Cerrar:Click()
    check((tonumber(datos().cerrados.zona) or 0) == 1, "cerrar con la X no contó")
    local hecho = false
    Ly.UI.Hablar({ id = "zona3", texto = "Otro comentario.", acciones = { { texto = "Uno", fn = function() hecho = true end } } })
    g.B1:Click()
    check(hecho and datos().cerrados.zona == nil, "usar el botón no reinició la cuenta")
  end
  Ly.UI.Callar(true)
end)

---------------------------------------------------------------------------
-- 11. Tus oficios
---------------------------------------------------------------------------
local lineas = {}
local function conOficios(fn)
  local S, ul, nav = C_SkillInfo, UnitLevel, A.Nav
  C_SkillInfo = {
    GetNumSkillLines = function() return #lineas end,
    GetSkillLineInfo = function(i) return lineas[i] end,
    GetSkillLineInfoByID = function() return nil end,
  }
  local nivel = 30
  UnitLevel = function() return nivel end
  A.Nav = { nearby = { Find = function(tipo, linea) return { name = "Brom Puñoférreo", map = 1426 }, 40 end, Go = function() return true end } }
  local ok, e = pcall(fn, function(n) nivel = n end)
  C_SkillInfo, UnitLevel, A.Nav = S, ul, nav
  if not ok then error(e) end
end

step("Tus oficios: al tope de un rango, el siguiente y dónde está tu instructor (una vez)", function()
  datos().oficios = nil
  lineas = {
    { skillID = 186, name = "Minería", rank = 75, maxRank = 75, isHeader = false },
    { skillID = 164, name = "Herrería", rank = 40, maxRank = 75, isHeader = false },
    { skillID = 98, name = "Lenguas", rank = 300, maxRank = 300, isHeader = false },
  }
  local n = #dichos
  conOficios(function() conLya(function() Of.Revisar() end) end)
  local c = dijo("75/75", n)
  check(c and c.texto:find("Minería", 1, true) and c.texto:find("Oficial", 1, true), "Lya no dijo que ya puedes aprender Oficial de Minería")
  check(c and c.texto:find("Brom", 1, true), "Lya no dijo dónde está tu instructor")
  if AlfaCerca then check(c and c.acciones and c.acciones[1].texto == "Llévame con el instructor", "falta «Llévame con el instructor»") end
  check(not dijo("Lenguas", n), "Lya habló de algo que no es un oficio")
  local n2 = #dichos
  conOficios(function() conLya(function() Of.Revisar() end) end)
  check(#dichos == n2, "Lya repitió el mismo rango")
end)

step("Tus oficios: el nivel que pide, el máximo en tu historia y apagado", function()
  lineas = { { skillID = 164, name = "Herrería", rank = 225, maxRank = 225, isHeader = false } }
  local n = #dichos
  conOficios(function(nivel) nivel(30) conLya(function() Of.Revisar() end) end)
  check(dijo("nivel 35", n), "Lya no dijo desde qué nivel enseñan Artesano")
  lineas = { { skillID = 164, name = "Herrería", rank = 300, maxRank = 300, isHeader = false } }
  local n2 = #dichos
  conOficios(function() conLya(function() Of.Revisar() end) end)
  check(dijo("300/300", n2), "Lya no festejó el oficio al máximo")
  check(Di.Tiene("oficioMax"), "el oficio al máximo no quedó en tu historia")
  A.Set("lya.oficios", false)
  lineas = { { skillID = 186, name = "Minería", rank = 150, maxRank = 150, isHeader = false } }
  local n3 = #dichos
  conOficios(function() conLya(function() Of.Revisar() end) end)
  check(#dichos == n3, "con lya.oficios apagado Lya habló")
  A.Set("lya.oficios", true)
end)

---------------------------------------------------------------------------
-- 12. Fin de mazmorra
---------------------------------------------------------------------------
local reloj = 1700000000
local function enMazmorra(fn, nombre)
  local ii, gi, gst, g = IsInInstance, GetInstanceInfo, GetServerTime, UnitGUID
  local dentro = true
  IsInInstance = function() if dentro then return true, "party" end return false, "none" end
  GetInstanceInfo = function() return nombre, "party", 1, "Normal", 5, 0, false, 36 end
  GetServerTime = function() return reloj end
  UnitGUID = function() return "Player-1-0001" end
  local ok, e = pcall(fn, function() dentro = false end)
  IsInInstance, GetInstanceInfo, GetServerTime, UnitGUID = ii, gi, gst, g
  if not ok then error(e) end
end

step("Fin de mazmorra: el tiempo, tus caídas y lo mejor que sacaste", function()
  datos().corrida = nil
  local n = #dichos
  enMazmorra(function(salir)
    conLya(function()
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      RUN_TIMERS(1)
      check(Fm.Corrida() and Fm.Corrida().nombre == "Minas de la Muerte", "no empezó la corrida al entrar")
      check(Di.Tiene("mazmorra"), "tu primera mazmorra no quedó en tu historia")
      FIRE_EVENT("PLAYER_DEAD")
      FIRE_EVENT("PLAYER_DEAD")
      local yo = LOOT_ITEM_SELF and LOOT_ITEM_SELF:format("%s") or "Recibes botín: %s."
      FIRE_EVENT("CHAT_MSG_LOOT", yo:gsub("%%s", "|cff1eff00|Hitem:2000::::::::|h[Botas verdes]|h|r"), "Lobato", "", "", "Lobato", "", 0, 0, "", 0, 1, "Player-1-0001")
      FIRE_EVENT("CHAT_MSG_LOOT", yo:gsub("%%s", "|cff0070dd|Hitem:2001::::::::|h[Espada azul]|h|r"), "Lobato", "", "", "Lobato", "", 0, 0, "", 0, 2, "Player-1-0001")
      FIRE_EVENT("CHAT_MSG_LOOT", "Otro recibe botín: |cffa335ee|Hitem:2002::::::::|h[Hacha épica]|h|r.", "Otro", "", "", "Otro", "", 0, 0, "", 0, 3, "Player-1-0002")
      FIRE_EVENT("CHAT_MSG_LOOT", "|cff9d9d9d|Hitem:2003::::::::|h[Basura]|h|r", "Lobato", "", "", "Lobato", "", 0, 0, "", 0, 4, "Player-1-0001")
      reloj = reloj + 25 * 60
      RUN_TIMERS(1)
      salir()
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      RUN_TIMERS(2)
    end)
  end, "Minas de la Muerte")
  local c = dijo("Salimos de Minas de la Muerte", n)
  check(c and c.importante, "Lya no dio el resumen al salir")
  check(c and c.texto:find("25 min", 1, true), "el resumen no dice el tiempo adentro: " .. tostring(c and c.texto))
  check(c and c.texto:find("2 veces", 1, true), "el resumen no dice tus caídas")
  check(c and c.texto:find("Espada azul", 1, true) and not c.texto:find("Hacha", 1, true), "el resumen no dice tu mejor botín (o contó el de otro)")
  check(Fm.Corrida() == nil, "la corrida no terminó")
  local e = Di.Lista()[1]
  check(e and e.clave == "corrida" and Di.Linea(e):find("2 caídas", 1, true), "tu última mazmorra no quedó en tu historia")
end)

step("Fin de mazmorra: una visita corta no cuenta; un nombre secreto no se lee", function()
  local n = #dichos
  enMazmorra(function(salir)
    conLya(function()
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      reloj = reloj + 60
      RUN_TIMERS(1)
      salir()
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      RUN_TIMERS(2)
    end)
  end, "Cavernas de Brazanegra")
  check(not dijo("Salimos de Cavernas", n), "una visita de un minuto dio resumen")
  local SECRETO = {}
  local isv = issecretvalue
  issecretvalue = function(v) return v == SECRETO end
  local n2 = #dichos
  enMazmorra(function(salir)
    conLya(function()
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      FIRE_EVENT("CHAT_MSG_LOOT", SECRETO, "Lobato", "", "", "Lobato", "", 0, 0, "", 0, 5, SECRETO)
      reloj = reloj + 10 * 60
      RUN_TIMERS(1)
      salir()
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      RUN_TIMERS(2)
    end)
  end, SECRETO)
  issecretvalue = isv
  check(dijo("Salimos de la mazmorra", n2), "con el nombre secreto no hubo resumen")
  A.Set("lya.finMazmorra", false)
  local n3 = #dichos
  enMazmorra(function(salir)
    conLya(function()
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      reloj = reloj + 10 * 60
      RUN_TIMERS(1)
      salir()
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      RUN_TIMERS(2)
    end)
  end, "Uldaman")
  A.Set("lya.finMazmorra", true)
  check(not dijo("Salimos de Uldaman", n3), "con lya.finMazmorra apagado Lya dio el resumen")
end)

step("Su página: tu historia y los consejos que callaste", function()
  Ap.Callar("consejo", "Un consejo")
  local okk, e = pcall(function()
    AlfaNucleo.A.Fire("SHOW_OPTIONS", "lya")
    RUN_TIMERS(2)
  end)
  check(okk, "la página de Lya falló: " .. tostring(e))
  Ap.DevolverTodos()
  check(#Ap.Lista() == 0, "«Devolverlos todos» no los devolvió")
end)

print(string.format("PRUEBA: 1.2.8 Lya, tu historia, aprende, tus oficios y el fin de la mazmorra, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
