-- Prueba de la 1.3.1, Combate y Curación (tools/prueba.py la corre con las demás prueba_*.lua):
--   * el aviso para cortar con datos secretos (mazmorras): la textura y si se
--     puede cortar van tal cual al juego, sin `or` ni comparar con nil; y el
--     barrido de la recarga de tu corte sale (antes `dur` se perdía); si a tu
--     corte solo le falta recurso, ese es el que toca (Golpe con escudo en
--     defensiva con poca ira, no Patada);
--   * la barra de amenaza contra un jefe (valores secretos) sin `or`;
--   * el maná de los curanderos: el porcentaje secreto no se compara con nil
--     y el reloj curacion.mana sigue vivo en combate; la lista se arma solo
--     cuando cambia el grupo y el reloj solo repinta los porcentajes;
--   * la venda con «Curar y seleccionar» apagado: tipo "item", sin /target;
--   * M.Conocido se recuerda hasta que cambia tu libro, y la página calcula
--     tus hechizos por tipo una vez por repintado.
-- El SECRETO del banco es una tabla: `or` y `~= nil` no fallan con ella (en el
-- juego sí). Por eso los secretos se prueban también leyendo el código.
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
local function check(cond, msg) if not cond then NOTE("1.3.1 combate y curación", msg) end end
local function T(n) RUN_TIMERS(n or 1) end

-- Revisión de código: ninguna línea (sin contar comentarios) trae el patrón.
local function sinPatron(ruta, patrones)
  local f = io.open(ruta, "rb")
  check(f ~= nil, "no pude leer " .. ruta .. " (corre la escena desde la carpeta del proyecto)")
  if not f then return end
  local s = f:read("*a")
  f:close()
  local n = 0
  for linea in (s .. "\n"):gmatch("(.-)\r?\n") do
    n = n + 1
    local codigo = linea:gsub("%-%-.*$", "")
    for _, p in ipairs(patrones) do
      if codigo:find(p, 1, true) then
        check(false, ruta .. ":" .. n .. " todavía usa «" .. p .. "» (un secreto no se prueba con `or` ni se compara, ni con nil)")
      end
    end
  end
end

---------------------------------------------------------------------------
-- El juego simulado: un guerrero en grupo con un sacerdote y un druida
---------------------------------------------------------------------------
local SECRETO = setmetatable({}, { __tostring = function() return "<secreto>" end })
issecretvalue = function(v) return rawequal(v, SECRETO) end

local NOMBRES = {
  [6552] = "Patada", [1719] = "Temeridad", [2687] = "Ira sangrienta", [133] = "Bola de Fuego",
  [2050] = "Sanar inferior", [2054] = "Sanar", [2060] = "Sanación superior", [2061] = "Curación relámpago",
  [139] = "Renovar", [527] = "Disipar magia", [1243] = "Palabra de poder: entereza",
}
local POR_NOMBRE = {}
for id, n in pairs(NOMBRES) do POR_NOMBRE[n] = id end
local SABE = { [6552] = true, [1719] = true, [2687] = true, [2050] = true, [2054] = true, [2061] = true,
  [139] = true, [527] = true, [1243] = true }
local consultas = 0 -- veces que se pregunta al libro (C_SpellBook.IsSpellKnown)
local cds = {}
IsPlayerSpell = function(id) return SABE[id] == true end
C_SpellBook = { IsSpellKnown = function(id) consultas = consultas + 1 return SABE[id] == true end }
C_Spell = {
  GetSpellName = function(id) return NOMBRES[id] end,
  GetSpellInfo = function(x)
    local id = type(x) == "number" and x or POR_NOMBRE[x]
    return id and { spellID = id, name = NOMBRES[id] } or nil
  end,
  GetSpellTexture = function(id) return 100000 + (tonumber(id) or 0) end,
  IsSpellUsable = function(id) return SABE[id] == true, false end,
  IsSpellInRange = function() return true end,
  GetSpellCooldown = function(id)
    return cds[id] or { startTime = 0, duration = 0, isEnabled = true, isActive = false, modRate = 1, isOnGCD = false }
  end,
}

-- Tu barra: Patada en la casilla 1 (tecla F).
for i = 1, 12 do
  local b = rawget(_G, "ActionButton" .. i) or CreateFrame("CheckButton", "ActionButton" .. i, UIParent)
  b.action = i
  b:Show()
