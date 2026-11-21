-- Prueba de la 1.3.1 (lo que reportó Toxic del juego):
--   * el buzón: en el juego el oro de una carta llega un momento después de
--     tomarlo (PLAYER_MONEY tarda). «Tomar todo» decía «No había nada que
--     tomar» aunque sí tomó dinero (el chat decía «Obtuviste: 7s 35c»). Aquí el
--     oro llega tarde a propósito: el resumen debe contar lo que salió de las
--     cartas;
--   * el minimapa: con «Ocultar los botones de addons», el botón de Alfa
--     siempre queda a la vista (los de otros addons sí se atenúan).
-- Las funciones del buzón son de mentira y viven aquí.
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
local function check(cond, msg) if not cond then NOTE("1.3.1 varios", msg) end end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit

---------------------------------------------------------------------------
-- El juego de mentira: el dinero llega tarde, como en el juego
---------------------------------------------------------------------------
local dinero = 100000
local enCamino = 0 -- lo que el servidor todavía no suma
GetMoney = function() return dinero end
local function llegaDinero()
  if enCamino > 0 then
    dinero = dinero + enCamino
    enCamino = 0
    FIRE_EVENT("PLAYER_MONEY")
  end
end

local bolsa = {}
local function libres() local n = 0 for s = 1, 16 do if not bolsa[s] then n = n + 1 end end return n end
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end
C_Container.GetContainerNumFreeSlots = function(b) if b == 0 then return libres(), 0 end return 0, 0 end
C_Container.CalculateTotalNumberOfFreeBagSlots = function() return libres() end
C_Container.GetContainerItemInfo = function(b, s) if b ~= 0 then return nil end return bolsa[s] end

local cartas = {}
local function evento(ev) C_Timer.After(0, function() FIRE_EVENT(ev) end) end
local function quitarSiVacia(i)
  local c = cartas[i]
  if c and c.dinero == 0 and #c.objetos == 0 then table.remove(cartas, i) end
end
GetInboxNumItems = function() return #cartas, #cartas end
GetInboxHeaderInfo = function(i)
  local c = cartas[i]
  if not c then return nil end
  return "icono", nil, c.remitente, "Asunto", c.dinero, c.cod or 0, c.dias or 30, #c.objetos, false, false, false, true, c.mj or false
end
GetInboxItem = function(i, a)
  local c = cartas[i]
  local o = c and c.objetos[a]
  if not o then return nil end
  return "Objeto " .. o[1], o[1], 134400, o[2], 1, true
end
HasInboxItem = function(i, a) local c = cartas[i] return c and c.objetos[a] ~= nil or false end
TakeInboxMoney = function(i)
  local c = cartas[i]
  if not c or c.dinero <= 0 then return end
  -- La carta queda sin dinero al momento, pero tu oro sube después.
  enCamino = enCamino + c.dinero
  c.dinero = 0
  quitarSiVacia(i)
  evento("MAIL_INBOX_UPDATE")
end
TakeInboxItem = function(i, a)
  local c = cartas[i]
  if not (c and c.objetos[a]) then return end
  for s = 1, 16 do if not bolsa[s] then bolsa[s] = { itemID = c.objetos[a][1], stackCount = c.objetos[a][2], quality = 1 } break end end
  table.remove(c.objetos, a)
  quitarSiVacia(i)
  evento("MAIL_INBOX_UPDATE")
end
C_Mail = { IsCommandPending = function() return false end, SetOpeningAll = function() end,
  HasInboxMoney = function(i) local c = cartas[i] return c and c.dinero > 0 or false end }
ATTACHMENTS_MAX_RECEIVE = 16
MailFrame = MailFrame or CreateFrame("Frame", "MailFrame", UIParent)
MailFrame:SetSize(384, 512)
MailFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -100)

