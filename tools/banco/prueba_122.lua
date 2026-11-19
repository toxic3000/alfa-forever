-- Prueba de la 1.2.2 (tools/prueba.py la corre con las demás prueba_*.lua):
--   * «Invitar al clan» (Alfa_Manada/Invitar.lua): en el clic derecho de un
--     jugador sale un submenú con tu hermandad (si puedes invitar) y tus
--     comunidades de personajes donde tu rango deja invitar; las de
--     Battle.net y aquellas sin permiso no salen;
--   * un clic envía la invitación con su nombre completo (con apellido), sin
--     escribirlo, y avisa en el chat;
--   * no sale en tu propio retrato, en una criatura, con el nombre secreto,
--     sin nada a dónde invitar, ni con el ajuste apagado; la hermandad no
--     sale para quien ya es de ella ni para la otra facción.
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
local function T(n) RUN_TIMERS(n or 2) end
local function check(cond, msg) if not cond then NOTE("invitar", msg) end end

-- El menú del juego: guarda lo que registra cada etiqueta.
local REGISTRADOS = {}
Menu = { ModifyMenu = function(tag, fn) REGISTRADOS[tag] = REGISTRADOS[tag] or {}; table.insert(REGISTRADOS[tag], fn) end }

local function nuevaDescripcion(texto, fn)
  local d = { texto = texto, fn = fn, hijos = {}, divisores = 0 }
  function d:CreateButton(t, f) local h = nuevaDescripcion(t, f); table.insert(self.hijos, h); return h end
  function d:CreateDivider() self.divisores = self.divisores + 1 end
  function d:CreateTitle(t) return self:CreateButton(t) end
  return d
end

-- Abre un menú como lo hace el juego y devuelve su raíz.
local function abrir(tag, contexto)
  local raiz = nuevaDescripcion(tag)
  for _, fn in ipairs(REGISTRADOS[tag] or {}) do fn(nil, raiz, contexto) end
  return raiz
end

-- El juego: hermandad, comunidades y el jugador del retrato.
local enHermandad, puedoInvitar = true, true
local ENVIADAS = {}
function IsInGuild() return enHermandad end
function GetGuildInfo(u) if u == "player" and enHermandad then return "OLYMPUS SKYHiGH", "Oficial", 1 end end
function CanGuildInvite() return puedoInvitar end
C_GuildInfo = C_GuildInfo or {}
C_GuildInfo.Invite = function(n) table.insert(ENVIADAS, { "hermandad", n }) end
local CLUBES = {
  { clubId = 11, name = "La Jauria", clubType = 1 },
  { clubId = 12, name = "Amigos BNet", clubType = 0 },
  { clubId = 13, name = "Sin permiso", clubType = 1 },
  { clubId = 14, name = "OLYMPUS SKYHiGH", clubType = 2 },
}
C_Club = {
  GetSubscribedClubs = function() return CLUBES end,
  GetClubPrivileges = function(id) return { canSendInvitation = id ~= 13 } end,
  SendCharacterInvitation = function(id, n) table.insert(ENVIADAS, { id, n }) end,
}
-- El Enum del banco da 0 a todo: el de las comunidades, como en el juego.
rawset(Enum, "ClubType", { BattleNet = 0, Character = 1, Guild = 2, Other = 3 })

local unidades = {
  target = { jugador = true, nombre = "Nimzy Tinkerwidget", faccion = "Horde" },
  focus = { jugador = false, nombre = "Jabalí" },
  player = { jugador = true, nombre = "Lobato Garra", faccion = "Horde" },
}
local secreto = false
function UnitIsPlayer(u) return unidades[u] and unidades[u].jugador or false end
function UnitIsUnit(a, b) return a == b end
function UnitIsInMyGuild(u) return unidades[u] and unidades[u].guild or false end
local faccionReal = UnitFactionGroup
function UnitFactionGroup(u) local x = unidades[u] if x and x.faccion then return x.faccion end return faccionReal(u) end
local issecretReal = issecretvalue
function issecretvalue(v) return secreto and v == "Nimzy Tinkerwidget" or issecretReal(v) end

