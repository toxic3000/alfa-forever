-- Prueba de la 1.3.8, los avisos (pedidos de Toxic):
--   1. el mensaje del barco en la flecha, a la manera de Alfa: sin «espera
--      promedio» ni coordenadas sueltas, con cuenta real, el siguiente y
--      «Llegas en»; lo mismo para zepelín, tranvía, portal y vuelo; el
--      horario del siguiente en el mapa (Barcos.lua);
--   2. los mensajes, únicos: cada suceso (llegar en barco, llegar a una zona,
--      zona peligrosa, subir de nivel, terminar una misión, un raro cerca,
--      llegar en grifo) cuenta lo que sale por cada canal (avisos, anuncios,
--      Lya, el chat, la tarjeta del motor) y falla si dos dicen lo mismo;
--      N.Suceso / N.YaSeVio entre avisos, anuncios, Lya y el chat;
--   3. los anuncios de zona: el nombre del juego se esconde desde el cambio
--      de zona (grifo, pantalla de carga) y nunca sale a la par; más cine
--      (polvo, brillo, profundidad, salida) y un sonido distinto por tipo;
--   4. la firma de cada módulo (color, ícono y sonido corto);
--   5. avisos parecidos que llegan juntos se agrupan (y las misiones listas
--      en el chat, en una sola línea);
--   6. «La última vez…» en Hoy, no como aviso.
-- Con BANCO_FOTOS=1 dibuja las capturas (tools/banco/shot-138-*.png).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["138-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.3.8 avisos", msg) end end

BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N, B = AlfaNucleo, AlfaBienvenida
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end

local A = Alfa
local K = N.Kit
local Z = N.Zonas
local ns = NS_OF("Alfa")
local Nav = ns.Nav
local Ly = NS_OF("Alfa_Lya")
A.Set("bienvenida.anuncios", true)
if N.Entrando then N.Entrando = function() return false end end
if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end

-- El mundo de mentira.
local mundo = { zona = "Los Humedales", sub = "Puerto de Menethil", pvp = "friendly", taxi = false, combate = false,
  resting = false, inst = false, instTipo = "none", nivel = 40 }
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
-- Cada zona con su mapa y sus niveles (como los da el motor).
local MAPAS = { ["Los Humedales"] = { 1437, 20, 30 }, ["Marjal Revolcafango"] = { 1445, 35, 45 }, ["Desolace"] = { 1443, 30, 39 },
  ["Durotar"] = { 1411, 1, 10 } }
C_Map = C_Map or {}
C_Map.GetBestMapForUnit = function() local m = MAPAS[mundo.zona] return m and m[1] or 1411 end
if A.Maps then
  A.Maps.GetZoneLevels = function(id)
    for _, m in pairs(MAPAS) do if m[1] == id then return m[2], m[3] end end
    return nil
  end
end
-- Lya a la vista (como en el juego): los avisos chicos los dice ella.
local Ce = Ly.Cerebro
local lyaVisible = true
if Ly.UI then Ly.UI.Visible = function() return lyaVisible end end
if Ce then Ce.Activa = function() return lyaVisible end end

-- El nombre que pone el juego arriba (ZoneTextFrame / SubZoneTextFrame).
local function marcoJuego(nombre)
  local g = rawget(_G, nombre)
  if not (type(g) == "table" and type(g.Show) == "function") then rawset(_G, nombre, nil) g = CreateFrame("Frame", nombre, UIParent) end
  return g
end
local zt, szt = marcoJuego("ZoneTextFrame"), marcoJuego("SubZoneTextFrame")
zt:Hide() szt:Hide()
-- El juego saca su nombre al cambiar de zona (después de los addons, como pasa a veces).
local function juegoNombre() zt:Show() zt:SetAlpha(1) end

---------------------------------------------------------------------------
-- Todo lo que sale, por canal
---------------------------------------------------------------------------
local salidas = {}
local function limpio(t)
  t = tostring(t or "")
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("\n", " ")
  return t