end
C_ActionBar = C_ActionBar or {}
C_ActionBar.FindSpellActionButtons = function(id) return id == 6552 and { 1 } or {} end
GetBindingKey = function(accion) return accion == "ACTIONBUTTON1" and "F" or nil end

-- Tú, tu grupo, tu objetivo y tu foco.
local CLASES = { player = "WARRIOR", party1 = "PRIEST", party2 = "DRUID", party3 = "MAGE" }
local NOMBRE_U = { player = "Lobato", party1 = "Colmillo", party2 = "Luna", party3 = "Aullido" }
local unidades = {}
local lanza = {}
local mana = { player = 100, party1 = 60, party2 = 20, party3 = 80 }
local manaSecreta = false
UnitClass = function(u) local c = CLASES[u] if c then return c, c, 1 end return nil end
UnitName = function(u) return NOMBRE_U[u], nil end
UnitExists = function(u) return unidades[u] == true or CLASES[u] ~= nil end
UnitCanAttack = function(_, u) return u == "target" or u == "focus" end
UnitIsDeadOrGhost = function() return false end
UnitIsUnit = function(a, b) return a == b end
UnitHealth = function() return 100 end
UnitHealthMax = function() return 100 end
UnitPower = function(u) if manaSecreta then return SECRETO end return mana[u] or 0 end
UnitPowerMax = function() if manaSecreta then return SECRETO end return 100 end
UnitPowerPercent = function(u) if manaSecreta then return SECRETO end return (mana[u] or 0) / 100 end
UnitGroupRolesAssigned = function() return "NONE" end
GetPartyAssignment = function() return false end
GetNumGroupMembers = function() return 4 end
GetShapeshiftFormID = function() return nil end
UnitCastingInfo = function(u)
  local c = lanza[u]
  if not c or c.canal then return nil end
  return c.nombre, c.nombre, c.tex, NOW * 1000, c.fin or (NOW + 2) * 1000, false, "Cast-1", c.inmune, 686
end
UnitChannelInfo = function() return nil end

local combate, grupo = false, true
InCombatLockdown = function() return combate end
UnitAffectingCombat = function() return combate end
IsInGroup = function() return grupo end
IsInRaid = function() return false end
local amenaza = { false, 0, 0 }
UnitDetailedThreatSituation = function() return amenaza[1], amenaza[2], amenaza[3], amenaza[3], 1000 end

-- Auras (nadie tiene perjuicios) y las bolsas: una venda de seda.
C_UnitAuras = {
  GetUnitAuraInstanceIDs = function() return {} end,
  GetAuraDataByAuraInstanceID = function() return nil end,
  GetAuraDataBySpellName = function() return nil end,
}
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end
C_Container.GetContainerItemID = function(b, i) if b == 0 and i == 2 then return 6450 end return nil end

-- El medidor del juego (el resumen lo lee al salir de combate).
Enum.DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6,
  DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 }
Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }
C_DamageMeter = {
  IsDamageMeterAvailable = function() return true, "" end,
  GetCombatSessionFromType = function() return { combatSources = {}, maxAmount = 1, totalAmount = 1, durationSeconds = 30 } end,
  GetCombatSessionFromID = function() return { combatSources = {} } end,
  GetAvailableCombatSessions = function() return {} end,
  GetSessionDurationSeconds = function() return 30 end,
  GetCombatSessionSourceFromType = function() return { combatSpells = {}, maxAmount = 1, totalAmount = 1 } end,
}

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
local A, N = Alfa, AlfaNucleo
local Co = NS_OF("Alfa_Combate")
local Cu = NS_OF("Alfa_Curacion")
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local function texto(fs) return fs and fs.GetText and tostring(fs:GetText() or "") or "" end
local function visible(f) return f and f:IsShown() and true or false end
local function entrar() combate = true FIRE_EVENT("PLAYER_REGEN_DISABLED") end
local function salir() combate = false FIRE_EVENT("PLAYER_REGEN_ENABLED") end

