-- The game's API, as much as Alfa's windows need of it.
UIP = CreateFrame("Frame", "UIParent")
UIP._parent = nil
UIParent = UIP
WorldFrame = CreateFrame("Frame", "WorldFrame")
-- 1.3.8: el mundo no tiene padre y llena la pantalla, como en el juego.
WorldFrame:SetParent(nil)
WorldFrame:SetAllPoints()
UISpecialFrames = {}
ADDON_META, LOADED = {}, {}
local nsByAddon = {}
function NS_OF(name) nsByAddon[name] = nsByAddon[name] or {} return nsByAddon[name] end

NOW = 1000
function GetTime() return NOW end
function GetServerTime() return 1700000000 end
time = os.time
date = os.date
function GetLocale() return "esMX" end
-- Los nombres de las marcas de banda (globales del juego).
for i, n in ipairs({ "Estrella", "Círculo", "Diamante", "Triángulo", "Luna", "Cuadrado", "Cruz", "Calavera" }) do _G["RAID_TARGET_" .. i] = n end
function AlfaIdioma() return "esMX" end -- src/Alfa_Idioma (tools/build.py)
function GetRealmName() return "Forever" end
function GetNormalizedRealmName() return "Forever" end
function UnitName(u) if u == "player" then return "Lobato", nil end return nil end
function UnitLevel(u) return 23 end
function UnitEffectiveLevel(u) return 23 end
function UnitFactionGroup() return "Horde", "Horda" end
function UnitRace() return "Orco", "Orc", 2 end
function UnitClass() return "Guerrero", "WARRIOR", 1 end
function UnitClassBase() return "WARRIOR", 1 end
function UnitSex() return 2 end
function UnitGUID() return "Player-1-0001" end
function UnitXP() return 4200 end
function UnitXPMax() return 10000 end
function GetXPExhaustion() return 2000 end
function GetMaxPlayerLevel() return 60 end
function IsXPUserDisabled() return false end
function UnitExists(u) return u == "player" end
function UnitIsDeadOrGhost() return false end
function UnitAffectingCombat() return false end
function UnitOnTaxi() return false end
function IsInInstance() return false, "none" end
-- 1.3.9: quieto (0), corriendo 7, volando 7, nadando 4.72 (en combate y en mazmorras llega secreta).
function GetUnitSpeed() return 0, 7, 7, 4.72 end
function IsInGroup() return false end
function IsInRaid() return false end
function GetNumGroupMembers() return 0 end
function InCombatLockdown() return false end
function IsLoggedIn() return true end
-- Valores secretos simulados (1.3.7, arreglos). SECRETO(v) da un valor que se
-- porta como un secreto del juego dentro del código de Alfa: type() dice el
-- tipo de lo que esconde, issecretvalue() dice true, y compararlo (< > y ==
-- entre dos secretos), hacer cuentas, indexarlo (s:find), llamarlo, medirlo
-- (#), pasarlo a tonumber o a string.* truena con «secret». tostring y ..
-- dan otro secreto, como en el juego. Lua 5.1 no deja atrapar `if v`,
-- `not v` ni `v == true`: eso lo revisa prueba_137b_bugs.lua leyendo el
-- código. Los marcos del banco (mock.lua/api.lua) sí lo leen, como el juego.
-- SECRETOS_PRENDER({ "UnitIsAFK", ... }) hace que esas funciones den sus
-- respuestas en secreto; SECRETOS_APAGAR() las devuelve.
do
  local rtype, rtonumber, rtostring, getmt = type, tonumber, tostring, getmetatable
  local OCULTO = setmetatable({}, { __mode = "k" })
  local function deBanco(nivel)
    local info = debug.getinfo(nivel, "S")
    local s = info and info.source or ""
    return s == "@mock.lua" or s == "@api.lua" or s == "@dump.lua" or s == "@drive.lua" or s == "=[C]"
  end
  local function truena(que) error("attempt to " .. que .. " a secret value (banco)", 3) end
  local MT = {}
  local function nuevo(v)
    local p = newproxy(true)
    local mt = getmt(p)
    for k, f in pairs(MT) do mt[k] = f end
    OCULTO[p] = { v = v, t = rtype(v) }
    return p
  end
  -- (nivel 3: quien indexa; el 2 es esta misma función)
  MT.__index = function(_, k) if deBanco(3) then return nil end truena("index") end
  MT.__newindex = function() truena("index") end
  MT.__call = function() truena("call") end
  MT.__len = function() truena("get length of") end
  MT.__eq = function() truena("compare") end
  MT.__lt = function() truena("compare") end
  MT.__le = function() truena("compare") end
  for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm" }) do
    MT[op] = function() truena("perform arithmetic on") end
  end
  MT.__concat = function() return nuevo("<secreto>") end
  MT.__tostring = function() return "<secreto>" end
  function SECRETO(v) return nuevo(v) end
  function SECRETO_VALOR(p) local o = OCULTO[p] return o and o.v end
  function issecretvalue(v) return rtype(v) == "userdata" and OCULTO[v] ~= nil end
  function canaccessvalue(v) return not issecretvalue(v) end
  function type(v)
    local t = rtype(v)
    if t == "userdata" and OCULTO[v] then return OCULTO[v].t end
    return t
  end
  -- 1.3.9: como en el juego, tonumber de un número secreto da el mismo
  -- secreto (compararlo después truena: Rastreador.lua:1007); de otro tipo,
  -- truena. Nivel 3 = quien llama (el 2 es esta misma función).
  function tonumber(v, base)
    if rtype(v) == "userdata" and OCULTO[v] then
      if deBanco(3) then return nil end
      if OCULTO[v].t == "number" then return v end
      error("bad argument #1 to 'tonumber' (a secret value) (banco)", 2)
    end
    return rtonumber(v, base)
  end
  function tostring(v)
    if rtype(v) == "userdata" and OCULTO[v] and not deBanco(3) then return nuevo("<secreto>") end
    return rtostring(v)
  end
  local guardadas = {}
  function SECRETOS_PRENDER(nombres)
    for _, n in ipairs(nombres) do
      local f = rawget(_G, n)
      if guardadas[n] == nil and rtype(f) == "function" then
        guardadas[n] = f
        rawset(_G, n, function(...)
          local r = { f(...) }
          for i = 1, table.maxn(r) do if r[i] ~= nil then r[i] = nuevo(r[i]) end end
          return unpack(r, 1, table.maxn(r))
        end)
      end
    end
  end
  function SECRETOS_APAGAR()
    for n, f in pairs(guardadas) do rawset(_G, n, f) end
    guardadas = {}
  end
end
function securecallfunction(fn, ...) return fn(...) end
function GetMoney() return 123456 end
function GetZoneText() return "Durotar" end
function GetRealZoneText() return "Durotar" end
function GetSubZoneText() return "" end
function GetMinimapZoneText() return "Durotar" end
function GetScreenWidth() return (PANTALLA_TAM()) end
function GetScreenHeight() return select(2, PANTALLA_TAM()) end
function GetPhysicalScreenSize() return PANTALLA_TAM() end
function GetCursorPosition() return 0, 0 end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function IsModifiedClick() return false end
function GetCVar() return "0" end
function GetCVarBool() return false end
function SetCVar() end
function PlaySound() end
function PlaySoundFile() end
function GetBindingKey() return nil end
function GetCurrentKeyBoardFocus() return nil end
function debugstack() return "" end
function debugprofilestop() return 0 end
function GetFramerate() return 60 end
function GetBuildInfo() return "1.60.1", "100", "Nov 1 2026", 16001 end
function GetAddOnMemoryUsage() return 1000 end
function UpdateAddOnMemoryUsage() end
function GetQuestDifficultyColor(level) return { r = 1, g = 0.8, b = 0 } end
function GetNumQuestLogEntries() return 0, 0 end
function GetQuestLogTitle() return nil end
function GetQuestsCompleted() return {} end
function IsQuestFlaggedCompleted() return false end
function GetItemInfo() return nil end
function GetItemIcon() return nil end
function GetSpellInfo() return nil end
function GetSpellTexture() return nil end
function GetContainerNumSlots() return 0 end
function GetInventoryItemID() return nil end
function GetInventoryItemLink() return nil end
function GetNumSkillLines() return 0 end
function GetProfessions() return nil end
function GetTalentInfo() return nil end
function GetNumTalentTabs() return 0 end
function GetNumTalents() return 0 end
function GetActiveTalentGroup() return 1 end
function HasPetUI() return false end
function GetBindLocation() return "Orgrimmar" end
function CanEditMacros() return false end
function ReloadUI() end
function EnableAddOn() end
function DisableAddOn() end
function GetNumAddOns() local n = 0 for _ in pairs(ADDON_META) do n = n + 1 end return n end
function IsAddOnLoaded(name) return LOADED[name] and true or false end
function GetAddOnMetadata(name, field) local m = ADDON_META[name] return m and m[field] end
function tContains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert, tremove = table.insert, table.remove
format, strfind, strsub, strlower, strupper, strlen, strrep, strbyte, strchar, gsub, strmatch, gmatch =
  string.format, string.find, string.sub, string.lower, string.upper, string.len, string.rep, string.byte, string.char, string.gsub, string.match, string.gmatch
floor, ceil, abs, max, min, sqrt, random = math.floor, math.ceil, math.abs, math.max, math.min, math.sqrt, math.random
sort, getn = table.sort, table.getn
function strtrim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
function strsplit(sep, s, n)
  local t = {}
  for p in (tostring(s) .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do t[#t + 1] = p end
  return unpack(t)
end
function strjoin(sep, ...) return table.concat({ ... }, sep) end
function strconcat(...) return table.concat({ ... }) end
bit = { band = function(a, b) return 0 end, bor = function() return 0 end, bxor = function() return 0 end,
  lshift = function() return 0 end, rshift = function() return 0 end }
function CopyTable(t) local o = {} for k, v in pairs(t) do o[k] = type(v) == "table" and CopyTable(v) or v end return o end
function Mixin(o, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do o[k] = v end end return o end
function CreateFromMixins(...) return Mixin({}, ...) end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGB = function(self) return self.r, self.g, self.b end, GetRGBA = function(self) return self.r, self.g, self.b, self.a end } end
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" } }
for _, c in pairs({ "MAGE", "PRIEST", "ROGUE", "DRUID", "HUNTER", "SHAMAN", "PALADIN", "WARLOCK" }) do RAID_CLASS_COLORS[c] = { r = 0.5, g = 0.5, b = 0.9, colorStr = "ff8080e6" } end
ITEM_QUALITY_COLORS = {}
for q = 0, 7 do ITEM_QUALITY_COLORS[q] = { r = 0.6, g = 0.6, b = 0.6, hex = "|cff999999" } end
C_ClassColor = { GetClassColor = function(f) local c = RAID_CLASS_COLORS[f] return c and CreateColor(c.r, c.g, c.b, 1) end }
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Guerrero" }
CLASS_ICON_TCOORDS = {}

-- Timers: run when the driver says. The tasks of Alfa's own clock (N.Cada,
-- N.Ticker: src/Alfa_Nucleo/Reloj.lua, 1.2.9) run once per round too, like
-- the game's tickers, unless a scene sets BANCO_RELOJ_REAL to drive that
-- clock by hand (FIRE(N.Reloj.marco, "OnUpdate", dt)).
local timers = {}
local function relojAlfa()
  if rawget(_G, "BANCO_RELOJ_REAL") then return false end
  local N = rawget(_G, "AlfaNucleo")
  local R = type(N) == "table" and N.Reloj
  if not (R and R.Adelantar) then return false end
  local ok, hay = pcall(R.Adelantar)
  if not ok then NOTE("reloj", hay) return false end
  return hay
end
function RUN_TIMERS(n)
  for _ = 1, n or 5 do
    local list = timers
    timers = {}
    NOW = NOW + 1
    for _, t in ipairs(list) do
      if not t.cancelled then
        local m0, t0 = PERFIL_ON and PERFIL_MARCA(), PERFIL_ON and PERFIL_RELOJ()
        local ok, e = pcall(t.fn, t)
        if t0 then PERFIL_SUMAR("reloj " .. PERFIL_CLAVE(t.fn), PERFIL_RELOJ() - t0, m0) end
        if not ok then NOTE("timer", e) end
        if t.ticker and not t.cancelled then timers[#timers + 1] = t end
      end
    end
    local m1, t1 = PERFIL_ON and PERFIL_MARCA(), PERFIL_ON and PERFIL_RELOJ()
    local hay = relojAlfa()
    if t1 then PERFIL_SUMAR("reloj N.Reloj (todo)", PERFIL_RELOJ() - t1, m1) end
    if #timers == 0 and not hay then break end
  end
end
C_Timer = {
  After = function(s, fn) timers[#timers + 1] = { fn = fn } end,
  NewTimer = function(s, fn) local t = { fn = fn } t.Cancel = function(self) self.cancelled = true end t.IsCancelled = function(self) return self.cancelled end timers[#timers + 1] = t return t end,
  NewTicker = function(s, fn) local t = { fn = fn, ticker = true } t.Cancel = function(self) self.cancelled = true end t.IsCancelled = function(self) return self.cancelled end timers[#timers + 1] = t return t end,
}

-- hooksecurefunc(table?, name, fn)
function hooksecurefunc(t, name, fn)
  if type(t) == "string" then t, name, fn = _G, t, name end
  local orig = t[name]
  if type(orig) ~= "function" then return end
  t[name] = function(...)
    local r = { orig(...) }
    fn(...)
    return unpack(r)
  end
end

-- 1.4.0 (revisión): una carpeta del dist existe aunque no se haya cargado (los
-- paquetes a pedido). BANCO_SIN_ADDON[nombre] = "falta" | "apagado" la quita o
-- la apaga para una prueba (una instalación a medias).
BANCO_SIN_ADDON = BANCO_SIN_ADDON or {}
function BANCO_EXISTE(n)
  if type(n) ~= "string" or BANCO_SIN_ADDON[n] == "falta" then return nil end
  local m = ADDON_META[n]
  if m then return m.LoadOnDemand == "1" and "1" or "0" end
  local r = PY_ADDON_EXISTS and PY_ADDON_EXISTS(n)
  if type(r) ~= "string" or r == "" then return nil end
  return r
end

C_AddOns = {
  GetAddOnMetadata = GetAddOnMetadata,
  IsAddOnLoaded = function(n) return LOADED[n] and true or false, LOADED[n] and true or false end,
  GetNumAddOns = GetNumAddOns,
  GetAddOnInfo = function(n)
    if type(n) == "number" then -- (1.3.9) por número, como en el juego: en orden alfabético
      local l = {}
      for k in pairs(ADDON_META) do l[#l + 1] = k end
      table.sort(l)
      n = l[n]
    end
    local m = n and ADDON_META[n] if not m then return nil end return n, m.Title, m.Notes, true, nil, "INSECURE", false end,
  GetAddOnEnableState = function(n) if BANCO_SIN_ADDON[n] then return 0 end return BANCO_EXISTE(n) and 2 or 0 end,
  IsAddOnLoadOnDemand = function(n) return BANCO_EXISTE(n) == "1" end,
  LoadAddOn = function(n) if BANCO_SIN_ADDON[n] then return false, BANCO_SIN_ADDON[n] == "apagado" and "DISABLED" or "MISSING" end if coroutine.running() and PY_ADDON_FILES and not LOADED[n] then return BANCO_CARGAR(n) end if PERFIL_ON and not LOADED[n] then PERFIL_PIDIO = PERFIL_PIDIO or {}; local t0 = PERFIL_RELOJ(); local ok = PY_LOAD_ADDON(n); PERFIL_PIDIO[#PERFIL_PIDIO + 1] = { n, PERFIL_RELOJ() - t0, debug.traceback("", 2) }; return ok, (not ok) and "MISSING" or nil end if PY_LOAD_ADDON then local ok = PY_LOAD_ADDON(n) return ok, (not ok) and "MISSING" or nil end return false, "MISSING" end,
  EnableAddOn = function() end, DisableAddOn = function() end,
  DoesAddOnExist = function(n) if BANCO_SIN_ADDON[n] == "falta" then return false end return BANCO_EXISTE(n) ~= nil end,
}
BANCO_ZONAS = {[1411] = "Durotar", [1412] = "Mulgore", [1413] = "Los Baldíos", [1414] = "Kalimdor", [1415] = "Reinos del Este", [1416] = "Montañas de Alterac", [1417] = "Tierras Altas de Arathi", [1418] = "Tierras Inhóspitas", [1419] = "Las Tierras Devastadas", [1420] = "Claros de Tirisfal", [1421] = "Bosque de Argénteos", [1422] = "Tierras de la Peste del Oeste", [1423] = "Tierras de la Peste del Este", [1424] = "Laderas de Trabalomas", [1425] = "Tierras del Interior", [1426] = "Dun Morogh", [1427] = "La Garganta de Fuego", [1428] = "Las Estepas Ardientes", [1429] = "Bosque de Elwynn", [1430] = "Paso de la Muerte", [1431] = "Bosque del Ocaso", [1432] = "Loch Modan", [1433] = "Montañas Crestagrana", [1434] = "Vega de Tuercespina", [1435] = "Pantano de las Penas", [1436] = "Páramos de Poniente", [1437] = "Los Humedales", [1438] = "Teldrassil", [1439] = "Costa Oscura", [1440] = "Vallefresno", [1441] = "Las Mil Agujas", [1442] = "Sierra Espolón", [1443] = "Desolace", [1444] = "Feralas", [1445] = "Marjal Revolcafango", [1446] = "Tanaris", [1447] = "Azshara", [1448] = "Frondavil", [1449] = "Cráter de Un'Goro", [1450] = "Claro de la Luna", [1451] = "Silithus", [1452] = "Cuna del Invierno", [1453] = "Ventormenta", [1454] = "Orgrimmar", [1455] = "Forjaz", [1456] = "Cima del Trueno", [1457] = "Darnassus", [1458] = "Entrañas"}
-- Un mundo chico pero de verdad para el mapa de Alfa: Azeroth (947) con sus dos
-- continentes y todas sus zonas en una cuadrícula, cada una con su rectángulo y
-- sus mosaicos de arte. Así el mapa se dibuja en el banco y la prueba puede
-- navegarlo (zoom, arrastre, pines).
BANCO_MAPA = { [947] = { tipo = 0, r = { 0, 1, 0, 1 } },
  [1414] = { padre = 947, tipo = 2, r = { 0.03, 0.46, 0.08, 0.92 } },
  [1415] = { padre = 947, tipo = 2, r = { 0.54, 0.97, 0.08, 0.92 } } }
do
  local function repartir(cont, ids)
    local c = BANCO_MAPA[cont].r
    local n = #ids
    local cols = math.ceil(math.sqrt(n))
    local filas = math.ceil(n / cols)
    local w, h = (c[2] - c[1]) / cols, (c[4] - c[3]) / filas
    for i, id in ipairs(ids) do
      local col, fila = (i - 1) % cols, math.floor((i - 1) / cols)
      local l, t = c[1] + col * w, c[3] + fila * h
      BANCO_MAPA[id] = { padre = cont, tipo = 3, r = { l + w * 0.04, l + w * 0.96, t + h * 0.04, t + h * 0.96 } }
    end
  end
  repartir(1414, { 1411, 1412, 1413, 1438, 1439, 1440, 1441, 1442, 1443, 1444, 1445, 1446, 1447, 1448, 1449, 1450, 1451, 1452, 1454, 1456, 1457 })
  repartir(1415, { 1416, 1417, 1418, 1419, 1420, 1421, 1422, 1423, 1424, 1425, 1426, 1427, 1428, 1429, 1430, 1431, 1432, 1433, 1434, 1435, 1436, 1437, 1453, 1455, 1458 })
end
C_Map = {
  GetBestMapForUnit = function() return 1411 end,
  GetPlayerMapPosition = function() return { x = 0.5, y = 0.5, GetXY = function() return 0.5, 0.5 end } end,
  GetMapInfo = function(id)
    local m = BANCO_MAPA[id]
    return { mapID = id, name = BANCO_ZONAS[id] or (id == 947 and "Azeroth") or ("Zona " .. tostring(id)),
      mapType = m and m.tipo or 3, parentMapID = m and m.padre or 1414 }
  end,
  GetMapArtLayers = function(id)
    if not BANCO_MAPA[id] then return nil end
    return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256, minScale = 1, maxScale = 1 } }
  end,
  GetMapArtLayerTextures = function(id)
    if not BANCO_MAPA[id] then return nil end
    local t = {}
    for i = 1, 12 do t[i] = 100000 + id * 16 + i end
    return t
  end,
  GetMapChildrenInfo = function(id, tipo)
    local out = {}
    for hijo, m in pairs(BANCO_MAPA) do
      if m.padre == id and (tipo == nil or m.tipo == tipo) then
        out[#out + 1] = { mapID = hijo, mapType = m.tipo, name = BANCO_ZONAS[hijo] or tostring(hijo), parentMapID = id }
      end
    end
    table.sort(out, function(a, b) return a.mapID < b.mapID end)
    return out
  end,
  GetWorldPosFromMapPos = function() return nil end,
  GetMapRectOnMap = function(id, sobre)
    local m = BANCO_MAPA[id]
    if not m then return nil end
    if sobre == 947 or sobre == nil then return m.r[1], m.r[2], m.r[3], m.r[4] end
    local p = BANCO_MAPA[sobre]
    if not p then return nil end
    local w, h = p.r[2] - p.r[1], p.r[4] - p.r[3]
    return (m.r[1] - p.r[1]) / w, (m.r[2] - p.r[1]) / w, (m.r[3] - p.r[3]) / h, (m.r[4] - p.r[3]) / h
  end,
  GetMapLevels = function() return nil end,
}
C_Item = {
  GetItemIconByID = function() return 134400 end,
  GetItemQualityColor = function(q) return 0.6, 0.6, 0.6, "ff999999" end,
  GetItemInfo = function() return nil end,
  GetItemNameByID = function() return nil end,
  GetItemQualityByID = function() return 2 end,
  RequestLoadItemDataByID = function() end,
  IsItemDataCachedByID = function() return true end,
  DoesItemExistByID = function() return true end,
  GetItemCount = function() return 0 end,
}
C_Spell = { GetSpellInfo = function() return nil end, GetSpellTexture = function() return nil end, GetSpellName = function() return nil end, RequestLoadSpellData = function() end, DoesSpellExist = function() return false end, IsSpellDataCached = function() return true end }
C_QuestLog = {
  IsQuestFlaggedCompleted = function() return false end, IsOnQuest = function() return false end, GetLogIndexForQuestID = function() return nil end,
  GetNumQuestLogEntries = function() return 0, 0 end, GetInfo = function() return nil end, GetQuestObjectives = function() return {} end,
  ReadyForTurnIn = function() return false end, IsComplete = function() return false end, GetTitleForQuestID = function() return nil end,
  GetQuestIDForLogIndex = function() return nil end, IsQuestTrivial = function() return false end,
}
C_CreatureInfo = { GetRaceInfo = function(id) return { raceName = "Raza" .. id, clientFileString = "Orc" } end, GetClassInfo = function() return { className = "Guerrero", classFile = "WARRIOR" } end }
C_ChatInfo = { SendAddonMessage = function() end, RegisterAddonMessagePrefix = function() return true end, IsAddonMessagePrefixRegistered = function() return true end }
C_CVar = { GetCVar = function() return "0" end, SetCVar = function() end, GetCVarBool = function() return false end }
C_TooltipInfo = nil
C_Reputation = nil

DEFAULT_CHAT_FRAME = CreateFrame("Frame", "ChatFrame1")
-- Los marcos del chat con su pestaña, su fondo y su caja de escribir (Comodidades
-- los viste): de verdad, como en el juego.
NUM_CHAT_WINDOWS = 10
for i = 1, NUM_CHAT_WINDOWS do
  local cf = i == 1 and DEFAULT_CHAT_FRAME or CreateFrame("Frame", "ChatFrame" .. i)
  cf:SetSize(430, 120)
  cf:EnableMouse(true) -- 1.4.1: como el juego (enlaces y rueda del chat)
  cf:EnableMouseWheel(true)
  if i > 2 then cf:Hide() end
  CreateFrame("Frame", "ChatFrame" .. i .. "Background", cf)
  local tab = CreateFrame("Button", "ChatFrame" .. i .. "Tab", UIParent)
  tab:SetSize(80, 24)
  tab:CreateFontString("ChatFrame" .. i .. "TabText", "OVERLAY", "GameFontNormalSmall")
  if not _G["ChatFrame" .. i .. "EditBox"] then CreateFrame("EditBox", "ChatFrame" .. i .. "EditBox", cf) end
end
function DEFAULT_CHAT_FRAME:AddMessage(m) PRINTED = (rawget(_G, "PRINTED") or 0) + 1 end
GameTooltip = CreateFrame("Frame", "GameTooltip")
do
  local tip = GameTooltip
  function tip:SetOwner(o) self._owner = o end
  function tip:GetOwner() return self._owner end
  function tip:SetText() end
  function tip:AddLine() end
  function tip:AddDoubleLine() end
  function tip:NumLines() return 1 end
  function tip:ClearLines() end
  function tip:SetItemByID() end
  function tip:SetSpellByID() end
  function tip:SetHyperlink() end
  function tip:SetMinimumWidth() end
  function tip:SetPadding() end
end
ItemRefTooltip = CreateFrame("Frame", "ItemRefTooltip")
Minimap = CreateFrame("Frame", "Minimap")
Minimap:EnableMouse(true) -- 1.4.1: como el juego (clic para marcar, paso del ratón)
Minimap:EnableMouseWheel(true)
Minimap:SetSize(140, 140)
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame")
ChatFrame1EditBox = CreateFrame("EditBox", "ChatFrame1EditBox")
StaticPopupDialogs = {}
SlashCmdList = {}
Enum = setmetatable({}, { __index = function(t, k) local v = setmetatable({}, { __index = function(_, kk) return 0 end }) rawset(t, k, v) return v end })
KEY_BINDINGS_MAC = nil
FACTION_HORDE, FACTION_ALLIANCE = "Horda", "Alianza"
NUM_BAG_SLOTS = 4
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4
GetMoneyString = function(c) c = math.floor(tonumber(c) or 0) return (math.floor(c / 10000)) .. "g " .. (math.floor(c / 100) % 100) .. "s " .. (c % 100) .. "c" end
-- Los marcos del minimapa que Alfa viste (Comodidades): de verdad, no comodines,
-- para que el banco pruebe ese código como lo corre el juego.
MinimapCluster = CreateFrame("Frame", "MinimapCluster")
MinimapCluster:SetSize(192, 200)
MinimapCluster.ZoneTextButton = CreateFrame("Button", "MinimapZoneTextButton", MinimapCluster)
MinimapCluster.ZoneTextButton:SetSize(140, 16)
MinimapZoneText = MinimapCluster.ZoneTextButton:CreateFontString("MinimapZoneText", "OVERLAY", "GameFontNormal")
BACKPACK_CONTAINER = 0

-- Every other global: a stand-in that accepts indexing and calls.
local G = _G
GLOBAL_READS = {}
local WATCH = { ["UI\Picker.lua"] = true, ["UI\Lookup.lua"] = true, ["UI\Dungeons.lua"] = true }
local function watched()
  for lvl = 2, 4 do
    local info = debug.getinfo(lvl, "S")
    if not info then return nil end
    local src = info.source or ""
    for w in pairs(WATCH) do if src:find(w, 1, true) then return src end end
  end
  return nil
end
setmetatable(G, { __newindex = function(t, k, v)
  local src = watched()
  if src then GLOBAL_READS["WRITE " .. tostring(k) .. " @" .. src] = true end
  rawset(t, k, v)
end, __index = function(t, k)
  if type(k) ~= "string" then return nil end
  local src = watched()
  if src then GLOBAL_READS[tostring(k) .. " @" .. src] = true end
  -- Other addons are not loaded.
  if k:match("^Questie") or k == "TomTom" or k == "EllesmereUI" or k == "OpenMap" or k == "ElvUI" or k == "BugGrabber" or k == "RXPGuides"
    or k == "TSM_API" or k == "Auctionator" or k == "Details" or k == "WeakAuras" or k == "Bagnon" or k == "AdiBags" or k == "Baganator"
    or k == "Pawn" or k == "ZygorGuidesViewer" or k == "Plater" or k == "Leatrix_Plus" or k == "C_TooltipInfo" or k == "BackdropTemplateMixin"
    or k:match("^Alfa") then return nil end
  local c = COMODIN()
  rawset(t, k, c)
  return c
end })

function geterrorhandler() return function(e) NOTE("errorhandler", e) end end
function seterrorhandler() end

-- 1.4.0: cargar un addon a pedido desde una corrutina (el Codex por partes lo
-- pide desde una tarea de Alfa_Rutas/Tareas.lua). En el juego se puede; en el
-- banco, Python no debe volver a llamar a Lua mientras corre una corrutina
-- (lupa usa la pila equivocada: «tuple indices must be integers»), así que
-- Python solo da los archivos (PY_ADDON_FILES, run.py) y todo lo demás se hace
-- aquí, igual que run.py: load_addon. -> ok, motivo
function BANCO_CARGAR(n)
  local datos = PY_ADDON_FILES(n)
  if type(datos) ~= "string" or datos == "" then return false, "MISSING" end
  local pos = 1
  local function pedazo()
    local dos = datos:find(":", pos, true)
    local largo = tonumber(datos:sub(pos, dos - 1))
    local s = datos:sub(dos + 1, dos + largo)
    pos = dos + largo + 1
    return s
  end
  if not ADDON_META[n] then
    local meta = {}
    for par in (pedazo() .. "\2"):gmatch("(.-)\2") do
      local k, v = par:match("^(.-)\1(.*)$")
      if k then meta[k] = v end
    end
    ADDON_META[n] = meta
  else
    pedazo()
  end
  LOADED[n] = true
  local ns = NS_OF(n)
  while pos <= #datos do
    local ruta = pedazo()
    local src = pedazo()
    LOAD_FILE(ruta, src, n, ns)
  end
  FIRE_EVENT("ADDON_LOADED", n)
  return true
end

function LOAD_FILE(name, src, addon, ns)
  local fn, err = loadstring(src, "@" .. name)
  ARCHIVOS_CARGADOS = ARCHIVOS_CARGADOS or {}
  ARCHIVOS_CARGADOS[#ARCHIVOS_CARGADOS + 1] = name
  if not fn then NOTE(name, err) return end
  local t0 = PERFIL_RELOJ()
  local ok, e = xpcall(function() return fn(addon, ns) end, debug.traceback)
  if not ok then NOTE("load " .. name, e) end
  if PERFIL_ON then
    PERFIL_CARGA = PERFIL_CARGA or {}
    PERFIL_CARGA[#PERFIL_CARGA + 1] = { name, PERFIL_RELOJ() - t0, addon }
    -- Los eventos del motor pasan por un solo marco: se envuelve cada
    -- manejador para saber de quién es el tiempo.
    if type(ns) == "table" and type(ns.RegisterEvent) == "function" and not ns._perfilEnvuelto then
      ns._perfilEnvuelto = true
      local reg, unreg, mapa = ns.RegisterEvent, ns.UnregisterEvent, setmetatable({}, { __mode = "k" })
      local function envolver(ev, fn)
        if type(fn) ~= "function" then return fn end
        mapa[fn] = mapa[fn] or {}
        if not mapa[fn][ev] then
          local clave = "evento " .. ev .. " " .. PERFIL_CLAVE(fn)
          mapa[fn][ev] = function(...)
            local m0, t = PERFIL_MARCA(), PERFIL_RELOJ()
            local r = { fn(...) }
            PERFIL_SUMAR(clave, PERFIL_RELOJ() - t, m0)
            return unpack(r)
          end
        end
        return mapa[fn][ev]
      end
      ns.RegisterEvent = function(ev, fn) return reg(ev, envolver(ev, fn)) end
      if type(ns.OnLogin) == "function" then
        local ol = ns.OnLogin
        ns.OnLogin = function(fn)
          if type(fn) ~= "function" then return ol(fn) end
          local clave = "OnLogin " .. PERFIL_CLAVE(fn)
          return ol(function(...) local t = PERFIL_RELOJ(); local r = { fn(...) }; PERFIL_SUMAR(clave, PERFIL_RELOJ() - t); return unpack(r) end)
        end
      end
      if unreg then ns.UnregisterEvent = function(ev, fn) return unreg(ev, envolver(ev, fn)) end end
    end
  end
end
