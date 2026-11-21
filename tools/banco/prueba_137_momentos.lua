-- Prueba de la 1.3.7, los momentos (Alfa_Nucleo/Momentos.lua, Kit/Ventanas.lua y Lya;
-- tools/prueba.py la corre con las demás prueba_*.lua):
--   * pausas: pantalla de carga (+3 s), cinemática, hablando con un PNJ (lo de ese PNJ
--     sí sale), pelea (lo no urgente espera), estandartes del juego (30-32, 39, 49);
--   * No molestar (/alfa calma, /dnd): lo callado queda en «Lo que me perdí» (50);
--   * «Te perdiste esto»: los últimos 30 por personaje, el contador del minimapa y el
--     renglón del menú (51-53);
--   * dos botones en un aviso, la duración según el texto, los sonidos (60, 69-71);
--   * Lya: lo importante que espera es una lista con prioridad (41), un solo aullido (35);
--   * Talentos: la tarjeta de rangos viejos que dice Lya ya no deja al motor esperando (125);
--   * la búsqueda encuentra los 4 ajustes de Lya que faltaban (156).
SNAPSHOTS = {}
BANCO_MOMENTOS = true
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
local function check(cond, msg) if not cond then NOTE("1.3.7 momentos", msg) end end

local A, N, K = Alfa, AlfaNucleo, AlfaNucleo.Kit
local Ly = NS_OF("Alfa_Lya")

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(8)

