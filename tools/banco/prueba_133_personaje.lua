-- Prueba de la 1.3.3, Personaje (Combate, Curación y Talentos; tools/prueba.py la corre con las demás):
--   1. el corte suena (más suave) en una instancia aunque el juego oculte el
--      hechizo (corteSonidoOculto); fuera de instancias, no;
--   2. contra un jefe (detalle de amenaza secreto) la barra avisa con
--      UnitThreatSituation, sin porcentaje;
--   3. en combate, el cuadro de un marco de Curación es corto: solo las líneas
--      de Alfa, sin SetUnit (descripcionCombate);
--   4. sin roles, el maná de los curanderos muestra solo a quienes curaron;
--   5. la entrada en silencio: «Así se lee tu ayuda de rotación» y «Tienes N
--      puntos de talento» no salen al entrar; la tarjeta de rangos viejos y las
--      líneas de Curación esperan a que termine N.Entrando() o la primera pelea.
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
local function check(cond, msg) if not cond then NOTE("1.3.3 personaje", msg) end end
local function T(n) RUN_TIMERS(n or 1) end

local SECRETO = setmetatable({}, { __tostring = function() return "<secreto>" end })
issecretvalue = function(v) return rawequal(v, SECRETO) end

---------------------------------------------------------------------------
-- El juego simulado: un guerrero en grupo con un sacerdote y una druida
---------------------------------------------------------------------------
local NOMBRES = { [6552] = "Patada", [6554] = "Patada", [2054] = "Sanar", [527] = "Disipar magia", [5185] = "Toque de sanación", [133] = "Bola de Fuego" }
local SABE = { [6552] = true, [527] = true }
IsPlayerSpell = function(id) return SABE[id] == true end
C_SpellBook = { IsSpellKnown = function(id) return SABE[id] == true end }
C_Spell = {
  GetSpellName = function(id) return NOMBRES[id] end,
  GetSpellInfo = function(x) return type(x) == "number" and NOMBRES[x] and { spellID = x, name = NOMBRES[x] } or nil end,
  GetSpellTexture = function(id) return 100000 + (tonumber(id) or 0) end,
  IsSpellUsable = function(id) return SABE[id] == true, false end,
  IsSpellInRange = function() return true end,
  GetSpellCooldown = function() return { startTime = 0, duration = 0, isEnabled = true, isActive = false, modRate = 1, isOnGCD = false } end,
}
local CLASES = { player = "WARRIOR", party1 = "PRIEST", party2 = "DRUID" }
local NOMBRE_U = { player = "Lobato", party1 = "Colmillo", party2 = "Luna" }
local roles = {}
local unidades = {}
local lanza = {}
local grupo, instancia, combate = true, false, false
UnitClass = function(u) local c = CLASES[u] if c then return c, c, 1 end return nil end
UnitName = function(u) return NOMBRE_U[u], nil end
UnitExists = function(u) if u == "party1" or u == "party2" then return grupo end return unidades[u] == true or u == "player" end
UnitCanAttack = function(_, u) return u == "target" or u == "focus" end
UnitIsDeadOrGhost = function() return false end
UnitIsUnit = function(a, b) return a == b end
UnitHealth = function() return 100 end
UnitHealthMax = function() return 100 end
UnitPower = function() return 60 end
UnitPowerMax = function() return 100 end
UnitGroupRolesAssigned = function(u) return roles[u] or "NONE" end
GetNumGroupMembers = function() return grupo and 3 or 0 end
GetShapeshiftFormID = function() return nil end
UnitCastingInfo = function(u)
  local c = lanza[u]
  if not c then return nil end
  return c.nombre, c.nombre, c.tex or 136197, NOW * 1000, c.fin or (NOW + 2) * 1000, false, "Cast-1", c.inmune, 686