-- Los marcos del juego con su retrato (Camelot): tu marco, el objetivo y el foco.
local function marcoConRetrato(nombre, clave, retrato)
  local f = CreateFrame("Frame", nombre, UIParent)
  f[clave] = CreateFrame("Frame", nil, f)
  f[clave][retrato] = f[clave]:CreateTexture()
  return f
end
marcoConRetrato("PlayerFrame", "PlayerFrameContainer", "PlayerPortrait")
marcoConRetrato("TargetFrame", "TargetFrameContainer", "Portrait")
marcoConRetrato("FocusFrame", "TargetFrameContainer", "Portrait")

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
local A = Alfa
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local M = NS_OF("Alfa_Manada")
local L = M.L
local fullReal = A.Compat.UnitFullName
A.Compat.UnitFullName = function(u) local x = unidades[u] if x then return x.nombre end return fullReal(u) end

local DICHO = {}
local decirReal = M.U.Decir
M.U.Decir = function(...) table.insert(DICHO, table.concat({ ... }, " ")); return decirReal(...) end

local function submenu(raiz)
  for _, h in ipairs(raiz.hijos) do if h.texto == L["Invitar al clan"] then return h end end
end
local function textos(sub)
  local out = {}
  for _, h in ipairs(sub and sub.hijos or {}) do out[#out + 1] = (h.texto:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  return table.concat(out, " / ")
end
local RETRATO = { unit = "target", name = "Nimzy", fromTargetFrame = true }

step("se engancha a los menús de un jugador", function()
  for _, tag in ipairs({ "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_FRIEND", "MENU_UNIT_COMMUNITIES_WOW_MEMBER" }) do
    check(REGISTRADOS[tag] and #REGISTRADOS[tag] == 1, "sin gancho (o doble) en " .. tag)
  end
  check(not REGISTRADOS.MENU_UNIT_SELF, "no debe engancharse a tu propio retrato")
end)

step("el retrato: hermandad y comunidades con permiso", function()
  local raiz = abrir("MENU_UNIT_PLAYER", RETRATO)
  local sub = submenu(raiz)
  check(sub ~= nil, "no salió «Invitar al clan»")
  check(raiz.divisores == 1, "falta la línea que lo separa de lo del juego")
  local t = textos(sub)
  print("  submenú:", t)
  check(#sub.hijos == 2, "esperaba 2 destinos, salieron: " .. t)
  check(sub.hijos[1].texto:find("OLYMPUS SKYHiGH", 1, true) and sub.hijos[1].texto:find(L["hermandad"], 1, true), "la hermandad va primero")
  check(sub.hijos[2].texto:find("La Jauria", 1, true) and sub.hijos[2].texto:find(L["comunidad"], 1, true), "falta La Jauria")
  check(not t:find("BNet") and not t:find("Sin permiso"), "salió una comunidad que no deja invitar")
end)

step("un clic invita con el nombre completo y avisa", function()
  local sub = submenu(abrir("MENU_UNIT_PLAYER", RETRATO))
  ENVIADAS, DICHO = {}, {}
  sub.hijos[1].fn()
  sub.hijos[2].fn()
  check(#ENVIADAS == 2, "esperaba 2 invitaciones, hubo " .. #ENVIADAS)
  check(ENVIADAS[1] and ENVIADAS[1][1] == "hermandad" and ENVIADAS[1][2] == "Nimzy Tinkerwidget", "la de hermandad no llevó el nombre completo")
  check(ENVIADAS[2] and ENVIADAS[2][1] == 11 and ENVIADAS[2][2] == "Nimzy Tinkerwidget", "la de La Jauria no fue a su comunidad")
  check(#DICHO == 2 and DICHO[2]:find("La Jauria", 1, true), "no avisó en el chat")
  print("  aviso:", DICHO[2])
end)

step("su nombre en el chat (sin unidad)", function()
  ENVIADAS = {}
  local sub = submenu(abrir("MENU_UNIT_FRIEND", { name = "Yuki Zoldyck", chatTarget = "Yuki Zoldyck" }))
  check(sub and #sub.hijos == 2, "desde el chat deben salir los 2 destinos")
  if sub then sub.hijos[2].fn() end
  check(ENVIADAS[1] and ENVIADAS[1][2] == "Yuki Zoldyck", "no invitó a quien escribió en el chat")
end)

step("donde no debe salir", function()
  check(submenu(abrir("MENU_UNIT_PLAYER", { unit = "player", name = "Lobato" })) == nil, "salió en tu propio retrato")
  check(submenu(abrir("MENU_UNIT_FRIEND", { name = "Lobato Garra" })) == nil, "salió en tu propio nombre en el chat")
  check(submenu(abrir("MENU_UNIT_PLAYER", { unit = "focus", name = "Jabalí" })) == nil, "salió en una criatura")
  secreto = true
  check(submenu(abrir("MENU_UNIT_PLAYER", RETRATO)) == nil, "salió con el nombre secreto")
  secreto = false
  A.Set("manada.invitarMenu", false)
  check(submenu(abrir("MENU_UNIT_PLAYER", RETRATO)) == nil, "salió con el ajuste apagado")
  A.Set("manada.invitarMenu", true)
end)

step("la hermandad solo cuando toca", function()
  unidades.target.guild = true
  local t = textos(submenu(abrir("MENU_UNIT_PLAYER", RETRATO)))
  check(not t:find("OLYMPUS"), "ofreció la hermandad a quien ya es de ella")
  unidades.target.guild = nil
  unidades.target.faccion = "Alliance"
  t = textos(submenu(abrir("MENU_UNIT_PLAYER", RETRATO)))
  check(not t:find("OLYMPUS") and t:find("La Jauria"), "con la otra facción: sin hermandad, con comunidad (" .. t .. ")")
  unidades.target.faccion = "Horde"
  t = textos(submenu(abrir("MENU_UNIT_COMMUNITIES_GUILD_MEMBER", { name = "Yuki Zoldyck" })))
  check(not t:find("OLYMPUS"), "desde la lista de la hermandad no se ofrece la hermandad")
  puedoInvitar = false
  t = textos(submenu(abrir("MENU_UNIT_PLAYER", RETRATO)))
  check(not t:find("OLYMPUS"), "sin permiso de invitar salió la hermandad")
  puedoInvitar = true
end)

step("sin nada a dónde invitar no sale", function()
  enHermandad = false
  local antes = CLUBES
  CLUBES = {}
  C_Club.GetSubscribedClubs = function() return CLUBES end
  check(submenu(abrir("MENU_UNIT_PLAYER", RETRATO)) == nil, "salió vacío")
  CLUBES = antes
  enHermandad = true
end)

step("los textos caben en todos los idiomas", function()
  for _, k in ipairs({ "Invitar al clan", "hermandad", "comunidad" }) do
    check(#L[k] > 0 and #L[k] <= 48, "texto demasiado largo para el menú: " .. k)
  end
end)

-- Rotación (1.2.2): de fábrica la prioridad de Alfa; y aunque elijas la de
-- Blizzard, si esa no sugiere nada o llega secreta, sale la de Alfa con las
-- que siguen (antes quedaba un ícono suelto o nada).
step("rotación: la prioridad de Alfa cuando la de Blizzard no dice nada", function()
  local Cb = NS_OF("Alfa_Combate")
  local R, P = Cb.Rotacion, Cb.Prioridad
  local siguiente = nil
  C_AssistedCombat = { IsAvailable = function() return true end, GetRotationSpells = function() return {} end,
    GetNextCastSpell = function() return siguiente end }
  -- Un guerrero que conoce sus habilidades (el banco no trae hechizos).
  local conoce, nombre, icono = A.Compat.IsPlayerSpell, Cb.NombreHechizo, Cb.IconoHechizo
  A.Compat.IsPlayerSpell = function(id) return type(id) == "number" end
  Cb.NombreHechizo = function(id) return type(id) == "number" and ("Hechizo " .. id) or nil end
  Cb.IconoHechizo = function(id) return "icono-" .. tostring(id) end
  P.Olvidar()
  if not P.Hay() then print("  (el banco no conoce hechizos de la clase: se revisa solo la fuente)") end
  check(A.Get("combate.prioridadAlfa") == true, "la prioridad de Alfa debe venir encendida de fábrica")
  if P.Hay() then check(R.Fuente() == "alfa", "de fábrica la fuente debe ser Alfa, es " .. tostring(R.Fuente())) end
  A.Set("combate.prioridadAlfa", false)
  check(R.Fuente() == "blizzard", "apagada y con la de Blizzard disponible, la fuente es Blizzard")
  if P.Hay() then
    -- En combate, contra un enemigo, con todo listo para usar.
    local combate, existe, atacable, usable = UnitAffectingCombat, UnitExists, UnitCanAttack, C_Spell.IsSpellUsable
    UnitAffectingCombat = function() return true end
    UnitExists = function(u) if u == "target" then return true end return existe(u) end
    UnitCanAttack = function() return true end
    C_Spell.IsSpellUsable = function() return true, false end
    for _, caso in ipairs({ "nada", "secreto" }) do
      siguiente = caso == "secreto" and 133 or nil
      local secretoReal = issecretvalue
      if caso == "secreto" then issecretvalue = function(v) return v == 133 or secretoReal(v) end end
      R.Ver()
      local f = _G.AlfaCombateRotacion
      check(f and f:IsShown() and f.Principal:IsShown(), "sin la de Blizzard (" .. caso .. ") no se ve el ícono")
      local tex = f and f.Principal.Icono:GetTexture()
      print("  " .. caso .. ": ícono", tostring(tex))
      check(type(tex) == "string" and tex:find("^icono%-"), "con la de Blizzard " .. caso .. " el ícono no es de la prioridad de Alfa")
      issecretvalue = secretoReal
    end
    UnitAffectingCombat, UnitExists, UnitCanAttack, C_Spell.IsSpellUsable = combate, existe, atacable, usable
    R.Ver()
  end
  A.Set("combate.prioridadAlfa", true)
  A.Compat.IsPlayerSpell, Cb.NombreHechizo, Cb.IconoHechizo = conoce, nombre, icono
  P.Olvidar()
end)

step("la insignia de La Jauría en el borde del retrato", function()
  local Rt = M.Retrato
  unidades.player.nombre = "Toxic Darunia" -- un Alfa de la lista (Insignias.lua)
  Rt.Refrescar()
  local ch = Rt.Chapa("player")
  check(ch and ch.aro:IsShown() and ch.lobo:IsShown(), "tu insignia no sale en tu retrato")
  local c = ch and ch.aro._vc
  check(c and math.abs(c[1] - 0.949) < 0.01, "el aro de un Alfa no es dorado")
  check(not (Rt.Chapa("target") and Rt.Chapa("target").aro:IsShown()), "salió insignia en un objetivo sin ella")
  unidades.target.nombre = "Toxic Darunia"
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  check(Rt.Chapa("target") and Rt.Chapa("target").aro:IsShown(), "el objetivo con insignia no la muestra")
  secreto = false
  A.Set("manada.insigniaRetrato", false)
  T(1)
  check(not ch.aro:IsShown() and not Rt.Chapa("target").aro:IsShown(), "apagada, la insignia sigue en los retratos")
  A.Set("manada.insigniaRetrato", true)
  T(1)
  check(ch.aro:IsShown(), "al volver a encenderla no regresó")
  unidades.target.nombre = "Nimzy Tinkerwidget"
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  check(not Rt.Chapa("target").aro:IsShown(), "la insignia se quedó al cambiar de objetivo")
  unidades.player.nombre = "Lobato Garra"
  Rt.Refrescar()
end)

-- Botones (1.2.2): «Probar» de los avisos sale aunque haya otro a la vista.
step("Probar muestra el aviso de prueba aunque haya otro", function()
  local Av = NS_OF("Alfa_Inicio").Aviso
  Av.Mostrar({ clave = "otro", tipo = "info", titulo = "Otro aviso", texto = "algo" })
  Av.Probar()
  local f = _G.AlfaInicioAviso
  local hay = false
  local function ver(x) for _, h in ipairs(rawget(x, "_children") or {}) do
    if h._kind == "FontString" and h._text == "Así se ven tus avisos" and h:IsShown() then hay = true end
    ver(h) end end
  if f then ver(f) end
  check(f and f:IsShown() and hay, "Probar no mostró el aviso de prueba encima del otro")
  Av.Ocultar(true)
end)

print(string.format("PRUEBA: 1.2.2 invitar y rotación, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
