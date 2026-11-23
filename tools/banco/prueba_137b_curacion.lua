-- Prueba de la 1.3.7 (segunda vuelta), Curación (tools/prueba.py la corre con las demás):
--   * «Curar y seleccionar» en TODO clic que cura: los 12 botones (izquierdo,
--     central y derecho, con o sin Mayús, Ctrl o Alt) son "/target u" y luego
--     "/cast [@u] Hechizo"; la venda igual con /use; una ranura sin hechizo al
--     menos selecciona; nada pasa de 255 letras; el fragmento seguro rehace las
--     12 con otra unidad; los botones son de acción (no los toma el clic para
--     lanzar de Blizzard) y lanzan al soltar (useOnKeyDown = false);
--   * apagado, el hechizo solo; nada se arma en combate; la migración por
--     personaje (quien lo tenía apagado lo vuelve a tener prendido);
--   * la barra de maná, furia o energía: aparece, cambia de color según el
--     tipo (UNIT_DISPLAYPOWER), sigue el valor (también secreto) y se apaga;
--   * el aspecto nuevo (fondo oscuro, vida apagada) y una captura de los marcos.
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
local function check(cond, msg) if not cond then NOTE("1.3.7b curacion", msg) end end
local function T(n) RUN_TIMERS(n or 2) end
local function cerca(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.01 end

---------------------------------------------------------------------------
-- Barras de estado que se ven (el banco no pinta su relleno): un relleno de
-- verdad, con su color, para probar el color y para la captura.
---------------------------------------------------------------------------
local FM
do
  local idx = getmetatable(CreateFrame("StatusBar")).__index
  for i = 1, 10 do
    local n, v = debug.getupvalue(idx, i)
    if n == "Frame" then FM = v break end
    if n == nil then break end
  end
end
local function relleno(self)
  local t = rawget(self, "_fill")
  if not t then
    t = self:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\Buttons\\WHITE8x8")
    rawset(self, "_fill", t)
  end
  return t
end
FM.SetStatusBarTexture = function(self) relleno(self) end
FM.SetStatusBarColor = function(self, r, g, b, a) relleno(self):SetVertexColor(r, g, b, a or 1) end
FM.GetStatusBarColor = function(self) return relleno(self):GetVertexColor() end
FM.GetStatusBarTexture = function(self) return relleno(self) end
-- Antes de la captura: el relleno llega hasta donde dice el valor.
local function rellenar(barras)
  for _, sb in ipairs(barras) do
    local t = relleno(sb)
    local mn, mx = sb:GetMinMaxValues()
    local v = sb:GetValue()
    if issecretvalue(v) then v = SECRETO_VALOR(v) end
    if issecretvalue(mx) then mx = SECRETO_VALOR(mx) end
    local frac = (type(mx) == "number" and mx > mn) and math.max(0, math.min(1, (v - mn) / (mx - mn))) or 0
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", sb, "TOPLEFT", 0, 0)
    t:SetPoint("BOTTOMLEFT", sb, "BOTTOMLEFT", 0, 0)
    local _, _, ancho = sb:GetRect()
    t:SetWidth(math.max(0.01, (ancho or 0) * frac))
    if frac <= 0 then t:Hide() else t:Show() end
  end
end

---------------------------------------------------------------------------
-- El juego simulado: un sacerdote en grupo
---------------------------------------------------------------------------
local LARGO = string.rep("a", 200)
local NOMBRES = {
  [2050] = "Sanar inferior", [2054] = "Sanar", [2060] = "Sanación superior", [2061] = "Curación relámpago",
  [139] = "Renovar", [17] = "Palabra de poder: escudo", [527] = "Disipar magia", [528] = "Curar enfermedad",
  [552] = "Suprimir enfermedad", [2006] = "Resurrección", [596] = "Rezo de sanación",
  [1243] = "Palabra de poder: entereza", [21562] = "Rezo de entereza", [14752] = "Espíritu divino",
  [77777] = LARGO,
}
local SABE = { [2050] = true, [2054] = true, [2061] = true, [139] = true, [17] = true, [527] = true, [528] = true,
  [2006] = true, [596] = true, [1243] = true, [77777] = true }
C_Spell.GetSpellName = function(id) return NOMBRES[id] end
C_SpellBook = C_SpellBook or {}
C_SpellBook.IsSpellKnown = function(id) return SABE[id] == true end

local CLASES = { player = "PRIEST", party1 = "WARRIOR", party2 = "DRUID", party3 = "MAGE", party4 = "ROGUE" }
local NOMBRE_U = { player = "Lobato", party1 = "Colmillo", party2 = "Luna", party3 = "Aullido", party4 = "Sombra" }
local vida = { player = 100, party1 = 70, party2 = 45, party3 = 90, party4 = 100 }
local poder = { player = 60, party1 = 20, party2 = 35, party3 = 80, party4 = 100 }
local tipoPoder = { player = { 0, "MANA" }, party1 = { 1, "RAGE" }, party2 = { 0, "MANA" }, party3 = { 0, "MANA" }, party4 = { 3, "ENERGY" } }
UnitClass = function(u) local c = CLASES[u] if c then return c, c, 1 end return nil end
UnitName = function(u) return NOMBRE_U[u], nil end
UnitExists = function(u) return CLASES[u] ~= nil end
UnitHealth = function(u) return vida[u] or 0 end
UnitHealthMax = function() return 100 end
UnitPower = function(u) return poder[u] or 0 end
UnitPowerMax = function() return 100 end
UnitPowerType = function(u) local t = tipoPoder[u] if t then return t[1], t[2] end return 0, "MANA" end
UnitIsUnit = function(a, b) return a == b end
UnitGroupRolesAssigned = function() return "NONE" end
IsInGroup = function() return true end
GetNumGroupMembers = function() return 5 end
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end
C_Container.GetContainerItemID = function(b, i) if b == 0 and i == 2 then return 6450 end return nil end
local combate = false
InCombatLockdown = function() return combate end
-- Los colores de clase de verdad (el banco los trae todos iguales).
for clase, c in pairs({ WARRIOR = { 0.78, 0.61, 0.43 }, HUNTER = { 0.67, 0.83, 0.45 }, SHAMAN = { 0.0, 0.44, 0.87 },
  PRIEST = { 1, 1, 1 }, ROGUE = { 1, 0.96, 0.41 }, MAGE = { 0.25, 0.78, 0.92 }, DRUID = { 1, 0.49, 0.04 },
  PALADIN = { 0.96, 0.55, 0.73 }, WARLOCK = { 0.53, 0.53, 0.93 } }) do
  RAID_CLASS_COLORS[clase] = { r = c[1], g = c[2], b = c[3] }
end

local N = AlfaNucleo
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
if Alfa.UI and Alfa.UI.Options and Alfa.UI.Options.frame then Alfa.UI.Options.frame:Hide() end

local Cu = NS_OF("Alfa_Curacion")

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

-- Un hechizo en cada una de las 12 ranuras.
local EN_RANURA = {
  ["1"] = 2061, ["3"] = 2054, ["2"] = 139, ["shift-1"] = 527, ["shift-3"] = 528, ["shift-2"] = 17,
  ["ctrl-1"] = 2050, ["ctrl-3"] = 596, ["ctrl-2"] = 1243, ["alt-1"] = 2006, ["alt-3"] = 2061, ["alt-2"] = 139,
}

local boton
step("De fábrica: seleccionar prendido, barra de recurso prendida, marcos compactos", function()
  check(Cu.CurarSelecciona() == true, "«Curar y seleccionar» no viene prendido")
  check(N.Get("curacion", "recurso") == true, "curacion.recurso no viene prendido")
  check(N.Get("curacion", "ancho") == 84 and N.Get("curacion", "alto") == 32, "los marcos no son 84 x 32 de fábrica")
  check(Cu.cabecera and Cu.cabecera:GetAttribute("template") == "SecureActionButtonTemplate", "la cabecera no arma botones de acción: " .. tostring(Cu.cabecera and Cu.cabecera:GetAttribute("template")))
  for g = 1, 8 do
    check(Cu.porGrupo[g]:GetAttribute("template") == "SecureActionButtonTemplate", "la cabecera del grupo " .. g .. " no arma botones de acción")
  end
end)

step("Todo clic que cura selecciona (12 ranuras)", function()
  Cu.AplicarPreajuste("curar", true)
  for r, id in pairs(EN_RANURA) do Cu.FijarRanura(r, { t = "spell", id = id }) end
  boton = CreateFrame("Button", "AlfaPrueba137bCuracion", UIParent, "SecureActionButtonTemplate")
  boton:SetSize(84, 32)
  boton:SetAttribute("unit", "party1")
  Cu.PrepararBoton(boton)
  T(2)
  local a = function(k) return boton:GetAttribute(k) end
  check(a("useOnKeyDown") == false, "el botón no lanza al soltar (useOnKeyDown)")
  for r, id in pairs(EN_RANURA) do
    local p, s = Cu.Partes(r)
    check(a(p .. "type" .. s) == "macro", r .. ": no es macro (" .. tostring(a(p .. "type" .. s)) .. ")")
    local esperado = "/target party1\n/cast [@party1] " .. NOMBRES[id]
    check(a(p .. "macrotext" .. s) == esperado, r .. ": macro " .. tostring(a(p .. "macrotext" .. s)))
    check(a(p .. "spell" .. s) == nil, r .. ": sobra el hechizo suelto")
    check(a("alfa-cmd-" .. p .. s) == "/cast" and a("alfa-arg-" .. p .. s) == NOMBRES[id], r .. ": faltan alfa-cmd/alfa-arg")
    -- /target primero, luego /cast sobre esa misma unidad
    local t = a(p .. "macrotext" .. s) or ""
    check(t:find("^/target party1\n/cast %[@party1%] ") ~= nil, r .. ": el orden no es /target y luego /cast [@unidad]")
  end
  local lista = a("alfa-objetivos") or ""
  local n = 0
  for _ in lista:gmatch("(%S-):(%d)") do n = n + 1 end
  check(n == 12, "alfa-objetivos no tiene las 12 ranuras: " .. lista)
end)

step("El fragmento seguro rehace las 12 con otra unidad", function()
  local attrs = {}
  for k, v in pairs(boton._attr) do attrs[k] = v end
  attrs.unit = "raid40"
  local r = correrRefresco(attrs)
  for ranura, id in pairs(EN_RANURA) do
    local p, s = Cu.Partes(ranura)
    check(r[p .. "macrotext" .. s] == Cu.Macro("raid40", "/cast", NOMBRES[id]), ranura .. ": el fragmento no rehízo la macro: " .. tostring(r[p .. "macrotext" .. s]))
    check(#r[p .. "macrotext" .. s] <= 255, ranura .. ": más de 255 letras")
  end
end)

step("Venda, ranura vacía, hechizo que no sabes, nombre larguísimo", function()
  Cu.FijarRanura("ctrl-3", { t = "venda" })
  Cu.FijarRanura("alt-3", { t = "nada" })
  Cu.FijarRanura("alt-2", { t = "spell", id = 99999 }) -- un hechizo sin nombre en tu cliente
  Cu.FijarRanura("shift-3", { t = "spell", id = 77777 }) -- 200 letras
  T(2)
  local a = function(k) return boton:GetAttribute(k) end
  check(a("ctrl-type3") == "macro" and a("ctrl-macrotext3") == "/target party1\n/use [@party1] item:6450", "la venda no cura y selecciona: " .. tostring(a("ctrl-macrotext3")))
  check(a("alt-type3") == "target", "la ranura vacía no selecciona: " .. tostring(a("alt-type3")))
  check(a("alt-type2") == "target", "un hechizo que no sabes no selecciona: " .. tostring(a("alt-type2")))
  local t = a("shift-macrotext3")
  check(a("shift-type3") == "macro" and type(t) == "string", "el nombre de 200 letras no es macro")
  local r = correrRefresco((function() local x = {} for k, v in pairs(boton._attr) do x[k] = v end x.unit = "raid40" return x end)())
  check(#(r["shift-macrotext3"] or "") <= 255, "con raid40 la macro pasa de 255 letras: " .. #(r["shift-macrotext3"] or ""))
  -- Sin venda en las bolsas: el clic de venda al menos selecciona.
  local antes = Cu.venda
  Cu.venda = nil
  Cu.AplicarMapa()
  T(2)
  check(a("ctrl-type3") == "target" and a("ctrl-macrotext3") == nil, "sin venda, el clic de venda no selecciona")
  Cu.venda = antes
  Cu.AplicarMapa()
  T(2)
  -- Seleccionar y menú siguen igual.
  Cu.FijarRanura("alt-1", { t = "target" })
  Cu.FijarRanura("2", { t = "menu" })
  T(2)
  check(a("alt-type1") == "target" and a("alt-macrotext1") == nil, "seleccionar con Alt no es «target»")
  check(a("type2") == "togglemenu", "el menú del derecho se perdió")
  Cu.FijarRanura("2", { t = "spell", id = 139 })
  T(2)
end)

step("Apagado: el hechizo solo; en combate nada se arma", function()
  Cu.FijarCurarSelecciona(false)
  T(2)
  local a = function(k) return boton:GetAttribute(k) end
  check(a("type1") == "spell" and a("spell1") == "Curación relámpago" and a("macrotext1") == nil, "apagado, el izquierdo no es el hechizo solo")
  check(a("shift-type2") == "spell" and a("shift-spell2") == "Palabra de poder: escudo", "apagado, Mayús + derecho no es el hechizo solo")
  check(a("ctrl-type3") == "item" and a("ctrl-item3") == "item:6450", "apagado, la venda no va sola")
  check(a("alt-type3") == nil, "apagado, la ranura vacía hace algo: " .. tostring(a("alt-type3")))
  check(a("alt-type1") == "target", "apagado, seleccionar dejó de seleccionar")
  combate = true
  local orig, cambios = boton.SetAttribute, 0
  boton.SetAttribute = function(self, k, v) cambios = cambios + 1 return orig(self, k, v) end
  local cab, cambiosCab = Cu.cabecera.SetAttribute, 0
  Cu.cabecera.SetAttribute = function(self, k, v) cambiosCab = cambiosCab + 1 return cab(self, k, v) end
  Cu.FijarCurarSelecciona(true)
  Cu.FijarRanura("3", { t = "spell", id = 2050 })
  T(2)
  check(cambios == 0 and cambiosCab == 0, "en combate se tocaron atributos: " .. cambios .. " del botón, " .. cambiosCab .. " de la cabecera")
  check(a("type1") == "spell", "en combate cambió el izquierdo")
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  T(2)
  boton.SetAttribute = nil
  Cu.cabecera.SetAttribute = nil
  check(a("type1") == "macro" and a("macrotext1") == "/target party1\n/cast [@party1] Curación relámpago", "al salir de combate no se armó «Curar y seleccionar»")
  check(a("macrotext3") == "/target party1\n/cast [@party1] Sanar inferior", "al salir de combate no se armó el central nuevo")
  local cab0 = Cu.cabecera:GetAttribute("_initialAttribute-macrotext1")
  check(cab0 == nil and Cu.cabecera:GetAttribute("_initialAttribute-type1") == "macro", "la cabecera no copia la macro a los botones nuevos")
  check(Cu.cabecera:GetAttribute("_initialAttribute-useOnKeyDown") == false, "la cabecera no copia useOnKeyDown")
end)

step("Migración: quien lo apagó a mano lo sigue teniendo apagado; quien nunca lo tocó, prendido", function()
  local d = Cu.Datos()
  d.curarSel, d.curarSelMig = false, nil
  check(Cu.CurarSelecciona() == false and d.curarSelMig == 1, "la migración prendió lo que apagaste a mano")
  d.curarSel, d.curarSelMig = nil, nil
  check(Cu.CurarSelecciona() == true and d.curarSelMig == 1, "a quien nunca lo tocó no le quedó prendido")
  Cu.FijarCurarSelecciona(false)
  check(Cu.CurarSelecciona() == false, "después de la migración, apagarlo no se respeta")
  Cu.FijarCurarSelecciona(true)
  T(2)
end)

step("Tus atajos de Blizzard: aviso y copiarlos al mapa de Alfa", function()
  local viejos = { C_ClickBindings = rawget(_G, "C_ClickBindings"), GetStringFromModifiers = rawget(_G, "GetStringFromModifiers") }
  local enumViejo = Enum.ClickBindingType, Enum.ClickBindingInteraction
  local iViejo = Enum.ClickBindingInteraction
  Enum.ClickBindingType = { None = 0, Spell = 1, Macro = 2, Interaction = 3, PetAction = 4 }
  Enum.ClickBindingInteraction = { Target = 1, OpenContextMenu = 2 }
  local MODS = { [1] = "SHIFT-", [2] = "CTRL-", [4] = "ALT-" }
  GetStringFromModifiers = function(b) return MODS[b] or "" end
  local perfil = {
    { type = 1, actionID = 2054, button = "MiddleButton", modifiers = 1 },  -- Mayús + central: Sanar
    { type = 2, actionID = 3, button = "LeftButton", modifiers = 2 },       -- Ctrl + izquierdo: una macro
    { type = 3, actionID = 1, button = "RightButton", modifiers = 4 },      -- Alt + derecho: seleccionar
  }
  C_ClickBindings = { GetProfileInfo = function() return perfil end }
  Cu.OlvidarBitsBlizzard()
  local mapa = Cu.Mapa()
  local antes = { mapa["shift-3"], mapa["ctrl-1"], mapa["alt-2"] }
  mapa["shift-3"], mapa["ctrl-1"], mapa["alt-2"] = { t = "nada" }, { t = "nada" }, { t = "nada" }
  check(Cu.ChoquesBlizzard() == 2, "no cuenta los dos atajos (hechizo y macro) que chocan: " .. tostring(Cu.ChoquesBlizzard()))
  local n, sin = Cu.CopiarBlizzard(true)
  check(n == 2 and sin == 1 and mapa["shift-3"].t == "nada", "probar no debe cambiar nada y contar 2 copiables y 1 sin copiar: " .. tostring(n) .. "/" .. tostring(sin))
  n = Cu.CopiarBlizzard()
  T(2)
  check(n == 2 and mapa["shift-3"].t == "spell" and mapa["shift-3"].id == 2054, "no copió Sanar a Mayús + central")
  check(mapa["alt-2"].t == "target", "no copió «seleccionar» a Alt + derecho")
  check(mapa["ctrl-1"].t == "nada", "una macro de Blizzard no se puede copiar y la cambió")
  check(Cu.ChoquesBlizzard() == 1, "después de copiar debe quedar solo la macro")
  mapa["shift-3"], mapa["ctrl-1"], mapa["alt-2"] = antes[1], antes[2], antes[3]
  C_ClickBindings, GetStringFromModifiers = viejos.C_ClickBindings, viejos.GetStringFromModifiers
  Enum.ClickBindingType, Enum.ClickBindingInteraction = enumViejo, iViejo
  Cu.OlvidarBitsBlizzard()
  Cu.AplicarMapa()
  T(2)
end)

local cuerpo
step("La barra de maná, furia o energía", function()
  cuerpo = boton.cuerpo
  check(cuerpo and cuerpo.recurso, "el marco no tiene barra de recurso")
  Cu.AjustarCuerpo(cuerpo, 84, 32)
  Cu.ActualizarTodo(boton)
  check(cuerpo.recurso:IsShown(), "la barra de recurso no se ve")
  local r, g, b = cuerpo.recurso:GetStatusBarColor()
  local rage = Cu.RECURSO.RAGE
  check(cerca(r, rage[1]) and cerca(g, rage[2]) and cerca(b, rage[3]), "el guerrero no tiene la barra color furia")
  check(cuerpo.recurso:GetValue() == 20, "la furia no vale 20: " .. tostring(cuerpo.recurso:GetValue()))
  check(Cu.oyeRecurso:IsEventRegistered("UNIT_POWER_UPDATE") and Cu.oyeRecurso:IsEventRegistered("UNIT_DISPLAYPOWER"), "no escucha el recurso")
  -- Cambia de recurso (forma de druida, por ejemplo): cambia el color.
  tipoPoder.party1 = { 3, "ENERGY" }
  FIRE(Cu.oyeRecurso, "OnEvent", "UNIT_DISPLAYPOWER", "party1")
  r, g, b = cuerpo.recurso:GetStatusBarColor()
  local en = Cu.RECURSO.ENERGY
  check(cerca(r, en[1]) and cerca(g, en[2]) and cerca(b, en[3]), "al cambiar a energía no cambió el color")
  -- Sin nombre (solo el número): maná.
  tipoPoder.party1 = { 0, nil }
  FIRE(Cu.oyeRecurso, "OnEvent", "UNIT_DISPLAYPOWER", "party1")
  r = cuerpo.recurso:GetStatusBarColor()
  check(cerca(r, Cu.RECURSO.MANA[1]), "con solo el número no pintó el maná")
  poder.party1 = 55
  FIRE(Cu.oyeRecurso, "OnEvent", "UNIT_POWER_UPDATE", "party1", "MANA")
  check(cuerpo.recurso:GetValue() == 55, "el valor no siguió al evento")
  -- Otra unidad (una placa de nombre): no se toca nada.
  FIRE(Cu.oyeRecurso, "OnEvent", "UNIT_POWER_UPDATE", "nameplate3", "MANA")
  -- En secreto: el valor pasa directo y el color se queda como estaba.
  SECRETOS_PRENDER({ "UnitPower", "UnitPowerMax", "UnitPowerType" })
  local antes = #ERRORS
  FIRE(Cu.oyeRecurso, "OnEvent", "UNIT_DISPLAYPOWER", "party1")
  FIRE(Cu.oyeRecurso, "OnEvent", "UNIT_POWER_UPDATE", "party1", "MANA")
  Cu.ActualizarTodo(boton)
  SECRETOS_APAGAR()
  check(#ERRORS == antes, "con valores secretos la barra de recurso truena")
  check(issecretvalue(cuerpo.recurso:GetValue()), "el valor secreto no llegó a la barra")
  r = cuerpo.recurso:GetStatusBarColor()
  check(cerca(r, Cu.RECURSO.MANA[1]), "con el tipo secreto cambió el color")
  tipoPoder.party1 = { 1, "RAGE" }
  poder.party1 = 20
  Cu.ActualizarTodo(boton)
  -- Apagada: se esconde, la vida baja hasta abajo y deja de escuchar.
  N.Set("curacion", "recurso", false)
  T(2)
  Cu.AjustarCuerpo(cuerpo, 84, 32)
  check(not cuerpo.recurso:IsShown(), "apagada, la barra de recurso se ve")
  check(not Cu.oyeRecurso:IsEventRegistered("UNIT_POWER_UPDATE"), "apagada, sigue escuchando el recurso")
  N.Set("curacion", "recurso", true)
  T(2)
  Cu.AjustarCuerpo(cuerpo, 84, 32)
  check(cuerpo.recurso:IsShown() and Cu.oyeRecurso:IsEventRegistered("UNIT_POWER_UPDATE"), "prendida otra vez, no volvió")
end)

step("El aspecto nuevo: fondo oscuro translúcido y la vida apagada", function()
  Cu.ActualizarTodo(boton)
  local _, _, _, a = cuerpo.fondo:GetVertexColor()
  local fr, fg, fb = cuerpo.fondo:GetVertexColor()
  check(a < 0.95 and fr < 0.15 and fg < 0.15 and fb < 0.15, "el fondo no es oscuro y translúcido")
  local r, g, b = cuerpo.barra:GetStatusBarColor()
  local w = RAID_CLASS_COLORS.WARRIOR
  check(r < w.r and g < w.g and b < w.b and r > 0.2, "la vida del guerrero no va con el color apagado")
  check(cuerpo.marco and #cuerpo.marco == 4, "falta el borde fino")
end)

step("Captura de los marcos (Curación, grupo de 5)", function()
  -- Cinco marcos de verdad (botones seguros) en columna, con el modo prueba al lado.
  local esc = CreateFrame("Frame", nil, UIParent)
  esc:SetFrameStrata("BACKGROUND")
  esc:SetSize(330, 230)
  esc:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  local cielo = esc:CreateTexture(nil, "BACKGROUND")
  cielo:SetAllPoints(esc)
  cielo:SetTexture("white")
  cielo:SetGradient("VERTICAL", CreateColor(0.035, 0.04, 0.045, 1), CreateColor(0.12, 0.14, 0.17, 1))
  for i = 1, 6 do
    local t = esc:CreateTexture(nil, "BACKGROUND", nil, -4)
    t:SetTexture("circle")
    t:SetSize(140 + i * 20, 90)
    t:SetPoint("CENTER", esc, "BOTTOMLEFT", i * 55, -10)
    t:SetVertexColor(0.06 + i * 0.004, 0.07, 0.08, 1)
  end
  local barras, marcos = {}, {}
  local unidades = { "player", "party1", "party2", "party3", "party4" }
  vida.party4 = 0
  for i, u in ipairs(unidades) do
    local b = CreateFrame("Button", "AlfaPrueba137bMarco" .. i, esc, "SecureActionButtonTemplate")
    b:SetSize(84, 32)
    b:SetPoint("TOPLEFT", esc, "TOPLEFT", 20, -20 - (i - 1) * 34)
    b:SetAttribute("unit", u)
    Cu.PrepararBoton(b)
    Cu.AjustarCuerpo(b.cuerpo, 84, 32)
    Cu.ActualizarTodo(b)
    marcos[#marcos + 1] = b
    barras[#barras + 1] = b.cuerpo.barra
    barras[#barras + 1] = b.cuerpo.recurso
  end
  UnitIsDeadOrGhost = function(u) return u == "party4" end
  Cu.ActualizarTodo(marcos[5])
  -- El objetivo: Colmillo (borde blanco fino).
  UnitIsUnit = function(a, b2) return a == b2 or (a == "party1" and b2 == "target") end
  Cu.ActualizarTodo(marcos[2])
  -- Al lado, el modo prueba con el porcentaje (cinco más).
  N.Set("curacion", "porcentaje", true)
  T(2)
  for _, b in ipairs(marcos) do Cu.ActualizarTodo(b) end
  Cu.Prueba(5)
  local an = Cu.ancla
  if an then
    an:ClearAllPoints()
    an:SetPoint("TOPLEFT", esc, "TOPLEFT", 128, -20)
  end
  for _, c in ipairs(Cu.cuerpos) do barras[#barras + 1] = c.barra barras[#barras + 1] = c.recurso end
  rellenar(barras)
  if Cu.asa then Cu.asa:Hide() end
  -- El banco pinta "white" como color liso (WHITE8x8 sería un ícono que falta).
  local function blanco(f)
    for _, c in ipairs(rawget(f, "_children") or {}) do
      if rawget(c, "_tex") == "Interface\\Buttons\\WHITE8x8" then c._tex = "white" end
      blanco(c)
    end
  end
  blanco(esc)
  if Cu.ancla then blanco(Cu.ancla) end
  SNAP("137b-curacion", esc, { Cu.ancla })
  check(#marcos == 5, "faltan marcos")
  Cu.Prueba(nil)
  N.Set("curacion", "porcentaje", false)
end)

print("prueba_137b_curacion: " .. (#ERRORS == 0 and "bien" or (#ERRORS .. " errores")))
