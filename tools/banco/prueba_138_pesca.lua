-- Prueba de la 1.3.8, Pesca (tools/prueba.py la corre con las demás):
--   1. La ventana de antes de pescar: no sale con una caña y sin cebos; sale
--      con dos cañas y un cebo; elegir caña, cebo y barra (vertical, sin un
--      botón) se guarda por personaje y lo usa tu tecla; «No volver a
--      preguntar»; nunca en combate; «A pescar» te pone la caña elegida.
--   2. «A pelear» / «Volver a mi equipo»: te ataca un enemigo o un jugador
--      (el aviso al instante, prioridad 1, con la tecla), en plena pelea (sin
--      SetAttribute), sin la barra (el botón sale solo), escudo en la mano
--      izquierda, arma de dos manos (no se pone la otra mano), varita en la
--      ranura 18, cambiaste de armas mientras pescabas, el arma que vendiste.
--   3. Tamaños: estables, creíbles por especie, trofeos por su nombre, nada
--      para un cofre; «32 cm» / «4,2 kg» en español, pulgadas y libras en inglés.
--   4. Récords por pez y por zona («¡Nuevo récord!»), el nivel de pescador,
--      el pez de la semana (igual para la facción, premio al sacar 5), la
--      sesión con su tamaño total y su mejor captura.
--   5. La tabla de La Jauría: apagada no manda ni guarda; prendida guarda lo
--      de tu facción, ignora lo de la otra y lo mal formado, responde a «Q».
--   6. Capturas: la ventana previa, el diario con tamaños, el pescador, las
--      sesiones y la tabla.
SNAPSHOTS = {}
BANCO_LETRA = 0.64 -- (como prueba.lua y las galerías: el banco mide las letras a ojo)
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[name] = { entries = entries, l = l, b = b, w = w, h = h }
end
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
local function check(cond, msg) if not cond then NOTE("1.3.8 pesca", msg) end end
local function T(n) RUN_TIMERS(n or 3) end

---------------------------------------------------------------------------
-- El juego simulado: cañas, armas, un cebo, bolsas
---------------------------------------------------------------------------
local CANA, CANA2, ESPADA, ESPADA2, ESCUDO, MANDOBLE, VARITA, GORRO, CEBO = 6256, 6365, 25, 2131, 2129, 2132, 5069, 1000, 6530
local NOMBRES = { [CANA] = "Caña de pescar", [CANA2] = "Caña robusta", [ESPADA] = "Espada corta", [ESPADA2] = "Espada nueva",
  [ESCUDO] = "Escudo", [MANDOBLE] = "Mandoble", [VARITA] = "Varita chispeante", [GORRO] = "Gorro", [CEBO] = "Lombrices",
  [6289] = "Pargo de barro crudo", [6292] = "Pargo de barro de 10 libras", [6351] = "Cofre del agua", [6358] = "Boca negra aceitosa" }
local function enlace(id) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. (NOMBRES[id] or ("#" .. id)) .. "]|h|r" end
local INFO = {
  [CANA] = { "INVTYPE_2HWEAPON", 2, 20 }, [CANA2] = { "INVTYPE_2HWEAPON", 2, 20 }, [ESPADA] = { "INVTYPE_WEAPON", 2, 7 },
  [ESPADA2] = { "INVTYPE_WEAPON", 2, 7 }, [ESCUDO] = { "INVTYPE_SHIELD", 4, 6 }, [MANDOBLE] = { "INVTYPE_2HWEAPON", 2, 8 },
  [VARITA] = { "INVTYPE_RANGEDRIGHT", 2, 19 }, [GORRO] = { "INVTYPE_HEAD", 4, 1 }, [CEBO] = { "", 0, 8 },
  [6289] = { "", 0, 0 }, [6292] = { "", 0, 0 }, [6351] = { "", 15, 0 }, [6358] = { "", 7, 8 },
}
Enum.ItemClass = { Weapon = 2, Armor = 4, Consumable = 0 }
Enum.ItemWeaponSubclass = { Fishingpole = 20 }
C_Item.GetItemInfoInstant = function(x)
  local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)"))
  local i = id and INFO[id]
  if not i then return nil end
  return id, "", "", i[1], 134400 + id % 50, i[2], i[3]