local vistos = {}
A.On("ALFA_AVISO", function(o) vistos[#vistos + 1] = o and o.titulo or "?" end)
local function visto(t) for _, x in ipairs(vistos) do if x == t then return true end end return false end
local function correr(n) for _ = 1, n do RUN_TIMERS(1) end end
local function limpiar() correr(25) vistos = {} end

---------------------------------------------------------------------------
step("Pantalla de carga: 3 s de calma", function()
  limpiar()
  FIRE_EVENT("LOADING_SCREEN_ENABLED")
  check(K.Aviso({ titulo = "En la carga", lya = false }) == nil, "un aviso salió en plena pantalla de carga")
  FIRE_EVENT("LOADING_SCREEN_DISABLED")
  local t0 = NOW
  check(select(2, N.Ocupado("aviso")) == "carga", "tras la carga no hubo calma")
  correr(1)
  check(not visto("En la carga"), "el aviso salió antes de los 3 s de calma")
  correr(6)
  check(visto("En la carga"), "el aviso de la carga no salió después")
  check(type(K.Aviso({ titulo = "Urgente en carga", lya = false, prioridad = 1 })) == "table", "lo urgente esperó sin carga")
end)

step("Cinemática: todo espera", function()
  limpiar()
  FIRE_EVENT("CINEMATIC_START")
  check(K.Aviso({ titulo = "En la cinemática", lya = false, prioridad = 1 }) == nil, "un aviso salió encima de una cinemática")
  correr(3)
  check(not visto("En la cinemática"), "salió en plena cinemática")
  FIRE_EVENT("CINEMATIC_STOP")
  correr(3)
  check(visto("En la cinemática"), "tras la cinemática no salió")
end)

step("Hablando con un PNJ: lo de ese PNJ sale, lo demás espera a que cierres", function()
  limpiar()
  FIRE_EVENT("MERCHANT_SHOW")
  check(type(K.Aviso({ titulo = "Del vendedor", lya = false })) == "table", "lo que sale al abrir el vendedor esperó")
  NOW = NOW + 5
  check(K.Aviso({ titulo = "Otra cosa", lya = false }) == nil, "algo ajeno salió mientras hablas con el vendedor")
  check(type(K.Aviso({ titulo = "Importante en PNJ", lya = false, importante = true })) == "table", "lo importante esperó al PNJ")
  correr(2)
  check(not visto("Otra cosa"), "lo ajeno salió con el vendedor abierto")
  FIRE_EVENT("MERCHANT_CLOSED")
  correr(4)
  check(visto("Otra cosa"), "al cerrar el vendedor no salió lo que esperaba")
end)

step("En una pelea, lo que no es urgente espera a que termine", function()
  limpiar()
  local icl = InCombatLockdown
  InCombatLockdown = function() return true end
  check(K.Aviso({ titulo = "En la pelea", lya = false }) == nil, "un aviso no urgente salió en plena pelea")
  check(type(K.Aviso({ titulo = "Urgente en la pelea", lya = false, prioridad = "urgente" })) == "table", "lo urgente esperó a la pelea")
  correr(3)
  check(not visto("En la pelea"), "salió en plena pelea")
  InCombatLockdown = icl
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  correr(4)
  check(visto("En la pelea"), "al terminar la pelea no salió lo que esperaba")
end)

step("Lo que pides tú sale ya", function()
  limpiar()
  FIRE_EVENT("CINEMATIC_START")
  check(type(K.Aviso({ titulo = "Pedido", lya = false, pedido = true })) == "table", "lo que pediste esperó")
  FIRE_EVENT("CINEMATIC_STOP")
end)

---------------------------------------------------------------------------
step("No molestar: /alfa calma guarda lo callado en «Lo que me perdí»", function()
  limpiar()
  N.OlvidarPerdidos()
  N.Calma("30")
  local en, por = N.EnCalma()
  check(en and por == "tiempo", "con /alfa calma 30 no quedó en calma")
  check(N.CalmaHasta() > GetServerTime(), "la calma no guardó hasta cuándo")
  check(K.Aviso({ titulo = "Callado", texto = "algo", lya = false }) == nil, "en calma salió un aviso no urgente")
  check(type(K.Aviso({ titulo = "Urgente en calma", lya = false, prioridad = 1 })) == "table", "en calma no salió lo urgente")
  local hay = false
  for _, e in ipairs(N.Perdidos()) do if e.titulo == "Callado" then hay = true end end
  check(hay, "lo callado no quedó en «Lo que me perdí»")
  check(N.Ocupado("anuncio") and select(2, N.Ocupado("anuncio")) == "calma", "en calma un anuncio no esperaría")
  check(not N.AnunciosGrandes(), "en calma los anuncios grandes siguen")
  N.Calma("no")
  check(not N.EnCalma(), "/alfa calma no la quitó")
  check(visto("Se acabó la calma"), "al terminar la calma no avisó cuántas cosas guardó")
  N.Calma("sesion")
  check(N.EnCalma(), "la calma de la sesión no quedó")
  N.Calma("no")
  -- /dnd del juego
  local dndOrig = UnitIsDND
  UnitIsDND = function() return true end
  check(N.EnCalma(), "con /dnd Alfa no se calló")
  A.Set("nucleo.respetarDnd", false)
  check(not N.EnCalma(), "con «Respetar el /dnd» apagado siguió callada")
  A.Set("nucleo.respetarDnd", true)
  UnitIsDND = dndOrig
end)

step("«Te perdiste esto»: los últimos 30, con hora, el contador y el menú", function()
  limpiar()
  N.OlvidarPerdidos()
  for i = 1, 35 do N.Perdido({ titulo = "Perdido " .. i, texto = "texto" }) end
  local l = N.Perdidos()
  check(#l == 30, "se guardaron " .. #l .. " en vez de 30")
  check(l[1].titulo == "Perdido 35" and type(l[1].hora) == "string" and l[1].hora ~= "", "el más nuevo no va primero o no trae su hora")
  check(AlfaNucleoCharDB and AlfaNucleoCharDB.momentos and AlfaNucleoCharDB.momentos.perdidos == l, "«Te perdiste esto» no se guarda por personaje")
  -- Un aviso que se va sin tocarlo (con o sin botón) queda ahí.
  N.OlvidarPerdidos()
  K.Aviso({ titulo = "Sin botón", lya = false })
  K.Aviso({ titulo = "Con botón", lya = false, accion = { texto = "Ir", alClic = function() end } })
  correr(3)
  local t = {}
  for _, e in ipairs(N.Perdidos()) do t[e.titulo] = e end
  check(t["Sin botón"] and t["Con botón"], "un aviso que se fue sin verlo no quedó en «Te perdiste esto»")
  check(t["Con botón"] and N.AccionPerdido(t["Con botón"]), "el aviso perdido no guardó su botón")
  -- Lo que pediste no se guarda.
  N.OlvidarPerdidos()
  K.Aviso({ titulo = "Lo pedí", lya = false, pedido = true })
  correr(3)
  check(#N.Perdidos() == 0, "un aviso que pediste quedó como perdido")
  -- El contador del minimapa.
  local mm = rawget(_G, "AlfaMinimapButton") or CreateFrame("Button", "AlfaMinimapButton", UIParent)
  N.Perdido({ titulo = "Uno", texto = "x" })
  N.Perdido({ titulo = "Dos", texto = "x" })
  N.PintarContadorPerdidos()
  check(mm.alfaContador and mm.alfaContador:IsShown(), "el botón del minimapa no enseña el contador")
  check(N.PerdidosSinVer() == 2, "el contador no cuenta 2: " .. N.PerdidosSinVer())
  -- El menú de Alfa y la ventana.
  local item = N.MenuPerdidos()
  check(item and item.text:find("Lo que me perdí", 1, true) and item.text:find("2", 1, true), "el menú no dice «Lo que me perdí (2)»")
  local O = A.UI and A.UI.Options
  if O and O.MenuItems then
    local hayMenu = false
    for _, it in ipairs(O.MenuItems(UIParent)) do if type(it.text) == "string" and it.text:find("Lo que me perdí", 1, true) then hayMenu = true end end
    check(hayMenu, "el menú de Alfa no trae «Lo que me perdí»")
  end
  N.VerPerdidos()
  check(_G.AlfaPerdidos and _G.AlfaPerdidos:IsShown(), "no se abrió «Lo que me perdí»")
  NOW = NOW + 1
  check(N.PerdidosSinVer() == 0, "al abrirla, el contador no volvió a cero")
  check(not mm.alfaContador:IsShown(), "el contador siguió a la vista")
  _G.AlfaPerdidos:Hide()
end)

---------------------------------------------------------------------------
step("Un aviso con dos botones, su duración y su sonido", function()
  limpiar()
  local usado, no = 0, 0
  local a = K.Aviso({ titulo = "Dos botones", texto = "elige", lya = false, importante = true,
    acciones = { { texto = "Usarlo", alClic = function() usado = usado + 1 end }, { texto = "Ahora no", fn = function() no = no + 1 end } } })
  check(type(a) == "table" and a.Boton and a.Boton:IsShown() and a.Boton2 and a.Boton2:IsShown(), "el aviso no enseña sus dos botones")
  if a and a.Boton2 then a.Boton2.alClic() end
  check(no == 1 and usado == 0, "el segundo botón no hizo lo suyo")
  check(not a.alfaVivo, "el aviso no se fue al tocar un botón")
  -- Sonido suave, según «Sonidos de Alfa».
  N.ultimoSonido = nil
  NOW = NOW + 1
  K.Aviso({ titulo = "Importante con sonido", lya = false, importante = true, donde = true })
  check(N.ultimoSonido == "importante", "lo importante no sonó suave: " .. tostring(N.ultimoSonido))
  A.Set("nucleo.sonidos", "ninguno")
  N.ultimoSonido = nil
  NOW = NOW + 1
  K.Aviso({ titulo = "Sin sonido", lya = false, importante = true, donde = true })
  check(N.ultimoSonido == nil, "con «Sonidos de Alfa: ninguno» sonó")
  A.Set("nucleo.sonidos", "importantes")
  check(N.SonidoPermitido(2) and not N.SonidoPermitido(3), "«solo los importantes» no filtra")
  A.Set("nucleo.sonidos", "todos")
end)

step("Un diálogo que nadie pidió no pone el velo", function()
  limpiar()
  local aceptado = false
  local d = K.Dialogo({ titulo = "Sin clic", texto = "pregunta", solo = true, alAceptar = function() aceptado = true end })
  check(d == nil and visto("Sin clic"), "un diálogo sin clic (solo = true) no salió como aviso")
  local velo = rawget(_G, "AlfaKitVelo")
  check(not (velo and velo:IsShown()), "un diálogo sin clic puso el velo")
  K.CerrarDialogo()
end)

---------------------------------------------------------------------------
step("Lya: lo importante que espera es una lista con prioridad", function()
  local Ce = Ly.Cerebro
  check(Ce and Ce.Esperas, "falta la lista de lo que espera Lya")
  if not (Ce and Ce.Esperas) then return end
  local activa, vis = Ce.Activa, Ly.UI.Visible
  Ce.Activa = function() return true end
  Ly.UI.Visible = function() return true end
  local dichos = {}
  local h = Ly.UI.Hablar
  Ly.UI.Hablar = function(c) dichos[#dichos + 1] = c.texto end
  FIRE_EVENT("CINEMATIC_START")
  check(Ce.Decir({ texto = "Primero importante", importante = true }) == "espera", "lo importante no esperó a la cinemática")
  check(Ce.Decir({ texto = "Segundo importante", importante = true }) == "espera", "lo segundo importante no esperó")
  check(#Ce.Esperas() == 2, "lo segundo borró a lo primero (esperan " .. #Ce.Esperas() .. ")")
  FIRE_EVENT("CINEMATIC_STOP")
  for _ = 1, 30 do RUN_TIMERS(1) if Ly.UI.Callar then pcall(Ly.UI.Callar, true) end end
  local uno, dos = false, false
  for _, t in ipairs(dichos) do if t == "Primero importante" then uno = true elseif t == "Segundo importante" then dos = true end end
  check(uno and dos, "Lya no dijo las dos cosas importantes que esperaban")
  Ly.UI.Hablar, Ce.Activa, Ly.UI.Visible = h, activa, vis
end)

step("Talentos: la tarjeta de rangos viejos que dice Lya deja pasar al motor (125)", function()
  limpiar()
  local cerrada = 0
  local porLya = K.AvisoPorLya
  K.AvisoPorLya = function() return true end
  A.Reemplazos.Llamar("SPELL_CARDS", { accion = "mostrar", tipo = "SPELL_CARDS", Cerrar = function() cerrada = cerrada + 1 end,
    modelo = { kind = "oldRanks", act = true, spells = { { id = 6552, bestId = 6554 } } } })
  correr(2)
  K.AvisoPorLya = porLya
  check(cerrada == 1, "la dijo Lya y el motor se quedó esperando (Cerrar: " .. cerrada .. ")")
end)

step("La búsqueda encuentra los 4 ajustes de Lya que faltaban (156)", function()
  local O = A.UI and A.UI.Options
  local Nm = N.ModuloPorId and N.ModuloPorId("lya")
  local controles = Nm and Nm.controles
  check(type(controles) == "table", "la página de Lya no trae sus controles")
  local hay = {}
  for _, c in ipairs(controles or {}) do if c.key then hay[c.key] = true end end
  for _, k in ipairs({ "lya.letra", "lya.avisos", "lya.aullidoMision", "lya.aullarGrupo" }) do
    check(hay[k], "la búsqueda no encuentra " .. k)
  end
  local ctl = N.ControlesMomentos and N.ControlesMomentos()
  check(ctl and #ctl >= 3, "faltan los ajustes de los momentos para la búsqueda")
end)

print("PRUEBA: 1.3.7 los momentos, " .. pasos .. " pasos, " .. #ERRORS .. " errores")
