-- Prueba de la 1.3.7: el medidor de daño como gráfica pequeña (pedido de
-- Toxic: «una gráfica de barras con los de tu grupo, por default y que no sea
-- tan invasivo») y las ayudas de jefe nuevas.
--   * Sin el medidor del juego (C_DamageMeter) nunca sale sola.
--   * «Automático» de fábrica: en grupo, en banda y en mazmorra sí; solo, no.
--   * 220 px de ancho, barras de 16 px, 5 filas en grupo (y la tuya siempre),
--     las de filasBanda en banda.
--   * La X la esconde hasta tu próximo grupo.
--   * En combate no atrapa clics; 10 s después de la pelea se atenúa.
--   * De fábrica no tapa las barras de acción.
--   * Quien tenía la ventana abierta en la 1.3.6 la conserva («siempre»).
--   * Anunciar: 3 líneas como mucho, solo con tu clic. No se lee dos veces ni
--     se repinta si nada cambió.
--   * En el menú de Alfa. «Sal de ahí», la cuenta para jalar y los tiempos del jefe.
local pasos = 0
local function step(nombre, fn)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function falla(msg) NOTE("medidor 1.3.7", msg) end

-- Combate, grupo, banda e instancia, a mano.
local combate, grupo, banda, instancia = false, false, false, false
InCombatLockdown = function() return combate end
UnitAffectingCombat = function() return combate end
IsInGroup = function() return grupo or banda end
IsInRaid = function() return banda end
IsInInstance = function() return instancia, instancia and "party" or "none" end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(8)
print("errores al entrar:", #ERRORS)

local A, N = Alfa, AlfaNucleo
local K = N.Kit
local M = NS_OF("Alfa_Combate")
local V, D = M.Ventana, M.Medidor

local function marco() return rawget(_G, "AlfaCombateMedidor") end
local function aLaVista() local f = marco() return f and f:IsShown() or false end
local function evento(ev) FIRE_EVENT(ev) RUN_TIMERS(2) end

step("de fábrica: automático", function()
  if M.ModoMedidor() ~= "auto" then falla("de fábrica el medidor no está en automático: " .. tostring(M.ModoMedidor())) end
end)

step("sin el medidor del juego nunca sale sola (ni en grupo)", function()
  C_DamageMeter = nil
  grupo = true
  evento("GROUP_ROSTER_UPDATE")
  if aLaVista() then falla("salió sin C_DamageMeter") end
  local _, porque = V.Quiere()
  if porque ~= "sinMedidor" then falla("debía decir sinMedidor, dijo " .. tostring(porque)) end
  grupo = false
  evento("GROUP_ROSTER_UPDATE")
end)

-- El medidor del juego, con 8 fuentes (tú en el 7.º lugar).
Enum.DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, DamageTaken = 7 }
Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }
local fuentes = {}
for i = 1, 8 do
  fuentes[i] = { name = (i == 7 and "Lobato" or ("Lobo" .. i)), isLocalPlayer = i == 7, totalAmount = 10000 - i * 1000,
    amountPerSecond = 500 - i * 40, classFilename = "WARRIOR" }
end
C_DamageMeter = {
  IsDamageMeterAvailable = function() return true, "" end,
  GetCombatSessionFromType = function() return { combatSources = fuentes, maxAmount = 9000, totalAmount = 36000 } end,
  GetCombatSessionFromID = function() return { combatSources = {} } end,
  GetAvailableCombatSessions = function() return {} end,
  GetSessionDurationSeconds = function() return 83 end,
}
GetCVar = function(n) if n == "damageMeterEnabled" then return "1" end return "0" end

step("solo en el mundo, no sale", function()
  grupo, banda, instancia = false, false, false
  evento("GROUP_ROSTER_UPDATE")
  if aLaVista() then falla("salió yendo solo") end
end)

step("en grupo sale: 220 px, barras de 16, 5 filas y la tuya aparte", function()
  grupo = true
  evento("GROUP_ROSTER_UPDATE")
  local f = marco()
  if not aLaVista() then falla("en grupo no salió") return end
  if math.abs(f:GetWidth() - 220) > 0.5 then falla("no mide 220 px: " .. tostring(f:GetWidth())) end
  local filas, alto, yo = 0, nil, false
  for _, x in ipairs(f.filas or {}) do
    if x:IsShown() then
      filas = filas + 1
      alto = x:GetHeight()
      if x.alfaDato and x.alfaDato.yo then yo = true end
    end
  end
  if filas ~= 6 then falla("en grupo debían salir 5 filas y la tuya: " .. filas) end
  if alto ~= 16 then falla("las barras no son de 16 px: " .. tostring(alto)) end
  if not yo then falla("tu fila no está a la vista") end
  local t = f.Titulo and f.Titulo:GetText() or ""
  if not t:find("1:23", 1, true) then falla("la cabecera no dice el tiempo: " .. t) end
end)

