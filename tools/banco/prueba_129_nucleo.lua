-- Prueba de la 1.2.9, el núcleo y la bienvenida (los puntos 19, 23, 24, 25 y 31):
--   * los errores atrapados: solo los de Alfa, sin repetir, con versión y
--     fecha, los últimos 30; el manejador va delante del que había (y le pasa
--     el error); BugGrabber; /alfa reportar los lleva; «Copiar» y «Borrar»;
--   * un solo reloj: N.Cada / N.Una / N.Quitar con un marco que duerme;
--     errores de una tarea; en combate espera; /alfa rendimiento;
--   * respaldos: semanal, antes de una migración, los últimos 3, restaurar
--     (pregunta y guarda «Antes de restaurar»), ajustes que llegan vacíos;
--   * Revisar Alfa: addons que chocan (y su arreglo), partes apagadas o de
--     otra versión, ajustes raros, datos guardados; /alfa diagnostico;
--   * Alfa sencillo / completo: la barra de secciones, los avisos de detalle,
--     el asistente, Ajustes y la migración 3 (cuenta nueva y de antes).
SNAPSHOTS = {}
BANCO_LETRA = 0.64
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
local function check(cond, msg) if not cond then NOTE("1.2.9 núcleo", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

-- BugGrabber de mentira: se registra al entrar.
local bgAviso
BugGrabber = { RegisterCallback = function(_, evento, fn) if evento == "BugGrabber_BugGrabbed" then bgAviso = fn end end }

Alfa.Hidden = function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(3)

local A, N, K = Alfa, AlfaNucleo, AlfaNucleo.Kit
local M = NS_OF("Alfa_Bienvenida")

-- Los avisos y los diálogos que salen.
local avisos, dialogos = {}, {}
local avisoOrig, dialogoOrig = K.Aviso, K.Dialogo
K.Aviso = function(o) avisos[#avisos + 1] = o return avisoOrig(o) end
K.Dialogo = function(o) dialogos[#dialogos + 1] = o return dialogoOrig(o) end
local function ultimoAviso() return avisos[#avisos] end

-- Lo que se manda a copiar (la ventana del motor).
local copias = {}
local UI = A.UI
local copiaOrig = UI and UI.ShowCopy
if UI then UI.ShowCopy = function(titulo, texto, o) copias[#copias + 1] = { titulo = titulo, texto = texto } end end

---------------------------------------------------------------------------
-- 19. Errores atrapados
---------------------------------------------------------------------------
step("Errores: solo los de Alfa, sin repetir, con versión", function()
  check(type(N.AnotarError) == "function" and type(N.Errores) == "function", "faltan N.AnotarError / N.Errores")
  N.BorrarErrores()
  local msg = 'Interface/AddOns/Alfa_Rutas/Guias.lua:120: attempt to index a nil value'
  check(N.AnotarError(msg, nil) == true, "un error de Alfa_Rutas no se anotó")
  check(N.AnotarError(msg, nil) == true, "el mismo error no se anotó otra vez")
  check(N.AnotarError('Interface/AddOns/OtroAddon/x.lua:5: boom', 'Interface/AddOns/OtroAddon/x.lua:5: in function') == false,
    "se anotó un error de otro addon")
  -- Uno de otro addon que pasa por el código de Alfa (su pila nombra a Alfa) sí cuenta.
  check(N.AnotarError('Interface/AddOns/OtroAddon/y.lua:9: algo', '[string "@Interface/AddOns/Alfa/Core/Init.lua"]:240: in function') == true,
    "un error cuya pila pasa por Alfa no se anotó")
  -- Un addon "Alfa_..." de otro autor no es de Alfa.
  ADDON_META["Alfa_DeOtro"] = { Title = "Alfa de otro", Author = "Fulano" }
  check(N.AnotarError('Interface/AddOns/Alfa_DeOtro/a.lua:1: x', nil) == false, "un addon Alfa_ de otro autor contó como de Alfa")
  ADDON_META["Alfa_DeOtro"] = nil
  local l = N.Errores()
  check(#l == 2, "se esperaban 2 errores guardados, hay " .. #l)
  local e = l[1]
  check(e and e.n == 2, "el error repetido no lleva 2 veces: " .. tostring(e and e.n))
  check(e and e.v == tostring(N.version), "el error no lleva la versión de Alfa")
  check(e and type(e.cuando) == "string" and e.cuando ~= "", "el error no lleva cuándo fue")
  check(e and not e.msg:find("Interface/AddOns", 1, true), "el mensaje lleva la ruta larga: " .. tostring(e and e.msg))
  check(e and e.addon == "Alfa_Rutas", "el error no sabe de qué parte de Alfa es")
  -- Se guarda en la cuenta.
  check(type(AlfaNucleoDB) == "table" and type(AlfaNucleoDB.errores) == "table" and AlfaNucleoDB.errores.lista == l,
    "los errores no se guardan en AlfaNucleoDB.errores")
end)

step("Errores: los últimos 30", function()
  N.BorrarErrores()
  for i = 1, 40 do N.AnotarError("Interface/AddOns/Alfa_Lya/Lya.lua:" .. i .. ": error " .. i, nil) end
  local l = N.Errores()
  check(#l == 30, "se guardaron " .. #l .. " errores, el tope es 30")
  check(l[30] and l[30].msg:find("error 40", 1, true), "el más nuevo no quedó al final")
  check(l[1] and l[1].msg:find("error 11", 1, true), "no se quitaron los más viejos")
  -- El repetido pasa al final.
  N.AnotarError("Interface/AddOns/Alfa_Lya/Lya.lua:15: error 15", nil)
  check(N.Errores()[30].msg:find("error 15", 1, true) and N.Errores()[30].n == 2, "un error repetido no pasó al final con su cuenta")
  local texto = N.ErroresTexto()
  check(texto:find("2x %[" .. tostring(N.version):gsub("%.", "%%.") .. "%]") ~= nil, "el texto para copiar no lleva cuántas veces y la versión")
end)

step("Errores: el manejador va delante del de antes y le pasa el error", function()
  local gOrig, sOrig = geterrorhandler, seterrorhandler
  local recibido, puesto
  local delJuego = function(m) recibido = m return "visto" end
  geterrorhandler = function() return puesto or delJuego end
  seterrorhandler = function(fn) puesto = fn end
  N.PonerManejador()
  check(puesto == N.ManejadorErrores, "no se puso el manejador de Alfa")
  check(N.ManejadorPrevio() == delJuego, "no se guardó el manejador de antes")
  N.BorrarErrores()
  local r = puesto("Interface/AddOns/Alfa_Bolsas/Bolsas.lua:3: falla de prueba")
  check(recibido == "Interface/AddOns/Alfa_Bolsas/Bolsas.lua:3: falla de prueba", "el manejador de antes no recibió el error")
  check(r == "visto", "no se devolvió lo que dijo el manejador de antes")
  check(#N.Errores() == 1, "el manejador no anotó el error")
  puesto("Interface/AddOns/Otro/z.lua:1: ajeno")
  check(#N.Errores() == 1 and recibido:find("ajeno"), "un error ajeno se anotó o no se pasó")
  -- Ponerlo otra vez no lo encadena consigo mismo.
  N.PonerManejador()
  check(N.ManejadorPrevio() == delJuego, "el manejador se encadenó consigo mismo")
  geterrorhandler, seterrorhandler = gOrig, sOrig
  N.PonerManejador() -- vuelve al del banco
end)

step("Errores: con BugGrabber se escucha su aviso", function()
  check(type(bgAviso) == "function", "no se escuchó BugGrabber_BugGrabbed")
  if not bgAviso then return end
  N.BorrarErrores()
  bgAviso("BugGrabber_BugGrabbed", { message = "Interface/AddOns/Alfa_Mundo/Mapa.lua:77: de BugSack", stack = "" })
  check(#N.Errores() == 1 and N.Errores()[1].msg:find("de BugSack", 1, true), "el error de BugGrabber no se anotó")
end)

step("Errores: /alfa reportar los lleva", function()
  check(type(M.ComponerReporte) == "function", "falta M.ComponerReporte")
  local r = M.ComponerReporte()
  check(r:find("de BugSack", 1, true) ~= nil, "el reporte no lleva el error atrapado")
  check(r:find("[" .. tostring(N.version) .. "]", 1, true) ~= nil, "el reporte no dice de qué versión es el error")
end)

step("Errores: la sección «Errores atrapados» copia y borra", function()
  local Rs = M.Respaldos
  check(Rs and Rs.CopiarErrores and Rs.BorrarErrores, "faltan Copiar / Borrar errores")
  local antes = #copias
  Rs.CopiarErrores()
  check(#copias == antes + 1 and copias[#copias].texto:find("de BugSack", 1, true), "«Copiar» no dio el texto de los errores")
  Rs.BorrarErrores()
  check(#N.Errores() == 0, "«Borrar» no vació la lista")
  antes = #copias
  Rs.CopiarErrores()
  check(#copias == antes, "sin errores se abrió la ventana para copiar")
  check(Rs.ResumenErrores():find("todo en orden", 1, true) ~= nil, "sin errores no dice que todo está en orden")
end)

---------------------------------------------------------------------------
-- 23. Un solo reloj
---------------------------------------------------------------------------
local reloj = N.Reloj and N.Reloj.marco
local function tic(dt) FIRE(reloj, "OnUpdate", dt or 0.1) end
-- Aquí el reloj se mueve a mano (sin esto, RUN_TIMERS corre sus tareas en cada vuelta).
BANCO_RELOJ_REAL = true
-- Las tareas de los módulos (1.2.9: todas en este reloj) se apartan mientras
-- tanto, para ver dormir al marco con solo las de la prueba.
local apartadas = {}
for clave, t in pairs(N.Reloj.lista or {}) do apartadas[clave] = t end
for clave in pairs(apartadas) do N.Reloj.lista[clave] = nil end

step("Reloj: una tarea que se repite y el marco que duerme", function()
  check(type(N.Cada) == "function" and type(N.Quitar) == "function" and reloj, "faltan N.Cada / N.Quitar / N.Reloj")
  local veces, dts = 0, {}
  N.Cada("prueba.cada", 5, function(dt) veces = veces + 1 dts[#dts + 1] = dt end)
  check(N.HayTarea("prueba.cada"), "la tarea no quedó anotada")
  check(not reloj:IsShown(), "con 5 s por delante el reloj no duerme")
  tic()
  check(veces == 0, "la tarea corrió antes de tiempo")
  NOW = NOW + 5
  T(1) -- el despertador
  check(reloj:IsShown(), "el reloj no despertó a tiempo")
  tic()
  check(veces == 1, "la tarea no corrió al llegar su hora (" .. veces .. ")")
  check(not reloj:IsShown(), "el reloj no se volvió a dormir")
  NOW = NOW + 5
  T(1)
  tic()
  check(veces == 2, "la tarea no se repitió")
  check(dts[2] and dts[2] >= 4.9, "la tarea no recibe los segundos desde su última vez: " .. tostring(dts[2]))
  N.Quitar("prueba.cada")
  check(not N.HayTarea("prueba.cada"), "N.Quitar no quitó la tarea")
  NOW = NOW + 10
  T(2)
  tic()
  check(veces == 2, "una tarea quitada siguió corriendo")
end)

step("Reloj: una sola vez, «ya», reemplazo y sin tareas no corre", function()
  local una, ya = 0, 0
  N.Una("prueba.una", 0.1, function() una = una + 1 end)
  check(reloj:IsShown(), "con una tarea cerca el reloj no queda despierto")
  NOW = NOW + 0.2
  tic()
  check(una == 1 and not N.HayTarea("prueba.una"), "N.Una no corrió una vez y se quitó")
  NOW = NOW + 1
  tic()
  check(una == 1, "N.Una corrió dos veces")
  N.Cada("prueba.ya", 60, function() ya = ya + 1 end, { ya = true })
  tic()
  check(ya == 1, "con o.ya la tarea no corrió en el siguiente cuadro")
  local otra = 0
  N.Cada("prueba.ya", 60, function() otra = otra + 1 end, { ya = true })
  tic()
  check(ya == 1 and otra == 1, "la misma clave no reemplazó la tarea")
  N.Quitar("prueba.ya")
  local quedan = 0
  for _, t in ipairs(N.Tareas()) do if t.clave:find("^prueba%.") then quedan = quedan + 1 end end
  check(quedan == 0, "quedaron tareas de la prueba")
end)

step("Reloj: una tarea con error se avisa y, a la quinta, se quita", function()
  local antes = #ERRORS
  N.Cada("prueba.falla", 1, function() error("falla a propósito") end, { ya = true })
  for _ = 1, 6 do tic() NOW = NOW + 1.1 T(1) end
  local avisados = #ERRORS - antes
  -- El banco anota cada error que llega al manejador: aquí son a propósito.
  for i = #ERRORS, antes + 1, -1 do table.remove(ERRORS, i) end
  check(avisados == 5, "se esperaban 5 errores avisados, hubo " .. avisados)
  check(not N.HayTarea("prueba.falla"), "la tarea que falla siempre no se quitó")
end)

step("Reloj: en combate espera a que termine", function()
  local veces = 0
  local combate = InCombatLockdown
  InCombatLockdown = function() return true end
  N.Cada("prueba.combate", 1, function() veces = veces + 1 end, { ya = true, fueraDeCombate = true })
  tic()
  check(veces == 0, "una tarea fueraDeCombate corrió en combate")
  InCombatLockdown = combate
  NOW = NOW + 1.1
  T(1)
  tic()
  check(veces == 1, "la tarea no corrió al salir de combate")
  N.Quitar("prueba.combate")
end)

step("Reloj: /alfa rendimiento cuenta memoria, procesador y tareas", function()
  local Pf = M.Perfiles
  N.Cada("prueba.rend", 30, function() end)
  local impreso = {}
  local imp = N.Imprimir
  N.Imprimir = function(t) impreso[#impreso + 1] = tostring(t) return imp(t) end
  local _, info = Pf.Rendimiento()
  N.Imprimir = imp
  check(type(info) == "table" and info.tareas and info.tareas >= 1, "rendimiento no cuenta las tareas del reloj")
  local todo = table.concat(impreso, "\n")
  -- En el banco no hay perfilador ni scriptProfile: se explica cómo encenderlo.
  check(info.como == nil and todo:find("scriptProfile 1", 1, true), "sin perfilador no se explica cómo medir el procesador")
  -- Con el perfilador del juego, ms por cuadro de cada parte.
  C_AddOnProfiler = { IsEnabled = function() return true end, GetAddOnMetric = function(n) return n == "Alfa" and 0.5 or 0.1 end }
  Enum = Enum or {}
  local enumAntes = Enum.AddOnProfilerMetric
  Enum.AddOnProfilerMetric = { RecentAverageTime = 1 }
  local como, lista, total = Pf.Procesador({ "Alfa", "Alfa_Nucleo" })
  check(como == "perfilador" and lista[1][1] == "Alfa" and math.abs(total - 0.6) < 1e-6, "el perfilador del juego no se lee bien")
  C_AddOnProfiler = nil
  Enum.AddOnProfilerMetric = enumAntes
  N.Quitar("prueba.rend")
end)

for clave, t in pairs(apartadas) do N.Reloj.lista[clave] = t end
BANCO_RELOJ_REAL = nil

---------------------------------------------------------------------------
-- 24. Respaldos
---------------------------------------------------------------------------
step("Respaldos: hacer, los últimos 3 y lo que llevan", function()
  check(type(N.Respaldar) == "function" and type(N.Respaldos) == "function", "faltan N.Respaldar / N.Respaldos")
  local l = N.Respaldos()
  for i = #l, 1, -1 do l[i] = nil end
  for k, v in pairs({ ["bolsas.agrupar"] = false, ["pesca.sonido"] = false, ["ui.textSize"] = 1.2, ["mundo.estiloMapa"] = "clasico",
      ["recoleccion.minimapa"] = false, ["inicio.verDiario"] = false }) do A.Set(k, v) end
  M.Perfiles.Guardar("Mi perfil de prueba")
  for i = 1, 4 do
    local ok = N.Respaldar(i == 4 and "manual" or "semanal")
    check(ok, "no se pudo respaldar")
  end
  l = N.Respaldos()
  check(#l == 3, "se guardaron " .. #l .. " respaldos, el tope es 3")
  local r = l[#l]
  check(r.motivo == "manual" and r.v == tostring(N.version) and r.cuando ~= "", "el respaldo no lleva motivo, versión y fecha")
  check(r.n >= 6 and r.ajustes.bolsas and r.ajustes.bolsas.agrupar == false, "el respaldo no lleva los ajustes")
  check(r.extras.perfiles and r.extras.perfiles["Mi perfil de prueba"], "el respaldo no lleva tus perfiles")
  -- Es una copia: cambiar los ajustes no cambia el respaldo.
  A.Set("bolsas.agrupar", true)
  check(r.ajustes.bolsas.agrupar == false, "el respaldo no es una copia")
  check(type(AlfaNucleoDB.respaldos) == "table" and AlfaNucleoDB.respaldos.lista == l, "los respaldos no viven en AlfaNucleoDB")
  check(M.Respaldos.Texto(r):find(tostring(N.version), 1, true), "el texto del respaldo no dice la versión")
end)

step("Respaldos: restaurar pregunta y guarda «Antes de restaurar»", function()
  local Rs = M.Respaldos
  local l = N.Respaldos()
  A.Set("pesca.sonido", true)
  M.Perfiles.Borrar("Mi perfil de prueba")
  local antes = #dialogos
  Rs.Restaurar(#l)
  check(#dialogos == antes + 1, "restaurar no preguntó primero")
  check(A.Get("pesca.sonido") == true, "se restauró antes de aceptar")
  local d = dialogos[#dialogos]
  d.alAceptar()
  K.CerrarDialogo()
  check(A.Get("pesca.sonido") == false and A.Get("bolsas.agrupar") == false, "restaurar no devolvió los ajustes")
  local hay = {}
  for _, n in ipairs(M.Perfiles.Lista()) do hay[n] = true end
  check(hay["Antes de restaurar"], "lo de antes no quedó como el perfil «Antes de restaurar»")
  check(hay["Mi perfil de prueba"], "el perfil borrado no volvió con el respaldo")
  local a = ultimoAviso()
  check(a and a.accion and a.accion.texto == "Recargar ahora", "restaurar no ofrece recargar")
end)

step("Respaldos: cada semana y antes de una migración", function()
  local x = AlfaNucleoDB.respaldos
  x.ultimo = os.time() - 3600
  local n = #N.Respaldos()
  check(not N.RespaldoSemanal(), "se respaldó otra vez en la misma semana")
  x.ultimo = os.time() - 8 * 24 * 3600
  check(N.RespaldoSemanal(), "pasada una semana no se respaldó")
  check(N.Respaldos()[#N.Respaldos()].motivo == "semanal", "el semanal no dice que es semanal")
  local visto
  N.Migracion(950, function(db) visto = N.Respaldos()[#N.Respaldos()].motivo end)
  local corridas = N.CorrerMigraciones()
  check(corridas == 1, "la migración de prueba no corrió")
  check(visto == "migracion", "no hubo respaldo antes de la migración (" .. tostring(visto) .. ")")
  check(N.CorrerMigraciones() == 0 and N.Respaldos()[#N.Respaldos()].motivo == "migracion", "sin migraciones pendientes se respaldó otra vez")
  check(n <= 3 and #N.Respaldos() == 3, "pasaron de 3 respaldos")
end)

step("Respaldos: ajustes que llegan vacíos ofrecen restaurar", function()
  local db = A.DB()
  local guardado = db.settings
  db.settings = {}
  AlfaNucleoDB.respaldos.ofrecido = nil
  local r = N.RevisarAjustes()
  check(r ~= nil and N.AjustesDanados() == r, "unos ajustes vacíos no se vieron como dañados")
  check(not N.RespaldoSemanal() and not N.AntesDeMigrar(), "con los ajustes vacíos se respaldó encima")
  local antes = #avisos
  T(12) -- el aviso sale unos segundos después
  local a
  for i = antes + 1, #avisos do if avisos[i].accion and avisos[i].accion.texto == "Restaurar" then a = avisos[i] end end
  check(a ~= nil, "no salió el aviso para restaurar")
  -- Solo una vez por respaldo.
  check(N.RevisarAjustes() == nil, "el aviso de ajustes vacíos se repite")
  -- Revisar Alfa también lo dice.
  N.RevisarAjustes()
  db.settings = guardado
end)

step("Respaldos: la sección en Estilo y sonido", function()
  N.Abrir("bienvenida")
  T(2)
  local vista = M.vista
  check(vista and vista:IsVisible(), "la página Estilo y sonido no se abrió")
  local textos = {}
  local function juntar(f)
    for _, h in ipairs(rawget(f, "_children") or {}) do
      if h._kind == "FontString" and h:IsVisible() and h.GetText then textos[#textos + 1] = tostring(h:GetText() or "") end
      juntar(h)
    end
  end
  juntar(vista)
  local todo = table.concat(textos, "\n")
  check(todo:find("Respaldos", 1, true), "falta la sección Respaldos")
  check(todo:find("El más reciente", 1, true), "no se ve el respaldo más reciente")
  check(todo:find("Errores atrapados", 1, true), "falta la sección Errores atrapados")
  check(todo:find("Revisar Alfa", 1, true), "falta «Revisar Alfa»")
  check(todo:find("Cómo ves Alfa", 1, true), "falta «Cómo ves Alfa»")
  N.CerrarVentana()
end)

---------------------------------------------------------------------------
-- 25. Revisar Alfa
---------------------------------------------------------------------------
local Dg = M.Diagnostico
local function hallazgo(id)
  for _, x in ipairs(Dg.Revisar()) do if x.id == id then return x end end
end

step("Diagnóstico: un addon que choca y su arreglo", function()
  check(Dg and Dg.Revisar, "falta M.Diagnostico")
  check(hallazgo("choque.bolsas") == nil, "sin Bagnon salió que choca")
  ADDON_META["Bagnon"] = { Title = "Bagnon" }
  LOADED["Bagnon"] = true
  A.Set("bolsas.reemplazar", true)
  local x = hallazgo("choque.bolsas")
  check(x and x.tono == "aviso" and x.arreglo, "con Bagnon no salió que choca con las bolsas")
  check(x and x.texto:find("Bagnon", 1, true), "el texto no nombra a Bagnon")
  if x then x.arreglo.alClic() end
  check(A.Get("bolsas.reemplazar") == false and A.Get("bolsas.banco") == false, "el arreglo no apagó las bolsas de Alfa")
  check(LOADED["Bagnon"] == true, "el arreglo tocó a Bagnon")
  check(hallazgo("choque.bolsas") == nil, "lo arreglado sigue saliendo")
  LOADED["Bagnon"], ADDON_META["Bagnon"] = nil, nil
  A.Set("bolsas.reemplazar", nil) A.Set("bolsas.banco", nil)
  -- TomTom: dos flechas, una sola con un clic.
  ADDON_META["TomTom"] = { Title = "TomTom" }
  LOADED["TomTom"] = true
  local t = hallazgo("choque.tomtom")
  if A.GetDefault("nav.useTomTomArrow") ~= nil then
    check(t and t.arreglo, "con TomTom no se ofreció usar una sola flecha")
    if t then t.arreglo.alClic() end
    check(A.Get("nav.useTomTomArrow") == true, "el arreglo de TomTom no usó su flecha")
    A.Set("nav.useTomTomArrow", nil)
  end
  LOADED["TomTom"], ADDON_META["TomTom"] = nil, nil
  -- Questie: solo se cuenta.
  ADDON_META["Questie"] = { Title = "Questie" }
  LOADED["Questie"] = true
  local q = hallazgo("choque.questie")
  check(q and q.tono == "info" and not q.arreglo, "Questie no salió como aviso sin arreglo")
  LOADED["Questie"], ADDON_META["Questie"] = nil, nil
end)

step("Diagnóstico: partes de Alfa apagadas o de otra versión", function()
  local CA = C_AddOns
  local estado, enable = CA.GetAddOnEnableState, CA.EnableAddOn
  local encendidas = {}
  CA.GetAddOnEnableState = function(n) if n == "Alfa_Pesca" then return 0 end return estado(n) end
  CA.EnableAddOn = function(n) encendidas[#encendidas + 1] = n end
  local x = hallazgo("partes.apagadas")
  check(x and x.texto:find("Alfa_Pesca", 1, true) and x.arreglo, "una parte apagada no salió con «Activar módulo»")
  if x then x.arreglo.alClic() end
  check(encendidas[1] == "Alfa_Pesca", "«Activar módulo» no encendió la parte")
  local a = ultimoAviso()
  check(a and a.accion and a.accion.texto == "Recargar ahora", "activar un módulo no ofrece recargar")
  CA.GetAddOnEnableState, CA.EnableAddOn = estado, enable
  local meta = ADDON_META["Alfa_Pesca"]
  local v = meta and meta.Version
  if meta then
    meta.Version = "0.9.9"
    local y = hallazgo("partes.version")
    if tostring(A.version) ~= "dev" then check(y and y.texto:find("0.9.9", 1, true), "una parte de otra versión no salió") end
    meta.Version = v
  end
  check(hallazgo("partes.version") == nil, "con todo de la misma versión salió que hay otra")
end)

step("Diagnóstico: ajustes raros, errores y datos guardados", function()
  local claves = { "bolsas.reemplazar", "curacion.activo", "combate.rotacion", "recoleccion.mapa", "pesca.activo",
    "lya.mostrar", "nav.arrow", "comodidades.chat", "comodidades.barras", "comodidades.minimapaEstilo", "nav.routeLines", "behavior.autoAccept" }
  check(hallazgo("ajustes.apagado") == nil, "con lo de fábrica salió que todo está apagado")
  for _, c in ipairs(claves) do if A.GetDefault(c) ~= nil then A.Set(c, false) end end
  local x = hallazgo("ajustes.apagado")
  check(x and x.arreglo, "con todo apagado no salió el aviso")
  for _, c in ipairs(claves) do A.Set(c, nil) end
  check(hallazgo("errores") == nil, "sin errores salió que hay")
  N.AnotarError("Interface/AddOns/Alfa_Inicio/Inicio.lua:1: de prueba", nil)
  local e = hallazgo("errores")
  check(e and e.arreglo and e.arreglo.texto == "Reportar", "con errores no se ofrece reportar")
  N.BorrarErrores()
  local d = hallazgo("datos")
  check(d and d.tono == "bien" and d.texto:find("MB", 1, true), "no se dice cuánto pesan los datos guardados")
  check(Dg.Peso({ a = "hola", b = { 1, 2, 3 } }, { n = 100 }) > 0, "Dg.Peso no mide")
end)

step("Diagnóstico: la ventana y /alfa diagnostico", function()
  ADDON_META["Bagnon"] = { Title = "Bagnon" }
  LOADED["Bagnon"] = true
  A.RunCommand("diagnostico")
  T(2)
  local v = rawget(_G, "AlfaDiagnostico")
  check(v and v:IsShown(), "/alfa diagnostico no abrió la ventana")
  check(Dg.Visible(), "Dg.Visible no lo sabe")
  local boton
  local function buscar(f)
    for _, h in ipairs(rawget(f, "_children") or {}) do
      if h.alClic and h.Texto and h:IsVisible() and tostring(h.Texto:GetText() or "") == "Apagar la parte de Alfa que choca" then boton = h end
      buscar(h)
    end
  end
  if v then buscar(v) end
  check(boton ~= nil, "la ventana no tiene el botón para arreglar el choque")
  if boton then boton.alClic() T(2) end
  check(A.Get("bolsas.reemplazar") == false, "el botón de la ventana no arregló")
  LOADED["Bagnon"], ADDON_META["Bagnon"] = nil, nil
  A.Set("bolsas.reemplazar", nil) A.Set("bolsas.banco", nil)
  if v then v:Cerrar() end
end)

---------------------------------------------------------------------------
-- 31. Alfa sencillo / completo
---------------------------------------------------------------------------
local function seccionesVistas()
  local win = A.UI.Options.frame
  local out = {}
  for _, b in ipairs(win and win.sectionButtons or {}) do if b:IsShown() then out[b.psKey] = true end end
  return out
end
local function pildorasVistas()
  local win = A.UI.Options.frame
  local out, n = {}, 0
  for _, b in ipairs(win and win.pillButtons or {}) do if b:IsShown() then out[b.psKey] = true n = n + 1 end end
  return out, n
end

step("Sencillo: solo lo esencial en la barra, lo demás sigue abriendo", function()
  check(type(N.Modo) == "function" and N.ESENCIALES, "faltan N.Modo / N.ESENCIALES")
  A.Set("bienvenida.modo", "completo")
  N.Abrir("inicio")
  T(2)
  local s = seccionesVistas()
  check(s.oficios and s.manada, "en completo faltan Oficios o Manada en la barra")
  A.Set("bienvenida.modo", "sencillo")
  T(1)
  check(N.Sencillo(), "N.Sencillo no lo sabe")
  s = seccionesVistas()
  check(s.hoy and s.aventura and s.personaje and s.mundo and s.ajustes, "en sencillo falta una sección esencial")
  check(not s.oficios and not s.manada, "en sencillo siguen Oficios o Manada en la barra")
  -- Personaje: Bolsas, Talentos (1.3.3) y Lya, sin Combate.
  A.UI.Options.SelectSection("personaje")
  T(1)
  local p, n = pildorasVistas()
  check(p.bolsas and p.lya and p.builds and not p.combate and n == 3, "Personaje en sencillo no muestra solo Bolsas, Talentos y Lya")
  check(not N.PaginaVisible("pesca") and N.PaginaVisible("bolsas") and N.PaginaVisible("comodidades"), "N.PaginaVisible no sigue la lista")
  -- Una página escondida sigue abriendo (su comando, la búsqueda, un enlace).
  N.Abrir("pesca")
  T(1)
  local O = A.UI.Options
  local vistas = O.Views("pesca")
  local vis = false
  for _, v in ipairs(vistas) do if v:IsVisible() then vis = true end end
  check(vis, "en sencillo la página de Pesca ya no abre")
  A.Set("bienvenida.modo", "completo")
  T(1)
  s = seccionesVistas()
  check(s.oficios and s.manada, "al volver a completo no regresó la barra")
  N.CerrarVentana()
end)

step("Sencillo: menos avisos", function()
  A.Set("bienvenida.modo", "sencillo")
  local r = K.Aviso({ titulo = "Un detalle", detalle = true, lya = false })
  check(r == false, "con sencillo salió un aviso de detalle")
  r = K.Aviso({ titulo = "Algo importante", lya = false })
  check(r and r ~= false, "con sencillo no salió un aviso normal")
  A.Set("bienvenida.modo", "completo")
  r = K.Aviso({ titulo = "Un detalle", detalle = true, lya = false })
  check(r and r ~= false, "con completo no salió el aviso de detalle")
end)

step("Sencillo: en el asistente y en Ajustes", function()
  check(M.MODOS and #M.MODOS == 2, "faltan los modos del asistente")
  local spec = N.ModuloPorId("bienvenida")
  local hay
  for _, c in ipairs(spec.controles or {}) do if c.key == "bienvenida.modo" then hay = c end end
  check(hay and hay.kind == "dropdown", "el buscador de ajustes no encuentra «Cómo ves Alfa»")
  check(A.GetDefault("bienvenida.modo") == "sencillo", "el de fábrica no es sencillo")
  -- El asistente: el paso del estilo trae la elección.
  -- La configuración pendiente sigue donde la dejaste: en el paso del estilo.
  local pasoAntes = N.Datos("bienvenida").paso
  N.Datos("bienvenida").paso = "estilo"
  M.AbrirVentana("asistente")
  T(2)
  N.Datos("bienvenida").paso = pasoAntes
  local v = rawget(_G, "AlfaBienvenidaVentana")
  local textos = {}
  local function juntar(f)
    for _, h in ipairs(rawget(f, "_children") or {}) do
      if h._kind == "FontString" and h.GetText then textos[#textos + 1] = tostring(h:GetText() or "") end
      juntar(h)
    end
  end
  if v then juntar(v) end
  local todo = table.concat(textos, "\n")
  check(todo:find("Alfa sencillo", 1, true) and todo:find("Alfa completo", 1, true), "el asistente no ofrece sencillo y completo")
  if v and v.Cerrar then v:Cerrar() end
end)

step("Sencillo: la migración 3 deja en completo a quien ya tenía Alfa", function()
  local db = A.DB()
  local nueva = A.IsNewAccount
  -- Una cuenta de antes, que nunca eligió.
  A.Set("bienvenida.modo", nil)
  db.alfaSchema = 2
  A.IsNewAccount = function() return false end
  N.CorrerMigraciones()
  check(A.Get("bienvenida.modo") == "completo", "a quien ya tenía Alfa no se le dejó en completo")
  check((tonumber(db.alfaSchema) or 0) >= 3, "la migración 3 no quedó anotada")
  -- Ya hecha, no vuelve a correr: quien después elige sencillo, se queda así.
  A.Set("bienvenida.modo", "sencillo")
  N.CorrerMigraciones()
  check(A.Get("bienvenida.modo") == "sencillo", "la migración 3 corrió dos veces")
  -- Una cuenta nueva queda en sencillo.
  A.Set("bienvenida.modo", nil)
  db.alfaSchema = 2
  A.IsNewAccount = function() return true end
  N.CorrerMigraciones()
  check(A.Get("bienvenida.modo") == "sencillo", "a una cuenta nueva se le puso completo")
  A.IsNewAccount = nueva
end)

K.Aviso, K.Dialogo = avisoOrig, dialogoOrig
if UI then UI.ShowCopy = copiaOrig end
print("PRUEBA: 1.2.9 núcleo, " .. pasos .. " pasos, " .. #ERRORS .. " errores")
