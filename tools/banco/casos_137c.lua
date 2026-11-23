-- Lo que pasa ANTES de cargar los addons en cada caso de prueba_137c_bugs.lua
-- (1.3.7). tools/casos137c.py lo pega detrás de las variables guardadas del
-- caso (BANCO_GUARDADAS) con BANCO_CASO ya puesto, así cada caso entra al
-- juego como entraría un jugador: con /reload a media mazmorra, en combate,
-- en grifo, muerto, en una banda de 40, con el juego en otro idioma, con la
-- interfaz escalada o con un módulo apagado en la lista de addons.
local C = rawget(_G, "BANCO_CASO") or {}
BANCO_CASO = C

-- Una cuenta que venía de la 1.2.x: sin las migraciones de después, con
-- ajustes con la forma de entonces y datos de Lya, la manada y las rutas.
if C.vieja then
  AlfaDB = {
    schema = 1, alfaSchema = 1, version = "1.2.2",
    settings = {
      comodidades = { barrasGrifos = "ocultar", colores = true, minimapa = false },
      party = { chat = true }, ui = { shown = true, textSize = 1.1 },
      bienvenida = { hecha = true, perfil = "completo", anuncios = true },
      lya = { visible = true, aullidoMision = true },
      manada = { guaridaVisible = true, rarosManada = true },
      combate = { corteSonido = true },
      mundo = { estiloMapa = "clasico" },
    },
  }
  AlfaCharDB = {}
end
if C.modo then
  AlfaDB = type(AlfaDB) == "table" and AlfaDB or {}
  AlfaDB.settings = type(AlfaDB.settings) == "table" and AlfaDB.settings or {}
  AlfaDB.settings.bienvenida = type(AlfaDB.settings.bienvenida) == "table" and AlfaDB.settings.bienvenida or {}
  AlfaDB.settings.bienvenida.modo = C.modo
end

-- El reino vacío (Forever desde el 20/11/2026) y el personaje de la cuenta real.
if C.reinoVacio then
  GetRealmName = function() return "" end
  GetNormalizedRealmName = function() return nil end
end
if C.yo then
  local yo, un = C.yo, UnitName
  UnitName = function(u) if u == "player" then return yo, nil end return un(u) end
  UnitFactionGroup = function() return "Alliance", "Alianza" end
end

-- El idioma del juego (Alfa_Idioma lo lee al cargar).
if C.idioma then
  local loc = C.idioma
  GetLocale = function() return loc end
end

-- Un módulo apagado en la lista de addons: el juego no lo carga ni deja
-- que otro lo cargue.
if C.quitar then
  local fuera = {}
  for n in tostring(C.quitar):gmatch("[^,]+") do fuera[n] = true end
  BANCO_FUERA = fuera
  local A = C_AddOns
  local cargar, estado, existe = A.LoadAddOn, A.GetAddOnEnableState, A.DoesAddOnExist
  A.LoadAddOn = function(n) if fuera[n] then return false, "DISABLED" end return cargar(n) end
  A.GetAddOnEnableState = function(a, b) local n = b or a if fuera[n] or fuera[a] then return 0 end return estado(a, b) end
  LoadAddOn = A.LoadAddOn
  local enc = GetAddOnEnableState
  if enc then GetAddOnEnableState = A.GetAddOnEnableState end
end

-- La interfaz escalada (como la escala del juego al 64 % en 1440p).
if C.escala then
  local s = C.escala
  UIParent:SetScale(s)
  GetScreenWidth = function() return 2560 / s end
  GetScreenHeight = function() return 1440 / s end
  local cv = GetCVar
  GetCVar = function(k) if k == "uiScale" then return tostring(s) end if k == "useUiScale" then return "1" end return cv(k) end
  local cvb = GetCVarBool
  GetCVarBool = function(k) if k == "useUiScale" then return true end return cvb(k) end
end

-- Dónde está el jugador al entrar.
if C.mazmorra then
  IsInInstance = function() return true, "party" end
  GetInstanceInfo = function() return "Cavernas de los Lamentos", "party", 1, "Normal", 5, 0, false, 43, 5 end
end
if C.banda then
  IsInInstance = function() return true, "raid" end
  GetInstanceInfo = function() return "Núcleo de Magma", "raid", 9, "40 jugadores", 40, 0, false, 409, 40 end
