-- Prueba de la 1.3.0, la interfaz (los puntos 36 a 40):
--   36. estilos nuevos: La Jauría nocturno y Fogata (Kit y tema, contraste,
--       muestras del selector, acento de fábrica, el chat de Comodidades);
--   37. la pantalla limpia: solo transparencia, lo protegido nunca en combate,
--       devuelve todo como estaba;
--   38. letra más grande y colores para daltonismo (tokens del Kit, perjuicios);
--   39. tus atajos: la lista sale de todos los Bindings.xml, se cambian con
--       SetBinding y SaveBindings fuera de combate;
--   40. «¿Qué es esto?»: con Alt abajo o el modo ayuda, cada control dice qué hace.
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
local function check(cond, msg) if not cond then NOTE("1.3.0 interfaz", msg) end end
local function T(n) RUN_TIMERS(n or 2) end
local function cerca(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.01 end

-- Lya aprende lo nuevo al entrar: se anota lo que se le enseña.
local ensenado = {}
local function espiarLya()
  local Lya = rawget(_G, "AlfaLya")
  if type(Lya) == "table" and type(Lya.Ensenar) == "function" and not Lya.alfaEspiada then
    local orig = Lya.Ensenar
    Lya.Ensenar = function(p) if type(p) == "table" then ensenado[p.id] = p end return orig(p) end
    Lya.alfaEspiada = true
  end
end
espiarLya()

Alfa.Hidden = function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(3)

local A, N, K = Alfa, AlfaNucleo, AlfaNucleo.Kit
local Th = A.Theme
local M = NS_OF("Alfa_Bienvenida")

---------------------------------------------------------------------------
-- 36. Estilos nuevos
---------------------------------------------------------------------------
local function ids()
  local t = {}
  for _, e in ipairs(K.ESTILOS) do t[e.id] = e end
  return t
end

step("Estilos: hay cinco, con nombre y texto en inglés", function()
  local e = ids()
  check(e.alfa and e.clasico and e.cristal and e.nocturno and e.fogata, "faltan estilos en K.ESTILOS")
  check(K.NombreEstilo("nocturno") == "La Jauría nocturno", "el nombre de nocturno: " .. tostring(K.NombreEstilo("nocturno")))
  local n = 0
  for _, c in ipairs(Th.SkinChoices()) do n = n + 1 end
  check(n == 5, "Ajustes > Apariencia no ofrece los cinco estilos: " .. n)
end)

local function contraste(tokA, tokB)
  local a = { K.Color(tokA) }
  local b = { K.Color(tokB) }
  return Th.Contrast(a, b)
end

local function revisarEstilo(id, fondoHex, acentoId)
  check(K.SetEstilo(id), "K.SetEstilo(" .. id .. ") falló")
  T(1)
  check(K.Estilo() == id and Th.EstiloKey() == id, id .. ": K.Estilo da " .. tostring(K.Estilo()))
  check(Th.SkinKey() == "alfa", id .. ": no usa las formas de la casa (SkinKey " .. tostring(Th.SkinKey()) .. ")")
  local r, g, b = K.Color("fondo")
  local fr = tonumber(fondoHex:sub(1, 2), 16) / 255
  check(math.abs(r - fr) < 0.05, id .. ": el fondo no es el del estilo (" .. r .. ")")
  check(K.AcentoActual() == acentoId, id .. ": el acento de fábrica no es " .. acentoId .. " sino " .. tostring(K.AcentoActual()))
  check(Th.Legibility(Th.Palette()) >= 0.999, id .. ": algún texto no se lee (legibilidad " .. Th.Legibility(Th.Palette()) .. ")")
  check(contraste("texto", "panel") >= 7, id .. ": el texto sobre el panel tiene poco contraste")
  check(contraste("textoTenue", "elevado") >= 4.5, id .. ": el texto tenue sobre lo elevado tiene poco contraste")
  check(contraste("sobreAcento", "acento") >= 4.5, id .. ": el texto sobre el acento tiene poco contraste")
  check(contraste("acento", "fondo") >= 4.5, id .. ": el acento sobre el fondo tiene poco contraste")
  for _, tok in ipairs({ "exito", "aviso", "peligro", "oro", "mision" }) do
    check(contraste(tok, "panel") >= 4.5, id .. ": " .. tok .. " sobre el panel tiene poco contraste")
  end
  -- Lo que viste Comodidades (chat, minimapa, barras) con "Igual que Alfa".
  local Co = NS_OF("Alfa_Comodidades")
  if Co and Co.ColorDe then
    local cr = Co.ColorDe(Co.EstiloDe and Co.EstiloDe("nada") or id, "fondo")
    check(cerca(cr, r), id .. ": el chat no se viste con el estilo")
  end
  -- Otro estilo pide sus colores sin cambiar el de ahora.
  local or_ = K.ColorEstilo(id == "nocturno" and "fogata" or "nocturno", "fondo")
  check(type(or_) == "number" and not cerca(or_, r), id .. ": K.ColorEstilo no da los colores del otro estilo")
end

step("Estilo La Jauría nocturno", function() revisarEstilo("nocturno", "0b0f1a", "plata") end)
step("Estilo Fogata", function() revisarEstilo("fogata", "15110e", "brasa") end)

step("Acento: cada estilo recuerda el suyo, y el verde se guarda en nocturno", function()
  K.SetEstilo("nocturno")
  K.SetAcento("jauria")
  T(1)
  local c = A.Get("ui.accent")
  check(type(c) == "table" and cerca(c[2], 0.878), "en nocturno el verde de La Jauría no quedó como acento propio")
  check(K.AcentoActual() == "jauria", "el acento de ahora no es el verde")
  K.SetEstilo("alfa")
  T(1)
  check(type(A.Get("ui.accent")) ~= "table" and K.AcentoActual() == "jauria", "en Alfa no volvió su verde de fábrica")
  K.SetEstilo("nocturno")
  T(1)
  check(K.AcentoActual() == "jauria", "al volver a nocturno no volvió el acento que elegiste ahí")
  K.SetAcento("plata")
  T(1)
  check(type(A.Get("ui.accent")) ~= "table" and K.AcentoActual() == "plata", "la plata de fábrica se guardó como propia")
end)

step("Selector de estilos: cinco muestras que se pintan y miden", function()
  local f = CreateFrame("Frame", nil, UIParent)
  local sel = K.SelectorEstilo(f, { min = 220 })
  check(#sel.opciones == 5, "el selector no trae cinco estilos: " .. #sel.opciones)
  local h = sel:Acomodar(700)
  check(type(h) == "number" and h > 0, "el selector no midió")
  -- Un clic en Fogata la aplica.
  for _, o in ipairs(sel.opciones) do if o.alfaId == "fogata" then o:Click() end end
  T(1)
  check(K.Estilo() == "fogata", "clic en la muestra de Fogata no la aplicó")
  K.SetEstilo("cristal")
  T(1)
  check(K.Estilo() == "cristal" and K.Cristal(), "Cristal dejó de funcionar")
  K.SetEstilo("alfa")
  T(1)
  check(K.Estilo() == "alfa", "no volvió a Alfa")
end)

---------------------------------------------------------------------------
-- 38. Letra más grande y colores para daltonismo
---------------------------------------------------------------------------
step("Letra más grande: todo el Kit crece y vuelve", function()
  local antes = K.Tamano("cuerpo")
  local fs = K.Texto(UIParent, "cuerpo")
  A.Set("nucleo.letraGrande", true)
  T(1)
  check(K.LetraGrande(), "K.LetraGrande no lo ve")
  local ahora = K.Tamano("cuerpo")
  check(ahora == 15 and antes == 13, "el tamaño de cuerpo no subió un escalón: " .. antes .. " -> " .. ahora)
  -- Cada rol queda en la escala del Kit.
  local escala = {}
  for _, spec in pairs(K.TIPO) do escala[spec[2]] = true end
  for rol in pairs(K.TIPO) do check(escala[K.Tamano(rol)], "con letra grande, " .. rol .. " sale de la escala: " .. K.Tamano(rol)) end
  local _, tam = fs:GetFont()
  check(tam == nil or cerca(tam, ahora), "un texto ya hecho no se repintó con la letra grande: " .. tostring(tam))
  A.Set("nucleo.letraGrande", false)
  T(1)
  check(K.Tamano("cuerpo") == antes, "al apagarla no volvió el tamaño")
end)

step("Colores para daltonismo: bien, aviso, peligro y perjuicios", function()
  local r1, g1, b1 = K.Color("exito")
  local p1 = { K.ColorPerjuicio("Poison") }
  local m1 = { K.ColorPerjuicio("Magic") }
  check(cerca(p1[1], 0) and cerca(p1[2], 0.6), "el veneno no tiene el verde del juego")
  check(cerca(m1[3], 1), "la magia no tiene el azul del juego")
  check(K.TokenPerjuicio(nil) == "debuffFisico" and K.TokenPerjuicio("Curse") == "debuffMaldicion", "K.TokenPerjuicio")
  A.Set("nucleo.daltonico", true)
  T(1)
  check(K.Daltonico(), "K.Daltonico no lo ve")
  local r2, g2, b2 = K.Color("exito")
  check(not cerca(g1, g2) or not cerca(b1, b2), "el éxito no cambió de color")
  check(b2 > r2 and b2 > 0.8, "el éxito no quedó azul")
  local p2 = { K.ColorPerjuicio("Poison") }
  local d2 = { K.ColorPerjuicio("Disease") }
  check(not cerca(p2[2], p1[2]) or not cerca(p2[3], p1[3]), "el veneno no cambió de color")
  check(math.abs(p2[1] - d2[1]) > 0.5, "veneno y enfermedad no se distinguen")
  -- Lo de peligro y aviso se sigue leyendo.
  check(contraste("peligro", "panel") >= 4.5 and contraste("aviso", "panel") >= 4.5 and contraste("exito", "panel") >= 4.5,
    "con daltonismo, algún color de estado no se lee sobre el panel")
  -- También en Clásico WoW (otra piel).
  K.SetEstilo("clasico")
  T(1)
  local r3, g3, b3 = K.Color("exito")
  check(b3 > r3, "en Clásico WoW el éxito no es el azul del modo para daltonismo")
  K.SetEstilo("alfa")
  A.Set("nucleo.daltonico", false)
  T(1)
  local r4, g4 = K.Color("exito")
  check(cerca(g4, g1), "al apagarlo no volvió el verde")
end)

---------------------------------------------------------------------------
-- 37. Pantalla limpia
---------------------------------------------------------------------------
step("Pantalla limpia: esconde lo elegido y lo devuelve como estaba", function()
  local Pl = N.PantallaLimpia
  check(Pl and Pl.Alternar and Pl.GRUPOS, "falta N.PantallaLimpia")
  check(BINDING_NAME_ALFA_PANTALLA_LIMPIA and BINDING_NAME_ALFA_AYUDA, "faltan los nombres de los atajos nuevos")
  local chat = ChatFrame1
  chat:SetAlpha(0.8)
  MinimapCluster:SetAlpha(1)
  -- Una barra protegida.
  local barra = rawget(_G, "MainMenuBar") or CreateFrame("Frame", "MainMenuBar")
  _G.MainMenuBar = barra
  barra.IsProtected = function() return true end
  barra:SetAlpha(1)
  A.Set("nucleo.limpiaBarras", true)
  A.Set("nucleo.limpiaChat", true)
  check(Pl.Alternar() == true and Pl.Activa(), "no quedó limpia")
  check(chat:GetAlpha() == 0 and MinimapCluster:GetAlpha() == 0, "el chat o el minimapa siguen a la vista")
  check(barra:GetAlpha() == 0, "la barra no se escondió (fuera de combate)")
  check(chat:IsShown(), "se ocultó el chat (solo debe ser transparente)")
  -- Apagar un grupo con la pantalla limpia puesta lo devuelve.
  A.Set("nucleo.limpiaMinimapa", false)
  check(MinimapCluster:GetAlpha() == 1, "apagar el minimapa no lo devolvió")
  A.Set("nucleo.limpiaMinimapa", true)
  check(MinimapCluster:GetAlpha() == 0, "prender el minimapa no lo escondió")
  -- Volver: cada uno con su transparencia de antes.
  check(Pl.Alternar() == false, "no volvió")
  check(cerca(chat:GetAlpha(), 0.8) and MinimapCluster:GetAlpha() == 1 and barra:GetAlpha() == 1, "no volvió todo como estaba")
  check(Pl.Escondidos() == 0, "quedaron marcos anotados")
end)

step("Pantalla limpia: lo protegido espera al fin del combate", function()
  local Pl = N.PantallaLimpia
  local barra = MainMenuBar
  local orig = InCombatLockdown
  InCombatLockdown = function() return true end
  Pl.Alternar(true)
  check(ChatFrame1:GetAlpha() == 0, "en combate, el chat (no protegido) no se escondió")
  check(barra:GetAlpha() == 1, "se tocó una barra protegida en combate")
  InCombatLockdown = orig
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  T(1)
  check(barra:GetAlpha() == 0, "al terminar el combate la barra no se escondió")
  InCombatLockdown = function() return true end
  Pl.Alternar(false)
  check(barra:GetAlpha() == 0, "se devolvió una barra protegida en combate")
  check(cerca(ChatFrame1:GetAlpha(), 0.8), "en combate el chat no volvió")
  InCombatLockdown = orig
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  T(1)
  check(barra:GetAlpha() == 1, "al terminar el combate la barra no volvió")
  A.Set("nucleo.limpiaBarras", false)
  -- El comando.
  A.RunCommand("limpia")
  check(Pl.Activa(), "/alfa limpia no la puso")
  A.RunCommand("limpia")
  check(not Pl.Activa(), "/alfa limpia otra vez no la quitó")
end)

---------------------------------------------------------------------------
-- 39. Tus atajos
---------------------------------------------------------------------------
step("Tus atajos: la lista sale de todos los módulos", function()
  local Tc = M.Teclas
  check(Tc and Tc.Lista, "falta M.Teclas")
  local l = Tc.Lista()
  local hay = {}
  for _, t in ipairs(l) do hay[t.accion] = t.nombre end
  for _, a in ipairs({ "ALFA_TOGGLE", "ALFA_OPTIONS", "ALFA_PANTALLA_LIMPIA", "ALFA_AYUDA", "ALFA_LYA_GUIA", "ALFA_MUNDO_MAPA",
      "ALFA_RUTAS_CERCA", "ALFA_PESCA_MODO", "CLICK AlfaPescaBoton:LeftButton", "CLICK AlfaQuestItemButton:LeftButton" }) do
    check(hay[a], "la lista no trae " .. a)
  end
  check(l[1] and l[1].accion == "ALFA_OPTIONS", "el primero no es abrir Alfa")
  -- Uno nuevo (de un módulo futuro) sale solo.
  BINDING_NAME_ALFA_PRUEBA_FUTURA = "Algo nuevo"
  local hayNuevo = false
  for _, t in ipairs(Tc.Lista()) do if t.accion == "ALFA_PRUEBA_FUTURA" then hayNuevo = true end end
  check(hayNuevo, "un atajo nuevo de otro módulo no sale")
  BINDING_NAME_ALFA_PRUEBA_FUTURA = nil
end)

step("Tus atajos: la ventana y cambiar una tecla", function()
  local Tc = M.Teclas
  local puestas, guardadas = {}, 0
  local SB, SV, GB, GC = SetBinding, SaveBindings, GetBindingKey, GetCurrentBindingSet
  local teclas = {}
  SetBinding = function(k, accion) puestas[#puestas + 1] = { k, accion } if accion then teclas[accion] = k else for a, t in pairs(teclas) do if t == k then teclas[a] = nil end end end return true end
  SaveBindings = function() guardadas = guardadas + 1 end
  GetCurrentBindingSet = function() return 1 end
  GetBindingKey = function(accion) return teclas[accion] end
  Tc.Abrir()
  T(1)
  check(Tc.Visible(), "la ventana de atajos no abrió")
  check(#Tc.Filas() == #Tc.Lista(), "la ventana no trae una fila por atajo")
  local G = A.Gamepad
  check(G and G.Bind, "falta el servicio de teclas del motor")
  check(G.Bind("ALFA_PANTALLA_LIMPIA", "CTRL-L"), "no se pudo poner la tecla")
  check(teclas.ALFA_PANTALLA_LIMPIA == "CTRL-L" and guardadas > 0, "SetBinding / SaveBindings no se llamaron")
  FIRE_EVENT("UPDATE_BINDINGS")
  T(1)
  -- En combate no se cambia.
  local orig = InCombatLockdown
  InCombatLockdown = function() return true end
  local antes = #puestas
  check(not G.Bind("ALFA_AYUDA", "CTRL-H"), "se cambió una tecla en combate")
  check(#puestas == antes, "SetBinding se llamó en combate")
  InCombatLockdown = orig
  A.RunCommand("teclas")
  check(Tc.Visible(), "/alfa teclas no abrió")
  SetBinding, SaveBindings, GetBindingKey, GetCurrentBindingSet = SB, SV, GB, GC
  _G.AlfaTeclas:Hide()
end)

---------------------------------------------------------------------------
-- 40. ¿Qué es esto?
---------------------------------------------------------------------------
step("«¿Qué es esto?»: con Alt abajo cada control dice qué hace", function()
  local info = function() return _G.AlfaKitInfo end
  local g = K.GrupoAjustes(UIParent, { titulo = "Prueba" })
  local fila = g:Fila({ titulo = "Tu interruptor", texto = "Hace algo útil.",
    control = function(f) return K.Interruptor(f, { clave = "nucleo.letraGrande" }) end })
  local c = fila.Control
  check(c and c.alfaAyuda, "el control de una fila no tiene su ayuda")
  local t, x = K.TextoAyuda(c)
  check(t == "Tu interruptor" and x == "Hace algo útil.", "la ayuda del control no es la de su fila")
  local alt = IsAltKeyDown
  IsAltKeyDown = function() return false end
  K.OcultarInfo()
  FIRE(c, "OnEnter")
  check(not (info() and info():IsShown()), "sin Alt la ayuda salió igual")
  FIRE(c, "OnLeave")
  IsAltKeyDown = function() return true end
  FIRE(c, "OnEnter")
  check(info() and info():IsShown() and info().dueno == c, "con Alt abajo la ayuda no salió")
  FIRE(c, "OnLeave")
  check(not info():IsShown(), "la ayuda no se fue al salir")
  -- Alt pulsado con el ratón ya encima.
  IsAltKeyDown = function() return false end
  FIRE(c, "OnEnter")
  IsAltKeyDown = function() return true end
  FIRE_EVENT("MODIFIER_STATE_CHANGED", "LALT", 1)
  check(info():IsShown() and info().dueno == c, "pulsar Alt con el ratón encima no mostró la ayuda")
  IsAltKeyDown = function() return false end
  FIRE_EVENT("MODIFIER_STATE_CHANGED", "LALT", 0)
  check(not info():IsShown(), "soltar Alt no quitó la ayuda")
  FIRE(c, "OnLeave")
  -- Otra tecla elegida: Alt ya no cuenta.
  A.Set("nucleo.ayudaTecla", "CTRL")
  IsAltKeyDown = function() return true end
  check(not K.AyudaActiva(), "con Ctrl elegida, Alt la activó")
  A.Set("nucleo.ayudaTecla", "ALT")
  IsAltKeyDown = alt
end)

step("«¿Qué es esto?»: el modo ayuda y los botones con ayuda", function()
  local info = function() return _G.AlfaKitInfo end
  local b = K.Boton(UIParent, "Botón", function() end, { ayuda = "Lo que hace este botón." })
  local f = CreateFrame("Button", nil, UIParent)
  K.Ayuda(f, "Una pieza", "Para qué sirve la pieza.")
  check(not K.ModoAyuda(), "el modo ayuda empezó prendido")
  FIRE(f, "OnEnter")
  check(not (info() and info():IsShown() and info().dueno == f), "sin modo ayuda la pieza mostró su ayuda")
  FIRE(f, "OnLeave")
  check(K.AlternarAyuda() == true and K.ModoAyuda(), "el modo ayuda no se prendió")
  FIRE(f, "OnEnter")
  check(info():IsShown() and info().dueno == f, "en modo ayuda la pieza no dijo qué hace")
  FIRE(f, "OnLeave")
  FIRE(b, "OnEnter")
  check(info():IsShown() and info().dueno == b, "en modo ayuda un botón con ayuda no la mostró")
  FIRE(b, "OnLeave")
  check(K.AlternarAyuda() == false, "el modo ayuda no se apagó")
  -- Su atajo.
  check(type(BINDING_NAME_ALFA_AYUDA) == "string", "falta el nombre del atajo de ayuda")
end)

---------------------------------------------------------------------------
-- La página Estilo y sonido y Lya
---------------------------------------------------------------------------
step("Estilo y sonido: la página con lo nuevo", function()
  N.Abrir(M.ID)
  T(2)
  check(type(M.OPCIONES_AYUDA) == "function" and #M.OPCIONES_AYUDA() == 4, "faltan las opciones de la tecla de ayuda")
  local mod = N.ModuloPorId(M.ID)
  check(mod ~= nil, "no está el módulo de la bienvenida")
  -- Cada estilo en la página, sin errores.
  for _, id in ipairs({ "nocturno", "fogata", "alfa" }) do
    K.SetEstilo(id)
    T(1)
  end
end)

step("Lya aprende lo nuevo", function()
  for _, id in ipairs({ "bienvenida.leer", "bienvenida.quees", "bienvenida.limpia", "bienvenida.teclas" }) do
    check(ensenado[id] or not rawget(_G, "AlfaLya"), "Lya no aprendió " .. id)
  end
end)

print(("PRUEBA: 1.3.0 interfaz (estilos, pantalla limpia, leer mejor, atajos, ayuda), %d pasos, %d errores"):format(pasos, #ERRORS))