end
local function anotar(canal, texto)
  texto = limpio(texto)
  if texto == "" or texto == " |  | " then return end
  salidas[#salidas + 1] = { canal = canal, texto = texto, t = NOW }
end
A.On("ALFA_AVISO", function(o) if type(o) == "table" then anotar("aviso", (o.titulo or "") .. " | " .. (o.texto or "")) end end)
do
  local h = Ly.UI and Ly.UI.Hablar
  if h then Ly.UI.Hablar = function(c, ...) if type(c) == "table" then anotar("lya", c.texto) end return h(c, ...) end end
  local cf = DEFAULT_CHAT_FRAME
  local am = cf.AddMessage
  cf.AddMessage = function(self, m, ...) anotar("chat", m) return am(self, m, ...) end
end
local ultimoAnuncio
local juegoA = false
local function mirarAnuncio()
  local a = K.AnuncioActual()
  local fa = rawget(_G, "AlfaAnuncio")
  -- (la cuenta del barco se escribe en la línea de abajo: se lee de ahí)
  local abajo = a and (a.texto or (fa and fa.Texto and fa.Texto:GetText()) or "") or ""
  local clave = a and ((a.sobre or "") .. " | " .. (a.titulo or "") .. " | " .. abajo:gsub("%d+:%d+", "")) or nil
  if clave and clave ~= ultimoAnuncio and not a.vuelve then anotar("anuncio", clave) end
  ultimoAnuncio = clave
  local al = rawget(_G, "AlfaAlert")
  if al and al:IsShown() and not al.alfaAnotado then
    al.alfaAnotado = true
    anotar("tarjeta", (al.Title and al.Title:GetText() or "") .. " | " .. (al.When and al.When:GetText() or ""))
  elseif al and not al:IsShown() then al.alfaAnotado = nil end
  -- El nombre del juego y el de Alfa nunca a la par.
  local f = rawget(_G, "AlfaAnuncio")
  if f and f:IsShown() and zt:IsShown() and (zt:GetAlpha() or 1) > 0.05 then juegoA = true end
end
local function anuncio() return rawget(_G, "AlfaAnuncio") end
local function correr(seg, dt)
  dt = dt or 0.1
  local t, n = 0, 0
  while t < seg do
    NOW = NOW + dt
    local f = anuncio()
    if f and f:IsShown() then FIRE(f, "OnUpdate", dt) end
    mirarAnuncio()
    t = t + dt
    n = n + 1
    if n % 10 == 0 then RUN_TIMERS(1) mirarAnuncio() end
  end
end
local function limpiar()
  K.QuitarAnuncio()
  NOW = NOW + 700
  if Z.Olvidar then Z.Olvidar() end
  if N.OlvidarSucesos then N.OlvidarSucesos() end
  RUN_TIMERS(3)
  salidas = {}
  ultimoAnuncio = nil
  juegoA = false
  zt:Hide() szt:Hide()
end

-- Las palabras que cuentan (sin artículos ni signos), para saber si dos
-- mensajes dicen lo mismo.
local VACIAS = { el = true, la = true, los = true, las = true, a = true, en = true, de = true, del = true, y = true,
  un = true, una = true, al = true, tu = true, te = true, se = true, ya = true, que = true, son = true, aqui = true }
local function palabras(t)
  local out = {}
  t = t:lower():gsub("\226\128[\147\148]", "-"):gsub("[%p¡¿«»·]", " ")
  for p in t:gmatch("%S+") do
    if not VACIAS[p] and #p > 2 then out[p] = true end
  end
  return out
end
local function parecidos(a, b)
  if a == b then return true end
  local pa, pb = palabras(a), palabras(b)
  local na, nb, comun = 0, 0, 0
  for p in pairs(pa) do na = na + 1 if pb[p] then comun = comun + 1 end end
  for _ in pairs(pb) do nb = nb + 1 end
  local menor = math.min(na, nb)
  return menor >= 3 and comun / menor >= 0.6
end
SUCESOS = {}
local function revisarSuceso(nombre, maximo, minimo)
  print(("SUCESO %s: %d mensajes"):format(nombre, #salidas))
  for _, s in ipairs(salidas) do print(("   [%s] %s"):format(s.canal, s.texto)) end
  SUCESOS[nombre] = #salidas
  for i = 1, #salidas do
    for j = i + 1, #salidas do
      if parecidos(salidas[i].texto, salidas[j].texto) then
        check(false, nombre .. ": dos mensajes dicen lo mismo: «" .. salidas[i].texto .. "» (" .. salidas[i].canal
          .. ") y «" .. salidas[j].texto .. "» (" .. salidas[j].canal .. ")")
      end
    end
  end
  if maximo then check(#salidas <= maximo, nombre .. ": salen demasiados mensajes (" .. #salidas .. ")") end
  if minimo then check(#salidas >= minimo, nombre .. ": no salió nada (" .. #salidas .. ")") end
  check(not juegoA, nombre .. ": el nombre del juego y el de Alfa salieron a la par")
end
local function hay(canal, patron)
  for _, s in ipairs(salidas) do if (not canal or s.canal == canal) and s.texto:find(patron) then return s end end
  return nil
end

---------------------------------------------------------------------------
-- 1. El mensaje del barco en la flecha
---------------------------------------------------------------------------
local X = ns.Transit
local Ar = Nav.arrow
local horario = { medido = false, llega = nil, sale = nil, espera = 175, viaje = 300, siguiente = 840, abordo = false }
local real = { NextArrival = X.NextArrival, NextDeparture = X.NextDeparture, Riding = X.Riding, Now = X.Now }
local function conHorario()
  X.Now = function() return NOW end
  X.NextArrival = function(_, _, now)
    if not horario.medido then return nil end
    return horario.llega, horario.sale, true
  end
  X.NextDeparture = function(_, _, now)
    if not horario.medido then return horario.espera, horario.viaje, false end
    if now and now > NOW + 3 then return horario.siguiente, horario.viaje, true end
    return horario.sale or horario.espera, horario.viaje, true
  end
  X.Riding = function() if horario.abordo then return { kind = "boat", route = "r1", dock = "Isla Theramore", arriveIn = 60 } end return nil end
end
local function sinHorario() for k, v in pairs(real) do X[k] = v end end
local muelle = { name = "Isla Theramore", c = 0, wx = 1, wy = 1, map = 1445, x = 0.6, y = 0.4 }
local function tramo(kind)
  return { kind = kind, label = "Take the boat to Theramore Isle", to = muelle, from = { c = 0, wx = 0, wy = 0 },
    transport = kind ~= "fly" and kind ~= "portal" and { id = "theramore" } or nil, side = "a", seconds = 300, rest = 800 }
end

step("La flecha: el barco a la manera de Alfa", function()
  conHorario()
  check(type(Ar.TextoViaje) == "function", "falta Arrow.TextoViaje")
  -- Sin horario medido: «sale en ~3 min», sin «espera promedio», con «Llegas en».
  local l1, l2, l3 = Ar.TextoViaje(tramo("boat"), 1135)
  print("FLECHA sin medir:", l1, "/", l2, "/", l3)
  check(l1 and l1:find("Toma el barco a Isla Theramore", 1, true), "no dice a dónde va el barco: " .. tostring(l1))
  check(l1 and l1:find("sale en ~3 min", 1, true), "sin horario no dice «sale en ~3 min»: " .. tostring(l1))
  check(l3 == "Llegas en 19 min", "no dice «Llegas en 19 min»: " .. tostring(l3))
  check(l2 and l2:find("aproximada", 1, true), "sin horario no dice que es aproximado: " .. tostring(l2))
  for _, t in ipairs({ l1 or "", l2 or "", l3 or "" }) do
    check(not t:find("promedio") and not t:find("average"), "aún dice «espera promedio»: " .. t)
    check(not t:find("%d+%.%d+, %d+%.%d+"), "hay coordenadas sueltas: " .. t)
  end
  -- Con horario medido: cuenta al segundo y el siguiente.
  horario.medido, horario.llega, horario.sale = true, 60, 80
  l1, l2 = Ar.TextoViaje(tramo("boat"), 1135)
  print("FLECHA medido:", l1, "/", l2)
  check(l1 and l1:find("sale en 1:20", 1, true), "con horario no cuenta al segundo: " .. tostring(l1))
  check(l2 and l2:find("el siguiente sale en 15 min", 1, true), "no dice el horario del siguiente: " .. tostring(l2))
  -- Atracado.
  horario.llega, horario.sale = 0, 40
  l1 = Ar.TextoViaje(tramo("boat"), 600)
  check(l1 and l1:find("ya está en el muelle! Sale en 0:40", 1, true), "atracado no dice que ya está: " .. tostring(l1))
  -- A bordo.
  horario.abordo = true
  l1 = Ar.TextoViaje(tramo("boat"), 300)
  check(l1 == "En el barco a Isla Theramore", "a bordo no dice «En el barco a…»: " .. tostring(l1))
  horario.abordo = false
  -- Zepelín, tranvía, portal y vuelo.
  horario.medido = false
  for kind, esp in pairs({ zeppelin = "Toma el zepelín a", tram = "Toma el tranvía a", portal = "Cruza el portal a", fly = "Vuela a" }) do
    local a, b, c = Ar.TextoViaje(tramo(kind), 400)
    check(a and a:find(esp, 1, true), kind .. ": no dice «" .. esp .. "»: " .. tostring(a))
    check(c == "Llegas en 7 min", kind .. ": no dice cuándo llegas: " .. tostring(c))
    if kind == "fly" then check(b == "Habla con el maestro de vuelo", "el vuelo no dice con quién hablar") end
  end
end)

step("La flecha sobre el muelle (la captura)", function()
  conHorario()
  horario.medido, horario.llega, horario.sale = true, 95, 118
  local f = Ar.frame
  local leg = tramo("boat")
  local T = Nav.travel
  local guarda = {}
  for _, k in ipairs({ "Active", "CurrentLeg", "CurrentLabel", "Remaining" }) do guarda[k] = T[k] end
  local gNav = { Sample = Nav.Sample, GetTarget = Nav.GetTarget, HiddenWithGuide = Nav.HiddenWithGuide,
    TomTomArrowGuides = Nav.TomTomArrowGuides, HandedOff = Nav.HandedOff, IsHiddenState = Nav.IsHiddenState }
  T.Active = function() return true end
  T.CurrentLeg = function() return leg end
  T.CurrentLabel = function() return "Toma el barco a Isla Theramore\nBarco: espera promedio 2:55" end
  T.Remaining = function() return 1135 end
  Nav.Sample = function() return "instruction", 0 end
  Nav.GetTarget = function() return { label = "Ve a 23.8, 77.3", map = 1445, x = 0.238, y = 0.773 } end
  Nav.HiddenWithGuide = function() return false end
  Nav.TomTomArrowGuides = function() return false end
  Nav.HandedOff = function() return false end
  Nav.IsHiddenState = function() return false end
  A.Set("nav.arrow", true)
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:Show()
  for _ = 1, 8 do NOW = NOW + 0.3 FIRE(f, "OnUpdate", 0.3) end
  local v = Ar.Viaje and Ar.Viaje()
  check(v and v.linea and v.linea:find("Toma el barco a Isla Theramore", 1, true), "la flecha no pintó el viaje")
  check(not Ar.labelText:GetText():find("23.8", 1, true), "la flecha sigue con las coordenadas: " .. tostring(Ar.labelText:GetText()))
  check(not Ar.distText:GetText():find("promedio", 1, true), "la flecha sigue con «espera promedio»")
  print("FLECHA:", Ar.distText:GetText(), "/", Ar.labelText:GetText(), "/", Ar.etaText:GetText())
  if FOTOS then
    local fondo = CreateFrame("Frame", nil, UIParent)
    fondo:SetFrameStrata("BACKGROUND")
    fondo:SetPoint("TOPLEFT", f, "TOPLEFT", -70, 20)
    fondo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 70, -30)
    local c = fondo:CreateTexture(nil, "BACKGROUND")
    c:SetAllPoints(fondo)
    c:SetTexture("white")
    c:SetGradient("VERTICAL", CreateColor(0.03, 0.05, 0.07, 1), CreateColor(0.1, 0.13, 0.17, 1))
    fondo:Show()
    SNAP("flecha-barco", fondo, { f })
    fondo:Hide()
  end
  f:Hide()
  for k, fn in pairs(guarda) do T[k] = fn end
  for k, fn in pairs(gNav) do Nav[k] = fn end
  sinHorario()
end)

step("El mapa: el horario del siguiente barco", function()
  local Rt = NS_OF("Alfa_Rutas")
  local Bc = Rt.Barcos
  check(Bc and Bc.Lista, "falta Barcos.Lista")
  if not (Bc and Bc.Lista and Nav.GetTravelData) then return end
  conHorario()
  horario.medido, horario.llega, horario.sale = true, 60, 80
  local gd = Nav.GetTravelData
  Nav.GetTravelData = function() return { transports = { { id = "theramore", kind = "boat", faction = 3,
    a = { name = "Puerto de Menethil", map = 1437, x = 0.5, y = 0.5 }, b = { name = "Isla Theramore", map = 1445, x = 0.6, y = 0.4 } } } } end
  local l = Bc.Lista()
  check(l[1] and l[1].siguiente and l[1].siguiente:find("15 min", 1, true), "el muelle no dice cuándo sale el siguiente: " .. tostring(l[1] and l[1].siguiente))
  Nav.GetTravelData = gd
  sinHorario()
end)

---------------------------------------------------------------------------
-- 2. Un mensaje por suceso
---------------------------------------------------------------------------
step("Llegar en barco: un mensaje de cada cosa", function()
  limpiar()
  mundo.nivel = 40
  local riding = X.Riding
  local llega = NOW + 19
  X.Riding = function() local r = llega - NOW if r <= 0 then return nil end return { kind = "boat", route = "r-theramore", dock = "Isla Theramore", arriveIn = r } end
  local gs = ns.GuideShown
  ns.GuideShown = function() return true end
  Nav.alerts.Check()
  correr(20)
  X.Riding = riding
  -- Bajas del barco: otra zona, otro rincón; el juego saca su nombre.
  mundo.zona, mundo.sub = "Marjal Revolcafango", "Isla Theramore"
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  juegoNombre()
  check(not zt:IsShown(), "al llegar en barco salió el nombre del juego (Alfa lo va a decir)")
  FIRE_EVENT("ZONE_CHANGED")
  correr(40)
  ns.GuideShown = gs
  revisarSuceso("llegar en barco", 4, 2)
  check(hay("anuncio", "Tierra a la vista"), "a bordo no dijo «¡Tierra a la vista!»")
  local z = hay("anuncio", "Marjal Revolcafango")
  check(z and z.texto:find("La manada desembarca", 1, true), "la zona no dice que la manada desembarca")
  check(z and not z.texto:find("Isla Theramore", 1, true), "la zona repite el muelle que ya dijo el barco")
end)

step("Llegar a una zona peligrosa: un solo aviso, con su salida", function()
  limpiar()
  local llevo = 0
  local salida = N.SalidaPeligro
  N.SalidaPeligro = function() llevo = llevo + 1 end
  mundo.zona, mundo.sub, mundo.nivel = "Desolace", "", 20
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  juegoNombre()
  correr(30)
  revisarSuceso("zona peligrosa", 3, 1)
  local a = hay("anuncio", "Zona peligrosa")
  check(a, "no salió el anuncio de zona peligrosa")
  check(not hay("lya", "Cuidado") and not hay("aviso", "Cuidado"), "Rutas también avisó de la zona peligrosa")
  N.SalidaPeligro = salida
  mundo.nivel = 40
end)

step("Llegar en grifo: el del juego en vuelo, el de Alfa al aterrizar", function()
  limpiar()
  mundo.taxi = true
  mundo.zona, mundo.sub = "Los Humedales", ""
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  correr(5)
  mundo.taxi = false
  zt:Hide()
  mundo.sub = "Puerto de Menethil"
  FIRE_EVENT("PLAYER_CONTROL_GAINED")
  juegoNombre()
  check(not zt:IsShown(), "al aterrizar salió el nombre del juego encima del de Alfa")
  FIRE_EVENT("ZONE_CHANGED")
  correr(30)
  revisarSuceso("llegar en grifo", 3, 1)
  check(hay("anuncio", "Aterrizas en"), "al aterrizar no dice «Aterrizas en»")
end)

step("Una pantalla de carga (portal, piedra): el nombre del juego no sale", function()
  limpiar()
  mundo.zona, mundo.sub = "Durotar", ""
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  juegoNombre()
  check(not zt:IsShown(), "tras la pantalla de carga salió el nombre del juego (Alfa lo va a decir)")
  correr(30)
  revisarSuceso("pantalla de carga", 3, 1)
  -- Con /reload: nada (ya sabes dónde estás).
  limpiar()
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
  juegoNombre()
  check(zt:IsShown(), "con /reload se escondió el nombre del juego sin que Alfa anuncie")
  correr(10)
  check(not hay("anuncio", "Durotar"), "con /reload salió el anuncio de zona")
end)

step("Subir de nivel", function()
  limpiar()
  mundo.nivel = 41
  FIRE_EVENT("PLAYER_LEVEL_UP", 41, 0, 0, 0, 0, 0, 0, 0, 0)
  correr(40)
  revisarSuceso("subir de nivel")
end)

step("Terminar una misión", function()
  limpiar()
  FIRE_EVENT("QUEST_TURNED_IN", 1234, 800, 500)
  correr(20)
  revisarSuceso("terminar misión")
end)

step("Un raro cerca", function()
  limpiar()
  ns.Fire("RARE_SPOTTED", { name = "Mor'Ladim", kind = "rare", id = 522, level = 35 })
  correr(20)
  revisarSuceso("raro cerca", 3, 1)
end)

step("Una voz: el aviso, el anuncio, Lya y el chat no se repiten", function()
  limpiar()
  lyaVisible = false
  local a1 = K.Aviso({ titulo = "Tus bolsas están llenas", texto = "Vende lo gris.", icono = "ic-bolsas", lya = false })
  check(type(a1) == "table", "no salió el primer aviso")
  check(K.Aviso({ titulo = "Tus bolsas están llenas", texto = "Vende lo gris.", icono = "ic-bolsas", lya = false }) == false,
    "el mismo aviso salió dos veces seguidas")
  -- Lya no repite lo que acaba de salir en un aviso.
  lyaVisible = true
  local dijo, por = Ce.Decir({ texto = "Tus bolsas están llenas. Vende lo gris." })
  check(dijo == false and por == "repetido", "Lya repitió lo que acaba de salir en un aviso")
  -- El chat tampoco.
  local antes = #salidas
  N.Imprimir("Tus bolsas están llenas. Vende lo gris.")
  check(#salidas == antes, "el chat repitió lo que acaba de salir en un aviso")
  -- El mismo suceso por dos lados: el primero gana.
  check(N.Suceso("prueba:barco") == true, "el primer suceso no pasó")
  check(K.Aviso({ titulo = "El barco ya viene", suceso = "prueba:barco", lya = false }) == false, "un suceso ya dicho salió otra vez")
  check(K.Anuncio({ titulo = "El barco ya viene otra vez", estilo = "barco", suceso = "prueba:barco", ya = true }) == true
    and not (K.AnuncioActual() and K.AnuncioActual().titulo == "El barco ya viene otra vez"), "un anuncio de un suceso ya dicho salió")
  -- Pasado su rato, vuelve a valer.
  NOW = NOW + 120
  check(type(K.Aviso({ titulo = "Tus bolsas están llenas", texto = "Vende lo gris.", icono = "ic-bolsas", lya = false })) == "table",
    "un aviso de hace dos minutos ya no puede volver a salir")
  -- Lo que pides tú siempre sale.
  check(type(K.Aviso({ titulo = "Tus bolsas están llenas", texto = "Vende lo gris.", pedido = true, lya = false })) == "table",
    "lo que pediste no salió por repetido")
end)

step("Los avisos no se empalman con el anuncio grande", function()
  limpiar()
  lyaVisible = false
  K.Anuncio({ estilo = "zona", titulo = "Los Baldíos", sobre = "Tierra amiga", texto = "Niveles 10–25", ya = true })
  local a = K.Aviso({ titulo = "Un aviso mientras se ve el anuncio", lya = false })
  check(type(a) == "table", "no salió el aviso")
  check(K.AvisosBajoAnuncio and K.AvisosBajoAnuncio(), "el aviso no se acomodó debajo del anuncio")
  local f = anuncio()
  if type(a) == "table" and f then
    check(a:GetTop() <= f:GetBottom() + 1, "el aviso tapa al anuncio")
  end
  correr(12)
  check(not (K.AvisosBajoAnuncio and K.AvisosBajoAnuncio()), "al irse el anuncio los avisos no volvieron a su lugar")
  if type(a) == "table" then a:Cerrar() end
end)

---------------------------------------------------------------------------
-- 3. Los anuncios, más cine
---------------------------------------------------------------------------
local fotos = { zona = { "Los Baldíos", "Tierra amiga", "El Cruce  ·  Niveles 10–25" },
  descubrir = { "Cascada del Lamento", "¡Descubriste un lugar nuevo!", "+120 de experiencia" },
  mazmorra = { "Cuevas de los Lamentos", "Entras a una mazmorra", "Niveles 17–24  ·  5 jefes" },
  peligro = { "Desolace", "Zona peligrosa", "Zona de nivel 30–39: ve con cuidado" },
  ciudad = { "Orgrimmar", "Un lugar para descansar", "Descansas aquí: tu experiencia de descanso se llena." },
  barco = { "Isla Theramore", "La manada viaja", "¡Tierra a la vista! Llegas en 0:19" },
  raro = { "Mor'Ladim", "Lya olfateó un raro", "Nivel 35 Raro  ·  120 m" },
  zepelin = { "Entrañas", "La manada viaja", "Prepárate: llega en 0:30" },
}
step("Los anuncios: polvo, brillo, profundidad y salida", function()
  local sonidos = {}
  for nombre, est in pairs(K.ESTILOS_ANUNCIO) do
    if est.sonido then
      check(not sonidos[est.sonido], "dos tipos de anuncio con el mismo sonido: " .. nombre .. " y " .. tostring(sonidos[est.sonido]))
      sonidos[est.sonido] = nombre
    end
  end
  for estilo, d in pairs(fotos) do
    limpiar()
    K.Anuncio({ estilo = estilo, titulo = d[1], sobre = d[2], texto = d[3], ya = true, segundos = 6, clave = "probar" })
    local f = anuncio()
    check(f and f:IsShown(), estilo .. ": no salió")
    if f and f:IsShown() then
      -- Entra con profundidad: el halo llega grande.
      FIRE(f, "OnUpdate", 0.05)
      local h0 = f.Halo:GetWidth()
      local polvo, brillo, maxY = 0, false, 0
      local t = 0
      while t < 1.6 do
        NOW = NOW + 0.05 t = t + 0.05
        FIRE(f, "OnUpdate", 0.05)
        if f.BrilloI:IsShown() then brillo = true end
      end
      for _, p in ipairs(f.Polvo) do if p:IsShown() and (p:GetAlpha() or 0) > 0.05 then polvo = polvo + 1 end end
      local h1 = f.Halo:GetWidth()
      local quieto = { destello = true, aulla = true, gira = true }
      if not quieto[K.ESTILOS_ANUNCIO[estilo].anim] then check(h0 > h1 + 20, estilo .. ": el halo no llega de lejos (" .. h0 .. " -> " .. h1 .. ")") end
      check(brillo, estilo .. ": la luz no cruzó el nombre")
      check(polvo >= 3, estilo .. ": sin polvo ni chispas (" .. polvo .. ")")
      check((f.Sobre:GetAlpha() or 0) > 0.9 and (f.Texto:GetAlpha() or 0) > 0.9, estilo .. ": la línea de arriba o la de abajo no aparecieron")
      if FOTOS then
        local fondo = CreateFrame("Frame", nil, UIParent)
        fondo:SetFrameStrata("BACKGROUND")
        fondo:SetPoint("TOPLEFT", f, "TOPLEFT", -10, 10)
        fondo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 10, -10)
        local c = fondo:CreateTexture(nil, "BACKGROUND")
        c:SetAllPoints(fondo)
        c:SetTexture("white")
        c:SetGradient("VERTICAL", CreateColor(0.03, 0.04, 0.05, 1), CreateColor(0.09, 0.11, 0.15, 1))
        for i = 1, 40 do
          local s = fondo:CreateTexture(nil, "BACKGROUND", nil, 2)
          s:SetSize(1, 1)
          s:SetPoint("TOPLEFT", fondo, "TOPLEFT", (i * 97) % 700, -((i * 53) % 90))
          s:SetColorTexture(0.8, 0.8, 0.85, 0.4)
        end
        for _, x in ipairs({ f.RayaI, f.RayaD, f.BandaI, f.BandaD, f.BrilloI, f.BrilloD }) do x._tex = "white" end
        fondo:Show()
        SNAP("anuncio-" .. estilo, fondo, { f })
        fondo:Hide()
      end
      -- La salida: sube un poco mientras se va.
      local _, _, _, _, y0 = f.C:GetPoint(1)
      while f:IsShown() and t < 12 do
        NOW = NOW + 0.05 t = t + 0.05
        FIRE(f, "OnUpdate", 0.05)
        local _, _, _, _, y = f.C:GetPoint(1)
        if f:IsShown() and (y or 0) > maxY then maxY = y end
      end
      check(not f:IsShown(), estilo .. ": no se fue solo")
      check(maxY >= 6, estilo .. ": no tiene salida elegante (subió " .. maxY .. ")")
    end
  end
  -- En modo ligero: nada de cine.
  limpiar()
  local lig = N.Ligero
  N.Ligero = function() return true end
  K.Anuncio({ estilo = "zona", titulo = "Durotar", ya = true, clave = "probar" })
  local f = anuncio()
  correr(1)
  local polvo = 0
  for _, p in ipairs(f.Polvo) do if p:IsShown() then polvo = polvo + 1 end end
  check(polvo == 0 and not f.BrilloI:IsShown(), "en modo ligero salió el polvo o el brillo")
  N.Ligero = lig
  limpiar()
end)

---------------------------------------------------------------------------
-- 4. La firma de cada módulo
---------------------------------------------------------------------------
step("Cada aviso trae la firma de su módulo", function()
  limpiar()
  lyaVisible = false
  local F = K.FIRMAS
  check(type(F) == "table", "falta K.FIRMAS")
  local sonidos, n = {}, 0
  for clave, f in pairs(F) do
    n = n + 1
    check(f.color and f.icono and f.sonido and f.id, clave .. ": su firma está incompleta")
  end
  check(n >= 12, "pocas firmas (" .. n .. ")")
  for _, clave in ipairs({ "ruta", "bolsas", "pesca", "combate", "manada", "lya", "comercio", "mundo", "mazmorras", "hoy" }) do
    check(F[clave], "falta la firma de " .. clave)
    if F[clave] then
      check(not sonidos[F[clave].sonido], clave .. " suena igual que " .. tostring(sonidos[F[clave].sonido]))
      sonidos[F[clave].sonido] = clave
    end
  end
  -- Por su módulo.
  NOW = NOW + 2
  local a = K.Aviso({ titulo = "Firma de prueba de Pesca", modulo = "pesca", lya = false })
  check(type(a) == "table" and a.alfaFirma == "pesca", "el aviso no tomó la firma de su módulo")
  if type(a) == "table" then
    check(a.Firma:IsShown() or a.Icono:GetTexture() == K.Ruta("ic-pesca"), "el aviso no lleva el ícono de Pesca")
    check(N.ultimoSonido == "firma:pesca", "no sonó el sonido corto de Pesca (" .. tostring(N.ultimoSonido) .. ")")
    a:Cerrar()
  end
  -- Por su ícono (si no dice de dónde viene).
  NOW = NOW + 2
  a = K.Aviso({ titulo = "Firma de prueba por ícono", icono = "ic-bolsas", lya = false })
  check(type(a) == "table" and a.alfaFirma == "bolsas", "por su ícono no se supo que es de Bolsas")
  if type(a) == "table" then a:Cerrar() end
  -- Desde la carpeta de quien lo pide (la pila del juego).
  local ds = debugstack
  debugstack = function() return "[string \"@Interface/AddOns/Alfa_Nucleo/Kit/Ventanas.lua\"]:700\n[string \"@Interface/AddOns/Alfa_Manada/Raro.lua\"]:12" end
  check(select(2, K.FirmaDe({ titulo = "x" })) == "manada", "no sabe de qué carpeta viene el aviso")
  debugstack = ds
  if FOTOS then
    NOW = NOW + 2
    local quien = { { "pesca", "¡Pez grande!", "Te picó un Pargo de la Bahía." }, { "manada", "Tu manada anda cerca", "Lobato está en tu zona." },
      { "bolsas", "Tus bolsas están casi llenas", "Te quedan 3 lugares." } }
    local hechos = {}
    for i, q in ipairs(quien) do
      NOW = NOW + 1
      hechos[i] = K.Aviso({ titulo = q[2], texto = q[3], modulo = q[1], lya = false, duracion = 30 })
    end
    local fondo = CreateFrame("Frame", nil, UIParent)
    fondo:SetFrameStrata("BACKGROUND")
    local top, bot = hechos[#hechos], hechos[1]
    if type(top) == "table" and type(bot) == "table" then
      fondo:SetPoint("TOPLEFT", top, "TOPLEFT", -14, 14)
      fondo:SetPoint("BOTTOMRIGHT", bot, "BOTTOMRIGHT", 14, -14)
      local c = fondo:CreateTexture(nil, "BACKGROUND")
      c:SetAllPoints(fondo)
      c:SetTexture("white")
      c:SetGradient("VERTICAL", CreateColor(0.03, 0.04, 0.05, 1), CreateColor(0.09, 0.11, 0.15, 1))
      fondo:Show()
      SNAP("firmas", fondo, hechos)
      fondo:Hide()
    end
    for _, h in ipairs(hechos) do if type(h) == "table" then h:Cerrar() end end
  end
end)

---------------------------------------------------------------------------
-- 5. Agrupar los parecidos
---------------------------------------------------------------------------
step("Avisos parecidos que llegan juntos van en uno", function()
  limpiar()
  lyaVisible = false
  local function lista(n, l) return N.Plural(n, "%d misión lista para entregar", "%d misiones listas para entregar"), l[#l].texto end
  local vivos0 = K.AvisosVivos()
  for i, q in ipairs({ "El lobo hambriento", "Pieles de jabalí", "Correo para Gamon" }) do
    K.Aviso({ titulo = "Misión lista para entregar", texto = q, grupo = "listas", agrupar = lista, lya = false })
    NOW = NOW + 0.5
  end
  check(K.AvisosVivos() - vivos0 == 1, "las tres misiones salieron en avisos separados (" .. (K.AvisosVivos() - vivos0) .. ")")
  check(hay("aviso", "3 misiones listas para entregar"), "no dice «3 misiones listas para entregar»")
  -- Sin grupo: el mismo título, sus textos uno bajo otro.
  limpiar()
  vivos0 = K.AvisosVivos()
  for _, t in ipairs({ "Cobre", "Estaño", "Hierro", "Mitril" }) do
    K.Aviso({ titulo = "Recogiste un mineral", texto = t, lya = false })
    NOW = NOW + 0.4
  end
  check(K.AvisosVivos() - vivos0 == 1, "cuatro avisos con el mismo título no se juntaron")
  local u = salidas[#salidas]
  check(u and u.texto:find("Cobre") and u.texto:find("y 1 más", 1, true), "el aviso junto no dice lo de cada uno: " .. tostring(u and u.texto))
  -- Separados en el tiempo: cada uno el suyo.
  NOW = NOW + 30
  K.Aviso({ titulo = "Recogiste un mineral", texto = "Plata", lya = false })
  check(salidas[#salidas].texto:find("Plata") and not salidas[#salidas].texto:find("Cobre"), "se juntó con uno de hace 30 s")
  -- Las misiones listas en tu chat: una sola línea.
  local PC = ns.PartyChat or (ns.Quests and ns.Quests.PartyChat)
  if PC and PC.Lista and PC.FlushReady then
    limpiar()
    for _, q in ipairs({ "[El lobo hambriento]", "[Pieles de jabalí]", "[Correo para Gamon]" }) do PC.Lista(q) end
    PC.FlushReady()
    local n = 0
    for _, s in ipairs(salidas) do if s.canal == "chat" then n = n + 1 end end
    check(n <= 1, "las misiones listas salieron en " .. n .. " líneas del chat")
  else
    print("(sin PartyChat en el banco: se salta la línea del chat)")
  end
end)

---------------------------------------------------------------------------
-- 6. «La última vez…»
---------------------------------------------------------------------------
step("«La última vez…» en Hoy, no como aviso", function()
  limpiar()
  local U = N.UltimaVez
  check(U and U.Resumen and U.AlEntrar, "falta N.UltimaVez")
  if not U then return end
  local d = N.DatosPersonaje("ultimaVez")
  local ahora = GetServerTime and GetServerTime() or 0
  d.t, d.listas, d.guia, d.hechos, d.total, d.carta = ahora - 3600, 3, "Los Baldíos 20-25", 12, 40, ahora + 86400 * 1.5
  local avisos = #salidas
  if N.OlvidarAlEntrar then N.OlvidarAlEntrar() end
  check(U.AlEntrar() == true, "no puso «La última vez…» en Hoy")
  check(#salidas == avisos, "«La última vez…» salió como aviso")
  local e
  for _, x in ipairs(N.AlEntrar()) do if x.id == "ultimaVez" then e = x end end
  check(e and e.titulo == "La última vez…", "Hoy no tiene la tarjeta «La última vez…»")
  check(e and e.texto:find("3 misiones listas", 1, true) and e.texto:find("12 de 40", 1, true) and e.texto:find("vence en un día", 1, true),
    "el resumen no dice lo pendiente: " .. tostring(e and e.texto))
  check(e and e.accion and e.accion.texto == "Seguir mi guía", "el resumen no trae su botón")
  -- Sin nada pendiente, nada; con un /reload o recién salido, nada.
  N.OlvidarAlEntrar("ultimaVez")
  d.listas, d.guia, d.carta = 0, nil, nil
  check(U.AlEntrar() == false, "sin pendientes salió «La última vez…»")
  d.t, d.listas = ahora - 60, 2
  check(U.AlEntrar() == false, "saliste hace un minuto y salió «La última vez…»")
  -- Guardar al salir no truena.
  check(type(U.Guardar()) == "table", "no guardó lo pendiente al salir")
end)

for nombre, n in pairs(SUCESOS) do print(("CUENTA %s = %d"):format(nombre, n)) end
print("pasos", pasos)
