-- Prueba de la 1.3.2, La Jauría y Lya (tools/prueba.py la corre con las demás):
--   1. «Cuéntame algo de aquí» con Lya oculta: el dato sale en un aviso;
--   2. citas (1C/1D) y notas (1N) sin pedir compartir tu ubicación;
--   3. la página: el bloque de una función apagada no sale;
--   4. el menú de Lya dice la acción y Lya confirma en su globo;
--   5. «Botín» vacío explica qué falta y deja prender tu clase y nivel;
--   6. «Pregúntale a Lya» busca sin acentos ni mayúsculas (también cirílico), palabra por palabra;
--   7. lo que crecía: los avisos que recuerda Lya y la vida del blanco solo con presa;
--   8. un solo reloj para las tareas de La Jauría, repartidas.
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
local function check(cond, msg) if not cond then NOTE("1.3.2 manada", msg) end end

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
local R, U = MN.Red, MN.U
local map = A.Compat.GetPlayerMapPosition()

local salidos, avisos = {}, {}
local function conRed(fn, sinCompartir)
  A.Set("manada.compartir", not sinCompartir)
  R.Escuchar()
  local via, envio, av, guild = R.Via, C_ChatInfo.SendAddonMessage, K.Aviso, IsInGuild
  R.Via = function() return "hermandad" end
  IsInGuild = function() return true end
  C_ChatInfo.SendAddonMessage = function(_, t, c, d) salidos[#salidos + 1] = { t, c, d } end
  K.Aviso = function(o) avisos[#avisos + 1] = o return true end
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
local function llega(texto, quien, canal) FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", texto, canal or "GUILD", quien) end
local function salio(patron, canal)
  for _, m in ipairs(salidos) do if m[1]:find(patron) and (not canal or m[2] == canal) then return m end end
  return nil
end
local function pagina()
  A.Fire("SHOW_OPTIONS", "manada")
  RUN_TIMERS(3)
  local view = MN.Pagina.view
  if view and view.Refresh then view.Refresh() end
  return MN.Pagina.ui
end

---------------------------------------------------------------------------
-- 1. «Cuéntame algo de aquí» con Lya oculta
---------------------------------------------------------------------------

step("«Cuéntame algo de aquí» con Lya oculta: el dato sale en un aviso", function()
  local H = Ly.Historias
  local av = K.Aviso
  local vistos = {}
  K.Aviso = function(o) vistos[#vistos + 1] = o return true end
  local mostrar = A.Get("lya.mostrar")
  A.Set("lya.mostrar", false)
  local ok, e = pcall(H.Contar)
  A.Set("lya.mostrar", mostrar)
  K.Aviso = av
  if not ok then error(e) end
  local a = vistos[1]
  check(a ~= nil, "con Lya oculta, «Cuéntame algo de aquí» no hizo nada")
  check(a and a.lya == false and a.titulo == "Lya te cuenta" and (a.texto or "") ~= "", "el aviso no trae el dato de Lya (lya = false)")
  check(a and a.accion and a.accion.texto ~= nil, "el aviso no trae «Otro dato» o «Historias»")
end)

---------------------------------------------------------------------------
-- 2. Citas y notas sin compartir tu ubicación
---------------------------------------------------------------------------

step("Citas y notas compartidas sin pedir tu ubicación", function()
  local Ci, No = MN.Cita, MN.Notas
  local reloj = GetServerTime()
  conRed(function()
    -- Citas: su permiso es manada.citas.
    salidos, avisos = {}, {}
    check(Ci.Proponer("Minas de la Muerte", reloj + 3600), "sin compartir tu ubicación no dejó proponer la cita")
    vaciarCola()
    check(salio("^1C|%d+|%d+|Minas de la Muerte$", "GUILD"), "la cita no salió por la hermandad (1C)")
    llega(("1C|31|%d|Vallefresno"):format(reloj + 7200), "Elsa Mora")
    local hay
    for _, c in ipairs(Ci.Lista()) do if c.que == "Vallefresno" then hay = c end end
    check(hay, "sin compartir no llegó la cita de Elsa")
    if hay then
      salidos = {}
      Ci.Responder(hay.llave, true)
      vaciarCola()
      check(salio("^1D|31|s$", "WHISPER"), "el «Voy» no salió (1D) sin compartir")
    end
    A.Set("manada.citas", false)
    check(select(2, Ci.Proponer("Otra", reloj + 3600)) == "apagado", "con las citas apagadas dejó proponer")
    A.Set("manada.citas", true)
    for _, c in ipairs(Ci.Lista()) do Ci.Quitar(c.llave) end
    -- Notas: su permiso es manada.notasCompartir.
    salidos = {}
    local n = No.Agregar("Sin compartir")
    vaciarCola()
    check(n and not n.compartida and not salio("^1N|"), "una nota salió sin «Compartir con la manada»")
    A.Set("manada.notasCompartir", true)
    salidos = {}
    local m = No.Agregar("Buen lugar para pescar")
    vaciarCola()
    check(m and m.compartida and salio("^1N|%d+|[%d%.]+|[%d%.]+|Buen lugar para pescar$", "GUILD"), "sin compartir tu ubicación la nota no salió (1N)")
    llega(("1N|%d|20.00|20.00|Tesoro escondido"):format(map), "Dana Ruiz")
    local de
    for _, x in ipairs(No.Lista("nota")) do if x.de then de = x end end
    check(de and de.texto == "Tesoro escondido", "sin compartir tu ubicación no se vio la nota de Dana")
    A.Set("manada.notasCompartir", false)
    for _, x in ipairs(No.Lista()) do No.Borrar(x.id) end
  end, true)
  -- Quien ya las usaba (compartiendo) sigue igual.
  conRed(function()
    salidos = {}
    check(Ci.Proponer("Con compartir", reloj + 3600), "compartiendo ya no dejó proponer")
    vaciarCola()
    check(salio("^1C|%d+|%d+|Con compartir$", "GUILD"), "compartiendo, la cita no salió")
    for _, c in ipairs(Ci.Lista()) do Ci.Quitar(c.llave) end
  end)
end)

---------------------------------------------------------------------------
-- 3. La página: lo apagado no ocupa lugar
---------------------------------------------------------------------------

step("La página de La Jauría esconde lo que apagaste", function()
  local ui = pagina()
  check(ui and ui.tablon and ui.mentor and ui.botin, "la página no se armó")
  if not (ui and ui.tablon) then return end
  check(ui.tablon:IsShown() and ui.mentor:IsShown(), "con todo prendido faltan bloques")
  for _, k in ipairs({ "tablon", "mentor", "botin", "citas", "notas" }) do A.Set("manada." .. k, false) end
  A.Set("manada.rarosReloj", false)
  ui = pagina()
  for _, b in ipairs({ "tablon", "mentor", "botin", "citas", "notas", "cazados", "calendario" }) do
    check(not ui[b]:IsShown(), "el bloque «" .. b .. "» sigue en la página con su función apagada")
  end
  for _, k in ipairs({ "tablon", "mentor", "botin", "citas", "notas", "rarosReloj" }) do A.Set("manada." .. k, true) end
  ui = pagina()
  check(ui.tablon:IsShown() and ui.citas:IsShown() and ui.calendario:IsShown(), "al prenderlas no volvieron")
end)

---------------------------------------------------------------------------
-- 4. El menú de Lya dice la acción
---------------------------------------------------------------------------

step("El menú de Lya dice lo que hace y Lya lo confirma en su globo", function()
  local f = rawget(_G, "AlfaLyaLoba")
  check(f, "Lya no está en pantalla")
  if not f then return end
  local opciones, alElegir
  local menu, decir, imprimir = K.Menu, Ly.Cerebro.Decir, N.Imprimir
  local dicho, impreso = {}, {}
  K.Menu = function(_, o, _, fn) opciones, alElegir = o, fn end
  Ly.Cerebro.Decir = function(c) dicho[#dicho + 1] = c.texto return true end
  N.Imprimir = function(t) impreso[#impreso + 1] = t end
  local frec, letra = A.Get("lya.frecuencia"), A.Get("lya.letra")
  local ok, e = pcall(function()
    A.Set("lya.frecuencia", "muchos")
    A.Set("lya.letra", "grande")
    FIRE(f, "OnClick", "RightButton")
    local textos = {}
    for _, o in ipairs(opciones or {}) do if o.texto then textos[o.valor or "?"] = o.texto end end
    check(textos.frec == "Menos consejos", "la fila de consejos no dice la acción: " .. tostring(textos.frec))
    check(textos.letra == "Letra muy grande", "la fila de la letra no dice la acción: " .. tostring(textos.letra))
    if alElegir then alElegir("frec") end
    check(A.Get("lya.frecuencia") == "pocos", "«Menos consejos» no cambió a pocos")
    check(dicho[#dicho] == "Consejos: pocos", "Lya no confirmó en su globo: " .. tostring(dicho[#dicho]))
    check(#impreso == 0, "la confirmación salió en el chat")
  end)
  K.Menu, Ly.Cerebro.Decir, N.Imprimir = menu, decir, imprimir
  A.Set("lya.frecuencia", frec)
  A.Set("lya.letra", letra)
  if not ok then error(e) end
end)

---------------------------------------------------------------------------
-- 5. «Botín» vacío
---------------------------------------------------------------------------

step("«Botín» vacío explica qué falta y deja prender tu clase y nivel", function()
  A.Set("manada.botinCompartir", false)
  local ui = pagina()
  local b = ui and ui.botin
  check(b, "falta el bloque de botín")
  if not b then return end
  b:Llenar()
  local t = b.Vacio:GetText() or ""
  check(t:find("Compartir mi clase y nivel", 1, true), "el botín vacío no dice que necesita lobos que compartan su clase y nivel: " .. t)
  check(b.Compartir and b.Compartir:IsShown(), "el botín vacío no trae «Compartir mi clase y nivel»")
  if b.Compartir then
    local dichos = {}
    local imp = N.Imprimir
    N.Imprimir = function(x) dichos[#dichos + 1] = x end
    FIRE(b.Compartir, "OnClick", "LeftButton")
    N.Imprimir = imp
    check(A.Get("manada.botinCompartir") == true, "el botón no prendió «Compartir mi clase y nivel»")
    check(#dichos > 0, "el botón no dijo qué pasó")
    b:Llenar()
    check(not b.Compartir:IsShown(), "ya prendido, el botón sigue")
  end
  A.Set("manada.botinCompartir", false)
end)

---------------------------------------------------------------------------
-- 6. «Pregúntale a Lya» busca mejor
---------------------------------------------------------------------------

step("«Pregúntale a Lya» busca sin acentos ni mayúsculas, palabra por palabra", function()
  local Gi = Ly.Guia
  check(Gi.Plegar and Gi.Coincide, "faltan Gi.Plegar o Gi.Coincide")
  if not (Gi.Plegar and Gi.Coincide) then return end
  check(Gi.Plegar("Misión ÁRBOL Ñandú") == "mision arbol nandu", "no pliega los acentos: " .. Gi.Plegar("Misión ÁRBOL Ñandú"))
  check(Gi.Plegar("Карта ЁЖ") == "карта еж", "no pliega el cirílico: " .. Gi.Plegar("Карта ЁЖ"))
  check(Gi.Plegar("Größe") == "grosse", "no pliega el alemán")
  local q = "¿Cómo me cambio de plano si hay mucha gente?"
  check(Gi.Coincide(Gi.Plegar("cambio plano"), q), "«cambio plano» no encontró la pregunta (palabra por palabra)")
  check(Gi.Coincide(Gi.Plegar("COMO"), q), "«COMO» no encontró «Cómo»")
  check(not Gi.Coincide(Gi.Plegar("plano barco"), q), "encontró la pregunta con una palabra que no tiene")
  check(Gi.Coincide(Gi.Plegar("КАРТА"), "Открой карту: карта мира"), "en ruso, la mayúscula no encontró la minúscula")
  -- La ventana abre y busca sin errores.
  Gi.Abrir()
  RUN_TIMERS(2)
end)

---------------------------------------------------------------------------
-- 7. Lo que crecía
---------------------------------------------------------------------------

step("Lya olvida los avisos viejos y solo escucha la vida del blanco con presa", function()
  local Ce, Di = Ly.Cerebro, Ly.Diario
  check(Ce.AvisosRecordados, "falta Ce.AvisosRecordados")
  -- Los avisos que Lya ya dijo: lo de más de 90 s se olvida.
  local UI = Ly.UI
  local vis, decir = UI.Visible, Ce.Decir
  UI.Visible = function() return true end
  Ce.Decir = function() return true end
  local ok, e = pcall(function()
    for i = 1, 20 do K.AvisoPorLya({ titulo = "Aviso " .. i, texto = "número " .. i }) end
    NOW = NOW + 100
    K.AvisoPorLya({ titulo = "Uno nuevo", texto = "después" })
    check(Ce.AvisosRecordados and Ce.AvisosRecordados() == 1, "Lya sigue recordando avisos de hace más de 90 s: " .. tostring(Ce.AvisosRecordados and Ce.AvisosRecordados()))
  end)
  UI.Visible, Ce.Decir = vis, decir
  if not ok then error(e) end
  -- La vida del blanco, solo con presa.
  check(Di.VigilaPresa, "falta Di.VigilaPresa")
  if not Di.VigilaPresa then return end
  check(not Di.VigilaPresa(), "escucha la vida del blanco sin presa")
  local vivo = true
  con(_G, {
    UnitGUID = function(u) if u == "target" then return "Creature-0-1-2-3-7001-61-0001" end return nil end,
    UnitClassification = function(u) return u == "target" and "rare" or "normal" end,
    UnitIsDead = function(u) return u == "target" and not vivo end,
    UnitCanAttack = function() return true end,
    UnitIsTapDenied = function() return false end,
    UnitName = function(u) if u == "target" then return "Mor'Ladim" end return "Lobato" end,
  }, function()
    local tiene = Di.Tiene("raro")
    FIRE_EVENT("PLAYER_TARGET_CHANGED")
    if tiene then
      check(not Di.VigilaPresa(), "ya con tu primer raro, siguió escuchando la vida del blanco")
    else
      check(Di.VigilaPresa(), "con un raro de blanco no escucha su vida")
      vivo = false
      FIRE_EVENT("UNIT_HEALTH", "target")
      check(Di.Tiene("raro"), "tu primer raro no quedó en tu historia")
      check(not Di.VigilaPresa(), "cazado el raro, siguió escuchando la vida del blanco")
    end
  end)
end)

---------------------------------------------------------------------------
-- 8. Un solo reloj para La Jauría
---------------------------------------------------------------------------

step("Las tareas de La Jauría van en un solo reloj, repartidas", function()
  local VIEJAS = { "manada.botin", "manada.citaRecordar", "manada.citaRepetir", "manada.guaridas", "manada.juntos",
    "manada.juntosOfrecer", "manada.logros", "manada.limpieza", "manada.mentor", "manada.plano", "manada.quienVa",
    "manada.relojRaros", "manada.tablon" }
  check(N.HayTarea("manada.reloj"), "falta la tarea manada.reloj")
  local sueltas = {}
  for _, k in ipairs(VIEJAS) do if N.HayTarea(k) then sueltas[#sueltas + 1] = k end end
  check(#sueltas == 0, "siguen sueltas en el reloj de Alfa: " .. table.concat(sueltas, ", "))
  check(MN.Tareas, "falta MN.Tareas")
  if not MN.Tareas then return end
  local por = {}
  for _, t in ipairs(MN.Tareas()) do por[t.clave] = t end
  local faltan = {}
  for _, k in ipairs(VIEJAS) do if not por[k] then faltan[#faltan + 1] = k end end
  check(#faltan == 0, "faltan en el reloj de La Jauría: " .. table.concat(faltan, ", "))
  -- Un minuto de reloj real (cada 10 s): cuántas veces corre cada una y en qué vuelta.
  local latir = N.Reloj.lista["manada.reloj"] and N.Reloj.lista["manada.reloj"].fn
  check(latir, "manada.reloj no tiene función")
  if not latir then return end
  -- Una vuelta para ponerse al día (el banco corrió el reloj de golpe antes).
  NOW = NOW + 10
  latir(10)
  local antes = {}
  for _, t in ipairs(MN.Tareas()) do antes[t.clave] = t.veces end
  local enVuelta = {}
  for v = 1, 12 do
    NOW = NOW + 10
    local previo = {}
    for _, t in ipairs(MN.Tareas()) do previo[t.clave] = t.veces end
    latir(10)
    for _, t in ipairs(MN.Tareas()) do
      if t.veces > previo[t.clave] and t.cada == 60 then enVuelta[v] = (enVuelta[v] or 0) + 1 end
    end
  end
  local ahora = {}
  for _, t in ipairs(MN.Tareas()) do ahora[t.clave] = t end
  local function veces(k) return ahora[k].veces - (antes[k] or 0) end
  check(veces("manada.guaridas") == 12 and veces("manada.plano") == 12, "las de 10 s no corrieron cada 10 s: " .. veces("manada.guaridas"))
  check(veces("manada.mentor") == 4 and veces("manada.citaRecordar") == 4, "las de 30 s no corrieron cada 30 s: " .. veces("manada.mentor"))
  check(veces("manada.juntosOfrecer") == 6, "la de 20 s no corrió cada 20 s: " .. veces("manada.juntosOfrecer"))
  check(veces("manada.tablon") == 2 and veces("manada.botin") == 2, "las de 60 s no corrieron cada minuto: " .. veces("manada.tablon"))
  local juntas = 0
  for _, n in pairs(enVuelta) do if n > juntas then juntas = n end end
  check(juntas <= 2, "las tareas de un minuto corren todas en la misma vuelta: " .. juntas)
  for _, t in ipairs(MN.Tareas()) do check(t.fallos == 0, "la tarea " .. t.clave .. " falla") end
end)

print(string.format("PRUEBA: 1.3.2 La Jauría y Lya, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
