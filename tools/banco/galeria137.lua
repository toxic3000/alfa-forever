-- Escenas de la 1.3.7 para la galería de CurseForge (tools/galeria.py):
-- «Tu oro», los anuncios (zona, descubrir, mazmorra), el resumen de nivel, el
-- medidor de daño junto a las barras, la espada de la pesca, «Lo que me perdí»
-- y la barra de información con los números de las recargas.
-- Datos de muestra (Lobato y su manada), nada de ningún jugador real.
-- Nada lleva fondo verde: las escenas sueltas van sobre una noche oscura.
SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[name] = { entries = entries, l = l, b = b, w = w, h = h }
end
local function step(name, fn, ...)
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("step " .. name, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. name)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 600)) end
  end
end
BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N, B = AlfaNucleo, AlfaBienvenida
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true -- ya visto: que no tape las vistas
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
local A = Alfa
local K = N.Kit
-- Los colores de clase de verdad (el banco los trae todos iguales).
for clase, c in pairs({ WARRIOR = { 0.78, 0.61, 0.43 }, HUNTER = { 0.67, 0.83, 0.45 }, SHAMAN = { 0.0, 0.44, 0.87 },
  PRIEST = { 1, 1, 1 }, ROGUE = { 1, 0.96, 0.41 }, MAGE = { 0.25, 0.78, 0.92 }, DRUID = { 1, 0.49, 0.04 },
  PALADIN = { 0.96, 0.55, 0.73 }, WARLOCK = { 0.53, 0.53, 0.93 } }) do
  RAID_CLASS_COLORS[clase] = { r = c[1], g = c[2], b = c[3], colorStr = string.format("ff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) }
end
local before = #ERRORS
if A.UI.Options.frame then A.UI.Options.frame:Hide() end

---------------------------------------------------------------------------
-- El escenario: una noche oscura con un degradado, colinas y polvo de luz
---------------------------------------------------------------------------
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
  -- El cielo: de un azul noche arriba a casi negro abajo.
  local cielo = capa(f, "BACKGROUND", -8)
  cielo:SetAllPoints(f)
  degradado(cielo, "VERTICAL", { 0.035, 0.04, 0.045 }, { 0.09, 0.11, 0.14 })
  -- Polvo de luz (estrellas tenues) en la parte de arriba.
  for _ = 1, math.floor(w * h * (estrellas or 0.35) / 4000) do
    local s = capa(f, "BACKGROUND", -6)
    local tam = azar() < 0.85 and 1 or 2
    s:SetSize(tam, tam)
    s:SetPoint("TOPLEFT", f, "TOPLEFT", azar() * w, -azar() * h * (estrellas or 0.35))
    local v = 0.55 + azar() * 0.4
    s:SetColorTexture(v, v, v * 1.05, 0.25 + azar() * 0.45)
  end
  -- Colinas a lo lejos (dos tonos), para que parezca el mundo y no un color liso.
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
  -- Viñeta: los lados un poco más oscuros.
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

-- Una barra de acción del juego simulada: botones con su «ícono», su borde y su tecla.
local TONOS = {
  { 0.55, 0.22, 0.12 }, { 0.62, 0.48, 0.16 }, { 0.2, 0.36, 0.55 }, { 0.42, 0.2, 0.45 },
  { 0.25, 0.45, 0.22 }, { 0.6, 0.3, 0.18 }, { 0.3, 0.3, 0.38 }, { 0.5, 0.15, 0.15 },
  { 0.18, 0.4, 0.42 }, { 0.55, 0.5, 0.35 }, { 0.35, 0.22, 0.12 }, { 0.28, 0.32, 0.5 },
}
local TECLAS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
local function botonAccion(padre, i, tam, tecla)
  local b = CreateFrame("Button", nil, padre)
  b:SetSize(tam, tam)
  local borde = capa(b, "BACKGROUND")
  borde:SetAllPoints(b)
  borde:SetColorTexture(0.02, 0.02, 0.025, 1)
  local c = TONOS[(i - 1) % #TONOS + 1]
  local ic = capa(b, "BORDER")
  ic:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  ic:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  degradado(ic, "VERTICAL", { c[1] * 0.55, c[2] * 0.55, c[3] * 0.55 }, { c[1], c[2], c[3] })
  -- Un brillo en diagonal, como el arte de los hechizos.
  local br = capa(b, "ARTWORK")
  br:SetPoint("TOPLEFT", ic, "TOPLEFT", tam * 0.2, -tam * 0.2)
  br:SetSize(tam * 0.4, tam * 0.4)
  br:SetTexture("circle")
  br:SetVertexColor(math.min(1, c[1] + 0.35), math.min(1, c[2] + 0.35), math.min(1, c[3] + 0.35), 0.45)
  local marco = capa(b, "OVERLAY")
  marco:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 2)
  marco:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  marco:SetHeight(1)
  marco:SetColorTexture(0, 0, 0, 0.6)
  if tecla then
    local t = b:CreateFontString(nil, "OVERLAY")
    t:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
    t:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -3)
    t:SetText(tecla)
    t:SetTextColor(0.85, 0.85, 0.85, 1)
  end
  b:Show()
  return b
end
local function barraAccion(padre, n, tam, vertical, teclas)
  local f = CreateFrame("Frame", nil, padre)
  local paso = tam + 4
  if vertical then f:SetSize(tam + 8, n * paso + 4) else f:SetSize(n * paso + 4, tam + 8) end
  local fondo = capa(f, "BACKGROUND")
  fondo:SetAllPoints(f)
  fondo:SetColorTexture(0, 0, 0, 0.35)
  f.botones = {}
  for i = 1, n do
    local b = botonAccion(f, i + (vertical and 5 or 0), tam, teclas and TECLAS[i] or nil)
    if vertical then b:SetPoint("TOP", f, "TOP", 0, -4 - (i - 1) * paso)
    else b:SetPoint("LEFT", f, "LEFT", 4 + (i - 1) * paso, 0) end
    f.botones[i] = b
  end
  f:Show()
  return f
end

---------------------------------------------------------------------------
-- 1. Tu oro: 4 personajes de 2 reinos
---------------------------------------------------------------------------
step("oro", function()
  local Bo = NS_OF("Alfa_Bolsas")
  local D, V, Or, Se = Bo.Datos, Bo.Ventana, Bo.Oro, Bo.Sesion
  local dinero = 874512
  GetMoney = function() return dinero end
  local pers = D.Raiz().personajes
  local hace = function(d, h) return time() - d * 86400 - (h or 0) * 3600 end
  pers["Garra-Forever"] = { nombre = "Garra", reino = "Forever", faccion = "Horde", clase = "HUNTER", nivel = 42,
    dinero = 3124530, visto = hace(1, 3), bolsas = {}, banco = {}, equipo = {} }
  pers["Colmillo-Forever"] = { nombre = "Colmillo", reino = "Forever", faccion = "Horde", clase = "SHAMAN", nivel = 31,
    dinero = 462075, visto = hace(3), bolsas = {}, banco = {}, equipo = {} }
  pers["Luna-Mankrik"] = { nombre = "Luna", reino = "Mankrik", faccion = "Alliance", clase = "PRIEST", nivel = 27,
    dinero = 1283340, visto = hace(6), bolsas = {}, banco = {}, equipo = {} }
  D.GuardarCabecera()
  GetRealZoneText = function() return "Los Baldíos" end
  GetZoneText = function() return "Los Baldíos" end
  -- La mochila de un cazador de nivel 23 en Los Baldíos.
  local OBJ = {
    [2592] = { "Paño de lana", 7, 5, "", 1, 33, 14 }, [2319] = { "Cuero medio", 7, 6, "", 1, 15, 18 },
    [858] = { "Poción de sanación inferior", 0, 1, "", 1, 25, 5 }, [1179] = { "Agua helada", 0, 5, "", 1, 6, 12 },
    [2770] = { "Mineral de cobre", 7, 7, "", 1, 5, 9 }, [1206] = { "Ágata musgosa", 7, 7, "", 2, 100, 1 },
    [5117] = { "Colmillo vibrante", 15, 0, "", 0, 85, 3 }, [4865] = { "Garra rota", 15, 0, "", 0, 5, 6 },
    [2515] = { "Flecha afilada", 6, 2, "INVTYPE_AMMO", 1, 1, 200 },
  }
  local orden = { 2592, 2319, 858, 1179, 2770, 1206, 5117, 4865 }
  local function enlace(id) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. OBJ[id][1] .. "]|h|r" end
  local function idDe(x) return tonumber(tostring(x):match("item:(%d+)") or x) end
  C_Item.GetItemInfo = function(x)
    local o = OBJ[idDe(x)]
    if not o then return nil end
    return o[1], enlace(idDe(x)), o[5], 20, 1, "Tipo", "Subtipo", 20, o[4], 134400, o[6], o[2], o[3], 0
  end
  C_Item.GetItemInfoInstant = function(x)
    local id = idDe(x)
    local o = OBJ[id]
    if not o then return id, "Objeto", "Objeto", "", 134400, 0, 0 end
    return id, "Tipo", "Subtipo", o[4], 134400, o[2], o[3]
  end
  C_Item.GetItemMaxStackSizeByID = function(id) return 20 end
  local bolsa = {}
  for s, id in ipairs(orden) do
    bolsa[s] = { itemID = id, stackCount = OBJ[id][7], quality = OBJ[id][5], hyperlink = enlace(id), isBound = false }
  end
  C_Container = C_Container or {}
  C_Container.GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end
  C_Container.GetContainerNumFreeSlots = function(b) if b == 0 then return 16 - #orden, 0 end return 0, 0 end
  C_Container.GetContainerItemInfo = function(b, s) return b == 0 and bolsa[s] or nil end
  C_Container.GetContainerItemLink = function(b, s) local i = b == 0 and bolsa[s] return i and i.hyperlink or nil end
  C_Container.GetContainerItemID = function(b, s) local i = b == 0 and bolsa[s] return i and i.itemID or nil end
  C_Container.GetContainerItemQuestInfo = function() return { isQuestItem = false } end
  C_Container.GetContainerItemCooldown = function() return 0, 0, 0 end
  -- La sesión empieza aquí (con el dinero de muestra).
  if Se.OlvidarCarga then Se.OlvidarCarga() end
  FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
  FIRE_EVENT("BAG_UPDATE", 0)
  RUN_TIMERS(3)
  V.MostrarBolsas(true)
  RUN_TIMERS(4)
  -- Una hora de farmeo: lo ganado, lo gastado y el botín.
  NOW = NOW + 3000
  dinero = dinero + 236500 FIRE_EVENT("PLAYER_MONEY")
  dinero = dinero - 41200 FIRE_EVENT("PLAYER_MONEY")
  rawset(_G, "LOOT_ITEM_SELF", rawget(_G, "LOOT_ITEM_SELF") or "Recibes botín: %s.")
  rawset(_G, "LOOT_ITEM_SELF_MULTIPLE", rawget(_G, "LOOT_ITEM_SELF_MULTIPLE") or "Recibes botín: %sx%d.")
  local precio = C_Item.GetItemInfo
  C_Item.GetItemInfo = function() return "Cuero medio", "x", 1, 20, 1, "Tipo", "Sub", 20, "", 134400, 315 end
  local link = "|cffffffff|Hitem:2319::::::::|h[Cuero medio]|h|r"
  for _ = 1, 6 do
    FIRE_EVENT("CHAT_MSG_LOOT", LOOT_ITEM_SELF_MULTIPLE:format(link, 3), "", "", "", "", "", "", 0, "", "", 0, UnitGUID("player"))
  end
  C_Item.GetItemInfo = precio
  NOW = NOW + 600
  local win = V.Ventana("bolsas")
  win.Monedas:Click()
  Or.Pintar()
  RUN_TIMERS(2)
  local p = Or.Panel()
  local esc = encuadre({ win, p }, 40)
  print("oro: ventana", win:GetWidth(), win:GetHeight(), "panel", p:GetWidth(), p:GetHeight())
  SNAP("137-oro", esc, { win, p })
  esc:Hide()
  win:Hide()
  p:Hide()
end)

print("pantalla", UIParent:GetWidth(), UIParent:GetHeight())

---------------------------------------------------------------------------
-- 2 y 3. Los anuncios: llegar a Los Baldíos, descubrir El Cruce, una mazmorra
---------------------------------------------------------------------------
local mundo = { zona = "Los Baldíos", sub = "", pvp = "friendly", inst = false, instTipo = "none", nivel = 23 }
local Z = N.Zonas
local function anuncio() return rawget(_G, "AlfaAnuncio") end
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
local function limpiarAnuncio()
  K.QuitarAnuncio()
  NOW = NOW + 10
  if Z and Z.Olvidar then Z.Olvidar() end
  RUN_TIMERS(2)
end
local zt, szt
local function snapAnuncio(nombre, abajo)
  local f = anuncio()
  if not (f and f:IsShown()) then NOTE("galeria137", "no salió el anuncio " .. nombre) return end
  -- Las rayas de luz son un degradado en el juego: que el banco lo pinte así.
  for _, t in ipairs({ f.RayaI, f.RayaD }) do if t then t._tex = "white" end end
  local esc = encuadre({ f }, 10, { l = 0, r = 0, t = 30, b = 40 + (abajo or 0) })
  SNAP(nombre, esc, { f })
  esc:Hide()
end
step("anuncios: el mundo", function()
  A.Set("bienvenida.anuncios", true)
  if N.Entrando then N.Entrando = function() return false end end
  GetRealZoneText = function() return mundo.zona end
  GetZoneText = function() return mundo.zona end
  GetSubZoneText = function() return mundo.sub end
  C_PvP = C_PvP or {}
  C_PvP.GetZonePVPInfo = function() return mundo.pvp, false, nil end
  UnitOnTaxi = function() return false end
  InCombatLockdown = function() return false end
  IsResting = function() return false end
  IsInInstance = function() return mundo.inst, mundo.instTipo end
  UnitLevel = function() return mundo.nivel end
  if A.Maps then A.Maps.GetZoneLevels = function() return 10, 25 end end
  zt = rawget(_G, "ZoneTextFrame")
  if not (type(zt) == "table" and type(zt.Show) == "function") then rawset(_G, "ZoneTextFrame", nil) zt = CreateFrame("Frame", "ZoneTextFrame", UIParent) end
  szt = rawget(_G, "SubZoneTextFrame")
  if not (type(szt) == "table" and type(szt.Show) == "function") then rawset(_G, "SubZoneTextFrame", nil) szt = CreateFrame("Frame", "SubZoneTextFrame", UIParent) end
  zt:Hide() szt:Hide()
end)

step("anuncio: zona", function()
  limpiarAnuncio()
  mundo.zona, mundo.sub = "Los Baldíos", "El Cruce"
  zt:Show() zt:SetAlpha(1) szt:Show() szt:SetAlpha(1)
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  RUN_TIMERS(3)
  local a = K.AnuncioActual()
  print("zona:", a and a.estilo, a and a.titulo, a and a.texto)
  correr(1.6)
  snapAnuncio("137-zona")
  zt:Hide() szt:Hide()
end)

step("anuncio: descubrir", function()
  limpiarAnuncio()
  rawset(_G, "ERR_ZONE_EXPLORED_XP", "Descubriste %s: %d de experiencia ganada")
  rawset(_G, "ERR_ZONE_EXPLORED", "Descubriste: %s")
  local Lya = rawget(_G, "AlfaLya")
  if Lya then Lya.DatoDeZona = function() return "Aquí beben las caravanas que cruzan Los Baldíos." end end
  mundo.sub = "Oasis Estancado"
  NOW = NOW + 30
  FIRE_EVENT("CHAT_MSG_SYSTEM", "Descubriste Oasis Estancado: 185 de experiencia ganada")
  RUN_TIMERS(2)
  local a = K.AnuncioActual()
  print("descubrir:", a and a.estilo, a and a.titulo, a and a.texto)
  correr(1.2)
  snapAnuncio("137-descubrir", 30)
end)

step("anuncio: mazmorra", function()
  limpiarAnuncio()
  AlfaNucleoDB = AlfaNucleoDB or {}
  AlfaNucleoDB.mazmorras = AlfaNucleoDB.mazmorras or {}
  AlfaNucleoDB.mazmorras.entradas = AlfaNucleoDB.mazmorras.entradas or {}
  AlfaNucleoDB.mazmorras.entradas.cuevas = { nombre = "Cuevas de los Lamentos", min = 17, max = 24, jefes = 8 }
  mundo.inst, mundo.instTipo = true, "party"
  GetInstanceInfo = function() return "Cuevas de los Lamentos", "party", 1, "Normal", 5, 0, false, 43 end
  mundo.zona, mundo.sub = "Cuevas de los Lamentos", ""
  zt:Show() zt:SetAlpha(1)
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  RUN_TIMERS(3)
  local a = K.AnuncioActual()
  print("mazmorra:", a and a.estilo, a and a.titulo, a and a.texto)
  correr(1.6)
  snapAnuncio("137-mazmorra")
  mundo.inst, mundo.instTipo = false, "none"
  mundo.zona = "Los Baldíos"
  zt:Hide() szt:Hide()
  limpiarAnuncio()
end)

---------------------------------------------------------------------------
-- 4. El resumen de nivel
---------------------------------------------------------------------------
step("nivel", function()
  BANCO_MOMENTOS = true
  local capturado
  local aviso = K.Aviso
  K.Aviso = function(o)
    local r = aviso(o)
    if o and o.id == "nivel" and type(r) == "table" then capturado = r end
    return r
  end
  AlfaBuilds = AlfaBuilds or {}
  AlfaBuilds.SiguienteTalento = function() return { ahora = true, libres = 1, nombre = "Disparo apuntado", porque = "galería" } end
  A.QoL = A.QoL or {}
  A.QoL.Spells = A.QoL.Spells or {}
  local newAt = A.QoL.Spells.NewAt
  A.QoL.Spells.NewAt = function(l) if l == 12 then return { { id = 1 }, { id = 2 } } end return {} end
  mundo.nivel = 12
  RUN_TIMERS(30)
  FIRE_EVENT("PLAYER_LEVEL_UP", 12)
  for _ = 1, 20 do
    RUN_TIMERS(1)
    if capturado then break end
  end
  K.Aviso = aviso
  A.QoL.Spells.NewAt = newAt
  BANCO_MOMENTOS = nil
  if not capturado then NOTE("galeria137", "no salió el resumen de nivel") return end
  print("nivel:", capturado:GetWidth(), capturado:GetHeight())
  local esc = encuadre({ capturado }, 50)
  SNAP("137-nivel", esc, { capturado })
  esc:Hide()
  if capturado.Cerrar then capturado:Cerrar() end
  mundo.nivel = 23
  RUN_TIMERS(3)
end)

---------------------------------------------------------------------------
-- 5. El medidor de daño con tu grupo y el resumen de la pelea, junto a las barras
---------------------------------------------------------------------------
step("medidor", function()
  local M = NS_OF("Alfa_Combate")
  local V = M.Ventana
  IsInGroup = function() return true end
  IsInRaid = function() return false end
  UnitAffectingCombat = function() return false end
  Enum.DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, DamageTaken = 7 }
  Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }
  local grupo = {
    { "Garra", "HUNTER", 18450 }, { "Lobato", "WARRIOR", 15230, true }, { "Sombra", "ROGUE", 12980 },
    { "Colmillo", "SHAMAN", 9870 }, { "Brisa", "PRIEST", 4320 },
  }
  local fuentes, total = {}, 0
  for i, g in ipairs(grupo) do
    fuentes[i] = { name = g[1], classFilename = g[2], totalAmount = g[3], amountPerSecond = g[3] / 83, isLocalPlayer = g[4] or false }
    total = total + g[3]
  end
  C_DamageMeter = {
    IsDamageMeterAvailable = function() return true, "" end,
    GetCombatSessionFromType = function() return { combatSources = fuentes, maxAmount = 18450, totalAmount = total } end,
    GetCombatSessionFromID = function() return { combatSources = {} } end,
    GetAvailableCombatSessions = function() return {} end,
    GetSessionDurationSeconds = function() return 83 end,
  }
  GetCVar = function(n) if n == "damageMeterEnabled" then return "1" end return "0" end
  -- Las barras de acción (las del juego, simuladas): abajo y a la derecha.
  local function nombrada(nombre, n, tam, vertical, teclas)
    rawset(_G, nombre, nil)
    local b = barraAccion(UIParent, n, tam, vertical, teclas)
    rawset(_G, nombre, b)
    return b
  end
  local principal = nombrada("MainMenuBar", 12, 40, false, true)
  principal:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -110, 8)
  local abajo = nombrada("MultiBarBottomLeft", 12, 40, false, false)
  abajo:SetPoint("BOTTOM", principal, "TOP", 0, 4)
  local derecha = nombrada("MultiBarRight", 12, 36, true, false)
  derecha:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -4, 112)
  local izq = nombrada("MultiBarLeft", 12, 36, true, false)
  izq:SetPoint("RIGHT", derecha, "LEFT", -2, 0)
  N.Datos("combate").pos = nil
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  RUN_TIMERS(2)
  V.Ver()
  RUN_TIMERS(2)
  local med = rawget(_G, "AlfaCombateMedidor")
  print("medidor:", med and med:IsShown(), med and med:GetWidth(), med and med:GetHeight(), med and med:GetLeft(), med and med:GetBottom())
  M.Resumen.Pintar({ dur = 83, dano = 15230, dps = 183.5, golpe = { nombre = "Embestida", quien = "Jabaguerrero Rajacieno", cuanto = 412 } })
  local res = rawget(_G, "AlfaCombateResumen")
  -- Donde quedarían con estas barras: encima de las de abajo, a un lado de las de la derecha.
  med:ClearAllPoints()
  med:SetPoint("BOTTOMRIGHT", abajo, "TOPRIGHT", 0, 16)
  if res then
    res:ClearAllPoints()
    res:SetPoint("BOTTOMRIGHT", med, "BOTTOMLEFT", -16, 0)
  end
  -- El relleno de cada barra (el banco no dibuja las StatusBar): su color de clase y su parte del máximo.
  local Dm = M.Medidor
  for _, fila in ipairs(med.filas or {}) do
    local x, r = fila.alfaDato, fila.alfaLectura
    if fila:IsShown() and x and r then
      local t = fila.Barra:CreateTexture(nil, "BORDER")
      local cr, cg, cb = Dm.Color(x.clase)
      t:SetColorTexture(cr, cg, cb, 0.55)
      t:SetPoint("TOPLEFT", fila, "TOPLEFT", 0, 0)
      t:SetPoint("BOTTOMLEFT", fila, "BOTTOMLEFT", 0, 0)
      t:SetWidth(math.max(1, fila:GetWidth() * (tonumber(x.valor) or 0) / math.max(1, tonumber(r.max) or 1)))
    end
  end
  print("resumen:", res and res:IsShown(), res and res:GetLeft(), res and res:GetBottom())
  -- El encuadre: la esquina de abajo a la derecha, con las barras.
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  local esc = escenario(780, 620, 0.3)
  esc:ClearAllPoints()
  esc:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
  SNAP("137-medidor", esc, { principal, abajo, derecha, izq, med, res })
  esc:Hide()
  for _, b in ipairs({ principal, abajo, derecha, izq }) do b:Hide() end
  if res then res:Hide() end
  if med then med:Hide() end
  IsInGroup = function() return false end
