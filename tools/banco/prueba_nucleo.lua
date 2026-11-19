-- Prueba del Núcleo, Talentos, Curación y Lya (tools/prueba.py la corre con
-- las demás prueba_*.lua): los casos difíciles del botón seguro del Kit
-- (K.Seguro: un botón que cambia de datos, que se apaga o se oculta, el mando,
-- después del combate), la tecla del juego, el enlace de una sección que no
-- tapa su título, los avisos de hechizos nuevos de Talentos y la búsqueda de
-- equipo que no se queda trabada.
--
-- Las trampas son las de prueba_kit.lua: si Alfa abre desde su código la
-- ventana de talentos o la de clic para lanzar, la prueba falla (el juego
-- bloquearía después lanzar desde ellas).
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
micro("PlayerSpellsMicroButton")
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

local function seguro() return _G.AlfaKitSeguro end
local function cubre(b) local s = seguro() return s and s:IsShown() and s.dueno == b end

-- Un botón del Kit con seguro, a la vista, en su propia capa.
local raiz = K.Raiz and K.Raiz() or UIParent
local caja = CreateFrame("Frame", nil, raiz)
caja:SetFrameStrata("HIGH")
caja:SetSize(400, 200)
caja:SetPoint("CENTER")
local normales = 0
local b = K.Boton(caja, "Probar", function() normales = normales + 1 end)
b:SetSize(120, 26)
b:SetPoint("CENTER")

-- 1. El seguro: hace su acción al soltar el clic, en la capa del botón y encima de él.
step("seguro: al soltar el clic, en la capa y encima del botón", function()
  K.Seguro(b, function() return K.AbrirJuego("talentos") end)
  FIRE(b, "OnEnter")
  local s = seguro()
  if not cubre(b) then error("el botón seguro no cubrió al botón") end
  -- Con "lanzar al pulsar la tecla" prendido, SecureActionButton_OnClick solo
  -- actúa al apretar; un clic que solo llega al soltar no haría nada.
  if s:GetAttribute("useOnKeyDown") ~= false then error("el botón seguro no tiene useOnKeyDown = false") end
  if s:GetFrameStrata() ~= b:GetFrameStrata() then error("el seguro no está en la capa del botón: " .. tostring(s:GetFrameStrata())) end
  if s:GetFrameLevel() <= b:GetFrameLevel() then error("el seguro quedó debajo del botón") end
  FIRE(s, "OnLeave")
  if s:IsShown() then error("el seguro no se fue al salir el ratón") end
end)

-- 2. Un botón que se reutiliza con otros datos (una tarjeta, el globo de Lya).
step("seguro: el botón cambia de datos con el ratón encima", function()
  FIRE(b, "OnEnter")
  if not cubre(b) then error("no cubrió") end
  K.SeguroDe(b, { texto = "Otra cosa", alClic = function() end })
  if seguro():IsShown() then error("el seguro siguió con la acción vieja tras cambiar los datos del botón") end
  K.SeguroDe(b, { texto = "Talentos", seguro = function() return K.AbrirJuego("talentos") end })
  FIRE(b, "OnEnter")
  if not cubre(b) then error("no volvió a cubrir") end
  K.SeguroDe(b, { texto = "Bolsas", seguro = function() return K.AbrirJuego("bolsas") end })
  if not cubre(b) then error("el seguro se fue al cambiar a otra acción del juego") end
  if seguro():GetAttribute("clickbutton") ~= _G.MainMenuBarBackpackButton then error("el seguro no tomó la acción nueva") end
  FIRE(seguro(), "OnLeave")
end)

-- 3. Si el botón se apaga o su ventana se oculta, el seguro se va.
step("seguro: botón apagado o ventana oculta", function()
  FIRE(b, "OnEnter")
  b:SetActivo(false)
  FIRE(seguro(), "OnUpdate", 0.02)
  if seguro():IsShown() then error("el seguro siguió sobre un botón apagado") end
  FIRE(b, "OnEnter")
  if seguro():IsShown() then error("el seguro cubrió un botón apagado") end
  b:SetActivo(true)
  FIRE(b, "OnEnter")
  if not cubre(b) then error("no cubrió otra vez") end
  caja:Hide()
  FIRE(seguro(), "OnUpdate", 0.02)
  if seguro():IsShown() then error("el seguro siguió tras ocultarse la ventana del botón") end
  caja:Show()
end)