step("en banda, las filas que elijas", function()
  banda = true
  M.SetOpt("filasBanda", 8)
  V.Ver()
  local n = 0
  for _, x in ipairs(marco().filas) do if x:IsShown() then n = n + 1 end end
  if n ~= 8 then falla("en banda con 8 filas salieron " .. n) end
  banda = false
  V.Ver()
end)

step("solo dentro de una mazmorra sale", function()
  grupo = false
  instancia = true
  evento("GROUP_ROSTER_UPDATE")
  if not aLaVista() then falla("solo en una mazmorra no salió") end
  instancia = false
  evento("PLAYER_ENTERING_WORLD")
  if aLaVista() then falla("al salir de la mazmorra, solo, siguió") end
end)

step("la X la esconde hasta tu próximo grupo", function()
  grupo = true
  evento("GROUP_ROSTER_UPDATE")
  local f = marco()
  f.Cerrar:GetScript("OnClick")(f.Cerrar, "LeftButton")
  if aLaVista() then falla("la X no la escondió") end
  evento("GROUP_ROSTER_UPDATE")
  if aLaVista() then falla("volvió en el mismo grupo") end
  grupo = false
  evento("GROUP_LEFT")
  grupo = true
  evento("GROUP_JOINED")
  if not aLaVista() then falla("no volvió en tu próximo grupo") end
end)

step("en combate no atrapa clics; después se atenúa", function()
  local f = marco()
  if not f:IsMouseEnabled() then falla("fuera de combate no se deja mover") end
  combate = true
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  if f:IsMouseEnabled() then falla("en combate atrapa clics") end
  if f.Cerrar:IsMouseEnabled() then falla("en combate su X atrapa clics") end
  for _, x in ipairs(f.filas) do if x:IsShown() and x:IsMouseEnabled() then falla("en combate una fila atrapa clics") break end end
  D.Pedir()
  RUN_TIMERS(3)
  if f:IsMouseEnabled() then falla("al repintar en combate volvió a atrapar clics") end
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  if not f:IsMouseEnabled() then falla("al salir de combate no se deja mover") end
  RUN_TIMERS(3)
  if not V.Tenue() then falla("después de la pelea no se atenuó") end
end)

step("no tapa las barras de acción", function()
  local function barra(nombre, punto, x, y, w, h)
    rawset(_G, nombre, nil)
    local b = CreateFrame("Frame", nombre, UIParent)
    b:SetPoint(punto, UIParent, punto, x, y)
    b:SetSize(w, h)
    b:Show()
    return b
  end
  barra("MultiBarRight", "RIGHT", -4, 0, 40, 480)
  barra("MultiBarLeft", "RIGHT", -48, 0, 40, 480)
  barra("MultiBarBottomRight", "BOTTOM", 120, 60, 500, 40)
  N.Datos("combate").pos = nil
  local f = marco()
  f:Hide()
  V.Ver()
  if M.TapaBarras(f) then
    local p = { f:GetPoint(1) }
    falla("el medidor tapa una barra (" .. tostring(p[1]) .. " " .. tostring(p[4]) .. "," .. tostring(p[5]) .. ")")
  end
end)

step("se repinta solo si algo cambió y lee una vez", function()
  V.Ver()
  local antes, lecturas = V.pintadas, D.lecturas
  for _ = 1, 4 do D.Pedir() end
  RUN_TIMERS(3)
  if V.pintadas ~= antes then falla("se repintó sin que nada cambiara") end
  if D.lecturas - lecturas > 1 then falla("leyó el medidor " .. (D.lecturas - lecturas) .. " veces por una actualización") end
  fuentes[1].totalAmount = fuentes[1].totalAmount + 500
  D.Pedir()
  RUN_TIMERS(3)
  if V.pintadas ~= antes + 1 then falla("con datos nuevos no se repintó") end
end)

