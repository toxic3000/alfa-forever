-- Prueba de la 1.3.7, los anuncios (pedido de Toxic: «cada vez que llegues a
-- ese tipo de zonas aparezca ese anuncio como el de los barcos, los trenes o
-- los raros, y que haya diferentes animaciones para cada estilo»):
--   1. cada tipo con su animación, color, ícono y tamaño;
--   2. no se enciman: van por prioridad y el que se iba vuelve después;
--   3. lo vencido caduca, el sonido suena al aparecer (y no al volver);
--   4. solo el título toma el ratón; clic derecho lo cierra;
--   5. una pelea lo desvanece y vuelve después si aún vale;
--   6. llegar a una zona: su nombre, su dueño y sus niveles; el del juego se
--      esconde (y vuelve con la opción apagada); no se repite antes de 10 min;
--      nada en grifo (sale al aterrizar) ni en combate;
--   7. rincones (chicos, 20 s entre uno y otro), descubrir (con Lya),
--      mazmorra (una vez cada 30 min), zona peligrosa, ciudad;
--   8. la placa de llegada primero; el ancho se adapta a la pantalla;
--   9. barco con menos de 10 s: compacto y ya; raro en plena pelea: ícono chico;
--  10. Ajustes: «Probar» de cada tipo.
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
local function check(cond, msg) if not cond then NOTE("1.3.7 anuncios", msg) end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(5)

local N = AlfaNucleo
local A = N.A
local K = N.Kit
local Z = N.Zonas
local ns = NS_OF("Alfa")
A.Set("bienvenida.anuncios", true)
if N.Entrando then N.Entrando = function() return false end end

local function anuncio() return rawget(_G, "AlfaAnuncio") end
local function actual() return K.AnuncioActual() end
-- El tiempo pasa: el reloj del juego y el marco del anuncio.
local function correr(seg, dt)
  dt = dt or 0.05
  local t = 0
  while t < seg do
    NOW = NOW + dt
    local f = anuncio()
    if f and f:IsShown() then FIRE(f, "OnUpdate", dt) end
    t = t + dt
  end
end
local function limpiar()
  K.QuitarAnuncio()
  NOW = NOW + 10
  Z.Olvidar()
  RUN_TIMERS(2)
end

-- El mundo de mentira.
local mundo = { zona = "Durotar", sub = "", pvp = "friendly", taxi = false, combate = false, resting = false,
  inst = false, instTipo = "none", nivel = 23 }
GetRealZoneText = function() return mundo.zona end
GetZoneText = function() return mundo.zona end
GetSubZoneText = function() return mundo.sub end
C_PvP = C_PvP or {}
C_PvP.GetZonePVPInfo = function() return mundo.pvp, false, nil end
UnitOnTaxi = function() return mundo.taxi end
InCombatLockdown = function() return mundo.combate end
IsResting = function() return mundo.resting end
IsInInstance = function() return mundo.inst, mundo.instTipo end
UnitLevel = function() return mundo.nivel end
local nivelesZona = { [1411] = { 1, 10 } }
local mapsReal = A.Maps and A.Maps.GetZoneLevels
if A.Maps then A.Maps.GetZoneLevels = function(id) local v = nivelesZona[id] if v then return v[1], v[2] end return nil end end