end
UnitChannelInfo = function() return nil end
InCombatLockdown = function() return combate end
UnitAffectingCombat = function() return combate end
IsInGroup = function() return grupo end
IsInRaid = function() return false end
IsInInstance = function() return instancia, instancia and "party" or "none" end
local detalle = { false, 0, 0 }
local estado = nil
UnitDetailedThreatSituation = function() return detalle[1], detalle[2], detalle[3], detalle[3], 0 end
UnitThreatSituation = function(u, mob) if u == "player" and mob == "target" then return estado end return nil end
local auras = {}
C_UnitAuras = {
  GetUnitAuraInstanceIDs = function(u) local a = auras[u] return a and { a.id } or {} end,
  GetAuraDataByAuraInstanceID = function(u, id) local a = auras[u] if a and a.id == id then return { auraInstanceID = id, dispelName = a.tipo, icon = 136071 } end return nil end,
  GetAuraDataBySpellName = function() return nil end,
}
Enum.DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6,
  DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 }
Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }
C_DamageMeter = {
  IsDamageMeterAvailable = function() return true, "" end,
  GetCombatSessionFromType = function() return { combatSources = {}, maxAmount = 1, totalAmount = 1 } end,
  GetCombatSessionFromID = function() return { combatSources = {} } end,
  GetAvailableCombatSessions = function() return {} end,
  GetSessionDurationSeconds = function() return nil end,
  GetCombatSessionSourceFromType = function() return { combatSpells = {} } end,
}

