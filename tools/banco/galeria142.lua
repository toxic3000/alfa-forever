-- Escenas de la 1.4.2 para revisar a ojo y para la galería de CurseForge:
-- tu ficha («Tu personaje» y «Tus personajes») y la portada de Hoy con una
-- sesión larga. Datos de muestra (Lobato y su manada), nada de ningún jugador real.
SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[name] = { entries = entries, l = l, b = b, w = w, h = h }
end
BANCO_LETRA = 0.64
GetMoney = function() return 1530676 end
UnitName = function() return "Lobato" end
UnitClass = function() return "Guerrero", "WARRIOR" end
UnitRace = function() return "Humano", "Human" end
UnitLevel = function() return 34 end
UnitXP = function() return 31000 end
UnitXPMax = function() return 52000 end
GetXPExhaustion = function() return 12000 end
GetGuildInfo = function() return "La Jauría" end
GetRealZoneText = function() return "Loch Modan" end
GetInventoryItemDurability = function(r) if r <= 10 then return 92, 100 end return nil end
C_Container.GetContainerNumSlots = function(b) return b == 0 and 16 or 22 end
C_Container.GetContainerNumFreeSlots = function(b) return b == 0 and 3 or 4, 0 end
C_SkillInfo = C_SkillInfo or {}
C_SkillInfo.GetNumSkillLines = function() return 4 end
C_SkillInfo.GetSkillLineInfo = function(i)
  local t = { { skillID = 164, skillName = "Herrería", rank = 255, maxRank = 300 }, { skillID = 186, skillName = "Minería", rank = 300, maxRank = 300 },
    { skillID = 185, skillName = "Cocina", rank = 180, maxRank = 225 }, { skillID = 356, skillName = "Pesca", rank = 159, maxRank = 225 } }
  return t[i]
end
for clase, c in pairs({ WARRIOR = { 0.78, 0.61, 0.43 }, HUNTER = { 0.67, 0.83, 0.45 }, MAGE = { 0.25, 0.78, 0.92 } }) do
  RAID_CLASS_COLORS[clase] = { r = c[1], g = c[2], b = c[3] }
end
PRUEBA_ENTRAR()
local N = AlfaNucleo
local In = NS_OF("Alfa_Inicio")
if In.Jugado then In.Jugado.Datos = function() return { total = 810000 } end end
local db = N.Datos("inicio")
db.ficha = db.ficha or {}
db.ficha["Lyara-Reino"] = { nombre = "Lyara", clase = "HUNTER", claseNombre = "Cazadora", nivel = 60, oro = 4210050,
  oficios = { { linea = 393, nombre = "Desuello", r = 300, m = 300 }, { linea = 165, nombre = "Peletería", r = 285, m = 300 } }, descansada = 0.5, visto = time() - 7200 }
db.ficha["Brasa-Reino"] = { nombre = "Brasa", clase = "MAGE", claseNombre = "Maga", nivel = 22, oro = 85300,
  oficios = { { linea = 197, nombre = "Sastrería", r = 110, m = 150 }, { linea = 333, nombre = "Encantamiento", r = 95, m = 150 } }, descansada = 1.2, visto = time() - 3 * 86400 }
