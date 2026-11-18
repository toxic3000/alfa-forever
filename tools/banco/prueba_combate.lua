-- Prueba de combate y barras (tools/prueba.py la corre con las demás prueba_*.lua).
--
-- * La barra de una forma vacía (Comodidades/Formas.lua): un druida en
--   Felino con su página vacía recibe el aviso una vez; "Llenar mi barra"
--   pone sus habilidades solo en las casillas vacías, nunca en combate (espera
--   a que termine), nunca con algo en el cursor ni encima de lo que ya está.
-- * El fondo de la barra principal (Comodidades/Barras.lua) no es hijo
--   directo de MainActionBar (un ResizeLayoutFrame que se mide con sus hijos).
-- * Los ajustes del juego que Combate ofrece (el resaltado oficial y el
--   registro de daño) nunca se cambian desde Alfa (ni con "/console", que
--   Blizzard corre con forceinsecure()): se dice dónde están en las opciones.
-- * AlfaBolsas.Abrir() abre la ventana de Alfa y sigue siendo la tabla de la
--   API después de crearla.
-- * El anuncio del medidor cuenta solo las filas que escribe.
SNAPSHOTS = {}
BANCO_LETRA = 0.64
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
local function ns(n) return NS_OF(n) end

---------------------------------------------------------------------------
-- El juego simulado: un druida, sus barras y su libro de hechizos
---------------------------------------------------------------------------
UnitClass = function() return "Druida", "DRUID", 11 end
UnitClassBase = function() return "DRUID", 11 end

local acciones = {}   -- casilla -> { tipo, id }
local cursor = nil    -- { tipo, id }
local offsetBarra = 0
local conocidos = { [1082] = true, [1822] = true, [5221] = true, [6807] = true, [779] = true }
local NOMBRES = { [1082] = "Garra", [1822] = "Arañazo", [5221] = "Triturar", [6807] = "Magullar", [779] = "Flagelo" }
local colocadas = 0

C_ActionBar = {
  GetBonusBarOffset = function() return offsetBarra end,
  HasAction = function(slot) return acciones[slot] ~= nil end,
  HasOverrideActionBar = function() return false end,
  HasVehicleActionBar = function() return false end,
  HasTempShapeshiftActionBar = function() return false end,
  FindSpellActionButtons = function() return {} end,
}
GetActionInfo = function(slot) local a = acciones[slot] if a then return a[1], a[2] end end
PlaceAction = function(slot)
  if InCombatLockdown() then error("PlaceAction en combate") end
  if acciones[slot] then error("PlaceAction encima de una casilla con algo (" .. slot .. ")") end
  if cursor then acciones[slot] = cursor cursor = nil colocadas = colocadas + 1 end
end
ClearCursor = function() cursor = nil end
GetCursorInfo = function() if cursor then return cursor[1], cursor[2] end end
C_Spell = {
  GetSpellName = function(id) return NOMBRES[id] end,
  PickupSpell = function(id) cursor = { "spell", id } end,
  IsSpellUsable = function() return false end,
  GetSpellTexture = function() return nil end,
}
C_SpellBook = { IsSpellKnown = function(id) return conocidos[id] == true end }
IsPlayerSpell = function(id) return conocidos[id] == true end
NUM_ACTIONBAR_PAGES = 6

-- La barra principal: un ResizeLayoutFrame con contenedores y botones (Shared/ActionBar.lua).
MainActionBar = CreateFrame("Frame", "MainActionBar", UIParent)
MainActionBar:SetSize(500, 45)
MainActionBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 10)
MainActionBar.BorderArt = MainActionBar:CreateTexture(nil, "BACKGROUND")
MainActionBar.actionButtons = {}
for i = 1, 12 do
  local c = CreateFrame("Frame", "MainActionBarButtonContainer" .. i, MainActionBar)
  c:SetSize(45, 45)
  c:SetPoint("BOTTOMLEFT", MainActionBar, "BOTTOMLEFT", (i - 1) * 47, 0)
  local b = CreateFrame("CheckButton", "ActionButton" .. i, c)
  b:SetAllPoints(c)
  b.container, b.bar, b.index, b.action = c, MainActionBar, i, i
  MainActionBar.actionButtons[i] = b