---------------------------------------------------------------------------
-- 1. Cortar en una mazmorra: la textura y si se puede cortar, secretos
---------------------------------------------------------------------------
step("Cortar: con datos secretos se pasan tal cual, sin `or` ni comparar con nil", function()
  sinPatron("src/Alfa_Combate/Corte.lua", { "x.textura or", "x.inmune ~= nil", "x.inmune == nil" })
  unidades.target = true
  lanza.target = { nombre = "Descarga de las Sombras", inmune = false, tex = 136197 }
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  local f = _G.AlfaCombateCorte
  check(visible(f), "no salió el aviso para cortar")
  if not f then return end
  local tex, alfa
  local setTex = f.Lanza.SetTexture
  f.Lanza.SetTexture = function(self, t, ...) tex = { t } return setTex(self, t, ...) end
  f.Cuerpo.SetAlphaFromBoolean = function(self, b, si, no) alfa = { b = b, si = si, no = no } end
  -- Lo que se puede leer no pasa por SetAlphaFromBoolean.
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  check(alfa == nil, "con «se puede cortar» legible igual llamó a SetAlphaFromBoolean")
  -- En una mazmorra: todo secreto.
  lanza.target = { nombre = SECRETO, inmune = SECRETO, fin = SECRETO, tex = SECRETO }
  tex, alfa = nil, nil
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  check(visible(f) and texto(f.Titulo) == "¡Está lanzando!", "con secretos no salió «¡Está lanzando!»: " .. texto(f.Titulo))
  check(tex and rawequal(tex[1], SECRETO), "la textura secreta no llegó tal cual a SetTexture")
  check(alfa and rawequal(alfa.b, SECRETO) and alfa.si == 0 and alfa.no == 1, "no le pasó el secreto a SetAlphaFromBoolean")
  -- Sin textura legible, el lobo.
  lanza.target = { nombre = "Sanar", inmune = false }
  tex = nil
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  check(tex and tex[1] ~= nil, "sin textura no puso al lobo")
  f.Lanza.SetTexture, f.Cuerpo.SetAlphaFromBoolean = nil, nil
  lanza.target = nil
  FIRE_EVENT("UNIT_SPELLCAST_STOP", "target")
  check(not visible(f), "el aviso no se fue al terminar")
end)