-- 4. Con la interfaz de mando, el botón hace su clic normal.
step("seguro: con la interfaz de mando no aparece", function()
  local viejo = A.GamepadUI
  A.GamepadUI = function() return true end
  FIRE(b, "OnEnter")
  local mostro = seguro():IsShown()
  A.GamepadUI = viejo
  if mostro then error("el seguro apareció con la interfaz de mando") end
  FIRE(b, "OnLeave")
end)

-- 5. El combate: se va antes y vuelve al terminar si el ratón sigue encima.
step("seguro: vuelve al terminar el combate", function()
  b.IsMouseOver = function() return true end
  FIRE(b, "OnEnter")
  if not cubre(b) then error("no cubrió") end
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  if seguro():IsShown() then error("el seguro siguió al entrar en combate") end
  local viejo = InCombatLockdown
  InCombatLockdown = function() return true end
  FIRE(b, "OnEnter")
  local mostro = seguro():IsShown()
  InCombatLockdown = viejo
  if mostro then error("el seguro se puso en combate") end
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  if not cubre(b) then error("al terminar el combate, con el ratón encima, el seguro no volvió") end
  b.IsMouseOver = nil
  FIRE(seguro(), "OnLeave")
  FIRE(b, "OnLeave")
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  if seguro():IsShown() then error("el seguro volvió sin el ratón encima") end
end)

-- 6. El botón del juego apagado no sirve: sigue el otro.
step("abrir del juego: un botón apagado no se usa", function()
  _G.TalentMicroButton:Disable()
  local a = K.AbrirJuego("talentos")
  _G.TalentMicroButton:Enable()
  if not (a and a.clickbutton == _G.PlayerSpellsMicroButton) then error("con el de talentos apagado no usó el de hechizos y talentos") end
  local a2 = K.AbrirJuego("talentos")
  if not (a2 and a2.clickbutton == _G.TalentMicroButton) then error("no prefirió el botón de talentos") end
end)

-- 7. La tecla del juego: si el juego no sabe escribirla, la tecla tal cual
-- (nunca el texto de un error).
step("tecla del juego", function()
  local viejo = GetBindingText
  GetBindingText = function() error("sin texto") end
  local t = K.TeclaJuego("talentos")
  GetBindingText = viejo
  if t ~= "N" then error("la tecla salió como: " .. tostring(t)) end
  if K.TeclaJuego("talentos") ~= "N" then error("sin la tecla de talentos") end
end)

-- 8. El enlace de una sección (a la derecha) no tapa su título.
step("sección: el título no se mete bajo el enlace", function()
  local s = K.Seccion(caja, "Un título de sección muy largo que no cabe junto a su enlace", {
    cuenta = "12/51", enlace = { texto = "Abrir la ventana del juego", alClic = function() end } })
  s:SetPoint("TOPLEFT", caja, "TOPLEFT", 0, 0)
  s:SetWidth(360)
  s:Acomodar(360)
  local derTitulo = s.Cuenta:GetRight()
  local izqEnlace = s.Enlace:GetLeft()
  if derTitulo and izqEnlace and derTitulo > izqEnlace + 1 then
    error(("el título (y su cuenta) llega a %d y el enlace empieza en %d"):format(derTitulo, izqEnlace))
  end
  s:Hide()
end)

