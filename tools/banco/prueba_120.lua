-- Prueba de los arreglos de la 1.2.0, la versión estable (tools/prueba.py la
-- corre con las demás prueba_*.lua). Lo que el banco puede simular:
--   * un texto "secreto" (el juego los da en mazmorras y en combate) en una
--     letra del tema no rompe nada, ni al ponerlo ni al repintar todo;
--   * al entrar en combate se cierra el menú del Kit (su capa no se come clics);
--   * Talentos no aplica con la ventana de talentos del juego abierta;
--   * los marcadores compartidos solo llegan del grupo, y no de un susurro;
--   * lo que espera al fin del combate no se repite;
--   * el lobo te recibe al entrar al juego (y no al recargar).
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

Alfa.Hidden = function() return false end
-- Quien ya terminó la configuración: así el saludo de cada entrada puede salir.
local B = NS_OF("Alfa_Bienvenida")
-- Cuenta las veces que la intro sale con el saludo de cada entrada.
local saludos = 0
local introReal = B.Intro
B.Intro = function(fn, o)
  if type(o) == "table" and type(o.texto) == "string" then saludos = saludos + 1 end
  return introReal(fn, o)
end
FIRE_EVENT("PLAYER_LOGIN")
local N = AlfaNucleo
N.Datos("bienvenida").respondio = B.VERSION
N.Datos("bienvenida").versionVista = B.VersionAlfa and B.VersionAlfa() or "9.9.9"
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
local A = Alfa
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end

local SECRETO = "\1secreto\1"
local realIssecret = issecretvalue

step("letras: un texto secreto no rompe el tema", function()
  issecretvalue = function(v) return v == SECRETO end
  local f = CreateFrame("Frame", nil, UIParent)
  local fs = f:CreateFontString(nil, "OVERLAY")
  A.Theme.Font(fs, "body")
  fs:SetText(SECRETO)
  fs:SetFormattedText("%s", SECRETO)
  local K = N.Kit
  K.Escribir(fs, SECRETO)
  A.Theme.Refresh()
  issecretvalue = realIssecret
end)
issecretvalue = realIssecret

step("menú del Kit: se cierra al entrar en combate", function()
  local K = N.Kit
  local caja = CreateFrame("Frame", nil, UIParent)
  caja:SetSize(200, 30)
  caja:SetPoint("CENTER")
  K.Menu(caja, { { valor = 1, texto = "Uno" }, { valor = 2, texto = "Dos" } }, 1, function() end)
  local menu = _G.AlfaKitMenu
  if not (menu and menu:IsShown()) then error("el menú no se abrió") end
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  if menu:IsShown() then error("el menú siguió abierto al entrar en combate") end
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
end)

step("Talentos: no aplica con la ventana del juego abierta", function()
  local Ar = NS_OF("Alfa_Builds").Arbol
  if not (Ar and Ar.PuedeEditar) then error("falta Arbol.PuedeEditar") end
  local viejo = { C_Traits = C_Traits, C_ClassTalents = C_ClassTalents }
  C_Traits = { PurchaseRank = function() return true end, CommitConfig = function() return true end,
    ConfigHasStagedChanges = function() return false end, CanEditConfig = function() return true end }
  C_ClassTalents = { CommitConfig = function() return true end, CanEditTalents = function() return true end }
  local ventana = CreateFrame("Frame", "PlayerSpellsFrame", UIParent)
  ventana:Show()
  local ok1, razon1 = Ar.PuedeEditar(1)
  ventana:Hide()
  C_Traits.ConfigHasStagedChanges = function() return true end
  local ok2, razon2 = Ar.PuedeEditar(1)
  C_Traits.ConfigHasStagedChanges = function() return false end
  local ok3 = Ar.PuedeEditar(1)
  C_Traits, C_ClassTalents = viejo.C_Traits, viejo.C_ClassTalents
  if ok1 or razon1 ~= "ventana" then error("aplicó con la ventana de talentos abierta (" .. tostring(razon1) .. ")") end
  if ok2 or razon2 ~= "pendientes" then error("pasaría por encima de tus cambios sin guardar (" .. tostring(razon2) .. ")") end
  if not ok3 then error("con todo en orden no deja aplicar") end
  for _, r in ipairs({ "ventana", "pendientes" }) do
    if type(Ar.RAZONES[r]) ~= "string" then error("falta el texto de la razón " .. r) end
  end
end)

step("marcadores: solo del grupo, nunca de un susurro", function()
  local Mk = NS_OF("Alfa_Mundo").Marcadores
  local antes = #Mk.Lista()
  local enGrupo = { ["Ana"] = true }
  UnitInParty = function(n) return enGrupo[n] or false end
  UnitInRaid = function() return nil end
  local function llega(texto, canal, quien) FIRE_EVENT("CHAT_MSG_ADDON", "AlfaMarca", texto, canal, quien) end
  llega("1|1429|4200|3700|huella|acento|Del susurro", "WHISPER", "Ana")
  llega("1|1429|4200|3700|huella|acento|Del extraño", "PARTY", "Extraño")
  if #Mk.Lista() ~= antes then error("aceptó un marcador de un susurro o de alguien fuera del grupo") end
  for i = 1, 6 do llega("1|1429|" .. (4000 + i * 100) .. "|3700|huella|acento|Punto " .. i, "PARTY", "Ana") end
  local nuevos = #Mk.Lista() - antes
  if nuevos == 0 then error("no aceptó el marcador de alguien de tu grupo") end
  if nuevos > 3 then error("aceptó " .. nuevos .. " marcadores de una persona en un minuto") end
  UnitInParty, UnitInRaid = nil, nil
end)

step("después del combate: la misma tarea no se repite", function()
  local cuenta = 0
  local function tarea() cuenta = cuenta + 1 end
  local viejo = InCombatLockdown
  InCombatLockdown = function() return true end
  N.FueraDeCombate(tarea)
  N.FueraDeCombate(tarea)
  N.FueraDeCombate("prueba.clave", function() cuenta = cuenta + 10 end)
  N.FueraDeCombate("prueba.clave", function() cuenta = cuenta + 100 end)
  InCombatLockdown = viejo
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  if cuenta ~= 101 then error("al salir del combate corrió " .. cuenta .. " (se esperaba 101: una vez la tarea y solo la última con clave)") end
end)

step("el lobo te recibe al entrar (no al recargar)", function()
  if A.Get("bienvenida.introSiempre") ~= true then error("el saludo no viene encendido de fábrica") end
  T(12)
  if saludos ~= 1 then error("al entrar al juego la intro con el saludo salió " .. saludos .. " veces (se esperaba 1)") end
  -- Un /reload no saluda otra vez.
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
  T(12)
  if saludos ~= 1 then error("al recargar la intro volvió a saludar") end
end)

print("PRUEBA: 1.2.0, " .. pasos .. " pasos, " .. #ERRORS .. " errores")
