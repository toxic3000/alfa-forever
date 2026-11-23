-- Cacería de bugs de la 1.3.7, tercera ronda. tools/prueba.py corre esta
-- escena una vez por caso (tools/casos137c.py): cada caso entra al juego en
-- otra situación que nadie había probado junta con las demás:
--   /reload en mazmorra, en combate, en grifo, muerto (fantasma), en banda
--   de 40; el juego en alemán o en chino; la interfaz escalada; Sencillo y
--   Completo; cada módulo apagado en la lista de addons (y solo el núcleo);
--   una cuenta vieja de la 1.2.x (y, con respaldos/, las cuentas reales).
-- Lo de antes de cargar (idioma, dónde está, módulo apagado) lo pone
-- tools/banco/casos_137c.lua. Aquí: entrar, jugar un rato con los secretos
-- simulados, abrir cada página y los comandos, salir del combate, aterrizar,
-- revivir. Falla con cualquier error de Lua, con un marco seguro tocado en
-- combate, con relojes que se multiplican y con datos guardados que crecen
-- sin tope (estos dos, en el primer caso). Corrida suelta (escena.py), usa
-- todos los casos igual.
SNAPSHOTS = {}
local C = rawget(_G, "BANCO_CASO") or { nombre = "suelto", secretos = true }
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: [" .. tostring(C.nombre) .. "] " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 900)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.3.7c bugs", msg) end end
local function pinta(n) for _ = 1, n or 3 do RUN_TIMERS(3) end end

local A, N = Alfa, AlfaNucleo
local SECRETAS = { "UnitIsAFK", "UnitIsDND", "UnitOnTaxi", "UnitIsDeadOrGhost", "UnitIsDead", "UnitIsGhost",
  "UnitAffectingCombat", "UnitIsUnit", "UnitInRange", "UnitIsConnected", "UnitHealth", "UnitHealthMax",
  "UnitPower", "UnitPowerMax", "UnitName", "UnitIsGroupLeader", "UnitThreatSituation", "UnitDetailedThreatSituation",
  "UnitCastingInfo", "UnitChannelInfo", "UnitIsTapDenied", "UnitClassification", "UnitGUID" }
-- Secretos solo donde el juego los da: en mazmorra, banda y combate.
local conSecretos = C.secretos and (C.mazmorra or C.banda or C.combate)
local function prender() if C.secretos then SECRETOS_PRENDER(SECRETAS) end end
local function apagar() SECRETOS_APAGAR() end

-- 1.3.7d: con la cuenta real, lo que trae guardado antes de entrar (para
-- revisar después que nada se perdió).
local guardadoAntes
if C.reinoVacio then
  guardadoAntes = { bolsas = {}, reinos = {}, recetas = {} }
  local db = rawget(_G, "AlfaNucleoDB")
  for k, r in pairs(db and db.bolsas and db.bolsas.personajes or {}) do
    guardadoAntes.bolsas[k] = { banco = type(r) == "table" and type(r.banco) == "table" and next(r.banco) ~= nil }
  end
  for k in pairs(db and db.comercio and db.comercio.reinos or {}) do guardadoAntes.reinos[k] = true end
  for k, f in pairs(db and db.comercio and db.comercio.recetas or {}) do
    local n = 0
    for _ in pairs(type(f) == "table" and type(f.r) == "table" and f.r or {}) do n = n + 1 end
    guardadoAntes.recetas[k] = n
  end
end

---------------------------------------------------------------------------
-- Entrar
---------------------------------------------------------------------------
if conSecretos then prender() end
step("entrar" .. (C.recarga and " con /reload" or ""), function()
  FIRE_EVENT("PLAYER_LOGIN")
  FIRE_EVENT("PLAYER_ENTERING_WORLD", not C.recarga, C.recarga and true or false)
  if C.combate then
    -- (PLAYER_REGEN_DISABLED llega justo antes del candado: ahí todavía se puede)
    FIRE_EVENT("PLAYER_REGEN_DISABLED")
    BANCO_CANDADO = true
  end
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  NOW = NOW + 4
  pinta(4)
  NOW = NOW + 30
  pinta(4)
end)
check(A.IsLoggedIn and A.IsLoggedIn(), "Alfa no terminó de entrar")