-- 9. Talentos: los avisos de hechizos nuevos se reemplazan y se ocultan sin errores.
local Bd = ns("Alfa_Builds")
step("talentos: avisos de hechizos nuevos (uno tras otro y ocultar)", function()
  local fn = A.Reemplazo and A.Reemplazo("SPELL_CARDS")
  if not fn then print("AVISO: Talentos no tomó SPELL_CARDS") return end
  -- Los avisos del Kit a la vista (los de al entrar pueden seguir ahí).
  local function vivos()
    local n = 0
    for _, f in ipairs(ALL_FRAMES()) do if f.alfaVivo and f.BotonCerrar then n = n + 1 end end
    return n
  end
  local antes = vivos()
  fn({ modelo = { kind = "newSpells", head = "Nivel 24", spells = { { id = 100, cost = 120 } } }, Cerrar = function() end })
  if vivos() ~= antes + 1 then error("no salió el aviso de hechizos nuevos") end
  -- Uno nuevo cierra el de antes (el motor ya lo dio por cerrado).
  fn({ modelo = { kind = "oldRanks", spells = { { id = 78, bestId = 284 } }, act = true }, Cerrar = function() end })
  if vivos() ~= antes + 1 then error("el aviso de antes no se cerró al llegar uno nuevo") end
  fn({ accion = "ocultar" })
  if vivos() ~= antes then error("«ocultar» no quitó el aviso") end
  T(2)
end)

-- 10. Equipo: si algo de la base falla, la búsqueda no se queda trabada.
step("equipo: un error no deja la búsqueda trabada", function()
  local E = Bd.Equipo
  local b0 = Bd.BuildElegido and Bd.BuildElegido()
  local DB = A.ItemDB
  if not (E and b0 and DB and DB.Get) then print("AVISO: sin build o sin base de objetos para buscar equipo") return end
  local listo = 0
  local ok, razon = E.Buscar(b0, function() listo = listo + 1 end)
  -- Después de Buscar (que carga la base): el primer pedazo choca con un objeto roto.
  local viejoGet, viejoErr = DB.Get, geterrorhandler
  local reportado = 0
  geterrorhandler = function() return function() reportado = reportado + 1 end end
  DB.Get = function() error("objeto roto") end
  T(3)
  DB.Get, geterrorhandler = viejoGet, viejoErr
  if not ok then print("AVISO: la búsqueda de equipo no arrancó en el banco: " .. tostring(razon)) return end
  if E.Ocupado() then error("la búsqueda quedó trabada en «Buscando…» tras un error") end
  if reportado == 0 then error("el error no se reportó") end
  if listo == 0 then error("la página no supo que la búsqueda terminó") end
end)

-- 11. Kit: el cuerpo de un aviso con acción del juego no la corre desde Alfa.
step("aviso: el clic en el cuerpo no corre una acción del juego", function()
  local n = 0
  local a = K.Aviso({ titulo = "Prueba", texto = "Con acción del juego",
    accion = { texto = "Abrir", alClic = function() n = n + 1 end, seguro = function() return K.AbrirJuego("talentos") end } })
  FIRE(a, "OnClick", "LeftButton")
  if n ~= 0 then error("el cuerpo del aviso corrió el clic de Alfa de una acción del juego") end
  if not a.alfaVivo then error("el aviso se cerró sin hacer nada") end
  a:Cerrar()
  local b2 = K.Aviso({ titulo = "Prueba", lya = false, accion = { texto = "Ir", alClic = function() n = n + 1 end } })
  FIRE(b2, "OnClick", "LeftButton")
  if n ~= 1 then error("el cuerpo de un aviso normal ya no hace su acción") end
end)

-- 12. Kit: en una fila de rejilla, los botones de las tarjetas a la misma altura.
step("rejilla: botones alineados en la fila", function()
  local r = K.Rejilla(caja, { min = 150, gap = 16 })
  r:SetPoint("TOPLEFT", caja, "TOPLEFT", 0, 0)
  local largo = string.rep("Un texto largo que ocupa varias líneas en su tarjeta. ", 6)
  r:Llenar({
    { icono = "ic-bolsas", titulo = "Uno", texto = "Corto.", secundaria = { texto = "Abrir", alClic = function() end } },
    { icono = "ic-manada", titulo = "Dos", texto = largo, secundaria = { texto = "Abrir", alClic = function() end } },
  })
  r:Acomodar(400)
  local t1, t2 = r.pool[1].Secundaria:GetTop(), r.pool[2].Secundaria:GetTop()
  if math.abs(t1 - t2) > 1 then error(("los botones quedan a distinta altura: %d y %d"):format(t1, t2)) end
  r:Hide()
end)

