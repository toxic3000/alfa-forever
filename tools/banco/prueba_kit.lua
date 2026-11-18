-- Prueba del botón seguro del Kit (K.Seguro) y de que Alfa nunca abre desde
-- su código las ventanas de Blizzard que bloquean después (tools/prueba.py la
-- corre con las demás prueba_*.lua).
--
-- En el juego, si un addon abre la ventana de talentos (que en Forever es la
-- misma del libro de hechizos) o la de clic para lanzar (que abre el libro),
-- el juego la marca como tocada por el addon y luego bloquea lanzar desde
-- ella: "Alfa_Builds se ha bloqueado de una acción disponible solo para la
-- interfaz de Blizzard". Aquí esas funciones son trampas: si Alfa las llama,
-- la prueba falla. El clic lo tiene que hacer el juego (un botón seguro).
SNAPSHOTS = {}
BANCO_LETRA = 0.64
local mal
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if mal and #mal > 0 then
    NOTE("paso " .. nombre, "Alfa abrió desde su código: " .. table.concat(mal, ", ") .. " (el juego bloquearía lanzar desde esa ventana; usa K.Seguro)")
    for i = #mal, 1, -1 do mal[i] = nil end
  end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function T(n) RUN_TIMERS(n or 2) end
local function ns(n) return NS_OF(n) end

