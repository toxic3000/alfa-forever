-- Prueba de la 1.3.7, Pesca (tools/prueba.py la corre con las demás):
--   1. «Volver a mi equipo» fuera de combate: te pone las armas (la macro) y
--      el resto (Restaurar, sin pedir otra vez las armas) y cierra el modo;
--   2. «A pelear» en combate: la macro ya está armada, el clic no toca la
--      armadura ni SetAttribute; el resto vuelve al salir de la pelea;
--   3. sin armas recordadas: el botón queda apagado y su cuadro dice por qué;
--   4. los arreglos del plan: 129 (pieza que no entra), 130 (volumen), 135
--      (duración real), 139 (solo el corcho), 144 («2 h»), 166 (bancos), 142
--      (el resumen de la vista mínima no se corta);
--   5. las mejoras: resumen al cerrar, cuánto falta para el tope, el tope,
--      el cebo que se acaba, el clic derecho de la barra y lo que te falta en la zona.
SNAPSHOTS = {}
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
local function check(cond, msg) if not cond then NOTE("1.3.7 pesca", msg) end end
local function T(n) RUN_TIMERS(n or 3) end

---------------------------------------------------------------------------
-- El juego simulado: una caña, una espada, un escudo y un sombrero
---------------------------------------------------------------------------
local CANA, ESPADA, ESCUDO, GORRO, GORRO_PESCA = 6256, 25, 2129, 1000, 1001
local function enlace(id, nombre) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. nombre .. "]|h|r" end
local L_CANA, L_ESPADA, L_ESCUDO, L_GORRO = enlace(CANA, "Caña de pescar"), enlace(ESPADA, "Espada corta"), enlace(ESCUDO, "Escudo"), enlace(GORRO, "Gorro")
local INFO = {
  [CANA] = { "INVTYPE_2HWEAPON", 2, 20 }, [ESPADA] = { "INVTYPE_WEAPON", 2, 7 },
  [ESCUDO] = { "INVTYPE_SHIELD", 4, 6 }, [GORRO] = { "INVTYPE_HEAD", 4, 1 }, [GORRO_PESCA] = { "INVTYPE_HEAD", 4, 1 },
}
Enum.ItemClass = { Weapon = 2, Armor = 4, Consumable = 0 }
Enum.ItemWeaponSubclass = { Fishingpole = 20 }
C_Item.GetItemInfoInstant = function(x)
  local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)"))
  local i = id and INFO[id]
  if not i then return nil end
  return id, "", "", i[1], 134400, i[2], i[3]
end
local puesto = { [16] = L_CANA, [1] = L_GORRO }
GetInventoryItemLink = function(_, r) return puesto[r] end
GetInventoryItemID = function(_, r) local l = puesto[r] return l and tonumber(l:match("item:(%d+)")) end
local equipados = {}
C_Item.EquipItemByName = function(l, r)
  equipados[#equipados + 1] = { l, r }
  if InCombatLockdown() and r ~= 16 and r ~= 17 then NOTE("1.3.7 pesca", "se pidió armadura en combate: ranura " .. tostring(r)) end
  puesto[r] = l
end
local combate = false
InCombatLockdown = function() return combate end
local avisos = {}

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)

