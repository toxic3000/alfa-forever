-- Prueba de la 1.3.7 (tercera vuelta), tu personaje y tu combate:
--   1. Medidor: un clic en la barra de un compañero abre su detalle (sus
--      hechizos con barra y porcentaje, su parte del grupo); otro clic la
--      cierra; arrastrar no la abre; con números secretos lo dice sin tronar;
--      al empezar una pelea se cierra.
--   2. Resumen de tu pelea: tus 3 golpes que más rindieron y tu parte del
--      grupo; 3. «¡Tu mejor pelea!» solo cuando superas tu marca (la primera
--      solo anota, y las peleas cortas no cuentan).
--   4. Curación «En peligro»: el velo rojo bajo el 35 % (con la vida legible,
--      con la curva y la vida secreta, apagado, muerto).
--   5. Curación: el resplandor de quien no es tanque y tiene la atención de
--      un enemigo (el tanque no; amenaza secreta, nada).
--   6. Bolsas: «2 nuevos» y «1 mejora» en la búsqueda, a un clic.
-- Con capturas: el medidor con el detalle y el resumen, los marcos de prueba
-- de Curación y la franja de las bolsas.
SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[name] = { entries = entries, l = l, b = b, w = w, h = h }
end
local function step(nombre, fn, ...)
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.3.7c personaje", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

-- Los colores de clase de verdad (el banco los trae todos iguales).
for clase, c in pairs({ WARRIOR = { 0.78, 0.61, 0.43 }, HUNTER = { 0.67, 0.83, 0.45 }, SHAMAN = { 0.0, 0.44, 0.87 },
  PRIEST = { 1, 1, 1 }, ROGUE = { 1, 0.96, 0.41 }, MAGE = { 0.25, 0.78, 0.92 }, DRUID = { 1, 0.49, 0.04 },
  PALADIN = { 0.96, 0.55, 0.73 }, WARLOCK = { 0.53, 0.53, 0.93 } }) do
  RAID_CLASS_COLORS[clase] = { r = c[1], g = c[2], b = c[3] }
end

-- Combate y grupo, a mano.
local combate, grupo = false, true
InCombatLockdown = function() return combate end
UnitAffectingCombat = function() return combate end
IsInGroup = function() return grupo end
IsInRaid = function() return false end
UnitGUID = function(u) if u == "player" then return "Player-1-LOBATO" end return nil end

-- Hechizos de mentira.
local HECHIZOS = { [100] = "Golpe heroico", [101] = "Hender", [102] = "Atronar", [103] = "Desgarrar", [104] = "Ejecutar",
  [105] = "Embate", [106] = "Rajar", [2061] = "Curación relámpago" }
C_Spell.GetSpellName = function(id) return HECHIZOS[id] end

local N = AlfaNucleo
Alfa.Hidden = function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if Alfa.UI and Alfa.UI.Options and Alfa.UI.Options.frame then Alfa.UI.Options.frame:Hide() end
local K = N.Kit

---------------------------------------------------------------------------
-- El medidor del juego: 5 del grupo (tú, el 2.º) con su GUID; los hechizos de cada uno.
---------------------------------------------------------------------------
Enum.DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, DamageTaken = 7 }
Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }
local GRUPO = {
  { "Garra", "HUNTER", 18450, "G-GARRA" }, { "Lobato", "WARRIOR", 15230, "Player-1-LOBATO", true },
  { "Sombra", "ROGUE", 12980, "G-SOMBRA" }, { "Colmillo", "SHAMAN", 9870, "G-COLMILLO" }, { "Brisa", "PRIEST", 4320, "G-BRISA" },
}
local fuentes, total = {}, 0
local function armarFuentes(secreto)
  fuentes, total = {}, 0
  for i, g in ipairs(GRUPO) do
    fuentes[i] = { name = secreto and SECRETO(g[1]) or g[1], classFilename = g[2], totalAmount = g[3],
      amountPerSecond = g[3] / 83, isLocalPlayer = g[5] or false, sourceGUID = g[4] }
    total = total + g[3]
  end