end)

---------------------------------------------------------------------------
-- 6. La pesca: la espada «A pelear» sobre la barra, con su cuadro
---------------------------------------------------------------------------
step("pesca", function()
  local CANA, ESPADA, ESCUDO, GORRO, GORRO_PESCA = 6256, 2488, 2129, 1000, 1001
  local function enlace(id, nombre) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. nombre .. "]|h|r" end
  local L_CANA, L_ESPADA, L_ESCUDO, L_GORRO = enlace(CANA, "Caña de pescar"), enlace(ESPADA, "Hacha de guerra pesada"), enlace(ESCUDO, "Escudo de madera"), enlace(GORRO, "Yelmo de cuero")
  local INFO = {
    [CANA] = { "INVTYPE_2HWEAPON", 2, 20 }, [ESPADA] = { "INVTYPE_WEAPON", 2, 0 },
    [ESCUDO] = { "INVTYPE_SHIELD", 4, 6 }, [GORRO] = { "INVTYPE_HEAD", 4, 1 }, [GORRO_PESCA] = { "INVTYPE_HEAD", 4, 1 },
  }
  Enum.ItemClass = { Weapon = 2, Armor = 4, Consumable = 0 }
  Enum.ItemWeaponSubclass = { Fishingpole = 20 }
  local antes = C_Item.GetItemInfoInstant
  C_Item.GetItemInfoInstant = function(x)
    local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)"))
    local i = id and INFO[id]
    if not i then return antes(x) end
    return id, "", "", i[1], 134400, i[2], i[3]
  end
  local puesto = { [16] = L_CANA, [1] = enlace(GORRO_PESCA, "Sombrero de pesca") }
  GetInventoryItemLink = function(_, r) return puesto[r] end
  GetInventoryItemID = function(_, r) local l = puesto[r] return l and tonumber(l:match("item:(%d+)")) end
  C_Item.EquipItemByName = function(l, r) puesto[r] = l end
  local P = NS_OF("Alfa_Pesca")
  local d = N.DatosPersonaje("pesca")
  d.equipoNormal = { [16] = L_ESPADA, [17] = L_ESCUDO, [1] = L_GORRO }
  P.AbrirModo()
  RUN_TIMERS(5)
  P.Habilidad = function() return 142, 150, 0 end
  P.Barra.Desplegar()
  RUN_TIMERS(1)
  -- Algo te ataca mientras pescas: «A pelear».
  InCombatLockdown = function() return true end
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  RUN_TIMERS(1)
  P.Barra.Desplegar()
  local barra = P.Barra.Barra()
  local boton = rawget(_G, "AlfaPescaPelear")
  print("pesca:", barra and barra:IsShown(), boton and boton:IsShown(), P.Pelear and P.Pelear.Estado and P.Pelear.Estado())
  -- La espada (arte del juego, que el banco no tiene): unos pixeles en diagonal.
  if boton.Icono then
    boton.Icono:Hide()
    local function px(x, y, c)
      local t = boton:CreateTexture(nil, "OVERLAY")
      t:SetSize(2, 2)
      t:SetPoint("BOTTOMLEFT", boton, "CENTER", x - 9, y - 9)
      t:SetColorTexture(c[1], c[2], c[3], 1)
    end
    local hoja, filo, oro, mango = { 0.78, 0.82, 0.86 }, { 0.95, 0.97, 1 }, { 0.85, 0.68, 0.25 }, { 0.45, 0.28, 0.15 }
    for i = 6, 16, 1 do px(i, i, hoja) px(i + 1, i, filo) end
    px(2, 8, oro) px(4, 6, oro) px(6, 4, oro) px(8, 2, oro) px(3, 7, oro) px(5, 5, oro) px(7, 3, oro)
    px(3, 3, mango) px(1, 1, oro) px(2, 2, mango) px(4, 4, mango)
  end
  FIRE(boton, "OnEnter")
  local info
  for _, f in ipairs(ALL_FRAMES()) do if rawget(f, "dueno") == boton and f:IsShown() then info = f end end
  print("pesca info:", info ~= nil)
  local esc = encuadre({ barra, boton, info }, 36)
  SNAP("137-pesca", esc, { barra, boton, info })
  esc:Hide()
  FIRE(boton, "OnLeave")
  InCombatLockdown = function() return false end
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  P.CerrarModo()
  RUN_TIMERS(5)
  C_Item.GetItemInfoInstant = antes
