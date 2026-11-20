-- Prueba de la 1.3.3, la entrada en silencio (Alfa_Nucleo/Entrada.lua; tools/prueba.py
-- la corre con las demás prueba_*.lua). En una sola corrida, tres entradas:
--   * la cuenta nueva: la intro y la configuración (lo que no puede esperar);
--   * la entrada normal: solo la intro y Lya llegando a su lugar; lo demás
--     (avisos del Kit, de Hoy, de Lya, líneas del chat, anuncios) queda en N.AlEntrar();
--   * un /reload: nada a la vista.
-- Y el ajuste bienvenida.alEntrar = "avisos" (como antes), las novedades que ya no se
-- abren solas (un punto en «Lo nuevo»), lo que pides tú (un comando, la ventana de
-- Alfa abierta) que sí sale, y los 60 s que dura.
SNAPSHOTS = {}
-- Las demás escenas entran sin silencio (Entrada.lua); esta lo pide.
BANCO_ENTRADA = true
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
local function check(cond, msg) if not cond then NOTE("1.3.3 entrada", msg) end end

local A, N, K = Alfa, AlfaNucleo, AlfaNucleo.Kit
local B = NS_OF("Alfa_Bienvenida")
local Ly = NS_OF("Alfa_Lya")
local In = NS_OF("Alfa_Inicio")

-- Lo que se ve: avisos del Kit (los que de verdad salen), los de Hoy, el globo
-- de Lya, el chat, los anuncios y la intro.
local vistos = {}
local function anota(tipo, txt) vistos[#vistos + 1] = { tipo = tipo, txt = tostring(txt or "") } end
local av = K.Aviso
K.Aviso = function(o)
  local r = av(o)
  if r ~= nil and r ~= false then anota("aviso", (o and o.titulo or "") .. " | " .. (o and o.texto or "")) end
  return r
end
if K.Anuncio then
  local an = K.Anuncio
  K.Anuncio = function(o) local r = an(o) if r then anota("anuncio", o and o.titulo) end return r end
end
if Ly.UI and Ly.UI.Hablar then
  local h = Ly.UI.Hablar
  Ly.UI.Hablar = function(c) anota("lya", c and c.texto) return h(c) end
end
if In.Aviso and In.Aviso.Mostrar then
  local m = In.Aviso.Mostrar
  In.Aviso.Mostrar = function(o)
    local r = m(o)
    local f = rawget(_G, "AlfaInicioAviso")
    if f and f:IsShown() then anota("hoy", o and o.titulo) end
    return r
  end
end
local add = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, m, ...) anota("chat", m) return add(self, m, ...) end
local intros = 0
if B.Intro then local f = B.Intro B.Intro = function(...) intros = intros + 1 return f(...) end end