---------------------------------------------------------------------------
-- Jugar un rato
---------------------------------------------------------------------------
local function eventosDeJuego()
  FIRE_EVENT("PLAYER_TARGET_CHANGED")
  for _, u in ipairs({ "player", "target", "party1", "raid2" }) do
    FIRE_EVENT("UNIT_HEALTH", u)
    FIRE_EVENT("UNIT_MAXHEALTH", u)
    FIRE_EVENT("UNIT_POWER_UPDATE", u, "MANA")
    FIRE_EVENT("UNIT_AURA", u, { isFullUpdate = true })
    FIRE_EVENT("UNIT_SPELLCAST_START", u, "Cast-1", 133)
    FIRE_EVENT("UNIT_SPELLCAST_SUCCEEDED", u, "Cast-1", 133)
    FIRE_EVENT("UNIT_THREAT_LIST_UPDATE", u)
    FIRE_EVENT("UNIT_FLAGS", u)
  end
  FIRE_EVENT("NAME_PLATE_UNIT_ADDED", "nameplate1")
  FIRE_EVENT("UPDATE_MOUSEOVER_UNIT")
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  FIRE_EVENT("QUEST_LOG_UPDATE")
  FIRE_EVENT("PLAYER_XP_UPDATE", "player")
  FIRE_EVENT("PLAYER_MONEY")
  FIRE_EVENT("CHAT_MSG_LOOT", "Recibes botín: [Piel ligera].", "Lobato")
  FIRE_EVENT("CHAT_MSG_SYSTEM", "Has descubierto: Valle de los Retos.")
  FIRE_EVENT("CHAT_MSG_PARTY", "hola", "Lobo2-Forever")
  FIRE_EVENT("CHAT_MSG_WHISPER", "hola", "Lobo3-Forever")
  FIRE_EVENT("UI_ERROR_MESSAGE", 50, "No puedes hacer eso todavía.")
  FIRE_EVENT("ZONE_CHANGED")
  FIRE_EVENT("ZONE_CHANGED_INDOORS")
  FIRE_EVENT("UPDATE_INVENTORY_DURABILITY")
end

step("jugar al entrar" .. (conSecretos and " (con secretos)" or ""), function()
  eventosDeJuego()
  if C.combate then
    FIRE_EVENT("ENCOUNTER_START", 1, "Jefe", 1, 5)
  end
  NOW = NOW + 5
  pinta()
end)

