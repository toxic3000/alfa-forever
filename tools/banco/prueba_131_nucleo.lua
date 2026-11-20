-- Prueba de la 1.3.1, el núcleo, la bienvenida y Lya (tools/prueba.py la corre
-- con las demás prueba_*.lua):
--   * respaldos y perfiles llevan su número de migración (esquema); al
--     restaurar o aplicar uno de antes, sus ajustes se mudan con las
--     migraciones que les faltan (quien ya tenía Alfa no cae en «Sencillo»);
--     los de antes de la 1.3.1, sin número, como dice Respaldos.lua;
--   * el fin de la mazmorra: caer y salir como espíritu no cierra la corrida
--     (ni Lya festeja «¡Salimos!»); al volver a entrar sigue la misma y se
--     cierra al salir vivo; «lya.finMazmorra» solo corre adentro;
--   * el recorrido: sin «Siguiente» termina solo, cerrar la ventana lo termina
--     en cualquier paso y no deja claves nuevas en las frases vistas de Lya;
--   * Lya no se pisa: un aviso de Alfa no tapa lo importante ni un globo con
--     botones; lo importante espera su turno y sale al callarse el globo;
--   * el reloj: un solo despertador (y no uno nuevo si el que hay alcanza); el
--     latido de Lya es una tarea del reloj que solo corre con ella a la vista;
--   * lo de la entrada (cómo te fue la última vez, la fiesta del día) espera a
--     que pase la espera entre globos y queda dicho solo cuando sale;
--   * importar un perfil salta y cuenta las líneas que no sirven (rutas con un
--     pedazo vacío, números que no son finitos, valores de otro tipo);
--   * las migraciones se anotan una por una (AlfaDB.alfaMigraciones): la de un
--     módulo que se prende después corre aunque ya hayan corrido otras mayores.
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
local function check(cond, msg) if not cond then NOTE("1.3.1 núcleo y Lya", msg) end end

Alfa.Hidden = function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local A, N, K = Alfa, AlfaNucleo, AlfaNucleo.Kit
local B = NS_OF("Alfa_Bienvenida")
local Ly = NS_OF("Alfa_Lya")
local Pf, Rc = B.Perfiles, B.Recorrido
local Ce, UI, Fm = Ly.Cerebro, Ly.UI, Ly.FinMazmorra

-- Los ajustes de antes de la prueba, para dejarlos como estaban.
local ajustesAntes = N.CopiarTabla(A.DB().settings)
local esquemaAntes = A.DB().alfaSchema
local function volverAjustes()
  A.DB().settings = N.CopiarTabla(ajustesAntes)
  A.DB().alfaSchema = esquemaAntes
  A.Fire("SETTING_CHANGED", "")
end

-- Lya a la vista, y lo que dice (sin su globo).
local dichos = {}
local function conLya(fn)
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
-- Lya a la vista con su globo de verdad.
local function conLyaReal(fn)
  local activa, visible = Ce.Activa, UI.Visible
  Ce.Activa = function() return true end
  UI.Visible = function() return true end
  local ok, e = pcall(fn)
  Ce.Activa, UI.Visible = activa, visible
  if not ok then error(e) end
end
local function enHistorial(texto)
  for _, x in ipairs(Ce.historial or {}) do if x.texto == texto then return true end end
  return false
end
local function activo() return Rc.Activo and Rc.Activo() or false end

