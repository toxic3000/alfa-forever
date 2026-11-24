-- Prueba de la 1.3.9, área interfaz (tools/prueba.py la corre con las demás):
--   34  Hoy: una sola «Siguiente acción» grande (lo urgente o tus misiones listas)
--   35/53  la franja de la primera vez en cada página y su recorrido de 3 pasos
--   36  la tecla de «Cerrar mis misiones» y la de la siguiente parada, a la vista
--   37  «Ahora no / No volver a mostrar» en las tarjetas (y recuperarlas)
--   39  «Deshacer» el último cambio de un ajuste
--   40  la ruta en los mapas con sus colores para daltonismo
--   42  títulos de paso en tu idioma («Into X» -> «Hacia X»), nada en inglés en Hoy
--   51/52  la bienvenida en 3 pantallas, «Ajustar más» y la primera acción real
--   54  el «?» de una página: Lya contesta la primera pregunta de esa página
--   55  Modo aprendiz: Lya explica cada aviso la primera vez (una sola vez)
--   56-62  la tabla de medidas, los tipos de botón, íconos sin repetir, las
--          ventanas con nombre (recuerdan su lugar)
--   75/76  Hoy según dónde estás, y sus partes ocultables y en tu orden
--   77  Planes: reordenar y verlo en el mapa
-- Con BANCO_FOTOS=1 dibuja tools/banco/shot-139i-*.png.
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS or not root then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["139i-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
end
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
local function check(cond, msg) if not cond then NOTE("1.3.9 interfaz", msg) end end

BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local Bv = NS_OF("Alfa_Bienvenida")
local In = NS_OF("Alfa_Inicio")
local Ru = NS_OF("Alfa_Rutas")
local O = A.UI.Options
local B = AlfaBienvenida

local NADA = {}
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do
    antes[k] = { v = rawget(t, k) }
    if v == NADA then rawset(t, k, nil) else rawset(t, k, v) end
  end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(t, k, a.v) end
  if not ok then error(e, 0) end
end
local function textosDe(f)
  local t = {}
  local function ver(x, d)
    if d > 40 or not x:IsShown() then return end
    if x._kind == "FontString" and type(x._text) == "string" then t[#t + 1] = x._text end
    for _, h in ipairs(rawget(x, "_children") or {}) do ver(h, d + 1) end
  end
  if f then ver(f, 0) end
  return table.concat(t, "\n")
end
local function limpiarPantalla()
  for _, n in ipairs({ "AlfaLyaLoba", "AlfaInicioAviso", "AlfaRastreador", "AlfaNavArrow" }) do
    local f = rawget(_G, n)
    if type(f) == "table" and f.Hide then f:Hide() end
  end
end

---------------------------------------------------------------------------
-- 51/52: la bienvenida en 3 pantallas (cuenta nueva: la configuración pendiente)
---------------------------------------------------------------------------
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(4)

step("51: la bienvenida corta tiene 3 pantallas; «Ajustar más» lleva a las de siempre", function()
  check(B and B.Pendiente and B.Pendiente(), "la configuración no quedó pendiente en una cuenta nueva")
  Bv.AbrirVentana("asistente")
  RUN_TIMERS(1)
  local v = rawget(_G, "AlfaBienvenidaVentana")
  check(v and v:IsShown(), "no se abrió la bienvenida")
  local c = v and v.alfaCorto
  check(c and #c.pasos == 3, "la bienvenida corta no tiene 3 pantallas: " .. tostring(c and #c.pasos))
  if not c then return end
  local ids = {}
  for i, p in ipairs(c.pasos) do ids[i] = p.id end
  check(table.concat(ids, ",") == "hola,tuestilo,acazar", "las pantallas no son hola, tu estilo y a cazar: " .. table.concat(ids, ","))
  check(c:IsShown() and not v.alfaAsistente:IsShown(), "no se ve la corta (o se ven las dos)")
  limpiarPantalla()
  SNAP("bienvenida-1", v)
  c:Ir(2) RUN_TIMERS(1)
  SNAP("bienvenida-2", v)
  c:Ir(3) RUN_TIMERS(1)
  local t3 = textosDe(v)
  check(t3:find("¿Qué hacemos primero?", 1, true), "la pantalla 3 no pregunta por la primera acción")
  check(t3:find("Ver Hoy y decidir después", 1, true), "falta la opción de ver Hoy")
  check(c.Saltar and c.Saltar:IsShown(), "no está «Ajustar más» en la pantalla 3")
  SNAP("bienvenida-3", v)
  -- 52: la primera acción de fábrica (nivel 23 con misiones: subir de nivel)
  check(Bv.PrimeraAccion() == "nivel", "la primera acción de fábrica no es subir de nivel: " .. tostring(Bv.PrimeraAccion()))
  -- «Ajustar más»
  Bv.AjustarMas() RUN_TIMERS(1)
  local l = v.alfaAsistente
  check(l:IsShown() and not c:IsShown(), "«Ajustar más» no pasó a las pantallas de siempre")
  local p = l.pasos[l:Paso()]
  check(p and p.id == "extras", "«Ajustar más» no empieza en los extras: " .. tostring(p and p.id))
  check(N.Datos("bienvenida").largo == true, "no recuerda que pediste «Ajustar más»")
  v:Cerrar()
end)

step("52: al terminar la primera vez, Alfa te lleva a tu primera acción (no solo a Hoy)", function()
  local pedido
  local R = rawget(_G, "AlfaRuta")
  con(R, { Asistente = function(camino) pedido = camino end }, function()
    N.Datos("bienvenida").primera = "nivel"
    N.Datos("bienvenida").largo = nil
    Bv.AbrirVentana("asistente")
    RUN_TIMERS(1)
    local v = rawget(_G, "AlfaBienvenidaVentana")
    local c = v.alfaCorto
    c:Ir(3) RUN_TIMERS(1)
    c:Siguiente() -- «Listo»
    RUN_TIMERS(3)
  end)
  check(pedido == "nivel", "no abrió el asistente de la guía (subir de nivel): " .. tostring(pedido))
  check(not B.Pendiente(), "la configuración siguió pendiente")
  -- Al revisar tu configuración ya no te manda a ningún lado.
  pedido = nil
  con(R, { Asistente = function(camino) pedido = camino end }, function()
    Bv.AbrirVentana("asistente") RUN_TIMERS(1)
    local v = rawget(_G, "AlfaBienvenidaVentana")
    check(v.alfaAsistente:IsShown(), "revisar tu configuración no abre la de siempre")
    v.alfaAsistente:Siguiente() RUN_TIMERS(3)
  end)
  check(pedido == nil, "revisar tu configuración te mandó a la guía otra vez")
  local f = O.frame or rawget(_G, "AlfaOptions")
  if f then f:Hide() end
end)

if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
N.Datos("bienvenida").recorrido = true
local Ly = NS_OF("Alfa_Lya")
if Ly and Ly.UI and Ly.UI.Aplicar then pcall(Ly.UI.Aplicar) end

---------------------------------------------------------------------------
-- 56-62: la tabla de medidas y la revisión de consistencia
---------------------------------------------------------------------------
step("56: la tabla de medidas del Kit, y las tarjetas la usan", function()
  local M0 = K.MEDIDA
  check(type(M0) == "table" and M0.pagina and M0.tarjeta and M0.fila and M0.boton, "falta K.MEDIDA")
  if not M0 then return end
  check(M0.boton.chico == K.ALTO.botonChico and M0.boton.normal == K.ALTO.boton and M0.boton.grande == K.ALTO.botonGrande, "los altos de botón no son los del Kit")
  check(M0.pagina.margen == N.MargenPagina(), "el margen de página no es el de la ventana: " .. tostring(N.MargenPagina()))
  local c = K.Tarjeta(UIParent, { variante = "compacta" })
  c:Set({ titulo = "Prueba", valor = "20%" })
  c:Acomodar(300)
  local _, _, _, x = c.Baldosa:GetPoint(1)
  check(x == M0.tarjeta.compacta, "la tarjeta compacta no usa su relleno: " .. tostring(x))
  c:Hide()
end)

-- Todos los botones del Kit de las páginas a la vista: de un tipo y alto conocidos.
local ALTOS = {}
for _, h in pairs(K.MEDIDA and K.MEDIDA.boton or {}) do ALTOS[h] = true end
local raros, vistos = {}, 0
local function revisarBotones(raiz, donde)
  local function ver(f, d)
    if d > 40 or not f:IsShown() then return end
    if rawget(f, "alfaTipo") and rawget(f, "alfaTam") and f.AnchoNatural then
      vistos = vistos + 1
      if not K.MEDIDA.tiposBoton[f.alfaTipo] then raros[#raros + 1] = donde .. ": tipo «" .. tostring(f.alfaTipo) .. "»" end
      local h = math.floor((f:GetHeight() or 0) + 0.5)
      if not rawget(f, "alfaDosLineas") and not ALTOS[h] then raros[#raros + 1] = donde .. ": alto " .. h end
    end
    for _, h in ipairs(rawget(f, "_children") or {}) do ver(h, d + 1) end
  end
  ver(raiz, 0)
end

step("57: en cada página, los botones son principal, secundario, de texto o peligro, con su alto", function()
  local f
  for _, p in ipairs(O.Pages()) do
    A.Fire("SHOW_OPTIONS", p.key) RUN_TIMERS(1)
    f = O.frame or rawget(_G, "AlfaOptions")
    revisarBotones(f, p.key)
  end
  check(vistos > 50, "se revisaron muy pocos botones: " .. vistos)
  for i = 1, math.min(#raros, 10) do NOTE("1.3.9 interfaz", "botón fuera de la tabla: " .. raros[i]) end
  if f then f:Hide() end
end)

step("58: cada página con su ícono, sin repetir", function()
  local por = {}
  for _, m in ipairs(N.modulos or {}) do
    if m.icono and not m.oculto then
      if por[m.icono] and por[m.icono] ~= m.id then NOTE("1.3.9 interfaz", "ícono repetido: " .. m.icono .. " en " .. por[m.icono] .. " y " .. m.id) end
      por[m.icono] = m.id
    end
  end
end)

step("59/62: listas con el lobo cuando están vacías; las ventanas con nombre recuerdan su lugar", function()
  local l = K.Lista(UIParent, {})
  l:SetDatos({})
  local lobo = l.Vacio and l.Vacio.Lobo and l.Vacio.Lobo:GetTexture()
  check(lobo == nil or tostring(lobo):find("lobo", 1, true), "una lista vacía no lleva al lobo")
  l:Hide()
  for _, v in ipairs(K.VENTANAS or {}) do
    check(type(v.alfaNombre) == "string" and v.alfaNombre ~= "", "una ventana del Kit sin nombre no recuerda su lugar")
  end
end)

---------------------------------------------------------------------------
-- 37: Ahora no / No volver a mostrar
---------------------------------------------------------------------------
step("37: la × de una tarjeta oculta su sugerencia «ahora» o «para siempre»", function()
  K.OlvidarDescartes()
  local c = K.Tarjeta(UIParent, { variante = "normal" })
  c:Set({ titulo = "Sugerencia", texto = "Algo útil", descartar = "prueba.sugerencia" })
  c:Acomodar(360)
  check(c.Descartar and c.Descartar:IsShown(), "la tarjeta no trae su ×")
  local elegir
  con(K, { Menu = function(_, ops, _, fn) elegir = { ops = ops, fn = fn } end }, function() c.Descartar:GetScript("OnClick")(c.Descartar, "LeftButton") end)
  check(elegir and #elegir.ops == 2, "la × no ofrece «Ahora no» y «No volver a mostrar»")
  if not elegir then return end
  elegir.fn("ahora")
  check(K.Descartado("prueba.sugerencia") and K.Descartes() == 0, "«Ahora no» no la ocultó solo por ahora")
  elegir.fn("siempre")
  check(K.Descartes() == 1, "«No volver a mostrar» no la guardó")
  K.OlvidarDescartes()
  check(not K.Descartado("prueba.sugerencia"), "«Volver a mostrar» no la recuperó")
  c:Hide()
end)

---------------------------------------------------------------------------
-- Hoy: 34, 37, 75, 76, 42
---------------------------------------------------------------------------
local P = In.Pagina
local Ac = In.Acomodo
local function abrirHoy()
  A.Fire("SHOW_OPTIONS", "inicio") RUN_TIMERS(2)
  if P.view and P.view.Refresh then P.view.alfaSucio = true pcall(N.RehacerPagina, P.view) end
  RUN_TIMERS(1)
  return O.frame or rawget(_G, "AlfaOptions")
end

step("34: sin guía, una sola «Siguiente acción» grande con lo urgente", function()
  local lista = { { clave = "bolsas", tono = "peligro", icono = "ic-bolsas", titulo = "Tus bolsas están llenas", texto = "0 de 16",
    accion = { texto = "Llévame a un vendedor", alClic = function() end } } }
  local d = P.SiguienteAccion(lista)
  check(d and d.titulo == "Tus bolsas están llenas" and d.sobre, "lo urgente no va arriba en grande")
  -- Con misiones listas y nada urgente: entregarlas.
  local R = rawget(_G, "AlfaRuta")
  con(R, { XPListas = function() return { n = 3, xp = 4200 } end, Liberar = function() end }, function()
    local d2 = P.SiguienteAccion({})
    check(d2 and d2.titulo == "Entrega tus misiones listas" and d2.descartar, "con misiones listas no propone entregarlas")
  end)
end)

step("37: una alerta oculta con su × ya no sale en Hoy", function()
  K.OlvidarDescartes()
  local f = abrirHoy()
  local hay = textosDe(f):find("Alertas", 1, true) ~= nil
  K.Descartar("hoy.alerta.bolsas", true)
  K.Descartar("hoy.alerta.entrenar", true)
  K.Descartar("hoy.alerta.equipo", true)
  f = abrirHoy()
  local t = textosDe(f)
  check(not t:find("Tus bolsas están llenas", 1, true), "la alerta de bolsas oculta sigue en Hoy")
  check(t:find("Volver a mostrar", 1, true) ~= nil or not N.Get("inicio", "verAjustes"), "no ofrece volver a mostrar lo oculto")
  K.OlvidarDescartes()
  if f then f:Hide() end
end)

step("75: en la ciudad suben las alertas y Buscar cerca; en una mazmorra, tus misiones", function()
  con(_G, { IsResting = function() return true end }, function()
    check(Ac.Contexto() == "ciudad", "con descanso no es la ciudad")
    local o = Ac.Orden()
    check(o[1] == "alertas" and o[2] == "cerca", "en la ciudad no suben alertas y cerca: " .. table.concat(o, ","))
  end)
  con(_G, { IsInInstance = function() return true, "party" end }, function()
    check(Ac.Contexto() == "mazmorra", "en una mazmorra no lo nota")
    local o = Ac.Orden()
    check(o[1] == "alertas" and o[2] == "clase", "en la mazmorra no suben alertas y clase: " .. table.concat(o, ","))
  end)
  A.Set("inicio.contexto", false)
  con(_G, { IsResting = function() return true end }, function()
    check(Ac.Orden()[1] == "alEntrar", "apagado, el lugar sigue cambiando el orden")
  end)
  A.Set("inicio.contexto", nil)
end)

step("76: ocultar y reordenar las partes de Hoy, y volver al de fábrica", function()
  Ac.Restablecer()
  Ac.Mover("diario", -1)
  local o = Ac.TuOrden()
  check(o[#o] == "revision" and o[#o - 1] == "diario", "subir «Tu diario» no lo movió: " .. table.concat(o, ","))
  Ac.Ver("camino", false)
  check(Ac.Oculta("camino"), "no se ocultó «Camino al 60»")
  local f = abrirHoy()
  check(P.camino and not P.camino:IsShown(), "«Camino al 60» oculto sigue en Hoy")
  local orden = P.tablero.Extra.bloques
  check(orden[#orden].b == P.ajustes, "los ajustes de tus avisos no quedaron al final")
  Ac.Abrir() RUN_TIMERS(1)
  local w = rawget(_G, "AlfaHoyAcomodo")
  check(w and w:IsShown(), "no se abrió «Acomodar Hoy»")
  local tw = textosDe(w)
  check(tw:find("Camino al 60", 1, true) and tw:find("Tu diario", 1, true), "«Acomodar Hoy» no lista las partes")
  limpiarPantalla()
  SNAP("acomodar-hoy", w)
  if w then w:Hide() end
  Ac.Restablecer()
  check(not Ac.Oculta("camino") and Ac.TuOrden()[1] == "alEntrar", "«Volver al orden de fábrica» no lo devolvió")
  if f then f:Hide() end
end)

step("42: un título de paso que quedó en inglés no sale en Hoy", function()
  local E = A.Engine
  local GUIA = { id = "prueba-139", title = "Vallefresno" }
  local vista = { title = "Into Vallefresno", current = 1,
    goals = { { t = "goto", text = "The road north to Splintertree Post", status = "todo", index = 1 } } }
  con(E, { GetGuide = function() return GUIA end, GetLiveStep = function() return 1 end, GetStepView = function() return vista end,
    GetProgress = function() return 1, 5 end, StepNumber = function() return 2 end, StepTotal = function() return 5 end }, function()
    local d = P.TarjetaPaso()
    check(d, "sin tarjeta del paso")
    if d then
      check(not tostring(d.titulo):find("Into ", 1, true), "Hoy dice «" .. tostring(d.titulo) .. "»")
      check(not tostring(d.texto or ""):find("The road", 1, true), "Hoy muestra una meta en inglés")
    end
  end)
  -- La raíz: el motor traduce la forma del título («Into {zone:N}» -> «Hacia {zone:N}»).
  check(type(A.TituloDeGuia) == "function", "falta TituloDeGuia en el motor")
  if A.TituloDeGuia then
    check(A.TituloDeGuia("Into {zone:1440}", "esMX") == "Hacia {zone:1440}", "«Into X» no sale en español")
    check(A.TituloDeGuia("{area:12}: kill these as you meet them", "esMX") == "{area:12}: derrótalos en el camino", "«kill these» no sale en español")
    check(A.TituloDeGuia("Back to {npc:5}", "deDE") == "Zurück: {npc:5}", "«Back to» no sale en alemán")
    check(A.TituloDeGuia("Into {zone:1440}", "enUS") == nil, "en inglés no debe cambiar")
    check(A.TituloDeGuia("Kill twelve boars and bring their tusks back to the farm near the river", "esMX") == nil, "una nota larga no debe cambiar")
  end
end)

step("36: la tecla de «Cerrar mis misiones» existe y lleva al mismo plan", function()
  check(type(rawget(_G, "BINDING_NAME_ALFA_CERRAR_MISIONES")) == "string", "falta el nombre de la tecla")
  local llamado
  local R = rawget(_G, "AlfaRuta")
  con(R, { CerrarTodo = function(origen) llamado = origen end }, function() AlfaBienvenida.CerrarMisiones() end)
  check(llamado == "tecla", "la tecla no arma el plan de «Cerrar mis misiones»")
  local lista = Bv.Teclas.Lista()
  local hay = false
  for _, x in ipairs(lista) do if x.accion == "ALFA_CERRAR_MISIONES" then hay = true end end
  check(hay, "la tecla no sale en «Tus atajos de Alfa»")
end)

---------------------------------------------------------------------------
-- 35/53: la primera vez en cada página
---------------------------------------------------------------------------
step("53/35: la franja de la primera vez, su recorrido de 3 pasos y que no se repite", function()
  local Pv = Bv.PrimeraVez
  Pv.Olvidar()
  if Bv.Recorrido and Bv.Recorrido.Terminar then Bv.Recorrido.Terminar() end
  -- (RUN_TIMERS corre todos los relojes sin esperar: la franja se iría sola
  -- enseguida; aquí se revisa antes.)
  A.Fire("SHOW_OPTIONS", "bolsas")
  check(Pv.Visible(), "no salió la franja la primera vez en Bolsas: " .. tostring(Pv.PorQueNo("bolsas")))
  local f = O.frame or rawget(_G, "AlfaOptions")
  limpiarPantalla()
  SNAP("primera-vez", f)
  Pv.Siguiente() check(Pv.Paso() == 1, "«Enséñame» no empezó el recorrido")
  Pv.Siguiente() Pv.Siguiente()
  check(Pv.Paso() == 3, "el recorrido no tiene 3 pasos")
  SNAP("primera-vez-paso3", f)
  RUN_TIMERS(2)
  check(Pv.Visible() and Pv.Paso() == 3, "el recorrido se fue solo (solo la franja se va sola)")
  Pv.Siguiente()
  check(not Pv.Visible(), "«Listo» no cerró el recorrido")
  A.Fire("SHOW_OPTIONS", "mundo")
  check(Pv.Visible(), "no salió en Mundo")
  RUN_TIMERS(2)
  check(not Pv.Visible(), "la franja no se fue sola")
  A.Fire("SHOW_OPTIONS", "bolsas") RUN_TIMERS(1)
  check(not Pv.Visible(), "la franja salió otra vez en Bolsas")
  A.Fire("SHOW_OPTIONS", "inicio")
  check(not Pv.Visible(), "Hoy no lleva franja (tiene su recorrido)")
  A.Set("bienvenida.primeraVez", false)
  Pv.Olvidar()
  A.Fire("SHOW_OPTIONS", "pesca")
  check(not Pv.Visible(), "apagada, la franja sigue saliendo")
  A.Set("bienvenida.primeraVez", nil)
  if f then f:Hide() end
end)

---------------------------------------------------------------------------
-- 39: Deshacer
---------------------------------------------------------------------------
step("39: «Deshacer» devuelve el último cambio de un ajuste", function()
  A.Fire("SHOW_OPTIONS", "bienvenida") RUN_TIMERS(1)
  O.OlvidarDeshacer()
  local antes = A.Get("nucleo.letraGrande") and true or false
  -- Lo que Alfa cambia sola no se deshace: solo lo que pide el jugador.
  con(N, { PidioJugador = function() return false end }, function() A.Set("bienvenida.anuncios", false) end)
  check(not O.PuedeDeshacer(), "un cambio que no pidió el jugador quedó para deshacer")
  A.Set("bienvenida.anuncios", nil)
  O.OlvidarDeshacer()
  local pj = N.PidioJugador
  N.PidioJugador = function() return true end
  A.Set("nucleo.letraGrande", not antes)
  RUN_TIMERS(1)
  check(O.PuedeDeshacer(), "no hay nada que deshacer tras un cambio")
  local f = O.frame or rawget(_G, "AlfaOptions")
  local hay = false
  for _, b in ipairs(f.footerButtons.left) do if b:IsShown() and textosDe(b):find("Deshacer", 1, true) then hay = true end end
  check(hay, "el pie no muestra «Deshacer»")
  check(O.Deshacer() == 1, "Deshacer no devolvió un ajuste")
  check((A.Get("nucleo.letraGrande") and true or false) == antes, "Deshacer no lo dejó como estaba")
  check(not O.PuedeDeshacer(), "Deshacer se quedó con algo")
  -- Restablecer página es un solo cambio (se deshace de una vez).
  A.Set("bienvenida.aullido", false)
  A.Set("nucleo.temporada", false)
  O.OlvidarDeshacer()
  O.ResetPage("bienvenida")
  check(O.PuedeDeshacer(), "«Restablecer página» no se puede deshacer")
  O.Deshacer()
  check(A.Get("bienvenida.aullido") == false, "deshacer «Restablecer página» no devolvió lo de antes")
  A.Set("bienvenida.aullido", nil) A.Set("nucleo.temporada", nil)
  N.PidioJugador = pj
  if f then f:Hide() end
end)

---------------------------------------------------------------------------
-- 40: daltonismo en los mapas
---------------------------------------------------------------------------
step("40: los colores de la ruta cambian con el modo para daltonismo y no se confunden", function()
  local T = A.Theme
  local function c(n) local r, g, b = T.Color(n) return string.format("%.2f,%.2f,%.2f", r, g, b) end
  A.Set("nucleo.daltonico", false) RUN_TIMERS(1)
  check(c("routeFlight") == c("success") and c("routeBoat") == c("npc"), "de fábrica la ruta no tiene sus colores de siempre")
  A.Set("nucleo.daltonico", true) RUN_TIMERS(1)
  local vistos2 = {}
  for _, n in ipairs({ "routeWalk", "routeFlight", "routeBoat", "routeZeppelin", "routeTram" }) do
    check(not vistos2[c(n)], "dos tramos con el mismo color en daltonismo: " .. n)
    vistos2[c(n)] = true
  end
  check(c("routeBoat") ~= c("npc"), "el barco no cambió con el daltonismo")
  A.Set("nucleo.daltonico", nil) RUN_TIMERS(1)
end)

---------------------------------------------------------------------------
-- 54: el «?» de una página
---------------------------------------------------------------------------
step("54: el «?» de Bolsas abre a Lya ya en la respuesta de esa página", function()
  local Gi = Ly and Ly.Guia
  if not (Gi and Gi.Abrir) then return end
  local Ce = Ly.Cerebro
  local dicho
  local UI = Ly.UI
  -- Lo que Lya dice en su ventana (Guia.lua: decir) pasa por su globo de la ventana: se lee de la ventana.
  Gi.Abrir(nil, "bolsas") RUN_TIMERS(1)
  local v = rawget(_G, "AlfaLyaGuia") or rawget(_G, "AlfaLyaAyuda")
  local t = v and textosDe(v) or ""
  check(not t:find("Abajo tienes lo que más me preguntan", 1, true), "Lya sigue diciendo el saludo en vez de contestar")
  if v and v.Hide then v:Hide() end
end)

---------------------------------------------------------------------------
-- 55: Modo aprendiz
---------------------------------------------------------------------------
step("55: con Modo aprendiz, Lya explica cada aviso la primera vez (una sola)", function()
  local Ap = Bv.Aprendiz
  Ap.Olvidar()
  local dichos = {}
  local Lya = rawget(_G, "AlfaLya")
  con(Lya, { Decir = function(t, o) dichos[#dichos + 1] = { t = t, o = o } return true end }, function()
    A.Set("bienvenida.aprendiz", true)
    local n0 = #dichos
    Ap.Explicar({ titulo = "Tus bolsas están casi llenas", texto = "Te quedan 3", modulo = "bolsas", alfaFirma = "bolsas" })
    check(#dichos == n0 + 1, "Lya no explicó el aviso la primera vez")
    local d = dichos[#dichos]
    check(d and d.t:find("Bolsas", 1, true) and d.o and d.o.accion, "la explicación no dice de dónde viene ni lleva a su página")
    Ap.Explicar({ titulo = "Tus bolsas están casi llenas", texto = "Te quedan 2", modulo = "bolsas", alfaFirma = "bolsas" })
    check(#dichos == n0 + 1, "Lya explicó dos veces el mismo aviso")
    A.Set("bienvenida.aprendiz", false)
    Ap.Olvidar()
    Ap.Explicar({ titulo = "Otro aviso", alfaFirma = "pesca" })
    check(#dichos == n0 + 1, "apagado, Lya sigue explicando")
  end)
  A.Set("bienvenida.aprendiz", nil)
end)

---------------------------------------------------------------------------
-- 77: Planes
---------------------------------------------------------------------------
step("77: Planes se reordena (las pestañas de la guía) y se ve en el mapa", function()
  local E = A.Engine
  local movido
  con(E, { MoveTab = function(a, b) movido = { a, b } end }, function()
    check(Ru.MoverPlan(3, 1), "MoverPlan no movió")
  end)
  check(movido and movido[1] == 3 and movido[2] == 1, "no pidió mover la pestaña 3 a la 1")
  local visto
  local R = rawget(_G, "AlfaRuta")
  con(R, { VerEnMapa = function() visto = true end }, function() Ru.VerPlanEnMapa({ tipo = "guia", activa = true }) end)
  check(visto, "«Ver en el mapa» no abrió el mapa")
  A.Fire("SHOW_OPTIONS", "planes") RUN_TIMERS(1)
  local f = O.frame or rawget(_G, "AlfaOptions")
  limpiarPantalla()
  SNAP("planes", f)
  if f then f:Hide() end
end)

---------------------------------------------------------------------------
-- 42: Hoy entero, en español (para la galería)
---------------------------------------------------------------------------
step("42: Hoy en la galería", function()
  local f = abrirHoy()
  limpiarPantalla()
  SNAP("hoy", f)
  if f then f:Hide() end
end)

print(string.format("PRUEBA: 1.3.9 interfaz, %d pasos, %d errores", pasos, #ERRORS))