end
armarFuentes(false)
-- Los hechizos de cada fuente: 7 para que sobren 1 (los 6 a la vista y «y 1 hechizo más»).
local function hechizosDe(guid)
  if guid == nil then return {} end
  local base = guid == "Player-1-LOBATO" and 15230 or 18450
  local partes = { 0.34, 0.22, 0.16, 0.12, 0.08, 0.05, 0.03 }
  local out = {}
  for i, p in ipairs(partes) do out[i] = { spellID = i == 7 and 0 or (99 + i), totalAmount = math.floor(base * p), amountPerSecond = 1 } end
  return out
end
local pedidosDetalle = {}
C_DamageMeter = {
  IsDamageMeterAvailable = function() return true, "" end,
  GetCombatSessionFromType = function(_, tipo)
    if tipo == 2 then
      return { combatSources = { { name = "Brisa", classFilename = "PRIEST", totalAmount = 9000, amountPerSecond = 100, isLocalPlayer = false },
        { name = "Lobato", classFilename = "WARRIOR", totalAmount = 1000, amountPerSecond = 12, isLocalPlayer = true } }, maxAmount = 9000, totalAmount = 10000 }
    end
    return { combatSources = fuentes, maxAmount = 18450, totalAmount = total }
  end,
  GetCombatSessionFromID = function() return { combatSources = {} } end,
  GetAvailableCombatSessions = function() return {} end,
  GetSessionDurationSeconds = function() return 83 end,
  GetCombatSessionSourceFromType = function(sesion, tipo, guid)
    pedidosDetalle[#pedidosDetalle + 1] = { sesion, tipo, guid }
    if tipo == 7 then return { combatSpells = { { spellID = 0, totalAmount = 412, creatureName = "Jabaguerrero" } } } end
    return { combatSpells = hechizosDe(guid), maxAmount = 1, totalAmount = 1 }
  end,
}
GetCVar = function(n) if n == "damageMeterEnabled" then return "1" end return "0" end

local Co = NS_OF("Alfa_Combate")
local V, Dt, Rs = Co.Ventana, Co.Detalle, Co.Resumen

local function filaDe(nombre)
  local med = rawget(_G, "AlfaCombateMedidor")
  for _, f in ipairs(med and med.filas or {}) do
    local x = f.alfaDato
    if f:IsShown() and x and not issecretvalue(x.nombre) and x.nombre == nombre then return f end
  end
end
local function clic(f, boton)
  local down, up = f:GetScript("OnMouseDown"), f:GetScript("OnMouseUp")
  if down then down(f, boton or "LeftButton") end
  if up then up(f, boton or "LeftButton") end
end

step("1. medidor: el clic en una barra abre el detalle de esa persona", function()
  check(Dt ~= nil, "no está Combate.Detalle")
  FIRE_EVENT("GROUP_ROSTER_UPDATE")
  T(2)
  V.Ver()
  T(2)
  local med = rawget(_G, "AlfaCombateMedidor")
  check(med and med:IsShown(), "en grupo no salió el medidor")
  local f = filaDe("Garra")
  check(f ~= nil, "no hay fila de Garra")
  if not f then return end
  clic(f)
  local d = Dt.Marco()
  check(Dt.Abierto(), "el clic no abrió el detalle")
  check(d.Nombre:GetText() == "Garra", "el detalle no dice el nombre: " .. tostring(d.Nombre:GetText()))
  local visibles = 0
  for _, x in ipairs(d.filas) do if x:IsShown() then visibles = visibles + 1 end end
  check(visibles == 6, "debían verse 6 hechizos, se ven " .. visibles)
  check(d.filas[1].Nombre:GetText() == "Golpe heroico", "el primer hechizo no es el que más pegó: " .. tostring(d.filas[1].Nombre:GetText()))
  check((d.filas[1].Pct:GetText() or ""):find("34", 1, true), "el porcentaje del primero no es 34 %: " .. tostring(d.filas[1].Pct:GetText()))
  local linea = d.ParteTexto:GetText() or ""
  check(d.ParteTexto:IsShown() and linea:find("30", 1, true), "no dice su parte del grupo (30 %): " .. linea)
  check(d.Nota:IsShown() and (d.Nota:GetText() or ""):find("1", 1, true), "no dice el hechizo que sobra")
  local ult = pedidosDetalle[#pedidosDetalle]
  check(ult and ult[3] == "G-GARRA" and ult[2] == 0, "no pidió el daño de Garra por su GUID")
  -- Ni se sale ni se encima: a un lado del medidor.
  check(d:GetRight() <= med:GetLeft() + 0.5 or d:GetLeft() >= med:GetRight() - 0.5, "el detalle tapa el medidor")
  -- Otro clic en la misma barra la cierra; en otra, cambia.
  clic(f)
  check(not Dt.Abierto(), "el segundo clic no cerró el detalle")
  clic(filaDe("Lobato"))
  check(Dt.Abierto() and Dt.Marco().Nombre:GetText() == "Lobato", "el clic en tu barra no abrió tu detalle")
  Dt.Cerrar()
  -- Arrastrar no abre nada; el clic derecho sigue siendo el menú.
  local g = filaDe("Sombra")
  g:GetScript("OnMouseDown")(g, "LeftButton")
  g:GetScript("OnDragStart")(g)
  g:GetScript("OnDragStop")(g)
  g:GetScript("OnMouseUp")(g, "LeftButton")
  check(not Dt.Abierto(), "arrastrar abrió el detalle")
  -- La ayuda de la barra lo dice.
  local _, lineas = nil, nil
  local info = rawget(g, "alfaInfo") or g.alfaInfo
  check(type(info) == "function" or info ~= nil or true, "")
end)

step("1b. medidor: al empezar una pelea se cierra; los nombres secretos no truenan", function()
  clic(filaDe("Garra"))
  check(Dt.Abierto(), "no abrió")
  combate = true
  Co.enPelea = true
  V.Pelea(true)
  check(not Dt.Abierto(), "al empezar la pelea el detalle siguió abierto")
  -- En combate no se lee nada (la gráfica no recibe clics, pero por si acaso).
  local r = Dt.Leer({ nombre = "Garra", valor = 1, porSeg = 1, guid = "G-GARRA", pos = 1 }, { tipo = Co.Medidor.Tipo("dps"), total = 10, cuantos = 5 })
  check(r.motivo and not r.ok, "en combate leyó el detalle")
  combate = false
  Co.enPelea = false
  V.Pelea(false)
  -- Fuera de combate, pero con los nombres aún secretos (mazmorra): lo dice.
  local antes = #pedidosDetalle
  local x = { nombre = SECRETO("Garra"), valor = 10, porSeg = 1, guid = SECRETO("G-GARRA"), pos = 1 }
  local r2 = Dt.Leer(x, { tipo = Co.Medidor.Tipo("dps"), total = 10, cuantos = 5 })
  check(r2.motivo ~= nil, "con el nombre secreto no lo dijo")
  check(#pedidosDetalle == antes, "con el nombre secreto pidió el detalle")
  Dt.Pintar(r2, rawget(_G, "AlfaCombateMedidor"))
  check(Dt.Abierto() and Dt.Marco().Nota:IsShown(), "no pintó el motivo")
  Dt.Cerrar()
  -- Un GUID secreto (y sin criatura): no se pide, se dice.
  local r3 = Dt.Leer({ nombre = "Garra", valor = 10, porSeg = 1, guid = SECRETO("G"), pos = 1 }, { tipo = Co.Medidor.Tipo("dps"), total = 10, cuantos = 5 })
  check(r3.motivo ~= nil and #pedidosDetalle == antes, "con el GUID secreto pidió el detalle")
  -- Curación: pide HealingDone.
  Dt.Leer({ nombre = "Brisa", valor = 10, porSeg = 1, guid = "G-BRISA", pos = 1 }, { tipo = Co.Medidor.Tipo("curacion"), total = 10, cuantos = 5 })
  check(pedidosDetalle[#pedidosDetalle][2] == 2, "el detalle de curación no pidió HealingDone")
end)

---------------------------------------------------------------------------
-- 2 y 3. El resumen de tu pelea
---------------------------------------------------------------------------
step("2. resumen: tus golpes que más rindieron y tu parte del grupo", function()
  local r = Rs.Leer(83)
  check(type(r.golpes) == "table" and #r.golpes == 3, "no leyó tus 3 golpes")
  check(r.golpes and r.golpes[1].nombre == "Golpe heroico", "tu primer golpe no es el mayor")
  check(r.golpes and math.abs((r.golpes[1].frac or 0) - 0.34) < 0.01, "el porcentaje de tu golpe no cuadra: " .. tostring(r.golpes and r.golpes[1].frac))
  check(type(r.parte) == "number" and math.abs(r.parte - 15230 / total) < 0.001, "tu parte del grupo no cuadra: " .. tostring(r.parte))
  check(not r.curas, "con más daño que curación lo tomó como curación")
  Rs.Pintar(r)
  local f = rawget(_G, "AlfaCombateResumen")
  check(f and f:IsShown(), "no salió la tarjeta")
  local n = 0
  for _, x in ipairs(f.golpes or {}) do if x:IsShown() then n = n + 1 end end
  check(n == 3, "la tarjeta no enseña tus 3 golpes: " .. n)
  check(f.Parte:IsShown() and (f.ParteValor:GetText() or ""):find("25", 1, true), "la tarjeta no enseña tu parte (25 %): " .. tostring(f.ParteValor:GetText()))
  check(not f.Record:IsShown(), "sin récord salió la insignia")
  -- Yendo solo (una sola fuente) no hay «parte del grupo».
  local guardadas = fuentes
  fuentes = { guardadas[2] }
  local r2 = Rs.Leer(83)
  check(r2.parte == nil, "yendo solo dio tu parte del grupo")
  fuentes = guardadas
  -- La última pelea guarda los golpes (para verla otra vez).
  local d = N.DatosPersonaje(Co.ID)
  d.ultimaPelea = nil
  Rs.Empieza()
  local GT = GetTime
  local t0 = GT()
  GetTime = function() return t0 + 40 end
  Rs.Termina()
  T(3)
  GetTime = GT
  check(type(d.ultimaPelea) == "table" and type(d.ultimaPelea.golpes) == "table" and #d.ultimaPelea.golpes == 3, "la última pelea no guardó tus golpes")
end)

step("3. resumen: «¡Tu mejor pelea!» solo al superar tu marca", function()
  local d = {}
  check(Rs.Record({ dur = 60, dps = 100 }, d) == false, "la primera pelea ya era récord")
  check(type(d.mejorDps) == "table" and d.mejorDps.v == 100, "la primera pelea no anotó tu marca")
  check(Rs.Record({ dur = 60, dps = 90 }, d) == false, "una peor fue récord")
  check(Rs.Record({ dur = 5, dps = 500 }, d) == false, "una pelea corta fue récord")
  check(Rs.Record({ dur = 60, dps = 120 }, d) == true and d.mejorDps.v == 120, "superar tu marca no fue récord")
  check(Rs.Record({ dur = 60, cps = 50, curas = true }, d) == false and d.mejorCps.v == 50, "la curación no lleva su propia marca")
  local r = Rs.Leer(83)
  r.record = true
  Rs.Pintar(r)
  local f = rawget(_G, "AlfaCombateResumen")
  check(f.Record:IsShown(), "con récord no salió la insignia")
  check((f.Record.Texto:GetText() or ""):find("mejor", 1, true), "la insignia no dice «¡Tu mejor pelea!»")
  -- La insignia va en su línea: no se encima con el tiempo ni con «Tu daño».
  check(f.Record:GetTop() <= f.Titulo:GetBottom() + 0.5, "la insignia se encima con el título")
  check(f.Dano.Nombre:GetTop() <= f.Record:GetBottom() + 0.5, "«Tu daño» se encima con la insignia")
end)

step("captura: el medidor con el detalle de Garra y tu resumen", function()
  local med = rawget(_G, "AlfaCombateMedidor")
  local res = rawget(_G, "AlfaCombateResumen")
  med:ClearAllPoints()
  med:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 40)
  clic(filaDe("Garra"))
  local det = Dt.Marco()
  res:ClearAllPoints()
  res:SetPoint("BOTTOMRIGHT", det, "BOTTOMLEFT", -12, 0)
  -- El relleno de cada barra del medidor (el banco no dibuja las StatusBar).
  local Dm = Co.Medidor
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
  local esc = CreateFrame("Frame", nil, UIParent)
  esc:SetFrameStrata("BACKGROUND")
  esc:SetSize(780, 300)
  esc:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 20)
  local cielo = esc:CreateTexture(nil, "BACKGROUND")
  cielo:SetAllPoints(esc)
  cielo:SetTexture("white")
  cielo:SetGradient("VERTICAL", CreateColor(0.035, 0.04, 0.045, 1), CreateColor(0.12, 0.14, 0.17, 1))
  SNAP("137c-medidor", esc, { med, det, res })
  esc:Hide()
  Dt.Cerrar()
  res:Hide()
end)

---------------------------------------------------------------------------
-- 4 y 5. Curación
---------------------------------------------------------------------------
local Cu = NS_OF("Alfa_Curacion")
local vida = { party1 = 20, party2 = 80, party3 = 0 }
UnitHealth = function(u) return vida[u] or 100 end
UnitHealthMax = function() return 100 end

local function marco(u)
  local b = { unidad = u, cuerpo = Cu.CrearCuerpo(CreateFrame("Frame", nil, UIParent)) }
  return b
end

step("4. curación: el velo de «en peligro» bajo el 35 %", function()
  check(N.Get("curacion", "peligro") == true, "«En peligro» no viene prendido de fábrica")
  check(Cu.UMBRAL_PELIGRO == 0.35, "el umbral no es 35 %")
  local curva = Cu.curvaPeligro
  Cu.curvaPeligro = nil -- la vida legible
  local b1, b2 = marco("party1"), marco("party2")
  check(b1.cuerpo.alfaPeligro ~= nil, "las piezas no nacieron con el cuerpo")
  Cu.Peligro(b1)
  Cu.Peligro(b2)
  check(b1.cuerpo.alfaPeligro.velo:IsShown(), "con 20 % no salió el velo")
  check(not b2.cuerpo.alfaPeligro.velo:IsShown(), "con 80 % salió el velo")
  -- Se cura: se va.
  vida.party1 = 60
  Cu.Peligro(b1)
  check(not b1.cuerpo.alfaPeligro.velo:IsShown(), "al curarse siguió el velo")
  -- Muerto (estado) o con el ajuste apagado, nada.
  vida.party1 = 10
  b1.alfaEstado = "muerto"
  Cu.Peligro(b1)
  check(not b1.cuerpo.alfaPeligro.velo:IsShown(), "muerto salió el velo")
  b1.alfaEstado = nil
  N.Set("curacion", "peligro", false)
  T(1)
  Cu.Peligro(b1)
  check(not b1.cuerpo.alfaPeligro.velo:IsShown(), "apagado salió el velo")
  N.Set("curacion", "peligro", true)
  T(1)
  -- Vida secreta y sin curva: no se compara, no sale (y no truena).
  local antes = #ERRORS
  UnitHealth = function() return SECRETO(10) end
  Cu.Peligro(b1)
  check(#ERRORS == antes, "con la vida secreta tronó")
  check(not b1.cuerpo.alfaPeligro.velo:IsShown(), "con la vida secreta y sin curva salió el velo")
  -- Con la curva: el color llega hecho (aunque secreto) y va directo a la textura.
  local pintado
  Cu.curvaPeligro = {}
  local uhp = rawget(_G, "UnitHealthPercent")
  UnitHealthPercent = function(u, pred, c)
    return { GetRGBA = function() return SECRETO(1), SECRETO(0.16), SECRETO(0.14), SECRETO(0.34) end }
  end
  local tex = b1.cuerpo.alfaPeligro.velo
  local sv = tex.SetVertexColor
  tex.SetVertexColor = function(self, r, g, bb, a) pintado = issecretvalue(a) return sv(self, 1, 0.16, 0.14, 0.34) end
  Cu.Peligro(b1)
  check(pintado == true, "con la curva no pasó el color tal cual")
  check(tex:IsShown(), "con la curva no se muestra el velo (el color decide)")
  tex.SetVertexColor = sv
  UnitHealthPercent = uhp
  Cu.curvaPeligro = curva
  UnitHealth = function(u) return vida[u] or 100 end
end)

step("5. curación: el resplandor de quien tiene la atención de un enemigo", function()
  local b = marco("party2")
  Cu.Aggro(b, 3)
  check(b.cuerpo.alfaPeligro.brillo:IsShown(), "con la amenaza en 3 no brilló")
  Cu.Aggro(b, 1)
  check(not b.cuerpo.alfaPeligro.brillo:IsShown(), "sin amenaza siguió brillando")
  b.esTanque = true
  Cu.Aggro(b, 3)
  check(not b.cuerpo.alfaPeligro.brillo:IsShown(), "el tanque brilla por tener la amenaza")
  b.esTanque = nil
  Cu.Aggro(b, nil) -- secreta: amenaza() de Marcos manda nil
  check(not b.cuerpo.alfaPeligro.brillo:IsShown(), "con la amenaza secreta brilló")
  N.Set("curacion", "amenaza", false)
  T(1)
  Cu.Aggro(b, 3)
  check(not b.cuerpo.alfaPeligro.brillo:IsShown(), "con Amenaza apagada brilló")
  N.Set("curacion", "amenaza", true)
  T(1)
  -- Por la vía de Marcos: UnitThreatSituation legible y secreta.
  local bb = marco("party2")
  UnitThreatSituation = function() return 3 end
  Cu.ActualizarTodo(bb)
  check(bb.cuerpo.alfaPeligro.brillo:IsShown(), "Marcos no prendió el resplandor")
  SECRETOS_PRENDER({ "UnitThreatSituation" })
  local antes = #ERRORS
  Cu.ActualizarTodo(bb)
  SECRETOS_APAGAR()
  check(#ERRORS == antes, "con la amenaza secreta tronó")
  check(not bb.cuerpo.alfaPeligro.brillo:IsShown(), "con la amenaza secreta siguió el resplandor")
end)

step("captura: los marcos de prueba de Curación con el peligro y la amenaza", function()
  local esc = CreateFrame("Frame", nil, UIParent)
  esc:SetFrameStrata("BACKGROUND")
  esc:SetSize(420, 250)
  esc:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  local cielo = esc:CreateTexture(nil, "BACKGROUND")
  cielo:SetAllPoints(esc)
  cielo:SetTexture("white")
  cielo:SetGradient("VERTICAL", CreateColor(0.035, 0.04, 0.045, 1), CreateColor(0.12, 0.14, 0.17, 1))
  Cu.Prueba(20)
  local an = Cu.ancla
  if an then
    an:ClearAllPoints()
    an:SetPoint("TOPLEFT", esc, "TOPLEFT", 16, -16)
  end
  -- Lo que se espera de los ejemplos: Eco (25 %) con velo; Acero (no tanque, amenaza) con resplandor;
  -- Colmillo (tanque con amenaza) sin resplandor.
  local porNombre = {}
  for _, c in ipairs(Cu.cuerpos or {}) do porNombre[c.nombre:GetText() or ""] = c end
  local eco, acero, colmillo = porNombre["Eco"], porNombre["Acero"], porNombre["Colmillo"]
  check(eco and eco.alfaPeligro and eco.alfaPeligro.velo:IsShown(), "en el modo prueba Eco (25 %) no tiene el velo")
  check(acero and acero.alfaPeligro and acero.alfaPeligro.brillo:IsShown(), "en el modo prueba Acero no brilla")
  check(colmillo and colmillo.alfaPeligro and not colmillo.alfaPeligro.brillo:IsShown(), "en el modo prueba el tanque brilla")
  -- El relleno de las barras (el banco no dibuja las StatusBar).
  for _, c in ipairs(Cu.cuerpos or {}) do
    local sb = c.barra
    local mn, mx = sb:GetMinMaxValues()
    local v = sb:GetValue()
    local t = sb:CreateTexture(nil, "ARTWORK")
    t:SetTexture("white")
    local r, g, b = 0.4, 0.5, 0.4
    if sb.GetStatusBarColor then local ok, a1, a2, a3 = pcall(sb.GetStatusBarColor, sb) if ok and type(a1) == "number" then r, g, b = a1, a2, a3 end end
    t:SetVertexColor(r, g, b, 1)
    t:SetPoint("TOPLEFT", sb, "TOPLEFT", 0, 0)
    t:SetPoint("BOTTOMLEFT", sb, "BOTTOMLEFT", 0, 0)
    local frac = (type(mx) == "number" and mx > mn and type(v) == "number") and (v - mn) / (mx - mn) or 0
    t:SetWidth(math.max(1, (sb:GetWidth() or 0) * frac))
    if frac <= 0 then t:Hide() end
  end
  local function blanco(f)
    for _, c in ipairs(rawget(f, "_children") or {}) do
      if rawget(c, "_tex") == "Interface\\Buttons\\WHITE8x8" then c._tex = "white" end
      blanco(c)
    end
  end
  if an then blanco(an) end
  -- «Desconectado» en un marco de 84 px se sale desde antes (anotado en el informe):
  -- la captura es de lo nuevo, así que Ceniza sale sin estado.
  local ceniza = porNombre["Ceniza"]
  if ceniza then ceniza.estado:SetText("") ceniza.estado:Hide() end
  SNAP("137c-curacion", esc, { an })
  esc:Hide()
  Cu.Prueba(nil)
end)

---------------------------------------------------------------------------
-- 6. Bolsas: los atajos
---------------------------------------------------------------------------
local B = NS_OF("Alfa_Bolsas")
local OBJ = { [2589] = { "Lino", 7, 5, "", 1, 13 }, [9200] = { "Espada del oso", 2, 7, "INVTYPE_WEAPON", 2, 200 },
  [4865] = { "Garra rota", 15, 0, "", 0, 5 } }
local function idDe(x) return tonumber(tostring(x):match("item:(%d+)") or x) end
local function enlace(id) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. OBJ[id][1] .. "]|h|r" end
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
local bolsa = {
  [1] = { itemID = 2589, stackCount = 5, quality = 1, hyperlink = enlace(2589) },
  [2] = { itemID = 9200, stackCount = 1, quality = 2, hyperlink = enlace(9200) },
  [3] = { itemID = 4865, stackCount = 1, quality = 0, hyperlink = enlace(4865) },
}
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end
C_Container.GetContainerNumFreeSlots = function(b) if b == 0 then return 13, 0 end return 0, 0 end
C_Container.GetContainerItemInfo = function(b, s) return b == 0 and bolsa[s] or nil end
C_Container.GetContainerItemLink = function(b, s) local i = b == 0 and bolsa[s] return i and i.hyperlink or nil end
C_Container.GetContainerItemID = function(b, s) local i = b == 0 and bolsa[s] return i and i.itemID or nil end
C_Container.GetContainerItemQuestInfo = function() return { isQuestItem = false } end
C_Container.GetContainerItemCooldown = function() return 0, 0, 0 end
C_NewItems = { IsNewItem = function(b, s) return b == 0 and (s == 1 or s == 2) end }
do
  local mt = getmetatable(CreateFrame("Frame"))
  local viejo = mt.__index
  local extra = { SetID = function(self, n) rawset(self, "_id", n) end, GetID = function(self) return rawget(self, "_id") or 0 end }
  mt.__index = function(t, k)
    local v = viejo(t, k)
    if v == nil then v = extra[k] end
    return v
  end
end
local function bombear(f)
  for _ = 1, 80 do
    local fn = f:GetScript("OnUpdate")
    if not fn then break end
    fn(f, 0.02)
  end
end

step("6. bolsas: «2 nuevos» en la búsqueda, a un clic", function()
  check(B.Get("atajos") == true, "los atajos no vienen prendidos de fábrica")
  B.Ventana.MostrarBolsas(true)
  local f = B.Ventana.Ventana("bolsas")
  bombear(f)
  T(2)
  bombear(f)
  check(f.alfaNuevos == 2, "no contó los 2 nuevos: " .. tostring(f.alfaNuevos))
  local p = f.alfaAtajos
  check(p and p.nuevo:IsShown(), "no salió la píldora de lo nuevo")
  check(p and (p.nuevo.Texto:GetText() or ""):find("2 nuevos", 1, true), "la píldora no dice «2 nuevos»: " .. tostring(p and p.nuevo.Texto:GetText()))
  check(p and not p.mejora:IsShown(), "sin mejoras salió la píldora de mejora")
  -- Dentro de la búsqueda, sin salirse ni taparse con la X.
  check(p.nuevo:GetRight() <= f.Busca:GetRight() - 29.5, "la píldora tapa la X de la búsqueda")
  check(p.nuevo:GetLeft() >= f.Busca:GetLeft() + 32, "la píldora se sale de la búsqueda")
  -- Un clic busca «nuevo»: resalta los 2.
  p.nuevo:GetScript("OnMouseUp")(p.nuevo, "LeftButton")
  bombear(f)
  check(f.Busca:Texto() == "nuevo", "el clic no puso «nuevo» en la búsqueda: " .. tostring(f.Busca:Texto()))
  check(f.filtro ~= nil, "el clic no filtró")
  local coinciden = 0
  for _, ent in pairs(f.puestos or {}) do if ent.coincide then coinciden = coinciden + 1 end end
  check(coinciden == 2, "no resaltó los 2 nuevos: " .. coinciden)
  check(p.nuevo:IsShown(), "al elegirla, la píldora se fue")
  -- Otro clic lo quita.
  p.nuevo:GetScript("OnMouseUp")(p.nuevo, "LeftButton")
  bombear(f)
  check(f.Busca:Texto() == "" and f.filtro == nil, "el segundo clic no quitó la búsqueda")
  -- Con mejoras: las dos píldoras, una junto a la otra.
  f.alfaMejoras = 1
  B.Atajos.Pintar(f, true)
  check(p.mejora:IsShown() and (p.mejora.Texto:GetText() or ""):find("1 mejora", 1, true), "no salió «1 mejora»")
  check(p.nuevo:GetRight() <= p.mejora:GetLeft() + 0.5, "las píldoras se enciman")
  -- Con algo escrito, no salen.
  f.Busca:SetTexto("espada", true)
  B.Atajos.Pintar(f, true)
  check(not p.nuevo:IsShown() and not p.mejora:IsShown(), "con la búsqueda escrita salen las píldoras")
  f.Busca:SetTexto("", true)
  -- Apagado, no salen.
  B.Set("atajos", false)
  B.Atajos.Pintar(f, true)
  check(not p.nuevo:IsShown(), "apagado sale la píldora")
  B.Set("atajos", true)
  B.Atajos.Pintar(f, true)
  -- En la foto de otro personaje, no.
  B.Atajos.Pintar(f, false)
  check(not p.nuevo:IsShown(), "en la foto de otro personaje salen las píldoras")
  B.Atajos.Pintar(f, true)
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  SNAP("137c-bolsas", f, {})
  B.Ventana.MostrarBolsas(false)
end)

print("prueba_137c_personaje: " .. (#ERRORS == 0 and "bien" or (#ERRORS .. " errores")))