---------------------------------------------------------------------------
-- 5. El reloj: un solo despertador
---------------------------------------------------------------------------
step("Reloj: un solo despertador, y no uno nuevo si el que hay alcanza", function()
  local lista = N.Reloj.lista
  local aparte = {}
  for k, t in pairs(lista) do aparte[k] = t end
  for k in pairs(aparte) do lista[k] = nil end
  BANCO_RELOJ_REAL = true
  local fns = {}
  local after = C_Timer.After
  C_Timer.After = function(s, fn) fns[#fns + 1] = fn return after(s, fn) end
  local nada = function() end
  N.Cada("prueba.cerca", 5, nada)
  for i = 1, 5 do N.Cada("prueba.lejos" .. i, 300, nada) end
  N.Quitar("prueba.lejos1")
  N.Cada("prueba.cerca2", 20, nada)
  local n = #fns
  -- Una tarea antes de la hora del despertador: hace falta otro, el mismo.
  N.Cada("prueba.antes", 2, nada)
  C_Timer.After = after
  check(n == 1, "se pusieron " .. n .. " despertadores para la misma hora (uno alcanza)")
  check(#fns == n + 1, "con una tarea más temprano no se puso otro despertador")
  local mismo = true
  for i = 2, #fns do if fns[i] ~= fns[1] then mismo = false end end
  check(mismo, "cada plan pone un despertador nuevo (una función nueva cada vez)")
  check(not N.Reloj.marco:IsShown(), "con 2 s por delante el reloj no duerme")
  -- Uno viejo que suena antes de tiempo no despierta al reloj; el bueno, sí.
  if fns[1] then fns[1]() end
  check(not N.Reloj.marco:IsShown(), "un despertador despertó al reloj con 2 s por delante")
  NOW = NOW + 2
  if fns[#fns] then fns[#fns]() end
  check(N.Reloj.marco:IsShown(), "el despertador no despertó al reloj a tiempo")
  FIRE(N.Reloj.marco, "OnUpdate", 0.1)
  for _, k in ipairs({ "prueba.cerca", "prueba.lejos2", "prueba.lejos3", "prueba.lejos4", "prueba.lejos5", "prueba.cerca2", "prueba.antes" }) do
    N.Quitar(k)
  end
  BANCO_RELOJ_REAL = nil
  for k, t in pairs(aparte) do lista[k] = t end
  N.Cada("prueba.replan", 1, nada)
  N.Quitar("prueba.replan")
end)

---------------------------------------------------------------------------
-- 1. Respaldos y perfiles: su número de migración
---------------------------------------------------------------------------
step("Respaldos: llevan su número y el de «antes de actualizar» se muda al restaurarlo", function()
  local db = A.DB()
  local nueva = A.IsNewAccount
  A.IsNewAccount = function() return false end
  -- Una cuenta de la 1.2.8: sin modo y en la migración 2.
  A.Set("bienvenida.modo", nil)
  db.alfaSchema = 2
  N.CorrerMigraciones() -- respalda «antes de actualizar» y corre la 3
  check(A.Get("bienvenida.modo") == "completo", "la migración 3 no dejó en completo a quien ya tenía Alfa")
  local r, i
  for j, x in ipairs(N.Respaldos()) do if x.motivo == "migracion" then r, i = x, j end end
  check(r ~= nil, "no hubo respaldo antes de la migración")
  check(r and tonumber(r.esquema) == 2, "el respaldo no lleva su número de migración (" .. tostring(r and r.esquema) .. ")")
  if i then N.RestaurarRespaldo(i) end
  check(A.Get("bienvenida.modo") == "completo",
    "al restaurar «antes de actualizar», quien ya tenía Alfa quedó en " .. tostring(A.Get("bienvenida.modo")))
  check((tonumber(db.alfaSchema) or 0) >= 3, "tras restaurar no quedó anotada la migración 3")
  -- Uno de ahora lleva el número de ahora.
  N.Respaldar("manual")
  local l = N.Respaldos()
  check(tonumber(l[#l].esquema) == (N.Esquema and N.Esquema() or -1), "un respaldo de ahora no lleva el número de ahora")
  A.IsNewAccount = nueva
  volverAjustes()
end)

step("Respaldos de antes (sin número): «antes de actualizar» o de antes de la 1.2.9 cuentan como 2; los demás como 3", function()
  local nueva = A.IsNewAccount
  -- Los ajustes que llegaron vacíos: la cuenta parece nueva, pero lo restaurado es de antes.
  A.IsNewAccount = function() return true end
  local function viejo(motivo, v)
    A.Set("bienvenida.modo", nil)
    N.Respaldar(motivo)
    local l = N.Respaldos()
    local r = l[#l]
    r.esquema, r.motivo, r.v = nil, motivo, v
    A.Set("bienvenida.modo", "completo")
    N.RestaurarRespaldo(#l)
    return A.Get("bienvenida.modo")
  end
  check(viejo("migracion", "1.2.9") == "completo", "el «antes de actualizar» de la 1.2.9 te dejó en sencillo")
  check(viejo("semanal", "1.2.8") == "completo", "un respaldo de la 1.2.8 te dejó en sencillo")
  -- Uno semanal de la 1.3.0 de quien eligió sencillo: ya estaba mudado, se queda así.
  check(viejo("semanal", "1.3.0") == "sencillo", "un respaldo de la 1.3.0 de quien eligió sencillo se mudó a completo")
  check(type(N.EsquemaDeRespaldo) == "function" and N.EsquemaDeRespaldo({ v = "1.2.8", motivo = "manual" }) == 2
    and N.EsquemaDeRespaldo({ v = "1.3.0", motivo = "semanal" }) == 3 and N.EsquemaDeRespaldo({ v = "1.2.9", motivo = "migracion" }) == 2
    and N.EsquemaDeRespaldo({ v = "1.3.1", esquema = 7 }) == 7, "N.EsquemaDeRespaldo no da el número de cada respaldo")
  A.IsNewAccount = nueva
  volverAjustes()
end)

step("Perfiles: llevan su número; uno de antes conserva tu modo; uno de antes de la migración se muda", function()
  local db = A.DB()
  local perfiles = N.Datos("bienvenida").perfiles or {}
  A.Set("bienvenida.modo", "completo")
  Pf.Guardar("Prueba 1.3.1")
  perfiles = N.Datos("bienvenida").perfiles
  local p = perfiles["Prueba 1.3.1"]
  check(p and tonumber(p["_alfa.esquema"]) == (N.Esquema and N.Esquema() or -1), "el perfil no lleva su número de migración")
  check(p and type(p["_alfa.version"]) == "string", "el perfil no lleva su versión")
  -- Un perfil guardado en la 1.2.8: sin número ni modo.
  local viejo = {}
  for k, v in pairs(p or {}) do if not k:find("^_alfa%.") and k ~= "bienvenida.modo" then viejo[k] = v end end
  perfiles["Prueba 1.2.8"] = viejo
  check(Pf.Aplicar("Prueba 1.2.8"), "no se aplicó el perfil de la 1.2.8")
  check(A.Get("bienvenida.modo") == "completo", "un perfil de antes te dejó en " .. tostring(A.Get("bienvenida.modo")))
  check(type(db.settings._alfa) ~= "table", "el número del perfil pasó a tus ajustes")
  -- El texto de «Exportar» lleva su número.
  local texto = Pf.Exportar()
  check(texto:find("\n_alfa.esquema=n:", 1, true) ~= nil, "el texto de «Exportar» no lleva su número de migración")
  -- Uno exportado antes de la migración 3 (número 2) y sin modo: se muda al importarlo.
  A.Set("bienvenida.modo", nil)
  local ok = Pf.Importar("Alfa:perfil:1\n_alfa.esquema=n:2\n_alfa.version=s:1.2.8\nlya.minutos=n:7")
  check(ok and A.Get("bienvenida.modo") == "completo", "importar uno de antes de la migración 3 te dejó en " .. tostring(A.Get("bienvenida.modo")))
  check(A.Get("lya.minutos") == 7, "importar no puso los ajustes del texto")
  check(type(db.settings._alfa) ~= "table", "el número del texto pasó a tus ajustes")
  -- Uno de antes en texto (sin número ni modo): conserva tu modo.
  A.Set("bienvenida.modo", "completo")
  ok = Pf.Importar("Alfa:perfil:1\nlya.minutos=n:6")
  check(ok and A.Get("bienvenida.modo") == "completo", "importar un texto de antes te cambió el modo a " .. tostring(A.Get("bienvenida.modo")))
  -- Y lo de ahora quedó guardado como perfil, con su número.
  local antes = perfiles[B.L and B.L["Antes de importar"] or "Antes de importar"]
  check(antes and tonumber(antes["_alfa.esquema"]) ~= nil, "«Antes de importar» no lleva su número")
  perfiles["Prueba 1.3.1"], perfiles["Prueba 1.2.8"] = nil, nil
  volverAjustes()
end)

---------------------------------------------------------------------------
-- 2. El fin de la mazmorra: caer no es salir
---------------------------------------------------------------------------
local reloj = 1700000000
local function enMazmorra(fn, nombre)
  local ii, gi, gst, g, dg = IsInInstance, GetInstanceInfo, GetServerTime, UnitGUID, UnitIsDeadOrGhost
  local e = { dentro = true, muerto = false }
  IsInInstance = function() if e.dentro then return true, "party" end return false, "none" end
  GetInstanceInfo = function() return nombre, "party", 1, "Normal", 5, 0, false, 70 end
  GetServerTime = function() return reloj end
  UnitGUID = function() return "Player-1-0001" end
  UnitIsDeadOrGhost = function() return e.muerto end
  local ok, err = pcall(fn, e)
  IsInInstance, GetInstanceInfo, GetServerTime, UnitGUID, UnitIsDeadOrGhost = ii, gi, gst, g, dg
  if not ok then error(err) end
end

step("Fin de mazmorra: caer y salir como espíritu no cierra la corrida; se cierra al salir vivo", function()
  N.DatosPersonaje("lya").corrida = nil
  local n = #dichos
  local inicio, sigue, tareaAfuera, misma
  enMazmorra(function(e)
    conLya(function()
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      RUN_TIMERS(1)
      local r = Fm.Corrida()
      check(r and r.nombre == "Uldaman", "no empezó la corrida al entrar")
      inicio = r and r.inicio
      check(N.HayTarea("lya.finMazmorra"), "adentro no corre «lya.finMazmorra»")
      FIRE_EVENT("PLAYER_DEAD")
      reloj = reloj + 15 * 60
      RUN_TIMERS(1)
      -- Cae el grupo y liberas el espíritu: apareces afuera, como espíritu.
      e.muerto, e.dentro = true, false
      FIRE_EVENT("PLAYER_ALIVE")
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      RUN_TIMERS(3)
      sigue = Fm.Corrida() ~= nil
      tareaAfuera = N.HayTarea("lya.finMazmorra")
      check(not dijo("Salimos", n), "como espíritu Lya dio el resumen de la mazmorra")
      -- Corres a la entrada y vuelves a entrar: la misma corrida.
      reloj = reloj + 3 * 60
      e.dentro = true
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      e.muerto = false
      FIRE_EVENT("PLAYER_UNGHOST")
      RUN_TIMERS(1)
      misma = Fm.Corrida() and Fm.Corrida().inicio == inicio
      reloj = reloj + 10 * 60
      RUN_TIMERS(1)
      -- Sales vivo: ahora sí, el resumen de toda la corrida.
      e.dentro = false
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      RUN_TIMERS(3)
    end)
  end, "Uldaman")
  check(sigue, "salir como espíritu cerró la corrida")
  check(not tareaAfuera, "afuera sigue corriendo «lya.finMazmorra»")
  check(misma, "al volver a entrar empezó otra corrida")
  local c = dijo("Salimos de Uldaman", n)
  check(c ~= nil, "al salir vivo Lya no dio el resumen")
  check(c and c.texto:find("28 min", 1, true), "el resumen no cuenta toda la corrida: " .. tostring(c and c.texto))
  check(c and c.texto:find("Caíste una vez", 1, true), "el resumen no cuenta la caída de antes de liberar: " .. tostring(c and c.texto))
  check(Fm.Corrida() == nil, "la corrida no se cerró al salir vivo")
  check(not N.HayTarea("lya.finMazmorra"), "al salir sigue corriendo «lya.finMazmorra»")
end)

step("Fin de mazmorra: revivir afuera con el ángel cierra la corrida", function()
  N.DatosPersonaje("lya").corrida = nil
  local n = #dichos
  enMazmorra(function(e)
    conLya(function()
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      RUN_TIMERS(1)
      reloj = reloj + 8 * 60
      RUN_TIMERS(1)
      FIRE_EVENT("PLAYER_DEAD")
      e.muerto, e.dentro = true, false
      FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
      RUN_TIMERS(3)
      check(Fm.Corrida() ~= nil, "salir como espíritu cerró la corrida")
      -- El ángel: revives afuera.
      e.muerto = false
      FIRE_EVENT("PLAYER_UNGHOST")
      RUN_TIMERS(3)
    end)
  end, "Uldaman")
  check(dijo("Salimos de Uldaman", n) ~= nil, "revivir afuera no dio el resumen")
  check(Fm.Corrida() == nil, "revivir afuera no cerró la corrida")
end)

---------------------------------------------------------------------------
-- 3. El recorrido no se atora
---------------------------------------------------------------------------
local function conAvisos(fn)
  local avisos = {}
  local av, vis = K.Aviso, AlfaLya.Visible
  K.Aviso = function(o) avisos[#avisos + 1] = o return {} end
  AlfaLya.Visible = function() return false end -- sin Lya: los pasos salen como aviso
  local ok, e = pcall(fn, avisos)
  K.Aviso, AlfaLya.Visible = av, vis
  if not ok then error(e) end
end

step("Recorrido: sin «Siguiente» termina solo y queda visto", function()
  check(type(Rc.Activo) == "function", "falta Rc.Activo()")
  conAvisos(function(avisos)
    N.Datos("bienvenida").recorrido = nil
    Rc.Empezar()
    check(activo(), "el recorrido no empezó")
    check(N.HayTarea("alfa.recorrido"), "el paso no tiene su espera de seguridad («alfa.recorrido»)")
    RUN_TIMERS(2) -- nadie le da «Siguiente»: pasa la espera
    check(not activo(), "el recorrido sigue a medias sin que nadie le dé «Siguiente»")
    check(N.Datos("bienvenida").recorrido == true, "el recorrido que terminó solo no quedó como visto")
    check(not N.HayTarea("alfa.recorrido"), "terminado, sigue su espera en el reloj")
  end)
end)

step("Recorrido: cerrar la ventana en el último paso lo termina", function()
  conAvisos(function(avisos)
    N.Abrir("inicio")
    RUN_TIMERS(1)
    local w = rawget(_G, "AlfaOptions")
    check(w and w:IsShown(), "no se abrió la ventana de Alfa")
    N.Datos("bienvenida").recorrido = nil
    Rc.Empezar()
    -- 1.3.6: el recorrido tiene 6 o 7 pasos (el lobo del minimapa, «¿Qué es esto?»).
    local function enUltimo()
      local u = avisos[#avisos]
      local k, n = tostring(u and u.texto or ""):match("%((%d+)/(%d+)%)")
      return k ~= nil and k == n
    end
    for _ = 1, 10 do
      if enUltimo() then break end
      local a = avisos[#avisos]
      if a and a.accion then a.accion.alClic() end
    end
    check(enUltimo(), "el recorrido no llegó al último paso")
    if w then w:Hide() end
    check(not activo(), "cerrar la ventana en el último paso no terminó el recorrido")
    check(N.Datos("bienvenida").recorrido == true, "cerrar la ventana en el último paso no lo dejó como visto")
  end)
end)

step("Recorrido: con Lya no deja claves nuevas en sus frases vistas", function()
  conLyaReal(function()
    UI.Aplicar()
    UI.Callar(true)
    N.Datos("bienvenida").recorrido = nil
    Rc.Empezar()
    local hay = false
    for k in pairs(N.DatosPersonaje("lya").vistos or {}) do if tostring(k):find("recorrido", 1, true) then hay = true end end
    check(not hay, "cada recorrido deja claves nuevas en las frases vistas de Lya")
    local h = Ce.historial and Ce.historial[1]
    check(h and tostring(h.texto):find("%(1/%d+%)"), "con Lya a la vista no lo dijo ella")
    Rc.Terminar()
    UI.Callar(true)
  end)
end)

---------------------------------------------------------------------------
-- 4. Lya no se pisa
---------------------------------------------------------------------------
step("Lya no se pisa: un aviso no tapa lo importante ni un globo con botones", function()
  conLyaReal(function()
    UI.Aplicar()
    UI.Callar(true)
    local r = Ce.Decir({ importante = true, texto = "Importante de prueba A", acciones = { { texto = "Uno", fn = function() end } } })
    check(r == true, "Lya no dijo lo importante: " .. tostring(r))
    local a = K.Aviso({ titulo = "Aviso de prueba B", texto = "Algo de Alfa." })
    check(type(a) == "table", "el aviso lo dijo Lya encima de lo importante")
    check(Ce.historial[1] and Ce.historial[1].texto == "Importante de prueba A", "el aviso pisó a lo importante")
    check(UI.Actual and UI.Actual() and UI.Actual().texto == "Importante de prueba A", "falta UI.Actual() o no dice lo de ahora")
    if type(a) == "table" and a.Cerrar then a:Cerrar() end
    -- Un globo con botones (no importante) tampoco se pisa.
    UI.Callar(true)
    Ce.Decir({ pedido = true, texto = "Con botones C", acciones = { { texto = "Uno", fn = function() end } } })
    a = K.Aviso({ titulo = "Aviso de prueba D" })
    check(type(a) == "table" and Ce.historial[1].texto == "Con botones C", "un aviso pisó un globo con botones")
    if type(a) == "table" and a.Cerrar then a:Cerrar() end
    -- Sin nada importante ni botones, el aviso lo sigue diciendo Lya.
    UI.Callar(true)
    Ce.Decir({ pedido = true, texto = "Algo suelto E" })
    a = K.Aviso({ titulo = "Aviso de prueba F" })
    check(a == true, "sin nada importante el aviso ya no lo dice Lya")
    UI.Callar(true)
    check(UI.Actual and UI.Actual() == nil, "callada, UI.Actual() sigue diciendo algo")
  end)
end)

step("Lya no se pisa: lo importante espera su turno y sale al callarse", function()
  conLyaReal(function()
    UI.Aplicar()
    UI.Callar(true)
    RUN_TIMERS(1)
    check(Ce.Decir({ importante = true, texto = "Primero importante" }) == true, "no dijo lo primero")
    local r = Ce.Decir({ importante = true, texto = "Segundo importante" })
    local r2 = Ce.Decir({ importante = true, texto = "Tercero importante" })
    check(r == "espera" and r2 == "espera", "lo importante no esperó su turno: " .. tostring(r) .. " / " .. tostring(r2))
    check(Ce.historial[1] and Ce.historial[1].texto == "Primero importante", "lo segundo pisó a lo primero")
    check(not enHistorial("Segundo importante"), "lo segundo salió mientras hablaba lo primero")
    UI.Callar() -- se fue el globo
    RUN_TIMERS(1)
    check(enHistorial("Segundo importante"), "lo que esperaba no salió al callarse el globo")
    check(not enHistorial("Tercero importante"), "lo tercero no esperó a que se callara lo segundo")
    UI.Callar()
    RUN_TIMERS(1)
    check(enHistorial("Tercero importante"), "lo tercero se perdió")
    -- Lo que pides tú (pedido) sale al momento, aunque hable de algo importante.
    UI.Callar(true)
    Ce.Decir({ importante = true, texto = "Cuarto importante" })
    check(Ce.Decir({ pedido = true, texto = "Lo pediste" }) == true and Ce.historial[1].texto == "Lo pediste", "lo que pediste esperó")
    UI.Callar(true)
    RUN_TIMERS(1)
    local cola = Ce.Cola and Ce.Cola() or {}
    check(#cola == 0, "quedó algo en la cola de Lya")
  end)
end)

---------------------------------------------------------------------------
-- 5. El latido de Lya y «lya.finMazmorra», solo cuando hacen falta
---------------------------------------------------------------------------
step("Lya: el latido va en el reloj y solo con Lya a la vista; «lya.finMazmorra» solo adentro", function()
  local f = UI.Frame and UI.Frame()
  if f then f:Hide() end
  Ce.Aplicar()
  check(UI.Visible(), "Lya no salió")
  check(N.HayTarea("lya.latido"), "con Lya a la vista el latido no está en el reloj («lya.latido»)")
  Ce.Mostrar(false)
  check(not UI.Visible(), "Lya no se ocultó")
  check(not N.HayTarea("lya.latido"), "con Lya oculta el latido sigue en el reloj")
  Ce.Mostrar(true)
  check(N.HayTarea("lya.latido"), "al volver Lya el latido no volvió al reloj")
  check(not N.HayTarea("lya.finMazmorra"), "afuera de una mazmorra corre «lya.finMazmorra»")
  RUN_TIMERS(2)
  local t = N.Reloj.lista["lya.latido"]
  check(t and t.veces > 0 and t.fallos == 0, "el latido no corre en el reloj o falla")
end)

---------------------------------------------------------------------------
-- 6. Lo de la entrada no se pierde por el saludo
---------------------------------------------------------------------------
-- Solo las tareas de la prueba en el reloj (las de los módulos, aparte).
local function soloMias(fn)
  local lista = N.Reloj.lista
  local aparte = {}
  for k, t in pairs(lista) do aparte[k] = t end
  for k in pairs(aparte) do lista[k] = nil end
  local ok, e = pcall(fn)
  for k, t in pairs(aparte) do if lista[k] == nil then lista[k] = t end end
  N.Cada("prueba.replan", 1, function() end)
  N.Quitar("prueba.replan")
  if not ok then error(e) end
end
local function enHistorialDe(patron)
  for _, x in ipairs(Ce.historial or {}) do
    if type(x.texto) == "string" and x.texto:find(patron, 1, true) then return true end
  end
  return false
end

step("Lya al entrar: «La última vez cazamos…» espera su turno y queda dicho cuando sale", function()
  local Di = Ly.Dia
  check(type(Di.ContarAyer) == "function", "falta Dia.ContarAyer")
  soloMias(function()
    conLyaReal(function()
      UI.Aplicar()
      UI.Callar(true)
      local d = N.DatosPersonaje("lya")
      Di.Hoy()
      d.diaAyer = { fecha = "2026-11-18", misiones = 7, niveles = 1, oro = 0, raros = 0, muertes = 0, minutos = 50 }
      -- Lya acaba de saludar.
      Ce.Decir({ pedido = true, texto = "Hola de prueba" })
      UI.Callar(true)
      local hablo = Di.ContarAyer and Di.ContarAyer()
      check(not hablo, "habló encima de su espera entre globos")
      check(d.diaAyer.dicho ~= true, "quedó como dicho sin decirlo")
      check(N.HayTarea("lya.diaAyer"), "no lo vuelve a intentar cuando pase la espera («lya.diaAyer»)")
      NOW = NOW + 400
      RUN_TIMERS(1)
      check(enHistorialDe("La última vez cazamos 7 misiones"), "pasada la espera, no contó cómo te fue la última vez")
      check(d.diaAyer.dicho == true, "lo dijo y no quedó como dicho")
      UI.Callar(true)
    end)
  end)
end)

step("Lya al entrar: la fiesta del día espera su turno", function()
  local Ah = Ly.Ahora
  local fiestas = Ah.Fiestas
  Ah.Fiestas = function() return { { nombre = "Feria de prueba" } } end
  local ok, e = pcall(soloMias, function()
    conLyaReal(function()
      UI.Aplicar()
      UI.Callar(true)
      local d = N.DatosPersonaje("lya")
      d.ahora = type(d.ahora) == "table" and d.ahora or {}
      d.ahora.festejo = nil
      Ce.Decir({ pedido = true, texto = "Hola de prueba 2" })
      UI.Callar(true)
      check(not Ah.Festejo(), "la fiesta habló encima de su espera entre globos")
      check(N.HayTarea("lya.fiesta"), "la fiesta no lo vuelve a intentar («lya.fiesta»)")
      NOW = NOW + 400
      RUN_TIMERS(1)
      check(enHistorialDe("Feria de prueba"), "pasada la espera, la fiesta del día se perdió")
      check(d.ahora.festejo == date("%Y-%m-%d"), "la fiesta salió y no quedó dicha hoy")
      UI.Callar(true)
    end)
  end)
  Ah.Fiestas = fiestas
  if not ok then error(e) end
end)

---------------------------------------------------------------------------
-- 7. Importar perfiles: las líneas que no sirven se saltan y se cuentan
---------------------------------------------------------------------------
step("Perfiles: al leer se saltan las líneas que no sirven y se cuentan", function()
  local texto = table.concat({ "Alfa:perfil:1",
    ".=b:1", "a..b=b:1", "lya.=b:1",           -- rutas con un pedazo vacío
    "lya.minutos=n:1e999", "lya.minutos=n:-1e999", -- números que no son finitos
    "lya.minutos=s:cinco", "lya.mostrar=n:1",    -- de otro tipo que el del ajuste
    "lya.minutos=n:5" }, "\n")
  local ok, n, plano, ign = Pf.Leer(texto)
  check(ok and n == 1 and type(plano) == "table" and plano["lya.minutos"] == 5,
    "no quedó solo lo bueno: " .. tostring(n) .. " ajustes, lya.minutos = " .. tostring(plano and plano["lya.minutos"]))
  check(ign == 7, "no contó las 7 líneas ignoradas: " .. tostring(ign))
  check(type(plano) == "table" and plano["."] == nil and plano["a..b"] == nil and plano["lya."] == nil, "una ruta con un pedazo vacío pasó")
  -- Importar: no truena y deja fuera lo malo.
  local bien, err = pcall(Pf.Importar, "Alfa:perfil:1\n.=b:1\nlya.minutos=n:6")
  check(bien, "importar una ruta «.» truena: " .. tostring(err))
  local ok2, n2, ign2 = false, nil, nil
  if bien then ok2, n2, ign2 = Pf.Importar("Alfa:perfil:1\n.=b:1\nlya.minutos=n:6") end
  check(ok2 and n2 == 1 and ign2 == 1 and A.Get("lya.minutos") == 6, "importar no dejó fuera lo malo: " .. tostring(n2) .. " / " .. tostring(ign2))
  -- Sin nada bueno no se importa (y no se borra lo de ahora).
  local antes = A.Get("lya.minutos")
  local ok3, por = Pf.Importar("Alfa:perfil:1\n.=b:1\nlya.minutos=n:1e999")
  check(not ok3 and por == "formato" and A.Get("lya.minutos") == antes, "un texto sin nada bueno se importó o borró tus ajustes")
  -- Lo de siempre sigue: un texto que no es perfil no se acepta.
  check(not Pf.Leer("Alfa:perfil:1\nqol.x=s:1\n_G.HACKEADO=true"), "aceptó una línea que no es ajuste")
  volverAjustes()
end)

---------------------------------------------------------------------------
-- 8. Las migraciones, una por una (al final: registra dos de prueba)
---------------------------------------------------------------------------
step("Migraciones: se anotan una por una; la de un módulo que se prende después corre", function()
  local db = A.DB()
  local antesSet, antesN = db.alfaMigraciones, db.alfaSchema
  -- Una cuenta de antes del conjunto: se siembra con todo lo que ya estaba hecho.
  -- (con el número más alto de las que hay hoy: otras versiones agregan las suyas)
  N.CorrerMigraciones()
  local hoy = math.max(3, N.Esquema())
  db.alfaMigraciones = nil
  db.alfaSchema = hoy
  local n0 = N.CorrerMigraciones()
  local h = db.alfaMigraciones
  check(n0 == 0, "una cuenta ya mudada volvió a correr migraciones (" .. tostring(n0) .. ")")
  check(type(h) == "table" and h[1] and h[2] and h[3], "no se sembró el conjunto de las migraciones hechas")
  h = type(h) == "table" and h or {}
  local corrio = {}
  -- La 9, de un módulo que sí está: corre.
  N.Migracion(9, function() corrio[9] = (corrio[9] or 0) + 1 end)
  N.CorrerMigraciones()
  check(corrio[9] == 1 and db.alfaSchema == 9 and h[9], "la migración 9 no corrió o no se anotó")
  -- La 8 era de un módulo apagado: se prende después y corre aunque ya se vaya en la 9.
  N.Migracion(8, function() corrio[8] = (corrio[8] or 0) + 1 end)
  N.CorrerMigraciones()
  check(corrio[8] == 1, "la migración de un módulo que se prendió después no corrió")
  check(db.alfaSchema == 9 and h[8], "la migración 8 no quedó anotada (o bajó el número)")
  -- Hechas, no vuelven a correr.
  N.CorrerMigraciones()
  check(corrio[8] == 1 and corrio[9] == 1, "una migración corrió dos veces")
  -- Unos ajustes de la 8 (un respaldo de antes): vuelve a correr la 9, no la 8.
  N.MigrarDesde(8)
  check(corrio[9] == 2 and corrio[8] == 1 and db.alfaSchema == 9, "N.MigrarDesde no volvió a correr solo las de después")
  db.alfaMigraciones, db.alfaSchema = antesSet, antesN
end)

volverAjustes()
print("PRUEBA: 1.3.1 núcleo y Lya, " .. pasos .. " pasos, " .. #ERRORS .. " errores")