end
local grupo = (C.banda and 40) or (C.mazmorra and 5) or 0
if grupo > 0 then
  local raid = C.banda and true or false
  IsInGroup = function() return true end
  IsInRaid = function() return raid end
  GetNumGroupMembers = function() return grupo end
  GetNumSubgroupMembers = function() return raid and 4 or grupo - 1 end
  local ux, un, uc, ug, ul = UnitExists, UnitName, UnitClass, UnitGUID, UnitLevel
  local CLASES = { "WARRIOR", "MAGE", "PRIEST", "ROGUE", "DRUID", "HUNTER", "SHAMAN", "WARLOCK" }
  local function num(u)
    if type(u) ~= "string" then return nil end
    local n = u:match("^raid(%d+)$") or u:match("^party(%d+)$")
    n = n and tonumber(n)
    if not n then return nil end
    if raid and u:find("^raid") and n <= grupo then return n end
    if u:find("^party") and n <= math.min(4, grupo - 1) then return n end
    return nil
  end
  UnitExists = function(u) if num(u) then return true end return ux(u) end
  UnitName = function(u) local n = num(u) if n then return "Lobo" .. n, nil end return un(u) end
  UnitClass = function(u) local n = num(u) if n then local c = CLASES[(n % #CLASES) + 1] return c, c, 1 end return uc(u) end
  UnitGUID = function(u) local n = num(u) if n then return ("Player-1-%08d"):format(n) end return ug(u) end
  UnitLevel = function(u) local n = num(u) if n then return 20 + (n % 10) end return ul(u) end
  UnitIsConnected = function() return true end
  UnitIsGroupLeader = function(u) return u == "player" end
  UnitGroupRolesAssigned = function(u) local n = num(u) if n == 1 then return "TANK" elseif n == 2 then return "HEALER" end return "DAMAGER" end
  GetRaidRosterInfo = function(i)
    if not raid or i > grupo then return nil end
    local c = CLASES[(i % #CLASES) + 1]
    return i == 1 and "Lobato" or ("Lobo" .. i), i == 1 and 2 or 0, math.floor((i - 1) / 5) + 1, 25, c, c, "Durotar", true, false, nil, nil
  end
end
if C.combate then
  -- Con /reload en combate, el juego carga los addons sin el candado del
  -- combate; PLAYER_REGEN_DISABLED llega después de entrar (la escena prende
  -- BANCO_CANDADO justo después de PLAYER_ENTERING_WORLD).
  BANCO_COMBATE, BANCO_CANDADO = true, false
  InCombatLockdown = function() return BANCO_CANDADO and BANCO_COMBATE end
  UnitAffectingCombat = function(u) return BANCO_COMBATE and (u == "player" or u == "target") end
end
if C.grifo then
  BANCO_GRIFO = true
  UnitOnTaxi = function(u) return BANCO_GRIFO and u == "player" end
end
if C.fantasma then
  BANCO_FANTASMA = true
  UnitIsDeadOrGhost = function(u) return BANCO_FANTASMA and u == "player" end
  UnitIsGhost = function(u) return BANCO_FANTASMA and u == "player" end
  UnitIsDead = function() return false end
end

-- Marcos seguros: el juego no deja moverlos, mostrarlos, esconderlos ni
-- cambiarles atributos en combate («Alfa se ha bloqueado de una acción»).
-- El banco anota la plantilla con que se crearon y avisa si Alfa los toca
-- en combate.
do
  local cf = CreateFrame
  local SEGUROS = setmetatable({}, { __mode = "k" })
  BANCO_SEGUROS = SEGUROS
  CreateFrame = function(kind, name, parent, template, ...)
    local f = cf(kind, name, parent, template, ...)
    if type(template) == "string" and (template:find("Secure") or template:find("SecureActionButton")) then SEGUROS[f] = template end
    return f
  end
  local mt = getmetatable(cf("Frame"))
  local F = mt and type(mt.__index) == "table" and mt.__index
  if not F and mt and type(mt.__index) == "function" then
    for i = 1, 5 do
      local n, v = debug.getupvalue(mt.__index, i)
      if n == "Frame" and type(v) == "table" then F = v break end
    end
  end
  if F then
    local function enCombate() return InCombatLockdown and InCombatLockdown() end
    for _, m in ipairs({ "SetAttribute", "Show", "Hide", "SetShown", "SetPoint", "ClearAllPoints", "SetAllPoints",
      "SetSize", "SetWidth", "SetHeight", "SetParent", "EnableMouse", "SetScale", "RegisterForClicks" }) do
      local orig = F[m]
      if type(orig) == "function" then
        F[m] = function(self, ...)
          if SEGUROS[self] and enCombate() then
            NOTE("marco seguro en combate", (rawget(self, "_name") or SEGUROS[self]) .. ":" .. m .. "\n" .. debug.traceback("", 2))
          end
          return orig(self, ...)
        end
      end
    end
  end
end
