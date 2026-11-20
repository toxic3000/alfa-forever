-- Prueba de la 1.2.9, segunda ola: optimización y lo que unía a los frentes
-- (tools/prueba.py la corre con las demás prueba_*.lua):
--   * un solo reloj (#23): los temporizadores que se repetían en los módulos
--     son tareas de N.Cada / N.Ticker; ninguno queda en C_Timer.NewTicker; su
--     trabajo sigue pasando (RUN_TIMERS corre el reloj como los del juego);
--     los que solo corren con algo abierto se quitan al cerrarlo;
--   * memoria (#22): en español, las tablas en inglés quedan vacías;
--   * Alfa sencillo: la barra del motor pregunta AlfaNucleo.PaginaVisible;
--   * la ficha de un objeto de la Enciclopedia: «A mi lista de compras»;
--   * la tarjeta de una mazmorra: «Revisar» (Listo para la mazmorra);
--   * las insignias («Hecho», «Pocos») se vuelven a medir con otra letra;
--   * los avisos de detalle (festejos, consejos) no salen con Alfa sencillo.
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
local function check(cond, msg) if not cond then NOTE("1.2.9 optim", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

-- Los temporizadores que se repiten, desde antes de entrar (después de cargar
-- los módulos: lo que se cree de aquí en adelante).
local tickers = {}
local nt = C_Timer.NewTicker
C_Timer.NewTicker = function(s, fn, ...)
  local t = nt(s, fn, ...)
  local src = "?"
  for n = 2, 9 do
    local i = debug.getinfo(n, "S")
    if not i then break end
    local s2 = tostring(i.source)
    if s2:find("Alfa_", 1, true) then src = s2 break end
  end
  tickers[#tickers + 1] = { t = t, src = src }
  return t
end

Alfa.Hidden = function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(3)

local N = AlfaNucleo
local A, K = N.A, N.Kit
local lista = N.Reloj and N.Reloj.lista or {}

local function boton(texto)
  for _, f in ipairs(ALL_FRAMES()) do
    local tx = rawget(f, "Texto")
    if type(tx) == "table" and tx.GetText and tx:GetText() == texto and f:IsVisible() then return f end
  end
end

---------------------------------------------------------------------------
-- #23 Un solo reloj
---------------------------------------------------------------------------
-- (1.3.1: «lya.finMazmorra» solo corre dentro de una mazmorra y «lya.latido»
-- solo con Lya a la vista: los prueba prueba_131_nucleo.lua.)
-- (1.3.2: «curacion.alcance» solo corre con marcos o en grupo: lo prueba
-- prueba_132_personaje.lua.)
local FIJAS = {
  "lya.minutos", "lya.momentos",
  -- (1.3.2: las de La Jauría de 10 s a 10 min son una sola, «manada.reloj»; las
  -- suyas las prueba prueba_132_manada.lua.)
  "manada.reloj", "manada.pulso",
  "inicio.camino", "inicio.sesion",
}

step("Reloj: las tareas de los módulos están tras entrar, sin temporizadores sueltos", function()
  check(type(N.Ticker) == "function", "falta N.Ticker")
  for _, clave in ipairs(FIJAS) do check(N.HayTarea(clave), "falta la tarea del reloj " .. clave) end
  -- Lo que se repite en los módulos ya no usa C_Timer.NewTicker (el motor sí, y
  -- las tandas de Bolsas y del buzón, que solo corren mientras haces algo).
  local sueltos = {}
  for _, x in ipairs(tickers) do
    if not x.t.cancelled and x.src ~= "?" and not x.src:find("Lotes.lua", 1, true) and not x.src:find("Buzon.lua", 1, true) then
      sueltos[#sueltos + 1] = x.src
    end
  end
  check(#sueltos == 0, "quedan temporizadores sueltos en: " .. table.concat(sueltos, ", "))
  local n = 0
  for _ in pairs(lista) do n = n + 1 end
  check(n >= #FIJAS, "el reloj tiene menos tareas de las esperadas: " .. n)
end)

step("Reloj: el trabajo de cada tarea sigue pasando", function()
  local veces = {}
  for _, clave in ipairs(FIJAS) do veces[clave] = lista[clave] and lista[clave].veces or 0 end
  -- Lya cuenta tus minutos de caza de hoy.
  local Ly = NS_OF("Alfa_Lya")
  local hoy = Ly.Dia.Hoy()
  local min0 = tonumber(hoy.minutos) or 0
  T(3)
  for _, clave in ipairs(FIJAS) do
    local t = lista[clave]
    check(t and t.veces > veces[clave], "la tarea " .. clave .. " no corrió")
    check(t and t.fallos == 0, "la tarea " .. clave .. " falla")
  end
  check((tonumber(Ly.Dia.Hoy().minutos) or 0) >= min0 + 3, "Lya no contó los minutos de caza")
end)

step("Reloj: N.Ticker se cancela como uno del juego, sin quitar a otro con su clave", function()
  local a, b = 0, 0
  local h1 = N.Ticker("prueba.optim", 5, function() a = a + 1 end)
  check(N.HayTarea("prueba.optim") and not h1:IsCancelled(), "N.Ticker no anotó la tarea")
  T(1)
  check(a == 1, "la tarea de N.Ticker no corrió")
  local h2 = N.Ticker("prueba.optim", 5, function() b = b + 1 end)
  check(h1:IsCancelled() and not h2:IsCancelled(), "la clave repetida no reemplazó al primero")
  h1:Cancel()
  check(N.HayTarea("prueba.optim"), "cancelar el viejo quitó al nuevo")
  h2:Cancel()
  check(not N.HayTarea("prueba.optim") and h2:IsCancelled(), "cancelar no quitó la tarea")
  T(1)
  check(a == 1 and b == 0, "una tarea cancelada siguió corriendo")
end)

step("Reloj: lo que corre con algo abierto se quita al cerrarlo", function()
  -- La subasta: el panel de vender se revisa cada medio segundo solo con ella abierta.
  FIRE_EVENT("AUCTION_HOUSE_SHOW")
  T(2)
  check(N.HayTarea("comercio.vender"), "con la subasta abierta no se revisa el panel de vender")
  FIRE_EVENT("AUCTION_HOUSE_CLOSED")
  check(not N.HayTarea("comercio.vender"), "al cerrar la subasta sigue la tarea del panel")
  -- El minimapa de Recolección: apagado, no vigila.
  check(N.HayTarea("recoleccion.minimapa"), "el vigía del minimapa de Recolección no está")
  A.Set("recoleccion.minimapa", false)
  T(1)
  check(not N.HayTarea("recoleccion.minimapa"), "con el minimapa apagado sigue el vigía")
  A.Set("recoleccion.minimapa", true)
  T(1)
  check(N.HayTarea("recoleccion.minimapa"), "al prender el minimapa no volvió el vigía")
end)

step("Reloj: duerme si lo próximo está lejos", function()
  -- (las tareas de 0.15 s lo tienen despierto casi siempre; aquí se ve con una sola)
  local aparte = {}
  for k, t in pairs(lista) do aparte[k] = t end
  for k in pairs(aparte) do lista[k] = nil end
  BANCO_RELOJ_REAL = true
  N.Cada("prueba.lejos", 30, function() end)
  check(not N.Reloj.marco:IsShown(), "con 30 s por delante el reloj no duerme")
  N.Quitar("prueba.lejos")
  check(not N.Reloj.marco:IsShown(), "sin tareas el reloj sigue despierto")
  BANCO_RELOJ_REAL = nil
  for k, t in pairs(aparte) do lista[k] = t end
  N.Cada("prueba.replan", 1, function() end)
  N.Quitar("prueba.replan")
end)

---------------------------------------------------------------------------
-- #22 Memoria: en español, las tablas en inglés quedan vacías
---------------------------------------------------------------------------
step("Memoria: en español no se guarda el inglés", function()
  check(N.espanol, "el banco no está en español")
  for _, m in ipairs({ "Alfa_Lya", "Alfa_Comercio", "Alfa_Pesca", "Alfa_Mazmorras", "Alfa_Rutas" }) do
    local ns = NS_OF(m)
    check(type(ns.EN) ~= "table" or next(ns.EN) == nil, m .. " guarda su tabla en inglés")
  end
  -- Y los textos siguen saliendo en español.
  local L = N.Textos({ ["Hola [saludo]"] = "Hi" })
  check(L["Hola [saludo]"] == "Hola", "N.Textos ya no da el español: " .. tostring(L["Hola [saludo]"]))
end)

---------------------------------------------------------------------------
-- Alfa sencillo en la barra del motor
---------------------------------------------------------------------------
step("Sencillo: la barra pregunta AlfaNucleo.PaginaVisible", function()
  local O = A.UI.Options
  local modo = A.Get("bienvenida.modo")
  A.Set("bienvenida.modo", "completo")
  N.Abrir("inicio")
  T(1)
  local function claves(sec)
    local out = {}
    for _, p in ipairs(O.PagesOf(sec)) do out[p.key] = true end
    return out
  end
  check(claves("personaje").builds, "en completo no sale Talentos")
  A.Set("bienvenida.modo", "sencillo")
  T(1)
  local p = claves("personaje")
  check(p.bolsas and p.lya and not p.builds and not p.combate, "en sencillo la barra del motor no esconde lo que no es esencial")
  check(not next(claves("manada")), "en sencillo Manada sigue con páginas")
  -- La que está abierta siempre sale (abrir una escondida no la pierde).
  N.Abrir("pesca")
  T(1)
  local of = claves(O.SectionOf("pesca"))
  check(of.pesca, "la página abierta no sale en su sección")
  check(N.EnvolverBarra and N.EnvolverBarra() == true, "N.EnvolverBarra ya no responde")
  A.Set("bienvenida.modo", modo)
  N.CerrarVentana()
  T(1)
end)

---------------------------------------------------------------------------
-- La Enciclopedia: «A mi lista de compras»
---------------------------------------------------------------------------
step("Enciclopedia: la ficha de un objeto lo suma a tu lista de compras", function()
  local E = NS_OF("Alfa_Enciclopedia")
  local Li = AlfaComercio and AlfaComercio.Lista
  check(type(Li) == "table", "falta AlfaComercio.Lista")
  if type(Li) ~= "table" then return end
  Li.Vaciar()
  local f = E.F.Objeto(2589)
  check(f and f.acciones and type(f.acciones.compra) == "function", "la ficha del objeto no trae «A mi lista de compras»")
  -- En la ventana: el botón, y su clic.
  AlfaEnciclopedia.Abrir("objeto", 2589)
  T(3)
  local b = boton("A mi lista de compras")
  check(b, "la ficha no muestra el botón «A mi lista de compras»")
  if b then b:Click("LeftButton") end
  T(1)
  local hay = false
  for _, m in ipairs(Li.Metas()) do if m.id == 2589 then hay = true end end
  check(hay, "el botón no sumó el objeto a la lista de compras")
  -- Sin Comercio, no sale.
  local C = AlfaComercio
  AlfaComercio = nil
  local f2 = E.F.Objeto(2589)
  AlfaComercio = C
  check(f2 and f2.acciones.compra == nil, "sin Comercio la ficha ofrece la lista de compras")
  AlfaEnciclopedia.Cerrar()
  Li.Vaciar()
end)

---------------------------------------------------------------------------
-- Mazmorras: «Revisar»
---------------------------------------------------------------------------
step("Mazmorras: la tarjeta de una mazmorra revisa lo que llevas", function()
  local I = AlfaInicio
  check(type(I) == "table" and type(I.RevisarMazmorra) == "function", "falta AlfaInicio.RevisarMazmorra")
  local real = I.RevisarMazmorra
  local pedidas = {}
  I.RevisarMazmorra = function(nombre) pedidas[#pedidas + 1] = nombre return {} end
  AlfaMazmorras.Abrir("ragefire-chasm")
  T(3)
  local b = boton("Revisar")
  check(b, "la tarjeta de la mazmorra no muestra «Revisar»")
  if b then b:Click("LeftButton") end
  I.RevisarMazmorra = real
  check(#pedidas == 1 and type(pedidas[1]) == "string" and pedidas[1] ~= "", "«Revisar» no pidió revisar la mazmorra")
  N.CerrarVentana()
  T(1)
end)

---------------------------------------------------------------------------
-- Las insignias con otra letra
---------------------------------------------------------------------------
step("Insignias: con otra letra se vuelven a medir y su texto no se corta", function()
  local c = K.Insignia(UIParent, "Hecho", "exito")
  c:Set("Hecho", "exito", "ic-exito")
  local w1 = c:GetWidth()
  local antes = BANCO_LETRA
  BANCO_LETRA = 0.9
  K.Repintar()
  local w2 = c:GetWidth()
  BANCO_LETRA = antes
  K.Repintar()
  check(w2 > w1, string.format("la insignia no se volvió a medir con la letra nueva (%s -> %s)", tostring(w1), tostring(w2)))
  local izq = (c.Texto:GetLeft() or 0) - (c:GetLeft() or 0)
  check(K.AnchoTexto(c.Texto) + izq <= c:GetWidth() + 0.5, "el texto de la insignia no cabe en ella")
  c:Hide()
end)

---------------------------------------------------------------------------
-- Avisos de detalle
---------------------------------------------------------------------------
step("Avisos de detalle: los festejos no salen con Alfa sencillo", function()
  local Mn = NS_OF("Alfa_Manada")
  local modo = A.Get("bienvenida.modo")
  local vistos = {}
  local real = K.Aviso
  local salen = {}
  K.Aviso = function(o) vistos[#vistos + 1] = o local r = real(o) salen[#salen + 1] = r return r end
  local Sa = Mn.Saludo
  local texto = Sa.Texto
  Sa.Texto = function() return "Andan conectados: Lobato." end
  Sa.Olvidar()
  A.Set("bienvenida.modo", "sencillo")
  Sa.Decir()
  Sa.Texto = texto
  K.Aviso = real
  A.Set("bienvenida.modo", modo)
  check(vistos[1] and vistos[1].detalle == true, "el saludo de la manada no es un aviso de detalle")
  check(salen[1] == false, "con Alfa sencillo salió el saludo de la manada")
  -- Los que importan no son de detalle.
  check(real({ titulo = "Prueba", texto = "Un aviso normal." }) ~= false, "un aviso normal no salió")
end)

C_Timer.NewTicker = nt
print(string.format("PRUEBA: 1.2.9 optimización y uniones, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