local P = NS_OF("Alfa_Pesca")
local N = AlfaNucleo
local Eq, Pe, E = P.Eq, P.Pelear, P.E
check(Eq and Pe and E, "no está el módulo de pesca o Pelear.lua")
if not (Eq and Pe and E) then print(string.format("PRUEBA: 1.3.7 pesca, %d pasos, %d errores", pasos, #ERRORS)) return end

local aviso = N.Kit.Aviso
N.Kit.Aviso = function(o) avisos[#avisos + 1] = o return aviso(o) end
local function ultimoAviso(id)
  for i = #avisos, 1, -1 do if avisos[i].id == id then return avisos[i] end end
  return nil
end

local boton = rawget(_G, "AlfaPescaPelear")
check(boton and boton.GetAttribute, "no existe el botón seguro AlfaPescaPelear")
-- Nunca SetAttribute en combate.
local enCombateAttr = {}
local setAttr = boton.SetAttribute
boton.SetAttribute = function(self, k, v)
  if InCombatLockdown() then enCombateAttr[#enCombateAttr + 1] = k end
  return setAttr(self, k, v)
end

boton.Icono.SetDesaturated = function(self, v) self._desat = v and true or false end

local function recordar()
  local d = N.DatosPersonaje("pesca")
  d.equipoNormal = { [16] = L_ESPADA, [17] = L_ESCUDO, [1] = L_GORRO }
  puesto[16], puesto[17], puesto[1] = L_CANA, nil, enlace(GORRO_PESCA, "Gorro de pesca")
end

step("fuera de combate: pone todo y cierra el modo", function()
  recordar()
  P.AbrirModo()
  T(5)
  check(P.Modo(), "el modo pesca no se abrió")
  local macro = boton:GetAttribute("macrotext") or ""
  check(boton:GetAttribute("type") == "macro", "el botón no tiene su macro")
  check(macro:find("/equipslot 16 Espada corta", 1, true), "la macro no pone la espada: " .. macro)
  check(macro:find("/equipslot 17 Escudo", 1, true), "la macro no pone el escudo: " .. macro)
  check(not macro:find("Gorro", 1, true), "la macro trae armadura (no cambia en combate): " .. macro)
  check(Pe.Estado() == "todo", "fuera de combate el botón no está listo: " .. tostring(Pe.Estado()))
  local titulo, texto = Pe.Info()
  check(titulo == "Volver a mi equipo", "el título fuera de combate es " .. tostring(titulo))
  check(texto:find("cierra el modo pesca", 1, true), "el cuadro no dice que cierra el modo")
  P.Barra.Desplegar() -- (el banco corre los relojes sin esperar: la barra ya se plegó)
  local barra = P.Barra.Barra()
  check(barra and barra.hueco, "la barra no le guarda su hueco")
  check(boton:IsShown(), "el botón no se ve sobre la barra (barra " .. tostring(barra and barra:IsShown()) .. ", hueco " .. tostring(barra and barra.hueco and barra.hueco:IsShown()) .. ")")
  -- El clic: la macro (el juego) pone las armas y luego PostClick.
  equipados = {}
  puesto[16], puesto[17] = L_ESPADA, L_ESCUDO
  boton:GetScript("PostClick")(boton, "LeftButton", false)
  T(10)
  check(not P.Modo(), "el modo pesca siguió abierto")
  local armas, gorro = 0, false
  for _, x in ipairs(equipados) do
    if x[2] == 16 or x[2] == 17 then armas = armas + 1 end
    if x[2] == 1 and x[1] == L_GORRO then gorro = true end
  end
  check(gorro, "no volvió el gorro de siempre")
  check(armas == 0, "Restaurar pidió otra vez las armas que ya puso la macro")
  check(not Eq.HayNormal(), "quedó equipo por devolver")
end)

step("en combate: solo las armas; el resto al salir", function()
  recordar()
  P.AbrirModo()
  T(5)
  check(boton:GetAttribute("macrotext"), "sin macro antes del combate")
  enCombateAttr = {}
  avisos = {}
  equipados = {}
  -- Como en el juego: PLAYER_REGEN_DISABLED llega antes del bloqueo.
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  combate = true
  T(5)
  check(boton:IsShown(), "al empezar la pelea el botón no quedó a la vista")
  check(Pe.Estado() == "armas", "en combate el botón no está listo: " .. tostring(Pe.Estado()))
  check(Pe.Titulo() == "A pelear", "en combate el título no es «A pelear»")
  local a = ultimoAviso("pesca.atacan")
  check(a and tostring(a.texto):find("armas", 1, true), "no salió el aviso de «te atacan con la caña»")
  local est = P.Estado()
  check(est.texto:find("A pelear", 1, true), "la barra no dice «A pelear» en combate: " .. tostring(est.texto))
  -- La macro (el juego) cambia las armas; luego PostClick.
  puesto[16], puesto[17] = L_ESPADA, L_ESCUDO
  FIRE_EVENT("PLAYER_EQUIPMENT_CHANGED", 16)
  boton:GetScript("PostClick")(boton, "LeftButton", false)
  T(5)
  check(#equipados == 0, "en combate se pidió equipo por código")
  check(ultimoAviso("pesca.pelear"), "no salió el aviso «En combate solo cambian las armas»")
  check(Eq.Normal()[1] == L_GORRO, "el gorro de siempre se olvidó en combate")
  -- Cambios en combate: nada de SetAttribute.
  P.Avisar("equipo")
  T(5)
  check(#enCombateAttr == 0, "SetAttribute en combate: " .. table.concat(enCombateAttr, ", "))
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  T(10)
  local gorro = false
  for _, x in ipairs(equipados) do if x[2] == 1 and x[1] == L_GORRO then gorro = true end end
  check(gorro, "al salir de la pelea no volvió el gorro")
  check(not P.Modo(), "al salir de la pelea el modo pesca siguió abierto")
end)

step("sin armas recordadas: apagado con su porqué", function()
  N.DatosPersonaje("pesca").equipoNormal = {}
  puesto[16] = L_CANA
  P.AbrirModo()
  T(5)
  check(boton:GetAttribute("type") == nil and boton:GetAttribute("macrotext") == nil, "sin armas, el botón sigue con macro")
  local estado, motivo = Pe.Estado()
  check(estado == "nada", "sin armas el botón no está apagado: " .. tostring(estado))
  check(motivo and motivo:find("no recuerda", 1, true), "el apagado no dice por qué")
  check(boton.Icono._desat == true, "el ícono no se ve apagado")
  -- Solo con armadura recordada: fuera de combate sí sirve, en combate no.
  N.DatosPersonaje("pesca").equipoNormal = { [1] = L_GORRO }
  check(Pe.Estado() == "todo", "con el gorro recordado, fuera de combate no sirve")
  combate = true
  check(Pe.Estado() == "nada", "en combate sin armas el botón no se apaga")
  combate = false
  N.DatosPersonaje("pesca").equipoNormal = {}
  P.CerrarModo()
  T(5)
end)

step("129: una pieza que no entra se salta", function()
  local c = { enlace = L_GORRO, ranura = 1 }
  Eq.OlvidarIntentos()
  check(not Eq.NoEntra(L_GORRO, 1), "sin intentar, ya se salta")
  Eq.Intentado({ c })
  T(2) -- pasa el tiempo (GetTime avanza)
  check(Eq.NoEntra(L_GORRO, 1), "un intento fallido no se salta")
  Eq.OlvidarIntentos()
  check(not Eq.NoEntra(L_GORRO, 1), "al abrir el modo no se olvida")
end)

step("130: el volumen general es el tuyo", function()
  local cvars = { Sound_MasterVolume = "0.4", Sound_SFXVolume = "0.5" }
  local puestos = {}
  local gC, sC = C_CVar.GetCVar, C_CVar.SetCVar
  C_CVar.GetCVar = function(n) return cvars[n] or "0" end
  C_CVar.SetCVar = function(n, v) puestos[n] = v cvars[n] = v end
  N.Set("pesca", "sonido", true)
  P.Aplicar()
  check(puestos.Sound_MasterVolume == nil, "subió el volumen general: " .. tostring(puestos.Sound_MasterVolume))
  check(puestos.Sound_SFXVolume == "1", "no subió los efectos")
  P.Restaurar()
  check(cvars.Sound_SFXVolume == "0.5", "no devolvió los efectos")
  cvars.Sound_MasterVolume = "0"
  puestos = {}
  P.Aplicar()
  check(puestos.Sound_MasterVolume == "0.3", "con el volumen en cero no se oiría el chapoteo")
  P.Restaurar()
  check(cvars.Sound_MasterVolume == "0", "no devolvió el volumen en cero")
  C_CVar.GetCVar, C_CVar.SetCVar = gC, sC
end)

step("135 y 142: duración real y la vista mínima sin cortes", function()
  local uci = rawget(_G, "UnitChannelInfo")
  UnitChannelInfo = function() return "Pesca", "", 0, NOW * 1000, (NOW + 21) * 1000, false, false, 7620 end
  P.AbrirModo()
  FIRE_EVENT("UNIT_SPELLCAST_CHANNEL_START", "player", "x", 7620)
  T(2)
  check(math.abs(P.DuracionCanal() - 21) < 0.01, "no usa la duración real: " .. tostring(P.DuracionCanal()))
  E.ultimo = { { nombre = string.rep("Pez de nombre larguísimo ", 4), cantidad = 3 } }
  P.Barra.MostrarCanal()
  P.Barra.EscribirRecap()
  local c = rawget(_G, "AlfaPescaCanal")
  check(c and c.Recap and c.Recap._wrap == true, "el resumen sigue en una sola línea cortada")
  UnitChannelInfo = uci
  FIRE_EVENT("UNIT_SPELLCAST_CHANNEL_STOP", "player", "x", 7620)
  T(5)
  P.CerrarModo()
  T(5)
end)

step("139: «Buen lanzamiento» solo con el corcho", function()
  E.canal = GetTime()
  check(P.EsCorcho("GameObject-0-1-2-3-35591-0000A"), "el corcho no cuenta")
  check(not P.EsCorcho("Creature-0-1-2-3-1234-0000A"), "un PNJ cuenta como corcho")
  check(not P.EsCorcho("GameObject-0-1-2-3-180582-0000A"), "un banco de peces cuenta como corcho")
  E.canal = nil
end)

step("144: las metas dicen «2 h»", function()
  local m = { tipo = "tiempo", objetivo = 7200, hecho = 900 }
  local t = P.TextoMeta(m)
  check(t:find("2 h", 1, true) and not t:find("120:00", 1, true) and not t:find("00 min", 1, true), "la meta dice: " .. t)
end)

step("166: un banco de peces cuenta una vez", function()
  local antes = P.Sesion().bancos
  local o = { { id = 6358, nombre = "Pez", cantidad = 1 } }
  P.R.Captura(o, { banco = 180582, bancoGuid = "GameObject-0-1-2-3-180582-AAA" })
  P.R.Captura(o, { banco = 180582, bancoGuid = "GameObject-0-1-2-3-180582-AAA" })
  check(P.Sesion().bancos == antes + 1, "el mismo banco contó dos veces")
  P.R.Captura(o, { banco = 180582, bancoGuid = "GameObject-0-1-2-3-180582-BBB" })
  check(P.Sesion().bancos == antes + 2, "otro banco no contó")
end)

step("mejoras: resumen al cerrar, tope, cebo, clic derecho", function()
  avisos = {}
  P.AbrirModo()
  T(3)
  P.R.Captura({ { id = 6358, nombre = "Pez", cantidad = 2 } }, {})
  P.CerrarModo()
  T(3)
  local a = ultimoAviso("pesca.resumen")
  check(a and tostring(a.texto):find("2 capturas", 1, true), "no salió el resumen al cerrar: " .. tostring(a and a.texto))
  -- Cuánto falta para el tope y qué sigue.
  local hab = P.Habilidad
  P.Habilidad = function() return 120, 150, 5 end
  local t, x = P.InfoHabilidad()
  check(x:find("30", 1, true), "no dice cuánto falta: " .. x)
  check(x:find("Experto", 1, true), "no dice qué rango sigue: " .. x)
  P.Habilidad = function() return 150, 150, 0 end
  N.DatosPersonaje("pesca").avisoTope = nil
  P.RevisarTope()
  T(3)
  check(ultimoAviso("pesca.tope"), "no avisó del tope")
  P.Habilidad = hab
  -- El cebo se acabó y no queda otro.
  E.modo = true
  E.avisoCebo = nil
  P.CeboAcabado()
  check(ultimoAviso("pesca.cebo"), "no avisó que se acabó el cebo")
  E.modo = false
  -- El clic derecho de la barra.
  local mas = P.Barra.MENUS.mas()
  check(mas and #mas.filas >= 4, "el menú «Más» no tiene sus filas")
  local mapa = P.MapaJugador
  P.MapaJugador = function() return 1413 end
  local falta = P.FaltanAqui()
  check(#falta > 0, "no dice qué te falta en la zona")
  P.MapaJugador = mapa
end)

print(string.format("PRUEBA: 1.3.7 pesca, %d pasos, %d errores", pasos, #ERRORS))