local avisos = {}
local avisoReal = K.Aviso
K.Aviso = function(o) avisos[#avisos + 1] = o return {} end
local function ultimo() return avisos[#avisos] end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)
A.Set("qol.sellJunk", false)

local C = NS_OF("Alfa_Comercio")
local Bz = C.Buzon

---------------------------------------------------------------------------
-- El buzón
---------------------------------------------------------------------------
step("El buzón: solo dinero, y el oro llega después de terminar", function()
  check(Bz and Bz.Tomar, "falta Buzon.lua") if not Bz then return end
  for s = 1, 16 do bolsa[s] = nil end
  cartas = {
    { remitente = "Subasta", dinero = 735, objetos = {} },
  }
  avisos = {}
  FIRE_EVENT("MAIL_SHOW")
  FIRE_EVENT("MAIL_INBOX_UPDATE")
  RUN_TIMERS(2)
  check(Bz.Tomar(), "Tomar todo no empezó")
  RUN_TIMERS(40)
  check(not Bz.Tomando(), "no terminó")
  local a = ultimo()
  check(a and not (a.texto or ""):find("No había nada", 1, true),
    "dijo «No había nada que tomar» aunque tomó 7s 35c: " .. tostring(a and a.texto))
  check(Bz.ultimo and Bz.ultimo.dinero == 735, "el resumen no cuenta el dinero de la carta (" .. tostring(Bz.ultimo and Bz.ultimo.dinero) .. ")")
  llegaDinero()
  RUN_TIMERS(2)
  FIRE_EVENT("MAIL_CLOSED")
end)

step("El buzón: dinero de varias cartas y objetos, con el oro tarde", function()
  for s = 1, 16 do bolsa[s] = nil end
  cartas = {
    { remitente = "Subasta", dinero = 2500, objetos = {} },
    { remitente = "Alt", dinero = 100, objetos = { { 2589, 20 } } },
    { remitente = "Vendedor", dinero = 0, cod = 5000, objetos = { { 2318, 1 } } },
    { remitente = "Subasta", dinero = 4000, objetos = {} },
  }
  avisos = {}
  FIRE_EVENT("MAIL_SHOW")
  FIRE_EVENT("MAIL_INBOX_UPDATE")
  RUN_TIMERS(2)
  Bz.Tomar()
  RUN_TIMERS(60)
  check(not Bz.Tomando(), "no terminó")
  check(Bz.ultimo and Bz.ultimo.dinero == 6600, "no contó el dinero de las 3 cartas (" .. tostring(Bz.ultimo and Bz.ultimo.dinero) .. ")")
  local a = ultimo()
  check(a and (a.texto or ""):find("Recibiste 20 piezas", 1, true), "el resumen no dice los objetos: " .. tostring(a and a.texto))
  check(a and (a.texto or ""):find("Dejé 1 carta", 1, true), "el resumen no dice la carta que dejó: " .. tostring(a and a.texto))
  llegaDinero()
  RUN_TIMERS(2)
  FIRE_EVENT("MAIL_CLOSED")
end)

step("El buzón: si el oro sí llega a tiempo, no se cuenta dos veces", function()
  for s = 1, 16 do bolsa[s] = nil end
  cartas = { { remitente = "Subasta", dinero = 1200, objetos = {} } }
  local real = TakeInboxMoney
  TakeInboxMoney = function(i) real(i) llegaDinero() end
  avisos = {}
  FIRE_EVENT("MAIL_SHOW")
  FIRE_EVENT("MAIL_INBOX_UPDATE")
  RUN_TIMERS(2)
  Bz.Tomar()
  RUN_TIMERS(40)
  TakeInboxMoney = real
  check(Bz.ultimo and Bz.ultimo.dinero == 1200, "contó mal el dinero que llegó a tiempo (" .. tostring(Bz.ultimo and Bz.ultimo.dinero) .. ")")
  FIRE_EVENT("MAIL_CLOSED")
end)
K.Aviso = avisoReal

---------------------------------------------------------------------------
-- El minimapa: el botón de Alfa siempre a la vista
---------------------------------------------------------------------------
step("Minimapa: el botón de Alfa no se esconde con los de otros addons", function()
  local Co = NS_OF("Alfa_Comodidades")
  local Mm = Co and Co.Minimapa
  check(Mm and Mm.EsBotonDeAddon, "falta el contrato de pruebas de Minimapa.lua") if not (Mm and Mm.EsBotonDeAddon) then return end
  local alfa = _G.AlfaMinimapButton or CreateFrame("Button", "AlfaMinimapButton", Minimap)
  local otro = CreateFrame("Button", "LibDBIcon10_OtroAddon", Minimap)
  check(not Mm.EsBotonDeAddon(alfa), "el botón de Alfa cuenta como botón de otro addon (se escondería)")
  check(Mm.EsBotonDeAddon(otro), "el botón de otro addon ya no se reconoce")
  A.Set("comodidades.minimapa", true)
  A.Set("comodidades.minimapaBotones", true)
  Mm.Aplicar()
  RUN_TIMERS(3)
  check((alfa:GetAlpha() or 1) >= 0.99, "el botón de Alfa quedó atenuado (" .. tostring(alfa:GetAlpha()) .. ")")
  check(not Mm.Botones[alfa], "el botón de Alfa quedó en la lista de los que se esconden")
  check(Mm.Botones[otro], "el botón del otro addon no se esconde")
  A.Set("comodidades.minimapaBotones", false)
  Mm.Aplicar()
end)

---------------------------------------------------------------------------
-- Los anuncios no se cruzan con lo que el juego escribe arriba
---------------------------------------------------------------------------
-- El nombre de la zona del juego (en el juego se desvanece solo).
-- (rawget: el banco inventa un comodín para los nombres que no existen)
local zona = rawget(_G, "ZoneTextFrame") or CreateFrame("Frame", "ZoneTextFrame", UIParent)
zona:Hide()
local function anuncio() return _G.AlfaAnuncio end
local function correrAnuncio(segundos)
  local a = anuncio()
  local t = 0
  while a and a:IsShown() and t < segundos do
    FIRE(a, "OnUpdate", 0.1)
    t = t + 0.1
  end
end

step("Anuncios: si el juego escribe la zona, el de Alfa sale después", function()
  K.QuitarAnuncio()
  zona:Show() zona:SetAlpha(1)
  check(K.Anuncio({ sobre = "La manada viaja", titulo = "Ventormenta", segundos = 5 }), "el anuncio no se aceptó")
  check(not (anuncio() and anuncio():IsShown()), "el anuncio salió encima del nombre de la zona del juego")
  check(K.AnuncioEsperando and K.AnuncioEsperando(), "el anuncio no quedó esperando su turno")
  RUN_TIMERS(2)
  check(not (anuncio() and anuncio():IsShown()), "salió mientras el juego seguía escribiendo")
  zona:Hide()
  RUN_TIMERS(3)
  check(anuncio() and anuncio():IsShown(), "no salió cuando el juego terminó")
  correrAnuncio(10)
  check(not anuncio():IsShown(), "el anuncio no se fue solo")
end)

step("Anuncios: si el juego escribe mientras se ve, se va y vuelve después", function()
  K.QuitarAnuncio()
  zona:Hide()
  K.Anuncio({ sobre = "Lya olfateó un raro", titulo = "Mor'Ladim", segundos = 6 })
  check(anuncio():IsShown(), "no salió")
  correrAnuncio(1)
  zona:Show() zona:SetAlpha(1)
  correrAnuncio(1)
  check(not anuncio():IsShown(), "siguió encima del nombre de la zona")
  check(K.AnuncioEsperando(), "no quedó esperando para volver")
  zona:Hide()
  RUN_TIMERS(3)
  check(anuncio():IsShown(), "no volvió cuando el juego terminó")
  K.QuitarAnuncio()
end)

step("Anuncios: si el juego no suelta la pantalla, sale igual al rato", function()
  K.QuitarAnuncio()
  zona:Show() zona:SetAlpha(1)
  K.Anuncio({ titulo = "Rut'theran", segundos = 4 })
  RUN_TIMERS(15)
  check(anuncio():IsShown(), "esperó para siempre")
  zona:Hide()
  K.QuitarAnuncio()
  check(not K.AnuncioEsperando(), "QuitarAnuncio no soltó el que esperaba")
end)

---------------------------------------------------------------------------
-- Acomodar la pantalla con el ratón
---------------------------------------------------------------------------
step("Acomodar: mover a Lya con el ratón y regresarla con clic derecho", function()
  local B = NS_OF("Alfa_Bienvenida")
  local Ac = B and B.Acomodar
  check(Ac and Ac.Abrir, "falta Acomodar.lua") if not (Ac and Ac.Abrir) then return end
  if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
  local Ly = NS_OF("Alfa_Lya")
  if Ly and Ly.UI and Ly.UI.Aplicar then Ly.UI.Aplicar() end
  local lya = rawget(_G, "AlfaLyaLoba")
  check(lya and lya:IsVisible(), "Lya no está a la vista para la prueba")
  local bloqueo = A.DragLocked
  check(Ac.Abrir(), "no se abrió")
  check(Ac.Activo(), "no quedó activo")
  check(not A.DragLocked(), "mientras acomodas, algo sigue bloqueado")
  local m = Ac.Marcas().lya
  check(m and m:IsShown(), "Lya no tiene su marco para moverla")
  -- Arrastrar: el ratón baja, Lya se mueve y al soltar guarda su lugar.
  FIRE(m, "OnMouseDown", "LeftButton")
  lya:ClearAllPoints()
  lya:SetPoint("CENTER", UIParent, "CENTER", 120, 60)
  FIRE(m, "OnMouseUp", "LeftButton")
  local pos = A.Get("lya.pos")
  check(type(pos) == "table" and pos[1] == "CENTER" and pos[2] == 120 and pos[3] == 60,
    "Lya no guardó su lugar nuevo: " .. tostring(pos and table.concat({ tostring(pos[1]), tostring(pos[2]), tostring(pos[3]) }, ",")))
  -- Clic derecho: a su lugar de siempre.
  FIRE(m, "OnClick", "RightButton")
  check(A.Get("lya.pos") == nil, "el clic derecho no la regresó a su lugar")
  -- Combate y Curación prenden sus propios marcos para mover.
  local Cb = NS_OF("Alfa_Combate")
  if Cb and Cb.Desbloqueado then check(Cb.Desbloqueado(), "no prendió los marcos para mover de Combate") end
  if AlfaCuracion and AlfaCuracion.Moviendo then check(AlfaCuracion.Moviendo(), "no prendió los marcos para mover de Curación") end
  Ac.Cerrar()
  check(not Ac.Activo(), "no se cerró")
  check(not m:IsShown(), "el marco de Lya se quedó al cerrar")
  check(A.DragLocked == bloqueo, "no devolvió el bloqueo de antes")
  if Cb and Cb.Desbloqueado then check(not Cb.Desbloqueado(), "Combate se quedó con sus marcos para mover") end
  if AlfaCuracion and AlfaCuracion.Moviendo then check(not AlfaCuracion.Moviendo(), "Curación se quedó con sus marcos para mover") end
end)

step("Acomodar: una pelea lo termina y en combate no se abre", function()
  local Ac = NS_OF("Alfa_Bienvenida").Acomodar
  Ac.Abrir()
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not Ac.Activo(), "siguió abierto al empezar la pelea")
  local real = InCombatLockdown
  InCombatLockdown = function() return true end
  check(not Ac.Abrir(), "se abrió en combate")
  InCombatLockdown = real
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
end)

print(string.format("PRUEBA: 1.3.1 buzón, minimapa, anuncios y acomodar, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