-- Las trampas: abrir estas ventanas desde Alfa es el error.
local abiertas = {}
mal = {}
-- Se anota (el código de Alfa podría llamarla dentro de un pcall) y se
-- revisa al final de cada paso.
local function trampa(nombre)
  return function() mal[#mal + 1] = nombre error("Alfa abrió desde su código: " .. nombre .. " (usa K.Seguro)") end
end
PlayerSpellsUtil = setmetatable({}, { __index = function(_, k) return trampa("PlayerSpellsUtil." .. tostring(k)) end })
PlayerSpellsFrame_LoadUI = trampa("PlayerSpellsFrame_LoadUI")
ToggleClickBindingFrame = trampa("ToggleClickBindingFrame")
ClickBindingFrame_LoadUI = trampa("ClickBindingFrame_LoadUI")
SLASH_CLICKCASTING1 = "/clickcast"

-- Los botones del juego que sí puede "clicar" el botón seguro.
local function micro(nombre)
  local b = CreateFrame("Button", nombre, UIParent)
  b:SetScript("OnClick", function() abiertas[nombre] = (abiertas[nombre] or 0) + 1 end)
  return b
end
micro("TalentMicroButton")
micro("MainMenuBarBackpackButton")

GetBindingKey = function(a) if a == "TOGGLETALENTS" then return "N" end if a == "OPENALLBAGS" then return "B" end return nil end
GetBindingText = function(k) return k end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
local A, N = Alfa, AlfaNucleo
local K = N.Kit
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
-- Quien ya pasó la bienvenida (si no, Alfa abre primero el asistente).
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

-- El clic del botón seguro, como lo hace el juego (SECURE_ACTIONS de
-- SecureTemplates.lua): "click" pulsa su clickbutton; "macro" corre el texto.
local macros = {}
local function clicSeguro(s)
  s:Click("LeftButton")
  local tipo = s:GetAttribute("type")
  if tipo == "click" then
    local d = s:GetAttribute("clickbutton")
    if not d then error("el botón seguro no tiene clickbutton") end
    d:Click("LeftButton")
  elseif tipo == "macro" then
    macros[#macros + 1] = s:GetAttribute("macrotext")
  else
    error("el botón seguro no tiene tipo: " .. tostring(tipo))
  end
end

local function seguro() return _G.AlfaKitSeguro end

-- Todos los botones del Kit con botón seguro que están a la vista.
local function conSeguro()
  local out = {}
  for _, f in ipairs(ALL_FRAMES()) do
    if f.alfaConSeguro and f.alfaSeguro and f:IsVisible() then out[#out + 1] = f end
  end
  return out
end

-- 1. El Kit: un botón con K.Seguro se cubre al pasar el ratón y el juego hace el clic.
step("kit: K.Seguro cubre el botón y hace el clic del juego", function()
  local raiz = K.Raiz and K.Raiz() or UIParent
  local hubo = 0
  local b = K.Boton(raiz, "Probar", function() hubo = hubo + 1 end)
  b:SetSize(120, 26) b:SetPoint("CENTER") b:Show()
  local tras = 0
  K.Seguro(b, function() return K.AbrirJuego("talentos") end)
  b.alfaTrasClic = function() tras = tras + 1 end
  FIRE(b, "OnEnter")
  local s = seguro()
  if not (s and s:IsShown() and s.dueno == b) then error("el botón seguro no cubrió al botón del Kit") end
  if s:GetAttribute("clickbutton") ~= _G.TalentMicroButton then error("no apunta al botón de talentos del juego") end
  clicSeguro(s)
  if (abiertas.TalentMicroButton or 0) ~= 1 then error("el clic no llegó al botón de talentos del juego") end
  if tras ~= 1 then error("no corrió lo de después del clic (alfaTrasClic)") end
  if hubo ~= 0 then error("también corrió el clic de Alfa") end
  FIRE(s, "OnLeave")
  if s:IsShown() then error("el botón seguro no se fue al salir el ratón") end
  -- Antes del combate se quita; en combate no aparece y el botón hace su clic normal.
  FIRE(b, "OnEnter")
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  if s:IsShown() then error("el botón seguro siguió puesto al entrar en combate") end
  local viejo = InCombatLockdown
  InCombatLockdown = function() return true end
  FIRE(b, "OnEnter")
  local mostro = s:IsShown()
  InCombatLockdown = viejo
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  if mostro then error("el botón seguro se puso en combate") end
  FIRE(b, "OnClick", "LeftButton")
  if hubo ~= 1 then error("sin botón seguro, el botón no hizo su clic normal") end
  -- Si el botón se oculta, el seguro se va con él.
  FIRE(b, "OnEnter")
  b:Hide()
  if s:IsShown() then error("el botón seguro se quedó tras ocultarse su botón") end
end)

-- 2. Talentos: sus botones para abrir la ventana del juego usan el botón seguro.
local Bd = ns("Alfa_Builds")
step("talentos: la página en todos sus estados sin abrir la ventana desde Alfa", function()
  A.Fire("SHOW_OPTIONS", "builds") T(2)
  if not (A.UI.Options.frame and A.UI.Options.frame:IsShown()) then error("no se abrió la página de Talentos") end
  for _, b in ipairs(conSeguro()) do
    FIRE(b, "OnEnter")
    local s = seguro()
    if s and s:IsShown() then clicSeguro(s) FIRE(s, "OnLeave") end
    -- Y el clic normal (en combate, teclado o mando): solo un aviso con la tecla.
    FIRE(b, "OnClick", "LeftButton")
  end
  T(1)
  if #conSeguro() == 0 then error("la página de Talentos no tiene ningún botón para abrir la ventana del juego") end
  if (abiertas.TalentMicroButton or 0) < 2 then error("el botón de Talentos no abrió la ventana del juego con el botón seguro") end
end)

-- 3. Curación: "Usar también en los marcos de Blizzard".
local Cu = ns("Alfa_Curacion")
step("curación: abrir el clic para lanzar de Blizzard con el botón seguro", function()
  A.Fire("SHOW_OPTIONS", "curacion") T(2)
  local antes = #macros
  for _, b in ipairs(conSeguro()) do
    FIRE(b, "OnEnter")
    local s = seguro()
    if s and s:IsShown() then clicSeguro(s) FIRE(s, "OnLeave") end
  end
  if #macros == antes then error("el botón «Usar» no abrió el clic para lanzar con el botón seguro") end
  if macros[#macros] ~= "/clickcast" then error("el botón seguro no corrió el comando del juego: " .. tostring(macros[#macros])) end
  local r = Cu.Datos().blizzard
  if not (type(r) == "table" and r.texto) then error("la página no dice qué pasó tras abrir la ventana") end
  -- El clic normal y el comando: solo dicen cómo abrirla.
  local ok, texto = Cu.UsarEnBlizzard()
  if not texto or not texto:find("/clickcast", 1, true) then error("sin botón seguro no dice cómo abrir la ventana: " .. tostring(texto)) end
  A.RunCommand("curacion blizzard")
end)

-- 4. Las demás páginas y ventanas tampoco abren esas ventanas desde Alfa.
local PAGINAS = { "inicio", "rutas", "enciclopedia", "builds", "bolsas", "manada", "mazmorras", "mundo",
  "pesca", "lya", "vista", "comodidades", "comercio", "recoleccion", "combate", "curacion" }
for _, id in ipairs(PAGINAS) do
  step("página " .. id .. " sin abrir ventanas del juego", function() A.Fire("SHOW_OPTIONS", id) T(1) end)
end

-- 5. El buscador de Ajustes sin resultados ofrece buscar en la Enciclopedia.
step("ajustes: buscar algo del juego lleva a la Enciclopedia", function()
  local O = A.UI.Options
  A.Fire("SHOW_OPTIONS", "inicio") T(1)
  local E = AlfaEnciclopedia
  if not (O.SetQuery and E and E.Buscar) then print("AVISO: sin buscador de ajustes o sin Enciclopedia") return end
  local pedida
  local viejo = E.Buscar
  E.Buscar = function(t) pedida = t end
  O.SetQuery("zzcobrexx") T(1)
  local link
  for _, f in ipairs(ALL_FRAMES()) do
    local etiqueta = f.Label or f.Text
    if type(etiqueta) == "table" and etiqueta.GetText then
      local t = etiqueta:GetText() or ""
      if t:find("zzcobrexx", 1, true) and t:find("Enciclopedia", 1, true) and f:IsVisible() then link = f end
    end
  end
  if not link then E.Buscar = viejo error("sin resultados no salió «Buscar … en la Enciclopedia»") end
  FIRE(link, "OnClick", "LeftButton")
  E.Buscar = viejo
  if pedida ~= "zzcobrexx" then error("el enlace no buscó en la Enciclopedia: " .. tostring(pedida)) end
  O.SetQuery("") T(1)
end)
step("cerrar ajustes", function() local f = A.UI.Options.frame if f then f:Hide() end end)

print(("PRUEBA: %d pasos, %d errores"):format(pasos, #ERRORS))