end
local function paginaEnBarra(pagina)
  for i = 1, 12 do MainActionBar.actionButtons[i].action = (pagina - 1) * 12 + i end
end

-- Ningún ajuste del juego que Combate ofrece se cambia desde Alfa.
local cvarsMal = {}
local function vigilarCVar(nombre)
  if nombre == "damageMeterEnabled" or nombre == "assistedCombatHighlight" then cvarsMal[#cvarsMal + 1] = nombre end
end
C_CVar = {
  GetCVar = function(n) if n == "assistedCombatHighlight" or n == "damageMeterEnabled" then return "0" end return "0" end,
  SetCVar = function(n) vigilarCVar(n) end,
  GetCVarBool = function() return false end,
}
SetCVar = function(n) vigilarCVar(n) end
GetCVar = function(n) return C_CVar.GetCVar(n) end
AssistedCombatManager = {}
C_AssistedCombat = { GetNextCastSpell = function() return nil end, GetRotationSpells = function() return {} end, IsAvailable = function() return true end }

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
local A, N = Alfa, AlfaNucleo
local K = N.Kit
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local Co = ns("Alfa_Comodidades")
local F = Co.Formas

---------------------------------------------------------------------------
-- 1. La barra de una forma vacía
---------------------------------------------------------------------------
step("formas: sin forma no hay aviso", function()
  if not F then error("Comodidades no publica M.Formas (Formas.lua no cargó)") end
  offsetBarra = 0
  paginaEnBarra(1)
  if F.Actual() then error("sin forma, Actual() devolvió una forma") end
end)

step("formas: Felino con la página vacía avisa una vez", function()
  offsetBarra = 1
  paginaEnBarra(7)
  local clave, pagina = F.Actual()
  if clave ~= "felino" or pagina ~= 7 then error("Felino debería ser la página 7: " .. tostring(clave) .. " " .. tostring(pagina)) end
  if F.Vacia(7) ~= true then error("la página 7 vacía no se leyó vacía") end
  FIRE_EVENT("UPDATE_BONUS_ACTIONBAR")
  T(2)
  if not F.Avisadas().felino then error("no salió el aviso de la barra de Felino vacía") end
end)

step("formas: la barra cambiada a mano no cuenta como la de la forma", function()
  paginaEnBarra(2)
  if F.Actual() then error("con la barra en la página 2, Actual() dijo que es la de la forma") end
  paginaEnBarra(7)
end)

step("formas: en combate no llena; al terminar, sí", function()
  local viejo = InCombatLockdown
  InCombatLockdown = function() return true end
  local n = F.Llenar("felino", 7)
  InCombatLockdown = viejo
  if n ~= nil then error("en combate Llenar devolvió " .. tostring(n)) end
  if colocadas ~= 0 then error("se pusieron habilidades en combate") end
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  T(1)
  if colocadas ~= 3 then error("al salir de combate debían quedar 3 habilidades (Garra, Arañazo, Triturar), quedaron " .. colocadas) end
  if not (acciones[73] and acciones[73][2] == 1082) then error("Garra no quedó en la primera casilla") end
end)

step("formas: nunca encima de lo que ya está ni con algo en el cursor", function()
  -- La barra de Oso, con una casilla ya ocupada (la piedra de hogar en la 97).
  for s = 97, 108 do acciones[s] = nil end
  acciones[97] = { "item", 6948 }
  colocadas = 0
  cursor = { "item", 1234 }
  local n = F.Llenar("oso", 9)
  if n ~= nil or colocadas ~= 0 then error("con algo en el cursor se llenó la barra") end
  cursor = nil
  n = F.Llenar("oso", 9)
  if n ~= 2 then error("debían ponerse Magullar y Flagelo, se pusieron " .. tostring(n)) end
  if not (acciones[97] and acciones[97][1] == "item") then error("se tocó la casilla que ya tenía algo") end
  if not (acciones[98] and acciones[98][2] == 6807) then error("Magullar no quedó en la primera casilla vacía") end
  -- Otra vez: lo que ya está no se repite.
  colocadas = 0
  n = F.Llenar("oso", 9)
  if n ~= 0 or colocadas ~= 0 then error("se repitieron habilidades que ya estaban en la barra") end
end)

step("formas: una página con algo no avisa; apagado no avisa", function()
  offsetBarra = 3
  paginaEnBarra(9)
  F.Revisar()
  if F.Avisadas().oso then error("avisó de la barra de Oso, que no está vacía") end
  N.Set("comodidades", "barraForma", false)
  offsetBarra = 4
  paginaEnBarra(10)
  F.Revisar()
  if F.Avisadas().lechucico then error("avisó con la opción apagada") end
  N.Set("comodidades", "barraForma", true)
  offsetBarra = 0
  paginaEnBarra(1)
end)

---------------------------------------------------------------------------
-- 2. El fondo de la barra principal no entra en su Layout()
---------------------------------------------------------------------------
step("barras: el fondo de la barra principal cuelga del contenedor de su primer botón", function()
  N.Set("comodidades", "barras", true)
  T(1)
  if Co.Barras and Co.Barras.Aplicar then Co.Barras.Aplicar() end
  local f = Co.Barras and Co.Barras.Fondos and Co.Barras.Fondos[MainActionBar]
  if not f then error("no se creó el fondo de la barra principal") end
  local padre = f.marco:GetParent()
  if padre == MainActionBar then error("el fondo es hijo directo de MainActionBar: agrandaría la barra en su Layout()") end
  if padre ~= MainActionBar.actionButtons[1].container then error("el fondo no cuelga del contenedor del primer botón") end
  N.Set("comodidades", "barras", false)
  T(1)
end)

---------------------------------------------------------------------------
-- 3. Combate: los ajustes del juego van por el clic seguro
---------------------------------------------------------------------------
local Cb = ns("Alfa_Combate")
-- Ni desde su código ni con "/console" (Blizzard lo corre con forceinsecure()):
-- el resaltado oficial y el registro de daño se cambian en las opciones del juego.
step("combate: el resaltado y el registro del juego no se cambian desde Alfa", function()
  local R, D = Cb.Rotacion, Cb.Medidor
  if not R.ResaltadoOficial() then error("el banco debería tener el resaltado oficial") end
  R.SetResaltado(true)
  R.SetResaltado(false)
  local a = D.AccionEncender()
  if a.seguro then error("Encender el registro no debe ir por un clic seguro con /console") end
  if type(a.alClic) ~= "function" then error("la acción del registro no hace nada") end
  a.alClic()
  if not tostring(D.ComoEncender()):find("Opciones", 1, true) then error("no dice dónde se enciende el registro") end
  if not tostring(R.ComoCambiarResaltado()):find("Opciones", 1, true) then error("no dice dónde se cambia el resaltado") end
  T(1)
  if #cvarsMal > 0 then error("Alfa cambió desde su código: " .. table.concat(cvarsMal, ", ")) end
end)

step("combate: la página entera con el resaltado oficial sin cambiar ajustes del juego", function()
  A.Fire("SHOW_OPTIONS", "combate") T(2)
  if not (A.UI.Options.frame and A.UI.Options.frame:IsShown()) then error("no se abrió la página de Combate") end
  -- Cada botón e interruptor a la vista: ninguno cambia un ajuste del juego.
  local lista = {}
  for _, f in ipairs(ALL_FRAMES()) do
    if f:IsVisible() and f.alfaValor ~= nil and f:GetScript("OnClick") then lista[#lista + 1] = f end
  end
  for _, f in ipairs(lista) do
    FIRE(f, "OnClick", "LeftButton")
    FIRE(f, "OnClick", "LeftButton")
  end
  T(2)
  for _, f in ipairs(ALL_FRAMES()) do
    if f.alfaConSeguro and type(f.alfaSeguro) ~= "nil" and f:IsVisible() then
      local at = type(f.alfaSeguro) == "function" and f.alfaSeguro(f) or f.alfaSeguro
      if type(at) == "table" and type(at.macrotext) == "string" and at.macrotext:find("/console", 1, true) then
        error("un botón seguro de la página corre /console: " .. at.macrotext)
      end
    end
  end
  if #cvarsMal > 0 then error("Alfa cambió desde su código: " .. table.concat(cvarsMal, ", ")) end
  if A.UI.Options.frame then A.UI.Options.frame:Hide() end
end)

step("combate: el anuncio del medidor cuenta solo las filas que escribe", function()
  local D = Cb.Medidor
  local enviados = {}
  local viejoLeer, viejoPuede = D.Leer, D.PuedeAnunciar
  local viejoGrupo, viejoChat = IsInGroup, C_ChatInfo
  IsInGroup = function() return true end
  C_ChatInfo = { SendChatMessage = function(m) enviados[#enviados + 1] = m end }
  D.PuedeAnunciar = function() return true end
  D.Leer = function()
    return { ok = true, tipo = { texto = "DPS", porSeg = true }, dur = 30, filas = {
      { pos = 1, nombre = "Uno", valor = 1000, porSeg = 33 },
      { pos = 2, nombre = "Dos", valor = 900, porSeg = 30 },
      { pos = 9, nombre = "Lobato", valor = 100, porSeg = 3, yo = true, aparte = true },
    } }
  end
  local ok, err = pcall(D.Anunciar, "actual", "dps")
  D.Leer, D.PuedeAnunciar, IsInGroup, C_ChatInfo = viejoLeer, viejoPuede, viejoGrupo, viejoChat
  if not ok then error(err) end
  if #enviados ~= 3 then error("debían salir 3 líneas (título y 2 filas), salieron " .. #enviados) end
  if not tostring(enviados[1]):find("Top 2", 1, true) then error("el título no dice Top 2: " .. tostring(enviados[1])) end
end)

---------------------------------------------------------------------------
-- 4. AlfaBolsas.Abrir
---------------------------------------------------------------------------
step("bolsas: AlfaBolsas.Abrir abre la ventana de Alfa y sigue siendo la API", function()
  if type(AlfaBolsas) ~= "table" or type(AlfaBolsas.Abrir) ~= "function" then error("no existe AlfaBolsas.Abrir") end
  if AlfaBolsas.Abrir() ~= true then error("con las bolsas de Alfa, Abrir() no devolvió true") end
  T(1)
  local v = _G.AlfaBolsasVentana
  if not (v and v:IsShown()) then error("no se abrió la ventana de bolsas de Alfa") end
  if type(AlfaBolsas.Abrir) ~= "function" then error("al crear la ventana se perdió AlfaBolsas.Abrir") end
  v:Hide()
  N.Set("bolsas", "reemplazar", false)
  T(1)
  if AlfaBolsas.Abrir() ~= false then error("con las bolsas de Alfa apagadas, Abrir() no devolvió false") end
  if AlfaBolsas.Activas() ~= false then error("Activas() no dice que están apagadas") end
  N.Set("bolsas", "reemplazar", true)
  T(1)
end)

---------------------------------------------------------------------------
-- 5. Comercio: borrar los precios no olvida la espera del escaneo
---------------------------------------------------------------------------
step("comercio: Olvidar deja la espera del escaneo completo", function()
  local Cm = ns("Alfa_Comercio")
  if not (Cm.Reino and Cm.Olvidar) then return end
  local r = Cm.Reino()
  r.pedido = Cm.Ahora()
  Cm.Olvidar()
  if Cm.Reino().pedido ~= r.pedido then error("Olvidar borró la espera del escaneo (pedido)") end
end)

---------------------------------------------------------------------------
-- 6. En combate nadie queda atrapado: diálogos con velo y la bienvenida
---------------------------------------------------------------------------
local function enCombate(fn)
  local viejo = InCombatLockdown
  InCombatLockdown = function() return true end
  local ok, e = pcall(fn)
  InCombatLockdown = viejo
  if not ok then error(e, 0) end
end

step("diálogo: se esconde al empezar un combate y vuelve al terminar", function()
  local acepto, cancelo = 0, 0
  local d = K.Dialogo({ titulo = "¿Probamos?", texto = "Una pregunta de prueba.",
    alAceptar = function() acepto = acepto + 1 end, alCancelar = function() cancelo = cancelo + 1 end })
  local velo = _G.AlfaKitVelo
  if not (velo and velo:IsShown()) then error("el diálogo no se abrió") end
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  if velo:IsShown() then error("el velo del diálogo siguió tomando el ratón al empezar el combate") end
  if cancelo ~= 0 then error("esconderlo por el combate lo dio por cancelado") end
  if not K.DialogoAbierto() then error("K.DialogoAbierto() no cuenta el diálogo que espera al combate") end
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  if not velo:IsShown() then error("el diálogo no volvió al terminar el combate") end
  FIRE(d.Aceptar, "OnClick", "LeftButton")
  if acepto ~= 1 or cancelo ~= 0 then error("la respuesta no llegó una sola vez (aceptar " .. acepto .. ", cancelar " .. cancelo .. ")") end
end)

step("diálogo: pedido en combate sale al terminar; cerrarlo mientras espera lo cancela", function()
  local cancelo = 0
  enCombate(function() K.Dialogo({ titulo = "En plena pelea", alCancelar = function() cancelo = cancelo + 1 end }) end)
  local velo = _G.AlfaKitVelo
  if velo:IsShown() then error("un diálogo pedido en combate se mostró en combate") end
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  if not velo:IsShown() then error("el diálogo pedido en combate no salió al terminar") end
  velo:Hide()
  if cancelo ~= 1 then error("cerrarlo no lo dio por cancelado") end
  enCombate(function() K.Dialogo({ titulo = "Otra", alCancelar = function() cancelo = cancelo + 1 end }) end)
  K.CerrarDialogo()
  if cancelo ~= 2 then error("cerrar el que esperaba al combate no lo dio por cancelado") end
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  if velo:IsShown() then error("un diálogo cerrado volvió al terminar el combate") end
end)

step("bienvenida: el asistente a pantalla completa se esconde en combate y vuelve", function()
  local Bv = ns("Alfa_Bienvenida")
  if not (Bv.AbrirVentana and Bv.EsperaCombate) then error("la bienvenida no publica AbrirVentana/EsperaCombate") end
  local pendiente = Bv.Pendiente
  Bv.Pendiente = function() return false end -- sin la intro del lobo
  local cerrados = 0
  local h = A.On("WELCOME_CLOSED", function() cerrados = cerrados + 1 end)
  local ok, err = pcall(function()
    Bv.AbrirVentana("asistente")
    T(1)
    local v = _G.AlfaBienvenidaVentana
    if not (v and v:IsShown()) then error("no se abrió el asistente") end
    local velo = v.alfaVelo
    if not (velo and velo:IsShown()) then error("el asistente no puso su velo") end
    FIRE_EVENT("PLAYER_REGEN_DISABLED")
    if v:IsShown() or velo:IsShown() then error("el asistente siguió a pantalla completa al empezar el combate") end
    if not Bv.EsperaCombate() then error("el asistente no quedó esperando el fin del combate") end
    if cerrados ~= 0 then error("esconderlo por el combate contó como cerrar la bienvenida") end
    FIRE_EVENT("PLAYER_REGEN_ENABLED")
    T(3)
    if not v:IsShown() then error("el asistente no volvió al terminar el combate") end
    if Bv.EsperaCombate() then error("el asistente siguió esperando tras volver") end
    v:Hide()
  end)
  Bv.Pendiente = pendiente
  if A.Off then A.Off(h) end
  if not ok then error(err, 0) end
end)

---------------------------------------------------------------------------
-- 7. Recolección: la ruta es de una profesión que tienes
---------------------------------------------------------------------------
step("recolección: la ruta usa la profesión de recolección que tienes", function()
  local Rc = ns("Alfa_Recoleccion").R
  if not (Rc and Rc.TipoRuta) then error("Recolección no publica R.TipoRuta") end
  local listas, habilidad = Rc.HabilidadesListas, Rc.Habilidad
  local tengo = {}
  Rc.HabilidadesListas = function() return true end
  Rc.Habilidad = function(t) return tengo[t] end
  local ok, err = pcall(function()
    tengo = { hierbas = 75 }
    if Rc.TipoRuta() ~= "hierbas" then error("con Herboristería y sin Minería propuso " .. tostring(Rc.TipoRuta())) end
    tengo = {}
    if Rc.TipoRuta() ~= nil then error("sin profesión de recolección propuso " .. tostring(Rc.TipoRuta())) end
    N.Set("recoleccion", "rutaTipo", "tesoros")
    if Rc.TipoRuta() ~= "tesoros" then error("lo que elegiste en Tipo no mandó") end
    N.Set("recoleccion", "rutaTipo", "auto")
  end)
  Rc.HabilidadesListas, Rc.Habilidad = listas, habilidad
  if not ok then error(err, 0) end
end)

print("PRUEBA: combate y barras, " .. pasos .. " pasos")