-- 13. Curación: sin buffs para otros, el preajuste es «Básico» y no se contradice.
local Cu = ns("Alfa_Curacion")
step("curación: «Básico» para una clase sin buffs, «Sin grupo»", function()
  if Cu.TieneBuffs("WARRIOR") then error("el guerrero no debería tener buffs para otros") end
  if Cu.NombrePreajuste("buffs", "WARRIOR") ~= "Básico" then error("sin buffs, «Solo buffs» no se llama Básico") end
  if Cu.NombrePreajuste("buffs", "PRIEST") ~= "Solo buffs" then error("con buffs, el preajuste debe seguir llamándose Solo buffs") end
  local d = Cu.DescripcionPreajuste("buffs")
  if d:find("no tiene buffs", 1, true) then error("el texto de Básico se contradice: " .. d) end
  if Cu.TituloPreajuste("buffs") ~= "Básico" then error("el título de la tarjeta no dice Básico") end
  -- «Desde cero» pondría los mismos clics que Básico: no se ofrece, salvo que sea el que usas.
  local d0 = Cu.Datos()
  local antes = d0.preajuste
  local function tiene(lista, x) for _, v in ipairs(lista) do if v == x then return true end end return false end
  d0.preajuste = "buffs"
  if tiene(Cu.PreajustesDe(), "cero") then error("sin buffs, se ofrece «Desde cero» (igual que Básico)") end
  d0.preajuste = "cero"
  if not tiene(Cu.PreajustesDe(), "cero") then error("quien usa «Desde cero» se quedó sin su tarjeta") end
  d0.preajuste = antes
  if not tiene(Cu.PreajustesDe("PRIEST"), "cero") then error("con buffs, «Desde cero» debe seguir") end
  if Cu.Recomendado() ~= "buffs" then error("el recomendado sin buffs debe ser Básico") end
  A.Fire("SHOW_OPTIONS", "curacion") T(2)
  local hay, viejo, asistente = false, false, false
  for _, f in ipairs(ALL_FRAMES()) do
    if f.GetText and f:IsVisible() then
      local s = f:GetText()
      if s == "Sin grupo" then hay = true end
      if s == "Configurar con el asistente" then asistente = true end
      if s == "Solo" or s == "Asistente" then viejo = s end
    end
  end
  if not hay then error("no sale la insignia «Sin grupo»") end
  if not asistente then error("no sale el botón «Configurar con el asistente»") end
  if viejo then error("sigue a la vista el texto viejo «" .. viejo .. "»") end
  -- El botón de la fila de Blizzard (el del clic seguro) dice lo que hace.
  local boton
  for _, f in ipairs(ALL_FRAMES()) do if f.alfaConSeguro and f.alfaSeguro and f:IsVisible() and f.Texto then boton = f end end
  if not boton then error("no está el botón de abrir el clic para lanzar") end
  if boton.Texto:GetText() ~= "Abrir clic para lanzar" then error("el botón de Blizzard dice: " .. tostring(boton.Texto:GetText())) end
end)

-- 14. Talentos: sin el árbol del juego, las ramas en tu idioma (no las de la foto en inglés).
local Bd2 = ns("Alfa_Builds")
step("talentos: las ramas en español sin el árbol del juego", function()
  local T = Bd2.Arbol
  local vivo = T.VivoDeFoto()
  if not vivo then print("AVISO: sin foto del árbol en el banco") return end
  local d = T.Disposicion(vivo)
  local nombres = {}
  for i, s in ipairs(d.specs) do nombres[i] = tostring(s.nombre) end
  local esperado = { "Armas", "Furia", "Protección" }
  for i, e in ipairs(esperado) do
    if nombres[i] ~= e then error("rama " .. i .. ": «" .. tostring(nombres[i]) .. "» en vez de «" .. e .. "»") end
  end
end)

step("cerrar", function() caja:Hide() local f = A.UI.Options.frame if f then f:Hide() end end)

print(("PRUEBA: %d pasos, %d errores"):format(pasos, #ERRORS))