local function pelea(on)
  mundo.combate = on
  FIRE_EVENT(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

---------------------------------------------------------------------------
-- 1. Cada tipo con su animación
---------------------------------------------------------------------------
step("Cada tipo de anuncio con su propia animación", function()
  local anims = {}
  for nombre, est in pairs(K.ESTILOS_ANUNCIO) do
    limpiar()
    check(K.Anuncio({ estilo = nombre, titulo = "Prueba " .. nombre, sobre = "Sobre", texto = "La línea de abajo", ya = true }),
      "no se aceptó el anuncio " .. nombre)
    local a = actual()
    check(a and a.estilo == nombre, "no salió el anuncio " .. nombre)
    if a then
      check(a.anim == est.anim, nombre .. ": no usa su animación")
      anims[a.anim] = (anims[a.anim] or 0) + 1
      if nombre == "subzona" then check(a.chico and a.rolTitulo == "titulo", "la subzona no sale chica") end
      if nombre == "peligro" then check(a.borde, "la zona peligrosa no tiene el borde que late") end
      if nombre == "descubrir" or nombre == "manada" then check(a.huellas, nombre .. ": sin sus huellas") end
      if nombre == "mazmorra" then check(a.color == "mazmorra", "la mazmorra no es morada") end
      if nombre == "ciudad" then check(a.color == "pnj", "la ciudad no es azul") end
      if nombre == "descubrir" or nombre == "tesoro" then check(a.color == "oro", nombre .. " no es dorado") end
    end
    -- La animación mueve el contenido (salvo los de solo fundido) y termina sola.
    local f = anuncio()
    local movio = false
    for _ = 1, 12 do
      correr(0.05)
      local _, _, _, x, y = f.C:GetPoint(1)
      if (x or 0) ~= 0 or (y or 0) ~= 0 then movio = true end
    end
    local quietos = { corto = true, lento = true, gira = true, late = true, aulla = true, cruzan = true }
    if not quietos[est.anim] then check(movio, nombre .. ": su animación no movió nada") end
    correr(12)
    check(not f:IsShown(), nombre .. ": el anuncio no se fue solo")
  end
  local n = 0
  for _ in pairs(anims) do n = n + 1 end
  check(n >= 13, "no hay una animación distinta para cada tipo (" .. n .. ")")
end)

---------------------------------------------------------------------------
-- 2. No se enciman
---------------------------------------------------------------------------
step("Un anuncio no pisa a otro: van por prioridad", function()
  limpiar()
  K.Anuncio({ estilo = "general", prioridad = 3, titulo = "Los Baldíos", ya = true, segundos = 8 })
  check(actual() and actual().estilo == "general", "no salió el primero")
  correr(1)
  -- El barco es más urgente: la zona se va y vuelve después.
  K.Anuncio({ estilo = "barco", titulo = "El barco a Trinquete ya viene", ya = true })
  check(actual() and actual().estilo == "barco", "el barco no pasó primero")
  local cola = K.AnuncioCola()
  check(#cola == 1 and cola[1].estilo == "general", "el primero no quedó esperando su turno")
  -- Un raro (menos urgente que el barco) espera; no lo tapa.
  K.Anuncio({ estilo = "raro", titulo = "Mor'Ladim", ya = true })
  check(actual().estilo == "barco", "el raro tapó al barco")
  cola = K.AnuncioCola()
  check(#cola == 2 and cola[1].estilo == "raro", "el raro no va antes que el primero en la cola")
  correr(9)
  RUN_TIMERS(1)
  check(actual() and actual().estilo == "raro", "después del barco no salió el raro")
  correr(10)
  RUN_TIMERS(1)
  local a = actual()
  check(a and a.estilo == "general" and a.vuelve, "el primero no volvió al final")
  limpiar()
  -- Una zona que esperó demasiado ya no vale: no sale tarde.
  K.Anuncio({ estilo = "barco", titulo = "El barco a Trinquete ya viene", ya = true, segundos = 8 })
  K.Anuncio({ estilo = "zona", titulo = "Los Baldíos", ya = true })
  correr(9)
  NOW = NOW + 10
  RUN_TIMERS(2)
  check(not anuncio():IsShown(), "una zona vencida salió tarde")
  limpiar()
end)

---------------------------------------------------------------------------
-- 3. Caducidad y sonido
---------------------------------------------------------------------------
step("Lo vencido caduca y el sonido suena al aparecer", function()
  limpiar()
  pelea(true)
  local sonidos = 0
  K.Anuncio({ estilo = "barco", titulo = "El barco que ya zarpó", caduca = NOW + 3, sonido = function() sonidos = sonidos + 1 end })
  check(not (anuncio() and anuncio():IsShown()), "salió en plena pelea")
  check(K.AnuncioEsperando(), "no quedó esperando")
  NOW = NOW + 10
  pelea(false)
  RUN_TIMERS(4)
  check(not (anuncio() and anuncio():IsShown()), "salió un barco que ya zarpó")
  check(sonidos == 0, "sonó un anuncio que no salió")
  -- Esperando al juego: el sonido, hasta que aparece.
  local zt = rawget(_G, "ZoneTextFrame")
  if not (type(zt) == "table" and type(zt.Show) == "function") then rawset(_G, "ZoneTextFrame", nil) zt = CreateFrame("Frame", "ZoneTextFrame", UIParent) end
  zt:Show() zt:SetAlpha(1)
  K.Anuncio({ estilo = "raro", titulo = "Thuros", sonido = function() sonidos = sonidos + 1 end })
  check(sonidos == 0, "el sonido sonó antes de que el anuncio apareciera")
  zt:Hide()
  RUN_TIMERS(3)
  check(actual() and actual().titulo == "Thuros", "el raro no salió cuando el juego terminó")
  check(sonidos == 1, "el sonido no sonó al aparecer (" .. sonidos .. ")")
  -- Se va por el juego y vuelve: no suena otra vez.
  correr(0.5)
  zt:Show()
  correr(1)
  zt:Hide()
  RUN_TIMERS(3)
  check(actual() and actual().vuelve, "no volvió después del juego")
  check(sonidos == 1, "sonó otra vez al volver")
  limpiar()
end)

---------------------------------------------------------------------------
-- 4. Los clics
---------------------------------------------------------------------------
step("Solo el título toma el ratón y el clic derecho lo cierra", function()
  limpiar()
  local clic = 0
  K.Anuncio({ estilo = "raro", titulo = "Rak'shiri", alClic = function() clic = clic + 1 end, pista = "Clic: ir de caza", ya = true })
  local a = actual()
  check(a and a.toca and not a.marcoToca, "la franja entera toma el ratón (o el título no)")
  local f = anuncio()
  FIRE(f.Toque, "OnClick", "LeftButton")
  check(clic == 1 and not f:IsShown(), "el clic en el título no hizo su acción")
  K.Anuncio({ estilo = "zona", titulo = "Durotar", ya = true })
  FIRE(f.Toque, "OnClick", "RightButton")
  check(not f:IsShown(), "el clic derecho no lo cerró")
  -- En pelea no toma el ratón.
  K.Anuncio({ estilo = "raro", titulo = "Rak'shiri", alClic = function() end, ya = true, enCombate = true })
  pelea(true)
  check(not f.Toque:IsMouseEnabled(), "en pelea el título sigue tomando el ratón")
  pelea(false)
  limpiar()
end)

---------------------------------------------------------------------------
-- 5. Una pelea
---------------------------------------------------------------------------
step("Si empieza una pelea se desvanece rápido y vuelve después", function()
  limpiar()
  K.Anuncio({ estilo = "descubrir", titulo = "El Cruce", ya = true, segundos = 6 })
  correr(1)
  pelea(true)
  correr(0.6)
  check(not anuncio():IsShown(), "siguió a la vista en plena pelea")
  check(K.AnuncioEsperando(), "no quedó para después")
  RUN_TIMERS(3)
  check(not anuncio():IsShown(), "volvió en plena pelea")
  pelea(false)
  RUN_TIMERS(3)
  check(actual() and actual().titulo == "El Cruce", "no volvió al terminar la pelea")
  limpiar()
end)

---------------------------------------------------------------------------
-- 6. Llegar a una zona
---------------------------------------------------------------------------
local zt = rawget(_G, "ZoneTextFrame")
local szt = rawget(_G, "SubZoneTextFrame")
if not (type(szt) == "table" and type(szt.Show) == "function") then rawset(_G, "SubZoneTextFrame", nil) szt = CreateFrame("Frame", "SubZoneTextFrame", UIParent) end
zt:Hide() szt:Hide()
local function llegar(zona, sub, ev)
  mundo.zona, mundo.sub = zona, sub or ""
  -- Como el juego: su nombre sale primero.
  if (ev or "ZONE_CHANGED_NEW_AREA") == "ZONE_CHANGED_NEW_AREA" then zt:Show() zt:SetAlpha(1) end
  if sub then szt:Show() szt:SetAlpha(1) end
  FIRE_EVENT(ev or "ZONE_CHANGED_NEW_AREA")
  RUN_TIMERS(3)
end

step("Al llegar a una zona: su nombre, su dueño y sus niveles; el del juego se esconde", function()
  limpiar()
  mundo.pvp = "hostile"
  llegar("Durotar", "Valle de los Retos")
  local a = actual()
  check(a and a.estilo == "zona" and a.titulo == "Durotar", "no salió el anuncio de la zona")
  check(a and a.color == "peligro", "una zona hostil no sale en rojo")
  check(a and a.texto and a.texto:find("Valle de los Retos", 1, true), "no dice el rincón donde estás")
  check(a and a.texto and a.texto:find("Niveles 1", 1, true), "no dice los niveles de la zona: " .. tostring(a and a.texto))
  check(not zt:IsShown() and not szt:IsShown(), "el nombre del juego siguió a la vista: salieron dos")
  correr(8)
  -- La misma zona antes de 10 minutos: nada de Alfa, y el del juego sí sale.
  llegar("Durotar")
  check(not (anuncio():IsShown()), "la misma zona se repitió antes de tiempo")
  check(zt:IsShown(), "sin anuncio de Alfa, el del juego no salió")
  zt:Hide()
  NOW = NOW + 601
  llegar("Durotar")
  check(actual() and actual().titulo == "Durotar", "pasados 10 minutos no volvió a salir")
  correr(8)
  -- Con «Alfa anuncia las zonas» apagado, el del juego vuelve y no hay dos.
  A.Set("anuncios.zona", false)
  llegar("Los Baldíos")
  check(zt:IsShown(), "con la opción apagada el nombre del juego no volvió")
  check(not anuncio():IsShown(), "con la opción apagada salió el de Alfa")
  zt:Hide()
  A.Set("anuncios.zona", nil)
  -- Pasado su momento, el juego vuelve a poder mostrarlo.
  NOW = NOW + 5
  zt:Show()
  check(zt:IsShown(), "el nombre del juego quedó roto")
  zt:Hide()
  mundo.pvp = "friendly"
  limpiar()
end)

step("Nada en grifo (sale al aterrizar) ni en combate", function()
  limpiar()
  mundo.taxi = true
  llegar("Mulgore")
  check(not anuncio():IsShown(), "salió en grifo")
  check(zt:IsShown(), "en grifo se escondió el del juego sin anunciar nada")
  zt:Hide()
  mundo.taxi = false
  FIRE_EVENT("PLAYER_CONTROL_GAINED")
  RUN_TIMERS(3)
  check(actual() and actual().titulo == "Mulgore", "al aterrizar no salió la zona a la que llegaste")
  correr(8)
  mundo.combate = true
  llegar("Los Baldíos")
  check(not anuncio():IsShown(), "salió en combate")
  mundo.combate = false
  zt:Hide()
  limpiar()
end)

---------------------------------------------------------------------------
-- 7. Rincones, descubrir, mazmorra, peligro, ciudad
---------------------------------------------------------------------------
step("Rincones: chicos, y 20 s entre uno y otro", function()
  limpiar()
  mundo.zona, mundo.sub = "Durotar", ""
  NOW = NOW + 30
  llegar("Durotar", "Aldea Razor", "ZONE_CHANGED")
  local a = actual()
  check(a and a.estilo == "subzona" and a.chico and a.titulo == "Aldea Razor", "el rincón no salió (chico)")
  check(not szt:IsShown(), "el nombre del rincón del juego siguió a la vista")
  correr(6)
  llegar("Durotar", "Sen'jin", "ZONE_CHANGED")
  check(not anuncio():IsShown(), "dos rincones seguidos, antes de 20 s")
  szt:Hide() zt:Hide()
  NOW = NOW + 25
  llegar("Durotar", "Sen'jin", "ZONE_CHANGED")
  check(actual() and actual().titulo == "Sen'jin", "pasados 20 s el otro rincón no salió")
  correr(6)
  -- Grande si lo pides.
  A.Set("anuncios.subzonaChica", false)
  NOW = NOW + 25
  llegar("Durotar", "Costa Tranquila", "ZONE_CHANGED")
  check(actual() and not actual().chico, "con «Rincones en chico» apagado siguió chico")
  A.Set("anuncios.subzonaChica", nil)
  szt:Hide() zt:Hide()
  limpiar()
end)

step("Descubrir: destello dorado, la experiencia y lo que sabe Lya", function()
  limpiar()
  rawset(_G, "ERR_ZONE_EXPLORED_XP", "Descubriste %s: %d de experiencia ganada")
  rawset(_G, "ERR_ZONE_EXPLORED", "Descubriste: %s")
  local Lya = rawget(_G, "AlfaLya")
  local dz = Lya and Lya.DatoDeZona
  if Lya then Lya.DatoDeZona = function() return "Aquí aullaban los lobos de antes." end end
  mundo.sub = "Fuerte Garra"
  FIRE_EVENT("CHAT_MSG_SYSTEM", "Descubriste Fuerte Garra: 120 de experiencia ganada")
  FIRE_EVENT("UI_INFO_MESSAGE", 0, "Descubriste Fuerte Garra: 120 de experiencia ganada")
  RUN_TIMERS(2)
  local a = actual()
  check(a and a.estilo == "descubrir" and a.titulo == "Fuerte Garra", "no salió el anuncio de descubrir")
  check(a and a.texto and a.texto:find("+120", 1, true), "no dice la experiencia ganada")
  if Lya then check(a and a.texto and a.texto:find("lobos de antes", 1, true), "Lya no contó nada de la zona") end
  check(#K.AnuncioCola() == 0, "el juego lo dijo dos veces y salieron dos")
  -- El rincón que descubriste no sale aparte.
  FIRE_EVENT("ZONE_CHANGED")
  RUN_TIMERS(3)
  check(#K.AnuncioCola() == 0, "el rincón descubierto salió además")
  -- Lya lo cuenta una vez por zona.
  correr(10)
  FIRE_EVENT("CHAT_MSG_SYSTEM", "Descubriste: Cañón Ventoso")
  RUN_TIMERS(2)
  a = actual()
  check(a and a.titulo == "Cañón Ventoso" and not (a.texto or ""):find("lobos", 1, true), "Lya repitió su dato en la misma zona")
  if Lya then Lya.DatoDeZona = dz end
  limpiar()
end)

step("Mazmorra: morada, con niveles y jefes, una vez cada 30 min", function()
  limpiar()
  AlfaNucleoDB = AlfaNucleoDB or {}
  AlfaNucleoDB.mazmorras = AlfaNucleoDB.mazmorras or {}
  AlfaNucleoDB.mazmorras.entradas = AlfaNucleoDB.mazmorras.entradas or {}
  AlfaNucleoDB.mazmorras.entradas.sima = { nombre = "Sima Ígnea", min = 13, max = 18, jefes = 5 }
  mundo.inst, mundo.instTipo = true, "party"
  local gi = GetInstanceInfo
  GetInstanceInfo = function() return "Sima Ígnea", "party", 1, "Normal", 5, 0, false, 389 end
  llegar("Sima Ígnea")
  local a = actual()
  check(a and a.estilo == "mazmorra" and a.titulo == "Sima Ígnea", "no salió el anuncio de la mazmorra")
  check(a and a.texto and a.texto:find("13", 1, true) and a.texto:find("5 jefes", 1, true), "no dice sus niveles y jefes: " .. tostring(a and a.texto))
  correr(9)
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  RUN_TIMERS(3)
  check(not anuncio():IsShown(), "la misma mazmorra se anunció antes de 30 minutos")
  GetInstanceInfo = gi
  mundo.inst, mundo.instTipo = false, "none"
  zt:Hide() szt:Hide()
  limpiar()
end)

step("Zona peligrosa para tu nivel: en rojo", function()
  limpiar()
  nivelesZona[1411] = { 30, 40 }
  mundo.nivel = 12
  llegar("Durotar")
  local a = actual()
  check(a and a.estilo == "peligro" and a.color == "peligro", "una zona de nivel 30 a nivel 12 no salió como peligrosa")
  check(a and a.texto and a.texto:find("Zona de nivel 30", 1, true), "no dice «Zona de nivel 30–40: ve con cuidado»")
  nivelesZona[1411] = { 1, 10 }
  mundo.nivel = 23
  zt:Hide() szt:Hide()
  limpiar()
end)

step("Ciudad o posada: azul y tranquila", function()
  limpiar()
  mundo.resting = true
  llegar("Orgrimmar")
  local a = actual()
  check(a and a.estilo == "ciudad", "llegar a donde descansas no salió como ciudad")
  correr(9)
  -- La posada: descansas sin cambiar de zona.
  mundo.sub = "Posada de Razor"
  NOW = NOW + 10
  FIRE_EVENT("PLAYER_UPDATE_RESTING")
  RUN_TIMERS(2)
  check(actual() and actual().estilo == "ciudad" and actual().titulo == "Posada de Razor", "la posada no se anunció")
  mundo.resting = false
  zt:Hide() szt:Hide()
  limpiar()
end)

---------------------------------------------------------------------------
-- 8. La placa de llegada y la pantalla
---------------------------------------------------------------------------
step("La placa de llegada primero; la zona después y debajo", function()
  limpiar()
  local Ar = A.Nav and A.Nav.arrow
  check(Ar and Ar.PlacaMarco, "la flecha no dice si su placa se ve")
  if not Ar then return end
  local real = Ar.PlacaMarco
  local p = CreateFrame("Frame", nil, UIParent)
  p:SetSize(264, 80) p:SetPoint("TOP", UIParent, "TOP", 0, -140) p:Show()
  Ar.PlacaMarco = function() return p end
  K.Anuncio({ estilo = "zona", titulo = "Mulgore" })
  check(not anuncio():IsShown(), "la zona salió encima de la placa de llegada")
  RUN_TIMERS(6)
  local a = actual()
  check(a and a.titulo == "Mulgore" and a.bajoPlaca, "la zona no salió debajo de la placa que se quedó")
  local _, rel = anuncio():GetPoint(1)
  check(rel == p, "la zona no quedó anclada debajo de la placa")
  -- Un barco no espera a la placa.
  limpiar()
  K.Anuncio({ estilo = "barco", titulo = "El barco a Trinquete ya viene" })
  check(actual() ~= nil, "el barco esperó a la placa")
  Ar.PlacaMarco = real
  limpiar()
end)

step("El ancho se adapta a la pantalla", function()
  limpiar()
  rawset(UIParent, "GetWidth", function() return 800 end)
  K.Anuncio({ estilo = "zona", titulo = "Las Tierras Altas de Arathi y un nombre muy largo que no cabe", ya = true })
  local a = actual()
  check(a and a.ancho <= 800 * 0.62 + 1, "el anuncio no se angostó con la pantalla chica (" .. tostring(a and a.ancho) .. ")")
  local f = anuncio()
  check(K.AnchoTexto(f.Titulo) <= a.ancho or f.Titulo:GetNumLines() <= 2, "el nombre largo se salió de su caja")
  check(a.rolTitulo ~= "anuncio", "el nombre largo no bajó de tamaño")
  rawset(UIParent, "GetWidth", nil)
  limpiar()
end)

---------------------------------------------------------------------------
-- 9. Barcos y raros
---------------------------------------------------------------------------
step("Barco con menos de 10 s: compacto y ya", function()
  limpiar()
  zt:Show() zt:SetAlpha(1)
  ns.Nav.alerts.Anuncio("El barco a Trinquete ya viene", "Prepárate: llega en %s", 7, "boat")
  local a = actual()
  check(a and a.estilo == "barco" and a.chico, "con 7 s el barco no salió compacto y ya")
  zt:Hide()
  limpiar()
  ns.Nav.alerts.Anuncio("El zepelín a Entrañas ya viene", "Prepárate: llega en %s", 30, "zeppelin")
  check(actual() and actual().estilo == "zepelin" and not actual().chico, "el zepelín no salió con su estilo")
  limpiar()
  ns.Nav.alerts.Anuncio("El tranvía a Forjaz ya viene", "Prepárate: llega en %s", 30, "tram")
  check(actual() and actual().estilo == "tranvia", "el tranvía no salió con su estilo")
  limpiar()
end)

step("Raro en plena pelea: ícono chico ya y el grande después si sigue ahí", function()
  limpiar()
  local Rr = ns.Rares
  local cerca = { "Thuros" }
  local nb = Rr.Nearby
  Rr.Nearby = function() return cerca end
  pelea(true)
  Rr.Toast.Show({ kind = "rare", id = 61, name = "Thuros", level = 29, zone = "Bosque de Elwynn", map = 1429, x = 50, y = 50, yards = 85 })
  check(K.AnuncioChicoVisible(), "en plena pelea no salió el ícono chico")
  check(not anuncio():IsShown(), "el anuncio grande salió en plena pelea")
  pelea(false)
  RUN_TIMERS(3)
  check(actual() and actual().estilo == "raro" and actual().titulo == "Thuros", "después de la pelea no salió el grande")
  limpiar()
  -- Si ya no está, no sale tarde.
  pelea(true)
  Rr.Toast.Show({ kind = "rare", id = 61, name = "Thuros", level = 29, zone = "Bosque de Elwynn", map = 1429, x = 50, y = 50, yards = 85 })
  cerca = {}
  NOW = NOW + 6
  pelea(false)
  RUN_TIMERS(3)
  check(not anuncio():IsShown(), "salió un raro que ya no estaba")
  Rr.Nearby = nb
  -- Un tesoro y el fundador, con su estilo.
  limpiar()
  Rr.Toast.Show({ kind = "treasure", id = 9, name = "Cofre", zone = "Durotar" })
  check(actual() and actual().estilo == "tesoro", "el tesoro no salió con su estilo")
  limpiar()
end)

---------------------------------------------------------------------------
-- 10. Ajustes
---------------------------------------------------------------------------
step("Ajustes: un interruptor y «Probar» por tipo", function()
  limpiar()
  check(type(N.GrupoAnuncios) == "function", "no está el grupo de los anuncios")
  for _, tipo in ipairs(K.ORDEN_ANUNCIOS) do
    limpiar()
    Z.Probar(tipo)
    local a = actual()
    check(a and a.estilo == tipo, "«Probar» de " .. tipo .. " no sacó su anuncio")
  end
  -- Apagado un tipo, el barco vuelve a la tarjeta de antes.
  limpiar()
  A.Set("anuncios.barco", false)
  ns.Nav.alerts.ShowSample()
  check(not anuncio():IsShown(), "con «Barcos» apagado salió el anuncio")
  A.Set("anuncios.barco", nil)
  local g = N.GrupoAnuncios(UIParent)
  check(g and #g.filas == #Z.FILAS, "faltan filas en Ajustes")
  limpiar()
end)

if A.Maps then A.Maps.GetZoneLevels = mapsReal end
print("pasos:", pasos, "errores:", #ERRORS)
