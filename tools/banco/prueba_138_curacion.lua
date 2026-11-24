-- Prueba de la 1.3.8, Curación (tools/prueba.py la corre con las demás):
--   * El bug del rojo fijo (lo vio Toxic: los marcos de su grupo salían rojos
--     de punta a punta con la vida llena). El velo de «En peligro» de la 1.3.7
--     era un rojo sobre toda la barra que dependía de la opacidad de una curva
--     de color, y el juego no la respetaba. El banco no tenía curvas: aquí se
--     simulan (C_CurveUtil y UnitHealthPercent) con ese mismo defecto (la
--     opacidad siempre 1) y se mide el color que se VE en medio de la barra
--     (la barra, más lo que tenga encima: mezcla normal o ADD).
--     Con la vida llena: el color de su clase, nunca rojo. Con vida, clase y
--     amenaza secretas, igual. Un guerrero (furia) y un sacerdote (maná).
--   * El color de los marcos: por clase (de fábrica), un solo color (con el
--     selector de colores del juego) y según la vida (también secreta), la
--     intensidad, «Color de clase» de antes, la página y la vista previa.
--   * «En peligro» solo bajo el 35 %, como borde y un tinte suave.
--   * Capturas de los tres modos con 5 de grupo (vida llena, media y baja).
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
local function check(cond, msg) if not cond then NOTE("1.3.8 curacion", msg) end end
local function T(n) RUN_TIMERS(n or 2) end
local function val(x) if issecretvalue(x) then return SECRETO_VALOR(x) end return x end
local function cerca(a, b, d) a, b = val(a), val(b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (d or 0.02) end
local function txt(r, g, b) return string.format("(%.2f, %.2f, %.2f)", val(r) or -1, val(g) or -1, val(b) or -1) end

---------------------------------------------------------------------------
-- Barras que se ven (el banco no pinta su relleno) y la mezcla de las texturas.
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
FM.SetBlendMode = function(self, m) rawset(self, "_blend", m) end
FM.GetBlendMode = function(self) return rawget(self, "_blend") or "BLEND" end
local function rellenar(barras)
  for _, sb in ipairs(barras) do
    local t = relleno(sb)
    local mn, mx = sb:GetMinMaxValues()
    local v, m = val(sb:GetValue()), val(mx)
    local frac = (type(m) == "number" and m > mn) and math.max(0, math.min(1, (v - mn) / (m - mn))) or 0
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", sb, "TOPLEFT", 0, 0)
    t:SetPoint("BOTTOMLEFT", sb, "BOTTOMLEFT", 0, 0)
    local _, _, ancho = sb:GetRect()
    t:SetWidth(math.max(0.01, (ancho or 0) * frac))
    if frac <= 0 then t:Hide() else t:Show() end
  end
end

---------------------------------------------------------------------------
-- Las curvas de color del juego, con el defecto que tiene en Forever: la
-- opacidad de los puntos no llega (GetRGBA siempre da 1). Los valores salen
-- secretos si la vida lo es.
---------------------------------------------------------------------------
local Enum = rawget(_G, "Enum") or {}
_G.Enum = Enum
Enum.LuaCurveType = { Linear = 0, Step = 1, Cosine = 2, Cubic = 3 }
local curvasCreadas = 0
local function nuevaCurva()
  curvasCreadas = curvasCreadas + 1
  local c = { puntos = {}, tipo = 0 }
  function c:SetType(t) self.tipo = t end
  function c:AddPoint(x, col) self.puntos[#self.puntos + 1] = { x, col.r, col.g, col.b, col.a } end
  function c:Evaluar(x)
    local P = self.puntos
    table.sort(P, function(a, b) return a[1] < b[1] end)
    if x <= P[1][1] then return P[1][2], P[1][3], P[1][4] end
    for i = 2, #P do
      if x < P[i][1] then
        if self.tipo == 1 then return P[i - 1][2], P[i - 1][3], P[i - 1][4] end
        local t = (x - P[i - 1][1]) / (P[i][1] - P[i - 1][1])
        local function m(k) return P[i - 1][k] + (P[i][k] - P[i - 1][k]) * t end
        return m(2), m(3), m(4)
      end
    end
    local u = P[#P]
    return u[2], u[3], u[4]
  end
  return c
end
C_CurveUtil = { CreateColorCurve = nuevaCurva, CreateCurve = function()
  local c = nuevaCurva()
  function c:AddPoint(x, y) self.puntos[#self.puntos + 1] = { x, y, y, y } end
  c.numerica = true -- (1.3.8 revisión: el porcentaje da un número, no un color)
  return c
end }
local vidaSecretaCurva = 0
UnitHealthPercent = function(u, pred, curva)
  local v, mx = UnitHealth(u), UnitHealthMax(u)
  local sec = issecretvalue(v) or issecretvalue(mx)
  v, mx = val(v), val(mx)
  local f = (mx and mx > 0) and v / mx or 0
  if not curva then return sec and SECRETO(f * 100) or f * 100 end
  if sec then vidaSecretaCurva = vidaSecretaCurva + 1 end
  -- (1.3.8 revisión) La curva recibe el mismo porcentaje que sale sin curva
  -- (aquí 0–100); Alfa averigua la escala (Marcos.lua, M.DetectarEscalaVida).
  local r, g, b = curva:Evaluar(f * 100)
  local function s(x) return sec and SECRETO(x) or x end
  if curva.numerica then return s(r) end
  -- (el defecto: la opacidad no llega)
  return { GetRGB = function() return s(r), s(g), s(b) end, GetRGBA = function() return s(r), s(g), s(b), s(1) end }
end
-- La clase secreta: el color también sale secreto.
C_ClassColor = { GetClassColor = function(clase)
  local sec = issecretvalue(clase)
  local c = RAID_CLASS_COLORS[val(clase)]
  if not c then return nil end
  if sec then return { r = SECRETO(c.r), g = SECRETO(c.g), b = SECRETO(c.b) } end
  return CreateColor(c.r, c.g, c.b, 1)
end }

---------------------------------------------------------------------------
-- El juego simulado: un sacerdote con su grupo de 5 clases distintas
---------------------------------------------------------------------------
local CLASES = { player = "PRIEST", party1 = "WARRIOR", party2 = "DRUID", party3 = "MAGE", party4 = "ROGUE" }
local NOMBRE_U = { player = "Toxic", party1 = "Yuki", party2 = "Luna", party3 = "Aullido", party4 = "Sombra" }
local vida = { player = 100, party1 = 100, party2 = 55, party3 = 25, party4 = 80 }
local poder = { player = 70, party1 = 0, party2 = 40, party3 = 85, party4 = 100 }
local tipoPoder = { player = { 0, "MANA" }, party1 = { 1, "RAGE" }, party2 = { 0, "MANA" }, party3 = { 0, "MANA" }, party4 = { 3, "ENERGY" } }
local amenazaDe = {}
UnitClass = function(u) local c = CLASES[u] if c then return c, c, 1 end return nil end
UnitName = function(u) return NOMBRE_U[u], nil end
UnitExists = function(u) return CLASES[u] ~= nil end
UnitHealth = function(u) return vida[u] or 0 end
UnitHealthMax = function() return 100 end
UnitPower = function(u) return poder[u] or 0 end
UnitPowerMax = function() return 100 end
UnitPowerType = function(u) local t = tipoPoder[u] if t then return t[1], t[2] end return 0, "MANA" end
UnitThreatSituation = function(u) return amenazaDe[u] end
UnitIsUnit = function(a, b) return a == b end
UnitIsConnected = function() return true end
UnitIsDeadOrGhost = function() return false end
UnitIsGhost = function() return false end
UnitGroupRolesAssigned = function() return "NONE" end
IsInGroup = function() return true end
GetNumGroupMembers = function() return 5 end
local combate = false
InCombatLockdown = function() return combate end
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
Cu.OlvidarCurvas() -- (las curvas se arman al primer uso: ya con las del banco)

local UNIDADES = { "player", "party1", "party2", "party3", "party4" }
local marcos = {}
for i, u in ipairs(UNIDADES) do
  local b = CreateFrame("Button", "AlfaPrueba138Marco" .. i, UIParent, "SecureActionButtonTemplate")
  b:SetSize(84, 32)
  b:SetAttribute("unit", u)
  Cu.PrepararBoton(b)
  Cu.AjustarCuerpo(b.cuerpo, 84, 32)
  marcos[u] = b
end
local function actualizar() for _, u in ipairs(UNIDADES) do Cu.ActualizarTodo(marcos[u]) end end

-- El color que se ve en medio de la barra: el relleno sobre el hueco, y encima
-- lo que se vea del velo de «En peligro» (mezcla normal o ADD). -> r, g, b
local function mezclar(base, t, alfaMarco)
  local r, g, b, a = t:GetVertexColor()
  r, g, b, a = val(r), val(g), val(b), val(a) or 1
  a = a * (alfaMarco or 1) * (val(t:GetAlpha()) or 1)
  if t:GetBlendMode() == "ADD" then
    return { base[1] + r * a, base[2] + g * a, base[3] + b * a }
  end
  return { base[1] * (1 - a) + r * a, base[2] * (1 - a) + g * a, base[3] * (1 - a) + b * a }
end
local function seVe(b)
  local c = b.cuerpo
  local hr, hg, hb = c.barra.fondo:GetVertexColor()
  local base = { val(hr), val(hg), val(hb) }
  local fill = relleno(c.barra)
  base = mezclar(base, fill)
  local p = c.alfaPeligro
  if p and p.velo:IsVisible() then base = mezclar(base, p.tinte, val(p.velo:GetAlpha())) end
  return base[1], base[2], base[3]
end
-- El borde del velo (lo que se ve en la orilla, sobre el color de la barra).
local function seVeBorde(b)
  local c = b.cuerpo
  local p = c.alfaPeligro
  local r, g, bb = seVe(b)
  if not (p and p.velo:IsVisible()) then return r, g, bb end
  local x = mezclar({ r, g, bb }, p.borde[1], val(p.velo:GetAlpha()))
  return x[1], x[2], x[3]
end
local function esRojoSolido(r, g, b) return r > 0.55 and g < 0.3 and b < 0.3 end
local function deClase(clase, k, base)
  local c = RAID_CLASS_COLORS[clase]
  k, base = k or 0.5, base or 0.04
  return c.r * k + base, c.g * k + base, c.b * k + base
end

---------------------------------------------------------------------------
step("La causa: con la vida llena nadie sale rojo (curva sin opacidad, como en el juego)", function()
  check(Cu.ModoColor() == "clase", "de fábrica el color no es «Por clase»: " .. tostring(Cu.ModoColor()))
  check(N.Get("curacion", "colorIntensidad") == "normal", "de fábrica la intensidad no es normal")
  for _, u in ipairs(UNIDADES) do vida[u] = 100 end
  actualizar()
  check(Cu.CurvaTanque() ~= nil and Cu.CurvasPeligro() ~= nil, "las curvas del banco no se armaron (la prueba no probaría nada)")
  for _, u in ipairs(UNIDADES) do
    local b = marcos[u]
    local r, g, bb = seVe(b)
    local er, eg, eb = deClase(CLASES[u])
    check(not esRojoSolido(r, g, bb), u .. " (" .. CLASES[u] .. ") con la vida llena se ve rojo: " .. txt(r, g, bb))
    check(cerca(r, er, 0.03) and cerca(g, eg, 0.03) and cerca(bb, eb, 0.03), u .. " con la vida llena no tiene el color de su clase: " .. txt(r, g, bb) .. " y debía " .. txt(er, eg, eb))
    check(not b.cuerpo.alfaPeligro.velo:IsShown(), u .. ": con la vida llena se ve el velo de «En peligro»")
    check(not b.cuerpo.pulso:IsShown(), u .. ": con la vida llena se ve el latido del tanque")
  end
  -- El guerrero (furia) y el sacerdote (maná): sus barras de recurso, intactas.
  local rr = { marcos.party1.cuerpo.recurso:GetStatusBarColor() }
  local rm = { marcos.player.cuerpo.recurso:GetStatusBarColor() }
  check(cerca(rr[1], Cu.RECURSO.RAGE[1]) and cerca(rr[2], Cu.RECURSO.RAGE[2]), "el guerrero no tiene su barra de furia")
  check(cerca(rm[1], Cu.RECURSO.MANA[1]) and cerca(rm[3], Cu.RECURSO.MANA[3]), "el sacerdote no tiene su barra de maná")
  check(marcos.party1.cuerpo.recurso:GetValue() == 0 and marcos.player.cuerpo.recurso:GetValue() == 70, "las barras de recurso no siguen su valor")
end)

step("Con vida, clase y amenaza secretas: tampoco rojo; abajo del 35 % solo un borde", function()
  for _, u in ipairs(UNIDADES) do vida[u] = 100 end
  amenazaDe.party3 = 3
  local antes = #ERRORS
  vidaSecretaCurva = 0
  SECRETOS_PRENDER({ "UnitHealth", "UnitHealthMax", "UnitClass", "UnitThreatSituation", "UnitPower", "UnitPowerMax" })
  actualizar()
  check(#ERRORS == antes, "con todo secreto los marcos truenan")
  check(vidaSecretaCurva > 0, "con la vida secreta no se usó la curva")
  for _, u in ipairs(UNIDADES) do
    local b = marcos[u]
    local p = b.cuerpo.alfaPeligro
    local r, g, bb = seVe(b)
    check(not esRojoSolido(r, g, bb), u .. " con la vida secreta (llena) se ve rojo: " .. txt(r, g, bb))
    -- La clase secreta: su color sin multiplicar, apagado con la opacidad.
    local c = RAID_CLASS_COLORS[CLASES[u]]
    local fr, fg, fb = relleno(b.cuerpo.barra):GetVertexColor()
    check(cerca(fr, c.r) and cerca(fg, c.g) and cerca(fb, c.b), u .. ": con la clase secreta la barra no lleva el color de su clase")
    if p.velo:IsShown() then
      check(p.tinte:GetBlendMode() == "ADD" and p.borde[1]:GetBlendMode() == "ADD", u .. ": con la vida secreta el velo no suma luz (ADD)")
      local br, bg, bbb = seVeBorde(b)
      check(cerca(br, r) and cerca(bg, g) and cerca(bbb, bb), u .. ": con la vida secreta llena se ve el borde rojo")
    end
    check(not b.cuerpo.alfaPeligro.brillo:IsShown(), u .. ": con la amenaza secreta brilla")
    check(not b.cuerpo.amenaza:IsShown(), u .. ": con la amenaza secreta sale la línea")
  end
  -- Baja (secreta): el borde rojo se ve, el medio de la barra apenas cambia.
  vida.party1 = 20
  Cu.ActualizarTodo(marcos.party1)
  local b = marcos.party1
  local r, g, bb = seVe(b)
  local br = seVeBorde(b)
  check(not esRojoSolido(r, g, bb), "con la vida secreta al 20 % la barra se ve roja sólida: " .. txt(r, g, bb))
  check(br > r + 0.4, "con la vida secreta al 20 % no se ve el borde de «En peligro»")
  SECRETOS_APAGAR()
  amenazaDe.party3 = nil
  vida.party1 = 100
  actualizar()
end)

step("El tanque en apuros: legible sin curva; secreto con ADD", function()
  local b = marcos.party1
  b.esTanque = true
  vida.party1 = 100
  Cu.Tanque(b)
  check(not b.cuerpo.pulso:IsShown() and b.alfaTanqueBajo == false, "el tanque con la vida llena late")
  vida.party1 = 30
  Cu.Tanque(b)
  check(b.cuerpo.pulso:IsShown() and b.alfaTanqueBajo == true, "el tanque al 30 % no late")
  SECRETOS_PRENDER({ "UnitHealth", "UnitHealthMax" })
  vida.party1 = 100
  Cu.Tanque(b)
  local t = b.cuerpo.alerta[1]
  local r, g, bb = t:GetVertexColor()
  check(t:GetBlendMode() == "ADD" and cerca(r, 0) and cerca(g, 0) and cerca(bb, 0), "con la vida secreta llena el borde del tanque no es negro con ADD (se vería)")
  SECRETOS_APAGAR()
  b.esTanque = false
  vida.party1 = 100
  Cu.Tanque(b)
end)

step("«En peligro»: solo bajo el 35 %, un borde y un tinte suave", function()
  local b = marcos.party3
  for _, v in ipairs({ 100, 60, 36, 35 }) do
    vida.party3 = v
    Cu.ActualizarTodo(b)
    check(not b.cuerpo.alfaPeligro.velo:IsShown(), "con " .. v .. " % sale el velo")
  end
  vida.party3 = 20
  Cu.ActualizarTodo(b)
  local p = b.cuerpo.alfaPeligro
  check(p.velo:IsShown(), "con 20 % no sale el velo")
  local _, _, _, a = p.tinte:GetVertexColor()
  check(val(a) <= 0.2, "el tinte de «En peligro» no es suave: " .. tostring(val(a)))
  local r, g, bb = seVe(b)
  check(not esRojoSolido(r, g, bb), "con 20 % el medio de la barra es rojo sólido: " .. txt(r, g, bb))
  check(#p.borde == 4, "falta el borde de «En peligro»")
  vida.party3 = 0
  Cu.ActualizarTodo(b)
  check(not p.velo:IsShown(), "con 0 de vida sale el velo")
  vida.party3 = 25
  Cu.ActualizarTodo(b)
end)

step("Un solo color, según la vida, intensidad y «Color de clase» de antes", function()
  local antes = 0
  local cab = Cu.cabecera
  local orig = cab and cab.SetAttribute
  if cab then cab.SetAttribute = function(self, k, v) antes = antes + 1 return orig(self, k, v) end end
  combate = true -- solo se repinta: se puede en combate (nada de atributos)
  N.Set("curacion", "colorUnico", { 0.2, 0.4, 0.9 })
  N.Set("curacion", "colorModo", "unico")
  T(1)
  check(N.Get("curacion", "colorClase") == false, "con «Un solo color», «Color de clase» quedó prendido")
  local fr, fg, fb = relleno(marcos.party1.cuerpo.barra):GetVertexColor()
  check(cerca(fr, 0.2 * 0.5 + 0.04) and cerca(fg, 0.4 * 0.5 + 0.04) and cerca(fb, 0.9 * 0.5 + 0.04), "«Un solo color» no pinta tu color: " .. txt(fr, fg, fb))
  local nr, ng, nb = marcos.party1.cuerpo.nombre:GetTextColor()
  check(val(nr) > val(nb), "con «Un solo color» el nombre del guerrero no lleva un toque de su clase")
  N.Set("curacion", "colorModo", "vida")
  T(1)
  vida.party2, vida.party3 = 55, 25
  actualizar()
  local function de(u) local r, g, b = relleno(marcos[u].cuerpo.barra):GetVertexColor() return val(r), val(g), val(b) end
  local r1, g1 = de("player")
  check(g1 > r1, "según la vida, la vida llena no es verde: " .. txt(de("player")))
  local r3, g3 = de("party3")
  check(r3 > g3 * 1.5, "según la vida, al 25 % no es rojo: " .. txt(de("party3")))
  check(r3 < 0.6, "según la vida, el rojo es chillón: " .. txt(de("party3")))
  local r2, g2, b2 = de("party2")
  check(r2 > b2 and g2 > b2, "según la vida, a la mitad no es amarillo: " .. txt(de("party2")))
  -- Con cada UNIT_HEALTH cambia.
  vida.player = 20
  FIRE_EVENT("UNIT_HEALTH", "player")
  local r4, g4 = de("player")
  check(r4 > g4, "según la vida, al bajar no cambió el color")
  vida.player = 100
  FIRE_EVENT("UNIT_HEALTH", "player")
  -- Secreta: va por la curva, igual que legible.
  SECRETOS_PRENDER({ "UnitHealth", "UnitHealthMax" })
  Cu.ActualizarTodo(marcos.party3)
  local sr, sg = de("party3")
  check(cerca(sr, r3) and cerca(sg, g3), "según la vida, secreta, no da el mismo color: " .. txt(de("party3")))
  SECRETOS_APAGAR()
  -- Intensidad.
  N.Set("curacion", "colorModo", "clase")
  T(1)
  check(N.Get("curacion", "colorClase") == true, "al volver a «Por clase», «Color de clase» quedó apagado")
  N.Set("curacion", "colorIntensidad", "vivo")
  T(1)
  local vr = de("party1")
  check(cerca(vr, 0.78 * 0.72 + 0.03), "«Vivo» no aviva el color: " .. txt(de("party1")))
  N.Set("curacion", "colorIntensidad", "apagado")
  T(1)
  local ar = de("party1")
  check(ar < vr and cerca(ar, 0.78 * 0.38 + 0.05), "«Apagado» no apaga el color: " .. txt(de("party1")))
  N.Set("curacion", "colorIntensidad", "normal")
  -- «Color de clase» apagado (de antes de la 1.3.8): un solo color, el verde de antes.
  N.Set("curacion", "colorClase", false)
  T(1)
  check(Cu.ModoColor() == "unico", "con «Color de clase» apagado de antes no es «Un solo color»")
  N.Set("curacion", "colorUnico", nil)
  N.Set("curacion", "colorClase", nil)
  N.Set("curacion", "colorModo", nil)
  T(1)
  check(Cu.ModoColor() == "clase", "restablecido no vuelve a «Por clase»")
  combate = false
  if cab then cab.SetAttribute = nil end
  check(antes == 0, "cambiar el color tocó la cabecera segura: " .. antes)
  check(#Cu.cuerpos > 0, "sin cuerpos")
end)

step("El selector de colores del juego", function()
  local info, mostrado
  ColorPickerFrame = { SetupColorPickerAndShow = function(self, i) info = i mostrado = true end,
    GetColorRGB = function() return 0.9, 0.3, 0.6 end }
  check(Cu.ElegirColor() == true and mostrado and info, "no abrió el selector de colores")
  check(Cu.ModoColor() == "unico", "elegir un color no pasa a «Un solo color»")
  check(info.hasOpacity == false and type(info.swatchFunc) == "function" and type(info.cancelFunc) == "function", "el selector no lleva sus funciones")
  info.swatchFunc()
  T(1)
  local r, g, b = Cu.ColorUnico()
  check(cerca(r, 0.9) and cerca(g, 0.3) and cerca(b, 0.6), "el color elegido no se guardó")
  local fr = relleno(marcos.player.cuerpo.barra):GetVertexColor()
  check(cerca(fr, 0.9 * 0.5 + 0.04), "el color elegido no se ve en los marcos")
  info.cancelFunc()
  T(1)
  r = Cu.ColorUnico()
  check(cerca(r, 0.545), "cancelar no deja el color de antes")
  combate = true
  mostrado = nil
  check(Cu.ElegirColor() == false and not mostrado, "en combate abrió el selector (es una ventana del juego)")
  combate = false
  ColorPickerFrame = nil
  N.Set("curacion", "colorModo", nil)
  N.Set("curacion", "colorClase", nil)
  N.Set("curacion", "colorUnico", nil)
  T(1)
end)

step("La página: «Color de los marcos» y su vista previa", function()
  local g = Cu.GrupoColor(UIParent, function() return true end)
  g:Refrescar()
  g:Acomodar(620)
  check(#g.filas == 4, "la sección no tiene sus 4 filas: " .. #g.filas)
  local vista = g.filas[4].Control
  check(vista and vista.minis and #vista.minis == 3, "falta la vista previa")
  local llena = vista.minis[1]
  local r, gg, b = llena.vida:GetVertexColor()
  local er, eg, eb = deClase("WARRIOR")
  check(cerca(r, er) and cerca(gg, eg) and cerca(b, eb), "la vista previa (por clase) no es el color del guerrero")
  check(llena.borde[1]:IsShown() == false and vista.minis[3].borde[1]:IsShown() == true, "la vista previa no muestra «En peligro» solo en la baja")
  N.Set("curacion", "colorModo", "vida")
  T(1)
  vista:Leer()
  local vr, vg = vista.minis[1].vida:GetVertexColor()
  check(val(vg) > val(vr), "la vista previa según la vida no es verde llena")
  local chip = g.filas[2].Control
  check(chip and chip.Chip and chip.Boton, "falta la muestra de «Tu color»")
  N.Set("curacion", "colorModo", nil)
  T(1)
  -- La búsqueda de ajustes: los controles nuevos están y el viejo no.
  local mod
  for _, m in pairs(N.modulos or {}) do if type(m) == "table" and m.id == "curacion" then mod = m end end
  if mod and mod.controles then
    local hay, viejo = {}, false
    for _, c in ipairs(mod.controles) do
      if c.key then hay[c.key] = true end
      if c.key == "curacion.colorClase" then viejo = true end
    end
    check(hay["curacion.colorModo"] and hay["curacion.colorIntensidad"], "la búsqueda no tiene «Color de la barra» o «Intensidad»")
    check(not viejo, "la búsqueda sigue con el interruptor viejo «Color de clase»")
  end
  g:Hide()
end)

---------------------------------------------------------------------------
-- Capturas: los tres modos, 5 de grupo con vida llena, media y baja.
---------------------------------------------------------------------------
local function blanco(f)
  for _, c in ipairs(rawget(f, "_children") or {}) do
    if rawget(c, "_tex") == "Interface\\Buttons\\WHITE8x8" then c._tex = "white" end
    blanco(c)
  end
end

local function escena(nombre, modo, extra)
  for k, v in pairs(extra or {}) do N.Set("curacion", k, v) end
  N.Set("curacion", "colorModo", modo)
  T(1)
  local esc = CreateFrame("Frame", nil, UIParent)
  esc:SetFrameStrata("BACKGROUND")
  esc:SetSize(124, 200)
  esc:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  local cielo = esc:CreateTexture(nil, "BACKGROUND")
  cielo:SetAllPoints(esc)
  cielo:SetTexture("white")
  cielo:SetGradient("VERTICAL", CreateColor(0.035, 0.04, 0.05, 1), CreateColor(0.11, 0.13, 0.17, 1))
  for i = 1, 4 do
    local t = esc:CreateTexture(nil, "BACKGROUND", nil, -4)
    t:SetTexture("circle")
    t:SetSize(90 + i * 14, 60)
    t:SetPoint("CENTER", esc, "BOTTOMLEFT", i * 30, -6)
    t:SetVertexColor(0.06 + i * 0.004, 0.07, 0.085, 1)
  end
  local barras = {}
  for i, u in ipairs(UNIDADES) do
    local b = CreateFrame("Button", "AlfaPrueba138" .. nombre .. i, esc, "SecureActionButtonTemplate")
    b:SetSize(84, 32)
    b:SetPoint("TOPLEFT", esc, "TOPLEFT", 20, -20 - (i - 1) * 34)
    b:SetAttribute("unit", u)
    Cu.PrepararBoton(b)
    Cu.AjustarCuerpo(b.cuerpo, 84, 32)
    Cu.ActualizarTodo(b)
    barras[#barras + 1] = b.cuerpo.barra
    barras[#barras + 1] = b.cuerpo.recurso
    -- nada chillón: el medio de cada barra no es rojo sólido
    local r, g, bb = seVe(b)
    -- (según la vida, quien está bajo sí va hacia el rojo: apagado, no sólido)
    if modo ~= "vida" or vida[u] >= 35 then
      check(not esRojoSolido(r, g, bb), nombre .. ": " .. u .. " se ve rojo sólido " .. txt(r, g, bb))
    end
    local mr, mg, mb = math.max(r, g, bb), math.min(r, g, bb), 0
    check(mr - mg < 0.72, nombre .. ": " .. u .. " tiene un color chillón " .. txt(r, g, bb))
  end
  rellenar(barras)
  blanco(esc)
  SNAP(nombre, esc)
  esc:Hide()
  for k in pairs(extra or {}) do N.Set("curacion", k, nil) end
  N.Set("curacion", "colorModo", nil)
  T(1)
end

step("Capturas de los tres modos (5 de grupo: llena, media y baja)", function()
  vida.player, vida.party1, vida.party2, vida.party3, vida.party4 = 100, 100, 55, 25, 80
  N.Set("curacion", "porcentaje", true)
  T(1)
  escena("138-curacion-clase", "clase")
  escena("138-curacion-unico", "unico", { colorUnico = { 0.36, 0.62, 0.86 } })
  escena("138-curacion-vida", "vida")
  escena("138-curacion-vivo", "clase", { colorIntensidad = "vivo" })
  N.Set("curacion", "porcentaje", nil)
  T(1)
end)

step("Captura de la sección «Color de los marcos»", function()
  local esc = CreateFrame("Frame", nil, UIParent)
  esc:SetSize(600, 330)
  esc:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  local fondo = esc:CreateTexture(nil, "BACKGROUND")
  fondo:SetAllPoints(esc)
  fondo:SetTexture("white")
  fondo:SetVertexColor(0.06, 0.07, 0.08, 1)
  N.Set("curacion", "colorUnico", { 0.36, 0.62, 0.86 })
  N.Set("curacion", "colorModo", "unico")
  T(1)
  local g = Cu.GrupoColor(esc, function() return true end)
  g:SetPoint("TOPLEFT", esc, "TOPLEFT", 12, -12)
  g:Refrescar()
  local alto = g:Acomodar(576)
  esc:SetHeight(alto + 24)
  blanco(esc)
  SNAP("138-curacion-pagina", esc)
  esc:Hide()
  N.Set("curacion", "colorModo", nil)
  N.Set("curacion", "colorUnico", nil)
  T(1)
end)

print("prueba_138_curacion: " .. (#ERRORS == 0 and "bien" or (#ERRORS .. " errores")))