end
C_Item.GetItemNameByID = function(id) return NOMBRES[id] end
local puesto = { [16] = enlace(CANA) }
GetInventoryItemLink = function(_, r) return puesto[r] end
GetInventoryItemID = function(_, r) local l = puesto[r] return l and tonumber(l:match("item:(%d+)")) end
local bolsa = {}   -- ranura -> { id, n, bono }
local function enBolsa(id, n, bono)
  for s = 1, 16 do if not bolsa[s] then bolsa[s] = { id = id, n = n or 1, bono = bono } return s end end
end
local function sacarDeBolsa(id)
  for s = 1, 16 do if bolsa[s] and bolsa[s].id == id then bolsa[s] = nil return true end end
end
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end
C_Container.GetContainerItemLink = function(b, s) local i = b == 0 and bolsa[s] return i and enlace(i.id) or nil end
C_Item.GetItemCount = function(id)
  local n = 0
  for s = 1, 16 do if bolsa[s] and bolsa[s].id == id then n = n + bolsa[s].n end end
  return n
end
-- La bonificación de pesca sale de la descripción (Equipo.lua).
C_TooltipInfo = C_TooltipInfo or {}
C_TooltipInfo.GetBagItem = function(b, s)
  local i = b == 0 and bolsa[s]
  if i and i.bono then return { lines = { { leftText = "Equipado: Pesca aumentada en +" .. i.bono .. "." } } } end
  return { lines = {} }