local PAGINAS = { "questing" }
for _, m in ipairs(N.modulos or {}) do PAGINAS[#PAGINAS + 1] = m.id end

local function abrirPaginas(donde)
  for _, id in ipairs(PAGINAS) do
    local antes = #ERRORS
    A.Fire("SHOW_OPTIONS", id)
    pinta(1)
    if #ERRORS > antes then print("  (al abrir " .. id .. " " .. donde .. ")") end
  end
  local o = A.UI and A.UI.Options and A.UI.Options.frame
  if o then o:Hide() end
  pinta(1)
end

-- Los comandos que no cambian nada para siempre.
local COMANDOS = { "", "help", "ayuda", "perdi", "calma", "calma", "rendimiento", "sesion", "listo", "cerca",
  "avisos", "teclas", "mapa", "camino", "lobito", "lya", "rutas", "bolsas", "mazmorras", "combate", "curacion",
  "pesca", "manada", "comodidades", "enciclopedia", "builds", "talentos", "recoleccion", "diagnostico", "" }
local function comandos(donde)
  local run = SlashCmdList and SlashCmdList.ALFA
  if type(run) ~= "function" then return end
  for _, c in ipairs(COMANDOS) do
    local antes = #ERRORS
    local ok, e = pcall(run, c)
    if not ok then NOTE("/alfa " .. c, e) end
    pinta(1)
    if #ERRORS > antes then print("  (con /alfa " .. c .. " " .. donde .. ")") end
  end
  local o = A.UI and A.UI.Options and A.UI.Options.frame
  if o then o:Hide() end
end

if C.combate then
  step("abrir cada página en combate", function() abrirPaginas("en combate") end)
  step("los comandos en combate", function() comandos("en combate") end)
  step("salir del combate", function()
    BANCO_COMBATE = false
    FIRE_EVENT("ENCOUNTER_END", 1, "Jefe", 1, 5, 1)
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    NOW = NOW + 5
    pinta(4)
  end)
end
if conSecretos then apagar() end

if C.grifo then
  step("aterrizar", function()
    FIRE_EVENT("PLAYER_CONTROL_LOST")
    pinta()
    BANCO_GRIFO = false
    FIRE_EVENT("PLAYER_CONTROL_GAINED")
    FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
    NOW = NOW + 5
    pinta(4)
  end)
end
if C.fantasma then
  step("revivir", function()
    FIRE_EVENT("PLAYER_DEAD")
    pinta()
    BANCO_FANTASMA = false
    FIRE_EVENT("PLAYER_ALIVE")
    FIRE_EVENT("PLAYER_UNGHOST")
    NOW = NOW + 5
    pinta(4)
  end)
end

step("abrir cada página", function() abrirPaginas("") end)
step("los comandos", function() comandos("") end)
if C.secretos then
  step("abrir cada página con secretos", function()
    prender()
    abrirPaginas("con secretos")
    apagar()
  end)
end

step("morir y revivir, salir de la mazmorra, subir de nivel", function()
  FIRE_EVENT("PLAYER_DEAD")
  pinta(1)
  FIRE_EVENT("PLAYER_ALIVE")
  FIRE_EVENT("PLAYER_UNGHOST")
  IsInInstance = function() return false, "none" end
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  FIRE_EVENT("PLAYER_LEVEL_UP", 24, 10, 0, 0, 1, 0, 0, 0, 0)
  NOW = NOW + 20
  pinta(4)
end)

---------------------------------------------------------------------------
-- Fugas: relojes que se multiplican y datos guardados sin tope
---------------------------------------------------------------------------
local function tareas()
  local n, claves = 0, {}
  for k in pairs(N.Reloj and N.Reloj.lista or {}) do n = n + 1 claves[k] = true end
  return n, claves
end
local GUARDADAS = { "AlfaDB", "AlfaCharDB", "AlfaNucleoDB", "AlfaNucleoCharDB" }
local function contar()
  local out, visto = {}, {}
  local function bajar(t, ruta, nivel)
    if visto[t] then return end
    visto[t] = true
    local n = 0
    for k, v in pairs(t) do
      n = n + 1
      if type(v) == "table" and nivel < 5 then
        bajar(v, ruta .. "." .. ((type(k) == "string" or type(k) == "number") and (type(k) == "number" and "#" or k) or "?"), nivel + 1)
      end
    end
    out[ruta] = (out[ruta] or 0) + n
  end
  for _, g in ipairs(GUARDADAS) do
    local t = rawget(_G, g)
    if type(t) == "table" then bajar(t, g, 1) end
  end
  return out
end
-- Una vuelta de juego: entrar a una mazmorra y salir, pelear, cambiar de
-- grupo, recoger, hablar, subir de nivel, un día que pasa.
local vuelta = 0
local function unaVuelta()
  vuelta = vuelta + 1
  local ii = IsInInstance
  IsInInstance = function() return true, "party" end
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  eventosDeJuego()
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  FIRE_EVENT("CHAT_MSG_LOOT", "Recibes botín: [Piel ligera " .. vuelta .. "].", "Lobato")
  FIRE_EVENT("CHAT_MSG_SYSTEM", "Lobo" .. vuelta .. " se une al grupo.")
  FIRE_EVENT("PLAYER_DEAD")
  FIRE_EVENT("PLAYER_ALIVE")
  IsInInstance = ii
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  FIRE_EVENT("QUEST_TURNED_IN", 800 + vuelta, 100, 0)
  FIRE_EVENT("PLAYER_LEVEL_UP", 24, 10, 0, 0, 1, 0, 0, 0, 0)
  NOW = NOW + 3700
  pinta(2)
end

if C.reinoVacio then
  -- 1.3.7d: sin el reino del juego, Alfa solo lo supone (una sola coincidencia
  -- con tu nombre, clase y facción) y entonces no junta ni borra nada: el
  -- registro «Toxic-» y los «?» se quedan hasta que el juego vuelva a dar el
  -- reino. Lo que se revisa: nada de lo guardado se perdió y no nace otro.
  step("la cuenta real con el reino vacío no pierde nada", function()
    pinta(2)
    local db = AlfaNucleoDB or {}
    local raiz = db.bolsas and db.bolsas.personajes or {}
    for k, a in pairs(guardadoAntes.bolsas) do
      local r = raiz[k]
      check(type(r) == "table", "Bolsas perdió el registro " .. k)
      if a.banco then check(type(r) == "table" and type(r.banco) == "table" and next(r.banco) ~= nil, "Bolsas perdió el banco de " .. k) end
    end
    local nuevos = {}
    for k in pairs(raiz) do if not guardadoAntes.bolsas[k] then nuevos[#nuevos + 1] = k end end
    check(#nuevos <= 1, "Bolsas creó más de un registro nuevo: " .. table.concat(nuevos, " | "))
    for k in pairs(guardadoAntes.reinos) do
      check(db.comercio and db.comercio.reinos and db.comercio.reinos[k], "Comercio perdió los precios de " .. k)
    end
    for k, n in pairs(guardadoAntes.recetas) do
      local f = db.comercio and db.comercio.recetas and db.comercio.recetas[k]
      local m = 0
      for _ in pairs(type(f) == "table" and type(f.r) == "table" and f.r or {}) do m = m + 1 end
      check(m >= n, ("Comercio perdió recetas de %s: %d de %d"):format(k, m, n))
    end
    local reino, seguro = N.Reino()
    print("REINO: " .. tostring(reino) .. (seguro and " (seguro)" or " (supuesto)"))
    check(not seguro, "con el reino vacío y sin el registro propio, el reino salió «seguro»")
  end)
  step("la cuenta real con el reino vacío, al volver el reino, queda en un solo registro por personaje", function()
    local rn, rnn = GetRealmName, GetNormalizedRealmName
    local yo = UnitName("player")
    local real
    for _, r in pairs(AlfaNucleoDB.bolsas and AlfaNucleoDB.bolsas.personajes or {}) do
      if type(r) == "table" and r.nombre == yo and type(r.reino) == "string" and r.reino ~= "" then real = r.reino end
    end
    check(real ~= nil, "no hay un registro de " .. tostring(yo) .. " con su reino")
    GetRealmName = function() return real end
    GetNormalizedRealmName = function() return (real:gsub("[%s%-]", "")) end
    N.ReinoOlvidar()
    FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
    pcall(NS_OF("Alfa_Comercio").JuntarReinoSinNombre)
    GetRealmName, GetNormalizedRealmName = rn, rnn
    pinta(2)
    local raiz = AlfaNucleoDB and AlfaNucleoDB.bolsas and AlfaNucleoDB.bolsas.personajes or {}
    local ks = {}
    for k in pairs(raiz) do ks[#ks + 1] = k end
    table.sort(ks)
    print("BOLSAS: " .. table.concat(ks, " | "))
    local cs = {}
    for k in pairs(AlfaNucleoDB.comercio and AlfaNucleoDB.comercio.reinos or {}) do cs[#cs + 1] = k end
    for k in pairs(AlfaNucleoDB.comercio and AlfaNucleoDB.comercio.recetas or {}) do cs[#cs + 1] = "recetas " .. k end
    table.sort(cs)
    print("COMERCIO: " .. table.concat(cs, " | "))
    for _, k in ipairs(ks) do check(not k:find("%-$"), "Bolsas sigue con un registro sin reino: " .. k) end
    for _, k in ipairs(cs) do check(not k:find("%?"), "Comercio sigue con un reino «?»: " .. k) end
  end)
end

-- Curación: «Desconectado» salía cortado («Desconecta…») en el marco de 84;
-- ninguna palabra de estado se corta, alto o bajo, en el idioma de cada caso.
do
  local Cu = NS_OF("Alfa_Curacion")
  local Mc = Cu and Cu.Marcos or Cu
  if Mc and Mc.CrearCuerpo and Mc.AjustarCuerpo and Mc.PonerEstado then
    step("las palabras de estado de Curación caben en su marco", function()
      local padre = CreateFrame("Frame", nil, UIParent)
      for _, tam in ipairs({ { 84, 32 }, { 84, 24 }, { 72, 32 }, { 100, 20 } }) do
        padre:SetSize(tam[1], tam[2])
        local c = Mc.CrearCuerpo(padre)
        Mc.AjustarCuerpo(c, tam[1], tam[2])
        for _, clave in ipairs({ "Desconectado", "Fantasma", "Muerto" }) do
          c.estado:Show()
          local t = Mc.PonerEstado(c, clave)
          local w = c.bajo and math.floor(tam[1] * 0.65) or c.estado:GetWidth()
          local mide = c.estado:GetUnboundedStringWidth()
          check(mide <= w, ("«%s» no cabe en un marco de %dx%d (%s): %.0f de %.0f"):format(tostring(t), tam[1], tam[2],
            tostring(BANCO_CASO and BANCO_CASO.idioma or "esMX"), mide, w))
        end
      end
    end)
  end
end

-- Avisos (la campanita): ninguna pastilla de los filtros se corta («Mun…»)
-- ni se sale de la ventana, en el idioma de cada caso.
if N.VerAvisos and N.Perdido then
  step("los filtros de Avisos caben enteros", function()
    local K = N.Kit
    for i, ic in ipairs({ "ic-bolsas", "ic-mundo", "ic-raros", "ic-ruta", "ic-comercio", "ic-hoy", "ic-manada", "ic-lya", "ic-pesca", "ic-combate" }) do
      for j = 1, i do N.Perdido({ titulo = "Aviso " .. i .. "-" .. j, texto = "de prueba", icono = ic }) end
    end
    local v = N.VerAvisos()
    pinta(2)
    local seg
    local function buscar(f, prof)
      if prof > 7 or seg then return end
      for _, c in ipairs({ f:GetChildren() }) do
        if c.SetOpciones and c.opciones then seg = c return end
        buscar(c, prof + 1)
      end
    end
    if v then buscar(v, 0) end
    check(seg ~= nil, "no están los filtros de Avisos")
    local derecha = v and v.Cuerpo and v.Cuerpo:GetRight() or (v and v:GetRight())
    for _, b in ipairs(seg and seg.botones or {}) do
      if b:IsShown() then
        local t = b.Texto:GetText() or ""
        local mide = b.Texto:GetUnboundedStringWidth()
        check(mide <= b.Texto:GetWidth() + 0.5, ("la pastilla «%s» se corta: %.0f de %.0f"):format(t, mide, b.Texto:GetWidth()))
        check(b.Texto:GetRight() <= b:GetRight() + 0.5 and (b.Cuenta:GetText() or "") == "" or b.Cuenta:GetRight() <= b:GetRight() + 0.5,
          ("el número de «%s» se sale de su pastilla"):format(t))
        if derecha then check(b:GetRight() <= derecha + 0.5, ("la pastilla «%s» se sale de la ventana"):format(t)) end
      end
    end
    N.OlvidarAvisos()
    if v then v:Hide() end
  end)
end

-- Forever da GetRealmName() vacío desde el 20/11/2026 (los WTF de Toxic:
-- «Toxic-» en Bolsas y «?-Alliance» en Comercio, el mismo personaje dos veces).
if C.vieja or C.nombre == "suelto" then
  step("el reino vacío no parte tus datos en dos", function()
    local rn, rnn = GetRealmName, GetNormalizedRealmName
    check(N.Reino() == "Forever", "N.Reino con el juego dando el reino: " .. tostring(N.Reino()))
    GetRealmName = function() return "" end
    GetNormalizedRealmName = function() return nil end
    check(N.Reino() == "Forever" and N.Reino(true) == "Forever", "N.Reino no recordó el reino: " .. tostring(N.Reino()))
    -- Bolsas: el registro «Lobato-» vuelve a «Lobato-Forever».
    local B = NS_OF("Alfa_Bolsas")
    local D = B and B.Datos
    if D and D.JuntarSinReino then
      local lista = D.Raiz().personajes
      local buena = D.Clave()
      check(buena == "Lobato-Forever", "la clave de Bolsas con el reino vacío: " .. tostring(buena))
      local antes = lista[buena]
      lista["Lobato-"] = { nombre = "Lobato", reino = "", visto = 9e9, dinero = 777 }
      D.JuntarSinReino("Lobato", buena)
      check(lista["Lobato-"] == nil, "quedó el registro sin reino")
      check(type(lista[buena]) == "table" and lista[buena].dinero == 777 and lista[buena].reino ~= "", "no se juntó el más nuevo con su reino")
      lista[buena] = antes -- (lo de prueba no se queda para los casos que siguen)
    end
    -- Comercio: «?-Horde» y «Lobato-?» vuelven a «Forever-Horde» y «Lobato-Forever».
    local Co = NS_OF("Alfa_Comercio")
    if Co and Co.JuntarReinoSinNombre then
      local d = Co.Datos()
      d.reinos["?-Horde"] = { p = { [2589] = { 50, 9e9, 3, 1 } }, h = { [2589] = "20000:50" }, escaneo = { 9e9, 1, 1 } }
      d.recetas = d.recetas or {}
      local recetaAntes, reinoAntes = d.recetas["Lobato-Forever"], d.reinos["Forever-Horde"]
      d.recetas["Lobato-?"] = { rk = "?-Horde", nombre = "Lobato", r = {}, profs = {} }
      check(Co.ClaveReino() == "Forever-Horde", "la clave de Comercio con el reino vacío: " .. tostring(Co.ClaveReino()))
      Co.JuntarReinoSinNombre()
      check(d.reinos["?-Horde"] == nil and d.reinos["Forever-Horde"] and d.reinos["Forever-Horde"].p[2589], "los precios del reino «?» no se juntaron")
      check(d.recetas["Lobato-?"] == nil and d.recetas["Lobato-Forever"] and d.recetas["Lobato-Forever"].rk == "Forever-Horde", "las recetas de «Lobato-?» no se juntaron")
      d.recetas["Lobato-Forever"], d.reinos["Forever-Horde"] = recetaAntes, reinoAntes
    end
    GetRealmName, GetNormalizedRealmName = rn, rnn
  end)
end

if C.fugas or C.vieja or C.nombre == "suelto" then
  step("los relojes no se multiplican ni los datos guardados crecen sin tope", function()
    for _ = 1, 5 do unaVuelta() end
    local t5, claves5 = tareas()
    local c5 = contar()
    for _ = 1, 30 do unaVuelta() end
    local t30, claves30 = tareas()
    local c30 = contar()
    local nuevas = {}
    for k in pairs(claves30) do if not claves5[k] then nuevas[#nuevas + 1] = tostring(k) end end
    table.sort(nuevas)
    check(t30 - t5 <= 4, ("los relojes de Alfa pasaron de %d a %d en 30 vueltas: %s"):format(t5, t30, table.concat(nuevas, ", "):sub(1, 400)))
    local crecen = {}
    for ruta, n in pairs(c30) do
      local antes = c5[ruta] or 0
      -- 30 vueltas: algo que suma una por vuelta y no se poda crece ~30.
      if n - antes >= 25 then crecen[#crecen + 1] = ("%s %d -> %d"):format(ruta, antes, n) end
    end
    table.sort(crecen)
    for _, l in ipairs(crecen) do print("CRECE " .. l) end
    check(#crecen == 0, "datos guardados que crecen una vez por vuelta (¿sin tope?): " .. table.concat(crecen, "; "):sub(1, 600))
  end)
end

local seguros = 0
for _ in pairs(BANCO_SEGUROS or {}) do seguros = seguros + 1 end
print(("PRUEBA: 1.3.7c bugs [%s], %d pasos, %d errores, %d marcos seguros vigilados"):format(tostring(C.nombre), pasos, #ERRORS, seguros))
print("errors: " .. #ERRORS)