local A, N = Alfa, AlfaNucleo
local K = N.Kit
-- La entrada de Alfa (la del Núcleo, simulada: puede no estar todavía).
local entrandoReal = rawget(N, "Entrando")
local entrando = true
N.Entrando = function() return entrando end
-- Lo que sale al entrar: los avisos del Kit y las líneas del chat.
local avisos, lineas = {}, {}
local avisar = K.Aviso
K.Aviso = function(o, ...) avisos[#avisos + 1] = type(o) == "table" and tostring(o.titulo) or "?" return avisar(o, ...) end
local imprimir = N.Imprimir
N.Imprimir = function(t, ...) lineas[#lineas + 1] = tostring(t) return imprimir(t, ...) end
local function hay(lista, trozo)
  for _, t in ipairs(lista) do if t:find(trozo, 1, true) then return true end end
  return false
end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(12)
local Co = NS_OF("Alfa_Combate")
local Cu = NS_OF("Alfa_Curacion")
local Bd = NS_OF("Alfa_Builds")
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local sonidos = {}
local tocar = A.PlaySound
A.PlaySound = function(kit, ...) sonidos[#sonidos + 1] = kit if tocar then return tocar(kit, ...) end end
local SUAVE = (SOUNDKIT and SOUNDKIT.MAP_PING) or 3175
local FUERTE = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959

local function texto(fs) return fs and fs.GetText and tostring(fs:GetText() or "") or "" end
local function visible(f) return f and f:IsShown() and true or false end
local function entrar() combate = true FIRE_EVENT("PLAYER_REGEN_DISABLED") end
local function salir() combate = false FIRE_EVENT("PLAYER_REGEN_ENABLED") end

---------------------------------------------------------------------------
-- 5. La entrada en silencio (primero: es lo que pasó al entrar)
---------------------------------------------------------------------------
-- (Lo que salió al entrar, antes de que las pruebas limpien la lista; y
-- antes de cualquier pelea, que suelta lo que espera.)
local alEntrar = avisos
avisos = {}
step("Al entrar: ni la ayuda de rotación ni los puntos de talento", function()
  check(not hay(alEntrar, "Así se lee tu ayuda de rotación"), "al entrar salió «Así se lee tu ayuda de rotación»")
  check(not hay(alEntrar, "punto de talento") and not hay(alEntrar, "puntos de talento"), "al entrar salió el aviso de tus puntos de talento")
  local d = N.DatosPersonaje("combate")
  check(not d.presentado, "la ayuda de rotación se dio por presentada al entrar")
  -- Tras tu primera pelea sí (si hay ayuda de rotación para ti).
  if Co.Rotacion.Fuente() then
    entrar() salir()
    check(d.presentado == true, "tras tu primera pelea no se presentó la ayuda de rotación")
  else
    print("AVISO: sin ayuda de rotación en el banco: no se prueba su presentación tras la pelea")
  end
end)

step("Al entrar: la tarjeta de rangos viejos espera a que termine la entrada", function()
  entrando = true
  Bd.ComoAlEntrar() -- (todavía sin pelear)
  local cerrada = 0
  local pedido = { accion = "mostrar", tipo = "SPELL_CARDS", Cerrar = function() cerrada = cerrada + 1 end,
    modelo = { kind = "oldRanks", act = true, spells = { { id = 6552, bestId = 6554 } } } }
  avisos = {}
  local porLya = K.PorLya
  K.PorLya = function() return false end -- (que no la diga Lya: aquí se mira el aviso)
  check(A.Reemplazos.Llamar("SPELL_CARDS", pedido), "Talentos no tomó la tarjeta de hechizos del motor")
  check(not hay(avisos, "rango viejo"), "mientras Alfa entra salió la tarjeta de rangos viejos")
  check(Bd.TarjetaEsperando(), "la tarjeta de rangos viejos no quedó esperando")
  -- Termina la entrada: sale.
  entrando = false
  T(1)
  check(hay(avisos, "rango viejo"), "al terminar la entrada no salió la tarjeta de rangos viejos")
  check(not Bd.TarjetaEsperando(), "la tarjeta siguió esperando")
  -- O tras la primera pelea, aunque la entrada siga (y después ya no espera).
  entrando = true
  avisos = {}
  A.Reemplazos.Llamar("SPELL_CARDS", pedido)
  check(not hay(avisos, "rango viejo"), "otra vez entrando, salió la tarjeta")
  entrar() salir()
  check(hay(avisos, "rango viejo"), "tras la primera pelea no salió la tarjeta de rangos viejos")
  avisos = {}
  A.Reemplazos.Llamar("SPELL_CARDS", pedido)
  check(not Bd.TarjetaEsperando(), "después de tu primera pelea la tarjeta volvió a esperar")
  K.PorLya = porLya
  entrando = false
end)

step("Al entrar: las líneas de Curación esperan a que termine la entrada", function()
  Cu.ComoAlEntrar() -- (todavía sin pelear)
  -- Un compañero con magia que puedes quitar, y ningún clic que la quite.
  CLASES.player = "PRIEST"
  SABE[527] = true
  FIRE_EVENT("SPELLS_CHANGED")
  local boton = CreateFrame("Button", "AlfaPrueba133", UIParent, "SecureUnitButtonTemplate")
  boton:SetSize(88, 36)
  boton:SetAttribute("unit", "party1")
  Cu.PrepararBoton(boton)
  Cu.FijarRanura("shift-1", { t = "nada" })
  Cu.FijarRanura("ctrl-1", { t = "nada" })
  auras.party1 = { id = 41, tipo = "Magic" }
  entrando = true
  lineas = {}
  Cu.ActualizarTodo(boton)
  check(not hay(lineas, "ningún clic lo hace"), "mientras Alfa entra salió la línea del perjuicio sin clic")
  check(Cu.Esperando("sinQuitar.Magic"), "la línea del perjuicio sin clic no quedó esperando")
  entrando = false
  T(1)
  check(hay(lineas, "ningún clic lo hace"), "al terminar la entrada no salió la línea del perjuicio sin clic")
  -- El hechizo nuevo (diálogo y línea) también espera.
  entrando = true
  lineas, avisos = {}, {}
  local d = Cu.Datos()
  d.preajuste, d.mapa, d.rechazos = "curar", {}, {}
  Cu.RevisarMejoras()
  check(not hay(lineas, "Hechizo nuevo para tus clics") and not hay(avisos, "Hechizo nuevo para tus clics"), "mientras Alfa entra salió el hechizo nuevo")
  check(Cu.Esperando("mejoras"), "el hechizo nuevo no quedó esperando")
  entrar() salir()
  T(3)
  -- (1.3.6: ahora es un aviso con «Abrir Curación», no una línea del chat)
  check(hay(lineas, "Hechizo nuevo para tus clics") or hay(avisos, "Hechizo nuevo para tus clics"), "tras la primera pelea no se ofreció el hechizo nuevo")
  if K.CerrarDialogo then K.CerrarDialogo() end
  entrando = false
  auras.party1 = nil
  Cu.ActualizarTodo(boton)
  Cu.botonPrueba133 = boton
end)

---------------------------------------------------------------------------
-- 1. El corte suena en mazmorras
---------------------------------------------------------------------------
step("Corte: en una instancia, con el hechizo oculto, suena más suave", function()
  unidades.target = true
  local function lanzar(c)
    lanza.target = nil
    FIRE_EVENT("UNIT_SPELLCAST_STOP", "target")
    NOW = NOW + 3
    lanza.target = c
    sonidos = {}
    FIRE_EVENT("UNIT_SPELLCAST_START", "target")
    return sonidos[1]
  end
  CLASES.player = "WARRIOR"
  check(A.Get("combate.corteSonidoOculto") == true, "combate.corteSonidoOculto no viene prendido")
  grupo, instancia = true, true
  local oculto = { nombre = SECRETO, inmune = SECRETO, fin = SECRETO, tex = SECRETO }
  check(lanzar(oculto) == SUAVE, "en una instancia, con el hechizo oculto, no sonó el sonido suave: " .. tostring(sonidos[1]))
  check(lanzar({ nombre = "Descarga de las Sombras", inmune = false }) == FUERTE, "en una instancia, lo que se puede cortar no sonó fuerte")
  instancia = false
  check(lanzar(oculto) == nil, "fuera de una instancia sonó con el hechizo oculto")
  instancia = true
  A.Set("combate.corteSonidoOculto", false)
  check(lanzar(oculto) == nil, "con «Más suave si el juego oculta el hechizo» apagado, sonó")
  A.Set("combate.corteSonidoOculto", true)
  A.Set("combate.corteSonido", false)
  check(lanzar(oculto) == nil, "con el sonido del corte apagado, sonó")
  A.Set("combate.corteSonido", true)
  instancia = false
  lanza.target, unidades.target = nil, nil
  FIRE_EVENT("UNIT_SPELLCAST_STOP", "target")
end)

---------------------------------------------------------------------------
-- 2. Amenaza contra un jefe
---------------------------------------------------------------------------
step("Amenaza: contra un jefe avisa con tu estado aunque no haya porcentaje", function()
  local Am = Co.Amenaza
  unidades.target = true
  grupo = true
  entrar()
  detalle, estado = { false, 0, 40 }, 0
  Am.Ver()
  local f = rawget(_G, "AlfaCombateAmenaza")
  check(visible(f), "no salió la barra de amenaza")
  if not f then return end
  detalle = { SECRETO, SECRETO, SECRETO }
  estado = 3
  local antes = #sonidos
  Am.Ver()
  check(texto(f.Aviso):find("atacando a ti", 1, true), "contra un jefe no avisó que te ataca a ti: " .. texto(f.Aviso))
  check(texto(f.Valor) == "", "contra un jefe escribió un porcentaje que no se puede leer: " .. texto(f.Valor))
  check(#sonidos == antes + 1, "contra un jefe no sonó al pasar a peligro")
  estado = 1
  Am.Ver()
  check(texto(f.Aviso):find("tanque", 1, true), "contra un jefe no avisó que casi se lo quitas al tanque: " .. texto(f.Aviso))
  -- Como tanque: están por quitártelo.
  A.Set("combate.amenazaPapel", "tanque")
  estado = 2
  Am.Ver()
  check(texto(f.Aviso):find("quitártelo", 1, true), "como tanque, contra un jefe, no avisó que están por quitártelo: " .. texto(f.Aviso))
  A.Set("combate.amenazaPapel", "auto")
  -- Sin estado legible: como antes, sin avisos.
  estado = SECRETO
  Am.Ver()
  check(texto(f.Aviso) == "" and texto(f.Valor) == "", "con todo secreto avisó o escribió algo")
  estado = nil
  salir()
  unidades.target = nil
  Am.Ver()
end)

---------------------------------------------------------------------------
-- 3. El cuadro corto de Curación en combate
---------------------------------------------------------------------------
step("Curación: en combate, un cuadro corto con las líneas de Alfa y sin SetUnit", function()
  local boton = Cu.botonPrueba133
  check(boton, "no está el botón de prueba de Curación")
  if not boton then return end
  CLASES.player = "PRIEST"
  Cu.FijarRanura("shift-1", { t = "spell", id = 527 })
  auras.party1 = { id = 42, tipo = "Magic" }
  Cu.ActualizarTodo(boton)
  check(boton.alfaTipo == "Magic", "no leyó el tipo del perjuicio")
  local lin, conUnidad, mostrado = {}, false, false
  local add, setu, show = GameTooltip.AddLine, GameTooltip.SetUnit, GameTooltip.Show
  GameTooltip.AddLine = function(self, t) lin[#lin + 1] = tostring(t) end
  GameTooltip.SetUnit = function() conUnidad = true end
  GameTooltip.Show = function() mostrado = true end
  local function pasar() lin, conUnidad, mostrado = {}, false, false FIRE(boton, "OnEnter") end
  combate = true
  pasar()
  check(mostrado and not conUnidad, "en combate no salió el cuadro corto, o salió el del juego (SetUnit)")
  check(hay(lin, "quítalo con"), "el cuadro corto no dice con qué clic se quita: " .. table.concat(lin, " | "))
  -- Si el juego oculta el tipo (mazmorras): tus clics para cada tipo.
  boton.alfaTipo, boton.alfaHay = nil, true
  pasar()
  check(mostrado and hay(lin, "Tiene un perjuicio que puedes quitar") and hay(lin, "Mayús"), "con el tipo oculto no dijo tus clics: " .. table.concat(lin, " | "))
  -- Apagado, nada.
  N.Set("curacion", "descripcionCombate", false)
  pasar()
  check(not mostrado, "con «Cuadro corto en combate» apagado salió el cuadro")
  N.Set("curacion", "descripcionCombate", true)
  -- Sin perjuicio, nada (no estorba).
  boton.alfaTipo, boton.alfaHay = nil, nil
  pasar()
  check(not mostrado, "sin nada que decir salió un cuadro vacío")
  combate = false
  GameTooltip.AddLine, GameTooltip.SetUnit, GameTooltip.Show = add, setu, show
  auras.party1 = nil
  Cu.ActualizarTodo(boton)
end)

---------------------------------------------------------------------------
-- 4. El maná, sin roles: quienes curaron
---------------------------------------------------------------------------
step("Maná sin roles: solo quienes curaron, y el título lo dice", function()
  local Mn = Cu.Mana
  CLASES.player = "WARRIOR"
  grupo = true
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  T(1)
  check(Mn.filas == 0, "sin roles y sin curas vistas salió el maná de alguien: " .. tostring(Mn.filas))
  -- La sacerdotisa cura: entra.
  FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast-1", 2054)
  check(Mn.filas == 1, "la sacerdotisa curó y no entró a la lista: " .. tostring(Mn.filas))
  local f = AlfaCuracionMana
  check(f and texto(f.titulo):find("quienes curaron", 1, true), "el título no dice que son quienes curaron: " .. texto(f and f.titulo))
  -- La druida lanza Bola de Fuego (no es cura) y una placa de nombre cura: nada cambia.
  FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "party2", "Cast-2", 133)
  FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "nameplate4", "Cast-3", 2054)
  check(Mn.filas == 1, "algo que no es una cura del grupo metió a alguien: " .. tostring(Mn.filas))
  -- Con lo secreto (en mazmorras) no se cuenta.
  FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "party2", "Cast-4", SECRETO)
  check(Mn.filas == 1, "una cura secreta contó")
  FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", "party2", "Cast-5", 5185)
  check(Mn.filas == 2, "la druida curó y no entró: " .. tostring(Mn.filas))
  -- Con roles, lo de siempre: el rol manda y el título es el de siempre.
  roles.party2 = "HEALER"
  FIRE_EVENT("PLAYER_ROLES_ASSIGNED")
  check(Mn.filas == 1 and not texto(f.titulo):find("quienes curaron", 1, true), "con roles no salió solo la curandera marcada con «Maná»: " .. tostring(Mn.filas) .. " / " .. texto(f.titulo))
  roles.party2 = nil
  FIRE_EVENT("PLAYER_ROLES_ASSIGNED")
end)

if entrandoReal then N.Entrando = entrandoReal else N.Entrando = nil end
print(string.format("PRUEBA: 1.3.3 personaje, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