end)

---------------------------------------------------------------------------
-- 7. Lo que me perdí
---------------------------------------------------------------------------
step("perdi", function()
  N.OlvidarPerdidos()
  local nada = function() end
  local lista = {
    { "21:15", { titulo = "Garra se conectó", texto = "Tu compañero de La Jauría está en Orgrimmar.", icono = "ic-manada" } },
    { "21:27", { titulo = "Tienes 3 misiones listas", texto = "Entrégalas en El Cruce antes de seguir tu ruta.", icono = "ic-misiones",
      accion = { texto = "Llévame", alClic = nada } } },
    { "21:38", { titulo = "Tus bolsas están casi llenas", texto = "Te quedan 2 espacios. Vende lo gris al comerciante.", icono = "ic-bolsas" } },
    { "21:44", { titulo = "Ishamuhale anda cerca", texto = "Raptor raro de nivel 19, al oeste de El Cruce.", icono = "ic-raros", origen = "anuncio",
      accion = { texto = "Llévame", alClic = nada } } },
    { "21:51", { titulo = "El barco a Bahía del Botín ya viene", texto = "Sale del muelle de Trinquete en menos de un minuto.", icono = "ic-ruta", origen = "anuncio" } },
  }
  for _, x in ipairs(lista) do
    local e = N.Perdido(x[2])
    if e then e.hora = x[1] end
  end
  N.VerPerdidos()
  RUN_TIMERS(2)
  local v = rawget(_G, "AlfaPerdidos")
  print("perdi:", v and v:IsShown(), v and v:GetWidth(), v and v:GetHeight())
  if not v then return end
  local esc = encuadre({ v }, 40)
  SNAP("137-perdi", esc, { v })
  esc:Hide()
  v:Hide()
end)

