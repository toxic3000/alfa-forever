-- Prueba de los arreglos de la 1.3.7 (la cacería de bugs; tools/prueba.py la
-- corre con las demás prueba_*.lua). Tres partes:
--   1. El valor secreto simulado del banco (api.lua: SECRETO) truena donde el
--      juego truena: compararlo, hacer cuentas, indexarlo, tonumber.
--   2. Lo que Lua 5.1 no deja atrapar (`if v`, `not v`, `v == true`, `and/or`)
--      se revisa leyendo el código de Alfa: una función del juego que puede
--      dar un sí/no secreto no se prueba directo; primero N.Si/N.Secreto/
--      issecretvalue. Los archivos de otras áreas salen como AVISO.
--   3. Un recorrido con las funciones del juego dando secretos (entrar,
--      combate, mazmorra, banda, subir de nivel, cada página) sin errores.
--      El error real de Toxic: Sesion.lua:304 (UnitIsAFK secreto, tarea
--      inicio.sesion).
SNAPSHOTS = {}
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 900)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.3.7 bugs", msg) end end

local A, N = Alfa, AlfaNucleo
if N.Entrando then N.Entrando = function() return false end end

---------------------------------------------------------------------------
-- 1. El secreto del banco
---------------------------------------------------------------------------
step("el secreto simulado truena como en el juego", function()
  local s = SECRETO(true)
  check(issecretvalue(s), "issecretvalue no reconoce el secreto")
  check(type(s) == "boolean", "type() de un secreto debe decir lo que esconde")
  check(N.Secreto(s) and not N.Secreto(true) and not N.Secreto(nil), "N.Secreto")
  check(N.Si(s) == false and N.Si(true) == true and N.Si(nil) == false, "N.Si")
  check(N.Leer(s, 7) == 7 and N.Leer(3, 7) == 3, "N.Leer")
  local n = SECRETO(5)
  local function truena(fn) local ok = pcall(fn) return not ok end
  check(truena(function() return n < 3 end), "comparar un secreto no tronó")
  check(truena(function() return n + 1 end), "sumar un secreto no tronó")
  check(truena(function() return n == SECRETO(5) end), "== entre secretos no tronó")
  local x = SECRETO("Nimzy")
  check(truena(function() return x:find("N") end), "indexar un secreto no tronó")
  check(truena(function() return #x end), "medir un secreto no tronó")
  -- tonumber desde el código de Alfa sí truena; desde el banco no.
  check(tonumber(n) == nil, "tonumber del banco")
  check(issecretvalue(x .. "a"), "concatenar da otro secreto")
end)

---------------------------------------------------------------------------
-- 2. Leer el código: sí/no del juego que pueden llegar secretos
---------------------------------------------------------------------------
-- Las funciones que el juego puede dar en secreto y que se suelen probar en
-- un if. UnitExists e IsPlayer se dejan fuera: no son secretas en Forever.
local SINO = { "UnitIsAFK", "UnitIsDND", "UnitOnTaxi", "UnitIsDeadOrGhost", "UnitIsDead", "UnitIsGhost",
  "UnitAffectingCombat", "UnitIsUnit", "UnitInRange", "UnitIsConnected", "UnitIsFriend", "UnitCanAttack",
  "UnitCanAssist", "UnitIsEnemy", "UnitIsTapDenied", "UnitIsVisible", "UnitIsGroupLeader", "UnitIsGroupAssistant",
  "UnitInVehicle", "UnitIsCharmed", "UnitIsPVP", "IsInInstance" }
-- Áreas de otros agentes en esta tanda: se avisan, no fallan.
local AJENAS = { "^src/Alfa_Curacion/", "^src/Alfa_Enciclopedia/", "^src/Alfa_Comercio/", "^src/Alfa_Rutas/",
  "^motor/Alfa/UI/Options%.lua$", "^motor/Alfa/UI/GuideFrame%.lua$" }
local function ajena(p) for _, a in ipairs(AJENAS) do if p:find(a) then return true end end return false end

local function fuente(nombre)
  -- "Alfa_Inicio\Sesion.lua" -> src/Alfa_Inicio/Sesion.lua; "Alfa\Nav\Arrow.lua" -> motor/Alfa/Nav/Arrow.lua
  local rel = nombre:gsub("\\", "/")
  for _, p in ipairs({ "src/" .. rel, "motor/" .. rel }) do
    local f = io.open(p, "rb")
    if f then local t = f:read("*a") f:close() return p, t end
  end
  return nil
end
local function sinComentario(l)
  local i = l:find("%-%-")
  if i then l = l:sub(1, i - 1) end
  return l
end
-- El final de la llamada que empieza en el "(" de la posición i.
local function cierre(l, i)
  local d = 0
  for j = i, #l do
    local c = l:sub(j, j)
    if c == "(" then d = d + 1 elseif c == ")" then d = d - 1 if d == 0 then return j end end
  end
  return #l
end
local PRUEBA = { "if", "elseif", "while", "not", "and", "or", "return" }
local function antesEsPrueba(pre)
  pre = pre:gsub("[%s%(]+$", "")
  for _, k in ipairs(PRUEBA) do
    if pre == k or pre:sub(-#k - 1):match("^[^%w_]" .. k .. "$") then return k end
  end
  if pre:match("[=~]=$") then return "==" end
  return nil
end
local function despuesEsPrueba(pos)
  pos = pos:gsub("^%s+", "")
  if pos:match("^and[^%w_]") or pos:match("^or[^%w_]") or pos:match("^then") or pos:match("^[=~]=") then return true end
  return false
end

local hallazgos, avisos, anotados = {}, {}, {}
local function anotar(p, n, l, que)
  local linea = p .. ":" .. n .. ": " .. que .. "  |  " .. l:gsub("^%s+", ""):sub(1, 140)
  if anotados[p .. ":" .. n] then return end
  anotados[p .. ":" .. n] = true
  if ajena(p) then avisos[#avisos + 1] = linea else hallazgos[#hallazgos + 1] = linea end
end

local function revisar(p, texto)
  local n = 0
  local vars = {} -- nombre -> { fn, linea } de un local que trae un sí/no del juego
  -- Los alias: local afk = rawget(_G, "UnitIsAFK") / local afk = UnitIsAFK
  -- (así venía el error real de Sesion.lua: afk("player") == true).
  local lista = {}
  for _, fn in ipairs(SINO) do
    lista[#lista + 1] = fn
    for alias in texto:gmatch("local%s+([%w_]+)%s*=%s*rawget%(%s*_G%s*,%s*\"" .. fn .. "\"%s*%)") do lista[#lista + 1] = alias end
    for alias in texto:gmatch("local%s+([%w_]+)%s*=%s*" .. fn .. "%s*[\r\n]") do lista[#lista + 1] = alias end
  end
  for crudo in (texto .. "\n"):gmatch("([^\n]*)\n") do
    n = n + 1
    local l = sinComentario(crudo:gsub("\r$", ""))
    if l:find("^%s*function ") or l:find("^function ") or l:find("^local function ") then vars = {} end
    for _, fn in ipairs(lista) do
      local desde = 1
      while true do
        local a, b = l:find(fn .. "%s*%(", desde)
        if not a then break end
        desde = b + 1
        local antes = a > 1 and l:sub(a - 1, a - 1) or " "
        if not antes:match("[%w_%.:\"']") then
          local pre, fin = l:sub(1, a - 1), cierre(l, b)
          -- Dentro de otra llamada (si(UnitX(...)), U.Leer(...)): no se prueba crudo.
          local argumento = pre:match("[%w_%.:]%s*%(%s*$") ~= nil
          local k = not argumento and antesEsPrueba(pre)
          -- «UnitX and UnitX(...)» solo pregunta si existe: lo que da se sigue abajo.
          if k == "and" and pre:find(fn .. "%s+and%s*$") then k = nil end
          if not argumento and (k or despuesEsPrueba(l:sub(fin + 1))) then
            anotar(p, n, l, fn .. " directo en una prueba (" .. (k or "and/or/==") .. ")")
          end
          -- local x = UnitIsAFK(...) / local ok, x = pcall(UnitIsAFK, ...)
        end
      end
      -- Se guarda en un local: se vigila en las líneas que siguen.
      local nombres = l:match("^%s*local%s+([%w_,%s]+)=%s*[%w_%.]*%s*%(?%s*" .. fn .. "[%s,%)%(]")
        or l:match("^%s*local%s+([%w_,%s]+)=%s*pcall%(%s*" .. fn .. "[%s,%)]")
        or l:match("^%s*local%s+([%w_,%s]+)=%s*" .. fn .. "%s+and%s+" .. fn .. "%s*%(")
      if nombres and (l:find("[%w_%.:]%s*%(%s*" .. fn .. "%s*%(") or l:find("ecret") or l:find("[Ll]eer%(") or l:find("[Ll]egible%(") or l:find("[Ss]i%(")) then
        nombres = nil -- si(UnitX(...)), N.Leer(...)
      end
      if nombres then
        for v in nombres:gmatch("[%w_]+") do if not v:find("^ok") and v ~= "_" then vars[v] = { fn, n } end end
      end
    end
    for v, info in pairs(vars) do
      if n > info[2] then
        if n - info[2] > 12 then vars[v] = nil
        elseif l:find("[^%w_]" .. v .. "[^%w_]") or l:find("^" .. v .. "[^%w_]") then
          local limpio = l:find("ecret") or l:find("[Ss]i%(" .. v) or l:find("[Ll]eer%(" .. v) or l:find("[Ll]egible%(" .. v)
            or l:find("[Ss]ecreto%(" .. v)
          if limpio then
            vars[v] = nil
          else
            local pat = { "if%s+" .. v .. "[^%w_]", "not%s+" .. v .. "[^%w_]", "[^%w_]" .. v .. "%s*[=~]=",
              "and%s+" .. v .. "[^%w_%.]", "or%s+" .. v .. "[^%w_%.]", "[^%w_]" .. v .. "%s+and[^%w_]", "[^%w_]" .. v .. "%s+or[^%w_]" }
            for _, pt in ipairs(pat) do
              if (" " .. l .. " "):find(pt) then
                anotar(p, n, l, v .. " (de " .. info[1] .. ", línea " .. info[2] .. ") se prueba sin ver si es secreto")
                vars[v] = nil
                break
              end
            end
          end
        end
      end
    end
  end
end

step("la revisión atrapa el error real de Sesion.lua (afk(\"player\") == true, if afk(...), if si)", function()
  local h0 = #hallazgos
  revisar("banco/Vieja.lua", [[
local afk = rawget(_G, "UnitIsAFK")
if type(afk) == "function" and afk("player") == true then return true end
if afk("player") then return true end
local si, tipo = IsInInstance()
if si then return true end
if N.SiJuego(afk, "player") then return true end
]])
  check(#hallazgos - h0 == 3, "la revisión debía atrapar 3 pruebas con secretos y halló " .. (#hallazgos - h0))
  for i = #hallazgos, h0 + 1, -1 do hallazgos[i] = nil end
end)

step("el código no prueba en un if un sí/no del juego que puede ser secreto", function()
  local vistos, cuantos = {}, 0
  for _, nombre in ipairs(ARCHIVOS_CARGADOS or {}) do
    local p, t = fuente(nombre)
    if p and not vistos[p] and not p:find("Guides") and not p:find("Codex") and not p:find("Idiomas") then
      vistos[p] = true
      cuantos = cuantos + 1
      revisar(p, t)
    end
  end
  check(cuantos > 100, "se leyeron muy pocos archivos de Alfa: " .. cuantos)
  for _, a in ipairs(avisos) do print("AVISO (otra área): " .. a) end
  for _, h in ipairs(hallazgos) do NOTE("secreto en un if", h) end
end)

---------------------------------------------------------------------------
-- 3. El recorrido con secretos
---------------------------------------------------------------------------
local SECRETAS = { "UnitIsAFK", "UnitIsDND", "UnitOnTaxi", "UnitIsDeadOrGhost", "UnitIsDead", "UnitIsGhost",
  "UnitAffectingCombat", "UnitIsUnit", "UnitInRange", "UnitIsConnected", "UnitHealth", "UnitHealthMax",
  "UnitPower", "UnitPowerMax", "UnitName", "UnitIsGroupLeader", "UnitThreatSituation", "UnitDetailedThreatSituation",
  "UnitCastingInfo", "UnitChannelInfo", "UnitIsTapDenied", "UnitClassification" }

local function pinta()
  for _ = 1, 3 do RUN_TIMERS(2) end
end

step("Sesion.lua:304: UnitIsAFK / UnitOnTaxi / IsInInstance secretos no truenan (tarea inicio.sesion)", function()
  local In = NS_OF("Alfa_Inicio")
  local S = In.Sesion
  check(S and S.Pausado, "falta M.Sesion.Pausado")
  local afk, taxi, ii = rawget(_G, "UnitIsAFK"), UnitOnTaxi, IsInInstance
  rawset(_G, "UnitIsAFK", function() return SECRETO(true) end)
  UnitOnTaxi = function() return SECRETO(true) end
  IsInInstance = function() return SECRETO(true), SECRETO("party") end
  local ok, r = pcall(S.Pausado)
  check(ok, "S.Pausado tronó con secretos: " .. tostring(r))
  check(r == false, "con todo secreto la sesión no se pausa (un secreto es «no sé»)")
  -- La tarea del reloj, de verdad.
  FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
  NOW = NOW + 60
  pinta()
  rawset(_G, "UnitIsAFK", afk) UnitOnTaxi, IsInInstance = taxi, ii
  rawset(_G, "UnitIsAFK", function() return true end)
  check(S.Pausado() == true, "ausente (sin secreto) sí pausa")
  rawset(_G, "UnitIsAFK", afk)
end)

local enCombate = false
local icl = InCombatLockdown
InCombatLockdown = function() return enCombate end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(5)
SECRETOS_PRENDER(SECRETAS)

step("entrar con secretos", function()
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  pinta()
end)

step("combate con secretos", function()
  enCombate = true
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  for _, u in ipairs({ "player", "target" }) do
    FIRE_EVENT("UNIT_HEALTH", u)
    FIRE_EVENT("UNIT_POWER_UPDATE", u, "MANA")
    FIRE_EVENT("UNIT_AURA", u, { isFullUpdate = true })
    FIRE_EVENT("UNIT_SPELLCAST_START", u, "Cast-1", 133)
    FIRE_EVENT("UNIT_THREAT_LIST_UPDATE", u)
  end
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  NOW = NOW + 5
  pinta()
  enCombate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  pinta()
end)

step("mazmorra y banda con secretos", function()
  local ii, ig, ir, gn = IsInInstance, IsInGroup, IsInRaid, GetNumGroupMembers
  IsInInstance = function() return SECRETO(true), SECRETO("party") end
  IsInGroup = function() return true end
  GetNumGroupMembers = function() return 5 end
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  enCombate = true
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  FIRE_EVENT("ENCOUNTER_START", 1, "Jefe", 1, 5)
  pinta()
  FIRE_EVENT("ENCOUNTER_END", 1, "Jefe", 1, 5, 1)
  enCombate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  -- banda
  IsInInstance = function() return SECRETO(true), SECRETO("raid") end
  IsInRaid = function() return true end
  GetNumGroupMembers = function() return 25 end
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  pinta()
  IsInInstance, IsInGroup, IsInRaid, GetNumGroupMembers = ii, ig, ir, gn
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  pinta()
end)

step("subir de nivel con secretos", function()
  FIRE_EVENT("PLAYER_LEVEL_UP", 24, 10, 0, 0, 1, 0, 0, 0, 0)
  FIRE_EVENT("PLAYER_XP_UPDATE", "player")
  NOW = NOW + 10
  pinta()
end)

step("abrir cada página con secretos", function()
  local PAGINAS = { "inicio", "rutas", "enciclopedia", "builds", "bolsas", "manada", "mazmorras", "mundo",
    "pesca", "lya", "vista", "comodidades", "comercio", "recoleccion", "combate", "curacion", "bienvenida", "questing" }
  for _, id in ipairs(PAGINAS) do
    local antes = #ERRORS
    A.Fire("SHOW_OPTIONS", id)
    pinta()
    if #ERRORS > antes then print("  (al abrir " .. id .. ")") end
  end
  local o = A.UI and A.UI.Options and A.UI.Options.frame
  if o then o:Hide() end
end)

SECRETOS_APAGAR()
InCombatLockdown = icl

print(("PRUEBA: 1.3.7 bugs, %d pasos, %d errores, %d avisos de otras áreas"):format(pasos, #ERRORS, #avisos))
print("errors: " .. #ERRORS)
