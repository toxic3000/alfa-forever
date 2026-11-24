-- Escenas de la 1.3.8 (Dos pantallas): la ventana del juego sobre dos monitores
-- con el mundo y la interfaz del juego en el principal y el Escritorio de Alfa
-- en el otro; el asistente, la prueba, el editor y el catálogo; 3840 x 1080 y
-- 5120 x 1440. Datos de muestra (Lobato y su manada), nada de ningún jugador real.
-- El mundo va con una noche con colinas (nada de fondo verde liso).
--   .venv/Scripts/python -I tools/banco/run.py <dist> <módulos> galeria138.lua
SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["138-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
PANTALLA_SIMULADA(3840, 1080)
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N, B = AlfaNucleo, AlfaBienvenida
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(6)
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
local A = Alfa
local K = N.Kit
for clase, c in pairs({ WARRIOR = { 0.78, 0.61, 0.43 }, HUNTER = { 0.67, 0.83, 0.45 }, SHAMAN = { 0.0, 0.44, 0.87 },
  PRIEST = { 1, 1, 1 }, ROGUE = { 1, 0.96, 0.41 }, MAGE = { 0.25, 0.78, 0.92 }, DRUID = { 1, 0.49, 0.04 },
  PALADIN = { 0.96, 0.55, 0.73 }, WARLOCK = { 0.53, 0.53, 0.93 } }) do
  RAID_CLASS_COLORS[clase] = { r = c[1], g = c[2], b = c[3], colorStr = string.format("ff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) }
end
if A.UI.Options.frame then A.UI.Options.frame:Hide() end
-- Que no salga nada encima (avisos y Lya fuera de la foto).
for _, n in ipairs({ "AlfaLyaLoba", "AlfaInicioAviso", "AlfaRastreador", "AlfaNavArrow" }) do
  local f = rawget(_G, n)
  if type(f) == "table" and f.Hide then f:Hide() end
end
-- Lo que el banco pone y el juego no (sus chats de prueba) y lo de Alfa que tapa la foto.
local function limpiar()
  for i = 1, 10 do
    for _, n in ipairs({ "ChatFrame" .. i, "ChatFrame" .. i .. "Tab" }) do
      local f = rawget(_G, n)
      if type(f) == "table" and f.Hide then f:Hide() end
    end
  end
  for _, n in ipairs({ "AlfaLyaLoba", "AlfaInicioAviso", "AlfaRastreador", "AlfaNavArrow", "Minimap", "MinimapCluster" }) do
    local f = rawget(_G, n)
    if type(f) == "table" and f.Hide then f:Hide() end
  end
  -- Lo que va pegado al minimapa del banco.
  for _, c in ipairs({ UIParent:GetChildren() }) do
    local _, rel = c:GetPoint(1)
    if rel and rel == rawget(_G, "Minimap") then c:Hide() end
  end
end
local snap0 = SNAP
SNAP = function(...) limpiar() return snap0(...) end
local Bv = NS_OF("Alfa_Bienvenida")
local Es, Ed, As = Bv.Escritorio, Bv.EscritorioEditor, Bv.EscritorioAsistente

---------------------------------------------------------------------------
-- El mundo: una noche con su luna, colinas y un camino (hijo de WorldFrame)
---------------------------------------------------------------------------
local semilla = 11
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
local mundo
local function pintarMundo()
  if mundo then mundo:Hide() end
  local w, h = WorldFrame:GetWidth(), WorldFrame:GetHeight()
  local f = CreateFrame("Frame", nil, WorldFrame)
  f:SetAllPoints(WorldFrame)
  f:SetFrameStrata("BACKGROUND")
  local cielo = capa(f, "BACKGROUND", -8)
  cielo:SetAllPoints(f)
  degradado(cielo, "VERTICAL", { 0.05, 0.07, 0.08 }, { 0.10, 0.14, 0.20 })
  for _ = 1, math.floor(w * h * 0.3 / 3000) do
    local s = capa(f, "BACKGROUND", -7)
    local tam = azar() < 0.85 and 1 or 2
    s:SetSize(tam, tam)
    s:SetPoint("TOPLEFT", f, "TOPLEFT", azar() * w, -azar() * h * 0.45)
    local v = 0.6 + azar() * 0.4
    s:SetColorTexture(v, v, v * 1.05, 0.25 + azar() * 0.5)
  end
  local luna = capa(f, "BACKGROUND", -6)
  luna:SetTexture("circle")
  luna:SetSize(h * 0.11, h * 0.11)
  luna:SetPoint("CENTER", f, "TOPLEFT", w * 0.72, -h * 0.2)
  luna:SetVertexColor(0.86, 0.88, 0.82, 0.9)
  local halo = capa(f, "BACKGROUND", -7)
  halo:SetTexture("circle")
  halo:SetSize(h * 0.3, h * 0.3)
  halo:SetPoint("CENTER", luna, "CENTER", 0, 0)
  halo:SetVertexColor(0.5, 0.6, 0.7, 0.08)
  local function colina(cx, cy, rx, ry, c)
    local t = capa(f, "BACKGROUND", -4)
    t:SetTexture("circle")
    t:SetSize(rx * 2, ry * 2)
    t:SetPoint("CENTER", f, "BOTTOMLEFT", cx, cy)
    t:SetVertexColor(c[1], c[2], c[3], 1)
  end
  colina(w * 0.2, -h * 0.02, w * 0.45, h * 0.36, { 0.07, 0.09, 0.08 })
  colina(w * 0.8, -h * 0.06, w * 0.55, h * 0.42, { 0.06, 0.08, 0.075 })
  colina(w * 0.5, -h * 0.22, w * 0.7, h * 0.4, { 0.045, 0.06, 0.05 })
  -- Un fuego de campamento a lo lejos.
  local fuego = capa(f, "BACKGROUND", -3)
  fuego:SetTexture("circle")
  fuego:SetSize(h * 0.05, h * 0.05)
  fuego:SetPoint("CENTER", f, "BOTTOMLEFT", w * 0.42, h * 0.2)
  fuego:SetVertexColor(0.95, 0.55, 0.2, 0.35)
  local fuego2 = capa(f, "BACKGROUND", -2)
  fuego2:SetTexture("circle")
  fuego2:SetSize(h * 0.012, h * 0.012)
  fuego2:SetPoint("CENTER", fuego, "CENTER", 0, 0)
  fuego2:SetVertexColor(1, 0.8, 0.4, 0.9)
  f:Show()
  mundo = f
end

---------------------------------------------------------------------------
-- La interfaz del juego simulada (hija de UIParent: se va con él)
---------------------------------------------------------------------------
local TONOS = {
  { 0.55, 0.22, 0.12 }, { 0.62, 0.48, 0.16 }, { 0.2, 0.36, 0.55 }, { 0.42, 0.2, 0.45 },
  { 0.25, 0.45, 0.22 }, { 0.6, 0.3, 0.18 }, { 0.3, 0.3, 0.38 }, { 0.5, 0.15, 0.15 },
  { 0.18, 0.4, 0.42 }, { 0.55, 0.5, 0.35 }, { 0.35, 0.22, 0.12 }, { 0.28, 0.32, 0.5 },
}
local function caja(padre, w, h, r, g, b, a)
  local f = CreateFrame("Frame", nil, padre)
  f:SetSize(w, h)
  local t = capa(f, "BACKGROUND")
  t:SetAllPoints(f)
  t:SetColorTexture(r, g, b, a or 1)
  f:Show()
  return f
end
local function barra(padre, n, tam)
  local f = caja(padre, n * (tam + 4) + 4, tam + 8, 0, 0, 0, 0.45)
  for i = 1, n do
    local c = TONOS[(i - 1) % #TONOS + 1]
    local bt = caja(f, tam, tam, 0.02, 0.02, 0.025, 1)
    bt:SetPoint("LEFT", f, "LEFT", 4 + (i - 1) * (tam + 4), 0)
    local ic = capa(bt, "BORDER")
    ic:SetPoint("TOPLEFT", bt, "TOPLEFT", 2, -2)
    ic:SetPoint("BOTTOMRIGHT", bt, "BOTTOMRIGHT", -2, 2)
    degradado(ic, "VERTICAL", { c[1] * 0.5, c[2] * 0.5, c[3] * 0.5 }, { c[1], c[2], c[3] })
  end
  return f
end
local function texto(padre, s, tam, r, g, b)
  local t = padre:CreateFontString(nil, "OVERLAY")
  t:SetFont("Fonts\\FRIZQT__.TTF", tam or 12, "OUTLINE")
  t:SetText(s)
  t:SetTextColor(r or 1, g or 0.82, b or 0)
  return t
end
local uiJuego
local function interfazJuego()
  if uiJuego then return uiJuego end
  local ui = CreateFrame("Frame", nil, UIParent)
  uiJuego = ui
  ui:SetAllPoints(UIParent)
  ui:SetFrameStrata("LOW")
  local b1 = barra(ui, 12, 40)
  b1:SetPoint("BOTTOM", ui, "BOTTOM", 0, 10)
  local b2 = barra(ui, 12, 40)
  b2:SetPoint("BOTTOM", b1, "TOP", 0, 2)
  local xp = caja(ui, 12 * 44 + 4, 8, 0.25, 0.2, 0.45, 0.95)
  xp:SetPoint("BOTTOM", b1, "BOTTOM", 0, -9)
  -- Tu retrato.
  local yo = caja(ui, 232, 74, 0, 0, 0, 0.55)
  yo:SetPoint("TOPLEFT", ui, "TOPLEFT", 24, -24)
  local cara = capa(yo, "ARTWORK")
  cara:SetTexture("circle")
  cara:SetSize(62, 62)
  cara:SetPoint("LEFT", yo, "LEFT", 6, 0)
  cara:SetVertexColor(0.45, 0.3, 0.22, 1)
  local nom = texto(yo, "Lobato", 13)
  nom:SetPoint("TOPLEFT", yo, "TOPLEFT", 78, -8)
  local vida = caja(yo, 140, 14, 0.1, 0.65, 0.15, 1)
  vida:SetPoint("TOPLEFT", yo, "TOPLEFT", 78, -28)
  local rabia = caja(yo, 140, 10, 0.7, 0.1, 0.1, 1)
  rabia:SetPoint("TOPLEFT", vida, "BOTTOMLEFT", 0, -3)
  local nivel = texto(yo, "23", 11, 1, 0.9, 0.3)
  nivel:SetPoint("BOTTOMLEFT", yo, "BOTTOMLEFT", 8, 4)
  -- El minimapa.
  local mm = CreateFrame("Frame", nil, ui)
  mm:SetSize(170, 170)
  mm:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -24, -30)
  local aro = capa(mm, "BORDER")
  aro:SetTexture("circle")
  aro:SetAllPoints(mm)
  aro:SetVertexColor(0.55, 0.45, 0.28, 1)
  local adentro = capa(mm, "ARTWORK")
  adentro:SetTexture("circle")
  adentro:SetPoint("TOPLEFT", mm, "TOPLEFT", 6, -6)
  adentro:SetPoint("BOTTOMRIGHT", mm, "BOTTOMRIGHT", -6, 6)
  adentro:SetVertexColor(0.2, 0.28, 0.16, 1)
  local zona = texto(ui, "Durotar", 12)
  zona:SetPoint("BOTTOM", mm, "TOP", 0, 4)
  mm:Show()
  -- El chat.
  local chat = caja(ui, 440, 180, 0, 0, 0, 0.35)
  chat:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 24, 110)
  local lineas = { { "[General] Garrafuerte: ¿alguien para Rajacieno?", 1, 0.75, 0.75 },
    { "Recibes botín: [Carne de jabalí].", 0, 0.67, 0 }, { "[Hermandad] Sombraluna: ¡grr! ya casi llego", 0.25, 1, 0.25 },
    { "Tu habilidad en Desuello ha subido a 87.", 0.4, 0.4, 1 } }
  for i, l in ipairs(lineas) do
    local t = texto(chat, l[1], 12, l[2], l[3], l[4])
    t:SetPoint("BOTTOMLEFT", chat, "BOTTOMLEFT", 8, 8 + (#lineas - i) * 18)
  end
  -- El seguimiento de misiones.
  local seg = CreateFrame("Frame", nil, ui)
  seg:SetSize(260, 120)
  seg:SetPoint("TOPRIGHT", mm, "BOTTOMRIGHT", 0, -40)
  local m1 = texto(seg, "Carne de jabalí", 13)
  m1:SetPoint("TOPLEFT", seg, "TOPLEFT", 0, 0)
  local m2 = texto(seg, "- Carne de jabalí: 4/6", 12, 0.9, 0.9, 0.9)
  m2:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 8, -4)
  local m3 = texto(seg, "Cosecha de sangre", 13)
  m3:SetPoint("TOPLEFT", m2, "BOTTOMLEFT", -8, -10)
  local m4 = texto(seg, "- Jabalíes moteados: 6/8", 12, 0.9, 0.9, 0.9)
  m4:SetPoint("TOPLEFT", m3, "BOTTOMLEFT", 8, -4)
  seg:Show()
  ui:Show()
  return ui
end

---------------------------------------------------------------------------
-- Los datos de muestra de cada panel
---------------------------------------------------------------------------
local I, R, Ly, C, Pe, Bo = AlfaInicio, AlfaRuta, AlfaLya, AlfaCombate, AlfaPesca, AlfaBolsas
I.Paso = function() return { guia = "Durotar · niveles 10 a 15", hechos = 14, todos = 40, num = 15, total = 40,
  titulo = "Entrega «Carne de jabalí» a Grimtak en Aldea Razor",
  metas = { { t = "kill", texto = "Jabalíes moteados: 6/8" }, { t = "collect", texto = "Carne de jabalí: 4/6" },
    { t = "turnin", texto = "Habla con Grimtak" } } } end
I.Distancia = function() return "142 yardas al noreste", "neutro", "Grimtak" end
I.Alertas = function() return {
  { titulo = "Tus bolsas están casi llenas", texto = "Te quedan 3 de 64 espacios", icono = "ic-bolsas", tono = "aviso" },
  { titulo = "Tienes habilidades nuevas", texto = "2 habilidades por aprender en Orgrimmar", icono = "ic-nivel", tono = "acento" } } end
I.Numeros = function() return {
  { titulo = "XP por hora", valor = "18,420", texto = "Tu ritmo de los últimos 15 minutos" },
  { titulo = "Para subir de nivel", valor = "38 min", texto = "Te faltan 11,560 XP" },
  { titulo = "Oro de hoy", valor = N.Dinero(21460, true), texto = "Ganado " .. N.Dinero(26800, true) },
  { titulo = "Esta sesión", valor = "1 h 12 min", texto = "6 misiones entregadas" } } end
I.Sesion = function() return { dur = 4320 } end
I.Jugado = function() return { total = 3 * 86400 + 5 * 3600 } end
R.ListaEnCurso = function() return {
  { tipo = "guia", nombre = "Durotar (10-15)", activa = true, paso = 15, pasos = 40 },
  { tipo = "guia", nombre = "Los Baldíos (15-20)", paso = 1, pasos = 52 },
  { tipo = "plan", nombre = "Mi plan: Desuello a 150", hechos = 2, total = 5 } } end
R.LineaEnCurso = function(it)
  if it.tipo == "plan" then return "2 de 5 metas" end
  return string.format("Paso %d de %d", it.paso, it.pasos) .. (it.activa and "  ·  la sigues ahora" or "  ·  la tocaste hace 2 h")
end
local engine = A.Engine
engine.GetLiveStep = function() return 15 end
local SIG = { [16] = "Mata 8 jabalíes moteados al sur de Aldea Razor", [17] = "Recoge 6 frutos de cactus",
  [18] = "Entrega «Frutos de cactus» a Gadrin", [19] = "Vuela a Orgrimmar", [20] = "Aprende tus habilidades nuevas" }
local gsv = engine.GetStepView
engine.GetStepView = function(i) if SIG[i] then return { title = SIG[i], goals = {} } end return gsv and gsv(i) end
A.UI.StepSummary = function(v) return v.title end
A.Nav = A.Nav or {}
A.Nav.GetTarget = function() return { label = "Grimtak", r = 8 } end
A.Nav.TargetOffset = function() return 100, -100 end
GetPlayerFacing = function() return 0.4 end
GetUnitSpeed = function() return 7 end
N.Avisos = function() return {
  { titulo = "Un raro cerca: Lomo Rojo", texto = "Al este del Valle de los Retos. Lya lo olió primero.", icono = "ic-raros", hora = "21:42" },
  { titulo = "Subiste a nivel 23", texto = "Tu talento: Golpe heroico mejorado", icono = "ic-nivel", hora = "21:18", visto = true },
  { titulo = "Barco a Bahía del Botín en 2 min", texto = "Desde el muelle de Trinquete", icono = "ic-mapa", hora = "20:55", visto = true },
  { titulo = "Sombraluna te saluda", texto = "De la manada, en Orgrimmar", icono = "ic-manada", hora = "20:31", visto = true } } end
N.IrDeAviso = function() return nil end
Ly.Historial = function() return {
  { texto = "¡Olí algo! Lomo Rojo anda al este, por el Valle de los Retos. ¿Vamos de caza?", hora = "21:42" },
  { texto = "Los jabalíes de aquí son tercos, pero su carne es de lo mejor para tu cocina.", hora = "21:30" },
  { texto = "Ya casi llenas tus bolsas: vende lo gris en Aldea Razor.", hora = "21:12" } } end
C.LeerMedidor = function() return { ok = true, max = 428, total = 1500, filas = {
  { pos = 1, nombre = "Lobato", clase = "WARRIOR", yo = true, valor = 12840, porSeg = 428 },
  { pos = 2, nombre = "Kaelith", clase = "MAGE", valor = 11200, porSeg = 373 },
  { pos = 3, nombre = "Garra", clase = "HUNTER", valor = 9800, porSeg = 327 },
  { pos = 4, nombre = "Colmillo", clase = "SHAMAN", valor = 6120, porSeg = 204 },
  { pos = 5, nombre = "Sombraluna", clase = "PRIEST", valor = 2100, porSeg = 70 } } } end
local lm = C.LeerMedidor
local filasMax = 428
C.LeerMedidor = function(s, t)
  local r = lm()
  if t == "dps" or t == nil then for _, f in ipairs(r.filas) do f.valor = f.porSeg end r.max = filasMax end
  return r
end
C.NumeroMedidor = function(v) return v and (v >= 1000 and string.format("%.1fK", v / 1000) or tostring(v)) or "" end
C.UltimaPelea = function() return { dur = 42, dano = 12840, dps = 305, cura = 1220, cps = 29,
  golpe = { nombre = "Embestida", quien = "Señor de los Jabalíes", cuanto = 1180 }, cuando = time() - 95 } end
Pe.Activo = function() return false end
Pe.Estado = function() return { texto = "Buen lanzamiento  ·  Pulsa F al salpicar", tono = "acento" } end
Pe.Habilidad = function() return "Aprendiz 126/150", 126, 150 end
Pe.Sesion = function() return { capturas = 23, lanzamientos = 29, valor = 3460 }, { exito = 0.79, porHora = 46 } end
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b <= 4 and 16 or 0 end
C_Container.GetContainerNumFreeSlots = function(b) return b == 0 and 1 or (b == 1 and 2 or 0), 0 end
Bo.Sesion = function() return { ganado = 26800, porHora = 22300, botin = 37, valor = 8450 } end
Bo.OroCuenta = function() return 845600 end
GetMoney = function() return 312455 end
GetGameTime = function() return 21, 44 end
GetZoneText = function() return "Durotar" end
GetSubZoneText = function() return "Aldea Razor" end
local unidades = { player = { "Lobato", "WARRIOR", 23, 0.86 }, party1 = { "Kaelith", "MAGE", 22, 0.64 },
  party2 = { "Garra", "HUNTER", 23, 1 }, party3 = { "Colmillo", "SHAMAN", 21, 0.42 }, party4 = { "Sombraluna", "PRIEST", 22, 0.95 } }
local enGrupo = false
IsInGroup = function() return enGrupo end
GetNumGroupMembers = function() return enGrupo and 5 or 0 end
UnitExists = function(u) return enGrupo and unidades[u] ~= nil or u == "player" end
UnitName = function(u) local x = unidades[u] return x and x[1] or nil end
UnitClass = function(u) local x = unidades[u] return x and x[1], x and x[2] end
UnitLevel = function(u) local x = unidades[u] return x and x[3] or 23 end
UnitHealth = function(u) local x = unidades[u] return x and math.floor(x[4] * 1000) or 0 end
UnitHealthMax = function() return 1000 end
-- El mapa de Alfa: su arte es del juego y el banco no lo tiene; aquí va un
-- mapa dibujado (tierra, agua, la ruta y tú) en la misma ventana de Alfa.
do
  local f = CreateFrame("Frame", "AlfaMundoMapa", UIParent)
  f:SetFrameStrata("HIGH")
  f:SetSize(760, 560)
  f.caja = K.Caja(f, { fondo = "fondo", borde = "linea", corte = K.CORTE.ventana })
  local cab = CreateFrame("Frame", nil, f)
  cab:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  cab:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  cab:SetHeight(34)
  local ic = K.Icono(cab, "ic-mapa", 16, "acento")
  ic:SetPoint("LEFT", cab, "LEFT", 12, 0)
  local ti = K.Texto(cab, "encabezado", "texto")
  ti:SetPoint("LEFT", ic, "RIGHT", 8, 0)
  K.Escribir(ti, "Durotar")
  local vista = CreateFrame("Frame", nil, f)
  vista:SetPoint("TOPLEFT", cab, "BOTTOMLEFT", 2, 0)
  vista:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
  vista:SetClipsChildren(true)
  local mar = capa(vista, "BACKGROUND", -6)
  mar:SetAllPoints(vista)
  degradado(mar, "HORIZONTAL", { 0.07, 0.13, 0.18 }, { 0.05, 0.10, 0.15 })
  local function mancha(x, y, w, h, c, sub)
    local t = capa(vista, "BACKGROUND", sub or -4)
    t:SetTexture("circle")
    t:SetSize(w, h)
    t:SetPoint("CENTER", vista, "TOPLEFT", x, -y)
    t:SetVertexColor(c[1], c[2], c[3], 1)
    return t
  end
  -- La tierra roja de Durotar, sus cerros y la costa (todo dentro de la vista).
  mancha(200, 190, 330, 330, { 0.36, 0.24, 0.16 })
  mancha(150, 110, 200, 170, { 0.40, 0.27, 0.17 }, -3)
  mancha(250, 250, 220, 160, { 0.33, 0.22, 0.15 }, -3)
  mancha(110, 250, 110, 110, { 0.27, 0.19, 0.13 }, -2)
  mancha(205, 175, 80, 70, { 0.30, 0.34, 0.18 }, -2)
  mancha(300, 120, 60, 46, { 0.28, 0.20, 0.14 }, -2)
  mancha(420, 260, 40, 26, { 0.30, 0.22, 0.15 }, -2)
  -- La ruta (puntos) y el destino.
  local ruta = { { 120, 258 }, { 138, 246 }, { 156, 234 }, { 174, 222 }, { 192, 210 }, { 212, 198 }, { 232, 186 }, { 252, 174 }, { 272, 164 } }
  for _, q in ipairs(ruta) do
    local d = capa(vista, "ARTWORK")
    d:SetTexture("circle")
    d:SetSize(6, 6)
    d:SetPoint("CENTER", vista, "TOPLEFT", q[1], -q[2])
    d:SetVertexColor(0.55, 0.88, 0.31, 0.95)
  end
  local pin = capa(vista, "OVERLAY")
  pin:SetTexture("circle")
  pin:SetSize(14, 14)
  pin:SetPoint("CENTER", vista, "TOPLEFT", 288, -156)
  pin:SetVertexColor(0.95, 0.82, 0.42, 1)
  local pin2 = capa(vista, "OVERLAY")
  pin2:SetTexture("circle")
  pin2:SetSize(6, 6)
  pin2:SetPoint("CENTER", pin, "CENTER", 0, 0)
  pin2:SetVertexColor(0.2, 0.15, 0.05, 1)
  local yo = capa(vista, "OVERLAY")
  yo:SetTexture("Interface\AddOns\Alfa\Media\Nav\arrow")
  yo:SetSize(22, 22)
  yo:SetPoint("CENTER", vista, "TOPLEFT", 112, -264)
  yo:SetVertexColor(1, 1, 1, 1)
  for _, z in ipairs({ { "Aldea Razor", 300, 136 }, { "Valle de los Retos", 110, 300 }, { "Orgrimmar", 150, 52 }, { "Mar sin Fin", 330, 330 } }) do
    local t = K.Texto(vista, "pequeno", "textoSuave", "OVERLAY")
    t:SetPoint("CENTER", vista, "TOPLEFT", z[2], -z[3])
    t:SetText(z[1])
  end
  f:Hide()
  local Mu = rawget(_G, "AlfaMundo")
  if Mu then
    Mu.Abrir = function() f:Show() end
    Mu.Cerrar = function() f:Hide() end
  end
end

---------------------------------------------------------------------------
-- 1. Antes: la ventana de 32:9 con el asistente
---------------------------------------------------------------------------
step("asistente", function()
  pintarMundo()
  interfazJuego()
  As.Abrir()
  As.Paso(2)
  RUN_TIMERS(2)
  SNAP("asistente", As.Ventana())
  As.Paso(1)
  SNAP("asistente-pantalla", As.Ventana())
  As.Paso(2)
  SNAP("antes-pantalla-completa", Es.Referencia(), { WorldFrame, UIParent })
end)

---------------------------------------------------------------------------
-- 2. Probar: «¿Se ve bien?»
---------------------------------------------------------------------------
step("probar", function()
  As.Probar()
  pintarMundo()
  RUN_TIMERS(3)
  SNAP("probando", Es.Referencia(), { WorldFrame, UIParent })
  Es.Confirmar()
  RUN_TIMERS(2)
end)

---------------------------------------------------------------------------
-- 3. Aventura, Mazmorra, Pesca y Comercio en 3840 x 1080
---------------------------------------------------------------------------
step("aventura", function()
  Es.Usar("aventura", "jugador")
  RUN_TIMERS(2)
  SNAP("aventura", Es.Referencia(), { WorldFrame, UIParent })
  SNAP("escritorio-aventura", Es.Marco(), { rawget(_G, "AlfaMundoMapa") })
end)
step("mazmorra", function()
  enGrupo = true
  Es.Usar("mazmorra", "jugador")
  RUN_TIMERS(2)
  SNAP("escritorio-mazmorra", Es.Marco(), { rawget(_G, "AlfaMundoMapa") })
  enGrupo = false
end)
step("pesca", function()
  Pe.Activo = function() return true end
  Es.Usar("pesca", "jugador")
  RUN_TIMERS(2)
  SNAP("escritorio-pesca", Es.Marco(), { rawget(_G, "AlfaMundoMapa") })
  Pe.Activo = function() return false end
end)
step("comercio", function()
  Es.Usar("comercio", "jugador")
  RUN_TIMERS(2)
  SNAP("escritorio-comercio", Es.Marco(), { rawget(_G, "AlfaMundoMapa") })
end)

---------------------------------------------------------------------------
-- 4. El editor con el catálogo y un panel a medio arrastrar
---------------------------------------------------------------------------
step("editor", function()
  A.Set("pantallas.auto", false)
  Es.Usar("aventura", "jugador")
  Ed.Abrir(true)
  RUN_TIMERS(2)
  local px, py = 0, 0
  local origCursor = GetCursorPosition
  GetCursorPosition = function() return px, py end
  local p = Es.Marcos.avisos
  for _, f in ipairs({ Es.Marco().Area:GetChildren() }) do
    if f.Esquina and f:GetLeft() and math.abs(f:GetLeft() - p:GetLeft()) < 1 and math.abs(f:GetTop() - p:GetTop()) < 1 then
      f:GetScript("OnMouseDown")(f, "LeftButton")
      local cw, ch = Es.Celda()
      px, py = cw * 1.4, -ch * 0.7
      f:GetScript("OnUpdate")(f, 0.1)
      SNAP("editor", Es.Marco(), { rawget(_G, "AlfaMundoMapa") })
      Ed.Soltar()
    end
  end
  GetCursorPosition = origCursor
  Ed.Cerrar()
  Es.Restablecer()
end)

---------------------------------------------------------------------------
-- 5. Los estilos
---------------------------------------------------------------------------
step("estilos", function()
  for _, e in ipairs({ "clasico", "cristal" }) do
    K.SetEstilo(e)
    RUN_TIMERS(2)
    Es.Acomodar()
    for _, p in pairs(Es.Marcos) do if p:IsShown() then Es.PintarPanel(p, true) end end
    SNAP("escritorio-" .. e, Es.Marco(), { rawget(_G, "AlfaMundoMapa") })
  end
  K.SetEstilo("alfa")
  RUN_TIMERS(2)
end)

---------------------------------------------------------------------------
-- 6. 5120 x 1440 (dos de 2560 x 1440)
---------------------------------------------------------------------------
step("5120", function()
  PANTALLA_SIMULADA(5120, 1440)
  FIRE_EVENT("DISPLAY_SIZE_CHANGED")
  RUN_TIMERS(3)
  pintarMundo()
  interfazJuego()
  Es.Usar("aventura", "jugador")
  RUN_TIMERS(2)
  SNAP("aventura-5120", Es.Referencia(), { WorldFrame, UIParent })
end)

---------------------------------------------------------------------------
-- 7. Una sola pantalla: el escritorio a un lado
---------------------------------------------------------------------------
step("una", function()
  PANTALLA_SIMULADA(2560, 1440)
  A.Set("pantallas.proporcion", "medida")
  A.Set("pantallas.medida", 68)
  FIRE_EVENT("DISPLAY_SIZE_CHANGED")
  RUN_TIMERS(3)
  Es.Aplicar()
  pintarMundo()
  interfazJuego()
  RUN_TIMERS(2)
  SNAP("una-pantalla", Es.Referencia(), { WorldFrame, UIParent })
end)
print("galeria138 lista")