---------------------------------------------------------------------------
-- 8. La barra de información y los números de las recargas
---------------------------------------------------------------------------
step("info", function()
  local M = NS_OF("Alfa_Comodidades")
  local I, Rc = M.Info, M.Recargas
  rawset(_G, "GetNetStats", function() return 0, 0, 38, 52 end)
  rawset(_G, "GetFramerate", function() return 60 end)
  rawset(_G, "GetInventoryItemDurability", function(s) if s == 5 then return 62, 100 end if s == 1 then return 90, 100 end return nil end)
  N.Set("comodidades", "info", true)
  local b = rawget(_G, "AlfaComodidadesInfo")
  if I.Sesion then I.Sesion.ganada = 48200 end
  NOW = NOW + 1800
  RUN_TIMERS(2)
  print("info:", b and b:IsShown(), b and b:GetWidth(), b and b:GetHeight())
  -- Una barra de acción con recargas, debajo.
  local barra = barraAccion(UIParent, 12, 42, false, true)
  barra:SetPoint("TOP", b, "BOTTOM", 0, -36)
  local botones = {}
  for i, bt in ipairs(barra.botones) do
    local cd = CreateFrame("Frame", nil, bt)
    cd:SetAllPoints(bt)
    rawset(bt, "cooldown", cd)
    rawset(cd, "SetCooldown", function() end)
    rawset(cd, "Clear", function() end)
    botones[i] = bt
  end
  local antesLista = M.BotonesDeAccion
  M.BotonesDeAccion = function() return botones end
  N.Set("comodidades", "recargas", true)
  -- Lo que falta en cada una: largo, medio, casi y a punto.
  local faltan = { [2] = 95, [3] = 24, [5] = 8, [6] = 2.4, [9] = 312, [11] = 14 }
  for i, s in pairs(faltan) do botones[i].cooldown:SetCooldown(NOW - 1, s + 1) end
  Rc.Tic()
  -- El velo oscuro del juego sobre los botones en recarga.
  for i in pairs(faltan) do
    local v = botones[i]:CreateTexture(nil, "ARTWORK")
    v:SetDrawLayer("ARTWORK", 7)
    v:SetPoint("TOPLEFT", botones[i], "TOPLEFT", 2, -2)
    v:SetPoint("BOTTOMRIGHT", botones[i], "BOTTOMRIGHT", -2, 2)
    v:SetColorTexture(0, 0, 0, 0.55)
  end
  local esc = encuadre({ b, barra }, 40)
  SNAP("137-info", esc, { b, barra })
  esc:Hide()
  M.BotonesDeAccion = antesLista
  N.Set("comodidades", "recargas", false)
  barra:Hide()
end)

print("errores en galeria137:", #ERRORS - before)
for i = before + 1, math.min(#ERRORS, before + 10) do print(tostring(ERRORS[i]):sub(1, 800)) end