step("Cortar: con tu corte en recarga, su ícono lleva el barrido", function()
  local f = _G.AlfaCombateCorte
  check(f and f.Tuyo and f.Tuyo.Recarga, "el aviso no tiene el barrido de tu corte")
  if not (f and f.Tuyo and f.Tuyo.Recarga) then return end
  local cd = f.Tuyo.Recarga
  local puesto, limpio
  cd.SetCooldown = function(self, inicio, dur) puesto = { inicio = inicio, dur = dur } end
  cd.Clear = function() limpio = true end
  cds[6552] = { startTime = NOW - 2, duration = 10, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
  lanza.target = { nombre = "Descarga de las Sombras", inmune = false, tex = 136197 }
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  check(texto(f.Linea):find("vuelve en 8 s", 1, true), "no dice cuánto le falta a Patada: " .. texto(f.Linea))
  check(puesto and puesto.dur == 10, "el barrido no se puso con la recarga de 10 s (la duración se perdía)")
  if puesto then check(math.abs(puesto.inicio - (NOW - 2)) < 0.01, "el barrido no empieza cuando empezó la recarga: " .. tostring(puesto.inicio)) end
  -- Lista: el barrido se quita.
  cds[6552], puesto, limpio = nil, nil, nil
  FIRE_EVENT("UNIT_SPELLCAST_START", "target")
  check(limpio and not puesto, "con Patada lista el barrido no se quitó")
  cd.SetCooldown, cd.Clear = nil, nil
  lanza.target, unidades.target = nil, nil
  FIRE_EVENT("UNIT_SPELLCAST_STOP", "target")
end)

step("Cortar: si solo te falta ira, esa es tu habilidad (Golpe con escudo en defensiva)", function()
  local usable = C_Spell.IsSpellUsable
  NOMBRES[72], SABE[72] = "Golpe con escudo", true
  local estado = {} -- id -> { se puede, le falta recurso }
  C_Spell.IsSpellUsable = function(id)
    local e = estado[id]
    if e then return e[1], e[2] end
    return SABE[id] == true, false
  end
  local function cual() return Co.Corte.Habilidad() end
  -- Defensiva con escudo y poca ira: Patada no va (actitud), a Golpe con escudo le falta ira.
  estado[6552], estado[72] = { false, false }, { false, true }
  check(cual() == 72, "en defensiva con poca ira no eligió Golpe con escudo: " .. tostring(cual()))
  -- A las dos les falta ira: la primera de la lista.
  estado[6552] = { false, true }
  check(cual() == 6552, "si a las dos les falta ira no eligió Patada: " .. tostring(cual()))
  -- Rabiosa con ira: Patada.
  estado[6552], estado[72] = { true, false }, { false, false }
  check(cual() == 6552, "en rabiosa con ira no eligió Patada: " .. tostring(cual()))
  -- Ninguna se puede ni por recurso: la primera que conoces, como antes.
  estado[6552], estado[72] = { false, false }, { false, false }
  check(cual() == 6552, "sin ninguna lista no volvió a la primera: " .. tostring(cual()))
  -- Lo secreto no cuenta como «le falta recurso».
  estado[72] = { SECRETO, SECRETO }
  check(cual() == 6552, "un valor secreto contó como que le falta ira: " .. tostring(cual()))
  C_Spell.IsSpellUsable = usable
  NOMBRES[72], SABE[72] = nil, nil
  check(cual() == 6552, "al volver todo, el corte no es Patada: " .. tostring(cual()))
end)

---------------------------------------------------------------------------
-- 2. Amenaza contra un jefe: valores secretos
---------------------------------------------------------------------------
step("Amenaza: contra un jefe el secreto va tal cual a la barra, sin `or`", function()
  sinPatron("src/Alfa_Combate/Amenaza.lua", { "SetValue, f.Barra, r.pct or" })
  local Am = Co.Amenaza
  unidades.target = true
  entrar()
  amenaza = { false, 0, 40 }
  Am.Ver()
  local f = _G.AlfaCombateAmenaza
  check(visible(f), "en grupo y en combate no salió la barra de amenaza")
  if not f then return end
  local valor
  local setV = f.Barra.SetValue
  f.Barra.SetValue = function(self, v) valor = { v } return setV(self, v) end
  amenaza = { SECRETO, SECRETO, SECRETO }
  Am.Ver()
  check(valor and rawequal(valor[1], SECRETO), "el porcentaje secreto no llegó tal cual a SetValue")
  check(visible(f) and texto(f.Aviso) == "" and texto(f.Valor) == "", "con secretos la barra comparó o avisó")
  -- Vacía (sin amenaza legible): 0, no nil.
  amenaza = { false, 0, 55 }
  Am.Ver()
  check(valor and valor[1] == 55, "la barra no muestra 55: " .. tostring(valor and valor[1]))
  f.Barra.SetValue = nil
  salir()
  unidades.target = nil
  Am.Ver()
end)

---------------------------------------------------------------------------
-- 3. El maná de los curanderos en combate: secreto
---------------------------------------------------------------------------
step("Maná: el porcentaje secreto no se compara y el reloj sigue vivo", function()
  sinPatron("src/Alfa_Curacion/Mana.lua", { "p ~= nil", "p == nil" })
  local Mn = Cu.Mana
  Mn.Refrescar()
  check(AlfaCuracionMana and AlfaCuracionMana:IsShown() and Mn.filas == 2, "no se ve el maná del sacerdote y la druida")
  combate = true
  manaSecreta = true
  local antes = #ERRORS
  T(6)
  check(#ERRORS == antes, "el maná secreto dio errores en combate")
  check(N.HayTarea("curacion.mana"), "el reloj curacion.mana se quitó en combate")
  local t = N.Reloj.lista["curacion.mana"]
  check(t and t.fallos == 0, "el reloj curacion.mana tiene fallos: " .. tostring(t and t.fallos))
  manaSecreta = false
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  T(1)
  check(Mn.filas == 2 and AlfaCuracionMana:IsShown(), "al salir de combate el maná no volvió")
end)

step("Maná: la lista se arma solo cuando cambia el grupo; el reloj solo repinta el porcentaje", function()
  local Mn = Cu.Mana
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  check(Mn.filas == 2, "tras GROUP_ROSTER_UPDATE no se ven 2 curanderos: " .. tostring(Mn.filas))
  local origL, origC, armadas, colores = Mn.Lista, Cu.ColorDeClase, 0, 0
  Mn.Lista = function(...) armadas = armadas + 1 return origL(...) end
  Cu.ColorDeClase = function(...) colores = colores + 1 return origC(...) end
  mana.party2 = 70
  T(5)
  check(armadas == 0, "el reloj volvió a armar la lista " .. armadas .. " veces sin cambios en el grupo")
  check(colores == 0, "el reloj volvió a buscar el color de clase " .. colores .. " veces")
  local fila = AlfaCuracionMana and AlfaCuracionMana.filas[2]
  check(fila and fila.valor:GetText() == "70%", "el reloj no repintó el maná de la druida: " .. tostring(fila and fila.valor:GetText()))
  -- Un nombre que llega tarde: UNIT_NAME_UPDATE de alguien del grupo.
  NOMBRE_U.party1 = "Colmillo Negro"
  FIRE_EVENT("UNIT_NAME_UPDATE", "party1")
  check(armadas == 1, "UNIT_NAME_UPDATE del grupo no volvió a armar la lista: " .. armadas)
  check(AlfaCuracionMana.filas[1].nombre:GetText() == "Colmillo Negro", "el nombre nuevo no salió: " .. tostring(AlfaCuracionMana.filas[1].nombre:GetText()))
  -- La placa de un enemigo no cuenta.
  FIRE_EVENT("UNIT_NAME_UPDATE", "nameplate3")
  check(armadas == 1, "UNIT_NAME_UPDATE de una placa armó la lista")
  -- Entra un chamán (GROUP_ROSTER_UPDATE) y cambian los roles (PLAYER_ROLES_ASSIGNED).
  CLASES.party3 = "SHAMAN"
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  check(Mn.filas == 3, "el chamán nuevo no entró a la lista: " .. tostring(Mn.filas))
  local n = armadas
  FIRE_EVENT("PLAYER_ROLES_ASSIGNED")
  check(armadas == n + 1, "PLAYER_ROLES_ASSIGNED no volvió a armar la lista")
  CLASES.party3, NOMBRE_U.party1, mana.party2 = "MAGE", "Colmillo", 20
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  Mn.Lista, Cu.ColorDeClase = origL, origC
  check(Mn.filas == 2, "al salir el chamán no volvió a 2 curanderos: " .. tostring(Mn.filas))
end)

---------------------------------------------------------------------------
-- 4. La venda sin «Curar y seleccionar»
---------------------------------------------------------------------------
local function correrRefresco(attrs)
  local b = { a = {} }
  for k, v in pairs(attrs) do b.a[k] = v end
  function b:GetAttribute(k) return self.a[k] end
  function b:SetAttribute(k, v) self.a[k] = v end
  local fn = assert(loadstring(Cu.REFRESCO))
  setfenv(fn, { self = b, gmatch = string.gmatch })
  fn()
  return b.a
end

step("La venda: con «Curar y seleccionar» apagado no te cambia el objetivo", function()
  local boton = CreateFrame("Button", "AlfaPruebaCuracion131", UIParent, "SecureUnitButtonTemplate")
  boton:SetSize(88, 36)
  boton:SetAttribute("unit", "party1")
  Cu.PrepararBoton(boton)
  local a = function(k) return boton:GetAttribute(k) end
  Cu.FijarCurarSelecciona(true)
  Cu.FijarRanura("ctrl-3", { t = "venda" })
  check(Cu.venda == 6450, "no encontró la venda de seda: " .. tostring(Cu.venda))
  check(a("ctrl-type3") == "macro" and a("ctrl-macrotext3") == "/target party1\n/use [@party1] item:6450",
    "prendido, la venda no cura y selecciona: " .. tostring(a("ctrl-macrotext3")))
  Cu.FijarCurarSelecciona(false)
  check(a("ctrl-type3") == "item", "apagado, la venda no va como \"item\": " .. tostring(a("ctrl-type3")))
  check(a("ctrl-item3") == "item:6450", "apagado, falta el objeto de la venda: " .. tostring(a("ctrl-item3")))
  check(a("ctrl-macrotext3") == nil, "apagado, sobra la macro con /target: " .. tostring(a("ctrl-macrotext3")))
  local obj = a("alfa-objetivos") or ""
  check(not obj:find("ctrl-:3", 1, true), "apagado, la venda sigue en alfa-objetivos: " .. obj)
  -- Con otra unidad (en combate, el fragmento seguro) tampoco sale /target.
  local attrs = {}
  for k, v in pairs(boton._attr) do attrs[k] = v end
  attrs.unit = "raid17"
  local r = correrRefresco(attrs)
  check(r["ctrl-macrotext3"] == nil, "el fragmento seguro le puso /target a la venda: " .. tostring(r["ctrl-macrotext3"]))
  -- Los botones nuevos de la cabecera la copian igual.
  if Cu.cabecera then
    check(Cu.cabecera:GetAttribute("_initialAttribute-ctrl-item3") == "item:6450", "la cabecera no copia el objeto de la venda")
    check((Cu.cabecera:GetAttribute("_initialAttributeNames") or ""):find("ctrl-item3", 1, true), "ctrl-item3 no está en _initialAttributeNames")
  end
  -- Volver a prenderlo devuelve la macro; sin acción no queda nada.
  Cu.FijarCurarSelecciona(true)
  check(a("ctrl-type3") == "macro" and a("ctrl-item3") == nil, "al prender no volvió la macro de la venda")
  Cu.FijarRanura("ctrl-3", { t = "nada" })
  check(a("ctrl-type3") == nil and a("ctrl-item3") == nil, "sin acción quedó algo en ctrl-3")
end)

---------------------------------------------------------------------------
-- 5. Lo que conoces, recordado; la página, una vez por repintado
---------------------------------------------------------------------------
step("M.Conocido se recuerda hasta que cambia tu libro", function()
  FIRE_EVENT("SPELLS_CHANGED")
  consultas = 0
  check(Cu.Conocido("sanar") == 2054, "no reconoce Sanar")
  local primera = consultas
  check(primera > 0, "la primera vez no preguntó al libro")
  check(Cu.Conocido("sanar") == 2054 and Cu.Conocido("sanar") == 2054, "la segunda vez cambió la respuesta")
  check(consultas == primera, "la segunda vez volvió a preguntar al libro (" .. (consultas - primera) .. " veces)")
  -- Lo que no conoces también se recuerda.
  check(Cu.Conocido("sanacionSuperior") == nil, "dice que conoces Sanación superior")
  local n = consultas
  Cu.Conocido("sanacionSuperior")
  check(consultas == n, "lo que no conoces se vuelve a preguntar")
  -- Aprendes un hechizo: el instructor (LEARNED_SPELL_IN_SKILL_LINE).
  SABE[2060] = true
  FIRE_EVENT("LEARNED_SPELL_IN_SKILL_LINE", 2060, 1, false)
  check(Cu.Conocido("sanacionSuperior") == 2060, "tras aprenderlo no reconoce Sanación superior")
  -- Cambia tu libro (SPELLS_CHANGED): se vuelve a leer.
  SABE[2060] = nil
  FIRE_EVENT("SPELLS_CHANGED")
  check(Cu.Conocido("sanacionSuperior") == nil, "tras SPELLS_CHANGED sigue la respuesta vieja")
  -- Las listas siguen completas.
  local op = Cu.OpcionesDe("1")
  local disipar = false
  for _, o in ipairs(op) do if o.valor == "spell:527" then disipar = true end end
  check(disipar, "la lista de un clic perdió Disipar magia")
end)

step("La página calcula tus hechizos por tipo una vez por repintado", function()
  local ok, e = pcall(function() A.Fire("SHOW_OPTIONS", "curacion") T(2) end)
  check(ok, "la página de Curación falló: " .. tostring(e))
  local vista = Cu.vista
  check(vista and vista:IsVisible(), "la página de Curación no está a la vista")
  if not (vista and vista:IsVisible()) then return end
  local orig, veces = Cu.HechizosPorCategoria, 0
  Cu.HechizosPorCategoria = function(...) veces = veces + 1 return orig(...) end
  local origR, repintados = vista.Refresh, 0
  vista.Refresh = function(...) repintados = repintados + 1 return origR(...) end
  N.Set("curacion", "ancho", 90)
  T(1)
  vista.Refresh = origR
  Cu.HechizosPorCategoria = orig
  check(repintados >= 1, "al mover el ancho la página no se repintó")
  check(veces <= repintados, ("la página calculó tus hechizos %d veces en %d repintado(s)"):format(veces, repintados))
  N.Set("curacion", "ancho", 88)
  T(1)
  local f = A.UI and A.UI.Options and A.UI.Options.frame
  if f then f:Hide() end
end)

print(string.format("PRUEBA: 1.3.1 combate y curación, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