step("Anunciar: 3 líneas como mucho y solo al chat del grupo", function()
  local enviados = {}
  local viejo = C_ChatInfo
  C_ChatInfo = { SendChatMessage = function(m, canal) enviados[#enviados + 1] = { m, canal } end }
  M.SetOpt("anunciar", 10)
  D.Anunciar("actual", "dps")
  if #enviados == 0 or #enviados > 3 then falla("Anunciar mandó " .. #enviados .. " líneas") end
  for _, e in ipairs(enviados) do
    if e[2] ~= "PARTY" then falla("Anunciar fue a " .. tostring(e[2])) end
    if #e[1] > 250 then falla("una línea es muy larga: " .. #e[1]) end
  end
  local n = #enviados
  grupo = false
  D.Anunciar("actual", "dps")
  if #enviados ~= n then falla("yendo solo, Anunciar escribió en el chat") end
  grupo = true
  C_ChatInfo = viejo
  M.SetOpt("anunciar", 5)
end)

step("el clic derecho trae lo demás", function()
  local o = V.Opciones()
  local hay = {}
  for _, x in ipairs(o) do if x.valor then hay[x.valor] = true end end
  for _, k in ipairs({ "tipo:dano", "sesion:anterior", "anunciar", "cero", "ajustes", "esconder" }) do
    if not hay[k] then falla("al menú le falta " .. k) end
  end
  V.Elegir("tipo:dano")
  if M.Opt("tipo") ~= "dano" then falla("elegir Daño en el menú no cambió el tipo") end
  V.Elegir("tipo:dps")
end)

step("quien la tenía abierta en la 1.3.6 la conserva", function()
  local db = { settings = { combate = { medidor = true } } }
  M.ConvertirMedidor(db)
  if db.settings.combate.medidorModo ~= "siempre" then falla("abierta: debía quedar «siempre»") end
  db = { settings = { combate = { medidor = true, medidorGrupo = true } } }
  M.ConvertirMedidor(db)
  if db.settings.combate.medidorModo ~= "auto" then falla("abierta solo en grupo: debía quedar «auto»") end
  db = { settings = { combate = { medidor = false } } }
  M.ConvertirMedidor(db)
  if db.settings.combate.medidorModo ~= nil then falla("cerrada (lo de fábrica): no debía cambiar nada") end
  db = { settings = { combate = { medidor = true, medidorModo = "apagado" } } }
  M.ConvertirMedidor(db)
  if db.settings.combate.medidorModo ~= "apagado" then falla("pisó un modo ya elegido") end
end)

step("apagado no sale, ni en grupo; /alfa dps sí la abre", function()
  M.SetOpt("medidorModo", "apagado")
  V.Ver()
  if aLaVista() then falla("apagado y salió") end
  V.Alternar()
  if not aLaVista() then falla("/alfa dps no la abrió") end
  V.Alternar()
  M.SetOpt("medidorModo", "auto")
  V.Ver()
end)

step("con Details cargado, el automático no sale (verías dos)", function()
  local viejo = C_AddOns
  C_AddOns = { IsAddOnLoaded = function(n) return n == "Details" end }
  N.DatosPersonaje("combate").medidorCerrado = nil
  local sale, porque = V.Quiere()
  C_AddOns = viejo
  if sale or porque ~= "otroMedidor" then falla("con Details salió igual (" .. tostring(porque) .. ")") end
end)

step("está en el menú de Alfa", function()
  local O = A.UI and A.UI.Options
  if not (O and O.MenuItems) then falla("no hay menú de Alfa") return end
  local items = O.MenuItems(UIParent)
  local esta
  for _, it in ipairs(items) do if it.text == "Medidor de daño" then esta = it end end
  if not esta then falla("el medidor no está en el menú de Alfa") return end
  local antes = aLaVista()
  esta.onClick()
  if aLaVista() == antes then falla("el menú no lo abrió ni lo cerró") end
end)

---------------------------------------------------------------------------
-- Ayudas de jefe
---------------------------------------------------------------------------
step("«¡Sal de ahí!» con algo del suelo, en una instancia y peleando", function()
  instancia = true
  M.SalDeAhi.Ver()
  combate = true
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  -- 1.3.7: sin duración, a la primera no (puede ser un roce); repetido, sí.
  local f0 = rawget(_G, "AlfaCombateSalDeAhi")
  if f0 then f0:Hide() end
  FIRE_EVENT("UNIT_AURA", "player", { addedAuras = { { isHarmful = true, isFromPlayerOrPlayerPet = false, spellId = 4242,
    duration = 0, name = "Fuego", icon = 135805 } } })
  local f = rawget(_G, "AlfaCombateSalDeAhi")
  if f and f:IsShown() then falla("«Sal de ahí» salió a la primera con algo sin duración") end
  FIRE_EVENT("UNIT_AURA", "player", { addedAuras = { { isHarmful = true, isFromPlayerOrPlayerPet = false, spellId = 4242,
    duration = 0, name = "Fuego", icon = 135805 } } })
  f = rawget(_G, "AlfaCombateSalDeAhi")
  if not (f and f:IsShown()) then falla("no salió «Sal de ahí»") end
  if f and f:IsMouseEnabled() then falla("«Sal de ahí» atrapa clics") end
  -- Una maldición que se puede curar no es del suelo.
  f:Hide()
  NOW = NOW + 10
  FIRE_EVENT("UNIT_AURA", "player", { addedAuras = { { isHarmful = true, isFromPlayerOrPlayerPet = false, spellId = 99,
    duration = 2, dispelName = "Curse", name = "Maldición" } } })
  if f:IsShown() then falla("salió con una maldición que se cura") end
end)

step("«¡Sal de ahí!» se apaga solo si el juego esconde los datos", function()
  local viejo = issecretvalue
  issecretvalue = function(v) return v == "secreto" end
  NOW = NOW + 10
  FIRE_EVENT("UNIT_AURA", "player", { addedAuras = { { isHarmful = true, isFromPlayerOrPlayerPet = false, spellId = "secreto", duration = 0 } } })
  issecretvalue = viejo
  if not M.SalDeAhi.Oculto() then falla("con datos secretos no se apagó") end
  FIRE_EVENT("PLAYER_ENTERING_WORLD")
  if M.SalDeAhi.Oculto() then falla("en la zona nueva no volvió") end
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
end)

step("la cuenta para jalar sale en grande", function()
  local visto
  local viejo = K.Anuncio
  K.Anuncio = function(o) visto = o return true end
  FIRE_EVENT("START_PLAYER_COUNTDOWN", "Player-1-1", 10, 10, true, "Grom-Reino")
  K.Anuncio = viejo
  if not visto then falla("la cuenta no sacó el anuncio") return end
  if not (visto.cuenta and visto.cuenta.hasta) then falla("el anuncio no trae la cuenta") end
  if not tostring(visto.sobre):find("Grom", 1, true) then falla("no dice quién la lanzó: " .. tostring(visto.sobre)) end
end)

step("los tiempos del jefe: aprende y luego avisa", function()
  local J = M.Jefes
  J.Evento("ENCOUNTER_START", 777)
  J.Evento("UNIT_SPELLCAST_START", "boss1", "x", 5000)
  NOW = NOW + 20
  J.Evento("UNIT_SPELLCAST_START", "boss1", "x", 5000)
  J.Evento("ENCOUNTER_END", 777)
  local f = rawget(_G, "AlfaCombateJefes")
  if f and f:IsShown() then falla("sin pelea, los tiempos siguen a la vista") end
  J.Evento("ENCOUNTER_START", 777)
  J.Evento("UNIT_SPELLCAST_START", "boss1", "x", 5000)
  NOW = NOW + 5
  local p = J.Proximos()
  if #p == 0 then falla("no aprendió nada del jefe") return end
  if math.abs(p[1].falta - 15) > 1 then falla("debía venir en ~15 s, dice " .. tostring(p[1].falta)) end
  J.Pintar()
  f = rawget(_G, "AlfaCombateJefes")
  local t = f and f.lineas[1]:GetText() or ""
  if not t:find("15", 1, true) then falla("la línea no dice ~15 s: " .. t) end
  if f:IsMouseEnabled() then falla("los tiempos del jefe atrapan clics") end
  J.Evento("ENCOUNTER_END", 777)
  -- Sin datos, nada.
  J.Evento("ENCOUNTER_START", 888)
  if #J.Proximos() ~= 0 then falla("con un jefe nuevo dijo algo sin datos") end
  J.Evento("ENCOUNTER_END", 888)
  instancia = false
end)

print(("PRUEBA: medidor 1.3.7, %d pasos, errores: %d"):format(pasos, #ERRORS))