local Fi = In.Ficha
local v = Fi.Abrir("yo")
TIEMPO(1)
SNAP("142-ficha", v)
Fi.Abrir("todos")
TIEMPO(1)
SNAP("142-personajes", v)
v:Cerrar()
-- La portada de Hoy con una sesión larga (el «1 h 48 min» que se salía).
local dur = N.Duracion
N.Duracion = function(sg, r) return "1 h 48 min" end
Alfa.Fire("SHOW_OPTIONS", "inicio")
TIEMPO(1)
local o = Alfa.UI.Options.frame
SNAP("142-portada", o)
N.Duracion = dur
o:Hide()
---------------------------------------------------------------------------
-- Más escenas de la 1.4.2 (avisos y ventanas de las novedades), sobre una
-- noche oscura como las de la 1.3.7 (nada de fondo verde liso).
---------------------------------------------------------------------------
if N.Entrando then N.Entrando = function() return false end end
local A = Alfa
local K = N.Kit
for clase, c in pairs({ WARRIOR = { 0.78, 0.61, 0.43 }, HUNTER = { 0.67, 0.83, 0.45 }, SHAMAN = { 0.0, 0.44, 0.87 },
  PRIEST = { 1, 1, 1 }, ROGUE = { 1, 0.96, 0.41 }, MAGE = { 0.25, 0.78, 0.92 }, DRUID = { 1, 0.49, 0.04 },
  PALADIN = { 0.96, 0.55, 0.73 }, WARLOCK = { 0.53, 0.53, 0.93 } }) do
  RAID_CLASS_COLORS[clase] = { r = c[1], g = c[2], b = c[3], colorStr = string.format("ff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) }
end
for _, n in ipairs({ "AlfaLyaLoba", "AlfaInicioAviso", "AlfaRastreador", "AlfaNavArrow" }) do
  local f = rawget(_G, n)
  if type(f) == "table" and f.Hide then f:Hide() end
end

local semilla = 7
local function azar()
  semilla = (semilla * 1103515245 + 12345) % 2147483648
  return semilla / 2147483648
end
local function capa(f, nivel, sub)
  local t = f:CreateTexture(nil, nivel or "BACKGROUND")
  if sub then t:SetDrawLayer(nivel or "BACKGROUND", sub) end
  return t
end
local function degradado(t, orient, a, b)
  t:SetTexture("white")
  t:SetGradient(orient, CreateColor(a[1], a[2], a[3], a[4] or 1), CreateColor(b[1], b[2], b[3], b[4] or 1))
end
local function escenario(w, h, estrellas)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetSize(w, h)
  local cielo = capa(f, "BACKGROUND", -8)
  cielo:SetAllPoints(f)
  degradado(cielo, "VERTICAL", { 0.035, 0.04, 0.045 }, { 0.09, 0.11, 0.14 })
  for _ = 1, math.floor(w * h * (estrellas or 0.35) / 4000) do
    local s = capa(f, "BACKGROUND", -6)
    local tam = azar() < 0.85 and 1 or 2
    s:SetSize(tam, tam)
    s:SetPoint("TOPLEFT", f, "TOPLEFT", azar() * w, -azar() * h * (estrellas or 0.35))
    local v = 0.55 + azar() * 0.4
    s:SetColorTexture(v, v, v * 1.05, 0.25 + azar() * 0.45)
  end
  local function colina(cx, cy, rx, ry, c)
    local t = capa(f, "BACKGROUND", -4)
    t:SetTexture("circle")
    t:SetSize(rx * 2, ry * 2)
    t:SetPoint("CENTER", f, "BOTTOMLEFT", cx, cy)
    t:SetVertexColor(c[1], c[2], c[3], 1)
  end
  colina(w * 0.18, -h * 0.05, w * 0.42, h * 0.32, { 0.06, 0.07, 0.08 })
  colina(w * 0.78, -h * 0.08, w * 0.5, h * 0.36, { 0.055, 0.065, 0.075 })
  colina(w * 0.45, -h * 0.2, w * 0.55, h * 0.34, { 0.04, 0.045, 0.05 })
  local izq, der = capa(f, "BACKGROUND", -2), capa(f, "BACKGROUND", -2)
  izq:SetPoint("TOPLEFT", f, "TOPLEFT") izq:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT") izq:SetWidth(w * 0.18)
  der:SetPoint("TOPRIGHT", f, "TOPRIGHT") der:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT") der:SetWidth(w * 0.18)
  degradado(izq, "HORIZONTAL", { 0, 0, 0, 0.45 }, { 0, 0, 0, 0 })
  degradado(der, "HORIZONTAL", { 0, 0, 0, 0 }, { 0, 0, 0, 0.45 })
  f:Show()
  return f
end
-- El escenario justo detrás de unos marcos, con `aire` alrededor.
local function encuadre(marcos, aire, ajuste)
  local l, r, t, b = math.huge, -math.huge, -math.huge, math.huge
  for _, m in ipairs(marcos) do
    if m and m:IsShown() and m:GetLeft() then
      l = math.min(l, m:GetLeft()) r = math.max(r, m:GetRight())
      t = math.max(t, m:GetTop()) b = math.min(b, m:GetBottom())
    end
  end
  ajuste = ajuste or {}
  l, r = l - aire - (ajuste.l or 0), r + aire + (ajuste.r or 0)
  t, b = t + aire + (ajuste.t or 0), b - aire - (ajuste.b or 0)
  local f = escenario(r - l, t - b)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
  return f
end
local function snapEn(nombre, marcos, aire, ajuste)
  local lista = {}
  for _, m in ipairs(marcos) do if m and m:IsShown() then lista[#lista + 1] = m end end
  if #lista == 0 then NOTE("galeria142", "nada que capturar en " .. nombre) return end
  local esc = encuadre(lista, aire or 40, ajuste)
  SNAP(nombre, esc, lista)
  esc:Hide()
end
-- Lo que sale del aviso pedido (con su ventanita: sin Lya).
local function capturarAviso(prueba, fn)
  local aviso = K.Aviso
  local capturado, opciones
  K.Aviso = function(o)
    if type(o) == "table" and prueba(o) then o.lya = false end
    local r = aviso(o)
    if type(o) == "table" and prueba(o) and type(r) == "table" then capturado, opciones = r, o end
    return r
  end
  local ok, e = pcall(fn)
  K.Aviso = aviso
  if not ok then error(e, 0) end
  -- El banco corre todos los relojes al instante (también el que lo esconde
  -- a sus segundos): para la foto se queda a la vista, como en el juego.
  if capturado and not capturado:IsShown() then capturado:Show() end
  if capturado and capturado.SetAlpha then capturado:SetAlpha(1) end
  return capturado, opciones
end
local function porId(id) return function(o) return o.id == id end end
local function porTitulo(t) return function(o) return o.titulo == t end end
local function cerrarAviso(f)
  if not f then return end
  if f.Cerrar then pcall(f.Cerrar, f) else f:Hide() end
  RUN_TIMERS(1)
end
-- Cambia campos de una tabla mientras corre fn.
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = rawget(t, k) } rawset(t, k, v) end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(t, k, a.v) end
  if not ok then error(e, 0) end
end
local Ru = NS_OF("Alfa_Rutas")
-- El banco no dibuja los íconos de las monedas dentro del texto: el dinero va
-- con sus letras («77p 50c»), la otra forma en que Alfa lo escribe.
local dineroConIconos = N.Dinero
N.Dinero = N.DineroTexto

---------------------------------------------------------------------------
-- 1. El mapa de la M: «Limpiar mapa» junto a la lupa, con su ayuda
---------------------------------------------------------------------------
PASO("mapa", function()
  local Mu = NS_OF("Alfa_Mundo")
  local MJ = Mu.MapaJuego
  WorldMapFrame:ClearAllPoints()
  WorldMapFrame:SetSize(1000, 680)
  WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  WorldMapFrame:Show()
  MJ.CrearBarra()
  local barra = rawget(_G, "AlfaMundoBotonesMapa")
  if not (barra and barra.Limpio) then NOTE("galeria142", "no salió la barra del mapa") return end
  barra:Show()
  if MJ.PintarLimpio then MJ.PintarLimpio() end
  RUN_TIMERS(1)
  -- En el juego, subir el nivel de la barra sube también el de sus botones;
  -- el banco no lo hace (su fondo quedaba encima de los botones).
  local function subir(f, nivel)
    for _, c in ipairs({ f:GetChildren() }) do c:SetFrameLevel(nivel) subir(c, nivel + 1) end
  end
  subir(barra, barra:GetFrameLevel() + 2)
  FIRE(barra.Limpio, "OnEnter")
  local info
  for _, f in ipairs(ALL_FRAMES()) do if rawget(f, "dueno") == barra.Limpio and f:IsShown() then info = f end end
  print("mapa:", barra:GetWidth(), barra:GetHeight(), "info", info ~= nil)
  snapEn("142-mapa", { barra, info }, 36)
  FIRE(barra.Limpio, "OnLeave")
  WorldMapFrame:Hide()
end)

---------------------------------------------------------------------------
-- 2. «¡Lista para entregar!»
---------------------------------------------------------------------------
PASO("lista", function()
  local La, Ir = Ru.ListaAviso, Ru.IrMision
  local Cp = Ru.Motor("Compat")
  local TIT = { [301] = "Colmillos de jabalí", [302] = "Pieles de jabalí" }
  local listo = { [301] = true }
  local R = rawget(_G, "AlfaRuta") or {}
  con(Cp, {
    GetLogQuests = function() return { 301, 302 } end,
    IsQuestReadyForTurnIn = function(q) return listo[q] == true end,
    IsOnQuest = function(q) return TIT[q] ~= nil end,
    GetQuestTitle = function(q) return TIT[q] end,
  }, function()
    con(Ir, { Punto = function(q) return { map = 1426, x = 46, y = 52, nombre = "Zureetha Fargaze" }, "entrega" end }, function()
      con(R, { EsDeMiRuta = function() return false end }, function()
        NOW = NOW + 20
        A.Set("rutas.avisoLista", false)
        La.Revisar()
        A.Set("rutas.avisoLista", true)
        listo[302] = true
        local f = capturarAviso(porTitulo("¡Lista para entregar!"), function() La.Revisar() RUN_TIMERS(1) end)
        if not f then NOTE("galeria142", "no salió «¡Lista para entregar!»") return end
        TIEMPO_CORTO(0.6)
        print("lista:", f:GetWidth(), f:GetHeight())
        snapEn("142-lista", { f }, 40)
        cerrarAviso(f)
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- 3. Misiones nuevas al subir de nivel: «Ver cuáles»
---------------------------------------------------------------------------
PASO("nuevas", function()
  local Su, Ix = Ru.AlSubir, Ru.Indice
  local MIS = {
    { id = 401, t = "La cueva de los kobolds", lvl = 13, x = 52, s = 95 },
    { id = 402, t = "Encargo para el herrero", lvl = 12, x = 55, s = 140 },
    { id = 403, t = "Los túneles de Ragnafuego", lvl = 14, x = 63, s = 260 },
    { id = 404, t = "Bigotes en el lago", lvl = 13, x = 70, s = 330 },
    { id = 405, t = "Un paquete para Thelsamar", lvl = 12, x = 80, s = 480 },
    { id = 406, t = "Cerveza para la excavación", lvl = 13, x = 84, s = 560 },
    { id = 407, t = "Los huevos del lago", lvl = 12, x = 88, s = 640 },
    { id = 408, t = "Arañas en la mina", lvl = 14, x = 92, s = 720 },
  }
  local por, indice = {}, { lista = {} }
  for _, m in ipairs(MIS) do
    por[m.id] = m
    indice.lista[#indice.lista + 1] = { id = m.id, min = 12, lvl = m.lvl }
  end
  local zonaDe = { [1432] = "Loch Modan", [1426] = "Dun Morogh" }
  con(Ix, {
    Listo = function() return indice end,
    Pedir = function(fn) return fn(indice) end,
    Disponible = function() return true end,
    EnRegistro = function() return false end,
    Puntos = function(e) local m = por[e.id] return { map = (m.id == 405 or m.id == 407) and 1426 or 1432, x = m.x, y = 40, name = "Dador" } end,
    Viaje = function(_, p) for _, m in ipairs(MIS) do if m.x == p.x then return m.s end end return 600 end,
  }, function()
    con(Ru, {
      TituloMision = function(q) return por[q] and por[q].t or ("Misión " .. q) end,
      Zona = function(map) return zonaDe[map] end,
    }, function()
      con(A, { PlayerPoint = function() return { map = 1432, x = 50, y = 50 } end }, function()
        Su.Abrir(12)
        RUN_TIMERS(1)
      end)
    end)
  end)
  local v = Su.Ventana()
  if not (v and v:IsShown()) then NOTE("galeria142", "no salió la ventana de misiones nuevas") return end
  TIEMPO_CORTO(0.5)
  print("nuevas:", v:GetWidth(), v:GetHeight())
  snapEn("142-nuevas", { v }, 30)
  v:Hide()
end)

---------------------------------------------------------------------------
-- El medidor del juego, de muestra (para la caída y el medidor)
---------------------------------------------------------------------------
local combate = false
local inCombatViejo, enCombateViejo = InCombatLockdown, UnitAffectingCombat
local function medidorDeMuestra()
  Enum.DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6,
    DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 }
  Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }
  local function fila(nombre, clase, yo, total, dur)
    return { name = nombre, classFilename = clase, isLocalPlayer = yo, totalAmount = total, amountPerSecond = total / (dur or 95), sourceGUID = "Player-1-" .. nombre }
  end
  local porTipo = {}
  porTipo[0] = { fila("Lyara", "HUNTER", false, 21840), fila("Lobato", "WARRIOR", true, 17320), fila("Sombra", "ROGUE", false, 16110),
    fila("Brasa", "MAGE", false, 14980), fila("Aullido", "PRIEST", false, 3920) }
  porTipo[1] = porTipo[0]
  porTipo[7] = { fila("Lobato", "WARRIOR", true, 9000), fila("Sombra", "ROGUE", false, 3100), fila("Brasa", "MAGE", false, 2400) }
  porTipo[8] = { fila("Brasa", "MAGE", false, 2860), fila("Lobato", "WARRIOR", true, 1940), fila("Sombra", "ROGUE", false, 1210),
    fila("Lyara", "HUNTER", false, 640), fila("Aullido", "PRIEST", false, 180) }
  porTipo[5] = { fila("Lobato", "WARRIOR", true, 6), fila("Sombra", "ROGUE", false, 4), fila("Brasa", "MAGE", false, 2) }
  porTipo[6] = { fila("Aullido", "PRIEST", false, 5) }
  local hechizos = { [7] = {
    { spellID = 133, totalAmount = 5100, creatureName = "Mago Defias", overkillAmount = 600, isAvoidable = false, isDeadly = true },
    { spellID = 2120, totalAmount = 2100, creatureName = "Mago Defias", overkillAmount = 0, isAvoidable = true, isDeadly = false },
  } }
  C_DamageMeter = {
    IsDamageMeterAvailable = function() return true, "" end,
    GetCombatSessionFromType = function(_, tipo)
      local f = porTipo[tipo] or {}
      local tot, mx = 0, 0
      for _, x in ipairs(f) do tot = tot + x.totalAmount if x.totalAmount > mx then mx = x.totalAmount end end
      return { combatSources = f, maxAmount = mx, totalAmount = tot }
    end,
    GetCombatSessionFromID = function() return { combatSources = {} } end,
    GetCombatSessionSourceFromType = function(_, tipo) return { combatSpells = hechizos[tipo] or {} } end,
    GetAvailableCombatSessions = function() return {} end,
    GetSessionDurationSeconds = function() return 95 end,
  }
  GetCVar = function(n) if n == "damageMeterEnabled" then return "1" end return "0" end
  local nombres = { [133] = "Bola de fuego", [2120] = "Fogonazo", [2006] = "Resurrección" }
  C_Spell = C_Spell or {}
  C_Spell.GetSpellName = function(id) return nombres[id] end
  InCombatLockdown = function() return combate end
  UnitAffectingCombat = function() return combate end
end
local function pelea(seg)
  combate = true
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  TIEMPO_CORTO(seg or 1)
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
end
local Cb = NS_OF("Alfa_Combate")

---------------------------------------------------------------------------
-- 4. «¿Qué me tumbó?»
---------------------------------------------------------------------------
PASO("caida", function()
  medidorDeMuestra()
  local f = capturarAviso(porId("combate.caida"), function()
    pelea(3)
    FIRE_EVENT("PLAYER_DEAD")
    RUN_TIMERS(5)
  end)
  if not f then NOTE("galeria142", "no salió «Lo que te tumbó»") return end
  TIEMPO_CORTO(0.6)
  print("caida:", f:GetWidth(), f:GetHeight())
  snapEn("142-caida", { f }, 40)
  cerrarAviso(f)
end)

---------------------------------------------------------------------------
-- 5. El medidor: daño evitable con tu grupo
---------------------------------------------------------------------------
PASO("medidor", function()
  medidorDeMuestra()
  IsInGroup = function() return true end
  IsInRaid = function() return false end
  Cb.SetOpt("medidorModo", "siempre")
  Cb.SetOpt("tipo", "evitable")
  N.Datos("combate").pos = nil
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  RUN_TIMERS(2)
  Cb.Ventana.Ver()
  Cb.Ventana.Pintar(true)
  RUN_TIMERS(1)
  local med = rawget(_G, "AlfaCombateMedidor")
  if not (med and med:IsShown()) then NOTE("galeria142", "no salió el medidor") return end
  -- El relleno de cada barra (el banco no dibuja las StatusBar): su color de clase y su parte del máximo.
  local Dm = Cb.Medidor
  for _, fl in ipairs(med.filas or {}) do
    local x, r = fl.alfaDato, fl.alfaLectura
    if fl:IsShown() and x and r then
      local t = fl.Barra:CreateTexture(nil, "BORDER")
      local cr, cg, cb = Dm.Color(x.clase)
      t:SetColorTexture(cr, cg, cb, 0.55)
      t:SetPoint("TOPLEFT", fl, "TOPLEFT", 0, 0)
      t:SetPoint("BOTTOMLEFT", fl, "BOTTOMLEFT", 0, 0)
      t:SetWidth(math.max(1, fl:GetWidth() * (tonumber(x.valor) or 0) / math.max(1, tonumber(r.max) or 1)))
    end
  end
  med:ClearAllPoints()
  med:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  print("medidor:", med:GetWidth(), med:GetHeight())
  snapEn("142-medidor", { med }, 40)
  med:Hide()
  Cb.SetOpt("tipo", "dps")
  Cb.SetOpt("medidorModo", "auto")
  IsInGroup = function() return false end
end)

---------------------------------------------------------------------------
-- 6. «Faltan por revivir»
---------------------------------------------------------------------------
PASO("revivir", function()
  local Cu = NS_OF("Alfa_Curacion")
  local Rv = Cu.Revivir
  local NOMBRES = { party1 = "Colmillo", party2 = "Brasa", party3 = "Lyara", party4 = "Sombra" }
  local muertos = { party1 = true, party3 = true }
  local nombre = UnitName
  local viejos = { IsInGroup = IsInGroup, GetNumGroupMembers = GetNumGroupMembers, UnitExists = UnitExists,
    UnitIsDeadOrGhost = UnitIsDeadOrGhost, UnitIsConnected = UnitIsConnected, UnitIsGhost = UnitIsGhost }
  IsInGroup = function() return true end
  GetNumGroupMembers = function() return 5 end
  UnitExists = function(u) return u == "player" or NOMBRES[u] ~= nil end
  UnitIsDeadOrGhost = function(u) return muertos[u] == true end
  UnitIsConnected = function() return true end
  UnitIsGhost = function() return false end
  UnitName = function(u) if NOMBRES[u] then return NOMBRES[u] end return nombre(u) end
  local conocido = Cu.Conocido
  Cu.Conocido = function(k) if k == "resurreccion" then return 2006 end return nil end
  local f = capturarAviso(porId("curacion.revivir"), function() Rv.Revisar() RUN_TIMERS(1) end)
  Cu.Conocido = conocido
  if not f then NOTE("galeria142", "no salió «Faltan por revivir»") else
    TIEMPO_CORTO(0.6)
    print("revivir:", f:GetWidth(), f:GetHeight())
    snapEn("142-revivir", { f }, 40)
    cerrarAviso(f)
  end
  UnitName = nombre
  for k, v in pairs(viejos) do _G[k] = v end
end)
InCombatLockdown, UnitAffectingCombat = inCombatViejo, enCombateViejo

---------------------------------------------------------------------------
-- 7. «Con quién cazaste»
---------------------------------------------------------------------------
PASO("companeros", function()
  local MN = NS_OF("Alfa_Manada")
  local Cp, U = MN.Companeros, MN.U
  local d = N.Datos(MN.ID)
  d.companeros = {}
  local ahora = time()
  local GENTE = {
    { "Lyara", "HUNTER", "Cazadora", 34, "Las Minas de la Muerte", 2 * 3600, 4 },
    { "Brasa", "MAGE", "Maga", 33, "Las Minas de la Muerte", 2 * 3600, 2 },
    { "Aullido", "PRIEST", "Sacerdotisa", 35, "Las Cuevas de los Lamentos", 26 * 3600, 3 },
    { "Sombra", "ROGUE", "Pícaro", 32, "Loch Modan", 3 * 86400, 1 },
    { "Colmillo", "SHAMAN", "Chamán", 31, "Los Humedales", 5 * 86400, 2 },
    { "Trueno", "PALADIN", "Paladín", 36, "Montañas de Alterac", 9 * 86400, 1 },
  }
  for _, g in ipairs(GENTE) do
    local c = U.Clave(g[1])
    d.companeros[c] = { nombre = g[1], destino = g[1], clase = g[2], claseNombre = g[3], nivel = g[4], zona = g[5], t = ahora - g[6], veces = g[7] }
  end
  Cp.Abrir()
  RUN_TIMERS(1)
  local v = Cp.Ventana()
  if not (v and v:IsShown()) then NOTE("galeria142", "no salió «Con quién cazaste»") return end
  TIEMPO_CORTO(0.5)
  print("companeros:", v:GetWidth(), v:GetHeight())
  snapEn("142-companeros", { v }, 30)
  if v.Cerrar then v:Cerrar() else v:Hide() end
end)

---------------------------------------------------------------------------
-- 8. «Siempre a la mano» en el comerciante
---------------------------------------------------------------------------
local Co = NS_OF("Alfa_Comercio")
PASO("reponer", function()
  local Rp = Co.Reponer
  local AGUA, PAN, VENDAS = 1205, 4541, 1251
  local VENDE = {
    { id = AGUA, nombre = "Agua dulce de manantial", precio = 125, por = 1, hay = -1, clase = 0 },
    { id = PAN, nombre = "Pan de avena", precio = 125, por = 1, hay = -1, clase = 0 },
    { id = VENDAS, nombre = "Venda de lino", precio = 40, por = 1, hay = -1, clase = 0 },
  }
  local CIp = {}
  for k, v in pairs(C_Item) do CIp[k] = v end
  CIp.GetItemInfo = function(id)
    id = tonumber(tostring(id):match("(%d+)") or id)
    for _, v in ipairs(VENDE) do
      if v.id == id then return v.nombre, "|cffffffff|Hitem:" .. id .. "|h[" .. v.nombre .. "]|h|r", 1, 5, 1, "x", "y", 20, "", 134400, 1, v.clase end
    end
    return "Objeto " .. tostring(id), nil, 1, 5, 1, "x", "y", 20, "", 134400, 1, 7
  end
  local tengo = { [AGUA] = 6, [PAN] = 12, [VENDAS] = 20 }
  local enBolsas = Co.EnBolsas
  Co.EnBolsas = function(id) return tengo[id] or 0 end
  Rp.Poner(AGUA, 40)
  Rp.Poner(PAN, 40)
  local MF = rawget(_G, "MerchantFrame") or CreateFrame("Frame", "MerchantFrame", UIParent)
  MF.selectedTab = 1
  local f
  con(_G, {
    C_Item = CIp, C_MerchantFrame = false,
    GetMoney = function() return 1530676 end,
    GetMerchantNumItems = function() return #VENDE end,
    GetMerchantItemID = function(i) return VENDE[i] and VENDE[i].id end,
    GetMerchantItemInfo = function(i) local v = VENDE[i] return v.nombre, 134400, v.precio, v.por, v.hay, true, true, false end,
    GetMerchantItemMaxStack = function() return 20 end,
    BuyMerchantItem = function() end,
  }, function()
    MF:Show()
    f = capturarAviso(porId("comercio.reponer"), function()
      FIRE_EVENT("MERCHANT_SHOW")
      TIEMPO(1)
    end)
    if f then
      TIEMPO_CORTO(0.6)
      print("reponer:", f:GetWidth(), f:GetHeight())
      snapEn("142-reponer", { f }, 40)
    else
      NOTE("galeria142", "no salió el aviso de reponer")
    end
    FIRE_EVENT("MERCHANT_CLOSED")
    MF:Hide()
  end)
  cerrarAviso(f)
  Rp.Quitar(AGUA)
  Rp.Quitar(PAN)
  Co.EnBolsas = enBolsas
end)

---------------------------------------------------------------------------
-- 9. «Tus subastas» en la página de Comercio
---------------------------------------------------------------------------
PASO("subastas", function()
  local Su = Co.Subastas
  local function L(id, n) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. n .. "]|h|r" end
  local MIAS = {
    { auctionID = 1, itemKey = { itemID = 2772 }, itemLink = L(2772, "Mena de hierro"), status = 0, quantity = 10, timeLeftSeconds = 3 * 3600, buyoutAmount = 1150 },
    { auctionID = 2, itemKey = { itemID = 4234 }, itemLink = L(4234, "Cuero pesado"), status = 0, quantity = 20, timeLeftSeconds = 11 * 3600, buyoutAmount = 480 },
    { auctionID = 3, itemKey = { itemID = 3575 }, itemLink = L(3575, "Barra de hierro"), status = 0, quantity = 5, timeLeftSeconds = 20 * 3600, buyoutAmount = 2400 },
    { auctionID = 4, itemKey = { itemID = 3827 }, itemLink = L(3827, "Poción de maná"), status = 0, quantity = 5, timeLeftSeconds = 30 * 3600, buyoutAmount = 1500 },
    { auctionID = 5, itemKey = { itemID = 2589 }, itemLink = L(2589, "Paño de lino"), status = 0, quantity = 20, timeLeftSeconds = 40 * 3600, buyoutAmount = 90 },
  }
  C_AuctionHouse = C_AuctionHouse or {}
  C_AuctionHouse.ReplicateItems = C_AuctionHouse.ReplicateItems or function() end
  C_AuctionHouse.GetNumReplicateItems = C_AuctionHouse.GetNumReplicateItems or function() return 0 end
  C_AuctionHouse.GetReplicateItemInfo = C_AuctionHouse.GetReplicateItemInfo or function() return nil end
  C_AuctionHouse.QueryOwnedAuctions = function() end
  C_AuctionHouse.GetOwnedAuctions = function() return MIAS end
  FIRE_EVENT("AUCTION_HOUSE_SHOW")
  TIEMPO(2)
  FIRE_EVENT("OWNED_AUCTIONS_UPDATED")
  TIEMPO(1)
  FIRE_EVENT("AUCTION_HOUSE_CLOSED")
  -- Otra visita: la barra de hierro ya se vendió.
  MIAS[3].status, MIAS[3].timeLeftSeconds = 1, nil
  local vendidas = capturarAviso(porId("comercio.subastasVendidas"), function()
    FIRE_EVENT("AUCTION_HOUSE_SHOW")
    TIEMPO(2)
    FIRE_EVENT("OWNED_AUCTIONS_UPDATED")
    TIEMPO(1)
  end)
  FIRE_EVENT("AUCTION_HOUSE_CLOSED")
  cerrarAviso(vendidas)
  local r = Su.Resumen()
  print("subastas:", r.activas, r.vendidas, r.valor)
  A.Fire("SHOW_OPTIONS", "comercio")
  TIEMPO(1)
  local o = A.UI.Options.frame
  -- El bloque de «Tus subastas»: se baja la página hasta él.
  local bloque
  for _, f in ipairs(ALL_FRAMES()) do
    local s = rawget(f, "Seccion")
    if rawget(f, "Tarjeta") and rawget(f, "Panel") and s and f:IsShown() then
      local t = s.Titulo or s.Texto
      local txt = t and t.GetText and t:GetText()
      if txt == "Tus subastas" then bloque = f end
    end
  end
  local sc = o and o.Scroll
  if bloque and sc then
    local hijo = sc:GetScrollChild()
    local desde = (hijo and hijo:GetTop() or sc:GetTop()) - bloque:GetTop()
    sc:SetVerticalScroll(math.max(0, desde - 16))
    TIEMPO_CORTO(0.3)
  else
    print("subastas: no encontré el bloque", bloque ~= nil, sc ~= nil)
  end
  SNAP("142-subastas", o)
  o:Hide()
end)

---------------------------------------------------------------------------
-- 10. «Qué pica aquí» en la barra de la pesca
---------------------------------------------------------------------------
PASO("aqui", function()
  local Pe = NS_OF("Alfa_Pesca")
  local Aq, B = Pe.Aqui, Pe.Barra
  local d = N.DatosPersonaje("pesca")
  d.lugares = { "Loch Modan", "Lago de Loch Modan", "Bosque de Elwynn", "Lago de Cristal", "Los Humedales", "La costa de Menethil" }
  d.registro = {}
  local BAGRE, SALMON, CAJA, PERCA, ACEITE = 6309, 6361, 6351, 6291, 6358
  local function capturas(id, n, z, s) for _ = 1, n do d.registro[#d.registro + 1] = { t = time(), id = id, n = 1, z = z, s = s } end end
  capturas(BAGRE, 14, 1, 2) capturas(SALMON, 9, 1, 2) capturas(PERCA, 6, 1, 2) capturas(ACEITE, 3, 1, 2) capturas(CAJA, 1, 1, 2)
  capturas(BAGRE, 12, 3, 4) capturas(PERCA, 8, 3, 4)
  capturas(CAJA, 4, 5, 6) capturas(ACEITE, 12, 5, 6)
  local diario = Pe.Diario()
  diario[BAGRE] = { n = 26, nombre = "Bagre fangoso" }
  diario[SALMON] = { n = 9, nombre = "Salmón de aletas plateadas" }
  diario[PERCA] = { n = 14, nombre = "Perca de roca" }
  diario[ACEITE] = { n = 12, nombre = "Pez aceitoso" }
  diario[CAJA] = { n = 4, nombre = "Caja de agua salada" }
  local valor, lugar = Pe.ValorDe, Pe.Lugar
  Pe.ValorDe = function(id)
    if id == CAJA then return 500, 2000 end
    if id == ACEITE then return 120, nil end
    if id == SALMON then return 16, nil end
    return 6, nil
  end
  Pe.Lugar = function() return "Loch Modan", "Lago de Loch Modan" end
  Pe.AbrirModo()
  RUN_TIMERS(3)
  Pe.Habilidad = Pe.Habilidad or function() return 159, 225, 0 end
  B.Desplegar()
  RUN_TIMERS(1)
  local barra = B.Barra()
  if not (barra and barra:IsShown()) then NOTE("galeria142", "no salió la barra de la pesca") end
  B.AlternarMenu("aqui", barra)
  RUN_TIMERS(1)
  local menu = rawget(_G, "AlfaPescaMenu")
  if not (menu and menu:IsShown()) then NOTE("galeria142", "no salió «Qué pica aquí»") else
    print("aqui:", menu:GetWidth(), menu:GetHeight())
    snapEn("142-aqui", { barra, menu }, 36)
  end
  B.CerrarMenu()
  Pe.CerrarModo()
  RUN_TIMERS(3)
  Pe.ValorDe, Pe.Lugar = valor, lugar
end)

N.Dinero = dineroConIconos
PRUEBA_FIN("galería 1.4.2")