end
C_TooltipInfo.GetInventoryItem = function() return { lines = {} } end
local equipados = {}
local combate = false
InCombatLockdown = function() return combate end
C_Item.EquipItemByName = function(l, r)
  equipados[#equipados + 1] = { l, r }
  if combate and r ~= 16 and r ~= 17 and r ~= 18 then NOTE("1.3.8 pesca", "se pidió armadura en combate: ranura " .. tostring(r)) end
  local id = tonumber(tostring(l):match("item:(%d+)"))
  if id then sacarDeBolsa(id) end
  if puesto[r] then local viejo = tonumber(puesto[r]:match("item:(%d+)")) if viejo then enBolsa(viejo) end end
  puesto[r] = l
end
local teclaPelear = nil
GetBindingKey = function(a) if a == "CLICK AlfaPescaPelear:LeftButton" then return teclaPelear end return nil end

FIRE_EVENT("PLAYER_LOGIN")
do
  local B = rawget(_G, "AlfaBienvenida")
  AlfaNucleo.Datos("bienvenida").respondio = B and B.VERSION or 99
  AlfaNucleo.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
  AlfaNucleo.Datos("bienvenida").recorrido = true
end
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end

local P = NS_OF("Alfa_Pesca")
local N = AlfaNucleo
local Eq, Pe, E, Pv, Pz, J = P.Eq, P.Pelear, P.E, P.Previa, P.Pez, P.Jauria
check(Eq and Pe and E and Pv and Pz and J, "faltan piezas de la pesca 1.3.8 (Previa, Pescador, Jauría)")
if not (Eq and Pe and E and Pv and Pz and J) then print(string.format("PRUEBA: 1.3.8 pesca, %d pasos, %d errores", pasos, #ERRORS)) return end

local avisos = {}
local aviso = N.Kit.Aviso
N.Kit.Aviso = function(o) avisos[#avisos + 1] = o return aviso(o) end
local function ultimoAviso(id)
  for i = #avisos, 1, -1 do if avisos[i].id == id then return avisos[i] end end
  return nil
end
local boton = rawget(_G, "AlfaPescaPelear")
local enCombateAttr = {}
local setAttr = boton.SetAttribute
boton.SetAttribute = function(self, k, v)
  if InCombatLockdown() then enCombateAttr[#enCombateAttr + 1] = k end
  return setAttr(self, k, v)
end
local function previaVisible() local v = rawget(_G, "AlfaPescaPrevia") return v ~= nil and v:IsShown() end
local function cerrarTodo()
  if P.Modo() then P.CerrarModo() end
  Pv.Cerrar()
  T(5)
end
N.Set("pesca", "restaurarEquipo", false)

---------------------------------------------------------------------------
-- 1. La ventana de antes de pescar
---------------------------------------------------------------------------
step("previa: una caña y ningún cebo no pregunta", function()
  check(not Pv.HayQueElegir(), "con una caña y sin cebos dice que hay que elegir")
  P.AbrirModo()
  T(5)
  check(P.Modo(), "el modo no se abrió")
  check(not previaVisible(), "salió la ventana previa con una sola caña y ningún cebo")
  cerrarTodo()
end)

step("previa: dos cañas y un cebo, elegir y recordar", function()
  enBolsa(CANA2, 1, 20)
  enBolsa(CEBO, 12)
  Eq.Marcar()
  check(Pv.HayQueElegir(), "con dos cañas y un cebo no pregunta")
  P.AbrirModo()
  T(5)
  check(previaVisible(), "no salió la ventana de antes de pescar")
  local ui = Pv.UI()
  check(ui and ui.canas and ui.cebos, "la ventana no tiene sus partes")
  -- Las cañas: «La mejor que tengas», la robusta (+20) y la puesta.
  local cartas = ui.canas.pool
  local robusta
  for _, c in ipairs(cartas) do
    local d = c.alfaDatos
    if d and d.titulo == "Caña robusta" then robusta = c end
  end
  check(robusta, "no está la caña robusta en la lista")
  check(robusta and tostring(robusta.alfaDatos.texto):find("+20", 1, true), "la caña no dice su bonificación")
  local base = nil
  for _, c in ipairs(cartas) do if c.alfaDatos and c.alfaDatos.titulo == "Caña de pescar" then base = c end end
  check(base and tostring(base.alfaDatos.texto):find("puesta", 1, true), "la caña puesta no dice «puesta»")
  -- Elegir la de pescar (la puesta, sin bono): la tecla ya no te cambia a la robusta.
  base:GetScript("OnClick")(base, "LeftButton")
  check(Eq.CanaElegida() == CANA, "no se guardó la caña elegida")
  local cambia = false
  for _, c in ipairs(Eq.MejorEquipo()) do if c.ranura == 16 then cambia = true end end
  check(not cambia, "con la caña elegida puesta, tu tecla te quiere poner otra")
  -- El cebo: las lombrices con su bonificación y cuántas.
  local lomb
  for _, c in ipairs(ui.cebos.pool) do if c.alfaDatos and c.alfaDatos.titulo == "Lombrices" then lomb = c end end
  check(lomb and tostring(lomb.alfaDatos.texto):find("12", 1, true), "el cebo no dice cuántos tienes")
  lomb:GetScript("OnClick")(lomb, "LeftButton")
  check(Eq.CeboElegido() == CEBO, "no se guardó el cebo elegido: " .. tostring(Eq.CeboElegido()))
  check(N.Get("pesca", "ceboPreferido") == 0, "el cebo elegido cambió el ajuste de toda la cuenta")
  SNAP("138-pesca-previa", Pv.Ventana())
  -- La barra: sin «como la tienes ahora», vertical y sin el botón de cocina.
  ui.comoAhora.Interruptor:GetScript("OnClick")(ui.comoAhora.Interruptor)
  check(Pv.Barra("barraVertical") == false, "al elegir la barra no queda horizontal")
  ui.vista.alCambiar("vertical")
  for _, b in ipairs(ui.botones.botones) do if b.alfaId == "cocina" then b:GetScript("OnClick")(b, "LeftButton") end end
  check(Pv.Ocultos().cocina, "no se escondió el botón de cocina")
  check(N.Get("pesca", "barraVertical") == false, "la barra elegida cambió el ajuste de la cuenta")
  T(3)
  SNAP("138-pesca-previa-barra", Pv.Ventana())
  local barra = P.Barra.Barra()
  P.Barra.Desplegar()
  P.Barra.Acomodar()
  check(barra and math.abs(barra:GetWidth() - 204) < 1, "la barra no quedó vertical: " .. tostring(barra and barra:GetWidth()))
  for _, b in ipairs(barra.botones) do
    if b.alfaId == "cocina" then check(not b:IsShown(), "el botón de cocina se sigue viendo") end
    if b.alfaId == "cerrar" then check(b:IsShown(), "el botón de cerrar se escondió") end
  end
  -- «A pescar»: elige la robusta y tu clic te la pone.
  robusta:GetScript("OnClick")(robusta, "LeftButton")
  equipados = {}
  ui.aPescar:GetScript("OnClick")(ui.aPescar, "LeftButton")
  check(not previaVisible(), "«A pescar» no cerró la ventana")
  check(#equipados == 1 and equipados[1][2] == 16 and tostring(equipados[1][1]):find("Caña robusta", 1, true), "«A pescar» no te puso la caña elegida")
  cerrarTodo()
end)

step("previa: no volver a preguntar, a mano y nunca en combate", function()
  Eq.Eleccion().noPreguntar = true
  P.AbrirModo()
  T(5)
  check(not previaVisible(), "salió aunque pediste no volver a preguntar")
  check(Pv.Abrir(true) and previaVisible(), "no se abre a mano (clic derecho de la barra o Ajustes)")
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  combate = true
  check(not previaVisible(), "al empezar la pelea la ventana siguió abierta")
  check(not Pv.Abrir(true), "se abrió en combate")
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  T(5)
  Eq.Eleccion().noPreguntar = nil
  -- Tras un /reload con el modo abierto no pregunta otra vez.
  cerrarTodo()
  N.DatosPersonaje("pesca").modo = true
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
  T(5)
  check(P.Modo(), "tras recargar el modo no siguió abierto")
  check(not previaVisible(), "tras recargar volvió a preguntar")
  -- La barra vuelve a como la tenías (para lo que sigue).
  Eq.Eleccion().barra = nil
  cerrarTodo()
end)

---------------------------------------------------------------------------
-- 2. A pelear / Volver a mi equipo
---------------------------------------------------------------------------
local function normal(t)
  local d = N.DatosPersonaje("pesca")
  d.equipoNormal = {}
  for r, id in pairs(t) do d.equipoNormal[r] = enlace(id) end
end
local function pelea(fn)
  NOW = NOW + 60 -- (el aviso sale una vez cada 30 s)
  enCombateAttr = {}
  avisos = {}
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  combate = true
  T(2)
  if fn then fn() end
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  T(8)
end

step("te ataca un enemigo: el aviso al instante con tu tecla", function()
  puesto[16], puesto[17], puesto[18] = enlace(CANA), nil, nil
  enBolsa(ESPADA) enBolsa(ESCUDO)
  normal({ [16] = ESPADA, [17] = ESCUDO })
  teclaPelear = "F"
  P.AbrirModo()
  T(5)
  Pv.Cerrar()
  local macro = boton:GetAttribute("macrotext") or ""
  check(macro:find("/equipslot 16 Espada corta", 1, true) and macro:find("/equipslot 17 Escudo", 1, true), "la macro no trae espada y escudo: " .. macro)
  pelea(function()
    local a = ultimoAviso("pesca.atacan")
    check(a, "no salió el aviso de «te atacan»")
    check(a and a.prioridad == 1 and a.lya == false, "el aviso no es urgente ni sale como aviso propio")
    check(a and tostring(a.texto):find("F", 1, true), "el aviso no dice tu tecla: " .. tostring(a and a.texto))
    check(Pe.Estado() == "armas", "en combate no está listo: " .. tostring(Pe.Estado()))
    -- En plena pelea, unos segundos después: la macro (el juego) y PostClick.
    T(5)
    puesto[16], puesto[17] = enlace(ESPADA), enlace(ESCUDO)
    sacarDeBolsa(ESPADA) sacarDeBolsa(ESCUDO) enBolsa(CANA)
    FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 16)
    FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 17)
    equipados = {}
    boton:GetScript("PostClick")(boton, "LeftButton", false)
    T(3)
    check(#equipados == 0, "en combate se pidió equipo por código")
    check(#enCombateAttr == 0, "SetAttribute en combate: " .. table.concat(enCombateAttr, ", "))
  end)
  check(not P.Modo(), "al salir de la pelea el modo pesca siguió abierto")
  teclaPelear = nil
end)

step("te ataca un jugador sin la barra a la vista: el botón sale solo", function()
  sacarDeBolsa(CANA)
  puesto[16], puesto[17] = enlace(CANA), nil
  enBolsa(ESPADA) enBolsa(ESCUDO)
  normal({ [16] = ESPADA, [17] = ESCUDO })
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 16)
  T(3)
  if P.Modo() then P.CerrarModo() T(3) end
  Pv.Cerrar()
  check(not boton:IsShown(), "sin el modo, el botón ya se veía antes de la pelea")
  -- (UnitIsPlayer del atacante no cambia nada: la pelea empieza igual)
  pelea(function()
    check(boton:IsShown(), "sin la barra, el botón no salió solo al empezar la pelea")
    local a = ultimoAviso("pesca.atacan")
    check(a and tostring(a.texto):find("abajo, al centro", 1, true), "el aviso no dice dónde salió la espada: " .. tostring(a and a.texto))
    check(Pe.Estado() == "armas", "sin la barra, en combate no está listo")
  end)
  check(not boton:IsShown(), "al terminar la pelea el botón suelto se quedó")
end)

step("arma de dos manos: no se pone la otra mano", function()
  sacarDeBolsa(ESPADA) sacarDeBolsa(ESCUDO)
  puesto[16], puesto[17] = enlace(CANA), nil
  enBolsa(MANDOBLE) enBolsa(ESCUDO)
  normal({ [16] = MANDOBLE, [17] = ESCUDO })
  Pe.Armar()
  local macro = boton:GetAttribute("macrotext") or ""
  check(macro:find("/equipslot 16 Mandoble", 1, true), "la macro no pone el mandoble: " .. macro)
  check(not macro:find("/equipslot 17", 1, true), "con un arma de dos manos la macro pone la otra mano: " .. macro)
  equipados = {}
  Eq.Restaurar()
  T(5)
  for _, x in ipairs(equipados) do check(x[2] ~= 17, "Restaurar puso la otra mano encima del mandoble") end
end)

step("varita en la ranura 18", function()
  puesto[16], puesto[17], puesto[18] = enlace(CANA), nil, nil
  sacarDeBolsa(MANDOBLE)
  enBolsa(ESPADA) enBolsa(VARITA)
  normal({ [16] = ESPADA, [18] = VARITA })
  Pe.Armar()
  local macro = boton:GetAttribute("macrotext") or ""
  check(macro:find("/equipslot 18 Varita chispeante", 1, true), "la macro no pone la varita: " .. macro)
  -- La foto también recuerda la ranura 18 si se quita con la caña puesta.
  N.DatosPersonaje("pesca").equipoNormal = {}
  puesto[18] = enlace(VARITA)
  Eq.Foto()
  puesto[18] = nil
  Eq.AlCambiar(18)
  check(Eq.Normal()[18] == enlace(VARITA), "la varita que se quitó con la caña puesta no se recordó")
end)

step("cambiaste de armas mientras pescabas", function()
  N.DatosPersonaje("pesca").equipoNormal = {}
  bolsa = {}
  puesto = { [16] = enlace(ESPADA), [17] = enlace(ESCUDO) }
  enBolsa(CANA) enBolsa(ESPADA2)
  Eq.Foto()
  -- Te pones la caña: se recuerdan la espada y el escudo.
  puesto[16], puesto[17] = enlace(CANA), nil
  Eq.AlCambiar(16) Eq.AlCambiar(17)
  check(Eq.Normal()[16] == enlace(ESPADA) and Eq.Normal()[17] == enlace(ESCUDO), "no recordó espada y escudo")
  -- Te pones la espada nueva a mano y luego otra vez la caña.
  puesto[16] = enlace(ESPADA2)
  Eq.AlCambiar(16)
  puesto[16] = enlace(CANA)
  Eq.AlCambiar(16)
  check(Eq.Normal()[16] == enlace(ESPADA2), "no se quedó con la espada nueva: " .. tostring(Eq.Normal()[16]))
  Pe.Armar()
  local macro = boton:GetAttribute("macrotext") or ""
  check(macro:find("Espada nueva", 1, true) and not macro:find("Espada corta", 1, true), "la macro trae la espada vieja: " .. macro)
  -- El escudo que vendiste ya no va en la macro.
  check(not macro:find("Escudo", 1, true), "la macro trae el escudo que ya no tienes: " .. macro)
end)

---------------------------------------------------------------------------
-- 3. Tamaños
---------------------------------------------------------------------------
step("tamaños: estables, creíbles y en tu idioma", function()
  local a = Pz.Tamano(6289, "pez", "yo:1:6289:1", 100)
  local b = Pz.Tamano(6289, "pez", "yo:1:6289:1", 100)
  check(a and b and a.mm == b.mm and a.g == b.g, "el mismo pez no da el mismo tamaño")
  local min, max, suma, n = 1e9, 0, 0, 0
  for i = 1, 400 do
    local t = Pz.Tamano(6289, "pez", "yo:" .. i, 100)
    min, max, suma, n = math.min(min, t.mm), math.max(max, t.mm), suma + t.mm, n + 1
  end
  local media = suma / n / 10
  check(media > 30 and media < 40, "el pargo no mide lo creíble: media " .. media)
  check(min > 150 and max < 700, "tamaños fuera de lo creíble: " .. min .. " a " .. max)
  local trofeo = Pz.Tamano(6292, "trofeo", "yo:1", 200, "Pargo de barro de 10 libras")
  check(trofeo and trofeo.g > 3000 and trofeo.g < 7000, "el trofeo de 10 libras no pesa eso: " .. tostring(trofeo and trofeo.g))
  check(Pz.Tamano(6351, "botin", "yo:1", 100) == nil, "un cofre tiene tamaño")
  check(Pz.Largo(320) == "32 cm", "el largo dice " .. Pz.Largo(320))
  check(Pz.Peso(4200) == "4,2 kg", "el peso dice " .. Pz.Peso(4200))
  check(Pz.Peso(350) == "350 g", "un pez chico dice " .. Pz.Peso(350))
  local loc, idi = GetLocale, rawget(_G, "AlfaIdioma")
  GetLocale = function() return "enUS" end
  AlfaIdioma = GetLocale
  check(Pz.Peso(4536) == "10.0 lb", "en inglés el peso dice " .. Pz.Peso(4536))
  check(Pz.Largo(254) == "10.0 in", "en inglés el largo dice " .. Pz.Largo(254))
  GetLocale = function() return "deDE" end
  AlfaIdioma = GetLocale
  check(Pz.Peso(4200) == "4,2 kg", "en alemán no lleva coma: " .. Pz.Peso(4200))
  GetLocale, AlfaIdioma = loc, idi
end)

---------------------------------------------------------------------------
-- 4. Récords, nivel, pez de la semana y sesión
---------------------------------------------------------------------------
step("récords, nivel, semana y sesión", function()
  P.NuevaSesion()
  local antes = Pz.Datos().xp
  local hubo = false
  local nivel0 = Pz.Nivel(antes)
  for i = 1, 40 do
    local nuevo = P.R.Captura({ { id = 6289, nombre = "Pargo de barro crudo", cantidad = 1, calidad = 1 } }, {})
    if nuevo[1].record == "pez" then hubo = true end
    check(nuevo[1].tam and nuevo[1].tam.mm, "la captura no trae su tamaño")
  end
  check(hubo, "en 40 capturas nunca hubo «¡Nuevo récord!»")
  local r = Pz.Record(6289)
  check(r and r.g > 0 and r.z, "no quedó el récord del pargo con su zona")
  check(#Pz.RecordsDe(6289) >= 1, "no hay récord por zona")
  local p = Pz.Datos()
  check(p.xp >= antes + 400, "la experiencia no subió: " .. tostring(p.xp - antes))
  check(Pz.Nivel(p.xp) > nivel0, "no subiste de nivel de pescador")
  check(ultimoAviso("pesca.nivel"), "no avisó el nivel nuevo")
  -- Un cofre no tiene tamaño pero da experiencia.
  local x = P.R.Captura({ { id = 6351, nombre = "Cofre del agua", cantidad = 1 } }, {})
  check(x[1].tam == nil and (x[1].xp or 0) > 0, "el cofre trae tamaño o no da experiencia")
  -- El pez de la semana: el mismo para la misma facción y semana.
  local s1, s2 = Pz.Semana(), Pz.Semana()
  check(s1 and s2 and s1.id == s2.id and #s1.mapas > 0, "el pez de la semana no es estable o no dice dónde")
  local otra = Pz.Semana(GetServerTime() + 7 * 86400)
  check(otra and otra.semana == s1.semana + 1, "la semana siguiente no cambia de número")
  local xp0 = Pz.Datos().xp
  avisos = {}
  for i = 1, 5 do P.R.Captura({ { id = s1.id, nombre = "Pez de la semana", cantidad = 1 } }, {}) end
  check(Pz.Semana().premiado, "sacar 5 del pez de la semana no dio el premio")
  check(Pz.Datos().xp - xp0 >= Pz.XP.premioSemana, "el premio no sumó su experiencia")
  check(ultimoAviso("pesca.semana"), "no avisó el pez de la semana cumplido")
  -- La sesión: tamaño total y la mejor; al cerrarse pasa al historial con eso.
  local s = P.Sesion()
  check(s.peso > 0 and type(s.mejor) == "table" and s.mejor.g > 0, "la sesión no lleva su tamaño ni su mejor captura")
  P.Sesion().lanzamientos = 50
  P.Sesion().activo = 1800
  P.NuevaSesion()
  local h = P.Historial()[1]
  check(h and h.peso > 0 and h.mejor and h.mejor.g > 0, "la sesión del historial no trae tamaño ni mejor captura")
end)

step("el nivel empieza con tu diario de antes", function()
  local d = N.DatosPersonaje("pesca")
  local guardado = d.pescador
  d.pescador = nil
  local p = Pz.Datos()
  check(p.xp > 0, "quien ya pescaba empieza en cero")
  d.pescador = guardado
end)

---------------------------------------------------------------------------
-- 5. La tabla de La Jauría
---------------------------------------------------------------------------
step("la tabla de La Jauría", function()
  local enviados = {}
  AlfaManada = AlfaManada or {}
  local red = AlfaManada.Red
  local envia = red and red.EnviarHermandad
  if red then red.EnviarHermandad = function(clave, tipo, texto) enviados[#enviados + 1] = { clave, tipo, texto } return true end end
  IsInGuild = function() return true end
  N.Set("pesca", "jauria", false)
  T(2)
  enviados = {}
  local okCampos = { "D", "1", "H", "12", "5400", "7", "20", "6289", "4200", Pz.Temporada(), "900", "3" }
  J.AlMensaje("Pelusa-Reino", "Pelusa-Reino", okCampos, "GUILD")
  check(next(J.Tabla()) == nil, "apagada, guardó lo que llegó")
  check(not J.Enviar() and #enviados == 0, "apagada, mandó algo")
  N.Set("pesca", "jauria", true)
  T(2)
  check(#enviados >= 1, "al prenderla no mandó lo tuyo")
  local tuyo
  for _, x in ipairs(enviados) do if x[1] == "pesca.tabla" then tuyo = x end end
  check(tuyo and tuyo[2] == "p" and tuyo[3]:match("^D|1|[AH]|%d+|"), "lo tuyo no va con su tipo y su forma: " .. tostring(tuyo and tuyo[3]))
  J.AlMensaje("Pelusa-Reino", "Pelusa-Reino", okCampos, "GUILD")
  check(J.Tabla()["Pelusa-Reino"] and J.Tabla()["Pelusa-Reino"].nivel == 12, "no guardó a un lobo de tu facción")
  local otra = { "D", "1", "A", "30", "99999", "40", "60", "6292", "8000", Pz.Temporada(), "5000", "9" }
  J.AlMensaje("Otro-Reino", "Otro-Reino", otra, "GUILD")
  check(J.Tabla()["Otro-Reino"] == nil, "guardó a alguien de la otra facción")
  J.AlMensaje("Malo-Reino", "Malo-Reino", { "D", "1", "H", "nan", "1", "1", "1", "1", "1", "202611", "1", "1" }, "GUILD")
  check(J.Tabla()["Malo-Reino"] == nil, "guardó un mensaje mal formado")
  J.AlMensaje("Susurro-Reino", "Susurro-Reino", okCampos, "WHISPER")
  check(J.Tabla()["Susurro-Reino"] == nil, "guardó algo que llegó por susurro")
  enviados = {}
  J.AlMensaje("Pelusa-Reino", "Pelusa-Reino", { "Q" }, "GUILD")
  T(15)
  check(#enviados == 1, "no respondió a «Q» (o respondió de más): " .. #enviados)
  J.AlMensaje("Pelusa-Reino", "Pelusa-Reino", { "Q" }, "GUILD")
  T(15)
  check(#enviados == 1, "respondió dos veces seguidas a «Q»")
  local lista = J.Lista("nivel")
  check(#lista == 2 and lista[1].nivel >= lista[2].nivel, "la tabla no queda en orden")
  if red then red.EnviarHermandad = envia end
end)

---------------------------------------------------------------------------
-- 6. Las ventanas (y sus capturas)
---------------------------------------------------------------------------
step("las pestañas nuevas y sus capturas", function()
  P.MapaJugador = function() return 1413 end
  -- Algo más en el diario para que se vea.
  for _, id in ipairs({ 6358, 6358, 6292 }) do P.R.Captura({ { id = id, nombre = NOMBRES[id], cantidad = 1, calidad = id == 6292 and 3 or 1 } }, { banco = id == 6358 and 180582 or nil }) end
  P.Sesion().lanzamientos = 30
  P.Sesion().activo = 1500
  P.V.Abrir("diario")
  T(3)
  local v = rawget(_G, "AlfaPescaVentana")
  check(v and v:IsShown(), "no se abrió la ventana de pesca")
  SNAP("138-pesca-diario", v)
  P.V.Mostrar("pescador")
  T(3)
  check(P.V.Actual() == "pescador", "no se abrió la pestaña Pescador")
  SNAP("138-pesca-pescador", v)
  local d = v.vistas and v.vistas.pescador and v.vistas.pescador.desp
  if d then d:GetScript("OnMouseWheel")(d, -10) SNAP("138-pesca-pescador-records", v) d:IrArriba() end
  P.V.Mostrar("sesiones")
  T(3)
  SNAP("138-pesca-sesiones", v)
  N.Set("pesca", "jauria", false)
  T(2)
  P.V.Mostrar("jauria")
  T(3)
  SNAP("138-pesca-jauria-pedir", v)
  N.Set("pesca", "jauria", true)
  T(2)
  local f = Pz.Temporada()
  for i, x in ipairs({ { "Hocico", "14", "7400", "9", "6359", "1800", "1400", "5" }, { "Colmillo", "9", "3100", "4", "6289", "620", "800", "2" },
    { "Aullido", "21", "12800", "15", "13422", "3900", "2100", "8" } }) do
    J.AlMensaje(x[1] .. "-Reino", x[1] .. "-Reino", { "D", "1", "H", x[2], x[3], x[4], "18", x[5], x[6], f, x[7], x[8] }, "GUILD")
  end
  P.V.Mostrar("jauria")
  T(3)
  SNAP("138-pesca-jauria", v)
  -- Las ocho pestañas caben.
  local seg = v.Seg
  check(seg and seg:GetWidth() <= v:AnchoCuerpo() + 1, "las pestañas no caben: " .. tostring(seg and seg:GetWidth()))
  v:Cerrar()
end)

print(string.format("PRUEBA: 1.3.8 pesca, %d pasos, %d errores", pasos, #ERRORS))