local function lista(tipos)
  local out = {}
  for _, v in ipairs(vistos) do if not tipos or tipos[v.tipo] then out[#out + 1] = v.tipo .. ": " .. v.txt:sub(1, 80) end end
  return out
end
local function correr(n) for _ = 1, n do RUN_TIMERS(1) end end
-- Las ventanas del Kit que se abrieron solas (la configuración es la de la cuenta nueva).
local function cerrarVentanas()
  for _, v in ipairs(K.VENTANAS or {}) do if v:IsShown() then v:Hide() end end
  local O = A.UI and A.UI.Options
  if O and O.frame and O.frame:IsShown() then O.frame:Hide() end
end

---------------------------------------------------------------------------
step("El contrato: N.Entrando, N.GuardarAlEntrar, N.AlEntrar, N.OlvidarAlEntrar y ALFA_ALENTRAR", function()
  check(type(N.Entrando) == "function" and type(N.GuardarAlEntrar) == "function" and type(N.AlEntrar) == "function"
    and type(N.OlvidarAlEntrar) == "function", "falta el contrato de la entrada en silencio")
  check(N.Entrando(), "antes de entrar al juego no se está entrando")
  local avisos = 0
  A.On("ALFA_ALENTRAR", function() avisos = avisos + 1 end)
  N.GuardarAlEntrar({ id = "prueba.uno", titulo = "Uno" })
  N.GuardarAlEntrar({ id = "prueba.dos", titulo = "Dos" })
  N.GuardarAlEntrar({ id = "prueba.uno", titulo = "Uno otra vez" })
  local l = N.AlEntrar()
  check(#l == 2 and l[1].id == "prueba.dos" and l[2].titulo == "Uno otra vez", "un id repetido no reemplazó al anterior o el orden no es el de llegada")
  N.OlvidarAlEntrar("prueba.uno") N.OlvidarAlEntrar("prueba.dos")
  check(#N.AlEntrar() == 0, "N.OlvidarAlEntrar no borró")
  check(avisos >= 4, "ALFA_ALENTRAR no avisó cada cambio (" .. avisos .. ")")
end)

---------------------------------------------------------------------------
-- 1. La cuenta nueva
---------------------------------------------------------------------------
step("Cuenta nueva: la intro y la configuración; nada más a la vista", function()
  FIRE_EVENT("PLAYER_LOGIN")
  FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
  correr(3)
  check(intros >= 1, "la cuenta nueva no vio la intro")
  -- El banco no mueve la intro sola: el jugador la salta con un clic.
  local it = rawget(_G, "AlfaIntro")
  if it and it:IsShown() and it:GetScript("OnClick") then it:GetScript("OnClick")(it) end
  correr(27)
  check(AlfaBienvenida.Pendiente(), "la cuenta nueva no quedó con la configuración pendiente")
  local v = rawget(_G, "AlfaBienvenidaVentana")
  check(v and v:IsShown(), "la configuración no se abrió")
  check(#lista({ aviso = true, chat = true, anuncio = true }) == 0, "en la cuenta nueva salió: " .. table.concat(lista({ aviso = true, chat = true, anuncio = true }), " / "))
end)

-- Termina la configuración (como lo haría el jugador) y prepara un día anterior.
step("Cuenta nueva: termina la configuración", function()
  local v = rawget(_G, "AlfaBienvenidaVentana")
  local a = v and v.alfaAsistente
  check(a ~= nil, "no está el asistente") if not a then return end
  a:Ir(1)
  for _ = 1, #a.pasos + 1 do a:Siguiente() RUN_TIMERS(1) end
  check(not AlfaBienvenida.Pendiente(), "la configuración no quedó terminada")
  cerrarVentanas()
  local d = N.DatosPersonaje("lya")
  d.presentada = true
  d.dia = { fecha = "2026-11-18", misiones = 7, niveles = 1, oro = 0, raros = 0, muertes = 0, minutos = 50 }
end)

---------------------------------------------------------------------------
-- 2. La entrada normal (otra sesión: lo de la entrada vuelve a empezar)
---------------------------------------------------------------------------
step("Entrada normal: solo la intro y Lya llegando; lo demás queda en N.AlEntrar()", function()
  N.OlvidarAlEntrar()
  if N.ReiniciarEntrada then N.ReiniciarEntrada() end
  vistos, intros = {}, 0
  -- Un aviso y una línea del chat de un módulo cualquiera, al entrar.
  FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
  K.Aviso({ id = "prueba.aviso", titulo = "Aviso de prueba al entrar", texto = "No debe verse." })
  N.Imprimir("Línea de prueba al entrar")
  correr(40)
  check(N.Entrando(), "a los 40 s de entrar ya no se está entrando")
  local fuera = lista({ aviso = true, chat = true, anuncio = true, hoy = true, lya = true })
  check(#fuera == 0, "al entrar salió: " .. table.concat(fuera, " / "))
  local hay, chat = false, false
  for _, x in ipairs(N.AlEntrar()) do
    if x.id == "prueba.aviso" then hay = true end
    if x.texto == "Línea de prueba al entrar" then chat = true end
  end
  check(hay, "el aviso que no salió no quedó en N.AlEntrar()")
  check(chat, "la línea del chat que no salió no quedó en N.AlEntrar()")
end)

step("Lo que no puede esperar y lo que pides tú sí sale", function()
  local a = K.Aviso({ titulo = "Importante de prueba", importante = "siempre", lya = false })
  check(type(a) == "table", "un aviso importante = \"siempre\" no salió")
  if type(a) == "table" and a.Cerrar then a:Cerrar() end
  a = K.Aviso({ titulo = "Con alEntrar", alEntrar = true, lya = false })
  check(type(a) == "table", "un aviso con alEntrar = true no salió")
  if type(a) == "table" and a.Cerrar then a:Cerrar() end
  -- La ventana de Alfa abierta: estás haciendo algo a propósito.
  A.Fire("SHOW_OPTIONS", "inicio") RUN_TIMERS(1)
  check(not N.Entrando(), "con la ventana de Alfa abierta sigue callando")
  a = K.Aviso({ titulo = "Con la ventana abierta", lya = false })
  check(type(a) == "table", "con la ventana de Alfa abierta un aviso no salió")
  if type(a) == "table" and a.Cerrar then a:Cerrar() end
  cerrarVentanas()
  -- Un comando de /alfa: lo que escribe sale.
  local antes = #vistos
  A.RunCommand("rendimiento")
  local escribio = false
  for i = antes + 1, #vistos do if vistos[i].tipo == "chat" then escribio = true end end
  check(escribio, "un comando de /alfa no escribió en el chat mientras se entraba")
  check(N.Entrando(), "después del comando ya no se está entrando")
end)

step("La entrada dura 60 s; después todo sale como siempre", function()
  correr(25)
  check(not N.Entrando(), "a los 65 s de entrar se sigue callando")
  local a = K.Aviso({ titulo = "Después de entrar", lya = false })
  check(type(a) == "table", "pasada la entrada un aviso no salió")
  if type(a) == "table" and a.Cerrar then a:Cerrar() end
end)

step("Los avisos con acción que se van sin tocarlos: ALFA_AVISO_PERDIDO (para Lya)", function()
  check(not N.Entrando(), "la entrada sigue: no se puede probar")
  local perdidos = {}
  A.On("ALFA_AVISO_PERDIDO", function(o) perdidos[#perdidos + 1] = o end)
  RUN_TIMERS(2) -- que venzan los de antes
  local function con(titulo) return { titulo = titulo, lya = false, accion = { texto = "Ir", alClic = function() end } } end
  -- Cuatro con acción (caben 3): el más viejo cede su lugar.
  local a1 = K.Aviso(con("Perdido uno"))
  check(type(a1) == "table" and a1.alfaO and a1.alfaO.titulo == "Perdido uno", "el aviso no guarda su o (a.alfaO)")
  K.Aviso(con("Perdido dos")) K.Aviso(con("Perdido tres"))
  local n0 = #perdidos
  K.Aviso(con("Perdido cuatro"))
  check(#perdidos == n0 + 1 and perdidos[#perdidos].titulo == "Perdido uno", "el aviso que cedió su lugar no avisó ALFA_AVISO_PERDIDO")
  -- Uno que tocas no se pierde; los demás ceden su lugar o vencen sin tocarlos.
  local antes = #perdidos
  local tocado = K.Aviso(con("Tocado"))
  if tocado and tocado.Boton and tocado.Boton.alClic then tocado.Boton.alClic() end
  local sin = K.Aviso({ titulo = "Sin acción", lya = false })
  local seguro = K.Aviso({ titulo = "Seguro", lya = false, accion = { texto = "Abrir", seguro = { type = "macro" }, alClic = function() end } })
  RUN_TIMERS(2)
  local vistos = {}
  for i = antes + 1, #perdidos do vistos[perdidos[i].titulo] = true end
  check(vistos["Perdido dos"] and vistos["Perdido tres"] and vistos["Perdido cuatro"], "un aviso con acción que cedió su lugar o venció no avisó ALFA_AVISO_PERDIDO")
  check(not vistos["Tocado"], "un aviso que tocaste avisó como perdido")
  check(not vistos["Sin acción"] and not vistos["Seguro"], "un aviso sin acción o con acción segura avisó como perdido")
end)

---------------------------------------------------------------------------
-- 3. Un /reload: nada
---------------------------------------------------------------------------
step("/reload: nada a la vista", function()
  if N.ReiniciarEntrada then N.ReiniciarEntrada() end
  vistos, intros = {}, 0
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
  correr(30)
  check(intros == 0, "en un /reload salió la intro")
  local fuera = lista({ aviso = true, chat = true, anuncio = true, hoy = true, lya = true })
  check(#fuera == 0, "en un /reload salió: " .. table.concat(fuera, " / "))
end)

---------------------------------------------------------------------------
-- 4. El ajuste y las novedades
---------------------------------------------------------------------------
step("bienvenida.alEntrar: «silencio» de fábrica; «avisos» como antes", function()
  check(A.Get("bienvenida.alEntrar") == "silencio", "el valor de fábrica no es «silencio»: " .. tostring(A.Get("bienvenida.alEntrar")))
  if N.ReiniciarEntrada then N.ReiniciarEntrada() end
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
  check(N.Entrando(), "recién entrando no se calla")
  A.Set("bienvenida.alEntrar", "avisos")
  check(not N.Entrando(), "con «avisos» se sigue callando")
  local a = K.Aviso({ titulo = "Con avisos", lya = false })
  check(type(a) == "table", "con «avisos» el aviso no salió")
  if type(a) == "table" and a.Cerrar then a:Cerrar() end
  A.Set("bienvenida.alEntrar", nil)
  local O = A.UI.Options
  local claves = {}
  for _, t in ipairs((O.Estructura("bienvenida") or { tabs = {} }).tabs) do for k in pairs(t.keys) do claves[k] = true end end
  check(claves["bienvenida.alEntrar"] and claves["bienvenida.introSiempre"], "el ajuste no está en Estilo y sonido junto a «El lobo te recibe al entrar»")
end)

step("Novedades: al actualizar no se abren solas; esperan con un punto en «Lo nuevo»", function()
  if N.ReiniciarEntrada then N.ReiniciarEntrada() end
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
  N.OlvidarAlEntrar()
  -- Una versión vieja vista: hay notas por ver.
  B.MarcarNotasVistas("0.0.1")
  check(B.NotasPorVer() ~= nil, "no hay notas por ver para probar")
  local abiertas = false
  local abrir = B.AbrirNotas
  B.AbrirNotas = function(...) abiertas = true return abrir(...) end
  B.RevisarNotas(0)
  correr(3)
  B.AbrirNotas = abrir
  check(not abiertas, "las novedades se abrieron solas al entrar")
  local guardada
  for _, x in ipairs(N.AlEntrar()) do if x.id == "bienvenida.novedades" then guardada = x end end
  check(guardada and guardada.accion and guardada.accion.alClic, "las novedades no quedaron en N.AlEntrar() con su «Ver»")
  check(B.NotasPorVer() ~= nil, "sin notas por ver no habría punto en «Lo nuevo»")
  -- Verlas quita el punto y el recuerdo.
  if guardada then guardada.accion.alClic() end
  check(B.NotasPorVer() == nil, "ver las novedades no las dejó vistas")
  local sigue = false
  for _, x in ipairs(N.AlEntrar()) do if x.id == "bienvenida.novedades" then sigue = true end end
  check(not sigue, "vistas las novedades, siguen en N.AlEntrar()")
  cerrarVentanas()
end)

---------------------------------------------------------------------------
-- 5. Sencillo con Talentos
---------------------------------------------------------------------------
step("Sencillo: Talentos a la vista", function()
  local modo = A.Get("bienvenida.modo")
  A.Set("bienvenida.modo", "sencillo")
  check(N.PaginaVisible("builds"), "con Sencillo Talentos no sale")
  A.Set("bienvenida.modo", modo)
end)

print("PRUEBA: 1.3.3 entrada en silencio, " .. pasos .. " pasos, " .. #ERRORS .. " errores")
